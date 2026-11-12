"""Build provenance: the extension exposes the engine commit and HiGHS version."""

import re
from pathlib import Path


def test_engine_meta_reports_provenance():
    import _tauargus

    meta = _tauargus.engine_meta()
    assert re.fullmatch(r"[0-9a-f]{40}", meta["engine_sha"])
    assert re.fullmatch(r"v\d+\.\d+\.\d+", meta["highs_version"])


def test_version_reports_train_version_from_engine_version_file():
    """The runtime version is the train version from engine/ENGINE-VERSION.

    The superbuild injects the file's content into the modules at
    configure time; a module built outside the superbuild falls back to
    its legacy version macro.
    """
    import _tauargus

    root = Path(__file__).resolve().parents[3]
    expected = (root / "engine" / "ENGINE-VERSION").read_text().strip()
    assert _tauargus.TauArgus().version() == expected
