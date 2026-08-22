#ifndef DOXTK_SCHED_HPP
#define DOXTK_SCHED_HPP

#include <cstdint>
#include <functional>
#include <map>
#include <memory>
#include <mutex>
#include <optional>
#include <set>
#include <sstream>
#include <stdexcept>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <vector>

#include "../executor/doxtk_executor.hpp"
#include "../ir/doxtk_ir.hpp"

namespace doxtk {
namespace sched {

/* ========================================================================
 * Capability Registry Entry
 *
 * Represents a single capability contract as defined in
 * manifests/Capabilities.yaml.  The Sched layer uses this to validate
 * that every node in a plan references a known capability.
 * ======================================================================== */

struct CapabilityEntry {
    std::string name;
    std::string version;
    std::string description;
    /* input/output schemas are stored as JSON strings for validation */
    std::string input_schema_json;
    std::string output_schema_json;
    std::vector<std::string> required_services;

    bool operator==(const CapabilityEntry& other) const {
        return name == other.name && version == other.version;
    }

    bool operator!=(const CapabilityEntry& other) const {
        return !(*this == other);
    }
};

/* ========================================================================
 * Capability Registry
 *
 * In-memory representation of the capability registry.
 * Indexed by capability name for fast lookup during plan validation.
 * ======================================================================== */

class CapabilityRegistry {
public:
    CapabilityRegistry() = default;

    bool register_capability(CapabilityEntry entry);
    const CapabilityEntry* lookup(const std::string& name) const;
    bool has_capability(const std::string& name,
                        const std::string& version) const;
    size_t size() const { return entries_.size(); }
    void clear();
    const std::unordered_map<std::string, CapabilityEntry>& entries() const {
        return entries_;
    }
    bool load_from_json(const std::string& json, std::string* error_out = nullptr);

private:
    std::unordered_map<std::string, CapabilityEntry> entries_;
};

/* ========================================================================
 * Kernel Registry Entry
 * ======================================================================== */

struct KernelEntry {
    std::string kernel_path;
    std::string kernel_name;
    std::vector<std::string> provided_capabilities;

    bool provides(const std::string& cap_name) const {
        return std::find(provided_capabilities.begin(),
                         provided_capabilities.end(),
                         cap_name) != provided_capabilities.end();
    }
};

/* ========================================================================
 * Kernel Registry
 * ======================================================================== */

class KernelRegistry {
public:
    KernelRegistry() = default;

    bool register_kernel(KernelEntry entry);
    const KernelEntry* resolve(const std::string& capability_name) const;
    size_t size() const { return kernels_.size(); }
    void clear();
    bool load_from_json(const std::string& json, std::string* error_out = nullptr);

private:
    std::vector<KernelEntry> kernels_;
    std::unordered_map<std::string, size_t> capability_index_;
};

/* ========================================================================
 * Plan Node ([S-2])
 * ======================================================================== */

struct PlanNode {
    std::string id;
    std::string capability_name;
    std::string capability_version;
    std::string input_json;
    std::string params_json;
    std::vector<std::string> dependencies;
    std::string resolved_kernel_path;

    bool operator==(const PlanNode& other) const {
        return id == other.id &&
               capability_name == other.capability_name &&
               capability_version == other.capability_version &&
               input_json == other.input_json &&
               params_json == other.params_json &&
               dependencies == other.dependencies;
    }

    bool operator!=(const PlanNode& other) const {
        return !(*this == other);
    }
};

/* ========================================================================
 * Plan Validation Result
 * ======================================================================== */

struct PlanValidationResult {
    bool valid = false;
    std::string error_code;
    std::string error_message;

    static PlanValidationResult ok() {
        PlanValidationResult r;
        r.valid = true;
        return r;
    }

    static PlanValidationResult fail(std::string code, std::string msg) {
        PlanValidationResult r;
        r.valid = false;
        r.error_code = std::move(code);
        r.error_message = std::move(msg);
        return r;
    }
};

/* ========================================================================
 * Plan ([S-2])
 * ======================================================================== */

class Plan {
public:
    Plan() = default;

    Plan& set_id(const std::string& id);
    std::string add_node(PlanNode node);
    bool remove_node(const std::string& id);
    bool add_edge(const std::string& upstream_id,
                  const std::string& downstream_id);

    const PlanNode* get_node(const std::string& id) const;
    bool has_node(const std::string& id) const;
    const std::string& id() const { return id_; }
    size_t node_count() const { return nodes_.size(); }
    const std::unordered_map<std::string, PlanNode>& nodes() const {
        return nodes_;
    }

