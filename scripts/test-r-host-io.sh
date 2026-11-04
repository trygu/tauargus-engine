#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="${1:-$(mktemp -d)}"
if [[ $# -eq 0 ]]; then trap 'rm -rf "$WORK"' EXIT; fi
mkdir -p "$WORK/fixture"
cp "$ROOT/scripts/r-host-test/native.c" "$ROOT/scripts/r-host-test/native.cpp" "$ROOT/scripts/r-host-test/bad-format.c" "$WORK/fixture/"
PYTHON=python3
"$PYTHON" -c 'import sys; assert sys.version_info >= (3, 8)' > /dev/null 2>&1 || PYTHON=python
"$PYTHON" "$ROOT/bindings/r/staging/patch-host.py" "$WORK/fixture" \
    "$ROOT/bindings/r/tauargusengine/src/rta_host_io.h"
R_INCLUDE="$(Rscript -e 'cat(R.home("include"))')"
cmake -S "$ROOT/scripts/r-host-test" -B "$WORK/build" \
    -DFIXTURE_DIR="$WORK/fixture" -DBINDING_SRC="$ROOT/bindings/r/tauargusengine/src" \
    -DR_INCLUDE="$R_INCLUDE"
cmake --build "$WORK/build" --parallel 2
ctest --test-dir "$WORK/build" --output-on-failure

if cmake --build "$WORK/build" --target r_host_bad_format > "$WORK/expected-format-error.log" 2>&1; then
    echo "native format diagnostics were lost" >&2
    exit 1
fi
grep -Eq 'format .*expects|format specifies|\[-Werror.*format' "$WORK/expected-format-error.log"
