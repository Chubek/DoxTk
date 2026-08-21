#include <catch2/catch_test_macros.hpp>
#include "pattern.h"
#include <fstream>

using namespace zpell;

TEST_CASE("Pattern matching", "[pattern]") {
    PatternMatcher matcher;
    
    SECTION("Simple pattern") {
        matcher.add_pattern("test.*", false, '/');
        
        REQUIRE(matcher.matches("test"));
        REQUIRE(matcher.matches("testing"));
        REQUIRE(matcher.matches("test123"));
    }
    
    SECTION("Exclusion pattern") {
        matcher.add_pattern(".*", false, '/');
        matcher.add_pattern("bad.*", true, '/');
        
        REQUIRE(matcher.matches("good"));
        REQUIRE(!matcher.matches("badword"));
    }
    
    SECTION("Clear patterns") {
        matcher.add_pattern("test", false, '/');
        matcher.clear();
        
        REQUIRE(matcher.patterns().empty());
    }
}

TEST_CASE("Dotfile parsing", "[pattern]") {
    SECTION("Parse simple dotfile") {
        std::string content = R"(
# Comment line
/test.*/
!/bad.*/
|good.*|
)";
        
        auto matcher = DotfileParser::parse_string(content);
        REQUIRE(matcher.patterns().size() == 3);
    }
    
    SECTION("Parse from file") {
        std::filesystem::path temp_path = std::filesystem::temp_directory_path() / "test.zpell";
        std::ofstream file(temp_path);
        file << "/test.*/\n";
        file << "!/exclude.*/\n";
        file.close();
        
        auto matcher = DotfileParser::parse(temp_path);
        REQUIRE(matcher.patterns().size() == 2);
        
        std::filesystem::remove(temp_path);
    }
}
