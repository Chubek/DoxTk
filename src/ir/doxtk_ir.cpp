#include "doxtk_ir.hpp"

#include <algorithm>
#include <sstream>
#include <stdexcept>

namespace doxtk {
namespace ir {

/* ========================================================================
 * JSON helpers (standalone, no dependency on QaMRpp)
 * ======================================================================== */

namespace {

/* Minimal JSON writer for attribute values. */
void json_escape(std::ostringstream& oss, const std::string& s) {
    oss << '"';
    for (char ch : s) {
        switch (ch) {
            case '"':  oss << "\\\""; break;
            case '\\': oss << "\\\\"; break;
            case '\n': oss << "\\n"; break;
            case '\r': oss << "\\r"; break;
            case '\t': oss << "\\t"; break;
            default:
                if (static_cast<unsigned char>(ch) < 0x20) {
                    char buf[8];
                    std::snprintf(buf, sizeof(buf), "\\u%04x",
                                  static_cast<unsigned int>(
                                      static_cast<unsigned char>(ch)));
                    oss << buf;
                } else {
                    oss << ch;
                }
                break;
        }
    }
    oss << '"';
}

void write_attr_value(std::ostringstream& oss, const IRAttrValue& val) {
    std::visit([&oss](const auto& v) {
        using T = std::decay_t<decltype(v)>;
        if constexpr (std::is_same_v<T, std::nullptr_t>) {
            oss << "null";
        } else if constexpr (std::is_same_v<T, bool>) {
            oss << (v ? "true" : "false");
        } else if constexpr (std::is_same_v<T, int64_t>) {
            oss << v;
        } else if constexpr (std::is_same_v<T, double>) {
            if (std::floor(v) == v && std::abs(v) < 9e15) {
                oss << static_cast<int64_t>(v);
            } else {
                oss << v;
            }
        } else if constexpr (std::is_same_v<T, std::string>) {
            json_escape(oss, v);
        } else if constexpr (std::is_same_v<T, std::vector<std::string>>) {
            oss << "[";
            for (size_t i = 0; i < v.size(); ++i) {
                if (i > 0) oss << ",";
                json_escape(oss, v[i]);
            }
            oss << "]";
        } else if constexpr (std::is_same_v<T, std::map<std::string, std::string>>) {
            oss << "{";
            bool first = true;
            for (const auto& [k, sv] : v) {
                if (!first) oss << ",";
                first = false;
                json_escape(oss, k);
                oss << ":";
                json_escape(oss, sv);
            }
            oss << "}";
        }
    }, val);
}

/* Minimal JSON parser for attribute values.
 * Returns a string "error:..." on parse failure. */
struct JsonParser {
    const std::string& text;
    size_t pos = 0;

    explicit JsonParser(const std::string& t) : text(t) {}

    char peek() const {
        while (pos < text.size() && std::isspace(static_cast<unsigned char>(text[pos])))
            pos++;
        if (pos >= text.size()) return '\0';
        return text[pos];
    }

    char consume() {
        char c = peek();
        if (c != '\0') pos++;
        return c;
    }

    void expect(char c) {
        if (peek() != c) {
            throw std::runtime_error(
                std::string("Expected '") + c + "' at position " +
                std::to_string(pos));
        }
        pos++;
    }

    std::string parse_string() {
        expect('"');
        std::string result;
        while (pos < text.size() && text[pos] != '"') {
            if (text[pos] == '\\') {
                pos++;
                if (pos >= text.size()) break;
                switch (text[pos]) {
                    case '"':  result += '"'; break;
                    case '\\': result += '\\'; break;
                    case 'n':  result += '\n'; break;
                    case 'r':  result += '\r'; break;
                    case 't':  result += '\t'; break;
                    default:   result += text[pos]; break;
                }
            } else {
                result += text[pos];
            }
            pos++;
        }
        expect('"');
        return result;
    }

