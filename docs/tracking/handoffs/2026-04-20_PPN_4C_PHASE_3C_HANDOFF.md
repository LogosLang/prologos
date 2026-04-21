# PPN Track 4C — Phase 3c Pre-Implementation Handoff

**Date**: 2026-04-20
**Purpose**: Transfer context from this session (Phase 1e close → Phase 1f → Phase 1V → Phase 3 mini-design → Phase 3a+3b implementation → Phase 3c mini-design) into a continuation session. Phase 3c design is fully worked through; implementation is the next session's focus.

**Before reading anything else**: read [`HANDOFF_PROTOCOL.org`](../principles/HANDOFF_PROTOCOL.org). This handoff is structured per that protocol. The Hot-Load Reading Protocol requires reading EVERY §2 document IN FULL before summarizing understanding back to the user.

---

## §1 Current Work State (PRECISE)

- **Track**: PPN Track 4C — "Bring elaboration completely on-network"
- **Design version**: **D.3** (external critique closed 2026-04-18; extensive mini-design work added 2026-04-19 and 2026-04-20)
- **Last commit**: `cd0918cd` — "PPN 4C Phase 3c sub-design: PUnify+SRE+Module-Theory lens refines propagator to ~30-50 LoC"
- **Branch**: `main`
- **Suite state**: 6022 affected-tests GREEN at 107s (last full run: after Phase 1f at commit `25b421fe`; Phase 3a+3b added 19 new tests in `test-classify-inhabit.rkt`, all passing)
- **Lint state**: 82 registered / 5 unregistered (4 unique) / 0 inline-lambda / 5 parameterized-passthrough / 1 domain-override / 11 multi-line. `--strict` exits 0.

### Progress Tracker status (D.3 §2)

| Phase | Status | Notes |
|---|---|---|
| 0 | ✅ | Acceptance + Pre-0 + parity skeleton |
| 1a | ✅ | `tools/lint-cells.rkt` + baseline (`eb4b7bd8`) |
| 1b | ✅ | `merge-fn-registry.rkt` Tier 2 API (`f990ddd7`) |
| 1c | ✅ | `#:domain` kwarg + Tier 3 inheritance (`827637c2`) |
| 1.5 | ✅ | srcloc infrastructure (`793e106d`) |
| 2 | ✅ | 4 facet SRE registrations (`1423259d`) |
| 2b | ✅ | Hasse-registry primitive (`c669db51`) |
| 1d | ✅ | Registration campaign through close (`f4d5526a`) |
| 1e | ✅ | η split + meta-solve identity + atms classification + clock primitive (`18204fc6`) |
| **1f** | ✅ | **Structural enforcement at net-add-propagator** (`25b421fe`) |
| **1V** | ✅ | **Vision Alignment Gate — Phase 1 COMPLETE** (`73a6e48e`) |
| **3** | 🔄 | **Phase 3a+3b ✅** (`98f503a2`) classify-inhabit.rkt infrastructure. **Phase 3c mini-design COMPLETE** (`cd0918cd`). Phase 3c implementation is the next session's work. |
| 4-12, 11b, T, V | ⬜ | Unchanged |

### Next immediate task

**Phase 3c implementation** per D.3 §6.15.8 sub-phase partition:

- **3c-i** (~30-50 LoC): reshape `:type` facet value to `classify-inhabit-value`; add reader shim (`:type` auto-unwraps classifier layer; `:term` magic keyword routes to inhabitant layer). 5 facets preserved (no new facet in AttributeRecord; `:term` is a user-surface alias).
- **3c-ii** (~50-100 LoC): per-rule writer migration in typing-propagators.rkt. Type-variable meta classifier writes → CLASSIFIER; literal/value writes → INHABITANT.
- **3c-iii** (~30-50 LoC): cross-tag residuation propagator via PUnify reuse. Fire function: `unify-core classifier (type-of-expr inhabitant) 'subtype`; dispatch on outcome (compatible / narrowing / contradiction). Narrowing emits stratum request per P4(b).
- **3c-iv** (deferred): α-equivalence refinement via ctor-desc.
- **3c-close**: tests + tracker update.

Total scope: ~120-200 LoC across 3 commits.

---

## §2 Documents to Hot-Load (ORDERED)

**CRITICAL**: the Hot-Load Reading Protocol requires reading EVERY document IN FULL. Sampling is not acceptable. Ask before proceeding if anything is unclear.

