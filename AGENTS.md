# Tau-Argus Rewrite: Agent Rules

Port SDC tool to HiGHS solver, portable cloud-native build, and headless Python CLI (replacing Java/Swing).

## 1. Context & Token Preservation (CRITICAL)

- **Terminal output discipline:** NEVER run tests or build commands that print unbounded raw logs into chat context.
  - Redirect verbose output: `<cmd> > /tmp/run.log 2>&1`
  - Inspect ONLY relevant lines: `tail -n 25 /tmp/run.log` or `grep -E "ERROR|CRASH|===|FAIL" /tmp/run.log`
  - Never run shell loops (e.g. `seq 1 25`) directly echoing stdout into context. Summarize results in a single log file.
- **Line reading limits:** Read maximum 60 lines per tool call (`limit=60`). Never read entire files.
- **No speculative code edits:** When debugging crashes, do not add arbitrary debug prints across multiple files. Run under ASan, get the exact stack trace, fix the flagged site, and verify.

## 2. Checkpoint & Progress Discipline

- **Micro-checkpoints:** You MUST update `PROGRESS.md` at every significant discovery or phase transition, NOT just when a task is 100% finished:
  1. When a hypothesis is confirmed or invalidated (e.g. "Invalidated: matsz buffer overflow").
  2. When an ASan stack trace is captured and root cause is identified.
  3. When a submodule build succeeds under new flags.
  4. When an in-flight task is verified.
- **State format:** Keep `PROGRESS.md` strictly under 35 lines. Completed items are moved to `ARCHIVE.md` immediately.

## 3. Source of Truth for Legacy Behavior (READ FIRST)

- **`docs/tau-argus-4.1-markdown-bundle/`**: the legacy τ-ARGUS 4.1 manual (PDF + 10.8k-line
  agent reference + 77 figure assets). This is the **source of truth** for legacy behavior:
  file formats, `.arb` batch grammar, parameters, and SDC mathematics. The rewrite must be a
  **drop-in replacement** for legacy τ-ARGUS: match its observable behavior, file I/O, and outputs.
  Part I (agent reference) is task-oriented; Part II is the page-by-page transcription.

## 4. Architecture & Boundaries

- Layout: `engine/` (C/C++ core) + `bindings/` (per-language front-ends).
  The engine is language-agnostic; each binding links the five engine libs.
- Native C/C++ engine: 5 git submodules under `engine/native/`:
  `core` (static), `csp` (HiGHS LP), `hitas` (links csp), `crp` (HiGHS MIP), `rounder` (links crp).
  Superbuild at `engine/CMakeLists.txt`.
  Build/commit INSIDE each submodule first, then bump pointers in the parent repo.
- Solver backend: Pure HiGHS (`<highs/interfaces/highs_c_api.h>`). No CPLEX, XPRESS, or legacy SCIP.
- Python binding: `bindings/python/` (pybind11 `_tauargus` extension, `cpp/`
  + CMake). The `pytauargus` package, `tauargus` CLI and TUI live in the
  separate `pytauargus` repo (github.com/trygu/pytauargus), which pins
  this repo as a git submodule (`tauargus-engine/`; the gitlink is the
  pin).
