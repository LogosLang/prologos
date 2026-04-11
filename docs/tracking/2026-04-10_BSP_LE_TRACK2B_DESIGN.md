# BSP-LE Track 2B: Parity Deployment + Parallel Search — Stage 2/3 Design

**Date**: 2026-04-10
**Series**: BSP-LE (Logic Engine on Propagators)
**Scope**: DFS↔Propagator parity validation, fact-row isolation, NAF/guard as async propagators, parallel executor default, `:auto` deployment
**Status**: D.6 — executor scaling data + hypercube merge topology
**Predecessor**: [BSP-LE Track 2 PIR](2026-04-10_BSP_LE_TRACK2_PIR.md) — ATMS Solver + Cell-Based TMS
**Design doc**: [BSP-LE Track 2 Design](2026-04-07_BSP_LE_TRACK2_DESIGN.md) (D.13, ~2000 lines)
**Prior art**: [Track 2 Session Handoff](standups/2026-04-09_2300_session_handoff.md), [Track 2 PIR §10-§12](2026-04-10_BSP_LE_TRACK2_PIR.md)

---

## Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| 0a | Pre-0: parity baseline | ✅ | 19/19 test files pass both strategies. Adversarial: 3 divergence categories found. |
| 0b | Pre-0: micro-benchmarks | ✅ | 28 benchmarks + overhead decomposition. ATMS 24.5x overhead identified → 4 optimization paths. |
| 0c | Pre-0: A/B executor comparison | ⬜ | Sequential vs futures vs threads on comparative suite |
| 1a | Clause selection as decision-cell narrowing | ⬜ | Argument-watching propagator + clause decision cell. Fixes Category 1+2. |
| 1b | Position-discriminant analysis | ⬜ | Needed-narrowing-inspired: identify best discriminating position, hierarchical narrowing |
| 2 | NAF as async propagator | ⬜ | Async from start: thread-spawned inner BSP, NAF-result cell, NAF-gate |
| 3 | Guard as propagator | ⬜ | Guard-test propagator with topology-request for inner goals |
| 5a | Tier 1 fast-path: deterministic query bypass | ⬜ | Skip solver-context + BSP for non-branching queries. Target: <3x DFS. |
| 5b | Lazy solver-context allocation | ⬜ | Defer decisions/commitments/assumptions/nogoods cells until first amb. |
| 5c | BSP empty-worklist fast-path | ⬜ | Skip BSP scheduling when no propagators on worklist after installation. |
| 5d | Context pooling | ⬜ | Pre-allocate solver-context, reuse across queries via CHAMP snapshots. |
| 6 | Parallel executor default + `:auto` switch | ⬜ | Enable optimal executor, flip `:auto` → propagator, full regression gate. |
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

**End state**: The propagator-native solver IS the default solver. `:auto` routes to `solve-goal-propagator`. The parallel thread executor is the default. Clause ordering has no effect on results (already true — CALM) AND no effect on performance (BSP parallel firing). All 95 test files that exercise `defr`/`solve` pass through the propagator path. The DFS solver (`solve-goals`/`solve-single-goal`) is retained as a fallback but is NOT the default.

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

---

## §3 Algebraic Foundation

### §3.1 Clause Selection as Decision-Cell Narrowing (D.4 — from Phase 0a findings)

#### The Problem (Phase 0a Adversarial Findings)

The propagator solver has two related bugs:

**Category 1 (facts)**: Fact rows write ALL values to free argument cells without checking bound arguments. `fact8 ?x` returns 1 result (last-write-wins) instead of 8. `fact16 8 ?y` returns wrong result.

**Category 2 (clauses)**: Multi-clause propagators are installed for ALL clauses concurrently without filtering on bound arguments. `five-way 3 ?y` returns 5 results instead of 1. `color-pair ?c1 ?c2` returns unresolved variables for `:c1`.

Both are the SAME problem: **clause selection doesn't narrow on bound arguments**.

#### The Structural Frame

**What is the information?** Two things intersect:
1. Query arguments — which positions are bound, to what values
2. Clause head patterns — what each clause/fact expects at each position

**What is the lattice?** The clause-viability lattice:

