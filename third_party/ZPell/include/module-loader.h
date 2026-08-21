#ifndef ZPELL_MODULE_LOADER_H
#define ZPELL_MODULE_LOADER_H

#include "zpell-module.h"
#include <filesystem>
#include <memory>
#include <vector>

namespace zpell {

/**
 * @brief Dynamic module loader
 */
class ModuleLoader {
public:
    ModuleLoader() = default;
    ~ModuleLoader();
    
    /**
     * @brief Load a module from shared library
     * @param path Path to .so/.dll file
     * @return True if successful
     */
    bool load(const std::filesystem::path& path);
    
    /**
     * @brief Unload all modules
     */
    void unload_all();
    
    /**
     * @brief Get loaded modules
     * @return Vector of module pointers
     */
    const std::vector<IModule*>& modules() const { return modules_; }
    
private:
    struct LoadedModule {
        void* handle;
        IModule* module;
        std::filesystem::path path;
    };
    
    std::vector<LoadedModule> loaded_;
    std::vector<IModule*> modules_;
};

} // namespace zpell

#endif // ZPELL_MODULE_LOADER_H
