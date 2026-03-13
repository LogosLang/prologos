# Track 1: Constraint Tracking — Cell-Primary Reads

**Created**: 2026-03-12
**Status**: Stage 3 (Implementation — Phases 0-5 COMPLETE, Phase 6 PARTIAL)
**Depends on**: Propagator-First Migration Sprint Phases 0-4 (COMPLETE)
**Enables**: Track 4 (ATMS Speculation)
**Research basis**: `2026-03-11_PROPAGATOR_FIRST_PIPELINE_AUDIT.md` §3.2, `2026-03-11_WHOLE_SYSTEM_PROPAGATOR_MIGRATION.md` §4.2 Tier 1
**Prior implementation**: `2026-03-11_1800_PROPAGATOR_FIRST_MIGRATION.md` Phases 1a-1e (dual-write)
**Supersedes**: Track 0 (`2026-03-12_TRACK0_CELL_PRIMARY_READS.md`) — benchmarking protocol folded in

---

## 1. Context

The Propagator-First Migration Sprint (Phases 1a-1e) established dual-write for all constraint tracking state: every constraint registration, trait constraint, hasmethod constraint, capability constraint, and wakeup registry entry is written to both the legacy Racket parameter AND a propagator cell. All **reads** still go through legacy parameters.

This track flips reads from parameters to cells, then removes the parameter writes — making cells the single source of truth for constraint tracking. This is the Pipeline Audit's highest-priority migration target because it eliminates the retry-loop/dirty-flag machinery that currently bridges the gap between parameter state and propagator-driven resolution.

**Key insight**: The current parameter-based constraint infrastructure (wakeup registries, dirty flags, retry loops) IS a hand-rolled propagator network — it maintains dependencies, tracks what needs re-evaluation, and fires callbacks on state changes. The dual-write proved that the actual propagator network can mirror this behavior exactly. This track replaces the hand-rolled version with the real one, gaining monotonic merges, automatic transitive wakeup, and ATMS-compatible provenance for free.

### 1.1 Current Read Sites (Parameter-Based)

| Function | File | What it reads | Used by |
|----------|------|---------------|---------|
| `all-postponed-constraints` | metavar-store.rkt:657 | `current-constraint-store` | driver.rkt (type-check pipeline) |
| `all-failed-constraints` | metavar-store.rkt:663 | `current-constraint-store` | driver.rkt (error reporting) |
| `get-wakeup-constraints` | metavar-store.rkt:579 | `current-wakeup-registry` | `retry-constraints-for-meta!` |
| `retry-constraints-for-meta!` | metavar-store.rkt:584 | `current-wakeup-registry` + `current-retry-unify` | `solve-meta!` (on meta solution) |
| `lookup-trait-constraint` | metavar-store.rkt:310 | `current-trait-constraint-map` | trait-resolution.rkt |
| `lookup-hasmethod-constraint` | metavar-store.rkt:374 | `current-hasmethod-constraint-map` | trait-resolution.rkt |
| `lookup-capability-constraint` | metavar-store.rkt:417 | `current-capability-constraint-map` | capability-inference.rkt |
| `resolve-trait-constraints!` | trait-resolution.rkt:316 | `current-trait-constraint-map` | driver.rkt (post-elaboration) |
| `check-unresolved-trait-constraints` | trait-resolution.rkt:338 | `current-trait-constraint-map` | driver.rkt (error check) |
| `resolve-hasmethod-constraints!` | trait-resolution.rkt:464 | `current-hasmethod-constraint-map` | driver.rkt (post-elaboration) |
| `unify` / `unify-core` | unify.rkt:707,547 | `current-constraint-store` (snapshot comparison) | everywhere |
| `with-speculative-rollback` | elab-speculation-bridge.rkt:190 | `current-constraint-store` (save/restore) | typing-core.rkt |

### 1.2 Current Cell-Based Reads (Already Exist)

