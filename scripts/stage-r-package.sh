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
FRONT_MIT=0
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
    if grep -qx 'License: MIT + file LICENSE' "$PKG_DIR/DESCRIPTION"; then
        FRONT_MIT=1
    fi
    # R names the shared object after the package verbatim (dots kept:
    # rtauargus.native.so), so useDynLib must use the dot form. The
    # init symbol cannot contain dots (C identifier), but R's dynload
    # falls back to the underscore form when the dotted lookup fails
    # (Rdynload.c: try R_init_<name>, then retry with . replaced by
    # _). The init function therefore carries the underscore form.
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
# Install the checked-in help pages with the injected native API. The
# merged front-end retains its own package-level topic.
mkdir -p "$PKG_DIR/man"
for f in "$BINDING"/man/*.Rd; do
    [[ -n "$MERGE_INTO" && "$(basename "$f")" == tauargusengine-package.Rd ]] && continue
    cp "$f" "$PKG_DIR/man/"
done
cp "$BINDING"/src/init.c "$BINDING"/src/rta.h "$BINDING"/src/rta_cpp.h \
   "$BINDING"/src/rta_engine.cpp "$BINDING"/src/rta_csp.cpp \
   "$BINDING"/src/rta_hitas.cpp "$BINDING"/src/rta_rounder.cpp \
   "$BINDING"/src/rta_meta.cpp "$PKG_DIR/src/"

# In merge mode the DLL entry point must carry the front-end package
# name in underscore form (the dotted form is not a valid C
# identifier; R's dynload finds it via its dot-to-underscore
# fallback).
if [[ -n "$MERGE_INTO" ]]; then
    sed "s/R_init_tauargusengine/R_init_${PKG_DYN}/" \
        "$PKG_DIR/src/init.c" > "$PKG_DIR/.init.staged"
    mv "$PKG_DIR/.init.staged" "$PKG_DIR/src/init.c"
    # The fork's engine tests qualify the binding namespace
    # (tauargusengine::). In the merged package the functions live in
    # the front-end namespace, so rewrite the qualifier.
    for f in "$PKG_DIR"/tests/testthat/*.R; do
        [[ -f "$f" ]] || continue
        sed "s/tauargusengine::/${PKG_NAME}::/" "$f" > "$f.ta"
        mv "$f.ta" "$f"
    done
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
    # front-end (dot form, the verbatim shared-object name R builds),
    # keep both export sets.
    {
        grep -v '^import(tauargusengine)$' "$PKG_DIR/NAMESPACE"
        printf 'useDynLib(%s, .registration = TRUE)\n' "$PKG_NAME"
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
            print "License: EUPL-1.2"
            next
        }
        { print }
    ' "$PKG_DIR/DESCRIPTION" > "$PKG_DIR/.DESCRIPTION.staged"
    mv "$PKG_DIR/.DESCRIPTION.staged" "$PKG_DIR/DESCRIPTION"

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

# 7) Ship license texts in inst/ so both source and installed packages
# carry them. The combined package is EUPL; the MIT front-end and HiGHS
# retain their original permissions and attribution.
LICENSES="$PKG_DIR/inst/LICENSES"
mkdir -p "$LICENSES/HiGHS"
cp "$ENGINE_DIR/LICENSE" "$LICENSES/EUPL-1.2.txt"
if [[ -f "$PKG_DIR/LICENSE" ]]; then
    if [[ "$FRONT_MIT" == 1 ]]; then
        year="$(sed -n 's/^YEAR: *//p' "$PKG_DIR/LICENSE")"
        holder="$(sed -n 's/^COPYRIGHT HOLDER: *//p' "$PKG_DIR/LICENSE")"
        [[ -n "$year" && -n "$holder" ]] || {
            echo "front-end MIT license is missing its year or holder" >&2
            exit 1
        }
        {
            printf 'MIT License\n\nCopyright (c) %s %s\n\n' "$year" "$holder"
            cat "$STAGING/MIT-LICENSE"
        } > "$LICENSES/MIT-frontend.txt"
    else
        cp "$PKG_DIR/LICENSE" "$LICENSES/binding-attribution.txt"
    fi
    # A MIT stub is not the license of the combined EUPL package.
    rm "$PKG_DIR/LICENSE"
fi
find "$HIGHS_SRC" -type f \( -iname '*license*' -o -iname '*licence*' \
    -o -iname 'copying*' -o -iname 'copyright*' -o -iname 'notice*' \) \
    -not -path '*/.git/*' | while IFS= read -r license; do
    relative="${license#"$HIGHS_SRC"/}"
    destination="$LICENSES/HiGHS/$relative"
    mkdir -p "$(dirname "$destination")"
    cp "$license" "$destination"
done
if [[ -f "$HIGHS_SRC/THIRD_PARTY_NOTICES.md" ]]; then
    cp "$HIGHS_SRC/THIRD_PARTY_NOTICES.md" "$LICENSES/HiGHS/"
fi

echo "staged: $PKG_DIR"
echo "  engine: $ENGINE_SHA (HiGHS $HIGHS_TAG)"
echo "  submodules: core=$CORE_SHA csp=$CSP_SHA hitas=$HITAS_SHA crp=$CRP_SHA rounder=$ROUNDER_SHA"
echo "  version: $VERSION"
echo
echo "next: R CMD build $PKG_DIR"
