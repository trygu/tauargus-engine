/*
 * tauargusengine — native routine registration.
 *
 * All .Call entry points are registered here so R can resolve them via
 * getNativeSymbolInfo() (used by .onLoad in R/zzz.R). The implementations
 * live in the C++ translation units rta_engine.cpp / rta_hitas.cpp /
 * rta_rounder.cpp / rta_csp.cpp and are declared in rta.h.
 */

#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>

#include "rta.h"

static const R_CallMethodDef CallEntries[] = {
    /* lifecycle */
    {"rta_tauargus_new", (DL_FUNC) &rta_tauargus_new, 0},
    {"rta_hitas_new",    (DL_FUNC) &rta_hitas_new,    0},
    {"rta_rounder_new",  (DL_FUNC) &rta_rounder_new,  0},

    /* build provenance */
    {"rta_engine_meta",  (DL_FUNC) &rta_engine_meta,  0},

    /* TauArgus: metadata / errors */
    {"rta_tau_version",    (DL_FUNC) &rta_tau_version,    1},
    {"rta_tau_error_string", (DL_FUNC) &rta_tau_error_string, 2},
    {"rta_tau_clean_all",  (DL_FUNC) &rta_tau_clean_all,  1},

    /* TauArgus: input file / dimensions */
    {"rta_tau_set_in_file_info", (DL_FUNC) &rta_tau_set_in_file_info, 3},
    {"rta_tau_set_number_var",   (DL_FUNC) &rta_tau_set_number_var,   2},
    {"rta_tau_set_number_tab",   (DL_FUNC) &rta_tau_set_number_tab,   2},
    {"rta_tau_explore_file",     (DL_FUNC) &rta_tau_explore_file,     2},

    /* TauArgus: variables */
    {"rta_tau_set_variable",               (DL_FUNC) &rta_tau_set_variable,               18},
    {"rta_tau_set_hierarchical_codelist",  (DL_FUNC) &rta_tau_set_hierarchical_codelist,  4},
    {"rta_tau_set_hierarchical_digits",    (DL_FUNC) &rta_tau_set_hierarchical_digits,    3},
    {"rta_tau_get_var_number_of_codes",    (DL_FUNC) &rta_tau_get_var_number_of_codes,    2},
    {"rta_tau_get_var_code",               (DL_FUNC) &rta_tau_get_var_code,               3},
    {"rta_tau_get_var_code_properties",    (DL_FUNC) &rta_tau_get_var_code_properties,    3},
    {"rta_tau_set_var_code_active",        (DL_FUNC) &rta_tau_set_var_code_active,        4},
    {"rta_tau_do_active_recode",           (DL_FUNC) &rta_tau_do_active_recode,           2},
    {"rta_tau_apply_recode",               (DL_FUNC) &rta_tau_apply_recode,               1},
    {"rta_tau_undo_recode",                (DL_FUNC) &rta_tau_undo_recode,                2},
    {"rta_tau_do_recode",                  (DL_FUNC) &rta_tau_do_recode,                  6},

    /* TauArgus: tables */
    {"rta_tau_set_table",              (DL_FUNC) &rta_tau_set_table,              14},
    {"rta_tau_set_table_safety",       (DL_FUNC) &rta_tau_set_table_safety,       23},
    {"rta_tau_set_table_safety_info",  (DL_FUNC) &rta_tau_set_table_safety_info,  19},
    {"rta_tau_through_table",          (DL_FUNC) &rta_tau_through_table,          1},
    {"rta_tau_compute_tables",         (DL_FUNC) &rta_tau_compute_tables,         1},
    {"rta_tau_get_total_table_size",   (DL_FUNC) &rta_tau_get_total_table_size,   2},
    {"rta_tau_get_table_cell_value",   (DL_FUNC) &rta_tau_get_table_cell_value,   3},
    {"rta_tau_get_table_cell_status",  (DL_FUNC) &rta_tau_get_table_cell_status,  3},
    {"rta_tau_get_table_cell_protection_levels",
     (DL_FUNC) &rta_tau_get_table_cell_protection_levels, 3},
    {"rta_tau_set_table_cell_protection_levels",
     (DL_FUNC) &rta_tau_set_table_cell_protection_levels, 5},
    {"rta_tau_set_table_cell_status_cell",
     (DL_FUNC) &rta_tau_set_table_cell_status_cell, 4},
    {"rta_tau_get_table_cell", (DL_FUNC) &rta_tau_get_table_cell, 4},
    {"rta_tau_set_table_cell_cost", (DL_FUNC) &rta_tau_set_table_cell_cost, 4},
    {"rta_tau_set_table_cell_status_dim",
     (DL_FUNC) &rta_tau_set_table_cell_status_dim, 4},
    {"rta_tau_set_protection_levels_dim",
     (DL_FUNC) &rta_tau_set_protection_levels_dim, 5},
    {"rta_tau_get_minimum_cell_value", (DL_FUNC) &rta_tau_get_minimum_cell_value, 2},

    /* TauArgus: secondary suppression entry points */
    {"rta_tau_set_secondary_jjformat",       (DL_FUNC) &rta_tau_set_secondary_jjformat,       4},
    {"rta_tau_write_jj_format",              (DL_FUNC) &rta_tau_write_jj_format,              8},
    {"rta_tau_prepare_hitas",                (DL_FUNC) &rta_tau_prepare_hitas,                5},
    {"rta_tau_set_secondary_hitas",          (DL_FUNC) &rta_tau_set_secondary_hitas,          2},
    {"rta_tau_set_realized_lower_and_upper", (DL_FUNC) &rta_tau_set_realized_lower_and_upper, 5},
    {"rta_tau_set_rounded_response",         (DL_FUNC) &rta_tau_set_rounded_response,         3},
    {"rta_tau_set_cell_key_values_freq",     (DL_FUNC) &rta_tau_set_cell_key_values_freq,     3},
    {"rta_tau_set_cell_key_values_cont",     (DL_FUNC) &rta_tau_set_cell_key_values_cont,     16},

    /* TauArgus: table input flow */
    {"rta_tau_set_in_table",           (DL_FUNC) &rta_tau_set_in_table,           12},
    {"rta_tau_set_in_code_list",       (DL_FUNC) &rta_tau_set_in_code_list,       3},
    {"rta_tau_set_totals_in_code_list", (DL_FUNC) &rta_tau_set_totals_in_code_list, 2},
    {"rta_tau_completed_table",        (DL_FUNC) &rta_tau_completed_table,        6},

    /* TauArgus: output writers */
    {"rta_tau_write_cell_records", (DL_FUNC) &rta_tau_write_cell_records, 10},
    {"rta_tau_write_csv",          (DL_FUNC) &rta_tau_write_csv,          6},

    /* HiTaSCtrl */
    {"rta_hitas_full_jj",      (DL_FUNC) &rta_hitas_full_jj,      7},
    {"rta_hitas_a_hitas",      (DL_FUNC) &rta_hitas_a_hitas,      10},
    {"rta_hitas_error_string", (DL_FUNC) &rta_hitas_error_string, 2},

    /* RounderCtrl */
    {"rta_rounder_set_double_constant", (DL_FUNC) &rta_rounder_set_double_constant, 3},
    {"rta_rounder_do_round",            (DL_FUNC) &rta_rounder_do_round,            11},

    /* CSP audit */
    {"rta_audit_jj", (DL_FUNC) &rta_audit_jj, 1},

    {NULL, NULL, 0}
};

void R_init_tauargusengine(DllInfo *dll) {
    R_registerRoutines(dll, NULL, CallEntries, NULL, NULL);
    R_forceSymbols(dll, TRUE);
}
