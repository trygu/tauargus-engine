# R wrappers for the RounderCtrl object (src/rta_rounder.cpp): controlled
# rounding (RND) via CRP/HiGHS.

#' Create a new RounderCtrl engine object
#' @return An external pointer to a C++ `RounderCtrl` instance.
#' @export
new_rounder <- function() .Call(rta_rounder_new)

#' Set a double constant for the rounding problem
#' @param self RounderCtrl object (see [new_rounder()])
#' @param variable Constant index
#' @param value Value
#' @export
rounder_set_double_constant <- function(self, variable, value)
  .Call(rta_rounder_set_double_constant, self, variable, value)

#' Run controlled rounding
#' @param self RounderCtrl object
#' @param solver Solver name ("SCIP", "HiGHS")
#' @param in_file JJ input file
#' @param base Rounding base
#' @param upper_bound Numeric vector of upper bounds (empty = none)
#' @param lower_bound Numeric vector of lower bounds (empty = none)
#' @param auditing Audit switch (0/1)
#' @param solution_file Solution file
#' @param statistics_file Statistics file
#' @param max_time Max solve time (0 = unlimited)
#' @param zero_restricted Zero-restriction switch
#' @return Numeric(5): result, max_jump, n_jump, used_time, error_code
#' @export
rounder_do_round <- function(self, solver, in_file, base,
                             upper_bound = numeric(0),
                             lower_bound = numeric(0), auditing = 0,
                             solution_file = "", statistics_file = "",
                             max_time = 0, zero_restricted = 0) {
  .Call(rta_rounder_do_round, self, solver, in_file, base, upper_bound,
            lower_bound, auditing, solution_file, statistics_file, max_time,
            zero_restricted)
}
