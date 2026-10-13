#' tauargusengine: native R bindings to the Tau-Argus SDC engine
#'
#' Low-level interface to the `tauargus-engine` native libraries (core, csp,
#' hitas, crp, rounder; HiGHS-backed). It exposes the `TauArgus`,
#' `HiTaSCtrl` and `RounderCtrl` C++ objects and the `audit_jj` routine to R
#' through `.Call`. The batch-level orchestration (parsing `.arb`/`.rda`
#' files, driving a suppression run, writing outputs) lives in the
#' `rtauargus` package, which `Imports` this one.
#'
#' @keywords internal
"_PACKAGE"
