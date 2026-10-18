"""Bootstrap for the Python binding smoke tests.

Builds the ``_tauargus`` extension with CMake into a scratch dir and puts
it on ``sys.path``. The engine superbuild output (``engine/build/lib``)
must exist first; build it with the engine repo's normal command:

    cmake -S engine -B engine/build -DHighs_DIR=$(brew --prefix)/lib/cmake/Highs
    cmake --build engine/build
"""

import os
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[3]
BIND_DIR = ROOT / "bindings" / "python"
EXT_DIR = BIND_DIR / "build-ext"
PKG_DIR = EXT_DIR / "pytauargus"


def _pybind11_dir() -> str:
    import pybind11

    return pybind11.get_cmake_dir()


def _drop_stale_cache() -> None:
    """A cache configured against a Python that no longer exists (e.g. an
    earlier ``uv run`` ephemeral env) breaks find_package(Python); drop it."""
    cache = EXT_DIR / "CMakeCache.txt"
    if not cache.exists():
        return
    for line in cache.read_text().splitlines():
        if line.startswith("PYTHON_EXECUTABLE:"):
            value = line.split("=", 1)[1].strip().strip('"')
            if value and not Path(value).exists():
                shutil.rmtree(EXT_DIR)
            return


def _run(cmd: list[str]) -> None:
    """Run a cmake step; on failure surface the captured output, not just
    the exit code (the CI log otherwise shows no actionable error)."""
    try:
        subprocess.run(
            cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        )
    except subprocess.CalledProcessError as exc:
        tail = (exc.stderr or b"").decode(errors="replace")[-4000:]
        raise RuntimeError(
            f"command failed ({exc.returncode}): {' '.join(cmd)}\n{tail}"
        ) from None


def _build_extension() -> None:
    _drop_stale_cache()
    PKG_DIR.mkdir(parents=True, exist_ok=True)
    cmd = [
        "cmake",
        "-S", str(BIND_DIR),
        "-B", str(EXT_DIR),
        f"-DTAUARGUS_PY_PKG_DIR={PKG_DIR}",
        f"-Dpybind11_DIR={_pybind11_dir()}",
    ]
    _run(cmd)
    build = ["cmake", "--build", str(EXT_DIR), "-j", str(os.cpu_count() or 4)]
    if os.name == "nt":
        # The Visual Studio generator is multi-config and defaults to
        # Debug, which needs the (unshipped) debug Python import lib and
        # does not match the Release engine libs we link. Select Release
        # explicitly, like the engine build and the wheel build do.
        build += ["--config", "Release"]
    _run(build)


@pytest.fixture(scope="session", autouse=True)
def extension_on_path():
    """Compile and link the extension against the prebuilt engine."""
    if not (ROOT / "engine" / "build" / "lib").is_dir():
        pytest.fail(
            "engine/build/lib is missing; build the superbuild first: "
            "cmake -S engine -B engine/build "
            "-DHighs_DIR=$(brew --prefix)/lib/cmake/Highs && "
            "cmake --build engine/build"
        )
    _build_extension()
    if str(PKG_DIR) not in sys.path:
        sys.path.insert(0, str(PKG_DIR))
