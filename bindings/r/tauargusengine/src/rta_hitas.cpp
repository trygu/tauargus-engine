// HiTaSCtrl bindings for R. This translation unit only includes the hitas
// headers, so the hitas `IProgressListener` (UpdateLB/UB/Groups/Tables/...)
// is the one in scope - it must never share a TU with core's different
// `IProgressListener`.

#include <string>

#include "HiTaSCtrl.h"

#include "rta.h"
#include "rta_cpp.h"

extern "C" SEXP rta_hitas_new(void) {
    HiTaSCtrl *obj = new HiTaSCtrl();
    SEXP ext = PROTECT(R_MakeExternalPtr(obj, R_NilValue, R_NilValue));
    R_RegisterCFinalizerEx(
        ext,
        +[](SEXP e) {
            void *p = R_ExternalPtrAddr(e);
            if (p) {
                delete static_cast<HiTaSCtrl *>(p);
                R_SetExternalPtrAddr(e, NULL);
            }
        },
        TRUE);
    UNPROTECT(1);
    return ext;
}

extern "C" SEXP rta_hitas_full_jj(SEXP self, SEXP in, SEXP out, SEXP max_time,
                                  SEXP ilm, SEXP out_dir, SEXP solver) {
    HiTaSCtrl &h = *static_cast<HiTaSCtrl *>(R_ExternalPtrAddr(self));
    long rc = h.FullJJ(rta_str(in).c_str(), rta_str(out).c_str(),
                       rta_long(max_time), rta_str(ilm).c_str(),
                       rta_str(out_dir).c_str(), rta_str(solver).c_str());
    return rta_long_sexp(rc);
}

extern "C" SEXP rta_hitas_a_hitas(SEXP self, SEXP pars, SEXP files,
                                  SEXP max_time, SEXP ilm, SEXP tau_out,
                                  SEXP solver, SEXP sws, SEXP swm, SEXP cdb) {
    HiTaSCtrl &h = *static_cast<HiTaSCtrl *>(R_ExternalPtrAddr(self));
    long rc = h.AHiTaS(rta_str(pars).c_str(), rta_str(files).c_str(),
                       rta_long(max_time), rta_str(ilm).c_str(),
                       rta_str(tau_out).c_str(), rta_str(solver).c_str(),
                       rta_lgl(sws), rta_lgl(swm), rta_lgl(cdb));
    return rta_long_sexp(rc);
}

extern "C" SEXP rta_hitas_error_string(SEXP self, SEXP code) {
    HiTaSCtrl &h = *static_cast<HiTaSCtrl *>(R_ExternalPtrAddr(self));
    return rta_str_sexp(h.GetErrorString((int) rta_long(code)));
}
