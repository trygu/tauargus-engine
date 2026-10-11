"""TUI app tests (headless, via textual's Pilot).

Drive the real app against ``data/TestRecode.arb``: load, navigator,
grid shape, cell detail, table switching, and the action keys.
"""

import time
from pathlib import Path

import pytest
from textual.widgets import DataTable, DirectoryTree, ListView, Static

from pytauargus_tui.app import (
    TauArgusApp,
    _ArbDirectoryTree,
    _BusySpinner,
    _FileBrowser,
    _HelpScreen,
)

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


# ===========================================================================
# Draft cell instructions (design §B.4 / §B.5)
# ===========================================================================
async def test_cell_mark_updates_draft_only(app):
    """Marking a cell updates the draft immediately: no solver run, the
    live (accepted) session is untouched."""
    async with app.run_test(size=(120, 35)) as pilot:
        await _loaded(pilot, app)
        g = grid(app)
        g.move_cursor(row=1, column=2)
        await wait_for(pilot, lambda: app.cursor == (1, 2), what="cursor")
        before = app.session.status_counts(0)
        await pilot.press("u")
        # Draft updated: one pending instruction, kind U.
        assert len(app.pending_instructions) == 1
        assert app.pending_instructions[0].kind == "U"
        # No preview / solver run was started.
        assert app.preview is None and app.pending is None
        # Live session untouched.
        assert app.session.status_counts(0) == before


async def test_cell_mark_toggle_off(app):
    async with app.run_test(size=(120, 35)) as pilot:
        await _loaded(pilot, app)
        g = grid(app)
        g.move_cursor(row=1, column=2)
        await wait_for(pilot, lambda: app.cursor == (1, 2), what="cursor")
        await pilot.press("u")
        assert len(app.pending_instructions) == 1
        await pilot.press("u")  # the same mark again clears it
        assert len(app.pending_instructions) == 0


async def test_cell_mark_replaces_kind(app):
    async with app.run_test(size=(120, 35)) as pilot:
        await _loaded(pilot, app)
        g = grid(app)
        g.move_cursor(row=1, column=2)
        await wait_for(pilot, lambda: app.cursor == (1, 2), what="cursor")
        await pilot.press("u")
        await pilot.press("p")  # a different mark on the same cell replaces it
        assert len(app.pending_instructions) == 1
        assert app.pending_instructions[0].kind == "P"


async def test_cell_mark_safe_shift_s(app):
    async with app.run_test(size=(120, 35)) as pilot:
        await _loaded(pilot, app)
        g = grid(app)
        g.move_cursor(row=1, column=2)
        await wait_for(pilot, lambda: app.cursor == (1, 2), what="cursor")
        await pilot.press("shift+s")
        assert len(app.pending_instructions) == 1
        assert app.pending_instructions[0].kind == "S"


async def test_preview_batches_marks_and_accept(app):
    """Two marks + OPT: one preview run applies both; accepting commits both
    and promotes them to the confirmed draft."""
    async with app.run_test(size=(120, 35)) as pilot:
        await _loaded(pilot, app)
        g = grid(app)
        g.move_cursor(row=1, column=2)
        await wait_for(pilot, lambda: app.cursor == (1, 2), what="cursor 1")
        await pilot.press("u")
        g.move_cursor(row=2, column=3)
        await wait_for(pilot, lambda: app.cursor == (2, 3), what="cursor 2")
        await pilot.press("u")
        assert len(app.pending_instructions) == 2
        before = app.session.status_counts(0)
        await pilot.press("s")  # OPT preview batches the two marks
        await wait_for(pilot, lambda: app.preview is not None, what="preview")
        await pilot.press("y")  # accept
        assert app.preview is None and app.pending is None
        assert app.session.status_counts(0) != before
        assert len(app.confirmed_instructions) == 2


async def test_discard_keeps_marks_and_live(app):
    """Discarding a preview keeps the draft marks and the accepted run."""
    async with app.run_test(size=(120, 35)) as pilot:
        await _loaded(pilot, app)
        g = grid(app)
        g.move_cursor(row=1, column=2)
        await wait_for(pilot, lambda: app.cursor == (1, 2), what="cursor")
        await pilot.press("u")
        assert len(app.pending_instructions) == 1
        before = app.session.status_counts(0)
        await pilot.press("s")
        await wait_for(pilot, lambda: app.preview is not None, what="preview")
        await pilot.press("n")  # discard
        assert app.preview is None and app.pending is None
        # Draft kept, live run untouched.
        assert len(app.pending_instructions) == 1
        assert app.session.status_counts(0) == before


# ===========================================================================
# Discoverability: spec'd status line + help overlay (design §B.1)
# ===========================================================================

def logline(app) -> str:
    """The bottom status line's widget content (what the user actually sees)."""
    return str(app.query_one("#logtext", Static).content)


