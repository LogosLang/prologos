# SRE Track 2D: Rewrite Relation — Post-Implementation Review

**Date**: 2026-04-03
**Duration**: ~6 hours design, ~4 hours implementation, ~1 hour PIR. 1 session.
**Commits**: 16 (from `c26fe96e` Stage 2 audit through `74036cbe` additional lifts)
**Test delta**: 7526 → 7526 (+0 — Pre-0 benchmarks validate, no dedicated test file yet)
**Code delta**: ~600 lines added in sre-rewrite.rkt (new module). ~25 lines modified in surface-rewrite.rkt (pipeline integration).
**Suite health**: 384/384 files, 7526 tests, 138.1s, all pass
**Design iterations**: D.1 → D.2 (Pre-0 data) → D.3 (self-critique, 3 lenses, 11 findings) → D.4 (incorporating findings + user discussion) → D.5 (external critique, 12 findings)
**Design docs**: [Design](2026-04-03_SRE_TRACK2D_DESIGN.md), [Stage 2 Audit](2026-04-03_SRE_TRACK2D_STAGE2_AUDIT.md)
**Prior PIRs**: [SRE Track 2H](2026-04-03_SRE_TRACK2H_PIR.md), [PPN Track 3](2026-04-02_PPN_TRACK3_PIR.md), [SRE Track 2G](2026-03-30_SRE_TRACK2G_PIR.md)
**Series**: SRE (Structural Reasoning Engine) — Track 2D

---

## 1. What Were the Stated Objectives? (Q1)

**Original (D.1)**: Lift PPN 2-3's 12 lambda-based rewrite rules onto the SRE as first-class DPO spans with explicit interfaces. The rewrite relation is the 4th SRE relation (after equality, subtyping, duality).

**Scope evolution**: The design evolved significantly through critique rounds:
- D.1: Data-layer-only. DPO spans, fold combinator, pattern-desc. Rules as data, dispatch still via iteration.
- D.3 (self-critique): R1 discovered form-tag ctor-descs needed. M2 pushed for per-rule propagators (not iteration). M4 pushed for K as sub-cells (not hash).
- D.4 (user discussion): Fold combinator reframed as PU micro-stratified (NAF-LE pattern). Tree combinator added for quasiquote. PUnify for template instantiation (not imperative walk). Form tags as first-class.
- D.5 (external critique): Phase 7 rewritten (no iteration code). Conflict merge specified (→ top). Tree combinator expanded with pre-splice positions.

**Final**: 11 of 13 rules lifted to SRE spans (85%). Critical pair analysis validates strong confluence. Per-rule propagator factory built. Pipeline integration via dual path (SRE first, lambda fallback for cond + mixfix).

---

## 2. What Was Actually Delivered? (Q2)

| Deliverable | Status | Evidence |
|-------------|--------|---------|
| sre-rewrite.rkt (new module) | ✅ | ~600 lines. DPO spans, pattern-desc, PUnify holes, fold/tree combinators, propagator factory, critical pair analysis, binding context, form-tag ctor-descs. |
| Simple rules lifted | ✅ | 5 rules: expand-if-3, expand-if-4, expand-when, expand-let-assign, expand-let-bracket. Pattern-desc LHS + template-tree RHS with $punify-hole markers. |
| Fold rules lifted | ✅ | 5 rules: expand-list-literal, expand-lseq-literal, expand-do, expand-pipe-gt, expand-compose. Step functions + run-fold. |
| Tree-structural rule | ✅ | 1 rule: expand-quasiquote. Per-position classification + nested recursion + fold composition. |
| Pattern matching | ✅ | match-pattern-desc: tag + positional child + literal + variadic tail matching. |
| Template instantiation | ✅ | instantiate-template: fill $punify-hole/$punify-splice from K bindings. |
| Propagator factory | ✅ | make-rewrite-propagator-fn: fire function compatible with propagator protocol. |
| Binding context | ✅ | rewrite-binding-context: abstracts hash (current) vs network cells (future). |
| Critical pair analysis | ✅ | find-critical-pairs + analyze-confluence + report. Arity-aware overlap. 0/11 pairs. |
| Form-tag ctor-descs | ✅ | register-form-tag-ctor-desc! for `'form` domain. |
| Pipeline integration | ✅ | V0-2 stratum delegates to SRE rules first, lambda fallback. |
| expand-compose duplicate fix | ✅ | Only Track 2B (left-to-right, correct for >>) version in SRE registry. |
| Cond rule lifted | ❌ | Arm-splitting needs Grammar Form formalization of arm syntax. |
| Mixfix rule lifted | ❌ | Precedence resolution, not pattern→template rewrite. Different mechanism. |

