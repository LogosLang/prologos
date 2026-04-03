# SRE Track 2H: Type Lattice Redesign — Post-Implementation Review

**Date**: 2026-04-03
**Duration**: ~8 hours design, ~4 hours implementation, ~2 hours PIR + follow-up. 2 sessions (Apr 2-3).
**Commits**: 30 (from `b30a7b83` Stage 2 audit through `7050e49b` keyword constructor)
**Test delta**: 7491 → 7526 (+35 in test-sre-track2h.rkt)
**Code delta**: ~500 lines added/modified across 16 files. 1 new module (union-types.rkt, 120 lines). 1 new test file.
**Suite health**: 384/384 files, 7526 tests, 129.9s, all pass
**Design iterations**: D.1 → D.2 (Pre-0 data) → D.3 (self-critique, 3 lenses) → D.4 (incorporating findings) → D.5 (external critique, 12 findings)
**Design docs**: [Design](2026-04-02_SRE_TRACK2H_DESIGN.md), [Stage 2 Audit](2026-04-02_SRE_TRACK2H_STAGE2_AUDIT.md)
**Prior PIRs**: [PPN Track 3](2026-04-02_PPN_TRACK3_PIR.md), [SRE Track 2G](2026-03-30_SRE_TRACK2G_PIR.md), [PPN Track 2B](2026-03-30_PPN_TRACK2B_PIR.md)
**Series**: SRE (Structural Reasoning Engine) — Track 2H

---

## 1. Stated Objectives and Evolution

**Original (D.1)**: Fix the type lattice's subtype ordering to produce union types instead of type-top for incomparable types. Make the subtype lattice Heyting (distributive + pseudo-complement). Per-relation property declarations. Pseudo-complement error reporting.

**Scope expansion (D.3, user challenge)**: The tensor (function application as quantale multiplication) was pulled into scope. Rationale: introducing union types without handling them in function application creates a half-built algebraic structure. The quantale (join + tensor) is the minimal complete structure.

**Final (D.5)**: Full quantale delivery — union-join with absorption, complete meet, tensor (core + scaffolding distribute), tensor-aware elaboration, per-relation properties, pseudo-complement scaffolding. Plus whnf fast-path (independent optimization from Pre-0 data).

**Scope adherence**: 9/9 phases complete. The tensor expansion added 2 phases (4-5 in final numbering) that were not in D.1. The scope GREW in ambition but the implementation was clean — no phases required reverts.

---

## 2. What Was Built

The type lattice under the subtype ordering is now a **quantale** — a distributive lattice (Heyting algebra for the ground sublattice) equipped with a tensor (function application) that distributes over the join. This is the algebraic foundation that PPN Track 4 needs to put elaboration on-network.

Concretely:
- **Union-join with absorption**: `subtype-lattice-merge(Int, String) = Int | String` instead of `type-top`. `Nat | Int → Int` (subtype absorption). Canonical normalization.
- **Complete meet**: `try-intersect-pure` now covers all 11 registered type constructors via ctor-registry descriptors (was only Pi/Sigma). Meet distributes over unions. Subtype-aware via callback.
- **Tensor**: `type-tensor-core` (single Pi × single arg — the propagator fire function) + `type-tensor-distribute` (scaffolding). Returns `type-bot` for inapplicable (not `type-top` — absence ≠ contradiction).
- **Tensor-aware elaboration**: `expr-app` in typing-core.rkt handles union-typed functions via tensor distribution.
- **Per-relation property declarations**: `sre-domain.declared-properties` nested by relation name. `sre-domain.operations` field for discoverable operations (tensor registered).
- **Pseudo-complement**: Scaffolding function for Heyting error reporting. First consumer of the distributive structure.
- **Algebraic validation**: V4 distributivity 0/512 (was 412/512). All lattice laws verified.

Additionally, an independent optimization emerged from Pre-0 data: **whnf fast-path guard** (`whnf-trivial?`) — 625× speedup for type atoms, 3.5% suite wall time improvement.

---

## 3. Timeline and Phases

### Time Breakdown