- R binding: `bindings/r/tauargusengine` (thin developer package). The
  `rtauargus.native` front-end (a fork of INSEE's `rtauargus`) is a
  separate repo (github.com/trygu/rtauargus.native); it pins this repo
  as a submodule and runs the R release pipeline, which stages the
  native layer into the fork so the release is one self-contained
  package.
- Engine bugs are fixed here; the front-end repos bump their engine pin.
  Never backport engine changes into a front-end repo.
- Legacy Java frontend `src/tauargus/`: removed from `master`; kept on the `tui`
  branch as the TUI porting reference (read-only; restorable from history).
- TUI docs (`docs/tui.md`, `docs/ui-design.md`) moved to the pytauargus repo;
  for TUI work read them there and update them in that repo.

## 5. Build Commands (macOS / Apple Silicon)

- **Dev loop.** `scripts/dev-test.sh` runs the full one-command dev loop
  (submodule drift gate, superbuild, native core ctest, Python binding
  smoke, R binding smoke when R is present). The HiGHS version is pinned
  in `engine/HiGHS-VERSION` (single source of truth; the CMake build,
  CI and the binding builds all read it). The `pytauargus` repo has its
  own `scripts/sync-venv.sh` (pin gate, engine build from the pinned
  checkout, local wheel, force-install); use that repo's venvs for
  package work.
- Highs Brew prefix: `-DHighs_DIR=$(brew --prefix)/lib/cmake/Highs`
- Submodule build:
  `cmake -S engine/native/<mod> -B engine/native/<mod>/build -DHighs_DIR=$(brew --prefix)/lib/cmake/Highs && cmake --build engine/native/<mod>/build`
- Superbuild (all 5):
  `cmake -S engine -B engine/build -DHighs_DIR=$(brew --prefix)/lib/cmake/Highs && cmake --build engine/build`
- ASan build (native debugging). Use a separate dir to preserve the release
  build:
  `cmake -S engine -B engine/build-asan -DHighs_DIR=$(brew --prefix)/lib/cmake/Highs -DCMAKE_C_FLAGS="-fsanitize=address -fno-omit-frame-pointer -g" -DCMAKE_CXX_FLAGS="-fsanitize=address -fno-omit-frame-pointer -g" && cmake --build engine/build-asan`
  (Preload runtime for Python: `DYLD_INSERT_LIBRARIES="$(clang -print-file-name=libclang_rt.asan_osx_dynamic.dylib)" uv run ...`)

## 6. Verification & Commits

- **TDD:** The agent is an avid TDD fan. For every feature/port, write the test
  *first* (it encodes the legacy contract), watch it fail for the right reason,
  then implement until green. A feature is not done until its test passes.
- Verification: native core `ctest --test-dir engine/build/native/core`;
  Python binding `cd bindings/python && uv run --with pytest --with pybind11 pytest tests -q`;
  R binding `R CMD INSTALL bindings/r/tauargusengine && Rscript bindings/r/tauargusengine/tests/test_binding_smoke.R`.
  Package, CLI, TUI and end-to-end tests run in the pytauargus repo.
- Surgical edits: Use targeted search/replace or patches. Avoid full-file rewrites.
- Commit cadence: Submodule commit first -> parent submodule bump + `PROGRESS.md` update.
- Conventional Commits for all new history (adopted at the 0.3.2 release;
  older history predates it): lowercase type `feat|fix|docs|refactor|perf|test|build|ci|chore`
  with optional scope and an imperative subject, e.g. `fix: status line off-screen`,
  `docs: tui guide`, `build(csp): 3007826 ...`. Release commits:
  `chore(release): X.Y.Z`. Auto-generated merge commits are exempt.
- Never stage build artifacts (`.venv/`, `build/`, `dist/`, `*.so`, `*.dylib`, `engine/build/`, `engine/native/build/`).
- No Windows registry APIs: Use environment variables, config files, or `tempfile`.
- Commits are authored as the user only: no `Co-authored-by` trailer.

## 7. Releasing

- Lockstep versioning: the R package (`rtauargus.native`) and the
  Python wheel (`pytauargus`) always ship the same version, built from
  the same engine commit. Never release one without the other.
- Release X.Y.Z = two tags cut from one engine commit (both front-end
  repos pin it as their submodule):
  1. `py-vX.Y.Z` on the `pytauargus` repo: the wheel pipeline builds
     self-contained wheels and publishes to PyPI and GitHub Release.
  2. `r-vX.Y.Z` on the `rtauargus.native` repo: its pipeline stages
     the native layer into the fork (single self-contained package)
     and publishes the release set (the R source tarball plus the
     platform binaries; standard R formats: gzipped tarball on
     Linux/macOS, zip on Windows; names carry version, R version,
     platform and architecture). See `docs/build-and-distribution.md`.
- Commit and push the engine change here first, then cut both tags.
  Release tags are cut by the user, not the agent.

## 8. Communication

- Always respond in English, regardless of the language the user writes in
  (the user often writes Norwegian; keep replies in English).

## 9. Documentation style

- Plain prose: active voice, short declarative sentences, common words. No
  filler or promotional vocabulary (e.g. additionally, crucial, delve,
  enhance, pivotal, showcase, testament, underscore, "serves as",
  "not just X but Y") and no grand generic conclusions.
- No em dashes or en dashes in prose. Use periods, commas or semicolons;
  hyphens stay for compounds and numeric ranges. Do not quote or reproduce
  em dashes from older sources.
- Colons introduce lists, examples or quoted output, not mid-sentence
  clauses.
- Bold is for list and section lead-in labels and the first definition of a
  key term. Do not bold names, acronyms or single words for emphasis.
- No arrow chains in prose (X -> Y -> Z); use verbs or commas ("returns",
  "then"). Arrows inside code identifiers or command examples are fine.
- User-facing docs (READMEs, `docs/`) state shipped, verified behaviour
  only. Internal tooling notes (screenshot capture recipes, local build
  steps) do not belong there.
- Verify claims against the code before writing them; when in doubt, read
  the source or the test suite.
