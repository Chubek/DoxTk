# ZPell Documentation

ZPell is a modular, extensible spellchecker built around BK-Trees and edit distance algorithms.

## Features

- Fast spell checking using BK-Tree data structure
- Configurable via TOML configuration files
- Pattern matching with regex support
- Extensible module system
- Lua scripting support
- JSON-RPC and IPC interfaces
- Persistent caching with libmdbx

## Documentation Sections

- [Introduction](manual/01-introduction.md) - Overview and architecture
- [Configuration](manual/02-configuration.md) - Configuration file format
- [API Reference](manual/03-api-reference.md) - C++ API documentation
- [Module Development](manual/04-module-development.md) - Creating custom modules
- [Wordlist Loading](manual/06-wordlist-loading.md) - Managing wordlists
- [Dotfile](manual/07-dotfile.md) - Pattern matching with .zpell files
- [RPC](manual/08-rpc.md) - JSON-RPC interface
- [IPC](manual/09-ipc.md) - Inter-process communication
- [Advanced Topics](manual/0advanced-topcs.md) - Performance tuning and optimization

## Quick Start

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

## Building

```bash
mkdir build && cd build
cmake ..
make
make test
```

## License

See LICENSE file for details.
