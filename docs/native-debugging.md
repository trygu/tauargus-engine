# Native heap/teardown crash debugging playbook

How to diagnose the class of non-deterministic segfaults that appear in the
native C/C++ stack (csp / hitas / core) but only ~40% of the time and only in
the *real* interpreter run. Written from the 2026-10-06 CSP/HiGHS teardown
segfault session; the **method** is the reusable part.

## Symptom that points to heap corruption

- A crash whose **faulting frame changes between runs** (one run dies in
  `Highs_destroy`/`HighsOptions::~`, the next in `operator new` inside core's
  `FillTables`/`AddTableCells`). One corruption, many crash sites.
- Address that looks like a *double* reinterpreted as a pointer, e.g.
  `0x3ff0000000000008` = double `1.0` + member offset.
- Returns from the interpreter are **133 (SIGTRAP)**, **134 (SIGABRT)**,
  **138/139 (SIGBUS/SIGSEGV)** — not a clean Python exception.
- A fresh `TauArgus()` object crashes *less* than the **second** call in the
  same process (2x-repro crashes ~12x more often than 1x) → process-lifetime
  global state is leaking between calls.

## The one tool that actually works here: macOS crash reports

`lldb` does **not** reproduce it (Heisenbug: changing timing hides the crash).
macOS writes a full native backtrace to a `.ips` file on every fatal signal —
use those instead of the debugger.

```sh
# trigger a batch of crashes
for i in $(seq 1 40); do uv run python python/repro_seg.py OPT 2 >/dev/null 2>&1; done
# newest report + parse its faulting thread
F=$(ls -t ~/Library/Logs/DiagnosticReports/Python-*.ips | head -1)
python3 - "$F" <<'PY'
import json,sys
d=json.loads(open(sys.argv[1]).read().split('\n',1)[1])
print(d.get('exception',{}).get('subtype'))
ft=d['faultingThread']; imgs=d.get('usedImages',[])
for f in d['threads'][ft]['frames'][:16]:
    print(f"  {imgs[f['imageIndex']]['name']} +{f['imageOffset']} {f.get('symbol','')}")
PY
```

The `.ips` backtrace (with `libtauargus_*.dylib` frames) is the ground truth.
Collect **several** reports — different crash sites reveal the shared root
cause. A frame like `libsystem_malloc … freelist_outlined` means **heap
corruption** (freelist clobbered by an earlier OOB write), not a null deref.

## ASan (AddressSanitizer) — what works and what doesn't

ASan flags the *first* OOB write, which is exactly what you want — **but** the
extension is a `dlopen`'d `.so` into an already-running Python process, and
ASan's runtime initializes too late to install its alloc interceptors
(`ERROR: Interceptors are not working … loaded too late (dlopen)`).

What does **not** work:

- ASan-instrument the `.so` and just run it → interceptor warning + abort 134.
- `DYLD_INSERT_LIBRARIES=libclang_rt.asan…` on an ASan `.so` → same.

What **does** work (use this):

1. Build a **normal** (non-ASan) extension.
2. Preload the ASan runtime into the *interpreter* at process start, so it is
   active before Python's first malloc:

   ```sh
   ASR=/Library/Developer/CommandLineTools/usr/lib/clang/21/lib/darwin/libclang_rt.asan_osx_dynamic.dylib
   ASAN_OPTIONS=detect_leaks=0 uv run env -u DYLD_LIBRARY_PATH \
     DYLD_INSERT_LIBRARIES="$ASR" python repro_seg.py OPT 2
   ```

   (Set `DYLD_INSERT_LIBRARIES` on the `python` invocation, and be sure a
   stale `DYLD_INSERT_LIBRARIES`/`DYLD_LIBRARY_PATH`/`ASAN_OPTIONS` is not left
   in the shell — a leftover one silently turns every run into an ASan abort.)

Caveat learned the hard way: with a genuinely **layout-dependent** corruption
ASan may change the heap layout enough that the OOB write stops happening →
it runs clean for 60+ iterations while the un-instrumented build still crashes.
If ASan stays silent, it is a layout/timing bug — fall back to the crash-report
backtraces + manual bounds review, not the sanitizer.

## Pure-solver mimic (rules out / confirms the solver API)

When a crash is inside a HiGHS call, write a ~100-line C program that links
`-lhighs` and replays the exact API sequence (passLp → run → addCols/addRows →
run → deleteColsByMask/deleteRowsByMask → destroy), 300–500 iterations, with
and without `presolve=off`.

```sh
clang -O1 -g mimic.c -o mimic -L$(brew --prefix)/lib -lhighs -Wl,-rpath,$(brew --prefix)/lib
./mimic 500 0   # presolve on
./mimic 500 1   # presolve off
```

Note: the brew HiGHS install does **not** ship `lp_data/*.h` internal headers,
so `#include "highs/interfaces/highs_c_api.h"` fails — `extern`-declare the
small C API subset you need instead (see `Highs_addRows`/`addCols` signature:
`starts` is length `[num_new_row]`/`[num_new_col]`, **not** `+1`).
If the mimic never crashes, the bug is CSP-specific state, not the HiGHS API.

