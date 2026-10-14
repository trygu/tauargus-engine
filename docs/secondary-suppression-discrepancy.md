# Secondary suppression discrepancy against legacy tau-ARGUS

**Status:** reproduced on published `pytauargus` 0.5.2; the cost
defaults are identified as a major cause; three residual cell
differences remain with explicit legacy-equivalent costs. Main
hypothesis (unconfirmed): Modular's integer weight scaling makes
different costs indistinguishable in the optimization. No library
fix has been made.
**Recorded:** 2026-10-14.

## Report

Oyvind ran `uvx --from pytauargus-tui tauargus-tui` and executed an
existing `.arb` batch with Modular and manually specified primary
suppression. He compared 1631 cells with unique response values out of
1665 total cells.

| Legacy status / our status | M: secondary | S: safe | U: primary |
|---|---:|---:|---:|
| B: primary in this selection | 0 | 0 | 425 |
| D: secondary | 164 | 51 | 0 |
| V: safe | 38 | 953 | 0 |

There are 89 secondary-suppression differences in this selection: 51
legacy-only and 38 ours-only. Legacy has 215 secondaries and ours 202
in the selection. All 425 selected primaries agree.

## Test setup received and reproduction completed

`argus_files_orig.zip` contains `sy1.arb`, `sy1.tab`, `sy1.rda`,
`sy1.hst`, `sy1.csv`, `sy1.txt`, `sy1.html`, and `sy1_apriori.html`.

The two referenced hierarchy files are absent: `hier1_df_unif.hrc` and
`hier2_df_unif.hrc`. Local hierarchies were reconstructed from the
coding trees in `sy1.html`. The trees contain 110 and 14 codes, plus
total T. Obtain the original hierarchy files to confirm the
reconstruction.

Windows paths were replaced with local Unix paths in copies. Original
input files and reference output were retained unchanged. Output names
were changed to avoid overwriting the reference CSV.

The original HTML report confirms:

- tau-ARGUS 4.2.5 (Build 2), ArgusLib 4.0.4 (Build 1).
- libTauHiTaS 4.3.2.1, CPLEX 12.5.0.0.
- Modular (HITAS), Salazar solution.
- MOD(1,5,0,0,0): five minutes per subtable; the three additional
  options are disabled.
- MAN(10) plus apriori status and protection levels.
- The report's cost values equal response values.
- Full table: 1665 cells, 429 manual primaries, 221 secondaries,
  1003 safe, 12 empty.

The batch has no `<SOLVER>` command. The HTML report resolves the
previously unknown solver.

Executed on Linux with Python 3.12.14 and published PyPI
`pytauargus==0.5.2`. This does not test the latest GitHub development
revision.

## Confirmed findings

### 1. Exact reproduction of the reported discrepancy

The original `SPECIFYTABLE` line, with only paths adjusted, produces
exactly the cross-tab reported above for the 1631-cell selection.
Across all 1653 non-empty cells, there are 93 status differences and
zero response-value differences when comparing the native table via
INTERMEDIATE output.

Dimension codes were matched using stable keys after removing
hierarchy padding asterisks from our output. Keys were checked for
uniqueness. All reference keys matched.

### 2. Different cost defaults

Original batch:

```
<SPECIFYTABLE> "var1""var2"|"response"||
```

The Python run interprets omitted cost as native cost variable `-1`
(frequency), with lambda `0` (logarithm). The total cell reports cost
`9.210440366976517 = log(10000 + 1)`. The original HTML reports the
response as cost, including its cost totals by cell status.

Controlled diagnostic batch:

```
<SPECIFYTABLE> "var1""var2"|"response"||"response",1
```

With explicit response cost and exponent `1`, the total cell cost
becomes `9043500512`, matching its response. The selected-cell
discrepancy falls from 89 to 3. This changes both the cost variable
and the exponent; it is a batch workaround, not a code fix.

| Legacy status / our status, explicit response cost | M | S | U |
|---|---:|---:|---:|
| B | 0 | 0 | 425 |
| D | 213 | 2 | 0 |
| V | 1 | 990 | 0 |

Full-table results:

| Run | Primary | Secondary | Safe | Empty | Differences from legacy, non-empty cells |
|---|---:|---:|---:|---:|---:|
| Legacy CPLEX | 429 | 221 | 1003 | 12 | reference |
| HiGHS, omitted cost/exponent | 429 | 204 | 1020 | 12 | 93 |
| HiGHS, explicit response cost/exponent 1 | 429 | 220 | 1004 | 12 | 3 |

Candidate implementation points (verified against `pytauargus`
`src/`): `SpecifyTable.lam`, `_parse_specify_table` in `batch.py`
(omitted cost gives `cost_idx = -1`, omitted lambda gives
`lam = 0.0`), and `_call_set_table` in `engine.py`. Check the legacy
default selection and exponent before changing code. Preserve the
explicit `-1`/`-2`/`-3` cost meanings and explicit lambda values.

### 3. Residual differences

| var1 | var2 | response | Legacy | HiGHS, explicit response cost |
|---|---|---:|---|---|
| C28 | 01 | 3397775 | secondary | safe |
| C28 | 0101 | 214701 | secondary | safe |
| C28 | 05 | 3462699 | safe | secondary |

