# BSP-LE Track 2B: Parity Deployment + Parallel Search — Stage 2/3 Design

**Date**: 2026-04-10
**Series**: BSP-LE (Logic Engine on Propagators)
**Scope**: DFS↔Propagator parity validation, fact-row isolation, NAF/guard as async propagators, parallel executor default, `:auto` deployment
**Status**: D.1 — initial design from Track 2 PIR findings
**Predecessor**: [BSP-LE Track 2 PIR](2026-04-10_BSP_LE_TRACK2_PIR.md) — ATMS Solver + Cell-Based TMS
**Design doc**: [BSP-LE Track 2 Design](2026-04-07_BSP_LE_TRACK2_DESIGN.md) (D.13, ~2000 lines)
**Prior art**: [Track 2 Session Handoff](standups/2026-04-09_2300_session_handoff.md), [Track 2 PIR §10-§12](2026-04-10_BSP_LE_TRACK2_PIR.md)

---

## Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| 0 | Pre-0: parity baseline + benchmarks | ⬜ | Run DFS tests through `:atms`, categorize failures |
| 1 | Fact-row branching | ⬜ | Per-fact-row PU isolation |
| 2 | NAF as async propagator | ⬜ | Replace blocking fork with NAF-result cell + BSP sub-computation |
| 3 | Guard as propagator | ⬜ | Replace synchronous eval with guard-test propagator |
| 4 | Parallel executor default + `:auto` switch | ⬜ | Enable `make-parallel-thread-fire-all`, flip `:auto` → propagator |
| T | Dedicated test file | ⬜ | Parity regression suite |
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

Currently, NAF forks the network and runs to quiescence SYNCHRONOUSLY inside the outer propagator's fire function. This blocks the entire BSP round.

**The correct model**: NAF is a propagator that watches its input cells, creates a sub-computation (inner goal on a forked network), and writes `succeeded?` / `failed?` to a NAF-result cell. The outer conjunction reads the NAF-result cell and residuates until it resolves.

**SRE Lattice Lens for NAF-result cell**:
- **Q1**: VALUE lattice (ternary: unknown → succeeded / failed)
- **Q2**: Three-element chain: `unknown < succeeded`, `unknown < failed`. NOT a Boolean lattice — succeeded and failed are incomparable (choosing both = contradiction).
- **Q3**: Inner goal scope → NAF-result (projection: bindings changed? → succeeded / not → failed). NAF-result → outer conjunction (gate: failed = proceed, succeeded = block).
- **Q5**: NAF-result is derived from inner computation
- **Q6**: Hasse diagram is a three-element lattice (fork from unknown to two endpoints)

**Termination**: NAF inner goal terminates by the same argument as the outer solver (finite clauses, monotone cells, fuel limit). The NAF propagator fires ONCE (fire-once pattern) when the inner computation completes.

**Key design question**: The NAF inner goal needs its OWN BSP loop (sub-computation). This is a nested quiescence — the inner goal runs to fixpoint, then the result flows to the outer network. This is the **Pocket Universe** pattern: the inner network IS a cell value from the outer network's perspective.

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

### §3.4 Conjunction — Installation Order vs Execution Order

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
  :writes [naf-result : NafResult]
  :fire-once true
  fire =
    let inner-net = fork-prop-network(outer-net)
    install inner-goal on inner-net
    run-to-quiescence(inner-net)  -- nested BSP
    if inner produced bindings:
      write succeeded to naf-result
    else:
      write failed to naf-result

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

1. **Is everything on-network?** Yes. NAF result, guard result, and fact-row branching all flow through cells. The NAF inner computation is a nested BSP (Pocket Universe) — the inner network IS the computation. No off-network state introduced.

2. **Did the model reveal impurities?** Yes — the NAF evaluator still calls `run-to-quiescence` synchronously inside its fire function. This means the inner BSP loop runs during the outer BSP round. This is not truly async — it's synchronous-within-a-fire. To be TRULY async, the inner computation should be scheduled as a sub-network that the BSP scheduler manages. However, this is the Pocket Universe pattern — the inner network is a self-contained computation. The outer network doesn't need to proceed until NAF resolves. This is acceptable for Phase 2 as long as NAF doesn't block OTHER clauses.

