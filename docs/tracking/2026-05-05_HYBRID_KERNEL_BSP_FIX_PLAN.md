# Fix Plan — Hybrid Kernel Callback BSP Violation

**Companion to**: `2026-05-05_HYBRID_KERNEL_CALLBACK_BSP_BUG.md` (root-cause).
**Date**: 2026-05-05 evening.
**Status**: **IMPLEMENTED** 2026-05-05 evening (same-day). Plan
landed as proposed (Fix A') with one addition: per user request,
silent fall-throughs were converted to hard-fail. The dirtied
buffer overflow now `@panic`s rather than degrading. Fuel
exhaustion now raises a Racket error rather than returning a
silent partial result.

## Goal

Make `[int-eq [int-mod 7 3] 0]` return `false` (and the 5 other
miscomputing chains in the bug report) without breaking any
currently-passing program. Recover correctness for any program that
chains a callback fire-fn into a native consumer.

## Non-goals

- **Don't** restructure the Racket-side fire-fn API (Fix C from the
  bug report). That alignment work belongs in a separate cleanup
  track once Phase 7 native migrations are decided.
- **Don't** migrate `int-mod` to a kernel native fire-fn. That's a
  workaround that masks the underlying bug for one case; the bug
  affects all callbacks.
- **Don't** change BSP semantics (snapshot reads, pending writes,
  round-by-round scheduling). Those are correct; only the
  callback-write scheduling path is broken.

## The fix in one sentence

Add a `firing` flag to the kernel that's true during the
worklist-firing loop. While it's true, `prologos_cell_write`
performs the write to the live cell (so the wrapper's read-back
returns the right value) but **defers subscriber scheduling** —
recording the dirtied cell in a small set. After the firing loop
completes, walk the dirtied set and schedule subscribers, then run
`merge_pending_writes()` and `swap_worklists()` as before.

This addresses **Fix A'** from the bug report (track dirtied cells
during firing, schedule post-merge). Smallest blast radius:
- One Zig file changed (~25 lines added).
- Zero Racket changes.
- All existing fire-fns continue to work.
- Performance neutral (one bool flag, one MAX_CELLS-sized index
  buffer, one extra loop after firing per round).

## Files to change

Single file: `runtime/prologos-runtime-hybrid.zig`.

The Racket side (`preduce-backend-hybrid.rkt`, `preduce.rkt`) is
unchanged.

## Code changes

### Change 1: add the flag and the dirtied-cell buffer

Near the existing `var pending_cid: [MAX_PROPS]u32 = undefined;` block (~line 381):

```zig
// =====================================================================
// BSP correction for callback fire-fns (2026-05-05).
//
// Callback wrappers (in preduce-backend-hybrid.rkt) call
// prologos_cell_write IMMEDIATELY from inside their fire-fn (via
// b-write -> backend.write-cell). Doing so during firing must NOT
// trigger immediate subscriber scheduling, because the subscriber
// may already be in the current worklist (in_worklist[pid] == 1)
// and schedule() early-returns on that — leading the subscriber to
// fire against an outdated snapshot in the same round and never
// re-fire in the next round (write_unchecked returns false on the
// matching pending write since the value already landed live).
//
// Fix: while `firing` is true, prologos_cell_write performs the
// store update normally but appends the cell-id to the dirtied
// buffer instead of scheduling subscribers. After the firing loop
// finishes (in run_to_quiescence), we walk the dirtied buffer and
// schedule subscribers for each cid — at this point all firing
// propagators have been processed, their in_worklist flags are
// cleared, and schedule() succeeds.
//
// See docs/tracking/2026-05-05_HYBRID_KERNEL_CALLBACK_BSP_BUG.md
// for the root-cause analysis.
// =====================================================================
var firing: bool = false;
var dirtied_cid: [MAX_CELLS]u32 = undefined;
var dirtied_len: u32 = 0;
```

Notes:
- `MAX_CELLS` is the existing constant for the cell store size. If
  it doesn't exist as a Zig const, mirror whatever upper bound the
  store uses.
- The buffer is indexed by an i, not by cid — multiple writes to the
  same cid append duplicates, but `schedule()`'s `in_worklist`
  dedup absorbs that. Keeps the implementation simple.

