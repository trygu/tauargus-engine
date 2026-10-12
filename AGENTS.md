# Tau-Argus Rewrite — Agent Rules

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
- **`docs/tau-argus-4.1-markdown-bundle/`** — the legacy τ-ARGUS 4.1 manual (PDF + 10.8k-line
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
- Python layer: `bindings/python/` (pybind11 bindings + `pytauargus` package, `tauargus` CLI).
  Target product is headless `.arb` batch CLI. A future R binding lives under `bindings/r/`.
- Legacy Java frontend `src/tauargus/`: removed from mainline by `307b977`.
  The canonical preserved source is `307b977^` (`0082a02`); inspect it with
  `git show 307b977^:src/tauargus/<path>` without restoring Java to mainline.
- For TUI work, read `docs/ui-design.md` (architecture, state contracts and
  prioritised plans) and `docs/tui.md` (shipped behaviour and current limits).
  Update both when implementing a planned capability; plans are not shipped features.

## 5. Build Commands (macOS / Apple Silicon)
- **Sync a venv with the current tree — the single dev-loop command, run after
  ANY change under `engine/` or `bindings/python/`:**
  `scripts/sync-venv.sh <venv>` — submodule-drift gate → release engine →
  wheel for the venv's Python → force-install. Dev venvs must run a locally
  built wheel, never PyPI (PyPI lags in-tree engine fixes by a release).
- Highs Brew prefix: `-DHighs_DIR=$(brew --prefix)/lib/cmake/Highs`
- Submodule build:
  `cmake -S engine/native/<mod> -B engine/native/<mod>/build -DHighs_DIR=$(brew --prefix)/lib/cmake/Highs && cmake --build engine/native/<mod>/build`
- Superbuild (all 5):
  `cmake -S engine -B engine/build -DHighs_DIR=$(brew --prefix)/lib/cmake/Highs && cmake --build engine/build`
- ASan build (native debugging) — use separate dir to preserve release build:
  `cmake -S engine -B engine/build-asan -DHighs_DIR=$(brew --prefix)/lib/cmake/Highs -DCMAKE_C_FLAGS="-fsanitize=address -fno-omit-frame-pointer -g" -DCMAKE_CXX_FLAGS="-fsanitize=address -fno-omit-frame-pointer -g" && cmake --build engine/build-asan`
  (Preload runtime for Python: `DYLD_INSERT_LIBRARIES="$(clang -print-file-name=libclang_rt.asan_osx_dynamic.dylib)" uv run ...`)

## 6. Verification & Commits
- **TDD:** The agent is an avid TDD fan. For every feature/port, write the test
  *first* (it encodes the legacy contract), watch it fail for the right reason,
  then implement until green. A feature is not done until its test passes.
- Verification: `cd bindings/python && uv run pytest` | `uv build --wheel`
- Surgical edits: Use targeted search/replace or patches. Avoid full-file rewrites.
- Commit cadence: Submodule commit first -> parent submodule bump + `PROGRESS.md` update.
- Conventional Commits for all new history (adopted at the 0.3.2 release;
  older history predates it): lowercase type `feat|fix|docs|refactor|perf|test|build|ci|chore`
  + optional scope, imperative subject — `fix: status line off-screen`,
  `docs: tui guide`, `build(csp): 3007826 ...`. Release commits:
  `chore(release): X.Y.Z`. Auto-generated merge commits are exempt.
- Never stage build artifacts (`.venv/`, `build/`, `dist/`, `*.so`, `*.dylib`, `engine/build/`, `engine/native/build/`).
- No Windows registry APIs: Use environment variables, config files, or `tempfile`.
- Commits are authored as the user only: no `Co-authored-by` trailer.

## 7. Releasing (PyPI + GHCR image)
- Releases are tag-driven: tag `py-v<version>` runs `.github/workflows/wheels.yml`
  (wheels -> GitHub Release -> PyPI via trusted publishing -> GHCR image).
- PyPI versions are immutable and the workflow fails if the tag differs from the
  package version. Never reuse or move a published tag.
- To release (only when the user asks):
  1. Bump `version` in `bindings/python/pyproject.toml` (semver: patch = fixes,
     minor = features, major = breaking).
  2. `cd bindings/python && uv lock && uv run pytest` must pass.
  3. Commit (`chore(release): X.Y.Z`) and push the branch.
  4. `git tag py-vX.Y.Z && git push origin py-vX.Y.Z`.
  5. Watch the run: `gh run list --workflow wheels --limit 1`.
- Wheels: macOS arm64, Linux x86_64+aarch64 (manylinux_2_28), Windows x64; Python 3.10-3.13.
- The image is `ghcr.io/trygu/tauargus-engine:<version>` and `:latest`.

## 8. Communication
- Always respond in English, regardless of the language the user writes in
  (the user often writes Norwegian; keep replies in English).
