# PPN Track 4C Phase 9+10+11 Addendum — Phase 1A-i Pre-Implementation Handoff

**Date**: 2026-04-21
**Purpose**: Transfer context from this session (Stage 1 research → Stage 2 audit → Stage 3 design D.1→D.2→D.3 → Phase 1A mini-design → Option B scope revision) into a continuation session. Phase 1A-i (dead-code cleanup) is ready to implement as the next immediate work.

**Before reading anything else**: read [`HANDOFF_PROTOCOL.org`](../principles/HANDOFF_PROTOCOL.org). The Hot-Load Reading Protocol requires reading EVERY §2 document IN FULL before summarizing understanding back to the user. DO NOT skim; the 13 specific documents below carry hard-earned context from this session.

**CRITICAL meta-lesson carried forward**: mini-design is CONVERSATIONAL dialogue over open questions, NOT pre-drafted resolutions in the design doc. The user may push back on any scope or approach. When they do, PAUSE and work through it. This pattern was re-validated during Phase 1A mini-design (user scope clarification led to Option B discovery).

---

## §1 Current Work State (PRECISE)

- **Track**: PPN Track 4C Phase 9+10+11 Addendum (substrate + orchestration unification)
- **This addendum renumbers to**: Phase 1 (substrate + tropical fuel), Phase 2 (orchestration), Phase 3 (union types + hypercube) — sub-phases A, B, C as needed
- **Parent design**: PPN 4C D.3 — `docs/tracking/2026-04-17_PPN_TRACK4C_DESIGN.md`
- **This addendum's design**: **D.3** at `docs/tracking/2026-04-21_PPN_4C_PHASE_9_DESIGN.md` (commit `b6d8a9c1`)
- **Last commit**: `b6d8a9c1` — "PPN 4C Phase 9+10+11 Design D.3: Phase 1A scope revision"
- **Branch**: `main`
- **Suite state**: not re-run this session; last known GREEN at the Phase 3 of PPN 4C (commit `cc7e4416`, 7941 tests at ~124s). No code changes this session — only documentation.

### Progress Tracker status (Design D.3 §3)

| Phase | Description | Status | Notes |
|---|---|---|---|
| Stage 1 | Research doc (tropical quantale) | ✅ | commit `de357aa1` |
| Stage 2 | Audit doc | ✅ | commits `62ce9f83`, `28208613` |
| Stage 3 | Design doc | ✅ D.3 | commit `b6d8a9c1` (scope revised per Phase 1A mini-audit) |
| 0 | Uses PPN 4C existing acceptance file + Pre-0 bench | ✅ | no new artifacts needed |
| **1A-i** | Retire dead code: `wrap-with-assumption` + `promote-cell-to-tms` | ⬜ | **NEXT TASK** — ~30-50 LoC, low risk |
| 1A-ii | Migrate 4 `net-new-tms-cell` sites in `elaborator-network.rkt` to tagged-cell-value | ⬜ | ~150-200 LoC, highest risk; mini-audit at phase start |
| 1A-iii | Retire TMS-cell mechanism + `current-speculation-stack` + fallback paths | ⬜ | ~100-200 LoC |
| 1B | Tropical fuel primitive + SRE registration | ⬜ | ~150-200 LoC |
| 1C | Canonical BSP fuel instance migration | ⬜ | ~100-200 LoC; A/B bench required |
| 1V | Vision Alignment Gate Phase 1 | ⬜ | |
| 2A | Register S(-1), L1, L2 as stratum handlers | ⬜ | ~75-125 LoC |
| 2B | Retire orchestrators | ⬜ | ~50-100 LoC |
| 2V | Vision Alignment Gate Phase 2 | ⬜ | |
| 3A | Fork-on-union basic mechanism | ⬜ | ~100-150 LoC |
| 3B | Hypercube integration | ⬜ | ~50-100 LoC |
| 3C | Residuation error-explanation | ⬜ | ~75-150 LoC |
| 3V | Vision Alignment Gate Phase 3 | ⬜ | |
| V | Capstone + PIR | ⬜ | |

