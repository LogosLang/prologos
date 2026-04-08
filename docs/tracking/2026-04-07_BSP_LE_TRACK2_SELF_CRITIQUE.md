# BSP-LE Track 2 D.1 — Self-Critique (P/R/M Lenses)

**Date**: 2026-04-08
**Design**: [D.1](2026-04-07_BSP_LE_TRACK2_DESIGN.md)
**Methodology**: [CRITIQUE_METHODOLOGY.org](principles/CRITIQUE_METHODOLOGY.org)

---

## Lens R: Reality-Check (Code Audit)

### R1: `current-speculation-stack` consumers — design says 5, code shows 6

The design (Phase 4) identifies 5 files for speculation migration: elab-speculation-bridge, metavar-store, cell-ops, typing-propagators, narrowing.

**Code audit finds 6 files**:
1. `propagator.rkt` (definition + 2 read sites in net-cell-read/net-cell-write) — **correctly identified**
2. `elab-speculation-bridge.rkt` (1 parameterize site, line 227) — **correctly identified**
3. `typing-propagators.rkt` (6 parameterize sites, lines 258-1589) — **correctly identified**
4. `metavar-store.rkt` (1 read site, line 1321) — **correctly identified**
5. `cell-ops.rkt` (2 read sites, lines 82-83) — **correctly identified**
6. `tests/test-tms-cell.rkt` (test file — parameterizes for testing) — **MISSING from design**

**narrowing.rkt does NOT directly use `current-speculation-stack`**. It uses `atms-amb` (via `elab-speculation.rkt`) but doesn't read the parameter. Design incorrectly lists narrowing as a migration target.

**Resolution**: Remove narrowing from Phase 4 scope. Add test-tms-cell.rkt (test infrastructure, low-risk).

### R2: `atms` struct has 7 fields, not 6

Design (Phase 5) says the `atms` struct has field `tms-cells` to retire. Code audit:

```racket
(struct atms (network assumptions nogoods tms-cells next-assumption believed amb-groups) #:transparent)
```

7 fields, including `amb-groups` which the design doesn't mention. The `amb-groups` field tracks all amb choice-point groups for `atms-solve-all`. This field IS needed in the new architecture — it tracks which assumption-id sets are mutually exclusive.

**Resolution**: Design should note that `amb-groups` persists; only `tms-cells` is retired.

### R3: `prop-net-cold` has 6 fields + will grow

Design (Phase 1) adds `worldview-cid` to `prop-net-cold`. Current fields:
```racket
(struct prop-net-cold (merge-fns contradiction-fns widen-fns
                       propagators next-cell-id next-prop-id
                       cell-decomps pair-decomps cell-dirs) #:transparent)
```

That's **9 fields**, not 6. Adding `worldview-cid` makes 10. There are **48 `struct-copy` operations** in propagator.rkt. Each struct-copy copies all fields. Adding a field increases every struct-copy cost.

**Resolution**: Consider adding `worldview-cid` and `nogoods-cid` to `prop-net-warm` (2 fields: cells, contradiction) instead of `prop-net-cold` (9 fields). Warm is accessed during cell read/write — which is where worldview is needed. Cold is accessed during propagator/cell registration — where worldview is irrelevant.

### R4: `relations.rkt` is NOT imported by anyone

Code audit shows 0 files depend on `relations.rkt`. It's a leaf module — the solver is called from `reduction.rkt` via `run-solve-goal` / `stratified-solve-goal`. This means Phase 6-7 changes to `relations.rkt` have zero downstream impact. Good — but the entry points are in `reduction.rkt`, not `relations.rkt`.

**Resolution**: Design should clarify that the solver entry point is `reduction.rkt:528-633` (4 call sites) dispatching to `relations.rkt`. Phase 9 (two-tier) needs to modify the dispatch in `reduction.rkt`, not just `relations.rkt`.

### R5: `atms-amb` usage is wider than expected

`atms-amb` appears in 26 places across the codebase — but most are pipeline traversals (parser, pretty-print, substitution, zonk, etc.) handling the `expr-atms-amb` AST node. Only 3 sites actually CALL `atms-amb` as an operation:
1. `atms.rkt:216` (definition + internal use in `atms-solve-all`)
2. `elab-speculation.rkt:84` (speculation branch creation)
3. `reduction.rkt:2885` (runtime `atms-amb` evaluation)

**Resolution**: Phase 6 doesn't need to change 26 call sites. It only changes how `atms-amb` works internally (creating PUs instead of just recording assumptions). The AST node pipeline is unaffected.

### R6: Benchmark data — TMS depth scaling confirms PU-per-branch viability