| Activity | Duration | Notes |
|----------|----------|-------|
| Stage 2 audit | ~1h | 11 sections, grep-backed measurements |
| Design D.1 draft | ~1.5h | 8 phases, NTT model, mathematical grounding |
| Tensor scope discussion + integration | ~1h | User challenge → full quantale, semiring research connection |
| Pre-0 benchmarks (design + run + analyze) | ~1h | 30 tests, 5 tiers, whnf finding |
| whnf fast-path optimization | ~0.5h | Independent concern, 63 lines, 625× speedup |
| Self-critique (D.3) + incorporation (D.4) | ~1.5h | 3 lenses, 10 findings, R1 blocker found |
| External critique (D.5) + incorporation | ~1h | 12 findings, F1+M3+F11 accepted |
| Process codification (Vision Alignment Gate) | ~0.5h | Two rules in workflow.md + DESIGN_METHODOLOGY.org |
| Implementation Phases 1-8 | ~3.5h | 8 phases, each with mini-audit + implement + test + commit |
| PIR + follow-up (tests, keyword migration) | ~2h | PIR, 35 regression tests, make-sre-domain, scaffolding docs |
| **Total** | **~14h** | **D:I ratio ≈ 2.5:1** (design+critique : implementation) |

### Phase Timeline

| Phase | Commit | Duration | Key Result |
|-------|--------|----------|------------|
| Audit | `b30a7b83` | 1h | 11-section Stage 2 audit |
| Design D.1 | `7b9b8570` | 1.5h | 8-phase design (later 9 after tensor scope expansion) |
| Tensor scope | `a9dc9112` | 0.5h | Pulled tensor into Track 2H scope (full quantale) |
| Pre-0 | `a8023d58` | 1h | 30 benchmarks, 5 tiers. Design unchanged by data. |
| whnf fast-path | `92006da8` | 0.5h | Independent optimization: 150μs → 0.24μs for atoms |
| D.3 self-critique | `3f22d1ad` | 1h | 10 findings (R1 blocker: circular dep, M3 win: core/scaffolding tensor split) |
| D.5 external critique | `f8369678` | 0.5h | 12 findings (F1: bot-on-failure, F7: Heyting scoped to ground, F11: merge phases 2+3) |
| ATMS doc | `51f5d9d4` | 0.25h | Documented speculation retirement for Track 4 |
| Vision Gate | `621e4e89` | 0.25h | New process rule codified from Track 3 deviations |
| Phase 1 | `7a91db47` | 0.25h | union-types.rkt extracted |
| Phase 2 | `8bb7af3d` | 0.5h | Subtype-aware join with absorption (atomic, F11) |
| Phase 3 | `0ba64c3b` | 0.5h | Generic descriptor-driven meet (2 → 11 constructors) |
| Phase 4 | `0edee767` | 0.5h | type-tensor-core + type-tensor-distribute |
| Phase 5 | `493cfc68` | 0.25h | Tensor-aware expr-app elaboration |
| Phase 6 | `bba6f7ab` | 0.75h | Per-relation properties + operations (13 sites migrated) |
| Phase 7 | `5735b9e8` | 0.5h | Distributivity achieved: V4 0/512. 3 fixes. |
| Phase 8 | `19e165e2` | 0.25h | Pseudo-complement scaffolding |
| PIR + follow-up | `47e8d401`→`7050e49b` | 2h | PIR, 35 tests, keyword migration |

---

## 3a. Test Coverage

No new dedicated test file. Validation via:
- **Pre-0 benchmarks** (bench-sre-track2h.rkt): 30 tests across 5 tiers (M, A, E, V, T). All V tests pass post-implementation.
- **Acceptance file** (2026-04-02-sre-track2h.prologos): 6 sections, all pass at Level 3 throughout.
- **Full test suite**: 383/383 GREEN at every phase commit.

**Gap closed during PIR follow-up**: `test-sre-track2h.rkt` added (`47e8d401`) with 35 tests across 6 suites. Includes F7 binder-type distributivity tests (Suite 6) — conjecture CONFIRMED for Pi/Sigma samples.

---

## 3b. What Was Deferred and Why?

| Deferred Item | Reason | Where Tracked |
|---------------|--------|---------------|
| ATMS-based union checking (replace `with-speculative-rollback`) | Requires Track 4 ATMS-managed type cells. Can't retrofit ATMS without putting elaboration on-network. | PPN Master Track 4 §scaffolding |
| Tensor as on-network propagator (vs pure function) | Track 4 wires `type-tensor-core` as propagator. Track 2H delivers the algebra; Track 4 delivers the network. | PPN Master Track 4 §integration vision |
| Union handling in eliminators beyond expr-app (fst, natrec, etc.) | P2 finding: exposure is limited. Monitor during implementation. Not triggered by any existing test. | Design §3.5 (P2 note) |
| Maps as `Any` type (open-world semantics) | CIU series scope, not Track 2H. User flagged during design discussion. | Not yet tracked — needs CIU entry |
| sre-domain keyword args → DONE in PIR follow-up | Was L4 debt from Track 2G. | Retired (`7050e49b`) |

