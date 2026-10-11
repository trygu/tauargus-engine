# pytauargus-tui

A lightweight **Textual** terminal UI for [Tau-Argus](https://github.com/trygu/tauargus-engine) —
a thin interactive view over the `pytauargus` engine.

> Design: [`docs/ui-design.md`](../../docs/ui-design.md), Option B. The TUI is a
> presentation layer only — every action is a call the headless CLI already
> makes. It re-implements no engine behaviour and never touches the native
> bindings directly.

## Install

```bash
pip install pytauargus-tui
```

This pulls `pytauargus` (the native engine + CLI) and `textual`.

## Run

```bash
tauargus-tui path/to/batch.arb
```

Load a `.arb` batch, browse the computed tables, inspect cells, preview
suppression/rounding, audit feasibility intervals, and save outputs.

## Layout

- **Left** — table navigator (one row per `specify_table`) with its
  explanatory/response variables and active safety rules.
- **Center** — the computed table as a grid; each cell is coloured by its
  status category (S=green, U=red, P=cyan, M=yellow, E=dim).
- **Detail** (bottom) — the selected cell's value, full status name and,
  after an audit, its realised feasibility interval.
- **Log/status** (bottom) — the engine log stream and a keymap hint.

## Develop

```bash
cd bindings/tui
# 0.3.0 wheels on PyPI cover CPython 3.10-3.13 (no cp314 yet):
uv venv --python 3.13 .venv
uv pip install -p .venv "pytauargus==0.3.0" textual pytest pytest-asyncio
uv pip install -p .venv -e .
.venv/bin/python -m pytest
```
