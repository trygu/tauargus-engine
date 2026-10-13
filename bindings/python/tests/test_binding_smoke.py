"""Binding smoke: the ``_tauargus`` extension compiles, links and constructs.

This is the thin binding contract on the engine side. Package-level
behaviour (batch, CLI, protect, TUI) is tested in the pytauargus repo.

The extension is built by the session fixture in ``conftest.py``; import it
inside the tests, not at module level (collection runs before the fixture).
"""


def _load():
    import _tauargus

    return _tauargus


def test_module_surface():
    m = _load()
    assert hasattr(m, "TauArgus")
    assert hasattr(m, "HiTaSCtrl")
    assert hasattr(m, "RounderCtrl")
    assert hasattr(m, "audit_jj")


def test_tauargus_constructs_and_reports_version():
    m = _load()
    engine = m.TauArgus()
    version = engine.version()
    assert isinstance(version, str)
    assert version
