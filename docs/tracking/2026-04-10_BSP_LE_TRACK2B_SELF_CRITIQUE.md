# BSP-LE Track 2B Self-Critique — P/R/M Three-Lens Analysis

**Date**: 2026-04-10
**Design**: D.6 (`docs/tracking/2026-04-10_BSP_LE_TRACK2B_DESIGN.md`)
**Methodology**: `docs/tracking/principles/CRITIQUE_METHODOLOGY.org`

---

## Lens P: Principles Challenged

### P1: Phase 1a Step 4 — "gate clause installation" is ambiguous between imperative check and topology-gated installation

The design says: "install-clause-propagators reads the clause decision cell, only installs propagators for clauses still in the viable set." Reading a cell value and using it to decide what to install is **imperative dispatch** — the propagator-native approach is: the narrowing propagator writes to the decision cell, and the decision cell's change triggers a **topology request** that installs only the newly-viable clauses.

The distinction matters: imperative gating requires the narrowing to complete BEFORE installation begins (imposed ordering). Topology-gated installation allows narrowing and installation to interleave (emergent ordering from dataflow).

**Challenge**: Could Phase 1a use topology requests exclusively, with clause propagators installed on-demand as the decision cell narrows?

**Resolution**: For FULLY-BOUND arguments (all ground at query time), construction-time filtering is acceptable — it's structural setup, analogous to `install-conjunction`'s `for/fold`. For PARTIALLY-BOUND arguments (some free, resolved during BSP), the arg-watcher propagator + topology request IS needed. The design should explicitly distinguish these two paths and state that construction-time filtering is scaffolding for the common case, with topology-gated installation as the general mechanism.

### P2: Phase 5a and 5c create TWO fast-paths — Decomplection violation?

Phase 5a: "check worklist emptiness after installation, skip BSP." Phase 5c: "inside `run-to-quiescence-bsp`, fast-path for N<=1 worklist." These are the SAME optimization at different call sites. Having both creates two overlapping bypass mechanisms — the caller decides AND the scheduler decides.

**Challenge**: Should 5a be folded into 5c? One mechanism (inside the scheduler) is simpler and avoids the question of which fast-path fires first.

**Resolution**: Merge 5a into 5c. The BSP scheduler itself should handle empty/trivial worklists efficiently. The caller (`solve-goal-propagator`) should not have its own worklist check — that's the scheduler's job. Decomplection: the scheduler handles scheduling; the solver handles solving.

### P3: NAF adaptive dispatch (sync vs async) — "pragmatic" red flag?

The design says: "facts-only inner goal → sync NAF; clause-bearing → async NAF." This is a conditional dispatch based on relation structure. Is this "pragmatic" or principled?

**Challenge**: Could the system determine sync/async STRUCTURALLY rather than by relation-info inspection?

**Resolution**: The distinction IS structural — it's a property of the relation (`variant-info-clauses` is empty vs non-empty). The dispatch is data-driven, not heuristic. However, the sync path violates the information-flow model: sync NAF returns a result inline (imperative), while async NAF writes to a cell (information flow). The principled approach is: ALWAYS write to a NAF-result cell (information flow), but choose whether the inner BSP runs on the same thread or a spawned thread. The cell write is the invariant; the thread choice is the optimization.

**Action**: Revise Phase 2 to always use the NAF-result cell + NAF-gate propagator pattern. The only difference between "sync" and "async" is whether the inner BSP blocks the current thread or runs on a new thread. The information flow (cell write → gate fire) is identical in both cases.

### P4: DFS retained as `:depth-first` fallback — "keeping the old path"?

**Challenge**: Is keeping ~170 lines of DFS solver code justified, or is it the "keeping the old path as fallback" anti-pattern?

**Resolution**: Justified as a debugging tool. The DFS solver is independent code (~170 lines) that doesn't interact with propagator infrastructure. It's useful for bisecting issues: if a query produces wrong results under `:atms`, running under `:depth-first` isolates whether the bug is in the solver infrastructure or the query. The code is stable (no changes in 4+ tracks). Keeping it has near-zero maintenance cost. This is NOT dual-path (both active) — it's fallback (one active, one diagnostic).

### P5: Discrimination map is off-network static data

