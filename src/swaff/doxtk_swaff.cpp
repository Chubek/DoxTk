#include "doxtk_swaff.hpp"

#include <algorithm>
#include <cctype>
#include <fstream>
#include <sstream>

namespace doxtk {
namespace swaff {

/* ========================================================================
 * Forward declarations of frontend subclasses
 * ======================================================================== */

class MarkdownFrontend;
class TeXFrontend;
class RoffFrontend;

/* ========================================================================
 * Frontend base implementation
 * ======================================================================== */

Frontend::Frontend(const FrontendOptions& options)
    : options_(options)
    , scheduler_(options.kernel_base_path) {
    configure_scheduler();
}

void Frontend::configure_scheduler() {
    executor::ResourceLimits limits;
    auto it = options_.config.find("cpu_ms");
    if (it != options_.config.end()) {
        limits.cpu_ms = static_cast<uint32_t>(std::stoul(it->second));
    }
    it = options_.config.find("memory_mb");
    if (it != options_.config.end()) {
        limits.memory_mb = static_cast<uint32_t>(std::stoul(it->second));
    }
    it = options_.config.find("output_mb");
    if (it != options_.config.end()) {
        limits.output_mb = static_cast<uint32_t>(std::stoul(it->second));
    }
    scheduler_.set_limits(limits);

    it = options_.config.find("clock_epoch");
    if (it != options_.config.end()) {
        scheduler_.set_clock_epoch(
            static_cast<int64_t>(std::stoll(it->second)));
    }
}

bool Frontend::load_registries() {
    std::string cap_path = options_.manifests_path + "Capabilities.yaml";
    {
        std::ifstream f(cap_path);
        if (f.is_open()) {
            std::ostringstream oss;
            oss << f.rdbuf();
            std::string cap_json = oss.str();
            if (!cap_json.empty()) {
                std::string error;
                if (!scheduler_.capability_registry().load_from_json(
                        cap_json, &error)) {
                    return false;
                }
            }
        }
    }

    std::string kern_path = options_.manifests_path + "Kernels.yaml";
    {
        std::ifstream f(kern_path);
        if (f.is_open()) {
            std::ostringstream oss;
            oss << f.rdbuf();
            std::string kern_json = oss.str();
            if (!kern_json.empty()) {
                std::string error;
                if (!scheduler_.kernel_registry().load_from_json(
                        kern_json, &error)) {
                    return false;
                }
            }
        }
    }

    return true;
}

FrontendResult Frontend::process() {
    if (!load_registries()) {
        return FrontendResult::failure(
            error::REGISTRY_FAILED,
            "Failed to load registries from " + options_.manifests_path);
    }

    std::shared_ptr<ir::IRGraph> ir_graph;
    try {
        ir_graph = parse_to_ir();
    } catch (const std::exception& e) {
        return FrontendResult::failure(
            error::PARSE_FAILED,
            std::string("Parse error: ") + e.what());
    }

    if (!ir_graph) {
        return FrontendResult::failure(
            error::PARSE_FAILED,
            "Failed to parse source into IR");
    }

    std::shared_ptr<sched::Plan> plan;
    try {
        plan = build_plan(ir_graph);
    } catch (const std::exception& e) {
        return FrontendResult::failure(
            error::PLAN_BUILD_FAILED,
            std::string("Plan build error: ") + e.what());
    }

    if (!plan) {
        return FrontendResult::failure(
            error::PLAN_BUILD_FAILED,
            "Failed to build execution plan");
    }

    sched::BuildResult build_result;
    try {
        build_result = execute_plan(plan);
    } catch (const std::exception& e) {
        return FrontendResult::failure(
            error::EXECUTION_FAILED,
            std::string("Execution error: ") + e.what());
    }

    if (!build_result.ok) {
        auto result = FrontendResult::failure(
            build_result.error_code,
            build_result.error_message);
        result.build_result = build_result;
        return result;
    }

    auto result = FrontendResult::success(ir_graph, plan, build_result);

    for (const auto& [node_id, output_json] : build_result.node_outputs) {
        result.artifacts["node_" + node_id] = output_json;
    }

    if (!options_.output_path.empty()) {
        std::string primary = extract_artifact(build_result, "root");
        if (!primary.empty()) {
            std::ofstream out(options_.output_path, std::ios::binary);
            out.write(primary.data(),
                      static_cast<std::streamsize>(primary.size()));
        }
    }

    return result;
}

sched::BuildResult Frontend::execute_plan(
    std::shared_ptr<sched::Plan> plan) {
    auto validation = scheduler_.compile(plan);
    if (!validation.valid) {
        sched::BuildResult fail;
        fail.ok = false;
        fail.error_code = validation.error_code;
        fail.error_message = validation.error_message;
        return fail;
    }
    return scheduler_.execute(plan);
}

std::string Frontend::extract_artifact(
    const sched::BuildResult& result,
    const std::string& node_id) {
    auto it = result.node_outputs.find(node_id);
    if (it != result.node_outputs.end()) {
        return it->second;
    }
    return {};
}

/* ========================================================================
 * Format detection
 * ======================================================================== */

SourceFormat detect_format(const std::string& source_path) {
    std::string lower = source_path;
    std::transform(lower.begin(), lower.end(), lower.begin(),
                   [](unsigned char c) { return std::tolower(c); });

    /* Check file extensions */
    if (lower.size() >= 3) {
        std::string ext3 = lower.substr(lower.size() - 3);
        if (ext3 == ".md") return SourceFormat::Markdown;
        if (ext3 == ".tex") return SourceFormat::TeX;
    }

    if (lower.size() >= 9) {
        if (lower.substr(lower.size() - 9) == ".markdown")
            return SourceFormat::Markdown;
    }

    if (lower.size() >= 5) {
        if (lower.substr(lower.size() - 5) == ".roff")
            return SourceFormat::ROFF;
    }

    if (lower.size() >= 2) {
        std::string ext2 = lower.substr(lower.size() - 2);
        if (ext2 == ".1" || ext2 == ".2" || ext2 == ".3" ||
            ext2 == ".4" || ext2 == ".5" || ext2 == ".6" ||
            ext2 == ".7" || ext2 == ".8") {
            return SourceFormat::ROFF;
        }
    }

    /* Fall back to content-based detection */
    std::ifstream f(source_path);
    if (!f.is_open()) return SourceFormat::Unknown;
    std::string content((std::istreambuf_iterator<char>(f)),
                         std::istreambuf_iterator<char>());
    return detect_format_from_content(content);
}

SourceFormat detect_format_from_content(const std::string& content) {
    /* TeX heuristics */
    if (content.find("\\documentclass") != std::string::npos ||
        content.find("\\begin{document}") != std::string::npos ||
        content.find("\\section{") != std::string::npos) {
        return SourceFormat::TeX;
    }

    /* ROFF heuristics */
    if (content.find(".TH ") == 0 ||
        content.find(".SH ") != std::string::npos ||
        content.find("\\fB") != std::string::npos) {
        return SourceFormat::ROFF;
    }

    /* Markdown heuristics */
    if (content.find("# ") != std::string::npos ||
        content.find("```") != std::string::npos) {
        return SourceFormat::Markdown;
    }

    return SourceFormat::Unknown;
}

std::string format_name(SourceFormat fmt) {
    switch (fmt) {
        case SourceFormat::Markdown: return "markdown";
        case SourceFormat::TeX:      return "tex";
        case SourceFormat::ROFF:     return "roff";
        default:                     return "unknown";
    }
}

/* ========================================================================
 * Frontend subclasses declared in this file
 * ======================================================================== */

class MarkdownFrontend : public Frontend {
public:
    explicit MarkdownFrontend(const FrontendOptions& options)
        : Frontend(options) {}

