# Test suite

add_executable(zpell_tests
    test_distance.cpp
    test_bktree.cpp
    test_wordlist.cpp
    test_config.cpp
    test_pattern.cpp
)

target_link_libraries(zpell_tests PRIVATE
    zpelltree
    Catch2::Catch2WithMain
)

target_include_directories(zpell_tests PRIVATE
    ${CMAKE_SOURCE_DIR}/include
)

# Register tests with CTest
include(CTest)
add_test(NAME zpell_tests COMMAND zpell_tests)
