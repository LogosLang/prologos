# BSP-LE Track 2B: Parity Deployment + Parallel Search — Stage 2/3 Design

**Date**: 2026-04-10
**Series**: BSP-LE (Logic Engine on Propagators)
**Scope**: DFS↔Propagator parity validation, fact-row isolation, NAF/guard as async propagators, parallel executor default, `:auto` deployment
**Status**: D.13 — Phase R: on-network redesign (mantra audit). NAF as inner sub-query + S1 threshold propagator. Relations on-network. All writes propagator-mediated.
**Self-critique**: [P/R/M Analysis](2026-04-10_BSP_LE_TRACK2B_SELF_CRITIQUE.md) (15 findings, 5 revised via self-hosting lens)
**External critique**: [Architect Review](2026-04-10_BSP_LE_TRACK2B_EXTERNAL_CRITIQUE.md) (18 findings, 2 critical, 8 major)
**Critique response**: [Response](2026-04-10_BSP_LE_TRACK2B_CRITIQUE_RESPONSE.md) (15 actions incorporated)
**Predecessor**: [BSP-LE Track 2 PIR](2026-04-10_BSP_LE_TRACK2_PIR.md) — ATMS Solver + Cell-Based TMS
**Design doc**: [BSP-LE Track 2 Design](2026-04-07_BSP_LE_TRACK2_DESIGN.md) (D.13, ~2000 lines)
**Prior art**: [Track 2 Session Handoff](standups/2026-04-09_2300_session_handoff.md), [Track 2 PIR §10-§12](2026-04-10_BSP_LE_TRACK2_PIR.md)

---

## Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| 0a | Pre-0: parity baseline | ✅ | 19/19 test files pass both strategies. Adversarial: 3 divergence categories found. |
| 0b | Pre-0: micro-benchmarks | ✅ | 28 benchmarks + overhead decomposition. ATMS 24.5x overhead identified → 4 optimization paths. |
| 0c | Pre-0: A/B executor comparison | ✅ | Sequential wins all current workloads. Threads cross over at N≥128. Futures eliminated. |
| 1a | Clause selection as decision-cell narrowing | ✅ | `a1df50f4`→`b47b9787`. On-network discrimination (broadcast), fact-row PU branching, domain-merge fix. Categories 1+2 FIXED. |
| 1b | Position-discriminant analysis | ✅ | `1eae7eb8`. Discrimination tree: position scoring, recursive partitioning, tree-guided installation. Flat ground-arg pass ensures coverage regardless of tree order. |
| **R1** | **Relation store on-network** | ✅ | `9bf8fff7`→`23041a2e`. cell-id 2=relation-store, cell-id 3=config. Discrim-data cells per variant. `store`/`config` params eliminated from 6 functions. |
| **R2** | **Fact-row PU as per-row propagator copies** | ✅ | `d4da77de`. Per-row fire-once propagators with maybe-wrap-worldview for combined bitmask. Single-fact also propagator-mediated. Fixes multi-result NAF composition. |
| **R3** | **All goal installation propagator-mediated** | ✅ | `3bdf3322`. 4 sites: unify var+ground, is-goal, one-clause ground, one-clause-concurrent ground. Fire-once with empty inputs, auto-enqueued. |
| **R4** | **General stratum infra + S1 NAF handler** | ✅ | `8fbc342b`. cell-id 4=naf-pending. S1 handler: fork+install+quiesce+check+nogood. General strata-list in BSP outer loop. -90 lines imperative S1, -naf-completions param. |
| **R6** | **PU dissolution — answer egress cell** | ✅ | `8e8ea659`. dissolve-solver-pu reads scope+worldview cells, projects results, writes answer-cid (egress, total sink). NTT interface SolverNet :outputs alignment. |
| 2a | NAF + scope sharing + product dissolution | ✅ | `a6b02159`→`4b2e5bdf`. Resolution B: scope sharing (no bridges). Product-worldview dissolution. S1 fork-based handler (R4). All adversarial NAF cases pass: basic ✅, variable ✅, both-passed 3 ✅, cross-relation 6 ✅. |
| 2b | Parallel tree-reduce merge (hypercube) | ✅ | `bbf3eb82`. Per-propagator cell-id namespaces (high-bit encoding). CHAMP diff for new-cell capture. merge-fire-results + tree-reduce-fire-results. Parallel pairwise via threads. Threshold-configurable (default 128). |
| 2c | Semaphore-based worker pool for BSP parallelism | ⬜ | Persistent K workers (K=cores), shared-memory buffer, semaphore dispatch (~0.01us vs ~3.6us thread). Expected crossover N≈8-16. Benefits both fire + merge phases. |
| 3 | Guard as propagator | ⬜ | Guard-test propagator with topology-request for inner goals |
| 5a | BSP fire-once fast-path (merged 5a+5c from critique) | ⬜ | Fire-once propagators execute directly, no scheduling ceremony. Handles fact-only (empty worklist) AND single-clause (one fire-once propagator). |
| 5b | Lazy solver-context allocation | ⬜ | Defer decisions/commitments/assumptions/nogoods cells until first amb. |
| 5c | Solver-template cell (was: context pooling — on-network per critique) | ⬜ | First-write-wins cell replaces parameter. Template reused via CHAMP fork. |
| 6 | `:auto` switch + adaptive parallel executor | ⬜ | Sequential default, threads at N≥128. Flip `:auto` → propagator. Full regression gate. |
| T | Parity regression suite | ⬜ | `test-solver-parity.rkt` — representative queries, BOTH strategies, set-equal results |
| PIR | Post-implementation review | ⬜ | |

**Per-phase completion protocol** (from DESIGN_METHODOLOGY.org §4):
1. Test coverage — if behavior added, tests exist; if not, state why in commit message
2. Commit — `git add` + `git commit` with descriptive message
3. Tracker — update this table (⬜ → ✅ + commit hash)
4. Dailies — append what was done, why, design choices, lessons
5. Proceed — next phase only after 1-4 done

---

## §1 Objectives

**End state**: The propagator-native solver IS the default solver. `:auto` routes to `solve-goal-propagator`. Clause ordering has no effect on results (already true — CALM) AND no effect on performance (BSP parallel firing). All test files that exercise `defr`/`solve` pass through the propagator path. The DFS solver remains as the `:depth-first` backend — one of multiple solver strategies (DFS, BSP/propagator-native, well-founded/bilattice), not a fallback.

**What changes**:
- `:auto` → propagator (was DFS)
- Fact queries: per-fact-row PU isolation (was last-write-wins)
- NAF: async propagator with NAF-result cell (was blocking fork)
- Guard: guard-test propagator with inner-goal continuation (was synchronous eval)
- `current-parallel-executor` → `make-parallel-thread-fire-all` (was `#f` / sequential)

**What doesn't change**:
- Solver-context, compound cells, tagged-cell-value infrastructure (Track 2 deliverables)
- DFS solver code (retained as `:depth-first` fallback)
- `solver-config` struct and key set
- Tabling infrastructure (producer/consumer propagators)
- `defr`/`solve`/`explain` syntax

**Success criterion**: All 95 test files pass with `:strategy :atms`. A/B benchmarks show ≤15% regression vs DFS baseline. Parallel executor shows measurable speedup on adversarial benchmarks with N≥4 clauses.

---

## §2 Stage 1/2: Gap Analysis (Code Measurements)

### §2.1 DFS Solver — What Must Be Matched

**File**: `relations.rkt` (1934 lines)

| Function | Lines | What It Does |
|---|---|---|
| `solve-goals` | 616-625 (10 lines) | Entry point: `append-map` over goals, threading substitution |
| `solve-single-goal` | 628-719 (92 lines) | Dispatch: unify, is, not, guard, cut, app. Depth limit check. |
| `solve-app-goal` | 841-909 (69 lines) | Relation lookup, facts then clauses, substitution threading |

**DFS characteristics that propagator must match**:
1. **All fact rows** returned as separate solutions (backtracking, lines 857-872)
2. **NAF**: oracle consultation + ground-instantiation check (lines 668-682)
3. **Guard**: inner-goal continuation in conditional arm (line 701)
4. **Cut**: returns current substitution (line 692) — deferred in BOTH solvers
5. **Depth limiting**: `DEFAULT-DEPTH-LIMIT` counter (line 629-630)

### §2.2 Propagator Solver — Current State

**File**: `relations.rkt` (1934 lines)

| Function | Lines | What It Does |
|---|---|---|
| `solve-goal-propagator` | 1857-1934 (78 lines) | Fresh network, install goals, run-to-quiescence, read results |
| `install-goal-propagator` | 1406-1515 (110 lines) | Goal dispatch: unify, is, app, not, guard, cut |
| `install-clause-propagators` | 1648-1681 (34 lines) | Three paths: consumer (table), producer (register), no-context |
| `install-one-clause-concurrent` | 1583-1640 (58 lines) | Multi-clause PU with worldview bitmask |
| `install-conjunction` | 1522-1525 (4 lines) | Sequential `for/fold` installation |

### §2.3 Gap Analysis — Concrete Measurements

| Gap | DFS Lines | Propagator Lines | Issue | Impact |
|---|---|---|---|---|
| **Fact-row isolation** | 857-872 (16 lines, backtrack all rows) | 1692-1704 (13 lines, last-write-wins) | Propagator writes all facts to same cells; last write wins | **Correctness**: queries returning N facts return only 1 |
| **NAF semantics** | 668-682 (15 lines, oracle + ground check) | 1463-1489 (27 lines, fork + quiescence) | Blocking `run-to-quiescence` inside outer propagator fire | **Correctness**: subtle semantic difference. **Performance**: blocks outer clause. |
| **Guard inner-goal** | 695-710 (16 lines, condition + inner goal) | 1491-1512 (22 lines, condition only) | No inner-goal continuation in propagator guard | **Completeness**: guard with inner body fails |
| **Depth limiting** | 629-630 (2 lines, counter decrement) | 1873-1875 (3 lines, fuel timeout) | Different termination models | **Low**: fuel timeout is acceptable substitute |
| **Cut** | 692 (1 line, returns subst) | 1514 (1 line, returns unchanged) | Deferred in both | **Low**: no test exercises cut semantics |

### §2.4 Test Infrastructure — The Confidence Gap

| Metric | Count | Source |
|---|---|---|
| Total test files | 400 | `tests/` directory |
| Files using `defr`/`solve` | 95 | grep-backed |
| Files with `:strategy :atms` | **0** | grep-backed |
| Propagator-solver-specific tests | 1 file (17 tests) | `test-propagator-solver.rkt` |
| DFS-exercising test files | 95 | All go through `:auto` → DFS |

**The confidence gap**: 0% of the existing solver test suite exercises the propagator path. The propagator solver has 17 dedicated tests covering individual goal types and multi-clause branching. The 95 files using `defr`/`solve` represent the parity target.

### §2.5 Parallel Executor Infrastructure — Ready But Dormant

**File**: `propagator.rkt` (2828 lines)

| Executor | Lines | Status |
|---|---|---|
| `sequential-fire-all` | 2192-2194 (3 lines) | Current default |
| `make-parallel-fire-all` | 2370-2383 (14 lines) | Futures-based, threshold=4 |
| `make-parallel-thread-fire-all` | 2404-2434 (31 lines) | True OS threads, partitions per core |
| `current-parallel-executor` | 2388 (parameter, default `#f`) | `#f` means sequential |
| `run-to-quiescence-bsp` | 2267-2358 (92 lines) | Calls executor at line 2293 |

The parallel infrastructure EXISTS from PAR Track 1. It has never been the default. Enabling it is a configuration change + validation.

### §2.6 Strategy Dispatch — Current Wiring

**File**: `stratified-eval.rkt` (lines 182-226)

```
:atms       → solve-goal-propagator (propagator-native)
:depth-first → solve-goal (DFS)
:auto       → solve-goal (DFS)  ← THIS IS WHAT WE CHANGE
```

The dispatch exists. `:auto` → propagator is a one-line change. The WORK is in making the propagator solver handle all the cases that `:auto`'s 95 test files exercise.

### §2.7 Phase 0a Findings (D.4)

**Parity harness**: `current-solver-strategy-override` parameter added to `stratified-eval.rkt` — one parameter + one `or` in dispatch. Enables running any test under `:atms` without code changes.

**Existing test suite**: 19/19 solver test files pass under BOTH strategies. No existing tests exercise the edge cases that diverge.

**Adversarial benchmark** (`parity-adversarial.prologos`): Found 3 categories of divergence:

| Category | Symptom | Root Cause | Scope |
|---|---|---|---|
| 1: Fact-row last-write-wins | `fact8 ?x` → 1 result (should be 8) | Facts path writes ALL rows without checking bound args | Phase 1a |
| 2: Multi-clause variable binding | `five-way 3 ?y` → 5 results (should be 1); `color-pair ?c1 ?c2` → unresolved `c1` | Clauses installed concurrently without narrowing on bound args | Phase 1a |
| 3: NAF semantic divergence | `not (ground-vals 20)` → should fail, returns success | Fork doesn't correctly detect inner goal success | Phase 2 |

**Key insight**: Categories 1 and 2 are the SAME problem — clause selection doesn't narrow on bound arguments. This is solved by one mechanism: clause decision-cell narrowing (§3.1).

### §2.8 Infrastructure Findings (D.2)

Key findings from code audit that change the design:

1. **BSP nesting is supported**: `run-to-quiescence-bsp` takes a `net` parameter, can be called recursively. No global state conflicts. Fuel is per-network (immutable in `prop-network` struct). The forked network gets its own fuel budget.

