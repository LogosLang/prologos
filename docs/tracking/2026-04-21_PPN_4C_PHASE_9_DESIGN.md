# PPN Track 4C Addendum: Substrate + Orchestration Unification (Phases 1-3) — Design

**Date**: 2026-04-21
**Stage**: 3 — Design per [DESIGN_METHODOLOGY.org](principles/DESIGN_METHODOLOGY.org) Stage 3
**Version**: D.3 — scope revision from D.2 per Phase 1A mini-design audit 2026-04-21
**Scope**: PPN 4C Phase 9+10+11 combined addendum (renumbered to Phase 1, 2, 3 for this addendum)

**D.2 → D.3 changes** (applied 2026-04-21, per Phase 1A mini-design audit finding):
- Phase 1A scope revised based on mini-audit finding: `current-speculation-stack` is MORE alive than the Stage 2 audit indicated. Key discoveries:
  * `wrap-with-assumption` (correct name; audit's "wrap-with-assumption-stack" was a typo) has ZERO production callers — dead code
  * `promote-cell-to-tms` has ZERO production callers — dead code
  * `net-new-tms-cell` has 4 PRODUCTION callers in `elaborator-network.rkt` (type cells, mult cells, meta-solution cells) — these create TMS-wrapped cells that route through the fallback path
  * Retiring `current-speculation-stack` therefore requires retiring the TMS-cell mechanism it serves, which means migrating these 4 elaborator-network.rkt sites to tagged-cell-value-based cells
- Phase 1A now sub-split into 1A-i, 1A-ii, 1A-iii (see §7.3, §7.4, §7.5)
- Phase 1 total LoC estimate revised upward: ~530-850 (was ~350-550) because Phase 1A grew from ~100-150 to ~280-450
- Track total LoC estimate revised: ~830-1450 (was ~650-1150)
- BSP-LE Track 2 PIR's "RETIRED" claim on `current-speculation-stack` is now contextualized: it retired the SPECULATION uses via `with-speculative-rollback`, NOT the TMS-cell-mechanism uses via `net-new-tms-cell`. This addendum track completes the retirement.

**D.1 → D.2 changes** (applied 2026-04-21):
- Added Phase 10 to explicit scope (D.1 mentioned only 9 and 11)
- Moved Progress Tracker from §16 to §3 (immediately after research/audit references), per new methodology discipline
- Removed pre-committed resolutions for Q-A3, Q-A4, Q-A5, Q-A6 from §6 — these become phase-time mini-design items (§16)
- NTT syntax cross-referenced against [`2026-03-22_NTT_SYNTAX_DESIGN.md`](2026-03-22_NTT_SYNTAX_DESIGN.md): §4 updated — `:preserves [Quantale]` removed from lattice declarations (NTT's `:preserves` is for BRIDGES per NTT §6, not lattices); quantale properties declared via `trait Quantale` instance per NTT §3.1; `:fires-once-at-threshold` flagged as sketch-extension
- Phase 0 acceptance file requirement removed — PPN 4C's existing acceptance file (`examples/2026-04-17-ppn-track4c.prologos`) serves this track
- All subsequent section numbers shifted by +1 (§3→§4, §4→§5, ..., §15→§16); old §16 Progress Tracker deleted; §17 References unchanged after cascade

**Prior stages**:
- Stage 1 (research): [`docs/research/2026-04-21_TROPICAL_QUANTALE_RESEARCH.md`](../research/2026-04-21_TROPICAL_QUANTALE_RESEARCH.md) (commit `de357aa1`)
- Stage 2 (audit): [`docs/tracking/2026-04-21_PPN_4C_PHASE_9_AUDIT.md`](2026-04-21_PPN_4C_PHASE_9_AUDIT.md) (commits `62ce9f83`, `28208613`)

**Parent design**: [PPN 4C D.3](2026-04-17_PPN_TRACK4C_DESIGN.md). This addendum refines Phase 9+10+11 as a coherent sub-track; D.3 §6.7 (Phase 11), §6.10 (Phase 9+10 including union types via ATMS), §6.11.3 (hypercube), §6.15.6 (Phase 3+9 joint item) are superseded by this document for implementation planning. D.3's Progress Tracker Phase 9, Phase 10, and Phase 11 rows all point here (all three absorb into the Phase 1/2/3 structure of this addendum).

---

## §1 Thesis and scope

### §1.1 Addendum thesis

PPN 4C's charter (D.3 §1) is to bring elaboration completely on-network. Phase 9+10+11 is the **substrate and orchestration unification chapter** of that charter. Three architectural moves, all instances of the same pattern ("unify the mechanisms"):

1. **Substrate**: retire legacy speculation-stack + migrate fuel-counter to tropical-quantale primitive, leaving one substrate story (bitmask worldview cell + per-propagator override + tropical fuel primitive)
2. **Orchestration**: retire the sequential `run-stratified-resolution-pure` in favor of BSP scheduler's uniform stratum iteration via `register-stratum-handler!`
3. **Features**: ship union types via ATMS branching (D.3 §6.10) atop the unified substrate + orchestration, exploiting already-implemented hypercube primitives (Gray code, Hamming, subcube-member?, tree-reduce)

### §1.2 Phase scope

**Phase 1 — Substrate reconciliation + tropical fuel primitive** (~530-850 LoC, revised per Phase 1A mini-audit)
- Retire `wrap-with-assumption` (dead) + `promote-cell-to-tms` (dead)
- Migrate 4 `net-new-tms-cell` sites in `elaborator-network.rkt` to tagged-cell-value-based cells
- Retire `net-new-tms-cell` factory + `tms-cell-value` struct + `tms-read`/`tms-write` (as their sole consumer goes away)
- Retire `current-speculation-stack` parameter + 3 fallback sites in propagator.rkt
- Ship tropical fuel primitive (SRE domain + primitive API) per Q-A2 resolution
- Migrate `prop-network-fuel` field + 15+ decrement/check sites to canonical tropical fuel cell via the primitive

**Phase 2 — Orchestration unification** (~150-250 LoC)
- Register S(-1) retraction, L1 readiness, L2 resolution as BSP stratum handlers
- Retire `run-stratified-resolution-pure` (primary) + delete dead `run-stratified-resolution!`

**Phase 3 — Union types via ATMS + hypercube integration** (~200-400 LoC)
- Fork-on-union branching (following S1 NAF handler precedent)
- Tagged branches with S(-1) retract on contradiction
- Wire already-implemented Gray code into branch traversal
- Wire subcube pruning into contradiction propagation
- Residuation-based error-explanation for all-branch-contradict

**Total estimate**: 830-1450 LoC across 3 phases + their sub-phases (revised D.3 per Phase 1A mini-audit scope finding).

### §1.3 Out of scope (explicit deferrals)

- **Phase-specific scope questions**: ATMS retirement scope (Q-A3), `elab-speculation.rkt` disposition (Q-A4), `atms-believed` retirement timing (Q-A5), residuation error-explanation placement (Q-A6). These emerge at phase mini-design time (§16), not in this design document.
- **Phase 9b γ hole-fill propagator**: downstream consumer; interface specified here (§15), detailed design in Phase 9b's own cycle.
- **PReduce cost-guided rewriting**: future consumer of the tropical fuel primitive.
- **Self-hosted language-level surface for tropical quantale** (Polynomial Lawvere Logic, Rational Lawvere Logic per research §4.4): infrastructure-only in this track.
- **General residual solver** (BSP-LE Track 6 forward reference): Phase 9+10+11 consumes BSP-LE 2B substrate without coupling to relational layer.

### §1.4 Relationship to PPN 4C D.3

This document is an addendum to D.3, not a replacement. D.3's Progress Tracker continues to own track-level state; the Phase 9, Phase 10, and Phase 11 rows all point to this document (all three absorb into the Phase 1/2/3 structure here). D.3 §6.10 (Phase 9 + Phase 10 design text), §6.11.3 (hypercube), §6.15.6 (Phase 3+9 joint item), and §6.7 (Phase 11) are SUPERSEDED by this document for implementation planning — but retain their conceptual framing as research inputs.

---

## §2 Research and audit inputs

### §2.1 Stage 1 research
[`docs/research/2026-04-21_TROPICAL_QUANTALE_RESEARCH.md`](../research/2026-04-21_TROPICAL_QUANTALE_RESEARCH.md) — tropical quantale algebraic foundations + Prologos-specific synthesis. 12 sections; ~1000 lines. Key inputs: §6 (quantale modules), §9 (tropical quantale definition), §10 (Prologos synthesis).

### §2.2 Stage 2 audit
[`docs/tracking/2026-04-21_PPN_4C_PHASE_9_AUDIT.md`](2026-04-21_PPN_4C_PHASE_9_AUDIT.md) — grep-backed survey of 8+1 targets. Key inputs: §3 (state of the art), §4 (reconciliation plan), §5 (partitioning), §3.9 (Phase 11 state), §8 (revised work-volume estimates).

### §2.3 Prior art
- BSP-LE Track 2+2B — bitmask worldview, tagged-cell-value, hypercube primitives (Gray code, Hamming, subcube), tree-reduce
- Cell-based TMS design note (2026-04-06) — informed Phase 1 substrate reconciliation
- Hypercube addendum (2026-04-08) — Gray code, bitmask subcube, hypercube all-reduce
- Module Theory research (2026-03-28) — quantale modules, backward residuation
- Phase 3c shipped (2026-04-20) — demonstrates stratum-request + stratum-handler pattern for cross-tag residuation; Phase 1 uses similar pattern for tropical fuel threshold
- NTT Syntax Design (2026-03-22) — NTT forms referenced in §4 of this design

---

## §3 Progress Tracker

Per DESIGN_METHODOLOGY Stage 3 "Progress Tracker Placement" discipline — placed near top as the single source of truth for implementation state.

| Phase | Description | Status | Notes |
|---|---|---|---|
| Stage 1 | Research doc (tropical quantale) | ✅ | commit `de357aa1` |
| Stage 2 | Audit doc | ✅ | commits `62ce9f83`, `28208613` |
| Stage 3 | Design doc (this) | 🔄 D.3 | Scope revised per Phase 1A mini-audit |
| 0 | Uses PPN 4C existing acceptance file + Pre-0 bench (no new artifacts needed) | ✅ | `examples/2026-04-17-ppn-track4c.prologos`; `benchmarks/micro/bench-ppn-track4c.rkt` |
| 1A-i | Retire dead code: `wrap-with-assumption` + `promote-cell-to-tms` | ✅ | commit `5cf9a262` — 29 lines deleted across 2 files; 85 tests pass; acceptance file clean |
| 1A-ii-a | Migrate 3 of 4 `net-new-tms-cell` sites: mult, level, session cells | ✅ | commit `7052f590` — 25 insertions; acceptance file clean; 111 targeted tests pass |
| 1A-ii follow-up | Register `'mult` SRE domain + extend `register/minimal` with `#:contradicts?` kwarg | ✅ | commit `8b85b28a` — Option Y + 2b; enables Phase 13 ratchet; 77 targeted tests pass |
| 1A-iii-probe | Pre-0 behavioral probe (`.prologos` file) capturing baseline pre-1A-iii-a-wide | ✅ | commit `329d4f30` — 6 scenarios, 28 expressions, 0 errors baseline captured |
| 1A-iii Sub-A | Type cell migration experiment: tagged-cell-value at elab-fresh-meta | ⏸️ REVERTED | Probe showed regression; root cause is deeper than Path (b) — see §7.5.8 |
| **Path T-3** | **Type lattice set-union merge redesign — PREREQUISITE** (Stage 1→4) | 🔄 | Point 3 architectural finding: `type-lattice-merge(Int, String)` → `type-top` is lattice design inadequacy. Set-union semantics required. |
| T-3 mini-design | Set-union semantics, Role A/B decomplection, type-unify-or-top helper | ✅ | commit `9c3172e0` — Q-T3-1 through Q-T3-9 resolved; subtype-lattice-merge prior art template |
| T-3 Stage 2 audit | Classify type-lattice-merge call sites (Role A/B) | ✅ (INCOMPLETE) | commit `6fddc5f7` — 4 Role B + 8 Role A + dispatch tables. MISSED contradiction-detection-as-fallback sites — see §7.6.12/§7.6.13 |
| T-3 probe baseline | Pre-0 behavioral probe (6 scenarios) | ✅ | commit `329d4f30` |
| T-3 Commit A | Role B migration (4 sites) + type-unify-or-top helper | ✅ | commit `37aaba2b` — zero behavior change; probe diff 0; 129 targeted tests pass |
| **T-3 Commit B** | `type-lattice-merge` set-union fallthrough + B6 migration + 5 test updates + distributivity finding | ✅ | commit `e07b809f` — probe diff = 0; canary `(infer <Nat | Bool>) = [Type 0]` PASSES; 7942-test suite 1-failure (pre-existing batch contamination, verified via stash test) |
| **T-3 T3-C3 re-audit** | Systematic audit for contradiction-detection-as-fallback sites | ✅ | Q3 C3 full grep classification: 5 Role B sites (B1-B5) + 1 architectural error (C1 expr-union) + B6 exposed during Commit B integration (elab-fresh-meta + identify-sub-cell). Q2 resolved: install is infer-only. See §7.6.14 |
| **T-3 Commit A.2-a** | Architectural fix: `make-union-fire-fn` + expr-union install rewrite + dead scaffolding removal | ✅ | commit `a5a33a71` — paralleling `make-pi-fire-fn`; probe diff = 0; 147 targeted tests pass; standalone-safe |
| **T-3 Commit A.2-b** | Centralized `type-map-write-unified` helper + B1 (app fire) + B2 (expr-ann) Role B migrations | ✅ | commit `f85dd50a` — Role A/B decomplection at API level; 154 targeted tests pass |
| **T-3 Commit A.2-c** | Cell merge-fn swaps: B3 (classify-inhabit), B4 (cap-type-bridge), B5 (session-type-bridge) | ✅ | commit `105bcdae` — Role B cell merge-fn semantics; 242 targeted tests across 11 files pass |
| **T-3 COMPLETE** | — | ✅ | **DONE** 2026-04-22. 4 commits, staged A→B. Set-union merge live; contradiction signal preserved via Role A/B decomplection chain. |
| **Re-sequencing 2026-04-22** | Post-T-3 task dependency clarified per charter-alignment dialogue | — | Tactical T-1/T-2 cleanup was framed against end-state (Phase 9 substrate + Phase 4 CHAMP retirement + PM 12 on-network migrations). Result: **1A-iii-a-wide Step 1 precedes T-1/T-2** because it IS the addendum's Phase 1 substrate-migration charter continuation. T-1 post-Step-1 becomes "scaffolding retirement plan," not "API redesign." See §7.5.10 for the framing. |
| **1A-iii-a-wide Step 1** | Type cell migration to tagged-cell-value + TMS retirement (Phase 1 substrate charter completion) | ✅ | **DONE** 2026-04-22. 5 commits S1.a-e. See §7.5.11 for full summary. S1.a (`3b6aefdb`) elab-fresh-meta → tagged-cell-value + 4th accidentally-load-bearing finding fix (visibility scope in `with-speculative-rollback` parameterize). S1.b (`2c8871ec`) retired 3 TMS fallback branches. S1.c (`d220ca51`) retired TMS API wholesale (~258 lines deleted). S1.d (`9f47ffe9`) retired current-speculation-stack parameter. S1.e (`b1468220`) peripheral cleanup (test-tms-cell.rkt deleted, cell-ops stale comments updated). Full suite: 7908 tests, 126.7s, 1 pre-existing batch contamination (unrelated). |
| Path T-1 | `with-speculative-rollback` scaffolding retirement plan | ✅ | **DONE** 2026-04-22 (commit TBD). Documentation-only pass per charter alignment. Labeled elab-net snapshot as scaffolding with retirement plan in elab-speculation-bridge.rkt module docstring + inline comments; cleaned up stale Phase 11 retirement-journey comments. PM Master updated with "PPN 4C 1A-iii-a-wide Step 1 + T-1 (2026-04-22) — `with-speculative-rollback` retirement handoff" section specifying light cleanup sub-phase for PM 12 (6 caller migrations to `speculate` form, ~20-30 min mechanical work). DEFERRED.md updated. No code changes; no caller simplifications warranted post-Step-1. Full retirement gated on Phase 4 (meta-info CHAMP) + PM 12 (constraint store + id-map). |
| Path T-2 | Map type inference open-world realignment ("Open by Design") | ✅ | **DONE** 2026-04-23. 3 commits. See §7.6.15 for full summary. Commit 1/3 (`4bfbd141`): `expr-Open` AST + pipeline integration (7 files: syntax/substitution/zonk/reduction/pretty-print/pnet-serialize/unify). Commit 2/3 (`246d4c2e`): typing semantics + map-op Open cases + map-assoc speculation retirement (typing-core + qtt). Commit 3/3 (`07fda438`): elaborator `surf-map-literal` emits Open for unannotated value type + test-mixed-map rewrite (21→25 tests) + test-path-expressions update + probe baseline refreshed. Full suite 7912 tests / 118.4s / 0 failures (pre-existing batch contamination cleared). speculation_count 12→0 in probe. Overrides 2026-03-20 CIU §8 D7. |
| **1A-iii-a-wide Step 2** | PU refactor (4 per-domain universes + shared hasse-registry + compound-tagged-merge + cell-access helper) | 🔄 | Vision-advancing capstone for Phase 1A. Per D.3 §7.5.4 (revised 2026-04-23 to Option B). S2.a ✅ (`ded412db`) + S2.a-followup ✅ (`2bab505a`). S2.b staged per §7.5.12 mini-design (2026-04-24). |
| Step 2 S2.b-ii | Reader dispatch in `meta-solution/cell-id` + scheduler component-path verification | ✅ | `82c9f426` — scheduler verified (supports cons-pair paths, but flat-hasheq universes use bare meta-id per §7.5.12.5); centralized dispatch lands as no-op pre-b-iii; probe diff = 0; 150 targeted tests green |
| Step 2 S2.b-iii | `elab-fresh-meta` migration + Category 2 direct consumers (TYPE domain) | ✅ | `cf60c397` — fresh-meta + solve-meta-core[!/pure] dispatch added; init-meta-universes! wired into reset-meta-store!; bug found+fixed in meta-solved? (direct elab-cell-read was returning raw hasheq → false "solved"); probe PASSES (semantic output matches baseline, 0 errors); 150 targeted tests green |
| Step 2 S2.b-iv | Set-latch + broadcast realization rewrite of 3 fan-in install sites + factory signature changes + scan retirement + test rename | ✅ | 7 commits `ffb5fd0b` (D.3 corrections + propagator-design refinement) → `dc05f940` (foundation: pnet helpers + elab wrappers + meta-ids field) → `0bfc7dbf` (helper) → `89cdaf89` (site 1/3 + broadcast '() bug fix) → `c76b49e3` (site 2/3 + trait factory) → `34b60155` (site 3/3 + hasmethod factory) → `bddfc3e3` (scan retirement + test file renamed/rewritten) + test-fix commit. **Suite: 7909/0 failure (was 7912/4 failures pre-b-iv); test-rewrite consolidated 5 scan-invocation tests into 13 event-driven tests**. Probe identical to baseline. |
| Step 2 S2.b-v | Formal measurement vs §5 hypotheses + go/no-go for S2.c | ✅ | bench-meta-lifecycle re-run 2026-04-24; results captured in [STEP2_BASELINE.md §12 "Actual vs Predicted"](2026-04-23_STEP2_BASELINE.md#12). **Suite wall time 119.5s within 118-127s baseline variance band — load-bearing user-facing metric MET**. Mixed micros: fresh-meta improved ~27% (2.534 μs vs 3.45 μs baseline; just barely missed §5 ≤2.5 μs target); solve-meta! REGRESSED ~31% (11.14 μs vs 8.53 μs); read paths slower (~80% on direct-cell-id, ~100% on cell-path). Cell counts transitional (54 vs 50; mult/level/session still per-cell). **Decision: GO for S2.c** — architecture is correct; full hypotheses validation gated on S2.e factory retirement. Solve-meta! regression flagged for follow-up audit post-S2.e. |
| Step 2 S2.c mini-design (D.3 §7.5.13) | Conversational mini-design + audit-driven scope expansion | ✅ | 4 converging architectural decisions identified: cross-domain bridge component-path, parameter injection gap, cell-id approach (option 1/2/4 microbench-gated), dispatch unification across mult/level/session. See §7.5.13. Commit `107a37c6`. |
| **Step 2 S2.precursor** | `net-add-cross-domain-propagator` accepts `:c-component-paths` / `:a-component-paths` / `:assumption` / `:decision-cell` / `:srcloc` (universal fix, 4 production bridges + ~12 test callers preserve backward-compat via empty-default kwargs) | ✅ | Universal infrastructure fix per D.3 §7.5.13.7. Defaults preserve whole-cell firing semantics for non-universe cells. 3 new tests in test-cross-domain-propagator.rkt verify kwargs accepted + bridge installs correctly. **Suite: 7912 tests / 120.7s / 0 failures** (vs 7909/119.5s baseline; +3 new tests, +1.2s within 118-127s variance band). Probe diff = 0. Commit `1c3970d0`. |
| Step 2 S2.c-i Task 2 (T-3 'equality audit) | Audit + permanent regression test (`tests/test-t3-equality-audit.rkt`, 5/5 PASS) | ✅ | **Audit found NO T-3 gap** — option 3a was wrong (would break union-aware structural reasoning). Option 3c adopted (per-domain merges in `meta-domain-info` table). Original S2.c-ii REMOVED. See D.3 §7.5.13.4. |
| ~~Step 2 S2.c-ii (close T-3 gap)~~ | — | REMOVED | Audit (Task 2) revealed no gap exists. Substituted by permanent regression test in S2.c-i Task 2. |
| Step 2 S2.c-i Task 1 (microbench) | §5 microbench A/B (option 1/2/4 cell-id approach) | ⬜ | Data-driven decision per §7.5.13.5. |
| Step 2 S2.c-i Task 3 (initial-Pi audit) | Trace mult-info flow when Pi initially elaborated from AST (verify scenario B understanding) | ⬜ | Confirms or refines §7.5.13.2. |
| Step 2 S2.c-ii (was iii) | Parameter injection per option 3c: wire 4 universe-merge parameters at elaborator-network.rkt module load with `compound-tagged-merge`-wrapped per-domain merges | ✅ | All 4 universe cells now use canonical domain merges (`compound-tagged-merge` of `type-unify-or-top` / `mult-lattice-merge` / `merge-meta-solve-identity`). Probe diff = 0 vs baseline. **Suite: 7917 tests / 126.4s / 0 failures** (within 118-127s variance band; +5 tests from test-t3-equality-audit.rkt, +5.7s within normal variance). |
| Step 2 S2.c-iii (was iv) | Dispatch unification: `meta-domain-info` table (with `'universe-active?` per-domain flag for staged migration correctness) + generic `meta-domain-solution(domain, id)` core (option 4 parameter-read per microbench winner) + retire OR in `unify.rkt:430` (redundant under option 4) | ✅ | 5 commits sub-step (a) docs `d5948677` + (a-dailies) `db616051` + (b1) infrastructure `a01e193b` + (b2) type shims + OR retirement `f4c8db9d` + (b3) mult/level/session shims `48afcce0`. **Net: 9 dispatch functions reduced to 1-2 line shims; -198 LoC of duplicated dispatch absorbed into 215 LoC of shared infrastructure (meta-domain-info table + helpers + cores).** Verification: probe diff = 0 vs S2.c-ii baseline (cells=54, cell_allocs=1195, infer_steps=55, all counters identical); acceptance file 0 errors; full suite **7917 tests / 125.2s / 0 failures** within 118-127s variance. Mini-audit findings + 5 surprises at §7.5.13.6.1. S2.e scope items at §7.5.14. PPN 4C parent Phase 4 + DEFERRED.md updated for cross-cutting (cache-field + callback retirements). |
| **Step 2 S2.c-iii Move B+ (corrective, 2026-04-24)** | Capture option 4 perf benefit missed by first-pass implementation (drop with-handlers + ignore explicit-cid for universe-active + retire legacy-type-fn). User-surfaced VAG drift via "did we do anything about the cache fields?" External challenge revealed first-pass VAG catalogued instead of challenged. | ✅ | 3 commits: methodology codification (`9f7c0b82`) — adversarial VAG + microbench claim verification across DESIGN_METHODOLOGY/CRITIQUE_METHODOLOGY/workflow.md/MEMORY.md/STEP2_BASELINE.md §6.1; Move B+ code (`c86596e0`) — universe-active path option 4 PURE (no with-handlers, ignore explicit-cid), legacy-type-fn retired; re-VAG documentation (`<this commit>`) — D.3 §7.5.13.6.2 with adversarial framing applied honestly (TWO COLUMN catalogue vs challenge). **Microbench verification**: Path 1 went 625 ns/call → 388 ns/call (Δ −237 ns/call ≈ 80% of predicted 302 ns option 4 benefit). Suite: 7917/128.2s/0 failures within variance. Methodology lesson codified: VAG must be ADVERSARIAL not auditional; microbench claims must be VERIFIED not assumed. |
| Step 2 S2.c-iv (was v) | `fresh-mult-meta` universe-path branch + cross-domain bridge migration (`current-structural-mult-bridge` declares component-paths) | ⬜ | ~80-120 LoC. Mirrors S2.b-iii pattern. |
| Step 2 S2.c-v (was vi) | Probe + targeted suite + measurement + GO/no-go for S2.d | ⬜ | STEP2_BASELINE.md §12 update. |
| **Phase 1E** | **`that-*` Storage Unification (NEW 2026-04-23)** | ⬜ | New phase sequenced between Step 2 and Phase 1B per architectural dialogue 2026-04-23. Storage-layer unification: route `that-*` (position-keyed user-facing API) to universe-cell component reads when position is a meta-position. Preserves 27ns `that-read` fast path (per PRE0). Prelude to Track 4D storage unification; not replacement. See §7.6.16 for implementation notes. |
| 1A-iii-b | Tier 2: Deprecated `atms` struct + `atms-believed` + deprecated internal API retirement | ⬜ | Independent of Path T; can proceed in parallel |
| 1A-iii-c | Tier 3: Surface ATMS AST retirement (14-file pipeline) | ⬜ | Independent of Path T; can proceed in parallel |
| 1B | Tropical fuel primitive + SRE registration | ⬜ | Follows Phase 1E per revised 2026-04-23 sequence. |
| 1C | Canonical BSP fuel instance migration | ⬜ | A/B bench required |
| 1V | Vision Alignment Gate Phase 1 | ⬜ | |
| 2A | Register S(-1), L1, L2 as stratum handlers | ⬜ | |
| 2B | Retire orchestrators (`run-stratified-resolution-pure` + dead `run-stratified-resolution!`) | ⬜ | |
| 2V | Vision Alignment Gate Phase 2 | ⬜ | |
| 3A | Fork-on-union basic mechanism | ⬜ | |
| 3B | Hypercube integration (Gray code + subcube) | ⬜ | |
| 3C | Residuation error-explanation | ⬜ | |
| 3V | Vision Alignment Gate Phase 3 | ⬜ | |
| V | Capstone + PIR | ⬜ | |

---

## §4 NTT Model — post-Phase-1-3 state

Per DESIGN_METHODOLOGY Stage 3 NTT Model Requirement. Cross-referenced against [NTT Syntax Design](2026-03-22_NTT_SYNTAX_DESIGN.md). Notation follows NTT conventions; extensions to NTT are flagged explicitly.

### §4.1 Tropical fuel primitive (Phase 1 delivery)

Per NTT §3.1 (value lattices) + §3.4 (`Quantale` extends `Lattice` with tensor):

```ntt
;; Tropical fuel lattice — atomic extended-real
type TropicalFuel := Nat | Infty
  :lattice :value

;; Tropical quantale instance: min-plus algebra.
;; Per research doc §9.1 (commutative integral residuated quantale).
;; Aligns with NTT §3.1's Quantale trait pattern.
trait Lattice TropicalFuel
  spec tropical-join TropicalFuel TropicalFuel -> TropicalFuel
  defn tropical-join [a b] -> (min a b)  ;; min ∨ semantics
  spec tropical-bot -> TropicalFuel
  defn tropical-bot -> 0

trait BoundedLattice TropicalFuel
  :extends [Lattice TropicalFuel]
  spec tropical-top -> TropicalFuel
  defn tropical-top -> Infty

trait Quantale TropicalFuel
  :extends [Lattice TropicalFuel]
  spec tropical-tensor TropicalFuel TropicalFuel -> TropicalFuel
  defn tropical-tensor [a b] -> (+ a b)  ;; + ⊗ semantics

;; Residuation: per research doc §9.3
trait Residuated TropicalFuel
  :extends [Quantale TropicalFuel]
  spec tropical-left-residual TropicalFuel TropicalFuel -> TropicalFuel
  defn tropical-left-residual [a b]
    -> (if (>= b a) (- b a) 0)  ;; b / a = b - a when b >= a else bot

;; Primitive cell factory (consumer-instantiable)
propagator net-new-tropical-fuel-cell
  :reads  []
  :writes [Cell TropicalFuel :init 0]

;; Canonical budget cell factory (paired with fuel cell)
propagator net-new-tropical-budget-cell
  :reads  []
  :writes [Cell TropicalFuel :init Budget]

;; Threshold propagator factory
;; NOTE: "fires once at threshold" is an NTT-extension sketch;
;; the current NTT has :fires-once-on-threshold (for fire-once propagators)
;; but not parameterized over runtime condition. Flagged as NTT refinement
;; candidate (§4.5 Observations).
propagator tropical-fuel-threshold  :extension-note
  :reads  [Cell TropicalFuel (at fuel-cid)
           Cell TropicalFuel (at budget-cid)]
  :writes [Cell Contradiction]
  :component-paths [(cons fuel-cid #f) (cons budget-cid #f)]
  fire-fn: if (>= fuel-cost budget) then write-contradiction else net
```

### §4.2 Worldview substrate post-retirement (Phase 1 delivery)

```ntt
;; Post-Phase-1 worldview architecture: two layers of the same bitmask

;; Layer 1: on-network authoritative cell (unchanged from BSP-LE 2B)
cell worldview-cache
  :type Bitmask  ;; Q_n Boolean lattice (hypercube)
  :lattice :value
  :merge worldview-cache-merge  ;; equality-check replacement
  :cell-id 1

;; Layer 2: per-propagator override (parameter, scoped inside fire functions)
;; NOTE: Racket parameter = scaffolding; PM Track 12 migration target
parameter current-worldview-bitmask :type Bitmask
  :default 0
  :scope fire-function

;; Retired: current-speculation-stack (legacy, Phase 1 retires)
;; Retired: tms-read/tms-write fallback paths in net-cell-read/write
```

### §4.3 Stratum handler topology post-unification (Phase 2 delivery)

Per NTT §7 (Level 5: Stratification) — `stratification` with `:fiber` forms:

```ntt
;; 9 registered stratum handlers post-Phase-2 (was 6 pre-Phase-2)

stratum-handlers := [
  ;; Topology tier (4, unchanged)
  (constraint-propagators-topology-cell-id  :tier 'topology)
  (elaborator-topology-cell-id              :tier 'topology)
  (narrowing-topology-cell-id               :tier 'topology)
  (sre-topology-cell-id                     :tier 'topology)

  ;; Value tier (5, +3 from Phase 2)
  (naf-pending-cell-id                      :tier 'value)
  (classify-inhabit-request-cell-id         :tier 'value)
  (retraction-stratum-request-cell-id       :tier 'value)   ;; NEW Phase 2
  (readiness-stratum-request-cell-id        :tier 'value)   ;; NEW Phase 2
  (resolution-stratum-request-cell-id       :tier 'value)   ;; NEW Phase 2
]

;; BSP scheduler's outer loop iterates all handlers per tier
;; Retired: run-stratified-resolution-pure (sequential orchestrator)
;; Retired: run-stratified-resolution! (dead code)
```

### §4.4 Union-type branching via ATMS (Phase 3 delivery)

Per D.3 §6.10 + NTT §7.6 (`:speculation :atms`, `:branch-on [union-types]`):

```ntt
;; ATMS-based branching on union type A | B
;; Per D.3 §6.10 framing: "ATMS branching on a union type IS applying
;; SRE ctor-desc to the ⊕ constructor"

propagator fork-on-union
  :reads  [(meta-pos :type)  ;; classifier cell (sees union)
           Cell Bitmask (at worldview-cache-cell-id)]
  :writes [Cell TaggedCellValue :tagged branch-a-aid
           Cell TaggedCellValue :tagged branch-b-aid
           Cell TropicalFuel (per-branch cost via primitive)]
  :fires-once-when (union-ctor-desc? classifier)
  fire-fn:
    let [a, b] = ctor-desc-decompose ⊕ classifier
    let aid-a = fresh-assumption-id
    let aid-b = fresh-assumption-id
    let branch-a = tag-worldview aid-a
    let branch-b = tag-worldview aid-b
    ;; Per-branch elaboration happens structurally via worldview-filtered reads
    ;; Cost accumulation via tropical fuel primitive per-branch

;; NTT extension: :writes :tagged annotation — branch-tagged writes.
;; Flagged as NTT refinement candidate (§4.5 Observations).

;; Gray-code branch traversal (Phase 3B integration)
;; NTT extension: :execution ordering annotation. Flagged as refinement.
spec traverse-branches
  :reads  [list-of-branches]
  :execution :gray-code-order

;; Subcube pruning on nogood (Phase 3B integration)
;; Existing Prologos primitive (decision-cell.rkt), exposed via NTT.
spec prune-nogood-subcube
  :reads  [nogood-bitmask, worldview-bitmask]
  :predicate (= (bitwise-and wv ng) ng)

;; Residuation-based error-explanation (Phase 3C)
;; Read-time function, not propagator (per D.3 §6.1.1 M4 critique).
spec derivation-chain-for
  :reads  [contradicting-cell, all-branches]
  :output ErrorChain
```

### §4.5 NTT Observations

Per NTT methodology "Observations" subsection requirement:

1. **Everything on-network?** Yes, with one fully-documented scaffolding: `current-worldview-bitmask` parameter remains as a per-fire-function override of the `worldview-cache` cell. Retirement plan: PM Track 12 (module loading on network), which migrates the scoping model. Not Phase 1-3 scope.

2. **Architectural impurities revealed by the NTT model?**
   - `tropical-fuel-threshold` requires "fires when runtime condition," beyond NTT's current `:fires-once-on-threshold`. Matches existing Phase 3c-iii residuation propagator pattern — precedent for extending NTT.
   - Fork-on-union propagator writes multiple tagged cells — reveals need for NTT's `:writes :tagged` syntax (not currently formalized).
   - Tropical fuel primitive writes to multiple cells (cost + budget) — NTT models as two separate cell factories. Clean.

3. **NTT syntax gaps surfaced**:
   - `:writes :tagged branch-aid` — branch-tagging annotation for fork propagators. Flagged for NTT design resumption.
   - `:execution :gray-code-order` — execution-order annotation for branch traversal. Flagged.
   - `:fires-once-when (predicate)` — runtime-condition-gated fire. Flagged as generalization of `:fires-once-on-threshold`.
   - `:preserves [Residual]` was already flagged in PPN 4C D.3 §15; confirmed relevant for tropical fuel quantale. Per NTT §13.3 "Quantale morphism syntax" known-unknown — this work provides concrete use case.

4. **Components the NTT cannot express?** None at D.2 level that isn't noted as refinement candidate. P/R/M/S critique (§11) may surface more.

---

## §5 Design Mantra Audit (Stage 0 gate)

Per DESIGN_METHODOLOGY Stage 0 Design Mantra Audit requirement. The mantra: *"All-at-once, all in parallel, structurally emergent information flow ON-NETWORK."*

For each major design component:

| Component | All-at-once | Parallel | Emergent | Info flow | On-network |
|---|---|---|---|---|---|
| Tropical fuel cell primitive | ✓ per-cell alloc | ✓ consumer-parallel | ✓ from SRE domain | ✓ cell merges | ✓ cell-based |
| Canonical BSP fuel instance | ✓ pre-alloc in make-prop-network | ✓ threshold propagator + fire-fn | ✓ from fuel/budget comparison | ✓ cost accumulates via merge | ✓ cell-based |
| `current-speculation-stack` retirement | N/A (deletion) | — | — | — | removes off-network residue |
| Stratum handler registration (Phase 2) | ✓ all handlers iterate | ✓ per-tier all handlers fire | ✓ from BSP scheduler | ✓ via request cells | ✓ already on-network |
| Fork-on-union (Phase 3) | ✓ both branches tagged simultaneously | ✓ per-branch elaboration | ✓ from ⊕ ctor-desc | ✓ via tagged-cell-value | ✓ |
| Gray-code branch ordering | N/A (traversal order) | — | ✓ from hypercube adjacency | ✓ CHAMP sharing | ✓ already on-network |
| Subcube pruning | N/A (filtering order) | ✓ O(1) per-branch | ✓ from bitmask structure | ✓ via worldview filter | ✓ |
| Residuation error-explanation | N/A (read-time) | — | ✓ from dep graph | ✓ backward residual walk | read-time only |

**Findings**: all components satisfy mantra. `current-worldview-bitmask` parameter is scoped-inside-fire-fn scaffolding (§4.2 note), with retirement plan to PM Track 12.

---

## §6 Architectural decisions

Architectural commitments for this addendum. Phase-specific scope questions (Q-A3 ATMS retirement scope, Q-A4 elab-speculation.rkt disposition, Q-A5 atms-believed timing, Q-A6 residuation error-explanation placement) emerge at phase mini-design time (§16) — not pre-resolved here.

### §6.1 Q-A1 — Phase partitioning (RESOLVED 2026-04-21)

**Decision**: 3 phases, sequential (single-agent process constraint), sub-phases labeled A-Z as needed. Phase names: 1 (substrate + tropical fuel), 2 (orchestration), 3 (union types + hypercube). Hypercube embedded in Phase 3 (not standalone) because primitives already implemented per audit §3.5.

**Lens justification**:
- **P (Principles)**: Decomplection — Phase 1 substrate, Phase 2 orchestration, Phase 3 features are separable. Most Generalizable Interface — Phase 1 substrate stabilizes first so 3 consumes.
- **R (Reality)**: Work-volume per audit §8.3 fits ~200-400 LoC per sub-phase at this partitioning.
- **M (Mindspace)**: dependency ordering is substrate → consumers.
- **S (Structural)**: Hasse of sub-phase dependencies has Phase 3 below Phase 1, Phase 2 independent — 3 sub-phase partition captures this faithfully.

### §6.2 Q-A2 — Tropical fuel cell placement (RESOLVED 2026-04-21)

**Decision**: Option 3 with canonical instance. Substrate-level tropical quantale registered as SRE domain; primitive API for consumer instantiation; canonical BSP scheduler instance allocated in `make-prop-network` using the primitive.

**Concretely**:
- `'tropical-fuel` SRE domain (Tier 1) with tropical quantale properties (Commutative, Unital, Integral, Residuated)
- `net-new-tropical-fuel-cell` + `net-new-tropical-budget-cell` + threshold propagator factory (primitive API)
- Canonical BSP instance at well-known cell-ids (fuel-cost = cell-id 11, budget = cell-id 12)
- Consumer instances (future PReduce, Phase 9b) allocate their own cells via primitive — no well-known IDs needed

**Lens justification**:
- **P**: First-Class by Default (primitive is reified); Decomplection (substrate algebra separated from consumer cell placement).
- **R**: Matches hasse-registry pattern (Phase 2b) + well-known cell-id pattern (substrate cells 0-10).
- **M**: Information flow via per-consumer cells, all consuming the same quantale algebra; cross-consumer reasoning via Galois bridges in quantale module theory.
- **S**: Module Theory — each fuel cell is a quantale-module over shared tropical quantale; cross-consumer cost queries are module morphisms. Research doc §6.5-§6.7 codifies this.

### §6.3 Q-A7 — Phase 4 β2 substrate contract (interface specification)

**Decision**: Specify the contract here (§14). Phase 4 β2 consumes:
- The tropical fuel primitive (meta-elaboration cost tracking optional)
- The `worldview-cache-cell-id` (meta entries bitmask-tagged per branch for ATMS speculation)
- `classify-inhabit-value` Module Theory Realization B tag-dispatch (already shipped in Phase 3 of PPN 4C)
- `solver-context` / `solver-state` API (no deprecated `atms` dependencies)

Phase 4 β2 does NOT consume:
- `current-speculation-stack` (retired by Phase 1)
- `prop-network-fuel` field (retired by Phase 1)

### §6.4 Q-A8 — Phase 9b interface specification

**Decision**: HIGH-level specification in §15; detailed design owned by Phase 9b's own design cycle.

Phase 9b γ hole-fill consumes from Phase 1-3:
- Tagged-cell-value for multi-candidate ATMS branching (Phase 3 deliverable, on-network)
- Tropical fuel primitive (if γ wants cost-bounded hole-fill — optional)
- Phase 2b Hasse-registry primitive (from PPN 4C Phase 2b, already shipped)

### §6.5 Phase-specific questions (deferred to mini-design)

Per user direction 2026-04-21: Q-A3 (retirement scope), Q-A4 (elab-speculation.rkt disposition), Q-A5 (atms-believed timing), Q-A6 (residuation placement) are phase-specific scope decisions with architectural tradeoffs best addressed at the phase mini-design step with code in hand. This design document does NOT pre-resolve them; they are mini-design items listed in §16.

---

## §7 Phase 1 — Substrate + Tropical Fuel

### §7.1 Scope and rationale

Phase 1 is the foundational sub-phase — retires legacy substrate (current-speculation-stack, prop-network-fuel counter) and ships the tropical fuel primitive that Phase 2, Phase 3, and downstream consumers build on.

### §7.2 Sub-phase partition

- **Phase 1A-i — Retire dead code** (~30-50 LoC)
- **Phase 1A-ii — Migrate elaborator-network.rkt TMS cells to tagged-cell-value** (~150-200 LoC)
- **Phase 1A-iii — Retire TMS-cell mechanism + `current-speculation-stack`** (~100-200 LoC)
- **Phase 1B — Tropical fuel primitive + SRE registration** (~150-200 LoC)
- **Phase 1C — Migrate `prop-network-fuel` → canonical tropical fuel cell** (~100-200 LoC)
- **Phase 1V — Vision Alignment Gate**

### §7.3 Phase 1A-i deliverables (dead-code cleanup)

**Retirement targets** (per Phase 1A mini-design audit 2026-04-21):
1. Delete `wrap-with-assumption` helper at `typing-propagators.rkt:325-329` — ZERO production callers (D.2's "wrap-with-assumption-stack" name was a typo; correct name is `wrap-with-assumption`)
2. Delete `promote-cell-to-tms` helper at `typing-propagators.rkt:334-338` — ZERO production callers (sole reference at `typing-propagators.rkt:1918` is a comment)
3. Update exports in `typing-propagators.rkt` if these are exported
4. No comment-only scrubs required (audit §3.1.1's claim about `cell-ops.rkt:62, 103` — re-verify at phase start; may be comments to leave or update)

**Deliverables**:
- Both dead helpers deleted
- Exports updated
- Affected-tests GREEN
- Per-phase regression: acceptance file clean via `process-file`

**Low risk**: pure deletion of dead code. Verification is whether the deletion triggers any unexpected test or module-load failures (i.e., confirmation that dead really means dead).

### §7.4 Phase 1A-ii — SPLIT into 1A-ii-a and 1A-ii-b (revised 2026-04-22)

**Root cause finding** (attempt 1 reverted): migrating ALL 4 `net-new-tms-cell` sites at once via factory-body rewrite introduced a broad regression (union-type inference failures, unsolved type metas, cascading multiplicity violations). Post-revert diagnostic via (e) deep audit + (a) code trace identified the cause:

Union-type inference at typing-propagators.rkt:1878-1920 parameterizes `current-worldview-bitmask` (not `current-speculation-stack`). Pre-migration, type meta cell writes during union speculation fell through to `net-cell-write`'s TMS legacy branch at line 1248 (`(and (tms-cell-value? old-val) (not (tms-cell-value? new-val)))`), which invokes `tms-write old '() new-val` — updating the BASE (not a branch) because `current-speculation-stack = '()`. Both union branches' writes accumulated in the same base via `make-tms-merge(type-lattice-merge)` → produced `Int | String` etc. Post-migration, tagged-cell-value writes under non-zero `current-worldview-bitmask` go to per-branch tagged entries — branches are isolated; base stays at type-bot; type metas read as unsolved.

BSP-LE Track 2 PIR's "`current-speculation-stack` RETIRED" claim was about parameterize usage (which IS retired). But the TMS STRUCTURE's dispatch at net-cell-write:1248 was providing load-bearing semantics for union inference independently of the parameter — a subtlety the PIR didn't capture.

**Path Z split**:

**Phase 1A-ii-a (DELIVERED 2026-04-22, commit `7052f590`)**: migrate 3 of 4 sites — mult, level, session cells. These don't participate in union-type inference the same way:
- `elaborator-network.rkt:921` — mult cell: flat lattice (identity-or-top); both union branches typically infer same mult
- `elaborator-network.rkt:995` — level cell: identity-or-error; both branches typically infer same level
- `elaborator-network.rkt:1011` — session cell: same as level

Branch-isolation under tagged-cell-value is semantically correct for these cells.

**Phase 1A-ii-b (PULLED INTO 1A-iii SCOPE)**: type cell migration — requires union-inference adaptation at typing-propagators.rkt:1878-1920. The migration must co-design:
- Type cell creation (line 114) → tagged-cell-value
- Union inference write path → either (a) write to base directly (not per-branch entries) OR (b) commit both branches' entries and rely on read-time merge via `tagged-cell-read(v, combined-bitmask, type-lattice-merge)`

Option (b) aligns with the lines 1912-1913 existing pattern (`combined-bitmask = bitwise-ior left-bitmask right-bitmask`) but requires verifying the read-time merge produces the expected union types. Option (a) preserves the pre-migration base-write semantic explicitly.

**1A-ii-a migration sites (DELIVERED)**:
1. `elaborator-network.rkt:921` — mult cell migrated ✓
2. `elaborator-network.rkt:995` — level cell migrated ✓
3. `elaborator-network.rkt:1011` — session cell migrated ✓

**1A-ii-b migration sites (DEFERRED to 1A-iii)**:
4. `elaborator-network.rkt:114` — type cell (paired with typing-propagators.rkt:1878+ adaptation)

**Migration target shape** (each site):
```
;; BEFORE
(net-new-tms-cell net INITIAL DOMAIN-MERGE [CONTRADICTS?])

;; AFTER
(net-new-cell net INITIAL
              (make-tagged-merge DOMAIN-MERGE)
              [CONTRADICTS?])
```

The tagged-cell-value mechanism (BSP-LE 2B infrastructure) handles speculation-tagging via `current-worldview-bitmask`. `with-speculative-rollback` continues to work because it reads/writes via the bitmask path which is the primary path for tagged-cell-value cells.

**Risk area**: ensuring `with-speculative-rollback` semantics are preserved post-migration. `with-speculative-rollback` callers (qtt.rkt, typing-errors.rkt, typing-core.rkt — 4 sites per audit §3.2.2) must continue to work identically. Parity tests target this.

**Deliverables**:
- 4 sites migrated
- `with-speculative-rollback` continues to work for all 4 production callers
- Affected-tests GREEN
- New parity tests (axis: speculation-mechanism-parity) confirming pre-1A-ii == post-1A-ii for representative speculation scenarios
- Per-phase regression: acceptance file clean

**Mini-design items at Phase 1A-ii start** (per methodology Stage 4 step 1):
- Confirm `make-tagged-merge` handles domain-specific merge composition correctly for all 4 domain merges (type-lattice-merge, mult-lattice-merge, merge-meta-solve-identity)
- Decide whether to retain `net-new-tms-cell` signature as-is (with migration internally to tagged-cell-value) OR expose `net-new-cell` directly
- Parity test design for speculation semantics
- Determine whether `with-speculative-rollback` needs any updates (audit §3.2.2 says "bitmask only" already per Phase 11, so likely no change)

### §7.5 Phase 1A-iii — EXPANDED SCOPE (revised 2026-04-22)

**Scope decisions** (resolved via mini-design dialogue 2026-04-22 per Path Z + Z-wide + Framing C):

- **Z-wide** (user direction 2026-04-22): "we want to land in greater completeness and correctness, architecturally — without concern of the implementation cost. Pragmatic implementation shortcuts should never be on the table for our consideration." 1A-iii absorbs PU refactor + hasse-registry integration in addition to TMS retirement.
- **Framing C** (Pocket Universe refactor + hasse-registry integration): per-meta cells collapse to 4 per-domain compound PU cells; shared hasse-registry-handle across domains with Q_n subsume-fn; per-component tagged-cell-value semantics.

**Architectural rationale**:

Per `propagator-design.md` § "Cell Allocation Efficiency" + `structural-thinking.md` § "Direct Sum Has Two Realizations" (Realization B — shared carrier with tagged layers), per-meta cells (N-separate-cells pattern) violate the PU principle now that we have mature PU infrastructure (decisions-state, commitments-state, scope-cell, attribute-map, worldview-cache — all N→1 compound cells). Per-meta cells are the last holdout; 1A-iii brings them into alignment.

The 1A-ii root cause (TMS dispatch at net-cell-write:1248 being load-bearing for union inference) also requires union-inference adaptation at typing-propagators.rkt:1878-1920 — Path (b) read-time merge via `tagged-cell-read(v, combined-bitmask, type-lattice-merge)`. Path (b) explicitly expresses union construction as a **hypercube read-time merge** — SRE ⊕ ctor-desc × Q_n hypercube structure × type-lattice-merge as domain-merge. This aligns with `structural-thinking.md` § "Hyperlattice Conjecture" and opens the groundwork for Phase 3 (fork-on-union + hypercube integration) to reuse the infrastructure.

### §7.5.1 PU sub-architecture resolutions

| Q | Decision | Rationale |
|---|---|---|
| Q-PU-1 Tagging | **Architecture B** — per-component tagged-cell-value inside the compound PU | Module Theory Realization B applied at the component level; O(1) speculative write cost vs Architecture A's O(N-metas) |
| Q-PU-2 Universe count | **4 per-domain universes** — `type-meta-universe`, `mult-meta-universe`, `level-meta-universe`, `session-meta-universe` | Decomplection: each domain has its own merge semantics (type-lattice-merge / mult-lattice-merge / merge-meta-solve-identity); collapsing entangles. 4→1 collapse is negligible benefit. |
| Q-PU-3 Hasse-registry | **Shared hasse-registry-handle** across all 4 universes | Q_n subsume-fn is uniform (bitmask subset check); one source of truth |
| Q-PU-4 API shape | **(a)** — return meta-id, introduce `elab-meta-read`/`elab-meta-write` | Names meta-id as the identity; cid becomes implementation detail of where the meta's data lives |
| Q-PU-5 Sequencing | **Two-step within 1A-iii-a-wide** — Step 1: TMS retirement + per-cell tagged-cell-value migration + union-inference adaptation; Step 2: PU refactor + hasse-registry integration | Per 1A-ii lesson: one architectural move at a time. Step 1 lands us at per-cell tagged-cell-value (BSP-LE 2B architecture); Step 2 lifts to PU. |
| Q-PU-6 Pre-0 probe | **Required** | Per 1A-ii lesson: behavioral probe captures baseline pre-edit; compares post-edit. ~15-30 min investment for the larger scope. |

### §7.5.2 NTT model for the PU compound cell + hasse-registry

Per NTT Syntax Design §3.2 (structural lattices) + §5.1 (interface declaration) + Hasse-registry integration:

```ntt
;; Per-domain meta universe — one compound cell per domain.
;; Example: type meta universe. Analogous definitions for 'mult, 'level, 'session.

type TypeMetaUniverseValue
  := (hasheq MetaId → TaggedCellValue[TypeExpr])
  :lattice :structural
  :bot (hasheq)

;; Compound merge function: per-component tagged-cell-merge with domain-merge
;; at the base level. Composition of:
;;   (a) hasheq pointwise per meta-id
;;   (b) tagged-cell-merge at each meta-id's TaggedCellValue
;;   (c) type-lattice-merge at each tagged-cell-value's base
trait Lattice TypeMetaUniverseValue
  spec compound-tagged-merge
    TypeMetaUniverseValue TypeMetaUniverseValue -> TypeMetaUniverseValue
  ;; Defined as: for each meta-id in union of keys, merge the per-meta
  ;; tagged-cell-values via make-tagged-merge(type-lattice-merge)

;; Cell declaration — one per domain, pre-allocated at make-prop-network.
cell type-meta-universe
  :type TypeMetaUniverseValue
  :lattice :structural
  :merge compound-tagged-merge
  :classification :structural  ;; PPN 4C Phase 1f: component-path enforcement
  :cell-id type-meta-universe-cell-id

;; Shared hasse-registry handle across all 4 universes.
;; Single instance, used by all per-domain lookups for worldview-bitmask
;; subset check. Per hasse-registry.rkt lines 28-31 + 88 — the Q_n
;; specialization explicitly called out as an override target.
cell shared-worldview-hasse-registry
  :handle (hasse-registry-handle
           :cell-id worldview-entries-cell-id
           :l-domain 'worldview     ;; SRE-registered Q_n lattice (TBD: register in 1A-iii-a Step 2)
           :position-fn (λ (entry) (car entry))   ;; entry = (cons bitmask value); position = bitmask
           :subsume-fn (λ (pos query) (= (bitwise-and pos query) query)))  ;; Q_n subset

;; Per-meta read — component-indexed access via meta-id.
spec elab-meta-read
  :reads [Cell TypeMetaUniverseValue (at type-meta-universe-cell-id)]
  :reads [Cell Bitmask (at worldview-cache-cell-id)]
  ElabNetwork MetaId -> TypeExpr
  ;; Resolution:
  ;;   1. universe ← read(type-meta-universe-cell-id)
  ;;   2. tagged ← (hash-ref universe meta-id (tagged-cell-value type-bot '()))
  ;;   3. wv ← current-worldview-bitmask OR read(worldview-cache-cell-id)
  ;;   4. return tagged-cell-read(tagged, wv, type-lattice-merge)

;; Per-meta write — component-indexed write via meta-id.
spec elab-meta-write
  :reads [Cell TypeMetaUniverseValue (at type-meta-universe-cell-id)]
  :writes [Cell TypeMetaUniverseValue (at type-meta-universe-cell-id)]
  :component-paths [(cons type-meta-universe-cell-id meta-id)]
  ElabNetwork MetaId TypeExpr -> ElabNetwork
  ;; Resolution:
  ;;   1. Build (hasheq meta-id new-val) as delta
  ;;   2. Universe merge fn (compound-tagged-merge) handles:
  ;;      - Union keys from old and delta
  ;;      - For each meta-id, merge existing tagged-cell-value with
  ;;        (tagged-cell-value new-val '()) via make-tagged-merge(type-lattice-merge)
  ;;   3. Component-indexed dependent firing: propagators declaring
  ;;      :component-paths (cons type-meta-universe-cell-id meta-id)
  ;;      fire only if THIS meta changed, not if sibling metas changed.
```

**Observations** (per NTT methodology):

1. **Everything on-network?** Yes. All meta state in compound PU cells; worldview entries in shared hasse-registry cell; zero off-network mirroring. `current-worldview-bitmask` remains as per-propagator-parameter scaffolding (PM Track 12 retirement).

2. **Architectural impurities?** None in the target state. The step-2 migration from per-cell to per-universe is the architectural move; step-1 (per-cell tagged-cell-value) is a transitional state clearly labeled as such.

3. **NTT syntax gaps surfaced?**
   - `compound-tagged-merge` is a new merge-function pattern (per-component tagged-cell-merge). May warrant NTT primitive notation.
   - Shared hasse-registry-handle across multiple cells: NTT has `hasse-registry-handle` struct but unclear whether "shared handle" is first-class in NTT. Flagged for NTT refinement.
   - `:component-paths` for compound-keyed paths (meta-id as key): NTT supports this via `structural-thinking.md`'s Realization B pattern, but explicit NTT notation for `(cons cell-id meta-id)` paths isn't formally spec'd.

4. **Components NTT cannot express?** None at the target state.

### §7.5.3 Step 1 deliverables (TMS retirement + per-cell tagged-cell-value migration + union-inference adaptation)

Per-cell tagged-cell-value migration (retains one-cell-per-meta shape; prerequisite for Step 2's PU refactor).

**Retirement targets** (propagator.rkt):
1. `current-speculation-stack` parameter definition + export
2. 3 fallback branches: `net-cell-read:991`, `net-cell-write:1248`, `net-cell-write-widen:3208+`
3. `net-new-tms-cell` factory
4. `tms-cell-value` struct
5. `tms-read` / `tms-write` / `tms-commit` function definitions
6. `make-tms-merge` / `merge-tms-cell`
7. `propagator.rkt` exports at :143-155 (TMS cell block)

**Type cell migration**:
- `elaborator-network.rkt:114` — `elab-fresh-meta` migrated to `net-new-cell` + `(tagged-cell-value type-bot '())` + `(make-tagged-merge type-lattice-merge)` (matching 1A-ii-a pattern for mult/level/session).

**Union-inference adaptation at typing-propagators.rkt:1878-1920** (Path b):
- Verify lines 1912-1913 `combined-bitmask = bitwise-ior left-bitmask right-bitmask` writes to `worldview-cache-cell-id` correctly
- Verify subsequent reads with combined-bitmask invoke `tagged-cell-read(v, combined-bitmask, type-lattice-merge)` (implicit via domain-merge in Path C of net-cell-read:981-989)
- Post-migration, with type cells = tagged-cell-value, two branches' entries tagged with left-bitmask and right-bitmask respectively; combined-bitmask read finds both entries → domain-merge yields union type via type-lattice-merge
- **Explicit design note**: document this as hypercube read-time merge (Q_n subset lookup with domain-merge composition) — the architecturally-aligned explicit form replacing the pre-migration accidental-of-mechanism TMS dispatch shortcut

**Serialization cleanup** (`pnet-serialize.rkt:392`): remove `(auto-cache! tms-cell-value d d)` — struct being retired; no tagged-cell-value caches exist in production (verified: tagged cells are transient/command-scoped, not in persistent .pnet caches). Old caches invalidate naturally on first load post-retirement.

**test-tms-cell.rkt disposition** (Q-1A-iii-4): delete + rewrite as tagged-cell-value parity tests for representative scenarios (baseline no-speculation, single-branch commit, union-type 2-branch merge, nested speculation, worldview-cache read).

**Deliverables**:
- All TMS mechanism retired
- Type cells at tagged-cell-value (per-cell shape, same as 1A-ii-a'd mult/level/session)
- Union-inference works end-to-end via Path b
- Pre-0 probe + acceptance file + full suite all pass post-step-1

### §7.5.4 Step 2 deliverables (PU refactor + hasse-registry integration)

Per Q-PU-1–Q-PU-5 resolutions. **Revised 2026-04-23 (Option B)**: dropped the proposed `elab-meta-read/write` API in favor of using existing `elab-cell-read/write` + a minimal `compound-cell-component-ref` helper. Rationale: the `elab-meta-*` API would have been a parallel to `that-*` at a different abstraction level, creating a migration cost for Track 4D's eventual storage unification. Step 2 focuses on the STORAGE architectural move (compound PU cells); storage-unification with `that-*` is its own dedicated Phase 1E (§7.6.16). See 2026-04-23 dialogue + `2026-04-23_STEP2_BASELINE.md` for architectural framing.

**New infrastructure**:
1. **4 per-domain PU compound cells** allocated in `make-elaboration-network`:
   - `type-meta-universe-cell-id` — value `(hasheq meta-id → tagged-cell-value-of-type)`, merge `compound-tagged-merge(type-unify-or-top)`, classification `'structural`
   - `mult-meta-universe-cell-id` — analogous, `mult-lattice-merge`
   - `level-meta-universe-cell-id` — analogous, `merge-meta-solve-identity`
   - `session-meta-universe-cell-id` — analogous, `merge-meta-solve-identity`

2. **`compound-tagged-merge`** merge-function factory — new (per Q-PU-1 Architecture B). Takes a domain-merge, returns a merge function for `(hasheq meta-id → tagged-cell-value)`. For each meta-id in the union of keys, merges per-meta tagged-cell-values via `make-tagged-merge(domain-merge)` at the base level. Zero propagation cost for untouched metas.

3. **Shared hasse-registry-handle** — one instance, used by reads across all 4 universes for worldview-bitmask subset check. Q_n subsume-fn specialized per `hasse-registry.rkt` lines 28-31 + 88.

4. **`compound-cell-component-ref(enet, cell-id, component-key)` helper** — minimal convenience wrapper for reading a component from a compound cell's hasheq value. Encapsulates the `(hash-ref (elab-cell-read enet cid) component-key default)` pattern. Used at meta-access sites.

**API (NO new user-facing API)**:
- Existing `elab-cell-read(enet, cid)` and `elab-cell-write(enet, cid, val)` stay as the mid-level cell API.
- `elab-fresh-meta` / `elab-fresh-mult-cell` / `elab-fresh-level-cell` / `elab-fresh-sess-cell` migrate to: register meta-id as a component in the appropriate universe cell (not allocate a new cell). Return meta-id (cell-id returned is the universe-cell-id — same for all metas of a domain).
- `prop-meta-id->cell-id` — returns universe-cell-id for the meta's domain (was per-meta cell-id).
- Meta-access call sites use `(compound-cell-component-ref enet universe-cid meta-id)` instead of `(elab-cell-read enet meta-cid)`.

**Call-site migration** across ~5-10 files:
- `solve-meta-core!` / `solve-meta-core-pure` in metavar-store.rkt
- `elab-cell-read` / `elab-cell-write` callers (propagator fire functions, typing-propagators.rkt, etc.) — for meta-access sites, update to helper form; for infra-cell sites, unchanged
- Propagator installations that reference meta cell-ids — update `:component-paths` declarations to `(cons universe-cell-id meta-id)`

**SRE registration for `'worldview` domain** (if not already registered) — provides Q_n lattice identity for hasse-registry's `:l-domain`.

**Deliverables**:
- 4 per-domain PU cells
- Shared hasse-registry-handle
- `compound-cell-component-ref` helper
- Call-site migrations complete (meta access routes through universe cell + component key)
- Propagator dependency indexing uses compound paths
- Pre-0 probe + acceptance file + full suite all pass post-step-2
- Cell count reduction: per-domain from N → 1 (~hundreds → 4 total cells for meta state)
- Per-meta `fresh-meta` cost: ≤ 2.5 μs/call (per `2026-04-23_STEP2_BASELINE.md` §5 success criteria)

**Sub-phase plan** (revised 2026-04-23 to Option B — 6 sub-phases + VAG, down from original 7+VAG):
- **S2.a** — Infrastructure: `compound-tagged-merge` factory + 4 universe cell-ids + `'worldview` SRE domain + shared hasse-registry-handle + `compound-cell-component-ref` helper. Add A/B bench micros to `bench-meta-lifecycle.rkt` for compound-vs-per-cell access costs. No call-site changes.
- **S2.b** — Migrate `type` domain: `elab-fresh-meta` + call sites. Probe + test. **Measurement checkpoint** (first domain — validates pattern).
- **S2.c** — Migrate `mult` domain.
- **S2.d** — Migrate `level` + `session` domains (simpler identity-or-error semantics).
- **S2.e** — Retire old per-cell factories wholesale. Deletions. **Measurement checkpoint** (final validation vs baselines in `2026-04-23_STEP2_BASELINE.md` §5).
- **S2.f** — Peripheral cleanup (docstrings, stale comments, obsolete tests).
- **S2-VAG** — VAG + D.3 §7.5.13 close section + dailies + final baseline doc §12 "Actual vs Predicted" update.

### §7.5.5 Pre-0 behavioral probe spec

Per Q-PU-6 + 1A-ii lesson. Focused `.prologos` file at `racket/prologos/examples/2026-04-22-1A-iii-probe.prologos` exercising:

1. **Baseline** (no speculation): simple def bindings, plain type metas
2. **Mult cell interaction**: function definition + application (QTT mult-check)
3. **Union types via mixed-type map** (the attempt-1 failure canary): `{:name "alice" :age 30}` + map-get access; expect `Int | String` union inference
4. **Nested union**: `{:a {:b 1 :c "x"} :d #t}` with deep mixed types
5. **Multi-meta solving**: expression with many metas solved together
6. **Level + session meta exercise**: sessionful / level-explicit constructs

**Protocol**:
- Run probe pre-edit (current HEAD post-1A-ii-a + 'mult SRE) — capture output as baseline in `data/probes/2026-04-22-1A-iii-baseline.txt`
- Run probe after Step 1 commit — diff against baseline; any semantic change investigated
- Run probe after Step 2 commit — diff against baseline; any semantic change investigated
- Probe file itself is committed as part of the 1A-iii-probe phase

### §7.5.6 1A-iii-b deliverables (Tier 2 — deprecated atms internal cleanup)

Per Q-1A-iii-5 full-completeness direction.

**atms.rkt retirement**:
- `atms` struct (lines 37, 159-) — delete
- `atms-believed` field — deleted with struct
- `atms-empty` constructor — delete
- Deprecated API functions (all call-sites migrated to solver-context/solver-state):
  - `atms-assume` / `atms-retract` / `atms-add-nogood` / `atms-consistent?` / `atms-with-worldview` / `atms-amb`
  - `atms-read-cell` / `atms-write-cell` / `atms-solve-all`
  - `atms-explain-hypothesis` / `atms-explain`
  - `atms-minimal-diagnoses` / `atms-conflict-graph`
  - `atms-amb-groups` accessor

**Test migrations**:
- `tests/test-atms.rkt` — audit + delete or rewrite using `solver-state`
- `tests/test-atms-types.rkt` — same

**Benchmark migrations**:
- `benchmarks/micro/bench-ppn-track0.rkt` (3+ sites) — migrate or delete cases
- `benchmarks/micro/bench-bsp-le-track2.rkt` (3+ sites) — migrate or delete cases

### §7.5.7 1A-iii-c deliverables (Tier 3 — surface ATMS AST retirement across pipeline)

Per Q-1A-iii-5 full-completeness direction. 14-file pipeline consistency.

**Struct definitions**:
- `syntax.rkt:204-206, 752-755` — delete `expr-atms-*` struct definitions (6 structs)
- `surface-syntax.rkt:925-933` — delete `surf-atms-*` structs (10 structs)

**Pipeline stages**:
- `parser.rkt:2537-2574` — delete surface atms parse rules
- `elaborator.rkt:2438-2466` — delete surface atms elaboration
- `reduction.rkt:2842-3635` — delete surface atms evaluation (~100 lines)
- `zonk.rkt:358-1258` — delete surface atms traversal (~50 lines)
- `pretty-print.rkt` — delete surface atms printing
- `typing-core.rkt` — delete surface atms type-check

**Dependency cleanup**:
- `typing-errors.rkt` / `substitution.rkt` / `qtt.rkt` / `trait-resolution.rkt` / `capability-inference.rkt` / `union-types.rkt` — grep + remove references

**Tests**:
- `tests/test-atms-types.rkt` — delete

### §7.5.8 Sub-A experiment + three architectural findings → Path T pivot (2026-04-22)

**Sub-A experiment** (incremental migration probe per Step 1 plan):
- Migrated only `elab-fresh-meta` at elaborator-network.rkt:114 to `(tagged-cell-value type-bot '())` + `(make-tagged-merge type-lattice-merge)`
- Ran 1A-iii-probe — 6/6 errors reproduced the attempt-1 regression signature (multiplicity violations + unbound variables cascading from unsolved type metas)
- Reverted via `git checkout` (baseline restored, probe diff clean)

**Root cause analysis** revealed three interrelated architectural findings (per user observations in mini-design dialogue 2026-04-22):

#### Finding 1 — Multiple competing sources of truth for speculation worldview

Four mechanisms claim ownership of "what worldview is this read/write under":
1. `current-speculation-stack` parameter (legacy TMS; retiring)
2. `current-worldview-bitmask` parameter (per-propagator, lexically-scoped)
3. `worldview-cache-cell-id` on-network cell (network-wide)
4. `elab-network` snapshot (whole-network rollback state)

Dispatch order determines which is load-bearing. When TMS was load-bearing at net-cell-write:1248 (pre-1A-iii), the bitmask parameterize was harmless. When tagged-cell-value becomes load-bearing, bitmask parameterize activates and breaks try-rollback semantics. This is the "accidental-of-mechanism" pattern hit twice (attempt-1, Sub-A) — a fingerprint of **correct-by-construction violation**.

`with-speculative-rollback` conflates two orthogonal concerns:
- **Speculation tagging**: which worldview is this in? → bitmask parameterize + worldview-cache writes
- **Rollback**: restore pre-speculation state on failure? → elab-net snapshot + restore

These two concerns serve DIFFERENT speculation semantics:
- **Try-rollback** (map-assoc, Church folds, 4 production sites): write provisionally; revert on failure via elab-net snapshot
- **Branch exploration** (expr-union at typing-propagators.rkt:1878-1920): worldview-tagged alternatives; both commit; read-time merge

Pre-migration TMS path IGNORED the bitmask → `with-speculative-rollback` was effectively elab-net-snapshot-only for type cells. That "accidental" correctness breaks post-migration.

#### Finding 2 — Map open-world typing misalignment

Per Prologos ergonomics design, `{:name "Alice" :age 30}` should infer to `Map Keyword _` (open-world, heterogeneous), with `schema Person` providing tighter typing where desired. Current typing-core.rkt:1187-1217 produces `(Map Keyword Int | String)` via explicit `build-union-type` — **overly narrow, contradicts language vision**.

This load-bearing misfeature drives the complicated `with-speculative-rollback` machinery at map-assoc (line 1205). Under open-world typing, there's no reason to try-and-rollback — the value type is `_` regardless of what's written.

#### Finding 3 — Type lattice set-union merge inadequacy

`type-lattice-merge(Int, String) = type-top` (contradiction) is the lattice design issue. A join over a type domain that includes unions SHOULD produce the union for structurally-incompatible atoms, not a contradiction. `type-top` should be reserved for REAL logical contradictions, not the absence of structural unification.

Proposed semantics (set-union merge):
- `merge(Int, String)` = `Int | String` (union via build-union-type)
- `merge(Int | String, Bool)` = `Int | String | Bool` (idempotent over union)
- `merge(Pi a b, Pi c d)` = `Pi (merge a c) (merge b d)` (structural — unchanged)
- `merge(Pi a b, Sigma c d)` = `(Pi a b) | (Sigma c d)` (structurally incompatible → union)
- `type-top` reserved for explicit contradiction signals (certain QTT states, explicit user annotations violated)

If `type-lattice-merge` has set-union semantics:
- Meta double-solve with different types produces union — no contradiction, no speculation needed
- `with-speculative-rollback` for map-assoc becomes unnecessary
- Aligns with Open World principle — merging accumulates options
- Schemas + explicit annotations still produce errors via `check` (subtyping fails)

### §7.5.9 Path T — Work through lattice design first, then reconsider

**User direction 2026-04-22**: "I think we work through T, persisting where designs land back into our current design document ... and see where that lands us in terms of addressing the other points."

**Scoping**:
- **Path T-3** (type lattice set-union redesign) is the **PREREQUISITE** — lattice correctness is foundational; it likely simplifies T-1 and T-2
- **Path T-1** (speculation mechanism consolidation) deferred until T-3 resolves — T-3 may obviate the need for try-rollback speculation in map-assoc, reducing T-1 scope
- **Path T-2** (Map open-world realignment) deferred until T-3 resolves — T-3 + explicit open-world choice may land `_` value type naturally

**1A-iii downstream**:
- **1A-iii-a-wide PAUSED** pending Path T (type cell migration is blocked by the lattice design issue)
- **1A-iii-b (Tier 2 atms cleanup) + 1A-iii-c (Tier 3 surface ATMS AST)** can proceed in parallel with Path T work (independent concerns)

### §7.6 Path T-3 — Type lattice set-union merge redesign

Mini-design resolved in dialogue 2026-04-22. Scope, semantics, and architectural principles captured below. Stage 2 audit (Role A/B call-site classification) is the next concrete work item.

#### §7.6.1 Core semantics — set-union merge (Q-T3-1)

`type-lattice-merge` becomes a set-union join over the type domain:

| Case | Behavior |
|---|---|
| `merge(bot, x)` | `x` (bot is join-identity) |
| `merge(top, x)` | `top` (top is absorbing) |
| `merge(A, A)` | `A` (idempotent) |
| `merge(Int, String)` | `Int \| String` (union via `build-union-type`) |
| `merge(Int \| String, Bool)` | `Int \| String \| Bool` (dedup-append) |
| `merge(Int \| String, Int)` | `Int \| String` (absorption) |
| `merge(Pi a b, Pi c d)` | structural: `Pi merge(a,c) meet(b,d)` if metas/compatibility permit; else `(Pi a b) \| (Pi c d)` |
| `merge(Pi a b, Sigma c d)` | `(Pi a b) \| (Sigma c d)` (structurally incompatible → union at outer level) |
| `merge(?T, Int)` | `Int` (metas unify, don't union; conservative solve — same as current) |
| `merge(?T₁, ?T₂)` | unify → single meta (unchanged) |

**Key principle**: the lattice's join is the powerset/free-distributive completion of the domain. Metas still unify. Atoms and structurally-incompatible types union via `build-union-type`.

#### §7.6.2 `type-top` legitimacy (Q-T3-2)

Post-T-3, `type-top` appears only for **explicit annotation violations during `check`**:
- `(the Int "foo")` — check fails; writer explicitly writes `type-top` to signal contradiction
- Role B callers that enforce equality and find incompatible types (see §7.6.4)

Merge NEVER produces top from structural mismatch. All non-check contradictions surface via the Role B migration (§7.6.4).

#### §7.6.3 Meet dual semantics (Q-T3-3)

Meet becomes set-intersection, dualizing cleanly:
- `meet(Int \| String, Int \| Bool)` = `Int` (intersection)
- `meet(Int, Nat)` = `Nat` if `Nat <: Int` (subtype-preserving; matches existing `type-lattice-meet`)
- `meet(Int, String)` = `bot` (empty intersection)
- `meet(Pi a b, Sigma c d)` = `bot` (structurally empty intersection)

Largely matches current `type-lattice-meet`. Audit verifies that structurally-incompatible meet already produces `bot` (not `top`); if any case produces `top`, adjust to `bot` for consistency.

#### §7.6.4 Q-T3-8 — **CRITICAL: Decouple merge (Role A) from unify-check (Role B)**

Your Q-T3-8 finding identified the **conflation risk** that could turn T-3 into a bug-pocalypse. `type-lattice-merge` currently serves two semantically opposite roles:

**Role A — Lattice join (accumulate)**:
- Incompatible concrete types → **union** (set-union semantics)
- Used when: multiple writes accumulate type information (narrowing, value-type cells, numeric-join, etc.)
- Correct behavior under set-union redesign

**Role B — Unify-check (enforce equality)**:
- Incompatible concrete types → **top** (contradiction)
- Used when: two cells or positions MUST have the same type (make-unify-propagator, check ctx e T, solve-meta! unification)
- **Under naive set-union merge: would silently produce union instead of top, losing contradiction detection**

**Architectural decomplection**:
- `type-lattice-merge(A, B)` = JOIN (Role A — accumulate)
- `try-unify-pure(A, B)` = UNIFICATION check (returns unified OR `#f`)
- Role B callers explicitly use `try-unify-pure` + write `type-top` on `#f`

**Known Role B site**: `make-unify-propagator` at elaborator-network.rkt:152-170 — writes `type-lattice-merge(va, vb)` to both cells; under set-union redesign would silently union instead of contradict. Must migrate.

**Implementation ordering enforcement**:
1. Stage 2 audit: classify every `type-lattice-merge` call site as Role A or Role B
2. Stage 3 design: migration spec for Role B sites
3. Stage 4 implementation (two atomic commits):
   - **Commit A**: migrate ALL Role B call sites to `try-unify-pure + type-top-on-#f` (no semantic change at this point — same behavior, different dispatch)
   - **Commit B**: change `type-lattice-merge` semantics to set-union (Role A call sites gain new semantics; Role B sites already migrated so unaffected)

This ordering is **load-bearing**. Commit B MUST NOT land before Commit A — if it does, Role B silently union where they should contradict.

#### §7.6.5 Meta interactions (Q-T3-5)

**Option (a) eager unify, confirmed**: metas still eagerly unify on merge.
- `merge(?T, Int)` → solve `?T = Int` (conservative; non-meta wins)
- `merge(?T₁, ?T₂)` → unify T₁ and T₂
- Metas don't become first-class union components

Rationale: preserves bidirectional inference semantics. Only structurally-incompatible CONCRETE types produce union.

#### §7.6.6 Q-T3-9 — BSP-LE 2B prior art correctly/incorrectly reused

BSP-LE 2B shipped branch-exploration substrate (`tagged-cell-value`, `worldview-cache-cell-id`, `current-worldview-bitmask`, `fork-prop-network`, hypercube primitives, assumption-tagged dependents). This is the correct substrate for **true branch exploration** (N alternatives, each tagged, committing or retracting).

**Correct reuse** (no architectural change):
- `expr-union` branching at typing-propagators.rkt:1878-1920 — uses `current-worldview-bitmask` parameterize + `worldview-cache` writes directly. This IS branch exploration.
- `atms-amb` / choice points — uses `solver-state-amb` via `fork-prop-network`. True branching.
- NAF handler forks via `fork-prop-network`. True branching.

**Misapplied** (architectural fix needed — T-1):
- `with-speculative-rollback` at elab-speculation-bridge.rkt. Uses BSP-LE 2B branching machinery (bitmask parameterize + worldview-cache writes) plus a SEPARATE `elab-network` snapshot mechanism. The bitmask layer is vestigial scaffolding from TMS-era code; the snapshot layer does the actual rollback work. Under set-union merge (T-3) + proper Role A/B separation, the bitmask layer is not needed for try-rollback semantics.

**T-1 post-T-3 scope**:
- Audit 4 `with-speculative-rollback` callers (qtt.rkt:2425, typing-errors.rkt:78, typing-core.rkt 1205/1291/1325/2439)
- Identify which become unnecessary post-T-3 (likely map-assoc at typing-core.rkt:1205 — set-union merge handles it naturally)
- For remaining callers: remove bitmask parameterize + worldview-cache writes; keep ONLY elab-net snapshot/restore
- Clean decoupling: branch-exploration substrate (BSP-LE 2B) for branching cases; transactional-rollback substrate (elab-net snapshot) for try-rollback cases; no conflation

**Principle** (for the lessons list): *BSP-LE 2B's branch-exploration substrate is distinct from transactional rollback. Applying both to a use case that needs only one is scaffolding conflation.*

#### §7.6.7 Implications for T-2 (Map open-world)

With T-3 landed:
- Set-union merge handles "accumulate types via writes" correctly — map-assoc could write value types and let union emerge naturally
- But ergonomics design says Maps should be open-world (`Map Keyword _`) — narrower unions are misalignment
- T-2 would then decide: does map-assoc still explicitly `build-union-type`, or migrate to open-world (`_` value type)?

Open-world decision: explicit `_` value type unless a schema narrows. `build-union-type` in map-assoc becomes redundant (wrong kind of narrowing).

T-2 is a separate dialogue post-T-3 landing, but T-3 clears the path (no more speculation scaffolding driving the narrow-union path).

#### §7.6.8 Stage 2 audit scope (next step)

**Audit target**: every `type-lattice-merge` call site in the codebase.

**Classification per site**:
- **Role A (accumulate / join)**: multiple writes to a cell that legitimately may have different types; OR narrowing accumulation; OR numeric-join. Site stays on `type-lattice-merge` → gains set-union behavior in Commit B.
- **Role B (enforce equality / unify)**: writes that must agree; OR unification propagators; OR check-style constraints. Site migrates to `try-unify-pure + type-top-on-#f` in Commit A.

**Audit outputs** (persist in §7.6.9):
- Full call-site list with classification
- Migration pattern for Role B sites
- Any ambiguous sites requiring design clarification

**Known starting points**:
- `make-unify-propagator` (elaborator-network.rkt:152-170) — Role B (confirmed)
- `numeric-join` (typing-core.rkt:52) — Role A (join semantics in name)
- `type-lattice-meet` (type-lattice.rkt:178+) — NOT in merge audit but may need consistency check
- External callers: `unify.rkt`, `subtype-predicate.rkt`, etc. — Role A/B TBD per audit

#### §7.6.9 Stage 2 audit findings (2026-04-22)

**Role B sites (4) — MIGRATE to `try-unify-pure + type-top-on-#f` in Commit A**:

All 4 sites compute `(type-lattice-merge va vb)` then check `(type-top? unified)` inline — the equality-enforcement pattern.

1. `elaborator-network.rkt:152-170` — `make-unify-propagator` (bidirectional unify between two cells)
2. `elaborator-network.rkt:178-188` — `elab-add-unify-constraint` FAST PATH (eager merge when both cells ground, no metas)
3. `elaborator-network.rkt:~895-909` — `make-structural-unify-propagator` (unify + structural decomposition)
4. `elaborator-network.rkt:1110-1141` — elaborator-topology stratum handler for pair-decomp

**Role A sites (8) — stay on `type-lattice-merge`, GAIN set-union in Commit B**:

Cell-level merge-fn allocations (accumulate semantics):

5. `elaborator-network.rkt:117` — type meta cells merge-fn
6. `elaborator-network.rkt:332, 335, 338` — structural decomposition sub-cells (3 sites)
7. `cap-type-bridge.rkt:191` — cap-type cell merge-fn
8. `session-type-bridge.rkt:115, 124` — session-type cell merge-fns (2 sites)
9. `classify-inhabit.rkt:163` — classifier × classifier quantale join

**Internal meet-recurse (2) — stay on `type-lattice-merge` (Role A in context)**:

10. `type-lattice.rkt:245` — Pi domain merge (contravariant = join inside `try-intersect-pure`)
11. `type-lattice.rkt:291` — generic descriptor-driven meet, contravariant components → join

**SRE dispatch tables (2) — reference `type-lattice-merge` as `'equality` merge**:

12. `subtype-predicate.rkt:359` — `subtype-query-merge-table`
13. `unify.rkt:71` — similar hasheq dispatch table

These are indirect call sites; SRE consumers resolve 'equality and call the returned merge. Under set-union redesign, SRE's 'equality merge gains union semantics for incompatible atoms. Consumer audit needed to confirm no Role B consumers — likely Role A based on SRE's "equality relation as accumulation" framing.

**Tests (7 assertions) — MUST UPDATE in Commit B**:

14. `tests/test-type-lattice.rkt:39` — `(check-equal? (type-lattice-merge (expr-Nat) (expr-Bool)) type-top)` → `(expr-union (expr-Bool) (expr-Nat))` (dedup-sorted)
15. `tests/test-type-lattice.rkt:42-44` — top absorbing tests (unchanged — top absorbing stays)
16. `tests/test-type-lattice.rkt:72` — `merge(Pi, Sigma) = type-top` → expect union
17. `tests/test-type-lattice.rkt:85` — similar

**Prior art template** (subtype-predicate.rkt:339-353 `subtype-lattice-merge`):

SRE Track 2H already applied set-union redesign to the SUBTYPE relation. T-3 applies the same pattern to the EQUALITY relation. The only structural difference: equality drops the `(subtype? a b)` + `(subtype? b a)` absorptions; keeps `equal?` absorption + meta conservative + union fallback.

**Audit summary**:

| Category | Count | Action |
|---|---|---|
| Role B (equality-enforce, inline type-top check) | 4 | Commit A: migrate to `try-unify-pure + explicit type-top-on-#f` |
| Role A (cell merge-fn, accumulate) | 8 | Commit B: gain set-union semantics automatically |
| Internal meet-recurse | 2 | No change needed (Role A in context) |
| SRE dispatch tables | 2 | Consumer audit; likely Role A |
| Tests | 7 assertions | Commit B: update expected values to unions |
| Benchmarks | 1 file | No change; performance validation reference |

**Scope is well-contained**: 4 Role B sites to migrate + 7 test assertions to update + one ~3-line change to `type-lattice-merge`. The `subtype-lattice-merge` prior art validates the pattern.

#### §7.6.10 Stage 3 design (2026-04-22)

**Target `type-lattice-merge` implementation** (applies `subtype-lattice-merge` template to equality relation):

```racket
(define (type-lattice-merge a b)
  (cond
    [(type-bot? a) b]                              ;; identity
    [(type-bot? b) a]
    [(type-top? a) type-top]                       ;; top absorbing
    [(type-top? b) type-top]
    [(eq? a b) a]                                  ;; pointer-equal fast path
    [(equal? a b) a]                               ;; structurally equal
    [(or (has-unsolved-meta? a) (has-unsolved-meta? b))
     ;; Meta handling (conservative): keep non-meta side
     (if (has-unsolved-meta? a) b a)]
    [else
     ;; Structurally compatible → try structural merge; else → union
     (or (try-unify-pure a b)
         (build-union-type-with-absorption (list a b)))]))
```

Net change from current (type-lattice.rkt:140-158): replace the final `[else type-top]` (line 158) with `(or (try-unify-pure a b) (build-union-type-with-absorption (list a b)))`. Lines 149-157 stay as-is (top absorbing, eq?, equal?, metas). Approximately **3-line change**.

**Role B migration pattern** (for Commit A):

```racket
;; BEFORE (current make-unify-propagator at elaborator-network.rkt:163-170):
(define unified (type-lattice-merge va vb))
(if (type-top? unified)
    (net-cell-write net cell-a type-top)
    (let ([net* (net-cell-write net cell-a unified)])
      (net-cell-write net* cell-b unified)))

;; AFTER (Commit A migration — try-unify-pure + explicit top-on-#f):
(define unified-opt (try-unify-pure va vb))
(cond
  [(not unified-opt)
   ;; Incompatible — write type-top explicitly (equality enforcement)
   (net-cell-write net cell-a type-top)]
  [else
   ;; Compatible — write unified to both
   (let ([net* (net-cell-write net cell-a unified-opt)])
     (net-cell-write net* cell-b unified-opt))])
```

Same migration for lines 186, 902, 1121 (minor variations per context).

**Why Commit A first is safe**: `try-unify-pure` is called internally by current `type-lattice-merge` (line 149 of type-lattice.rkt), so its semantics are already load-bearing. Migrating Role B sites to call it directly doesn't change behavior — same unified-or-#f outcome. The explicit `type-top` write on `#f` matches what the merge-then-check-top flow produces under the current `[else type-top]` fallthrough. **Zero behavior change**; preparation for Commit B.

**Why Commit B is safe after Commit A**: Role A sites call `type-lattice-merge` and accept ANY result (union is fine for accumulation). Role B sites no longer call `type-lattice-merge` for equality checks. So changing merge's `[else type-top]` to set-union only affects Role A callers — who welcome the union.

**Test updates (Commit B)**:
- `tests/test-type-lattice.rkt`: update 7 assertions expecting type-top for incompatible atoms → expect unions
- Update absorption tests to include new "incompatible → union" cases
- Add tests confirming `merge(Int | String, Bool) = Int | String | Bool` and `merge(Int | String, Int) = Int | String`

#### §7.6.11 Stage 4 implementation plan (confirmed)

Two atomic commits. Each validated against probe + acceptance file + full suite.

**Commit A — Role B migration** (~100-150 LoC across elaborator-network.rkt):
- Migrate 4 Role B sites to `try-unify-pure + type-top-on-#f` pattern
- NO change to `type-lattice-merge` semantics
- NO change to tests (Role B sites preserved behavior exactly)
- Validation: probe diff = 0; acceptance file 0 errors; full suite unchanged

**Commit B — Merge semantics change** (~10-15 LoC across type-lattice.rkt + ~30-50 LoC test updates):
- Change `type-lattice-merge` fallthrough from `type-top` to `build-union-type-with-absorption`
- Update 7 test assertions + add new cases for union production
- Validation: probe may change (map-assoc behavior now produces union via merge not speculation); full suite regression investigated

**Consumer audit for SRE dispatch tables** (during Commit A): verify `subtype-query-merge-table` and `unify.rkt`'s dispatch table consumers are Role A (they call merge and accept any result). If any Role B consumer exists, migrate in Commit A.

**Post-implementation**: T-3 ships. Then revisit:
- T-1 (speculation mechanism consolidation): now simplified — many try-rollback sites become unnecessary since set-union merge handles type-incompatibility naturally
- T-2 (Map open-world): typing-core.rkt:1196-1217's explicit `build-union-type` becomes redundant (merge does it automatically) OR map-assoc migrates to `_` open-world value type (user's ergonomics choice)
- 1A-iii-a-wide: type cell migration becomes straightforward since the conflated mechanisms are now decoupled

#### §7.6.11 Stage 4 implementation

Two atomic commits (per §7.6.4 ordering):
- **Commit A**: Role B call sites migrate to `type-unify-or-top + type-top-on-#f` — no semantic change (current merge behavior preserved for these sites via explicit dispatch)
- **Commit B**: `type-lattice-merge` gains set-union behavior — Role A call sites gain union construction; Role B sites already migrated so unaffected

**Commit A DELIVERED** (commit `37aaba2b`, 2026-04-22):
- Added `type-unify-or-top` helper in type-lattice.rkt (encodes current merge semantics)
- Migrated 4 Role B sites in elaborator-network.rkt (make-unify-propagator, elab-add-unify-constraint fast path, make-structural-unify-propagator, pair-decomp topology handler)
- Zero semantic change — probe diff = 0, 129 targeted tests pass
- Stable; ready for Commit B

**Commit B PAUSED** (2026-04-22) — see §7.6.12 for rationale.

#### §7.6.12 Third accidentally-load-bearing mechanism finding + T3-C3 decision (2026-04-22)

Commit B (`type-lattice-merge` set-union fallthrough) was implemented and tested. Post-change, `test-union-types.rkt:234` regressed: `(infer <Nat | Bool>)` returned `"Bool | Nat"` instead of `"[Type 0]"`.

**Diagnostic**: reverted only Commit B's fallthrough change (keeping Commit A, keeping type-type-lattice.rkt's test updates temporarily) — test PASSED. Confirmed regression source is specifically Commit B's set-union change.

**Root cause — THIRD accidentally-load-bearing mechanism in the series**:

At typing-propagators.rkt:1907/1919, the on-network expr-union typing writes the branch component types (Nat, Bool) to position `e`'s `:type` classifier facet under bitmask-tagged branches. Pre-T-3 Commit B, `type-lattice-merge(Nat, Bool) = type-top` → cell accumulates `type-top` → downstream logic detects this and falls back to the sexp-based `infer` at typing-core.rkt:459, which correctly returns `[Type 0]` via `infer-level`.

Post-T-3 Commit B, merge produces `Bool | Nat` → cell has valid union → no contradiction signal → no fallback → returns garbage union value as the TYPE of the union-type expression (which should be `[Type 0]`, the universe).

**Pattern confirmed across this addendum** (third occurrence):

1. **Attempt 1** (1A-ii attempt 1 reverted): TMS dispatch at net-cell-write:1248 was load-bearing for union-type inference via `tms-write old '() new` updating BASE regardless of bitmask.
2. **Sub-A** (reverted): `with-speculative-rollback`'s bitmask parameterize was redundant when TMS path was active; became load-bearing when tagged-cell-value activated.
3. **Commit B** (paused): expr-union typing's `type-lattice-merge → type-top` was load-bearing for `[Type 0]` fallback via contradiction-detection path.

Each mechanism did its real work through a different pipe than its obvious API. Migrating the obvious API surfaces the hidden dependency. This vindicates the "correct-by-construction via decomplection" direction — hidden fallback dependencies are the bug source.

**User direction 2026-04-22 (accepting Path T3-C3)**: before landing Commit B, perform a **systematic re-audit** to identify ALL similar hidden dependencies. Avoid the whack-a-mole pattern of fixing one at a time.

**T3-C3 re-audit scope** (NEXT SESSION):

1. **Grep for inline `(type-top? ...)` checks** that might be contradiction-detection-as-fallback in contexts where `type-lattice-merge` result is inspected (direct or indirect via `net-cell-read` on cells using `type-lattice-merge` as merge-fn + `type-lattice-contradicts?` as the predicate).
2. **Grep for `(type-lattice-contradicts? ...)` consumers** — what triggers downstream when this fires? Are any consumers depending on spurious contradictions from structural mismatch (not real contradictions)?
3. **Audit typing-propagators.rkt:1878-1920 (expr-union typing)**: the writes at 1907/1919 ARE wrong — they write component types instead of `[Type 0]`. Fix to write `(expr-Type (infer-level ...))` or similar. This is architecturally correct AND removes the type-top fallback dependency.
4. **Audit other expr-foo typing in typing-propagators.rkt** for similar patterns: writing component types that rely on merge-produces-top-on-incompat to get the real answer via fallback.
5. **Audit cell merge-fn uses with `type-lattice-contradicts?`**: these cells' behavior changes under set-union semantics. Any logic that relied on the cell going to type-top for incompatible writes is Role B in disguise.

**Commit B blocked pending audit completion and Role B migrations for all discovered sites.**

**Principle surfaced** (for codification after next session):
> **Contradiction-detection-as-fallback is a hidden Role B pattern.** When code writes a value and expects `type-top` to trigger a downstream fallback (instead of explicitly signaling the intent via `type-unify-or-top + type-top-on-#f`), it's relying on merge-produces-top-on-incompat as an implicit contradiction signal. Under set-union merge (Role A), this contradiction signal disappears. All such sites must be audited and explicitly migrated to Role B semantics.

#### §7.6.13 Stage 2 audit COMPLETION criteria (for next session)

Original §7.6.9 audit found 4 Role B sites via grep for inline `(type-top? ...)` after `type-lattice-merge`. **Incomplete** — missed:

- **Contradiction-detection-as-fallback sites**: code that writes via type-lattice-merge without inline check but relies on downstream type-top-detection for correctness
- **Cell merge-fn sites with behavioral dependency**: cells with merge-fn = type-lattice-merge that have consumers expecting type-top propagation for specific semantics

Enhanced audit criteria:
- **Audit item 1 (inline checks — DONE §7.6.9)**: sites with `(type-top? unified)` after calling type-lattice-merge or reading a cell that uses it
- **Audit item 2 (downstream fallback — NEW)**: sites that write to cells using type-lattice-merge and rely on downstream type-top detection for semantic correctness. Requires tracing merge results through cell writes to consumer reads.
- **Audit item 3 (cell contradicts? consumers — NEW)**: consumers of `type-lattice-contradicts?` or `net-contradiction?` downstream of cells using type-lattice-merge as merge-fn.

Each site identified in items 2/3 needs migration analysis — might be Role B (migrate to explicit contradiction signal) OR might be architecturally wrong (like typing-propagators.rkt:1907/1919, which should write the universe type not the component types).

#### §7.6.14 T3-C3 re-audit results (2026-04-22)

Executed Q3 C3 full grep classification of every `(type-top? ...)` consumer + Q2 install-caller audit. Findings:

**Category A — MIGRATED Role B sites (Commit A, verified)** — 4 sites in elaborator-network.rkt: make-unify-propagator, elab-add-unify-constraint fast path, make-structural-unify-propagator, pair-decomp topology handler. No changes needed; Commit A preserved these correctly.

**Category B — NEW Role B sites (§7.6.9 audit missed these)** — 5 sites requiring migration:

*Write-expected-type-then-check-merge-top pattern (fix via centralized helper)*:
- **B1**: `typing-propagators.rkt:1160+1164` — app fire function writes `dom` (expected domain) to arg-pos, checks `arg-after-merge` for type-top. Pattern: write equality constraint via merge, expect merge-produces-top on mismatch.
- **B2**: `typing-propagators.rkt:1930+1932+1942` — expr-ann writes annotation to term position, contradiction propagator checks term-type for type-top. Same pattern.

*Cell merge-fn using Role A semantics where Role B needed (fix via merge-fn swap)*:
- **B3**: `classify-inhabit.rkt:163` — classifier × classifier merge uses `type-lattice-merge` inside merge-classify-inhabit; expects equality enforcement (Q5 confirmed Role B).
- **B4**: `cap-type-bridge.rkt:191` — function-type cell's merge-fn = `type-lattice-merge`; each function has ONE type.
- **B5**: `session-type-bridge.rkt:115/124` — Send/Recv message-type cells' merge-fns; each channel has ONE message type per direction.

**Category C — Architectural error (not merge semantics)** — 1 site:
- **C1**: `typing-propagators.rkt:1878-1920` expr-union install — writes COMPONENT types (left, right) to position `e`'s :type, with misplaced Phase 8 Option D worldview-bitmask branching at INFER time. Fix: `make-union-fire-fn` paralleling `make-pi-fire-fn` — writes `(expr-Type (lmax level(left) level(right)))`.

**Category L — LEGITIMATE type-top consumers (no change needed)**:
- 10 reconstructor propagators in elaborator-network.rkt (decompose-pi/sigma/eq/vec/map/pair/lam, make-*-reconstructor, generic reconstructor) — correctly propagate type-top from child to parent under ANY merge semantics (real contradictions still propagate)
- 12 readiness checks in metavar-store.rkt — "solved = not bot AND not top" defense
- Internal lattice operations (type-lattice.rkt, subtype-predicate.rkt)
- Defense code (cap-type-bridge.rkt:97, session-type-bridge.rkt:337) — fire only for real contradictions under new semantics
- Root fallback gate (typing-propagators.rkt:2319) — catches REAL failures (annotation violations) after C1 fix; sexp fallback becomes defensive rather than load-bearing
- Tensor result check (typing-propagators.rkt:1217) — type-tensor-core returns type-top only for genuine tensor contradictions

**Q2 install-caller audit (branching use at check time)** — RESOLVED:

`install-typing-network` has ONE production caller (typing-propagators.rkt:2220, top-level infer entry). No check-time invocation. The expr-union case's Phase 8 Option D branching at INFER time is therefore misplaced. Check-time branching against union types (if needed in future) belongs in typing-errors.rkt:check/err, not install. Confirmed Option A2 (remove branching, install make-union-fire-fn).

**Refined Commit A.2 structure (Q4 S2 staged)**:

- **Commit A.2-a** (architectural fix C1) — standalone-safe under BOTH current and post-Commit-B merge semantics. LANDS FIRST.
- **Commit A.2-b** (centralized `type-map-write-unified` helper + B1 + B2 migrations) — Role B equality-enforcement writes via explicit helper.
- **Commit A.2-c** (merge-fn swaps B3 + B4 + B5) — cells that should have Role B semantics use `type-unify-or-top` as merge-fn directly.
- **Commit B** (merge semantics change) — `type-lattice-merge` fallthrough: `type-top` → `build-union-type-with-absorption`. All Role B sites insulated by prior commits; Role A sites gain set-union semantics cleanly.

Each commit validated independently (probe diff = 0, targeted tests green). Commit B validated additionally by test-union-types:234 passing (the canary).

### §7.5.10 Charter alignment — re-sequencing post-T-3 (2026-04-22)

**Context**: post-T-3 completion, the active queue had T-1/T-2/1A-iii-a-wide listed as parallel "unblocked" items. Dialogue 2026-04-22 surfaced that this framing treated tactical cleanups (T-1, T-2) in isolation from the larger PPN 4C charter ("bring elaboration completely on-network"). Re-framing against end-state collapsed several design decisions.

**End-state reference** (from [PPN 4C D.3 §1](2026-04-17_PPN_TRACK4C_DESIGN.md), §6.3, §6.10, main-track Phase 4 + Phase 9 + Phase 11 + Phase 12):
- All elaboration state in AttributeMap `:type` facet (Phase 4 β2)
- All speculation via BSP-LE 1.5 cell-based TMS (Phase 9 — worldview-cells + tagged-cell-value)
- `current-speculation-stack` parameter retired (Phase 9 Phase D)
- `meta-info` CHAMP retired wholesale (Phase 4 close)
- Union types via ATMS branching on the cell-based-TMS substrate (Phase 10)
- Stratification orchestrated by BSP scheduler alone (Phase 11)
- Zonk wholesale deleted (Phase 12)
- **Under end-state: `with-speculative-rollback` doesn't exist**; replaced by ATMS-tagged writes + nogood-recording. No snapshot. No rollback concept in the user API.

**The gap**: off-network state (meta-info CHAMP + constraint store + id-map). Until migrated, `with-speculative-rollback`'s elab-net snapshot remains as scaffolding for off-network residue.

**What blocks retiring scaffolding**:
- meta-info CHAMP retirement → **Phase 4 of main track** (immediate follow-on to this addendum)
- constraint store + id-map retirement → **PM Track 12** (on-network registries)

**Re-sequencing decision**:

```
CURRENT queue (parallel-unblocked):    T-1 ‖ T-2 ‖ 1A-iii-a-wide Step 1 ‖ Step 2

PIVOTED queue (dependency-ordered):    1A-iii-a-wide Step 1 → T-1 → T-2 → Step 2
```

Rationale:
1. **Step 1 IS the addendum's Phase 1 substrate migration charter continuation** (§7.5.3). Type cells migrate to `tagged-cell-value`; TMS mechanism retires; `current-speculation-stack` retires. This is CHARTER work, not tactical cleanup.
2. **T-1 post-Step-1 becomes tractable cleanup**: bitmask layer becomes architecturally sound (writes tagged directly on the new substrate); elab-net snapshot is named as scaffolding with explicit retirement tied to Phase 4 + PM 12; no new API needed.
3. **T-2 post-Step-1 becomes mechanical verification**: T-3 set-union merge subsumes map-assoc's explicit `build-union-type`; `_` open-world decision completes the realignment.
4. **Step 2 (PU refactor)** is the vision-advancing capstone of Phase 1A per §7.5.4.

**Scope boundaries clarified**:
- **In this addendum**: Step 1 substrate delivery + T-1 scaffolding-plan + T-2 verification + Step 2 PU refactor. Remaining Phases 1B/1C/1V/2/3/V per original plan.
- **Immediate follow-on (main track Phase 4)**: `meta-info` CHAMP retirement, migrating meta storage entirely onto the Phase 9 substrate + attribute-map `:type` facet. User direction 2026-04-22: Phase 4 immediately follows the addendum; if specific Phase-4 aspects need to be pulled forward into the addendum, that can be evaluated, but absorbing Phase 4 wholesale is not required.
- **Later tracks**: PM Track 12 (on-network registries), Phase 10/11/12 per main track.

**Framing principle codified** (candidate for DEVELOPMENT_LESSONS.org, see dailies 2026-04-22):
> *Tactical cleanup tracks should be framed against end-state architecture, not as local optimizations.* When a tactical task (simplify X, decouple Y) surfaces, first check whether X or Y is a LOCAL view of a LARGER architectural change already planned. If yes, frame the tactical work as a way-station toward the end-state — naming scaffolding with explicit retirement plans tied to specific follow-on tracks. Designing in isolation produces MORE infrastructure that preserves the current mechanism indefinitely; framing against end-state produces SCAFFOLDING with retirement plans. Origin: T-1 scope dialogue 2026-04-22 — isolated framing would have built a new `with-transactional-rollback` API; charter-aligned framing recognizes `with-speculative-rollback` as vestigial en route to ATMS-tagged writes, and reduces T-1 to a scaffolding-retirement-plan labeling exercise.

### §7.5.11 1A-iii-a-wide Step 1 summary (2026-04-22) — DELIVERED

Phase 1 substrate migration charter (§7.5.3) complete. 5 atomic sub-phase commits delivered the TMS-to-tagged-cell-value migration for the type meta cell (the last TMS consumer).

**Sub-phase commits**:

| Sub-phase | Commit | Delivery |
|---|---|---|
| S1.a | `3b6aefdb` | `elab-fresh-meta` factory migrated: `net-new-tms-cell` → `net-new-cell` + `(tagged-cell-value type-bot '())` + `(make-tagged-merge type-unify-or-top)` + custom contradicts? wrapper. **4th "accidentally-load-bearing mechanism" finding FIXED inline** via `with-speculative-rollback` parameterize scope (include worldview-cache bits, not just hyp-bit — see below). Localized fix preserves BSP-LE 2/2B clause-propagator isolation for global net-cell-read. |
| S1.b | `2c8871ec` | Retired 3 TMS fallback branches in propagator.rkt (net-cell-read:991-996, net-cell-write:1248-1250, net-cell-write-widen:3222-3225). Dead code post-S1.a. |
| S1.c | `d220ca51` | Retired TMS API wholesale (~258 lines from propagator.rkt): `tms-cell-value` struct, `tms-read`/`tms-write`/`tms-commit` functions, `net-commit-assumption`, `tms-retract`/`net-retract-assumption`, `merge-tms-cell`/`make-tms-merge`, `net-new-tms-cell` factory. Plus pnet-serialize.rkt cleanup (import + auto-cache). |
| S1.d | `9f47ffe9` | Retired `current-speculation-stack` parameter from propagator.rkt. Zero live consumers post-S1.c. |
| S1.e | `b1468220` | Peripheral cleanup: deleted `tests/test-tms-cell.rkt` (370 lines, 34 tests — mechanism-specific for retired API); updated stale comments in cell-ops.rkt (worldview-visible? rationale, elab-cell-read-worldview docstring) to reflect post-TMS semantics. |

**Fourth accidentally-load-bearing mechanism — details for codification**:

S1.a's initial migration surfaced a latent architectural issue in `with-speculative-rollback`. Pre-S1.a, type meta cells were TMS-wrapped. Writes during speculation hit propagator.rkt:1248's TMS fallback (`tms-write old (current-speculation-stack='()) new`) which updated BASE regardless of the bitmask parameterize. Prior-committed speculation results were trivially visible.

Post-S1.a, the bitmask layer activates. But `with-speculative-rollback` parameterized `current-worldview-bitmask` to ONLY `hyp-bit`, which under net-cell-read's tagged-cell-value dispatch (propagator.rkt:968-975) **OVERRIDES** worldview-cache entirely (per-propagator isolation semantic for BSP-LE 2/2B clause propagators). Result: prior-committed speculation results INVISIBLE during subsequent speculation — back-to-back `map-assoc` broke (canary: test-mixed-map failures on nested/mixed maps).

This is the **4th instance** of the "accidentally-load-bearing mechanism" pattern in this addendum (attempt-1 TMS dispatch → Sub-A with-speculative-rollback bitmask scaffolding → Commit B expr-union typing contradiction-fallback → S1.a visibility scope). Significantly, it was surfaced by BEHAVIOR (test-mixed-map failure), not static audit. Confirms the Stage 2 audit discipline needs integration-test coverage, not just grep-based site enumeration.

**Fix** (localized, preserves clause-propagator isolation): parameterize `current-worldview-bitmask` to the FULL worldview (`outer-active | worldview-cache | hyp-bit`) instead of just `hyp-bit`. Fix is in `with-speculative-rollback`, not in global `net-cell-read`. Documented with full rationale in elab-speculation-bridge.rkt.

**Vision Alignment Gate (all 4 questions pass)**:

- **(a) On-network?** YES. TMS mechanism fully retired. Speculation-tagging flows through tagged-cell-value + worldview-cache-cell + current-worldview-bitmask (all on-network except the parameter, which is per-propagator scaffolding tied to PM Track 12 retirement). Remaining scaffolding explicitly labeled: elab-net snapshot for off-network residue (meta-info CHAMP + constraint store + id-map) — retires with Phase 4 + PM 12.
- **(b) Complete?** YES. All 5 sub-phases landed per plan. Union-inference adaptation (originally in Step 1 scope per §7.5.3) was already delivered via T-3 Commit A.2-a's `make-union-fire-fn` — no additional work required. Zero TMS consumers in production code.
- **(c) Vision-advancing?** YES. Completes the addendum's Phase 1 substrate migration charter. BSP-LE 2/2B's tagged-cell-value is now the sole speculation mechanism for on-network state. Aligns with PPN 4C end-state (§6.3, §6.10). Brings us closer to Level-3 ideal (pure branch-exploration, no rollback concept) per §7.5.10 charter alignment.
- **(d) Drift-risks-cleared?** YES. The 4th accidentally-load-bearing finding was discovered mid-S1.a and FIXED inline (not deferred). No other drift detected across 5 sub-phases.

**Aggregate statistics**:

| Metric | Value |
|---|---|
| Sub-phase commits | 5 (S1.a-e) |
| Production files modified | 4 (elaborator-network.rkt, propagator.rkt, elab-speculation-bridge.rkt, pnet-serialize.rkt, cell-ops.rkt) |
| Lines deleted from propagator.rkt | ~258 (TMS API block) |
| Tests deleted | 34 (test-tms-cell.rkt; mechanism obsolete) |
| Full suite | 7908 tests, 126.7s (down from 7942 — matches test-tms-cell.rkt deletion) |
| Probe diff vs baseline | 0 (28 expressions identical) |

**Fourth-finding codification candidate** (dailies 2026-04-22 watching list, promote if 5th instance observed):

> *Accidentally-load-bearing mechanisms are often surfaced by integration-test behavior, not static audit.* Stage 2 audits that grep for inline predicates (e.g., `(type-top? ...)`, `(tms-cell-value? ...)`) catch SOME sites. They miss sites where a mechanism's BEHAVIOR — not its obvious API — is load-bearing downstream. B6 (T-3 Commit B, type meta cell merge-fn) and S1.a (visibility scope in with-speculative-rollback parameterize) were both surfaced by test-failure-during-integration, not by static audit. Implication: Stage 2 audits for API migrations must include integration-test runs of realistic workloads, not just static site enumeration.

### §7.5.12 Step 2 S2.b Sub-phase Mini-design (2026-04-24)

Opening conversational mini-design for S2.b per the refined Stage 4 methodology (mini-design + mini-audit outcomes persist to the design doc; see DESIGN_METHODOLOGY.org Stage 4 Per-Phase Protocol edits codified 2026-04-23). Context: post-S2.a-followup (`2bab505a`), S2.b rescoped to Option S2.b-staged (§7.5.4) after the attempted full migration surfaced 3 caller categories exceeding the original 200-400 LoC estimate.

#### §7.5.12.1 Caller categories (grep-verified)

Migration target for S2.b: the TYPE domain (mult/level/session are S2.c/d scope). Three categories of call sites consume meta cell identity:

**Category 1 — Readers via `meta-solution/cell-id`** (9 production sites):
- `unify.rkt:206`, `:259`, `:430`
- `zonk.rkt:55`, `:496`
- `typing-core.rkt:2818`
- `reduction.rkt:3176`
- `trait-resolution.rkt:57`, `:119`
- `pretty-print.rkt:82`

These reach meta values through the centralized reader; dispatch can be added at that centralized site without touching any caller.

**Category 2 — Direct `prop-meta-id->cell-id` + `expr-meta-cell-id` consumers** (the silent class — root cause of the reverted `#hasheq()` failure mode):
- `metavar-store.rkt:455` — `dict-cell-id` (bridge-fn output target for trait resolution)
- `metavar-store.rkt:618` — `hm-cell-id` (bridge-fn output target for hasmethod)
- `metavar-store.rkt:1780` — `solve-meta-core!` write path
- `metavar-store.rkt:627` — `expr-meta-cell-id` for trait-var-cell-id
- `metavar-store.rkt:694` — resolve path (internal dispatch)
- `driver.rkt:2661` — `mult-cid` callback (mult domain — S2.c scope)
- `driver.rkt:2653` — `expr-meta-cell-id` direct access
- `unify.rkt:258` — `expr-meta-cell-id` direct access

These treat the returned cell-id as a direct cell, bypassing the centralized reader. Must migrate explicitly to `compound-cell-component-ref`/`compound-cell-component-write` (S2.a helper) with `(universe-cid, meta-id)` as the identity.

**Category 3 — Propagator installations with meta cell-id as OUTPUT target**:
- `metavar-store.rkt:463` — `elab-add-propagator ... (list dict-cell-id) ...` for trait bridge-fn
- `metavar-store.rkt:636` — `elab-add-propagator ... (list hm-cell-id) ...` for hasmethod bridge-fn
- `resolution.rkt:428+` — `make-pure-trait-bridge-fire-fn` factory (fire-fn writes via `net-cell-write pnet dict-cell-id`)
- `resolution.rkt` — `make-pure-hasmethod-bridge-fire-fn` analog

Under S2.b, the output cell-id becomes a universe-cid; the fire function must route writes through `compound-cell-component-write` (component-keyed by meta-id), and the installation's `:component-paths` declaration becomes `(cons universe-cid meta-id)` so the scheduler's dependent firing is meta-specific (not whole-universe).

#### §7.5.12.2 Migration patterns per category

**Category 1 → centralized dispatch in `meta-solution/cell-id`**:
```racket
;; At metavar-store.rkt:2011, inside meta-solution/cell-id:
(cond
  [(meta-universe-cell-id? cell-id)
   (with-handlers ([exn:fail? (lambda (_) (meta-solution id))])
     (let ([v (compound-cell-component-ref enet cell-id id)])
       (and (not (prop-type-bot? v)) (not (prop-type-top? v)) v)))]
  ;; ... existing direct-cell-read path for non-universe cell-ids ...)
```
All 9 Category 1 callers remain unchanged. Dispatch overhead is a single predicate call + hash-ref (~50 ns per S2.a benchmarks) — negligible vs. the 113 ns baseline direct read.

**Category 2 → explicit compound-cell-component-ref/write at each site**:
```racket
;; BEFORE (e.g., solve-meta-core!:1780)
(set-box! net-box (elab-cell-write (unbox net-box) cid solution))

;; AFTER
(set-box! net-box (compound-cell-component-write (unbox net-box) cid id solution))
```
Each Category 2 site needs the (universe-cid, meta-id) tuple explicit. Where the site receives only a cid (having called `prop-meta-id->cell-id`), we need the meta-id as well — which means updating the callsite to pass both or refactoring the surrounding function signature.

**Category 3 → bridge-fn factory updates + component-paths**:
```racket
;; resolution.rkt make-pure-trait-bridge-fire-fn BEFORE
(net-cell-write pnet dict-cell-id dict-expr)

;; AFTER — factory closes over (universe-cid, meta-id) pair
(compound-cell-component-write pnet dict-universe-cid dict-meta-id dict-expr)

;; installation site (metavar-store.rkt:463) BEFORE
(elab-add-propagator net dep-cids (list dict-cell-id) fire-fn
                     #:component-paths ... )

;; AFTER — path is bare meta-id symbol per §7.5.12.5 verification
(elab-add-propagator net dep-cids (list type-meta-universe-cell-id) fire-fn
                     #:component-paths (list dict-meta-id))
```

#### §7.5.12.3 Sub-phase partition

| Sub-phase | Scope | Est. LoC | Deliverables |
|---|---|---|---|
| **S2.b-ii** | Centralized reader dispatch in `meta-solution/cell-id` + scheduler component-path verification | ~50-100 | Category 1 readers transparent; scheduler's `filter-dependents-by-paths` confirmed supporting cons-pair component-paths (or remediation scope identified) |
| **S2.b-iii** | `elab-fresh-meta` migration + Category 2 direct consumers (TYPE domain only) | ~200-300 | Factory registers meta-id as universe component; all direct `prop-meta-id->cell-id` consumers updated. **Probe checkpoint** after this sub-phase before b-iv. |
| **S2.b-iv** | Category 3 propagator installation migration (bridge-fn factories + component-paths) | ~100-150 | Trait bridge + hasmethod bridge factories write via `compound-cell-component-write`; component-paths use `(cons universe-cell-id meta-id)` for meta-specific dependent firing |
| **S2.b-v** | Driver callback residual + probe + targeted suite + **measurement checkpoint** per §7.5.4 + STEP2_BASELINE §5 | ~50 LoC + measurement | bench-meta-lifecycle E1-E5 + probe diff = 0 vs baseline; compare to hypotheses; go/no-go for S2.c |

**Ordering rationale**: b-ii dispatch-first lets Category 1 keep working while b-iii migrates the factory. b-iv is forced by b-iii because installation sites feed the factory's closed-over cell-ids. b-v closes with measurement.

**Scope boundary**: TYPE domain only. `driver.rkt:2661` mult-cid + level/session migrations are S2.c/d scope.

#### §7.5.12.4 Dispatch strategy (Q1 resolved)

Centralized dispatch in `meta-solution/cell-id` (not per-site inlined), because:
- Existing dispatch point — smaller surface to review and measure
- Dispatch overhead (~50 ns per predicate + hash-ref) is negligible vs. the 113 ns baseline direct read
- Migration proceeds without touching 9 Category 1 callers
- Future reverts (should we need them) change one function, not 9 sites

#### §7.5.12.5 Scheduler component-path verification (Q3 resolved) — COMPLETE 2026-04-24, **CORRECTED 2026-04-24**

Done as the first task of S2.b-ii. Findings:

**Scheduler supports arbitrary `equal?`-comparable path shapes.** `filter-dependents-by-paths` at `propagator.rkt:1058` uses `member` (equal? comparison) between declared paths and the changed-set. Existing code heavily uses cons-pair paths — notably `typing-propagators.rkt` declares `(cons tm-cid (cons ctx-pos ':context))` (triple-nested) for attribute-map dependent firing; `tests/test-component-paths-enforcement.rkt` uses simple `(cons cid 'path)`. Zero scheduler adaptation needed.

**Path shape for compound universe cells — CORRECTED**: declaration is `:component-paths (list (cons universe-cid meta-id))`. The earlier note in this section claiming bare `meta-id` was incorrect — it conflated the WIRE format (changed-set emitted by `pu-value-diff`) with the DECLARATION format (input to `net-add-propagator`). They are different shapes at different layers, both correct as designed:

1. **Declaration** at install (`net-add-propagator` lines 1466-1470): `(filter (lambda (pair) (equal? cid (car pair))) component-paths)` then `(map cdr matches)`. The installer expects **cons-pairs** `(cons cell-id path)`. After `(map cdr matches)`, the **stored** path is the bare path-value (the cdr).

2. **Wire format** in `pu-value-diff` (lines 1008-1045): for FLAT hasheq (tagged-cell-value as value), emits **bare keys** as the changed-set; for NESTED hasheq-of-hasheq (attribute-map), emits `(cons position facet)` pairs.

3. **Filter** in `filter-dependents-by-paths` (lines 1108-1110): `(for/or ([p (in-list paths)]) (member p changed-set))`. Compares stored bare paths against bare changed-set keys. Match.

So for our flat compound universe cell `(hasheq meta-id → tagged-cell-value)`:
- Declare `:component-paths (list (cons universe-cid meta-id))` — cons-pair shape, satisfies installer's `(car pair)` extraction
- Stored path after `(map cdr matches)` = `(list meta-id)` — bare symbols
- `pu-value-diff` emits bare meta-ids as changed-set (FLAT hasheq path)
- `filter-dependents-by-paths` matches bare-stored-path against bare-changed-set → fires correctly

**Why b-ii and b-iii didn't surface this**: neither installed propagators ON universe-cid. Only b-iv installs propagators with `:component-paths` declaring meta-id paths on universe-cid. The earlier verification checked the wire format and filter layer but missed the installer's cons-pair expectation. Audit caught it pre-implementation 2026-04-24.

**`tagged-cell-value` equality**: `#:transparent` struct (`decision-cell.rkt:397`) → `equal?` does field-by-field comparison; merge changes (new bitmask tag entry added to `entries`, base updated) trigger proper diff emission. Verified.

**Mantra-check flag on "all in parallel" → CLEARED.** Confirmed all 5 mantra words satisfied without scheduler adaptation.

The Category 3 migration pattern in §7.5.12.2 uses cons-pair paths: `:component-paths (list (cons universe-cid meta-id))`.

#### §7.5.12.6 Measurement cadence (Q4 resolved)

Two measurement points during S2.b:
1. **Probe diff check between S2.b-iii and S2.b-iv** — low cost (~5s probe run against baseline); high signal. Catches Category 2 migration regressions before the Category 3 bridge-factory changes complicate diagnosis.
2. **Formal measurement checkpoint at S2.b close** (pre-agreed per STEP2_BASELINE.md §6) — bench-meta-lifecycle E1-E5 + probe + targeted suite regression check; compare to §5 hypotheses; go/no-go for S2.c.

#### §7.5.12.7 Drift risks (for mid-flight principles challenge)

1. **Half-migration parallel-sources-of-truth** — if we stop between categories, the 3 categories disagree on what `prop-meta-id->cell-id` returns. Either ALL type-meta sites migrate in one pass, or we don't start.
2. **Scope creep into Phase 1E** — tempting to route `that-*` through the universe cell too. Guard: Phase 1E is deferred; S2.b must leave 1E clean.
3. **Real-workload performance regression** — S2.a's +55% read-path win was synthetic. Deep zonk chains, nested meta resolutions, bridge-fn hot paths may behave differently. Measurement cadence (above) is the guard.
4. **Bridge-fn factory integrity** — resolution.rkt closes over `dict-cell-id` as the output target. If the factory's fire function retains pre-S2.b `(net-cell-write pnet dict-cell-id dict-expr)` shape while the installation declares a universe-cid, writes go to the WHOLE universe cell instead of the meta component. Exactly the subset of the `#hasheq()` failure mode we saw in the reverted first attempt. S2.b-iv's acceptance test must verify the factory writes component-keyed.

#### §7.5.12.8 Sub-phase completion criteria

- **S2.b-ii**: scheduler component-path verification outcome; centralized dispatch lands; 9 Category 1 sites work unchanged; probe diff = 0.
- **S2.b-iii**: `elab-fresh-meta` no longer allocates per-meta cells; all Category 2 sites migrated; probe diff = 0.
- **S2.b-iv**: Category 3 bridge factories write via `compound-cell-component-write`; `:component-paths` declare bare `meta-id` (not cons-pair, per §7.5.12.5 verification); set-latch pattern replaces fan-in propagators (§7.5.12.9); meta-specific dependent firing verified; probe diff = 0; `test-constraint-retry-propagator.rkt` passes.
- **S2.b-v**: formal measurement against STEP2_BASELINE.md §5 criteria; if hypotheses met → go for S2.c; if regression → investigate before proceeding.

#### §7.5.12.9 S2.b-iv set-latch design decision (2026-04-24, **EXPANDED 2026-04-24** post-mini-audit)

**Full-suite empirical findings post-S2.b-iii** (commit `997a7896`, includes the b-iii follow-up fixes for `'infra-bot` filter + worldview-cache fallback in `compound-cell-component-ref`):

- Full suite: **7912 tests / 110.7s / 1 file failing** (`test-constraint-retry-propagator.rkt`)
- 408/409 test files GREEN; 7908/7912 tests GREEN
- Suite wall time 110.7s vs baseline 118-127s — **7-13% faster, a S2.b win**
- Acceptance file `examples/2026-04-17-ppn-track4c.prologos`: 0 errors, 28 expected outputs correct
- Probe `examples/2026-04-22-1A-iii-probe.prologos`: 0 errors, semantic output matches baseline exactly

**The 4 failures in `test-constraint-retry-propagator.rkt`** (all 16 tests in file; 12 pass):

| Test | Expected | Actual | Root cause |
|---|---|---|---|
| `constraint-with-two-metas-has-two-cell-ids` (line 47) | `(length cell-ids) = 2` | 1 | 2 distinct type metas → both have same universe-cid → `remove-duplicates` collapses |
| `retries-when-meta-solved` (line 109) | `'solved` | `'postponed` | Fan-in reads `(net-cell-read pnet universe-cid)` → returns whole hasheq → neither bot nor top → `any-ground?` fires incorrectly → bridge retry path never actually reaches component value |
| `constraint-postponed-again-on-partial-solve` (line 225) | `(length cell-ids) = 2` | 1 | Same cell-id collapse |
| `cell-reads-reflect-meta-solutions` (line 262) | `#t` | `#f` | Direct universe-cid read for "is this meta solved?" breaks |

All 4 cluster around **multi-meta constraints + direct `net-cell-read` on universe-cid**. This is the Category 3 (bridge-fn + readiness propagator) territory flagged in §7.5.12.

**Design decision: set-latch rewrite with broadcast realization at install layer** (refined 2026-04-24 post-mini-audit)

Replace the existing 3-stage fan-in pipeline (threshold-cell + fan-in propagator + readiness propagator) with the **set-latch pattern** codified in [`propagator-design.md`](../../.claude/rules/propagator-design.md) § Set-Latch for Fan-In Readiness, **using broadcast at the install layer for the universe-meta sub-set** (post-mini-audit refinement). Rationale: set-latch's structural shape (latch + threshold + per-input watcher) composed with broadcast's polynomial-functor realization (1 propagator + N items + parallel-decomposition profile) is the architecturally most-aligned fan-in pattern. The imperative fan-in appears at 3 sites in `metavar-store.rkt` (constraint retry, trait bridge, hasmethod bridge) — all benefit; future Phase 10 fork-on-union and Phase 9b γ multi-candidate inherit.

**Why set-latch's STRUCTURAL shape, not inline per-meta dispatch in the fan-in fire-fn**:
1. The set-latch uses FIRST-CLASS PRIMITIVES we already ship (`'monotone-set` SRE domain, `net-add-broadcast-propagator`, `net-add-fire-once-propagator`, `make-threshold-fire-fn`) rather than ad-hoc inline dispatch.
2. Component-path precision: each watcher declares `:component-paths (list (cons universe-cid meta-id) ...)` and fires ONLY when one of THIS constraint's metas changes. Sibling meta changes on the same universe cell don't wake it.
3. Identity preserved in the latch — callers can enumerate which metas are ready.
4. Fire-once semantics structurally correct (no spurious re-fires on subsequent universe-cell writes).
5. Mantra-aligned (all-at-once, all-in-parallel, structurally emergent, info-flow-through-cells, on-network).
6. Same pattern generalizes to Phase 10 fork-on-union per-branch latches + Phase 9b γ hole-fill multi-candidate readiness.

**Why broadcast at install layer, not N fire-once**:
1. Broadcast's A/B data: 2.3× faster at N=3, 75.6× at N=100 vs N-propagator model (per propagator-design.md § Broadcast Propagators).
2. ONE propagator install per fan-in site instead of N — saves CHAMP install overhead (~2.7μs × N) + worklist entries.
3. Broadcast-profile metadata enables future scheduler-level parallel decomposition across items at fire time — automatic, no caller code changes.
4. Component-paths supported on broadcast (BSP-LE Track 2 Phase 5.1b extension at `propagator.rkt:1638-1642`) — same precision benefits as N fire-once.
5. The "ONE fire reads all N components" cost is bounded; for typical N=1-5 it's a wash; for large N (Phase 9b γ), parallel decomposition recovers the cost.

**Why broadcast for universe sub-set + fire-once for per-cell legacy sub-set**:

Under b-iii, only TYPE metas are universe-migrated. Mult/level/session metas are still per-cell (S2.c/d/e scope). A constraint can have MIXED metas: type (universe component) + mult (per-cell). The helper handles this by partitioning meta-ids:
- `universe-mids` → ONE broadcast propagator on universe-cid with cons-pair component-paths
- `per-cell-mids` → fire-once propagators per meta on per-cell cids (legacy path; narrows as S2.c/d/e migrate)

This is "scaffolding with named retirement" — not belt-and-suspenders. The fire-once branch handles a DIFFERENT meta storage shape (pre-universe per-cell), not redundant handling of the same. As S2.c/d/e land, `per-cell-mids` shrinks to empty and the helper collapses to broadcast-only.

**Mini-audit findings (2026-04-24)** that reshape the original 7-step plan:

1. **§7.5.12.5 component-path shape was wrong** — corrected this section. Declaration is `(list (cons universe-cid meta-id))` (cons-pair, not bare); installer's `(car pair)` extraction requires it.

2. **Consumer surface broader than the 3 fan-in sites** — `constraint-cell-ids` is also consumed by 2 scan paths with the IDENTICAL universe-cid bug:
   - `retry-constraints-via-cells!` (metavar-store.rkt:894-908) — Stratum 2 retry scan
   - `collect-ready-constraints-via-cells` (metavar-store.rkt:919-931) — Stratum 1 readiness scan
   - And ANALOGOUS for traits/hasmethods: `collect-ready-traits-via-cells` (:942-956) + `collect-ready-hasmethods-via-cells` (:982-996)

3. **The 4 scan functions have ZERO production callers** — verified by grep 2026-04-24. They were Track 7 Phase 8a-era polling mechanisms that became vestigial when the readiness propagators (the 3-stage fan-in) landed. Test files contain the only invocations (5 calls in test-constraint-retry-propagator.rkt).

4. **Scan paths violate Propagator-First** — per DESIGN_PRINCIPLES.org § Stratified Propagator Networks, scan loops are "symptoms of resolution logic living outside the propagator network." The set-latch pattern IS the architecturally-correct S1 readiness mechanism; scans are anti-patterns the architecture was supposed to retire. Track 7 missed this retirement; b-iv closes it.

**b-iv expanded scope** (post-audit refinement):

1. **`constraint` struct change** (metavar-store.rkt:283)
   - Add `meta-ids` field alongside existing `cell-ids` (list of meta-ids for metas in lhs/rhs — per-meta identity under universe model)
   - `cell-ids` retained for backward-compat readers (driver/elaborator) until full migration

2. **`add-constraint!` populator** (metavar-store.rkt:764+)
   - `meta-ids` is ALREADY collected at line 768 via `append (collect-meta-ids lhs) (collect-meta-ids rhs)` — for wakeup purposes. Step 2 stores this existing value into the new struct field.
   - De-duplicate via `remove-duplicates eq?`

3. **Foundation: pnet-level helpers in meta-universe.rkt**
   - `compound-cell-component-ref/pnet pnet cell-id component-key [default]` — mirrors enet-level using `net-cell-read` and the worldview-bitmask resolver
   - `compound-cell-component-write/pnet pnet cell-id component-key value` — mirrors enet-level using `net-cell-write`
   - `resolve-worldview-bitmask/pnet pnet` — pnet variant of the b-iii fallback

4. **Foundation: enet-level wrappers in elab-network-types.rkt**
   - `elab-add-fire-once-propagator` — thin wrapper over `net-add-fire-once-propagator` mirroring `elab-add-propagator`
   - `elab-add-broadcast-propagator` — thin wrapper over `net-add-broadcast-propagator`

5. **Helper: `add-readiness-set-latch! enet meta-ids action-thunk`** in metavar-store.rkt
   - Allocate latch cell (`'monotone-set` domain, `merge-set-union`, bot `(seteq)`)
   - Partition `meta-ids` by storage shape (`meta-universe-cell-id?` predicate)
   - For universe sub-set: install ONE broadcast propagator on universe-cid with `:component-paths (map (lambda (m) (cons universe-cid m)) universe-mids)`; item-fn reads each meta's component from input-vals[0]; result-merge-fn = `merge-set-union`; output → latch-cid
   - For per-cell sub-set: install N fire-once propagators (one per per-cell meta), each reading its cid via `net-cell-read` and writing `(seteq mid)` to latch
   - Install threshold fire-once propagator on latch-cid → fires `action-thunk` when latch becomes non-empty, writes to ready-queue
   - All propagators tagged with `current-speculation-assumption` for branch-isolated firing

6. **Rewrite 3 fan-in install sites** to use the helper:
   - Constraint retry (metavar-store.rkt:820-852) — 32 lines deleted; 1-line helper call
   - Trait bridge readiness (metavar-store.rkt:425-459) — 35 lines deleted; 1-line helper call
   - Hasmethod bridge readiness (metavar-store.rkt:577-618) — 42 lines deleted; 1-line helper call

7. **Bridge fire-fn factory updates** in `resolution.rkt`:
   - `make-pure-trait-bridge-fire-fn` (line 428): signature change to accept `dict-meta-id` + `dep-meta-id-pairs` (where each pair is `(cons universe-cid meta-id)` for universe metas, `(cons per-cell-cid #f)` for per-cell). Body uses `compound-cell-component-ref/pnet` for universe components and `net-cell-read` for per-cell. Writes via `compound-cell-component-write/pnet` for universe outputs.
   - `make-pure-hasmethod-bridge-fire-fn` (line 499): analog. Trait-var, dict-meta, and the meta itself can each be universe or per-cell — handle uniformly.
   - Order preservation: `impl-key-str` order driven by caller's meta-id list — preserve in factory.

8. **Retire 4 vestigial scan functions** (Option B per audit):
   - Delete definitions: `retry-constraints-via-cells!` (:894), `collect-ready-constraints-via-cells` (:919), `collect-ready-traits-via-cells` (:942), `collect-ready-hasmethods-via-cells` (:982)
   - Remove from `provide` block (metavar-store.rkt:88, :233-235)
   - Remove related comment references at :437, :561, :662, :759
   - These have zero production callers; only test-file references retire when the test file is restructured (step 9)

9. **Test rewrite + filename rename**: `tests/test-constraint-retry-propagator.rkt` → `tests/test-constraint-readiness.rkt`
   - Rename file (honest to post-b-iv mechanism: event-driven readiness, not retry-propagator)
   - Update header comment: "Tests for set-latch readiness pattern (constraint retry + trait bridge + hasmethod bridge)"
   - Replace direct `retry-constraints-via-cells!` invocations with event-driven test pattern: write meta solution via `compound-cell-component-write/pnet` + run-to-quiescence + check constraint status
   - Update identity-per-meta tests: `(length (constraint-cell-ids c))` → `(length (constraint-meta-ids c))` for lines 47, 225
   - Update direct cell read tests (line 262): use `compound-cell-component-ref` for solution check
   - Tests covering "skip when nothing solved", "skip already-solved", "skip without cell-ids" become PROPERTIES of the event-driven path: quiescence yields no spurious retries; idempotent latch + fire-once prevents re-fires; no meta-ids = no set-latch installation = no retry

10. **Regression validation**:
    - Probe (`examples/2026-04-22-1A-iii-probe.prologos`): diff = 0 (semantic output matches baseline)
    - Targeted tests: `test-constraint-readiness.rkt` (renamed) + bridge tests + speculation-bridge GREEN
    - Full suite: 7912/0-failure (or better — broadcast install reduction may shave a few seconds off wall time)

**Estimated scope**: ~280-330 LoC net across metavar-store.rkt (-100 LoC deletions, +110 helper) + resolution.rkt (+50) + meta-universe.rkt (+30 pnet helpers) + elab-network-types.rkt (+15 wrappers) + tests/test-constraint-readiness.rkt (rename + ~80 LoC restructuring).

**Drift risks for b-iv implementation**:
1. **Component-path shape on broadcast** — broadcast's `:component-paths` extraction at `propagator.rkt:1638-1642` uses `(filter (lambda (pair) (equal? cid (car pair))) ...)` — same shape as `net-add-propagator`. Cons-pairs verified.
2. **Bridge fire-fn readers for mixed dep metas** — universe deps need `compound-cell-component-ref/pnet`; per-cell deps need `net-cell-read`. Use paired list `(listof (cons cell-id meta-id-or-#f))` in factory closures; dispatch on whether `cell-id` is a universe-cid via `meta-universe-cell-id?`.
3. **Order preservation in `impl-key-str`** — preserve caller's `type-arg-metas` order through the factory. Build dep-pair list in order; iterate in order during read.
4. **Universe-cell domain unclassified** — universe cells are not registered with a Tier 1 SRE domain classification yet, so `enforce-component-paths!` skips them. Post-b-iv, classifying as `'structural` would make the component-paths declaration structurally-enforced. NOT in b-iv scope; flagged for a follow-up (post-S2.b-v or S2-VAG).
5. **Scan retirement test impact** — the 5 test invocations in test-constraint-retry-propagator.rkt are tightly coupled to `retry-constraints-via-cells!`'s direct-write-to-cid pattern. Restructuring tests to event-driven semantics is REQUIRED, not optional.
6. **Action-thunk closure shape** — the 3 sites differ in action: `action-retry-constraint c`, `action-resolve-trait dict-meta-id info`, `action-resolve-hasmethod meta-id info`. Action-thunk parameterizes per-site without callback proliferation.
7. **`current-speculation-assumption` propagation** — must be captured at helper-call time (not at fire time) for branch-isolated tagging. The helper closes over `aid` and tags all installed propagators.

**Observation: set-latch + broadcast as complementary patterns**

The set-latch pattern (latch + threshold + per-input readiness) and the broadcast pattern (1 propagator + N items + parallel-decomposition profile) are NOT substitutes — they are complementary:
- Set-latch is the STRUCTURAL shape for fan-in readiness (where N independent inputs feed an aggregate readiness signal)
- Broadcast is the REALIZATION strategy for processing N independent items in 1 propagator with parallel decomposition

The architecturally most-aligned fan-in uses BOTH: set-latch's structural shape + broadcast's realization at the per-input watcher layer. The mantra "all-at-once, all in parallel" is satisfied at multiple layers — N propagators installed in one helper call (all-at-once at install), N items processed in one fire-fn with broadcast-profile metadata (all-in-parallel via scheduler decomposition), latch state IS the readiness signal (structurally emergent, on-network). For mixed-domain inputs (some universe-component, some per-cell legacy), partition and use broadcast for the universe sub-set + fire-once for the per-cell sub-set; both share the same latch.

This complementarity should be reflected in `propagator-design.md` § Set-Latch for Fan-In Readiness as the refinement of the 2026-04-24 codification.

**Codification updates** (committed as part of this design correction):
- `propagator-design.md` § Set-Latch for Fan-In Readiness: refined to specify broadcast realization with mixed-domain transition
- D.3 §7.5.12.5: corrected component-path shape (cons-pair, not bare)
- D.3 §7.5.12.9 (this section): expanded to 10 steps; broadcast realization; scan retirement; filename rename; Observation note

### §7.5.13 Step 2 S2.c Sub-phase Mini-design (2026-04-24)

Opening conversational mini-design for S2.c per refined Stage 4 methodology (mini-design + mini-audit outcomes persist to design doc; cycle between them; outcomes drive the design doc). Context: post-S2.b CLOSED (TYPE domain migrated). S2.c migrates the **mult domain** to compound universe cells.

The mini-design surfaced four converging architectural concerns that elevate S2.c from a mechanical S2.b mirror to a more substantial principles-driven track. Each is a real architectural decision with audit + measurement gates before commit.

#### §7.5.13.1 Architectural framing — four converging decisions

S2.c integrates four architectural moves that prior framing (S2.b's "mirror the pattern" plan) treated as mechanical extensions but, on audit, surface real principles questions:

1. **Cross-domain bridge component-path migration** (Q1) — `net-add-cross-domain-propagator` (used by 6 bridges) is universe-blind; needs `:component-paths` support. Lands as **S2.precursor** — independent infrastructure, then S2.c consumes.
2. **Parameter injection gap** (§B.3) — S2.a-followup's parameter-injection design was set up but never wired. All universe cells silently use `default-pointwise-hasheq-merge`. Type works by coincidence (single Role B write per meta); mult would silently break under multiple writes. Real correctness gap to close.
3. **Cell-id storage approach** (§C/§5) — S2.b extended PM 8F's expr-meta cell-id cache field. Question: is the cache earning its keep? STEP2_BASELINE numbers suggest no. Microbench-gated decision among options 1 (cache field), 2 (id-map lookup), 4 (parameter-read).
4. **Dispatch symmetry** (§F4) — current `mult-meta-solved?` / `mult-meta-solution` / level / session dispatch is per-domain code duplication. Opportunity: unify around `meta-domain-solution(domain, id)` parameterized by domain.

These four threads converge on a clean architectural target if all decisions land favorably:

```racket
;; Single source of truth per principle:
(define meta-domain-info
  (hasheq
    'type    (hasheq 'universe-cid current-type-meta-universe-cell-id  ; option 4: parameter
                     'merge type-unify-or-top                            ; option 3a: Role B
                     'bot? prop-type-bot? 'top? prop-type-top?)
    'mult    (hasheq 'universe-cid current-mult-meta-universe-cell-id
                     'merge mult-lattice-merge
                     'bot? mult-bot? 'top? mult-top?)
    'level   (hasheq ... 'merge merge-meta-solve-identity ...)
    'session (hasheq ... 'merge merge-meta-solve-identity ...)))

(define (meta-solution domain id)
  (define net-box (current-prop-net-box))
  (define cid ((hash-ref (hash-ref meta-domain-info domain) 'universe-cid)))
  (cond
    [(and cid net-box) (compound-cell-component-ref (unbox net-box) cid id)]
    [else (fallback domain id)]))
```

- Single cell-id source: parameter (option 4)
- Single merge source: SRE-driven (option 3)
- Single dispatch site: `meta-domain-info` table (F4 unification)
- No struct-field cache, no id-map round-trip for type-meta access

This is the architecturally cleanest landing target. Each decision is independently gated; if any fails its check, we fall back to the next-best option for that thread and the rest still land.

#### §7.5.13.2 Q1 cross-domain bridge architecture (scenario B confirmed)

`decompose-pi` (`elaborator-network.rkt:433-493`) is the call site for the bridge — invoked from `make-structural-unify-propagator`'s topology handler at lines 908 and 1171. The flow:

```racket
(define (decompose-pi net cell-a cell-b va vb unified pair-key)
  ;; Extract Pi components
  (define mult-a (expr-Pi-mult src-a))
  ...
  ;; PUnify: dom + cod get sub-cells via ctor-desc
  (define-values (net1 subs-a)
    (get-or-create-sub-cells net cell-a 'Pi (list dom-a-expr cod-a-expr)))
  ...
  ;; Cross-domain bridge: mult goes to mult-cell (different lattice)
  (define bridge-fn (current-structural-mult-bridge))
  (for/fold ([n net6])
            ([type-cell (list cell-a cell-b)] [mult-val (list mult-a mult-b)])
    (if (mult-meta? mult-val) (bridge-fn n type-cell mult-val) n)))
```

**Architectural picture**:
- PUnify's ctor-desc decomposition handles **dom + cod** as first-class sub-cells (same lattice as parent — type lattice).
- Mult is in a **different lattice** (flat 3-element + bot/top); cannot be a sub-cell of a type-cell.
- Cross-domain bridge connects type-cell ↔ mult-cell as a Galois projection.

**Verdict**: scenario B (complementary). The bridge is **necessary**. Aligns with `structural-thinking.md` § "Direct Sum Has Two Realizations": "Bridges are the right answer only when the Cᵢ carry genuinely different types or live at different strata." Mult and type DO carry different lattices — Realization B (shared carrier) is not applicable here.

**Implication**: bridge stays; primitive must be component-path-aware under universe migration. Hence S2.precursor.

##### §7.5.13.2.1 Initial-Pi-elaboration audit (S2.c-i Task 3, 2026-04-24) — scenario B confirmed exhaustively

Audit verified `decompose-pi` is the sole mult-bridge installer and traced ALL paths that write Pi values to cells:

**Bridge install sites**: only `decompose-pi` at `elaborator-network.rkt:482-491`. No other module installs cross-domain bridges between type and mult cells.

**Pi-writing-to-cells paths** (production code):
1. **`make-pi-reconstructor`** (`elaborator-network.rkt:416`) — installed by `decompose-pi` at lines 471 + 475. The reconstructor uses the FIXED mult value captured at `decompose-pi` time (it doesn't introduce new mult-metas). When it fires, the bridge is ALREADY installed for any in-scope mult-metas. No additional bridge installation needed.
2. **`solve-meta!` writing `expr-Pi` literals** — `grep` found ZERO production sites that pass a literal `expr-Pi` as the second arg to `solve-meta!`. In practice, Pi values reach metas via unification's structural decomposition path (where `decompose-pi` fires), not via direct `solve-meta!` calls.

**Conclusion**: scenario B (complementary) holds exhaustively. Every path that writes a Pi value to a type cell either:
- Goes through `decompose-pi` (which installs the bridge), OR
- Goes through `make-pi-reconstructor` (which `decompose-pi` already installed with the bridge), OR
- Doesn't exist in production (the hypothetical `solve-meta!` direct-Pi-write path has no callers)

S2.c-iv's bridge migration covers all the paths that currently exist. No additional invocation paths need to be handled.

**Caveat**: if a future code path writes Pi values to type cells without going through unification (e.g., a yet-unwritten elaboration shortcut), it would NOT trigger bridge installation. Mult propagation for mult-metas inside such Pi values would defer to the next unification involving that cell — same behavior pre/post universe migration. This is acceptable because mult propagation works correctly via unification anyway; the bridge is an OPTIMIZATION for eager propagation when the type cell changes outside unification context.

#### §7.5.13.3 §B.3 Parameter injection gap (audit-confirmed)

`grep -n "current-mult-universe-merge\|current-type-universe-merge"` across `elaborator-network.rkt` returns NOTHING. The S2.a-followup parameter-injection design (commit `2bab505a`) declared the parameters but no module ever sets them.

Consequence: `init-meta-universes!` (called in `reset-meta-store!` post-S2.b-iii) reads the parameters at their default values:

```racket
(define current-mult-universe-merge (make-parameter default-pointwise-hasheq-merge))
(define current-mult-universe-contradicts? (make-parameter default-no-contradicts?))
```

Where `default-pointwise-hasheq-merge` is conservative pointwise-without-domain-semantics; `default-no-contradicts?` always returns #f.

**Why type accidentally works**: type metas typically receive ONE Role B solution write per meta-id. Pointwise-hasheq's "new wins" coincidentally produces the right result for single writes. Multiple type writes with different values would silently lose information rather than contradict — but tests don't seem to exercise this.

**Why mult is at risk**: mult lattice has real algebra (`merge('m0, 'm1) = 'm1`, `merge('mw, 'm0) = 'mw`). Multiple writes ARE expected to compose via lattice join (mult inference accumulates resource usage). Without injection, multiple mult writes overwrite rather than join. **Correctness gap.**

**Resolution**: option 3 (SRE-driven lookup) — see §7.5.13.4. Each domain's SRE registration provides its canonical merge; init-meta-universes! looks them up. Single source of truth.

#### §7.5.13.4 §4 SRE-driven merge lookup — audit findings + correction (option 3c, NOT 3a)

**Original 3a proposal**: change `unify.rkt:71` `'equality` from `type-lattice-merge` → `type-unify-or-top`. **REJECTED post-audit (S2.c-i Task 2, 2026-04-24)** — would silently break T-3's union-aware structural reasoning.

##### §7.5.13.4.1 Audit findings (S2.c-i Task 2)

Audit traced runtime consumers of `(sre-domain-merge type-sre-domain sre-equality)`:

1. **`sre-core.rkt:265, 279, 295, 308`** — Property-inference tests (`test-commutative-join`, `test-associative-join`, `test-idempotent-join`, `test-distributive`). NOT runtime; Stage-2 audit tools.

2. **`sre-core.rkt:676`** — `sre-identify-sub-cell` uses merge as cell-creation merge function for sub-cells during structural decomposition. **Role**: cell-merge for accumulation (Role A appropriate).

3. **`sre-core.rkt:927`** — `sre-make-equality-propagator`: when two cells have a structural equality relation, fires `(merge va vb)` and writes unified to both. Under T-3's set-union semantics, incompat values → union; **both cells become the union, satisfying "they're equal" (to the same union)**. This is the architecturally-correct behavior under union-aware design.

4. **`sre-core.rkt:998, 1015`** — `sre-make-subtype-propagator` fallback when subtype-merge unavailable. Uses equality merge to compute contradiction signal. Role mixed but operates correctly under post-T-3 semantics.

5. **`sre-core.rkt:1032`** — `sre-make-duality-propagator` for sessions. Sub-cell merge.

6. **`unify.rkt`'s `unify-core` itself**: traces through `classify-whnf-problem` → `dispatch-unify-whnf`. For ground atom mismatches (`Int` vs `String`), classify returns `'(conv)` → dispatcher calls `(conv-nf a b)` (line 724) → returns `#f`. **Never touches the SRE 'equality merge.** T-3's set-union semantics is structurally invisible to `unify-core`.

##### §7.5.13.4.2 Empirical confirmation (`tests/test-t3-equality-audit.rkt`)

Permanent regression test added 2026-04-24. All 5 tests PASS:

```racket
(check-false (unify-ok? (unify '() (expr-Int) (expr-String))))
(check-false (unify-ok? (unify '() (expr-Int) (expr-Bool))))
(check-false (unify-ok? (unify '() (expr-Pi 'mw (expr-Int) (expr-Bool))
                                     (expr-Sigma (expr-Int) (expr-Bool)))))
(check-not-false (unify-ok? (unify '() (expr-Int) (expr-Int))))
(check-not-false (unify-ok? (unify '() (expr-Pi 'mw (expr-Int) (expr-Bool))
                                        (expr-Pi 'mw (expr-Int) (expr-Bool)))))
(check-false (unify-ok? (unify '() (expr-Pi 'mw (expr-Int) (expr-Bool))
                                     (expr-Pi 'mw (expr-String) (expr-Bool)))))
```

**Confirmation**: `unify-core` correctly fails on ground incompat atoms post-T-3. The audit hypothesis (path-not-taken via `'conv` → `conv-nf`) is validated empirically. The test file remains as a permanent regression guard against future changes that might silently break unify-core's failure detection.

##### §7.5.13.4.3 Why option 3a was wrong — design intent of T-3

T-3 Commit B (2026-04-22, `e07b809f`) intentionally redesigned `type-lattice-merge` to set-union for incompat atoms. The user's pushback during S2.c mini-design dialogue (2026-04-24) was protecting this:

> "§4 3a sounds like an issue that we needed to spend a lot of time on recently. **Union types need set-union semantics.** I'm not sure if you're referencing this exactly. But you should check with audits..."

T-3's set-union is the correct semantics for **structural equality between cells** in a union-aware type system: when two cells must be "equal" and contain incompat values, the post-T-3 semantics says "they're both equal to the union of their possibilities." This is union-types-as-first-class.

The Role B (equality-enforce, top-on-incompat) sites are **specific, EXPLICIT** locations where the designer wants strict equality — these are direct callers of `type-unify-or-top`, NOT of SRE 'equality. T-3 Commit A migrated 4 such sites in `elaborator-network.rkt`. The SRE 'equality table was correctly NOT changed (T-3's Stage 2 audit at D.3 §7.6.9's "likely Role A" classification was correct in spirit; the framing "as accumulation" was unclear, but the conclusion to leave it alone was right).

**Conclusion**: there is NO T-3 'equality gap. The SRE 'equality merge for `'type` IS correctly `type-lattice-merge` with set-union semantics. The architecture is sound as-is.

##### §7.5.13.4.4 Option 3c — meta-cell merges in `meta-domain-info` table directly

**Decision (revised)**: don't change SRE 'equality. Per-domain meta-cell merges go DIRECTLY into `meta-domain-info` table, bypassing SRE 'equality dispatch for this purpose:

```racket
(define meta-domain-info
  (hasheq
    'type    (hasheq 'universe-cid current-type-meta-universe-cell-id
                     'merge type-unify-or-top              ; Role B for type metas (NOT SRE 'equality)
                     'contradicts? type-lattice-contradicts?
                     'bot? prop-type-bot? 'top? prop-type-top?)
    'mult    (hasheq 'universe-cid current-mult-meta-universe-cell-id
                     'merge mult-lattice-merge              ; lattice join (= 'mult SRE 'equality)
                     'contradicts? mult-lattice-contradicts?
                     'bot? mult-bot? 'top? mult-top?)
    'level   (hasheq 'universe-cid current-level-meta-universe-cell-id
                     'merge merge-meta-solve-identity       ; identity-or-error (= 'meta-solve SRE 'equality)
                     'contradicts? meta-solve-contradiction?
                     'bot? (lambda (v) (eq? v 'unsolved))
                     'top? meta-solve-contradiction?)
    'session (hasheq 'universe-cid current-session-meta-universe-cell-id
                     'merge merge-meta-solve-identity
                     ...)))
```

**Why this is correct**:
- For `'type`: meta-cell merge is **`type-unify-or-top`** (Role B). Type metas represent ONE type by design; double-solve with different value is a type error, not an opportunity to accumulate. This is what `elab-fresh-meta` already uses directly post-T-3 Commit B (S1.a, `3b6aefdb`).
- For `'mult`: meta-cell merge is `mult-lattice-merge`. Coincides with `'mult` SRE 'equality (mult only has one merge — its lattice join is also its equality merge). Mult metas can accumulate via lattice join (resource semantics).
- For `'level` / `'session`: meta-cell merge is `merge-meta-solve-identity`. Coincides with `'meta-solve` SRE 'equality (single merge per domain).
- The merges are EXACTLY what the per-cell factories (`elab-fresh-meta`, `elab-fresh-mult-cell`, `elab-fresh-level-cell`, `elab-fresh-sess-cell`) use today. Option 3c just LIFTS those merges into the universe-init function's data structure.

**Symmetry preserved**: each domain's meta-cell merge is the merge it already uses. No SRE registration changes. No T-3 gap to close (no gap exists).

##### §7.5.13.4.5 Sub-phase impact

- **S2.c-ii** (which was "close T-3 gap") is **REMOVED** from the partition (no T-3 gap to close)
- The S2.c-i Task 2 outcome is the **audit finding + permanent regression test** (`tests/test-t3-equality-audit.rkt`)
- **S2.c-iii** simplifies: parameter injection per option 3c just means populating `meta-domain-info` table at module load; no SRE 'equality changes

The corrected sub-phase partition appears in §7.5.13.7 (updated below).

#### §7.5.13.5 §C/§5 option 4 — parameter-read for cell-id (microbench-gated)

**Lean: option 4** (read universe-cid from parameter, no cache field, no id-map round-trip). Decision gated on microbench A/B comparing all three options.

**Architectural rationale**: under universe migration, `(prop-meta-id->cell-id type-meta-id)` ALWAYS returns the same universe-cid. The id-map entry for every type meta is the SAME constant. Caching this in the expr-meta struct (PM 8F's option 1) introduces a denormalized cache with discipline-maintained correctness (`with-handlers` fallback for stale cell-ids). Reading the parameter directly (option 4) is structurally cleaner — the parameter IS the single source of truth, set once at universe init.

**Three options for measurement**:

| Option | Path | Mechanism | Architecture |
|---|---|---|---|
| **1** | Cache field | `(expr-meta-cell-id e)` ~3ns + universe dispatch + compound-ref | Denormalized cache, with-handlers fallback (PM 8F current state) |
| **2** | id-map lookup | `(prop-meta-id->cell-id id)` ~80ns + universe dispatch + compound-ref | No cache, but id-map walk overhead |
| **4** | Parameter read | `(current-type-meta-universe-cell-id)` ~3ns + compound-ref | No cache, no id-map, no dispatch (universe-cid IS the constant) |

**Why option 4 is mantra-aligned**:
- *On-network*: universe-cid is the parameter's value (set at init); no off-network state
- *Single source of truth*: parameter IS the source; no copies in struct fields
- *Structurally emergent*: dispatch falls out of the parameter lookup; no imperative branch on cache-vs-lookup
- *Correct-by-construction*: stale cache impossible (no cache); no `with-handlers` discipline needed

**Microbench plan** (S2.c-i Task 2):

Three workloads × three paths × representative scale:

```
Workload A — single meta access (dispatch-overhead-dominant)
Workload B — 100 metas, mix of solved/unsolved (typical elaboration)
Workload C — 1000 metas (large file)

For each workload:
  Path 1 (cache):       (meta-solution/cell-id (expr-meta-cell-id e) (expr-meta-id e))
  Path 2 (id-map):      (meta-solution (expr-meta-id e))  
  Path 4 (parameter):   (meta-solution-via-parameter 'type (expr-meta-id e))  [new helper]
```

**Decision rules**:
- Path 4 ≤ Path 1 within 10ns/call → option 4 wins (architectural cleanliness, no perf cost)
- Path 4 > Path 1 by ≥30ns/call → reconsider; option 1 may be worth keeping for type, option 2 for mult
- Path 4 ≤ Path 2 by ≥50ns/call → option 4 strictly dominant over option 2 (which we'd otherwise default to)

**Sub-question retroactive type bench**: yes — bench captures both paths anyway. If option 4 wins, follow-up retires expr-meta cell-id field for type metas (path-1 inactive across the whole codebase).

**Estimated cost**: ~60min (read harness, design workloads, run, interpret).

##### §7.5.13.5.1 Microbench results (S2.c-i Task 1, 2026-04-24) — option 4 wins

Bench harness: section F added to `benchmarks/micro/bench-meta-lifecycle.rkt`. 50000 iterations per path × workload, GC between trials. Measurement uses universe-cells initialized via `init-meta-universes!` post-S2.b-iii.

| Workload | Path 1 (cache field) | Path 2 (id-map lookup) | **Path 4 (parameter-read)** |
|---|---|---|---|
| W1 — 1 meta | 625 ns/call | 423 ns/call | **323 ns/call** |
| W2 — 100 metas | 628 ns/call | 436 ns/call | **325 ns/call** |
| W3 — 1000 metas | 632 ns/call | 454 ns/call | **328 ns/call** |

**Deltas** (Path 4 vs others, negative = Path 4 faster):
- vs Path 1 (cache): −302 to −304 ns/call across all workloads
- vs Path 2 (id-map): −100 to −125 ns/call across all workloads

**Decision (per §7.5.13.5 rules)**:
- Path 4 ≤ Path 2 by ≥50ns ✓ → **option 4 strictly dominant over option 2**
- Path 4 ≤ Path 1 by ≥10ns ✓ → **option 4 wins over option 1**
- Path 4 is BOTH the architecturally cleanest AND the fastest path

**Mechanistic explanation**:
- Path 1 (cache): goes through `meta-solution/cell-id`'s `with-handlers` wrapper at line 2219 (per `metavar-store.rkt` audit). The continuation-marker overhead from `with-handlers` adds ~300ns vs the no-handler paths.
- Path 2 (id-map): does CHAMP walk (~80ns per `prop-meta-id->cell-id` per A4 measurement) + the universe dispatch + compound-cell-component-ref. No `with-handlers`.
- Path 4 (parameter): single parameter read (~3ns) + compound-cell-component-ref. Skips both id-map walk AND with-handlers.

**Sub-question** (retire PM 8F's expr-meta cell-id field for type metas retroactively):
**Strong yes, eventually.** The cell-id field is now provably a perf regression (302ns/call slower than parameter-read). However:
- Retiring the field requires touching the `expr-meta` struct definition (pipeline.md "New Struct Field" cascade)
- Touches every site that reads `expr-meta-cell-id`
- Out of S2.c scope; flag as a follow-up (call it **`expr-meta-cell-id` retirement**, gated on Phase 4 CHAMP retirement which already touches this surface)

For S2.c, option 4 is achievable WITHOUT retiring the field. The new dispatch helper `meta-domain-solution(domain, id)` reads from parameters and never references `expr-meta-cell-id`. The field becomes inert (still set, never used). Phase 4 cleanup retires it.

##### §7.5.13.5.2 Final decision — option 4 adopted

The dispatch unification table in §7.5.13.6 uses option 4 (parameter-read) for all 4 domains. The `meta-solution/cell-id` and `meta-solution` (no-args) backward-compat shims continue to exist for callers that have an `expr-meta` struct in hand, but they delegate to the new generic `meta-domain-solution(domain, id)` core.

**Codification candidate** (post-S2.c codify): "phantom optimization detected via microbench — PM 8F's cache field was 302ns SLOWER than the no-cache path under universe migration." Pattern: cached optimizations from earlier-architecture eras may become net-negative after substrate changes. Microbench should be standard practice when migrating substrates that touch heavily-cached paths. 1 data point this session.

#### §7.5.13.6 §F4 dispatch unification across mult/level/session

**Decision**: unify mult/level/session readers via a single `meta-domain-solution(domain, id)` core, parameterized by a domain registry.

**Current state — duplicated dispatch**:
- `meta-solution/cell-id` — type meta dispatch (centralized, post-S2.b-ii)
- `meta-solved?` — type meta dispatch (separate)
- `mult-meta-solved?` / `mult-meta-solution` — mult dispatch (CHAMP fallback)
- `level-meta-solved?` / `level-meta-solution` — level dispatch
- `sess-meta-solved?` / `sess-meta-solution` — session dispatch

Five domain-specific function pairs doing essentially the same thing parameterized by domain.

**Symmetric form** (S2.c-iv deliverable):

```racket
;; Single dispatch core, parameterized by domain
(define (meta-domain-solution domain id [explicit-cid #f])
  (define net-box (current-prop-net-box))
  (define info (hash-ref meta-domain-info domain))
  (define cid (or explicit-cid ((hash-ref info 'universe-cid))))   ;; option 4
  (cond
    [(and cid net-box)
     (with-handlers ([exn:fail? (lambda (_) (champ-fallback domain id))])
       (let ([v (compound-cell-component-ref (unbox net-box) cid id)])
         (and v (not (eq? v 'infra-bot))
              (not ((hash-ref info 'bot?) v))
              (not ((hash-ref info 'top?) v))
              v)))]
    [else (champ-fallback domain id)]))

(define (meta-domain-solved? domain id)
  (and (meta-domain-solution domain id) #t))
```

Per-domain entries:
- `'type` — universe-cid getter, type-bot/top predicates, CHAMP-box for fallback
- `'mult` — universe-cid getter, mult-bot/top predicates, mult CHAMP-box
- `'level` — universe-cid getter, ('unsolved bot, no top), level CHAMP-box
- `'session` — same shape as level

**Backward-compat shims** (retained for callers — most are domain-typed):
- `meta-solution(id)` → `(meta-domain-solution 'type id)`
- `mult-meta-solution(id)` → `(meta-domain-solution 'mult id)`
- `level-meta-solution(id)` → `(meta-domain-solution 'level id)`
- etc.

**Pros**:
- Single source of truth for dispatch logic
- S2.d (level + session migration) becomes near-zero work — just register their `meta-domain-info` entries
- Bug fixes happen in one place
- Aligns with SRE-domain-registration philosophy (each domain knows its own ops)

**Cons**:
- Added indirection (one hash-ref per call) — ~5-10ns per call
- Refactor is larger than just-add-mult-dispatch
- Some risk of inadvertently changing semantics for level/session (which we're not migrating per se in S2.c)

**Why in S2.c, not deferred**: doing it generically takes only marginally more effort than per-domain mult dispatch. S2.c is already touching these readers' surfaces. S2.d benefits significantly. Two architectural moves at once is acceptable when the second move is "make existing logic generic" rather than "introduce a new architectural pattern."

#### §7.5.13.6.1 Mini-audit findings (S2.c-iii, 2026-04-24)

Per Stage 4 mini-design + mini-audit methodology (§7.5.13 cycle): codebase audit run before S2.c-iii implementation, persisted here.

**Production caller enumeration** (grep-verified 2026-04-24):

| Function | Production callers | Test callers |
|---|---|---|
| `meta-solution` (no-args) | driver.rkt:2633 (callback install — see Surprise #1), unify.rkt:224, metavar-store.rkt:2219 (with-handlers fallback inside `meta-solution/cell-id`) — ~3-5 sites | ~25 |
| `meta-solution/cell-id` | pretty-print.rkt:82, zonk.rkt:55+496, unify.rkt:206+259+430, trait-resolution.rkt:57+119, typing-core.rkt:2818, reduction.rkt:3176, metavar-store.rkt:879 — **~9 production sites**, all pass `(expr-meta-cell-id e)` | ~5 |
| `meta-solved?` | qtt.rkt (mult-meta? gate), unify.rkt:429+814, resolution.rkt (~12 sites), trait-resolution.rkt (~6 sites), metavar-store.rkt internal (~3) — **~25 production sites** | ~30 |
| `mult-meta-solution` / `mult-meta-solved?` | unify.rkt:963+968 (mult solve-flex), qtt.rkt:2106+2108 (mult-meta finite check), metavar-store.rkt:2578+2585 (zonk-mult/zonk-mult-default) | ~10 |
| `level-meta-solution` / `level-meta-solved?` | unify.rkt:928+933 (level solve-flex), metavar-store.rkt:2435+2444 (zonk-level/zonk-level-default). `level-meta-solved?` has **NO production callers** | ~5 |
| `sess-meta-solution` / `sess-meta-solved?` / `sess-meta-solution/cell-id` | typing-sessions.rkt:78+83 (no-args only); `sess-meta-solution/cell-id` is **INTERNAL-ONLY** (metavar-store.rkt:2729+2749 zonk-session); `sess-meta-solved?` has **NO production callers** | ~10 |

**Surprises (5)**:

1. **`current-lattice-meta-solution-fn` is OFF-NETWORK SCAFFOLDING (mantra violation)**. driver.rkt:2633 installs `meta-solution` as a Racket-parameter callback to type-lattice.rkt for `is-meta-unsolved?`-style checks (type-lattice.rkt:86, 176, 399, 403, 421). Exists to break import cycle (type-lattice.rkt is leaf; can't import metavar-store.rkt → callback parameter installed by driver). **Mantra check: ❌ off-network, ❌ not structurally emergent, ❌ not info flow through cells**. Don't rationalize the "constraint on shim signature" as a feature — the constraint exists BECAUSE of the scaffolding. **Retirement plan**: gated on PM Track 12 (module loading on network) + import restructuring; PPN 4C parent Phase 4 (CHAMP retirement) provides the natural reframing point. Captured in DEFERRED.md § "Off-Network Registry Scaffolding" + PPN 4C parent Phase 4 tracker row.

2. **`sess-meta-solution/cell-id` is internal-only** — only zonk-session and zonk-session-default invoke it (metavar-store.rkt:2729+2749); not exported, no external callers. The dual surface (`sess-meta-solution` + `sess-meta-solution/cell-id`) is PM 8F-era scaffolding mirroring type's. **Both shims delegate to the SAME generic core** (`meta-domain-solution 'session id`); the cell-id arg is accepted for backward-compat but doesn't route differently from the no-args form.

3. **`unify.rkt:430` `(or (meta-solution/cell-id cell-id id) (meta-solution id))` becomes redundant** under option 4. Both calls go through the same generic core; both compute the same value via parameter-read. The OR is genuinely dead. **Retired in S2.c-iii** as part of the dispatch unification (added to S2.c-iii scope).

4. **CORRECTNESS GATE — `'universe-active?` per-domain flag required**. All 4 universe-cid parameters are SET post-S2.c-ii (`init-meta-universes!` allocates all 4 universe cells). But `fresh-X-meta` only registers TYPE metas in their universe (S2.b-iii landed); mult/level/session universes are EMPTY. Naive routing of all dispatch through `meta-universe-cell-id?` would return #f for all solved mult/level/session metas. **Fix**: `meta-domain-info` table includes `'universe-active?` field per domain. Type = #t (S2.b-iii landed); mult/level/session = #f. The flag flips ATOMICALLY with each domain's universe migration (S2.c-iv flips 'mult; S2.d flips 'level/'session). Correctness-by-construction: the table's flag IS the source of truth for "is this domain using universe dispatch." Dispatch code is invariant; data drives behavior.

5. **Session domain has the SAME PM 8F debt as type** (mantra violation, multi-instance pattern). `sess-meta` struct's `cell-id` field (Track 10B Phase B1b) is the SAME phantom optimization as `expr-meta-cell-id`. Per microbench (S2.c-i Task 1), the cache field path is ~302ns SLOWER than parameter-read (with-handlers continuation-marker overhead exceeds 80ns id-map savings). Plus session has `current-sess-meta-store` parameter (off-network hasheq, line 2595) and `current-sess-meta-champ-box` parameter (off-network CHAMP-box). **Retirement plan distributed across phases**:
   - `sess-meta.cell-id` field retirement → **PPN 4C parent Phase 4 tracker row** (alongside `expr-meta-cell-id` retirement; same phantom-optimization pattern)
   - `current-sess-meta-store` + `current-sess-meta-champ-box` parameter retirement → **§7.5.14 (S2.e Forward Scope Notes)**
   - `sess-meta-solution/cell-id` dual-surface retirement → **§7.5.14 (S2.e Forward Scope Notes)**

**Refined `meta-domain-info` shape (with `'universe-active?` correctness fix)**:

```racket
(define meta-domain-info
  (hasheq
    'type    (hasheq 'universe-active? #t            ; S2.b-iii landed
                     'universe-cid current-type-meta-universe-cell-id  ; option 4 thunk
                     'merge type-unify-or-top
                     'contradicts? type-lattice-contradicts?
                     'bot? prop-type-bot? 'top? prop-type-top?
                     'champ-box current-prop-meta-info-box)
    'mult    (hasheq 'universe-active? #f            ; S2.c-iv flips
                     'universe-cid current-mult-meta-universe-cell-id
                     'merge mult-lattice-merge
                     'contradicts? mult-lattice-contradicts?
                     'bot? mult-bot? 'top? mult-top?
                     'champ-box current-mult-meta-champ-box)
    'level   (hasheq 'universe-active? #f            ; S2.d flips
                     ...)
    'session (hasheq 'universe-active? #f            ; S2.d flips
                     ...)))

(define (meta-domain-solution domain id [explicit-cid #f])
  (define info (hash-ref meta-domain-info domain))
  (cond
    [(hash-ref info 'universe-active?)
     ... universe dispatch via option 4 / explicit-cid ...]
    [else
     ... legacy id-map walk via per-domain CHAMP fallback ...]))
```

Each per-domain migration (S2.c-iv for mult, S2.d for level/session) atomically flips its `'universe-active?` to #t when its `fresh-X-meta` migration lands. The dispatch code is invariant; data drives behavior. This is the correctness-by-construction landing the user's pushback (§5.4) demanded.

**Codification candidate (1 data point this session, watching list)**: "PM 8F-era cache fields + dual surfaces are phantom optimizations under universe migration. Microbench reveals the cache-field path is ~300ns slower than parameter-read due to with-handlers continuation-marker overhead. Pattern repeats: type domain (`expr-meta-cell-id`) AND session domain (`sess-meta.cell-id`). Retirement is structural, not local — both fields go inert post-option-4 + universe migration; cleanup absorbed by Phase 4 (CHAMP retirement) for fields and S2.e for parameter scaffolding."

#### §7.5.13.6.2 Honest re-VAG with adversarial framing applied — Move B+ corrective (2026-04-24)

**Context**: S2.c-iii's first-pass VAG (commit `8f686a6f`) passed cataloguing but didn't catch that the implementation preserved the `with-handlers` wrapper from PM 8F era — the SOURCE of the 302 ns/call delta the S2.c-i Task 1 microbench measured. The architectural shape of option 4 landed; its perf benefit didn't. User external challenge ("did we do anything about the cache fields?") surfaced the drift. Move B+ (commit `c86596e0`) is the corrective.

This subsection re-runs the VAG with the **adversarial framing** codified in the same session arc (commit `9f7c0b82` — DESIGN_METHODOLOGY.org § Vision Alignment Gate, CRITIQUE_METHODOLOGY.org § Cataloguing Instead of Challenging, workflow.md, MEMORY.md). For each of the 4 VAG questions, TWO COLUMNS: catalogue (the first-pass answer that passed) + challenge (what the adversarial framing would surface).

##### Question (a) On-network?

| Catalogue (first-pass S2.c-iii VAG) | Challenge (adversarial framing) |
|---|---|
| ✓ All reads via `meta-domain-info` → `compound-cell-component-ref` → cell. CHAMP fallback labeled as scaffolding (Phase 4 retires for type; S2.e + Phase 4 jointly retire mult/level/session). | ❌ The `with-handlers` wrapper IS off-network state — continuation marker held in Racket runtime; defensive guard catching imperative crash, not lattice-flow. Universe migration **structurally mitigates** the stale-cell concern this wrapper guarded against (PM 8F-era per-meta cell-ids could be out-of-range across enets; universe-cid is a constant per domain set per-enet). The wrapper is **belt-and-suspenders defensive scaffolding** (workflow.md anti-pattern) — keeping it for safety when the guarded condition is structurally impossible IS the anti-pattern. **Mantra violation I missed.** |

**Corrective (Move B+)**: dropped `with-handlers` from universe-active path. Stale-cell concern resolved structurally by universe-cid stability across enet copies, not papered over by defensive wrapper.

##### Question (b) Complete?

| Catalogue (first-pass) | Challenge (adversarial) |
|---|---|
| ✓ All 9 dispatch functions converted to shims; OR retired; mini-audit at §7.5.13.6.1; S2.e scope at §7.5.14; cross-cutting work captured at PPN 4C parent Phase 4 + DEFERRED.md. | ❌ The microbench confirmed option 4 wins by 302 ns/call **specifically because Path 4 has no `with-handlers` wrapper**. By preserving the wrapper, my generic core sat at ~Path 1 (625 ns/call), not Path 4 (323 ns). **I shipped the architectural SHAPE without the perf BENEFIT.** This is the "Validated ≠ Deployed" anti-pattern applied at the design-target level — I treated "all dispatch converted ✓" as completion, but completion requires the perf claim to land. **Did I treat this as refactor (preserve patterns) OR fresh design (challenge inherited patterns)? Refactor — and that's the gap.** |

**Corrective (Move B+)**: dropped `with-handlers` + ignored explicit-cid for universe-active path. Re-microbench: Path 1 went 625 → 388 ns/call (Δ −237 ns/call ≈ 80% of predicted 302 ns benefit; remaining 50-60 ns is cost of data-driven dispatch via `meta-domain-info` table, accepted for architectural cleanliness).

##### Question (c) Vision-advancing?

| Catalogue (first-pass) | Challenge (adversarial) |
|---|---|
| ✓ Single sources of truth (cell-id via parameter, merge per domain, dispatch via table). S2.c-iv flips ONE character per domain. Mantra-aligned: data drives behavior. | ❌ Single source of truth for cell-id was the design's CLAIM. But `(or explicit-cid (parameter))` meant callers passing `(expr-meta-cell-id e)` BYPASSED the parameter — so we had **TWO sources of truth on the hot path** (cache field + parameter, both returning the same value but via different mechanisms). The principle wasn't realized. ❌ "Data drives behavior" was the claim for the `'universe-active?` flag. True at the universe-vs-legacy axis. But within the universe-active branch, **IMPERATIVE control flow** (`with-handlers`) was catching stale-cell errors that universe migration structurally prevents. The data-driven story had an imperative escape hatch. |

**Corrective (Move B+)**: explicit-cid IGNORED for universe-active path → genuinely single source of truth (parameter only). `with-handlers` retired → no imperative escape hatch within the data-driven dispatch.

##### Question (d) Drift-risks-cleared?

| Catalogue (first-pass) | Challenge (adversarial) |
|---|---|
| ✓ All 7 named risks cleared (6 from §7.5.13.6.1 + 1 callback identity from §5.1 user pushback). | ❌ The 7 risks I named were ALL about correctness preservation. **None of them were "did we capture the perf benefit option 4 was supposed to deliver?"** That's a design-target-fidelity risk I didn't enumerate. Did I name perf-vs-design-target risks, or only correctness risks? Only correctness. The gap allowed a 302 ns/call drift to land invisibly at the gate. |

**Corrective (Move B+ + microbench claim verification rule)**: re-microbench post-implementation captured the missing benefit (~80%). Codified as Stage 4 step 6 obligation: when a phase's design references a microbench finding as load-bearing for a quantitative claim, the phase MUST re-microbench at close.

##### Methodology gap surfaced + codified

The S2.c-iii first-pass VAG was **rationalization, not challenge**. Each ✓ catalogued the work I did; none of them forced "could this be MORE aligned?" The catalogue→challenge transition is NEVER natural. It must be **actively forced** at every gate.

**4 specific drifts I missed by cataloguing**:
1. `with-handlers` wrapper preserved (off-network defensive scaffolding under new architecture)
2. `(or explicit-cid (parameter))` short-circuit (dual sources of truth on hot path)
3. `legacy-type-fn` written "for symmetry" (speculative scaffolding — workflow.md flag)
4. `type-champ-fallback` referenced only by retired wrapper post-Move-B+ (would have become dead)

**Codification** (commit `9f7c0b82`):
- DESIGN_METHODOLOGY.org Stage 4 § VAG: adversarial framing as leading paragraph; cataloguing-vs-challenging examples; red-flag patterns; two-column process discipline
- DESIGN_METHODOLOGY.org Stage 4 § NEW step 6: microbench claim verification (per-sub-phase obligation when design references microbench finding)
- CRITIQUE_METHODOLOGY.org § Cataloguing Instead of Challenging: extended scope (BEYOND critique rounds: VAG, Mantra Audit, Principles-First Gate, P/R/M/S)
- workflow.md: 2 new operational bullets + question (b) updated (shape + benefit)
- MEMORY.md: 2 quick-reference sections
- STEP2_BASELINE.md §6.1: exception to "skipped for S2.c/d/f" when sub-phase implements microbench-justified architectural decision

**Corrective implementation** (commit `c86596e0` — Move B+):
- Universe-active dispatch path: option 4 PURE (parameter-read only, no `with-handlers`, no explicit-cid pickup)
- `legacy-type-fn` retired
- `'type` entry in `meta-domain-info` has no `'legacy-fn`
- Microbench-verified: ~80% of predicted 302 ns/call benefit captured

**Re-VAG outcome (post-Move-B+)**: all 4 questions pass under adversarial framing — universe-active path is genuinely on-network (no defensive wrapper), genuinely complete (perf benefit captured), genuinely vision-advancing (one source of truth on hot path), genuinely drift-risk-cleared (microbench verified the perf claim landed).

#### §7.5.13.7 Sub-phase partition (revised post-Task-2 audit, S2.precursor + S2.c-i through S2.c-v)

**Revision note (2026-04-24)**: original partition had 6 sub-phases (S2.c-i through S2.c-vi). After S2.c-i Task 2 audit (§7.5.13.4) revealed no T-3 'equality gap exists, the partition collapses to 5 sub-phases. **S2.c-ii is REMOVED** (no fix needed); subsequent sub-phases keep their original semantics but renumber S2.c-iii → S2.c-ii, S2.c-iv → S2.c-iii, S2.c-v → S2.c-iv, S2.c-vi → S2.c-v.

| Sub-phase | Description | Est. LoC | Key gate |
|---|---|---|---|
| **S2.precursor** | `net-add-cross-domain-propagator` accepts `:c-component-paths` / `:a-component-paths` kwargs (universal fix for all 6 bridges) + tests | ~50-80 | Lands first; S2.c consumes |
| **S2.c-i** | Audits + measurements: (a) §5 microbench (option 1/2/4); (b) option 3a regression test + 'type 'equality consumer audit; (c) initial-Pi-elaboration path audit | ~30 + report | Data-driven decisions documented in this design doc |
| ~~**S2.c-ii** Close T-3 gap~~ | ~~3-line change at unify.rkt:71~~ | — | **REMOVED 2026-04-24** post-Task-2 audit (§7.5.13.4): no gap exists. Audit's permanent regression test (`tests/test-t3-equality-audit.rkt`) substitutes. |
| **S2.c-ii** (was iii) | Parameter injection per option 3c: populate `meta-domain-info` table at module load with per-domain meta-cell merges (`type-unify-or-top`, `mult-lattice-merge`, `merge-meta-solve-identity`); update `init-meta-universes!` to consume the table | ~40-60 | All 4 universe cells use correct domain merges |
| **S2.c-iii** (was iv) | Dispatch unification: generic `meta-domain-solution(domain, id)` core driven by `meta-domain-info` table; option 4 (parameter-read) if microbench supports | ~150 + -100 dup | Backward-compat shims preserve all existing call sites |
| **S2.c-iv** (was v) | `fresh-mult-meta` universe-path branch (mirrors S2.b-iii pattern) + cross-domain bridge migration (`current-structural-mult-bridge` updated to declare component-paths) | ~80-120 | Probe diff = 0; mult tests green |
| **S2.c-v** (was vi) | Probe + targeted suite + measurement + GO/no-go for S2.d | ~0 + report | Suite within variance band; measurement update to STEP2_BASELINE.md §12 |

Estimated total: **~390-540 LoC** (slightly reduced from original 400-550 due to S2.c-ii removal). Five sub-phases + 1 precursor.

#### §7.5.13.8 Audits + measurements required during S2.c-i

S2.c-i is the data-collection sub-phase. Outputs are persisted into this design document section as findings (not separate audit files), per refined Stage 4 methodology.

1. **§5 microbench A/B** (option 1 vs 2 vs 4):
   - Read `bench-meta-lifecycle.rkt` harness fully
   - Design 3-path × 3-workload comparison (single, 100, 1000 metas; mix solved/unsolved)
   - Run with `bench` macro; capture ns/call
   - Decide option per §7.5.13.5 decision rules
   - Persist results as §7.5.13.5 update

2. **§4 option 3a verification**:
   - Write regression tests:
     ```racket
     (check-false (unify-ok? (unify '() (expr-Int) (expr-String))))
     (check-false (unify-ok? (unify '() (expr-Pi 'mw (expr-Int) (expr-Bool))
                                          (expr-Sigma (expr-Int) (expr-Bool)))))
     ```
   - Run BEFORE applying fix — confirms whether bug is dormant or active
   - `grep` `'type` 'equality consumers — confirm all are Role B (no Role A surprises)
   - Persist confirmation as §7.5.13.4 update

3. **Initial Pi elaboration path audit**:
   - `grep` for type-cell writes that don't go through `make-structural-unify-propagator`
   - Trace: how does mult information from `Pi A B` AST reach mult-cells?
   - Confirms scenario B understanding or surfaces alternate paths
   - Persist findings as §7.5.13.2 update if surprises emerge

#### §7.5.13.9 Drift risks (for mid-flight principles challenge)

1. **Cross-domain bridge component-path declarations** — under universe migration, the bridge α/γ closures must use `compound-cell-component-{ref,write}/pnet` and declare `:component-paths`. Forgetting either is the same bug class as S2.b-iv's bridge factory work.
2. **Microbench harness reliability** — STEP2_BASELINE numbers had a confound (`with-handlers` overhead vs id-map cost). New microbench must isolate cleanly. Risk: false signal leads to wrong option.
3. **'equality regression test outcome surprise** — if pre-fix tests FAIL today (active bug), implications wider than S2.c expected. May surface other consumers; may need broader audit.
4. **Dispatch unification breaking level/session** — refactor touches level/session readers without migrating them to universe (those are S2.d). Risk: subtle semantic change leaks through. Mitigation: backward-compat shims preserve exact existing behavior; tests catch.
5. **Phase 4 forward compat** — universe-cell shape `(hasheq meta-id → tagged-cell-value)` is Phase 4-compatible (same as type's). No new compatibility risk.
6. **Parameter injection timing** — if init-meta-universes! runs BEFORE the parameters are set (module-load order), allocation uses defaults. Need to verify injection happens at module load, before reset-meta-store! fires init.
7. **option 4 vs init order** — `(current-type-meta-universe-cell-id)` is set by init-meta-universes!. If a meta-solution call happens BEFORE init (test contexts, early elab), parameter is `#f` → fallback path. Must verify the fallback is correct or guard against premature access.

#### §7.5.13.10 Sub-phase completion criteria (revised post-Task-2 audit)

- **S2.precursor**: `net-add-cross-domain-propagator` accepts kwargs; all 6 bridges' tests still green; new test verifies component-paths support ✅ (`1c3970d0`)
- **S2.c-i**: 3 audits/measurements complete and persisted into D.3
  - Task 1 (microbench): option 1/2/4 decision documented in §7.5.13.5 ⬜
  - Task 2 (T-3 audit): findings documented in §7.5.13.4 + permanent regression test in `tests/test-t3-equality-audit.rkt` ✅ (5/5 PASS — option 3c adopted, original S2.c-ii REMOVED)
  - Task 3 (initial-Pi audit): findings persisted into §7.5.13.2 if surprises emerge ⬜
- **~~S2.c-ii (close T-3 gap)~~**: REMOVED — no gap exists per §7.5.13.4 audit
- **S2.c-ii** (was S2.c-iii): `meta-domain-info` table populated with per-domain meta-cell merges (option 3c); `init-meta-universes!` consumes table; targeted tests green for compound-merge semantics
- **S2.c-iii** (was S2.c-iv): Dispatch unification lands; backward-compat shims preserve behavior; targeted tests green for type/mult/level/session readers
- **S2.c-iv** (was S2.c-v): Mult universe migration complete; cross-domain bridge component-path-aware; probe diff = 0; targeted mult tests green
- **S2.c-v** (was S2.c-vi): Suite within 118-127s variance band; STEP2_BASELINE.md §12 updated with S2.c outcomes; GO/no-go for S2.d

#### §7.5.13.11 Codification updates (committed as part of this mini-design)

- D.3 §7.5.13 (this section): NEW — captures S2.c mini-design + audit findings + sub-phase plan
- D.3 §3 Progress Tracker: rows for S2.precursor + S2.c-i through S2.c-vi added
- (Mid-flight) D.3 §7.5.13.4 / §7.5.13.5: updated with audit + measurement findings during S2.c-i
- (Mid-flight) D.3 §7.5.13.6.1: NEW — mini-audit findings for S2.c-iii + 5 surprises (added 2026-04-24)
- (At S2.c close) D.3 §7.5.13: Vision Alignment Gate outcome appended

### §7.5.14 S2.e Forward Scope Notes (NEW 2026-04-24)

Captured during S2.c-iii mini-design + audit. S2.e is the factory-retirement + final-measurement sub-phase of Step 2. This section accumulates scope notes ahead of S2.e mini-design open. Items will be folded into a proper S2.e mini-design when that sub-phase opens (~end-of-Step-2 sequence). Persisting in D.3 (rather than DEFERRED.md) because these are **track-internal scope items** — they belong to the design that is currently active, not to the cross-track deferred backlog.

#### §7.5.14.1 Session-domain off-network parameter retirements

Surfaced by S2.c-iii mini-audit (§7.5.13.6.1 Surprise #5). The session domain accumulated multiple PM 8F-era off-network state patterns parallel to type's:

- **`current-sess-meta-store` parameter** (`metavar-store.rkt:2595`): Racket parameter holding `(make-hasheq)`. Off-network mantra violation; legacy from pre-network meta storage era.
- **`current-sess-meta-champ-box` parameter**: Racket parameter holding box of CHAMP for sess-meta status tracking. Same off-network pattern as `current-prop-meta-info-box` (type) and `current-mult-meta-champ-box` (mult).

**S2.e retirement plan**: when session universe migration (S2.d) is complete and the universe is the authoritative store, both parameters become unused (the `'champ-box` entry in `meta-domain-info` for `'session` is no longer consulted because `'universe-active? = #t`). Retire alongside the per-cell factory retirement.

Mantra check post-retirement: ✓ on-network (universe cell), ✓ structurally emergent (dispatch via table), ✓ info flow through cells (compound-cell-component-ref).

#### §7.5.14.2 Session-domain dual-surface retirement

The `sess-meta-solution/cell-id` (PM 8F-style fast path with `sess-meta.cell-id` cache field) becomes redundant under option 4 dispatch:

- Both `sess-meta-solution` and `sess-meta-solution/cell-id` shims delegate to `meta-domain-solution 'session id` (as designed in S2.c-iii)
- The cell-id arg is accepted for backward-compat but doesn't change dispatch (parameter-read wins)
- The 2 internal-only callers in metavar-store.rkt (zonk-session at :2729, zonk-session-default at :2749) currently pass `(sess-meta-cell-id s)` → after Phase 4's `sess-meta.cell-id` field retirement, they stop passing it → only `sess-meta-solution` remains

**S2.e retirement plan** (post-Phase-4): once `sess-meta.cell-id` field is deleted, retire `sess-meta-solution/cell-id` shim entirely. Single-surface contraction matches the option-4 mantra-aligned shape; the dual surface was scaffolding tracking PM 8F's cache-field optimization.

#### §7.5.14.3 Other potential S2.e items (placeholder)

Future findings during S2.c-iv / S2.d / S2.f may surface additional retirement candidates — e.g., dual-surface patterns for mult/level analogous to session's, factory functions that become near-trivial post-universe-migration, parameter scaffolding that the universe migration makes unused. This subsection accumulates them as they arise. Mini-design at S2.e open consolidates and partitions.

### §7.6.15 Path T-2 — "Open by Design" Map semantics (2026-04-23) — DELIVERED

Post-T-3 dialogue surfaced the T-2 scope. T-3 Commit B's set-union merge at the cell level DID NOT automatically make map-assoc's explicit `build-union-type` (at `typing-core.rkt:1196-1217`) redundant — the widening was a sexp-level TYPE EXPRESSION construction, not a cell-merge. T-2 resolved this by retiring the narrow-union-widening pathway entirely in favor of **"Open by Design"** — a new α-semantic universal type for unannotated heterogeneous map values, inspired by Clojure's practical ergonomics ("The Pragmatic Prover").

**Two architectural decisions** (dialogue 2026-04-23):

**D1 — Override CIU §8 D7**: `docs/tracking/2026-03-20_COLLECTION_INTERFACE_UNIFICATION_DESIGN.md` §8 considered this exact question and recommended Option C (schema-first, keep narrow-union default). User override: CIU is a draft note, not a design commitment; the vision has always been Clojure-ergonomic Maps. Override taken with eyes open.

**D2 — α-semantic for Open** (not β "unknown"-style, not γ "freshen-per-access"):
- `check ctx v (expr-Open) = #t` always (Open accepts any value)
- `check ctx e T` where `(infer e) = (expr-Open)` succeeds via `unify Open T = T` (Open passes through)
- Open unifies in both directions, never fails, never solves
- Trust at the map-read use site; validation via schema when needed

**Implementation** (3 staged commits):

| Commit | Focus | Hash |
|---|---|---|
| 1/3 | `expr-Open` AST + pipeline integration (7 files) | `4bfbd141` |
| 2/3 | Typing semantics + map-op Open cases + map-assoc speculation retirement | `246d4c2e` |
| 3/3 | Elaborator emits Open + test rewrites + probe baseline refresh | `07fda438` |

**Files touched** (10 production + 2 test + 1 data):
- syntax.rkt (struct + provide + predicate)
- substitution.rkt, zonk.rkt, reduction.rkt, pretty-print.rkt, pnet-serialize.rkt, unify.rkt (identity/wildcard cases)
- typing-core.rkt (infer/check/infer-level + Open cases for all 9 map operations + map-assoc speculation retirement)
- qtt.rkt (parallel inferQ/checkQ)
- elaborator.rkt (`surf-map-literal` emits Open)
- tests/test-mixed-map.rkt (11 rewrites + 4 new tests, 21→25)
- tests/test-path-expressions.rkt (1 assertion update)
- data/probes/2026-04-22-1A-iii-baseline.txt (refreshed to post-T-2 state)

**Aggregate statistics**:

| Metric | Value |
|---|---|
| Commits | 3 (Commit 1/2/3 of 3) |
| Production files modified | 10 |
| Test files modified | 2 |
| New tests | +4 (21 → 25 in test-mixed-map) |
| Full suite | 7912 tests / 118.4s / 0 failures (**pre-existing** test-facet-sre-registration contamination cleared as side-effect) |
| Probe `speculation_count` | 12 → 0 (complete retirement for map operations) |
| Probe `atms_hypothesis_count` | 17 → 5 (-70%) |
| Probe `infer_steps` | 73 → 55 (-24%) |
| Probe `meta_created` | 19 → 16 (-16%) |
| Probe `reduce_steps` | 339 → 315 (-7%) |

**Vision Alignment Gate (all 4 questions pass)**:

- **(a) On-network?** YES for new mechanism. `expr-Open` is a pure type-level AST node; no Racket parameters, no mutable state, no off-network registries added. `unify.rkt`'s classify handles Open as a wildcard in the same way `expr-hole` is handled — pure dispatch.
- **(b) Complete?** YES. All 9 map operations (get, assoc, nil-safe-get, dissoc, size, has-key, keys, vals, generic get) have Open cases. α-semantic applied consistently. Annotation path preserves strict narrow-union checks (Concern B). Schema path preserved (Concern B).
- **(c) Vision-advancing?** YES. Completes the T-3 → T-2 arc: T-3 removed narrow-union-widening as a lattice-merge obligation; T-2 removes it as a typing-rule obligation. Reframes Maps as Clojure-ergonomic primitives without the Haskell-style narrow-union coercion. One of six `with-speculative-rollback` sites retired; the other five retire naturally at PM 12. Aligns with PPN 4C charter (everything on-network via simple substrates).
- **(d) Drift-risks-cleared?** YES. All 11 test-mixed-map assertions rewritten; path-expressions updated; probe baseline refreshed with delta documentation. No stale mechanisms left hanging.

**Scope preserved** (not touched):
- Other 5 `with-speculative-rollback` sites (typing-core.rkt:1291/1325/2439, qtt.rkt:2425, typing-errors.rkt:78) — union-read disambiguation, scheduled for PM 12 light-cleanup sub-phase per T-1 PM Master handoff.
- Annotated-narrow paths: `def m : (Map K T) := {...}` strict-checks as before. Narrow-union annotations `(Map K <A | B>)` also preserved (Concern B).
- Schema system: `lookup-schema-by-name` + `selection-field-type` paths unchanged.
- On-network typing (typing-propagators.rkt): no changes needed — SRE ctor-desc decomposition handles `expr-Open` as any type component.

**Codification candidate** (watching list update — T-2 is the application of the pattern):

> *Retiring narrow-union default maps as the "accidentally-load-bearing" fingerprint.* The narrow-union-widening pathway (map-assoc calling build-union-type in the widening branch) was the SOURCE of three of the four T-3/Step-1 findings. It was architectural debt that kept surfacing as correctness-via-coincidence. Retiring it structurally (via Open-by-Design semantic) eliminated the pattern at that specific site. General lesson: when a feature produces repeated accidentally-load-bearing findings, the ergonomic-correct replacement is often simpler than more-careful-migration.

**Re-sequencing complete**: `1A-iii-a-wide Step 1 → T-1 → T-2 → Step 2` arc has landed Steps 1, T-1, T-2. Next: Step 2 (PU refactor — vision-advancing Phase 1A capstone per §7.5.4).

### §7.6.16 Phase 1E — `that-*` Storage Unification (NEW 2026-04-23)

**Status**: ⬜ Planned. Sequenced between Step 2 and Phase 1B.

**Implementation note** (NOT a Stage 3 design — this section captures the architectural considerations surfaced during 2026-04-23 Step 2 mini-design dialogue, to persist them for the future Phase 1E design cycle).

#### §7.6.16.1 Motivation

During Step 2 mini-design (2026-04-23), user surfaced architectural concern about the relationship between:
- `that-read` / `that-write` — position-keyed attribute-record API (shipped PPN 4C Phase 3, user-surface-facing per Track 7 `grammar` form vision)
- Proposed `elab-meta-read` / `elab-meta-write` — meta-id-keyed + domain-parameterized API for Step 2 PU refactor
- Track 4D's unified attribute-grammar substrate (`2026-04-22_ATTRIBUTE_GRAMMAR_UNIFICATION_VISION.md`)

**Core concern**: two APIs doing conceptually similar things (both store "what we know about expression X's type"), at different abstraction levels (position vs. meta-id). Absent unification, this is architectural debt — two sources of truth, two sets of lattice merge semantics, two dependency-tracking paths.

**Resolution for Step 2**: drop the proposed `elab-meta-*` API (Option B). Step 2 focuses on compound-cell storage. Storage-layer unification becomes its own dedicated Phase 1E.

#### §7.6.16.2 Scope

**In scope**:
- Route `that-read(am, pos, :type)` to the appropriate universe-cell component when `pos` corresponds to a meta
- Route `that-write(net, am-cid, pos, :type, val)` similarly
- Position-for-meta synthesis: derive a canonical position representation for each meta from `meta-source-info` + disambiguator (multiple metas at same source-loc must have distinct positions)
- Preserve 27 ns `that-read :type` fast path (per 2026-04-17 PRE0 baseline); meta path may add 50-150 ns routing overhead but fast path for non-meta positions unchanged
- Meta-id ↔ position mapping (bidirectional, structurally backed — probably a component of `elab-cell-info` or a new side table)
- Consumers of `that-*` see unified access regardless of whether underlying store is attribute-map or universe cell

**Out of scope** (Track 4D territory):
- Declarative grammar rule representation (4D Phase A)
- Grammar rule compiler (4D Phase B)
- Migration of typing rules to grammar form (4D Phase C)
- Sexp-infer retirement (4D Phase D)
- PUnify consolidation via attribute equations (4D Phase E)
- Zonking as readiness stratum (4D Phase F)
- Reduction as `:whnf` facet (4D Phase G)

**Phase 1E is STORAGE unification. Track 4D is RULES unification.** Both are needed for the Track 4D vision; Phase 1E is the substrate that Track 4D's rule compiler will target.

#### §7.6.16.3 Key architectural considerations (for Stage 3 design when Phase 1E opens)

**1. Position representation**

Current: position = srcloc + scope-disambiguator (per PPN 4C Phase 3).

Phase 1E options:
- **(a)** Extend position to encode either "surface position" (existing) OR "meta position" (new variant). Tagged union. Changes position type everywhere it appears.
- **(b)** Meta-positions use a synthesized srcloc + meta-id as scope-disambiguator. No type change; all consumers treat meta-positions as regular positions.
- **(c)** Separate position namespaces for surface vs meta; `that-*` dispatches on a predicate.

**Leaning (b)**: least disruptive, preserves existing attribute-map CHAMP shape. Meta-id naturally disambiguates concurrent metas.

**2. Meta-id ↔ position mapping**

Bidirectional mapping required (sometimes from meta-id, sometimes from position). Options:
- **(a)** Add to `elab-cell-info`: each meta's info includes its canonical position. Reverse map (position → meta-id) maintained in side CHAMP.
- **(b)** Position IS meta-id for meta-positions (encoding-based); no explicit map needed.
- **(c)** Extend elab-network with a `meta-position-map` field.

**Leaning (b)**: zero storage overhead; dispatch via position encoding. Depends on position representation choice.

**3. Fast path preservation (27 ns `that-read :type`)**

Current fast path: direct CHAMP lookup in attribute-map for `(position, :type)`. No conditional dispatch.

Phase 1E must preserve this for non-meta positions. Design:
- **(a)** Branch at top of `that-read`: if position is meta-position → universe-cell path; else → existing attribute-map path. Branch cost: ~1-5 ns (predicate check). Fast path effectively unchanged.
- **(b)** Type-tagged positions allow the branch to be a cheap pattern-match dispatch.

Validation: `bench-ppn-track4c.rkt` M1 must show `≤ 35 ns/call` (allow 25% margin from 27 ns baseline) for surface positions post-Phase-1E.

**4. Universe cell integration with attribute-map**

Step 2 lands 4 universe cells (`type-meta-universe-cell-id`, etc.). Phase 1E bridges these to `that-*`:
- `that-read(am, meta-pos, :type)` for meta-pos corresponding to a type meta → `(compound-cell-component-ref enet type-meta-universe-cell-id meta-id)`
- Analogous for `:mult` / `:level` / `:session` facets (though facet naming may differ — see consideration 5)

**5. Facet naming alignment**

Current facets: `:type`, `:term`, `:context`, `:usage`, `:constraints`, `:warnings`. Step 2 domains: `type`, `mult`, `level`, `session`.

Overlap: `:type` facet ↔ type domain. No direct correspondence for `:mult` / `:level` / `:session` — these are orthogonal inference dimensions not currently represented as facets in attribute-map.

Phase 1E decisions needed:
- Do mult/level/session get new facets (`:mult`, `:level`, `:session`) on attribute-records? Probably yes for consistency.
- How do they interact with existing `:usage` facet (which tracks QTT usage — related to mult but different)?

This is substantial design work. Not minor. Stage 2 audit + Stage 3 design warranted when Phase 1E opens.

**6. Write-through semantics**

`that-write(net, am-cid, meta-pos, :type, val)` routes to universe cell. But: universe cells have `compound-tagged-merge` + domain-merge (e.g., `type-unify-or-top` for type metas), while attribute-map uses `classify-inhabit-value` merge via `make-classify-inhabit-merge`. Different lattice semantics.

Question: when routing, does `that-write` use the universe cell's domain merge, or wrap in `classify-inhabit-value` for consistency with non-meta attribute-record writes?

**Leaning**: universe cell's domain merge, since universe cells are the authoritative store for meta values. The `classify-inhabit-value` wrapping is specific to attribute-map positions that carry both CLASSIFIER and INHABITANT layers — metas typically only have classifier (the type). Phase 1E resolves this tension explicitly.

**7. Track 4D compatibility**

Track 4D's §3.1 "Every expression position carries an attribute-record" — under Phase 1E, meta-positions ARE expression positions. Track 4D's grammar-rule compiler targets `that-*` as the access API. After Phase 1E:
- `that-*` is the unified access layer
- Underlying storage can be attribute-map cell OR universe cells (transparent to rule compiler)
- Track 4D can focus on RULES, not storage

This is the architectural payoff — Phase 1E makes Track 4D's substrate work clean.

#### §7.6.16.4 Performance constraints (non-negotiable)

From `2026-04-23_STEP2_BASELINE.md` §11:
- `that-read :type` surface position: **≤ 35 ns/call** post-Phase-1E (baseline 27 ns + 25% margin)
- `that-read :type` meta position (NEW): target **≤ 200 ns/call** (covers universe-cell + component ref + tagged-cell-read)
- `that-write :type` surface position: existing overhead unchanged
- `that-write :type` meta position (NEW): target **≤ 300 ns/call** (covers universe-cell write + compound-tagged-merge)

Bench harness: extend `bench-ppn-track4c.rkt` M1 with meta-position variants; validate pre-commit.

#### §7.6.16.5 Prerequisites

- **Step 2 complete** (this addendum): compound universe cells + helper + call-site migration. The storage substrate exists.
- **PPN 4C Phase 4 decided scope-wise** (not necessarily implemented — just decided): meta-info CHAMP retirement affects what data lives where. Phase 1E might coordinate or precede.
- **Benchmark baseline stable** (✓ `2026-04-23_STEP2_BASELINE.md`): need reference point for fast-path preservation.

#### §7.6.16.6 Stage 2 audit TODO (when Phase 1E opens)

- Inventory: every `that-read` / `that-write` call site and its facet usage pattern
- Inventory: every meta-access call site (post-Step-2) and the `compound-cell-component-ref` helper usage
- Position representation: grep for every consumer of `position` values in `attribute-map` context; identify representation-change ripples
- Facet semantics: audit how `classify-inhabit-value` layers interact with different facets; understand where dual-layer vs single-layer applies
- Benchmark coverage: identify which micros in `bench-ppn-track4c.rkt` stress `that-*` vs alternate paths

#### §7.6.16.7 Rough sub-phase sketch (pre-design, will be refined at Stage 3)

- **1E.a** — Position representation extension + meta-position synthesis. Add position-type-tagged dispatch in `that-read` / `that-write`. Measurement: fast path unchanged.
- **1E.b** — Route type-facet meta-positions to `type-meta-universe` via helper. Facet naming decisions.
- **1E.c** — Route mult/level/session analogously (if new facets adopted).
- **1E.d** — Retire direct `compound-cell-component-ref` call sites in favor of `that-*` (since `that-*` now handles meta positions transparently).
- **1E.e** — Cleanup + docs.
- **1E-VAG** — Vision alignment + D.3 or successor doc close.

Estimated scope: ~800-1200 LoC across 5-8 files. 3-5 sessions. Proper Stage 2 audit + Stage 3 design cycle when opened.

#### §7.6.16.8 Deferral trigger

Phase 1E opens AFTER Step 2 closes (with VAG passing). Defer signals that would push 1E later:
- Step 2 reveals additional storage-layer concerns requiring their own phase first
- PM Track 12 (module loading) starts and absorbs 1E as a joint scope item
- Track 4D opens earlier than anticipated and swallows 1E as its Phase 0

Defer signals that would pull 1E earlier (into Step 2 scope):
- Two-API cognitive load surfaces as bug source in Step 2 (not expected, but possible)
- Performance measurement at Step 2 close indicates compound-cell access pattern is significantly suboptimal without the `that-*` fast path — would motivate pulling forward

Default: 1E opens immediately after Step 2 close. Dedicated mini-design + Stage 2 audit + Stage 3 design at that point.

#### §7.6.16.9 References

- Step 2 mini-design dialogue (2026-04-23): architectural option review (A / B / C) + Path 1/2/3 decision on scheduling
- Performance baseline: [`2026-04-23_STEP2_BASELINE.md`](2026-04-23_STEP2_BASELINE.md) §1 headline, §11 PRE0→post-T-2 A/B
- Track 4D vision: [`2026-04-22_ATTRIBUTE_GRAMMAR_UNIFICATION_VISION.md`](../research/2026-04-22_ATTRIBUTE_GRAMMAR_UNIFICATION_VISION.md)
- Attribute grammar research: [`2026-04-05_ATTRIBUTE_GRAMMARS_RESEARCH.md`](../research/2026-04-05_ATTRIBUTE_GRAMMARS_RESEARCH.md) §7.5 `that` operation as AG query
- PPN 4C Phase 3 delivery: D.3 §6.15 + tracker row "Phase 3" — the `that-*` API shipped
- PPN 4C Phase 3e classification + `#:component-paths` enforcement: foundation for meta-position component paths

### §7.7 Phase 1B deliverables

**Tropical fuel primitive**:
1. New module `racket/prologos/tropical-fuel.rkt`:
   - `tropical-fuel-bot = 0` (identity for min)
   - `tropical-fuel-top = +inf.0` (absorbing)
   - `tropical-fuel-merge` = min
   - `tropical-fuel-contradiction?` = `= +inf.0`
   - `net-new-tropical-fuel-cell net` → values `(net, cell-id)`
   - `net-new-tropical-budget-cell net budget` → values `(net, cell-id)`
   - `make-tropical-fuel-threshold-propagator fuel-cid budget-cid` — factory returning a propagator that contradicts on `fuel >= budget`
2. SRE domain registration:
   - `(make-sre-domain #:name 'tropical-fuel ...)` in `tropical-fuel.rkt`
   - Tier 2 linkage: `(register-merge-fn!/lattice tropical-fuel-merge #:for-domain 'tropical-fuel)`
   - `#:classification 'value` (atomic extended-real; not component-indexed)
3. Tests (`tests/test-tropical-fuel.rkt`):
   - Merge semantics (min, bot, top, contradiction)
   - Primitive allocation (cell creation, initial values)
   - Threshold propagator fires contradiction when `cost >= budget`
   - Per-consumer independence (two instances don't cross-contaminate)
   - Cross-consumer cost comparison (quantale algebra works across instances)
4. Module imports / provides per codebase conventions
5. `tropical-fuel.rkt` imports only from `sre-core.rkt`, `merge-fn-registry.rkt`, `propagator.rkt` (no higher-level dependencies — primitive is foundational)

### §7.8 Phase 1C deliverables

**Canonical BSP fuel instance migration**:
1. Allocate canonical fuel-cost cell at `cell-id 11` in `make-prop-network` (next contiguous after `classify-inhabit-request-cell-id = 10`) using the primitive
2. Allocate canonical budget cell at `cell-id 12` with initial value from existing `make-prop-network`'s `fuel` parameter
3. Install threshold propagator at `make-prop-network` setup
4. Retire `prop-network-fuel` struct field in `prop-net-cold`
5. Retire `prop-network-fuel` accessor (`propagator.rkt:402`) — replace with `net-cell-read net fuel-cost-cell-id`
6. Migrate 15+ decrement/check sites:
   - Decrement sites (`propagator.rkt:2655, 3272, 3325`): change `(- fuel n)` to `(net-cell-write net fuel-cost-cell-id (+ cost n))` (tropical `⊗` is addition; merge via `min` ensures monotone accumulation)
   - Check sites (12 sites per audit §3.8.3): rewrite `(<= fuel 0)` to `(net-contradiction? net)` since the threshold propagator writes contradiction when fuel exhausts
7. Retire `prop-network-fuel` export
8. Update test read-only usage (15+ test sites per audit) to use `(net-cell-read net fuel-cost-cell-id)`
9. `pretty-print.rkt:462` fix (prints fuel; update to cell read)

### §7.9 Phase 1V — Vision Alignment Gate

4 VAG questions per DESIGN_METHODOLOGY Step 5:
- **On-network?** — yes; substrate retired; tropical fuel lives in cells; primitive registered at SRE.
- **Complete?** — all retirement targets + primitive + canonical instance delivered.
- **Vision-advancing?** — substrate unified; tropical fuel enables cross-consumer cost reasoning.
- **Drift-risks-cleared?** — named in Phase 1 mini-design.

### §7.10 Phase 1 termination arguments

Per GÖDEL_COMPLETENESS Phase 1's new propagators/cells:
- Tropical fuel cell — Level 1 (Tarski fixpoint): finite lattice (bounded by budget or +∞); monotone merge (min); per-BSP-round cost accumulation bounded.
- Threshold propagator — Level 1: fires once at threshold (monotone; cost only increases); contradicts-or-no-op.
- No new strata added; no cross-stratum feedback; no well-founded measure needed.

### §7.11 Phase 1 parity-test strategy

Axes:
- **speculation-mechanism-parity** (new, Phase 1A-ii): confirm `with-speculative-rollback` behavior identical pre/post TMS-cell migration
- **tropical-fuel-parity** (new, Phase 1C): confirm tropical fuel exhausts at same point as decrementing counter for representative workloads

Per D.3 §9.1 convention, wire into `test-elaboration-parity.rkt`.

---

## §8 Phase 2 — Orchestration Unification

### §8.1 Scope and rationale

Phase 2 consolidates the elaborator strata (S(-1) retraction, L1 readiness, L2 resolution) into BSP stratum handler registrations, retiring the sequential `run-stratified-resolution-pure` orchestrator. Architectural parallel to Phase 1: unify the mechanisms.

### §8.2 Sub-phase partition

- **Phase 2A — Register S(-1), L1, L2 as stratum handlers** (~75-125 LoC)
- **Phase 2B — Retire orchestrators** (~50-100 LoC)
- **Phase 2V — Vision Alignment Gate**

### §8.3 Phase 2A deliverables

1. Introduce 3 new request-accumulator cells in `make-prop-network`:
   - `retraction-stratum-request-cell-id` (cell-id 13; set-valued, set-union merge)
   - `readiness-stratum-request-cell-id` (cell-id 14; hash-union merge)
   - `resolution-stratum-request-cell-id` (cell-id 15; hash-union merge)
2. Register handlers:
   - `register-stratum-handler! retraction-stratum-request-cell-id process-retraction #:tier 'value`
   - `register-stratum-handler! readiness-stratum-request-cell-id process-readiness #:tier 'value`
   - `register-stratum-handler! resolution-stratum-request-cell-id process-resolution #:tier 'value`
3. Migrate existing sequential calls to write to the new cells:
   - `(record-assumption-retraction! aid)` at `metavar-store.rkt:1336` → `(net-cell-write net retraction-stratum-request-cell-id (set aid))`
   - L1 / L2 completion signals: write to respective cells
4. Handler functions wrap existing logic:
   - `process-retraction net request-set` wraps `run-retraction-stratum!`
   - `process-readiness net pending-hash` wraps `collect-ready-constraints-via-cells`
   - `process-resolution net actions` wraps `execute-resolution-actions!`
5. Invariant: handler behavior observationally equivalent to sequential orchestrator (parity axis)

### §8.4 Phase 2B deliverables

1. Delete `run-stratified-resolution-pure` at `metavar-store.rkt:1915` (after confirming no test callers)
2. Delete `run-stratified-resolution!` at `metavar-store.rkt:1863` (dead code; R3 external critique finding)
3. Simplify the entry point at `metavar-store.rkt:1699` to rely on BSP scheduler outer loop
4. Clean up exports at `metavar-store.rkt:172, 218, 221-222`
5. Update performance-counters.rkt:137 reference

### §8.5 Phase 2 termination arguments

- S(-1) retraction handler — Level 1: finite assumption set; narrowing only.
- L1 readiness handler — Level 1 (Tarski): pure scan, observation only.
- L2 resolution handler — Level 2 (well-founded): cross-stratum feedback decreases type depth (inherited from current implementation).
- BSP scheduler outer loop — finite because fuel-budgeted (Phase 1 tropical fuel).

### §8.6 Phase 2 parity-test strategy

Axis: orchestration parity. Confirm elaboration results identical pre-Phase-2 and post-Phase-2 for representative workloads. Parity tests wire into `test-elaboration-parity.rkt`.

---

## §9 Phase 3 — Union Types via ATMS + Hypercube Integration

### §9.1 Scope and rationale

Phase 3 ships union types via ATMS branching (D.3 §6.10), exploiting already-implemented hypercube primitives (audit §3.5) and residuation-based error-explanation (research §10.3).

### §9.2 Sub-phase partition

- **Phase 3A — Fork-on-union basic mechanism** (~100-150 LoC)
- **Phase 3B — Hypercube integration (Gray code, subcube pruning)** (~50-100 LoC)
- **Phase 3C — Residuation error-explanation** (~75-150 LoC)
- **Phase 3V — Vision Alignment Gate**

### §9.3 Phase 3A deliverables

1. Fork-on-union propagator: watches `:type` facet (classifier layer) per position; when classifier is a ⊕ compound, SRE ctor-desc decomposes into components
2. For each component: fresh assumption-id via ATMS, tag worldview, elaborate per-branch with worldview-filtered reads
3. Per-branch cost tracking: allocate per-branch fuel cell via tropical primitive (Phase 1 dependency)
4. Contradiction in branch → nogood on main network worldview-cache (S1 NAF handler pattern)
5. All branches contradict → fall through to error-explanation (Phase 3C)
6. Winning branch → commit (worldview narrows; tagged entries become authoritative)
7. Tests (`tests/test-union-types-atms.rkt`): axis union parity

Note: `elab-speculation.rkt` disposition (Q-A4) is a Phase 3A mini-design item (§16.3).

### §9.4 Phase 3B deliverables

Hypercube integration leveraging already-implemented primitives (audit §3.5):

1. Wire Gray-code branch ordering: replace naive branch enumeration with `gray-code-order` from `relations.rkt`
2. Benefit: successive forks differ by one assumption bit → CHAMP structural sharing maximized
3. Subcube pruning on contradictions: when branch X contradicts, writes nogood; subsequent branches containing the same nogood-bits skipped via `subcube-member?` check (already implemented in `decision-cell.rkt:368`)
4. Tests: performance + correctness (structural sharing benefit measurable via heartbeat counters)

### §9.5 Phase 3C deliverables

Residuation-based error-explanation for all-branch-contradict:

1. New helper `derivation-chain-for(contradicting-cell, branches, net)` in dedicated module (e.g., `error-explanation.rkt`)
2. Read-time function (not propagator) — walks propagator-firing dependency graph backward from contradicting cell
3. Collects per-step: propagator-id, assumption-id, source-loc (from Phase 1.5 srcloc infrastructure)
4. Output: structured derivation chain + human-readable message
5. Integration: error message output at Phase 3A's all-branch-contradict fall-through
6. Tests (`tests/test-union-error-explanation.rkt`): axis error-provenance-chain per D.3 §9.1 Phase 11b row

Note: Q-A6 (placement of residuation error-explanation — this track or Phase 11b diagnostic) is a Phase 3C mini-design item (§16.3).

### §9.6 Phase 3V — Vision Alignment Gate

Per 4 VAG questions:
- **On-network?** — branching via fork-prop-network (O(1) CHAMP share); tagged-cell-value worldview; residuation via on-network dep graph.
- **Complete?** — union types work end-to-end; hypercube optimizations active; error-explanation ships.
- **Vision-advancing?** — union types via ATMS is exactly the Track 4B blocked feature; hypercube + tropical + ATMS compose naturally per Hyperlattice Conjecture.
- **Drift-risks-cleared?** — named at Phase 3 mini-design start.

### §9.7 Phase 3 termination arguments

- Fork-on-union propagator — Level 2: branch count bounded by union component count; per-branch cost-bounded via tropical fuel primitive.
- Gray-code traversal — finite permutation of finite branch set.
- Residuation walk — finite dependency graph; walk terminates when all deps traversed.

### §9.8 Phase 3 parity-test strategy

Axes: union (per D.3 §9.1); error-provenance-chain (added). Parity: pre-Phase-3 union-type elaboration currently fails (not supported); post-Phase-3 succeeds. Parity tests verify narrow-by-constraint cases (`<Int | String>` narrowed by `eq?` to `Int`) per D.3 §9 §9.1.

---

## §10 Tropical quantale — implementation details

(Consolidates the tropical-specific design across all three phases)

### §10.1 SRE domain registration

```racket
(define tropical-fuel-sre-domain
  (make-sre-domain
    #:name 'tropical-fuel
    #:merge-registry tropical-fuel-merge-registry
    #:contradicts? (λ (v) (= v +inf.0))
    #:bot? (λ (v) (= v 0))
    #:bot-value 0
    #:top-value +inf.0
    #:classification 'value))
(register-domain! tropical-fuel-sre-domain)
(register-merge-fn!/lattice tropical-fuel-merge #:for-domain 'tropical-fuel)
```

### §10.2 Primitive API

```racket
;; Allocate a fuel cost cell (initial 0; merge min)
(define (net-new-tropical-fuel-cell net)
  (net-new-cell net 0 tropical-fuel-merge #:domain 'tropical-fuel))

;; Allocate a budget cell (initial budget; merge = first-write-wins)
(define (net-new-tropical-budget-cell net budget)
  (net-new-cell net budget budget-merge))

;; Threshold propagator factory
(define (make-tropical-fuel-threshold-propagator fuel-cid budget-cid)
  (λ (net)
    (define cost (net-cell-read net fuel-cid))
    (define budget (net-cell-read net budget-cid))
    (if (>= cost budget)
        (net-contradiction net 'fuel-exhausted)
        net)))
```

### §10.3 Canonical BSP scheduler instance

```racket
;; In make-prop-network (propagator.rkt)
(define-values (net1 fuel-cid) (net-new-tropical-fuel-cell base-net))
(define-values (net2 budget-cid) (net-new-tropical-budget-cell net1 fuel))
(define threshold-prop (make-tropical-fuel-threshold-propagator fuel-cid budget-cid))
(net-add-propagator net2 (list fuel-cid budget-cid) '() threshold-prop)
;; Export fuel-cost-cell-id = 11, fuel-budget-cell-id = 12
```

### §10.4 Migration of `prop-network-fuel` decrement sites

15+ sites pattern rewrite:

```racket
;; BEFORE
[fuel (- (prop-network-fuel net) n)]

;; AFTER
(net-cell-write net fuel-cost-cell-id (+ (net-cell-read net fuel-cost-cell-id) n))
```

Check sites:

```racket
;; BEFORE
[(<= (prop-network-fuel net) 0) net]

;; AFTER
[(net-contradiction? net) net]
```

(The threshold propagator writes the contradiction when `cost >= budget`, so `net-contradiction?` is already checking the right thing.)

### §10.5 Residuation for error-explanation

Per research §10.3. When threshold propagator writes contradiction (fuel exhausted), the `derivation-chain-for` helper can be invoked (from Phase 3C, subject to Q-A6 mini-design) to walk backward. For pure fuel exhaustion (outside union-branching context), the chain is the sequence of propagators that consumed fuel — in order, with per-step costs. Broader applicability (non-union contradictions) is Phase 11b diagnostic territory per Q-A6 mini-design decision.

### §10.6 Future multi-quantale composition

Primitive API supports cross-consumer cost queries via shared quantale algebra (Module Theory §6.4 tensor products). Not shipped in Phase 1-3; primitive enables without requiring. Future PReduce or other tracks can allocate their own fuel cells and reason about combined costs via quantale morphisms.

---

## §11 P/R/M/S Self-Critique

Applied inline during decision-making; consolidated here per DESIGN_METHODOLOGY Stage 3 requirement. The S lens (SRE Structural Thinking: PUnify / SRE / Hyperlattice+Hasse / Module-theoretic / Algebraic-structure-on-lattices) is an addition per user direction 2026-04-21, codified in DESIGN_METHODOLOGY.org Stage 3 §6 Lens S.

### §11.1 P — Principles challenged

Decisions reviewed against the 10 load-bearing principles:

| Decision | Principle served | Potential conflict | Resolved? |
|---|---|---|---|
| Substrate-level tropical fuel primitive (Q-A2) | Most Generalizable Interface, First-Class by Default | — | ✓ |
| 3-phase sequential partition (Q-A1) | Decomplection | — | ✓ |
| Phase 4 β2 contract specified here (Q-A7) | Decomplection, Completeness | — | ✓ |
| Phase 9b interface specified here (Q-A8) | Decomplection | — | ✓ |

**Red-flag scrutiny**: no "temporary bridge," "belt-and-suspenders," "pragmatic shortcut" in Phase 1-3 architectural commitments. Phase-specific scope (Q-A3-A6) deferred to mini-design per user direction — not pre-committed.

### §11.2 R — Reality check (code audit)

Audit §3 (Stage 2) grounded the design in concrete code. Highlights:
- Phase 2 scope matches audit §3.9 findings (3 strata, 1 orchestrator to retire)
- Phase 1C migration sites count matches audit §3.8 (15+ `prop-network-fuel` sites)
- Phase 3 infrastructure matches audit §3.6 (90% union-type machinery in place)
- Audit §3.5 confirms hypercube primitives already implemented; Phase 3B is integration

Scope claims tied to grep-backed audit data; no speculation floats above the codebase.

### §11.3 M — Propagator mindspace

Design mantra check (§5) passed for all components. Highlights:
- Tropical fuel cell: pure cell-based, merge via `min`; no hidden state
- Threshold propagator: fires once at threshold; monotone
- Fork-on-union: all-at-once decomposition via ctor-desc; per-branch elaboration structurally emergent
- Gray-code ordering: structural hypercube adjacency, not imposed
- Subcube pruning: O(1) bitmask check, not scan
- Residuation chain: read-time walk on existing dep graph; not new propagator

No "scan" / "walk" / "iterate" in propagator design (all operations are cell reads/writes or structural decomposition).

### §11.4 S — SRE Structural Thinking

PUnify, SRE, Hyperlattice/Hasse, Module-theoretic, Algebraic-structure-on-lattices applied per new DESIGN_METHODOLOGY Lens S:

**PUnify**:
- Per-branch union elaboration invokes `unify-union-components` (audit §3.6); reuses existing PUnify infrastructure (research doc §6.4)
- No new unification algorithm

**SRE**:
- Tropical fuel is an SRE-registered domain (§10.1); property inference runs at registration
- Union-type branching uses SRE ctor-desc decomposition (D.3 §6.10); no hand-rolled pattern matcher
- Tagged-cell-value (Module Theory Realization B) carries per-branch state

**Hyperlattice / Hasse**:
- Worldview lattice IS Q_n hypercube; Gray code + subcube pruning exploit this structural identity (per `structural-thinking.md` mandate for Boolean lattices)
- Phase 2's stratum handler topology Hasse: 9 handlers in 2 tiers, BSP scheduler iterates uniformly

**Module theoretic**:
- Cells are Q-modules (research §6.5); propagators are Q-module morphisms
- Tropical fuel cell is a 1-dim tropical-quantale module
- Cross-consumer fuel cells compose via quantale tensor products (research §6.4)
- Residuation native in quantale modules (research §6.4)

**Algebraic structure on lattices**:
- Tropical quantale registered with full property declaration (Quantale, Integral, Residuated, Commutative)
- Residuation formula: `a \ b = b - a` when b ≥ a else bot (research §9.3)
- Error-explanation uses the quantale left-residual (research §5.6, §10.3)
- TypeFacet quantale (SRE 2H) + tropical fuel quantale compose via Galois bridges (future work; primitive enables)

---

## §12 Parity test skeleton

Per D.3 §9.1, each phase enables its parity axis tests in `test-elaboration-parity.rkt`:

| Phase | Axis | Tests to enable |
|---|---|---|
| 1 | tropical-fuel (NEW) | fuel-exhaustion-parity (old counter vs new cell yields equivalent exhaustion point) |
| 2 | orchestration (NEW per R3 critique) | orchestration-parity (elaboration result identical pre/post) |
| 3A | union (D.3 §9.1) | union-narrow-by-constraint (`<Int\|String>` narrowed to `Int` by `eq?`) |
| 3B | hypercube-structural-sharing (NEW) | CHAMP reuse improvement under Gray code (microbench-backed) |
| 3C | error-provenance-chain (D.3 §9.1, adapted) | `derivation-chain-for` output shape for all-branch-contradict |

Phase V (capstone): all parity tests GREEN.

---

## §13 Termination arguments

Consolidated per DESIGN_METHODOLOGY requirement.

| Component | Phase | Guarantee level | Measure |
|---|---|---|---|
| Tropical fuel merge | 1 | Level 1 (Tarski) | Finite lattice bounded by budget; monotone min |
| Tropical fuel threshold propagator | 1 | Level 1 | Fires once at threshold; monotone cost accumulation |
| Retraction stratum handler | 2 | Level 1 | Finite retracted-aid set; narrowing only |
| Readiness stratum handler | 2 | Level 1 | Pure scan; observation only |
| Resolution stratum handler | 2 | Level 2 (well-founded) | Cross-stratum feedback decreases type depth |
| Fork-on-union propagator | 3 | Level 2 | Bounded by ⊕ component count; per-branch fuel-budgeted |
| Gray-code traversal | 3 | — | Finite permutation of finite branch set |
| Subcube pruning | 3 | — | O(1) bitmask check per nogood |
| Residuation walk | 3 | — | Finite dep graph; one pass |

BSP scheduler outer loop finite via canonical tropical fuel cell (Phase 1 dependency).

---

## §14 Phase 4 β2 substrate contract

Per Q-A7 resolution (§6.3). Phase 4 (PPN 4C CHAMP retirement with β2 scope — attribute-map becomes sole meta store) consumes from Phase 1-3 the following:

**Consumes (read-only or read-write per-meta)**:
- `worldview-cache-cell-id` + per-propagator `current-worldview-bitmask` (for meta worldview-tagging)
- Tropical fuel primitive (optional — if per-meta elaboration cost tracking desired; not required)
- `classify-inhabit-value` Module Theory Realization B tag-dispatch (already shipped Phase 3 of PPN 4C)
- `solver-context` / `solver-state` (modern ATMS API)
- Phase 2 stratum handler substrate (if meta-specific stratification desired; not required)

**Does NOT consume (retired by Phase 1-3)**:
- `current-speculation-stack` (retired Phase 1)
- `prop-network-fuel` field (retired Phase 1C)

**Invariants Phase 1-3 guarantees for Phase 4**:
- Substrate worldview bitmask read/write is stable and cell-based
- Tropical fuel primitive API is stable (mini-design for Phase 4 may decide per-meta instance allocation)
- Stratum handler API is stable post-Phase-2
- Union-type ATMS branching (Phase 3) supports meta-level union types (per-meta classifier may be a union)

**Mini-design items for Phase 4 start**:
- Decision: per-meta fuel tracking (via primitive) or inherit canonical BSP fuel?
- Decision: meta-specific stratum handler (if any) or reuse existing strata?

---

## §15 Phase 9b interface specification

Per Q-A8 resolution (§6.4). Phase 9b γ hole-fill propagator (D.3 §6.2.1, §6.10) consumes from Phase 1-3:

**Consumes**:
- Tagged-cell-value multi-candidate ATMS branching mechanism (Phase 3A delivery)
- Phase 2b Hasse-registry primitive (from PPN 4C Phase 2b, already shipped)
- `classify-inhabit-value` tag-dispatch (Phase 3 of PPN 4C, shipped)
- Tropical fuel primitive (optional — cost-bounded hole-fill)

**Invariants for Phase 9b**:
- Tagged branching mechanism is stable post-Phase-3
- Residuation error-explanation API (`derivation-chain-for`) can generalize to γ's multi-candidate explanations

**Detailed design**: owned by Phase 9b's own design cycle. This document specifies only the interface.

---

## §16 Open questions — mini-design scope (not blockers)

Per user direction: phase-specific questions deferred to mini-design at phase start. Listed here for traceability; each question has its mini-design trigger point.

### §16.1 Phase 1 mini-design items

- **Q-A3** (Retirement scope for Phase 1): how much of ATMS retirement (deprecated `atms` struct, `atms-believed` field per BSP-LE 2B D.1 finding, surface AST migration) is in Phase 1 vs deferred? A/B-microbench alternatives if performance-relevant; Q-A5 (atms-believed) is architecturally coupled.
- **Q-A5** (atms-believed retirement timing): structurally coupled to Q-A3 — retires with the deprecated struct, if at all.
- API naming for tropical fuel primitive
- Representation: `+inf.0` vs sentinel for fuel-exhausted
- `wrap-with-assumption-stack` migration: single caller replacement strategy
- A/B microbench: decrement counter vs min-merge cell (fuel cost migration)
- Remaining internal deprecated-atms consumers audit (grep for opportunistic migration)

### §16.2 Phase 2 mini-design items

- Request cell-id allocation (13, 14, 15 proposed; confirm next available)
- Retraction handler request-clearing invariant
- L1 / L2 shared cell vs separate cells
- A/B microbench: sequential orchestrator vs BSP-iterated handlers

### §16.3 Phase 3 mini-design items

- **Q-A4** (elab-speculation.rkt disposition): delete dead library, retain as library primitives for union branching, or migrate its API to pure-bitmask? Phase 3A decides with code in hand.
- **Q-A6** (residuation for error-explanation placement): ships with Phase 3C for union all-branch-contradict, or deferred entirely to Phase 11b diagnostic? Phase 3C decides, informed by union branching implementation complexity.
- Per-branch fuel: separate budget vs shared
- Cell-to-tagged promotion discipline
- `infer`/`check` dispatch integration point for union fork
- Bitmask subcube: 9-bit vs bitvector
- `derivation-chain-for` API signature + output format
- LSP integration hooks (forward ref)

### §16.4 Cross-phase (all)

- Drift risks per phase (named at phase start per VAG step 5d)
- Parity test detailed cases per axis

---

## §17 References

### §17.1 Stage 1/2 artifacts (this track)
- [`docs/research/2026-04-21_TROPICAL_QUANTALE_RESEARCH.md`](../research/2026-04-21_TROPICAL_QUANTALE_RESEARCH.md)
- [`docs/tracking/2026-04-21_PPN_4C_PHASE_9_AUDIT.md`](2026-04-21_PPN_4C_PHASE_9_AUDIT.md)

### §17.2 Parent and adjacent design docs
- [`docs/tracking/2026-04-17_PPN_TRACK4C_DESIGN.md`](2026-04-17_PPN_TRACK4C_DESIGN.md) (D.3)
- [`docs/tracking/2026-03-22_NTT_SYNTAX_DESIGN.md`](2026-03-22_NTT_SYNTAX_DESIGN.md) (NTT syntax reference for §4)
- [`docs/research/2026-04-06_CELL_BASED_TMS_DESIGN_NOTE.md`](../research/2026-04-06_CELL_BASED_TMS_DESIGN_NOTE.md)
- [`docs/research/2026-04-08_HYPERCUBE_BSP_LE_DESIGN_ADDENDUM.md`](../research/2026-04-08_HYPERCUBE_BSP_LE_DESIGN_ADDENDUM.md)
- [`docs/research/2026-03-28_MODULE_THEORY_LATTICES.md`](../research/2026-03-28_MODULE_THEORY_LATTICES.md)

### §17.3 Completed-track PIRs
- BSP-LE Track 2 PIR — worldview substrate foundations
- BSP-LE Track 2B PIR — Module Theory Realization B, hypercube addendum
- PPN Track 4B PIR — Phase 8 union types blocked on cell-based TMS

### §17.4 Methodology and rules
- [`docs/tracking/principles/DESIGN_METHODOLOGY.org`](principles/DESIGN_METHODOLOGY.org) Stage 3 (incl. new Lens S)
- [`docs/tracking/principles/DESIGN_PRINCIPLES.org`](principles/DESIGN_PRINCIPLES.org)
- [`docs/tracking/principles/CRITIQUE_METHODOLOGY.org`](principles/CRITIQUE_METHODOLOGY.org)
- [`.claude/rules/on-network.md`](../../.claude/rules/on-network.md)
- [`.claude/rules/propagator-design.md`](../../.claude/rules/propagator-design.md)
- [`.claude/rules/stratification.md`](../../.claude/rules/stratification.md)
- [`.claude/rules/structural-thinking.md`](../../.claude/rules/structural-thinking.md)

---

## Document status

**Stage 3 Design D.3** — scope revised per Phase 1A mini-design audit finding (2026-04-21). Next: Phase 1A-i implementation (dead-code cleanup, ~30-50 LoC). Phase 1A-ii (elaborator-network.rkt migration) gets its own mini-design audit at phase start per Stage 4 methodology.
