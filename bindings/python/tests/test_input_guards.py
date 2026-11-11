"""Phase 4.2: input guards for the pybind11 layer.

Invalid input must raise a clean typed Python error that names the
argument before it reaches the native core:

- negative values for index/count arguments -> ValueError;
- NaN/Inf (or negative values) for documented non-negative doubles
  (cost, lam, protection levels, zero safety range, max scale, the
  rounder base) -> ValueError;
- NaN for bound vectors, while +/-Inf (unbounded) stays legal ->
  ValueError only for NaN;
- out-of-int64-range and fractional values for integer arguments are
  rejected by the pybind11 argument casters (OverflowError /
  TypeError).

Arguments that carry the legacy "none" sentinel (``shadow_var=-1``,
``cost_var=-1``, ``cellkey_var=-1``, ``peep_var=-1`` in ``set_table``)
stay legal.

The extension is built by the session fixture in ``conftest.py``;
import it inside the tests, not at module level.
"""

import pytest


def _load():
    import _tauargus

    return _tauargus


VAR_KW = dict(
    b_pos=1, n_pos=3, n_dec=0, n_missing=0,
    missing1="", missing2="", total_code="",
    is_peeper=False, peeper_code1="", peeper_code2="",
    is_categorical=True, is_numeric=False, is_weight=False,
    is_hierarchical=False, is_holding=False, is_record_key=False,
)


def _fresh():
    t = _load().TauArgus()
    t.clean_all()
    t.set_in_file_info(True, "")
    return t


def _one_var_one_table():
    """One hierarchical variable, one table slot: the minimal state in
    which ``set_table`` with sentinel values is a legal native call."""
    t = _fresh()
    t.set_number_var(1)
    assert t.set_variable(index=0, **dict(VAR_KW, is_hierarchical=True))
    # the digit sum must equal the variable's position count (n_pos=3)
    assert t.set_hierarchical_digits(0, [3])
    t.set_number_tab(1)
    return t


# -- counts -------------------------------------------------------------------

def test_set_number_tab_negative():
    t = _fresh()
    with pytest.raises(ValueError, match="n_tab"):
        t.set_number_tab(-1)


def test_set_number_var_negative():
    t = _fresh()
    with pytest.raises(ValueError, match="n_var"):
        t.set_number_var(-1)


def test_long_overflow_rejected():
    t = _fresh()
    # pybind11's integer caster rejects out-of-int64-range values with a
    # clean TypeError (older/newer versions may use OverflowError)
    with pytest.raises((TypeError, OverflowError)):
        t.set_number_tab(2 ** 63)


def test_fractional_long_rejected():
    t = _fresh()
    with pytest.raises(TypeError):
        t.set_number_tab(1.5)


# -- variable registration ------------------------------------------------------

def test_set_variable_negative_index():
    t = _fresh()
    with pytest.raises(ValueError, match="index"):
        t.set_variable(index=-1, **VAR_KW)


def test_set_variable_negative_n_dec():
    t = _fresh()
    with pytest.raises(ValueError, match="n_dec"):
        t.set_variable(index=0, **dict(VAR_KW, n_dec=-1))


def test_set_hierarchical_codelist_negative_var():
    t = _one_var_one_table()
    with pytest.raises(ValueError, match="var"):
        t.set_hierarchical_codelist(-1, "does-not-exist", "1.")


def test_set_hierarchical_digits_negative_element():
    t = _one_var_one_table()
    with pytest.raises(ValueError, match="digits"):
        t.set_hierarchical_digits(0, [1, -1])


def test_get_var_code_negative_var_or_code():
    t = _one_var_one_table()
    with pytest.raises(ValueError, match="var"):
        t.get_var_code(-1, 0)
    with pytest.raises(ValueError, match="code"):
        t.get_var_code(0, -1)


def test_set_var_code_active_negative_code():
    t = _one_var_one_table()
    with pytest.raises(ValueError, match="code"):
        t.set_var_code_active(0, -1, False)


def test_undo_recode_negative_var():
    t = _one_var_one_table()
    with pytest.raises(ValueError, match="var"):
        t.undo_recode(-1)