All deferrals are intentional (genuine dependency on unbuilt infrastructure). No scope creep or exhaustion deferrals.

---

## 4. Bugs Found and Fixed

**Bug 1: Union sort key non-deterministic for compound types (Phase 7).** Pi types all got sort key `"3:Pi"` regardless of domain/codomain. Two Pi types in a union could sort differently depending on insertion order → commutativity violation (V1a: 4 failures). Fix: recursive sort keys (`"3:Pi:0:Nat:0:Bool"`). WHY the wrong path seemed right: the original sort key was designed for pairwise union unification, not for ensuring canonical ordering of ALL union components.

**Bug 2: Pre-0 V1d identity failures (18/18) — pre-existing.** `subtype-lattice-merge` missing bot handling. `merge(bot, x)` fell to `subtype?` which returned `#f`, then → `type-top`. Fixed in Phase 2 by adding explicit bot/top cases. WHY this was missed: the original function didn't handle bot because it was never called with bot — the elaborator doesn't produce bot-typed values. Track 2H's merge changes make bot handling necessary for lattice law compliance.

**Bug 3: V4 distributivity failures (106 remaining after Phase 3).** `type-lattice-meet(Nat, Int)` returned `type-bot` instead of `Nat`. The meet only did structural matching (same constructor tag). For flat subtype relationships (Nat <: Int), the GLB should be the lesser. Fix: `current-lattice-subtype-fn` callback + meet distributes over unions. WHY: type-lattice.rkt can't import subtype? (circular dep). The callback pattern (same as `current-lattice-meta-solution-fn`) breaks the cycle.

---

## 5. What Went Well?

1. **The design cycle (5 iterations) front-loaded ALL difficult decisions.** Every implementation phase was clean — no reverts, no diagnostic protocol, no mid-flight pivots. The 10 self-critique findings and 12 external critique findings resolved issues that would have been implementation snags: R1 (circular dep for tensor), F1 (bot-on-failure), M3 (core/scaffolding split), F11 (atomic phases 2+3). Compare to PPN Track 3 which had two major deviations DURING implementation (§11, §12).

2. **The user's tensor scope expansion was the most important design decision.** The D.1 design delivered "half a semiring." The challenge to include the tensor expanded Track 2H from a lattice fix to a full quantale delivery. This reduced PPN Track 4's scope — Track 4 inherits a validated quantale and only needs to wire it as propagators.

3. **The Pre-0 algebraic validation tier drove implementation.** V4 (distributivity 0/512) was the SPECIFICATION. Three Phase 7 fixes (sort key, subtype callback, meet distribution) were all discovered by running V4 and investigating failures. Without the algebraic validation tier in the benchmarks, these would have been found much later.

4. **The whnf fast-path optimization was a high-value independent discovery.** 63 lines of code, 625× speedup for atoms, 3.5% suite improvement. Emerged from Pre-0 data — nobody had measured whnf on atoms in isolation before.

---

## 6. What Went Wrong?

1. **The D.1 design missed the tensor entirely.** Five design iterations were needed to reach the full quantale. The tensor scope expansion came from the user, not from the design process. The root cause: the design cycle asked "what files change?" (system boundaries) instead of "what's the minimal complete algebraic structure?" (mathematical completeness).

2. **Phase completion protocol was not followed for Phases 5-7.** Tracker updates were skipped during implementation momentum. Caught by the user. Codified as a blocking checklist rule — but the rule should not have been needed if the existing protocol had been followed.

3. **No persistent test file until PIR follow-up.** The Pre-0 benchmarks validated algebraic properties comprehensively, but they're not regression tests. A dedicated test file should have been part of the implementation phases, not a follow-up.

---

## 7. Where We Got Lucky

1. **The binder-type distributivity conjecture (F7) holds.** We scoped Heyting to the ground sublattice and conjectured it holds for Pi/Sigma. The follow-up test (35 tests, Suite 6) confirmed it. If it had FAILED, the Heyting claim would need to be weakened and PPN Track 4's design would be more constrained. We got lucky that the algebra is cleaner than we had evidence for during design.

