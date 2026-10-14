#!/usr/bin/env bash
# Assemble the self-contained tauargusengine R source package.
#
# The staged package carries the binding sources plus the native engine
# sources (engine/) and the pinned HiGHS sources (highs/). Its
# configure script builds everything from the package's own sources at
# install time, so no engine checkout, engine/build/lib or prebuilt engine
# is needed downstream. This script only assembles files; it does not
# compile anything.
#
#   scripts/stage-r-package.sh [--out DIR] [--engine DIR] [--highs-src DIR]
#                              [--version X.Y.Z]
#
#   scripts/stage-r-package.sh --merge-into DIR [--engine DIR]
#                              [--highs-src DIR]
#
# Defaults:
#   --out         build/r-package
#   --engine      the repo root (detected from the script location)
#   --highs-src   build/highs-src; the script clones the pinned
#                 engine/HiGHS-VERSION tag there if the dir is missing
#   --version     the Version field of the in-tree binding DESCRIPTION
#
# Merge mode (--merge-into): instead of assembling a standalone
# tauargusengine package, compose the native layer (binding R code, src/,
# configure, engine/, highs/, provenance) into an existing
# front-end package (the rtauargus.native checkout) so the release ships
# one self-contained package. The front-end keeps its own name, version
# and R code; its NAMESPACE and DESCRIPTION are patched in place, and the
# checkout is not wiped.
set -euo pipefail
cd "$(dirname "$0")/.."
ENGINE_DIR="$(pwd)"

OUT=""
HIGHS_SRC=""
VERSION=""
MERGE_INTO=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --out) OUT="$2"; shift 2 ;;
        --engine) ENGINE_DIR="$2"; shift 2 ;;
        --highs-src) HIGHS_SRC="$2"; shift 2 ;;
        --version) VERSION="$2"; shift 2 ;;
        --merge-into) MERGE_INTO="$2"; shift 2 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
done
OUT="${OUT:-$ENGINE_DIR/build/r-package}"
HIGHS_SRC="${HIGHS_SRC:-$ENGINE_DIR/build/highs-src}"
BINDING="$ENGINE_DIR/bindings/r/tauargusengine"
STAGING="$ENGINE_DIR/bindings/r/staging"

# Gate: submodule worktrees must match the pins recorded by the parent, or
# the staged sources would not represent a recorded engine revision.
drift="$(git -C "$ENGINE_DIR" submodule status | grep '^+' || true)"
if [[ -n "$drift" ]]; then
    echo "submodule worktree drift (worktree != recorded pin):" >&2
    echo "$drift" >&2
    echo "restore with: git -C $ENGINE_DIR submodule update --checkout <name>" >&2
    exit 1
fi

HIGHS_TAG="$(tr -d '[:space:]' < "$ENGINE_DIR/engine/HiGHS-VERSION")"
[[ -n "$HIGHS_TAG" ]] || { echo "engine/HiGHS-VERSION is empty" >&2; exit 1; }

# HiGHS sources at the pinned tag (clone once; reuse the dir otherwise).
if [[ ! -d "$HIGHS_SRC/.git" ]]; then
    echo "cloning HiGHS $HIGHS_TAG -> $HIGHS_SRC"
    rm -rf "$HIGHS_SRC"
    git clone --depth 1 --branch "$HIGHS_TAG" \
        https://github.com/ERGO-Code/HiGHS.git "$HIGHS_SRC" > /dev/null
fi
if [[ ! -f "$HIGHS_SRC/CMakeLists.txt" ]]; then
    echo "HiGHS sources not usable at $HIGHS_SRC" >&2
    exit 1
fi

# Provenance: engine revision + submodule pins + HiGHS tag.
ENGINE_SHA="$(git -C "$ENGINE_DIR" rev-parse HEAD)"
sha_of() { git -C "$ENGINE_DIR/engine/native/$1" rev-parse HEAD 2>/dev/null || echo unknown; }
CORE_SHA="$(sha_of core)"; CSP_SHA="$(sha_of csp)"; HITAS_SHA="$(sha_of hitas)"
CRP_SHA="$(sha_of crp)"; ROUNDER_SHA="$(sha_of rounder)"

if [[ -n "$MERGE_INTO" ]]; then
    # Merge mode: the front-end checkout is the package root; nothing is
    # wiped.
    PKG_DIR="$MERGE_INTO"
    for f in DESCRIPTION NAMESPACE; do
        [[ -f "$PKG_DIR/$f" ]] || { echo "merge target missing $f: $PKG_DIR" >&2; exit 1; }
    done
    [[ -d "$PKG_DIR/R" ]] || { echo "merge target missing R/: $PKG_DIR" >&2; exit 1; }
    PKG_NAME="$(awk -F': *' '/^Package:/{print $2; exit}' "$PKG_DIR/DESCRIPTION")"
    # R names the extension after the package with dots turned into
    # underscores (as for data.table: DLL data_table, symbol
    # R_init_data_table). The init function must be valid C, so the
    # underscore form is the only option.
    PKG_DYN="${PKG_NAME//./_}"
