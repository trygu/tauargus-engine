"""View-model tests for the TUI.

These encode the legacy contract the TUI reads from the engine: the same
tables, codes, cell values and status symbols the CLI and notebooks already
produce for ``TestRecode.arb``. The model layer must expose them as plain
Python so the textual widgets never touch the native bindings directly.
"""

from pathlib import Path

import pytest

from pytauargus_tui.model import (
    Session,
    SuppressionOp,
    arb_with_ops,
    format_status_delta,
)

DATA = Path(__file__).resolve().parent.parent.parent.parent / "data"
ARB = DATA / "TestRecode.arb"


@pytest.fixture(scope="module")
def session() -> Session:
    return Session.from_arb(ARB)


def test_table_count(session):
    assert session.n_tables == 2


def test_table_meta(session):
    t0 = session.table(0)
    assert t0.exp_vars == ("Size", "Region")
    assert t0.resp_var == "Var2"
    assert t0.n_cells == 126
    t1 = session.table(1)
    assert t1.exp_vars == ("Region", "IndustryCode")
    assert t1.n_cells == 12726


def test_grid_shape(session):
    g = session.grid(0)
    assert g.row_var == "Size"
    assert g.col_var == "Region"
    assert len(g.rows) == 7
    assert len(g.cols) == 18
    assert len(g.cells) == 7
    assert all(len(row) == 18 for row in g.cells)


def test_grid_cell_values(session):
    g = session.grid(0)
    # Every populated cell has an int status in the known range and a float value.
    for row in g.cells:
        for cell in row:
            assert isinstance(cell.status, int)
            assert 1 <= cell.status <= 14
            assert isinstance(cell.value, float)
            assert cell.symbol in ("S", "U", "P", "M", "E", "?")


def test_grid_total_cell_count(session):
    g = session.grid(0)
    assert sum(len(row) for row in g.cells) == g.tab.n_cells


def test_status_names(session):
    g = session.grid(0)
    # The pre-suppression sample batch is fully safe, so the first cell is safe.
    assert g.cells[0][0].status_name in ("safe", "safe_manual")


def test_rule_display(session):
    t0 = session.table(0)
    # The batch declares NK(2,75) for table 1 (0-based index 0).
    assert any("NK" in r and "2" in r and "75" in r for r in t0.rules)


# ===========================================================================
# Staged suppression + preview (design §B.3)
# ===========================================================================
def test_suppression_op_arb_lines():
    assert SuppressionOp("OPT", 2).arb_line() == "<SUPPRESS> OPT(2)"
    assert SuppressionOp("MOD", 1).arb_line() == "<SUPPRESS> MOD(1)"
    assert (SuppressionOp("RND", 3, rnd_base=1000000).arb_line()
            == "<SUPPRESS> RND(3,1000000)")


def test_arb_with_ops_appends():
    # No <WRITETABLE> in the spec: lines are appended at the end.
    out = arb_with_ops("a\nb\n", [SuppressionOp("OPT", 1)])
    assert out == "a\nb\n<SUPPRESS> OPT(1)\n"


def test_arb_with_ops_before_writetable():
    out = arb_with_ops('a\n<WRITETABLE> (1,1,0,"x")\n',
                       [SuppressionOp("RND", 2, 10)])
    assert out == 'a\n<SUPPRESS> RND(2,10)\n<WRITETABLE> (1,1,0,"x")\n'


def test_format_status_delta():
    d = format_status_delta({1: 104, 3: 1}, {1: 101, 3: 1, 11: 3})
    assert "safe 104→101" in d
    assert "unsafe_rule 1→1" in d
    assert "secondary_unsafe 0→3" in d
    # Stable ordering: ascending status code.
    assert d.index("safe") < d.index("unsafe_rule") < d.index("secondary_unsafe")


def test_status_counts(session):
    counts = session.status_counts(0)
    assert sum(counts.values()) == 126
    assert all(1 <= k <= 14 for k in counts)
    # The pre-suppression sample batch has safe cells.
    assert counts.get(1, 0) + counts.get(2, 0) > 0


@pytest.fixture(scope="module")
def preview_session(session):
    """Throwaway run of the same .arb with OPT(1) appended (design §B.3)."""
    return session.preview([SuppressionOp("OPT", 1)])


def test_preview_is_a_full_session(preview_session):
    assert preview_session.n_tables == 2
    assert preview_session.table(0).n_cells == 126


def test_preview_changes_table_statuses(session, preview_session):
    before = session.status_counts(0)
    after = preview_session.status_counts(0)
    assert sum(after.values()) == 126
    # The previewed OPT(1) changes table 1's cell statuses.
    assert after != before
