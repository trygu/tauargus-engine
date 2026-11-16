# R binding (`tauargusengine`)

The thin R package `tauargusengine` in `r/tauargusengine/`: one
`.Call` wrapper per C++ method. The authoritative export list is
`NAMESPACE`; the roxygen man pages in `man/` are the per-function
reference, and R CMD check runs them as a docs gate in CI. The
self-contained release package is staged by
`scripts/stage-r-package.sh` and released from the
[rtauargus.native](https://github.com/trygu/rtauargus.native) repo.

Shared conventions for all engine bindings (error-code catalogs,
error containment, solver return semantics, process model, default
differences between the bindings):
[../binding-api.md](../binding-api.md).

## Objects

| C++ class | R |
|---|---|
| `TauArgus` (core) | `new_tauargus()`; functions `tauargus_*` |
| `HiTaSCtrl` (hitas) | `new_hitas()`; functions `hitas_*` |
| `RounderCtrl` (rounder) | `new_rounder()`; functions `rounder_*` |
| module level | `audit_jj(jjfile)`, `tauargus_engine_meta()` |

Each method is one exported function; the first argument is always
the object. `tauargus_clean_all(self)` resets the state of an
existing object. R argument names are the short legacy ones
(`resp`, `shadow`, `cost`, `cellkey`, `lam`, `ptable`, ...);
positions and types match the Python names.

## Return conventions

- Success flag: `logical(1)`.
- Multiple values: a named list; the field order is identical to the
  Python tuple.
- Status code: `numeric`; `0` is success unless the row says
  otherwise.
- Version and error strings: `character`.
- On failure of a multi-value call the list is returned in full with
  `ok = FALSE` and the numeric fields zero, except where the binding
  signals an R error (the HiTaS solves, `audit_jj`).

## Input guards

Index and count arguments are validated before the native call; a
negative or non-whole value signals an R error naming the argument.
Double arguments the native code compares or stores are checked for
NaN/Inf. A guard rejects before any native code runs.

## TauArgus (core)

| Method | Args (defaults shown) | Returns |
|---|---|---|
| `tauargus_version` | none | str |
| `tauargus_error_string` | `code` | str |
| `tauargus_clean_all` | none | None |
| `tauargus_set_in_file_info` | `is_fixed_format`, `sep` | None |
| `tauargus_explore_file` | `file` | ok, err, line, var |
| `tauargus_set_number_tab` | `n` | bool |
| `tauargus_set_number_var` | `n` | bool |
| `tauargus_set_variable` | `idx`, `b_pos`, `n_pos`, `n_dec`, `n_missing`, `missing_1`, `missing_2`, `total_code`, `is_peeper`, `peeper_code_1`, `peeper_code_2`, `is_categorical`, `is_numeric`, `is_weight`, `is_hierarchical`, `is_holding`, `is_record_key` | bool |
| `tauargus_set_hierarchical_codelist` | `var`, `file`, `lead` | status code (0 = success, 1500+ on failure) |
| `tauargus_set_hierarchical_digits` | `var`, `digits` | bool |
| `tauargus_get_var_number_of_codes` | `var` | ok, n_codes, n_active_codes |
| `tauargus_get_var_code` | `var`, `code` | ok, code_type, code_string, is_missing, level |
| `tauargus_get_var_code_properties` | `var`, `code` | ok, is_parent, is_active, is_missing, level, n_children, code |
| `tauargus_set_var_code_active` | `var`, `code`, `active` | bool |
| `tauargus_do_active_recode` | `var` | bool |
| `tauargus_apply_recode` | none | bool |
| `tauargus_undo_recode` | `var` | bool |
| `tauargus_do_recode` | `var`, `data`, `n_missing`, `m1`, `m2` | ok, error_type, error_line, error_pos, warning |
| `tauargus_set_table` | `index`, `explanatory`, `is_freq`, `resp`, `shadow`, `cost = -1`, `cellkey = -1`, `ckm_type = ""`, `ckm_topk = -1`, `lam = 0`, `max_scaled_cost = 20000`, `peep_var = -1`, `missing_as_safe = FALSE` | bool |
| `tauargus_set_table_safety` | `index`, `dom`, `dom_n`, `dom_k`, `pq`, `pq_p`, `pq_q`, `pq_n`, `min_freq`, `peep_perc`, `peep_marge`, `peep_min_freq`, `apply_peep`, `apply_weight`, `weight_on_safety`, `apply_holding`, `zero_rule`, `empty_as_ns`, `ns_range`, `zero_range`, `manual_perc`, `freq_perc` | bool |
| `tauargus_set_table_safety_info` | `index`, `has_maxscore`, `dom`, `dom_n`, `dom_p`, `pq`, `pq_p`, `pq_q`, `pq_n`, `has_freq`, `freq_perc`, `safe_min_rec`, `has_status`, `manual_perc`, `zero_rule`, `zero_range`, `empty_as_ns`, `ns_range` | ok, errc |
| `tauargus_through_table` | none | bool |
| `tauargus_compute_tables` | none | ok, err, table_index |
| `tauargus_get_total_table_size` | `tab` | ok, n_cells, size_data_cell |
| `tauargus_get_minimum_cell_value` | `tab` | ok, min, max |
| `tauargus_get_table_cell_value` | `tab`, `cell` | ok, value |
| `tauargus_get_table_cell_status` | `tab`, `cell` | ok, status |
| `tauargus_get_table_cell_protection_levels` | `tab`, `cell` | ok, lower, upper |
| `tauargus_get_table_cell` | `tab`, `dim_index`, `topn` | 22 fields: ok, resp, rresp, cta, ckm, shadow, cost, key, key_nz, freq, status, ms, msw, holding_freq, hms, hnr, peep_cell, peep_holding, lower, upper, rlower, rupper |
| `tauargus_set_table_cell_cost` | `tab`, `dim_index`, `cost` | bool |
| `tauargus_set_table_cell_status_dim` | `tab`, `dim_index`, `status` | bool |
| `tauargus_set_table_cell_status_cell` | `tab`, `cell`, `status` | bool |
| `tauargus_set_table_cell_protection_levels` | `tab`, `cell`, `lpl`, `upl` | bool |
| `tauargus_set_protection_levels_dim` | `tab`, `dim_index`, `lpl`, `upl` | bool |
| `tauargus_set_secondary_jjformat` | `tab`, `file`, `with_bogus = FALSE` | code, n_set_secondary (code 1 = success; 0 or JJF code 4200+ = error) |
| `tauargus_write_jj_format` | `tab`, `file`, `lo = 0`, `hi = 1000`, `with_bogus = FALSE`, `as_perc = FALSE`, `for_rounding = FALSE` | bool |
| `tauargus_prepare_hitas` | `tab`, `param`, `files`, `tau_temp` | bool |
| `tauargus_set_secondary_hitas` | `tab` | ok, n_set_secondary |
| `tauargus_set_realized_lower_and_upper` | `tab`, `cell`, `up`, `lo` | bool |
| `tauargus_set_rounded_response` | `file`, `tab` | bool |
| `tauargus_set_cell_key_values_freq` | `tab`, `ptable` | code, min_diff, max_diff (code 1 = success; -1 = bad table index, -9 = ptable read failed) |
| `tauargus_set_cell_key_values_cont` | `tab`, `ptable_file_cont`, `ptable_file_sep`, `ckm_type`, `top_k`, `include_zeros = FALSE`, `parity = FALSE`, `separation = FALSE`, `m1sqr = 0`, `scaling = "linear"`, `sigma0 = 0`, `sigma1 = 0`, `xstar = 0`, `q = 0`, `epsilon = numeric(0)`, `mu_c = 0` | status code (1 = success; -1 bad table, -90/-91/-92/-93/-94 ptable read errors) |
| `tauargus_set_in_table` | `idx`, `codes`, `shadow`, `cost`, `resp`, `freq`, `maxscore`, `maxscore_hold`, `status`, `lpl`, `upl` | ok, err, err_var |
| `tauargus_set_in_code_list` | `var_index`, `codes` | ok, err, ev |
| `tauargus_set_totals_in_code_list` | `var_index` | ok, err, ev |
| `tauargus_completed_table` | `idx`, `file`, `calc_totals = FALSE`, `calc_totals_safe = FALSE`, `for_cover = FALSE` | ok, err |
| `tauargus_write_cell_records` | `tab`, `file`, `sbs = 1`, `sbs_level = FALSE`, `suppress_empty = FALSE`, `first_line = ""`, `show_unsafe = FALSE`, `embed_quotes = FALSE`, `resp_type = 0` | bool |
| `tauargus_write_csv` | `tab`, `file`, `embed_quotes = FALSE`, `dim_seq = numeric(0)`, `resp_type = 0` | bool |

Notes on the core table:

- `get_table_cell` returns all configured scores; `topn` only limits
  the length of the score arrays (`ms`, `msw`, `hms`, `hnr`). On
  failure R returns the full list with `ok = FALSE` and the numeric
  fields zero.

## HiTaSCtrl (optimal suppression)

| Method | Args (defaults shown) | Returns |
|---|---|---|
| `hitas_error_string` | `code` | str |
| `hitas_full_jj` | `in_file_jj`, `out_file`, `max_time = 0`, `ilm_file = ""`, `out_dir = ""`, `solver = "SCIP"` | 0 (optimal) or 1 (sub-optimal); a code above 1 signals an R error |
| `hitas_a_hitas` | `pars_file`, `files_file`, `max_time = 0`, `ilm_file = ""`, `tau_out_dir = ""`, `solver = "SCIP"`, `single_with_single = FALSE`, `single_with_more = FALSE`, `do_count_bounds = FALSE` | 0 on success; a non-zero code signals an R error |

The R binding follows the legacy interactive contract: a failed solve
signals an R error carrying the code and its `hitas_error_string`
translation, instead of returning the code. The R calls block the R
process.

## RounderCtrl (controlled rounding)

| Method | Args (defaults shown) | Returns |
|---|---|---|
| `rounder_error_string` | `code` | str |
| `rounder_set_double_constant` | `variable`, `value` | None |
| `rounder_do_round` | `solver`, `in_file`, `base`, `upper_bound = numeric(0)`, `lower_bound = numeric(0)`, `auditing = 0`, `solution_file = ""`, `statistics_file = ""`, `max_time = 0`, `zero_restricted = 0` | result, max_jump, n_jump, used_time, error_code |

`rounder_do_round` returns a length-5 numeric vector, in the same
field order as the Python 5-tuple. `error_code` is a CRP ErrorTypes
value (see
[Error codes](../binding-api.md#error-codes)).

## Module level

| Function | Args | Returns |
|---|---|---|
| `audit_jj` | `jjfile` | data.frame with columns `cell`, `min`, `max`, `value`, `status`, `unsafe`, ascending cell order |
| `tauargus_engine_meta` | none | named character vector: `engine_sha`, the recorded pin of each native submodule (`submodule_core`, `submodule_csp`, `submodule_hitas`, `submodule_crp`, `submodule_rounder`, `submodule_ghm`) and `highs_version` |

`audit_jj` computes the realized feasibility intervals for the
suppressed cells of the table described by the JJ file (the legacy
intervalle audit). On failure it signals an R error carrying the
native rc and the file name.

## Version and release

`DESCRIPTION` pins the binding version to the release-train version
(the smoke test checks it, skipped when run from a staged copy). For
release, `scripts/stage-r-package.sh --merge-into` composes the native
layer (this package's `R/`, `src/`, the engine and pinned HiGHS
sources) into the
[rtauargus.native](https://github.com/trygu/rtauargus.native) INSEE
fork, so the release ships one self-contained `rtauargus.native`
package that builds everything from its own sources at install time.

## Installing and testing

```bash
R CMD INSTALL bindings/r/tauargusengine
Rscript bindings/r/tauargusengine/tests/test_binding_smoke.R
```
