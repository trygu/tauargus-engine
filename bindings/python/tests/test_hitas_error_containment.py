"""hitas error codes must cross the binding as return values.

The legacy hitas port throws raw ``int`` error codes from its file
operations (OpenFile throws 5000/5001, Amyio.cpp). pybind11 can only
translate ``std::exception``; an ``int`` escaping across the module
boundary is undefined behavior. ``FullJJ`` and ``AHiTaS`` call
``CheckStart`` before any internal try block, so a log directory that
cannot be written to triggers the escape before any file is opened.
"""


def _load():
    import _tauargus

    return _tauargus


def test_full_jj_unwritable_out_dir_returns_file_error_code(tmp_path):
    m = _load()
    h = m.HiTaSCtrl()
    rc = h.full_jj(
        in_file_jj=str(tmp_path / "does-not-exist.jj"),
        out_file=str(tmp_path / "out.jj"),
        max_time=0,
        ilm_file="",
        out_dir="/nonexistent-tauargus-outdir-xyz/",
        solver="SCIP",
    )
    assert rc in (5000, 5001), f"expected a hitas file error code, got {rc}"


def test_full_jj_unsatisfiable_allocation_returns_memory_error(tmp_path):
    # A negative variable count makes every header malloc fail
    # (size wraps past the address space), so FullJJ must report
    # HITAS_NOTENOUGHMEMORY instead of dereferencing NULL.
    import os

    m = _load()
    jj = tmp_path / "bad.jj"
    jj.write_text("0\n-1\n")
    outdir = tmp_path / "out"
    outdir.mkdir()
    h = m.HiTaSCtrl()
    rc = h.full_jj(
        in_file_jj=str(jj),
        out_file=str(outdir / "out.jj"),
        max_time=0,
        ilm_file="",
        out_dir=str(outdir) + os.sep,
        solver="SCIP",
    )
    assert rc == 5002, f"expected HITAS_NOTENOUGHMEMORY (5002), got {rc}"


def test_a_hitas_unwritable_out_dir_returns_file_error_code(tmp_path):
    m = _load()
    h = m.HiTaSCtrl()
    rc = h.a_hitas(
        pars_file=str(tmp_path / "does-not-exist.pars"),
        files_file=str(tmp_path / "does-not-exist.files"),
        max_time=0,
        ilm_file="",
        tau_out_dir="/nonexistent-tauargus-outdir-xyz/",
        solver="SCIP",
    )
    assert rc in (5000, 5001), f"expected a hitas file error code, got {rc}"
