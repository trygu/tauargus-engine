#!/usr/bin/env bash
# Acceptance test for stage-r-package.sh --merge-into.
#
# Builds a hermetic fixture (a minimal pure-R front-end package plus a fake
# HiGHS source dir, so no network access is needed), stages the merged
# package on top of it, and asserts the resulting layout, NAMESPACE merge,
# DESCRIPTION patch and provenance wiring.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# --- fixture: a minimal pure-R front-end package ---------------------------
FE="$WORK/front-end"
mkdir -p "$FE/R" "$FE/tests/testthat"
cat > "$FE/DESCRIPTION" <<'EOF'
Package: rtauargus.native
Title: Test Front End
Version: 1.3.7
Description: Fixture front end for the merge staging test.
License: MIT + file LICENSE
Encoding: UTF-8
Imports:
    purrr (>= 0.2),
    tauargusengine (>= 0.5.3)
Suggests:
    testthat
EOF
cat > "$FE/NAMESPACE" <<'EOF'
import(tauargusengine)
importFrom(purrr,map)
export(frontrun)
EOF
echo 'frontrun <- function(...) invisible(list(...))' > "$FE/R/front.R"
echo '"_PACKAGE"' > "$FE/R/rtauargus.native-package.R"
printf 'YEAR: 2026\nCOPYRIGHT HOLDER: fixture\n' > "$FE/LICENSE"
echo '^docs$' > "$FE/.Rbuildignore"
echo 'test_that("front", expect_true(TRUE))' > "$FE/tests/testthat/test_front.R"
cat > "$FE/tests/testthat.R" <<'EOF'
library(testthat)
library(rtauargus.native)
test_check("rtauargus.native")
EOF

# --- fixture HiGHS dir (the real clone is skipped via --highs-src) ----------
HIGHS="$WORK/highs-fixture"
mkdir -p "$HIGHS/cmake" "$HIGHS/highs" "$HIGHS/extern" "$HIGHS/app" "$HIGHS/examples"
touch "$HIGHS/CMakeLists.txt"

# --- stage ------------------------------------------------------------------
if ! "$ROOT/scripts/stage-r-package.sh" --merge-into "$FE" --highs-src "$HIGHS" \
    > "$WORK/stage.log" 2>&1; then
    echo "staging failed:" >&2
    cat "$WORK/stage.log" >&2
    exit 1
fi

fail=0
check() {
    if ( cd "$WORK" && eval "$2" ); then echo "ok:   $1"
    else echo "FAIL: $1"; fail=1; fi
}

check "binding R files injected" \
    '[[ -f $FE/R/hitas.R && -f $FE/R/rounder.R && -f $FE/R/csp.R && -f $FE/R/meta.R && -f $FE/R/engine.R ]]'
check "front-end R files kept" \
    '[[ -f $FE/R/front.R && -f $FE/R/rtauargus.native-package.R ]]'
check "binding package doc not copied" \
    '[[ ! -f $FE/R/tauargusengine-package.R ]]'
check "binding src injected" \
    '[[ -f $FE/src/init.c && -f $FE/src/rta_engine.cpp && -f $FE/src/rta_meta.cpp && -f $FE/src/rta_csp.cpp && -f $FE/src/rta_hitas.cpp && -f $FE/src/rta_rounder.cpp ]]'
check "provenance meta header generated" \
    'grep -q "RTA_META_ENGINE_SHA " $FE/src/rta_meta.h'
check "init symbol renamed to the front-end" \
    'grep -q "R_init_rtauargus_native" $FE/src/init.c && ! grep -q "R_init_tauargusengine" $FE/src/init.c'
check "engine sources vendored" \
    '[[ -d $FE/engine/native/core/src && -d $FE/engine/native/rounder/src && -f $FE/engine/HiGHS-VERSION ]]'
check "highs sources vendored" \
    '[[ -d $FE/highs/highs && -d $FE/highs/extern ]]'
check "configure set in place" \
    '[[ -x $FE/configure && -f $FE/configure.win && -f $FE/configure.R ]]'
check "binding smoke test copied" \
    '[[ -f $FE/tests/test_binding_smoke.R ]]'
check "binding smoke test loads the front-end" \
    'grep -q "library(rtauargus.native)" $FE/tests/test_binding_smoke.R && ! grep -q "library(tauargusengine)" $FE/tests/test_binding_smoke.R'
check "front-end tests kept" \
    '[[ -f $FE/tests/testthat/test_front.R && -f $FE/tests/testthat.R ]]'
check "NAMESPACE: import(tauargusengine) removed" \
    '! grep -q "^import(tauargusengine)$" $FE/NAMESPACE'
check "NAMESPACE: useDynLib points at the front-end (dot form)" \
    'grep -q "^useDynLib(rtauargus.native, .registration = TRUE)$" $FE/NAMESPACE'
check "NAMESPACE: binding exports kept" \
    'grep -q "^export(new_hitas)$" $FE/NAMESPACE && grep -q "^export(audit_jj)$" $FE/NAMESPACE'
check "NAMESPACE: front-end exports kept" \
    'grep -q "^export(frontrun)$" $FE/NAMESPACE'
check "DESCRIPTION: tauargusengine import gone" \
    '! grep -q "tauargusengine (" $FE/DESCRIPTION'
check "DESCRIPTION: front-end version kept" \
    'grep -q "^Version: 1.3.7$" $FE/DESCRIPTION'
check "DESCRIPTION: SystemRequirements added" \
    'grep -q "^SystemRequirements:" $FE/DESCRIPTION'
check "DESCRIPTION: provenance comment added" \
    'grep -q "^Comment: Staged native layer from tauargus-engine " $FE/DESCRIPTION'
check "LICENSE: engine notice appended" \
    'grep -q "EUPL-1.2" $FE/LICENSE'
check "Rbuildignore: native build artifacts ignored" \
    'grep -qxF "^src/\.ta" $FE/.Rbuildignore'

if [[ "$fail" -ne 0 ]]; then
    echo "test-stage-r-merge: FAILURES" >&2
    exit 1
fi
echo "test-stage-r-merge: all checks passed"
