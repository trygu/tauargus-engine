# Binding API

Canonical reference for the two native bindings of the engine. The
Python module `_tauargus` (pybind11) and the R package
`tauargusengine` expose the same C++ classes with the same behavior.
For every method that exists in both languages, the tables list both
names, the arguments and the returned fields, so that any consumer
(the pytauargus and rtauargus.native front-ends, or a new one) builds
on a single description.

Sources of truth: `python/cpp/` (`bind_core.cpp`, `bind_hitas.cpp`,
`bind_rounder.cpp`, `bind_csp.cpp`) for Python and
`r/tauargusengine/src/` (`rta_engine.cpp`, `rta_hitas.cpp`,
`rta_rounder.cpp`, `rta_csp.cpp`) for R. The authoritative R export
list is `r/tauargusengine/NAMESPACE`.

## Objects and naming

| C++ class | Python | R |
|---|---|---|
| `TauArgus` (core) | `TauArgus` | `new_tauargus()`, functions `tauargus_*` |
| `HiTaSCtrl` (hitas) | `HiTaSCtrl` | `new_hitas()`, functions `hitas_*` |
| `RounderCtrl` (rounder) | `RounderCtrl` | `new_rounder()`, functions `rounder_*` |
| module level | `audit_jj`, `engine_meta` | `audit_jj`, `tauargus_engine_meta` |

Python: methods on an instance (`t = TauArgus()`, then
`t.set_table(...)`). R: external pointer objects plus one exported
function per method; the first argument is always the object.
`clean_all` / `tauargus_clean_all` resets the state of an existing
object.

## Return conventions

- Success flag: Python `bool`, R `logical(1)`.
- Multiple values: Python returns a tuple (positional), R returns a
  named list. The field order is identical in both languages.
