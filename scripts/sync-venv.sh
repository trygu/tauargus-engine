#!/usr/bin/env bash
# Sync a Python venv with the current tree: engine -> wheel -> venv.
#
# Run this after ANY change under engine/ (or bindings/python) so that the
# fix lands in the venv — one command instead of build, wheel, install:
#
#   scripts/sync-venv.sh bindings/tui/.venv
#
# The TUI dev venv must run a locally built wheel, never the PyPI one:
# PyPI lags behind in-tree engine fixes by a full release cycle.
#
# The script gates on submodule drift first: a '+' line in
# `git submodule status` means an engine worktree does not match the commit
# the parent records, so the built wheel would not represent the tree.
set -euo pipefail
cd "$(dirname "$0")/.."

VENV="${1:-}"
if [[ -z "$VENV" || ! -x "$VENV/bin/python" ]]; then
    echo "usage: scripts/sync-venv.sh <path-to-venv>" >&2
    exit 2
fi
VENV="$(cd "$VENV" && pwd)"
VENV_PY="$VENV/bin/python"

# Gate: submodule worktrees must match the pins recorded by the parent.
drift="$(git submodule status | grep '^+' || true)"
if [[ -n "$drift" ]]; then
    echo "submodule worktree drift (worktree != recorded pin):" >&2
    echo "$drift" >&2
    echo "restore with: git submodule update --checkout <name>" >&2
    exit 1
fi

JOBS="$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)"
HIGHS_DIR="${HIGHS_DIR:-$(brew --prefix)/lib/cmake/Highs}"

# 1) Release engine.
cmake -S engine -B engine/build -DHighs_DIR="$HIGHS_DIR" > /dev/null
cmake --build engine/build --parallel "$JOBS" > /dev/null

# 2) Wheel matching the venv's Python (uv build must run in the package dir;
# the freshest wheel in dist/ is the one just built).
if ! WHEEL="$(cd bindings/python && uv build --wheel --python "$VENV_PY" -q && ls -t dist/*.whl | head -n1)"; then
    echo "wheel build failed (see: cd bindings/python && uv build --wheel --python \"$VENV_PY\")" >&2
    exit 1
fi

# 3) Force-install into the venv (never touch its other packages).
uv pip install --python "$VENV_PY" --force-reinstall --no-deps "bindings/python/$WHEEL" > /dev/null

echo "synced: $WHEEL -> $VENV"
