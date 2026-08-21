# Module Development

## Creating a ZPell Module

Modules extend ZPell functionality through a plugin architecture.

## Module Interface

All modules must implement the `IModule` interface:

```cpp
#include "zpell-module.h"

class MySpellModule : public zpell::IModule {
public:
    zpell::ModuleInfo get_info() const override {
        return {
            "MySpellModule",           // name
            "1.0.0",                   // version
            "Custom spell checker",    // description
            zpell::MODULE_API_VERSION  // API version
        };
    }
    
    bool initialize() override {
        // Initialize module resources
        return true;
    }
    
    std::vector<std::string> process(const std::string& word) override {
        // Process word and return suggestions
        std::vector<std::string> results;
        // ... custom logic ...
        return results;
    }
};
```

## Module Entry Point

Export the module creation function:

```cpp
ZPELL_MODULE_EXPORT zpell::IModule* zpell_create_module() {
    return new MySpellModule();
}
```

## Building a Module

Create a CMakeLists.txt:

```cmake
cmake_minimum_required(VERSION 3.20)
project(MySpellModule)

set(CMAKE_CXX_STANDARD 20)

add_library(myspell MODULE myspell.cpp)

target_include_directories(myspell PRIVATE
    /usr/include/zpell
)

set_target_properties(myspell PROPERTIES
    PREFIX ""
    SUFFIX ".so"
)
```

Build:

```bash
mkdir build && cd build
cmake ..
make
```

## Loading Modules

### Via Configuration

```toml
module_paths = ["/path/to/modules"]
```

### Programmatically

```cpp
zpell::ModuleLoader loader;
loader.load("/path/to/myspell.so");

for (auto* module : loader.modules()) {
    auto info = module->get_info();
    std::cout << "Loaded: " << info.name << "\n";
}
```

## Module Best Practices

1. **Thread Safety**: Modules may be called from multiple threads
2. **Error Handling**: Return empty results on error, don't throw
3. **Resource Management**: Clean up in destructor
4. **API Version**: Always check API version compatibility
5. **Documentation**: Provide clear module documentation

## Example: Domain-Specific Module

```cpp
class MedicalSpellModule : public zpell::IModule {
private:
    std::unordered_set<std::string> medical_terms;
    
public:
    bool initialize() override {
        // Load medical dictionary
        medical_terms = load_medical_terms();
        return !medical_terms.empty();
    }
    
    std::vector<std::string> process(const std::string& word) override {
        std::vector<std::string> results;
        
        // Check if word is medical term
        if (medical_terms.count(word)) {
            results.push_back(word);
        }
        
        // Find similar medical terms
        for (const auto& term : medical_terms) {
            if (similar(word, term)) {
                results.push_back(term);
            }
        }
        
        return results;
    }
};
```
