# BSP-LE Track 2B: Parity Deployment + Parallel Search — Stage 2/3 Design

**Date**: 2026-04-10
**Series**: BSP-LE (Logic Engine on Propagators)
**Scope**: DFS↔Propagator parity validation, fact-row isolation, NAF/guard as async propagators, parallel executor default, `:auto` deployment
**Status**: D.3 — hypercube-guided optimality lens + Phase 0 investigation scope
**Predecessor**: [BSP-LE Track 2 PIR](2026-04-10_BSP_LE_TRACK2_PIR.md) — ATMS Solver + Cell-Based TMS
**Design doc**: [BSP-LE Track 2 Design](2026-04-07_BSP_LE_TRACK2_DESIGN.md) (D.13, ~2000 lines)
**Prior art**: [Track 2 Session Handoff](standups/2026-04-09_2300_session_handoff.md), [Track 2 PIR §10-§12](2026-04-10_BSP_LE_TRACK2_PIR.md)

---

## Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| 0a | Pre-0: parity baseline | ⬜ | Run ALL 95 DFS test files through `:atms`, categorize every failure |
| 0b | Pre-0: micro-benchmarks | ⬜ | Fact-row PU overhead at N=1,2,4,8,16; NAF sync vs async; executor comparison |
| 0c | Pre-0: A/B executor comparison | ⬜ | Sequential vs futures vs threads on comparative suite; analyze with data |
| 1 | Fact-row branching | ⬜ | Per-fact-row PU isolation (threshold data-driven from 0b) |
| 2 | NAF as async propagator | ⬜ | Async from start: thread-spawned inner BSP, NAF-result cell, NAF-gate |
| 3 | Guard as propagator | ⬜ | Guard-test propagator with topology-request for inner goals |
| 4 | Parallel executor default + `:auto` switch | ⬜ | Enable optimal executor (from 0c data), flip `:auto` → propagator |
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

### §2.7 Infrastructure Findings (D.2)

Key findings from code audit that change the design:

1. **BSP nesting is supported**: `run-to-quiescence-bsp` takes a `net` parameter, can be called recursively. No global state conflicts. Fuel is per-network (immutable in `prop-network` struct). The forked network gets its own fuel budget.

2. **Current NAF uses Gauss-Seidel, not BSP**: Line 1475 calls `run-to-quiescence` (GS), not `run-to-quiescence-bsp`. Even the synchronous fix of switching to BSP would be an improvement.

3. **Fork is O(1)**: `fork-prop-network` creates fresh worklist + fuel, shares cells/propagators/merge-fns via CHAMP structural sharing. Copy-on-write isolation. Two struct allocations.

4. **Thread infrastructure exists**: `make-parallel-thread-fire-all` (propagator.rkt lines 2404-2434) uses Racket 9 parallel threads with per-core partitioning. The thread spawn/join pattern is proven.

5. **Fuel is propagator-firings, not wall-clock**: `fuel := fuel - length(deduplicated_worklist)` per BSP round (line 2290). The `solver-config-timeout` converts ms to firings via `fuel = timeout_ms * 1000` (rough heuristic, line 1873). Default: 1,000,000 firings.

6. **DFS depth limit is independent**: `DEFAULT-DEPTH-LIMIT = 100` (line 551), counts call stack depth, errors on overflow. Completely separate mechanism from fuel.

---

## §3 Algebraic Foundation

### §3.1 Fact-Row Branching — The Missing Lattice

Currently, fact queries write all matching fact values to the same cells in sequence. The last write wins. This is NOT a lattice operation — it's imperative overwrite.

**The correct model**: Each fact row is a branch (same as each clause is a branch). The result is the JOIN of all fact-row results — the answer accumulator collects all solutions.

This reuses Track 2's concurrent multi-clause infrastructure exactly:
- Each fact row gets a worldview bitmask bit
- Each writes to scope cells tagged with its bitmask
- The answer accumulator collects all tagged results

**SRE Lattice Lens**:
- **Q1 (Classification)**: VALUE lattice (answer set accumulates monotonically)
- **Q2 (Properties)**: Boolean (powerset of answers), distributive
- **Q3 (Bridges)**: Fact-row scope → answer accumulator (same as clause-scope → answer)
- **Q4 (Composition)**: Identical to multi-clause composition — fact rows ARE clauses structurally
- **Q5 (Primary/Derived)**: Per-row scope cells are primary; answer accumulator is derived
- **Q6 (Hasse)**: For K fact rows, the answer set lattice is P(K) — powerset. Same as multi-clause.

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

---

## §4 NTT Model

