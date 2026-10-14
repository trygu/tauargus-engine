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

## In flight: distribution independence (3-repo plan)

- [x] A: engine owns the recipe: `engine/HiGHS-VERSION` (v1.15.1), versioned `find_package(Highs)` in csp/crp, CI + `scripts/dev-test.sh` read the file.
- [x] B: `scripts/stage-r-package.sh` -> self-contained R source package (engine + HiGHS sources in `inst/`, configure builds in-package, static HiGHS, 4 bundled engine dylibs, rpath = @loader_path only, `tauargus_engine_meta()` provenance). Verified: tarball -> R CMD INSTALL -> smoke green, no build paths in the installed binaries.
- [ ] C: `r-package.yml` CI: source + binary packages (ubuntu-24.04 / macos arm64 / windows, R 4.4), publish to GitHub Packages + Release, clean-room install job.
- [ ] D: pytauargus: HiGHS tag read from pinned engine; pin bump.
- [ ] E: rtauargus `native-engine`: tauargusengine minimum version, README install docs, CI test workflow installing tauargusengine from GHP (pinned).
- [ ] F: docs: build chain per repo (engine `docs/build-and-distribution.md`, pytauargus README, rtauargus README); clean-room verification (Linux container).

## Watch items

- [ ] Rejected-method refs: sdcTools `hypercube` (Fortran GHMIter, EUPL-1.1) for GH; NET -> Castro (UPC 2014).
- 5008 on re-OPT w/ secondary suppression; GHCR/project rename; OPT/MOD deadline expiry; solver-strategy doc.
- Linux binary glibc floor = 24.04 (R 4.4); SSPCloud/Onyxia image to confirm in phase F.
