#ifndef DOXTK_SWAFF_HPP
#define DOXTK_SWAFF_HPP

#include <cstdint>
#include <map>
#include <memory>
#include <optional>
#include <string>
#include <vector>

#include "../sched/doxtk_sched.hpp"
#include "../ir/doxtk_ir.hpp"

namespace doxtk {
namespace swaff {

/* ========================================================================
 * Frontend Result
 * ======================================================================== */

struct FrontendResult {
    bool ok = false;
    std::string error_code;
    std::string error_message;

    std::shared_ptr<ir::IRGraph> ir_graph;
    std::shared_ptr<sched::Plan> plan;
    sched::BuildResult build_result;
    std::map<std::string, std::string> artifacts;

    static FrontendResult success(std::shared_ptr<ir::IRGraph> ir,
                                  std::shared_ptr<sched::Plan> p,
                                  sched::BuildResult br) {
        FrontendResult r;
        r.ok = true;
        r.ir_graph = std::move(ir);
        r.plan = std::move(p);
        r.build_result = std::move(br);
        return r;
    }

    static FrontendResult failure(std::string code, std::string msg) {
        FrontendResult r;
        r.ok = false;
        r.error_code = std::move(code);
        r.error_message = std::move(msg);
        return r;
    }
};

/* ========================================================================
 * Frontend Options
 * ======================================================================== */

struct FrontendOptions {
    std::string source_path;
    std::string source_content;
    std::string output_format = "pdf";
    std::string output_path;
    std::map<std::string, std::string> config;
    std::string kernel_base_path = "kernel/";
    std::string manifests_path = "manifests/";
    bool use_inline_content = false;
};

/* ========================================================================
 * Abstract Frontend ([W-1] through [W-3])
 *
 * Every Swaff frontend MUST implement this interface.
 * Frontends MUST NOT invoke kernels directly ([W-2]).
 * ======================================================================== */

class Frontend {
public:
    explicit Frontend(const FrontendOptions& options);
    virtual ~Frontend() = default;

    FrontendResult process();

    virtual std::shared_ptr<ir::IRGraph> parse_to_ir() = 0;
    virtual std::shared_ptr<sched::Plan> build_plan(
        std::shared_ptr<ir::IRGraph> ir_graph) = 0;

    const FrontendOptions& options() const { return options_; }
    sched::Scheduler& scheduler() { return scheduler_; }
    const sched::Scheduler& scheduler() const { return scheduler_; }

protected:
    bool load_registries();
    void configure_scheduler();
    sched::BuildResult execute_plan(std::shared_ptr<sched::Plan> plan);
    std::string extract_artifact(const sched::BuildResult& result,
                                 const std::string& node_id);

    FrontendOptions options_;
    sched::Scheduler scheduler_;
};

/* ========================================================================
 * Frontend Factory
 * ======================================================================== */

enum class SourceFormat {
    Markdown,
    TeX,
    ROFF,
    Unknown
};

SourceFormat detect_format(const std::string& source_path);
SourceFormat detect_format_from_content(const std::string& content);
std::unique_ptr<Frontend> create_frontend(const FrontendOptions& options);
std::string format_name(SourceFormat fmt);

/* ========================================================================
 * Error codes for Swaff layer
 * ======================================================================== */

namespace error {
    constexpr const char* PARSE_FAILED       = "ERR_SWAFF_PARSE";
    constexpr const char* PLAN_BUILD_FAILED  = "ERR_SWAFF_PLAN";
    constexpr const char* EXECUTION_FAILED   = "ERR_SWAFF_EXEC";
    constexpr const char* UNSUPPORTED_FORMAT = "ERR_SWAFF_FORMAT";
    constexpr const char* REGISTRY_FAILED    = "ERR_SWAFF_REGISTRY";
    constexpr const char* OUTPUT_FAILED      = "ERR_SWAFF_OUTPUT";
} // namespace error

} // namespace swaff
} // namespace doxtk

#endif // DOXTK_SWAFF_HPP
