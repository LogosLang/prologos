# PPN Track 4C — Phase 9 Pre-Mini-Design Handoff

**Date**: 2026-04-20
**Purpose**: Transfer context from this session (Phase 3 full completion → Phase 4 mini-design opened → pivoted to Phase 9 per framing B resequencing decision) into a continuation session. Phase 9 mini-design is the NEXT design work; Phase 3 is fully closed; framing B is settled.

**Before reading anything else**: read [`HANDOFF_PROTOCOL.org`](../principles/HANDOFF_PROTOCOL.org). The Hot-Load Reading Protocol requires reading EVERY §2 document IN FULL before summarizing understanding back to the user. **CRITICAL meta-lesson from this session**: mini-design is CONVERSATIONAL dialogue over open questions, NOT pre-drafted resolutions in the design doc. DO NOT draft a §6.X design section for Phase 9 unilaterally; work through Q&A with the user first, capture resolutions AFTER dialogue.

---

## §1 Current Work State (PRECISE)

- **Track**: PPN Track 4C — "Bring elaboration completely on-network"
- **Design version**: **D.3** (with ~20 mini-design additions 2026-04-19 through 2026-04-20)
- **Last commit**: `cc7e4416` — "PPN 4C: framing B — Phase 9 resequenced ahead of Phase 4 (β2 absorbed)"
- **Branch**: `main`
- **Suite state**: 7941 full-suite tests GREEN at ~124s (from Phase 3V close). Acceptance file clean via `process-file`. Lint `--strict` exits 0.

### Progress Tracker status (D.3 §2)

| Phase | Status | Notes |
|---|---|---|
| 0 | ✅ | Acceptance + Pre-0 + parity skeleton |
| 1 (1a-1f, 1V) | ✅ | Tier 1/2/3 architecture + enforcement |
| 2, 2b | ✅ | Facet SRE registrations + Hasse-registry primitive |
| 3 (3a+3b, 3c-i/ii/iii, 3d, 3e, 3V) | ✅ | **Phase 3 COMPLETE** (commit `2a4c636e`) — A5 :type/:term tag-layer split |
| **9** | ⬜ | **NEXT mini-design target** (framing B resequenced 2026-04-20) |
| **4** | ⬜ | **Scope expanded to β2** (attribute-map absorbs meta storage); depends on Phase 9 |
| 5, 6, 7, 8 | ⬜ | Unchanged |
| 9b, 10, 11, 11b, 12a-d | ⬜ | Unchanged |
| T | ⬜ | Enumerated dedicated tests |
| 13 | ⬜ | Progressive SRE domain classification (cross-cutting, §6.16 captures) |
| V | ⬜ | Acceptance + A/B + capstone + PIR |

### Next immediate task

**Open Phase 9 mini-design conversationally with the user.** Phase 9 is heavy; it has multiple inherited mini-design items + its own 4 sub-phases (9A/B/C/D per §6.10). The mini-design session resolves these open questions before implementation. Do NOT pre-draft resolutions — surface the question set, work through with user, capture resolutions AFTER dialogue.

---

## §2 Documents to Hot-Load (ORDERED)

**CRITICAL**: the Hot-Load Reading Protocol requires reading EVERY document IN FULL. Sampling is not acceptable. Ask before proceeding if anything is unclear.

### §2.0 Start here

0. [`HANDOFF_PROTOCOL.org`](../principles/HANDOFF_PROTOCOL.org) — THIS protocol.

### §2.1 Always-Load (every session)

1. [`CLAUDE.md`](../../../CLAUDE.md) + [`CLAUDE.local.md`](../../../CLAUDE.local.md)
2. [`MEMORY.md`](../../../MEMORY.md) — auto-memory index; updated this session with the `--tests` workflow rule
3. [`DESIGN_METHODOLOGY.org`](../principles/DESIGN_METHODOLOGY.org) — Stage 4 Implementation Protocol
4. [`DESIGN_PRINCIPLES.org`](../principles/DESIGN_PRINCIPLES.org) — 10 principles + Hyperlattice Conjecture
5. [`CRITIQUE_METHODOLOGY.org`](../principles/CRITIQUE_METHODOLOGY.org) — P/R/M lenses + SRE lattice lens

