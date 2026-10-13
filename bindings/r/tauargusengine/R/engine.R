# R wrappers for the TauArgus core object (src/rta_engine.cpp).
#
# Each function is a thin passthrough to a registered .Call routine. The
# first argument `self` is always the external pointer returned by
# new_tauargus(). Scalar numeric arguments may be integer or double; strings
# are character(1) (NULL is accepted where the native side has an empty
# default).

#' Create a new TauArgus engine object
#'
#' @return An external pointer to a C++ `TauArgus` instance (finalized
#'   automatically when garbage collected).
#' @export
new_tauargus <- function() .Call(rta_tauargus_new)

#' Engine version string
#' @param self TauArgus object (see [new_tauargus()])
#' @export
tauargus_version <- function(self) .Call(rta_tau_version, self)

#' Human-readable text for a native error code
#' @param self TauArgus object
#' @param code Error code (numeric)
#' @export
tauargus_error_string <- function(self, code)
  .Call(rta_tau_error_string, self, code)

#' Reset the engine to a clean state
#' @param self TauArgus object
#' @export
tauargus_clean_all <- function(self) .Call(rta_tau_clean_all, self)

#' Describe the microdata input file format
#' @param self TauArgus object
#' @param is_fixed_format logical; fixed-width layout
#' @param sep Field separator ("" when fixed format)
#' @export
tauargus_set_in_file_info <- function(self, is_fixed_format, sep)
  .Call(rta_tau_set_in_file_info, self, is_fixed_format, sep)

#' Declare the number of input variables
#' @param self TauArgus object
#' @param n Number of variables
#' @export
tauargus_set_number_var <- function(self, n)
  .Call(rta_tau_set_number_var, self, n)

#' Declare the number of output tables
#' @param self TauArgus object
#' @param n Number of tables
#' @export
tauargus_set_number_tab <- function(self, n)
  .Call(rta_tau_set_number_tab, self, n)

#' Declare one input variable (from the .rda metadata)
#' @param self TauArgus object
#' @param idx Variable index (1-based)
#' @param b_pos Start position (fixed format)
#' @param n_pos Field width (fixed format)
#' @param n_dec Number of decimals
#' @param n_missing Number of missing value codes
#' @param missing_1 First missing code
#' @param missing_2 Second missing code
#' @param total_code Total (..) code
#' @param is_peeper logical
#' @param peeper_code_1 First peeper code
#' @param peeper_code_2 Second peeper code
#' @param is_categorical logical
#' @param is_numeric logical
#' @param is_weight logical
#' @param is_hierarchical logical
#' @param is_holding logical
#' @param is_record_key logical
#' @export
tauargus_set_variable <- function(self, idx, b_pos, n_pos, n_dec, n_missing,
                                  missing_1, missing_2, total_code,
                                  is_peeper, peeper_code_1, peeper_code_2,
                                  is_categorical, is_numeric, is_weight,
                                  is_hierarchical, is_holding,
                                  is_record_key) {
  .Call(rta_tau_set_variable, self, idx, b_pos, n_pos, n_dec,
            n_missing, missing_1, missing_2, total_code, is_peeper,
            peeper_code_1, peeper_code_2, is_categorical, is_numeric,
            is_weight, is_hierarchical, is_holding, is_record_key)
}

#' Read a hierarchical code list for a variable
#' @param self TauArgus object
#' @param var Variable index
#' @param file Code list file
#' @param lead Leading character convention
#' @return 1 on success, a 1500+ error code on failure
#' @export
tauargus_set_hierarchical_codelist <- function(self, var, file, lead)
  .Call(rta_tau_set_hierarchical_codelist, self, var, file, lead)

#' Declare the number of digits per hierarchy level
#' @param self TauArgus object
#' @param var Variable index
#' @param digits Numeric vector of digits per level
#' @export
tauargus_set_hierarchical_digits <- function(self, var, digits)
  .Call(rta_tau_set_hierarchical_digits, self, var, digits)

