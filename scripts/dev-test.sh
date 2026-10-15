#!/usr/bin/env bash
# One-command engine dev loop: gate on submodule drift, build the native
# superbuild, then run the native core tests, the thin Python binding smoke
# tests and (when R is available) the R binding smoke test.
#
# The pytauargus repo has its own scripts/sync-venv.sh that builds a wheel
# from a pinned engine revision and force-installs it into a venv; use that
# for Python package work. This script covers this repo only.
set -euo pipefail
cd "$(dirname "$0")/.."

JOBS="$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)"

# Gate: submodule worktrees must match the pins recorded by the parent.
drift="$(git submodule status | grep '^+' || true)"
if [[ -n "$drift" ]]; then
    echo "submodule worktree drift (worktree != recorded pin):" >&2
    echo "$drift" >&2
    echo "restore with: git submodule update --checkout <name>" >&2
    exit 1
fi

# HiGHS. Override with HIGHS_DIR (path to the CMake package dir) or
# HIGHS_PREFIX (an installed prefix; the script derives Highs_DIR from it).
# Defaults: Homebrew on macOS, /usr otherwise.
HIGHS_TAG="$(tr -d '[:space:]' < engine/HiGHS-VERSION)"
if [[ -n "${HIGHS_DIR:-}" ]]; then
    :
elif [[ -n "${HIGHS_PREFIX:-}" ]]; then
    HIGHS_DIR="${HIGHS_PREFIX}/lib/cmake/Highs"
elif [[ "$(uname)" == "Darwin" ]] && command -v brew >/dev/null 2>&1; then
    HIGHS_DIR="$(brew --prefix)/lib/cmake/Highs"
    export HIGHSPREFIX="${HIGHSPREFIX:-$(brew --prefix)}"
else
    HIGHS_DIR=""
fi
export HIGHSPREFIX="${HIGHSPREFIX:-/usr}"
if [[ -n "$HIGHS_DIR" && ! -d "$HIGHS_DIR" ]]; then
    echo "HiGHS package dir not found: $HIGHS_DIR (HiGHS pin: $HIGHS_TAG)" >&2
    echo "install the matching HiGHS or pass -DHighs_DIR / HIGHS_DIR / HIGHS_PREFIX" >&2
    exit 1
fi

# 1) Release engine superbuild.
cmake -S engine -B engine/build -DHighs_DIR="$HIGHS_DIR" -DTAUARGUS_CORE_BUILD_TESTS=ON > /dev/null
cmake --build engine/build --parallel "$JOBS" > /dev/null

# 2) Native core regression tests.
ctest --test-dir engine/build/native/core --output-on-failure

# 3) Thin Python binding smoke tests (build the extension into scratch/).
(cd bindings/python && uv run --with pytest --with pybind11 pytest tests -q)

# 4) R binding smoke (only when R is installed; skips cleanly otherwise).
if command -v Rscript >/dev/null 2>&1; then
    Rlib="$(mktemp -d)"
    mkdir -p "$Rlib"
    R CMD INSTALL --library="$Rlib" bindings/r/tauargusengine > /dev/null
    R_LIBS="$Rlib" Rscript bindings/r/tauargusengine/tests/test_binding_smoke.R
else
    echo "R not found; skipping the R binding smoke test"
fi

echo "dev-test: all green"