The discrimination map (`hasheq position -> (hasheq value -> clause-indices)`) is computed at registration time and never changes. This is off-network state.

**Challenge**: Could the discrimination map be a cell?

**Resolution**: No — it's a CONSTANT. Constants are not lattice values (they don't refine monotonically). Putting a constant in a cell adds overhead (cell allocation, merge function) for zero benefit. Static data that never changes is legitimately off-network. The map is analogous to the `relation-info` struct itself — data about the program structure, not data that evolves during computation.

### P6: Context pooling (5d) uses a parameter — parameters should be cells?

**Challenge**: `current-solver-context-pool` is a `make-parameter`. The on-network mandate says parameters holding hasheqs should be cells.

**Resolution**: The pool holds a TEMPLATE (an immutable CHAMP snapshot of a solver-context). It's written once (first query) and never modified — only forked. This is a constant after initialization. A cell would add overhead for no benefit. However, the parameter SHOULD be documented as "write-once, then read-only" to prevent misuse. If it ever needs to be updated mid-file (e.g., when new relations are registered), it should become a cell.

---

## Lens R: Reality-Check (Code Audit)

### R1: Discrimination map extraction — non-unification first goals

The design says "peek at first unification goal to extract discriminating value." But clause bodies can start with non-unification goals:
- `&> (double x ?mid) (triple mid result)` — first goal is `app`, not `unify`
- `&> (is result [int* n 2])` — first goal is `is`, not `unify`
- `&> (guard [int> n 0]) (= label "positive")` — first goal is `guard`

For these clauses, the discrimination map has NO entry at any position — the clause is compatible with any argument value (wildcard). The design needs to state this explicitly: discrimination works ONLY for clauses whose first goal is `(= param ground-value)`. All other clauses are wildcards in the discrimination map.

**Impact**: For relations where all clauses start with `app` or `is` goals, the discrimination map is empty — no narrowing occurs. This is correct (all clauses must be tried) but should be noted as a limitation.

### R2: Phase 5a scope is narrower than claimed

The design says "skip BSP for non-branching queries." But the worklist is non-empty after installing single-clause relations (propagators are installed). The fast-path applies ONLY to fact-only queries (no clauses = no propagators = empty worklist). Single-clause queries still need BSP to fire their propagators.

**Impact**: Phase 5a helps fact queries (the 52.6% BSP overhead is eliminated) but NOT single-clause queries. The overhead for single-clause Tier 1 queries remains. This narrows the "deterministic query fast-path" to "fact-only query fast-path."

**Action**: Rename 5a to "fact-query fast-path" or expand it: for single-clause queries, the propagators fire exactly once — could use fire-once semantics without full BSP ceremony.

### R3: Phase 1a line count estimate is low

Discrimination map extraction (~50) + clause decision cell (~30) + argument-watching propagator (~50) + gate installation (~30) + fact-row PU branching (~30 from existing pattern). Total: ~190 lines, not ~150. Additionally, the discrimination map needs integration with `relation-register` (storing the map alongside `variant-info`), which adds ~20 lines. Revised estimate: ~210 lines.

### R4: Phase 5b — worldview cache cell (cell-id 1) interaction

`net-cell-read` checks the worldview cache cell on every read (Phase 4 infrastructure). With lazy solver-context, the decisions cell that feeds the worldview cache doesn't exist initially. The cache cell stays at 0 (no speculation). This IS correct for Tier 1 queries. But: does `promote-cell-to-tagged` check for the worldview cache cell's existence? If promotion is attempted before the lazy context is promoted, does it crash?

**Action**: Verify that `promote-cell-to-tagged` handles the case where worldview cache cell holds 0 (no active speculation). The Phase 4 code should already handle this (0 = base path, no filtering), but needs explicit verification during implementation.

### R5: Existing test count for solver paths

The design references "19 test files" from Phase 0a. But the parity harness tests each file's `process-file` output — it doesn't test the internal solver API (`solve-goal-propagator` directly). The internal API is tested only by `test-propagator-solver.rkt` (17 tests). Phase 1a's clause selection mechanism changes the internal API — the 17 tests may not cover the new narrowing behavior.

