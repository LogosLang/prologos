# SRE Track 1 + 1B: Relation-Parameterized Structural Decomposition — PIR

**Date**: 2026-03-23 through 2026-03-24
**Duration**: ~8h implementation across 2 sessions (Track 1: ~5h, Track 1B: ~3h)
**Commits**: 21 (Track 1: 12, Track 1B: 9). From `6c24277` through `5c5fc89`.
**Test delta**: 7358 → 7401 (+43 new tests across 3 test files)
**Code delta**: ~900 lines added across 9 files
**Suite health**: 7401 tests, 382 files, 244.8s, all pass
**Design docs**: [Track 1 Design](2026-03-23_SRE_TRACK1_RELATION_PARAMETERIZED_DECOMPOSITION_DESIGN.md) (4 critique rounds: D.1→D.4), [Track 1B Design](2026-03-23_SRE_TRACK1B_POST_IMPLEMENTATION_FIXES_DESIGN.md)
**Prior art**: [SRE Track 0 PIR](2026-03-22_SRE_TRACK0_PIR.md), [PM Track 8 PIR](2026-03-22_TRACK8_PIR.md), [SRE Research](../research/2026-03-22_STRUCTURAL_REASONING_ENGINE.md), [NTT Syntax Design](2026-03-22_NTT_SYNTAX_DESIGN.md)

---

## 1. What Was Built

A relation-parameterized Structural Reasoning Engine that handles three structural
relations — equality (symmetric merge), subtyping (directional check with
variance-driven decomposition), and duality (constructor pairing with involution)
— through a single unified mechanism.

The SRE now accepts a `#:relation` parameter on `sre-make-structural-relate-propagator`.
Each relation carries its own merge function (via a merge-per-relation registry on
`sre-domain`), sub-relation derivation function (how to relate sub-components),
and binder-opening declaration (whether the relation operates on ground types or
needs fresh metas). Session duality is fully on-network via SRE propagators,
replacing the old imperative `(dual v)` function.

Track 1B followed immediately with 5 post-implementation fixes: merge-per-relation
registry (generalizable to any number of lattice orderings), correct-by-construction
decomposition guard, dependent session duality (DSend/DRecv), edge case tests, and
a 110× performance improvement on the structural failure path via direct recursive
ground-type checking.

## 2. Timeline and Phases

### Track 1 (relation infrastructure + integration)

| Phase | Commit | Description |
|-------|--------|-------------|
| 1a | `6c24277` | sre-relation struct, 5 built-in relations, variance on ctor-desc, dual-pairs on sre-domain |
| 1b | `45a816d` | Polarity inference utilities (variance-join, variance-flip) |
| 2 | `200bec6` | Subtype-aware structural-relate propagator, relation-aware decomp cache key |
| 2b | `260903f` | **Principles fixes**: flat-subtype? → subtype-lattice-merge (on-network), subtype? extraction, duality error |
| 3 | `20a3e84` | Duality propagator, session constructors in ctor-registry, dual-pair decomposition |
| 3-fix | `48634d8` | ctor-registry test count 21 → 26 |
| 4 | `9045059` | subtype? delegates compound types to SRE (query pattern) |
| 4-fix | `7c8ef21` | Reflexive subtype semantics (standard preorder) |
| 5 | `58dd714` | Session duality via SRE (drop-in replacement, 21 tests pass unchanged) |
| 6 | `dc796fb` | **Critical fix**: binder-depth bypass for non-equality relations (7 eliminator tests) |
| PIR | `b5f4ac0` | Track 1 PIR + progress tracker |

### Track 1B (post-implementation fixes)

| Phase | Commit | Description |
|-------|--------|-------------|
| 1 | `312ca3a` | Microbenchmark: 0 compound checks in suite. Success 8μs, failure 333μs. |
| 2a | `d276922` | Merge-per-relation registry: sre-domain 10 → 9 fields. case dispatch. |
| 2c | `3e00244` | compound-type? guard: flat NOT path 2.0μs → 0.47μs (4.3×) |
| 2d | `a1b347d` | **Direct recursive check**: 8μs → 2.6μs success, 333μs → 3μs failure (110×) |
| 3 | `faeb915` | requires-binder-opening? on sre-relation (replaces name-check) |
| 4 | `87ab254` | DSend/DRecv registered, dependent duality works on ground types |
| 5 | `19fa95d` | 7 edge case tests + mu fix (bot sub-components for non-equality decomp) |

