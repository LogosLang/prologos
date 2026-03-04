# Logic Engine Subsystem Migration Plan

**Date**: 2026-03-03
**Status**: PLANNING
**Source**: `docs/tracking/2026-03-03_LE_SUBSYSTEM_AUDIT.md` (Priority 1-5 subsystems)
**Pattern**: Replicates the proven migration methodology from
`docs/tracking/2026-02-26_TYPE_INFERENCE_IMPLEMENTATION.md` (baseline -> shadow -> switchover -> PIR)

---

## Table of Contents

- [1. Executive Summary](#1-executive-summary)
- [2. Migration Methodology](#2-migration-methodology)
- [3. Current State Assessment](#3-current-state-assessment)
- [4. Priority 1: Type Inference + Unification (Completion)](#4-priority-1)
- [5. Priority 2: Session Types on Propagator Network](#5-priority-2)
- [6. Priority 3: Trait Resolution as Propagators](#6-priority-3)
- [7. Priority 4: Test Dependency Propagation](#7-priority-4)
- [8. Priority 5: QTT Multiplicity Migration](#8-priority-5)
- [9. Cross-Cutting: Benchmarking Strategy](#9-benchmarking)
- [10. Dependency Graph](#10-dependency-graph)
- [11. Progress Tracker](#11-progress-tracker)

---

<a id="1-executive-summary"></a>

## 1. Executive Summary

This document tracks the migration of five subsystems to the Prologos propagator network
infrastructure (`propagator.rkt`). The migration follows a proven four-stage methodology:
**Baseline -> Shadow Validation -> Switchover -> Post-Implementation Review (PIR)**.

The type inference migration (Priority 1) demonstrated this pattern achieves 56-62% speedup
with zero API-breaking changes (commit history: Phases 0-8, documented in
`2026-02-26_TYPE_INFERENCE_IMPLEMENTATION.md` and `2026-02-26_1200_TYPE_INFERENCE_PIR.md`).

### Priority Matrix

| # | Subsystem | Current State | Target State | Value | Status |
|---|-----------|---------------|--------------|-------|--------|
| 1 | Type Inference + Unification | CHAMP-backed (Phases 8+A-E2) | Full propagator unification | Very High | **MOSTLY COMPLETE** |
| 2 | Session Types | AST + typing rules only | Built on propagator from day one | High | NOT STARTED |
| 3 | Trait Resolution | Wakeup callbacks (Phase C) | Propagator-based resolution | Medium | PARTIAL |
| 4 | Test Dependencies | Static `dep-graph.rkt` | Dynamic dependency propagation | Medium | NOT STARTED |
| 5 | QTT Multiplicities | CHAMP metas (Phase B) | Multiplicity propagators | Low-Medium | PARTIAL |

### Key Metrics from Type Inference Migration (Reference)

| Metric | Before | After | Delta |
|--------|--------|-------|-------|
| Speculation save/restore | O(n) hash copy | O(1) CHAMP ref | **Primary win** |
| Wall time (10 benchmarks) | 97-4460ms | 38-1946ms | **56-62% improvement** |
| Test suite wall time | 200.4s | 189.4s | -5.5% |
| Test regressions | — | 0 | Zero breakage |
| Consumer files changed | — | 0 of 13 | Zero disruption |

---

<a id="2-migration-methodology"></a>

## 2. Migration Methodology

Each priority subsystem follows the same four-stage process, adapted from the type inference
migration. The stages are designed so each is independently deployable and revertable.

### Stage 1: Benchmark Baseline

1. **Capture current performance** using existing infrastructure:
   - `racket tools/benchmark-tests.rkt --report` for wall time per test file
   - `racket tools/bench-ab.rkt` for targeted A/B comparisons (10 programs x 15 runs)
   - Record to `data/benchmarks/baseline-<subsystem>.jsonl`
2. **Identify subsystem-specific metrics** (heartbeats, call counts, phase timing)
3. **Capture baseline HTML report** → `data/benchmarks/<subsystem>-baseline-report.html`
4. **Commit baseline**: Immutable reference point for all future comparisons

### Stage 2: Shadow Validation

1. **Mirror operations** to a parallel propagator network without affecting behavior
2. **Validate equivalence**: Shadow network produces same results as production path
3. **Measure overhead**: Shadow adds X% — acceptable if < 5% for temporary validation
4. **Run full test suite** under shadow mode — zero mismatches required
5. **Advisory only**: Mismatches log to stderr, never affect program behavior

### Stage 3: Switchover

1. **Propagator network becomes primary** data path
2. **Legacy path retained** for backward compatibility (dual-write if needed)
3. **Run full benchmark suite**: Compare against Stage 1 baseline
4. **Remove legacy path** once confidence is established
5. **Commit switchover**: New performance baseline

### Stage 4: Post-Implementation Review (PIR)

1. **Gap analysis**: Objectives vs. outcomes
2. **Performance analysis**: Benchmark comparison with statistical rigor
3. **Error reporting quality**: Did diagnostics improve?
4. **Lessons learned**: Technical, process, architectural
5. **Transfer opportunities**: What patterns apply to the next migration?
6. **Write PIR document** → `docs/tracking/YYYY-MM-DD_<SUBSYSTEM>_PIR.md`

### Benchmarking at Each Stage

| Stage | Benchmark Action | Output |
|-------|-----------------|--------|
| Baseline | Full suite + targeted A/B | `baseline-<sub>.jsonl` |
| Shadow | Full suite (measure overhead) | overhead measurement |
| Switchover | Full suite + targeted A/B | `switchover-<sub>.jsonl` |
| PIR | Compare baseline vs switchover | PIR document with analysis |

---

<a id="3-current-state-assessment"></a>

## 3. Current State Assessment

### 3.1 What's Already on the Propagator Network

| Component | File | Status | Lattice |
|-----------|------|--------|---------|
| Capability inference | `capability-inference.rkt` | PRODUCTION | CapabilitySet (powerset) |
| Cap <-> Type bridge | `cap-type-bridge.rkt` | PRODUCTION | Galois connection |
| Type inference (meta store) | `metavar-store.rkt` + `elaborator-network.rkt` | PRODUCTION (CHAMP primary) | Type (bot/concrete/top) |
| Speculation (save/restore) | `elab-speculation.rkt` + bridge | PRODUCTION (O(1) via CHAMP) | — |
| ATMS provenance | `atms.rkt` | PRODUCTION (not in error pipeline) | — |
| Tabling | `tabling.rkt` | PRODUCTION | Set (answer merge) |
| Union-find | `union-find.rkt` | PRODUCTION | — |
| Level/mult/session metas | `metavar-store.rkt` | PRODUCTION (CHAMP Phase B) | Flat |

### 3.2 What's NOT on the Propagator Network

| Component | File(s) | Call Sites | Migration Target |
|-----------|---------|------------|------------------|
| Unification (imperative) | `unify.rkt` (~600 LOC) | 201+ | Priority 1 (E3+) |
| Trait resolution | `trait-resolution.rkt` (~1000 LOC) | 24 call sites in driver | Priority 3 |
| Test dependencies | `tools/dep-graph.rkt` (~200 LOC) | Static hash | Priority 4 |
| QTT multiplicity checking | `qtt.rkt` (~800 LOC) | Imperative context threading | Priority 5 |
| Session type checking | `typing-sessions.rkt` (~258 LOC) | 9 typing rules | Priority 2 (new build) |

### 3.3 Existing Infrastructure to Leverage

| Infrastructure | File | Used By |
|----------------|------|---------|
| Propagator network (CHAMP-backed) | `propagator.rkt` (763 LOC) | All migrations |
| Elaboration network wrapper | `elaborator-network.rkt` (180 LOC) | P1, P3, P5 |
| Type lattice (merge, contradicts) | `type-lattice.rkt` (404 LOC) | P1, P2, P3 |
| ATMS (assumptions, nogoods) | `atms.rkt` (280 LOC) | P1, P2, P3 (errors) |
| Speculation (fork/commit) | `elab-speculation.rkt` (155 LOC) | P1, P3 |
| Speculation bridge | `elab-speculation-bridge.rkt` (80 LOC) | P1 |
| A/B benchmark harness | `tools/bench-ab.rkt` | All PIRs |
| Timing infrastructure | `bench-lib.rkt`, `timings.jsonl` | All benchmarks |
| CI regression check | `tools/ci-regression-check.rkt` | All |

---

<a id="4-priority-1"></a>

## 4. Priority 1: Type Inference + Unification (Completion)

### 4.0 What's Already Done

The type inference migration is **mostly complete**. Phases 0-8 and A-E2 delivered:
- CHAMP-backed metavar store (O(1) save/restore)
- Type lattice module (`type-lattice.rkt`)
- Elaboration network (`elaborator-network.rkt`)
- Shadow validation framework (built and then removed after proving equivalence)
- Speculation bridge (`with-speculative-rollback`)
- ATMS-backed speculation
- Always-on propagator network
- Full switchover (56-62% improvement)
- E1006 union exhaustion errors with per-branch detail
- Level/mult/session metas on CHAMP (Phase B)
- Incremental trait resolution via wakeup callbacks (Phase C)
- ATMS derivation chains in error messages (Phases D1-D4)
- Pure unification with read-only callback (Phase E1)
- Propagator-driven constraint wakeup (Phase E2)
- Hash removal — CHAMP as sole source of truth

**See**: `docs/tracking/2026-02-26_TYPE_INFERENCE_IMPLEMENTATION.md` (full history)
**PIR**: `docs/tracking/2026-02-26_1200_TYPE_INFERENCE_PIR.md`

### 4.1 Remaining Work

#### P1-E3: Constraint-Retry Propagators

**Status**: DEFERRED (re-entrancy risk)
**What**: Move full constraint retry into propagator fire functions. Currently, Phase E2's
legacy retry path handles this safely via `solve-meta!` → `run-to-quiescence`.

**Risk**: Fire functions that create new constraints (side-effectful propagators) introduce
re-entrancy: a propagator firing during quiescence adds a new propagator, potentially
invalidating the worklist. The current sequential Gauss-Seidel scheduler handles this
correctly (new propagators are appended to the worklist), but the BSP scheduler would
need modification.

**Approach**:
- [ ] P1-E3a: Audit all constraint-retry patterns in `typing-core.rkt`
- [ ] P1-E3b: Categorize: which retries can be pure propagators vs side-effectful
- [ ] P1-E3c: Implement pure constraint-retry propagators for the safe subset
- [ ] P1-E3d: Test coverage for re-entrancy edge cases
- [ ] P1-E3e: Benchmark — confirm no regression from propagator overhead

**Benchmark plan**:
- Baseline: Current E2 performance (already captured)
- Target: Neutral or slight improvement (constraint retry is not a hot path)
- Metric: `constraint-retry-count` heartbeat, wall time on implicit-heavy programs

#### P1-F: Hash Backward Compatibility Elimination

**Status**: COMPLETE (Phase A of elaborator refactoring)
**Note**: Dual-write hash was eliminated during Phase A. CHAMP is sole source of truth.
~20 test files migrated to `with-fresh-meta-env`.

#### P1-G: Unification as Pure Propagators (Long-Term)

**Status**: NOT STARTED
**Value**: Eliminates the imperative `unify` call graph (201+ sites). Unification becomes
declarative: "these two cells must agree" rather than "solve this meta now."

**Approach** (from PIR §8.5):
- [ ] P1-G1: Design propagator-based unification API (preserving three-valued returns)
- [ ] P1-G2: Implement `unify-propagator` for structural terms (no metas)
- [ ] P1-G3: Implement `unify-propagator` for meta-bearing terms
- [ ] P1-G4: Shadow validation — run both imperative and propagator unification in parallel
- [ ] P1-G5: Benchmark — targeted A/B on unification-heavy programs
- [ ] P1-G6: Switchover — propagator unification as primary
- [ ] P1-G7: Remove imperative unification code
- [ ] P1-G8: PIR

**Benchmark plan**:
- Baseline: Current E2 performance
- Metrics: `unify-steps` heartbeat, `cell-merge-count`, wall time
- Key programs: `implicit-args.prologos`, `church-fold-nat.prologos`, `dependent.prologos`
- Statistical rigor: 15 runs, Mann-Whitney U, p < 0.05

**Risk**: Very High — unification is the core of the type checker. Must be extremely careful.
**Estimated effort**: 1-2 weeks.
**Dependency**: None (can proceed independently).

---

<a id="5-priority-2"></a>

## 5. Priority 2: Session Types on Propagator Network

### 5.0 Context

Session types should be built ON the propagator network from day one, avoiding the
migration pattern entirely. A separate implementation plan exists at:
`docs/tracking/2026-03-03_SESSION_TYPE_IMPL_PLAN.md`

This section tracks the propagator-specific aspects of that plan.

### 5.1 Session Lattice (Phase S4a from Session Impl Plan)

**New file**: `session-lattice.rkt` (~200 lines)
Modeled after `type-lattice.rkt`.

| Component | Design |
|-----------|--------|
| Sentinels | `session-bot` (no info), `session-top` (contradiction) |
| Merge | Structural: Send+Send merge types+conts; Send+Recv → top |
| Choice merge | Intersect labels (covariant) |
| Offer merge | Union labels (contravariant) |
| Subtyping | Gay & Hole: covariant output, contravariant input |
| Unification | `try-unify-session-pure` — pure structural, no side effects |

**Benchmark plan**:
- Baseline: N/A (new subsystem — no "before" to compare)
- Metrics: Session cell merge count, session propagator firings, quiescence rounds
- Approach: Absolute performance targets, not comparative
- Target: Session type checking of a 10-step protocol in < 5ms

### 5.2 Session Inference Propagators (Phase S4b)

**New file**: `session-propagators.rkt` (~300 lines)

| Propagator | Description |
|------------|-------------|
| `add-send-prop` | Constrain sess-cell to Send(T, S), bridge T to type cell |
| `add-recv-prop` | Constrain sess-cell to Recv(T, S) |
| `add-select-prop` | Constrain to Choice with label |
| `add-offer-prop` | Constrain to Offer, return branch cells |
| `add-stop-prop` | Constrain to End |
| `add-duality-prop` | Bidirectional dual enforcement between channel pairs |

### 5.3 Cross-Domain Bridges (Phase S4e)

| Bridge | Direction | What It Enables |
|--------|-----------|-----------------|
| Session <-> Type | Message types create type-lattice cells | Type inference from protocol |
| Session <-> QTT | Linear channels (:1) constrain multiplicity | Compile-time linearity |
| Session <-> Capability | Boundary ops gate on capabilities | Secure channel opening |

### 5.4 ATMS Integration (Phase S4d)

Each process operation creates an ATMS assumption with source location. Session lattice
contradictions produce derivation chains (minimal conflict sets) for error messages:

```
Protocol violation at line 42:
  Channel self was inferred as (Send String . End) because:
    - self ! "hello"    [line 10, assumption A1]
    - self ! "world"    [line 11, assumption A2]  <-- second send past End
  Minimal conflict: {A1, A2}
```

### 5.5 Benchmarking Strategy for Session Types

Since session types are built fresh (not migrated), we use **absolute benchmarks**
rather than comparative A/B:

| Benchmark Program | What It Measures |
|-------------------|------------------|
| `simple-greeting.prologos` | 2-step protocol: ! String . ? String . end |
| `counter-protocol.prologos` | Recursive protocol with choice (inc/done) |
| `dependent-length.prologos` | Dependent session: ?: n Nat . ? Vec String n |
| `multi-channel.prologos` | 3-party protocol with new/par/link |
| `async-pipeline.prologos` | Async operators !! / ?? / @ |

**Targets** (absolute, not comparative):
- Simple protocol (2 steps): < 2ms
- Recursive protocol (10 steps): < 10ms
- Dependent protocol: < 20ms
- Multi-channel (3 parties): < 30ms

**Recording**: Same JSONL format (`schema_version: 4`), same `bench-ab.rkt` harness.

### 5.6 Progress Tracker

See `docs/tracking/2026-03-03_SESSION_TYPE_IMPL_PLAN.md` for full phase breakdown (S1-S8).
Propagator-specific milestones tracked here:

- [ ] S4a: Session lattice module (`session-lattice.rkt`)
- [ ] S4b: Session inference propagators (`session-propagators.rkt`)
- [ ] S4c: Duality bidirectional propagator
- [ ] S4d: ATMS integration for error derivations
- [ ] S4e: Cross-domain bridges (Session <-> Type, Session <-> QTT)
- [ ] S4f: Deadlock detection via unresolved cells
- [ ] S7a: Channel cells for runtime execution
- [ ] S7b: Process-to-propagator compilation (runtime)

---

<a id="6-priority-3"></a>

## 6. Priority 3: Trait Resolution as Propagators

### 6.0 Current State

Trait resolution is partially migrated:
- **Phase C** (COMPLETE): Incremental trait resolution via wakeup callbacks.
  `solve-meta!` triggers `run-to-quiescence`, which wakes up trait constraints
  watching the solved meta.
- **Current mechanism**: `resolve-trait-constraints!` is a post-inference pass.
  It iterates all unsolved trait metas and attempts resolution only when all type
  arguments are ground (`andmap ground-expr?`).
- **24 call sites** in driver.rkt / expander invoke the post-pass.

### 6.1 Target Architecture

Replace the post-pass with propagator-based resolution:

```
Current (post-pass):
  1. Type-check expression → unsolved trait constraints [Eq ?A, Num ?B]
  2. Solve metas via unification → ?A = Int, ?B = Float
  3. Post-pass: resolve-trait-constraints!
     - Walk all unsolved trait metas
     - For each: check if all args ground → try monomorphic → try parametric
  4. Report E1004 for unresolved

Target (propagator):
  1. Type-check expression → create trait constraint cells
  2. Each trait constraint has a propagator watching its type-argument cells
  3. When a type-argument cell is solved (meta → ground type):
     - Propagator fires automatically
     - Attempts resolution (monomorphic, then parametric)
     - On success: writes dict expression to output cell
     - On failure with all args ground: records ATMS nogood → E1004
  4. No post-pass needed — resolution is incremental
```

### 6.2 Implementation Phases

#### P3-A: Benchmark Baseline

- [ ] P3-A1: Capture trait resolution timing
  - Instrument `resolve-trait-constraints!` with `time-phase 'trait-resolve`
  - Record: number of traits resolved, retry count, wall time per file
- [ ] P3-A2: Capture targeted A/B baselines
  - Programs: `implicit-add.prologos`, `implicit-map.prologos`, `trait-chain.prologos`
  - 15 runs each via `bench-ab.rkt`
- [ ] P3-A3: Record to `data/benchmarks/baseline-trait-resolution.jsonl`
- [ ] P3-A4: Commit baseline

**Heartbeat metrics for trait resolution**:
- `trait-resolve-attempts`: Each `try-monomorphic-resolve` or `try-parametric-resolve` call
- `trait-resolve-successes`: Successful resolutions
- `trait-resolve-retries`: Times a constraint was re-examined after meta solving
- `trait-constraint-count`: Total trait constraints created

#### P3-B: Trait Constraint Cells

- [ ] P3-B1: Define `trait-constraint-cell` type
  - Value domain: `unsolved` | `resolved(dict-expr)` | `contradiction`
  - Merge: `unsolved ⊔ resolved(d) = resolved(d)`, `resolved(d1) ⊔ resolved(d2) = d1 if d1=d2, top otherwise`
- [ ] P3-B2: Create cells for each trait constraint during type-checking
  - When `add-constraint!` is called with a trait constraint, also create a prop-cell
  - Wire propagator watching the trait's type-argument cells
- [ ] P3-B3: Tests: 10-15 tests for trait constraint cell creation and merge

#### P3-C: Resolution Propagator

- [ ] P3-C1: Implement `make-trait-resolution-propagator`
  - Inputs: type-argument cells (from elaboration network)
  - Output: trait dict cell
  - Fire function:
    1. Read all type-argument cells
    2. If any is `type-bot` → no-op (wait for more info)
    3. If all ground → attempt resolution (monomorphic, then parametric)
    4. On success → write `resolved(dict-expr)` to output cell
    5. On failure → write contradiction + ATMS nogood
- [ ] P3-C2: Wire into `add-constraint!` path
  - When trait constraint is added, create propagator
  - Propagator is automatically scheduled when input cells change
- [ ] P3-C3: Tests: 15-20 tests covering monomorphic, parametric, chain depth

#### P3-D: Shadow Validation

- [ ] P3-D1: Run both post-pass and propagator resolution in parallel
  - Post-pass result is authoritative
  - Log mismatches between post-pass and propagator results
- [ ] P3-D2: Run full test suite under shadow mode
  - Target: zero mismatches across all 4632+ tests
- [ ] P3-D3: Measure overhead of shadow validation (target: < 5%)

#### P3-E: Switchover

- [ ] P3-E1: Propagator resolution becomes primary
  - Remove `resolve-trait-constraints!` post-pass
  - Remove the 24 call sites in driver.rkt
- [ ] P3-E2: Retain post-pass as fallback (conditional, behind parameter)
- [ ] P3-E3: Run full benchmark suite → compare against P3-A baseline
- [ ] P3-E4: Remove fallback path once confidence established

#### P3-F: PIR

- [ ] P3-F1: Write PIR document at `docs/tracking/YYYY-MM-DD_TRAIT_RESOLUTION_PIR.md`
  - Gap analysis, performance comparison, lessons learned
  - Transfer opportunities for Priority 4 and 5

### 6.3 Benchmarking Plan

**Baseline** (P3-A):
| Program | Metric | Expected Range |
|---------|--------|----------------|
| `implicit-add.prologos` | Wall time, trait-resolve-attempts | ~33ms, ~5 attempts |
| `implicit-map.prologos` | Wall time, trait-resolve-attempts | ~54ms, ~12 attempts |
| `trait-chain.prologos` | Wall time, chain depth | TBD |
| `prelude-boot.prologos` | Wall time, total constraints | ~1946ms, ~200 constraints |

**Expected improvement**: Modest (5-15%). The main benefit is architectural (no post-pass),
not performance. Trait resolution is not a hot path compared to unification/speculation.

**Risk assessment**: Medium. Ordering interaction with constraint postponement system needs
careful analysis — traits currently resolve after ALL type-checking is complete.

### 6.4 Key Risk: Resolution Ordering

The post-pass resolves traits after all metas that CAN be solved ARE solved. Moving
resolution earlier (as propagators fire) means some metas may not yet be solved when
the propagator fires. The propagator must handle this gracefully:

- **Safe case**: All type args ground → resolve immediately
- **Partial case**: Some type args still `type-bot` → do nothing, wait for more info
- **Ambiguous case**: Args ground but resolution is ambiguous → ATMS branching

The Phase C wakeup callbacks already handle the safe and partial cases. The propagator
formalization makes this explicit rather than implicit.

---

<a id="7-priority-4"></a>

## 7. Priority 4: Test Dependency Propagation

### 7.0 Current State — COMPLETE

**UPDATE (2026-03-03)**: P4 is COMPLETE. The original assessment below was inaccurate.
`dep-graph.rkt` is ~1682 lines (not ~200), already had auto-scan functions, BFS transitive
closure, reverse-dep precomputation, and 4-layer dependency tracking. The only gap was
`--write` mode in `update-deps.rkt`, which has now been implemented (commit `ec10d77`).

**What was done**: Implemented `run-write` in `update-deps.rkt` to auto-generate
dep-graph.rkt data from actual `require` chains on disk. Fixed 301 stale dependencies.
`--check` now reports 0 mismatches. Full suite (5056 tests) passes with zero regressions.

**Original assessment (for historical context)**:
Test dependencies were managed by a **static hash table** in `tools/dep-graph.rkt`.
Manual entries map test files to source files. When a source file changes,
`run-affected-tests.rkt` looks up all test files that depend on it and runs them.

**Problems (original — now resolved)**:
1. ~~Manual maintenance — new files require manual `dep-graph.rkt` entries~~
   → Solved: `--write` auto-generates from disk
2. ~~No transitive dependencies~~ → Already had BFS transitive closure
3. ~~No dynamic discovery~~ → Already had auto-scan; now `--write` keeps data fresh
4. Overly conservative — partially addressed (auto-discovered deps are more precise)

### 7.1 Target Architecture

Replace static hash with a propagator network:

```
Source file cells:                    Test file cells:
  [syntax.rkt] ──────────┐         ┌── [test-nat.rkt]        = pass/fail/unknown
  [typing-core.rkt] ──┐  │         │   [test-string.rkt]     = pass/fail/unknown
  [elaborator.rkt] ─┐ │  │         │   [test-elaborator.rkt] = pass/fail/unknown
                     │ │  │         │
                     v v  v         v
                  Dependency Propagators
                  (source change → test invalidation)
```

- Each source file is a cell (value = content hash)
- Each test file is a cell (value = `pass` | `fail` | `unknown`)
- Propagators encode dependencies: when source cell changes, dependent test cells
  are invalidated (set to `unknown`)
- `run-to-quiescence` identifies exactly which tests need re-running

### 7.2 Implementation Phases

#### P4-A: Dynamic Dependency Discovery

- [ ] P4-A1: Parse `require` chains from Racket source files
  - Walk `(require "foo.rkt")` forms to build actual dependency graph
  - Handle transitive requires
- [ ] P4-A2: Parse `.prologos` `import` / `ns` to discover stdlib dependencies
- [ ] P4-A3: Build dynamic dependency map
  - Compare with static `dep-graph.rkt` — flag missing and spurious entries
- [ ] P4-A4: Tests: Validate dynamic discovery matches manual graph

#### P4-B: Propagator Network for Dependencies

- [ ] P4-B1: Create source cells (content hash per file)
- [ ] P4-B2: Create test cells (pass/fail/unknown)
- [ ] P4-B3: Create dependency propagators (source change → test invalidation)
- [ ] P4-B4: `run-to-quiescence` → set of tests in `unknown` state
- [ ] P4-B5: Tests: Basic invalidation scenarios

#### P4-C: Integration with Test Runner

- [ ] P4-C1: Replace `dep-graph.rkt` lookup with propagator network query
- [ ] P4-C2: Retain `dep-graph.rkt` as fallback (behind parameter)
- [ ] P4-C3: Validate: same or fewer tests selected (never more, unless dependency was missing)
- [ ] P4-C4: Benchmark: Time to compute affected set (target: < 100ms)

#### P4-D: Transitive Invalidation

- [ ] P4-D1: Multi-hop propagation (A depends on B depends on C; changing C invalidates A)
- [ ] P4-D2: Smart invalidation for broad dependencies
  - `syntax.rkt` changes should NOT trigger all tests if only a specific struct was modified
  - Content-hash + export-set comparison for fine-grained invalidation
- [ ] P4-D3: Tests: Transitive scenarios

#### P4-E: Cleanup

- [ ] P4-E1: Remove static `dep-graph.rkt` once dynamic approach is proven
- [ ] P4-E2: Update `tools/update-deps.rkt` to work with propagator network
- [ ] P4-E3: Document new approach

### 7.3 Benchmarking Plan

**This migration is NOT about performance improvement** — it's about correctness and
maintenance reduction. Benchmarks measure:

| Metric | Current (static) | Target (dynamic) |
|--------|------------------|-------------------|
| Dependency computation time | ~instant (hash lookup) | < 100ms (propagation) |
| False positives (unnecessary test runs) | High (syntax.rkt → all) | Lower (fine-grained) |
| False negatives (missed tests) | Unknown (manual errors) | Zero (automatic discovery) |
| Manual maintenance burden | High (edit dep-graph.rkt) | Zero (automatic) |

**Key benchmark**: How many tests does a typical single-file change trigger?
- Current: Often 50-100+ (due to broad static dependencies)
- Target: 5-20 (only actually-dependent tests)

### 7.4 Risk Assessment

**Low risk**. Test dependency management is peripheral to the compiler. Failures are
caught immediately (tests that should have run didn't → manual full-suite run catches it).
The static `dep-graph.rkt` can always be used as fallback.

---

<a id="8-priority-5"></a>

## 8. Priority 5: QTT Multiplicity Migration

### 8.0 Current State

QTT multiplicity checking (`qtt.rkt`, ~800 lines) uses imperative context threading:
- `UsageCtx`: List of multiplicities parallel to typing context
- `inferQ`/`checkQ`: Track multiplicities imperatively during type inference
- Level/mult/session metas: Already on CHAMP (Phase B)

The multiplicity lattice is tiny: `m0 < m1 < mw` (3 elements).

### 8.1 Target Architecture

Each variable's multiplicity becomes a cell in the elaboration network:

```
Variable    Current                     Target
─────────────────────────────────────────────────────
x : Nat :1  UsageCtx entry [1]          Cell(x-mult) = m1
y : Bool :w UsageCtx entry [w]          Cell(y-mult) = mw
z : Int :0  UsageCtx entry [0]          Cell(z-mult) = m0
```

Usage propagators accumulate actual usage:
- Each use of `x` writes `m1` to `Cell(x-mult)` (merge: max)
- Final check: `Cell(x-mult) <= declared-mult(x)`
- Contradiction: used at `mw` but declared `:1`

### 8.2 Cross-Domain Bridge: Type <-> Multiplicity

A Galois connection between type and multiplicity domains:
- alpha: `type -> mult` — if type is linear (session endpoint), mult must be `:1`
- gamma: `mult -> type constraint` — if mult is `:0`, value cannot be used at runtime

This enables **linear type inference**: declaring a channel as `[c : Session]` automatically
constrains `c`'s multiplicity to `:1` without explicit annotation.

### 8.3 Implementation Phases

#### P5-A: Benchmark Baseline

- [ ] P5-A1: Instrument QTT checking with heartbeats
  - `qtt-check-steps`: Each `checkQ`/`inferQ` call
  - `qtt-usage-updates`: Each usage context update
- [ ] P5-A2: Capture baseline on programs with linear types
- [ ] P5-A3: Record to `data/benchmarks/baseline-qtt.jsonl`

#### P5-B: Multiplicity Cells

- [ ] P5-B1: Define multiplicity lattice
  - `mult-bot` (no info) < `m0` < `m1` < `mw` < `mult-top` (contradiction)
  - Merge: `max` in the lattice ordering
  - Note: Need to decide if `m0` and `m1` are incomparable (join = `mw`) or ordered
- [ ] P5-B2: Create multiplicity cells in elaboration network
  - One cell per variable binding
  - Initialized to `mult-bot`
- [ ] P5-B3: Tests: Multiplicity lattice merge properties

#### P5-C: Usage Propagators

- [ ] P5-C1: Each variable reference creates a usage propagator
  - Writes observed multiplicity to the variable's mult cell
- [ ] P5-C2: Declaration constraint propagator
  - Watches mult cell, compares against declared multiplicity
  - Contradiction if inferred usage exceeds declaration
- [ ] P5-C3: Tests: Basic linear usage, erased usage, unrestricted usage

#### P5-D: Cross-Domain Bridge

- [ ] P5-D1: Type <-> Multiplicity Galois connection
  - Session type → `:1` multiplicity
  - `:0` multiplicity → erased at runtime
- [ ] P5-D2: Wire into elaboration network
- [ ] P5-D3: Tests: Linear session endpoints, erased type parameters

#### P5-E: Shadow Validation + Switchover

- [ ] P5-E1: Shadow validate against current `checkQ`/`inferQ`
- [ ] P5-E2: Switchover to propagator-based QTT
- [ ] P5-E3: Benchmark comparison against P5-A baseline

#### P5-F: PIR

- [ ] P5-F1: Write PIR document

### 8.4 Benchmarking Plan

| Metric | Current | Expected After |
|--------|---------|----------------|
| QTT check wall time | ~2% of total | ~2% (no significant change) |
| Linear type errors | Post-pass detection | Incremental (during type-check) |
| Cross-domain inference | Manual annotation | Automatic from session types |

**Expected improvement**: Minimal performance change. The multiplicity lattice is too small
(3 elements) for propagation to provide speedup. The value is architectural:
- Unified infrastructure (all metas on same network)
- Cross-domain bridges enable linear type inference from session types
- Foundation for future linear logic features

### 8.5 Risk Assessment

**Low risk**. QTT checking is well-isolated (800 lines, clear API). The multiplicity
lattice is trivial. Migration is straightforward once type inference migration is complete.

**Dependency**: Should be done AFTER Priority 1 completion (shares elaboration network).

---

<a id="9-benchmarking"></a>

## 9. Cross-Cutting: Benchmarking Strategy

### 9.1 Existing Infrastructure

| Component | File | Status |
|-----------|------|--------|
| Subprocess timing | `bench-lib.rkt` | PRODUCTION |
| Parallel benchmark execution | `benchmark-tests.rkt` | PRODUCTION |
| JSONL recording | `data/benchmarks/timings.jsonl` | PRODUCTION |
| A/B comparison | `bench-ab.rkt` | PRODUCTION |
| CI regression check | `tools/ci-regression-check.rkt` | PRODUCTION |
| Static HTML report | `data/benchmarks/baseline-report.html` | EXISTS |

### 9.2 Infrastructure Gaps (from Benchmarking Framework Design)

| Gap | Priority | Blocked By |
|-----|----------|------------|
| ~~Heartbeat counters (`performance-counters.rkt`)~~ | ~~P0~~ | **COMPLETE** — 12 counters wired into production |
| ~~Phase-level timing in driver~~ | ~~P0~~ | **COMPLETE** — 7 phases in driver.rkt |
| Micro-benchmark harness | P1 | Nothing |
| Multi-run statistical baseline (rolling median) | P1 | Nothing |
| Memory profiling (peak RSS, GC) | P1 | Nothing |
| Property-based testing (rackcheck) | P2 | Generator design |

**Note**: Heartbeat counters and phase-level timing were discovered to be already complete
in `performance-counters.rkt` (12 counters across 7 modules, all wired into production code).
This was listed as NOT STARTED but is in fact COMPLETE.

### 9.3 Per-Migration Benchmark Artifacts

Each migration produces:

```
data/benchmarks/
  baseline-<subsystem>.jsonl          # Stage 1 capture
  baseline-<subsystem>-report.html    # Stage 1 HTML
  shadow-<subsystem>.jsonl            # Stage 2 overhead measurement
  switchover-<subsystem>.jsonl        # Stage 3 comparison
  pir-<subsystem>-report.html         # Stage 4 final analysis
```

### 9.4 Unified Benchmark Suite

Programs used across all migrations (from Type Inference PIR §3.1):

| Program | What It Stresses |
|---------|------------------|
| `bid-nat-bool.prologos` | Basic inference, simple types |
| `bid-identity.prologos` | Polymorphic identity, implicit args |
| `bid-if-match.prologos` | Pattern matching, control flow |
| `prelude-boot.prologos` | Full prelude loading (~500 defs) |
| `implicit-add.prologos` | Trait resolution, implicit dicts |
| `implicit-map.prologos` | Higher-order trait usage |
| `church-fold-nat.prologos` | Speculative type-checking |
| `union-check-3.prologos` | Union type inference |
| `union-check-nested.prologos` | Nested union handling |
| `map-literal.prologos` | Map/schema inference |

Future additions for session types and QTT:

| Program | What It Stresses |
|---------|------------------|
| `simple-greeting.prologos` | Basic session protocol |
| `counter-protocol.prologos` | Recursive session with choice |
| `linear-channel.prologos` | QTT linear resource tracking |
| `multi-party.prologos` | Multi-channel session |

### 9.5 Statistical Methodology

From the Type Inference PIR and Benchmarking Framework Design:

- **Runs per comparison**: 15 (minimum for statistical power)
- **Statistical test**: Mann-Whitney U (non-parametric, no normality assumption)
- **Significance threshold**: p < 0.05
- **Effect size gating**: Require BOTH >15% relative change AND >500ms absolute change
- **Variance flagging**: CV > 15% triggers investigation
- **Regression threshold**: 15% (CI gate)

---

<a id="10-dependency-graph"></a>

## 10. Dependency Graph

```
                    P1 (Type Inference Completion)
                    [Phases E3, G — mostly done]
                              |
                    +---------+---------+
                    |                   |
              P3 (Trait Resolution)    P5 (QTT Multiplicities)
              [Phases A-F]             [Phases A-F]
                    |                   |
                    +---+---+-----------+
                        |   |
                        v   v
                  P2 (Session Types)
                  [S4a-f: propagator-based]
                  [Cross-domain: Session<->Type, Session<->QTT]
                        |
                        v
                  P4 (Test Dependencies)
                  [Independent — can proceed anytime]
```

**Notes**:
- P1 (completion) is prerequisite for P3 and P5 (they share the elaboration network)
- P2 (session types) benefits from P3 and P5 being done (cross-domain bridges)
  but can proceed independently (builds its own lattice)
- P4 is fully independent — can proceed at any time
- P3 and P5 can proceed in parallel after P1

### Recommended Execution Order (Revised 2026-03-03)

Interleaves session type parsing (no propagator dependency) with infrastructure work:

1. **S1-S2** (session/process parsing) — pure surface syntax, no propagator dependency
2. **P4** (test dependencies) — multiplicative benefit, independent, low risk
3. **S3** (session elaboration) — connects parsing to semantic AST, still no propagator needed
4. **P3** (trait resolution as propagators) — enriches propagator network before S4
5. **S4** (session propagator network) — lands on battle-tested, enriched infra
6. **P5 + S5-S8** (QTT multiplicities, capabilities, runtime, async) — later
7. **P1-E3, P1-G** (constraint-retry, pure unification) — long-term

**Rationale**: S1-S3 cost the same regardless of when they're done. P4 and P3 between
S3 and S4 means the most complex session type work (S4) benefits from both multiplicative
testing improvement AND a more mature propagator ecosystem.

---

<a id="11-progress-tracker"></a>

## 11. Progress Tracker

### Overall Status

| Priority | Subsystem | Status | Phases Done | Phases Remaining |
|----------|-----------|--------|-------------|------------------|
| 1 | Type Inference + Unification | **MOSTLY COMPLETE** | 0-8, A-E2 | E3, G |
| 2 | Session Types | NOT STARTED | — | S4a-f, S7a-b |
| 3 | Trait Resolution | PARTIAL (wakeup callbacks) | — | A-F |
| 4 | Test Dependencies | NOT STARTED | — | A-E |
| 5 | QTT Multiplicities | PARTIAL (CHAMP metas) | — | A-F |

### Benchmarking Infrastructure

| Component | Status |
|-----------|--------|
| Wall-clock timing (`bench-lib.rkt`) | COMPLETE |
| JSONL recording | COMPLETE |
| A/B comparison (`bench-ab.rkt`) | COMPLETE |
| CI regression gate | COMPLETE |
| Heartbeat counters (`performance-counters.rkt`) | **COMPLETE** (12 counters, all wired) |
| Phase-level timing in driver | **COMPLETE** (7 phases in driver.rkt) |
| Micro-benchmark harness | NOT STARTED |
| Multi-run statistical baseline | NOT STARTED |

### Detailed Phase Status

#### Priority 1: Type Inference + Unification
- [x] Phase 0: Benchmarking baseline
- [x] Phase 1: Type lattice module
- [x] Phase 2: Parallel infrastructure (elaborator-network)
- [x] Phase 3: Shadow network validation
- [x] Phase 4: ATMS-backed speculation
- [x] Phase 5: Always-on network + speculation bridge
- [x] Phase 6: Error enrichment (E1006)
- [x] Phase 7: Performance optimization + CI
- [x] Phase 8: Full switchover (56-62% improvement)
- [x] Phase A: CHAMP meta-info store, hash elimination
- [x] Phase B: Level/mult/session metas on CHAMP
- [x] Phase C: Incremental trait resolution (wakeup callbacks)
- [x] Phase D1-D4: ATMS derivation chains in errors
- [x] Phase E1: Meta-aware pure unification
- [x] Phase E2: Propagator-driven constraint wakeup
- [ ] Phase E3: Constraint-retry propagators (DEFERRED)
- [ ] Phase G: Unification as pure propagators (LONG-TERM)

#### Priority 2: Session Types
- [ ] S4a: Session lattice
- [ ] S4b: Session inference propagators
- [ ] S4c: Duality propagator
- [ ] S4d: ATMS integration
- [ ] S4e: Cross-domain bridges
- [ ] S4f: Deadlock detection
- [ ] S7a: Channel cells
- [ ] S7b: Process-to-propagator compilation

#### Priority 3: Trait Resolution
- [ ] P3-A: Benchmark baseline
- [ ] P3-B: Trait constraint cells
- [ ] P3-C: Resolution propagator
- [ ] P3-D: Shadow validation
- [ ] P3-E: Switchover
- [ ] P3-F: PIR

#### Priority 4: Test Dependencies
- [x] P4-A: Dynamic dependency discovery — ALREADY EXISTED (`scan-rkt-requires`, `scan-test-source-deps`, etc.)
- [x] P4-B: `--write` mode in `update-deps.rkt` — auto-generates dep-graph.rkt from disk (commit `ec10d77`)
- [x] P4-C: Auto-sync dep-graph — fixed 301 stale dependencies, `--check` reports 0 mismatches (commit `ec10d77`)
- [x] P4-D: Transitive invalidation — ALREADY EXISTED (`transitive-closure` BFS in dep-graph.rkt)
- [x] P4-E: Integration verified — 5056 tests pass, zero regressions
- NOTE: Propagator network approach SUPERSEDED — existing BFS transitive closure + `--write` auto-sync is sufficient
- KNOWN LIMITATION: Regex scanner under-counts prelude implicit deps for `(ns ...)` tests

#### Priority 5: QTT Multiplicities
- [ ] P5-A: Benchmark baseline
- [ ] P5-B: Multiplicity cells
- [ ] P5-C: Usage propagators
- [ ] P5-D: Cross-domain bridge (Type <-> Multiplicity)
- [ ] P5-E: Shadow validation + switchover
- [ ] P5-F: PIR

---

## Appendix A: Files Referenced

| File | Lines | Role | Priorities |
|------|-------|------|------------|
| `propagator.rkt` | ~763 | Core propagator network | All |
| `elaborator-network.rkt` | ~180 | Type inference bridge | P1, P3, P5 |
| `type-lattice.rkt` | ~404 | Type domain lattice | P1, P2, P3 |
| `atms.rkt` | ~280 | Assumption-based TMS | P1, P2, P3 |
| `elab-speculation.rkt` | ~155 | Speculation framework | P1, P3 |
| `elab-speculation-bridge.rkt` | ~80 | Speculation bridge | P1 |
| `metavar-store.rkt` | ~250 | Meta store (CHAMP-backed) | P1 |
| `unify.rkt` | ~600 | Imperative unification | P1 (target) |
| `typing-core.rkt` | ~3000 | Core type checker | P1, P3 |
| `trait-resolution.rkt` | ~1000 | Trait instance search | P3 (target) |
| `qtt.rkt` | ~800 | Multiplicity checking | P5 (target) |
| `sessions.rkt` | ~117 | Session type AST | P2 |
| `processes.rkt` | ~83 | Process AST | P2 |
| `typing-sessions.rkt` | ~258 | Session typing rules | P2 |
| `tools/dep-graph.rkt` | ~200 | Static test deps | P4 (target) |
| `tools/run-affected-tests.rkt` | ~300 | Test runner | P4 |
| `tools/bench-ab.rkt` | — | A/B comparison | All PIRs |
| `tools/benchmark-tests.rkt` | — | Parallel benchmarks | All |
| `tools/ci-regression-check.rkt` | — | CI gate | All |

## Appendix B: Related Documents

| Document | Role |
|----------|------|
| `2026-03-03_LE_SUBSYSTEM_AUDIT.md` | Source audit — priority classification |
| `2026-03-03_SESSION_TYPE_DESIGN.md` | Session type Phase II design |
| `2026-03-03_SESSION_TYPE_IMPL_PLAN.md` | Session type implementation phases |
| `2026-02-26_TYPE_INFERENCE_IMPLEMENTATION.md` | Type inference migration tracker |
| `2026-02-26_1200_TYPE_INFERENCE_PIR.md` | Type inference PIR (benchmark reference) |
| `2026-02-25_TYPE_INFERENCE_ON_LOGIC_ENGINE_DESIGN.md` | Original design document |
| `2026-02-25_BENCHMARKING_FRAMEWORK_DESIGN.md` | Benchmarking framework design |
| `DEFERRED.md` | Deferred work tracker |
