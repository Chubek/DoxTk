#include "zpell-api.h"
#include "rpc.h"
#include "ipc.h"
#include <CLI/CLI.hpp>
#include <iostream>
#include <fstream>

using namespace zpell;

int main(int argc, char** argv) {
    CLI::App app{"ZPell - Modular spellchecker built around BK-Trees"};
    
    // Global options
    std::string config_path;
    std::string wordlist_path;
    bool use_cache = true;
    
    app.add_option("-c,--config", config_path, "Configuration file path");
    app.add_option("-w,--wordlist", wordlist_path, "Wordlist file path");
    app.add_flag("--no-cache,!--cache", use_cache, "Enable/disable cache");
    
    // Check command
    auto check_cmd = app.add_subcommand("check", "Check if a word is spelled correctly");
    std::string check_word;
    check_cmd->add_option("word", check_word, "Word to check")->required();
    
    // Suggest command
    auto suggest_cmd = app.add_subcommand("suggest", "Get spelling suggestions");
    std::string suggest_word;
    int max_suggestions = 5;
    suggest_cmd->add_option("word", suggest_word, "Word to get suggestions for")->required();
    suggest_cmd->add_option("-n,--max", max_suggestions, "Maximum number of suggestions");
    
    // Load command
    auto load_cmd = app.add_subcommand("load", "Load a wordlist file");
    std::string load_path;
    load_cmd->add_option("file", load_path, "Path to wordlist file")->required();
    
    // Daemon command
    auto daemon_cmd = app.add_subcommand("daemon", "Run as RPC/IPC daemon");
    bool use_rpc = false;
    bool use_ipc = false;
    std::string rpc_host = "127.0.0.1";
    int rpc_port = 9876;
    daemon_cmd->add_flag("--rpc", use_rpc, "Enable RPC server");
    daemon_cmd->add_flag("--ipc", use_ipc, "Enable IPC server");
    daemon_cmd->add_option("--host", rpc_host, "RPC host address");
    daemon_cmd->add_option("--port", rpc_port, "RPC port number");
    
    CLI11_PARSE(app, argc, argv);
    
    // Load configuration
    Config config;
    if (!config_path.empty()) {
        auto loaded = ConfigLoader::load(config_path);
        if (loaded) {
            config = *loaded;
        } else {
            std::cerr << "Failed to load config from: " << config_path << std::endl;
            return 1;
        }
    } else {
        config = ConfigLoader::load_default();
    }
    
    // Override with command line options
    if (!wordlist_path.empty()) {
        config.wordlist_path = wordlist_path;
    }
    config.enable_cache = use_cache;
    
    // Initialize ZPell
    ZPell zpell(config);
    
    // Execute commands
    if (*check_cmd) {
        bool correct = zpell.check(check_word);
        if (correct) {
            std::cout << "✓ '" << check_word << "' is spelled correctly" << std::endl;
            return 0;
        } else {
            std::cout << "✗ '" << check_word << "' is misspelled" << std::endl;
            
            // Show suggestions
            auto suggestions = zpell.suggest(check_word, 5);
            if (!suggestions.empty()) {
                std::cout << "\nSuggestions:" << std::endl;
                for (const auto& [word, dist] : suggestions) {
                    std::cout << "  " << word << " (distance: " << dist << ")" << std::endl;
                }
            }
            return 1;
        }
    }
    
    if (*suggest_cmd) {
        auto suggestions = zpell.suggest(suggest_word, max_suggestions);
        
        if (suggestions.empty()) {
            std::cout << "No suggestions found for '" << suggest_word << "'" << std::endl;
            return 1;
        }
        
        std::cout << "Suggestions for '" << suggest_word << "':" << std::endl;
        for (const auto& [word, dist] : suggestions) {
            std::cout << "  " << word << " (distance: " << dist << ")" << std::endl;
        }
        return 0;
    }
    
    if (*load_cmd) {
        std::cout << "Loading wordlist from: " << load_path << std::endl;
        if (zpell.load_wordlist(load_path)) {
            std::cout << "Successfully loaded wordlist" << std::endl;
            return 0;
        } else {
            std::cerr << "Failed to load wordlist" << std::endl;
            return 1;
        }
    }
    
    if (*daemon_cmd) {
        std::cout << "Starting ZPell daemon..." << std::endl;
        
        if (use_rpc) {
            RPCServer rpc;
            if (rpc.initialize(&zpell, rpc_host, rpc_port)) {
                std::cout << "RPC server listening on " << rpc_host << ":" << rpc_port << std::endl;
                rpc.run();
            } else {
                std::cerr << "Failed to start RPC server" << std::endl;
                return 1;
            }
        }
        
        if (use_ipc) {
            IPCServer ipc;
            if (ipc.initialize(&zpell, config.ipc_name)) {
                std::cout << "IPC server started with name: " << config.ipc_name << std::endl;
                ipc.run();
            } else {
                std::cerr << "Failed to start IPC server" << std::endl;
                return 1;
            }
        }
        
        return 0;
    }
    
    // No command specified, show help
    std::cout << app.help() << std::endl;
    return 0;
}
