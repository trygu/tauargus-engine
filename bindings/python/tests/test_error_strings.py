"""0.7.0 error contract: native error-string catalogs (phase 2.3).

Every native error code must translate to a real message, not the
legacy "UnKnown Error (N)" fallback. The catalogs are embedded in the
engine at build time (the legacy TauArgus.properties was loaded from
the working directory and does not survive the headless port).

Core: the ErrorCodes enum (defines.h) covers 1000-1027, 1500-1507,
2000-2006, 3000-3003, 4000-4008, 4200-4202, 4225-4232.
HITAS: the legacy ErrorStrings.txt (5000-5012, 6000-6008, 7000-7003).
Rounder: the CRP ErrorTypes (WrapCRP.h, 7100-7110).
"""

_CORE_RANGES = [
    list(range(1000, 1028)),
    list(range(1500, 1508)),
    list(range(2000, 2007)),
    list(range(3000, 3004)),
    list(range(4000, 4009)),
    list(range(4200, 4203)),
    list(range(4225, 4233)),
]


def _load():
    import _tauargus

    return _tauargus


def _unknown(code):
    return "UnKnown Error (%d)" % code


def test_core_known_codes_translate():
    m = _load()
    t = m.TauArgus()
    for code in (c for r in _CORE_RANGES for c in r):
        msg = t.error_string(code)
        assert isinstance(msg, str)
        assert msg, f"core code {code} has no message"
        assert msg != _unknown(code), (
            f"core code {code} falls back to unknown: {msg!r}"
        )


def test_core_unknown_code_falls_back():
    m = _load()
    t = m.TauArgus()
    assert t.error_string(999999) == _unknown(999999)


def test_core_spotcheck_contract():
    m = _load()
    t = m.TauArgus()
    assert t.error_string(1000) == "File not found"
    assert t.error_string(1015) == "Table is not set"
    assert t.error_string(1017) == "Code not in code list"
    assert t.error_string(1027) == "Code does not exist"
    assert t.error_string(1505) == "Variable is not hierarchical"


def test_hitas_known_codes_translate():
    m = _load()
    h = m.HiTaSCtrl()
    for code in (5000, 5001, 5002, 5009, 6000, 6004, 7002):
        msg = h.error_string(code)
        assert isinstance(msg, str)
        assert msg, f"hitas code {code} has no message"


def test_hitas_unknown_code_falls_back():
    m = _load()
    h = m.HiTaSCtrl()
    assert h.error_string(999999) == _unknown(999999)


def test_rounder_known_codes_translate():
    m = _load()
    r = m.RounderCtrl()
    for code in (7100, 7104, 7105, 7110):
        msg = r.error_string(code)
        assert isinstance(msg, str)
        assert msg, f"rounder code {code} has no message"


def test_rounder_infeasible_message():
    m = _load()
    r = m.RounderCtrl()
    assert "infeasible" in r.error_string(7105).lower()
