# UI Design — replacing the Java/Swing frontend

Status: **The headless product is shipped; the TUI is being developed on
`tui`.** Navigator, grid, cell details and engine actions exist. The state
contracts below are the agreed target for the next iteration, not a claim
that draft editing, previews or workspace persistence are implemented.

**State decision (2026-10-11): immediate draft edits → explicit solver
preview → accept result → export.** Saving a workspace is a separate action.

## 1. Background

- The legacy product is a Java/Swing desktop app (`src/tauargus/gui/*`,
  `nbproject/`, SWIG bindings). It has been removed from `master`; the `tui`
  branch retains it as a read-only reference for porting behaviour.
- Task 8 was **BLOCKED** on the assumption that an interactive frontend must
  replace Swing first. That assumption is dropped: **deleting Swing does not
  require a 1:1 replacement to exist yet.**
- The rewrite's *product* is a **headless `.arb` batch CLI**
  (`bindings/python/`, entry point `tauargus`). The `Engine`
  (`pytauargus.engine.Engine`) is a clean, importable Python library over the
  pybind11 native core, and `pytauargus.cli` already exposes the full verb
  surface. The TUI is a **thin presentation layer over that same library** —
  it does not reimplement any engine behavior.

## 2. Decision

The headless CLI remains the independently shipped product (Option A).
Option B is the chosen interactive companion and has its own release cadence.

### Option A — Headless CLI (the shipped product)

The product is the headless CLI + batch runner. Interactive needs (spec
authoring, table inspection, suppression tuning) are served by:
- the CLI verbs: `run`, `explore`, `specify`, `compute`, `suppress`, `round`,
  `apriori`, `audit`, `save`, `tables`, `version`;
- machine-readable outputs (CSV, INTERMEDIATE `.tab`, audit rows) that feed
  the example notebooks, spreadsheets, or dashboards;
- structured `logger` output for batch observability.

**Pros:** smallest surface, fastest to a releasable product, no new platform
risk, nothing to keep in sync with the engine.
**Cons:** interactive table inspection and suppression tuning require CLI
round-trips or another presentation layer.

### Option B — Lightweight ANSI terminal UI

A TUI in the OpenCode terminal aesthetic: monospace, minimal chrome,
keyboard-driven, **panes not modal dialogs**. A thin interactive layer over the
`Engine` — not a rewrite.

**Library: `textual`** (decided). It is a pure-Python TUI framework with
widgets, panes, key handling, and live updates — the closest fit to the
OpenCode feel, and it ships a virtualized `DataTable` (so wide tables do not
break the terminal, the main risk with a home-rolled `rich` grid).
`rich` + `prompt_toolkit` is the fallback if we want fewer moving parts, but
it forces us to hand-wire pane layout and focus; `textual` gives that for free.

**Distribution: its own PyPI package, `pytauargus-tui`** (decided). It is a
separate project — its own `pyproject.toml`, version, wheel, and release
cadence — but **lives in this monorepo** (`bindings/tui/`, sibling to
`bindings/python/`) and is developed on its **own branch** while in flight, so:
- the core `pytauargus` wheel stays minimal — `textual` is never a dependency
  of it (no extra, no subcommand in the core `tauargus` CLI);
- the TUI can move (features, breaking UI changes) without bumping the engine
  release;
- `pip install pytauargus-tui` pulls `pytauargus>=<min>` (the native engine +
  CLI) as its only engine dependency.

- Console script: `tauargus-tui` (distinct from the core `tauargus` CLI).
- Depends on: `pytauargus>=0.2.1`, `textual>=0.50`.
- Release: its own tag scheme (e.g. `tui-v*`) + wheel; can reuse the existing
  `wheels.yml` pattern once the layout is proven.

### B.1 Layout

```
┌ tables & vars ┬──────────────────────── grid ────────────────────────┐
│ 1 REGION|CA ▸ │ REGION\CA  R1    R2    R3    TOTAL                   │
│ 2 SEXE  |CA   │  R1        S     U     S     S                       │
│ 3 AGE   |CA   │  R2        U     S     U     U                       │
│             │  R3        S     S     S     S                         │
│ [vars]      │  TOTAL     S     U     S     S                         │
├──────────────┴───────────────────────────────────────────────────────┤
│ cell (R2, R3): value=12  status=U (unsafe_rule)  interval=[4, 30]    │
├──────────────────────────────────────────────────────────────────────┤
│ draft r12 · 3 edits · preview outdated · accepted r9 · s=preview OPT │
└──────────────────────────────────────────────────────────────────────┘
```

- **Left pane** — table navigator (one row per `specify_table`) + the
  explanatory/response vars and active safety rules for the selected table.