async def test_status_line_shows_state_and_hint(app):
    """The bottom line carries the spec state facts + keymap hint (§B.1)."""
    async with app.run_test(size=(200, 35)) as pilot:
        await _loaded(pilot, app)
        line = logline(app)
        assert "draft r1" in line
        assert "preview —" in line
        assert "acc —" in line
        assert "?=help" in line
        # the widget content is the composed string the app reports
        assert line == app.status_text


async def test_status_line_marks_bump_revision_and_edits(app):
    """A draft mark advances the revision and the pending edit count."""
    async with app.run_test(size=(200, 35)) as pilot:
        await _loaded(pilot, app)
        g = grid(app)
        g.move_cursor(row=1, column=2)
        await wait_for(pilot, lambda: app.cursor == (1, 2), what="cursor")
        await pilot.press("u")
        assert app.draft_revision == 2
        line = logline(app)
        assert "draft r2" in line
        assert "1 edit(s)" in line
        assert line == app.status_text


async def test_status_line_preview_fresh_and_pending_hint(app):
    """A live preview reads fresh; the hint switches to y/n while pending."""
    async with app.run_test(size=(200, 35)) as pilot:
        await _loaded(pilot, app)
        await pilot.press("s")
        await wait_for(pilot, lambda: app.preview is not None, what="preview")
        assert app.preview_freshness == "fresh"
        line = logline(app)
        assert "preview fresh" in line
        assert "y=accept" in line and "n=cancel" in line


async def test_status_line_accepted_revision_after_confirm(app):
    """Accepting records the accepted revision and clears the preview."""
    async with app.run_test(size=(200, 35)) as pilot:
        await _loaded(pilot, app)
        await pilot.press("s")
        await wait_for(pilot, lambda: app.preview is not None, what="preview")
        await pilot.press("y")  # accept
        assert app.preview is None and app.pending is None
        assert app.accepted_revision == app.draft_revision
        line = logline(app)
        assert "preview —" in line
        assert f"acc r{app.draft_revision}" in line


async def test_help_overlay_opens_and_closes(app):
    """? opens the help overlay; esc closes it. No engine involvement."""
    async with app.run_test(size=(200, 40)) as pilot:
        await _loaded(pilot, app)
        await pilot.press("?")
        await wait_for(pilot, lambda: isinstance(app.screen, _HelpScreen),
                       what="help overlay")
        body = str(app.screen.query_one("#help", Static).content)
        assert "how it works" in body
        assert "s = suppress" in body
        assert "safe" in body and "unsafe" in body
        await pilot.press("escape")
        await wait_for(pilot, lambda: not isinstance(app.screen, _HelpScreen),
                       what="help closed")


# ===========================================================================
# No-arg launch: file browser (design §B.7)
# ===========================================================================

@pytest.fixture
def app_none() -> TauArgusApp:
    return TauArgusApp(None)


def test_arb_directory_tree_filters_to_arb_and_dirs(tmp_path):
    """Only subdirectories and .arb files are listed/openable (no others)."""
    (tmp_path / "good.arb").write_text("x")
    (tmp_path / "notes.txt").write_text("x")
    (tmp_path / "sub").mkdir()
    (tmp_path / ".hidden.arb").write_text("x")
    tree = _ArbDirectoryTree(tmp_path)
    shown = {p.name for p in tree.filter_paths(list(tmp_path.iterdir()))}
    assert "good.arb" in shown
    assert "sub" in shown
    assert "notes.txt" not in shown
    assert ".hidden.arb" not in shown


async def test_noarg_shows_filebrowser(app_none):
    """Running with no batch shows the file browser (not an empty app)."""
    async with app_none.run_test(size=(100, 35)) as pilot:
        await wait_for(pilot, lambda: isinstance(app_none.screen, _FileBrowser),
                       what="file browser")
        assert app_none.session is None  # nothing loaded yet
        assert app_none.screen.query_one("#fbtree", DirectoryTree) is not None


async def test_filebrowser_open_arb_loads(app_none):
    """Picking a .arb (the browser's callback) loads it, same path as arg mode."""
    async with app_none.run_test(size=(100, 35)) as pilot:
        await wait_for(pilot, lambda: isinstance(app_none.screen, _FileBrowser),
                       what="file browser")
        app_none._on_arb_chosen(ARB)  # what the browser does on Enter over a .arb
        await wait_for(pilot, lambda: app_none.session is not None,
                       what="load after pick")
        assert app_none.session.n_tables == 2


async def test_filebrowser_handler_opens_arb_only(app_none):
    """The tree's file-selected handler routes .arb to the load callback, and
    ignores anything else (only files that make sense to open are openable)."""
    async with app_none.run_test(size=(100, 35)) as pilot:
        await wait_for(pilot, lambda: isinstance(app_none.screen, _FileBrowser),
                       what="file browser")
        fb = app_none.screen
        chosen = []
        fb.app._on_arb_chosen = lambda p: chosen.append(p)
        fb.dismiss = lambda *a, **k: None  # don't actually pop in this test

        class Event:
            pass
        e = Event(); e.path = ARB
        fb.on_directory_tree_file_selected(e)
        assert chosen == [ARB]                      # .arb opens

        e2 = Event(); e2.path = ARB.with_suffix(".txt")
        fb.on_directory_tree_file_selected(e2)
        assert chosen == [ARB]                      # non-.arb ignored


