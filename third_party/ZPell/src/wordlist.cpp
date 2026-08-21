#include "wordlist.h"
#include <fstream>
#include <sstream>
#include <algorithm>

namespace zpell {

bool Wordlist::load(const std::filesystem::path& path) {
    if (!std::filesystem::exists(path)) {
        return false;
    }
    
    std::ifstream file(path);
    if (!file.is_open()) {
        return false;
    }
    
    std::string line;
    while (std::getline(file, line)) {
        // Trim whitespace
        line.erase(0, line.find_first_not_of(" \t\r\n"));
        line.erase(line.find_last_not_of(" \t\r\n") + 1);
        
        if (!line.empty()) {
            tree_.insert(line);
        }
    }
    
    return true;
}

bool Wordlist::load_default() {
    return load(DEFAULT_WORDLIST);
}

bool Wordlist::contains(const std::string& word) const {
    auto results = tree_.search(word, 0);
    return !results.empty() && results[0].second == 0;
}

std::vector<std::pair<std::string, int>> Wordlist::suggest(const std::string& word, int max_distance) const {
    return tree_.search(word, max_distance);
}

} // namespace zpell
