#include <catch2/catch_test_macros.hpp>
#include "wordlist.h"
#include <fstream>
#include <filesystem>

using namespace zpell;

TEST_CASE("Wordlist operations", "[wordlist]") {
    Wordlist wl;
    
    SECTION("Load from file") {
        // Create temporary wordlist
        std::filesystem::path temp_path = std::filesystem::temp_directory_path() / "test_wordlist.txt";
        std::ofstream file(temp_path);
        file << "hello\n";
        file << "world\n";
        file << "test\n";
        file.close();
        
        REQUIRE(wl.load(temp_path));
        REQUIRE(wl.tree().size() == 3);
        
        // Cleanup
        std::filesystem::remove(temp_path);
    }
    
    SECTION("Contains word") {
        std::filesystem::path temp_path = std::filesystem::temp_directory_path() / "test_wordlist2.txt";
        std::ofstream file(temp_path);
        file << "hello\nworld\n";
        file.close();
        
        wl.load(temp_path);
        
        REQUIRE(wl.contains("hello"));
        REQUIRE(wl.contains("world"));
        REQUIRE(!wl.contains("notfound"));
        
        std::filesystem::remove(temp_path);
    }
    
    SECTION("Suggestions") {
        std::filesystem::path temp_path = std::filesystem::temp_directory_path() / "test_wordlist3.txt";
        std::ofstream file(temp_path);
        file << "hello\nhallo\nhullo\nworld\n";
        file.close();
        
        wl.load(temp_path);
        
        auto suggestions = wl.suggest("hello", 1);
        REQUIRE(!suggestions.empty());
        
        std::filesystem::remove(temp_path);
    }
}