# ===========================================================================
# Draft edit history — undo/redo (design §B.4 / §B.5)
# ===========================================================================
async def test_undo_reverses_mark(app):
    """Undo removes the last draft mark; the revision advances (spec: a
    revert is still a semantic edit)."""
    async with app.run_test(size=(120, 35)) as pilot:
        await _loaded(pilot, app)
        g = grid(app)
        g.move_cursor(row=1, column=2)
        await wait_for(pilot, lambda: app.cursor == (1, 2), what="cursor")
        rev0 = app.draft_revision
        await pilot.press("u")
        assert len(app.pending_instructions) == 1
        assert app.can_undo and not app.can_redo
        await pilot.press("ctrl+z")                 # undo
        assert len(app.pending_instructions) == 0   # the mark is gone
        assert app.can_redo and not app.can_undo
        assert app.draft_revision == rev0 + 2       # mark + undo


async def test_redo_reapplies_mark(app):
    async with app.run_test(size=(120, 35)) as pilot:
        await _loaded(pilot, app)
        g = grid(app)
        g.move_cursor(row=1, column=2)
        await wait_for(pilot, lambda: app.cursor == (1, 2), what="cursor")
        await pilot.press("u")
        await pilot.press("ctrl+z")
        assert len(app.pending_instructions) == 0
        await pilot.press("ctrl+y")                 # redo
        assert len(app.pending_instructions) == 1
        assert app.pending_instructions[0].kind == "U"
        assert app.can_undo and not app.can_redo


async def test_undo_walks_back_replacements(app):
    """A mark then a kind-replacement: undo steps back to the prior kind,
    then to unmarked (before/after are captured per edit)."""
    async with app.run_test(size=(120, 35)) as pilot:
        await _loaded(pilot, app)
        g = grid(app)
        g.move_cursor(row=1, column=2)
        await wait_for(pilot, lambda: app.cursor == (1, 2), what="cursor")
        await pilot.press("u")                       # mark U
        await pilot.press("p")                       # replace with P
        assert app.pending_instructions[0].kind == "P"
        await pilot.press("ctrl+z")                  # undo replacement -> U
        assert len(app.pending_instructions) == 1
        assert app.pending_instructions[0].kind == "U"
        await pilot.press("ctrl+z")                  # undo original mark -> cleared
        assert len(app.pending_instructions) == 0


async def test_new_mark_clears_redo(app):
    """A fresh edit makes the redo branch stale (standard undo/redo)."""
    async with app.run_test(size=(120, 35)) as pilot:
        await _loaded(pilot, app)
        g = grid(app)
        g.move_cursor(row=1, column=2)
        await wait_for(pilot, lambda: app.cursor == (1, 2), what="cursor")
        await pilot.press("u")
        await pilot.press("ctrl+z")
        assert app.can_redo
        await pilot.press("p")                       # a new edit
        assert not app.can_redo                      # redo branch cleared


async def test_undo_reset_after_accept(app):
    """Accept commits the draft, so the edit history is reset: a subsequent
    undo cannot reach back into the just-accepted marks."""
    async with app.run_test(size=(120, 35)) as pilot:
        await _loaded(pilot, app)
        g = grid(app)
        g.move_cursor(row=1, column=2)
        await wait_for(pilot, lambda: app.cursor == (1, 2), what="cursor")
        await pilot.press("u")
        assert app.can_undo
        await pilot.press("s")                        # stage OPT preview
        await wait_for(pilot, lambda: app.preview is not None, what="preview")
        await pilot.press("y")                        # accept
        await wait_for(pilot, lambda: app.pending is None, what="confirmed")
        assert app.can_undo is False                  # history reset
        await pilot.press("ctrl+z")                   # undo: nothing to do
        assert len(app.pending_instructions) == 0


# ===========================================================================
# Audit ownership — one result, one revision (design §B.5)
# ===========================================================================
async def test_audit_not_carried_into_accepted_result(app):
    """Audit belongs to the result it was computed on (design §B.5): the
    accepted result's audit may stay available while editing a draft, but
    accepting a *new* result must not carry the old result's audit into it.
    The new result has no audit until it is audited itself."""
    async with app.run_test(size=(120, 35)) as pilot:
        await _loaded(pilot, app)
        await pilot.press("a")                         # audit table 1
        await wait_for(pilot, lambda: len(app.session.audit_rows(0)) > 0,
                       what="audit")
        # Preview + accept a new result (OPT suppress on table 1).
        await pilot.press("s")
        await wait_for(pilot, lambda: app.preview is not None, what="preview")
        await pilot.press("y")                         # accept
        await wait_for(pilot, lambda: app.pending is None, what="confirmed")
        # The new (accepted) result has no audit yet — the old one didn't leak.
        assert app.session.audit_rows(0) == []
