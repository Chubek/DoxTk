#ifndef ZPELL_WORDLIST_H
#define ZPELL_WORDLIST_H

#include "bktree.h"
#include <string>
#include <filesystem>

namespace zpell {

/**
 * @brief Wordlist loader and manager
 */
class Wordlist {
public:
    Wordlist() = default;
    
    /**
     * @brief Load words from file into BK-Tree
     * @param path Path to wordlist file
     * @return True if successful
     */
    bool load(const std::filesystem::path& path);
    
    /**
     * @brief Load default system wordlist
     * @return True if successful
     */
    bool load_default();
    
    /**
     * @brief Get the underlying BK-Tree
     * @return Reference to BK-Tree
     */
    const BKTree& tree() const { return tree_; }
    BKTree& tree() { return tree_; }
    
    /**
     * @brief Check if a word exists
     * @param word Word to check
     * @return True if word exists
     */
    bool contains(const std::string& word) const;
    
    /**
     * @brief Get suggestions for a word
     * @param word Query word
     * @param max_distance Maximum edit distance
     * @return Vector of suggestions with distances
     */
    std::vector<std::pair<std::string, int>> suggest(const std::string& word, int max_distance = 2) const;
    
private:
    BKTree tree_;
    static constexpr const char* DEFAULT_WORDLIST = "/usr/share/dict/words";
};

} // namespace zpell

#endif // ZPELL_WORDLIST_H
