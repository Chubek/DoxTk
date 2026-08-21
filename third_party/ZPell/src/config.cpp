#include "config.h"
#include <toml.h>
#include <fstream>
#include <cstdlib>

namespace zpell {

std::optional<Config> ConfigLoader::load(const std::filesystem::path& path) {
    if (!std::filesystem::exists(path)) {
        return std::nullopt;
    }
    
    FILE* fp = fopen(path.string().c_str(), "r");
    if (!fp) {
        return std::nullopt;
    }
    
    char errbuf[200];
    toml_table_t* conf = toml_parse_file(fp, errbuf, sizeof(errbuf));
    fclose(fp);
    
    if (!conf) {
        return std::nullopt;
    }
    
    Config config = load_default();
    
    // Parse wordlist path
    toml_datum_t wordlist = toml_string_in(conf, "wordlist_path");
    if (wordlist.ok) {
        config.wordlist_path = wordlist.u.s;
        free(wordlist.u.s);
    }
    
    // Parse RPC settings
    toml_table_t* rpc = toml_table_in(conf, "rpc");
    if (rpc) {
        toml_datum_t host = toml_string_in(rpc, "host");
        if (host.ok) {
            config.rpc_host = host.u.s;
            free(host.u.s);
        }
        
        toml_datum_t port = toml_int_in(rpc, "port");
        if (port.ok) {
            config.rpc_port = static_cast<int>(port.u.i);
        }
    }
    
    // Parse IPC settings
    toml_table_t* ipc = toml_table_in(conf, "ipc");
    if (ipc) {
        toml_datum_t name = toml_string_in(ipc, "name");
        if (name.ok) {
            config.ipc_name = name.u.s;
            free(name.u.s);
        }
    }
    
    // Parse cache settings
    toml_table_t* cache = toml_table_in(conf, "cache");
    if (cache) {
        toml_datum_t enable = toml_bool_in(cache, "enable");
        if (enable.ok) {
            config.enable_cache = enable.u.b;
        }
        
        toml_datum_t cache_path = toml_string_in(cache, "path");
        if (cache_path.ok) {
            config.cache_path = cache_path.u.s;
            free(cache_path.u.s);
        }
    }
    
    // Parse dotfile path
    toml_datum_t dotfile = toml_string_in(conf, "dotfile_path");
    if (dotfile.ok) {
        config.dotfile_path = dotfile.u.s;
        free(dotfile.u.s);
    }
    
    toml_free(conf);
    return config;
}

Config ConfigLoader::load_default() {
    Config config;
    config.wordlist_path = "/usr/share/dict/words";
    
    // Set default cache path
    const char* home = std::getenv("HOME");
    if (home) {
        config.cache_path = std::filesystem::path(home) / ".cache" / "zpell" / "cache.mdb";
    }
    
    return config;
}

std::filesystem::path ConfigLoader::get_config_path() {
    const char* xdg_config = std::getenv("XDG_CONFIG_HOME");
    std::filesystem::path config_dir;
    
    if (xdg_config) {
        config_dir = xdg_config;
    } else {
        const char* home = std::getenv("HOME");
        if (home) {
            config_dir = std::filesystem::path(home) / ".config";
        } else {
            config_dir = "/etc";
        }
    }
    
    return config_dir / "zpell" / "Config.toml";
}

} // namespace zpell