**Design-to-implementation ratio**: ~2:1. 4 critique rounds for Track 1 design,
1 mini-design for Track 1B. Consistent with Track 0's ratio (2:1, zero bugs in
core logic). The bugs in Track 1 were all at domain boundaries (lattice ordering
mismatch, circular dependencies, binder semantics) — NOT in the core SRE logic.
This confirms the SRE Track 0 PIR finding: "design investment pays off in the core,
but boundary interactions surprise regardless."

## 3. Test Coverage

| File | Tests | Categories |
|------|-------|------------|
| `test-sre-subtype.rkt` | 22 | Variance verification (5), relation basics (5), sub-relation derivation (3), polarity utilities (4), flat preservation (3), structural checks (6) |
| `test-sre-duality.rkt` | 19 | Basic propagation (4), self-dual (1), nested (1), sub-relation (2), dependent (3), edge cases (7) |
| `test-ctor-registry.rkt` | +1 updated | Total ctor-desc count 21 → 28 |
| `test-subtyping.rkt` | +1 updated | Reflexive subtype semantics |
| `test-eliminator-typing.rkt` | 7 fixed | Binder-depth bypass restored negative test correctness |

**Gap**: No tests for user-defined type structural subtyping (polarity inference not
yet integrated into data elaboration). No tests for partially-known session duality
(metas in session types). Both are Track 2 scope.

## 4. Bugs Found and Fixed

| # | Bug | Root Cause | Why it seemed right | Fix |
|---|-----|-----------|-------------------|-----|
| 1 | type-lattice merge ≠ subtype ordering | Type lattice is flat (Nat ≠ Int → top). `merge(a,b) = b` doesn't encode subtyping. | Lattice merge encodes ordering — true for equality lattices, false when two orderings exist on one carrier. | `subtype-lattice-merge` with proper subtype ordering. |
| 2 | Circular dep: unify → typing-core | `subtype?` was in typing-core; unify needs it for SRE domain. | Seemed like a small extraction. The transitive chain (typing-core → unify) was non-obvious. | Extracted `subtype-predicate.rkt`. |
| 3 | Duality pre-write cross-domain bot | Writing `Recv(sess-bot, sess-bot)` puts session-domain bot in type-lattice position. | Skeleton approach worked for equality (one domain); failed for cross-domain components. | Don't pre-write. Let sub-cell propagators build values. |
| 4 | Binder-depth blocked Pi decomposition | Pi has binder-depth=1. `sre-maybe-decompose` fell through. | Binder-depth was a universal gate; should be relation-specific. | `requires-binder-opening?` on sre-relation. |
| 5 | mu duality: unified fallback copies un-dualized body | `sre-decompose-generic` uses `unified` for b-side when b-side is bot. | Equality decomposition safely copies unified (both sides converge). Duality copies the wrong value. | Non-equality relations use bot sub-components when b-side doesn't match. |
| 6 | `flat-subtype?` off-network | Predicate check inside propagator violates Propagator-First. | Quick fix to get tests passing. User caught it during implementation review. | `subtype-lattice-merge` keeps subtyping on-network. |
| 7 | Reflexive subtype semantics | `subtype?(Int, Int)` returned `#f` (strict). New `equal?` fast path makes it `#t`. | Old `subtype?` was only called after equality check failed — reflexive case never occurred. | Updated test to standard preorder semantics. |

**Pattern**: Bugs 1, 3, 5 are all the same class: "equality-relation assumptions break for non-equality relations." Equality is symmetric (both sides converge to same value), uses one lattice ordering, and can safely copy unified values. Subtyping is directional (different ordering). Duality is asymmetric (different constructors on each side, wrong-side copies produce wrong values). **Three instances confirm the pattern: every equality-specific assumption must be audited when adding a new relation.**

