#ifndef ZPELL_MODULE_H
#define ZPELL_MODULE_H

#include <string>
#include <vector>

namespace zpell {

/**
 * @brief Module interface version
 */
constexpr int MODULE_API_VERSION = 1;

/**
 * @brief Module information
 */
struct ModuleInfo {
    const char* name;
    const char* version;
    const char* description;
    int api_version;
};

/**
 * @brief Module interface
 */
class IModule {
public:
    virtual ~IModule() = default;
    
    /**
     * @brief Get module information
     */
    virtual ModuleInfo get_info() const = 0;
    
    /**
     * @brief Initialize module
     */
    virtual bool initialize() = 0;
    
    /**
     * @brief Process a word
     * @param word Input word
     * @return Processed word or suggestions
     */
    virtual std::vector<std::string> process(const std::string& word) = 0;
};

} // namespace zpell

// Module entry point macro
#define ZPELL_MODULE_EXPORT extern "C"

#endif // ZPELL_MODULE_H
