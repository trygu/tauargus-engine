# Build and distribution

The three repos and what each owns:

- `trygu/tauargus-engine` (this repo): the native engine (five modules
  under `engine/native/`), the thin Python and R bindings, the R package
  build recipe, and the engine and binding tests.
- `trygu/pytauargus`: the `pytauargus` package, the `tauargus` CLI, the
  TUI, and the Python wheel pipeline. Pins this repo as a git submodule.
- `trygu/rtauargus.native`: the high-level R package (a fork of INSEE's
  `rtauargus`). It imports `tauargusengine`; it contains no native code
  of its own. Pins this repo as a git submodule and runs the R release
  pipeline for both R packages.

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

- The `tauargus-engine` git submodule in `pytauargus` (the gitlink) pins
  the exact engine commit.
- CI checks out the repo with `submodules: recursive`, builds HiGHS from
  the pinned tag, builds the engine superbuild, and builds the wheel
  from the pinned sources. The wheel records the engine commit and HiGHS
  version (`pytauargus.engine_meta()`).
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

Install from a GitHub Release of the
[rtauargus.native](https://github.com/trygu/rtauargus.native) repo. Its
release set contains the `tauargusengine` files (pick the one that
matches your platform; names carry version, R version, platform and
architecture) and the `rtauargus.native` source tarball:

```r
# the binding: platform binary (no compiler; R 4.5.3) or source
install.packages(
    "https://github.com/trygu/rtauargus.native/releases/download/r-vX.Y.Z/tauargusengine_X.Y.Z_r4.5.3_linux-x86_64.tar.gz",
    repos = NULL, type = "binary")
# the front-end: pure R, any platform
install.packages(
    "https://github.com/trygu/rtauargus.native/releases/download/r-vX.Y.Z/rtauargus.native_1.3.6.tar.gz",
    repos = NULL)
```

On macOS use `..._macos-arm64.tar.gz`, on Windows
`..._windows-x86_64.zip` (the standard R zip binary format). The
`tauargusengine` source tarball installs on any platform with CMake >=
3.16 and a C++11 compiler.

`tauargus_engine_meta()` reports the exact engine SHA, submodule pins
and HiGHS version a build came from. Use it when reporting a problem.

### R release pipeline

The pipeline lives in the
[rtauargus.native](https://github.com/trygu/rtauargus.native) repo
(`.github/workflows/release.yml`), which pins this repo as a submodule
and reuses `scripts/stage-r-package.sh` from it. On every push it
builds and installs both R packages on ubuntu-24.04, macos-15 and
windows-2022 (R 4.5.3) and runs the full `rtauargus.native` test
suite; it repackages the installed binding as a platform binary in the
standard R format (gzipped tarball on Linux/macOS, zip on Windows). On
an `r-v*` tag it publishes one GitHub Release set (both source tarballs
plus the three platform binaries) and runs a clean-room job that
installs both packages from the release artifacts in a bare container
with no checkout and no compiler.

## Releasing (lockstep)

The R packages and the Python wheel always ship the same version, built
from the same engine commit. Release X.Y.Z = two tags from one engine
commit (both front-end repos pin it as their submodule):

1. `py-vX.Y.Z` on `pytauargus`: the wheel pipeline builds self-contained
   wheels, runs the test suites, and publishes to PyPI and GitHub
   Release.
2. `r-vX.Y.Z` on `rtauargus.native`: the R pipeline publishes the
   release set (both source tarballs plus the three platform
   binaries).

## Supported platforms

- Python wheels: Linux (x86_64, aarch64, manylinux_2_28), macOS arm64,
  Windows x86_64; CPython 3.10 to 3.15.
- R package: source builds on any platform with CMake and a C++11
  compiler. Binary packages for R 4.5.3 on Linux x86_64 (built on
  ubuntu-24.04, glibc floor 2.39), macOS arm64 and Windows x86_64.
