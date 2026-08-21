#ifndef ZPELL_PATTERN_H
#define ZPELL_PATTERN_H

#include <string>
#include <vector>
#include <memory>
#include <filesystem>

namespace zpell {

/**
 * @brief Pattern matching rule
 */
struct Pattern {
    std::string pattern;
    bool is_exclusion = false;
    char delimiter = '/';
    
    Pattern(std::string p, bool excl = false, char delim = '/') 
        : pattern(std::move(p)), is_exclusion(excl), delimiter(delim) {}
};

/**
 * @brief Pattern matcher using regex
 */
class PatternMatcher {
public:
    PatternMatcher();
    ~PatternMatcher();
    
    // Move semantics
    PatternMatcher(PatternMatcher&&) noexcept;
    PatternMatcher& operator=(PatternMatcher&&) noexcept;
    
    // Delete copy
    PatternMatcher(const PatternMatcher&) = delete;
    PatternMatcher& operator=(const PatternMatcher&) = delete;
    
    /**
     * @brief Add a pattern
     * @param pattern Pattern string
     * @param is_exclusion Whether this is an exclusion pattern
     * @param delimiter Pattern delimiter ('/' or '|')
     */
    void add_pattern(const std::string& pattern, bool is_exclusion = false, char delimiter = '/');
    
    /**
     * @brief Check if a word matches any pattern
     * @param word Word to check
     * @return True if matches (considering exclusions)
     */
    bool matches(const std::string& word) const;
    
    /**
     * @brief Clear all patterns
     */
    void clear();
    
    /**
     * @brief Get all patterns
     * @return Vector of patterns
     */
    const std::vector<Pattern>& patterns() const { return patterns_; }
    
private:
    std::vector<Pattern> patterns_;
    struct Impl;
    std::unique_ptr<Impl> impl_;
};

/**
 * @brief Parse .zpell dotfile
 */
class DotfileParser {
public:
    /**
     * @brief Parse a .zpell file
     * @param path Path to .zpell file
     * @return PatternMatcher with loaded patterns
     */
    static PatternMatcher parse(const std::filesystem::path& path);
    
    /**
     * @brief Parse pattern string
     * @param content Content to parse
     * @return PatternMatcher with loaded patterns
     */
    static PatternMatcher parse_string(const std::string& content);
};

} // namespace zpell

#endif // ZPELL_PATTERN_H