Pre-0 micro-benchmarks show TMS read/write scales linearly with depth:
- Depth 1: 19ns read, 21ns write
- Depth 5: 83ns read, 137ns write (4.4×/6.5× respectively)
- Depth 10: 178ns read, 287ns write (9.4×/13.7×)

PU-per-branch avoids depth scaling entirely (depth always 1 within a PU). Network creation cost: 90ns + 270ns per cell + 810ns per propagator. A 5-cell, 3-propagator PU costs ~3.9μs to create.

**Resolution**: Data confirms PU-per-branch is the right architecture. No design change needed, but the benchmark data should be captured in the design document.

### R7: Adversarial hotspot — deep nesting is the expensive case

`atms-adversarial.prologos` shows `level4` (5 levels of binary branching, 32 leaves) at 314ms — 2× more expensive than the next command. In solve-adversarial, `color-code` (10-clause query-all) is the hotspot at 219ms.

**Resolution**: Phase 11 parity validation should specifically benchmark deep nesting and wide-clause patterns. These are the cases where propagator-native search has the most opportunity (concurrent exploration) and the most risk (PU allocation overhead × branch count).

---

## Lens M: Propagator-Mindspace

### M1: `clause-match-bulk` — is this a propagator or a function call?

Phase 6 describes `clause-match-bulk` as: "A single propagator takes resolved args + the full clause list. For each clause: α-rename, attempt unification with args."

But this reads as a function call: take input, iterate clauses, return matches. It's described as "embarrassingly parallel map" but it's implemented as a sequential function. Where are the cells? Where is the information flow?

**Challenge**: Can clause matching genuinely be a propagator? The input (resolved args) comes from cells. The output (matching clauses) could go to a cell. But the matching itself is a pure function — no lattice merge, no monotone refinement. It's a one-shot computation: args arrive → match → results.

**Assessment**: `clause-match-bulk` is correctly a FUNCTION, not a propagator. It's called WITHIN a propagator's fire function — the propagator watches the arg cells, and when args are available, fires and calls the matching function internally. The matching results then drive PU creation (topology mutation at the topology stratum).

**Resolution**: Clarify in the design: `clause-match-bulk` is a pure function called inside a goal-app propagator's fire function. It's NOT itself a propagator. This is analogous to how `numeric-join` is a pure function called inside Track 4B's typing propagator — the propagator watches cells, the function computes the result.

### M2: Phase 7 conjunction — CORRECTED but verify the correction

Phase 7 was revised to "simultaneous installation, order-independent." Verify: the revised text says "Install ALL goal propagators simultaneously — no sequencing." But the `install-conjunction` function still takes "a list of goals" — does the LIST imply ordering?

**Assessment**: The list is for enumeration (which goals to install), not for sequencing (what order to execute them). All goals' propagators are installed in one pass; execution order comes from dataflow. This is correct.

**Resolution**: No change needed, but the NTT functor `GoalConjunction` should explicitly state: "The goals list is an enumeration, not an ordering. Installation order is irrelevant."

### M3: `branch-pruner` — is PU drop a propagator operation?

The NTT model declares `branch-pruner` as a propagator with `:non-monotone` that calls `pu-drop`. But `pu-drop` is a structural operation — it discards a network reference. Is this genuinely a propagator (reads a cell, fires, produces an effect), or is it an imperative cleanup action triggered by a cell value?

**Challenge**: Can PU dropping be expressed as information flow? Dropping a PU doesn't WRITE to any cell — it removes structure. This is topology mutation, which is inherently non-monotone and happens at S(-1).

**Assessment**: The `branch-pruner` is a legitimate propagator at S(-1). It reads the worldview cell, detects contradiction, and its "write" is the topology mutation (removing the PU). This parallels how S(-1) retraction propagators already work in the existing stratified architecture — they read cells and remove/modify structure. The non-monotonicity is the point.

However: the CALM violation must be handled via the stratified topology protocol from PAR Track 1. The branch-pruner should EMIT a topology request (monotone — it writes a request to a topology-request cell), and the topology stratum EXECUTES the drop.

**Resolution**: Design should clarify that `branch-pruner` emits a drop REQUEST at S(-1) (monotone write to topology-request cell), and the topology stratum executes it. Same pattern as PAR Track 1's dynamic topology protocol.

### M4: Two-tier transition — is Tier 1→2 an on-network operation?

Phase 9 describes: "First multi-clause match detected → upgrade: create worldview cell, set `worldview-cid` in `prop-net-cold`." Setting a field on `prop-net-cold` is a `struct-copy` — an imperative mutation of the network structure.

**Challenge**: Is the tier transition information flowing through cells, or is it an imperative structural change?

