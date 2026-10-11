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
- [x] **Release 0.3.2 shipped**: TUI published in lockstep with pytauargus
  (same `py-v*` trigger, 3-way version check, per-project PyPI publish, GH
  Release carries all 17 wheels, image installs both CLIs, `pytauargus[tui]`).
  Status-line off-screen bug fixed (regression test; TUI suite 68).
  TUI guide `docs/tui.md` + screenshots. Conventional Commits adopted for
  new history (§6/§7).
- [x] **Release 0.3.3 shipped** (docs-only): PyPI freezes each version's
  README; this puts the improved TUI README (in-sdist screenshots, absolute
  doc links) on the published PyPI page. Verified on PyPI + GH Release.

## In flight
- [ ] TUI §B.7/§B.8: workspace reopen/restore + replay/export.

## Feature branches
- `feature/example-tables`: `data/examples/ex1` fixture (pushed, unmerged).

## Watch items
- 5008 on re-OPT w/ secondary suppression is a legacy limitation.
- GHCR rename; project rename; solver-strategy doc.
- OPT/MOD deadline expiry coverage; `open_microdata`+`clean_all` note; Parquet.