else
    PKG_DIR="$OUT/tauargusengine"
    rm -rf "$OUT"
fi
mkdir -p "$PKG_DIR/src" "$PKG_DIR/engine" "$PKG_DIR/highs"

# 1) Binding: R code, C/C++ sources, tests.
if [[ -n "$MERGE_INTO" ]]; then
    # Every binding R file except the package doc file (the front-end
    # keeps its own).
    for f in "$BINDING"/R/*.R; do
        base="$(basename "$f")"
        [[ "$base" == *package.R ]] && continue
        cp "$f" "$PKG_DIR/R/"
    done
    mkdir -p "$PKG_DIR/tests"
    # Point the smoke test at the front-end package name.
    sed 's/library(tauargusengine)/library('"$PKG_NAME"')/' \
        "$BINDING/tests/test_binding_smoke.R" > "$PKG_DIR/tests/test_binding_smoke.R"
else
    cp -R "$BINDING/R" "$PKG_DIR/R"
    cp "$BINDING/NAMESPACE" "$BINDING/LICENSE" "$PKG_DIR/"
    cp -R "$BINDING/tests" "$PKG_DIR/tests"
fi
cp "$BINDING"/src/init.c "$BINDING"/src/rta.h "$BINDING"/src/rta_cpp.h \
   "$BINDING"/src/rta_engine.cpp "$BINDING"/src/rta_csp.cpp \
   "$BINDING"/src/rta_hitas.cpp "$BINDING"/src/rta_rounder.cpp \
   "$BINDING"/src/rta_meta.cpp "$PKG_DIR/src/"

# In merge mode the DLL entry point must carry the front-end package
# name (dot form), or R loads the extension without registering the
# routines.
if [[ -n "$MERGE_INTO" ]]; then
    sed "s/R_init_tauargusengine/R_init_${PKG_DYN}/" \
        "$PKG_DIR/src/init.c" > "$PKG_DIR/.init.staged"
    mv "$PKG_DIR/.init.staged" "$PKG_DIR/src/init.c"
fi

# 2) Provenance header (overwrites the in-tree dev placeholder).
HIGHS_VERSION="${HIGHS_TAG#v}"
cat > "$PKG_DIR/src/rta_meta.h" <<EOF
/* Generated by scripts/stage-r-package.sh; do not edit. */
#ifndef RTA_META_H
#define RTA_META_H
#define RTA_META_ENGINE_SHA "$ENGINE_SHA"
#define RTA_META_ENGINE_SHA_CORE "$CORE_SHA"
#define RTA_META_ENGINE_SHA_CSP "$CSP_SHA"
#define RTA_META_ENGINE_SHA_HITAS "$HITAS_SHA"
#define RTA_META_ENGINE_SHA_CRP "$CRP_SHA"
#define RTA_META_ENGINE_SHA_ROUNDER "$ROUNDER_SHA"
#define RTA_META_HIGHS_VERSION "$HIGHS_VERSION"
#endif
EOF

