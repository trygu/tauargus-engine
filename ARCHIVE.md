# Tau-Argus Rewrite: Archive

## Protection-to-publication regression (2026-10-12)

- Added four isolated pipeline tests: OPT/MOD on ex1 tabular input and an
  adapted GaussSuppression magnitude/dominance microdata example.
- ex1 verifies the known recoverable pre-suppression value, 20% required
  margins and realised protection on both sides. Dominance verifies the
  externally documented primary cells and their native protection levels.
- Both cases audit withheld cells and round-trip a minimal masked release
  CSV. No fixed secondary pattern or Gauss-method equivalence is asserted.
- Mutation checks reject bypassed suppression and unmasked publication.
- Linux x86_64, source-built HiGHS 1.15.1 and pinned native submodules:
  native core 1 passed; Python suite 268 passed, 3 skipped; wheel build passed.


Historical/completed state, extracted from `PROGRESS.md` on 2026-10-06
(repo meta-cleanup). See `PROGRESS.md` for current state.

## Java workflow review and TUI architecture (2026-10-12)

- Reviewed original sdcTools/tauargus Java revision `20d2b606`: main menus,
  table view/indexing and actions, details/summary, method parameters,
  protection/undo, outputs/report, apriori, recoding, specification and linked
  workflows. Source inspection, not a Swing execution or exhaustive parity audit.
- Compared with mainline `cad4abb` and the 4.1 manual. Confirmed stale design
  branch/release claims, missing full-dimensional grid coordinates, preview
  replay of original protection/output commands, and recipe recomputation on
  reopen without exact accepted-artifact restore or dependency fingerprints.
- Updated design status/packaging and documented module ownership, state gaps,
  prioritised capability matrix, evidence links and incremental acceptance gates.
  Keep the table-first layout; inspection and result/output integrity precede
  optional authoring or specialist methods. No application code changed.
- User guide distinguishes current diagnostic export/reopen limits from plans;
  AGENTS now directs TUI work to both design and shipped-behaviour documents.
- Verification: 17 pinned Java links match the inspected revision, source
  paths and line bounds; local document/image links resolve in Git; PROGRESS
  remains under 35 lines and `git diff --check` passes. Runtime tests were not
  run for this documentation-only change; no screenshots or native state changed.
- Release-pipeline checkpoint moved from PROGRESS: TUI smoke tests install the
  engine wheel from the same run (`build-tui` needs `build-linux`); compatibility
  floors need not rely on a previously published engine wheel.

Branch: `rewrite`