### Change 2: gate `prologos_cell_write`'s schedule call

Modify `prologos_cell_write` (~line 275):

```zig
export fn prologos_cell_write(id: u32, value: i64) void {
    if (store.write_unchecked(id, value)) {
        prof.writes_committed += 1;
        if (firing) {
            // Defer subscriber scheduling to post-firing-loop walk.
            if (dirtied_len < MAX_CELLS) {
                dirtied_cid[dirtied_len] = id;
                dirtied_len += 1;
            }
            // (If dirtied buffer full, fall through silently — the
            //  worst case is the subscriber doesn't re-fire, which
            //  is the pre-fix behavior. Should never happen in
            //  practice; MAX_CELLS is generous.)
        } else {
            var i: u32 = 0;
            while (i < store.num_subs(id)) : (i += 1) {
                schedule(store.sub_at(id, i));
            }
        }
    } else {
        prof.writes_dropped += 1;
    }
}
```

### Change 3: wrap the firing loop with the flag + post-firing schedule walk

Modify `prologos_run_to_quiescence` (~line 512):

```zig
export fn prologos_run_to_quiescence() void {
    ensure_init();
    const start_ns = profile.now_ns();
    swap_worklists();
    while (worklist_len > 0) {
        if (max_rounds != 0 and prof.rounds >= max_rounds) {
            prof.fuel_exhausted = 1;
            break;
        }
        prof.rounds += 1;
        store.take_snapshot();

        // Begin firing phase: prologos_cell_write() should defer
        // scheduling until after the loop completes.
        firing = true;
        var i: u32 = 0;
        while (i < worklist_len) : (i += 1) {
            const pid = worklist[i];
            in_worklist[pid] = 0;
            fire_against_snapshot(pid);
        }
        worklist_len = 0;
        firing = false;

        // Drain dirtied buffer: schedule subscribers for each cell
        // that was immediately written by a callback fire-fn during
        // this round.
        i = 0;
        while (i < dirtied_len) : (i += 1) {
            const cid = dirtied_cid[i];
            var j: u32 = 0;
            while (j < store.num_subs(cid)) : (j += 1) {
                schedule(store.sub_at(cid, j));
            }
        }
        dirtied_len = 0;

        merge_pending_writes();
        swap_worklists();
    }
    prof.run_ns += profile.now_ns() - start_ns;
}
```

### Change 4: reset state in `prologos_kernel_reset`

Modify `prologos_kernel_reset` (~line 624):

```zig
export fn prologos_kernel_reset() void {
    store = CellStore.init(0);
    num_props = 0;
    prop_in_arena_used = 0;
    worklist_len = 0;
    next_worklist_len = 0;
    pending_len = 0;
    firing = false;        // <-- new
    dirtied_len = 0;       // <-- new
    var i: u32 = 0;
    while (i < MAX_PROPS) : (i += 1) {
        in_worklist[i] = 0;
    }
    prof.reset();
    cb_prof.reset();
}
```

## Why this works (re-trace of `[int-eq [int-mod 7 3] 0]`)

Cell allocations: cid-7=7, cid-3=3, cid-mod-out=bot, cid-0=0,
cid-eq-out=bot. Initial `firing=false, dirtied_len=0`.

**Round 1**:
- `swap_worklists()`. worklist = [int-mod, int-eq].
- `take_snapshot()`. Snapshot of all cells captured.
- `firing = true`.
- Iter 0: pid = int-mod. `in_worklist[int-mod] = 0`. fire:
    - tag is callback. Wrapper invokes fire-fn.
    - fire-fn b-writes 1 to cid-mod-out → `prologos_cell_write(cid-mod-out, 1)`.
        - `store.write_unchecked` → true (was bot, now 1).
        - **`firing == true` → append cid-mod-out to dirtied. NO immediate schedule.**
    - Wrapper returns `prologos_cell_read(cid-mod-out)` = 1.
    - Kernel: `pending[0] = (cid-mod-out, 1)`.
- Iter 1: pid = int-eq. `in_worklist[int-eq] = 0`. fire:
    - native, reads snapshot: cid-mod-out=bot, cid-0=0. Returns true.
    - Kernel: `pending[1] = (cid-eq-out, true)`.
