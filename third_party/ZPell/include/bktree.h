#ifndef ZPELL_BKTREE_H
#define ZPELL_BKTREE_H

#include <string>
#include <vector>
#include <memory>
#include <unordered_map>

namespace zpell {

/**
 * @brief BK-Tree node structure
 */
struct BKNode {
    std::string word;
    std::unordered_map<int, std::unique_ptr<BKNode>> children;
    
    BKNode(std::string w) : word(std::move(w)) {}
};

/**
 * @brief BK-Tree for fast spell checking
 */
class BKTree {
public:
    BKTree() = default;
    ~BKTree() = default;
    
    // Move semantics
    BKTree(BKTree&&) noexcept = default;
    BKTree& operator=(BKTree&&) noexcept = default;
    
    // Delete copy
    BKTree(const BKTree&) = delete;
    BKTree& operator=(const BKTree&) = delete;
    
    /**
     * @brief Insert a word into the tree
     * @param word Word to insert
     */
    void insert(const std::string& word);
    
    /**
     * @brief Search for words within a given distance
     * @param word Query word
     * @param max_distance Maximum edit distance
     * @return Vector of matching words with their distances
     */
    std::vector<std::pair<std::string, int>> search(const std::string& word, int max_distance) const;
    
    /**
     * @brief Check if tree is empty
     * @return True if empty
     */
    bool empty() const { return root_ == nullptr; }
    
    /**
     * @brief Get number of words in tree
     * @return Word count
     */
    size_t size() const { return size_; }
    
private:
    std::unique_ptr<BKNode> root_;
    size_t size_ = 0;
    
    void insert_recursive(BKNode* node, const std::string& word);
    void search_recursive(const BKNode* node, const std::string& word, 
                         int max_distance, std::vector<std::pair<std::string, int>>& results) const;
};

} // namespace zpell

#endif // ZPELL_BKTREE_H
