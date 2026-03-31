# SRE Track 2G: Algebraic Domain Awareness — Post-Implementation Review

**Date**: 2026-03-30
**Duration**: ~4 hours implementation across 1 session (design cycle ~6 hours prior)
**Commits**: 10 implementation commits (from `baa0fde6` Phase 1 through `990bbca8` Phase 7b)
**Test delta**: 7459 → 7459 (zero new test files; infrastructure validated via inline tests)
**Code delta**: ~350 lines added to sre-core.rkt, ~90 lines across type-lattice.rkt + session-lattice.rkt + unify.rkt + session-propagators.rkt
**Suite health**: 382/382 files, 7459 tests, all pass, ~130s
**Design iterations**: D.1, D.2 (3 revisions: P1 cells, P2 ring-action, M3 Pocket Universe), D.3 (11 findings), NTT model (revealed scatter impurity), Phase 5 finding (type lattice not distributive)
**Design docs**: [SRE Track 2G Design](2026-03-30_SRE_TRACK2G_DESIGN.md), [Stage 2 Audit](2026-03-30_SRE_TRACK2G_STAGE2_AUDIT.md)
**Prior PIRs**: [PPN Track 2B](2026-03-30_PPN_TRACK2B_PIR.md), [PPN Track 2](2026-03-29_PPN_TRACK2_PIR.md)
**Series**: SRE (Structural Reasoning Engine) — Track 2G

---

## 1. What Was Built

SRE Track 2G adds algebraic domain awareness to the Structural Reasoning Engine. Every SRE domain can declare (or have inferred) a set of algebraic properties — commutativity, associativity, idempotence, distributivity, etc. — that describe the domain's lattice structure. These properties are stored as cells on the network (scaffolding: currently struct field hashes, with clear path to network cells). Implication rules derive composite properties (Heyting = distributive ∧ has-pseudo-complement). Downstream code uses property-gated behavior to select algorithms based on domain properties.

The track also delivers: meet operations for type and session domains (lattice greatest lower bound, variance-aware via ring action), a central domain registry, and a property inference engine that validates declarations by testing algebraic axioms against sample values with counterexample witnesses.

**Critical discovery during implementation**: The type lattice under equality merge is NOT distributive (flat lattice with many incomparable atoms). This means the type domain is NOT Heyting — the originally-planned Heyting pseudo-complement error reporting consumer is not applicable. A type lattice redesign (union types as join, subtype-aware meet) is needed for Heyting compliance — identified as its own track.

---

## 2. Timeline and Phases

| Phase | Commit | What | Duration |
|-------|--------|------|----------|
| 0 | — | Pre-0 benchmarks: merge ~159μs, property test ~200ms one-time | 15m |
| 1 | `baa0fde6` | Property cell infrastructure: 4-valued lattice, property-cell-ids + declared-properties fields, has-property? API. 9 construction sites updated. | 30m |
| 1.5 | `191d0933` | Domain registry: register-domain!, lookup-domain, all-registered-domains. Both production domains registered. | 20m |
| 2 | `9737625d` | Type lattice meet: type-lattice-meet with ring action. Pi variance: contra→join, co→meet, inv→eq-meet. Meta→⊥. | 40m |
| 3 | `01d115c1` | Session lattice meet: session-lattice-meet. Ground sessions only. | 15m |
| 4 | `85d9a262` | Property declarations: type domain 4 properties, session domain 4 properties. All 9 sites updated. | 25m |
| 5 | `caacdff4` | Property inference: 4 axiom test functions, evidence structs (confirmed/refuted with witness). **FINDING**: type lattice NOT distributive. | 35m |
| 6 | `d6647b87` | Implication rules: standard rules (heyting, boolean). resolve-domain-properties pipeline. | 20m |
| 7a+7b | `990bbca8` | Diagnostic property reporting + property-gated behavior infrastructure. | 25m |

Design-to-implementation ratio: ~6h design : ~4h implementation ≈ 1.5:1.

---

## 3. Test Coverage