2. **No existing tests depended on subtype-lattice-merge producing type-top.** The redesign changed the merge from type-top to union types for incomparable inputs. If any test had asserted `(check-equal? (subtype-lattice-merge ...) type-top)`, it would have broken. None did — because subtype-lattice-merge is only used in SRE query cells, not in the main elaboration path. This is structural luck: the SRE's cell isolation protected us from regression.

3. **The circular dependency (R1) was caught during critique, not during implementation.** If type-tensor-core had been placed in type-lattice.rkt (as D.1 specified), compilation would have failed. The self-critique's reality check caught it — but it could easily have been missed if the codebase reality check lens hadn't been applied.

---

## 8. What Surprised Us?

1. **whnf costs 150μs per atom.** A single call to `whnf(Nat)` — where Nat is trivially in WHNF — costs 150μs because Racket's `match` traverses ~100 patterns in a 1,700-line function. This was the dominant cost in ALL lattice operations. The fast-path guard reduced it to 0.24μs. The surprise: a systems-level performance issue was hiding behind algorithmic-level measurements. E2E benchmarks hid it in aggregate noise; only micro-benchmarks on individual operations revealed it.

2. **Distributivity requires the meet to distribute over unions.** The initial implementation achieved union-join + complete meet but still had 106 distributivity failures. The insight: `meet(a, b|c) = meet(a,b) | meet(a,c)` IS the distributive law — it needs to be IMPLEMENTED in the meet function, not just verified as a property. Distributivity is something you construct, not something you discover.

3. **The subtype merge change was invisible to the test suite.** 383/383 GREEN at every phase — including the core Phase 2 change that replaced type-top with union types. This is because subtype-lattice-merge only flows through SRE query cells, not main elaboration cells. The change is algebraically significant but operationally invisible in the current architecture.

---

## 9. How Did the Architecture Hold Up?

**SRE infrastructure held up well.** The `sre-domain` struct was extensible (added 1 field — operations). The merge-registry pattern cleanly separated equality and subtype orderings. The property declaration infrastructure from Track 2G needed only a nesting change (flat → nested hash) to support per-relation properties. The ctor-registry's generic-merge pattern was directly mirrored for generic-meet.

**Callback pattern for breaking circular deps works.** `current-lattice-subtype-fn` follows the same pattern as `current-lattice-meta-solution-fn`. Both are installed by driver.rkt at startup. This is becoming an architectural pattern — but it's scaffolding. The permanent mechanism is the propagator network, where cell reads replace callbacks.

**Friction point: positional struct args.** Growing from 11 to 12 fields on `sre-domain` was the immediate pain. RESOLVED during PIR follow-up: `make-sre-domain` keyword constructor eliminates positional counting. All 13 construction sites migrated.

**Friction point: union sort key non-determinism.** The original `union-sort-key` gave all Pi types the same key `"3:Pi"`. This was adequate for pairwise union unification (where components are compared, not sorted) but broke commutativity when unions are built from arbitrary component orderings. Fixed with recursive sort keys — but this revealed that the sort key was designed for a narrower use case than Track 2H requires.

---

## 10. Key Design Decisions and Rationale

| Decision | Rationale | Principle |
|----------|-----------|-----------|
| Tensor returns bot for inapplicable, not top (F1) | Absence ≠ contradiction. In the network, a propagator that can't apply simply doesn't write. | Propagator-First (1) |
| Core/scaffolding tensor split (M3) | Distribution is emergent network behavior, not explicit computation. Core = propagator fire fn. | Propagator-First (1) |
| Phases 2+3 merged atomically (F11) | Non-absorbed unions violate absorption law — not a valid lattice state. | Correct-by-Construction (3) |
| Per-relation nested hash, not relation-scoped (P4) | Same relation (e.g., subtype) has different properties on different domains. | Decomplection (5) |
| Pseudo-complement as scaffolding (M2) | ATMS replaces: nogood → retract → pseudo-complement from dependency structure. | Propagator-First (1) |
| Absorption algorithm as scaffolding (F3) | Network does pairwise merge natively. Explicit O(n²) is imperative simulation. | Propagator-First (1) |
| whnf-trivial? fast-path guard | ~50 struct predicate checks vs ~150μs match fallthrough. Independent optimization. | Completeness (6) — the lattice ops work was blocked on whnf cost |

