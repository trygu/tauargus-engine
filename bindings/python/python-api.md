# Python binding (`_tauargus`)

The pybind11 extension `_tauargus`, built from `cpp/` against
`engine/build/lib/` and HiGHS. The
[pytauargus](https://github.com/trygu/pytauargus) package consumes it;
its wheels bundle the extension, the six engine libraries and HiGHS.

Shared conventions for all engine bindings (error-code catalogs,
error containment, solver return semantics, process model, default
differences between the bindings):
[../binding-api.md](../binding-api.md).

## Objects

| C++ class | Python |
|---|---|
| `TauArgus` (core) | `TauArgus` |
| `HiTaSCtrl` (hitas) | `HiTaSCtrl` |
| `RounderCtrl` (rounder) | `RounderCtrl` |
| module level | `audit_jj(jjfile)`, `engine_meta()` |

Methods live on the instance: `t = TauArgus()`, then
`t.set_table(...)`. `clean_all` resets the state of an existing
object.

## Return conventions

- Success flag: `bool`.
- Multiple values: a positional `tuple`; the field order is fixed per
  method and identical to the R binding's named list.
- Status code: `int`; `0` is success unless the row says otherwise
  (some methods report a code instead of a flag).
- Version and error strings: `str`.

## Input guards

Index and count arguments are validated before the native call. A
negative value raises `ValueError` naming the argument (for example
`n_tab must be a non-negative integer, got -1`); index vectors are
checked element by element. Double arguments the native code compares
or stores are checked for NaN/Inf. A guard rejects before any native
code runs.

## GIL

Every native call that blocks releases the GIL for the duration of the
native work, so other Python threads (for example the TUI event loop)
keep running: `explore_file`, `apply_recode`, `do_active_recode`,
`do_recode`, `undo_recode`, `through_table`, `compute_tables` and
`write_jj_format` (core), `audit_jj` (csp), `full_jj` and `a_hitas`
(hitas) and `do_round` (rounder).

## TauArgus (core)

| Method | Args (defaults shown) | Returns |
|---|---|---|
| `version` | none | str |
| `error_string` | `code` | str |
| `clean_all` | none | None |
| `set_in_file_info` | `is_fixed_format`, `separator` | None |
| `explore_file` | `file` | ok, err, line, var |
| `set_number_tab` | `n_tab` | bool |
| `set_number_var` | `n_var` | bool |
| `set_variable` | `index`, `b_pos`, `n_pos`, `n_dec`, `n_missing`, `missing1`, `missing2`, `total_code`, `is_peeper`, `peeper_code1`, `peeper_code2`, `is_categorical`, `is_numeric`, `is_weight`, `is_hierarchical`, `is_holding`, `is_record_key` | bool |
| `set_hierarchical_codelist` | `var`, `file`, `level_string` | status code (0 = success, 1500+ on failure) |
| `set_hierarchical_digits` | `var`, `digits` | bool |
| `get_var_number_of_codes` | `var` | ok, n_codes, n_active_codes |
| `get_var_code` | `var`, `code` | ok, code_type, code_string, is_missing, level |
| `get_var_code_properties` | `var`, `code` | ok, is_parent, is_active, is_missing, level, n_children, code |
| `set_var_code_active` | `var`, `code`, `active` | bool |
| `do_active_recode` | `var` | bool |
| `apply_recode` | none | bool |
| `undo_recode` | `var` | bool |
| `do_recode` | `var`, `recode_data`, `n_missing`, `missing1`, `missing2` | ok, error_type, error_line, error_pos, warning |
| `set_table` | `index`, `explanatory_vars`, `is_frequency`, `response_var`, `shadow_var`, `cost_var`, `cellkey_var`, `ckm_type=""`, `ckm_topk=0`, `lam=0.0`, `max_scaled_cost=0.0`, `peep_var=-1`, `missing_as_safe=False` | bool |
| `set_table_safety` | `index`, `dominance_rule`, `dominance_number`, `dominance_k`, `pq_rule`, `pq_p`, `pq_q`, `pq_n`, `min_freq`, `peep_percentage`, `peep_marge`, `peep_min_freq`, `apply_peep`, `apply_weight`, `weight_on_safety_rule`, `apply_holding`, `apply_zero_rule`, `empty_as_non_structural`, `ns_empty_safety_range`, `zero_safety_range`, `manual_safety_perc`, `cell_holding_freq_safety_perc` | bool |
| `set_table_safety_info` | `index`, `has_max_score`, `dominance_rule`, `dominance_number`, `dominance_perc`, `pq_rule`, `pq_p`, `pq_q`, `pq_n`, `has_freq`, `freq_safety_perc`, `safe_min_rec`, `has_status`, `manual_safety_perc`, `apply_zero_rule`, `zero_safety_range`, `empty_as_non_structural`, `ns_empty_safety_range` | ok, errc |
| `through_table` | none | bool |
| `compute_tables` | none | ok, err, table_index |
| `get_total_table_size` | `tab` | ok, n_cells, size_data_cell |
| `get_minimum_cell_value` | `tab` | ok, min, max |
| `maximum_protection_level` | `tab` | max protection level (int) |
| `get_table_cell_value` | `tab`, `cell` | ok, value |
| `get_table_cell_status` | `tab`, `cell` | ok, status |
| `get_table_cell_protection_levels` | `tab`, `cell` | ok, lower, upper |
| `get_table_cell` | `tab`, `dim_index`, `topn=0` | 22 fields: ok, resp, rresp, cta, ckm, shadow, cost, key, key_nz, freq, status, ms, msw, holding_freq, hms, hnr, peep_cell, peep_holding, lower, upper, rlower, rupper |
| `set_table_cell_cost` | `tab`, `dim_index`, `cost` | bool |
| `set_table_cell_status_dim` | `tab`, `dim_index`, `status` | bool |
| `set_table_cell_status_cell` | `tab`, `cell`, `status` | bool |
| `set_table_cell_protection_levels` | `tab`, `cell`, `lpl`, `upl` | bool |
| `set_protection_levels_dim` | `tab`, `dim_index`, `lpl`, `upl` | bool |
| `set_all_empty_non_structural` | `tab` | bool |
| `set_secondary_jjformat` | `tab`, `file`, `with_bogus=False` | code, n_set_secondary (code 1 = success; 0 or JJF code 4200+ = error) |
| `write_jj_format` | `tab`, `file`, `lower`, `upper`, `with_bogus=False`, `as_perc=False`, `for_rounding=False` | bool |
| `prepare_hitas` | `tab`, `name_param_file`, `name_files_file`, `tau_temp` | bool |
| `set_secondary_hitas` | `tab` | ok, n_set_secondary |
| `run_ghmiter` | `steer_file`, `cells_file`, `result_file`, `minw=1.0`, `maxw=100.0`, `nulw=0.0`, `absbet=0.0`, `qquote=0.0`, `dquote=0.0`, `gewran=1`, `schaez=1`, `mode=0`, `print1=1`, `exact=1` | code, n_set_secondary, message |
| `write_ghmiter_data_cell` | `file`, `tab`, `is_singleton` | bool |
| `write_ghmiter_stuer` | `file`, `end1`, `end2`, `tab` | bool |
| `set_secondary_ghmiter` | `file`, `tab`, `is_singleton=False` | code, n_set_secondary (code 1 = success; GHM code 4000+ = error) |
| `set_secondary_from_hierarchical_ampl` | `file`, `tab` | ok, err |
| `write_hierarchical_table_in_ampl_format` | `ampl_file`, `temp_dir`, `tab`, `max_scale` | ok, err |
| `set_cta_values` | `tab`, `cell`, `org_val`, `cta_val` | ok, n_set_secondary (ok = index/cell in range) |
| `set_realized_lower_and_upper` | `tab`, `cell`, `upper`, `lower` | bool |
| `set_rounded_response` | `file`, `tab` | bool |
| `set_cell_key_values_freq` | `tab`, `ptable_file` | code, min_diff, max_diff (code 1 = success; -1 = bad table index, -9 = ptable read failed) |
| `set_cell_key_values_cont` | `tab`, `ptable_file_cont`, `ptable_file_sep`, `ckm_type`, `top_k`, `include_zeros`, `parity`, `separation`, `m1sqr`, `scaling`, `sigma0`, `sigma1`, `xstar`, `q`, `epsilon`, `mu_c` | status code (1 = success; -1 bad table, -90/-91/-92/-93/-94 ptable read errors) |
| `undo_secondary_suppress` | `tab`, `sort=1` | bool |
| `set_in_table` | `index`, `codes`, `shadow`, `cost`, `response`, `freq`, `max_score_cell`, `max_score_holding`, `status`, `lpl`, `upl` | ok, err, err_var |
| `set_in_code_list` | `var_index`, `codes` | ok, err, ev |
| `set_totals_in_code_list` | `var_index` | ok, err, ev |
| `completed_table` | `index`, `file`, `compute_totals`, `calculated_totals_as_safe=False`, `for_cover_table=False` | ok, err |
| `write_cell_records` | `tab`, `file`, `sbs`, `sbs_level=False`, `suppress_empty=False`, `first_line=""`, `show_unsafe=False`, `embed_quotes=True`, `resp_type=1` | bool |
| `write_csv` | `tab`, `file`, `embed_quotes=True`, `dim_sequence=[]`, `resp_type=1` | bool |

Notes on the core table:

- `get_table_cell` returns all configured scores; `topn` only limits
  the length of the score arrays (`ms`, `msw`, `hms`, `hnr`). On
  failure Python returns a single-element `(False,)` tuple.
- `run_ghmiter` runs the in-process hypercube port (the `ghm` module)
  over the same steering, cells and result file formats as the legacy
  `GHMITER`. It is self-contained, like the legacy program: there is
  no solver in this path, so a GH failure is an engine failure, never
  a solver failure.

## HiTaSCtrl (optimal suppression)

| Method | Args (defaults shown) | Returns |
|---|---|---|
| `version` | none | str |
| `error_string` | `code` | str |
| `set_jj_constants_int` | `name`, `value` | None |
| `set_jj_constants_dbl` | `name`, `value` | None |
| `set_debug_mode` | `debug` | None |
| `full_jj` | `in_file_jj`, `out_file`, `max_time=0`, `ilm_file=""`, `out_dir=""`, `solver="SCIP"` | status code (0 = optimal, 1 = sub-optimal, otherwise a HiTaS error code) |
| `a_hitas` | `pars_file`, `files_file`, `max_time=0`, `ilm_file=""`, `tau_out_dir=""`, `solver="SCIP"`, `single_with_single=False`, `single_with_more=False`, `do_count_bounds=False` | status code (0 = success, otherwise a HiTaS error code) |

`full_jj` and `a_hitas` run the HiGHS MIP with the GIL released. The
legacy port throws raw integer error codes from its file operations;
the binding catches them and returns the value as the status code, so
a caller never sees a raw exception from a file failure.

## RounderCtrl (controlled rounding)

| Method | Args (defaults shown) | Returns |
|---|---|---|
| `version` | none | str |
| `error_string` | `code` | str |
| `set_double_constant` | `variable`, `value` | None |
| `do_round` | `solver`, `in_file`, `base`, `upper_bound=[]`, `lower_bound=[]`, `auditing=0`, `solution_file=""`, `statistics_file=""`, `max_time=0`, `zero_restricted=0`, `log_file=""` | result, max_jump, n_jump, used_time, error_code |

`do_round` returns a 5-tuple, in the same field order as the R
length-5 numeric vector, with the GIL released. `error_code` is a CRP
ErrorTypes value (see
[Error codes](../binding-api.md#error-codes)).
With `log_file`, CRP writes its diagnostics to that file without replacing
process stdout or stderr. The default keeps console output for callers
that do not request a log file.

## Module level

| Function | Args | Returns |
|---|---|---|
| `audit_jj` | `jjfile` | list of `{cell, min, max, value, status, unsafe}` dicts, ascending cell order |
| `engine_meta` | none | dict with `engine_sha` and `highs_version` |

`audit_jj` computes the realized feasibility intervals for the
suppressed cells of the table described by the JJ file (the legacy
intervalle audit), with the GIL released. On failure it raises a
`RuntimeError` carrying the native rc and the file name.

## Python-only methods

The Python binding exposes methods the R binding does not. They cover
the interactive and legacy-GUI paths that the R front-end does not
use:

- core: `maximum_protection_level`, `set_all_empty_non_structural`,
  `run_ghmiter`, `write_ghmiter_data_cell`, `write_ghmiter_stuer`,
  `set_secondary_ghmiter`, `set_secondary_from_hierarchical_ampl`,
  `write_hierarchical_table_in_ampl_format`, `set_cta_values`,
  `undo_secondary_suppress`
- hitas: `version`, `set_jj_constants_int`, `set_jj_constants_dbl`,
  `set_debug_mode`
- rounder: `version`

## Building and testing

Build the six native libraries first (repository root,
[Building from source](../../README.md#building-from-source)), then
compile the extension against them:

```bash
cmake -S bindings/python -B bindings/python/build-ext \
  -DTAUARGUS_PY_PKG_DIR=bindings/python/build-ext/pytauargus \
  -Dpybind11_DIR="$(python3 -c 'import pybind11; print(pybind11.get_cmake_dir())')"
cmake --build bindings/python/build-ext -j
```

Smoke tests in `tests/` run against a locally built engine:

```bash
cd bindings/python
uv run --with pytest --with pybind11 pytest tests -q
```
