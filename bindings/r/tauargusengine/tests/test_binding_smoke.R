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

# 0.7.0 error contract: the binding exposes the native success flag and
# error codes. A declared-but-unprepared engine is the fixture.
e2 <- new_tauargus()
stopifnot(isTRUE(tauargus_set_number_var(e2, 1L)))
stopifnot(isTRUE(tauargus_set_number_tab(e2, 1L)))
sz <- tauargus_get_var_number_of_codes(e2, 9L)
stopifnot(identical(sz[["ok"]], FALSE), sz[["n_codes"]] == 0L)
sz0 <- tauargus_get_var_number_of_codes(e2, 0L)
stopifnot(identical(sz0[["ok"]], TRUE))
cv <- tauargus_get_table_cell_value(e2, 0L, 0L)
stopifnot(identical(cv[["ok"]], FALSE), cv[["value"]] == 0)
cs <- tauargus_get_table_cell_status(e2, 9L, 0L)
stopifnot(identical(cs[["ok"]], FALSE), cs[["status"]] == 0L)
pl <- tauargus_get_table_cell_protection_levels(e2, 0L, 0L)
stopifnot(identical(pl[["ok"]], FALSE), pl[["lower"]] == 0,
          pl[["upper"]] == 0)
tt <- tauargus_get_total_table_size(e2, 0L)
stopifnot(identical(tt[["ok"]], FALSE), tt[["n_cells"]] == 0L)
mn <- tauargus_get_minimum_cell_value(e2, 9L)
stopifnot(identical(mn[["ok"]], FALSE), mn[["min"]] == 0, mn[["max"]] == 0)
si <- tauargus_set_in_table(e2, 9L, "1", 0, 0, 1, 0, numeric(0),
                            numeric(0), 0, 0, 1)
stopifnot(identical(si[["ok"]], FALSE), si[["err"]] != 0L)
ss <- tauargus_set_table_safety_info(
    e2, 9L, FALSE, FALSE, integer(0), integer(0), FALSE, integer(0),
    integer(0), integer(0), FALSE, 0L, 0L, FALSE, 0L, FALSE, 0.0, FALSE,
    0L)
stopifnot(identical(ss[["ok"]], FALSE), ss[["errc"]] != 0L)

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