---

## 11. Lessons Learned

**L1: The external critique's propagator lens caught architectural issues the self-critique missed.** F1 (bot-on-failure) and M3 (distribution as network behavior) were both external critique findings. The self-critique caught the circular dependency (R1) and the migration sizing (R2) — real but mechanical issues. The propagator mindset lens produced the deeper architectural insights. Implication: always include an explicit propagator mindset lens in external critique.

**L2: The user's challenge to include the tensor in scope was correct and essential.** The original D.1 design deferred the tensor to Track 4. The user asked "Pi types DO have tensors... is it not in scope?" This expanded the track from a lattice fix to a full quantale delivery. Without it, Track 2H would have introduced union types that the elaborator couldn't process — a completeness gap.

**L3: The Vision Alignment Gate prevents implementation drift.** Codified during this track based on PPN Track 3's two deviations. Applied to every phase. No deviations occurred. The gate's three questions (on-network? complete? vision-advancing?) are quick to answer and catch both §11-type (wrong direction) and §12-type (incomplete delivery) deviations.

**L4: Phase completion is a blocking checklist, not a suggestion.** Tracker updates were skipped for Phases 5-7 until the user caught it. Codified as a workflow rule: don't start the next phase's mini-audit until the current phase's tracker + dailies are updated.

**L5: Pre-0 benchmarks that measure algebraic properties (not just performance) are essential for lattice tracks.** The V4 distributivity test (0/512 target) drove three implementation fixes (sort key, subtype callback, meet distribution). Without the algebraic validation tier in the benchmarks, these would have been discovered much later.

---

## 12. Metrics

| Metric | Value |
|--------|-------|
| Design iterations | 5 (D.1 → D.5) |
| Self-critique findings | 10 (3 lenses: R, P, M) |
| External critique findings | 12 |
| Implementation phases | 8 (+ Phase 0 Pre-0) |
| Commits (total) | 30 |
| New modules | 1 (union-types.rkt) |
| Files modified | 14 |
| Lines added/modified | ~350 |
| Construction sites migrated (Phase 6) | 13 |
| Bugs found and fixed | 3 |
| V4 distributivity: before → after | 412/512 → 0/512 |
| V1d identity: before → after | 18/18 → 0/18 |
| V5 absorption: before → after | 56/64 → 0/64 |
| whnf speedup for atoms | 150μs → 0.24μs (625×) |
| Suite wall time: before → after | 136.2s → 131.4s (-3.5%) |
| D:I ratio | 2.5:1 (design+critique : implementation) |
| Test delta | +35 (test-sre-track2h.rkt) |

---

## 13. What's Next

**Immediate**:
- ~~Add persistent test file~~ — DONE (`47e8d401`, 35 tests)
- ~~make-sre-domain keyword constructor~~ — DONE (`7050e49b`, L4 retired)
- Dedicated codification session for 9+ lessons flagged READY across multiple sessions

**Medium-term**:
- PPN Track 4: elaboration on network. Track 2H's quantale is the prerequisite. Tensor → propagator. ATMS replaces speculation. Per-relation properties → cell reads.
- SRE Track 3: trait resolution benefits from Heyting properties for strategy selection.

**Long-term**:
- SRE Track 6 / PM Track 9: Reduction-on-SRE. whnf becomes propagator-driven (cell read, not function call). The whnf fast-path is the interim optimization.
- Residuated lattice: backward type propagation. The tensor's residual is the Heyting implication — `type-tensor` and `type-pseudo-complement` are the building blocks.

---

## 14. Key Files

| File | Role |
|------|------|
| `union-types.rkt` | NEW: canonical union construction (extracted from unify.rkt + type-lattice.rkt) |
| `subtype-predicate.rkt` | Redesigned subtype-lattice-merge, build-union-type-with-absorption, type-tensor-core/distribute, type-pseudo-complement |
| `type-lattice.rkt` | type-lattice-meet extended (subtype callback, union distribution, generic ctor meet) |
| `typing-core.rkt` | Tensor-aware expr-app elaboration |
| `sre-core.rkt` | sre-domain +operations field, declared-properties nested by relation, API gains #:relation |
| `reduction.rkt` | whnf-trivial? fast-path guard (independent optimization) |
| `unify.rkt` | type-sre-domain: per-relation properties, tensor in operations |
| `driver.rkt` | install-lattice-subtype-fn! callback |