**Track total LoC**: ~830-1450 estimated (revised up from ~650-1150 per Phase 1A scope expansion).

### Next immediate task

**Phase 1A-i implementation**: delete two dead helpers in `typing-propagators.rkt`:

1. `wrap-with-assumption` at `typing-propagators.rkt:325-329` (surrounding comment block at lines 313-323)
2. `promote-cell-to-tms` at `typing-propagators.rkt:334-338` (surrounding comment block at lines 331-333)

Both have ZERO production callers (mini-audit confirmed). The sole comment reference to `promote-cell-to-tms` at line 1918 is descriptive historical context.

Steps:
1. Quick re-grep to confirm zero callers (double-check the audit)
2. Edit `typing-propagators.rkt` — delete both helpers, their comment blocks, any export entries
3. Run affected tests (targeted mode): `racket tools/run-affected-tests.rkt --tests tests/test-typing-propagators.rkt` (or relevant test file; verify via tests affected)
4. Run acceptance file: `"/Applications/Racket v9.0/bin/racket" path/to/process-file examples/2026-04-17-ppn-track4c.prologos`
5. Commit 1A-i with descriptive message
6. Update D.3 tracker row: 1A-i ⬜ → ✅ + commit hash
7. Dailies update (per workflow rule: commit triggers dailies update)

---

## §2 Documents to Hot-Load (ORDERED)

**CRITICAL**: the Hot-Load Reading Protocol requires reading EVERY document IN FULL. Sampling is not acceptable.

### §2.0 Start here

0. [`HANDOFF_PROTOCOL.org`](../principles/HANDOFF_PROTOCOL.org) — THIS protocol

### §2.1 Always-Load (every session)

