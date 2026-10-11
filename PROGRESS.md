# Tau-Argus Rewrite — Progress

Branches: `master` (mainline, 0.3.0) + `tui` (TUI). Goal: HiGHS solvers, headless CLI.

## Verified checkpoints (details in ARCHIVE.md)
- [x] Core: WRITETABLE type-5, apriori, MOD/OPT/RND, audit (Intervalle).
- [x] Headless CLI; wheel + CI → PyPI + GHCR; Release 0.3.0 (DataFrame
  `protect()`, cp310–cp313).
- [x] Engine fixes in-tree: 2nd-OPT SIGABRT (csp `3007826`) + legacy
  `ErrorStrings.txt` embedded (hitas `d3e5b91`); re-OPT → 5008 (legacy behavior).
- [x] Dev loop: `scripts/sync-venv.sh <venv>` (drift gate → engine → wheel →
  install); venvs run local wheels, not PyPI. Cleanup: `references/` removed;
  Java frontend removed from `master`, kept on `tui` as porting reference.

## In flight — TUI (branch `tui`, `bindings/tui/`, pkg `pytauargus-tui`)
- [x] v1 (2026-10-11): navigator, grid, detail, log (j/k s r a o);
  real-terminal verified. Staged s/r + preview-delta + spinner; 25 tests.
  Preview = throwaway `run_batch` (spec + confirmed + staged ops, §B.3);
  `y` accepts the previewed run, `n` discards; re-OPT 5008 displayed
  (proves op carry-forward); adopted session re-binds to the original `.arb`.
  textual 8.x notes in app.py comments.
- [x] **State design (2026-10-11):** immediate draft edits → explicit preview
  → accept result; workspace save and export separate. Legacy Java traced;
  revision/audit/job ownership + B.8 acceptance checks in `docs/ui-design.md`.
- [ ] Next (ui-design §2/§B.8): revisioned draft commands + history (cell
  instructions, undo/redo), isolated previews with freshness, acceptance/
  audit ownership; then workspace save + replay/export; file-picker startup;
  `tui-v*`.
- Dev: py3.13 venv; `uv sync` resolves pytauargus from `../python` (uv path
  source — TUI follows the in-tree engine). sync-venv.sh = fast path after
  engine changes (rebuilds superbuild + force-install).

## Watch items / next non-TUI
- tui→master merge: `src/tauargus` modify/delete conflict → resolve by deletion.
- 5008 on re-OPT with secondary suppression is a legacy limitation; proper
  `m` re-optimization (solver semantics) would be future research if wanted.
- GHCR rename (0.2.1 verified, delete old pkg); project rename; solver-strategy doc.
- OPT/MOD deadline expiry coverage; `open_microdata`+`clean_all` note; Parquet.