#' Scan the microdata file and verify the declared layout
#' @param self TauArgus object
#' @param file Microdata file
#' @return List: ok (logical), err, line, var
#' @export
tauargus_explore_file <- function(self, file)
  .Call(rta_tau_explore_file, self, file)

#' Declare one output table
#' @param self TauArgus object
#' @param index Table index (1-based)
#' @param explanatory Numeric vector of explanatory variable indices (0 = none)
#' @param is_freq logical; frequency table
#' @param resp Response variable index (0 = none)
#' @param shadow Shadow variable index (-1 only for frequency tables;
#'   otherwise a numeric variable, typically the response variable)
#' @param cost Cost variable index (0 = none)
#' @param cellkey Cell key variable index (-1 = none)
#' @param ckm_type CKM type ("", "R", "K")
#' @param ckm_topk CKM k
#' @param lam Lambda (CKM)
#' @param max_scaled_cost Max scaled cost
#' @param peep_var Peeper variable index (-1 = none)
#' @param missing_as_safe logical
#' @export
tauargus_set_table <- function(self, index, explanatory, is_freq, resp,
                               shadow, cost = -1, cellkey = -1, ckm_type = "",
                               ckm_topk = -1, lam = 0, max_scaled_cost = 20000,
                               peep_var = -1, missing_as_safe = FALSE) {
  .Call(rta_tau_set_table, self, index, explanatory, is_freq, resp,
            shadow, cost, cellkey, ckm_type, ckm_topk, lam, max_scaled_cost,
            peep_var, missing_as_safe)
}

#' Declare the safety parameters of one table
#' @param self TauArgus object
#' @param index Table index
#' @param dom logical; domain check
#' @param dom_n Numeric vector (domain variable indices)
#' @param dom_k Numeric vector (domain k)
#' @param pq logical
#' @param pq_p Numeric vector
#' @param pq_q Numeric vector
#' @param pq_n Numeric vector
#' @param min_freq Numeric vector
#' @param peep_perc Numeric vector
#' @param peep_marge Numeric vector
#' @param peep_min_freq Numeric vector
#' @param apply_peep logical
#' @param apply_weight logical
#' @param weight_on_safety logical
#' @param apply_holding logical
#' @param zero_rule logical
#' @param empty_as_ns logical
#' @param ns_range Numeric
#' @param zero_range Numeric
#' @param manual_perc Numeric
#' @param freq_perc Numeric vector
#' @export
tauargus_set_table_safety <- function(self, index, dom, dom_n, dom_k, pq,
                                      pq_p, pq_q, pq_n, min_freq, peep_perc,
                                      peep_marge, peep_min_freq, apply_peep,
                                      apply_weight, weight_on_safety,
                                      apply_holding, zero_rule, empty_as_ns,
                                      ns_range, zero_range, manual_perc,
                                      freq_perc) {
  .Call(rta_tau_set_table_safety, self, index, dom, dom_n, dom_k, pq,
            pq_p, pq_q, pq_n, min_freq, peep_perc, peep_marge,
            peep_min_freq, apply_peep, apply_weight, weight_on_safety,
            apply_holding, zero_rule, empty_as_ns, ns_range, zero_range,
            manual_perc, freq_perc)
}

