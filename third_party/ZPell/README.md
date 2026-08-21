# ZPell

A modular, extensible spellchecker built around BK-Trees and edit distance algorithms.

## Features

- **Fast BK-Tree Implementation**: O(log n) average search time
- **Configurable**: TOML-based configuration with XDG support
- **Pattern Matching**: Regex-based inclusion/exclusion patterns
- **Extensible**: Plugin system for custom modules
- **Scriptable**: Lua bindings for custom behavior
- **Network Ready**: JSON-RPC and IPC interfaces
- **Persistent Caching**: Fast startup with libmdbx

## Quick Start

### Building

```bash
mkdir build && cd build
cmake ..
make -j$(nproc)
sudo make install
```

### Usage

```bash
# Check a word
zpell check hello

# Get suggestions
zpell suggest helo

# Load custom wordlist
zpell load /path/to/wordlist.txt

# Run as daemon
zpell daemon --rpc --port 9876
```

## Documentation

Full documentation is available in the `docs/` directory:

- [Introduction](docs/manual/01-introduction.md)
- [Configuration](docs/manual/02-configuration.md)
- [API Reference](docs/manual/03-api-reference.md)
- [Module Development](docs/manual/04-module-development.md)
- [Wordlist Loading](docs/manual/06-wordlist-loading.md)
- [Dotfile Patterns](docs/manual/07-dotfile.md)
- [RPC Interface](docs/manual/08-rpc.md)
- [IPC Interface](docs/manual/09-ipc.md)
- [Advanced Topics](docs/manual/0advanced-topcs.md)

## Architecture

ZPell is built in 5 stages:

1. **Core Infrastructure**: CMake build system, third-party integration
2. **Core Engine**: BK-Tree, distance calculation, wordlist management
3. **Configuration**: TOML parsing, pattern matching, dotfile support
4. **Extensibility**: Module system, Lua bindings, RPC/IPC
5. **CLI & Testing**: Command-line interface, test suite, documentation

## Dependencies

- C++20 compiler (GCC 10+, Clang 12+)
- CMake 3.20+
- Third-party libraries (included):
  - Catch2 (testing)
  - CLI11 (command-line parsing)
  - PEGTL (parsing)
  - rapidfuzz-cpp (fuzzy matching)
  - libmdbx (caching)
  - Lua (scripting)
  - Oniguruma (regex)
  - tomlc99 (configuration)
  - msgpack11 (serialization)
  - jsonrpc-lean (RPC)
  - Boost.Interprocess (IPC)
  - Boost.DLL (module loading)

## Configuration Example

```toml
# ~/.config/zpell/Config.toml

wordlist_path = "/usr/share/dict/words"
dotfile_path = "~/.zpell"

[rpc]
host = "127.0.0.1"
port = 9876

[cache]
enable = true
path = "~/.cache/zpell/cache.mdb"

[checking]
max_suggestions = 5
max_distance = 2
```

## API Example

```cpp
#include "zpell-api.h"

int main() {
    zpell::ZPell zpell;
    zpell.load_wordlist("/usr/share/dict/words");
    
    // Check spelling
    bool correct = zpell.check("hello");
    
    // Get suggestions
    auto suggestions = zpell.suggest("helo", 5);
    for (const auto& [word, distance] : suggestions) {
        std::cout << word << " (distance: " << distance << ")\n";
    }
    
    return 0;
}
```

## Testing

```bash
cd build
ctest --output-on-failure
```

## License

See LICENSE file for details.

## Contributing

Contributions are welcome! Please see CONTRIBUTING.md for guidelines.

## Author

Developed following the 5-stage implementation plan defined in AGENTS.md.
