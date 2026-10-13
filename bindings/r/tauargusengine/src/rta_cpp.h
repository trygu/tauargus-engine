/*
 * Shared C++ helpers for converting R values to C++ call arguments and back.
 * C++ only; included by the per-object translation units.
 */

#ifndef RTA_CPP_H
#define RTA_CPP_H

#include <R.h>
#include <Rinternals.h>
#undef length
#undef sqrt
#undef error

#include <string>
#include <vector>
#include <cstdarg>

static inline std::string rta_str(SEXP x) {
    if (x == R_NilValue) return std::string();
    if (TYPEOF(x) != STRSXP) x = Rf_coerceVector(x, STRSXP);
    return CHAR(STRING_ELT(x, 0));
}

static inline long rta_long(SEXP x) {
    if (x == R_NilValue) return 0;
    if (TYPEOF(x) == INTSXP) return (long) INTEGER(x)[0];
    if (TYPEOF(x) == REALSXP) return (long) REAL(x)[0];
    if (TYPEOF(x) == LGLSXP) return (long) LOGICAL(x)[0];
    return (long) Rf_asReal(x);
}

static inline double rta_dbl(SEXP x) {
    if (x == R_NilValue) return 0.0;
    return (double) Rf_asReal(x);
}

static inline bool rta_lgl(SEXP x) {
    if (x == R_NilValue) return false;
    if (TYPEOF(x) == LGLSXP) return LOGICAL(x)[0] != 0;
    if (TYPEOF(x) == INTSXP) return INTEGER(x)[0] != 0;
    if (TYPEOF(x) == REALSXP) return REAL(x)[0] != 0;
    return Rf_asLogical(x) != 0;
}

/* A vector of integers (coerced through real to keep large values exact). */
static inline std::vector<long> rta_long_vec(SEXP x) {
    int n = x == R_NilValue ? 0 : LENGTH(x);
    std::vector<long> v(n);
    if (n) {
        SEXP xr = PROTECT(Rf_coerceVector(x, REALSXP));
        for (int i = 0; i < n; i++) v[i] = (long) REAL(xr)[i];
        UNPROTECT(1);
    }
    return v;
}

static inline std::vector<double> rta_dbl_vec(SEXP x) {
    int n = x == R_NilValue ? 0 : LENGTH(x);
    std::vector<double> v(n);
    if (n) {
        SEXP xr = PROTECT(Rf_coerceVector(x, REALSXP));
        for (int i = 0; i < n; i++) v[i] = REAL(xr)[i];
        UNPROTECT(1);
    }
    return v;
}

static inline std::vector<std::string> rta_str_vec(SEXP x) {
    int n = x == R_NilValue ? 0 : LENGTH(x);
    std::vector<std::string> v(n);
    if (n) {
        SEXP xs = PROTECT(Rf_coerceVector(x, STRSXP));
        for (int i = 0; i < n; i++) v[i] = CHAR(STRING_ELT(xs, i));
        UNPROTECT(1);
    }
    return v;
}

/* Set the names attribute of a VECSXP (or similar) from a varargs list of
 * C strings. Must be called while `v` is on the PROTECT stack. */
static inline void rta_set_names(SEXP v, ...) {
    int n = LENGTH(v);
    SEXP nm = PROTECT(Rf_allocVector(STRSXP, n));
    va_list ap;
    va_start(ap, v);
    for (int i = 0; i < n; i++) {
        const char *s = va_arg(ap, const char *);
        SET_STRING_ELT(nm, i, Rf_mkChar(s));
    }
    va_end(ap);
    Rf_setAttrib(v, Rf_install("names"), nm);
    UNPROTECT(1);
}

/* -- return value constructors ----------------------------------------- */

static inline SEXP rta_str_sexp(const std::string &s) {
    return Rf_ScalarString(Rf_mkCharCE(s.c_str(), CE_UTF8));
}

static inline SEXP rta_lgl_sexp(bool b) { return Rf_ScalarLogical(b ? 1 : 0); }
static inline SEXP rta_dbl_sexp(double d) { return Rf_ScalarReal(d); }
static inline SEXP rta_long_sexp(long l) { return Rf_ScalarInteger((int) l); }

static inline SEXP rta_dbl2(double a, double b) {
    SEXP v = PROTECT(Rf_allocVector(REALSXP, 2));
    REAL(v)[0] = a;
    REAL(v)[1] = b;
    UNPROTECT(1);
    return v;
}

static inline SEXP rta_long2(long a, long b) {
    SEXP v = PROTECT(Rf_allocVector(INTSXP, 2));
    INTEGER(v)[0] = (int) a;
    INTEGER(v)[1] = (int) b;
    UNPROTECT(1);
    return v;
}

static inline SEXP rta_long3(long a, long b, long c) {
    SEXP v = PROTECT(Rf_allocVector(INTSXP, 3));
    INTEGER(v)[0] = (int) a;
    INTEGER(v)[1] = (int) b;
    INTEGER(v)[2] = (int) c;
    UNPROTECT(1);
    return v;
}

static inline SEXP rta_dbl4(double a, double b, double c, double d) {
    SEXP v = PROTECT(Rf_allocVector(REALSXP, 4));
    REAL(v)[0] = a;
    REAL(v)[1] = b;
    REAL(v)[2] = c;
    REAL(v)[3] = d;
    UNPROTECT(1);
    return v;
}

static inline SEXP rta_dbl5(double a, double b, double c, double d, double e) {
    SEXP v = PROTECT(Rf_allocVector(REALSXP, 5));
    REAL(v)[0] = a;
    REAL(v)[1] = b;
    REAL(v)[2] = c;
    REAL(v)[3] = d;
    REAL(v)[4] = e;
    UNPROTECT(1);
    return v;
}

#endif /* RTA_CPP_H */