### §2.0 Start here

0. [`HANDOFF_PROTOCOL.org`](../principles/HANDOFF_PROTOCOL.org) — THIS protocol. Ground the reading discipline.

### §2.1 Always-Load (every session)

1. [`CLAUDE.md`](../../../CLAUDE.md) + [`CLAUDE.local.md`](../../../CLAUDE.local.md) — project + local instructions
2. [`MEMORY.md`](../../../MEMORY.md) — auto-memory index
3. [`DESIGN_METHODOLOGY.org`](../principles/DESIGN_METHODOLOGY.org) — Stage 4 Implementation Protocol steps 1-6. Mini-design audit is step 1 (codified 2026-04-19 at `3beeb3ae`).
4. [`DESIGN_PRINCIPLES.org`](../principles/DESIGN_PRINCIPLES.org) — 10 principles + Hyperlattice Conjecture
5. [`CRITIQUE_METHODOLOGY.org`](../principles/CRITIQUE_METHODOLOGY.org) — P/R/M lenses + SRE lattice lens

### §2.2 Architectural Rules (MUST be internalized)

6. [`.claude/rules/on-network.md`](../../../.claude/rules/on-network.md) — THE DESIGN MANTRA
7. [`.claude/rules/structural-thinking.md`](../../../.claude/rules/structural-thinking.md) — SRE 6 questions + Module Theory Realization B (CRITICAL for Phase 3)
8. [`.claude/rules/propagator-design.md`](../../../.claude/rules/propagator-design.md) — fire-once, broadcast, component-indexing, worldview bitmask
9. [`.claude/rules/workflow.md`](../../../.claude/rules/workflow.md) — operational discipline
10. [`.claude/rules/testing.md`](../../../.claude/rules/testing.md) — diagnostic protocol
11. [`.claude/rules/pipeline.md`](../../../.claude/rules/pipeline.md) — exhaustiveness checklists (CRITICAL: Phase 3 reshapes `:type` facet value — pipeline-wide impact)
12. [`.claude/rules/stratification.md`](../../../.claude/rules/stratification.md) — stratum infrastructure (CRITICAL for P4(b) stratum request mechanism)
13. [`.claude/rules/prologos-syntax.md`](../../../.claude/rules/prologos-syntax.md) — WS syntax conventions

### §2.3 Session-Specific — THE D.3 DESIGN (READ IN FULL)

14. [`docs/tracking/2026-04-17_PPN_TRACK4C_DESIGN.md`](../2026-04-17_PPN_TRACK4C_DESIGN.md) — **THE D.3 design. READ IN FULL.** Key sections updated THIS session:
    - §2 Progress Tracker (rows 1f ✅, 1V ✅, 3 🔄 with 3a+3b ✅, 4 with per-meta-cell mini-design, 9 with Phase 3+9 joint mini-design)
    - **§6.14** — Phase 1e correctness refactors (full design + sub-phase partition)
    - **§6.15** — **Phase 3 mini-design** (dialogue resolutions S1+P4, sub-phase partition, PU audit, Phase 9 coherence)
    - **§6.15.8** — **Phase 3c sub-design** (Q1-Q6 resolutions, PUnify+SRE+Module-Theory lens for residuation propagator)
    - **§6.15.9** — Phase 3c drift risks (VAG 5d checklist, 8 named risks)

### §2.4 Session-Specific — PRIOR HANDOFFS (context continuity)

15. [`docs/tracking/handoffs/2026-04-19_PPN_4C_PHASE_1D_MID_HANDOFF.md`](2026-04-19_PPN_4C_PHASE_1D_MID_HANDOFF.md) — Phase 1d mid-campaign handoff. Context for most of Phase 1's work.
16. [`docs/tracking/handoffs/2026-04-18_PPN_4C_D2_EXTERNAL_CRITIQUE_HANDOFF.md`](2026-04-18_PPN_4C_D2_EXTERNAL_CRITIQUE_HANDOFF.md) — D.2 external critique handoff. Design decision rationale.

### §2.5 Session-Specific — CURRENT DAILIES

17. [`docs/tracking/standups/2026-04-19_dailies.md`](../standups/2026-04-19_dailies.md) — Extensive session log spanning 2026-04-19 + 2026-04-20 content: Phase 0 closure, Stage 4 methodology codification, Phase 1 complete execution (1a-1V), Phase 1e full dialogue + execution, Phase 1f + 1V execution, Phase 3 mini-design + Phase 3a+3b execution, Phase 3c mini-design.

