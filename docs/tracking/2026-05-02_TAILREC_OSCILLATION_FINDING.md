# Tail-rec lowering oscillates under opaque inputs — research + proposals

Status: investigated 2026-05-02 (lowering-yolo session).
Author: lowering-yolo session.
Branch: `lowering-yolo`.

**Update 2026-05-03 — fixed in compiler:** `lower-tail-rec`
(`racket/prologos/ast-to-low-pnet.rkt`) now follows **Solution 2** from
§ Solution proposals below: `cond` / `step` read a lagged **`prev`**
copy of state (`kernel-identity`), while **`kernel-select` writes
directly back into each state cell** (freeze branch reads raw state at
logical depth 0). Parameterised tail-rec nets quiesce in \(O(n)\) BSP
rounds instead of entering a perpetual 2–3 cycle at fuel exhaustion.

## TL;DR

The historical tail-rec lowering (pre-2026-05-03) produced a propagator network that
**never quiesces** when the iteration counter is opaque at compile
time. After the iteration "finishes" (cond becomes true), the cells
in the feedback loop enter a **2- or 3-cycle oscillation** indefinitely.

The lowering-yolo M3–M7 benchmark suite passes by **lucky parity**:
the default fuel cap of 100k rounds happens to land the entry cell on
the correct value. Bumping fuel reveals the bug:

| Fuel for `01-tailrec-pair-fib n=10` (expected `fib(10)=55`) | `c1` (entry) |
|---|---|
| 99 000 | **55** ✓ |
| 99 500 | **0** ✗ |
| 100 000 (default) | **55** ✓ |
| 101 000 | **0** ✗ |
| 200 000 | **0** ✗ |
| 300 000 | **55** ✓ |

(Table: behaviour of the **pre-2026-05-03** next-cell feedback lowering.)

This was a real bug, not a substrate quirk. It was masked previously
because every closed-form benchmark in the lowering perf suite folded
to a literal at compile time via Gate 2 — the BSP scheduler never
ran the iteration. Once M3 made inputs opaque (forcing real BSP
execution), the bug surfaced.

## How the bug manifests

The lowered IR for any tail-rec under opaque inputs contains, per
state slot, a five-cell loop:

```
state-cell  ←─ identity feedback ─── next-cell
    │                                   ▲
    │                                   │
    └──── id bridge ──── c11 ──┐        │
                               │        │
                            select(cond, c11, step) → next
                               │
    state-snd ── id bridge ── c9 ────┘
```

The path `state → c11 → next → state` is **3 BSP rounds long** when
F.5's depth-bridge identities are present (which they always are for
multi-arg or pair-state tail-rec). Without F.5's bridges it would be
2 rounds.

After cond flips to TRUE (cond=1, base case), the loop is supposed to
freeze:

```
next ← select(cond=1, state-on-true, _) = state-on-true
state ← identity(next) = next = state-on-true   ← stable iff state == next
```

That fixed point is reached **only if `state == next` at the round
when cond flips**. Under BSP snapshot semantics the propagator chain
is phase-shifted by 2–3 rounds, so this equality almost never holds
in practice. The system enters a periodic limit cycle.

Empirical trace at `n=2` for `01-tailrec-pair-fib` (15 cells, 12 props):
after the iteration computes the right answer (around round 8), the
following 3-cycle persists indefinitely:

```
phase 0: c1=0  c2=1  c10=1  c11=1  c12=2
phase 1: c1=1  c2=2  c10=0  c11=0  c12=1
phase 2: c1=1  c2=2  c10=1  c11=1  c12=2  ← back to phase 0 after one more round
```

For `n=10` at fuel=200 000: `c1=0` (wrong), `c10=55`, `c11=55`,
`c2=1`, `c12=89` — the right values exist *somewhere* in the loop,
just not in the entry cell at the moment fuel runs out.

## Why none of this was noticed earlier

1. Every benchmark in `racket/prologos/benchmarks/lowering/` and
   every example in `racket/prologos/examples/network/n2-tailrec/` is
   closed-form. Gate 2's static-eval folds them at compile time to a
   literal `cell-decl 0 0 N` — the BSP scheduler never runs.

2. The round-trip-acceptance gate (Phase 4 Day 10, `tools/round-trip-acceptance.rkt`)
   only covers `racket/prologos/examples/network/`, all of which static-fold.

3. The Racket prop-network interpreter has the same BSP semantics as
   the Zig kernel (`run-to-quiescence` + snapshot/diff/merge), so
   running the parameterised IR through it would reproduce the same
   oscillation. The interpreter just isn't being asked to.

4. The historical claim "`fib-iter` runs in 32 BSP rounds, regardless
   of N" in `n2-tailrec/fib-iter.prologos` predates Gate 2 and was
   not re-validated after Gate 2 shipped.

