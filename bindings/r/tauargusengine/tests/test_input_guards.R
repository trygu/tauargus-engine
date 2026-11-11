# Phase 4 input guards: NA / fractional / Inf / out-of-range inputs must
# raise a clean typed R error that names the argument, never undefined
# behavior, and R must remain usable afterwards.
library(tauargusengine)

check_error <- function(expr, pattern, .envir = parent.frame()) {
  result <- tryCatch(eval(substitute(expr), .envir), error = identity)
  stopifnot(inherits(result, "error"))
  stopifnot(grepl(pattern, conditionMessage(result)))
}

e <- new_tauargus()
r <- new_rounder()

# rta_long: NA, fractional, Inf, out of range (names the argument)
check_error(tauargus_set_number_tab(e, NA), "n_tab.*NA|NA.*n_tab")
check_error(tauargus_set_number_tab(e, 1.5), "n_tab.*(whole|integer)")
check_error(tauargus_set_number_tab(e, Inf), "n_tab.*finite")
check_error(tauargus_set_number_tab(e, 1e19), "n_tab.*range")
# On 64-bit systems (double)LONG_MAX rounds up to 2^63. This value must
# be rejected before a double-to-long cast, not passed to the engine.
check_error(tauargus_set_number_tab(e, 2^63), "n_tab.*range")
check_error(tauargus_set_number_var(e, NA), "n_var")

# rta_lgl: NA
check_error(tauargus_set_var_code_active(e, 1L, 1L, NA), "active")

# rta_long_vec: NA / fractional element (fires before the native call)
check_error(tauargus_set_hierarchical_digits(e, 1L, c(1L, NA)), "digits")
check_error(tauargus_set_hierarchical_digits(e, 1L, c(1L, 2.5)), "digits")
check_error(tauargus_set_hierarchical_digits(e, 1L, c(1, 2^63)), "digits.*range")

# rta_dbl_vec: NA element; Inf stays legal for bound vectors. The file
# exists but is malformed, so the Inf run passes the guards and only
# then fails inside the solver with a non-zero code.
work <- tempfile("guard_"); dir.create(work); setwd(work)
writeLines("99", "bad.jj")
check_error(
  rounder_do_round(r, "SCIP", "bad.jj", 5,
                   upper_bound = c(1, NA), lower_bound = c(0, 0)),
  "upper")
# A 5-element result vector back means the guard accepted Inf and the
# call reached the solver (which then fails on the malformed file).
inf_result <- rounder_do_round(r, "SCIP", "bad.jj", 5,
                               upper_bound = c(1, Inf),
                               lower_bound = c(0, 0))
stopifnot(is.numeric(inf_result), length(inf_result) == 5L)

# Legal whole numbers and logicals do not trip the guards (they may
# still be rejected by the engine for other reasons, e.g. no tables set
# yet on a fresh object).
stopifnot(is.logical(tauargus_set_number_tab(e, 3L)))
stopifnot(is.logical(tauargus_set_var_code_active(e, 1L, 1L, TRUE)))

# R remains usable after all the rejected calls
stopifnot(nzchar(tauargus_version(e)))
cat("input guards ok\n")