    PlanValidationResult compile(const CapabilityRegistry& cap_registry,
                                  const KernelRegistry& kernel_registry);
    bool is_sealed() const { return sealed_; }
    std::vector<std::string> topological_order() const;

    std::string to_json() const;
    static std::optional<Plan> from_json(const std::string& json,
                                          std::string* error_out = nullptr);

private:
    enum class VisitState { Unvisited, Visiting, Visited };

    bool has_cycle_dfs(const std::string& node_id,
                       std::unordered_map<std::string, VisitState>& state) const;

    PlanValidationResult check_types(const CapabilityRegistry& cap_registry) const;

    PlanValidationResult resolve_capabilities(
        const CapabilityRegistry& cap_registry,
        const KernelRegistry& kernel_registry);

    void topo_dfs(const std::string& node_id,
                  std::unordered_map<std::string, VisitState>& state,
                  std::vector<std::string>& order) const;

    std::string id_;
    std::unordered_map<std::string, PlanNode> nodes_;
    bool sealed_ = false;
};

/* ========================================================================
 * Build Result
 * ======================================================================== */

struct BuildResult {
    bool ok = false;
    std::string error_code;
    std::string error_message;
    std::unordered_map<std::string, std::string> node_outputs;
    uint64_t cache_hits = 0;
    uint64_t cache_misses = 0;

    static BuildResult success() {
        BuildResult r;
        r.ok = true;
        return r;
    }

    static BuildResult failure(std::string code, std::string msg) {
        BuildResult r;
        r.ok = false;
        r.error_code = std::move(code);
        r.error_message = std::move(msg);
        return r;
    }
};

/* ========================================================================
 * Scheduler ([S-1] through [S-4])
 * ======================================================================== */

class Scheduler {
public:
    explicit Scheduler(std::string kernel_base_path = "kernel/",
                       std::string env_descriptor = "");

    Scheduler(const Scheduler&) = delete;
    Scheduler& operator=(const Scheduler&) = delete;

    CapabilityRegistry& capability_registry() { return cap_registry_; }
    const CapabilityRegistry& capability_registry() const { return cap_registry_; }

    KernelRegistry& kernel_registry() { return kernel_registry_; }
    const KernelRegistry& kernel_registry() const { return kernel_registry_; }

    executor::Executor& executor() { return executor_; }
    const executor::Executor& executor() const { return executor_; }

    std::shared_ptr<Plan> new_plan();

    std::string add_node(std::shared_ptr<Plan> plan,
                         const std::string& capability_name,
                         const std::string& input_json,
                         const std::string& params_json);

    PlanValidationResult compile(std::shared_ptr<Plan> plan);

    BuildResult execute(std::shared_ptr<Plan> plan);

    void set_limits(const executor::ResourceLimits& limits);
    void set_clock_epoch(int64_t epoch);

    const executor::ExecutorStats& stats() const { return executor_.stats(); }
    void reset_stats();

private:
    std::string next_node_id();

    CapabilityRegistry cap_registry_;
    KernelRegistry kernel_registry_;
    executor::Executor executor_;
    uint64_t node_counter_ = 0;
};

/* ========================================================================
 * Error codes (Section 11, Table 4)
 * ======================================================================== */

namespace error {
    using executor::error::SANDBOX_VIOLATION;
    using executor::error::RESOURCE_LIMIT;
    using executor::error::KERNEL_RUNTIME;
    using executor::error::IR_INVALID;

    constexpr const char* PLAN_CYCLE      = "ERR_PLAN_CYCLE";
    constexpr const char* PLAN_TYPE       = "ERR_PLAN_TYPE";
    constexpr const char* PLAN_UNRESOLVED = "ERR_PLAN_UNRESOLVED";
} // namespace error

/* ========================================================================
 * lsched Lua API
 * ======================================================================== */

class LschedAPI {
public:
    explicit LschedAPI(Scheduler& scheduler);

    int lua_new_plan();
    int lua_add_node();
    int lua_compile();
    int lua_execute();

    bool register_with(qamrpp::Context& ctx);

    Scheduler& scheduler() { return scheduler_; }

private:
    Scheduler& scheduler_;
    std::unordered_map<int, std::shared_ptr<Plan>> plans_;
    int next_handle_ = 1;
    std::mutex mutex_;
};

} // namespace sched
} // namespace doxtk

#endif // DOXTK_SCHED_HPP
