# Phase 2.5: BSP Parallel Propagator Execution

**Created**: 2026-02-24
**Completed**: 2026-02-24
**Plan file**: `.claude/plans/buzzing-launching-pascal.md`
**Purpose**: Add BSP (Bulk Synchronous Parallel) scheduler, threshold propagators, and parallel executor to the propagator network — making it parallel-ready before Phase 3 type integration.

---

## Status Legend

- ✅ **Done** — implemented, tested, passing

---

## Summary

| Component                       | Status | Details                                                                                                             |
|---------------------------------|--------|---------------------------------------------------------------------------------------------------------------------|
| BSP scheduler (2.5a)            | ✅     | 5 new functions: dedup-pids, fire-and-collect-writes, bulk-merge-writes, sequential-fire-all, run-to-quiescence-bsp |
| Threshold propagators (2.5b)    | ✅     | 4 new functions: make-threshold-fire-fn, make-barrier-fire-fn, net-add-threshold, net-add-barrier                   |
| Parallel executor (2.5c)        | ✅     | 1 new function: make-parallel-fire-all (racket/future)                                                              |
| `propagator.rkt` (updated)      | ✅     | ~265 → ~480 lines (+~120 new lines, 9 new exports)                                                                  |
| `tests/test-propagator-bsp.rkt` | ✅     | 18 tests: 10 BSP core + 5 threshold + 3 parallel                                                                    |
| `tools/dep-graph.rkt`           | ✅     | 1 new test dep added                                                                                                |

---

## Architecture

### BSP (Bulk Synchronous Parallel) Scheduler

The existing `run-to-quiescence` uses **Gauss-Seidel iteration** — fire one propagator at a time, each seeing the latest state. The new `run-to-quiescence-bsp` uses **Jacobi iteration**:

```
Round k:
  1. Deduplicate worklist (CHAMP-based set, no racket/list dependency)
  2. Clear worklist, snapshot the network, decrease fuel by N
  3. Fire ALL propagators against the SAME snapshot
  4. Collect writes by diffing output cells (propagator.outputs)
  5. Bulk-merge all writes into snapshot via net-cell-write
  6. Repeat until contradiction / fuel / empty worklist
```

**Same fixpoint** as Gauss-Seidel, guaranteed by the CALM theorem: lattice join is commutative, associative, and idempotent → any scheduling order produces the same result.

| Property                 | Gauss-Seidel (existing) | BSP (Jacobi)     |
|--------------------------|-------------------------|------------------|
| Convergence (chain of N) | 1–N passes              | Exactly N rounds |
| Convergence (fan-out)    | 2–3 passes              | 1–2 rounds       |
| Parallelizable           | No                      | Yes (per round)  |
| Fuel usage               | ≤ BSP                   | ≥ Gauss-Seidel   |
| Deterministic ordering   | Worklist order          | Round-based      |

### Threshold Propagators

Threshold propagators gate downstream computation until a cell's value crosses a lattice threshold. They are standard propagators whose `fire-fn` checks a predicate before executing the body.

- **`make-threshold-fire-fn`**: Watches a single cell, fires body only when `(threshold? (net-cell-read net watched-cid))` is true
- **`make-barrier-fire-fn`**: Watches multiple cells via a conditions list, fires only when ALL predicates are satisfied
- **`net-add-threshold`** / **`net-add-barrier`**: Convenience wrappers that auto-include watched cells in input-ids

For monotonic lattices, once a threshold is met it stays met → the body fires at most once after crossing. This is push-based and reactive (not polling).

### Parallel Executor

`make-parallel-fire-all` creates a pluggable executor for `run-to-quiescence-bsp`:

- Below threshold (default: 4 propagators): falls back to `sequential-fire-all`
- Above threshold: creates one `future` per propagator, `touch` all to collect results
- **Future-safe**: CHAMP operations are pure struct/vector operations — no mutation, no I/O

```racket
;; Sequential (default)
(run-to-quiescence-bsp net)

;; Parallel
(run-to-quiescence-bsp net #:executor (make-parallel-fire-all))

;; Parallel with custom threshold
(run-to-quiescence-bsp net #:executor (make-parallel-fire-all 8))
```

**Contract**: fire-fns MUST be pure for parallel execution. Non-pure fire-fns produce non-deterministic results with the parallel executor.

---

## New Functions

### Phase 2.5a: BSP Scheduler

| Function | Signature | Description |
|----------|-----------|-------------|
| `dedup-pids` | `(listof prop-id) → (listof prop-id)` | CHAMP-based deduplication (internal) |
| `fire-and-collect-writes` | `net pid → (listof (cons cell-id value))` | Fire propagator against snapshot, diff output cells |
| `bulk-merge-writes` | `net all-writes → net` | Fold net-cell-write over all collected writes |
| `sequential-fire-all` | `net pids → (listof writes)` | Map fire-and-collect-writes over all pids |
| `run-to-quiescence-bsp` | `net [#:executor] → net` | BSP loop with pluggable executor |

### Phase 2.5b: Threshold Propagators

