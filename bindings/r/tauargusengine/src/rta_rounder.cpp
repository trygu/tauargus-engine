// RounderCtrl bindings for R (controlled rounding via CRP/HiGHS). Kept in its
// own translation unit for the same IProgressListener-isolation reason as
// rta_hitas.cpp.

#include <string>
#include <vector>

#include "RounderCtrl.h"

#include "rta.h"
#include "rta_cpp.h"

extern "C" SEXP rta_rounder_new(void) {
    RounderCtrl *obj = new RounderCtrl();
    SEXP ext = PROTECT(R_MakeExternalPtr(obj, R_NilValue, R_NilValue));
    R_RegisterCFinalizerEx(
        ext,
        +[](SEXP e) {
            void *p = R_ExternalPtrAddr(e);
            if (p) {
                delete static_cast<RounderCtrl *>(p);
                R_SetExternalPtrAddr(e, NULL);
            }
        },
        TRUE);
    UNPROTECT(1);
    return ext;
}

extern "C" SEXP rta_rounder_set_double_constant(SEXP self, SEXP variable,
                                                SEXP value) {
    RounderCtrl &r = *static_cast<RounderCtrl *>(R_ExternalPtrAddr(self));
    r.SetDoubleConstant((int) rta_long(variable), rta_dbl(value));
    return R_NilValue;
}

extern "C" SEXP rta_rounder_do_round(SEXP self, SEXP solver, SEXP in_file,
                                     SEXP base, SEXP upper, SEXP lower,
                                     SEXP auditing, SEXP solution,
                                     SEXP statistics, SEXP max_time,
                                     SEXP zero_restricted) {
    RounderCtrl &r = *static_cast<RounderCtrl *>(R_ExternalPtrAddr(self));
    std::vector<double> u = rta_dbl_vec(upper);
    std::vector<double> l = rta_dbl_vec(lower);

    std::string s_solver = rta_str(solver);
    std::string s_in = rta_str(in_file);
    std::string s_solution = rta_str(solution);
    std::string s_statistics = rta_str(statistics);

    double mj = 0;
    long nj = 0;
    double ut = 0;
    long ec = 0;
    int result = r.DoRound(
        const_cast<char *>(s_solver.c_str()), const_cast<char *>(s_in.c_str()),
        rta_dbl(base), u.empty() ? nullptr : u.data(),
        l.empty() ? nullptr : l.data(), rta_long(auditing),
        const_cast<char *>(s_solution.c_str()),
        const_cast<char *>(s_statistics.c_str()), nullptr, nullptr,
        rta_long(max_time), rta_long(zero_restricted), nullptr, &mj, &nj, &ut,
        &ec);

    // -> numeric(5): result, max_jump, n_jump, used_time, error_code
    SEXP v = PROTECT(Rf_allocVector(REALSXP, 5));
    REAL(v)[0] = (double) result;
    REAL(v)[1] = mj;
    REAL(v)[2] = (double) nj;
    REAL(v)[3] = ut;
    REAL(v)[4] = (double) ec;
    UNPROTECT(1);
    return v;
}
