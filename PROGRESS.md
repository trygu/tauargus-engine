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
- [x] F (live): run 13 fully green: linux, macos, windows, clean-room (publish runs only on r-v*). Windows: MinGW CRP exports, cspaudit.h EXPORTFUNC, Makevars -L flag, DLL staging to libs/x64. Clean-room: sudo, bash, libR in the ldd guard. Release engine commit: `dba1a14`.
- [ ] G: pytauargus pin -> `dba1a14` + 0.5.3 (pyproject.toml, tui/pyproject.toml), push; user cuts `py-v0.5.3` (pytauargus) + `r-v0.5.3` (engine `dba1a14`); then verify clean installs and push the rtauargus `native-engine` branch.

## Watch items

- CRAN evaluation for the R packages: `docs/cran-evaluation.md`. Build is fine (1.8 MB source, ~1 min install); hard gate is the license (EUPL-1.2 not in R's accepted list, engine submodules have no license files). Decision: relicense (then B: engine on CRAN first) or stay on GitHub Releases (option A).

- User report: secondary suppression differs from legacy tau-ARGUS on a real dataset (89 of 1631 cells): reproduced; omitted cost/exponent defaults identified as a major cause (89 differences to 3 residual cells, all around C28). Findings + next steps in `docs/secondary-suppression-discrepancy.md`; separate format-4 zero-response export issue noted.

- [ ] Rejected-method refs: sdcTools `hypercube` (Fortran GHMIter, EUPL-1.1) for GH; NET -> Castro (UPC 2014).
- 5008 on re-OPT w/ secondary suppression; GHCR/project rename; OPT/MOD deadline expiry; solver-strategy doc.
- Linux binary glibc floor = 24.04 (R 4.4); SSPCloud/Onyxia image to confirm in phase F.
