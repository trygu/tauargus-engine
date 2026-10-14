/*
 * Build provenance exposed to R: a named character vector with the engine
 * revision, the recorded pin of each native submodule and the pinned HiGHS
 * version, all baked in at staging time (rta_meta.h).
 */

#include <R.h>
#include <Rinternals.h>

#include "rta_meta.h"

extern "C" SEXP rta_engine_meta(void)
{
    static const char *const keys[] = {
        "engine_sha",
        "submodule_core", "submodule_csp", "submodule_hitas",
        "submodule_crp", "submodule_rounder",
        "highs_version"};
    static const char *const vals[] = {
        RTA_META_ENGINE_SHA,
        RTA_META_ENGINE_SHA_CORE, RTA_META_ENGINE_SHA_CSP,
        RTA_META_ENGINE_SHA_HITAS, RTA_META_ENGINE_SHA_CRP,
        RTA_META_ENGINE_SHA_ROUNDER, RTA_META_HIGHS_VERSION};
    const int n = (int)(sizeof(keys) / sizeof(keys[0]));

    SEXP out = PROTECT(Rf_allocVector(STRSXP, n));
    for (int i = 0; i < n; i++)
        SET_STRING_ELT(out, i, Rf_mkChar(vals[i]));
    SEXP nm = PROTECT(Rf_allocVector(STRSXP, n));
    for (int i = 0; i < n; i++)
        SET_STRING_ELT(nm, i, Rf_mkChar(keys[i]));
    Rf_setAttrib(out, R_NamesSymbol, nm);
    UNPROTECT(2);
    return out;
}
