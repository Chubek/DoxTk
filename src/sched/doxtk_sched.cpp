#include "doxtk_sched.hpp"

#include <algorithm>
#include <chrono>
#include <fstream>
#include <iomanip>
#include <sstream>
#include <stdexcept>

namespace doxtk {
namespace sched {

/* ========================================================================
 * CapabilityRegistry
 * ======================================================================== */

bool CapabilityRegistry::register_capability(CapabilityEntry entry) {
    if (entries_.find(entry.name) != entries_.end()) {
        return false;
    }
    entries_[entry.name] = std::move(entry);
    return true;
}

const CapabilityEntry* CapabilityRegistry::lookup(
    const std::string& name) const {
    auto it = entries_.find(name);
    if (it == entries_.end()) return nullptr;
    return &it->second;
}

bool CapabilityRegistry::has_capability(
    const std::string& name, const std::string& version) const {
    const auto* entry = lookup(name);
    if (!entry) return false;
    return entry->version == version;
}

void CapabilityRegistry::clear() {
    entries_.clear();
}

bool CapabilityRegistry::load_from_json(
    const std::string& json, std::string* error_out) {
    /* Parse a JSON array of capability objects:
     * [
     *   {
     *     "name": "style.resolve",
     *     "version": "1.0.0",
     *     "description": "...",
     *     "input_schema": {...},
     *     "output_schema": {...},
     *     "services": ["doxtk.json"]
     *   }
     * ]
     */
    auto val = doxtk::glue::JsonUtil::decode(json);
    if (!val) {
        if (error_out) *error_out = "Failed to parse JSON";
        return false;
    }

    if (val->type != qamrpp::Value::ARRAY) {
        if (error_out) *error_out = "Expected JSON array at top level";
        return false;
    }

    for (const auto& entry_val : val->array_entries) {
        if (!entry_val || entry_val->type != qamrpp::Value::TABLE) {
            if (error_out) *error_out = "Expected object in capabilities array";
            return false;
        }

        CapabilityEntry entry;
        auto* t = entry_val.get();

        /* name (required) */
        auto name_it = std::find_if(t->table_entries.begin(), t->table_entries.end(),
            [](const auto& kv) {
                return kv.first->type == qamrpp::Value::STRING &&
                       kv.first->string_value == "name";
            });
        if (name_it == t->table_entries.end()) {
            if (error_out) *error_out = "Capability missing 'name' field";
            return false;
        }
        entry.name = name_it->second->string_value;

        /* version (required) */
        auto ver_it = std::find_if(t->table_entries.begin(), t->table_entries.end(),
            [](const auto& kv) {
                return kv.first->type == qamrpp::Value::STRING &&
                       kv.first->string_value == "version";
            });
        if (ver_it == t->table_entries.end()) {
            if (error_out) *error_out = "Capability '" + entry.name + "' missing 'version'";
            return false;
        }
        entry.version = ver_it->second->string_value;

        /* description */
        auto desc_it = std::find_if(t->table_entries.begin(), t->table_entries.end(),
            [](const auto& kv) {
                return kv.first->type == qamrpp::Value::STRING &&
                       kv.first->string_value == "description";
            });
        if (desc_it != t->table_entries.end()) {
            entry.description = desc_it->second->string_value;
        }

        /* input_schema */
        auto in_it = std::find_if(t->table_entries.begin(), t->table_entries.end(),
            [](const auto& kv) {
                return kv.first->type == qamrpp::Value::STRING &&
                       kv.first->string_value == "input_schema";
            });
        if (in_it != t->table_entries.end()) {
            entry.input_schema_json = doxtk::glue::JsonUtil::encode(in_it->second);
        }

        /* output_schema */
        auto out_it = std::find_if(t->table_entries.begin(), t->table_entries.end(),
            [](const auto& kv) {
                return kv.first->type == qamrpp::Value::STRING &&
                       kv.first->string_value == "output_schema";
            });
        if (out_it != t->table_entries.end()) {
            entry.output_schema_json = doxtk::glue::JsonUtil::encode(out_it->second);
        }

        /* services */
        auto svc_it = std::find_if(t->table_entries.begin(), t->table_entries.end(),
            [](const auto& kv) {
                return kv.first->type == qamrpp::Value::STRING &&
                       kv.first->string_value == "services";
            });
        if (svc_it != t->table_entries.end() &&
            svc_it->second->type == qamrpp::Value::ARRAY) {
            for (const auto& svc : svc_it->second->array_entries) {
                if (svc && svc->type == qamrpp::Value::STRING) {
                    entry.required_services.push_back(svc->string_value);
                }
            }
        }

        register_capability(std::move(entry));
    }

    return true;
}

/* ========================================================================
 * KernelRegistry
 * ======================================================================== */

bool KernelRegistry::register_kernel(KernelEntry entry) {
    /* Check for duplicate kernel path */
    for (const auto& existing : kernels_) {
        if (existing.kernel_path == entry.kernel_path) {
            return false;
        }
    }

    size_t idx = kernels_.size();
    kernels_.push_back(std::move(entry));

    /* Index by capability name */
    for (const auto& cap_name : kernels_[idx].provided_capabilities) {
        if (capability_index_.find(cap_name) != capability_index_.end()) {
            /* Capability already provided by another kernel – keep first */
            continue;
        }
        capability_index_[cap_name] = idx;
    }

    return true;
}

const KernelEntry* KernelRegistry::resolve(
    const std::string& capability_name) const {
    auto it = capability_index_.find(capability_name);
    if (it == capability_index_.end()) return nullptr;
    if (it->second >= kernels_.size()) return nullptr;
    return &kernels_[it->second];
}

void KernelRegistry::clear() {
    kernels_.clear();
    capability_index_.clear();
}

bool KernelRegistry::load_from_json(
    const std::string& json, std::string* error_out) {
    /* Parse a JSON array of kernel objects:
     * [
     *   {
     *     "name": "style-resolve",
     *     "path": "kernels/style-resolve.lua",
     *     "capabilities": ["style.resolve"]
     *   }
     * ]
     */
    auto val = doxtk::glue::JsonUtil::decode(json);
    if (!val) {
        if (error_out) *error_out = "Failed to parse JSON";
        return false;
    }

    if (val->type != qamrpp::Value::ARRAY) {
        if (error_out) *error_out = "Expected JSON array at top level";
        return false;
    }

    for (const auto& entry_val : val->array_entries) {
        if (!entry_val || entry_val->type != qamrpp::Value::TABLE) {
            if (error_out) *error_out = "Expected object in kernels array";
            return false;
        }

        KernelEntry entry;
        auto* t = entry_val.get();

        /* name */
        auto name_it = std::find_if(t->table_entries.begin(), t->table_entries.end(),
            [](const auto& kv) {
                return kv.first->type == qamrpp::Value::STRING &&
                       kv.first->string_value == "name";
            });
        if (name_it != t->table_entries.end()) {
            entry.kernel_name = name_it->second->string_value;
        }

        /* path (required) */
        auto path_it = std::find_if(t->table_entries.begin(), t->table_entries.end(),
            [](const auto& kv) {
                return kv.first->type == qamrpp::Value::STRING &&
                       kv.first->string_value == "path";
            });
        if (path_it == t->table_entries.end()) {
            if (error_out) *error_out = "Kernel missing 'path' field";
            return false;
        }
        entry.kernel_path = path_it->second->string_value;

        /* capabilities */
        auto caps_it = std::find_if(t->table_entries.begin(), t->table_entries.end(),
            [](const auto& kv) {
                return kv.first->type == qamrpp::Value::STRING &&
                       kv.first->string_value == "capabilities";
            });
        if (caps_it != t->table_entries.end() &&
            caps_it->second->type == qamrpp::Value::ARRAY) {
            for (const auto& cap : caps_it->second->array_entries) {
                if (cap && cap->type == qamrpp::Value::STRING) {
                    entry.provided_capabilities.push_back(cap->string_value);
                }
            }
        }

        register_kernel(std::move(entry));
    }

    return true;
}

/* ========================================================================
 * Plan
 * ======================================================================== */

Plan& Plan::set_id(const std::string& id) {
    if (sealed_) return *this;
    id_ = id;
    return *this;
}

std::string Plan::add_node(PlanNode node) {
    if (sealed_) return "";
    if (node.id.empty()) return "";

    if (nodes_.find(node.id) != nodes_.end()) {
        return "";  /* duplicate id */
    }

    std::string nid = node.id;
    nodes_[nid] = std::move(node);
    return nid;
}

bool Plan::remove_node(const std::string& id) {
    if (sealed_) return false;
    auto it = nodes_.find(id);
    if (it == nodes_.end()) return false;

    /* Remove edges from other nodes that depend on this one */
    for (auto& [nid, node] : nodes_) {
        node.dependencies.erase(
            std::remove(node.dependencies.begin(),
                        node.dependencies.end(), id),
            node.dependencies.end());
    }

    nodes_.erase(it);
    return true;
}

bool Plan::add_edge(const std::string& upstream_id,
                    const std::string& downstream_id) {
    if (sealed_) return false;
    if (!has_node(upstream_id) || !has_node(downstream_id)) return false;
    if (upstream_id == downstream_id) return false;

    auto& downstream = nodes_[downstream_id];

    /* Avoid duplicate edges */
    if (std::find(downstream.dependencies.begin(),
                  downstream.dependencies.end(),
                  upstream_id) != downstream.dependencies.end()) {
        return false;
    }

    downstream.dependencies.push_back(upstream_id);
    return true;
}

const PlanNode* Plan::get_node(const std::string& id) const {
    auto it = nodes_.find(id);
    if (it == nodes_.end()) return nullptr;
    return &it->second;
}

bool Plan::has_node(const std::string& id) const {
    return nodes_.find(id) != nodes_.end();
}

/* ========================================================================
 * Plan: Cycle Detection ([S-4].1)
 * ======================================================================== */

bool Plan::has_cycle_dfs(
    const std::string& node_id,
    std::unordered_map<std::string, Plan::VisitState>& state) const {
    state[node_id] = VisitState::Visiting;

    auto it = nodes_.find(node_id);
    if (it == nodes_.end()) {
        state[node_id] = VisitState::Visited;
        return false;
    }

    for (const auto& dep_id : it->second.dependencies) {
        auto s = state.find(dep_id);
        if (s == state.end()) {
            if (has_cycle_dfs(dep_id, state)) return true;
        } else if (s->second == VisitState::Visiting) {
            return true;  /* back edge = cycle */
        }
    }

    state[node_id] = VisitState::Visited;
    return false;
}

/* ========================================================================
 * Plan: Type Checking ([S-4].2)
 * ======================================================================== */

PlanValidationResult Plan::check_types(
    const CapabilityRegistry& cap_registry) const {
    /* For each node, verify that its declared capability exists.
     * Full type-checking of input/output schemas would require schema
     * validation logic; here we verify capability registration and
     * version match. */
    for (const auto& [nid, node] : nodes_) {
        const auto* cap = cap_registry.lookup(node.capability_name);
        if (!cap) {
            return PlanValidationResult::fail(
                error::PLAN_TYPE,
                "Node '" + nid + "' references unknown capability '" +
                node.capability_name + "'");
        }
        if (!node.capability_version.empty() &&
            cap->version != node.capability_version) {
            return PlanValidationResult::fail(
                error::PLAN_TYPE,
                "Node '" + nid + "' requests capability '" +
                node.capability_name + "' version " +
                node.capability_version + " but registry has version " +
                cap->version);
        }
    }

    return PlanValidationResult::ok();
}

/* ========================================================================
 * Plan: Capability Resolution ([S-4].3)
 * ======================================================================== */

PlanValidationResult Plan::resolve_capabilities(
    const CapabilityRegistry& cap_registry,
    const KernelRegistry& kernel_registry) {
    for (auto& [nid, node] : nodes_) {
        /* Verify capability exists in registry */
        const auto* cap = cap_registry.lookup(node.capability_name);
        if (!cap) {
            return PlanValidationResult::fail(
                error::PLAN_UNRESOLVED,
                "Node '" + nid + "' requires capability '" +
                node.capability_name + "' which is not registered");
        }

        /* Resolve to a kernel */
        const auto* kernel = kernel_registry.resolve(node.capability_name);
        if (!kernel) {
            return PlanValidationResult::fail(
                error::PLAN_UNRESOLVED,
                "Node '" + nid + "' requires capability '" +
                node.capability_name + "' but no kernel provides it");
        }

        node.resolved_kernel_path = kernel->kernel_path;
    }

    return PlanValidationResult::ok();
}

/* ========================================================================
 * Plan: Compile (validate + seal)
 * ======================================================================== */

PlanValidationResult Plan::compile(
    const CapabilityRegistry& cap_registry,
    const KernelRegistry& kernel_registry) {
    if (sealed_) {
        return PlanValidationResult::fail(
            "ERR_PLAN_INTERNAL", "Plan is already sealed");
    }

    /* Step 1: Cycle Detection ([S-4].1) */
    std::unordered_map<std::string, VisitState> state;
    for (const auto& [nid, node] : nodes_) {
        if (state.find(nid) == state.end()) {
            if (has_cycle_dfs(nid, state)) {
                return PlanValidationResult::fail(
                    error::PLAN_CYCLE,
                    "Cycle detected in plan '" + id_ +
                    "': node '" + nid + "' is part of a cycle");
            }
        }
    }

    /* Step 2: Type Checking ([S-4].2) */
    auto type_result = check_types(cap_registry);
    if (!type_result.valid) {
        return type_result;
    }

    /* Step 3: Capability Resolution ([S-4].3) */
    auto resolve_result = resolve_capabilities(cap_registry, kernel_registry);
    if (!resolve_result.valid) {
        return resolve_result;
    }

    sealed_ = true;
    return PlanValidationResult::ok();
}

/* ========================================================================
 * Plan: Topological Order
 * ======================================================================== */

void Plan::topo_dfs(
    const std::string& node_id,
    std::unordered_map<std::string, Plan::VisitState>& state,
    std::vector<std::string>& order) const {
    state[node_id] = VisitState::Visiting;

    auto it = nodes_.find(node_id);
    if (it != nodes_.end()) {
        for (const auto& dep_id : it->second.dependencies) {
            if (state.find(dep_id) == state.end() ||
                state[dep_id] == VisitState::Unvisited) {
                topo_dfs(dep_id, state, order);
            }
        }
    }

    state[node_id] = VisitState::Visited;
    order.push_back(node_id);
}

std::vector<std::string> Plan::topological_order() const {
    std::vector<std::string> order;
    if (!sealed_) return order;

    std::unordered_map<std::string, VisitState> state;
    for (const auto& [nid, node] : nodes_) {
        state[nid] = VisitState::Unvisited;
    }

    for (const auto& [nid, node] : nodes_) {
        if (state[nid] == VisitState::Unvisited) {
            topo_dfs(nid, state, order);
        }
    }

    return order;
}

/* ========================================================================
 * Plan: Serialization
 * ======================================================================== */

std::string Plan::to_json() const {
    std::ostringstream oss;
    oss << "{";

    /* id */
    oss << "\"id\":";
    /* manual JSON escape for id */
    oss << '"';
    for (char ch : id_) {
        switch (ch) {
            case '"': oss << "\\\""; break;
            case '\\': oss << "\\\\"; break;
            case '\n': oss << "\\n"; break;
            default: oss << ch; break;
        }
    }
    oss << '"';

    oss << ",\"sealed\":" << (sealed_ ? "true" : "false");

    /* nodes */
    oss << ",\"nodes\":{";
    bool first_node = true;
    for (const auto& [nid, node] : nodes_) {
        if (!first_node) oss << ",";
        first_node = false;

        oss << '"';
        for (char ch : nid) {
            switch (ch) {
                case '"': oss << "\\\""; break;
                case '\\': oss << "\\\\"; break;
                default: oss << ch; break;
            }
        }
        oss << '"' << ":";

        oss << "{";
        oss << "\"id\":\"";
        for (char ch : node.id) {
            switch (ch) {
                case '"': oss << "\\\""; break;
                case '\\': oss << "\\\\"; break;
                default: oss << ch; break;
            }
        }
        oss << '"';

        oss << ",\"capability_name\":\"";
        for (char ch : node.capability_name) {
            switch (ch) {
                case '"': oss << "\\\""; break;
                case '\\': oss << "\\\\"; break;
                default: oss << ch; break;
            }
        }
        oss << '"';

        oss << ",\"capability_version\":\"";
        for (char ch : node.capability_version) {
            switch (ch) {
                case '"': oss << "\\\""; break;
                case '\\': oss << "\\\\"; break;
                default: oss << ch; break;
            }
        }
        oss << '"';

        oss << ",\"resolved_kernel_path\":\"";
        for (char ch : node.resolved_kernel_path) {
            switch (ch) {
                case '"': oss << "\\\""; break;
                case '\\': oss << "\\\\"; break;
                default: oss << ch; break;
            }
        }
        oss << '"';

        oss << ",\"dependencies\":[";
        for (size_t i = 0; i < node.dependencies.size(); ++i) {
            if (i > 0) oss << ",";
            oss << '"';
            for (char ch : node.dependencies[i]) {
                switch (ch) {
                    case '"': oss << "\\\""; break;
                    case '\\': oss << "\\\\"; break;
                    default: oss << ch; break;
                }
            }
            oss << '"';
        }
        oss << "]";

        oss << "}";
    }
    oss << "}";

    oss << "}";
    return oss.str();
}

std::optional<Plan> Plan::from_json(
    const std::string& json, std::string* error_out) {
    auto val = doxtk::glue::JsonUtil::decode(json);
    if (!val || val->type != qamrpp::Value::TABLE) {
        if (error_out) *error_out = "Failed to parse Plan JSON";
        return std::nullopt;
    }

    Plan plan;
    auto* t = val.get();

    /* id */
    auto id_it = std::find_if(t->table_entries.begin(), t->table_entries.end(),
        [](const auto& kv) {
            return kv.first->type == qamrpp::Value::STRING &&
                   kv.first->string_value == "id";
        });
    if (id_it != t->table_entries.end()) {
        plan.set_id(id_it->second->string_value);
    }

    /* nodes */
    auto nodes_it = std::find_if(t->table_entries.begin(), t->table_entries.end(),
        [](const auto& kv) {
            return kv.first->type == qamrpp::Value::STRING &&
                   kv.first->string_value == "nodes";
        });
    if (nodes_it != t->table_entries.end() &&
        nodes_it->second->type == qamrpp::Value::TABLE) {
        for (const auto& kv : nodes_it->second->table_entries) {
            if (!kv.second || kv.second->type != qamrpp::Value::TABLE) continue;

            PlanNode node;
            node.id = kv.first->string_value;
            auto* nt = kv.second.get();

            auto cap_it = std::find_if(nt->table_entries.begin(), nt->table_entries.end(),
                [](const auto& ekv) {
                    return ekv.first->type == qamrpp::Value::STRING &&
                           ekv.first->string_value == "capability_name";
                });
            if (cap_it != nt->table_entries.end()) {
                node.capability_name = cap_it->second->string_value;
            }

            auto ver_it = std::find_if(nt->table_entries.begin(), nt->table_entries.end(),
                [](const auto& ekv) {
                    return ekv.first->type == qamrpp::Value::STRING &&
                           ekv.first->string_value == "capability_version";
                });
            if (ver_it != nt->table_entries.end()) {
                node.capability_version = ver_it->second->string_value;
            }

            auto path_it = std::find_if(nt->table_entries.begin(), nt->table_entries.end(),
                [](const auto& ekv) {
                    return ekv.first->type == qamrpp::Value::STRING &&
                           ekv.first->string_value == "resolved_kernel_path";
                });
            if (path_it != nt->table_entries.end()) {
                node.resolved_kernel_path = path_it->second->string_value;
            }

            auto deps_it = std::find_if(nt->table_entries.begin(), nt->table_entries.end(),
                [](const auto& ekv) {
                    return ekv.first->type == qamrpp::Value::STRING &&
                           ekv.first->string_value == "dependencies";
                });
            if (deps_it != nt->table_entries.end() &&
                deps_it->second->type == qamrpp::Value::ARRAY) {
                for (const auto& dep : deps_it->second->array_entries) {
                    if (dep && dep->type == qamrpp::Value::STRING) {
                        node.dependencies.push_back(dep->string_value);
                    }
                }
            }

            plan.add_node(std::move(node));
        }
    }

    return plan;
}

/* ========================================================================
 * Scheduler
 * ======================================================================== */

Scheduler::Scheduler(std::string kernel_base_path,
                     std::string env_descriptor)
    : executor_(std::move(kernel_base_path), std::move(env_descriptor)) {}

std::shared_ptr<Plan> Scheduler::new_plan() {
    return std::make_shared<Plan>();
}

std::string Scheduler::next_node_id() {
    return "node_" + std::to_string(++node_counter_);
}

std::string Scheduler::add_node(
    std::shared_ptr<Plan> plan,
    const std::string& capability_name,
    const std::string& input_json,
    const std::string& params_json) {
    if (!plan) return "";

    /* Look up the capability to get its version */
    std::string version;
    const auto* cap = cap_registry_.lookup(capability_name);
    if (cap) {
        version = cap->version;
    }

    PlanNode node;
    node.id = next_node_id();
    node.capability_name = capability_name;
    node.capability_version = version;
    node.input_json = input_json;
    node.params_json = params_json;

    return plan->add_node(std::move(node));
}

PlanValidationResult Scheduler::compile(std::shared_ptr<Plan> plan) {
    if (!plan) {
        return PlanValidationResult::fail(
            "ERR_PLAN_INTERNAL", "Null plan pointer");
    }
    return plan->compile(cap_registry_, kernel_registry_);
}

BuildResult Scheduler::execute(std::shared_ptr<Plan> plan) {
    if (!plan) {
        return BuildResult::failure(
            "ERR_PLAN_INTERNAL", "Null plan pointer");
    }

    if (!plan->is_sealed()) {
        return BuildResult::failure(
            "ERR_PLAN_INTERNAL", "Plan is not compiled/sealed");
    }

    BuildResult build_result = BuildResult::success();
    std::unordered_map<std::string, std::string> node_outputs;

    /* Execute nodes in topological order */
    auto order = plan->topological_order();
    for (const auto& node_id : order) {
        const auto* node = plan->get_node(node_id);
        if (!node) {
            return BuildResult::failure(
                "ERR_PLAN_INTERNAL",
                "Node '" + node_id + "' not found in plan during execution");
        }

        /* Build the input JSON by combining upstream outputs */
        std::ostringstream combined_input;
        combined_input << "{";
        if (!node->input_json.empty() && node->input_json != "{}") {
            /* Strip the outer braces and include the inner content */
            std::string inner = node->input_json;
            if (inner.size() >= 2 && inner.front() == '{' && inner.back() == '}') {
                inner = inner.substr(1, inner.size() - 2);
            }
            combined_input << inner;
        }

        /* Append upstream node outputs */
        bool need_comma = !node->input_json.empty() && node->input_json != "{}";
        for (const auto& dep_id : node->dependencies) {
            auto out_it = node_outputs.find(dep_id);
            if (out_it != node_outputs.end()) {
                if (need_comma) combined_input << ",";
                combined_input << "\"" << dep_id << "\":" << out_it->second;
                need_comma = true;
            }
        }
        combined_input << "}";

        /* Read the kernel source */
        std::string kernel_path = node->resolved_kernel_path;
        std::string kernel_source;
        {
            std::ifstream kf(kernel_path);
            if (!kf.is_open()) {
                return BuildResult::failure(
                    "ERR_KERNEL_RUNTIME",
                    "Cannot open kernel file: " + kernel_path);
            }
            std::ostringstream kss;
            kss << kf.rdbuf();
            kernel_source = kss.str();
        }

        /* Build the activation input */
        executor::ActivationInput input;
        input.kernel_path = kernel_path;
        input.kernel_source = kernel_source;
        input.capability_name = node->capability_name;
        input.input_json = combined_input.str();
        input.params_json = node->params_json;

        /* Execute through the executor */
        auto result = executor_.execute(input);

        if (!result.ok) {
            build_result.ok = false;
            build_result.error_code = result.error_code;
            build_result.error_message = "Node '" + node_id + "': " +
                                         result.error_message;
            return build_result;
        }

        node_outputs[node_id] = result.output.output_json;

        if (result.output.from_cache) {
            build_result.cache_hits++;
        } else {
            build_result.cache_misses++;
        }
    }

    build_result.node_outputs = std::move(node_outputs);
    return build_result;
}

void Scheduler::set_limits(const executor::ResourceLimits& limits) {
    executor_.set_limits(limits);
}

void Scheduler::set_clock_epoch(int64_t epoch) {
    executor_.set_clock_epoch(epoch);
}

void Scheduler::reset_stats() {
    executor_.reset_stats();
}

/* ========================================================================
 * LschedAPI
 * ======================================================================== */

LschedAPI::LschedAPI(Scheduler& scheduler)
    : scheduler_(scheduler) {}

int LschedAPI::lua_new_plan() {
    std::lock_guard<std::mutex> lock(mutex_);
    auto plan = scheduler_.new_plan();
    int handle = next_handle_++;
    plans_[handle] = plan;
    return handle;
}

int LschedAPI::lua_add_node() {
    /* Args: plan_handle, capability_name, input_json, params_json
     * Returns: node_id string (pushed to Lua stack) */
    /* This is called from Lua; the actual argument extraction happens
     * in the Lua binding wrapper. */
    std::lock_guard<std::mutex> lock(mutex_);
    /* Placeholder – actual implementation is in register_with */
    return 0;
}

int LschedAPI::lua_compile() {
    std::lock_guard<std::mutex> lock(mutex_);
    /* Placeholder – actual implementation is in register_with */
    return 0;
}

int LschedAPI::lua_execute() {
    std::lock_guard<std::mutex> lock(mutex_);
    /* Placeholder – actual implementation is in register_with */
    return 0;
}

bool LschedAPI::register_with(qamrpp::Context& ctx) {
    /* Create the lsched table on the Lua context's globals.
     * Each API function is a C++ lambda bound via QaMRpp. */

    auto lsched_table = qamrpp::Value::make_table();

    /* lsched.new_plan() -> plan_handle */
    auto new_plan_fn = std::make_shared<qamrpp::Value>(
        qamrpp::Value::Function{
            [this](qamrpp::Context& /*ctx*/,
                   const std::vector<qamrpp::ValuePtr>& /*args*/)
                -> qamrpp::ValuePtr {
                int handle = lua_new_plan();
                return std::make_shared<qamrpp::Value>(
                    static_cast<int64_t>(handle));
            }
        });

    /* lsched.add_node(plan_handle, capability_name, input_json, params_json)
     *   -> node_id */
    auto add_node_fn = std::make_shared<qamrpp::Value>(
        qamrpp::Value::Function{
            [this](qamrpp::Context& /*ctx*/,
                   const std::vector<qamrpp::ValuePtr>& args)
                -> qamrpp::ValuePtr {
                if (args.size() < 4) {
                    auto err = qamrpp::Value::make_table();
                    err->table_entries.push_back({
                        std::make_shared<qamrpp::Value>("ok"),
                        std::make_shared<qamrpp::Value>(false)
                    });
                    err->table_entries.push_back({
                        std::make_shared<qamrpp::Value>("error"),
                        std::make_shared<qamrpp::Value>(
                            "lsched.add_node requires 4 arguments: "
                            "plan_handle, capability_name, input_json, params_json")
                    });
                    return err;
                }

                int handle = static_cast<int>(args[0]->int_value);
                std::string cap_name = args[1]->string_value;
                std::string input_json = args[2]->string_value;
                std::string params_json = args[3]->string_value;

                std::lock_guard<std::mutex> lock(mutex_);
                auto it = plans_.find(handle);
                if (it == plans_.end()) {
                    auto err = qamrpp::Value::make_table();
                    err->table_entries.push_back({
                        std::make_shared<qamrpp::Value>("ok"),
                        std::make_shared<qamrpp::Value>(false)
                    });
                    err->table_entries.push_back({
                        std::make_shared<qamrpp::Value>("error"),
                        std::make_shared<qamrpp::Value>(
                            "Invalid plan handle: " + std::to_string(handle))
                    });
                    return err;
                }

                std::string node_id = scheduler_.add_node(
                    it->second, cap_name, input_json, params_json);

                if (node_id.empty()) {
                    auto err = qamrpp::Value::make_table();
                    err->table_entries.push_back({
                        std::make_shared<qamrpp::Value>("ok"),
                        std::make_shared<qamrpp::Value>(false)
                    });
                    err->table_entries.push_back({
                        std::make_shared<qamrpp::Value>("error"),
                        std::make_shared<qamrpp::Value>(
                            "Failed to add node to plan")
                    });
                    return err;
                }

                auto result = qamrpp::Value::make_table();
                result->table_entries.push_back({
                    std::make_shared<qamrpp::Value>("ok"),
                    std::make_shared<qamrpp::Value>(true)
                });
                result->table_entries.push_back({
                    std::make_shared<qamrpp::Value>("node_id"),
                    std::make_shared<qamrpp::Value>(node_id)
                });
                return result;
            }
        });

    /* lsched.compile(plan_handle) -> { ok, error } */
    auto compile_fn = std::make_shared<qamrpp::Value>(
        qamrpp::Value::Function{
            [this](qamrpp::Context& /*ctx*/,
                   const std::vector<qamrpp::ValuePtr>& args)
                -> qamrpp::ValuePtr {
                if (args.empty()) {
                    auto err = qamrpp::Value::make_table();
                    err->table_entries.push_back({
                        std::make_shared<qamrpp::Value>("ok"),
                        std::make_shared<qamrpp::Value>(false)
                    });
                    err->table_entries.push_back({
                        std::make_shared<qamrpp::Value>("error"),
                        std::make_shared<qamrpp::Value>(
                            "lsched.compile requires plan_handle")
                    });
                    return err;
                }

                int handle = static_cast<int>(args[0]->int_value);

                std::lock_guard<std::mutex> lock(mutex_);
                auto it = plans_.find(handle);
                if (it == plans_.end()) {
                    auto err = qamrpp::Value::make_table();
                    err->table_entries.push_back({
                        std::make_shared<qamrpp::Value>("ok"),
                        std::make_shared<qamrpp::Value>(false)
                    });
                    err->table_entries.push_back({
                        std::make_shared<qamrpp::Value>("error"),
                        std::make_shared<qamrpp::Value>(
                            "Invalid plan handle: " + std::to_string(handle))
                    });
                    return err;
                }

                auto result = scheduler_.compile(it->second);

                auto lua_result = qamrpp::Value::make_table();
                lua_result->table_entries.push_back({
                    std::make_shared<qamrpp::Value>("ok"),
                    std::make_shared<qamrpp::Value>(result.valid)
                });
                if (!result.valid) {
                    lua_result->table_entries.push_back({
                        std::make_shared<qamrpp::Value>("error_code"),
                        std::make_shared<qamrpp::Value>(result.error_code)
                    });
                    lua_result->table_entries.push_back({
                        std::make_shared<qamrpp::Value>("error"),
                        std::make_shared<qamrpp::Value>(result.error_message)
                    });
                }
                return lua_result;
            }
        });

    /* lsched.execute(plan_handle) -> { ok, error, node_outputs, cache_hits, cache_misses } */
    auto execute_fn = std::make_shared<qamrpp::Value>(
        qamrpp::Value::Function{
            [this](qamrpp::Context& /*ctx*/,
                   const std::vector<qamrpp::ValuePtr>& args)
                -> qamrpp::ValuePtr {
                if (args.empty()) {
                    auto err = qamrpp::Value::make_table();
                    err->table_entries.push_back({
                        std::make_shared<qamrpp::Value>("ok"),
                        std::make_shared<qamrpp::Value>(false)
                    });
                    err->table_entries.push_back({
                        std::make_shared<qamrpp::Value>("error"),
                        std::make_shared<qamrpp::Value>(
                            "lsched.execute requires plan_handle")
                    });
                    return err;
                }

                int handle = static_cast<int>(args[0]->int_value);

                std::lock_guard<std::mutex> lock(mutex_);
                auto it = plans_.find(handle);
                if (it == plans_.end()) {
                    auto err = qamrpp::Value::make_table();
                    err->table_entries.push_back({
                        std::make_shared<qamrpp::Value>("ok"),
                        std::make_shared<qamrpp::Value>(false)
                    });
                    err->table_entries.push_back({
                        std::make_shared<qamrpp::Value>("error"),
                        std::make_shared<qamrpp::Value>(
                            "Invalid plan handle: " + std::to_string(handle))
                    });
                    return err;
                }

                auto build_result = scheduler_.execute(it->second);

                auto lua_result = qamrpp::Value::make_table();
                lua_result->table_entries.push_back({
                    std::make_shared<qamrpp::Value>("ok"),
                    std::make_shared<qamrpp::Value>(build_result.ok)
                });

                if (!build_result.ok) {
                    lua_result->table_entries.push_back({
                        std::make_shared<qamrpp::Value>("error_code"),
                        std::make_shared<qamrpp::Value>(build_result.error_code)
                    });
                    lua_result->table_entries.push_back({
                        std::make_shared<qamrpp::Value>("error"),
                        std::make_shared<qamrpp::Value>(build_result.error_message)
                    });
                } else {
                    lua_result->table_entries.push_back({
                        std::make_shared<qamrpp::Value>("cache_hits"),
                        std::make_shared<qamrpp::Value>(
                            static_cast<int64_t>(build_result.cache_hits))
                    });
                    lua_result->table_entries.push_back({
                        std::make_shared<qamrpp::Value>("cache_misses"),
                        std::make_shared<qamrpp::Value>(
                            static_cast<int64_t>(build_result.cache_misses))
                    });

                    auto outputs_table = qamrpp::Value::make_table();
                    for (const auto& [nid, out_json] : build_result.node_outputs) {
                        outputs_table->table_entries.push_back({
                            std::make_shared<qamrpp::Value>(nid),
                            std::make_shared<qamrpp::Value>(out_json)
                        });
                    }
                    lua_result->table_entries.push_back({
                        std::make_shared<qamrpp::Value>("node_outputs"),
                        outputs_table
                    });
                }

                return lua_result;
            }
        });

    /* Assemble the lsched table */
    lsched_table->table_entries.push_back({
        std::make_shared<qamrpp::Value>("new_plan"), new_plan_fn
    });
    lsched_table->table_entries.push_back({
        std::make_shared<qamrpp::Value>("add_node"), add_node_fn
    });
    lsched_table->table_entries.push_back({
        std::make_shared<qamrpp::Value>("compile"), compile_fn
    });
    lsched_table->table_entries.push_back({
        std::make_shared<qamrpp::Value>("execute"), execute_fn
    });

    /* Install on globals */
    ctx.globals["lsched"] = lsched_table;

    return true;
}

} // namespace sched
} // namespace doxtk