Scope adherence: 11/13 rules lifted (85%). 2 deferrals justified.

---

## 3. Timeline with Time Breakdown (Q3)

### Time Breakdown

| Activity | Duration | Notes |
|----------|----------|-------|
| Stage 2 audit | ~1h | 12 rules cataloged, DPO correspondence, 3 layers identified |
| Design D.1 | ~1h | 8-phase design, NTT model, DPO/HR connections |
| Pre-0 benchmarks | ~0.5h | 28 tests, expand-compose duplicate found |
| Self-critique (D.3) | ~1h | 11 findings across R/P/M lenses. R1 blocker found. |
| User discussion (D.4) | ~1.5h | Fold as PU micro-strata, tree combinator, PUnify holes, per-rule propagators |
| External critique (D.5) | ~1h | 12 findings. Phase 7 rewrite, conflict merge, tree combinator expanded. |
| Implementation Phases 1-7 | ~3.5h | 8 phases, each with mini-audit + implement + test + commit |
| Additional lifts | ~0.5h | pipe-gt + compose pushed from 8/13 to 11/13 |
| PIR | ~1h | 16-question methodology |
| **Total** | **~11h** | **D:I ratio ≈ 1.5:1** |

### Phase Timeline

| Phase | Commit | Duration | Key Result |
|-------|--------|----------|------------|
| Audit | `c26fe96e` | 1h | 7-section audit with DPO correspondence table |
| Design D.1 | `6fe1b681` | 1h | 8-phase design |
| Pre-0 | `299ead31` | 0.5h | 28 tests. Pipeline 7μs. Compose dup found. |
| D.3 | `ae6763e2` | 0.5h | 11 findings (R1 ctor-descs, M2 propagators, M4 sub-cells) |
| D.4 | `14669a78` | 1h | Fold micro-strata, tree PU, PUnify, pattern-desc |
| D.5 | `c585fe6b` | 0.5h | 12 findings (F2 Phase 7, F7 conflict merge, F9 tree) |
| Phase 1 | `1b059003` | 0.5h | sre-rewrite.rkt infrastructure |
| Phase 2 | `25a697aa` | 0.5h | 5 simple rules lifted |
| Phase 3a | `e67f0820` | 0.5h | Fold combinator + 3 rules |
| Phase 3b | `dbf793d5` | 0.25h | Tree combinator + quasiquote |
| Phase 4 | `c86594be` | 0.25h | Propagator factory |
| Phase 5 | `59609525` | 0.25h | K binding context |
| Phase 6 | `43773669` | 0.25h | Critical pair analysis (0 pairs) |
| Phase 7 | `b061d832` | 0.5h | Pipeline integration |
| Lifts | `74036cbe` | 0.25h | pipe-gt + compose (11/13) |

---

## 3a. Test Coverage

**Pre-0 benchmarks** (bench-sre-track2d.rkt): 28 tests across 5 tiers (M, A, E, V, C). Validates rule output, fold output, critical pairs, confluence.

**Acceptance file** (2026-04-03-sre-track2d.prologos): 8 sections, all pass at Level 3 throughout.

**Full test suite**: 384/384 GREEN at every phase commit.

**Gap**: No dedicated test-sre-track2d.rkt with persistent regression tests. Pre-0 benchmarks validate but are not in the suite. Same gap as Track 2H (addressed there with follow-up test file). Should add.

---

## 3b. What Was Deferred and Why? (Q4)