### §2.2 Architectural Rules (MUST be internalized)

6. [`.claude/rules/on-network.md`](../../../.claude/rules/on-network.md) — THE DESIGN MANTRA
7. [`.claude/rules/structural-thinking.md`](../../../.claude/rules/structural-thinking.md) — SRE 6 questions + Module Theory
8. [`.claude/rules/propagator-design.md`](../../../.claude/rules/propagator-design.md) — **CRITICAL for Phase 9**: fire-once, broadcast, component-indexing, worldview bitmask, cell-allocation efficiency
9. [`.claude/rules/workflow.md`](../../../.claude/rules/workflow.md) — operational discipline
10. [`.claude/rules/testing.md`](../../../.claude/rules/testing.md) — **UPDATED this session** with the `--tests FILE...` targeted runner discipline
11. [`.claude/rules/pipeline.md`](../../../.claude/rules/pipeline.md) — exhaustiveness checklists
12. [`.claude/rules/stratification.md`](../../../.claude/rules/stratification.md) — **CRITICAL for Phase 9**: stratum infrastructure, NAF pattern precedent, BSP scheduler integration
13. [`.claude/rules/prologos-syntax.md`](../../../.claude/rules/prologos-syntax.md)

### §2.3 Session-Specific — D.3 DESIGN (READ IN FULL)

14. [`docs/tracking/2026-04-17_PPN_TRACK4C_DESIGN.md`](../2026-04-17_PPN_TRACK4C_DESIGN.md) — **THE D.3 design. READ IN FULL.** Critical sections updated THIS session:
    - §2 Progress Tracker (Phase 3 fully ✅; Phase 9 next; Phase 4 scope expanded to β2 per framing B)
    - §6.10 — existing Phase 9 + Phase 10 design text
    - §6.15 (Phase 3 design, now closed)
    - §6.16 — Phase 13 Progressive Classification
    - §6.15.6 — Phase 3+9 joint mini-design item
    - Dependency graph updated (Phase 9 ahead of Phase 4)

### §2.4 Session-Specific — CORE PHASE 9 REFERENCES (READ IN FULL)

15. [`docs/research/2026-04-06_CELL_BASED_TMS_DESIGN_NOTE.md`](../../research/2026-04-06_CELL_BASED_TMS_DESIGN_NOTE.md) — **THE Phase 9 design note.** Phase 9A/B/C/D migration path. ~450 line scope estimate.

16. [`docs/research/2026-04-08_HYPERCUBE_BSP_LE_DESIGN_ADDENDUM.md`](../../research/2026-04-08_HYPERCUBE_BSP_LE_DESIGN_ADDENDUM.md) — Q_n worldview lattice, Gray-code traversal, bitmask subcube pruning, hypercube all-reduce. Phase 9 mini-design revisits these per §6.15.6 and §6.11.3.

17. [`docs/research/2026-03-28_MODULE_THEORY_LATTICES.md`](../../research/2026-03-28_MODULE_THEORY_LATTICES.md) — Module Theory lens. Phase 9 is where tropical-lattice fuel cell first instantiates. §6 e-graphs as quotient modules relevant to cost-optimization framing.

### §2.5 Session-Specific — PHASE 3 CLOSURE + FRAMING B

18. [`docs/tracking/standups/2026-04-19_dailies.md`](../standups/2026-04-19_dailies.md) — Session log covering: Phase 3 full completion (3a+3b through 3V), tm-cid follow-up, Phase 13 capture, **framing B decision with full rationale** (end of file).

### §2.6 Session-Specific — PRIOR HANDOFFS (continuity)

19. [`docs/tracking/handoffs/2026-04-20_PPN_4C_PHASE_3C_HANDOFF.md`](2026-04-20_PPN_4C_PHASE_3C_HANDOFF.md) — Phase 3c pre-implementation handoff (this session implemented it).

