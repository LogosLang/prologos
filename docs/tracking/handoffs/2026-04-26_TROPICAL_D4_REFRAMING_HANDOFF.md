# PPN 4C Tropical Quantale Addendum — D.4 Architectural Reframing + §13.6 Spike Continuation Handoff

**Date**: 2026-04-26 (D.4 scaffolding pass complete; Cell/Propagator/Scheduler Orthogonality principle codified; §13.6 Pre-0 spike pending — the falsification test)
**Purpose**: Transfer context into a continuation session to pick up **§13.6 Pre-0 spike execution → D.4 vs D.3 commit decision → completion of revised Phase 1B/1C design under chosen architecture**.

**Before reading anything else**: read [`HANDOFF_PROTOCOL.org`](../principles/HANDOFF_PROTOCOL.org). The Hot-Load Reading Protocol requires reading EVERY §2 document IN FULL before summarizing understanding back to the user. Hot-load is a PROTOCOL, not a prioritization — codified at [`DEVELOPMENT_LESSONS.org`](../principles/DEVELOPMENT_LESSONS.org) § "Hot-Load Is a Protocol, Not a Prioritization" (8+ data points across sessions; user explicitly enforces).

**CRITICAL meta-lessons from this session arc** — read these BEFORE anything else:

1. **The rare design state where two architectures are live simultaneously**: D.4 (on-network specialized cell type) is the PREFERRED architecture (principle-aligned per Cell/Propagator/Scheduler Orthogonality); D.3 (hybrid pivot) is the FALLBACK (empirically-grounded). §13.6 Pre-0 spike acts as the FALSIFICATION TEST that decides which architecture ships. Per discipline (newly codified): never extrapolate a principle-violating commit when the alternative can be directly measured.

2. **Cell/Propagator/Scheduler Orthogonality is now a load-bearing principle** (codified 2026-04-26 in DESIGN_PRINCIPLES.org). The architecture has three orthogonal layers; optimizations should be located at the layer that owns the concern. Mixing layers breaks scheduler-portability AND violates CALM's order-independence. This principle is prophylactic for PReduce, OE, SH Series tracks — without it, hybrid scaffolding would propagate as the de facto template across multiple tracks (compounding architectural debt).

3. **D.3 critique findings (18 from D.2.SC + 11 from D.3.EC = 29 total) status under D.4**: 18 become MOOT under the on-network reframing (the architectural reframing eliminates the underlying concerns rather than addressing piecemeal); 4 remain RELEVANT (S3, S4, S5, EX1, MG2 — multi-quantale composition + external positioning, orthogonal to cell substrate concerns). The full D.2.SC + D.3.EC + D.4 critique-resolution work in this session arc is captured in the D.4 Revision Summary table at the top of the design doc.

4. **The orthogonality principle emerged from user-articulated insight during D.3.EC critique resolution** — specifically Group 1 batch acceptance review. The user said: "If we're using off-network scaffolding to optimize, and that we'll need to retire with the PReduce/SH series anyways... PReduce series, we're planning on working through next, so we'd be potentially facing the same sort of concern. I'm wondering if there's an optimization path that we haven't considered, that would be more sustainable long-term." This reframed the entire hybrid pivot decision and led to D.4.

5. **Pre-0's MG1 gap (cell-write not measured pre-commit) became load-bearing**: Pre-0 R-19 measured struct-copy + extrapolated to cell-write. The extrapolation was reasonable but UNVERIFIED. D.3.EC MG1 surfaced this as a finding; the user's response made it load-bearing (the hybrid pivot rested on an unverified extrapolation; the alternative SHOULD be measured). §13.6 spike directly addresses this gap.

6. **§4.6 Specialized cell type framework composes Options A+B+C+D from D.3.EC exploration**:
   - A: Cell-as-Box with adaptive storage (`:storage 'monotone-counter`)
   - B: Threshold-as-cell-property (`:on-write-check` predicate)
   - C: Propagator-fire skip for monotone counters (`:fires-on 'threshold-crossing`)
   - D: Hot/warm/cold cells (`:tier 'hot`)
   - Composition: cell registration declares all four properties; cell mechanism dispatches accordingly
   - Scheduler-neutral: all optimization at cell layer per orthogonality principle
   - Implementation cost: ~250-450 LoC for Phase 1B (framework + fuel-cost cell registration + tests)

7. **§13.6 spike scope** (the falsification test):
   - Mock the specialized cell mechanism (~100-200 LoC throwaway in `benchmarks/micro/bench-specialized-cell-spike.rkt`)
   - Measure 5 dimensions (W1-W5): cell-write fast path; on-write-check trigger; GC profile at 100k; cell-read; speculation fallback
   - Decision criteria: PASS (D.4 canonical), FAIL (D.3 hybrid fallback), MIXED (re-design)
   - Execution time: ~30-60 min including bench run

8. **Session arc deliverables** (this session, picking up from prior `ffab0079`):
   - Critique resolution: D.2.SC 18 findings closed across 10 commits (`0538582f` through `76a73ada`)
   - D.3.EC external critique drafted (`61d7ab07`)
   - D.4 architectural reframing initiated (`6a628bc7` orthogonality principle codification)
   - D.4 scaffolding pass (`45181c07` §4.6 framework + §13.6 spike plan + supersession notes)
   - **Total: 13 commits + 3 critique/design documents**

---

## §1 Current Work State (PRECISE)

