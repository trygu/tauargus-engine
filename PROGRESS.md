# Tau-Argus Rewrite: Progress

Branches: `master` (mainline) + short-lived feature branches for fixes.

## Verified checkpoints (details in ARCHIVE.md)
- [x] Core: WRITETABLE type-5, apriori, MOD/OPT/RND, audit (Intervalle).
- [x] Headless CLI; wheel + CI to PyPI + GHCR; releases 0.3.2-0.4.0 shipped
  (lockstep TUI pipeline; 0.4.0 verified PyPI/GH/GHCR; TUI smoke test in CI).
- [x] Dev loop: `scripts/sync-venv.sh`; venvs run local wheels, not PyPI.
- [x] TUI on mainline: staged s/r preview, marks u/p/S + undo/redo, audit,
  workspace save/reopen, replay batch, preview-in-grid; guide `docs/tui.md`.
- [x] Conventional Commits for new history; agent rule: English replies.
- [x] Batch parser: `<APRIORI>` quoted separator now parses (legacy
  `"file",tab,"sep",flags` form; 3 tests in test_batch.py).
- [x] TUI 82 / py 264 green at 0.4.0.
- [x] `feature/example-tables` merged: `data/examples/ex1` (tabular flow,
  one manual-U cell; demo: `s` gives the OPT M-pattern, red cell stays).
- [x] Manual safety margin default 20 (legacy `TableSet.manualMarge`;
  manual p.123) + OPT contract test (cell suppression: values never
  rewritten, unsafe cell stays published, non-empty M pattern).
- [x] Docs plain-prose pass: all READMEs, `docs/tui.md`, `docs/ui-design.md`;
  style rules in AGENTS.md §9.

## In flight
- TUI architecture/plans: `docs/ui-design.md` §5; Java review in ARCHIVE.
- [ ] Remaining §B.7/§B.8: export provenance (reuse saved artifacts;
  record the written revision).

## Watch items
- [ ] Rejected-method refs: sdcTools `hypercube` (Fortran GHMIter, EUPL-1.1)
  for GH; `network` has no code; README points to Castro (UPC 2014) for NET.
- 5008 on re-OPT w/ secondary suppression (legacy limitation); GHCR/project rename.
- OPT/MOD deadline expiry; `open_microdata`+`clean_all` note; Parquet; solver-strategy doc.
