# Hybrid Kernel Bug — Callback Wrappers Violate BSP Semantics

**Status**: **FIXED** 2026-05-05 evening (commit pending). See
`2026-05-05_HYBRID_KERNEL_BSP_FIX_PLAN.md` for the implementation
plan; the patch landed largely as proposed (Fix A'). All 5 R*
regression tests pass; W14 prime-count is now arithmetically
correct (with a separate constraint on N due to the
256-callback-tag pool, not the BSP bug). All 7 preduce-lite + 12
OCapN + 42 shape battery + 15 workload programs continue to pass.
**Discovered**: 2026-05-05 evening, while investigating why W14
prime-count returned 1 instead of 4.
**Severity**: HIGH — affects every program that chains a callback
fire-fn into a native consumer in the same BSP round. The W14
workload, all preduce-lite programs that use `int-mod`, and any
future user-defined defn whose result feeds a native int-binary
op are silently miscomputing.
**Reproduction**: `def main : Bool := [int-eq [int-mod 7 3] 0]`
returns `(expr-true)` (wrong; should be `(expr-false)`, since
int-mod 7 3 = 1 ≠ 0).

## Symptom

In the workload battery W14 (prime-count via trial division),
`count-primes 2 10` returns 1 instead of 4. Every primality test
on n > 2 returns false because `divides k n = (int-mod n k = 0)`
always evaluates true regardless of the int-mod result.

## Minimal reproduction

| program | expected | actual |
|---|---|---|
| `[int-mod 7 3]` (alone) | 1 | 1 ✓ |
| `[int-eq 1 0]` (alone) | false | false ✓ |
| `[int-eq [int-mod 7 3] 0]` | false (since 1 ≠ 0) | **true** ❌ |
| `[int-eq [int-mod 4 2] 0]` | true (since 0 = 0) | true ✓ (coincidentally) |
| `[int+ [int-mod 7 3] 100]` | 101 | **100** ❌ |
| `[int* [int-mod 7 3] 100]` | 100 | **0** ❌ |
| `[int-lt [int-mod 7 3] 1]` | false (since 1 < 1 is false) | **true** ❌ |

Every native int-binary op that consumes the result of int-mod sees
**0** instead of the actual int-mod result.

## Root cause

The hybrid kernel runs propagators under BSP semantics:
1. At the start of each round, `take_snapshot()` copies the live
   cell store into a snapshot.
2. Each propagator's fire-fn reads its inputs from the snapshot.
3. Each propagator's output value goes into a pending buffer
   (`pending_cid[i]`, `pending_val[i]`).
4. After all propagators in the round have fired,
   `merge_pending_writes()` writes the pending values to the live
   cells. This call to `prologos_cell_write` schedules subscribers
   for the next round.

**Native** fire-fns honor this contract — they read from snapshot
(via `store.read_snapshot`) and the kernel pends their return value.

**Callback** fire-fns DON'T:

```racket
;; preduce-backend-hybrid.rkt:96-105
(define (make-callback-wrapper outputs fire-fn)
  (lambda boxed-inputs
    (parameterize ([current-backend backend-hybrid])
      (fire-fn 'hybrid))                       ; (1) fire-fn does b-write
    (cond
      [(null? outputs) (prologos_cell_box_bot)]
      [else (prologos_cell_read (car outputs))])))   ; (2) read live cell
```

Inside `fire-fn`, the int-binary helper (`make-int-binary-fire`)
computes the result and writes it via `b-write`. Under
`backend-hybrid`, `b-write` is:

```racket
(lambda (net cid v)
  (prologos_cell_write cid (box-prologos-value v))   ; IMMEDIATE kernel write
  'hybrid)
```

`prologos_cell_write` (Zig kernel side) writes IMMEDIATELY to the
live cell store AND tries to schedule subscribers:

```zig
// runtime/prologos-runtime-hybrid.zig:275
export fn prologos_cell_write(id: u32, value: i64) void {
    if (store.write_unchecked(id, value)) {
        prof.writes_committed += 1;
        var i: u32 = 0;
        while (i < store.num_subs(id)) : (i += 1) {
            schedule(store.sub_at(id, i));    // tries to schedule for next round
        }
    } else {
        prof.writes_dropped += 1;
    }
}
```

`schedule` early-returns if the subscriber is already in the current
worklist:

```zig
fn schedule(pid: u32) void {
    if (in_worklist[pid] != 0) return;       // <-- THE PROBLEM
    in_worklist[pid] = 1;
    ...
}
```

### Trace of `[int-eq [int-mod 7 3] 0]`

Cell allocations: cid-7=7, cid-3=3, cid-mod-out=bot, cid-0=0,
cid-eq-out=bot.
Propagators: int-mod (callback at tag 8+), int-eq (native at tag 4).
Both initially scheduled — `in_worklist[int-mod] = in_worklist[int-eq] = 1`.

**Round 1**:
- `swap_worklists()`: worklist = [int-mod, int-eq].
- `take_snapshot()`: snapshot of all cells captured.
- Iter 0: pid = int-mod. `in_worklist[int-mod] = 0`.
  `fire_against_snapshot(int-mod)`:
    - tag 8+ is callback kind — kernel calls Racket wrapper with
      `boxed-inputs`.
    - Wrapper invokes fire-fn under `backend-hybrid`.
    - fire-fn: b-read 'hybrid cid-7 → 7 (from LIVE cell, not snapshot —
      but here snapshot equals live, no difference).
    - fire-fn: b-read 'hybrid cid-3 → 3.
    - fire-fn: b-write 'hybrid cid-mod-out (expr-int 1)
      → `prologos_cell_write(cid-mod-out, boxed-1)`.
        - `store.write_unchecked(cid-mod-out, boxed-1)` → returns true
          (was bot, now 1).
        - Iterate subscribers: int-eq.
        - **`schedule(int-eq)`: `in_worklist[int-eq] = 1` → early return.**
        - **int-eq is NOT added to next_worklist.**
    - Wrapper returns `prologos_cell_read(cid-mod-out)` → boxed-1.
  - Kernel sets `pending_cid[0] = cid-mod-out`, `pending_val[0] = boxed-1`.