#' Declare table-level safety info for a table-input (tabular data) table
#' @param self TauArgus object
#' @param index Table index
#' @param has_maxscore logical
#' @param dom logical
#' @param dom_n Numeric vector
#' @param dom_p Numeric vector
#' @param pq logical
#' @param pq_p Numeric vector
#' @param pq_q Numeric vector
#' @param pq_n Numeric vector
#' @param has_freq logical
#' @param freq_perc Numeric
#' @param safe_min_rec Numeric
#' @param has_status logical
#' @param manual_perc Numeric
#' @param zero_rule logical
#' @param zero_range Numeric
#' @param empty_as_ns logical
#' @param ns_range Numeric
#' @return logical \code{TRUE} on success (failures can be translated with
#'   \code{tauargus_error_string}).
#' @export
tauargus_set_table_safety_info <- function(self, index, has_maxscore, dom,
                                           dom_n, dom_p, pq, pq_p, pq_q,
                                           pq_n, has_freq, freq_perc,
                                           safe_min_rec, has_status,
                                           manual_perc, zero_rule,
                                           zero_range, empty_as_ns,
                                           ns_range) {
  .Call(rta_tau_set_table_safety_info, self, index, has_maxscore, dom,
            dom_n, dom_p, pq, pq_p, pq_q, pq_n, has_freq, freq_perc,
            safe_min_rec, has_status, manual_perc, zero_rule, zero_range,
            empty_as_ns, ns_range)
}

#' End the declaration phase for table input (tabular data flow)
#' @param self TauArgus object
#' @export
tauargus_through_table <- function(self)
  .Call(rta_tau_through_table, self)

#' Compute all declared tables from the microdata
#' @param self TauArgus object
#' @return List: ok (logical), err, table_index
#' @export
tauargus_compute_tables <- function(self)
  .Call(rta_tau_compute_tables, self)

#' Total size of a computed table
#' @param self TauArgus object
#' @param tab Table index
#' @return Numeric(2): number of cells, table size
#' @export
tauargus_get_total_table_size <- function(self, tab)
  .Call(rta_tau_get_total_table_size, self, tab)

#' Value of one cell of a computed table
#' @param self TauArgus object
#' @param tab Table index
#' @param cell Cell index
#' @export
tauargus_get_table_cell_value <- function(self, tab, cell)
  .Call(rta_tau_get_table_cell_value, self, tab, cell)

#' Status of one cell of a computed table
#' @param self TauArgus object
#' @param tab Table index
#' @param cell Cell index
#' @export
tauargus_get_table_cell_status <- function(self, tab, cell)
  .Call(rta_tau_get_table_cell_status, self, tab, cell)

#' Protection levels (lower, upper) of one cell
#' @param self TauArgus object
#' @param tab Table index
#' @param cell Cell index
#' @return Numeric(2): lower, upper
#' @export
tauargus_get_table_cell_protection_levels <- function(self, tab, cell)
  .Call(rta_tau_get_table_cell_protection_levels, self, tab, cell)

#' Set the protection levels of a table cell by cell index
#' @param self TauArgus object
#' @param tab Table index
#' @param cell Cell index
#' @param lpl Lower protection level
#' @param upl Upper protection level
#' @return Logical: TRUE on success
#' @export
tauargus_set_table_cell_protection_levels <- function(self, tab, cell, lpl, upl)
  .Call(rta_tau_set_table_cell_protection_levels, self, tab, cell, lpl, upl)

#' Set the status of a table cell by cell index
#' @param self TauArgus object
#' @param tab Table index
#' @param cell Cell index
#' @param status New cell status
#' @return Logical: TRUE on success
#' @export
tauargus_set_table_cell_status_cell <- function(self, tab, cell, status)
  .Call(rta_tau_set_table_cell_status_cell, self, tab, cell, status)

#' Read a table cell by dimension index (all 22 fields)
#' @param self TauArgus object
#' @param tab Table index
#' @param dim_index Integer vector of per-dimension codes (0-based, length =
#'   number of table dimensions)
#' @param topn Length of the score arrays to return (0 is treated as 1)
#' @return Named list of 22 elements: ok, resp, rresp, cta, ckm, shadow,
#'   cost, key, key_nz, freq, status, ms, msw, holding_freq, hms, hnr,
#'   peep_cell, peep_holding, lower, upper, rlower, rupper. On failure
#'   ok is FALSE and the numeric fields are zero.
#' @export
tauargus_get_table_cell <- function(self, tab, dim_index, topn)
  .Call(rta_tau_get_table_cell, self, tab, dim_index, topn)