5. The default fuel of 100 000 happens to land the correct value in
   the entry cell for every benchmark we've tested. The bench harness
   only validates the entry cell at fuel-out, not the kernel's
   `fuel_out` flag.

## Why "more lifts" doesn't help

The F.5 + F.6 bridge-cache machinery in `lower-tail-rec`
(`ast-to-low-pnet.rkt:1147–1171`) was added to ensure all per-slot
selects fire at the same depth. The intent was correct: under BSP
barrier semantics, synchronising fire boundaries is necessary so
state cells update atomically per iteration.

But the depth-bridges *introduce* the very phase shift they were
meant to suppress. Each `(emit-propagator! ... 'kernel-identity)`
adds a 1-round lag: the bridge cell reads the source from snapshot
and commits the new value to itself one round later. So the
3-element chain `state → c11 → next → state` is what F.5 actually
created.

Removing the F.5 bridges shortens the chain to 2 rounds (`state ↔
next`), which is still a 2-cycle oscillator.

A hand-written self-loop pattern (verified in `/tmp/fib-direct.c`,
not committed):

```
new-state ← select(cond, current-state, step)   ; out0 == in1 (state cell)
```

quiesces cleanly when cond=true (snapshot read + same-value commit
drops the write, no subscriber re-schedule). But it overshoots by
one iteration because `cond` is computed from `state` and lags one
round behind, so the select picks `step` once after the iteration
should have stopped: `fib(2)` returns 2, `fib(5)` returns 9.

The bug is **fundamental to the current lowering shape**, not to the
particular bridging strategy.

## Solution proposals

Ranked by recommended priority, with scope and risk.

### Solution 1 (RECOMMENDED): Iteration-as-scope

Lower a tail-rec call to a **kernel scope**. Inside the scope, run
the iteration to quiescence using the existing pattern. When the
scope's BSP loop quiesces (cond=true reached, no further state
changes inside the scope), publish the entry-cell's value to a
parent-scope cell via the privileged `cell_reset` write. The
outer network sees a single atomic state transition.

Why this works:
- The kernel already supports scopes (Phase 1 Day 3+) with their
  own fuel, worklist, and quiescence detection.
- `cell_reset` is the non-merging write that doesn't schedule
  subscribers — exactly the "snap to converged value" primitive we
  need.
- Quiescence inside the scope is well-defined: when the inner
  worklist drains AND no value cells changed, we're done. The
  oscillation problem disappears because the inner scope has no
  outer subscribers to keep firing.
- This was the original Pocket Universe + stratification design
  vision (`docs/tracking/2026-05-02_KERNEL_POCKET_UNIVERSES.md`):
  iteration-as-scope was the canonical example. We just never
  wired it up for tail-rec.

Cost:
- One new propagator tag (`kernel-scope-run` or similar) that calls
  `prologos_scope_enter` / `prologos_scope_run` / `prologos_scope_exit`.
- Lower `lower-tail-rec` to: allocate scope, build sub-network in
  scope, install a "scope-run" propagator that fires once and
  publishes the result.
- ~200 lines in `ast-to-low-pnet.rkt`, ~30 lines in
  `prologos-runtime.zig` for the new tag.
- Re-tests all 4 parameterised benchmarks, plus a CI gate for
  fuel-doubling stability.

Risk: medium. Requires careful interaction with the topology-
mutation tier of the 2-tier outer loop. The scope-run propagator
fires once during the outer round-1; the inner BSP loop runs to
quiescence; the published cell update wakes outer subscribers.

### Solution 2: Same-cell self-loop with one-round cond-prefetch

Replace the `state-cell + next-cell + identity-feedback` triple with
a single state-cell that the select writes to directly:

```
state ← select(cond, state, step)
```

This quiesces cleanly when `cond=true` (snapshot self-read commits
identical value, no schedule).

The one-round overshoot bug needs fixing by **computing cond from a
"pre-state" snapshot**: introduce a dedicated cond-ready cell that
lags state by exactly one round, and have the select read from it
instead of state directly:

```
state-prev ← identity(state)                  ; lags state by 1
cond       ← int-lt(state-prev-counter, 1)
step       ← f(state-prev)                    ; uses state-prev
state      ← select(cond, state, step)        ; self-loop
```

So the full loop is:
- Round k: state := X; subscribers fire; arith reads state=X.
- Round k+1: state-prev := X; cond := (X<1); step := f(X).
- Round k+2: select(cond[X<1], state, step) writes state := select-result.

Termination: when `state-counter` reaches 0, round k+1 sets cond=1.
Round k+2's select picks `state` (cond=1) → state := state. Drop.
Quiesces.

