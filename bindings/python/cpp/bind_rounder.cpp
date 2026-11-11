// RounderCtrl bindings (controlled rounding via CRP/HiGHS).
// Uses RProgressListener/RCallback (distinct names) — no IProgressListener
// collision, but kept in its own TU for clarity.

#include <pybind11/pybind11.h>
#include <pybind11/stl.h>

#include <string>
#include <vector>

#include "RounderCtrl.h"
#include "init_decls.h"
#include "input_guards.h"

namespace py = pybind11;
using namespace py::literals;
namespace g = tauargus::guards;

void init_rounder(py::module_ &m) {
    py::class_<RounderCtrl>(m, "RounderCtrl")
        .def(py::init<>())
        .def("version", &RounderCtrl::GetVersion)
        .def("error_string", [](RounderCtrl &r, long code) {
            return r.GetErrorString((int) code);
        }, py::arg("code"))
        .def("set_double_constant", &RounderCtrl::SetDoubleConstant,
             py::arg("variable"), py::arg("value"))
        .def("do_round", [](RounderCtrl &r, const std::string &solver,
                             const std::string &in_file, double base,
                             const std::vector<double> &upper,
                             const std::vector<double> &lower, long auditing,
                             const std::string &solution,
                             const std::string &statistics, long max_time,
                             long zero_restricted) {
            g::finite_non_negative("base", base);
            // +/-Inf bounds are legal (unbounded); NaN never is.
            g::finite_or_inf_vec("upper_bound", upper);
            g::finite_or_inf_vec("lower_bound", lower);
            g::non_negative("auditing", auditing);
            g::non_negative("max_time", max_time);
            g::non_negative("zero_restricted", zero_restricted);
            std::vector<double> u = upper, l = lower;
            double mj = 0;
            long nj = 0;
            double ut = 0;
            long ec = 0;
            int result;
            {
                // Run the HiGHS MIP without the GIL so other threads (TUI
                // event loop, concurrent workers) keep running during the solve.
                py::gil_scoped_release release;
                result = r.DoRound(const_cast<char *>(solver.c_str()),
                                    const_cast<char *>(in_file.c_str()), base,
                                    u.empty() ? nullptr : u.data(),
                                    l.empty() ? nullptr : l.data(), auditing,
                                    const_cast<char *>(solution.c_str()),
                                    const_cast<char *>(statistics.c_str()), nullptr,
                                    nullptr, max_time, zero_restricted, nullptr, &mj,
                                    &nj, &ut, &ec);
            }
            return py::make_tuple(result, mj, nj, ut, ec);
        }, py::arg("solver"), py::arg("in_file"), py::arg("base"),
           py::arg("upper_bound") = py::list(), py::arg("lower_bound") = py::list(),
           py::arg("auditing") = 0, py::arg("solution_file") = "",
           py::arg("statistics_file") = "", py::arg("max_time") = 0,
           py::arg("zero_restricted") = 0,
           "-> (result, max_jump, n_jump, used_time, error_code)");
}
