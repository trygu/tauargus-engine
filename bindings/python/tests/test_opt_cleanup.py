"""A rejected JJ input must leave no native file handles open."""

import os

from pytauargus.engine import Engine


def file_is_open(path):
    target = path.stat()
    for fd in range(256):
        try:
            candidate = os.fstat(fd)
        except OSError:
            continue
        if (candidate.st_dev, candidate.st_ino) == (target.st_dev, target.st_ino):
            return True
    return False


def test_full_jj_rejection_closes_input_and_output(tmp_path):
    engine = Engine()
    source = tmp_path / "JJ.IN"
    output = tmp_path / "JJ.OUT"
    # A valid JJ layout with a secondary suppression, rejected by the
    # legacy optimizer with 5008 before optimization starts.
    source.write_text("0\n2\n0 10 1 m 0 100 1 1 0\n"
                      "1 10 1 s 0 100 0 0 0\n1\n0 2 : 0 (1) 1 (-1)\n")
    result = engine._hitas.full_jj(in_file_jj=str(source), out_file=str(output), max_time=1)
    assert result == 5008
    for path in (source, output):
        if os.name == "posix":
            assert not file_is_open(path), f"FullJJ left {path.name} open on rejection"
        # Windows refuses removal if either stream still owns a handle.
        path.unlink()
