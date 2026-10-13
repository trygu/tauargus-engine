// TauArgus core bindings for R. This translation unit only includes the core
// headers (TauArgus.h), so the core `IProgressListener` is the one in scope.
// It must never share a TU with the hitas or rounder headers (which define
// their own, differently-named IProgressListener/RCallback types).

#include <algorithm>
#include <string>
#include <vector>

#include "TauArgus.h"

#include "rta.h"
#include "rta_cpp.h"

// ---------------------------------------------------------------------------
// Lifecycle
// ---------------------------------------------------------------------------
extern "C" SEXP rta_tauargus_new(void) {
    TauArgus *obj = new TauArgus();
    SEXP ext = PROTECT(R_MakeExternalPtr(obj, R_NilValue, R_NilValue));
    // delete in the C++ destructor (runs CleanUp) when the externalptr is GC'd
    R_RegisterCFinalizerEx(
        ext, +[](SEXP e) {
            void *p = R_ExternalPtrAddr(e);
            if (p) {
                delete static_cast<TauArgus *>(p);
                R_SetExternalPtrAddr(e, NULL);
            }
        },
        TRUE);
    UNPROTECT(1);
    return ext;
}

// ---------------------------------------------------------------------------
// Metadata / errors
// ---------------------------------------------------------------------------
extern "C" SEXP rta_tau_version(SEXP self) {
    TauArgus &t = *static_cast<TauArgus *>(R_ExternalPtrAddr(self));
    return rta_str_sexp(t.GetVersion());
}

extern "C" SEXP rta_tau_error_string(SEXP self, SEXP code) {
    TauArgus &t = *static_cast<TauArgus *>(R_ExternalPtrAddr(self));
    return rta_str_sexp(t.GetErrorString(rta_long(code)));
}

extern "C" SEXP rta_tau_clean_all(SEXP self) {
    TauArgus &t = *static_cast<TauArgus *>(R_ExternalPtrAddr(self));
    t.CleanAll();
    return R_NilValue;
}

// ---------------------------------------------------------------------------
// Input file / dimensions
// ---------------------------------------------------------------------------
extern "C" SEXP rta_tau_set_in_file_info(SEXP self, SEXP is_fixed, SEXP sep) {
    TauArgus &t = *static_cast<TauArgus *>(R_ExternalPtrAddr(self));
    t.SetInFileInfo(rta_lgl(is_fixed), rta_str(sep).c_str());
    return R_NilValue;
}

extern "C" SEXP rta_tau_set_number_var(SEXP self, SEXP n) {
    TauArgus &t = *static_cast<TauArgus *>(R_ExternalPtrAddr(self));
    return rta_lgl_sexp(t.SetNumberVar(rta_long(n)));
}

extern "C" SEXP rta_tau_set_number_tab(SEXP self, SEXP n) {
    TauArgus &t = *static_cast<TauArgus *>(R_ExternalPtrAddr(self));
    return rta_lgl_sexp(t.SetNumberTab(rta_long(n)));
}

extern "C" SEXP rta_tau_explore_file(SEXP self, SEXP file) {
    TauArgus &t = *static_cast<TauArgus *>(R_ExternalPtrAddr(self));
    long err = 0, line = 0, var = 0;
    bool ok = t.ExploreFile(rta_str(file).c_str(), &err, &line, &var);
    // -> list(ok, err, line, var)
    SEXP r = PROTECT(Rf_allocVector(VECSXP, 4));
    SET_VECTOR_ELT(r, 0, rta_lgl_sexp(ok));
    SET_VECTOR_ELT(r, 1, rta_long_sexp(err));
    SET_VECTOR_ELT(r, 2, rta_long_sexp(line));
    SET_VECTOR_ELT(r, 3, rta_long_sexp(var));
    rta_set_names(r, "ok", "err", "line", "var");
    UNPROTECT(1);
    return r;
}

// ---------------------------------------------------------------------------
// Variables
// ---------------------------------------------------------------------------
extern "C" SEXP rta_tau_set_variable(SEXP self, SEXP idx, SEXP b_pos, SEXP n_pos,
                                     SEXP n_dec, SEXP n_missing, SEXP m1,
                                     SEXP m2, SEXP total, SEXP is_peeper,
                                     SEXP p1, SEXP p2, SEXP is_cat,
                                     SEXP is_num, SEXP is_weight,
                                     SEXP is_hier, SEXP is_holding,
                                     SEXP is_rec) {
    TauArgus &t = *static_cast<TauArgus *>(R_ExternalPtrAddr(self));
    return rta_lgl_sexp(t.SetVariable(
        rta_long(idx), rta_long(b_pos), rta_long(n_pos), rta_long(n_dec),
        rta_long(n_missing), rta_str(m1).c_str(), rta_str(m2).c_str(),
        rta_str(total).c_str(), rta_lgl(is_peeper), rta_str(p1).c_str(),
        rta_str(p2).c_str(), rta_lgl(is_cat), rta_lgl(is_num),
        rta_lgl(is_weight), rta_lgl(is_hier), rta_lgl(is_holding),
        rta_lgl(is_rec)));
}