2. **Current NAF uses Gauss-Seidel, not BSP**: Line 1475 calls `run-to-quiescence` (GS), not `run-to-quiescence-bsp`. Even the synchronous fix of switching to BSP would be an improvement.

3. **Fork is O(1)**: `fork-prop-network` creates fresh worklist + fuel, shares cells/propagators/merge-fns via CHAMP structural sharing. Copy-on-write isolation. Two struct allocations.

4. **Thread infrastructure exists**: `make-parallel-thread-fire-all` (propagator.rkt lines 2404-2434) uses Racket 9 parallel threads with per-core partitioning. The thread spawn/join pattern is proven.

5. **Fuel is propagator-firings, not wall-clock**: `fuel := fuel - length(deduplicated_worklist)` per BSP round (line 2290). The `solver-config-timeout` converts ms to firings via `fuel = timeout_ms * 1000` (rough heuristic, line 1873). Default: 1,000,000 firings.

6. **DFS depth limit is independent**: `DEFAULT-DEPTH-LIMIT = 100` (line 551), counts call stack depth, errors on overflow. Completely separate mechanism from fuel.

### §2.9 Phase 0b Benchmark Data (D.5)

#### S1: Fact-Row Scaling (Current Solver Baseline)

| N facts | Median (us/query) | vs N=1 |
|---|---|---|
| 1 | 11.7 | 1.00x |
| 2 | 11.9 | 1.02x |
| 4 | 13.2 | 1.13x |
| 8 | 15.6 | 1.33x |
| 16 | 20.4 | 1.74x |
| 32 | 29.4 | 2.51x |

**Linear in N** — ~0.56us per additional fact row. The current (broken) last-write-wins approach costs proportional to N because it writes all facts to cells.

#### S2: Decision-Cell Narrowing Cost (Clause Selection Mechanism)

| Operation | Per-op (us) |
|---|---|
| Narrow 4→1 | 0.125 |
| Narrow 8→2 | 0.289 |
| Narrow 16→4 | 0.602 |
| Narrow 32→8 | 1.56 |

**Sub-microsecond to low-microsecond.** Negligible vs query cost (11-29us). No threshold needed — narrowing is effectively free.

#### S3: Fork + Quiescence (NAF Baseline)

| Operation | Per-op (us) |
|---|---|
| Fork (10 cells) | 0.022 |
| Fork (50 cells) | 0.023 |
| GS quiescence (empty fork) | 0.192 |
| BSP quiescence (empty fork) | 0.307 |

**Fork is O(1)** — 22ns regardless of cell count. BSP is 1.6x GS on empty forks.

#### S4: Thread Spawn Overhead (Async NAF)

| Operation | Per-op (us) |
|---|---|
| Thread no-op spawn+join | 3.6 |
| Thread fork+quiesce | 4.1 |
| Sync fork+quiesce (no thread) | 0.31 |

**Thread overhead: ~3.6us.** Async NAF costs 13x sync. Worth it only for non-trivial inner goals.

#### S5: Tagged-Cell-Value Operations

| Read N entries | Per-op (us) | Write | Per-op (us) |
|---|---|---|---|
| N=4 | 0.043 | to N=4 | 0.009 |
| N=8 | 0.070 | — | — |
| N=16 | 0.129 | to N=16 | 0.008 |
| N=32 | 0.236 | — | — |

Reads scale linearly with N. Writes are constant (prepend).

#### S6: Discrimination Map Lookup

| Map size | Per-op (us) |
|---|---|
| N=4 | 0.010 |
| N=32 | 0.013 |

**Hash lookup is constant-time.** Negligible cost.

#### S7: DFS vs ATMS Full Pipeline

| Query | DFS (us) | ATMS (us) | Ratio |
|---|---|---|---|
| Single fact | 0.91 | 23.0 | **25.3x** |
| 3-clause | 6.1 | 50.5 | **8.3x** |
| 8-fact | 1.8 | 16.0 | **8.7x** |

#### ATMS Overhead Decomposition (Single-Fact Query, 23.0us total)

| Component | Cost (us) | % of Total |
|---|---|---|
| Network + context allocation (steps 1-4) | 3.6 | 15.5% |
| Goal installation (step 5 delta) | 7.0 | 30.4% |
| **BSP scheduling + propagator firing (step 6 delta)** | **12.1** | **52.6%** |
| Result reading (step 7) | 0.1 | 0.4% |

**The dominant cost is BSP scheduling (52.6%)** — worklist dedup, fuel check, outer loop, topology stratum. Even for a query with zero propagators to fire, the scheduler has fixed overhead.

**Context reuse**: Skipping network+context allocation saves 33% (23.0us → 15.5us). Still 17x DFS.

### §2.10 Executor Scaling + Thread Pool Analysis (D.6)

#### Parallel Scaling (N × W matrix)

Synthetic workload: N concurrent propagators, 3 work levels, 3 executors. (`bench-parallel-scaling.rkt`)

| N | Fut/Seq | **Thr/Seq** | Winner |
|---|---|---|---|
| 4 | 2.7-7.1x slower | ~1.0x | sequential |
| 8 | 4-19x slower | 13-29x slower | sequential |
| 16 | 31-35x slower | 12-27x slower | sequential |
| 32 | 11-18x slower | 3.5-5.7x slower | sequential |
| 64 | 4.5-5.4x slower | 1.4-1.6x slower | sequential |
| **128** | 2.2-2.8x slower | **0.52-0.56x (1.9x speedup)** | **threads** |

**Futures never win** — Racket VM restrictions (no allocation during future execution) make them unsuitable. **Eliminated from consideration.**

**Threads cross over at N=128** — 1.9x speedup. At N=64 still 1.4-1.6x slower.

#### Thread Synchronization Cost Stack (`bench-thread-pool.rkt`)

| Mechanism | Cost/op (us) |
|---|---|
| Thread create+join | 3.6 |
| Channel round-trip (persistent thread) | 1.57 |
| Semaphore post+wait | 0.01 |
| Thread pool dispatch (4 items, channels) | 6.5 (1.6/item) |

**Channel communication (1.57us) is the floor** for any pool-based approach. Even eliminating thread creation cost entirely, channel dispatch limits the crossover to ~N=64.

#### Three Optimization Tiers

| Tier | Mechanism | Per-round cost (K=8) | Est. crossover |
|---|---|---|---|
| Current | Fresh threads per round | 27us | N=128 |
| A: Thread pool (channels) | Persistent workers, channel dispatch | ~13us | N≈64 |
| B: Shared-memory + semaphore | Workers on shared buffer, semaphore gate | ~1us | N≈8-16 |
| C: Hypercube all-reduce (§3.7) | Pairwise merge tree, shared-memory | ~0.06us | N≈4-8 |

Tier C applies the Hyperlattice Conjecture's optimality claim to the BSP barrier merge itself — see §3.7.

#### Real-World Benchmark Comparison (7 programs, 10 runs each)

| Program | Seq (ms) | Fut (ms) | Thr (ms) | Change |
|---|---|---|---|---|
| simple-typed | 104.6 | 104.9 | 105.4 | noise |
| nat-arithmetic | 110.5 | 112.0 | 113.4 | +1-3% regression |
| higher-order | 160.6 | 162.9 | 162.9 | +1.4% regression |
| solve-adversarial | 3834 | 3835 | 3842 | noise |
| atms-adversarial | 4146 | 4152 | 4163 | noise |
| parity-adversarial | 3577 | 3579 | 3573 | noise |
| constraints-adversarial | 5249 | 5510 | 5378 | +2-5% regression *** |

**No current workload benefits from parallelism.** All programs have too few concurrent propagators per BSP round.

### §2.11 R4 Verification: Lazy Context + Worldview Cache (D.7)

**Verified safe.** Audit findings:
1. Cell-id 1 (worldview cache) is **always pre-allocated** in `make-prop-network` with initial value 0 — independent of `make-solver-context`. Lazy context doesn't affect it.
2. `promote-cell-to-tagged` makes **no reference to cell-id 1** — it only operates on the specific cell being promoted (its value + merge function).
3. `net-cell-read` with tagged values: if cell-id 1 is `'none`, defaults to bitmask=0 (base value, no filtering). If cell-id 1 has value 0, same result. Both paths safe.
4. Multi-clause installation supports `ctx = #f` fallback (local assumption IDs) and calls `promote-cell-to-tagged` regardless — but the main entry point (`solve-goal-propagator`) always creates a context first.

**Conclusion**: lazy solver-context (Phase 5b) is safe. No interaction hazards with tagged-cell-value infrastructure.

---

## §3 Algebraic Foundation

### §3.1 Clause Selection as Decision-Cell Narrowing (D.4 — from Phase 0a findings)

#### The Problem (Phase 0a Adversarial Findings)

The propagator solver has two related bugs:

**Category 1 (facts)**: Fact rows write ALL values to free argument cells without checking bound arguments. `fact8 ?x` returns 1 result (last-write-wins) instead of 8. `fact16 8 ?y` returns wrong result.

**Category 2 (clauses)**: Multi-clause propagators are installed for ALL clauses concurrently without filtering on bound arguments. `five-way 3 ?y` returns 5 results instead of 1. `color-pair ?c1 ?c2` returns unresolved variables for `:c1`.

Both are the SAME problem: **clause selection doesn't narrow on bound arguments**.

#### The Structural Frame — Not a New Lattice

The clause-viability lattice is NOT a new algebraic structure. It is an **instance** of the existing Track 2 decision cell lattice with a new narrowing SOURCE:

| | ATMS Decision Cell (Track 2) | Clause-Viability Cell (Track 2B) |
|---|---|---|
| Carrier | P(Alternatives) | P(ClauseIndices) |
| Order | ⊇ (reverse inclusion) | ⊇ (reverse inclusion) |
| Bot | all alternatives viable | all clauses viable |
| Top | ∅ (contradiction) | ∅ (no clause matches) |
| Merge | set-intersection | set-intersection |
| **Narrowing source** | **Nogoods** (contradictions) | **Bound arguments** (query constraints) |

Same lattice. Same infrastructure (`decisions-state`). Same merge. We are adding a new **bridge** to an existing lattice, not introducing a new algebraic structure.

**What emerges?** When a ground value arrives at query argument position k:
- The arg-watcher propagator fires, looks up the discrimination map
- Clauses whose head at position k is incompatible are eliminated from the domain
- Their assumption bits are cleared in the decision cell
- Their propagators become inert (assumption no longer in viable domain)
- Only matching clauses' propagators fire

Clause selection IS decision-cell narrowing. The mechanism is structurally identical to what Track 2 built for ATMS alternatives.

#### SRE Lattice Lens — Full Analysis

**Q1 (Classification)**: STRUCTURAL lattice. Clause indices ARE constructors — each clause is a mutually exclusive alternative. Maps directly onto SRE form registry: alternatives = constructors, narrowing = eliminating constructors. Same classification as Track 2 decision cells.

**Q2 (Algebraic Properties)**: Boolean (dual powerset), distributive, complemented, Heyting, frame — inherits ALL properties from P(N) under ⊇.

Distributivity is critical for Phase 1b: narrowing by (position 0 AND position 1) = (narrow by 0) THEN (narrow by 1) = (narrow by 1) THEN (narrow by 0). The order of multi-position narrowing does NOT affect the result. The "best position first" optimization (needed narrowing) is about PERFORMANCE (fewer intermediate states), not CORRECTNESS (same final result guaranteed by distributivity).

**Q3 (Bridges to other lattices)**:

```
Query Argument Cells ──(narrow-by-arg)──→ Clause-Viability Cell
                                              │
                                         (gate branches)
                                              │
                                    ┌─────────┼─────────┐
                                    ↓         ↓         ↓
                              Branch PU₁  Branch PU₂  Branch PUₖ
                              (worldview  (worldview  (worldview
                               bitmask)   bitmask)    bitmask)
                                    │         │         │
                                    ↓         ↓         ↓
                             Scope cells (per-clause, tagged)
                                    │         │         │
                                    └─────────┼─────────┘
                                              │
                                       Answer Accumulator
```

| Bridge | From | To | α (forward) | Galois? |
|---|---|---|---|---|
| **Narrow-by-arg** | Query arg cell (position k) | Clause-viability cell | `ground_value → compatible_clause_set` via discrimination map | Yes: α preserves joins |
| **Gate-branches** | Clause-viability cell | Branch topology | Viable set → PU branches for viable clauses only | Topology mutation (CALM-safe) |
| **Inherit assumptions** | Clause-viability (per-clause) | Worldview (compound decisions) | Each viable clause's assumption bit → worldview bitmask | Composition with existing Track 2 bridge |

The narrow-by-arg bridge IS a Galois connection. The discrimination map defines α (forward: value → clause set). The adjoint γ (backward: clause set → "what values keep these viable?") is the inverse of the map.

**Q4 (Composition)**: The clause-viability cell sits BETWEEN query arguments and Track 2 branching. It's a pre-filter that reduces the input to the branching infrastructure:

```
                                   Track 2B (new)
                                  ┌─────────────────┐
Query Args ──(narrow-by-arg)──→  │ Clause-Viability │
                                  │      Cell        │
                                  └────────┬────────┘
                                           │
                                    (gate branches)
                                           │
                                   Track 2 (existing)
                                  ┌────────┴────────┐
                                  │  Per-Clause PU   │
                                  │  Branches with   │
                                  │  Worldview Bits  │
                                  └────────┬────────┘
                                           │
                           ┌───────────────┼───────────────┐
                    Decision Cells    Commitment Cells   Nogood Cell
                           │               │               │
                           └───────────────┼───────────────┘
                                    Worldview Cache (cell-id 1)
```

The clause-viability cell does NOT replace any Track 2 lattice. It COMPOSES with them by reducing the input. Fewer viable clauses = fewer branches = less ATMS overhead.