## 5. Design Decisions and Rationale

| # | Decision | Rationale | Principle |
|---|----------|-----------|-----------|
| 1 | Merge-per-relation registry (not fixed fields) | Two orderings exist now; more may emerge. Registry generalizes without struct changes. | Most General Interface |
| 2 | Derive duality sub-relations from component lattice types | Removes `component-sub-relations` field. ctor-desc stays lean (10 fields). | Decomplection |
| 3 | Direct recursive check for ground types (not mini-network) | Ground-type subtyping is a pure function. Propagation adds no information. 110× failure speedup. | Propagator-First (propagators for incremental flow, not total functions) |
| 4 | `requires-binder-opening?` on sre-relation (not name-check) | New relations declare binder requirements at construction time. Correct-by-construction. | Correct-by-Construction |
| 5 | `subtype?` extraction to `subtype-predicate.rkt` | Breaks circular dep. Clean module boundary. Both unify and typing-core import without cycles. | Decomplection |
| 6 | Session duality via SRE (replacing imperative `dual`) | On-network structural decomposition. Sub-cell relations derived from component lattice types. | Propagator-First |

## 6. What Went Well

1. **Design-to-implementation ratio continues to predict smoothness.** 4 critique rounds → zero core logic bugs. All 7 bugs were at domain boundaries (lattice/circular-dep/binder), not in the SRE's structural reasoning. This is the 3rd consecutive data point (Track 8: 0.5:1 ratio, ghost-meta bugs; Track 0: 2:1, zero bugs; Track 1: 2:1, boundary bugs only). **Ready for codification in DESIGN_METHODOLOGY.org.**

2. **Principles-First Design Gate caught violations during implementation.** The user identified `flat-subtype?` as off-network (Phase 2) and the 4 open question deferrals as Completeness violations (D.2). Both caught before they compounded. The Track 8 D.4 lesson ("the gate works") continues to hold.

3. **Second-domain validation.** Session duality (21 tests, drop-in replacement) validates the relation-parameterized SRE abstraction. Same pattern as Track 0 (term-value domain, zero sre-core changes). **2nd consecutive instance of "second domain validates abstraction."**

4. **Benchmarking before changing (Track 1B).** Reordering Phase 5 to Phase 1 revealed: early-exit quiescence already implemented, real bottleneck was cold-start allocation (not computation), and the flat NOT path had unnecessary overhead. This shifted the optimization from "smarter quiescence" to "eliminate the network for ground types" — a fundamentally better solution.

## 7. What Went Wrong

See §4 (Bugs Found and Fixed) for the complete list. The overarching theme: **equality-specific assumptions pervade the SRE's decomposition code.** Three bugs (lattice ordering, pre-write copies, unified fallback) all stem from the assumption that both sides converge to the same value — true for equality, false for subtyping and duality.

## 8. Where Did We Get Lucky

1. **The binder-depth fix (Phase 6) was caught by existing tests.** 7 eliminator typing tests failed — they expected type errors for wrong-codomain functions. If these tests didn't exist, the binder-depth bug would have silently allowed unsound subtyping (Pi(Nat, Bool) <: Pi(Nat, Nat) would pass). The test suite was the safety net. We did NOT get lucky — we had good tests. But we ALMOST got unlucky: we initially dismissed the failures as "pre-existing." The user's insistence on investigating caught it.

2. **Session duality being a drop-in replacement.** This could have required test changes (different propagation order, different intermediate values). It didn't — the SRE's structural decomposition produces identical final values. But we should add tests for incremental session type arrival (Track 2 scope) to avoid relying on this coincidence.

## 9. What Surprised Us

1. **Two lattice orderings on the same carrier.** We expected one lattice per domain. The type domain needs TWO: flat (for equality) and partially-ordered (for subtyping). This is a mathematical insight — the carrier set is the same, but the orderings are different algebraic structures. The merge-per-relation registry is the architectural response.