extern "C" SEXP rta_tau_set_hierarchical_codelist(SEXP self, SEXP var,
                                                  SEXP file, SEXP lead) {
    TauArgus &t = *static_cast<TauArgus *>(R_ExternalPtrAddr(self));
    return rta_long_sexp(
        t.SetHierarchicalCodelist(rta_long(var), rta_str(file).c_str(),
                                  rta_str(lead).c_str()));
}

extern "C" SEXP rta_tau_set_hierarchical_digits(SEXP self, SEXP var,
                                                SEXP digits) {
    TauArgus &t = *static_cast<TauArgus *>(R_ExternalPtrAddr(self));
    std::vector<long> d = rta_long_vec(digits);
    return rta_lgl_sexp(t.SetHierarchicalDigits(rta_long(var),
                                                (long) d.size(), d.data()));
}

extern "C" SEXP rta_tau_get_var_number_of_codes(SEXP self, SEXP var) {
    TauArgus &t = *static_cast<TauArgus *>(R_ExternalPtrAddr(self));
    long n = 0, na = 0;
    t.GetVarNumberOfCodes(rta_long(var), &n, &na);
    return rta_long2(n, na);
}

extern "C" SEXP rta_tau_get_var_code(SEXP self, SEXP var, SEXP code) {
    TauArgus &t = *static_cast<TauArgus *>(R_ExternalPtrAddr(self));
    long ctype = 0, missing = 0, level = 0;
    std::string cs;
    bool ok = t.GetVarCode(rta_long(var), rta_long(code), &ctype, &cs,
                           &missing, &level);
    // -> list(ok, code_type, code_string, is_missing, level)
    SEXP r = PROTECT(Rf_allocVector(VECSXP, 5));
    SET_VECTOR_ELT(r, 0, rta_lgl_sexp(ok));
    SET_VECTOR_ELT(r, 1, rta_long_sexp(ctype));
    SET_VECTOR_ELT(r, 2, rta_str_sexp(cs));
    SET_VECTOR_ELT(r, 3, rta_long_sexp(missing));
    SET_VECTOR_ELT(r, 4, rta_long_sexp(level));
    rta_set_names(r, "ok", "code_type", "code_string", "is_missing", "level");
    UNPROTECT(1);
    return r;
}

extern "C" SEXP rta_tau_get_var_code_properties(SEXP self, SEXP var,
                                                SEXP code) {
    TauArgus &t = *static_cast<TauArgus *>(R_ExternalPtrAddr(self));
    long parent = 0, active = 0, missing = 0, level = 0, nchild = 0;
    const char *c = nullptr;
    bool ok = t.GetVarCodeProperties(rta_long(var), rta_long(code), &parent,
                                     &active, &missing, &level, &nchild, &c);
    std::string cs = c ? std::string(c) : std::string();
    // -> list(ok, is_parent, is_active, is_missing, level, n_children, code)
    SEXP r = PROTECT(Rf_allocVector(VECSXP, 7));
    SET_VECTOR_ELT(r, 0, rta_lgl_sexp(ok));
    SET_VECTOR_ELT(r, 1, rta_long_sexp(parent));
    SET_VECTOR_ELT(r, 2, rta_long_sexp(active));
    SET_VECTOR_ELT(r, 3, rta_long_sexp(missing));
    SET_VECTOR_ELT(r, 4, rta_long_sexp(level));
    SET_VECTOR_ELT(r, 5, rta_long_sexp(nchild));
    SET_VECTOR_ELT(r, 6, rta_str_sexp(cs));
    rta_set_names(r, "ok", "is_parent", "is_active", "is_missing", "level",
                  "n_children", "code");
    UNPROTECT(1);
    return r;
}

extern "C" SEXP rta_tau_set_var_code_active(SEXP self, SEXP var, SEXP code,
                                            SEXP active) {
    TauArgus &t = *static_cast<TauArgus *>(R_ExternalPtrAddr(self));
    return rta_lgl_sexp(
        t.SetVarCodeActive(rta_long(var), rta_long(code), rta_lgl(active)));
}

extern "C" SEXP rta_tau_do_active_recode(SEXP self, SEXP var) {
    TauArgus &t = *static_cast<TauArgus *>(R_ExternalPtrAddr(self));
    return rta_lgl_sexp(t.DoActiveRecode(rta_long(var)));
}

extern "C" SEXP rta_tau_apply_recode(SEXP self) {
    TauArgus &t = *static_cast<TauArgus *>(R_ExternalPtrAddr(self));
    t.ApplyRecode();
    return R_NilValue;
}