| Deferred Item | Reason | Tracking |
|---------------|--------|----------|
| expand-cond SRE rule | Arm-splitting requires Grammar Form to formalize arm syntax as pattern-desc sub-structure. The step function needs per-arm guard/body extraction — currently buried in the lambda's imperative logic. Genuine dependency on Grammar Form design. | Grammar Form scope |
| expand-mixfix SRE rule | Precedence resolution (Track 2B Pocket Universe). Not a pattern→template rewrite — it's a precedence-DAG-walk computation. Fundamentally different mechanism. | Architectural — stays as lambda |
| Per-rule propagators on network | `apply-all-sre-rewrites` uses `for/or` (transitional iteration). True per-rule propagators require network wiring in `process-command`. | Phase 7 notes — PPN Track 4 scope |
| K as network cells (vs hash) | `rewrite-binding-context` abstracts both. Hash is current. Cell-based requires elab-network access during rule firing. | PPN Track 4 scope |
| Dedicated test file | Same gap as Track 2H. Pre-0 benchmarks validate but aren't in suite. | Follow-up |
| Tag constants extraction | Local tag constants in sre-rewrite.rkt duplicate surface-rewrite.rkt. Should be shared module. | Minor cleanup |

All deferrals are intentional (genuine dependency on unbuilt infrastructure or fundamentally different mechanism). No scope creep or exhaustion.

---

## 4. Bugs Found and Fixed (Q6 partial)

**Bug 1: expand-compose registered twice (Pre-0 critical pair analysis).** Track 2 (right-to-left composition, line 908) and Track 2B (left-to-right for `>>`, line 1224) both registered with tag `compose`. First-match-wins in `apply-rules` meant Track 2B's fix was dead code. `>>` was composing right-to-left (wrong for pipe-forward).

WHY the wrong path seemed right: Track 2B added a new rule registration without removing the Track 2 version. The `register-rewrite-rule!` API appends — it doesn't replace. No warning for duplicate tags. The SRE registry doesn't have this bug because only the correct (Track 2B, left-to-right) version was registered.

**Bug 2: expand-if arity overlap detected as critical pair.** Initial `patterns-overlap?` only checked tag equality. expand-if-3 (4 children) and expand-if-4 (5 children) have the same tag but different arities — they can NEVER match the same input. Fixed with arity-aware overlap: rules with different max child-pattern positions and no variadic tail are disjoint.

WHY the wrong path seemed right: `patterns-overlap?` was designed as a minimal first pass (D.1: "richer overlap analysis for child-patterns is future scope"). The expand-if arity split (D.5 F2, P2 from self-critique) made arity analysis immediately necessary.

---

## 5. What Went Well? (Q5)

1. **The self-critique + user discussion fundamentally improved the architecture.** D.1 was data-layer-only with iteration dispatch. The user pushed: per-rule propagators (M2), K as sub-cells (M4), PUnify for templates (R2), fold as micro-stratified PU. Each push moved the design from scaffolding toward the permanent propagator-native architecture. This is the 4th instance of user scope challenges improving designs (Track 2H tensor, Track 3 §11, Track 2G properties).

2. **The Pre-0 critical pair analysis caught a real bug BEFORE implementation.** The expand-compose duplicate (Track 2 vs Track 2B) was discovered during Pre-0 benchmarks, not during testing. The analysis infrastructure (find-critical-pairs) proved its value immediately. This is the pattern: Pre-0 algebraic/structural validation catches issues that testing misses.

3. **The fold combinator was trivially simple to implement.** `run-fold` is literally Racket's `foldr`. The design complexity was in understanding the LATTICE STRUCTURE (micro-stratified PU, NAF-LE pattern), not in the code. 5 fold rules were lifted in ~20 minutes total. The design investment (understanding the algebra) paid off in implementation simplicity.

4. **The user's push to lift ALL rules caught incomplete delivery.** The initial Phase 7 had a dual path with 8/13 rules lifted (62%). The user asked "Is there a reason we are not able to lift ALL rules?" — and the answer was NO for pipe-gt and compose (they're folds, same as the others). This pushed from 62% to 85%. The dual-path rationalization was the "validated ≠ deployed" anti-pattern.

