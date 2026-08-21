#include "zpell-api.h"
#include <algorithm>

namespace zpell {

ZPell::ZPell() : config_(ConfigLoader::load_default()) {}

ZPell::ZPell(const Config& config) : config_(config) {
    initialize(config);
}

ZPell::~ZPell() = default;

bool ZPell::initialize(const Config& config) {
    config_ = config;
    
    // Open cache if enabled
    if (config_.enable_cache && !config_.cache_path.empty()) {
        cache_.open(config_.cache_path);
    }
    
    // Load wordlist
    if (!config_.wordlist_path.empty()) {
        if (!load_wordlist(config_.wordlist_path)) {
            return false;
        }
    }
    
    // Load patterns if dotfile specified
    if (!config_.dotfile_path.empty()) {
        load_patterns(config_.dotfile_path);
    }
    
    return true;
}

bool ZPell::load_wordlist(const std::filesystem::path& path) {
    // Try to load from cache first
    if (cache_.is_open()) {
        auto cached = cache_.load_tree(path.string());
        if (cached) {
            // Cache hit - would need proper deserialization
            // For now, fall through to regular load
        }
    }
    
    // Load from file
    bool success = wordlist_.load(path);
    
    // Save to cache
    if (success && cache_.is_open()) {
        cache_.save_tree(wordlist_.tree(), path.string());
    }
    
    return success;
}

bool ZPell::check(const std::string& word) const {
    // Check against patterns first
    if (!patterns_.patterns().empty() && !patterns_.matches(word)) {
        return false;
    }
    
    return wordlist_.contains(word);
}

std::vector<std::pair<std::string, int>> ZPell::suggest(const std::string& word, int max_suggestions) const {
    auto suggestions = wordlist_.suggest(word, config_.max_distance);
    
    // Filter by patterns if any
    if (!patterns_.patterns().empty()) {
        suggestions.erase(
            std::remove_if(suggestions.begin(), suggestions.end(),
                [this](const auto& s) { return !patterns_.matches(s.first); }),
            suggestions.end()
        );
    }
    
    // Limit results
    if (suggestions.size() > static_cast<size_t>(max_suggestions)) {
        suggestions.resize(max_suggestions);
    }
    
    return suggestions;
}

bool ZPell::load_patterns(const std::filesystem::path& path) {
    patterns_ = DotfileParser::parse(path);
    return true;
}

} // namespace zpell
