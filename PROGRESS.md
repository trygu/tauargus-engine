# Tau-Argus Rewrite — Progress

Branches: `master` (mainline, 0.3.0) + `tui` (TUI). Goal: HiGHS solvers, headless CLI.

## Verified checkpoints (details in ARCHIVE.md)
- [x] Core: WRITETABLE type-5, apriori, MOD/OPT/RND, audit (Intervalle).
- [x] Headless CLI; wheel + CI → PyPI + GHCR; Release 0.3.0 (DataFrame
  `protect()`, cp310–cp313).
- [x] 2nd-OPT SIGABRT fixed (csp `3007826`): counters reset at loadprob entry
  + freeprob exit; `m` cells still → 5008 (legacy behavior, no longer a crash).
- [x] Legacy `ErrorStrings.txt` restored + embedded at build time (hitas
  `d3e5b91`); `error_string()` now returns real messages (5008 verified).
- [x] Core submodule worktree realigned to pin `ab37b03` (was stale at
  ancestor `e7ecb98`, which broke the wheel build: `GetTableCellBufferSizes`).

## In flight — TUI (branch `tui`, `bindings/tui/`, pkg `pytauargus-tui`)
- [x] `model.py` + `app.py` (navigator, grid, detail, log; j/k s r a o).
  13 tests green; human-verified in a real terminal (2026-10-11).
- [x] **Decision (2026-10-11):** staged + preview, confirm to commit —
  s/r stage method + preview-delta on scratch session; protection edits on
  table view; confirm applies to live session; save writes outputs (later: `.arb` emit).
- [ ] Next: staged s/r + preview-delta impl; file-picker startup; `.arb` emit; `tui-v*`.
- Dev: py3.13 venv on PyPI 0.3.0 wheel (`__version__` stale 0.2.1).

## Watch items / next non-TUI
- 5008 on re-OPT with secondary suppression is a legacy limitation; proper
  `m` re-optimization (solver semantics) would be future research if wanted.
- GHCR rename (0.2.1 verified, delete old pkg); project rename; solver-strategy doc.
- OPT/MOD deadline expiry coverage; `open_microdata`+`clean_all` note; Parquet.
