# Inter-Process Communication (IPC)

## Overview

ZPell provides IPC via shared memory for high-performance local communication.

## Starting the IPC Server

### Command Line

```bash
zpell daemon --ipc
```

### Configuration

```toml
[ipc]
name = "zpell_ipc"
```

### Programmatically

```cpp
#include "ipc.h"

zpell::ZPell zpell;
zpell::IPCServer ipc;

ipc.initialize(&zpell, "zpell_ipc");
ipc.run();  // Blocking
```

## IPC Protocol

### Message Structure

```cpp
struct IPCMessage {
    enum class Type {
        CHECK_WORD,
        SUGGEST,
        RELOAD,
        RESPONSE
    };
    
    Type type;
    std::string data;
    std::vector<std::string> results;
};
```

### Message Types

- **CHECK_WORD**: Check if word is correct
- **SUGGEST**: Get spelling suggestions
- **RELOAD**: Reload wordlist
- **RESPONSE**: Server response

## Client Implementation

### C++ Client

```cpp
#include <boost/interprocess/shared_memory_object.hpp>
#include <boost/interprocess/mapped_region.hpp>

class ZPellIPCClient {
public:
    bool connect(const std::string& name) {
        try {
            shm_ = std::make_unique<boost::interprocess::shared_memory_object>(
                boost::interprocess::open_only,
                name.c_str(),
                boost::interprocess::read_write
            );
            
            region_ = std::make_unique<boost::interprocess::mapped_region>(
                *shm_,
                boost::interprocess::read_write
            );
            
            return true;
        } catch (...) {
            return false;
        }
    }
    
    bool check_word(const std::string& word) {
        // Send CHECK_WORD message
        // Read response
        return true;
    }
    
    std::vector<std::string> suggest(const std::string& word) {
        // Send SUGGEST message
        // Read response
        return {};
    }
    
private:
    std::unique_ptr<boost::interprocess::shared_memory_object> shm_;
    std::unique_ptr<boost::interprocess::mapped_region> region_;
};
```

## Performance Comparison

| Method | Latency | Throughput |
|--------|---------|------------|
| IPC    | ~10μs   | ~100k ops/s |
| RPC    | ~1ms    | ~1k ops/s   |
| CLI    | ~10ms   | ~100 ops/s  |

## Use Cases

### Editor Integration

```cpp
// Vim/Neovim plugin
class VimSpellChecker {
    ZPellIPCClient client;
    
public:
    void initialize() {
        client.connect("zpell_ipc");
    }
    
    bool check_word_under_cursor() {
        std::string word = get_current_word();
        return client.check_word(word);
    }
    
    void show_suggestions() {
        std::string word = get_current_word();
        auto suggestions = client.suggest(word);
        display_popup(suggestions);
    }
};
```

### Real-time Checking

```cpp
// Document processor
class DocumentChecker {
    ZPellIPCClient client;
    
public:
    void check_document(const std::string& text) {
        auto words = tokenize(text);
        
        for (const auto& word : words) {
            if (!client.check_word(word)) {
                mark_misspelled(word);
            }
        }
    }
};
```

## Synchronization

### Mutex Protection

```cpp
#include <boost/interprocess/sync/interprocess_mutex.hpp>
#include <boost/interprocess/sync/scoped_lock.hpp>

struct SharedData {
    boost::interprocess::interprocess_mutex mutex;
    char message[1024];
    bool ready;
};

// Client
{
    boost::interprocess::scoped_lock<boost::interprocess::interprocess_mutex> 
        lock(data->mutex);
    
    // Write message
    strcpy(data->message, "hello");
    data->ready = true;
}
```

## Memory Layout

```
+------------------+
| Mutex            | 64 bytes
+------------------+
| Message Type     | 4 bytes
+------------------+
| Data Length      | 4 bytes
+------------------+
| Data Buffer      | 65472 bytes
+------------------+
| Total            | 65536 bytes (64KB)
+------------------+
```

## Best Practices

1. **Connection Pooling**: Reuse connections for multiple requests
2. **Timeout Handling**: Implement timeouts for IPC operations
3. **Error Recovery**: Handle shared memory cleanup on crashes
4. **Message Batching**: Batch multiple checks for efficiency
5. **Memory Limits**: Monitor shared memory usage

## Troubleshooting

### Shared Memory Not Found

```bash
# List shared memory segments
ls -l /dev/shm/

# Remove stale segment
rm /dev/shm/zpell_ipc
```

### Permission Denied

```bash
# Check permissions
ls -l /dev/shm/zpell_ipc

# Fix permissions
chmod 666 /dev/shm/zpell_ipc
```

### Memory Leak

```bash
# Monitor shared memory
watch -n 1 'ls -lh /dev/shm/'

# Clean up on exit
trap 'rm -f /dev/shm/zpell_ipc' EXIT
```
