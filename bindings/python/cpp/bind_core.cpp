// Core TauArgus bindings. This TU only includes core headers, so the core
// `IProgressListener` (single UpdateProgress) is the one in scope.

#include <pybind11/pybind11.h>
#include <pybind11/stl.h>

#include <string>
#include <vector>
#include <algorithm>

#include "TauArgus.h"
#include "init_decls.h"

namespace py = pybind11;
using namespace py::literals;

void init_core(py::module_ &m) {
    py::class_<TauArgus>(m, "TauArgus")
        .def(py::init<>())

        .def("clean_all", &TauArgus::CleanAll)
        .def("version", &TauArgus::GetVersion)
        .def("error_string", [](TauArgus &t, long code) {
            return t.GetErrorString(code);
        }, py::arg("code"), "Human-readable text for a native error code.")

        // -- input file / exploration --------------------------------------
        .def("set_in_file_info", &TauArgus::SetInFileInfo,
             py::arg("is_fixed_format"), py::arg("separator"))
        .def("explore_file", [](TauArgus &t, const std::string &file) {
            long err = 0, line = 0, var = 0;
            bool ok;
            {
                // File scan can take a while on large inputs; keep other
                // threads (TUI event loop) running (see through_table).
                py::gil_scoped_release release;
                ok = t.ExploreFile(file.c_str(), &err, &line, &var);
            }
            return py::make_tuple(ok, err, line, var);
        }, py::arg("file"), "Explore an input file. -> (ok, err, line, var).")

        // -- dimensions ----------------------------------------------------
        .def("set_number_tab", &TauArgus::SetNumberTab, py::arg("n_tab"))
        .def("set_number_var", &TauArgus::SetNumberVar, py::arg("n_var"))

        // -- variables -----------------------------------------------------
        .def("set_variable", [](TauArgus &t, long idx, long b_pos, long n_pos,
                                 long n_dec, long n_missing,
                                 const std::string &m1, const std::string &m2,
                                 const std::string &total, bool is_peeper,
                                 const std::string &p1, const std::string &p2,
                                 bool is_cat, bool is_num, bool is_weight,
                                 bool is_hier, bool is_holding, bool is_rec) {
            return t.SetVariable(idx, b_pos, n_pos, n_dec, n_missing,
                                  m1.c_str(), m2.c_str(), total.c_str(), is_peeper,
                                  p1.c_str(), p2.c_str(), is_cat, is_num, is_weight,
                                  is_hier, is_holding, is_rec);
        }, py::arg("index"), py::arg("b_pos"), py::arg("n_pos"), py::arg("n_dec"),
           py::arg("n_missing"), py::arg("missing1"), py::arg("missing2"),
           py::arg("total_code"), py::arg("is_peeper"), py::arg("peeper_code1"),
           py::arg("peeper_code2"), py::arg("is_categorical"), py::arg("is_numeric"),
           py::arg("is_weight"), py::arg("is_hierarchical"), py::arg("is_holding"),
           py::arg("is_record_key"))
        .def("set_hierarchical_codelist", &TauArgus::SetHierarchicalCodelist,
             py::arg("var"), py::arg("file"), py::arg("level_string"))
        .def("set_hierarchical_digits", [](TauArgus &t, long var,
                                           const std::vector<long> &digits) {
            std::vector<long> d = digits;
            return t.SetHierarchicalDigits(var, (long)d.size(), d.data());
        }, py::arg("var"), py::arg("digits"))
        .def("get_var_number_of_codes", [](TauArgus &t, long var) {
            long n = 0, na = 0;
            t.GetVarNumberOfCodes(var, &n, &na);
            return py::make_tuple(n, na);
        }, py::arg("var"), "-> (n_codes, n_active_codes)")
        .def("get_var_code", [](TauArgus &t, long var, long code) {
            long ctype = 0, missing = 0, level = 0;
            std::string cs;
            bool ok = t.GetVarCode(var, code, &ctype, &cs, &missing, &level);
            return py::make_tuple(ok, ctype, cs, missing, level);
        }, py::arg("var"), py::arg("code"),
           "-> (ok, code_type, code_string, is_missing, level)")
        .def("get_var_code_properties", [](TauArgus &t, long var, long code) {
            long parent = 0, active = 0, missing = 0, level = 0, nchild = 0;
            const char *c = nullptr;
            bool ok = t.GetVarCodeProperties(var, code, &parent, &active, &missing,
                                             &level, &nchild, &c);
            std::string cs = c ? std::string(c) : std::string();
            return py::make_tuple(ok, parent, active, missing, level, nchild, cs);
        }, py::arg("var"), py::arg("code"),
           "-> (ok, is_parent, is_active, is_missing, level, n_children, code)")
        .def("set_var_code_active", &TauArgus::SetVarCodeActive,
             py::arg("var"), py::arg("code"), py::arg("active"))
        .def("do_active_recode", &TauArgus::DoActiveRecode, py::arg("var"),
             py::call_guard<py::gil_scoped_release>())
        .def("apply_recode", &TauArgus::ApplyRecode,
             py::call_guard<py::gil_scoped_release>())
        .def("undo_recode", &TauArgus::UndoRecode, py::arg("var"),
             py::call_guard<py::gil_scoped_release>())
        .def("do_recode", [](TauArgus &t, long var, const std::string &data,
                              long n_missing, const std::string &missing1,
                              const std::string &missing2) {
            long et = 0, el = 0, ep = 0;
            const char *warn = nullptr;
            bool ok;
            {
                py::gil_scoped_release release;
                ok = t.DoRecode(var, data.c_str(), n_missing, missing1.c_str(),
                                missing2.c_str(), &et, &el, &ep, &warn);
            }
            std::string w = warn ? warn : "";
            return py::make_tuple(ok, et, el, ep, w);
        }, py::arg("var"), py::arg("recode_data"), py::arg("n_missing"),
           py::arg("missing1"), py::arg("missing2"))

        // -- table specification --------------------------------------------
        .def("set_table", [](TauArgus &t, long idx,
                             const std::vector<long> &explanatory, bool is_freq,
                             long resp, long shadow, long cost, long cellkey,
                             const std::string &ckm_type, long ckm_topk,
                             double lambda, double max_scaled_cost, long peep_var,
                             bool missing_as_safe) {
            std::vector<long> e = explanatory;
            return t.SetTable(idx, (long)e.size(), e.data(), is_freq, resp, shadow,
                              cost, cellkey, ckm_type, ckm_topk, lambda,
                              max_scaled_cost, peep_var, missing_as_safe);
        }, py::arg("index"), py::arg("explanatory_vars"), py::arg("is_frequency"),
           py::arg("response_var"), py::arg("shadow_var"), py::arg("cost_var"),
           py::arg("cellkey_var"), py::arg("ckm_type") = "", py::arg("ckm_topk") = 0,
           py::arg("lam") = 0.0, py::arg("max_scaled_cost") = 0.0,
           py::arg("peep_var") = -1, py::arg("missing_as_safe") = false)
        .def("set_table_safety_info", [](TauArgus &t, long idx, bool has_maxscore,
             bool dom, const std::vector<long> &dom_n, const std::vector<long> &dom_p,
             bool pq, const std::vector<long> &pq_p, const std::vector<long> &pq_q,
             const std::vector<long> &pq_n, bool has_freq, long freq_perc,
             long safe_min_rec, bool has_status, long manual_perc, bool zero_rule,
             double zero_range, bool empty_as_ns, long ns_range) {
            std::vector<long> a(dom_n), b(dom_p), c(pq_p), d(pq_q), e(pq_n);
            long errc = 0;
            return t.SetTableSafetyInfo(idx, has_maxscore, dom,
                    a.empty() ? nullptr : a.data(), b.empty() ? nullptr : b.data(),
                    pq, c.empty() ? nullptr : c.data(), d.empty() ? nullptr : d.data(),
                    e.empty() ? nullptr : e.data(), has_freq, freq_perc, safe_min_rec,
                    has_status, manual_perc, zero_rule, zero_range, empty_as_ns,
                    ns_range, &errc);
         }, py::arg("index"), py::arg("has_max_score"), py::arg("dominance_rule"),
            py::arg("dominance_number"), py::arg("dominance_perc"), py::arg("pq_rule"),
            py::arg("pq_p"), py::arg("pq_q"), py::arg("pq_n"), py::arg("has_freq"),
            py::arg("freq_safety_perc"), py::arg("safe_min_rec"), py::arg("has_status"),
            py::arg("manual_safety_perc"), py::arg("apply_zero_rule"),
            py::arg("zero_safety_range"), py::arg("empty_as_non_structural"),
            py::arg("ns_empty_safety_range"))
        .def("set_table_safety", [](TauArgus &t, long idx, bool dom,
              const std::vector<long> &dom_n, const std::vector<long> &dom_k,
              bool pq, const std::vector<long> &pq_p, const std::vector<long> &pq_q,
              const std::vector<long> &pq_n, const std::vector<long> &min_freq,
              const std::vector<long> &peep_perc, const std::vector<long> &peep_range,
              const std::vector<long> &peep_minfreq, bool apply_peep, bool apply_weight,
              bool weight_on_safety, bool apply_holding, bool zero_rule,
              bool empty_as_ns, long ns_range, double zero_range, long manual_perc,
              const std::vector<long> &freq_perc) {
             std::vector<long> a(dom_n), b(dom_k), c(pq_p), d(pq_q), e(pq_n);
             std::vector<long> f(min_freq), g(peep_perc), h(peep_range), i(peep_minfreq), j(freq_perc);
             auto or2 = [](std::vector<long> &v, long dft) {
                 while (v.size() < 4) v.push_back(dft);  // PeepPerc is read as [0..3]
             };
             or2(a, 0); or2(b, 0); or2(c, 0); or2(d, 100); or2(e, 0);
             or2(f, 0); or2(g, 0); or2(h, 0); or2(i, 0); or2(j, 0);
             return t.SetTableSafety(idx, dom, a.data(), b.data(), pq, c.data(),
                     d.data(), e.data(), f.data(), g.data(), h.data(), i.data(),
                     apply_peep, apply_weight, weight_on_safety, apply_holding,
                     zero_rule, empty_as_ns, ns_range, zero_range, manual_perc,
                     j.data());
         }, py::arg("index"), py::arg("dominance_rule"), py::arg("dominance_number"),
            py::arg("dominance_k"), py::arg("pq_rule"), py::arg("pq_p"),
            py::arg("pq_q"), py::arg("pq_n"), py::arg("min_freq"),
            py::arg("peep_percentage"), py::arg("peep_marge"),
            py::arg("peep_min_freq"), py::arg("apply_peep"), py::arg("apply_weight"),
            py::arg("weight_on_safety_rule"), py::arg("apply_holding"),
            py::arg("apply_zero_rule"), py::arg("empty_as_non_structural"),
            py::arg("ns_empty_safety_range"), py::arg("zero_safety_range"),
            py::arg("manual_safety_perc"), py::arg("cell_holding_freq_safety_perc"))

        // -- compute ---------------------------------------------------------
        // The solver calls below run HiGHS, which can take seconds to minutes.
        // They release the GIL for the duration of the call so that other
        // threads (e.g. the TUI event loop rendering the spinner / accepting
        // keys while a solve runs in a worker thread) keep running.
        .def("through_table", &TauArgus::ThroughTable,
             py::call_guard<py::gil_scoped_release>())
        .def("compute_tables", [](TauArgus &t) {
            long err = 0, tab = 0;
            bool ok;
            {
                py::gil_scoped_release release;
                ok = t.ComputeTables(&err, &tab);
            }
            return py::make_tuple(ok, err, tab);
        }, "-> (ok, err, table_index)")
        .def("get_minimum_cell_value", [](TauArgus &t, long tab) {
            double mx = 0;
            double mn = t.GetMinimumCellValue(tab, &mx);
            return py::make_tuple(mn, mx);
        }, py::arg("tab"), "-> (min, max)")
        .def("maximum_protection_level", &TauArgus::MaximumProtectionLevel,
             py::arg("tab"))

        // -- cell read -------------------------------------------------------
        .def("get_table_cell_value", [](TauArgus &t, long tab, long cell) {
            double r = 0;
            t.GetTableCellValue(tab, cell, &r);
            return r;
        }, py::arg("tab"), py::arg("cell"))
        .def("get_table_cell_status", [](TauArgus &t, long tab, long cell) {
            long s = 0;
            t.GetTableCellStatus(tab, cell, &s);
            return s;
        }, py::arg("tab"), py::arg("cell"))
        .def("get_table_cell_protection_levels", [](TauArgus &t, long tab,
                                                     long cell) {
            double l = 0, u = 0;
            t.GetTableCellProtectionLevels(tab, cell, &l, &u);
            return py::make_tuple(l, u);
        }, py::arg("tab"), py::arg("cell"))
        .def("get_table_cell", [](TauArgus &t, long tab,
                                  const std::vector<long> &dim_index,
                                  long topn) -> py::tuple {
            std::vector<long> d = dim_index;
            long dimensions = 0, cell_scores = 0, holding_scores = 0;
            if (!t.GetTableCellBufferSizes(tab, &dimensions, &cell_scores,
                                           &holding_scores)
                    || dimensions <= 0 || d.size() != (size_t)dimensions) {
                return py::make_tuple(false);
            }
            const size_t msz = (size_t)(topn > 0 ? topn : 1);
            double resp = 0, rresp = 0, cta = 0, ckm = 0, shadow = 0, cost = 0;
            double key = 0, key_nz = 0, peep_cell = 0, peep_holding = 0;
            double lower = 0, upper = 0, rlower = 0, rupper = 0;
            long freq = 0, status = 0, holding_freq = 0;
            // GetTableCell always writes all configured scores. `topn` only
            // limits the arrays returned to Python after the native call.
            const size_t cell_cap = std::max(msz, (size_t)cell_scores);
            const size_t holding_cap = std::max(msz, (size_t)holding_scores);
            std::vector<double> ms(cell_cap, 0.0), msw(cell_cap, 0.0);
            std::vector<double> hms(holding_cap, 0.0);
            std::vector<long> hnr(holding_cap, 0);
            long peep_sort_cell = 0, peep_sort_holding = 0;
            bool ok = t.GetTableCell(
                    tab, d.data(), &resp, &rresp, &cta, &ckm, &shadow, &cost,
                    &key, &key_nz, &freq, &status, ms.data(), msw.data(),
                    &holding_freq, hms.data(), hnr.data(), &peep_cell,
                    &peep_holding, &peep_sort_cell, &peep_sort_holding, &lower,
                    &upper, &rlower, &rupper);
            if (!ok) return py::make_tuple(false);
            ms.resize(msz); msw.resize(msz); hms.resize(msz); hnr.resize(msz);
            return py::make_tuple(true, resp, rresp, cta, ckm, shadow, cost,
                                   key, key_nz, freq, status, ms, msw,
                                   holding_freq, hms, hnr, peep_cell,
                                   peep_holding, lower, upper, rlower, rupper);
        }, py::arg("tab"), py::arg("dim_index"), py::arg("topn") = 0)
        .def("get_total_table_size", [](TauArgus &t, long tab) {
            long ncell = 0, size = 0;
            t.GetTotalTabelSize(tab, &ncell, &size);
            return py::make_tuple(ncell, size);
        }, py::arg("tab"), "-> (n_cells, size_data_cell)")

        // -- cell write / status --------------------------------------------
        .def("set_table_cell_cost", [](TauArgus &t, long tab,
                                       const std::vector<long> &dim, double cost) {
            std::vector<long> d = dim;
            return t.SetTableCellCost(tab, d.data(), cost);
        }, py::arg("tab"), py::arg("dim_index"), py::arg("cost"))
        .def("set_table_cell_status_dim", [](TauArgus &t, long tab,
                                             const std::vector<long> &dim, long status) {
            std::vector<long> d = dim;
            return t.SetTableCellStatus(tab, d.data(), status);
        }, py::arg("tab"), py::arg("dim_index"), py::arg("status"))
        .def("set_table_cell_status_cell", [](TauArgus &t, long tab, long cell,
                                              long status) {
            return t.SetTableCellStatus(tab, cell, status);
        }, py::arg("tab"), py::arg("cell"), py::arg("status"))
        .def("set_table_cell_protection_levels",
             &TauArgus::SetTableCellProtectionLevels, py::arg("tab"), py::arg("cell"),
             py::arg("lpl"), py::arg("upl"))
        .def("set_protection_levels_dim", [](TauArgus &t, long tab,
                                             const std::vector<long> &dim,
                                             double lpl, double upl) {
            std::vector<long> d = dim;
            return t.SetProtectionLevelsForResponseTable(tab, d.data(), lpl, upl);
        }, py::arg("tab"), py::arg("dim_index"), py::arg("lpl"), py::arg("upl"))
        .def("set_all_empty_non_structural", &TauArgus::SetAllEmptyNonStructural,
             py::arg("tab"))

        // -- secondary suppression entry points -----------------------------
        .def("set_secondary_jjformat", [](TauArgus &t, long tab,
                                          const std::string &file, bool with_bogus) {
            long n = 0;
            long code = t.SetSecondaryJJFORMAT(tab, file.c_str(), with_bogus, &n);
            return py::make_tuple(code, n);
        }, py::arg("tab"), py::arg("file"), py::arg("with_bogus") = false,
           "-> (code, n_set_secondary)")
        .def("write_jj_format", &TauArgus::WriteJJFormat, py::arg("tab"),
             py::arg("file"), py::arg("lower"), py::arg("upper"),
             py::arg("with_bogus") = false, py::arg("as_perc") = false,
             py::arg("for_rounding") = false,
             py::call_guard<py::gil_scoped_release>())
        .def("prepare_hitas", &TauArgus::PrepareHITAS, py::arg("tab"),
             py::arg("name_param_file"), py::arg("name_files_file"), py::arg("tau_temp"))
        .def("set_secondary_hitas", [](TauArgus &t, long tab) {
            long n = 0;
            bool ok = t.SetSecondaryHITAS(tab, &n);
            return py::make_tuple(ok, n);
        }, py::arg("tab"), "-> (ok, n_set_secondary)")
        .def("write_ghmiter_data_cell", &TauArgus::WriteGHMITERDataCell,
             py::arg("file"), py::arg("tab"), py::arg("is_singleton"))
        .def("write_ghmiter_stuer", &TauArgus::WriteGHMITERSteuer, py::arg("file"),
             py::arg("end1"), py::arg("end2"), py::arg("tab"))
        .def("set_secondary_ghmiter", [](TauArgus &t, const std::string &file,
                                         long tab, bool is_singleton) {
            long n = 0;
            long code = t.SetSecondaryGHMITER(file.c_str(), tab, &n, is_singleton);
            return py::make_tuple(code, n);
        }, py::arg("file"), py::arg("tab"), py::arg("is_singleton") = false,
           "-> (code, n_set_secondary)")
        .def("set_secondary_from_hierarchical_ampl", [](TauArgus &t,
                                                        const std::string &file,
                                                        long tab) {
            long err = 0;
            bool ok = t.SetSecondaryFromHierarchicalAMPL(file.c_str(), tab, &err);
            return py::make_tuple(ok, err);
        }, py::arg("file"), py::arg("tab"))
        .def("write_hierarchical_table_in_ampl_format",
             [](TauArgus &t, const std::string &file, const std::string &temp,
                long tab, double max_scale) {
            long err = 0;
            bool ok = t.WriteHierarchicalTableInAMPLFormat(file.c_str(), temp.c_str(),
                                                           tab, max_scale, &err);
            return py::make_tuple(ok, err);
        }, py::arg("ampl_file"), py::arg("temp_dir"), py::arg("tab"), py::arg("max_scale"))
        .def("set_cta_values", [](TauArgus &t, long tab, long cell, double org,
                                  double cta) {
            long sec = 0;
            return py::make_tuple(t.SetCTAValues(tab, cell, org, cta, &sec), sec);
        }, py::arg("tab"), py::arg("cell"), py::arg("org_val"), py::arg("cta_val"))
        .def("set_realized_lower_and_upper", &TauArgus::SetRealizedLowerAndUpper,
             py::arg("tab"), py::arg("cell"), py::arg("upper"), py::arg("lower"))
        .def("set_rounded_response", &TauArgus::SetRoundedResponse, py::arg("file"),
             py::arg("tab"))
        .def("set_cell_key_values_freq", [](TauArgus &t, long tab,
                                            const std::string &ptable) {
            int mn = 0, mx = 0;
            return py::make_tuple(t.SetCellKeyValuesFreq(tab, ptable, &mn, &mx), mn, mx);
        }, py::arg("tab"), py::arg("ptable_file"))
        .def("set_cell_key_values_cont", [](TauArgus &t, long tab,
                                            const std::string &ptable_cont,
                                            const std::string &ptable_sep,
                                            const std::string &ckm_type, int top_k,
                                            bool zeros, bool parity, bool separation,
                                            double m1sqr, const std::string &scaling,
                                            double s0, double s1, double z_f, double q,
                                            const std::vector<double> &epsilon,
                                            double mu_c) {
            std::vector<double> eps = epsilon;
            return t.SetCellKeyValuesCont(tab, ptable_cont, ptable_sep, ckm_type,
                    top_k, zeros, parity, separation, m1sqr, scaling, s0, s1, z_f, q,
                    eps.data(), mu_c);
        }, py::arg("tab"), py::arg("ptable_file_cont"), py::arg("ptable_file_sep"),
           py::arg("ckm_type"), py::arg("top_k"), py::arg("include_zeros"),
           py::arg("parity"), py::arg("separation"), py::arg("m1sqr"),
           py::arg("scaling"), py::arg("sigma0"), py::arg("sigma1"), py::arg("xstar"),
           py::arg("q"), py::arg("epsilon"), py::arg("mu_c"))
        .def("undo_secondary_suppress", &TauArgus::UndoSecondarySuppress,
             py::arg("tab"), py::arg("sort") = 1)

        // -- table input (tabular data flow) --------------------------------
        .def("set_in_table", [](TauArgus &t, long idx,
                                const std::vector<std::string> &codes, double shadow,
                                double cost, double resp, long freq,
                                const std::vector<double> &maxscore,
                                const std::vector<double> &maxscore_hold, long status,
                                double lpl, double upl) {
            long err = 0, ev = 0;
            std::vector<std::string> c = codes;
            std::vector<char *> cp(c.size());
            for (size_t i = 0; i < c.size(); i++) cp[i] = const_cast<char *>(c[i].c_str());
            std::vector<double> ms(maxscore), mh(maxscore_hold);
            return t.SetInTable(idx, cp.data(), shadow, cost, resp, freq,
                    ms.empty() ? nullptr : ms.data(),
                    mh.empty() ? nullptr : mh.data(), status, lpl, upl, &err, &ev);
        }, py::arg("index"), py::arg("codes"), py::arg("shadow"), py::arg("cost"),
           py::arg("response"), py::arg("freq"), py::arg("max_score_cell"),
           py::arg("max_score_holding"), py::arg("status"), py::arg("lpl"),
           py::arg("upl"))
        .def("set_in_code_list", [](TauArgus &t, const std::vector<long> &var_index,
                                    const std::vector<std::string> &codes) {
            long err = 0, ev = 0;
            std::vector<std::string> c = codes;
            std::vector<char *> cp(c.size());
            for (size_t i = 0; i < c.size(); i++) cp[i] = const_cast<char *>(c[i].c_str());
            std::vector<long> v = var_index;
            bool ok = t.SetInCodeList((long)v.size(), v.data(), cp.data(), &err, &ev);
            return py::make_tuple(ok, err, ev);
        }, py::arg("var_index"), py::arg("codes"))
        .def("set_totals_in_code_list", [](TauArgus &t,
                                           const std::vector<long> &var_index) {
            long err = 0, ev = 0;
            std::vector<long> v = var_index;
            bool ok = t.SetTotalsInCodeList((long)v.size(), v.data(), &err, &ev);
            return py::make_tuple(ok, err, ev);
        }, py::arg("var_index"))
        .def("completed_table", [](TauArgus &t, long idx, const std::string &file,
                                    bool calc_totals, bool calc_totals_safe,
                                    bool for_cover) {
            long err = 0;
            bool ok = t.CompletedTable(idx, &err, file.c_str(), calc_totals,
                                       calc_totals_safe, for_cover);
            return py::make_tuple(ok, err);
        }, py::arg("index"), py::arg("file"), py::arg("compute_totals"),
           py::arg("calculated_totals_as_safe") = false,
           py::arg("for_cover_table") = false)
        .def("write_cell_records", &TauArgus::WriteCellRecords, py::arg("tab"),
             py::arg("file"), py::arg("sbs"), py::arg("sbs_level") = false,
             py::arg("suppress_empty") = false, py::arg("first_line") = "",
             py::arg("show_unsafe") = false, py::arg("embed_quotes") = true,
             py::arg("resp_type") = 1)
        .def("write_csv", [](TauArgus &t, long tab, const std::string &file,
                             bool embed_quotes, const std::vector<long> &dim_seq,
                             long resp_type) {
            std::vector<long> d = dim_seq;
            return t.WriteCSV(tab, file.c_str(), embed_quotes,
                              d.empty() ? nullptr : d.data(), resp_type);
        }, py::arg("tab"), py::arg("file"), py::arg("embed_quotes") = true,
           py::arg("dim_sequence") = py::list(), py::arg("resp_type") = 1);
}