- `firing = false`.
- Drain dirtied: cid-mod-out → subscribers (int-eq).
  - **`schedule(int-eq)`: `in_worklist[int-eq] == 0` (cleared at iter 1 start). Adds int-eq to next_worklist.**
- `merge_pending_writes()`:
  - `prologos_cell_write(cid-mod-out, 1)` — already 1. `write_unchecked` returns false. No-op.
  - `prologos_cell_write(cid-eq-out, true)` — was bot. write_unchecked → true. firing == false → schedule subscribers (none).

**Round 2**:
- `swap_worklists()`. worklist = [int-eq].
- `take_snapshot()`. Snapshot cid-mod-out = 1, cid-eq-out = true, cid-0 = 0.
- `firing = true`.
- Iter 0: pid = int-eq. `in_worklist[int-eq] = 0`. fire:
    - native, reads snapshot: cid-mod-out=1, cid-0=0. Returns false.
    - Kernel: `pending[0] = (cid-eq-out, false)`.
- `firing = false`.
- Drain dirtied: empty.
- `merge_pending_writes()`:
  - `prologos_cell_write(cid-eq-out, false)` — was true. write_unchecked → true. Schedule subscribers (none).

**Round 3**: empty worklist. Quiescence.

**Final cid-eq-out = false. CORRECT.** ✓

## Test plan

### Phase 1 — Bug repro suite (must pass after fix)

Add `examples/hybrid-battery/R{1..6}-bsp-callback-chain.prologos`:

```
R1: def main : Bool := [int-eq [int-mod 7 3] 0]      ; expect false
R2: def main : Int  := [int+ [int-mod 7 3] 100]      ; expect 101
R3: def main : Int  := [int* [int-mod 7 3] 100]      ; expect 100
R4: def main : Bool := [int-lt [int-mod 7 3] 1]      ; expect false
R5: def x : Int := [int-mod 7 3]
    def main : Int := [int+ x 100]                   ; expect 101
R6: ; W14-style: prime-count via int-mod chain
    [count-primes 2 10] from W14                     ; expect 4
```

All 6 currently FAIL with the bug. All 6 must PASS after the fix.

### Phase 2 — Regression: re-run existing batteries

After the rebuild, re-run all of:
- `examples/preduce-lite/*.prologos` (7 programs)
- `examples/ocapn/ocapn-hybrid-{1..12}.prologos` (12)
- `examples/hybrid-battery/{A..L}*.prologos` (42 OK + 4 known-fail)
- `examples/hybrid-workloads/W{1..15}.prologos` (15 — including W14 which should now produce 4)

Acceptance: same OK count as before for each set, plus W14 now correct.

### Phase 3 — Profile sanity-check