3. **Did the model reveal NTT syntax gaps?** Yes — NTT has no syntax for "nested quiescence" or "Pocket Universe sub-computation." A `sub-network` construct would be useful.

4. **Termination arguments**:
   - Fact-row propagators: fire-once, terminates trivially
   - NAF evaluator: inner goal terminates by fuel limit (same as outer solver). Fire-once.
   - Guard evaluator: pure evaluation, no recursion. Fire-once.
   - NAF/guard gates: fire-once, triggered by result cell.

---

## §5 Phased Roadmap

### Phase 0: Parity Baseline (~1-2h)

**Objective**: Establish the exact gap between DFS and propagator solver across ALL 95 test files.

**Steps**:
1. Create a parity test harness that runs each test file's `defr`/`solve` expressions through BOTH `:strategy :depth-first` AND `:strategy :atms`
2. Compare results: same answers? Same count? Same bindings?
3. Categorize every failure: fact-row (expected), NAF (expected), guard (expected), cut (expected), depth-limit (expected), OTHER (investigate)
4. Capture DFS baseline timings for A/B comparison

**Deliverable**: Parity matrix (95 files × pass/fail per strategy) + failure categorization.

**Design input**: The categorization may reveal gaps not identified in §2.3. If the failure count is <10, the track scope may be smaller than estimated. If >50, there may be fundamental issues beyond the 5 identified gaps.

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

**Objective**: Replace blocking fork-and-check NAF with a NAF-result cell + fire-once propagator.

**Steps**:
1. Define `naf-result` lattice (three-element: unknown/succeeded/failed)
2. Create `install-naf-propagator` that:
   a. Allocates a NAF-result cell on the outer network
   b. Installs a fire-once propagator that, when all input bindings are resolved:
      - Forks the network
      - Installs the inner goal on the forked network
      - Runs the inner goal to quiescence (nested BSP)
      - Writes succeeded/failed to the NAF-result cell
3. Update `install-conjunction` to handle NAF goals: subsequent goals residuate on the NAF-result cell (they watch it and only fire when it resolves to `failed`)
4. Verify semantic parity with DFS NAF: ground-instantiation checking must match

**Key design decision**: The inner BSP runs synchronously within the NAF propagator's fire function (Pocket Universe pattern). This means the NAF doesn't truly "unblock" other clauses — it still takes time. But it separates the NAF computation from the outer network's cell writes, enabling correct behavior. True async (the inner network runs as a scheduled sub-task) is a future optimization for PAR Track 2.

**Tests**: All 4 well-founded test files must pass. NAF-specific test cases in parity matrix.

**Vision gate**: On-network? NAF-result is a cell. Inner computation is a Pocket Universe. Complete? NAF semantics match DFS. Vision-advancing? NAF as information flow, not imperative control.

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

## §9 Open Design Questions (for D.2 iteration)

1. **NAF: synchronous Pocket Universe vs truly async sub-network?** The NTT model (§4) notes that the inner BSP runs synchronously within the NAF propagator's fire. This doesn't block other clauses (different worldview bitmask), but it does consume time in the same BSP round. For Phase 2, synchronous PU is sufficient. True async (inner network scheduled as BSP sub-task) is PAR Track 2 scope. But should the design anticipate the async path?

2. **Parallel executor: futures vs threads?** `make-parallel-fire-all` uses Racket futures (lightweight but limited by Racket VM — no allocation in futures). `make-parallel-thread-fire-all` uses true threads (more overhead but no restrictions). Which should be default? Need A/B data from Phase 0 benchmarks.

3. **Parity definition**: Should propagator solver return results in the SAME ORDER as DFS? Or is set-equality sufficient? DFS returns results in clause-order (first clause's results first). Propagator returns in bitmask order (worldview tagging). If tests assert on ordering, parity fails even when results are correct.

4. **Depth limiting**: DFS uses a recursive depth counter. Propagator uses fuel (time-based). Should propagator also track recursive depth? Or is fuel sufficient as a termination mechanism?

5. **Fact-row branching threshold**: For N=1 fact row, branching overhead is unnecessary. For N=100, it's essential. Should there be a threshold below which facts are handled without PU branching? Or should the uniform treatment (all facts = branches) be the principle?