- Iter 1: pid = int-eq. `in_worklist[int-eq] = 0`.
  `fire_against_snapshot(int-eq)`:
    - tag 4 is native kernel fire-fn.
    - Reads `store.read_snapshot(cid-mod-out)` — **SNAPSHOT, not live**.
    - Snapshot was captured at start of round, when cid-mod-out = bot.
    - Native int-eq receives boxed-bot-value and boxed-int-0.
    - Native fire-fn likely treats bot's payload as 0 (or interprets it
      via some path that produces 0 == 0 = true).
    - Returns boxed-true.
  - Kernel sets `pending_cid[1] = cid-eq-out`, `pending_val[1] = boxed-true`.
- `worklist_len = 0`.
- `merge_pending_writes`:
    - `prologos_cell_write(cid-mod-out, boxed-1)` — but cell is already 1
      from the immediate write. `write_unchecked` returns false (no
      change). **No subscriber scheduling.**
    - `prologos_cell_write(cid-eq-out, boxed-true)` — cell was bot, now
      true. `write_unchecked` returns true. Schedules subscribers (none).
- `swap_worklists()`: worklist_len = 0.
- Loop exits.

**Result**: cid-eq-out = true. WRONG. The native int-eq read from
snapshot (cid-mod-out = bot, treated as 0) and never re-fired
because cid-mod-out's cell value was set to 1 by the IMMEDIATE
write before the pending phase, so the pending write was a no-op
that didn't trigger re-scheduling.

### Why some cases coincidentally work

`int-mod 4 2 = 0`. `int-eq 0 0 = true`. Native int-eq reads
snapshot bot (treated as 0), reads literal 0, returns true. The
result happens to be correct because the actual int-mod result is
also 0. False positive that masks the bug for any input where
int-mod returns 0.