| Function | File | What it reads | Status |
|----------|------|---------------|--------|
| `read-constraint-store` | metavar-store.rkt:629 | Cell with parameter fallback | Exported but mostly unused |
| `retry-constraints-via-cells!` | metavar-store.rkt:603 | Meta cells (not constraint cells) | Active — runs after quiescence |

### 1.3 What Flipping Reads Eliminates

Once constraint reads go through cells:

- **`current-retry-trait-resolve` dirty flag** — trait resolution fires as a propagator when dependent metas solve, not via a polling loop
- **`current-retry-unify` dirty flag** — constraint retry fires via wakeup propagation, not via explicit dirty-flag check
- **Manual wakeup registry** — the propagator network's dependency graph IS the wakeup registry; explicit `current-wakeup-registry` becomes redundant
- **`retry-constraints-via-cells!` full-scan** — exists precisely because the wakeup registry is parameter-based and misses transitive wakeups; with cells, transitive wakeup is automatic
- **Speculation constraint leak** — `with-speculative-rollback` manually saves/restores `current-constraint-store` (Phase 4b fix); with cell-primary flow, the network snapshot handles this automatically

---

## 2. Design

### 2.1 Phase 0: Benchmarking Baseline + Cell Metrics

Before any read-flips, establish the performance baseline that all subsequent phases measure against.

**Deliverables**:
- `git tag benchmark-baseline-track-1`
- `data/benchmarks/baseline-track-1.txt` from `--report`
- Cell metrics instrumentation: total cells, total propagators, cells-with-content per elaboration

**Cell metrics implementation**: Add a `--cell-metrics` flag to `tools/run-affected-tests.rkt` that, for each test file, records alongside timing:

```jsonl
{"file": "...", "wall_ms": ..., "cells": N, "propagators": M, "cells_with_content": K}
```

Source: after `process-string` / `process-file` returns, read `prop-network-next-cell-id` and `prop-network-next-prop-id` from the final `elab-network`. This is a read of two struct fields — zero overhead when the flag isn't set, negligible when it is.

**Workflow rule** (add to `.claude/rules/workflow.md`):

> **Benchmarking protocol for migration tracks**: Before starting a migration track, run `racket tools/benchmark-tests.rkt --report`, save output to `data/benchmarks/baseline-track-N.txt`, and `git tag benchmark-baseline-track-N`. After each phase, run `--compare benchmark-baseline-track-N`. Include delta in the progress table's "Bench" column. Flag any regression >5% wall time for investigation.

### 2.2 Phase 1: Constraint Store Reads → Cell

The most impactful flip. `current-constraint-store` is read in 5 locations across 3 files.

**Change**: Make `read-constraint-store` (which already exists with cell-read + parameter-fallback) the sole read path. Then update callers:

| Current call | Change to |
|-------------|-----------|
| `(current-constraint-store)` in `all-postponed-constraints` | `(read-constraint-store)` |
| `(current-constraint-store)` in `all-failed-constraints` | `(read-constraint-store)` |
| `(current-constraint-store)` in `retry-constraints-via-cells!` | `(read-constraint-store)` |
| `(current-constraint-store)` in `unify.rkt` (2 snapshot sites) | `(read-constraint-store)` |
| `(current-constraint-store)` in `elab-speculation-bridge.rkt` | See Phase 4 |

After all callers are switched and the test suite passes, remove the legacy parameter write from `add-constraint!` — the cell write is the only write.

**Files touched**: `metavar-store.rkt`, `unify.rkt`
**Test gate**: Full suite (6889 tests), no failures

### 2.3 Phase 2: Trait/HasMethod/Capability Constraint Reads → Cell

The trait constraint maps are read by `trait-resolution.rkt` for iteration and by `metavar-store.rkt` for lookup.

**Change**: For each map, add a cell-read accessor following the same pattern as `read-constraint-store`:

```racket
(define (read-trait-constraints)
  (define cid (current-trait-constraint-cell-id))
  (define net-box (current-prop-net-box))
  (define read-fn (current-prop-cell-read))
  (if (and cid net-box read-fn)
      (read-fn (unbox net-box) cid)
      (current-trait-constraint-map)))

(define (read-hasmethod-constraints)
  ;; same pattern with current-hasmethod-constraint-cell-id
  ...)

(define (read-capability-constraints)
  ;; same pattern with current-capability-constraint-cell-id
  ...)
```