**Q5 (Primary/Derived)**: Clause-viability cell is **PRIMARY** — derived from query arguments (inputs), not from other solver lattice cells. The discrimination map is a STATIC FUNCTION applied by the arg-watcher propagator. Per-clause viability (whether propagators fire) is DERIVED from the viability cell + Track 2 assumption-tagged dependents.

**Q6 (Hasse Diagram — Optimality)**: For N clauses, the Hasse diagram is dual hypercube Q_N:
- Nodes: all subsets of {0, ..., N-1}
- Edges: subsets differing by one element
- Bot: {0, ..., N-1} (all viable) at top
- Top: ∅ (none viable) at bottom
- Narrowing traverses DOWNWARD

For Phase 1b hierarchical narrowing: each argument position is a DIMENSION. Q_N = Q_{N-1} × Q_1 — each position splits the clause space in half. The optimal narrowing order (needed narrowing) IS the dimension order that minimizes traversal depth.

Bitmask representation enables O(1): narrowing = `viable AND compatible_mask`, viability check = `viable AND (1 << idx)`, contradiction = `viable == 0`.

#### Module-Theoretic Decomposition

A relation R with N clauses is a **direct sum of clause modules**:

```
R = C₁ ⊕ C₂ ⊕ ... ⊕ Cₙ
```

Each clause Cᵢ is a sub-module: `(input bindings) → (output bindings)` via the clause body.

The clause-viability cell computes a **projection**: given query arguments, project R onto the sub-module spanned by compatible clauses. If arguments narrow to {C₂, C₅}, then R_projected = C₂ ⊕ C₅.

The discrimination map IS the **kernel** of this projection — it determines which clauses project to zero for a given argument value. The arg-watcher propagator IS the projection morphism.

For Phase 1b: hierarchical narrowing is **iterated projection** through the module's decomposition tree. Each argument position defines a further projection. The tree of projections IS the module's composition series.

#### Forward Composition with Phases 2-6

| Phase | How Clause-Viability Composes |
|---|---|
| Phase 2 (NAF) | NAF inner goal creates its own clause-viability cell. No interaction with outer viability. |
| Phase 3 (Guard) | Guard-gate watches guard-result, not clause-viability. Independent lattices. |
| Phase 5a (Fire-once) | Viability may narrow to 0-1 clauses → BSP worklist empty → fire-once fast-path triggers. Narrowing FEEDS the fast-path. |
| Phase 5b (Lazy context) | Viability narrows to 0-1 clauses → never reaches `amb` → lazy context stays minimal. Narrowing REDUCES context allocation. |
| Phase 6 (Parallel) | Narrowing reduces N (concurrent propagators). Fewer viable clauses = closer to sequential fast-path. Narrowing is an anti-parallelism optimization. |

The key insight: clause-viability narrowing **compounds** with every Tier 1 optimization. Better narrowing → fewer branches → more queries hit fire-once → lower overhead. The lattice IS the optimization's input.

#### Three Components

**1. Discrimination map** (static, computed once at relation registration):

For each clause/fact-row, extract what ground value it expects at each argument position:
- **Fact rows**: the row values ARE the expected values (`|| 1 2 3` → position 0 expects `{1: row0, 2: row1, 3: row2}`)
- **Clause bodies**: peek at the first unification goal (`&> (= c1 "red") ...` → position 0 expects `"red"` for this clause)
- **No first-goal**: clause is compatible with any value at that position (wildcard)

Result: `hasheq position → (hasheq value → (listof clause-index))` — for each position, which values map to which clauses.

**2. Clause decision cell** (Track 2 `decisions-state`):

Created at solve time. Alternatives = all clause/fact-row indices. Merge = set-intersection (narrowing). One per relation invocation.

**3. Argument-watching propagator** (fire-once per position):

For each argument position that has discrimination power:
- Watch the query argument cell at position k
- When a ground value arrives, look up the discrimination map
- Narrow the clause decision cell to only clauses compatible with that value
- Non-matching clauses' assumption bits are cleared → their propagators become inert

This propagator does NOT need to be installed for positions with no discrimination power (all clauses accept any value). The discrimination map analysis identifies which positions matter.

#### Needed-Narrowing Optimization (Phase 1b)

Inspired by FL-Narrowing's definitional trees, but built natively on Track 2 infrastructure:

**Position analysis**: Which argument position BEST discriminates? If position 0 splits N clauses into N singletons, it's maximally discriminating. If position 0 groups into {A: [c1,c2], B: [c3,c4,c5]}, it's partially discriminating — within each group, another position may further split.

**Hierarchical narrowing**: Build a tree of argument-watching propagators. Level 0 watches position p0 (best discriminant). Level 1 watches position p1 within each group from level 0. Each level is a Q_1 decomposition — the recursive structure of the hypercube.

This is the definitional tree structure, but realized as nested decision cells on the network:
- Each level IS a decision cell with its own merge
- Each level's propagator watches a specific argument position
- The tree of decision cells IS the Hasse diagram of the hierarchical clause decomposition

Unlike FL-Narrowing's off-network tree walking, this puts the entire clause selection on-network. Information flows through cells. Narrowing is lattice operations. The structure IS the parallel decomposition (hypercube optimality).

**When to build the tree**: At relation registration time (static analysis, no runtime cost). The tree structure is stored alongside the relation's `variant-info`. At solve time, the tree guides propagator installation — only install what the discrimination tree doesn't eliminate.

#### Why This Is New Composition, Not Integration

| Aspect | FL-Narrowing (old) | Clause Selection (new) |
|---|---|---|
| Clause filtering | Off-network tree walking | Decision-cell narrowing on network |
| Branch dispatch | `make-branch-fire-fn` callback | Assumption-tagged dependents (Track 2) |
| Position analysis | `extract-definitional-tree` | Discrimination map extraction (simpler — `defr` heads are ground values, not patterns) |
| Topology mutation | Direct propagator installation | Topology requests (CALM-safe protocol) |
| Residuation | Custom wait logic | Cell residuation (propagator fires when cell resolves) |
| Hierarchical | Tree data structure | Nested decision cells on network |

The theory is the same (needed narrowing). The realization is entirely Track 2 infrastructure.

### §3.R Phase R: On-Network Redesign (D.13 — Mantra Audit)

> **"All-at-once, all in parallel, structurally emergent information flow ON-NETWORK."**

#### Origin

A mantra audit of all Track 2B code (Phases 1a-2a) revealed six components violating the design mantra. The audit challenged every line against each word: all-at-once, all-in-parallel, structurally emergent, information flow, ON-NETWORK. The violations range from correctness bugs (fact-row PU composition) to architectural debt (off-network result reading).

The Completeness principle demands: if we know these components need to be on-network for self-hosting, do it now while context is fresh. Phase R addresses all six before resuming Phase 2a.

#### Audit Findings Summary

| Component | Mantra Violation | Severity |
|---|---|---|
| Fact-row PU (2105-2182) | `for/fold` direct writes, no per-branch propagators | **Correctness bug** — root cause of multi-result NAF divergence |
| Relation store (`current-relation-store`) | Off-network `make-parameter` with hasheq | **Architectural** — blocks on-network NAF inner goal |
| Goal installation (unify ground case, line 1773) | Direct `logic-var-write` at construction time | **Step-think** — creates ordering dependency in conjunctions |
| S1 NAF evaluation (2401-2492) | Imperative post-processing, off-network | **Off-network** — superseded by threshold + stratum design |
| NAF completions (`naf-completions`) | `make-hasheq` parameter | **Off-network** — superseded by S1 threshold design |
| Result reading (2498-2576) | Imperative assembly, off-network | **Off-network** — answer-cid exists but unused |

#### R1: Relation Store and Config On-Network

**Architecture**: The solver query follows the PU micro-stratum pattern from PPN Track 4. The relation store and config are well-known cells on the solver's network, read by propagators via component-indexed access. Discrimination data is DERIVED from the relation store via fire-once derivation propagators.

**Prior art**: PPN Track 1 (5 embedded-lattice PU cells), PPN Track 4 (typing PU as cell on elab-network), SRE Track 2D PIR (PU micro-stratum model for non-monotone operations).

##### SRE Lattice Lens — Relation Store Cell

**Q1 (Classification)**: VALUE lattice (registry). The relation store maps names to structured data (relation-info). Same classification as the module registry in `namespace.rkt`.

**Q2 (Algebraic Properties)**: Join-semilattice. `hash-union` merge: commutative, associative, idempotent. Monotone accumulation — relations added, never removed. CALM-safe: coordination-free registration. Not Boolean (no complement).

**Q3 (Bridges)**:

| Bridge | From | To | α (forward) | Galois? |
|---|---|---|---|---|
| Register | defr AST | relation-store cell | hash-set into store | Yes: preserves joins |
| Derive | relation-store cell | discrim-data cells | compute discrimination map per variant | Yes: hash-union preserves |
| Goal-install | relation-store cell | solver PU internals | read relation, install propagators | Component-indexed read |
| Result | solver PU scope cells | answer accumulator | project scope → answer tuples | Set-union |

**Q4 (Composition)**:

```
         Solver Network (PU micro-stratum)
        ┌─────────────────────────────────────────────┐
        │                                             │
        │  relation-store cell ←── defr snapshot      │
        │       │          (well-known cell-id)       │
        │       │                                     │
        │       │ (derive, fire-once per variant,     │
        │       │  component-indexed by rel-name)     │
        │       ↓                                     │
        │  discrim-data cells (per variant, DERIVED)  │
        │       │                                     │
        │  config cell ←── solver-config snapshot     │
        │       │     (well-known cell-id, constant)  │
        │       │                                     │
        │  ┌────┴────────────────────────┐            │
        │  │  Query scope (per solve)    │            │
        │  │  scope cells, viability     │            │
        │  │  discrimination propagators │            │
        │  │  fact-row/clause propagators│            │
        │  │  NAF threshold (S1)         │            │
        │  │  result-projection          │            │
        │  └────┬────────────────────────┘            │
        │       ↓                                     │
        │  answer-accumulator cell (PU output)        │
        └─────────────────────────────────────────────┘
```

**Q5 (Primary/Derived)**:
- relation-store cell: **PRIMARY** (written by defr, not derived)
- config cell: **PRIMARY** (written by caller, constant)
- discrim-data cells: **DERIVED** (from relation-store, via derivation propagator)
- answer accumulator: **DERIVED** (from solver PU fixpoint)

**Q6 (Hasse Diagram)**: Flat join-semilattice — each relation entry is independent, no inter-entry ordering. Hasse is a product of singletons. CALM-safe. No interesting parallel structure at the registry level; the interesting Hasse structure is inside the query scope (worldview hypercube Q_n).

##### Cell Specifications

**Relation store** — well-known cell-id (pre-allocated, like `worldview-cache-cell-id`):
- **Carrier**: `hasheq relation-name → relation-info`
- **Merge**: `hash-union` (accumulate relations monotonically)
- **Initial**: Written once at query start with current file-level store snapshot
- **Reads**: Component-indexed by relation name. Goal-installation propagators declare `#:component-paths (list (cons relation-store-cid goal-name))`. Registering `other-vals` does NOT fire the propagator for `ground-vals`.
- **Phase 0 scaffolding**: Per-query network, snapshot write. Self-hosting: on elab-network, written incrementally by `defr` processing. Migration is a scope change, not a structural change.

**Config** — well-known cell-id:
- **Carrier**: `solver-config` struct
- **Merge**: First-write-wins (constant after initialization)
- **Reads**: By installation propagators for timeout, tabling decisions

**Discrimination data** (per variant) — dynamically allocated:
- **Carrier**: `hasheq position → (hasheq clause-idx → expected-value)`
- **Merge**: `hash-union` (positions accumulate)
- **Producer**: Fire-once derivation propagator, watches relation-store cell (component-indexed by relation name), computes discrimination data, writes to discrim-data cell
- **Consumers**: Discrimination propagators in `install-discrimination-propagators` read the cell instead of calling `build-discrimination-data`

##### Parameter Elimination

The `store` parameter (threaded through ~20 call sites) and `config` parameter are eliminated from function signatures. Both are well-known cells — any propagator with access to the network reads them directly via component-indexed cell reads. Functions that currently take `store` and `config` lose those parameters.

##### Why This Unlocks Everything

With relations on-network:
- **NAF inner goal (R5)**: installed via the same code path as any goal — `install-goal-propagator` reads from the relation-store cell. No special NAF infrastructure. The inner goal is just a goal.
- **Discrimination (R2)**: derivation propagators produce discrimination data reactively. The self-hosted compiler gets a derivation path, not opaque pre-computed constants.
- **Forward references (self-hosting)**: goal-installation propagators residuate until the relation is registered, then fire. No ordering dependency between `defr` and `solve`.
- **Config reads (R4/R5)**: S1 threshold propagator reads timeout from config cell. BSP stratum extension reads config for fuel decisions.

#### R2: Fact-Row PU as Per-Row Propagator Copies

**What**: Replace the `for/fold` direct-write pattern (lines 2135-2182) with `install-one-clause-concurrent`-style per-row installation.

Each viable fact row becomes a "trivial clause":
1. Allocate assumption via `solver-assume` (existing, already done)
2. Fresh inner scope via `build-var-env` for per-row local variables
3. Arg-to-param bridge propagators wrapped with `wrap-with-worldview(fire, bit-position)`
4. Body is trivial: no conjunction goals, just the unification writes as propagators
5. Ground arg writes are fire-once propagators (see R3), not direct `logic-var-write`