extern "C" SEXP rta_tau_undo_recode(SEXP self, SEXP var) {
    TauArgus &t = *static_cast<TauArgus *>(R_ExternalPtrAddr(self));
    return rta_lgl_sexp(t.UndoRecode(rta_long(var)));
}

extern "C" SEXP rta_tau_do_recode(SEXP self, SEXP var, SEXP data,
                                  SEXP n_missing, SEXP m1, SEXP m2) {
    TauArgus &t = *static_cast<TauArgus *>(R_ExternalPtrAddr(self));
    long et = 0, el = 0, ep = 0;
    const char *warn = nullptr;
    bool ok = t.DoRecode(rta_long(var), rta_str(data).c_str(),
                         rta_long(n_missing), rta_str(m1).c_str(),
                         rta_str(m2).c_str(), &et, &el, &ep, &warn);
    std::string w = warn ? std::string(warn) : std::string();
    // -> list(ok, error_type, error_line, error_pos, warning)
    SEXP r = PROTECT(Rf_allocVector(VECSXP, 5));
    SET_VECTOR_ELT(r, 0, rta_lgl_sexp(ok));
    SET_VECTOR_ELT(r, 1, rta_long_sexp(et));
    SET_VECTOR_ELT(r, 2, rta_long_sexp(el));
    SET_VECTOR_ELT(r, 3, rta_long_sexp(ep));
    SET_VECTOR_ELT(r, 4, rta_str_sexp(w));
    rta_set_names(r, "ok", "error_type", "error_line", "error_pos", "warning");
    UNPROTECT(1);
    return r;
}

// ---------------------------------------------------------------------------
// Table specification
// ---------------------------------------------------------------------------
extern "C" SEXP rta_tau_set_table(SEXP self, SEXP index, SEXP explanatory,
                                  SEXP is_freq, SEXP resp, SEXP shadow,
                                  SEXP cost, SEXP cellkey, SEXP ckm_type,
                                  SEXP ckm_topk, SEXP lam,
                                  SEXP max_scaled_cost, SEXP peep_var,
                                  SEXP missing_as_safe) {
    TauArgus &t = *static_cast<TauArgus *>(R_ExternalPtrAddr(self));
    std::vector<long> e = rta_long_vec(explanatory);
    return rta_lgl_sexp(t.SetTable(
        rta_long(index), (long) e.size(), e.data(), rta_lgl(is_freq),
        rta_long(resp), rta_long(shadow), rta_long(cost), rta_long(cellkey),
        rta_str(ckm_type), rta_long(ckm_topk), rta_dbl(lam),
        rta_dbl(max_scaled_cost), rta_long(peep_var),
        rta_lgl(missing_as_safe)));
}

extern "C" SEXP rta_tau_set_table_safety(SEXP self, SEXP index, SEXP dom,
                                         SEXP dom_n, SEXP dom_k, SEXP pq,
                                         SEXP pq_p, SEXP pq_q, SEXP pq_n,
                                         SEXP min_freq, SEXP peep_perc,
                                         SEXP peep_marge, SEXP peep_min_freq,
                                         SEXP apply_peep, SEXP apply_weight,
                                         SEXP weight_on_safety,
                                         SEXP apply_holding, SEXP zero_rule,
                                         SEXP empty_as_ns, SEXP ns_range,
                                         SEXP zero_range, SEXP manual_perc,
                                         SEXP freq_perc) {
    TauArgus &t = *static_cast<TauArgus *>(R_ExternalPtrAddr(self));
    std::vector<long> a = rta_long_vec(dom_n), b = rta_long_vec(dom_k);
    std::vector<long> c = rta_long_vec(pq_p), d = rta_long_vec(pq_q);
    std::vector<long> e = rta_long_vec(pq_n);
    std::vector<long> f = rta_long_vec(min_freq), g = rta_long_vec(peep_perc);
    std::vector<long> h = rta_long_vec(peep_marge);
    std::vector<long> i = rta_long_vec(peep_min_freq);
    std::vector<long> j = rta_long_vec(freq_perc);
    // The native side reads fixed-length arrays; pad to at least 4 entries.
    auto pad4 = [](std::vector<long> &v, long dft) {
        while (v.size() < 4) v.push_back(dft);
    };
    pad4(a, 0);
    pad4(b, 0);
    pad4(c, 0);
    pad4(d, 100);
    pad4(e, 0);
    pad4(f, 0);
    pad4(g, 0);
    pad4(h, 0);
    pad4(i, 0);
    pad4(j, 0);
    return rta_lgl_sexp(t.SetTableSafety(
        rta_long(index), rta_lgl(dom), a.data(), b.data(), rta_lgl(pq),
        c.data(), d.data(), e.data(), f.data(), g.data(), h.data(), i.data(),
        rta_lgl(apply_peep), rta_lgl(apply_weight),
        rta_lgl(weight_on_safety), rta_lgl(apply_holding), rta_lgl(zero_rule),
        rta_lgl(empty_as_ns), rta_long(ns_range), rta_dbl(zero_range),
        rta_long(manual_perc), j.data()));
}

