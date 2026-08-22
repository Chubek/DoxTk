#ifndef DOXTK_EXECUTOR_HPP
#define DOXTK_EXECUTOR_HPP

#include <chrono>
#include <cstdint>
#include <functional>
#include <map>
#include <memory>
#include <mutex>
#include <optional>
#include <sstream>
#include <stdexcept>
#include <string>
#include <unordered_map>
#include <vector>

#include "../glue/doxtk_glue.hpp"

namespace doxtk {
namespace executor {

/* ========================================================================
 * Activation Key
 * ======================================================================== */

struct ActivationKey {
    std::string digest;  /* hex-encoded XXH3-64 */

    bool operator==(const ActivationKey& other) const {
        return digest == other.digest;
    }

    bool operator!=(const ActivationKey& other) const {
        return digest != other.digest;
    }

    bool empty() const { return digest.empty(); }
    std::string to_string() const { return digest; }
};

/* ========================================================================
 * Resource Limits ([E-2])
 * ======================================================================== */

struct ResourceLimits {
    uint32_t cpu_ms = 2000;
    uint32_t memory_mb = 64;
    uint32_t output_mb = 16;

    std::string to_string() const {
        std::ostringstream oss;
        oss << "ResourceLimits{cpu_ms=" << cpu_ms
            << ", memory_mb=" << memory_mb
            << ", output_mb=" << output_mb << "}";
        return oss.str();
    }
};

/* ========================================================================
 * Activation Input / Output
 * ======================================================================== */

struct ActivationInput {
    std::string kernel_path;
    std::string kernel_source;
    std::string capability_name;
    std::string input_json;
    std::string params_json;
};

struct ActivationOutput {
    std::string output_json;
    bool from_cache = false;
};

/* ========================================================================
 * Activation Result
 * ======================================================================== */

struct ActivationResult {
    bool ok = false;
    std::string error_code;
    std::string error_message;
    ActivationOutput output;

    static ActivationResult success(ActivationOutput out) {
        ActivationResult r;
        r.ok = true;
        r.output = std::move(out);
        return r;
    }

    static ActivationResult failure(std::string code, std::string msg) {
        ActivationResult r;
        r.ok = false;
        r.error_code = std::move(code);
        r.error_message = std::move(msg);
        return r;
    }
};

/* ========================================================================
 * Cache Entry
 * ======================================================================== */

struct CacheEntry {
    std::string output_json;
    std::string integrity_hash;
    std::string kernel_path;
    std::string capability_name;
    uint64_t timestamp = 0;
};

/* ========================================================================
 * Activation Cache ([E-4], [E-5])
 * ======================================================================== */

class ActivationCache {
public:
    ActivationCache() = default;

    ActivationCache(const ActivationCache&) = delete;
    ActivationCache& operator=(const ActivationCache&) = delete;

    /* Query the cache for an activation key.
     * Returns the cached output if found and integrity check passes,
     * otherwise returns std::nullopt. */
    std::optional<std::string> lookup(const ActivationKey& key);

    /* Store output in the cache under the given key. */
    void store(const ActivationKey& key,
               const std::string& output_json,
               const std::string& kernel_path,
               const std::string& capability_name);

    /* Invalidate a specific cache entry. */
    void invalidate(const ActivationKey& key);

    /* Clear all cache entries. */
    void clear();

    /* Number of cached entries. */
    size_t size() const;

    /* True if the cache contains the given key. */
    bool contains(const ActivationKey& key) const;

    /* Compute integrity hash of a value. */
    static std::string compute_integrity_hash(const std::string& data);

private:
    std::mutex mutex_;
    std::unordered_map<std::string, CacheEntry> entries_;

    bool verify_integrity(const CacheEntry& entry) const;
};

/* ========================================================================
 * Executor Statistics
 * ======================================================================== */

struct ExecutorStats {
    uint64_t total_activations = 0;
    uint64_t cache_hits = 0;
    uint64_t cache_misses = 0;
    uint64_t errors = 0;
    uint64_t total_execution_ms = 0;

    void reset() {
        total_activations = 0;
        cache_hits = 0;
        cache_misses = 0;
        errors = 0;
        total_execution_ms = 0;
    }
};

/* ========================================================================
 * Executor ([E-1] through [E-7])
 * ======================================================================== */

class Executor {
public:
    /* Construct an executor.
     * kernel_base_path: directory containing kernel .lua files.
     * env_descriptor:   host environment descriptor for H_env ([E-6]). */
    explicit Executor(std::string kernel_base_path = "kernel/",
                      std::string env_descriptor = "");

    Executor(const Executor&) = delete;
    Executor& operator=(const Executor&) = delete;
    Executor(Executor&&) = default;
    Executor& operator=(Executor&&) = default;

    /* --- Configuration --- */

    void set_limits(const ResourceLimits& limits);
    const ResourceLimits& limits() const { return limits_; }

    void set_env_descriptor(const std::string& desc);
    const std::string& env_descriptor() const { return env_descriptor_; }

    void set_clock_epoch(int64_t epoch);

    /* --- Activation Key Computation ([E-6], [E-7]) --- */

    /* Compute the activation key for the given input.
     * K_act = XXH3-64(H_code || H_inputs || H_params || H_env) */
    ActivationKey compute_activation_key(const ActivationInput& input) const;

    /* --- Execution ([E-1], [E-2], [E-3], [E-5]) --- */

    /* Execute a single activation.
     * Creates a fresh GlueContext, checks the cache, and runs the kernel
     * if needed. Returns the result. */
    ActivationResult execute(const ActivationInput& input);

    /* --- Cache --- */

    ActivationCache& cache() { return cache_; }
    const ActivationCache& cache() const { return cache_; }

    /* --- Statistics --- */

    const ExecutorStats& stats() const { return stats_; }
    void reset_stats();

    /* --- Static helpers --- */

    /* Compute XXH3-64 of a string, returning hex-encoded digest. */
    static std::string xxhash_hex(const std::string& data);

    /* Compute XXH3-64 of concatenated buffers. */
    static std::string xxhash_hex(const std::vector<std::string>& parts);

private:
    /* Create a fresh, isolated GlueContext for one activation. */
    glue::GlueContext create_context();

    /* Enforce resource limits on the result of an activation.
     * Returns ERR_RESOURCE_LIMIT if any limit is exceeded. */
    std::optional<ActivationResult> check_resource_limits(
        const ActivationOutput& output);

    /* Build the host environment descriptor string. */
    std::string build_env_descriptor() const;

    std::string kernel_base_path_;
    std::string env_descriptor_;
    ResourceLimits limits_;
    ActivationCache cache_;
    ExecutorStats stats_;
    int64_t clock_epoch_ = 0;
};

/* ========================================================================
 * Error codes (Section 11, Table 4)
 * ======================================================================== */

namespace error {
    constexpr const char* SANDBOX_VIOLATION = "ERR_SANDBOX_VIOLATION";
    constexpr const char* RESOURCE_LIMIT    = "ERR_RESOURCE_LIMIT";
    constexpr const char* KERNEL_RUNTIME    = "ERR_KERNEL_RUNTIME";
    constexpr const char* IR_INVALID        = "ERR_IR_INVALID";
    constexpr const char* PLAN_CYCLE        = "ERR_PLAN_CYCLE";
    constexpr const char* PLAN_TYPE         = "ERR_PLAN_TYPE";
    constexpr const char* PLAN_UNRESOLVED   = "ERR_PLAN_UNRESOLVED";
} // namespace error

} // namespace executor
} // namespace doxtk

#endif // DOXTK_EXECUTOR_HPP