    std::shared_ptr<ir::IRGraph> parse_to_ir() override;
    std::shared_ptr<sched::Plan> build_plan(
        std::shared_ptr<ir::IRGraph> ir_graph) override;
};

class TeXFrontend : public Frontend {
public:
    explicit TeXFrontend(const FrontendOptions& options)
        : Frontend(options) {}

    std::shared_ptr<ir::IRGraph> parse_to_ir() override;
    std::shared_ptr<sched::Plan> build_plan(
        std::shared_ptr<ir::IRGraph> ir_graph) override;
};

class RoffFrontend : public Frontend {
public:
    explicit RoffFrontend(const FrontendOptions& options)
        : Frontend(options) {}

    std::shared_ptr<ir::IRGraph> parse_to_ir() override;
    std::shared_ptr<sched::Plan> build_plan(
        std::shared_ptr<ir::IRGraph> ir_graph) override;
};

/* ========================================================================
 * Factory function
 * ======================================================================== */

std::unique_ptr<Frontend> create_frontend(const FrontendOptions& options) {
    SourceFormat fmt;
    if (options.use_inline_content) {
        fmt = detect_format_from_content(options.source_content);
    } else {
        fmt = detect_format(options.source_path);
    }

    switch (fmt) {
        case SourceFormat::Markdown:
            return std::make_unique<MarkdownFrontend>(options);
        case SourceFormat::TeX:
            return std::make_unique<TeXFrontend>(options);
        case SourceFormat::ROFF:
            return std::make_unique<RoffFrontend>(options);
        default:
            return nullptr;
    }
}

} // namespace swaff
} // namespace doxtk
