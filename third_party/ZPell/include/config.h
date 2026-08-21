#ifndef ZPELL_CONFIG_H
#define ZPELL_CONFIG_H

#include <string>
#include <filesystem>
#include <vector>
#include <optional>

namespace zpell {

/**
 * @brief Configuration structure
 */
struct Config {
    std::filesystem::path wordlist_path;
    std::vector<std::filesystem::path> module_paths;
    std::filesystem::path dotfile_path;
    
    // RPC settings
    std::string rpc_host = "127.0.0.1";
    int rpc_port = 9876;
    
    // IPC settings
    std::string ipc_name = "zpell_ipc";
    
    // Cache settings
    bool enable_cache = true;
    std::filesystem::path cache_path;
    
    // Default values
    int max_suggestions = 5;
    int max_distance = 2;
};

/**
 * @brief Configuration loader
 */
class ConfigLoader {
public:
    /**
     * @brief Load configuration from TOML file
     * @param path Path to config file
     * @return Config structure or nullopt on error
     */
    static std::optional<Config> load(const std::filesystem::path& path);
    
    /**
     * @brief Load default configuration
     * @return Default config
     */
    static Config load_default();
    
    /**
     * @brief Get XDG config path
     * @return Path to config file
     */
    static std::filesystem::path get_config_path();
};

} // namespace zpell

#endif // ZPELL_CONFIG_H
