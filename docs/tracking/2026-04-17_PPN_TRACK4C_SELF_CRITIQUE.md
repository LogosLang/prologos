# PPN Track 4C — Self-Critique (D.2)

**Date**: 2026-04-17
**Target**: [PPN 4C Design D.2](2026-04-17_PPN_TRACK4C_DESIGN.md) as of commit `006a83dc`.
**Methodology**: [CRITIQUE_METHODOLOGY.org](principles/CRITIQUE_METHODOLOGY.org) — three lenses (P/R/M) + SRE lattice lens.
**Status**: Round closed (2026-04-18). All findings resolved; see §8 for summary. D.2 ready for external critique round (D.3+).

---

## §1 Summary

| Lens | Findings | Severity distribution |
|---|---|---|
| P (Principles Challenged) | 4 | 1 substantive, 3 minor |
| R (Reality-Check) | 5 | **1 major** (R1), 4 confirmations / clarifications |
| M (Propagator-Mindspace) | 5 | 1 substantive, 4 clarifications |
| SRE (Lattice lens) | 1 | 1 substantive |

**Top three highest-severity findings** (for priority incorporation):
- **R1**: `net-new-cell` migration scope is much larger than D.2 acknowledges — **666 call sites across 97 files**. Phase 1 description under-states the scale.
- **S1**: Missing cross-facet bridge TypeToWarnings — coercion warnings flow off-diagram in current D.2 architecture.
- **M2**: "Pattern match IS PUnify" claim across multiple phases needs R-lens verification — does current PUnify (unify.rkt) work on TypeFacet quantale elements, or only on Expr-level metas?

Below, findings formatted per methodology (lens + sequential number + description + resolution proposal). User + author review together; resolved findings incorporate into D.3.

---

## §2 P Findings — Principles Challenged

### P1 — Option A freeze scaffold period: belt-and-suspenders risk across Phase 8–12?

**Finding**: Option A (tree walk reading `:term` facet) lands in Phase 8. Option C (cell-refs replacing `expr-meta`) lands in Phase 12. Between them: Phases 9, 9b, 10, 11 run with **both** mental models — tree-walk freeze exists AND cell-refs are being designed for. Red-flag phrase "scaffold" is legitimately used, but the retirement window spans 4 intermediate phases. During this window, new code could reinforce Option A patterns (tree-walk-reading-`:term`) and make Option C harder to land.

**Principle challenged**: Correct-by-Construction. The scaffold period is discipline-maintained, not structural. Phase 12 relies on the team not layering new tree-walk code on top of Option A.

**Counter**: retirement plan is explicit; Phase 12 deletes the tree-walk. Scope is bounded: phases 9, 9b, 10, 11 don't directly add freeze/zonk code — they target different axes.

**Resolution proposal**: Strengthen §6.6 with an explicit invariant: *no new code in Phases 9, 9b, 10, 11 reads `:term` via tree walk; any new read uses cell-ref deref (Phase 12 forward-declared) or fails*. Lint rule candidate: `no-new-tree-walk-freeze-reads`. Soft until Phase 12.

### P2 — Cell `:lattice` annotation is immutable; documented?

**Finding**: §6.8 implies `:lattice` is set at `net-new-cell` time. D.2 doesn't explicitly state this is *immutable* (the cell's lattice classification is its type, set at creation, cannot change). If a cell's usage pattern evolves and the annotation is wrong, the enforcement fails wrong.

**Counter**: natural for a type declaration; no one would expect a cell to change classification post-creation.

**Resolution proposal**: add one sentence in §6.8 stating the invariant explicitly. Low-cost clarity.

### P3 — Couple A8 enforcement to CHAMP retirement

**Finding**: A8 (`:lattice` enforcement at `net-add-propagator`) and A2 (CHAMP retirement) are separate phases but related. After CHAMP retirement (Phase 4), the CHAMP cell should not exist. Any new `net-add-propagator` attempting to read the retired CHAMP fails at what level? If the CHAMP parameter is `#f` post-retirement, reads fail at runtime; could be earlier.

