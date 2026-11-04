#!/usr/bin/env bash
# The CRAN check wrapper rejects bare R and Rscript commands on PATH.
# Both install launchers must use the R_HOME supplied by R CMD INSTALL.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/R home/bin" "$WORK/wrappers"
cat > "$WORK/R home/bin/Rscript" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" > "$CONFIGURE_TEST_ARGS"
EOF
chmod +x "$WORK/R home/bin/Rscript"
for command in R Rscript; do
    cat > "$WORK/wrappers/$command" <<'EOF'
#!/bin/sh
echo "bare R commands must not be used during CRAN checks" >&2
exit 1
EOF
    chmod +x "$WORK/wrappers/$command"
done
printf '%s\n' configure.R 'argument with spaces' --test > "$WORK/expected"
for launcher in configure configure.win; do
    CONFIGURE_TEST_ARGS="$WORK/args" R_HOME="$WORK/R home" \
        PATH="$WORK/wrappers:$PATH" \
        /bin/sh "$ROOT/bindings/r/staging/$launcher" \
        'argument with spaces' --test
    cmp "$WORK/expected" "$WORK/args"
    if (unset R_HOME; /bin/sh "$ROOT/bindings/r/staging/$launcher") \
        > "$WORK/missing-home.log" 2>&1; then
        echo "$launcher accepted a missing R_HOME" >&2
        exit 1
    fi
    grep -q 'R_HOME' "$WORK/missing-home.log"
done
echo 'R configure launchers: passed'