20. [`docs/tracking/handoffs/2026-04-19_PPN_4C_PHASE_1D_MID_HANDOFF.md`](2026-04-19_PPN_4C_PHASE_1D_MID_HANDOFF.md) — Earlier handoff.

### §2.7 Session-Specific — PHASE 9 EXISTING INFRASTRUCTURE (audit targets)

21. [`racket/prologos/elab-speculation.rkt`](../../../racket/prologos/elab-speculation.rkt) — **speculation bridge (Phase 9 migration target)**. `save-meta-state` / `restore-meta-state!` mechanism; `current-speculation-stack` parameter retires in Phase 9D.

22. [`racket/prologos/propagator.rkt`](../../../racket/prologos/propagator.rkt) — `current-speculation-stack`, `current-worldview-bitmask`, `net-cell-write`/`read`, TMS mechanism. Phase 9A/B modifies these.

23. [`racket/prologos/relations.rkt`](../../../racket/prologos/relations.rkt) — **S1 NAF handler precedent** at `process-naf-request` (line ~116). Phase 9's worldview-tagging pattern follows this shape per §6.15.6.

24. [`racket/prologos/atms.rkt`](../../../racket/prologos/atms.rkt) — existing ATMS solver. Phase 9's C2 mini-design decides relationship: substrate-only / + representative migration / wholesale replacement.

25. [`racket/prologos/decision-cell.rkt`](../../../racket/prologos/decision-cell.rkt) — `counter-merge` prior art + topology-stratum discipline. Phase 9's tropical-fuel cell (M2) follows this pattern.

### §2.8 Session-Specific — CORE PHASE 3 ARTIFACTS (context for Phase 9's joint item)

26. [`racket/prologos/classify-inhabit.rkt`](../../../racket/prologos/classify-inhabit.rkt) — tag-layer carrier. Phase 9's worldview-tagging overlay composes with this.

27. [`racket/prologos/typing-propagators.rkt`](../../../racket/prologos/typing-propagators.rkt) — residuation propagator + stratum-request mechanism (Phase 3c-iii). Phase 9's joint item (§6.15.6) refines the stratum-request worldview-tagging for these.

### §2.9 Tracking metadata

28. [`docs/tracking/DEFERRED.md`](../DEFERRED.md) — scaffolding registry.

29. [`docs/tracking/2026-03-13_PROPAGATOR_MIGRATION_MASTER.md`](../2026-03-13_PROPAGATOR_MIGRATION_MASTER.md) — PM series master.

---

## §3 Key Design Decisions (RATIONALE — do NOT re-litigate)

### §3.1 Framing B — Phase 9 resequenced ahead of Phase 4 (commit `cc7e4416`)

Track-level sequencing decision closed 2026-04-20.

**Decision**: Phase 9 ships before Phase 4. Phase 4's scope absorbs β2 (attribute-map becomes sole meta store onto Phase 9's worldview-tagged substrate). No separate A2-II follow-up.

**Alternative framings considered** (dialogue captured in dailies):
- A: current order, α + A2-II later (duplication window = belt-and-suspenders smell)
- B: **adopted** — swap, Phase 9 first; Phase 4 does β2 in one pass
- C: combine 4+9 into enlarged phase (too large; violates "focused scope per phase")

**Rationale**:
- β2 is the vision target (single source of truth; attribute-map authoritative)
- Phase 9 is a substrate phase leveraged by multiple downstream phases (4 β2, 9b, 10)
- Phase 9 has NO hard functional dependency on Phase 4 (transit via Phase 8 only)
- Framing A's duplication window is real architectural debt
- Phase 9 warrants its own concentrated mini-design session

**Implication for next session**: open Phase 9 mini-design, NOT Phase 4.

### §3.2 All prior Phase 3 decisions remain binding

The full Phase 3 delivery (3a+3b tag-layer infra → 3c-i/ii/iii reader shim + writer migration + residuation → 3d parity + A/B bench → 3e 'attribute-map 'structural → 3V). See D.3 §6.15 for closed design decisions. Do NOT revisit Q1-Q7 from Phase 3 mini-design or Q1-Q6 from Phase 3c sub-design.