Cost:
- Smaller change than Solution 1: ~80 lines in `lower-tail-rec`.
- No kernel changes.
- Per-slot allocation: 1 state cell + 1 state-prev cell instead of
  3 cells (state + bridge + next). Typically 5/3 the cell count
  reduction.

Risk: medium-low. Requires getting the depth/timing of `state-prev`
right; the F.5 alignment work would migrate to ensuring all of
{state, state-prev, cond, step} fire on synchronised rounds.

### Solution 3: Add a "stable" domain to the kernel

Introduce a new cell domain (alongside LWW and MIN) where once a
write commits, all subsequent writes are dropped regardless of
value. Use it for the entry cell only.

Conceptually: "this cell wants exactly one value during its
lifetime; the iteration that produces it is allowed to overshoot
internally, but the entry-cell snapshot is whatever the iteration
*first wrote* after cond=true."

Cost:
- ~30 lines in `prologos-runtime.zig` for the new domain.
- ~20 lines in `low-pnet-to-llvm.rkt` to allocate the entry cell
  with the new domain.
- ~5 lines in `ast-to-low-pnet.rkt`.

Risk: high. This **doesn't fix the underlying oscillation** — it
just makes the entry-cell read correct by accident the same way
the current code does, only deterministic. Internal cells still
fire 100k times wasting CPU. Wall-time of the parameterised
benchmarks stays at 3 seconds. And the "first write after cond=true"
heuristic is fragile if the iteration overshoots before cond
catches up.

Not recommended as the primary fix; could be a useful complement
for entry-cell stability.

### Solution 4: Cycle detection in the BSP scheduler

Maintain a small ring buffer of "cell-state snapshots over the last
K rounds". After each round, check whether the current cell-state
matches any of the last K. If yes, force quiescence.

Cost:
- ~80 lines in `prologos-runtime.zig`.
- BSS impact: K × HAMT-root snapshots (K=8 → ~64 bytes since HAMT
  roots are pointer-share).
- O(K) hash compare per round.

Risk: high. This is a substrate-level workaround that masks the
lowering bug. Doesn't fix the wasted CPU (K rounds are still wasted
detecting the cycle). Is intrusive to the kernel.

Not recommended.

### Solution 5: Eliminate F.5 bridges + accept overshoot

Strip F.5/F.6 from `lower-tail-rec` and accept that the resulting
2-step `state ↔ next` loop has a fixed-parity oscillation. Pin
fuel to a known-good parity (e.g. 100 000) and document the
fragility.

Cost: trivial code removal.
Risk: extreme — this is what we have today, just made explicit.

Not recommended.

## Recommendation

**Implement Solution 1 (iteration-as-scope) as the canonical fix.**
It aligns with the Pocket Universe design that has been extensively
discussed and partially implemented. The kernel already exposes the
scope APIs we need (`prologos_scope_enter/run/exit`). The remaining
work is in `ast-to-low-pnet.rkt` to lower tail-rec into a scope-run
propagator, and a small kernel addition for the new propagator tag.

**Implement Solution 2 (same-cell + state-prev) as a fallback** if
Solution 1 turns out to have unforeseen scope-interaction issues.
Solution 2 is purely a lowering change and would unblock the
parameterised benchmarks within a few hours.

**Add a CI gate**: extend `tools/bench-lowering.rkt` to run each
parameterised program at multiple fuel levels (e.g. 10k, 100k,
500k, 1M) and verify the entry cell value is stable across them.
This catches the parity-dependence bug deterministically.

## What is NOT recommended

- **Don't ship more parameterised benchmarks** until one of
  Solutions 1 or 2 is in. The current pass-by-luck behaviour is
  fragile; any change to the kernel scheduler, propagator install
  order, or default fuel could flip every benchmark to FAIL.
- **Don't bump default `MAX_ROUNDS`**. Higher fuel just changes
  the parity dimension of the bug; wall-time goes up linearly.
- **Don't try to fix this in `low-pnet-to-llvm.rkt`**. The IR
  itself is wrong. Fixing it at the LLVM emission stage would
  diverge from the Racket interpreter's behaviour and break the
  round-trip-acceptance gate as a regression detector.

## Provenance

- Lowering source: `racket/prologos/ast-to-low-pnet.rkt:1032–1215`
  (`lower-tail-rec`).
- F.5 + F.6 bridge logic: same file, lines 964–1018.
- Kernel BSP loop: `runtime/prologos-runtime.zig:647–684`
  (`prologos_run_to_quiescence`) + 700–735 (`run_value_tier`).
- Per-round trace evidence: `/tmp/trace-fib-natural` (not committed),
  raw IR in `/tmp/01-tailrec-pair-fib.pnet`.
- Fuel-parity table: this doc, "TL;DR" section above.
