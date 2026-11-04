#!/usr/bin/env bash
# Prove the R build can install five static engine libraries and run regressions.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HIGHS_CONFIG="${1:?usage: test-r-static-build.sh Highs_CONFIG_DIR [BUILD_DIR]}"
WORK="${2:-$(mktemp -d)}"
if [[ $# -lt 2 ]]; then trap 'rm -rf "$WORK"' EXIT; fi
harden=()
csp_tests=OFF
if [[ "${RUNNER_OS:-}" != Windows ]]; then
    harden=("-DCMAKE_C_FLAGS=-D_FORTIFY_SOURCE=2 -Werror=unused-result"
            "-DCMAKE_CXX_FLAGS=-D_FORTIFY_SOURCE=2 -Wformat -Werror=format-security -Werror=format -Werror=deprecated -Werror=deprecated-declarations -Werror=unused-result")
    csp_tests=ON
fi
cmake -S "$ROOT/scripts/r-static-test" -B "$WORK/build" \
    -DTAUARGUS_ROOT="$ROOT" \
    -DHighs_DIR="$HIGHS_CONFIG" -DBUILD_SHARED_LIBS=OFF -DTAUARGUS_MAX_THREADS=2 "${harden[@]}" \
    -DTAUARGUS_CORE_BUILD_TESTS=ON -DTAUARGUS_CSP_BUILD_TESTS="$csp_tests" \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$WORK/install"
cmake --build "$WORK/build" --config Release --parallel 2
cmake --install "$WORK/build" --config Release
for module in tauargus_core tauargus_csp tauargus_hitas CRP tauargus_rounder; do
    if [[ ! -f "$WORK/install/lib/lib$module.a" && ! -f "$WORK/install/lib/$module.lib" ]]; then
        echo "missing static library: $module" >&2
        exit 1
    fi
done
if find "$WORK/install" -type f \( -name '*.dll' -o -name '*.dylib' -o -name '*.so*' \) | grep -q .; then
    echo "static R build unexpectedly installed shared engine libraries" >&2
    exit 1
fi
ctest --test-dir "$WORK/build" -C Release --output-on-failure
ctest --test-dir "$WORK/build/engine/native/core" -C Release --output-on-failure
if [[ "$csp_tests" == ON ]]; then
    ctest --test-dir "$WORK/build/engine/native/csp" -C Release --output-on-failure
fi
echo "static R engine build: passed"
