#include <catch2/catch_test_macros.hpp>
#include "distance.h"

using namespace zpell;

TEST_CASE("Edit distance calculation", "[distance]") {
    SECTION("Identical strings") {
        REQUIRE(edit_distance("hello", "hello") == 0);
        REQUIRE(edit_distance("", "") == 0);
    }
    
    SECTION("Single character difference") {
        REQUIRE(edit_distance("hello", "hallo") == 1);
        REQUIRE(edit_distance("cat", "bat") == 1);
    }
    
    SECTION("Insertion") {
        REQUIRE(edit_distance("cat", "cats") == 1);
        REQUIRE(edit_distance("", "a") == 1);
    }
    
    SECTION("Deletion") {
        REQUIRE(edit_distance("cats", "cat") == 1);
        REQUIRE(edit_distance("a", "") == 1);
    }
    
    SECTION("Multiple operations") {
        REQUIRE(edit_distance("kitten", "sitting") == 3);
        REQUIRE(edit_distance("saturday", "sunday") == 3);
    }
}

TEST_CASE("Normalized distance", "[distance]") {
    SECTION("Identical strings") {
        REQUIRE(normalized_distance("hello", "hello") == 0.0);
    }
    
    SECTION("Completely different") {
        double dist = normalized_distance("abc", "xyz");
        REQUIRE(dist > 0.0);
        REQUIRE(dist <= 1.0);
    }
}
