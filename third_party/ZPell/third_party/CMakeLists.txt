# Third-party library integration

# Catch2 - Testing framework
add_subdirectory(Catch2)

# CLI11 - Header-only command line parser
add_subdirectory(CLI11)

# PEGTL - Header-only parsing library
set(PEGTL_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(PEGTL_BUILD_TESTS OFF CACHE BOOL "" FORCE)
add_subdirectory(PEGTL)

# rapidfuzz-cpp - Header-only fuzzy string matching
add_subdirectory(rapidfuzz-cpp)

# libmdbx - Embedded database
set(MDBX_BUILD_SHARED_LIBRARY OFF CACHE BOOL "" FORCE)
set(MDBX_BUILD_TOOLS OFF CACHE BOOL "" FORCE)
add_subdirectory(libmdbx)

# Lua - Scripting language
if(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/lua/CMakeLists.txt)
    add_subdirectory(lua)
else()
    # Build Lua manually
    file(GLOB LUA_SOURCES lua/*.c)
    list(REMOVE_ITEM LUA_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/lua/lua.c)
    list(REMOVE_ITEM LUA_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/lua/luac.c)
    
    add_library(lua_static STATIC ${LUA_SOURCES})
    target_include_directories(lua_static PUBLIC lua)
    set_target_properties(lua_static PROPERTIES OUTPUT_NAME lua)
endif()

# oniguruma - Regex library
if(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/oniguruma/CMakeLists.txt)
    add_subdirectory(oniguruma)
else()
    message(WARNING "Oniguruma CMakeLists.txt not found, skipping")
endif()

# tomlc99 - TOML parser
add_library(tomlc99 STATIC
    tomlc99/toml.c
    tomlc99/toml.h
)
target_include_directories(tomlc99 PUBLIC tomlc99)

# msgpack11 - MessagePack serialization (disabled due to compilation issues)
# if(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/msgpack11/CMakeLists.txt)
#     add_subdirectory(msgpack11)
# else()
#     message(WARNING "msgpack11 CMakeLists.txt not found, skipping")
# endif()

# jsonrpc-lean - JSON-RPC library (disabled - not needed for basic functionality)
# if(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/jsonrpc-lean/CMakeLists.txt)
#     add_subdirectory(jsonrpc-lean)
# else()
#     message(WARNING "jsonrpc-lean CMakeLists.txt not found, skipping")
# endif()

# Boost.Interprocess - Header-only IPC
add_library(boost_interprocess INTERFACE)
target_include_directories(boost_interprocess INTERFACE boost.interprocess/include)

# Boost.DLL - Dynamic library loading
add_library(boost_dll INTERFACE)
target_include_directories(boost_dll INTERFACE boost.dll/include)