**Counter**: §6.3 says "CHAMP code path deleted" — it just stops existing. Any residual read would be a compile error, not a runtime error.

**Resolution proposal**: no design change needed if §6.3's "deleted" is literal. But §6.3 could say "CHAMP meta-info struct + backing storage removed entirely; any lingering reference is a compile error." Locks in correctness-by-construction.

### P4 — Ergonomics of 666-site `:lattice` migration

**Finding**: R1 below shows 666 cell-creation sites. Requiring `:lattice` annotation on each is a significant churn. Is there a lower-friction design that preserves correctness?

**Options**:
1. (D.2 current): hard-require `:lattice` on `net-new-cell`. Audit + migrate 666 sites.
2. (Alternative): `:lattice` keyword optional, but merge-function registration carries the lattice classification. Cell creation inherits its classification from the merge function's declared classification. Sites that use registered merge functions (most) auto-annotate; only novel merge functions need explicit declaration.

Option 2 reduces per-site friction to near-zero while preserving enforcement. Merge-function-based inference IS NOT a shape heuristic — the merge function's `:lattice` declaration IS the annotation, just located on the function not the cell. Inheritance is structural, not heuristic.

**Counter**: cell can use a merge function with multiple valid `:lattice` classifications (e.g., a hash-union merge could work for either a structural compound or a value-set). Inheritance ambiguity.

**Resolution proposal**: D.3 considers Option 2 as a migration strategy — merge functions registered via a wrapper like `(define-merge-fn/lattice my-merge :lattice 'structural ...)` auto-propagate the classification to cells. Cell-level annotation required only when the merge function's classification is ambiguous or not registered. Migration compresses from 666 sites to ~30-50 merge-function sites.

---

## §3 R Findings — Reality Check (code audit)

### R1 — `net-new-cell` migration scope: 666 sites / 97 files (MAJOR finding)

**Finding**: D.2 §6.8 + §2 Phase 1 imply a "cell-creation site audit + migration" but don't quantify. Grep confirms:

- **666 `net-new-cell` call sites** across **97 files** (production + test + benchmarks).
- Production files with highest counts: session-runtime.rkt (16), atms.rkt (8), narrowing.rkt (7), propagator.rkt (6), zonk.rkt (6).
- Test files: ~50 in test-propagator-bsp.rkt, 41 in test-propagator-network.rkt, 34 in test-effect-bridge-01.rkt, many others.

**Scope implication**: this is NOT a small migration. Even mechanical classification of each site is 666 changes (stage across ~30 commits, minimum). Property inference at A9 covers 6 facets; `:lattice` annotation covers 666 cells. Apples-to-oranges scale.

**Resolution proposal**: D.3 should either:
- Adopt P4's Option 2 (merge-function-based inheritance) to compress migration.
- Acknowledge the scale explicitly in §6.8 + §2 Phase 1 (note 666 sites, expect multi-commit migration, with lint-cells baseline tracking progress).
- Consider phased migration: Phase 1 requires `:lattice` ONLY for cells read by new 4C propagators; existing cells annotated gradually over follow-on work.

### R2 — `register-stratum-handler!` does support `:tier` keyword (confirmation)

**Finding**: D.2 §6.7 claims `register-stratum-handler!` supports `:tier 'value | 'topology`. Audit confirms at [propagator.rkt:2392](../../racket/prologos/propagator.rkt):

```
(define (register-stratum-handler! request-cell-id handler-fn
                                   #:tier [tier 'value]
                                   #:reset-value [reset-value (hasheq)])
  (unless (memq tier '(topology value))
    (error 'register-stratum-handler! "tier must be 'topology or 'value, got ~a" tier))
  ...)
```

Default is `'value`. Current registrations: 4 topology, 1 value (S1 NAF in relations.rkt:245). ✓ confirmed.

**No action required.**

### R3 — `current-speculation-stack` migration scope (Phase 9)

