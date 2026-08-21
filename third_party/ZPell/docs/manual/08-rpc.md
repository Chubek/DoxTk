# JSON-RPC Interface

## Overview

ZPell provides a JSON-RPC 2.0 server for remote spell checking.

## Starting the RPC Server

### Command Line

```bash
zpell daemon --rpc --host 127.0.0.1 --port 9876
```

### Configuration

```toml
[rpc]
host = "127.0.0.1"
port = 9876
```

### Programmatically

```cpp
#include "rpc.h"

zpell::ZPell zpell;
zpell::RPCServer rpc;

rpc.initialize(&zpell, "127.0.0.1", 9876);
rpc.run();  // Blocking
```

## RPC Methods

### check_word

Check if a word is spelled correctly.

**Request:**
```json
{
    "jsonrpc": "2.0",
    "method": "check_word",
    "params": {
        "word": "hello"
    },
    "id": 1
}
```

**Response:**
```json
{
    "jsonrpc": "2.0",
    "result": true,
    "id": 1
}
```

### suggest

Get spelling suggestions for a word.

**Request:**
```json
{
    "jsonrpc": "2.0",
    "method": "suggest",
    "params": {
        "word": "helo",
        "max_suggestions": 5
    },
    "id": 2
}
```

**Response:**
```json
{
    "jsonrpc": "2.0",
    "result": [
        {"word": "hello", "distance": 1},
        {"word": "help", "distance": 2},
        {"word": "hero", "distance": 2}
    ],
    "id": 2
}
```

### reload

Reload the wordlist.

**Request:**
```json
{
    "jsonrpc": "2.0",
    "method": "reload",
    "params": {},
    "id": 3
}
```

**Response:**
```json
{
    "jsonrpc": "2.0",
    "result": true,
    "id": 3
}
```

## Client Examples

### Python

```python
import requests
import json

def check_word(word):
    payload = {
        "jsonrpc": "2.0",
        "method": "check_word",
        "params": {"word": word},
        "id": 1
    }
    response = requests.post("http://127.0.0.1:9876", json=payload)
    return response.json()["result"]

def suggest(word, max_suggestions=5):
    payload = {
        "jsonrpc": "2.0",
        "method": "suggest",
        "params": {
            "word": word,
            "max_suggestions": max_suggestions
        },
        "id": 2
    }
    response = requests.post("http://127.0.0.1:9876", json=payload)
    return response.json()["result"]

# Usage
print(check_word("hello"))  # True
print(suggest("helo"))      # [{"word": "hello", "distance": 1}, ...]
```

### JavaScript

```javascript
async function checkWord(word) {
    const response = await fetch('http://127.0.0.1:9876', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({
            jsonrpc: '2.0',
            method: 'check_word',
            params: {word},
            id: 1
        })
    });
    const data = await response.json();
    return data.result;
}

async function suggest(word, maxSuggestions = 5) {
    const response = await fetch('http://127.0.0.1:9876', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({
            jsonrpc: '2.0',
            method: 'suggest',
            params: {word, max_suggestions: maxSuggestions},
            id: 2
        })
    });
    const data = await response.json();
    return data.result;
}
```

### curl

```bash
# Check word
curl -X POST http://127.0.0.1:9876 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"check_word","params":{"word":"hello"},"id":1}'

# Get suggestions
curl -X POST http://127.0.0.1:9876 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"suggest","params":{"word":"helo","max_suggestions":5},"id":2}'
```

## Error Handling

**Error Response:**
```json
{
    "jsonrpc": "2.0",
    "error": {
        "code": -32602,
        "message": "Invalid params"
    },
    "id": 1
}
```

**Error Codes:**
- `-32700`: Parse error
- `-32600`: Invalid request
- `-32601`: Method not found
- `-32602`: Invalid params
- `-32603`: Internal error

## Security Considerations

1. **Bind to localhost**: Use `127.0.0.1` for local-only access
2. **Firewall**: Block external access to RPC port
3. **Authentication**: Add authentication layer if exposing publicly
4. **Rate Limiting**: Implement rate limiting for production use
