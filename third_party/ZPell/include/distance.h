#ifndef ZPELL_DISTANCE_H
#define ZPELL_DISTANCE_H

#include <string>
#include <string_view>

namespace zpell {

/**
 * @brief Calculate edit distance between two strings
 * @param a First string
 * @param b Second string
 * @return Edit distance (Levenshtein distance)
 */
int edit_distance(std::string_view a, std::string_view b);

/**
 * @brief Calculate normalized edit distance (0.0 to 1.0)
 * @param a First string
 * @param b Second string
 * @return Normalized distance
 */
double normalized_distance(std::string_view a, std::string_view b);

} // namespace zpell

#endif // ZPELL_DISTANCE_H