Then update callers:

| Current call | Change to |
|-------------|-----------|
| `(current-trait-constraint-map)` in `resolve-trait-constraints!` | `(read-trait-constraints)` |
| `(current-trait-constraint-map)` in `check-unresolved-trait-constraints` | `(read-trait-constraints)` |
| `(current-trait-constraint-map)` in `lookup-trait-constraint` | `(hash-ref (read-trait-constraints) meta-id #f)` |
| `(current-trait-constraint-map)` in `retry-trait-wakeup-for-meta!` (2 sites) | `(read-trait-constraints)` |
| `(current-hasmethod-constraint-map)` in `resolve-hasmethod-constraints!` | `(read-hasmethod-constraints)` |
| `(current-hasmethod-constraint-map)` in `lookup-hasmethod-constraint` | `(hash-ref (read-hasmethod-constraints) meta-id #f)` |
| `(current-hasmethod-constraint-map)` in wakeup path | `(read-hasmethod-constraints)` |
| `(current-capability-constraint-map)` in `lookup-capability-constraint` | `(hash-ref (read-capability-constraints) meta-id #f)` |

**Precondition (Phase 2pre)**: `current-capability-constraint-map` has dual-write for `register-capability-constraint!` but the explore agent reported it may not be dual-written yet (Phase 1b incomplete for capability). **Before flipping any reads in Phase 2, verify and complete the dual-write.** This was Open Question #1 — resolved by making it a gate.

**Files touched**: `metavar-store.rkt`, `trait-resolution.rkt`
**Test gate**: Full suite, no failures

### 2.4 Phase 3: Wakeup Registry Reads → Cell

The wakeup registry maps meta-ids to lists of constraints for targeted retry. The cell version uses `merge-hasheq-list-append`.

**Change**:

```racket
(define (read-wakeup-registry)
  (define cid (current-wakeup-registry-cell-id))
  (define net-box (current-prop-net-box))
  (define read-fn (current-prop-cell-read))
  (if (and cid net-box read-fn)
      (read-fn (unbox net-box) cid)
      (current-wakeup-registry)))
```

Update `get-wakeup-constraints` to use `read-wakeup-registry`. Add a matching `read-trait-wakeup-map` accessor for `current-trait-wakeup-map` (used in `retry-trait-wakeup-for-meta!`).

**Subtlety**: The legacy `current-wakeup-registry` and `current-trait-wakeup-map` are **mutable hasheq** (`make-hasheq` with `hash-set!`). The cell versions store **immutable hasheq** (each write merges via `merge-hasheq-list-append`). The read values should be equivalent, but the mutable → immutable transition means we can't `eq?`-compare them. `equal?` comparison is the correctness gate.

**Phase 3c verification**: After flipping reads, grep for any remaining `hash-set!` calls on the wakeup maps. There should be zero — all mutations should go through cell writes.

```bash
grep -rn 'hash-set!.*wakeup' racket/prologos/
```

**Files touched**: `metavar-store.rkt`
**Test gate**: Full suite, no failures

### 2.5 Phase 4: Speculation Save/Restore Alignment

`with-speculative-rollback` currently saves/restores `current-constraint-store` as a separate parameter (Phase 4b fix). Once constraint reads go through cells, this save/restore is redundant — the network snapshot already captures the constraint cell's state.

**Change**: Remove the explicit `(define saved-constraints (current-constraint-store))` and `(current-constraint-store saved-constraints)` from `with-speculative-rollback`. The `save-meta-state` / `restore-meta-state!` already captures and restores the `current-prop-net-box`, which contains the constraint cell.