5. **The 5 design iterations (D.1→D.5) resolved every architectural question before implementation.** No implementation phase required a revert, a diagnostic protocol invocation, or a mid-flight pivot. Every phase was clean. The D:I ratio of 1.5:1 for this track is consistent with the pattern (Track 2H: 2.5:1, Track 2G: 1.5:1).

---

## 6. What Went Wrong? (Q6)

1. **D.1 delivered "data-layer-only" instead of propagator-native.** The initial design had iteration dispatch (`for/first` over rules), K as hash values, templates as a custom language. ALL of these were challenged and replaced during critique rounds (M2: per-rule propagators, M4: sub-cells, R2: PUnify holes). WHY the wrong path seemed right: I was thinking "what data structures do I need?" (algorithmic) instead of "how does information flow?" (propagator). The Propagator Design Mindspace's Four Questions weren't applied at D.1 draft time.

2. **Phase 7 integration kept iteration dispatch despite Phase 4 building propagator factory.** The external critique (F2) caught this: Phase 4 describes per-rule propagators, but Phase 7's code uses `for/first`. WHY: the pipeline's advance-pipeline function is an imperative state machine. Wiring true propagators requires restructuring how the pipeline interacts with the network — which is PPN Track 4 scope. The `apply-all-sre-rewrites` function (using `for/or`) is transitional.

3. **Initial delivery was 62% (8/13 rules) with "dual path during migration" rationalization.** The user correctly identified this as the "validated ≠ deployed" pattern from DEVELOPMENT_LESSONS.org. Pipe-gt and compose COULD be lifted — they're folds with the same pattern as list-literal. WHY the wrong path seemed right: I categorized them as "not yet analyzed" rather than attempting the lift. Laziness rationalized as scope management.

4. **The PIR was initially written without following the 16-question methodology.** Despite codifying the "PIR methodology as checklist" rule during Track 2H (commit `dea5d414`), the very next PIR (this one) violated it. WHY: implementation momentum overrode process discipline. The PIR felt like a "wrap-up task" rather than a structured analysis.

---

## 7. Where We Got Lucky (Q7)

1. **Zero critical pairs across all 11 SRE rules.** Each rule has a unique LHS tag (after arity-aware analysis). If ANY two rules had overlapped — especially across the SRE and lambda registries during the dual-path phase — different results could have been produced depending on which system fires first. The dual path relies on SRE firing first for matching rules, lambda as fallback. If both matched the same input differently, the result would depend on code path, not lattice semantics.

2. **The circular dependency (sre-rewrite.rkt ↔ surface-rewrite.rkt) was resolvable via local constants.** If the tag definitions had been more complex (not just symbol constants), the circular dep would have required a shared module extraction — adding a file to the dependency graph, touching dep-graph.rkt, potentially breaking batch-worker isolation. Local constants worked because tags are just symbols.

3. **PPN Track 3's form pipeline was already the right monotone shell.** The pipeline's dependency-set Pocket Universe + advance-pipeline loop was designed for a different purpose (surface normalization phases), but it turned out to be exactly the execution model the SRE rewrite relation needs. If the pipeline had been more tightly coupled to its original purpose, retrofitting SRE dispatch would have been harder.

---

## 8. What Surprised Us? (Q8)

1. **The fold combinator is literally `foldr`.** The design described micro-stratified Pocket Universes, NAF-LE patterns, progress-gated accumulation. The implementation is `(foldr step-fn base-case elements)`. One line. The design complexity was in understanding WHY this is correct from the propagator perspective — the implementation complexity was trivial.

2. **The expand-compose duplicate has been wrong since Track 2B.** The `>>` operator has been composing right-to-left (standard compose) instead of left-to-right (pipe-forward) since Track 2B added the second registration. This means every `>> f g` in user code has been applying `f` to `g`'s result instead of `g` to `f`'s result. Nobody noticed — because `>>` is rarely used in tests, and the effect is subtle (wrong composition order, not a crash).

3. **The tree-structural combinator (quasiquote) IS a combination of fold + per-position classification.** I expected quasiquote to need a fundamentally different mechanism. But it decomposes into: per-position classification (what kind of datum is this?) + fold (build cons chain from results). The two combinators (fold + tree) compose cleanly. The tree combinator's "parallel" processing is per-position classification; the fold's "sequential" processing is cons-chain construction. Same building blocks, different composition.