- **Center pane** — the computed table as a `DataTable`: rows = one
  explanatory var's codes, columns = another's. Remaining dimensions select
  a slice. Each cell shows the value and is colored by status category;
  pending edits have a separate marker rather than a solver-result colour.
- **Detail pane** (bottom) — the selected cell's value, full status name, and
  — when the table has been audited — its realized feasibility interval.
- **Log/status line** (bottom) — the engine's `logger` stream + a one-line
  keymap hint, draft revision, pending edit count, preview freshness and
  accepted revision. Busy state remains visible during engine work.

Status color = the `_status_symbol` category from `pytauargus.engine`
(`S` safe=green, `U` unsafe=red, `P` protect_manual=cyan, `M`
secondary_unsafe=yellow, `E` empty=dim). Full status names come from
`pytauargus.cli._STATUS_NAMES` (1–14).

### B.2 Feature → API map

Native operations use the existing Python engine and batch semantics. Draft
editing, history, revisions and workspace persistence belong to the TUI;
they do not require a solver or batch-parser implementation in the widgets.

| Pane / action | Real `pytauargus` surface |
|---------------|---------------------------|
| Open data | `open_microdata(data_file, Metadata)` (or `run_batch(arb)` for a ready batch) |
| Table navigator | `eng._n_tables`, `eng._tables[i]` (`spec.exp_vars`, `spec.resp_var`, safety rules) |
| Grid cell value + status | `eng._tau.get_table_cell(tab, dim, 0)` → `res[1]`=value, `res[10]`=status; size via `get_total_table_size`, bounds via `get_minimum_cell_value` |
| Detail: feasibility interval | `eng.audit(tab)` → rows `{cell,min,max,value,status,unsafe}` |
| Preview suppress / round | On the scratch run: `eng.suppress(Suppress(kind="OPT"/"MOD"/"RND", tab_no=…, rnd_base=…))` |
| Apply draft cell instructions | On the scratch run: `eng.apply_apriori(Apriory(…))`; preserve engine validation and trivial-level expansion |
| Accept result | TUI promotes an eligible preview; no solver call or file export |
| Save workspace | TUI persists a versioned recipe and accepted-result references; no native-object serialization |
| Export accepted result | `eng.write_table(WriteTable(…))`, `eng.write_intermediate_table(tab, path, with_audit=True)` from that result's retained run |
| Emit replay files | Existing batch generation + apriori files encode the recipe; output requests are explicit |

### B.3 Legacy behaviour and the state decision

The Java UI separated cell editing from solving:

- Cell status buttons called `SetTableCellStatus` immediately and refreshed
  the cell; they did not run secondary suppression after each edit.
- The separate Suppress/Round action invoked the chosen method. Most status,
  cost and recoding edits were disabled after protection until Undo.
- Undo called `UndoSecondarySuppress` and cleared method, audit and output
  bookkeeping. This is a specific protection reset, not general undo/redo
  for cell edits, settings, recoding and file operations.
- Save Table exported the current table. Write Batch File was a separate
  operation, not a journal recording each interactive edit.