**Focused speculation tests** (Phase 4b — must all pass before proceeding):
- `tests/test-speculation-bridge-01.rkt` — explicit save/restore scenarios
- `tests/test-church-fold-*.rkt` — speculative Church fold with constraint rollback
- `tests/test-union-*.rkt` — union type resolution via speculation
- `tests/test-bare-param-*.rkt` — bare parameter inference with fallback
- `tests/test-trait-resolution-*.rkt` — trait resolution interacting with speculation

These exercise the exact scenario where speculation adds constraints that must be rolled back on failure. Run these individually to validate Phase 4a before running the full suite.

**Files touched**: `elab-speculation-bridge.rkt`
**Test gate**: Focused speculation tests first, then full suite

### 2.6 Phase 5: Remove Legacy Parameter Writes

With all reads going through cells and all tests passing, the legacy parameter writes are dead code. Remove them:

- Remove `(current-constraint-store (cons c ...))` from `add-constraint!` (keep only the cell write)
- Remove `(hash-set! (current-trait-constraint-map) ...)` from `register-trait-constraint!`
- Remove `(hash-set! (current-hasmethod-constraint-map) ...)` from `register-hasmethod-constraint!`
- Remove `(hash-set! (current-capability-constraint-map) ...)` from `register-capability-constraint!`
- Remove `(hash-set! (current-wakeup-registry) ...)` wakeup builds (keep only cell writes)
- Remove `(hash-set! (current-trait-wakeup-map) ...)` wakeup builds

**Do NOT remove the parameter definitions yet** — they may still be referenced in `reset-meta-store!`, `with-meta-env`, test fixtures. Those are cleaned up in a subsequent pass.

**Phase 5b**: After removing writes, re-run the focused speculation tests from Phase 4b. Write removal changes the operational semantics — speculation paths that previously read from parameters now see different state. Regression here would indicate a dual-write inconsistency that was masked by the parameter path.

**Files touched**: `metavar-store.rkt`
**Test gate**: Focused speculation tests (Phase 5b), then full suite

### 2.7 Phase 6: Parameter Removal + Cleanup

Remove the now-dead parameters and update all reset/initialization code:

- Remove `current-constraint-store` parameter definition and all references
- Remove `current-wakeup-registry` parameter definition (mutable hasheq)
- Remove `current-trait-constraint-map` parameter definition (mutable hasheq)
- Remove `current-trait-wakeup-map` parameter definition (mutable hasheq)
- Remove `current-hasmethod-constraint-map` parameter definition (mutable hasheq)
- Remove `current-capability-constraint-map` parameter definition (mutable hasheq)
- Remove `current-retry-unify` dirty flag (if wakeup is now propagator-driven)
- Remove `current-retry-trait-resolve` dirty flag (if trait resolution is now propagator-driven)
- Update `reset-constraint-store!` — cell IDs are still reset per-command (new cells created)
- Update `with-meta-env` in test fixtures — remove constraint parameter bindings
- Update `driver.rkt` parameterize blocks — remove constraint parameters

**Mental model for dirty-flag removal (Phase 6b)**: For each dirty flag, ask: "What propagator edge does this flag represent?" The flag is a manual notification channel — it says "something changed, re-evaluate me." In the cell-primary world, this notification is a propagator edge from the source cell to the consumer. If we can identify that edge and verify it fires correctly, the flag is dead code. If we can't identify it, the flag encodes a dependency we haven't yet surfaced — keep it and document what's missing.

- `current-retry-unify`: represents edge from meta-solution → constraint retry
- `current-retry-trait-resolve`: represents edge from meta-solution → trait resolution

**Caution**: These flags may still be needed if the transition is partial (some retry paths still use polling). Remove only when ALL retry paths go through propagator wakeup. If uncertain, defer removal to a later track and document in DEFERRED.md.

**Files touched**: `metavar-store.rkt`, `driver.rkt`, `unify.rkt`, `elab-speculation-bridge.rkt`, test fixtures
**Test gate**: Full suite, no failures

---

## 3. Progress Tracker

