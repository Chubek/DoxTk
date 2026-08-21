#include <catch2/catch_test_macros.hpp>
#include "config.h"
#include <fstream>

using namespace zpell;

TEST_CASE("Configuration loading", "[config]") {
    SECTION("Default config") {
        Config config = ConfigLoader::load_default();
        REQUIRE(!config.wordlist_path.empty());
        REQUIRE(config.rpc_port == 9876);
        REQUIRE(config.enable_cache == true);
    }
    
    SECTION("Load from TOML") {
        std::filesystem::path temp_path = std::filesystem::temp_directory_path() / "test_config.toml";
        std::ofstream file(temp_path);
        file << "wordlist_path = \"/custom/path/words\"\n";
        file << "[rpc]\n";
        file << "host = \"0.0.0.0\"\n";
        file << "port = 8888\n";
        file << "[cache]\n";
        file << "enable = false\n";
        file.close();
        
        auto config = ConfigLoader::load(temp_path);
        REQUIRE(config.has_value());
        REQUIRE(config->wordlist_path == "/custom/path/words");
        REQUIRE(config->rpc_host == "0.0.0.0");
        REQUIRE(config->rpc_port == 8888);
        REQUIRE(config->enable_cache == false);
        
        std::filesystem::remove(temp_path);
    }
    
    SECTION("Config path resolution") {
        auto path = ConfigLoader::get_config_path();
        REQUIRE(!path.empty());
    }
}