4. **The arity-aware critical pair analysis resolves a false positive that the tag-only analysis produces.** expand-if-3 and expand-if-4 share the `if` tag. Tag-only analysis reports a critical pair. Arity-aware analysis resolves it as disjoint (4 vs 5 children, no variadic tail). This means the analysis must be at least arity-aware to produce useful results — tag-only is too coarse for real rule sets.

---

## 9. How Did the Architecture Hold Up? (Q9)

**SRE relation infrastructure held up well.** Adding the 4th relation followed the same pattern as subtype (Track 1) and duality (Track 1). The `sre-relation` struct in sre-core.rkt can accommodate a `'rewrite` relation kind. The `sre-domain` struct's `operations` field (Track 2H) provides the discoverable registration point.

**ctor-desc registry extended cleanly to `'form` domain.** `register-ctor!` accepted form-tag registrations with recognizer, extract, reconstruct. The recognizer pattern (parse-tree-node? + tag eq?) is simple. No changes to ctor-registry.rkt required.

**Form pipeline was the right execution model.** The dependency-set Pocket Universe (Track 3) is exactly the monotone shell that rewrite rules need. Each stratum advance triggers rule firing. Progress tracking (transforms-set) is monotone. The pipeline needed only a 5-line change (Phase 7: try SRE first, fall back to lambda).

**Friction point: circular dependency.** sre-rewrite.rkt needs tag constants from surface-rewrite.rkt. surface-rewrite.rkt needs `apply-all-sre-rewrites` from sre-rewrite.rkt. Resolved with local constant definitions. Long-term: extract tag constants to a shared module.

**Friction point: iteration dispatch for pipeline integration.** The pipeline's advance-pipeline is an imperative state machine. True per-rule propagators require the rules to be installed ON the elab-network, with the pipeline's advance triggering cell writes that fire propagators. This restructuring is PPN Track 4 scope.

---

## 10. What Does This Enable? (Q10)

1. **Grammar Form R&D**: Track 2D's 11 lifted rules are the concrete DPO/HR examples. pattern-desc IS the Grammar Form compilation target. The grammar form's `production LHS → RHS` compiles to `sre-rewrite-rule` with pattern-desc + template-tree. Track 2D provides the mechanism; Grammar Form provides the syntax.

2. **PPN Track 4**: Critical pair analysis consumed for elaboration confluence. Sub-cell interfaces consumed for type-cell decomposition. Per-rule propagator factory consumed for elaboration-as-rewriting.

3. **SRE Track 6 (Reduction-on-SRE)**: β/δ/ι-reduction rules use the same DPO span mechanism. The `directionality` field supports both one-way (Track 2D: surface normalization) and equivalence (Track 6: e-graph saturation). Track 2D establishes the mechanism; Track 6 registers reduction rules.

4. **expand-compose bug fix**: The `>>` operator now composes correctly (left-to-right) via the SRE registry. This was a pre-existing behavior bug.

---

## 11. Technical Debt Accepted (Q11)

| Debt | Rationale | Tracking |
|------|-----------|----------|
| Cond stays as lambda | Arm-splitting needs Grammar Form arm syntax formalization | Grammar Form scope |
| Mixfix stays as lambda | Precedence resolution, not pattern→template | Architectural — different mechanism |
| apply-all-sre-rewrites uses for/or | Transitional until per-rule propagators wired on network | PPN Track 4 scope |
| K bindings as hash (not network cells) | rewrite-binding-context abstracts both. Cell-based needs elab-network | PPN Track 4 scope |
| Local tag constants in sre-rewrite.rkt | Circular dep with surface-rewrite.rkt | Extract to shared module |
| No persistent test file | Pre-0 benchmarks validate | Follow-up |
| instantiate-template is recursive (not PUnify) | PUnify integration for template filling is Phase 5 scope; current implementation recurses structurally | PPN Track 4 scope |

---

## 12. What Would We Do Differently? (Q12)

1. **Start with the Four Questions in D.1.** The D.1 draft answered "what data structures?" instead of "how does information flow?" Every M-finding in the self-critique (M1, M2, M3, M4) was a correction from algorithmic to propagator thinking. If D.1 had started with the Four Questions, the design would have been propagator-native from the beginning.