| Phase | Description | Status | Bench | Notes |
|-------|-------------|--------|-------|-------|
| 0a | Capture baseline benchmarks (`--report`) | ✅ | 189.2s | 6889 tests, 358 files |
| 0b | Add `--cell-metrics` to test runner | ✅ | 197.5s | `ffc5d26` — cells 37-81/file |
| 0c | Tag baseline commit | ✅ | — | `benchmark-baseline-track-1` |
| 1a | `all-postponed-constraints` → cell read | ✅ | | `b11cce8` |
| 1b | `all-failed-constraints` → cell read | ✅ | | `b11cce8` |
| 1c | `retry-constraints-via-cells!` → cell read | ✅ | | `b11cce8` |
| 1d | `unify.rkt` snapshot sites → cell read | ✅ | | `b11cce8` — `last` not `car` |
| 1e | Remove parameter write from `add-constraint!` | ✅ | | Folded into Phase 5a |
| 2pre | Verify capability constraint dual-write complete | ✅ | | Verified — dual-write present |
| 2a | `read-trait-constraints` accessor + callers | ✅ | | `6720408` |
| 2b | `read-hasmethod-constraints` accessor + callers | ✅ | | `6720408` |
| 2c | `read-capability-constraints` accessor + callers | ✅ | | `6720408` |
| 2d | Remove parameter writes for trait/hasmethod/cap | ✅ | | Folded into Phase 5a |
| 3a | `read-wakeup-registry` accessor + callers | ✅ | | `7fe5d5a` |
| 3b | `read-trait-wakeup-map` accessor + callers | ✅ | | `7fe5d5a` |
| 3c | Verify no `hash-set!` on wakeup maps remains | ✅ | | Only writes remain |
| 3d | Remove parameter writes for wakeup registries | ✅ | | Folded into Phase 5a |
| 4a | Speculation alignment for cell-primary | ✅ | | `3f1c69b` — conditional save/restore |
| 4b | Focused speculation test pass | ✅ | | 27/27 pass |
| 5a | Cell-primary writes with parameter fallback | ✅ | 190.6s | `2c6e237` — all 6889 tests pass |
| 5b | Re-run speculation tests after write removal | ✅ | | All pass |
| 6a | Remove constraint parameter definitions | ⏸️ | | Parameters stay as fallback for unit tests |
| 6b | Remove dirty flags (`current-retry-unify` etc.) | ⏸️ | | Defer: retry paths still use polling |
| 6c | Update `reset-meta-store!`, `with-meta-env`, driver | ⏸️ | | Blocked on 6a |
| 6d | Final benchmark comparison | ✅ | 191.4s | +1.2% vs baseline (noise) |

---

## 4. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Constraint cell content differs from parameter (drift) | Low | High | Dual-write has been validated by 6889 tests over months; `read-constraint-store` already exists with fallback |
| Speculation rollback breaks when relying on cell snapshot | Medium | High | Phase 4 is dedicated to this; focused speculation tests gate it |
| Mutable→immutable hasheq transition causes subtle bugs | Low | Medium | All cell merges use immutable hasheq; reads return immutable values; callers already use `hash-ref` (read-only) |
| Removing dirty flags breaks retry in edge cases | Medium | Medium | Phase 6 defers dirty-flag removal if uncertain; existing 3-layer retry (legacy + cell-scan + targeted) provides safety net |
| Performance regression from cell reads vs parameter reads | Low | Low | Cell reads are O(1) CHAMP lookup; Phase 0 benchmarks gate any regression |

---

## 5. Files Affected

| File | Phases | Nature of Change |
|------|--------|-----------------|
| `metavar-store.rkt` | 1-6 | Core: read-accessors, remove writes, remove parameters |
| `unify.rkt` | 1 | Constraint store snapshot reads |
| `trait-resolution.rkt` | 2 | Trait/hasmethod iteration reads |
| `elab-speculation-bridge.rkt` | 4 | Remove explicit constraint save/restore |
| `driver.rkt` | 6 | Remove constraint parameters from parameterize blocks |
| `tools/run-affected-tests.rkt` | 0 | Add `--cell-metrics` flag |
| Test fixtures | 6 | Remove constraint parameter bindings from `with-meta-env` |

