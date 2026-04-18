# PPN Track 4C — D.2 → External Critique Handoff

**Date**: 2026-04-18
**Purpose**: Carry the hard-earned context from D.1 → D.2 self-critique closure into the external critique round and beginning of implementation. This handoff is a *transfer of understanding*, not a summary.

**Before reading anything else**: read [`HANDOFF_PROTOCOL.org`](../principles/HANDOFF_PROTOCOL.org) carefully. It defines what a handoff is, the Hot-Load Reading Protocol (§Hot-Load Reading Protocol), and the standard of "I have full context" (having read every document in §2, being able to articulate every decision in §3, and knowing every surprise in §4). This handoff is structured per that protocol.

---

## §1 Current Work State (PRECISE)

- **Track**: PPN Track 4C — "Bring elaboration completely on-network."
- **Design version**: D.2 (self-critique round closed 2026-04-18). Ready for external critique round (D.3+).
- **Last commit**: `a9027740` — "PPN 4C D.2: self-critique round closed — all findings resolved"
- **Branch**: `main`
- **Suite state**: untouched by this session. All design work, no implementation.

### Progress Tracker status (§2 of design doc)

All 16 phases in design, no phases started:

| Phase | Status |
|---|---|
| 0 (acceptance + Pre-0 + parity) | 🔄 (Pre-0 bench + adversarial + report committed; acceptance file exists; parity skeleton TBD) |
| 1 (A8 enforcement) | ⬜ |
| 2 (A9 facet SRE registrations) | ⬜ |
| 2b (Hasse-registry primitive) | ⬜ |
| 3 (A5 `:type`/`:term` tag layers) | ⬜ |
| 4 (A2 CHAMP retirement) | ⬜ |
| 5 (A6 Warnings authority) | ⬜ |
| 6 (A3 Aspect-coverage) | ⬜ |
| 7 (A1 Parametric trait-resolution) | ⬜ |
| 8 (A4 Option A freeze) | ⬜ |
| 9 (BSP-LE 1.5 cell-based TMS) | ⬜ |
| 9b (γ hole-fill propagator) | ⬜ |
| 10 (Phase 8 union types via ATMS) | ⬜ |
| 11 (A7 Elaborator strata → BSP) | ⬜ |
| 11b (Diagnostic infrastructure) | ⬜ |
| 12 (A4 Option C cell-refs, zonk retirement) | ⬜ |
| T (dedicated test files) | ⬜ |
| V (acceptance + A/B + demo + PIR) | ⬜ |

### Next immediate task

**External critique round** per [`CRITIQUE_METHODOLOGY.org`](../principles/CRITIQUE_METHODOLOGY.org) §4 (Orientation for External Critics) + §5 (Receiving External Critique: Grounded Pushback). Produces `docs/tracking/YYYY-MM-DD_PPN_TRACK4C_EXTERNAL_CRITIQUE.md`. After external critique + response incorporation: D.3.

After external critique closes, **Stage 4 implementation begins at Phase 0** (acceptance file + Pre-0 baselines re-validated + parity skeleton).

---

## §2 Documents to Hot-Load (ORDERED)

**Critical**: the Hot-Load Reading Protocol requires reading *every* document in §2 *in full* — not sampled, not skimmed. "I have full context" is not met by seeing 40 lines.

### §2.0 Start here

0. [`HANDOFF_PROTOCOL.org`](../principles/HANDOFF_PROTOCOL.org) — THIS protocol. Read first to ground the reading discipline.

### §2.1 Always-Load (every session, per HANDOFF_PROTOCOL §2a)

1. [`CLAUDE.md`](../../../CLAUDE.md) + [`CLAUDE.local.md`](../../../CLAUDE.local.md) — project + local instructions
2. [`MEMORY.md`](../../../MEMORY.md) — auto-memory index
3. [`DESIGN_METHODOLOGY.org`](../principles/DESIGN_METHODOLOGY.org) — 5 stages, critique cycle, Implementation Protocol, WS-Mode Validation Protocol, Lazy evaluation discipline from M5
4. [`DESIGN_PRINCIPLES.org`](../principles/DESIGN_PRINCIPLES.org) — ten load-bearing principles + Hyperlattice Conjecture
5. [`CRITIQUE_METHODOLOGY.org`](../principles/CRITIQUE_METHODOLOGY.org) — three lenses (P/R/M) + SRE lattice lens; **load-bearing for the external critique round**