**Action**: Phase 1a must add tests for: (a) narrowing with bound arguments, (b) narrowing with free arguments (no narrowing), (c) partial binding (some bound, some free), (d) non-unification first goals (wildcard), (e) mixed facts+clauses.

---

## Lens M: Propagator-Mindspace

### M1: Phase 1a step 4 is step-think if implemented as imperative filter

If `install-clause-propagators` reads the decision cell value and filters clauses BEFORE installing propagators, this is imperative dispatch — the function "decides" which clauses to install based on a value it reads. The propagator-native approach: install an arg-watcher propagator for each discriminating position, and have the watcher emit topology requests for matching clauses. Clauses are installed BY the topology stratum, not BY the installation function.

However, for the common case (all arguments ground at query time), the arg-watcher would fire immediately during the first BSP round and emit topology requests that are processed in the topology stratum — adding one full BSP round of latency for something that could be done at construction time.

**Resolution**: Construction-time narrowing (imperative) is acceptable for fully-ground arguments — it's structural setup. The arg-watcher propagator (reactive) is needed for partially-bound arguments. The design should name both mechanisms and state when each applies. The construction-time path is an optimization of the general mechanism, not a replacement.

### M2: "Rounds" in hypercube all-reduce (§3.7) is step-think vocabulary

§3.7 describes the merge as "log₂(K) rounds of pairwise merge." Rounds are imposed temporal ordering. The propagator-native description: each worker IS a propagator, pairwise connections ARE propagator edges on a merge network, and the BSP scheduler fires them all simultaneously. The "rounds" are BSP supersteps that EMERGE from the merge network's dataflow depth (log₂(K) because the merge tree has depth log₂(K)).

**Resolution**: Revise §3.7 to describe the merge topology as a propagator network with pairwise merge propagators. The log₂(K) rounds emerge from the network's depth, not from an imposed schedule. The implementation may still use explicit rounds for efficiency (the merge tree structure is known at compile time), but the DESIGN should be expressed as information flow.

### M3: NAF sync path returns inline — not information flow

The NAF "sync" path (facts-only inner goal) currently: forks, quiesces, reads result, returns. The result flows through a return value, not through a cell. This is imperative — the caller uses the return value to decide what to do next.

Per P3 resolution: both sync and async should write to a NAF-result cell. The information flow is: inner computation → NAF-result cell → NAF-gate propagator → continuation. Whether the inner computation blocks the current thread or spawns a new one is an implementation choice, not an information-flow difference.

**Action**: Phase 2 must ensure the cell-write + gate-fire pattern is invariant. The thread choice is orthogonal to the information flow.

### M4: Phase 5d context pooling — "on first query, build full context" is step-think

The design says: "on first query, build the full context, store in pool." This is a mutable-state pattern (first query triggers one-time initialization, subsequent queries reuse). The propagator-native approach: the context pool IS a cell that starts at bot (no template) and is written to when the first query creates a context. Subsequent queries read the cell value.

**Resolution**: This is a minor point — the parameter-based approach works and the state is truly write-once. But if we're being rigorous: `current-solver-context-pool` could be a cell with a "first-write wins" merge (identity merge: first non-bot value becomes the fixed value). This aligns with the on-network mandate. Low priority — the parameter approach is acceptable scaffolding.

### M5: Network Reality Check on Phase 1a (Three Binary Questions)

1. **Which `net-add-propagator` calls are added?** The arg-watcher propagator: one per discriminating argument position. This IS a propagator call.
2. **Which `net-cell-write` calls produce the result?** The arg-watcher writes to the clause decision cell (narrowing). The clause decision cell's narrowed value gates which clause propagators fire (via assumption viability). This IS cell writes producing the result.
3. **Can you trace: cell → propagator → cell → result?** Query argument cell → arg-watcher propagator → clause decision cell → assumption viability → clause propagators fire (or not) → scope cells → answer. YES — the trace is complete.

**Verdict**: Phase 1a IS on-network. The trace is clean.

---

## Summary

