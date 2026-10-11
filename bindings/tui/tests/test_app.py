"""TUI app tests (headless, via textual's Pilot).

Drive the real app against ``data/TestRecode.arb``: load, navigator,
grid shape, cell detail, table switching, and the action keys.
"""

import time
from pathlib import Path

import pytest
from textual.widgets import DataTable, ListView

from pytauargus_tui.app import TauArgusApp, _BusySpinner

DATA = Path(__file__).resolve().parent.parent.parent.parent / "data"
ARB = DATA / "TestRecode.arb"


async def wait_for(pilot, pred, timeout=30.0, what="condition"):
    deadline = time.monotonic() + timeout
    while not pred():
        if time.monotonic() > deadline:
            raise AssertionError(f"timed out waiting for {what}")
        await pilot.pause()


@pytest.fixture
def app() -> TauArgusApp:
    return TauArgusApp(ARB)


def grid(app) -> DataTable:
    return app.query_one("#grid", DataTable)


async def test_app_loads_batch(app):
    async with app.run_test(size=(120, 35)) as pilot:
        await wait_for(pilot, lambda: app.session is not None, what="session load")
        assert app.session.n_tables == 2
        nav = app.query_one("#nav", ListView)
        await wait_for(pilot, lambda: len(nav.children) == 2, what="nav rows")
        # Table 0 = Size(7 rows) x Region(18 cols) + 1 label column.
        await wait_for(pilot, lambda: grid(app).row_count == 7, what="grid")
        assert len(grid(app).columns) == 19
        assert app.current_table == 0


async def test_grid_cell_status_colors(app):
    async with app.run_test(size=(120, 35)) as pilot:
        await wait_for(pilot, lambda: app.session is not None)
        await wait_for(pilot, lambda: grid(app).row_count == 7, what="grid")
        # Every data cell is a rich Text with a style (status colour).
        from rich.text import Text

        ncols = len(grid(app).columns)
        for r in range(grid(app).row_count):
            for c in range(1, ncols):
                val = grid(app).get_cell(f"r{r}", f"c{c - 1}")
                assert isinstance(val, Text)
                assert val.style in ("green", "red", "cyan", "yellow", "dim")


async def test_table_switch_jk(app):
    async with app.run_test(size=(120, 35)) as pilot:
        await wait_for(pilot, lambda: app.session is not None)
        await wait_for(pilot, lambda: grid(app).row_count == 7, what="grid")
        await pilot.press("j")
        assert app.current_table == 1
        # Table 1 = Region(18 rows) x IndustryCode(707 cols) + label column.
        await wait_for(pilot, lambda: grid(app).row_count == 18, what="grid 1")
        assert len(grid(app).columns) == 708
        await pilot.press("k")
        assert app.current_table == 0
        await wait_for(pilot, lambda: grid(app).row_count == 7, what="grid 0")


async def test_cell_detail(app):
    async with app.run_test(size=(120, 35)) as pilot:
        await wait_for(pilot, lambda: app.session is not None)
        await wait_for(pilot, lambda: grid(app).row_count == 7, what="grid")
        g = grid(app)
        g.move_cursor(row=1, column=2)
        await wait_for(
            pilot,
            lambda: "value=" in app.detail_text and "status=" in app.detail_text,
            what="cell detail",
        )
        assert "cell (" in app.detail_text


async def _loaded(pilot, app) -> None:
    await wait_for(pilot, lambda: app.session is not None, what="session load")
    await wait_for(pilot, lambda: grid(app).row_count == 7, what="grid")


# ===========================================================================
# Staged suppress/round: preview before committing (design §B.3)
# ===========================================================================
async def test_suppress_stages_preview_not_live(app):
    async with app.run_test(size=(120, 35)) as pilot:
        await _loaded(pilot, app)
        before = app.session.status_counts(0)
        # NB: textual 8.x Pilot.press waits for process CPU to idle, which
        # includes the engine worker thread — so the busy window is not
        # observable around press. The spinner contract is covered by
        # test_spinner_tracks_busy_flag instead.
        await pilot.press("s")
        await wait_for(pilot, lambda: app.preview is not None, what="preview")
        assert app.busy is False  # spinner down once the preview lands
        # The live session is untouched while a preview is pending.
        assert app.session.status_counts(0) == before
        assert app.pending is not None
        assert "→" in app.preview_delta
        assert app.last_action == "OPT previewed on table 1"