### Why callback→callback chains work

In the `my-eq-zero (my-mod 7 3)` test (`rounds=3`), both ops are
callbacks. The second callback's fire-fn does `b-read` on its
input cell — which goes through `prologos_cell_read` (LIVE state),
not snapshot. So the second callback sees int-mod's actual output.
The bug is specific to NATIVE consumers reading from snapshot.

## Why the existing test suite didn't catch this

The hybrid bundle exists at `dist/prologos-hybrid-bundle/`. The
shape battery's A1–A8 (int-binary tests) all pass because they
test int-binary ops in isolation — no chaining. The OCapN battery
doesn't use `int-mod` at all. Among the workload programs, only W4
GCD and W14 prime-count exercise int-mod, and W4 happens to compute
gcd correctly because the recursion terminates on `int-eq b 0`
which only triggers the "everything reads as 0" case for the final
iteration where b actually IS 0.

The preduce-lite micro suite also doesn't chain int-mod into a
native op, so this bug went undetected.

## Proposed fixes (ranked by invasiveness)

### Fix A: kernel-side — defer scheduling during fire-fn execution (smallest)

In `runtime/prologos-runtime-hybrid.zig`, set a `firing: bool`
flag at the start of `fire_against_snapshot` and clear it at the
end. In `prologos_cell_write`, skip the subscriber scheduling
loop when `firing == true`:

