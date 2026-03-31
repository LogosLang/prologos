# SRE Track 2G: Algebraic Domain Awareness — Post-Implementation Review

**Date**: 2026-03-30
**Duration**: ~4 hours implementation, ~6 hours design cycle. 1 session.
**Commits**: 11 (from `baa0fde6` Phase 1 through `dbe3e31f` test file)
**Test delta**: 7459 → 7491 (+32 new tests in test-sre-algebraic.rkt)
**Code delta**: ~440 lines added to sre-core.rkt, ~105 lines across type-lattice.rkt + session-lattice.rkt + unify.rkt + session-propagators.rkt. 241 lines test file.
**Suite health**: 383/383 files, 7491 tests, all pass, ~130s
**Design iterations**: D.1, D.2 (3 revisions: P1 cells, P2 ring-action, M3 Pocket Universe), D.3 (11 findings), NTT model (revealed scatter impurity), Phase 5 finding
**Design docs**: [SRE Track 2G Design](2026-03-30_SRE_TRACK2G_DESIGN.md), [Stage 2 Audit](2026-03-30_SRE_TRACK2G_STAGE2_AUDIT.md)
**Prior PIRs**: [PPN Track 2B](2026-03-30_PPN_TRACK2B_PIR.md), [PPN Track 2](2026-03-29_PPN_TRACK2_PIR.md), [PAR Track 1](2026-03-28_PAR_TRACK1_PIR.md), [PPN Track 1](2026-03-26_PPN_TRACK1_PIR.md)
**Series**: SRE (Structural Reasoning Engine) — Track 2G

---

## 1. What Were the Stated Objectives?

**Original (D.1)**: Every SRE domain declares or has inferred a set of algebraic properties. Property cells on the network. Meet operations. Ring action generalization. Implication propagators. Heyting pseudo-complement error reporting as first consumer.

**Final (after Phase 5 finding)**: Same infrastructure, but Heyting consumer replaced by diagnostic property reporting + property-gated behavior infrastructure. The type lattice is NOT Heyting under equality merge — discovered during implementation, not design.

**Scope evolution**: Heyting error reporting → diagnostic reporting + property-gated behavior. Domain registry added (D.3 F10). Phase 7 split into 7a + 7b. The scope SHRANK in ambition (no Heyting) but GREW in infrastructure (registry, diagnostics, gating pattern).

---

## 2. What Was Actually Delivered?

