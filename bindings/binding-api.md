# Engine bindings: conventions and guide

Canonical reference for how the engine is bound to programming
languages: what the engine exposes, the conventions every binding
follows, and how to add a binding for a new language.

Per-language API references:

| Language | Binding | Reference |
|---|---|---|
| Python | `_tauargus` (pybind11 extension) | [python/python-api.md](python/python-api.md) |
| R | `tauargusengine` package | [r/r-api.md](r/r-api.md) |

## What the engine exposes

Six native modules (see `engine/README.md` for the module map):

- `core`: data model, Argus/JJ file I/O, SDC entry points
- `csp`: cell-suppression LP (branch-and-price) and the feasibility
  audit (the legacy `intervalle` port)
- `hitas`: hierarchical table suppression (links `csp`)
- `crp`: controlled rounding
- `ghm`: hypercube (GH) secondary suppression, the C port of the
  legacy `GHMITER`
- `rounder`: dispatch layer over `crp`

The language surface is three C++ control classes plus module-level
audit and build metadata:

| Surface | Header | Role |
|---|---|---|
| `TauArgus` | `engine/native/core/src/TauArgus.h` | core: input files, variables, code lists, tables, safety rules, computation, cell access, secondary suppression, writing |
| `HiTaSCtrl` | `engine/native/hitas/src/HiTaSCtrl.h` | optimal (`FullJJ`) and modular (`AHiTaS`) suppression, HiGHS MIP |
| `RounderCtrl` | `engine/native/rounder/src/RounderCtrl.h` | controlled rounding (CRP) |
| `audit_jj` | `engine/native/csp/` | in-process feasibility audit over a `.JJ` file (the legacy `intervalle` executable) |
| build metadata | generated at build time | engine revision, each native submodule pin, HiGHS version |

The C++ headers are the source of truth for method names, argument
lists and return types. A binding mirrors the header one-to-one; when
a binding and a header disagree, the header wins and the binding is a
bug.

## Conventions

### Return conventions

- Success flag: a boolean in the target language (`bool`,
  `logical(1)`).
- Multiple values: one value per field, in a fixed field order that
  is identical across methods with the same shape (positional tuple
  in Python, named list in R).
- Status code: an integer. `0` means success unless the method is
  documented to return a code instead of a flag (for example
  `set_secondary_jjformat` returns `1` on success; `set_cta_values`
  and `set_cell_key_values_freq` report a code).
- Version and error strings: a string.

### Error codes

Native calls report failures as integer codes. Each control object
translates the codes of its own library:

| Translator | Catalog | Ranges |
|---|---|---|
| `TauArgus.error_string` | core `ErrorCodes` (`native/core/src/defines.h`), embedded in `native/core/src/TauArgusErrorStrings.h` | 1000-1027, 1500-1507, 2000-2006, 3000-3003, 4000-4008, 4200-4202, 4225-4232 |
| `HiTaSCtrl.error_string` | HiTaS catalog (`native/hitas/ErrorStrings.txt`), including the JJ-routine and solver codes | 5000-5012, 6000-6016, 7000-7003, 8000-8001 |
| `RounderCtrl.error_string` | CRP `ErrorTypes` (`native/crp/src/WrapCRP.h`) | 7100-7110 |

- A code missing from a catalog returns `"UnKnown Error (N)"` in all
  three libraries.
- The core catalog is embedded because the legacy
  `TauArgus.properties` (loaded from the working directory) does not
  survive the headless port; a `TauArgus.properties` in the working
  directory still overrides the embedded table.
- The core messages are reconstructed from the `ErrorCodes` enum names
  and their use; the original properties file does not survive in git
  history.
- The 8000-8001 codes (XPress, CPLEX license) are legacy; the engine
  uses HiGHS and never reports them.

### Error containment

The legacy port throws raw integer error codes from its file
operations (for example `OpenFile` in the HiTaS file I/O). A raw
integer crossing a language boundary is undefined behaviour in some
bindings (pybind11 only translates `std::exception`), so every
binding catches those integers at the boundary and either returns
them as the status code or signals a language error carrying the code
and its `error_string` translation. A caller never sees a raw integer
throw.

