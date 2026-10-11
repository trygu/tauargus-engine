# Tau-Argus Rewrite — Progress

Branches: `master` (mainline) + short-lived feature branches for fixes.
Goal: HiGHS solvers, portable cloud-native build, headless Python CLI + TUI.

## Verified checkpoints (details in ARCHIVE.md)
- [x] Core: WRITETABLE type-5, apriori, MOD/OPT/RND, audit (Intervalle).
- [x] Headless CLI; wheel + CI → PyPI + GHCR; Releases 0.3.0 / 0.3.1 shipped.
- [x] Engine fixes in-tree: 2nd-OPT SIGABRT (csp `3007826`), `ErrorStrings.txt`
  (hitas `d3e5b91`), FullJJ streams (`caf7528`); re-OPT → 5008.
- [x] Dev loop: `scripts/sync-venv.sh`; venvs run local wheels, not PyPI.
- [x] TUI on mainline (`bindings/tui/`, pkg `pytauargus-tui`): staged s/r
  preview, marks u/p/S + undo/redo, audit, workspace save, preview-in-grid.
- [x] TUI hints + status-line visibility fixed; 68 tests (details in ARCHIVE).
- [x] AGENTS requires feature branches and PRs for all changes, including submodules.
- [x] TUI user guide: `docs/tui.md` + 7 screenshots (`docs/tui-images/`),
  implemented vs outstanding (§B.7/§B.8 gaps listed).

## In flight
- [ ] **Release 0.3.2**: preparation is on master; `py-v0.3.2` tags `923f41c`. TUI
  published in **lockstep** with pytauargus — same `py-v*` trigger,
  `build-tui` job, tag==py==tui version check, per-project PyPI publish,
  GH Release carries all wheels, container image installs engine + TUI.
  `pytauargus[tui]` extra. Suites green (py 259/3 skip; TUI 68).
  Next: verify publication completes successfully.
- [ ] TUI §B.7/§B.8: workspace reopen/restore + replay/export.

## Feature branches
- `feature/example-tables`: `data/examples/ex1` fixture (pushed, unmerged).

## Watch items
- 5008 on re-OPT w/ secondary suppression is a legacy limitation.
- GHCR rename; project rename; solver-strategy doc.
- OPT/MOD deadline expiry coverage; `open_microdata`+`clean_all` note; Parquet.