async def test_spinner_tracks_busy_flag(app):
    """The busy flag drives the spinner: visible + animated while True."""
    async with app.run_test(size=(120, 35)) as pilot:
        await wait_for(pilot, lambda: app.session is not None, what="load")
        assert app.busy is False  # settled after the load worker
        spin = app.query_one("#spin", _BusySpinner)
        assert spin.visible is False
        app._set_busy(True)
        assert app.busy is True
        assert spin.visible is True
        assert str(spin.render()).strip() != ""  # a frame is drawn
        app._set_busy(False)
        assert app.busy is False
        assert spin.visible is False


async def test_round_stages_preview(app):
    async with app.run_test(size=(120, 35)) as pilot:
        await _loaded(pilot, app)
        await pilot.press("r")
        await wait_for(pilot, lambda: app.preview is not None, what="RND preview")
        assert "→" in app.preview_delta
        assert app.last_action == "RND previewed on table 1"


async def test_confirm_adopts_preview(app):
    async with app.run_test(size=(120, 35)) as pilot:
        await _loaded(pilot, app)
        before = app.session.status_counts(0)
        await pilot.press("s")
        await wait_for(pilot, lambda: app.preview is not None, what="preview")
        preview_sess = app.preview
        await pilot.press("y")
        assert app.preview is None and app.pending is None
        # The previewed run becomes the working session (design §B.3).
        assert app.session is preview_sess
        assert app.session.status_counts(0) != before
        assert app.last_action == "OPT confirmed on table 1"
        # The grid shows the adopted (suppressed) table.
        assert grid(app).row_count == 7


async def test_cancel_keeps_live(app):
    async with app.run_test(size=(120, 35)) as pilot:
        await _loaded(pilot, app)
        before = app.session.status_counts(0)
        await pilot.press("s")
        await wait_for(pilot, lambda: app.preview is not None, what="preview")
        await pilot.press("n")
        assert app.preview is None and app.pending is None
        assert app.session.status_counts(0) == before
        assert app.last_action == "OPT preview cancelled"


async def test_second_opt_preview_surfaces_5008(app):
    """A second OPT on an already-optimised table fails with legacy code
    5008; the TUI surfaces it as an error (no crash) and drops the pending
    preview. This also proves confirmed ops carry into the next preview:
    without the confirmed OPT(1) in the previewed .arb, the second preview
    would have succeeded."""
    async with app.run_test(size=(120, 35)) as pilot:
        await _loaded(pilot, app)
        await pilot.press("s")
        await wait_for(pilot, lambda: app.preview is not None, what="preview 1")
        await pilot.press("y")  # adopt the first OPT
        assert app.last_action == "OPT confirmed on table 1"
        assert [op.arb_line() for op in app.confirmed_ops] == ["<SUPPRESS> OPT(1)"]
        await pilot.press("s")  # preview a second OPT on the same table
        await wait_for(pilot, lambda: "5008" in app.log_text, what="5008 error")
        assert app.preview is None and app.pending is None
        assert app.busy is False


async def test_save_action_writes_tab(app, tmp_path):
    # Point the app at a copy of the batch so `out/` lands in tmp_path.
    import shutil

    arb = tmp_path / "TestRecode.arb"
    shutil.copy(ARB, arb)
    # The batch references data files relative to the arb's directory.
    for f in ("tau_testW.asc", "tau_testW.rda", "GK.grc", "IndCode2.grc",
              "region2.hrc"):
        shutil.copy(DATA / f, tmp_path / f)
    app = TauArgusApp(arb)
    async with app.run_test(size=(120, 35)) as pilot:
        await wait_for(pilot, lambda: app.session is not None, what="load")
        await wait_for(pilot, lambda: grid(app).row_count == 7, what="grid")
        await pilot.press("o")
        await wait_for(pilot, lambda: app.log_text.startswith("saved "),
                       what="save log")
        out = tmp_path / "out" / "table_1.tab"
        assert out.is_file()
        content = out.read_text()
        assert len(content.splitlines()) > 7