### §3.3 Phase 4 scope is β2, not α

Row 4 in the tracker was updated. Phase 4's mini-design (when it comes) resolves migration scope + sub-phase partition + drift risks — but NOT the α/β/γ architecture choice (β2 is pre-committed via framing B).

### §3.4 Meta-lesson: mini-design is conversational dialogue, not pre-drafted resolutions

This session had one stumble where I drafted a full Phase 4 §6.17 design section unilaterally (resolutions, sub-phases, drift risks, etc.) — the user corrected: "That's not how we do phase design. We review what we have from the design, and then work through the design through conversation together." I reverted the premature commit (was `be49b567`, now reset).

The pattern is: (1) review what the design doc already has for this phase; (2) surface open questions for dialogue; (3) work through each question with the user; (4) capture resolutions AFTER they emerge.

For Phase 9 mini-design: surface questions, do NOT pre-resolve them.

### §3.5 that-read arity-2 extension shipped (commit `716bc923`)

Addendum beyond §6.15.3 checklist: `(that-read am pos)` now returns a whole-record hash with `:type`/`:term` decomposition. Consumers: Phase 11b `derivation-chain-for`, LSP hover, user-facing `that` grammar form. No action needed; documented in D.3 §6.15.

---

## §4 Surprises and Non-Obvious Findings

### §4.1 that-read 1400× speedup is already realized

The "1400× faster than CHAMP" Pre-0 finding applies to CURRENT code. `that-read` is in active use across typing-propagators.rkt. Phase 4 (β2) will complete the migration by retiring the remaining CHAMP path; the performance win is cumulative across migrated consumers.

### §4.2 Phase 3 inhabitant × inhabitant merge uses equal? (α-equiv proxy)

3c shipped with `equal?` as α-equivalence proxy. 3c-iv ctor-desc-based α-walk deferred to observational trigger (§6.15.8 Q5). Phase 9 doesn't interact with this.

### §4.3 Phase 3c-ii surfaced a bridge migration (solve-meta! chain)

`make-meta-solution-output-fire-fn` reads `:term` (not `:type`) post-3c-ii. This is the bridge pattern for Phase 4 β2 too — the solve-meta! chain is already primed to write authoritative `:term` reads. Phase 4 migration will extend this pattern across all readers.

### §4.4 Phase 9's mini-design items accumulate

Inherited mini-design items (from external critique rounds + joint items):
- **M2** (external critique 2026-04-18): tropical-lattice fuel cell. Lean: (b) on-network min-merge cell. First practical tropical-lattice in the codebase; template for PReduce.
- **C2** (external critique 2026-04-18): relationship to existing ATMS infrastructure. Options (1)/(2)/(3). Framing B now suggests (2) "substrate + one representative migration" is natural, with Phase 4 β2 as the first substrate consumer post-Phase-9.
- **§6.15.6 joint item from Phase 3**: stratum-request worldview-tagging overlay. Pattern precedent: S1 NAF handler.
- **Hypercube algorithms** (from hypercube addendum): Gray-code traversal, bitmask subcube pruning, hypercube all-reduce.

These resolve via dialogue in Phase 9 mini-design.

### §4.5 Phase 9 is a SUB-TRACK with phases 9A/B/C/D

Per §6.10:
- 9A: worldview-cell infrastructure
- 9B: net-cell-write/read accept explicit worldview arg (backward-compatible)
- 9C: migrate speculation users (elab-speculation-bridge, union type checking)
- 9D: retire current-speculation-stack parameter

Mini-design needs to settle ordering, scope of each sub-phase, and how to incorporate M2 + C2 + §6.15.6 joint + hypercube across them.

### §4.6 Suite pre-push safety is live (new this session)

The `--tests FILE...` mode on `run-affected-tests.rkt` (commit `1b5c5172`) is the new targeted-test discipline. Do NOT use bare `raco test tests/test-X.rkt` after production export changes — linklet mismatch risk. Use `racket tools/run-affected-tests.rkt --tests tests/test-X.rkt --tests tests/test-Y.rkt`.