#' Set the cost of a table cell by dimension index
#' @param self TauArgus object
#' @param tab Table index
#' @param dim_index Integer vector of per-dimension codes (0-based)
#' @param cost Cell cost
#' @return Logical: TRUE on success
#' @export
tauargus_set_table_cell_cost <- function(self, tab, dim_index, cost)
  .Call(rta_tau_set_table_cell_cost, self, tab, dim_index, cost)

#' Set the status of a table cell by dimension index
#' @param self TauArgus object
#' @param tab Table index
#' @param dim_index Integer vector of per-dimension codes (0-based)
#' @param status New cell status
#' @return Logical: TRUE on success
#' @export
tauargus_set_table_cell_status_dim <- function(self, tab, dim_index, status)
  .Call(rta_tau_set_table_cell_status_dim, self, tab, dim_index, status)

#' Set the protection levels of a table cell by dimension index
#' @param self TauArgus object
#' @param tab Table index
#' @param dim_index Integer vector of per-dimension codes (0-based)
#' @param lpl Lower protection level
#' @param upl Upper protection level
#' @return Logical: TRUE on success
#' @export
tauargus_set_protection_levels_dim <- function(self, tab, dim_index, lpl, upl)
  .Call(rta_tau_set_protection_levels_dim, self, tab, dim_index, lpl, upl)

#' Minimum and maximum cell value of a table
#' @param self TauArgus object
#' @param tab Table index
#' @return Numeric(2): min, max
#' @export
tauargus_get_minimum_cell_value <- function(self, tab)
  .Call(rta_tau_get_minimum_cell_value, self, tab)

#' Number of codes (and NA codes) of a variable
#' @param self TauArgus object
#' @param var Variable index
#' @return Integer(2): n_codes, n_na
#' @export
tauargus_get_var_number_of_codes <- function(self, var)
  .Call(rta_tau_get_var_number_of_codes, self, var)

#' Fetch one code of a variable
#' @param self TauArgus object
#' @param var Variable index
#' @param code Code index
#' @return List: ok, code_type, code_string, is_missing, level
#' @export
tauargus_get_var_code <- function(self, var, code)
  .Call(rta_tau_get_var_code, self, var, code)

#' Fetch properties of one code of a variable
#' @param self TauArgus object
#' @param var Variable index
#' @param code Code index
#' @return List: ok, is_parent, is_active, is_missing, level, n_children, code
#' @export
tauargus_get_var_code_properties <- function(self, var, code)
  .Call(rta_tau_get_var_code_properties, self, var, code)

#' Activate / deactivate one code of a variable (recode preparation)
#' @param self TauArgus object
#' @param var Variable index
#' @param code Code index
#' @param active logical
#' @export
tauargus_set_var_code_active <- function(self, var, code, active)
  .Call(rta_tau_set_var_code_active, self, var, code, active)

#' Apply the active/inactive selection of one variable
#' @param self TauArgus object
#' @param var Variable index
#' @export
tauargus_do_active_recode <- function(self, var)
  .Call(rta_tau_do_active_recode, self, var)

#' Apply all prepared recodes
#' @param self TauArgus object
#' @export
tauargus_apply_recode <- function(self)
  .Call(rta_tau_apply_recode, self)

#' Undo the recode of one variable
#' @param self TauArgus object
#' @param var Variable index
#' @export
tauargus_undo_recode <- function(self, var)
  .Call(rta_tau_undo_recode, self, var)

#' Run a classic DoRecode data file
#' @param self TauArgus object
#' @param var Variable index
#' @param data Recode file
#' @param n_missing Number of missing codes
#' @param m1 First missing code
#' @param m2 Second missing code
#' @return List: ok, error_type, error_line, error_pos, warning
#' @export
tauargus_do_recode <- function(self, var, data, n_missing, m1, m2)
  .Call(rta_tau_do_recode, self, var, data, n_missing, m1, m2)

