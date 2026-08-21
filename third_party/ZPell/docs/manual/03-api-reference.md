# API Reference

## Core Classes

### ZPell

Main API class for spell checking.

```cpp
#include "zpell-api.h"

zpell::ZPell zpell;
zpell.initialize(config);

// Check spelling
bool correct = zpell.check("hello");

// Get suggestions
auto suggestions = zpell.suggest("helo", 5);
for (const auto& [word, distance] : suggestions) {
    std::cout << word << " (distance: " << distance << ")\n";
}
```

### BKTree

BK-Tree implementation for fast approximate string matching.

```cpp
#include "bktree.h"

zpell::BKTree tree;
tree.insert("hello");
tree.insert("world");

auto results = tree.search("helo", 2);
```

### Distance

Edit distance calculation.

```cpp
#include "distance.h"

int dist = zpell::edit_distance("hello", "hallo");
double norm = zpell::normalized_distance("hello", "hallo");
```

### Config

Configuration management.

```cpp
#include "config.h"

auto config = zpell::ConfigLoader::load("/path/to/config.toml");
if (config) {
    zpell::ZPell zpell(*config);
}
```

### PatternMatcher

Regex-based pattern matching.

```cpp
#include "pattern.h"

zpell::PatternMatcher matcher;
matcher.add_pattern("test.*", false, '/');
matcher.add_pattern("bad.*", true, '/');  // Exclusion

bool matches = matcher.matches("testing");
```

## Module Interface

```cpp
#include "zpell-module.h"

class MyModule : public zpell::IModule {
public:
    zpell::ModuleInfo get_info() const override {
        return {"MyModule", "1.0", "Description", zpell::MODULE_API_VERSION};
    }
    
    bool initialize() override {
        return true;
    }
    
    std::vector<std::string> process(const std::string& word) override {
        // Process word
        return {word};
    }
};

ZPELL_MODULE_EXPORT zpell::IModule* zpell_create_module() {
    return new MyModule();
}
```

## Lua Bindings

```lua
-- Check word
local correct = zpell.check("hello")

-- Get suggestions
local suggestions = zpell.suggest("helo", 5)
for i, sugg in ipairs(suggestions) do
    print(sugg.word, sugg.distance)
end
```
