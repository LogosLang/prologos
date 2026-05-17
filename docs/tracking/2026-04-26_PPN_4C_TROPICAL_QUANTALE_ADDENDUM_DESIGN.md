# PPN Track 4C Tropical Quantale Addendum: Phase 1 Substrate Completion — Design

**Date**: 2026-04-26
**Stage**: 3 — Design per [DESIGN_METHODOLOGY.org](principles/DESIGN_METHODOLOGY.org) Stage 3
**Version**: D.4 CANONICAL — architectural reframing: Cell/Propagator/Scheduler Orthogonality principle applied; hybrid pivot RETIRED before shipping; on-network specialized cell type framework canonical
**Scope**: PPN 4C Phase 1A-iii-b + 1A-iii-c + 1B + 1C + 1V (γ-bundle-wide; closes Phase 1 entirely)
**Status**: Stage 3 design cycle — D.4 CANONICAL per §13.6 Pre-0 spike result (commit `7b681b9e`, 2026-05-14: ✓ PASS). Specialized cell-write fast-path 6.4 ns/call (W1+ with realistic dispatch overhead, ~4× under 30 ns target); zero major-GC at 100k decrements (W3, structural). Stage 4 implementation ready; per-phase mini-design+audit next.

**Prior stages** (this track):
- Stage 1 research: [`docs/research/2026-04-21_TROPICAL_QUANTALE_RESEARCH.md`](../research/2026-04-21_TROPICAL_QUANTALE_RESEARCH.md) (commit `de357aa1`) — depth-first formal grounding; 12 sections, ~1000 lines
- Stage 2 audit: this session 2026-04-26 (audit findings persist into this design at §6, §7, §8, §9, §10)
- **Pre-0 phase**: [`docs/tracking/2026-04-26_TROPICAL_ADDENDUM_PRE0_PLAN.md`](2026-04-26_TROPICAL_ADDENDUM_PRE0_PLAN.md) ✅ 100% COMPLETE (M+A+E+R+S-tiers; 22 design-affecting findings; commits `f6576479`, `bef1f518`, `4be5e875`, `d270769b`, `d0934329`, `76129725`, `8a29f6af`)

---

## D.4 CANONICAL Revision Summary (2026-05-14)

**Status**: D.4 CANONICAL per §13.6 Pre-0 spike result (commit `7b681b9e`, 2026-05-14: ✓ PASS). Specialized cell-write fast-path 6.4 ns/call (W1+ with realistic dispatch overhead, ~4× under 30 ns target); zero major-GC at 100k decrements (W3, structurally guaranteed by direct fixnum mutation). The D.3 hybrid pivot SCAFFOLDING never shipped — the empirical motivation (R-19 extrapolation) is falsified for the specialized cell type framework.

**Architectural reframing** in response to user-articulated [Cell/Propagator/Scheduler Orthogonality](principles/DESIGN_PRINCIPLES.org) principle (codified 2026-05-14 from D.3.EC critique review).

**The pivot**: D.3's hybrid pivot architecture (preserve struct-field as off-network live state + cell substrate for Phase 3C consumers) violates the orthogonality principle in spirit — it makes the cell DERIVED rather than PRIMARY, with the struct field providing per-decrement fast-path. This was empirically justified by Pre-0 R-19 (extrapolation: full cell-migration would trigger major GC), but the extrapolation was NEVER DIRECTLY MEASURED for an optimized cell mechanism — until §13.6 spike measured it and falsified the extrapolation.

