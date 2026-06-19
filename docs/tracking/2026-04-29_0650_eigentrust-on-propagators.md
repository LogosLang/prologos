# EigenTrust on Propagators (Racket-direct, 5th comparison variant)

**Track**: PR #2 follow-up — direct Racket-on-propagators eigentrust to
compare against the four Prologos surface variants.

## Summary

The four existing variants (List + Rat, List + Posit32, PVec + Rat,
PVec + Posit32 — see `2026-04-23_eigentrust_comparison.md`) are all
Prologos surface programs whose `reduce_ms` we measure through
`process-file`. They share the Prologos elaboration / type-check
overhead and the exact-Rat denominator dynamics.

This track adds a 5th variant: a direct Racket implementation of
EigenTrust that uses Prologos's underlying propagator network
infrastructure (`make-prop-network`, `net-new-cell`,
`net-add-propagator`, `run-to-quiescence-bsp`) but bypasses the
Prologos surface language entirely. The measurement isolates "how
fast is the propagator infrastructure on this workload" from "how
fast is Prologos elaboration + reduction on this workload".

## Design

### Architecture: chain-of-cells, one per iteration

```
+---+   step-1   +---+   step-2   +---+   step-3   +---+
|t_0| ---------> |t_1| ---------> |t_2| ---------> |t_3|
+---+            +---+            +---+            +---+
```

- **Cells**: `t_0`, `t_1`, …, `t_K` — each holds the entire trust
  vector at iteration k, as a Racket value. The `t_0` cell is
  pre-loaded with the pre-trust vector p.
- **Constants on-network**: `m-cid` (matrix), `p-cid` (pre-trust),
  `alpha-cid` (damping). Each is a fire-once-write cell with
  last-write-wins merge.
- **Propagators**: K fire-once propagators. `step-k` reads
  (`alpha`, `m`, `p`, `t_{k-1}`) and writes `t_k = (1-α)·M·t + α·p`.
  Fire-once because each step happens exactly once (no re-fire).
- **Final read**: after BSP quiescence, `net-cell-read net t_K-cid`
  returns the result vector.

### Cell merge

Trust vectors are not naturally monotone (each step replaces).
Merge is **last-write-wins**: `(λ (old new) new)`. Combined with
fire-once, this gives "exactly one write" semantics — the cell value
is the propagator's output. (For a true monotone formulation we
would need iteration-indexed lattice values, but that adds
complexity without illuminating the comparison; documented as a
follow-up.)

### Workload

Match the Prologos benchmarks' W3 (the dominant workload):
**4-peer ring matrix, pre-trust concentrated on peer 0, α = 3/10,
3 forced iterations** (eps = 0/1, budget = 3). The expected
result after 3 iterations is

```
[5401/10000, 21/100, 147/1000, 1029/10000]
```

— same hand-computed trajectory as the Prologos versions, derivable
from `t_{k+1} = 7/10·M·t_k + 3/10·p`.

## Network Reality Check

Per `.claude/rules/workflow.md` § "Network Reality Check":

1. **`net-add-propagator` calls?** K calls (one per step) → installation phase.
2. **`net-cell-write` calls produce the result?** K writes (one per `t_k`); final answer is read from `t_K`'s cell.
3. **cell creation → prop installation → cell write → cell read = result?** Yes — direct chain.

The matrix-vector multiply inside the fire function is off-network Racket compute. This is acknowledged debt: the on-network cell flow carries trust vectors between iterations; the per-step computation is opaque to the network. A finer-grained variant (one cell per peer per iteration, K·n propagators each doing one row's dot product) would be more on-network but at higher constant cost — out of scope for the comparison-vs-Prologos goal.

## Progress Tracker

| Phase | Description | Status | Notes |
|---|---|---|---|
| 0 | Tracking doc (this file) | ✅ | – |
| 1 | Implementation: chain-of-cells eigentrust on propagators | ✅ | `benchmarks/comparative/eigentrust-propagators.rkt` — plain propagators (not fire-once); ring-4 W3 returns matching `[5401/10000, 21/100, 147/1000, 1029/10000]` |
| 2 | rackunit test: verify ring-4 result matches the Prologos variants | ✅ | `tests/test-eigentrust-propagators.rkt` — 13 tests (col-stochastic check, off-network kernel, end-to-end, mass preservation), all pass |
| 3 | Benchmark runner integrated with `tools/bench-micro.rkt`-style timing | ✅ | `benchmarks/comparative/eigentrust-propagators-bench.rkt` — W1/W2/W3/W3-deep, 5-run median |
| 4 | 5-way comparison numbers; update `2026-04-23_eigentrust_comparison.md` | ✅ | W3 reduce_ms = 0.16 ms vs Prologos List+Rat 18 372 ms (~115 000× faster); k=10 tractable where surface variants O(k²) blow up |

## Headline result

| Variant            | reduce_ms (W3, ring k=4) |
|--------------------|--------------------------|
| List + Rat (P)     | 18 372 |
| List + Posit32 (P) | 17 990 |
| PVec + Rat (P)     | 33 006 |
| PVec + Posit32 (P) | 33 198 |
| **propagators**    | **0.16** |

The propagator-direct version is ~115 000× faster because it
bypasses Prologos elaboration + reduction — both versions perform
identical Racket-level rational arithmetic. The gap measures the
cost of the Prologos surface language + reducer on this workload.

## Network Reality Check (final)

1. **`net-add-propagator` calls?** K (= 4 for W3) plain propagators installed.
2. **`net-cell-write` calls produce the result?** K writes to t_1..t_K cells; the final answer is read from t_K.
3. **cell creation → prop installation → cell write → cell read = result?** Yes. After construction, BSP runs; after K rounds the chain has settled; final cell is read.

The matrix-vector multiply inside each fire function is off-network
Racket compute (Racket's vector + rational ops). The on-network
flow is the trust-vector cell sequence between iterations. A
fine-grained variant (one cell per peer per iteration, K·n
propagators each doing one row's dot product) is documented in
the design as out-of-scope; the K-step chain is the simplest
on-network expression of the iteration that satisfies the Reality
Check.

## Files

- `racket/prologos/benchmarks/comparative/eigentrust-propagators.rkt` — implementation + main entry
- `racket/prologos/tests/test-eigentrust-propagators.rkt` — rackunit
- `docs/tracking/2026-04-23_eigentrust_comparison.md` — updated with 5th-variant numbers (Phase 4)

## Out of scope

- Fine-grained per-peer cells (K·n propagators)
- Convergence-driven version (eps-based) — only forced-iteration here, matches W3
- Iteration-indexed lattice values for true monotone semantics
- Rewriting the Prologos surface variants to use the same fixture set (already done in PR #2)