1. [`CLAUDE.md`](../../../CLAUDE.md) + [`CLAUDE.local.md`](../../../CLAUDE.local.md)
2. [`MEMORY.md`](../../../MEMORY.md) — auto-memory index
3. [`DESIGN_METHODOLOGY.org`](../principles/DESIGN_METHODOLOGY.org) — **UPDATED THIS SESSION**: Lens S added to Stage 3/4; Progress Tracker Placement discipline added to Stage 3 (commit `42ca336c`)
4. [`DESIGN_PRINCIPLES.org`](../principles/DESIGN_PRINCIPLES.org) — 10 principles + Hyperlattice Conjecture
5. [`CRITIQUE_METHODOLOGY.org`](../principles/CRITIQUE_METHODOLOGY.org) — P/R/M lenses + SRE lattice lens (Lens S addition noted in DESIGN_METHODOLOGY.org; not yet persisted into CRITIQUE_METHODOLOGY.org — that's a follow-up opportunity)

### §2.2 Architectural Rules (MUST be internalized)

6. [`.claude/rules/on-network.md`](../../../.claude/rules/on-network.md) — THE DESIGN MANTRA
7. [`.claude/rules/structural-thinking.md`](../../../.claude/rules/structural-thinking.md) — SRE 6 questions + Module Theory (basis for Lens S)
8. [`.claude/rules/propagator-design.md`](../../../.claude/rules/propagator-design.md) — **CRITICAL**: silent-write-drop discipline (`net-cell-read-raw` for snapshot/diffing, BSP-LE 2B PIR §6); fire-function network parameter discipline
9. [`.claude/rules/workflow.md`](../../../.claude/rules/workflow.md) — operational discipline, commit cadence, dailies updates
10. [`.claude/rules/testing.md`](../../../.claude/rules/testing.md) — `--tests FILE...` targeted test discipline; test-run protocol
11. [`.claude/rules/pipeline.md`](../../../.claude/rules/pipeline.md) — exhaustiveness checklists
12. [`.claude/rules/stratification.md`](../../../.claude/rules/stratification.md) — stratum infrastructure (relevant for Phase 2)
13. [`.claude/rules/prologos-syntax.md`](../../../.claude/rules/prologos-syntax.md)

### §2.3 Session-Specific — THE ADDENDUM DESIGN STACK (READ IN FULL)

14. [`docs/tracking/2026-04-21_PPN_4C_PHASE_9_DESIGN.md`](../2026-04-21_PPN_4C_PHASE_9_DESIGN.md) — **THE D.3 design. READ IN FULL.** This addendum's primary design document. 966 lines. Contains:
    - §3 Progress Tracker (current state)
    - §4 NTT model (post-Phase-1-3 substrate)
    - §5 Design mantra audit
    - §6 Architectural decisions (Q-A1, Q-A2, Q-A7, Q-A8 resolved; others mini-design items)
    - §7 Phase 1 (sub-phased 1A-i / 1A-ii / 1A-iii / 1B / 1C / 1V) — **§7.3 is the Phase 1A-i deliverables**
    - §8 Phase 2
    - §9 Phase 3
    - §10 Tropical quantale implementation details
    - §11 P/R/M/S self-critique
    - §14 Phase 4 β2 substrate contract
    - §15 Phase 9b interface
    - §16 Mini-design items (Q-A3, Q-A4, Q-A5, Q-A6)

15. [`docs/tracking/2026-04-21_PPN_4C_PHASE_9_AUDIT.md`](../2026-04-21_PPN_4C_PHASE_9_AUDIT.md) — Stage 2 audit. ~800 lines. Key inputs: §3 (state of the art), §3.1 (three worldview paths), §3.9 (Phase 11 state), §4 (reconciliation plan), §8 (work-volume).

16. [`docs/research/2026-04-21_TROPICAL_QUANTALE_RESEARCH.md`](../../research/2026-04-21_TROPICAL_QUANTALE_RESEARCH.md) — Stage 1 research. 1000 lines, 12 sections. Key inputs: §6 (quantale modules), §9 (tropical quantale definition), §10 (Prologos synthesis).

### §2.4 Session-Specific — PARENT DESIGN + NTT

17. [`docs/tracking/2026-04-17_PPN_TRACK4C_DESIGN.md`](../2026-04-17_PPN_TRACK4C_DESIGN.md) — PPN 4C D.3 parent design. This addendum refines §6.7 (Phase 11), §6.10 (Phase 9+10), §6.11.3 (hypercube), §6.15.6 (Phase 3+9 joint item).

18. [`docs/tracking/2026-03-22_NTT_SYNTAX_DESIGN.md`](../2026-03-22_NTT_SYNTAX_DESIGN.md) — NTT syntax reference. D.3 §4 cross-references this; read at least §3 (lattices), §4 (propagators), §6 (bridges), §7 (stratification), §13.3 (known unknowns).

### §2.5 Session-Specific — PRIOR HANDOFF (context continuity)

19. [`docs/tracking/handoffs/2026-04-20_PPN_4C_PHASE_9_HANDOFF.md`](2026-04-20_PPN_4C_PHASE_9_HANDOFF.md) — prior session's handoff (framing B decision; Phase 9 mini-design open). This session implemented that handoff's goals: ran the Phase 9 mini-design conversationally, produced Stage 1/2/3 artifacts.

### §2.6 Session-Specific — RELATED PRIOR ART (referenced by design)

20. [`docs/research/2026-04-06_CELL_BASED_TMS_DESIGN_NOTE.md`](../../research/2026-04-06_CELL_BASED_TMS_DESIGN_NOTE.md) — TMS design note (informed Phase 1 substrate reconciliation framing)
21. [`docs/research/2026-04-08_HYPERCUBE_BSP_LE_DESIGN_ADDENDUM.md`](../../research/2026-04-08_HYPERCUBE_BSP_LE_DESIGN_ADDENDUM.md) — hypercube primitives (Gray code, subcube, all-reduce) — referenced by Phase 3B
22. [`docs/research/2026-03-28_MODULE_THEORY_LATTICES.md`](../../research/2026-03-28_MODULE_THEORY_LATTICES.md) — Module Theory framing used in research doc §6 and Lens S

### §2.7 Session-Specific — CODE FILES FOR PHASE 1A (READ WHEN STARTING)

For Phase 1A-i (next task):
- [`racket/prologos/typing-propagators.rkt`](../../../racket/prologos/typing-propagators.rkt) — lines 313-338 are the Phase 1A-i retirement targets. Also re-grep zero-caller claims at phase start.

For Phase 1A-ii context (carried in design §7.4):
- [`racket/prologos/elaborator-network.rkt`](../../../racket/prologos/elaborator-network.rkt) — lines 114, 921, 995, 1011 are the 4 `net-new-tms-cell` migration sites

For Phase 1A-iii context (carried in design §7.5):
- [`racket/prologos/propagator.rkt`](../../../racket/prologos/propagator.rkt) — `current-speculation-stack` at 1621, fallback paths at 995/1251/3225, `net-new-tms-cell` factory at 1593
- [`racket/prologos/tests/test-tms-cell.rkt`](../../../racket/prologos/tests/test-tms-cell.rkt) — 9 parameterize sites at lines 273-333 for rewrite/retirement

### §2.8 Tracking metadata

23. [`docs/tracking/DEFERRED.md`](../DEFERRED.md) — scaffolding registry. Q-A3 (ATMS retirement) may become a new entry after Phase 1A mini-design completes per-site classification.

---

## §3 Key Design Decisions (RATIONALE — do NOT re-litigate)

Decisions CLOSED this session. Revisiting wastes the work that settled them.

### §3.1 Phase 11 pulled into addendum scope (2026-04-21)

Originally Phase 9+10 addendum; user pulled Phase 11 (orchestration unification) in because the architectural theme is identical: "unify the mechanisms." Both use `register-stratum-handler!`. Doing them together ensures consistent substrate + orchestration design across the combined track's ~9-12 stratum handlers. Captured in audit §3.9.

### §3.2 Phase partitioning — 3 sequential phases, sub-phases A-Z (Q-A1, RESOLVED)

Sequential (single-agent process constraint), not parallel. Phase names: 1 (substrate + tropical fuel), 2 (orchestration), 3 (union types + hypercube). User clarified that mantra's "all in parallel" word is for IMPLEMENTATION, not PROCESS — my initial P4 "Layer 1 parallelism" framing was wrong. Rewritten accordingly.

### §3.3 Tropical fuel as substrate primitive + canonical instance (Q-A2, RESOLVED)

Option 3 per dialogue: SRE domain + primitive API (`net-new-tropical-fuel-cell`, `net-new-tropical-budget-cell`, threshold propagator factory) + canonical BSP scheduler instance at well-known cell-ids 11/12. Per-consumer instances allocate via the primitive; shared tropical quantale enables cross-consumer cost reasoning via Galois bridges.

### §3.4 Phase-specific decisions deferred to mini-design (Q-A3, Q-A4, Q-A5, Q-A6)

Per user direction: "I'm not sure if a larger retirement is what we want, and we should reconsider scope thereon and therefore; I do not take your lean as granted without deeper insight into what is at play." Architectural decisions in design doc §6; phase-specific questions go to §16 mini-design items.

### §3.5 Phase 1A scope revision — Option B sub-split (2026-04-21)

Mini-audit discovered `net-new-tms-cell` is LIVE in production (4 `elaborator-network.rkt` sites). BSP-LE Track 2 PIR's "RETIRED" claim on `current-speculation-stack` was partial — retired speculation uses, not TMS-cell-mechanism uses. Phase 1A grows to ~280-450 LoC via sub-split into 1A-i (dead code), 1A-ii (elaborator migration), 1A-iii (TMS retirement). This IS legitimate scope, not scope creep — it's finishing BSP-LE 2's retirement.

### §3.6 Process improvements codified (2026-04-21)

- **Lens S** (SRE Structural Thinking: PUnify / SRE / Hyperlattice+Hasse / Module-theoretic / Algebraic-structure-on-lattices) added to DESIGN_METHODOLOGY.org Stage 3 §6 and Stage 4 principles challenge mid-flight. Origin: this track.
- **Progress Tracker Placement** discipline: mandatory near-top placement for design docs (§2 or §3). Origin: D.1 → D.2 feedback.
- These updates are committed; NOT persisted into CRITIQUE_METHODOLOGY.org yet (future session opportunity).

### §3.7 Phase 4 β2 contract + Phase 9b interface specified (§14, §15)

Phase 4 (β2 per framing B) and Phase 9b γ hole-fill have interface commitments from this addendum. Detailed design owned by their respective cycles; this addendum commits to providing stable substrate.

---

## §4 Surprises and Non-Obvious Findings

Highest-risk items for the continuation session.

### §4.1 BSP-LE Track 2 PIR overclaim discovered

PIR says `current-speculation-stack` RETIRED. Code shows:
- 3 fallback read sites in `propagator.rkt` (net-cell-read, net-cell-write, net-cell-write-widen)
- `net-new-tms-cell` creates TMS-wrapped cells from day 1 (line 1605: `(tms-cell-value initial-value (hasheq))`)
- 4 production callers in `elaborator-network.rkt` (type cells, mult cells, meta-solution cells)
- Tests in `test-tms-cell.rkt` (9 parameterize sites)

This reshaped Phase 1A from ~100-150 LoC to ~280-450 LoC. It's legitimate completion of prior retirement work, not scope creep.

### §4.2 Dead code vs live code distinction was subtle

`wrap-with-assumption` (correct name; audit mis-named it `wrap-with-assumption-stack`) is dead. `promote-cell-to-tms` is dead. Both trivially retirable. But `net-new-tms-cell` is a LIVE FACTORY that creates cells used by 4 production sites. Grepping function names only doesn't catch this — you have to trace cell creation.

### §4.3 Phase 3 hypercube work is smaller than expected

Audit §3.5 confirmed hypercube primitives are ALREADY IMPLEMENTED:
- `gray-code-order` at `relations.rkt:1874` (BSP-LE 2 Phase 6d-ii)
- `hamming-distance` at `decision-cell.rkt:361`
- `subcube-member?` at `decision-cell.rkt:368`
- Hypercube tree-reduce (all-reduce) at `propagator.rkt:2433-2495`
- Hasse-registry Q_n override pattern at `test-hasse-registry.rkt:238`

Phase 3B is INTEGRATION work, not primary development. ~50-100 LoC.

### §4.4 elab-speculation.rkt is dead library code

189 lines + test file, zero production consumers (only `tests/test-elab-speculation.rkt` references it). Production speculation uses `elab-speculation-bridge.rkt` (`with-speculative-rollback`). Handoff `2026-04-20_PPN_4C_PHASE_9_HANDOFF.md` incorrectly identified it as the speculation bridge. Q-A4 disposition (delete / retain / migrate) is a Phase 3A mini-design item.

### §4.5 NTT syntax cross-referencing revealed subtle errors

D.1's NTT model used `:preserves [Quantale Integral Residuated]` on lattice declarations — but NTT's `:preserves` is for BRIDGES (NTT §6), not lattices. D.2 corrected this to use `trait Quantale` instance pattern per NTT §3.1. Some extensions I used (`:writes :tagged`, `:execution :gray-code-order`, `:fires-once-when`) are sketch extensions flagged as NTT refinement candidates in §4.5 Observations.

### §4.6 Silent-write-drop discipline is load-bearing

Per propagator-design.md and BSP-LE 2B PIR §6: `fire-and-collect-writes` MUST use `net-cell-read-raw` (not `net-cell-read`) for snapshot/diffing. Per-propagator worldview filtering makes tagged entries invisible to ordinary reads — silent write loss. Phase 1A-iii MUST preserve this when editing `net-cell-read`/`net-cell-write` bodies to remove the TMS fallback branch.

### §4.7 Prior handoff's surprises remain valid

All from [Phase 9 handoff §4](2026-04-20_PPN_4C_PHASE_9_HANDOFF.md#4-surprises-and-non-obvious-findings):
- Framing B decision (Phase 9 before Phase 4)
- Cell is not a lattice
- PUnify reach richer than D.2 assumed
- that-read 1400× faster than CHAMP

Still load-bearing.

---

## §5 Open Questions and Deferred Work

### §5.1 Phase 1A implementation (NEXT)

- **Phase 1A-i** (immediate): dead code cleanup, ~30-50 LoC. Mechanical. No blockers.
- **Phase 1A-ii** (after 1A-i): mini-audit at phase start per methodology. Expected focus:
  - Confirm `make-tagged-merge` handles 3 domain-merge compositions (type-lattice-merge, mult-lattice-merge, merge-meta-solve-identity)
  - Decide `net-new-tms-cell` signature retention vs direct `net-new-cell` expose
  - Parity test design for speculation semantics
  - Whether `with-speculative-rollback` needs any updates
- **Phase 1A-iii** (after 1A-ii): Q-A3 / Q-A4 / Q-A5 resolution required:
  - Q-A3 retirement scope (deprecated atms struct / atms-believed / surface AST)
  - Q-A4 test-tms-cell.rkt disposition
  - Q-A5 atms-believed timing (coupled to Q-A3)
  - Dependency grep for anything transitively using `tms-cell-value`, `tms-read`, `tms-write`, `tms-commit`, `merge-tms-cell`, `make-tms-merge`

### §5.2 Phase 1B, 1C, Phase 2, Phase 3

Per design doc §7-§9. Each has mini-design items in §16.

### §5.3 Q-A3 deeper scope (deferred per user direction)

User flagged: "I want to visit this in the design discussion on the phase. I think there is a lot to unpack here, and needs its own treatment." The Phase 1A-iii mini-design is where this gets deep treatment. User wants A/B microbench data and informed decisions, not pre-committed leans.

### §5.4 Process improvements — not yet persisted

- **Lens S in CRITIQUE_METHODOLOGY.org**: currently in DESIGN_METHODOLOGY.org Stage 3/4 but not yet in the dedicated critique methodology document. Future session opportunity.
- **DEFERRED.md entry** for ATMS retirement: pending Phase 1A-iii outcome

### §5.5 Prior deferrals STILL OPEN from parent design

All PPN 4C D.3 deferrals (Phase 9b γ hole-fill, Phase 11b diagnostic infrastructure, Phase 12a-d Option C zonk retirement, etc.) remain scheduled. This addendum delivers Phase 9+10+11; those others are separate phases on D.3's roadmap.

---

## §6 Process Notes

### §6.1 Codified this session

- **Lens S** (SRE Structural Thinking) — added to DESIGN_METHODOLOGY.org Stage 3 §6 Self-Critique and Stage 4 Implementation Protocol §3 Principles-challenge mid-flight
- **Progress Tracker Placement** — new discipline in DESIGN_METHODOLOGY.org Stage 3 Artifacts, requiring tracker near top of design documents
- **Phase 1A mini-design dialogue pattern** — validated: start with design target note (methodology Step 1), open questions, optional mini-audit, scope resolution via dialogue

### §6.2 Validated process patterns (still active)

- Mini-design at start of each sub-phase (§16 items are the raw material; phase-start dialogue resolves)
- Conversational cadence — max ~1h autonomous stretch
- User pushback catches framing errors ("mantra is for implementation, not process"; "scope not pre-committed")
- Lens discipline (P/R/M/S) applied inline in design drafting, not only in dedicated critique round
- Commit discipline: one commit per code change; tracker update + dailies together or fast-follow
- `.org` files canonical for principles docs; methodology edits go to `.org`

### §6.3 Commit span this session

From prior handoff's last commit `cbf4020d` through this session's end `b6d8a9c1`. Key landmarks:
- `de357aa1` — Stage 1 research (tropical quantale, 1000 lines)
- `62ce9f83` — Stage 2 audit initial (689 lines)
- `28208613` — Audit §3.9 Phase 11 appendix
- `dfcb7460` — D.1 design (945 lines)
- `42ca336c` — D.2 refinements + methodology updates (Lens S, tracker placement)
- `b6d8a9c1` — D.3 Phase 1A scope revision

### §6.4 Conversational cadence for multi-sub-phase work

Phase 1A's three sub-phases have different risk profiles. 1A-i is low-risk dead-code cleanup; 1A-ii is highest-risk (production migration); 1A-iii depends on 1A-ii outcome. Handle each at its own mini-design pace. Don't bundle.

---

## §7 What the Continuation Session Should Produce

### §7.1 Immediate (Phase 1A-i)

1. Hot-load every §2 document IN FULL
2. Summarize understanding back to user; validate
3. Execute Phase 1A-i implementation (steps in §1 "Next immediate task")
4. Commit 1A-i
5. Update D.3 tracker: 1A-i ⬜ → ✅ with commit hash
6. Append to current dailies (or create new if past daily boundary)
7. Ready for Phase 1A-ii mini-design dialogue

### §7.2 Medium-term (Phase 1A-ii, 1A-iii)

- Phase 1A-ii mini-design (at phase start): audit `make-tagged-merge` composition; design migration shape; parity test skeleton
- Phase 1A-ii implementation: migrate 4 elaborator-network.rkt sites
- Phase 1A-iii mini-design: deep dialogue on Q-A3 / Q-A4 / Q-A5; grep for dependencies
- Phase 1A-iii implementation: retire TMS mechanism + current-speculation-stack + fallback paths

### §7.3 Longer-term (rest of addendum)

Phase 1B (tropical fuel primitive), Phase 1C (fuel migration), Phase 1V, Phase 2A/2B/2V, Phase 3A/3B/3C/3V, Phase V capstone.

---

## §8 Final Notes

### §8.1 What "I have full context" requires (per HANDOFF_PROTOCOL §Hot-Load Reading Protocol)

- Read EVERY document in §2 IN FULL
- Articulate EVERY decision in §3 with rationale (especially §3.5 Phase 1A scope revision — the key this-session finding)
- Know EVERY surprise in §4
- Understand the open questions in §5.1 but DO NOT pre-resolve them

Good articulation: "Phase 1A scope grew from D.2's ~100-150 LoC to D.3's ~280-450 LoC because the mini-audit discovered `net-new-tms-cell` is LIVE in production via 4 elaborator-network.rkt sites (not just test fixtures as BSP-LE Track 2 PIR implied). Phase 1A now sub-splits into 1A-i (dead code), 1A-ii (elaborator migration), 1A-iii (TMS mechanism retirement). 1A-i is the immediate next work: delete `wrap-with-assumption` and `promote-cell-to-tms` in typing-propagators.rkt — both zero-caller dead code."

### §8.2 User-preference patterns observed this session

- **Concrete over abstract**: "I need something tangible to sound against" — the user pushed D.1 from question-heavy to concrete-drafting. In the design doc, concrete code examples, specific cell-ids, specific function signatures are preferred.
- **Data-led reasoning**: "microbenchmarking ... measured reality ... our sometimes optimistic intuition or cost reasoning are often tempered with measured reality." A/B benches at sub-phase boundaries are expected (see Phase 1C, 1A-ii parity tests).
- **Conversational cadence, not unilateral drafts**: the user pushes back when I pre-resolve. The right pattern is: surface question, propose options with leans, defer to dialogue. The user's question-answer rhythm drives design commitment; I don't commit solo.
- **Principled depth**: user wants theoretical grounding AND engineering pragmatism. The Stage 1 research (1000 lines, quantale theory) + Stage 2 audit (grep-backed) + Stage 3 design with P/R/M/S matches this.

### §8.3 Gratitude

This session produced substantial artifacts because the user kept redirecting when I drifted:
- "That's not how we do phase design" earlier corrected unilateral drafting
- "Mantra is for implementation, not process" corrected a lens misapplication
- "I do not take your lean as granted without deeper insight" preserved design option space
- The user's instinct to scrutinize my leans repeatedly surfaced better framings

Honor this pattern. Surface questions with leans, invite pushback, wait for dialogue, then commit.

The context is in safe hands.