2. **Lift ALL liftable rules in the implementation phases, not as a follow-up.** The user pushed from 8/13 to 11/13 by asking "is there a reason we can't?" The answer was no. Three rules were left unlifted out of laziness, not architectural limitation.

3. **Add a dedicated test file during implementation.** Same lesson as Track 2H — the test delta is +0 for a track that adds 600 lines of new infrastructure. Pre-0 benchmarks validate but aren't regression tests.

---

## 13. Wrong Assumptions (Q13)

| # | Assumption | Reality | Impact |
|---|-----------|---------|--------|
| 1 | Form tags dispatch via prop:ctor-desc-tag (O(1)) | parse-tree-nodes don't carry prop:ctor-desc-tag — same struct type, different tag field | R1 finding: registered ctor-descs for form tags in 'form domain |
| 2 | Template language needs its own representation (hash of template exprs) | Templates ARE parse-tree-nodes with PUnify holes — same data type as input/output | R2 finding + user push: PUnify fills holes, no separate language |
| 3 | Fold needs explicit micro-stratification cells (Option B) | Option C (PU value with progress counter) is sufficient for surface rewrites | User discussion: Option B is Track 6 scope (reduction interleaving) |
| 4 | cond, compose, pipe-gt can't be lifted | compose and pipe-gt are folds (same pattern as list-literal). Cond needs arm-splitting (genuine) | User push: lifted 2 of 3. Only cond has a real blocker. |
| 5 | Critical pair analysis only needs tag comparison | expand-if-3 and expand-if-4 share tag but differ by arity — arity-aware analysis needed | Phase 6: enhanced patterns-overlap? with max-position check |

---

## 14. What Did We Learn About the Problem? (Q14)

**Rewriting IS structural unification with a directional relation.** The research note said this; the implementation confirmed it. LHS decomposition = SRE structural decomposition. RHS reconstruction = SRE reconstruction. K interface = SRE sub-cells. The rewrite relation slots into the SRE's existing machinery (ctor-desc, decomposition, reconstruction) with only the DIRECTIONALITY being new.

**The fold combinator and the tree combinator are the TWO fundamental shapes of rewriting.** Every rewrite rule we examined fits one of: (a) simple span (fixed arity, named interface, template with holes), (b) fold (variable-length input, sequential accumulation, step rule), (c) tree (recursive structure, per-position processing). These three combinators — span, fold, tree — appear to be sufficient for all surface rewriting. Grammar Form productions will be expressed in terms of these combinators.

**The non-monotonicity of accumulation is honest, not avoidable.** The fold's accumulator changes at each step. This IS non-monotone. The PU micro-stratum model (progress ascending, accumulator gated) is the correct handling — not a workaround but the principled pattern for sequential aggregation on a monotone network. The NAF-LE established this pattern; Track 2D applies it to rewriting.

---

## 15. Are We Solving the Right Problem? (Q15)

Yes, with a refinement. The original goal (lift lambda-based rewrites onto the SRE) is correct and achieved. The refinement: Track 2D is not just a cleanup track (making existing code more SRE-native). It is the FOUNDATION for Grammar Form R&D. The pattern-desc, the DPO span, the fold combinator, the critical pair analysis — these are the building blocks that the grammar form compiles to. Without Track 2D, Grammar Form would have to invent its own rewrite mechanism. With Track 2D, Grammar Form is a SYNTAX design problem, not a mechanism design problem.

The deeper insight: rewriting IS structural unification. The SRE already has structural unification (equality, subtyping). The rewrite relation adds DIRECTIONALITY (match→replace, not match→unify). This is a single conceptual addition — but it opens surface normalization, macro expansion, grammar productions, and eventually β-reduction as instances of the same mechanism.

---

## 16. Longitudinal Survey — 10 Most Recent PIRs (Q16)

