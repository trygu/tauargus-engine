# Build provenance (src/rta_meta.cpp + src/rta_meta.h).

#' Provenance of the built engine
#'
#' Returns a named character vector describing the native engine this
#' package was built from: the tauargus-engine revision (git SHA), the
#' recorded pin of each native submodule, and the pinned HiGHS version.
#' Use it when reporting a problem.
#'
#' @return A named character vector.
#' @export
tauargus_engine_meta <- function() .Call(rta_engine_meta)
