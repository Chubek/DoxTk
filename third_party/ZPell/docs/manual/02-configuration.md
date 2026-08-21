# Configuration

## Configuration File Format

ZPell uses TOML for configuration. The default location is:
- `$XDG_CONFIG_HOME/zpell/Config.toml`
- Falls back to `~/.config/zpell/Config.toml`

## Example Configuration

```toml
# Wordlist path
wordlist_path = "/usr/share/dict/words"

# Dotfile path for patterns
dotfile_path = "~/.zpell"

# Module paths
module_paths = [
    "/usr/lib/zpell/modules",
    "~/.local/lib/zpell/modules"
]

# RPC settings
[rpc]
host = "127.0.0.1"
port = 9876

# IPC settings
[ipc]
name = "zpell_ipc"

# Cache settings
[cache]
enable = true
path = "~/.cache/zpell/cache.mdb"

# Spell checking settings
[checking]
max_suggestions = 5
max_distance = 2
```

## Configuration Options

### Wordlist
- `wordlist_path`: Path to dictionary file (one word per line)

### Modules
- `module_paths`: Array of directories to search for modules

### RPC
- `rpc.host`: Host address for RPC server
- `rpc.port`: Port number for RPC server

### IPC
- `ipc.name`: Shared memory segment name

### Cache
- `cache.enable`: Enable/disable persistent caching
- `cache.path`: Path to cache database file

### Checking
- `checking.max_suggestions`: Default number of suggestions
- `checking.max_distance`: Maximum edit distance for suggestions

## Command Line Override

Configuration can be overridden via command line:

```bash
zpell --config /path/to/config.toml check word
zpell --wordlist /custom/words.txt suggest word
zpell --no-cache check word
```
