"""Pure-Python view model over the ``pytauargus`` engine.

The TUI widgets never import the native bindings directly — they read from
this module only. Every engine call goes through the documented Python API
(``run_batch`` / ``Engine`` methods) exactly as the CLI does, so the TUI is a
thin presentation layer and re-implements no engine behaviour (design §2,
§B.2, §B.4).

One ``Session`` wraps one ``Engine`` (the design's "one Engine per open
session"). The grid caches per-table cell reads after compute and is
invalidated on any mutating action.
"""

from __future__ import annotations

import os
import tempfile
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional, Sequence, Tuple, Union

from pytauargus.engine import Engine, _status_symbol, run_batch
from pytauargus import cli as _cli

# Full status names (1-14) live in the CLI module (design §B.1 references them).
_STATUS_NAMES: Dict[int, str] = dict(_cli._STATUS_NAMES)

_CS_EMPTY = 14


# ===========================================================================
# Dataclasses (plain Python — safe for any widget layer)
# ===========================================================================
@dataclass(frozen=True)
class Cell:
    """One grid cell: the published value plus its cell-status code."""

    value: float
    status: int

    @property
    def symbol(self) -> str:
        """Category symbol: S/U/P/M/E (``_status_symbol`` contract)."""
        return _status_symbol(self.status)

    @property
    def status_name(self) -> str:
        return _STATUS_NAMES.get(self.status, "unknown")


@dataclass(frozen=True)
class TableMeta:
    """Navigator row for one specified table."""

    index: int
    exp_vars: Tuple[str, ...]
    resp_var: str
    n_cells: int
    rules: Tuple[str, ...] = ()


@dataclass
class TableGrid:
    """A computed table as a 2-D grid (rows x cols of :class:`Cell`).

    For a two-explanatory-var table, ``rows`` = first var's codes and
    ``cols`` = second var's codes. For a one-var table there is a single
    column (``cols == []``). For three or more vars the grid falls back to a
    flat single-column listing (see :meth:`Session.grid`).
    """

    tab: TableMeta
    row_var: str
    col_var: Optional[str]
    rows: List[str]
    cols: List[str]
    cells: List[List[Cell]]


# ===========================================================================
# Staged suppression (design §B.3)
# ===========================================================================
@dataclass(frozen=True)
class SuppressionOp:
    """One staged suppression, materialised as a batch ``<SUPPRESS>`` line.

    The batch grammar is the legacy source of truth (``batch.py``):
    ``OPT(n)``, ``MOD(n)``, ``RND(n,base)`` — table numbers are 1-based.
    """

    kind: str  # "OPT" | "MOD" | "RND"
    tab: int  # 1-based table number
    rnd_base: int = 0

    def arb_line(self) -> str:
        if self.kind == "RND":
            return f"<SUPPRESS> RND({self.tab},{self.rnd_base})"
        return f"<SUPPRESS> {self.kind}({self.tab})"


def arb_with_ops(arb_text: str, ops: Sequence[SuppressionOp]) -> str:
    """The batch text with one ``<SUPPRESS>`` line per op.

    Suppression is inserted before the first ``<WRITETABLE>`` (the legacy
    order: suppress, then write) or appended when the spec has no
    ``<WRITETABLE>``.
    """
    lines = arb_text.splitlines()
    insert_at = len(lines)
    for i, ln in enumerate(lines):
        if ln.lstrip().startswith("<WRITETABLE>"):
            insert_at = i
            break
    extra = [op.arb_line() for op in ops]
    return "\n".join(lines[:insert_at] + extra + lines[insert_at:]) + "\n"


def format_status_delta(before: Dict[int, int],
                        after: Dict[int, int]) -> str:
    """Per-status ``name before→after`` pairs, ascending status code.

    The delta the preview shows (design §B.3 step 3), e.g.
    ``safe 104→101  secondary_unsafe 0→3``.
    """
    codes = sorted(set(before) | set(after))
    return "  ".join(
        f"{_STATUS_NAMES.get(c, str(c))} {before.get(c, 0)}→{after.get(c, 0)}"
        for c in codes
    )