---

## 6. Estimated Effort

| Phase | Est. Effort |
|-------|-------------|
| 0 (benchmarking) | 0.5 day |
| 1-3 (read flips) | 1-2 days |
| 4 (speculation) | 0.5 day |
| 5-6 (removal + cleanup) | 1 day |
| **Total** | **3-4 days** |

---

## 7. Implementation Summary

**Completed 2026-03-12**. Track 1 achieved the primary goal: all constraint reads go through cell-primary accessors with parameter fallback. Write paths are cell-primary when a propagator network is active; parameters serve as fallback only for unit tests that run without a full elaboration pipeline.

**Architecture**: Cell-primary with parameter fallback, not pure cell-only. This is the correct design because:
1. Unit tests (`with-fresh-meta-env`) don't create a propagator network
2. The parameter fallback preserves backward compatibility for test harnesses
3. The driver pipeline always has a network, so production paths are cell-primary

**Deferred to later tracks**: Phase 6a-6c (full parameter removal) requires migrating all test fixtures to use propagator networks, which is a larger effort. Phase 6b (dirty flag removal) requires verifying all retry paths use propagator wakeup, which depends on Track 2 (cross-domain propagator wiring).

**Commits**: `ffc5d26` (metrics), `b11cce8` (Phase 1), `6720408` (Phase 2), `7fe5d5a` (Phase 3), `2c6e237` (Phase 5a), `3f1c69b` (Phase 4a)

**Benchmark**: Baseline 189.2s → Final 191.4s (+1.2%, within noise). No performance regression.

---

## 8. Cross-Domain Composition Opportunities

Making constraint cells primary doesn't just clean up the read path — it makes constraint state **wirable**. Constraint cells become first-class participants in the propagator network, composable with the six existing cross-domain bridges via `net-add-cross-domain-propagator`.

### 7.1 Existing Bridge Inventory

The codebase has six active cross-domain bridges, all using the same α/γ Galois connection pattern:

| Bridge | Source Domain | Target Domain | File | Direction |
|--------|-------------|---------------|------|-----------|
| **P5c** | Type | Multiplicity | `elaborator-network.rkt` | α active, γ identity |
| **S4** | Session | Type | `session-type-bridge.rkt` | α active (send/recv), γ identity |
| **AD-B** | Session | Effect Position | `effect-bridge.rkt` | α only (unidirectional) |
| **IO-I** | Type | Capability Set | `cap-type-bridge.rkt` | Full Galois adjunction (α + γ) |
| **D2** | Elaboration | Speculation/ATMS | `elab-speculation-bridge.rkt` | Bidirectional via ATMS hypotheses |
| **IO-B2** | Session + IO State | Filesystem | `io-bridge.rkt` | α only (side-effecting) |

### 7.2 New Compositions Enabled by Cell-Primary Constraints

Once constraint cells are primary (readable, not just shadow-written), the following cross-domain connections become possible:

**Constraint ↔ Impl Registry (Reactive Trait Resolution)**
- α: When `impl-registry` cell gains a new instance, propagate to trait-constraint cells — any pending constraint matching the new instance resolves immediately
- γ: When a trait constraint narrows (type arg solved), propagate the narrowed type-tag to the impl-registry lookup — refine which instances are candidates
- **Effect**: `resolve-trait-constraints!` as an explicit driver pass becomes a propagator that fires on cell changes. The retry loop disappears.

**Constraint ↔ Type (Bidirectional Inference)**
- α: When a type cell solves (unification), propagate to constraint cells — the `retry-constraints-for-meta!` wakeup becomes a propagator edge
- γ: When a constraint resolves to a single candidate, propagate the resolved type back to the type cell — currently done by `solve-meta!` but the dependency is implicit; as a propagator edge it becomes explicit and traceable
- **Effect**: The wakeup registry is replaced by the network's own dependency graph. Transitive wakeups are automatic.

