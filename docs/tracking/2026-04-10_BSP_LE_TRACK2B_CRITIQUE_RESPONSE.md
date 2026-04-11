# BSP-LE Track 2B External Critique Response

**Date**: 2026-04-10
**Critique**: `docs/tracking/2026-04-10_BSP_LE_TRACK2B_EXTERNAL_CRITIQUE.md`
**Design**: D.7 → D.8

---

## Responses

### P1/R1: `solve-goal-propagator` calls GS, not BSP — Critical

**Accept problem. Reframe solution.**

The critique frames this as a "hidden prerequisite" — as if BSP is overhead to be avoided. But developing the BSP solver IS the point of this track. We want to explore the potential of parallel search and resolution of logic programming. BSP isn't overhead — it's the architecture.

The GS-to-BSP switch is Phase 1a's prerequisite, not a separate phase. When clause selection narrowing is installed (Phase 1a), the solver needs BSP to fire the arg-watcher propagators across rounds. The switch happens naturally as part of making the solver propagator-native.

The optimization pipeline (5a fire-once fast-path) then makes BSP competitive with GS for Tier 1 queries. The sequence is: switch to BSP → fire-once fast-path eliminates BSP ceremony for trivial queries → BSP is cost-neutral for Tier 1, beneficial for Tier 2.

**Action**: Note in Phase 1a that the GS-to-BSP switch is step 0. Add a micro-benchmark AFTER the switch to verify Tier 1 cost.

### P2: Phase 5a/5c still separate in roadmap — Major

**Accept.** The critic is right — the progress tracker was updated but the roadmap descriptions were NOT. This is a consistency failure in the document. Stale Phase 5a, 5c, and 5d descriptions remain in §5 despite the §3.6 optimization section and progress tracker reflecting the merge.

**Action**: D.8 must clean up the roadmap: remove old Phase 5a/5c/5d descriptions, write new Phase 5a (fire-once, merged), Phase 5b (lazy context), Phase 5c (solver-template cell) descriptions that match the progress tracker.

### P3: NAF adaptive dispatch = structural introspection — Major

**Accept problem, accept deferred-spawn solution.** The emergent approach is better: start inner BSP on current thread; if it converges in one round (fire-once), result is immediate. If not, spawn thread and continue asynchronously. The thread decision emerges from computation behavior, not from static relation-info inspection.

**Action**: Revise Phase 2 to use deferred-spawn pattern. Remove `variant-info-clauses` introspection.

### P4: Discrimination cell has no producing propagator — Major

**Accept.** This fits in Phase 1a — it's part of the clause selection mechanism. When discrimination map extraction (Phase 1a step 1) computes the map, it writes to a discrimination cell. For Phase 0 Racket, this is an eager write at relation-registration time (scaffolding). The producing propagator is scaffolding with retirement plan for self-hosting (when relation registration is itself on-network).

**Action**: Phase 1a step 1 explicitly allocates the discrimination cell and writes the map to it.

### P5: Conjunction ordering IS relevant for NAF/guard — Major

**Accept problem. Apply hypercube prefix insight.**

The critique is right that installation order affects BSP round count for NAF/guard goals. But the solution is NOT imposed ordering — it's the hypercube parallel prefix algorithm from our research conversation.

For a conjunction with dependency chains (goal A → goal B → goal C), the parallel prefix algorithm organizes the information flow so the chain converges in O(log(chain_length)) BSP rounds instead of O(chain_length). The key: each goal's propagator is installed with the same topology (no ordering), but the BSP scheduler's dataflow-driven firing naturally produces the prefix-optimal convergence pattern.

For NAF/guard goals specifically: the NAF-gate/guard-gate propagators residuate until their input cells resolve. This IS the parallel prefix pattern — each gate is a "join" that waits for its input. The BSP scheduler fires all gates simultaneously; those whose inputs are available produce results, which feed into the next round's gates. Chain convergence in O(log N) rounds emerges from the topology.

The current `for/fold` installation order doesn't affect correctness (CALM) or convergence rate (BSP round count is determined by dataflow depth, not installation order). Installation order DOES affect which propagators are on the worklist in round 1, but residuation handles the rest.

**Action**: Note in design that conjunction convergence follows the parallel prefix pattern from hypercube research. Conjunction installation order is irrelevant for both correctness AND performance — BSP dataflow depth determines convergence.

### P6: DFS retirement condition — Minor

