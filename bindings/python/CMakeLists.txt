cmake_minimum_required(VERSION 3.16)
project(tauargus_python CXX)

set(CMAKE_CXX_STANDARD 11)

find_package(pybind11 CONFIG REQUIRED)

# Root of the tauargus-engine checkout. In-tree builds use the default
# (this dir's grandparent); the pytauargus repo's wheel build passes it
# explicitly (or via the TAUARGUS_ENGINE_DIR environment variable).
if(NOT DEFINED TAUARGUS_ENGINE_DIR)
    if(DEFINED ENV{TAUARGUS_ENGINE_DIR})
        set(TAUARGUS_ENGINE_DIR $ENV{TAUARGUS_ENGINE_DIR})
    else()
        set(TAUARGUS_ENGINE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../..)
    endif()
endif()

# The engine is pre-built by the superbuild (engine/CMakeLists.txt) into
# engine/build/lib. We link the already-compiled libs by path, so their
# file names are resolved per host platform below.
# Build provenance baked into the extension (cpp/py_meta.h.in): the engine
# commit and the pinned HiGHS version, exposed via _tauargus.engine_meta().
execute_process(
    COMMAND git -C ${TAUARGUS_ENGINE_DIR} rev-parse HEAD
    OUTPUT_VARIABLE ENGINE_SHA OUTPUT_STRIP_TRAILING_WHITESPACE
    RESULT_VARIABLE _meta_git_res)
if(NOT _meta_git_res EQUAL 0)
    set(ENGINE_SHA "unknown")
endif()
file(READ ${TAUARGUS_ENGINE_DIR}/engine/HiGHS-VERSION _HIGHS_VERSION_RAW)
string(STRIP "${_HIGHS_VERSION_RAW}" HIGHS_VERSION)
configure_file(cpp/py_meta.h.in ${CMAKE_CURRENT_BINARY_DIR}/py_meta.h @ONLY)

set(NATIVE_LIB_DIR ${TAUARGUS_ENGINE_DIR}/engine/build/lib)
set(NATIVE_CORE_SRC ${TAUARGUS_ENGINE_DIR}/engine/native/core/src)
set(NATIVE_CSP_SRC ${TAUARGUS_ENGINE_DIR}/engine/native/csp/src)
set(NATIVE_HITAS_SRC ${TAUARGUS_ENGINE_DIR}/engine/native/hitas/src)
set(NATIVE_ROUNDER_SRC ${TAUARGUS_ENGINE_DIR}/engine/native/rounder/src)

# Resolve the engine lib file names for the host platform.
#   - macOS / Linux: shared libs are lib<name>.{dylib,so} in build/lib.
#   - Windows: link against import libs (build/lib); runtime DLLs are in
#     build/bin and must be bundled into the wheel separately.
if(APPLE)
    set(ENGINE_SHARED
        ${NATIVE_LIB_DIR}/libtauargus_csp.dylib
        ${NATIVE_LIB_DIR}/libtauargus_hitas.dylib
        ${NATIVE_LIB_DIR}/libtauargus_rounder.dylib
        ${NATIVE_LIB_DIR}/libCRP.dylib)
    set(ENGINE_STATIC ${NATIVE_LIB_DIR}/libtauargus_core.a)
    set(BUNDLE_LIBS ${ENGINE_SHARED})
    set(EXT_BUILD_RPATH "${NATIVE_LIB_DIR};@loader_path")
    set(EXT_INSTALL_RPATH "@loader_path")
elseif(UNIX)
    set(ENGINE_SHARED
        ${NATIVE_LIB_DIR}/libtauargus_csp.so
        ${NATIVE_LIB_DIR}/libtauargus_hitas.so
        ${NATIVE_LIB_DIR}/libtauargus_rounder.so
        ${NATIVE_LIB_DIR}/libCRP.so)
    set(ENGINE_STATIC ${NATIVE_LIB_DIR}/libtauargus_core.a)
    set(BUNDLE_LIBS ${ENGINE_SHARED})
    set(EXT_BUILD_RPATH "${NATIVE_LIB_DIR};$ORIGIN")
    set(EXT_INSTALL_RPATH "$ORIGIN")
