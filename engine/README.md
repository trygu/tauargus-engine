# Engine

The C/C++ SDC engine. `CMakeLists.txt` is a superbuild of the six git
submodules under `native/`; the build produces the six engine libraries
in `build/lib/`.

## Modules

| Module | Role | Links |
| --- | --- | --- |
| `native/core` | Data model, Argus/JJ file I/O, engine entry points | none (static lib) |
| `native/csp` | Cell-suppression LP (branch-and-price) and feasibility audit | HiGHS |
| `native/hitas` | Hierarchical table suppression (HiTaS) | `csp` |
| `native/crp` | Controlled rounding (iterative rounding, MIP audit) | HiGHS |
| `native/ghm` | Hypercube (GH) secondary suppression (C port of GHMITER, no solver) | none |
| `native/rounder` | Dispatch layer over `crp` | `crp` |

Each module has its own README at `native/<module>/README.md`.

## C++ entry points

- `TauArgus` (`native/core/src/TauArgus.h`): the main engine object;
  table and variable setup, safety rules, suppression dispatch, cell
  access.
- `TauAuditJj()` (`native/csp/src/cspaudit.h`): the feasibility-interval
  audit, the native port of the legacy `intervalle.exe`.

These are internal C++ APIs. The thin bindings in `../bindings/` mirror
them one-to-one, and the user-facing APIs are documented in the
front-end repos:
[pytauargus](https://github.com/trygu/pytauargus/blob/master/docs/python-api.md)
(Python) and
[rtauargus.native](https://github.com/trygu/rtauargus.native) (R).

## Standalone engine releases

Releases are cut per `engine-vX.Y.Z` tag (the first release is
`engine-v0.8.1`), one self-contained package per platform:
`linux-x86_64`, `linux-arm64`, `macos-arm64`, `windows-x86_64`. Each
package is the installed engine prefix: the six module libraries, the
public headers under `include/`, the CMake package config, and the
pinned HiGHS bundled under `highs/` (built static). Use it to build
your own bindings or tools:

```cmake
cmake_minimum_required(VERSION 3.16)
project(my_tool CXX)
find_package(tauargus-engine REQUIRED)  # via CMAKE_PREFIX_PATH
add_executable(my_tool main.cpp)
target_link_libraries(my_tool PRIVATE tauargus::core tauargus::csp)
```

The imported targets are `tauargus::core`, `tauargus::csp`,
`tauargus::hitas`, `tauargus::crp`, `tauargus::rounder` and
`tauargus::ghm`; each carries its link dependencies, including HiGHS.

## Building

See [Building from source](../README.md#building-from-source) at the
repository root. The HiGHS version is pinned in `HiGHS-VERSION`.
