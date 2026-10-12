# Tau-Argus Rewrite — Progress

Branches: `master` (mainline) + short-lived feature branches for fixes.

## Verified checkpoints (details in ARCHIVE.md)
- [x] Core: WRITETABLE type-5, apriori, MOD/OPT/RND, audit (Intervalle).
- [x] Headless CLI; wheel + CI → PyPI + GHCR; Releases 0.3.0 / 0.3.1 shipped.
- [x] Dev loop: `scripts/sync-venv.sh`; venvs run local wheels, not PyPI.
- [x] TUI on mainline: staged s/r preview, marks u/p/S + undo/redo, audit,
  workspace save, preview-in-grid; guide `docs/tui.md`.
- [x] **Releases 0.3.2 / 0.3.3 / 0.3.4 shipped** (lockstep TUI pipeline;
  PyPI README lesson: absolute hosted image URLs; product-first TUI README).
- [x] Conventional Commits for new history; agent rule: English replies.
- [x] Batch parser: `<APRIORI>` quoted separator now parses (legacy
  `"file",tab,"sep",flags` form; 3 tests in test_batch.py).
- [x] TUI §B.7: workspace **reopen/restore** (CLI arg + file browser; recipe
  re-run on a fresh engine, draft restored undoable, stale input reconciled
  fresh, bad version refused) + **replay batch** (`R`). TUI 82 / py 262 green.
- [x] **Release 0.4.0 shipped**: workspace reopen + replay + APRIORI fix;
  verified on PyPI/GH Release/GHCR.
- [x] Release pipeline: TUI smoke test now installs the engine wheel built
  in the same run (`build-tui` needs `build-linux`) — floors may track the
  release version instead of the last published one.

## In flight
- [ ] Remaining §B.7/§B.8: export provenance (reuse saved artifacts; record
  the written revision).

## Feature branches
- `feature/example-tables`: `data/examples/ex1` fixture (pushed, unmerged).

## Watch items
- 5008 on re-OPT w/ secondary suppression (legacy limitation); GHCR/project rename.
- OPT/MOD deadline expiry; `open_microdata`+`clean_all` note; Parquet; solver-strategy doc.