elseif(WIN32)
    # Visual Studio is multi-config: the superbuild puts outputs in <dir>/Release.
    set(WIN_LIB_DIR ${NATIVE_LIB_DIR}/Release)
    set(WIN_BIN_DIR ${NATIVE_LIB_DIR}/../bin/Release)
    set(ENGINE_SHARED
        ${WIN_LIB_DIR}/tauargus_csp.lib
        ${WIN_LIB_DIR}/tauargus_hitas.lib
        ${WIN_LIB_DIR}/tauargus_rounder.lib
        ${WIN_LIB_DIR}/CRP.lib)
    set(ENGINE_STATIC ${WIN_LIB_DIR}/tauargus_core.lib)
    set(ENGINE_RUNTIME_DLLS
        ${WIN_BIN_DIR}/tauargus_csp.dll
        ${WIN_BIN_DIR}/tauargus_hitas.dll
        ${WIN_BIN_DIR}/tauargus_rounder.dll
        ${WIN_BIN_DIR}/CRP.dll)
    set(BUNDLE_LIBS ${ENGINE_RUNTIME_DLLS})
    set(EXT_BUILD_RPATH "${WIN_BIN_DIR}")
    set(EXT_INSTALL_RPATH "")
else()
    message(FATAL_ERROR "Unsupported platform for pytauargus build")
endif()

# Five translation units: the module entry point plus one TU per native
# namespace. Separate TUs keep the duplicate IProgressListener classes
# (core vs. hitas) from ever sharing a translation unit.
pybind11_add_module(_tauargus
    cpp/module.cpp
    cpp/bind_core.cpp
    cpp/bind_csp.cpp
    cpp/bind_hitas.cpp
    cpp/bind_rounder.cpp
)

target_include_directories(_tauargus
    PRIVATE
        ${CMAKE_SOURCE_DIR}/cpp
        ${CMAKE_CURRENT_BINARY_DIR}
        ${NATIVE_CORE_SRC}
        ${NATIVE_CSP_SRC}
        ${NATIVE_HITAS_SRC}
        ${NATIVE_ROUNDER_SRC}
)

# Core is a static lib (code copied in). csp/hitas + rounder are shared libs
# (they pull in HiGHS transitively). csp is linked explicitly for the audit
# (TauAuditJj) entry point.
target_link_libraries(_tauargus PRIVATE
    ${ENGINE_STATIC}
    ${ENGINE_SHARED}
)

# Output the extension straight into the python package dir so that a plain
# `import pytauargus._tauargus` works both in dev and inside the wheel. The
# pytauargus repo's wheel build points this at its own src/pytauargus; the
# engine-side binding tests point it at a scratch dir.
if(NOT DEFINED TAUARGUS_PY_PKG_DIR)
    set(TAUARGUS_PY_PKG_DIR ${CMAKE_CURRENT_SOURCE_DIR}/src/pytauargus)
endif()
set(PKG_DIR ${TAUARGUS_PY_PKG_DIR})
set_target_properties(_tauargus PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY ${PKG_DIR}
    LIBRARY_OUTPUT_DIRECTORY_RELEASE ${PKG_DIR}
    BUILD_RPATH "${EXT_BUILD_RPATH}"
    INSTALL_RPATH "${EXT_INSTALL_RPATH}"
)

# Ship the runtime libs next to the extension so the dev build is
# self-contained. rounder links CRP, so CRP must ship alongside it. The wheel
# repair step (delocate/auditwheel/delvewheel) then bundles HiGHS too.
add_custom_command(TARGET _tauargus POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        ${BUNDLE_LIBS}
        ${PKG_DIR}
)

# Install into the wheel so `import pytauargus` works from an installed wheel
# (scikit-build-core runs `cmake --install` into the wheel staging dir).
install(TARGETS _tauargus LIBRARY DESTINATION pytauargus)
install(FILES
    ${BUNDLE_LIBS}
    DESTINATION pytauargus
)