## Key architectural facts (so you don't re-derive them)

- The CSP keeps the LP in a **process-lifetime global** `JJLPptr lp`
  (`native/csp/src/cspsolve.c:75`). Each Python `TauArgus()` is a fresh object,
  but `lp` (and `Nlp` in `Cspnet.c`/`cspheur.c`) survives across calls in the
  same process. `load_lp()` is only ever called from `cspbranc.c:203`;
  `unload_lp()` at `Cspmain.c:466/541/554`.
- `JJloadprob`/`JJfreeprob` (Jjsolver.c:80/148) map 1:1 to
  `Highs_create`/`Highs_destroy`. A double-free or OOB write anywhere in the
  add/delete/run loop lands on the `Highs` heap and detonates at
  `Highs_destroy`.
- `ASSERT(...)` in `native/core` is a **no-op in release** (see `TauArgus.cpp:3805`
  guarding `cellindex < t.nCell`). An OOB cellindex silently writes past the
  `CellPtr` vector → heap corruption. `CellPtr` is `resize(nCell+1)`
  (Table.cpp:424).

## Build / rebuild quick refs

- Superbuild: `cmake -S native -B native/build -DHighs_DIR=$(brew --prefix)/lib/cmake/Highs && cmake --build native/build -j8`
- Copy fresh dylibs into the package before testing:
  `cp native/build/lib/libtauargus_{csp,hitas,rounder}.dylib python/src/tauargus/`
- Rebuild the extension **in place** (so `import` picks it up): `uv build --wheel`
  builds isolated; for the in-place `.so` run the extension CMake directly.
  After any ASan experiment, rebuild clean and confirm
  `otool -L python/src/tauargus/_tauargus.cpython-*.so | grep -i asan` is empty.
- In-process repro: see the recipe in the "Status (FIXED)" method, step 3
  (fresh `run_batch` per iteration, one `suppress` per iter).

## Status (2026-10-07) — FIXED (root cause: legacy column-0 RHS sentinel)

The CSP/HiGHS teardown segfault is **fixed**. Root cause was **not** a HiGHS
bug and not a `Highs_destroy` lifecycle problem — it was a **corrupted LP
matrix** handed to HiGHS, which detonated in the dual-simplex pivot
(`HighsSparseMatrix::update`).

**The bug:** `add_row()` in `native/csp/src/cspsolve.c` appended a legacy
sentinel entry `rmatind[l]=0; rmatval[l]=*rhs` to *every* cut row. Under the
old CPLEX/XPRESS back-ends the row RHS was read from that column-0 coefficient
(`matind=0`). The HiGHS port passes the RHS separately (via the row lower/upper
bounds in `JJaddrows`), so the sentinel was a redundant **spurious coefficient
on the dummy column 0** leaking into the matrix. The dumped MPS showed it
directly: `c0 r1 1` / `c0 r2 1` (the cut RHS values appearing as real entries).
Removing the sentinel (the `*rhs` is already the effective RHS after the
`FIX_UB` adjustment) makes the matrix structurally correct and the crash is
gone.

**The method that pinned it** (the reusable part — use this for the next one):