```
;; ===== Fact-Row Branching (Phase 1) =====

;; Fact rows = branches, same as multi-clause
lattice FactAnswer : Set Answer where
  bot   = {}
  join  = set-union
  -- Monotone: answers only accumulate

cell fact-answer-acc : FactAnswer := bot

;; One propagator per fact row, worldview-tagged
propagator install-fact-row-propagator
  :reads  [resolved-args : TermCell]
  :writes [scope-vars : ScopeCell, fact-answer-acc : FactAnswer]
  :worldview bit-k  -- per-row isolation
  :fire-once true
  fire = unify row-terms with resolved-args,
         write bindings to scope-vars (tagged with bit-k),
         write result to fact-answer-acc

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

### Phase 1: Fact-Row Branching (~2-3h)

**Objective**: Per-fact-row PU isolation so that fact queries return ALL matching rows, not just the last.

**Steps**:
1. In `install-clause-propagators`, detect the fact-row path (already distinct at lines 1692-1704)
2. For N fact rows, create N worldview bitmask bits (reuse `install-one-clause-concurrent` pattern)
3. Each fact row gets its own `wrap-with-worldview` fire function that writes to scope cells tagged with its bitmask
4. Answer accumulator collects all N tagged results
5. Gray code ordering for CHAMP sharing (same as multi-clause)

**Tests**: Fact queries with N>1 matching rows must return all N results. Verify ordering independence.

**Vision gate**: On-network? Yes (tagged writes). Complete? All fact rows isolated. Vision-advancing? Fact rows are structurally equivalent to clauses — this unifies the treatment.

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

### Phase 4: Parallel Executor Default + `:auto` Switch (~2-3h)

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
| NAF semantic divergence (propagator produces different results than DFS) | Medium | High | Phase 0 parity baseline catches this. DFS retained as fallback. |
| Parallel executor introduces non-determinism | Low | High | BSP guarantees confluence (CALM). Parallel changes firing order, not results. |
| Performance regression >15% | Low | Medium | A/B benchmarks as gate. Sequential executor as fallback. |
| Fact-row branching increases cell allocation significantly | Medium | Low | K fact rows = K bitmask bits + K tagged writes. Track 2 compound cells mitigate. |
| Guard topology requests create BSP round overhead | Low | Low | One topology request per guard. Topology stratum runs between value strata. |

---

## §8 Files Modified

| File | Phases | Changes |
|---|---|---|
| `relations.rkt` | 1, 2, 3 | Fact-row branching, NAF propagator, guard propagator |
| `stratified-eval.rkt` | 4 | `:auto` → propagator |
| `propagator.rkt` | 4 | `current-parallel-executor` default |
| `decision-cell.rkt` | 2, 3 | NAF-result and guard-result lattice values (if not using existing cell infrastructure) |
| `test-propagator-solver.rkt` | 1, 2, 3 | Extended with fact-row, NAF, guard tests |
| `test-solver-parity.rkt` | T | NEW — parity regression suite |

---

## §9 Open Design Questions

### Resolved in D.2

1. ~~**NAF: synchronous vs async?**~~ → **Async from start.** Infrastructure audit shows minimal additional work (thread spawn + cell write vs inline read). The BSP scheduler supports nested `run-to-quiescence-bsp` calls. No global parameter conflicts. Phase 0b will measure the overhead delta.

2. ~~**Parallel executor: futures vs threads?**~~ → **Data-driven from Phase 0c.** Both exist. A/B comparison on comparative suite will determine which is default. Futures have Racket VM restrictions (no allocation); threads have more overhead but no restrictions.

3. ~~**Parity definition?**~~ → **Set-equality.** Non-deterministic multiple solutions have no canonical ordering. Tests asserting DFS clause-order are asserting an implementation detail. Phase 0a will identify order-dependent tests for adjustment.

### Open for D.3

4. **Fuel: propagator-firings, not wall-clock** — the "timeout in ms" config is misleading (1ms ≈ 1000 firings heuristic). Should we rename the config key? Should fuel be per-network or shared across forks? Phase 0b fuel consumption profiles will inform this.

5. **Fact-row threshold** — D.1's N=4 was arbitrary (borrowed from broadcast A/B). Phase 0b micro-benchmarks at N=1,2,4,8,16,32 will give data-driven answer. Possible outcomes:
   - PU overhead is negligible at all N → uniform treatment (Completeness principle)
   - PU overhead significant at N=1-2 → threshold at N=3 or N=4
   - PU overhead significant at all N → different approach needed

6. **Cross-network cell write for async NAF** — the NAF thread writes to a cell on the OUTER network. The outer BSP needs to detect this write and schedule the NAF-gate. Options:
   - (a) NAF thread writes to a shared mailbox/channel; outer BSP checks between rounds
   - (b) NAF thread directly writes to outer network's cells CHAMP; outer BSP re-scans worklist
   - (c) NAF thread signals completion via a Racket channel; outer BSP picks up in topology stratum
   Option (c) aligns with the existing topology-request protocol (between BSP rounds, sequential processing). Phase 0b NAF benchmarks should test all three.

7. **Recursive depth tracking** — DFS counts call stack depth (`DEFAULT-DEPTH-LIMIT = 100`). Propagator uses fuel (propagator-firings). For recursive relations (e.g., `ancestor` calling itself), does the propagator solver need a recursive depth counter? Or does fuel naturally bound recursive unfolding? Phase 0a parity testing on recursive relation tests will reveal whether fuel alone is sufficient.

8. **NAF fuel budget** — should the NAF fork inherit the parent's remaining fuel (shared budget, NAF competes for firings), or get its own budget (independent, NAF can't starve the outer solver)? Independent budgets risk total fuel exceeding the user's intent; shared budgets risk NAF consuming all fuel. Phase 0b data will inform.