The sum of secondary response values is `1471468986` in legacy and
`1471319209` in the adjusted run. This is an aggregate final-table
measure, not proof of global optimality or of the cause of the
remaining differences.

### 4. Audit results

Our audit reports `unsafe=False` for all 633 suppressed cells in the
default run and all 649 suppressed cells in the explicit-response-cost
run. This is our implementation's audit, not an independent audit by
legacy tau-ARGUS. The legacy report does not establish the results of
an equivalent audit.

### 5. Separate SBS export issue

The format-4 output produced by `pytauargus` 0.5.2 writes zero
response values for non-empty cells. Native cell values are correct,
and INTERMEDIATE export preserves them. Comparisons therefore use
INTERMEDIATE values and statuses. Investigate the format-4 export
path and its arguments separately; this is not evidence of incorrect
input values in the suppression model.

## Main hypothesis for the residual differences (unconfirmed)

Cost scaling and solution choice inside Modular. The hypothesis is
concrete but not a confirmed explanation.

The hitas port computes the MIP weights for each subtable in
`AMiscFunc.cpp`:

- `AdjustMarginalWeights` (lines 267-312): marginal cells get an added
  weight derived from the largest interior cost and the dimension
  sizes, so marginals cost more than interior cells.
- All costs are then scaled by `fac = MAXWEIGHT / Tab.costs[0]`
  (`ScaleMarginalWeights`, lines 314-330; `MAXWEIGHT` defaults to
  `20000` in `Amyio.cpp:148`).
- Each cell's optimization weight is
  `Tab.weight[m] = (int) ceil(Tab.costs[m])`: the scaled cost rounded
  **up** to an integer.

Consequences, if this hypothesis holds:

- Different original costs can map to the same integer weight, so the
  optimization cannot distinguish them.
- The scaling factor depends on the total cell cost; a small input
  difference changes `fac` and therefore the rounded weights of every
  cell in the subtable.
- The residual aggregate difference is consistent with near-tie
  solutions: the secondary response sums differ by `149777`, about
  0.01 percent of `1471468986`.

Because the weights are computed deterministically from the input
costs, identical input costs should give identical weights and hence
identical subtable models. The residual difference is then either
(a) several equally weighted optimal patterns, with CPLEX and HiGHS
choosing different ones, or (b) a model or computation difference
between the legacy libTauHiTaS 4.3.2.1 and our port. Step 4 below
distinguishes the two cases.

Decision: do not force the same three suppressions until the cause is
known. If the models are identical, accept the differing patterns and
verify cost and protection; if the models or computations differ, fix
the port.

## Comparison caveats from Oyvind

- Different status letters are not themselves suppression
  differences. Use stable dimension-code keys.
- Do not assume a solver change explains differences. Oyvind reports
  identical interval optima across solvers in GaussSuppression and
  tau-ARGUS audit, apart from numerical precision. Distinguish
  objective value, chosen solution, and audit intervals. Models solved
  to documented optimality should have matching objective values
  within tolerance; multiple patterns may share an optimum.
- Do not assume Modular globally optimizes the complete table. Compare
  the first diverging subproblem, and document time limits and
  termination before attributing differences to early stopping.

## Next investigation steps

1. Obtain the original hierarchy files and confirm the reconstruction.
2. Repeat with the current development version before deciding whether
   a fix is still needed.
3. Correct the omitted cost/exponent interpretation against the
   legacy contract. Add a regression using this fixture, checking
   costs before suppression as well as the final result.
4. Locate the first divergent Modular subproblem around C28 with
   identical cost inputs. Compare subtable ordering, solver models,
   the integer weights after scaling and `ceil` rounding (see the
   main hypothesis), optimal objectives, bounds, tolerances, time
   limits, and stop reasons.
5. Audit both final patterns with equivalent settings, and audit a
   fixed identical pattern to test interval calculations
   independently of suppression selection.
6. Investigate the format-4 zero-response export separately.
7. Repeat through the rtauargus fork. The original failed AI-built
   `.exe` attempt remains a separate integration issue.

## Reproduction and evidence

The evidence pack lives outside the repo, in `tauargus-suppression-repro/`
next to the engine checkout: `argus_files_orig.zip` (the user's
original files) plus `rtauargus-examples/` (unchanged original inputs,
local Unix batch/metadata copies, reconstructed hierarchies, result
tables, audit JSON, per-cell differences, a README and
`run_repro.py`).

From its extracted directory:

```
uv run --with pytauargus==0.5.2 python run_repro.py
```

The script rebases local paths, runs both main variants, verifies
response equality and unique keys, and writes the full and selected
cross-tabs. No production source code has been changed.

## Expected deliverable from the implementing agent

A verified default-cost fix if still needed, regression coverage, an
explanation of the three residual differences supported by the first
divergent subproblem, a separately verified format-4 export fix if
still needed, and R verification. State confirmed findings and
hypotheses separately.

Source of truth for legacy Modular behavior:
`docs/tau-argus-4.1-markdown-bundle/` (agent reference, parts I and
II).
