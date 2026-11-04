cmake_minimum_required(VERSION 3.16)
project(r_host_io_tests C CXX)
set(CMAKE_CXX_STANDARD 11)
find_package(Threads REQUIRED)
add_executable(r_host_io_tests test.cpp
    "${FIXTURE_DIR}/native.c" "${FIXTURE_DIR}/native.cpp"
    "${BINDING_SRC}/rta_host_io.cpp")
target_include_directories(r_host_io_tests PRIVATE "${BINDING_SRC}" "${R_INCLUDE}")
target_compile_options(r_host_io_tests PRIVATE
    $<$<COMPILE_LANGUAGE:C>:-fexceptions>)
target_link_libraries(r_host_io_tests PRIVATE Threads::Threads)
enable_testing()
add_test(NAME r_host_io COMMAND r_host_io_tests)

add_library(r_host_bad_format STATIC EXCLUDE_FROM_ALL "${FIXTURE_DIR}/bad-format.c")
target_compile_options(r_host_bad_format PRIVATE -Wformat -Werror=format)