Compare `--profile` output for L2-fib + W2-quicksort + a few others
before/after. Native-fire counts should be IDENTICAL (the fix
doesn't touch native paths). Callback-fire counts may go UP
slightly (some scheduled-but-skipped subscribers in the buggy
version now correctly re-fire and contribute to the count). Round
counts may go up by 1 or 2 for programs with callback→native
chains; rounds remain ≤ ~hundreds. Run-time will increase modestly
because previously-incorrect-but-fast paths now correctly do more
work.

This phase ALSO confirms the fix doesn't reintroduce a fuel
explosion: any program that completes in N rounds today should
complete in ≤ 2N rounds after.

### Phase 4 — Bench A/B vs HEAD

Before pushing the fix, run `tools/bench-ab.rkt --runs 10
benchmarks/comparative/` against HEAD~1 (pre-fix) to quantify
overhead. Expected impact: <5% regression on workloads that don't
use callbacks (the firing-flag check is a single bool compare in
prologos_cell_write).

## Risks

| risk | mitigation |
|---|---|
| `MAX_CELLS` exceeded by dirtied buffer | The current store size is bounded; the buffer is sized to that. Fall-through silently if exceeded — pre-fix behavior. Document and cap. |
| Bug in dirtied-buffer dedup | No dedup in the proposed code; rely on `schedule`'s `in_worklist` check. Verified safe. |
| Regression in non-callback programs | The flag is `firing`. For pure-native programs, no callback fires, no `prologos_cell_write` calls happen during firing (native fire-fns return values; pending writes happen post-firing when `firing == false`). Native paths see no behavior change. |
| Reentrancy: callback fire-fn calling kernel which calls another fire-fn | Hybrid mode's only re-entry is `prologos_cell_read` and `prologos_cell_write` from inside Racket — neither triggers another fire. Safe. |
| Subscriber scheduling order changes | The dirtied-set walk happens AFTER the firing loop but BEFORE merge_pending_writes. Native pending-writes' scheduling happens AFTER the dirtied walk (in merge_pending_writes). Order: dirtied → pending. Should be functionally equivalent. |

## Rollback

The fix is a single-file change. If a regression surfaces:
- `git revert` the fix commit.
- Rebuild the runtime: `cd runtime && zig build-lib -dynamic prologos-runtime-hybrid.zig -O ReleaseFast`.
- Rebuild the bundle: `tools/build-hybrid-binary.sh`.

W14 reverts to producing the wrong answer; everything else
(including all OCapN programs and the shape battery) reverts to its
pre-fix behavior.

## Open questions for the user before implementing

1. **MAX_CELLS sizing**: where is this constant defined? Should the
   dirtied buffer share its bound, or use a separate (smaller) bound
   tuned to typical round-write counts (~~50-200 dirtied cells per
   round across the workload battery)?

2. **Phase 3 profile diff acceptance**: how much round-count
   regression is acceptable? My guess: workloads currently completing
   in K rounds will complete in ≤ K+1 rounds (one extra round per
   callback→native chain). For W14 specifically, 216 rounds → maybe
   220-230. Acceptable?

3. **Test placement**: should the R1-R6 regression tests live in
   `examples/hybrid-battery/` (alongside the shape probes) or in a
   dedicated `tests/test-bsp-callback-chain.rkt` Racket test? The
   former is simpler; the latter integrates with `run-affected-tests`.
   Recommendation: both — the .prologos files for human-readable repro,
   plus a small Racket test that runs them through `process-file` and
   asserts the expected results.

4. **Forward scope**: do you want me to also commit-prepare the test
   files in this same fix commit, or defer them to a follow-up?
   Recommendation: bundle them — the fix is small, the tests prove
   it, the audit trail is cleaner.

## Files this fix will commit

| file | what | size |
|---|---|---|
| `runtime/prologos-runtime-hybrid.zig` | the 4 patches above | +25 lines |
| `runtime/libprologos-runtime-hybrid.so` | rebuilt binary | (artifact) |
| `dist/prologos-hybrid-bundle/lib/libprologos-runtime-hybrid.so` | rebuilt bundle copy | (artifact) |
| `examples/hybrid-battery/R1-bsp-eq-mod.prologos` | regression test 1 | ~3 lines |
| `examples/hybrid-battery/R2-bsp-add-mod.prologos` | test 2 | ~3 lines |
| `examples/hybrid-battery/R3-bsp-mul-mod.prologos` | test 3 | ~3 lines |
| `examples/hybrid-battery/R4-bsp-lt-mod.prologos` | test 4 | ~3 lines |
| `examples/hybrid-battery/R5-bsp-def-mod.prologos` | test 5 | ~5 lines |
| `examples/hybrid-workloads/W14-prime-count.prologos` | already exists; verify W14 now returns 4 | (no edit) |
| `docs/tracking/2026-05-05_HYBRID_KERNEL_CALLBACK_BSP_BUG.md` | mark as FIXED in commit | +1 status line |
| `docs/tracking/2026-05-05_HYBRID_PHASE7_MIGRATION_DATA.md` | mark int-mod migration back to "trivial cleanup" — the BSP fix subsumes the correctness need | +1 line |

## Estimated effort

- Implementation: 30 min (4 zig patches, well-localized).
- Build + smoke-test: 5 min.
- Phase 1 regression suite: 10 min (write 5 R*.prologos, run, verify).
- Phase 2 full regression: 5 min (re-run battery + workloads).
- Phase 3 profile diff: 10 min (capture before/after).
- Total: ~1 hour.
