# R wrapper for the CSP audit (src/rta_csp.cpp): realized feasibility
# intervals (the "intervalle" audit).

#' Compute realized feasibility intervals for a suppressed table
#'
#' Mirrors the legacy intervalle audit: for every suppressed cell of the table
#' described by the JJ file, returns the realized lower/upper interval, the
#' rounded value, the status character and whether the interval is unsafe
#' (width above the bound).
#'
#' @param jjfile Path to the JJ file describing the table.
#' @return A data.frame with columns `cell`, `min`, `max`, `value`,
#'   `status`, `unsafe`, in ascending cell index order.
#' @export
audit_jj <- function(jjfile) .Call(rta_audit_jj, jjfile)