2. **The structural failure path was 110× more expensive than success.** We expected maybe 2-3× (contradiction detection adds some overhead). The actual 333μs was dominated by cold-start allocation (mini-network creation), not computation (only 4 propagator firings). The fix (direct recursive check) eliminated the network entirely for ground types.

3. **Duality decomposition is fundamentally asymmetric.** We expected to reuse `sre-decompose-generic` for duality. It doesn't work — equality decomposition uses ONE descriptor (same tag both sides), duality uses TWO (different tags). This required `sre-duality-decompose-dual-pair` — a dedicated function.

## 10. Architecture Assessment

**sre-domain**: 9 fields (down from 10 after merge-registry consolidation).
`merge-registry` replaces `lattice-merge` + `subtype-merge`. Generalizable
to any number of orderings without struct changes.

**sre-relation**: 3 fields (name, sub-relation-fn, requires-binder-opening?).
Correct-by-construction: new relations must declare all properties at
struct construction time.

**ctor-desc**: 10 fields. At the D.2 threshold. Two fields added (component-variances,
binder-open-fn). If Track 2 adds more, factor into core + capabilities.

**sre-core.rkt**: ~600 lines (up from ~325 after Track 0, ~550 after Track 1,
~600 after Track 1B). The duality propagator + helpers are the largest addition.
Still manageable but approaching the point where relation-specific code should
be split into separate modules.

**NTT-Racket isomorphism**: CONFIRMED across Track 1 + 1B. Every Racket construct
has a direct NTT correspondence. Promote from "watching" to "confirmed pattern."

## 11. What Does This Enable

1. **SRE Track 2 (Elaborator-on-SRE)**: The elaborator can now express subtyping
   and duality constraints via `structural-relate` with the appropriate relation.
   Track 1 provides the infrastructure; Track 2 uses it.

2. **Structural subtyping for user-defined types**: Polarity inference utilities
   exist. Integration into `data` elaboration (filling `component-variances`
   automatically) is Track 2 scope.

3. **CIU Track 3**: Trait-dispatched access can use structural subtyping for
   impl selection (e.g., `impl Indexed PVec` matching `PVec Nat` when `PVec Int`
   is expected).

## 12. What Would We Do Differently

1. **Start with benchmarking.** Track 1B reordered phases to benchmark first.
   This should have been Track 1's approach — measuring the query pattern overhead
   before building it would have led us to the direct recursive check sooner.

2. **Audit equality-specific assumptions before implementing non-equality relations.**
   Three of seven bugs came from equality assumptions in `sre-decompose-generic`.
   A systematic audit ("what does this function assume about the relation?") before
   Phase 2 would have caught them at design time.

3. **Don't dismiss failing tests.** The 7 eliminator test failures were initially
   assessed as "pre-existing." They weren't — they were caused by our binder-depth
   change. Every test failure after our changes is our responsibility until proven
   otherwise.

## 13. What Assumptions Were Wrong

1. **"One lattice ordering per domain."** Wrong — the type domain needs two orderings
   (flat for equality, partial for subtyping). The fix (merge-per-relation) generalizes
   to any number.

2. **"`sre-decompose-generic` is generic enough for all relations."** Wrong — it
   assumes symmetric decomposition (same tag both sides). Duality is asymmetric.

3. **"Binder-depth is a universal decomposition gate."** Wrong — it's relation-specific.
   Equality needs binder opening (fresh metas). Subtyping/duality on ground types don't.

4. **"The mini-network query pattern is fast enough."** Wrong for the failure path
   (333μs). Direct recursive check is 110× faster.

## 14. What Did We Learn About the Problem

Structural relation checking is not a single operation parameterized by a flag —
it's a family of operations with different algebraic properties:
- **Equality**: symmetric, merging, bidirectional, needs binder opening
- **Subtyping**: directional, checking (not merging), needs variance
- **Duality**: symmetric-ish (involution), constructor-swapping, needs dual-pair mapping

Each property affects decomposition mechanics, not just sub-cell semantics.
The SRE's generic code needed three separate adaptations: dual-pair decomposition,
bot-sub-component initialization for non-equality, and relation-aware merge selection.
Future relations should be analyzed along these four axes: symmetry, merge semantics,
constructor mapping, and binder requirements.