**Reject with justification.** DFS is not being retired. BSP is an alternative solver backend, not a replacement. The vision includes multiple solver backends (DFS, BSP/propagator-native, well-founded/bilattice). `:strategy` already supports dispatch. DFS remains as `:depth-first`.

### R2: Fact-row PU estimate too low — Major

**Accept.** Revised to ~60-80 lines for fact-row PU (mirrors multi-clause infrastructure).

### R3: Bitmask namespace collision — Major

**Accept.** Fact-row and clause assumptions must be allocated from the same counter via `solver-assume`. This is already how multi-clause works — extend to fact rows.

### R4: Phase 5c/5d overlap — Minor

**Accept.** Remove old Phase 5d. Phase 5c IS the solver-template cell (the on-network version of context pooling).

### R5: Cross-network NAF write unresolved — Major

**Defer to Phase 2 design.** We have mechanisms: topology requests (between BSP rounds), cross-network cell writes (CHAMP is pure functional), component-indexed compound cells. The specific mechanism will be designed when Phase 2 goes deeper. Not concerned about this — it's implementation detail within existing infrastructure patterns.

### R6: Guard parameter capture — Minor

**Accept.** Capture `current-is-eval-fn` at installation time in Phase 3.

### M1: Current NAF is imperative no-op — Major

**Accept.** NAF must be brought on-network. Inner success detection = answer-accumulator cell non-bot (single cell read, not env-scanning). Phase 2 builds this.

### M2: Lazy context flag is imperative — Minor

**Accept.** Solver-context as monotone cell refinement (minimal → full). Cell write, not flag check.

### M3: Hypercube merge sketch uses imperative vocabulary — Minor

**Accept.** This was the same critique point from the self-critique (M2). The design document was NOT updated carefully after the self-critique — the sketch still uses `my-result` and `shared-buffer`. Must rewrite as propagator network description. This reveals a process issue: self-critique resolutions were noted but not always applied to the document text.

### M4: Guard adds one BSP outer round — Observation

**Accept as performance characteristic.** The topology request protocol inherently adds one outer loop round. This is the CALM-safe cost of dynamic topology mutation. For the common case (one guard per conjunction), the cost is one extra round — acceptable. For multiple guards, the rounds don't actually accumulate if the guards are independent (they all fire in the same topology stratum).

If guards are chained (guard A gates goal B which feeds guard C), the depth is O(log N) via the parallel prefix pattern (same as P5). Not O(N).

### M5: NTT model missing conjunction wiring — Major

**Accept.** Add conjunction construct to NTT model showing: goal cells → NAF-gate/guard-gate outputs → next-goal inputs. The wiring IS the dataflow topology — subsequent goals watch prior goals' output cells.

### M6: Conjunction for/fold is self-hosting debt — Observation

**Accept.** Documented as scaffolding.

---

## Summary of Actions for D.8

| Finding | Action | Where |
|---|---|---|
| P1/R1 | GS-to-BSP switch is Phase 1a step 0, not separate phase | Phase 1a |
| P2 | Clean up roadmap: remove stale 5a/5c/5d, write consistent descriptions | §5 roadmap |
| P3 | NAF deferred-spawn (emergent thread decision) | Phase 2, §3.2 |
| P4 | Discrimination cell allocated in Phase 1a step 1 | Phase 1a |
| P5 | Conjunction convergence via parallel prefix (hypercube) | §3.5 |
| P6 | DFS is alternative backend, not being retired | §1, remove retirement language |
| R2 | Fact-row PU estimate: ~60-80 lines | Phase 1a |
| R3 | Bitmask allocation via solver-assume | Phase 1a step 5 |
| R4 | Remove old Phase 5d from roadmap | Progress tracker + §5 |
| R6 | Capture current-is-eval-fn at installation | Phase 3 |
| M1 | NAF on-network: answer-acc cell read for success detection | Phase 2 |
| M2 | Lazy context as monotone cell refinement | Phase 5b |
| M3 | Rewrite hypercube merge sketch as propagator network | §3.7 |
| M5 | Add conjunction construct to NTT model | §4 |
| M6 | Note for/fold as scaffolding | §3.5 |

### Process Observation

The critique revealed that self-critique resolutions were incompletely applied to the design document. The progress tracker and §3.6 optimization section were updated, but the §5 roadmap descriptions were not. The §3.7 merge sketch vocabulary was noted (M2 self-critique) but not rewritten. This is a consistency gap in our D.N iteration process — each revision should include a consistency pass across ALL sections, not just the sections directly affected by the finding.
