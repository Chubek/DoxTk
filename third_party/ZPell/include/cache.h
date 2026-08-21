#ifndef ZPELL_CACHE_H
#define ZPELL_CACHE_H

#include "bktree.h"
#include <filesystem>
#include <optional>
#include <memory>

namespace zpell {

/**
 * @brief Cache manager using libmdbx
 */
class Cache {
public:
    Cache();
    ~Cache();
    
    // Move semantics
    Cache(Cache&&) noexcept;
    Cache& operator=(Cache&&) noexcept;
    
    // Delete copy
    Cache(const Cache&) = delete;
    Cache& operator=(const Cache&) = delete;
    
    /**
     * @brief Open cache database
     * @param path Path to cache file
     * @return True if successful
     */
    bool open(const std::filesystem::path& path);
    
    /**
     * @brief Close cache database
     */
    void close();
    
    /**
     * @brief Save BK-Tree to cache
     * @param tree Tree to save
     * @param key Cache key (e.g., wordlist path)
     * @return True if successful
     */
    bool save_tree(const BKTree& tree, const std::string& key);
    
    /**
     * @brief Load BK-Tree from cache
     * @param key Cache key
     * @return Tree if found
     */
    std::optional<BKTree> load_tree(const std::string& key);
    
    /**
     * @brief Check if cache is open
     * @return True if open
     */
    bool is_open() const { return is_open_; }
    
private:
    struct Impl;
    std::unique_ptr<Impl> impl_;
    bool is_open_ = false;
};

} // namespace zpell

#endif // ZPELL_CACHE_H
