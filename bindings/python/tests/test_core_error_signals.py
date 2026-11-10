"""0.7.0 error contract: binding-level failure signals.

The binding must expose the native success flag and error code for
every entry point that has one, instead of discarding them. The
failure paths below need no data: an engine with declared but
unprepared tables and out-of-range indices is the fixture.
"""


def _load():
    import _tauargus

    return _tauargus


def _engine_with_empty_table():
    m = _load()
    t = m.TauArgus()
    assert t.set_number_var(1)
    assert t.set_number_tab(1)
    return t


def test_get_var_number_of_codes_reports_ok():
    t = _engine_with_empty_table()
    assert t.get_var_number_of_codes(9) == (False, 0, 0)
    # A declared but unexplored variable has zero codes and still
    # succeeds: ok is True.
    assert t.get_var_number_of_codes(0) == (True, 0, 0)


def test_cell_getters_report_ok():
    t = _engine_with_empty_table()
    assert t.get_table_cell_value(0, 0) == (False, 0.0)
    assert t.get_table_cell_status(0, 0) == (False, 0)
    assert t.get_table_cell_protection_levels(0, 0) == (False, 0.0, 0.0)
    assert t.get_table_cell_value(9, 0) == (False, 0.0)
    assert t.get_table_cell_status(9, 0) == (False, 0)
    assert t.get_table_cell_protection_levels(9, 0) == (False, 0.0, 0.0)


def test_table_size_and_bounds_report_ok():
    t = _engine_with_empty_table()
    assert t.get_total_table_size(0) == (False, 0, 0)
    assert t.get_total_table_size(9) == (False, 0, 0)
    assert t.get_minimum_cell_value(0) == (False, 0.0, 0.0)
    assert t.get_minimum_cell_value(9) == (False, 0.0, 0.0)
    assert t.maximum_protection_level(0) == 0.0
    assert t.maximum_protection_level(9) == 0.0


def test_set_in_table_reports_error_code():
    t = _engine_with_empty_table()
    ok, err, ev = t.set_in_table(
        9, ["1"], 0.0, 0.0, 1.0, 0, [], [], 0, 0.0, 1.0)
    assert ok is False
    assert err != 0, "a failed set_in_table must carry the native code"
    assert ev == 0


def test_set_table_safety_info_reports_error_code():
    t = _engine_with_empty_table()
    ok, errc = t.set_table_safety_info(
        9, False, False, [], [], False, [], [], [], False, 0, 0,
        False, 0, False, 0.0, False, 0)
    assert ok is False
    assert errc != 0, "a failed set_table_safety_info must carry the code"
