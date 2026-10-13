/*
 * tauargusengine — C entry points exposed to R.
 *
 * These are the R-visible symbols, registered in init.c via
 * R_registerRoutines and looked up from R with getNativeSymbolInfo().
 * The C++ implementations live in the sibling translation units. Each
 * "self" argument is an externalptr created by the matching *_new().
 */

#ifndef RTA_H
#define RTA_H

#include <R.h>
#include <Rinternals.h>

/* Rinternals.h defines convenience macros that collide with C++ standard
 * library declarations (std::char_traits::length, std::sqrt, ...). Undefine
 * them so the engine and libc++ headers can be parsed after the R headers. */
#undef length
#undef sqrt
#undef error

#ifdef __cplusplus
extern "C" {
#endif

/* -- lifecycle ---------------------------------------------------------- */
SEXP rta_tauargus_new(void);
SEXP rta_hitas_new(void);
SEXP rta_rounder_new(void);

/* -- TauArgus ----------------------------------------------------------- */
SEXP rta_tau_version(SEXP self);
SEXP rta_tau_error_string(SEXP self, SEXP code);
SEXP rta_tau_clean_all(SEXP self);
SEXP rta_tau_set_in_file_info(SEXP self, SEXP is_fixed, SEXP sep);
SEXP rta_tau_set_number_var(SEXP self, SEXP n);
SEXP rta_tau_set_number_tab(SEXP self, SEXP n);
SEXP rta_tau_set_variable(SEXP self, SEXP idx, SEXP b_pos, SEXP n_pos,
                          SEXP n_dec, SEXP n_missing, SEXP m1, SEXP m2,
                          SEXP total, SEXP is_peeper, SEXP p1, SEXP p2,
                          SEXP is_cat, SEXP is_num, SEXP is_weight,
                          SEXP is_hier, SEXP is_holding, SEXP is_rec);
SEXP rta_tau_set_hierarchical_codelist(SEXP self, SEXP var, SEXP file, SEXP lead);
SEXP rta_tau_set_hierarchical_digits(SEXP self, SEXP var, SEXP digits);
SEXP rta_tau_explore_file(SEXP self, SEXP file);
SEXP rta_tau_set_table(SEXP self, SEXP index, SEXP explanatory, SEXP is_freq,
                       SEXP resp, SEXP shadow, SEXP cost, SEXP cellkey,
                       SEXP ckm_type, SEXP ckm_topk, SEXP lam,
                       SEXP max_scaled_cost, SEXP peep_var, SEXP missing_as_safe);
SEXP rta_tau_set_table_safety(SEXP self, SEXP index, SEXP dom, SEXP dom_n,
                              SEXP dom_k, SEXP pq, SEXP pq_p, SEXP pq_q,
                              SEXP pq_n, SEXP min_freq, SEXP peep_perc,
                              SEXP peep_marge, SEXP peep_min_freq,
                              SEXP apply_peep, SEXP apply_weight,
                              SEXP weight_on_safety, SEXP apply_holding,
                              SEXP zero_rule, SEXP empty_as_ns, SEXP ns_range,
                              SEXP zero_range, SEXP manual_perc, SEXP freq_perc);
SEXP rta_tau_set_table_safety_info(SEXP self, SEXP index, SEXP has_maxscore,
                                   SEXP dom, SEXP dom_n, SEXP dom_p, SEXP pq,
                                   SEXP pq_p, SEXP pq_q, SEXP pq_n,
                                   SEXP has_freq, SEXP freq_perc,
                                   SEXP safe_min_rec, SEXP has_status,
                                   SEXP manual_perc, SEXP zero_rule,
                                   SEXP zero_range, SEXP empty_as_ns,
                                   SEXP ns_range);
SEXP rta_tau_through_table(SEXP self);
SEXP rta_tau_compute_tables(SEXP self);
SEXP rta_tau_get_total_table_size(SEXP self, SEXP tab);
SEXP rta_tau_get_table_cell_value(SEXP self, SEXP tab, SEXP cell);
SEXP rta_tau_get_table_cell_status(SEXP self, SEXP tab, SEXP cell);
SEXP rta_tau_get_table_cell_protection_levels(SEXP self, SEXP tab, SEXP cell);
SEXP rta_tau_set_table_cell_protection_levels(SEXP self, SEXP tab, SEXP cell,
                                              SEXP lpl, SEXP upl);
SEXP rta_tau_set_table_cell_status_cell(SEXP self, SEXP tab, SEXP cell,
                                        SEXP status);
SEXP rta_tau_get_table_cell(SEXP self, SEXP tab, SEXP dim_index, SEXP topn);
SEXP rta_tau_set_table_cell_cost(SEXP self, SEXP tab, SEXP dim_index,
                                 SEXP cost);
SEXP rta_tau_set_table_cell_status_dim(SEXP self, SEXP tab, SEXP dim_index,
                                       SEXP status);
SEXP rta_tau_set_protection_levels_dim(SEXP self, SEXP tab, SEXP dim_index,
                                       SEXP lpl, SEXP upl);
SEXP rta_tau_get_minimum_cell_value(SEXP self, SEXP tab);
SEXP rta_tau_get_var_number_of_codes(SEXP self, SEXP var);
SEXP rta_tau_get_var_code(SEXP self, SEXP var, SEXP code);
SEXP rta_tau_get_var_code_properties(SEXP self, SEXP var, SEXP code);
SEXP rta_tau_set_var_code_active(SEXP self, SEXP var, SEXP code, SEXP active);
SEXP rta_tau_do_active_recode(SEXP self, SEXP var);
SEXP rta_tau_apply_recode(SEXP self);
SEXP rta_tau_undo_recode(SEXP self, SEXP var);
SEXP rta_tau_do_recode(SEXP self, SEXP var, SEXP data, SEXP n_missing,
                       SEXP m1, SEXP m2);
SEXP rta_tau_write_csv(SEXP self, SEXP tab, SEXP file, SEXP embed_quotes,
                       SEXP dim_seq, SEXP resp_type);
SEXP rta_tau_write_cell_records(SEXP self, SEXP tab, SEXP file, SEXP sbs,
                                SEXP sbs_level, SEXP suppress_empty,
                                SEXP first_line, SEXP show_unsafe,
                                SEXP embed_quotes, SEXP resp_type);
SEXP rta_tau_write_jj_format(SEXP self, SEXP tab, SEXP file, SEXP lo, SEXP hi,
                             SEXP with_bogus, SEXP as_perc, SEXP for_rounding);
SEXP rta_tau_prepare_hitas(SEXP self, SEXP tab, SEXP param, SEXP files,
                           SEXP tau_temp);
SEXP rta_tau_set_secondary_hitas(SEXP self, SEXP tab);
SEXP rta_tau_set_secondary_jjformat(SEXP self, SEXP tab, SEXP file,
                                    SEXP with_bogus);
SEXP rta_tau_set_realized_lower_and_upper(SEXP self, SEXP tab, SEXP cell,
                                          SEXP up, SEXP lo);
SEXP rta_tau_set_rounded_response(SEXP self, SEXP file, SEXP tab);
SEXP rta_tau_set_cell_key_values_freq(SEXP self, SEXP tab, SEXP ptable);
SEXP rta_tau_set_cell_key_values_cont(SEXP self, SEXP tab, SEXP ptable_cont,
                                      SEXP ptable_sep, SEXP ckm_type,
                                      SEXP top_k, SEXP include_zeros,
                                      SEXP parity, SEXP separation, SEXP m1sqr,
                                      SEXP scaling, SEXP s0, SEXP s1,
                                      SEXP z_f, SEXP q, SEXP epsilon,
                                      SEXP mu_c);
SEXP rta_tau_set_in_table(SEXP self, SEXP idx, SEXP codes, SEXP shadow,
                          SEXP cost, SEXP resp, SEXP freq, SEXP maxscore,
                          SEXP maxscore_hold, SEXP status, SEXP lpl, SEXP upl);
SEXP rta_tau_set_in_code_list(SEXP self, SEXP var_index, SEXP codes);
SEXP rta_tau_set_totals_in_code_list(SEXP self, SEXP var_index);
SEXP rta_tau_completed_table(SEXP self, SEXP idx, SEXP file, SEXP calc_totals,
                             SEXP calc_totals_safe, SEXP for_cover);

/* -- HiTaSCtrl ---------------------------------------------------------- */
SEXP rta_hitas_full_jj(SEXP self, SEXP in, SEXP out, SEXP max_time, SEXP ilm,
                       SEXP out_dir, SEXP solver);
SEXP rta_hitas_a_hitas(SEXP self, SEXP pars, SEXP files, SEXP max_time,
                       SEXP ilm, SEXP tau_out, SEXP solver, SEXP sws,
                       SEXP swm, SEXP cdb);
SEXP rta_hitas_error_string(SEXP self, SEXP code);

/* -- RounderCtrl -------------------------------------------------------- */
SEXP rta_rounder_set_double_constant(SEXP self, SEXP variable, SEXP value);
SEXP rta_rounder_do_round(SEXP self, SEXP solver, SEXP in_file, SEXP base,
                          SEXP upper, SEXP lower, SEXP auditing,
                          SEXP solution, SEXP statistics, SEXP max_time,
                          SEXP zero_restricted);

/* -- CSP audit ---------------------------------------------------------- */
SEXP rta_audit_jj(SEXP jjfile);

#ifdef __cplusplus
}
#endif

#endif /* RTA_H */