1. **Build HiGHS itself with ASan** (this was the missing piece). The brew
   HiGHS is uninstrumented, so ASan only saw *our* code and the corruption
   "disappeared" (it was really inside HiGHS, triggered by bad input). Cloning
   HiGHS, building with `-fsanitize=address -O1 -g`, and pointing the CSP
   ASan superbuild at `Highs_DIR=/tmp/highs-asan/install/lib/cmake/Highs`
   made the fault reportable **inside HiGHS at the fault site**:
   `heap-buffer-overflow READ ... in HighsSparseMatrix::update` during
   `HEkkDual::iterate` → `JJdualopt` (cspsolve.c `solve_lp`), **deterministic at
   iter 0** of the `FullJJ` harness (previously "iter 12, non-deterministic").
    Build refs (write the harness below to `/tmp/asan_harness.cpp`):

    ```sh
    # 1) HiGHS with ASan (clone https://github.com/ERGO-Code/HiGHS, pin 1.15.x)
    cmake -S /tmp/highs -B /tmp/highs/build -DCMAKE_BUILD_TYPE=RelWithDebInfo \
      -DCMAKE_C_FLAGS="-fsanitize=address -fno-omit-frame-pointer -O1 -g" \
      -DCMAKE_CXX_FLAGS="-fsanitize=address -fno-omit-frame-pointer -O1 -g"
    cmake --build /tmp/highs/build -j8 && cmake --install /tmp/highs/build --prefix /tmp/highs/install
    # 2) CSP superbuild against the instrumented HiGHS
    cmake -S native -B native/build-asan -DHighs_DIR=/tmp/highs/install/lib/cmake/Highs \
      -DCMAKE_C_FLAGS="-fsanitize=address -fno-omit-frame-pointer -fno-stack-protector -O1 -g" \
      -DCMAKE_CXX_FLAGS="-fsanitize=address -fno-omit-frame-pointer -fno-stack-protector -O1 -g"
    cmake --build native/build-asan -j8
    # 3) standalone harness (real executable => ASan interceptors work)
    clang++ -O1 -g -fno-stack-protector /tmp/asan_harness.cpp -o /tmp/asan_harness \
      -I native/hitas/include native/build-asan/lib/libtauargus_hitas.dylib \
      -Wl,-rpath,native/build-asan/lib -Wl,-rpath,/tmp/highs/install/lib
    ASAN_OPTIONS=quarantine_size=0:detect_leaks=0 /tmp/asan_harness /tmp/JJ.IN 25
    ```

    The harness (a minimal driver that loops `FullJJ` so the CSP process-lifetime
    statics `lp`/`Nlp` persist and stress the same path as the real batch):

    ```cpp
    // /tmp/asan_harness.cpp — replays HiTaSCtrl::FullJJ N times in one process
    #include "HiTaSCtrl.h"
    #include <cstdio>
    #include <cstring>
    struct NullListener : IProgressListener {
        void UpdateLB(int) override {} void UpdateUB(int) override {}
        void UpdateGroups(int) override {} void UpdateTables(int) override {}
        void UpdateDiscrepancy(double) override {} void UpdateTime(int) override {}
        void UpdateNSuppressed(int) override {}
    };
    struct NullCallback : ICallback { int SetStopTime() override { return 0; } };
    int main(int argc, char** argv) {
        const char* jjin = (argc > 1) ? argv[1] : "/tmp/JJ.IN";
        int iters = (argc > 2) ? atoi(argv[2]) : 2;
        if (iters < 2) iters = 2;
        for (int i = 0; i < iters; ++i) {
            fprintf(stderr, "iter %d: running FullJJ...\n", i); fflush(stderr);
            HiTaSCtrl h;
            h.SetProgressListener(new NullListener());
            h.SetCallback(new NullCallback());
            long r;
            try { r = h.FullJJ(jjin, "/tmp/JJ.OUT", 0, "", "/tmp/", "SCIP"); }
            catch (...) { fprintf(stderr, "iter %d: THREW\n", i); fflush(stderr); continue; }
            fprintf(stderr, "iter %d: returned %ld\n", i, r); fflush(stderr);
        }
        fprintf(stderr, "ALL OK\n"); return 0;
    }
    ```

    `/tmp/JJ.IN` (the `.jj` model) is regenerated any time from
    `run_batch(data/TestRecode.arb).suppress(OPT)` via `write_jj_format`.
2. **Dump the LP to MPS at the crash, then replay it standalone.** An env-gated
   `JJmpswrite(lp, "/tmp/csp_crash.mps")` on the first `solve_lp` gave the exact
   matrix. Reading the MPS is what exposed `c0 Obj inf` + `c0 r1/r2` entries.
   Replaying the same MPS with the standalone HiGHS binary solved clean, which
   told us the *data* was fine and the fault was in how the matrix was
   *constructed* (the sentinel) — not a HiGHS algorithmic bug.
3. **In-process Python repro** (for the release build, to confirm a crash is
   gone / has returned). Each iter makes a fresh engine object so the CSP
   process-lifetime statics (`lp`, `Nlp`) persist and stress the same path the
   real batch does:

   ```python
   # repro: run N in-process suppressions of one kind on the sample data
   import sys
   from tauargus.engine import run_batch
   from tauargus.batch import Suppress
   which = sys.argv[1] if len(sys.argv) > 1 else "OPT"   # OPT | MOD | RND
   n = int(sys.argv[2]) if len(sys.argv) > 2 else 9
   from pathlib import Path
   DATA = Path(__file__).resolve().parent.parent / "data" / "TestRecode.arb"
   for i in range(n):
       eng = run_batch(DATA)
       eng.suppress(Suppress(kind=which, tab_no=1))   # RND also needs a base set
       print(f"iter {i}: OK", flush=True)
   print("ALL OK", flush=True)
   ```

   Pre-fix this crashed ~40% (RC 133/139); post-fix 9/9 clean. RND must set a
   rounding base (e.g. `eng.set_round_base(10**7)`) or it raises a clean
   `BatchError`, not a crash.

**Verification:** ASan harness 60/60 `FullJJ` iters clean (RC 0, "ALL OK");
normal build: 67/67 `uv run pytest` green; `repro_seg.py OPT` × 9 in-process
suppressions (the old ~40% crash repro) all clean.

- Kept (genuine latent fix): `add_rows` matrix buffers sized `rcnt*(mac+1)`.
- The `put_base`/`Highs_setBasis` path (cspbranc.c branch-resume) was *not* the
  crash (that path isn't in the in-loop `solve_lp`), and its `stat`→basis-code
  mapping still uses raw CSP values; worth a follow-up if branch-resume ever
  misbehaves, but out of scope for this fix.
