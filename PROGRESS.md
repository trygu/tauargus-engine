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
- [x] TUI §B.7: workspace **reopen/restore** + **replay batch** (`R`);
  TUI 82 / py 264 green.
- [x] **Release 0.4.0 shipped**: reopen + replay + APRIORI fix; verified on
  PyPI/GH Release/GHCR; TUI smoke test now builds against this run's wheel.
- [x] `feature/example-tables` merged: `data/examples/ex1` (tabular flow,
  one manual-U cell; demo: `s` → OPT M-pattern, red cell stays).
- [x] Manual safety margin default 20 (legacy `TableSet.manualMarge`;
  manual p.123) + OPT contract test (cell suppression: values never
  rewritten, unsafe cell stays published, non-empty M pattern).

## In flight
- TUI architecture/plans: `docs/ui-design.md` §5; Java review in ARCHIVE.
- [ ] Remaining §B.7/§B.8: export provenance (reuse saved artifacts; record
  the written revision).

## Watch items
- [ ] sdcTools `hypercube`/`network` (github.com/sdcTools) as subsystem
  candidates for the rejected methods (NET/GH).
- 5008 on re-OPT w/ secondary suppression (legacy limitation); GHCR/project rename.
- OPT/MOD deadline expiry; `open_microdata`+`clean_all` note; Parquet; solver-strategy doc.
