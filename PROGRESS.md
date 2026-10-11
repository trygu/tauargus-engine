# Tau-Argus Rewrite — Progress

Branches: `master` (mainline) + short-lived feature branches for fixes.

## Verified checkpoints (details in ARCHIVE.md)
- [x] Core: WRITETABLE type-5, apriori, MOD/OPT/RND, audit (Intervalle).
- [x] Headless CLI; wheel + CI → PyPI + GHCR; Releases 0.3.0 / 0.3.1 shipped.
- [x] Engine fixes in-tree: 2nd-OPT SIGABRT (csp `3007826`), `ErrorStrings.txt`
  (hitas `d3e5b91`), FullJJ streams (`caf7528`).
- [x] Dev loop: `scripts/sync-venv.sh`; venvs run local wheels, not PyPI.
- [x] TUI on mainline (`bindings/tui/`, pkg `pytauargus-tui`): staged s/r
  preview, marks u/p/S + undo/redo, audit, workspace save, preview-in-grid.
- [x] **Release 0.3.2 shipped**: TUI in lockstep with pytauargus (same
  `py-v*` trigger, 3-way version check, per-project PyPI publish, GH Release
  all wheels, image installs both CLIs, `pytauargus[tui]`); status-line
  off-screen bug fixed (regression test, TUI suite 68); `docs/tui.md` guide.
- [x] **Release 0.3.3 shipped** (docs-only): PyPI freezes each version's
  README — but relative in-sdist screenshot paths do NOT render on PyPI
  (verified broken; lesson: use absolute hosted image URLs).
- [x] **Release 0.3.4 shipped** (docs-only): TUI README product-first
  (what it does / can't yet), screenshots at absolute raw.githubusercontent
  URLs — verified in the published PyPI description (0 relative refs).
- [x] Conventional Commits adopted for new history; agent rule: always
  respond in English (AGENTS.md §8).

## In flight
- [ ] TUI §B.7/§B.8: workspace reopen/restore + replay/export.

## Feature branches
- `feature/example-tables`: `data/examples/ex1` fixture (pushed, unmerged).

## Watch items
- 5008 on re-OPT w/ secondary suppression (legacy limitation); GHCR/project rename.
- OPT/MOD deadline expiry; `open_microdata`+`clean_all` note; Parquet; solver-strategy doc.