def test_do_recode_negative_n_missing():
    t = _one_var_one_table()
    with pytest.raises(ValueError, match="n_missing"):
        t.do_recode(0, "1:1", -1, "m", "")


# -- table specification ----------------------------------------------------------

def test_set_table_negative_index():
    t = _one_var_one_table()
    with pytest.raises(ValueError, match="index"):
        t.set_table(-1, [0], False, 0, -1, -1, -1)


def test_set_table_negative_explanatory_or_response():
    t = _one_var_one_table()
    with pytest.raises(ValueError, match="explanatory_vars"):
        t.set_table(0, [-1], False, 0, -1, -1, -1)
    with pytest.raises(ValueError, match="response_var"):
        t.set_table(0, [0], False, -1, -1, -1, -1)


def test_set_table_sentinels_allowed():
    # shadow/cost/cellkey/peep_var carry the legacy "none" sentinel -1.
    t = _one_var_one_table()
    t.set_table(0, [0], False, 0, -1, -1, -1, "", 0, 0.0, 0.0, -1, False)
    # must not raise ValueError (the native call may return False)


def test_set_table_nan_lam():
    t = _one_var_one_table()
    with pytest.raises(ValueError, match="lam"):
        t.set_table(0, [0], False, 0, -1, -1, -1, "", 0, float("nan"),
                    0.0, -1, False)


def test_set_table_safety_info_nan_zero_range():
    t = _one_var_one_table()
    with pytest.raises(ValueError, match="zero_safety_range"):
        t.set_table_safety_info(0, False, False, [], [], False, [], [],
                                [], False, 0, 0, False, 0, False,
                                float("nan"), False, 0)


# -- cell access ---------------------------------------------------------------------

def test_set_table_cell_cost_rejects_bad_values():
    t = _one_var_one_table()
    with pytest.raises(ValueError, match="cost"):
        t.set_table_cell_cost(0, [0], float("nan"))
    with pytest.raises(ValueError, match="cost"):
        t.set_table_cell_cost(0, [0], float("inf"))
    with pytest.raises(ValueError, match="cost"):
        t.set_table_cell_cost(0, [0], -1.0)


def test_set_table_cell_status_cell_negative_tab_or_cell():
    t = _one_var_one_table()
    with pytest.raises(ValueError, match="tab"):
        t.set_table_cell_status_cell(-1, 0, 1)
    with pytest.raises(ValueError, match="cell"):
        t.set_table_cell_status_cell(0, -1, 1)


def test_set_table_cell_protection_levels_rejects_bad_values():
    t = _one_var_one_table()
    with pytest.raises(ValueError, match="lpl"):
        t.set_table_cell_protection_levels(0, 0, float("nan"), 0.0)
    with pytest.raises(ValueError, match="upl"):
        t.set_table_cell_protection_levels(0, 0, 0.0, float("-inf"))


def test_set_protection_levels_dim_negative_dim():
    t = _one_var_one_table()
    with pytest.raises(ValueError, match="dim_index"):
        t.set_protection_levels_dim(0, [-1], 0.0, 0.0)


def test_get_table_cell_negative_tab_or_dim():
    t = _one_var_one_table()
    with pytest.raises(ValueError, match="tab"):
        t.get_table_cell(-1, [0], 0)
    with pytest.raises(ValueError, match="dim_index"):
        t.get_table_cell(0, [-1], 0)


def test_set_in_table_negative_or_nan():
    t = _one_var_one_table()
    with pytest.raises(ValueError, match="index"):
        t.set_in_table(-1, ["A"], 0.0, 0.0, 1.0, 0, [], [], 0, 0.0, 0.0)
    with pytest.raises(ValueError, match="freq"):
        t.set_in_table(0, ["A"], 0.0, 0.0, 1.0, -1, [], [], 0, 0.0, 0.0)
    with pytest.raises(ValueError, match="lpl"):
        t.set_in_table(0, ["A"], 0.0, 0.0, 1.0, 0, [], [], 0,
                       float("nan"), 0.0)


