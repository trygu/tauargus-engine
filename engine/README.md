# Engine

The C/C++ SDC engine. `CMakeLists.txt` is a superbuild of the five git
submodules under `native/`; the build produces the five engine libraries
in `build/lib/`.

## Modules

| Module | Role | Links |
| --- | --- | --- |
| `native/core` | Data model, Argus/JJ file I/O, engine entry points | none (static lib) |
| `native/csp` | Cell-suppression LP (branch-and-price) and feasibility audit | HiGHS |
| `native/hitas` | Hierarchical table suppression (HiTaS) | `csp` |
| `native/crp` | Controlled rounding (iterative rounding, MIP audit) | HiGHS |
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

## Building

See [Building from source](../README.md#building-from-source) at the
repository root. The HiGHS version is pinned in `HiGHS-VERSION`.