| Deliverable | Status | Evidence |
|-------------|--------|---------|
| Property cell infrastructure (4-valued lattice) | ✅ | sre-core.rkt: property-value-join, prop-unknown/confirmed/refuted/contradicted |
| Central domain registry | ✅ | sre-core.rkt: register-domain!, lookup-domain, all-registered-domains. 2 domains registered. |
| Meet for type domain (ring action) | ✅ | type-lattice.rkt: type-lattice-meet, try-intersect-pure. Pi variance: contra→join, co→meet. |
| Meet for session domain | ✅ | session-lattice.rkt: session-lattice-meet. Ground sessions. |
| Ring action function | ✅ | Design only (not separate code — ring action encoded in type-lattice-meet's variance handling). |
| Property declarations | ✅ | declared-properties field (11th on sre-domain). Type: 4 properties. Session: 4 properties. |
| Property inference with witnesses | ✅ | 4 axiom test functions. axiom-confirmed(count), axiom-refuted(witness). |
| Implication rules | ✅ | implication-rule struct. 2 standard rules (heyting, boolean). derive-composite-properties. |
| Diagnostic property reporting | ✅ | format-property-profile, resolve-and-report-properties. Evidence details. |
| Property-gated behavior | ✅ | with-domain-property, select-by-property. Graceful fallback. |
| Heyting pseudo-complement | ❌ DEFERRED | Type lattice not Heyting. Deferred to type lattice redesign track. |
| Dedicated test file | ✅ | test-sre-algebraic.rkt: 32 tests across 9 categories. |

Scope adherence: 10/11 deliverables (91%). The one deferral was justified by a mathematical discovery during implementation.

---

## 3. Timeline

| Phase | Commit | Duration | Key Event |
|-------|--------|----------|-----------|
| 0 | — | 15m | Pre-0 benchmarks: merge ~159μs, property test ~200ms one-time |
| 1 | `baa0fde6` | 30m | 4-valued property lattice, property-cell-ids + declared-properties fields, 9 sites |
| 1.5 | `191d0933` | 20m | Domain registry: register-domain!, 2 domains registered |
| 2 | `9737625d` | 40m | type-lattice-meet: ring action variance, Pi/Sigma/base types |
| 3 | `01d115c1` | 15m | session-lattice-meet: ground sessions |
| 4 | `85d9a262` | 25m | Property declarations: type 4 props, session 4 props, 9 sites |
| 5 | `caacdff4` | 35m | Inference + **FINDING**: type lattice NOT distributive |
| 6 | `d6647b87` | 20m | Implication rules + full resolution pipeline |
| 7a+7b | `990bbca8` | 25m | Diagnostic reporting + property-gated behavior |
| 8 | `60e2f334` | 15m | PIR + docs |
| Tests | `dbe3e31f` | 20m | test-sre-algebraic.rkt: 32 tests |

D:I ratio: ~6h design : ~4h implementation ≈ 1.5:1

---

## 4. Bugs Found and Fixed

**Bug 1: Type domain declared distributive when it's not.** Phase 4 declared `distributive = prop-confirmed`. Phase 5 inference found the counterexample: `Int ⊔ (Nat ⊓ String) = Int ⊔ ⊥ = Int` but `(Int ⊔ Nat) ⊓ (Int ⊔ String) = ⊤ ⊓ ⊤ = ⊤`. Root cause: the type lattice under equality merge is FLAT — Int and Nat are incomparable atoms, so `Int ⊔ Nat = ⊤`. Flat lattices with >2 atoms are not distributive. WHY the wrong path seemed right: the intuition "types form a rich lattice with subtyping" conflated the subtype ordering with the equality ordering. Fixed: removed distributive and has-pseudo-complement declarations.

**Bug 2: `binder-info` constructor not imported.** Initial `try-intersect-pure` tried to construct `binder-info` structs. type-lattice.rkt doesn't import this constructor. WHY the wrong path seemed right: mirroring try-unify-pure's structure, but that function uses different reconstruction patterns. Fixed: `struct-copy expr-Pi` preserves original binder while replacing domain/codomain.

**Bug 3: `string-join` not imported in sre-core.rkt.** The diagnostic reporting function uses `string-join` from `racket/string`, which wasn't in sre-core.rkt's requires. Trivial fix.

---

## 5. What Went Well?

1. **The Implementation Protocol produced clean execution.** Every phase: mini-audit → implement → commit → update tracker → update dailies. No phase required a revert. No thrashing. The mini-audits prevented wrong assumptions (count construction sites BEFORE changing struct, read merge function BEFORE writing meet).

2. **Inference caught the incorrect declaration.** The design declared the type domain distributive. The inference mechanism (built to validate declarations) found the counterexample. The 4-valued property lattice (⊤ = contradicted) handled this correctly. This validates the dual-path design: declarations are the fast path, inference is the safety net.

3. **The design cycle (D.1→D.3 + NTT) front-loaded decisions.** Three critique rounds + NTT modeling resolved 14 issues before implementation. The NTT model caught the scatter impurity in Phase 6. The external critique caught the 4-valued lattice need (F1), counterexample witness (F2), context-dependent equality (F6), and meta-meet handling (F4). All of these would have been mid-implementation pivots without the design cycle.

4. **Ring action generalization was clean.** The Module Theory insight (variance IS ring action) produced a clean implementation: contravariant meet uses join (antitone flips), invariant requires equality (identity preserves). Adding future operations requires zero table changes.

---

## 6. What Went Wrong?

1. **Incorrect distributivity assumption.** The design DECLARED the type domain distributive without verifying. The inference caught it, but the declaration was in the design document (§3.1, Phase 4 section) and survived three critique rounds. None of the critiques questioned the assumption. The distributivity declaration was made from intuition ("types form a lattice, lattices are often distributive") not from analysis.

2. **Test file written AFTER PIR, not during implementation.** The PIR identified the testing gap, then tests were written as a follow-up. Per the Implementation Protocol, tests should be part of each phase or at minimum a dedicated phase. The REPL tests during implementation were sufficient for correctness but not for regression prevention.

3. **11-field positional struct is ergonomic debt.** Adding 2 fields (property-cell-ids + declared-properties) required editing 9 construction sites × 2 = 18 edits. Each edit is a positional-arg addition prone to miscounting. Keyword arguments would reduce this to 0 edits for callers that don't use the new field.

---

## 7. Where We Got Lucky

1. **The Phase 5 inference counterexample was obvious.** `Int, Nat, String` immediately showed the distributivity failure. If the counterexample required dependent types or polymorphic constructors, the inference might not have found it with the simple sample set (base types only).

2. **No existing code depends on type domain algebraic properties.** Since Track 2G is new infrastructure, no existing code broke when we discovered the type lattice isn't distributive. If there had been existing Heyting-based error reporting, the finding would have been a regression, not a discovery.

---

## 8. What Surprised Us?

1. **The type lattice is NOT distributive.** This was the biggest surprise. The design assumed it was, the research notes discussed it as if it were, and three critique rounds didn't catch it. The flat equality merge — where `Int ⊔ Nat = ⊤` rather than `Int | Nat` (union type) — is the root cause. This means the equality merge is arguably the WRONG primary ordering for the type domain.

2. **The Implementation Protocol made Phase execution smooth.** No phase hit a snag. No diagnostic protocol needed. This is unusual compared to Track 2B (which hit snags on almost every phase). The difference: systematic mini-audits + principles challenges prevented wrong assumptions.

3. **Phase 6 (implication rules) was trivial.** The design described elaborate Pocket Universe internal stratification with scatter propagators. The implementation: a 30-line function that folds over rules and checks source properties. The elaborate design was for the PERMANENT structure; the scaffolding was simple. This gap between design complexity and implementation simplicity suggests the design was over-engineered for Track 2G — the elaborate version is Track 3-4 scope.

---

## 9. How Did the Architecture Hold Up?

**SRE infrastructure held up well.** The `sre-domain` struct was extensible (added 2 fields). The relation properties pattern (seteq on sre-relation, checked via has-property?) was directly reusable for domain properties. The domain registry paralleled ctor-registry cleanly.

**type-lattice.rkt was a clean mirror target.** type-lattice-meet mirrors type-lattice-merge structurally. The variance-aware decomposition for Pi/Sigma followed the same pattern as try-unify-pure. The ring action (contra→join, co→meet) slotted into the existing variance handling.

**Friction point: positional struct args.** 11 positional fields on `sre-domain` is unwieldy. Every new field requires updating all 9 construction sites. This is the most significant ergonomic issue.

**Friction point: no module-load-time network.** Property cells are designed to be on the network, but at module load time (when domains are constructed), no network exists. The scaffolding (struct field hash) handles this, but the permanent solution requires domain registration to happen AFTER network creation — which is a lifecycle ordering issue.

---

## 10. What Does This Enable?

1. **PPN Track 3**: Parse lattice domains can declare algebraic properties. Property profiles reported at registration. Property-gated behavior selects parsing strategies based on domain properties.
2. **Type lattice redesign track**: The finding that the type lattice isn't distributive under equality is a clear motivation and requirement specification for the redesign. The infrastructure (meet, property inference, diagnostic reporting) is ready to validate the redesigned lattice.
3. **UCS**: Domain algebraic properties will drive solving strategy selection (`#=` operator).
4. **Future domains**: Any new domain registered via `register-domain!` gets automatic property inference and implication derivation.

---

## 11. Technical Debt Accepted

| Debt | Rationale | Tracking |
|------|-----------|----------|
| Property cells as struct field hash (not network cells) | Module-load-time network doesn't exist. Struct fields are honest scaffolding. | PPN Master Track 3 notes |
| Domain registry as module-level hash (not network cell) | Same lifecycle issue. Same scaffolding pattern as ctor-registry. | PPN Master Track 3 notes |
| Implication rules as eager function (not network propagators) | Elaborate Pocket Universe design is Track 3-4 scope. Scaffolding is 30 lines. | Design doc §3.4 |
| 11-positional-field sre-domain struct | Works but unwieldy. Keyword args needed. | SRE Master note for future tracks |
| Ring action function not extracted as separate module | Encoded in type-lattice-meet variance handling. Extracting adds complexity for 2 domains. | Future: when >3 domains exist |

---

## 12. What Would We Do Differently?

1. **Test the distributivity assumption BEFORE declaring it.** A 5-minute REPL check (`for* ([a samples] [b samples] [c samples]) (check distributivity)`) would have caught the flat lattice issue in the design phase, not Phase 5. The Pre-0 benchmarks measured PERFORMANCE but not ALGEBRAIC PROPERTIES. A "Pre-0 property check" should be part of the design cycle for algebraic tracks.

2. **Write the test file as Phase 7c (not post-PIR).** The PIR identified the gap. The gap should have been prevented by the Implementation Protocol. Recommendation: add "tests" as an explicit Phase in every design (not just "test at every boundary" — a DEDICATED test phase).

3. **Use keyword arguments for sre-domain from the start.** Track 2F added the properties field to sre-relation using a seteq (clean). Track 2G added 2 fields to sre-domain using positional args (unwieldy). The sre-relation pattern was better.

---

## 13. Wrong Assumptions

| # | Assumption | Reality | Impact |
|---|-----------|---------|--------|
| 1 | Type lattice is distributive | Flat under equality merge (>2 incomparable atoms → not distributive) | Heyting consumer deferred. Phase 7 redesigned. |
| 2 | Equality merge IS the type domain's primary ordering | Equality and subtyping are different orderings on the same carrier | Design insight: algebraic properties may need to be per-ordering |
| 3 | Phase 6 needs elaborate Pocket Universe with scatter | 30-line function suffices for scaffolding | Design was over-specified for the immediate implementation |

---

## 14. What Did We Learn About the Problem?

**Algebraic domain awareness is fundamentally about the ORDERING, not just the carrier set.** The same set of types has different algebraic structure under equality (flat, not distributive) vs subtyping (structured, potentially distributive). This means "the type domain is Heyting" is not a well-formed statement — you must specify WHICH ordering.

This has implications beyond Track 2G: the SRE's relation system (equality, subtype, duality) already encodes different orderings on the same carrier. Algebraic properties per-relation (not just per-domain) is the principled long-term design — but it adds a combinatorial dimension that the current flat property model avoids.

**Property inference is more valuable as a DESIGN TOOL than as a runtime mechanism.** The counterexample `(Int, Nat, String)` told us something about the type system's architecture that no amount of testing or code review would have revealed. Running axiom tests during design (not just at registration) could catch mathematical assumptions early.

---

## 15. Are We Solving the Right Problem?

Yes, with a refinement. The original goal (algebraic domain awareness) is correct — domains SHOULD declare their algebraic structure, and infrastructure SHOULD derive capabilities from it. The implementation delivers this.

But the Phase 5 finding reveals a deeper problem: the type lattice's equality merge is the WRONG primary ordering for rich algebraic properties. The RIGHT primary ordering is subtyping (which includes unions, intersections, and has the structure Heyting algebras need). The type lattice redesign track is the REAL path to Heyting error reporting — Track 2G provides the infrastructure that the redesigned lattice will use.

Track 2G solved the right infrastructure problem. The type lattice redesign solves the right mathematical problem.

---

## 16. Longitudinal Survey — 10 Most Recent PIRs

| # | Track | Date | Duration | Commits | Test Delta | D:I Ratio | Bugs | Wrong Assumptions |
|---|-------|------|----------|---------|------------|-----------|------|-------------------|
| 1 | PM Track 8 | 03-22 | ~18h | 66 | +35 | 1:2 | 10+ | 3 |
| 2 | SRE Track 0 | 03-22 | ~3h | 7 | +15 | 2:1 | 0 | 0 |
| 3 | SRE Track 1+1B | 03-23 | ~8h | 21 | +43 | 2:1 | 4 | 2 |
| 4 | SRE Track 2 | 03-23 | ~4h | 6 | +0 | 1.7:1 | 1 | 1 |
| 5 | PM 8F | 03-24 | ~8h | 15 | +0 | 1.5:1 | 2 | 3 |
| 6 | PM Track 10 | 03-24 | ~18h | 30 | -37 | 1:2 | 8 | 3 |
| 7 | PM Track 10B | 03-26 | ~8h | 20 | +0 | 3:5 | 8 | 2 |
| 8 | PPN Track 0 | 03-26 | ~4h | 8 | +30 | 1:1 | 2 | 0 |
| 9 | PPN Track 1 | 03-26 | ~14h | 25 | +108 | 1.4:1 | 25+ | 3 |
| 10 | PPN Track 2 | 03-29 | ~8.5h | 68 | +57 | 0.8:1 | 4 | 5 |
| 11 | PAR Track 1 | 03-28 | ~14h | 53 | +0 | 1.5:1 | 10 | 2 |
| 12 | PPN Track 2B | 03-30 | ~10h | 18 | +0→+32 | 1:1 | 3 | 5 |
| **13** | **SRE Track 2G** | **03-30** | **~10h** | **11** | **+32** | **1.5:1** | **3** | **3** |

### Recurring Patterns

**Pattern 1: Design critique prevents implementation bugs (13/13 PIRs).** Every track with ≥3 design iterations had fewer implementation pivots. Track 2G: 3 critique rounds + NTT model → 14 issues resolved pre-implementation → 0 reverts, 0 snags.

**Pattern 2: Wrong assumptions cluster at mathematical/theoretical boundaries (new pattern).** Track 2G's #1 assumption (distributive type lattice) was a MATHEMATICAL assumption, not an implementation assumption. Prior tracks' wrong assumptions were about code structure, API shapes, or execution ordering. This is the first track where the wrong assumption was about the MATHEMATICS of the domain. Implication: algebraic tracks need "Pre-0 property checks" alongside Pre-0 benchmarks.

**Pattern 3: Implementation Protocol correlation.** Track 2G used the formalized Implementation Protocol (mini-audit per phase, principles challenge, phase completion). Result: 0 reverts, 0 diagnostic protocol invocations, 3 bugs (all caught by built infrastructure). Compare Track 2B (no formalized protocol): 3 reverts, multiple diagnostic invocations, 5+ wrong assumptions. Sample size is 1 vs 1, but the correlation is suggestive.

**Pattern 4: D:I ratio stabilizing at 1.5:1 for algebraic tracks.** SRE Track 0 (2:1), SRE Track 2 (1.7:1), SRE Track 2G (1.5:1). Infrastructure tracks with clear mathematical grounding have higher D:I ratios than application tracks (PPN Track 2: 0.8:1, PPN Track 2B: 1:1). The design investment pays off in fewer bugs and smoother execution.

**Pattern 5: NTT modeling catches architectural impurities (2/2 tracks that used it).** PPN Track 2 NTT model found 3 gaps (rewrite, refine, foreach). SRE Track 2G NTT model found the scatter impurity in Phase 6. NTT modeling should be MANDATORY for propagator tracks, not optional.

### Slow-Moving Trends

**Trend A: Test delta per track is increasing for infrastructure tracks.** SRE Track 0 (+15), SRE Track 2 (+0), SRE Track 2G (+32). The emphasis on persistent tests (vs REPL-only validation) is growing. The PIR testing gap finding drove the +32.

**Trend B: "Wrong assumptions" severity is shifting from code to mathematics.** Early tracks: "struct field missing" (code). Middle tracks: "API shape wrong" (interface). Track 2G: "type lattice isn't distributive" (mathematics). As the infrastructure matures, the assumptions that survive to implementation are increasingly about the mathematical properties of the domain, not about the code.

---

## Lessons Distilled

| Lesson | Candidate For | Status |
|--------|---------------|--------|
| L1: Inference validates declarations (dual-path design) | DEVELOPMENT_LESSONS.org | Pending |
| L2: NTT modeling catches architectural impurities | DESIGN_METHODOLOGY.org (NTT section) | Reinforced (2nd instance) — approaching codification (3+) |
| L3: Algebraic properties are per-ordering, not per-carrier | Research note for type lattice redesign track | Pending |
| L4: Keyword args for >8-field structs | SRE Master note | Done (`dbe3e31f` session) |
| Implementation Protocol smooths execution | DESIGN_METHODOLOGY.org Stage 4 | Done (`b46c24ff`) |
| "Pre-0 property check" for algebraic tracks | DESIGN_METHODOLOGY.org Stage 3 | Pending — new pattern from this track |

---

## Open Questions

- **Should the type lattice's equality merge be replaced by a subtype-aware merge?** This is the type lattice redesign question. The equality merge produces ⊤ for incomparable types; a union-type-aware merge would produce `Int | String`. The algebraic properties of the redesigned lattice would be richer.
- **Should NTT modeling be MANDATORY for all propagator tracks?** 2/2 tracks that used it found architectural issues. The cost is ~1 hour of design time. The benefit is catching impurities before implementation.
- **Should algebraic property inference run during the design cycle (Pre-0)?** The counterexample `(Int, Nat, String)` would have been found in minutes during design. Adding "Pre-0 property check" to the design methodology for algebraic tracks would catch mathematical assumptions early.