def test_set_in_code_list_negative_var():
    t = _one_var_one_table()
    with pytest.raises(ValueError, match="var_index"):
        t.set_in_code_list([-1], ["A"])
    with pytest.raises(ValueError, match="var_index"):
        t.set_totals_in_code_list([-1])


# -- writers / completion ---------------------------------------------------------

def test_completed_table_negative_index():
    t = _one_var_one_table()
    with pytest.raises(ValueError, match="index"):
        t.completed_table(-1, "/tmp/does-not-exist.tab", True, True, False)


def test_write_csv_negative_tab_or_dim():
    t = _one_var_one_table()
    with pytest.raises(ValueError, match="tab"):
        t.write_csv(-1, "/tmp/guard.csv")
    with pytest.raises(ValueError, match="dim_sequence"):
        t.write_csv(0, "/tmp/guard.csv", True, [-1], 1)


def test_write_cell_records_negative_tab():
    t = _one_var_one_table()
    with pytest.raises(ValueError, match="tab"):
        t.write_cell_records(-1, "/tmp/guard.csv", False)


def test_write_jj_format_rejects_nan_bounds(tmp_path):
    t = _one_var_one_table()
    jj = tmp_path / "a.jj"
    with pytest.raises(ValueError, match="lower"):
        t.write_jj_format(0, str(jj), float("nan"), 10.0)
    with pytest.raises(ValueError, match="upper"):
        t.write_jj_format(0, str(jj), 0.0, float("nan"))


def test_write_hierarchical_ampl_negative_max_scale(tmp_path):
    t = _one_var_one_table()
    with pytest.raises(ValueError, match="max_scale"):
        t.write_hierarchical_table_in_ampl_format(
            str(tmp_path / "a.ampl"), str(tmp_path), -1, -2.0)
    with pytest.raises(ValueError, match="max_scale"):
        t.write_hierarchical_table_in_ampl_format(
            str(tmp_path / "a.ampl"), str(tmp_path), 0, float("inf"))


# -- HiTaS ---------------------------------------------------------------------------

def test_full_jj_negative_max_time():
    h = _load().HiTaSCtrl()
    with pytest.raises(ValueError, match="max_time"):
        h.full_jj("/tmp/does-not-exist.jj", "/tmp/out.jj", -1)


def test_a_hitas_negative_max_time():
    h = _load().HiTaSCtrl()
    with pytest.raises(ValueError, match="max_time"):
        h.a_hitas("pars", "files", -1)


# -- rounder ---------------------------------------------------------------------------

def _bad_jj(tmp_path):
    jj = tmp_path / "bad.jj"
    jj.write_text("99", encoding="utf-8")
    return str(jj)


def test_do_round_rejects_bad_base_and_time(tmp_path):
    r = _load().RounderCtrl()
    jj = _bad_jj(tmp_path)
    with pytest.raises(ValueError, match="base"):
        r.do_round("SCIP", jj, float("nan"))
    with pytest.raises(ValueError, match="base"):
        r.do_round("SCIP", jj, -5.0)
    with pytest.raises(ValueError, match="max_time"):
        r.do_round("SCIP", jj, 5.0, max_time=-1)


def test_do_round_upper_rejects_nan_allows_inf(tmp_path):
    r = _load().RounderCtrl()
    jj = _bad_jj(tmp_path)
    with pytest.raises(ValueError, match="upper"):
        r.do_round("SCIP", jj, 5.0, [1.0, float("nan")])
    # +/-Inf bounds are legal (unbounded); the call passes the guards and
    # fails inside the solver on the malformed file, like the R binding
    # contract (test_input_guards.R).
    res = r.do_round("SCIP", jj, 5.0, [1.0, float("inf")], [0.0, 0.0])
    assert isinstance(res, tuple) and len(res) == 5


# -- the object stays usable after rejected calls ---------------------------------------

def test_usable_after_rejected_calls():
    t = _fresh()
    with pytest.raises(ValueError):
        t.set_number_tab(-1)
    with pytest.raises(ValueError):
        t.set_table_cell_cost(0, [0], float("nan"))
    assert isinstance(t.version(), str) and t.version()
