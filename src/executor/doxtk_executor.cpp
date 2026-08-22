#include "doxtk_executor.hpp"

#define XXH_IMPLEMENTATION
#include "../../third_party/xxHash/xxhash.h"

#include <algorithm>
#include <cstring>
#include <fstream>
#include <iomanip>
#include <sstream>

namespace doxtk {
namespace executor {

/* ========================================================================
 * SHA-256 helpers
 * ======================================================================== */

std::string Executor::xxhash_hex(const std::string& data) {
    XXH64_hash_t hash = XXH3_64bits(data.data(), data.size());

    std::ostringstream oss;
    oss << std::hex << std::setfill('0') << std::setw(16)
        << hash;
    return oss.str();
}

std::string Executor::sha256_hex(const std::vector<std::string>& parts) {
    SHA256_CTX ctx;
    SHA256_Init(&ctx);
    for (const auto& part : parts) {
        SHA256_Update(&ctx, part.data(), part.size());
    }
    unsigned char hash[SHA256_DIGEST_LENGTH];
    SHA256_Final(hash, &ctx);

    std::ostringstream oss;
    for (int i = 0; i < SHA256_DIGEST_LENGTH; ++i) {
        oss << std::hex << std::setfill('0') << std::setw(2)
            << static_cast<int>(hash[i]);
    }
    return oss.str();
}

/* ========================================================================
 * Deterministic JSON serialization ([E-7])
 * ======================================================================== */

namespace {

/* Sort keys in a JSON string for deterministic serialization.
 * Handles top-level objects and nested objects recursively.
 * This is a simple parser that re-serializes with sorted keys. */
std::string sort_json_keys(const std::string& json) {
    /* Parse the JSON into a qamrpp::Value, then re-serialize with
     * sorted keys.  We use the Glue layer's JsonUtil. */
    auto val = doxtk::glue::JsonUtil::decode(json);
    if (!val) return json;

    /* JsonUtil::encode already sorts keys because QaMRpp's
     * table_entries are stored in insertion order, and we need
     * to sort.  We'll do a recursive sort pass. */

    std::function<void(qamrpp::ValuePtr)> sort_rec;
    sort_rec = [&](qamrpp::ValuePtr v) {
        if (!v) return;
        if (v->type == qamrpp::Value::TABLE) {
            /* Sort entries by key */
            std::sort(v->table_entries.begin(), v->table_entries.end(),
                [](const auto& a, const auto& b) {
                    if (a.first->type != qamrpp::Value::STRING ||
                        b.first->type != qamrpp::Value::STRING) {
                        return false;
                    }
                    return a.first->string_value < b.first->string_value;
                });
            /* Recurse into values */
            for (auto& kv : v->table_entries) {
                sort_rec(kv.second);
            }
        }
    };

    sort_rec(val);
    return doxtk::glue::JsonUtil::encode(val);
}

} // anonymous namespace

/* ========================================================================
 * ActivationCache
 * ======================================================================== */

std::string ActivationCache::compute_integrity_hash(
    const std::string& data) {
    return Executor::sha256_hex(data);
}

bool ActivationCache::verify_integrity(const CacheEntry& entry) const {
    std::string computed = compute_integrity_hash(entry.output_json);
    return computed == entry.integrity_hash;
}

std::optional<std::string> ActivationCache::lookup(const ActivationKey& key) {
    std::lock_guard<std::mutex> lock(mutex_);
    auto it = entries_.find(key.digest);
    if (it == entries_.end()) return std::nullopt;

    if (!verify_integrity(it->second)) {
        /* Integrity check failed – remove the corrupted entry */
        entries_.erase(it);
        return std::nullopt;
    }

    return it->second.output_json;
}

void ActivationCache::store(const ActivationKey& key,
                            const std::string& output_json,
                            const std::string& kernel_path,
                            const std::string& capability_name) {
    std::lock_guard<std::mutex> lock(mutex_);
    CacheEntry entry;
    entry.output_json = output_json;
    entry.integrity_hash = compute_integrity_hash(output_json);
    entry.kernel_path = kernel_path;
    entry.capability_name = capability_name;
    entry.timestamp = std::chrono::duration_cast<std::chrono::seconds>(
        std::chrono::system_clock::now().time_since_epoch()).count();
    entries_[key.digest] = std::move(entry);
}

void ActivationCache::invalidate(const ActivationKey& key) {
    std::lock_guard<std::mutex> lock(mutex_);
    entries_.erase(key.digest);
}

void ActivationCache::clear() {
    std::lock_guard<std::mutex> lock(mutex_);
    entries_.clear();
}

size_t ActivationCache::size() const {
    std::lock_guard<std::mutex> lock(mutex_);
    return entries_.size();
}

bool ActivationCache::contains(const ActivationKey& key) const {
    std::lock_guard<std::mutex> lock(mutex_);
    return entries_.find(key.digest) != entries_.end();
}

/* ========================================================================
 * Executor
 * ======================================================================== */

Executor::Executor(std::string kernel_base_path,
                   std::string env_descriptor)
    : kernel_base_path_(std::move(kernel_base_path))
    , env_descriptor_(std::move(env_descriptor)) {}

void Executor::set_limits(const ResourceLimits& limits) {
    limits_ = limits;
}

void Executor::set_env_descriptor(const std::string& desc) {
    env_descriptor_ = desc;
}

void Executor::set_clock_epoch(int64_t epoch) {
    clock_epoch_ = epoch;
}

void Executor::reset_stats() {
    stats_.reset();
}

std::string Executor::build_env_descriptor() const {
    /* If an explicit descriptor was provided, use it.
     * Otherwise, build one from the host service versions exposed
     * by a fresh GlueContext. */
    if (!env_descriptor_.empty()) return env_descriptor_;

    /* Build a minimal env descriptor from a fresh context */
    auto ctx = create_context();
    std::ostringstream oss;
    auto names = ctx.registry().service_names();
    std::sort(names.begin(), names.end());
    for (const auto& name : names) {
        auto* svc = ctx.registry().find(name);
        if (svc) {
            oss << name << "=" << svc->contract().version << ";";
        }
    }
    return oss.str();
}

glue::GlueContext Executor::create_context() {
    glue::GlueContext ctx(kernel_base_path_);
    auto result = ctx.initialise();
    if (!result.ok()) {
        throw std::runtime_error(
            "Failed to initialise GlueContext: " + result.message);
    }
    ctx.set_clock_epoch(clock_epoch_);
    return ctx;
}

ActivationKey Executor::compute_activation_key(
    const ActivationInput& input) const {
    /* [E-6] K_act = SHA-256(H_code || H_inputs || H_params || H_env) */

    /* H_code: SHA-256 of the kernel source code */
    std::string h_code = sha256_hex(input.kernel_source);

    /* H_inputs: SHA-256 of deterministically-serialized input values */
    std::string sorted_inputs = sort_json_keys(input.input_json);
    std::string h_inputs = sha256_hex(sorted_inputs);

    /* H_params: SHA-256 of deterministically-serialized parameters */
    std::string sorted_params = sort_json_keys(input.params_json);
    std::string h_params = sha256_hex(sorted_params);

    /* H_env: SHA-256 of the host environment descriptor */
    std::string env_desc = build_env_descriptor();
    std::string h_env = sha256_hex(env_desc);

    /* Concatenate the four component hashes and hash again */
    std::string combined = h_code + h_inputs + h_params + h_env;
    ActivationKey key;
    key.digest = sha256_hex(combined);
    return key;
}

std::optional<ActivationResult> Executor::check_resource_limits(
    const ActivationOutput& output) {
    /* Check output size limit */
    size_t output_bytes = output.output_json.size();
    size_t max_output_bytes = static_cast<size_t>(limits_.output_mb) * 1024 * 1024;
    if (output_bytes > max_output_bytes) {
        std::ostringstream msg;
        msg << "Output size " << output_bytes
            << " bytes exceeds limit of " << max_output_bytes
            << " bytes (" << limits_.output_mb << " MB)";
        return ActivationResult::failure(error::RESOURCE_LIMIT, msg.str());
    }

    return std::nullopt;
}

ActivationResult Executor::execute(const ActivationInput& input) {
    stats_.total_activations++;
    auto start_time = std::chrono::steady_clock::now();

    /* Step 1: Compute activation key */
    ActivationKey key = compute_activation_key(input);

    /* Step 2: Query cache ([E-5].2) */
    auto cached = cache_.lookup(key);
    if (cached.has_value()) {
        /* Step 3: Cache hit ([E-5].3) */
        stats_.cache_hits++;
        auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::steady_clock::now() - start_time).count();
        stats_.total_execution_ms += static_cast<uint64_t>(elapsed);

        ActivationOutput out;
        out.output_json = cached.value();
        out.from_cache = true;
        return ActivationResult::success(std::move(out));
    }