**Assessment**: The tier transition IS an imperative structural change. You can't express "the network now has a worldview cell" as a cell write — it's a network topology change. This is the same category as PU creation: topology mutation at the topology stratum.

But there's a subtlety: the transition only happens once (Tier 1 → 2 is irreversible). It's not a recurring non-monotone operation — it's a one-time structural upgrade. After the transition, everything is on-network.

**Resolution**: Accept this as scaffolding — the tier transition is an imperative one-shot that creates the on-network infrastructure. Label it explicitly as "not on-network: one-time topology creation." Future work: if the network always starts with a worldview cell (Tier 2 from the start), the transition is unnecessary. The `:strategy :atms` configuration already does this.

### M5: `atms-solve-all` — is answer enumeration on-network?

The existing `atms-solve-all` in `atms.rkt` uses a Cartesian product over `amb-groups` with consistency filtering. This is a sequential algorithm (iterate all worldview combinations, filter by nogoods, collect answers). The design doesn't explicitly address how answer collection works in the propagator model.

**Challenge**: In propagator-native search, answers emerge from quiescence — the result cells of surviving branches contain the answers after all contradicted branches are pruned. But how are these collected? Is there a "scan all surviving PUs and read their result cells" step? That would be step-think.

**Assessment**: Answers should flow to an accumulator cell. Each branch's commit operation (Phase 2, `pu-commit`) writes the branch's result to a shared answer accumulator cell with set-union merge. After quiescence + S(-1) pruning + commit, the accumulator cell holds all answers. No scanning needed — the answers arrive via cell writes.

**Resolution**: Add an answer accumulator cell to the design. Each branch-committer writes its result to the accumulator. The accumulator's merge is set-union. After quiescence, read the accumulator = all answers. This replaces `atms-solve-all`.

### M6: NAF "fires after S0 quiesces" — what triggers it?

Phase 7 says NAF is at S1, firing after S0 quiesces. But S1 is readiness-triggered — a propagator at S1 fires when a threshold is reached. What's the threshold for NAF?

**Challenge**: The NAF propagator needs to know that S0 has fully quiesced and the inner goal's result cell has STABILIZED (no more changes). How does it detect this? Reading the cell and seeing ⊥ isn't enough — ⊥ might mean "not yet computed" rather than "computed and failed."

**Assessment**: This is the classic "closed-world assumption" problem in logic programming. The NAF propagator needs a COMPLETION signal — "S0 is done, this cell won't change." In BSP, this IS the barrier between S0 and S1 — the barrier is the completion signal. After the S0 barrier, all S0 propagators have fired and quiesced. S1 propagators can then check: is the cell still ⊥? If yes, the goal genuinely failed (no producer wrote to it).

**Resolution**: NAF semantics are correct under BSP barrier — the S0→S1 barrier IS the completion signal. Make this explicit in the design: the NAF propagator fires at S1 AFTER the S0 barrier confirms quiescence. The cell's value at S1 fire time is its final S0 value.

---

## Lens P: Principles Challenged

### P1: Propagator-First — is the two-tier model a compromise?

The two-tier model (Tier 1 = no ATMS, Tier 2 = full ATMS) means deterministic queries bypass the worldview lattice entirely. Is this a concession to performance that violates Propagator-First?

**Challenge**: If worldview is fundamental to the architecture, should ALL queries have a worldview cell? The empty worldview (⊥ = no assumptions) is a valid lattice value. Tier 1 could be: worldview cell exists, value is ⊥, all operations pass through TMS with ⊥ stack = O(1) base read.

**Assessment**: The Pre-0 benchmarks show TMS depth-1 read is 19ns vs. plain read (no TMS) which is effectively 0ns. For deterministic queries that never branch, the 19ns overhead per cell read is measurable but small. For a query with 1000 cell reads, that's 19μs overhead.

The question: is 19μs per query worth the architectural purity of "always have a worldview cell"?

**Resolution**: This is a genuine trade-off. Tier 1 (no worldview cell) is a performance optimization that sacrifices architectural uniformity. Tier 2 (always worldview cell) is principled but adds ~19μs per deterministic query. The design should present this as a decision with data, not assume Tier 1 is correct. The `:strategy :atms` configuration already provides Tier 2 — making it the default and removing Tier 1 is architecturally cleaner.

### P2: Completeness — does the design handle ALL goal types?

Phase 7 lists 5 goal types: app, unify, is, not, guard. Are there others?

**Code audit**: `solve-single-goal` in `relations.rkt` dispatches on:
- `app` ✓
- `unify` ✓
- `is` ✓
- `not` ✓
- `cut` — **MISSING from design**
- `guard` ✓