| ID | Lens | Finding | Severity | Original Resolution | **D.7 Outcome** |
|---|---|---|---|---|---|
| P1 | P | Step 4 ambiguous: imperative vs topology-gated | Medium | Split: construction-time for ground args, topology-request for partial. | **REVISED (§3.8)**: Eliminated construction-time path. Reactive narrowing always — arg-watcher fires in BSP round 1 for ground args. One mechanism. |
| P2 | P | Phases 5a+5c duplicate fast-paths | Medium | Merge 5a into 5c. | **ACCEPTED**: Merged into single fire-once fast-path inside BSP scheduler. Handles fact-only (worklist=0) AND single-clause (fire-once). |
| P3 | P | NAF sync path violates information-flow | Medium | Always use NAF-result cell. | **ACCEPTED**: Both sync/async write to NAF-result cell. Thread choice orthogonal to information flow. Updated in Phase 2 description. |
| P4 | P | DFS fallback justified | Low | Keep as diagnostic tool. | **ACCEPTED**: ~170 lines, no interaction with propagator infra. Diagnostic tool. |
| P5 | P | Discrimination map off-network | Low | ~~Justified — constant.~~ | **REVISED (§3.8, self-hosting lens)**: Dismissed too readily. On-network: discrimination cell with hash-union merge. Reactive updates when new clauses registered. Cost: 1 cell. |
| P6 | P | Pool parameter vs cell | Low | ~~Write-once parameter acceptable.~~ | **REVISED (§3.8, self-hosting lens)**: On-network: solver-template cell with first-write-wins merge. Observable, composable. |
| R1 | R | Non-unification first goals → wildcard in discrim map | Medium | State explicitly. | **ACCEPTED**: Documented in §3.1 + Phase 1a limitations section. |
| R2 | R | Phase 5a only helps fact-only queries, not all Tier 1 | High | Rename or expand scope. | **ACCEPTED + EXPANDED**: Fire-once fast-path handles both fact-only AND single-clause. User insight: fire-once (self-cleaning) propagator keeps single-clause on fast path. |
| R3 | R | Line count estimate low (~150 → ~210) | Low | Update estimate. | **ACCEPTED**: Estimate updated to ~210 lines. |
| R4 | R | Lazy context + worldview cache interaction | Medium | Verify. | **VERIFIED SAFE (§2.11)**: Cell-id 1 always pre-allocated, promote-cell-to-tagged has no dependency, net-cell-read defaults to 0. |
| R5 | R | Internal API test gap | Medium | Phase 1a test plan needed. | **ACCEPTED**: 5 test categories added to Phase 1a. |
| M1 | M | Construction-time narrowing is imperative but acceptable | Low | ~~Name as optimization.~~ | **REVISED (§3.8, self-hosting lens)**: Eliminated. Reactive narrowing is the only mechanism. Ground args fire watcher in BSP round 1 — "optimization" falls out from BSP scheduling. |
| M2 | M | "Rounds" in §3.7 is step-think vocabulary | Low | Reframe as merge network depth. | **ACCEPTED**: §3.7 notes that rounds emerge from merge tree depth, not imposed schedule. |
| M3 | M | NAF sync path returns inline, not via cell | Medium | Same as P3. Cell write invariant. | **ACCEPTED**: Same as P3. |
| M4 | M | Context pool parameter is mutable state | Low | ~~Acceptable scaffolding.~~ | **REVISED (§3.8, self-hosting lens)**: On-network: solver-template cell. No parameter. |
| M5 | M | Phase 1a passes Network Reality Check | — | ✅ Clean trace. | **CONFIRMED** |

### Design Changes Incorporated in D.7

1. **P2 + R2**: ✅ Merged into fire-once fast-path (Phase 5a). User expanded scope to fire-once pattern for single-clause.
2. **P3 + M3**: ✅ NAF always writes to cell. Thread choice orthogonal. Updated in Phase 2 + §3.2.
3. **P1 + M1 + P5 + P6 + M4** (self-hosting lens): ✅ All five off-network dismissals REVISED. New §3.8: discrimination map → cell, construction-time path eliminated, context pool → cell.
4. **R1**: ✅ Wildcard limitation documented in §3.1 discrimination map section + Phase 1a limitations.
5. **R3**: ✅ Estimate updated to ~210 lines.
6. **R4**: ✅ Verified safe, documented in §2.11.
7. **R5**: ✅ 5 test categories specified in Phase 1a.
8. **M2**: ✅ Noted in §3.7 (rounds = emergent from merge tree depth).
