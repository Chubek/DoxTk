#ifndef ZPELL_LUA_BINDINGS_H
#define ZPELL_LUA_BINDINGS_H

#include <string>
#include <filesystem>

struct lua_State;

namespace zpell {

class ZPell;

/**
 * @brief Lua scripting interface
 */
class LuaBindings {
public:
    LuaBindings();
    ~LuaBindings();
    
    /**
     * @brief Initialize Lua state
     * @param zpell ZPell instance to bind
     * @return True if successful
     */
    bool initialize(ZPell* zpell);
    
    /**
     * @brief Execute Lua script
     * @param script Script content
     * @return True if successful
     */
    bool execute(const std::string& script);
    
    /**
     * @brief Execute Lua file
     * @param path Path to script file
     * @return True if successful
     */
    bool execute_file(const std::filesystem::path& path);
    
    /**
     * @brief Get Lua state
     * @return Lua state pointer
     */
    lua_State* state() const { return L_; }
    
private:
    lua_State* L_ = nullptr;
    ZPell* zpell_ = nullptr;
};

} // namespace zpell

#endif // ZPELL_LUA_BINDINGS_H
