# Build and distribution

The three repos and what each owns:

- `trygu/tauargus-engine` (this repo): the native engine (five modules
  under `engine/native/`), the thin Python and R bindings, the R package
  build recipe, and the R package release pipeline.
- `trygu/pytauargus`: the `pytauargus` package, the `tauargus` CLI, the
  TUI, and the Python wheel pipeline.
- `trygu/rtauargus`: the high-level R package. It imports
  `tauargusengine`; it contains no native code of its own.

## The HiGHS version pin

`engine/HiGHS-VERSION` is the single source of truth for the HiGHS
version (currently `v1.15.1`). Everything reads it:

- The superbuild and the `csp`/`crp` sub-builds require the pinned
  version via `find_package(Highs <version> REQUIRED)`.
- The CI workflows (this repo and `pytauargus`) read the file and build
  HiGHS from that tag.
- The R package staging script clones that tag into the package.

## Building the engine

```sh
cmake -S engine -B engine/build \
      -DHighs_DIR=$(brew --prefix)/lib/cmake/Highs
cmake --build engine/build
```

Outputs land in `engine/build/lib` (the five libraries) and
`engine/build/bin`. `scripts/dev-test.sh` runs the full dev loop:
submodule drift gate, superbuild, native core tests, Python binding
smoke, R binding smoke.

## Python chain (pytauargus)

- `pytauargus/tauargus-engine-rev` pins the exact engine commit.
- CI checks out that commit with all submodules, builds HiGHS from the
  pinned tag, builds the engine superbuild, and builds the wheel from
  the pinned sources.
- The wheel bundles the binding, the four engine shared libraries and
  HiGHS (the platform repair step adds HiGHS). The installed wheel and
  `uvx pytauargus-tui` work without any engine checkout.

## R chain

### Development (this repo)

`bindings/r/tauargusengine` is the developer binding. It links the
prebuilt `engine/build/lib` plus the local HiGHS prefix. Build the
superbuild first, then:

```sh
R CMD INSTALL bindings/r/tauargusengine
Rscript bindings/r/tauargusengine/tests/test_binding_smoke.R
```

### Distribution (the tauargusengine package)

`scripts/stage-r-package.sh` assembles a self-contained source package:

- the binding sources, plus `inst/engine` (the five module sources and
  the same CMake recipes the superbuild uses) and `inst/highs` (the
  pinned HiGHS tag);
- a `configure`/`configure.win` pair that, at install time, builds
  HiGHS (static) and the five engine libraries from the package's own
  sources;
- a generated `src/rta_meta.h` with the engine SHA, the submodule pins
  and the HiGHS version.

At install time the package compiles only its own sources. No engine
checkout, no `engine/build/lib`, no HiGHS prefix and no other git
checkout are needed. The four engine shared libraries are installed in
the package `libs/` directory next to the R DLL, and every binary
resolves its libraries relative to the installation
(`@loader_path`/`$ORIGIN`, the DLL directory on Windows). The installed
package references no build-machine path.

Install from a GitHub Release of this repo. The release files are the
distribution channel; pick the one that matches your platform (names
carry version, R version, platform and architecture):

Binary (no compiler; R 4.4.3):

```r
install.packages(
    "https://github.com/trygu/tauargus-engine/releases/download/r-vX.Y.Z/tauargusengine_X.Y.Z_r4.4.3_linux-x86_64.tar.gz",
    repos = NULL, type = "binary")
```

On macOS use `..._macos-arm64.tar.gz`, on Windows
`..._windows-x86_64.zip` (the standard R zip binary format).

Source (any platform; needs CMake >= 3.16 and a C++11 compiler):

```r
install.packages(
    "https://github.com/trygu/tauargus-engine/releases/download/r-vX.Y.Z/tauargusengine_X.Y.Z.tar.gz",
    repos = NULL)
```

`tauargus_engine_meta()` reports the exact engine SHA, submodule pins
and HiGHS version a build came from. Use it when reporting a problem.

### R release pipeline

`.github/workflows/r-package.yml` runs on pull requests to `master` and
on `r-v*` tags:

- builds and installs the staged package on ubuntu-24.04, macos-15 and
  windows-2022 (R 4.4.3) and runs the binding smoke test;
- repackages each installed package as a platform binary in the
  standard R format (gzipped tarball on Linux/macOS, zip on Windows),
  named with version, R version, platform and architecture;
- on a tag: attaches the source package and the three platform
  binaries to a GitHub Release, and runs a clean-room job that
  installs the Linux binary in a bare container with no checkout and
  no compiler.

## Releasing (lockstep)

The R package and the Python wheel always ship the same version, built
from the same engine commit. Release X.Y.Z = two tags from one engine
commit:

1. `py-vX.Y.Z` on `pytauargus`: bump `tauargus-engine-rev`, build the
   wheels, publish to PyPI, GitHub Release and GHCR.
2. `r-vX.Y.Z` on this repo: the GitHub Release with the source package
   and the three platform binaries.

## Supported platforms

- Python wheels: Linux (x86_64, aarch64, manylinux_2_28), macOS arm64,
  Windows x86_64; CPython 3.10 to 3.15.
- R package: source builds on any platform with CMake and a C++11
  compiler. Binary packages for R 4.4.3 on Linux x86_64 (built on
  ubuntu-24.04, glibc floor 2.39), macOS arm64 and Windows x86_64.