The design doesn't mention `cut`. The PUnify Part 3 document (§3.4) explicitly says "No `cut`" — it's deprecated under ATMS. But the code still has a `cut` case (line 674-676: returns current substitution).

**Resolution**: Design should explicitly address `cut`: under `:strategy :atms` and `:strategy :auto`, `cut` is a no-op (ATMS handles pruning via nogoods, not control-flow cuts). Under `:strategy :depth-first`, `cut` preserves existing DFS semantics. Add a note to Phase 7.

### P3: Correct-by-Construction — is PU isolation guaranteed?

The design claims PU-per-branch provides structural branch isolation. But does it? If a branch PU reads parent cells (it must — to see base facts), and writes to those parent cells (during unification with shared variables), the isolation could leak.

**Challenge**: What prevents a branch PU from writing to a parent cell and having that write visible to sibling branches?

**Assessment**: The TMS handles this. A branch PU's writes go through TMS-aware `net-cell-write`, which tags writes with the branch's assumption-id. Sibling branches reading the same cell see only their own tagged values (or base values). This is correct — TMS branch isolation IS the mechanism.

But the PU-per-branch model adds STRUCTURAL isolation (separate network) ON TOP OF TMS isolation (branch-tagged values). Are both needed? Could we have TMS isolation alone (all branches on the same network, TMS-tagged writes)?

**Assessment**: Both provide isolation, but PU-per-branch adds structural GC (dropping a PU is O(1), cleaning TMS branches from a shared network is O(cells)). The structural isolation is not for correctness — TMS handles correctness. It's for allocation efficiency (the Phase 0b concern). This should be stated explicitly.

**Resolution**: Clarify in the design: TMS provides CORRECTNESS isolation (branch-tagged values are invisible across branches). PU provides EFFICIENCY isolation (structural GC on contradiction). Both are needed, but for different reasons.

### P4: Decomplection — are worldview and computation genuinely separated?

The design puts worldview cells on the outer network and computation in PUs. But Phase 5 (ATMS bridge) has the ATMS struct managing worldviews imperatively (`atms-add-nogood` returns new ATMS value) while the worldview cell reflects this state.

**Challenge**: Is the ATMS struct a second source of truth alongside the worldview cell? If so, that's a coupling (two representations of worldview state).

**Assessment**: Yes — after Phase 5, the ATMS struct AND the worldview cell both represent worldview state. The ATMS is the "manager" (adds assumptions, records nogoods), the cell is the "broadcast" (propagators read it). The bridge keeps them in sync. This IS a coupling.

**Resolution**: Accept as necessary scaffolding for Track 2. The ATMS struct manages the combinatorial logic (mutual exclusion, nogood checking, worldview enumeration) that is not yet expressible as pure cell operations. A future track could dissolve the ATMS struct entirely — assumptions as cells, nogoods as cells, mutual exclusion as propagators. But that's a deeper redesign. Note this as a Track 3 or Track 4 consideration.

---

## Summary

| Finding | Lens | Severity | Resolution |
|---------|------|----------|------------|
| R1: Migration scope off (6 files, not 5; narrowing excluded) | R | Medium | Fix Phase 4 scope |
| R2: ATMS has 7 fields, `amb-groups` persists | R | Low | Note in Phase 5 |
| R3: `prop-net-cold` has 9 fields; worldview-cid better in warm | R | Medium | Move to prop-net-warm |
| R4: Solver entry point is reduction.rkt, not relations.rkt | R | Low | Clarify dispatch path |
| R5: atms-amb has 3 real callers, not 26 | R | Low | Correct scope note |
| R6: Benchmark data confirms PU-per-branch viable | R | — | Capture data in design |
| R7: Deep nesting is the hotspot to benchmark | R | Low | Add to Phase 11 |
| M1: clause-match-bulk is a function, not a propagator | M | Medium | Clarify in design |
| M2: GoalConjunction list is enumeration, not ordering | M | Low | Note in NTT model |
| M3: branch-pruner should emit request, not directly drop | M | Medium | Align with PAR Track 1 topology protocol |
| M4: Tier 1→2 transition is imperative one-shot | M | Low | Label as scaffolding |
| M5: Answer collection needs accumulator cell | M | **High** | Add accumulator to design |
| M6: NAF completion signal = BSP S0→S1 barrier | M | Medium | Make explicit |
| P1: Two-tier vs always-worldview — 19μs trade-off | P | Medium | Present as decision with data |
| P2: `cut` goal type missing from Phase 7 | P | Low | Address explicitly |
| P3: PU isolation = efficiency; TMS = correctness | P | Medium | Clarify both roles |
| P4: ATMS struct is second source of truth | P | Medium | Label as scaffolding for Track 2 |