## 15. Is This Part of a Pattern?

**Cross-referencing with prior PIRs**:

| Pattern | Instances | Status |
|---------|-----------|--------|
| "Design critique changes designs" | Track 7 D.2, Track 8 D.4, SRE Track 0 D.2, **Track 1 D.2 (Completeness revision)** | 4th instance. **Ready for codification.** |
| "Second domain validates abstraction" | SRE Track 0 (term-value), **Track 1 (session duality)** | 2nd instance. Emerging. |
| "Design:implementation ratio predicts smoothness" | Track 8 (0.5:1, bugs), Track 0 (2:1, clean), **Track 1 (2:1, boundary bugs)** | 3rd instance. **Ready for codification.** |
| "Don't pre-populate from wrong side" | Dual-pair pre-write, skeleton, **unified fallback** | 3rd instance. **Ready for codification.** |
| "Equality assumptions break for non-equality" | Lattice ordering, pre-write, **unified fallback** | 3rd instance. NEW PATTERN. |
| "Benchmark before changing" | BSP-LE Track 0 Phase 5 (transient CHAMP), **Track 1B Phase 1 reorder** | 2nd instance. Emerging. |

## 16. Lessons Distilled

| Lesson | Target Document | Status |
|--------|----------------|--------|
| "Correct lattice for the correct relation" | DEVELOPMENT_LESSONS.org | Pending |
| "Don't pre-populate sub-cells from wrong side for non-equality" (3 instances) | PATTERNS_AND_CONVENTIONS.org | Pending |
| "Equality-specific assumptions break for non-equality relations" (3 instances) | DEVELOPMENT_LESSONS.org | Pending |
| "Benchmark before changing" (2 instances) | DESIGN_METHODOLOGY.org | Pending — needs 3rd instance |
| "Design:implementation ratio predicts smoothness" (3 instances) | DESIGN_METHODOLOGY.org | Pending |
| "Design critique changes designs" (4 instances) | DESIGN_METHODOLOGY.org | Pending |
| "Principles Gate works during implementation" | Already in workflow.md | Done (`c7cda29`) |
| "Symbol sentinels for cross-module lattice identity" | PATTERNS_AND_CONVENTIONS.org | Pending |
| NTT-Racket isomorphism confirmed | MEMORY.md Watching → Confirmed | Pending |

## 17. Key Files

| File | Role | Lines changed |
|------|------|---------------|
| `sre-core.rkt` | Relation structs, propagators, merge lookup, decomp guard | +250 |
| `ctor-registry.rkt` | Variance, session constructors, binder-open-fn | +120 |
| `subtype-predicate.rkt` | Extracted predicate, subtype-merge, direct recursive check | +130 (new) |
| `session-propagators.rkt` | SRE duality delegation, merge registry | +35, -24 |
| `propagator.rkt` | Relation-aware decomp key | +15 |
| `unify.rkt` | Domain spec + merge registry | +10 |
| `typing-core.rkt` | subtype? extraction | -30 |
| `tests/test-sre-subtype.rkt` | 22 structural subtype tests | +175 (new) |
| `tests/test-sre-duality.rkt` | 19 duality tests (basic + edge cases) | +200 (new) |
| `benchmarks/micro/bench-subtype.rkt` | Performance measurement | +80 (new) |

## 18. Metrics

| Metric | Track 1 Start | Track 1 End | Track 1B End |
|--------|--------------|-------------|-------------|
| Tests | 7358 | 7392 (+34) | 7401 (+43) |
| Suite time | 236.7s | 243.9s (+3.0%) | 244.8s (+3.4%) |
| ctor-descs | 21 | 26 | 28 |
| sre-domain fields | 8 | 10 | 9 |
| sre-relation fields | — | 2 | 3 |
| Structural subtype success | — | 8.3μs | 2.6μs |
| Structural subtype failure | — | 333μs | 3.0μs |
| Flat NOT overhead | — | 2.0μs | 0.4μs |