    /* Step 4: Cache miss – execute the kernel ([E-5].4) */
    stats_.cache_misses++;

    ActivationOutput out;
    out.from_cache = false;

    try {
        /* Create a fresh, isolated GlueContext ([E-1]) */
        auto ctx = create_context();

        /* Build the capability call */
        glue::GlueContext::CapabilityCall call;
        call.kernel_path = input.kernel_path;
        call.capability_name = input.capability_name;
        call.input_json = input.input_json;
        call.params_json = input.params_json;

        /* Invoke the capability */
        auto kernel_output = ctx.invoke_capability(call);

        if (!kernel_output.error.ok()) {
            /* Map Glue errors to executor error codes */
            std::string err_code;
            switch (kernel_output.error.error) {
                case glue::GlueError::SandboxViolation:
                    err_code = error::SANDBOX_VIOLATION;
                    break;
                case glue::GlueError::ResourceLimit:
                    err_code = error::RESOURCE_LIMIT;
                    break;
                case glue::GlueError::KernelLoadFailed:
                case glue::GlueError::KernelAdvertiseFailed:
                case glue::GlueError::CapabilityNotFound:
                case glue::GlueError::InternalError:
                default:
                    err_code = error::KERNEL_RUNTIME;
                    break;
            }

            stats_.errors++;
            return ActivationResult::failure(
                err_code, kernel_output.error.message);
        }

        out.output_json = kernel_output.raw_json;

        /* Check resource limits ([E-2], [E-3]) */
        auto limit_result = check_resource_limits(out);
        if (limit_result.has_value()) {
            stats_.errors++;
            return limit_result.value();
        }

    } catch (const std::exception& e) {
        stats_.errors++;
        return ActivationResult::failure(
            error::KERNEL_RUNTIME,
            std::string("Executor exception: ") + e.what());
    }

    /* Step 5: Store result in cache ([E-5].4) */
    cache_.store(key, out.output_json,
                 input.kernel_path, input.capability_name);

    auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::steady_clock::now() - start_time).count();
    stats_.total_execution_ms += static_cast<uint64_t>(elapsed);

    return ActivationResult::success(std::move(out));
}

} // namespace executor
} // namespace doxtk
