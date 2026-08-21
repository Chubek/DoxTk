#include <catch2/catch_test_macros.hpp>
#include "bktree.h"

using namespace zpell;

TEST_CASE("BK-Tree operations", "[bktree]") {
    BKTree tree;
    
    SECTION("Empty tree") {
        REQUIRE(tree.empty());
        REQUIRE(tree.size() == 0);
    }
    
    SECTION("Insert words") {
        tree.insert("hello");
        REQUIRE(!tree.empty());
        REQUIRE(tree.size() == 1);
        
        tree.insert("world");
        REQUIRE(tree.size() == 2);
    }
    
    SECTION("Duplicate insertion") {
        tree.insert("hello");
        tree.insert("hello");
        REQUIRE(tree.size() == 1);
    }
    
    SECTION("Search exact match") {
        tree.insert("hello");
        tree.insert("world");
        
        auto results = tree.search("hello", 0);
        REQUIRE(results.size() == 1);
        REQUIRE(results[0].first == "hello");
        REQUIRE(results[0].second == 0);
    }
    
    SECTION("Search with distance") {
        tree.insert("hello");
        tree.insert("hallo");
        tree.insert("hullo");
        tree.insert("world");
        
        auto results = tree.search("hello", 1);
        REQUIRE(results.size() >= 2);  // hello, hallo, hullo
        
        // Check all results are within distance 1
        for (const auto& [word, dist] : results) {
            REQUIRE(dist <= 1);
        }
    }
}
