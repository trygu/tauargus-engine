# tauargus-engine

Native, headless engine for statistical disclosure control (SDC) of tabular
data, plus a Python tool that drives it. It is a drop-in replacement for the
batch mode of legacy Tau-Argus 4.1: same `.arb` batch files, file formats and
outputs, without the GUI.

This is a personal rewrite of the legacy product, started a few years ago and
worked on in on-and-off sprints: the C/C++ solver engine is rebuilt to a modern
toolchain on an open-source solver, and the Java/Swing desktop front-end is
replaced by a headless Python CLI.

The project has two parts:

- **tauargus-engine** (`engine/`): the C/C++ libraries that do the work, built
  against the open-source [HiGHS](https://github.com/ERGO-Code/HiGHS) solver.
  The legacy CPLEX, XPRESS and SCIP backends are gone.
- **pytauargus** (`bindings/python/`): a DataFrame API (`protect()`), batch
  API and `tauargus` command-line tool that link those libraries. Wheels
  bundle HiGHS and the engine.

## Relationship to the original Tau-Argus

This is the original Tau-Argus solver code, not a reimplementation:

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

## Install

From [PyPI](https://pypi.org/project/pytauargus/):

```bash
pip install pytauargus          # into the current environment
uv tool install pytauargus      # or: pipx install pytauargus (isolated, puts `tauargus` on PATH)
tauargus --version
```

Use it from Python as well:

```python
from pytauargus.engine import run_batch

run_batch("mybatch.arb")
```

Wheels bundle HiGHS and the engine libraries, so nothing else needs installing.
They are built for Python 3.10-3.13 on:

| Platform | Architecture |
|----------|--------------|
| macOS    | arm64 (Apple Silicon) |
| Linux (manylinux_2_28) | x86_64, aarch64 |
| Windows  | x64 |

Intel Macs and Windows ARM are not built, and there is no source
distribution; on those platforms see [Building from source](#building-from-source).
The same wheels are attached to each
[GitHub Release](https://github.com/trygu/tauargus-engine/releases).

## Cloud native

Built to run unattended in containers, CI and batch services:

- **Headless:** no GUI, no display, no interactive prompts.
- **Self-contained:** one `pip install`; the solver (HiGHS) and native libraries
  are bundled in the wheel. No licensed solver, license server, system packages
  or Windows registry.
- **Stateless:** input and output are plain files in the working directory;
  scratch files go to the system temp directory.
- **Scriptable:** success is exit code 0; errors go to stderr with a non-zero
  exit code.
- **Portable:** wheels for Linux (manylinux_2_28, so any glibc 2.28+ image such
  as `python:3.x-slim`), macOS arm64 and Windows x64.

A ready-made image is published to GitHub Container Registry with each release
(linux/amd64 and linux/arm64):

```bash
docker run --rm -v "$PWD":/work ghcr.io/trygu/tauargus-engine run batch.arb
```

Pin a version with `ghcr.io/trygu/tauargus-engine:0.3.0`. To build your own image:

```dockerfile
FROM python:3.12-slim
RUN pip install --no-cache-dir pytauargus
WORKDIR /work
ENTRYPOINT ["tauargus"]
```

## Quick start

### From a DataFrame

The new `protect()` API is on the development branch and awaits the next
release. [Build from source](#building-from-source), then install pandas support
with `uv sync --extra dataframe` from `bindings/python/`.

```python
import pandas as pd
from pytauargus import protect

micro = pd.DataFrame({
    "Region": ["North"] * 6 + ["South"] * 6,
    "Sector": ["Retail"] * 3 + ["Services"] * 3
              + ["Retail"] * 3 + ["Services"] * 3,
    "Turnover": [100., 5., 5., 10., 10., 10., 20., 20., 20., 30., 30., 30.],
})
result = protect(
    micro, ["Region", "Sector"], response="Turnover",
    safety_rules="NK(2,75)", workdir="tauargus_run",
)
table = result.tables[0]
published = table.dataframe()[["Region", "Sector"]].copy()
published["Turnover"] = table.safe()  # primary/secondary suppressed values -> "x"
published.to_csv("protected.csv", index=False)
print(published)
```

`protect()` generates `.asc`, `.rda` and `.arb`, computes the table, applies
OPT suppression by default and returns `TableResult` objects. Dicts of columns,
lists of row dicts and polars DataFrames are accepted too. Pass a nested list
of explanatory variables for multiple tables, or `run=False` to write inputs
without invoking the engine.

`dataframe()` and `unsafe()` include original values for analysis; use `safe()`
for the publication response. Audit is explicit: `result.engine.audit(0)`.
Intermediate files are retained in `result.workdir` for inspection and cleanup.
See the [Python API guide](bindings/python/README.md#dataframe-protection) for
result accessors, per-table options and audit/export details.

### From an existing batch

```bash
tauargus run data/TestRecode.arb
```

## Command-line usage

```bash
tauargus run      mybatch.arb    # parse and execute a batch file
tauargus compute  mybatch.arb    # table computation only
tauargus suppress mybatch.arb    # compute, then apply suppression
tauargus round    mybatch.arb    # compute, then round
tauargus audit    mybatch.arb    # feasibility intervals of suppressed cells
tauargus save     mybatch.arb    # compute, then write tables
tauargus tables   mybatch.arb    # print a table summary
```

`<SOLVER>` tags in a batch file are accepted, but only HiGHS is used; any
other solver name logs a warning and the job continues.

Sample batches and fixtures are in [data/](data). The batch grammar, file
formats and parameters follow the legacy Tau-Argus 4.1 manual, which is bundled
in [docs/](docs).

## Writing batch inputs

Beyond running batches, `pytauargus` can *generate* them. The generator is a
port of [rtauargus](https://github.com/InseeFrLab/rtauargus), the R wrapper, so
it emits the exact file formats the engine reads:

```python
from pytauargus.arb import micro_arb

# writes a .arb batch: two tables (REGION, then SEXE) of the response var CA
micro_arb(
    asc_filename="donnees.asc",
    explanatory_vars=[["REGION"], ["SEXE"]],
    response_var="CA",
    safety_rules=["NK(1,85)", "FREQ(3,10)"],
    suppress="GH(.,100)",
    output_names=["tab1.csv", "tab2.csv"],
    output_type="1",  # CSV; the generator default is SBS/type 4
)
```

`pytauargus.micro.micro_asc_rda` writes fixed-width `.asc` microdata together
with `.rda` metadata. `pytauargus.hrc.write_hrc` produces `.hrc` hierarchy
files, and `pytauargus.rda.write_rda` writes metadata text separately.
`micro_arb` references an existing `.asc` / `.rda` pair; `protect()` coordinates
the complete DataFrame-to-files-to-engine pipeline.

## Example notebooks

[bindings/python/notebooks/](bindings/python/notebooks/) contains three
**executed, output-saved** notebooks that double as API documentation:

1. [`01_quickstart`](bindings/python/notebooks/01_quickstart.ipynb) —
   DataFrame → `protect()` → `TableResult` → masked CSV, then existing batches.
2. [`02_protection_and_audit`](bindings/python/notebooks/02_protection_and_audit.ipynb)
   — OPT/MOD DataFrame protection, explicit audit and masked export; lower-level
   OPT/MOD/RND methods and the ported Intervalle.
3. [`03_generators`](bindings/python/notebooks/03_generators.ipynb) —
   file-only preview (`run=False`), multiple tables and custom generators.

Headless execution (no Jupyter needed):
`uv run --with nbclient --with nbformat --with ipykernel python notebooks/_run.py`
(from `bindings/python/`). See
[the Python README](bindings/python/README.md#example-notebooks) for details.

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

In legacy Tau-Argus this was a **separate program** — `intervalle.exe`, a
standalone Delphi/Pascal executable. Tau-Argus wrote a `.JJ` file, launched the
executable externally, and read the intervals back. The operator had to install
it and keep it on the path, so it was the one part of the pipeline that did not
run in-process.

The rewrite folds it in: the audit logic is ported into the `csp` engine module
(`TauAuditJj`), so it runs in-process over a temporary `.JJ` file and needs
nothing external. Use it three ways:

- **CLI:** `tauargus audit mybatch.arb` — compute, suppress, then report each
  suppressed cell's realized interval and whether it is still unsafe.
- **Python:** `engine.audit(tab)` — returns one row per suppressed cell
  (`cell`, `min`, `max`, `value`, `status`, `unsafe`); the realized bounds are
  also stored on the table and readable via `get_table_cell`.
- **Export:** `tauargus save mybatch.arb --audit --format intermediate` writes
  the legacy INTERMEDIATE (type-5) audit file, including the realized-interval
  columns.

## Architecture

```
.arb batch  ->  tauargus CLI  ->  pytauargus  ->  tauargus-engine (C/C++)  ->  HiGHS
```

The engine is C++11, built from five git submodules under `engine/native/`:

| Module   | Role |
|----------|------|
| `core`   | Data model, Argus/JJ file I/O, SDC engine entry points |
| `csp`    | Cell-suppression LP (branch-and-price) and feasibility audit |
| `hitas`  | Hierarchical table suppression (HiTaS); links `csp` |
| `crp`    | Controlled rounding (iterative rounding, audit) |
| `rounder`| Dispatch layer over `crp` |

```
.
├── engine/      C/C++ engine; CMakeLists.txt is a superbuild of the 5 submodules
├── bindings/
│   └── python/  pybind11 bindings (cpp/), pytauargus package (src/), tests/
├── data/        sample .arb batches and tabular fixtures
├── docs/        legacy Tau-Argus 4.1 manual and design notes
└── src/         legacy Java/Swing front-end (read-only, pending removal)
```

## Building from source

Requirements:

- CMake ≥ 3.16 and a C++11 compiler
- Python 3.10+ and [uv](https://docs.astral.sh/uv/)
- [HiGHS](https://github.com/ERGO-Code/HiGHS) with its CMake package:
  `brew install highs` (macOS), `sudo apt-get install libhighs-dev`
  (Debian/Ubuntu), or [build from source](https://github.com/ERGO-Code/HiGHS#building)

Clone with submodules (`git clone --recurse-submodules`). Build the five native
libraries first; the Python binding links the resulting `engine/build/lib/`
artifacts. CMake finds HiGHS from its installation prefix (set `Highs_DIR`
explicitly if needed):

```bash
# from the repository root
cmake -S engine -B engine/build -DCMAKE_BUILD_TYPE=Release
cmake --build engine/build -j
```

Then build the Python package. scikit-build-core compiles the pybind11 module:

```bash
cd bindings/python
uv sync --extra dataframe                        # environment + extension + pandas
uv build --wheel                                 # dist/pytauargus-*.whl
uv tool install --force dist/pytauargus-*.whl    # puts `tauargus` on PATH
```

Wheels built this way link HiGHS at its install path. The release wheels
bundle it; see [wheels.yml](.github/workflows/wheels.yml).

## Testing

```bash
cd bindings/python
uv sync --extra test
uv run pytest
```

## Acknowledgements

This project stands on the shoulders of the people who developed Tau-Argus,
its statistical methods and native libraries, and the R and Python tools
around it. Their work is the foundation for everything built here.

This is what open source makes possible in official statistics: sharing
methods and tools so that others can inspect, use, and build on them.

### Original Tau-Argus and native libraries

Thank you to **Statistics Netherlands (CBS)** and the original Tau-Argus
contributors: **Peter-Paul de Wolf**,
**Anco Hundepool**, **Sarah Giessing** (GHMITER and audit),
**Juan José Salazar González** (optimisation methods), and **Jordi Castro**
(network solutions and CTA). Historical project contact:
[argus@cbs.nl](mailto:argus@cbs.nl).

| Component | Authors and contributors |
| --- | --- |
| `libtauargus` (core) | Statistics Netherlands and Peter-Paul de Wolf. |
| `CSP` (cell suppression) | Matteo Fischetti, Juan José Salazar González, and M. D. Montes de Oca. |
| `CRP` (controlled rounding) | Juan José Salazar González; historical contact: [jjsalaza@ull.es](mailto:jjsalaza@ull.es). |
| `tauhitas` (modular suppression) | Statistics Netherlands and Peter-Paul de Wolf. |
| `taurounder` (rounding interface) | Statistics Netherlands and Peter-Paul de Wolf. |

We also thank the [HiGHS](https://highs.dev/) developers and contributors for
the open-source LP/MIP solver used by this engine.

### R and Python interfaces

Thank you to [rtauargus](https://github.com/InseeFrLab/rtauargus), developed
at **INSEE / InseeFrLab**, and its authors **Pierre-Yves Berrard**,
**Julien Jamme**, **Nathanaël Rastout**, **Jeanne Pointet**, **Félix Beroud**,
**André-Raymond Socard**, **Wistan Pomel**, and **Clara Baudry**, together
with its contributors. Its metadata, batch and hierarchy generation logic
was ported to `pytauargus`; its `micro_rtauargus()` workflow also informed
the high-level `protect()` pipeline.

Public contacts:

- **Julien Jamme**, author and package maintainer: [julien.jamme@insee.fr](mailto:julien.jamme@insee.fr).
- **Pierre-Yves Berrard**: [pierre-yves.berrard@insee.fr](mailto:pierre-yves.berrard@insee.fr).
- **Nathanaël Rastout**: [nathanael.rastout@insee.fr](mailto:nathanael.rastout@insee.fr).
- **Clara Baudry**: [clara.baudry@insee.fr](mailto:clara.baudry@insee.fr).

Thank you to [PiArgus (`piargus`)](https://github.com/lverweijen/piargus),
by **[Laurent Verweijen (`lverweijen`)](https://github.com/lverweijen)**
and contributors. Its DataFrame-to-table workflow and result API inspired
`TableResult` and its `safe()`, `status()`, `unsafe()` and `dataframe()` accessors.
Public contact: [lauwerund@gmail.com](mailto:lauwerund@gmail.com).

Their work made these interfaces possible and provides valuable examples of
integrating Tau-Argus into reproducible data-processing workflows.

## License

Distributed under the European Union Public Licence (EUPL) v1.2; see
[LICENSE](LICENSE). Tau-Argus is © Statistics Netherlands, with contributions
from the original author teams of each solver module.

This software is provided "AS IS", without warranties or conditions of any
kind, express or implied.
