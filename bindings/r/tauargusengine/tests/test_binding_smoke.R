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

engine <- new_tauargus()
version <- tauargus_version(engine)
stopifnot(is.character(version))
stopifnot(nchar(version) > 0L)

hitas <- new_hitas()
rounder <- new_rounder()
stopifnot(inherits(hitas, "hitas_ctrl") || !is.null(hitas))
stopifnot(!is.null(rounder))

cat("tauargusengine binding smoke ok:", version, "\n")
