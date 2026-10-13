# Tau-Argus Rewrite: Progress

Branches: `master` (mainline) + short-lived feature branches for fixes.

## Verified checkpoints (details in ARCHIVE.md)

- [x] OPT/MOD end-to-end protection, audit and masked CSV on ex1 and dominance.
- [x] Core: WRITETABLE type-5, apriori, MOD/OPT/RND, audit (Intervalle).
- [x] Headless CLI; wheel + CI to PyPI + GHCR; releases 0.3.2-0.5.0 shipped; lockstep TUI pipeline, 0.5.0 verified, TUI smoke test in CI.
- [x] Dev loop: `scripts/sync-venv.sh`; venvs run local wheels, not PyPI.
- [x] TUI on mainline: staged s/r preview, marks u/p/S + undo/redo, audit,
  workspace save/reopen, replay batch, preview-in-grid; guide `docs/tui.md`.
- [x] Conventional Commits for new history; agent rule: English replies.
- [x] `feature/example-tables` merged: `data/examples/ex1` (tabular flow,
  one manual-U cell; demo: `s` gives the OPT M-pattern, red cell stays).
- [x] Manual safety margin default 20 (legacy `TableSet.manualMarge`;
  manual p.123) + OPT contract test.
- [x] Parquet I/O + S3 URLs: `protect()` reads `.parquet` paths/URLs, `TableResult.to_parquet`, CLI `protect`; pyarrow `parquet` extra.
- [x] Markdown lint: `.markdownlint.json` (MD013 off), legacy bundle excluded;
  repo `.md` files clean under `markdownlint-cli2`.
- [x] 0.5.2 shipped: cp314/cp315 wheels on PyPI; plain `uvx pytauargus-tui` works again.
- [x] Repo split v1: pytauargus package, CLI, TUI, notebooks, TUI docs and release workflow now live in the `pytauargus` repo (self-contained wheel from a pinned engine revision); this repo keeps the engine + thin Python/R bindings with binding smoke tests (Python and R); new repo's wheel build and 273 package tests verified locally.

## In flight

- [ ] Repo split (finish): pin the first engine revision in the `pytauargus` repo; run and verify its tests/wheels CI; PyPI trusted publishing for the new repo.
- [ ] Remaining §B.7/§B.8: export provenance (reuse saved artifacts; record the written revision).

## Watch items

- [ ] Rejected-method refs: sdcTools `hypercube` (Fortran GHMIter, EUPL-1.1)
  for GH; `network` has no code; README points to Castro (UPC 2014) for NET.
- 5008 on re-OPT w/ secondary suppression (legacy limitation); GHCR/project rename; OPT/MOD deadline expiry; `open_microdata`+`clean_all` note; solver-strategy doc.