No new test files. Infrastructure validated via:
- Inline REPL tests at each phase (type-lattice-meet correctness, property declaration reads, inference results, implication derivation, diagnostic output, property-gated behavior)
- Full suite GREEN at every phase (7459 tests, 382 files)
- Pre-0 benchmarks establishing baseline

**Gap**: No dedicated test file for sre-core.rkt Phase 2G additions. The inference engine, implication rules, and property-gated behavior are tested via REPL but not in the persistent test suite. This should be addressed in a follow-up.

---

## 4. Bugs Found and Fixed

**Bug 1: Type lattice declared distributive when it's not.** The initial design (and Phase 4 declaration) asserted `distributive = prop-confirmed` for the type domain. Phase 5 inference found the counterexample: `Int ⊔ (Nat ⊓ String) = Int` but `(Int ⊔ Nat) ⊓ (Int ⊔ String) = ⊤`. Root cause: the type lattice under equality merge is FLAT — Int and Nat are incomparable atoms, so `Int ⊔ Nat = ⊤`. Flat lattices with >2 atoms are not distributive. Fixed: removed distributive and has-pseudo-complement declarations. The property lattice's 4-valued system (⊤ = contradicted) worked exactly as designed.

**Bug 2: `binder-info` constructor not imported in type-lattice-meet.** Initial implementation of `try-intersect-pure` tried to construct `binder-info` structs for Pi meet results. The constructor wasn't imported and type-lattice.rkt doesn't use it elsewhere. Fixed: use `struct-copy expr-Pi` instead, which preserves the original binder structure while replacing domain/codomain.

---

## 5. Design Decisions and Rationale

| Decision | Rationale | Principle |
|----------|-----------|-----------|
| Properties as flat set (not class hierarchy) | Avoids multiple inheritance. Composites via implication propagators. Same as `bundle` approach for traits. | Decomplection |
| Ring action function (not per-operation table columns) | Uniform across all operations: monotone preserves, antitone flips. Adding new operations requires zero table changes. | Data Orientation (ordering in data, not code) |
| 4-valued property lattice (⊥, #t, #f, ⊤) | ⊤ = declaration/inference disagree. Preserves diagnostic info. Implication treats ⊤ as #f for gating. | Correct-by-Construction |
| Meta meet = ⊥ (conservative) | Can't compute GLB of unknown. Property inference uses ground types. Pseudo-complement fires on resolved metas. | Completeness (honest about what we don't know) |
| Eager inference at registration | has-property? is a pure read. 200ms one-time cost with pnet caching. | Decomplection (no query-with-side-effect) |
| Phase 7 revised: reporting + property-gating instead of Heyting | Type lattice not Heyting under equality merge. Infrastructure is the deliverable. Heyting activates automatically when type lattice redesign makes it available. | Completeness (don't pretend to deliver what the math doesn't support) |

---

## 6. Lessons Learned

**L1: Property inference caught an incorrect design assumption.** The design declared the type domain distributive. The inference mechanism (built to VERIFY declarations) found the counterexample. This validates the declaration + inference dual-path design: declarations are the fast path, inference is the safety net. Without inference, we would have shipped an incorrect Heyting declaration.

**L2: The NTT model caught an architectural impurity.** Phase 6's implication "installation" was described as a static wiring step — enumerate domains, loop, install. The NTT model (expressing it as propagators with `:reads`/`:writes`) revealed this was imperative, not reactive. Revised to: scatter propagator reads registry, computes diff, creates topology. This is the Propagator Design Mindspace in action — the speculative syntax forced honest on-network modeling.

**L3: Algebraic properties are per-ordering, not per-carrier.** The same carrier set (types) has different algebraic structure under equality (flat, not distributive) vs subtyping (structured, potentially distributive). This means a type lattice redesign is needed to make the type domain Heyting — which is a significant but well-scoped future track.

**L4: 11-field positional structs are unwieldy.** `sre-domain` now has 11 positional arguments. Adding fields requires updating 9 construction sites each time. Keyword arguments would be cleaner. This is a small ergonomics improvement that should be made alongside the next Track 2G-adjacent change.

