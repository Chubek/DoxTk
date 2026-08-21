#ifndef DOXTK_GLUE_HPP
#define DOXTK_GLUE_HPP

#include <cstdint>
#include <functional>
#include <map>
#include <memory>
#include <sstream>
#include <stdexcept>
#include <string>
#include <unordered_map>
#include <vector>

#define QAMRPP_HOME_DEFAULT "/mnt/warble/doxweave/third_party/QaMRpp"
#include "../../third_party/QaMRpp/include/QaMRpp.hpp"
#undef QAMRPP_HOME_DEFAULT

namespace doxtk {
namespace glue {

/* ========================================================================
 * Error types
 * ======================================================================== */

enum class GlueError {
    Ok = 0,
    SandboxViolation,
    HostServiceNotFound,
    HostServiceVersionMismatch,
    KernelLoadFailed,
    KernelAdvertiseFailed,
    CapabilityNotFound,
    InvalidInput,
    ResourceLimit,
    InternalError
};

struct GlueResult {
    GlueError error = GlueError::Ok;
    std::string message;

    bool ok() const { return error == GlueError::Ok; }
    static GlueResult success() { return {GlueError::Ok, {}}; }
    static GlueResult failure(GlueError e, std::string msg) {
        return {e, std::move(msg)};
    }
};

/* ========================================================================
 * Host Service contract
 * ======================================================================== */

struct HostServiceContract {
    std::string name;
    std::string version;
    std::string description;
    bool deterministic_replay = false;
};

class HostService {
public:
    HostService(HostServiceContract contract) : contract_(std::move(contract)) {}
    virtual ~HostService() = default;

    const HostServiceContract& contract() const { return contract_; }

    virtual GlueResult register_with(qamrpp::Context& ctx) = 0;
    virtual void unregister_from(qamrpp::Context& /*ctx*/) {}

    bool check_version(const std::string& requested) const {
        return contract_.version == requested;
    }

protected:
    HostServiceContract contract_;
};

/* ========================================================================
 * JSON utility functions (public – used by host services & kernels)
 * ======================================================================== */

class JsonUtil {
public:
    static std::string encode(const qamrpp::ValuePtr& val);
    static qamrpp::ValuePtr decode(const std::string& text);
};

/* ========================================================================
 * Host Service: doxtk.json
 * ======================================================================== */

class JsonService : public HostService {
public:
    JsonService()
        : HostService({"doxtk.json", "1.0.0",
                       "JSON encode/decode for kernels", false}) {}

    GlueResult register_with(qamrpp::Context& ctx) override;
};

/* ========================================================================
 * Host Service: doxtk.clock
 * ======================================================================== */

class ClockService : public HostService {
public:
    ClockService()
        : HostService({"doxtk.clock", "1.0.0",
                       "Deterministic clock for reproducible builds", true})
        , fixed_epoch_(0) {}

    void set_epoch(int64_t epoch) { fixed_epoch_ = epoch; }
    int64_t epoch() const { return fixed_epoch_; }

    GlueResult register_with(qamrpp::Context& ctx) override;

private:
    int64_t fixed_epoch_;
};

/* ========================================================================
 * Host Service: haru.pdf
 * ======================================================================== */

class HaruPdfService : public HostService {
public:
    HaruPdfService()
        : HostService({"haru.pdf", "1.0.0",
                       "PDF generation via libharu (memory-backed)", false}) {}

    GlueResult register_with(qamrpp::Context& ctx) override;
};

/* ========================================================================
 * Host Service: haru.font
 * ======================================================================== */

class HaruFontService : public HostService {
public:
    HaruFontService()
        : HostService({"haru.font", "1.0.0",
                       "Font measurement via libharu (memory-backed)", false}) {}

    GlueResult register_with(qamrpp::Context& ctx) override;
};

/* ========================================================================
 * Host Service Registry
 * ======================================================================== */

class HostServiceRegistry {
public:
    void register_service(std::unique_ptr<HostService> service);
    HostService* find(const std::string& name);
    GlueResult validate_service_request(const std::string& name,
                                        const std::string& version);
    GlueResult install_all(qamrpp::Context& ctx);
    void uninstall_all(qamrpp::Context& ctx);
    std::vector<std::string> service_names() const;

private:
    std::unordered_map<std::string, std::unique_ptr<HostService>> services_;
};

/* ========================================================================
 * Glue Context – sandboxed Lua environment
 * ======================================================================== */

class GlueContext {
public:
    explicit GlueContext(const std::string& kernel_base_path = "kernel/");

    GlueContext(const GlueContext&) = delete;
    GlueContext& operator=(const GlueContext&) = delete;
    GlueContext(GlueContext&&) = default;
    GlueContext& operator=(GlueContext&&) = default;

    /* --- Setup --- */

    GlueResult initialise();

    HostServiceRegistry& registry() { return registry_; }
    const HostServiceRegistry& registry() const { return registry_; }

    /* --- Kernel execution --- */

    struct KernelOutput {
        std::string raw_json;
        qamrpp::ValuePtr raw_value;
        GlueResult error;
    };

    KernelOutput load_kernel(const std::string& kernel_path);
    GlueResult advertise_kernel(const std::string& kernel_path,
                                std::string& out_json);

    struct CapabilityCall {
        std::string kernel_path;
        std::string capability_name;
        std::string input_json;
        std::string params_json;
    };

    KernelOutput invoke_capability(const CapabilityCall& call);

    /* --- Accessors --- */

    qamrpp::Context& qamrpp_context() { return ctx_; }
    const qamrpp::Context& qamrpp_context() const { return ctx_; }

    std::string kernel_base_path() const { return kernel_base_path_; }
    void set_clock_epoch(int64_t epoch);

private:
    GlueResult setup_sandbox();
    GlueResult register_builtin_services();
    GlueResult install_sandboxed_import();

    GlueResult load_kernel_module(const std::string& kernel_path,
                                  qamrpp::ValuePtr& out_module);

    static std::string read_file(const std::string& path);

    qamrpp::Context ctx_;
    HostServiceRegistry registry_;
    std::string kernel_base_path_;
    std::unique_ptr<ClockService> clock_service_;
};

/* ========================================================================
 * Resource limits
 * ======================================================================== */

struct ResourceLimits {
    uint32_t cpu_ms = 2000;
    uint32_t memory_mb = 64;
    uint32_t output_mb = 16;
};

// ============================================================
// Implementation
// ============================================================

} // namespace glue
} // namespace doxtk

#endif // DOXTK_GLUE_HPP