#' Write a table in CSV format
#' @param self TauArgus object
#' @param tab Table index
#' @param file Output file
#' @param embed_quotes logical
#' @param dim_seq Numeric vector of dimensions to include (empty = identity 0..9)
#' @param resp_type Value type: 0 = raw, 1 = rounded/suppressed, 2 = CTA,
#'   3 = CKM
#' @export
tauargus_write_csv <- function(self, tab, file, embed_quotes = FALSE,
                               dim_seq = numeric(0), resp_type = 0) {
  .Call(rta_tau_write_csv, self, tab, file, embed_quotes, dim_seq,
            resp_type)
}

#' Write a table as cell records
#' @param self TauArgus object
#' @param tab Table index
#' @param file Output file
#' @param sbs SBS format switch
#' @param sbs_level logical
#' @param suppress_empty logical
#' @param first_line First line content
#' @param show_unsafe logical
#' @param embed_quotes logical
#' @param resp_type Value type: 0 = raw, 1 = rounded/suppressed, 2 = CTA,
#'   3 = CKM
#' @export
tauargus_write_cell_records <- function(self, tab, file, sbs = 1,
                                        sbs_level = FALSE,
                                        suppress_empty = FALSE,
                                        first_line = "",
                                        show_unsafe = FALSE,
                                        embed_quotes = FALSE,
                                        resp_type = 0) {
  .Call(rta_tau_write_cell_records, self, tab, file, sbs, sbs_level,
            suppress_empty, first_line, show_unsafe, embed_quotes, resp_type)
}

#' Write a table in JJ format (preparation for HiTaS / rounding)
#' @param self TauArgus object
#' @param tab Table index
#' @param file Output file
#' @param lo Lower bound
#' @param hi Upper bound
#' @param with_bogus logical
#' @param as_perc logical
#' @param for_rounding logical
#' @export
tauargus_write_jj_format <- function(self, tab, file, lo = 0, hi = 1000,
                                     with_bogus = FALSE, as_perc = FALSE,
                                     for_rounding = FALSE) {
  .Call(rta_tau_write_jj_format, self, tab, file, lo, hi, with_bogus,
            as_perc, for_rounding)
}

#' Prepare HiTaS input for one table (OPT: optimal cell suppression)
#' @param self TauArgus object
#' @param tab Table index
#' @param param Parameters file
#' @param files Files file
#' @param tau_temp Temp directory
#' @export
tauargus_prepare_hitas <- function(self, tab, param, files, tau_temp)
  .Call(rta_tau_prepare_hitas, self, tab, param, files, tau_temp)

#' Configure the engine to use HiTaS as secondary suppression
#' @param self TauArgus object
#' @param tab Table index
#' @return List: ok (logical), n_set_secondary
#' @export
tauargus_set_secondary_hitas <- function(self, tab)
  .Call(rta_tau_set_secondary_hitas, self, tab)

#' Configure a secondary JJ-format suppression file for one table
#' @param self TauArgus object
#' @param tab Table index
#' @param file JJ file
#' @param with_bogus logical
#' @return List: code, n_set_secondary
#' @export
tauargus_set_secondary_jjformat <- function(self, tab, file,
                                            with_bogus = FALSE)
  .Call(rta_tau_set_secondary_jjformat, self, tab, file, with_bogus)

#' Set realized lower and upper bounds on a suppressed cell
#' @param self TauArgus object
#' @param tab Table index
#' @param cell Cell index
#' @param up Upper bound
#' @param lo Lower bound
#' @export
tauargus_set_realized_lower_and_upper <- function(self, tab, cell, up, lo)
  .Call(rta_tau_set_realized_lower_and_upper, self, tab, cell, up, lo)

#' Load a rounded response file back into the engine
#' @param self TauArgus object
#' @param file Rounded response file
#' @param tab Table index
#' @export
tauargus_set_rounded_response <- function(self, file, tab)
  .Call(rta_tau_set_rounded_response, self, file, tab)

