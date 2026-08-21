#include "bktree.h"
#include "distance.h"
#include <algorithm>

namespace zpell {

void BKTree::insert(const std::string& word) {
    if (word.empty()) return;
    
    if (!root_) {
        root_ = std::make_unique<BKNode>(word);
        size_ = 1;
        return;
    }
    
    insert_recursive(root_.get(), word);
    size_++;
}

void BKTree::insert_recursive(BKNode* node, const std::string& word) {
    const int dist = edit_distance(node->word, word);
    
    if (dist == 0) {
        // Word already exists
        size_--;
        return;
    }
    
    auto it = node->children.find(dist);
    if (it == node->children.end()) {
        node->children[dist] = std::make_unique<BKNode>(word);
    } else {
        insert_recursive(it->second.get(), word);
    }
}

std::vector<std::pair<std::string, int>> BKTree::search(const std::string& word, int max_distance) const {
    std::vector<std::pair<std::string, int>> results;
    
    if (!root_) return results;
    
    search_recursive(root_.get(), word, max_distance, results);
    
    // Sort by distance
    std::sort(results.begin(), results.end(), 
              [](const auto& a, const auto& b) { return a.second < b.second; });
    
    return results;
}

void BKTree::search_recursive(const BKNode* node, const std::string& word, 
                              int max_distance, std::vector<std::pair<std::string, int>>& results) const {
    const int dist = edit_distance(node->word, word);
    
    if (dist <= max_distance) {
        results.emplace_back(node->word, dist);
    }
    
    // Search children within distance range
    const int min_dist = dist - max_distance;
    const int max_dist = dist + max_distance;
    
    for (const auto& [child_dist, child] : node->children) {
        if (child_dist >= min_dist && child_dist <= max_dist) {
            search_recursive(child.get(), word, max_distance, results);
        }
    }
}

} // namespace zpell
