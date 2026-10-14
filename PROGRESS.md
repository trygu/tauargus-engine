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

- [ ] Ship one self-contained `rtauargus.native` package per platform in the R release, replacing the separate `tauargusengine` binding package (two-file install removed).
- [x] Staging: `stage-r-package.sh --merge-into DIR` composes the native layer (binding R/src, configure, vendored engine + HiGHS, provenance) into the front-end; NAMESPACE/DESCRIPTION patched in place; `scripts/test-stage-r-merge.sh` green (24 checks); standalone mode regression-tested.
- [x] Merge blockers found in local integration and fixed: (1) R CMD build runs configure via its temp install and tars the mutated tree, so sources vendor in top-level `engine/`/`highs/` dirs R never installs and configure is read-only on them; (2) R names the shared object after the package verbatim (`rtauargus.native.so`), so `useDynLib` keeps the dot form, the init symbol is the underscore form `R_init_rtauargus_native` (valid C; R's dynload falls back to it when the dotted lookup fails), and the fork's `tauargusengine::` test qualifier is rewritten to the front-end namespace by staging; (3) the clean-room installs the CRAN deps because binary `R CMD INSTALL` checks Imports. A stale `tauargusengine 0.1.0` left in the local R framework library was silently masking the namespace problem; removed.
- [x] Version 0.5.4 prep: engine binding DESCRIPTION 0.5.4; both front-end pins at engine `aa811ed`; pytauargus + TUI 0.5.4; pushed (pytauargus `95d4ca3`, rtauargus.native master `4d67cb7`, 3-platform branch CI running).
- [ ] Verification: local integration green + R branch CI green (3 platforms, R 4.5.3), then the 0.5.4 tags (user).
- [x] R repo edits: `release.yml` single-package flow (tag vs engine-pin check, merge staging, one binary per platform, one-file clean-room + CRAN deps, static tarball verification), README per-platform install + quick test, `docs/compatibility.md` (was untracked; force-added), `tools/engine-meta-check.R` on the merged package, DESCRIPTION 1.3.7 + NEWS. `audit_jj` (CSP intervalle audit) stays exported in the merged NAMESPACE; the front-end `audit(tab)`/`with_audit` paths are untouched fork code.

## Watch items

- CRAN evaluation closed (`docs/cran-evaluation.md`): codebase is EUPL-1.2 (sdcTools/tauargus derivation, copyleft), which R/CRAN do not accept; no CRAN submission, GitHub Releases stays the R channel.

- User report: secondary suppression differs from legacy tau-ARGUS on a real dataset (89 of 1631 cells): reproduced; omitted cost/exponent defaults identified as a major cause (89 differences to 3 residual cells, all around C28). Findings + next steps in `docs/secondary-suppression-discrepancy.md`; separate format-4 zero-response export issue noted.

- [ ] Rejected-method refs: sdcTools `hypercube` (Fortran GHMIter, EUPL-1.1) for GH; NET -> Castro (UPC 2014).
- 5008 on re-OPT w/ secondary suppression; GHCR/project rename; OPT/MOD deadline expiry; solver-strategy doc.
- Linux binary glibc floor = 24.04 (R 4.4); SSPCloud/Onyxia image to confirm in phase F.