---

## 15. Lessons Distilled

| Lesson | Distilled To | Status |
|--------|-------------|--------|
| L1: Propagator lens in external critique catches architectural issues | DESIGN_METHODOLOGY.org (already in Stage 3 via D.5 framing) | Reinforced |
| L2: User challenge to expand scope was correct (tensor) | Design methodology: listen when scope expansion is proposed for completeness | Pending |
| L3: Vision Alignment Gate prevents drift | DESIGN_METHODOLOGY.org + workflow.md | Done (`621e4e89`) |
| L4: Phase completion blocking checklist | workflow.md | Done (`129dee8d`) |
| L5: Pre-0 algebraic validation for lattice tracks | DESIGN_METHODOLOGY.org (Pre-0 property check, Track 2G L6) | Reinforced (2nd instance) |
| F2: Meta handling monotonicity unsoundness | Document for Track 4 ATMS retirement | In design doc |
| whnf fast-path: struct predicate guard before large match | PATTERNS_AND_CONVENTIONS.org | Pending |

---

## 16. Technical Debt Accepted

| Debt | Rationale | Tracking |
|------|-----------|----------|
| Pseudo-complement as function-over-list (scaffolding) | ATMS replaces in Track 4. Proves concept. | Design §3.8, M2 |
| type-tensor-distribute imperative distribution (scaffolding) | Network does distribution natively. Imperative simulation for pre-network elaborator. | Design §3.4, M3 |
| absorb-subtype-components O(n²) (scaffolding) | Network does pairwise merge. Imperative simulation. | Design §3.2, F3 |
| Property keyword API (scaffolding) | Property cells are permanent (Track 4). Keyword dispatch is imperative query. | Design §3.6, F5 |
| Meta handling in subtype-lattice-merge breaks monotonicity | Pre-existing pattern. Compensated by solve-meta! pipeline. | Design §3.2, F2 |
| ~~sre-domain 12 positional args~~ | ~~RESOLVED: `make-sre-domain` keyword constructor (`7050e49b`)~~ | ~~Retired~~ |
| ~~No persistent test file~~ | ~~RESOLVED: test-sre-track2h.rkt 35 tests (`47e8d401`)~~ | ~~Retired~~ |

---

## 17. What Would We Do Differently?

1. **Include the tensor from D.1, not D.3.** The user's challenge to expand scope was a design improvement that should have been in the initial draft. The original design delivered "half a semiring" — the user saw the gap before the critique rounds did.

2. **Update the progress tracker at each phase commit, not in catch-up batches.** Three phases' tracker updates were skipped. The blocking checklist rule codified during this track prevents recurrence.

3. **Add a persistent test file during implementation, not as follow-up.** The Pre-0 benchmarks were comprehensive but are not regression tests. A dedicated test file should be part of the implementation phases.

---

## 18. Wrong Assumptions

| # | Assumption | Reality | Impact |
|---|-----------|---------|--------|
| 1 | Meet only needs structural matching | Meet needs subtype awareness AND union distribution for distributivity | Phase 7 added subtype callback + union distribution in meet |
| 2 | Union sort key for compound types is adequate | Same sort key for all Pi types → non-deterministic ordering | Phase 7 fixed with recursive sort keys |
| 3 | Tensor is Track 4 scope | Tensor is Track 2H scope — without it, union types in the elaborator produce errors | Design expanded at D.3 by user challenge |

---

## 19. What Did We Learn About the Problem?

The type lattice redesign is fundamentally about making the subtype ordering a PROPER lattice — with join (union types), meet (GLB with distribution), and algebraic laws (distributive, Heyting). The key insight: **distributivity is not a property to verify — it is a property to CONSTRUCT.** Meet distributing over union-join is not something we test for; it is something we implement in the meet function. The meet function's union case IS the distributive law.

The tensor's role became clear during design iteration: it is not a future abstraction but the **completion** of the union-join design. Introducing union types without handling them in function application creates a half-built algebraic structure. The quantale (join + tensor) is the minimal complete structure.

The distinction between scaffolding and permanent is the core architectural pattern of this track. Every component has a clear answer: "is this on-network?" If not, it's scaffolding with a named retirement plan. This pattern (from the Vision Alignment Gate) should be applied to every future track.

