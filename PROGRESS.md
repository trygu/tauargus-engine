# Tau-Argus Rewrite — Progress

Branches: `master` (mainline) + short-lived feature branches for fixes.
Goal: HiGHS solvers, portable cloud-native build, headless Python CLI + TUI.

## Verified checkpoints (details in ARCHIVE.md)
- [x] Core: WRITETABLE type-5, apriori, MOD/OPT/RND, audit (Intervalle).
- [x] Headless CLI; wheel + CI → PyPI + GHCR; Release 0.3.0 (DataFrame `protect()`, cp310–cp313).
- [x] Engine fixes in-tree: 2nd-OPT SIGABRT (csp `3007826`) + legacy `ErrorStrings.txt`
  embedded (hitas `d3e5b91`) + FullJJ streams closed on solver errors (`caf7528`); re-OPT → 5008.
- [x] Dev loop: `scripts/sync-venv.sh` (drift gate → engine → wheel → install); venvs run
  local wheels, not PyPI. `references/` + legacy Java frontend removed from mainline.
- [x] TUI on mainline (`bindings/tui/`, pkg `pytauargus-tui`): nav/grid/detail/log, staged
  s/r preview, cell instructions u/p/S, undo/redo, audit ownership, workspace save, GIL-freeze
  fix, preview-in-grid. 67 tests. `tui` branch merged + deleted.
- [x] README acknowledgements + release-following install guidance (PR #6).

## In flight
- [ ] **Release 0.3.1** (tag `py-v0.3.1`): ships the in-tree engine fixes (csp/hitas) + TUI
  onto PyPI/GHCR. Bump version → tests → tag.
- [ ] TUI §B.7/§B.8: workspace reopen/restore + replay/export.

## Feature branches
- `fix/u-hint`: correct the misleading u/p status hints + help text (green, ready to merge).

## Watch items
- 5008 on re-OPT w/ secondary suppression is a legacy limitation.
- GHCR rename; project rename; solver-strategy doc.
- OPT/MOD deadline expiry coverage; `open_microdata`+`clean_all` note; Parquet.