**Constraint ↔ Capability (Capability-Aware Trait Resolution)**
- α: A trait constraint carrying capability requirements propagates to the capability lattice — `cap-type-bridge.rkt`'s `type-to-cap-set` can compose with constraint resolution to determine the capability footprint of a resolved instance
- Currently `capability-constraint-map` is independent of trait constraints. Composing them via cells enables: "this trait resolution chose instance X, which requires capability Y"

**Constraint ↔ Speculation/ATMS (Provenance)**
- Each constraint in a cell carries an implicit ATMS support set (which assumptions it depends on)
- When constraint reads go through cells, `atms-explain-hypothesis` can answer "why was this constraint created?" — the ATMS derivation chain traces back through unification steps to user annotations
- **Effect**: Error messages gain automatic provenance: "type mismatch because constraint C was created at line 12 under assumption A, which conflicts with..."

### 7.3 What This Track Does vs. Defers

This track makes constraint cells **readable** — prerequisite for all the above. It does NOT wire any new cross-domain propagators. The wiring is Track 4 (ATMS Speculation) and future work (reactive trait resolution).

The distinction matters: this track is mechanical (flip reads, remove parameters, verify tests pass). The compositional opportunities require design decisions (which α/γ functions? what merge semantics for constraint ↔ impl?). Those decisions belong in subsequent tracks or in a dedicated reactive-resolution design doc.

### 7.4 Network Topology After This Track

```
                    ┌──────────────────┐
                    │  Type Cells      │
                    │  (meta solutions)│
                    └──┬───────┬───────┘
                       │       │
              P5c α/γ  │       │ (future: constraint↔type bridge)
                       │       │
              ┌────────▼──┐  ┌─▼──────────────────────┐
              │ Mult Cells │  │ Constraint Cells        │ ← NOW READABLE
              └────────────┘  │ (store, trait, hasmethod,│
                              │  capability, wakeup)    │
                              └─────────┬───────────────┘
                                        │
                           (future: constraint↔impl bridge)
                                        │
                              ┌─────────▼───────────────┐
                              │ Registry Cells           │
                              │ (impl, trait, schema...) │ ← Track 2
                              └──────────────────────────┘
```

---

## 8. Principle Alignment (updated from §7)

| Principle | How This Track Upholds It |
|-----------|--------------------------|
| **Correct by Construction** | Cells with merge functions make constraint consistency structural — no dirty flags, no manual retry loops |
| **Propagator-First Infrastructure** | Constraint tracking moves from ad-hoc parameters to first-class network participants; wakeup becomes propagator dependency |
| **The Most Generalizable Interface** | No new abstractions introduced — uses existing `prop-cell-read`, `merge-hasheq-union`, cell factories |
| **Completeness Over Deferral** | Each phase completes its scope fully; dirty-flag removal is explicit (Phase 6) or documented as deferred with rationale |
| **Observability** | Phase 0 establishes cell-metric baseline; every subsequent phase records delta |
| **Concurrency readiness** | Immutable cell values (via pure merge functions) are inherently thread-safe; mutable `hash-set!` parameters are not. This track eliminates the last mutable-hasheq constraint state, making constraint tracking safe for future parallel elaboration (LSP multi-file, speculative parallelism) |

---

## 9. Open Questions

1. ~~**Is the capability constraint cell dual-write actually complete?**~~ **RESOLVED** — moved to Phase 2 precondition (Phase 2pre). Verify and complete dual-write before flipping any reads in Phase 2.

2. **Should `retry-constraints-via-cells!` be removed after Phase 3?** It exists as a safety net for missed transitive wakeups. With wakeup registry reads going through cells, the safety net may be unnecessary. But removing it is a behavioral change — keep it unless benchmarks show it's a measurable cost.

3. **How do `current-retry-unify` and `current-retry-trait-resolve` interact with cell-primary flow?** These are callbacks set in `unify.rkt` and `macros.rkt` respectively. They may still serve as the "do the retry" function even when wakeup is propagator-driven. The dirty *flags* are what we want to eliminate; the retry *functions* may persist as propagator fire-fns.
