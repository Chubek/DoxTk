# Introduction to ZPell

## What is ZPell?

ZPell is a high-performance, modular spellchecker designed for extensibility and speed. It uses BK-Trees (Burkhard-Keller trees) for efficient spell checking and suggestion generation.

## Architecture Overview

ZPell consists of several key components:

### Core Engine
- **BK-Tree**: Fast data structure for approximate string matching
- **Distance Calculator**: Levenshtein edit distance implementation
- **Wordlist Manager**: Loads and manages dictionary files

### Configuration System
- TOML-based configuration files
- XDG Base Directory specification support
- Runtime configuration override

### Pattern Matching
- Regex-based pattern matching using Oniguruma
- Support for inclusion and exclusion patterns
- Custom delimiter support (`/pattern/` or `|pattern|`)

### Extensibility
- **Module System**: Load custom modules via shared libraries
- **Lua Bindings**: Script ZPell behavior with Lua
- **RPC Interface**: JSON-RPC server for remote access
- **IPC Interface**: Shared memory for local inter-process communication

## BK-Tree Explanation

A BK-Tree is a metric tree specifically adapted to discrete metric spaces. For spell checking:

1. Each node contains a word
2. Children are indexed by edit distance from parent
3. Search prunes branches based on triangle inequality
4. Provides O(log n) average search time

This makes ZPell significantly faster than linear dictionary scans.

## Use Cases

- Command-line spell checking
- Editor integration via RPC/IPC
- Custom spell checking pipelines
- Domain-specific dictionaries
- Multi-language support through modules
