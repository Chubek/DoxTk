#include <cassert>
#include <cstdio>
#include <cstring>
#include <iostream>
#include <string>
#include <vector>

#define QAMRPP_HOME_DEFAULT "/mnt/warble/doxweave/third_party/QaMRpp"
#include "../../src/glue/doxtk_glue.hpp"

/* ========================================================================
 * Simple test framework
 * ======================================================================== */

static int tests_run = 0;
static int tests_passed = 0;
static int tests_failed = 0;
static std::string current_test;

#define TEST(name) \
    current_test = name; \
    tests_run++; \
    std::cout << "  TEST " << tests_run << ": " << name << " ... "

#define PASS() \
    tests_passed++; \
    std::cout << "PASSED\n"

#define FAIL(msg) \
    tests_failed++; \
    std::cout << "FAILED: " << msg << "\n"

#define CHECK(cond) \
    if (!(cond)) { FAIL(#cond); return; }

#define CHECK_EQ(a, b) \
    if ((a) != (b)) { \
        std::ostringstream oss; \
        oss << #a << " != " << #b << " (" << (a) << " != " << (b) << ")"; \
        FAIL(oss.str()); \
        return; \
    }

#define CHECK_STR_EQ(a, b) \
    if (std::string(a) != std::string(b)) { \
        std::ostringstream oss; \
        oss << #a << " != " << #b << " ('" << (a) << "' != '" << (b) << "')"; \
        FAIL(oss.str()); \
        return; \
    }

/* ========================================================================
 * Tests
 * ======================================================================== */

using namespace doxtk::glue;

// --- Helper: create a fresh, initialised context ---
static GlueContext make_ctx() {
    GlueContext ctx;
    auto result = ctx.initialise();
    if (!result.ok()) {
        std::cerr << "Failed to initialise GlueContext: " << result.message << "\n";
        std::exit(1);
    }
    return ctx;
}

// --- Helper: run Lua code and return result as string ---
static std::string run_lua(GlueContext& ctx, const std::string& code) {
    try {
        auto val = ctx.qamrpp_context().run(code);
        return JsonUtil::encode(val);
    } catch (const std::exception& e) {
        return std::string("ERROR: ") + e.what();
    }
}

// 1. Context initialisation
static void test_01_context_init() {
    TEST("GlueContext initialisation succeeds");
    GlueContext ctx;
    auto result = ctx.initialise();
    CHECK(result.ok());
    PASS();
}

// 2. Sandbox: dofile is blocked
static void test_02_sandbox_dofile() {
    TEST("Sandbox blocks dofile");
    auto ctx = make_ctx();
    auto nil_val = ctx.qamrpp_context().globals["dofile"];
    CHECK(nil_val != nullptr);
    CHECK(nil_val->type == qamrpp::Value::NIL);
    PASS();
}

// 3. Sandbox: loadfile is blocked
static void test_03_sandbox_loadfile() {
    TEST("Sandbox blocks loadfile");
    auto ctx = make_ctx();
    auto val = ctx.qamrpp_context().globals["loadfile"];
    CHECK(val != nullptr);
    CHECK(val->type == qamrpp::Value::NIL);
    PASS();
}

// 4. Sandbox: load is blocked
static void test_04_sandbox_load() {
    TEST("Sandbox blocks load");
    auto ctx = make_ctx();
    auto val = ctx.qamrpp_context().globals["load"];
    CHECK(val != nullptr);
    CHECK(val->type == qamrpp::Value::NIL);
    PASS();
}

// 5. Sandbox: io is blocked
static void test_05_sandbox_io() {
    TEST("Sandbox blocks io");
    auto ctx = make_ctx();
    auto val = ctx.qamrpp_context().globals["io"];
    CHECK(val != nullptr);
    CHECK(val->type == qamrpp::Value::NIL);
    PASS();
}

// 6. Sandbox: os.execute is blocked (os is replaced with safe version)
static void test_06_sandbox_os() {
    TEST("Sandbox replaces os with safe version");
    auto ctx = make_ctx();
    auto val = ctx.qamrpp_context().globals["os"];
    CHECK(val != nullptr);
    CHECK(val->type == qamrpp::Value::TABLE);
    // os.execute should not exist
    bool has_execute = false;
    for (const auto& kv : val->table_entries) {
        if (kv.first->type == qamrpp::Value::STRING &&
            kv.first->string_value == "execute") {
            has_execute = true;
        }
    }
    CHECK(!has_execute);
    PASS();
}

// 7. Sandbox: package is blocked
static void test_07_sandbox_package() {
    TEST("Sandbox blocks package");
    auto ctx = make_ctx();
    auto val = ctx.qamrpp_context().globals["package"];
    CHECK(val != nullptr);
    CHECK(val->type == qamrpp::Value::NIL);
    PASS();
}

// 8. Sandbox: debug is blocked
static void test_08_sandbox_debug() {
    TEST("Sandbox blocks debug");
    auto ctx = make_ctx();
    auto val = ctx.qamrpp_context().globals["debug"];
    CHECK(val != nullptr);
    CHECK(val->type == qamrpp::Value::NIL);
    PASS();
}

// 9. Sandbox: safe os.date exists
static void test_09_sandbox_os_date() {
    TEST("Sandbox provides safe os.date");
    auto ctx = make_ctx();
    auto val = ctx.qamrpp_context().globals["os"];
    bool has_date = false;
    for (const auto& kv : val->table_entries) {
        if (kv.first->type == qamrpp::Value::STRING &&
            kv.first->string_value == "date") {
            has_date = true;
            CHECK(kv.second->type == qamrpp::Value::FUNCTION);
        }
    }
    CHECK(has_date);
    PASS();
}

// 10. Sandbox: safe os.time exists
static void test_10_sandbox_os_time() {
    TEST("Sandbox provides safe os.time");
    auto ctx = make_ctx();
    auto val = ctx.qamrpp_context().globals["os"];
    bool has_time = false;
    for (const auto& kv : val->table_entries) {
        if (kv.first->type == qamrpp::Value::STRING &&
            kv.first->string_value == "time") {
            has_time = true;
            CHECK(kv.second->type == qamrpp::Value::FUNCTION);
        }
    }
    CHECK(has_time);
    PASS();
}

// 11. Host Service: doxtk.json is registered
static void test_11_hs_json_registered() {
    TEST("Host service doxtk.json is registered");
    auto ctx = make_ctx();
    auto val = ctx.qamrpp_context().globals["doxtk_json"];
    CHECK(val != nullptr);
    CHECK(val->type == qamrpp::Value::TABLE);
    PASS();
}

// 12. Host Service: doxtk.json encode
static void test_12_hs_json_encode() {
    TEST("doxtk.json encode works");
    auto ctx = make_ctx();
    auto val = ctx.qamrpp_context().globals["doxtk_json"];

    qamrpp::ValuePtr encode_fn;
    for (const auto& kv : val->table_entries) {
        if (kv.first->type == qamrpp::Value::STRING &&
            kv.first->string_value == "encode") {
            encode_fn = kv.second;
        }
    }
    CHECK(encode_fn != nullptr);

    auto input = qamrpp::Value::make_table();
    input->table_entries.push_back({
        std::make_shared<qamrpp::Value>("hello"),
        std::make_shared<qamrpp::Value>("world")
    });

    std::vector<qamrpp::ValuePtr> args = {input};
    auto result = encode_fn->function_value(ctx.qamrpp_context(), args);
    CHECK(result->type == qamrpp::Value::STRING);
    CHECK_STR_EQ(result->string_value, "{\"hello\":\"world\"}");
    PASS();
}

// 13. Host Service: doxtk.json decode
static void test_13_hs_json_decode() {
    TEST("doxtk.json decode works");
    auto ctx = make_ctx();
    auto val = ctx.qamrpp_context().globals["doxtk_json"];

    qamrpp::ValuePtr decode_fn;
    for (const auto& kv : val->table_entries) {
        if (kv.first->type == qamrpp::Value::STRING &&
            kv.first->string_value == "decode") {
            decode_fn = kv.second;
        }
    }
    CHECK(decode_fn != nullptr);

    auto input = std::make_shared<qamrpp::Value>("{\"key\":42}");
    std::vector<qamrpp::ValuePtr> args = {input};
    auto result = decode_fn->function_value(ctx.qamrpp_context(), args);
    CHECK(result->type == qamrpp::Value::TABLE);

    bool has_key = false;
    for (const auto& kv : result->table_entries) {
        if (kv.first->type == qamrpp::Value::STRING &&
            kv.first->string_value == "key") {
            has_key = true;
            CHECK_EQ(kv.second->int_value, 42);
        }
    }
    CHECK(has_key);
    PASS();
}

// 14. Host Service: doxtk.clock default epoch
static void test_14_hs_clock_default() {
    TEST("doxtk.clock returns default epoch 0");
    auto ctx = make_ctx();
    auto val = ctx.qamrpp_context().globals["doxtk_clock"];
    CHECK(val != nullptr);
    CHECK(val->type == qamrpp::Value::FUNCTION);

    std::vector<qamrpp::ValuePtr> args;
    auto result = val->function_value(ctx.qamrpp_context(), args);
    CHECK_EQ(result->float_value, 0.0);
    PASS();
}

// 15. Host Service: doxtk.clock set_epoch
static void test_15_hs_clock_set_epoch() {
    TEST("doxtk.clock set_epoch works");
    auto ctx = make_ctx();
    ctx.set_clock_epoch(1234567890);

    auto val = ctx.qamrpp_context().globals["doxtk_clock"];
    std::vector<qamrpp::ValuePtr> args;
    auto result = val->function_value(ctx.qamrpp_context(), args);
    CHECK_EQ(result->float_value, 1234567890.0);
    PASS();
}

// 16. Host Service: haru.pdf is registered
static void test_16_hs_pdf_registered() {
    TEST("Host service haru.pdf is registered");
    auto ctx = make_ctx();
    auto val = ctx.qamrpp_context().globals["haru_pdf"];
    CHECK(val != nullptr);
    CHECK(val->type == qamrpp::Value::TABLE);
    PASS();
}

// 17. Host Service: haru.pdf create_document
static void test_17_hs_pdf_create_document() {
    TEST("haru.pdf create_document works");
    auto ctx = make_ctx();
    auto val = ctx.qamrpp_context().globals["haru_pdf"];

    qamrpp::ValuePtr create_fn;
    for (const auto& kv : val->table_entries) {
        if (kv.first->type == qamrpp::Value::STRING &&
            kv.first->string_value == "create_document") {
            create_fn = kv.second;
        }
    }
    CHECK(create_fn != nullptr);

    std::vector<qamrpp::ValuePtr> args;
    auto result = create_fn->function_value(ctx.qamrpp_context(), args);
    CHECK(result->type == qamrpp::Value::TABLE);

    bool has_pages = false;
    for (const auto& kv : result->table_entries) {
        if (kv.first->type == qamrpp::Value::STRING &&
            kv.first->string_value == "pages") {
            has_pages = true;
            CHECK(kv.second->type == qamrpp::Value::TABLE);
        }
    }
    CHECK(has_pages);
    PASS();
}

// 18. Host Service: haru.pdf add_page and write_text
static void test_18_hs_pdf_add_page_write_text() {
    TEST("haru.pdf add_page and write_text work");
    auto ctx = make_ctx();
    auto pdf = ctx.qamrpp_context().globals["haru_pdf"];

    // Get functions
    qamrpp::ValuePtr create_fn, add_page_fn, write_text_fn, serialize_fn;
    for (const auto& kv : pdf->table_entries) {
        if (kv.first->type == qamrpp::Value::STRING) {
            if (kv.first->string_value == "create_document") create_fn = kv.second;
            if (kv.first->string_value == "add_page") add_page_fn = kv.second;
            if (kv.first->string_value == "write_text") write_text_fn = kv.second;
            if (kv.first->string_value == "serialize") serialize_fn = kv.second;
        }
    }
    CHECK(create_fn && add_page_fn && write_text_fn && serialize_fn);

    // Create doc
    std::vector<qamrpp::ValuePtr> empty;
    auto doc = create_fn->function_value(ctx.qamrpp_context(), empty);

    // Create a page
    auto page = qamrpp::Value::make_table();

    // Add page
    std::vector<qamrpp::ValuePtr> add_args = {doc, page};
    add_page_fn->function_value(ctx.qamrpp_context(), add_args);

    // Write text
    auto x = std::make_shared<qamrpp::Value>(72.0);
    auto y = std::make_shared<qamrpp::Value>(700.0);
    auto text = std::make_shared<qamrpp::Value>("Hello World");
    std::vector<qamrpp::ValuePtr> wt_args = {page, x, y, text};
    write_text_fn->function_value(ctx.qamrpp_context(), wt_args);

    // Serialize
    std::vector<qamrpp::ValuePtr> ser_args = {doc};
    auto result = serialize_fn->function_value(ctx.qamrpp_context(), ser_args);
    CHECK(result->type == qamrpp::Value::STRING);
    CHECK(result->string_value.find("Hello World") != std::string::npos);
    PASS();
}

// 19. Host Service: haru.font is registered
static void test_19_hs_font_registered() {
    TEST("Host service haru.font is registered");
    auto ctx = make_ctx();
    auto val = ctx.qamrpp_context().globals["haru_font"];
    CHECK(val != nullptr);
    CHECK(val->type == qamrpp::Value::TABLE);
    PASS();
}

// 20. Host Service: haru.font measure_text
static void test_20_hs_font_measure_text() {
    TEST("haru.font measure_text works");
    auto ctx = make_ctx();
    auto font = ctx.qamrpp_context().globals["haru_font"];

    qamrpp::ValuePtr measure_fn;
    for (const auto& kv : font->table_entries) {
        if (kv.first->type == qamrpp::Value::STRING &&
            kv.first->string_value == "measure_text") {
            measure_fn = kv.second;
        }
    }
    CHECK(measure_fn != nullptr);

    auto text = std::make_shared<qamrpp::Value>("Hello");
    auto spec = qamrpp::Value::make_table();
    spec->table_entries.push_back({
        std::make_shared<qamrpp::Value>("size"),
        std::make_shared<qamrpp::Value>(12.0)
    });

    std::vector<qamrpp::ValuePtr> args = {text, spec};
    auto result = measure_fn->function_value(ctx.qamrpp_context(), args);
    CHECK(result->type == qamrpp::Value::TABLE);

    bool has_glyphs = false, has_total_width = false;
    for (const auto& kv : result->table_entries) {
        if (kv.first->type == qamrpp::Value::STRING &&
            kv.first->string_value == "glyphs") {
            has_glyphs = true;
            CHECK(kv.second->type == qamrpp::Value::TABLE);
            // "Hello" has 5 chars
            CHECK_EQ(static_cast<int>(kv.second->table_entries.size()), 5);
        }
        if (kv.first->type == qamrpp::Value::STRING &&
            kv.first->string_value == "total_width") {
            has_total_width = true;
            CHECK(kv.second->float_value > 0.0);
        }
    }
    CHECK(has_glyphs);
    CHECK(has_total_width);
    PASS();
}

// 21. HostServiceRegistry: register and find
static void test_21_registry_register_find() {
    TEST("HostServiceRegistry register and find works");
    HostServiceRegistry reg;
    reg.register_service(std::make_unique<JsonService>());

    auto* svc = reg.find("doxtk.json");
    CHECK(svc != nullptr);
    CHECK_STR_EQ(svc->contract().name, "doxtk.json");
    CHECK_STR_EQ(svc->contract().version, "1.0.0");

    auto* missing = reg.find("nonexistent");
    CHECK(missing == nullptr);
    PASS();
}

// 22. HostServiceRegistry: validate version
static void test_22_registry_validate_version() {
    TEST("HostServiceRegistry validate version works");
    HostServiceRegistry reg;
    reg.register_service(std::make_unique<JsonService>());

    auto result = reg.validate_service_request("doxtk.json", "1.0.0");
    CHECK(result.ok());

    auto bad = reg.validate_service_request("doxtk.json", "2.0.0");
    CHECK(!bad.ok());
    CHECK(bad.error == GlueError::HostServiceVersionMismatch);
    PASS();
}

// 23. HostServiceRegistry: validate missing service
static void test_23_registry_validate_missing() {
    TEST("HostServiceRegistry validate missing service fails");
    HostServiceRegistry reg;
    auto result = reg.validate_service_request("nonexistent", "1.0.0");
    CHECK(!result.ok());
    CHECK(result.error == GlueError::HostServiceNotFound);
    PASS();
}

// 24. HostServiceRegistry: service_names
static void test_24_registry_service_names() {
    TEST("HostServiceRegistry service_names lists all services");
    HostServiceRegistry reg;
    reg.register_service(std::make_unique<JsonService>());
    reg.register_service(std::make_unique<ClockService>());

    auto names = reg.service_names();
    CHECK_EQ(names.size(), 2u);
    bool has_json = false, has_clock = false;
    for (const auto& n : names) {
        if (n == "doxtk.json") has_json = true;
        if (n == "doxtk.clock") has_clock = true;
    }
    CHECK(has_json);
    CHECK(has_clock);
    PASS();
}

// 25. Sandboxed import: doxtk_ljson is available
static void test_25_sandbox_import_ljson() {
    TEST("Sandboxed import: doxtk_ljson is available");
    auto ctx = make_ctx();
    auto val = ctx.qamrpp_context().globals["require"];
    CHECK(val != nullptr);
    CHECK(val->type == qamrpp::Value::FUNCTION);

    auto req = std::make_shared<qamrpp::Value>("doxtk_ljson");
    std::vector<qamrpp::ValuePtr> args = {req};
    auto result = val->function_value(ctx.qamrpp_context(), args);
    CHECK(result->type == qamrpp::Value::TABLE);

    // Check encode is available
    bool has_encode = false, has_decode = false;
    for (const auto& kv : result->table_entries) {
        if (kv.first->type == qamrpp::Value::STRING &&
            kv.first->string_value == "encode") has_encode = true;
        if (kv.first->type == qamrpp::Value::STRING &&
            kv.first->string_value == "decode") has_decode = true;
    }
    CHECK(has_encode);
    CHECK(has_decode);
    PASS();
}

// 26. Sandboxed import: other imports denied
static void test_26_sandbox_import_denied() {
    TEST("Sandboxed import: other imports return empty table");
    auto ctx = make_ctx();
    auto val = ctx.qamrpp_context().globals["require"];

    auto req = std::make_shared<qamrpp::Value>("some_evil_lib");
    std::vector<qamrpp::ValuePtr> args = {req};
    auto result = val->function_value(ctx.qamrpp_context(), args);
    CHECK(result->type == qamrpp::Value::TABLE);
    CHECK_EQ(static_cast<int>(result->table_entries.size()), 0);
    PASS();
}

// 27. JSON encode: various types
static void test_27_json_encode_types() {
    TEST("JsonUtil::encode handles all types");
    CHECK_STR_EQ(JsonUtil::encode(std::make_shared<qamrpp::Value>()), "null");
    CHECK_STR_EQ(JsonUtil::encode(std::make_shared<qamrpp::Value>(true)), "true");
    CHECK_STR_EQ(JsonUtil::encode(std::make_shared<qamrpp::Value>(false)), "false");
    CHECK_STR_EQ(JsonUtil::encode(
        std::make_shared<qamrpp::Value>(static_cast<int64_t>(42))), "42");
    CHECK_STR_EQ(JsonUtil::encode(std::make_shared<qamrpp::Value>("hello")),
                 "\"hello\"");
    PASS();
}

// 28. JSON encode: nested objects
static void test_28_json_encode_nested() {
    TEST("JsonUtil::encode handles nested objects");
    auto inner = qamrpp::Value::make_table();
    inner->table_entries.push_back({
        std::make_shared<qamrpp::Value>("a"),
        std::make_shared<qamrpp::Value>(static_cast<int64_t>(1))
    });

    auto outer = qamrpp::Value::make_table();
    outer->table_entries.push_back({
        std::make_shared<qamrpp::Value>("inner"),
        inner
    });

    auto result = JsonUtil::encode(outer);
    CHECK_STR_EQ(result, "{\"inner\":{\"a\":1}}");
    PASS();
}

// 29. JSON encode: arrays
static void test_29_json_encode_arrays() {
    TEST("JsonUtil::encode handles arrays");
    auto arr = qamrpp::Value::make_table();
    arr->table_entries.push_back({
        std::make_shared<qamrpp::Value>(static_cast<int64_t>(1)),
        std::make_shared<qamrpp::Value>("one")
    });
    arr->table_entries.push_back({
        std::make_shared<qamrpp::Value>(static_cast<int64_t>(2)),
        std::make_shared<qamrpp::Value>("two")
    });

    auto result = JsonUtil::encode(arr);
    CHECK_STR_EQ(result, "[\"one\",\"two\"]");
    PASS();
}

// 30. JSON decode: basic types
static void test_30_json_decode_types() {
    TEST("JsonUtil::decode handles basic types");
    auto null_val = JsonUtil::decode("null");
    CHECK(null_val->type == qamrpp::Value::NIL);

    auto bool_val = JsonUtil::decode("true");
    CHECK(bool_val->type == qamrpp::Value::BOOL);
    CHECK_EQ(bool_val->bool_value, true);

    auto int_val = JsonUtil::decode("42");
    CHECK(int_val->type == qamrpp::Value::INT);
    CHECK_EQ(int_val->int_value, 42);

    auto str_val = JsonUtil::decode("\"hello\"");
    CHECK(str_val->type == qamrpp::Value::STRING);
    CHECK_STR_EQ(str_val->string_value, "hello");
    PASS();
}

// 31. JSON decode: objects
static void test_31_json_decode_object() {
    TEST("JsonUtil::decode handles objects");
    auto val = JsonUtil::decode("{\"name\":\"test\",\"count\":5}");
    CHECK(val->type == qamrpp::Value::TABLE);

    bool has_name = false, has_count = false;
    for (const auto& kv : val->table_entries) {
        if (kv.first->type == qamrpp::Value::STRING &&
            kv.first->string_value == "name") {
            has_name = true;
            CHECK_STR_EQ(kv.second->string_value, "test");
        }
        if (kv.first->type == qamrpp::Value::STRING &&
            kv.first->string_value == "count") {
            has_count = true;
            CHECK_EQ(kv.second->int_value, 5);
        }
    }
    CHECK(has_name);
    CHECK(has_count);
    PASS();
}

// 32. JSON decode: arrays
static void test_32_json_decode_array() {
    TEST("JsonUtil::decode handles arrays");
    auto val = JsonUtil::decode("[1,2,3]");
    CHECK(val->type == qamrpp::Value::TABLE);
    CHECK_EQ(static_cast<int>(val->table_entries.size()), 3);
    PASS();
}

// 33. JSON roundtrip
static void test_33_json_roundtrip() {
    TEST("JsonUtil encode/decode roundtrip");
    auto original = JsonUtil::decode("{\"key\":\"value\",\"num\":42}");
    auto encoded = JsonUtil::encode(original);
    auto decoded = JsonUtil::decode(encoded);

    bool has_key = false, has_num = false;
    for (const auto& kv : decoded->table_entries) {
        if (kv.first->type == qamrpp::Value::STRING &&
            kv.first->string_value == "key") {
            has_key = true;
            CHECK_STR_EQ(kv.second->string_value, "value");
        }
        if (kv.first->type == qamrpp::Value::STRING &&
            kv.first->string_value == "num") {
            has_num = true;
            CHECK_EQ(kv.second->int_value, 42);
        }
    }
    CHECK(has_key);
    CHECK(has_num);
    PASS();
}

// 34. GlueResult: error types
static void test_34_glue_result_errors() {
    TEST("GlueResult error types work correctly");
    auto ok = GlueResult::success();
    CHECK(ok.ok());
    CHECK_EQ(ok.error, GlueError::Ok);

    auto fail = GlueResult::failure(GlueError::SandboxViolation, "test error");
    CHECK(!fail.ok());
    CHECK_EQ(fail.error, GlueError::SandboxViolation);
    CHECK_STR_EQ(fail.message, "test error");
    PASS();
}

// 35. ResourceLimits defaults
static void test_35_resource_limits() {
    TEST("ResourceLimits has correct defaults");
    ResourceLimits limits;
    CHECK_EQ(limits.cpu_ms, 2000u);
    CHECK_EQ(limits.memory_mb, 64u);
    CHECK_EQ(limits.output_mb, 16u);
    PASS();
}

// 36. HostServiceContract: check_version
static void test_36_contract_check_version() {
    TEST("HostServiceContract check_version works");
    HostServiceContract contract{"test", "1.2.3", "desc", false};
    HostService svc(contract);

    CHECK(svc.check_version("1.2.3"));
    CHECK(!svc.check_version("1.2.4"));
    CHECK(!svc.check_version("2.0.0"));
    PASS();
}

// 37. Registry: uninstall_all clears services
static void test_37_registry_uninstall() {
    TEST("HostServiceRegistry uninstall_all works");
    HostServiceRegistry reg;
    reg.register_service(std::make_unique<JsonService>());

    auto ctx = make_ctx();
    auto result = reg.install_all(ctx.qamrpp_context());
    CHECK(result.ok());

    // Service should be in globals
    CHECK(ctx.qamrpp_context().globals["doxtk_json"] != nullptr);

    reg.uninstall_all(ctx.qamrpp_context());
    PASS();
}

// 38. GlueContext: kernel_base_path
static void test_38_glue_ctx_kernel_path() {
    TEST("GlueContext kernel_base_path is set correctly");
    GlueContext ctx("custom/path/");
    CHECK_STR_EQ(ctx.kernel_base_path(), "custom/path/");
    PASS();
}

// 39. GlueContext: set_clock_epoch before init
static void test_39_clock_epoch_before_init() {
    TEST("set_clock_epoch works before initialise");
    GlueContext ctx;
    ctx.set_clock_epoch(999);
    auto result = ctx.initialise();
    CHECK(result.ok());

    auto val = ctx.qamrpp_context().globals["doxtk_clock"];
    std::vector<qamrpp::ValuePtr> args;
    auto clock_result = val->function_value(ctx.qamrpp_context(), args);
    CHECK_EQ(clock_result->float_value, 999.0);
    PASS();
}

// 40. GlueContext: multiple contexts are independent
static void test_40_independent_contexts() {
    TEST("Multiple GlueContext instances are independent");
    auto ctx1 = make_ctx();
    auto ctx2 = make_ctx();

    ctx1.set_clock_epoch(100);
    ctx2.set_clock_epoch(200);

    auto val1 = ctx1.qamrpp_context().globals["doxtk_clock"];
    auto val2 = ctx2.qamrpp_context().globals["doxtk_clock"];

    std::vector<qamrpp::ValuePtr> args;
    auto r1 = val1->function_value(ctx1.qamrpp_context(), args);
    auto r2 = val2->function_value(ctx2.qamrpp_context(), args);

    CHECK_EQ(r1->float_value, 100.0);
    CHECK_EQ(r2->float_value, 200.0);
    PASS();
}

// 41. HaruPdfService: serialize empty document
static void test_41_pdf_serialize_empty() {
    TEST("haru.pdf serialize empty document works");
    auto ctx = make_ctx();
    auto pdf = ctx.qamrpp_context().globals["haru_pdf"];

    qamrpp::ValuePtr create_fn, serialize_fn;
    for (const auto& kv : pdf->table_entries) {
        if (kv.first->type == qamrpp::Value::STRING) {
            if (kv.first->string_value == "create_document") create_fn = kv.second;
            if (kv.first->string_value == "serialize") serialize_fn = kv.second;
        }
    }
    CHECK(create_fn && serialize_fn);

    std::vector<qamrpp::ValuePtr> empty;
    auto doc = create_fn->function_value(ctx.qamrpp_context(), empty);

    std::vector<qamrpp::ValuePtr> ser_args = {doc};
    auto result = serialize_fn->function_value(ctx.qamrpp_context(), ser_args);
    CHECK(result->type == qamrpp::Value::STRING);
    PASS();
}

// 42. HaruFontService: measure empty text
static void test_42_font_measure_empty() {
    TEST("haru.font measure_text empty string works");
    auto ctx = make_ctx();
    auto font = ctx.qamrpp_context().globals["haru_font"];

    qamrpp::ValuePtr measure_fn;
    for (const auto& kv : font->table_entries) {
        if (kv.first->type == qamrpp::Value::STRING &&
            kv.first->string_value == "measure_text") {
            measure_fn = kv.second;
        }
    }
    CHECK(measure_fn != nullptr);

    auto text = std::make_shared<qamrpp::Value>("");
    auto spec = qamrpp::Value::make_table();
    std::vector<qamrpp::ValuePtr> args = {text, spec};
    auto result = measure_fn->function_value(ctx.qamrpp_context(), args);
    CHECK(result->type == qamrpp::Value::TABLE);

    bool has_total_width = false;
    for (const auto& kv : result->table_entries) {
        if (kv.first->type == qamrpp::Value::STRING &&
            kv.first->string_value == "total_width") {
            has_total_width = true;
            CHECK_EQ(kv.second->float_value, 0.0);
        }
    }
    CHECK(has_total_width);
    PASS();
}

// 43. Sandbox: Lua code cannot use dofile
static void test_43_sandbox_lua_dofile() {
    TEST("Lua code cannot access dofile");
    auto ctx = make_ctx();
    try {
        ctx.qamrpp_context().run("dofile('test')");
        FAIL("dofile should have thrown");
    } catch (const std::exception&) {
        PASS();
    }
}

// 44. Sandbox: Lua code can use safe functions
static void test_44_sandbox_lua_safe() {
    TEST("Lua code can use safe arithmetic");
    auto ctx = make_ctx();
    try {
        auto result = ctx.qamrpp_context().run("return 1 + 2");
        CHECK(result->int_value == 3);
        PASS();
    } catch (const std::exception& e) {
        FAIL(std::string("Unexpected error: ") + e.what());
    }
}

// 45. Sandboxed import: Lua require works through sandbox
static void test_45_lua_require_ljson() {
    TEST("Lua require('doxtk_ljson') works through sandbox");
    auto ctx = make_ctx();
    try {
        auto result = ctx.qamrpp_context().run(
            "local json = require('doxtk_ljson')\n"
            "return json.encode({a=1})\n"
        );
        CHECK(result->type == qamrpp::Value::STRING);
        CHECK_STR_EQ(result->string_value, "{\"a\":1}");
        PASS();
    } catch (const std::exception& e) {
        FAIL(std::string("Unexpected error: ") + e.what());
    }
}

// 46. HaruPdfService: set_font on page
static void test_46_pdf_set_font() {
    TEST("haru.pdf set_font sets font properties");
    auto ctx = make_ctx();
    auto pdf = ctx.qamrpp_context().globals["haru_pdf"];

    qamrpp::ValuePtr set_font_fn;
    for (const auto& kv : pdf->table_entries) {
        if (kv.first->type == qamrpp::Value::STRING &&
            kv.first->string_value == "set_font") {
            set_font_fn = kv.second;
        }
    }
    CHECK(set_font_fn != nullptr);

    auto page = qamrpp::Value::make_table();
    auto font_name = std::make_shared<qamrpp::Value>("Liberation Serif");
    auto size = std::make_shared<qamrpp::Value>(14.0);

    std::vector<qamrpp::ValuePtr> args = {page, font_name, size};
    auto result = set_font_fn->function_value(ctx.qamrpp_context(), args);

    bool has_font = false, has_size = false;
    for (const auto& kv : result->table_entries) {
        if (kv.first->type == qamrpp::Value::STRING &&
            kv.first->string_value == "_font_name") {
            has_font = true;
            CHECK_STR_EQ(kv.second->string_value, "Liberation Serif");
        }
        if (kv.first->type == qamrpp::Value::STRING &&
            kv.first->string_value == "_font_size") {
            has_size = true;
            CHECK_EQ(kv.second->float_value, 14.0);
        }
    }
    CHECK(has_font);
    CHECK(has_size);
    PASS();
}

/* ========================================================================
 * Main
 * ======================================================================== */

int main() {
    std::cout << "\n=== DoxTk Glue Layer Test Suite ===\n\n";

    test_01_context_init();
    test_02_sandbox_dofile();
    test_03_sandbox_loadfile();
    test_04_sandbox_load();
    test_05_sandbox_io();
    test_06_sandbox_os();
    test_07_sandbox_package();
    test_08_sandbox_debug();
    test_09_sandbox_os_date();
    test_10_sandbox_os_time();
    test_11_hs_json_registered();
    test_12_hs_json_encode();
    test_13_hs_json_decode();
    test_14_hs_clock_default();
    test_15_hs_clock_set_epoch();
    test_16_hs_pdf_registered();
    test_17_hs_pdf_create_document();
    test_18_hs_pdf_add_page_write_text();
    test_19_hs_font_registered();
    test_20_hs_font_measure_text();
    test_21_registry_register_find();
    test_22_registry_validate_version();
    test_23_registry_validate_missing();
    test_24_registry_service_names();
    test_25_sandbox_import_ljson();
    test_26_sandbox_import_denied();
    test_27_json_encode_types();
    test_28_json_encode_nested();
    test_29_json_encode_arrays();
    test_30_json_decode_types();
    test_31_json_decode_object();
    test_32_json_decode_array();
    test_33_json_roundtrip();
    test_34_glue_result_errors();
    test_35_resource_limits();
    test_36_contract_check_version();
    test_37_registry_uninstall();
    test_38_glue_ctx_kernel_path();
    test_39_clock_epoch_before_init();
    test_40_independent_contexts();
    test_41_pdf_serialize_empty();
    test_42_font_measure_empty();
    test_43_sandbox_lua_dofile();
    test_44_sandbox_lua_safe();
    test_45_lua_require_ljson();
    test_46_pdf_set_font();

    std::cout << "\n=== Results ===\n";
    std::cout << "Total:  " << tests_run << "\n";
    std::cout << "Passed: " << tests_passed << "\n";
    std::cout << "Failed: " << tests_failed << "\n\n";

    return (tests_failed > 0) ? 1 : 0;
}