### §2.2 Architectural Rules (every session — automatically loaded via `.claude/rules/` but MUST be internalized, not just present)

6. [`.claude/rules/propagator-design.md`](../../../.claude/rules/propagator-design.md) — fire-once, broadcast, `#:component-paths` (MANDATORY per this doc — also NTT refinement note persisted 2026-04-17)
7. [`.claude/rules/on-network.md`](../../../.claude/rules/on-network.md) — the self-hosting mandate. **The Design Mantra lives here.**
8. [`.claude/rules/structural-thinking.md`](../../../.claude/rules/structural-thinking.md) — SRE 6 questions + **Module Theory § Direct Sum Has Two Realizations** (load-bearing for D.2's Realization B everywhere)
9. [`.claude/rules/testing.md`](../../../.claude/rules/testing.md) — diagnostic protocol; **TRIGGER-level intervention** when failures appear
10. [`.claude/rules/pipeline.md`](../../../.claude/rules/pipeline.md) — exhaustiveness checklists; **Two-Context Audit**
11. [`.claude/rules/stratification.md`](../../../.claude/rules/stratification.md) — the stratum infrastructure; A7 elaborator-strata→BSP consolidation rests on this
12. [`.claude/rules/prologos-syntax.md`](../../../.claude/rules/prologos-syntax.md) — WS syntax conventions
13. [`.claude/rules/workflow.md`](../../../.claude/rules/workflow.md) — operational discipline (phase completion, commit discipline, etc.)

### §2.3 Session-Specific — the D.2 design artifact and its critique (READ IN FULL)

These are the primary design artifacts. The external critic must see the full design; the self-critique shows what we've already considered.

14. [`docs/tracking/2026-04-17_PPN_TRACK4C_DESIGN.md`](../2026-04-17_PPN_TRACK4C_DESIGN.md) — **THE D.2 design. Read in full.** 16 sections including the Progress Tracker (§2), Mantra Audit (§3), NTT Speculative Model (§4), Correspondence Table (§5), Architecture Details §6.1 through §6.13, Termination (§7), Principles Challenge (§8), Parity Skeleton (§9), Pre-0 Results (§10), Acceptance File (§11), Dependencies (§12), Open Questions (§13), What's Next (§14), Observations (§15).

15. [`docs/tracking/2026-04-17_PPN_TRACK4C_SELF_CRITIQUE.md`](../2026-04-17_PPN_TRACK4C_SELF_CRITIQUE.md) — **Self-critique round, CLOSED 2026-04-18.** §8 has the round summary with six structural insights. Every resolved finding documents WHY it was resolved that way — don't re-open closed questions without understanding the reasoning.

16. [`docs/tracking/2026-04-17_PPN_TRACK4C_AUDIT.md`](../2026-04-17_PPN_TRACK4C_AUDIT.md) — Stage 2 audit. Grep-backed code measurements that shaped the design scope.

17. [`docs/tracking/2026-04-17_PPN_TRACK4C_PRE0_REPORT.md`](../2026-04-17_PPN_TRACK4C_PRE0_REPORT.md) — Pre-0 benchmark + adversarial findings. Three standout data points (1400× that-read speedup, 343 MB E2 parametric allocation, speculation cheapness) shaped design decisions.

### §2.4 Session-Specific — the prior PPN lineage

18. [`docs/tracking/2026-03-26_PPN_MASTER.md`](../2026-03-26_PPN_MASTER.md) — series tracker. §4 has the 7 cross-cutting lessons from BSP-LE 2B that inform 4C.

19. [`docs/research/2026-04-07_PPN_TRACK4C_DESIGN_NOTE.md`](../../research/2026-04-07_PPN_TRACK4C_DESIGN_NOTE.md) — the 6-bridge design note that kicked off 4C.

20. [`docs/tracking/2026-04-04_PPN_TRACK4_PIR.md`](../2026-04-04_PPN_TRACK4_PIR.md) — Track 4 PIR. **§3.4b** on zonk retirement (the unmet expectation now owned by 4C Phase 12).

21. [`docs/tracking/2026-04-07_PPN_TRACK4B_PIR.md`](../2026-04-07_PPN_TRACK4B_PIR.md) — Track 4B PIR. §12 notes zonk retirement still deferred; §1 reframes "side effects ARE attributes."

22. [`docs/tracking/2026-04-16_BSP_LE_TRACK2B_PIR.md`](../2026-04-16_BSP_LE_TRACK2B_PIR.md) — BSP-LE 2B PIR. §16.4 Module Theory Resolution B; §16.5 skip-the-mechanism lesson; §16.8 per-variable split entries lesson.

### §2.5 Session-Specific — research docs that shaped D.2

These are the research foundations. D.2's architectural choices cite them directly.

23. [`docs/research/2026-03-28_MODULE_THEORY_LATTICES.md`](../../research/2026-03-28_MODULE_THEORY_LATTICES.md) — **Critical for O3 provenance resolution.** Propagator networks as quantale modules; §5 residuation; §6 e-graph quotient structure.

24. [`docs/research/2026-03-24_HYPERGRAPH_REWRITING_PROPAGATOR_PARSING.md`](../../research/2026-03-24_HYPERGRAPH_REWRITING_PROPAGATOR_PARSING.md) — **Critical for O3.** §6.3: "dependency graph IS a proof object"; Engelfriet-Heyker equivalence.

25. [`docs/research/2026-04-03_ADHESIVE_CATEGORIES_PARSE_TREES.md`](../../research/2026-04-03_ADHESIVE_CATEGORIES_PARSE_TREES.md) — parse trees as presheaf objects; DPO adhesive guarantees; critical-pair completeness (impl coherence via this mechanism).

26. [`docs/research/2026-04-05_ATTRIBUTE_GRAMMARS_RESEARCH.md`](../../research/2026-04-05_ATTRIBUTE_GRAMMARS_RESEARCH.md) — catamorphisms; Silver aspect-orientation; circular attribute grammars = propagator fixpoint.

27. [`docs/research/2026-04-05_PROLOGOS_ATTRIBUTE_GRAMMAR.md`](../../research/2026-04-05_PROLOGOS_ATTRIBUTE_GRAMMAR.md) — the 5-facet attribute record formalization; attribute flow semantics.

28. [`docs/tracking/2026-03-22_NTT_SYNTAX_DESIGN.md`](../2026-03-22_NTT_SYNTAX_DESIGN.md) — **NTT guiderails.** §3.1-3.2 lattice/type declarations match Tier 1; §4 propagator form; §6 bridges; §7 stratification; §7.6 `:trace` modes (provenance infrastructure for Phase 11b); §5 interface (egress convention).

29. [`docs/research/2026-04-08_HYPERCUBE_BSP_LE_DESIGN_ADDENDUM.md`](../../research/2026-04-08_HYPERCUBE_BSP_LE_DESIGN_ADDENDUM.md) — worldview lattice as Q_n hypercube; Gray-code traversal, subcube pruning, hypercube all-reduce.

30. [`docs/research/2026-04-06_CELL_BASED_TMS_DESIGN_NOTE.md`](../../research/2026-04-06_CELL_BASED_TMS_DESIGN_NOTE.md) — BSP-LE 1.5 design note; 4C Phase 9 substrate for Phase 10 union types.

31. [`docs/research/2026-03-26_GRAMMAR_TOPLEVEL_FORM.md`](../../research/2026-03-26_GRAMMAR_TOPLEVEL_FORM.md) — the `grammar` form + `that` vision. 4C provides the infrastructure; Track 7 lifts this to user surface.

32. [`docs/research/2026-03-30_SEXP_IR_TO_PROPAGATOR_COMPILER.md`](../../research/2026-03-30_SEXP_IR_TO_PROPAGATOR_COMPILER.md) — self-hosting trajectory. PPN Track 4 (including 4C) is the threshold of Phase 1 self-hosting.

### §2.6 Session-Specific — infrastructure artifacts

33. [`racket/prologos/benchmarks/micro/bench-ppn-track4c.rkt`](../../../racket/prologos/benchmarks/micro/bench-ppn-track4c.rkt) — Pre-0 bench file. M/A/E/V tiers with wall-clock + memory.

34. [`racket/prologos/examples/2026-04-17-ppn-track4c-adversarial.prologos`](../../../racket/prologos/examples/2026-04-17-ppn-track4c-adversarial.prologos) — adversarial testing per semantic axis.

### §2.7 BSP-LE Master (for Track 6 forward reference)

35. [`docs/tracking/2026-03-21_BSP_LE_MASTER.md`](../2026-03-21_BSP_LE_MASTER.md) — contains Track 6-future "General Residual Solver" entry added during D.2 dialogue.

---

## §3 Key Design Decisions (RATIONALE — do NOT re-litigate)

These are decisions the self-critique round has already closed. Revisiting them wastes the work that settled them. If a future session has a genuine reason to re-open, document the reason explicitly.

### §3.1 Thesis

**"Bring elaboration completely on-network. Mantra = north star. Principles = filter. NTT = guiderails. Solver infrastructure (BSP-LE 2+2B) = substrate."** (Per user direction 2026-04-17.)

*What was rejected*: framing NTT-conformance as the thesis (NTT is verification, not goal). Framing parametric resolution or CHAMP retirement as the thesis (those are axes, not the thesis).

### §3.2 The 9 Axes (not the 6 bridges from the design note)

D.1 reframed the "6 bridges" into 9 axes plus 3 structural items (A7, A8, A9). The reframe surfaced that the bridges aren't imperative debt but *misplaced attribute writes + duplicate stores + conflated facets*. See §2 Axis table in [design §2](../2026-04-17_PPN_TRACK4C_DESIGN.md).

### §3.3 `:type` / `:term` as tag-layers on shared TypeFacet carrier (D.2 restructure)

*Decision*: Module Theory Realization B applied here. NOT two separate facets with a `TermInhabitsType` bridge.

*Rationale*: MLTT foundation — no type/term lattice distinction; "type" and "term" are layers at adjacent universe levels. Duplicate Expr storage under D.1 was the scent. Cells are instances of a lattice, not lattices themselves; `:lattice` annotation on cells was conceptually wrong (user insight 2026-04-17).

*What was rejected*: two separate facets (D.1); shape heuristic for `:lattice` (Q4 Option A); explicit `:lattice` annotation at every cell creation site (Q4 Option B original formulation, 666 sites).

*See*: §6.1 (tag-layer scheme), §6.2 (residuation internal to quantale), §6.2.1 (γ hole-fill mantra-reframed), §6.8 (Tier 1/2/3 architecture), §13 Q1 + Q4 CLOSED.

### §3.4 Tier 1 / 2 / 3 lattice architecture

*Decision*: classification belongs to the *lattice type* (Tier 1, SRE-domain-registered), implemented by *merge functions* (Tier 2, `register-merge-fn!/lattice` linking merge to domain), *inherited by cells* (Tier 3). Override via `#:domain DomainName` keyword taking a named registered domain.

*Rationale*: Per NTT `impl Lattice L` with `join fn` syntax directly. Cells are instances, not lattices. Migration scope: 37 merge functions, not 666 cell sites (grep-confirmed; production-only figure).

*What was rejected*: D.1's cell-level `:lattice` annotation (user insight: "a cell is not a lattice"); shape heuristic for structural detection; Q4 Option A (per-site annotation); Q4 Option C (SRE-registration-as-sole-detection) without Tier 2 linking.

*See*: §6.8, §13 Q4 CLOSED.

### §3.5 Zonk retirement ENTIRELY in scope (via Option C Phase 12)

*Decision*: `zonk-intermediate`, `zonk-final`, `zonk-level` deleted. `expr-meta` replaced by `expr-cell-ref`. Reading the expression IS zonking.

*Rationale*: Original [Track 4 Design §3.4b](../2026-04-04_PPN_TRACK4_DESIGN.md) commitment unmet in 4B. User direction: PPN 4 is not complete until zonk is retired. Option A (tree walk on `:term` facet) is a staging scaffold retired in Phase 12.

*What was rejected*: Option A alone (scaffold, not target); deferring Option C to SRE Track 6.

*See*: §1 Scope, §6.6, §2 Phase 12.

### §3.6 Union types via ATMS + cell-based TMS (Phases 9 + 10)

*Decision*: BSP-LE 1.5 cell-based TMS is inline as 4C Phase 9. Union types via ATMS branching (Phase 10). Phase 8 (Option A) → Phase 9 → Phase 9b → Phase 10 → Phase 11 → 11b → 12.

*Rationale*: Per user direction: "this is why we went to BSP-LE" — union types are the reason BSP-LE 2+2B was built. Cell-based TMS is prerequisite.

### §3.7 Per-(meta, trait) propagators + Hasse-indexed registry + PUnify for parametric trait resolution (Phase 7 / A1)

*Decision*: module-theoretic decomposition of `:constraints` by trait tag; per-(meta, trait) propagator; Hasse-indexed impl registry (O(log N) lookup); PUnify via SRE ctor-desc; ATMS branching on multi-candidate; set-latch fan-in per meta for dict aggregation.

*Rationale*: Rebuilt-for-efficiency per user direction, not retrofit. E2 Pre-0 baseline (343 MB allocation) motivates.

*What was rejected*: single stratum handler (off-network wonky — user-caught); per-meta propagator (internal `for/fold` = step-think); imperative algorithm wrapped as propagator.

*See*: §6.5, §13 Q6 CLOSED.

### §3.8 Lazy residuation check (synchronous-within-merge, re-fired on narrowing)

*Decision*: cross-tag CLASSIFIER × INHABITANT merge fires check when `cross-tag-present AND (CLASSIFIER-narrowed OR INHABITANT-narrowed)`. Executes synchronously within the merge function. Option 4 (separate propagator for the check) dismissed.

*Rationale*: Naive lazy-cache-and-skip would miss narrowing re-check (subtle case). Synchronous-in-merge avoids timing windows with unverified cross-tag state. BSP/CALM/ATMS compatible.

*Verification deferred to Phase 3*: parity tests (Phase 0) + property inference (Phase 2) + A/B micro-bench (Phase 3). Threshold for decision: if eager overhead <5% adopt eager; if ≥10% keep lazy.

*See*: §6.2, §13 M5 RESOLVED.

### §3.9 Hasse-registry as first-class primitive (§6.12, new Phase 2b)

*Decision*: one `hasse-registry` primitive, parameterized by lattice L. Used by Phase 7 (impl registry) + Phase 9b (inhabitant catalog). Future consumers: General Residual Solver (BSP-LE Track 6), PPN 5, FL-Narrowing.

*Rationale*: User observation 2026-04-17 — "virtually every track will be designing for its own Hasse diagram." Compositional reuse.

*What was rejected*: building two separate ad-hoc Hasse lookups (impl + catalog) without primitive extraction.

### §3.10 Provenance as structural emergence (O3)

*Decision*: provenance chain is structurally emergent from the propagator-firing dependency graph — NOT a new data structure. Three sources compose: ATMS assumption tagging (Phase 9), `:trace :structural` mode (NTT §7.6), source-location registry (Phase 4 R5). Error-reporting via backward residuation on the Module-Theoretic chain (Phase 11b).

*Rationale*: [Module Theory §5-6](../../research/2026-03-28_MODULE_THEORY_LATTICES.md) + [Hypergraph Rewriting §6.3](../../research/2026-03-24_HYPERGRAPH_REWRITING_PROPAGATOR_PARSING.md). "Dependency graph IS a proof object."

*Use case* (per user direction 2026-04-18): first-class compiler and error features, not debugging aid. Precise source-code mapping, human-readable error messages, machine-readable traces for IDE/LSP, residuation-backward error explanation.

*See*: §6.1.1, Phase 11b.

### §3.11 PUnify's existing infrastructure covers all D.2 claims (M2+R4 audit)

*Decision*: no new PUnify algorithm needed. Variance via `'subtype` relation (already first-class), union via `unify-union-components`, tensor via `type-tensor-core`, metas via `current-structural-meta-lookup`, flex-app via `decompose-meta-app`. Net-new work: ~150-200 lines of composition wiring.

*See*: §6.13 PUnify audit.

### §3.12 General Residual Solver scoped to future BSP-LE Track 6

*Decision*: extracted as future track (BSP-LE series). Audit 2026-04-17 confirmed BSP-LE's low-level search machinery is relation-with-atoms coupled. Generalization is its own effort.

*What 4C consumes*: the HIGH-LEVEL substrate (BSP, stratification, ATMS, worldview). NOT the full relational solver.

*See*: §6.11.7 + BSP-LE Master Track 6-future.

---

## §4 Surprises and Non-Obvious Findings

These are what took significant dialogue to resolve. Highest-risk for a future session to get wrong.

### §4.1 "Cell is not a lattice" — the conceptual gotcha

D.1 originally had `:lattice :structural` annotation on cells. User flagged this as conceptually wrong — a cell is an *instance* of a lattice, not itself a lattice. This drove the Tier 1/2/3 refactor.

**Lesson for future sessions**: when naming things in the design, carefully distinguish between:
- The lattice (type / algebraic structure)
- The merge function (implementation)
- The cell (instance holding a value)

Don't conflate. `#:domain` override reads "this cell is in this domain" (correct); `:lattice 'structural` reads "this cell IS a structural lattice" (wrong).

### §4.2 "Walks" keeps sneaking in

D.1 described γ as "walks type-env + ctor-desc catalogue" — step-think that slipped past review. User caught it. D.2 reframed.

Then M1 in self-critique found "walks the Hasse diagram" in §6.5 and §6.12 — step-think slipped in AGAIN during the §6.5 rewrite.

**Lesson**: every occurrence of "walk", "scan", "iterate", "traverse", "for each" is a process smell. Audit wording deliberately. The SRE lens's structural framing is a discipline: replace step-think with index navigation.

### §4.3 666 → 101 rescope (R1)

D.2 original claimed 666 `net-new-cell` call sites to migrate. Grep found that's total across all files (production + tests + benchmarks + pnet cache). Production scope: 101 call sites using 37 merge functions. Top 10 merge functions cover 70% of production.

**Lesson**: when quantifying migration scope, grep production-only. Tests and benchmarks follow structurally once production merge functions are registered.

### §4.4 PUnify reach is MORE complete than D.2 assumed

M2 audit: `unify-core` + `'subtype` relation + `sre-structural-classify` + `type-tensor-core` + `unify-union-components` already cover everything D.2 claims. Variance is first-class via relation name — `'equality` strict, `'subtype` variance. No new algorithm needed.

**Lesson for external critique**: the existing infrastructure is richer than D.1 appeared to assume. External critics might suggest "build a pattern matcher for types" — respond with "existing PUnify via SRE ctor-desc handles it; see §6.13 audit."

### §4.5 Impl coherence and inhabitant catalog are structurally identical

O2 surfaced: both are Hasse-registry instances differing only in parameterization. §6.12 primitive abstracts the identity.

**Lesson**: the compositional win came from applying the lens systematically. If the lens hadn't been applied uniformly, these would be implemented as two ad-hoc mechanisms diverging over time.

### §4.6 Tagged-cell-value layers are the structural generalization of Module Theory Realization B

O2 also surfaced: every "shared-carrier + tags" situation in 4C is one instance of a single lattice structure. `:type`/`:term`, `:constraints` by trait, worldview by assumption, attribute-map by position — all one pattern.

**Lesson**: when the same lattice pattern appears in multiple places, it's the *structural* generalization worth naming. See §6.11.8 for the explicit statement.

### §4.7 Module Theory had the answer for provenance

O3 was initially framed as "how do we represent the provenance chain?" User pointed at Module Theory research. Answer: provenance IS the network topology (per hypergraph §6.3, Module Theory §5-6). "Dependency graph IS a proof object." No new data structure needed.

**Lesson**: when a design problem surfaces, check existing research before inventing new data structures. The hard work may already be done.

### §4.8 The elaborator is already partially BSP-integrated

`elaborator-network.rkt:1058` already uses `register-stratum-handler!` for `elaborator-topology-cell-id`. A7 (elaborator-strata → BSP) extends this pattern from topology to value-tier stratum handlers (S(-1) retraction, S1 readiness, S2 commit).

**Lesson**: don't assume a consolidation requires building from zero. Audit the existing infrastructure first — the pattern may already be partially in place.

### §4.9 `that-read` is ~1400× faster than CHAMP reads

Pre-0 finding. CHAMP retirement (A2) is therefore a hot-path win, not a neutral migration. Shaped the design's confidence in the A2 axis.

### §4.10 Residuation check lazy trigger needs NARROWING detection

M5: naive lazy ("fire once per cross-tag record") misses the case where CLASSIFIER narrows AFTER the initial check fired. Previously-compatible INHABITANT may no longer inhabit. Trigger must include narrowing detection, not just "new cross-tag."

**Lesson**: "lazy" in a monotone lattice isn't "cache and skip" — it's "skip when unchanged, re-fire when narrowed." Monotone narrowing IS a signal.

---

## §5 Open Questions and Deferred Work

### §5.1 For external critique

All D.1 open questions were resolved through dialogue + D.2 refinement. The D.2 self-critique round surfaced findings, all resolved. The external critique round opens space for NEW findings. Areas most likely to surface critique:

- **Tier 1/2/3 split** — is this the right abstraction, or is it splitting too fine?
- **Tag-layer lattice generalization** — does treating `:type`/`:term`, `:constraints`, worldview, attribute-map all as instances of one lattice actually simplify things, or obscure differences?
- **Option C cell-refs** — 14-file pipeline impact in Phase 12. Feasibility check.
- **Phase dependency graph** — are the inter-phase dependencies right? Can any parallelize?
- **Hasse-registry primitive** — does §6.12's parameterization adequately cover impl-registry AND inhabitant-catalog use cases?
- **Residuation check lazy vs eager** — the verification plan defers this; external critic may push one way or the other.
- **Phase 11b diagnostic scope** — is error-reporting infrastructure really 4C, or should it be a follow-on track?
- **Step-think audit** — external critics well-versed in propagators may catch remaining step-think slips.

### §5.2 Phase-time mini-design deferrals

Per user direction during D.2: certain design details are deferred to phase-time mini-design:
- Q2 multi-source-evaluator pattern details (Phase 7 + 9b)
- Q6 parametric resolution scaling specifics (Phase 7)
- `register-merge-fn!/lattice` API shape (Phase 1)
- `derivation-chain-for(position, tag)` helper API shape (Phase 11b)
- Whether to adopt lazy or eager residuation check (Phase 3 A/B bench)
- Whether SRE ctor-desc auto-derivation simplifies typing-rule registration (Phase 6)

### §5.3 Verifications required during implementation

- Phase 2 A9: property inference on 5 facet lattices + tag-dispatched merge. Expected: find ≥1 lattice bug (per Track 3 §12 + SRE 2G precedent).
- Phase 2 A9 audit: ConstraintsToWarnings potential bridge (S1 follow-up). Verify whether any soft-diagnostic flow exists.
- Phase 3: residuation check A/B bench (lazy vs eager).
- Phase 5 (A3) sub-audit: exact AST-kind coverage gap. 75 unregistered is upper bound; actual may be smaller via group dispatch.
- Phase 7 (A1) sub-audit: impl registry size to confirm Hasse-index scaling is sufficient.

### §5.4 DEFERRED.md not updated

The handoff session didn't add entries to `docs/tracking/DEFERRED.md`. Future session should scan for anything that belongs there.

---

## §6 Process Notes — Discipline Established in This Session

### §6.1 Lens discipline

Every design decision filtered through:
- **Design Mantra** (on-network.md) as primary filter — step-think check at every decision
- **SRE Lattice Lens** (6 questions) for every lattice
- **Module Theory** for every direct-sum / decomposition choice
- **PUnify** for every pattern-matching / subsumption / unification claim
- **Hasse diagram** for every structural-navigation claim

Uniform application catches things per-decision scrutiny misses (see §4.5, §4.6).

### §6.2 Progress Tracker near top

Per user direction 2026-04-17: design docs put Progress Tracker near the top (§2), not at the back. Makes the shape of the work visible immediately.

### §6.3 "Stage X" not in artifact names

Per user direction: artifact names don't leak process-stage language. `_AUDIT` and `_DESIGN` and `_PIR` are content-descriptive and OK. `_STAGE2_AUDIT` is process-stage leakage and was renamed to `_AUDIT`.

### §6.4 Correctness over pragmatism

User direction during Q4/R1: when correctness and pragmatism tension, choose correctness. The Tier 1/2/3 architecture is correct-by-construction; D.2's original `:lattice` approach was pragmatic but conflated concepts.

### §6.5 Check research before inventing

O3 is the canonical example: instead of inventing a new provenance data structure, user pointed at research; Module Theory + Hypergraph Rewriting had the answer already. **Always check research docs before inventing.**

### §6.6 Grep-backed scope measurements

R1: "666 sites" feels overwhelming; grep breakdown revealed production is 101. Same discipline applies everywhere — measure before scoping.

### §6.7 Don't ask questions the project answers

User direction 2026-04-17: "Every question that needs answering costs human development time." Before asking a design question, verify it isn't already answered by methodology/principles/rules/research.

---

## §7 What the External Critique Round Should Produce

Per [CRITIQUE_METHODOLOGY.org](../principles/CRITIQUE_METHODOLOGY.org) §4 (Orientation for External Critics) and §5 (Receiving External Critique: Grounded Pushback):

### §7.1 Critic orientation (§4)

The briefing for external critics from CRITIQUE_METHODOLOGY §4:

> Prologos designs are evaluated from a propagator-mindspace. The system's computational model is monotone information flow on a propagator network — not sequential algorithmic steps. When reviewing:
> - Do NOT suggest solutions that involve "first do X, then do Y." Instead, suggest what information flows where, through which cells.
> - Do NOT suggest scanning/iterating data structures. Instead, suggest which propagators watch which cells and fire when information arrives.
> - Sequential ordering should EMERGE from dataflow dependencies, not be imposed by design.
> - Every component should be traceable as: cell creation → propagator installation → cell writes → cell reads = result.
> - If a component can't be traced this way, it should be explicitly labeled as scaffolding with a retirement plan.
> - The ten design principles (especially Propagator-First, Data Orientation, and Correct-by-Construction) are the evaluation criteria, not algorithmic efficiency or implementation convenience.

### §7.2 Response format (§5)

For each external critique finding:

- **Accept**: finding correct AND resolution aligns with principles. Incorporate.
- **Accept problem, reject solution**: problem real, solution algorithmic/off-network/principle-violating. State why, propose alternative.
- **Reject with justification**: premise doesn't hold in our codebase, or conflicts with load-bearing principle. Cite specific principle + code.
- **Defer with tracking**: valid but out of scope. Add to DEFERRED.md.

Never accept without evaluation. Never reject without citing principle/code.

### §7.3 Output artifact

`docs/tracking/YYYY-MM-DD_PPN_TRACK4C_EXTERNAL_CRITIQUE.md` — external critique findings + our responses. Linked from design doc header. Drives D.3.

### §7.4 After external critique converges

- D.3 written
- Parity skeleton `test-elaboration-parity.rkt` committed (Phase 0)
- Pre-0 re-validation if needed
- Phase 0 proper: acceptance file + parity + Pre-0 baselines
- Then Phase 1 implementation begins

---

## §8 Final Notes

### §8.1 What "I have full context" requires (per HANDOFF_PROTOCOL §Hot-Load Reading Protocol)

- Having read EVERY document in §2 in full, not sampled.
- Being able to articulate EVERY decision in §3 with its rationale.
- Knowing EVERY surprise in §4.

If any is unclear, ASK before proceeding. "I think I understand the design" is not sufficient for an external-critique response. "I understand why Tier 1/2/3 is the architecture, specifically because cells are instances not lattices and merge functions implement lattices" is.

### §8.2 The session was long

This session covered:
- Stage 2 audit
- D.1 draft
- D.2 restructure (lens application, `:type`/`:term` tag layers, Hasse-registry extraction)
- Pre-0 benchmarking + adversarial testing
- Self-critique round (16 findings, all resolved)

Much hard-earned context. The handoff's job is to not lose it.

### §8.3 Commits in this session (chronological)

From `ff5619ec` (kickoff briefing committed) through `a9027740` (self-critique closed). 30+ commits. `git log --oneline --since 2026-04-17` shows the full span.

### §8.4 Gratitude

This design has been shaped by careful, principled dialogue. The user's pushbacks (on thesis, on conflations, on step-think, on correctness-over-pragmatism) are WHY the design is as good as it is. Future sessions should honor that care.