Sources inspected at `3c8e2ab`:
[cell edits](https://github.com/trygu/tauargus-engine/blob/3c8e2ab9b50e59e312e7f1b7593cb5648884f699/src/tauargus/gui/PanelTable.java#L1581-L1605),
[editing restrictions](https://github.com/trygu/tauargus-engine/blob/3c8e2ab9b50e59e312e7f1b7593cb5648884f699/src/tauargus/gui/PanelTable.java#L2261-L2312),
[suppression undo](https://github.com/trygu/tauargus-engine/blob/3c8e2ab9b50e59e312e7f1b7593cb5648884f699/src/tauargus/service/TableService.java#L86-L104),
[batch output](https://github.com/trygu/tauargus-engine/blob/3c8e2ab9b50e59e312e7f1b7593cb5648884f699/src/tauargus/gui/DialogWriteBatchFile.java#L341-L399).
The [legacy manual](tau-argus-4.1-markdown-bundle/tau-argus-4.1-agent-reference.md)
defines status changes, apriori instructions and the solve/audit/export workflow.

**Decision:** retain the separation between editing and solving, with an
explicit draft, preview and accepted result. Cell edits give immediate
feedback; solver work is batched on an explicit Preview command. Automatic
solver runs on every keystroke are not the default. Accepting a preview and
saving/exporting files are distinct operations.

### B.4 Authoritative state

The mutable native engine is a derived execution object. The session owns:

1. **Draft recipe:** input/metadata/hierarchy references, table definitions,
   rules, cell instructions, method parameters and execution scope. Each
   semantic edit advances a revision and enters undoable command history.
2. **Preview result:** a candidate produced from a frozen recipe revision.
   It records the exact input identities, parameters, engine version, run
   outcome, resulting cells, comparison basis and any audit findings.
3. **Accepted result:** the result the operator chose to keep. It remains
   intact while another draft or preview is being explored. An accepted
   result is not a claim that acceptance itself proves confidentiality.

An engine run may mutate its own tables, but its recipe and completed result
are fixed. Accept promotes the already computed candidate; it does not run
the optimiser again. A failed run cannot replace the accepted result.

Use separate facts for `draft_changed_since_accept`, workspace changes not
yet saved, preview freshness and job state. One `dirty` flag cannot represent
all of these. There may be an accepted result while a newer draft is dirty
and a preview job is running.

**Cell identity:** table definition identity + ordered variable names and
complete categorical code tuple. Preserve codes as strings, including spaces
and leading zeros. Screen coordinates and native cell indices are display/run
details. Recoding or hierarchy changes require revalidating instruction
targets; do not silently attach old edits to a different cell.

**Intent versus outcome:** store operator instructions separately from the
solver's resulting statuses. Distinguish require suppression (`U`), override
as safe (`S`), retain from secondary suppression (`P`), cost (`C`) and
protection distances (`PL`). In legacy terminology, "protected" means a cell
may not be selected for secondary suppression. It does not mean hide it.
Use existing apriori validation, including equivalent trivial levels; do not
infer confidentiality or implement status-transition rules in the widgets.

### B.5 Editing, preview, acceptance and audit

| Action | State contract |
| --- | --- |
| Edit a cell, rule or method parameter | Update draft + visible pending changes immediately; no solver run or mutation of the accepted run |
| Preview (`s` for OPT, `r` for RND; MOD through method selection) | Freeze the recipe and run all pending instructions together on a scratch session |
| Accept preview | Promote an eligible completed result for the current draft revision and scope; no export |
| Undo / redo edit | Reverse / replay draft commands; advance revision and invalidate preview eligibility |
| Discard preview | Drop the candidate, keeping the draft and accepted result |
| Save workspace | Persist draft/settings and accepted-result references, independently of solving |
| Export (`o`) | Write the explicitly identified accepted result; never silently use the draft or an outdated preview |

Cell instruction commands are distinct from table-level Preview. Do not
silently reinterpret the same action as a cell toggle or a solver run based
only on focus. A separate pending marker distinguishes edits from computed
primary/secondary statuses. Show the before/after cell changes, per-status
counts and relevant response/cost effects, alongside method outcome and scope.
Label comparisons with their basis: rule-derived baseline or last accepted
result. A method preference/cell override alone is not a solved preview.

Each edit makes the previous preview ineligible for acceptance. Old results
can remain visible for comparison, clearly labelled with their revision.
Reverting an edit still advances revision; reusing a cached result requires
matching the complete recipe and input identities, not merely a cell count.

Audit belongs to one result and revision. Show it only for that result,
including success/failure and exact/partial disclosure findings. An audit of
the accepted result can remain available while editing a draft, but cannot
appear as the audit of the draft or a later preview. Grid/audit caches must
include result identity and be invalidated accordingly.
Enable audit only for methods/scopes supported by the engine's audit operation.

Example: mark ten cells as requiring suppression. All ten marks appear
immediately and can be undone. Preview performs one run with all ten
instructions; the operator inspects its secondary suppressions, optionally
audits, then accepts or discards it. A solver error leaves the ten draft
instructions and the previous accepted result available.

### B.6 Execution and concurrency

Start with a fresh scratch run reconstructed from inputs and the draft.
Optimise this later only with a verified restore/reset contract; legacy
`UndoSecondarySuppress` alone is not general transactional rollback.

The execution recipe separates preparation/compute, apriori instructions,
the chosen protection method and output requests. An imported `.arb` may
already contain `<SUPPRESS>` and `<WRITETABLE>` commands. Do not blindly
append another method to the completed protected table. Preserve preparation
semantics through the existing parser/engine APIs and replace the requested
method for its scope; retain unrelated configuration explicitly. Preview
outputs go to scratch storage, never to the user's configured export paths.
Importing a batch with output requests must make their execution explicit.

Apply the draft instructions before solving. Each comparison starts from
the same preparation recipe; results from an earlier solver run are not
new input constraints. A linked-table scope is one coordinated run and
acceptance unit, rather than independently accepting arbitrary table slices.
Initially support scopes covered by the engine; do not present independent
table solves as coordinated linked protection.

Serialize native jobs initially. Each job carries run ID, draft revision,
input identities and scope. Editing can continue while a frozen job runs,
but a late result cannot overwrite newer state or become eligible for the
newer revision. Native-engine ownership stays with the worker while busy;
the UI reads materialized view data. No concurrent mutation of an accepted
engine or overlapping calls to legacy solver globals.

Show progress and errors without blocking keyboard navigation. Cancellation
must respect the worker's real capabilities: cancelling a thread does not
necessarily stop its native call. Wait for termination before starting the
next native job; isolated worker processes are an option for hard cancellation
and crash containment. Failure/cancellation preserves draft and accepted state.

### B.7 Workspace persistence and output

Use a versioned TUI workspace manifest referencing inputs and result artifacts.
Save logical state, never pickle a native engine or native memory addresses.
Record the recipe, input fingerprints, revisions, scope, method parameters,
engine/build provenance and the actual accepted outcome, including its
selected suppression pattern or rounded values. A replayable recipe does not
guarantee the same optimiser tie-breaking or reproduce the exact old output.

Workspace saving must work before a valid preview exists. Write artifacts
first and replace the manifest atomically so a failed save leaves the last
workspace intact. On reopening, display the saved accepted outcome; rebuild
native execution state when needed. Changed inputs or incompatible versions
require explicit reconciliation before old results are treated as current.
Table/focus/scroll selection may be restored as convenience state; it does
not define the recipe or a cell's identity.

After reopening, reuse saved accepted export artifacts or a verified restore
of the accepted values/statuses through the engine. Do not rerun optimisation
silently to export: a different outcome needs a new preview and acceptance.

Export selects an accepted result and format and records which revision was
written. If the draft differs, make the accepted revision visible; do not
quietly accept or solve as a side effect of export. Inspection/intermediate
artifacts must be identified as such, separately from publication output.
Generated `.arb` + apriori files should replay the recorded operator intent
through the headless engine; they do not substitute for saving the actual
accepted result or its audit evidence.

### B.8 Acceptance checks for the state implementation

- Multiple cell edits update the draft immediately without native mutation
  of the accepted run; one Preview batches the complete instruction set.
- Undo/redo follows logical cell identity across navigation and slices; edits
  made invalid by recoding are reported rather than silently retargeted.
- Repeated OPT/MOD/RND previews reconstruct the preparation recipe instead
  of resuppressing an earlier result; source batch exports are not executed
  silently in the preview directory or the user's output directory.
- Failure/cancellation preserves draft and accepted state. Editing during a
  run rejects late results for the new revision and never overlaps native jobs.
- Accept requires a usable current preview for its full execution scope;
  it does not rerun the solver or export. Discard keeps draft and accepted state.
- Audit/grid views never reuse evidence from another result or revision.
- Save/reopen preserves pending intent and the exact accepted outcome;
  failed writes retain the previous workspace and input changes are detected.
- Export names the accepted revision and reproduces its output; headless
  replay files encode the same recipe without promising identical tie-breaking.

### B.9 Non-goals

- No new solver or batch-parser logic; no native code touched by the TUI.
- No GUI/desktop stack; terminal-only.
- No multi-document workspace manager in the first iteration; one workspace
  can hold the tables and coordinated scopes from one input recipe.
- No 1:1 recreation of Swing screens or per-keystroke automatic solver runs.

## 3. Recommendation

1. **Ship the product as Option A.** The headless CLI is the complete
   product; do not gate it on a UI.
2. **Continue Option B on `tui`, shipped as `pytauargus-tui`.** Implement
   revisioned draft commands and history, isolated previews, acceptance and
   audit ownership, then workspace persistence and replay/export. The current
   navigator/grid/actions are the foundation; the checks in B.8 define done.
3. **Keep the engine independent.** Swing is already removed from `master`;
   the TUI branch's reference copy can be dropped when porting is complete.

## 4. Split-out requirement (Option B)

The UI is **its own task, its own branch, and its own PyPI package**
(`pytauargus-tui`), independent of the native engine port and of core
packaging:
- Branch: `tui` (in this monorepo); source lives in `bindings/tui/`.
- Distribution: `pytauargus-tui` — its own `pyproject.toml`/version/**wheel**;
  depends on `pytauargus>=<min>` + `textual`; console script `tauargus-tui`.
- Does not touch: `engine/native/*`, the batch parser, or solver backends.
  The core `pytauargus` wheel and CLI are unchanged by the TUI.
- Acceptance: drives a real `.arb` end-to-end in the terminal —
  compute → edit draft → preview suppress/round → accept → export — and
  preserves the state contracts in B.8. Workspace saving is independent.
  Runs use the same engine semantics as headless replay; compare recipe,
  constraints and valid outcomes, retaining exact accepted artifacts for export.

The TUI complements the headless product and does not gate its releases.