## Consolidated DataFrame branch (2026-10-10)
- Merged master (`c0b6e48`, PR #3) into `feature/dataframe-protect`, which
  already contains PR #4 and the native capacity query (`5f913c95`).
- Both fixes, regression suites and documentation changes now share the
  active feature branch. Only PROGRESS needed conflict resolution.
- Combined full Python suite against release native libs: 218 passed,
  3 optional skips. No additional branch created.

## DataFrame API checkpoint (2026-10-10)
- `protect(df|dict, tables, response, ...)` writes microdata/metadata/batch and
  reads type-5 `SO+` output into `TableResult`; `run=False` writes inputs only.
- `Variable.is_numeric` excludes categorical variables to avoid native
  `ConvertNumeric` errors (`ISNOTNUMERIC`, 1018) on categorical codes.
- Initial branch verification reported 213 passed, 3 skipped. Its subprocess
  test accepted JSON even on a crash and retried signal failures; subsequent
  macOS CI exposed an abort, so that result did not establish memory safety.

## DataFrame native abort diagnosis and fix (2026-10-10)
- CI run 38071022820, macOS job 114268275994 failed in the full `protect()`
  subprocess with SIGABRT. The same input reproduced a SIGSEGV locally,
  sometimes after output, during Python GC.
- ASan identified an 8-byte write just after a 520-byte allocation in
  `TauArgus::GetTableCell`, called by `bind_core.cpp`: the default request
  allocated 1 + 64 scores, but `P(25,1000)` configured 1000 native scores.
- Core adds `GetTableCellBufferSizes`; binding allocates cell, weighted and
  holding buffers from the effective table counts before trimming to `topn`.
  Validate dimension count before passing its index buffer to native code.
- Removed retries and JSON-only success from the regression. Child failures
  always fail the test, with faulthandler enabled and a bounded timeout.
- Fixed separate fresh-import recursion in `from pytauargus import protect`.
- Before fix: plain/weighted/holding regressions fail under ASan. After fix:
  11 protect tests pass under ASan; original input passes 60 fresh processes
  under ASan and 60 with release libs; full suite: 216 passed, 3 optional skips.
- GitHub CI run 38072531248 passes macOS 15, Ubuntu x86_64 and Ubuntu ARM64.
  Fix submitted as tauargus-engine PR #4 to `feature/dataframe-protect`;
  core capacity-query addition is libtauargus PR #1 (pin `5f913c95`).
- Both PRs merged: native #1 into `rewrite` (`b75aabe2`), engine #4 into
  `feature/dataframe-protect` (`746bc115`). Temporary fix branches removed;
  subsequent fixes use the active feature branch directly.

## Original goals
1. Port to the open source solver and make it cloud native and portable
2. Clean up the code
3. Port the Swing/Java UI to Python with a CLI-based UI
4. Remove all traces of Java

## Architecture (as-is, at analysis time)
- **Native C++ engine** in 5 git submodules under `native/`:
  - `native/core` — data model, Argus/JJ file I/O, table compute engine (`TauArgus` class). Static lib `tauargus_core`.
  - `native/csp` — cell suppression (branch-and-price LP), LP backend **HiGHS** (`src/Jjsolver.c`). Shared lib `tauargus_csp`.
  - `native/crp` — controlled rounding (CP/S/XP/XM main programs).
  - `native/hitas` — hierarchical/iterative suppression (`AHiTaS` + `FullJJ`). Links `tauargus_csp`.
  - `native/rounder` — rounder driver (calls CRP `DoRound`).
- **Java frontend** in `src/tauargus/` (90 files, ~38k LOC): `model/` (batch.java 1358 lines, OptiSuppress 1776 lines, Application, Metadata, SaveTable), `gui/` (Swing), `service/TableService.java` (integration seam via SWIG/JNI), `extern/dataengine/` (SWIG-generated).
- Solver selection (Java `Application.java`): SOLVER_XPRESS=1, CPLEX=2, SOPLEX=3 ("SCIP"); batch `<SOLVER>` tag picks it.
- SWIG interface `native/core/src/TauArgusJava.swg` — replaced by pybind11.
- Core public API: `native/core/src/TauArgus.h` — ~172 methods.

## Environment (macOS/Apple Silicon)
cmake 4.4.2, AppleClang 21, python3 3.14.7 (/opt/homebrew), HiGHS 1.15.1 via brew.

## Verified builds (all done)
- [x] `native/core` → `libtauargus_core.a` on macOS (warnings only).
- [x] `native/csp` → `libtauargus_csp.dylib` with HiGHS. Exports `SCIPv::CSP*` + globals.
- [x] `native/hitas` → `libtauargus_hitas.dylib`, links csp + HiGHS.
- [x] `native/crp` → HiGHS MIP backend (rewritten from SCIP). `libCRP.dylib` links `libhighs.1.dylib`; numeric MIP test passes.
- [x] `native/rounder` → `libtauargus_rounder.dylib`, links CRP. Removed stale duplicated `src/WrapCRP.h`.
- [x] Top-level `native/CMakeLists.txt` superbuild — all 5 modules, libs in `native/build/lib/`.

## hitas porting notes (done)
- Removed `cplex.h`/`xprs.h`/SCIP includes from `HiTaSCtrl.cpp`; `CloseSolver` no-op; `CheckStart` logs "using HiGHS".
- `WrapCSP.{h,cpp}`: single `SCIPv::` CSP API only.
- `HITAS_EXPORT` macro replaces `__declspec(dllexport)`.
- macOS fixes: removed `<malloc.h>`, `<vector.h>`→`<vector>`, added `<cassert>`.
- SWIG wrapper `HiTaSCtrl_wrap.*` excluded.

## crp porting notes (done, HiGHS-backed)
- HiGHS C API header: `<highs/interfaces/highs_c_api.h>` (NOT `highs/highs_c_api.h`).
- `crpSmain.c` (MIP): `Highs_passMip` (CSR + integrality) → `Highs_run` → `Highs_getModelStatus` → `Highs_getSolution`.
- `crpSaudit.c` (audit LP): `Highs_passLp` + `Highs_changeColCost`/`Highs_changeColBounds` per iteration; `col_dual` gives reduced costs directly.
- Both files compiled as **C++** (C++ internal linkage for header `const`s; K&R defs converted to ANSI).
- `Highs_clear()` resets ALL options — re-apply `output_flag=0` + `log_to_console=0` after every clear.
- No `Highs_inf` in C API; `#define CRP_HIGHS_INF 1.0e20`.
- CMake: `find_package(Highs REQUIRED)` + `highs::highs`; kept `SCIPV` define for churn minimization.
- Verified: all `S_CRP*` entry points export; 2-cell MIP (total-25) solved correctly.

## Python port — completed state
Headless Python CLI path is **end-to-end functional** for the microdata flow.
`data/TestRecode.arb` runs to completion; **47 tests green**.
- **pybind11 module** (`python/cpp/bind_{core,hitas,rounder}.cpp`): ~54 `TauArgus` methods + `HiTaSCtrl` + `RounderCtrl`. Wheel via `uv build --wheel` (self-contained, `@loader_path` rpath). Smoke: `TauArgus().version()` → `1.1.4.11`.
- **`batch.py`** — legacy-compatible `.arb` parser (18 command dataclasses, tokenizer, status machine).
- **`engine.py`** — `parse_rda`/`parse_rda_table` mirror `Metadata.read*Metadata`; `Engine.run_batch` drives the native engine end-to-end (clean → set info → vars → explore → tables → compute → recodes).
- Native-call fidelity fixes: kwargs `is_numeric`/`is_hierarchical`; `set_hierarchical_digits` trims trailing-zero levels; `set_table` `max_scaled_cost >= 1`, shadow var defaults to response var; `set_table_safety` holding thresholds match `TableSet.readSafetyRule`; Recode: 3 paths (digit truncation, `<TREERECODE>` file via `get_var_code` lookup, classic `DoRecode`).

## Key files (reference)
- `native/core/src/TauArgus.h` — full API surface (~172 methods)
- `src/tauargus/service/TableService.java` — how native is driven
- `src/tauargus/model/batch.java` — .arb grammar
- `src/tauargus/model/OptiSuppress.java` — suppression/rounding orchestration
- `src/tauargus/model/Application.java` — solver constants, Windows registry (to replace)
- `native/csp/src/Jjsolver.c` — HiGHS LP shim
- `native/crp/src/crpSmain.c` / `crpSaudit.c` — HiGHS MIP/LP

## Notes / decisions
- "Open source solver" = HiGHS for csp (LP) and crp (MIP); SCIP dropped.
- Windows registry (WinRegistry.java, SystemUtils.getReg*) → config file / env vars.
- Temp dir conventions → `tempfile` module + explicit work-dir option in CLI.
- Progress listeners → Python callbacks / logging.
- Do NOT port Swing dialogs one-by-one; CLI + headless batch is the product.

## Completed task sub-items (Tasks 1, 2 partial)
Task 1 (open source solver + portable): core/csp/hitas/crp/rounder build-verified with HiGHS; rounder CMakeLists; superbuild.
Task 2 (pybind11): module built & linked; ~54 methods bound; verified with smoke tests.
Task 3 (model/service layer): batch.py, engine.py (metadata parse + orchestration) done; suppress.py/apriori/recode/save pending.

## Suppress/round smoke tests (done 2026-10-06)
`python/tests/test_suppress.py` rewritten to assert the engine's *observable*
invariants (the old assertions were wrong):
- MOD (AHiTaS) / OPT (FullJJ) leave the target unsafe cell's status (3)
  unchanged but mark neighbouring safe cells secondary (status 11/12) →
  assert "secondary count increases".
- RND (CRP/HiGHS) stores values via `SetRoundedResponse`; `get_table_cell_value`
  returns the original response (not the rounded one), so a "multiple of base"
  check on that getter is invalid. Assert: do_round succeeds, values stay
  non-negative, and a base below `_min_round_base` raises BatchError.
- Per-cell LPL/UPL (`GetTableCellProtectionLevels`) return sentinel values
  (e.g. 0.01) for safe cells → not usable as a range check.
- Each test uses a fresh `Engine` (function-scoped fixture in the test file):
  running a second suppression on an already-modified table crashes the native
  engine.

## OPEN BUG (native/csp, HiGHS teardown segfault)
Non-deterministic (~40%) segfault in `Highs_destroy` (HiGHS `HighsOptions`
destructor) reached from `JJfreeprob` → `unload_lp` during/after `AHiTaS` in
`native/csp` (Cspmain.c `PPCSPoptimize`, `cspsolve.c` global `JJLPptr lp`).
Symptom: full `uv run pytest` intermittently dies RC 133/139 after a suppress
test; single suppress tests pass in isolation. Needs a native `native/csp`
fix (LP lifecycle: `load_lp` in read_prob / `unload_lp` paths) — see PROGRESS.md
"Current". Not a Python/test issue.

## Completed detailed checkpoints (2026-10-09)
- WRITETABLE type-5 (INTERMEDIATE) audit file ported (`Engine.write_intermediate_table`),
  `get_table_cell` pybind binding, `+SO`/`+HI`/`+SE`, CLI `save --format intermediate`.
  `+AR` realized-interval columns deferred (needs external `intervalle.exe`).
  Legacy batch number = `safeFileFormat+1` → intermediate is **5** (4=SBS),
  matching 0-based Java constant `FILE_FORMAT_INTERMEDIATE=4`.
- Tabular (pre-aggregated) table flow: `data/tableinput/TestTable.arb` runs
  headless; `engine.read_table` = 3-phase port of Java `TableSet.read`
  (SetInCodeList → SetTotalsInCodeList → SetTable/SafetyInfo → buildCell/
  SetInTable → CompletedTable). 7 tests in `test_table_smoke.py`.
  Note: `pp.tab` subtotals internally inconsistent; `1T` recomputes from
  leaves, so total cells can differ ~1.0 from the file.
- Apriori ported (`Engine.apply_apriori`, `_bogus_range`, `_apply_apriori_change`),
  port of `APriori.processAprioryFile`. Headerless file `<c1>;<c2>;<TYPE>
  [;v1 [;v2]]`; first line validated AND applied. Types S/U/P/M/ML (status),
  C/W (cost), PL (prot-level, unsafe cells 3..9 only); AB unimplemented.
  `--expand-bogus` = single-child chain. CLI verb `apriori`. 9 tests in
  `test_apriori.py`. Native quirk: `SetTableCellCost` returns True but
  `GetTableCell` cost field is a different store (legacy read cost from the
  Java-side cell cache). `GetVarCodeProperties` returns ok=False for all
  non-hierarchical codes → apriori builds its code index from `GetVarCode`.
- **Task 3 `cover`**: `Engine._protect_cover_table` + `for_cover_table`; 4 tests.
- **Intervalle (audit) source** pinned as submodule `reference/intervalle`
  (`430b67b`) — the Pascal/FPC reference the native audit port mirrors.

## Submodule + README cleanup (2026-10-09)
Legacy cruft removed from all five `native/` submodules and the top-level
README rewritten for the rewrite. Per repo (submodule commit first, then
parent pointer bump):
- **core** `894f4c0`: dropped `Help/` (66 HTML), `nbproject/`, `NBMakefile`/
  `MakefileRobert`/`MakefileAction`/`Makefile`, `.github/` (stale Java-DLL CI),
  and the COM/VB6/SWIG sources in `src/` (GhmiterANCO, TauArgCtrl, StdAfx,
  NewTauArgus, TauArgusJava_wrap, `.dsp`/`.dsw`/`.idl`/`.rc`, images). 112 files.
- **csp** `e3a2b84`: dropped `nbproject/`, old Makefiles, dead `CSPLOAD.H`.
- **hitas** `25d935a`: dropped `nbproject/`, old Makefiles, SWIG `hitasctrl.swg`,
  generated `dist/` Java stubs, `.dep.inc`, dead `APCSPglobs.h`/`pcspmain.h`
  + untracked CPLEX/XPRESS solver headers.
- **crp** `571b3f5`: dropped CPLEX/XPRESS solver variants (`crpC*`/`crpX*`),
  `XXRounder/` + its CMake option, `nbproject/`, `Makefile`, `crp.pc.in`,
  stale `build.yml` (referenced removed `-DUSE_SCIP`), 6-line `WrapCRP.h` stub.
- **rounder** `1981385`: dropped `nbproject/`, `Makefile`, `RounderCtrl.swg`,
  `.dep.inc`.
Top-level `README.md` rewritten: native-rewrite overview, module table, HiGHS
build + `uv` CLI usage, tests. (Parent-root legacy files — `Makefile`,
`build.xml`, `nbproject/`, old manual PDFs, runtime logs — left for Task 8.)

(The older "OPEN BUG: HiGHS teardown segfault" note above is RESOLVED — see
the CSP/HiGHS teardown checkpoint in PROGRESS.md / `docs/native-debugging.md`.)

## pytauargus rename + engine//bindings/ restructure (2026-10-09)
- **`pytauargus` rename** (commit `7a6ff3d`): Python package `tauargus`→`pytauargus`
  (CLI command stays `tauargus`). Project identity = `tauargus-engine`. Only the
  Python layer renamed — C libraries keep `tauargus` names (`libtauargus_*`,
  `_tauargus` ext, `TauArgus`/`HiTaSCtrl`/`RounderCtrl` classes, `tauargus_native`).
  Wheel made self-contained via CMake `install()` (ext + csp/hitas/rounder dylibs).
- **Directory restructure**: `native/`→`engine/native/` (submodules, SHAs preserved
  via `.git/modules/` intact), superbuild moved to `engine/CMakeLists.txt`
  (`add_subdirectory(native/...)`), `python/`→`bindings/python/`. Updated `.gitmodules`
  paths, `bindings/python/CMakeLists.txt` `NATIVE_*`, test `DATA` paths (4 parents),
  `.gitignore`, `AGENTS.md`, `README.md` (layout tree).
- **Consolidation rejected**: a single `libtauargus_engine` is blocked by the
  **two global-namespace `IProgressListener` classes** (`core`: `UpdateProgress`;
  `hitas`: 7 methods). Both `TauArgus.h` and `HiTaSCtrl.h` include it; the per-module
  include-path trick (csp takes hitas's via PRIVATE include) is what makes separate
  libs work. Keeping 5 separate libs + per-binding TU isolation (current model).
- **CRP wheel fix**: `libtauargus_rounder.dylib` links `@rpath/libCRP.dylib`, but the
  wheel previously bundled only csp/hitas/rounder → `tauargus round` would dyld-fail
  from an installed wheel. Now `libCRP.dylib` is copied (POST_BUILD) + `install(FILES)`.
  Verified: isolated venv `tauargus round ... --tab 1` runs CRP/HiGHS, exit 0.
- Gate: superbuild rebuilds clean at `engine/`; 99/99 tests green; self-contained
  wheel (`_tauargus` + csp/hitas/rounder/CRP dylibs) verified in isolated venv.

## Self-contained wheels + cross-platform CI (2026-10-09)
- **Problem:** the engine dylibs linked HiGHS at its absolute install path
  (`/opt/homebrew/opt/highs/lib/libhighs.1.dylib` on macOS), so a wheel only
  worked where HiGHS happened to live there.
- **Fix (macOS, verified):** `delocate-wheel` (console script, not `-m`)
  bundles HiGHS into `pytauargus/.dylibs/` and rewrites refs to
  `@loader_path/.dylibs/...`. Verified: repaired wheel installed in an
  isolated venv runs `tauargus round` (exit 0, HiGHS bundled).
- **Platform-aware binding CMake** (`bindings/python/CMakeLists.txt`): resolves
  engine lib names per OS (`.dylib`/`.a` macOS, `.so`/`.a` Linux, `.lib`+`.dll`
  Windows) and sets the right BUILD/INSTALL rpath. Previously hardcoded
  `.dylib` — macOS-only.
- **`wheels.yml`** (GitHub Actions, manual matrix — not cibuildwheel, which
  can't see the sibling `engine/` the Python CMake links against):
  - jobs: macos-14/arm64 + macos-13/x86_64, manylinux2014 (container), windows-2022;
    CPython 3.10–3.13.
  - each: HiGHS from source (`HIGHS_TAG`, cached) → engine superbuild (cached) →
    `pip wheel bindings/python --no-deps` → repair (delocate/auditwheel/delvewheel)
    → upload artifact.
  - release job (on `v*` tag): download artifacts → **GitHub Release assets**
    (softprops/action-gh-release) → optional PyPI publish (`vars.PYPI_ENABLED`).
- **Known gaps (need a real CI run):** Linux auditwheel `--exclude` for libstdc++
  and the manylinux CPython path; Windows delvewheel HiGHS DLL discovery. The
  macOS leg is fully proven locally.

## Submodule + root cleanup (2026-10-09)
- **`reference/intervalle` submodule dropped** (`6115cbd`): the audit is fully
  ported natively (`TauAuditJj` in `engine/native/csp`), so the Pascal reference
  is no longer needed in-tree. The upstream repo (sdcTools/intervalle) stays
  available for cross-checks.
- **Legacy Java-era root files removed**: `BUILDINFO.TXT`, `Error.txt`,
  `ErrorStrings.txt`, `MAKEINFO`, `Makefile`, `TauArgus.properties`,
  `TauManualV4.0.pdf` / `TauManualV4.1.pdf` (superseded by
  `docs/tau-argus-4.1-markdown-bundle/`), `TauNews.html`, `_TauChanges.txt`,
  `build.xml`, `manifest.mf`, `tau-Argus_CTA_help.pdf`, `tauARGUS.css`, and
  the whole `nbproject/` NetBeans tree. Untracked runtime output
  (`.DS_Store`, `CSPlogfile.txt`, `HiTaS.log`, `Highs.log`, `JJUit.dat`,
  `cspSCIP.*`, `hierinfo.dat`, `sdc.lp`) deleted from disk.
- `.gitattributes` slimmed (dropped `*.java`/`*.form`/`*.properties` rules;
  added `*.pdf` binary). Root now contains only: docs, `engine/`,
  `bindings/`, `data/`, `src/` (Java, kept for Task 8), and top-level
  project files.

## README rewrite (2026-10-10)
README rewritten: no Greek letters; top-level project is `tauargus-engine`
(C/C++ libraries under `engine/`), `pytauargus` is the Python package/CLI using them.

## `.arb` + `.rda` writer ports (2026-10-10)
Generator-side file writers ported from `references/rtauargus`, so the Python
package can emit the exact `.arb`/`.rda`/`.hrc` batch inputs our own engine
parser consumes (fixture generator + round-trip validator).

- `pytauargus/util.py` — `cite`, `norm_path` (R `normalizePath(mustWork=FALSE)`
  semantics: returns path unchanged when it doesn't resolve, absolute when it
  does), `df_param_defaut`, `following_dup`, `output_extensions`.
- `pytauargus/arb.py` — `micro_arb`, `specif_safety`, `suppr_writetable`,
  `apriori_batch`, `norm_apriori_params` (port of `R/micro_arb.R`).
- `pytauargus/rda.py` — `write_rda_1var`, `write_rda`, `rda_text` (port of
  `R/micro_asc_rda.R::write_rda*`; the `.rda` text writer only).

Tests: `tests/test_arb.py`, `tests/test_rda.py`, `tests/test_util.py` — direct
translations of `test_micro_arb.R`, `test_micro_asc_rda.R` (write_rda block),
`test_util.R`. All expected values captured by running the pure-R source in
base R. **174 tests green.**

Port notes / gotchas:
- macOS: `datetime.now().strftime("%Z")` is empty (libiconv quirk); use
  `datetime.now().astimezone().strftime(...)` to match R's `Sys.time()` zone.
- `specif_safety`/`write_rda` build each table's block as one string with
  embedded `\n`; the *file* is written with a real `writeLines`/join so
  `<SUPPRESS>`/`<WRITETABLE>` land on separate file lines.

Gaps (intentionally NOT ported): the `micro_asc_rda()` orchestrator that also
emits the fixed-width `.asc` via `gdata::write.fwf` and computes
position/width/digits from microdata — a separate `.asc` generator, not part of
the `.rda` writer. No `.tab`/`.hst` generator, no native `.hrc` getter
(matches the rtauargus gap list).

## Example notebooks + micro.py rda fix (2026-10-10)

- `bindings/python/notebooks/` — three executed notebooks doubling as API
  docs: `01_quickstart` (import, data locator, parse_rda/Metadata, run_batch,
  table+cell inspection), `02_protection_and_audit` (safety rules ->
  OPT/MOD/RND -> status distribution -> audit() realized intervals),
  `03_generators` (micro_arb, write_rda/rda_text, write_hrc,
  generator->run_batch round-trip). Built by `notebooks/_build.py`, executed
  + output-saved by `notebooks/_run.py` (nbclient, no Jupyter needed).
- `notebooks` optional extra (jupyterlab/nbclient/nbformat/ipykernel);
  optional `tests/test_notebooks.py` (importorskip nbclient) so the release
  `uv run pytest` gate stays fast/dependency-free. Outputs -> gitignored
  `notebooks/out/`.
- Safe defaults only: OPT/MOD max_time=0; RND rnd_base from the engine; no
  GH/NET/CTA (external executables).
- `micro.py::write_rda_1var` bug: emitted the header glued to the first body
  line (missing the newline before it). R uses `paste(sep="\n", ligne1,
  body...)`. Fixed to join header + body with a single `\n`. (`rda.py`'s
  separate `write_rda_1var` was already correct.)
- `tests/test_micro.py` (untracked, in-flight .asc writer port) fixed its
  R-contract port: R `strsplit("\n  +")` is a regex (newline + 2+ spaces)
  applied per block vector then unlist-ed, not a literal `str.split` on the
  joined string. Now splits each block with `re` and flattens.
- After fixes: 177 passed, 1 skipped (the notebook test without nbclient).

## Positive solver time limits + audit documentation (2026-10-10)

- The previous claim that every nonzero OPT/MOD `max_time` deterministically
  segfaults was not reproduced with the published 0.2.1 wheel on macOS arm64,
  CPython 3.13. Both methods completed with a one-minute limit on a small
  synthetic table and on `data/TestRecode.arb`, three fresh engines per method
  in the same process. Secondary suppression counts increased on every run.
- `tests/test_solver_time_limits.py` covers OPT and MOD with positive limits
  on TestRecode. Each test runs three fresh engines in a child process, so a
  native crash fails the test without killing pytest. It explicitly covers
  accepting a finite limit, not reaching the deadline or concurrent use.
- Replaced stale crash warnings in notebook 02/03 and their `_build.py`
  source with the units (minutes) and the meaning of `0` (no limit).
- Corrected the reversed audit explanation in both READMEs and notebook 02:
  protection requires sufficient uncertainty relative to the protection
  requirements; a narrow interval can disclose the value. The original value
  normally lies inside the feasibility interval. Documented the audit's
  `unsafe` flag as its insufficient-protection check and `value` as the original
  cell value withheld from the release table.
- Notebook edits affect Markdown only; code, execution counts and saved outputs
  are preserved. No native solver changes were needed for the tested workload.
- Verification: **179 passed, 1 skipped** (nbclient absent), using the current
  Python sources with the native artifacts from the published 0.2.1 wheel.

## DataFrame documentation and executable examples (2026-10-10)

- Refreshed all three notebooks and their `_build.py` source around the public
  `protect()` API: DataFrame quickstart, OPT/MOD and explicit audit, masked CSV,
  multiple tables and `run=False` preview. Kept the lower-level batch examples.
- Updated the root, Python binding and notebook READMEs. Documented retained
  files, optional pandas, result accessors and the distinction between original
  diagnostic values, protection levels, realized audit bounds and safe exports.
  Corrected source-build order and the stale claim that no writer produces ASC.
  Custom CSV examples now explicitly request output type 1.
- Added pandas to the notebook extra. The runner consistently uses the notebook
  directory, and selective regeneration preserves IDs of unchanged cells.
- Executing the README examples exposed duplicated paths for relative
  `workdir` values. Normalize the workdir to an absolute path before generating
  batch inputs/outputs; a strict native subprocess regression fails before the
  fix and passes afterward. All changes stay on `feature/dataframe-protect`.
- Verification: **219 passed, 2 skipped** in the non-notebook suite (optional
  polars checks); all three notebooks executed separately, **37 code cells**
  with saved outputs and no cell errors. Both README examples ran in fresh
  processes, notebook files validated, and all cell sources match `_build.py`.

## Reject unprepared cell-buffer capacity queries (2026-10-10)

- Confirmed the review finding: code-list exploration does not prepare tables.
  `GetTableCellBufferSizes` previously returned success for an unconfigured
  table, with capacities that could change during subsequent preparation.
- Core `ab37b03` rejects a null or unprepared effective table, including the
  recoded-table selection, before writing any output arguments. Documented
  that failure leaves those arguments unchanged.
- Added an opt-in native CTest regression. It failed before the guard, and now
  checks rejection before exploration, after exploration, after configuration
  and for invalid indices. Prepared original and recoded tables still succeed,
  including valid zero score capacities. The test uses explicit checks that
  remain active in release builds.
- Native regression passes in release and ASan builds. Rebuilt the Python
  extension against the updated core: **219 passed, 2 optional polars skips**.
  Enabled the native regression in the existing three-platform test workflow.

## Wrapper acknowledgements (2026-10-10)

- Added acknowledgements in the root and Python binding READMEs, with links
  to InseeFrLab/rtauargus and lverweijen/piargus (PiArgus).
- Credited rtauargus for the ported file-generation logic and protection flow;
  credited PiArgus for DataFrame/result API inspiration and TableResult accessors.

## PR #5 review corrections (2026-10-10)

- Added regressions before fixes for all six API findings and both notebook
  path findings. Also covered duplicate labels after string conversion and
  duplicate explanatory/response names, which could silently overwrite data.
- Preserve the result layout by rejecting reserved diagnostic names (`freq`,
  `cost`, `status`, `lower`, `upper`) before `protect()` writes files. Apply
  equivalent checks in the parser and row-based constructor. A frequency
  table can still use `freq` as its response because it has no extra freq field.
- Dict columns require equal lengths. Record input uses the first-seen union
  of keys, filling absent fields with None. Frame adapters read original labels
  while producing unique string keys, including integer/tuple pandas labels.
- Reject invalid per-table suppression lengths before file generation while
  retaining the single-spec table-number rewriting behavior. The DataFrame
  fallback returns defensive result rows, preserving later safe/status views.
- Display portable paths in generated batch previews and file-write messages;
  engine inputs retain actual paths. Rebuilt and executed all three notebooks
  (**37 code cells**, no errors); saved outputs contain no workstation paths.
- Verification: **255 Python tests passed, 2 optional polars skips**, plus
  **3 saved-notebook checks passed**. Both README examples execute in fresh
  processes, notebook files validate, and their sources match `_build.py`.

## Release 0.3.0 preparation (2026-10-10)

- PR #5 merged to master (`4457752`); mainline CI passed on all three runners.
- Bumped package and lock from 0.2.1 to 0.3.0 for the new DataFrame API.
  Updated wheel/container version guidance and removed unreleased API wording
  from the binding README, notebook README, generator, and quickstart notebook.
- `uv lock`, editable package build, and full `uv run --no-sync pytest` passed
  in the existing test environment, including all three executable notebooks.
  Native `cell_buffer_sizes` CTest passed; notebook sources match the generator.
- The first fresh-environment sync was stopped after stalled downloads; the
  existing environment was synced with test extras and rebuilt as 0.3.0.

## 2nd-OPT SIGABRT fix (2026-10-11, csp submodule 3007826)

- Symptom: `run_batch` + `suppress(OPT)` twice on the same table → SIGABRT in
  `remove_row` ← `PPCSPfreeprob` ← `FullJJ` catch (HiTaSCtrl.cpp:521). Reproduced
  deterministically with the plain PyPI 0.3.0 wheel (both TestRecode tables) and
  with a C++ ASan driver (`/tmp/fj_seq.cpp`: FullJJ normal-JJ then
  secondary-JJ in one process; `rows[k]` = 0xbebebe… stale pool read).
- Chain: `PPCSPfreeprob` never reset global counters, so after a successful run
  `nrows` etc. stayed stale. A 2nd OPT writes a JJ file with `m` (secondary)
  cells; `change_status` (Cspmain.c) has no `'m'` case → loadprob fails with
  HITAS_JJNOTLOADED (5008) *after* the `rows` realloc but *before* `nrows=0`
  → the catch's `CSPfreeprob` walks a garbage row pool → abort.
- Legacy check: the pre-port csp history and the original `HiTaSCtrl.cpp`
  (initial commit) contain the identical missing-`'m'` + unreset counters +
  same catch path, and legacy Java `RunOptimal` has no pre-check for existing
  secondary suppression (it calls native `WriteJJFormat` + `FullJJ` and throws
  on result > 1). So τ-ARGUS 4.1 had the same latent crash; the TUI's s-s
  workflow just triggers it directly.
- Fix (csp `3007826`): `PPCSPloadprob` resets all global problem counters at
  entry (failed load leaves a consistent empty problem → freeprob free loops
  are no-ops); `PPCSPfreeprob` resets the same counters on exit (idempotent).
  `change_status` documented: `'m'` intentionally rejected (legacy behavior) —
  re-running OPT on a table with existing secondary suppression returns 5008
  gracefully instead of crashing.
- Verification: ASan driver run1→1, run2→5008, clean exit, no ASan report;
  Python E2E (fixed dylib swapped into the 0.3.0 wheel package — note the
  wheel keeps a second csp copy in the hidden `.dylibs/` dir that hitas loads
  via `@loader_path/.dylibs/…`) → both tables: OPT#1 ok, OPT#2 raises
  `BatchError: FullJJ failed (code 5008)`, no crash.

## Error strings + core sync (2026-10-11, hitas d3e5b91)

- `GetErrorString` (HiTaSCtrl) looked up a global `StringTable` that was only
  ever populated by `LoadErrorStrings` from `ErrorStrings.txt` in the CWD —
  a call that was commented out in the port, so every error surfaced with an
  empty message (e.g. "FullJJ failed (code 5008): ").
- The txt file was never checked into any repo (shipped next to the legacy
  jar/exe). Found verbatim upstream:
  `raw.githubusercontent.com/sdcTools/tauargus/refs/heads/master/ErrorStrings.txt`
  (35 lines, `NAME = code = text`, codes match `resource.h` exactly).
- Fix: file restored to `engine/native/hitas/ErrorStrings.txt`; CMakeLists
  generates `ErrorStrings_generated.inc` at configure time (note: CMake's
  regex engine does not support `[[:space:]]` — use ` *`); `HiTaSCtrl.cpp`
  initializes the table from the embedded array; `LoadErrorStrings` kept as
  optional runtime override.
- Core submodule: worktree had drifted to `e7ecb98` (ancestor of the pin
  `ab37b03`), which broke `uv build --wheel` (bind_core.cpp needs
  `GetTableCellBufferSizes` from `5f913c9`/`ab37b03`). Restored the pin —
  plain fast-forward, nothing lost; wheel build now passes.
- Verification with the freshly built cp313 wheel in the TUI venv:
  `error_string(5008)` → "Couldn't load JJ-routines"; OPT×2 repro →
  `BatchError: FullJJ failed (code 5008): Couldn't load JJ-routines`, no crash.

## CI: push submodule commits before the parent (2026-10-11)

- Pushing a parent that pins not-yet-pushed submodule commits breaks every
  runner checkout with "fatal: remote error: upload-pack: not our ref
  <sha>" (happened for csp 3007826 / hitas d3e5b91 after the 2nd-OPT
  segfault fix).
- Cadence: commit in submodule -> **push submodule** -> bump + commit
  parent -> push parent.
- Side note: tests.yml uses `concurrency: cancel-in-progress`; a
  `gh run rerun` queued behind a newer run on the same branch cancels
  the in-flight one.

## Acknowledgements source review (2026-10-11)

- Separate `docs/acknowledgements` branch from mainline `211876d`.
- Checked the original Tau-Argus 4.1 manual and authorship/copyright
  headers in all five native modules, including CSP implementation credits.
- Verified all eight rtauargus authors and its four published email addresses
  in upstream DESCRIPTION; Julien Jamme is listed as maintainer (`cre`).
- PiArgus metadata publishes `lauwerund@gmail.com`; its author's public
  GitHub profile identifies `lverweijen` as Laurent Verweijen.
- HiGHS v1.15.1 AUTHORS lists Julian Hall, Ivet Galabova, Qi Huangfu,
  Leona Gottwald and Michael Feldmeier.
- Earlier completed checkpoints moved here to keep PROGRESS.md under 35 lines:
  the local-wheel sync script and removal of mainline references/Java
  (the Java frontend remains on `tui` as a porting reference).
- Updated root and Python README acknowledgements together, preserving
  the existing interface-inspiration credits and license sections. Source links
  pin the reviewed native commits, wrapper metadata and HiGHS release.
- Documentation checks passed: matching sections, resolved Markdown references,
  public contacts and header credits match upstream; `git diff --check` clean.
  Runtime tests were not needed for this documentation-only change.

## Acknowledgements presentation (2026-10-11)

- Removed the source column, citations and metadata references from both
  README acknowledgement sections; kept author credits and public contacts.
- User confirmed that the header names `pwof` and `Peter-Paul` refer to
  Peter-Paul de Wolf. All three native module credits now use his full name.
- Combined J. J. Salazar with Juan José Salazar González in the CSP credit.
- Verified matching README sections, retained contacts, unified names,
  no remaining source references, and unchanged content outside acknowledgements;
  `git diff --check` passed and PROGRESS.md remains under 35 lines.

## Acknowledgements framing (2026-10-11)

- Added the agreed opening about standing on the shoulders of earlier authors
  and the value of sharing methods and tools in official statistics.
- Confirmed CSP and CRP link to `highs::highs` and call its C API for solving.
  HiGHS now receives a short separate dependency acknowledgement; the native
  table focuses on the five inherited Tau-Argus modules.
- Verified matching README sections, five native credits, retained contacts,
  and unchanged content outside acknowledgements; `git diff --check` passed.

## Peter-Paul acknowledgement wording (2026-10-11)

- Removed the manual-derived `(Modular)` qualifier after Peter-Paul de Wolf
  in both READMEs. The user clarified his broader role as the main Tau-Argus
  author; the acknowledgement should not narrow his contribution to one method.

## Acknowledgements final presentation (2026-10-11)

- Kept one expression of gratitude in the opening; removed repeated thanks
  and the closing summary. Preserved the open-source framing, author names,
  project links and descriptions of the wrapper contributions.
- Removed email addresses from both README sections for a consistent credits
  presentation. The public contacts found during research are retained below
  as working notes; the first two come from historical manual/header records.

| Project / person | Published contact |
| --- | --- |
| Tau-Argus (historical project address) | argus@cbs.nl |
| CRP / Juan José Salazar González (historical header address) | jjsalaza@ull.es |
| rtauargus / Julien Jamme (package maintainer) | julien.jamme@insee.fr |
| rtauargus / Pierre-Yves Berrard | pierre-yves.berrard@insee.fr |
| rtauargus / Nathanaël Rastout | nathanael.rastout@insee.fr |
| rtauargus / Clara Baudry | clara.baudry@insee.fr |
| PiArgus / Laurent Verweijen | lauwerund@gmail.com |
- Verified identical sections, one expression of gratitude, all named
  contributors and project links retained, seven contacts archived, unchanged
  surrounding README content, and clean `git diff --check`.

## Release-independent installation guidance (2026-10-11)

- Verified that wheels.yml already publishes both the release version and
  `latest` for the Docker image; no workflow changes are needed.
- Both READMEs now explicitly use `:latest` with `--pull=always`, preventing
  a cached image from silently keeping the default example on an older release.
- Replaced the fixed Docker release example with a generic version placeholder
  and a Releases link. Added Python version-pinning guidance linked to PyPI;
  pip examples use `--upgrade` for installations that already have the package.
- Retained `>=0.3.0` as the DataFrame feature's historical minimum, rather than
  a moving current-release number. Fixed the stale root README statement that
  `protect()` was unreleased and aligned it with the binding README.
- Verified consistent Docker command arguments and version-pinning guidance,
  existing version/latest publication tags, unchanged acknowledgements, and
  clean `git diff --check`; PROGRESS.md remains under 35 lines.
## TUI state design agreed (2026-10-11)

- Traced Java cell-edit, suppression, undo and export handlers at `3c8e2ab`,
  with the legacy manual as the behaviour reference. Cell edits changed the
  working table immediately; solving was explicit, and protection locked most
  editing until suppression undo. This was source inspection, not a Java run.
- Replaced the old one-engine/no-persistence design with immediate draft
  commands, explicit isolated previews, acceptance and independent workspace
  saving/export. User instructions and solver-selected statuses stay separate.
- Specified stable cell identity, revisioned audit/cache ownership, serialized
  jobs, late-result rejection, failure preservation and exact accepted-result
  artifacts. Existing batch protection/output commands must be separated from
  preparation rather than blindly replayed/appended during previews.
- Corrected the claim that no native undo exists: suppression undo is present,
  but is not a general transaction/restore contract. Fresh scratch runs are the
  initial preview strategy; optimisation needs verified reset semantics.
- Updated `docs/ui-design.md` with implementation acceptance checks and the
  current `tui` branch status. These are design targets; no UI/engine behaviour
  was changed. Documentation structure/links and diff whitespace checked.

## TUI cell-instruction milestone (2026-10-11)

- First B.8 acceptance check implemented: multiple cell edits update the draft
  immediately without native mutation of the accepted run; one Preview batches
  the complete instruction set.
- Model: `CellInstruction` (stable identity = table + ordered code tuple + kind
  U/S/P) and `apriory_lines()` (legacy apriori row `<c1>;<c2>;...;<cmd>`).
  `Session.preview(ops, instructions=())` switched from a spec-text rewrite to a
  programmatic recipe: fresh `run_batch` (original spec) → per-table
  `apply_apriori` (`ignore_error=False`, so an edit invalidated by recoding is
  surfaced, not silently retargeted) → `suppress(op.suppress_cmd())` per op.
  Equivalent to the old batch-text rewrite (5008 carry-forward test still green).
- App: `u`/`p`/`shift+s` mark the cursor cell (toggle/replace, one instruction
  per cell); pending marker on the grid (kept distinct from the status colour) +
  detail pane; `_all_instructions()` merges confirmed + pending (latest intent
  wins per cell); accept promotes marks to confirmed; discard keeps the draft;
  the cursor is restored across marker re-renders.
- Total (marginal) cells are not markable this iteration: the grid shows the
  display label (`get_total_code()`, falling back to `"Total"`) while the
  apriori parser matches only the variable's real total code. Marking a total
  cell is a refinement that needs the real total code.
- textual 8.x: `Pilot.press("shift+s")` (no `shift=` kwarg); `move_cursor` is
  required to keep the cursor after a re-render (clear+re-add drops the
  highlight). `Pilot.press` waits for process-CPU idle, so the busy window is
  not observable around `press` (spinner covered by its own contract test).
- Verification: TUI suite 36/36 (was 25). TDD: tests written first, observed to
  fail for the right reason before implementing.

## TUI releases 0.3.2–0.3.4 + §B.7 workspace reopen (2026-10-12)

- 0.3.2: TUI shipped in lockstep with pytauargus (same `py-v*` trigger,
  3-way version check, per-project PyPI publish, image installs both CLIs,
  `pytauargus[tui]` extra); status-line off-screen fix (regression test);
  `docs/tui.md` guide + 7 screenshots.
- 0.3.3: PyPI README lesson — relative in-sdist image paths do NOT render on
  PyPI (verified broken on the 0.3.3 page); fix = absolute
  raw.githubusercontent URLs.
- 0.3.4: TUI README product-first rewrite (what it does / what it can't do
  yet), hosted screenshots; verified in the published PyPI description
  (0 relative refs).
- §B.7 reopen/restore: `tauargus-tui` accepts a `.workspace.json` (CLI arg or
  file browser). `Session.from_workspace` replays the manifest recipe on a
  fresh engine (spec + confirmed apriori marks + confirmed ops); the pending
  draft is restored as undoable edits; revisions/focus stay continuous.
  `WorkspaceStale` (fingerprint mismatch / missing input) → the current input
  is opened fresh instead (explicit reconciliation, the saved outcome is NOT
  treated as current); incompatible manifest version refused → file browser.
- Replay batch (`R`): `model.replay_batch()` writes `<stem>.replay.arb` next
  to the input with one `<SUPPRESS>` line per confirmed op and one
  `<APRIORI>` line (full legacy 5-field form, strict `0,0`) per table of
  confirmed marks, plus sibling `<stem>.tab<n>.apri` files. The still-pending
  draft is not included — the replay encodes the accepted recipe only.
- Engine fix: `_parse_apriory` (batch.py) could not parse ANY legacy
  `<APRIORI>` line — the quoted separator was read with `next_token`, which
  kept the closing quote (and trailing flags). Now read up to the closing
  quote; 3 new tests in test_batch.py pin the rtauargus `apriori_batch` form.
- Docs: `docs/tui.md` (reopen + replay sections, `R` key, outstanding list),
  TUI README (reopen + replay in "what it does"), top-level README (TUI
  section, current Docker image, screenshot — `e62270f`).
- Verification: TUI suite 82 passed (was 68); Python suite 262 passed /
  3 skipped (was 259). TDD throughout (red → green). Release 0.4.0
  (lockstep) pending user go-ahead — PyPI versions are immutable.