**Why this fixes multi-result NAF**: The arg-to-param bridge propagator carries its bitmask as a closure. When composed with NAF bitmask (ORed at installation time via `current-worldview-bitmask`), the propagator fire function writes under the combined bitmask. Each fact row's propagators fire independently during BSP. Multi-level composition (NAF + fact-row) works structurally because each level adds a bit to the bitmask.

**The `for/fold` over rows at installation time** is acceptable scaffolding (construction-time setup, independent items). The self-hosted compiler would use broadcast or simultaneous topology requests.

#### R3: All Goal Installation Propagator-Mediated

**What**: Replace construction-time direct writes with fire-once propagators.

The specific case: `install-goal-propagator` for `(unify)` with one variable and one ground value (line 1773):
```racket
;; Current (construction-time, off-network):
[(var-ref? lhs) (logic-var-write net lhs rhs)]

;; On-network: fire-once propagator
[(var-ref? lhs)
 (let ([write-fire (maybe-wrap-worldview
                    (lambda (net) (logic-var-write net lhs rhs)))])
   (net-add-fire-once-propagator net '() (list (if (scope-ref? lhs) (scope-ref-cid lhs) lhs))
                                  write-fire))]
```

Similarly for the symmetric case (line 1774: `[(var-ref? rhs) (logic-var-write net rhs lhs)]`).

**Why this matters for conjunction**: With all writes propagator-mediated, conjunction goals are truly order-independent for installation. `install-conjunction`'s `for/fold` becomes installation of N independent propagator sets — BSP-emergent convergence, same as PPN 1's character reading.

**Cost**: One extra `net-add-fire-once-propagator` call per ground unification. Negligible — fire-once is a single struct allocation + CHAMP insert.

#### R4: General Stratum Infrastructure + S1 NAF Handler (subsumes old R4+R5)

**Architecture**: Follows the existing topology stratum pattern — request-accumulator cell + scheduler handler — generalized to N strata. Propagators are stratum-agnostic. The stratification is in the scheduler's control flow and request-accumulator cells.

**Prior art**: The topology stratum (lines 2379-2399 of propagator.rkt) uses exactly this pattern: the decomp-request cell (cell-id 0) accumulates requests during S0; the scheduler reads and processes them between BSP rounds; handlers are registered functions; the cell is cleared (non-monotone reset) after processing. R4 generalizes this to a list of (request-cell, handler) pairs.

**Why stratification is required**: NAF inverts provability — non-monotone. CALM guarantees confluence only for monotone operations within a stratum. Evaluating NAF during S0 would produce wrong answers when inner goal variables are bound by later conjunction goals. S1 fires only at S0 fixpoint, when all positive goals have converged and all variables that CAN be bound ARE bound.

**Why NOT gate cells / propagator stratum flags**: The existing topology stratum doesn't use gate cells or stratum metadata on propagators. Stratification is implicit in information flow: request accumulator cells + scheduler control flow. Adding gate cells would create two different patterns for the same concept. Adding `#:stratum` flags to propagators violates stratum-agnosticism — propagators are pure functions that shouldn't know about scheduling.

##### 1. NAF-pending cell (well-known cell-id 4)

Replaces the `naf-completions` make-hasheq parameter and `current-naf-completions`. Written by `install-goal-propagator` for `not` goals during S0 installation. Each NAF registers: inner goal descriptor, environment, naf assumption-id, naf bit position.

- **Carrier**: `hasheq naf-aid → (hasheq 'inner-goal goal-desc 'env env 'naf-bit-pos n)`
- **Merge**: `hash-union` (NAF registrations accumulate monotonically)
- **Classification**: VALUE lattice (registry of pending evaluations)
- **Read by**: S1 NAF handler after S0 quiesces

##### 2. S1 NAF handler

Registered as a stratum handler (like topology handlers). After S0 quiesces + topology done, the scheduler reads the NAF-pending cell. For each pending NAF:

1. **Fork** the main network (O(1) — CHAMP structural sharing via `fork-prop-network`)
2. **Resolve inner goal args** on the fork: read outer scope cells for variable bindings (S0 fixpoint values, available on the fork via structural sharing)
3. **Install inner goal** on the fork: standard `install-goal-propagator` code path. Fresh inner scope via `build-var-env`. Reads relation-store cell from the fork. Discrimination propagators, fact-row PU, clause concurrent — all standard infrastructure.
4. **Run BSP on the fork**: nested `run-to-quiescence`. Inner goal converges to fixpoint.
5. **Check provability**: read inner scope cell on the fork. If any component is non-bot → inner goal succeeded → P is provable → write nogood for h_naf on the **main** network via `solver-add-nogood`.
6. **Discard the fork**: the inner goal's propagators and cells are ephemeral. Only the nogood (if any) persists on the main network.

After processing all pending NAFs: clear the NAF-pending cell (non-monotone reset, same as topology clears decomp-request). If nogoods were written → worldview narrows → S0 worklist may have new entries → restart from S0.

##### 3. Generalized BSP outer loop

The `run-to-quiescence-bsp` outer loop becomes:

```
S0 value stratum → quiesce (existing inner loop)
for each (request-cell-id, handler-fn) in strata-list:
  read request-cell
  if non-empty: handler processes requests, clears cell
  if new S0 work (worklist non-empty) → restart from S0
termination: all request cells empty + S0 worklist empty
```

The strata-list for Phase R4:
```racket
(list (cons decomp-request-cell-id process-topology-requests)
      (cons naf-pending-cell-id     process-naf-requests))
```

Adding future strata (S(-1) retraction, S2 well-founded) = prepending/appending to this list.

##### What this replaces

- The entire imperative S1 evaluation (lines 2401-2492): ~90 lines removed
- The `naf-completions` make-hasheq parameter: replaced by NAF-pending cell
- The `current-naf-completions` parameter: eliminated
- The post-quiescence worldview cache clearing: handled by existing nogood→worldview infrastructure
- The old R5 design (S1 threshold propagator): subsumed by the fork-based S1 handler

##### Correctness

At S0 fixpoint: all positive goals have converged, all variables that CAN be bound ARE bound. The forked network inherits all S0 cell values via CHAMP structural sharing. The inner goal installs on the fork and runs to its own fixpoint. The fork's scope cells reflect the inner goal's provability. The main network is untouched until the nogood write.

The S0↔S1 fixpoint iteration: if nogoods eliminate assumptions, worldview narrows, some S0 propagators' tagged writes become invisible, scope cells may lose entries, new S0 propagators may fire. The outer loop re-enters S0. After S0 re-quiesces, S1 handler re-reads the NAF-pending cell (which may have new entries from newly-installed goals). Loop until stable.

##### NTT correspondence

```ntt
;; NAF-pending cell — S1 request accumulator
cell naf-pending : Lattice(HashEq(AssumptionId, NafRegistration))
  :merge hash-union
  :well-known cell-id-4

;; S1 handler — processes NAF requests at S0 fixpoint
stratum-handler naf-evaluation
  :reads naf-pending
  :at-fixpoint-of S0
  :for-each (naf-aid, registration) in naf-pending:
    fork net → inner-net
    install inner-goal on inner-net
    quiesce inner-net
    if provable(inner-net): solver-add-nogood(main-net, naf-aid)
  :clears naf-pending

;; Exchange (NTT Level 6)
exchange S0 <-> S1
  :left  partial-fixpoint -> naf-inputs    ;; S0 scope cell values
  :right naf-results -> s0-constraints     ;; nogoods constraining S0
  :kind  suspension-loop                   ;; S1 suspends until S0 quiesces
```

#### R6: PU Dissolution — Answer Egress Cell

**What**: Implement the `SolverNet :outputs [answers]` egress cell from the NTT interface specification. The `answer-cid` becomes the solver PU's output cell, written via the PU dissolution protocol after all strata quiesce.

**NTT alignment**:
```ntt
interface SolverNet
  :inputs  [query-goals, relation-store, table-store]
  :outputs [answers : Cell (Set Answer)]   ;; ← answer-cid (egress, total sink)
  :cells   [assumptions, nogoods, counter, decisions]  ;; internal
```

**PU dissolution protocol** (after all strata quiesce):
1. Read scope cell (raw) — cell read of internal state
2. Read worldview cache — cell read of internal state
3. Project: enumerate visible bitmask entries, extract query variable bindings. Pure function on cell values. Leaf-bitmask filter + worldview visibility + variable projection.
4. Write result set to `answer-cid` — cell write to egress cell
5. Caller reads `answer-cid` — one cell read, returns list of hasheqs

**Egress invariant**: `answer-cid` is declared as `:outputs` in the SolverNet interface. No internal propagator declares it as an input. Information flows IN (dissolution write) and OUT (caller read). Total sink in the information flow graph.

**answer-cid merge**: Replacement (dissolution writes the complete result set once after fixpoint). The merge function is secondary — dissolution writes once, and the egress invariant means no other writer exists.

**What this replaces**: ~65 lines of imperative bitmask iteration, leaf filter, worldview check, hasheq assembly in `solve-goal-propagator`. Becomes a clean dissolution function (~30 lines) that operates on cell values, aligned with the NTT interface specification.

**Phase 0 → self-hosting path**: For Phase 0, dissolution is a Racket function after `run-to-quiescence`. For self-hosting, the dissolution becomes a bridge propagator on the outer (compiler) network — the PU cell (answer-cid) on the outer network holds the projected results, consumed by downstream propagators.

#### Phase R Ordering and Dependencies

```
R1 (relation store cell) — independent, unlocks R4
R3 (propagator-mediated writes) — independent, unlocks R2
R2 (fact-row per-row propagators) — depends on R3
R4 (general strata + S1 NAF handler) — depends on R1
R6 (result-projection) — depends on R2 (correct tagged writes)
```

**Suggested order**: R1 → R3 → R4 → R2 → R6

R1 and R3 are independent infrastructure (both ✅). R4 uses R1's relation cell for the forked inner goal. R2 uses R3's fire-once writes. R6 uses R2's correctly tagged scope cells.

#### NTT Speculative Model

```ntt
;; Relation store — well-known cell, component-indexed by relation name
cell relation-store : Lattice(HashEq(Name, RelationInfo))
  :merge hash-union
  :well-known cell-id-N
  :component-indexed-by Name

;; Config — well-known cell, constant after init
cell config : Lattice(SolverConfig)
  :merge first-write-wins
  :well-known cell-id-M

;; Discrimination data — DERIVED from relation store, per variant
;; Fire-once derivation propagator watches relation-store
cell discrim-data[v] : Lattice(HashEq(Pos, HashEq(Idx, Value)))
  :merge hash-union

propagator derive-discrim[rel-name, variant-idx] :fire-once
  :reads (relation-store)
  :writes (discrim-data[variant-idx])
  :component-paths ((relation-store . rel-name))
  fire(net) →
    rel ← hash-ref(net-cell-read(net, relation-store), rel-name)
    variant ← list-ref(relation-info-variants(rel), variant-idx)
    data ← build-discrimination-data(variant)
    net-cell-write(net, discrim-data[variant-idx], data)

;; Ground unification as fire-once propagator (R3)
propagator ground-write :fire-once
  :reads ()
  :writes (scope-cell)
  fire(net) → logic-var-write(net, var, ground-val)

;; Fact-row PU as per-row propagator (R2)
propagator fact-row-bridge[row-i] :fire-once
  :reads (query-scope-cell)
  :writes (query-scope-cell)
  :worldview (outer-bm | row-bit-i)
  fire(net) → for-each-arg: logic-var-write(net, arg, row-val)

;; NAF-pending cell — S1 request accumulator (R4)
cell naf-pending : Lattice(HashEq(AssumptionId, NafRegistration))
  :merge hash-union
  :well-known cell-id-4

;; S1 NAF handler — fork-based provability check (R4, replaces old R5)
stratum-handler naf-evaluation
  :reads naf-pending
  :at-fixpoint-of S0
  :for-each pending-naf:
    fork main-net → inner-net
    install-goal-propagator(inner-net, inner-goal, fresh-scope)
    quiesce(inner-net)
    if inner-scope-has-bindings: solver-add-nogood(main-net, h_naf)
  :clears naf-pending

;; PU dissolution — answer egress (R6, aligned with NTT interface SolverNet)
;; Not a propagator — PU exit protocol after all strata quiesce
dissolution solver-pu-exit
  :reads (query-scope-cell, worldview-cache-cell)
  :writes (answer-cid)  ;; egress cell, total sink
  dissolve(net) →
    scope-raw ← net-cell-read-raw(net, scope-cid)
    worldview ← net-cell-read(net, worldview-cache-cell-id)
    results ← project-visible-entries(scope-raw, worldview, query-vars)
    net-cell-write(net, answer-cid, results)
    net-cell-write(net, answer-cid, results)
```

#### Correspondence Table

| NTT Construct | Racket Implementation | File | Lines (approx) |
|---|---|---|---|
| `cell relation-store` | `net-new-cell` in `make-solver-context` | relations.rkt | new |
| `cell discrim-data[v]` | `net-new-cell` in `install-discrimination-propagators` | relations.rkt | ~520 (modified) |
| `propagator ground-write` | `net-add-fire-once-propagator` in `install-goal-propagator` | relations.rkt | ~1773 (modified) |
| `propagator fact-row-bridge` | new function `install-one-fact-concurrent` | relations.rkt | new (~40 lines) |
| `cell naf-pending` | `net-new-cell` well-known cell-id 4, hash-union merge | propagator.rkt | new |
| `stratum-handler naf-evaluation` | `register-stratum-handler!` + `process-naf-request` | relations.rkt | new (~40 lines) |
| `strata-list` in BSP outer loop | Generalized topology processing to N strata | propagator.rkt | ~30 lines modified |
| `dissolution solver-pu-exit` | `dissolve-solver-pu` function in `solve-goal-propagator` | relations.rkt | new (~30 lines, replaces ~65 lines) |