#' Set cell key values (frequency variant) for a table
#' @param self TauArgus object
#' @param tab Table index
#' @param ptable PTable data file
#' @return List: ok, min, max
#' @export
tauargus_set_cell_key_values_freq <- function(self, tab, ptable)
  .Call(rta_tau_set_cell_key_values_freq, self, tab, ptable)

#' Set CKM cell key values from a continuous (cont) ptable
#' @param self TauArgus object
#' @param tab Table index
#' @param ptable_file_cont Path to the continuous ptable file
#' @param ptable_file_sep Path to the separation ptable file
#' @param ckm_type CKM type
#' @param top_k Top-k parameter
#' @param include_zeros Whether to include zeros
#' @param parity Parity flag
#' @param separation Separation flag
#' @param m1sqr m1sqr parameter
#' @param scaling Scaling string
#' @param sigma0 sigma0 parameter
#' @param sigma1 sigma1 parameter
#' @param xstar xstar parameter
#' @param q q parameter
#' @param epsilon Numeric vector of epsilon values
#' @param mu_c mu_c parameter
#' @return Integer: status code
#' @export
tauargus_set_cell_key_values_cont <- function(self, tab, ptable_file_cont,
                                              ptable_file_sep, ckm_type,
                                              top_k, include_zeros = FALSE,
                                              parity = FALSE,
                                              separation = FALSE,
                                              m1sqr = 0, scaling = "linear",
                                              sigma0 = 0, sigma1 = 0,
                                              xstar = 0, q = 0,
                                              epsilon = numeric(0),
                                              mu_c = 0) {
  .Call(rta_tau_set_cell_key_values_cont, self, tab, ptable_file_cont,
        ptable_file_sep, ckm_type, top_k, include_zeros, parity, separation,
        m1sqr, scaling, sigma0, sigma1, xstar, q, epsilon, mu_c)
}

#' Declare one table of tabular (table-input) data
#' @param self TauArgus object
#' @param idx Table index
#' @param codes Character vector of cell key codes
#' @param shadow Numeric
#' @param cost Numeric
#' @param resp Numeric
#' @param freq Numeric
#' @param maxscore Numeric vector
#' @param maxscore_hold Numeric vector
#' @param status Numeric
#' @param lpl Numeric
#' @param upl Numeric
#' @export
tauargus_set_in_table <- function(self, idx, codes, shadow, cost, resp, freq,
                                  maxscore, maxscore_hold, status, lpl, upl) {
  .Call(rta_tau_set_in_table, self, idx, codes, shadow, cost, resp,
            freq, maxscore, maxscore_hold, status, lpl, upl)
}

#' Restrict the codes of one variable (table-input flow)
#' @param self TauArgus object
#' @param var_index Numeric vector of variable indices
#' @param codes Character vector of codes to keep
#' @return List: ok, err, ev
#' @export
tauargus_set_in_code_list <- function(self, var_index, codes)
  .Call(rta_tau_set_in_code_list, self, var_index, codes)

#' Add totals to the code list of one variable (table-input flow)
#' @param self TauArgus object
#' @param var_index Numeric vector of variable indices
#' @return List: ok, err, ev
#' @export
tauargus_set_totals_in_code_list <- function(self, var_index)
  .Call(rta_tau_set_totals_in_code_list, self, var_index)

#' Declare a completed (suppressed) table for a COVER step
#' @param self TauArgus object
#' @param idx Table index
#' @param file Table file
#' @param calc_totals logical
#' @param calc_totals_safe logical
#' @param for_cover logical
#' @return List: ok, err
#' @export
tauargus_completed_table <- function(self, idx, file, calc_totals = FALSE,
                                     calc_totals_safe = FALSE,
                                     for_cover = FALSE) {
  .Call(rta_tau_completed_table, self, idx, file, calc_totals,
            calc_totals_safe, for_cover)
}
