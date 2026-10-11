# Tau-Argus Rewrite — Progress

Branches: `master` (mainline, 0.3.0) + `tui` (TUI). Goal: HiGHS solvers, headless CLI.

## Verified checkpoints (details in ARCHIVE.md)
- [x] Core: WRITETABLE type-5, apriori, MOD/OPT/RND, audit (Intervalle).
- [x] Headless CLI; wheel + CI → PyPI + GHCR; Release 0.3.0 (DataFrame
  `protect()`, cp310–cp313).
- [x] 2nd-OPT SIGABRT fixed (csp `3007826`): counters reset at loadprob entry
  + freeprob exit; `m` cells still → 5008 (legacy behavior, no longer a crash).
- [x] Legacy `ErrorStrings.txt` restored + embedded at build time (hitas
  `d3e5b91`); `error_string()` returns real messages (5008 verified).
- [x] Dev loop: `scripts/sync-venv.sh <venv>` (drift gate → engine → wheel →
  install); venvs run local wheels, not PyPI. Cleanup: `references/` removed;
  Java frontend removed from `master`, kept on `tui` as porting reference.

## In flight — TUI (branch `tui`, `bindings/tui/`, pkg `pytauargus-tui`)
- [x] `model.py` + `app.py` (navigator, grid, detail, log; j/k s r a o).
  13 tests green; human-verified in a real terminal (2026-10-11).
- [x] **State design (2026-10-11):** immediate draft edits → explicit preview
  → accept result; workspace save and export separate. Legacy Java traced;
  revision/audit/job ownership and acceptance checks in `docs/ui-design.md`.
- [ ] Next: draft undo/redo + isolated previews + acceptance; workspace/replay
  persistence; spinner, file-picker startup and `tui-v*`.
- Dev: py3.13 venv; `uv sync` resolves pytauargus from `../python` (uv path
  source — TUI follows the in-tree engine). sync-venv.sh = fast path after
  engine changes (rebuilds superbuild + force-install).

## Watch items / next non-TUI
- tui→master merge: `src/tauargus` modify/delete conflict → resolve by deletion.
- 5008 on re-OPT with secondary suppression is a legacy limitation; proper
  `m` re-optimization (solver semantics) would be future research if wanted.
- GHCR rename (0.2.1 verified, delete old pkg); project rename; solver-strategy doc.
- OPT/MOD deadline expiry coverage; `open_microdata`+`clean_all` note; Parquet.
