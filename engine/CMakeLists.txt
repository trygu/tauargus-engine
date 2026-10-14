# Tau-Argus — top-level native superbuild.
#
# Builds the five SDC engine modules in dependency order:
#   core    (static; shared data structures / utilities)
#   csp     (LP/MIP engine, HiGHS-backed)
#   hitas   (hierarchical table suppression; links csp)
#   crp     (controlled rounding, HiGHS-backed)
#   rounder (thin C++ dispatch over crp)
#
# All solver backends converge on the open-source HiGHS. Configure with the
# HiGHS CMake package path, e.g. on macOS Homebrew:
#
#   cmake -S engine -B engine/build \
#         -DHighs_DIR=$(brew --prefix)/lib/cmake/Highs
#   cmake --build engine/build -j

cmake_minimum_required(VERSION 3.16)
project(tauargus_native C CXX)

# Single source of truth for the HiGHS version: engine/HiGHS-VERSION.
# Exported to the sub-builds so their find_package(Highs ...) calls require
# exactly the pinned version. CI and the binding builds read the same file.
file(READ "${CMAKE_CURRENT_SOURCE_DIR}/HiGHS-VERSION" _TA_HIGHS_TAG)
string(STRIP "${_TA_HIGHS_TAG}" _TA_HIGHS_TAG)
string(REGEX REPLACE "^v" "" TAUARGUS_HIGHS_VERSION "${_TA_HIGHS_TAG}")
message(STATUS "tauargus: requiring HiGHS ${TAUARGUS_HIGHS_VERSION}")

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# The static core lib is linked into the Python extension (a shared object).
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# Centralize build outputs: all shared/static libs in <build>/lib, binaries in
# <build>/bin. (Directory-scoped; inherited by the add_subdirectory calls below.)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

# Default HiGHS search hint (overridable via -DHighs_DIR).
if(NOT DEFINED Highs_DIR AND CMAKE_SYSTEM_NAME STREQUAL "Darwin")
    find_program(BREW brew)
    if(BREW)
        execute_process(COMMAND ${BREW} --prefix
                        OUTPUT_VARIABLE _BREW_PREFIX
                        OUTPUT_STRIP_TRAILING_WHITESPACE)
        if(EXISTS "${_BREW_PREFIX}/lib/cmake/Highs")
            set(Highs_DIR "${_BREW_PREFIX}/lib/cmake/Highs")
        endif()
    endif()
endif()

add_subdirectory(native/core)
add_subdirectory(native/csp)
add_subdirectory(native/hitas)
add_subdirectory(native/crp)
add_subdirectory(native/rounder)