extern "C" SEXP rta_tau_set_table_safety_info(SEXP self, SEXP index,
                                              SEXP has_maxscore, SEXP dom,
                                              SEXP dom_n, SEXP dom_p, SEXP pq,
                                              SEXP pq_p, SEXP pq_q, SEXP pq_n,
                                              SEXP has_freq, SEXP freq_perc,
                                              SEXP safe_min_rec,
                                              SEXP has_status,
                                              SEXP manual_perc, SEXP zero_rule,
                                              SEXP zero_range,
                                              SEXP empty_as_ns, SEXP ns_range) {
    TauArgus &t = *static_cast<TauArgus *>(R_ExternalPtrAddr(self));
    std::vector<long> a = rta_long_vec(dom_n), b = rta_long_vec(dom_p);
    std::vector<long> c = rta_long_vec(pq_p), d = rta_long_vec(pq_q);
    std::vector<long> e = rta_long_vec(pq_n);
    long errc = 0;
    bool ok = t.SetTableSafetyInfo(
        rta_long(index), rta_lgl(has_maxscore), rta_lgl(dom),
        a.empty() ? nullptr : a.data(), b.empty() ? nullptr : b.data(),
        rta_lgl(pq), c.empty() ? nullptr : c.data(),
        d.empty() ? nullptr : d.data(), e.empty() ? nullptr : e.data(),
        rta_lgl(has_freq), rta_long(freq_perc), rta_long(safe_min_rec),
        rta_lgl(has_status), rta_long(manual_perc), rta_lgl(zero_rule),
        rta_dbl(zero_range), rta_lgl(empty_as_ns), rta_long(ns_range), &errc);
    (void) errc;
    // Logical, like the SetTable/SetTableSafety siblings (the caller can
    // translate failures via TauArgus::ErrorString).
    return rta_lgl_sexp(ok);
}

// ---------------------------------------------------------------------------
// Compute
// ---------------------------------------------------------------------------
extern "C" SEXP rta_tau_through_table(SEXP self) {
    TauArgus &t = *static_cast<TauArgus *>(R_ExternalPtrAddr(self));
    t.ThroughTable();
    return R_NilValue;
}

extern "C" SEXP rta_tau_compute_tables(SEXP self) {
    TauArgus &t = *static_cast<TauArgus *>(R_ExternalPtrAddr(self));
    long err = 0, tab = 0;
    bool ok = t.ComputeTables(&err, &tab);
    // -> list(ok, err, table_index)
    SEXP r = PROTECT(Rf_allocVector(VECSXP, 3));
    SET_VECTOR_ELT(r, 0, rta_lgl_sexp(ok));
    SET_VECTOR_ELT(r, 1, rta_long_sexp(err));
    SET_VECTOR_ELT(r, 2, rta_long_sexp(tab));
    rta_set_names(r, "ok", "err", "table_index");
    UNPROTECT(1);
    return r;
}

extern "C" SEXP rta_tau_get_minimum_cell_value(SEXP self, SEXP tab) {
    TauArgus &t = *static_cast<TauArgus *>(R_ExternalPtrAddr(self));
    double mx = 0;
    double mn = t.GetMinimumCellValue(rta_long(tab), &mx);
    return rta_dbl2(mn, mx);
}

// ---------------------------------------------------------------------------
// Cell read
// ---------------------------------------------------------------------------
extern "C" SEXP rta_tau_get_total_table_size(SEXP self, SEXP tab) {
    TauArgus &t = *static_cast<TauArgus *>(R_ExternalPtrAddr(self));
    long ncell = 0, size = 0;
    t.GetTotalTabelSize(rta_long(tab), &ncell, &size);
    return rta_long2(ncell, size);
}

extern "C" SEXP rta_tau_get_table_cell_value(SEXP self, SEXP tab, SEXP cell) {
    TauArgus &t = *static_cast<TauArgus *>(R_ExternalPtrAddr(self));
    double r = 0;
    t.GetTableCellValue(rta_long(tab), rta_long(cell), &r);
    return rta_dbl_sexp(r);
}

extern "C" SEXP rta_tau_get_table_cell_status(SEXP self, SEXP tab,
                                              SEXP cell) {
    TauArgus &t = *static_cast<TauArgus *>(R_ExternalPtrAddr(self));
    long s = 0;
    t.GetTableCellStatus(rta_long(tab), rta_long(cell), &s);
    return rta_long_sexp(s);
}

extern "C" SEXP rta_tau_get_table_cell_protection_levels(SEXP self, SEXP tab,
                                                         SEXP cell) {
    TauArgus &t = *static_cast<TauArgus *>(R_ExternalPtrAddr(self));
    double l = 0, u = 0;
    t.GetTableCellProtectionLevels(rta_long(tab), rta_long(cell), &l, &u);
    return rta_dbl2(l, u);
}