- **Track**: PPN Track 4C Phase 9+10+11 Addendum — substrate + orchestration unification (per D.3 parent)
- **Sub-track**: Tropical Quantale Addendum — Phase 1A-iii-b + 1A-iii-c + 1B + 1C + 1V (γ-bundle-wide per Q-A3)
- **Stage**: Stage 3 Design — **D.4 architectural reframing scaffolding complete; §13.6 Pre-0 spike pending**
- **Conditional commit state**: D.4 PREFERRED (on-network specialized cell type) vs D.3 FALLBACK (hybrid pivot); §13.6 spike decides
- **Last commit**: `45181c07` (D.4 scaffolding pass — §4.6 framework + §13.6 spike plan + supersession notes)
- **Branch**: `main` (ahead of origin/main by many commits; don't push unless directed)
- **Working tree**: clean except pre-existing user-managed changes (standup edits, benchmark data, deleted .md files with .org versions, .prologos file edits)
- **Suite state**: 7914 tests / 119.3s / 0 failures (per S2.e-v close `118ab57a`; not re-run this session)

### Session arc commits (2026-04-26 continuing from `ffab0079` Pre-0 S-tier prep)

| Commit | Focus |
|---|---|
| `0538582f` | D.3 first revision — 3 BLOCKING findings from D.2.SC accepted + applied (P3 staleness + M1 propagator role + S1 §14.4 Q5) |
| `934b2ba3` | D.3 — P1 REFINEMENT accepted; Issue #55 opened (hybrid pivot scaffolding retirement under SH Series) |
| `db15bece` | D.3 — P2 REFINEMENT accepted (Q-1B-6 spike + §11.3 final-verification gate) |
| `a4cbbbfc` | D.3 — P4 consolidated with P1 into §10.1.A "Honest framing & retirement plan" |
| `9c014389` | D.3 — P6 REFINEMENT accepted (§6.6 + MASTER_ROADMAP.org hybrid-as-scaffolding-NOT-template caveat) |
| `c1a1e5c8` | D.3 — P5 ACKNOWLEDGE accepted (γ-bundle sub-phase count precision); P-lens complete (6/6) |
| `072eea14` | D.3 — R1 REFINEMENT accepted (Phase 1C ~45-90 LoC hybrid-aware vs ~250-400 D.1) |
| `00fe67cc` | D.3 — R2 REFINEMENT accepted (Q-Audit-1 17-refs rescoping under hybrid) |
| `9cf19ce7` | D.3 — R4 REFINEMENT accepted (Phase 1V microbench list expanded to 11 re-runs) |
| `76a73ada` | D.3 — R3 + batch (M2 + M3 + S2 + S3 + S4 + S5) accepted; **D.2.SC RESOLUTION COMPLETE** (18/18) |
| `61d7ab07` | D.3.EC external critique drafted (11 findings; CL/MG/SP/OS/TD/AP/TS/EX/MB lenses) |
| **`6a628bc7`** | **Cell/Propagator/Scheduler Orthogonality principle codified** — architectural reframing initiated |
| **`45181c07`** | **D.4 scaffolding pass** — §4.6 specialized cell type framework + §13.6 Pre-0 spike plan + supersession notes |

### Design state snapshot (2026-04-26 session close)

| Sub-phase | Status | Notes |
|---|---|---|
| Stage 1 research | ✅ `de357aa1` | TROPICAL_QUANTALE_RESEARCH.md (~1000 lines) |
| Stage 2 audits | ✅ This session | Q-Audit-1/2/3 |
| Stage 3 D.1 draft | ✅ `fc4b9d3e` | 1179 lines / 18 sections |
| Pre-0 plan + execution | ✅ M+A+E+R+S complete | 22 cumulative design-affecting findings |
| D.2 hybrid pivot commit | ✅ `2a4d938c` | Phase 1C reframed to hybrid |
| D.2.SC self-critique | ✅ `219d8eb9` | 18 findings P/R/M/S |
| **D.3 critique resolution** | ✅ Complete | 18/18 D.2.SC findings closed; 10 commits |
| **D.3.EC external critique** | ✅ Drafted `61d7ab07` | 11 findings via fresh lenses |
| **Orthogonality principle codification** | ✅ `6a628bc7` | DESIGN_PRINCIPLES.org + cross-references |
| **D.4 scaffolding pass** | ✅ `45181c07` | §4.6 + §13.6 + supersession notes |
| **§13.6 Pre-0 spike** | ⬜ **NEXT SESSION** | Falsification test for D.4 vs D.3 |
| D.4 full Phase 1B/1C revision | ⬜ Pending spike result | If D.4 passes |
| D.4 vs D.3 commit | ⬜ Pending spike | One architecture ships |
| Stage 4 implementation | ⬜ Per-phase mini-design+audit | Post-D.4-or-D.3 decision |

### Next immediate task — §13.6 Pre-0 spike

Per the new §13.6 plan in D.4:

**Spike scope** (~30-60 min + ~100-200 LoC throwaway):
1. Implement mock specialized cell mechanism in `benchmarks/micro/bench-specialized-cell-spike.rkt`:
   - Direct-counter-cell storage (unboxed fixnum; no `tagged-cell-value` wrapping under no-speculation)
   - Inline on-write check predicate (no propagator-fire ceremony)
   - Fire-on-threshold-crossing notification (most writes don't notify dependents)
   - Hardcode hot+monotone-counter dispatch (skip full cell-meta framework)

2. Measure 5 dimensions (W1-W5):
   - **W1**: Specialized cell-write cost (no-speculation; no threshold crossing) — target ≤ 30 ns/call
   - **W2**: Specialized cell-write cost (threshold crossing; contradiction written) — rare; target ≤ 200 ns/call
   - **W3**: Specialized cell-write GC profile at 100k decrements — target ZERO major-GC
   - **W4**: Specialized cell-read cost — target ≤ 15 ns/call
   - **W5**: Specialized cell-write under speculation (tagged-cell-value fallback) — reference

3. Decision criteria:
   - **PASS**: W1 ≤ 30 ns + W3 = ZERO major-GC + W4 ≤ 15 ns + (W1+W4) ≤ 45 ns
   - **FAIL**: W1 > 60 ns OR W3 > 0 major-GC at 100k OR (W1+W4) > 60 ns
   - **MIXED**: cell-write fast but GC-pressured (or vice-versa); investigate sub-options

### Conditional next steps after spike

**If D.4 PASSES** (specialized cell-write within 25-50% of struct-copy + zero major-GC):
1. Complete D.4 §9 Phase 1B full revision (specialized cell framework implementation plan; ~250-450 LoC)
2. Complete D.4 §10 Phase 1C full revision (direct migration patterns + sub-phase plan; ~150-250 LoC)
3. Update D.4 §15 parity test skeleton for D.4
4. Update Pre-0 plan separate doc cross-reference to D.4
5. Close GitHub Issue #55 as "superseded by D.4 principled on-network design"
6. Retire DEFERRED.md "PPN 4C tropical addendum: hybrid pivot scaffolding retirement" entry
7. Mark D.3 hybrid-specific sections as PERMANENTLY SUPERSEDED (the SUPERSEDED-BY-D.4 status becomes RETIRED-PER-D.4-CANONICAL)
8. Commit D.4 canonical state
9. Open Stage 4 implementation (Phase 1B first per Q-Open-4 strict sequencing)

**If D.4 FAILS** (cell-write significantly costlier OR major-GC pressure):
1. Mark §4.6 + §13.6 + D.4 Revision Summary as "explored alternative; falsified by spike"
2. D.3 hybrid pivot becomes canonical
3. Remove SUPERSEDED-BY-D.4 annotations from §10.1.A + §10.A + §10.B + §14.4 (they remain D.3-canonical content)
4. Document the spike result in dailies + add codification candidate: "when extrapolation justifies a principle-violating commit, direct measurement IS the falsification discipline; the spike validates the empirical justification"
5. Issue #55 remains active (hybrid pivot scaffolding retirement under SH Series)
6. Pre-0 plan retains hybrid pivot framing
7. Commit D.3 canonical state with D.4 falsification documented
8. Open Stage 4 implementation under D.3 hybrid

---

## §2 Documents to Hot-Load (ORDERED — NO TIERING)

**CRITICAL**: per the codified hot-load-is-protocol rule, read EVERY document IN FULL. NO tiering. ~500K-700K token budget anticipated. User will explicitly enforce.

### §2.0 Start here

0. [`HANDOFF_PROTOCOL.org`](../principles/HANDOFF_PROTOCOL.org)

### §2.1 Always-Load

1. [`CLAUDE.md`](../../../CLAUDE.md) + [`CLAUDE.local.md`](../../../CLAUDE.local.md)
2. [`MEMORY.md`](../../../MEMORY.md) — auto-memory
3. [`DESIGN_METHODOLOGY.org`](../principles/DESIGN_METHODOLOGY.org) — Stage 3 critical
4. **[`DESIGN_PRINCIPLES.org`](../principles/DESIGN_PRINCIPLES.org)** — **NEW SECTION at end: Cell/Propagator/Scheduler Orthogonality** (load-bearing for D.4)
5. [`CRITIQUE_METHODOLOGY.org`](../principles/CRITIQUE_METHODOLOGY.org) — D.2.SC + D.3.EC discipline; Receiving External Critique grounded pushback
6. [`HANDOFF_PROTOCOL.org`](../principles/HANDOFF_PROTOCOL.org) (self-reference)
7. [`docs/tracking/MASTER_ROADMAP.org`](../MASTER_ROADMAP.org) — OE Series caveat updated to Orthogonality inheritance discipline
8. [`docs/tracking/2026-03-26_PPN_MASTER.md`](../2026-03-26_PPN_MASTER.md) — parent series
9. [`DEVELOPMENT_LESSONS.org`](../principles/DEVELOPMENT_LESSONS.org) — NEW lesson "Cell/Propagator/Scheduler Orthogonality — Codified Architectural Principle"

### §2.2 Architectural Rules (loaded via `.claude/rules/`)

10. [`.claude/rules/on-network.md`](../../../.claude/rules/on-network.md) — UPDATED with orthogonality cross-reference + constraint extension
11. [`.claude/rules/structural-thinking.md`](../../../.claude/rules/structural-thinking.md) — SRE lattice lens
12. [`.claude/rules/propagator-design.md`](../../../.claude/rules/propagator-design.md) — UPDATED with orthogonality cross-reference + anti-pattern catch (rejecting Option E historical example)
13. [`.claude/rules/workflow.md`](../../../.claude/rules/workflow.md) — adversarial VAG + critique discipline + microbench-claim verification
14. [`.claude/rules/testing.md`](../../../.claude/rules/testing.md) — full suite as regression gate; targeted test discipline
15. [`.claude/rules/pipeline.md`](../../../.claude/rules/pipeline.md) — § "Per-Domain Universe Migration" template
16. [`.claude/rules/stratification.md`](../../../.claude/rules/stratification.md) — strata as module composition
17. [`.claude/rules/mempalace.md`](../../../.claude/rules/mempalace.md)
18. [`.claude/rules/prologos-syntax.md`](../../../.claude/rules/prologos-syntax.md)

### §2.3 THE active design + critique documents (READ IN FULL)

19. **[`docs/tracking/2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_DESIGN.md`](../2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_DESIGN.md)** — **D.4 scaffolding complete**. Key sections to read:
    - **D.4 Revision Summary at top** — 22-row table mapping all D.2.SC + D.3.EC findings to D.4 status (most MOOT under reframing); conditional commit state
    - **D.3 Revision Summary (SUPERSEDED)** — D.2.SC critique resolutions; preserved for traceability
    - **§4.6 NEW** — Specialized cell type framework NTT model (composes Options A+B+C+D)
    - **§4.5 UPDATED** — `:fires-when` extension note status under D.4
    - **§10 reframed** — D.4 reconsideration note at top; D.4 Phase 1C revised scope sketched; D.3 hybrid content preserved
    - **§10.1.A + §10.A + §10.B** — marked SUPERSEDED BY D.4; D.3 content preserved
    - **§13.6 NEW** — Pre-0 spike plan (W1-W5 measurements; PASS/FAIL/MIXED decision criteria)
    - **§14.4 Q5** — dual classification reframed; reverts to single PRIMARY if D.4 passes
    - **§17 What's next** — UPDATED with full D.4 trajectory (11-step) + 5 new D.4 adversarial questions
    - **Document status** — D.4 trajectory; conditional commit state

20. **[`docs/tracking/2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_SELF_CRITIQUE.md`](../2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_SELF_CRITIQUE.md)** — D.2.SC; 18 findings; RESOLUTION COMPLETE under D.3; status under D.4 captured in D.4 Revision Summary table

21. **[`docs/tracking/2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_EXTERNAL_CRITIQUE.md`](../2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_EXTERNAL_CRITIQUE.md)** — D.3.EC; 11 findings (CL/MG/SP/OS/TD/AP/TS/EX/MB); user's response to Group 1 review was the orthogonality insight that reshaped to D.4

22. [`docs/tracking/2026-04-26_TROPICAL_ADDENDUM_PRE0_PLAN.md`](../2026-04-26_TROPICAL_ADDENDUM_PRE0_PLAN.md) — Pre-0 plan; 22 findings; needs §13.6 cross-reference update next session

23. [`docs/tracking/2026-04-21_PPN_4C_PHASE_9_DESIGN.md`](../2026-04-21_PPN_4C_PHASE_9_DESIGN.md) — D.3 parent addendum (Phase 9 design)

24. [`docs/tracking/2026-04-17_PPN_TRACK4C_DESIGN.md`](../2026-04-17_PPN_TRACK4C_DESIGN.md) — PPN 4C parent track

### §2.4 Stage 1 Research (foundational; READ IN FULL)

25. [`docs/research/2026-04-21_TROPICAL_QUANTALE_RESEARCH.md`](../../research/2026-04-21_TROPICAL_QUANTALE_RESEARCH.md) — Stage 1 doc
26. [`docs/research/2026-03-28_MODULE_THEORY_LATTICES.md`](../../research/2026-03-28_MODULE_THEORY_LATTICES.md)
27. [`docs/research/2026-03-28_ALGEBRAIC_EMBEDDINGS_LATTICES.md`](../../research/2026-03-28_ALGEBRAIC_EMBEDDINGS_LATTICES.md)
28. [`docs/research/2026-03-22_STRUCTURAL_REASONING_ENGINE.md`](../../research/2026-03-22_STRUCTURAL_REASONING_ENGINE.md)
29. [`docs/research/2026-04-22_ATTRIBUTE_GRAMMAR_UNIFICATION_VISION.md`](../../research/2026-04-22_ATTRIBUTE_GRAMMAR_UNIFICATION_VISION.md)
30. [`docs/research/2026-03-26_PARALLEL_PROPAGATOR_SCHEDULING.md`](../../research/2026-03-26_PARALLEL_PROPAGATOR_SCHEDULING.md) — NEW RELEVANCE under orthogonality (PAR Series scheduler-independence)

### §2.5 Baseline data + reference

31. [`racket/prologos/data/benchmarks/tropical-pre0-baseline-2026-04-26.txt`](../../../racket/prologos/data/benchmarks/tropical-pre0-baseline-2026-04-26.txt) — 189 lines; full M+A+E+R+S baselines
32. [`docs/tracking/2026-04-23_STEP2_BASELINE.md`](../2026-04-23_STEP2_BASELINE.md) — §6 measurement discipline
33. [`docs/tracking/DEFERRED.md`](../DEFERRED.md) — UPDATED with hybrid pivot scaffolding retirement entry (status pending §13.6 spike outcome)

### §2.6 Code files (current state at this handoff)

34. [`racket/prologos/benchmarks/micro/bench-ppn-track4c.rkt`](../../../racket/prologos/benchmarks/micro/bench-ppn-track4c.rkt) — bench infrastructure; spike will add new section
35. [`racket/prologos/propagator.rkt`](../../../racket/prologos/propagator.rkt) — `make-prop-network` line 81; `prop-net-cold` struct line 337; `prop-network-fuel` macro line 399; 17 production refs
36. [`racket/prologos/atms.rkt`](../../../racket/prologos/atms.rkt) — Tier 2 retirement target
37. [`racket/prologos/syntax.rkt`](../../../racket/prologos/syntax.rkt) — Tier 3 retirement target

### §2.7 Dailies + standup

38. **[`docs/tracking/standups/2026-04-26_dailies.md`](../standups/2026-04-26_dailies.md)** — **~1936 lines** after this session's massive additions; full session arc narrative:
    - Pre-0 S-tier execution + 3 findings (initial session opening)
    - D.2 hybrid pivot commit
    - D.2.SC self-critique drafted + 18 findings closed across 10 sub-phases
    - D.3.EC external critique drafted (11 findings)
    - **Major reframing**: Cell/Propagator/Scheduler Orthogonality codified
    - D.4 scaffolding pass with conditional commit state explained
39. [`docs/tracking/standups/2026-04-23_dailies.md`](../standups/2026-04-23_dailies.md) — prior dailies (closed)
40. [`docs/standups/standup-2026-04-26.org`](../../standups/standup-2026-04-26.org) — user's standup (write-once; read-only)

### §2.8 Prior handoffs (session arc context)

41. [`docs/tracking/handoffs/2026-04-26_TROPICAL_PRE0_STIER_DOTWO_HANDOFF.md`](2026-04-26_TROPICAL_PRE0_STIER_DOTWO_HANDOFF.md) — earlier handoff this session arc (Pre-0 S-tier + D.2 revise opening)
42. [`docs/tracking/handoffs/2026-04-26_TROPICAL_PRE0_ATIER_HANDOFF.md`](2026-04-26_TROPICAL_PRE0_ATIER_HANDOFF.md) — even earlier (A-tier opening)
43. [`docs/tracking/handoffs/2026-04-26_PPN_4C_TROPICAL_ADDENDUM_HANDOFF.md`](2026-04-26_PPN_4C_TROPICAL_ADDENDUM_HANDOFF.md) — earliest (tropical addendum opening)

---

## §3 Key Design Decisions (RATIONALE — do NOT re-litigate)

### §3.1 γ-bundle-wide for Phase 1 scope (PRESERVED from D.1; Q-A3)

1A-iii-b + 1A-iii-c + 1B + 1C + 1V all in addendum. ~12-15 implementation sub-phases under γ-bundle-wide.

### §3.2 D.3 scaffolding treated as draft D.0 (PRESERVED from D.1; Q-Open-1)

D.1+ refines + verifies + extends D.3 parent. Don't re-derive.

### §3.3 Multi-quantale composition NTT in scope (PRESERVED from D.1; Q-Open-3 β)

D.4 §4.2 covers TypeFacetQ + TropicalFuelQ co-existence as independent Q-modules. S3+S4 critique findings remain RELEVANT under D.4 (multi-quantale composition completeness + quantaloid forward-compat).

### §3.4 Phase 3C cross-reference capture (PRESERVED; Q-Open-2)

Form A + Form B + Form C deferred per capture-gap discipline.

### §3.5 Strict sequencing per pipeline.md template (PRESERVED; Q-Open-4)

1B substrate ships before 1C consumer migration.

### §3.6 Memory as first-class measurement axis (PRESERVED + REINFORCED)

Validated by Pre-0 R-19 (R3 zero-major-GC). §13.6 spike measures GC profile directly.

### §3.7 **Cell/Propagator/Scheduler Orthogonality is LOAD-BEARING (NEW per `6a628bc7`)**

The architecture has three orthogonal layers; optimizations at the layer that owns the concern. Anti-pattern: scheduler-coupled optimization (rejected Option E historical example). Codified in DESIGN_PRINCIPLES.org as top-level principle.

**Implications for D.4 and future tracks**:
- D.4 specialized cell type framework (§4.6) lives at CELL layer (storage strategy + on-write check + fire-on policy)
- The threshold check is INLINE at cell write (not a separate propagator) — eliminates propagator-as-decoration concern
- Scheduler-neutral: Gauss-Seidel, BSP, Zig-LLVM, future schedulers all run the network identically
- Future PReduce + OE Series inherit the framework, not the hybrid scaffolding pattern

### §3.8 **D.4 architectural reframing (NEW per `45181c07`)**

D.4 = D.3 + Orthogonality principle applied. Specialized cell type framework replaces hybrid pivot scaffolding. **Conditional commit**: §13.6 spike decides D.4 vs D.3.

**The reframing rationale**:
- D.3 hybrid pivot's "off-network struct field as live state" violates Cell-as-Single-Source-of-Truth
- D.3 was empirically motivated by R-19 EXTRAPOLATION (cell-write would trigger major GC); never directly measured
- D.4 reframes: extend the CELL mechanism (not scheduler) with specialized storage strategy; direct fixnum mutation under no-speculation; inline on-write check; fire-on-threshold-crossing
- Falsification test: §13.6 spike directly measures specialized cell-write vs struct-copy baseline

### §3.9 Conditional commit state (NEW per D.4)

The rare design state where two architectures are live simultaneously:
- **D.4** (PREFERRED): on-network specialized cell type; principle-aligned per Orthogonality; framework reusable by PReduce + OE
- **D.3** (FALLBACK): hybrid pivot; empirically-grounded if D.4 spike fails; scaffolding retirement under SH Series per Issue #55

§13.6 spike decides. After spike, exactly one architecture ships; the other retires.

**Discipline (newly codified)**: NEVER extrapolate a principle-violating commit when the alternative can be directly measured.

### §3.10 D.2.SC + D.3.EC finding status under D.4

| Status under D.4 | Count | Examples |
|---|---|---|
| MOOT (architectural reframing eliminates concern) | 18 | P1-P6 hybrid pivot concerns; M1 propagator decoration; M2 imperative dispatch; M3 imposed ordering; S1 §14.4 Q5 inconsistency; R1 Phase 1C estimate; R2 17-refs framing; TD1 four-surface tracking; MB1 retirement checklist; CL1/CL2 sprawl/tractability; AP1 naming asymmetry; OS1 propagator over-specification; SP1 §10 sprawl; TS1 staleness contract tests |
| RESOLVED differently | 4 | M1 (threshold is cell predicate); S1 (Q5 single classification); MG1 (directly measured via §13.6) |
| UNCHANGED (still relevant) | 5 | S3 multi-quantale completeness; S4 quantaloid forward-compat; S5 C-series gate; EX1 e-graph positioning; MG2 multi-worldview cell-write (deferred to Phase 3A) |

Full detail at D.4 Revision Summary table.

### §3.11 Cross-cutting concerns matrix (UNCHANGED from D.3)

| Parent Track Phase | Addendum interaction | Notes |
|---|---|---|
| Step 2 ✅ CLOSED | Tropical fuel cells co-exist with type meta universe cells | No interference |
| **Phase 1B + 1C + 1V (this addendum)** | D.4 specialized cell type OR D.3 hybrid (spike decides) | Per §13.6 |
| Phase 1E | AFTER addendum implementation lands | 5 carry-forward Q1-Q5 |
| Phase 2 (orchestration) | Independent | Likely after Phase 1E |
| Phase 3A/B/C | Phase 3C consumes tropical residuation operator | Forward-captured |
| Phase 4 (CHAMP retirement) | Coordinates with PM Track 12 | Orthogonal |
| Track 4D | Per-command transient consolidation | Forward-captured |
| **Future PReduce series** | **Inherits §4.6 specialized cell framework** (if D.4 passes) | Architectural template, not hybrid scaffolding |
| **OE Series** | First production landing | Per MASTER_ROADMAP.org § OE; Orthogonality inheritance discipline |

---

## §4 Surprises and Non-Obvious Findings

### §4.1 User-articulated insight reshaped the design mid-resolution

The Cell/Propagator/Scheduler Orthogonality principle emerged from user critique-resolution dialogue, not from my analytical exploration. Specifically:
- Group 1 batch acceptance review (MG1+MG2+CL2+MB1 from D.3.EC)
- User raised: "If we're using off-network scaffolding to optimize, and that we'll need to retire with the PReduce/SH series anyways..."
- User then: "We've explored three scheduler implementations without changes to the network computation... it is conceivable that we could have arbitrary number of different schedulers to run the same network — even in different languages."
- User's concern: "coupling too much on the scheduler, complecting what should be orthogonal — making a thin scheduler and portability more tricky"

This reframed the hybrid pivot decision entirely. The principle was codified immediately (not as a watching-list candidate) because:
- Foundational principle with multi-track impact
- Without it, PReduce + OE + SH Series would re-derive the same conclusion (compounding architectural debt)
- Cost of one codification session ≈ multi-session × N tracks if re-derived per track

### §4.2 Pre-0's MG1 measurement gap was load-bearing

Pre-0 R-19 ("zero major-GC during 100k struct-copy decrements") was used to extrapolate "cell-write at the same rate would trigger major-GC pressure." The extrapolation was REASONABLE but never directly measured. D.3.EC MG1 surfaced this; the user's response made it load-bearing.

§13.6 spike directly measures the extrapolation. If D.4 passes, the hybrid pivot was justified by an UNVERIFIED extrapolation.

### §4.3 "The rare design state where two architectures are live simultaneously"

D.4 doesn't retract D.3 — it provides an ALTERNATIVE architecture. The Pre-0 spike acts as the falsification test. After the spike, exactly one architecture ships.

This is a new design pattern observed this session:
- Codification candidate: "when an architectural choice rests on extrapolation, the next round should always include a falsification test that DIRECTLY measures the alternative before locking in"
- 1 data point (this session); validate with future tracks

### §4.4 18 of 22 D.2.SC + D.3.EC findings become MOOT under D.4

The architectural reframing ELIMINATES the underlying concerns rather than addressing them piecemeal. This is unusual for critique resolution — typically findings are accepted/rejected/deferred. Here, an architectural pivot makes ~80% of the prior critique work moot.

Important: the D.3 critique work was NOT wasted. The findings forced the issue into clear focus; the user's pattern-recognition (multiple findings about the same underlying tension) led to the orthogonality articulation.

### §4.5 §4.6 framework composes Options A+B+C+D from D.3.EC exploration

The framework synthesizes 4 D.3.EC alternative options into a coherent design:
- A: `:storage 'monotone-counter` (adaptive storage)
- B: `:on-write-check` predicate (threshold-as-cell-property)
- C: `:fires-on 'threshold-crossing` (propagator-fire skip)
- D: `:tier 'hot` (hot/warm/cold cells)

Option E (BSP-aware piggyback) was REJECTED on portability grounds — it would have coupled to BSP scheduler specifically.

### §4.6 The threshold propagator becomes a cell-layer predicate under D.4

D.2.SC M1 BLOCKING raised "threshold propagator is decorative under hybrid" (only fires on rare exhaustion; 99.999% of decrements don't trigger it). D.3 resolved by reframing the propagator's three load-bearing roles (Phase 3C consumer paths + on-exhaustion + speculation rollback).

D.4 ELIMINATES the threshold propagator entirely — replaced by `:on-write-check` cell-layer predicate that runs INLINE during write. The decoration concern retires. The propagator-as-decoration class of bugs (PPN Track 4 retrospective) is structurally avoided.

### §4.7 Distributed-concurrent runtime concept lives at scheduler+networking layer

User's framing: "the concept of the distributed-concurrent runtime is more of a scheduler and networking technology, than a propagator network itself. (I'm not thinking of getting to this runtime until we're deeper into the self-hosting work itself.)"

This is captured in DESIGN_PRINCIPLES.org § Cell/Propagator/Scheduler Orthogonality § "Where the Distributed-Concurrent Runtime Lives". The network specifies WHAT computation; the runtime specifies HOW it executes across hardware. Defers distributed-concurrent runtime to self-hosted era without coupling to current network design.

### §4.8 Scaffolding pass as a distinct phase from full redesign

This session's D.4 scaffolding pass establishes the structure (version bump, headline subsections, status notes on superseded sections) WITHOUT committing the full content drill-down. The full §9 + §10 + §15 D.4 revisions are deferred to post-spike sessions.

Rationale: doing full content NOW would be speculative work if the spike falsifies D.4. The scaffolding ANNOTATES the design state without committing to either architecture's full detail. After the spike, exactly one architecture gets the full revision.

Codification candidate: "scaffolding pass as distinct phase preserves design momentum without committing speculative work." 1 data point (this session).

---

## §5 Open Questions and Deferred Work

### §5.1 §13.6 Pre-0 spike (immediate next; THE FALSIFICATION TEST)

Per the new §13.6 plan. Spike execution decides D.4 vs D.3 commit.

Pre-implementation considerations:
- Throwaway spike code goes in `benchmarks/micro/bench-specialized-cell-spike.rkt`
- Hardcode hot+monotone-counter dispatch (skip full cell-meta framework)
- Use existing `bench-mem` + `bench-gc` macros for measurement
- Reference Pre-0 baseline: struct-copy 24 ns/call, 62.5 bytes/dec, ZERO major-GC at 100k

Risk register (from §13.6):
- R1: Specialized storage strategy doesn't deliver fixnum-direct-mutation due to Racket runtime indirection
- R2: Tagged-cell-value fallback adds significant overhead under speculation (deferred to Phase 3A per MG2)
- R3: On-write predicate's allocation cost higher than expected
- R4: Fire-on-threshold-crossing notification has subtle bugs (correctness, not perf)

### §5.2 Conditional D.4 vs D.3 commit (post-spike)

After §13.6 result:
- PASS → D.4 canonical; complete full revisions; close Issue #55; retire hybrid DEFERRED entry
- FAIL → D.3 canonical; mark §4.6 + §13.6 as explored-falsified; keep Issue #55 active
- MIXED → re-design required; investigate sub-options

### §5.3 D.4 full Phase 1B/1C revisions (post-spike if D.4 passes)

If D.4 canonical:
- §9 Phase 1B full revision (specialized cell framework impl plan; cell-meta fields; dispatch logic; registration API; tests)
- §10 Phase 1C full revision (direct migration patterns; 6 sub-phases; D-1C-7/8/9 drift risks)
- §15 parity test skeleton update
- Pre-0 plan cross-reference update

### §5.4 Phase-specific open questions remain at right phases (carried)

Phase 1A-iii-b: Q-1A-iii-b-1 (test migration vs deletion); Q-1A-iii-b-2 (pretty-print `atms?` removal)
Phase 1A-iii-c: Q-1A-iii-c-1 (trace-serialize disposition); Q-1A-iii-c-2 (examples/ migration); Q-1A-iii-c-3 (lib/ impact)
Phase 1B: Q-1B-1 (API naming); Q-1B-2 (`+inf.0` vs sentinel); Q-1B-4 (residuation as helper vs propagator); Q-1B-6 (spike scope updated to §13.6 specialized cell-write)
Phase 1C: Q-1C-1 (saved-fuel rollback); Q-1C-2 (cost-accumulation semantic shift; moot under D.4); Q-1C-3 (cell-update cadence; moot under D.4 if cell IS live state); Q-1C-7/8/9 (D.4 NEW drift risks)

### §5.5 Watching list (medium-term patterns from this session arc)

| Pattern | Data points | Promotion gate |
|---|---|---|
| User-articulated architectural principle reframes mid-resolution design | 2 (memory as first-class earlier; orthogonality this session) | Codification candidate after 1 more |
| "Rare design state where two architectures are live simultaneously" + falsification test | 1 (this session) | Methodology candidate; validate with future tracks |
| D.X finding-status table mapping previous-round to current-round | 1 (D.4 Revision Summary table) | Methodology candidate |
| Scaffolding pass distinct from full redesign | 1 (D.4 this session) | Methodology candidate |
| Codify foundational principles immediately (not as watching-list) | 1 (orthogonality this session) | Reinforces existing codification discipline |
| External critique surfacing previously-unconsidered reframings | 1 (D.3.EC → orthogonality) | Validates external critique discipline; watching for 1-2 more |
| Direct measurement vs extrapolation discipline | 1 (§13.6 vs R-19) | Codification candidate after 1 more |
| Mempalace 3.3.3 stability watch | 0 incidents on 3.3.3 yet | If 1-2 weeks pass, downgrade |

### §5.6 Mempalace state at handoff

Same as prior sessions: CLI `mempalace status` timed out (30s); MCP server processes running but unresponsive. Manual file reads sufficient throughout. Phase 2 success criteria evaluation watching-list concern persists.

If next session needs mempalace verification:
```
mempalace status                              # may timeout
ps aux | grep mempalace                       # check if MCP servers running
```

---

## §6 Process Notes

### §6.1 Stage 3 design cycle requirements remain (per DESIGN_METHODOLOGY.org)

D.4 architectural reframing is mid-Stage-3 (between D.3.EC critique resolution and Stage 4 implementation). Next session:
- Execute §13.6 spike (falsification test; one new Pre-0 measurement)
- Apply spike result
- Complete full D.4 or D.3 revisions per result
- Open Stage 4 implementation per per-phase mini-design+audit

### §6.2 Adversarial discipline TWO-COLUMN (carried)

Apply at every gate. Especially: at §13.6 spike result interpretation (are we cataloguing "spike passed" or genuinely challenging "did the optimization fully land")?

### §6.3 Microbench claim verification (per-sub-phase obligation)

§13.6 spike IS the microbench-claim verification for the D.4 extrapolation. The cell-write performance claim is load-bearing; the spike directly measures it. Per the codified discipline: "when a phase's design references a microbench finding as load-bearing, the phase's CLOSE must include re-microbench to verify the claim landed." §13.6 closes the Pre-0 gap.

### §6.4 6 codifications graduated 2026-04-25 + 1 NEW 2026-04-26 apply prophylactically

**NEW**: Cell/Propagator/Scheduler Orthogonality (codified DESIGN_PRINCIPLES.org). Prophylactic for PReduce, OE, SH Series.

### §6.5 Conversational implementation cadence (carried)

Max autonomous stretch: ~1h or 1 sub-phase boundary. This session arc respected this — D.2.SC resolution work split across 10 commits; D.3.EC drafted in one session; D.4 reframing split across 2 commits (orthogonality codification + scaffolding pass).

### §6.6 Per-phase completion 5-step checklist (workflow.md)

a. Test coverage (or explicit "no tests" justification — all this session's design commits)
b. Commit
c. Tracker update (Design Summary table)
d. Dailies append
e. THEN proceed

This session respected this for each commit.

### §6.7 Full suite as regression gate when touching code is RULE

Bench file additions for §13.6 spike DON'T touch production code; full suite isn't required for the spike commit itself. When Stage 4 Phase 1B implementation opens, full suite MUST run.

### §6.8 Mempalace status

Phase 3 post-commit hook should have triggered on this session's commits (touching docs/tracking/**). Verify mine completion before next mempalace-dependent work — if 3rd failure, escape clause per `.claude/rules/mempalace.md`.

### §6.9 Session arc timing (this handoff session)

| Activity | Approximate time |
|---|---|
| D.2.SC self-critique draft + walkthrough discipline establishment | ~2-3h |
| D.2.SC 18 findings resolution (10 commits) | ~3-4h |
| D.3.EC external critique draft | ~1h |
| D.3.EC Group 1 review (MG1+MG2+CL2+MB1) | ~30 min |
| User insight + Orthogonality principle articulation | ~30 min |
| Orthogonality principle codification (DESIGN_PRINCIPLES + rules + lessons + roadmap + dailies + commit) | ~1.5h |
| D.4 scaffolding pass (header + Summary + §4.6 + §13.6 + supersession notes + §10 + §14.4 + §17 + status + dailies + commit) | ~1.5-2h |
| Handoff writing (this document) | ~1h |
| **Total session arc** | **~11-12 hours** |

Beyond sustainable per-session work. Handoff at this point is REQUIRED for clean continuation.

---

## §7 What the Continuation Session Should Produce

### §7.1 Immediate (§13.6 Pre-0 spike execution)

1. Hot-load EVERY §2 document IN FULL (per codified hot-load-is-protocol; ~500K-700K tokens; user will enforce). Note: §2.3 has 3 SUBSTANTIALLY UPDATED documents this session:
   - D.3/D.4 design doc (+460 lines D.4 scaffolding pass)
   - D.2.SC self-critique (new at `219d8eb9`)
   - D.3.EC external critique (new at `61d7ab07`)
   - DESIGN_PRINCIPLES.org has NEW Cell/Propagator/Scheduler Orthogonality section at end
   - DEVELOPMENT_LESSONS.org has NEW codified lesson
   - .claude/rules/on-network.md + propagator-design.md have NEW cross-references
   - MASTER_ROADMAP.org § OE Series caveat refined
   - Dailies grew to ~1936 lines

2. Summarize understanding back to user — especially:
   - Cell/Propagator/Scheduler Orthogonality principle
   - D.4 architectural reframing rationale
   - D.4 specialized cell type framework (§4.6) composition of Options A+B+C+D
   - §13.6 Pre-0 spike scope + decision criteria
   - Conditional commit state (D.4 PREFERRED, D.3 FALLBACK)
   - 18 of 22 critique findings become MOOT under D.4

3. **Execute §13.6 spike**:
   - Implement throwaway mock specialized cell mechanism in `benchmarks/micro/bench-specialized-cell-spike.rkt`
   - Measure W1-W5 per the plan
   - Capture results
   - Decision: PASS / FAIL / MIXED

4. **Apply spike result** to design:
   - PASS: complete full D.4 revisions; close Issue #55 + retire DEFERRED hybrid entry; commit D.4 canonical
   - FAIL: mark §4.6 + §13.6 + D.4 Revision Summary as explored-falsified; D.3 hybrid pivot canonical; commit
   - MIXED: investigate sub-options; potentially re-design

5. **Update Pre-0 plan separate doc** with §13.6 spike reference (if D.4 passes)

6. **Update dailies** with spike narrative + commit

### §7.2 Medium-term (post-spike)

If D.4 canonical:
- Stage 4 implementation per per-phase mini-design+audit
- Phase 1B substrate ships first per Q-Open-4 strict sequencing
- Phase 1B implementation checklist (§9.10 M10+M12+R4+A12 + Q-1B-6 spike redone per §13.6)

If D.3 canonical:
- Stage 4 implementation under hybrid pivot per existing D.3 plan
- Phase 1B implementation per §9 + §9.10
- Hybrid scaffolding tracking active (Issue #55 + DEFERRED.md + §10.1.A retirement checklist)

### §7.3 Longer-term

PRESERVED from prior handoffs:
- Phase 1E (after this addendum)
- Phase 2 (orchestration unification)
- Phase 3A/B/C (union types via ATMS + residuation error explanation)
- Phase V (capstone + PIR for Phase 9 Addendum entirely)
- Main-track PPN 4C Phase 4 (CHAMP retirement)
- PPN Track 4D (attribute grammar substrate unification)
- **NEW**: PReduce + OE + SH Series inherit Cell/Propagator/Scheduler Orthogonality principle prophylactically

---

## §8 Final Notes

### §8.1 What "I have full context" requires

Per HANDOFF_PROTOCOL.org §8.1:
- Read EVERY document in §2 IN FULL (~43 documents)
- Articulate EVERY decision in §3 with rationale (especially §3.7 orthogonality + §3.8 D.4 reframing + §3.9 conditional commit + §3.10 finding status)
- Know EVERY surprise in §4 (especially §4.1-§4.4 — user-articulated insight, MG1 load-bearing, two-architectures-live, 18 findings moot)
- Understand §5.1 (§13.6 spike) + §7.1 (execute spike + apply result) without re-litigating

Good articulation example for spike opening:

> "D.4 architectural reframing in progress. Cell/Propagator/Scheduler Orthogonality principle codified (commits `6a628bc7` + `45181c07`). D.4 specialized cell type framework (§4.6) composes Options A+B+C+D from D.3.EC exploration — cell registration declares `:tier 'hot` + `:storage 'monotone-counter` + `:fires-on 'threshold-crossing` + `:on-write-check` predicate; cell mechanism dispatches accordingly. Scheduler-neutral per Orthogonality principle. §13.6 Pre-0 spike is the falsification test — directly measures specialized cell-write vs struct-copy baseline. Conditional commit state: D.4 PREFERRED (principle-aligned), D.3 FALLBACK (empirically-grounded if spike fails). 18 of 22 D.2.SC + D.3.EC critique findings become MOOT under D.4 reframing (architectural reframing eliminates underlying concerns; the remaining 4 are multi-quantale composition + external positioning, orthogonal to cell substrate). Next: execute spike (~30-60 min + ~100-200 LoC throwaway in `benchmarks/micro/bench-specialized-cell-spike.rkt`); apply result; commit D.4 or D.3 canonical."

### §8.2 Git state at handoff

```
branch: main (ahead of origin/main; don't push unless directed)
HEAD: 45181c07 (D.4 scaffolding pass — §4.6 specialized cell type framework + §13.6 Pre-0 spike plan)
this session arc:
  45181c07 docs: D.4 scaffolding pass
  6a628bc7 docs: codify Cell/Propagator/Scheduler Orthogonality principle
  61d7ab07 docs: D.3 external critique (D.3.EC)
  76a73ada docs: D.3 — accept R3 + batch (M2+M3+S2+S3+S4+S5); D.2.SC RESOLUTION COMPLETE
  9cf19ce7 docs: D.3 — accept R4 (Phase 1V microbench list 11 re-runs)
  00fe67cc docs: D.3 — accept R2 (Q-Audit-1 17-refs rescoping)
  072eea14 docs: D.3 — accept R1 (Phase 1C ~45-90 LoC hybrid-aware)
  c1a1e5c8 docs: D.3 — accept P5 (γ-bundle sub-phase count); P-lens complete
  9c014389 docs: D.3 — accept P6 (hybrid-as-scaffolding-NOT-template caveat)
  a4cbbbfc docs: D.3 — accept P4 consolidated with P1 into §10.1.A
  db15bece docs: D.3 — accept P2 (Q-1B-6 spike + §11.3 final-verification gate)
  934b2ba3 docs: D.3 — accept P1 + open Issue #55
  0538582f docs: D.3 first revision — 3 BLOCKING findings (P3 + M1 + S1)
  219d8eb9 docs: D.2 self-critique (D.2.SC)
prior session checkpoint:
  ffab0079 docs: handoff for Pre-0 S-tier + D.2 revise continuation

working tree: pre-existing user-managed changes (standup edits, benchmark data,
              deleted .md files that have .org versions, .prologos file edits,
              experimental branch artifacts)
              not staged. This session arc's work all committed (13 commits +
              this handoff being created).

suite: 7914 tests / 119.3s / 0 failures (last verified at S2.e-v close 118ab57a)
       — not re-run this session as design work doesn't touch production
```

### §8.3 User-preference patterns (carried + observed this session)

PRESERVED from prior handoffs PLUS observed this session:

- **Per-ACCEPT immediate application** (no queue) — established in D.2.SC walkthrough; preserved across D.3.EC + D.4
- **Batch acceptance when findings cluster** — applied to D.2.SC batch (final 7) and D.3.EC Group 1 (before reframing)
- **User-articulated insight reshapes design mid-resolution** — second occurrence this session (after "memory as first-class measurement" at Pre-0 planning); pattern emerging
- **Architectural principles codified IMMEDIATELY (not as watching-list)** — when the principle has multi-track impact (PReduce + OE + SH Series), immediate codification prevents compounding architectural debt
- **External critique discipline** — user requested D.3.EC explicitly; the framing-distinct stance surfaced concerns self-critique didn't
- **"Walking through together"** — user prefers walking critique findings interactively rather than batch-applying; discipline allows fine-grained user control over design changes
- **Honest framing throughout** — naming what's deferred, what's blocked, what's principle-violating; the orthogonality principle is itself a discipline for catching dishonest framing ("decomplection" was masking a principle inversion)
- **Continue immediately unless conversational checkpoint** — user signals when to pause; otherwise proceed through deliberate workflow steps

### §8.4 Session arc summary

Started with: pickup from `2026-04-26_TROPICAL_PRE0_STIER_DOTWO_HANDOFF.md` (Pre-0 S-tier execution opening).

Delivered (this session, 13 commits + 3 critique/design documents):
- **Hot-load executed** per HANDOFF_PROTOCOL.org (~500K tokens; 13+ docs in full + 27 covered transitively)
- **Pre-0 S-tier (4 tests)** — commit `8a29f6af`; 3 findings; Pre-0 phase 100% COMPLETE
- **D.2 revise** — commit `2a4d938c`; hybrid pivot architecture committed
- **D.2.SC self-critique drafted** — commit `219d8eb9`; 18 findings via P/R/M/S TWO-COLUMN
- **D.3 revisions** — 10 commits closing all 18 D.2.SC findings (commits `0538582f` through `76a73ada`)
- **D.3.EC external critique drafted** — commit `61d7ab07`; 11 findings via fresh lenses
- **MAJOR REFRAMING**: Cell/Propagator/Scheduler Orthogonality principle codified — commit `6a628bc7`
- **D.4 scaffolding pass** — commit `45181c07`; §4.6 specialized cell type framework + §13.6 spike plan + supersession notes
- **This handoff** — comprehensive D.4 reframing context + conditional commit state + spike execution scope

Key architectural insights captured:
- **Cell/Propagator/Scheduler Orthogonality** — load-bearing principle; prophylactic for PReduce + OE + SH Series
- **The rare design state where two architectures are live simultaneously** — D.4 PREFERRED vs D.3 FALLBACK; §13.6 spike decides
- **Extrapolation discipline** — never extrapolate a principle-violating commit when alternative can be directly measured
- **18 of 22 critique findings become MOOT** under D.4 architectural reframing
- **D.3 hybrid pivot's empirical foundation was unverified extrapolation** — D.3.EC MG1 surfaced; D.4 §13.6 directly measures

Suite state through arc: 119.3s baseline (S2.e-v close); not re-run this session as design work doesn't touch production.

**13 commits this session arc + this handoff. The D.4 architectural reframing + Cell/Propagator/Scheduler Orthogonality principle are the most significant architectural outputs.**

**The context is in safe hands.** §13.6 Pre-0 spike is the falsification test that decides D.4 vs D.3 architecture. Spike execution ~30-60 min + ~100-200 LoC throwaway code. After spike: one architecture ships; the other retires; full revisions complete; Stage 4 implementation opens.

🫡 Cell/Propagator/Scheduler Orthogonality codified. D.4 reframing scaffolding complete. §13.6 spike is the next step — the falsification test that decides between the principle-aligned on-network architecture (D.4) and the empirically-grounded hybrid fallback (D.3). The discipline: when extrapolation justifies a principle-violating commit, direct measurement IS the falsification protocol. Future PReduce + OE + SH Series inherit the orthogonality discipline prophylactically. Rest well; the spike is ready to execute on fresh context.