```zig
var firing: bool = false;

fn fire_against_snapshot(pid: u32) void {
    firing = true;
    defer firing = false;
    // ... existing body ...
}

export fn prologos_cell_write(id: u32, value: i64) void {
    if (store.write_unchecked(id, value)) {
        prof.writes_committed += 1;
        if (!firing) {                      // <-- new gate
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

This way, the immediate b-write from inside a callback's fire-fn
mutates the live cell (so the wrapper's read-back returns the
right value, and `merge_pending_writes` writes the same value
again), but doesn't trigger early scheduling that gets discarded.
After firing completes, `merge_pending_writes` calls
`prologos_cell_write` from outside any fire-fn, `firing == false`,
and subscribers get scheduled normally.

Caveat: with this fix, `merge_pending_writes`'s call to
`prologos_cell_write(cid-mod-out, boxed-1)` would be a no-op
(value already 1 from immediate write) → `writes_committed` not
incremented → `write_unchecked` returns false → still no
scheduling. **The fix above is incomplete**.

### Fix A': better kernel-side — track "this round dirtied cells" separately

Introduce a "dirtied during round" set. The immediate b-write adds
the cell to this set. After firing completes, before merge, walk
the set and schedule subscribers. This avoids relying on the
no-op return from `write_unchecked` for cells the immediate write
already updated.

Or simpler: the immediate write inside a fire-fn shouldn't write
at all — just record (cid, value) in a side buffer the wrapper can
return.

### Fix B: Racket-side — wrapper avoids fire-fn's b-write entirely

Restructure so fire-fns RETURN their computed value via a Racket-
side parameter, and the wrapper returns that value (via the kernel
ABI) without ever calling `prologos_cell_write` mid-fire:

```racket
(define current-callback-result (make-parameter #f))

(define (b-write-or-capture net cid v)
  (cond
    [(current-callback-result)
     ;; Inside a callback fire-fn for which the wrapper will return
     ;; the captured value. Skip the kernel write.
     (current-callback-result (cons cid (box-prologos-value v)))
     net]
    [else
     ;; Normal write path (e.g., during init).
     ((preduce-backend-write-cell (current-backend)) net cid v)]))

(define (make-callback-wrapper outputs fire-fn)
  (lambda boxed-inputs
    (define captured (box #f))
    (parameterize ([current-callback-result captured]
                   [current-backend backend-hybrid])
      (fire-fn 'hybrid))
    (cond
      [(unbox captured) => cdr]   ; the boxed value
      [(null? outputs) (prologos_cell_box_bot)]
      [else (prologos_cell_read (car outputs))])))
```

This requires `b-write` to be funneled through a hook that respects
`current-callback-result`. The fire-fns themselves don't change.

### Fix C: Racket-side — fire-fns return their value (most invasive)

Change `make-int-binary-fire` (and all other fire-fn factories) so
fire-fns return the computed value as their fire-fn return value
rather than b-writing. Wrapper captures that value. Fire-fn
shape becomes `(net) -> any/c` (the returned value), used only by
backend-hybrid. backend-racket's wrapper does the b-write.

Most invasive but cleanest architecturally — separates "compute"
from "place output", which is what BSP actually wants.

## Recommendation

Implement **Fix A'** (track dirtied cells during firing, schedule
on the dirtied set after merge). Smallest blast radius:
- One Zig file changed.
- No Racket changes.
- All existing fire-fns continue to work via b-write.
- Performance neutral (one bool flag, one small set).

Defer Fix C to a future cleanup that aligns the Racket-side fire-fn
ABI with what BSP wants conceptually.

## Test additions needed once fixed

Add to `tests/` or `examples/hybrid-battery/`:

1. Direct chain: `[int-eq [int-mod 7 3] 0]` → false.
2. Chain through int+: `[int+ [int-mod 7 3] 100]` → 101.
3. Chain through int*: `[int* [int-mod 7 3] 100]` → 100.
4. Chain through int-lt: `[int-lt [int-mod 7 3] 1]` → false.
5. Re-check W14: `count-primes 2 10` should return 4.
6. Defn returning callback used as native input:
   `def x : Int := [int-mod 7 3]` then `def main := [int+ x 100]`
   → 101.

All 6 currently fail with the bug, will pass after fix.

## Implication for Phase 7 migration ranking

The Phase 7 doc ranks `int-mod` migration as #6 (last priority,
trivial fix, single-fire savings). **This bug elevates int-mod
migration to a CORRECTNESS fix**: until int-mod is either routed
to a native tag OR the BSP-violation is fixed, every program that
chains int-mod into a native consumer silently miscomputes.
That includes all idiomatic prime-checking, modular-arithmetic,
and hash-related programs.

Either:
- (a) **Fix the BSP violation in the callback wrapper / kernel**
  (Fix A' or Fix C above) — addresses the root cause for ALL
  callbacks, not just int-mod. Required if we want
  user-defined `defn` results to feed native consumers correctly.
  (Note: defn-results-feed-native works in our existing tests
  *only* because the elaborator statically β-reduces simple defns
  to literals, masking the bug.)
- (b) **Migrate int-mod to native** — a workaround that fixes
  int-mod specifically but leaves the same bug latent for any
  future callback fire-fn whose output feeds a native consumer.

(a) is the architecturally-correct fix. (b) is a band-aid.

## File references

- `racket/prologos/preduce-backend-hybrid.rkt:96-105` —
  `make-callback-wrapper` (the wrapper that does b-write +
  read-back).
- `racket/prologos/preduce-backend-hybrid.rkt:114-126` —
  backend-hybrid's `write-cell` callback (calls
  `prologos_cell_write`).
- `racket/prologos/preduce.rkt:417` — int-mod's compile case
  (the only int-binary without `#:native-op`).
- `racket/prologos/preduce.rkt:1439` — `int-mod-fire` definition.
- `runtime/prologos-runtime-hybrid.zig:275-285` — kernel-side
  `prologos_cell_write` (the immediate-write + scheduling path).
- `runtime/prologos-runtime-hybrid.zig:385-394` — `schedule`
  (early-returns if `in_worklist[pid] != 0`).
- `runtime/prologos-runtime-hybrid.zig:396-466` —
  `fire_against_snapshot`.
- `runtime/prologos-runtime-hybrid.zig:489-495` —
  `merge_pending_writes`.
- `runtime/prologos-runtime-hybrid.zig:512-534` —
  `prologos_run_to_quiescence` (the BSP outer loop).