extern "C" SEXP rta_tau_set_table_cell_protection_levels(SEXP self, SEXP tab,
                                                         SEXP cell, SEXP lpl,
                                                         SEXP upl) {
    TauArgus &t = *static_cast<TauArgus *>(R_ExternalPtrAddr(self));
    return rta_lgl_sexp(t.SetTableCellProtectionLevels(rta_long(tab),
                                                       rta_long(cell),
                                                       rta_dbl(lpl),
                                                       rta_dbl(upl)));
}

extern "C" SEXP rta_tau_set_table_cell_status_cell(SEXP self, SEXP tab,
                                                   SEXP cell, SEXP status) {
    TauArgus &t = *static_cast<TauArgus *>(R_ExternalPtrAddr(self));
    return rta_lgl_sexp(t.SetTableCellStatus(rta_long(tab), rta_long(cell),
                                             rta_long(status)));
}

/* Full cell read (22 fields). Always returns a named 22-element list; on
 * failure (bad dim_index, GetTableCell error) ok=FALSE and the numeric
 * fields are zero. Mirrors the pybind get_table_cell semantics: `topn`
 * (0 -> 1) truncates the score arrays returned. */
extern "C" SEXP rta_tau_get_table_cell(SEXP self, SEXP tab, SEXP dim_index,
                                       SEXP topn) {
    TauArgus &t = *static_cast<TauArgus *>(R_ExternalPtrAddr(self));
    std::vector<long> d = rta_long_vec(dim_index);
    bool ok = false;
    double resp = 0, rresp = 0, cta = 0, ckm = 0, shadow = 0, cost = 0;
    double key = 0, key_nz = 0, peep_cell = 0, peep_holding = 0;
    double lower = 0, upper = 0, rlower = 0, rupper = 0;
    long freq = 0, status = 0, holding_freq = 0;
    long dimensions = 0, cell_scores = 0, holding_scores = 0;
    long topn_l = rta_long(topn);
    std::vector<double> ms, msw, hms;
    std::vector<long> hnr;
    if (t.GetTableCellBufferSizes(rta_long(tab), &dimensions, &cell_scores,
                                  &holding_scores)
            && dimensions > 0 && d.size() == (size_t) dimensions) {
        const size_t msz = (size_t) (topn_l > 0 ? topn_l : 1);
        const size_t cell_cap = std::max(msz, (size_t) cell_scores);
        const size_t holding_cap = std::max(msz, (size_t) holding_scores);
        ms.assign(cell_cap, 0.0);
        msw.assign(cell_cap, 0.0);
        hms.assign(holding_cap, 0.0);
        hnr.assign(holding_cap, 0);
        long peep_sort_cell = 0, peep_sort_holding = 0;
        ok = t.GetTableCell(rta_long(tab), d.data(), &resp, &rresp, &cta,
                            &ckm, &shadow, &cost, &key, &key_nz, &freq,
                            &status, ms.data(), msw.data(), &holding_freq,
                            hms.data(), hnr.data(), &peep_cell,
                            &peep_holding, &peep_sort_cell,
                            &peep_sort_holding, &lower, &upper, &rlower,
                            &rupper);
        if (ok) {
            ms.resize(msz); msw.resize(msz); hms.resize(msz); hnr.resize(msz);
        }
    }
    SEXP r = PROTECT(Rf_allocVector(VECSXP, 22));
    SET_VECTOR_ELT(r, 0, rta_lgl_sexp(ok));
    SET_VECTOR_ELT(r, 1, rta_dbl_sexp(resp));
    SET_VECTOR_ELT(r, 2, rta_dbl_sexp(rresp));
    SET_VECTOR_ELT(r, 3, rta_dbl_sexp(cta));
    SET_VECTOR_ELT(r, 4, rta_dbl_sexp(ckm));
    SET_VECTOR_ELT(r, 5, rta_dbl_sexp(shadow));
    SET_VECTOR_ELT(r, 6, rta_dbl_sexp(cost));
    SET_VECTOR_ELT(r, 7, rta_dbl_sexp(key));
    SET_VECTOR_ELT(r, 8, rta_dbl_sexp(key_nz));
    SET_VECTOR_ELT(r, 9, rta_long_sexp(freq));
    SET_VECTOR_ELT(r, 10, rta_long_sexp(status));
    SEXP vms = PROTECT(Rf_allocVector(REALSXP, (int) ms.size()));
    for (size_t i = 0; i < ms.size(); i++) REAL(vms)[i] = ms[i];
    SET_VECTOR_ELT(r, 11, vms);
    SEXP vmsw = PROTECT(Rf_allocVector(REALSXP, (int) msw.size()));
    for (size_t i = 0; i < msw.size(); i++) REAL(vmsw)[i] = msw[i];
    SET_VECTOR_ELT(r, 12, vmsw);
    SET_VECTOR_ELT(r, 13, rta_long_sexp(holding_freq));
    SEXP vhms = PROTECT(Rf_allocVector(REALSXP, (int) hms.size()));
    for (size_t i = 0; i < hms.size(); i++) REAL(vhms)[i] = hms[i];
    SET_VECTOR_ELT(r, 14, vhms);
    SEXP vhnr = PROTECT(Rf_allocVector(INTSXP, (int) hnr.size()));
    for (size_t i = 0; i < hnr.size(); i++) INTEGER(vhnr)[i] = (int) hnr[i];
    SET_VECTOR_ELT(r, 15, vhnr);
    SET_VECTOR_ELT(r, 16, rta_dbl_sexp(peep_cell));
    SET_VECTOR_ELT(r, 17, rta_dbl_sexp(peep_holding));
    SET_VECTOR_ELT(r, 18, rta_dbl_sexp(lower));
    SET_VECTOR_ELT(r, 19, rta_dbl_sexp(upper));
    SET_VECTOR_ELT(r, 20, rta_dbl_sexp(rlower));
    SET_VECTOR_ELT(r, 21, rta_dbl_sexp(rupper));
    rta_set_names(r, "ok", "resp", "rresp", "cta", "ckm", "shadow", "cost",
                  "key", "key_nz", "freq", "status", "ms", "msw",
                  "holding_freq", "hms", "hnr", "peep_cell", "peep_holding",
                  "lower", "upper", "rlower", "rupper");
    UNPROTECT(5);
    return r;
}