```
Carrier:   P(ClauseIndices)          — subsets of clause/fact-row indices
Order:     ⊇ (reverse inclusion)     — fewer alternatives = more information
Bot:       {0, 1, ..., N-1}          — all N clauses/fact-rows viable
Top:       ∅                         — contradiction (no clause matches)
Merge:     set-intersection          — combining constraints narrows alternatives
```

This IS a decision cell from Track 2. We already have `decisions-state` with exactly these semantics.

**What emerges?** When a ground value arrives at query argument position k:
- Clauses whose head at position k is incompatible are eliminated from the domain
- Their assumption bits are cleared in the decision cell
- Their propagators become inert (assumption no longer in viable domain)
- Only matching clauses' propagators fire

Clause selection IS decision-cell narrowing. The mechanism is structurally identical to what Track 2 built for ATMS alternatives.

#### SRE Lattice Lens

- **Q1 (Classification)**: STRUCTURAL lattice (clause domain, alternatives = constructors)
- **Q2 (Properties)**: Boolean (dual powerset), constraint narrowing — same as Track 2 decision cells
- **Q3 (Bridges)**: Query argument cells → clause decision cell (narrowing). Clause decision cell → clause propagator installation (topology gating).
- **Q4 (Composition)**: Clause decision cell composes with per-clause worldview bitmasks (Track 2). Narrowing the decision cell makes inert the corresponding worldview-tagged propagators.
- **Q5 (Primary/Derived)**: Clause decision cell is primary. Per-clause viability is derived.
- **Q6 (Hasse)**: For N clauses, the clause decision cell's Hasse diagram is the dual hypercube Q_N — narrowing traverses downward. Bitmask enables O(1) subcube operations (same as Track 2 nogood pruning).

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

### §3.2 NAF as Async Propagator — Lattice Analysis

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

`install-conjunction` uses `for/fold` (sequential installation). This is acceptable because:
- Installation order ≠ execution order. Propagators fire in BSP rounds regardless of installation order.
- The `for/fold` threads the network struct (needed for cell allocation). This is a construction-time concern, not an execution-time concern.
- CALM guarantees convergence regardless of firing order.

