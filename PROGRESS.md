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
- [x] C: `r-package.yml` CI: source + binary packages (ubuntu-24.04 / macos arm64 / windows, R 4.4.3), install-from-sources + smoke on each OS, clean-room container job (no checkout/compiler). GitHub Release on `r-v*` is the only R channel (no GitHub Packages): source + binaries in standard R formats (tar.gz on Linux/macOS, zip on Windows), names carry version, R version, platform, arch.
- [x] D (engine side): pytauargus workflows read the HiGHS tag from the pinned engine checkout; pin bump to this engine commit in the pytauargus repo.
- [x] E: rtauargus `native-engine`: `tauargusengine (>= 0.5.3)`, README install docs from the engine's GitHub Releases, `tests.yaml` + pkgdown install the pinned engine binary from the release files (no secrets; needs the `r-v*` release to exist). Verified locally: full rtauargus suite against the installed tauargusengine green (386 pass, 0 fail). Branch unpushed (CI red until the release exists).
- [x] F (local): release-file install verified in a clean local environment: staged pkg -> source tarball + release-format binary -> fresh-library install -> inline smoke + slim installed tree (no bundled sources; configure discovers `highs-config.cmake`, moves engine sources to the build tree) + full rtauargus suite green.
- [ ] F (live): CI verification in flight: `r-package.yml` dispatch (3-OS source install + clean-room) and pytauargus tests on the re-bumped pin (pin + 0.5.3 version bump happen on the final green engine commit, before the user cuts the tags).

## Watch items

- [ ] Rejected-method refs: sdcTools `hypercube` (Fortran GHMIter, EUPL-1.1) for GH; NET -> Castro (UPC 2014).
- 5008 on re-OPT w/ secondary suppression; GHCR/project rename; OPT/MOD deadline expiry; solver-strategy doc.
- Linux binary glibc floor = 24.04 (R 4.4); SSPCloud/Onyxia image to confirm in phase F.
