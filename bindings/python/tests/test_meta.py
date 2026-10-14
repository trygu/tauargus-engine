"""Build provenance: the extension exposes the engine commit and HiGHS version."""

import re


def test_engine_meta_reports_provenance():
    import _tauargus

    meta = _tauargus.engine_meta()
    assert re.fullmatch(r"[0-9a-f]{40}", meta["engine_sha"])
    assert re.fullmatch(r"v\d+\.\d+\.\d+", meta["highs_version"])
