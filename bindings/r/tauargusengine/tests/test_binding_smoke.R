# Binding smoke: the tauargusengine package compiles, links and constructs.
#
# Prerequisite: the engine superbuild output (engine/build/lib) exists.
# Install the package, then run this script:
#
#   R CMD INSTALL bindings/r/tauargusengine
#   Rscript bindings/r/tauargusengine/tests/test_binding_smoke.R
#
# The package-level R front-end (rtauargus) is tested in its own repo.

library(tauargusengine)
binding_package <- getNamespaceName(environment(new_tauargus))
stopifnot(identical(getLoadedDLLs()[[binding_package]][["dynamicLookup"]], FALSE))

engine <- new_tauargus()
version <- tauargus_version(engine)
stopifnot(is.character(version))
stopifnot(nchar(version) > 0L)

# Exercise the 17-argument native entry point. A fresh engine has no
# tables, so the engine must return its invalid-table status before
# trying to read either ptable file.
stopifnot(tauargus_set_cell_key_values_cont(
    engine, 0L, "unused", "unused", "T", 1L) == -1)

# audit_jj failure must surface as an R error carrying the native rc and
# the file name. The binding throws (not Rf_error) so C++ temporaries
# are destroyed before the long jump; rta_call raises the R error.
err <- tryCatch({
    audit_jj("/nonexistent-tauargus-audit-xyz.jj")
    NULL
}, error = function(e) conditionMessage(e))
stopifnot(is.character(err))
# -2 is the read_jj failure code (file missing or unparseable); -1 is
# the model/LP error funnel.
stopifnot(grepl("audit_jj failed (rc=-2)", err, fixed = TRUE))
stopifnot(grepl("/nonexistent-tauargus-audit-xyz.jj", err, fixed = TRUE))

hitas <- new_hitas()
rounder <- new_rounder()
stopifnot(inherits(hitas, "hitas_ctrl") || !is.null(hitas))
stopifnot(!is.null(rounder))

meta <- tauargus_engine_meta()
stopifnot(is.character(meta), !is.na(meta[["engine_sha"]]))
stopifnot(!is.na(meta[["highs_version"]]), nchar(meta[["highs_version"]]) > 0L)

# Regression: the embedded error-string table is process-wide.
# Dropping a hitas object (the R GC finalizer destroys it) must not
# blank the table for objects created afterwards.
stopifnot(nchar(hitas_error_string(hitas, 7002L)) > 0L)
hitas <- NULL
invisible(gc())
hitas <- new_hitas()
stopifnot(nchar(hitas_error_string(hitas, 7002L)) > 0L)

cat("tauargusengine binding smoke ok:", version, "\n")
cat("engine meta:", meta[["engine_sha"]], "| HiGHS", meta[["highs_version"]], "\n")
