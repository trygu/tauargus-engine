# CRAN evaluation: the R packages

**Status:** closed; the codebase is EUPL-1.2 (confirmed 2026-10-14), which
R and CRAN do not accept, so no CRAN submission will be made. Distribution
stays on GitHub Releases (option A).
**Recorded:** 2026-10-14.

## Question

Should `tauargusengine` (the low-level binding, built and released from
this repo) and/or `rtauargus` (the high-level front-end repo) be
submitted to CRAN, and what would each require?

## Current distribution path (status quo)

- `tauargusengine`: source + prebuilt binaries per platform (Linux,
  macOS, Windows) as GitHub Release files on this repo, cut on `r-v*`
  tags. Proven green on 2026-10-14.
- `rtauargus`: depends on `tauargusengine (>= 0.5.3)`, installed from
  the release files in its CI. Not distributed anywhere public yet.
- CRAN has no `tauargus`-family package today, so both names are free.

## Findings

### 1. License: hard blocker

- The R package declares `License: EUPL-1.2`. EUPL is not in R's
  accepted license list (verified against the license set shipped with
  R and against r-project.org/Licenses, which has no EUPL entry).
  CRAN's first automated check rejects an unrecognized license.
- The five engine submodules (`core`, `csp`, `hitas`, `crp`,
  `rounder`) carry no license file at all. The EUPL-1.2 claim exists
  only in the R package's `LICENSE` ("tauargus-engine contributors").
  CRAN review requires a clear license for all bundled code.
- The bundled HiGHS copy is MIT licensed, which CRAN accepts.
- Decision (2026-10-14): the engine is derived from sdcTools/tauargus,
  which is EUPL-1.2. EUPL is copyleft, so the derived code stays
  EUPL-1.2; there is no path to a permissive relicense without the
  original copyright holders. CRAN is therefore not an option for
  `tauargusengine` or, by the dependency gate, for `rtauargus.native`.
  Follow-up hygiene: the five engine submodules carry no LICENSE file
  of their own (the engine root and the R package do).

### 2. Build size and time: acceptable

Measured locally on a 4-core Apple Silicon machine, from the staged
self-contained package (bundled HiGHS + engine sources):

| Step | Result |
|---|---|
| Staged package size | 11 MB |
| Source tarball (`R CMD build`) | 1.8 MB, build takes ~2 s |
| `R CMD INSTALL` from tarball | ~33 s wall (parallel) |

CRAN checkers are slower than a modern desktop (typically 2-4 cores),
so expect roughly 1-4 minutes for the install there. That is within
the norm for CRAN packages with native code. No downloads at install
time: everything compiles from bundled sources.

### 3. Documentation

- `tauargusengine`: 58 exported functions, zero man pages. R CMD check
  errors on undocumented exports, so this needs a full Roxygen pass
  before submission. Mechanical but real work.
- `rtauargus`: 49 man pages over 43 R files, mature documentation.
  Two caveats for CRAN: the `Description`/docs have a French
  component (`Language: fr`, INSEE heritage), and CRAN requires
  package documentation in English. The DESCRIPTION also carries the
  `tauargusengine` import that is not on CRAN (see 4).

### 4. Dependency gate

CRAN requires all `Depends`/`Imports` packages to be on CRAN.
`rtauargus` imports `tauargusengine (>= 0.5.3)`, so it cannot be
submitted until the binding is on CRAN. Its other imports (purrr,
dplyr, tidyr, data.table, gdata, stringr, rlang, zoo, sdcHierarchies,
igraph, lifecycle) are all CRAN packages.

### 5. Low-level package value on CRAN

There is little standalone value in `tauargusengine` on CRAN; it is a
binding. Its CRAN presence matters only as the dependency gate for
`rtauargus` (or as a building block for other R SDC tools).

## Options

**A. Status quo, no CRAN.** Keep GitHub Release binaries for
`tauargusengine` and consume them in `rtauargus`. If binary
distribution for R users matters later, Posit Package Manager (P3M)
is the standard alternative to CRAN for native packages.

**B. Relicense, then two CRAN packages.** Make the engine license
CRAN-acceptable, add license files, write the man pages, submit
`tauargusengine`; then submit `rtauargus` with a normal dependency.
Clean layering, no duplicated engine sources, matches the current
repo split.

**C. Relicense, then one vendored CRAN package.** Fold the engine and
HiGHS sources into `rtauargus` as a subsystem (the staging script
already inlines them for `tauargusengine`; the same mechanism serves a
single-package CRAN tarball). Removes the dependency gate and hides
the low-level package from CRAN, at the cost of maintaining a second
copy of the engine sources inside the front-end.

## Final recommendation

Option A: keep GitHub Releases as the R distribution channel (prebuilt
binaries per platform, as the pipeline already produces). If binary
distribution for R users matters later, Posit Package Manager (P3M) is
the standard alternative to CRAN for native packages. The build numbers
above show the source is CRAN-ready on mechanics; only the license
prevents a submission, and that is fixed by the derivation.

## If the CRAN track resumes

The CRAN policies (https://cran.r-project.org/web/packages/policies.html)
are part of the submission requirements for that track; check them
against both packages when the license question is resolved.
