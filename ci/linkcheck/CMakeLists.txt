# Link + load check for the installed engine bundle.
#
# Configure with -DBUNDLE_DIR=<unpacked bundle>. The program links the
# bundled tauargus_csp library from <bundle>/lib only (no other engine
# or HiGHS paths), so a broken or incomplete bundle fails here.
#
#   cmake -S ci/linkcheck -B build -DBUNDLE_DIR=<bundle>
#   cmake --build build [--config Release]   # multi-config generators
cmake_minimum_required(VERSION 3.16)
project(engine_bundle_linkcheck C)

if(NOT DEFINED BUNDLE_DIR OR BUNDLE_DIR STREQUAL "")
    message(FATAL_ERROR "BUNDLE_DIR is required (the unpacked engine bundle)")
endif()

find_library(TAU_CSP_LIB
    NAMES tauargus_csp
    PATHS "${BUNDLE_DIR}/lib"
    NO_DEFAULT_PATH)
if(NOT TAU_CSP_LIB)
    message(FATAL_ERROR "bundled tauargus_csp library not found under ${BUNDLE_DIR}/lib")
endif()

add_executable(linkcheck main.c)
target_link_libraries(linkcheck PRIVATE "${TAU_CSP_LIB}")
