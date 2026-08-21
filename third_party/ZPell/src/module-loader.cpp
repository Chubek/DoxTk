#include "module-loader.h"
#include <dlfcn.h>

namespace zpell {

ModuleLoader::~ModuleLoader() {
    unload_all();
}

bool ModuleLoader::load(const std::filesystem::path& path) {
    if (!std::filesystem::exists(path)) {
        return false;
    }
    
    void* handle = dlopen(path.string().c_str(), RTLD_LAZY);
    if (!handle) {
        return false;
    }
    
    // Look for module creation function
    typedef IModule* (*CreateModuleFn)();
    CreateModuleFn create_fn = reinterpret_cast<CreateModuleFn>(dlsym(handle, "zpell_create_module"));
    
    if (!create_fn) {
        dlclose(handle);
        return false;
    }
    
    IModule* module = create_fn();
    if (!module) {
        dlclose(handle);
        return false;
    }
    
    // Initialize module
    if (!module->initialize()) {
        delete module;
        dlclose(handle);
        return false;
    }
    
    // Store loaded module
    LoadedModule lm;
    lm.handle = handle;
    lm.module = module;
    lm.path = path;
    
    loaded_.push_back(std::move(lm));
    modules_.push_back(module);
    
    return true;
}

void ModuleLoader::unload_all() {
    for (auto& lm : loaded_) {
        delete lm.module;
        dlclose(lm.handle);
    }
    loaded_.clear();
    modules_.clear();
}

} // namespace zpell
