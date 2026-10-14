# tauargus-engine

Native, headless engine for statistical disclosure control (SDC) of tabular
data, with thin Python and R bindings. Together with the
[pytauargus](https://github.com/trygu/pytauargus) front-end it is a drop-in
replacement for the supported batch mode of the legacy open-source τ-ARGUS:
the same `.arb` batch files, file formats and outputs, without the GUI. See
[Compatibility and validation](#compatibility-and-validation) for which
methods and batch commands are supported.

This is a personal rewrite of the legacy product, started a few years ago and
worked on in on-and-off sprints. The C/C++ solver engine is rebuilt on a
modern toolchain and an open-source solver; the Java/Swing desktop front-end
is replaced by a headless Python CLI.

This repo holds the foundation: the engine and the thin language bindings.
The user-facing front-ends live in separate repos:

- **engine** (`engine/`): the C/C++ libraries that do the work, built
  against the open-source [HiGHS](https://github.com/ERGO-Code/HiGHS) solver.
  The legacy CPLEX, XPRESS and SCIP backends are gone.
- **bindings**: thin bindings over the five engine libs. `bindings/python/`
  is the pybind11 `_tauargus` extension; `bindings/r/tauargusengine` is the
  thin R package.
- **[pytauargus](https://github.com/trygu/pytauargus)**: the Python package
  (DataFrame API `protect()`, batch API, `tauargus` CLI) and the
  `pytauargus-tui` terminal UI. Its wheels bundle HiGHS and the engine,
  built from a pinned revision of this repo.
- **[rtauargus](https://github.com/trygu/rtauargus)**: the R package
  front-end over the thin R binding.

## Relationship to the original Tau-Argus

This is the original Tau-Argus solver code, not a reimplementation. The
legacy open-source τ-ARGUS is maintained by Statistics Netherlands (EUPL) at
[sdcTools/tauargus](https://github.com/sdcTools/tauargus). Version marking in
that code is inconsistent (the inherited `core` module reports `1.1.4.11`,
`hitas` says `4.3.1.1`), so this project calls the code line "τ-ARGUS 4.x"
and uses the bundled 4.1 manual as the behavioural reference.

- **Engine:** the C/C++ code is largely unchanged. The changes make it build
  with a modern toolchain (CMake, current GCC/Clang/MSVC), switch the solver
  backend to HiGHS, and make it self-contained.
- **Audit:** the standalone `intervalle.exe` audit program (Delphi, i.e. modern Pascal) is ported
  into the `csp` engine module, so the feasibility-interval audit runs in-process
  instead of as a separate executable.
- **Python package:** `pytauargus` is new. Its file-generation workflow builds
  on [rtauargus](https://github.com/InseeFrLab/rtauargus), the R wrapper around
  Tau-Argus. Its DataFrame and result API is inspired by
  [PiArgus (`piargus`)](https://github.com/lverweijen/piargus).

## Compatibility and validation

The engine is the legacy τ-ARGUS solver code, modernised. It builds on a
current toolchain and solves with [HiGHS](https://github.com/ERGO-Code/HiGHS)
instead of CPLEX, XPRESS or the legacy free solver. The behavioural reference
is the bundled τ-ARGUS 4.1 manual; the legacy release line continued at
least through 4.2.x, so this is a 4.x drop-in, not a guarantee of every
legacy feature.

**Supported suppression methods.** `OPT`, `MOD` and `RND` are implemented and
regression-tested. `CKM` has a dispatch path but no dedicated end-to-end
regression suite. `GH`, `NET` and `CTA` are rejected by the headless engine
although the batch parser still accepts their legacy syntax.

**No numerical-equivalence claim.** The regression suite is a contract check,
not proof of equivalence with original Tau-Argus. The solver change can alter
tolerances, termination and the choice between equally good solutions. Before
adopting a workflow, compare protection requirements, realised audit intervals,
information loss and failure behaviour on representative tables. The
suppression pattern may differ from the original; the protection requirements
must still hold.

**Audit is explicit.** The feasibility-interval audit (the legacy `intervalle`
program) runs in-process and is contract-tested against known intervals from
the manual. Call it with `engine.audit(tab)`; `TableResult.safe()` only masks
unsafe/secondary cells and does not run the audit.

**Diagnostics versus publication.** The engine's intermediate outputs (JJ,
INTERMEDIATE `.tab`, audit bounds) are diagnostics. They carry protection
levels and bounds; they are not masked release tables. Build publication
output explicitly through the engine API/CLI. The TUI grid is a diagnostic
view too. It shows the first two variables and original responses even after
rounding.

**Operational limits.** Run one job per process and working/output directory.
The native solver keeps process-global state, and concurrent engine calls in
one process are not validated. `OPT`/`MOD` time limits are in minutes
(`0` = no limit). Deadline expiry and partial results are not yet covered by
tests, so validate that behaviour before relying on a time limit as a
production termination guarantee.

## What it does

SDC reduces the risk that published tables disclose information about
individual respondents or businesses. A cell can be sensitive because too few
respondents contribute, a few dominate, or another contributor could estimate
a contribution. Deleting the value is often not enough, because totals and
bounds can reveal it, so related cells are protected too. This is the tabular
counterpart to [mu-Argus](https://github.com/INSEE/Argus), which protects
microdata.

A batch file drives the whole pipeline:

```text
input data + metadata
  -> define table dimensions and response
  -> define sensitivity rules and protection requirements
  -> construct or read the table
  -> identify primary sensitive cells
  -> protect: secondary suppression + audit, or controlled rounding
  -> write release table + report
```

## Audit (Intervalle)

After suppression, each suppressed cell still has a *range* of values it could
take and stay consistent with the published totals: its **realized lower and
upper bounds** (the *feasibility interval*). Protection requires sufficient
uncertainty to meet the configured protection requirements. A narrow interval
can reveal the original value or constrain it too closely; interval width alone
does not establish protection. The audit checks for insufficient protection.

In legacy Tau-Argus this was a separate program, `intervalle.exe`, a
standalone Delphi/Pascal executable. Tau-Argus wrote a `.JJ` file, launched
the executable externally, and read the intervals back. The operator had to
install it and keep it on the path, so it was the one part of the pipeline
that did not run in-process.

The rewrite folds it in. The audit logic is ported into the `csp` engine
module (`TauAuditJj`); it runs in-process over a temporary `.JJ` file and
needs nothing external. Use it three ways:

- **CLI.** `tauargus audit mybatch.arb` computes and suppresses, then reports
  each suppressed cell's realized interval and whether it is still unsafe.
- **Python.** `engine.audit(tab)` returns one row per suppressed cell
  (`cell`, `min`, `max`, `value`, `status`, `unsafe`). The realized bounds are
  also stored on the table and readable via `get_table_cell`.
- **Export.** `tauargus save mybatch.arb --audit --format intermediate` writes
  the legacy INTERMEDIATE (type-5) audit file, including the realized-interval
  columns.

## Architecture

```text
.arb batch  ->  tauargus CLI / tauargus-tui  ->  pytauargus  ->  tauargus-engine (C/C++)  ->  HiGHS
```

The engine is C++11, built from five git submodules under `engine/native/`:

- `core`: Data model, Argus/JJ file I/O, SDC engine entry points
- `csp`: Cell-suppression LP (branch-and-price) and feasibility audit
- `hitas`: Hierarchical table suppression (HiTaS); links `csp`
- `crp`: Controlled rounding (iterative rounding, audit)
- `rounder`: Dispatch layer over `crp`

```text
.
├── engine/      C/C++ engine; CMakeLists.txt is a superbuild of the 5 submodules
├── bindings/
│   ├── python/  pybind11 extension (cpp/) + CMake, binding smoke tests
│   └── r/       tauargusengine, the thin R package + binding smoke test
├── data/        sample .arb batches and tabular fixtures; also the test
│                fixtures consumed by the pytauargus repo's package tests
└── docs/        legacy Tau-Argus 4.1 manual and native debugging notes
```

## Building from source

Requirements:

- CMake ≥ 3.16 and a C++11 compiler
- Python 3.10+ and [uv](https://docs.astral.sh/uv/)
- [HiGHS](https://github.com/ERGO-Code/HiGHS) with its CMake package, at
  the version pinned in `engine/HiGHS-VERSION`: `brew install highs`
  (macOS), `sudo apt-get install libhighs-dev` (Debian/Ubuntu), or
  [build from source](https://github.com/ERGO-Code/HiGHS#building)

Clone with submodules (`git clone --recurse-submodules`). Build the five native
libraries first; the Python binding links the resulting `engine/build/lib/`
artifacts. CMake finds HiGHS from its installation prefix (set `Highs_DIR`
explicitly if needed):

```bash
# from the repository root
cmake -S engine -B engine/build -DCMAKE_BUILD_TYPE=Release
cmake --build engine/build -j
```

Then compile the Python extension against the built engine (the pytauargus
repo's wheel build does the same from a pinned checkout of this repo):

```bash
cmake -S bindings/python -B bindings/python/build-ext \
  -DTAUARGUS_PY_PKG_DIR=bindings/python/build-ext/pytauargus \
  -Dpybind11_DIR="$(python3 -c 'import pybind11; print(pybind11.get_cmake_dir())')"
cmake --build bindings/python/build-ext -j
```

Release wheels (bundling HiGHS and the engine) are built and published by
the [pytauargus](https://github.com/trygu/pytauargus) repo from a pinned
revision of this repo.

### R package

The distributable R package `tauargusengine` is self-contained:
`scripts/stage-r-package.sh` assembles it with the engine and HiGHS
sources, and its configure script builds everything from the package's
own sources at install time. Releases (source package to GitHub
Packages, binaries on GitHub Releases) run from `r-v*` tags via
`.github/workflows/r-package.yml`. See
[Build and distribution](docs/build-and-distribution.md) for the full
build chain across the three repos.

## Testing

Native core (CMake/CTest), then the binding smoke tests for the Python and
R bindings:

```bash
ctest --test-dir engine/build/native/core --output-on-failure

cd bindings/python
uv run --with pytest --with pybind11 pytest tests -q

R CMD INSTALL bindings/r/tauargusengine
Rscript bindings/r/tauargusengine/tests/test_binding_smoke.R
```

Package, CLI, TUI and end-to-end tests run in the
[pytauargus](https://github.com/trygu/pytauargus) repo.

## Acknowledgements

This project builds on Tau-Argus, its statistical methods and native
libraries, and the R and Python tools around it, developed by the people
named below.

### Original Tau-Argus and native libraries

The original Tau-Argus authors and contributors include Statistics
Netherlands (CBS), Peter-Paul de Wolf, Anco Hundepool, Sarah Giessing
(GHMITER and audit), Juan José Salazar González (optimisation methods),
and Jordi Castro (network solutions and CTA).

| Component | Authors and contributors |
| --- | --- |
| `libtauargus` (core) | Statistics Netherlands and Peter-Paul de Wolf. |
| `CSP` (cell suppression) | Matteo Fischetti, Juan José Salazar González, and M. D. Montes de Oca. |
| `CRP` (controlled rounding) | Juan José Salazar González. |
| `tauhitas` (modular suppression) | Statistics Netherlands and Peter-Paul de Wolf. |
| `taurounder` (rounding interface) | Statistics Netherlands and Peter-Paul de Wolf. |

The engine uses [HiGHS](https://highs.dev/) as its open-source LP/MIP solver.

### R and Python interfaces

[rtauargus](https://github.com/InseeFrLab/rtauargus) is developed at
INSEE / InseeFrLab by Pierre-Yves Berrard, Julien Jamme, Nathanaël Rastout,
Jeanne Pointet, Félix Beroud, André-Raymond Socard, Wistan Pomel,
Clara Baudry, and contributors.
Its metadata, batch and hierarchy generation logic was ported to
`pytauargus`; its `micro_rtauargus()` workflow also informed the high-level
`protect()` pipeline.

[PiArgus (`piargus`)](https://github.com/lverweijen/piargus), by
[Laurent Verweijen (`lverweijen`)](https://github.com/lverweijen) and
contributors, inspired the DataFrame-to-table workflow and `TableResult`
with its `safe()`, `status()`, `unsafe()` and `dataframe()` accessors.

[GaussSuppression](https://github.com/statisticsnorway/ssb-gausssuppression)
is developed at Statistics Norway by Øyvind Langsrud, Daniel Lupp,
Hege Bøvelstad and contributors. The protection regression tests adapt
the dominance example from its magnitude-table vignette.

## License

Distributed under the European Union Public Licence (EUPL) v1.2; see
[LICENSE](LICENSE). Tau-Argus is © Statistics Netherlands, with contributions
from the original author teams of each solver module.

This software is provided "AS IS", without warranties or conditions of any
kind, express or implied.
