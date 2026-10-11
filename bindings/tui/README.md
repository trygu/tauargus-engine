# pytauargus-tui

An interactive **terminal UI** for [Tau-Argus](https://github.com/trygu/tauargus-engine),
the statistical disclosure control engine. It is a thin view over the
`pytauargus` engine — every action is a call the headless CLI already makes —
and installing it gives you the `tauargus` CLI as well.

## Screenshots

![Loaded table — every cell coloured by its safety status](https://raw.githubusercontent.com/trygu/tauargus-engine/master/docs/tui-images/02-table0-unsafe.png)

![Suppression preview — inspect the throwaway result before accepting](https://raw.githubusercontent.com/trygu/tauargus-engine/master/docs/tui-images/04-preview.png)

![Accepted — the preview becomes the working session](https://raw.githubusercontent.com/trygu/tauargus-engine/master/docs/tui-images/05-accepted.png)

## What it does

- **Runs your `.arb` batch** — the full Tau-Argus pipeline (apriori safety
  rules, suppression, rounding, audit) with every computed table browsable.
  Start without a file and a `.arb` file browser opens.
- **Colours cells by status** — green safe · red unsafe (a sensitive value) ·
  cyan protected · yellow hidden by a suppression · dim empty. All 14 engine
  status codes are recognised and named.
- **Shows what any cell means** — value, status name, pending mark, and after
  an audit the realised feasibility interval, for the cell under the cursor.
- **Lets you mark cells before solving** — `u` require suppression, `p`
  protect (keep), `S` override safe. Marks are instant draft edits with
  toggle/replace and undo/redo; the solver never runs until you ask.
- **Previews suppression and rounding** — `s` (OPT, whole table) and `r`
  (RND) run on a *throwaway copy* of your batch: you inspect the previewed
  grid, then `y` accepts or `n` cancels. Your working table never changes
  behind your back, and a preview that is no longer current is flagged.
- **Audits** — realised feasibility intervals per cell (`a`).
- **Exports** — writes the accepted table as a legacy `INTERMEDIATE` `.tab`
  file (`o`).
- **Saves the workspace** — a versioned, fingerprinted JSON manifest of
  everything you did (accepted operations, cell marks) next to the `.arb`
  (`w`).

## What it can't do (yet)

- **Reopen a saved workspace** — the manifest is saved, but restoring a
  session from it is not implemented (design §B.7).
- **Mark total cells** — that needs the real total code, which the display
  labels do not preserve; the app blocks such marks with a message.
- **Choose the rounding base** — `r` always uses the engine's minimum base.
- **Work on several batches** — one `.arb` per session, and the batch spec
  itself is not editable from the UI.

## Install

```bash
pip install pytauargus-tui
# or, as an extra of the engine package:
pip install "pytauargus[tui]"
```

## Run

```bash
tauargus-tui                 # opens a .arb file browser
tauargus-tui path/to/batch.arb
```

**Full user guide** — every key, every status code, the whole workflow:
[`docs/tui.md`](https://github.com/trygu/tauargus-engine/blob/master/docs/tui.md).

## Develop (monorepo)

```bash
cd bindings/tui
uv sync --extra test
.venv/bin/python -m pytest
```