extern "C" SEXP rta_tau_set_table_cell_cost(SEXP self, SEXP tab,
                                            SEXP dim_index, SEXP cost) {
    TauArgus &t = *static_cast<TauArgus *>(R_ExternalPtrAddr(self));
    std::vector<long> d = rta_long_vec(dim_index);
    return rta_lgl_sexp(t.SetTableCellCost(rta_long(tab), d.data(),
                                           rta_dbl(cost)));
}

extern "C" SEXP rta_tau_set_table_cell_status_dim(SEXP self, SEXP tab,
                                                  SEXP dim_index,
                                                  SEXP status) {
    TauArgus &t = *static_cast<TauArgus *>(R_ExternalPtrAddr(self));
    std::vector<long> d = rta_long_vec(dim_index);
    return rta_lgl_sexp(t.SetTableCellStatus(rta_long(tab), d.data(),
                                             rta_long(status)));
}

extern "C" SEXP rta_tau_set_protection_levels_dim(SEXP self, SEXP tab,
                                                  SEXP dim_index, SEXP lpl,
                                                  SEXP upl) {
    TauArgus &t = *static_cast<TauArgus *>(R_ExternalPtrAddr(self));
    std::vector<long> d = rta_long_vec(dim_index);
    return rta_lgl_sexp(t.SetProtectionLevelsForResponseTable(
        rta_long(tab), d.data(), rta_dbl(lpl), rta_dbl(upl)));
}

// ---------------------------------------------------------------------------
// Secondary suppression entry points
// ---------------------------------------------------------------------------
extern "C" SEXP rta_tau_set_secondary_jjformat(SEXP self, SEXP tab,
                                               SEXP file, SEXP with_bogus) {
    TauArgus &t = *static_cast<TauArgus *>(R_ExternalPtrAddr(self));
    long n = 0;
    long code = t.SetSecondaryJJFORMAT(rta_long(tab), rta_str(file).c_str(),
                                       rta_lgl(with_bogus), &n);
    // -> list(code, n_set_secondary)
    SEXP r = PROTECT(Rf_allocVector(VECSXP, 2));
    SET_VECTOR_ELT(r, 0, rta_long_sexp(code));
    SET_VECTOR_ELT(r, 1, rta_long_sexp(n));
    rta_set_names(r, "code", "n_set_secondary");
    UNPROTECT(1);
    return r;
}

extern "C" SEXP rta_tau_write_jj_format(SEXP self, SEXP tab, SEXP file,
                                        SEXP lo, SEXP hi, SEXP with_bogus,
                                        SEXP as_perc, SEXP for_rounding) {
    TauArgus &t = *static_cast<TauArgus *>(R_ExternalPtrAddr(self));
    return rta_lgl_sexp(t.WriteJJFormat(rta_long(tab), rta_str(file).c_str(),
                                        rta_dbl(lo), rta_dbl(hi),
                                        rta_lgl(with_bogus), rta_lgl(as_perc),
                                        rta_lgl(for_rounding)));
}

extern "C" SEXP rta_tau_prepare_hitas(SEXP self, SEXP tab, SEXP param,
                                      SEXP files, SEXP tau_temp) {
    TauArgus &t = *static_cast<TauArgus *>(R_ExternalPtrAddr(self));
    return rta_lgl_sexp(t.PrepareHITAS(rta_long(tab),
                                       rta_str(param).c_str(),
                                       rta_str(files).c_str(),
                                       rta_str(tau_temp).c_str()));
}