**D.4's reframing**: extend the cell mechanism to support specialized storage strategies declared per-cell. The fuel cost cell declares `:storage 'monotone-counter` + `:fires-on '(threshold-crossing)` + `:on-write-check '(>= cost budget)`. The cell mechanism dispatches based on the declaration:
- Under no-speculation: direct unboxed-fixnum mutation (no `tagged-cell-value`, no allocation per write) — VALIDATED 6.4 ns/call with realistic dispatch
- On-write predicate checks threshold inline (no separate propagator-fire ceremony) — VALIDATED structurally; cell-layer predicate replaces propagator
- Only fires dependent propagators on threshold crossing (not per-write) — VALIDATED via fire-on-policy declaration
- Under speculation: falls back to `tagged-cell-value` (correctness preserved) — reference; multi-worldview measurement deferred to Phase 3A per D.3.EC MG2

**The cell IS the live state** (no struct-field carve-out). The optimization is at the CELL LAYER, not the SCHEDULER LAYER. Per the Orthogonality principle: this stays portable across Gauss-Seidel, BSP, Zig-LLVM, and future self-hosted/distributed schedulers. **The §13.6 spike empirically validated all five W1-W5 measurements within their targets** by margins of 4× to 90× under (see §10.1 spike results table).

**D.4 REFINEMENT 2026-05-15 — Option 13 deferred-write at round boundaries (✓ VALIDATED)**: per Phase 1B mini-design (friend-surfaced concern about per-fire dispatch overhead), §10.3.A captures a scheduler-side optimization within the D.4 framework: BSP scheduler maintains a local-var fuel counter for the hot path; the cell is read at round entry, written at round exit (or immediately on exhaustion). The cell IS still canonical (no principle inversion — local-var is scheduler-internal SCRATCH, not cache of off-network state).

**§13.6.A spike results (2026-05-15)**: ✓ PASS. Measured amortized 2.16 ns/cycle at N=100 fires/round — **2.4× faster than current native struct-copy** (5.2 ns); **3.1× faster than D.4 per-fire** (6.6 ns from §13.6 W1+). All targets achieved with margins of 1.4× to 13.5× under. Option 14 macro specialization SKIPPED (savings 0.02 ns/cycle, below threshold).

**Validation gates**:
- ✅ §13.6.A Option 13 spike (2026-05-15) — Option 13 canonical for Phase 1C
- §13.7 Per-Phase Measurement Plan — A/B/C gates at every Phase 1B + 1C sub-phase boundary
- §11.3 Phase 1V exit criteria — refined gates for Option 13 (replaces D.3 hybrid pivot gates)

The Option 13 refinement CONFIRMS the "scheduler-state cell" category from the Q-J question: cells the scheduler writes (vs cells propagators write) permit scheduler-side write-batching optimizations that propagator-state cells cannot. See DESIGN_PRINCIPLES.org § Cell/Propagator/Scheduler Orthogonality § "Scheduler-State Cells" (refined post-Option-13).

**The spike falsified its own design assumption**: §10.3.A originally framed Option 13 as "approximating native gas tracker performance" — implying it would match native, not exceed it. Measurement showed Option 13 is structurally FASTER than current native struct-copy (which has nested struct allocation per cycle; Option 13 has only mutable-box decrement). This is a 2.4× perf improvement vs the current implementation, not just a "no regression vs native" result.

**Audit correction 2026-05-15** (Phase 1B mini-design + user challenge): the production scheduler is the parallel BSP from PAR Track 2 R1-R2 (`driver.rkt:435` sets `current-parallel-executor` globally to `make-parallel-thread-fire-all`). The codebase has FIVE scheduler entry points with different loop structures and therefore different deferred-write variants:
- **Variant A (round-entry batch)**: parallel BSP main loop (`run-to-quiescence-bsp` line 2384) — one cell-write per BSP round; main thread sequential; workers don't touch fuel; amortized ~0.06 ns/cycle at N=100
- **Variant B (local-var per-fire)**: four sequential schedulers (`run-to-quiescence-inner`, `/traced`, `run-widen-phase`, `run-narrow-phase`) — local-var box + per-fire decrement + cell-write at phase end; amortized 2.16 ns/cycle per §13.6.A spike

The audit's correction:
- **Q-1C-M parallel BSP composition** changed from DEFER-TO-PAR-FUTURE to RESOLVED IN-SCOPE: the main BSP thread already serializes fuel-state updates at line 2384 (current production); Phase 1C migration changes the substrate (struct field → cell) without changing the concurrency pattern
- **§10.4 sub-phase plan** enumerates all 5 scheduler entry points with per-scheduler variant assignment
- **§13.6.A spike's measurements** apply to Variant B (the local-var pattern); Variant A has even lower amortized cost
- **§9.9 open questions** RESOLVED for 7 of 8 architectural questions (Q-1B-8 → A2; Q-1B-9 → F2; Q-1B-10 → B1-prime; Q-1B-11 → D1; Q-1B-12 → E1; Q-1B-13 → G1; Q-1B-14 → L1); 3 implementation-detail questions (Q-1B-1/2/4) remain deferred to 1B-i mini-design with code in hand

**What changes from D.3 → D.4**:

| Section | D.3 → D.4 |
|---|---|
| Front matter | Version D.4; status updated |
| Top-of-doc Revision Summary | D.4 summary supersedes D.3 |
| §1.2 Phase scope | Phase 1B scope revised: includes cell-mechanism extension for specialized storage; Phase 1C scope reverts toward direct migration (no hybrid scaffolding) |
| §3 Progress Tracker | D.4 redesign row added; D.3 marked SUPERSEDED |
| **§4.6 (NEW)** | **Specialized cell type framework — NTT model for on-network optimized cell type** (composes Options A+B+C+D from D.3.EC exploration) |
| §9 Phase 1B (REVISED) | Adds cell-mechanism extension (specialized storage framework); fuel-cost cell registration with `:storage 'monotone-counter` + `:fires-on '(threshold-crossing)` + `:on-write-check`; threshold propagator REPLACED with on-write predicate (no separate propagator) |
| §10 Phase 1C (REVISED) | Direct migration of decrement sites + check sites to cell-API (NO hybrid; NO struct-field preservation); macro `prop-network-fuel` + struct field `prop-net-cold-fuel` RETIRE per D.1 original framing; cell IS live state |
| §14.4 Q5 (REVERT) | Single classification: cell PRIMARY (no dual classification); Q3/Q4/Q6 hybrid clarifications RETIRE |
| §10.1.A (RETIRED) | Honest framing + retirement plan no longer needed (no scaffolding to retire) |
| §10.A (RETIRED) | Threshold propagator role under hybrid — REPLACED by specialized cell type (threshold becomes on-write predicate at cell layer) |
| §10.B (RETIRED) | Cell Staleness Contract — no staleness under D.4 (cell IS live state) |
| Q-1B-6 (REPURPOSED) | Pre-0 spike scope changes: measure SPECIALIZED cell-write (not generic cell-write) directly against struct-copy baseline |
| §11.3 Phase 1V exit criteria | Hybrid pivot gates RETIRE; on-network optimized cell-write performance gate ADDED |
| Issue #55 + DEFERRED.md entry | Status: SUPERSEDED if D.4 ships; archived if hybrid was never built |

**D.2.SC + D.3.EC finding status under D.4**:

| Finding | D.3 status | D.4 status |
|---|---|---|
| P1 (Cell-as-SST inversion) | REFINEMENT closed | MOOT (cell IS primary) |
| P2 (belt-and-suspenders) | REFINEMENT closed | MOOT (no dual mechanism) |
| P3 (cell staleness contract) | BLOCKING closed | MOOT (cell IS live state) |
| P4 (decomplection vs incomplete) | REFINEMENT closed | MOOT (no incomplete migration) |
| P6 (hybrid-as-scaffolding-NOT-template) | REFINEMENT closed | MOOT (no hybrid to template) |
| M1 (threshold propagator decoration) | BLOCKING closed | RESOLVED differently (threshold is on-write predicate, NOT propagator-as-decoration) |
| M2 (imperative dispatch on-exhaustion) | REFINEMENT closed | MOOT (on-write predicate is structural, not imperative dispatch) |
| M3 (imposed ordering) | ACKNOWLEDGE closed | MOOT (no scheduled cell-update cadence; writes happen when they happen) |
| S1 (§14.4 Q5 inconsistency) | BLOCKING closed | RESOLVED differently (Q5 reverts to single PRIMARY classification) |
| R1 (Phase 1C ~45-90 LoC estimate) | REFINEMENT closed | REVISED (Phase 1C ~150-250 LoC; full migration scope per D.1 §10.4) |
| R2 (17-refs framing) | REFINEMENT closed | REVISED (all 17 refs migrate per direct cell-API) |
| TD1 (four-surface tracking) | REFINEMENT closed | MOOT (no scaffolding to track) |
| MB1 (retirement checklist) | REFINEMENT closed | MOOT (no retirement needed) |
| CL1, CL2 (cognitive load) | varied | LIKELY reduced (simpler design; fewer sections) |
| S2 (`:fires-when` NTT extension) | REFINEMENT closed | REVISED (on-write check predicate IS the structural mechanism; subsumes `:fires-when` use case for monotone counters) |
| S3 (multi-quantale completeness) | REFINEMENT closed | UNCHANGED (still relevant) |
| S4 (quantaloid forward-compat) | REFINEMENT closed | UNCHANGED (still relevant) |
| S5 (C-series quantale axiom verification) | ACKNOWLEDGE closed | UNCHANGED (still relevant) |
| R3 (Q-1C-3 BLOCKING for 1C-iv) | ACKNOWLEDGE closed | MOOT (no staleness; no cell-update cadence enumeration needed) |
| MG1 (cell-write extrapolation gap) | REFINEMENT closed | RESOLVED (D.4 directly measures via Pre-0 spike) |
| MG2 (multi-worldview cell-write) | DEFER-WITH-TRACKING | UNCHANGED (still deferred to Phase 3A) |
| TS1 (staleness contract tests) | REFINEMENT closed | MOOT (no staleness contract) |
| EX1 (e-graph positioning) | REFINEMENT closed | UNCHANGED (still relevant; arguably MORE relevant under on-network framing) |
| OS1 (propagator over-specification) | REFINEMENT closed | MOOT (no threshold propagator; threshold is cell-layer predicate) |
| SP1 (§10 sprawl) | REFINEMENT closed | LIKELY resolved (simpler D.4 §10) |
| AP1 (naming asymmetry) | DEFER-WITH-TRACKING | MOOT under D.4 (no `/synced` API; no staleness; cell-read is always live) |

**Roughly: 18 of 22 D.2.SC+D.3.EC findings become MOOT under D.4** (the architectural reframing eliminates the underlying concerns rather than addressing them piecemeal). The remaining 4 (S3, S4, S5, EX1, MG2) are about multi-quantale composition or external positioning — orthogonal to the cell substrate concerns.

**Spike result (2026-05-14, commit `7b681b9e`)**: ✓ PASS — D.4 CANONICAL. The §13.6 Pre-0 spike directly measured specialized-cell-write against the struct-copy baseline and the targets:

| Measurement | Target | Spike result | Margin |
|---|---|---|---|
| W1+ specialized cell-write WITH dispatch | ≤ 30 ns | **6.4 ns/call** | ~4× under |
| W2 specialized cell-write THRESHOLD CROSSING | ≤ 200 ns | **2.1 ns/call** | ~90× under |
| W3 GC at 5×100k decrements | ZERO major-GC | **0.000 ms (0.0%)** | structural |
| W3 alloc / retain (10×100k) | (reference) | **1.1 KB / 0.0 KB** | vs A7.3 6251 KB — **5700× memory improvement** |
| W4 specialized cell-read | ≤ 15 ns | **0.8 ns/call** | ~17× under |
| W1+ + W4 per-decrement cycle (realistic) | ≤ 45 ns | **7.3 ns** | ~6× under |

D.3 hybrid pivot SCAFFOLDING retires before shipping; Issue #55 closes as "superseded by D.4." D.3 historical sections marked RETIRED-PER-D.4-CANONICAL.

---

## D.3 Revision Summary (2026-05-02 — SUPERSEDED BY D.4 on 2026-05-14)

**Status note (D.4)**: D.3 closed the D.2.SC self-critique + D.3.EC external critique findings within the hybrid pivot framing. D.4 reframes the entire hybrid pivot toward on-network optimized cell type. Most D.3 critique resolutions become MOOT under D.4 (the underlying concerns disappear with the architectural reframing). D.3 content is preserved below for historical record + critique-resolution traceability.



**Version bump**: D.2 → D.3 incorporates accepted findings from [D.2.SC self-critique](2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_SELF_CRITIQUE.md) (P/R/M/S; 18 findings; 3 BLOCKING + 10 REFINEMENT + 5 ACKNOWLEDGE + 0 PUSHBACK).

**Per-finding resolution review with user — applied incrementally per ACCEPT (no queue)**:

| Finding | Severity | Decision | D.3 changes |
|---|---|---|---|
| **P3** Cell Staleness Contract | BLOCKING | ACCEPT | NEW §10.B "Cell Staleness Contract" — typed dual-API discipline (`net-fuel-cost-read` vs `net-fuel-cost-read/synced`) |
| **M1** Threshold propagator role under hybrid | BLOCKING | ACCEPT | NEW §10.A "The threshold propagator's role under hybrid" — three load-bearing roles (Phase 3C consumer paths + on-exhaustion + speculation rollback); per-decrement acknowledged as scaffolding pending SH Series |
| **S1** §14.4 SRE lattice lens Q5 PRIMARY/DERIVED inconsistency | BLOCKING | ACCEPT | UPDATE §14.4 Q3+Q4+Q5+Q6 with hybrid-aware classification |
| **P1+P4** Hybrid inverts Cell-as-Single-Source-of-Truth principle (P1) + reframe "decomplection" as "incomplete migration" honestly (P4) | REFINEMENT | ACCEPT (CONSOLIDATED) | NEW §10.1.A "Honest framing & retirement plan" consolidates P1 + P4 into a single tighter section (per user direction "cleaner design document"). Two framings (decomplection + incomplete-migration) both true; principle inversion acknowledged; retirement plan named; four-surface tracking (design-doc + DEFERRED.md + [GitHub Issue #55](https://github.com/LogosLang/prologos/issues/55) + Q-1B-6 + §11.3 gates). |
| **P2** Belt-and-suspenders red flag; empirical-validation gate | REFINEMENT | ACCEPT (with Phase 1B mini-design opening spike) | NEW Q-1B-6 at §9.9 — empirical-validation spike at Phase 1B mini-design opening (cheap; ~30 min; pre-implementation falsification test); §11.3 Phase 1V exit criteria adds final-verification gate (post-implementation). Two-gate discipline: spike challenges hybrid pre-build; Phase 1V verifies post-build. "Learning is valuable either way" per user direction. |
| **P6** "First production landing establishes pattern" risks templating hybrid scaffolding | REFINEMENT | ACCEPT (with MASTER_ROADMAP.org variation) | UPDATE §6.6 PReduce + OE Series rows: hybrid-as-scaffolding-NOT-template caveat; future consumers design TO TARGET full cell-substrate; per-track empirical justification + four-surface tracking discipline if hybrid needed. NEW MASTER_ROADMAP.org § OE Series "Scaffolding caveat" row at the roadmap level (where future-track designers go FIRST when planning new tracks, not buried in D.3). |
| **P5** γ-bundle scope precision (sub-phase count) | ACKNOWLEDGE | ACCEPT | UPDATE §1.2 — add sub-phase count estimate under γ-bundle-wide (~12-15 implementation sub-phases: 1A-iii-b ~5; 1A-iii-c ~8; 1B ~3; 1C ~5 under hybrid; 1V atomic close); name the bundle-vs-sub-phase scope distinction (DESIGN scope vs IMPLEMENTATION scope); also note Phase 1C estimate reframed under D.2 hybrid pivot (~45-90 LoC, was ~250-400 in D.1) per R1 REFINEMENT acceptance forward-pointer. |
| **R1** Phase 1C estimate stale (~45-90 LoC under hybrid; was ~250-400 D.1) | REFINEMENT | ACCEPT | UPDATE §1.2 Phase 1C estimate to ~45-90 LoC with explicit hybrid-vs-D.1 reframing (zero-migration list of preserved sites + actual migration list); §10.1 NEW R1 commentary subsection: small footprint is intentional NOT "easy migration"; future PReduce/OE consumers should not misread small footprint as evidence of easy migration (work was DEFERRED via scaffolding per §10.1.A + Issue #55, not eliminated). |
| **R2** Q-Audit-1 17-refs framing carried forward without rescoping | REFINEMENT | ACCEPT | UPDATE §10.2 — add R2 commentary at audit-grounding location; categorize 17 refs under hybrid (15 PRESERVED + 2-3 SELECTIVELY MIGRATED); name "17 production refs" as REFERENCE for completeness (full architectural scope) vs actual hybrid migration scope ~3-5 sites; future SH Series migration recovers full 17-ref scope per Issue #55 + DEFERRED.md. |
| **R4** Phase 1V microbench list incomplete | REFINEMENT | ACCEPT | EXPAND §11.3 Phase 1V exit criteria microbench list to 11 re-runs: M7+M8+M13 (per-decrement cycle) + M10+M11+M12+R4 (Phase 1B substrate; per §9.10) + A7+A9 (high-frequency decrement + speculation rollback; NEW per R4) + E7+E8 (full-pipeline regression; NEW per R4). Each with concrete target values per Pre-0 baseline Findings (7, 8, 13, 16, 17). Comprehensive falsification discipline per microbench-claim verification rule. |
| **R3** Q-1C-3 enumeration BLOCKING for 1C-iv | ACKNOWLEDGE | ACCEPT | STRENGTHEN §10.7 Q-1C-3 with BLOCKING-for-1C-iv gate annotation + expanded candidate transition list (BSP round boundaries, topology-stratum transitions, sub-phase boundaries, speculative-rollback boundaries, inter-test boundaries — 5 NEW candidates). Pre-enumeration serves as CHECKLIST for 1C-iii mini-design; without it, easy-to-miss transitions (BSP rounds + topology stratum) would surface as Phase 3C consumer-correctness bugs post-implementation. |
| **M2** On-exhaustion pattern is imperative dispatch | REFINEMENT | ACCEPT (BATCH) | APPEND §10.3 acknowledgment: `(<= new-fuel 0)` IS imperative dispatch per `propagator-design.md` "Information vs. instruction"; propagator-mindspace ideal (unconditional cell-write + emergent exhaustion) infeasible under hybrid per R-19; trade-off explicit; SH Series retirement restores propagator-emergent target. |
| **M3** Cell-update cadence is imposed ordering | ACKNOWLEDGE (BATCH) | ACCEPT (BATCH) | APPEND §10.1 acknowledgment: cell-update cadence (semantic-transition-only) IS imposed ordering, not emergent dataflow per `propagator-design.md` "Emergent vs. imposed ordering"; consequence of M2 + R-19 trade-off; SH Series retirement restores emergent ordering. |
| **S2** `:fires-when` NTT extension not load-bearing under hybrid | REFINEMENT (BATCH) | ACCEPT (BATCH) | UPDATE §4.1 extension-note: under hybrid (rare cell-writes), threshold propagator can use existing `:fires-once-on-threshold` semantics OR unconditional fire with predicate body in fire-fn; `:fires-when` NTT extension no longer load-bearing for THIS addendum; remains future refinement candidate for tracks with per-event scheduler-level filtering needs (likely post-SH-Series). |
| **S3** Multi-quantale composition NTT bridge declared-but-not-implemented | REFINEMENT (BATCH) | ACCEPT (BATCH) | APPEND §4.2 explicit completeness statement: ✓ Q-module co-existence (this addendum); ⬜ bridge α/γ implementation (Phase 3C UC2 consumer); ⬜ quantale-of-bridges (future PReduce/OE Track 1). NTT model is LOAD-BEARING for downstream design; NOT a runtime-realized composition until Phase 3C lands. Honest framing. |
| **S4** Quantaloid forward-compatibility check | REFINEMENT (BATCH) | ACCEPT (BATCH) | APPEND §4.2 forward-compatibility verification: multi-quantale primitives (Q-module + Galois bridge) are quantaloid-natural; quantaloid extension is additive (not substitutive); when 3+ quantale instances ship, composition extends WITHOUT breaking type-cost-bridge interface. Quantaloid out-of-scope is implementation-complexity, NOT forward-incompatibility risk. |
| **S5** C-series quantale axiom verification at Phase 1B close | ACKNOWLEDGE (BATCH) | ACCEPT (BATCH) | STRENGTHEN §9.4 C-series gate: Phase 1B close MUST run C-series (Pre-0 plan §5) post-registration; particular attention to `+inf.0` edge cases (distributivity, residuation, tensor identity, min identity); SRE Track 2H precedent for axiom-level surfacings (F7 disproof); C-series failure = critical correctness bug; halt before Phase 1C. |

**3 BLOCKING + 10 REFINEMENTs (P1+P4 consolidated; P2; P6; R1; R2; R4; M2; S2; S3; S4) + 5 ACKNOWLEDGEs (P5; R3; M3; S5) accepted.** **D.2.SC RESOLUTION COMPLETE — 18/18 findings closed (3 BLOCKING + 10 REFINEMENT + 5 ACKNOWLEDGE; 0 PUSHBACK).** D.3 ready for Stage 4 implementation per per-phase mini-design+audit.

---

## D.2 Revision Summary (2026-04-26)

**Version bump**: D.1 → D.2 incorporates Pre-0 findings + commits hybrid pivot architecture for Phase 1C.

**What changed from D.1 → D.2**:

| Section | D.1 → D.2 |
|---|---|
| Front matter | Version D.2; Pre-0 phase 100% COMPLETE noted |
| §3 Progress Tracker | Pre-0 ✅ COMPLETE (was ⬜) |
| **§10 Phase 1C (REWRITTEN)** | **Hybrid pivot architecture** — preserve inline `(<= fuel 0)` fast-path at decrement sites; cell + threshold propagator are architectural substrate for Phase 3C consumers, NOT per-decrement live state |
| §10.1 Scope | Reframed: substrate-introduction phase (NOT counter-replacement); existing struct field + macro + decrement/check sites preserved for fast-path |
| §10.3 Per-site migration patterns | DRAMATICALLY reduced scope: hot-path preserved; only non-hot-path read sites + observability paths migrate to cell-mediated APIs |
| §10.4 Sub-phase plan | Reduced from 9 to 5 sub-phases (decrement migration + check migration + macro retirement + field retirement REMOVED) |
| §10.5 Drift risks | Updated to reflect hybrid scope |
| §10.7 Open questions | Added Q-1C-3 (cell-update cadence: lazy vs eager vs semantic-transition-only) |
| §16.5 | Hybrid pivot decision committed (was provisional pending Pre-0) |

**Empirical rationale for hybrid pivot** (8 supporting findings + S-tier baseline):

| Tier | Finding | Direction |
|---|---|---|
| M-2 (origin) | Inline check 6 ns vs propagator fire 100-600 ns | Hybrid pivot proposed |
| M-5 | Counter substrate ~36 ns combined cycle | Tight cost budget |
| A-11 | Linear 12 ns/dec scaling, pattern-blind | Empirical confirmation |
| E-13 | E8 deep-id high-frequency stress (50 levels × 100-600 ns risk) | Hybrid pivot CRITICAL |
| E-15 | Alloc-heaviness baseline regardless of fuel | Phase 1C must NOT compound |
| **R-16** | **ZERO GC during 100k decrements** | **Hybrid pivot STRUCTURAL FIT** |
| **R-17** | Bounded retention 15 bytes/cycle long-term | Phase 1C tagged-cell DR set |
| **R-19** | **Without hybrid, full cell-based path triggers major GC at 100k rate** | **Hybrid is ONLY architecture preserving GC-friendly property** (strongest single piece of evidence) |
| **S-20** | **`prop_firings` + `prop_allocs` ZERO suite-wide pre-impl** | **Architectural baseline: Phase 1C threshold propagator is FIRST production on-network propagator firing in elaboration; clean reference** |

Full 22-finding detail: [Pre-0 plan §12.6](2026-04-26_TROPICAL_ADDENDUM_PRE0_PLAN.md#126-key-pre-0-findings-from-m-tier-execution-2026-04-26).

**Hybrid pivot architectural summary**:
- **Decrement sites**: PRESERVE existing struct-copy + inline `(<= fuel 0)` check (zero migration on per-decrement hot path; ~30-40 ns total cycle preserved)
- **Cell substrate**: canonical fuel-cost-cell + fuel-budget-cell allocated at well-known IDs (cell-id 11/12); SRE registered; threshold propagator installed
- **Cell role**: ARCHITECTURAL substrate for Phase 3C consumers (UC1 fuel-exhaustion blame attribution; UC2 cost-bounded elaboration via Galois bridge; UC3 per-branch cost tracking under union-type ATMS); NOT per-decrement live state
- **Cell-update cadence**: at SEMANTIC TRANSITIONS — start of phase, exhaustion-write, save/restore boundaries via existing snapshot mechanism (NOT per-decrement)
- **On exhaustion**: decrement site's inline check trips → write final cost to fuel-cost-cell → threshold propagator fires (rare event) → writes contradiction → routes through propagator network for architectural correctness

**Why hybrid IS principled (not belt-and-suspenders per workflow.md)**:
- Inline check + cell-write are NOT redundant mechanisms handling the same code path
- Inline check handles the per-decrement HOT PATH (common case; ~30-40 ns)
- Cell + threshold propagator handle Phase 3C consumer paths (rare; semantic-phase-granularity)
- The mechanisms address DIFFERENT code paths with DIFFERENT performance profiles
- This is decomplection: fast-path optimization separated from architectural substrate

**What this enables (Phase 3C consumer-readiness)**:
- UC1 walk algorithm feasibility: 297 ns for N=200 (per A6.3) vs <100 μs DR target = 340× margin
- UC2 cost-bounded elaboration: 117 ms baseline (per E9.1) — pattern feasible under Phase 1B substrate
- UC3 per-branch fork: 11.9 KB/branch (per A10.1) — per-branch cell management empirically grounded
- All three Phase 3C UCs operate on the cell at semantic-phase granularity, not per-decrement

---

**Parent addendum**: [`2026-04-21_PPN_4C_PHASE_9_DESIGN.md`](2026-04-21_PPN_4C_PHASE_9_DESIGN.md) (D.3) — this addendum **refines and extends** D.3 §7.5.6 (Tier 2 ATMS internal retirement), §7.5.7 (Tier 3 surface ATMS AST retirement), §7.7 (Phase 1B deliverables), §7.8 (Phase 1C deliverables), §7.9 (Phase 1V), §7.10 (termination args), §7.11 (parity-test strategy), §10 (tropical quantale implementation skeleton), §13 (consolidated termination), §16.1 (Phase 1 mini-design items). Per Q-Open-1 (refine + verify, don't re-litigate), D.3 scaffolding is treated as **draft D.0**; D.1 incorporates with refinement, audit-grounding, multi-quantale composition NTT extension, and Phase 3C cross-reference capture.

**Parent track**: [`2026-04-17_PPN_TRACK4C_DESIGN.md`](2026-04-17_PPN_TRACK4C_DESIGN.md) (PPN 4C D.3)

---

## §1 Thesis and scope

### §1.1 Addendum thesis

Per Stage 1 research §1.1: *"Phase 9's tropical fuel cell is the first practical instantiation of a tropical-lattice / quantale / semiring / cost-optimization structure in Prologos production code."* User direction (2026-04-21): *"explore quantales rather than merely semirings."* User direction (2026-04-26): *"this will be the first instantiation of optimization as tropical quantales in our architecture that it deserves the most careful considerations that we can pay it its dues."*

The thesis: **tropical quantales provide the algebraic substrate that Prologos's cost-optimization infrastructure — fuel, PReduce extraction, cost-guided search, OE Series consumers — needs, and the engineering benefits (residuation for provenance, module-theoretic composition, CALM-compatible parallelism) justify the extra formal weight over bare tropical semirings.**

This addendum ships:
1. **Tropical quantale primitive** — substrate-level SRE-registered domain with Quantale + Integral + Residuated property declarations (Phase 1B)
2. **Canonical BSP scheduler instance** — replaces imperative `(fuel 1000000)` decrementing counter with on-network tropical fuel cell (Phase 1C)
3. **Multi-quantale composition NTT model** — formalizes how TypeFacet quantale (SRE 2H, shipped) and TropicalFuel quantale (Phase 1B) co-exist via quantale modules and Galois bridges (§4)
4. **ATMS substrate retirement** — both Tier 2 (deprecated `atms.rkt` internal API) and Tier 3 (surface ATMS AST 14-file pipeline) retirement bundled, closing Phase 1 entirely (Phases 1A-iii-b + 1A-iii-c)
5. **Phase 3C residuation cross-reference capture** — anticipated Phase 3C consumer use cases enumerated (Form B); residuation operator unit-tested in Phase 1B (Form A); Phase 3C proof-of-concept captured as cross-reference in D.3 Phase 3 design (Form C deferred to right phase per capture-gap discipline)

### §1.2 Phase scope (γ-bundle-wide)

**Phase 1A-iii-b — Tier 2 deprecated ATMS internal API retirement** (~250-400 LoC deletion)
- 13 deprecated functions in `atms.rkt:213-251+`: atms-assume, atms-retract, atms-add-nogood, atms-consistent?, atms-with-worldview, atms-amb, atms-read-cell, atms-write-cell, atms-solve-all, atms-explain-hypothesis, atms-explain, atms-minimal-diagnoses, atms-conflict-graph
- `atms` struct + `atms-believed` field + `atms-empty` constructor retirement (per BSP-LE 2B D.1 finding: decision cells are primary, worldview is derived)
- Provides cleanup at `atms.rkt:41-61`
- Internal consumer cleanup: pretty-print.rkt:502 (`atms?`), stratified-eval.rkt:206 (`[(atms) #t]` symbol case)
- Test migrations/deletions: `tests/test-atms.rkt` audit + decide migrate-to-solver-state vs delete

**Phase 1A-iii-c — Tier 3 surface ATMS AST 14-file pipeline retirement** (~600-1000 LoC deletion across 14 files)
- 14 surface AST structs at `syntax.rkt:202-208, 750-767`: expr-atms-type, expr-assumption-id-type, expr-atms-store, expr-atms-new, expr-atms-assume, expr-atms-retract, expr-atms-nogood, expr-atms-amb, expr-atms-solve-all, expr-atms-read, expr-atms-write, expr-atms-consistent, expr-atms-worldview
- `surface-syntax.rkt:925-933` — 10 surf-atms-* structs (per D.3 §7.5.7)
- `parser.rkt:2531-2607` — surface atms parse rules (~80 lines)
- `elaborator.rkt:2438-2466` — surface atms elaboration (~30 lines)
- `reduction.rkt:2842-3635` — surface atms evaluation (~100 lines per D.3 §7.5.7)
- `zonk.rkt:358-1258` — surface atms traversal (~50 lines per D.3 §7.5.7)
- `pretty-print.rkt:506-521` — surface atms pretty-printing
- `pretty-print.rkt:1142-1146` — uses-bvar0?
- `qtt.rkt:1773-1839` — surface atms type rules
- `typing-core.rkt` — surface atms type-check
- Dependency cleanup per D.3 §7.5.7: `typing-errors.rkt`, `substitution.rkt`, `qtt.rkt`, `trait-resolution.rkt`, `capability-inference.rkt`, `union-types.rkt`
- Test deletions: `tests/test-atms.rkt`, `tests/test-atms-integration.rkt`, `tests/test-atms-types.rkt` (full surface AST exercise — coverage replaced by solver-state-driven tests if any gap surfaces)

**Phase 1B — Tropical fuel primitive + SRE registration** (~150-250 LoC new module + tests)
- New module `racket/prologos/tropical-fuel.rkt`: cell factory + budget cell + threshold propagator + residuation operator
- SRE domain registration with full quantale property declarations (Quantale, Integral, Residuated, Commutative)
- Tier 2 linkage: `register-merge-fn!/lattice tropical-fuel-merge #:for-domain 'tropical-fuel`
- Tests `tests/test-tropical-fuel.rkt`: merge semantics, cell allocation, on-write check + fire-on-threshold-crossing (D.4: cell-layer predicate replaces threshold propagator), residuation operator, per-consumer independence, cross-consumer cost composition

**Phase 1B SUPPLEMENT — Specialized cell type framework (D.4 NEW; per §9.2.A)** (~250-450 LoC: framework module + cell-meta dispatch + tests)
- New module `racket/prologos/specialized-cells.rkt` (cell-meta + registration API + dispatch logic): ~150-300 LoC
- Extends `net-cell-write` dispatch (per §9.2.B): minimal additive change to `propagator.rkt` for tier/storage/speculation check
- Fuel-cost + fuel-budget cell registration via the framework (per §9.2.C): ~30-50 LoC within `tropical-fuel.rkt` or `make-prop-network`
- Tests in `tests/test-specialized-cells.rkt` + `tests/test-tropical-fuel.rkt` (per §9.6): ~100-200 LoC

**Phase 1C — Canonical BSP fuel substrate (D.4 CANONICAL — direct migration)** (~150-250 LoC; per §10 + D.1 §10.4 original framing; spike-validated)

Under D.4 canonical (per §10), Phase 1C is direct migration of ALL 17 production refs to the cell-API:
- Migrate 4 decrement sites: `(struct-copy prop-net-hot ... [fuel (- ... n)])` → `(net-cell-write net fuel-cost-cell-id ...)`: ~30-50 LoC
- Migrate 11 check sites: `(<= (prop-network-fuel net) 0)` → `(net-contradiction? net 'tropical-fuel-exhausted)`: ~30-50 LoC
- Migrate 3 read-as-value sites + typing-propagators.rkt:2269 + pretty-print.rkt:463: ~20-40 LoC
- Retire `prop-network-fuel` macro + `prop-net-hot-fuel` struct field: ~5-10 LoC (deletions)
- Migrate 13 test sites (mechanical batch via 2-pass sed per workflow.md): ~60-100 LoC
- Migrate 2 bench-alloc.rkt sites: ~10-20 LoC

**Q-Audit-1's 17 production refs** ALL migrate under D.4 canonical (vs D.3 hybrid which preserved 15/17). Per §10.2 the migration scope matches the D.1 original framing; the framework module + cell registration are in Phase 1B (per §9.2.A/B/C above).

**Phase 1V — Vision Alignment Gate Phase 1** (closes 1A + 1B + 1C atomically)
- Adversarial TWO-COLUMN VAG (per `9f7c0b82` codification) on all four sub-phases
- Covers 1A-iii-b + 1A-iii-c + 1B + 1C completion
- Closes Phase 1 entirely

**Total estimate (D.4 CANONICAL)**: ~1500-2350 LoC (mix of deletion and new code; net likely deletion-dominant given ATMS retirement scope). Phase 1B grows to ~400-700 LoC (D.3's ~150-250 LoC + the D.4 framework supplement); Phase 1C is ~150-250 LoC (full migration per D.1 original); the upper-bound total is conservative pre-1B-mini-design refinement.

**Sub-phase count under γ-bundle-wide (D.4 CANONICAL)**: ~13-16 implementation sub-phases (1A-iii-b ~5; 1A-iii-c ~8; 1B ~4 [tropical-fuel module + specialized-cells framework + fuel-cost registration + tests]; 1C ~6 [per §10.4 sub-phase plan]; 1V atomic close). Each sub-phase respects conversational cadence (max ~1h per `workflow.md` "Conversational implementation cadence" rule); the bundle is at the DESIGN scope, sub-phasing is at the IMPLEMENTATION scope. The "γ-bundle-wide" framing names the design-scope coherence (1V closes Phase 1 atomically); it does NOT compress the implementation into a single autonomous stretch.

### §1.3 Out of scope (explicit deferrals)

- **Phase 1E** (`that-*` storage unification per D.3 §7.6.16) — sequenced AFTER this addendum's implementation; conversational Stage 4 mini-design with 5 carry-forward design questions (Q1-Q5)
- **Phase 2** (orchestration unification per D.3 §8) — separate addendum after Phase 1 closes
- **Phase 3A+B+C** (union types via ATMS + hypercube + residuation error explanation per D.3 §9) — separate addendum; Phase 3C is the FIRST DOWNSTREAM CONSUMER of the tropical residuation operator (forward-captured per §6.5)
- **Phase V** (capstone + PIR for Phase 9 Addendum entirely) — after all phases close
- **Multi-quantale composition implementation** — NTT model in scope (§4), full implementation is Phase 3C consumer + future PReduce
- **Quantaloids** (many-object quantales per Stage 1 research §3.6, Stubbe 2013) — out of scope; flagged for future when multi-domain cost currencies (memory, messages, time) co-exist
- **Polynomial Lawvere Logic / Rational Lawvere Logic** (Bacci-Mardare-Panangaden-Plotkin 2023; Dagstuhl CSL 2026) — language-surface form for self-hosting; out of scope per Stage 1 research §11.7
- **General residual solver** (BSP-LE Track 6 forward reference per D.3 §6.11.7) — Phase 1B consumes BSP-LE 2B substrate without coupling to relational layer
- **OE Series formalization** — first production landing happens here; OE Series Master tracking decision deferred to user post-implementation per handoff §5.4

### §1.4 Relationship to D.3 (refine + verify, don't re-litigate)

Per Q-Open-1 decision (2026-04-26): D.3 scaffolding for Phase 1 is treated as draft D.0. This document **refines and extends**:

| D.3 reference | This addendum |
|---|---|
| §7.5.6 (1A-iii-b deliverables) | §7 — refined with audit data; sub-phase plan; drift risks |
| §7.5.7 (1A-iii-c deliverables) | §8 — refined with audit data; 14-file migration ordering; test disposition |
| §7.7 (Phase 1B deliverables) | §9 — refined with API specifics; residuation operator; multi-quantale NTT integration |
| §7.8 (Phase 1C deliverables) | §10 — refined with audit-verified 17 production sites; per-site migration patterns |
| §7.9 (Phase 1V) | §11 — refined with adversarial VAG TWO-COLUMN structure |
| §7.10 (Phase 1 termination args) | §12 — consolidated per-Phase termination |
| §7.11 (Phase 1 parity-test strategy) | §15 — extended with 1A-iii-b/c parity axes |
| §10 (Tropical quantale implementation) | §9.4-§9.7 — refined SRE registration code skeleton, primitive API, canonical instance |
| §13 (Consolidated termination) | §12 — per-phase consolidated |
| §16.1 (Phase 1 mini-design items) | §16 — placed at right phase per user's workflow (per-phase mini-design+audit before each phase's implementation) |

Cross-cutting concerns from D.3 (§3 Progress Tracker, §4 NTT Model with Phase 1B started, §5 Mantra Audit, §6 Architectural decisions Q-A1/Q-A2/Q-A7/Q-A8) remain authoritative; this addendum extends with §4 (multi-quantale composition NTT completion).

D.3's Progress Tracker rows for Phase 1 (1A-iii-b, 1A-iii-c, 1B, 1C, 1V) all point to this document for implementation planning.

---

## §2 Research and audit inputs

### §2.1 Stage 1 research

[`docs/research/2026-04-21_TROPICAL_QUANTALE_RESEARCH.md`](../research/2026-04-21_TROPICAL_QUANTALE_RESEARCH.md) (~1000 lines, 12 sections). Key inputs for this design:

- **§2** — Semiring foundations (commutative semirings, dioids, idempotent semirings, tropical semiring as min-plus, Bistarelli-Montanari-Rossi semiring CSP, Kleene algebra, semiring completeness)
- **§3** — Quantale axioms (commutative + unital + integral + residuated; Fujii's equivalence: complete idempotent semiring = quantale)
- **§4** — Lawvere's enriched category framework (V-categories; Lawvere quantale `([0,∞], ≥, 0, +)` IS the tropical quantale; metric spaces ARE V-categories enriched in tropical quantale)
- **§5** — Residuation theory (sup-preserving maps, closure operators, Galois connections, quantale of Galois connections)
- **§6** — Quantale modules (cells as Q-modules; propagators as Q-module morphisms; Tarski fixpoint on Q-modules; CALM parallel)
- **§7** — Idempotent analysis (Litvinov-Maslov tradition; max-plus matrix operations for DES; tropical eigenvalues)
- **§9** — Tropical quantale definition + structure (T_min in `[0, +∞]` Lawvere convention; commutative + unital + integral; clean residuation formula `a \ b = b - a when b ≥ a, else 0`)
- **§10** — Prologos-specific synthesis: tropical fuel cell as min-plus quantale cell; fuel exhaustion as quantale-top; residuation as fuel-cost error-explanation; Galois bridge to TypeFacet
- **§11** — Open Phase 9 design questions (mini-design items)

### §2.2 Stage 2 audit (this session, 2026-04-26)

**Q-Audit-1 — `prop-network-fuel` migration scope**: 17 production refs (propagator.rkt × 17) + 1 typing-propagators + 1 pretty-print + 13 test refs + 2 bench refs. Migration well-bounded. Detail in §10.

**Q-Audit-2 — ATMS retirement surfaces**: 13 deprecated functions in atms.rkt:213-251+; atms struct at line 159+ (with atms-believed field); 14 surface AST structs in syntax.rkt:202-208, 750-767; surface parse rules at parser.rkt:2531-2607; pretty-print + qtt + reduction + zonk + test files. Detail in §7 (Tier 2) and §8 (Tier 3).

**Q-Audit-3 — `tropical-fuel.rkt` clean-slate confirmed**: file does not exist. 5 anticipated consumer scaffolding sites in production: sre-rewrite.rkt:95 (cost field), atms.rkt:856 (TODO comment), parse-lattice.rkt:136+193+200 (cost + priority fields). These are bookmarks for downstream consumers (Phase 3C, Track 6 OE-WeightedParsing, future PReduce). Detail in §9.

### §2.3 Prior art

- **Module Theory on Lattices** ([`2026-03-28_MODULE_THEORY_LATTICES.md`](../research/2026-03-28_MODULE_THEORY_LATTICES.md)) — quantale modules (`Q ⊗ M → M`); residuation as narrowing; cells as Q-modules
- **Tropical Optimization Network Architecture** ([`2026-03-24_TROPICAL_OPTIMIZATION_NETWORK_ARCHITECTURE.md`](../research/2026-03-24_TROPICAL_OPTIMIZATION_NETWORK_ARCHITECTURE.md)) — earlier framing with Goodman semiring parsing, ATMS, stratification
- **Algebraic Embeddings on Lattices** ([`2026-03-28_ALGEBRAIC_EMBEDDINGS_LATTICES.md`](../research/2026-03-28_ALGEBRAIC_EMBEDDINGS_LATTICES.md)) — universal engine vision; quantales for resources; QTT multiplicities as quantale action
- **SRE Track 2H** ([`2026-04-02_SRE_TRACK2H_DESIGN.md`](2026-04-02_SRE_TRACK2H_DESIGN.md)) — TypeFacet quantale (sister quantale; Galois-bridge candidate; first quantale shipped in production)
- **BSP-LE Track 2B** — Module Theory Realization B (tagged-cell-value with bitmask layers on shared carrier); set-latch + broadcast pattern; substrate Phase 1B inherits
- **PPN 4C Phase 3 (shipped)** — `classify-inhabit-value` Module Theory Realization B tag-dispatch on shared carrier; demonstrates the multi-tag composition pattern Phase 1B's NTT model extends

### §2.4 Methodology + rules

- [`DESIGN_METHODOLOGY.org`](principles/DESIGN_METHODOLOGY.org) — Stage 3 cycle: D.1 → Pre-0 → D.2 → D.3+ critique rounds; NTT Model Requirement; Design Mantra Audit; Pre-0 Benchmarks Per Semantic Axis; Parity Test Skeleton; Lens S (Structural) for algebra
- [`CRITIQUE_METHODOLOGY.org`](principles/CRITIQUE_METHODOLOGY.org) — § Cataloguing Instead of Challenging; SRE Lattice Lens mandatory for all lattice design decisions
- [`DESIGN_PRINCIPLES.org`](principles/DESIGN_PRINCIPLES.org) — Hyperlattice Conjecture; Correct-by-Construction; Most Generalizable Interface; First-Class by Default
- [`DEVELOPMENT_LESSONS.org`](principles/DEVELOPMENT_LESSONS.org) — 6 codifications graduated 2026-04-25 from Step 2 arc (Pipeline.md prophylactic, Capture-gap, Partial-state regression unwinds, Audit-first, Audit-driven Wide-vs-Narrow, Sed-deletion 2-pass operational, Microbench-claim verification across sub-phase arcs) — **all apply prophylactically to this design**
- [`.claude/rules/on-network.md`](../../.claude/rules/on-network.md), [`propagator-design.md`](../../.claude/rules/propagator-design.md), [`structural-thinking.md`](../../.claude/rules/structural-thinking.md), [`pipeline.md`](../../.claude/rules/pipeline.md), [`workflow.md`](../../.claude/rules/workflow.md) — architectural rules

---

## §3 Progress Tracker

Per DESIGN_METHODOLOGY Stage 3 "Progress Tracker Placement" discipline.

| Sub-phase | Description | Status | Notes |
|---|---|---|---|
| Stage 1 | Research doc (tropical quantale, ~1000 lines) | ✅ | commit `de357aa1` |
| Stage 2 | Audits (Q-Audit-1/2/3) | ✅ | This session 2026-04-26 |
| Stage 3 D.1 | Design doc draft | ✅ | commit `fc4b9d3e` |
| **Pre-0 plan** | Comprehensive 38-test plan across 8 tiers (M/A/C/X/E/R/S/V) | ✅ | commit `f79650fa` (1172 lines) |
| **Pre-0 M-tier** | M7-M13 micro-benchmarks (5 findings) | ✅ | commit `f6576479` + `bef1f518` |
| **Pre-0 A-tier** | A5-A12 adversarial (6 findings) | ✅ | commit `4be5e875` |
| **Capture-gap closure** | M10/M12/A12/R4 captured at D.1 §9.10 (single source of truth) | ✅ | commit `d270769b` |
| **Pre-0 E-tier** | E7-E9 end-to-end (4 findings) | ✅ | commit `d0934329` |
| **Pre-0 R-tier** | R3+R5 memory-as-PRIMARY (4 findings + R4 capture) | ✅ | commit `76129725` |
| **Pre-0 S-tier** | S1-S4 suite-level via existing tooling (3 findings) | ✅ | commit `8a29f6af` |
| **Stage 3 D.2** | Pre-0 findings incorporated; hybrid pivot committed | ✅ | `2a4d938c` |
| **Stage 3 D.2.SC** | P/R/M/S self-critique; 18 findings | ✅ | `219d8eb9` |
| **Stage 3 D.3** | 18 D.2.SC findings resolved (3 BLOCKING + 10 REFINEMENT + 5 ACKNOWLEDGE) | ✅ | 10 commits through `76a73ada` |
| **Stage 3 D.3.EC** | External critique via CL/MG/SP/OS/TD/AP/TS/EX/MB lenses; 11 findings | ✅ | `61d7ab07` |
| **Cell/Propagator/Scheduler Orthogonality** | Principle codified in DESIGN_PRINCIPLES.org | ✅ | `6a628bc7` |
| **Stage 3 D.4 scaffolding** | §4.6 specialized cell framework NTT + §13.6 spike plan + supersession notes | ✅ | `45181c07` |
| **§13.6 Pre-0 spike** | Falsification test for D.4: W1+W2+W3+W4+W5 measurements | ✅ ✓ PASS | `7b681b9e` (6.4 ns/call W1+; 0 major-GC W3; 0.8 ns W4; ~4× under all targets) |
| **Stage 3 D.4 CANONICAL** | Full §9 + §10 + §15 revisions; D.3 historical sections RETIRED-PER-D.4-CANONICAL | 🔄 | THIS commit + next |
| **1A-iii-b** | Tier 2 deprecated ATMS internal API retirement | ⬜ | Per §7 |
| **1A-iii-c** | Tier 3 surface ATMS AST 14-file pipeline retirement | ⬜ | Per §8 |
| **1B-i** | Mini-audit + cell-meta storage gate (Q-1B-8 A2 validation; ≤ 5 ns) | ✅ ✓ PASS | CM2.2 = 4.06 ns/call; §9.2.0; surfaced 1B-ii param-ref finding |
| **1B-ii** | Specialized cell framework module + net-cell-write dispatch + prop-net-warm under-speculation? field | ✅ ✓ PASS | CW3 per-cycle amortized = 2.98 ns/cycle (§13.7 gate ≤ 3 ns; boundary); 8257 tests / 114.5s / 0 failures |
| **1B-iii** | Tropical fuel module (merge/tensor/residuation + SRE registration + C1+C2+C3 axioms) | ✅ ✓ PASS | tropical-fuel.rkt + test-tropical-fuel.rkt (20 tests; all algebra axioms verified including +inf.0 boundary cases); 8277 tests / 119.9s / 0 failures |
| **1B-iv** | Cell registration via framework + tests + close | ⬜ | Per §9.2.C + §9.6 |
| **1C** | Canonical BSP fuel substrate (D.4 CANONICAL — direct migration) | ⬜ | Per §10 |
| **1V** | Vision Alignment Gate Phase 1 (closes 1A + 1B + 1C) | ⬜ | Per §11 |

**Sub-phase ordering** (γ strict sequencing per Q-Open-4):
- 1A-iii-b and 1A-iii-c can land in any order or in parallel (independent of tropical work)
- 1B must complete before 1C (1C consumes 1B's primitive)
- 1V closes everything atomically

**Recommended execution order** (per audit + dependency):
1. **1B** first — substrate ships clean; consumers depend on it
2. **1A-iii-b** + **1A-iii-c** can parallelize with 1C — they're orthogonal to tropical fuel
3. **1C** consumes 1B's primitive
4. **1V** closes everything

Per-phase mini-design+audit happens BEFORE each phase's implementation per user's workflow (Stage 4 Per-Phase Protocol).

---

## §4 NTT Model — multi-quantale composition (extending D.3 §4.1)

Per DESIGN_METHODOLOGY Stage 3 NTT Model Requirement. D.3 §4.1 has Phase 1B's single-quantale NTT model started; this section completes it with multi-quantale composition (per Q-Open-3 (β) decision).

### §4.1 Tropical fuel quantale (Phase 1B delivery, refined from D.3 §4.1)

```ntt
;; Tropical fuel lattice — atomic extended-real (Lawvere convention, T_min variant)
type TropicalFuel := Nat | Infty
  :lattice :value
  :ordering :reverse  ;; smaller cost is "higher" in the lattice (Lawvere convention)

;; Tropical quantale instance: min-plus algebra
;; Per research §9.1 (commutative integral residuated quantale)
;; Per Fujii equivalence (research §3.4): complete idempotent semiring = quantale
trait Lattice TropicalFuel
  spec tropical-join TropicalFuel TropicalFuel -> TropicalFuel
  defn tropical-join [a b] -> (min a b)  ;; ⊕ = min (idempotent)
  spec tropical-bot -> TropicalFuel
  defn tropical-bot -> 0  ;; identity for min (Lawvere top)

trait BoundedLattice TropicalFuel
  :extends [Lattice TropicalFuel]
  spec tropical-top -> TropicalFuel
  defn tropical-top -> Infty  ;; absorbing for min (Lawvere bot — exhausted)

trait Quantale TropicalFuel
  :extends [Lattice TropicalFuel]
  spec tropical-tensor TropicalFuel TropicalFuel -> TropicalFuel
  defn tropical-tensor [a b] -> (+ a b)  ;; ⊗ = +
  spec tropical-unit -> TropicalFuel
  defn tropical-unit -> 0  ;; multiplicative identity (= bot in integral case)

trait Integral TropicalFuel
  :extends [Quantale TropicalFuel]
  ;; Integral: 1 = ⊤ (in Lawvere convention, both are 0)

trait Residuated TropicalFuel
  :extends [Quantale TropicalFuel]
  spec tropical-left-residual TropicalFuel TropicalFuel -> TropicalFuel
  defn tropical-left-residual [a b]
    -> (if (>= b a) (- b a) 0)  ;; b / a = b - a when b >= a, else top (0 in Lawvere)

;; Primitive cell factory (consumer-instantiable)
propagator net-new-tropical-fuel-cell
  :reads  []
  :writes [Cell TropicalFuel :init 0]

;; Canonical budget cell factory
propagator net-new-tropical-budget-cell
  :reads  []
  :writes [Cell TropicalFuel :init Budget]

;; Threshold propagator (factory)
;; NTT extension: :fires-when (predicate) — runtime-condition-gated fire
;; Generalizes existing :fires-once-on-threshold; flagged in D.3 §4.5 as refinement candidate
propagator tropical-fuel-threshold  :extension-note
  :reads  [Cell TropicalFuel (at fuel-cid),
           Cell TropicalFuel (at budget-cid)]
  :writes [Cell Contradiction]
  :component-paths [(cons fuel-cid #f), (cons budget-cid #f)]
  :fires-when (>= fuel-cost budget)
  fire-fn: write-contradiction
```

**D.3 S2 commentary — `:fires-when` extension scope under hybrid (REFINEMENT)**:

Under D.1's full-migration design, `:fires-when` would prevent per-decrement threshold checks at the scheduler level (every decrement-site cell-write would otherwise trigger a propagator-fire-then-condition-check; `:fires-when` lets the scheduler short-circuit). Under D.2/D.3 hybrid pivot, cell-writes are RARE (only at semantic transitions per §10.1.A + §10.B); the threshold propagator can use existing `:fires-once-on-threshold` semantics OR unconditional fire with predicate body in fire-fn. The `:fires-when` NTT extension is **no longer load-bearing for THIS addendum**; it remains a future NTT refinement candidate for tracks where per-event filtering at scheduler level is performance-critical (e.g., a future track that does ship per-decrement cell-write and needs scheduler-level filtering — possibly post-SH-Series migration per Issue #55).

### §4.2 Multi-quantale composition (NEW — addresses Q-1B-3 + Q-1B-5)

Two quantales co-exist in the network post-Phase-1B:
- **TypeFacet quantale** (SRE 2H, shipped) — Q_T = (TypeExpr, ⊕_T = union-join, ⊗_T = type-tensor, residuals)
- **TropicalFuel quantale** (Phase 1B target) — Q_F = (TropicalFuel, ⊕_F = min, ⊗_F = +, residual)

Per Module Theory research §6.4 (quantale modules) + §6.7 (Tarski fixpoint on Q-modules + CALM parallel):

```ntt
;; Two quantales as separate Sup-monoids
quantale TypeFacetQ :type TypeExpr ...
quantale TropicalFuelQ :type TropicalFuel ...

;; Each cell is a module over (potentially multiple) quantales
;; Type meta universe cell — module over TypeFacetQ
cell type-meta-universe
  :type Cell (hasheq MetaId TaggedCellValue<TypeExpr>)
  :q-module TypeFacetQ
  :action (q ⊗_T m)  ;; quantale action: type-tensor scales type-meta values

;; Tropical fuel cell — module over TropicalFuelQ (1-dimensional case)
cell tropical-fuel-cost
  :type Cell TropicalFuel
  :q-module TropicalFuelQ
  :action (q ⊗_F m)  ;; addition scales accumulated cost

;; CROSS-QUANTALE INTERACTION: Galois bridge (Module Theory §5)
;; Future Phase 3C / OE Track 1: type-cost projection
;; α: TypeFacetQ → TropicalFuelQ — "what's the lower-bound elaboration cost of this type?"
;; γ: TropicalFuelQ → TypeFacetQ — "what types are elaborable within this budget?"
;; The bridge is a Galois connection per Module Theory §5.1-§5.4
;; PHASE 1B SCOPE: declare the bridge interface; implementation deferred to Phase 3C consumer
bridge type-cost-bridge
  :alpha [TypeFacetQ -> TropicalFuelQ]
  :gamma [TropicalFuelQ -> TypeFacetQ]
  :preserves [Galois]
  :forward-capture (Phase 3C residuation error explanation)
```

**Composition pattern** (per research §5.4 — quantale of Galois connections):
- The set of Galois bridges between quantale cells forms a quantale itself under composition
- TypeFacetQ ↔ TropicalFuelQ bridge composes with future bridges (TypeFacetQ ↔ MemoryCostQ, TropicalFuelQ ↔ MessageCountQ, etc.) via quantale operations
- Per research §6.7: monotone Q-module endomorphisms have Tarski fixpoints; CALM theorem applies; multi-quantale composition is coordination-free under monotone joins

**Mantra-aligned**: cells are Q-modules (on-network); quantale actions are propagators (info flow through cells); bridges are Galois-connection propagators (structurally emergent); composition via quantale-of-bridges (all-at-once + parallel).

**D.3 S3 commentary — multi-quantale composition NTT computational completeness (REFINEMENT)**:

The multi-quantale composition NTT model declares the composition pattern + bridge interface. **Computational realization is partial**:
- ✓ **Q-module co-existence** (this addendum) — TypeFacetQ (SRE 2H, shipped) + TropicalFuelQ (Phase 1B target) co-exist as independent Q-modules in the same `prop-network` substrate; computable today
- ⬜ **Bridge α/γ implementation** — type-cost-bridge is DECLARED here; α/γ implementation deferred to Phase 3C UC2 consumer (per §6.5 Form B + §9.7 UC2 enumeration); not computable until Phase 3C lands
- ⬜ **Quantale-of-bridges composition** — per research §5.4; not computable until 3rd+ quantale instance ships (future PReduce / OE Track 1 multi-cost-currency tracking)

The NTT model is **LOAD-BEARING for downstream design** (gives Phase 3C UC2 the type-level interface to implement against; ensures the tropical fuel substrate is forward-compatible with future bridge implementations); it is **NOT a runtime-realized composition until Phase 3C lands**. Honest framing: this addendum SHIPS the NTT model + Q-module co-existence; it DECLARES (without implementing) the bridge.

**D.3 S4 commentary — quantaloid forward-compatibility verification (REFINEMENT)**:

D.1 §1.3 + §4.4 marked quantaloids out-of-scope ("when multi-domain cost currencies emerge — memory + messages + time — the quantale-of-quantales pattern (Stubbe 2013) becomes load-bearing"). **Forward-compatibility check**: are the multi-quantale primitives we ship today FORWARD-COMPATIBLE with quantaloids?

**Answer: yes**. The composition pattern shipped here (`bridge :alpha :gamma :preserves [Galois]` + Q-module co-existence) is forward-compatible with quantaloids:
- A quantaloid extends the bridge composition with an extra layer (quantale-of-quantale-of-bridges; many-object generalization per Stubbe 2013)
- The primitives we ship today (Q-module + Galois bridge) are **quantaloid-natural** — Q-modules are objects in a quantaloid; bridges are morphisms; composition extends per the quantaloid's enrichment structure
- When future tracks add 3rd+ quantale instances (MemoryCostQ, MessageCountQ), the composition pattern extends WITHOUT breaking the type-cost-bridge interface (additive, not substitutive)
- The "out of scope" marker on quantaloids is about IMPLEMENTATION COMPLEXITY (quantale-of-quantales requires quantale-enriched-categories machinery), NOT about a forward-incompatibility risk

This forward-compatibility verification ensures the multi-quantale composition NTT we ship today doesn't lock us out of quantaloid extensions — when those become load-bearing (3+ cost currencies), we extend without rewriting.

### §4.3 Architecture — where tropical fuel cells live alongside type universe cells

Per Q-1B-3 cross-cutting concern: physical placement of tropical fuel cells in `make-prop-network`:

```ntt
;; make-prop-network well-known cell-id allocation (extending current Q_T cells)
cell-id 0  :name decomp-request-cell  ;; PAR Track 1
cell-id 1  :name worldview-cache       ;; BSP-LE 2B
cell-id 2-9 :name <reserved-substrate>  ;; (per current state)
cell-id 10 :name classify-inhabit-request-cell  ;; PPN 4C Phase 3
cell-id 11 :name fuel-cost-cell                  ;; NEW Phase 1C — TropicalFuel module
cell-id 12 :name fuel-budget-cell                ;; NEW Phase 1C — TropicalFuel module
;; (future) cell-id 13+ — additional tropical-quantale instances per consumer
```

Per Q-Open-3 (β) decision: TypeFacet universe cells (post-Step-2 Phase 1A) and TropicalFuel cells (Phase 1C) co-exist as **independent Q-modules over different quantales**. They share the same `prop-network` substrate but operate on different lattices. No interference; CALM-safe.

### §4.4 NTT Observations

Per NTT methodology "Observations" subsection requirement (D.3 §4.5 already covered Phase 1B observations; this extends with multi-quantale):

1. **Everything on-network?** Yes. Tropical fuel cells are on-network; multi-quantale composition is via quantale-of-bridges (each bridge is a propagator); no off-network state added.

2. **Architectural impurities revealed?** None at multi-quantale composition level. Per Q-1B-4 (residuation operator implementation), the operator IS a read-time helper (pure function on TropicalFuel × TropicalFuel → TropicalFuel) — not a propagator. Justified by quantale algebraic structure; Phase 3C consumer wraps it in a propagator if needed.

3. **NTT syntax gaps surfaced**:
   - `:q-module Q` — declare cell as Q-module; flagged for NTT design resumption
   - `:action (q ⊗ m)` — quantale action declaration
   - `bridge ... :preserves [Galois]` — Galois connection annotation; aligns with existing bridge syntax
   - `:fires-when (predicate)` — runtime-condition-gated fire (already flagged D.3 §4.5)

4. **Quantaloids (out of scope)** — when multi-domain cost currencies emerge (memory + messages + time), the quantale-of-quantales pattern (Stubbe 2013) becomes load-bearing. Not Phase 1 scope; flagged for future.

### §4.5 (D.3) `:fires-when` extension-note — UPDATED FOR D.4

Under D.3 hybrid pivot, the `:fires-when` NTT extension was a refinement candidate; under D.4 on-network framing (per §4.6), the equivalent pattern is `:on-write-check` (cell-layer predicate) — see §4.6. The `:fires-when` extension would still be useful for tracks where per-event filtering at scheduler level is performance-critical (NOT this addendum).

### §4.6 Specialized cell type framework (NEW per D.4 — on-network optimized cell type) (NEW)

**The architectural pivot from hybrid (D.3) to on-network optimized (D.4)** rests on extending the cell mechanism with PER-CELL declarations of storage strategy + fire-on policy + on-write predicates. This subsection NTT-models the framework.

**Cell type declarations** extend `cell` syntax with optional fields:

```ntt
;; Generic cell (current; D.3 baseline)
cell <name>
  :type <LatticeType>
  :merge <merge-fn>
  :bot <bot-value>

;; D.4 specialized cell (extends above with optimization declarations)
cell <name>
  :type <LatticeType>
  :merge <merge-fn>
  :bot <bot-value>
  :tier 'hot | 'warm | 'cold       ;; storage tier (extends BSP-LE Track 0 prop-net-hot/cold split to cells)
  :storage 'monotone-counter |     ;; specialized storage strategy
           'general |              ;; (default)
           'sparse |
           ...
  :fires-on 'any-change |          ;; when do dependent propagators fire?
            'threshold-crossing |  ;; only on threshold-crossing (cheap monotone case)
            'monotonic-progress |
            ...
  :on-write-check <predicate>      ;; OPTIONAL: inline check at write time
                                    ;; if predicate returns truthy, write contradiction
                                    ;; (replaces threshold propagator pattern)
  :on-read-check <predicate>       ;; OPTIONAL: inline check at read time
                                    ;; (typically used for derived properties)
```

**For the canonical fuel cost cell** (D.4 Phase 1B/1C):

```ntt
cell fuel-cost
  :type TropicalFuel              ;; per §4.1
  :merge tropical-fuel-merge       ;; min (idempotent)
  :bot 0
  :tier 'hot                       ;; per-decrement workload; needs hot-path
  :storage 'monotone-counter       ;; non-decreasing integer; direct fixnum storage
  :fires-on 'threshold-crossing    ;; only fire dependent propagators when cost crosses budget
  :on-write-check (lambda (new-cost net)
                    (>= new-cost (net-cell-read net fuel-budget-cell-id)))
  ;; if on-write-check returns #t, the cell-write path writes contradiction
  ;; structurally (NO separate threshold propagator)
```

**Cell mechanism dispatch** (under-the-hood):

```racket
;; net-cell-write under D.4 specialized cell type framework
(define (net-cell-write net cell-id new-value)
  (define meta (net-cell-meta net cell-id))
  (cond
    ;; FAST PATH: hot + monotone-counter + no-speculation
    [(and (eq? (cell-meta-tier meta) 'hot)
          (eq? (cell-meta-storage meta) 'monotone-counter)
          (not (under-speculation? net)))
     (define current (direct-counter-cell-ref net cell-id))
     (define merged (tropical-fuel-merge current new-value))
     ;; On-write predicate check (replaces threshold propagator):
     (cond
       [(and (cell-meta-on-write-check meta)
             ((cell-meta-on-write-check meta) merged net))
        (net-contradiction net 'tropical-fuel-exhausted)]
       [else
        (define net' (direct-counter-cell-set! net cell-id merged))
        ;; Fire-on policy: only notify dependent propagators if threshold crossed
        (cond
          [(and (eq? (cell-meta-fires-on meta) 'threshold-crossing)
                (not (threshold-crossed? current merged)))
           net']  ;; no propagator-fire ceremony
          [else
           (notify-dependents net' cell-id)])])]

    ;; SLOW PATH: general case (existing net-cell-write logic)
    [else
     (existing-net-cell-write-implementation net cell-id new-value)]))
```

Key properties:
1. **The cell IS the live state** — `direct-counter-cell-ref` reads the live value; no struct field carve-out
2. **Direct fixnum mutation under no-speculation** — no `tagged-cell-value` wrapping; no allocation per write
3. **Inline on-write check** — no propagator-fire ceremony for threshold detection; the check runs in-line during cell-write
4. **Fire-on-threshold-crossing only** — most cell-writes don't notify propagators (only the rare threshold crossing does); the BSP scheduler doesn't see per-decrement worklist entries
5. **Scheduler-neutral** — Gauss-Seidel, BSP, Zig-LLVM all run this dispatch identically; the optimization is at the cell layer

**Under speculation worldview**:
- The fast path falls through to the general case (correctness preserved via `tagged-cell-value`)
- Speculation paths happen RARELY relative to hot-path decrements; the overhead amortizes
- Per D.3.EC MG2 (still relevant): multi-worldview cell-write deferred to Phase 3A measurement

**NTT Observations**:
1. **Everything on-network?** YES. The fuel cost cell IS the live state; on-write check is a cell-layer property; fire-on policy is cell-layer declaration. No off-network struct field carve-out.
2. **Architectural impurities revealed?** NONE under D.4 (compared to D.3 which had the principle inversion at §10.1.A acknowledged-but-not-fixed).
3. **NTT syntax gaps surfaced**:
   - `:tier 'hot`/'warm'/'cold' — extends cell registration with storage-tier annotation (cell mechanism dispatches; scheduler agnostic)
   - `:storage 'monotone-counter` — declares specialized storage strategy
   - `:fires-on 'threshold-crossing` — declares fire-on policy (more granular than "any-change")
   - `:on-write-check predicate` — inline check at write time (replaces separate threshold propagator)
   - `:on-read-check predicate` — inline check at read time (for derived properties on read)
4. **Scheduler-portability check**: ✓ all declarations are CELL properties; scheduler reads them via uniform `net-cell-write` API; no scheduler-specific dispatch.
5. **CALM-safety check**: ✓ the on-write predicate is monotone (cost can only grow; threshold crossing is monotone-detectable). The cell value lattice (tropical fuel) is monotone. CALM theorem applies.

**Implementation cost**:
- Cell mechanism extension (cell-meta fields + `net-cell-write` dispatch + direct-counter-cell storage): ~150-300 LoC (new module: `specialized-cells.rkt`)
- Fuel-cost cell registration (uses the framework): ~30-50 LoC (within `tropical-fuel.rkt`)
- Tests for the framework + fuel-cost cell: ~100-200 LoC

**Total**: ~250-450 LoC for Phase 1B (specialized cell framework + fuel-cost cell registration + tests). Phase 1C remains direct migration of decrement/check sites (~100-200 LoC).

**Comparison to D.3 (hybrid pivot)**:
- D.3 Phase 1B: ~150-250 LoC (just the substrate + threshold propagator)
- D.3 Phase 1C: ~45-90 LoC (hybrid; struct-field preserved)
- D.3 total: ~200-340 LoC, but with hybrid scaffolding maintenance debt
- D.4 Phase 1B: ~250-450 LoC (cell framework extension + cell registration + tests)
- D.4 Phase 1C: ~100-200 LoC (direct migration)
- D.4 total: ~350-650 LoC; NO scaffolding maintenance debt; PReduce + OE inherit the framework

D.4 is MORE work UPFRONT but pays off through (a) no retirement work later, (b) framework reuse by future tracks.

**Pre-0 spike to verify feasibility**: see §13.6 (NEW).

---

## §5 Design Mantra Audit (Stage 0 gate)

Per DESIGN_METHODOLOGY Stage 0 Design Mantra Audit. Mantra: *"All-at-once, all in parallel, structurally emergent information flow ON-NETWORK."*

| Component | All-at-once | Parallel | Emergent | Info flow | On-network |
|---|---|---|---|---|---|
| Tropical fuel cell primitive (1B) | ✓ per-cell alloc | ✓ consumer-parallel | ✓ from SRE domain | ✓ cell merges | ✓ cell-based |
| Canonical BSP fuel instance (1C) | ✓ pre-alloc in make-prop-network | ✓ threshold propagator + fire-fn | ✓ from fuel/budget comparison | ✓ cost accumulates via merge | ✓ cell-based |
| Multi-quantale composition (§4) | ✓ all bridges installed at registration | ✓ Q-module independence | ✓ from Galois connection structure | ✓ via bridge propagators | ✓ |
| Residuation operator (read-time) | N/A (pure function) | — | ✓ from quantale algebra | ✓ caller threads result through cells | read-time pure function |
| ATMS internal retirement (1A-iii-b) | N/A (deletion) | — | — | — | removes off-network deprecated APIs |
| Surface ATMS AST retirement (1A-iii-c) | N/A (deletion) | — | — | — | removes 14-file pipeline scaffolding |

**Findings**: all components satisfy mantra. The residuation operator is intentionally a read-time pure function (per Q-1B-4 lean); when a propagator needs it, the propagator wraps it — keeping the operator algebraically simple AND consumer-flexible. This is the SAME pattern as `type-tensor-core` (SRE 2H) being a read-time function while `make-pi-fire-fn` wraps it in a propagator.

**Adversarial challenge**: could the residuation operator be MORE on-network? E.g., as a propagator that watches a contradicted fuel cell + writes a derivation chain cell?
- Counter-challenge: Phase 1B's primitive doesn't HAVE a derivation chain cell — that's Phase 3C's anticipated infrastructure (forward-captured per Q-Open-2). Wrapping the operator as a propagator in Phase 1B would prematurely commit to Phase 3C's design. Read-time helper is the right abstraction layer for the primitive.

---

## §6 Architectural decisions (refined from D.3)

Per Q-Open-1 (refine + verify, don't re-litigate). D.3 §6 architectural decisions (Q-A1, Q-A2, Q-A7, Q-A8) remain authoritative; this section refines + adds new decisions surfaced by this addendum.

### §6.1 Q-A1 — Phase partitioning (refined to γ-bundle-wide)

**Original D.3 decision**: 3 phases sequential (1, 2, 3 — substrate / orchestration / features); sub-phases A-Z as needed.

**Refinement (this addendum)**: γ-bundle-wide for Phase 1 (1A-iii-b + 1A-iii-c + 1B + 1C + 1V all in scope). Per Q-Open-1 + Q-Audit-2 findings: ATMS retirement (1A-iii-b/c) is naturally adjacent to substrate work — deprecating the OLD substrate (atms struct + surface AST) alongside shipping the NEW one (tropical primitive). 1V can close all of Phase 1 atomically.

### §6.2 Q-A2 — Tropical fuel cell placement (PRESERVED from D.3)

**D.3 decision**: Option 3 with canonical instance. Substrate-level tropical quantale registered as SRE domain; primitive API for consumer instantiation; canonical BSP scheduler instance allocated in `make-prop-network` using the primitive.

**This addendum verification**: Q-Audit-3 confirms `tropical-fuel.rkt` doesn't exist (clean slate); `make-prop-network` signature confirmed at propagator.rkt:81 (where canonical instance lives per cell-id 11/12 in §4.3). 5 anticipated consumer scaffolding sites in production (sre-rewrite, atms.rkt TODO, parse-lattice × 3) confirm the substrate-level placement is architecturally meaningful.

**No changes**.

### §6.3 Q-A3 — ATMS retirement scope (RESOLVED — γ-bundle-wide)

**D.3 §16.1 deferred to mini-design**: "how much of ATMS retirement (deprecated atms struct, atms-believed field per BSP-LE 2B D.1 finding, surface AST migration) is in Phase 1 vs deferred?"

**This addendum decision (per Q-Open-1 user direction γ-bundle-wide)**: ALL of ATMS retirement in Phase 1.
- 1A-iii-b: Tier 2 internal API + struct + atms-believed
- 1A-iii-c: Tier 3 surface AST 14-file pipeline + tests
- Both bundled per γ-bundle-wide decision

### §6.4 Q-A5 — atms-believed retirement timing (RESOLVED)

**D.3 §16.1 deferred to mini-design**: "atms-believed retirement timing (architecturally coupled to Q-A3)"

**This addendum decision**: atms-believed retires WITH the atms struct in Phase 1A-iii-b. Per BSP-LE Track 2 D.1 finding (decision cells are primary, worldview is derived as union of committed assumption bits), the atms-believed field was vestigial — the field tracking which assumptions are believed is structurally derivable and was a parallel source of truth. Retirement is structurally clean.

### §6.5 Q-A2-extension (NEW) — Phase 3C residuation cross-reference capture

**Per Q-Open-2 (A+B+cross-reference capture)**:

- **Form A** (Phase 1B unit test): tests/test-tropical-fuel.rkt includes test cases for the residuation operator. Cases:
  - `(tropical-left-residual 0 0) = 0` (identity)
  - `(tropical-left-residual 5 10) = 5` (b - a when b >= a)
  - `(tropical-left-residual 10 5) = 0` (top — overspend)
  - `(tropical-left-residual a infty) = (- infty a)` (= infty for finite a)
  - `(tropical-left-residual infty b) = 0` (vacuous)
- **Form B** (Phase 1B design enumerates Phase 3C anticipated use cases):
  - **UC1**: Fuel exhaustion → reverse-walk propagator dependency graph from contradicted cell → sum per-step costs → identify which propagators consumed the budget → blame attribution. Per research §10.3.
  - **UC2**: Cost-bounded elaboration — given a budget, compute "what types are elaborable within budget" via γ direction of type-cost-bridge (§4.2). Per research §10.4.
  - **UC3**: Per-branch cost tracking in union-type ATMS branching (Phase 3A) — per-branch tropical fuel cell allocated; threshold per branch; residuation walks per-branch dependency chain on contradiction.
- **Form C** (Phase 3C cross-reference capture): D.3 Phase 3 design (§9.5 "Phase 3C deliverables" in current D.3) gets a NEW subsection with cross-reference back to this addendum's §6.5 + §9.7 (residuation operator + UC enumeration). This is the capture mechanism — when Phase 3C design opens, the implementer picks up the cross-reference and runs the proof of concept for UC1/UC2/UC3.

This is the capture-gap pattern's correct application: capture lives at the right phase (3C), not in current phase (1B); cross-reference makes it discoverable; design-time enumeration ensures it's load-bearing.

### §6.6 Cross-cutting concerns matrix (refined)

| Parent Track Phase | This addendum interaction | Notes |
|---|---|---|
| Step 2 ✅ CLOSED | Tropical fuel cells co-exist with type meta universe cells per §4.3 | No interference; different quantales |
| **Phase 1A-iii-b + 1A-iii-c (this addendum)** | ATMS substrate retirement bundled | Tier 2 + Tier 3 both in scope per γ-bundle-wide |
| **Phase 1B + 1C + 1V (this addendum)** | Tropical fuel substrate ships | First optimization-quantale instantiation |
| Phase 1E | AFTER this addendum implementation lands | 5 carry-forward Q1-Q5 per D.3 §7.6.16; conversational Stage 4 |
| Phase 2 (orchestration) | Independent of this addendum | Likely after Phase 1E |
| Phase 3A/B/C | Phase 3C consumes tropical residuation operator | Forward-captured per §6.5 |
| Phase 4 (CHAMP retirement, parent track) | Coordinates with PM Track 12 on cache fields | Orthogonal mostly |
| Track 4D | Per-command transient consolidation | Forward-captured in DEFERRED.md from Step 2 |
| **Future PReduce series** | Inherits tropical quantale primitive for cost-guided rewriting / e-graph extraction | **First production landing establishes pattern. Hybrid-as-scaffolding caveat (D.3 from P6 REFINEMENT)**: under D.3 hybrid pivot, the pattern being established is SCAFFOLDING (cell substrate co-exists with off-network fast-path until SH Series runtime supports full migration per [Issue #55](https://github.com/LogosLang/prologos/issues/55)), NOT the architectural target. **Future PReduce consumers should DESIGN TO TARGET full cell-substrate migration** (per D.1's original framing) and only fall back to hybrid pattern IF measurement shows runtime constraints (with their own R-19-equivalent empirical justification + Issue tracking + DEFERRED.md entry per the four-surface tracking discipline at §10.1.A). The hybrid is a SCAFFOLDING pattern, NOT a template. |
| **OE Series** | This addendum is OE Track 0/1/2's first production landing | Per MASTER_ROADMAP.org § OE; formalization decision deferred. **Same hybrid-as-scaffolding caveat as PReduce row above (D.3 from P6 REFINEMENT)**: future OE consumers (cost-bounded weighted parsing, multi-cost-currency tracking, future cost-guided search) target full cell-substrate per D.1 design intent; hybrid scaffolding pattern requires per-track empirical justification (their own R-19-equivalent baseline) + retirement plan with specific blocker named + four-surface tracking. Without this discipline, hybrid scaffolding propagates as the implicit architectural default across the codebase, perpetuating the Cell-as-Single-Source-of-Truth principle inversion (per §10.1.A). |
| **Future Self-Hosting** | Polynomial Lawvere Logic is the language-surface form | Out of scope per §1.3 |

---

## §7 Phase 1A-iii-b — Tier 2 deprecated ATMS internal API retirement

### §7.1 Scope and rationale

Retire the deprecated `atms.rkt` internal API (13 functions + struct + atms-believed field). Modern API (`solver-context`/`solver-state` from BSP-LE 2) coexists; this phase removes the deprecated parallel surface.

### §7.2 Audit-grounded scope (Q-Audit-2 findings)

**Functions to retire** (atms.rkt:213-251+, all exported at lines 41-61):
1. `atms-assume` (line 213)
2. `atms-retract` (line 225)
3. `atms-add-nogood` (line 235)
4. `atms-consistent?` (line 241)
5. `atms-with-worldview` (line 251)
6. `atms-amb`
7. `atms-read-cell`
8. `atms-write-cell`
9. `atms-solve-all`
10. `atms-explain-hypothesis`
11. `atms-explain`
12. `atms-minimal-diagnoses`
13. `atms-conflict-graph`
14. `atms-amb-groups` (accessor)

**Struct to retire**:
- `atms` struct (line 159+) with fields including `atms-believed`
- `atms-empty` constructor
- `atms?` predicate (referenced at pretty-print.rkt:502, stratified-eval.rkt:206)

**Internal consumer cleanup**:
- `pretty-print.rkt:502`: replace `(if (atms? v) (hash-count (atms-assumptions v)) 0)` with solver-state-based equivalent OR remove if dead
- `stratified-eval.rkt:206`: `[(atms) #t]` symbol case — verify no longer reachable post-Tier-2 retirement; remove or migrate

**Tests**:
- `tests/test-atms.rkt` — pre-migration audit: which tests verify deprecated APIs vs modern solver-state? Decision: migrate tests to use `solver-state` API where coverage gap exists; delete tests that verify only-deprecated behavior

### §7.3 Sub-phase plan

- **1A-iii-b-i** — Pre-implementation audit (mini-audit): grep all production callers of each deprecated function; classify migration target (solver-state equivalent or delete); enumerate test cases per category
- **1A-iii-b-ii** — Function retirement (atomic commit): retire 13 functions + struct + atms-empty; remove from provide block (atms.rkt:41-61)
- **1A-iii-b-iii** — Internal consumer cleanup: pretty-print.rkt + stratified-eval.rkt
- **1A-iii-b-iv** — Test migration/deletion: per audit findings
- **1A-iii-b-v** — Verification + close: probe + targeted suite + full suite + parity test

### §7.4 Drift risks (per phase mini-design + audit before implementation)

Risks named at design time; verified at implementation:
- **D-b-1**: Deprecated function may have hidden callers not caught by grep (e.g., dynamically-resolved via `eval` or callback)
- **D-b-2**: Test deletion vs migration decision — verify modern solver-state API has equivalent coverage
- **D-b-3**: pretty-print.rkt `atms?` removal may surface dead code paths
- **D-b-4**: stratified-eval.rkt symbol case may have semantic significance (e.g., type predicate) — audit before removal

### §7.5 Termination + parity

- Termination: pure deletion phase; no new propagators; no recursive structure changes. Trivially terminates.
- Parity: tropical-fuel-parity axis doesn't apply here. Per D.3 §7.11, this phase contributes "ATMS-deprecated-API parity" axis — pre-retirement vs post-retirement: behavior identical for non-ATMS-deprecated callers; deprecated callers either migrated or removed.

### §7.6 Open questions (deferred to per-phase mini-design+audit per user's workflow)

- Q-1A-iii-b-1: Test migration vs deletion criteria — needs audit of test coverage gap
- Q-1A-iii-b-2: pretty-print.rkt `atms?` removal — does this surface dead code or active state we should preserve via solver-state?

---

## §8 Phase 1A-iii-c — Tier 3 surface ATMS AST 14-file pipeline retirement

### §8.1 Scope and rationale

Retire the surface ATMS AST 14-file pipeline. The user-facing surface ATMS expressions (e.g., `(atms-new (net-new 1000))`, `(atms-assume atms :h0 true)`) are scaffolding from a pre-solver-state era. Modern solver-state-driven approach replaces; surface AST retirement removes the 14-file maintenance burden per the AST node pipeline checklist (`.claude/rules/pipeline.md`).

### §8.2 Audit-grounded scope (Q-Audit-2 findings)

**Per `.claude/rules/pipeline.md` "New AST Node" checklist applied IN REVERSE** (retirement):

**Core pipeline (always touched)**:
1. `syntax.rkt:202-208` — 14 surface AST struct exports
2. `syntax.rkt:750-767` — 14 struct definitions
3. `substitution.rkt` — verify shift/subst cases for atms-* (likely exists; remove)
4. `zonk.rkt:358-1258` — surface atms traversal (~50 lines per D.3 §7.5.7)
5. `reduction.rkt:2842-3635` — surface atms evaluation (~100 lines)
6. `pretty-print.rkt:506-521` — surface atms display
7. `pretty-print.rkt:1142-1146` — uses-bvar0?
8. `pnet-serialize.rkt` — verify reg0!/reg1!/regN! for auto-cache (likely retire)
9. `typing-core.rkt` — surface atms type-check
10. `qtt.rkt:1773-1839` — surface atms type rules

**User-facing surface syntax**:
11. `surface-syntax.rkt:925-933` — 10 surf-atms-* structs (per D.3 §7.5.7)
12. `parser.rkt:2531-2607` — surface atms parse rules (~80 lines)
13. `elaborator.rkt:2438-2466` — surface atms elaboration

**Dependency cleanup** (per D.3 §7.5.7):
- `typing-errors.rkt`, `substitution.rkt`, `qtt.rkt`, `trait-resolution.rkt`, `capability-inference.rkt`, `union-types.rkt` — grep + remove references

**Tests**:
- `tests/test-atms.rkt` — DELETE (full surface AST exercise)
- `tests/test-atms-integration.rkt` — DELETE (~100 test cases per audit observation)
- `tests/test-atms-types.rkt` — DELETE

**Trace/serialize**:
- `trace-serialize.rkt:75-89` — atms-event:* references (these are EVENT types, not the atms struct; verify if they reference deprecated state — they may stay if event types remain valid)

### §8.3 Sub-phase plan (14-file pipeline retirement ordering)

Per pipeline.md retirement protocol (REVERSE of "New AST Node"):

- **1A-iii-c-i** — Pre-implementation audit (mini-audit): grep every file in pipeline.md checklist; verify all 14 structs are in scope; identify any external callers in lib/ or examples/; classify trace-serialize references
- **1A-iii-c-ii** — Surface forms retirement (parse + elaboration): parser.rkt + elaborator.rkt + surface-syntax.rkt — surface forms can no longer be parsed
- **1A-iii-c-iii** — Pipeline core retirement (substitution + zonk + reduction + pretty-print): cores can no longer process them
- **1A-iii-c-iv** — Type rules retirement (typing-core + qtt): type-checker can no longer type them
- **1A-iii-c-v** — Struct definition retirement (syntax.rkt): structs no longer exist
- **1A-iii-c-vi** — Test deletion (3 test files; ~100+ test cases)
- **1A-iii-c-vii** — Dependency cleanup (typing-errors + substitution + qtt + trait-resolution + capability-inference + union-types) + trace-serialize verification
- **1A-iii-c-viii** — Verification + close: probe + targeted suite + full suite + parity test

### §8.4 Drift risks

- **D-c-1**: Hidden parser callers (e.g., macro expansion of atms-* forms)
- **D-c-2**: Library files (lib/) referencing surface ATMS forms — would surface as elaboration errors post-retirement
- **D-c-3**: `examples/` files using surface ATMS — verify and migrate to solver-state-based approach OR delete examples
- **D-c-4**: trace-serialize atms-event:* references — these might be event types valid for solver-state too; audit before retiring
- **D-c-5**: Test deletion may surface unrelated test isolation issues — verify with shared-fixture pattern

### §8.5 Termination + parity

- Termination: deletion phase; trivially terminates
- Parity: "surface-ATMS-AST-elaboration parity" — pre-retirement: surface forms parse + elaborate + type-check + reduce; post-retirement: surface forms parse error (correct behavior — forms no longer exist)

### §8.6 Open questions (deferred to per-phase mini-design+audit)

- Q-1A-iii-c-1: trace-serialize.rkt atms-event:* — retire with surface AST or preserve for solver-state events?
- Q-1A-iii-c-2: examples/ files using surface ATMS — migrate to solver-state OR delete entirely?
- Q-1A-iii-c-3: lib/ files using surface ATMS — extent of migration impact

---

## §9 Phase 1B — Tropical fuel primitive + Specialized cell framework + SRE registration (D.4 CANONICAL)

> **D.4 CANONICAL status (2026-05-14)**: §13.6 Pre-0 spike PASSED (commit `7b681b9e`). Phase 1B under D.4 ships THREE deliverables: (1) the tropical fuel primitive module (per the D.3 scope, preserved); (2) the specialized cell type framework module (NEW under D.4 per §4.6); (3) the fuel-cost cell registration via the framework (NEW under D.4). The threshold propagator factory from D.3 is RETIRED — the threshold check becomes a cell-layer `:on-write-check` predicate, replacing the propagator.

### §9.1 Scope and rationale (D.4 CANONICAL)

Ship three foundational pieces:
1. **Tropical fuel primitive module** (`racket/prologos/tropical-fuel.rkt`) — quantale axioms + merge + tensor + residuation; SRE domain registration
2. **Specialized cell type framework module** (`racket/prologos/specialized-cells.rkt`, NEW under D.4) — cell-meta fields (`:tier`, `:storage`, `:fires-on`, `:on-write-check`, `:on-read-check`) + dispatch logic in `net-cell-write` + registration API
3. **Canonical fuel-cost cell registration** — uses the framework to register cell-id 11 (fuel-cost) + cell-id 12 (fuel-budget) with `:tier 'hot` + `:storage 'monotone-counter` + `:fires-on 'threshold-crossing` + `:on-write-check`

This is the substrate that Phase 1C (direct migration of decrement/check sites), Phase 3C (residuation error explanation, future), and OE Series consumers (future PReduce, weighted parsing per parse-lattice.rkt scaffolding) build on.

### §9.2 Architecture (refined from D.3 §7.7 + §10)

**Module**: `racket/prologos/tropical-fuel.rkt` (NEW; clean slate per Q-Audit-3)

**Imports** (per Phase 1B's foundational positioning):
- `sre-core.rkt` (for `make-sre-domain` + `register-domain!`)
- `merge-fn-registry.rkt` (for `register-merge-fn!/lattice`)
- `propagator.rkt` (for `net-new-cell` + `net-add-propagator` + `net-cell-read`/`write` + `net-contradiction`)
- No higher-level dependencies (primitive is foundational)

**Provides**:
```racket
(provide
  ;; Lattice constants
  tropical-fuel-bot           ;; = 0
  tropical-fuel-top           ;; = +inf.0
  tropical-fuel-merge         ;; = min
  tropical-fuel-contradiction?  ;; = (= +inf.0)
  tropical-fuel-tensor        ;; = +
  tropical-left-residual      ;; (a b) -> (if (>= b a) (- b a) 0)
  ;; Cell factories
  net-new-tropical-fuel-cell   ;; net -> (values net cell-id)
  net-new-tropical-budget-cell ;; net budget -> (values net cell-id)
  ;; D.4: the threshold check is a cell-layer predicate, NOT a propagator
  ;; (make-tropical-fuel-threshold-propagator from D.3 is RETIRED under D.4 canonical)
  ;; SRE domain (referenced by registrations)
  tropical-fuel-sre-domain)
```

### §9.2.0 1B-i mini-audit findings (D.4 CANONICAL 2026-05-15 — validates A2)

> **Status**: ✓ GATE PASS. Q-1B-8 resolution A2 (meta field on `prop-cell` struct itself) is empirically validated.
> **Spike data**: [`racket/prologos/data/benchmarks/tropical-1b-i-cell-meta-2026-05-15.txt`](../../racket/prologos/data/benchmarks/tropical-1b-i-cell-meta-2026-05-15.txt).
> **Microbench code**: [`bench-ppn-track4c.rkt`](../../racket/prologos/benchmarks/micro/bench-ppn-track4c.rkt) §CM1-CM5.

**Codebase audit findings**:

- **`prop-cell` struct** at `propagator.rkt:253`: current 2 fields `(value dependents)`, `#:transparent`. A2 modification adds a 3rd `meta` field → `(value dependents meta)`.
- **~30 construction sites** in `propagator.rkt` use the 2-arg constructor `(prop-cell init-val champ-empty)` — all need updating to `(prop-cell init-val champ-empty #f)` in 1B-ii. Backward compat via `meta = #f` default for regular cells.
- **`struct-copy` sites** for `prop-cell` (~5 sites) preserve unspecified fields automatically — no changes needed beyond the struct definition itself.
- **Accessors** `prop-cell-value`, `prop-cell-dependents` unchanged. `prop-cell-meta` becomes the new accessor for specialized-cell dispatch.
- **Cell-id allocation**: production `make-prop-network` (lines 621-660) allocates 11 well-known cells (cell-ids 0-10: req-cell, wv-cell, rs-cell, cfg-cell, naf-cell, pc-cell, cp-cell, elab-cell, narr-cell, sre-cell, cir-cell). Cell-ids 11/12 (fuel-cost-cell + fuel-budget-cell per §4.3) are the next slots — no conflict (resolves D-1C-3).

**Microbench results (CM1-CM5)** — 50000 iterations per measurement; mock structs mimic A2's layout; DCE defeated via mutable-box accumulator:

| Measurement | Result | Notes |
|---|---|---|
| CM1.1 2-field construct (current baseline) | 5 ns/call | Current production rep |
| CM1.2 3-field construct, meta=#f (backward-compat) | 5 ns/call | **NO construction regression for regular cells** |
| CM1.3 3-field construct, meta=sample (specialized) | 5 ns/call | NO regression for specialized cells either |
| **CM2.2 meta accessor, meta=sample (CORE GATE)** | **4.06 ns/call** | **§13.7 target ≤ 5 ns → ✓ PASS** |
| CM2.1 meta accessor, meta=#f | 4 ns/call | Common case |
| CM3.1 backward-compat branch, meta=#f | 5 ns/call | `(if meta special generic)` short-circuits to generic |
| CM3.2 specialized branch, meta=sample | 4 ns/call | Takes special path |
| CM4 chained access `cell-meta-tier ∘ prop-cell-meta` | 7 ns/call | 2 struct-field reads |
| CM5.1 full dispatch, meta=#f (slow-path bypass) | 4 ns/call | `and` short-circuits at meta=#f |
| CM5.2 full dispatch, meta=sample (full path) | 54 ns/call | **Parameter-ref dominates; see surfaced finding** |

**Verdict: ✓ GATE PASS** — A2 confirmed feasible. 1B-ii proceeds with `(struct prop-cell (value dependents meta) #:transparent)` modification + the ~30 construction-site updates.

**Surfaced architectural finding for 1B-ii** (the microbench made visible):

CM5.2's 54 ns/call is **dominated by the Racket-parameter ref** for the speculation check (`(mock-current-speculation)`). Production uses `(current-speculation-assumption)` (parameter) per `metavar-store.rkt:194`. If 1B-ii's `net-cell-write` fast-path dispatch reads the speculation state via a parameter, the dispatch overhead is ~54 ns (10× the §13.6 spike's 6.4 ns vector-ref dispatch). **The §13.6 spike's W1+ measurement didn't include a parameter ref** — it used a struct field on the mock-net to indicate speculation state.

**Architectural recommendation for 1B-ii**: avoid Racket parameter for the speculation check in the cell-write fast path. Options:
- A: read speculation state from a struct field on `prop-net-warm` (where contradiction already lives) — ~1 ns access
- B: pass the under-speculation flag as an explicit argument to `net-cell-write` (caller-supplies; scheduler knows its own speculation state) — 0 ns intrinsic
- C: keep parameter but only check it on a slow path (most writes are no-speculation; structure dispatch to skip the param ref entirely under the common case)

Lean: **A (struct field on `prop-net-warm`)** — preserves orthogonality (state on-network; no scheduler coupling), constant-time check, no parameter overhead. Confirm at 1B-ii mini-design.

**Lesson surfaced (codification candidate)**: per-phase microbench gates validate not just the gate-target answer, but also the **production implementation choices that the design didn't pin down**. Without CM5.2 measuring the parameter-based dispatch path, 1B-ii might have used a parameter for the speculation check (matching production's `current-speculation-assumption` convention) and silently regressed ~50 ns vs the §13.6 spike's vector-ref baseline. The microbench acted as a design-question surfacer, not just a gate validator. Watching list: 1 data point (this measurement); 1-2 more for graduation.

### §9.2.0.5 1B-ii mini-design resolutions (D.4 CANONICAL 2026-05-15)

Conversational mini-design between user + Claude opened 1B-ii by surfacing **four architectural questions** that the prior design didn't pin down (three NEW from the post-1B-i audit; one carried from 1B-i CM5.2). Resolutions captured here so 1B-ii implementation enters Stage 4 with the decisions locked in.

**Q-1B-ii-α — Speculation-check mechanism (carried from 1B-i CM5.2)**

The 1B-i microbench surfaced that using a Racket parameter for the speculation check (matching production's `current-speculation-assumption` convention at `metavar-store.rkt:194`) costs ~50 ns/call — defeating the cell-meta dispatch budget.

Options considered: (A) struct field on `prop-net-warm` alongside `contradiction`; (A') re-use existing cell-id 1 `worldview-cache-cell-id`; (B) explicit argument to `net-cell-write`; (C/D) parameter (rejected).

**Resolution**: **(A2) — struct field on `prop-net-warm`, scheduler-refresh form**. Speculation state co-locates with `contradiction` (matching lifecycle semantics — both are set during execution, cleared at rollback boundary); one struct-field load ~1 ns. The 2026-05-15 codebase audit surfaced an initial concern that adding the field would require refactoring 8 `parameterize` binding sites + threading the network through speculation entry/exit; the audit also overstated by counting 19 `struct-copy` sites as needing updates (struct-copy auto-preserves unspecified fields — no change needed).

**A2-scheduler-refresh form** keeps `parameterize` machinery unchanged. The BSP scheduler reads `(current-worldview-bitmask)` once at round entry and struct-copies `prop-net-warm` with `[under-speculation? (not (zero? bm))]`. The field is a **scheduler-maintained cache** of the parameter. Total cost: ~5-10 LoC at one site (the BSP round-entry code).

**Named constraint (load-bearing)**: the cache is **fresh per BSP round entry**; stays fixed during the round. If a fire function entered speculation mid-fire (via `with-speculative-rollback`), the parameter would go non-zero but the cache would stay stale until next round entry. **This is acceptable** because specialized cells are scheduler-state cells per DESIGN_PRINCIPLES.org § Scheduler-State Cells — they are written by the scheduler at round/phase boundaries, not by fire functions. The cache-staleness window doesn't overlap with specialized-cell writes in Phase 1B/1C. Future tracks adding specialized cells that ARE written by fire functions would need a different refresh discipline (likely write-time parameter ref inside the dispatch, or threading-style refactor).

**Why A2 over A' (cell-id 1 worldview-cache)**: A' would re-use cell-id 1 which was allocated for the tagged-cell-value worldview-bitmask cache mechanism. Re-using it for specialized-cell dispatch couples two distinct concerns (tagged-cell-value caching + specialized-cell speculation gate) to the same cell. A2 gives speculation-state its own dedicated, named field; matches the existing co-location pattern with `contradiction`. More principled. Implementation cost is similar (~10 LoC vs ~5 LoC).

### §9.2.0.6 1B-iii mini-design resolutions (D.4 CANONICAL 2026-05-15/16)

Conversational mini-design + codebase audit opened 1B-iii (tropical-fuel module + SRE registration + C-series). Four architectural questions resolved.

**Q-1B-iii-α — Cell value semantic: remaining-fuel vs accumulated-cost**

The design has an internal tension flagged at 1B-ii close:
- §9.3 (algebraic foundations): `tropical-fuel-merge = min` (Lawvere join)
- §10.3 D.4 (Phase 1C migration patterns): `(net-cell-write net cid (+ current n))` — writes accumulate UP
- Under min-merge, `(min current current+n) = current` → writes silently dropped

Two framings considered:

| Option | Cell semantic | Initial | Writes | Operational exhaustion | Algebraic correctness |
|---|---|---|---|---|---|
| A | "Remaining fuel" (counts down) | `budget` | `(- current n)` | `(<= remaining 0)` | min-merge correctly takes the lower-remaining ✓ |
| B | "Accumulated cost" (counts up) | `0` | `(+ current n)` | `(>= cost budget)` | requires max-merge or replace; breaks Lawvere consistency |

**Resolution: Option A (remaining fuel)**. Rationale:
- Matches existing native fuel mechanism 1:1 (`prop-net-hot.fuel` decrements; cell becomes on-network equivalent)
- Algebraically clean under Lawvere convention — writes refine downward; min-merge correctly takes the lower-remaining value at speculation reconciliation
- Phase 1C migration scope shrinks (decrement sites become subtractions, not the broader rewrite)
- The "cost" framing remains as semantic concept: derive `cost = budget - remaining` when needed
- §10.3 D.4 examples (`(+ current n)`) are wrong under Option A — they need correcting at 1B-iv cell registration / Phase 1C migration. **Tracked as a 1B-iv consistency item**.

**Constraint on §9.4 SRE domain (preserved unchanged)**:
- `bot-value = 0`, `top-value = +inf.0`, `contradicts? = (= v +inf.0)` stay as-is. These describe the **abstract tropical quantale** (`T_min` per §9.3). The operational exhaustion check for the fuel-cost cell happens at the **cell-specific `on-write-check` layer** (1B-iv) — `(λ (old new net) (<= new 0))`. The two predicates serve different purposes:
  - SRE domain `contradicts?` — "is this value the algebraic top?" (lattice-level)
  - Cell `on-write-check` — "does this write trigger the operational threshold?" (cell-level)

This separation is **architecturally cleaner**: the SRE domain captures abstract algebra; the cell instance overlays operational semantics. 1B-iii ships the algebra; 1B-iv applies it.

**Q-1B-iii-β — SRE domain registration scope: full quantale property declarations**

Resolution: ship the FULL quantale property declarations per §9.4 (commutative-join, associative-join, idempotent-join, has-meet, distributive, quantale, commutative-quantale, unital-quantale, integral-quantale, residuated, has-pseudo-complement). Plus operations: `tensor` (= `+`) + `residual` (= `tropical-left-residual`). Plus a meet function (= `max`; registered via meet-registry for downstream consumers).

Rationale: the addendum's thesis is "tropical quantales as cost-optimization substrate." Declaring properties is load-bearing for SRE Track 2I's property-cell mechanisms / property-based testing. Future tracks (PReduce e-graph cost extraction, OE Series) read these declarations to validate algebraic preconditions.

**User-flagged consideration**: "this should be something we can test for with our SRE algebraic mechanisms/property testing." SRE Track 2I's property-testing infrastructure (sweep matrices via `all-sweep-properties`) can verify the declared properties against samples. **Tracked as a 1B-iii post-impl consideration**: after the domain is registered, run the SRE property-testing sweep on it to confirm the declarations hold empirically. If property infrastructure isn't ready, defer to 1B-iv close or Phase 1V.

**Q-1B-iii-γ — C-series scope and methodology**

Resolution: C1 (quantale axioms) + C2 (residuation laws) + C3 (integral verification) in 1B-iii. C4 (module-theory laws) + C5 (CALM-safety) deferred to 1B-iv where cells exist to test module action + CALM property. Place tests in `tests/test-tropical-fuel.rkt` per §9.6.

Methodology: assertion-based via rackunit `check-equal?` with sample tuples + boundary cases. Particular attention to `+inf.0` edge cases per S5 ACKNOWLEDGE — distributivity, residuation at infinity, tensor identity at infinity, min identity at zero.

**Q-1B-iii-δ — API naming + representation choices**

Resolutions per Q-1B-1 / Q-1B-2 / Q-1B-4 (deferred to 1B-iii from earlier mini-design):
- **API naming** (Q-1B-1): `tropical-fuel-bot`, `tropical-fuel-top`, `tropical-fuel-merge`, `tropical-fuel-contradiction?`, `tropical-fuel-tensor`, `tropical-left-residual` per §9.2 Provides — locked in.
- **`+inf.0` vs sentinel** (Q-1B-2): `+inf.0` (Racket float-infinity). Racket-native, well-defined arithmetic, IEEE 754 absorbing-element semantics. Sentinel would complicate the residuation formula.
- **Residuation as helper vs propagator** (Q-1B-4): read-time helper (pure function). Phase 3C consumers wrap in propagator if needed.

**Summary**: 4 architectural questions resolved. 1B-iii ships the algebraic substrate; 1B-iv applies it to specific fuel-cost cell registration.

**Drift risks named for 1B-iii**:
- D-1B-iii-1: Numerical edge cases at `+inf.0` — verified via C1+C2 assertion tests
- D-1B-iii-2: Residuation formula correctness — verified via C2 adjunction law (`(+ a (tropical-left-residual a b)) <=_rev b`)
- D-1B-iii-3: merge-registry function signature — must return #f for unknown relations (verify against existing SRE domain patterns)
- D-1B-iii-4: 1B-iv consistency item — §10.3 D.4 `(+ current n)` examples are wrong under Option A; must correct at 1B-iv cell registration
- D-1B-iii-5: SRE property-test sweep on the new domain — deferred to 1B-iv close or Phase 1V if Track 2I infrastructure ready

### §9.2.0.7 1B-iv mini-design resolutions (D.4 CANONICAL 2026-05-16)

Conversational mini-design + codebase audit opened 1B-iv (canonical fuel cell registration via the framework). Four architectural questions resolved.

**Q-1B-iv-α — Shadow vs replace (the load-bearing decision)**

Two framings considered:

| Option | What ships in 1B-iv | What Phase 1C does |
|---|---|---|
| A (shadow) | Cells registered; `prop-net-hot.fuel` UNCHANGED; nothing reads/writes cells in production | Migrates decrement/check/read sites to cells; retires fuel field + macro |
| B (replace) | Cells registered + ALL decrement/check/read sites migrated + fuel field retired | (Phase 1C work absorbed into 1B-iv) |

**Resolution: Option A (shadow)**. Justified by §1.2 substrate-vs-migration phasing (Phase 1C IS the explicit deployment phase, sub-phased + scheduled — not deferred indefinitely). Smaller 1B-iv scope; cleaner review; reversible if Phase 1C surfaces issues.

**Discharging the "Validated ≠ Deployed" concern**: the anti-pattern is when the new path is validated but deployment is deferred indefinitely with a switch defaulting to OLD. Our case is structurally different — Phase 1C is the explicit deployment phase, immediately following 1B-iv. The cells are pre-deployment substrate ready for the next sub-phase. **Discipline commitment**: 1B-iv close commits to Phase 1C as the immediate next sub-phase (no drift to other tracks first). If Phase 1C is delayed, the cells DO become "validated not deployed" — flagged as D-1B-iv-5.

**Q-1B-iv-β — Cell naming under Option A semantic**

Under Option A (remaining-fuel), the cell tracks REMAINING, not COST. Design's `fuel-cost-cell-id` (per §4.3, §9.2.C, §10.3 D.4) is misleading. Three options considered.

**Resolution: B2 — rename to `fuel-cell-id`** (concise, semantically neutral). Together with `fuel-budget-cell-id` they form "the fuel state on the network." The cost framing remains a derived concept (`cost = budget - remaining`); cells themselves don't carry the "cost" label.

**Cross-section consistency items** (drift risks D-1B-iv-3 + D-1B-iv-4 — apply in impl commit):
- §4.3 cell-id allocation table: `fuel-cost-cell` → `fuel-cell`
- §9.2.C cell registration example: variable name + example direction (Option A: initial=budget, on-write-check uses `<=` on remaining)
- §10.3 D.4 patterns: `(net-cell-write net fuel-cost-cell-id (+ current n))` → `(net-cell-write net fuel-cell-id (- current n))`
- §9.2.C predicate signature: 2-arg `(new net)` → 3-arg `(old new net)` per Q-1B-9 F2

**Q-1B-iv-γ — Where the cell registration happens**

Two options considered:

| | Option | Cycle risk |
|---|---|---|
| **γ1** | **Inline in `make-prop-network`**; propagator.rkt requires tropical-fuel.rkt for `tropical-fuel-merge` | NO (one-way: propagator.rkt → tropical-fuel.rkt) |
| γ2 | Helper function exported from tropical-fuel.rkt; tropical-fuel.rkt requires propagator.rkt for `net-register-specialized-cell` + `cell-id` | YES (cycle: propagator.rkt ↔ tropical-fuel.rkt) |

**Resolution: γ1 (inline registration)**. γ2 creates a cycle. γ1's import direction is one-way; cycle risk verified absent by audit (tropical-fuel.rkt requires only sre-core.rkt + merge-fn-registry.rkt; neither imports propagator.rkt).

**Q-1B-iv-δ — `fork-prop-network` behavior under shadow mode**

`fork-prop-network` currently shares warm cells + creates fresh hot state with new `fuel` arg. Under shadow:
- Cells inherited (initial = budget, unchanged in Phase 1B since unused)
- prop-net-hot.fuel = new fuel arg (potentially different from cell value at fork time)
- Mismatch is HARMLESS in Phase 1B (cells unused by production)

**Resolution: leave `fork-prop-network` unchanged in 1B-iv**. Phase 1C will update `fork-prop-network` to also reset the cell to the new fuel value as part of its migration scope. Outside 1B-iv.

**Drift risks named for 1B-iv**:
- D-1B-iv-1: Cell initial value must be `fuel` parameter (NOT 0; Option A initial = budget). Both fuel-cell + fuel-budget-cell start at the same `fuel` parameter.
- D-1B-iv-2: On-write-check predicate signature `(old new net)` per Q-1B-9 F2.
- D-1B-iv-3: D-1B-iii-4 consistency — correct §10.3 D.4 + §9.2.C examples in impl commit.
- D-1B-iv-4: Cell name rename `fuel-cost-cell-id` → `fuel-cell-id` — propagate through design doc.
- D-1B-iv-5: 1B-iv close commits to Phase 1C as immediate next sub-phase (Validated≠Deployed discipline).
- D-1B-iv-6: cell-id 11/12 allocation order — verify at registration time via assertion.
- D-1B-iv-7: SRE property-sweep verification (Q-1B-iii-β) — verify post-impl if Track 2I infrastructure applies.

**Implementation plan summary**: ~30-50 LoC code + ~80-120 LoC tests + design corrections. Detailed steps in dailies + impl commit.

**Q-1B-ii-β — Specialized cell value storage location (NEW)**

The 1B-ii audit of `net-cell-write` (propagator.rkt:1205-1303) surfaced that the existing path does substantial work per call: 2 CHAMP lookups (cells + merge-fns) + tagged-cell-value wrapping + struct-copy prop-cell + CHAMP insert + dependent filtering + 2 struct-copy prop-network ≈ 140 ns total. The §13.6 spike's W1+ of 6.4 ns measured a vector-indexed sidecar mock that bypassed CHAMP entirely. Two architectures available:

- **CHAMP-based**: specialized cells live in the existing CHAMP; meta on prop-cell; net-cell-write has fast-path branches but uses the unified cell store. Production W1+ ~50-70 ns. Per-cycle amortized under Option 13 deferred-write at N=100 fires/round: ~0.5-0.7 ns (Variant A) or ~2.2 ns (Variant B, dominated by local-var set-box!).
- **Sidecar**: specialized cells live in a separate vector-indexed storage; bypass CHAMP for fast-path writes. Production W1+ ~6-10 ns matching spike. Adds dual-source-of-truth complexity (CHAMP entry + sidecar value; invariants under speculation-rollback; Phase 3C consumer API splits).

**Resolution**: **CHAMP-based**. Under Option 13 deferred-write, per-cycle cost is dominated by Variant B's local-var set-box! (~2 ns) or Variant A's amortization (~0.06 ns/cycle). The ~50 ns vs ~10 ns difference at the boundary becomes 0.5 ns vs 0.1 ns per cycle — tiny. Sidecar complexity (dual storage, invariant maintenance, Phase 3C API split) outweighs the marginal speedup. Per "Let pain drive design": ship the simpler architecture; future PReduce/OE Series tracks may want the sidecar; defer until concrete need.

**Q-1B-ii-γ — `specialized-cells.rkt` module shape (NEW; resolves §9.2.A ↔ §9.9 Q-1B-10 inconsistency)**

The design doc has an internal inconsistency: §9.2.A (drafted at D.4 scaffolding pass) places cell-meta struct + registration API + dispatch hooks in `specialized-cells.rkt`; §9.9 Q-1B-10 (resolved at the 2026-05-15 mini-design walkthrough) chose **B1-prime**: cell-meta + registration + dispatch in `propagator.rkt`, with `specialized-cells.rkt` as a thin convenience-only layer. The B1-prime resolution avoided a circular-import risk (the dispatch logic in `net-cell-write` needs cell-meta accessors).

Three shapes considered during mini-design:

| Shape | cell-meta location | `specialized-cells.rkt` | Trade-off |
|---|---|---|---|
| 1 | propagator.rkt | NOT shipped (no file) | Simplest; but framework/substrate boundary muddied; future tracks grow propagator.rkt |
| 2 (B1-prime) | propagator.rkt | THIN (re-exports + convenience constructors) | Framework anchor exists; no circular imports; thin layer ~20-40 LoC |
| 3 (§9.2.A as written) | specialized-cells.rkt | FULL (struct + API + dispatch hooks) | Most separation; circular-import risk; B1-prime rejected this |

**Resolution**: **Shape 2 (B1-prime)**. The D.4 §4.6 NTT model frames the specialized cell type framework as canonical infrastructure that future PReduce / OE / SH tracks inherit. Shape 1 muddies framework/substrate; Shape 3 has the import risk. Shape 2 establishes a proper anchor without duplication.

**Concrete split**:
- `propagator.rkt`: `cell-meta` struct, `net-register-specialized-cell` API, `net-cell-write` fast-path dispatch
- `racket/prologos/specialized-cells.rkt` (NEW, thin ~20-40 LoC): re-exports `cell-meta` + provides convenience constructors `make-monotone-counter-meta` and `make-cold-general-meta` for the two specialized cells Phase 1B/1C ships

**§9.2.A update required** (drive-by edit in this commit): align §9.2.A's Module / Imports / Provides description with Shape 2.

**Q-1B-ii-δ — §13.7 1B-ii gate target (NEW; revise under Option 13)**

The current §13.7 row for 1B-ii reads "Production W1+ ≤ 1.5× spike's 6.4 ns (≤ 10 ns) → PASS." But that gate was set BEFORE Option 13 was discovered (per §10.3.A 2026-05-15 refinement). Under Option 13 deferred-write, the load-bearing measurement is **per-cycle amortized cost at N=100 fires/round**, not per-call W1+.

**Resolution**: revise the §13.7 1B-ii gate to:
- **Primary (load-bearing)**: per-cycle amortized cost ≤ 3 ns at synthetic N=100 BSP round (matches Option 13 production reality)
- **Secondary (informational)**: production W1+ documented; expected ~50-70 ns under CHAMP-based; that's fine because Option 13 amortization absorbs it

§13.7 row will be updated in this commit.

**Summary**: 4 architectural questions resolved. 1B-ii enters Stage 4 with α/β/γ/δ locked in.

### §9.2.A Cell mechanism extension (D.4 CANONICAL — Shape 2 per §9.2.0.5 Q-1B-ii-γ)

**Two-module split (Shape 2)**:

| Module | Role | Ships in |
|---|---|---|
| `propagator.rkt` | `cell-meta` struct + `net-register-specialized-cell` API + `net-cell-write` fast-path dispatch + `under-speculation?` (reads `prop-net-warm.under-speculation?` field) | EXTENDED (cell-meta machinery added; no new file) |
| `racket/prologos/specialized-cells.rkt` | Re-exports `cell-meta` + provides convenience constructors (`make-monotone-counter-meta`, `make-cold-general-meta`) | NEW (~20-40 LoC thin) |

The cell-meta struct + registration API + dispatch live in `propagator.rkt` because `net-cell-write`'s fast-path dispatch needs cell-meta accessors (the §9.9 Q-1B-10 B1-prime resolution avoids circular imports this way). `specialized-cells.rkt` is the **conceptual anchor for the framework** — future PReduce / OE / SH tracks looking for "how do I declare a specialized cell?" find it here. Phase 1B/1C uses it for the two convenience constructors; future tracks extend it without modifying `propagator.rkt`.

This module extends the propagator network's cell mechanism with per-cell declarations of storage strategy, fire-on policy, and on-write/on-read predicates — per the §4.6 NTT model. Under no-speculation, hot+monotone-counter cells use direct fixnum mutation (no `tagged-cell-value` wrapping, no per-write allocation). Under speculation (detected via `prop-net-warm.under-speculation?` field per Q-1B-ii-α), the fast path falls through to the existing generic cell-write with `tagged-cell-value` worldview tagging (per-D.3.EC-MG2; multi-worldview measurement deferred to Phase 3A).

**`propagator.rkt` extensions (cell-meta machinery)**:

```racket
;; In propagator.rkt — colocated with prop-cell struct + net-cell-write
(provide
  cell-meta cell-meta?
  cell-meta-tier cell-meta-storage cell-meta-fires-on
  cell-meta-on-write-check cell-meta-on-read-check
  net-register-specialized-cell
  under-speculation?)
```

**`racket/prologos/specialized-cells.rkt` (NEW; thin convenience layer)**:

```racket
;; Re-exports cell-meta from propagator.rkt + provides convenience constructors
(require "propagator.rkt")
(provide
  (struct-out cell-meta)               ;; re-export
  net-register-specialized-cell        ;; re-export
  make-monotone-counter-meta           ;; tier='hot, storage='monotone-counter, fires-on='threshold-crossing
  make-cold-general-meta)              ;; tier='cold, storage='general, fires-on='any-change

(define (make-monotone-counter-meta on-write-check)
  (cell-meta 'hot 'monotone-counter 'threshold-crossing on-write-check #f))

(define (make-cold-general-meta)
  (cell-meta 'cold 'general 'any-change #f #f))
```

Future tracks adding storage strategies / fire-on policies extend `specialized-cells.rkt` with new convenience constructors. The cell-meta struct + dispatch stay in `propagator.rkt`.

**Cell-meta data**:
```racket
(struct cell-meta
  (tier              ;; 'hot | 'warm | 'cold
   storage           ;; 'monotone-counter | 'general | 'sparse | ...
   fires-on          ;; 'any-change | 'threshold-crossing | 'monotonic-progress | ...
   on-write-check    ;; (lambda (new-value net) -> boolean) | #f
   on-read-check)    ;; (lambda (read-value net) -> boolean) | #f
  #:transparent)
```

**Registration API**:
```racket
;; net-register-specialized-cell — register a cell with framework metadata
;;
;; Allocates a new cell, attaches cell-meta, returns (values net cell-id).
;; Under no-speculation: cell value is stored directly (per :storage strategy)
;;   - 'monotone-counter: unboxed fixnum in a specialized storage map
;;   - 'general: existing tagged-cell-value representation
;;   - 'sparse: hash-based; only stores non-bot values
;; The dispatch happens in net-cell-write/read (see §9.2.B).
(define (net-register-specialized-cell net
          #:domain domain-name
          #:initial-value init-value
          #:tier tier
          #:storage storage
          #:fires-on fires-on
          #:on-write-check [on-write-check #f]
          #:on-read-check [on-read-check #f])
  ...)
```

### §9.2.B Cell mechanism dispatch extension (D.4 CANONICAL)

Modifies `net-cell-write` (and `net-cell-read`) in `propagator.rkt` to dispatch on `cell-meta`. Under the FAST PATH (hot + monotone-counter + no-speculation):

```racket
(define (net-cell-write net cell-id new-value)
  (define meta (cell-meta-for net cell-id))
  (cond
    ;; FAST PATH: hot + monotone-counter + no-speculation
    [(and meta
          (eq? (cell-meta-tier meta) 'hot)
          (eq? (cell-meta-storage meta) 'monotone-counter)
          (not (under-speculation? net)))
     (define current (specialized-counter-cell-ref net cell-id))
     (define merged (tropical-fuel-merge current new-value))
     (define on-write (cell-meta-on-write-check meta))
     (cond
       ;; On-write predicate fires (e.g., threshold crossing)
       [(and on-write (on-write merged net))
        ;; Write contradiction structurally (no separate propagator)
        (net-contradiction net (cell-meta-contradiction-kind meta))]
       [else
        (define net' (specialized-counter-cell-set! net cell-id merged))
        ;; Fire-on policy: only notify dependents on threshold crossing
        (cond
          [(and (eq? (cell-meta-fires-on meta) 'threshold-crossing)
                (not (threshold-crossed? current merged on-write net)))
           net']  ; no propagator-fire ceremony; most writes bypass worklist
          [else (notify-dependents net' cell-id)])])]

    ;; SLOW PATH: speculation OR non-specialized cell
    [else
     (existing-net-cell-write net cell-id new-value)]))
```

The dispatch overhead (cell-meta lookup + tier/storage/speculation check) is ~5-10 ns per call; the fast path itself (direct mutation + inline check) is ~2-3 ns per call. Per §13.6 spike: W1+ (with dispatch) measured 6.4 ns/call — well within ≤ 30 ns target. The framework is feasible.

### §9.2.C Fuel-cost cell registration via the framework (D.4 CANONICAL)

In `tropical-fuel.rkt` (or alongside in `make-prop-network`), the canonical fuel-cost cell registers as:

```racket
(define-values (net1 fuel-cost-cid)
  (net-register-specialized-cell net0
    #:domain 'tropical-fuel
    #:initial-value 0
    #:tier 'hot
    #:storage 'monotone-counter
    #:fires-on 'threshold-crossing
    #:on-write-check
      (lambda (new-cost net)
        (>= new-cost (net-cell-read net fuel-budget-cell-id)))))

(define-values (net2 budget-cid)
  (net-register-specialized-cell net1
    #:domain 'tropical-fuel-budget
    #:initial-value initial-budget
    #:tier 'cold              ; written once at allocation; rarely-read otherwise
    #:storage 'general
    #:fires-on 'any-change))
```

No threshold propagator install — the on-write predicate replaces the propagator structurally (per §10.A retired observation: the propagator-as-decoration concern from D.2.SC M1 is structurally avoided under D.4 because the check is at the cell layer, not a separate firing entity).

### §9.3 Algebraic foundations (refined from research §9-§10)

**Tropical quantale `T_min = ([0, +∞], ≤_rev, +, 0)`** in Lawvere convention:
- Carrier: non-negative extended reals `[0, +∞]`
- Order: `a ≤_rev b ⟺ a ≥ b` (smaller cost is "higher" — Lawvere)
- Join (⊕): `min` (idempotent — cost-minimization)
- Meet (⋀): `max`
- Tensor (⊗): `+` (cost composition)
- Unit (1 = ⊤_rev): `0` (zero-cost operation)
- Bot (⊥_rev): `+∞` (infinite cost — exhausted)

**Quantale axioms verified** (per research §9.2):
- ✅ Complete lattice
- ✅ Commutative + Unital + Integral monoid
- ✅ Distributivity over arbitrary joins/meets
- ✅ Residuation: `a \ b = b - a when b ≥ a, else 0` (research §9.3)

### §9.4 SRE domain registration (refined from D.3 §10.1)

```racket
(define tropical-fuel-sre-domain
  (make-sre-domain
    #:name 'tropical-fuel
    #:merge-registry tropical-fuel-merge-registry
    #:contradicts? (λ (v) (= v +inf.0))
    #:bot? (λ (v) (= v 0))
    #:bot-value 0
    #:top-value +inf.0
    #:classification 'value      ;; atomic extended-real
    #:declared-properties
      (hasheq 'equality
              (hasheq 'commutative-join     prop-confirmed
                      'associative-join     prop-confirmed
                      'idempotent-join      prop-confirmed
                      'has-meet             prop-confirmed
                      'distributive         prop-confirmed
                      ;; QUANTALE properties
                      'quantale             prop-confirmed
                      'commutative-quantale prop-confirmed
                      'unital-quantale      prop-confirmed
                      'integral-quantale    prop-confirmed
                      'residuated           prop-confirmed
                      'has-pseudo-complement prop-confirmed))
    #:operations
      (hasheq 'tensor   (hasheq 'fn tropical-fuel-tensor
                                'properties '(distributes-over-join
                                              associative
                                              has-identity
                                              commutative))
              'residual (hasheq 'fn tropical-left-residual
                                'properties '(adjoint-to-tensor)))))

(register-domain! tropical-fuel-sre-domain)
(register-merge-fn!/lattice tropical-fuel-merge #:for-domain 'tropical-fuel)
```

**Property inference** (per Phase 2 of PPN 4C tradition): runs explicitly at registration to verify quantale laws (commutativity, associativity, idempotence, distributivity, residuation laws). Per Track 3 §12 + SRE 2G precedent, expect ≥1 lattice-law verification finding (possibly 0 since quantale axioms are well-grounded).

**D.3 S5 strengthening — C-series quantale axiom verification at Phase 1B close (ACKNOWLEDGE)**:

Phase 1B implementation **MUST run C-series** ([Pre-0 plan §5](2026-04-26_TROPICAL_ADDENDUM_PRE0_PLAN.md)) post-registration to verify quantale axioms hold for the actual `+` / `min` / `+inf.0` representation. **Particular attention to edge cases at `+inf.0`**:

- **Distributivity at infinity**: does `(+ +inf.0 (min b c)) = (min (+ +inf.0 b) (+ +inf.0 c))` hold? Both sides should equal `+inf.0` by absorbing-element semantics, but verify via assertion (Racket's `+inf.0` arithmetic is well-defined per IEEE 754; the assertion is for our semantics, not for IEEE).
- **Residuation at infinity**: `(tropical-left-residual +inf.0 b)` for finite `b` → 0 (overspend; vacuous); `(tropical-left-residual a +inf.0)` for finite `a` → `+inf.0` (infinite remaining).
- **Tensor identity at infinity**: `(+ +inf.0 0) = +inf.0` (absorbing × identity).
- **Min identity at zero**: `(min 0 a) = a` for `a >= 0` (zero is bot in Lawvere convention).

**Precedent for axiom-level surfacings**: SRE Track 2H's property inference DID find lattice-law disproofs (F7 distributivity disproof per `mempalace.md` watching list; Track 2H PIR §7). Tropical quantale's distributivity may have similar edge cases at `+inf.0`. **C-series failure → critical correctness bug; halt before Phase 1C** (per Pre-0 plan §13 "Decision rules summary table" C1-C5 row).

### §9.5 Primitive API (D.4 CANONICAL — threshold propagator factory RETIRED)

> **D.4 status**: `make-tropical-fuel-threshold-propagator` factory from D.3 is RETIRED under D.4 canonical. The threshold check is now an `:on-write-check` predicate at the cell layer (per §9.2.B + §9.2.C). The factory was scaffolding for the D.3 hybrid architecture's separate-propagator pattern; under D.4 the predicate runs INLINE at cell-write, eliminating the propagator-as-decoration concern (D.2.SC M1 resolution retires structurally).

```racket
;; Residuation operator (read-time pure function — Q-1B-4 lean; UNCHANGED from D.3)
(define (tropical-left-residual a b)
  (if (>= b a) (- b a) 0))  ;; b - a when b >= a, else top (0 in Lawvere)

;; Tropical tensor (cost composition — UNCHANGED from D.3)
(define (tropical-fuel-tensor a b)
  (+ a b))  ;; (+inf.0 + a) = +inf.0 by IEEE 754 absorbing-element

;; Tropical merge (idempotent min — UNCHANGED from D.3)
(define (tropical-fuel-merge a b)
  (min a b))

;; D.4: cell registration via the §9.2.A framework
;; (replaces D.3's net-new-tropical-fuel-cell + net-new-tropical-budget-cell +
;;  make-tropical-fuel-threshold-propagator triple)
;; See §9.2.C for the canonical fuel-cost + fuel-budget cell registration pattern.
```

> **D.3 (historical) Primitive API** — preserved for traceability with the threshold-propagator pattern that was retired under D.4:
> ```racket
> ;; D.3 (RETIRED-PER-D.4-CANONICAL):
> ;; Threshold propagator factory replaced by :on-write-check predicate at cell layer
> (define (make-tropical-fuel-threshold-propagator fuel-cid budget-cid)
>   (λ (net)
>     (define cost (net-cell-read net fuel-cid))
>     (define budget (net-cell-read net budget-cid))
>     (if (>= cost budget)
>         (net-contradiction net 'tropical-fuel-exhausted)
>         net)))
> ```

### §9.6 Tests (refined from D.3 §7.7)

`tests/test-tropical-fuel.rkt` (NEW):

**Merge semantics** (5+ tests):
- `(tropical-fuel-merge 0 0) = 0` (bot identity)
- `(tropical-fuel-merge +inf.0 0) = 0` (top absorbing for ≤_rev)
- `(tropical-fuel-merge 5 3) = 3` (min)
- `(tropical-fuel-merge 5 +inf.0) = 5`
- `(tropical-fuel-contradiction? +inf.0) = #t`

**Cell allocation** (3+ tests):
- `net-new-tropical-fuel-cell` produces cell with initial value 0
- `net-new-tropical-budget-cell` with budget 1000 produces cell with initial 1000
- Multiple consumers: each gets independent cell

**On-write check (cell-layer predicate; D.4)** (4+ tests; REPLACES "Threshold propagator firing" under D.3):
- Cost < budget: cell-write succeeds; no contradiction; no propagator notification
- Cost = budget: cell-write triggers on-write check; contradiction written
- Cost > budget: cell-write triggers on-write check; contradiction written
- Fire-on-threshold-crossing semantics: dependent propagators notified ONLY on crossing (not per-write)
- Per-consumer independence: two specialized cells on different (cell-id, budget) pairs don't cross-contaminate

**Tensor operation** (3+ tests):
- `(tropical-fuel-tensor 3 5) = 8` (cost composition)
- `(tropical-fuel-tensor 0 5) = 5` (identity)
- `(tropical-fuel-tensor +inf.0 5) = +inf.0` (absorbing)

**Residuation operator (Form A per §6.5)** (5+ tests):
- `(tropical-left-residual 0 0) = 0` (identity)
- `(tropical-left-residual 5 10) = 5` (b - a when b >= a)
- `(tropical-left-residual 10 5) = 0` (overspend → top)
- `(tropical-left-residual 5 +inf.0) = +inf.0` (infinite remaining)
- Algebra: `(tropical-fuel-tensor a (tropical-left-residual a b)) <=_rev b` (adjunction law verification)

**SRE domain registration** (2+ tests):
- `(lookup-domain 'tropical-fuel)` returns the registered domain
- Property inference confirms declared properties (quantale, residuated, etc.)

**Specialized cell framework — `tests/test-specialized-cells.rkt` (NEW under D.4)** (8+ tests):
- *Cell-meta registration*: `net-register-specialized-cell` with `:tier 'hot` + `:storage 'monotone-counter` + `:fires-on 'threshold-crossing` + `:on-write-check` returns cell-id; cell-meta accessible via internal API
- *Fast-path dispatch*: under no-speculation, `net-cell-write` on a hot+monotone-counter cell takes the fast path (direct mutation; no `tagged-cell-value` wrapping); verify by inspecting allocation profile + measuring cell-write cost (~6-10 ns in production)
- *Speculation fallback*: under speculation, `net-cell-write` on the same cell falls through to generic cell-write with `tagged-cell-value` worldview tagging; verify correctness for cost-tracking across multiple worldviews
- *On-write check semantics*: predicate fires inline at cell-write; when predicate returns truthy, contradiction is written structurally
- *Fire-on-threshold-crossing*: dependent propagators notified ONLY when crossing detected (not per-write); verify by installing a downstream propagator + counting fires
- *Cross-tier interaction*: hot cell writes don't interfere with warm/cold cells in the same network; tier dispatch is per-cell
- *Cell-id allocation*: specialized cells get cell-ids in the same pool as generic cells; no conflict at the registration API level
- *Cell-meta query*: internal API can recover cell-meta from cell-id post-registration (useful for debugging + Phase 3C consumer code)

**Specialized fuel-cost cell (integration; D.4)** (4+ tests):
- *Registration*: `make-prop-network` allocates fuel-cost (cell-id 11) + fuel-budget (cell-id 12) via `net-register-specialized-cell`; verify both cell-ids + initial values
- *Per-decrement write*: `(net-cell-write net fuel-cost-cell-id (+ current 1))` mutates directly (no allocation); verify W3-equivalent zero-GC at 10k decrements
- *Exhaustion semantics*: writing a value `>= budget` triggers on-write predicate; `(net-contradiction? net 'tropical-fuel-exhausted)` returns `#t` after the write; per-decrement loop terminates correctly
- *Speculation*: under `with-speculative-rollback`, fuel-cost cell uses tagged-cell-value fallback; rollback restores pre-speculation cost correctly

### §9.7 Phase 3C anticipated use cases (Form B per §6.5)

Enumerated for forward-capture; cross-referenced in Phase 9 Addendum design Phase 3 section:

**UC1 — Fuel exhaustion blame attribution** (per research §10.3):
When tropical fuel cell reaches `+∞` (contradiction), Phase 3C deploys a propagator that:
1. Watches the contradicted fuel cell
2. Walks the propagator dependency graph backward from the cell
3. Sums per-step costs along the chain (using `tropical-left-residual`)
4. Identifies which propagators consumed budget → blame attribution
5. Emits derivation chain (per D.3 Phase 11b srcloc infrastructure)

**UC2 — Cost-bounded elaboration via Galois bridge** (per research §10.4):
Future Phase 3C consumer + future OE Series Track 1:
1. Allocate tropical fuel cell per type cell
2. α: type → cost mapping via type-cost-bridge (§4.2)
3. γ: budget → "elaborable types within budget" via reverse direction
4. `tropical-left-residual` computes "remaining budget after current cost"

**UC3 — Per-branch cost tracking in union-type ATMS** (per D.3 §6.10 + Phase 3A):
1. Per-branch tropical fuel cell allocated per union component
2. Threshold propagator per branch
3. Branch-local residuation walks per-branch dependency chain on contradiction
4. Aggregate cost reporting via tropical-fuel-tensor across branches

These three use cases ground the Form B anticipated-use enumeration. Phase 3C's design picks up the cross-reference and implements UC1/UC2/UC3 as proof-of-concept (Form C deferred to right phase).

### §9.8 Drift risks (D.4 CANONICAL)

- **D-1B-1**: Quantale property declarations may not all be load-bearing — verify via Phase 3C anticipated use cases (forward-capture per §9.7)
- **D-1B-2**: Residuation operator as read-time function may need to be wrapped in propagator by some consumer — leave operator as pure function; consumers wrap if needed (per Q-1B-4 lean)
- **D-1B-3**: `+inf.0` Racket float-infinity vs sentinel symbol (Q-1B-2) — see §9.9
- **D-1B-4**: API naming (Q-1B-1) — see §9.9
- **D-1B-5**: Multi-quantale composition NTT (§4) is design-only in this addendum; implementation deferred to Phase 3C consumer + future PReduce
- **D-1B-6 (D.4 NEW)**: Specialized cell framework dispatch overhead in production — per §13.6 spike, the mock with vector-ref cell-meta lookup measured 6.4 ns/call (W1+). Production implementation may have additional overhead (cell-meta lookup via hash-ref instead of vector-ref; integration with prop-network struct layout). Mitigation: Phase 1B close re-microbenches `net-cell-write` against §13.6 spike numbers; if regression > 50%, investigate cell-meta storage strategy (struct field vs hash vs vector)
- **D-1B-7 (D.4 NEW)**: `:on-write-check` predicate allocation under repeated invocation — predicate closure capture must be 0-allocation under fixnum comparison; verify with `bench-mem` on the registered fuel-cost cell. Mitigation: predicate written as a top-level `define`, not a closure capturing budget; budget read inside predicate via `net-cell-read` (cell-id is constant)
- **D-1B-8 (D.4 NEW)**: Cell-meta storage representation — open design choice (hash-keyed by cell-id, vector-indexed, struct field on prop-net-warm). Mitigation: decide at 1B mini-design with code in hand; default to vector-indexed for fast-path performance (per §13.6 spike); Phase 3A may revisit if multi-worldview meta requires hash representation

### §9.9 Open questions + Phase 1B mini-design resolutions (D.4 CANONICAL; Phase 1B mini-design 2026-05-15)

**Mini-design conversation 2026-05-15** (between mini-design + Option 13 + §13.6.A spike + audit-correction) resolved most architectural questions. Implementation-detail questions remain deferred to per-phase mini-design+audit with code in hand. Status: ✅ RESOLVED / 🔄 DEFER-TO-CODE / 🚫 RETIRED.

**Implementation-detail questions (defer to 1B-i / 1C-i mini-design with code)**:

- **Q-1B-1** 🔄: API naming. Lean: `tropical-fuel-merge`, `tropical-fuel-tensor`, `tropical-left-residual`. Alternative: `min-merge`, `quantale-join`, etc. Decide at 1B mini-design with code in hand.
- **Q-1B-2** 🔄: `+inf.0` (Racket float-infinity) vs sentinel `'tropical-top`. Lean: `+inf.0` — Racket-native; arithmetic well-defined (`+inf.0 + a = +inf.0`); easier interop. Decide at 1B mini-design.
- **Q-1B-4** 🔄: Residuation operator as read-time helper vs propagator. Lean: read-time helper (per §9.5 + §6.5). Decide at 1B mini-design with Phase 3C UC1/UC2/UC3 anticipated use cases in hand.

**Spike-validated questions**:

- **Q-1B-6** 🚫 (RETIRED under D.4): Hybrid pivot empirical-validation spike. **EXECUTED 2026-05-14** (commit `7b681b9e`). Results: ✓ PASS — D.4 canonical. Specialized cell-write fast-path 6.4 ns/call (with realistic dispatch); zero major-GC at 100k decrements (structural). The hybrid pivot's empirical motivation (R-19 extrapolation) is falsified for the specialized cell type framework. See §13.6 for spike plan + results.

**Architectural questions resolved in Phase 1B mini-design 2026-05-15**:

- **Q-1B-8 (resolved A2)** ✅: Cell-meta storage representation. Under Option 13's deferred-write, cell-meta dispatch fires only at scheduler boundaries (Variant A: once per BSP round; Variant B: once per phase entry+exit), not per fire. Performance pressure that initially favored vector-indexed dispatch has dissolved. **Resolution: A2 — meta field on `prop-cell` struct itself**. Cell knows its own meta; one extra word per cell (~8 bytes); no separate CHAMP lookup; one accessor at boundary. A1 (parallel CHAMP on prop-net-cold) is viable too but adds dispatch indirection that A2 avoids. Cleanliness wins under the relaxed perf pressure.

- **Q-1B-9 (resolved F2)** ✅: Predicate API for `:on-write-check`. Under Option 13 (and Phase 3C forward-compat), passing `(current, new-value, net)` lets the predicate distinguish "threshold crossed this write" from "threshold already crossed in a prior write." For monotone counter the distinction doesn't matter, but forward-compatibility for future Phase 3C consumers (which may want "transition" semantics) is cheap. **Resolution: F2 — predicate signature `(current, new-value, net) -> boolean`**.

- **Q-1B-10 (NEW; resolved B1-prime)** ✅: Module organization. Under Option 13 the framework's dispatch site is in `propagator.rkt`'s `net-cell-write` (the natural home for cell mechanism). The Option 13 BSP-deferred-write logic lives in BSP scheduler code (Variant A at line 2384's equivalent; Variant B in sequential phase functions). **Resolution: B1-prime — cell-meta struct + registration API + dispatch in `propagator.rkt`; a thin `specialized-cells.rkt` provides convenience constructors (e.g., `make-monotone-counter-meta`) but isn't load-bearing; BSP deferred-write helpers (the local-var boilerplate for Variant B) live in BSP scheduler code OR a `bsp-helpers.rkt` if reused**. Avoids the circular-import dance from earlier framing.

- **Q-1B-11 (NEW; resolved D1)** ✅: Storage strategy enum scope. **Resolution: D1 — ship `'general` (default) + `'monotone-counter`**. Other strategies (`'sparse`, `'specialized-vector`, etc.) added when future PReduce/OE consumers need them. Aligns with "Let pain drive design" (DEVELOPMENT_LESSONS.org).

- **Q-1B-12 (NEW; resolved E1)** ✅: Fire-on policy enum scope. **Resolution: E1 — ship `'any-change` (default) + `'threshold-crossing`**. Other policies (`'monotonic-progress`, `'change-magnitude`) added when future consumers need them.

- **Q-1B-13 (NEW; resolved G1)** ✅: On-write predicate timing — runs BEFORE merge or AFTER. **Resolution: G1 — predicate runs AFTER merge**. For monotone counter (fuel-cost), merge is `min` (idempotent) so post-merge value is the live state; predicate sees the actual cell-state-after-write. Matches §9.2.B sketch + §13.6.A spike pattern.

- **Q-1B-14 (NEW; resolved at §10.3.A)** ✅: Local-var location for Variant B. **Resolution: L1 — let-scoped `box`, ephemeral per scheduler-phase invocation**. Each phase reads cell at entry, writes cell at exit. Avoids "what's the source of truth between phases" question.

**Deferred-but-named questions** (under Option 13 + audit-corrected scheduler matrix):

- **Q-1C-K** 🔄 → defer-to-1C-i mini-audit per §10.7 — local-var flush timing enumeration.
- **Q-1C-L** ✅ → resolved L1 per Q-1B-14.
- **Q-1C-M** ✅ → RESOLVED IN-SCOPE per §10.7 (parallel BSP composition via main-thread serialization).
- **Q-1C-N** 🔄 → forward-capture per §13.7 (other scheduler-state cells using deferred-write pattern).

> **Phase 1B mini-design status**: 8 questions resolved (Q-1B-8/9/10/11/12/13/14 + Q-1B-6 retired); 3 deferred to code (Q-1B-1/2/4). Phase 1B is ready to enter Stage 4 implementation with the architectural decisions locked in.

### §9.10 Post-Phase-1B benchmark capture — forward-pointer for Pre-0 deferred items (NEW 2026-04-26)

Per **capture-gap discipline** (DEVELOPMENT_LESSONS.org, codified 2026-04-25; "every 'future phase X handles Y' claim requires capture verification or explicit capture creation at the time of the claim"). Pre-0 plan §3-§4 has 3 items labeled "N/A pre-impl, deferred to post-Phase-1B" — captured here at the right phase so the work isn't dropped when Phase 1B implementation opens.

Phase 1B's deliverables include `bench-tropical-fuel.rkt` (NEW; per Pre-0 plan §11.1 file table) which is the home for these post-impl benchmarks. The Form A unit tests (§9.6) cover **correctness** of the residuation operator + tensor + boundary cases; the deferred Pre-0 micros below cover **performance characterization**.

**M10 — Residuation operator (read-time pure function) cost**:
- Per Pre-0 plan §3 M10: pure function call cost on `(tropical-left-residual a b)` for various (a, b) value combinations
- Implementation site: `bench-tropical-fuel.rkt` micro section
- HYP: ~10-30 ns/call for fixnum cases; ~50-100 ns/call for `+inf.0` cases (per Pre-0 plan §3 M10 hypothesis)
- DR: if wall > 100 ns → optimize residuation operator (open-coded comparison)
- Boundary cases (per Pre-0 plan §3 M10): simple `(tropical-left-residual 5 10)`, boundary `(tropical-left-residual 0 0)`, infinite cases, pathological extreme values
- Decision input for Q-1B-4: read-time helper has near-zero overhead → consumers wrap in propagator only when needed

**M12 — SRE domain registration overhead**:
- Per Pre-0 plan §3 M12: one-time module-load cost for `register-domain! tropical-fuel-sre-domain`
- Implementation site: `bench-tropical-fuel.rkt` micro section
- HYP: < 1 ms (one-time at module load); < 10 KB per domain (struct + property declarations + merge-fn entries)
- DR: if significantly higher → investigate property inference triggering at registration vs lazy
- Sub-tests: one-time registration cost; idempotency check (repeat registration is no-op vs re-runs property inference)

**A12 — Edge-case algebra (residuation at boundaries)**:
- Per Pre-0 plan §4 A12: assertion-based correctness for 6 boundary cases + algebraic adjunction law
- Implementation site: `tests/test-tropical-fuel.rkt` (covered by Form A unit tests per §9.6 above)
- The 6 cases (a=b, a=0, b=+inf, a=+inf, a>b overspend, both 0 identity) are the boundary semantics for `(tropical-left-residual a b)`
- Cross-reference: A12 boundary cases are **the same cases** as §9.6 Form A unit tests — A12 was named in Pre-0 plan as adversarial-tier coverage but is realized via Form A unit tests
- Methodology: assertion-based correctness (rackunit `check-equal?`); wall-clock secondary (timing covered by M10)
- DR: if any boundary case produces wrong result → bug in `tropical-left-residual` implementation OR reconsider `+inf.0` representation choice (Q-1B-2)

**R4 — Memory cost of compound cell value vs flat tagged-cell-value**:
- Per Pre-0 plan §8 R4: cell value layout impact on memory
- Implementation site: `bench-tropical-fuel.rkt` micro section (R-series companion to M9 cell allocation cost)
- Tropical fuel cell IS atomic value (`'value` classification per D.1 §9.4 SRE registration); should NOT need compound layout
- HYP: per-cell base ~150-300 bytes; per-additional-worldview-tag ~50-100 bytes
- DR: if base > 1 KB → investigate cell layout; if per-worldview marginal > 200 bytes → investigate tag-entry overhead
- Sub-tests:
  - Atomic tropical fuel cell allocation (control)
  - Compare to hypothetical flat tagged-cell-value with single worldview tag
  - Compare to hypothetical compound cell with multiple worldview tags (when speculation creates branches)
- Validates D.1 §9.4 `'value` classification choice — if compound layout has comparable cost to atomic, validates the architectural decision; if compound is significantly heavier, validates keeping atomic for tropical fuel

**Phase 1B implementation checklist** (capture-gap closure):
- [ ] M10 added to `bench-tropical-fuel.rkt` (residuation operator timing measurement)
- [ ] M12 added to `bench-tropical-fuel.rkt` (SRE registration cost measurement)
- [ ] R4 added to `bench-tropical-fuel.rkt` (compound vs flat cell value layout measurement)
- [ ] A12 boundary cases verified in `tests/test-tropical-fuel.rkt` (per §9.6 Form A enumeration)
- [ ] Cross-reference verification: §9.6 Form A test list matches Pre-0 plan §4 A12 boundary cases enumeration
- [ ] Update Pre-0 plan §12.5 M10/M12/R4/A12 rows with measured baseline data post-Phase-1B
- [ ] Document any findings in Pre-0 plan §12.6 from M10/M12/R4/A12 measurements

**Why this capture is critical**: without explicit cross-reference back to D.1 §9, the Phase 1B implementer might:
- Look at D.1 §9.6 → see Form A unit tests → implement them in `test-tropical-fuel.rkt`
- Look at Pre-0 plan §4 A12 → see "deferred post-Phase-1B" → potentially DUPLICATE in `bench-tropical-fuel.rkt` thinking they're separate
- OR miss M10 / M12 entirely (no Form A counterpart in §9.6)

This subsection is the SINGLE SOURCE OF TRUTH for "what post-Phase-1B benchmarks are owed" — the implementer reads this checklist + §9.6 + Pre-0 plan §11.1 together. The capture lives at Phase 1B (the right phase per capture-gap discipline) with explicit cross-references back to Pre-0 plan items.

---

## §10 Phase 1C — Canonical BSP fuel substrate (D.4 CANONICAL — direct migration)

> **D.4 CANONICAL status (2026-05-14)**: §13.6 Pre-0 spike PASSED (commit `7b681b9e`); D.4 architecture is canonical. The specialized cell type framework (§4.6) provides a fast-path with 6.4 ns/call (with realistic dispatch overhead) — well within the ≤ 30 ns target — and structurally guaranteed zero major-GC pressure. The hybrid pivot from D.3 has been retired before shipping; D.3 historical content preserved below with RETIRED-PER-D.4-CANONICAL annotations.

### §10.1 Scope and rationale (D.4)

**Phase 1C is the direct migration phase**: replaces the imperative `(fuel 1000000)` decrementing counter pattern with on-network fuel-cost-cell semantics via the specialized cell type framework (§4.6). The cell IS the live state. The struct-field `prop-net-hot-fuel` and macro `prop-network-fuel` RETIRE per D.1 §10.3 original framing.

**Architectural commitments** (validated by §13.6 spike):
- **The cell IS the live state** — no off-network struct-field carve-out; no staleness contract
- **Per-decrement cell-write is GC-friendly** — direct fixnum mutation under no-speculation allocates zero bytes
- **The threshold propagator is replaced by `:on-write-check`** — cell-layer predicate runs inline during write; no propagator-fire ceremony for the rare exhaustion event (or no ceremony at all for the common-case fast path)
- **Fire-on-threshold-crossing** — dependent propagators (Phase 3C consumers) only notified when cost crosses budget; most writes don't enter the worklist
- **CALM-safe + scheduler-portable** — per Cell/Propagator/Scheduler Orthogonality, the optimization is at the cell layer; Gauss-Seidel, BSP, Zig-LLVM, future schedulers all run the network identically

**Empirical foundation** (validated; not extrapolated):
| Measurement | §13.6 spike result | Pre-0 baseline | Target | Margin |
|---|---|---|---|---|
| Specialized cell-write fast-path (W1+) | 6.4 ns/call | M7 = 24 ns/call | ≤ 30 ns | ~4× under |
| GC profile at 100k decrements (W3) | 0.000 ms / 0.0% | R3 = 0.00 ms / 0.0% | ZERO major-GC | structural |
| Allocation at 10×100k decrements | 1.1 KB | A7.3 = 6251 KB | (reference) | **5700× memory improvement** |
| Per-decrement cycle (W1+ + W4) | 7.3 ns | M7 + M13 = 30 ns | ≤ 45 ns | ~6× under |

The D.3 hybrid pivot's empirical motivation (R-19 extrapolation: "full cell-migration would trigger major GC") is **falsified for the specialized cell type framework**. Direct fixnum mutation on a mutable struct field allocates zero per write; the zero-GC result is structurally guaranteed.

### §10.2 Audit-grounded substrate plan (Q-Audit-1 17-refs FULL migration)

Under D.4 canonical, ALL 17 production refs from Q-Audit-1 migrate to cell-API:

**Allocation in `make-prop-network`**:
```racket
(define (make-prop-network [fuel 1000000])
  ;; ... existing allocations (cell-ids 0-10) ...

  ;; Phase 1C — canonical tropical fuel cells via §4.6 specialized framework
  ;; The cell registration declares :tier 'hot + :storage 'monotone-counter
  ;; + :fires-on 'threshold-crossing + :on-write-check; cell mechanism dispatches.
  (define-values (net1 fuel-cost-cid)
    (net-register-specialized-cell net0
      #:domain 'tropical-fuel
      #:initial-value 0
      #:tier 'hot
      #:storage 'monotone-counter
      #:fires-on 'threshold-crossing
      #:on-write-check (lambda (new-cost net)
                         (>= new-cost (net-cell-read net fuel-budget-cell-id)))))
  ;; (verify cell-id allocated as 11 — well-known position per §4.3)

  (define-values (net2 budget-cid)
    (net-register-specialized-cell net1
      #:domain 'tropical-fuel-budget
      #:initial-value fuel
      #:tier 'cold       ; written once at allocation; rarely-read otherwise
      #:storage 'general
      #:fires-on 'any-change))
  ;; (verify cell-id allocated as 12)

  ;; NO threshold propagator install — the on-write check is at the cell layer.
  ;; NO struct-field 'fuel' in prop-net-hot — cell IS the live state.
  ;; ...
)
```

**Export well-known cell-ids**: `fuel-cost-cell-id = 11`, `fuel-budget-cell-id = 12` per §4.3.

**Production scope under D.4 (FULL migration)**:
- **Decrement sites** (4): MIGRATE — replace `(struct-copy prop-net-hot ... [fuel (- ... n)])` with `(net-cell-write net fuel-cost-cell-id (+ (net-cell-read net fuel-cost-cell-id) n))` (or the equivalent specialized cell-API surface)
- **Check sites** (11): MIGRATE — replace `(<= (prop-network-fuel net) 0)` with `(net-contradiction? net 'tropical-fuel-exhausted)` (the on-write predicate writes contradiction when cost crosses budget; check sites just observe contradiction)
- **Read-as-value sites** (3): MIGRATE to `(net-cell-read net fuel-cost-cell-id)` (architecturally-consistent; no staleness concern under D.4)
- **Macro `prop-network-fuel`**: RETIRE (no struct-field accessor needed)
- **Struct field `prop-net-hot-fuel`**: RETIRE (no fuel field in prop-net-hot)
- **typing-propagators saved-fuel** (1): MIGRATE to cell-mediated semantics (cell snapshot via worldview-bitmask, NOT struct-copy)
- **pretty-print** (1): UPDATE to display cell value + budget
- **Test sites** (13): MIGRATE — replace `(prop-network-fuel result)` assertions with `(net-cell-read result fuel-cost-cell-id)` (mechanical batch via sed-style discipline per workflow.md)
- **Bench sites** (2): MIGRATE — `bench-alloc.rkt` now measures cell-write cost; this is the post-impl A/B baseline

**Total migration scope**: ~150-250 LoC across propagator.rkt + typing-propagators.rkt + pretty-print.rkt + 13 test files + 2 bench files (per D.1 §10.4 original framing).

### §10.3 Per-site patterns (D.4)

**Decrement sites** (4 sites — propagator.rkt:2384, 3000, 3053, +1 widening):

```racket
;; D.4: direct cell-API replaces struct-copy
;; The cell mechanism's :on-write-check writes contradiction if (>= new-cost budget);
;; otherwise the fast path mutates directly (no allocation, no propagator-fire).
(net-cell-write net fuel-cost-cell-id
                (+ (net-cell-read net fuel-cost-cell-id) n))
```

**Check sites** (11 sites — propagator.rkt:1817, 2366, 2373, 2329, 2992, 3045, 3132, 3135, 3142, 65, 399):

```racket
;; D.4: observe contradiction state; on-write check has already routed
;; exhaustion through the network if it happened.
[(net-contradiction? net 'tropical-fuel-exhausted) net]
```

The pattern is uniform: the on-write predicate handles the exhaustion semantics structurally; check sites observe the result. **No imperative dispatch** — the exhaustion decision emerges from cell state, not from per-decrement-site control flow.

**Read-as-value sites** (3 sites — propagator.rkt:1824, 1872, 2875):

```racket
;; D.4: direct cell-read
(define remaining-fuel
  (box (- (net-cell-read net fuel-budget-cell-id)
          (net-cell-read net fuel-cost-cell-id))))
```

**typing-propagators.rkt:2269** (saved-fuel rollback):

```racket
;; D.4: cell snapshot via worldview-bitmask (NOT struct-copy of fuel field)
;; The cell mechanism's speculation-fallback path uses tagged-cell-value;
;; rollback narrows worldview, restoring pre-speculation cell value.
;; No saved-fuel value capture — the network IS the snapshot.
;; (existing speculation rollback mechanism handles this uniformly)
```

**pretty-print.rkt:463** (display):

```racket
;; D.4
[(expr-prop-network v)
 (format "#<prop-network cost=~a budget=~a>"
         (net-cell-read v fuel-cost-cell-id)
         (net-cell-read v fuel-budget-cell-id))]
```

**Macro `prop-network-fuel` (propagator.rkt:399)** — RETIRE:

```racket
;; D.4: macro RETIRES; callers use (net-cell-read net fuel-cost-cell-id) or
;; (- (net-cell-read net fuel-budget-cell-id) (net-cell-read net fuel-cost-cell-id))
;; for remaining-fuel calculations.
```

**Struct field `prop-net-hot-fuel` (propagator.rkt prop-net-hot struct)** — RETIRE:

```racket
;; D.4: struct field RETIRES; prop-net-hot no longer has 'fuel' field.
;; Cell-id 11 (fuel-cost-cell) IS the live state.
```

**Test migrations** (13 sites — batch mechanical):

```racket
;; BEFORE (D.3 / pre-D.4)
(check-equal? (prop-network-fuel result) expected-fuel)

;; AFTER (D.4)
(check-equal? (- (net-cell-read result fuel-budget-cell-id)
                 (net-cell-read result fuel-cost-cell-id))
              expected-fuel)
```

Use 2-pass sed pattern per workflow.md "Sed-Deletion of Parameterize Bindings" discipline — verified on 1 file copy before batch.

**Bench migrations** (2 sites in `bench-alloc.rkt`):

```racket
;; BEFORE: struct-copy decrement cost
;; AFTER (D.4): specialized cell-write cost via net-cell-write
;;   The post-impl bench measures the actual production cost; compares to Pre-0 M7
;;   (24 ns struct-copy baseline) and the spike's W1+ (6.4 ns specialized).
```

### §10.3.A Option 13 — Scheduler-side deferred write at boundaries (D.4 REFINEMENT 2026-05-15, corrected 2026-05-15)

> **Origin**: surfaced during Phase 1B mini-design when a friend's question highlighted that D.4's per-fire `net-cell-write` pattern adds ~3-4 ns dispatch overhead vs a "native" gas tracker. The architectural lever the question makes visible: **D.4 assumed `net-cell-write` should be called per-fire**. That assumption is what produces the dispatch overhead. The orthogonality principle does NOT require per-fire writes — only that the cell's BEHAVIOR is scheduler-neutral. The scheduler is free to CHOOSE WHEN to call `net-cell-write` (per-fire OR batched) as long as the cell's observable semantics are preserved at the points where anything else can observe them.
>
> **Correction (2026-05-15 audit)**: the production scheduler is the PARALLEL BSP from PAR Track 2 R1-R2 (commit `driver.rkt:435` sets `current-parallel-executor` globally to `make-parallel-thread-fire-all`). The codebase has FIVE scheduler entry points, with different loop structures and therefore different deferred-write variants. The original §10.3.A pseudocode described only the SEQUENTIAL local-var pattern; the parallel BSP main loop uses a simpler round-entry batch decrement pattern. Both variants are valid implementations of "Option 13 deferred-write" — they share the architectural principle (scheduler writes cell at boundaries, not per-fire), with the boundary choice fitting the scheduler's loop structure.

**Scheduler entry points and their deferred-write variants** (audit 2026-05-15):

| # | Function (line) | Loop structure | Variant | Pattern |
|---|---|---|---|---|
| 1 | `run-to-quiescence-inner` (1835-1866) | Sequential Gauss-Seidel; box-mutation; per-fire | **Variant B (local-var)** | Local-var box + per-fire decrement + cell-write at phase end |
| 2 | `run-to-quiescence-inner/traced` (1870-1898) | Same + tracing | **Variant B (local-var)** | Same as #1 |
| 3 | `run-to-quiescence-bsp` (2315+) | **PARALLEL BSP** (production default); round-entry batch | **Variant A (round-entry-batch)** | Single `net-cell-write` at line 2384 equivalent; main thread sequential; workers don't touch fuel |
| 4 | `run-widen-phase` (2989+) | Sequential widening; per-fire | **Variant B (local-var)** | Same as #1 |
| 5 | `run-narrow-phase` (3042+) | Sequential narrowing; per-fire | **Variant B (local-var)** | Same as #1 |

**Variant A — Round-entry batch decrement (parallel BSP main loop; production default)**:

```racket
;; Inside the BSP outer loop (run-to-quiescence-bsp at line 2376+):
(define raw-pids (dedup-pids (prop-network-worklist net)))
(define pids (filter (lambda (pid) (not (hash-has-key? fired-set pid))) raw-pids))
(define n (length pids))

;; Round-entry batch decrement: ONE cell-write per BSP round, on main thread,
;; BEFORE parallel workers spin up. Workers see the post-decrement value in the
;; snapshot but don't write fuel.
(define new-fuel-cost (+ (net-cell-read net fuel-cost-cell-id) n))
(define snapshot
  (struct-copy prop-network net
    [hot (struct-copy prop-net-hot (prop-network-hot net)
           [worklist '()])]))
;; D.4: net-cell-write replaces the old [fuel (- ...)] field in struct-copy
(define snapshot+fuel
  (net-cell-write snapshot fuel-cost-cell-id new-fuel-cost))
;; The cell's on-write predicate runs here; if exhausted, contradiction is
;; written structurally and worker dispatch is short-circuited.

;; Workers fire pids against snapshot+fuel (sequentially per-thread; parallel
;; across threads). Workers don't touch fuel-cost cell during fire.
(define all-writes (executor snapshot+fuel pids))
;; ... bulk-merge proceeds as before
```

Cost: ~6 ns per BSP round (one cell-write); amortized over N=100 fires per round = **~0.06 ns/cycle**. The dominant per-fire cost is the propagator-fire itself, NOT the fuel update.

**Variant B — Local-var + cell-write at phase boundaries (sequential schedulers)**:

```racket
;; At sequential-phase entry (e.g., run-to-quiescence-inner, run-widen-phase):
(define local-fuel-cost (box (net-cell-read net fuel-cost-cell-id)))
(define budget (net-cell-read net fuel-budget-cell-id))

;; Per fire (inline, in the sequential loop body):
(define new-cost (+ (unbox local-fuel-cost) 1))
(set-box! local-fuel-cost new-cost)
(when (>= new-cost budget)
  ;; Flush + contradict (rare; on exhaustion only)
  (set! net (net-cell-write net fuel-cost-cell-id new-cost))
  ;; The on-write check at the cell layer routes contradiction structurally
  (return-from-sequential-phase net))

;; At sequential-phase exit (no exhaustion):
(set! net (net-cell-write net fuel-cost-cell-id (unbox local-fuel-cost)))
```

Cost: ~2.16 ns/cycle amortized (per §13.6.A spike); applies to sequential schedulers (#1, #2, #4, #5).

**Performance characterization (MEASURED — §13.6.A spike VALIDATED 2026-05-15)**:

| Component | Measured cost | Frequency | Source | Variant |
|---|---|---|---|---|
| Variant A: round-entry batch cell-write (one per BSP round) | **~6 ns/round** | Once per BSP round | §13.6.A W2b-O13 + ~3 ns dispatch | A |
| Variant A: amortized per fire at N=100 fires/round | **~0.06 ns/cycle** | Hot path under parallel BSP | Variant A formula | A |
| Variant B: per-fire local-var decrement + threshold check | **2.2 ns/call** | 100s-1000s per phase | §13.6.A W1-O13a | B |
| Variant B: amortized per-fire at N=100 fires/phase | **2.16 ns/cycle** | Hot path under sequential | §13.6.A W3-O13a.2 | B |
| Both: per-boundary cell-read | **1.3 ns/call** | Once per boundary | §13.6.A W2a-O13 | A + B |
| Both: per-boundary cell-write | **1.4 ns/call** | Once per boundary | §13.6.A W2b-O13 | A + B |
| Both: contradiction flush on exhaustion | **3.7 ns/call** | Once per workload typically | §13.6.A W4-O13 | A + B |

For the production parallel BSP main loop (Variant A), per-cycle cost amortizes to **~0.06 ns/cycle at N=100** — far below any per-fire overhead concern. For sequential schedulers (Variant B), per-cycle cost is **~2.16 ns/cycle** — still faster than current native struct-copy (5.2 ns) by 2.4×. Both variants beat the per-fire `net-cell-write` pattern (Option Y from D.4 original) which was 6.6 ns/cycle (§13.6 W1+).

**The original §10.3.A pseudocode applied only to sequential schedulers** (the local-var pattern). The parallel BSP main loop uses the simpler Variant A; this correction names both variants and the scheduler/variant mapping.

The Option 14 macro specialization saves only 0.02 ns/cycle (per §13.6.A W3-O13a vs W3-O13b); SKIP Option 14. The savings are within the same variant; cross-variant the architectural choice (A vs B per scheduler) dominates.

> **The spike falsified an assumption in the design**: §10.3.A originally estimated "approximating native gas tracker performance" suggesting Option 13 might just match native. The measurement shows Option 13 (Variant B) actually BEATS native struct-copy by 2.4× for sequential schedulers; Variant A is even faster for the parallel BSP main loop (amortized 0.06 ns/cycle vs 5.2 ns native = ~87× faster). The reason: current native uses nested struct-copy on `prop-network` + `prop-net-hot` (multiple allocator calls per cycle); Variants A + B avoid the struct-copy allocation entirely. The deferred-write pattern is structurally faster than the current native implementation.

**Why this is materially different from D.3 hybrid pivot (not a principle inversion)**:

| Aspect | D.3 hybrid | Option 13 deferred-write |
|---|---|---|
| Live state location | Struct-field (off-network) | Cell (on-network) — same as D.4 canonical |
| Per-fire decrement | `(struct-copy prop-net-hot ... [fuel ...])` | `(set-box! local-fuel-cost ...)` (scheduler-internal) |
| Cell update timing | "Semantic transitions" (vague; ambiguous to enumerate) | BSP round boundaries (well-defined; matches CALM's natural granularity) |
| Phase 3C reads | Possibly stale per Cell Staleness Contract | Always-current at round boundary (where Phase 3C consumers fire) |
| Principle alignment | Cell DERIVED, struct PRIMARY (INVERSION) | Cell PRIMARY, local-var SCRATCH (no inversion) |
| Cell visible to consumers | Yes, with staleness contract | Yes, at all observation points |

D.3 made the cell a **cache** of an off-network struct (read this; the struct is the truth). Option 13 makes the local-var a **scratch** of the cell (read the cell; the local-var is the scheduler's working register that flushes back). The cell IS canonical at every observation point; the local-var is invisible outside the BSP scheduler's fire loop.

**Why this preserves Cell/Propagator/Scheduler Orthogonality**:

The deferred-write is a SCHEDULER-LAYER optimization. The cell mechanism's behavior is unchanged: when `net-cell-write` is called (at round boundary or on exhaustion), it dispatches per §9.2.B; the on-write check runs; the value is written. The scheduler CHOOSES WHEN to invoke `net-cell-write` — this choice is the scheduler's own concern.

Other schedulers (Gauss-Seidel, Zig-LLVM, future) can choose their own strategies:
- Gauss-Seidel might call per-update (its natural granularity)
- Zig-LLVM might batch per-N-iterations (its loop structure)
- BSP uses round boundaries (this design)

The cell's contract is: "when written, the on-write check runs and may produce contradiction." How often `net-cell-write` is called is the scheduler's concern. **This is exactly the orthogonality principle's "scheduler optimizes WITHOUT coupling cell behavior" case** — fully aligned, not just permissively allowed.

**Why this confirms the "scheduler-state cell" category**:

Scheduler-state cells (cells the scheduler writes; not written by any fire function) permit deferred-write optimization that propagator-state cells (cells written by fire functions in parallel) cannot. Propagator-state cells have writes that must be individually consequential (they're outputs of computation). Scheduler-state cells are the scheduler's own bookkeeping; the scheduler can batch its own writes without breaking anyone else's observation.

This is a **clean architectural category** that the D.4 design implicitly assumed but didn't name. With Option 13 + the category, future schedulers (and scheduler-state cells beyond fuel-cost — e.g., worklist-cache, future BSP-round-counter cell, etc.) inherit the deferred-write pattern naturally.

**Trade-offs and complications**:

- **Snapshot/restore**: when speculation forks mid-phase (rare; usually at phase boundaries), Variant B local-var must flush first. Adds ~6 ns to fork operation. Variant A (parallel BSP main) naturally aligns with round boundaries; speculation forks at round boundaries see the post-decrement cell value. Speculation operations are rare relative to fires; net overhead is negligible.
- **Phase 3C consumer granularity**: round/phase-level not per-fire. For UC1 (blame attribution), round-level + dependency-graph traversal gives propagator-level attribution (acceptable). For UC2 (cost-bounded elaboration), round-level is natural (decision points are between rounds). For UC3 (per-branch cost): each branch's scheduler instance has its own boundary writes → cell updates at branch fork/join boundaries (correct semantics).
- **Mid-phase on-write check**: the on-write predicate currently runs at cell-write time. Under deferred-write, predicate runs at boundary cell-write (round entry for Variant A; phase entry+exit for Variant B; OR on-exhaustion mid-loop for both). For monotone counter (fuel-cost), this works correctly — the predicate sees the post-batch value (Variant A) or the post-phase value (Variant B); if it crosses threshold, contradiction fires. For non-monotone use cases (future), per-write semantics would still be required.
- **Parallel BSP (production default; PAR Track 2 R1-R2 closed)**: **RESOLVED IN-SCOPE** for Phase 1B/1C. The parallel BSP main loop (Variant A) does the cell-write on the MAIN THREAD at round entry (line 2384's equivalent), BEFORE workers spin up. Workers fire pids against the post-decrement snapshot without touching fuel-cost. No contention; no reduce-at-round-end needed. The parallel BSP architecture already serializes scheduler-state updates on the main thread; Phase 1C migration just changes the substrate (struct field → cell) without changing the concurrency pattern. This was incorrectly marked "deferred to Phase 2 PAR" before the 2026-05-15 audit; corrected here.
- **Future parallel scheduler variants** (Phase 2 PAR R3+): if a future PAR design eliminates the main-thread round-boundary serialization (e.g., per-worker fuel-counter shards with atomic reduction), THAT design choice would need to revisit fuel-cost cell semantics. Currently out of scope; the production parallel BSP keeps the main-thread serialization.
- **Cell-API call boundary**: the deferred-write pattern still calls `net-cell-write` — just less often. The cell mechanism's contract is unchanged. The scheduler CHOOSES the call frequency.

**Composability with macro-based specialization (Optional optimization Option 14)**:

We can go FURTHER: macro-expand the deferred-write pattern at the 4 BSP fire sites, eliminating function-call overhead entirely. Shaves another ~0.5-1 ns per cycle. Probably worth doing if Phase 1V close microbenches show the deferred-write pattern still has measurable overhead vs ideal native. Deferred to Phase 1C-iv mini-design with code in hand.

### §10.4 Sub-phase plan (6 sub-phases under D.4 — REFINED for Option 13)

- **1C-i** — Pre-implementation audit + mini-design:
  - Verify §9 framework implementation (Phase 1B) lands cleanly; cell registration API stable
  - ✅ **§13.6.A Option 13 spike executed** (commit `77daf81c`) — Variant B amortized 2.16 ns/cycle (sequential schedulers); Variant A amortized ~0.06 ns/cycle (parallel BSP); Option 14 SKIPPED
  - Re-verify §13.6 spike measurements at scale (probe + targeted-test runs)
  - Identify any cell-id 11/12 conflicts (per D-1C-3)
  - Confirm speculation-fallback semantics for monotone-counter cells (per D-1C-8)
  - **Audit all FIVE scheduler entry points** (per §10.3.A corrected; identify per-scheduler variant assignment):
    - #1 `run-to-quiescence-inner` (1835-1866): Variant B (sequential; box-mutation → local-var pattern)
    - #2 `run-to-quiescence-inner/traced` (1870-1898): Variant B (same as #1)
    - #3 `run-to-quiescence-bsp` line 2384: **Variant A** (parallel BSP; round-entry batch)
    - #4 `run-widen-phase` (2989+): Variant B (sequential; struct-copy → local-var pattern)
    - #5 `run-narrow-phase` (3042+): Variant B (sequential; struct-copy → local-var pattern)
  - **Per §13.7 measurement plan: capture A baseline (current implementation per-entry-point) microbench data for A/B/C comparison at 1C-vi close**

- **1C-ii** — Migrate 5 scheduler entry points to Option 13 deferred-write pattern (per-variant):
  - **Variant A migration (entry point #3, parallel BSP main loop)**: replace line 2384's `[fuel (- (prop-network-fuel net) n)]` in struct-copy with a `net-cell-write` of `(+ current n)` to fuel-cost-cell, BEFORE workers spin up. Main thread sequential; workers don't touch fuel-cost. Single cell-write per BSP round. Cost: ~6 ns/round (amortized ~0.06 ns/cycle at N=100).
  - **Variant B migration (entry points #1, #2, #4, #5, sequential schedulers)**: at phase entry, read fuel-cost cell into local-var box; per-fire decrement local-var + threshold check inline; at phase exit, flush local-var → cell-write. Cost: ~2.16 ns/cycle amortized.
  - On exhaustion (any variant; rare): flush + contradiction-write (via cell-mechanism on-write check).
  - Atomic commit per variant (Variant A as one commit; Variant B sites as one commit OR split per entry point if scope-warranted).
  - **Per §13.7**: re-microbench BOTH variants; verify Variant A achieves ~0.06 ns/cycle amortized + Variant B achieves ~2.16 ns/cycle amortized (matches §13.6.A spike targets).
  - Targeted tests: test-propagator + test-tropical-fuel + test-widen-narrow.

- **1C-iii** — Migrate 11 check sites:
  - Atomic commit; each site replaces `(<= (prop-network-fuel net) 0)` with `(net-contradiction? net 'tropical-fuel-exhausted)`
  - Most check sites are AFTER round boundary OR within BSP fire loop (where local-var is current); semantic equivalence preserved
  - Verify exhaustion semantics: representative workloads exhaust at correct points
  - **Per §13.7: re-microbench check-site cost; target unchanged ~6 ns**
  - Targeted test: full suite (these check sites are widely distributed)

- **1C-iv** — Retire macro + struct field + migrate read-as-value + typing-propagators + pretty-print:
  - Retire `prop-network-fuel` macro (propagator.rkt:399)
  - Retire `prop-net-hot-fuel` struct field (propagator.rkt prop-net-hot definition)
  - Migrate 3 read-as-value sites (these now read the cell directly; cell value is current at consumer-fire boundaries; Variant A's main BSP path has cell written at round entry, so reads-during-round see the post-decrement value)
  - Migrate typing-propagators.rkt:2269 saved-fuel handling — speculation forks at round/phase boundaries see the cell value naturally; for Variant B mid-phase forks, local-var flushes BEFORE fork (sub-fork starts with current cell value)
  - Update pretty-print display
  - Verify no orphan callers (grep verification)
  - ✅ **Option 14 (macro specialization) RESOLVED via §13.6.A spike (commit `77daf81c`): SKIP** — measured savings 0.02 ns/cycle, far below 1 ns threshold. Function-call pattern is sufficient.

- **1C-v** — Migrate 13 test sites + 2 bench sites:
  - Batch mechanical migration via 2-pass sed pattern per workflow.md (single-file verification before batch)
  - Tests' `(prop-network-fuel result)` assertions become `(- (net-cell-read result fuel-budget-cell-id) (net-cell-read result fuel-cost-cell-id))` for remaining-fuel, OR direct cell-read for cost-tracking
  - Full suite verification post-batch
  - Post-impl bench captures the D.4 numbers for A/B/C comparison vs Pre-0 baseline (per §13.7)

- **1C-vi** — Verification + close:
  - Probe + acceptance file + full suite
  - Tropical-fuel-counter-parity test (per §15): exhaustion semantics equivalent before/after at round-boundary observation points
  - **Per §13.7: full A/B/C comparison report**:
    - A = current struct-copy (baseline)
    - B = hypothetical per-fire `net-cell-write` (D.4 original; spike's W1+ measured but not implemented)
    - C = Option 13 deferred-write (this design; the actual production landing)
    - Confirm C ≤ A on per-cycle cost; confirm C matches §13.6.A spike's ~2 ns/cycle target
  - Performance verification: per-decrement cycle ≤ 5 ns amortized (Option 13 target; vs ≤ 45 ns per-fire which we no longer implement)
  - Re-microbench Phase 1V exit criteria (per §11.3; 11 microbenches refined for Option 13)

### §10.5 Drift risks (D.4)

Risks named at design time; verified at implementation:

- **D-1C-1**: Cell-id 11/12 conflicts — verify at 1C-i mini-audit no other phase has reserved these IDs (per §4.3)
- **D-1C-2**: typing-propagators.rkt:2269 saved-fuel rollback under tagged-cell-value semantics — verify worldview-bitmask rollback restores correct cost without explicit struct-copy save (Q-1C-1)
- **D-1C-3**: Performance regression at decrement sites — Pre-0 M7+M8+M13 + §13.6 spike numbers must be preserved; re-microbench at 1C-vi close (per microbench-claim verification rule)
- **D-1C-4**: Threshold-crossing semantics under speculation — the on-write check runs on the per-worldview cost; verify each speculation branch sees its own crossing event correctly (D-1C-8 expansion)
- **D-1C-5**: Speculation-fallback path overhead — under speculation, the fast-path falls through to generic cell-write with tagged-cell-value wrapping; per Pre-0 spike, this is ~500-1000 ns/call (reference only). For Phase 1C, the speculation case is RARE; amortized over typical workloads, no concern. Phase 3A measurement (per D.3.EC MG2) revisits if multi-worldview branching dominates.
- **D-1C-7** (D.4 NEW): specialized cell-write fast-path performance regression vs §13.6 spike — possible if cell-meta dispatch in production has higher overhead than the vector-ref mock. Mitigation: 1C-vi re-microbench; if regression, investigate via cell-meta lookup optimization (struct-field on prop-net-cold for cell-id 11/12 fast path; specialized cell registry separate from CHAMP)
- **D-1C-8** (D.4 NEW): speculation-fallback path semantics differ from monotone-counter expectations — possible if tagged-cell-value's worldview-narrow doesn't preserve the on-write predicate's threshold-check behavior. Mitigation: C-series quantale axiom verification (§9.4) under speculation; behavioral tests for cross-worldview cost semantics.
- **D-1C-9** (D.4 NEW): fire-on-threshold-crossing notification mechanism misses crossings — possible if multi-write batches happen within one BSP round and the crossing is detected for the wrong intermediate value. Mitigation: correctness behavioral tests; the predicate runs INLINE at each write, so single-write atomicity guarantees correct detection (multi-write batching would only happen within a single propagator's body, where the writes are sequenced).
- **D-1C-10** (D.4 NEW, 2026-05-15 audit): five scheduler entry points must be migrated with the CORRECT variant per scheduler. Risk: applying Variant B (local-var pattern) to entry point #3 (parallel BSP main) would introduce a per-fire local-var decrement that doesn't exist today — wasteful and incorrect. Applying Variant A (round-entry batch) to sequential schedulers (#1, #2, #4, #5) would require introducing a "round" concept that doesn't exist in their loop structures. Mitigation: 1C-i mini-audit enumerates each entry point + its variant assignment per §10.3.A's scheduler-pattern matrix; 1C-ii migration follows the matrix; 1C-vi verification re-microbenches per variant to confirm correct application.
- **D-1C-11** (D.4 NEW, 2026-05-15 audit): existing parallel BSP main loop's batch decrement at line 2384 must NOT be replaced with a per-fire pattern. Under D.4 Variant A, the single `[fuel (- ... n)]` field in the struct-copy becomes a `net-cell-write` BEFORE workers spin up. The decrement remains BATCH (by N), not per-fire. Mitigation: 1C-ii Variant A migration explicitly preserves the batch semantic; targeted test verifies workers don't write fuel-cost cell during parallel fire.

### §10.6 Termination + parity

- **Termination**: Phase 1C migration preserves Tarski-fixpoint termination (the cell merge is `min`, idempotent + monotone). The on-write predicate `(>= cost budget)` is a one-shot threshold check — the cell transitions from "below threshold" to "at/above threshold" exactly once per workload (monotone cost accumulation). Trivially terminates.

- **Parity** (per §15 — tropical-fuel-counter-parity axis):
  - For representative workloads, OLD counter and NEW cell produce IDENTICAL exhaustion semantics (cost == budget triggers contradiction in both cases)
  - The cell value AT exhaustion equals the budget (the on-write predicate fires when `(>= new-cost budget)`)
  - V-tier post-impl validates: existing tests' `(prop-network-fuel result)` assertions migrate to `(net-cell-read result fuel-cost-cell-id)` and PASS with equivalent semantics

### §10.7 Open questions (D.4)

- **Q-1C-1** (CARRIED, REFRAMED under D.4): typing-propagators saved-fuel rollback semantics under tagged-cell-value worldview-narrow — verify at 1C-i mini-design whether existing speculation-rollback mechanism handles cell value correctly without explicit save/restore. Lean: yes, since the cell's tagged-cell-value entries are per-worldview by construction; rollback narrows worldview, restoring pre-speculation entries.

- **Q-1C-2** (CARRIED, REFRAMED): test cell-mediated API additions — under D.4, the 13 test sites migrate to direct cell-API; what NEW cell-mediated tests are owed beyond the migration? Lean: add specialized-cell-semantics-parity tests (per §15) covering on-write check behavior + fire-on-threshold-crossing notification.

- **Q-1C-3** (RETIRED under D.4): cell-update cadence enumeration. Was BLOCKING for Phase 1C-iv under D.3 (hybrid required exhaustive enumeration of semantic transitions for the Cell Staleness Contract). Under D.4, the cell IS the live state — no staleness; the cell value updates per-decrement, which is what the propagator network sees. No cadence enumeration needed.

- **Q-1C-4** (D.4 NEW): cell-id 11/12 reservation — verify no future phase wants these slots; consider if cell-id allocation should be more flexible (e.g., per-domain allocation registry). Lean: hard-code 11/12 for now per §4.3 (well-known positions); future flexibility via the SRE domain registry is a Phase 1E/2 concern.

- **Q-1C-K** (D.4 NEW, Option 13 refinement; defer-to-1C-i-mini-audit): local-var flush timing — enumerate the boundary points where Variant B flushes local-var to cell. Candidate list:
  - Phase entry (cell-read into local-var)
  - Phase exit (local-var → cell-write)
  - Contradiction detection (immediate flush + contradiction-write)
  - Speculation fork (immediate flush before fork; sub-fork reads from cell)
  - External snapshot/restore boundary (immediate flush)
  
  Variant A (parallel BSP main loop) only has one boundary point: round entry. No flush logic needed beyond the round-entry cell-write itself.
  
  Lean: 1C-i mini-audit enumerates each variant's flush points; implement uniformly via a `flush-fuel-local-var!` helper macro/function called at each site for Variant B; Variant A's single cell-write at round entry handles its case directly.

- **Q-1C-L** (D.4 NEW, Option 13 refinement; RESOLVED): local-var location for Variant B — three options:
  - L1: Let-scoped `box` inside the sequential phase's function (ephemeral; lives only during the phase invocation)
  - L2: Struct field on `prop-network` (persistent; mutable)
  - L3: Racket parameter (banned per DEVELOPMENT_LESSONS.org "Callbacks Are a Propagator-First Anti-Pattern" + off-network state)
  
  Lean: **L1 (let-scoped box, ephemeral)**. Avoids "what's the source of truth between phases" question — each phase reads cell at entry, writes cell at exit. Variant A doesn't have a local-var at all (the cell-write at round entry is direct).

- **Q-1C-M** (D.4 NEW, Option 13 refinement; RESOLVED IN-SCOPE 2026-05-15 per audit): parallel BSP composition. The production scheduler is the parallel BSP from PAR Track 2 R1-R2 (`current-parallel-executor` set globally in `driver.rkt:435`). Under Variant A: the main BSP thread does the round-entry cell-write SEQUENTIALLY before workers spin up; workers fire pids against the post-decrement snapshot but don't touch fuel-cost cell. No multi-thread contention on fuel; no reduce-at-round-end needed. The parallel BSP architecture already serializes scheduler-state updates on the main thread (per current line 2384's struct-copy on the main thread); Phase 1C migration changes the substrate (struct field → cell) without changing the concurrency pattern. Earlier framing as "deferred to Phase 2 PAR future" was incorrect; corrected 2026-05-15.

- **Q-1C-N** (D.4 NEW, Option 13 refinement; FORWARD-CAPTURE): other scheduler-state cells that could use the deferred-write pattern. Candidates: worklist-cache cell (currently read per BSP round; could benefit from Variant A); future BSP-round-counter cell (if introduced); future PReduce/OE cost cells. Out of scope for Phase 1B/1C; captured in §13.7 forward-look for future tracks.

---

> **Below: §10 D.3 (historical hybrid pivot content) — RETIRED-PER-D.4-CANONICAL**
> 
> Preserved for traceability with D.2.SC + D.3.EC critique resolution rationale. §13.6 Pre-0 spike (commit `7b681b9e`) decisively falsified the empirical motivation for the hybrid pivot; the on-network specialized cell type framework provides the per-decrement performance + zero-GC guarantee that the hybrid was designed to preserve via off-network struct-field. The D.3 hybrid pivot SCAFFOLDING never shipped.

---

---

## §10 (D.3 historical) — Canonical BSP fuel substrate (hybrid pivot architecture)

**REWRITTEN in D.2** per Pre-0 findings. The original D.1 §10 framing — "replace the imperative `(fuel 1000000)` decrementing counter with the on-network tropical fuel cell" — was reframed by Pre-0 measurement evidence (8 supporting findings + S-tier baseline finding 20). The hybrid pivot is empirically grounded across all 5 measurement tiers (M+A+E+R+S).

### §10.1 Scope and rationale (HYBRID PIVOT — D.2)

**Phase 1C INTRODUCES the canonical tropical fuel substrate as architectural foundation for Phase 3C consumers** (UC1 fuel-exhaustion blame attribution; UC2 cost-bounded elaboration via Galois bridge; UC3 per-branch cost tracking under union-type ATMS) **WITHOUT migrating the per-decrement hot path off the existing struct-copy + inline check fast-path.**

**The hybrid architecture**:
- Decrement sites (4) PRESERVE the existing `(struct-copy prop-net-cold ... [fuel (- ... n)])` pattern (no migration; ~24 ns)
- Check sites (11) PRESERVE the existing `(<= (prop-network-fuel net) 0)` inline check (no migration; ~6 ns)
- Per-decrement total cycle stays at ~30-40 ns (matches Pre-0 baseline; no regression)
- The canonical fuel-cost-cell + fuel-budget-cell are allocated at well-known IDs (cell-id 11/12) and serve as the architectural substrate for Phase 3C consumers, NOT as per-decrement live state
- The threshold propagator is installed as the structural guarantee that contradiction-on-exhaustion routes through the propagator network for any path that updates the cell
- Cell value is updated at SEMANTIC TRANSITIONS (start of phase, exhaustion-write, save/restore boundaries via existing snapshot mechanism) — NOT per-decrement

**Empirical rationale** (Pre-0 plan §12.6 Findings 2, 5, 11, 13, 15, 16, 17, 19, 20):
- M-2: inline check 6 ns vs propagator fire 100-600 ns (10-100× regression risk if per-decrement)
- R-16: ZERO GC during 100k decrements under struct-copy; per-decrement cell-write would generate tagged-cell-value entries → MAJOR GC pressure
- R-19: hybrid pivot is the ONLY architecture preserving the GC-friendly property of the current substrate (strongest single piece of evidence)
- S-20: pre-impl `prop_firings` + `prop_allocs` are ZERO suite-wide; Phase 1C threshold propagator becomes the FIRST production on-network propagator firing in elaboration; clean architectural baseline

**Why hybrid IS principled (not belt-and-suspenders)**:
- Decrement sites' inline check + cell substrate handle DIFFERENT code paths with DIFFERENT performance profiles
- Inline check: per-decrement HOT PATH (common case; ~30-40 ns; 100k+ ops/sec in deep type inference)
- Cell + threshold propagator: Phase 3C consumer paths (rare; semantic-phase granularity; few ops per file)
- The mechanisms are NOT redundant; they decomplect fast-path optimization from architectural substrate

**D.3 R1 commentary — small code-change footprint is intentional, not "easy migration"**:

Phase 1C's small code-change footprint under hybrid (~45-90 LoC vs D.1's ~250-400) is the empirical consequence of preserving the per-decrement hot path. The design weight is in the architectural framing (cell substrate + threshold propagator + cell staleness contract per §10.B + Phase 3C consumer API + four-surface scaffolding tracking per §10.1.A), NOT in code volume.

Future PReduce / OE consumers (per §6.6 hybrid-as-scaffolding-NOT-template caveat) should NOT use Phase 1C's small footprint as evidence of "easy migration" — under hybrid, the work was DEFERRED via scaffolding (per §10.1.A retirement plan + Issue #55), NOT eliminated. The full-migration footprint (~250-400 LoC per D.1 §10.4) is recoverable as the future SH Series migration scope (per DEFERRED.md "PPN 4C tropical addendum: hybrid pivot scaffolding retirement" entry).

**D.3 M3 acknowledgment — cell-update cadence is IMPOSED ORDERING (ACKNOWLEDGE)**:

Cell-update cadence (semantic-transition-only per §10.B + Q-1C-3) is IMPOSED ORDERING, not emergent from dataflow per [`propagator-design.md` § "Emergent vs. imposed ordering"](../../.claude/rules/propagator-design.md). This is the consequence of preserving struct-field as live state (per M2 + R-19): without per-decrement cell-write, the cell's update points must be imperatively chosen ("update at start of phase" / "update on save/restore" / "update on exhaustion"). **Trade-off explicit**: imposed ordering (lose mantra alignment at hot-path) vs major-GC-risk (lose runtime feasibility). The hybrid chooses the former for the per-decrement timescale; SH Series retirement (per Issue #55) restores emergent ordering when runtime supports per-decrement cell-write.

### §10.1.A Honest framing & retirement plan (D.3 consolidating P1 + P4 REFINEMENTs) — RETIRED-PER-D.4-CANONICAL

> **D.4 CANONICAL status (2026-05-14)**: §13.6 Pre-0 spike PASSED (commit `7b681b9e`); the hybrid pivot SCAFFOLDING never shipped. This subsection's retirement plan + four-surface tracking discipline is therefore obsolete (no scaffolding to retire; cell IS the live state under D.4 canonical). Section content preserved below for traceability with D.2.SC P1+P4 critique resolution rationale and as a record of the design alternative considered.


The "decomplection" framing in §10.1 describes WHAT the hybrid does at the architectural level. This subsection adds the WHY (specific blocker), the principle-level acknowledgment (Cell-as-Single-Source-of-Truth inversion), and the retirement plan with dual-surface tracking. Both framings are simultaneously true and intentional — design intent + honest accountability.

**Two framings, both true**:

1. **Decomplection** (positive description; what the design does): hybrid separates fast-path optimization (struct-copy + inline check at per-decrement) from architectural substrate (cell + threshold propagator at semantic-phase granularity). The mechanisms address different code paths with different performance profiles.

2. **Incomplete migration deferred to SH Series** (honest acknowledgment; why the design does it): apply the [`workflow.md` § "'Pragmatic' Is a Rationalization for Incomplete"](../../.claude/rules/workflow.md) test — replace "decomplection" with "incomplete migration" and verify the rephrased framing is acceptable:
   > "The hybrid pivot is INCOMPLETE migration — decrement sites preserve struct field because cell-write at per-decrement rate triggers major GC under current Racket runtime (per Pre-0 Finding 19 R3 baseline)."
   
   The rephrasing IS acceptable because it names the **specific blocker**: Racket runtime GC behavior at per-decrement cell-write rate. Per the codified pattern, "deferred to Track N because [specific dependency]" is the principled deferral form; "decomplection" alone (without specific blocker) would be rationalization.

**Principle inversion (acknowledged explicitly)**:

[`DESIGN_PRINCIPLES.org § Propagator-First Infrastructure`](principles/DESIGN_PRINCIPLES.org) defaults to cells over off-network state — Cell-as-Single-Source-of-Truth. Under hybrid, this principle is **INVERTED at the per-decrement timescale**: the struct-field `prop-net-cold-fuel` is the LIVE STATE for fuel-cost; the cell is DERIVED via lazy sync at semantic transitions (per §10.B Cell Staleness Contract). The inversion is empirically forced (not stylistic) per [Pre-0 Finding 19](2026-04-26_TROPICAL_ADDENDUM_PRE0_PLAN.md): R3 measured ZERO major GC during 100k decrements under struct-copy; ANY architecture making the cell PRIMARY at per-decrement granularity triggers major GC pressure (architectural failure under R3 baseline).

**Retirement plan**:

The inversion is SCAFFOLDING pending SH Series runtime infrastructure that makes per-decrement cell-write GC-friendly. Under SH Series:
- Per-decrement cell-write becomes feasible (cheaper GC characteristics, lighter cell representation, OR object pooling for tagged-cell-value entries)
- The cell becomes PRIMARY storage; the struct-field `prop-net-cold-fuel` is retired
- The hybrid pivot retires; full migration lands as the original D.1 design intended (see D.1 §10.3 patterns)
- §14.4 SRE lattice lens Q5 dual-classification reverts to single (cell PRIMARY)

**Dual-surface tracking** (operational + design-time visibility):
- [GitHub Issue #55](https://github.com/LogosLang/prologos/issues/55) — "PPN 4C tropical addendum: retire hybrid pivot scaffolding (per-decrement fuel-cost cell migration) under SH Series runtime" (queryable, linkable from PRs, surfaces in repo dashboards)
- [`DEFERRED.md`](DEFERRED.md) entry under "PPN 4C tropical addendum: hybrid pivot scaffolding retirement" (in-repo single-source-of-truth for deferred work)
- [`Q-1B-6` empirical-validation spike at Phase 1B mini-design opening](#§99-open-questions-deferred-to-per-phase-mini-designaudit-per-users-workflow) (PRE-implementation falsification test) + [§11.3 Hybrid pivot reconsideration gate at Phase 1V close](#§113-phase-1v-exit-criteria) (POST-implementation final verification)

The four-surface tracking (design-doc + DEFERRED.md + GitHub Issue + bracketed implementation gates) ensures the scaffolding is impossible to forget when SH Series runtime work begins.

**This is honest deferral, not principle violation** per `workflow.md` § "Validated ≠ Deployed" + `DEVELOPMENT_LESSONS.org` § "'Pragmatic' Is a Rationalization for Incomplete." The principled discipline: name the specific blocker (✓ Racket runtime GC at per-decrement cell-write rate); name the retirement trigger (✓ SH Series runtime infrastructure); track at multiple surfaces (✓ four surfaces above); verify the deferral remains valid (✓ Q-1B-6 + §11.3 falsification gates).

### §10.A The threshold propagator's role under hybrid (D.3 from M1 BLOCKING) — RETIRED-PER-D.4-CANONICAL

> **D.4 CANONICAL status (2026-05-14)**: §13.6 Pre-0 spike PASSED. Under D.4 (per §4.6), the threshold check is an INLINE on-write predicate at the CELL layer (NOT a separate propagator). The propagator-as-decoration concern from M1 is structurally avoided. Section content preserved below for traceability with M1 resolution rationale and as a record of the alternative considered.


Per Network Reality Check (`workflow.md`): apply the three concrete questions to the threshold propagator under hybrid:

1. **Which `net-add-propagator` calls?** — 1 (at make-prop-network setup; per §10.2)
2. **Which `net-cell-write` calls produce the result?** — Cell-write-mutating call sites (per §10.B Cell Staleness Contract); decrement sites use struct-copy (NOT cell-write)
3. **Trace cell creation → propagator installation → cell write → cell read = result?** — YES for non-decrement-site paths; NO for the per-decrement hot path

**Honest reframing**: under hybrid, the threshold propagator does NOT carry per-decrement information flow. Decrement sites use inline check + struct-copy; the cell isn't written per-decrement. The propagator's load-bearing role is for **non-decrement-site cell-write paths**, of which there are exactly THREE under D.3 design:

1. **Phase 3C consumer paths** that update fuel cost. Examples:
   - UC1 walks accumulating cost across propagator dependency chains (residuation walk for fuel-exhaustion blame attribution per §9.7)
   - UC2 budget projection writes (cost-bounded elaboration via Galois bridge γ direction per §9.7)
   - UC3 per-branch cost updates under union-type ATMS branching (per §9.7)
2. **On-exhaustion path** — decrement site detects exhaustion via inline check; writes final cost to fuel-cost-cell; propagator fires (rare event); writes contradiction. This routes contradiction through propagator network for architectural correctness on the rare exhaustion event.
3. **Speculation rollback** — cell-restore via worldview narrow under tagged-cell-value semantics; threshold propagator may re-fire if rollback restores a different cost level relative to budget.

**For per-decrement information flow on the hot path**: NOT propagator-mediated under hybrid. This is acknowledged scaffolding pending SH Series runtime infrastructure that makes per-decrement cell-write GC-friendly (per Pre-0 Finding 19; current Racket runtime triggers major GC under per-decrement cell-write at 100k+ ops/sec).

**Why this matters**: this honest framing prevents the "propagator-as-decoration" failure mode (per CRITIQUE_METHODOLOGY § Lens M; PPN Track 4 retrospective). The propagator IS load-bearing — for the three named roles above, NOT for every decrement. Future maintainers reading "threshold propagator installed for Phase 1C" should understand:
- Phase 3C consumers MUST trigger the propagator via cell-write to get contradiction-on-exhaustion semantics for their consumer paths
- The propagator does NOT serve as a per-decrement "watch the cost cell, fire on every change" — that pattern is structurally avoided under hybrid for performance + GC reasons

**Cross-reference**: per §10.B Cell Staleness Contract, the propagator's three roles all involve EXPLICIT cell-write operations (not implicit per-decrement updates); this is consistent with the staleness contract's "cell value lags struct-field by at most one semantic transition" framing.

### §10.B Cell Staleness Contract (D.3 from P3 BLOCKING) — RETIRED-PER-D.4-CANONICAL

> **D.4 CANONICAL status (2026-05-14)**: §13.6 Pre-0 spike PASSED. Under D.4 (per §4.6), the cell IS the live state — no staleness; no dual-API discipline; `net-cell-read` always returns the current value (or `tagged-cell-value` filtered by current worldview). P3 staleness concern is structurally absent. Section content preserved below for traceability with P3 resolution rationale and as a record of the alternative considered.


Under hybrid pivot, the fuel-cost cell's value LAGS the struct-field's live state. This subsection makes the staleness explicit at the API surface so consumers can reason correctly.

**Staleness bound**: at most one semantic transition. The cell value reflects the cost-state as-of the last semantic-transition cell-write (per Q-1C-3 enumeration, deferred to Phase 1C-iii mini-design).

**Two API surfaces** (typed read APIs):

```racket
;; net-fuel-cost-read net :: Net -> TropicalFuel
;;   Returns the cell value (POSSIBLY STALE — caller accepts staleness).
;;   Use when: cost-as-of-last-transition is sufficient for the consumer's purpose.
;;   Examples: Phase 3C UC1 walk accumulating cost from prior dependency chain
;;             snapshots; UC3 branch-local cost reads at branch-fork boundaries.
(define (net-fuel-cost-read net)
  (net-cell-read net fuel-cost-cell-id))

;; net-fuel-cost-read/synced net :: Net -> (Values Net TropicalFuel)
;;   Triggers sync from struct-field BEFORE reading. Returns updated net + live cost.
;;   Use when: caller needs LIVE cost-state at the read point.
;;   Examples: Phase 3C UC2 budget projection at semantic-phase boundary;
;;             on-exhaustion reads triggered from non-decrement-site contexts.
(define (net-fuel-cost-read/synced net)
  (define current-fuel (prop-network-fuel net))         ; struct-field live state
  (define budget (net-cell-read net fuel-budget-cell-id))
  (define current-cost (- budget current-fuel))         ; derive cost from struct-field
  (define synced-net (net-cell-write net fuel-cost-cell-id current-cost))
  (values synced-net current-cost))
```

**Discipline at the API surface**: Phase 3C consumer authors choose explicitly which API to use based on staleness tolerance. The naming convention (`/synced` suffix) makes the choice visible at the call site:
- `(net-fuel-cost-read net)` reads possibly-stale data — fine for many consumer purposes, FAST
- `(net-fuel-cost-read/synced net)` triggers sync — guaranteed live, costs one struct-field read + one cell-write

**Why this matters (Correct-by-Construction enforcement)**: per DESIGN_PRINCIPLES.org § Correct by Construction, the wrong thing should be hard to express. Without the typed API discipline, consumer code writes `(net-cell-read net fuel-cost-cell-id)` and silently accepts whatever the cell value happens to be — the staleness gap is invisible until it produces incorrect results in a Phase 3C UC. With the discipline, the consumer's read API choice IS their staleness contract; the design surface enforces the contract structurally.

**Documentation requirement**: the dual-API discipline + staleness bound MUST be documented INLINE at the API definitions in `tropical-fuel.rkt` (Phase 1B implementation), not just in this design doc. The inline documentation is the load-bearing artifact for consumer authors; the design doc is reference.

**Open question (deferred to Phase 1C-iii)**: Q-1C-3 cell-update cadence enumeration is BLOCKING for this contract — see §10.7. Without exhaustive enumeration of "what counts as a semantic transition," the staleness bound is ambiguous in practice.

### §10.2 Audit-grounded substrate plan (Q-Audit-1 findings — UNCHANGED)

**Allocation in `make-prop-network`** (per D.3 §10.3 — substrate setup is the same):
```racket
(define (make-prop-network [fuel 1000000])
  ;; ... existing allocations (cell-ids 0-10) ...

  ;; Phase 1C — canonical tropical fuel cells (architectural substrate)
  (define-values (net1 fuel-cid) (net-new-tropical-fuel-cell base-net))
  ;; (verify cell-id allocated as 11 — well-known position)

  (define-values (net2 budget-cid) (net-new-tropical-budget-cell net1 fuel))
  ;; (verify cell-id allocated as 12)

  ;; Install threshold propagator (structural guarantee for cell-write paths)
  (define threshold-prop (make-tropical-fuel-threshold-propagator fuel-cid budget-cid))
  (net-add-propagator net2 (list fuel-cid budget-cid) '() threshold-prop)
  ;; ...

  ;; PRESERVE: prop-net-cold struct still has 'fuel' field (per-decrement live state)
  ;; PRESERVE: prop-network-fuel macro at line 399 (fast-path accessor)
)
```

**Export well-known cell-ids**: `fuel-cost-cell-id = 11`, `fuel-budget-cell-id = 12` per §4.3.

**Production scope under hybrid** (vs original D.1 §10.2 audit findings):
- **Decrement sites** (4): NO migration; preserve existing struct-copy pattern
- **Check sites** (11): NO migration; preserve existing inline `(<= fuel 0)` check
- **Read-as-value sites** (3): MIGRATE selectively (architecturally-consistent paths use cell-read; performance-sensitive paths use struct-field)
- **Macro `prop-network-fuel`**: PRESERVED (still accesses struct field)
- **Struct field `prop-net-cold-fuel`**: PRESERVED (live state for fast-path)
- **typing-propagators saved-fuel** (1): MIGRATE to cell-mediated semantics (snapshot/restore boundary is a semantic transition)
- **pretty-print** (1): UPDATE to display both struct-field cost and cell-budget for debugging
- **Test sites** (13): MINIMAL migration — preserve existing struct-field assertions; ADD new tests for cell-mediated APIs where Phase 3C-relevant
- **Bench sites** (2): NO migration (bench-alloc.rkt measures decrement cost, which stays struct-copy)

**D.3 R2 commentary — Q-Audit-1 17-refs framing under hybrid**:

D.1 §2.2 Q-Audit-1 enumerated 17 production refs to `prop-network-fuel`. Under D.2/D.3 hybrid pivot, the categorization is:
- **15 PRESERVED** (no migration; per the production scope list above): 4 decrement sites + 11 check sites
- **2-3 SELECTIVELY MIGRATED** (per §10.3 selective-migration patterns): 1-2 read-as-value sites at semantic-transition paths + typing-propagators saved-fuel cell sync
- **Plus**: 1 pretty-print update (dual display); 13 test refs MOSTLY PRESERVED (struct-field assertions); 2 bench refs PRESERVED

The "17 production refs" count from Q-Audit-1 is **REFERENCE for completeness** (architectural visibility into the full migration scope D.1 envisioned); the actual MIGRATION scope under hybrid is ~3-5 sites (per R1 §1.2 reframing). Future SH Series migration will recover the full 17-ref scope (per [Issue #55](https://github.com/LogosLang/prologos/issues/55) + [DEFERRED.md](DEFERRED.md) "PPN 4C tropical addendum: hybrid pivot scaffolding retirement" entry).

This rescoping note bridges the audit grounding (17-refs framing useful for full architectural visibility) with the actual hybrid migration scope (~3-5 sites) so future readers don't misread the audit count as the implementation count.

### §10.3 Per-site patterns under hybrid (REVISED)

**Decrement sites** (4 sites — propagator.rkt:2384, 3000, 3053, +1 widening — UNCHANGED):

```racket
;; PRESERVED: struct-copy decrement (fast-path; 24 ns/call per Pre-0 M7.1)
(struct-copy prop-net-cold ... [fuel (- (prop-network-fuel net) n)])
```

**Check sites** (11 sites — propagator.rkt:1817, 2366, 2373, 2329, 2992, 3045, 3132, 3135, 3142, 65, 399 — UNCHANGED):

```racket
;; PRESERVED: inline check (fast-path; 6 ns/call per Pre-0 M8)
[(<= (prop-network-fuel net) 0) net]
```

**On exhaustion (decrement site detects cost >= budget)** — NEW pattern under hybrid:

```racket
;; When decrement would cause exhaustion, write the exhausted cost to the cell
;; This triggers the threshold propagator (rare event), which routes contradiction
;; through the propagator network for architectural correctness.
(let* ([new-fuel (- (prop-network-fuel net) n)])
  (cond
    [(<= new-fuel 0)
     ;; Exhausted — write to cell to trigger threshold propagator
     (define cost-on-exhaustion (- (prop-network-fuel-budget net) new-fuel))
     (net-cell-write net fuel-cost-cell-id cost-on-exhaustion)]
     ;; threshold propagator fires; writes contradiction; net is now contradicted
    [else
     ;; Fast-path: struct-copy update; no cell-write; no propagator fire
     (struct-copy prop-net-cold ... [fuel new-fuel])]))
```

The exhaustion path is RARE (per Pre-0 finding 5: a typical run completes within budget; exhaustion is the failure case). The cost of cell-write + propagator fire is amortized over the entire run.

**D.3 M2 acknowledgment — on-exhaustion pattern IS imperative dispatch (REFINEMENT)**:

The decrement site's `(<= new-fuel 0)` check IS imperative dispatch (the site decides which path to take), per [`propagator-design.md` § "Information vs. instruction"](../../.claude/rules/propagator-design.md). The propagator-mindspace ideal would be unconditional cell-write with propagator-emergent exhaustion (cell value crosses budget threshold → propagator fires emergently → writes contradiction); this is INFEASIBLE under hybrid per Pre-0 R-19 (per-decrement cell-write triggers major GC). The hybrid CHOOSES imperative dispatch for the hot-path; the cell + propagator handle rare-event consumer paths (Phase 3C UC1/UC2/UC3 + speculation rollback) emergently per §10.A. This trade-off is the consequence of the per-decrement timescale's runtime constraint; under SH Series (per Issue #55 retirement), the imperative-dispatch hot-path retires alongside the struct-field, restoring propagator-emergent exhaustion as the architectural target.

**Read-as-value sites** (3 sites — selective migration):

```racket
;; Site 1: propagator.rkt:1824 (general-purpose remaining-fuel boxing)
;;   PRESERVE struct-field access (fast-path; not a semantic transition)
(define remaining-fuel (box (prop-network-fuel net)))

;; Site 2: propagator.rkt:1872 (similar pattern)
;;   PRESERVE struct-field access

;; Site 3: propagator.rkt:2875 (potentially semantic-transition path)
;;   AUDIT at 1C-iv mini-design: if path is reached at semantic-transition
;;   (e.g., before save/restore, before phase boundary), MIGRATE to cell-read
;;   to ensure cell value reflects current cost; otherwise PRESERVE struct-field
```

**typing-propagators.rkt:2269** (saved-fuel rollback — semantic transition):

```racket
;; BEFORE
(define saved-fuel (prop-network-fuel net2w))
;; ... later restore via snapshot mechanism

;; AFTER (under hybrid)
;; Save/restore IS a semantic transition; sync cell at this boundary
(define saved-fuel (prop-network-fuel net2w))  ; struct-field for fast-path
;; Cell update at the snapshot boundary (semantic transition):
(net-cell-write net2w fuel-cost-cell-id
                (- (net-cell-read net2w fuel-budget-cell-id) saved-fuel))
;; (later restore: existing snapshot mechanism handles BOTH struct-field AND cell)
```

Per Q-1C-1 (deferred to 1C-iv mini-design): verify whether elab-net snapshot mechanism already captures cell state, OR whether explicit cell-write is needed at save/restore boundaries.

**pretty-print.rkt:463** (display — update to show both):

```racket
;; BEFORE
[(expr-prop-network v) (format "#<prop-network ~a>" (prop-network-fuel v))]

;; AFTER
[(expr-prop-network v)
 (format "#<prop-network fuel=~a cost-cell=~a budget-cell=~a>"
         (prop-network-fuel v)                   ; struct-field (live state)
         (net-cell-read v fuel-cost-cell-id)     ; cell value (semantic-transition state)
         (net-cell-read v fuel-budget-cell-id))]
;; If struct-field and cell value differ, that's expected (cell is updated only at
;; semantic transitions); display both for debugging/observability.
```

**Macro `prop-network-fuel` (propagator.rkt:399)** — PRESERVED:

```racket
;; PRESERVED: still expands to struct-field access; serves fast-path callers
(define-syntax-rule (prop-network-fuel net) (prop-net-cold-fuel (prop-net-cold-of net)))
```

**Struct field `prop-net-cold-fuel` (propagator.rkt:337)** — PRESERVED:

```racket
;; PRESERVED: still in prop-net-cold struct; serves as per-decrement live state
;; Cell substrate is COMPLEMENTARY (semantic-transition state for Phase 3C consumers)
```

**Test migrations** (selective):
- 13 test sites: most PRESERVE existing `(prop-network-fuel net)` assertions (testing struct-field/counter behavior)
- ADD new tests for cell-mediated APIs:
  - Cell allocation at make-prop-network: verify cell-id 11/12 + initial values
  - Threshold propagator installation: verify cell-write triggers contradiction at boundary
  - Semantic-transition sync: verify cell value reflects cost at save/restore boundaries
  - Phase 3C UC1/UC2/UC3 cell-read patterns (forward-capture for Phase 3C tests)

**Bench migrations** (no migration):
- bench-alloc.rkt 2 sites: PRESERVE struct-copy measurement (the per-decrement cost is the architecturally-significant metric)

### §10.4 Sub-phase plan (REVISED — REDUCED scope)

Under hybrid, Phase 1C is dominated by SUBSTRATE setup, not migration. Sub-phase plan compressed from 9 to 5 sub-phases:

- **1C-i** — Pre-implementation audit (mini-audit): verify cell-id 11/12 unconflicted; identify which read-as-value sites (3) are semantic transitions vs fast-path; identify Phase 3C UC test scaffolding sites
- **1C-ii** — Allocate canonical cells in `make-prop-network` (cell-id 11/12 + threshold propagator install); export `fuel-cost-cell-id` + `fuel-budget-cell-id` constants
- **1C-iii** — Implement on-exhaustion cell-write at decrement sites (rare-event path; not per-decrement hot-path); implement typing-propagators saved-fuel cell sync at semantic-transition boundaries; update pretty-print display
- **1C-iv** — Migrate selective read-as-value sites (per audit at 1C-i); add new tests for cell-mediated APIs (substrate validation + Phase 3C UC forward-capture)
- **1C-v** — Verification + close: probe + targeted suite + full suite + parity test (tropical-fuel-parity axis: counter exhaustion AND cell-write-on-exhaustion equivalent for representative workloads); verify per-decrement performance preserved (M7+M8+M13 within Pre-0 variance)

**Sub-phases REMOVED from D.1 §10.4** (no longer needed under hybrid):
- ~~1C-iii Migrate decrement sites~~ — preserved
- ~~1C-iv Migrate check sites~~ — preserved
- ~~1C-vi Retire prop-network-fuel macro + prop-net-cold-fuel field~~ — preserved
- ~~1C-vii Migrate test sites batch mechanical~~ — minimal migration
- ~~1C-viii Migrate bench sites~~ — preserved

### §10.5 Drift risks (REVISED for hybrid)

- **D-1C-1**: Cell-update cadence ambiguity — when EXACTLY does the cell get synced from struct-field? Per Q-1C-3 (NEW): semantic-transition-only is the leaning answer, but explicit enumeration of transitions (start of phase / exhaustion / save-restore / phase-boundary) needs verification at 1C-iii mini-design
- **D-1C-2**: typing-propagators saved-fuel rollback — verify whether elab-net snapshot mechanism captures cell state automatically OR explicit cell-write at boundaries needed (per Q-1C-1)
- **D-1C-3**: Cell-id 11/12 conflicts — verify at 1C-i mini-audit no other phase has reserved these IDs
- **D-1C-4**: Threshold propagator firing semantics under speculation — verify with test-speculation-bridge that cell-write under speculation worldview correctly tags the threshold-fire event
- **D-1C-5**: Performance regression at decrement sites under hybrid — Pre-0 M7+M8+M13 baseline must be preserved (per microbench-claim verification rule). At 1C-v close: re-run M7+M8+M13 to verify ≤5% regression vs baseline.
- **D-1C-6** (NEW): Cell value vs struct-field divergence — under hybrid, the cell can be stale relative to struct-field between semantic transitions. Phase 3C consumers reading the cell must understand this; either accept staleness OR trigger sync first. Document the cell-staleness contract at 1C-ii mini-design.

### §10.6 Termination + parity

- Termination: Phase 1C substrate setup is structural (cell allocation + propagator install); preserves existing decrement+check semantics; trivially terminates
- Parity: tropical-fuel-parity axis (per D.3 §7.11) — UPDATED:
  - For representative workloads, OLD counter and NEW substrate produce IDENTICAL exhaustion semantics (struct-field counter is the live state in both cases)
  - The cell value at semantic-transition boundaries equals (budget - struct-field-fuel); this equivalence is the parity invariant
  - On-exhaustion contradiction-write routes through propagator network in NEW; same semantic effect as OLD inline `(<= fuel 0)` short-circuit
  - V-tier post-impl validates: existing tests' `(prop-network-fuel result)` assertions PASS unchanged

### §10.7 Open questions (deferred to per-phase mini-design+audit)

- **Q-1C-1** (CARRIED): typing-propagators saved-fuel rollback semantics — verify at 1C-iii mini-design
- **Q-1C-2** (CARRIED, REFRAMED): Test cell-mediated API additions — which Phase 3C UC forward-capture tests belong in Phase 1C? (The cost-accumulation semantic shift in D.1 §10.7 is moot under hybrid since struct-field assertions are preserved.)
- **Q-1C-3** (NEW under hybrid; **BLOCKING for Phase 1C-iv per D.3 R3 ACKNOWLEDGE**): Cell-update cadence — exhaustively enumerate ALL semantic transitions where cell sync occurs. **BLOCKING for Phase 1C-iv**: this enumeration must be COMPLETE at Phase 1C-iii mini-design BEFORE selective-migration code lands at Phase 1C-iv (otherwise Phase 3C consumers may discover "semantic transition" doesn't cover their use case post-implementation).

  **Candidate transition list** (D.3-time enumeration; refine at 1C-iii with code):
  - Start of phase (initial budget allocation in `make-prop-network`)
  - End of phase (final cost capture; pretty-print display)
  - Save/restore boundaries (snapshot-mediated; typing-propagators saved-fuel sync per Q-1C-1)
  - On-exhaustion path (decrement site detects exhaustion; writes final cost to cell)
  - Phase 3C UC explicit query sites (sync-on-read via `net-fuel-cost-read/synced` per §10.B Cell Staleness Contract)
  - **NEW per D.3 R3 (consider at 1C-iii mini-design)**:
    - **BSP round boundaries** within a single elaboration? (yes if Phase 3C UC1 walks dependency chains across rounds; verify at 1C-iii)
    - **Topology-stratum transitions** when new cells/propagators are added? (likely yes; topology stratum runs between BSP rounds; cell sync at topology boundary preserves consistency for any propagator the topology stratum installs)
    - **Sub-phase boundaries** within a single command processing? (probably no; sub-phases are internal to a command; semantic-transition granularity is at command level)
    - **Speculative-rollback boundaries** per `with-speculative-rollback` retirement scope? (yes; rollback IS a save/restore boundary)
    - **Inter-test boundaries** per-test fuel reset semantics? (yes; per-test fixture pattern resets fuel; cell sync at test boundary = fuel reset captured)

  For each candidate transition: decide YES (synced) or NO (not a transition); document the staleness bound; update §10.B cell-staleness-contract API documentation.
  
  Lean: enumerate at 1C-iii mini-design with code in hand; the answer informs whether cell-staleness is bounded and predictable.

---

## §11 Phase 1V — Vision Alignment Gate Phase 1

### §11.1 Scope

Adversarial TWO-COLUMN VAG (per `9f7c0b82` codification) on all of Phase 1: 1A-iii-b + 1A-iii-c + 1B + 1C closure together. Closes Phase 1 entirely.

### §11.2 VAG structure (per Stage 4 Per-Phase Protocol Step 5)

Four questions × TWO-COLUMN catalogue vs challenge:

**Question (a) On-network?**
- Catalogue: tropical fuel substrate fully on-network; ATMS deprecated APIs + surface AST retired (no off-network deprecated state)
- Challenge: are there any remaining off-network references to retired APIs? Defensive guards "for safety" preserved? Run pipeline.md "Two-Context Audit" to verify both elaboration + module-loading contexts.

**Question (b) Complete?**
- Catalogue: 1A-iii-b retirement complete (13 functions + struct + atms-believed); 1A-iii-c retirement complete (14-file pipeline); 1B primitive shipped + tested; 1C substrate setup complete (cell-id 11/12 allocated; threshold propagator installed; struct-field + macro + decrement/check sites preserved per hybrid pivot)
- Challenge: did Pre-0 microbenchmark perf claims land? Re-microbench M7+M8+M13 at close per microbench-claim verification rule (Pre-0 plan §12.6 cross-reference); per-decrement cycle should remain ~30-40 ns. Did any quantale property declarations remain speculative (capture-gap risk; M10/M12/R4/A12 captured at §9.10 Phase 1B implementation checklist)? Under hybrid: did the decomplection of fast-path + cell substrate genuinely deliver, or did edge cases force per-decrement cell writes (architectural failure)?

**Question (c) Vision-advancing?**
- Catalogue: first optimization-quantale instantiation in production; tropical fuel substrate; multi-quantale composition NTT; Phase 3C cross-reference capture; hybrid pivot's empirically-grounded decomplection
- Challenge: is the residuation operator load-bearing (Form A test passes) or speculative? Does the multi-quantale NTT actually compose with TypeFacet quantale, or is it parallel co-existence only? Is OE Series Track 0/1/2 first landing recognized? Under hybrid: is preserving the struct field + macro genuinely "fast-path needed for performance" or "scaffolding preserved for safety" (workflow.md belt-and-suspenders red flag — D.3 lens P scrutiny target)?

**Question (d) Drift-risks-cleared?**
- Catalogue: drift risks named per §7.4, §8.4, §9.8, §10.5 (D-1C-1 through D-1C-6 under hybrid) all addressed
- Challenge: did the named risks cover both correctness AND perf-vs-design-target axes? Were any inherited patterns (deprecated APIs, surface AST scaffolding) preserved without challenge? Under hybrid specifically: D-1C-5 (per-decrement perf regression) is the load-bearing perf gate — verify M7+M8+M13 stay within Pre-0 variance at 1V close.

### §11.3 Phase 1V exit criteria

- All 4 VAG questions pass under adversarial framing
- Probe diff = 0 semantically vs pre-Phase-1 baseline (S4 reference: 28 commands; Pre-0 plan §12.5 + S-tier baseline file)
- Full suite GREEN within 118-127s variance band (S1 reference: 119.288s)
- Parity tests GREEN (tropical-fuel-counter-parity reframed for hybrid per §10.6 + 1A-iii-b parity + 1A-iii-c parity)
- 1+ codifications graduated to DEVELOPMENT_LESSONS.org if patterns surfaced (capture-gap discipline at 5 data points already graduation-ready)
- Cross-reference capture in D.3 Phase 3 design verified (Form C scheduled)

**Pre-0 microbench claims verified at Phase 1V close — comprehensive list (D.3 R4 REFINEMENT)**:

Per microbench-claim verification rule ([`DEVELOPMENT_LESSONS.org § Microbench-Claim Verification Pays Off Across Sub-Phase Arcs`](principles/DEVELOPMENT_LESSONS.org)): every load-bearing Pre-0 finding requires re-microbench at Phase 1V close. **Total: 11 microbench re-runs**.

- **Per-decrement cycle preserved (3 re-runs)**: re-microbench M7 (struct-copy decrement) + M8 (inline check) + M13 (prop-network-fuel access). **Target**: per-decrement cycle (M7+M8+M13 sum) ≤ 5% regression vs Pre-0 baseline (~36 ns).
- **Phase 1B substrate baselines (4 re-runs; per §9.10 Phase 1B implementation checklist)**: M10 (residuation operator) + M11 (tropical tensor) + M12 (SRE registration overhead) + R4 (cell layout). **Target**: per Pre-0 plan §3 + §8 hypotheses at Phase 1B close.
- **High-frequency decrement at scale (3 re-runs; NEW per R4)**: re-microbench A7.1/A7.2/A7.3 (1k/10k/100k decrements). **Target**: 62.5 bytes/dec linear scaling preserved (per Pre-0 Finding 7); ZERO major-GC at 100k (per Pre-0 Finding 16 R3 baseline).
- **Speculation rollback no-leak (1 re-run; NEW per R4)**: re-microbench A9 (100 spec cycles save+write+restore). **Target**: ≤ 0 KB retention at 100 cycles (per Pre-0 Finding 8 baseline) + ≤ 30 KB at 1000 cycles (per Pre-0 Finding 17 R5 long-term residual bound).
- **Full-pipeline regression (2 re-runs; NEW per R4)**: re-microbench E7 (probe full file 28 expressions) + E8 (50-deep id composition; hybrid pivot CRITICAL scenario per Pre-0 Finding 13). **Target**: E7 wall ≤ +5% (≤ 351 ms) + memory ≤ +10% (≤ 894 MB); E8 wall ≤ +25% (per Pre-0 plan §7).

The list is comprehensive for the "did the perf claims land" verification. ~30-60 min total at Phase 1V close.

**Architectural + reconsideration gates (D.4 CANONICAL + Option 13 refinement)**:

- **Option 13 deferred-write performance gate**: per-cycle amortized cost (W3-O13 at typical N) ≤ 5 ns; per-fire local-var decrement (W1-O13) ≤ 5 ns; round-boundary flush (W2b-O13) ≤ 15 ns. Cross-reference §13.6.A spike target. **A/B/C comparison**: confirm C (Option 13) ≤ A (current struct-copy) at amortized per-cycle cost.
- **Option 13 architectural gate**: aggregate `prop_firings` post-impl shows on-write-check fires ONLY at round boundaries + exhaustion events (NOT per-fire) — verifies the deferred-write pattern actually defers. Suite-wide `prop_firings` delta from S-20 baseline should be small + bounded.
- **Cell observability gate**: probe + acceptance file workflows that read fuel-cost cell at consumer-fire boundaries see correct values (round-boundary granularity is sufficient for Phase 3C UC patterns).
- **Speculation correctness gate**: A9 microbench (100 spec cycles save+write+restore) shows correct rollback under deferred-write (local-var flushes before fork; sub-fork starts with current cell value).
- **Macro-specialization decision gate** (Option 14 from §10.3.A): measure deferred-write at production fire sites with/without macro-expansion; apply Option 14 if saves ≥ 1 ns/cycle.

> **D.3 hybrid pivot gates** (RETIRED-PER-D.4-CANONICAL): the previous "Hybrid pivot performance gate" / "architectural gate" / "reconsideration gate" tracked the hybrid pivot's behavior; under D.4 + Option 13, those gates are superseded by the gates above. Preserved here for traceability: the D.3 gates were `per-decrement cycle ≤ 5% regression`, `prop_firings ≤ 1× per file BSP-barrier-equivalent`, and `post-impl reconsider if cell-write ≤ 50% of struct-copy + R3 zero major-GC`.

---

## §12 Termination arguments

Per [GÖDEL_COMPLETENESS.org](principles/GÖDEL_COMPLETENESS.org). Each new/modified propagator + cell needs explicit termination argument.

| Component | Phase | Guarantee level | Measure |
|---|---|---|---|
| Tropical fuel cell merge (min) | 1B | Level 1 (Tarski) | Finite lattice bounded by budget; monotone min |
| Tropical fuel threshold propagator | 1B | Level 1 | Fires once at threshold; monotone cost accumulation |
| Tropical-left-residual operator | 1B | N/A (pure function) | Read-time computation |
| Canonical BSP fuel cell migration | 1C | Level 1 | Inherits tropical fuel termination; no new strata |
| ATMS deprecated API retirement | 1A-iii-b | N/A (deletion) | Pure deletion; no termination concern |
| Surface ATMS AST retirement | 1A-iii-c | N/A (deletion) | Pure deletion |

**No new strata added; no cross-stratum feedback; no well-founded measure beyond Tarski needed.**

BSP scheduler outer loop: Phase 1C makes the loop's termination structurally backed by the canonical tropical fuel cell. The cell's Tarski-fixpoint termination + threshold propagator's contradiction-on-exhaustion gives the BSP scheduler a structural termination guarantee, replacing the imperative `prop-network-fuel` decrementing counter.

---

## §13 Pre-0 benchmark plan

> **D.2 STATUS**: §13 is HISTORICAL — it sketched the Pre-0 plan at D.1 time. The comprehensive Pre-0 plan (38 tests across 8 tiers M/A/C/X/E/R/S/V; memory as first-class) lives in [`docs/tracking/2026-04-26_TROPICAL_ADDENDUM_PRE0_PLAN.md`](2026-04-26_TROPICAL_ADDENDUM_PRE0_PLAN.md) and executed to completion (M+A+E+R+S-tiers; 22 design-affecting findings; commits `f6576479` → `8a29f6af`). §13.5's predicted "If M8 shows threshold propagator overhead > 100% of inline check, reconsider threshold approach" came true at Pre-0 M-tier (Finding 2: inline 6 ns vs propagator 100-600 ns); D.2 §10 reframes Phase 1C with the hybrid pivot in response. The historical sketch below is preserved for traceability.

Per DESIGN_METHODOLOGY Stage 3 Pre-0 Benchmarks Per Semantic Axis. Extends existing `benchmarks/micro/bench-ppn-track4c.rkt` (295 lines, M1-M6 + A1-A4 + E1-E6 + V1-V3 tiers per file inspection).

### §13.1 New micros (M-tier extension)

**M7 — Tropical fuel merge (min) cost vs counter decrement**
- Setup: pre-allocated tropical fuel cell + pre-allocated counter (existing prop-network-fuel)
- Measure: `(net-cell-write net fuel-cid (+ cost n))` cost in ns/call
- Compare: `(struct-copy prop-net-cold ... [fuel (- fuel n)])` in ns/call
- Hypothesis: cell-write within 50% of struct-copy cost (acceptable; structural correctness justifies marginal cost)

**M8 — Threshold propagator firing cost vs `(<= fuel 0)` check**
- Setup: pre-allocated fuel + budget cells + threshold propagator installed
- Measure: per-write threshold check (propagator fires) cost
- Compare: `(<= (prop-network-fuel net) 0)` inline check cost
- Hypothesis: threshold propagator within 30% of inline check (single comparison + conditional write)

**M9 — Per-consumer fuel cell allocation cost (multi-consumer)**
- Setup: 1 cell vs 5 cells vs 50 cells per net
- Measure: `net-new-tropical-fuel-cell` allocation cost
- Hypothesis: O(1) per cell (cell-allocation is well-bounded)

### §13.2 New adversarial test (A-tier extension)

**A5 — Cost-bounded exploration vs flat fuel exhaustion (semantic axis)**
- Setup: workload with non-uniform per-step cost (some steps cost 1, others cost 100)
- Measure: tropical fuel exhaustion point matches budget exactly
- Compare: counter decrement exhaustion point (counter decrements by 1 regardless of step cost — semantic mismatch)
- Hypothesis: tropical fuel provides cost-aware exhaustion; counter only does step-count

### §13.3 Parity test (F-tier — new axis)

**F-tropical — Old counter vs new cell exhaustion equivalence (semantic parity)**
- Setup: 5+ representative workloads (typical elaboration, prelude load, deep type inference, etc.)
- Measure: exhaustion point under old counter (pre-1C) vs new cell (post-1C) for each workload
- Hypothesis: equivalent exhaustion points (within step-counting equivalence — old counter decrements 1/step; new cell accumulates step-cost which IS step-count if cost-per-step is 1)

### §13.4 Pre-0 execution plan

- Extend `bench-ppn-track4c.rkt` with M7-M9 + A5 + F-tropical sections (~80-120 LoC additions)
- Run pre-implementation baseline (current state, no tropical fuel cells)
- Establish predicted post-implementation deltas in this design (Phase 1V verifies actuals)
- Cost: ~15-30 min for benchmark execution; ~30-60 min for benchmark code addition

### §13.6 D.4 specialized cell-write spike plan (NEW)

**Purpose**: directly measure the cost of specialized cell-write (per §4.6 framework) against the existing struct-copy baseline. This is the FALSIFICATION TEST for the D.4 architectural pivot — if the spike passes, D.4 is canonical; if it fails, D.3 hybrid pivot remains.

**What was extrapolated** (per D.3.EC MG1 acknowledgment):
- Pre-0 R-19 inferred "full cell-migration would trigger major GC at 100k decrements" from struct-copy measurements
- The cell-write mechanism we'd ACTUALLY implement (specialized hot+monotone-counter cell with direct-fixnum storage under no-speculation) was NOT directly measured
- D.3 hybrid pivot rested on this extrapolation
- The D.4 framework changes the cell mechanism's dispatch — the extrapolation may not hold for the SPECIALIZED cell type

**Spike scope** (~30-60 min execution; minimal implementation):
1. **Mock the specialized cell mechanism** (`benchmarks/micro/bench-specialized-cell-spike.rkt`):
   - Implement a minimal direct-counter-cell storage (just enough to write/read a fixnum without `tagged-cell-value` wrapping)
   - Implement the on-write check predicate inline (no propagator-fire ceremony)
   - Skip the full cell-meta framework; hardcode the hot+monotone-counter dispatch
2. **Measure**:
   - **W1**: Specialized cell-write cost (no-speculation; no threshold crossing) — target ≤ 30 ns/call (within ~25% of struct-copy 24 ns)
   - **W2**: Specialized cell-write cost (threshold crossing detected; contradiction written) — rare; target ≤ 200 ns/call (allows for contradiction-write ceremony)
   - **W3**: Specialized cell-write GC profile at 100k decrements — target ZERO major-GC (matches R3 baseline)
   - **W4**: Specialized cell-read cost (direct-counter access) — target ≤ 15 ns/call (within ~50% of struct-field 6 ns; cell-API has indirection)
   - **W5**: Specialized cell-write under tagged-cell-value (speculation) — fallback path; measure as reference; target ≤ 600 ns/call (matches existing cell-write under speculation)
3. **Compare to Pre-0 baseline**:
   - Per-decrement cycle (W1 + W4): target ≤ 45 ns total (within ~25% of struct-copy + inline check ~30 ns)
   - GC profile (W3): target ZERO major-GC at 100k (matches R3)

**Decision criteria**:
- **PASS (D.4 canonical)**: W1 ≤ 30 ns + W3 = ZERO major-GC + W4 ≤ 15 ns + per-decrement cycle ≤ 45 ns. The specialized cell-write is within 25-50% of struct-copy cost AND GC-friendly.
- **FAIL (D.3 hybrid pivot remains)**: W1 > 60 ns OR W3 > 0 major-GC at 100k OR per-decrement cycle > 60 ns. The specialized cell-write doesn't close the gap; hybrid pivot's empirical motivation holds.
- **MIXED (re-design required)**: cell-write fast but GC pressured, or vice-versa. Investigate; may indicate the specialized-storage strategy needs further work (e.g., object pooling, different layout).

**Implementation cost for the spike itself**: ~100-200 LoC for the mock specialized cell mechanism. NOT the full Phase 1B framework — just enough to measure the core fast-path under realistic workload.

**Spike-vs-Phase-1B relationship**:
- The spike's mock is THROWAWAY (won't ship; spike-only code)
- Phase 1B implements the FULL framework (cell-meta fields, dispatch logic, registration API, tests) per §4.6
- If spike passes, Phase 1B builds the framework with confidence; if spike fails, hybrid pivot ships per D.3
- Spike runs at Phase 1B mini-design OPENING (per Q-1B-6, but spike scope is now D.4-specific, NOT generic cell-write)

**Updated Q-1B-6** (was: "generic cell-write empirical-validation spike"; now per D.4: "specialized cell-write spike per §13.6"):

Phase 1B mini-design opening runs the spike per §13.6. The spike result drives the architectural decision (D.4 canonical vs D.3 hybrid pivot retains). The spike is fast (~30-60 min) AND cheap (~100-200 LoC throwaway code).

**Risk register**:
- *R1*: Specialized storage strategy doesn't actually deliver fixnum-direct-mutation under Racket's runtime (e.g., the indirection through `net-cell-meta` lookup adds overhead). Mitigation: spike measures directly; if R1 materializes, investigate sub-options (struct-field on `prop-net-cold` for cell-id lookup; specialized cell registry separate from CHAMP).
- *R2*: Tagged-cell-value fallback adds significant overhead under speculation. Mitigation: per D.3.EC MG2, multi-worldview measurement is Phase 3A scope; for Phase 1B spike, no-speculation hot path is the target.
- *R3*: On-write predicate's allocation cost is higher than expected. Mitigation: spike measures with a representative predicate (`(>= cost budget)`); should be 0-allocation under fixnum comparison.
- *R4*: Fire-on-threshold-crossing notification mechanism has subtle bugs (e.g., misses crossing if multi-write batch). Mitigation: this is a correctness concern, not perf; tested via C-series + behavioral tests.

### §13.6.A Option 13 deferred-write spike plan + RESULTS (D.4 REFINEMENT 2026-05-15)

**Status (2026-05-15)**: ✓ PASS — Option 13 canonical for Phase 1C. Spike executed at session-tail of Phase 1B mini-design; results saved to `racket/prologos/data/benchmarks/tropical-spike-d4-option13-2026-05-15.txt`.

**Results vs targets**:

| Measurement | Target | Spike result | Margin |
|---|---|---|---|
| W1-O13a function-call per-fire | ≤ 5 ns | **2.2 ns/call** | ~2.3× under |
| W1-O13b macro-inline per-fire | ≤ 5 ns | **2.1 ns/call** | ~2.4× under |
| W2a-O13 round-entry cell-read | ≤ 15 ns | **1.3 ns/call** | ~11.5× under |
| W2b-O13 round-exit cell-write | ≤ 15 ns | **1.4 ns/call** | ~10.7× under |
| W3-O13a function-call amortized N=100 | ≤ 3 ns | **2.16 ns/cycle** | ~1.4× under |
| W3-O13b macro-inline amortized N=100 | ≤ 3 ns | **2.14 ns/cycle** | ~1.4× under |
| W4-O13 exhaustion flush + contradiction | ≤ 50 ns | **3.7 ns/call** | ~13.5× under |

**A/B/C comparison** (Option 13 vs alternatives):

| Variant | Per-cycle cost | vs Option 13 |
|---|---|---|
| A — Current native struct-copy (B.M7.2 in spike) | 5.2 ns/cycle | Option 13 is **2.4× faster** |
| B — D.4 per-fire cell-write w/ dispatch (W1+ from §13.6) | 6.6 ns/cycle | Option 13 is **3.1× faster** |
| **C-fn — Option 13 function-call (canonical)** | **2.16 ns/cycle** | — |
| C-macro — Option 13 + Option 14 macro | 2.14 ns/cycle | savings 0.02 ns/cycle vs C-fn |

**Option 14 specialization decision (per §10.4 1C-iv decision gate)**:
- Macro savings: 0.02 ns/cycle (essentially zero)
- Decision: **SKIP Option 14** — function-call variant achieves the perf target on its own; macro specialization adds complexity for negligible benefit. Per the decision rule "if savings ≥ 1 ns/cycle apply Option 14": savings 0.02 ns far below threshold; SKIP.

**Critical insight from spike**: Option 13 amortized cost (2.16 ns/cycle at N=100) is FASTER than:
- Current production native struct-copy (5.2 ns/cycle) — 2.4× faster
- D.4 per-fire pattern (6.6 ns/cycle) — 3.1× faster
- Spike's W1 specialized cell-write fast path (2.2 ns/cycle) — essentially equivalent

The deferred-write pattern doesn't just match native performance — it BEATS the native struct-copy baseline. The reason: the current struct-copy on `prop-network` (3 fields) + `prop-net-hot` (with fuel field) is more expensive than mutable-box decrement + occasional cell-flush. Option 13 is structurally faster.

**Purpose** (original): validate the Option 13 deferred-write pattern's ~2 ns/cycle amortized estimate before committing to the BSP fire-site migration at Phase 1C-ii. The §13.6 spike validated per-fire cell-write (6.4 ns/call with realistic dispatch); §13.6.A validates the scheduler-side deferred-write refinement (target: ~2 ns/cycle amortized). **Result**: target achieved with margin.

**Spike scope** (~30-40 min execution; extends `bench-specialized-cell-spike.rkt` OR a new sibling spike file):

1. **Mock the deferred-write pattern**:
   - Local-var box for fuel-cost counter (scheduler-internal scratch)
   - Per-fire: `(set-box! local-fuel-cost (+ 1 (unbox local-fuel-cost)))` + threshold check
   - Per-round-boundary: simulated `net-cell-write` to mock cell (use §13.6's specialized mock cell with `set-mutable-counter!`)
   - On-exhaustion: flush + contradiction (mock)

2. **Measure 4 dimensions (W1-O13 through W4-O13)**:
   - **W1-O13**: Per-fire local-var decrement + threshold check (no exhaustion) — target ≤ 5 ns/call (estimate: ~2 ns; the box + add + compare + branch)
   - **W2a-O13**: Per-round cell-read at entry — target ≤ 15 ns/call (just `net-cell-read` from spike's W4 baseline of 0.8 ns; expect slightly higher in production)
   - **W2b-O13**: Per-round cell-write at exit — target ≤ 15 ns/call (using §13.6's W1+ dispatch path of 6.4 ns + slight overhead for production)
   - **W3-O13**: Per-fire amortized cost across BSP round of N fires (N=10, 100, 1000) — at N=100 expect ~2.1 ns/cycle (W1-O13 + W2/N); at N=1000 expect ~2.01 ns/cycle
   - **W4-O13**: Exhaustion-path cost (flush + contradiction-write) — target ≤ 50 ns/call (rare; only once per workload typically)

3. **Compare A/B/C**:
   - **A**: spike's "B.M7.2 nested struct-copy" (5.7 ns from §13.6 spike; mirrors current implementation)
   - **B**: spike's "W1+ specialized cell-write with dispatch" (6.4 ns from §13.6 spike; per-fire pattern of D.4 original Option Y)
   - **C**: this spike's "W3-O13 amortized" (target ~2-2.1 ns at typical N; deferred-write pattern of Option 13)

**Decision criteria for §13.6.A spike**:
- **PASS**: W1-O13 ≤ 5 ns + W3-O13 ≤ 3 ns at N=100 + amortized comparable to or better than C above struct-copy baseline → Option 13 canonical for Phase 1C
- **FAIL**: W1-O13 > 10 ns OR amortized exceeds D.4 per-fire baseline → revert to D.4 per-fire pattern (Option Y; spike W1+ ≤ 30 ns target still satisfied)
- **MIXED**: per-fire fast but per-round overhead higher than expected; investigate (likely Q-1B-8 cell-meta storage representation differs from spike mock)

**Implementation cost for spike itself**: ~50-100 LoC extension to `bench-specialized-cell-spike.rkt`. NOT the full Phase 1C migration — just enough to validate the deferred-write pattern's measured performance characteristics.

**Spike-vs-Phase-1C relationship**:
- The spike's mock is THROWAWAY (won't ship; spike-only code)
- Phase 1C-ii implements the deferred-write pattern AT the 4 BSP fire sites for production
- If §13.6.A spike PASSES, Phase 1C builds the migration with confidence; if FAILS, fall back to D.4 per-fire pattern (already validated by §13.6 spike)

**Risk register**:
- *RO13-1*: Box mutation isn't actually ~2 ns under Racket's runtime (e.g., box-mutation has higher overhead than expected). Mitigation: spike measures directly; if RO13-1 materializes, consider unboxed-fixnum alternatives (e.g., mutable struct field on a scheduler-private struct).
- *RO13-2*: Amortization at low N (e.g., short BSP rounds with < 10 fires) doesn't deliver the expected savings. Mitigation: measure across N values; if low-N has poor amortization, Phase 1C-ii sub-phase can apply per-fire pattern for short-round workloads, deferred-write for long-round workloads (hybrid; opt-in per fire-site).
- *RO13-3*: Snapshot/restore at speculation forks doesn't compose cleanly with deferred-write. Mitigation: speculation flushes local-var before fork (validated via A9 microbench at Phase 1V).
- *RO13-4*: On-write check timing under deferred-write — for monotone counter, the check sees final value of round (correct semantics). Verify with behavioral tests; not a perf concern.

### §13.5 What Pre-0 might surface (potentially design-affecting)

- If M7 shows cell-write is significantly slower (>2x struct-copy), reconsider canonical instance approach — maybe per-consumer allocation only, with no canonical fuel cell
- If M8 shows threshold propagator overhead > 100% of inline check, reconsider threshold approach — maybe explicit check at decrement sites
- If M9 shows non-O(1) allocation, reconsider per-consumer allocation feasibility

These are unlikely (per S2 architectural pattern + BSP-LE 2B benchmarks showing cell ops are fast), but Pre-0 verifies before D.1 commits to specifics.

### §13.7 Per-Phase Measurement Plan (D.4 CANONICAL 2026-05-15)

> **Purpose**: validate D.4 design assumptions throughout Stage 4 implementation. The §13.6 + §13.6.A spikes establish the architectural feasibility; this section establishes the per-phase microbench gates that catch regressions or assumption-violations early, when they're cheap to address.
>
> **Discipline origin**: surfaced during Phase 1B mini-design when a friend's question about fuel-cell write semantics highlighted that the §13.6 spike's PASS verdict validated "D.4 is feasible at acceptable cost" but did NOT validate "D.4 is the optimal architecture for fuel-cost specifically." The architecturally-correct response is **explicit measurement gates at sub-phase boundaries** rather than relying on the post-implementation Phase 1V close to catch divergences.
>
> Aligns with `workflow.md` "Measure before, during, AND after — and include memory cost"; makes the discipline CONCRETE (named measurements, named targets, named decision rules) rather than implicit.

**A/B/C structure for fuel-cost write pattern** (the key architectural decision under Option 13):

| Variant | Pattern | Expected per-cycle cost | Validation source |
|---|---|---|---|
| **A** (baseline) | Current native struct-copy (`(struct-copy prop-net-hot ... [fuel ...])`) | ~24 ns (Pre-0 M7 measured) | Pre-0 baseline file 2026-04-26 |
| **B** (D.4 per-fire — NOT implemented; reference only) | `(net-cell-write net fuel-cost-cell-id ...)` per fire | ~6 ns (§13.6 W1+) | §13.6 spike (2026-05-14, commit `7b681b9e`) |
| **C** (D.4 + Option 13 deferred-write — production target) | Local-var per fire + cell-write at round boundary | ~2 ns/cycle amortized (estimated) | §13.6.A spike (Phase 1C-i; PENDING) |

**Per-sub-phase measurement gates (Phase 1B + 1C)**:

| Sub-phase | Measurements | Decision rule (PASS = continue; FAIL = stop & investigate) |
|---|---|---|
| **1B-i** (mini-audit) | Q-1B-8 cell-meta storage choice prototyped + measured (vector-indexed on prop-net-cold; CHAMP-keyed; struct field on prop-cell). Microbench: cell-meta lookup cost at production storage. | Storage choice ≤ 5 ns lookup overhead → PASS. > 10 ns → investigate alternative storage strategy. |
| **1B-ii** (framework module + dispatch) | **Primary (load-bearing per Q-1B-ii-δ)**: synthetic N=100 BSP round amortized per-cycle cost. **Secondary (informational)**: production W1+ at CHAMP-based storage (Q-1B-ii-β resolution). Memory: framework module load cost (M12-equivalent). | Primary: per-cycle amortized ≤ 3 ns at N=100 → PASS. Secondary: W1+ documented (~50-70 ns expected under CHAMP-based; absorbed by Option 13 amortization). Memory: framework module load < 1 ms, < 10 KB. **Note**: prior gate "W1+ ≤ 10 ns" assumed vector-indexed sidecar; revised per Option 13 + CHAMP-based architecture. |
| **1B-iii** (tropical fuel module) | C-series quantale axiom verification (§9.4); M10 residuation operator cost; M11 tensor cost; M12 SRE registration. | Quantale axioms hold → PASS. Any C-series failure → CRITICAL; halt before 1B-iv. M10 ≤ 30 ns; M11 ≤ 5 ns; M12 < 1 ms one-time. |
| **1B-iv** (cell registration + tests + close) | Full Phase 1B framework microbench: cell-write/read across all registered specialized cells. Test coverage: 12+ tests per §9.6. Probe: 28 commands unchanged (semantic parity per S4 baseline). | All targets within bounds → PASS. Probe semantic divergence → CRITICAL. Phase 1B closed. |
| **1C-i** (mini-audit) | **§13.6.A Option 13 spike executes here** (W1-O13 through W4-O13). | Spike PASS → continue with Option 13 pattern at 1C-ii. Spike FAIL → fall back to D.4 per-fire (Option Y; spike already validated at §13.6). Spike MIXED → re-design. |
| **1C-ii** (4 BSP fire sites migrate) | Re-microbench M7+M8+M13 at production BSP fire sites (now using deferred-write pattern). Compare to §13.6.A spike numbers + Pre-0 baseline. | Per-cycle ≤ §13.6.A target + 1 ns slack → PASS. Per-cycle > §13.6.A target by > 2 ns → investigate (production overhead vs spike mock). |
| **1C-iii** (11 check sites migrate) | Re-microbench check-site cost (now `net-contradiction?` call). Full suite parity (these sites widely distributed). | Per-check cost ≤ 10 ns + full suite GREEN → PASS. Suite regression > 5% → investigate. |
| **1C-iv** (macro + struct field retirement + Option 14 decision) | Measure deferred-write at production sites with/without macro-expansion specialization. | If macro saves ≥ 1 ns/cycle → apply Option 14 specialization. If saving < 0.5 ns/cycle → skip (YAGNI). |
| **1C-v** (test/bench migration) | Full suite GREEN; benchmark file replays match (A/B baseline data captured for Phase 1V close). | Suite GREEN; A/B baseline captured → PASS. Any test divergence → investigate (likely an `(prop-network-fuel result)` assertion that needs migration semantics review). |
| **1C-vi** (verification + close) | **Full A/B/C comparison report generated**. All 11 Phase 1V microbenches per §11.3 re-run. Probe semantic parity confirmed. | A/B/C report shows C ≤ A on per-cycle cost AND C achieves §13.6.A target → PASS. Any divergence → investigate before Phase 1V close. |

**§11.3 Phase 1V exit criteria — refined for Option 13**: see §11.3 (the existing 11-microbench list refined with Option 13-specific targets and A/B/C summary).

**Cross-track measurement integration**:

- **Bench infrastructure**: extends `racket/prologos/benchmarks/micro/bench-ppn-track4c.rkt` (existing W7-tier section) with Option 13 measurements (the existing bench file is the home; the spike file `bench-specialized-cell-spike.rkt` is throwaway). Per-phase measurements run via `racket tools/bench-ab.rkt --runs 10 ...` for statistical rigor.
- **A/B/C comparison tool**: `tools/bench-ab.rkt` currently supports A/B (`--ref HEAD~1`). For A/B/C: run 3 separate `bench-ab.rkt` invocations against tagged baseline commits (e.g., `--ref pre-1c-baseline` for A; current HEAD for B/C). Or extend `bench-ab.rkt` with `--refs` for multi-way comparison (Phase 1C-vi requirement; small tool enhancement).
- **Suite-level (S-tier)**: full suite wall-time recorded post-each-sub-phase per `tools/run-affected-tests.rkt`; expected variance within Pre-0 S1 baseline (119.3s ± 10%). Larger regressions investigated immediately, not deferred to Phase 1V.

**Honest framing of the measurement discipline**:

This per-phase plan adds measurement OVERHEAD to Stage 4 implementation — each sub-phase pause for microbench + A/B/C capture. Estimated cost: ~30-60 min per sub-phase boundary × ~6 sub-phases (1B-i through 1C-iv) = ~3-6 hours of measurement work across Phase 1B + 1C. Worth it because: (a) catches regressions when they're cheap to address (1 sub-phase ago, not at Phase 1V close); (b) validates the Option 13 ~2 ns/cycle estimate before committing; (c) generates A/B/C data that informs future tracks (PReduce, OE) about what's actually fast.

**Codification candidate (post-Phase-1V close)**:

"Per-phase measurement plan with A/B/C structure" pattern — when a design's correctness rests on assumptions about performance (e.g., "Option 13 achieves ~2 ns/cycle amortized"), the implementation plan should EXPLICITLY name the measurements that validate each assumption at each sub-phase boundary. This is stronger than the existing "per-phase microbench" discipline because it names CONCRETE comparisons (A/B/C) and DECISION RULES (PASS/FAIL/INVESTIGATE), rather than ad-hoc per-phase measurements. Watching list: 1 data point (this addendum); ~1-2 more for graduation.

---

## §14 P/R/M/S Self-Critique

Applied inline during decision-making; consolidated here per DESIGN_METHODOLOGY Stage 3 requirement. The S lens (Structural — SRE/PUnify/Hyperlattice+Hasse/Module-theoretic/Algebraic-structure-on-lattices) is **load-bearing for this addendum** per CRITIQUE_METHODOLOGY mandate.

### §14.1 P — Principles challenged

| Decision | Principle served | Adversarial challenge |
|---|---|---|
| γ-bundle-wide (all of Phase 1) | Completeness; Decomplection | Could Tier 3 (1A-iii-c) defer to its own design? **No** — bundling closes Phase 1 atomically per 1V; γ-bundle-wide IS the principled choice when wide scope is achievable. |
| Multi-quantale composition NTT (β) | First-Class by Default; Most Generalizable Interface | Could be deferred to single-quantale only? **No** — multi-quantale composition makes the residuation declaration load-bearing (Phase 3C UC1/UC2/UC3 grounded); single-quantale would be capture-gap risk. |
| Form A+B+cross-reference capture for Phase 3C | Capture-gap discipline; Decomplection | Form C in Phase 1B was scope creep? **Yes** — confirmed; Form C belongs in Phase 3C with cross-reference back. |
| Residuation operator as read-time helper | Decomplection (consumer flexibility) | Should it be a propagator? **No** for Phase 1B — wrapping is consumer's choice; primitive stays algebraically simple. |
| `+inf.0` as tropical-top | Pragmatism with rigor; Most Generalizable Interface | Sentinel symbol for SRE alignment? **Lean toward `+inf.0`** but defer to 1B mini-design with code in hand. |

**Red-flag scrutiny**: no "temporary bridge", "belt-and-suspenders", "pragmatic shortcut" in this addendum's architectural commitments. Phase-specific scope items (Q-1B-1, Q-1B-2, Q-1B-4, etc.) deferred to per-phase mini-design+audit per user's workflow — this IS principled deferral, not vagueness.

### §14.2 R — Reality check (code audit)

Per §2.2 audit findings:
- Q-Audit-1: 17 production refs in propagator.rkt + 1 typing-propagators + 1 pretty-print + 13 test refs + 2 bench refs (well-bounded)
- Q-Audit-2: 13 deprecated functions + struct + 14 surface AST structs + 14-file pipeline impact (substantial but bounded)
- Q-Audit-3: tropical-fuel.rkt clean slate + 5 anticipated consumer scaffolding sites grounding the substrate-level placement

Scope claims tied to grep-backed audit data; no speculation floats above the codebase.

### §14.3 M — Propagator mindspace

Design mantra check (§5) passed for all components. Key on-network properties:
- Tropical fuel cell: pure cell-based, merge via `min`, no hidden state
- Threshold propagator: fires once at threshold; monotone
- Multi-quantale composition: cells as Q-modules; bridges as Galois-connection propagators; quantale-of-bridges
- Residuation operator: read-time pure function (consumer-wrapped if propagator semantics needed)

No "scan" / "walk" / "iterate" in design. The "fuel exhaustion" check IS a threshold propagator firing on cell write — emergent from cell state, not imperative loop.

### §14.4 S — SRE Structural Thinking (load-bearing)

**SRE lattice lens (mandatory)** per CRITIQUE_METHODOLOGY.

**D.4 status (2026-05-14)**: §14.4 Q5's dual classification (D.1 full-migration vs D.2/D.3 hybrid pivot) was a D.3 reconciliation under hybrid. Under D.4 architectural reframing (per §4.6 + §10), the cell IS the live state and Q5 reverts to SINGLE classification (cell PRIMARY). Q3 + Q4 + Q6 hybrid clarifications retire. The dual-classification framing is preserved below for traceability with D.3.SC S1 BLOCKING resolution rationale; it becomes MOOT if §13.6 spike passes.

**D.3 status note (preserved)**: §14.4 Q5 was inconsistent with D.2 §10's hybrid pivot (Q5 declared cell PRIMARY under D.1's full-migration; hybrid inverts to struct-field PRIMARY, cell DERIVED). Q5 + dependent Qs (Q3, Q4, Q6) updated below to acknowledge dual classification (D.1 full-migration vs D.2/D.3 hybrid pivot).

| Aspect | Tropical fuel quantale (this addendum) |
|---|---|
| **Q1 Classification** | VALUE lattice (atomic extended-real) — UNCHANGED across D.1/D.2/D.3 |
| **Q2 Algebraic properties** | Quantale + Commutative + Unital + Integral + Residuated; Heyting-like (residuation provides pseudo-complement-like structure); join-semilattice (idempotent min); CALM-safe — UNCHANGED across D.1/D.2/D.3 |
| **Q3 Bridges** | Future Galois bridge to TypeFacetQ (§4.2 type-cost-bridge); future bridges to MemoryCostQ, MessageCountQ (out of scope); composition via quantale-of-bridges. **D.3 hybrid clarification**: under hybrid, the cell value at projection time is POSSIBLY-STALE relative to live struct-field state (per §10.B Cell Staleness Contract). The α projection must accept the staleness OR trigger sync first via `net-fuel-cost-read/synced`. The bridge's Galois property HOLDS under the staleness contract since the cell value at any sync point IS a valid lattice element of TropicalFuelQ — staleness is "behind in time," not "wrong in lattice." |
| **Q4 Composition** | Two quantales co-exist as Q-modules; CALM-safe under monotone joins; Tarski-fixpoint per Q-module. **D.3 hybrid clarification**: TropicalFuelQ Q-module's cell receives infrequent writes (only at semantic transitions per §10.B); the tagged-cell-value semantics under speculation worldviews still composes correctly (each worldview tag holds a single TropicalFuel value; min-merge is the lattice join). Tarski-fixpoint per Q-module preserved; reduced write rate doesn't change the algebraic correctness. |
| **Q5 Primary/Derived** | **Under D.1's full-migration design**: PRIMARY for fuel-cost tracking; cell is PRIMARY storage. **Under D.2/D.3 hybrid pivot**: struct-field `prop-net-cold-fuel` is PRIMARY (live state); cell is DERIVED (lazy sync at semantic transitions per §10.B Cell Staleness Contract + Q-1C-3 cadence enumeration). The classification inversion is empirically forced by Pre-0 Finding 19 (full-cell-migration triggers major GC under R3 baseline); under SH Series runtime, primary inverts back to cell. **This dual-classification IS the scaffolding-with-retirement-plan pattern at the structural-analysis level** (per workflow.md "Validated ≠ Deployed" + DEVELOPMENT_LESSONS.org "Pragmatic Is a Rationalization for Incomplete" — the deferral is principled when the blocker is named: Racket runtime GC behavior at per-decrement cell-write rate). |
| **Q6 Hasse diagram** | Linear chain `0 ≤_rev 1 ≤_rev 2 ≤_rev ... ≤_rev +∞` (totally ordered); compute topology: trivially parallel (no decomposition needed for atomic values). **D.3 hybrid clarification**: under hybrid, the cell visits a SUBSET of the linear chain (only semantic-transition values; per-decrement values are in the struct field, not the cell). The lattice ordering is preserved (subset of values still totally-ordered); the Hasse-based optimality argument unchanged (linear chain is trivially parallel regardless of which subset is visited). |

**PUnify**: tropical fuel is atomic; PUnify-style structural unification doesn't apply at the value level. PUnify within propagator computation (e.g., when residuation is wrapped in a Phase 3C propagator) follows the same patterns as type unification.

**Hyperlattice / Hasse**: linear chain Hasse → trivially parallel; no Gray code or hypercube optimizations apply (those are Boolean lattice patterns). Cost-bounded exploration (research §3.6) over multi-quantale composition might exhibit hypercube structure if multiple cost dimensions interact (out of scope).

**Module theoretic**: cells as Q-modules per §4.2; propagators as Q-module morphisms; quantale action of cost on state; cross-quantale Galois bridges via type-cost-bridge.

**Algebraic structure on lattices**: tropical quantale fully declared (Quantale + Integral + Residuated + Commutative); residuation formula `a \ b = b - a when b ≥ a, else 0` per research §9.3; backward error-explanation algebraically grounded (Phase 3C UC1).

---

## §15 Parity test skeleton (D.4 CANONICAL)

Per D.3 §9.1 convention, parity tests wire into `tests/test-elaboration-parity.rkt`. New axes for this addendum (D.4 canonical):

| Phase | Axis | Tests to enable |
|---|---|---|
| 1A-iii-b | atms-deprecated-api-parity | Behavior identical for non-ATMS-deprecated callers; deprecated callers either migrated or removed |
| 1A-iii-c | surface-atms-ast-elaboration-parity | Pre-retirement: surface forms parse + elaborate + reduce; post-retirement: surface forms produce parse error (correct behavior — no longer exist) |
| 1B | tropical-fuel-merge-parity | Merge semantics + on-write check behavior + residuation operator (Form A unit tests in `test-tropical-fuel.rkt`; integration-level parity in `test-elaboration-parity.rkt`) |
| 1B | **specialized-cell-semantics-parity (D.4 NEW)** | Cell-meta registration; fast-path dispatch under no-speculation (zero allocation per write); speculation fallback to `tagged-cell-value` (correctness preserved); on-write check inline-execution; fire-on-threshold-crossing notification (no spurious fires); cross-tier interaction. Wires into `test-specialized-cells.rkt` per §9.6 |
| 1C | tropical-fuel-counter-parity (D.4 reframed) | OLD counter exhaustion (struct-field-based) vs NEW cell exhaustion (on-write predicate at cell layer) at equivalent points for representative workloads. The cell value AT exhaustion equals the budget; the on-write predicate fires when `(>= new-cost budget)`. Per F-tropical in §13.3. |
| 1C | **direct-migration-parity (D.4 NEW)** | Pre-migration test assertions (`(prop-network-fuel result)`) vs post-migration (`(net-cell-read result fuel-cost-cell-id)`) produce equivalent values for representative workloads. Verifies the mechanical batch migration (per §10.4 sub-phase 1C-v) preserves observable behavior across all 13 test sites. |

> **D.3 (historical) — staleness-contract-tests axis RETIRED**: under D.3 hybrid pivot, §15 included a `cell-staleness-contract-parity` axis testing the dual-API discipline (`net-fuel-cost-read` vs `net-fuel-cost-read/synced`). Under D.4, the cell IS the live state; no staleness; no dual-API; the axis is structurally moot.

---

## §16 Open questions — phase-specific deferred to per-phase mini-design+audit

Per user's workflow direction (2026-04-26): "if there are any remaining open questions that affect the overall addendum design, we should iterate through those; otherwise, we should place the open questions on the phases they touch, and work through them as per-phase mini-design+audit prior to their implementation."

### §16.1 Phase 1A-iii-b (Tier 2 ATMS internal retirement)
- Q-1A-iii-b-1: Test migration vs deletion criteria (D-b-2 + §7.6)
- Q-1A-iii-b-2: pretty-print.rkt `atms?` removal — surface dead code or active state? (D-b-3 + §7.6)

### §16.2 Phase 1A-iii-c (Tier 3 surface ATMS AST retirement)
- Q-1A-iii-c-1: trace-serialize.rkt atms-event:* — retire or preserve for solver-state? (D-c-4 + §8.6)
- Q-1A-iii-c-2: examples/ files using surface ATMS — migrate or delete? (D-c-3 + §8.6)
- Q-1A-iii-c-3: lib/ files using surface ATMS — extent of migration impact (D-c-2 + §8.6)

### §16.3 Phase 1B (tropical fuel primitive)
- Q-1B-1: API naming (lean: `tropical-fuel-merge`/`tropical-fuel-tensor`/`tropical-left-residual`)
- Q-1B-2: `+inf.0` Racket float-infinity vs sentinel `'tropical-top` (lean: `+inf.0`)
- Q-1B-4: Residuation operator implementation — read-time helper vs propagator (lean: read-time helper)

### §16.4 Phase 1C (canonical BSP fuel substrate — hybrid pivot per D.2)
- Q-1C-1 (CARRIED): typing-propagators.rkt:2269 saved-fuel rollback semantics (D-1C-2)
- Q-1C-2 (CARRIED, REFRAMED): test cell-mediated API additions (Phase 3C UC forward-capture)
- **Q-1C-3 (NEW per D.2)**: cell-update cadence — semantic-transition enumeration (start of phase / end of phase / save-restore / Phase 3C UC query sites / on-exhaustion); lean toward semantic-transition-only sync (cell stale between transitions; consumers must accept or trigger sync); resolve at 1C-iii mini-design with code in hand

### §16.5 Cross-cutting (D.1 close + D.2 commits)
- Q-Open-2 ✅ RESOLVED at D.1: A+B+cross-reference capture per §6.5
- Q-Open-3 ✅ RESOLVED at D.1: (β) multi-quantale composition NTT in this addendum per §4.2
- Q-Open-4 ✅ RESOLVED at D.1: γ strict sequencing per pipeline.md template
- Q-A3 ✅ RESOLVED at D.1: γ-bundle-wide per §6.3
- Q-A5 ✅ RESOLVED at D.1: atms-believed retires with struct in 1A-iii-b per §6.4
- Q-1B-3 ✅ RESOLVED at D.1: cell-id 11/12 placement; co-existence as independent Q-modules per §4.3
- Q-1B-5 ✅ RESOLVED at D.1: NTT model completion via quantale-of-bridges per §4.2
- **Q-Hybrid-Pivot ✅ COMMITTED at D.2 → RETIRED at D.4**: Phase 1C was reframed to hybrid architecture at D.2 (commits `2a4d938c` etc.); under D.4 architectural reframing + §13.6 spike PASS (commit `7b681b9e`), the hybrid pivot SCAFFOLDING retires before shipping. Phase 1C is direct migration per §10 D.4 canonical content; the D.3 hybrid pivot empirical rationale (R-19 extrapolation) is falsified for the specialized cell type framework.
- **Q-D.4-CANONICAL ✅ RESOLVED at §13.6 spike**: Specialized cell type framework (§4.6) is canonical; D.3 hybrid pivot scaffolding retires; Issue #55 + DEFERRED.md entry close as "superseded by D.4" (governance surfaces — to be updated in Chunk 2 follow-up commit).

**No remaining cross-cutting open questions blocking D.4 CANONICAL close.** Stage 4 implementation opens next per per-phase mini-design+audit.

---

## §17 What's next (D.4 CANONICAL)

Per user's workflow (updated post-§13.6 spike 2026-05-14):
1. ✅ **D.1 draft complete** (commit `fc4b9d3e`)
2. ✅ **Pre-0 microbenchmark plan + execution** — 8 commits; 22 cumulative design-affecting findings
3. ✅ **D.2 revise** (commit `2a4d938c`) — Pre-0 findings incorporated; hybrid pivot architecture committed for Phase 1C
4. ✅ **D.2.SC self-critique** (commit `219d8eb9`) — 18 findings; D.3 incorporated all
5. ✅ **D.3 revisions** — 10 commits closing all D.2.SC findings (commit `76a73ada` complete)
6. ✅ **D.3.EC external critique** (commit `61d7ab07`) — 11 findings; resolution review surfaced architectural concern
7. ✅ **D.4 architectural reframing** (commit `6a628bc7`) — Cell/Propagator/Scheduler Orthogonality principle codified
8. ✅ **D.4 scaffolding pass** (commit `45181c07`) — §4.6 specialized cell type framework NTT + §13.6 Pre-0 spike plan + supersession notes
9. ✅ **§13.6 Pre-0 spike — ✓ PASS** (commit `7b681b9e`) — W1+ = 6.4 ns/call (with realistic dispatch); zero major-GC at 100k decrements; ~4× under all targets. **D.4 canonical**; D.3 hybrid pivot SCAFFOLDING never shipped.
10. ✅ **D.4 CANONICAL Chunk 1** (commit `ae057b3a`) — §9 + §10 + §15 full content; D.3 historical sections RETIRED-PER-D.4-CANONICAL
11. ✅ **D.4 CANONICAL Chunk 2** (commit `bb503255`) — Issue #55 CLOSED + DEFERRED.md RETIRED + MASTER_ROADMAP.org refined
12. ✅ **D.4 REFINEMENT Option 13 + §13.7 measurement discipline** (commit `8aa4c907`) — Option 13 deferred-write pattern captured; §13.6.A spike plan + §13.7 Per-Phase Measurement Plan; scheduler-state cell category confirmed in DESIGN_PRINCIPLES.org
13. ✅ **§13.6.A Option 13 spike — ✓ PASS (THIS commit)** — measured 2.16 ns/cycle amortized at N=100; **2.4× faster than native struct-copy + 3.1× faster than D.4 per-fire**. Option 14 macro specialization SKIPPED (savings 0.02 ns/cycle).
14. ⬜ **Stage 4 implementation** — per-phase mini-design+audit with §13.7 measurement gates at each sub-phase boundary. Phase 1B substrate first per Q-Open-4 strict sequencing; Phase 1C migrates BSP fire sites to Option 13 deferred-write pattern.
    - **Phase 1B** (~400-700 LoC): tropical-fuel.rkt module + specialized-cells.rkt framework + fuel-cost cell registration + tests (~4 sub-phases)
    - **Phase 1A-iii-b** (~250-400 LoC deletion): Tier 2 deprecated ATMS internal API retirement (~5 sub-phases)
    - **Phase 1A-iii-c** (~600-1000 LoC deletion): Tier 3 surface ATMS AST 14-file pipeline retirement (~8 sub-phases)
    - **Phase 1C** (~150-250 LoC): direct migration of decrement+check sites (~6 sub-phases per §10.4)
    - **Phase 1V** (atomic close): adversarial TWO-COLUMN VAG closes Phase 1 entirely

**D.4 adversarial questions for Stage 4 mini-design opening** (forward-capture):
- Does the production implementation of the specialized cell framework match the spike's measured performance? The spike used a vector-ref mock for cell-meta lookup; production may use struct field on `prop-net-warm` or a similar fast-path structure. Re-microbench at Phase 1B close to verify (per microbench-claim verification rule).
- Is the `:on-write-check` predicate at the cell layer ACTUALLY structural-not-imperative? It runs INLINE during write; that's deterministic + scheduler-agnostic, which is structural. But it's IMPERATIVE in the sense that the writer triggers the check rather than emergent from cell state changes. Honest framing: "cell-level reactive dispatch" — structural at the type/dispatch level; imperative at the per-write level. The boundary is at the cell mechanism, not the network mantra.
- Under speculation worldview, does the fast path correctly fall through to `tagged-cell-value`? Verify with C-series + behavioral tests at Phase 1B close. Multi-worldview measurement is Phase 3A scope per D.3.EC MG2.
- Does the fire-on-threshold-crossing notification mechanism miss crossings under any code path (e.g., multi-write batches within one BSP round)? Behavioral tests at Phase 1B; the predicate runs per-write so single-write atomicity guarantees correct detection — multi-write batching only happens within a single propagator's body where writes are sequenced.
- Future PReduce + OE inheritance: does the §4.6 framework actually generalize, or is it fuel-cell-specific? Phase 1B mini-design includes a sketch of PReduce e-graph cost extraction against the framework (~30 min; not implementation).

**Mempalace + dailies discipline**: D.4 CANONICAL is the principled outcome of the spike falsification test. Dailies entry for the spike at commit `7b681b9e`; this revision commit will append a "D.4 canonical revisions Chunk 1" entry. Mempalace re-mine triggers post-commit per Phase 3 hook.

---

## §18 References

### §18.1 Stage 1/2 artifacts (this track)
- [`docs/research/2026-04-21_TROPICAL_QUANTALE_RESEARCH.md`](../research/2026-04-21_TROPICAL_QUANTALE_RESEARCH.md)
- This session 2026-04-26 audit findings (Q-Audit-1/2/3) at §2.2

### §18.2 Parent and adjacent design docs
- **[`docs/tracking/2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_SELF_CRITIQUE.md`](2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_SELF_CRITIQUE.md) — D.2.SC (P/R/M/S self-critique; 18 findings; 3 BLOCKING + 10 REFINEMENTS + 5 ACKNOWLEDGEs)** — RESOLUTION COMPLETE (18/18 closed; D.3 incorporated)
- **[`docs/tracking/2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_EXTERNAL_CRITIQUE.md`](2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_EXTERNAL_CRITIQUE.md) — D.3.EC (external critique; 11 findings via CL/MG/SP/OS/TD/AP/TS/EX/MB lenses)** — pending resolution review with user; D.4 incorporates accepted findings
- [`docs/tracking/2026-04-21_PPN_4C_PHASE_9_DESIGN.md`](2026-04-21_PPN_4C_PHASE_9_DESIGN.md) — D.3 (parent addendum; refined by this doc per Q-Open-1)
- [`docs/tracking/2026-04-17_PPN_TRACK4C_DESIGN.md`](2026-04-17_PPN_TRACK4C_DESIGN.md) — PPN 4C parent track
- [`docs/tracking/2026-03-22_NTT_SYNTAX_DESIGN.md`](2026-03-22_NTT_SYNTAX_DESIGN.md) — NTT syntax reference for §4
- [`docs/research/2026-03-28_MODULE_THEORY_LATTICES.md`](../research/2026-03-28_MODULE_THEORY_LATTICES.md) — Q-modules + residuation
- [`docs/research/2026-03-24_TROPICAL_OPTIMIZATION_NETWORK_ARCHITECTURE.md`](../research/2026-03-24_TROPICAL_OPTIMIZATION_NETWORK_ARCHITECTURE.md) — earlier framing
- [`docs/research/2026-03-28_ALGEBRAIC_EMBEDDINGS_LATTICES.md`](../research/2026-03-28_ALGEBRAIC_EMBEDDINGS_LATTICES.md) — quantales for resources
- [`docs/research/2026-03-22_STRUCTURAL_REASONING_ENGINE.md`](../research/2026-03-22_STRUCTURAL_REASONING_ENGINE.md) — SRE foundations
- [`docs/tracking/2026-04-23_STEP2_BASELINE.md`](2026-04-23_STEP2_BASELINE.md) — measurement discipline + microbench claim verification rule

### §18.3 Cross-references for downstream consumers
- D.3 §6.10 + §9 (Phase 3 union types via ATMS + residuation error explanation) — Phase 3C consumer of tropical residuation operator (Form C cross-reference per §6.5)
- [`docs/research/2026-04-22_ATTRIBUTE_GRAMMAR_UNIFICATION_VISION.md`](../research/2026-04-22_ATTRIBUTE_GRAMMAR_UNIFICATION_VISION.md) — Track 4D vision
- [`docs/tracking/MASTER_ROADMAP.org`](MASTER_ROADMAP.org) § OE Series — first production landing

### §18.4 Methodology and rules
- [`docs/tracking/principles/DESIGN_METHODOLOGY.org`](principles/DESIGN_METHODOLOGY.org) Stage 3 (incl. Lens S)
- [`docs/tracking/principles/DESIGN_PRINCIPLES.org`](principles/DESIGN_PRINCIPLES.org) — Hyperlattice Conjecture; Correct-by-Construction
- [`docs/tracking/principles/CRITIQUE_METHODOLOGY.org`](principles/CRITIQUE_METHODOLOGY.org) — SRE Lattice Lens; adversarial framing
- [`docs/tracking/principles/DEVELOPMENT_LESSONS.org`](principles/DEVELOPMENT_LESSONS.org) — 6 codifications graduated 2026-04-25 (apply prophylactically)
- [`.claude/rules/on-network.md`](../../.claude/rules/on-network.md), [`propagator-design.md`](../../.claude/rules/propagator-design.md), [`structural-thinking.md`](../../.claude/rules/structural-thinking.md), [`pipeline.md`](../../.claude/rules/pipeline.md), [`workflow.md`](../../.claude/rules/workflow.md)

### §18.5 Code references (verified at this session 2026-04-26)
- [`racket/prologos/propagator.rkt`](../../racket/prologos/propagator.rkt) — `make-prop-network` line 81; `prop-net-cold` struct line 337; `prop-network-fuel` macro line 399; 17 production refs per Q-Audit-1
- [`racket/prologos/atms.rkt`](../../racket/prologos/atms.rkt) — 13 deprecated functions lines 213-251+; struct + atms-believed line 159+; provides lines 41-61
- [`racket/prologos/syntax.rkt`](../../racket/prologos/syntax.rkt) — 14 surface ATMS AST structs lines 202-208 + 750-767
- [`racket/prologos/sre-core.rkt`](../../racket/prologos/sre-core.rkt) + [`merge-fn-registry.rkt`](../../racket/prologos/merge-fn-registry.rkt) — SRE registration patterns
- [`racket/prologos/benchmarks/micro/bench-ppn-track4c.rkt`](../../racket/prologos/benchmarks/micro/bench-ppn-track4c.rkt) — 295 lines; M1-M6 + A1-A4 + E1-E6 + V1-V3 tiers; M7-M9 + A5 + F-tropical extensions per §13

---

## Document status

**Stage 3 Design D.4 CANONICAL** — Cell/Propagator/Scheduler Orthogonality principle applied; specialized cell type framework canonical; §13.6 Pre-0 spike PASSED (commit `7b681b9e`, 2026-05-14: W1+ 6.4 ns/call, W3 ZERO major-GC, ~4× under all targets); D.3 hybrid pivot SCAFFOLDING retires before shipping.

**Design trajectory** (D.1 → D.2 → D.2.SC → D.3 → D.3.EC → D.4 → §13.6 spike → D.4 CANONICAL):
1. ✅ D.1 drafted (commit `fc4b9d3e`)
2. ✅ Pre-0 microbenchmark plan + execution (M+A+E+R+S-tiers; 22 design-affecting findings)
3. ✅ D.2 revise (commit `2a4d938c`) — hybrid pivot architecture committed
4. ✅ D.2.SC self-critique (commit `219d8eb9`) — 18 findings via P/R/M/S
5. ✅ D.3 revisions (10 commits through `76a73ada`) — all 18 D.2.SC findings closed
6. ✅ D.3.EC external critique (commit `61d7ab07`) — 11 findings via fresh lenses (CL/MG/SP/OS/TD/AP/TS/EX/MB)
7. ✅ **D.4 architectural reframing — orthogonality principle codified** (commit `6a628bc7`)
8. ✅ **D.4 scaffolding pass** (commit `45181c07`) — §4.6 specialized cell type framework NTT model; §13.6 Pre-0 spike plan; §10 + §14.4 reframed; §10.1.A + §10.A + §10.B marked SUPERSEDED
9. ✅ **§13.6 Pre-0 spike — ✓ PASS** (commit `7b681b9e`) — W1+ = 6.4 ns/call (with realistic dispatch); zero major-GC at 100k decrements; ~4× under all targets. **D.4 canonical**.
10. ✅ **D.4 CANONICAL Chunk 1** (commit `ae057b3a`) — §9 + §10 + §15 full content; D.3 historical sections RETIRED-PER-D.4-CANONICAL
11. ✅ **D.4 CANONICAL Chunk 2** (commit `bb503255`) — Issue #55 CLOSED + DEFERRED.md RETIRED + MASTER_ROADMAP.org refined; all four D.3 hybrid pivot tracking surfaces now consistent
12. ✅ **D.4 REFINEMENT Option 13 + measurement discipline** (commit `8aa4c907`) — §10.3.A deferred-write pattern; §13.6.A spike plan; §13.7 Per-Phase Measurement Plan; refined §11.3 + §10.4; scheduler-state cell category confirmed in DESIGN_PRINCIPLES.org
13. ✅ **§13.6.A Option 13 spike — ✓ PASS (THIS commit)** — measured 2.16 ns/cycle at N=100 (2.4× faster than native struct-copy; 3.1× faster than D.4 per-fire); Option 14 macro specialization SKIPPED
14. ⬜ Stage 4 implementation per per-phase mini-design+audit with §13.7 gates

**Sub-phase mini-design+audit happens BEFORE each phase's implementation per Stage 4 Per-Phase Protocol.**

**The architectural foundation under D.4 CANONICAL**: tropical quantale as the substrate for OE Series Track 0/1/2 first production landing + future PReduce + future cost-guided search; **specialized cell type framework (§4.6) inherited by future tracks** (PReduce e-graph cost extraction, OE weighted parsing). The framework is PRINCIPLED on-network optimization; future tracks target it from the start (not the hybrid scaffolding pattern, which never shipped).

**The D.4 CANONICAL rationale (per Cell/Propagator/Scheduler Orthogonality + §13.6 spike validation)**:
- D.4 specializes the CELL mechanism (not the SCHEDULER) — optimization at the proper architectural layer
- §13.6 spike measured the specialized cell-write directly: 6.4 ns/call with realistic dispatch overhead — well within the ≤ 30 ns target
- W3 zero-GC at 100k decrements is STRUCTURALLY guaranteed (direct fixnum mutation allocates zero per write)
- Result: cell IS live state; portable across schedulers (Gauss-Seidel, BSP, Zig-LLVM, future); no scaffolding maintenance debt; framework reusable by PReduce + OE Series

**Discipline codified by this session arc**: never extrapolate a principle-violating commit when the alternative can be directly measured. The §13.6 spike took ~30 min to implement + run; it decisively resolved the architecture choice. This pattern (D.X commits a principle-violating architecture on extrapolated measurement → D.X+1 includes a falsification test that DIRECTLY measures the alternative before locking in) is a strong codification candidate after this 1 data point; promote to canonical after 1 more future instance.