    IRAttrValue parse_value() {
        char c = peek();
        switch (c) {
            case 'n':
                pos += 4; // "null"
                return nullptr;
            case 't':
                pos += 4; // "true"
                return true;
            case 'f':
                pos += 5; // "false"
                return false;
            case '"':
                return parse_string();
            case '[': {
                consume(); // '['
                std::vector<std::string> arr;
                while (peek() != ']') {
                    arr.push_back(parse_string());
                    if (peek() == ',') consume();
                }
                consume(); // ']'
                return arr;
            }
            case '{': {
                consume(); // '{'
                std::map<std::string, std::string> obj;
                while (peek() != '}') {
                    auto key = parse_string();
                    expect(':');
                    auto val = parse_string();
                    obj[key] = val;
                    if (peek() == ',') consume();
                }
                consume(); // '}'
                return obj;
            }
            default: {
                /* number */
                std::string num;
                bool is_float = false;
                while (pos < text.size()) {
                    char dc = text[pos];
                    if (std::isdigit(static_cast<unsigned char>(dc)) ||
                        dc == '-' || dc == '+' || dc == '.') {
                        if (dc == '.') is_float = true;
                        num += dc;
                        pos++;
                    } else {
                        break;
                    }
                }
                if (is_float) {
                    return std::stod(num);
                } else {
                    return static_cast<int64_t>(std::stoll(num));
                }
            }
        }
    }
};

} // anonymous namespace

/* ========================================================================
 * IRGraph construction
 * ======================================================================== */

IRGraph& IRGraph::set_root(const std::string& root_id) {
    if (sealed_) {
        throw std::runtime_error("IRGraph: cannot set_root on a sealed graph");
    }
    root_ = root_id;
    return *this;
}

bool IRGraph::add_node(IRNode node) {
    if (sealed_) return false;
    if (node.id.empty()) return false;
    if (nodes_.count(node.id) > 0) return false;
    nodes_[node.id] = std::move(node);
    return true;
}

bool IRGraph::remove_node(const std::string& id) {
    if (sealed_) return false;
    nodes_.erase(id);
    /* Clean up dangling references */
    for (auto& [nid, node] : nodes_) {
        node.children.erase(
            std::remove(node.children.begin(), node.children.end(), id),
            node.children.end());
    }
    return true;
}

/* ========================================================================
 * IRGraph query
 * ======================================================================== */

const IRNode* IRGraph::get_node(const std::string& id) const {
    auto it = nodes_.find(id);
    if (it == nodes_.end()) return nullptr;
    return &it->second;
}

bool IRGraph::has_node(const std::string& id) const {
    return nodes_.count(id) > 0;
}

/* ========================================================================
 * IRGraph immutability
 * ======================================================================== */

void IRGraph::seal() {
    sealed_ = true;
}

/* ========================================================================
 * IRGraph validation
 * ======================================================================== */

IRValidationResult IRGraph::validate() const {
    IRValidationResult result = IRValidationResult::ok();

    /* 1. Root node must exist */
    if (root_.empty()) {
        result.add_error("Root node id is empty");
    } else if (!has_node(root_)) {
        result.add_error("Root node '" + root_ + "' not found in nodes");
    }

    /* 2. Every node must have non-empty id and type */
    for (const auto& [nid, node] : nodes_) {
        if (node.id.empty()) {
            result.add_error("Node has empty id");
        }
        if (node.type.empty()) {
            result.add_error("Node '" + nid + "' has empty type");
        }
        if (node.id != nid) {
            result.add_error("Node '" + nid + "' has id field '" +
                             node.id + "' which does not match its key");
        }
    }

    /* 3. All child references must resolve */
    for (const auto& [nid, node] : nodes_) {
        for (size_t i = 0; i < node.children.size(); ++i) {
            const auto& child_id = node.children[i];
            if (!has_node(child_id)) {
                result.add_error("Node '" + nid + "'.children[" +
                                 std::to_string(i) + "]: '" + child_id +
                                 "' not found in nodes");
            }
        }
    }

    /* 4. Cycle detection (DAG) */
    std::unordered_map<std::string, VisitState> state;
    for (const auto& [nid, node] : nodes_) {
        state[nid] = VisitState::Unvisited;
    }

    for (const auto& [nid, node] : nodes_) {
        if (state[nid] == VisitState::Unvisited) {
            if (has_cycle_dfs(nid, state)) {
                result.add_error("Cycle detected in graph");
                break;
            }
        }
    }

    return result;
}

bool IRGraph::has_cycle_dfs(
    const std::string& node_id,
    std::unordered_map<std::string, VisitState>& state) const {

    state[node_id] = VisitState::Visiting;

    auto it = nodes_.find(node_id);
    if (it != nodes_.end()) {
        for (const auto& child_id : it->second.children) {
            auto sit = state.find(child_id);
            if (sit == state.end()) continue;
            if (sit->second == VisitState::Visiting) {
                return true; /* back edge = cycle */
            }
            if (sit->second == VisitState::Unvisited) {
                if (has_cycle_dfs(child_id, state)) return true;
            }
        }
    }

    state[node_id] = VisitState::Visited;
    return false;
}

/* ========================================================================
 * IRGraph topological order
 * ======================================================================== */

std::vector<std::string> IRGraph::topological_order() const {
    std::vector<std::string> result;
    std::unordered_map<std::string, VisitState> state;
    for (const auto& [nid, node] : nodes_) {
        state[nid] = VisitState::Unvisited;
    }

    /* Check for cycles first */
    for (const auto& [nid, node] : nodes_) {
        if (state[nid] == VisitState::Unvisited) {
            if (has_cycle_dfs(nid, state)) {
                return {}; /* has cycles */
            }
        }
    }

    /* Reset state */
    for (auto& [nid, s] : state) {
        s = VisitState::Unvisited;
    }

    /* Post-order DFS */
    std::function<void(const std::string&)> dfs;
    dfs = [&](const std::string& node_id) {
        if (state[node_id] != VisitState::Unvisited) return;
        state[node_id] = VisitState::Visiting;

        auto it = nodes_.find(node_id);
        if (it != nodes_.end()) {
            for (const auto& child_id : it->second.children) {
                dfs(child_id);
            }
        }

        state[node_id] = VisitState::Visited;
        result.push_back(node_id);
    };

    for (const auto& [nid, node] : nodes_) {
        if (state[nid] == VisitState::Unvisited) {
            dfs(nid);
        }
    }

    /* Reverse for root-first order */
    std::reverse(result.begin(), result.end());
    return result;
}

/* ========================================================================
 * IRGraph serialization ([I-3])
 * ======================================================================== */

std::string IRGraph::to_json() const {
    std::ostringstream oss;

    oss << "{\"root\":";
    json_escape(oss, root_);
    oss << ",\"nodes\":{";

    bool first_node = true;
    for (const auto& [nid, node] : nodes_) {
        if (!first_node) oss << ",";
        first_node = false;

        json_escape(oss, nid);
        oss << ":{";

        /* id */
        oss << "\"id\":";
        json_escape(oss, node.id);

        /* type */
        oss << ",\"type\":";
        json_escape(oss, node.type);

        /* attributes */
        oss << ",\"attributes\":{";
        bool first_attr = true;
        for (const auto& [key, val] : node.attributes) {
            if (!first_attr) oss << ",";
            first_attr = false;
            json_escape(oss, key);
            oss << ":";
            write_attr_value(oss, val);
        }
        oss << "}";

        /* children */
        oss << ",\"children\":[";
        for (size_t i = 0; i < node.children.size(); ++i) {
            if (i > 0) oss << ",";
            json_escape(oss, node.children[i]);
        }
        oss << "]";

        /* content (optional) */
        if (node.content.has_value()) {
            oss << ",\"content\":";
            json_escape(oss, node.content.value());
        }

        oss << "}";
    }

    oss << "}}";
    return oss.str();
}

std::optional<IRGraph> IRGraph::from_json(const std::string& json,
                                          std::string* error_out) {
    IRGraph graph;

    try {
        JsonParser p(json);

        /* Parse root object */
        p.expect('{');

        /* Expect "root" key */
        auto root_key = p.parse_string();
        if (root_key != "root") {
            if (error_out) *error_out = "Expected 'root' key, got '" + root_key + "'";
            return std::nullopt;
        }
        p.expect(':');
        auto root_id = p.parse_string();
        graph.set_root(root_id);

        /* Expect comma, then "nodes" key */
        if (p.peek() == ',') p.consume();
        auto nodes_key = p.parse_string();
        if (nodes_key != "nodes") {
            if (error_out) *error_out = "Expected 'nodes' key, got '" + nodes_key + "'";
            return std::nullopt;
        }
        p.expect(':');
        p.expect('{');

        /* Parse each node */
        while (p.peek() != '}') {
            auto node_id = p.parse_string();
            p.expect(':');
            p.expect('{');

            IRNode node;
            node.id = node_id;

            /* Parse node fields */
            while (p.peek() != '}') {
                auto field = p.parse_string();
                p.expect(':');

                if (field == "id") {
                    node.id = p.parse_string();
                } else if (field == "type") {
                    node.type = std::get<std::string>(p.parse_value());
                } else if (field == "attributes") {
                    p.expect('{');
                    while (p.peek() != '}') {
                        auto attr_key = p.parse_string();
                        p.expect(':');
                        node.attributes[attr_key] = p.parse_value();
                        if (p.peek() == ',') p.consume();
                    }
                    p.expect('}');
                } else if (field == "children") {
                    p.expect('[');
                    while (p.peek() != ']') {
                        node.children.push_back(p.parse_string());
                        if (p.peek() == ',') p.consume();
                    }
                    p.expect(']');
                } else if (field == "content") {
                    auto content_val = p.parse_value();
                    if (auto* s = std::get_if<std::string>(&content_val)) {
                        node.content = *s;
                    }
                } else {
                    /* Skip unknown fields */
                    p.parse_value();
                }

                if (p.peek() == ',') p.consume();
            }
            p.expect('}');

            graph.add_node(std::move(node));

            if (p.peek() == ',') p.consume();
        }
        p.expect('}');

        p.expect('}');

    } catch (const std::exception& e) {
        if (error_out) *error_out = e.what();
        return std::nullopt;
    }

    return graph;
}

/* ========================================================================
 * IRGraph equality
 * ======================================================================== */

bool IRGraph::operator==(const IRGraph& other) const {
    if (root_ != other.root_) return false;
    if (nodes_.size() != other.nodes_.size()) return false;
    for (const auto& [nid, node] : nodes_) {
        auto it = other.nodes_.find(nid);
        if (it == other.nodes_.end()) return false;
        if (node != it->second) return false;
    }
    return true;
}

/* ========================================================================
 * Utilities
 * ======================================================================== */

std::string ir_graph_summary(const IRGraph& graph) {
    std::ostringstream oss;
    oss << "IRGraph{root=" << graph.root()
        << ", nodes=" << graph.node_count() << "}";
    return oss.str();
}

IRGraph clone_graph(const IRGraph& source) {
    IRGraph copy;
    copy.set_root(source.root());
    for (const auto& [nid, node] : source.nodes()) {
        copy.add_node(node); /* IRNode is copyable */
    }
    /* Never seal the clone */
    return copy;
}

} // namespace ir
} // namespace doxtk