extern "C" SEXP rta_tau_set_secondary_hitas(SEXP self, SEXP tab) {
    TauArgus &t = *static_cast<TauArgus *>(R_ExternalPtrAddr(self));
    long n = 0;
    bool ok = t.SetSecondaryHITAS(rta_long(tab), &n);
    // -> list(ok, n_set_secondary)
    SEXP r = PROTECT(Rf_allocVector(VECSXP, 2));
    SET_VECTOR_ELT(r, 0, rta_lgl_sexp(ok));
    SET_VECTOR_ELT(r, 1, rta_long_sexp(n));
    rta_set_names(r, "ok", "n_set_secondary");
    UNPROTECT(1);
    return r;
}

extern "C" SEXP rta_tau_set_realized_lower_and_upper(SEXP self, SEXP tab,
                                                     SEXP cell, SEXP up,
                                                     SEXP lo) {
    TauArgus &t = *static_cast<TauArgus *>(R_ExternalPtrAddr(self));
    return rta_lgl_sexp(t.SetRealizedLowerAndUpper(rta_long(tab),
                                                   rta_long(cell),
                                                   rta_dbl(up), rta_dbl(lo)));
}

extern "C" SEXP rta_tau_set_rounded_response(SEXP self, SEXP file, SEXP tab) {
    TauArgus &t = *static_cast<TauArgus *>(R_ExternalPtrAddr(self));
    return rta_lgl_sexp(t.SetRoundedResponse(rta_str(file).c_str(),
                                             rta_long(tab)));
}

extern "C" SEXP rta_tau_set_cell_key_values_freq(SEXP self, SEXP tab,
                                                 SEXP ptable) {
    TauArgus &t = *static_cast<TauArgus *>(R_ExternalPtrAddr(self));
    int mn = 0, mx = 0;
    int ok = t.SetCellKeyValuesFreq(rta_long(tab), rta_str(ptable), &mn, &mx);
    // -> list(ok, min, max)
    SEXP r = PROTECT(Rf_allocVector(VECSXP, 3));
    SET_VECTOR_ELT(r, 0, rta_long_sexp(ok));
    SET_VECTOR_ELT(r, 1, rta_long_sexp(mn));
    SET_VECTOR_ELT(r, 2, rta_long_sexp(mx));
    rta_set_names(r, "ok", "min", "max");
    UNPROTECT(1);
    return r;
}

extern "C" SEXP rta_tau_set_cell_key_values_cont(SEXP self, SEXP tab,
                                                 SEXP ptable_cont,
                                                 SEXP ptable_sep,
                                                 SEXP ckm_type, SEXP top_k,
                                                 SEXP include_zeros,
                                                 SEXP parity,
                                                 SEXP separation, SEXP m1sqr,
                                                 SEXP scaling, SEXP s0,
                                                 SEXP s1, SEXP z_f, SEXP q,
                                                 SEXP epsilon, SEXP mu_c) {
    TauArgus &t = *static_cast<TauArgus *>(R_ExternalPtrAddr(self));
    std::vector<double> eps = rta_dbl_vec(epsilon);
    return rta_long_sexp(t.SetCellKeyValuesCont(
        rta_long(tab), rta_str(ptable_cont), rta_str(ptable_sep),
        rta_str(ckm_type), (int)rta_long(top_k), rta_lgl(include_zeros),
        rta_lgl(parity), rta_lgl(separation), rta_dbl(m1sqr),
        rta_str(scaling), rta_dbl(s0), rta_dbl(s1), rta_dbl(z_f),
        rta_dbl(q), eps.empty() ? nullptr : eps.data(), rta_dbl(mu_c)));
}

// ---------------------------------------------------------------------------
// Table input (tabular data flow)
// ---------------------------------------------------------------------------
extern "C" SEXP rta_tau_set_in_table(SEXP self, SEXP idx, SEXP codes,
                                     SEXP shadow, SEXP cost, SEXP resp,
                                     SEXP freq, SEXP maxscore,
                                     SEXP maxscore_hold, SEXP status,
                                     SEXP lpl, SEXP upl) {
    TauArgus &t = *static_cast<TauArgus *>(R_ExternalPtrAddr(self));
    std::vector<std::string> c = rta_str_vec(codes);
    std::vector<char *> cp(c.size());
    for (size_t i = 0; i < c.size(); i++)
        cp[i] = const_cast<char *>(c[i].c_str());
    std::vector<double> ms = rta_dbl_vec(maxscore);
    std::vector<double> mh = rta_dbl_vec(maxscore_hold);
    long err = 0, ev = 0;
    bool ok = t.SetInTable(rta_long(idx), cp.data(), rta_dbl(shadow),
                           rta_dbl(cost), rta_dbl(resp), rta_long(freq),
                           ms.empty() ? nullptr : ms.data(),
                           mh.empty() ? nullptr : mh.data(),
                           rta_long(status), rta_dbl(lpl), rta_dbl(upl), &err,
                           &ev);
    (void) err; (void) ev;
    // Logical, like the other Set* wrappers (the Python binding also
    // discards err/ev here).
    return rta_lgl_sexp(ok);
}