### §3.2 NAF as Async Propagator — Lattice Analysis

> **NOTE (D.13)**: §3.2's fork-based async NAF model is superseded by §3.R Phase R5: NAF as inner sub-query + S1 threshold propagator. The lattice analysis below remains valid for the NAF-result cell; the implementation mechanism changes from async fork to on-network threshold at S1.

Currently, NAF (lines 1463-1489 of relations.rkt) forks the network and runs to quiescence SYNCHRONOUSLY inside the outer propagator's fire function, using Gauss-Seidel (NOT BSP). This blocks the entire BSP round.

**Infrastructure audit (D.2)**: The async path requires LESS new infrastructure than expected:
- `run-to-quiescence-bsp` takes a `net` parameter, CAN be called recursively, no global state conflicts
- `fork-prop-network` provides O(1) CHAMP structural sharing (copy-on-write)
- `make-parallel-thread-fire-all` already supports thread spawning
- `with-forked-network` macro explicitly supports parameterizing the network box around forks
- No global parameter conflicts (`current-use-bsp-scheduler?`, `current-parallel-executor` are all parameterizable)

**The async model** (designed directly, skipping synchronous intermediate):

A NAF propagator that:
1. When input bindings resolve, spawns a thread
2. The thread: forks network → installs inner goal → runs `run-to-quiescence-bsp` on the fork
3. On completion, writes `succeeded` or `failed` to a NAF-result cell on the OUTER network
4. A NAF-gate propagator on the outer network watches the NAF-result cell
5. The outer BSP continues with other clauses while the NAF thread runs

The difference from sync is literally: wrap the inner BSP in `thread`, write result to a cell instead of reading inline.

**SRE Lattice Lens for NAF-result cell**:
- **Q1**: VALUE lattice (ternary: unknown → succeeded / failed)
- **Q2**: Three-element chain: `unknown < succeeded`, `unknown < failed`. NOT a Boolean lattice — succeeded and failed are incomparable (choosing both = contradiction).
- **Q3**: Inner goal scope → NAF-result (projection: bindings changed? → succeeded / not → failed). NAF-result → outer conjunction (gate: failed = proceed, succeeded = block).
- **Q5**: NAF-result is derived from inner computation
- **Q6**: Hasse diagram is a three-element lattice (fork from unknown to two endpoints)

**Termination**: NAF inner goal terminates by fuel limit (propagator firings). Fork inherits fuel from parent or gets its own budget (design choice — Phase 0b data should inform whether shared fuel or per-fork fuel is better). The NAF propagator fires ONCE (fire-once pattern).

