# ZPell core library
add_library(zpelltree STATIC
    bktree.cpp
    distance.cpp
    wordlist.cpp
    cache.cpp
    config.cpp
    pattern.cpp
    module-loader.cpp
    lua-bindings.cpp
    rpc.cpp
    ipc.cpp
    zpell-api.cpp
)

target_include_directories(zpelltree PUBLIC
    ${CMAKE_SOURCE_DIR}/include
    ${CMAKE_SOURCE_DIR}/third_party/rapidfuzz-cpp
    ${CMAKE_SOURCE_DIR}/third_party/PEGTL/include
    ${CMAKE_SOURCE_DIR}/third_party/CLI11/include
)

target_link_libraries(zpelltree PUBLIC
    Threads::Threads
    mdbx-static
    tomlc99
    boost_interprocess
    boost_dll
)

# Check if Lua was built
if(TARGET lua_static)
    target_link_libraries(zpelltree PUBLIC lua_static)
elseif(TARGET lua)
    target_link_libraries(zpelltree PUBLIC lua)
endif()

# Check if oniguruma was built
if(TARGET onig)
    target_link_libraries(zpelltree PUBLIC onig)
endif()

# CLI executable
add_executable(zpell_cli
    zpell-cli.cpp
)

target_link_libraries(zpell_cli PRIVATE
    zpelltree
)

set_target_properties(zpell_cli PROPERTIES OUTPUT_NAME zpell)

# Install targets
install(TARGETS zpell_cli DESTINATION bin)
install(TARGETS zpelltree DESTINATION lib)
install(DIRECTORY ${CMAKE_SOURCE_DIR}/include/ DESTINATION include/zpell)
