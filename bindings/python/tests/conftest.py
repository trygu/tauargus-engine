"""Bootstrap for the Python binding smoke tests.

Builds the ``_tauargus`` extension with CMake into a scratch dir and puts
it on ``sys.path``. The engine superbuild output (``engine/build/lib``)
must exist first; build it with the engine repo's normal command:

    cmake -S engine -B engine/build -DHighs_DIR=$(brew --prefix)/lib/cmake/Highs
    cmake --build engine/build
"""

import os
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


def _build_extension() -> None:
    PKG_DIR.mkdir(parents=True, exist_ok=True)
    cmd = [
        "cmake",
        "-S", str(BIND_DIR),
        "-B", str(EXT_DIR),
        f"-DTAUARGUS_PY_PKG_DIR={PKG_DIR}",
        f"-Dpybind11_DIR={_pybind11_dir()}",
    ]
    subprocess.run(cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    jobs = str(os.cpu_count() or 4)
    subprocess.run(
        ["cmake", "--build", str(EXT_DIR), "-j", jobs],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


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
