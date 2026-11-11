// Phase 4.2 input guards for the pybind11 layer.
//
// The native core assumes well-formed indices and finite values; a
// negative index or a NaN/Inf double can turn into out-of-bounds
// access or a solver abort. These helpers reject such input with a
// clean ValueError (py::value_error) that names the argument, before
// the native call. They mirror the R binding guards (rta_cpp.h,
// phase 4.1).

#ifndef TAUARGUS_PY_INPUT_GUARDS_H
#define TAUARGUS_PY_INPUT_GUARDS_H

#include <cmath>
#include <cstddef>
#include <string>
#include <vector>

#include <pybind11/pybind11.h>

namespace tauargus {
namespace guards {

// Index/count arguments: must be a non-negative whole number.
inline void non_negative(const char *name, long value) {
    if (value < 0) {
        throw pybind11::value_error(std::string(name) +
            " must be a non-negative integer, got " + std::to_string(value));
    }
}

// Vector of indices (e.g. dimension sequences): each element >= 0.
inline void non_negative_vec(const char *name, const std::vector<long> &v) {
    for (std::size_t i = 0; i < v.size(); i++) {
        if (v[i] < 0) {
            throw pybind11::value_error(std::string(name) + "[" + std::to_string(i) +
                "] must be a non-negative integer, got " + std::to_string(v[i]));
        }
    }
}

inline std::string format_double(double value) {
    if (std::isnan(value)) return "nan";
    if (std::isinf(value)) return value > 0 ? "inf" : "-inf";
    return std::to_string(value);
}

// Documented non-negative doubles (cost, lam, protection levels, the
// rounder base, ...): must be finite and >= 0.
inline void finite_non_negative(const char *name, double value) {
    if (std::isnan(value) || std::isinf(value)) {
        throw pybind11::value_error(std::string(name) +
            " must be a finite non-negative number, got " + format_double(value));
    }
    if (value < 0) {
        throw pybind11::value_error(std::string(name) +
            " must be a non-negative number, got " + format_double(value));
    }
}

// Bound values that may legitimately be unbounded: +/-Inf is legal,
// NaN never is.
inline void finite_or_inf(const char *name, double value) {
    if (std::isnan(value)) {
        throw pybind11::value_error(std::string(name) + " must not be NaN");
    }
}

// Vector of bounds (rounder upper/lower): element-wise, +/-Inf legal.
inline void finite_or_inf_vec(const char *name, const std::vector<double> &v) {
    for (std::size_t i = 0; i < v.size(); i++) {
        if (std::isnan(v[i])) {
            throw pybind11::value_error(std::string(name) + "[" + std::to_string(i) +
                "] must not be NaN");
        }
    }
}

}  // namespace guards
}  // namespace tauargus

#endif  // TAUARGUS_PY_INPUT_GUARDS_H
