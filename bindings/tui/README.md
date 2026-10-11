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

This pulls the matching version of `pytauargus` (the native engine + CLI)
and `textual`. The two packages share one version and release together under
`py-v<version>`; installing the engine alone does not install the TUI.
See [the shared release procedure](../../docs/tui-publishing.md).
The first TUI package will be available with the next Python release.

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
# From the repository root; build the in-tree engine, not an older PyPI wheel:
uv venv --python 3.13 bindings/tui/.venv
scripts/sync-venv.sh bindings/tui/.venv
uv sync --project bindings/tui --extra test
uv run --project bindings/tui pytest bindings/tui/tests -q
```