### §4.7 Prior handoffs' surprises remain valid

All surprises from [Phase 3c handoff §4](2026-04-20_PPN_4C_PHASE_3C_HANDOFF.md#4-surprises-and-non-obvious-findings) and [Phase 1d handoff §4](2026-04-19_PPN_4C_PHASE_1D_MID_HANDOFF.md#4-surprises-and-non-obvious-findings) are still load-bearing. Notably:
- Cell is not a lattice (Tier 1/2/3 architecture)
- PUnify reach is richer than D.2 assumed
- Elaborator is already partially BSP-integrated

---

## §5 Open Questions and Deferred Work

### §5.1 Phase 9 mini-design (NEXT SESSION FOCUS)

Phase 9's mini-design work will resolve:

**Q-9-1 — C2 resolution**: relationship to existing ATMS infrastructure. Options (1) substrate-only, (2) substrate + representative migration (Phase 4 β2 natural candidate), (3) wholesale replacement. Framing B's resequencing suggests (2) is natural. But needs dialogue.

**Q-9-2 — M2 resolution**: tropical-lattice fuel cell. Lean (b) per external critique. Confirm + decide tropical fuel semantics (min-merge, exhaustion signaling, interaction with other cells).

**Q-9-3 — Phase 3 joint item (§6.15.6)**: stratum-request worldview-tagging overlay. Pattern precedent S1 NAF. Mini-design confirms and refines.

**Q-9-4 — Hypercube algorithms adoption**: Gray-code traversal, bitmask subcube pruning, hypercube all-reduce. Which ship in Phase 9 vs defer to Phase 10?

**Q-9-5 — Sub-phase partition (9A/B/C/D)**: existing design-note shape — confirm or refine.

**Q-9-6 — Phase 4 β2 handoff shape**: Phase 9 must deliver enough substrate for Phase 4 β2 (per-meta cell retirement onto worldview-tagged attribute-map). What exactly is the substrate contract? Meta-cell migration mechanism?

**Q-9-7 — Existing ATMS cell audit**: per C2 option (1/2/3), an R-lens inventory of existing ATMS-like call sites. What scope?

**Q-9-8 — Phase 9b interaction**: γ hole-fill (Phase 9b) consumes Phase 9's TMS for multi-candidate ATMS branching. Any constraints Phase 9 must honor for 9b readiness?

**Q-9-9 — Drift risks**: named after other questions settle.

**Q-9-10 — Budget estimate**: §6.10 says ~450 lines. Framing B addition (Phase 4 β2 substrate handoff) may extend.

DO NOT resolve these by pre-drafting a §6.18 Phase 9 mini-design section unilaterally. Work through each with the user.

### §5.2 Phase 4 (post-Phase-9)

When Phase 9 ships, Phase 4 mini-design opens with β2 pre-committed. Remaining questions: migration sequencing (stage-then-delete vs forced), scope of zonk.rkt migration (in Phase 4 or wait for Phase 12), `meta-info-ctx` vs `:context` invariant, `meta-info-status` derivation, parity axis 2 test inputs, sub-phase partition, drift risks.

### §5.3 Phase 13 progressive classification

Captured; §6.16 has full scope. Opportunistic scheduling.

### §5.4 DEFERRED.md entries stable

No new entries from this session. Existing scaffolding tracking remains.

### §5.5 Mini-design deferrals STILL OPEN from prior sessions

- **P3 / Phase 6**: structural coverage lean
- **M1 / Phase 7**: impl registration path
- **M3 / Phase 9b**: γ catalog re-firing
- **Phase 11b**: trace monoidal category research input

---

## §6 Process Notes

### §6.1 Codified this session

- **`--tests FILE...` targeted test discipline**: new runner mode + MEMORY.md rule. Commit `1b5c5172`. Prevents linklet-mismatch errors on bare `raco test` after production export changes.
- **Phase 13 tracked**: progressive SRE domain classification captured as a phase (§6.16). Commit `fac686c8`.
- **Meta-lesson**: mini-design is conversational dialogue, not pre-drafted resolutions. See §3.4 above.

### §6.2 Validated process patterns (still active)

- Mini-design audit at start of each sub-phase
- Scope-reduction as correct response to premise-failure
- 5-step phase completion checklist
- Conversational cadence: user pushback catches framing errors (framing B itself emerged this way)
- Lens discipline (Module Theory, SRE, PUnify, Hasse, Hypercube) — applied reflexively in dialogue

### §6.3 Commit discipline

One commit per code change + one commit per docs update (tracker + dailies). Full suite GREEN before each commit. Acceptance file clean. Lint --strict exits 0.

### §6.4 Conversational cadence for heavy phases

Phase 9 is heavy (multiple inherited mini-design items + 4 sub-phases + hypercube algorithms). Mini-design may span multiple sessions. Handoff-per-session pattern worked for Phase 3c; plan for Phase 9 similarly.

---

## §7 What the Continuation Session Should Produce

### §7.1 Immediate (Phase 9 mini-design)

1. Hot-load every §2 document IN FULL
2. Summarize understanding back to user; validate
3. **Open Phase 9 mini-design conversationally** — surface the open questions (§5.1); work through each with user dialogue; capture resolutions AFTER dialogue in D.3 §6.18 (or whatever section number)
4. Remember: DO NOT pre-draft resolutions. This session's §3.4 meta-lesson is load-bearing.

### §7.2 Medium-term (Phase 9 implementation)

After mini-design resolves:
- Sub-phase implementation following §6.10 + mini-design resolutions
- Parity/bench artifacts per Phase 3d precedent if applicable
- 9V Vision Alignment Gate

### §7.3 Then Phase 4 (β2)

Post-Phase-9: Phase 4 mini-design opens with β2 pre-committed. Work through §5.2 open questions. Implementation follows.

---

## §8 Final Notes

### §8.1 What "I have full context" requires (per HANDOFF_PROTOCOL §Hot-Load Reading Protocol)

- Read EVERY document in §2 IN FULL
- Articulate EVERY decision in §3 with rationale (especially §3.1 framing B)
- Know EVERY surprise in §4
- Understand the open questions in §5.1 but DO NOT pre-resolve them

If unclear, ASK before proceeding. "I understand framing B resequenced Phase 9 ahead of Phase 4 because β2 is the vision target and the duplication window in framing A is a belt-and-suspenders smell; Phase 9 is the substrate for β2 and other downstream phases" is a good articulation.

### §8.2 Commit span this session

From `716bc923` (post-3V arity-2 extension) → `cc7e4416` (framing B closed). Key landmarks:
- `2a4c636e` Phase 3V — Phase 3 COMPLETE
- `f52ebbc9` tm-cid follow-up (literal-fire / universe-fire pure writes; constraint-creation specific-path)
- `fac686c8` Phase 13 tracked (progressive classification)
- `716bc923` that-read arity-2 extension
- `cc7e4416` framing B

Also: `1b5c5172` tools `--tests` mode added mid-session (during 3c-close).

### §8.3 Suite health

7941 tests GREEN at 124s (~124ms baseline; within ~200s ceiling). Stable throughout Phase 3 + all follow-ups. Acceptance file runs clean. Lint `--strict` exits 0. No regressions.

### §8.4 Gratitude

This session's Phase 3 delivery + framing B decision owe substantially to the user's lens-based pushback pattern:
- "Is there an SRE/structural unification/module theoretic lens?" (Phase 3c) → residuation simplified from 60-100 LoC to 15 LoC
- "That's not how we do phase design" (Phase 4 attempt) → corrected the unilateral-drafting stumble; restored conversational discipline
- "Or does it make more sense to design and implement Phase 9 now?" → framing B landed, avoided the α + A2-II duplication window

The pattern: the user applies architectural lenses reflexively. Phase 9's mini-design will benefit from this same rigor. Respect the pattern — surface questions, don't drop pre-answered designs on the user.

The context is in safe hands.
