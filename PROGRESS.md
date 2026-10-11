# Tau-Argus Rewrite — Progress

Branches: `master` (mainline) + `tui` (TUI). DataFrame work merged to
`master` in PR #5; **Release 0.3.0** published (tag `py-v0.3.0`).
Goal: HiGHS solvers, portable cloud-native build, headless Python CLI.

## Verified checkpoints (details in ARCHIVE.md)
- [x] Core: WRITETABLE type-5, apriori, MOD/OPT/RND, audit (Intervalle).
- [x] Task 4 headless CLI; rename to `pytauargus`; self-contained wheel +
  CI → GH Release + PyPI + GHCR. **Release 0.2.0**; example notebooks.
- [x] **High-level API — DataFrame `protect()`** (PR #5): DataFrame/dict ->
  native batch -> type-5 `TableResult`; optional pandas.
- [x] OPT/MOD time-limit regressions + audit docs (PR #3); `protect()`
  score-buffer overflow + import (PR #4); 219 tests + 37 executed cells.
- [x] **Release 0.3.0** (tag `py-v0.3.0`): cp310–cp313 wheels + GHCR image.
- [x] 2nd-OPT SIGABRT fixed (csp `3007826`): counters reset at loadprob
  entry + freeprob exit; re-OPT with secondary cells → 5008, no crash.
- [x] Legacy `ErrorStrings.txt` restored + embedded at build time (hitas
  `d3e5b91`); `error_string()` returns real messages.
- [x] Acknowledgements: Tau-Argus/native/HiGHS + wrapper authors/contacts;
  clean presentation + Peter-Paul aliases unified (`docs/acknowledgements`).

## Next (priority order)
1. **GHCR rename → `tauargus-engine`** — 0.2.1 verified. Delete old
   `trygu/tauargus` package.
2. **Top-level project rename** (repo/package naming) — decide + execute.
3. Task 1: document solver strategy (legacy roles → HiGHS); Dockerfile.
4. **ANSI-TUI** (`textual`, own `pytauargus-tui`) on `tui` branch.

## Watch items
- Ship the 2nd-OPT fix + ErrorStrings as **0.3.1** (in-tree since 0.3.0).
- OPT/MOD deadline expiry needs separate coverage; positive limits pass.
- `open_microdata` calls `clean_all` — safe only because tables finalize after.
- Parquet as the microdata dataframe backend (not started).