However, for future self-hosting, conjunction installation should be a broadcast-like pattern (install all goals' propagators in one pass). This is a future optimization, not a correctness issue.

### §3.6 Tier 1 Optimization Pipeline (D.5 — from Phase 0b data)

Phase 0b reveals the ATMS solver is 25x slower than DFS for trivial single-fact queries. The overhead decomposes to: BSP scheduling 52.6%, goal installation 30.4%, context allocation 15.5%, result reading 0.4%. Four optimizations target each component, together aiming for <3x DFS on Tier 1 queries.

#### Optimization 1: Deterministic Query Fast-Path (Phase 5a) — targets 52.6% BSP overhead

**The insight**: For deterministic queries (no `amb`, single clause or facts only), BSP scheduling is pure waste. The query can be answered by direct cell writes and reads — no propagators need to fire, no worklist needs scheduling, no topology stratum needs checking.

**The mechanism**: Before calling `run-to-quiescence`, check if the worklist is empty after goal installation. For a single-fact query, `install-goal-propagator` writes fact values directly to scope cells (no propagators installed). The worklist is empty → skip BSP entirely → read cells directly.

This is NOT a special case — it's recognizing that deterministic queries don't need the scheduler at all. The information is already in the cells after installation. BSP is for convergence of interdependent propagators, not for reading pre-computed values.

**Expected savings**: ~12.1us (52.6% of 23us). Target: ~11us → 12x DFS (still high — need other optimizations).

**SRE lens**: This is the CALM observation made operational. Deterministic queries are trivially monotone — one write, one read, no fixpoint needed. The BSP scheduler is coordination infrastructure; CALM says coordination-free computations don't need it.

#### Optimization 2: Lazy Solver-Context (Phase 5b) — targets 15.5% allocation overhead

**The insight**: `make-solver-context` allocates 7 cells + 1 projection propagator for EVERY query — even queries that never branch. The decisions cell, commitments cell, assumptions cell, nogoods cell, counter cell, and table registry cell are all unused for deterministic queries.

**The mechanism**: Replace eager `make-solver-context` with a lazy version that allocates only:
- Minimum: scope cell + answer accumulator (2 cells)
- On first `amb`: promote to full solver-context (remaining 5 cells + projection)

This is a structural optimization: the solver-context IS a lattice value that starts at bot (minimal allocation) and grows monotonically (more cells allocated as needed). Promotion is a one-time cost paid only by branching queries.

**Expected savings**: ~3.6us for Tier 1 queries (15.5% of 23us). Combined with Opt 1: ~7.3us → 8x DFS.

#### Optimization 3: BSP Empty-Worklist Fast-Path (Phase 5c) — targets BSP entry overhead

**The insight**: Even when the worklist is non-empty, the BSP loop has fixed entry overhead: dedup worklist, check fuel, enter outer loop, check topology stratum. For queries with very few propagators (1-2), this overhead is disproportionate.

**The mechanism**: In `run-to-quiescence-bsp`, add a fast-path check at entry:
- If worklist has ≤ 1 item AND no topology requests pending: fire the single propagator directly (bypass BSP loop), return network
- If worklist is empty: return network immediately (no scheduling at all)

This is the degenerate case of BSP: when the "bulk" in Bulk Synchronous Parallel is N=0 or N=1, the synchronization protocol is overhead without benefit. The fast-path recognizes this.

**Expected savings**: ~2-3us for trivial queries (reduces step 6 delta from 12.1us to ~9-10us). Smaller than Opt 1 but compounds with it.

#### Optimization 4: Context Pooling (Phase 5d) — targets repeated query overhead

**The insight**: When multiple `solve` blocks appear in the same `.prologos` file (very common — see A7 section of `atms-adversarial.prologos` with 50 sequential solves), each creates a fresh network + solver-context from scratch. CHAMP immutability means a pre-built context can be safely reused as a snapshot base.

**The mechanism**: Maintain a `current-solver-context-pool` parameter. On first query, build the full context. On subsequent queries, fork from the pooled context (O(1) CHAMP fork) instead of allocating from scratch.

Phase 0b data: context reuse saves 33% (23.0us → 15.5us). For 50 sequential solves, this saves ~375us total.

**Expected savings**: Per-query savings of ~7.5us after first query. Amortized over N queries: `(7.5 * (N-1)) / N` us savings per query.

#### Combined Optimization Target

| Optimization | Targets | Savings (us) | Cumulative ATMS (us) | vs DFS |
|---|---|---|---|---|
| Baseline | — | — | 23.0 | 25.3x |
| 5a: Empty-worklist fast-path | BSP scheduling (52.6%) | ~12.1 | ~10.9 | ~12x |
| 5b: Lazy solver-context | Allocation (15.5%) | ~3.6 | ~7.3 | ~8x |
| 5c: BSP entry fast-path | BSP entry overhead | ~2-3 | ~4.5 | ~5x |
| 5d: Context pooling | Repeated query amortization | ~7.5 (amortized) | ~4.0 (amort.) | ~4.4x |
| **All combined (Tier 1)** | | | **~3-5** | **~3-5x** |

Target: <5x DFS for Tier 1 deterministic queries. For Tier 2 branching queries, the overhead is already more acceptable (8.3x for 3-clause) and the propagator solver provides genuine parallelism that DFS cannot.

#### Architectural Integrity

All four optimizations preserve the on-network architecture:
- **5a** skips BSP for queries that have no propagators — the information is already in cells
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

#### Implementation Sketch

```
;; Per-round pairwise merge (dimension k of the hypercube)
(for each round k from 0 to log₂(K)-1:
  ;; Each worker i communicates with partner i XOR 2^k
  (for each worker i in parallel:
    partner = i XOR (1 << k)
    if i < partner:
      ;; i is the "receiver": merge partner's result into own
      merged = cell-merge(my-result, shared-buffer[partner])
      my-result = merged
    else:
      ;; i is the "sender": write result to shared buffer for partner
      shared-buffer[i] = my-result
  ;; Barrier (semaphore) between rounds)
```

After log₂(K) rounds, worker 0 holds the global merged result. This is the standard hypercube all-reduce algorithm adapted for CHAMP merge.

#### Scope Decision

This is a significant optimization but architecturally clean — it changes the BSP barrier's merge topology without affecting the propagator model. Options:
- **Phase 6 scope**: implement alongside `:auto` switch as the production parallel executor
- **Future track**: defer to PAR Track 2 (parallel scheduling) where it compounds with other parallel optimizations
- **Data-driven**: implement Phase 5a-5d first (Tier 1 fast-path), re-measure. If Tier 1 is <5x DFS, the parallel executor is less urgent and can be deferred

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
1. **Discrimination map extraction** (~50 lines in `relations.rkt`):
   - For fact rows: extract ground values at each position
   - For clause bodies: peek at first unification goal to extract discriminating value
   - Store as `hasheq position → (hasheq value → (listof clause-index))`
   - Compute at relation registration time (static, no runtime cost)

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

5. **Per-fact-row PU branching** (for N>1 matching facts after narrowing):
   - Surviving fact rows get worldview bitmask bits (same as multi-clause)
   - Gray code ordering for CHAMP sharing
   - Answer accumulator collects all tagged results

**Tests**: All parity-adversarial.prologos sections P1 + P2 must match DFS results. `fact16 8 ?y` returns 1 result. `five-way 3 ?y` returns 1 result. `five-way ?x ?y` returns 5 results.

**Vision gate**: On-network? Decision cell + narrowing propagator. Complete? Facts + clauses unified. Vision-advancing? Clause selection IS information flow (lattice narrowing), not imperative filtering.

### Phase 1b: Position-Discriminant Analysis (~2h)

**Objective**: Needed-narrowing-inspired optimization: identify best discriminating argument position, build hierarchical narrowing.

**Steps**:
1. **Position scoring**: For each argument position, count how many distinct groups the discrimination map creates. Best = most groups (highest discrimination power).
2. **Hierarchical tree building**: If position p0 groups clauses into subgroups, recurse: within each subgroup, find the next best position p1. Build a tree of (position, value → subgroup) entries.
3. **Nested decision cells**: Each tree level becomes a decision cell on the network. Level 0 narrows on p0. Level 1 narrows on p1 within each group. Propagators watch the corresponding argument cells.
4. **Integration**: Store the discrimination tree alongside `variant-info` at registration time. At solve time, use the tree to guide propagator installation.

**Tests**: Relations with multiple discriminating positions (e.g., 2-arg relation where both args have unique values per clause). Verify that narrowing cascades correctly through levels.

**Vision gate**: On-network? Nested decision cells. Complete? Multi-position discrimination. Vision-advancing? The tree IS the Hasse diagram of the clause decomposition.

### Phase 2: NAF as Async Propagator (~3-4h)

**Objective**: Replace blocking fork-and-check NAF with async thread-spawned inner BSP + NAF-result cell.

**Steps**:
1. Define `naf-result` lattice (three-element: unknown/succeeded/failed) in `decision-cell.rkt`
2. Create `install-naf-propagator` in `relations.rkt` that:
   a. Allocates a NAF-result cell on the outer network
   b. Installs a fire-once propagator that, when input bindings resolve:
      - Spawns a thread (using existing thread infrastructure from PAR Track 1)
      - Thread: forks network → installs inner goal → runs `run-to-quiescence-bsp` (BSP, not Gauss-Seidel — the current NAF uses GS which is a known deficiency)
      - Thread: writes `succeeded` or `failed` to NAF-result cell on outer network
      - Thread terminates (bounded by fork's fuel budget)
   c. Installs a NAF-gate propagator (fire-once) that watches NAF-result:
      - `failed` → write current scope to continuation (NAF succeeds)
      - `succeeded` → no-op (NAF fails, clause blocked)
      - `unknown` → residuate
3. Implement cross-network write mechanism (Phase 0b data determines: channel, direct write, or topology-request protocol)
4. Update `install-conjunction` to handle NAF goals: subsequent goals residuate on NAF-result cell
5. Verify semantic parity with DFS NAF (ground-instantiation check must match)

**Fuel budget**: Per Phase 0b data. Default: fork gets own budget (not competing with outer solver).

**Tests**: All 4 well-founded test files must pass. NAF-specific parity cases. Async-specific tests: verify outer clauses proceed while NAF thread runs.

**Vision gate**: On-network? NAF-result is a cell. Inner computation is a Pocket Universe. Async? Thread-spawned, non-blocking. Complete? NAF semantics match DFS. Vision-advancing? NAF as parallel sub-computation, not blocking control flow.

### Phase 3: Guard as Propagator (~2-3h)

**Objective**: Replace synchronous guard evaluation with a guard-test propagator that supports inner-goal continuation.

**Steps**:
1. Define `guard-result` lattice (same three-element as NAF)
2. Create `install-guard-propagator` that:
   a. Allocates a guard-result cell
   b. Installs a fire-once propagator that evaluates the condition when inputs resolve
   c. On `passed`: emits a topology request to install inner goals
   d. On `failed`: no-op (clause fails)
3. Handle guard with inner body: when guard passes, install inner goals via topology request (between BSP rounds)
4. Verify semantic parity: DFS guard evaluation + inner-goal continuation

**Tests**: Guard-specific test cases. Guards with inner bodies.

**Vision gate**: On-network? Guard result is a cell. Topology request is the CALM-safe protocol. Complete? Inner-goal continuation supported. Vision-advancing? Guard as data-driven topology mutation.

### Phase 5a: Deterministic Query Fast-Path (~2h)

**Objective**: Skip BSP scheduling for queries with no propagators on worklist after installation. Targets the 52.6% BSP overhead.

**Steps**:
1. After `install-goal-propagator`, check `prop-network-worklist` length
2. If worklist is empty (pure fact query, all values already written to cells): skip `run-to-quiescence` entirely, read cells directly
3. If worklist has 1 item: fire the single propagator directly (bypass BSP loop), return network
4. Otherwise: proceed to BSP as normal

**Tests**: All parity-adversarial P1 fact queries produce correct results via fast-path. Single-fact benchmark target: <5us (from 23us baseline).

**Vision gate**: Not a special case — recognizing that CALM-trivial queries don't need coordination infrastructure.

### Phase 5b: Lazy Solver-Context (~2h)

**Objective**: Defer allocation of decisions/commitments/assumptions/nogoods/counter/table-registry cells until first `amb`. For Tier 1 queries, these are never used.

**Steps**:
1. Create `make-lazy-solver-context` that allocates only 2 cells (scope + answer accumulator)
2. On first `amb` call: promote to full context (allocate remaining 5 cells + projection propagator)
3. `solver-context` struct gains a `promoted?` field or lazy accessor pattern

**Tests**: Tier 1 queries work with lazy context. Tier 2 (branching) queries promote and work correctly.

### Phase 5c: BSP Empty-Worklist Fast-Path (~1h)

**Objective**: Inside `run-to-quiescence-bsp`, add fast-path for N≤1 worklist items.

**Steps**:
1. At entry to `run-to-quiescence-bsp`, check worklist length
2. If 0: return network immediately (no scheduling overhead)
3. If 1: fire the single propagator, collect writes, merge, return (skip BSP loop ceremony)
4. If >1: proceed to BSP as normal

**Tests**: Benchmark regression: BSP overhead for trivial queries should drop to near-zero.

### Phase 5d: Context Pooling (~2h)

**Objective**: Pre-allocate solver-context for reuse across queries via CHAMP snapshot.

**Steps**:
1. Add `current-solver-context-pool` parameter (default `#f`)
2. On first query in a file: build full context, store in pool
3. On subsequent queries: `fork-prop-network` from pooled context (O(1) CHAMP fork)
4. Wire into `solve-goal-propagator` entry point

**Tests**: 50 sequential solves (atms-adversarial A7) — measure per-query savings vs fresh allocation.

### Phase 6: Parallel Executor Default + `:auto` Switch (~2-3h)

**Objective**: Make the propagator solver the default and enable true OS-level parallelism.

**Steps**:
1. **Re-run parity matrix**: After Phases 1-3, all 95 files should pass through `:atms`. Any remaining failures are investigated individually.
2. **Enable parallel executor**: Set `current-parallel-executor` to `make-parallel-thread-fire-all` as default (or `make-parallel-fire-all` as conservative option)
3. **A/B benchmarks**: Run comparative suite with `:depth-first` vs `:atms` + parallel executor. Acceptance: ≤15% regression on single-clause benchmarks, measurable speedup on multi-clause (N≥4).
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