**Thread safety**: The inner BSP runs on its own thread with its own forked network. The ONLY shared write is the NAF-result cell on the outer network. Cell writes are already thread-safe (CHAMP operations are pure functional; `net-cell-write` produces a new CHAMP, doesn't mutate). The NAF-result cell write happens ONCE (fire-once).

### §3.3 Guard as Propagator — Lattice Analysis

Currently, guard evaluates its condition synchronously during installation and installs inner goals only if truthy.

**The correct model**: A guard-test propagator watches the condition's input cells. When inputs resolve, it evaluates the condition and writes the result to a guard-result cell. If truthy, the inner goals are installed via a topology request.

**SRE Lattice Lens for guard-result cell**:
- **Q1**: VALUE lattice (ternary: unknown → passed / failed)
- **Q2**: Same three-element chain as NAF
- **Q3**: Condition inputs → guard-result (evaluation). Guard-result → topology (passed = install inner goals).
- **Q5**: Guard-result is derived from condition evaluation
- **Q6**: Same three-element Hasse as NAF

**Termination**: Guard evaluation is pure (no side effects, no recursion). Fires once when inputs resolve.

### §3.4 Hypercube-Guided Optimality Lens (D.3)

The Hypercube Conversation (standup-2026-04-08.org) establishes that **the Hasse diagram of ANY lattice is the communication graph for optimal parallel computation on that lattice.** The hypercube Q_n (Hasse diagram of the Boolean lattice 2^n) is the canonical case. Our ATMS worldview space IS Q_n — structural identity, not metaphor.

This is formal ground for the second half of the Hyperlattice Conjecture: **optimality**. The Hasse diagram IS the optimal parallel decomposition. This lens must guide every design decision in this track.

#### Fact-Row Branching (Phase 1) through the Hypercube Lens

K fact rows = K-bit Boolean lattice Q_{log₂ K}. The exploration of all K fact-row results IS a traversal of Q_{log₂ K}. Gray code traversal (already implemented for multi-clause in Track 2 via `gray-code-order`) maximizes CHAMP structural sharing between adjacent fact-row explorations — each step changes one bit, adjacent states share almost all network state.

For K=8 fact rows, Q_3 has diameter 3. Gray code traversal visits all 8 results changing one bit per step. The BSP scheduler fires all 8 fact-row propagators concurrently (same round). The answer accumulator merges results via set-union (monotone, CALM-safe).

The micro-benchmark in Phase 0b should measure: does Gray code ordering of fact-row PUs actually improve CHAMP sharing compared to arbitrary ordering? At what K does the difference become measurable?

#### BSP Barrier Synchronization (Phase 4) through the Hypercube Lens

For T threads, the BSP barrier is an all-reduce operation. Flat barrier: all threads synchronize at a single point (contention). Hypercube all-reduce: log₂(T) rounds of pairwise synchronization, each thread communicates with one partner per round. Optimal for T > 4-8 threads.

The existing `make-parallel-thread-fire-all` partitions work per core count but uses flat thread joins (channel collect). Phase 0c should measure: for M-series Macs with 8-10 performance cores, is the hypercube pairwise-sync pattern faster than flat barrier?

The all-reduce pattern: round k, each thread communicates with the thread differing in bit k. After log₂(T) rounds, all threads hold the global result. This IS the BSP superstep synchronization — merge all thread-local cell writes into the global network state.

#### Async NAF (Phase 2) through the Hypercube Lens

NAF sub-computation is a **Pocket Universe**: Q_1 decomposition (NAF succeeded / NAF failed). The inner BSP runs on a forked network (Q_{n-1} × Q_1 decomposition — fixing the NAF bit to "evaluate", leaving all other assumptions free). Completion signal is a broadcast from the inner PU to the outer network — writing to the NAF-result cell.

For multiple concurrent NAF goals (rare but possible), each is an independent Q_1 decomposition. K concurrent NAFs = K independent sub-computations, each writing to its own NAF-result cell. The outer conjunction residuates on all K cells — a fan-in that IS the merge of K ternary lattice values.

#### Recursive Decomposition and fork-prop-network

`fork-prop-network` IS the Q_n = Q_{n-1} × Q_1 decomposition. Fixing one dimension (one assumption) and exploring the remaining (n-1)-dimensional sub-hypercube. CHAMP structural sharing makes this O(1) fork — the two sub-hypercubes share almost all state (only the cells affected by the fixed assumption differ).

This recursive decomposition is the structural basis for:
- Multi-clause branching (one dimension per alternative)
- Fact-row branching (one dimension per row)
- NAF evaluation (one dimension: inner goal succeeds/fails)
- Speculative type checking (one dimension per union branch)

The hypercube structure unifies all these as Q_1 decompositions composed into Q_n. The Hasse diagram IS the parallel exploration structure.

### §3.5 Conjunction — Installation Order vs Execution Order

> **NOTE (D.13)**: §3.5's characterization of `for/fold` as "acceptable scaffolding" is superseded by §3.R Phase R3: all goal installation is propagator-mediated. With fire-once propagators for ground unification, conjunction goals are truly order-independent. The `for/fold` remains at installation time (construction-time scaffolding) but no longer creates ordering dependencies because there are no construction-time direct writes.

`install-conjunction` uses `for/fold` (sequential installation). This is acceptable because:
- Installation order ≠ execution order. Propagators fire in BSP rounds regardless of installation order.
- The `for/fold` threads the network struct (needed for cell allocation). This is a construction-time concern, not an execution-time concern.
- CALM guarantees convergence regardless of firing order.

For conjunction goals with dependency chains (goal A's output feeds goal B, which feeds goal C), the **parallel prefix** algorithm from the hypercube research applies: the chain converges in O(log(chain_length)) BSP rounds instead of O(chain_length). Each goal's propagator is installed without ordering; the BSP scheduler's dataflow-driven firing naturally produces prefix-optimal convergence. NAF-gate and guard-gate propagators residuate until their input cells resolve — this IS the parallel prefix pattern (each gate is a "join" that waits for its input).

Installation order does not affect correctness (CALM) or convergence rate (BSP round count is determined by dataflow depth, not installation order). The `for/fold` is scaffolding for self-hosting — the self-hosted compiler would install conjunction goals as a broadcast (all at once, via topology request).

### §3.6 Tier 1 Optimization Pipeline (D.5 — from Phase 0b data)

Phase 0b reveals the ATMS solver is 25x slower than DFS for trivial single-fact queries. The overhead decomposes to: BSP scheduling 52.6%, goal installation 30.4%, context allocation 15.5%, result reading 0.4%. Four optimizations target each component, together aiming for <3x DFS on Tier 1 queries.

#### Optimization 1: BSP Fire-Once Fast-Path (Phase 5a, merged from critique P2+R2) — targets 52.6% BSP overhead

**The insight**: The BSP scheduler's fixed overhead (worklist dedup, fuel check, outer loop, topology stratum) is disproportionate for queries with 0-1 propagators. Fire-once propagators (which cover both fact-row writes and single-clause unification) can execute directly without scheduling ceremony.

**The mechanism**: Inside `run-to-quiescence-bsp`, at entry:
- **Empty worklist** (fact-only queries): return immediately. No scheduling needed — fact values are already in cells from `install-goal-propagator`.
- **Single fire-once propagator on worklist**: fire it directly (call its fire function, merge writes), return. No BSP loop, no topology stratum check. This is the self-cleaning property of fire-once: it fires once and becomes inert, so no second round is possible.
- **Multiple propagators or non-fire-once**: proceed to full BSP.

This is ONE fast-path inside the scheduler (not a separate caller-side check — critique P2 resolved). It handles both fact-only (worklist=0) AND single-clause (worklist=1 fire-once) queries. The scheduler handles scheduling; the solver handles solving (Decomplection).

**Expected savings**: ~12.1us for fact-only; ~8-10us for single-clause (eliminates BSP ceremony for the single fire). Combined target: Tier 1 queries under 10us.

**SRE lens**: CALM observation made operational. Fire-once propagators are trivially convergent — one fire, one merge, fixpoint. The scheduler recognizes this structurally (fire-once flag), not by counting worklist items.

#### Optimization 2: Lazy Solver-Context (Phase 5b) — targets 15.5% allocation overhead

**The insight**: `make-solver-context` allocates 7 cells + 1 projection propagator for EVERY query — even queries that never branch. The decisions cell, commitments cell, assumptions cell, nogoods cell, counter cell, and table registry cell are all unused for deterministic queries.

**The mechanism**: Replace eager `make-solver-context` with a lazy version that allocates only:
- Minimum: scope cell + answer accumulator (2 cells)
- On first `amb`: promote to full solver-context (remaining 5 cells + projection)

This is a structural optimization: the solver-context IS a lattice value that starts at bot (minimal allocation) and grows monotonically (more cells allocated as needed). Promotion is a one-time cost paid only by branching queries.

**Expected savings**: ~3.6us for Tier 1 queries (15.5% of 23us). Combined with Opt 1: ~7.3us → 8x DFS.

#### Optimization 3: Solver-Template Cell (Phase 5c, revised from critique P6/M4) — targets repeated query overhead

**The insight**: Multiple `solve` blocks in the same file each create fresh network + solver-context. CHAMP immutability enables safe reuse.

**The mechanism (on-network, per §3.8)**: A `solver-template-cell` with first-write-wins merge:
- First solver invocation: creates full context, writes to template cell
- Subsequent invocations: read template cell, fork via CHAMP (O(1))
- Merge: `(lambda (old new) (if (eq? old 'bot) new old))` — first non-bot value becomes the fixed template

No parameter. The template IS a cell value — observable, composable, on-network.

Phase 0b data: context reuse saves 33% (23.0us → 15.5us). For 50 sequential solves, ~375us total.

**Expected savings**: ~7.5us per query after first. Amortized over N queries: `(7.5 * (N-1)) / N` us.

#### Combined Optimization Target

| Optimization | Targets | Savings (us) | Cumulative ATMS (us) | vs DFS |
|---|---|---|---|---|
| Baseline | — | — | 23.0 | 25.3x |
| 5a: Fire-once fast-path (merged 5a+5c) | BSP scheduling (52.6%) | ~12.1 | ~10.9 | ~12x |
| 5b: Lazy solver-context | Allocation (15.5%) | ~3.6 | ~7.3 | ~8x |
| 5c: Solver-template cell | Repeated query amortization | ~7.5 (amortized) | ~4.0 (amort.) | ~4.4x |
| **All combined (Tier 1)** | | | **~3-5** | **~3-5x** |

Target: <5x DFS for Tier 1 deterministic queries. For Tier 2 branching queries, the overhead is already more acceptable (8.3x for 3-clause) and the propagator solver provides genuine parallelism that DFS cannot.

#### Architectural Integrity

All three optimizations preserve the on-network architecture:
- **5a** recognizes fire-once convergence structurally (flag-based, not conditional check) — fires directly, no scheduling ceremony
- **5b** defers allocation, doesn't eliminate it — branching queries still get the full context
- **5c** is a scheduler optimization inside `run-to-quiescence-bsp` — transparent to callers
- **5d** reuses CHAMP snapshots — immutability guarantees isolation

None introduce off-network state. None create special cases that bypass the propagator model. They recognize that the GENERAL infrastructure has fixed costs that are amortizable for the COMMON case.

#### NAF Adaptive Dispatch (from S4 data)

Phase 0b S4 shows async NAF costs 13x sync (4.1us vs 0.31us). This argues for adaptive dispatch:
- **Facts-only inner goal**: sync NAF (inner computation is trivial, thread overhead dominates)
- **Clause-bearing inner goal**: async NAF (inner computation is expensive, thread overhead is amortized)
- **Heuristic**: if the inner goal's relation has clauses (not just facts), use async

This is not a special case but an optimization: the choice between sync and async is an implementation detail of the NAF propagator, invisible to the outer network.

### §3.7 Hypercube Merge Topology for BSP Barriers (D.6)

The current parallel executor uses a **star topology** for result collection:

```
Dispatch:  dispatcher ──→ K workers     (fan-out, 1 round, K sends)
Execute:   K workers fire independently
Collect:   K workers ──→ dispatcher     (fan-in, 1 round, K sequential channel-gets)
                                         ^^^^ bottleneck: sequential merge
```

The collection phase is sequential: `(apply append (for/list ([ch ...]) (channel-get ch)))` — K channel-gets in order. For K=8, this is 8 × 1.57us = 12.6us of channel overhead alone.

#### The Structural Insight

Merging K workers' cell writes IS a **lattice join** — cell merge functions are lattice joins by construction. The Hyperlattice Conjecture's optimality claim: **the Hasse diagram of the lattice IS the optimal communication topology.**

For lattice join of K values, the Hasse diagram gives the **binary merge tree** — which IS the hypercube all-reduce:

```
Star (current):
  w₀ ─┐
  w₁ ─┤
  w₂ ─┼──→ collector (8 sequential merges)
  ...  ┤
  w₇ ─┘

Hypercube all-reduce (log₂ K rounds of pairwise merge):
  Round 1: (w₀⊕w₁) (w₂⊕w₃) (w₄⊕w₅) (w₆⊕w₇)   — 4 independent merges
  Round 2: (w₀₁⊕w₂₃) (w₄₅⊕w₆₇)                  — 2 independent merges
  Round 3: (w₀₁₂₃⊕w₄₅₆₇)                          — 1 merge → global result
```

Star: 1 round, K sequential merges (collector bottleneck).
Hypercube: log₂(K) rounds, each with K/2^round **independent parallel** merges.

For K=8: star = 8 sequential merges; hypercube = 3 rounds of 4→2→1 parallel merges. Each round's merges are independent — they can run in parallel (CHAMP merges are pure functional).

#### CHAMP Structural Sharing Benefit

Pairwise merge preserves CHAMP structural sharing better than sequential merge. When w₀'s CHAMP and w₁'s CHAMP are merged, the result shares structure with both inputs (Hamming distance 1 in the hypercube). When that merged result merges with w₂₃'s result, sharing cascades through the tree. Sequential merge (star) builds a progressively larger CHAMP that shares less with later workers' contributions.

This connects to Gray code: the hypercube all-reduce's pairwise merge follows the Hasse diagram's adjacency — each merge combines maximally-sharing pairs.

#### Cost Model

| Topology | Communication | Merge rounds | Total cost (K=8, shared-memory) |
|---|---|---|---|
| Star (channels) | K × 1.57us | K sequential | ~12.6us |
| Star (shared-memory) | K × 0.01us | K sequential | ~0.08us + merge time |
| **Hypercube (shared-memory)** | log₂(K) × 2 × 0.01us | log₂(K) parallel | **~0.06us + parallel merge time** |

With shared-memory coordination (semaphore-gated buffers), the hypercube topology reduces both communication AND merge costs. The merge time itself is parallelized — at each round, K/2^r independent merges run simultaneously.

#### Propagator Network Description

The merge tree IS a propagator network. Each pairwise merge is a propagator that reads two input cells and writes to an output cell:

```
;; Merge tree for K=8 workers (log₂ 8 = 3 levels of depth)
;;
;; Level 0 (inputs): cells w₀ w₁ w₂ w₃ w₄ w₅ w₆ w₇
;;                     ↘↙     ↘↙     ↘↙     ↘↙
;; Level 1 (merges):  m₀₁    m₂₃    m₄₅    m₆₇     ← 4 merge propagators
;;                      ↘↙         ↘↙
;; Level 2 (merges):  m₀₁₂₃      m₄₅₆₇              ← 2 merge propagators
;;                        ↘↙
;; Level 3 (result):  m₀₁₂₃₄₅₆₇                      ← 1 merge propagator
;;
;; Each merge propagator: reads 2 cells, writes merged result to output cell
;; Fire function: (cell-merge (net-cell-read left) (net-cell-read right))
;; All propagators at each level are INDEPENDENT — fire in same BSP round
;; Depth = log₂(K) — the number of BSP rounds to reach global merge
```

The merge tree's depth (log₂ K) determines the BSP round count. This is EMERGENT from the propagator topology — not imposed by a scheduling algorithm. The BSP scheduler fires all propagators whose inputs are available; at each round, the next level's inputs become available from the previous level's outputs. The "rounds" ARE BSP supersteps.

For CHAMP specifically: each pairwise merge preserves structural sharing (Hamming-adjacent entries share almost all structure). The tree topology produces optimal CHAMP sharing because adjacent workers (differing by one bit position) are merged first.

After log₂(K) supersteps, the root cell holds the global merged result.

#### Scope Decision

This is a significant optimization but architecturally clean — it changes the BSP barrier's merge topology without affecting the propagator model. Options:
- **Phase 6 scope**: implement alongside `:auto` switch as the production parallel executor
- **Future track**: defer to PAR Track 2 (parallel scheduling) where it compounds with other parallel optimizations
- **Data-driven**: implement Phase 5a-5d first (Tier 1 fast-path), re-measure. If Tier 1 is <5x DFS, the parallel executor is less urgent and can be deferred

### §3.8 Self-Hosting Lens — On-Network Mandate for All Compiler State (D.7)

The self-critique (P1, P5, P6, M1, M4) dismissed five instances of off-network state as "constants," "static data," or "write-once parameters." The self-hosting lens challenges ALL five dismissals: **in the self-hosted compiler, all compiler state flows through cells. "Constant" is a lattice element at fixpoint after one write — it still belongs on-network.**

#### Why Off-Network Constants Are Self-Hosting Debt

The self-hosted compiler runs ON the propagator network. It needs to:
- **Observe** its own state (debugging, tracing, introspection)
- **Compose** state from different compiler phases (relation registration → clause selection → solver execution)
- **Extend** state incrementally (new modules add new relations → discrimination map grows)

Off-network constants are invisible to all three. A discrimination map in a hasheq is opaque — the compiler can't trace how it was derived, compose it with other lattice values, or extend it when new clauses arrive.

#### Revised Design Decisions

**1. Discrimination map → discrimination cell** (was P5, "justified constant")

The discrimination map IS derived information:
- **Source**: relation registration (writes clause heads to relation registry cell)
- **Derivation**: extract ground values at each position from clause heads/first-goals
- **Lattice**: `hasheq position → (hasheq value → (listof clause-index))`, with hash-union merge (new clause registrations extend the map monotonically)
- **Merge**: `(hash-union old new #:combine append)` — new clauses ADD to existing position entries

At self-hosting, the discrimination map is a cell written by a propagator that watches the relation registry cell. When a new clause is registered, the propagator fires and updates the discrimination map. This is reactive, not computed-once.

Cost: one cell allocation per relation. Near-zero ongoing cost. Benefit: the map is observable, composable, and extensible on-network.

**2. Construction-time narrowing → reactive narrowing always** (was P1/M1, "acceptable optimization")

The self-hosting lens eliminates the need for two mechanisms. The arg-watcher propagator IS the general mechanism:
- When arguments are ground at query time, the watcher fires **immediately in BSP round 1** — the "construction-time optimization" falls out naturally from BSP scheduling
- When arguments are partially bound, the watcher fires **when information arrives** — same mechanism, no separate path
- No imperative dispatch, no construction-time filter, no bifurcation

One mechanism. Information flow. The BSP scheduler handles timing. This is SIMPLER than the D.6 design (which had two paths) and MORE aligned with the propagator model.

**3. Context pool → solver-template cell** (was P6/M4, "write-once parameter acceptable")

The solver-template is information about available solver infrastructure. On-network:
- **Cell**: `solver-template-cell` with first-write-wins merge
- **Write**: first solver invocation creates the template, writes to cell
- **Read**: subsequent invocations read the cell, fork via CHAMP
- **Merge**: `(lambda (old new) (if (eq? old 'bot) new old))` — first non-bot value wins

No parameter. The template IS a cell value. The network can observe it, compose with it, and (at self-hosting) the compiler can reason about available solver infrastructure through the network.

#### Summary: Off-Network → On-Network

| Item | D.6 (dismissed) | D.7 (on-network) | Self-hosting benefit |
|---|---|---|---|
| Discrimination map | Static hasheq, off-network | Cell with hash-union merge | Reactive updates when new clauses registered |
| Construction-time narrowing | Imperative filter for ground args | Arg-watcher fires in BSP round 1 | One mechanism, no bifurcation |
| Context pool | `make-parameter`, write-once | Cell with first-write-wins merge | Observable solver infrastructure |

The cost is ~2 additional cell allocations. The benefit is architectural integrity for self-hosting and design simplification (one narrowing mechanism instead of two).

---

## §4 NTT Model

```
;; ===== Clause Selection as Decision-Cell Narrowing (Phase 1a) =====

;; Clause viability = decision cell (Track 2 infrastructure)
lattice ClauseViability : DecisionDomain where
  bot   = {0, 1, ..., N-1}   -- all clauses viable
  top   = {}                  -- contradiction
  merge = set-intersection    -- narrowing

cell clause-decision : ClauseViability := bot

;; Discrimination map (static, computed at registration)
;; position -> (value -> [clause-indices])
;;   e.g., {0: {"red" -> [0], "blue" -> [1], "green" -> [2]}}

;; Argument-watching propagator: narrows clause decision on ground arrival
propagator arg-watcher
  :reads  [arg-cell-k : TermCell]       -- query argument at position k
  :writes [clause-decision : ClauseViability]
  :fire-once true
  fire =
    let val = read arg-cell-k
    if val is ground:
      let compatible = discrimination-map[k][val]  -- {clause-indices}
      narrow clause-decision to compatible
    else:
      no-op  -- all clauses remain viable for unbound args

;; Surviving fact rows get per-row PU branching (same as multi-clause)
propagator fact-row-propagator
  :reads  [resolved-args : TermCell]
  :writes [scope-vars : ScopeCell, answer-acc : AnswerSet]
  :worldview bit-k  -- per-row isolation
  :assumption aid   -- gated on clause-decision viability
  :fire-once true
  fire = unify row-terms with resolved-args,
         write bindings to scope-vars (tagged with bit-k),
         write result to answer-acc

;; ===== NAF as Async Propagator (Phase 2) =====

lattice NafResult : {unknown, succeeded, failed} where
  bot  = unknown
  join = \cases
    (unknown, x) -> x
    (x, unknown) -> x
    (x, x)       -> x
    _             -> contradiction  -- succeeded + failed = impossible

cell naf-result : NafResult := unknown

propagator naf-evaluator
  :reads  [input-bindings : ScopeCell]  -- outer scope
  :writes [naf-result : NafResult]      -- on OUTER network
  :fire-once true
  :async true                           -- D.2: async from start
  fire =
    spawn-thread:                       -- parallel-ready
      let inner-net = fork-prop-network(outer-net)
      install inner-goal on inner-net
      run-to-quiescence-bsp(inner-net)  -- BSP, not Gauss-Seidel
      if inner produced bindings:
        write succeeded to naf-result   -- cross-network cell write
      else:
        write failed to naf-result
    ;; Outer BSP continues; NAF-gate fires when cell resolves

;; Outer conjunction residuates on naf-result
propagator naf-gate
  :reads [naf-result : NafResult]
  :writes [continuation-scope : ScopeCell]
  :fire-once true
  fire =
    match naf-result:
      failed    -> write current scope to continuation (NAF succeeds)
      succeeded -> no-op (NAF fails, clause blocked)
      unknown   -> residuate (don't fire yet)

;; ===== Guard as Propagator (Phase 3) =====

lattice GuardResult : {unknown, passed, failed} where
  bot  = unknown
  join = same as NafResult

cell guard-result : GuardResult := unknown

propagator guard-evaluator
  :reads  [condition-inputs : ScopeCell]
  :writes [guard-result : GuardResult]
  :fire-once true
  fire =
    evaluate condition with current bindings
    if truthy: write passed
    else:      write failed

propagator guard-gate
  :reads [guard-result : GuardResult]
  :writes [-- topology request to install inner goals --]
  :fire-once true
  fire =
    match guard-result:
      passed  -> emit topology-request(install inner-goals)
      failed  -> no-op (guard fails, clause blocked)
      unknown -> residuate
```

#### Conjunction Wiring (D.8 — critique M5)

```
;; ===== Conjunction: how goals compose =====
;; Conjunction is NOT sequential installation — it is a dataflow topology.
;; Each goal's output cells ARE the next goal's input cells (shared scope).

;; Example: conjunction of [unify-goal, naf-goal, app-goal]
;;
;;   scope-cell (shared across all goals)
;;       ↑ writes              ↑ reads           ↑ reads+writes
;;   [unify-propagator]   [naf-evaluator]    [app clause propagators]
;;                              ↓ writes
;;                         naf-result cell
;;                              ↓ reads
;;                         [naf-gate]
;;                              ↓ writes (on success)
;;                         scope-cell (continuation)
;;
;; Dataflow: unify writes to scope → naf-evaluator reads scope →
;;   naf writes to naf-result → naf-gate reads result →
;;   gate writes continuation → app reads continuation scope
;;
;; Ordering EMERGES from cell dependencies:
;;   - naf-evaluator residuates until scope has non-bot bindings
;;   - naf-gate residuates until naf-result resolves
;;   - app clause propagators residuate until their input bindings resolve
;;
;; Guard wiring (similar):
;;   guard-evaluator reads condition inputs from scope →
;;   writes guard-result → guard-gate reads result →
;;   gate emits topology-request (inner goals installed in SAME scope) →
;;   inner goals fire in next BSP round, writing to shared scope

;; All goals installed simultaneously (broadcast, no ordering).
;; BSP scheduler fires those whose inputs are available.
;; Convergence follows parallel prefix pattern: O(log(depth)) rounds
;; for chains of depth D.
```

### NTT Model Observations

1. **Is everything on-network?** Yes. NAF result, guard result, and fact-row branching all flow through cells. The NAF inner computation is a nested BSP (Pocket Universe) on a forked network. The cross-network write (NAF thread → outer network's NAF-result cell) is the ONLY shared-state interaction.

2. **Did the model reveal impurities?** The D.1 impurity (synchronous NAF) is resolved in D.2 by async design. The remaining impurity is the **cross-network cell write**: the NAF thread writes to a cell on the outer network. This is thread-safe (CHAMP is pure functional, cell write produces new CHAMP), but the outer BSP scheduler needs to detect the new write and schedule the NAF-gate propagator. This may require a "pending writes from sub-networks" queue that the BSP outer loop checks between rounds.

3. **Did the model reveal NTT syntax gaps?** Yes:
   - NTT has no syntax for `:async` propagators or `spawn-thread`
   - NTT has no syntax for cross-network cell writes
   - A `sub-network` construct and `async-fire` keyword would be useful NTT extensions

4. **Termination arguments**:
   - Fact-row propagators: fire-once, terminates trivially
   - NAF evaluator: inner goal terminates by fuel limit on forked network (independent fuel budget). Fire-once. Thread terminates when inner BSP quiesces.
   - Guard evaluator: pure evaluation, no recursion. Fire-once.
   - NAF/guard gates: fire-once, triggered by result cell.
   - Async thread: bounded by fork's fuel. No unbounded spawning (one thread per NAF goal, NAF goals are finite).

---

## §5 Phased Roadmap

### Phase 0: Investigation + Benchmarks (~3-4h)

Phase 0 is design input, not validation. Its findings may change Phases 1-4 scope and ordering.

#### Phase 0a: Parity Baseline (~1-2h)

**Objective**: Establish the exact gap between DFS and propagator solver across ALL 95 test files.

**Steps**:
1. Create a parity test harness that runs each test file's `defr`/`solve` expressions through BOTH `:strategy :depth-first` AND `:strategy :atms`
2. Compare results using **set-equality** (not ordered comparison). Non-deterministic multiple solutions have no canonical ordering; requiring order-parity would assert an implementation detail of DFS, not a semantic property.
3. Categorize every failure: fact-row (expected), NAF (expected), guard (expected), cut (expected), depth-limit (expected), OTHER (investigate)
4. Record which tests assert on result ordering — these need adjustment for set-equality

**Deliverable**: Parity matrix (95 files × pass/fail per strategy) + failure categorization + list of order-dependent tests.

**Design input**: The categorization may reveal gaps not identified in §2.3. If the failure count is <10, the track scope may be smaller than estimated. If >50, there may be fundamental issues beyond the 5 identified gaps.

#### Phase 0b: Micro-Benchmarks (~1h)

**Objective**: Data-driven answers to open design questions.

**Benchmarks to run** (using `bench-micro.rkt` infrastructure for statistical rigor):

1. **Fact-row PU overhead**: Measure solve-goal-propagator on a fact-only relation with N rows, for N = 1, 2, 4, 8, 16, 32. Compare:
   - Current (last-write-wins, no PU branching)
   - Per-row PU branching (with tagged-cell-value)
   - Measure: wall time, cell allocations, propagator firings

   This determines the **fact-row threshold**: at what N does PU branching become worth the overhead? The D.1 estimate of N=4 was borrowed from broadcast A/B data (different mechanism). We need fact-row-specific data.

2. **NAF sync vs async overhead**: Measure a relation with NAF goals:
   - Current (Gauss-Seidel fork, inline quiescence)
   - BSP fork (same thread, BSP scheduler on inner)
   - Thread-spawned BSP fork (new thread, async result)
   - Measure: wall time, thread creation overhead, BSP round count

3. **Fuel consumption profile**: Run adversarial benchmarks with verbose output, measure fuel consumption per relation. This informs whether shared-fuel or per-fork-fuel is better for NAF.

4. **Gray code vs arbitrary ordering**: For multi-clause and fact-row branching, measure CHAMP allocation count with Gray code ordering vs arbitrary bit assignment. The hypercube lens predicts Gray code should minimize CHAMP structural divergence between adjacent branches. Measure at N=4, 8, 16.

5. **Hypercube all-reduce vs flat barrier**: For the parallel thread executor, measure BSP barrier overhead with flat join (current) vs hypercube pairwise-sync pattern. Test at T=2, 4, 8 threads on M-series hardware.

#### Phase 0c: A/B Executor Comparison (~1h)

**Objective**: Determine which parallel executor should be default.

**Method**: Run `bench-ab.rkt` comparative suite with three configurations:
1. `sequential-fire-all` (current default)
2. `make-parallel-fire-all` (futures, threshold=4)
3. `make-parallel-thread-fire-all` (OS threads, per-core partitioning)

On BOTH the standard comparative suite (13 programs) AND the adversarial benchmarks (designed for N-clause stress). Use `--runs 15` for statistical significance.

**Deliverable**: Performance matrix (3 executors × 13+ programs) with Mann-Whitney U significance tests. This directly answers: which executor should be default?

### Phase 1a: Clause Selection as Decision-Cell Narrowing (~3-4h)

**Objective**: Bound arguments narrow clause/fact-row selection via decision cell. Fixes Category 1 (fact-row last-write-wins) AND Category 2 (multi-clause variable binding).

**Steps**:
0. **GS-to-BSP switch** (critique P1/R1 prerequisite): Change `solve-goal-propagator` line 1889 from `run-to-quiescence` to `run-to-quiescence-bsp`. This is the foundational change — BSP IS the architecture. Arg-watcher propagators need BSP rounds to fire reactively. Micro-benchmark after switch to measure Tier 1 cost delta (GS vs BSP baseline).

1. **Discrimination cell allocation** (~50 lines in `relations.rkt`, critique P4):
   - For fact rows: extract ground values at each position
   - For clause bodies: peek at first unification goal to extract discriminating value
   - Write to a **discrimination cell** (on-network per §3.8) with hash-union merge
   - Allocate cell at relation registration time; write map eagerly (scaffolding — self-hosting: derivation propagator watches relation registry cell)
   - **Limitation (critique R1)**: clauses with non-unification first goals (`app`, `is`, `guard`) are wildcards — no discrimination at that position

2. **Clause decision cell** (~30 lines):
   - At solve time, create a `decisions-state` for the relation's clauses/fact-rows
   - Alternatives = all clause/fact-row indices
   - Wire into the existing `solver-context` infrastructure

3. **Argument-watching propagator** (~50 lines):
   - For each discriminating position, install a fire-once propagator
   - Watches the query argument cell at that position
   - On ground value arrival: look up discrimination map, narrow decision cell
   - Non-matching clauses become inert (assumption bit cleared)

4. **Gate clause installation on decision cell** (~30 lines):
   - `install-clause-propagators` reads the clause decision cell
   - Only installs propagators for clauses still in the viable set
   - Fact-row writes only execute for matching rows

5. **Per-fact-row PU branching** (~60-80 lines, mirrors multi-clause PU infrastructure, critique R2):
   - Surviving fact rows get worldview bitmask bits via `solver-assume` (same counter as multi-clause — critique R3: coordinated namespace prevents collision for mixed fact+clause relations)
   - Gray code ordering for CHAMP sharing
   - Answer accumulator collects all tagged results

**Tests**: All parity-adversarial.prologos sections P1 + P2 must match DFS results. `fact16 8 ?y` returns 1 result. `five-way 3 ?y` returns 1 result. `five-way ?x ?y` returns 5 results.

**Discrimination map limitation (critique R1)**: Clauses whose first goal is NOT a unification (`app`, `is`, `guard`) are **wildcards** in the discrimination map — they match any argument value at all positions. For relations where ALL clauses start with non-unification goals, the map is empty and no narrowing occurs (all clauses tried). This is correct behavior but should be noted: the optimization benefits relations with unification-first clause heads (the common case for `defr` with `&>` clauses and fact rows).

**Estimate (critique R3)**: ~210 lines (revised from ~150). Breakdown: discrimination cell extraction (~50), clause decision cell (~30), arg-watcher propagator (~50), clause installation gating (~30), fact-row PU branching (~30), relation-register integration (~20).

**Test plan (critique R5)**: Phase 1a must include 5 test categories:
- (a) Narrowing with bound arguments — `five-way 3 ?y` returns 1 result
- (b) No narrowing with free arguments — `five-way ?x ?y` returns 5 results
- (c) Partial binding — `fact16 8 ?y` returns 1 result from 16 rows
- (d) Wildcard first goals — clauses with `app`/`is` first goal are not filtered
- (e) Mixed facts + clauses — `hybrid ?x ?y` returns results from both fact rows and clause bodies

**Vision gate**: On-network? Discrimination cell + arg-watcher propagator + clause decision cell. Complete? Facts + clauses unified. Vision-advancing? Clause selection IS information flow (lattice narrowing on decision cell), not imperative filtering. Self-hosting: discrimination cell is reactive to new clause registrations (§3.8).

### Phase 1b: Position-Discriminant Analysis (~2h)

**Objective**: Needed-narrowing-inspired optimization: identify best discriminating argument position, build hierarchical narrowing.

**Steps**:
1. **Position scoring**: For each argument position, count how many distinct groups the discrimination map creates. Best = most groups (highest discrimination power).
2. **Hierarchical tree building**: If position p0 groups clauses into subgroups, recurse: within each subgroup, find the next best position p1. Build a tree of (position, value → subgroup) entries.
3. **Nested decision cells**: Each tree level becomes a decision cell on the network. Level 0 narrows on p0. Level 1 narrows on p1 within each group. Propagators watch the corresponding argument cells.
4. **Integration**: Store the discrimination tree alongside `variant-info` at registration time. At solve time, use the tree to guide propagator installation.

**Tests**: Relations with multiple discriminating positions (e.g., 2-arg relation where both args have unique values per clause). Verify that narrowing cascades correctly through levels.

**Vision gate**: On-network? Nested decision cells. Complete? Multi-position discrimination. Vision-advancing? The tree IS the Hasse diagram of the clause decomposition.

### Phase 2a+2b: NAF as Worldview Assumption + S1 Nogood Elimination (~2-3h)

**Objective**: NAF goals get worldview assumptions (same as clause branches). NAF-dependent writes are tagged with the NAF bitmask. S1 stratum validates NAF assumptions by checking provability at S0 fixpoint. Invalid NAF assumptions → nogoods → Track 2 worldview narrowing eliminates them. Tagged-cell-value filtering makes correct results visible. REUSES EXISTING INFRASTRUCTURE ENTIRELY.

**Key architectural insight (D.12 design conversation)**: NAF is a stratification ON TOP of worldviews, not a separate mechanism alongside them. Each NAF assumption IS a worldview element — the assumption `h_naf` means "this NAF succeeded." The S1 stratum determines which NAF assumptions are valid by checking inner goal provability. Invalid NAF assumptions are eliminated via nogoods — the SAME mechanism Track 2 uses for clause branch elimination. No new cells, no new result-reading filters, no step-think.

**The structural model**: worldviews × NAF = Q_n × Q_1^k

Each NAF goal adds a Q_1 dimension to the worldview space. The combined space is the product lattice. Nogoods express which combinations in the product are contradicted. Tagged-cell-value filtering on the product gives the correct results.

```
S0: Positive goals reach fixpoint
    - Clause branches: assumptions h_1, h_2, ..., h_m (from solver-assume)
    - NAF assumptions: h_naf_1, h_naf_2, ..., h_naf_k (from solver-assume)
    - NAF-dependent writes tagged with h_naf_i (via wrap-with-worldview)
    - All goals fire concurrently; worldview filtering isolates branches

S1: Validate NAF assumptions via provability check
    - For each NAF h_naf_i: is the inner goal provable at S0 fixpoint?
    - If provable: {h_naf_i} is a nogood (or {h_branch_j, h_naf_i} for branch-dependent)
    - Write nogoods → Track 2 infrastructure narrows worldview
    - If any narrowing: back to S0 (tagged writes under eliminated assumptions become invisible)

Result: worldview filtering in tagged-cell-read produces correct results
    - NAF-succeeded branches: h_naf assumption present → tagged writes visible
    - NAF-failed branches: h_naf assumption eliminated → tagged writes invisible
    - Branch-dependent NAF: per-branch nogoods eliminate specific (branch, NAF) combinations
```

**Why this reuses Track 2 infrastructure entirely**:
- `solver-assume` → allocates NAF assumption (same as clause branches)
- `wrap-with-worldview` → tags NAF-dependent writes (same as concurrent clauses)
- `promote-cell-to-tagged` → enables worldview tagging (same as multi-clause)
- `solver-add-nogood` → registers NAF provability contradictions (Track 2 Phase 3)
- `tagged-cell-read` worldview filtering → makes correct results visible (already works)
- No NAF-result cells. No NAF filters in result reading. No step-think.

**Phase 2a: NAF Assumption + S0 Installation** (~20 lines in relations.rkt):

1. `install-goal-propagator` ('not case):
   a. Get fresh NAF assumption via `solver-assume` (provides h_naf bit position)
   b. Promote outer scope cells to tagged-cell-value (same as multi-clause)
   c. Install subsequent goals in the conjunction under `wrap-with-worldview(h_naf)` — their writes are tagged with the NAF assumption
   d. Register the NAF for S1 evaluation (record: inner-goal, env, store, h_naf)
   e. Return — no inner goal installation at S0

2. No result-reading changes needed — worldview filtering handles NAF automatically

**Phase 2b: S1 NAF Nogood Stratum** (~40-50 lines in propagator.rkt + relations.rkt):

1. Add S1 stratum to `run-to-quiescence-bsp` outer loop
2. For each registered NAF: check inner goal provability via discrimination
   - Resolve args against S0 fixpoint (read scope cells with their final values)
   - Build discrimination data, compute viable set
   - If viable → inner provable → `solver-add-nogood` for `{h_naf}` (or `{h_branch, h_naf}`)
   - If not viable → inner not provable → h_naf remains valid (no action)
3. Nogoods trigger Track 2 narrowing → worldview contracts → back to S0 if changed

**Branch-dependent NAF** (`not(= ?x ?y)` where x, y vary per branch):
- S1 resolves `?x` and `?y` under EACH branch's worldview bitmask
- For branch h_j: read `(logic-var-read net x)` under bitmask including h_j
- If `x = y` under h_j: `{h_j, h_naf}` is a nogood (NAF fails for this branch)
- If `x ≠ y` under h_j: valid (NAF succeeds for this branch)
- Per-branch nogoods compose with the worldview lattice structurally

**Tests**: All adversarial parity P3 cases. Ground NAF, variable NAF, multi-branch NAF, cross-relation NAF, branch-dependent NAF.

**Vision gate**: On-network? NAF assumption IS a worldview element. Writes tagged. Nogoods flow through Track 2 infrastructure. Complete? Handles all cases structurally. Vision-advancing? NAF is NOT a special mechanism — it IS worldview assumption + stratified validation. One infrastructure for branches AND negation.

### Phase 3: Guard as Propagator (~2-3h)

**Objective**: Replace synchronous guard evaluation with a guard-test propagator that supports inner-goal continuation.

**Steps**:
1. Define `guard-result` lattice (same three-element as NAF)
2. Create `install-guard-propagator` that:
   a. Allocates a guard-result cell
   b. Installs a fire-once propagator that evaluates the condition when inputs resolve
   c. **Capture `current-is-eval-fn` at installation time** (critique R6 — parameter must survive into propagator fire context, especially under parallel executor)
   d. On `passed`: emits a topology request to install inner goals (in the conjunction's scope — the topology request carries the env and answer-cid, per NTT conjunction wiring)
   e. On `failed`: no-op (clause fails)
3. Handle guard with inner body: when guard passes, install inner goals via topology request (between BSP rounds). Note: adds one BSP outer round per guard (critique M4 — acceptable, CALM-safe cost of dynamic topology mutation)
4. Verify semantic parity: DFS guard evaluation + inner-goal continuation

**Tests**: Guard-specific test cases. Guards with inner bodies. Guards chained in a conjunction (verify O(log N) convergence via parallel prefix, not O(N)).

**Vision gate**: On-network? Guard result is a cell. Topology request is the CALM-safe protocol. Complete? Inner-goal continuation supported. Vision-advancing? Guard as data-driven topology mutation.

### Phase 5a: BSP Fire-Once Fast-Path (~2h)

**Objective**: Inside `run-to-quiescence-bsp`, fire-once propagators execute directly without BSP scheduling ceremony. Handles fact-only (empty worklist) AND single-clause (one fire-once propagator) queries. Targets the 52.6% BSP overhead.

**Steps** (all INSIDE the BSP scheduler — caller does not check):
1. At entry to `run-to-quiescence-bsp`, check worklist
2. If empty: return immediately (fact-only queries — values already in cells)
3. If single fire-once propagator: fire it directly, merge writes, return (no BSP loop, no topology stratum, no outer loop). The fire-once flag IS the structural recognition that this propagator converges trivially.
4. If multiple propagators or non-fire-once: proceed to full BSP

**This is ONE fast-path inside the scheduler** (critique P2 resolution — not a caller-side check). The scheduler handles scheduling; the solver handles solving (Decomplection). Fire-once is the structural mechanism (from Track 2 infrastructure) — not a conditional worklist-length check.

**Tests**: Parity-adversarial P1 fact queries + single-clause queries. Benchmark target: Tier 1 under 5us (from 23us baseline).

### Phase 5b: Lazy Solver-Context as Monotone Cell Refinement (~2h)

**Objective**: Defer allocation of decisions/commitments/assumptions/nogoods/counter/table-registry cells until first `amb`. For Tier 1 queries, these are never used.

**Steps**:
1. Solver-context IS a cell whose value is a lattice element: `{minimal, full}` with `minimal < full`, merge = max
2. Minimal context: 2 cells (scope + answer accumulator) — sufficient for Tier 1
3. On first `amb`: write `full` to the context cell, triggering allocation of remaining 5 cells + projection propagator
4. Promotion IS a cell write, not a boolean flag check (critique M2 resolution)

**Tests**: Tier 1 queries work with minimal context. Tier 2 (branching) queries promote via cell write and work correctly. Verify promote-cell-to-tagged handles minimal context (R4 verified safe in §2.11).

### Phase 5c: Solver-Template Cell (~2h)

**Objective**: Reuse solver-context across queries via on-network template cell with CHAMP fork.

**Steps** (on-network per §3.8, critique P6/M4 resolution):
1. `solver-template-cell` with first-write-wins merge: `(lambda (old new) (if (eq? old 'bot) new old))`
2. First solver invocation: creates full context, writes template to cell
3. Subsequent invocations: read cell, fork via CHAMP (O(1))
4. No parameter — the template IS a cell value, observable and composable

**Tests**: 50 sequential solves (atms-adversarial A7) — measure per-query savings vs fresh allocation.

### Phase 6: `:auto` Switch + Adaptive Parallel Executor (~2-3h)

**Objective**: Make the propagator solver the default. Parallel executor enabled adaptively (sequential default, threads at N≥128).

**Steps**:
1. **Re-run parity matrix**: After Phases 1-3 + 5a-5c, all test files should pass through `:atms`
2. **Flip `:auto`**: Change `stratified-eval.rkt` dispatch from `solve-goal` to `solve-goal-propagator`
3. **Adaptive executor**: Sequential default. BSP scheduler checks worklist size; enables thread executor when N≥128 (from Phase 0c scaling data). Futures eliminated (never beneficial, Racket VM restriction).
4. **A/B benchmarks**: Comparative suite with `:depth-first` vs `:atms`. Acceptance: ≤15% regression on Tier 1, measurable benefit on Tier 2.
4. **Flip `:auto`**: Change `stratified-eval.rkt` line ~200 from `solve-goal` to `solve-goal-propagator`
5. **Full regression gate**: 397/397 files, all pass

**Tests**: Full suite as regression gate. A/B benchmarks as performance gate.

**Vision gate**: On-network? `:auto` routes to propagator solver. Complete? DFS retained as `:depth-first` fallback. Vision-advancing? The propagator solver IS the solver.

### Phase T: Parity Regression Suite

**Objective**: Ensure long-term parity between strategies.

Create `test-solver-parity.rkt` that runs a representative subset of solver queries through BOTH strategies and asserts identical results. This becomes a permanent regression test.

---

## §6 WS Impact

This track does NOT add or modify user-facing syntax. All changes are internal solver infrastructure. No WS impact analysis needed.

---

## §7 Risk Analysis

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| NAF semantic divergence (propagator produces different results than DFS) | Medium | High | Phase 0a adversarial caught 3 divergences. DFS retained as `:depth-first` fallback. |
| Parallel executor introduces non-determinism | Low | High | BSP guarantees confluence (CALM). Parallel changes firing order, not results. |
| **Tier 1 performance regression >5x DFS** | **High** | **High** | **Phase 0b: currently 25x. Optimizations 5a-5d target <5x. A/B gate after each.** |
| Optimizations 5a-5d don't compound as expected | Medium | Medium | Each optimization measured independently via A/B. If target not met, DFS retained for Tier 1 via tiered dispatch. |
| Lazy context promotion (5b) creates mid-query allocation spike | Low | Medium | Promotion is one-time per query. CHAMP allocation is amortized. |
| Context pooling (5d) leaks state between queries | Low | High | CHAMP immutability guarantees isolation. Fork creates independent snapshot. |
| Fact-row branching increases cell allocation significantly | Low | Low | Phase 0b S2: narrowing is sub-microsecond. PU branching adds K bitmask bits — same as multi-clause. |
| Guard topology requests create BSP round overhead | Low | Low | One topology request per guard. Topology stratum runs between value strata. |

---

## §8 Files Modified

| File | Phases | Changes |
|---|---|---|
| `relations.rkt` | 1a, 1b, 2, 3, 5a, 5b, 5d | Clause selection, fact-row PU, NAF propagator, guard propagator, fast-paths, lazy context, pooling |
| `stratified-eval.rkt` | 0a, 6 | Strategy override parameter; `:auto` → propagator |
| `propagator.rkt` | 5c, 6 | BSP empty-worklist fast-path; `current-parallel-executor` default |
| `atms.rkt` | 5b, 5d | Lazy solver-context; context pooling |
| `decision-cell.rkt` | 1a, 2, 3 | Clause viability, NAF-result, guard-result lattice values |
| `test-propagator-solver.rkt` | 1a, 1b, 2, 3 | Extended with clause selection, fact-row, NAF, guard tests |
| `test-solver-parity.rkt` | T | NEW — parity regression suite |
| `bench-track2b-solver.rkt` | 0b | Micro-benchmarks (28 benchmarks) |
| `bench-track2b-overhead.rkt` | 0b | ATMS overhead decomposition |
| `parity-adversarial.prologos` | 0a | Adversarial parity benchmark (10 sections) |

---

## §9 Open Design Questions

### Resolved in D.2

1. ~~**NAF: synchronous vs async?**~~ → **Async from start.** Infrastructure audit shows minimal additional work (thread spawn + cell write vs inline read). The BSP scheduler supports nested `run-to-quiescence-bsp` calls. No global parameter conflicts. Phase 0b will measure the overhead delta.

2. ~~**Parallel executor: futures vs threads?**~~ → **Data-driven from Phase 0c.** Both exist. A/B comparison on comparative suite will determine which is default. Futures have Racket VM restrictions (no allocation); threads have more overhead but no restrictions.

3. ~~**Parity definition?**~~ → **Set-equality.** Non-deterministic multiple solutions have no canonical ordering. Tests asserting DFS clause-order are asserting an implementation detail. Phase 0a will identify order-dependent tests for adjustment.

### Resolved in D.5 (from Phase 0b data)

5. ~~**Fact-row threshold?**~~ → **No threshold needed.** Phase 0b S2 shows narrowing is sub-microsecond (0.125us for 4→1) — negligible vs query cost. Uniform treatment: all facts = branches, all get decision-cell narrowing. Completeness principle applies.

8. ~~**NAF fuel budget?**~~ → **Adaptive dispatch.** Phase 0b S4 shows async costs 13x sync (4.1us vs 0.31us). Adaptive: sync for facts-only inner goals, async for clause-bearing. Budget: independent per fork (don't let NAF starve outer solver).

### Open for D.6

4. **Fuel config naming** — `solver-config-timeout` in "ms" is misleading (1ms ≈ 1000 firings heuristic). Rename to `:fuel` or `:max-firings`? Or keep `:timeout` with documentation clarification?

6. **Cross-network cell write for async NAF** — the NAF thread writes to a cell on the OUTER network. Options:
   - (a) Shared mailbox/channel; outer BSP checks between rounds
   - (b) Direct CHAMP write; outer BSP re-scans worklist
   - (c) Racket channel; outer BSP picks up in topology stratum
   Option (c) aligns with topology-request protocol. Needs prototyping.

7. **Recursive depth tracking** — does fuel alone bound recursive relations? Phase 0a parity adversarial P5 (`ancestor`) test showed both strategies ran successfully, but deeper recursion (100+ levels) hasn't been tested.

9. **Optimization ordering** — Phase 5a-5d are presented as independent optimizations, but implementation order matters. 5a (worklist fast-path) is simplest and highest-value. 5b (lazy context) and 5d (pooling) interact (lazy makes pooling less valuable). Should 5c (BSP entry fast-path) be folded into 5a? Proposed order: 5a → 5c → 5b → 5d, with A/B benchmarks after each to measure actual savings.

10. **Tier 1/Tier 2 dispatch** — should `solve-goal-propagator` detect Tier 1 queries (no branching) and take a dedicated fast-path? Or should the optimizations (5a-5d) make Tier 1 fast enough that a single path works? A dedicated Tier 1 path is simpler but creates a bifurcation. A unified path with optimizations is more architecturally clean but may not achieve <5x DFS.

8. **NAF fuel budget** — should the NAF fork inherit the parent's remaining fuel (shared budget, NAF competes for firings), or get its own budget (independent, NAF can't starve the outer solver)? Independent budgets risk total fuel exceeding the user's intent; shared budgets risk NAF consuming all fuel. Phase 0b data will inform.