| Function | Signature | Description |
|----------|-----------|-------------|
| `make-threshold-fire-fn` | `cid threshold? body-fn → fire-fn` | Gated fire-fn (single cell watch) |
| `make-barrier-fire-fn` | `conditions body-fn → fire-fn` | Multi-cell gated fire-fn |
| `net-add-threshold` | `net cid threshold? inputs outputs body-fn → (values net pid)` | Convenience: threshold + add-propagator |
| `net-add-barrier` | `net conditions extra-inputs outputs body-fn → (values net pid)` | Convenience: barrier + add-propagator |

### Phase 2.5c: Parallel Executor

| Function | Signature | Description |
|----------|-----------|-------------|
| `make-parallel-fire-all` | `[threshold] → executor-fn` | Creates parallel executor via racket/future |

---

## Files Modified

| File | Change |
|------|--------|
| `propagator.rkt` | +~120 lines: BSP scheduler, threshold propagators, parallel executor, `(require racket/future)` |
| `tools/dep-graph.rkt` | +1 test dep entry for `test-propagator-bsp.rkt` |

## Files Created

| File | Description |
|------|-------------|
| `tests/test-propagator-bsp.rkt` | 18 tests across 3 categories |

---

## Test Categories

### BSP Core (10 tests)

| # | Test | What's Verified |
|---|------|----------------|
| 1 | Simple chain A→B converges | Basic BSP propagation |
| 2 | Diamond A→B, A→C, B+C→D converges | Parallel writes in same round |
| 3 | Fan-out: one input, 2 outputs | Multiple propagators fire simultaneously |
| 4 | Chain of 5 cells | Multi-round BSP convergence |
| 5 | Fuel decreases by N per round | Fuel accounting consistency |
| 6 | Worklist deduplication | Duplicate pid → fired once (CHAMP dedup) |
| 7 | Contradiction halts BSP | Sticky contradiction stops execution |
| 8 | Already-contradicted returns immediately | Early exit (eq? same net) |
| 9 | Empty worklist returns immediately | Early exit (eq? same net) |
| 10 | Same fixpoint as Gauss-Seidel | Diamond + tail chain, compare all cells |

### Threshold Propagators (5 tests)

| # | Test | What's Verified |
|---|------|----------------|
| 11 | Fires when condition met | ca >= 5 → body writes to cb |
| 12 | Does NOT fire below threshold | ca < 10 → cb unchanged |
| 13 | Multi-round gating | A→B propagation triggers threshold on B → writes C |
| 14 | Barrier: all conditions met | ca >= 5 AND cb >= 3 → fires |
| 15 | Barrier: partial conditions block | ca met, cb not met → doesn't fire |

### Parallel Executor (3 tests)

| # | Test | What's Verified |
|---|------|----------------|
| 16 | Same result as sequential | Diamond network, threshold=1 forces futures |
| 17 | Below-threshold fallback | threshold=100, only 1 propagator → sequential |
| 18 | Large fan-out (20 propagators) | Stress test: 20 parallel copy propagators |

---

## Key Design Decisions

1. **BSP coexists with Gauss-Seidel**: `run-to-quiescence` (sequential) and `run-to-quiescence-bsp` (parallel-ready) coexist. Users choose the scheduler. Both produce the same fixpoint for monotone networks.

2. **Write collection via diffing**: Instead of capturing writes inline, `fire-and-collect-writes` runs the propagator against a snapshot and diffs output cells. This is clean, composable, and works with any fire-fn — no changes to existing propagator contract.

3. **Executor as parameter**: `run-to-quiescence-bsp` takes an `#:executor` keyword argument. Default is `sequential-fire-all`. Swap in `(make-parallel-fire-all)` for parallelism. This keeps the scheduler logic independent of the execution strategy.

4. **CHAMP-based deduplication**: `dedup-pids` uses CHAMP as a set (via `champ-has-key?` + `champ-insert`) instead of `remove-duplicates` from `racket/list`. Avoids adding a dependency on `racket/list`.

5. **Threshold propagators are standard propagators**: No special scheduler support needed. The gating logic is in the fire-fn closure. This means they work with both Gauss-Seidel and BSP schedulers.

6. **Future safety**: CHAMP operations are pure struct/vector operations. Each propagator fires against a frozen snapshot and produces a new network. No shared mutable state → `racket/future` is safe.

7. **Threshold for parallel fallback**: Below 4 propagators (configurable), futures overhead exceeds benefit. The parallel executor falls back to sequential automatically.

---

## Key Lessons

1. **Duplicate `_` binding names in Racket**: `define-values` does not allow multiple `_` bindings in the same scope (unlike some other languages). In `test-propagator-bsp.rkt`, we used unique names (`_p0`, `_p1`, etc.) instead.

2. **BSP fuel accounting**: Fuel decreases by N (propagators fired per round), consistent with Gauss-Seidel where fuel decreases by 1 per propagator. This makes fuel usage comparable between the two schedulers.

3. **Jacobi vs Gauss-Seidel convergence**: For chain topologies, BSP requires exactly N rounds (one per link). Gauss-Seidel can converge in 1 pass if worklist happens to be in the right order. Fan-out topologies converge in 1 BSP round regardless.

---

## Dependency Structure

```
propagator.rkt ──depends-on──> champ.rkt, racket/future

test-propagator-bsp.rkt ──depends-on──> propagator.rkt, champ.rkt
```

No dependency on the AST pipeline — fully isolated (same as Phase 2).