extern "C" SEXP rta_tau_set_in_code_list(SEXP self, SEXP var_index,
                                         SEXP codes) {
    TauArgus &t = *static_cast<TauArgus *>(R_ExternalPtrAddr(self));
    std::vector<std::string> c = rta_str_vec(codes);
    std::vector<char *> cp(c.size());
    for (size_t i = 0; i < c.size(); i++)
        cp[i] = const_cast<char *>(c[i].c_str());
    std::vector<long> v = rta_long_vec(var_index);
    long err = 0, ev = 0;
    bool ok = t.SetInCodeList((long) v.size(), v.data(), cp.data(), &err,
                              &ev);
    // -> list(ok, err, ev)
    SEXP r = PROTECT(Rf_allocVector(VECSXP, 3));
    SET_VECTOR_ELT(r, 0, rta_lgl_sexp(ok));
    SET_VECTOR_ELT(r, 1, rta_long_sexp(err));
    SET_VECTOR_ELT(r, 2, rta_long_sexp(ev));
    rta_set_names(r, "ok", "err", "ev");
    UNPROTECT(1);
    return r;
}

extern "C" SEXP rta_tau_set_totals_in_code_list(SEXP self, SEXP var_index) {
    TauArgus &t = *static_cast<TauArgus *>(R_ExternalPtrAddr(self));
    std::vector<long> v = rta_long_vec(var_index);
    long err = 0, ev = 0;
    bool ok = t.SetTotalsInCodeList((long) v.size(), v.data(), &err, &ev);
    // -> list(ok, err, ev)
    SEXP r = PROTECT(Rf_allocVector(VECSXP, 3));
    SET_VECTOR_ELT(r, 0, rta_lgl_sexp(ok));
    SET_VECTOR_ELT(r, 1, rta_long_sexp(err));
    SET_VECTOR_ELT(r, 2, rta_long_sexp(ev));
    rta_set_names(r, "ok", "err", "ev");
    UNPROTECT(1);
    return r;
}

extern "C" SEXP rta_tau_completed_table(SEXP self, SEXP idx, SEXP file,
                                        SEXP calc_totals,
                                        SEXP calc_totals_safe,
                                        SEXP for_cover) {
    TauArgus &t = *static_cast<TauArgus *>(R_ExternalPtrAddr(self));
    long err = 0;
    bool ok = t.CompletedTable(rta_long(idx), &err, rta_str(file).c_str(),
                               rta_lgl(calc_totals),
                               rta_lgl(calc_totals_safe),
                               rta_lgl(for_cover));
    // -> list(ok, err)
    SEXP r = PROTECT(Rf_allocVector(VECSXP, 2));
    SET_VECTOR_ELT(r, 0, rta_lgl_sexp(ok));
    SET_VECTOR_ELT(r, 1, rta_long_sexp(err));
    rta_set_names(r, "ok", "err");
    UNPROTECT(1);
    return r;
}

// ---------------------------------------------------------------------------
// Output writers
// ---------------------------------------------------------------------------
extern "C" SEXP rta_tau_write_cell_records(SEXP self, SEXP tab, SEXP file,
                                           SEXP sbs, SEXP sbs_level,
                                           SEXP suppress_empty,
                                           SEXP first_line,
                                           SEXP show_unsafe,
                                           SEXP embed_quotes,
                                           SEXP resp_type) {
    TauArgus &t = *static_cast<TauArgus *>(R_ExternalPtrAddr(self));
    return rta_lgl_sexp(t.WriteCellRecords(
        rta_long(tab), rta_str(file).c_str(), rta_long(sbs),
        rta_lgl(sbs_level), rta_lgl(suppress_empty),
        rta_str(first_line).c_str(), rta_lgl(show_unsafe),
        rta_lgl(embed_quotes), rta_long(resp_type)));
}

extern "C" SEXP rta_tau_write_csv(SEXP self, SEXP tab, SEXP file,
                                  SEXP embed_quotes, SEXP dim_seq,
                                  SEXP resp_type) {
    TauArgus &t = *static_cast<TauArgus *>(R_ExternalPtrAddr(self));
    std::vector<long> d = rta_long_vec(dim_seq);
    // The native WriteCSV dereferences DimSequence[d] for d < nDim, so a
    // NULL is not acceptable: fall back to the identity permutation 0..MAXDIM-1
    // (the Python engine always passes list(range(10))).
    if (d.empty()) {
        for (long i = 0; i < MAXDIM; i++) d.push_back(i);
    }
    return rta_lgl_sexp(t.WriteCSV(rta_long(tab), rta_str(file).c_str(),
                                   rta_lgl(embed_quotes), d.data(),
                                   rta_long(resp_type)));
}
