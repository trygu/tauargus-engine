// CSP audit (realized feasibility intervals) bindings for R. This TU only
// declares the extern "C" TauAuditJj entry point from the tauargus_csp shared
// lib (mirroring bindings/python/cpp/bind_csp.cpp), so it never pulls in the
// csp HiGHS/VSCIP headers.

#include <string>

#include "rta.h"
#include "rta_cpp.h"

// From native/csp/src/cspaudit.h
extern "C" {
int TauAuditJj(const char *jjfile, int *n_out, long **cell_idx,
               double **a_min, double **a_max, double **a_value,
               char **a_status, int **a_unsafe);
void TauAuditJjFree(int n, long *cell_idx, double *a_min, double *a_max,
                    double *a_value, char *a_status, int *a_unsafe);
}

extern "C" SEXP rta_audit_jj(SEXP jjfile) {
    std::string f = rta_str(jjfile);

    int n = 0;
    long *ci = nullptr;
    double *mn = nullptr, *mx = nullptr, *val = nullptr;
    char *st = nullptr;
    int *fl = nullptr;

    int rc = TauAuditJj(f.c_str(), &n, &ci, &mn, &mx, &val, &st, &fl);
    if (rc != 0) {
        Rf_error("audit_jj failed (rc=%d): %s", rc, f.c_str());
    }

    const int N = n > 0 ? n : 0;

    SEXP df = PROTECT(Rf_allocVector(VECSXP, 6));

    SEXP cell = PROTECT(Rf_allocVector(INTSXP, N));
    for (int i = 0; i < N; i++) INTEGER(cell)[i] = (int) ci[i];
    SET_VECTOR_ELT(df, 0, cell);

    SEXP vmin = PROTECT(Rf_allocVector(REALSXP, N));
    SEXP vmax = PROTECT(Rf_allocVector(REALSXP, N));
    SEXP vval = PROTECT(Rf_allocVector(REALSXP, N));
    SEXP vstat = PROTECT(Rf_allocVector(STRSXP, N));
    SEXP vun = PROTECT(Rf_allocVector(LGLSXP, N));
    for (int i = 0; i < N; i++) {
        REAL(vmin)[i] = mn[i];
        REAL(vmax)[i] = mx[i];
        REAL(vval)[i] = val[i];
        SET_STRING_ELT(vstat, i,
                       Rf_mkCharCE(std::string(1, st[i]).c_str(), CE_UTF8));
        LOGICAL(vun)[i] = (fl[i] != 0);
    }
    SET_VECTOR_ELT(df, 1, vmin);
    SET_VECTOR_ELT(df, 2, vmax);
    SET_VECTOR_ELT(df, 3, vval);
    SET_VECTOR_ELT(df, 4, vstat);
    SET_VECTOR_ELT(df, 5, vun);

    SEXP nm = PROTECT(Rf_allocVector(STRSXP, 6));
    SET_STRING_ELT(nm, 0, Rf_mkChar("cell"));
    SET_STRING_ELT(nm, 1, Rf_mkChar("min"));
    SET_STRING_ELT(nm, 2, Rf_mkChar("max"));
    SET_STRING_ELT(nm, 3, Rf_mkChar("value"));
    SET_STRING_ELT(nm, 4, Rf_mkChar("status"));
    SET_STRING_ELT(nm, 5, Rf_mkChar("unsafe"));
    Rf_setAttrib(df, Rf_install("names"), nm);

    SEXP rn = PROTECT(Rf_allocVector(INTSXP, 2));
    INTEGER(rn)[0] = NA_INTEGER;
    INTEGER(rn)[1] = -N;
    Rf_setAttrib(df, Rf_install("row.names"), rn);

    SEXP cls = PROTECT(Rf_allocVector(STRSXP, 1));
    SET_STRING_ELT(cls, 0, Rf_mkChar("data.frame"));
    Rf_setAttrib(df, Rf_install("class"), cls);

    if (N > 0) {
        TauAuditJjFree(N, ci, mn, mx, val, st, fl);
    }

    UNPROTECT(10);
    return df;
}