### Solver return semantics

- `FullJJ` returns `0` (optimal) or `1` (sub-optimal); anything above
  `1` is a HiTaS error code.
- `AHiTaS` returns `0` on success; anything else is a HiTaS error
  code.

How each language surfaces a failure code (returned status code
versus raised error) is documented in the per-language references.

### Input guards

The native core assumes well-formed input: indices and counts are
non-negative whole numbers, and the doubles it compares or stores are
finite. A negative index or a NaN/Inf can turn into out-of-bounds
access or a solver abort. Every binding validates such arguments
before the native call and rejects them with the language's value
error, naming the argument (Python: `ValueError`; R: an error). See
the per-language references for the guarded argument classes.

### Long-running calls

The solver-backed calls (`compute_tables`, the HiTaS solves,
`do_round`, the `audit_jj` audit) are blocking and can take a long
time on large or high-dimensional tables. A binding documents which
calls are long-running and, where the language allows it, yields
during them (Python releases the GIL).

### Process model

Run one job per process and per working/output directory. The native
solver keeps process-global state, and concurrent engine calls in one
process are not validated.

### Build metadata

Expose build provenance at module level: the engine commit, the
recorded pin of each native submodule and the pinned HiGHS version,
baked in at build time. Both existing bindings do this
(`engine_meta()` in Python, `tauargus_engine_meta()` in R).

### Known default differences

Positions and types match across the Python and R bindings; the
defaults in the table differ. Callers that rely on a default should
check the side they use (each per-language reference shows its own
defaults).

| Method | Arg | Python default | R default |
|---|---|---|---|
| `set_table` | cost | required | -1 |
| `set_table` | cellkey | required | -1 |
| `set_table` | ckm_topk | 0 | -1 |
| `set_table` | max_scaled_cost | 0.0 | 20000 |
| `get_table_cell` | topn | 0 | required |
| `write_jj_format` | lower | required | 0 |
| `write_jj_format` | upper | required | 1000 |
| `write_cell_records` | sbs | required | 1 |
| `write_cell_records` | embed_quotes | True | FALSE |
| `write_cell_records` | resp_type | 1 | 0 |
| `write_csv` | embed_quotes | True | FALSE |
| `write_csv` | resp_type | 1 | 0 |

## Adding a binding for a new language

1. Read the three headers (`TauArgus.h`, `HiTaSCtrl.h`,
   `RounderCtrl.h`) and the module-level audit entry point. They are
   the API.
2. Wrap the three classes and the module-level functions, following
   the conventions above. Keep the mapping one-to-one: one language
   export per C++ method, the object as the first argument.
3. Catch the raw integer throws at the file-operation boundaries and
   convert them per the error-containment convention.
4. Add input guards for index/count and double arguments.
5. Generate the build-metadata header at CMake configure time, the
   way `python/cpp/py_meta.h.in` and
   `r/tauargusengine/src/rta_meta.h` do it.
6. Link the six native libraries from `engine/build/lib/` and the
   HiGHS at the version pinned in `engine/HiGHS-VERSION`.
7. Add a smoke test that mirrors the existing ones: create each
   object, call `version` and `error_string`, run `compute_tables`
   plus a secondary suppression and `audit_jj` on a fixture from
   `data/`, and check the input guards.
8. Add the binding to the table at the top of this file.

The Python and R bindings are the reference implementations, and
their source is the starting point for a new binding: `python/cpp/`
(`bind_core.cpp`, `bind_csp.cpp`, `bind_hitas.cpp`,
`bind_rounder.cpp`, `module.cpp`, `input_guards.h`) and
`r/tauargusengine/src/` (`rta_engine.cpp`, `rta_csp.cpp`,
`rta_hitas.cpp`, `rta_rounder.cpp`, `rta_meta.h`, `rta_cpp.h`).
