# Bindings

Thin language bindings over the five engine libraries. Both bindings
mirror the C++ API one-to-one; they are consumed by the front-end repos,
not by end users.

- **Python** (`python/`): the pybind11 extension `_tauargus`, compiled
  against `engine/build/lib/`. The module exposes:
  - `TauArgus`: the core engine object, mirroring
    `native/core/src/TauArgus.h`
  - `HiTaSCtrl`: hierarchical suppression control
  - `RounderCtrl`: controlled-rounding control
  - `engine_meta()`: build provenance (engine commit, HiGHS version)

  The binding code lives in `python/cpp/bind_core.cpp`,
  `python/cpp/bind_csp.cpp`, `python/cpp/bind_hitas.cpp` and
  `python/cpp/bind_rounder.cpp`. Smoke tests in `python/tests/` run
  against a locally built engine.

- **R** (`r/tauargusengine/`): the thin R package `tauargusengine`.
  Exposes `new_tauargus()`, `new_hitas()` and `new_rounder()` plus one
  `.Call` wrapper per C++ method (see `NAMESPACE`), and `audit_jj()` for
  the in-process feasibility audit. Smoke tests in `tests/`. The
  distributable, self-contained R package is staged by
  `scripts/stage-r-package.sh` and released from the
  [rtauargus.native](https://github.com/trygu/rtauargus.native) repo.

Build instructions for the Python extension are in
[Building from source](../README.md#building-from-source) at the
repository root. The user-facing APIs are documented in the front-end
repos:
[pytauargus](https://github.com/trygu/pytauargus/blob/master/docs/python-api.md)
(Python) and
[rtauargus.native](https://github.com/trygu/rtauargus.native) (R).
