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
mkdir -p "$FE/R" "$FE/tests/testthat" "$FE/man"
cat > "$FE/DESCRIPTION" <<'EOF'
Package: rtauargus.native
Title: Test Front End
Version: 1.3.7
Authors@R: person("Trygve", "Falch", role = c("aut", "cre"),
    email = "trygve.falch@gmail.com")
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
printf '^docs$\n^tools$\n' > "$FE/.Rbuildignore"
printf 'front-end package documentation\n' > "$FE/man/rtauargus.native-package.Rd"
echo 'test_that("front", expect_true(TRUE))' > "$FE/tests/testthat/test_front.R"
echo 'tauargusengine::tauargus_example(1L)' >> "$FE/tests/testthat/test_front.R"
cat > "$FE/upstream.json" <<'EOF'
{"repository":"InseeFrLab/rtauargus","revision":"2222222222222222222222222222222222222222","version":"1.3.6","description_sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}
EOF
cat > "$FE/tests/testthat.R" <<'EOF'
library(testthat)
library(rtauargus.native)
test_check("rtauargus.native")
EOF

# --- fixture HiGHS dir (the real clone is skipped via --highs-src) ----------
HIGHS="$WORK/highs-fixture"
mkdir -p "$HIGHS/cmake" "$HIGHS/highs" "$HIGHS/extern" "$HIGHS/app" "$HIGHS/examples"
git init -q "$HIGHS"
touch "$HIGHS/CMakeLists.txt"
printf 'MIT License\nCopyright fixture HiGHS\n' > "$HIGHS/LICENSE.txt"
printf 'cff-version: 1.2.0\n' > "$HIGHS/CITATION.cff"
mkdir -p "$HIGHS/extern/example"
printf 'Third-party fixture license\n' > "$HIGHS/extern/example/LICENSE"

# --- stage ------------------------------------------------------------------
if ! "$ROOT/scripts/stage-r-package.sh" --merge-into "$FE" --highs-src "$HIGHS" --version 0.6.1 \
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
check "git worktree files excluded from vendored sources" \
    '! find "$FE/tools/engine" -name .git -print | grep -q .'
check "custom metadata uses a Config field" \
    'grep -q "^Config/tauargus/engine:" "$FE/DESCRIPTION" && ! grep -q "^Comment:" "$FE/DESCRIPTION"'
check "tools are retained and generated Makevars ignored" \
    '! grep -qxF "^tools$" "$FE/.Rbuildignore" && grep -qxF "^src/Makevars" "$FE/.Rbuildignore"'
check "provenance meta header generated" \
    'grep -q "RTA_META_ENGINE_SHA " $FE/src/rta_meta.h'
check "init symbol renamed to the front-end" \
    'grep -q "R_init_rtauargus_native" $FE/src/init.c && ! grep -q "R_init_tauargusengine" $FE/src/init.c'
check "engine sources vendored" \
    '[[ -d $FE/tools/engine/native/core/src && -d $FE/tools/engine/native/rounder/src && -f $FE/tools/engine/HiGHS-VERSION ]]'
check "highs sources vendored" \
    '[[ -d $FE/tools/highs/highs && -d $FE/tools/highs/extern ]]'
check "HiGHS citation retained outside the R CITATION namespace" \
    'test -f "$FE/inst/REFERENCES/highs.cff" && test -f "$FE/tools/highs/highs.cff" && test ! -f "$FE/tools/highs/CITATION.cff"'
check "configure set in place" \
    '[[ -x $FE/configure && -f $FE/configure.win && -f $FE/tools/configure.R ]]'
check "native help pages copied unchanged" \
    'cmp "$ROOT/bindings/r/tauargusengine/man/new_tauargus.Rd" "$FE/man/new_tauargus.Rd" && cmp "$ROOT/bindings/r/tauargusengine/man/tauargus_set_cell_key_values_cont.Rd" "$FE/man/tauargus_set_cell_key_values_cont.Rd"'
check "front-end package help preserved" \
    'grep -qx "front-end package documentation" "$FE/man/rtauargus.native-package.Rd" && [[ ! -f $FE/man/tauargusengine-package.Rd ]]'
check "binding smoke test copied" \
    '[[ -f $FE/tests/test_binding_smoke.R ]]'
check "native error test copied and loads the front-end" \
    '[[ -f $FE/tests/test_native_errors.R ]] && grep -q "library(rtauargus.native)" $FE/tests/test_native_errors.R'
check "binding smoke test loads the front-end" \
    'grep -q "library(rtauargus.native)" $FE/tests/test_binding_smoke.R && ! grep -q "library(tauargusengine)" $FE/tests/test_binding_smoke.R'
check "front-end tests kept" \
    '[[ -f $FE/tests/testthat/test_front.R && -f $FE/tests/testthat.R ]]'
check "engine tests: binding namespace rewritten to the front-end" \
    'grep -q "rtauargus.native::tauargus_example" $FE/tests/testthat/test_front.R && ! grep -q "tauargusengine::" $FE/tests/testthat/test_front.R'
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
check "DESCRIPTION: version combines imported INSEE and native versions" \
    'grep -qx "Version: 1.3.6-0.6.1" "$FE/DESCRIPTION"'
check "DESCRIPTION: static linkage and component versions recorded" \
    'grep -qx "Config/tauargus/linkage: static" "$FE/DESCRIPTION" && grep -qx "Config/rtauargus/upstream-version: 1.3.6" "$FE/DESCRIPTION"'
check "native attribution installed and included in authors" \
    'test -f "$FE/inst/COPYRIGHTS" && grep -q "Statistics Netherlands" "$FE/DESCRIPTION" && test -f "$FE/inst/LICENSES/native/csp/README.md"'
check "DESCRIPTION: SystemRequirements added" \
    'grep -q "^SystemRequirements:" $FE/DESCRIPTION'
check "DESCRIPTION: combined package uses EUPL" \
    'grep -qx "License: EUPL-1.2" $FE/DESCRIPTION'
check "full EUPL text installed" \
    'grep -q "This European Union Public Licence" $FE/inst/LICENSES/EUPL-1.2.txt'
check "front-end MIT notice retained" \
    'grep -q "Copyright (c) 2026 fixture" $FE/inst/LICENSES/MIT-frontend.txt && grep -q "Permission is hereby granted" $FE/inst/LICENSES/MIT-frontend.txt'
check "HiGHS keeps its MIT license" \
    'cmp $HIGHS/LICENSE.txt $FE/inst/LICENSES/HiGHS/LICENSE.txt'
check "HiGHS third-party licenses installed" \
    'cmp $HIGHS/extern/example/LICENSE $FE/inst/LICENSES/HiGHS/extern/example/LICENSE'
check "MIT stub is not mislabeled as EUPL" \
    '[[ ! -f $FE/LICENSE ]]'
check "Rbuildignore: native build artifacts ignored" \
    'grep -qxF "^src/\.ta" $FE/.Rbuildignore'

if [[ "$fail" -ne 0 ]]; then
    echo "test-stage-r-merge: FAILURES" >&2
    exit 1
fi
echo "test-stage-r-merge: all checks passed"
