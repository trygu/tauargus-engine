# Test data

Each `.arb` batch lives together with the files it references, because
the legacy batch grammar names inputs by bare relative filenames. The
top-level files are the original legacy τ-ARGUS test set, kept flat for
the same reason.

## Layout

| Path | Contents | Used by |
| --- | --- | --- |
| `TestRecode.arb` | Two-table microdata batch (Size×Region, Region×IndustryCode) with recodes | The main engine fixture |
| `tau_testW.asc`, `tau_testW.rda` | Legacy microdata input for the batch above | `test_metadata`, `test_batch`, `test_cli`, `test_intermediate`, `test_audit_engine` |
| `GK.grc`, `IndCode2.grc` | Recode files for the batch above | referenced by `TestRecode.arb` |
| `region.cdl`, `region2.hrc`, `GK.CDL`, `Region.hrc` | Code lists and hierarchies from the legacy set | `region.cdl` and `region2.hrc` are asserted in `test_metadata` and `test_audit_engine` |
| `examples/ex1/` | Published ex1 example, tabular flow with one manually marked cell | `test_table_smoke`, `test_protection_e2e`, the READMEs and `docs/tui.md` |
| `tableinput/` | Pre-aggregated table flow: `TestTable.arb` + `pp.tab` + `pp.rda` + code lists | `test_table_smoke`, `test_audit_engine`, `test_batch`, `test_cover`, `test_metadata` |
| `cellkey/Frequency/`, `cellkey/Magnitude/` | Legacy CKM (cellkey matrix) examples, frequency and magnitude variants | Reference only. CKM is dispatch-only in the headless engine, so no test runs these |
| `vars1to5sampleG.asc`, `vars1to5sampleG.rda` | Legacy sample microdata | Not used by the current test suite; kept as reference data |

`TestRecode.arb` is the fixture behind the `engine` module fixture in
`bindings/python/tests/conftest.py` and drives most engine-level tests
(apriori, audit, intermediate, suppress, solver time limits, GIL
release, CLI) as well as the TUI screenshots in `docs/tui.md`.

The dominance microdata case in `test_protection_e2e.py` is defined
inline in the test file (adapted from the GaussSuppression
magnitude-table vignette, values scaled by ten), so it needs no fixture
files.

## Conventions

- A new fixture gets its own subdirectory under `data/`, with the
  `.arb` that reads it and all of its inputs.
- Engine-generated output (an `out/` directory, solver logs such as
  `*.log`, `*.bra`, `*.heu`, `*.sta`, `CSPlogfile.txt`, `sdc.lp`) and
  TUI workspace manifests (`*.workspace.json`) are gitignored. Tests
  write scratch files to `tmp_path`, never into `data/`.
- Do not commit generated outputs; everything under `data/` should be
  an input a batch or test reads.
