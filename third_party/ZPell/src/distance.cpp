#include "distance.h"
#include <algorithm>
#include <vector>

namespace zpell {

int edit_distance(std::string_view a, std::string_view b) {
    const size_t m = a.size();
    const size_t n = b.size();
    
    if (m == 0) return static_cast<int>(n);
    if (n == 0) return static_cast<int>(m);
    
    // Use two rows for space optimization
    std::vector<int> prev(n + 1);
    std::vector<int> curr(n + 1);
    
    // Initialize first row
    for (size_t j = 0; j <= n; ++j) {
        prev[j] = static_cast<int>(j);
    }
    
    // Calculate edit distance
    for (size_t i = 1; i <= m; ++i) {
        curr[0] = static_cast<int>(i);
        
        for (size_t j = 1; j <= n; ++j) {
            if (a[i - 1] == b[j - 1]) {
                curr[j] = prev[j - 1];
            } else {
                curr[j] = 1 + std::min({
                    prev[j],      // deletion
                    curr[j - 1],  // insertion
                    prev[j - 1]   // substitution
                });
            }
        }
        
        std::swap(prev, curr);
    }
    
    return prev[n];
}

double normalized_distance(std::string_view a, std::string_view b) {
    const int dist = edit_distance(a, b);
    const size_t max_len = std::max(a.size(), b.size());
    
    if (max_len == 0) return 0.0;
    
    return static_cast<double>(dist) / static_cast<double>(max_len);
}

} // namespace zpell
