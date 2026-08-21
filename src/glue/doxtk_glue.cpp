#include "doxtk_glue.hpp"

#include <fontconfig/fontconfig.h>

#include <cmath>
#include <cstdio>
#include <fstream>
#include <sstream>

namespace doxtk {
namespace glue {

/* ========================================================================
 * Fontconfig helper functions
 * ======================================================================== */

static std::string PatternToJson(FcPattern* pat) {
    if (!pat) return "{}";
    auto result = qamrpp::Value::make_table();

    FcPatternIter iter;
    FcPatternIterStart(pat, &iter);
    do {
        if (!FcPatternIterIsValid(pat, &iter)) break;
        const char* obj = FcPatternIterGetObject(pat, &iter);
        if (!obj) continue;
        int count = FcPatternIterValueCount(pat, &iter);
        if (count <= 0) continue;

        FcValue v;
        FcValueBinding b;
        FcResult r = FcPatternIterGetValue(pat, &iter, 0, &v, &b);
        if (r != FcResultMatch) continue;

        qamrpp::ValuePtr val;
        switch (v.type) {
            case FcTypeString:
                val = std::make_shared<qamrpp::Value>(
                    std::string(reinterpret_cast<const char*>(v.u.s)));
                break;
            case FcTypeInteger:
                val = std::make_shared<qamrpp::Value>(
                    static_cast<double>(v.u.i));
                break;
            case FcTypeDouble:
                val = std::make_shared<qamrpp::Value>(v.u.d);
                break;
            case FcTypeBool:
                val = std::make_shared<qamrpp::Value>(v.u.b == FcTrue);
                break;
            default:
                val = std::make_shared<qamrpp::Value>(std::string(""));
                break;
        }
        result->table_entries.push_back({
            std::make_shared<qamrpp::Value>(std::string(obj)),
            val
        });
    } while (FcPatternIterNext(pat, &iter));

    return JsonUtil::encode(result);
}

static FcPattern* JsonToPattern(const std::string& json) {
    auto val = JsonUtil::decode(json);
    if (!val || val->type != qamrpp::Value::TABLE) {
        return FcPatternCreate();
    }

    auto pat = FcPatternCreate();
    for (const auto& kv : val->table_entries) {
        if (kv.first->type != qamrpp::Value::STRING) continue;
        const auto& key = kv.first->string_value;
        const auto& v = kv.second;

        switch (v->type) {
            case qamrpp::Value::STRING:
                FcPatternAddString(pat, key.c_str(),
                    reinterpret_cast<const FcChar8*>(v->string_value.c_str()));
                break;
            case qamrpp::Value::INT:
                FcPatternAddInteger(pat, key.c_str(),
                    static_cast<int>(v->int_value));
                break;
            case qamrpp::Value::FLOAT:
                FcPatternAddDouble(pat, key.c_str(), v->float_value);
                break;
            case qamrpp::Value::BOOL:
                FcPatternAddBool(pat, key.c_str(),
                    v->bool_value ? FcTrue : FcFalse);
                break;
            default:
                break;
        }
    }
    return pat;
}

static FcObjectSet* JsonToObjectSet(const std::string& json) {
    auto val = JsonUtil::decode(json);
    if (!val || val->type != qamrpp::Value::TABLE) {
        return nullptr;
    }

    auto os = FcObjectSetCreate();
    for (const auto& kv : val->table_entries) {
        const auto& v = kv.second;
        if (v->type == qamrpp::Value::STRING) {
            FcObjectSetAdd(os, v->string_value.c_str());
        }
    }
    return os;
}

/* ========================================================================
 * JsonUtil
 * ======================================================================== */

std::string JsonUtil::encode(const qamrpp::ValuePtr& val) {
    if (!val) return "null";

    switch (val->type) {
        case qamrpp::Value::NIL:
            return "null";
        case qamrpp::Value::BOOL:
            return val->bool_value ? "true" : "false";
        case qamrpp::Value::INT:
            return std::to_string(val->int_value);
        case qamrpp::Value::FLOAT: {
            double d = val->float_value;
            if (std::floor(d) == d && std::abs(d) < 9e15) {
                return std::to_string(static_cast<int64_t>(d));
            }
            std::ostringstream oss;
            oss << d;
            return oss.str();
        }
        case qamrpp::Value::STRING: {
            std::string out = "\"";
            for (char ch : val->string_value) {
                switch (ch) {
                    case '"':  out += "\\\""; break;
                    case '\\': out += "\\\\"; break;
                    case '\n': out += "\\n"; break;
                    case '\r': out += "\\r"; break;
                    case '\t': out += "\\t"; break;
                    default:
                        if (static_cast<unsigned char>(ch) < 0x20) {
                            char buf[8];
                            std::snprintf(buf, sizeof(buf),
                                          "\\u%04x",
                                          static_cast<unsigned char>(ch));
                            out += buf;
                        } else {
                            out += ch;
                        }
                }
            }
            out += '"';
            return out;
        }
        case qamrpp::Value::TABLE: {
            bool is_array = true;
            for (const auto& kv : val->table_entries) {
                if (kv.first->type != qamrpp::Value::INT &&
                    kv.first->type != qamrpp::Value::FLOAT) {
                    is_array = false;
                    break;
                }
            }

            if (is_array && !val->table_entries.empty()) {
                std::string out = "[";
                for (size_t i = 0; i < val->table_entries.size(); ++i) {
                    if (i > 0) out += ",";
                    out += encode(val->table_entries[i].second);
                }
                out += "]";
                return out;
            } else {
                std::string out = "{";
                bool first = true;
                for (size_t i = 0; i < val->table_entries.size(); ++i) {
                    if (!first) out += ",";
                    first = false;
                    out += encode(val->table_entries[i].first);
                    out += ":";
                    out += encode(val->table_entries[i].second);
                }
                out += "}";
                return out;
            }
        }
        case qamrpp::Value::FUNCTION:
        case qamrpp::Value::USERDATA:
        default:
            return "null";
    }
}

qamrpp::ValuePtr JsonUtil::decode(const std::string& text) {
    if (text.empty()) return std::make_shared<qamrpp::Value>();

    struct Parser {
        const std::string& src;
        size_t pos = 0;

        explicit Parser(const std::string& s) : src(s) {}

        void skip_ws() {
            while (pos < src.size() &&
                   (src[pos] == ' ' || src[pos] == '\t' ||
                    src[pos] == '\n' || src[pos] == '\r')) {
                ++pos;
            }
        }

        char peek() {
            skip_ws();
            return (pos < src.size()) ? src[pos] : '\0';
        }

        char advance() {
            skip_ws();
            return (pos < src.size()) ? src[pos++] : '\0';
        }

        qamrpp::ValuePtr parse_string() {
            advance(); // opening '"'
            std::string s;
            while (pos < src.size()) {
                char c = src[pos++];
                if (c == '"') break;
                if (c == '\\') {
                    if (pos >= src.size()) break;
                    char esc = src[pos++];
                    switch (esc) {
                        case '"':  s += '"'; break;
                        case '\\': s += '\\'; break;
                        case '/':  s += '/'; break;
                        case 'b':  s += '\b'; break;
                        case 'f':  s += '\f'; break;
                        case 'n':  s += '\n'; break;
                        case 'r':  s += '\r'; break;
                        case 't':  s += '\t'; break;
                        case 'u': {
                            if (pos + 4 > src.size()) break;
                            std::string hex = src.substr(pos, 4);
                            pos += 4;
                            unsigned cp = static_cast<unsigned>(
                                std::stoul(hex, nullptr, 16));
                            if (cp < 0x80) {
                                s += static_cast<char>(cp);
                            } else if (cp < 0x800) {
                                s += static_cast<char>(0xC0 | (cp >> 6));
                                s += static_cast<char>(0x80 | (cp & 0x3F));
                            } else {
                                s += static_cast<char>(0xE0 | (cp >> 12));
                                s += static_cast<char>(0x80 |
                                                       ((cp >> 6) & 0x3F));
                                s += static_cast<char>(0x80 |
                                                       (cp & 0x3F));
                            }
                            break;
                        }
                        default:
                            s += esc;
                            break;
                    }
                } else {
                    s += c;
                }
            }
            return std::make_shared<qamrpp::Value>(s);
        }

        qamrpp::ValuePtr parse_number() {
            skip_ws();
            size_t start = pos;
            bool is_float = false;
            if (pos < src.size() && src[pos] == '-') ++pos;
            while (pos < src.size() &&
                   std::isdigit(static_cast<unsigned char>(src[pos]))) ++pos;
            if (pos < src.size() && src[pos] == '.') {
                is_float = true;
                ++pos;
                while (pos < src.size() &&
                       std::isdigit(static_cast<unsigned char>(src[pos]))) ++pos;
            }
            if (pos < src.size() &&
                (src[pos] == 'e' || src[pos] == 'E')) {
                is_float = true;
                ++pos;
                if (pos < src.size() &&
                    (src[pos] == '+' || src[pos] == '-')) ++pos;
                while (pos < src.size() &&
                       std::isdigit(static_cast<unsigned char>(src[pos]))) ++pos;
            }
            std::string num = src.substr(start, pos - start);
            if (is_float) {
                return std::make_shared<qamrpp::Value>(std::stod(num));
            } else {
                return std::make_shared<qamrpp::Value>(
                    static_cast<int64_t>(std::stoll(num)));
            }
        }

        qamrpp::ValuePtr parse_bool() {
            if (pos + 4 <= src.size() && src.substr(pos, 4) == "true") {
                pos += 4;
                return std::make_shared<qamrpp::Value>(true);
            }
            if (pos + 5 <= src.size() && src.substr(pos, 5) == "false") {
                pos += 5;
                return std::make_shared<qamrpp::Value>(false);
            }
            throw std::runtime_error("Invalid JSON boolean");
        }

        qamrpp::ValuePtr parse_null() {
            if (pos + 4 <= src.size() && src.substr(pos, 4) == "null") {
                pos += 4;
                return std::make_shared<qamrpp::Value>();
            }
            throw std::runtime_error("Invalid JSON null");
        }

        qamrpp::ValuePtr parse_object() {
            advance(); // '{'
            auto obj = qamrpp::Value::make_table();
            if (peek() == '}') { advance(); return obj; }

            while (true) {
                auto key = parse_string();
                if (advance() != ':') {
                    throw std::runtime_error("Expected ':' in JSON object");
                }
                auto val = parse_value();
                obj->table_entries.push_back({key, val});

                char c = advance();
                if (c == '}') break;
                if (c != ',') {
                    throw std::runtime_error(
                        "Expected ',' or '}' in JSON object");
                }
            }
            return obj;
        }

        qamrpp::ValuePtr parse_array() {
            advance(); // '['
            auto arr = qamrpp::Value::make_table();
            int idx = 1;
            if (peek() == ']') { advance(); return arr; }

            while (true) {
                auto val = parse_value();
                arr->table_entries.push_back({
                    std::make_shared<qamrpp::Value>(
                        static_cast<int64_t>(idx++)),
                    val
                });

                char c = advance();
                if (c == ']') break;
                if (c != ',') {
                    throw std::runtime_error(
                        "Expected ',' or ']' in JSON array");
                }
            }
            return arr;
        }

        qamrpp::ValuePtr parse_value() {
            char c = peek();
            if (c == '{') return parse_object();
            if (c == '[') return parse_array();
            if (c == '"') return parse_string();
            if (c == 't' || c == 'f') return parse_bool();
            if (c == 'n') return parse_null();
            if (c == '-' || (c >= '0' && c <= '9')) return parse_number();
            throw std::runtime_error("Unexpected JSON token: " +
                                     std::string(1, c));
        }
    };

    try {
        Parser parser(text);
        auto result = parser.parse_value();
        return result;
    } catch (const std::exception&) {
        auto fallback = qamrpp::Value::make_table();
        fallback->table_entries.push_back({
            std::make_shared<qamrpp::Value>("raw"),
            std::make_shared<qamrpp::Value>(text)
        });
        return fallback;
    }
}

/* ========================================================================
 * JsonService
 * ======================================================================== */

GlueResult JsonService::register_with(qamrpp::Context& ctx) {
    auto service_table = qamrpp::Value::make_table();

    qamrpp::NativeFn encode_fn =
        [](qamrpp::Context&, std::vector<qamrpp::ValuePtr>& args) -> qamrpp::ValuePtr {
            if (args.empty()) return qamrpp::Value::make_table();
            return std::make_shared<qamrpp::Value>(JsonUtil::encode(args[0]));
        };

    qamrpp::NativeFn decode_fn =
        [](qamrpp::Context&, std::vector<qamrpp::ValuePtr>& args) -> qamrpp::ValuePtr {
            if (args.empty() || args[0]->type != qamrpp::Value::STRING)
                return qamrpp::Value::make_table();
            return JsonUtil::decode(args[0]->string_value);
        };

    service_table->table_entries.push_back({
        std::make_shared<qamrpp::Value>("encode"),
        std::make_shared<qamrpp::Value>(encode_fn)
    });
    service_table->table_entries.push_back({
        std::make_shared<qamrpp::Value>("decode"),
        std::make_shared<qamrpp::Value>(decode_fn)
    });

    ctx.globals["doxtk_json"] = service_table;
    return GlueResult::success();
}

/* ========================================================================
 * FontconfigService
 * ======================================================================== */

GlueResult FontconfigService::register_with(qamrpp::Context& ctx) {
    auto fc_table = qamrpp::Value::make_table();

    /* --- fc.init() --- */
    qamrpp::NativeFn init_fn =
        [](qamrpp::Context&, std::vector<qamrpp::ValuePtr>&) -> qamrpp::ValuePtr {
            FcInit();
            return std::make_shared<qamrpp::Value>(true);
        };
    fc_table->table_entries.push_back({
        std::make_shared<qamrpp::Value>("init"),
        std::make_shared<qamrpp::Value>(init_fn)
    });

    /* --- fc.parse(name) -> pattern_json --- */
    qamrpp::NativeFn parse_fn =
        [](qamrpp::Context&, std::vector<qamrpp::ValuePtr>& args) -> qamrpp::ValuePtr {
            if (args.empty() || args[0]->type != qamrpp::Value::STRING) {
                return qamrpp::Value::make_table();
            }
            auto pat = FcNameParse(reinterpret_cast<const FcChar8*>(
                args[0]->string_value.c_str()));
            if (!pat) return qamrpp::Value::make_table();
            auto result = PatternToJson(pat);
            FcPatternDestroy(pat);
            return result;
        };
    fc_table->table_entries.push_back({
        std::make_shared<qamrpp::Value>("parse"),
        std::make_shared<qamrpp::Value>(parse_fn)
    });

    /* --- fc.match(pattern_json) -> font_info_json --- */
    qamrpp::NativeFn match_fn =
        [](qamrpp::Context&, std::vector<qamrpp::ValuePtr>& args) -> qamrpp::ValuePtr {
            if (args.empty() || args[0]->type != qamrpp::Value::STRING) {
                return qamrpp::Value::make_table();
            }
            auto pattern = JsonToPattern(args[0]->string_value);
            if (!pattern) return qamrpp::Value::make_table();

            FcConfigSubstitute(nullptr, pattern, FcMatchPattern);
            FcDefaultSubstitute(pattern);

            FcResult result = FcResultNoMatch;
            auto matched = FcFontMatch(nullptr, pattern, &result);
            FcPatternDestroy(pattern);

            if (!matched) return qamrpp::Value::make_table();
            auto out = PatternToJson(matched);
            FcPatternDestroy(matched);
            return out;
        };
    fc_table->table_entries.push_back({
        std::make_shared<qamrpp::Value>("match"),
        std::make_shared<qamrpp::Value>(match_fn)
    });

    /* --- fc.list(pattern_json, objects_json) -> [font_info_json, ...] --- */
    qamrpp::NativeFn list_fn =
        [](qamrpp::Context&, std::vector<qamrpp::ValuePtr>& args) -> qamrpp::ValuePtr {
            FcPattern* pattern = nullptr;
            if (args.size() >= 1 && args[0]->type == qamrpp::Value::STRING &&
                !args[0]->string_value.empty()) {
                pattern = JsonToPattern(args[0]->string_value);
            }
            if (!pattern) {
                pattern = FcPatternCreate();
            }

            FcObjectSet* os = nullptr;
            if (args.size() >= 2 && args[1]->type == qamrpp::Value::STRING &&
                !args[1]->string_value.empty()) {
                os = JsonToObjectSet(args[1]->string_value);
            }
            if (!os) {
                os = FcObjectSetBuild(FC_FAMILY, FC_STYLE, FC_FILE, FC_INDEX,
                                      FC_WEIGHT, FC_SLANT, FC_WIDTH,
                                      FC_SCALABLE, FC_FONTVERSION, (char*)nullptr);
            }

            auto font_set = FcFontList(nullptr, pattern, os);
            FcPatternDestroy(pattern);
            FcObjectSetDestroy(os);

            auto arr = qamrpp::Value::make_table();
            if (font_set) {
                for (int i = 0; i < font_set->nfont; ++i) {
                    auto info = PatternToJson(font_set->fonts[i]);
                    arr->table_entries.push_back({
                        std::make_shared<qamrpp::Value>(
                            static_cast<double>(i + 1)),
                        info
                    });
                }
                FcFontSetDestroy(font_set);
            }
            return arr;
        };
    fc_table->table_entries.push_back({
        std::make_shared<qamrpp::Value>("list"),
        std::make_shared<qamrpp::Value>(list_fn)
    });

    /* --- fc.sort(pattern_json, objects_json) -> [font_info_json, ...] --- */
    qamrpp::NativeFn sort_fn =
        [](qamrpp::Context&, std::vector<qamrpp::ValuePtr>& args) -> qamrpp::ValuePtr {
            if (args.empty() || args[0]->type != qamrpp::Value::STRING) {
                return qamrpp::Value::make_table();
            }
            auto pattern = JsonToPattern(args[0]->string_value);
            if (!pattern) return qamrpp::Value::make_table();

            FcConfigSubstitute(nullptr, pattern, FcMatchPattern);
            FcDefaultSubstitute(pattern);

            FcObjectSet* os = nullptr;
            if (args.size() >= 2 && args[1]->type == qamrpp::Value::STRING &&
                !args[1]->string_value.empty()) {
                os = JsonToObjectSet(args[1]->string_value);
            }
            if (!os) {
                os = FcObjectSetBuild(FC_FAMILY, FC_STYLE, FC_FILE, FC_INDEX,
                                      FC_WEIGHT, FC_SLANT, FC_WIDTH,
                                      FC_SCALABLE, FC_FONTVERSION, (char*)nullptr);
            }

            FcResult result = FcResultNoMatch;
            auto font_set = FcFontSort(nullptr, pattern, FcTrue, nullptr, &result);
            FcPatternDestroy(pattern);
            FcObjectSetDestroy(os);

            auto arr = qamrpp::Value::make_table();
            if (font_set) {
                for (int i = 0; i < font_set->nfont; ++i) {
                    auto info = PatternToJson(font_set->fonts[i]);
                    arr->table_entries.push_back({
                        std::make_shared<qamrpp::Value>(
                            static_cast<double>(i + 1)),
                        info
                    });
                }
                FcFontSetDestroy(font_set);
            }
            return arr;
        };
    fc_table->table_entries.push_back({
        std::make_shared<qamrpp::Value>("sort"),
        std::make_shared<qamrpp::Value>(sort_fn)
    });

    /* --- fc.substitute(pattern_json) -> pattern_json --- */
    qamrpp::NativeFn substitute_fn =
        [](qamrpp::Context&, std::vector<qamrpp::ValuePtr>& args) -> qamrpp::ValuePtr {
            if (args.empty() || args[0]->type != qamrpp::Value::STRING) {
                return qamrpp::Value::make_table();
            }
            auto pattern = JsonToPattern(args[0]->string_value);
            if (!pattern) return qamrpp::Value::make_table();

            FcConfigSubstitute(nullptr, pattern, FcMatchPattern);
            FcDefaultSubstitute(pattern);

            auto result = PatternToJson(pattern);
            FcPatternDestroy(pattern);
            return result;
        };
    fc_table->table_entries.push_back({
        std::make_shared<qamrpp::Value>("substitute"),
        std::make_shared<qamrpp::Value>(substitute_fn)
    });

    /* --- fc.render_prepare(pattern_json) -> pattern_json --- */
    qamrpp::NativeFn render_prepare_fn =
        [](qamrpp::Context&, std::vector<qamrpp::ValuePtr>& args) -> qamrpp::ValuePtr {
            if (args.empty() || args[0]->type != qamrpp::Value::STRING) {
                return qamrpp::Value::make_table();
            }
            auto pattern = JsonToPattern(args[0]->string_value);
            if (!pattern) return qamrpp::Value::make_table();

            auto rendered = FcFontRenderPrepare(nullptr, pattern, pattern);
            FcPatternDestroy(pattern);
            if (!rendered) return qamrpp::Value::make_table();
            auto result = PatternToJson(rendered);
            FcPatternDestroy(rendered);
            return result;
        };
    fc_table->table_entries.push_back({
        std::make_shared<qamrpp::Value>("render_prepare"),
        std::make_shared<qamrpp::Value>(render_prepare_fn)
    });

    ctx.globals["fontconfig"] = fc_table;
    return GlueResult::success();
}

/* ========================================================================
 * ClockService
 * ======================================================================== */

GlueResult ClockService::register_with(qamrpp::Context& ctx) {
    auto* epoch_ptr = &fixed_epoch_;

    qamrpp::NativeFn clock_fn =
        [epoch_ptr](qamrpp::Context&, std::vector<qamrpp::ValuePtr>&) -> qamrpp::ValuePtr {
            return std::make_shared<qamrpp::Value>(
                static_cast<double>(*epoch_ptr));
        };

    ctx.globals["doxtk_clock"] =
        std::make_shared<qamrpp::Value>(clock_fn);
    return GlueResult::success();
}

/* ========================================================================
 * HaruPdfService
 * ======================================================================== */

GlueResult HaruPdfService::register_with(qamrpp::Context& ctx) {
    auto pdf_table = qamrpp::Value::make_table();

    qamrpp::NativeFn create_fn =
        [](qamrpp::Context&, std::vector<qamrpp::ValuePtr>&) -> qamrpp::ValuePtr {
            auto doc = qamrpp::Value::make_table();
            doc->table_entries.push_back({
                std::make_shared<qamrpp::Value>("pages"),
                qamrpp::Value::make_table()
            });
            return doc;
        };

    qamrpp::NativeFn add_page_fn =
        [](qamrpp::Context&, std::vector<qamrpp::ValuePtr>& args) -> qamrpp::ValuePtr {
            if (args.size() < 2) return qamrpp::Value::make_table();
            auto& doc = args[0];
            auto& page = args[1];
            for (auto& kv : doc->table_entries) {
                if (kv.first->type == qamrpp::Value::STRING &&
                    kv.first->string_value == "pages" &&
                    kv.second->type == qamrpp::Value::TABLE) {
                    kv.second->table_entries.push_back(
                        {qamrpp::Value::make_table(), page});
                    break;
                }
            }
            return page;
        };

    qamrpp::NativeFn set_font_fn =
        [](qamrpp::Context&, std::vector<qamrpp::ValuePtr>& args) -> qamrpp::ValuePtr {
            if (args.size() < 3) return qamrpp::Value::make_table();
            auto& page = args[0];
            page->table_entries.push_back({
                std::make_shared<qamrpp::Value>("_font_name"), args[1]
            });
            page->table_entries.push_back({
                std::make_shared<qamrpp::Value>("_font_size"), args[2]
            });
            return page;
        };

    qamrpp::NativeFn write_text_fn =
        [](qamrpp::Context&, std::vector<qamrpp::ValuePtr>& args) -> qamrpp::ValuePtr {
            if (args.size() < 4) return qamrpp::Value::make_table();
            auto& page = args[0];

            auto cmd = qamrpp::Value::make_table();
            cmd->table_entries.push_back({
                std::make_shared<qamrpp::Value>("op"),
                std::make_shared<qamrpp::Value>("text")
            });
            cmd->table_entries.push_back({
                std::make_shared<qamrpp::Value>("x"), args[1]
            });
            cmd->table_entries.push_back({
                std::make_shared<qamrpp::Value>("y"), args[2]
            });
            cmd->table_entries.push_back({
                std::make_shared<qamrpp::Value>("content"), args[3]
            });

            bool found = false;
            for (auto& kv : page->table_entries) {
                if (kv.first->type == qamrpp::Value::STRING &&
                    kv.first->string_value == "_commands" &&
                    kv.second->type == qamrpp::Value::TABLE) {
                    kv.second->table_entries.push_back(
                        {qamrpp::Value::make_table(), cmd});
                    found = true;
                    break;
                }
            }
            if (!found) {
                auto cmds = qamrpp::Value::make_table();
                cmds->table_entries.push_back(
                    {qamrpp::Value::make_table(), cmd});
                page->table_entries.push_back({
                    std::make_shared<qamrpp::Value>("_commands"), cmds
                });
            }
            return page;
        };

    qamrpp::NativeFn serialize_fn =
        [](qamrpp::Context&, std::vector<qamrpp::ValuePtr>& args) -> qamrpp::ValuePtr {
            if (args.empty()) {
                return std::make_shared<qamrpp::Value>("");
            }
            return std::make_shared<qamrpp::Value>(JsonUtil::encode(args[0]));
        };

    pdf_table->table_entries.push_back({
        std::make_shared<qamrpp::Value>("create_document"),
        std::make_shared<qamrpp::Value>(create_fn)
    });
    pdf_table->table_entries.push_back({
        std::make_shared<qamrpp::Value>("add_page"),
        std::make_shared<qamrpp::Value>(add_page_fn)
    });
    pdf_table->table_entries.push_back({
        std::make_shared<qamrpp::Value>("set_font"),
        std::make_shared<qamrpp::Value>(set_font_fn)
    });
    pdf_table->table_entries.push_back({
        std::make_shared<qamrpp::Value>("write_text"),
        std::make_shared<qamrpp::Value>(write_text_fn)
    });
    pdf_table->table_entries.push_back({
        std::make_shared<qamrpp::Value>("serialize"),
        std::make_shared<qamrpp::Value>(serialize_fn)
    });

    ctx.globals["haru_pdf"] = pdf_table;
    return GlueResult::success();
}

/* ========================================================================
 * HaruFontService
 * ======================================================================== */

GlueResult HaruFontService::register_with(qamrpp::Context& ctx) {
    auto font_table = qamrpp::Value::make_table();

    qamrpp::NativeFn measure_fn =
        [](qamrpp::Context&, std::vector<qamrpp::ValuePtr>& args) -> qamrpp::ValuePtr {
            auto result = qamrpp::Value::make_table();

            if (args.size() < 2) {
                result->table_entries.push_back({
                    std::make_shared<qamrpp::Value>("glyphs"),
                    qamrpp::Value::make_table()
                });
                return result;
            }

            auto& text = args[0];
            auto& font_spec = args[1];

            std::string text_str =
                (text->type == qamrpp::Value::STRING)
                    ? text->string_value : "";

            double font_size = 12.0;
            if (font_spec->type == qamrpp::Value::TABLE) {
                for (const auto& kv : font_spec->table_entries) {
                    if (kv.first->type == qamrpp::Value::STRING &&
                        kv.first->string_value == "size") {
                        if (kv.second->type == qamrpp::Value::FLOAT)
                            font_size = kv.second->float_value;
                        else if (kv.second->type == qamrpp::Value::INT)
                            font_size = static_cast<double>(
                                kv.second->int_value);
                        break;
                    }
                }
            }

            auto glyphs = qamrpp::Value::make_table();
            double x = 0.0;
            for (size_t i = 0; i < text_str.size(); ++i) {
                double advance = font_size * 0.6;
                auto glyph = qamrpp::Value::make_table();
                auto ch = std::string(1, text_str[i]);
                glyph->table_entries.push_back({
                    std::make_shared<qamrpp::Value>("char"),
                    std::make_shared<qamrpp::Value>(ch)
                });
                glyph->table_entries.push_back({
                    std::make_shared<qamrpp::Value>("width"),
                    std::make_shared<qamrpp::Value>(advance)
                });
                glyph->table_entries.push_back({
                    std::make_shared<qamrpp::Value>("x"),
                    std::make_shared<qamrpp::Value>(x)
                });
                glyph->table_entries.push_back({
                    std::make_shared<qamrpp::Value>("height"),
                    std::make_shared<qamrpp::Value>(font_size)
                });

                glyphs->table_entries.push_back({
                    std::make_shared<qamrpp::Value>(
                        static_cast<int64_t>(i + 1)),
                    glyph
                });
                x += advance;
            }

            result->table_entries.push_back({
                std::make_shared<qamrpp::Value>("glyphs"), glyphs
            });
            result->table_entries.push_back({
                std::make_shared<qamrpp::Value>("total_width"),
                std::make_shared<qamrpp::Value>(x)
            });
            result->table_entries.push_back({
                std::make_shared<qamrpp::Value>("total_height"),
                std::make_shared<qamrpp::Value>(font_size)
            });

            return result;
        };

    font_table->table_entries.push_back({
        std::make_shared<qamrpp::Value>("measure_text"),
        std::make_shared<qamrpp::Value>(measure_fn)
    });

    ctx.globals["haru_font"] = font_table;
    return GlueResult::success();
}

/* ========================================================================
 * HostServiceRegistry
 * ======================================================================== */

void HostServiceRegistry::register_service(
    std::unique_ptr<HostService> service) {
    services_[service->contract().name] = std::move(service);
}

HostService* HostServiceRegistry::find(const std::string& name) {
    auto it = services_.find(name);
    return (it != services_.end()) ? it->second.get() : nullptr;
}

GlueResult HostServiceRegistry::validate_service_request(
    const std::string& name, const std::string& version) {
    auto* svc = find(name);
    if (!svc) {
        return GlueResult::failure(GlueError::HostServiceNotFound,
            "Host service not found: " + name);
    }
    if (!svc->check_version(version)) {
        return GlueResult::failure(GlueError::HostServiceVersionMismatch,
            "Host service version mismatch: " + name +
            " requested " + version +
            " but " + svc->contract().version + " is available");
    }
    return GlueResult::success();
}

GlueResult HostServiceRegistry::install_all(qamrpp::Context& ctx) {
    for (auto& kv : services_) {
        auto result = kv.second->register_with(ctx);
        if (!result.ok()) return result;
    }
    return GlueResult::success();
}

void HostServiceRegistry::uninstall_all(qamrpp::Context& ctx) {
    for (auto& kv : services_) {
        kv.second->unregister_from(ctx);
    }
}

std::vector<std::string> HostServiceRegistry::service_names() const {
    std::vector<std::string> names;
    for (const auto& kv : services_) {
        names.push_back(kv.first);
    }
    return names;
}

/* ========================================================================
 * GlueContext
 * ======================================================================== */

GlueContext::GlueContext(const std::string& kernel_base_path)
    : kernel_base_path_(kernel_base_path) {
    clock_service_ = std::make_unique<ClockService>();
}

void GlueContext::set_clock_epoch(int64_t epoch) {
    clock_service_->set_epoch(epoch);
}

GlueResult GlueContext::initialise() {
    setup_sandbox();
    auto reg_result = register_builtin_services();
    if (!reg_result.ok()) return reg_result;
    auto svc_result = registry_.install_all(ctx_);
    if (!svc_result.ok()) return svc_result;
    return install_sandboxed_import();
}

GlueResult GlueContext::setup_sandbox() {
    auto nil_val = std::make_shared<qamrpp::Value>();

    ctx_.globals["dofile"] = nil_val;
    ctx_.globals["loadfile"] = nil_val;
    ctx_.globals["load"] = nil_val;
    ctx_.globals["require"] = nil_val;
    ctx_.globals["io"] = nil_val;

    auto os_table = qamrpp::Value::make_table();
    qamrpp::NativeFn safe_date =
        [](qamrpp::Context&, std::vector<qamrpp::ValuePtr>&) -> qamrpp::ValuePtr {
            return std::make_shared<qamrpp::Value>("1970-01-01");
        };
    qamrpp::NativeFn safe_time =
        [](qamrpp::Context&, std::vector<qamrpp::ValuePtr>&) -> qamrpp::ValuePtr {
            return std::make_shared<qamrpp::Value>(0.0);
        };
    os_table->table_entries.push_back({
        std::make_shared<qamrpp::Value>("date"),
        std::make_shared<qamrpp::Value>(safe_date)
    });
    os_table->table_entries.push_back({
        std::make_shared<qamrpp::Value>("time"),
        std::make_shared<qamrpp::Value>(safe_time)
    });
    ctx_.globals["os"] = os_table;

    ctx_.globals["package"] = nil_val;
    ctx_.globals["debug"] = nil_val;

    return GlueResult::success();
}

GlueResult GlueContext::register_builtin_services() {
    registry_.register_service(std::make_unique<JsonService>());
    registry_.register_service(std::make_unique<ClockService>());
    registry_.register_service(std::make_unique<FontconfigService>());
    registry_.register_service(std::make_unique<HaruPdfService>());
    registry_.register_service(std::make_unique<HaruFontService>());

    auto* clock = registry_.find("doxtk.clock");
    if (clock) {
        clock_service_.reset(static_cast<ClockService*>(clock));
    }

    return GlueResult::success();
}

GlueResult GlueContext::install_sandboxed_import() {
    qamrpp::NativeFn sandboxed_require =
        [](qamrpp::Context& c,
           std::vector<qamrpp::ValuePtr>& args) -> qamrpp::ValuePtr {
            if (args.empty() || args[0]->type != qamrpp::Value::STRING) {
                return qamrpp::Value::make_table();
            }

            std::string lib_name = args[0]->string_value;

            if (lib_name == "doxtk_ljson") {
                auto mod = qamrpp::Value::make_table();
                qamrpp::NativeFn enc_fn =
                    [](qamrpp::Context&,
                       std::vector<qamrpp::ValuePtr>& a) -> qamrpp::ValuePtr {
                        if (a.empty())
                            return std::make_shared<qamrpp::Value>("null");
                        return std::make_shared<qamrpp::Value>(
                            JsonUtil::encode(a[0]));
                    };
                qamrpp::NativeFn dec_fn =
                    [](qamrpp::Context&,
                       std::vector<qamrpp::ValuePtr>& a) -> qamrpp::ValuePtr {
                        if (a.empty() ||
                            a[0]->type != qamrpp::Value::STRING) {
                            return qamrpp::Value::make_table();
                        }
                        return JsonUtil::decode(a[0]->string_value);
                    };
                mod->table_entries.push_back({
                    std::make_shared<qamrpp::Value>("encode"),
                    std::make_shared<qamrpp::Value>(enc_fn)
                });
                mod->table_entries.push_back({
                    std::make_shared<qamrpp::Value>("decode"),
                    std::make_shared<qamrpp::Value>(dec_fn)
                });
                return mod;
            }

            return qamrpp::Value::make_table();
        };

    ctx_.globals["require"] =
        std::make_shared<qamrpp::Value>(sandboxed_require);

    return GlueResult::success();
}

std::string GlueContext::read_file(const std::string& path) {
    std::ifstream file(path);
    if (!file.is_open()) {
        throw std::runtime_error("Cannot open file: " + path);
    }
    std::stringstream buffer;
    buffer << file.rdbuf();
    return buffer.str();
}

GlueResult GlueContext::load_kernel_module(
    const std::string& kernel_path,
    qamrpp::ValuePtr& out_module) {
    std::string source;
    try {
        source = read_file(kernel_base_path_ + "/" + kernel_path);
    } catch (const std::exception& e) {
        return GlueResult::failure(GlueError::KernelLoadFailed,
            "Failed to read kernel: " + std::string(e.what()));
    }

    try {
        out_module = ctx_.run(source);
    } catch (const std::exception& e) {
        return GlueResult::failure(GlueError::KernelLoadFailed,
            "Failed to load kernel: " + std::string(e.what()));
    }

    if (!out_module || out_module->type != qamrpp::Value::TABLE) {
        return GlueResult::failure(GlueError::KernelLoadFailed,
            "Kernel did not return a module table: " + kernel_path);
    }

    return GlueResult::success();
}

GlueContext::KernelOutput GlueContext::load_kernel(
    const std::string& kernel_path) {
    KernelOutput out;
    out.error = load_kernel_module(kernel_path, out.raw_value);
    if (out.error.ok() && out.raw_value) {
        out.raw_json = JsonUtil::encode(out.raw_value);
    }
    return out;
}

GlueResult GlueContext::advertise_kernel(
    const std::string& kernel_path, std::string& out_json) {
    qamrpp::ValuePtr module;
    auto load_result = load_kernel_module(kernel_path, module);
    if (!load_result.ok()) return load_result;

    bool found = false;
    qamrpp::ValuePtr advertise_fn;
    for (const auto& kv : module->table_entries) {
        if (kv.first->type == qamrpp::Value::STRING &&
            kv.first->string_value == "advertise") {
            advertise_fn = kv.second;
            found = true;
            break;
        }
    }
    if (!found || !advertise_fn ||
        advertise_fn->type != qamrpp::Value::FUNCTION) {
        return GlueResult::failure(GlueError::KernelAdvertiseFailed,
            "Kernel does not expose an advertise function: " +
            kernel_path);
    }

    try {
        std::vector<qamrpp::ValuePtr> empty_args;
        auto result = advertise_fn->function_value(ctx_, empty_args);
        out_json = JsonUtil::encode(result);
    } catch (const std::exception& e) {
        return GlueResult::failure(GlueError::KernelAdvertiseFailed,
            "advertise() failed: " + std::string(e.what()));
    }

    return GlueResult::success();
}

GlueContext::KernelOutput GlueContext::invoke_capability(
    const CapabilityCall& call) {
    KernelOutput out;

    qamrpp::ValuePtr module;
    out.error = load_kernel_module(call.kernel_path, module);
    if (!out.error.ok()) return out;

    bool found = false;
    qamrpp::ValuePtr cap_fn;
    for (const auto& kv : module->table_entries) {
        if (kv.first->type == qamrpp::Value::STRING &&
            kv.first->string_value == call.capability_name) {
            cap_fn = kv.second;
            found = true;
            break;
        }
    }
    if (!found || !cap_fn ||
        cap_fn->type != qamrpp::Value::FUNCTION) {
        out.error = GlueResult::failure(GlueError::CapabilityNotFound,
            "Capability not found in kernel: " + call.capability_name);
        return out;
    }

    try {
        auto inputs = JsonUtil::decode(call.input_json);
        std::vector<qamrpp::ValuePtr> args = {inputs};
        auto result = cap_fn->function_value(ctx_, args);
        out.raw_value = result;
        out.raw_json = JsonUtil::encode(result);
    } catch (const std::exception& e) {
        out.error = GlueResult::failure(GlueError::InternalError,
            "Capability invocation failed: " + std::string(e.what()));
    }

    return out;
}

} // namespace glue
} // namespace doxtk