# ===========================================================================
# Safety-rule display
# ===========================================================================
def _rules_display(srs) -> Tuple[str, ...]:
    """Render a ``SafetyRuleSet`` as short human-readable rule strings.

    Mirrors the batch tokens (``NK(n,k)``, ``P(p,q,n)``) so the navigator can
    show the same rules the ``.arb`` declared.
    """
    out: List[str] = []
    for n, k in zip(srs.dom_n, srs.dom_k):
        out.append(f"NK({n},{k})")
    for p, q, n in zip(srs.pq_p, srs.pq_q, srs.pq_n):
        if q == 100 and p == 0 and n == 0:
            out.append("P(0,0,0)")
        else:
            out.append(f"P({p},{q},{n})")
    for f, m in zip(srs.min_freq, srs.freq_marge):
        out.append(f"FREQ({f},{m})")
    if srs.zero_rule:
        out.append(f"ZERO({srs.zero_range:g})")
    if srs.apply_weight:
        out.append("WGT")
    if srs.manual_perc:
        out.append(f"MAN({srs.manual_perc})")
    return tuple(out)


# ===========================================================================
# Session
# ===========================================================================
class Session:
    """One open Tau-Argus session: a view over a single computed ``Engine``."""

    def __init__(self, eng: Engine,
                 arb_path: Optional[Union[str, Path]] = None) -> None:
        self._eng = eng
        self._arb_path = Path(arb_path) if arb_path else None
        self._grid_cache: Dict[int, TableGrid] = {}
        self._audit_rows: Dict[int, List[dict]] = {}

    # -- construction --------------------------------------------------------
    @classmethod
    def from_arb(cls, arb_path: Union[str, Path]) -> "Session":
        """Run a ``.arb`` batch in a fresh engine and wrap it."""
        return cls(run_batch(Path(arb_path)), arb_path)

    @property
    def engine(self) -> Engine:
        return self._eng

    # -- navigator -----------------------------------------------------------
    @property
    def n_tables(self) -> int:
        return self._eng._n_tables

    def table(self, i: int) -> TableMeta:
        eng = self._eng
        if i < 0 or i >= len(eng._tables):
            raise IndexError(f"table {i} out of range")
        spec, srs = eng._tables[i]
        n, _ = eng._tau.get_total_table_size(i)
        return TableMeta(
            index=i,
            exp_vars=tuple(spec.exp_vars),
            resp_var=spec.resp_var,
            n_cells=n,
            rules=_rules_display(srs),
        )

    def tables(self) -> List[TableMeta]:
        return [self.table(i) for i in range(self.n_tables)]

    # -- grid ----------------------------------------------------------------
    def grid(self, i: int) -> TableGrid:
        """Return (and cache) the computed grid for table ``i``."""
        cached = self._grid_cache.get(i)
        if cached is not None:
            return cached
        grid = self._build_grid(i)
        self._grid_cache[i] = grid
        return grid

    def _codes_for(self, var_name: str) -> List[Tuple[int, str]]:
        """Active code index + display label for a categorical variable."""
        eng = self._eng
        vi = eng.metadata.index_of(var_name)
        var = eng.metadata.variables[vi]
        _n_codes, n_active = eng._tau.get_var_number_of_codes(vi)
        out: List[Tuple[int, str]] = []
        for ci in range(n_active):
            ok, _ct, cs, _miss, _level = eng._tau.get_var_code(vi, ci)
            if not ok or cs == "":
                cs = var.tot_code if var.tot_code else "Total"
            out.append((ci, cs))
        return out

    def _cell(self, i: int, dim: List[int]) -> Cell:
        eng = self._eng
        res = eng._tau.get_table_cell(i, dim, 0)
        if not res or len(res) < 11:
            return Cell(value=0.0, status=_CS_EMPTY)
        return Cell(value=float(res[1]), status=int(res[10]))

    def _build_grid(self, i: int) -> TableGrid:
        meta = self.table(i)
        exp = list(meta.exp_vars)
        dims_codes = [self._codes_for(name) for name in exp]

        if len(exp) >= 2:
            row_var, col_var = exp[0], exp[1]
            rows = [label for _ci, label in dims_codes[0]]
            cols = [label for _ci, label in dims_codes[1]]
            cells: List[List[Cell]] = []
            for r, (rci, _rl) in enumerate(dims_codes[0]):
                row_cells: List[Cell] = []
                for cci, _cl in dims_codes[1]:
                    row_cells.append(self._cell(i, [rci, cci]))
                cells.append(row_cells)
        else:
            # Single explanatory var: one column.
            row_var = exp[0] if exp else ""
            col_var = None
            rows = [label for _ci, label in dims_codes[0]] if exp else [""]
            cells = [
                [self._cell(i, [rci])] for rci, _label in dims_codes[0]
            ] if exp else [[self._cell(i, [])]]
        return TableGrid(
            tab=meta,
            row_var=row_var,
            col_var=col_var,
            rows=rows,
            cols=cols if col_var is not None else [],
            cells=cells,
        )

    # -- cache invalidation --------------------------------------------------
    def invalidate(self) -> None:
        """Drop cached grids after any mutation of the running tables."""
        self._grid_cache.clear()

    # -- per-status cell counts (preview delta, design §B.3) ------------------
    def status_counts(self, i: int) -> Dict[int, int]:
        """Count of cells per status code for table ``i`` (via the grid)."""
        counts: Dict[int, int] = {}
        for row in self.grid(i).cells:
            for cell in row:
                counts[cell.status] = counts.get(cell.status, 0) + 1
        return counts

    # -- throwaway preview (design §B.3) --------------------------------------
    def adopt_spec(self, arb_path: Union[str, Path]) -> None:
        """Re-bind this session to a spec file so later previews can re-run
        it. Called when a previewed session is adopted as the working
        session: the preview's own temp spec is gone, but the original
        ``.arb`` plus the app's confirmed ops re-materialize the same state
        (design §B.3 step 4)."""
        self._arb_path = Path(arb_path)

    def preview(self, ops: Sequence[SuppressionOp]) -> "Session":
        """Fresh, throwaway run of this session's ``.arb`` with ``ops``
        appended (or inserted before its ``<WRITETABLE>``).

        The engine is stateful with no in-place undo, so a "preview" is a
        fresh ``run_batch`` of the same spec plus the suppression — the same
        mechanism the CLI and notebooks use. The returned session is for
        inspection/diffing only; it is not meant to be re-previewed.
        """
        if self._arb_path is None or not self._arb_path.is_file():
            raise RuntimeError("this session has no .arb file to re-run")
        text = arb_with_ops(self._arb_path.read_text(), ops)
        # The temp arb must sit next to the original one: the batch resolves
        # data files relative to the arb's directory.
        fd, tmp = tempfile.mkstemp(prefix=".preview-", suffix=".arb",
                                   dir=str(self._arb_path.parent))
        try:
            with os.fdopen(fd, "w") as f:
                f.write(text)
            return type(self)(run_batch(tmp), tmp)
        finally:
            Path(tmp).unlink(missing_ok=True)

    # -- pass-through actions (mutate -> invalidate) -------------------------
    def suppress(self, cmd) -> None:
        self._eng.suppress(cmd)
        self.invalidate()

    def audit(self, i: int) -> List[dict]:
        rows = self._eng.audit(i)
        self._audit_rows[i] = rows
        self.invalidate()
        return rows

    def audit_rows(self, i: int) -> List[dict]:
        """Rows returned by the last audit of table ``i`` (empty if none)."""
        return self._audit_rows.get(i, [])

    def apply_apriori(self, cmd) -> Dict[str, int]:
        res = self._eng.apply_apriori(cmd)
        self.invalidate()
        return res

    def write_intermediate_table(self, i: int, path: str, **kw) -> None:
        self._eng.write_intermediate_table(i, path, **kw)