- Status code: Python `int`, R `numeric`. `0` is success; any other
  value is a native error code (see [Error codes](#error-codes)).
- Version and error strings: Python `str`, R `character`.

Multi-value returns start with a success flag `ok`, except where the
native function reports a code instead of a flag:
`set_secondary_jjformat` returns `code, n_set_secondary`,
`set_cell_key_values_freq` returns `ok, min, max` with `ok` being `0`
on success, and (Python only) `set_cta_values` returns
`code, n_set_secondary`.

R argument names are the short legacy ones (`resp`, `shadow`, `cost`,
`cellkey`, `lam`, `ptable`, ...); positions and types match the Python
names given in the tables. Defaults differ in a few places; see
[Default differences](#default-differences).

## TauArgus (core)

| Python | R | Args (Python names, defaults shown) | Returns |
|---|---|---|---|
| `version` | `tauargus_version` | | str |
| `error_string` | `tauargus_error_string` | `code` | str |
| `clean_all` | `tauargus_clean_all` | | None |
| `set_in_file_info` | `tauargus_set_in_file_info` | `is_fixed_format`, `separator` | None |
| `explore_file` | `tauargus_explore_file` | `file` | ok, err, line, var |
| `set_number_tab` | `tauargus_set_number_tab` | `n_tab` | bool |
| `set_number_var` | `tauargus_set_number_var` | `n_var` | bool |
| `set_variable` | `tauargus_set_variable` | `index`, `b_pos`, `n_pos`, `n_dec`, `n_missing`, `missing1`, `missing2`, `total_code`, `is_peeper`, `peeper_code1`, `peeper_code2`, `is_categorical`, `is_numeric`, `is_weight`, `is_hierarchical`, `is_holding`, `is_record_key` | bool |
| `set_hierarchical_codelist` | `tauargus_set_hierarchical_codelist` | `var`, `file`, `level_string` | status code (0 = success, 1500+ on failure) |
| `set_hierarchical_digits` | `tauargus_set_hierarchical_digits` | `var`, `digits` | bool |
| `get_var_number_of_codes` | `tauargus_get_var_number_of_codes` | `var` | ok, n_codes, n_active_codes |
| `get_var_code` | `tauargus_get_var_code` | `var`, `code` | ok, code_type, code_string, is_missing, level |
| `get_var_code_properties` | `tauargus_get_var_code_properties` | `var`, `code` | ok, is_parent, is_active, is_missing, level, n_children, code |
| `set_var_code_active` | `tauargus_set_var_code_active` | `var`, `code`, `active` | bool |
| `do_active_recode` | `tauargus_do_active_recode` | `var` | bool |
| `apply_recode` | `tauargus_apply_recode` | | bool |
| `undo_recode` | `tauargus_undo_recode` | `var` | bool |
| `do_recode` | `tauargus_do_recode` | `var`, `recode_data`, `n_missing`, `missing1`, `missing2` | ok, error_type, error_line, error_pos, warning |
| `set_table` | `tauargus_set_table` | `index`, `explanatory_vars`, `is_frequency`, `response_var`, `shadow_var`, `cost_var`, `cellkey_var`, `ckm_type=""`, `ckm_topk=0`, `lam=0.0`, `max_scaled_cost=0.0`, `peep_var=-1`, `missing_as_safe=False` | bool |
| `set_table_safety` | `tauargus_set_table_safety` | `index`, `dominance_rule`, `dominance_number`, `dominance_k`, `pq_rule`, `pq_p`, `pq_q`, `pq_n`, `min_freq`, `peep_percentage`, `peep_marge`, `peep_min_freq`, `apply_peep`, `apply_weight`, `weight_on_safety_rule`, `apply_holding`, `apply_zero_rule`, `empty_as_non_structural`, `ns_empty_safety_range`, `zero_safety_range`, `manual_safety_perc`, `cell_holding_freq_safety_perc` | bool |
| `set_table_safety_info` | `tauargus_set_table_safety_info` | `index`, `has_max_score`, `dominance_rule`, `dominance_number`, `dominance_perc`, `pq_rule`, `pq_p`, `pq_q`, `pq_n`, `has_freq`, `freq_safety_perc`, `safe_min_rec`, `has_status`, `manual_safety_perc`, `apply_zero_rule`, `zero_safety_range`, `empty_as_non_structural`, `ns_empty_safety_range` | ok, errc |
| `through_table` | `tauargus_through_table` | | bool |
| `compute_tables` | `tauargus_compute_tables` | | ok, err, table_index |
| `get_total_table_size` | `tauargus_get_total_table_size` | `tab` | ok, n_cells, size_data_cell |
| `get_minimum_cell_value` | `tauargus_get_minimum_cell_value` | `tab` | ok, min, max |
| `maximum_protection_level` | (Python only) | `tab` | max protection level (int) |
| `get_table_cell_value` | `tauargus_get_table_cell_value` | `tab`, `cell` | ok, value |
| `get_table_cell_status` | `tauargus_get_table_cell_status` | `tab`, `cell` | ok, status |
| `get_table_cell_protection_levels` | `tauargus_get_table_cell_protection_levels` | `tab`, `cell` | ok, lower, upper |
| `get_table_cell` | `tauargus_get_table_cell` | `tab`, `dim_index`, `topn=0` | 22 fields: ok, resp, rresp, cta, ckm, shadow, cost, key, key_nz, freq, status, ms, msw, holding_freq, hms, hnr, peep_cell, peep_holding, lower, upper, rlower, rupper |
| `set_table_cell_cost` | `tauargus_set_table_cell_cost` | `tab`, `dim_index`, `cost` | bool |
| `set_table_cell_status_dim` | `tauargus_set_table_cell_status_dim` | `tab`, `dim_index`, `status` | bool |
| `set_table_cell_status_cell` | `tauargus_set_table_cell_status_cell` | `tab`, `cell`, `status` | bool |
| `set_table_cell_protection_levels` | `tauargus_set_table_cell_protection_levels` | `tab`, `cell`, `lpl`, `upl` | bool |
| `set_protection_levels_dim` | `tauargus_set_protection_levels_dim` | `tab`, `dim_index`, `lpl`, `upl` | bool |
| `set_all_empty_non_structural` | (Python only) | `tab` | bool |
| `set_secondary_jjformat` | `tauargus_set_secondary_jjformat` | `tab`, `file`, `with_bogus=False` | code, n_set_secondary (code 1 = success; 0 or JJF code 4200+ = error) |
| `write_jj_format` | `tauargus_write_jj_format` | `tab`, `file`, `lower`, `upper`, `with_bogus=False`, `as_perc=False`, `for_rounding=False` | bool |
| `prepare_hitas` | `tauargus_prepare_hitas` | `tab`, `name_param_file`, `name_files_file`, `tau_temp` | bool |
| `set_secondary_hitas` | `tauargus_set_secondary_hitas` | `tab` | ok, n_set_secondary |
| `write_ghmiter_data_cell` | (Python only) | `file`, `tab`, `is_singleton` | bool |
| `write_ghmiter_stuer` | (Python only) | `file`, `end1`, `end2`, `tab` | bool |
| `set_secondary_ghmiter` | (Python only) | `file`, `tab`, `is_singleton=False` | code, n_set_secondary (code 1 = success; GHM code 4000+ = error) |
| `set_secondary_from_hierarchical_ampl` | (Python only) | `file`, `tab` | ok, err |
| `write_hierarchical_table_in_ampl_format` | (Python only) | `ampl_file`, `temp_dir`, `tab`, `max_scale` | ok, err |
| `set_cta_values` | (Python only) | `tab`, `cell`, `org_val`, `cta_val` | ok, n_set_secondary (ok = index/cell in range) |
| `set_realized_lower_and_upper` | `tauargus_set_realized_lower_and_upper` | `tab`, `cell`, `upper`, `lower` | bool |
| `set_rounded_response` | `tauargus_set_rounded_response` | `file`, `tab` | bool |
| `set_cell_key_values_freq` | `tauargus_set_cell_key_values_freq` | `tab`, `ptable_file` | code, min_diff, max_diff (code 1 = success; -1 = bad table index, -9 = ptable read failed) |
| `set_cell_key_values_cont` | `tauargus_set_cell_key_values_cont` | `tab`, `ptable_file_cont`, `ptable_file_sep`, `ckm_type`, `top_k`, `include_zeros`, `parity`, `separation`, `m1sqr`, `scaling`, `sigma0`, `sigma1`, `xstar`, `q`, `epsilon`, `mu_c` | status code (1 = success; -1 bad table, -90/-91/-92/-93/-94 ptable read errors) |
| `undo_secondary_suppress` | (Python only) | `tab`, `sort=1` | bool |
| `set_in_table` | `tauargus_set_in_table` | `index`, `codes`, `shadow`, `cost`, `response`, `freq`, `max_score_cell`, `max_score_holding`, `status`, `lpl`, `upl` | ok, err, err_var |
| `set_in_code_list` | `tauargus_set_in_code_list` | `var_index`, `codes` | ok, err, ev |
| `set_totals_in_code_list` | `tauargus_set_totals_in_code_list` | `var_index` | ok, err, ev |
| `completed_table` | `tauargus_completed_table` | `index`, `file`, `compute_totals`, `calculated_totals_as_safe=False`, `for_cover_table=False` | ok, err |
| `write_cell_records` | `tauargus_write_cell_records` | `tab`, `file`, `sbs`, `sbs_level=False`, `suppress_empty=False`, `first_line=""`, `show_unsafe=False`, `embed_quotes=True`, `resp_type=1` | bool |
| `write_csv` | `tauargus_write_csv` | `tab`, `file`, `embed_quotes=True`, `dim_sequence=[]`, `resp_type=1` | bool |

Notes on the core table:

- `get_table_cell` returns all configured scores; `topn` only limits
  the length of the score arrays (`ms`, `msw`, `hms`, `hnr`). On
  failure Python returns a single-element `(False,)` tuple; R
  returns the full list with `ok = FALSE` and the numeric fields
  zero.
- The solver-backed calls (`explore_file`, `do_recode`,
  `compute_tables`, `write_jj_format`) run with the Python GIL
  released, so other threads (for example a TUI event loop) keep
  running. R calls block the R process.

## HiTaSCtrl (optimal suppression)

| Python | R | Args (Python names, defaults shown) | Returns |
|---|---|---|---|
| `version` | (Python only) | | str |
| `error_string` | `hitas_error_string` | `code` | str |
| `set_jj_constants_int` | (Python only) | `name`, `value` | None |
| `set_jj_constants_dbl` | (Python only) | `name`, `value` | None |
| `set_debug_mode` | (Python only) | `debug` | None |
| `full_jj` | `hitas_full_jj` | `in_file_jj`, `out_file`, `max_time=0`, `ilm_file=""`, `out_dir=""`, `solver="SCIP"` | status code (0 = success, otherwise a HiTaS error code) |
| `a_hitas` | `hitas_a_hitas` | `pars_file`, `files_file`, `max_time=0`, `ilm_file=""`, `tau_out_dir=""`, `solver="SCIP"`, `single_with_single=False`, `single_with_more=False`, `do_count_bounds=False` | status code (0 = success, otherwise a HiTaS error code) |

`full_jj` and `a_hitas` run the HiGHS MIP with the GIL released. The
legacy port throws raw integer error codes from its file operations;
the bindings catch those and return the value as the status code, so
a caller never sees a raw exception from a file failure.

## RounderCtrl (controlled rounding)

| Python | R | Args (Python names, defaults shown) | Returns |
|---|---|---|---|
| `version` | (Python only) | | str |
| `error_string` | `rounder_error_string` | `code` | str |
| `set_double_constant` | `rounder_set_double_constant` | `variable`, `value` | None |
| `do_round` | `rounder_do_round` | `solver`, `in_file`, `base`, `upper_bound=[]`, `lower_bound=[]`, `auditing=0`, `solution_file=""`, `statistics_file=""`, `max_time=0`, `zero_restricted=0` | result, max_jump, n_jump, used_time, error_code |

`do_round` returns a 5-tuple in Python and a length-5 numeric vector
in R, in the same field order. `error_code` is a CRP ErrorTypes value
(see [Error codes](#error-codes)).

## Module level

| Python | R | Args | Returns |
|---|---|---|---|
| `audit_jj` | `audit_jj` | `jjfile` | list of `{cell, min, max, value, status, unsafe}` dicts / data.frame with the same columns, ascending cell order |
| `engine_meta` | `tauargus_engine_meta` | | dict `engine_sha`, `highs_version` / named character vector with the engine revision, each native submodule pin and the HiGHS version |

`audit_jj` computes the realized feasibility intervals for the
suppressed cells of the table described by the JJ file (the legacy
intervalle audit). On failure both languages raise an error
(`RuntimeError` in Python, an R error) carrying the native rc and the
file name.

## Python-only methods

The Python binding exposes methods the R binding does not. They cover
the interactive and legacy-GUI paths that the R front-end does not
use (GHMITER secondary suppression, hierarchical AMPL, CTA, JJ solver
constants, version strings of the two solver controls):

- core: `maximum_protection_level`, `set_all_empty_non_structural`,
  `set_secondary_ghmiter`, `write_ghmiter_data_cell`,
  `write_ghmiter_stuer`, `set_secondary_from_hierarchical_ampl`,
  `write_hierarchical_table_in_ampl_format`, `set_cta_values`,
  `undo_secondary_suppress`
- hitas: `version`, `set_jj_constants_int`, `set_jj_constants_dbl`,
  `set_debug_mode`
- rounder: `version`

## Error codes

Native calls report failures as integer codes. Each binding object
translates the codes of its own library:

| Translator | Catalog | Ranges |
|---|---|---|
| `TauArgus.error_string` / `tauargus_error_string` | core `ErrorCodes` (native/core/src/defines.h), embedded in native/core/src/TauArgusErrorStrings.h | 1000-1027, 1500-1507, 2000-2006, 3000-3003, 4000-4008, 4200-4202, 4225-4232 |
| `HiTaSCtrl.error_string` / `hitas_error_string` | HiTaS catalog (native/hitas/ErrorStrings.txt), including the JJ-routine and solver codes | 5000-5012, 6000-6016, 7000-7003, 8000-8001 |
| `RounderCtrl.error_string` / `rounder_error_string` | CRP `ErrorTypes` (native/crp/src/WrapCRP.h) | 7100-7110 |

- A code missing from a catalog returns `"UnKnown Error (N)"` in all
  three libraries.
- The core catalog is embedded because the legacy
  `TauArgus.properties` (loaded from the working directory) does not
  survive the headless port; a `TauArgus.properties` in the working
  directory still overrides the embedded table.
- The core messages are reconstructed from the `ErrorCodes` enum names
  and their use; the original properties file does not survive in git
  history.
- The 8000-8001 codes (XPress, CPLEX license) are legacy; the engine
  uses HiGHS and never reports them.

## Default differences

Positions and types match; the defaults listed here differ between the
two bindings. Callers that rely on a default should check the side
they use.

| Method | Arg | Python default | R default |
|---|---|---|---|
| `set_table` | cost | required | -1 |
| `set_table` | cellkey | required | -1 |
| `set_table` | ckm_topk | 0 | -1 |
| `set_table` | max_scaled_cost | 0.0 | 20000 |
| `write_jj_format` | lower | required | 0 |
| `write_jj_format` | upper | required | 1000 |
| `write_cell_records` | sbs | required | 1 |
| `write_cell_records` | embed_quotes | True | FALSE |
| `write_cell_records` | resp_type | 1 | 0 |
| `write_csv` | embed_quotes | True | FALSE |
| `write_csv` | resp_type | 1 | 0 |