### §2.6 Session-Specific — CORE PHASE 3 ARTIFACTS (READ IN FULL)

18. [`racket/prologos/classify-inhabit.rkt`](../../../racket/prologos/classify-inhabit.rkt) — **Phase 3a+3b**. Tag-layer value shape + pure accumulation merge + `'classify-inhabit` SRE domain. 3c migration activates this infrastructure.

19. [`racket/prologos/tests/test-classify-inhabit.rkt`](../../../racket/prologos/tests/test-classify-inhabit.rkt) — 19/19 tests for tag-layer semantics.

### §2.7 Session-Specific — UPSTREAM CONTEXT

20. [`racket/prologos/typing-propagators.rkt`](../../../racket/prologos/typing-propagators.rkt) — **Phase 3c migration target**. Contains ~13 `that-read ... :type` sites + ~5 `that-write ... :type` sites. The `:type` facet infrastructure lives here. 3c-i reshape + 3c-ii writer migration touches this file.

21. [`racket/prologos/type-lattice.rkt`](../../../racket/prologos/type-lattice.rkt) — `type-lattice-merge` (SRE 2H quantale 'equality merge). 3c-iii residuation propagator's fire function uses `unify-core` which routes through this.

22. [`racket/prologos/unify.rkt`](../../../racket/prologos/unify.rkt) — `unify-core` with 'subtype relation is the PUnify entry point for 3c-iii. See §6.13 of D.3 for the full PUnify audit documenting what's available.

23. [`racket/prologos/elaborator-network.rkt`](../../../racket/prologos/elaborator-network.rkt) — **Phase 1e-β-i context**. `merge-meta-solve-identity` + `'meta-solve` SRE domain registered here. 3c may interact with how metas are classified (CLASSIFIER for type-variable metas).

24. [`racket/prologos/propagator.rkt`](../../../racket/prologos/propagator.rkt) — **Phase 1f enforcement infrastructure**. `enforce-component-paths!` + `current-domain-classification-lookup` callback. 3c-iii residuation propagator must declare `:component-paths` because `'classify-inhabit` is classified 'structural.

25. [`racket/prologos/sre-core.rkt`](../../../racket/prologos/sre-core.rkt) — SRE domain registration + `lookup-domain-classification` (Phase 1f). `sre-domain` struct now has `classification` field.

### §2.8 Session-Specific — PRIOR-ART REUSE FOR 3c-iii

26. [`racket/prologos/relations.rkt`](../../../racket/prologos/relations.rkt) — S1 NAF handler pattern at `process-naf-request`. **THE PATTERN PRECEDENT** for stratum-request-based cross-cell operations. 3c-iii's stratum request follows this shape.

27. [`racket/prologos/decision-cell.rkt`](../../../racket/prologos/decision-cell.rkt) — ATMS counter + topology-stratum discipline (line 609-610 comment). 3c-iii's stratum handler inherits this discipline.

### §2.9 Tracking metadata

28. [`docs/tracking/DEFERRED.md`](../DEFERRED.md) — scaffolding registry (~10 entries including Phase 1e-β-iii-a clock parameters) + PM Track 12 design input sections (32 identity-candidate sites + 5 timestamp-candidate sites).

29. [`docs/tracking/2026-03-13_PROPAGATOR_MIGRATION_MASTER.md`](../2026-03-13_PROPAGATOR_MIGRATION_MASTER.md) — PM series master. Track 12 has TWO design-input subsections now (2026-04-19 and 2026-04-20).

### §2.10 Research for context

30. [`docs/research/2026-03-28_MODULE_THEORY_LATTICES.md`](../../research/2026-03-28_MODULE_THEORY_LATTICES.md) — Module Theory lens. Phase 3's Realization B is an instance.

31. [`docs/research/2026-04-08_HYPERCUBE_BSP_LE_DESIGN_ADDENDUM.md`](../../research/2026-04-08_HYPERCUBE_BSP_LE_DESIGN_ADDENDUM.md) — Phase 9 hypercube context (deferred scope; Phase 3+9 joint mini-design item).

---

## §3 Key Design Decisions (RATIONALE — do NOT re-litigate)

Decisions this session CLOSED. Revisiting wastes the work that settled them.

### §3.1 Phase 1f structural enforcement (commit `25b421fe`)

`sre-domain` gains `classification` field ('structural | 'value | 'unclassified). Parameter-callback pattern (cycle avoidance): propagator.rkt holds `current-domain-classification-lookup`; sre-core.rkt exports `lookup-domain-classification`; infra-cell-sre-registrations.rkt wires them at load. Enforcement fires on classified-structural cells without `:component-paths`. Progressive rollout: 'hasse-registry 'structural; 'meta-solve, 'timestamped-cell 'value; all others 'unclassified. Hard error at `net-add-propagator` when enforcement triggers.

### §3.2 Phase 1V Vision Alignment Gate — Phase 1 COMPLETE (commit `73a6e48e`)

All 4 VAG questions passed (on-network, complete, vision-advancing, drift-risks-cleared). All 8 Phase 1 mini-design drift risks cleared. Honest deferrals (1e-α scope-reduction, 1e-β-iii-b snapshot-cell finding) captured for PM Track 12.

### §3.3 Phase 3 mini-design (commit `7e9cdc07`)

- **S1 resolved**: reading (i) — TermFacet IS the SRE 2H quantale. Role-tags over ONE carrier lattice. MLTT-native framing.
- **P4 resolved**: path (b) — cross-tag merge emits stratum request; merge stays pure `(v × v → v)`. Matches S1 NAF + topology stratum pattern.
- **Sub-phase partition**: 3a+3b atomic (facet infra + tag-dispatched merge), 3c migration, 3d parity + A/B, 3e Phase 1f classification to 'structural, 3V gate.
- **PU audit**: Phase 3 is PU-aligned (attribute-map already compound). Per-meta-cell consolidation deferred to Phase 4 mini-design (tracker row 4 captures 3 options α/β/γ).
- **Phase 9 coherence**: mostly orthogonal. ONE joint mini-design item: P4(b) stratum request carries worldview assumption-id for Phase 9 overlay. Captured in tracker row 9.

### §3.4 Phase 3a+3b implementation (commit `98f503a2`)

`classify-inhabit.rkt` ships tag-layer struct + pure accumulation merge + `'classify-inhabit` SRE domain (Tier 1 'structural + Tier 2 linkage). Classifier × classifier uses `type-lattice-merge`; inhabitant × inhabitant uses `equal?` as α-equiv proxy. Cross-tag residuation check deferred to 3c as dedicated propagator. 19/19 tests GREEN.

### §3.5 Phase 3c mini-design (commit `cd0918cd`)

Design settled 2026-04-20:

- **Q1 migration strategy (C)**: hybrid reshape with shim. `:type` facet's VALUE SHAPE becomes `classify-inhabit-value`. `(that-read ... :type)` auto-unwraps classifier layer; `(that-read ... :term)` routes to inhabitant layer via magic keyword dispatch. 5 facets preserved in AttributeRecord.

- **Q2 residuation propagator via PUnify reuse**: the cross-tag residuation check is a QUANTALE MEET operation per SRE lens. The propagator's fire function reduces to ~10-15 LoC via `unify-core` with `'subtype` relation + existing SRE ctor-desc. No new unification algorithm. Under Module Theory, narrowing writes are principled module endomorphism actions carried by the stratum request.

- **Q3 migration order (iii)**: reader-first migration. Shim immediately; writer migration per-rule.

- **Q4 `:term` is magic keyword**: no new facet; attribute-map's dispatch recognizes `:term` and routes to INHABITANT layer of `:type` facet. 5 facets preserved per §4.2.

- **Q5 α-equivalence proxy**: ship 3c with `equal?` proxy; ctor-desc-based α-walk refinement deferred to follow-up. Gain from ctor-desc is correctness-by-construction (eliminates false-positive contradictions on α-variants), not performance. Upgrade trigger: property inference or real-world false-positive surfaces.

- **Q6 sub-phase partition**: 3c-i (reader shim + value reshape), 3c-ii (per-rule writer migration), 3c-iii (PUnify-based residuation propagator), 3c-iv (deferred α-equiv refinement), 3c-close.

**Estimated 3c total**: ~120-200 LoC across 3 commits + tests.

### §3.6 Design invariants to preserve during 3c implementation

- **Merge purity** (P4(b)): `merge-classify-inhabit` is `(v × v → v)` pure. Cross-tag residuation check is a PROPAGATOR, not in the merge. Do NOT put side effects in the merge.
- **5 facets in AttributeRecord**: `:type`, `:context`, `:usage`, `:constraints`, `:warnings`. `:term` is surface alias, NOT a 6th facet.
- **Stratum request mechanism**: follow S1 NAF handler precedent at `relations.rkt:process-naf-request`. Request struct carries ALL metadata needed for inter-round processing.
- **Component-paths enforcement**: `'classify-inhabit` is classified 'structural (Phase 1f). The 3c-iii propagator MUST declare `:component-paths` for both CLASSIFIER and INHABITANT layers — otherwise hard error at installation.
- **Phase 9 coherence**: the stratum request mechanism should be worldview-agnostic in 3c. Phase 9 refines with worldview-tagging overlay. Don't pre-couple.

---

## §4 Surprises and Non-Obvious Findings

Highest-risk items for the continuation session.

### §4.1 Phase 1e-α scope-reduction pattern matters for 3c

1e-α surfaced 22 test failures on identity-or-error migration; investigation showed test-fixture pattern makes some registries legitimately replace-semantics. Scope-reduction was architecturally correct: per-site classification needs PM Track 12's submodule scope. **Apply same discipline at 3c**: if large-scale migration surfaces many failures, investigate whether the premise was wrong vs real bugs.

### §4.2 Phase 1f uses callback-parameter pattern for cycle avoidance

propagator.rkt cannot import sre-core.rkt (cycle). Pattern: propagator holds parameter `current-domain-classification-lookup`; sre-core provides `lookup-domain-classification`; infra-cell-sre-registrations wires them at load. Tests importing infra-cell-sre-registrations trigger wiring automatically. **Apply same pattern if 3c-iii needs cross-module access**.

### §4.3 PUnify reuse reduced 3c-iii scope significantly

My initial estimate was ~60-100 LoC for the residuation propagator. The SRE+PUnify+Module-Theory lens revealed unify-core + 'subtype + SRE ctor-desc already provide the machinery. Fire function is ~10-15 LoC. **Respect the lens — don't reinvent**.

### §4.4 `:term` is not a real facet

D.3 §4.2 says 5 facets, not 6. The classifier/inhabitant split is via tag-layers on the `:type` facet carrier. `:term` is user surface syntax that routes to the inhabitant layer. When implementing 3c-i, do NOT add a new facet to AttributeRecord.

### §4.5 Stratum request carries ALL metadata needed for inter-round processing

Per P4(b) + §6.14.6 joint mini-design item with Phase 9: the stratum request carries the worldview assumption-id. For 3c (pre-Phase-9), the request can omit worldview (uses a default / always-true). Phase 9 adds the tagging layer. Don't hard-code assumptions about what metadata the request carries — make it extensible.

### §4.6 Phase 1V declared Phase 1 COMPLETE but many SRE domains stay 'unclassified

Phase 1f progressive rollout: only 3 domains classified so far ('hasse-registry, 'meta-solve, 'timestamped-cell). ~25 others stay 'unclassified. Phase 3c shouldn't classify all of them — keep the progressive pattern. 3c classifies `'classify-inhabit` at 3e timing.

### §4.7 Per-meta-cell consolidation is Phase 4 territory, not Phase 3

PU audit surfaced that elaborator-network.rkt allocates N cells for N metas. Consolidation to compound meta-cell is a Phase 4 mini-design question — captured in tracker row 4 with 3 options (α per-meta, β compound, γ hybrid). **Phase 3 is agnostic to this choice**: tag-layer scheme works in all three options.

### §4.8 Phase 3+9 joint mini-design item carries

P4(b) stratum request worldview-tagging is joint with Phase 9 cell-based TMS design. 3c ships mechanism WITHOUT worldview specificity; Phase 9 adds overlay. Captured in tracker row 9.

### §4.9 α-equivalence is equal? proxy, upgrade on demand

Ship 3c with `equal?`. If tests/property inference/real-world surface false-positive contradictions on α-variants, upgrade to ctor-desc-based α-walk. Don't pre-optimize.

### §4.10 Prior handoff §4 surprises REMAIN VALID

All surprises from the prior 2026-04-19 Phase 1d mid-campaign handoff §4 are still load-bearing. Most notably:
- Cell is not a lattice (underpins Tier 1/2/3 architecture)
- Walks keeps sneaking in (review wording deliberately)
- PUnify reach richer than D.2 assumed (confirmed again in Phase 3c design)
- Elaborator partially BSP-integrated (will be relevant for stratum request handler wiring in 3c-iii)

---

## §5 Open Questions and Deferred Work

### §5.1 Phase 3c remaining

1. **3c-i**: reader shim + `:type` facet value reshape to `classify-inhabit-value`
2. **3c-ii**: per-rule writer migration in typing-propagators.rkt
3. **3c-iii**: cross-tag residuation propagator via PUnify + stratum request
4. **3c-iv**: α-equivalence refinement via ctor-desc (deferred; trigger on false-positive)
5. **3c-close**: tests + tracker ✅

### §5.2 Phase 3 remaining after 3c

6. **3d**: parity tests for `type-meta-split` class per §9.1. A/B bench for lazy-vs-eager residuation per §6.2 verification plan.
7. **3e**: Phase 1f enforcement — classify `'classify-inhabit` as 'structural. Any newly-surfaced `:component-paths` gaps treated as findings.
8. **3V**: Vision Alignment Gate for Phase 3.

### §5.3 Follow-up candidates (not immediate)

- α-equivalence ctor-desc refinement (if needed)
- Migration of remaining SRE domains from 'unclassified to 'structural / 'value (progressive per-session)
- Phase 4 mini-design when CHAMP retirement begins (per-meta-cell authority decision)
- Phase 9 joint mini-design (worldview-tagging overlay for stratum requests)

### §5.4 Mini-design deferrals STILL OPEN from prior sessions

All deferrals from prior handoffs §5.1 remain active:
- P3 + C1 / Phase 6 (structural coverage + quiescence gate)
- M1 / Phase 7 (impl registration path)
- M3 / Phase 9b (γ catalog re-firing)
- C2 / Phase 9 (cell-based TMS vs existing ATMS; now with Phase 3+9 joint item)

### §5.5 DEFERRED.md entries stable

No new DEFERRED.md entries from this session. Existing scaffolding tracking (Tier 2 merge-fn registry, current-source-loc, hasse-registry-handle, current-process-id, current-clock-cell-id, current-domain-classification-lookup) remains PM Track 12 territory.

---

## §6 Process Notes

### §6.1 This session codified NOTHING NEW — execution-heavy session

Prior sessions codified: mini-design audit as Stage 4 step 1; D2 framework; scaffolding registry discipline; cycle-breaking modules. This session EXECUTED against those disciplines — no new codifications surfaced.

### §6.2 Validated process patterns

- **Mini-design audit at start of each sub-phase**: applied consistently (Phase 1f, Phase 3, Phase 3c)
- **Scope-reduction as correct response to premise-failure**: Phase 1e-α pattern repeated (though didn't fire in Phase 3c; design was robust)
- **5-step phase completion checklist**: respected per sub-phase
- **Conversational cadence**: user pushback on Q1 (C convergence), Q2 (SRE/PUnify/Module-Theory lens), Q5 (ctor-desc vs equal?) materially improved design quality — lens-based framing reduced Phase 3c-iii LoC estimate from 60-100 to 30-50

### §6.3 Key lens application

Phase 3c's Q2 dialogue demonstrated the SRE+PUnify+Module-Theory lens providing concrete architectural payoff. The insight that "residuation check is a quantale MEET via PUnify" reduced the propagator design from a complex bespoke check to a 10-15 LoC wrapper. **Apply this lens reflexively** when the user asks "is there a structural/SRE/module-theoretic framing?"

### §6.4 Commit discipline

Per sub-phase:
- Code commit (core changes)
- Separate docs commit (tracker + dailies)
- Exception: small commits may combine if scope is clearly single-purpose

3c implementation should produce 3 code commits (3c-i, 3c-ii, 3c-iii) + 1 docs commit per sub-phase (or consolidated at close).

---

## §7 What the Continuation Session Should Produce

### §7.1 Immediate (Phase 3c implementation)

Per D.3 §6.15.8 sub-phase partition:

1. **3c-i implementation**: modify typing-propagators.rkt's that-read/that-write to recognize `:term` keyword. Reshape `:type` facet initialization to `(classify-inhabit-value 'bot 'bot)`. Auto-unwrap classifier layer on `:type` reads; route `:term` reads/writes to inhabitant layer. All existing `(that-read ... :type)` callers keep working with no code change (they receive classifier layer, which is the same value they received before under single-value facet).

2. **3c-ii implementation**: per-rule writer migration. Audit typing-propagators.rkt's `(that-write ... :type ...)` calls. For each: decide CLASSIFIER or INHABITANT. Type-variable meta writes (telling what TYPE a meta must have) → CLASSIFIER. Value-position writes (telling what VALUE a position has) → INHABITANT. Test per-rule.

3. **3c-iii implementation**: residuation propagator.
   - Watches `:classify-inhabit` cell component-paths (both tag layers) at each position
   - Fire-once-on-threshold trigger: both layers populated
   - Fire function:
     - Read classifier + inhabitant
     - Compute `type-of-expr(inhabitant)` (may need helper in typing-core.rkt)
     - Invoke `unify-core classifier (type-of-expr inhabitant) 'subtype`
     - Dispatch:
       - Compatible (no narrowing): no-op
       - Narrowing (PUnify returns refined type): emit stratum request to write refined classifier back
       - Contradiction: write `'classify-inhabit-contradiction` sentinel
   - Stratum handler:
     - Register via `register-stratum-handler!` with a new request-cell
     - Between BSP rounds, process pending requests: execute the narrowing writes
     - Follow S1 NAF handler pattern at `relations.rkt:process-naf-request`

4. **3c-close**: tests for each sub-phase + 3c tracker row update. Phase 3 progress shifts to "3a+3b ✅, 3c ✅, 3d ⬜".

### §7.2 Medium-term (complete Phase 3)

5. **3d**: parity tests (`type-meta-split` class per §9.1) + A/B bench (lazy-vs-eager residuation check per §6.2). Decision locks lazy vs eager.
6. **3e**: classify `'classify-inhabit` as 'structural; address any surfaced enforcement gaps.
7. **3V**: Vision Alignment Gate for Phase 3.

### §7.3 Then Phase 4

Phase 4 (A2 CHAMP retirement) is next with the per-meta-cell consolidation mini-design (row 4 tracker captures 3 options α/β/γ).

---

## §8 Final Notes

### §8.1 What "I have full context" requires (per HANDOFF_PROTOCOL §Hot-Load Reading Protocol)

- Read EVERY document in §2 IN FULL, not sampled
- Articulate EVERY decision in §3 with rationale
- Know EVERY surprise in §4

If any is unclear, ASK before proceeding. "I think I understand Phase 3c" is not sufficient. "I understand Phase 3c uses PUnify via unify-core with 'subtype relation; the propagator's fire function is ~10-15 LoC because it reuses existing SRE ctor-desc infrastructure; cross-tag narrowing writes emit stratum requests per P4(b); `:term` is a magic keyword routed to the inhabitant layer, not a 6th facet" is.

### §8.2 Commit span

This session: `18204fc6` (Phase 1e close, start of session) through `cd0918cd` (Phase 3c mini-design). Key landmarks:
- `25b421fe` Phase 1f enforcement
- `73a6e48e` Phase 1V / Phase 1 COMPLETE
- `7e9cdc07` Phase 3 mini-design
- `98f503a2` Phase 3a+3b infrastructure
- `32996b5e` 3a+3b tracker/dailies
- `cd0918cd` Phase 3c mini-design

### §8.3 Gratitude

This session's Phase 3 mini-design dialogue was especially productive. The user's question about "is there an SRE/structural unification/module theoretic lens that is useful, beyond the proposed propagator design?" crystallized the Phase 3c-iii design from a vague "residuation propagator" into a precise "PUnify-via-unify-core-'subtype-relation reduced to 10-15 LoC." Similarly, the PU audit question ("check for our cell-cost expectations and efficiency") surfaced the per-meta-cell consolidation question at the correct phase (Phase 4).

The pattern these questions share: **the user applies architectural lenses reflexively**. Future sessions should continue this discipline — when faced with a new propagator design, asking "what does SRE / PUnify / Module Theory say here?" often reveals a simpler design than bespoke invention.

### §8.4 Suite health

6022 affected-tests GREEN at 107s (last full run after Phase 1f). Phase 3a+3b added 19 tests, all passing. No regressions introduced.

The context is in safe hands.
