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

## In flight: 3-repo restructure (user directive, 2026-10-14)

- [ ] P1 pytauargus: engine as pinned git submodule (replaces `tauargus-engine-rev` as source of truth); TUI depends on the matching pytauargus release, no second engine copy; engine commit + HiGHS version in build metadata; user then cuts `py-v0.5.3`.
- [ ] P2 R repo: rename to `rtauargus.native` (repo + package); engine as pinned submodule; combined pipeline builds `tauargusengine` + `rtauargus.native` from the submodule's scripts and publishes both as one GitHub Release set; one tested install procedure for both; branch pushed.
- [ ] P3 engine: remove `r-package.yml` once P2 is green; README ownership/dependency/install updates in all three repos; superseded docs removed.

## Watch items

- CRAN evaluation closed (`docs/cran-evaluation.md`): codebase is EUPL-1.2 (sdcTools/tauargus derivation, copyleft), which R/CRAN do not accept; no CRAN submission, GitHub Releases stays the R channel.

- User report: secondary suppression differs from legacy tau-ARGUS on a real dataset (89 of 1631 cells): reproduced; omitted cost/exponent defaults identified as a major cause (89 differences to 3 residual cells, all around C28). Findings + next steps in `docs/secondary-suppression-discrepancy.md`; separate format-4 zero-response export issue noted.

- [ ] Rejected-method refs: sdcTools `hypercube` (Fortran GHMIter, EUPL-1.1) for GH; NET -> Castro (UPC 2014).
- 5008 on re-OPT w/ secondary suppression; GHCR/project rename; OPT/MOD deadline expiry; solver-strategy doc.
- Linux binary glibc floor = 24.04 (R 4.4); SSPCloud/Onyxia image to confirm in phase F.