**Finding**: D.2 §6.10 + Phase 9 reference cell-based TMS migration of `current-speculation-stack`. Audit: **21 occurrences across 6 files**:
- cell-ops.rkt (2)
- propagator.rkt (5)
- elab-speculation-bridge.rkt (2)
- typing-propagators.rkt (3)
- tests/test-tms-cell.rkt (8)
- tools/parameter-lint-baseline.txt (1)

Total ~13 production call sites + 8 test sites. Modest. Consistent with BSP-LE 1.5 design note's ~450 line estimate.

**No action required beyond acknowledging in Phase 9 scope.**

### R4 — PUnify / structural-unify existing infrastructure (confirmation, with caveat)

**Finding**: D.2 claims "PUnify is the match operation" across §6.1, §6.4, §6.5, §6.6, §6.10. Audit: **507 occurrences in 27 files**. unify.rkt alone has 40. Substantial existing infrastructure.

**Caveat (M2 below)**: current PUnify operates on Expr-valued cells with logic-variable-style metas. D.2 claims it extends to tag-dispatched merge on the shared TypeFacet carrier. That extension may be mechanical or substantial; needs verification. R2 confirms infrastructure exists; doesn't confirm reach.

**Resolution proposal**: Phase 3 (A5 `:type`/`:term` tag-layers) must verify PUnify's current scope against the design's assumed scope. If a gap exists, scope expansion to cover quantale-element unification. Mini-audit in Phase 3 pre-design.

### R5 — Meta `source` side registry not declared in §6.3

**Finding**: Pre-0 report concluded "5 of 7 meta-info fields map to facets; `source` goes to side registry." §6.3 (CHAMP retirement) says "move to a separate `:meta-metadata` facet or a side registry" — ambiguous, decision not recorded in design doc.

**Resolution proposal**: §6.3 explicit statement: `meta-source-metadata-registry` (single Racket parameter holding hasheq of meta-id → source-info) retains the debug metadata post-CHAMP retirement. Small, clear, consistent with how the Pre-0 decision was framed.

---

## §4 M Findings — Propagator-Mindspace

### M1 — "walk from most-specific downward" language (§6.5, §6.12)

