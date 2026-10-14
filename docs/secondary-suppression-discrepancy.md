# Secondary suppression discrepancy against legacy tau-ARGUS

Status: open, blocked on the test setup from the user.
Recorded: 2026-10-14.

## Report

A real user (Oyvind) ran `uvx --from pytauargus-tui tauargus-tui`, executed an
existing `.arb` batch (Modular, manually set primary suppression) and compared
the suppression result with the legacy tau-ARGUS run of the same batch.

Compared: 1631 cells with unique response value (1665 total). Primary
suppression agrees on all 425 manually primary-suppressed cells.
Secondary suppression cross-tab (rows: legacy status, columns: our status):

| legacy \ ours | M: secondary | S: safe | U: primary |
|---|---:|---:|---:|
| B: primary in this selection | 0 | 0 | 425 |
| D: secondary | 164 | 51 | 0 |
| V: safe | 38 | 953 | 0 |

- 89 cells differ in secondary suppression: 51 secondary only in the legacy
  run, 38 secondary only in ours.
- Legacy run: 215 secondary cells. Ours: 202 in this selection.

## Comparison caveats (from the user)

- Status codes must be normalized before comparing; different letters are not
  by themselves a suppression discrepancy.
- Use stable cell keys based on dimension codes in the reproduction, so that
  cells without a unique response value can also be compared.
- Do not assume the solver change (legacy Xpress/CPLEX/free solver to HiGHS)
  explains the difference. The user has seen different solvers give identical
  interval results in GaussSuppression and in tau-ARGUS audit, apart from
  numerical precision. For a model solved to documented optimality the
  objective must match within tolerance, but that does not imply a unique
  suppression pattern: several patterns can share the same cost.

## Investigation plan

1. Reproducible reference: obtain the test setup (`.arb`, data, metadata,
   hierarchies, manual primary marks, reference outputs, logs); record
   program, engine and solver versions; find the legacy `<SOLVER>` choice or
   stored settings if the command does not carry it.
2. Batch interpretation: compare Modular parameters, defaults, time limits,
   costs, protection levels and extra protection rules; identify commands or
   parameters that are ignored or translated differently.
3. Compare engine inputs before secondary suppression: cell values, dimension
   codes, hierarchies, additive relations, primary status, cell bounds and
   costs, for all cells with stable keys.
4. First divergence in Modular: map subtable order, the models sent to the
   solver and the results written back; compare at the first subproblem where
   the runs diverge, before the difference propagates. Do not assume the whole
   Modular run finds a global optimum for the whole table.
5. Document the optimization: objective values, solution status, available
   bounds, optimality gap, tolerances, run time and stop reasons. If possible,
   solve the same diverging subproblem with both solvers and a generous time
   limit. Time limits and incomplete optimization must be documented with
   stop reasons and solution status before they are cited as the cause.
6. Protection and quality: audit each final pattern with identical
   preconditions; compare achieved intervals against the requirements, the
   number of secondary suppressions and the total cost. Different patterns can
   give different intervals; the point is whether both meet the same
   protection requirements. Also audit one identical fixed suppression
   pattern to test the interval computation itself.
7. Root cause before conclusion: distinguish input, batch interpretation,
   parameter differences, algorithm implementation, early stopping, numerics
   and multiple optimal solutions. Do not conclude "solver difference" without
   concrete evidence.
8. Regression test and R verification: run the setup through the rtauargus
   fork (the user's comparison setup is in R). Test manual primary
   suppression, protection requirements, relevant costs and result files.
   Require an identical pattern if the reference is unambiguous or a
   documented rule makes it necessary; otherwise test the properties the
   solution must satisfy.

## Expected deliverable

A reproduction command, versions and settings, a per-cell comparison, the
first documented divergence in the run, and a justified causal explanation.
State what is confirmed and what is still a hypothesis, and which concrete
change or test is needed next.

## Open items / blocked on

- Test setup (`.arb`, data, reference output) requested, not yet received.
- Legacy solver and version used by the user: unknown.
- Kept separate: an AI-built `.exe` attempt by the user produced no result
  CSV; that is a distinct integration problem, not part of the suppression
  difference.

Source of truth for legacy Modular behavior:
`docs/tau-argus-4.1-markdown-bundle/` (agent reference, part I and II).
