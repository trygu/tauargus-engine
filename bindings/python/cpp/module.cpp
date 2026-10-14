// Tau-Argus native engine — pybind11 module entry point.
// The three binding namespaces are defined in separate translation units
// (see bind_core.cpp / bind_hitas.cpp / bind_rounder.cpp) so that the
// duplicate `IProgressListener` classes (core vs. hitas) never collide.

#include <pybind11/pybind11.h>

#include "init_decls.h"
#include "py_meta.h"

namespace py = pybind11;

PYBIND11_MODULE(_tauargus, m) {
    m.doc() = "Tau-Argus native SDC engine (HiGHS-backed)";
    init_core(m);
    init_csp(m);
    init_hitas(m);
    init_rounder(m);
    m.def("engine_meta", []() {
        return py::dict(py::arg("engine_sha") = PY_META_ENGINE_SHA,
                        py::arg("highs_version") = PY_META_HIGHS_VERSION);
    }, "Build provenance: the engine commit and the pinned HiGHS version.");
}
