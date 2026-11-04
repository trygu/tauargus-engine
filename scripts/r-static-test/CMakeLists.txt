cmake_minimum_required(VERSION 3.16)
project(r_static_link_test C CXX)
add_subdirectory("${TAUARGUS_ROOT}/engine" engine)
add_executable(r_static_link_test smoke.cpp)
target_link_libraries(r_static_link_test PRIVATE
    tauargus::core tauargus::hitas tauargus::rounder)
enable_testing()
add_test(NAME r_static_link_test COMMAND r_static_link_test)