# 3) Package metadata.
if [[ -n "$MERGE_INTO" ]]; then
    # NAMESPACE: drop the binding import, point useDynLib at the
    # front-end, keep both export sets.
    {
        grep -v '^import(tauargusengine)$' "$PKG_DIR/NAMESPACE"
        printf 'useDynLib(%s, .registration = TRUE)\n' "$PKG_DYN"
        grep -v '^useDynLib(' "$BINDING/NAMESPACE"
    } > "$PKG_DIR/.NAMESPACE.staged"
    mv "$PKG_DIR/.NAMESPACE.staged" "$PKG_DIR/NAMESPACE"

    # DESCRIPTION: drop the binding import, add the native build
    # requirements and the provenance comment. The front-end keeps its
    # own name and version.
    awk -v highs="$HIGHS_VERSION" -v engsha="$ENGINE_SHA" '
        /^[[:space:]]*tauargusengine[[:space:]]*\(/ { next }
        /^License:/ {
            print "SystemRequirements: CMake >= 3.16 and a C++11 compiler; the"
            print "    package builds the bundled tauargus-engine native sources"
            print "    and HiGHS (" highs ") from its own sources at install time."
            print "NeedsCompilation: yes"
            print "Comment: Staged native layer from tauargus-engine " engsha " (HiGHS " highs ")"
        }
        { print }
    ' "$PKG_DIR/DESCRIPTION" > "$PKG_DIR/.DESCRIPTION.staged"
    mv "$PKG_DIR/.DESCRIPTION.staged" "$PKG_DIR/DESCRIPTION"

    # LICENSE: note the engine-licensed portion.
    cat >> "$PKG_DIR/LICENSE" <<EOF

---
The bundled native sources (src/, engine/, highs/, configure,
configure.win, configure.R) belong to tauargus-engine
(https://github.com/trygu/tauargus-engine) and are licensed under EUPL-1.2.
EOF

    # .Rbuildignore: keep the native build artifacts out of the tarball.
    for pat in '^src/\.ta' '^src/.*\.(o|so|dll|dylib|a|lib|obj)$' '^inst/libs'; do
        grep -qxF "$pat" "$PKG_DIR/.Rbuildignore" 2>/dev/null \
            || echo "$pat" >> "$PKG_DIR/.Rbuildignore"
    done
else
# 3a) Standalone DESCRIPTION: patch version, SystemRequirements, URLs
#     and provenance.
[[ -n "$VERSION" ]] || VERSION="$(awk -F': ' '/^Version:/{print $2; exit}' "$BINDING/DESCRIPTION")"
awk -v ver="$VERSION" -v highs="$HIGHS_VERSION" -v engsha="$ENGINE_SHA" '
    /^Version:/ { print "Version: " ver; next }
    /^SystemRequirements:/ {
        print "SystemRequirements: CMake >= 3.16 and a C++11 compiler; the"
        print "    package builds the bundled tauargus-engine native sources"
        print "    and HiGHS (" highs ") from its own sources at install time."
        in_sysreq = 1; next
    }
    in_sysreq { if ($0 ~ /^    /) next; in_sysreq = 0 }
    /^Suggests:/ {
        print "URL: https://github.com/trygu/tauargus-engine"
        print "BugReports: https://github.com/trygu/tauargus-engine/issues"
        print "Comment: Staged from tauargus-engine " engsha " (HiGHS " highs ")"
    }
    { print }
' "$BINDING/DESCRIPTION" > "$PKG_DIR/DESCRIPTION"
fi

# 4) Build system: configure for Unix and Windows + shared configure.R.
#    In merge mode the front-end keeps its own .Rbuildignore (already
#    extended in step 3); only the standalone package takes the staged one.
cp "$STAGING/configure" "$STAGING/configure.win" "$STAGING/configure.R" "$PKG_DIR/"
[[ -z "$MERGE_INTO" ]] && cp "$STAGING/.Rbuildignore" "$PKG_DIR/"
chmod +x "$PKG_DIR/configure"

# 5) Native engine sources (same tree and CMake recipes the superbuild uses).
cp "$ENGINE_DIR/engine/CMakeLists.txt" "$ENGINE_DIR/engine/HiGHS-VERSION" \
   "$PKG_DIR/engine/"
for m in core csp hitas crp rounder; do
    mkdir -p "$PKG_DIR/engine/native/$m"
    cp "$ENGINE_DIR/engine/native/$m/CMakeLists.txt" "$PKG_DIR/engine/native/$m/"
    cp -R "$ENGINE_DIR/engine/native/$m/src" "$PKG_DIR/engine/native/$m/src"
    # Other build-input files at the module top level (e.g. hitas/ErrorStrings.txt)
    find "$ENGINE_DIR/engine/native/$m" -maxdepth 1 -type f \
        ! -name "CMakeLists.txt" ! -name "README.md" \
        -exec cp {} "$PKG_DIR/engine/native/$m/" \;
done

# 6) HiGHS sources at the pinned tag (library build subset; the app and
# examples dirs return early when their options are off, but CMake still
# requires the directories to exist).
for f in CMakeLists.txt Version.txt highs.pc.in LICENSE.txt AUTHORS \
         CITATION.cff README.md CODE_OF_CONDUCT.md CONTRIBUTING.md \
         FEATURES.md THIRD_PARTY_NOTICES.md; do
    [[ -f "$HIGHS_SRC/$f" ]] && cp "$HIGHS_SRC/$f" "$PKG_DIR/highs/" || true
done
cp -R "$HIGHS_SRC/cmake" "$HIGHS_SRC/highs" "$HIGHS_SRC/extern" \
   "$HIGHS_SRC/app" "$HIGHS_SRC/examples" "$PKG_DIR/highs/"

echo "staged: $PKG_DIR"
echo "  engine: $ENGINE_SHA (HiGHS $HIGHS_TAG)"
echo "  submodules: core=$CORE_SHA csp=$CSP_SHA hitas=$HITAS_SHA crp=$CRP_SHA rounder=$ROUNDER_SHA"
echo "  version: $VERSION"
echo
echo "next: R CMD build $PKG_DIR"
