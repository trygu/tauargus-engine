# Tau-Argus — top-level native superbuild.
#
# Builds the six SDC engine modules in dependency order:
#   core    (static; shared data structures / utilities)
#   csp     (LP/MIP engine, HiGHS-backed)
#   hitas   (hierarchical table suppression; links csp)
#   crp     (controlled rounding, HiGHS-backed)
#   rounder (thin C++ dispatch over crp)
#   ghm     (hypercube secondary suppression; standalone, no solver)
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

option(BUILD_SHARED_LIBS "Build shared native libraries" ON)

if(NOT DEFINED CMAKE_CXX_STANDARD)
    set(CMAKE_CXX_STANDARD 11)
endif()
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# The static core lib is linked into the Python extension (a shared object).
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# Linux: statically link the C++ runtime into the shared libraries so the
# shipped binaries do not depend on the host libstdc++ version. Without
# this, a build on a new runner (GLIBCXX_3.4.32 on ubuntu-24.04) fails to
# load on older distros (missed at 0.5.5). --exclude-libs keeps the
# embedded runtime's symbols local to each library: if they were exported,
# a second C++ runtime in the same process (for example pyarrow's dynamic
# libstdc++) would bind to them and the two runtimes would corrupt each
# other (observed as free(): invalid pointer when importing pyarrow after
# pytauargus).
if(CMAKE_SYSTEM_NAME STREQUAL "Linux" AND CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
    # Keep a single string: appending a multi-element CMake list leaks
    # ';' list separators into the link line. One -Wl per archive,
    # because the GCC driver splits -Wl, lists on commas (a comma-joined
    # list would pass the extra names to the linker as bare file names).
    set(CMAKE_SHARED_LINKER_FLAGS
        "${CMAKE_SHARED_LINKER_FLAGS} -static-libstdc++ -static-libgcc -Wl,--exclude-libs,libstdc++.a -Wl,--exclude-libs,libsupc++.a -Wl,--exclude-libs,libgcc.a -Wl,--exclude-libs,libgcc_eh.a")
endif()

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
add_subdirectory(native/ghm)

# ---------------------------------------------------------------------------
# CMake package (standalone releases)
#
# install(EXPORT) records the six module targets with their link
# dependencies (hitas on csp, rounder on crp, csp and crp on Highs);
# the config file adds the tauargus::<module> alias targets and makes
# the pinned HiGHS findable from the bundled copy under <prefix>/highs.
# A release stage bundles that HiGHS next to the installed prefix, e.g.:
#
#   cmake --install engine/build --prefix <stage>/tauargus-engine
#   cp -r <highs-install-prefix>/. <stage>/tauargus-engine/highs
#
# Consumers then: find_package(tauargus-engine REQUIRED).
install(TARGETS tauargus_core tauargus_csp tauargus_hitas CRP
        tauargus_rounder tauargus_ghm
    EXPORT tauargus-engine)
install(EXPORT tauargus-engine
    FILE tauargus-engine-targets.cmake
    NAMESPACE tauargus::
    DESTINATION lib/cmake/tauargus-engine)

include(CMakePackageConfigHelpers)
configure_file(cmake/tauargus-engine-config.cmake.in
    "${CMAKE_CURRENT_BINARY_DIR}/tauargus-engine-config.cmake" @ONLY)
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/tauargus-engine-config.cmake"
    DESTINATION lib/cmake/tauargus-engine)
