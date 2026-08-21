cmake_minimum_required(VERSION 3.20)
project(ZPell VERSION 1.0.0 LANGUAGES CXX C)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Build options
option(BUILD_TESTS "Build test suite" ON)
option(BUILD_DOCS "Build documentation" ON)

# Find system dependencies
find_package(Threads REQUIRED)

# Third-party libraries
add_subdirectory(third_party)

# Core library
add_subdirectory(src)

# Include directories
include_directories(${CMAKE_SOURCE_DIR}/include)

# Documentation
if(BUILD_DOCS)
    add_subdirectory(docs)
endif()

# Tests
if(BUILD_TESTS)
    enable_testing()
    add_subdirectory(tests)
endif()
