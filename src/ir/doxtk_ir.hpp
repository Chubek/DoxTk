#ifndef DOXTK_IR_HPP
#define DOXTK_IR_HPP

#include <cstdint>
#include <map>
#include <memory>
#include <optional>
#include <string>
#include <unordered_map>
#include <variant>
#include <vector>

namespace doxtk {
namespace ir {

/* ========================================================================
 * IR Attribute Value
 *
 * Represents a JSON-compatible value stored in a node's attributes map.
 * The spec says Map<String, Value>; we use a variant for type safety.
 * ======================================================================== */

using IRAttrValue = std::variant<
    std::nullptr_t,
    bool,
    int64_t,
    double,
    std::string,
    std::vector<std::string>,
    std::map<std::string, std::string>
>;

/* ========================================================================
 * IR Node ([I-2])
 *
 * Every IR node MUST conform to this schema:
 *   id         – document-unique node identifier
 *   type       – the kind of node (document, section, paragraph, text, image...)
 *   attributes – key-value properties (style classes, metadata, configuration)
 *   children   – ordered list of child node identifiers
 *   content    – optional leaf text content
 * ======================================================================== */

struct IRNode {
    std::string id;
    std::string type;
    std::map<std::string, IRAttrValue> attributes;
    std::vector<std::string> children;
    std::optional<std::string> content;

    IRNode() = default;

    IRNode(std::string id_, std::string type_)
        : id(std::move(id_)), type(std::move(type_)) {}

    IRNode& add_child(const std::string& child_id) {
        children.push_back(child_id);
        return *this;
    }

    IRNode& set_attr(const std::string& key, IRAttrValue value) {
        attributes[key] = std::move(value);
        return *this;
    }

    IRNode& set_content(const std::string& text) {
        content = text;
        return *this;
    }

    bool operator==(const IRNode& other) const {
        return id == other.id &&
               type == other.type &&
               attributes == other.attributes &&
               children == other.children &&
               content == other.content;
    }

    bool operator!=(const IRNode& other) const {
        return !(*this == other);
    }
};

/* ========================================================================
 * Validation Result
 * ======================================================================== */

struct IRValidationResult {
    bool valid = false;
    std::vector<std::string> errors;

    static IRValidationResult ok() {
        IRValidationResult r;
        r.valid = true;
        return r;
    }

    static IRValidationResult fail(std::string error) {
        IRValidationResult r;
        r.valid = false;
        r.errors.push_back(std::move(error));
        return r;
    }

    IRValidationResult& add_error(std::string error) {
        valid = false;
        errors.push_back(std::move(error));
        return *this;
    }

    void merge(const IRValidationResult& other) {
        if (!other.valid) valid = false;
        errors.insert(errors.end(), other.errors.begin(), other.errors.end());
    }
};

/* ========================================================================
 * IR Graph ([I-1], [I-3])
 *
 * An immutable directed acyclic graph of IRNode instances.
 * Once sealed, no further modifications are allowed.
 * ======================================================================== */

class IRGraph {
public:
    IRGraph() = default;

    /* --- Construction (before sealing) --- */

    IRGraph& set_root(const std::string& root_id);

    bool add_node(IRNode node);

    bool remove_node(const std::string& id);

    /* --- Query --- */

    const IRNode* get_node(const std::string& id) const;

    bool has_node(const std::string& id) const;

    const std::string& root() const { return root_; }

    size_t node_count() const { return nodes_.size(); }

    const std::unordered_map<std::string, IRNode>& nodes() const {
        return nodes_;
    }

    /* --- Immutability --- */

    void seal();

    bool is_sealed() const { return sealed_; }

    /* --- Validation --- */

    IRValidationResult validate() const;

    /* --- Serialization ([I-3]) --- */

    std::string to_json() const;

    static std::optional<IRGraph> from_json(const std::string& json,
                                            std::string* error_out = nullptr);

    /* --- Topological Order --- */

    std::vector<std::string> topological_order() const;

    /* --- Equality --- */
    bool operator==(const IRGraph& other) const;
    bool operator!=(const IRGraph& other) const { return !(*this == other); }

private:
    enum class VisitState { Unvisited, Visiting, Visited };
    bool has_cycle_dfs(const std::string& node_id,
                       std::unordered_map<std::string, VisitState>& state) const;

    std::string root_;
    std::unordered_map<std::string, IRNode> nodes_;
    bool sealed_ = false;
};

/* ========================================================================
 * Utilities
 * ======================================================================== */

std::string ir_graph_summary(const IRGraph& graph);

IRGraph clone_graph(const IRGraph& source);

} // namespace ir
} // namespace doxtk

#endif // DOXTK_IR_HPP
