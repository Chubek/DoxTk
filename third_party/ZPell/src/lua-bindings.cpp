#include "lua-bindings.h"
#include "zpell-api.h"
#include <lua.hpp>

namespace zpell {

// Lua C functions
static int lua_zpell_check(lua_State* L) {
    ZPell* zpell = *static_cast<ZPell**>(lua_touserdata(L, lua_upvalueindex(1)));
    const char* word = luaL_checkstring(L, 1);
    
    bool result = zpell->check(word);
    lua_pushboolean(L, result);
    return 1;
}

static int lua_zpell_suggest(lua_State* L) {
    ZPell* zpell = *static_cast<ZPell**>(lua_touserdata(L, lua_upvalueindex(1)));
    const char* word = luaL_checkstring(L, 1);
    int max_suggestions = luaL_optinteger(L, 2, 5);
    
    auto suggestions = zpell->suggest(word, max_suggestions);
    
    lua_newtable(L);
    for (size_t i = 0; i < suggestions.size(); ++i) {
        lua_newtable(L);
        
        lua_pushstring(L, "word");
        lua_pushstring(L, suggestions[i].first.c_str());
        lua_settable(L, -3);
        
        lua_pushstring(L, "distance");
        lua_pushinteger(L, suggestions[i].second);
        lua_settable(L, -3);
        
        lua_rawseti(L, -2, i + 1);
    }
    
    return 1;
}

LuaBindings::LuaBindings() {
    L_ = luaL_newstate();
    if (L_) {
        luaL_openlibs(L_);
    }
}

LuaBindings::~LuaBindings() {
    if (L_) {
        lua_close(L_);
    }
}

bool LuaBindings::initialize(ZPell* zpell) {
    if (!L_ || !zpell) return false;
    
    zpell_ = zpell;
    
    // Create zpell table
    lua_newtable(L_);
    
    // Store zpell pointer as upvalue
    ZPell** udata = static_cast<ZPell**>(lua_newuserdata(L_, sizeof(ZPell*)));
    *udata = zpell;
    
    // Register functions
    lua_pushvalue(L_, -1);
    lua_pushcclosure(L_, lua_zpell_check, 1);
    lua_setfield(L_, -3, "check");
    
    lua_pushvalue(L_, -1);
    lua_pushcclosure(L_, lua_zpell_suggest, 1);
    lua_setfield(L_, -3, "suggest");
    
    lua_pop(L_, 1);  // Pop userdata
    
    // Set global
    lua_setglobal(L_, "zpell");
    
    return true;
}

bool LuaBindings::execute(const std::string& script) {
    if (!L_) return false;
    
    int result = luaL_dostring(L_, script.c_str());
    if (result != LUA_OK) {
        return false;
    }
    
    return true;
}

bool LuaBindings::execute_file(const std::filesystem::path& path) {
    if (!L_ || !std::filesystem::exists(path)) return false;
    
    int result = luaL_dofile(L_, path.string().c_str());
    if (result != LUA_OK) {
        return false;
    }
    
    return true;
}

} // namespace zpell
