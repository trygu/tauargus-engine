# Tau-Argus Rewrite — Progress

Branches: `master` (mainline, 0.3.0) + `tui` (TUI). Goal: HiGHS solvers, headless CLI.

## Verified checkpoints (details in ARCHIVE.md)
- [x] Core: WRITETABLE type-5, apriori, MOD/OPT/RND, audit (Intervalle).
- [x] Headless CLI; wheel + CI → PyPI + GHCR; Release 0.3.0 (DataFrame
  `protect()`, cp310–cp313).
- [x] Engine fixes in-tree: 2nd-OPT SIGABRT (csp `3007826`) + legacy
  `ErrorStrings.txt` embedded (hitas `d3e5b91`); re-OPT → 5008 (legacy behavior).
- [x] Dev loop: `scripts/sync-venv.sh` (drift gate → engine → wheel → install);
  venvs run local wheels, not PyPI. `references/` + Java frontend cleaned up.

## In flight — TUI (branch `tui`, `bindings/tui/`, pkg `pytauargus-tui`)
- [x] v1: nav/grid/detail/log + staged s/r preview-delta + spinner; re-OPT
  5008 (carry-forward); real-terminal verified.
- [x] Cell instructions: `u`/`p`/`S` = draft edits (pending markers, no solver);
  Preview batches confirmed + pending apriori + method ops on a scratch run
  (run_batch → apply_apriori → suppress, §B.6); `y` confirms, `n` keeps draft.
- [x] Discoverability (§B.1): spec'd status line + `?`/F1 help overlay.
- [x] No-arg file browser (§B.7): no-arg launch opens a `DirectoryTree`
  filtered to subdirs + `.arb` only; Enter loads (shared arg-mode path),
  `q` quits. 45 tests green.
- [ ] Next (§B.8): undo/redo, per-revision audit; workspace save + replay/export;
  `tui-v*`.
- Dev: `uv sync` uses local pytauargus (uv path source); sync-venv.sh after
  engine changes.

## Watch items / next non-TUI
- tui→master merge: `src/tauargus` modify/delete conflict → resolve by deletion.
- 5008 on re-OPT with secondary suppression is a legacy limitation; proper
  `m` re-optimization (solver semantics) would be future research if wanted.
- GHCR rename (0.2.1 verified, delete old pkg); project rename; solver-strategy doc.
- OPT/MOD deadline expiry coverage; `open_microdata`+`clean_all` note; Parquet.