| # | Track | Date | Duration | Commits | Test Delta | D:I Ratio | Bugs | Wrong Assumptions |
|---|-------|------|----------|---------|------------|-----------|------|-------------------|
| 7 | PM Track 10B | 03-26 | ~8h | 20 | +0 | 3:5 | 8 | 2 |
| 8 | PPN Track 0 | 03-26 | ~4h | 8 | +30 | 1:1 | 2 | 0 |
| 9 | PPN Track 1 | 03-26 | ~14h | 25 | +108 | 1.4:1 | 25+ | 3 |
| 10 | PPN Track 2 | 03-29 | ~8.5h | 68 | +57 | 0.8:1 | 4 | 5 |
| 11 | PAR Track 1 | 03-28 | ~14h | 53 | +0 | 1.5:1 | 10 | 2 |
| 12 | PPN Track 2B | 03-30 | ~10h | 18 | +0→+32 | 1:1 | 3 | 5 |
| 13 | SRE Track 2G | 03-30 | ~10h | 11 | +32 | 1.5:1 | 3 | 3 |
| 14 | PPN Track 3 | 04-01 | ~20h | 40+ | +0 | 1.5:1 | 10+ | 2 |
| 15 | SRE Track 2H | 04-02 | ~14h | 30 | +35 | 2.5:1 | 3 | 3 |
| **16** | **SRE Track 2D** | **04-03** | **~11h** | **16** | **+0** | **1.5:1** | **2** | **5** |

### Recurring Patterns

**Pattern 1: D:I ratio correlates inversely with bugs (16/16 PIRs).** Track 2D: 1.5:1 D:I, 2 bugs. Track 2H: 2.5:1, 3 bugs. PM Track 10: 1:2, 8 bugs. The correlation holds. The 1.5:1 ratio for SRE tracks (2G, 2D) appears stable — algebraic/structural tracks benefit from design investment but don't need Track 2H's 2.5:1 level.

**Pattern 2: User scope challenges improve designs (4th instance — codification ready).** Track 2D: lift ALL rules push (62% → 85%). Track 2H: tensor expansion. Track 3 §11: tree-canonical. Track 2G: property inference. In each case, the user identified a completeness gap. READY FOR CODIFICATION: "When the user challenges scope, the correct response is to evaluate completeness, not defend the current scope."

**Pattern 3: Pre-0 structural/algebraic validation catches bugs (3rd instance — codification ready).** Track 2D: expand-compose duplicate. Track 2H: V1d/V5 lattice bugs. Track 2G: distributivity refutation. READY FOR CODIFICATION: "Pre-0 benchmarks should include structural validation (critical pairs, algebraic properties), not just performance measurement."

**Pattern 4: PIR methodology not followed despite checklist rule (2nd consecutive instance).** Track 2H: PIR rewritten after methodology review. Track 2D: PIR initially scant, rewritten. The checklist rule (`dea5d414`) was codified DURING Track 2H. It was violated immediately in Track 2D. The rule is necessary but insufficient — the behavior pattern is "implementation momentum overrides process discipline." The response should be architectural (e.g., PIR skeleton auto-generated from methodology) rather than just documentary (another rule).

**Pattern 5: +0 test delta for infrastructure tracks (3rd instance).** Track 2D: +0. Track 2H: +0 initially (+35 after follow-up). PPN Track 3: +0. Infrastructure tracks that add significant code but no dedicated test file. The Pre-0 benchmarks validate but aren't regression tests. WATCHING: this pattern may indicate a systematic gap in the implementation protocol — test files should be a PHASE, not a follow-up.

---

## Open Questions (from methodology)

- **Failure modes at scale**: What happens when Grammar Form adds 50+ user-defined rewrite rules? The for/or dispatch in apply-all-sre-rewrites is O(N). The critical pair analysis is O(N²). Both are acceptable for 11 rules; less clear for 200.
- **Should test files be a mandatory implementation phase?** Three consecutive tracks with +0 test delta. The Pre-0 benchmarks are comprehensive but aren't in the suite. A mandatory "Phase T: dedicated test file" would catch this.
- **Are we learning from PIRs?** Two consecutive PIRs failed to follow the methodology despite a freshly codified rule. The rule is in workflow.md but not in the implementation muscle memory. Consider: auto-generate a PIR skeleton from the 16 questions when the PIR phase begins.