**Finding**: Both §6.5 (parametric resolution) and §6.12 (Hasse-registry primitive) use "walk from most-specific candidates downward." "Walk" is step-think language. Even if the underlying operation is structural Hasse navigation (single index read at query's neighborhood), the wording imports the wrong mindspace.

**Resolution proposal**: rename throughout to propagator-mindspace equivalents:
- "walk from most-specific downward" → "structural lookup at the query's Hasse neighborhood" or "Hasse-navigation from most-specific candidates"
- "traverse" / "iterate" / "scan" in similar contexts: audit and reframe
- Add to the §6.12 primitive spec: lookup is a *structural index operation*, not a traversal

### M2 — "Pattern match IS PUnify" needs verification (see R4)

**Finding**: D.2 asserts pattern matching in Axis 1, aspect coverage, residuation, union ATMS branching, and Option C reduction all reduce to PUnify invocation. PUnify currently operates on Expr-valued structures with term-level metas (see unify.rkt). TypeFacet quantale elements are a richer structure (⊗ tensor, ⊕ union-join, residuals). Does PUnify handle them today, or is this an extension the design underdeclares?

**Specifically**:
- `List Int` vs `List E` (E = impl-level type var) — straightforward structural unification.
- `(A | B) ⊗ C` vs `Pi(C, ?D)` — union distribution + structural match. More complex. Does current PUnify handle union? Does it handle tensor?
- Residuation check `e : T` via PUnify-with-variance — does PUnify support variance, or is variance new?

**Resolution proposal**: Phase 3 pre-design (A5 `:type`/`:term` tag-layers) does a PUnify reach audit:
1. Does unify.rkt's PUnify handle union-typed operands? Tensor? Residuals?
2. Does it support variance (subsumption vs strict unification)?
3. If gaps: scope PUnify extension as part of Phase 3 or as a precursor sub-phase.

The M2 risk is "PUnify IS the mechanism" being a conceptual claim that needs an implementation retrofit. If the extension is mechanical, fine. If it's substantial, it deserves its own phase.

### M3 — Hasse-registry lookup: propagator or helper?

**Finding**: §6.12.1 describes `lookup(query)` as an operation. Unclear if it's itself a propagator (fires when query cells change) or a helper function invoked from fire functions. Implementation implication is non-trivial:
- If propagator: registry IS a network. Queries are cell values. Results written to output cells. Every lookup is a network event.
- If helper: fire function of another propagator calls `(lookup ...)` synchronously. Lookup doesn't fire independently; it's library code called from within a propagator's fire body.

D.2's §6.5 and §6.2.1 both read queries via lookup inside a fire function (not as a separate propagator). That's helper-function usage. But §6.12 doesn't say so explicitly.

**Resolution proposal**: §6.12 clarifies: registry is a cell (on-network). Lookup is a helper function called from fire functions — synchronous, reads the registry cell, returns the result. Not a separate propagator. Fire function's `:reads` includes the registry cell so it fires when the registry updates (not on every query — registry is monotone, rarely updates post-registration).

### M4 — Union ATMS framing: conceptual vs implementation

**Finding**: §6.10 asserts "ATMS union branching IS ⊕ ctor-desc decomposition." True conceptually — each union component is a structural sub-part. But BSP-LE's actual ATMS mechanism is `atms-amb` + assumption creation + worldview forking, not ctor-desc-driven.

**Resolution proposal**: §6.10 one-sentence clarification: the ⊕ ctor-desc framing is a *conceptual lens* explaining why ATMS branching on unions is principled. Phase 10 implementation uses `atms-amb` (BSP-LE 2+2B infrastructure); ctor-desc lens explains WHY the mechanism applies cleanly, without changing the implementation. Avoids over-claiming an implementation change that isn't happening.

### M5 — Residuation check timing (lazy vs eager)

**Finding**: §6.2 says cross-tag CLASSIFIER × INHABITANT merge computes residuation check. Merges happen on every cell write. Is the check computed eagerly (every write), or lazily (only when both tags present)?

Eagerly: expensive if residuation is non-trivial for compound types. Every INHABITANT write triggers subsumption check against any existing CLASSIFIER; every CLASSIFIER write triggers check against any existing INHABITANT.

Lazily: the merge function detects tag combinations and defers. Accumulate CLASSIFIERs and INHABITANTs; check on first cross-tag occurrence.

D.2 doesn't specify. Performance and correctness implications differ.

**Resolution proposal**: §6.2 specifies: residuation check fires at cross-tag merge time (i.e., only when a write would produce a record containing both CLASSIFIER and INHABITANT tagged entries). Existing tag-uniform merges are fast (type-lattice-merge or α-equivalence). Cross-tag check is rare (fires when CLASSIFIER is written after INHABITANT, or vice versa) — lazy by construction. Property inference verifies residuation check idempotence under repeated writes.

---

## §5 SRE Lattice Lens Findings

### S1 — Missing bridge TypeToWarnings

**Finding**: §4.3 declares four cross-facet bridges:
- TypeToConstraints
- ContextToType
- UsageToType
- TermInhabitsType (retired in D.2 — now internal residuation)

But: coercion warnings (e.g., cross-numeric-family `Int + Posit32`) are generated from type-family classification. This is a cross-facet flow from TypeFacet to WarningFacet. **No bridge declared.** The SRE lens Q4 (composition — full bridge diagram) finds a gap.

Information flow from TypeFacet reaches WarningFacet somehow in 4B today (emit-coercion-warning! — the Axis 6 bridge). Post-4C, driver reads `:warnings` facet directly. The propagator that detects coercion and writes `:warnings` operates on TypeFacet classifier info and writes to WarningFacet — that IS a cross-facet morphism, which by §6.11.1's framing should be a `bridge`.

**Resolution proposal**: Add to §4.3:

```
;; Coercion warnings emerge from type-family classification
bridge TypeToWarnings
  :from TypeFacet (CLASSIFIER layer)
  :to   WarningFacet
  :alpha detect-cross-family-coercion   ;; classifier → warning set
  :gamma #f                              ;; one-way — warnings don't flow back to types
```

Updates §4.3 (bridge declaration) and §6.11.1 SRE lens table (adds bridge to Composition row).

Also: is there a bridge for usage-validation warnings (Axis 6 covers coercion; usage validation from §6.4 produces `:warnings` writes too)? Check for completeness. If yes, either UsageToWarnings bridge or generalize to `TypeAndUsageToWarnings`.

---

## §6 Additional observations

### O1 — 666-site scale interacts with Phase 1 timing

If P4 Option 2 (merge-function inheritance) is adopted, Phase 1 scope compresses significantly. This could move Phase 1 earlier in the track (since it becomes smaller) or enable parallel work. If retained as "annotate all 666 sites," Phase 1 is a substantial standalone phase and any parallelization plans downstream shift.

### O2 — SRE lens application depth

D.2 §6.11.1 applies the SRE lens to 5 facets. The lens application depth is good for facets. The §6.11.6 addition for stratification as module composition extends it. But OTHER lattices in the design (e.g., impl coherence lattice from §6.11.4, inhabitant catalog lattice from §6.2.1) aren't explicitly registered through the SRE lens's 6 questions.

Per methodology: "SRE lattice lens is mandatory for all lattice design decisions." Phase 2 (A9) covers the 6 facets; what about the Hasse-registry's ambient lattice, or the worldview Boolean lattice (Phase 9)?

**Resolution proposal**: §6.12 includes SRE lens classifications for the Hasse-registry's ambient lattice (L parameter). §6.10 (union ATMS) includes worldview lattice SRE classification (already hypercube-documented in the BSP-LE addendum). Cross-reference per phase.

### O3 — Provenance chain implementation not specified

§6.1 claims "each tagged entry carries its derivation chain (source-loc + producer propagator + ATMS assumption)." Implementation not specified. Is this a new field on tagged-cell-value? Existing infrastructure? Cost?

**Resolution proposal**: §6.1 specifies the derivation-chain representation. Likely piggybacks on existing tagged-cell-value structure + ATMS assumption tracking. Verify in Phase 3 pre-design.

---

## §7 Resolution summary — candidates for D.3 incorporation

Grouped by decision point for user review:

| # | Finding | Severity | Resolution effort | Status |
|---|---|---|---|---|
| **R1 + P4** | 666-site migration + merge-function inheritance option | **Major** | Design decision + Phase 1 rescope | **✅ RESOLVED** (commit TBD). Tier 1/2/3 architecture adopted. Cell-level `:lattice` retired; `#:domain` override; ~37 merge functions. §6.8 rewritten. §13 Q4 updated. P2 (immutability) and P3 (coupling to CHAMP) absorbed via architectural clarity. O1 (Phase 1 timing) implicitly resolved. |
| **S1** | Missing TypeToWarnings bridge | Major | §4.3 addition + §6.11.1 update | ⬜ pending |
| **M2 + R4** | PUnify reach audit for quantale types | Substantive | Phase 3 pre-design includes audit | **✅ RESOLVED** (commit TBD). Audit of unify.rkt (1028 lines) confirms all D.2 claims map to existing infrastructure. Variance support already first-class via `'subtype` relation. Net-new PUnify work: ~150-200 lines of composition wiring, no algorithm development. §6.13 captures audit. Section citations added to §6.1/§6.2/§6.4/§6.5/§6.6/§6.10/§6.12. |
| M1 | Rename "walk" language in §6.5, §6.12 | Minor | Language polish | **✅ RESOLVED** (minors batch 2026-04-18). "walks the Hasse diagram" → "dispatches through Hasse structural index" in §6.5 and §6.12. |
| M3 | Clarify Hasse-registry lookup as helper | Minor | §6.12 clarification | **✅ RESOLVED** (minors batch 2026-04-18). §6.12.1 notes lookup is a helper function invoked synchronously from consuming propagators' fire bodies, not a standalone propagator. |
| M4 | Union ATMS framing is conceptual, not impl change | Minor | §6.10 clarification | **✅ RESOLVED** (minors batch 2026-04-18). §6.10 adds framing note: "ATMS branching IS ⊕ ctor-desc decomposition" is conceptual lens; Phase 10 uses existing `atms-amb` machinery. |
| M5 | Residuation check lazy-vs-eager | Substantive | §6.2 specification | **✅ RESOLVED** (commit TBD). Lazy (skipped-when-unnecessary + re-fired-on-narrowing, synchronous within merge) committed for D.3. Trigger condition specified in §6.2 with full correctness analysis for BSP/CALM/ATMS. Option 4 (separate propagator) dismissed. Verification plan: parity tests (Phase 0) + property inference (Phase 2) + A/B bench (Phase 3). Decision locked pending verification. |
| P1 | Option A scaffold period — lint rule candidate | Minor | Optional; discipline-based | **✅ RESOLVED-BY-DESIGN** (2026-04-18). Phase sequencing itself provides the guarantee: cell-refs don't exist until Phase 12; any freeze-like read during Phases 9-11b necessarily uses Option A (tree walk on `:term`), which is correct for those phases. There is no parallel code path to converge. Phase 12 retires Option A atomically — not staged. Lint rule would catch nothing because there's no alternative to misuse. P3 (couple A8 to CHAMP retirement) already structurally prevents the related concern of residual CHAMP reads post-Phase-4. |
| P2 | `:lattice` annotation immutability documented | Minor | One sentence | **✅ RESOLVED** by R1+P4 (cell-level `:lattice` retired) |
| P3 | Couple A8 to CHAMP retirement deletion | Minor | §6.3 wording | **✅ RESOLVED** (minors batch 2026-04-18). §6.3 Phase 3 close now states CHAMP code path + meta-info lattice fields deleted entirely; residual reads become compile errors. Explicit coupling to A8 enforcement. |
| R3 | Phase 9 `current-speculation-stack` scope confirmed | Confirmation | No action | ✅ confirmed (21 sites/6 files) |
| R5 | Meta `source` side registry named | Minor | §6.3 explicit | **✅ RESOLVED** (minors batch 2026-04-18). §6.3 names `current-meta-source-registry` as the side registry; explicit choice not to facetize (no lattice structure in source-loc); Phase 4 migration includes test-support.rkt + batch-worker.rkt save/restore per pipeline.md Two-Context Audit. |
| O1 | Phase 1 timing interacts with P4 resolution | Follow-up | Depends on P4 decision | **✅ RESOLVED** by R1+P4 (smaller migration; Phase 1 timing unaffected) |
| O2 | SRE lens applied to more lattices | Substantive | §6.12, §6.10 extensions | **✅ RESOLVED** (commit TBD). New §6.11.8 comprehensive lens catalog applies SRE + Module Theory + PUnify + Hasse-adjacency lens to all non-facet lattices (AttributeRecord, AttributeMap, impl coherence, inhabitant catalog, Hasse-registry L, worldview Q_n, ready-queue, retraction request set, tagged-cell-value layers). Two structural insights surfaced: impl coherence + inhabitant catalog are identical Hasse-registry instances; tagged-cell-value layers are the structural generalization of Module Theory Realization B. |
| O3 | Provenance chain representation | Substantive | §6.1 specification | **✅ RESOLVED** (commit TBD). Reframed per Module Theory + Hypergraph Rewriting research: provenance is structurally emergent from the propagator-firing dependency graph, not a new data structure. New §6.1.1 specifies three structural sources (ATMS tagging, `:trace :structural`, source-loc registry). **Error-reporting via backward residuation in 4C scope** per user direction — first-class compiler features, not debugging aid. New Phase 11b in Progress Tracker for diagnostic infrastructure. Helper API deferred to phase-time mini-design. |

**Resolution log**:
- 2026-04-17: R1 + P4 resolved via Tier 1/2/3 architecture (§6.8 rewrite). Grep confirmed production scope is 101 sites / 37 merge functions (not 666). Cell-level `:lattice` retired; replaced by Tier 2 merge-function inheritance with `#:domain` override. Absorbs P2 (immutability) and O1 (Phase 1 timing). Dialogue settled `#:domain` keyword (SRE vocabulary alignment; cells are instances not lattices).
- 2026-04-17: S1 resolved via TypeToWarnings bridge (§4.3) — composed α covering coercion + deprecation; one-way (no γ — warnings don't narrow type info). Dialogue clarified bridge-vs-propagator distinction: bridges are point-to-point Galois connections, multi-input flows are propagators. Multi-source warning detectors (multiplicity, capability) documented as propagators in §4.4 rather than bridges. Network egress (driver reading `:warnings` for display) not a bridge per NTT §5 convention. ConstraintsToWarnings potential gap noted as Phase 2 audit item (§6.9) rather than preemptive declaration.
- 2026-04-17: M2 + R4 resolved via PUnify audit of unify.rkt (1028 lines). All D.2 "PUnify IS the match operation" claims map to existing infrastructure — `sre-structural-classify` for ctor-desc decomposition, `unify-union-components` for ⊕, `type-tensor-core` for ⊗, `subtype-lattice-merge` via `'subtype` relation for variance, `current-structural-meta-lookup` for meta handling, flex-app machinery for Miller's-pattern metas. **Variance is already first-class via relation name**. Net-new work: ~150-200 lines of composition wiring (tag-dispatched merge function + Hasse-registry integration + γ hole-fill per-candidate PUnify + property inference), no new algorithm. New §6.13 in design doc captures audit; section citations added throughout (§6.1, §6.2, §6.4, §6.5, §6.6, §6.10, §6.12). Risk level: low.
- 2026-04-18: M5 resolved. Lazy cross-tag residuation check committed. "Lazy" = skipped-when-unnecessary AND re-fired-on-narrowing, executed synchronously within merge function. Trigger: cross-tag-present AND (CLASSIFIER-narrowed OR INHABITANT-narrowed). Case analysis (5 cases) + correctness analysis (BSP/CALM/ATMS compatibility) + property inference tractability. Option 4 (separate propagator for check) dismissed — creates unverified-state timing window. Decision locked for D.3 pending Phase 3 verification: parity tests + property inference + A/B micro-bench (vs eager alternative; threshold for decision is ≥10% overhead difference). §6.2 specifies trigger condition + verification plan.
- 2026-04-18: Minors batch resolved (M1, M3, M4, P3, R5). M1 language polish removes "walks" step-think wording from §6.5/§6.12. M3 clarifies Hasse-registry `lookup` as helper function (invoked from consuming propagators' fire bodies), not standalone propagator. M4 frames "ATMS branching IS ⊕ ctor-desc" as conceptual lens explaining principled connection; Phase 10 impl uses existing `atms-amb` machinery. P3 couples A8 enforcement to A2 retirement: CHAMP deletion is hard-delete, residual reads are compile errors. R5 names `current-meta-source-registry` as side registry for lattice-irrelevant source-loc metadata; explicit non-facetization choice documented.
- 2026-04-18: O2 resolved via new §6.11.8 comprehensive lens catalog. Applies SRE (6 questions) + Module Theory + PUnify + Hasse-adjacency lens uniformly to all non-facet lattices: AttributeRecord (product of facets), AttributeMap (position-indexed compound), impl coherence (Phase 7), inhabitant catalog (Phase 9b), Hasse-registry ambient L (§6.12), worldview Q_n (Phase 9/10 hypercube), ready-queue actions (S1), retraction request set (S(-1)), tagged-cell-value layers (pervasive Module Theory Realization B carrier). Two structural insights surfaced by the systematic treatment: (1) impl coherence + inhabitant catalog are structurally identical Hasse-registry instances differing only in parameterization — §6.12 primitive abstracts the identity for compositional win; (2) tagged-cell-value layer lattice is the structural generalization of Module Theory Realization B — every "shared-carrier + tags" application in 4C (`:type`/`:term`, `:constraints` by trait, worldview by assumption, attribute-map by position) is one instance of this lattice. Per CRITIQUE_METHODOLOGY § "SRE Lattice Lens is Mandatory": uniform application achieved.
- 2026-04-18: O3 resolved via provenance-as-structural-emergence framing, per user-identified research: Module Theory on Lattices §5-6 + Hypergraph Rewriting Research §6.3 ("dependency graph IS a proof object — the network naturally maintains provenance"). New §6.1.1 specifies: three structural sources (ATMS assumption tagging from Phase 9, `:trace :structural` mode from NTT §7.6, source-loc registry from Phase 4 R5). Error-reporting via backward residuation IS in 4C scope per user direction (push for better human-/machine-traceable errors/warnings/feedback; first-class compiler/error features; precise source mapping; IDE/LSP tooling support). New Phase 11b (diagnostic infrastructure) added to Progress Tracker, positioned after Phase 11 orchestration so all supporting infrastructure is in place. `derivation-chain-for(position, tag)` helper API shape deferred to phase-time mini-design per user direction.
- 2026-04-18: P1 resolved-by-design. Option A scaffold-period concern dissolves under phase sequencing: cell-refs don't exist until Phase 12; freeze-like reads during Phases 9-11b necessarily use Option A (correct for those phases); no alternative to misuse during the window. Phase 12 retires Option A atomically (not staged). Lint rule unnecessary. Related concern (residual CHAMP reads) already structurally prevented by P3 (A8 enforcement coupled to A2 hard-delete).

---

## §8 Self-Critique Round Closed (2026-04-18)

All findings from the P/R/M/SRE self-critique round resolved:

- **Major findings**: R1, P4, S1, M2+R4, M5 — all resolved with substantive design refinements.
- **Minor findings**: M1, M3, M4, P3, R5, P1, P2 — resolved via clarifications or absorbed by major refinements.
- **Follow-up observations**: O1, O2, O3 — all resolved, with O2 extending lens coverage and O3 adding a new Phase 11b for diagnostic infrastructure.
- **Confirmations**: R2, R3 — no action required.

**Structural insights surfaced by the critique round**:

1. **Tier 1/2/3 lattice architecture** (from R1+P4) separates lattice-type classification from merge-function implementation from cell-instance inheritance. `#:domain` keyword for override. Aligns with NTT `impl Lattice L` directly.
2. **Two Hasse-registry instances are structurally identical** (from O2) — impl coherence (Phase 7) and inhabitant catalog (Phase 9b) both PUnify-with-`'subtype` over Hasse-indexed entries; §6.12 primitive abstracts the identity.
3. **Tagged-cell-value layer lattice is the structural generalization of Module Theory Realization B** (from O2) — every "shared-carrier + tags" application in 4C (`:type`/`:term`, `:constraints` by trait, worldview by assumption, attribute-map by position) is one instance.
4. **Provenance is structurally emergent** (from O3) — the propagator-firing dependency graph IS the proof object; no new data structure needed. Error-reporting via backward residuation (Module-Theory-principled).
5. **PUnify's reach covers all D.2 claims** (from M2+R4) — audit of unify.rkt confirmed variance (via `'subtype` relation), union operands, tensor, metas, flex-app all already supported. Net-new PUnify work: ~150-200 lines of composition wiring.
6. **Production migration scope is 10× smaller than D.2 original implied** (from R1) — 101 production call sites, 37 merge functions, not 666 cells.

**D.2 is ready for external critique round** per CRITIQUE_METHODOLOGY §"Integration with Design Methodology" — D.3+ via external critique.

**Proposed order of discussion**:
1. R1 + P4 together — scope decision.
2. S1 — missing bridge, architectural.
3. M2 + R4 — PUnify reach.
4. M5 — residuation timing.
5. O2, O3 — lens/provenance depth.
6. Minor findings (M1, M3, M4, P1, P2, P3, R5) — batch.

User to decide incorporation; D.3 written per decisions.
