# R wrappers for the HiTaSCtrl object (src/rta_hitas.cpp): optimal (MOD /
# FullJJ) cell suppression via the HiGHS MIP.

#' Create a new HiTaSCtrl engine object
#' @return An external pointer to a C++ `HiTaSCtrl` instance.
#' @export
new_hitas <- function() .Call(rta_hitas_new)

#' Optimal cell suppression (FullJJ)
#' @param self HiTaSCtrl object (see [new_hitas()])
#' @param in_file_jj JJ input file
#' @param out_file Output file
#' @param max_time Max solve time (0 = unlimited)
#' @param ilm_file Initial LP file
#' @param out_dir Output directory
#' @param solver Solver name ("SCIP", "HiGHS")
#' @return Numeric status code (0 = success).
#' @export
hitas_full_jj <- function(self, in_file_jj, out_file, max_time = 0,
                          ilm_file = "", out_dir = "", solver = "SCIP") {
  .Call(rta_hitas_full_jj, self, in_file_jj, out_file, max_time,
            ilm_file, out_dir, solver)
}

#' Modular (hierarchical iterative) cell suppression
#' @param self HiTaSCtrl object
#' @param pars_file Parameters file
#' @param files_file Files file
#' @param max_time Max solve time (0 = unlimited)
#' @param ilm_file Initial LP file
#' @param tau_out_dir Output directory
#' @param solver Solver name ("SCIP", "HiGHS")
#' @param single_with_single Solve singles jointly (logical)
#' @param single_with_more Solve singles with higher tables jointly (logical)
#' @param do_count_bounds Enable count bounds (logical)
#' @return Numeric status code (0 = success).
#' @export
hitas_a_hitas <- function(self, pars_file, files_file, max_time = 0,
                          ilm_file = "", tau_out_dir = "", solver = "SCIP",
                          single_with_single = FALSE, single_with_more = FALSE,
                          do_count_bounds = FALSE) {
  .Call(rta_hitas_a_hitas, self, pars_file, files_file, max_time,
            ilm_file, tau_out_dir, solver, single_with_single,
            single_with_more, do_count_bounds)
}

#' Human-readable text for a HiTaS error code
#' @param self HiTaSCtrl object
#' @param code Error code
#' @export
hitas_error_string <- function(self, code)
  .Call(rta_hitas_error_string, self, code)
