// HiTaSCtrl bindings. This TU only includes hitas headers, so the hitas
// `IProgressListener` (UpdateLB/UB/Groups/Tables/...) is the one in scope —
// it must never share a TU with core's different `IProgressListener`.

#include <pybind11/pybind11.h>
#include <pybind11/stl.h>

#include <string>

#include "HiTaSCtrl.h"
#include "init_decls.h"
#include "input_guards.h"

namespace py = pybind11;
using namespace py::literals;
namespace g = tauargus::guards;

void init_hitas(py::module_ &m) {
    py::class_<HiTaSCtrl>(m, "HiTaSCtrl")
        .def(py::init<>())
        .def("set_jj_constants_int", &HiTaSCtrl::SetJJconstantsInt,
             py::arg("name"), py::arg("value"))
        .def("set_jj_constants_dbl", &HiTaSCtrl::SetJJconstantsDbl,
             py::arg("name"), py::arg("value"))
        .def("set_debug_mode", &HiTaSCtrl::SetDebugMode, py::arg("debug"))
        .def("version", &HiTaSCtrl::GetVersion)
        .def("error_string", &HiTaSCtrl::GetErrorString, py::arg("code"))
        .def("full_jj", [](HiTaSCtrl &h, const std::string &in, const std::string &out,
                            long max_time, const std::string &ilm,
                            const std::string &out_dir, const std::string &solver) {
            g::non_negative("max_time", max_time);
            // The legacy port throws raw int error codes from its file
            // operations (OpenFile, Amyio.cpp). pybind11 only translates
            // std::exception, so an int crossing the boundary is undefined
            // behavior; convert it to the return code the callers check.
            try {
                return h.FullJJ(in.c_str(), out.c_str(), max_time, ilm.c_str(),
                                out_dir.c_str(), solver.c_str());
            } catch (int code) {
                return static_cast<long>(code);
            }
        }, py::arg("in_file_jj"), py::arg("out_file"), py::arg("max_time") = 0,
            py::arg("ilm_file") = "", py::arg("out_dir") = "",
            py::arg("solver") = "SCIP",
            "Optimal cell suppression (FullJJ). Returns a status code.",
            // Run the HiGHS MIP without the GIL so other threads (TUI event
            // loop, concurrent workers) keep running during the solve.
            py::call_guard<py::gil_scoped_release>())
        .def("a_hitas", [](HiTaSCtrl &h, const std::string &pars, const std::string &files,
                            long max_time, const std::string &ilm,
                            const std::string &tau_out, const std::string &solver,
                            bool single_with_single, bool single_with_more,
                            bool do_count_bounds) {
            g::non_negative("max_time", max_time);
            // Same int-throw containment as full_jj (CheckStart runs
            // before any internal try block, AHiTaS HiTaSCtrl.cpp:706).
            try {
                return h.AHiTaS(pars.c_str(), files.c_str(), max_time, ilm.c_str(),
                                tau_out.c_str(), solver.c_str(), single_with_single,
                                single_with_more, do_count_bounds);
            } catch (int code) {
                return static_cast<long>(code);
            }
        }, py::arg("pars_file"), py::arg("files_file"), py::arg("max_time") = 0,
            py::arg("ilm_file") = "", py::arg("tau_out_dir") = "",
            py::arg("solver") = "SCIP", py::arg("single_with_single") = false,
           py::arg("single_with_more") = false, py::arg("do_count_bounds") = false,
           "Modular (hierarchical iterative) cell suppression. Returns a status code.",
            // Run the HiGHS MIP without the GIL (see full_jj).
            py::call_guard<py::gil_scoped_release>());
}