---

## 7. Metrics

| Metric | Value |
|--------|-------|
| Wall clock (implementation) | ~4 hours |
| Design cycle | ~6 hours (D.1 through D.3 + NTT + Phase 5 finding revision) |
| D:I ratio | ~1.5:1 |
| Implementation commits | 10 |
| Lines added (sre-core.rkt) | ~350 |
| Lines added (other files) | ~90 |
| Construction sites updated | 9 (× 2 field additions = 18 edits) |
| Production domains | 2 (type, session) |
| Algebraic properties implemented | 10 atomic + 2 composite |
| Axiom test functions | 4 (commutativity, associativity, idempotence, distributivity) |
| Pre-0 merge cost | ~159 μs/op |
| Pre-0 property test cost | ~200ms one-time |
| Suite health | 382/382, 7459 tests, ~130s |

---

## 8. What's Next

### Immediate
- **Dedicated test file** for Track 2G additions (inference, implications, property-gated behavior)
- **Type lattice redesign track** — union types as join, subtype-aware meet. This makes the type domain Heyting-compliant. Scoped as its own track with background research.

### Medium-term (PPN Track 3 consumer)
- PPN Track 3 registers parse lattice domains → algebraic profiles reported automatically
- Property-gated behavior selects parse strategies based on domain properties (Boolean token lattice → complement operations, etc.)

### Long-term
- **UCS integration**: `#=` operator selects solving strategy based on domain algebraic properties
- **Heyting error reporting**: activates automatically when type lattice redesign makes type domain Heyting (zero code changes — property cell advances, property-gated behavior fires)
- **Residuation**: automatic backward propagator derivation for residuated domains
- **Per-relation properties**: algebraic properties per (domain, relation) pair rather than per-domain only

---

## 9. Key Files

| File | Role | Lines Changed |
|------|------|--------------|
| `racket/prologos/sre-core.rkt` | Property infrastructure, registry, inference, implications, reporting, gating | +350 |
| `racket/prologos/type-lattice.rkt` | type-lattice-meet (greatest lower bound) | +84 |
| `racket/prologos/session-lattice.rkt` | session-lattice-meet | +20 |
| `racket/prologos/unify.rkt` | Type domain declarations + registration | +15 |
| `racket/prologos/session-propagators.rkt` | Session domain declarations + registration | +10 |
| `docs/tracking/2026-03-30_SRE_TRACK2G_DESIGN.md` | Design document (D.1 through D.3 + NTT + revisions) | ~600 lines |

---

## 10. Lessons Distilled

| Lesson | Candidate For | Status |
|--------|---------------|--------|
| L1: Inference validates declarations (catches incorrect assumptions) | DEVELOPMENT_LESSONS.org | Pending — "declaration + inference dual path" pattern |
| L2: NTT modeling catches architectural impurities | Already noted in DESIGN_METHODOLOGY.org §NTT Speculative Syntax | Reinforced |
| L3: Algebraic properties are per-ordering | Research note candidate | Pending — type lattice redesign track will elaborate |
| L4: Keyword args for >8-field structs | PATTERNS_AND_CONVENTIONS.org | Pending — small ergonomics improvement |
| Propagator Design Mindspace codified | DESIGN_METHODOLOGY.org | Done (Track 2B contribution, used throughout 2G) |

---

## 11. Open Questions

- **Is the type lattice's equality merge the RIGHT primary ordering?** The subtype ordering is richer and more type-theoretically natural. The equality merge may be an implementation artifact from early type inference work. The type lattice redesign track should examine this.
- **Should property inference run automatically at domain registration?** Currently it must be called explicitly. The design says "eager at registration" but the implementation doesn't wire it into `register-domain!`. Phase 6's Pocket Universe design (wiring-state cell + scatter) would automate this.
- **Can algebraic property inference be extended to user-defined lattices?** The infrastructure is domain-agnostic. A user defining a new lattice domain (via future NTT `lattice` declaration) could get automatic property inference by providing sample values.
