// CSP audit (realized feasibility intervals) bindings. This TU only declares
// the extern "C" TauAuditJj entry point from the tauargus_csp shared lib, so
// it never pulls in the csp HiGHS/VSCIP headers and can safely share the
// module with the core/hitas/rounder namespaces.

#include <pybind11/pybind11.h>
#include <pybind11/stl.h>

#include <string>
#include <stdexcept>
#include <vector>

#include "init_decls.h"

namespace py = pybind11;

// From native/csp/src/cspaudit.h
extern "C" {
int TauAuditJj(const char *jjfile,
               int *n_out,
               long **cell_idx,
               double **a_min,
               double **a_max,
               double **a_value,
               char **a_status,
               int **a_unsafe);
void TauAuditJjFree(int n, long *cell_idx, double *a_min, double *a_max,
                    double *a_value, char *a_status, int *a_unsafe);
}

void init_csp(py::module_ &m) {
    m.def(
        "audit_jj",
        [](const std::string &jjfile) {
            int n = 0;
            long *ci = nullptr;
            double *mn = nullptr, *mx = nullptr, *val = nullptr;
            char *st = nullptr;
            int *fl = nullptr;

            int rc;
            {
                // Run the HiGHS audit without the GIL so other threads (TUI
                // event loop, concurrent workers) keep running during the solve.
                py::gil_scoped_release release;
                rc = TauAuditJj(jjfile.c_str(), &n, &ci, &mn, &mx, &val,
                                &st, &fl);
            }
            if (rc != 0) {
                throw std::runtime_error("audit_jj failed (rc=" +
                                         std::to_string(rc) + "): " + jjfile);
            }

            std::vector<py::dict> rows;
            rows.reserve(n > 0 ? n : 0);
            for (int i = 0; i < n; i++) {
                py::dict d;
                d["cell"] = (long)ci[i];
                d["min"] = mn[i];
                d["max"] = mx[i];
                d["value"] = val[i];
                d["status"] = std::string(1, st[i]);
                d["unsafe"] = (fl[i] != 0);
                rows.push_back(std::move(d));
            }

            if (n > 0) {
                TauAuditJjFree(n, ci, mn, mx, val, st, fl);
            }
            return rows;
        },
        py::arg("jjfile"),
        "Compute realized feasibility intervals for the suppressed cells of "
        "the table described by the JJ file. Returns a list of "
        "{cell, min, max, value, status, unsafe} dicts in ascending cell "
        "index order, mirroring the legacy intervalle audit.");
}