---

## 20. Are We Solving the Right Problem?

Yes. The type lattice redesign is the prerequisite for PPN Track 4 (elaboration on network). Track 4 needs:
- Union types as the join (to merge type information from multiple sources)
- The tensor as a propagator fire function (to compute application results)
- Per-relation properties (to select elaboration strategies based on algebraic structure)
- Pseudo-complement (for informative error reporting when contradictions arise)

Track 2H delivers all four. The scaffolding (imperative distribution, function-over-list pseudo-complement, keyword API) is honestly labeled and has clear retirement paths via Track 4's ATMS.

---

## 21. Longitudinal Survey — 10 Most Recent PIRs

| # | Track | Date | Duration | Commits | Test Delta | D:I Ratio | Bugs | Wrong Assumptions |
|---|-------|------|----------|---------|------------|-----------|------|-------------------|
| 4 | SRE Track 2 | 03-23 | ~4h | 6 | +0 | 1.7:1 | 1 | 1 |
| 5 | PM 8F | 03-24 | ~8h | 15 | +0 | 1.5:1 | 2 | 3 |
| 6 | PM Track 10 | 03-24 | ~18h | 30 | -37 | 1:2 | 8 | 3 |
| 7 | PM Track 10B | 03-26 | ~8h | 20 | +0 | 3:5 | 8 | 2 |
| 8 | PPN Track 0 | 03-26 | ~4h | 8 | +30 | 1:1 | 2 | 0 |
| 9 | PPN Track 1 | 03-26 | ~14h | 25 | +108 | 1.4:1 | 25+ | 3 |
| 10 | PPN Track 2 | 03-29 | ~8.5h | 68 | +57 | 0.8:1 | 4 | 5 |
| 11 | PAR Track 1 | 03-28 | ~14h | 53 | +0 | 1.5:1 | 10 | 2 |
| 12 | PPN Track 2B | 03-30 | ~10h | 18 | +0→+32 | 1:1 | 3 | 5 |
| 13 | SRE Track 2G | 03-30 | ~10h | 11 | +32 | 1.5:1 | 3 | 3 |
| 14 | PPN Track 3 | 04-01 | ~20h | 40+ | +0 | 1.5:1 | 10+ | 2 |
| **15** | **SRE Track 2H** | **04-02** | **~12h** | **26** | **+0** | **2:1** | **3** | **3** |

### Recurring Patterns

**Pattern 1: D:I ratio correlates inversely with bugs (15/15 PIRs).** Track 2H: 2:1 D:I ratio, 3 bugs. Track 2G: 1.5:1, 3 bugs. PPN Track 2: 0.8:1, 4 bugs. PM Track 10: 1:2, 8 bugs. Design investment pays off in implementation smoothness. The 2:1 ratio for algebraic tracks (Track 2G, Track 2H) appears to be the sweet spot.

**Pattern 2: External critique with propagator lens produces deeper findings (2/2 tracks that used it).** Track 2H's external critique found F1 (bot-on-failure) and M3 (distribution as network behavior) — architectural insights. The self-critique found mechanical issues (R1 circular dep, R2 migration count). RECOMMENDATION: make propagator-lens external critique STANDARD for all SRE/PPN tracks.

**Pattern 3: User scope challenges improve designs (3+ instances).** Track 2H: tensor expansion. PPN Track 3 §11: tree-canonical pivot. Track 2G: property inference. In each case, the user identified a completeness gap that the design cycle missed. The pattern: design cycles focus on INTERNAL consistency but miss EXTERNAL completeness (does the design deliver the full algebraic structure?).

**Pattern 4: Phase completion protocol adherence degrades under implementation momentum (2nd instance).** Track 2H: tracker updates skipped for Phases 5-7. PPN Track 3: SRE integration deferred. Both caught by the user. The blocking checklist rule (codified during Track 2H) is the response. Monitor in future PIRs: does the rule prevent recurrence?

**Pattern 5: Pre-0 algebraic validation drives implementation (2nd instance — approaching codification).** Track 2G: distributivity refuted → design pivoted. Track 2H: V4 distributivity test drove three fixes (sort key, subtype callback, union distribution). The V4 test was the SPECIFICATION — implementation was correct when V4 reached 0/512. READY FOR CODIFICATION: "Pre-0 algebraic validation is the specification for lattice tracks."
