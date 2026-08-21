#ifndef ZPELL_API_H
#define ZPELL_API_H

#include "bktree.h"
#include "wordlist.h"
#include "config.h"
#include "pattern.h"
#include "cache.h"
#include <memory>

namespace zpell {

/**
 * @brief Main ZPell API
 */
class ZPell {
public:
    ZPell();
    explicit ZPell(const Config& config);
    ~ZPell();
    
    /**
     * @brief Initialize with configuration
     * @param config Configuration
     * @return True if successful
     */
    bool initialize(const Config& config);
    
    /**
     * @brief Load wordlist
     * @param path Path to wordlist
     * @return True if successful
     */
    bool load_wordlist(const std::filesystem::path& path);
    
    /**
     * @brief Check if a word is spelled correctly
     * @param word Word to check
     * @return True if correct
     */
    bool check(const std::string& word) const;
    
    /**
     * @brief Get spelling suggestions
     * @param word Word to check
     * @param max_suggestions Maximum number of suggestions
     * @return Vector of suggestions with distances
     */
    std::vector<std::pair<std::string, int>> suggest(const std::string& word, int max_suggestions = 5) const;
    
    /**
     * @brief Load patterns from .zpell file
     * @param path Path to .zpell file
     * @return True if successful
     */
    bool load_patterns(const std::filesystem::path& path);
    
    /**
     * @brief Get configuration
     * @return Current configuration
     */
    const Config& config() const { return config_; }
    
    /**
     * @brief Get wordlist
     * @return Wordlist reference
     */
    const Wordlist& wordlist() const { return wordlist_; }
    
private:
    Config config_;
    Wordlist wordlist_;
    PatternMatcher patterns_;
    Cache cache_;
};

} // namespace zpell

#endif // ZPELL_API_H
