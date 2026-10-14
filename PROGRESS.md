# Tau-Argus Rewrite: Progress

Branches: `master` (mainline) + short-lived feature branches for fixes.

## Verified checkpoints (details in ARCHIVE.md)

- [x] OPT/MOD end-to-end protection, audit and masked CSV on ex1 and dominance.
- [x] Core: WRITETABLE type-5, apriori, MOD/OPT/RND, audit (Intervalle).
- [x] Headless CLI; wheel + CI to PyPI + GHCR; releases 0.3.2-0.5.0 shipped; lockstep TUI pipeline, 0.5.0 verified, TUI smoke test in CI.
- [x] Conventional Commits for new history; agent rule: English replies.
- [x] `data/examples/ex1` demo; manual safety margin default 20; Parquet I/O + S3 URLs; markdown lint clean.
- [x] 0.5.2 shipped: cp314/cp315 wheels on PyPI; `uvx pytauargus-tui` works.
- [x] Repo split v1: pytauargus owns package/CLI/TUI/wheel pipeline from a pinned engine revision; this repo keeps engine + thin Python/R bindings.
- [x] Build mapping done: all local-path/env dependencies catalogued (R Makevars `../../../..` + baked rpaths; HiGHS pin only in CI; Python links `engine/build/lib`).
- [x] Distribution independence: HiGHS pin file, self-contained R staging, r-package.yml green on 3 OSes + clean-room (release commit `dba1a14`), release-file install + full rtauargus suite verified.
- [x] Release history backfill: 12 `py-v*` releases (0.1.0-0.5.2, 195 assets) moved to the pytauargus repo; this repo's release page clean; wheel pipeline re-enabled.

## In flight: R single-package release (user directive, 2026-10-14)

- [ ] Ship one self-contained `rtauargus.native` package per platform in the R release, replacing the separate `tauargusengine` binding package. Preparation complete: staging, merge blockers, engine table-mode fix, R front-end fixes, and local integration (386 PASS, README example, build-path guard) are verified; branch CI running on `native-engine`. The `r-v0.5.4` tag must be re-cut on the final commit and the release run by the user.

## Secondary suppression discrepancy (user directive, 2026-10-15)

- [x] Legacy `SPECIFYTABLE` cost/lambda default confirmed: shadow and cost default to response, lambda defaults to 1.
- [x] Fix implemented in pytauargus (`batch.py`, `engine.py`) and rtauargus.native (`R/engine_batch.R`, `R/engine_run.R`); regression tests added.
- [x] `sy1` reproduction: discrepancy reduced from 89 to 3 cells (all around `C28`) with correct response-cost default; default and explicit-response-cost runs are now identical.
- [ ] Root-cause the 3 residual `C28` differences as a model/port discrepancy (not solver tie-breaking); verify or fix.

## Watch items

- CRAN evaluation closed (`docs/cran-evaluation.md`): codebase is EUPL-1.2 (sdcTools/tauargus derivation, copyleft), which R/CRAN do not accept; no CRAN submission, GitHub Releases stays the R channel.

- User report: secondary suppression differs from legacy tau-ARGUS on a real dataset (89 of 1631 cells): reproduced; omitted cost/exponent defaults identified as a major cause (89 differences to 3 residual cells, all around C28). Findings + next steps in `docs/secondary-suppression-discrepancy.md`; separate format-4 zero-response export issue noted.

- [ ] Rejected-method refs: sdcTools `hypercube` (Fortran GHMIter, EUPL-1.1) for GH; NET -> Castro (UPC 2014).
- 5008 on re-OPT w/ secondary suppression; GHCR/project rename; OPT/MOD deadline expiry; solver-strategy doc.
- Linux binary glibc floor = 24.04 (R 4.4); SSPCloud/Onyxia image to confirm in phase F.
