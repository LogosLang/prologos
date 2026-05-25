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

PPN 4C's charter (D.3 §1) is to bring elaboration completely on-network. Phase 9+10+11 is the **substrate and orchestration unification chapter** of that charter. Four architectural moves, all instances of the same pattern ("unify the mechanisms"):

1. **Substrate**: retire legacy speculation-stack + migrate fuel-counter to tropical-quantale primitive, leaving one substrate story (bitmask worldview cell + per-propagator override + tropical fuel primitive)
2. **Orchestration (in-form)**: retire the sequential `run-stratified-resolution-pure` in favor of BSP scheduler's uniform stratum iteration via `register-stratum-handler!`
3. **Features**: ship union types via ATMS branching (D.3 §6.10) atop the unified substrate + orchestration, exploiting already-implemented hypercube primitives (Gray code, Hamming, subcube-member?, tree-reduce)
4. **Orchestration (between-form)**: retire `process-command`'s sequential top-level form loop in favor of BSP-orchestrated form processing. Completes the "no sequential orchestrators" thesis at all layers. Designed at phase open ([#22](https://github.com/LogosLang/prologos/issues/22)).

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

**Phase 4 — Top-level orchestration unification** (LoC TBD; mini-design at phase open)
- Retire `process-command`'s sequential top-level form loop in `driver.rkt`
- Per-form-type processing as BSP stratum handlers (parallel to Phase 2's in-form retirement pattern)
- Topology-phase semantics: top-level names register into cells before any body elaborates
- Mutual recursion falls out of cell architecture (no order needed) — completes the thesis at all layers
- Coordinate with PM Track 12 (parameter→cell migration for env) and PM Track 10 (module loading on network)
- Motivating use case: mutual recursion ([PR #14](https://github.com/LogosLang/prologos/pull/14), kumavis pitfall #4)
- Tracking: [#22](https://github.com/LogosLang/prologos/issues/22)

**Total estimate**: 830-1450 LoC across Phases 1-3 + their sub-phases (revised D.3 per Phase 1A mini-audit scope finding); Phase 4 estimated at phase-open mini-design.

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
| **1A-iii-a-wide Step 2** | PU refactor (4 per-domain universes + shared hasse-registry + compound-tagged-merge + cell-access helper) | ✅ **CLOSED 2026-04-25** | Vision-advancing capstone for Phase 1A. Per D.3 §7.5.4 (revised 2026-04-23 to Option B). All sub-phases delivered: S2.a + a-followup + b (TYPE) + c (mult; precursor + i-iv with Move B+ corrective) + c-v + d (level + session + followup) + e (i + ii + iii + iv-a/b/c + v + vi + VAG). **Step 2 net delivery**: universe cell as single source of truth for all 4 meta domains; meta-domain-info dispatch fully unified (lean 4 keys/domain); ~929 net LoC deletion across S2.e arc; 6 codifications graduated; Move B+ benefit MAINTAINED through 5 sub-phases (microbench-claim verification rule pays off); honest §5 hypothesis reframing per §7.5.14.4 (per-command transient consolidation captured as Track 4D scope). |
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
| Step 2 S2.c-iv (was v) | `fresh-mult-meta` universe-path branch + cross-domain bridge migration (`current-structural-mult-bridge` declares component-paths) | ✅ | 3 commits: S2.precursor++ extending primitive with CBC compound-cell access + gamma-fn=#f support `22866050`; S2.c-iv core (fresh-mult-meta + 'universe-active? flip + solve-mult-meta! dispatch + driver callback + retire mult->type-gamma) `e791739c`; S2.c-iv close (this — adversarial VAG + tracker + dailies). **Atomic migration**: storage (fresh-mult-meta) + dispatch (table flag) + writes (solve-mult-meta!) + bridge (component-paths via CBC primitive) + retired dead γ everywhere. **Probe**: cell_allocs 1195 → 1183 (-12 — mult metas no longer per-meta cells). **Suite**: 7920/124.2s/0 failures within variance. **Adversarial VAG findings**: 2 minor cleanups captured in §7.5.14 S2.e scope (elab-add-type-mult-bridge test-only post-S2.c-iv; parameter scaffolding for pre-init paths). |
| Step 2 S2.c-v (was vi) | Probe + targeted suite + measurement + GO/no-go for S2.d | ✅ | **DONE** 2026-04-25 (this commit). Probe diff = 0 semantically (28 result strings IDENTICAL to baseline; cell_allocs 1183 = mult win -12 from S2.b); acceptance file 0 errors; Section F microbench verified Move B+ ~80% gain SURVIVED S2.c-iv (Path 1 went 625→372 ns at W1, ~84% of predicted 302 ns benefit retained). **3 of 6 §5 criteria MET**: fresh-meta 2.13 μs ≤2.5 ✓ (improved past target); solve-meta! 7.67 μs ≤8 ✓ (S2.b-iv regression UNWOUND, -10% PAST baseline); meta-solution 0.383 μs ≤0.4 ✓. cells=54 + cell_allocs=1183 transitional (S2.d/e). Suite 124.2s within 118-127s variance. **Surprising finding**: solve-meta! regression unwound — partial-migration micros often resolve when architecture completes (codification candidate extending §12.3). [STEP2_BASELINE.md §12.4](2026-04-23_STEP2_BASELINE.md#124-s2c-iv-close-measurement-2026-04-25) added with full data. **GO for S2.d** (apply `pipeline.md` Per-Domain Universe Migration checklist prophylactically). |
| **Step 2 S2.d-level** | LEVEL domain universe migration (3 atomic sites per pipeline.md "Per-Domain Universe Migration": fresh-level-meta + solve-level-meta! + 'universe-active? flip) | ✅ | 1 commit `badf5fa9`. **Atomic per checklist** — fresh + solve + flag flip in same commit; pipeline.md checklist applied prophylactically (would have prevented S2.c-iv 4-min hang). NO cross-domain bridge for level (self-contained); NO γ retirement applicable. Probe: cell_allocs **1181** (-2 from S2.c-iv 1183 = level win); semantic diff = 0 (all 28 result strings IDENTICAL); 132 targeted tests across 6 files (test-metavar + test-meta-feedback + test-mult-propagator + test-tycon + test-elaborator-network + test-sess-inference) all GREEN in 7.1s. |
| **Step 2 S2.d-session** | SESSION domain universe migration (3 atomic sites per checklist) | ✅ | 2 commits: S2.d-session core (`440e6139`) + S2.d-followup honesty reframe (this). Same atomic pattern as S2.d-level. **Slight complication**: `sess-meta` struct has `cell-id` field (Track 10B Phase B1b PM-8F-style cache). **S2.d-followup correction (2026-04-25)**: under universe-active path, cell-id field is set to **#f** (was misleadingly set to universe-cid in initial S2.d-session commit). Per Move B+ (S2.c-iii commit `c86596e0`), meta-domain-solution IGNORES explicit-cid under universe-active dispatch — the field is functionally INERT. Setting to #f honestly signals "no per-meta cell allocated"; setting to universe-cid was misleading scaffolding. The 2 production callers (zonk-session + zonk-session-default at metavar-store.rkt:2873/2893) pass `(sess-meta-cell-id s)` to `sess-meta-solution/cell-id` which under universe-active routes via parameter-read for universe-cid — explicit-cid arg is unused. Field itself awaits Phase 4 retirement per D.3 §7.5.14.2 (cache-field cleanup absorbed into CHAMP retirement coherent unit). **Same reframe applied to expr-meta.cell-id (S2.b-iii path)** — was set to type-universe-cid; now #f under universe-active for parallel honesty. NO cross-domain bridge; NO γ retirement applicable. Probe: cell_allocs 1181 (no change — session metas not exercised in probe); semantic diff = 0; acceptance file 0 errors; targeted tests all GREEN. **All 4 domains now universe-active** ('type + 'mult + 'level + 'session); meta-domain-info dispatch fully unified. |
| **Step 2 S2.e** | Factory retirement + final formal measurement + 6 codifications (Step 2 close) | ✅ **COMPLETE — all 7 sub-phases delivered (i + ii + iii + iv-a/b/c + v + vi + VAG)** | **Mini-design persisted at D.3 §7.5.15** (commit `209d5721`, 2026-04-25). 7 sub-phases: S2.e-i (Option C-4 lazy init, ZERO test fixture surgery) → S2.e-ii (retire mult write callback) → S2.e-iii (retire 3 factory callbacks) → S2.e-iv (retire 6 store/champ-box params + 4 fallback fns + clean meta-domain-info) → S2.e-v (elab-add-type-mult-bridge test-only retirement per §7.5.14.3) → S2.e-vi (§5 measurement + honest hypothesis reframing per §7.5.14.4 + 4 codifications) → S2.e-VAG (adversarial close). Total scope ~-200-300 LoC NET (mostly deletions). **Critical finding from mini-design audit (§7.5.14.4)**: §5 hypothesis (cells ≤ 42, cell_allocs ≤ 1000) was framed for PERSISTENT meta cells; measurement reveals the bottleneck is per-command TRANSIENT cells (~30-50 cells per command × 28 commands = ~1100 transient allocations dominating cell_allocs). Step 2 met its actual charter (persistent meta consolidation + dispatch unification + Move B+ benefit retained); per-command transient consolidation is captured as Track 4D scope (§7.5.14.4 + Track 4D research forward-pointer + DEFERRED.md entry). **S2.e-vi is most important**: honest reframing rather than rationalizing "the architecture is right, the metric was framed wrong." |
| **Step 2 S2.e-i (Option C-4 lazy init)** | Lazy `init-meta-universes!` in 4 fresh-X-meta sites — eliminates fallback path STRUCTURALLY | ✅ | 1 commit `0a38fab2` (2026-04-25). Per D.3 §7.5.15.1 — added `(when (and net-box (not (current-X-meta-universe-cell-id)))) → init-meta-universes!` guard at the top of fresh-meta + fresh-mult-meta + fresh-level-meta + fresh-sess-meta. **+28 / -4 LoC** (32 net). Pure refactor — no new tests needed (production + with-fresh-meta-env: noop because reset-meta-store! already calls init; lazy init only fires in bare-metavar-store test contexts). **Verification**: probe diff = 0 semantically (cell_allocs=1181 IDENTICAL to S2.d-followup baseline; all 28 result strings match); acceptance file 0 errors; 9 targeted tests / 194 cases all GREEN in 9.7s; **full suite: 7920 / 118.4s / 0 failures** within 118-127s baseline variance band. **Drift risk D1 verified**: lazy guard prevents double-allocation; `init-meta-universes!` is atomic. Enables aggressive retirement in S2.e-ii through S2.e-v. |
| **Step 2 S2.e-ii (retire mult write callback)** | Retire `current-prop-mult-cell-write` parameter + restore symmetry with level/sess | ✅ | 1 commit `e943f6d7` (2026-04-25). Per D.3 §7.5.15.2 + §7.5.14.3 — 4 atomic edits: removed provide, deleted parameter definition, deleted driver install, replaced callback dispatch in solve-mult-meta! legacy [else] with direct `(elab-cell-write enet cid solution)` matching solve-level-meta!/solve-sess-meta! pattern. **+22 / -7 LoC** (15 net deletion). The asymmetry was a legacy artifact noted in S2.c-iv adversarial VAG. Post-S2.c-iv + S2.e-i, the legacy [else] branch is unreachable in any context with net-box (lazy init ensures cid is universe-cid); replacement is defensive only — full removal in S2.e-iv with rest of legacy paths. `elab-mult-cell-write` definition retained for 1 test consumer (test-mult-propagator.rkt:187); will be retired in S2.e-v. **Verification**: probe diff = 0; 4 targeted tests / 73 cases GREEN in 5.0s; **full suite 7920 / 124.7s / 0 failures** within 118-127s variance. |
| **Step 2 S2.e-iv-c (meta-store + champ-box retirement + 169-test-file surgery)** | Retire 6 store/champ-box parameter definitions + provides + with-fresh-meta-env bindings + reset-meta-store! cleanup + 180-file mechanical sed batch (169 tests + 7 benchmarks + driver + lsp + tools/batch-worker) | ✅ | 1 commit `d7bd97a4` (2026-04-25). Per D.3 §7.5.15.2 (Category A per pre-implementation audit) + §7.5.14.1. **180 files modified, 108 insertions / 427 deletions = ~319 net deletion**. Methodology: smart 2-pass sed (substitution preserves closing `)` for `(make-hasheq)])` lines; deletion removes `(make-hasheq)]` lines). Initial single-pass sed broke 94 parameterize blocks (deleted closing parens); detected via test-session-runtime-03.rkt read-syntax error; reverted via `git checkout`, redid with 2-pass sed. ALL fixed. Production cleanup: 6 parameter retirements + 6 provides + 6 with-fresh-meta-env bindings + reset-meta-store! simplification (removed 3 hash-clear! + 3 champ-box set-box! + 3 create-on-first-call; collapsed `(if mi-box (begin ...) (begin ...))` to simple `if/then/else`) + 3 driver.rkt module-loading bindings. **Verification**: probe diff = 0; 8 targeted tests / 155 cases GREEN in 10.2s including previously-broken test-session-runtime-03.rkt; **full suite 7920 / 119.7s / 0 failures** within 118-127s variance, on lower end. |
| **Step 2 S2.e-iii (retire 3 fresh-X-cell callbacks)** | Retire `current-prop-fresh-{mult,level,sess}-cell` parameters + their legacy [else] branches | ✅ | 1 commit `619a8776` (2026-04-25). Per D.3 §7.5.15.2 + §7.5.14.1 — 6 edits: removed 3 provides, deleted 3 parameter definitions, removed 3 driver installs, simplified fresh-mult-meta + fresh-level-meta from cond to when (cond value unused; [else] removed), kept fresh-sess-meta cond [else #f] structure (cond value bound to cell-id). **+79 / -97 LoC** (18 net deletion). Post-S2.e-i (lazy init), the legacy [else] branches were unreachable in any context with net-box; their removal is the literal "Dead code post-lazy-init" the design called for. The elab-fresh-X-cell functions (elaborator-network.rkt:965, 1089, 1109) remain — `elab-fresh-mult-cell` has 1 test consumer (test-mult-propagator.rkt:122); S2.e-v / Phase 4 retires. **Verification**: probe diff = 0 (all 28 result strings IDENTICAL); 10 targeted tests / 217 cases GREEN in 12.2s; **full suite 7920 / 124.2s / 0 failures** within 118-127s variance. |
| **Step 2 S2.e-iv-a (champ-box status migration)** | Migrate fresh/solve-{mult,level,sess}-meta!'s status tracking from champ-box to universe cell. Architectural: eliminates dual-source-of-truth post-S2.d. | ✅ | 1 commit `85e9ad8b` (2026-04-25). Per D.3 §7.5.15.2 (Category B per pre-implementation audit) + §7.5.14.1. **Sub-phase split** of S2.e-iv per implementation audit (3 sub-phases: a/b/c). 7 atomic edits: 3 fresh-X-meta drop champ-box write; 3 solve-X-meta! replace champ-box-based status check with universe cell read + drop champ-box write + simplify cell write (drop id-map detour + dead [else]); 1 retraction loop deletes 3 mult/level/sess champ-box retraction blocks. **+86 / -117 LoC** (31 net deletion). New structure: "Unknown meta" check via raw `elab-cell-read` + `hash-has-key?`; "Already solved" check via `meta-domain-solution` (worldview-filtered); write via `compound-cell-component-write` directly. Type-meta universe pattern (post-S2.b-iii) showed worldview-bitmask filtering at read time replaces explicit retraction. **Drift risks D1 + D4 VERIFIED** via test-speculation-bridge GREEN (universe cell's tagged-cell-value correctly handles per-worldview rollback via enet snapshot). **Verification**: probe diff = 0; 10 targeted tests / 217 cases GREEN in 11.4s including speculation-bridge; **full suite 7920 / 125.0s / 0 failures** within 118-127s variance. Champ-box parameters become unused post-S2.e-iv-a (no reads, no writes); formal retirement S2.e-iv-c. |
| **Step 2 S2.e-iv-b (champ-fallback + legacy-fn cleanup)** | Retire 6 dead functions (3 mult/level/sess champ-fallback + 3 legacy-X-fn) + simplify meta-domain-info table + simplify meta-domain-solution dispatch | ✅ | 1 commit `6efb709e` (2026-04-25). Per D.3 §7.5.15.2 (Category C). 6 function deletions + meta-domain-info table cleanup + meta-domain-solution simplification. **+54 / -150 LoC** (96 net deletion). KEPT: type-champ-fallback (still active reading current-prop-meta-info-box; Phase 4 retires alongside meta-info CHAMP). Table simplified: `'universe-active?` (4 entries) + `'legacy-fn` (3 entries) + `'champ-fallback` for mult/level/sess (3 entries) all removed. meta-domain-solution: outer cond on `'universe-active?` retired (always #t); pure universe dispatch with defensive `(hash-ref info 'champ-fallback (lambda (_id) #f))` for type-only fallback. The architectural intent "universe cell as single source of truth" now FULLY REALIZED in dispatch core. **Verification**: probe diff = 0; 10 targeted tests / 217 cases GREEN in 10.8s; **full suite 7920 / 123.0s / 0 failures** within 118-127s variance. |
| **Step 2 S2.e-v (Wide retirement: 6 test-only/dead-code mult-cell + bridge surfaces + test migration)** | Retire 6 functions in elaborator-network.rkt: elab-fresh-mult-cell + elab-mult-cell-read + elab-mult-cell-write + elab-add-type-mult-bridge + elab-fresh-level-cell + elab-fresh-sess-cell. Migrate test-mult-propagator.rkt to use net-add-cross-domain-propagator + type->mult-alpha directly. | ✅ | 1 commit `118ab57a` (2026-04-25). Per D.3 §7.5.14.3 + audit-driven scope expansion (capture-gap pattern, 3rd data point this session — graduation-ready). Audit revealed 6 surfaces (vs design's named 2). User-directed Wide + Migrate. **+91 / -130 LoC** (39 net deletion across 2 files). Test migration: helper inlines mult cell allocation (mirrors retired elab-fresh-mult-cell pattern) + direct primitive bridge install + 6 elab-mult-cell-read → elab-cell-read + bridge/gamma-noop test retired (γ retired in S2.c-iv → test premise no longer valid). 13 bridge tests preserved (was 14). **Verification**: probe diff = 0 (cell_allocs=1181 IDENTICAL; all 28 result strings match baseline); acceptance file 0 errors; 109 targeted tests across 6 files GREEN in 6.1s; **full suite 7914 / 119.3s / 0 failures** within 118-127s variance (-1 from gamma-noop; -5 from test-properties.rkt counting variance — passes 13 individually, batch counts as 8; not a regression). Adversarial VAG TWO-COLUMN passed; the Wide-vs-Narrow scope decision IS the adversarial finding (capture-gap caught the 4 surfaces the design's narrow framing missed). |
| **Step 2 S2.e-vi (final §5 measurement + honest hypothesis reframing + 6 codifications graduation)** | Re-run bench-meta-lifecycle full sequence; honestly reframe §5 hypothesis per §7.5.14.4 (per-command transients dominate cell_allocs, NOT persistent metas); graduate 6 watching-list patterns to DEVELOPMENT_LESSONS.org. THE most important S2 deliverable beyond the architecture. | ✅ | 1 commit (this commit, 2026-04-25). Bench results: 3 of 6 §5 micro criteria MET (fresh-meta 2.367 μs ✓; solve-meta! 7.832 μs ✓ — partial-state regression UNWOUND past baseline; meta-solution 0.368 μs ✓); 2 transitional (cells=54, cell_allocs=1181) honestly reframed per §7.5.14.4 — **§5 hypothesis was framed for the wrong bottleneck** (per-command transients ~1100 of 1181 dominate; persistent meta consolidation worked as charter); full suite 7914/119.3s within variance. Section F Move B+ benefit MAINTAINED through 5 sub-phases (Path 4 still dominates Path 1 by 28-46 ns across 3 workloads). STEP2_BASELINE.md §12.5 added with full data + honest D4 reframing + 6 codification graduation list. DEVELOPMENT_LESSONS.org extended with 6 entries: (1) Pipeline.md per-domain universe migration prophylactic; (2) Capture-gap pattern (3 data points this session); (3) Partial-state regression unwinds when architecture completes (3 data points); (4) Audit-first methodology prevents under-scoped implementation (4 data points); (5) Audit-driven scope expansion Wide vs Narrow decision point (NEW codification, 2 data points); (6) Sed-deletion 2-pass operational rule (1 high-confidence data point); (7) Microbench-claim verification pays off across sub-phase arcs (3 data points extending workflow.md rule). Per-command transient consolidation captured as Track 4D scope per D.3 §7.5.14.4 + Track 4D research §5.4 + DEFERRED.md "Future Track 4D Scope". |
| **Phase 1D** | **Meta-Solution Canonical Store Consolidation** | ⏸️ **DEFERRED to PPN 4D (2026-05-19)** | Added during rewound 1E exploration as proposed precursor (Architecture A: reverse-bridge propagator from universe cell to attribute-map :term). Architecture A blocked empirically by install-breaks-resolution diagnostic finding (6 reductions all fail; topology-stratum hypothesis untested). Scope re-thinking 2026-05-19 recognized 1D as scope drift — dual-store inconsistency is sources-of-truth fragmentation, fits 4D's charter. Full findings carried forward to [PPN 4D Implementation Draft Note (2026-05-19)](2026-05-19_PPN_4D_IMPLEMENTATION_DRAFT_NOTE.md). Pre-Phase-1E cleanup commit `1340aec8` (Move B+ 2nd instance) stands as Phase 1V incidental cleanup. See §7.6.16 deferral header for rationale. |
| **Phase 1E** | **`that-*` Storage Routing Extension** | ⏸️ **DEFERRED to PPN 4D (2026-05-19)** | Storage-layer unification originally planned between Step 2 and Phase 1B per architectural dialogue 2026-04-23. Re-scoping decision 2026-05-19: belongs in PPN 4D's substrate-unification charter, not the addendum's substrate+orchestration scope. Full findings (Stage 2 audit + research + architecture exploration + critical install-breaks-resolution diagnostic finding) carried forward to [PPN 4D Implementation Draft Note (2026-05-19)](2026-05-19_PPN_4D_IMPLEMENTATION_DRAFT_NOTE.md). Durable bench harness `bench-attribute-record.rkt` + baselines preserved. See §7.6.16 deferral header for rationale. |
| 1A-iii-b | Tier 2: Deprecated `atms` struct + `atms-believed` + deprecated internal API retirement | ⬜ | Independent of Path T; can proceed in parallel |
| 1A-iii-c | Tier 3: Surface ATMS AST retirement (14-file pipeline) | ⬜ | Independent of Path T; can proceed in parallel |
| 1B | Tropical fuel primitive + SRE registration | ⬜ | Follows Phase 1E per revised 2026-04-23 sequence. |
| 1C | Canonical BSP fuel instance migration | ⬜ | A/B bench required |
| 1V | Vision Alignment Gate Phase 1 | ⬜ | |
| 2A | Register S(-1), L2 as stratum handlers (L1 already cell-based per S2.b-iv) | 🔄 | Mini-design + audit 2026-05-19 (§8.7); revised scope: 2 cells, not 3 (cell-ids 13+14); §4.6 framework declarations. Sub-phases below. |
| 2A.0 | Precursor — allocate cell-ids 13+14 in make-prop-network with §4.6 declarations; no behavior change | ✅ | commit `a8ef9e3f` (2026-05-19) — Cell-id 13: retraction-stratum-request (set-union merge); cell-id 14: resolution-stratum-request (list-append merge). Added `make-warm-general-meta` to specialized-cells.rkt (4th §4.6 framework instance; first warm-tier usage). Suite: 8224 tests / 107.3s / 0 failures. Cells dormant pending 2A.a + 2A.b handler wiring. |
| 2A.a | Define `process-retraction` handler; migrate `record-assumption-retraction!` to write cell-id 13; register handler value-tier | ✅ | Mini-design + mini-audit persisted at §8.7.a (2026-05-20). Approach C (refined Option d): pure handler on prop-net (scoped cells only); meta-info + id-map retraction deferred to Parent Phase 4 via worldview-filtering at read time; 6 UNSAFE reader sites migrated to worldview-aware lookups; 4 STUB callbacks retired as dead code (`current-prop-id-map-read/set` + `current-prop-meta-info-read/set`); `record-assumption-retraction` pure function replaces bang version; tests migrated (process-retraction direct + record-assumption-retraction API surface + integration via run-to-quiescence); `retraction-parity` axis added to test-elaboration-parity. **Full suite: 8228 tests / 109.1s / 0 failures.** Adversarial VAG passed. |
| 2A.b | Define `process-resolution` handler; migrate readiness propagators to write cell-id 14 (retiring `current-ready-queue-cell-id`); register handler value-tier | ✅ | Mini-design + mini-audit persisted at §8.7.b (2026-05-20); implementation landed at commit `014944a5`. Option A: handler approach matching 2A.a precedent; box-bridge to elab-net labeled scaffolding (Parent Phase 4 + PM 12 retire). `process-resolution` registered value-tier on cell-14 with `#:reset-value '()`. `add-readiness-set-latch!` (line 443) + `read-ready-queue-actions` (line 2245) rq-cid migrated from parameter read to well-known constant. `current-ready-queue-cell-id` parameter RETIRED at 5 sites (defn + reset + alloc + provide + batch-worker binding). Stale comment at propagator.rkt:703 updated. **Bonus scheduler fix**: empty-pending guard in `process-tier` (propagator.rkt:3077-3090) extended to recognize `null?` empty list — required for list-merge stratum cells to preserve eq? identity in run-to-quiescence (caught by test-readiness-propagator.rkt:469). `test-readiness-propagator.rkt:271` migrated (1 direct param read; 4 indirect calls via `read-ready-queue-actions` continue to work). `resolution-parity` axis added (3 baseline tests + falsification-coverage NOTE pointing to integration test in test-readiness-propagator.rkt:291 + test-trait-resolution.rkt + full suite, since run-ns-last binds empty prelude env making eq-check unbound). **Full suite: 8231 tests / 121.1s / 0 failures** (within 118-127s variance band). Adversarial 3-column VAG passed all 4 questions with honest scaffolding labels. PM Track 13 handler-mechanism concern remains orthogonal (separate track; does not gate). |
| 2A.c | Orchestration parity verification (probe + acceptance + full suite); add orchestration-parity axis to test-elaboration-parity | ✅ | Mini-design persisted at §8.7.c (2026-05-20); implementation landed at commit `2b4bd5a8`. **Empirical falsification of §8.7.4's "S(-1) runs POST-S0" timing concern** — 3 retraction-heavy parity tests pass: `orchestration-union-no-retraction` (Int branch succeeds first), `orchestration-union-with-retraction` (Int fails → retract → String succeeds — THE falsification case), `orchestration-union-flipped-with-retraction` (asymmetry check). All exercise `with-speculative-rollback` at `typing-core.rkt:2385` → `record-assumption-retraction` writes cell-13 → process-retraction fires POST-S0 → restart-from-outer-loop → S0 fires on cleaned state → correct branch succeeds. `(ns t)` bootstrap pattern works in `run-ns-last` harness (D1 risk verified, no fallback needed). **Full suite: 8234 tests / 116.3s / 0 failures** (vs 8231/121.1s pre-2A.c; +3 tests; wall -4.8s within variance). Adversarial 3-column VAG passed all 4 questions. Empirical confirmation that worldview-filtering preserves correctness — S(-1)'s POST-S0 timing produces equivalent results to pre-S0 sequential cleanup. **2A group COMPLETE** — ready for 2B (retire `run-stratified-resolution-pure` orchestrator). |
| 2B | Retire orchestrators (`run-stratified-resolution-pure` + dead `run-stratified-resolution!`) | ✅ | Mini-design + mini-audit persisted at §8.8 (2026-05-20); implementation landed at commit `c24cbae6`. **6 functions retired** (5 design-enumerated + `retry-constraints-for-meta!` surfaced as also dead during audit): run-stratified-resolution-pure, run-stratified-resolution!, execute-resolution-actions!, read-ready-queue-actions, run-retraction-stratum!, retry-constraints-for-meta!. **3 parameters retired**: current-resolution-executor (imperative), current-retracted-assumptions (cell-13 supersedes), current-in-stratified-resolution? (re-entry guard vestigial — D1 verified). solve-meta! simplified 3-branch → 2-branch. **Surfaced + fixed**: test-speculation-bridge.rkt had 2 `run-retraction-stratum!` callsites the §8.8.2 audit missed; migrated to `maybe-flush-network!` (BSP outer-loop driver — same semantic). 5 stale comment-hygiene sites updated. Driver.rkt: deleted init at :467-468 + install at :2705; updated comment at :2624 (re BSP outer-loop progress detection). Test migrations: test-constraint-postponement.rkt:60 migrated to `current-resolution-executor-pure #f`; test-readiness-propagator.rkt retired 2 unit tests for `read-ready-queue-actions` + migrated integration test to direct cell-14 read via test-local `read-resolution-actions-cell` helper. **Full suite: 8232 tests / 109.2s / 0 failures — −11.9s wall vs 2A.b (121.1s) confirming retired wrapper's redundant work was real**. Adversarial 3-column VAG passed all 4 questions with honest scaffolding labels. **First net-deletion sub-phase of addendum Phase 2** — net ~−200 LoC + perf win. Phase 2 charter "one orchestration mechanism" COMPLETE. |
| 2V | Vision Alignment Gate Phase 2 | ✅ | Cross-arc adversarial 3-column VAG persisted at §8.9 (2026-05-20). All 4 questions PASS with honest scaffolding labels across the full 2A.0 → 2A.a → 2A.b → 2A.c → 2B arc. **Cumulative metrics**: +8 tests / −1.7s wall / ~−200 LoC production retired / 6 functions + 3 parameters + 7 provides retired / 2 new BSP stratum cells + handlers / 3 parity axes added. **Charter complete**: BSP outer-loop is sole orchestration for in-form work; ~200 LoC scaffolding retired. **Patterns surfaced** (§8.9.4): adversarial 3-column framing matures across arc; PM 13 spin-off was right call; audit-driven scope expansion is consistent (4 data points — graduation-ready at addendum PIR); first net-deletion phase in addendum; wall delta of −1.7s validates wrapper's overhead approximately equaled new handler overhead. **2 codifications graduation-ready at addendum PIR** (adversarial 3-column + audit-driven scope expansion). **Cross-track captures consolidated** (§8.9.6) for Phase 3 / Phase 4 / PM 12 / PM 13. **Phase 3 readiness gate** ALL PREREQUISITES MET (§8.9.7) — ready to open. |
| Phase 3 mini-design + mini-audit | OQ1-OQ4 resolved via conversational dialogue; outcomes persisted at §9.3.1 | ✅ `d13be339` | **Architectural pivot**: BSP-LE 2/2B Realization B (in-place worldview tagging on shared carrier) over S1 NAF fork-and-rejoin. **OQ1**: non-committing inhabitation semantics — classifier preserved as union after check; multi-success branches coexist via worldview tagging; type-theory unanimous (Castagna semantic subtyping; TypeScript bidirectional; Scala 3 hard unions; Typed Racket occurrence typing). **OQ2**: per-command bit scope; ≤30 bits gate; no reclaim within command. **OQ3**: stratum handler (B3) + B2-broadcast watcher; unification primitives stay PURE (decomplection preserved). **OQ4**: Level 1 (Tarski) — simpler than original §9.7 Level 2. **Cells**: cell-15 (fork-on-union-request), cell-16 (fork-contradiction-request) for 3A.0. **Parity axis**: 'union-narrow-by-constraint renamed → 'union-inhabitation-fork; expectation updated for type-theoretic correctness. |
| 3A | Fork-on-union basic mechanism (in-place tagging per Realization B) | ✅ | **CLOSED 2026-05-22** per §9.3.9 cross-arc VAG. Sub-phases 3A.0 ✅ + 3A.a ✅ + 3A.b ✅ + 3A.c ✅ (cumulative `ba0a2bfd` after 7-commit R7-reframe arc) + 3A.d ✅ (`0e80e120` elab-speculation.rkt retirement) + 3A-VAG ✅ (this commit). Full suite 8232/117.3s/0 failures stable. Union-types via ATMS branching delivered end-to-end. 3 codifications promotion-ready (Stranded high-level abstraction × 3 data points; Multi-axis discriminating coverage × 3 sites; Audit-driven scope refinement × 3 data points). |
| 3A.0 | Allocate fork-on-union stratum-request cells (cell-15 + cell-16) via §4.6 framework; register no-op handler stubs in typing-propagators.rkt; cell-id cascade test fixes (3c-iii precedent) | ✅ `b4d8c22b` |
| 3A.a | Wire `process-fork-on-union` handler body + `make-branch-check-fire-fn` factory; per-position request entries → N aids → worldview-cache init → N branch check propagators installed; new test file `tests/test-union-types-atms.rkt` with 8 tests (unit + E2E with stubbed classifier-watcher) | ✅ `f3597fbb` | Mini-design + mini-audit + implementation persisted at §9.3.3 (2026-05-22). **+~110 LoC typing-propagators.rkt (factory + handler body) + ~245 LoC new test file**. D-3A.a-stratum-tier RESOLVED in implementation (value tier works for stratum handlers — CALM topology guard only active during BSP fire rounds, not between rounds). Per-command aid scope via `current-command-atms` verified (driver.rkt:464 init pattern). Probe semantic diff = 0; full suite **8240 tests / 108.3s / 0 failures** (+8 tests / −1.0s wall vs pre-3A.a). Adversarial 3-column VAG passed all 4 questions. Methodology data point: stratum-handler tests must use `run-to-quiescence` to drive invocation (not direct calls) to avoid double-invocation when followed by BSP iteration. **Next: Phase 3A.b** (B2-broadcast contradiction watcher + `process-fork-contradiction` body — atomic worldview-cache narrowing on aid-set). | Mini-design + mini-audit + implementation persisted at §9.3.2 (2026-05-22). **+~115 LoC production (cells + merges + allocations + stubs) + 5 test fixes (cell-id 14→17 cascade in test-propagator + test-observatory-01 + test-trace-serialize)**. Probe semantic diff = 0; full suite **8232 tests / 109.3s / 0 failures** (identical to pre-3A.0 baseline). Adversarial 3-column VAG passed all 4 questions (on-network, complete, vision-advancing, drift-risks-cleared). D-3A.0-allocation-drift + D-3A.0-handler-no-op-leak + D-3A.0-cell-init-merge-shape all cleared. **Next: Phase 3A.a** (process-fork-on-union body — flatten-union + solver-state-amb + worldview-cache initialization + branch check propagator install). |
| **3A.b mini-design revised (Option E)** | Audit + BSP-LE 2/2B research + mempalace search surfaced `promote-cell-to-tagged` (propagator.rkt:1579) as the missing step. Pattern used at 5 production sites in relations.rkt (NAF, guard, fact-row, multi-clause concurrent). Cell-Based TMS 2026-04-06 design note's original intent confirmed via mempalace. Q1-Q5 user-resolved. | ✅ `44b434ed` | Persisted at §9.3.4. Replaces prior 4-option matrix (A/B/C/D) with **Option E: lazy `promote-cell-to-tagged` at fork-on-union entry**. Updates §9.3.1.2 (Realization B narrative) + §9.3 deliverables (added step 2.5 promote + step 5a helper). Codification graduation (3rd data point) to DEVELOPMENT_LESSONS.org. |
| 3A.b | N fire-once contradiction watchers wrapped per-branch wv + `process-fork-contradiction` body (atomic narrowing via bitwise-AND-with-NOT-mask) + `promote-cell-to-tagged` insertion at fork-on-union entry + `tagged-attribute-map-read-with-base-merge` defensive helper for Phase 9b cross-position reads | ✅ `44b434ed` | Per §9.3.4 (Option E). +~125 LoC production (typing-propagators.rkt) + ~+150 LoC tests (test-union-types-atms +7 unit/E2E + 2 updated 3A.a; test-tagged-cell-value +3 substrate parity). **Methodology refinement**: §9.3.4.6 step 3's "B2-broadcast" framing imprecise; net-add-broadcast-propagator reads inputs ONCE per fire, not per-item — used N fire-once propagators wrapped per branch wv (matches relations.rkt:2487-2510 fact-row pattern, parallel-decomposable). Probe semantic diff = 0; acceptance 0 errors; targeted 141/141; full suite **8251 tests / 117.1s / 0 failures** (vs pre-3A.b 8240 / 108.3s; +11 tests; wall +8.8s within 118-127s variance). Adversarial 3-column VAG passed all 4 questions (persisted at §9.3.4.11). Originally-failing E2E ("Int succeeds + String fails → 1 bit") NOW PASSES. |
| 3A.c | Classifier-watcher integration (β.1 universal install + FP3 cell-17 guard) + test migration. Production retires sexp typing-core.rkt:2385 union check semantically (code-level retirement Parent Phase 4 / PM 12). Multi-axis parity testing (4 active + 1 skip-gated). | ✅ | **CLOSED 2026-05-22** per §9.3.8 cumulative VAG. Final form via R7 reframe (centralized inline-emit at type-map-write API; commit `0e08e08b` R7.a+b + `a4b33fce` R7.c) post-revert + R8 empirical fuel-test (§9.3.6.8). Sub-steps 3A.c.1-3A.c.6 all ✅. Full suite 8255/117.8s/0 failures pre-3A.d. 6 methodology data points captured (§9.3.8.4). |
| 3A.d | Wholly retire `elab-speculation.rkt` (188 LoC) + `tests/test-elab-speculation.rkt` (388 LoC). **Audit finding**: orchestrators have ZERO production callers (stranded after prior refactor; only test-elab-speculation.rkt references them). `elab-speculation-bridge.rkt` + test-speculation-bridge.rkt UNCHANGED (alive via 4 remaining w-s-r callers — Parent Phase 4 / PM 12 scope). Codification candidate: "Stranded high-level abstraction after refactor" → 3rd data point on retirement. | ✅ `0e80e120` | **DONE 2026-05-22**. ~576 LoC retirement (188 prod + 388 test) + 4 secondary references cleaned (propagator.rkt comment + tools/dep-graph.rkt × 2 + bench-scheduler-ab.rkt comment). Full suite **8232 tests / 117.3s / 0 failures** (-23 tests = test-elab-speculation.rkt; -1 file). "Stranded high-level abstraction after refactor" codification now has 3 data points (3A.c.2 helpers + elab-speculation.rkt + R7.c retirement; ready for DEVELOPMENT_LESSONS.org graduation). Adversarial 3-column VAG passed all 4 questions. |
| 3A-VAG | Adversarial 3-column cross-arc VAG for Phase 3A; verify all drift risks D-3A-*; bit-budget measurement gate (≤30 bits per command) | ✅ `9e8a6c3e` | DONE 2026-05-22 per §9.3.9. Cumulative VAG passed all 4 questions adversarially (catalogue / challenge / adversarial × 4). All cross-arc D-3A-* drift risks cleared (fuel-budget via R7; typing-core-2385-residual via empirical grep; bit-budget at 167× headroom; cross-arc mantra via on-network audit; codification-debt noted with promotion candidates). User-facing behavior matrix documented (§9.3.9.2). Handoff to Phase 3B/3C/9b/Parent Phase 4/PM 12/PPN Track 5/Track 4D captured (§9.3.9.5). 3 codifications promotion-ready (§9.3.9.4); graduation deferred to user direction. |
| 3B | Substrate decomplection + hypercube integration (Gray code) — conditional on empirical evidence | ✅ | **CLOSED 2026-05-22** per §9.4.5 cross-arc adversarial 3-column VAG. 3 sub-phases delivered: 3B.0 ✅ (measurement + audit; A/B falsification of Conjecture's CHAMP-sharing under Realization B; Variant B retired); 3B.A ✅ (M0 substrate fix — `#:mutual-exclusion?` flag delivered); 3B.B ✅ documented-defer per §9.4.2.10 (pre-committed falsification outcome). All 6 D-3B-* parent drift risks CLEARED. Original M1 commitment (§9.4.1) REVISED to M0 via audit-driven re-examination (§9.4.2.9). Full suite **8242/111.4s/0** (+10 tests, -5.9s wall vs 8232 baseline). **Methodology output**: 2 PROMOTION-READY codifications reinforced (audit-driven scope refinement — 5 data points; multi-axis parity testing — 5 application sites); 4 promotion candidates from 3B.0; 3 new watching-list candidates from 3B.A. M1+M3 deferred to PPN Track 4D (vision research §5.5). |
| 3B mini-design + mini-audit | Conversational opening of Phase 3B; surfaced OQ1 ↔ mutual-exclusion semantic tension Phase 3A's mini-design missed; explored M0/M1/M3 with adversarial 3-column; M1 selected; sub-phase partition refined; pre-committed falsification criteria locked | ✅ `5df6745a` | Persisted at §9.4.1 per Stage 4 methodology (mini-design + mini-audit outcomes persist to design doc). 11 subsections (§9.4.1.1-§9.4.1.12) covering: audit findings, semantic exploration, architectural decision, sub-phase partition, Phase 3B.0 scope, falsification criteria, drift risks, cross-track captures (5), methodology notes, resolved Q1-Q5, status, cross-references. |
| 3B.0 | Measurement + Audit phase: Pre-0 A/B harness for Gray-code aid ordering empirical question + Stage 2 audit (A1-A6) for M1 substrate decomplection design. 5 workloads (W1-W5), 5 metric tiers, pre-committed falsification criteria. | ✅ | **CLOSED 2026-05-22** per §9.4.2.11 cross-arc VAG. 5 commits: mini-design opening (`483957ba`) → A1-A6 audit (`8ca0a1a4`) → Option 3 confirmed M0 (`f2e948b5`) → harness + Variant B (`98cbbc3d`) → measurement + Variant B retirement + VAG close (`0eaa9506`). **Key outcomes**: (1) OQ1↔mutual-exclusion semantic tension surfaced + M0 selected (audit-driven re-examination of §9.4.1's M1 commitment); (2) A/B measurement falsified Hyperlattice CHAMP-sharing under Realization B (all deltas within ±1.5%); (3) Variant B scaffolding retired honestly per pre-committed Q8; (4) M1+M3 substrate decomplection captured at Track 4D vision §5.5. 4 codifications promotion-ready (rigorous-audit-refutes-framing, multi-consumer-symmetry, pre-committed-falsification, mechanism-coupled-claims). |
| 3B.A | **M0 substrate fix** — `#:mutual-exclusion?` flag on `solver-amb` (default `#t` preserves classical); `solver-state-amb` threads flag with conditional amb-groups append (Q2(b)); `process-fork-on-union` (typing-propagators.rkt:1139) migrates to `(solver-state-amb ss alternatives #:mutual-exclusion? #f)`. **REVISED from M1 per §9.4.2.9** (audit-driven re-examination 2026-05-22). | ✅ | **CLOSED 2026-05-22** per §9.4.4 cross-arc VAG. 5 substantive commits: mini-design (`37da04b7`) → code migration (`a14557db`) → M0 doc (`8c526a1a`) → 4 discriminating axes (`42720386`) → close VAG (this). Net production ~+39 LoC; net docs ~+260 LoC; net tests +111 LoC / +5 cases (4 axes; axis 4 split). Full suite **8242 / 111.4s / 0 failures** (+10 tests, -5.9s wall vs 8232 baseline). 5/5 D-3B.A-* drift risks cleared. 5 methodology data points captured (2 reinforce promotion-ready codifications; 3 new watching-list candidates). M0 architectural commitment in source code AND design doc; multi-consumer survey (5 non-committing consumers) inherit for free; M1+M3 deferred to Track 4D per §5.5. |
| 3B.A mini-design + mini-audit | Conversational opening of Phase 3B.A post-3B.0 close; A1-A6 mini-audit verified §9.4.2.9.4 scope + verified A4 inertness claim at deeper level; surfaced Q2 (amb-groups append conditional behavior); 5 Q-decisions resolved | ✅ | Persisted at §9.4.3 per Stage 4 methodology. 7 subsections (§9.4.3.1-§9.4.3.7) covering: audit findings, resolved Q1-Q5, sub-step partition, drift risks, closure criteria, status, cross-references. |
| 3B.B | Hypercube integration (Gray-code aid ordering) — **DOCUMENTED-DEFER** per 3B.0 falsification (§9.4.2.10) | ✅ (defer) | **DECIDED 2026-05-22**: A/B measurement (n=10 × 5 workloads × 2 variants) showed ALL DELTAS WITHIN ±1.5% (W1 -0.2% / W2 -0.6% / W3 -1.0% / W4 +0.4% / W5 -0.6%); IQRs tight (~1-2% of median). Per pre-committed §9.4.1.6 criteria, ±5% on W4/W5 → DOCUMENTED-DEFER. Falsification narrow: Conjecture's CHAMP-sharing claim does NOT transfer to Realization B's in-place tagging; does NOT refute the Conjecture broadly. Future consumers (Phase 9b under fork-and-rejoin, PReduce, BSP-LE 6) need separate per-mechanism A/B tests. Variant B scaffolding retired per pre-committed Q8 (§9.4.2.10.5). |
| 3B-VAG | Adversarial 3-column cross-arc VAG; verify all D-3B-* drift risks cleared (D-3B-shape-without-benefit, fork-vs-Realization-B-confusion, orphan-primitive-keepalive, scheduler-coupled-optimization, subcube-without-consumer, measurement-confound-inert-nogoods) | ✅ | **CLOSED at §9.4.5** (this commit). All 6 D-3B-* parent drift risks verified cleared adversarially. 4 VAG questions × 3 columns (catalogue + challenge + adversarial) all pass. Methodology pattern reusability NEW codification candidate (1 data point — 3B.0 + 3B.A applied IDENTICAL process shape with different content). 3B parent row → ✅. |
| 3C mini-design + mini-audit | Conversational opening of Phase 3C; 12-task tier-organized audit (A1-A11 + synthesis A12) + Q6.x empirical probe + 10 Q-decisions resolved (Q1-Q10) + 13 D-3C-* drift risks named (D-3C-10 CLEARED pre-implementation) + Propagator-First Diagnostics vision-forward framing (watching-list codification, graduates at Phase 11b second consumer) + cross-track captures (Phase 11b / SH Master Track 1+4 / PPN 8 LSP / PReduce 6 / sexp-as-IR retirement multi-track arc) | ✅ `ef8196d3` | Persisted at §9.5.1 per Stage 4 methodology. 11 subsections (§9.5.1.1-§9.5.1.11) covering: audit findings, Q6.x empirical reframe, Propagator-First Diagnostics framing, resolved Q1-Q10, sub-phase partition (3C.a/.b/.c/.d + 3C-VAG), drift risks, cross-track captures, methodology notes (6th data point for audit-driven scope refinement + empirical-falsification sub-codification), closure criteria, status, cross-references. Probe artifact at `examples/2026-05-22-3C-Q6x-probe.prologos` (committed concurrently). |
| 3C | Residuation error-explanation | 🔄 | **Mini-design persisted at §9.5.1.** Phase 3C ships UC3-flavored union-type consumer + reusable `static-reverse-walk` primitive (exported per vision-forward Propagator-First Diagnostics framing); populates the EMPTY `union-exhaustion-error.derivation-chain` field (Q6.x finding: chain field exists but is empty today) for BOTH annotated-union (sexp check/err path) AND inferred-union (on-network process-fork-contradiction path) scenarios. UC1 + UC2 deferred to OE Track 4 / Phase 11b. Sub-phases: 3C.a ✅ → 3C.b (union-contradict consumer) → 3C.c (union-check consumer) → 3C.d (format + parity) → 3C-VAG. Est. ~430-700 LoC total. |
| 3C.a mini-design + mini-audit | Opening 3C.a foundation; Q-A.1-7 + 8 test cases + 5 D-3C.a-* drift risks; LOCKED leans per dialogue + §9.5.2 persistence | ✅ `1d803ed2` | Persisted at §9.5.2 per Stage 4 mini-audit-precedes-implementation discipline. 7 subsections covering mini-audit findings, Q-A.* locked leans (3-column adversarial), test plan, drift risks, deliverables, closure criteria, status. |
| 3C.a — Foundation (`error-explanation.rkt` + 8 tests) | NEW module + structs + `static-reverse-walk` primitive + 8 test cases T1-T8 + smoke test | ✅ `1d803ed2` | error-explanation.rkt (156 LoC): `derivation-chain` + `derivation-step` structs (transparent; LSP-ready) + `static-reverse-walk net cell-id #:max-depth 32 #:filter-fn pred → derivation-chain` primitive. Single-layer decorated walk; cycle detection (visited prop-id set); DFS pre-order cons-onto-head produces causal-reading order (deepest cause first). Decomplection: primitive sets assumption-names='() + residual-cost=#f; 3C.b/c consumers enrich. Preserves Cell/Propagator/Scheduler Orthogonality (no observer-set; static walk only). test-error-explanation.rkt (~165 LoC): 9 tests all PASS. **Full suite 8251/98.8s/0 failures** (+9 tests vs baseline 8242/111.4s). All 5 D-3C.a-* drift risks cleared. Ready for 3C.b mini-design. |
| 3C.b mini-design + mini-audit | Opening 3C.b union-contradict consumer; Q-B.1-5 + 6 D-3C.b-* drift risks; user-articulated coupling intuition during dialogue refined option (c) handler-side detection → **option (d) per-fork threshold propagator + per-position monotone latch cell** (set-latch + threshold canonical pattern); cascading simplification: Q-B.1.iii (idempotence) STRUCTURALLY SUBSUMED by fire-once propagator (emitted-chains tracker cell ELIMINATED); Q-B.1.ii γ phase-boundary restructure (3C.b builds + STORES chain on-network at cell-19; 3C.c bridges from check/err to consume); Q-B.2 β field type change to `(listof derivation-chain)`; 5 axis tests including 2 negative (no-error-no-chain + multi-success-no-chain) | ✅ (this commit) | Persisted at §9.5.3 per Stage 4 mini-audit-precedes-implementation discipline. 8 subsections covering 7-tier mini-audit, Q-B.1-5 locked leans (3-column adversarial), refined option (d) architecture, sub-step partition (3C.b.1/.2/.3/.4/.5 + 3C.b-VAG), 6 drift risks, cross-track captures, closure criteria, status. Honest scope-up to ~275-425 LoC noted in §9.5.3.4 (vs original 80-150 estimate). |
| 3C.b.1 — Cell allocations | New cell-18 (`contradicted-branch-aids-cell-id`, monotone hash-of-sets, hash-union with set-union merge, Tier 2 'monotone-set) + cell-19 (`union-derivation-chains-cell-id`, hash-union new-wins merge, Tier 2 'hasheq-replace); allocation + drift checks at make-prop-network; 8 hardcoded cell-count test assertions updated across 3 test files (test-propagator + test-trace-serialize + test-observatory-01); design doc cell-20→cell-19 numbering correction folded in (sketching gap; actual next-available is cell-19) | ✅ `c160fbc7` | 165 lines added across propagator.rkt + 3 test files + design doc. Cells INERT until 3C.b.2 wires watcher fan-out + 3C.b.4 installs threshold propagator. **Full suite 8251/106.7s/0 failures** (within 109-115s variance band). All 3 D-3C.b-* risks for this sub-step cleared (cell-id drift via drift checks; test assertion drift via 8 updates; D-3C.b-2 per-position branch-mask gap closed by cell-18). No tests: infrastructure-only; drift checks ARE the behavioral assertion. |
| 3C.b.2 — Watcher fan-out | Modify `make-branch-contradiction-watcher-fire-fn` (typing-propagators.rkt:1248) to fan-out write: BOTH cell-16 ((seteq aid) — UNCHANGED 3A.b semantic) AND cell-18 ((hasheq position (seteq aid)) — NEW 3C.b.2 persistent latch entry); 3 new test cases (extended fan-out + extended no-emit + 2 new tests for set-union per-position + hash-union across positions) | ✅ `c51b08e4` | 127 insertions / 7 deletions across typing-propagators.rkt + test-union-types-atms.rkt. Existing handlers stay SINGLE-CONCERN. Both cell writes monotone + CALM-safe. **Full suite 8253/107.6s/0 failures** (+2 fan-out tests; within 109-115s variance band). D-3C.b-6 codification candidate (watcher fan-out coupling pattern) documented in fire-fn comment; pattern bounded to 2-cell minimum (future readers install separate propagators reading cell-16). Cell-18 now ACTIVELY POPULATED. |
| 3C.b.3 — Wrapper + enrichment | Build `derivation-chain-for/union-contradict net branch-aid-set request-info → derivation-chain` in error-explanation.rkt (exported); wraps `static-reverse-walk` with filter-fn closing over aid-set normalized to integer aid-ns (D-3C.b-7 fix); enriches steps with `assumption-names` via `solver-state-assumptions` lookup (D-3C.b-1 mitigation: prefers string datum over symbol name); 5 new test cases (T-B.1 enrichment + T-B.2 fallback + T-B.3 filter + T-B.4 defensive missing tm-cid + T-B.5 graceful no-ATMS) | ✅ `94647535` | 326 insertions / 5 deletions across error-explanation.rkt + test-error-explanation.rkt. D-3C.b-1 verified at impl: `solver-amb` (atms.rkt:397+403) stores synthetic `'h0`/`'h1` symbols in name field + label STRING in datum field → wrapper prefers datum-string. NEW D-3C.b-7 discovered at impl: aid identity is integer `assumption-id-n`, not struct identity; `seteq` membership fails between fresh decoded aids and canonical originals; fixed via integer-keyed normalization at wrapper boundary. **Full suite 8258/106.9s/0 failures** (+5 wrapper tests; within 109-115s variance band). |
| 3C.b.4 — Threshold propagator install | At process-fork-on-union step 4.5 (between watcher install and cell-17 guard write), install per-fork threshold propagator via PLAIN net-add-propagator (NOT fire-once — fire-once would self-clean before predicate met across multiple-round contradictions); reads cell-18; closes over (position, branch-aid-set, request-info); on subset met, builds chain via 3C.b.3 wrapper + writes cell-19. NEW factory exported `make-fork-chain-threshold-fire-fn`. 3 new threshold unit tests + 1 existing propagator-count assertion updated (4 → 5) | ✅ `e8cbf0e1` | 232 insertions / 5 deletions across typing-propagators.rkt + test-union-types-atms.rkt. **Critical design**: fire-once vs plain — chosen plain because threshold CONDITION may not be met on first cell-18 change (multi-round contradiction accumulation); Q-B.1.iii idempotence preserved via structural cell-18 stability (watchers all fire-once) + defensive cell-19 emit-once guard. NEW codification candidate (1 data point): "fire-once semantic gotcha when predicate not met on first invocation." **Full suite 8261/106.0s/0 failures** (+3 threshold tests; within 109-115s variance band). The Propagator-First Diagnostics architecture is now COMPLETE end-to-end on-network through 3C.b. |
| 3C.b.5 mini-design + mini-audit | Opening 3C.b.5 sub-step (closing the 3C.b implementation arc); Q-C.b.5.1-5 LOCKED via 3-column adversarial (B net-access via `process-string/return-net`; (a) test-elaboration-parity.rkt new section; (iv) retire `/idempotent` axis — structurally guaranteed across 3 layers; (a) Q6.x probe re-run as documentation artifact; 4 axes confirmed); 5 D-3C.b.5-* drift risks named; sub-step partition revised to 3C.b.5.a (mini-design)/.b (net-access)/.c (4 axes)/.d (probe)/-close | ✅ `2c6e8d3d` | Persisted at §9.5.3.9 per Stage 4 mini-audit-precedes-implementation discipline. 7-tier mini-audit (parity infra / run-ns-last / process-string + net access / error-explanation exports / cell-18/19 wiring / Q6.x dispatch / cell-read test patterns) grounded design in code reality. Honest scope-up: ~110-150 LoC total (was 80-120) due to net-access infra (~30-50 LoC `process-string/return-net`). |
| 3C.b.5.b — `process-string/return-net` | NEW public function in driver.rkt: `: string → (values results net)`. Mirrors process-string body; captures the parameterized `current-prop-net-box` via `let` before parameterize body exit (so caller sees the elaborated network). Update provides list. No dedicated smoke per Q-C.b.5.1 lean γ — 3C.b.5.c axes will exercise extensively. | ✅ `051483e8` | +49 LoC in driver.rkt. Returns `elab-network?` (NOT `prop-network?`); caller uses `elab-cell-read` for cell access. Located adjacent to `process-string` per D-3C.b.5.b-1 mitigation. Functional smoke verified via direct invocation. Targeted suite (test-elaboration-parity + test-union-types-atms + test-error-explanation) 64 tests / 5.0s / PASS — no regression. |
| **3C.b.5.c-bugfix** — Watcher output declaration | **CRITICAL BUGFIX** surfaced by 3C.b.5.c empirical probe. typing-propagators.rkt:1213 watcher install — cell-18 added to outputs list (was previously only cell-16). Pre-bugfix: cell-18 writes hit undeclared-writes bypass-merge path (propagator.rkt:2848-2871 + :2971-2989) → silent last-write-wins → cell-18 only accumulated ONE branch's aid → threshold subset check never held → cell-19 chain never written end-to-end. The mechanism shipped at 3C.b.4 was structurally broken; T-C.b.4 unit tests masked the gap by manually populating cell-18. | ✅ `bc47e0d6` | +28 LoC documentation + 1 LoC semantic change. Direct probe post-fix: cell-18 accumulates both aids; cell-19 populated with 2-step derivation-chain; assumption-names include "branch-N-at-..." substring. 21 existing test-union-types-atms tests PASS — no regression. Diagnosed via diagnostic protocol (workflow.md): printf trace + reading net-cell-write + reading fire-and-collect-writes + reading bulk-merge-writes. NEW codification candidate (1 data point): "Watchers writing beyond declared outputs hit undeclared-writes bypass-merge — silent last-write-wins. ALL cells a propagator writes to must be in outputs list when merge functions are load-bearing." Promote at 2nd data point. |
| 3C.b.5.c — 4 axes in test-union-types-atms.rkt (PIVOT post-empirical) | PIVOT from Q-C.b.5.2 lean (a) to (b) per D-3C.b.5-6 empirical falsification: sexp annotated `def : T := value` goes through sexp `check/err` path, NOT Phase 3A. 4 axes use synthetic E2E pattern (mirror test-union-types-atms.rkt:585-662): make-test-fixture + current-command-atms parameterize + write-classify-inhabit + direct cell-15 write + run-to-quiescence + cell-19 read. Axes: `/int-bool-both-fail` (positive); `/nat-string-both-fail` (positive variety); `/int-string-int-succeeds` (negative partial); `/nat-int-both-succeed` (negative full). | ✅ `9b93ab2d` | +139 LoC across test-union-types-atms.rkt (+ racket/string require). 4 axes PASS post-bugfix. Targeted suite (6 files: test-union-types-atms + test-elaboration-parity + test-error-explanation + test-propagator + test-trace-serialize + test-observatory-01) → 132 tests / 6.1s / PASS — no regression. Distinct coverage from T-C.b.4 unit tests (which test threshold body in isolation via manually-populated cell-18): these axes test the COMPOSITION (watcher fan-out + cell-18 accumulation + threshold + wrapper + cell-19). |
| 3C.b.5.d — Q6.x probe re-run | Re-ran `examples/2026-05-22-3C-Q6x-probe.prologos` via process-file post-3C.b. Saved artifact to `data/probes/2026-05-22-3C-Q6x-post-3Cb.txt` (27 lines). §9.5.3.9.6 closed with empirical interpretation. | ✅ `0ccd248e` | Probe confirms `prop_allocs=0`, `prop_firings=0`, `CELL-METRICS: cells=42, propagators=0` for 3 WS-mode scenarios — Phase 3A does NOT fire for WS-mode. `union-exhaustion-error.derivation-chain = '(() ())` / `'(() () ())` — empty from sexp check/err path. **EVIDENCE for 3C.c sexp-bridge necessity** confirmed empirically; D-3C.b.5-6 deployment gap confirmed. |
| **3C.b.5-close** | Full suite regression gate + §3 tracker backfill + dailies close session entry | ✅ (this commit) | **Full suite: 8265 tests / 106.1s / 0 failures** (+4 tests vs pre-3C.b.5 baseline 8261/106.0s; within 109-115s variance band; all 422 test files PASS). All 5 D-3C.b.5-* + 1 NEW D-3C.b.5-7 (bugfix-class) drift risks cleared. 3C.b.5 sub-step partition COMPLETE: 3C.b.5.a (mini-design) + 3C.b.5.b (process-string/return-net) + 3C.b.5.c-bugfix (cell-18 output) + 3C.b.5.c (4 axes) + 3C.b.5.d (probe). Ready for 3C.b-VAG cumulative cross-sub-step close. |
| **3C.b-VAG** | Cumulative cross-sub-step adversarial 3-column VAG (per CRITIQUE_METHODOLOGY.org). 4 VAG questions × catalogue/challenge/adversarial; 6 D-3C.b-* + 7 D-3C.b.5-* drift risks verified cleared. | ✅ (this commit) | See §9.5.3.10 for the cumulative VAG application. **Phase 3C.b CLOSED end-to-end** — substrate + watcher fan-out + threshold + wrapper + chain storage + 4 E2E axes + Q6.x probe artifact + bugfix all delivered. Ready for Phase 3C.c (sexp-bridge → union-exhaustion-error.derivation-chain). |
| **3C.c.0 mini-design + mini-audit** | Opening 3C.c sexp-bridge consumer; LHC vision reframing per user direction 2026-05-24 (cell-19 authoritative store; sexp `check/err` as temporary writer with Track 4D retirement target); 7-tier mini-audit grounded in code; Q-C.1-6 LOCKED via 3-column adversarial; NEW Q-C.6 finding (cell-19 ↔ field shape consistency) — minimal 3C.b adjustment honest correction of missed-audit; 9 D-3C.c-* drift risks named; §9.5.4.7 expected error message verbatim baseline. | ✅ `c5678e29` | Persisted at §9.5.4 per Stage 4 mini-audit-precedes-implementation discipline. 12 subsections (mini-audit / vision framing / Q-C.6 new finding / Q-C.1-6 locked leans / implementation sketch / sub-phase partition / drift risks / acceptance criterion / closure criteria / cross-track captures / status / cross-references). Honest scope-up to ~270 LoC noted in §9.5.4.6 (vs original 80-150 estimate from §9.5.1.5) due to (a) per-branch-split 3C.b adjustment, (b) format-error update with ATMS state queries, (c) test site co-migration. |
| **3C.c.1** | `derivation-chain-for/union-check` translator in error-explanation.rkt — sexp-mode translator PARALLEL TO RETIRED build-derivation-chain (per §9.5.4.5.1 lean α — takes sub-failures list, NOT branch failure); flattens DFS pre-order across speculation-failure forest; translates to derivation-step (propagator-id=#f, srcloc=#f, aids from speculation-failure-hypothesis-id, names via decode-aid-name with label fallback, residual-cost=#f); 6 new tests T-C.c-1.1a/b through T-C.c-1.6 | ✅ `6d281d20` | +251 LoC across error-explanation.rkt + test-error-explanation.rkt. NO new module-load deps: elab-speculation-bridge.rkt was already required by error-explanation.rkt for current-command-atms (3C.b.3); speculation-failure accessors already provided via struct-out. Targeted suite test-error-explanation.rkt: 21 tests / 3.3s / PASS (was 15 pre-3C.c.1; +6 new; no regressions). Parens balance GREEN. D-3C.c-1 ACTIVE (srcloc=#f documented). D-3C.c-10 RESOLVED via (α) sub-failures lean — atomic-case empty chain asserted by T-C.c-1.1a/b. |
| **3C.c.2** | 3C.b per-branch-split adjustment — `make-fork-chain-threshold-fire-fn` (typing-propagators.rkt:1346) replaces single-chain write with per-branch iterative wrapper call; cell-19 value shape flips to `position → (listof derivation-chain)` per Q-C.6 (a) lean; 3C.b 4-axis tests (test-union-types-atms.rkt:724-799) updated to assert `(listof derivation-chain)` shape | ⬜ | ~10-15 LoC + test updates est. Honest correction of missed-audit point at 3C.b VAG; small adjustment to existing closed-phase code. |
| **3C.c.3** | check/err integration in typing-errors.rkt:64-118 — replace union path (lines 70-104) chain construction with `derivation-chain-for/union-check` per-branch; write cell-19 via `net-cell-write` on (current-prop-net-box) elab-network; flip `union-exhaustion-error.derivation-chain` field type atomically; retire `build-derivation-chain` union-type code path (Q9 mandate); non-union path unchanged for type-mismatch-error (Phase 11b scope) | ⬜ | ~50 LoC est. Field type flip atomic with 3C.c.4 format-error update — no broken intermediate state. |
| **3C.c.4** | format-error update in errors.rkt:267-287 — union-exhaustion-error case handles `derivation-chain` struct (not strings); ATMS conflict info via `solver-state-explain-hypothesis` queried at RENDER TIME (decomplection per §9.5.4.4 adversarial); minimal diagnoses via `solver-state-minimal-diagnoses` queried at render time; preserves today's diagnostic richness | ⬜ | ~30-50 LoC est. User-facing message MUST match §9.5.4.7 verbatim acceptance criterion. |
| **3C.c.5** | Test site updates — ~10 sites across test-provenance-errors.rkt (7 sites), test-speculation-bridge.rkt (assertions on branches/branch-mismatches unchanged), test-gde-errors.rkt (2 sites); all assertions updated to check `derivation-chain?` structure instead of list-of-string | ⬜ | ~50 LoC est. Grep at impl catches all consumers via `union-exhaustion-error-derivation-chain` accessor pattern. |
| **3C.c.6** | E2E acceptance criterion verification — (a) atomic Q6.x probe re-run: rendered output IDENTICAL to pre-3C.c per §9.5.4.7.1 byte-for-byte; (b) NEW nested-scenario probe for richness validation per §9.5.4.7.2 (exact scenario selected at 3C.c.6 mini-design open via exploratory probe); (c) structural assertions on cell-19 written + field type flipped. Per §9.5.4.5.1 audit discovery: atomic chain stays empty (matches retired build-derivation-chain semantic); nested chain demonstrates richness path. Save artifacts to `data/probes/2026-05-24-3C-Q6x-post-3Cc.txt` (atomic) + `data/probes/2026-05-24-3C-Q6x-post-3Cc-nested.txt` (nested baseline). | ⬜ | ~30 LoC + 2 probe artifacts est. Full suite gate: stable within 109-115s variance band. |
| **3C.c-VAG** | Cumulative cross-sub-step adversarial 3-column VAG (4 questions × catalogue/challenge/adversarial); all 9 D-3C.c-* drift risks verified cleared; Q-C.6 (NEW finding) outcome verified; multi-writer scaffolding documented + retirement target named (Track 4D) | ⬜ | Phase 3C.c CLOSED gate. Ready for Phase 3C.d (format integration + 4-axis discriminating parity tests) per §9.5.1.5. |
| 3V | Vision Alignment Gate Phase 3 | ⬜ | Per §9.6 revised. Conditional on 3A ✅ + 3B-VAG ✅ + 3C close. |
| **4** | **Top-level orchestration unification — retire `process-command` sequential loop** | ⬜ | Designed at phase open per addendum methodology. Tracking [#22](https://github.com/LogosLang/prologos/issues/22). Motivating use case: mutual recursion ([PR #14](https://github.com/LogosLang/prologos/pull/14)). Gates on Phase 1 (tropical fuel) + Phase 2 (in-form strata) close. Sub-phases (4A, 4B, 4V) populated at phase open. |
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

Per NTT §7 (Level 5: Stratification) — `stratification` with `:fiber` forms.

**Revised 2026-05-19 per Phase 2A mini-design + mini-audit (§8.7)**: handler count is 8, not 9. L1 readiness is already structurally emergent post-S2.b-iv (readiness propagators write to `ready-queue` cell during S0 BSP rounds); no L1 stratum handler needed. Phase 2A adds 2 handlers (S(-1) retraction + L2 resolution), not 3.

```ntt
;; 8 registered stratum handlers post-Phase-2 (was 6 pre-Phase-2; +2 from Phase 2A)

stratum-handlers := [
  ;; Topology tier (4, unchanged)
  (constraint-propagators-topology-cell-id  :tier 'topology)
  (elaborator-topology-cell-id              :tier 'topology)
  (narrowing-topology-cell-id               :tier 'topology)
  (sre-topology-cell-id                     :tier 'topology)

  ;; Value tier (4, +2 from Phase 2A)
  (retraction-stratum-request-cell-id       :tier 'value)   ;; NEW Phase 2A; cell-id 13
  (resolution-stratum-request-cell-id       :tier 'value)   ;; NEW Phase 2A; cell-id 14
  (naf-pending-cell-id                      :tier 'value)
  (classify-inhabit-request-cell-id         :tier 'value)
]

;; Registration order (= iteration order within tier; module-load determined):
;;   metavar-store.rkt loads BEFORE relations.rkt (driver.rkt lines 37 + 45)
;;   → S(-1) retraction + L2 resolution register first (value-tier)
;;   → S1 NAF (relations.rkt) registers after
;;   → classify-inhabit-request (typing-propagators.rkt) registers after relations.rkt

;; §4.6 framework declarations for NEW cells (Phase 2A):
cell retraction-stratum-request
  :tier 'warm
  :storage 'general
  :fires-on 'any-change
  :merge-fn merge-set-union   ;; cached on specialized-cell-meta
  :reset-value (set)

cell resolution-stratum-request
  :tier 'warm
  :storage 'general
  :fires-on 'any-change
  :merge-fn merge-list-append   ;; cached on specialized-cell-meta
  :reset-value '()

;; BSP scheduler's outer loop iterates all handlers per tier
;; Retired by Phase 2B: run-stratified-resolution-pure (sequential orchestrator)
;; Retired by Phase 2B: run-stratified-resolution! (dead code)
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

#### §7.5.14.1 Per-domain off-network parameter retirements (EXPANDED 2026-04-25 from S2.d-followup audit)

Surfaced originally by S2.c-iii mini-audit (§7.5.13.6.1 Surprise #5) for session; expanded 2026-04-25 to cover all 3 non-type domains uniformly. The session/mult/level domains accumulated parallel PM-8F-era off-network state patterns:

**Per-domain meta-store parameters** (Racket parameters holding `(make-hasheq)` — off-network):
- **`current-sess-meta-store`** (`metavar-store.rkt:2693`)
- **`current-mult-meta-store`** (`metavar-store.rkt:2562`)
- **`current-level-meta-store`** (`metavar-store.rkt:2465`)

**Per-domain CHAMP-box parameters** (Racket parameters holding box of CHAMP for status tracking):
- **`current-sess-meta-champ-box`**
- **`current-mult-meta-champ-box`**
- **`current-level-meta-champ-box`**
- (parallel to type's `current-prop-meta-info-box`)

**Per-domain factory callbacks** (Racket parameters holding fresh-cell allocation closures for legacy fallback path):
- **`current-prop-fresh-mult-cell`** (per §7.5.14.3)
- **`current-prop-fresh-level-cell`** (parallel — used in fresh-level-meta legacy fallback)
- **`current-prop-fresh-sess-cell`** (parallel — used in fresh-sess-meta legacy fallback)

**Per-domain write callbacks** (similar pattern; mult only, since level/session use direct `elab-cell-write`):
- **`current-prop-mult-cell-write`** (per §7.5.14.3)

**S2.e retirement plan**: when all 4 domains are universe-migrated (post-S2.d, complete) and the universe is the authoritative store, the meta-store + CHAMP-box parameters become unused (their `'champ-fallback` entries in `meta-domain-info` are no longer consulted because `'universe-active? = #t` for all 4 domains). Retire all 6 per-domain stores + 3 fresh-cell callbacks + 1 write callback together with the per-cell factory retirement. Net: 10 off-network parameters retired in S2.e.

Mantra check post-retirement: ✓ on-network (universe cells), ✓ structurally emergent (dispatch via meta-domain-info table), ✓ info flow through cells (compound-cell-component-{ref,write}).

**PM Track 12 cross-reference**: these 10 parameters are tracked in DEFERRED.md PM 12 section (per "per-track registry tracking" pattern) — PM 12's submodule-scope primitive provides the natural retirement target for the underlying registry semantics.

#### §7.5.14.2 Session-domain dual-surface retirement

The `sess-meta-solution/cell-id` (PM 8F-style fast path with `sess-meta.cell-id` cache field) becomes redundant under option 4 dispatch:

- Both `sess-meta-solution` and `sess-meta-solution/cell-id` shims delegate to `meta-domain-solution 'session id` (as designed in S2.c-iii)
- The cell-id arg is accepted for backward-compat but doesn't change dispatch (parameter-read wins)
- The 2 internal-only callers in metavar-store.rkt (zonk-session at :2729, zonk-session-default at :2749) currently pass `(sess-meta-cell-id s)` → after Phase 4's `sess-meta.cell-id` field retirement, they stop passing it → only `sess-meta-solution` remains

**S2.e retirement plan** (post-Phase-4): once `sess-meta.cell-id` field is deleted, retire `sess-meta-solution/cell-id` shim entirely. Single-surface contraction matches the option-4 mantra-aligned shape; the dual surface was scaffolding tracking PM 8F's cache-field optimization.

#### §7.5.14.3 Mult-domain post-migration cleanup (added 2026-04-24 from S2.c-iv adversarial VAG)

Surfaced by S2.c-iv adversarial VAG (per the new methodology codified at commit `9f7c0b82`). Two minor cleanup opportunities found by challenging the "vision-advancing" question:

- **`elab-add-type-mult-bridge` is test-only post-S2.c-iv**: production code uses the `current-structural-mult-bridge` callback at driver.rkt:2658. Only `test-mult-propagator.rkt:124` still calls `elab-add-type-mult-bridge` directly. Two surfaces for the same operation. **S2.e retirement plan**: migrate test-mult-propagator.rkt to use the same bridge install path as production (or retire the test if S2.c-iv's mult bridge regression coverage in test-mult-inference.rkt + test-tycon.rkt is sufficient). Then retire `elab-add-type-mult-bridge` definition + provide.

- **Off-network parameter scaffolding for pre-init paths**: `current-prop-fresh-mult-cell` (driver.rkt:2600 → elab-fresh-mult-cell) and `current-prop-mult-cell-write` (driver.rkt:2605 → elab-mult-cell-write) are Racket parameters holding callbacks. Used in fresh-mult-meta + solve-mult-meta! legacy paths for pre-init test contexts. PM Track 12 retires when test fixture infrastructure goes on-network. **S2.e retirement plan**: review whether pre-init contexts still need these callbacks under PM 12 readiness, or if the legacy paths can collapse entirely (test infrastructure migrates to call init-meta-universes! at setup).

**S2.c-iv methodology lesson**: adversarial VAG with two-column discipline surfaced these refactor-preservation drifts that the catalogue framing would have missed. Both are MINOR (test-only surfaces + known scaffolding with retirement plan) — not blocking S2.c-iv close, but worth capturing for future cleanup. The methodology IS catching drift; the gate is working.

#### §7.5.14.4 Per-command transient cell consolidation — NEW finding for future track scope (added 2026-04-25 from S2.e measurement)

**Finding**: Step 2's universe consolidation addressed PERSISTENT meta cells (4 universes per the meta-domain-info architecture). However, S2.e measurement revealed that the persistent-cell delta is ~+4 (50→54 in the probe), while `cell_allocs` (cumulative `net-new-cell` calls) is +110 (1071→1181). The `cell_allocs` counter only tracks `net-new-cell` invocations — NOT cell-version-updates from `net-cell-write`. So the +110 increment is from new cells being created, not more writes to existing cells.

**Where the +110 cells go**: PER-COMMAND TRANSIENT ELABORATION. Each top-level command (~28 in the probe) allocates ~30-50 cells during elaboration (attribute-record cells per AST position, SRE structural decomposition sub-cells from `decompose-pi`, per-command spec/FormCell instances, typing-propagator scratch cells). These cells are created in the persistent network but are functionally per-command — their lifetime is bounded by command processing.

**Per-command breakdown** (from probe verbose 2026-04-25, post-S2.d):
| Command | cell_allocs (delta) | What it represents |
|---|---|---|
| `def p1-x := 42` (cmd 0) | 37 | Simple literal def → still 37 cells of attribute-record + structural decomposition |
| `defn p1-inc [n] [int+ n 1]` (cmd 6) | 35 | Function def with type sig |
| `def p5-list := '[1 2 3 4 5]` (cmd 18) | 47 | List with 5 cons calls — multiple meta creations |
| `defn p6-id {A : Type} A -> A` (cmd 24) | 51 | Polymorphic function → more sub-cells |

Even simple commands allocate 30-50 cells. The probe's 28 commands × ~40 avg = ~1100 transient allocations dominating the cell_allocs metric.

**Architectural insight**: Step 2's PU consolidation pattern (4 universe cells for N metas) APPLIES to other repeated allocation sites. The per-command attribute-record allocation, SRE Pi/Sigma decomposition sub-cells, and spec registration all fit the "many per-N-X cells consolidate to compound PU" pattern. Each is a candidate for further PU consolidation.

**Why this isn't S2.e scope**: S2.e's charter is META universe completion (Step 2 close). Per-command transient consolidation is a SEPARATE optimization concern affecting elaboration substrate broadly, not just meta storage. It belongs to a future track — most naturally Track 4D (Attribute Grammar Substrate Unification) since 4D's thesis IS substrate unification across typing/elaboration/reduction.

**Why this IS captured now (vs deferred informally)**: per the capture-gap pattern (S2.d-followup lesson + this session reinforcement), naming a future phase without verifying capture means the work gets missed. This subsection ensures the finding is anchored in:
1. D.3 (this section) — track-internal scope notes; survives S2 close
2. Track 4D research vision — forward-pointer to the natural conceptual home (this commit adds the link)
3. DEFERRED.md — cross-track tracking entry (this commit adds the entry)

**S2.e measurement reframing**: §5 hypothesis "cells ≤ 42, cell_allocs ≤ 1000" was framed for persistent meta cells. The measurement reveals the metric is dominated by per-command transients, not persistent metas. Step 2 met its actual charter (persistent meta consolidation, dispatch unification, Move B+ benefit retained); the §5 metric was framed for a different bottleneck. S2.e-vi captures this honest reframing.

**Forward scope candidates** (not exhaustive — Track 4D's mini-design will refine):
- **Per-command attribute-record PU**: each command's positions could share a per-command compound cell (similar to how attribute-map is already a position-keyed compound)
- **SRE structural decomposition sub-cell consolidation**: `decompose-pi` allocates dom + cod + mult sub-cells per Pi; could be consolidated into a Pi-PU
- **Per-command spec/FormCell registration**: Phase 4D's grammar-rule compilation might subsume these into the unified substrate

These are research-stage forward scope; concrete designs await Track 4D's Stage 1-3 cycle.

#### §7.5.14.5 Other potential S2.e items (placeholder)

Future findings during S2.e implementation may surface additional retirement candidates. This subsection accumulates them as they arise.

### §7.5.15 Step 2 S2.e Sub-phase Mini-design (2026-04-25)

Conversational mini-design opened post-S2.d close per refined Stage 4 methodology (mini-design + mini-audit outcomes persist to design doc; co-dependent cycle). Context: post-S2.d-session + S2.d-followup, all 4 meta domains universe-active; meta-domain-info dispatch fully unified; cell-id fields functionally inert under universe-active per Move B+; S2.e is the closing sub-phase of Step 2.

#### §7.5.15.1 Architecture decision — Option C-4 (lazy universe init in fresh-X-meta)

Mini-audit of pre-init test contexts surfaced 3 candidate paths for fallback retirement:

- **Option A (full retirement + test fixture surgery)**: force ALL test contexts to call `init-meta-universes!` setup. Touches N test files (audit-pending count); high scope; "clean" choice.
- **Option B (preserve fallback)**: keep meta-store + champ-box parameters; retire only the dead `current-prop-mult-cell-write` callback. Minimal scope; preserves dual mechanism (workflow.md belt-and-suspenders concern).
- **Option C-4 (architectural lift — lazy init)**: lazy-init universe cells in fresh-X-meta when net-box is set but universe-cid is not. Eliminates pre-init fallback need without test fixture surgery.

**Decision: Option C-4 adopted** (user direction 2026-04-25). Rationale:
- Eliminates fallback path STRUCTURALLY (no `(and cid net-box)` fallback condition needed under universe-active dispatch)
- Eliminates need for `current-prop-fresh-X-cell` factory callbacks AND `current-prop-mult-cell-write` write callback
- Eliminates need for `current-X-meta-store` + `current-X-meta-champ-box` parameters (their consumers — champ-fallback functions — become dead code)
- Eliminates `'champ-fallback` and `'legacy-fn` entries in `meta-domain-info` (dead-pointers cleanup)
- ZERO test fixture surgery required (lazy init handles bare-metavar-store contexts uniformly)
- Architecturally cleanest landing — matches Track 4D vision of "everything on universe substrate"

**Implementation sketch** (per fresh-X-meta domain):

```racket
(define (fresh-meta ctx type source)
  ...
  (define net-box (current-prop-net-box))
  ;; C-4 lazy init: ensure universe cells exist for this network
  (when (and net-box (not (current-type-meta-universe-cell-id)))
    (set-box! net-box (init-meta-universes! (unbox net-box))))
  (define type-universe-cid (current-type-meta-universe-cell-id))
  ...)
```

Same pattern for fresh-mult/level/sess-meta. After this:
- Test contexts with a network: get universe cells lazily on first meta creation
- Test contexts with no network (bare CHAMP, no net-box): correctly skip both paths
- Production: lazy init never triggers because driver already called init explicitly

**Caveats** (drift risks named):
- **D1**: `init-meta-universes!` modifies the network — verify it's safe to call mid-fresh-meta (atomic; no in-flight network state)
- **D2**: lazy init happens once per network; if a test creates multiple networks, each gets init on first meta — still only +5 cells per network init (4 universes + 1 hasse-registry)
- **D3**: Step ordering — if init happens AFTER current speculation-assumption is set, cells inherit that assumption-tagging which may not match what the test expects. Mitigation: init-meta-universes! is pure cell allocation; the cells are EMPTY at init, no values to tag.

#### §7.5.15.2 Sub-phase partition

7 sub-phases ordered by dependency (each unlocks the next):

| Sub-phase | Scope | Est. LoC | Key gate |
|---|---|---|---|
| **S2.e-i** ✅ | Implement Option C-4 lazy init in 4 fresh-X-meta sites | ~20-40 (actual: +28 / -4) | DONE commit `0a38fab2` — probe diff = 0 semantically; cell_allocs=1181 unchanged; 9 targeted tests / 194 cases GREEN; full suite 7920 / 118.4s / 0 failures. D1 risk verified (lazy guard prevents double-allocation). |
| **S2.e-ii** ✅ | Retire `current-prop-mult-cell-write` write callback (1 site) | -10 deletion (actual: +22 / -7 = 15 net) | DONE commit `e943f6d7` — restored symmetry with level/sess (direct elab-cell-write); probe diff = 0; 73 targeted tests GREEN; full suite 7920 / 124.7s / 0 failures. |
| **S2.e-iii** ✅ | Retire 3 factory callbacks `current-prop-fresh-{mult,level,sess}-cell` + their dead [else] branches | -30-50 deletion (actual: +79 / -97 = 18 net) | DONE commit `619a8776` — 6 edits: 3 provides + 3 definitions + 3 installs + 3 [else] branch retirements (cond → when for mult/level; cond [else #f] for sess); probe diff = 0; 10 targeted tests / 217 cases GREEN; full suite 7920 / 124.2s / 0 failures. |
| **S2.e-iv** ✅ | Retire 3 meta-store parameters + 3 champ-box parameters + 4 champ-fallback functions + clean meta-domain-info entries (`'champ-fallback`, `'legacy-fn`) | -150-250 deletion | **3 sub-phases all delivered**: S2.e-iv-a ✅ `85e9ad8b` (Cat B status migration); S2.e-iv-b ✅ `6efb709e` (Cat C cleanup); S2.e-iv-c ✅ `d7bd97a4` (Cat A retire 6 params + 169-test-file surgery). **Net S2.e-iv: ~+200 / -700 LoC = ~500 net deletion** across all 3 sub-phases. Architecturally: universe cell is now the SINGLE source of truth for mult/level/sess meta status; meta-domain-info dispatch is lean; 6 parameters + 169 test fixture references retired. |
| **S2.e-v** ✅ | Retire 6 test-only/dead-code mult-cell + bridge surfaces (Wide scope per audit, vs design's named 2) + migrate test-mult-propagator.rkt | actual: +91 / -130 = 39 net deletion | DONE commit `118ab57a` (2026-04-25). Audit-driven scope: design named elab-add-type-mult-bridge + elab-mult-cell-write; audit revealed 4 additional surfaces (elab-fresh-mult-cell + elab-mult-cell-read = test-only mult; elab-fresh-level-cell + elab-fresh-sess-cell = DEAD CODE). User-directed Wide + Migrate. Test helper migrated to use net-add-cross-domain-propagator + type->mult-alpha primitives directly. 13 bridge tests preserved (was 14; -1 from bridge/gamma-noop retirement — γ retired in S2.c-iv made test premise no longer valid). Probe diff = 0; full suite 7914 / 119.3s / 0 failures. **Capture-gap pattern 3rd data point this session — graduation-ready.** |
| **S2.e-vi** ✅ | Final §5 measurement + **honest hypothesis reframing** (persistent vs transient cell distinction per §7.5.14.4) + 6 codifications from S2 arc | actual: docs-heavy; +~250 LoC docs across STEP2_BASELINE §12.5 + DEVELOPMENT_LESSONS.org × 6 entries | DONE this commit (2026-04-25). 3 of 6 §5 micro criteria MET; 2 transitional honestly reframed (D4 risk addressed — §5 hypothesis was framed for the WRONG bottleneck per §7.5.14.4; per-command transients dominate, persistent meta consolidation worked); full suite 119.3s within variance; Move B+ benefit MAINTAINED through 5 sub-phases. 6 patterns graduated to DEVELOPMENT_LESSONS.org (Pipeline.md prophylactic, Capture-gap, Partial-state regression unwinds, Audit-first, Audit-driven Wide-vs-Narrow NEW, Sed-deletion 2-pass operational, Microbench-claim verification across sub-phase arcs). |
| **S2.e-VAG** ✅ | Adversarial Vision Alignment Gate close (Step 2 final close) | docs-only; appended to dailies | DONE this commit (2026-04-25). 4 questions × TWO-COLUMN catalogue vs challenge applied to entire Step 2 arc. All 4 pass under adversarial framing — challenges surfaced honest gaps already addressed (off-network surfaces captured for Phase 4/PM 12; cells/cell_allocs reframed; sub-charter scoping honest; drift risks named + codified). **Net adversarial finding**: Step 2 is more architecturally honest than most tracks because of conversational checkpoint cadence + adversarial VAG at each sub-phase + microbench-claim verification at 3 distinct points + capture-gap pattern caught real-time + honest §5 reframing + 6 codifications graduated. **STEP 2 SUBSTANTIVELY CLOSED**. Addendum proceeds to Phase 1E. |

**Total estimated scope**: ~-200-300 LoC NET (mostly deletions) + S2.e-vi documentation.

**S2.e-vi codifications** (4 from S2 arc):
1. **Pipeline.md "Per-Domain Universe Migration" checklist works prophylactically** — 3 data points (S2.c-iv 4-min hang prevention; S2.d-level + S2.d-session clean landings)
2. **Capture-gap pattern** — when a sub-phase audit surfaces work for one domain, parallel domains should be captured at the same time. 2 data points this session (S2.d-followup §7.5.14.1 expansion; this S2.e mini-design §7.5.14.4 capture for transient consolidation)
3. **Partial-state regression unwinds when architecture completes** — 3 data points (S2.a positive surprise; S2.b-iv→S2.c-iv solve-meta! recovery; S2.c-iv→S2.d follow-through)
4. **Backward-compat-as-rationalization audit pattern** — 1 data point (S2.d-followup Path B reframe). The workflow.md "preserved for backward-compat" red-flag phrase IS the test; audit consumer dependencies before claiming preservation

**S2.e measurement (S2.e-vi)**:
- Re-run probe + acceptance to verify retirements landed without semantic regression
- Re-run bench-meta-lifecycle.rkt full sequence; compare against §5 hypotheses
- **Honest reframe of §5**: persistent meta cells (delta target) vs transient per-command cells (the bottleneck driving cell_allocs). Step 2 met its actual charter; the §5 metric was framed for a different bottleneck. Per-command transient consolidation is captured in §7.5.14.4 for Track 4D scope.

#### §7.5.15.3 Drift risks (for mid-flight principles challenge)

1. **D1 — Lazy init timing**: init-meta-universes! must be safe to call mid-fresh-X-meta. Verify by audit + targeted tests during S2.e-i.
2. **D2 — Champ-fallback dead-pointer cleanup**: `meta-domain-info` entries reference `'champ-fallback` + `'legacy-fn`; entries must be cleaned (not just functions retired) to avoid stale references.
3. **D3 — Test fixture surprise**: some tests may explicitly set/test the meta-store / champ-box parameters. Mitigation: targeted tests for each retirement sub-phase catch unexpected dependencies.
4. **D4 — §5 hypothesis temptation to rationalize**: cells/cell_allocs targets are still NOT met after S2.e (per §7.5.14.4 finding — bottleneck is transients, not metas). S2.e-vi MUST honestly reframe rather than rationalize "the architecture is right, the metric was wrong is good enough." The honest answer is: the metric was framed for the wrong bottleneck; capture that finding; point forward to Track 4D for the real fix.
5. **D5 — Capture discipline regression**: each sub-phase touching a parameter retirement should capture per-domain analogs uniformly (the §7.5.14.1 capture-gap pattern from S2.d-followup). Apply prophylactically.

#### §7.5.15.4 Sub-phase completion criteria

- **S2.e-i**: Lazy init works in all 4 fresh-X-meta sites; probe diff = 0; targeted fresh-meta tests pass; full suite GREEN
- **S2.e-ii**: `current-prop-mult-cell-write` deleted; mult tests green; full suite GREEN
- **S2.e-iii**: 3 factory callbacks deleted; mult/level/session targeted tests green; full suite GREEN
- **S2.e-iv**: 6 parameters + 4 fallback functions + meta-domain-info entries cleaned; comprehensive targeted tests; full suite GREEN
- **S2.e-v**: elab-add-type-mult-bridge surface decision (migrate test or retire) + tests green
- **S2.e-vi**: §5 measurement run; STEP2_BASELINE.md §12.5 added with post-S2.e data + honest hypothesis reframe; 4 codifications captured (in DEVELOPMENT_LESSONS.org graduation candidates)
- **S2.e-VAG**: TWO-COLUMN adversarial VAG; if challenges surface drift, address before commit; otherwise pass

#### §7.5.15.5 Cross-cutting captures (verified during this mini-design)

Per the capture-gap discipline (1 data point reinforced this session — second occurrence after S2.d-followup), verifying ALL future-work claims have explicit capture:

- ✅ Per-command transient cell consolidation → §7.5.14.4 (added this commit) + Track 4D research forward-pointer + DEFERRED.md entry
- ✅ Cache field retirements (expr-meta.cell-id, sess-meta.cell-id) → Phase 4 row in parent design
- ✅ Dual-surface retirements (sess-meta-solution/cell-id, meta-solution/cell-id) → Phase 4 + S2.e cooperative per §7.5.14.2
- ✅ Off-network parameter retirements (10 total) → §7.5.14.1 expanded + DEFERRED.md PM 12 entries

No remaining capture gaps surfaced by S2.e mini-design audit.

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

### §7.6.16 Phase 1E + Phase 1D — `that-*` Storage Unification + Meta-Solution Canonical Store (DEFERRED to PPN 4D, 2026-05-19)

**Status**: ⏸️ **DEFERRED to PPN 4D** (decision 2026-05-19). See [PPN 4D Implementation Draft Note (2026-05-19)](2026-05-19_PPN_4D_IMPLEMENTATION_DRAFT_NOTE.md) for full findings carried forward.

**Why deferred** (per 2026-05-19 scope re-thinking):

Phase 1D/1E concern is **storage / API-routing substrate unification** — different architectural concern from the addendum's stated charter (per §1.1: speculation substrate + fuel substrate in Phase 1; orchestration unification in Phase 2; union-types/hypercube/residuation in Phase 3; top-level orchestration in Phase 4). The substrate-unification concern fits PPN 4D's charter naturally:

> 4D thesis: "Collapse fragmented typing/elaboration/reduction subsystems into a unified attribute-grammar substrate... Motivated by PPN 4C Addendum T-3's three accidentally-load-bearing findings (the structural fingerprint of sources-of-truth fragmentation)."

The 1D/1E exploration discovered a fourth potential accidentally-load-bearing finding (install-breaks-resolution under specific patterns) — a latent architectural constraint relevant to 4D's grammar-rule-compiler design. The dual-store inconsistency 1D was attempting to close IS sources-of-truth fragmentation; the piecemeal cut wants holistic treatment that 4D's substrate unification provides.

**Nothing in the addendum's remaining phases (2A/2B/2V/3A/3B/3C/3V/4/V) depends on 1D/1E.** Closing them as deferred-to-4D unblocks Phase 2.

**Captured for 4D** in [PPN 4D Implementation Draft Note](2026-05-19_PPN_4D_IMPLEMENTATION_DRAFT_NOTE.md):
- Stage 2 audit findings (M+A+E+R+S bench baseline + post-cleanup A/B + bench harness)
- Realization B research (Coq/Agda/Idris/Lean precedent)
- Architecture exploration (Approaches A/B/C/D/E with adversarial principles evaluation)
- 1D.a BSP-firing spike findings (no speculation-guard pattern)
- **Critical diagnostic finding**: install-breaks-resolution anomaly + 6 hypotheses ruled out + topology-stratum hypothesis UNTESTED (must be addressed by 4D or independently before 4D opens)
- Durable bench harness (`bench-attribute-record.rkt`) + baselines (pre-cleanup + post-cleanup)
- Pre-cleanup commit `1340aec8` (Move B+ 2nd instance) — INDEPENDENTLY VALUABLE; stands as Phase 1V incidental cleanup

**Sections §7.6.16.1 through §7.6.16.14 below are historical record** — preserved for traceability and forensic value. They informed the scope re-thinking and feed PPN 4D's design cycle, but are not the canonical 1E or 1D design.

**Process lesson** (codification candidate for DEVELOPMENT_LESSONS.org): audit findings flag debt, but don't auto-promote to precursor phases. The exploration's framing of "1D as precursor to 1E" was scope drift — the dual-store smell was real but didn't gate 1E's stated surface-routing charter. Discipline forward: audit findings are architectural INPUTS, not auto-promoted precursors.

---

**Original implementation note** (NOT a Stage 3 design — this section captures the architectural considerations surfaced during 2026-04-23 Step 2 mini-design dialogue, to persist them for the future Phase 1E design cycle).

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

#### §7.6.16.10 Stage 2 audit findings (2026-05-17/18, this session)

Per §7.6.16.6 TODO, Stage 2 audit executed in two arcs this session.

**Pre-0 measurement build-out** (commits `13d8f7d6` → `88da1b8c` → `e0fe1aa0`):

New durable bench file: [`racket/prologos/benchmarks/micro/bench-attribute-record.rkt`](../../racket/prologos/benchmarks/micro/bench-attribute-record.rkt) — harness survives Phase 1E close; Track 4D inherits when adding `:whnf`/`:reduce`/`:surface` facets. Five tiers:

- **M-tier (8 micros)**: current baselines for `that-*` + `compound-cell-component-*` + meta-domain dispatch + id-map walk
- **A-tier (5 micros)**: J-A simulated vs J-C composition + dispatch predicate + specialized-cell-cache LB + memory growth (1k/10k positions)
- **E-tier (12 micros)**: read-state spread (solved/unsolved/unallocated) + speculation-active vs cache-fallback + cross-facet at fully-populated meta-pos + arity-2 whole-record decomposition
- **R-tier**: process-file on `examples/2026-04-17-ppn-track4c.prologos` (67 commands, 4674 ms wall, 114 ms elaborate (~2.4% of wall), 1203 ms reduce (~26% dominant))
- **S-tier**: 6 frozen-value semantic axes captured at [`data/benchmarks/attribute-record-pre0-baseline-2026-05-17.txt`](../../racket/prologos/data/benchmarks/attribute-record-pre0-baseline-2026-05-17.txt)

**Pre-Phase-1E cleanup** (commit `1340aec8`): retired `with-handlers` wrappers in `resolve-worldview-bitmask` — enet variant at `meta-universe.rkt:288`, pnet variant at `propagator.rkt:3877`. Both guarded a structurally-impossible failure (worldview-cache-cell-id is cell-id 1, always allocated by `make-prop-network`). Move B+ pattern, 2nd instance (S2.c-iii was 1st).

**A/B impact** (captured at [`attribute-record-post-cleanup-2026-05-18.txt`](../../racket/prologos/data/benchmarks/attribute-record-post-cleanup-2026-05-18.txt)):

| Bench | Pre-cleanup | Post-cleanup | Δ |
|---|---:|---:|---:|
| M5a `compound-cell-component-ref` solved | 207 ns | **78.5 ns** | **−62%** |
| M5b ref unsolved | 208 ns | **77.9 ns** | **−63%** |
| M7a `meta-solution` full dispatch | 328 ns | **173 ns** | **−47%** |
| E2b wv=0 cache-fallback | 209 ns | **89.8 ns** | **−57%** |
| Full suite (8224 tests) | 114.7s | **110.9s** | **−3.8s (3.3%)** |

E2 axis confirmed the diagnosis empirically: pre-cleanup E2a (81.9, no with-handlers branch) vs E2b (209.4, with-handlers branch) differed by 127 ns. Post-cleanup both paths ~90 ns. The 127 ns matched the predicted continuation-marker overhead.

**Dispatch primitive cost validated** (spike in `/tmp/bench-expr-meta-pred.rkt`, run 2026-05-18):
- `(expr-meta? meta) → #t`: **1.61 ns**
- `(expr-meta? literal/app/Pi) → #f`: **0.97-1.38 ns**
- `(expr-meta-id meta)`: **0.99 ns**

Position-keyed dispatch via `expr-meta?` + extraction is **~1.5-2 ns total** — essentially free. Substantially cheaper than cell-id-keyed `meta-universe-cell-id?` (53-257 ns per A1 measurement) which fights the natural data flow.

**R-tier projection signal** (heuristic that-* call counting from PERF-COUNTERS):
- Estimated calls per acceptance run: ~3773 writes + ~2039 reads (~43% at meta positions)
- Projected `that-*` total time (post-cleanup):
  - Current path: ~1268 μs (~1.11% of `elaborate_ms`)
  - Phase 1E J-C unoptimized: ~1227 μs (~1.08% of `elaborate_ms`)
  - **J-C is cheaper than current J-A-like surface API post-cleanup**

Architecturally: Phase 1E routing cost is **essentially invisible at the macro level** (<0.005% of total wall). The architectural decision is no longer a perf trade-off — correctness + principle alignment dominate.

#### §7.6.16.11 Research findings + Qc resolution (2026-05-18)

Initial Phase 1E framing (pre-2026-05-18) assumed the INHABITANT layer in attribute-map's `:type` facet was scaffolding mirroring universe-cell `solve-meta!` writes — initial recommendation was retirement. User pushback (this session) required studying the original design intent before recommending changes.

**Module Theory Realization B is deliberate, not scaffolding** (per D.3 §6.1):

> "There is one universe hierarchy; Nat, Type(0), Type(1), etc. are all terms at adjacent levels. 'Type' and 'term' are a **layer distinction, not a lattice distinction**. Attempting to separate them into two lattices in D.1 duplicates the carrier... The duplication is the scent."
>
> "**User-visible surface is preserved**: `that-read pos :type` reads CLASSIFIER-tagged entries; `that-read pos :term` reads INHABITANT-tagged entries. The tag distinction is implementation — :type and :term **remain distinct surface names with distinct semantics**."
>
> "**Naming precedent**: Coq's `evar_map` has `concl` (goal type) and `body` (optional solution) as separate fields — but Coq stores them in one meta-info record per meta, not two independent stores. Agda/Idris/Lean follow similar patterns. **Realization B matches how elaboration with metavariables is done in the reference systems, rendered in propagator-network terms**."

**Provenance is first-class** (per D.3 §6.1.1): each tagged entry carries `(propagator-id, assumption-id, source-loc)` for first-class compiler + error features — supporting Track 7 and Phase 11b.

**Dual-store discovery** (uncovered during research):

Currently TWO distinct write paths produce "the meta is solved" state:

| Meta class | Solution write path | Where stored |
|---|---|---|
| Trait dict meta | `(that-write net tm-cid dict-meta-pos ':term dict-expr)` → magic-keyword routes to attribute-map `:type` INHABITANT layer | attribute-map |
| Type-unification meta | `solve-meta!` (from unification propagators) | universe cell |

This means `(that-read am type-meta-pos :term)` returns bot even when the meta is solved (because `solve-meta!` doesn't write through to attribute-map INHABITANT). NOT consistent across meta classes.

**Qc resolution** (user-confirmed 2026-05-18):

> "I do believe the intent is a user-defined assertion/extension. The hope is to have an easily-usable attribute grammar that is extendable by user grammars, with as much expressivity and power as we as the language implementers would have."

Track 7 `that x :term V` is intended as **user-asserted-inhabitant**. User assertions are FIRST-CLASS WRITES to the same store solver-derivation writes to. They:
- Participate in elaboration network like solver writes (provenance, contradiction-on-mismatch, worldview-aware)
- Converge on ONE canonical store via merge (Role B equality-enforce)
- Carry provenance distinguishing source (user assertion vs solver derivation)

This collapses the "dual-store conundrum" into **single-store-with-multiple-writers + provenance + projection**. The architectural question becomes: **where is the canonical store, and what role does any other store play?**

#### §7.6.16.12 Architectural reframe — 3 architectures (post-Qc)

Pre-Qc framing (Z1/Z2/ZA) treated the question as "consolidate stores." Post-Qc, the framing is **single canonical store + worldview-tagged projection + multi-writer provenance**. Three architectures evaluated:

##### Architecture A — attribute-map canonical, universe cell as worldview projection

**Design**:
- attribute-map `:type` CLASSIFIER × INHABITANT = single source of truth (Realization B preserved)
- All writes (`solve-meta!`, trait-resolution, future user-`that` assertions) converge on attribute-map
- Universe cell = derived projection (worldview-tagged) maintained by bridge propagator
- Bridge fires on attribute-map `:type` INHABITANT writes at meta-pos → updates universe cell projection
- Speculation hot paths (zonk, unify worldview-filtered reads) consume universe cell projection
- `(that-read am pos :type/:term)` reads attribute-map directly (unchanged from current behavior)
- `(meta-solution id)` reads universe cell projection (existing API; sees worldview-filtered solver value)

**Estimated scope**: ~600-900 LoC. Migrate `solve-meta!` to write attribute-map (directly or via reflective bridge); add bridge propagator for universe-cell projection; audit consumer paths.

**Principle alignment**:
- **Decomplection** ✓✓ — position-keyed substrate uniform across metas + non-metas
- **Single Source of Truth** ✓✓ — attribute-map canonical; universe cell is derived
- **Realization B** ✓✓ — fully preserved (Coq/Agda/Idris/Lean precedent matched)
- **Most Generalizable Interface** ✓✓ — `that-*` uniform API
- **First-Class by Default** ✓✓ — user `that` assertions natural

**Concerns**:
- Universe cell becomes derived; speculation paths must consume the projection
- Bridge propagator must maintain consistency under speculation branches (each worldview's bridge update is per-branch worldview-tagged)

##### Architecture B — universe cell canonical for metas, classify-inhabit-value shape extended

**Design**:
- Universe cell value shape changes: `(hasheq meta-id → tagged-cell-value(classify-inhabit-value(CLASSIFIER, INHABITANT)))`
- Universe cell holds BOTH tag layers per meta, worldview-tagged
- attribute-map `:type` at meta-pos = retired (universe cell takes over for metas)
- attribute-map `:type` at non-meta-pos = unchanged (classify-inhabit-value as currently)
- `(that-read am pos :type/:term)` dispatches by `(expr-meta? pos)` (~1.6 ns) — meta-pos routes to universe cell
- All meta writes converge in universe cell layered-tagged store

**Estimated scope**: ~1500-2200 LoC. Universe cell value-shape change + write-path partitioning by tag + read routing + merge function rework (compound-tagged-merge over classify-inhabit-value per meta-id).

**Principle alignment**:
- **Decomplection** ✓ — meta state in one place per concept
- **Single Source of Truth** ✓✓ — universe cell canonical for metas
- **Realization B** ✓✓ — preserved via universe cell layered shape

**Concerns**:
- Largest of the three migrations; universe-cell merge becomes nested compound
- Splits meta vs non-meta architectures (different value shapes for the same conceptual data)

##### Architecture C — attribute-map extended with worldview-tagging

**Design**:
- attribute-map facets (or `:type` only) extended to support tagged-cell-value worldview-tagging natively
- Universe cells retired for metas (attribute-map handles everything)
- Single store + worldview-tagging + Realization B + uniform across metas + non-metas

**Estimated scope**: ~2000-3000+ LoC. Worldview-tagging cascade across attribute-map facets.

**Principle alignment**: maximum uniformity but at the cost of touching infrastructure outside the meta-store concern.

**Concerns**: largest migration; touches `:context`, `:usage`, `:constraints`, `:warnings` (may not need worldview-tagging); inverts the Phase 9 substrate purpose for universe cells.

##### Lean: Architecture A (pending mini-design dialogue)

Smallest delta with maximum principle gain. Preserves Realization B (matches Coq/Agda/Idris/Lean reference). Keeps universe cells in their designed role (worldview-tag optimization for speculation paths). Track 7 user-`that` assertions land naturally on the canonical store. Post-cleanup measurements show `that-*` cost is invisible at macro level (<0.005% of wall), so the bridge's cost is also invisible — A optimizes for correctness + principle alignment, not micro-perf.

Push-back consideration: Architecture B keeps universe cells central, which means speculation paths get direct access without bridge cost. If Phase 3 ATMS union-type branching turns out speculation-heavy at the macro level, B might pay back its larger migration cost. However: R-tier projection shows `that-*` cost is <0.005% of wall — speculation-heavy or not, the bridge cost in A is below measurable.

**Decision pending mini-design dialogue** in Phase 1D opening.

#### §7.6.16.13 Phase 1D scope — Meta-Solution Canonical Store Consolidation

**Purpose**: resolve the dual-store inconsistency for "meta solution" (§7.6.16.11) by establishing attribute-map `:type` INHABITANT as the canonical store and adding a reverse-bridge propagator that reflects universe-cell solver writes back to it. Precedes Phase 1E because:
- 1E's mult/level/session magic-keyword routing should target a single canonical store, not two
- The dispatch design (`(expr-meta? pos)` routing) is informed by which store is canonical
- Once 1D resolves the canonical-store question, 1E becomes a pure surface extension (routing + cache + cleanup + A/B)

**Architecture**: **A (CONFIRMED 2026-05-18)** — attribute-map canonical, universe cell as worldview-tagged projection. Refined per audit findings: bridge install-time wiring is reusable; meta-pos synthesis is free under universe-active path (`(expr-meta id #f)` uniform). Scope estimate dropped from 600-900 to ~300-500 LoC. See §7.6.16.10 mini-audit findings + §7.6.16.12 architecture comparison.

**Mini-audit findings persisted** (executed 2026-05-18):

Inventory:
- `solve-meta!` family — ~20 call sites across `unify.rkt`, `resolution.rkt`, `trait-resolution.rkt`, `qtt.rkt`, `typing-sessions.rkt`. All write to universe cells (+ meta-info CHAMP).
- `that-write :term` — 3 production sites (typing-propagators.rkt:768, 1210, 1215). All write to attribute-map `:type` INHABITANT.
- `that-read :term` — 2 production sites (typing-propagators.rkt:766, 907). Latter is `make-meta-solution-output-fire-fn` — the existing bridge from attribute-map → output cell.

Key audit data:
- Type metas DUAL-WRITTEN today: network propagator path (app-fire-fn → attribute-map → output cell → resolution loop → `solve-meta!` → universe cell) AND imperative paths (`solve-meta!` directly from unify/resolution/etc.). The asymmetry: network path closes loop; imperative path doesn't update attribute-map.
- Mult/level/session metas: single-stored in universe cells (no attribute-map facet today).
- `expr-meta` struct shape: `(struct expr-meta (id cell-id))`. Under universe-active path (production post-S2.d), `cell-id = #f` uniformly. **Implication**: meta-pos = `(expr-meta id #f)` synthesizable from meta-id alone (`equal?`-compatible).
- Existing bridge (`make-meta-solution-output-fire-fn`) is per-meta, install-time-wired at typing-propagators.rkt:1778 with `(tm-cid meta-pos meta-id output-cid)` already in closure.

**Decision**: Reverse-bridge propagator can be co-installed alongside existing bridge at line 1778, with `(tm-cid meta-pos meta-id)` captured at install time. No runtime meta-pos lookup needed. Scope simplifies materially.

##### Sub-phase partition (confirmed)

| Sub-phase | Scope | Est. LoC |
|---|---|---:|
| **1D.a** | Co-install reverse-bridge propagator per type meta at `install-typing-network:1778`. Bridge watches universe cell at component-key=meta-id (worldview-tagged via `tagged-cell-value`). On universe-cell write, bridge reads value (worldview-filtered) and writes via `that-write net tm-cid meta-pos ':term value`. Closure captures `(tm-cid e id)` at install time. | 150-250 |
| **1D.b** | Convergence verification — targeted tests for type metas solved via `solve-meta!` from imperative paths (unify, resolution, trait-resolution, qtt, sessions). Verify `(that-read am type-meta-pos :term)` returns the solution post-1D.a regardless of write path. Per Stage 4 methodology: tests required because the phase adds behavior (the reverse-bridge closure). | 50-100 |
| **1D.c** | Provenance integration — bridge writes attribute-map `:term` with provenance source `'bridge-from-solver` (distinguishable from `'network-propagator` and future `'user-assertion`). Aligns with D.3 §6.1.1 provenance infrastructure for Phase 11b. | 50-100 |
| **1D.d** | Post-implementation A/B + bench validation — re-run `bench-attribute-record.rkt`; compare to post-cleanup baseline ([`attribute-record-post-cleanup-2026-05-18.txt`](../../racket/prologos/data/benchmarks/attribute-record-post-cleanup-2026-05-18.txt)); verify no suite-level regression vs 110.9s. Capture new baseline file. | 50 |
| **1D-VAG** | Adversarial gate (TWO-COLUMN catalogue-vs-challenge per workflow.md). Verify drift risks cleared. | — |

Total estimated scope: **~300-500 LoC** net.

##### Drift risks (named at 1D opening; ① RESOLVED via spike 2026-05-18)

**① Speculation-aware bridge firing — RESOLVED VIA SPIKE 2026-05-18** (see §7.6.16.14)

Initial framing assumed: bridge installed at base would fire at base worldview only; speculation guard (skip if `current-worldview-bitmask != 0`) would defer; post-speculation, BSP would re-fire the bridge at base for committed values.

**Spike falsified this**: bridge fires at the WRITING worldview, not at install worldview. Under speculation (wv=1), bridge fires with current-worldview-bitmask=1. Post-speculation parameterize exit does NOT re-fire the bridge. If guarded, speculatively-solved metas would never reflect to attribute-map.

**Resolved design**: NO speculation guard. Bridge writes attribute-map regardless of wv. Rollback safety provided by `with-speculative-rollback`'s elab-net snapshot/restore at the speculation boundary — same pattern as the existing app-fire-fn `term-map-write` at typing-propagators.rkt:1210/1215 (which writes attribute-map under speculation without worldview-tagging; snapshot handles rollback).

2. **Bridge fire-pattern + dependent firing precision** — bridge must declare `:component-paths (list (cons type-meta-universe-cell-id meta-id))` so it fires only when THIS meta's universe-cell component changes, not when sibling components change. Phase 1f enforcement applies.

3. **Cascade with existing bridge** — the new reverse-bridge could trigger an idempotent cycle: solve-meta! → universe cell write → reverse-bridge → attribute-map :term write → existing meta-solution-output-fire-fn fires → output cell append → resolution loop reads output cell → calls solve-meta!. The cycle terminates because the value is idempotent (same solution; merge is α-equiv strict no-op when identical). Verify empirically in 1D.b tests.

4. **Backward compat for `(that-read am type-meta-pos :term)` consumers** — currently returns bot for imperatively-solved metas. Post-1D.a, returns the actual solution. Audit for tests/consumers that ASSERT bot expecting imperative solve hasn't reached attribute-map; update or remove.

##### Performance constraints

- No suite-level regression (post-cleanup baseline: 110.9s / 8224 tests / 0 failures)
- M5a / M7a / E2 axis numbers should not regress materially (current 78.5 / 173 / 89.8 ns)
- Bridge fire cost amortized over all type meta solves — projected impact <0.005% of total wall per R-tier framing

##### Phase 1E re-scoped post-1D (unchanged from §7.6.16.13 earlier framing)

- **1E.a**: `that-*` magic-keyword routing extension (`:mult` / `:level` / `:session`) via `(expr-meta? pos)` dispatch (~200-300 LoC). Mult/level/session route directly to universe cells; no attribute-map facet involved (no Realization B story for these dimensions today; revisit if Track 4D introduces).
- **1E.b**: Universe-cell specialized-cell-cache — 4th §4.6 framework instance (~200-300 LoC)
- **1E.c**: Cleanup + post-implementation A/B + parity wiring in [`tests/test-elaboration-parity.rkt`](../../racket/prologos/tests/test-elaboration-parity.rkt) (~100-200 LoC)
- **1E-VAG**: Adversarial gate

Per-phase scope (post-confirmation):

| Phase | Est. LoC | Notes |
|---|---:|---|
| 1D.a | 150-250 | Reverse-bridge install (no speculation guard per §7.6.16.14 spike) |
| 1D.b | 50-100 | Convergence tests |
| 1D.c | 50-100 | Provenance integration |
| 1D.d | 50 | A/B + baseline capture |
| 1D-VAG | — | Adversarial gate |
| 1E.a | 200-300 | Routing extension |
| 1E.b | 200-300 | Specialized-cell-cache (§4.6 4th instance) |
| 1E.c | 100-200 | Cleanup + tests + A/B |
| 1E-VAG | — | Adversarial gate |

#### §7.6.16.14 Phase 1D.a BSP-firing spike (2026-05-18)

Mini-design surfaced drift risk #1 (speculation-aware bridge firing). Spike executed before 1D.a implementation to verify BSP behavior empirically — the speculation guard pattern hinged on whether BSP re-fires dependents on speculation-exit (parameterize end + worldview-cache update).

**Spike file**: `/tmp/spike-1d-bsp-firing.rkt` (throwaway).

**Setup**: fresh elab-network → init-meta-universes! → create meta m1 → install observation propagator watching universe cell at component-key=m1's meta-id.

**Findings**:

| Test | Action | Bridge fires? | At wv? | Sol observed |
|---|---|---|---:|---|
| 1 | `solve-meta!(m1.id, expr-Int)` at base (wv=0) | ✓ | 0 | (expr-Int) |
| 2 | direct universe-cell write under speculation (wv=1) with (expr-Bool) | ✓ | **1** | (expr-Bool) |
| 3 | post-speculation observation (no new writes) | ✗ no firings | — | — |
| 4 | post-speculation read at wv=0 vs wv=1 | — | — | wv=0: `'type-top`; wv=1: (expr-Bool) |

**Critical architectural finding**: bridge fires at the WRITING worldview, not at install worldview. Under speculation (wv=1), bridge fires with current-worldview-bitmask=1. Post-speculation parameterize exit does NOT re-fire the bridge. This **invalidates** the "speculation guard + re-fire post-commit" pattern proposed in mini-design.

**Resolved design**: NO speculation guard. Bridge follows the same pattern as existing `app-fire-fn term-map-write` at lines 1210/1215 — writes attribute-map regardless of wv; rollback safety via `with-speculative-rollback`'s elab-net snapshot/restore at the speculation boundary.

Test 4 anomaly note: post-speculation read at wv=0 returns `'type-top` because the test mixed `solve-meta!` (which writes via the full meta-solve path including `meta-info` CHAMP) with direct `compound-cell-component-write/pnet` (which bypasses solve-meta!). Production flows always go through `solve-meta!`, which handles already-solved + contradiction-detection within its body. The 'type-top reading is an artifact of the synthetic test, not a production concern.

**Updated 1D.a bridge factory**:

```racket
(define (make-meta-solution-attribute-reflect-fire-fn tm-cid meta-pos meta-id type-universe-cid)
  (lambda (net)
    (define sol (compound-cell-component-ref/pnet net type-universe-cid meta-id))
    (cond
      [(not sol) net]
      [(eq? sol 'infra-bot) net]
      [(eq? sol 'type-bot) net]           ;; expr-meta-bot-placeholder
      [(prop-type-bot? sol) net]
      [(prop-type-top? sol) net]          ;; contradiction
      [(expr-meta? sol) net]              ;; still a meta — deferred resolution
      [else
       (that-write net tm-cid meta-pos ':term sol)])))
```

**Install** (at typing-propagators.rkt:1786, between meta-solution-output and residuation):

```racket
;; PPN 4C Phase 1D.a — reverse-bridge: reflect universe-cell solver writes
;; to attribute-map :type INHABITANT layer. Closes the dual-store inconsistency
;; per §7.6.16.13 + spike §7.6.16.14.
(define type-universe-cid (current-type-meta-universe-cell-id))
(define net-rb
  (if type-universe-cid
      (let-values ([(n _) (net-add-propagator net-b
                            (list type-universe-cid) (list tm-cid)
                            (make-meta-solution-attribute-reflect-fire-fn
                             tm-cid e id type-universe-cid)
                            #:component-paths
                            (list (cons type-universe-cid id)))])
        n)
      net-b))
```

**Always-on (`net-add-propagator` not fire-once)** per mini-design decision: a meta might be solved multiple times under refinement; fire-once would prevent reflecting refinement. Idempotent cycles terminate via attribute-map-merge-fn α-equiv strict (line 422 `(equal? old-val val) → rec`) — same-value writes are no-ops.

**Spike codification candidate** (1 data point; watch for graduation): "When a mini-design hinges on assumed BSP scheduler behavior, run a small spike to verify empirically before implementing. Spike data falsified the speculation-guard pattern here, redirecting the design from a 'principled but wrong' approach to the established 'snapshot/restore at speculation boundary' precedent."

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

### §8.3 Phase 2A deliverables (ORIGINAL — superseded by §8.7 mini-design 2026-05-19)

**Note**: this list represents the original D.3 design. §8.7 below revises it per Phase 2A mini-design + mini-audit (2026-05-19). Key revisions: 3 cells → 2 cells (L1 already cell-based per S2.b-iv); cell-id 14 → cell-id 14 for resolution (since readiness retired); `collect-ready-constraints-via-cells` reference is stale (was retired in S2.b-iv). Refer to §8.7 for the current design.

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
   - `process-readiness net pending-hash` wraps `collect-ready-constraints-via-cells`  ← STALE: retired in S2.b-iv
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

### §8.7 Phase 2A Mini-design + Mini-audit (2026-05-19)

Per Stage 4 Per-Phase Protocol: mini-design + mini-audit cycle before implementation. Outcomes persist into this design doc per DESIGN_METHODOLOGY refined Stage 4 methodology.

#### §8.7.1 Mini-audit findings (codebase grounding)

**Cell-id allocation (post-Tropical-Addendum)**:

```
cell-id 0  decomp-request-cell-id
cell-id 1  worldview-cache-cell-id
cell-id 2  relation-store-cell-id
cell-id 3  config-cell-id
cell-id 4  naf-pending-cell-id              (S1 NAF — value tier)
cell-id 5  pool-config-cell-id
cell-id 6  constraint-propagators-topology  (topology tier)
cell-id 7  elaborator-topology              (topology tier)
cell-id 8  narrowing-topology               (topology tier)
cell-id 9  sre-topology                     (topology tier)
cell-id 10 classify-inhabit-request-cell-id (value tier; Phase 3c-iii)
cell-id 11 fuel-cell-id                     (Tropical Addendum)
cell-id 12 fuel-budget-cell-id              (Tropical Addendum)
─── next available: cell-id 13 ───
```

**`register-stratum-handler!` API** (propagator.rkt:2768-2775):
- Signature: `(request-cell-id handler-fn #:tier [tier 'value] #:reset-value [reset-value (hasheq)])`
- Handler signature: `(net pending) → net`
- BSP outer-loop auto-clears via `(net-cell-reset processed req-cid reset-val)` after handler runs (propagator.rkt:3017) — handlers don't clear manually

**BSP outer loop structure** (propagator.rkt:2990-3046) — confirmed multi-pass fixpoint pattern:
```
outer-loop:
  S0 quiescence (BSP fire rounds)
  process topology-tier handlers; restart-from-outer-loop on worklist
  process value-tier handlers (in registration order); restart on worklist
  if no progress → done
```

**Critical finding — §8.3 stale reference**: §8.3 deliverable 4 says `process-readiness wraps collect-ready-constraints-via-cells`. But `collect-ready-constraints-via-cells` was **RETIRED in PPN 4C S2.b-iv** (commit `bddfc3e3`, 2026-04-24) per the codification: vestigial Track-7-Phase-8a polling mechanism, replaced by readiness propagators (set-latch + threshold) that write to `ready-queue` cell directly during S0. Post-S2.b-iv, **L1 readiness is structurally emergent**; no L1 stratum handler needed.

**Module load order** (driver.rkt:37 + 45): `metavar-store.rkt` loads BEFORE `relations.rkt`. Metavar-store doesn't transitively require relations. If S(-1) + L2 handlers register in metavar-store, they register before S1 NAF (in relations.rkt). Resulting value-tier iteration order: **[S(-1) retraction, L2 resolution, S1 NAF, classify-inhabit]**.

**Current sequential resolution loop** (metavar-store.rkt:2131-2169):
```racket
(define (run-stratified-resolution-pure enet trigger-meta-id resolution-executor)
  (let loop ([fuel ...] [meta-id ...] [current-enet enet])
    (let* (;; S(-1): Retraction — run imperatively for now (reads/writes box)
           ;; TODO: purify retraction stratum in Phase 8   ← THIS IS PHASE 2 WORK
           [_ (run-retraction-stratum!)]
           ;; S0: Type propagation (quiescence) — pure on prop-net
           [enet-s0 ((current-quiescence-scheduler) ...)]
           ;; S1/L1: read ready-queue (already populated by readiness propagators)
           [queue-actions (read-ready-queue-actions enet-s0)]
           ;; S2: Resolution commitment — for/fold over actions
           [enet-s2 (for/fold ([e enet-s0]) ([action (in-list queue-actions)])
                      (resolution-executor e action))])
      (if (eq? enet-s2 enet-s0) enet-s2 (loop ...)))))
```

#### §8.7.2 Design revisions to §8.3

| §8.3 original | §8.7 revised | Why |
|---|---|---|
| 3 new cells (13/14/15) | **2 new cells (13/14)** | L1 readiness already structurally emergent post-S2.b-iv |
| readiness-stratum-request | **REMOVED** | Readiness propagators already write `ready-queue` cell during S0 |
| resolution-stratum-request cell-id 15 | **resolution-stratum-request cell-id 14** | Cell-id reused (no readiness cell to allocate) |
| Bare cell allocations | **§4.6 specialized cell type framework declarations** | Per Phase 1 framework precedent + user direction (don't add legacy-shaped cells for PM 12 to migrate) |

#### §8.7.3 §4.6 framework declarations for the 2 new cells

| Cell | `:tier` | `:storage` | `:fires-on` | `:merge-fn` | `:reset-value` |
|---|---|---|---|---|---|
| retraction-stratum-request (cell-id 13) | `'warm` | `'general` | `'any-change` | `merge-set-union` | `(set)` |
| resolution-stratum-request (cell-id 14) | `'warm` | `'general` | `'any-change` | `merge-list-append` | `'()` |

No `:on-write-check` or `:on-read-check` (no inline gating). No direct-ref cache on prop-net-warm (not hot path yet). Forward-compatible: if benchmarking shows these become hot, can promote to `:tier 'hot` + add cache (4th+ instance of cross-track template pattern).

**Implementation**: adds `make-warm-general-meta` convenience constructor to `specialized-cells.rkt` (small extension following the existing `make-monotone-counter-meta` + `make-cold-general-meta` precedents). Both new cells allocate via `net-register-specialized-cell` in `make-prop-network` (post-fuel-cell registration).

**Resolution-stratum cell retires `current-ready-queue-cell-id` parameter**: per user direction (use specialized cells; don't expand PM 12 scope), the new well-known resolution-stratum-request cell SUBSUMES the per-command ready-queue cell's role. Sites that currently write `ready-queue` (the readiness propagators via `add-readiness-set-latch!`) migrate to write resolution-stratum-request. Single source of truth; small (1-parameter) PM 12 contribution directly tied to 2A's charter.

#### §8.7.4 Subtler finding — S(-1) timing semantic change

Under current sequential loop, S(-1) runs **BEFORE** S0 fires (pre-S0 cleanup):
```
loop: cleanup → S0 fires on cleaned state → L2 → ...
```

Under Phase 2A BSP outer-loop, S(-1) runs **AFTER** S0 quiescence (as value-tier handler):
```
outer-loop: S0 fires on potentially-stale state → S(-1) cleans → restart-from-outer-loop → S0 fires on cleaned state
```

The 2A model adds one "extra round" of S0 firing on pre-cleanup state per outer-loop iteration.

**Correctness analysis**: probably preserved via worldview-filtering of cell reads. `(net-cell-read net cid)` filters by `current-worldview-bitmask`; propagators firing under a worldview that excludes retracted assumption bits don't see stale entries. Stale entries exist in the cell but are invisible to correct-worldview reads. S(-1)'s subsequent cleanup removes them entirely (compaction, not correctness).

**Needs empirical verification** on retraction-heavy workloads — see drift risk #7-bis. Parity test axis "orchestration-parity" should explicitly cover retraction scenarios (speculative branch failure, contradiction-driven retraction).

**If verification surfaces real issues**: escalate to `#:priority` extension to `register-stratum-handler!` API (handlers within tier sorted by priority; S(-1) gets high priority for pre-everything execution within value-tier). Out of scope for 2A.0; revisit in 2A.c if needed.

#### §8.7.5 Drift risks (mid-implementation tripwires)

1. **Stale design references** — §8.3's `collect-ready-constraints-via-cells` reference. Resolved by §8.7 revisions; §8.3 marked superseded.
2. **L1 readiness already done** — design simplification (2 cells, not 3). Resolved.
3. **Per-command ready-queue retirement** — directly tied to 2A's charter. Acceptable per user guidance ("don't add legacy-shaped cells for PM 12").
4. **Handler iteration order** — module-load order (driver.rkt:37 before :45) naturally puts S(-1) + L2 before S1 NAF. Verified.
5. **Auto-clearing via `#:reset-value`** — BSP outer-loop calls `(net-cell-reset processed req-cid reset-val)` after handler. Handlers don't need to clear. Verified at propagator.rkt:3017.
6. **Outer-loop fuel** — BSP outer-loop has 20-round iteration bound (propagator.rkt:3033). Should be sufficient for elaboration workloads; verify via parity tests.
7. **`run-stratified-resolution-pure` callers** — line 1889 calls it from solve-meta-core!'s caller chain. After 2B retires it, the caller chain needs entry point that triggers BSP outer-loop directly. Mechanical migration.
8. **`record-assumption-retraction!`** at line 1476 currently writes to imperative state (box). Migration: writes to retraction-stratum-request cell via net-cell-write. Confirm all callers have net access.
9. **(7-bis) S(-1) timing semantic change** — under 2A, S(-1) runs post-S0 (was pre-S0). Worldview-filtering should preserve correctness; needs empirical verification on retraction-heavy workloads. Parity test axis covers this.
10. **Behavioral parity invariant** — handler behavior MUST be observationally equivalent to sequential orchestrator. Add to test-elaboration-parity.rkt orchestration-parity axis as 2A.c deliverable.

#### §8.7.6 Sub-phase partition

| Sub-phase | Scope | Est. LoC |
|---|---|---|
| **2A.0** | Precursor: allocate cell-ids 13 + 14 in `make-prop-network` with §4.6 framework declarations. Adds `make-warm-general-meta` to specialized-cells.rkt. NO BEHAVIOR CHANGE (cells exist but unused). Verifies suite GREEN unchanged. | ~30-50 |
| **2A.a** | Define `process-retraction` handler wrapping `run-retraction-stratum!` logic; register value-tier; migrate `record-assumption-retraction!` at line 1476 to write retraction-stratum-request cell instead of imperative state. | ~50-100 |
| **2A.b** | Define `process-resolution` handler wrapping for/fold + `resolution-executor` logic; register value-tier; migrate readiness propagators (`add-readiness-set-latch!`) to write resolution-stratum-request cell. Retire `current-ready-queue-cell-id` parameter. | ~80-150 |
| **2A.c** | Orchestration parity verification (probe + acceptance + full suite). Add orchestration-parity axis to `test-elaboration-parity.rkt` with retraction-heavy + composition test cases. Verify no regression vs 110.9s baseline. | ~50-100 (mostly test code) |

Estimated 2A total: **~210-400 LoC** across propagator.rkt + specialized-cells.rkt + metavar-store.rkt + resolution.rkt + tests. At the upper end of original §8.2 estimate (~75-125), reflecting the §4.6 framework declarations + ready-queue retirement adds.

#### §8.7.7 Mantra check (per word)

| Word | Verdict |
|---|---|
| All-at-once | ✓ All stratum handlers iterated in one BSP outer-loop pass per tier |
| All in parallel | ✓ Handlers can run in parallel within a tier (BSP scheduler decides); state coordinated via cells |
| Structurally emergent | ✓ Ordering from BSP outer-loop's stratum iteration + worklist progress detection; no imperative sequencing |
| Information flow | ✓ Through request cells (writes from propagators) → handlers (reads from cells) → back to network state |
| ON-NETWORK | ✓ All state in cells; handlers are pure functions `(net, pending) → net`; auto-clearing via BSP outer-loop reset |

#### §8.7.8 Principles in play

| Principle | How 2A serves it |
|---|---|
| Decomplection | Separates orchestration concern (BSP outer-loop) from resolution-step concern (handlers) |
| Propagator-First Infrastructure | Request cells + handlers replace imperative sequential calls |
| Correct by Construction | BSP outer-loop's auto-clear via `#:reset-value` makes request-cell-clearing structural, not discipline-maintained |
| Cell/Propagator/Scheduler Orthogonality | Cells declare framework properties (§4.6); handlers are propagator-layer; BSP outer-loop iteration is scheduler concern; clean separation |
| Specialized Cell Type Framework as Cross-Track Template | Follows §4.6 declarations on the 2 new cells; consistent with Phase 1 framework instances; adds `make-warm-general-meta` constructor (new pattern for cross-track use) |
| Stratified Propagator Networks | Concrete instantiation: elaborator's S(-1) + L2 join existing topology + S1-NAF + classify-inhabit strata; ONE unified mechanism across both networks |

### §8.7.a Phase 2A.a Mini-design + Mini-audit (2026-05-20)

Per Stage 4 Per-Phase Protocol: opening mini-design + mini-audit cycle for Phase 2A.a (process-retraction handler + record-assumption-retraction migration). Outcomes persist into this design doc per refined Stage 4 methodology.

Charter: register S(-1) retraction as BSP value-tier stratum handler; migrate `record-assumption-retraction!` from imperative box (`current-retracted-assumptions` parameter) to cell write (`retraction-stratum-request-cell-id`). Cell allocated in 2A.0 (`bf025224`).

#### §8.7.a.1 Pre-design audit: reader-audit for Option (d) viability

Initial mini-design proposed an Option (a) "box-bridge" handler — handler reads `current-prop-net-box` to access elab-net state (meta-info CHAMP + id-map) and writes back via `set-box!`. Adversarial principles framework challenge surfaced TWO violations: (1) handler reads off-network parameter (`current-prop-net-box`); (2) Cell/Propagator/Scheduler Orthogonality violated by parameter-touch at handler layer.

User-directed audit: investigate Option (d) — pure handler on prop-net (only scoped cells); defer meta-info + id-map retraction by relying on worldview-filtering at read time (the same pattern S2.e-iv-a established for mult/level/session universe cells).

**Audit method**: grep all raw consumers of `elab-network-meta-info` + `elab-network-id-map` struct accessors. Categorize by safety class.

**Categorization (grep-verified)**:

| Category | Sites | Verdict |
|---|---|---|
| SAFE-1 — Structural reflow (constructor pass-through) | elaborator-network.rkt:156, 237, 253; elab-speculation.rkt:107-108; unify.rkt:335-336, 386-387, 426-427; elab-network-types.rkt:119-164 | No migration needed |
| SAFE-2 — Inside worldview-aware reader impl | cell-ops.rkt:112, 118 | No migration needed |
| SAFE-3 — Raw read followed by explicit `worldview-visible?` check | metavar-store.rkt:1700 (uses `champ-lookup-worldview`); :1935-1948 (`solve-meta!`); :2004-2014 (`solve-meta-core-pure`) | Already worldview-aware at use |
| **UNSAFE — Bare `champ-lookup` without worldview filter** | metavar-store.rkt:2363 (`meta-info-solved?`); :2376 (`meta-lookup`); :2957 (`all-unsolved-metas`); :617-623, :764, :791, :963-971 (id-map readers in trait/hasmethod/unify paths) | **6 sites need migration to worldview-aware lookups** |
| WRITE-PATH — Read for `champ-insert` | metavar-store.rkt:1804, 1832, 2439, 2569, 2703 | Not a read concern; new writes tag with current worldview |
| CALLBACK-INSTALLER — STUB params | driver.rkt:2566, 2571 + metavar-store.rkt:1399, 1591 | **Pure dead code** — params explicitly labeled "STUB — no longer consulted" (Track 8 B2b retirement); ZERO production consumers |

**Memory bounds check**: `reset-meta-store!` (metavar-store.rkt:2827) line 2840 (`(set-box! mi-box champ-empty)`) + line 2852 (`(make-elaboration-network)` fresh enet on callback wire-up) confirms meta-info CHAMP + id-map reset per-command. Stale tagged entries from un-retracted speculations are bounded by one command's lifetime. Memory growth: negligible.

**Audit verdict**: Option (d) is viable with a small reader migration (~25 LoC across 6 UNSAFE sites). Alignment: post-S2.e-iv-a pattern (worldview-filtering at read time replaces explicit retraction). Sets up Parent Phase 4 cleanly (meta-info CHAMP + id-map → cells with tagged-cell-value; cell mechanism's native worldview filtering supersedes the explicit `worldview-visible?` checks).

#### §8.7.a.2 Architecture decision: Approach C (refined Option d) — pure handler + reader migration + dead-code retirement

Selected approach delivers handler with **ZERO scaffolding labels** at the new code surface. Adversarial mantra check + principles check ALL pass without violations.

**Trade-offs analyzed**:

| Aspect | Option (a) Box-bridge | Option (d) Pure handler + reader migration |
|---|---|---|
| Handler purity | Off-network bridge (`current-prop-net-box` + `set-box!`) | Pure on prop-net |
| Mantra/Principles | 2 violations (labeled scaffolding) | Zero violations |
| Retraction completeness | Full (scoped + meta-info + id-map) | Partial (scoped only; meta-info/id-map invisible via worldview-filtering) |
| Memory compaction | Yes | No (stale entries until Parent Phase 4); per-command bounded |
| Reader migration cost | None | ~25 LoC (6 sites) |
| Parent Phase 4 setup | Box-bridge dissolves later | CHAMP→cell promotion is the structural retirement |

#### §8.7.a.3 Deliverables

1. **`process-retraction` handler** in metavar-store.rkt — pure on prop-net; only scoped cells:

```racket
;; PPN 4C 2A.a (2026-05-20): S(-1) retraction stratum as BSP value-tier handler.
;; Registered on retraction-stratum-request-cell-id (cell 13).
;; Cell accumulates retracted assumption-ids via record-assumption-retraction
;; during with-speculative-rollback failures. BSP outer-loop processes between
;; rounds; cell auto-clears via #:reset-value (set). If retraction enqueues
;; worklist (via net-cell-replace cascades), BSP restarts S0.
;;
;; Architecture: pure on prop-net. Meta-info CHAMP + id-map retraction is
;; deferred to Parent Phase 4 (A2 CHAMP retirement) — worldview-filtering at
;; read time (the post-S2.e-iv-a pattern) makes stale tagged entries invisible.
;; Memory bounds: per-command reset via reset-meta-store!.
(define (process-retraction net retracted-set)
  (cond
    [(set-empty? retracted-set) net]
    [else
     (for/fold ([n net]) ([cid (in-list (scoped-cell-ids))])
       (define val (net-cell-read n cid))
       (cond
         [(not (hash? val)) n]
         [else
          (define cleaned
            (if (and (positive? (hash-count val))
                     (let ([sample (for/first ([(k v) (in-hash val)]) v)])
                       (list? sample)))
                (retract-hasheq-list-entries val retracted-set)
                (retract-hasheq-entries val retracted-set)))
          (if (equal? val cleaned) n (net-cell-replace n cid cleaned))]))]))

(register-stratum-handler! retraction-stratum-request-cell-id
                            process-retraction
                            #:tier 'value
                            #:reset-value (set))
```

2. **`record-assumption-retraction`** pure functional `(enet aid) → enet*` (no bang):

```racket
;; PPN 4C 2A.a (2026-05-20): writes assumption-id to retraction-stratum-request-cell-id.
;; Pure function — no off-network state touched. Caller commits via set-box!
;; at the existing imperative boundary (with-speculative-rollback's retract branch).
(define (record-assumption-retraction enet assumption-id)
  (cond
    [(not assumption-id) enet]
    [else
     (define pnet (elab-network-prop-net enet))
     (define pnet* (net-cell-write pnet retraction-stratum-request-cell-id
                                    (set assumption-id)))
     (elab-network-rewrap enet pnet*)]))
```

3. **Caller migration at elab-speculation-bridge.rkt:329** — direct functional call:

```racket
;; Before:
(record-assumption-retraction! hyp-id)

;; After — direct call + set-box! consolidated at existing speculation boundary
;; (the surrounding retract branch already touches box at lines 318, 327):
(when (and elab-net-box hyp-id)
  (set-box! elab-net-box
            (record-assumption-retraction (unbox elab-net-box) hyp-id)))
```

4. **6 reader migrations** — Category UNSAFE → worldview-aware lookups:

| Site | Migration |
|---|---|
| metavar-store.rkt:2359 (`meta-info-solved?`) | Use `elab-meta-info-read-worldview` instead of bare `champ-lookup` on `elab-network-meta-info` |
| metavar-store.rkt:2372 (`meta-lookup`) | Same pattern |
| metavar-store.rkt:2957 (`all-unsolved-metas`) | Same pattern |
| metavar-store.rkt:617 (trait dispatcher cell-id extract) | Use `elab-id-map-read-worldview` |
| metavar-store.rkt:764 (hasmethod cell-id extract) | Same pattern |
| metavar-store.rkt:791 (hasmethod cell-id extract) | Same pattern |
| metavar-store.rkt:963 (`add-unify-constraint` lhs/rhs cell-id extract) | Same pattern |

5. **Dead-code retirement** — STUB callbacks (~10 LoC deletion):
   - `current-prop-id-map-read` parameter + install (driver.rkt:2566, metavar-store.rkt:1591, provide block)
   - `current-prop-meta-info-read` parameter + install (driver.rkt:2571, metavar-store.rkt:1399, provide block)
   - Comments at metavar-store.rkt:1387, 1394, 1395, 1587, 1588 updated to reflect cleanup

6. **Test file migration** — `tests/test-retraction-stratum.rkt`:
   - Direct tests on `process-retraction` (handler logic correctness — set processing, cell reads/replaces)
   - Tests on `record-assumption-retraction` pure function (enet × aid → enet* semantics; cell observation via `net-cell-read`)
   - Retire box-based test scaffolding (parameterize `current-retracted-assumptions`); replace with cell-based scaffolding (allocate network, write to cell, observe)

7. **`retraction-parity` axis** in `tests/test-elaboration-parity.rkt` (integration-level):
   - Write aid via `record-assumption-retraction` → run quiescence → observe scoped cells cleaned
   - Verify pre-2A.a behavior preserved for representative workloads

8. **`current-retracted-assumptions` parameter + box + driver.rkt:467-468 init** — DEFERRED to 2B (alongside `run-stratified-resolution-pure` retirement; per discussion 2026-05-20).

#### §8.7.a.4 Scaffolding retirement targets — explicit captures

Per workflow.md "scaffolding with named retirement plan" discipline:

**Retiring in 2A.a (this phase)**:

| Item | Where in code | Reason |
|---|---|---|
| `current-prop-id-map-read` parameter | metavar-store.rkt:1591 (defn), driver.rkt:2566 (install), metavar-store.rkt:218 (provide) | STUB; zero production consumers post-Track-8-B2b |
| `current-prop-meta-info-read` parameter | metavar-store.rkt:1399 (defn), driver.rkt:2571 (install), metavar-store.rkt:170 (provide) | Same — STUB |

**Deferred to PPN 4C Addendum Phase 2B** (this addendum, §8.4):

| Item | Where in code | Retirement note |
|---|---|---|
| `current-retracted-assumptions` parameter + box | metavar-store.rkt:1473 | Becomes dead post-2A.a (no writers/readers); retire alongside `run-stratified-resolution-pure` orchestrator |
| driver.rkt:467-468 init block | driver.rkt | Same — dead per-command init |
| `run-retraction-stratum!` function (legacy box-reader) | metavar-store.rkt:1532 | No-op post-2A.a; retire with `run-stratified-resolution-pure` |

**Deferred to PPN 4C Parent Phase 4** (CHAMP retirement; parent design doc §2 tracker row "Phase 4"):

| Item | Where in code | Retirement note |
|---|---|---|
| `elab-network-meta-info` CHAMP struct field | elab-network-types.rkt | Promoted to cell with tagged-cell-value; native worldview filtering replaces explicit `worldview-visible?` checks at consumers |
| `elab-network-id-map` CHAMP struct field | elab-network-types.rkt | Same |
| Worldview-aware reader migration sites (6 from §8.7.a.3 item 4) | metavar-store.rkt | Become trivial cell reads; explicit `worldview-visible?` checks dissolve |

**Deferred to PM Track 12** (per `docs/tracking/2026-03-13_PROPAGATOR_MIGRATION_MASTER.md` Track 12 row):

| Item | Where in code | Retirement note |
|---|---|---|
| `current-prop-net-box` parameter | metavar-store.rkt + driver.rkt + callers | Parameter→cell module-loading migration; bridge dissolves |
| Scoped-cell-id parameters (constraint, trait-constraint, wakeup, etc.) | metavar-store.rkt | Same — parameter→registry-cell |
| `with-speculative-rollback`'s elab-net snapshot + set-box! | elab-speculation-bridge.rkt | Speculation infrastructure retires alongside meta-info CHAMP (Phase 4) + parameter retirement (PM 12) |

#### §8.7.a.5 Mantra check (adversarial three-column)

| Word | Catalogue | Adversarial challenge | Status |
|---|---|---|---|
| All-at-once | ✓ Set-union merge accumulates aids; handler processes set in one call | Could merge be more granular per-aid? No — set semantics already optimal for accumulation | ✓ Aligned |
| All in parallel | ✓ Handler invocations parallel via BSP; within-handler `for/fold` over scoped cells sequential | Could within-handler parallelize? Race on `net-cell-replace` (non-monotone). Sequential within-handler is correct. | ✓ Aligned |
| Structurally emergent | ✓ BSP stratum iteration; aid identified structurally via speculation's `hyp-id` | Could aid identification be more structural? hyp-id IS the assumption's structural identity. | ✓ Aligned |
| Information flow | ✓ Cell-write → handler-read; pure function takes enet returns enet* | Did we eliminate ALL parameter-based info flow in new code? Yes — handler reads `net` (BSP arg); `record-assumption-retraction` reads `enet` (caller arg). | ✓ Aligned |
| ON-NETWORK | ✓ All new code on-network | Did we add ANY off-network state? No — handler pure; pure record- function; reader migrations toward on-network filtering. Existing `set-box!` in caller is pre-existing speculation scaffolding (PM 12 + Phase 4 scope), not introduced. | ✓ Aligned |

#### §8.7.a.6 Principles check (adversarial three-column)

| Principle | Catalogue | Adversarial challenge | Status |
|---|---|---|---|
| Decomplection | ✓ Trigger/execution/storage decoupled (cell write / handler / scoped cells) | Could `record-assumption-retraction` split further? Over-engineering for 1-cell-write. | ✓ Aligned |
| Propagator-First Infrastructure | ✓ Imperative box-state → on-network cell | Did we leave ANY imperative paths in new code? No. Caller's box-touch is existing scaffolding, not new code. | ✓ Aligned |
| Correct by Construction | ✓ BSP auto-clear + pure function + worldview-aware reads | Are there discipline-maintained invariants? Auto-clear is structural; reader-migration toward worldview-aware filtering is structural pattern (post-S2.e-iv-a). | ✓ Aligned |
| Cell/Propagator/Scheduler Orthogonality | ✓ Handler is pure prop-net; cell on cell layer; BSP outer-loop is scheduler concern | Would handler work under Gauss-Seidel / Zig+LLVM? Pure function, cell-write portable. Zero scheduler-specific machinery. | ✓ Aligned |
| Stratified Propagator Networks | ✓ S(-1) joins existing strata | Could merge with another stratum? S(-1) has distinct (non-monotone) semantics; separate handler correct. | ✓ Aligned |
| Specialized Cell Type Framework as Cross-Track Template | ✓ Cell 13 uses §4.6 declarations (warm + general + any-change) — landed in 2A.0 | Could cell metadata be richer? `make-warm-general-meta` is the 4th template instance; framework holds up under usage. | ✓ Aligned |

#### §8.7.a.7 Drift risks (for mid-flight scrutiny)

1. **D1 — Pure function purity**: ensure `record-assumption-retraction` doesn't accidentally re-introduce `current-prop-net-box` touch in the body. Audit the implementation; the body should ONLY touch `enet` argument + `assumption-id` argument.
2. **D2 — Caller migration completeness**: only ONE production caller (elab-speculation-bridge.rkt:329). Test callers in test-retraction-stratum.rkt are scoped to test migration. No hidden callers (grep-verified).
3. **D3 — Reader migration completeness**: 6 sites identified in audit. Any additional UNSAFE sites discovered during implementation must be migrated atomically.
4. **D4 — STUB callback retirement**: provides/exports/installs/definitions must all be removed atomically; partial retirement (e.g., delete defn but leave install) would error.
5. **D5 — `(scoped-cell-ids)` correctness post-handler**: the function returns a list of cell-ids based on parameter values. Under the handler, these parameters must be set (per-command lifecycle via `reset-meta-store!`). If the handler is called in a context where parameters are unset (`#f`), `(scoped-cell-ids)` returns empty list — handler is no-op. SAFE (no error case).
6. **D6 — Test fixture handling**: test files using `parameterize current-retracted-assumptions` must migrate to cell-based fixtures. Risk: test file may reference scaffolding that changes; bulk-edit + careful read.
7. **D7 — Parity test coverage**: `retraction-parity` axis must cover at least: single retraction; multiple aids in one set; retraction after speculation; retraction triggers worklist enqueue (via `net-cell-replace` cascades).

#### §8.7.a.8 Coordination concern (verification item, not blocker)

`record-assumption-retraction` is called from `with-speculative-rollback`'s retract branch, which can run during BSP fire rounds (elaboration is propagator-driven post-Phase-4A). The cell-write goes through `elab-net-box`'s prop-net; BSP's intra-round `net` snapshot is a separate copy.

**This is the same coordination pattern with-speculative-rollback already uses for worldview-cache writes** (elab-speculation-bridge.rkt:326). It works in production. Our retraction cell-write follows the same path. Parity tests verify the integration (write aid → run quiescence → observe scoped cells cleaned).

If parity tests reveal coordination issues, the resolution surfaces at test time. Existing speculation-bridge scaffolding is already labeled with retirement plan (Parent Phase 4 + PM 12); any coordination fix would land alongside that retirement.

#### §8.7.a.9 Sub-steps + completion criteria

| Step | Deliverable | Est. LoC |
|---|---|---|
| 1 | Add `process-retraction` handler + `register-stratum-handler!` call (metavar-store.rkt) | ~35 |
| 2 | Add `record-assumption-retraction` pure function (metavar-store.rkt) + update provides | ~12 |
| 3 | Migrate caller at elab-speculation-bridge.rkt:329 | ~3 |
| 4 | Migrate 6 reader sites (metavar-store.rkt) to worldview-aware lookups | ~25 |
| 5 | Retire STUB callbacks (driver.rkt + metavar-store.rkt) | ~10 (delete) |
| 6 | Migrate `tests/test-retraction-stratum.rkt` (both `process-retraction` direct + `record-assumption-retraction` API surface tests) | ~75-125 |
| 7 | Add `retraction-parity` axis to `tests/test-elaboration-parity.rkt` | ~25 |
| 8 | Validation: delimiter check + targeted tests + probe + acceptance + full suite | — |
| 9 | Commit + tracker update + dailies entry per phase-completion protocol | — |

**Total LoC**: ~178-228 (with test migration the largest component).

**Completion criteria**:
- Probe diff = 0 (semantic identical to baseline)
- Acceptance file 0 errors
- `tests/test-retraction-stratum.rkt` GREEN with migrated assertions
- `retraction-parity` axis GREEN
- Full suite: 8224 tests / ≤110.9s (pre-2A.0 baseline) / 0 failures
- Adversarial mantra check + principles check all pass
- Tracker row 2A.a marked ✅ with commit hash + key result
- Dailies entry per phase-completion protocol

#### §8.7.a.10 Codifications captured during this mini-design

- **Adversarial three-column framing at every mini-design + mini-audit** (not just VAG gate close): catalogue / challenge / status. Catalogue is rationalization; challenge is where drift surfaces. Codification candidate (1 data point this session, watching for next instance): "The adversarial framing must be actively forced at EVERY application of P/R/M/S — Stage 4 mini-design, mini-audit, mid-flight principles challenge, VAG. The catalogue→challenge transition is NEVER natural; without explicit two-column or three-column discipline, the gate catalogues and misses drift."
- **STUB-labeled dead code IS code smell** (Track 8 B2b STUB parameters survived since the callback retirement): "Each pass that touches a file should leave it cleaner than it found it. STUB labels with no consumers should be retired when the next touching pass occurs, not left as inertia." Watching-list candidate.
- **Pure functional API beats imperative-bang API** when state is on-network: `record-assumption-retraction` (no bang) is more aligned than `record-assumption-retraction!` (with bang implying box mutation). The pure function lets callers commit at their existing imperative boundaries.

### §8.7.b Phase 2A.b Mini-design + Mini-audit (2026-05-20)

Per Stage 4 Per-Phase Protocol: opening mini-design + mini-audit cycle for Phase 2A.b (`process-resolution` handler + `add-readiness-set-latch!` migration + `current-ready-queue-cell-id` parameter retirement). Outcomes persist into this design doc per refined Stage 4 methodology.

Charter: register L2 resolution as BSP value-tier stratum handler on `resolution-stratum-request-cell-id` (cell 14, allocated in 2A.0); migrate readiness propagators to write cell-14 instead of `ready-queue` parameter cell; retire `current-ready-queue-cell-id` parameter (small PM 12 contribution directly tied to 2A's charter per §8.7.3).

#### §8.7.b.1 Architectural reframing: handler approach surfaces as scaffolding concern

During mini-design dialogue 2026-05-20, user-direction surfaced a **deeper architectural concern about the handler approach itself** (not specific to 2A.b — affects all 7+ shipped/proposed stratum handlers including 2A.a's `process-retraction`). The concern: handlers/scaffolding hiding behavior; side-effecting nature inside handler bodies; the `stratum-handlers` box at `propagator.rkt:2827` is off-network.

**Operational principle crystallized**:
> *"Anything that is not on-network is scaffolding."*

This is the mantra in its sharpest form. Off-network ≡ scaffolding by definition; every off-network mechanism is a retirement candidate with an explicit retirement plan attached.

**Two distinct levels of concern** identified:

1. **Handler body side-effects** — `current-prop-net-box` read + `current-resolution-executor-pure` read + `set-box! net-box` mutation inside handler. **Structural until PPN 4C Parent Phase 4 + PM Track 12 land** — actions inherently touch enet state.
2. **Handler registration/invocation mechanism** — `stratum-handlers` box + BSP outer-loop's imperative dispatch. **Separate architectural concern**; affects ALL 7+ handlers (4 topology + classify-inhabit + S1 NAF + process-retraction (2A.a) + process-resolution (2A.b)).

**Decision**: 2A.b proceeds with handler approach (Option A from dialogue) — matches established prior art (6 existing handlers + 2A.a's process-retraction shipped this week); completes Phase 2 charter (orchestration unification: BSP outer-loop iterates registered handlers); introducing a different mechanism mid-charter would create heterogeneity within the addendum.

**Level 2 concern captured as NEW PM Track 13** — Stratum-Handler Mechanism + Scheduler State as On-Network Cells. See [`2026-05-20_PM_TRACK13_IMPLEMENTATION_NOTE.md`](2026-05-20_PM_TRACK13_IMPLEMENTATION_NOTE.md) (Stage 0 SEED note; pending Stage 1 research). Track 13 row added to PM Master.

**Level 1 concern (body side-effects) captured back into PPN 4C Parent Design Doc Phase 4 row** — see [`2026-04-17_PPN_TRACK4C_DESIGN.md`](2026-04-17_PPN_TRACK4C_DESIGN.md) §2 row "Phase 4" item (viii). The handler's box-bridge pattern is the same scaffolding as `with-speculative-rollback`; same Phase 4 (CHAMP→cell) + PM 12 (parameter→cell) retirement path.

#### §8.7.b.2 Mini-audit findings (codebase grounding)

**Affected sites** (grep-verified 2026-05-20):

| Site | File:Line | Role | Migration |
|---|---|---|---|
| `add-readiness-set-latch!` rq-cid lookup | metavar-store.rkt:443 + threshold write at :565 | Writes latch threshold output to ready-queue | Change `rq-cid` from `(current-ready-queue-cell-id)` → well-known `resolution-stratum-request-cell-id` |
| `read-ready-queue-actions` rq-cid lookup | metavar-store.rkt:2245 | Reads tagged-entry-wrapped actions; consumer of L1/L2 in `run-stratified-resolution-pure` | Change `rq-cid` similarly. Becomes effectively no-op post-2A.b (handler drains during BSP); 2B retires entirely. |
| `current-ready-queue-cell-id` parameter | metavar-store.rkt:1706 (defn) + :1370 (with-fresh-meta-env reset) + :2967 (reset-meta-store! allocation) + :221 (provide) + batch-worker.rkt:259 (test scaffolding) | Per-command cell-id holder | **RETIRE** entirely (well-known cell-14 replaces) |
| `test-readiness-propagator.rkt` | :271, :281, :307, :316 (5 sites) | Tests directly reference `current-ready-queue-cell-id` | Migrate to cell-14 reads |

**Action shape preserved** (per §7.5.12.9 step 5):
- `add-readiness-set-latch!` writes `(list (tagged-entry (action-thunk) aid))` to rq-cid
- merge: list-append accumulates across multiple latches
- `read-ready-queue-actions` unwraps tagged-entries before dispatch
- Cell-14 uses same shape: list-append merge + initial `'()` (per `resolution-stratum-merge` at propagator.rkt:699-704)

**Executor parameters audit**:
- `current-resolution-executor` (metavar-store.rkt:1145) — imperative `(action) → void`; used by `execute-resolution-actions!` (line 1151) called only from `run-stratified-resolution!` (line 2174, dead code path per checkpoint)
- `current-resolution-executor-pure` (metavar-store.rkt:1148) — pure `(enet × action) → enet*`; used by `run-stratified-resolution-pure` line 2229 (production path)
- Both installed at driver.rkt:2705 + 2707

**`resolution-execute-action-pure` signature** (resolution.rkt:286): `(enet × action) → enet*`. Fundamentally operates on **elab-network** (calls `read-constraint-by-cid-pure`, `write-constraint-to-store-pure`, `retry-unify-constraint-pure`, `resolve-trait-constraint-pure`, `resolve-hasmethod-constraint-pure`, `solve-meta-core-pure`). All touch enet state.

**Per-command lifecycle preservation**: ready-queue is per-command (allocated in reset-meta-store!). Cell-14 is network-wide. `reset-meta-store!` creates fresh elab-network on each command via `(make-elaboration-network)` → fresh prop-net → cell-14 initialized to `'()`. **Per-command semantic preserved structurally** ✓.

#### §8.7.b.3 Architectural honesty — 2A.b CANNOT achieve zero-scaffolding cut

2A.a's `process-retraction` was pure on prop-net via Option (d) — scoped-cell retraction operates entirely on prop-net cells; meta-info + id-map CHAMP retraction deferred to Parent Phase 4 via worldview-filtering. **2A.b cannot replicate this**: actions invoke `resolution-execute-action-pure (enet × action) → enet*` — fundamentally needs enet access (meta-info CHAMP, id-map, scoped cells via solve-meta-core-pure).

The box-bridge is required scaffolding for this phase, labeled with explicit retirement to **Parent Phase 4** (CHAMP→cell promotion dissolves enet/pnet boundary; the handler's `(elab-network-rewrap (unbox net-box) net)` + `set-box! net-box enet*` pattern dissolves) + **PM Track 12** (parameter→cell module loading retires `current-prop-net-box` + `current-resolution-executor-pure` parameter reads).

#### §8.7.b.4 Deliverables

1. **`process-resolution` handler** in metavar-store.rkt:

```racket
;; PPN 4C 2A.b (2026-05-20): L2 resolution stratum as BSP value-tier handler.
;; Registered on resolution-stratum-request-cell-id (cell 14). Reads
;; tagged-entry-wrapped action descriptors written by readiness propagators
;; (via add-readiness-set-latch! migrated to write cell-14); invokes pure
;; resolution executor (current-resolution-executor-pure) on each action;
;; BSP outer-loop auto-clears cell to '() via #:reset-value after handler.
;; If actions cascade more S0 work (e.g., solve-meta cascade), BSP outer-loop's
;; restart-from-outer-loop fires S0 → readiness latches → cell-14 fills again.
;;
;; Scaffolding: box-bridge via current-prop-net-box + current-resolution-executor-pure
;; parameter. Box-bridge labeled scaffolding for Parent Phase 4 (CHAMP→cell)
;; + PM Track 12 (parameter→cell). Cannot be retired in 2A.b because
;; resolution-execute-action-pure fundamentally operates on elab-network
;; (meta-info CHAMP, id-map, scoped cells).
;;
;; Handler approach itself surfaced as architectural concern during 2A.b
;; mini-design (2026-05-20); captured as PM Master Track 13 for separate
;; research + design cycle. See §8.7.b.1 + PM 13 implementation note.
;;
;; See D.3 §8.7.b for full mini-design + audit (incl. architectural-honesty
;; trade-off vs 2A.a's pure handler).
(define (process-resolution net pending-actions)
  (cond
    [(null? pending-actions) net]
    [else
     (define net-box (current-prop-net-box))
     (define executor (current-resolution-executor-pure))
     (cond
       [(or (not net-box) (not executor)) net]
       [else
        ;; Rewrap elab-net with BSP's net so executor's writes cascade on it
        (define enet (elab-network-rewrap (unbox net-box) net))
        ;; Unwrap tagged-entry actions; thread enet through for/fold
        (define enet*
          (for/fold ([e enet]) ([entry (in-list pending-actions)])
            (define action (if (tagged-entry? entry) (tagged-entry-value entry) entry))
            (executor e action)))
        ;; Update box for elab-net side consumers; return updated prop-net
        (set-box! net-box enet*)
        (elab-network-prop-net enet*)])]))

(register-stratum-handler! resolution-stratum-request-cell-id
                            process-resolution
                            #:tier 'value
                            #:reset-value '())
```

2. **`add-readiness-set-latch!` rq-cid migration** — change line 443 from `(define rq-cid (current-ready-queue-cell-id))` to `(define rq-cid resolution-stratum-request-cell-id)`. Threshold write at line 565 unchanged (same shape).

3. **`read-ready-queue-actions` rq-cid migration** — change line 2245 similarly. Function becomes effectively no-op post-2A.b (cell drained by handler before this reads); 2B retires entirely with `run-stratified-resolution-pure`.

4. **`current-ready-queue-cell-id` parameter RETIREMENT**:
   - Delete parameter definition (metavar-store.rkt:1706)
   - Delete `with-fresh-meta-env` reset binding (metavar-store.rkt:1370)
   - Delete per-command allocation in `reset-meta-store!` (metavar-store.rkt:2967)
   - Delete provide (metavar-store.rkt:221)
   - Delete `batch-worker.rkt:259` parameterize binding
   - Delete `test-readiness-propagator.rkt` direct references (5 sites) — migrate to cell-14 reads

5. **`test-readiness-propagator.rkt` migration** — ~25-40 LoC across 5 test sites; mirror 2A.a's test migration approach (test against `resolution-stratum-request-cell-id` reads instead of `current-ready-queue-cell-id` parameter).

6. **`resolution-parity` axis** in `test-elaboration-parity.rkt` — 2-3 live integration smoke tests verifying readiness latch → cell-14 → handler → execution end-to-end.

7. **Driver-side `current-retracted-assumptions` parameter init** (driver.rkt:467-468) — STILL DEFERRED to 2B (per Q3 in 2A.a dialogue; alongside `run-stratified-resolution-pure` retirement).

#### §8.7.b.5 Scaffolding retirement targets — explicit captures

Per workflow.md "scaffolding with named retirement plan" discipline + user direction 2026-05-20 ("Any retirement work that is put on PPN 4C Parent Phase 4, should be captured back into the Parent Design document"):

**Retiring in 2A.b (this phase)**:

| Item | Where in code | Reason |
|---|---|---|
| `current-ready-queue-cell-id` parameter + per-command alloc + provides + with-fresh-meta-env binding + batch-worker.rkt:259 binding | metavar-store.rkt:1706, 1370, 2967, 221 + batch-worker.rkt:259 | Per-command cell replaced by well-known cell-14 (small PM 12 contribution directly tied to 2A's charter; § §8.7.3 user-direction "don't add legacy-shaped cells for PM 12 to migrate") |

**Deferred to PPN 4C Addendum Phase 2B** (per §8.4):

| Item | Where in code | Retirement note |
|---|---|---|
| `read-ready-queue-actions` function | metavar-store.rkt:2244 | Becomes no-op post-handler-drain; retire alongside `run-stratified-resolution-pure` orchestrator |
| `current-resolution-executor` imperative parameter + `execute-resolution-actions!` | metavar-store.rkt:1145 + :1151 | Only used by dead `run-stratified-resolution!` path; retire with orchestrator |
| `run-stratified-resolution-pure` orchestrator | metavar-store.rkt:2200 | Replaced by BSP outer-loop's value-tier iteration (handlers from 2A.a + 2A.b) |

**Deferred to PPN 4C Parent Phase 4** (CHAMP retirement; **captured back into parent design doc §2 row "Phase 4" item (viii)** per user direction 2026-05-20):

| Item | Where in code | Retirement note |
|---|---|---|
| `set-box! net-box enet*` in handler body | new code (this phase) | Bridge dissolves post-CHAMP-promotion; enet/pnet boundary becomes single cell-network |
| `(elab-network-rewrap (unbox net-box) net)` pattern | new code | Same — rewrap pattern unnecessary when meta-info + id-map are cells |

**Deferred to PM Track 12** (per `docs/tracking/2026-03-13_PROPAGATOR_MIGRATION_MASTER.md` Track 12 row):

| Item | Where in code | Retirement note |
|---|---|---|
| `current-prop-net-box` parameter read in handler | new code (this phase) | Parameter→cell migration retires the box-bridge |
| `current-resolution-executor-pure` parameter read in handler | new code (this phase) | Parameter→cell migration (or PPN 4C Parent Phase 4 if executor migrates with CHAMP retirement — TBD per PM 12/Phase 4 mini-design coordination) |

**Captured for PM Track 13** (NEW track, added 2026-05-20 — see [`2026-05-20_PM_TRACK13_IMPLEMENTATION_NOTE.md`](2026-05-20_PM_TRACK13_IMPLEMENTATION_NOTE.md)):

| Item | Where in code | Retirement note |
|---|---|---|
| `stratum-handlers` box | propagator.rkt:2827 | Off-network registry. Affects ALL 7+ handlers (4 topology + classify-inhabit + S1 NAF + process-retraction + process-resolution). Stage 0 SEED; pending Stage 1 research. |
| `register-stratum-handler!` imperative API | propagator.rkt:2829 | Becomes functional cell-write after PM 13 migration |
| BSP outer-loop's imperative handler dispatch | propagator.rkt:3061 | Reads registry cell instead of box after PM 13 |
| Handler-as-procedure vs handler-as-data design question | architectural | Stage 1 research decides (Option α: opaque procedure in cell; Option β: declarative transition graph) |

#### §8.7.b.6 Mantra check (adversarial three-column)

| Word | Catalogue | Adversarial challenge | Status |
|---|---|---|---|
| All-at-once | ✓ Cell-14 accumulates ALL ready actions via list-append merge | Could merge be more structured? List-append preserves ORDER which may matter for resolution sequencing. Genuine. | ✓ |
| All in parallel | ✓ Readiness latches fire in parallel during S0; handler executes via for/fold | Could handler EXECUTE actions in parallel? Actions touch enet state (solve-meta cascades); sequential is existing semantic; parallel would race. Sequential within-handler is correct. | ✓ |
| Structurally emergent | ✓ Cell-14's non-empty state IS readiness signal; BSP value-tier iteration drives handler | Are we keeping any imperative pull-from-queue pattern? `read-ready-queue-actions` in `run-stratified-resolution-pure` stays — but reads empty cell-14 post-handler-drain → no-op. NOT a parallel-mechanism violation. | ✓ |
| Information flow | ✓ Cell write → handler read → executor invocation → cell writes cascade | **VIOLATION**: handler reads `current-prop-net-box` parameter (PM 12 scope); handler reads `current-resolution-executor-pure` parameter (PM 12 scope); handler `set-box!`-es elab-net (Parent Phase 4 scope). **Labeled scaffolding; captured in §8.7.b.5 retirement table + Parent Design Doc §2 row "Phase 4" item (viii).** | ◐ |
| ON-NETWORK | ✓ Cell-14 on-network; per-command parameter retires | **VIOLATION**: box-bridge for enet state coupling — UNAVOIDABLE because actions touch elab-net. Same scaffolding pattern as `with-speculative-rollback`. Labeled scaffolding with explicit Parent Phase 4 + PM 12 retirement. Additional MECHANISM concern (handlers themselves as scaffolding) captured as PM 13 (new). | ◐ |

**Honest verdict**: 2 mantra word VIOLATIONS, both labeled scaffolding with explicit retirement plans (Parent Phase 4 + PM 12). This is structural — 2A.b's mechanism inherently bridges to elab-net until those phases land. **The deeper handler-mechanism concern is captured as PM 13** (separate track; doesn't gate 2A.b).

#### §8.7.b.7 Principles check (adversarial three-column)

| Principle | Catalogue | Adversarial challenge | Status |
|---|---|---|---|
| Stratified Propagator Networks | ✓ L2 resolution joins existing BSP value-tier strata | Genuinely aligned. | ✓ |
| Correct by Construction | ✓ BSP auto-clear via `#:reset-value '()` is structural | Cell-clear is structural; box-bridge `set-box!` is discipline-maintained. Acknowledged scaffolding. | ◐ |
| Cell/Propagator/Scheduler Orthogonality | ✓ Cell + handler + scheduler clean at boundary | **VIOLATION**: handler reads off-network parameters (current-prop-net-box, current-resolution-executor-pure). Would NOT survive a scheduler that doesn't run on Racket parameters (e.g., Zig+LLVM lowering). Labeled Parent Phase 4 + PM 12 + PM 13 scope. | ◐ |
| Decomplection | ✓ Trigger (readiness latch) / accumulation (cell) / execution (handler) decoupled | Genuinely aligned. | ✓ |
| Propagator-First Infrastructure | ✓ Cell replaces per-command parameter (ready-queue → cell-14) | Box-bridge in handler retains off-network coupling for executor + enet access. Acknowledged. | ◐ |

**Honest verdict**: 2A.b's handler has **acknowledged scaffolding violations** that 2A.a's didn't. The violations are STRUCTURAL — actions touch enet; until Parent Phase 4 + PM 12 + PM 13 land, the box-bridge is required. Labeling these with explicit retirement paths is the honest framing.

#### §8.7.b.8 Drift risks

1. **D1 — Action duplicate execution**: process-resolution drains cell-14 inside BSP value-tier; `run-stratified-resolution-pure`'s L1 reads AFTER BSP returns. Cell-14 should be EMPTY at that point (BSP auto-clears via `#:reset-value '()`). Verify: parity test exercises both paths to confirm no double execution.
2. **D2 — Empty `pending-actions` short-circuit**: handler returns net unchanged (eq?) if pending list is empty. Confirmed in design.
3. **D3 — Tagged-entry shape preservation**: cell-14 value is list of tagged-entries (per add-readiness-set-latch! threshold write at line 565); handler unwraps before passing to executor. Mirrors `read-ready-queue-actions` behavior.
4. **D4 — Executor parameter race**: handler reads `current-resolution-executor-pure` at fire time. If not installed (test contexts), handler is no-op. Same pattern as `execute-resolution-actions!` (line 1151-1155).
5. **D5 — Reader/writer site coordination**: `add-readiness-set-latch!` writes cell-14; `read-ready-queue-actions` reads cell-14; both migrate atomically in same commit.
6. **D6 — Test impact**: `test-readiness-propagator.rkt` directly references `current-ready-queue-cell-id` (5 sites). Migration to cell-14 reads required.
7. **D7 — Per-command cell init**: BSP auto-clear handles inter-round; per-command init via `(make-elaboration-network)` in reset-meta-store! creates fresh prop-net with cell-14 = `'()`. Structurally preserved ✓.
8. **D8 — Coordination with S(-1) retraction (2A.a)**: process-retraction registered value-tier in 2A.a; process-resolution registers value-tier in 2A.b. Module load order: metavar-store loads before relations — value-tier iteration order = [S(-1) retraction, L2 resolution, S1 NAF, classify-inhabit]. Confirm correctness preserved (S(-1)'s POST-S0 timing is §8.7.4 drift risk addressed in 2A.c).

#### §8.7.b.9 Sub-steps + LoC estimate

| Step | Deliverable | Est. LoC |
|---|---|---|
| 1 | Add `process-resolution` handler + `register-stratum-handler!` call (metavar-store.rkt) | ~30 |
| 2 | Migrate `add-readiness-set-latch!` rq-cid lookup (metavar-store.rkt:443) | ~5 |
| 3 | Migrate `read-ready-queue-actions` rq-cid lookup (metavar-store.rkt:2245) | ~3 |
| 4 | Retire `current-ready-queue-cell-id` parameter + provide + per-command alloc + with-fresh-meta-env reset + batch-worker.rkt:259 | ~15 (deletions) |
| 5 | Migrate `test-readiness-propagator.rkt` (~5 sites) | ~25-40 |
| 6 | Add `resolution-parity` axis to test-elaboration-parity.rkt | ~15 |
| 7 | Validation: delimiter + raco make + targeted + probe + acceptance + full suite | — |
| 8 | Commit + tracker + dailies | — |

**Total: ~95-110 LoC** (within §8.7.6 estimate of 80-150).

#### §8.7.b.10 Completion criteria

- Probe diff = 0 (semantic identical to baseline 8228/109.1s)
- Acceptance file 0 errors
- `test-readiness-propagator.rkt` GREEN with migrated assertions
- `resolution-parity` axis GREEN
- Full suite: 8228+ tests / ≤110.9s / 0 failures
- Adversarial mantra check + principles check applied with three-column framing
- Tracker row 2A.b marked ✅ with commit hash + key result
- Dailies entry per phase-completion protocol

#### §8.7.b.11 Codifications captured during this mini-design

- **Operational principle codified**: "Anything that is not on-network is scaffolding." Off-network ≡ scaffolding; every off-network mechanism is a retirement candidate. This is the mantra in its sharpest form. Candidate for `.claude/rules/on-network.md` codification after PM 13 research validates the framing (3+ data points: PPN 4C box-bridges, PM 12 parameter snapshots, PM 13 handler registry).
- **Compiler-technology framing for propagator networks + scheduler**: networks are first-class IR (per SH Series Track 1's `.pnet`); scheduler is interpreter; specialized cell type framework is IR vocabulary. Scheduler state (registry, worklist, fuel) should be IR-native, not Racket-box bookkeeping. Captured in PM 13 implementation note.
- **Retirement-target capture discipline**: per user direction 2026-05-20, retirement work assigned to Parent Phase 4 must be captured back into the Parent Design Document's Phase 4 row (so that Phase 4's mini-design absorbs the scope items). Applied retroactively to 2A.a retirements + prospectively to 2A.b. Codification candidate (1 data point, watching).

#### §8.7.b.12 Cross-track references

- **PM Master Track 13** — [`2026-05-20_PM_TRACK13_IMPLEMENTATION_NOTE.md`](2026-05-20_PM_TRACK13_IMPLEMENTATION_NOTE.md): NEW PM track capturing handler-mechanism architectural concern. Stage 0 SEED; pending Stage 1 research.
- **PPN 4C Parent Design Doc** — [`2026-04-17_PPN_TRACK4C_DESIGN.md`](2026-04-17_PPN_TRACK4C_DESIGN.md) §2 row "Phase 4" item (viii): 2A.b's box-bridge body side-effects captured here as Phase 4 scope items.
- **PM Master Track 12** — parameter→cell migration; absorbs `current-prop-net-box` + `current-resolution-executor-pure` parameter retirements.

### §8.7.c Phase 2A.c Mini-design + Mini-audit (2026-05-20)

Per Stage 4 Per-Phase Protocol: opening mini-design + mini-audit cycle for Phase 2A.c (orchestration parity verification + critical §8.7.4 retraction-heavy empirical test). Outcomes persist into this design doc.

Charter: validate that the BSP outer-loop's value-tier orchestration (2A.a's `process-retraction` + 2A.b's `process-resolution`) is observationally equivalent to the pre-2A sequential orchestrator (`run-stratified-resolution-pure`) for retraction-heavy workloads. The empirical test is the falsification gate for §8.7.4's "S(-1) runs POST-S0" timing concern.

#### §8.7.c.1 The semantic change to verify

Per §8.7.4 + drift risk #9: under 2A, S(-1) retraction runs AFTER S0 quiescence (as value-tier handler), not BEFORE S0 (as the sequential loop did). The 2A model adds one "extra round" of S0 firing on pre-cleanup state per outer-loop iteration.

Correctness argument (§8.7.4): worldview-filtering at `net-cell-read` should hide stale entries from propagators firing under a retracted assumption bitmask. S(-1)'s cleanup is COMPACTION (not correctness). Empirical verification on retraction-heavy workloads is the load-bearing check.

#### §8.7.c.2 Mini-audit findings (codebase grounding)

**Production callers of `with-speculative-rollback`** (the speculation trigger):
- `qtt.rkt:2329` — union checkQ left branch
- `typing-core.rkt:2385` — union check left branch (THE canonical retraction trigger)
- `typing-core.rkt:1307` + `:1344` — checking-context variants (map-related, narrower scope)
- `typing-errors.rkt:78` — error handler speculation

**Existing retraction test coverage**:
- `test-retraction-stratum.rkt` — unit-level mechanism (record-assumption-retraction + process-retraction + tagged-entry primitives). Comprehensive at unit level. Does NOT exercise post-S0 timing because tests directly invoke handler on prop-net.
- `retraction-parity` axis (test-elaboration-parity.rkt:228-272, added 2A.a) — BASELINE-only smoke (arithmetic, polymorphic, type annotation). Doesn't trigger retraction.
- `test-punify-integration.rkt:228` — `(ns t) (def x : <Int | Bool> := "hello")` exercises contradiction-driven retraction (both branches fail). Uses local `run-last` helper.

**Retraction-triggering workload pattern** (from test-punify-integration precedent): `"(ns t) (def x : <Type | Type> := value) x"`. `(ns t)` bootstraps namespace context + prelude. `def x : <T1 | T2> := value` triggers `check ctx value (expr-union T1 T2)` → `with-speculative-rollback` tries T1, on failure retracts hyp-id and tries T2.

**`run-ns-last` harness compatibility**: needs verification that `(ns t)` bootstrap works in the parity harness. `process-string` (used by `run-ns-last`) processes multi-form input. The `<Int | String>` syntax reads as `($angle-type Int $pipe String)` in sexp mode (per test-sexp-reader-parity:105-107); preparse converts to `expr-union`.

#### §8.7.c.3 Deliverables

1. **`orchestration-parity` axis** in `test-elaboration-parity.rkt` — distinct from `retraction-parity` (baseline-only smoke) and `resolution-parity` (baseline). Targets the post-S0 timing semantic specifically.

2. **Test cases** (mirror existing axis style):
   - `orchestration-union-no-retraction` — `(ns t) (def x : <Int | String> := 42) x` — Int branch succeeds first, no retraction. Baseline confirmation that union check path works under 2A.
   - `orchestration-union-with-retraction` — `(ns t) (def x : <Int | String> := "hello") x` — **THE FALSIFICATION CASE for §8.7.4**: Int branch fails → `with-speculative-rollback` invokes `record-assumption-retraction` (writes to cell-13) → BSP outer-loop's value-tier processes S(-1) AFTER S0 quiescence → restart-from-outer-loop → S0 fires again with retracted bits filtered out → String branch succeeds. If worldview-filtering doesn't hide stale entries from the failed Int branch, String branch elaboration could pick up contaminating type information OR get wrong type.
   - `orchestration-union-flipped-with-retraction` — `(ns t) (def x : <String | Int> := 42) x` — same as above but with String branch first; verifies the retraction path doesn't have a left/right asymmetry.

3. **Fallback if `(ns t)` pattern doesn't work in `run-ns-last`** (analogous to 2A.b's parity harness reframing): drop to baseline cases + add falsification-coverage NOTE pointing to `test-punify-integration.rkt:228` (existing retraction-driven contradiction test in different harness).

#### §8.7.c.4 Scaffolding retirement targets

None NEW for 2A.c. All scaffolding inherited from 2A.a/b already captured. 2A.c is verification-only (no production code changes beyond test additions).

#### §8.7.c.5 Mantra check (adversarial three-column)

| Word | Catalogue | Challenge | Adversarial |
|---|---|---|---|
| All-at-once | ✓ Parity tests exercise the BSP outer-loop's "all stratum-handlers iterated in one pass" property | Could axis test more strata simultaneously? | **What if one stratum handler's writes get clobbered by another's reset in the same outer-loop iteration?** D8 (2A.b's coordination concern) names module-load order [S(-1) retraction, L2 resolution, S1 NAF, classify-inhabit]. Worth a specific test asserting both retraction AND resolution can fire in same outer-loop iteration without interference. Not in 2A.c scope — separate stratification concern. |
| All in parallel | N/A (parity = correctness check, not parallelism check) | — | — |
| Structurally emergent | ✓ Parity verifies emergent ordering preserves semantics vs imposed sequential | — | — |
| Information flow | ✓ Test asserts post-elaboration result preserves correct flow through the value-tier handlers | — | — |
| ON-NETWORK | ✓ All retraction state in cell-13; speculation via worldview-tagged writes | — | — |

#### §8.7.c.6 Principles check (adversarial three-column)

| Principle | Catalogue | Challenge | Adversarial |
|---|---|---|---|
| Correct by Construction | ✓ Parity tests are structural regression gates | Tests as RUNTIME checks, not STATIC structural property | **Is there a structural property of the BSP outer-loop that makes the post-S0 timing provably equivalent to pre-S0?** Worldview-filtering at read-time is the structural argument. A property test (not a unit test) would verify the invariant "any read at worldview W ignores entries tagged with retracted bits in W" — that's the load-bearing property. Out of 2A.c scope (would require dedicated property-test infrastructure); empirical workload tests are sufficient confidence here. |
| Stratified Propagator Networks | ✓ Tests exercise the stratification mechanism via real Prologos expressions | — | — |
| Cell/Propagator/Scheduler Orthogonality | ✓ Tests don't couple to specific scheduler (BSP outer-loop is one implementation; same network would work under Gauss-Seidel) | — | — |

#### §8.7.c.7 Drift risks

1. **D1 — `(ns t)` bootstrap may not work in `run-ns-last`**: harness sets `current-ns-context #f` and `current-prelude-env (hasheq)`. The `(ns t)` form should trigger namespace setup but needs empirical verification. **Mitigation**: if tests fail with "unbound" errors, fall back to baseline-only axis + falsification-coverage NOTE pointing to `test-punify-integration.rkt:228` (existing run-last harness that DOES bootstrap correctly).
2. **D2 — Multi-form parsing**: `process-string` claims to process ALL forms but `run-ns-last` returns LAST result. Verify that the final `x` expression's type/value comes through correctly.
3. **D3 — Pretty-print of `<Int | String>`**: output format may use `[Int | String]` brackets vs `<Int | String>` angle. Use `string-contains?` substring matching (the existing harness pattern) to be format-agnostic. Or check value only (`#:expected 42`), not type annotation.
4. **D4 — Wall-time impact**: 3 new parity tests add ~3-5s suite time. Within variance band.
5. **D5 — Test framework: `parity-test` vs `parity-test-skip`**: if tests fail due to harness limitation, use `parity-test-skip` with explicit phase pointer ("Phase 10 ATMS branching" or similar) — honest framing per 2A.b's reframing precedent.

#### §8.7.c.8 Sub-steps + LoC estimate

| Step | Deliverable | Est. LoC |
|---|---|---|
| 1 | Add `orchestration-parity` axis to `test-elaboration-parity.rkt` (3 test cases) | ~40-60 |
| 2 | Run targeted (test-elaboration-parity + test-retraction-stratum); confirm parity tests pass | — |
| 3 | If `(ns t)` pattern doesn't work: fall back to baseline + falsification NOTE | ~10-20 (alternative path) |
| 4 | Run probe + acceptance | — |
| 5 | Run full suite (regression gate) | — |
| 6 | Adversarial 3-column VAG; commit; tracker; dailies | — |

**Total: ~40-80 LoC** (mostly test code).

#### §8.7.c.9 Completion criteria

- `orchestration-parity` axis ships with falsification coverage (either via working `(ns t)` cases OR with explicit pointer to test-punify-integration if reframed)
- Probe diff = 0 semantically
- Acceptance file 0 errors
- Full suite: 8231+ tests / within 118-127s variance band / 0 failures
- Adversarial 3-column VAG passed all 4 questions
- Tracker row 2A.c marked ✅ with commit hash

#### §8.7.c.10 Cross-track references

- **PPN 4C Parent Design Doc Phase 4 row item (viii)** — retirement targets already captured per 2A.a/b commits; no new captures from 2A.c.
- **2B sub-phase** — `run-stratified-resolution-pure` orchestrator retirement is the natural next phase. 2A.c is the verification gate before 2B can land safely.

### §8.8 Phase 2B Mini-design + Mini-audit (2026-05-20)

Per Stage 4 Per-Phase Protocol: opening mini-design + mini-audit cycle for Phase 2B (orchestrator retirement). Outcomes persist into this design doc per refined Stage 4 methodology.

Charter: retire the sequential `run-stratified-resolution-pure` orchestrator now that 2A.0+2A.a+2A.b have moved its responsibilities (S(-1) retraction + S0 quiescence + L1/L2 resolution drain) onto the BSP outer-loop's value-tier strata. Simplify `solve-meta!` to call `(current-quiescence-scheduler)` directly. Retire the dead `run-stratified-resolution!` (R3 external critique finding) + supporting helpers + Racket-parameter scaffolding. Phase 2 charter ("one orchestration mechanism") completes here.

#### §8.8.1 Architectural reframing — what 2A made redundant

Post-2A.a+2A.b, the wrapper `run-stratified-resolution-pure` (metavar-store.rkt:2266) has become a pass-through:
- **S(-1) retraction** — `process-retraction` BSP value-tier handler (2A.a) does the work. The wrapper's `run-retraction-stratum!` call (line 2277) is belt-and-suspenders since 2A.a landed.
- **S0 quiescence** — the wrapper calls `(current-quiescence-scheduler)`, which IS the BSP outer-loop. Same call path.
- **L1 readiness + L2 resolution** — `process-resolution` BSP value-tier handler (2A.b) drains cell-14 inside the BSP outer-loop. The wrapper's subsequent `read-ready-queue-actions` (line 2295) returns `'()` since cell-14 was already drained. The wrapper's `(for/fold ... resolution-executor)` (line 2297-2299) runs on the empty list = no-op.
- **Progress detection + fuel** — BSP outer-loop has its own progress detection (`(when (pair? (prop-network-worklist after-value-tier)))` at propagator.rkt:3109) and 20-iteration safety limit (line 3088). The wrapper's 100-iteration fuel + `(eq? enet-s2 enet-s0)` check duplicate this.

**Verdict**: `run-stratified-resolution-pure` is now structurally redundant. `solve-meta!`'s call to the wrapper can collapse to a direct BSP outer-loop invocation.

`run-stratified-resolution!` (imperative, line 2214) was already "mostly dead code" per the Track 8 A5 comment; grep confirms ZERO production callers. R3 external critique flagged this in 2026-04-18.

#### §8.8.2 Mini-audit findings (codebase grounding)

**Functions to retire** (grep-verified 2026-05-20):

| Function | File:Line | Production callers | Rationale |
|---|---|---|---|
| `run-stratified-resolution!` | metavar-store.rkt:2214 | ZERO (dead code per Track 8 A5; R3 critique 2026-04-18) | Imperative variant superseded by `-pure`; never reached |
| `run-stratified-resolution-pure` | metavar-store.rkt:2266 | 1 internal (solve-meta!:2024) | Body now pass-through over BSP outer-loop; retire by inlining at solve-meta! |
| `execute-resolution-actions!` | metavar-store.rkt:1155 | 1 (run-stratified-resolution! only) | Dead with run-stratified-resolution! |
| `read-ready-queue-actions` | metavar-store.rkt:2316 | 2 (run-stratified-resolution! :2240 + run-stratified-resolution-pure :2295) | Both dead post-retirement; function obsolete |
| `run-retraction-stratum!` | metavar-store.rkt:1566 | 2 (run-stratified-resolution! :2227 + run-stratified-resolution-pure :2277) | Dead post-retirement; process-retraction handler does the work |

**Parameters to retire**:

| Parameter | File:Line | Consumers | Rationale |
|---|---|---|---|
| `current-resolution-executor` | metavar-store.rkt:1149 | execute-resolution-actions! + run-stratified-resolution! (both dead) + driver.rkt:2705 install + test-constraint-postponement.rkt:60 | Imperative-path parameter; only used by retiring functions + 1 test (migrate) |
| `current-retracted-assumptions` | metavar-store.rkt:1490 | run-retraction-stratum! (retiring) + record-assumption-retraction + driver.rkt:467-468 init | Box-based retracted-aid set; superseded by cell-13 (retraction-stratum-request) per 2A.a |
| `current-in-stratified-resolution?` | metavar-store.rkt:1995 | solve-meta!:2020 (re-entry guard) + run-stratified-resolution!:2216 | Re-entry guard becomes vestigial: resolution-execute-action-pure uses solve-meta-core-pure (NOT solve-meta!), no re-entry path post-retirement |
| `current-resolution-executor-pure` | metavar-store.rkt:1152 | process-resolution handler (2A.b) + driver.rkt:2707 install | **KEEP** — load-bearing for process-resolution handler; PM 12 retires |

**Solve-meta! simplification** (metavar-store.rkt:2016-2033):

The 3-branch cond becomes a 2-branch cond:
```racket
;; BEFORE (post-2A.b, pre-2B):
(define (solve-meta! id solution)
  (define net-box (current-prop-net-box))
  (define executor (current-resolution-executor-pure))
  (cond
    [(and net-box executor (not (current-in-stratified-resolution?)))
     (define enet (unbox net-box))
     (define-values (enet* _) (solve-meta-core-pure enet id solution))
     (define enet** (run-stratified-resolution-pure enet* id executor))
     (set-box! net-box enet**)]
    [net-box
     (define enet (unbox net-box))
     (define-values (enet* _) (solve-meta-core-pure enet id solution))
     (set-box! net-box enet*)]
    [else
     (solve-meta-core! id solution)]))

;; AFTER (post-2B):
(define (solve-meta! id solution)
  (define net-box (current-prop-net-box))
  (cond
    [net-box
     (define enet (unbox net-box))
     (define-values (enet* _) (solve-meta-core-pure enet id solution))
     ;; Quiesce via BSP outer-loop — handles retraction + resolution +
     ;; constraint propagators via registered value-tier handlers
     ;; (process-retraction + process-resolution + classify-inhabit + S1 NAF).
     (define pnet (elab-network-prop-net enet*))
     (define pnet** ((current-quiescence-scheduler) pnet))
     (set-box! net-box (elab-network-rewrap enet* pnet**))]
    [else
     (solve-meta-core! id solution)]))
```

**Driver.rkt sites**:

| Site | File:Line | Action |
|---|---|---|
| `current-retracted-assumptions` init | driver.rkt:467-468 | DELETE (parameter retired) |
| Comment about `run-stratified-resolution-pure` | driver.rkt:2624 | UPDATE — point to BSP outer-loop instead |
| `(current-resolution-executor resolution-execute-action!)` | driver.rkt:2705 | DELETE (parameter retired) |
| `(current-resolution-executor-pure resolution-execute-action-pure)` | driver.rkt:2707 | **KEEP** — load-bearing for process-resolution |

**Provides to retire** (metavar-store.rkt):

| Line | Provide |
|---|---|
| 203 | `current-retracted-assumptions` |
| 206 | `run-retraction-stratum!` |
| 211 | `current-resolution-executor` |
| 217 | `run-stratified-resolution-pure` |
| 226 | `read-ready-queue-actions` |
| 272 | `execute-resolution-actions!` |
| (also `current-in-stratified-resolution?` if it's provided — check) |

**Tests** (3 sites needing migration):

| Site | File:Line | Migration |
|---|---|---|
| `current-resolution-executor #f` | test-constraint-postponement.rkt:60 | Replace with `current-resolution-executor-pure #f` — process-resolution handler short-circuits on unset executor (same disable semantic) |
| Two "read-ready-queue-actions" unit tests | test-readiness-propagator.rkt:261-265 + 267-287 | RETIRE — these tested the retired helper's behavior; obsolete post-2B |
| "integration: trait constraint readiness fires when dep meta solved" | test-readiness-propagator.rkt:293-321 | MIGRATE — replace `read-ready-queue-actions` observation with direct `elab-cell-read enet resolution-stratum-request-cell-id` + tagged-entry unwrap (inline 2-3 lines) |

**performance-counters.rkt:137**: comment "iterations of run-stratified-resolution! loop" — update to reflect BSP outer-loop iterations.

**propagator.rkt:888**: comment reference to `current-retracted-assumptions` — update or remove.

#### §8.8.3 Architectural honesty — 2B is the clean cut 2A.b couldn't make

Unlike 2A.b's box-bridge that had to ship as scaffolding, 2B's retirement IS the clean cut. The orchestrator wrapper has become structurally redundant; deleting it reveals the principled architecture underneath: `solve-meta!` writes a solution pure-functionally, then the BSP outer-loop drives convergence via registered handlers. One mechanism. No wrapper.

The remaining off-network scaffolding in `solve-meta!` is `current-prop-net-box` + `set-box!` + `(elab-network-rewrap ...)` — the same box-bridge family 2A.b labeled for Parent Phase 4 + PM 12 retirement. 2B doesn't make this worse; it doesn't fix it either. Phase 4 / PM 12 are the clean cut for that family.

#### §8.8.4 Deliverables

1. **Simplify `solve-meta!` body** (metavar-store.rkt:2016-2033, ~20 LoC) — 3-branch cond → 2-branch cond per §8.8.2 sketch. Drop executor parameter read, re-entry guard, run-stratified-resolution-pure call. Inline the quiesce step.

2. **Delete `run-stratified-resolution-pure`** (metavar-store.rkt:2266-2304, ~40 LoC).

3. **Delete `run-stratified-resolution!`** (metavar-store.rkt:2214-2249, ~36 LoC).

4. **Delete `execute-resolution-actions!`** (metavar-store.rkt:1155 + body, ~10-15 LoC). NOTE: line 1073 also has a `(define executor (current-resolution-executor))` — check what function that's in; likely also dead.

5. **Delete `read-ready-queue-actions`** (metavar-store.rkt:2304-2320, ~17 LoC).

6. **Delete `run-retraction-stratum!`** (metavar-store.rkt:1566 + body, ~30-50 LoC). NOTE: also removes the imperative side-effect path on `current-retracted-assumptions` box.

7. **Delete parameters**:
   - `current-resolution-executor` (metavar-store.rkt:1149 + provides + driver init at :2705)
   - `current-retracted-assumptions` (metavar-store.rkt:1490 + provides + driver init at :467-468 + use at :1567)
   - `current-in-stratified-resolution?` (metavar-store.rkt:1995 + use at :2020 — already retired by solve-meta! simplification)

8. **Update comments**:
   - performance-counters.rkt:137 (`resolution-cycles` counter doc)
   - propagator.rkt:888 (current-retracted-assumptions reference)
   - driver.rkt:2624 (run-stratified-resolution-pure mention)

9. **Test migrations**:
   - test-constraint-postponement.rkt:60 — `current-resolution-executor #f` → `current-resolution-executor-pure #f`
   - test-readiness-propagator.rkt — retire the 2 unit tests for `read-ready-queue-actions`; migrate the 1 integration test to direct cell read

10. **Update provides** in metavar-store.rkt (retire 6 entries; keep `current-resolution-executor-pure`).

#### §8.8.5 Scaffolding retirement targets — explicit captures

**Retiring in 2B (this phase)**:

| Item | Where | Retirement note |
|---|---|---|
| `run-stratified-resolution-pure` | metavar-store.rkt:2266 | Structurally redundant post-2A.a+b; BSP outer-loop is sole orchestration |
| `run-stratified-resolution!` | metavar-store.rkt:2214 | Dead code (ZERO production callers); R3 external critique 2026-04-18 |
| `execute-resolution-actions!` | metavar-store.rkt:1155 | Dead with run-stratified-resolution! |
| `read-ready-queue-actions` | metavar-store.rkt:2304 | No-op post-2A.b; obsolete post-2B |
| `run-retraction-stratum!` | metavar-store.rkt:1566 | process-retraction (2A.a) is the canonical mechanism |
| `current-resolution-executor` parameter | metavar-store.rkt:1149 + driver.rkt:2705 | Imperative path retired |
| `current-retracted-assumptions` parameter | metavar-store.rkt:1490 + driver.rkt:467-468 | Cell-13 is the canonical mechanism (2A.a) |
| `current-in-stratified-resolution?` parameter | metavar-store.rkt:1995 | Vestigial re-entry guard (no re-entry path post-retirement) |

**Deferred to PPN 4C Parent Phase 4** (already captured in parent design doc §2 row "Phase 4" item (viii) per 2A.a/b commits):

| Item | Where | Retirement note |
|---|---|---|
| `set-box! net-box` + `(elab-network-rewrap ...)` in `solve-meta!` | metavar-store.rkt (simplified body) | Same box-bridge pattern as 2A.b's process-resolution; CHAMP→cell retirement dissolves the rewrap pattern |
| `current-prop-net-box` parameter reads in solve-meta! + process-resolution | metavar-store.rkt | PM Track 12 (parameter→cell module loading) |

**Deferred to PM Track 13** (NEW track per 2A.b mini-design):

| Item | Where | Retirement note |
|---|---|---|
| Stratum-handler mechanism (registry + dispatch) | propagator.rkt:2827+ | Orthogonal handler-mechanism concern; doesn't gate 2B |

#### §8.8.6 Mantra check (adversarial three-column)

| Word | Catalogue | Challenge | Adversarial |
|---|---|---|---|
| All-at-once | ✓ Single quiesce call after solve-core; BSP outer-loop runs all strata simultaneously | Could solve-meta-core-pure + BSP quiesce be co-scheduled (fused)? Probably not — they're different concerns (write vs propagate) | **What if multiple solve-meta! calls happen in quick succession during elaboration cascade?** Each invocation drains the worklist to fixpoint. If cascade work needs another solve, that call's BSP cycles. Pattern is: solve → quiesce → solve → quiesce... Each pair atomic. No "all-at-once" violation, but also no batching. Genuine. |
| All in parallel | ✓ BSP outer-loop fires propagators per round in parallel; value-tier handlers iterate sequentially per BSP design | Could process-retraction + process-resolution + S1 NAF fire in parallel within the same value-tier round? BSP currently iterates them sequentially. Genuine question for PAR Series; doesn't affect 2B's charter | **Are there ordering dependencies among value-tier handlers?** process-retraction runs first (module load order); process-resolution runs second; S1 NAF + classify-inhabit run after. If process-resolution's actions trigger retraction (via solve cascade), the retraction request goes to cell-13 → next outer-round picks up. Correct. |
| Structurally emergent | ✓ solve-meta! is a 2-branch cond on net-box presence — no orchestration logic; BSP outer-loop is the implicit fixpoint loop | Even simpler: could solve-meta! collapse to a single line `(set-box! net-box ((current-quiescence-scheduler) (solve-meta-core-pure enet id solution)))`? Sketch-wise yes; clarity-wise prefer named bindings | **The simplified solve-meta! still has off-network state (net-box). Is the off-network surface honestly captured?** Yes — Parent Phase 4 + PM 12 retirements. Same scaffolding family as 2A.b. No new scaffolding introduced by 2B; 2B reduces by ~200 LoC of retired wrapper. |
| Information flow | ✓ Solution → enet* → pnet* → enet** → box. Linear chain, no orchestration callbacks | The `(elab-network-rewrap ...)` pattern is the elab-net/prop-net boundary scaffolding. Same captured-as-Parent-Phase-4. | **Did 2B retain any information-flow path that bypasses cells?** No — `current-resolution-executor-pure` is the parameter retained (process-resolution reads it). All resolution actions go through cells (cell-14 → handler → executor pure path). |
| ON-NETWORK | ✓ BSP outer-loop is on-network; value-tier handlers operate on cells; solution + resolution writes go through solve-meta-core-pure (pure cell write) | Off-network: box-bridge in solve-meta! + handler. Same scaffolding family as 2A.b; not introduced by 2B. | **Is there any path where solve-meta-core-pure writes get LOST between BSP outer-loop iterations?** No — solve-meta-core-pure writes to enet (immutable struct); BSP outer-loop sees the new enet via the box-update; subsequent rounds operate on the updated state. The box-bridge IS the seam but writes propagate correctly across it. |

**Honest verdict**: 2B does NOT introduce new scaffolding; it REMOVES ~200 LoC of orchestrator + helpers. The remaining off-network state (box-bridge family) is unchanged from 2A.b's level — Parent Phase 4 + PM 12 retire that family. PASS.

#### §8.8.7 Principles check (adversarial three-column)

| Principle | Catalogue | Challenge | Adversarial |
|---|---|---|---|
| Stratified Propagator Networks | ✓ S(-1) + S0 + L1 + L2 unified onto BSP outer-loop; one orchestration mechanism (Phase 2 charter complete) | The "strata" concept now lives ENTIRELY in registration order (module-load order = value-tier iteration order). Is that order-by-load-order principled? | **What if module load order changes (e.g., refactor that splits/merges files)?** Current order: metavar-store loads before relations → [S(-1), L2 resolution, S1 NAF, classify-inhabit]. If relations were loaded first, S1 NAF would interleave with retraction. Is that a correctness issue? Per BSP-LE 2B PIR + stratification.md, S1 NAF requires S0 fixpoint before evaluating — handled by BSP outer-loop's tier iteration. Within value-tier, order matters only for handlers that interact through cells. process-retraction's cleanup is independent of process-resolution's executor invocation. Order-dependence is bounded. Captured as drift risk. |
| Correct by Construction | ✓ Removing dead code; simpler solve-meta! is harder to misuse | Re-entry guard removal: am I sure no path post-2B calls solve-meta! recursively? | **What about future tracks (Phase 7 parametric resolution, Phase 9b γ hole-fill) that might introduce new resolution paths?** If those new paths use the pure executor pattern (solve-meta-core-pure inside fire functions), no re-entry. If they introduce solve-meta! callers from inside the BSP outer-loop, the guard would be needed again. Codification candidate: when introducing new resolution mechanisms, audit for solve-meta! callers from inside BSP fire chains. Watching list. |
| Cell/Propagator/Scheduler Orthogonality | ✓ Solve-meta! at elaboration layer; BSP outer-loop at scheduler layer; handlers at cell+propagator layer. Clean separation | Still box-bridge across elab/pnet (captured) | **Did 2B introduce any new scheduler-coupling?** No — the quiesce call uses `(current-quiescence-scheduler)` parameter, which is the same scheduler interface 2A.a+b used. Different schedulers (Gauss-Seidel, BSP, Zig+LLVM) plug in here. The Orthogonality principle is preserved. |
| Decomplection | ✓ Separates "write solution" (pure) from "drive convergence" (BSP). Wrapper conflated these | Could solve-meta-core-pure and the quiesce step be further decomplected (e.g., write-only API + separate quiesce-now API)? Possible refactor; not needed for 2B's charter | **What if a caller wants to write a solution WITHOUT quiescing immediately?** Currently solve-meta! is the SOLE entry point and always quiesces. If a caller wanted batched writes (write N solutions, then quiesce once), they'd need a new API. Not currently a use case; YAGNI for 2B. |
| Propagator-First Infrastructure | ✓ BSP outer-loop is propagator-first; handlers + cells are the propagator-first orchestration | Box-bridge remains (Parent Phase 4) | **Is there a code path that writes meta solutions BYPASSING the propagator network?** solve-meta-core! (legacy bang version) is still around for the no-network fallback. Used only when net-box is #f (rare test contexts). The fallback path doesn't trigger propagators. Captured as scaffolding tied to network availability; PM 12 / Phase 4 retire when the fallback is no longer needed. |

**Honest verdict**: 2B advances the Phase 2 charter (one orchestration mechanism) cleanly. Adversarial column surfaces order-dependence within value-tier as a real concern (watching for future tracks); module-load-order is principled per stratification.md but bounded by handler independence within the tier.

#### §8.8.8 Drift risks

1. **D1 — Re-entry guard removal**: dropping `current-in-stratified-resolution?` assumes no path post-2B calls solve-meta! recursively from inside BSP outer-loop. Verified via grep: only `resolution-execute-action-pure` (used by process-resolution) calls solve-meta-core-pure (NOT solve-meta!). The imperative `resolution-execute-action!` (which DID call solve-meta! recursively) is dead with `run-stratified-resolution!` retirement. **Falsification gate**: full suite passes — if any path still calls solve-meta! recursively during BSP, infinite recursion would manifest as stack overflow.

2. **D2 — BSP 20-iteration limit vs orchestrator 100-fuel**: BSP outer-loop's safety bound is stricter (20 vs 100). Both are sentinels for "possible infinite loop", not fuel budgets. In practice both should be far above typical convergence (~3-10 iterations). **Falsification gate**: any production workload that hit the 100-fuel previously would now error at 20. Suite-level regression test catches.

3. **D3 — Test migration: read-ready-queue-actions retirement**: 2 unit tests test the retiring helper's behavior; 1 integration test uses it as observer. Migration plan: retire 2 unit tests (obsolete); migrate integration test to direct cell read. **Risk**: integration test misses a regression that the unit tests would have caught. **Mitigation**: the integration test already verifies the end-to-end chain (latch → cell-14 → solve cascade); the unit-level coverage of the helper's unwrap logic moves into the inline test code.

4. **D4 — `current-resolution-executor` parameter in test-constraint-postponement.rkt**: test parameterizes to `#f` to disable resolution. Post-2B, equivalent is `current-resolution-executor-pure #f` (process-resolution handler short-circuits on unset executor). **Verification**: rerun test post-migration to confirm same disable semantic preserved.

5. **D5 — Value-tier handler order dependence**: 2B finalizes module-load-order as the value-tier iteration order. Future tracks introducing new value-tier handlers must understand this. **Codification candidate** (watching): "Value-tier handler order is determined by module load order (driver.rkt require order); document the canonical sequence when adding new value-tier handlers."

6. **D6 — Comment hygiene at retirement**: propagator.rkt:888 + driver.rkt:2624 + performance-counters.rkt:137 reference retiring functions/parameters. Need full comment sweep. **Risk**: stale comments survive retirement and mislead future readers. **Mitigation**: grep + manual review in commit; followup commit acceptable if missed.

7. **D7 — Tests pass with retired functions still imported**: a test that requires `read-ready-queue-actions` would get unbound-identifier at import time. **Verification**: targeted test run catches this immediately.

8. **D8 — Driver.rkt re-test path**: driver.rkt loads the parameter installs at startup. With param retired, the install line fails. **Atomic commit discipline**: ALL retirements + driver.rkt cleanups land in same commit.

#### §8.8.9 Sub-steps + LoC estimate

| Step | Deliverable | Est. LoC |
|---|---|---|
| 1 | Simplify `solve-meta!` body (3-branch → 2-branch; inline quiesce) | ~20 (net: -10) |
| 2 | Delete `run-stratified-resolution-pure` | ~40 deletion |
| 3 | Delete `run-stratified-resolution!` + supporting comments | ~36 deletion |
| 4 | Delete `execute-resolution-actions!` + line 1073 audit (likely dead) | ~10-15 deletion |
| 5 | Delete `read-ready-queue-actions` | ~17 deletion |
| 6 | Delete `run-retraction-stratum!` | ~30-50 deletion |
| 7 | Delete 3 parameters + `(set-box! ...)` mutation in `record-assumption-retraction` if applicable | ~15 deletion |
| 8 | Driver.rkt cleanups (3 sites: 467-468 delete + 2624 comment + 2705 delete; 2707 KEEP) | ~6 deletion + 1-2 comment edit |
| 9 | Provides cleanup (6 entries retired) | ~6 deletion |
| 10 | Comment updates (perf-counters.rkt:137 + propagator.rkt:888) | ~2-4 edits |
| 11 | Test migrations (test-constraint-postponement + test-readiness-propagator) | ~10-20 net (retire 2 tests + migrate 1) |
| 12 | Validation: delimiter + raco make + targeted + probe + acceptance + full suite | — |
| 13 | Commit + tracker + dailies | — |

**Total: ~150-200 LoC net DELETION** (mostly retirements; net negative — first net-deletion sub-phase in addendum's Phase 2).

#### §8.8.10 Completion criteria

- `solve-meta!` simplified body lands cleanly; targeted tests for solve cascade pass
- All 5 functions + 3 parameters deleted (no dead-code stubs remaining)
- Driver.rkt installs cleaned up; only `current-resolution-executor-pure` install survives (line 2707)
- Provides updated; no orphan exports
- Test migrations preserve disable-resolution + integration-test semantics
- Comments hygiene applied (perf-counters + propagator.rkt + driver.rkt:2624)
- Probe (`examples/2026-04-22-1A-iii-probe.prologos`): 0 errors; semantic output preserved
- Acceptance (`examples/2026-04-17-ppn-track4c.prologos`): 0 errors
- Full suite: 8231+ tests / ≤127s wall (within 118-127s variance band) / 0 failures
- Adversarial 3-column VAG applied with two-column catalogue/challenge + third adversarial column
- Tracker row 2B marked ✅ with commit hash
- Dailies entry per phase-completion protocol

#### §8.8.11 Codifications captured during this mini-design

- **D5 codification candidate (watching)**: "Value-tier handler order is determined by module load order; document the canonical sequence when adding new value-tier handlers." 1 data point this session — graduate when next handler addition surfaces order-dependence.
- **D1 codification candidate (watching)**: "When introducing new resolution-cascade mechanisms, audit for solve-meta! callers from inside BSP fire chains; the re-entry guard's retirement assumes no such callers exist." 1 data point — graduate when next resolution-mechanism addition triggers the audit.
- **Architectural pattern**: orchestrator retirement is the natural completion of an orchestration-unification phase. 2A introduces the new mechanism (handlers on BSP); 2B retires the old mechanism (wrapper). Same pattern likely applies to addendum Phase 4 (process-command retirement after top-level orchestration handlers ship).

#### §8.8.12 Cross-track references

- **PPN 4C Parent Design Doc Phase 4 row item (viii)** — box-bridge + `(elab-network-rewrap ...)` pattern in simplified `solve-meta!` body inherits Parent Phase 4 retirement target (already captured per 2A.a/b commits; no new captures).
- **PM Master Track 12** — `current-prop-net-box` retirement absorbs the box-bridge in solve-meta!.
- **PM Master Track 13** — orthogonal (stratum-handler mechanism); doesn't gate 2B.
- **Phase 2V** — Vision Alignment Gate for Phase 2 immediately follows 2B (the addendum Phase 2 charter completes at 2B's close).

### §8.9 Phase 2V — Cross-Arc Vision Alignment Gate (2026-05-20)

Per Stage 4 Implementation Protocol + workflow.md adversarial-VAG discipline: cross-arc Vision Alignment Gate covering Phase 2's full implementation (2A.0 → 2A.a → 2A.b → 2A.c → 2B). Per-sub-phase VAGs already passed at each close (§8.7.a + §8.7.b + §8.7.c + §8.8); this gate verifies the CUMULATIVE delivery against the addendum's §1.1 Phase 2 charter and identifies arc-wide patterns the per-sub-phase gates couldn't see.

Documentation-only sub-phase. No code changes; outcomes persist into D.3 for future-track reference + dailies entry per phase-completion protocol.

#### §8.9.1 Charter recap

Per addendum §1.1 (Phase 2 charter): *"retire the sequential `run-stratified-resolution-pure` in favor of BSP scheduler's uniform stratum iteration via `register-stratum-handler!`"*

Per §1.2 LoC estimate: ~150-250 LoC.

#### §8.9.2 Cumulative metrics (full arc — pre-2A.0 vs post-2B)

| Boundary | Commit | Tests | Wall (s) | Delta vs pre-Phase-2 |
|---|---|---|---|---|
| Pre-Phase-2 (post-1V baseline) | `b8405dfb` | 8224 | 110.9 | — |
| 2A.0 close (cells dormant) | `bf025224` | 8224 | 107.3 | 0 / -3.6s |
| 2A.a close (process-retraction) | `0c25400f` | 8228 | 109.1 | +4 / -1.8s |
| 2A.b close (process-resolution + ready-queue retirement) | `014944a5` | 8231 | 121.1 | +7 / +10.2s |
| 2A.c close (orchestration-parity axis) | `2b4bd5a8` | 8234 | 116.3 | +10 / +5.4s |
| **2B close (orchestrator retirement)** | **`c24cbae6`** | **8232** | **109.2** | **+8 / −1.7s** |

**Full-arc delta**: +8 tests / −1.7s wall / ~−200 LoC production code / 5 new BSP stratum cells + handlers / 6 functions + 3 parameters + 7 provides retired.

LoC vs §1.2 estimate: arc total ~+450 LoC of new infrastructure (handlers, parity axes, mini-design persistence) + ~−200 LoC of retirements + ~−71 LoC net code (the rest is documentation comments preserved for narrative). The original §1.2 estimate of ~150-250 LoC was for new code only and didn't account for retirement scope or design-doc growth; the actual delta is comparable when normalized.

Wall delta interpretation: the arc absorbed +12s at 2A.b (new handler infrastructure + readiness-latch broadcast path) then RETIRED −12s at 2B (orchestrator wrapper's redundant retraction + readiness drain). Net is a wash + slight improvement. The wrapper's overhead was REAL — not hypothetical.

#### §8.9.3 Adversarial three-column VAG (4 questions, arc-wide)

##### Question (a) On-network? — across the full arc

| Catalogue | Challenge | Adversarial |
|---|---|---|
| ✓ Phase 2's charter delivered: BSP outer-loop is sole orchestration mechanism for in-form stratified work. 5 value-tier handlers (4 topology + classify-inhabit + S1 NAF + process-retraction + process-resolution). | The handlers themselves are still Racket procedures stored in an off-network registry box (`stratum-handlers` at propagator.rkt:2831). The mechanism is "on-network at the cell+propagator layer" but the registration/dispatch mechanism is off-network. | **Did Phase 2 make this WORSE?** No — the off-network registry pre-existed (used by topology handlers + S1 NAF + classify-inhabit before Phase 2). Phase 2 added 2 more entries; it did NOT introduce the box. The mechanism-level concern is captured as PM Track 13 with explicit retirement direction; Phase 2 stayed within its in-form orchestration charter. **Honest framing**: the "on-network" claim is incremental (handlers run via cells + worldview-tagged reads), not absolute (registration is still imperative). PM 13 closes the absolute gap. |
| Box-bridge in process-resolution handler reads `current-prop-net-box` + `current-resolution-executor-pure` + writes via `set-box!`. Box-bridge in simplified solve-meta! reads `current-prop-net-box` + `set-box!` + `elab-network-rewrap`. | Could 2A.b have shipped without the box-bridge? Per §8.7.b.3, no — resolution-execute-action-pure fundamentally operates on enet (meta-info CHAMP + id-map). Structural until Parent Phase 4. | **Could 2B have eliminated more off-network state by going further than the wrapper retirement?** Phase 2's charter was "retire `run-stratified-resolution-pure`." Going further (e.g., migrating meta-info CHAMP to cells) is Parent Phase 4's charter. Mixing charters mid-track is scope creep (the lesson from 1D/1E deferral). Phase 2 stayed clean. |

**Honest verdict**: Phase 2 is on-network within its charter. Two scaffolding families remain (box-bridge to elab-net; off-network registry box for handlers); both labeled with explicit retirement plans (Parent Phase 4 + PM 12 + PM 13). PASS.

##### Question (b) Complete? — across the full arc

| Catalogue | Challenge | Adversarial |
|---|---|---|
| ✓ All 5 design-named sub-phases (2A.0, 2A.a, 2A.b, 2A.c, 2B) shipped to ATOMIC CLOSE per phase-completion protocol. All adversarial VAGs passed at each sub-phase. Cumulative: 6 functions + 3 parameters + 7 provides retired; 2 new BSP handlers landed; 3 parity-test axes added (retraction-parity + resolution-parity + orchestration-union). | Was the §1.2 LoC estimate accurate? ~150-250 LoC predicted vs actual ~+450 new / −200 retired / −71 net. The retirement scope wasn't fully predicted at §1.2; surfaced incrementally per sub-phase. Honest. | **Did anything ship as SHAPE without BENEFIT?** Test the perf-claim verification rule: did 2A.b/2B reference any microbench claim that needed verification? No — Phase 2 had no load-bearing microbench claims (unlike Phase 1's tropical addendum). Suite wall delta (-1.7s arc) is empirical bonus, not a target. No microbench-claim-verification obligation triggered. PASS by absence. |
| `retraction-parity` + `resolution-parity` + `orchestration-union-*` axes added to test-elaboration-parity.rkt. | The resolution-parity axis (2A.b) is BASELINE-ONLY (no falsification case) because run-ns-last binds empty prelude env — eq-check unbound. Falsification coverage redirected to integration test in test-readiness-propagator.rkt + test-trait-resolution.rkt + full suite. | **2A.c proved this redirect was wrong** — the other session used `(ns t)` bootstrap in run-ns-last to access prelude bindings, achieving full falsification in the orchestration-union axes. **Did 2A.b ship a weaker parity-test than necessary?** Yes, and the alternative was unknown to that session. **Codification candidate**: harness limitations may have workarounds the immediate session doesn't see; explicit pattern documentation (the `(ns t)` bootstrap in 2A.c) makes it discoverable for future sessions. Watching list. |
| §8.3 (original Phase 2A deliverables) was superseded by §8.7 mini-design (the audit revealed L1 readiness already cell-based per S2.b-iv; 3 cells → 2 cells). | Design evolved under mini-audit. Stale §8.3 references retired code (collect-ready-constraints-via-cells). | **Did the §8.3 supersession introduce inconsistency in the design doc?** The §8.3 heading marks itself as "ORIGINAL — superseded by §8.7 mini-design 2026-05-19" but the body wasn't deleted. Future readers might still cite §8.3 numbers. **Honest mitigation**: the supersession header is explicit; §8.7+ is the canonical reference. Codification candidate: "design-doc supersession headers preserve narrative while preventing stale-citation drift." 1 data point. |

**Honest verdict**: Phase 2 complete per its stated charter. Parity-test reframing at 2A.b was honest given session-bounded harness understanding; 2A.c demonstrated the workaround. No SHAPE-without-BENEFIT drift. PASS with codification candidates captured.

##### Question (c) Vision-advancing? — across the full arc

| Catalogue | Challenge | Adversarial |
|---|---|---|
| ✓ One orchestration mechanism delivered. Addendum's Phase 2 charter ("retire sequential orchestrator in favor of BSP scheduler iteration") fully realized. solve-meta! is structurally simpler (3-branch → 2-branch). Suite faster (-1.7s arc, with -11.9s 2B improvement empirically validating the retired wrapper's redundant work). | Where does the deeper vision (addendum-wide) still have gap? Phase 4 (top-level orchestration) still uses sequential `process-command` loop. Phase 3 (union types via ATMS) yet to land. Phase 1E (storage unification) deferred to PPN 4D. | **Where do MULTIPLE orchestration mechanisms STILL EXIST?** Look at the bigger picture: (1) BSP outer-loop (substrate); (2) process-command sequential loop at driver.rkt (top-level forms — Phase 4 addresses); (3) macro/parser pipeline pre-elaboration (still imperative); (4) `run-stratified-resolution` reference in commits (sh/kernel-pu branch was working on parallel retirement). **Addendum's Phase 2 is one CLEAN cut among multiple orchestration mechanisms.** The full charter ("one orchestration mechanism" addendum-wide) is met at Phase 4 close, not Phase 2. Phase 2V's correct framing: Phase 2 completes its scoped charter; the larger vision continues at Phase 4. |
| Plus 5 new codifications captured for graduation (audit-driven scope expansion at 4 data points — graduation-ready). Plus PM Track 13 spun off as orthogonal handler-mechanism concern (captured the deeper concern without scope-creeping mid-track). | The 4-data-point pattern is across PPN 4C 2A/2B; need 1-2 cross-track instances to graduate. | **Did Phase 2 produce ARCHITECTURAL drift it didn't surface?** Look for inherited patterns we preserved without challenging. (i) Box-bridge family — labeled scaffolding (Parent Phase 4 + PM 12). (ii) Stratum-handlers box — labeled scaffolding (PM 13). (iii) Parity-test harness limitation — honest framing + (ns t) workaround surfaced at 2A.c. (iv) §8.3 supersession — explicit header preserves narrative. **All inherited patterns either labeled with retirement plan OR addressed in-arc.** No silent inheritance. |

**Honest verdict**: Phase 2 advances the addendum's vision incrementally — in-form orchestration unified; between-form orchestration awaits Phase 4. PM 13 captures the mechanism-level deeper concern without scope-creeping. PASS.

##### Question (d) Drift-risks-cleared? — across the full arc

| Sub-phase | Risks named | Risks materialized | Risks slipped past | Codification |
|---|---|---|---|---|
| 2A.0 | 4 (§8.7.5) | 1 (§8.7.4 timing change) | 0 (timing change captured as 2A.c verification gate) | — |
| 2A.a | 5 (§8.7.a.8) | 1 (4 STUB callbacks dead) | 0 (audit-surfaced retirement; included in scope) | "audit-surfaced retirement" pattern (data point 1) |
| 2A.b | 8 (§8.7.b.8) | 1 (empty-list scheduler guard) | 1 (was NOT in D1-D8; surfaced at test failure) | Codified: extend empty-pending guard for list-merge stratum cells |
| 2A.c | (per §8.7.c.7) | 0 named materialized | 0 | `(ns t)` bootstrap pattern (D1 verified workaround) |
| 2B | 8 (§8.8.6) | 1 (retry-constraints-for-meta! dead) + 1 (test-speculation-bridge audit gap) | 1 (audit gap; surfaced at full-suite-run) | Codified: grep ALL callers (tests + production) atomically when retiring functions |

**Arc-wide adversarial review**:

| Catalogue | Challenge | Adversarial |
|---|---|---|
| ✓ All named drift risks tracked + addressed (or codified for graduation). Audit gaps caught at full-suite-run before commit. | 2 drift risks slipped past per-sub-phase audits (2A.b empty-list guard; 2B test-speculation-bridge gap) — both caught by full-suite as the cumulative regression gate. | **Is the audit methodology improving across the arc?** Yes — 2A.a found 4 STUB callbacks (audit caught at planning); 2A.b found empty-list guard (caught at test failure); 2B found retry-constraints-for-meta! (caught at audit) + test-speculation-bridge gap (caught at full-suite). The pattern: audits catch more each sub-phase, full-suite catches what audits miss. **No drift was rationalized away — every surfaced finding either landed in-scope or got captured for future graduation.** |
| 4-data-point pattern for audit-driven scope expansion: 2A.a 4 STUB callbacks; 2A.b empty-list guard; 2A.b parity-axis reframe; 2B retry-constraints-for-meta!. | All 4 are this-arc. Need cross-track validation to graduate from "watching" to codified principle. | **Could the pattern be graduated NOW based on 4 data points within one phase?** Workflow says "watching for 2-3 more data points" — but 4 in one phase across orthogonal sub-phases is strong evidence. **Decision deferred to cross-arc retrospective** (i.e., the PIR at addendum close); pattern is graduation-ready and will be promoted in the addendum PIR with full evidence. |

**Honest verdict**: 2 drift risks slipped past per-sub-phase audits + were caught by the full-suite regression gate. This validates the layered gate design (per-sub-phase audits + full-suite as backstop). Codifications graduated where appropriate; deferred where evidence was within-arc only. PASS.

#### §8.9.4 Cross-arc patterns surfaced

Patterns visible only when viewing the full arc:

1. **Adversarial 3-column framing reaches maturity through the arc**: 2A.a applied it; 2A.b applied it (catching parity-axis reframe); 2A.c applied it; 2B applied it. The third column ("adversarial") consistently surfaces drift that columns 1+2 rationalize. This is the codified discipline from workflow.md proving effective at 4 sub-phase gates + this cross-arc gate (5 instances).

2. **PM 13 spin-off was the right call**: the alternative — absorbing handler-mechanism redesign into Phase 2 — would have produced a wrong-scope multi-month track. The clean charter discipline (Phase 2 = in-form orchestration; Phase 4 = between-form; PM 13 = mechanism redesign) kept each track to its right scope. Lesson reinforced: when a concern surfaces mid-track that's orthogonal to track's charter, capture as separate track. **Same pattern as 1D/1E deferral to PPN 4D**; same pattern likely applies again in Phase 3 (when union-type ATMS branching surfaces a deeper ATMS-mechanism concern).

3. **Audit-driven scope expansion is consistent**: 4 instances in the arc. Each sub-phase's design framing missed 1-2 related dead-code or retirement opportunities; implementation-time audit caught them all. The cost of one extra grep at each phase open is small; the cost of leaving dead code is technical debt. Graduation-ready.

4. **First net-deletion phase in addendum**: Phase 1 was net-addition (tropical fuel + specialized cells); Phase 2 retired ~200 LoC of orchestration scaffolding that had been in place since Track 7. The pattern "build new mechanism (sub-phase a/b/c) → retire old mechanism (sub-phase 2B)" is a natural completion arc shape. Phase 4 likely follows the same arc (build new top-level mechanism → retire process-command sequential loop).

5. **Suite wall fluctuation across the arc is informative**: 2A.b's +12s wall absorbed the new handler infrastructure cost; 2B's −12s removed the wrapper's redundant work. The net is −1.7s — the wrapper's overhead approximately equaled the new handler's overhead. This is empirical confirmation that the orchestration mechanism was being substituted, not added, even though the codepath shows new code + retired code separately. **Honest framing**: Phase 2's net perf delta is variance-band-small; the retirement validates the new mechanism is equally efficient.

#### §8.9.5 Codifications status (graduation + watching)

**Graduated to DEVELOPMENT_LESSONS.org** (during the arc):
- (none graduated in-arc; all candidates accumulated to watching list for cross-arc retrospective)

**Watching list — graduation candidates this arc** (1-4 data points each):

| Codification | Data points | Graduation gate |
|---|---|---|
| Adversarial 3-column framing at every gate | 5 (this arc) | Graduation-ready — promote at addendum PIR |
| Audit-driven scope expansion | 4 (this arc) | Graduation-ready — promote at addendum PIR |
| Stratum-handler with list-merge reset needs empty-pending guard extension | 1 (2A.b) | Watching — 2 more instances |
| Parity-axis falsification ambition meets harness limitation → reframe honestly OR find bootstrap workaround | 2 (2A.b reframe + 2A.c `(ns t)` bootstrap) | Watching — 1 more instance |
| Pure functional API beats imperative-bang when state is on-network | 2 (rq-cid as constant + record-assumption-retraction) | Watching — 1 more instance |
| Re-entry guard removal assumes no solve-meta! callers in BSP fire chains | 1 (2B verified) | Watching — graduate when next resolution-mechanism addition audits |
| Value-tier handler order = module-load order | 1 (2B observation) | Watching — graduate when next handler addition surfaces order-dependence |
| When retiring a function, grep ALL callers (tests + production) atomically | 1 (2B test-speculation-bridge gap) | Watching — 1-2 more instances |
| Compiler-technology framing: networks + scheduler ARE compiler tech | 1 (2A.b PM 13 spin-off context) | Watching — graduate at SH Series founding |
| Off-network ≡ scaffolding (operational principle, sharpest mantra form) | 2 (2A.b codification + 2B reinforcement) | Watching — graduate at PM 13 research validation |

**Recommendation**: at addendum-wide PIR (Phase V), graduate 2 patterns to DEVELOPMENT_LESSONS.org based on this-arc evidence (adversarial 3-column framing + audit-driven scope expansion). The others wait for cross-track validation.

#### §8.9.6 Cross-track captures (consolidated for Phase 4 / Phase 3 / PM 12 / PM 13 implementers)

**For PPN 4C Parent Phase 4** (CHAMP retirement; already captured in parent design doc §2 row "Phase 4" item (viii) per 2A.a/b/c/B commits):
- `set-box! net-box` + `elab-network-rewrap` patterns in process-resolution handler + simplified solve-meta!
- 6 worldview-aware reader migration sites in metavar-store.rkt (from 2A.a) — trivial cell reads post-CHAMP-promotion
- meta-info CHAMP + id-map CHAMP (the worldview-filtered storage that 2A.a's process-retraction defers cleanup of)

**For PM Track 12** (parameter→cell module loading):
- `current-prop-net-box` parameter reads (handler + solve-meta!)
- `current-resolution-executor-pure` parameter (the bridge from process-resolution to resolution-execute-action-pure)
- Per `2026-05-20_PM_TRACK13_IMPLEMENTATION_NOTE.md`: these are the Phase 2 contributions to PM 12's scope

**For PM Master Track 13** (NEW track captured at 2A.b — Stratum-Handler Mechanism + Scheduler State as On-Network Cells):
- `stratum-handlers` box at propagator.rkt:2831 (off-network registry)
- `register-stratum-handler!` imperative API at propagator.rkt:2833
- BSP outer-loop's imperative handler dispatch at propagator.rkt:3061
- Cross-cutting affects ALL 7+ shipped handlers (4 topology + classify-inhabit + S1 NAF + process-retraction (2A.a) + process-resolution (2A.b))

**For PPN 4C Addendum Phase 3** (union types via ATMS + hypercube + residuation):
- Cell-13 (retraction-stratum-request) + process-retraction handler — Phase 3's union-branch retraction can write to cell-13 from fork-on-union failure paths
- Cell-14 (resolution-stratum-request) + process-resolution handler — Phase 3 readiness latches on union branches use the same drain pattern
- `make-warm-general-meta` (specialized-cells.rkt) — Phase 3's per-branch fuel cell allocation follows the same §4.6 framework declaration pattern
- `(ns t)` bootstrap pattern from 2A.c — Phase 3's parity-test axes can use this to achieve falsification coverage in run-ns-last harness
- §8.9.4 pattern 4: build-then-retire arc shape — Phase 3A (basic mechanism) → 3B (hypercube integration) → 3C (residuation error-explanation) follows the same incremental pattern with no retirement (Phase 3 is new functionality, not replacement)

#### §8.9.7 Phase 3 readiness gate

Phase 3 (union types via ATMS + hypercube + residuation per addendum §9) is the natural next sub-phase. Readiness check:

| Prerequisite | Status |
|---|---|
| BSP outer-loop is sole in-form orchestration mechanism | ✅ delivered by Phase 2 |
| Cell-13 + process-retraction handler (for branch retraction) | ✅ delivered by 2A.a |
| Cell-14 + process-resolution handler (for branch readiness drain) | ✅ delivered by 2A.b |
| `make-warm-general-meta` framework (for per-branch fuel cells) | ✅ delivered by 2A.0 (extends §4.6 framework from Phase 1) |
| §4.6 specialized cell type framework | ✅ delivered by Phase 1 (Tropical Quantale Addendum) |
| Tropical fuel primitive (tropical-fuel-primitives.rkt + tropical-fuel.rkt) | ✅ delivered by Phase 1 |
| Tropical-left-residual operator (for §9.5.A Form C consumer at 3C) | ✅ delivered by Phase 1 |
| Hypercube primitives (Gray code, subcube-member?, Hamming) | ✅ pre-existing per BSP-LE Track 2/2B + audit §3.5 |
| `(ns t)` bootstrap pattern (for parity-axis falsification coverage) | ✅ discovered + documented at 2A.c |

All Phase 3 prerequisites are met. **Phase 3 READY TO OPEN.**

#### §8.9.8 Phase 2 close — declaration

Per the Addendum §1.1 charter, **Phase 2 is COMPLETE**:
- One orchestration mechanism: BSP outer-loop iterates 8 registered stratum handlers across topology + value tiers (4 topology + classify-inhabit + S1 NAF + process-retraction + process-resolution).
- `run-stratified-resolution-pure` orchestrator wrapper RETIRED.
- `run-stratified-resolution!` dead code RETIRED.
- Sequential orchestration in solve-meta! simplified to direct BSP outer-loop invocation.
- ~200 LoC production code retired across the arc.
- Suite wall: ~variance-band-equivalent (−1.7s arc) with empirical proof that retired wrapper's overhead was real (−11.9s at 2B alone).
- 3 new parity-test axes regression-gate the new mechanism (retraction-parity + resolution-parity + orchestration-union-*).
- Adversarial 3-column VAG at each sub-phase + this cross-arc gate all PASSED with honest scaffolding labels.

**Next**: Phase 3 (Union Types via ATMS + Hypercube Integration + Residuation Error-Explanation) per addendum §9.

---

## §9 Phase 3 — Union Types via ATMS + Hypercube Integration

### §9.1 Scope and rationale

Phase 3 ships union types via ATMS branching (D.3 §6.10), exploiting already-implemented hypercube primitives (audit §3.5) and residuation-based error-explanation (research §10.3).

### §9.2 Sub-phase partition

- **Phase 3A — Fork-on-union basic mechanism** (~100-150 LoC)
- **Phase 3B — Hypercube integration (Gray code, subcube pruning)** (~50-100 LoC)
- **Phase 3C — Residuation error-explanation** (~75-150 LoC)
- **Phase 3V — Vision Alignment Gate**

### §9.3 Phase 3A deliverables (revised post-§9.3.1 mini-design)

**Architectural model**: BSP-LE 2/2B Realization B (in-place worldview tagging on shared carrier, **realized via lazy `promote-cell-to-tagged` at branch-installation time** — see §9.3.1.2). NOT fork-and-rejoin. See §9.3.1 for rationale + dialogue outcomes; §9.3.4 for 3A.b carrier-promotion mini-design (Option E).

1. **Fork-on-union request propagator** — watches `:type` facet's CLASSIFIER layer per position; threshold-fires once when classifier becomes `(expr-union l r)`; writes decomposition request to cell-15 (`fork-on-union-request-cell-id`). Threshold-fire-once per (position, decomposition) pair.
2. **`process-fork-on-union` stratum handler** (cell-15) — per request entry: flatten union via `flatten-union` to N components (N-ary flat decomposition; not nested binary); allocate N fresh aids via `solver-state-amb`; initialize worldview-cache by setting all N branch bits (`(bitwise-ior worldview-cache (bits-of branch-aids))`); **promote attribute-map cell to tagged-cell-value via `promote-cell-to-tagged` (per §9.3.4 — REQUIRED for per-branch isolation; one promote per fork firing, idempotent)**; install N branch check propagators wrapped at branch worldviews (via `wrap-with-worldview(aid-bit)`); install branch contradiction watcher (see #4).
3. **Branch check propagators**: per branch, the existing check propagator chain elaborates `e` against the X-th component under wv = (outer | X-bit). Per-branch metas/writes tag automatically via `current-worldview-bitmask` AND the post-promotion tagged-aware attribute-map cell. Per-branch cost tracking (if needed for Phase 3C UC3) via worldview-tagged writes to canonical fuel-cost cell (cell-11) — shared budget; per-branch accumulation via tagged-cell-value.
4. **Branch contradiction watcher (B2-broadcast realization)** — ONE propagator installed per fork-on-union firing, items = N branch aids; for each item, reads e's :type cell at branch worldview (via `wrap-with-worldview(branch-bit)`), detects contradiction sentinel (`'classify-inhabit-contradiction` or type-top), produces `(seteq aid)` on detection else `(seteq)`; result-merge-fn = set-union; writes to cell-16 (`fork-contradiction-request-cell-id`). **Unification primitives (`type-unify-or-top`, `merge-classify-inhabit`) STAY PURE** — no integrated detection (per OQ3 decomplection).
5. **`process-fork-contradiction` stratum handler** (cell-16) — consumes accumulated aid-set per BSP round; narrows worldview-cache atomically: `worldview-cache &= ~(bits-of contradicted-aids)`. Mirrors 2A.a `process-retraction` pattern. `#:reset-value (seteq)`.
5a. **Position-local read constraint helper** (per §9.3.4 Q1, defensive for Phase 9b): `tagged-attribute-map-read-with-base-merge net tm-cid position facet` — explicitly merges tagged branch entry with base via `attribute-map-merge-fn`, returning the requested facet value. Fast path: if cell holds plain hasheq (no entries match worldview), falls through to direct hasheq lookup with no overhead. Used by future branch propagators that need to read attribute-map at positions OTHER than their fork's union position (e.g., Phase 9b γ hole-fill multi-candidate; PReduce e-class branching).
6. **Non-committing inhabitation semantics** (per OQ1) — after BSP convergence: classifier preserved as `(expr-union l r)` at outer worldview; surviving branches' bits remain set in worldview-cache; failed branches' bits cleared. Outer-wv reads see classifier=union, INHABITANT=branch-witnesses (multi-success entries coexist; `tagged-cell-read` with optional `domain-merge` joins if needed).
7. **All branches contradict** → worldview-cache narrows to NOT include any branch bits → fall through to error-explanation (Phase 3C).
8. **Tests** (`tests/test-union-types-atms.rkt`): axis `'union-inhabitation-fork` (renamed from `'union-narrow-by-constraint` at `test-elaboration-parity.rkt:423`); expected behavior: classifier preserves union after check; inhabitant matches synthesized type; multi-success branches coexist under non-committing semantics.

**Cell allocations** (next available after cell-14):
- **Cell-15**: `fork-on-union-request-cell-id` — merge: hash-union (request hash); handler: `process-fork-on-union` (one-shot per entry); `#:tier 'value`, `#:reset-value (hasheq)`
- **Cell-16**: `fork-contradiction-request-cell-id` — merge: set-union (aid set); handler: `process-fork-contradiction` (atomic narrowing per BSP round); `#:tier 'value`, `#:reset-value (seteq)`

**Q-A4 resolved** (per §9.3.1): `elab-speculation.rkt` orchestrators (`speculation-begin`/`try-branch`/`commit`/`speculate-first-success`) retire — replaced by stratum-handler architecture. `solver-state-amb` primitive retained (still load-bearing for aid generation). Test consumers (test-elab-speculation.rkt + test-speculation-bridge.rkt) audit at 3A close — retire or migrate.

### §9.3.1 Phase 3 mini-design + mini-audit (2026-05-22 — conversational opening of Phase 3A)

Mini-design + mini-audit opened in fresh session post-Phase-2 ATOMIC CLOSE (commit `5d838c00`, 2026-05-20). Phase 3 readiness gate met (§8.9.7 — all 9 prerequisites). Outcomes persisted per Stage 4 methodology (mini-design + mini-audit findings persist to design doc, not parallel files / dailies-only).

#### §9.3.1.1 Audit findings — building-against survey

Audited Phase 3A's compositional substrate (existing infrastructure 3A integrates with):

| Layer | What's available |
|---|---|
| **AST** | `expr-union (left right)` (syntax.rkt:973) — binary right-associated; `flatten-union` (union-types.rkt:30) for N-ary decomposition; `build-union-type` for canonical ACI construction |
| **Existing union infer-time** | `make-union-fire-fn` (typing-propagators.rkt:1289) — infer-time TYPE-of-union (universe-level); NOT branching. Phase 3A's check-time fork is ORTHOGONAL. |
| **Canonical union check (sexp)** | `typing-core.rkt:2384-2389` — `(or (with-speculative-rollback ...))` first-success pattern. Phase 3A's on-network REPLACEMENT target. 4 additional `with-speculative-rollback` callers (qtt.rkt:2329, typing-core.rkt:1307+1344, typing-errors.rkt:78). |
| **ATMS API** | `solver-state-amb` (atms.rkt:67/440) — fresh-aid allocation via counter cell; one aid-group per call. `solver-state-add-nogood`, `solver-amb-groups`. |
| **Worldview substrate** | `worldview-cache-cell-id` (cell-1); `current-worldview-bitmask` parameter (per-propagator override); `wrap-with-worldview(bit-pos)` wrapper. |
| **Tagged-cell-value** | `(struct tagged-cell-value (base entries))` (decision-cell.rkt:397); `tagged-cell-read tcv wv [domain-merge]` with most-specific subset match + optional domain-merge for multi-success join. |
| **Hypercube primitives** | `hamming-distance`, `hasse-adjacent?`, `subcube-member?`, `popcount`, `decision-bitmask` (decision-cell.rkt:342-373) — Phase 3B integration target; all pre-existing. |
| **Fork primitive (reference, NOT used by 3A)** | `fork-prop-network` (propagator.rkt:924) — D.4-aware; S1 NAF pattern. Phase 3A does NOT use this (in-place tagging instead). |
| **Phase 1 substrate** | `net-new-tropical-fuel-cell`, `net-new-tropical-budget-cell`, `make-tropical-fuel-threshold-propagator`, `tropical-left-residual`. SRE domain `'tropical-fuel`. `make-monotone-counter-meta` / `make-cold-general-meta` / `make-warm-general-meta` (§4.6 framework). |
| **Phase 2 substrate** | Cell-13 (retraction) + cell-14 (resolution) + handlers (process-retraction at metavar-store.rkt:1598; process-resolution at :1655). `register-stratum-handler!` API. Phase 3A allocates cell-15 + cell-16 following this pattern. |
| **S1 NAF handler precedent** | `process-naf-request` (relations.rkt:116-243) — fork-and-rejoin pattern. Phase 3A rejects this pattern (see §9.3.1.2). |
| **classify-inhabit substrate** | `classify-inhabit-value` struct; pure `merge-classify-inhabit (v×v→v)` (load-bearing per classify-inhabit.rkt:142-143); SRE domain 'classify-inhabit classified 'structural; cross-tag residuation propagator (3c-iii) at `classify-inhabit-request-cell-id` (cell-10). |
| **`(ns t)` bootstrap** | Discovered at 2A.c; enables full parity-axis falsification in `run-ns-last` harness for Phase 3A. |
| **Existing test coverage** | test-union-types.rkt (264 lines; AST + WS, NO branching); test-elab-speculation.rkt (388); test-tagged-cell-value.rkt (358); test-solver-context.rkt (392); test-elaboration-parity.rkt — `'union-narrow-by-constraint` skip-gated at line 423. **`test-union-types-atms.rkt` does NOT exist yet** (Phase 3A target). |
| **Cell-id allocation** | Next available: cell-15. Phase 3A allocates cell-15 + cell-16. |

**Concrete Phase 3A consumer-of-substrate**: items 1-7 of revised §9.3 above are EACH a specific consumption of an audit-listed primitive. No new infrastructure outside cell-15/cell-16 + their handlers + the watcher propagator.

#### §9.3.1.2 Architectural pivot — Realization B over fork-and-rejoin

Original §9.3 (pre-revision) framed fork-on-union via the S1 NAF pattern (fork-prop-network + per-branch quiescence + nogood-on-main-net). Mini-design dialogue surfaced that **BSP-LE 2/2B Realization B is the architecturally-correct precedent**, NOT S1 NAF.

**Why S1 NAF is the wrong precedent**: NAF's inner goal lives in a genuinely separate scope (separate logic variables, separate success criterion). Union check is fundamentally different — each branch checks the SAME expression `e` against a DIFFERENT component of the SAME union, in the SAME elaboration context, touching the SAME meta vars. Branches share carrier; they only need to differ in worldview tagging.

**Why Realization B is correct**: BSP-LE Track 2B's PIR (§6.3, §12.2) and `structural-thinking.md` § "Module Theory of Lattices" established that speculation is structurally **"tag writes on the shared carrier cell with the worldview bitmask"** — NOT "fork the network and rejoin." This applies directly to union check. The bridge-collapse failure mode that motivated BSP-LE 2B's D.9/D.10/D.11 iterations IS the failure mode Phase 3A would inherit under fork-and-rejoin.

**Lazy carrier promotion is the canonical Realization B mechanism** (clarification persisted 2026-05-22 post-3A.b mini-audit per §9.3.4). Realization B does NOT mean "the carrier is tagged-cell-value-aware by design"; it means **"the carrier is lazily promoted to tagged at branch-installation time via `promote-cell-to-tagged` (propagator.rkt:1579)."** This pattern is used at **5 production sites in `relations.rkt`** (lines 2034, 2079, 2481, 2564, 2944) for NAF / guard / fact-row / multi-clause concurrent installations. The canonical install sequence:

```
1. Allocate aids for each branch (solver-state-amb)
2. Promote shared carrier cells to tagged via promote-cell-to-tagged
3. Install branch propagators wrapped at branch bitmask via wrap-with-worldview
4. Writes through wrap-with-worldview become tagged entries automatically
5. Reads through current-worldview-bitmask filter correctly via tagged-cell-read
```

`promote-cell-to-tagged` is idempotent (no-op if already tagged), wraps the current value as `(tagged-cell-value val '())`, and atomically rewrites the cell's merge-fn to `(make-tagged-merge old-merge)`. The 2026-04-06 Cell-Based TMS Design Note explicitly anticipated this as the intended pattern for attribute-map: *"TMS keeps branch values separate within the SHARED attribute-map cell."*

**Downstream consumers should NOT re-derive this pattern.** Phase 9b γ hole-fill multi-candidate, PReduce Track 1 e-class cells, and any future track that introduces fork-style branching on a shared carrier should reference this section directly.

**Mantra alignment** (in-place vs fork-and-rejoin):

| Axis | Fork-and-rejoin (S1 NAF) | In-place tagging (Realization B) |
|---|---|---|
| All-at-once | ~ (per-branch sequential in handler) | ✓ N branches install simultaneously |
| All in parallel | ✗ Branches in for/fold | ✓ Branches fire in parallel BSP rounds |
| Structurally emergent | ✓ Handler triggered by request cell | ✓ Tagged-cell-read with worldview filtering |
| Info-flow through cells | ~ Main↔fork via parameters | ✓ Tagged-cell-value carries per-branch state |
| ON-NETWORK | ~ Fork's network on-network; orchestration in handler | ✓ Everything on-network |

#### §9.3.1.3 Resolved design questions (OQ1-OQ4)

| OQ | Question | Resolution | Type / source |
|---|---|---|---|
| **OQ1** | Branch commit policy: first-success vs non-committing? | **Non-committing inhabitation semantics**. Classifier preserved as union after check. Multi-success branches coexist via worldview tagging. Narrowing is downstream concern (PPN Track 5, occurrence typing). | Design choice; type-theory unanimous |
| **OQ2** | Worldview bit allocation strategy + bit-space limits? | **Per-command bit scope** (default; reset via `reset-meta-store!`); **no reclaim within command** (subcube-member? correctness); **≤30 bits gate at 3A close**; **PERF-COUNTERS observability** for `max-aids-per-command`; bignum fallback if exceeded. | Design choice + measurement obligation |
| **OQ3** | Contradiction detection mechanism? | **Stratum handler (B3) + B2-broadcast watcher**. Cell-16 (`fork-contradiction-request`) accumulates aid set via set-union merge per BSP round; `process-fork-contradiction` handler atomically narrows worldview-cache. Watcher propagator (1 broadcast per fork firing; N items = N branch aids; per-item read+check+set-union into aid-set). **Unification primitives STAY PURE** — no integrated detection. | Design choice; decomplection challenge surfaced via adversarial 3-column |
| **OQ4** | Termination argument under in-place model? | **Level 1 (Tarski) — simpler than original §9.7 Level 2**. Per-branch monotone refinement under finite cell lattice; cross-branch isolation via worldview filter (empirically validated at 2A.c; 3A parity axis extends validation); monotone worldview narrowing; tropical fuel safety-net. **CONDITIONAL on worldview filter correctness** — load-bearing assumption, validated via 3A's parity axis. | Restatement (was Level 2; now Level 1) |

**Type-theory citations for OQ1** (per type-theoretic foundations):
- Frisch, Castagna, Benzaken — *Semantic Subtyping* (JACM 2008): types as sets; `e : A | B` is set membership; no commit semantic
- Castagna — *Programming with Union, Intersection, and Negation Types* (2022): set-theoretic semantics; expression's type is the annotated union
- Reconstructing TypeScript Part 4 (Donham 2021): bidirectional per-arm check; "checker does NOT commit to a specific arm — accepts the expression if any arm matches"; resulting type IS the union
- Scala 3 spec: hard unions PRESERVED as union; soft unions widened to visible join (inference-only)
- Tobin-Hochstadt, Felleisen — *Logical Types for Untyped Languages* (ICFP 2010): occurrence typing narrows via predicates DOWNSTREAM of check; check preserves union

**Type-theory conclusion**: "first-success commit" in our sexp `or` is an algorithmic shortcut, not a type-theoretic obligation. Non-committing aligns with semantic subtyping + bidirectional check + Scala 3 + Typed Racket. **This is the architecturally correct semantic for Prologos under SRE Track 2H quantale + Path T-3 set-union merge.**

#### §9.3.1.4 Implementation-time audit obligations (deferred from mini-design)

These are not open design questions — they are concrete audit tasks to run at Phase 3A.0 / 3A.a implementation start:

- **OQ5 — fork-on-union install site**: Phase 3A.0's mini-audit must verify the install pattern. Likely a **classifier-watcher propagator** installed per-position (or once at network init, fired per-position on classifier writes that match `expr-union`). Audit `classify-inhabit-request` stratum handler (3c-iii precedent at `classify-inhabit-request-cell-id` = cell-10) — symmetric trigger architecture, different decomposition.
- **solver-context counter scope verification**: confirm that `solver-context` (atms.rkt:215+) is allocated per elab-network (reset per command via `reset-meta-store!`) vs persistent across commands. If per-command, OQ2's "per-command bit scope" is structurally enforced. If persistent, need to design explicit per-command counter scoping.
- **worldview-cache merge function audit**: confirm worldview-cache's merge supports atomic bitwise-AND-with-NOT-mask narrowing. process-fork-contradiction handler writes via this; needs structurally-correct merge for accumulated narrowing.
- **Watcher scope**: per OQ3 sub-question, the contradiction watcher's `:component-paths` covers e's :type cell minimum. Implementation audit determines whether sub-expression :type cells need additional watcher coverage (contradictions in sub-expressions during branch elaboration; may propagate up via existing mechanisms OR may need explicit per-sub-position watchers).

#### §9.3.1.5 Drift risks named (per Stage 4 mini-design discipline)

To be re-verified at Phase 3A close (drift-risks-cleared question in 3V VAG):

- **D-3A-bit-budget**: max aids per command post-3A may approach fixnum (62) boundary, especially with Phase 9b multi-candidate consideration. Pre-0 instrumentation captures baseline; Phase 3A close gate: ≤30 bits per command (half fixnum, leaves Phase 9b headroom). If exceeded → surface to mini-design for corrective.
- **D-3A-watcher-scope**: contradiction watcher's `:component-paths` scope. Minimum (e's :type only) may miss contradictions in sub-expressions; maximum (recursive walk) is expensive. Implementation-time audit determines scope.
- **D-3A-filter-correctness**: Level 1 termination claim depends on worldview-filter correctness. 3A parity axis MUST exercise the new filter usage patterns (in-place tagging with multiple simultaneously-active branches at outer worldview after non-committing commit). Empirical validation; 2A.c is precedent but not coverage.
- **D-3A-meta-divergence**: branches solving same meta to different values produces outer-wv contradiction via tagged-cell-read domain-merge. Expected behavior (correctness preserved; static error signal). Diagnostic message clarity deferred to Phase 3C.
- **D-3A-recursion-safety**: fork-on-union watcher must threshold-fire-once per (position, decomposition) to avoid re-triggering on subsequent classifier writes. Following 3c-iii residuation propagator's threshold-fire pattern.

#### §9.3.1.6 Refined sub-phase partition

Per the resolved architecture:

| Sub-phase | Scope | Est. LoC | Key gate |
|---|---|---|---|
| **3A.0** | Cell-15 + cell-16 allocations via §4.6 framework (`make-warm-general-meta`); register `process-fork-on-union` + `process-fork-contradiction` stratum handlers; OQ5 implementation audit (classifier-watcher install pattern); worldview-cache merge audit | ~80-120 | Cells allocated; handlers registered (no-op until 3A.a); allocation-drift assertions pass |
| **3A.a** | `process-fork-on-union` handler — request-entry processing: flatten-union; aid generation via `solver-state-amb`; initial worldview-cache write (set branch bits); install branch check propagators wrapped at branch worldviews | ~150-200 | Single-union-component check works end-to-end at branch worldview; targeted test in test-union-types-atms.rkt |
| **3A.b** | Branch contradiction watcher (B2-broadcast) + `process-fork-contradiction` handler — narrowing on contradiction. Watcher per-fork-firing, N items broadcast, set-union-merge to cell-16. Handler atomic narrowing. | ~100-150 | Single-branch contradiction → worldview-cache narrowing correctly; multi-branch independence (one contradicts, other succeeds); targeted tests |
| **3A.c** | Integration with check propagator chain + classifier-watcher install at typing-propagators (per OQ5 implementation audit). Update test-elaboration-parity.rkt 'union-narrow-by-constraint axis → 'union-inhabitation-fork (rename + expectation revision per OQ1 non-committing). | ~80-120 | parity axis green; acceptance file 0 errors; full suite GREEN; D-3A-filter-correctness empirically validated |
| **3A.d** | Q-A4 disposition — retire `elab-speculation.rkt` orchestrators (speculation-begin/try-branch/commit/speculate-first-success); retain `solver-state-amb` primitive; migrate or retire 2 test files (test-elab-speculation.rkt, test-speculation-bridge.rkt) | ~-200 to -300 (net deletion) | elab-speculation.rkt minimal (primitives only); tests retired or migrated; full suite GREEN |
| **3A-VAG** | Adversarial 3-column VAG; verify all drift risks D-3A-*; restate §9.7 termination if not done; bit-budget measurement gate | doc-heavy | All 4 VAG questions pass under adversarial framing; bit budget ≤ 30 |

Total Phase 3A estimate: **~210-490 LoC** (net + retirements). Plus per-phase regression discipline (probe + acceptance + full suite after each sub-phase per `workflow.md`).

#### §9.3.1.7 Cross-track captures

**Phase 3C** (residuation error-explanation): inherits worldview/contradiction infrastructure from 3A. Form C UC1/UC2/UC3 (per §9.5.A) consume tropical-left-residual + per-branch contradiction signals. Phase 3A's cell-16 contradiction signal IS the diagnostic chain anchor.

**Phase 9b** (multi-candidate γ hole-fill): inherits Phase 3A's fork-on-union pattern. N candidate inhabitants for a hole → N branches via same mechanism. **D-9b-bit-budget**: N candidates may exceed bit budget (large N>30). 9b mini-design will need budget-management mechanism (per-fork sub-context with nested counter, or candidate-pruning at fork-time). Cross-phase capture for 9b's eventual mini-design.

**Parent Phase 4** (CHAMP retirement): Phase 3A delivers on-network REPLACEMENT for `with-speculative-rollback` union path. 4 callers of `with-speculative-rollback` (qtt.rkt:2329, typing-core.rkt:1307+1344+2385, typing-errors.rkt:78). Phase 3A retires the canonical site (typing-core.rkt:2385); remaining 4 callers retire as parent Phase 4 / PM 12 scope (per dailies §1310).

**PM Track 12** (parameter→cell module loading): `solver-context`'s counter cell scope (per-command vs per-session) is a PM 12-adjacent concern. If OQ5 implementation audit reveals per-session scope, capture as PM 12 input.

**Parity axis revision**: `test-elaboration-parity.rkt:423` `'union-narrow-by-constraint` → `'union-inhabitation-fork`. Old expectation (`#:expected-type 'Int` for `(the <Int | String> 0)` narrowed by `[eq? x 0]`) was protecting a sexp implementation artifact (first-success commit). New expectation: classifier preserved as union; narrowing happens via downstream constraint propagation, not via check-time commit. Phase 3A.c lands the axis revision.

#### §9.3.1.8 Methodology notes — adversarial 3-column gate captures

Two real drift catches during mini-design dialogue:

1. **OQ3 integrated detection** — first-pass recommendation was to push contradiction emission INTO `type-unify-or-top` (rationalized as "structurally aligned at propagator-fire boundary"). Adversarial column (user external challenge) surfaced that this conflated **levels**: `type-unify-or-top` is a PURE function called by fire functions, NOT a fire function itself. Pushing side effects into pure primitives violates the documented `(v × v → v)` purity pattern (classify-inhabit.rkt:142-143). Reversed to separate watcher + stratum handler. **Decomplection preserved.**

2. **OQ1 first-success commit** — original framing leaned toward first-success "for parity preservation." Adversarial column (challenge to type-theoretic correctness) prompted research lookup; type-theory literature unanimous against commit. Reversed to non-committing inhabitation. **Lattice correctness preserved (T-3 set-union semantics composes naturally).**

**Codification candidate (graduation-ready at addendum PIR — 3+ data points)**: *"Pure-vs-effectful layer audit on architectural decisions involving cell writes."* Three data points across the addendum:
- S2.c-iii drift (with-handlers wrapper preserved; missed perf claim) — 2026-04-24
- 2A.b handler-as-scaffolding (PM 13 spin-off) — 2026-05-20
- OQ3 integrated detection (this commit) — 2026-05-22

All three: external user challenge caught what internal application missed. **Adversarial 3-column discipline is necessary but not sufficient — external review IS the load-bearing gate for design decisions.** Capture as DEVELOPMENT_LESSONS.org candidate.

#### §9.3.1.9 Status

- Mini-design + mini-audit COMPLETE — OQ1-OQ4 resolved
- Implementation-time obligations enumerated (OQ5 + sub-questions)
- Drift risks named (D-3A-*)
- Sub-phase partition refined (3A.0 / 3A.a / 3A.b / 3A.c / 3A.d / 3A-VAG)
- Ready for Phase 3A.0 implementation opening

### §9.3.2 Phase 3A.0 — Cell allocations + handler stubs (CLOSE 2026-05-22)

Mini-design + mini-audit + implementation per Stage 4 Per-Phase Protocol. 3A.0 establishes the infrastructure SHAPE for fork-on-union orchestration; bodies wire at 3A.a + 3A.b.

#### §9.3.2.1 Implementation deliverables

**propagator.rkt** (+~70 LoC):
- Provides extended: `fork-on-union-request-cell-id`, `fork-contradiction-request-cell-id`, `fork-on-union-request-merge`, `fork-contradiction-request-merge`
- Cell-id constants (lines after 2A.0's cell-13/14): `(define fork-on-union-request-cell-id (cell-id 15))` + `(define fork-contradiction-request-cell-id (cell-id 16))`
- Local merge functions (after 2A.0 merges):
  - `fork-on-union-request-merge` — hash-union (per-position request keyed by position; CALM-safe under monotone hash-union for distinct keys)
  - `fork-contradiction-request-merge` — set-union (eq-based seteq for aid-set; mirrors retraction-stratum-merge)
- Allocations in `make-prop-network` (after 2A.0's cell-13/14 allocations) via `net-register-specialized-cell` with `#:tier 'warm #:storage 'general #:fires-on 'any-change` (per §4.6 framework `make-warm-general-meta` pattern)
- Drift assertions per 2A.0 precedent — `(unless (equal? actual-cid expected-cell-id) (error ...))` for both cells
- Updated `let*` block at end of make-prop-network to use `net6` (latest cells CHAMP) instead of `net4` for the prop-net-warm fuel-cell-cache + worldview-cache-cache direct-ref lookups

**typing-propagators.rkt** (+~45 LoC):
- Stub handlers `process-fork-on-union` + `process-fork-contradiction` — return net unchanged (no-op at 3A.0; bodies wire at 3A.a + 3A.b)
- Registered at module load with `register-stratum-handler! #:tier 'value #:reset-value <empty>` (mirrors 2A.0's metavar-store.rkt:1615/1675 pattern)

**Test fixes (cell-id cascade per 3c-iii precedent — `cell-id 10→11 cascade` analog at `cell-id 14→17`)**:
- `tests/test-propagator.rkt:42, 72, 79, 199, 237` — hardcoded next-cell-id expectations 15→17; user-cell base 15→17; batch sequence `(15 16 17)→(17 18 19)`
- `tests/test-observatory-01.rkt:307-309` — cell-meta-label "cell-15"→"cell-17" (+ siblings)
- `tests/test-trace-serialize.rkt:110, 124` — totalCells 15→17 + 17→19

#### §9.3.2.2 Cell-id allocation map (post-3A.0)

| Cell-id | Cell | Source |
|---|---|---|
| 0 | decomp-request | PAR Track 1 |
| 1 | worldview-cache | BSP-LE Track 2 Phase 4 |
| 2 | relation-store | BSP-LE Track 2B Phase R1 |
| 3 | config | BSP-LE Track 2B Phase R1 |
| 4 | naf-pending | BSP-LE Track 2B Phase R4 |
| 5 | pool-config | (Phase 2c) |
| 6-9 | topology requests | (constraint-propagators, elaborator, narrowing, sre) |
| 10 | classify-inhabit-request | PPN 4C Phase 3c-iii |
| 11 | fuel-cost | Tropical Quantale Addendum 1B-iv |
| 12 | fuel-budget | Tropical Quantale Addendum 1B-iv |
| 13 | retraction-stratum-request | PPN 4C Phase 2A.0 |
| 14 | resolution-stratum-request | PPN 4C Phase 2A.0 |
| **15** | **fork-on-union-request** | **PPN 4C Phase 3A.0 (this commit)** |
| **16** | **fork-contradiction-request** | **PPN 4C Phase 3A.0 (this commit)** |
| 17+ | User cells (formerly 15+) | First user-allocated cell |

#### §9.3.2.3 Verification (adversarial 3-column VAG)

| Q | Catalogue | Challenge | Adversarial |
|---|---|---|---|
| (a) On-network? | ✓ Cells on prop-network; handlers stratum-registered; merges defined; no off-network parameters added | Is `register-stratum-handler!` itself off-network (module-load imperative call mutating a box)? | Module-init scaffolding parallel to ALL SRE registrations + 2A.0 registrations + 3c-iii classify-inhabit registration. PM Track 13 captures the handler-mechanism concern for separate research. **NOT a fresh violation** — inherited from existing pattern; labeled as scaffolding with retirement plan tied to PM 13. Pass. |
| (b) Complete? | ✓ All §9.3.1.6 3A.0 scope items landed (cell allocations, drift assertions, stub handlers, registrations, implementation-time audits embedded in §9.3.1.4) | Did 3A.0 implement OQ5 + worldview-cache merge audits, or defer them? | Worldview-cache merge audit DONE (line 732-733 = `(if (= old new) old new)` replacement; atomicity preserved by stratum-handler architecture — cell-16 accumulates set-union; handler narrows once between rounds). OQ5 (classifier-watcher install) correctly DEFERRED to 3A.c per §9.3.1.4 — 3A.0 does NOT install watchers. Pass. |
| (c) Vision-advancing? | ✓ Infrastructure cells allocated; ready for 3A.a body wiring | Is 3A.0 just bureaucratic preparation, or does it commit to the architecture? | The SHAPE of 3A.0 (cells + stub handlers) IS the architectural commitment to Realization B. No alternative architecture can sneak in at 3A.a/b once cells exist. **The SHAPE is load-bearing.** Pass. |
| (d) Drift-risks-cleared? | ✓ D-3A.0-allocation-drift cleared (assertions land); D-3A.0-handler-no-op-leak cleared (probe diff = 0 semantically); D-3A.0-cell-init-merge-shape cleared (hash-union + set-union mirror precedent) | Are there unanticipated drifts? | 3 cell-id cascade test failures (test-propagator + test-observatory + test-trace-serialize) — EXPECTED per 3c-iii precedent; mechanical fixes. No semantic regression. Probe wall + GC numbers slightly improved (likely GC variance). Pass. |

**All 4 questions pass under adversarial framing.**

#### §9.3.2.4 Validation results

| Measurement | Value | vs Baseline |
|---|---|---|
| Probe `examples/2026-04-22-1A-iii-probe.prologos` semantic diff | 0 (all 28 elaboration outputs identical) | ✓ no semantic change |
| Probe `cells` counter | 59 (was 57) | +2 (exactly cell-15 + cell-16) |
| Probe `cell_allocs` counter | 1495 (was 1381) | +114 (per-command transient overhead; ~4/command for 28 commands) |
| Probe semantic outputs | 28 / 0 errors | identical to baseline |
| Targeted tests (4 files) | 96/96 PASS in 5.0s | baseline preservation |
| Full suite (post-fixes) | **8232 tests / 109.3s / 0 failures** | identical to pre-3A.0 baseline (8232/109.2s) |
| Cell-id cascade test fixes | 3 files updated (test-propagator, test-observatory-01, test-trace-serialize) | precedent: 3c-iii's `cell-id 10→11 cascade` |

#### §9.3.2.5 Status

- Phase 3A.0 **COMPLETE** at this commit
- Cell-15 + cell-16 allocated with drift assertions
- Stub handlers registered as no-ops (bodies wire at 3A.a + 3A.b)
- Test cell-id cascade applied to 3 affected test files
- Probe + acceptance + full suite all GREEN (no semantic change vs pre-3A.0)
- Ready for **Phase 3A.a** (process-fork-on-union body — handler consumes cell-15 requests, allocates aids, initializes worldview-cache, installs branch propagators)

**Methodology**: mini-audit cycle reached design clarity in one pass; no surprises during implementation beyond the expected cell-id cascade (3c-iii precedent). Adversarial 3-column passed all 4 VAG questions.

### §9.3.3 Phase 3A.a — `process-fork-on-union` handler body (CLOSE 2026-05-22)

Mini-design + mini-audit + implementation per Stage 4 Per-Phase Protocol. 3A.a wires the handler body that consumes cell-15 requests, allocates aids, initializes worldview-cache, and installs branch check propagators.

#### §9.3.3.1 Implementation deliverables

**typing-propagators.rkt** (+~110 LoC):
- Imports added: `(only-in "atms.rkt" assumption-id-n solver-state-amb)`, `(only-in "elab-speculation-bridge.rkt" current-command-atms)`, `(only-in "union-types.rkt" flatten-union)`. Note: pre-T-3 atms.rkt imports were retired in Commit A.2-a; 3A.a re-introduces them for a DIFFERENT (non-imperative) purpose — per-branch worldview tagging on shared carrier per Realization B
- `make-branch-check-fire-fn` factory (parallel to `make-classify-inhabit-residuation-fire-fn`): per-branch propagator parameterized by `tm-cid`, `position`, and `component` (branch's portion of union). Closes over `component` as expected classifier. Wrapped via `wrap-with-worldview(branch-bit-pos)` at install time → fires under branch worldview → reads INHABITANT via worldview-filtered read → checks `subtype?` against component → writes `'classify-inhabit-contradiction` sentinel under branch wv if incompatible
- `process-fork-on-union` body: consumes cell-15 pending-hash (per-position request entries); per entry, runs 3 steps:
  1. **Aid allocation**: `solver-state-amb` with N labels (one per component); uses `current-command-atms` per-command box; updates the box with `set-box!`
  2. **Worldview-cache init**: `bitwise-ior` current-wv with N branch bits (`(arithmetic-shift 1 (assumption-id-n aid))` per aid)
  3. **Branch propagator install**: per component + aid pair, `net-add-propagator` wrapped via `wrap-with-worldview(bit-pos)`; `:component-paths (list (cons tm-cid (cons position ':term)))` triggers fire on INHABITANT change at branch wv
- Defensive cases: empty pending-hash → no-op; missing 'components or 'tm-cid → defensive no-op per entry; missing atms-box → defensive no-op

**Request entry shape** (cell-15 value semantics, defined at 3A.a; consumed at 3A.a; written by 3A.c classifier-watcher when implemented):
```
pending-hash : (hasheq position → request-info)
request-info : (hasheq 'components (listof TypeExpr)  ; flattened union components
                       'tm-cid CellId                ; attribute-map cell-id
                       ['source-loc (or srcloc #f)]) ; optional for diagnostics
```

**Exports added to typing-propagators.rkt**: `make-branch-check-fire-fn`, `process-fork-on-union`, `process-fork-contradiction` (latter is the 3A.b body stub registered at 3A.0). Used by test-union-types-atms.rkt + (future) classifier-watcher install.

**New test file** `tests/test-union-types-atms.rkt` (+~245 LoC; 8 tests):
- Unit: `make-branch-check-fire-fn` subtype-pass (Nat <: Int → no contradiction)
- Unit: `make-branch-check-fire-fn` non-subtype (Nat NOT <: String → contradiction sentinel)
- Unit: `make-branch-check-fire-fn` defers when inhabitant 'bot
- Unit: `process-fork-on-union` empty pending → no-op
- Unit: `process-fork-on-union` allocates N aids + sets N worldview bits + installs N propagators
- Unit: `process-fork-on-union` defensive on malformed request (missing 'components)
- **E2E**: stubbed classifier-watcher writes cell-15 → BSP `run-to-quiescence` invokes handler → branch propagators install → 2 branch bits in worldview-cache + cell-15 reset via `#:reset-value` per BSP outer-loop
- D-3A.a-stratum-tier verification: `check-not-exn` on direct handler invocation (confirms #:tier 'value works for our case; no CALM topology guard violation)

#### §9.3.3.2 D-3A.a-stratum-tier resolution

The risk: handler installs propagators (topology change); could be blocked by CALM topology guard if registered at `#:tier 'value`. **RESOLVED**: handler runs cleanly at `#:tier 'value`. The CALM topology guard (`current-bsp-fire-round?`) is active DURING BSP fire rounds (within a propagator's fire function), not during stratum handlers (which run BETWEEN rounds). Stratum handlers can install propagators regardless of tier.

3A.0's `#:tier 'value` registration is correct; no change needed.

#### §9.3.3.3 Verification (adversarial 3-column VAG)

| Q | Catalogue | Challenge | Adversarial |
|---|---|---|---|
| (a) On-network? | ✓ Handler reads/writes via net-cell-read/write; branch propagators on-network with wrap-with-worldview; aid-bit-tagged writes; structurally emergent contradiction signaling | `solver-state-amb` + `set-box!` on `current-command-atms` are off-network operations | Yes — atms-box mutation is off-network (D-3A.a-atms-box-mutation; labeled scaffolding per §9.3.3.5). Inherits the established PM Track 12 scaffolding pattern (`current-prop-net-box` + `set-box!` family). NOT a fresh violation; tied to PM 12 retirement. Honest framing preserved. |
| (b) Complete? | ✓ Handler consumes cell-15; allocates aids; sets worldview bits; installs branch propagators; 8 tests including E2E verify behavior | Are there §9.3.3 spec items unmet, or open obligations passed to 3A.b/c? | Spec coverage: items 1-7 of §9.3.3 implementation deliverables landed. Open obligations: 3A.b delivers contradiction watcher + cell-16 narrowing (not 3A.a scope); 3A.c delivers classifier-watcher install (E2E test stubs this). D-3A.a-stratum-tier RESOLVED in implementation (value tier works). Pass. |
| (c) Vision-advancing? | ✓ Realization B in-place tagging realized; non-committing semantics; per-branch worldview isolation; pure unification primitives preserved (decomplection) | Does this compose with future tracks (3A.b/c, Phase 9b multi-candidate, Parent Phase 4 retirement of with-speculative-rollback)? | Contract with 3A.b clean: branch propagators write `'classify-inhabit-contradiction` tagged at branch wv; 3A.b's watcher observes + writes to cell-16. Contract with 3A.c clean: classifier-watcher writes cell-15 with request-info shape; 3A.a handler consumes. Phase 9b multi-candidate inherits the SAME pattern (N candidates → N aids → N branch propagators; constrained by OQ2's ≤30 bits/command gate). Parent Phase 4: 3A.a delivers the on-network replacement for `with-speculative-rollback` union check; retirement gates on 3A.b + 3A.c + classifier-watcher install at canonical site (typing-core.rkt:2385's expr-ann path). Pass. |
| (d) Drift-risks-cleared? | ✓ D-3A.a-stratum-tier RESOLVED (value tier works); D-3A.a-cell-15-reset VERIFIED (E2E test confirms `#:reset-value (hasheq)` clears cell-15 after handler runs) | What about D-3A.a-atms-box-mutation, D-3A.a-aid-budget, D-3A.a-branch-propagator-fire-pattern? | D-3A.a-atms-box-mutation: labeled scaffolding (PM 12). D-3A.a-aid-budget: 3A.a tests use 1-2 branches each (well within ≤30 bits gate); production budget verified at 3A.c integration. D-3A.a-branch-propagator-fire-pattern: mitigated by idempotent `subtype?` check + contradiction sentinel absorption under `merge-classify-inhabit` (writing the same contradiction twice is a no-op). Pass. |

**All 4 questions pass under adversarial framing.**

#### §9.3.3.4 Methodology data point — E2E test double-invocation

During implementation, the E2E test initially failed with "expected 2 branch bits, got 4." Root cause: test directly invoked `process-fork-on-union` AND `run-to-quiescence` (which also invokes the handler via BSP outer-loop). The handler ran twice; 4 aids allocated; 4 worldview bits set.

**Fix**: removed direct invocation; let BSP's `run-to-quiescence` drive everything (matches production flow). Cell-15 reset via `#:reset-value (hasheq)` after handler runs prevents subsequent re-invocation.

**Codification candidate (1 data point; watching list)**: *"Stratum-handler tests should use `run-to-quiescence` to drive handler invocation; not direct calls. Direct calls bypass BSP's `#:reset-value` clearance, leading to double-invocation when followed by `run-to-quiescence`."* Watch for 2nd+ data point at 3A.b / Phase 9b / future stratum-handler tests.

#### §9.3.3.5 Validation results

| Measurement | Value | vs Baseline |
|---|---|---|
| New test file `tests/test-union-types-atms.rkt` | 8 tests, all PASS | — |
| Probe semantic diff | 0 (all 28 elaboration outputs identical) | ✓ no semantic change |
| Probe `cells` counter | 59 (unchanged) | no new persistent cells |
| Targeted tests (8 affected files) | 168/168 PASS in 6.6s | baseline preservation + 3A.a coverage |
| Full suite | **8240 tests / 108.3s / 0 failures** | +8 tests / −1.0s wall vs pre-3A.a (8232/109.3s) |

#### §9.3.3.6 Status

- Phase 3A.a **COMPLETE** at this commit
- `process-fork-on-union` handler body operational
- `make-branch-check-fire-fn` factory delivered
- D-3A.a-stratum-tier RESOLVED (value tier works for in-place propagator installation)
- 8 new tests including E2E flow with stubbed classifier-watcher
- Probe + acceptance + full suite all GREEN
- Ready for **Phase 3A.b** (contradiction watcher + `process-fork-contradiction` body — B2-broadcast watcher reads e's :type at branch worldviews; on contradiction sentinel detection, writes branch aid to cell-16; handler atomically narrows worldview-cache via bitwise-AND-with-NOT-mask)

### §9.3.4 Phase 3A.b — Revised mini-design (Option E: lazy `promote-cell-to-tagged`)

Mini-design opened post-3A.a per Stage 4 Per-Phase Protocol. Initial 3A.b mini-design + implementation HALTED at an architectural finding (prior session, commit `18645783`); working tree reverted to 3A.a baseline (`f933608a`). This sub-section captures the audit + research that produced **Option E** as the architecturally-canonical fix, supersedes the prior 4-option framing, and persists the revised plan.

#### §9.3.4.1 The architectural finding (recap from prior session)

The original 3A.b mini-design assumed Realization B applies at the attribute-map carrier — i.e., the carrier IS tagged-cell-value-aware and per-branch isolation flows automatically under `wrap-with-worldview`. Empirical evidence from a halted E2E test refuted this:

> *E2E "Int branch succeeds; String branch fails" produced 0 added-bits (both narrowed) instead of 1 (Int retained). Tracing: String's contradiction sentinel merged into base attribute-map → Int's watcher (at wv=1) also saw contradiction → both watchers wrote aids → handler cleared both bits.*

Root cause (audit-verified this session):
- `attribute-map-merge-fn` (typing-propagators.rkt:417-440) is a vanilla two-level pointwise hasheq merge. ZERO awareness of `tagged-cell-value`.
- `make-branch-check-fire-fn` (typing-propagators.rkt:937-962) writes a plain hasheq `(hasheq position (hasheq ':type 'classify-inhabit-contradiction))`.
- `net-cell-write`'s tagged-wrapping branch (propagator.rkt:1782) is gated by `(and (tagged-cell-value? old-val) (not (tagged-cell-value? new-val)))`. Since attribute-map is created plain, `old-val` is plain hasheq, so the tagged-wrapping branch NEVER fires, and per-branch isolation collapses.

#### §9.3.4.2 BSP-LE 2/2B audit — the pattern the mini-design missed

**`promote-cell-to-tagged` (propagator.rkt:1579-1599)** is a production helper that wraps a plain cell value as `(tagged-cell-value val '())` AND rewrites its merge-fn to `(make-tagged-merge old-merge)` atomically. It is idempotent (no-op if already tagged). The doc-string explicitly states: *"Must be called BEFORE speculative writes under a non-zero worldview."*

**It is used at 5 production sites in `relations.rkt`** — the EXACT analog of what Phase 3A needed:

| Site | Goal kind | Pattern |
|---|---|---|
| relations.rkt:2034 | NAF | Allocate naf-aid → `promote-cell-to-tagged` on outer scope cells → install wrapped propagators |
| relations.rkt:2079 | Guard | Allocate guard-aid → `promote-cell-to-tagged` on outer scope cells → wrap-with-worldview |
| relations.rkt:2481 | Fact-row install | Allocate fact-aids → `promote-cell-to-tagged` on shared scope cells → per-row wrapped propagators |
| relations.rkt:2564 | Multi-clause concurrent | Allocate clause-aids → `promote-cell-to-tagged` on shared scope → install ALL clauses wrapped per-clause |
| relations.rkt:2944 | (analogous additional site) | Same pattern |

The pattern (canonical Realization B):
```
1. Allocate aids for each branch (solver-state-amb or analogous)
2. Promote shared carrier cells to tagged via promote-cell-to-tagged
3. Install branch propagators wrapped at branch bitmask via wrap-with-worldview
4. Writes through wrap-with-worldview become tagged entries
5. Reads through current-worldview-bitmask filter correctly via tagged-cell-read
```

**Corrective framing**: Realization B is NOT "the carrier is tagged-aware by design"; it is **"the carrier is lazily promoted to tagged at branch-installation time."** Scope cells in relations.rkt are PLAIN cells that become tagged-aware on-demand at fork time. Phase 3A.a missed the `promote-cell-to-tagged` step.

#### §9.3.4.3 Mempalace search — original architectural intent confirmed

A mempalace semantic search this session surfaced the **2026-04-06 Cell-Based TMS Design Note** which explicitly anticipated Phase 3A's need:

> *"TMS keeps branch values separate within the SHARED attribute-map cell"* ... *"Phase 8 (ATMS union type branching in the attribute PU) DEPENDS on this rearchitecture for the principled implementation."*

The 2026-04-06 design note named the attribute-map cell as the SHARED carrier with TMS branch separation. When 3A's mini-design adopted Realization B framing, it cited BSP-LE 2/2B precedent without checking whether the attribute-map carrier had been prepared per the 2026-04-06 plan — an architectural-lineage gap the audit closed.

**Caveat**: mempalace's vector index is currently broken (97% drawers invisible per its fallback message). Results were BM25 keyword-only. Recommend `mempalace repair` at some point. Despite this limitation, the BM25 search successfully surfaced the load-bearing 2026-04-06 design-intent document.

#### §9.3.4.4 Option E — the architecturally-canonical fix

**Option E**: insert a `promote-cell-to-tagged` call on the attribute-map cell at fork-on-union entry, mirroring relations.rkt's 5 production sites. This is the missing step from Phase 3A.a's implementation of Realization B.

Replaces the prior 4-option matrix (A: full carrier migration / B: combined approach / C: pivot to fork-and-rejoin / D: undefined hybrid). Option E preserves Realization B's narrative literally, preserves watcher/handler decomplection cleanly, preserves Phase 3C diagnostic evidence trail, and is a one-line addition rather than a wholesale migration.

##### Adversarial 3-column VAG of Option E

| Q | Catalogue | Challenge | Adversarial |
|---|---|---|---|
| (a) On-network? | ✓ Promotion is a structural rewrite of cell value + merge-fn; both stay on-network. Branch writes become tagged entries via existing infrastructure. | Is `promote-cell-to-tagged` itself an off-network operation? It mutates merge-fns CHAMP. | **NOT a fresh violation.** It's a structural-rewrite operation on the network value — same kind as `net-cell-reset` / `net-add-propagator`. The CHAMP update returns a new prop-network (pure functional). Inherits 5-site BSP-LE 2/2B precedent. |
| (b) Complete? | ✓ Restores per-branch isolation; current Phase 3A.b watcher pattern works correctly post-promote. | Does it actually fix the failing E2E test? Have I traced the merge semantics correctly? | **Trace verified**: under Option E, "Int succeeds, String fails" — String's contradiction at wv=String-bit becomes tagged entry; Int's watcher at wv=Int-bit finds NO entries with bm subset of Int-bit (String-bit ⊄ Int-bit) → returns base → no contradiction → Int watcher does NOT write to cell-16. String's watcher correctly fires. Handler narrows only String-bit. Outcome: **1 added bit (Int retained). FIX CONFIRMED ANALYTICALLY.** Empirical verification required pre-commit. |
| (c) Vision-advancing? | ✓ Preserves Realization B narrative literally; preserves watcher/handler decomplection; preserves Phase 3C evidence trail; 1-line addition. | Are we preserving a flawed framing by accepting "promote when needed"? Is lazy promotion a workaround for not having a tagged-aware carrier by default? | **Lazy promotion IS the architectural pattern**, not a workaround. relations.rkt's 5 sites confirm. The "tagged-aware by default" alternative (Option A) would impose perf cost on the 90%+ of code paths that never branch. **Lazy promotion at branch time is precisely the principled-and-pragmatic balance the substrate was designed for.** |
| (d) Drift-risks-cleared? | ✓ Surgical scope (1 promote call); pattern already-validated across 5 production sites. | What about branch propagators that need to read attribute-map at positions OTHER than the union position? Under tagged-cell-read, they would see only the branch entry, NOT merged with base. | **Real caveat surfaced**. Current `make-branch-check-fire-fn` only reads at the union position — safe. But Phase 9b multi-candidate γ hole-fill (which inherits this pattern per §9.3.1.7) may need to read other positions. **Mitigation per Q1 user-resolved**: build `tagged-attribute-map-read-with-base-merge` helper NOW defensively, so the constraint doesn't become a Phase 9b footgun. |

All 4 questions pass under adversarial framing.

#### §9.3.4.5 Resolved design questions (Q1–Q5 user-resolved 2026-05-22)

| Q | Question | Resolution |
|---|---|---|
| **Q1** | Position-local read constraint for branch propagators: document-only, or build helper now? | **Build helper now defensively.** `tagged-attribute-map-read-with-base-merge` — explicitly merges branch entry with base via attribute-map-merge-fn. Phase 9b inherits it. Rationale: "designing for the need now, so it is properly considered for future need is appropriate." |
| **Q2** | Promote site: at fork-on-union entry, or per-branch-install? | **At fork-on-union entry** (one promote per fork, mirrors relations.rkt:2031-2034 NAF pattern). Idempotent so per-branch would also be correct, but single promote is cleaner. |
| **Q3** | Substrate parity test for per-branch isolation property? | **YES** — completeness in testing finds more bugs / preserves correctness. Test: write under wv=1 + wv=2, read each independently, read base under wv=0, verify isolation structural. Added to `test-tagged-cell-value.rkt` (substrate-level) and propagated to `test-union-types-atms.rkt` (3A-specific). |
| **Q4** | Graduate codification candidate ("check codebase for existing helpers") now or wait for 4th data point? | **Graduate now.** 3 data points sufficient (S2.c-iii with-handlers; 2A.b handler-as-scaffolding; 3A.b promote-cell-to-tagged miss). User direction: *"worth graduating. An important lesson, that I'm sure we'll be encountering again."* See DEVELOPMENT_LESSONS.org for the persisted entry. |
| **Q5** | Update D.3 §9.3.1.2 (Realization B narrative) to cite lazy-promotion pattern? | **YES.** Updated in this commit to explicitly cite the 5 relations.rkt production sites + `promote-cell-to-tagged` helper, so future Phase 9b implementer + PReduce Track 1 implementer (e-class cells) don't repeat the conflation. |

#### §9.3.4.6 Implementation plan

Per Stage 4 phase completion protocol:

1. **Helper**: `tagged-attribute-map-read-with-base-merge net tm-cid position facet` — returns the requested facet value, merged with base via `attribute-map-merge-fn` if the underlying cell holds tagged-cell-value entries at the current worldview. Added to `typing-propagators.rkt` alongside `that-read` / `type-map-read`. Position-local fast path preserved (if no tagged entries match, falls through to base hasheq direct lookup).

2. **Promotion**: insert `(set! n1 (promote-cell-to-tagged n1 tm-cid))` in `process-fork-on-union` body, AFTER aid allocation + worldview-cache init, BEFORE the branch propagator install loop. One promote per fork firing (idempotent if cell already tagged).

3. **B2-broadcast contradiction watcher install**: in `process-fork-on-union` body, after branch propagator install loop, install ONE broadcast propagator with N items (one per branch aid). Each item-fn reads attribute-map at the union position UNDER ITS BRANCH WORLDVIEW (via `wrap-with-worldview(branch-bit)`), checks for `'classify-inhabit-contradiction` sentinel, returns `(seteq aid)` on detection else `(seteq)`. result-merge-fn = `set-union`. writes to `fork-contradiction-request-cell-id`.

4. **`process-fork-contradiction` body**: consumes accumulated aid-set per BSP round; computes contradicted-bits mask = `(bitwise-ior (arithmetic-shift 1 (assumption-id-n aid))...)`; atomically narrows `worldview-cache-cell-id` via `bitwise-and worldview-cache (bitwise-not contradicted-bits)`. Mirrors 2A.a `process-retraction` pattern. `#:reset-value (seteq)` already in place from 3A.0.

5. **Tests**: per Q3 — substrate parity (per-branch isolation), 3A.b unit (watcher fire correctness, handler narrowing), E2E ("Int succeeds, String fails" → 1 bit remaining).

6. **Verification**: probe diff = 0; targeted tests GREEN; full suite GREEN within 118-127s variance band.

7. **VAG**: adversarial 3-column; persist outcome at §9.3.4.X.

8. **Phase completion**: commit + tracker + dailies.

#### §9.3.4.7 Drift risks named (per Stage 4 mini-design discipline)

- **D-3A.b-promote-perf**: post-promote, attribute-map reads go through tagged-cell-read filtering (slight overhead). Acceptable per relations.rkt precedent. Verify full suite wall time within variance band.
- **D-3A.b-watcher-fire-pattern**: B2-broadcast watcher must fire when branch writes land on attribute-map. Verify `:component-paths` declarations correctly route firing per-position.
- **D-3A.b-handler-atomic**: `process-fork-contradiction` must narrow worldview-cache atomically (no intermediate states visible). The handler runs between BSP rounds — atomicity preserved by stratum-handler architecture.
- **D-3A.b-position-local-reads**: branch propagators must only read at the union position OR via the new `tagged-attribute-map-read-with-base-merge` helper. Document constraint at helper docstring + Phase 9b cross-track capture.
- **D-3A.b-merge-fn-rewrite**: `promote-cell-to-tagged` rewrites merge-fn to `make-tagged-merge(attribute-map-merge-fn)`. Verify this composes correctly with attribute-map's existing two-level pointwise merge (it should: make-tagged-merge delegates to domain-merge for both-plain case).

#### §9.3.4.8 Cross-track captures

- **Phase 9b γ hole-fill multi-candidate**: inherits the lazy-promotion pattern. **D-9b-cross-position-read**: γ hole-fill may need to read attribute-map at positions OTHER than the hole position — must use `tagged-attribute-map-read-with-base-merge` helper (delivered by 3A.b).
- **Phase 3C residuation error-explanation**: per-branch contradiction evidence preserved at branch worldview in attribute-map (NOT collapsed into cell-16 set-union signal). Phase 3C's `derivation-chain-for` can walk back from the tagged entry to the branch-specific contradiction with full provenance.
- **PReduce Track 1 e-class cell substrate**: when e-class cells participate in speculative reduction, the same lazy-promotion pattern applies. Pre-existing 5 sites + this addition = 6 production references at PReduce Track 1 opening; pattern is canonical.
- **PM Track 12 (parameters → cells)**: `current-worldview-bitmask` parameter scaffolding remains in place; PM 12 retires. No new dependency added by 3A.b.

#### §9.3.4.9 Methodology data points captured

1. **Codification candidate graduated (3rd data point)**: *"Mini-audit must verify the SPECIFIC carrier cell supports the architectural pattern AND check whether the codebase already has a helper for the missing capability."* See DEVELOPMENT_LESSONS.org (graduated this session).
2. **Adversarial 3-column framing IS necessary but not sufficient** — the original 3A mini-design's 3-column VAG passed cataloguing without challenging the carrier-capability question. **E2E tests are mini-audit power tools** (the prior session's E2E test caught in ~5 minutes what the grep-based mini-audit missed).
3. **External user direction surfaced the audit-first approach** — *"Let's audit the code that these decisions touch on first, to ground our context to the reality of the codebase."* The audit then surfaced the 5 production-site promote-cell-to-tagged pattern that closed the option matrix conclusively.

#### §9.3.4.10 Implementation deliverables (CLOSE 2026-05-22)

Per Stage 4 implementation plan (§9.3.4.6) — all 4 deliverables landed atomically:

**typing-propagators.rkt** (~+125 LoC production):
- `tagged-attribute-map-read-with-base-merge` helper (~60 LoC inc. docstring) — defensive read helper for Phase 9b cross-position cases; position-local fast path preserved for plain hasheq carriers; tagged-cell-value path explicitly merges base with all entries whose bitmask is subset of current worldview via attribute-map-merge-fn
- `promote-cell-to-tagged` insertion in `process-fork-on-union` body Step 2.5 (1 line + comment) — the load-bearing addition; mirrors relations.rkt × 5 production sites
- N fire-once contradiction watcher installs in `process-fork-on-union` body Step 4 (~20 LoC) — per-branch wrapped via `wrap-with-worldview`; reads attribute-map at union position under branch wv (tagged-cell-value subset filter isolates per-branch); writes `(seteq aid)` to cell-16 on contradiction sentinel detection
- `make-branch-contradiction-watcher-fire-fn` factory (~20 LoC) — per-branch watcher fire function closing over `tm-cid + position + aid`
- `process-fork-contradiction` body (~25 LoC) — replaces 3A.0 stub; atomic bitwise-AND-with-NOT-mask narrowing of worldview-cache; idempotent (no write if no actual change); set-empty / non-set defensive checks

**Import additions**:
- `(only-in "decision-cell.rkt" tagged-cell-value? tagged-cell-value-base tagged-cell-value-entries)` — accessor imports for the helper

**Provide additions**:
- `tagged-attribute-map-read-with-base-merge` (defensive helper for Phase 9b)
- `make-branch-contradiction-watcher-fire-fn` (watcher factory, exported for unit tests)

**tests/test-union-types-atms.rkt** (~+150 LoC, +7 new tests, +2 updated):
- 5 new 3A.b unit tests: watcher writes aid on contradiction; watcher NO emit when no contradiction; handler narrows worldview correctly; handler no-op on empty set; handler defensive no-op on non-set input
- 3 new E2E tests: "Int succeeds + String fails → 1 bit remaining" (THE original failing scenario, NOW PASSES); "Both branches fail → 0 added bits remain" (all-contradict signal for Phase 3C); "Both branches succeed → both bits remain" (non-committing semantics per OQ1)
- 2 updated 3A.a tests: propagator count 2→4 (now 2 check + 2 watcher); 3A.a E2E updated for post-3A.b semantics (1 bit instead of 2)

**tests/test-tagged-cell-value.rkt** (~+80 LoC, +3 new substrate parity tests):
- "per-branch isolation: writes under disjoint worldviews are isolated" — load-bearing substrate property
- "per-branch isolation: failed branch's write does NOT affect sibling branch's read" — the precise bug Option E fixes
- "per-branch isolation: promote-cell-to-tagged is idempotent" — handler's safety property

#### §9.3.4.11 Post-implementation adversarial 3-column VAG (CLOSE 2026-05-22)

| Q | Catalogue | Challenge | Adversarial |
|---|---|---|---|
| (a) On-network? | ✓ `promote-cell-to-tagged` lives on prop-network; watcher writes via `net-cell-write` to cell-16; handler reads + writes via `net-cell-write` on worldview-cache; helper uses `net-cell-read-raw` + `net-cell-read` (both on-network). Zero new off-network state added. | Is the `tagged-attribute-map-read-with-base-merge` helper an off-network manual merge that should ideally live inside `tagged-cell-read`? | **Real consideration.** The helper composes existing on-network primitives (`net-cell-read-raw` + `attribute-map-merge-fn` + `that-read`); it doesn't introduce off-network state. But the SEMANTIC ("read with base merge") could conceptually be a tagged-cell-read option. Defer to a future tagged-cell-read API refinement (cross-track capture for PReduce + Phase 9b); for now the helper at the attribute-map-specific layer is appropriate because attribute-map-merge-fn is itself attribute-map-specific (not generic). **NOT a fresh on-network violation.** |
| (b) Complete? | ✓ All §9.3.4.6 deliverables landed; targeted tests pass (141 in 6 files); acceptance file 0 errors; full suite 8251 / 117.1s / 0 failures (after recompile of test-facet-sre-registration to clear pre-existing batch-worker linklet staleness per dailies §4.4). All 3 E2E test scenarios cover the design's claimed semantic: 1 branch succeeds + 1 fails → 1 bit; both fail → 0 bits; both succeed → 2 bits. Substrate parity tests verify the underlying isolation property independently. | Does the test coverage prove the load-bearing CORRECTNESS argument from §9.3.4.4 adversarial column (analytical trace) is empirically correct? | **Empirically verified** — the "Int succeeds, String fails → 1 bit" E2E test passes; this is THE originally-failing scenario from the prior session checkpoint. The substrate parity test "failed branch's write does NOT affect sibling branch's read" is the precise property the analytical trace claimed. Two independent verifications (substrate-level + E2E-level) of the same property. **The fix IS the architectural property; we measured it directly.** |
| (c) Vision-advancing? | ✓ Realization B narrative preserved literally (in-place worldview tagging on shared carrier via lazy promotion); pure unification primitives untouched (decomplection preserved); watcher/handler separation preserves Phase 3C diagnostic evidence trail; Phase 9b cross-position read constraint handled DEFENSIVELY (per Q1 user direction "designing for the need now"); D.3 §9.3.1.2 + §9.3 + §9.3.4 all updated so future implementers don't re-derive. | Does the LAZY promotion pattern compose well with Phase 3C's residuation walk, given the residuation walk reads the dep graph backward from contradictions? Will Phase 3C see the right evidence at the right worldviews? | **Yes — Phase 3C is designed to walk dep graphs anchored at contradiction cells. Under Option E, per-branch contradictions live at branch worldviews in the attribute-map cell's tagged entries. Phase 3C's `derivation-chain-for` will read these entries explicitly (per design) — the per-branch isolation is exactly what diagnostic chains need to distinguish "this branch's contradiction came from path X". The vision-alignment is positive: Option E DELIVERS Phase 3C-ready evidence, not just 3A.b correctness.** |
| (d) Drift-risks-cleared? | ✓ D-3A.b-promote-perf — full suite within 118-127s variance (117.1s); D-3A.b-watcher-fire-pattern — 5 unit tests verify watcher fire correctness across compatible/incompatible/multiple-branch scenarios; D-3A.b-handler-atomic — stratum-handler architecture guarantees atomicity (BSP between-rounds invocation); D-3A.b-position-local-reads — helper delivered defensively for Phase 9b; D-3A.b-merge-fn-rewrite — `make-tagged-merge(attribute-map-merge-fn)` semantics verified via substrate parity tests + E2E. | Are there NEW drift risks the implementation surfaced that weren't anticipated? | **Three observations beyond the named risks**: (i) propagator count assertion in 3A.a `process-fork-on-union: allocates N aids + sets N branch bits` test changed from 2→4 (now includes watchers) — captured as documentation in test; (ii) `make-branch-check-fire-fn` doesn't write contradiction back into the read merge chain (it writes a delta hasheq, which the tagged-cell-value merge wraps as tagged entry — confirmed by the helper's understanding); (iii) **the "broadcast" framing for the watcher in §9.3.4.6 step 3 was slightly imprecise** — net-add-broadcast-propagator reads inputs ONCE outside the per-item loop, so it can't be used for per-branch-worldview reads. Used N fire-once propagators wrapped per branch (mirrors relations.rkt:2487-2510 fact-row pattern; more mantra-aligned: parallel-decomposable). Doc-only refinement; semantic intent preserved. |

**All 4 questions pass under adversarial framing.**

#### §9.3.4.12 Validation results

| Measurement | Value | vs Baseline |
|---|---|---|
| Probe `examples/2026-04-22-1A-iii-probe.prologos` semantic diff | 0 (28 numbered results identical to 3A.a baseline; pre-existing `[Map ...]` formatting + `#t` line drift unrelated to 3A.b) | ✓ no semantic regression |
| Acceptance `examples/2026-04-17-ppn-track4c.prologos` | 0 errors | ✓ |
| Targeted tests (6 files: union-types-atms + tagged-cell-value + propagator + classify-inhabit + residuation + elaboration-parity) | 141/141 PASS in 6.8s | baseline preservation + new tests |
| Full suite | **8251 tests / 117.1s / 0 failures** | +11 tests / +8.8s vs pre-3A.b (8240 / 108.3s); within 118-127s variance band |
| Test deltas | +7 in test-union-types-atms (5 unit + 3 E2E - 1 reformulated existing E2E + 1 updated propagator count assertion = net +7); +3 in test-tagged-cell-value (substrate parity) | +10 net new + 1 from elsewhere |

#### §9.3.4.13 Methodology data points captured during implementation

1. **Helper-API discovery succeeded**: the audit-and-grep approach surfaced `promote-cell-to-tagged` at 5 relations.rkt sites in ~10 minutes. Validates the codified DEVELOPMENT_LESSONS.org "Mini-Audit Must Verify Carrier Capability AND Check For Existing Helpers" (just graduated).
2. **Broadcast vs N-fire-once trade-off**: the "B2-broadcast" framing in §9.3.4.6 step 3 was slightly imprecise — `net-add-broadcast-propagator` reads inputs ONCE per fire (not per-item), so per-branch-worldview reads need N fire-once propagators wrapped per branch. Realization: the broadcast primitive is for "1 propagator × N items × same input snapshot"; the per-branch-worldview pattern is "N propagators × per-branch wv × independent reads." Different design pattern. Doc-only refinement.
3. **Substrate parity tests revealed the load-bearing property explicitly**: the "failed branch's write does NOT affect sibling branch's read" test is the precise property Option E rests on; making it a standalone substrate test (independent of 3A specifics) creates a tripwire for any future regression in `promote-cell-to-tagged` / tagged-cell-read / `make-tagged-merge` interaction.
4. **3A.a E2E test update was clean**: the only updates needed were (a) propagator count 2→4 (added watchers), (b) expected bits 2→1 (post-3A.b narrowing). Both updates well-documented in test comments. Indicates 3A.b is an additive enhancement of 3A.a, not a refactor.

#### §9.3.4.14 Status

- **Phase 3A.b COMPLETE** at this commit (TBD hash)
- Option E (lazy `promote-cell-to-tagged` on attribute-map at fork-on-union entry) delivered
- `tagged-attribute-map-read-with-base-merge` helper delivered defensively for Phase 9b
- `make-branch-contradiction-watcher-fire-fn` + `process-fork-contradiction` body delivered
- 5 new 3A.b unit tests + 3 new E2E tests + 3 new substrate parity tests
- Codification "Mini-Audit Must Verify Carrier Capability AND Check For Existing Helpers" graduated to DEVELOPMENT_LESSONS.org (3 data points)
- D.3 §9.3.1.2 + §9.3 + this §9.3.4 updated to cite lazy-promotion pattern + relations.rkt × 5 production sites
- Probe + acceptance + targeted + full suite all GREEN
- Ready for **Phase 3A.c** (integration with check propagator chain + classifier-watcher install at typing-propagators per OQ5 implementation audit + parity axis rename `'union-narrow-by-constraint` → `'union-inhabitation-fork`)

### §9.3.5 Phase 3A.c — Revised mini-design (deliberative dialogue post-revert, 2026-05-22)

Phase 3A.c was initially implemented in a single autonomous session (commit `de453f69`, reverted at `e267206b` + `a8eed7e2`). The implementation may or may not have been architecturally correct — but the PROCESS that produced it bypassed codified Stage 4 Per-Phase Protocol discipline (DESIGN_METHODOLOGY.org Stage 4 step 1+2 + workflow.md "Conversational implementation cadence"). The work went audit → code → tests → adversarial VAG → close in ~1 hour autonomous, without dialogue on the 4 substantive decision points the audit surfaced. The user could not assess the architectural choices because the deliberation never happened.

This section captures the deliberative-dialogue redo, applying principle-guided framing per the codified discipline. It supersedes the reverted §9.3.5 content from `de453f69` (preserved in git history for reference but **must NOT be taken as a starting point**).

#### §9.3.5.1 Methodology context — the cadence violation + corrective

The autonomous implementation drift on 3A.c is the **2nd data point** for a codification candidate that now graduates to DEVELOPMENT_LESSONS.org:

> *Opening a phase ("let's open 3A.x") is an invitation to deliberative dialogue, NOT a green light for solo implementation. The protocol is: audit → present option matrices with adversarial 3-column framing → ask for user direction on each decision → implement on direction → checkpoint per sub-step.*

Data point 1: PPN Track 4 (track-level autonomous drift surfaced post-hoc). Data point 2: this 3A.c sub-phase autonomous drift surfaced at the sub-phase boundary. The pattern shape is the same — codified discipline existed, was bypassed, retrospective "Mini-Design done ✓" was cataloguing rather than challenging.

Also surfaced during the deliberative redo: the user methodology refinement to **3-column adversarial framing** (catalogue / challenge / **adversarial**). The 2-column codification (workflow.md / DESIGN_METHODOLOGY.org § VAG, codified 2026-04-24 from PPN 4C S2.c-iii drift) was too easily satisfied by qualification ("could this be MORE aligned?"); the adversarial column forces rejection-attempt framing ("where does this BREAK? what specifically refutes the claim?"). All 4 decisions below apply this framing throughout.

#### §9.3.5.2 Decision 3 — Inferred-union surface assessment (Posture B confirmed)

**Question**: which classifier-union sources need on-network coverage in 3A.c?

**Audit data** (Section B of the deliberative audit, grep-verified at HEAD `d2c1c8ff`):

| Source | Mechanism | Site | Post-T-2 surface |
|---|---|---|---|
| Annotated unions | `expr-ann (expr-union l r)` AST at parse time | typing-propagators.rkt:2311 (install-typing-network's expr-ann case) | 100% covered by install-time hook at expr-ann |
| **Source A** — emergent classifier-merge | T-3 set-union fallback under `type-unify-or-top` Role A merge | type-lattice.rkt:181 | Triggered when two Role A writes to same `:type` classifier produce incompatible types |
| Source B — sexp map-op results | `expr-map-get`/`expr-nil-safe-get` over union-typed Maps | typing-core.rkt:1316/1329/1352 | Narrow post-Open-by-Design; requires user-annotated `Map K <V1\|V2>` types |
| Source C — subtype-lattice-merge internals | Subtype join | subtype-predicate.rkt:275+ | Internal; not in main typing path |

**Two postures**:
- **Posture A — "narrow enough to defer Source A"**: install-time hook at expr-ann covers ~100% of CURRENT production paths. Source A becomes a watching-list concern.
- **Posture B — "comprehensive coverage as architectural correctness"**: classifier-watcher covers ALL classifier-union sources by construction.

**Principle-guided resolution**: Posture B.

Adversarial framing exposed Posture A's multi-anti-pattern violations:

| Anti-pattern | How Posture A violates it |
|---|---|
| Belt-and-suspenders (workflow.md "blocking red flag") | Keeps OLD `with-speculative-rollback` sexp path at typing-core.rkt:2385 alive for uncovered cases, alongside NEW cell-15 mechanism for annotated cases |
| "We'll come back to it" (DEVELOPMENT_LESSONS.org § Completeness Over Deferral) | Documents Source A as "D-3A.c-non-ann-unions known limitation"; deferral licit only for genuine dependencies on unbuilt infrastructure (3c-iii precedent shows watcher pattern works) |
| Validated ≠ Deployed (workflow.md) | Effective state: new mechanism deployed for annotated; old mechanism deployed for everything else |

Posture B's hybrid (γ) collapses to β under audit (watcher catches the same write the pre-write would catch). Multi-site pre-write (δ) approximates β with explicit case-enumeration — exactly the algorithmic shortcut the Hyperlattice Conjecture rejects.

**Q3 sub-questions resolution**:
- Q3.1 (instrumentation now vs accept grep evidence): MOOT under Posture B — structural coverage regardless of frequency
- Q3.2 (Phase 7 future Source A): MOOT — future parametric union classifiers flow through the watcher automatically
- Q3.3 (Sources B + C deferral): UNCHANGED — sexp-path internals, Parent Phase 4 / PM 12 territory

#### §9.3.5.3 Decision 1 — Install pattern (β.1 + FP3 resolution)

**Sub-Question 1: Install Scope**

Eliminated by audit:
- **β.2 (expr-meta only)**: insufficient — annotated unions arrive at term positions via `type-map-write` (line 2316), NOT at meta positions
- **β.4 (single global watcher on attribute-map)**: structurally blocked by A8 enforcement (`'attribute-map` SRE domain is `'structural`-classified; `enforce-component-paths!` hard-errors on reads without component-paths; β.4 can't declare them at install time because positions are dynamic per command)

Choice: β.1 (universal install) vs β.3 (targeted).

**Principle-guided resolution**: β.1.

10+ principles point to β.1 with NO principle favoring β.3:

| Principle | Direction |
|---|---|
| Correct by Construction | β.1 — coverage is structural property of architecture; β.3 depends on accurate enumeration (auditing burden) |
| Completeness over Deferral | β.1 — β.3 defers Phase 7 + unknown future sites with "we'll come back to it when needed" |
| Hyperlattice Conjecture | β.1 — β.3 enumeration is the case-by-case pattern the conjecture explicitly rejects |
| Most Generalizable Interface | β.1 — one mechanism, uniform behavior |
| Open Extension, Closed Verification | β.1 — new expr-* cases inherit watcher install via centralized point; β.3 requires enumeration update |
| Belt-and-suspenders avoidance | β.1 — β.3 enumeration gaps leave sexp fallback live as dual path |
| "Pragmatic" as rationalization | β.1 — β.3 framed as "pragmatic for current empirical surface" is the explicit anti-pattern phrase |
| Validated ≠ Deployed | β.1 — β.3 risks deploying partial coverage with sexp fallback retained |
| First-Class by Default | β.1 (slight) — reifies the watcher as uniform first-class network primitive |
| Data Orientation | β.1 (slight) — positions are data; uniform behavior |

The single argument for β.3 (empirical-rare for Source A) is the rationalization anti-pattern explicitly named in workflow.md.

**Sub-Question 2: Fire Pattern**

Audit surfaced the re-fire mechanics concretely: watcher reads classifier under outer worldview; branch propagators write contradiction sentinels at branch wv; under outer wv = 0, tagged entries from branch writes are filtered out; watcher continues to read classifier as union; re-fires would re-write same request to cell-15; handler re-allocates aids unboundedly.

Four fire-pattern options:

| Option | Status |
|---|---|
| **FP1**: plain net-add-propagator + accept defect | BROKEN — re-decomposition unbounded; aid budget exhausts |
| **FP2**: net-add-fire-once-propagator + predicate inside fire-fn | SILENT REDUCTION to Posture A — flag consumed on first fire regardless of predicate; never fires when classifier becomes union later in emergent case |
| **FP3**: plain net-add-propagator + decomposed-positions guard cell (NEW cell-17) | **PRINCIPLED** — idempotence is structural via guard cell |
| **FP4**: two-stage install (idempotent detector + fire-once actor) | Heavier infrastructure; topology-during-fire concerns (Stage 1's install of Stage 2 during BSP fire round violates CALM topology guard) |

**Principle-guided resolution**: FP3.

| Principle | Direction |
|---|---|
| Correct by Construction | FP3 — guard cell makes idempotence structural; FP1 broken, FP2 silently reduces, FP4 has topology-during-fire concerns |
| First-Class by Default | FP3 — guard cell makes "decomposed-position" state explicit first-class data |
| Cell/Propagator/Scheduler Orthogonality | FP3 — guard cell at cell layer; watcher at propagator layer; no scheduler coupling |
| Data Orientation | FP3 — "decomposed" is data in cell-17 (WHAT); handler writes it (WHEN at decomposition) |
| Stratified Propagator Networks | FP3 — handler+watcher+guard composition mirrors S(-1)/S0/L1/L2 at smaller scale |
| Cell Allocation Efficiency (propagator-design.md) | FP3 — separate cell for separate concern (decomposed-positions tracking) |

**Substrate gap codification candidate** (1 data point; watching list): FP3 patches at application layer what would be cleaner as substrate primitive ("fire-once-when-predicate-matches" / deferred-flag-consumption). If PReduce Track 1 or Phase 9b γ hole-fill surfaces the same need, promote to substrate addition.

#### §9.3.5.4 Decision 4 — 3A.d scope coupling

**Audit finding (the surprise)**: `elab-speculation.rkt` is already DEAD IN PRODUCTION.

| Probe | Result |
|---|---|
| Grep for callers of `speculation-begin`, `speculation-try-branch`, `speculation-commit`, `speculate-first-success`, queries — excluding elab-speculation.rkt itself | **ZERO production callers**; ONLY test-elab-speculation.rkt references them |
| Grep for `(require ... "elab-speculation.rkt")` — excluding elab-speculation-bridge.rkt | **NO HITS** in production code |
| `with-speculative-rollback` (elab-speculation-bridge.rkt:200) implementation | Uses `solver-state-assume` from atms.rkt + parameter scaffolding directly; does NOT invoke any speculation orchestrator |
| test-speculation-bridge.rkt | Requires elab-speculation-bridge.rkt only (NOT elab-speculation.rkt); 0 references to orchestrators |

**Implication**: elab-speculation.rkt was REFACTORED OUT of the call chain at some prior point (likely PPN 4B or earlier) but never code-level retired. The two files are decoupled — bridge stays alive via 5 with-speculative-rollback callers; orchestrators are stranded.

**Principle-guided resolution**:

- **Q4.1 — retirement scope**: wholly retire elab-speculation.rkt (188 LOC) + test-elab-speculation.rkt (388 LOC) in 3A.d. Net: −576 LOC. No principle supports keeping dead code.
- **Q4.2 — test migration scope** for test-speculation-bridge.rkt's union sections: 8-10 test cases for typing-core.rkt:2385 path MIGRATE in 3A.c (assertion updates to expect non-committing semantics); 7 test cases for qtt.rkt:2329 + typing-errors.rkt:78 paths STAY ALIVE
- **Q4.3 — sequencing**: sequential 3A.c → 3A.d (codified default per §9.3.1.6 sub-phase partition + Conversational Implementation Cadence)
- **Q4.4 — codification**: graduate "Stranded high-level abstraction after refactor" to watching list (1 data point — elab-speculation.rkt finding)

Codification candidate text:
> *When a high-level abstraction is refactored to be implemented via lower-level primitives (the abstraction's body becomes a direct call to primitives, bypassing its own structure), audit whether the abstraction still has external callers. If zero, retire the abstraction immediately — do not leave it stranded as a "reference implementation" or "parallel API." The stranding creates phantom maintenance burden + accumulates dead test coverage.*

**Important clarification on typing-core.rkt:2385**: under β.1 + FP3, the on-network mechanism handles annotated unions via fork-on-union at install-typing-network time, BEFORE typing-core.rkt:check would be called recursively with a union type. Production callers (via `process-string` / `process-file`) go through on-network typing and never reach typing-core.rkt:2385. The line BECOMES production-dead (analogous to elab-speculation.rkt's pre-finding state) — code-level retirement of typing-core.rkt:2385 lands in Parent Phase 4 / PM 12 when sexp paths broadly retire. **3A.c does NOT touch typing-core.rkt:2385 directly**; it deploys the on-network mechanism that bypasses it. The 4 active parity axes (§9.3.5.5) are the load-bearing validation that production uses on-network.

This is principled "production-dead with codified retirement plan" — not anti-pattern, because Parent Phase 4 / PM 12 owns the code-level retirement.

#### §9.3.5.5 Decision 2 — Parity axis structure (D' resolution)

**Reframing**: the reverted 3A.c's option matrix (A/B/C/D) mixed surface-level and mechanism-level testing concerns. The deliberative dialogue separated them:
- **test-elaboration-parity.rkt**: tests user-facing semantic equivalence through elaboration pipeline at SURFACE level (pretty-printed output via check-parity-equal?)
- **test-union-types-atms.rkt**: tests MECHANISM specifics (cell-15 writes, worldview bits, branch propagators, contradiction sentinels) — already covers ~8 tests from 3A.a + 3A.b extensions

Under this separation, structural assertions belong in test-union-types-atms.rkt, NOT in test-elaboration-parity.rkt. Decision 2 becomes: which surface properties does test-elaboration-parity.rkt validate?

**Principle-guided resolution**: D' — 4 active axes + 1 skip-gated.

| Principle | Direction |
|---|---|
| Correct by Construction | D' — multi-axis discriminates between mechanisms (sexp first-success would FAIL multi-success axis); single axis can't discriminate |
| Completeness over Deferral | D' — single axis defers coverage of multi-success / isolation / exhaustion properties |
| Decomplection | D' — separate surface properties tested as separate axes |
| Confirmation bias avoidance (CRITIQUE_METHODOLOGY.org) | D' — A' (single axis) is the test-matches-implementation pattern user checkpoint explicitly named |
| Belt-and-suspenders avoidance | NOT C' (structural assertions in parity tests) — creates dual coverage with test-union-types-atms.rkt |
| Phase scope discipline | NOT B' (restore narrowing) — Track 5 work, out of 3A.c scope |
| 2A.c precedent | D' — 2A.c added 3 axes for orchestration parity; multi-axis for single architectural delivery is codified pattern |

**The 4 active axes**:

| Axis | Input | Expected | Property tested |
|---|---|---|---|
| `union-inhabitation-preserved` | `(ns t) (def x : <Int \| String> := 42) x` | `'42` + `"Int \| String"` | Classifier preserved as union when Int branch succeeds |
| `union-inhabitation-flipped` | `(ns t) (def x : <String \| Int> := 42) x` | `'42` + `"Int \| String"` (or `"String \| Int"` per pp-expr convention) | Branch ordering symmetry; left-fail-right-succeed |
| `union-inhabitation-multi-success` | `(ns t) (def x : <Nat \| Int> := 0N) x` | `'0N` + `"Nat \| Int"` | Both branches succeed (0N is both via subtype); multi-success non-committing semantic — classifier preserved (NOT narrowed to first-success) |
| `union-inhabitation-all-fail` | `(ns t) (def x : <Int \| Bool> := "hello") x` | Type error of union-exhaustion shape | All branches fail produces error (typing-errors.rkt:78 path stays alive) |

**The 1 skip-gated axis** (preserves the original test's narrowing intent for future):

| Axis | Input | Expected | Deferred to |
|---|---|---|---|
| `union-inhabitation-narrowing` (renamed from `union-narrow-by-constraint`) | `(ns t) (def x : <Int \| String> := 42) [int+ x 1]` | `'43` (occurrence-typed narrowing via `int+`) | **PPN Track 5 (occurrence typing)** |

The multi-success axis is the LOAD-BEARING discriminator: a sexp first-success commit would return `'Nat` (commits to first branch) and FAIL the `"Nat | Int"` substring match. Only non-committing semantics passes this axis. Without it, the parity test couldn't distinguish on-network from any first-success-commit alternative.

#### §9.3.5.6 Concrete implementation deliverables

**Code changes** (~250-350 LoC across multiple files):

1. **propagator.rkt** (+~30 LoC):
   - New cell-id constant: `(define decomposed-positions-cell-id (cell-id 17))`
   - Local merge function: `decomposed-positions-merge` — set-union over seteq (mirrors `retraction-stratum-merge` + `fork-contradiction-request-merge`; defined locally per propagator.rkt's cycle constraint with infra-cell.rkt)
   - Allocation in `make-prop-network` via `net-register-specialized-cell` per §4.6 framework: `#:tier 'warm #:storage 'general #:fires-on 'any-change` (mirrors 3A.0's cell-15/16 pattern). **NO `#:reset-value`** — cell-17 is NOT a stratum-request cell (no handler registered for it); it's a guard cell that the watcher READS and the handler WRITES. Persists across BSP rounds within a command; resets between commands via `reset-meta-store!` reconstruction
   - Drift assertion: `(unless (equal? actual-cid decomposed-positions-cell-id) (error ...))`
   - Provide: `decomposed-positions-cell-id`, `decomposed-positions-merge`
   - Update `let*` block at end of `make-prop-network` to use `net7` (latest cells CHAMP after cell-17 allocation) for fuel-cell-cache + worldview-cache-cache direct-ref lookups

2. **typing-propagators.rkt** (+~50-80 LoC):
   - `make-classifier-watcher-fire-fn tm-cid e` factory:
     ```
     (lambda (net)
       (define record (hash-ref (net-cell-read net tm-cid) e (hasheq)))
       (define cinhab-val (hash-ref record ':type classify-inhabit-bot-value))
       (define classifier (classify-inhabit-classifier cinhab-val))
       (cond
         [(not (expr-union? classifier)) net]
         [(set-member? (net-cell-read net decomposed-positions-cell-id) e) net]
         [else
          (define request-info (hasheq 'components (flatten-union classifier) 'tm-cid tm-cid))
          (net-cell-write net fork-on-union-request-cell-id (hasheq e request-info))]))
     ```
   - `install-classifier-watcher net tm-cid e` helper:
     ```
     (net-add-propagator net (list tm-cid) (list fork-on-union-request-cell-id)
       (make-classifier-watcher-fire-fn tm-cid e)
       #:component-paths (list (cons tm-cid (cons e ':type))))
     ```
   - Centralized invocation at install-typing-network's expr-* cases (one line per case OR centralized wrapper around the dispatch)
   - `process-fork-on-union` body addition (line 1077+): after decomposition, write `(seteq position)` to decomposed-positions-cell-id

3. **Test cell-id cascade** (3 files, same precedent as 3A.0's 15+16 cascade per §9.3.2.1):
   - tests/test-propagator.rkt: hardcoded next-cell-id expectations 17→18; user-cell base 17→18; batch sequence updates per §9.3.2.1 pattern (specific line numbers: 42, 72, 79, 199, 237)
   - tests/test-observatory-01.rkt: cell-meta-label "cell-17"→"cell-18" + siblings (lines 307-309 precedent)
   - tests/test-trace-serialize.rkt: totalCells expectations updated (lines 110, 124 precedent)

4. **Tier 2 reverse-lookup registration** in propagator.rkt (at lines 794-795 block; same module as the local merge definition):
   - `(register-merge-fn!/lattice decomposed-positions-merge #:for-domain 'monotone-set)` — mirrors 3A.b cleanup's cell-13 + cell-16 Tier 2 registration (per propagator.rkt:765-795 block). Gives cell-17 Tier 3 domain inheritance, classified as `'monotone-set` (SRE-validated comm + assoc + idem; structural classification for `:component-paths` enforcement when needed). Note: `register-merge-fn!/lattice` provided by merge-fn-registry.rkt (NOT infra-cell.rkt); propagator.rkt requires it directly, avoiding the propagator → infra-cell cycle.

4. **tests/test-elaboration-parity.rkt** (+~60-80 LoC):
   - Add new section "Phase 3A.c — Union types via ATMS (non-committing inhabitation)"
   - 4 active `parity-test` axes per §9.3.5.5
   - 1 `parity-test-skip` axis (`union-inhabitation-narrowing`) pointing to "PPN Track 5 (occurrence typing)"
   - DELETE the old `parity-test-skip 'union-narrow-by-constraint "Phase 10"` block (lines 423-427)

5. **tests/test-speculation-bridge.rkt** (+~30-50 LoC of assertion updates):
   - Migrate `union-tests` block (lines 245-274): 4 cases for `check e : (A|B)`. Update assertions to expect non-committing semantics (classifier preserved; not first-success commit)
   - Migrate map widening (lines 276-281): 2 cases for `(the (Map K <V1|V2>) ...)`. Same migration pattern.
   - Migrate pipeline integration (lines 309-318): 2 cases. Assertion updates as needed.
   - KEEP unchanged: QTT union speculation (lines 290-297) — exercises qtt.rkt:2329 (Parent Phase 4)
   - KEEP unchanged: Union exhaustion error tests (lines 336-380+) — exercises typing-errors.rkt:78 (Parent Phase 4)

**Code NOT touched in 3A.c**:
- typing-core.rkt:2385 (becomes production-dead per §9.3.5.4; Parent Phase 4 / PM 12 retires)
- qtt.rkt:2329, typing-errors.rkt:78, typing-core.rkt:1307, typing-core.rkt:1344 (Parent Phase 4)
- elab-speculation.rkt (3A.d retires entirely)
- test-elab-speculation.rkt (3A.d retires)
- elab-speculation-bridge.rkt (keeps alive via 4 remaining w-s-r callers)

#### §9.3.5.7 Sub-step partition for implementation

Per `workflow.md` Conversational Implementation Cadence: each sub-step ends with dialogue checkpoint. Maximum ~1 hour or 1 sub-step before checkpoint.

| Sub-step | Scope | Est. LoC | Checkpoint criterion |
|---|---|---|---|
| **3A.c.1** ✅ `ffa7149b` | cell-17 allocation infrastructure: propagator.rkt cell-id + merge + provide + allocation + drift assertion + Tier 2 registration + 3 test files cell-id cascade | ~70-90 (actual: +100/-32 = +68 net) | DONE 2026-05-22. Probe: 0 errors; cells +1 (60 vs 59 baseline; cell-17); cell_allocs +57 (cell-17 allocated per make-prop-network; reveals prop-network is created ~2x per command via solver-state-amb forks — inherited from cells 15/16, watching list observation). Targeted 64 tests / 4.2s PASS. Acceptance 0 errors. Full suite **8251 tests / 109.9s / 0 failures** (test count unchanged; wall within 118-127s variance; actually −7.2s vs post-3A.b 117.1s — variance / fresh GC). Adversarial 3-column VAG passed all 4 questions. Mini-audit caught 2 design-doc errors before implementation (#:tier nomenclature + #:reset-value mismatch + Tier 2 registration site) — fixed inline. |
| **3A.c.2** ✅ `4e8e9ad4` | `make-classifier-watcher-fire-fn` factory + `install-classifier-watcher` helper definitions in typing-propagators.rkt. NO invocations yet (helper added but dead). | ~40 (actual: +128) | DONE 2026-05-22. Helpers added + exported. Probe: cell_allocs 1552 IDENTICAL to 3A.c.1; cells 60 IDENTICAL; propagators 0 IDENTICAL — D-3A.c.2-no-invocation-leak STRUCTURALLY verified. Full suite **8251 / 108.8s / 0 failures** (vs 3A.c.1 8251/109.9s; -1.1s variance). Adversarial 3-column VAG passed all 4 questions. Pattern mirrors 3 precedents (make-branch-check-fire-fn line 1023, make-branch-contradiction-watcher-fire-fn line 1182, classify-inhabit-residuation install line 2158). |
| **3A.c.3** | **R7 reframe** (post-revert; per §9.3.6 audit + §9.3.7 mini-design): centralized inline-emit at type-map-write API + Part B cell-17 guard write in handler. Replaces original watcher approach. Decision rationale per R8 empirical fuel test (§9.3.6.8). | ✅ | Sub-steps R7.a ✅ + R7.b ✅ + R7.c ✅. Original watcher-based 3A.c.3 design (Part A universal install) confirmed structurally correct but quantitatively over-budget under TYPING-FUEL-LIMIT=200. R7 preserves β.1 universal coverage AND TYPING-FUEL-LIMIT divergence-detection signal. |
| **3A.c.3-R7.a** ✅ `0e08e08b` | Mini-audit: :type write sites + type-map-write/-unified API coverage. Persisted at §9.3.7.5 | doc-only | DONE 2026-05-22. 47 production :type writes flow through type-map-write/-unified APIs; 2 direct net-cell-write bypasses write contradiction sentinels (not union types) — R7 correctly skips. No coverage gap; D-R7-direct-write-bypass risk RESOLVED empirically. |
| **3A.c.3-R7.b** ✅ `0e08e08b` | Implement centralized inline-emit: `maybe-emit-fork-on-union-request` helper + type-map-write modification + Part B (cell-17 write in process-fork-on-union handler Step 5) | ~50 LoC (actual: +49 / -13 = +36 net) | DONE 2026-05-22. Helper checks (expr-union? type-val) + cell-17 guard before emit. type-map-write-unified delegates to type-map-write — picks up emit automatically (one function-pair change covers both API paths per audit). Verification: Probe 0 errors, cell_allocs=1552 IDENTICAL to baseline, 28 results match. Acceptance 0 errors. Targeted 103/103 PASS. Full suite **8246 tests / 108.0s / 0 failures** (vs 3A.c.2 baseline 8246/103.7s; +4.3s within 118-127s variance band). Adversarial 3-column VAG passed all 4 questions. |
| **3A.c.3-R7.c** ✅ `a4b33fce` | Retire 3A.c.2 classifier-watcher helpers (make-classifier-watcher-fire-fn + install-classifier-watcher; commit 4e8e9ad4); replace with historical-context comment pointing to git + §9.3.5 + §9.3.7 | ~-130 LoC | DONE 2026-05-22. Decision: RETIRE (per principled lean — "Stranded high-level abstraction after refactor" codification 2nd data point; Phase 9b γ multi-candidate watcher can resurrect from git when use case materializes). Helpers deleted; 2 provide exports removed; replaced with 6-line historical-context comment. Full suite **8251 tests / 117.7s / 0 failures**; probe + acceptance clean. Adversarial 3-column VAG passed all 4 questions. |
| **3A.c.4** ✅ `d5b6bdbf` | test-elaboration-parity.rkt: 4 active union-inhabitation axes + 1 skip-gated (narrowing → PPN Track 5); delete old `'union-narrow-by-constraint` block | ~60-80 (actual: +91 / -9 = +82 net) | DONE 2026-05-22. 4 active axes: preserved, flipped, multi-success (LOAD-BEARING DISCRIMINATOR — sexp first-success would FAIL `"Nat \| Int"` substring), all-fail. 1 skip-gated: narrowing → PPN Track 5. All-fail axis tests downstream unbound-variable symptom (honest framing per §9.3.5.5 — direct exhaustion-error in test-union-types-atms.rkt mechanism tests). Targeted parity tests: 29/29 PASS. Full suite **8255 tests / 117.3s / 0 failures** (+4 net vs R7.c 8251). Adversarial 3-column VAG passed all 4 questions; multi-success discriminator empirically proves on-network non-committing. |
| **3A.c.5** ✅ `77ea36e4` | test-speculation-bridge.rkt: 6 union test cases migrated with non-committing classifier substring assertions; 2 preserved as-is | ~30-50 (actual: +48 / -7 = +41 net) | DONE 2026-05-22. Suite 3 (Union Type Speculation): 3 migrations (left-succeeds + left-fails-right-succeeds + nested) + 1 preserve (both-fail error path). Suite 4 (Map Widening): 1 migration (union value-type) + 1 preserve (no-union test). Suite 6 (Pipeline): 2 migrations (union+polymorphic + multi-def). QTT (Suite 5) + Error Improvement (Suite 7) UNCHANGED per §9.3.5.6 (Parent Phase 4 territory). All 6 migrated tests add `(string-contains? result-str "Nat \| Bool")` substring assertions as LOAD-BEARING DISCRIMINATOR — would FAIL under sexp first-success commit. Existing prologos-error? assertions PRESERVED. Full suite **8255 / 117.8s / 0 failures**. Adversarial 3-column VAG passed all 4 questions. |
| **3A.c.6** ✅ `ba0a2bfd` | Adversarial 3-column VAG + commit + tracker + dailies (cumulative phase close) | doc | DONE 2026-05-22. All 4 VAG questions pass under cumulative adversarial framing (§9.3.8.2 catalogue/challenge/adversarial columns); all 7 D-3A.c-* drift risks addressed under adversarial verification (§9.3.8.2 row d); §9.3.5.9 completion criteria checklist all ✅ (§9.3.8.3); 6 methodology data points captured (§9.3.8.4). **3A.c CLOSED.** Next: 3A.d (elab-speculation.rkt retirement; §9.3.5.4). |

Total: 6 sub-steps; ~3-5 hours of focused implementation across one or two sessions.

#### §9.3.5.8 Drift risks named (for mid-flight principles challenge + close VAG)

- **D-3A.c-install-density**: per-position watcher install cost — measure via probe wall-time + cell_allocs counter at 3A.c.3 close. Expected ~30-50 watchers per command × 28 commands ≈ 1000 extra installs at suite scale; per-install CHAMP overhead ~2-3 μs → ~3 ms suite-wide. Within variance band. If wall regression >5s, investigate.
- **D-3A.c-cell-17-cascade**: cell-id cascade in 3 test files — mechanical pattern same as 3A.0's 15+16 cascade. Risk: missed test file. Mitigation: targeted-test-runner catches at 3A.c.1 close.
- **D-3A.c-fire-pattern-soundness**: re-fire concern resolved via guard cell. Verify empirically: under multi-fire scenarios (multiple :type writes to same position; classifier becomes union after multiple writes), watcher fires once decomposition writes guard. Multi-success axis (3A.c.4) exercises this.
- **D-3A.c-typing-core-2385-residual**: typing-core.rkt:2385 stays alive in sexp test paths. Verify production never reaches it. Risk: hidden recursive caller within typing-core.rkt:check that on-network elaboration triggers. Mitigation: at 3A.c.6 close, grep for `check ctx _ (expr-union _ _)` callers; verify none on the on-network path; if any found, surface as drift requiring scope expansion.
- **D-3A.c-axis-confirmation-bias**: each new axis should DISCRIMINATE between on-network and sexp first-success. The multi-success axis (`union-inhabitation-multi-success`) specifically does — a sexp first-success commit returns `'Nat` (first branch); non-committing returns `"Nat | Int"`. Mitigation: at 3A.c.4 close, mental check on each axis: "would the OLD mechanism pass this?" If yes for any axis, that axis is non-discriminating — add structural-discriminator language to assertion or replace with different surface property.
- **D-3A.c-test-speculation-bridge-coverage**: migrated tests must preserve coverage equivalence — what the OLD tests validated structurally should still be validated under non-committing semantics. Risk: migration silently reduces coverage. Mitigation: per-test-case migration with explicit before/after assertion comparison documented in commit message.
- **D-3A.c-bit-budget**: per OQ2 (§9.3.1.3), max aids per command ≤30 bits. With per-position watchers under β.1, decomposed-positions cell may grow large; but each decomposition still uses N=union-component-count aids (typically 2-3). Verify via PERF-COUNTERS `max-aids-per-command` at 3A.c.6 close.

#### §9.3.5.9 Completion criteria (3A.c close)

- All 6 sub-steps landed atomically (each with dialogue checkpoint per cadence discipline)
- Probe `examples/2026-04-22-1A-iii-probe.prologos`: semantic outputs match baseline (modulo expected post-3A.c changes for annotated union expressions producing non-committing classifier-preserved results)
- Acceptance file `examples/2026-04-17-ppn-track4c.prologos`: 0 errors
- All 4 active parity axes (`union-inhabitation-preserved`, `-flipped`, `-multi-success`, `-all-fail`) PASS
- 1 skip-gated axis (`union-inhabitation-narrowing`) present with explicit "PPN Track 5 (occurrence typing)" pointer
- test-speculation-bridge.rkt: 8-10 migrated cases PASS; QTT + exhaustion sections unchanged and still passing
- test-union-types-atms.rkt: existing mechanism tests still PASS (no regression to 3A.a/3A.b coverage)
- Full suite: 8251+ tests / within 118-127s variance band / 0 failures
- Adversarial 3-column VAG passed all 4 questions (catalogue / challenge / **adversarial** for each)
- Tracker row 3A.c marked ✅ with commit hash + key result summary
- Dailies entry per phase-completion protocol (steps a-d-e from `workflow.md`)
- D-3A.c-* drift risks each addressed in close VAG (catalogue ✓ + adversarial cross-check)

#### §9.3.5.10 Codification candidates surfaced during this mini-design

| Pattern | Data points | Status |
|---|---|---|
| **Opening a phase is invitation to deliberative dialogue, not solo implementation** | 2 (PPN Track 4 + this 3A.c) | GRADUATE to DEVELOPMENT_LESSONS.org at close |
| **3-column adversarial framing (catalogue / challenge / adversarial)** | Multiple this session | GRADUATE — refinement of existing 2-column codification (workflow.md, DESIGN_METHODOLOGY.org § VAG, CRITIQUE_METHODOLOGY.org § Cataloguing Instead of Challenging) |
| **Stranded high-level abstraction after refactor** | 1 (elab-speculation.rkt) | Watching list — graduate at 2nd-3rd data point |
| **Substrate gap: fire-once-when-predicate-matches (deferred-flag-consumption semantic)** | 1 (FP3 cell-17 guard patches at app layer) | Watching list — graduate when PReduce Track 1 or Phase 9b γ surfaces same gap |
| **Multi-axis parity testing for discriminating coverage** | 2 (2A.c orchestration parity + 3A.c union-inhabitation) | Watching list — refinement of "parity-test as design artifact" codification |
| **Centralized helper-invocation at install-typing-network's expr-* cases** | 1 (β.1 classifier-watcher install) | Watching list — pattern reusable for Phase 9b γ multi-candidate watcher; codify if 2nd data point lands |

#### §9.3.5.11 Cross-references

- **Decision 3 audit data**: §B of deliberative dialogue (Section B in the audit pass — preserved in dailies 2026-05-22 session entry)
- **Decision 1 (install pattern β.1 + FP3)**: §9.3.5.3 of this document
- **Decision 4 (3A.d scope)**: §9.3.5.4 + addendum §9.3.1.7 (Phase 9b multi-candidate inheritance) + addendum §9.3.5.4 (typing-core.rkt:2385 production-dead reading)
- **Decision 2 (parity axes)**: §9.3.5.5 + 2A.c orchestration-parity axes precedent (test-elaboration-parity.rkt:380-417)
- **Cross-track captures** (unchanged from §9.3.1.7):
  - Phase 3C: residuation error-explanation consumes worldview/contradiction infrastructure from 3A.b + cell-16 narrowing signal
  - Phase 9b: γ hole-fill multi-candidate inherits fork-on-union pattern + classifier-watcher install template
  - Parent Phase 4: typing-core.rkt:2385 + remaining 4 with-speculative-rollback callers retirement
  - PM Track 12: `current-prop-net-box` + box-bridge family retirement
- **Codifications graduated** (per §9.3.5.10): added to DEVELOPMENT_LESSONS.org alongside the 3A.b graduation ("Mini-Audit Must Verify Carrier Capability AND Check For Existing Helpers")

### §9.3.6 Phase 3A.c.3 re-approach mini-audit (post-revert, 2026-05-22)

The 3A.c.3 attempt (Part A universal `install-classifier-watcher` at TOP of `let install` body + Part B cell-17 guard write in `process-fork-on-union`) failed with 11 polymorphic trait-dispatch failures in tests like `test-collection-fns-01.rkt`'s `filter-list-eval` / `reduce-list-eval` / etc. The CHECKPOINT preserved 6 candidate hypotheses (H-compound-1 through H-compound-6) and 3 reframing options (R1/R2/R3). This subsection captures the thorough code audit (A1–A10) that ran before any re-attempt, resolving hypothesis status and surfacing additional reframings.

#### §9.3.6.1 Audit scope and methodology

10 audit items in 3 tiers (per pre-audit scoping dialogue):
- **Tier 1** (foundational): A1 (install-typing-network structure), A2 (install-from-rule recursion), A3 (recover reverted 3A.c.3 code), A4 (test-collection-fns-01 failure analysis)
- **Tier 2** (mechanism understanding): A5 (`:type` write sites across compound fire-fns), A6 (component-paths precision), A7 (process-fork-on-union walk-through)
- **Tier 3** (peripheral signal): A8 (fuel pressure quantification), A9 (classify-inhabit-value edge cases), A10 (outer-entry vs recursive-entry distinction)

Mode: read-only investigation — no code changes; no test runs. Findings persist into this §9.3.6 (not dailies-only) per refined Stage 4 methodology.

#### §9.3.6.2 Tier 1 findings — foundational

**A1 — install-typing-network expr-* cases** (line 2220+):

Structure: `(let install ([net X] [e X] [ctx-pos X]) (match e ...))` at line 2234. The `install` named-let is the recursion entry; watcher install at TOP of `let install` body fires per recursive call.

Cases classified by `:type` write multiplicity:
- **Atomic** (single immediate write, no propagator): expr-int, expr-nat-val, expr-true, expr-false, expr-Int, expr-Nat, expr-Bool, expr-String, expr-Type, expr-fvar, expr-tycon
- **Meta** (initial ⊥; refined by meta-bridge): expr-meta
- **Compound — single-write potential**: expr-ann (direct write of annotation), expr-generic-from-int/rat (direct write of target-type)
- **Compound — multi-write potential**: expr-app, expr-lam, expr-Pi, expr-reduce, expr-pair, expr-union, expr-bvar (each has fire-fns that write `e`'s `:type` and can fire multiple times as children refine)
- **Default**: SRE typing-domain dispatch via `install-from-rule` (recurses into install-typing-network for children)

Bisection map (assuming Part A added watcher atop `let install`):
- PASSING (expr-ann + expr-meta): single-shot `:type` writes; watcher fires once or twice
- FAILING (compound positions): multi-write `make-app-fire-fn` and similar wake the watcher on every refinement

**A2 — install-from-rule recursion** (lines 1874-1919):

install-from-rule calls install-typing-network recursively on children at lines 1886 (computed return-type path) and 1908 (constant return-type path). Two recursion layers exist:
1. Inner recursion (`let install`): same lambda, different `e` argument per call
2. Outer recursion (install-from-rule → install-typing-network): fresh outer entry, fresh root-ctx-pos gensym

**H-compound-3 (duplicate-install at same position) — STRUCTURALLY REFUTED**: ASTs are tree-shaped; each expression node visited exactly ONCE total per outer entry. A watcher install at the top-of-`let-install-body` executes once per recursive call → one watcher per position, NOT duplicates. The recursion is not the problem.

The reframing: not "duplicate installs" but "per-position fire-multiplicity":
- expr-ann writes `e`'s `:type` ONCE at install (direct `type-map-write`)
- expr-app does NOT write at install; `make-app-fire-fn` writes MULTIPLE times as func/arg refine
- Watcher co-installed on `e`'s `:type` wakes on EACH refinement → fuel pressure (A8 dominant finding)

**A3 — Reverted 3A.c.3 code reconstruction**:

The 3A.c.3 attempt was reverted at working-tree level only (never committed). Reconstruction from CHECKPOINT prose + audit:

```racket
;; Part A: at line 2234+ (top of `let install` body)
(let install ([net net-with-ctx] [e expr] [ctx-pos root-ctx-pos])
  (define net (install-classifier-watcher net tm-cid e))   ; ← added line
  (match e ...))

;; Part B: at line ~1145+ in process-fork-on-union (after watcher install for/fold)
(net-cell-write n6 decomposed-positions-cell-id (seteq position))
```

**Major discovery via `git show de453f69`**: The ORIGINAL FIRST 3A.c attempt (Posture A — install-time pre-write at expr-ann) was empirically working (8251 tests / 109.7s / 0 failures), and its commit message **explicitly anticipated the watcher re-fire problem** that bit 3A.c.3:

> *"Watcher approach was unnecessarily complex: Re-fire problem — branch propagator writes to :type trigger watcher again (via component-path match), watcher reads classifier under outer wv (still union), re-writes to cell-15, handler re-decomposes → wasteful or infinite. Mitigations require additional infrastructure: decomposed-positions guard cell (cell-17 + cell-id cascade), or two-stage delayed install, or fire-once with first-write-is-union assumption."*

The deliberative re-do (§9.3.5) REJECTED Posture A on Decision 3 + Decision 1 principle aggregation (10+ principles favoring β.1 + FP3), citing Posture A as multi-anti-pattern (belt-and-suspenders, Validated ≠ Deployed, etc.). It then BUILT exactly the mitigation infrastructure the original author had named as undesirable (cell-17 guard) — which mitigates "re-decomposes" but does NOT mitigate "wasteful fires" (the watcher still wakes on every `:type` write).

**A4 — test-collection-fns-01.rkt failure analysis**:

Failing tests in this file exercise generic collection functions imported from `prologos::core::collections`: filter, reduce, reduce1, length, any?, all?, etc. User-facing call `(filter pos? '[0N 1N 2N 0N 3N])` elaborates to `[filter Nat ?m22716 ?m22717 ?m22721 test::pos? '[0N 1N 2N 0N 3N]]` — six positions, three of which are unsolved metas (trait dictionaries + element type witness).

Trait-resolution must converge by inferring element type from literal → looking up `(Foldable List)`/`(Buildable List)` impls → unifying dictionary metas → substituting through curried Pi chain. Each round writes `:type` at multiple positions as metas refine through the Pi chain.

AST depth: ~6 curried `expr-app` levels × 2-3 sub-positions each = **~15-20 compound positions per failing test**. Adding 15-20 watcher propagators wakes 36-60 times per call → fuel pressure (A8).

#### §9.3.6.3 Tier 2 findings — mechanism understanding

**A5 — `:type` write multiplicity across compound fire-fns**:

| Fire-fn | Writes `e`'s `:type` | Re-fire pattern |
|---|---|---|
| `make-app-fire-fn` (1653) | YES + downward `:type` to arg-pos | Multi-fire as func/arg refine |
| `make-lam-fire-fn` (1737) | YES (Pi assembly) | Multi-fire as dom/body refine |
| `make-pi-fire-fn` (1752) | YES (Type at lmax) | 1-2 fires |
| `make-union-fire-fn` (1777) | YES (Type at lmax) | 1-2 fires |
| `make-app-fire-fn` feedback (1694+) | `term-map-write` to dom | Multi-fire |

Position write-multiplicity classification:
- Single-write: atomic, expr-fvar/tycon, expr-ann e-position, expr-Pi e-position, expr-union e-position
- **Multi-write**: expr-app e-position, expr-app arg-position, expr-lam e-position

For polymorphic dispatch `[filter Nat ?m1 ?m2 ?m3 test::pos? '[...]]`:
- 6 expr-app × 2 positions = 12 multi-write positions
- ~3-5 `:type` refinements per position during convergence
- **Watcher wake-ups: 36-60 per polymorphic call**

**A6 — Component-paths precision**:

Watcher declares `:component-paths (list (cons tm-cid (cons e ':type)))`. Verified precise:
- `pu-value-diff` emits `(cons position facet)` pairs for nested-hasheq attribute-map writes
- `filter-dependents-by-paths` matches by `equal?` between declared `(cons e ':type)` and changed-set entries
- Watcher fires ONLY on `:type` writes at position e — NOT siblings, NOT other facets

Residuation propagator (line 2283) has IDENTICAL precision but is installed ONLY at expr-meta positions. **The precision pattern is proven-working**; what differs in 3A.c.3 is **install scope**, not declaration precision.

**A7 — process-fork-on-union walk-through**:

Handler steps:
1. Allocate N aids via `solver-state-amb`
2. Initialize worldview-cache (N branch bits)
3. `promote-cell-to-tagged` on attribute-map (3A.b load-bearing)
4. Install N branch check propagators (wrapped at branch worldview)
5. Install N fire-once contradiction watchers (wrapped at branch worldview)

Part B (reverted) would add Step 6: cell-17 guard write. Why Part B alone is harmless: handler runs only when cell-15 has entries; without Part A, no entries are ever written; handler never invoked; cell-17 stays empty.

Handler narrowing pattern is sound and downstream-correct. The problem is purely **install scope** at install-typing-network.

#### §9.3.6.4 Tier 3 findings — peripheral signal

**A8 — Fuel pressure quantification — H-compound-4 CONFIRMED as leading mechanism**:

`TYPING-FUEL-LIMIT = 200` (line 2697). Set per-elaboration via `net-cell-reset` on canonical tropical-fuel cell (Phase 1B); restored at close.

| Test class | Compound positions | Watcher wake-ups | Baseline TR fuel | Total | vs 200 budget |
|---|---|---|---|---|---|
| Simple def | 0-2 | 0-2 | ~10-20 | ~10-25 | comfortable |
| Single-meta dispatch | 3-5 | 6-15 | ~50-80 | ~56-95 | comfortable |
| **Polymorphic trait dispatch** | **15-20** | **45-100** | **~150-170** | **~195-270** | **AT OR OVER budget** |
| Deeply curried | 20-30 | 60-150 | ~170-200 | ~230-350 | OVER budget |

Bisection table fits H-compound-4 cleanly. Empirically testable: temporarily bump TYPING-FUEL-LIMIT to 1000 → if failing tests pass, mechanism confirmed.

Even early-returning watcher fires consume fuel — the wake-up itself is the cost, not whether work is produced. This is exactly what the FIRST attempt commit message warned about (3A.c.3 reverted in pure form).

**A9 — classify-inhabit-value edge cases**:

Watcher's early-return logic is correct across all edge cases (uninitialized position, classifier-only, both layers populated, contradiction sentinel, post-decomposition with FP3 guard, tagged-cell under outer/branch worldview). The watcher does NOT produce spurious requests; FP3 guard prevents re-emission after decomposition. Correctness is sound — failure is purely from wake-up frequency consuming fuel.

**A10 — Outer-entry vs recursive-entry**:

install-typing-network is invoked from 2 outer sites (infer-on-network) + 2 recursive sites (install-from-rule lines 1886, 1908). Setup code (root-ctx-pos gensym + that-write) re-executes per outer entry. Inner `let install` recursion is per-sub-expression.

R5 (outer-only install) is NOT VIABLE — would only cover top-level expressions, missing sub-expressions where unions could arrive.

But the structural distinction surfaces R7 (in-rule inline pre-write) — see §9.3.6.6 options matrix.

#### §9.3.6.5 Hypothesis status post-audit

| Hypothesis | Status | Evidence |
|---|---|---|
| H-compound-1 (co-write conflict) | **CONTRIBUTING** | Multi-write at compound positions IS the trigger; but the conflict isn't "interaction between propagators" — it's wake-up frequency on multi-write positions |
| H-compound-2 (timing interference) | UNLIKELY | Watcher's early-return is correct (A9); no timing interference produced — just scheduling overhead |
| H-compound-3 (duplicate installs) | **REFUTED** | Tree-shaped ASTs; each position visited exactly once; no N² blow-up |
| **H-compound-4 (fuel pressure)** | **CONFIRMED — leading mechanism** | Wake-up arithmetic (A8) fits bisection table; ORIGINAL FIRST attempt explicitly warned about this |
| H-compound-5 (install-order coupling) | UNLIKELY | Watcher is installed FIRST in 3A.c.3 attempt; passing/failing pattern follows position write-multiplicity, not order |
| H-compound-6 (compound-case reader) | UNLIKELY | Watcher writes to cell-15 (not other propagator's input cells); no semantic interference |

**Mechanism summary**: every `:type` write at a watched position wakes the watcher. Multi-write compound positions produce 3-5 wakes each. At ~15-20 compound positions per polymorphic dispatch test, watcher overhead consumes 22-50% of TYPING-FUEL-LIMIT — enough to push trait-resolution over budget for non-trivial inputs.

#### §9.3.6.6 Reframing options matrix (3-column adversarial framing)

Each option presented with TWO+ONE columns: catalogue (does it satisfy?), challenge (could it be more aligned?), **adversarial** (where does it BREAK / what would refute it?).

**R1 — Semantic-distinction β (install at expr-ann + expr-meta only)**:

| Column | Content |
|---|---|
| Catalogue | Matches bisection-passing configuration empirically (14/14 PASS). Aligns watcher install with positions where unions can structurally ARRIVE (annotation, meta downward write). |
| Challenge | "Semantic distinction" still requires case enumeration — what defines "where unions can arrive" structurally? Is this just β.3 dressed up with principle-aligned vocabulary? |
| **Adversarial** | The Hyperlattice Conjecture explicitly REJECTED case enumeration in Decision 1's principle aggregation. Adopting R1 means **REVERSING Decision 1** — the principles cited then must now be re-evaluated against the empirical finding. Specifically: Correct by Construction (still served if "structural arrival" is structurally defined), Completeness over Deferral (NOT served — Source A inferred unions deferred; same Posture A objection re-emerges), Most Generalizable Interface (NOT served — two semantic categories of positions). If we adopt R1, we're admitting principle-aggregation can be empirically wrong AND the Hyperlattice Conjecture's "no case enumeration" guideline has exceptions tied to mechanism cost. That's a methodology lesson worth codifying. |

**R2 — β.1 with fuel-limit increase**:

| Column | Content |
|---|---|
| Catalogue | Simplest fix; preserves principle aggregation from Decision 1 unchanged; TYPING-FUEL-LIMIT is a tunable parameter. |
| Challenge | Is 200 the "right" limit, or was it the minimum needed pre-3A.c? Increasing to mask watcher overhead is a band-aid for an architectural inefficiency. |
| **Adversarial** | Raising fuel limit **does not fix** the wasteful-fire pathology — it masks it. Every early-return fire still consumes fuel doing nothing. Future load increases (more complex polymorphic dispatch in user code, Phase 9b γ hole-fill, Track 7 user grammar extensions) compound the inefficiency. The mechanism is fundamentally wasteful; fuel-limit raises move the failure threshold but don't address the cause. Also: TYPING-FUEL-LIMIT was likely tuned for production divergence detection; raising it changes that signal. We'd need to verify no real divergence cases become hidden. |

**R3 — Defer 3A.c entirely**:

| Column | Content |
|---|---|
| Catalogue | Safe; doesn't ship anything broken. |
| Challenge | 3A.c IS the substantial deliverable of Phase 3A; deferring means union-types-via-ATMS doesn't actually reach user-facing typing pipeline. What specifically would change with more design time? |
| **Adversarial** | We've completed thorough audit (A1-A10) — the mechanism is well-understood. Deferral without a concrete next-design-attempt sets up indefinite punt. R3 should be paired with EITHER a specific design gap to fill OR honest acknowledgment that Phase 3A.c's charter can't be delivered within current architecture (which would be a major reframing affecting Phase 3 entirely). |

**R4 — Hybrid (install-time pre-write at expr-ann + watcher at expr-meta only)**:

| Column | Content |
|---|---|
| Catalogue | Two-mechanism for two-source; both principled (install-time pre-write for known unions; watcher for emergent meta unions). Matches bisection-passing configuration. |
| Challenge | Two mechanisms for what's conceptually one concern (union detection + decomposition request). Is this decomplection (separate sources, separate mechanisms) or over-engineering (one concern doubled up)? |
| **Adversarial** | The watcher at expr-meta still pays per-meta wake-up cost as the meta's classifier refines. For metas that participate in trait resolution (most metas in failing tests), classifier refinement happens multiple times. If R4's watcher-at-expr-meta-only fires 5-10 times per polymorphic dispatch test, fuel pressure may STILL push budget over the edge for the deepest polymorphic tests. Empirical validation needed before adoption. Also: residuation propagator at expr-meta already exists; would another watcher there be redundant or complementary? |

**R7 — In-rule inline pre-write (zero extra wake-ups)**:

| Column | Content |
|---|---|
| Catalogue | Zero extra propagator fires — union-detection happens inline with existing work (make-app-fire-fn, make-pi-fire-fn, T-3 merge-fn, etc.). Matches Data Orientation philosophy: data drives the request. |
| Challenge | Spreads union-detection across N fire-fns. Decomplection question: is "compute type and write" + "if type is union, also emit cell-15 request" a single concern (type emergence) or two? |
| **Adversarial** | (1) **Completeness audit burden**: every union-producing type-write needs the check. Missing one site is a latent gap; the audit is empirically rare-to-find. (2) **Coupling concern**: each fire-fn now has TWO outputs — its computed type write AND a side-effect cell-15 write. Violates single-responsibility (debatable; could argue both are "what this propagator emits"). (3) **Sources we need to cover**: app-fire-fn's `(subst 0 arg-pos cod)` result; pi-fire-fn's Type construction (doesn't produce unions); lam-fire-fn's Pi construction (doesn't produce unions); type-lattice-merge's union fallback (Role A path); SRE typing-domain rules with computed return-type. (4) **Future-extension friction**: Phase 7 trait dispatch returning union types would need its own inline check in the trait-resolution propagator. Track 4D's attribute grammar substrate would need to propagate the check across all rule kinds. Watcher approach is uniform; R7 distributes it. |

**R8 — Empirical-fuel-test prerequisite (process step, not architectural option)**:

| Column | Content |
|---|---|
| Catalogue | Before committing to R1/R2/R4/R7, EMPIRICALLY validate H-compound-4 by temporarily bumping TYPING-FUEL-LIMIT to 1000 and re-running the failing tests with reverted 3A.c.3 code re-applied. If they PASS → fuel confirmed → choose architectural option with informed data. If they FAIL → another mechanism is contributing (H-compound-2/5 escape); need broader investigation. |
| Challenge | Adds a session of work before architectural decision. Risks: the temporary bump might mask other latent issues that would surface at the higher budget; the test environment might differ subtly from production paths. |
| **Adversarial** | If R8 PASSES the fuel test, we have STRONG empirical evidence that the principle-aggregation in Decision 1 missed a quantitative consideration (fuel cost per fire). That's a methodology lesson — principle-guided design alone is insufficient when mechanism overhead has empirical cost. If R8 FAILS the fuel test, we've spent a session on a misdiagnosis — but the audit data still narrows the next investigation. **R8 is a prerequisite, not an option** — without empirical confirmation of mechanism, we'd be choosing R1/R4/R7 based on hypothesis, not data. |

#### §9.3.6.7 Cross-references

- Original FIRST 3A.c attempt: commit `de453f69` (Posture A, install-time pre-write at expr-ann)
- Revert of original: commit `e267206b` (revert) + `a8eed7e2` (dailies-revert)
- Deliberative re-do design: §9.3.5 + commit `e6ca1f80`
- 3A.c.1 cell-17 infrastructure: commit `ffa7149b`
- 3A.c.2 helper definitions: commit `4e8e9ad4`
- 3A.c.3 reverted attempt: working-tree only, never committed (CHECKPOINT in dailies preserves design)
- Audit dialogue: dailies 2026-05-22 (this session)

#### §9.3.6.8 R8 empirical fuel-test result (2026-05-22, working-tree only)

Per the R8 prerequisite from §9.3.6.6 reframing options matrix, the empirical fuel test was executed before architectural commitment:

**Procedure**:
1. Re-applied 3A.c.3 Part A (universal `install-classifier-watcher` at TOP of `let install` body via `set!`)
2. Re-applied 3A.c.3 Part B (cell-17 guard write captured as Step 5 of `process-fork-on-union`)
3. Temporarily bumped `TYPING-FUEL-LIMIT` 200 → 1000
4. All changes working-tree-only; reverted after measurement

**Results**:

| Configuration | Tests | Wall | Failures | Notes |
|---|---|---|---|---|
| 3A.c.2 baseline (no Part A/B; fuel=200) | 8246 | 103.7s | 0 | CHECKPOINT baseline |
| 3A.c.3 + fuel=200 | — | — | **11** (polymorphic dispatch) | CHECKPOINT diagnostic |
| **3A.c.3 + fuel=1000** | **8251** | **108.0s** | **0** | R8 result (this measurement) |

Targeted runs as canaries (all PASS under R8):
- `tests/test-collection-fns-01.rkt`: 14/14 PASS (4.2s)
- `tests/test-collection-fns-02.rkt`: 15/15 PASS (4.7s)
- `tests/test-elaboration-parity.rkt`: 25/25 PASS (1.2s)

**Conclusion — H-COMPOUND-4 (FUEL PRESSURE) EMPIRICALLY CONFIRMED as the leading mechanism**:

The architectural design of 3A.c.3 (Part A + Part B with cell-17 guard) is **structurally correct**. All 8251 tests pass under the universal β.1 install + FP3 guard pattern when fuel budget is sufficient. The 11 failures under fuel=200 were exclusively from watcher wake-up overhead consuming budget that polymorphic-trait-dispatch trait-resolution needed for convergence.

This vindicates Decision 1's principle aggregation (β.1 + FP3 IS architecturally sound) while exposing a quantitative axis the aggregation did not consider (per-fire fuel cost on multi-write positions). The principles-vs-reality conflict resolves to: **the principles were correct on the architecture; the missing consideration was mechanism overhead in production polymorphic workloads**.

**Methodology data point** (graduate to DEVELOPMENT_LESSONS.org candidate after one more data point):

> *Principle-aggregation can be architecturally correct yet quantitatively insufficient. When a mechanism is principled but adds per-event overhead at scale, the principles-aggregation framework needs a quantitative-cost lens alongside the structural lens. The diagnostic protocol exists for exactly this case — when principles favor one direction yet implementation breaks, the empirical conflict often reveals a missing quantitative dimension (here: per-fire fuel cost × per-position write multiplicity), not a wrong-architecture problem. Adopt the architecture; address the cost separately.*

Data points to-date for this codification candidate:
1. PPN 4C Tropical Quantale Addendum Phase 1V's Item #1 (cache miss surfaced via §13.7 gate decision-tree gap; quantitative measurement reshaped architectural choice)
2. PPN 4C Phase 3A.c.3 R8 (this finding; principle aggregation correct, fuel cost dimension missing)

**Reframing options matrix update** (post-R8 empirical data):

| Option | Status post-R8 |
|---|---|
| R1 — Semantic-distinction β | Still viable but ARCHITECTURALLY LESS PRINCIPLED than β.1 was. Adopting R1 means trading architectural completeness for fuel efficiency. Decision 1's principle aggregation stands; R1 would be empirical pragma. |
| **R2 — β.1 + fuel-limit increase** | Now viable. Empirically validated by R8. Adversarial concern (band-aid) somewhat softened by data: the architecture IS correct; we're funding its mechanism cost. |
| R3 — Defer 3A.c entirely | NOT NEEDED — R8 shows we have a working architecture. R3 was contingent on no-viable-path; that's refuted. |
| R4 — Hybrid (pre-write expr-ann + watcher expr-meta) | Still viable but adds complexity vs R2 simplicity OR R7 elegance. Mid-tier option. |
| **R7 — In-rule inline pre-write** | **STRONGEST architectural choice**. Zero extra wake-ups. Matches Data Orientation (computed type IS the data; emit request inline). Achieves β.1's structural coverage WITHOUT fuel cost. The completeness audit burden is the trade-off (vs R2's simplicity). |

**Cross-track impact of R8 finding**:

The TYPING-FUEL-LIMIT mechanism's purpose is divergence detection at the elaboration boundary. If R2 is chosen (bump to 1000), the divergence detection signal weakens — runaway elaborations now have 5× longer to manifest before fuel triggers. This is acceptable IF:
- Production polymorphic dispatch needs ≤ 200 fuel under baseline (no watcher)
- Watcher overhead is ~50 fuel per polymorphic call max
- Total under R2 is ~250-300 fuel; 1000 limit gives ~3× safety margin
- Real divergence (e.g., recursive type metas without termination) typically exceeds 1000 fuel by orders of magnitude — still caught

But the divergence-detection-signal-weakening is a real cost. R7 avoids this entirely (zero overhead → keep TYPING-FUEL-LIMIT = 200 — divergence signal preserved at its tuned threshold).

**Recommended decision direction** (presented for user direction):
- **R7** is the architecturally-strongest answer: preserves both Decision 1's principle aggregation AND TYPING-FUEL-LIMIT's divergence-detection signal
- **R2** is the simplest answer: 1-line config change + R8's existing 3A.c.3 design + accept fuel-budget shift
- **R7 → R2-fallback** sequence: attempt R7 first; if completeness-audit-burden exceeds expected scope, fall back to R2 with explicit "Phase 9b γ hole-fill will need a more efficient mechanism anyway" documentation

### §9.3.7 Phase 3A.c.3 R7 mini-design (committed effort, no fallback — 2026-05-22)

User direction post-R8: *"give R7 a committed effort. No fallback. If effort is greater than a session, then we can checkpoint and pick it back up. I like being complete and principally aligned, rather than an expedient implementation shortcut. Language design and implementation needs rigor, resolve, and strong principles."*

R7 selected over R2 (the simpler fuel-bump option) because R7 preserves both Decision 1's principle aggregation (β.1 universal coverage) AND TYPING-FUEL-LIMIT's divergence-detection signal (no per-fire-fn overhead from a watcher mechanism).

#### §9.3.7.1 Implementation pattern — centralized at the type-write API

R7's original sketch was "per-fire-fn enumeration": modify each compound case fire-fn (make-app-fire-fn, etc.) to check if the computed type is a union and emit a cell-15 request inline. The mini-design refined this to a more architecturally aligned variant: **centralize the inline union-detection at the `:type` write API**.

The two type-write API functions in typing-propagators.rkt:
- `type-map-write` (line 585): writes `type-val` to attribute-map at `(position, :type)`
- `type-map-write-unified` (line 603): Role B equality-enforce variant; computes `(type-unify-or-top current expected)` then writes via type-map-write

R7's implementation adds at the API layer (not at each caller):
```racket
;; After write (in both type-map-write and type-map-write-unified)
(cond
  [(expr-union? type-val)
   (cond
     [(set-member? (net-cell-read net decomposed-positions-cell-id) position) net]  ; cell-17 guard
     [else
      (define components (flatten-union type-val))
      (define request-info (hasheq 'components components 'tm-cid tm-cid))
      (net-cell-write net fork-on-union-request-cell-id
                      (hasheq position request-info))])]
  [else net])
```

| Per-fire-fn enumeration (original R7 sketch) | Centralized at type-map-write (refined R7) |
|---|---|
| Modify N fire-fns (~5-8 sites) | Modify 2 functions (type-map-write, type-map-write-unified) |
| Each fire-fn's contract becomes "compute type + maybe emit request" — multi-responsibility | type-map-write contract stays "write the type and emit request if union" — single responsibility at the API layer |
| Audit completeness burden: did we catch every union-producing fire-fn? | Audit completeness reduces to: does every `:type` write go through these two APIs? |
| Future tracks (Phase 9b γ, Phase 7 trait dispatch) need their own per-fire-fn checks | Future tracks pick up the behavior for free — any `:type` write through the API gets it |

The centralized variant is the **Data Orientation realization** of the original idea: the type-write API IS the data-driven boundary; the union check happens at the moment the data is written, not when observed (watcher) and not at the propagator level (per-fire-fn).

#### §9.3.7.2 3-column adversarial framing — centralized R7

| Column | Content |
|---|---|
| **Catalogue** | One function-pair to modify (type-map-write + type-map-write-unified); inline `(expr-union? type-val)` check + cell-15 emit if guarded by cell-17. Zero extra propagator wakes. Preserves TYPING-FUEL-LIMIT divergence-detection signal. β.1 universal coverage achieved structurally. Composes naturally with Phase 9b γ + Phase 7 trait dispatch (any future write at the API gets the behavior). |
| **Challenge** | Are we sure ALL `:type` writes go through type-map-write or type-map-write-unified? Direct `net-cell-write` to attribute-map might exist somewhere — would bypass the inline emit. Grep needed (R7.a audit). Also: is type-map-write the natural seam, or is `that-write` (the user-facing API) the higher-leverage seam? |
| **Adversarial** | (1) **Hidden direct writes**: any `net-cell-write` to attribute-map that constructs a hasheq update at position e's `:type` facet would bypass type-map-write. Need exhaustive grep across production code. (2) **`that-write` higher-leverage?**: `that-write` is the user-facing API; if we centralize at `that-write`, we cover ALL facet writes. But `that-write` is generic; embedding `:type`-specific union-check there violates separation of concerns. **type-map-write IS the right granularity** — facet-specific API for facet-specific behavior. (3) **Re-entry concern**: if type-map-write emits to cell-15, the handler runs between BSP rounds. If during the handler's branch-check propagator installs, those propagators call type-map-write internally, we have re-entry. cell-17 guard prevents re-decomposition but the inline-emit fire might still occur during handler-installed propagator fires. Verify cell-17 guard is checked BEFORE emit decision. (4) **Cost on every :type write**: even non-union writes pay the `(expr-union? type-val)` predicate cost. For ~1000+ :type writes per command, the cost is ~1000 predicate calls — small (O(1) struct-tag check) but non-zero. Trade-off vs no-op watcher fires under the rejected approach. (5) **3A.c.2 helpers become dead code**: `make-classifier-watcher-fire-fn` + `install-classifier-watcher` (commits `4e8e9ad4`) have no use case under R7. They were designed for the watcher approach. Decision deferred to R7.c based on R7.b implementation experience. |

#### §9.3.7.3 Sub-step partition

Per Conversational Implementation Cadence — each sub-step ends with dialogue checkpoint:

| Sub-step | Scope | Est. LoC | Checkpoint criterion |
|---|---|---|---|
| **3A.c.3-R7.a** | Mini-audit: grep `:type` write sites; verify all go through type-map-write/type-map-write-unified; identify direct-net-cell-write bypasses. Persist findings here in §9.3.7.5 | doc-only | Comprehensive site enumeration + classification |
| **3A.c.3-R7.b** | Implement centralized inline-emit in type-map-write + type-map-write-unified. cell-17 guard check inline; cell-15 emit when union detected and not in guard. | ~30-50 | Probe + acceptance + targeted tests PASS; semantic outputs match baseline (with new behavior for annotated union case) |
| **3A.c.3-R7.c** | Retire OR defer 3A.c.2 classifier-watcher helpers based on R7.b experience | ~-130 (deletions) OR doc-only | Decision documented; if retired, exports cleaned |
| **3A.c.4** | test-elaboration-parity.rkt: 4 active axes + 1 skip-gated (per §9.3.5.5) | ~60-80 | 4 active parity axes PASS empirically |
| **3A.c.5** | test-speculation-bridge.rkt: migrate 8-10 union test cases (per §9.3.5.6) | ~30-50 | All bridge tests pass; QTT + exhaustion sections unchanged |
| **3A.c.6** | Adversarial 3-column VAG + commit + tracker + dailies | doc | All 4 VAG questions PASS under 3-column framing |

Estimated total: 3A.c.3-R7.a-c likely fits one session; 3A.c.4-.6 may extend to second session per cadence discipline.

#### §9.3.7.4 Drift risks named (for mid-flight principles challenge)

| Risk | Mitigation |
|---|---|
| **D-R7-direct-write-bypass**: some site directly `net-cell-write`s to attribute-map at :type facet, bypassing type-map-write | R7.a audit; grep for `net-cell-write.*attribute-map\|tm-cid` in all production .rkt files; classify each |
| **D-R7-cell-17-guard-ordering**: inline-emit must check cell-17 guard BEFORE writing cell-15 | Code review at R7.b commit; cell-17 read happens before cell-15 emit |
| **D-R7-handler-reentry**: handler's branch-check propagators may write to attribute-map under branch worldview; if type-map-write inline-emits there, we get reentry | Guard cell-17 catches reentry (position already decomposed → skip). Verify under multi-branch test scenario in R7.b |
| **D-R7-3A.c.2-helpers-dead-code**: classifier-watcher helpers + install-classifier-watcher become unused | R7.c decision; documented either way |
| **D-R7-perf-on-non-union-writes**: inline `(expr-union? type-val)` check pays predicate cost on every :type write | Predicate is O(1) struct-tag check; should be negligible vs CHAMP write cost. Microbench if concern surfaces in test wall-time |
| **D-R7-position-knowledge**: type-map-write knows position e (parameter); type-map-write-unified also knows position. cell-17 guard requires set-member? on position. No coverage gap | Verified by API signatures |
| **D-R7-Tier-2-coverage**: type-map-write and type-map-write-unified are the only :type write APIs — but verify the `that-write` generic API at :type facet doesn't bypass | R7.a audit covers this |

#### §9.3.7.5 R7.a audit findings (2026-05-22)

Comprehensive grep across production code (excluding tests + benchmarks) for `:type` write paths:

**Layer 1 — type-map-write API surface**:
- `type-map-write` (typing-propagators.rkt:585): `(define (type-map-write net tm-cid position type-val) (that-write net tm-cid position ':type type-val))` — the canonical `:type` write API
- `type-map-write-unified` (line 603): Role B equality-enforce wrapper: `(type-map-write net tm-cid position (type-unify-or-top current expected))`

**Layer 2 — `:type` write call site enumeration**:

| Site count | Source |
|---|---|
| **45** | `type-map-write` call sites in production code (all flow through type-map-write → that-write at `:type`) |
| **2** | `type-map-write-unified` call sites: line 1676 (make-app-fire-fn arg-pos downward write; Role B equality enforcement); line 2451 (expr-ann case term position; Role B downward annotation enforcement) |
| **47 total** | through the centralized API pair |

**Layer 3 — Direct bypass audit (potential coverage gaps)**:

Grep for direct writes that bypass type-map-write/type-map-write-unified:

| Pattern | Hits in production | Classification |
|---|---|---|
| `(that-write ... ':type ...)` (outside type-map-write's body) | **0** | No direct `that-write` at `:type` bypasses |
| `(net-cell-write ... tm-cid ...)` direct attribute-map writes | **2** (lines 987-988, 1055-1056) | Both write `'classify-inhabit-contradiction` SYMBOL — NOT `expr-union` struct; R7's `(expr-union? type-val)` check correctly skips |
| `(net-cell-write attribute-map ...)` or `(that-write attribute-map ...)` (without going through tm-cid binding) | **0** | No alternate-binding bypasses |
| `current-attribute-map-cell-id` consumers | typing-propagators.rkt (definer + 4 internal) + batch-worker.rkt (test infrastructure) | No production write-bypass paths |

**Coverage conclusion**: R7 centralized at `type-map-write` + `type-map-write-unified` covers **100% of production `:type` writes that could yield union-typed values**. The 2 direct-write bypasses at lines 987-988 + 1055-1056 write contradiction sentinels (`'classify-inhabit-contradiction`), which are symbols not expr-union structs, so R7's inline check correctly does not fire on them — and these writes would NEVER be the right place to emit a fork-on-union request (they're WRITING contradictions discovered during typing, not propagating union annotations).

**No coverage gap. R7's centralized approach is complete.**

**D-R7-direct-write-bypass drift risk RESOLVED**: empirical audit confirms zero union-producing direct writes.

**Adversarial cross-check** (forcing the challenge):
- *"Are we sure the 2 direct bypasses can NEVER write a union?"* The values written are LITERAL symbols `'classify-inhabit-contradiction`, hardcoded into the source. The Racket constant cannot become an expr-union struct. Refuted as concern.
- *"Could a future site add a new direct net-cell-write bypassing type-map-write?"* Yes — but R7's coverage holds at TIME OF IMPLEMENTATION. Future bypasses would be a separate audit obligation. Codification candidate: add a lint rule that flags direct `(net-cell-write ... tm-cid ...)` with hash-shape constructing `:type` facet — but this is gold-plating; the current audit is sufficient.
- *"Is `that-write` at `:type` really only in type-map-write's body?"* Grep confirms exactly one match: line 586, which is type-map-write's definition. No external `that-write` at `:type` exists.

**Test-fixture sites** (intentionally not audited above per "production only" scope): test files may have direct `(hasheq :type ...)` constructions for fixture setup. These would not be affected by R7 because:
- Test fixtures bypass the production network entirely OR set up isolated networks
- R7's check fires only when type-map-write is called with the attribute-map cell-id, which test fixtures generally don't do
- Worst case: test fixture's union-shaped fixture would trigger R7's emit, but the fork-on-union handler would be registered/unregistered with the test's network independently — no crosstalk

**Audit summary for R7.b**:
- Modify 2 functions (type-map-write at line 585, type-map-write-unified at line 603)
- Add ~10 lines inline check + cell-15 emit (per function, with cell-17 guard precondition)
- Total LoC change: ~25-30 lines
- No callers need modification
- No tests need modification (parity tests cover the behavior in 3A.c.4)

#### §9.3.7.6 Cross-references

- R7 selection rationale: §9.3.6.8 (R8 empirical result + post-R8 options matrix)
- 3A.c.2 helpers (R7.c candidate retirement): commit `4e8e9ad4`
- cell-17 infrastructure (R7 dependency): commit `ffa7149b`
- Original §9.3.5 deliberative-design (β.1 + FP3 watcher; R7 supersedes the watcher mechanism, preserves the β.1 + FP3 architectural intent)
- Phase 9b γ + Phase 7 trait dispatch downstream consumers: §9.3.1.7 + §9.3.5.11

### §9.3.8 Phase 3A.c overall close — cumulative adversarial 3-column VAG (2026-05-22)

Phase 3A.c objective per §9.3.5: integrate the fork-on-union mechanism (3A.0/3A.a/3A.b) with the user-facing typing pipeline via β.1 universal coverage + FP3 idempotence + non-committing inhabitation semantics.

#### §9.3.8.1 Cumulative arc summary

| Sub-step | Commit | Description |
|---|---|---|
| 3A.c.1 | `ffa7149b` | cell-17 (decomposed-positions guard) allocation infrastructure + Tier 2 registration + 3 test-file cell-id cascade |
| 3A.c.2 | `4e8e9ad4` | classifier-watcher helper definitions (subsequently superseded by R7; retired at R7.c) |
| 3A.c.3-R7.a | `0e08e08b` | Thorough audit (A1-A10) + R8 empirical fuel test confirming H-compound-4 + R7 mini-design |
| 3A.c.3-R7.b | `0e08e08b` | Centralized inline-emit at type-map-write API (`maybe-emit-fork-on-union-request` helper) + Part B cell-17 write in handler Step 5 |
| 3A.c.3-R7.c | `a4b33fce` | 3A.c.2 helpers retired (~130 LoC deletion; stranded-abstraction codification 2nd data point) |
| 3A.c.4 | `d5b6bdbf` | 4 active union-inhabitation parity axes + 1 skip-gated (multi-success LOAD-BEARING DISCRIMINATOR) |
| 3A.c.5 | `77ea36e4` | 6 test-speculation-bridge cases migrated with non-committing classifier substring assertions + 2 preserved |
| 3A.c.6 | (this commit) | Phase close: cumulative adversarial 3-column VAG + tracker update + dailies entry |

**Process narrative**: Phase 3A.c had a non-trivial arc — the initial attempt (`de453f69`, "Posture A install-time pre-write at expr-ann") was REVERTED for bypassing deliberative dialogue discipline; the second attempt (deliberative re-do per §9.3.5, "Posture B β.1 universal watcher install") was REVERTED at working-tree level when it broke 11 polymorphic-trait-dispatch tests under TYPING-FUEL-LIMIT=200. The third attempt (R7 reframe, this arc) was the architecturally-strongest answer: centralize the union-detection inline at the type-write API, achieving β.1 universal coverage via Data Orientation (data drives behavior, not via watcher polling) AND preserving TYPING-FUEL-LIMIT divergence-detection signal (zero extra propagator wakes).

The arc captured 4 distinct methodology data points (see §9.3.8.4 below).

#### §9.3.8.2 Cumulative VAG — 4 questions × 3 columns

**Question (a) On-network?**

| Catalogue | Challenge | **Adversarial** |
|---|---|---|
| ✓ R7 inline-emit at type-map-write API is on-network (cell-17 read + cell-15 write). Cell-17 guard is on-network (set-union merge). Handler's Part B cell-17 write is on-network. Parity tests assert via run-ns-last (production network). Substring discriminators verify on-network behavior. | Could any 3A.c work have introduced off-network state? | Audit: zero new parameters, registries, or off-network state. Helper `maybe-emit-fork-on-union-request` is STATELESS (all state via net-cell-read/write). 3A.c.2 retirement REMOVED dead code (further reduced off-network surface). Test framework uses production network throughout. **Pass.** |

**Question (b) Complete?**

| Catalogue | Challenge | **Adversarial** |
|---|---|---|
| ✓ All 6 sub-steps landed atomically with dialogue checkpoints per Conversational Implementation Cadence. Coverage: 47 production :type write sites flow through type-map-write API; 100% covered by R7. Test coverage: 4 active parity axes + 6 substring-migrated speculation-bridge tests (multi-success discriminator load-bearing). Full suite: 8255 tests / 117.8s / 0 failures (vs pre-arc 8246 baseline; +9 net tests). | Shape OR benefit? Did we ship the architecture AND verify the benefit? | **Both delivered**: (1) Shape — R7 implementation lands at `0e08e08b`; mechanism is correct (per R8 empirical fuel test confirmation). (2) Benefit — multi-success axis empirically proves non-committing semantics work end-to-end (sexp first-success commit would FAIL the "Nat \| Int" substring match; R7 produces it). 6 test-speculation-bridge substring assertions add load-bearing discrimination beyond preserved "no error" coverage. **Shape + benefit both verified. Pass.** |

**Question (c) Vision-advancing?**

| Catalogue | Challenge | **Adversarial** |
|---|---|---|
| ✓ β.1 universal coverage achieved structurally (every :type write through API picks up R7). FP3 idempotence achieved structurally (cell-17 guard). Decision 1 principle aggregation PRESERVED. TYPING-FUEL-LIMIT divergence-detection signal PRESERVED. 3A.c.2 helpers retired (stranded-abstraction codification 2nd data point). Multi-axis discriminating coverage codification has 3 application sites this session. | Could the arc have been MORE aligned? | (1) R7 generalizes the original FIRST attempt's "install-time pre-write" pattern from install-time-known (annotations only) to type-write-time-computed (any union-producing source) — strict improvement in expressiveness. (2) Composition gain: Phase 9b γ + Phase 7 trait dispatch + Track 4D attribute grammar rules pick up R7's behavior for free when they write :type via the API — no per-track instrumentation needed. (3) Discriminating coverage pattern generalizes beyond parity tests to ANY test framework where assertions must distinguish architectural variants. (4) Honest framing of all-fail axis (downstream symptom; direct exhaustion testing in mechanism tests) IS more aligned than rationalizing — surfaces the test-framework limit explicitly. **Maximally aligned within Phase 3A.c scope. Pass.** |

**Question (d) Drift-risks-cleared?**

| Risk | Status post-arc | Adversarial verification |
|---|---|---|
| D-3A.c-install-density | NO LONGER APPLICABLE under R7 | R7 has ZERO extra propagator installs (vs original watcher approach which would have added 15-20 per polymorphic call). The risk presumed watcher approach; R7 architecturally eliminates it. |
| D-3A.c-cell-17-cascade | CLEARED at 3A.c.1 | cell-id 17 cascade verified across 3 test files (test-propagator + test-observatory-01 + test-trace-serialize); landed at `ffa7149b` |
| D-3A.c-fire-pattern-soundness | CLEARED via R7 structural idempotence | R7's inline check at type-map-write reads cell-17 BEFORE emit decision (code review verified); cell-17 guard makes re-emission STRUCTURALLY impossible (not flag-guarded, not downstream-deduped) |
| D-3A.c-typing-core-2385-residual | CLEARED via empirical grep | Grep confirms `with-speculative-rollback` only at qtt.rkt:2329 (Parent Phase 4 territory) + typing-errors.rkt:78 (kept alive per §9.3.5.4). Production goes through on-network via type-map-write → R7 → handler. Parent Phase 4 owns retirement when sexp paths broadly retire. |
| D-3A.c-axis-confirmation-bias | CLEARED at 3A.c.4 | Multi-success axis (`union-inhabitation-multi-success`) genuinely discriminates: sexp first-success returns `"0N : Nat"` → fails `"Nat \| Int"` substring; R7 non-committing returns `"0N : Nat \| Int"` → passes |
| D-3A.c-test-speculation-bridge-coverage | CLEARED at 3A.c.5 | All 6 migrated tests KEEP existing prologos-error? assertions AND ADD substring discriminators. Coverage equivalence preserved (no assertion deleted); discrimination added. Per-test-case before/after documented in commit `77ea36e4` message. |
| D-3A.c-bit-budget | CLEARED via PROVENANCE-STATS | Probe shows atms_hypothesis_count=5 across 28 commands ≈ 0.18 aids/command. Bit budget cap is 30 per command. Headroom: 167×. **No bit-budget concerns.** |

All 7 drift risks addressed under adversarial verification.

#### §9.3.8.3 Completion criteria checklist (§9.3.5.9)

- ✅ All 6 sub-steps landed atomically (each with dialogue checkpoint per Conversational Implementation Cadence)
- ✅ Probe `examples/2026-04-22-1A-iii-probe.prologos`: semantic outputs match baseline (cell_allocs=1552 IDENTICAL throughout 3A.c arc)
- ✅ Acceptance file `examples/2026-04-17-ppn-track4c.prologos`: 0 errors
- ✅ All 4 active parity axes (`union-inhabitation-preserved`, `-flipped`, `-multi-success`, `-all-fail`) PASS
- ✅ 1 skip-gated axis (`union-inhabitation-narrowing`) present with explicit "PPN Track 5 (occurrence typing)" pointer
- ✅ test-speculation-bridge.rkt: 6 migrated cases + 2 preserves PASS; QTT (Suite 5) + exhaustion (Suite 7) sections UNCHANGED and still passing
- ✅ test-union-types-atms.rkt: existing mechanism tests still PASS (no regression to 3A.a/3A.b coverage)
- ✅ Full suite: 8255 tests / 117.8s / 0 failures (within 118-127s variance band)
- ✅ Adversarial 3-column VAG passed all 4 questions (this §9.3.8.2)
- ✅ Tracker row 3A.c marked ✅ with commit hash + key result summary (this commit)
- ✅ Dailies entry per phase-completion protocol (companion commit)
- ✅ D-3A.c-* drift risks each addressed in close VAG (§9.3.8.2 row (d))

**Phase 3A.c CLOSED.**

#### §9.3.8.4 Methodology data points graduated to watching list / DEVELOPMENT_LESSONS.org

1. **"Principle-aggregation can be architecturally correct yet quantitatively insufficient"** (2 data points: PPN 4C Tropical Phase 1V Item #1 + 3A.c R8/R7 arc). The diagnostic protocol exists for exactly this case — when principles favor one direction with high confidence yet implementation breaks, the empirical conflict often reveals a missing QUANTITATIVE dimension (here: per-fire fuel cost × per-position write multiplicity), not a wrong-architecture problem. ADOPT THE ARCHITECTURE; ADDRESS THE COST SEPARATELY. **Promotion candidate to DEVELOPMENT_LESSONS.org at 3rd data point.**

2. **"Stranded high-level abstraction after refactor"** (now 2 data points: elab-speculation.rkt at §9.3.5.4 + 3A.c.2 helpers retired at R7.c). When refactoring SUPERSEDES an abstraction (the abstraction's body becomes a direct call to primitives, bypassing its own structure), the abstraction should be RETIRED in the same arc or immediate follow-up — not preserved "for future use." Git history + design doc capture the resurrection path; source code reflects what's CURRENT. **Promotion-eligible to DEVELOPMENT_LESSONS.org.**

3. **"Multi-axis parity testing for discriminating coverage"** (3 application sites this session arc: 2A.c orchestration-parity + 3A.c.4 parity axes + 3A.c.5 substring discriminators). When an architectural change introduces a new semantic property, tests must include assertions that would FAIL under the OLD variant. Single assertions like "no error" preserve coverage equivalence but don't discriminate. Pattern generalizes beyond parity-test framework specifically to ANY test framework where assertions must distinguish architectural variants. **Strong promotion candidate refining the existing "parity-test as design artifact" codification.**

4. **R7 generalizes "install-time pre-write" → "type-write-time pre-write"** — composition gain pattern. The original FIRST attempt's "install-time pre-write at expr-ann" covered install-time-known unions (annotations). R7 centralizes the pattern at the type-write API → covers ANY union-producing source (annotations + T-3 set-union merge + meta refinement + future trait dispatch returns + future grammar rule outputs). This is the "Data Orientation realization of the install-time pattern." **Watching list — promotion candidate when Phase 9b γ or Phase 7 trait dispatch picks up the pattern (3rd data point).**

5. **"3-column adversarial framing in concentrated use"** (catalogued/challenged/adversarial — refinement of 2-column codification). Applied uniformly across A11 synthesis, R7 mini-design, R7.b VAG, R7.c VAG, 3A.c.4 VAG, 3A.c.5 VAG, and this 3A.c.6 cumulative VAG. The adversarial column surfaced concrete drift candidates (Decision 1 reversal implications for R1, fuel-bump band-aid concern for R2, R7's completeness audit burden, all-fail downstream-symptom honest framing, etc.) that catalogue + challenge alone would have missed. **Validates the methodology refinement (user-articulated 3-column framing) at strong scale.**

6. **"Audit-driven scope refinement"** (3 data points this session — graduating). The original R7 sketch was "per-fire-fn enumeration"; R7.a audit revealed type-map-write-unified delegates to type-map-write, making "one function-pair change" structurally cleaner. The audit didn't just verify the design — it REFINED the design at the implementation boundary. This is the codified discipline (Stage 4 Per-Phase Protocol step 1+2 — co-dependent mini-design + mini-audit cycle) working as designed.

#### §9.3.8.5 Cross-track captures (post-3A.c)

Per §9.3.1.7 + this arc's discoveries, downstream consumers:

| Track | Capture |
|---|---|
| **Phase 3A.d** | `elab-speculation.rkt` retirement (§9.3.5.4) — sequential after 3A.c. Stranded high-level abstraction (zero production callers); retire whole file (188 LoC) + test (388 LoC). Already designed; ready for implementation. |
| **Phase 3B** | Hypercube primitives integration (§9.4) — Gray-code branch ordering + subcube pruning. Builds on 3A.b's contradiction watchers + 3A.c's cell-15 + cell-17 + cell-16 infrastructure. |
| **Phase 3C** | Residuation error-explanation (§9.5) — first downstream consumer of Form C cross-reference (§9.5.A). Consumes worldview/contradiction infrastructure from 3A.b + cell-16 narrowing signal + R7's inline-emit (type-write event provides natural derivation-chain anchor). |
| **Phase 9b** | γ hole-fill multi-candidate (§15) — inherits fork-on-union handler pattern + R7's centralized-at-API insight. Phase 9b's multi-candidate watcher CAN resurrect the retired 3A.c.2 helper pattern from git if needed, OR can adopt R7's inline-at-write-API pattern (now demonstrated). |
| **Parent Phase 4** | typing-core.rkt:2385 + qtt.rkt:2329 + typing-errors.rkt:78 + remaining 4 with-speculative-rollback callers — sexp-path retirement when meta-info CHAMP retires + PM 12 + on-network completion. |
| **PM Track 12** | `current-prop-net-box` + box-bridge family — Racket parameter scaffolding for module loading; out of 3A.c scope. |
| **PPN Track 5** | Occurrence typing (renamed `union-inhabitation-narrowing` skip-gated parity axis points here) — narrowing of union to single component via constraint propagation. |
| **PPN Track 4D** | Attribute Grammar Substrate Unification — R7's centralized-at-API pattern composes naturally with grammar-rule compilation (rules write :type via type-map-write → R7 picks up automatically; no per-rule instrumentation). |

#### §9.3.8.6 Cross-references

- 3A.c arc commits: `ffa7149b` (3A.c.1) → `4e8e9ad4` (3A.c.2) → `0e08e08b` (R7.a + R7.b) → `a4b33fce` (R7.c) → `d5b6bdbf` (3A.c.4) → `77ea36e4` (3A.c.5) → this commit (3A.c.6)
- §9.3.5 (deliberative-design mini-design; superseded by R7 reframe but architectural intent preserved)
- §9.3.6 (re-approach mini-audit + R8 empirical fuel test)
- §9.3.7 (R7 mini-design; centralized at type-map-write API)
- §9.3.8 (this — cumulative close VAG)

### §9.3.9 Phase 3A cross-arc VAG (2026-05-22)

Phase 3A overall close per §3 tracker row 189: adversarial 3-column cross-arc VAG covering the entire 3A arc (3A.0/.a/.b/.c/.d), bit-budget verification, drift-risk verification at cross-arc level, and §3 tracker row 3A → ✅.

#### §9.3.9.1 Phase 3A arc summary

Phase 3A delivered fork-on-union basic mechanism (in-place tagging per Realization B) — union-types via ATMS branching brought to the user-facing typing pipeline. 5 sub-phases:

| Sub-phase | Commit | Description |
|---|---|---|
| 3A.0 | `b4d8c22b` | Allocate cell-15 (fork-on-union-request) + cell-16 (fork-contradiction-request) via §4.6 framework + handler stubs registered |
| 3A.a | `f3597fbb` | `process-fork-on-union` handler body — N branch propagators install per-branch worldview; `make-branch-check-fire-fn` factory |
| 3A.b | `44b434ed` | N fire-once contradiction watchers wrapped per branch wv + `process-fork-contradiction` handler (atomic narrowing via bitwise-AND-with-NOT-mask) + lazy `promote-cell-to-tagged` insertion at fork-on-union entry |
| 3A.c | (arc closed `ba0a2bfd` after 7-commit arc) | User-facing integration via R7 reframe (centralized inline-emit at type-map-write API); §9.3.8 cumulative close VAG |
| 3A.d | `0e80e120` | Wholly retire `elab-speculation.rkt` (188 LoC) + `tests/test-elab-speculation.rkt` (388 LoC); stranded high-level abstraction (3rd codification data point) |

**Total LoC delta across Phase 3A** (rough):
- Production: ~+450 (3A.0 + 3A.a + 3A.b) + ~+50 (R7.b helper + Part B) + ~-130 (R7.c retirement) + ~-188 (3A.d production retirement) = ~+182 net production additions
- Test code: ~+400 (3A.a/.b tests + parity axes + speculation-bridge migrations) + ~-388 (3A.d test retirement) = ~+12 net
- **Net suite delta**: 8200ish → 8232 (within variance band) — small net additions despite substantial retirement

**Total commits**: ~14 across Phase 3A (foundation + sub-step + close commits + docs backfills).

#### §9.3.9.2 User-facing behavior post-3A

Annotated union types work end-to-end via on-network mechanism:

| Input | Output | Property |
|---|---|---|
| `(def x : <Int \| String> := 42) x` | `42 : Int \| String` | Single-success branch retains union classifier |
| `(def x : <String \| Int> := 42) x` | `42 : String \| Int` (source-order preserved) | Branch-order symmetry; pp-expr preserves source order |
| `(def x : <Nat \| Int> := 0N) x` | `0N : Nat \| Int` | **Multi-success non-committing** — both branches survive |
| `(def x : <Int \| Bool> := "hello") x` | type error → unbound x | All-fail exhaustion error |

The non-committing semantic is the LOAD-BEARING property: under sexp first-success, `0N : <Nat | Int>` would commit to `Nat` only. R7's mechanism preserves the classifier as the original union. Multi-success axis empirically discriminates.

#### §9.3.9.3 Cumulative adversarial 3-column VAG

**Question (a) On-network?**

| Catalogue | Challenge | **Adversarial** |
|---|---|---|
| ✓ All Phase 3A cells (cell-15 fork-on-union-request, cell-16 fork-contradiction-request, cell-17 decomposed-positions-guard) on-network with proper SRE-domain classification + merge functions. All handlers (process-fork-on-union, process-fork-contradiction) registered with BSP scheduler at 'value tier. Branch propagators wrapped per-branch worldview via `wrap-with-worldview`. R7's inline-emit at type-map-write API IS the union-detection mechanism (cell-write event). 3A.d retirement REDUCED off-network surface by 576 LoC. | Any new off-network state introduced across the arc? | (1) **Zero new Racket parameters added** — no `current-*` parameters introduced in any sub-phase. (2) **Zero new mutable boxes** — all state via cells. (3) **R7 helper STATELESS** — all state via net-cell-read/write. (4) **Tagged-cell-value promotion idempotent + lazy** — `promote-cell-to-tagged` only fires when needed; no eager state. (5) **Bridge file (elab-speculation-bridge.rkt) PRESERVED** for legacy with-speculative-rollback callers — labeled scaffolding with Parent Phase 4 / PM 12 retirement plan; HONEST framing (not "permanent"). (6) **Cumulative**: Phase 3A REDUCED off-network surface (3A.d's 576 LoC retirement + R7.c's 130 LoC retirement = ~706 LoC dead code retired vs ~+50 LoC R7 mechanism added). Net REDUCTION in off-network surface. **Pass at cross-arc level.** |

**Question (b) Complete?**

| Catalogue | Challenge | **Adversarial** |
|---|---|---|
| ✓ 5 sub-phases all closed (3A.0/.a/.b/.c/.d) with sub-phase adversarial VAGs. 3A.c cumulative VAG passed all 4 questions at §9.3.8. Full suite 8232 / 117.3s / 0 failures stable across arc. Production union annotations work end-to-end (probe + acceptance + 4 parity axes + 6 speculation-bridge migrations all PASS). | Shape OR benefit at the Phase 3A level? | **BOTH delivered**. (1) **Shape**: fork-on-union mechanism (3A.0/.a/.b) + R7 inline-emit (3A.c) + cell-17 guard + branch propagator install per-branch wv + contradiction narrowing via S(-1) — all structurally correct per per-sub-phase VAG verification. (2) **Benefit**: multi-success parity axis EMPIRICALLY DISCRIMINATES non-committing semantics from sexp first-success commit (load-bearing). Production union annotations elaborate correctly with classifier preserved. (3) **Retirement**: 3A.d's stranded elab-speculation.rkt retired (576 LoC); R7.c's 3A.c.2 helpers retired (130 LoC). Codification "Stranded high-level abstraction after refactor" promoted to 3 data points (READY for DEVELOPMENT_LESSONS.org). **Shape + benefit + cleanup all delivered. Pass.** |

**Question (c) Vision-advancing?**

| Catalogue | Challenge | **Adversarial** |
|---|---|---|
| ✓ Union-types via ATMS branching delivered (originally blocked at Track 4B). Composition gain via R7's centralization-at-API pattern — Phase 9b γ + Phase 7 trait dispatch + Track 4D attribute grammar rules pick up R7 for free when they write `:type` via type-map-write. Decision 1's principle aggregation (β.1 + FP3) vindicated empirically (R8 fuel test confirmed; R7 reframe preserves architecture + addresses quantitative cost). | Could the arc have been MORE aligned? | (1) **R7 GENERALIZES the original FIRST attempt's "install-time pre-write" pattern** — from install-time-known unions (annotations only; Posture A) to type-write-time-computed unions (any union-producing source; R7). Strict improvement in expressiveness without sacrificing fuel budget. (2) **Realization B (in-place worldview tagging on shared carrier)** chosen over Realization A (separate cells with bridges) — proper Module-Theoretic decomposition; bridges-cause-tag-collapse failure mode avoided structurally (per BSP-LE 2B PIR §6.3 lesson). (3) **3 promotion-ready codifications surfaced** (Stranded high-level abstraction × 3 data points; Principle-aggregation quantitatively insufficient × 2 data points; Multi-axis discriminating coverage × 3 application sites) — strong methodological capital generation across the arc. (4) **Honest framing throughout** — all-fail axis tests downstream symptom (not direct exhaustion error; documented in test docstring); typing-core.rkt:2385 noted as production-dead with Parent Phase 4 / PM 12 retirement plan; 3A.b lazy promote-cell-to-tagged labeled as substrate primitive with explicit reuse from relations.rkt 5 production sites. **Maximally aligned within Phase 3A scope. Pass.** |

**Question (d) Drift-risks-cleared?**

Per-sub-phase D-3A.0-* / D-3A.a-* / D-3A.b-* / D-3A.c-* / D-3A.d-* risks all cleared at respective sub-phase closes (§9.3.2-9.3.8). Cross-arc Phase 3A risks:

| Risk | Status | Adversarial verification |
|---|---|---|
| D-3A-fuel-budget | CLEARED via R7 architecture (R7.b adopted) | R7's inline-emit at type-map-write API adds ZERO extra propagator wakes (vs original watcher approach which added 45-100 wakes per polymorphic dispatch). TYPING-FUEL-LIMIT=200 preserved at production threshold. R8 empirical fuel test (§9.3.6.8) confirmed mechanism; R7 reframe (§9.3.7) addresses the cost without sacrificing architecture. |
| D-3A-typing-core-2385-residual | CLEARED via empirical grep | `with-speculative-rollback` only at qtt.rkt:2329 (Parent Phase 4 territory) + typing-errors.rkt:78 (kept alive per §9.3.5.4). Production goes through on-network via type-map-write → R7 → handler. Parent Phase 4 owns the code-level retirement when sexp paths broadly retire. |
| D-3A-bit-budget | CLEARED via PROVENANCE-STATS | Probe (28 commands) shows `atms_hypothesis_count: 5` ≈ 0.18 aids/command. 30-bit cap = 167× headroom. No bit-budget concerns at production scale. |
| D-3A-cross-arc-mantra-violation | CLEARED via cumulative on-network audit (column a above) | Zero new Racket parameters / mutable state / off-network registries across entire arc. R7 helper stateless. Bridge file labeled scaffolding. Net REDUCTION in off-network surface (-706 LoC dead code retired vs +50 LoC mechanism added). |
| D-3A-codification-debt | NOTED — 3 candidates ready | "Stranded high-level abstraction after refactor" (3 data points; promotion-ready); "Principle-aggregation quantitatively insufficient" (2 data points); "Multi-axis discriminating coverage" (3 application sites). Graduation to DEVELOPMENT_LESSONS.org deferred to user direction (not blocking 3A-VAG close). |

All cross-arc drift risks addressed.

#### §9.3.9.4 Phase 3A codification graduation candidates (status)

The session arc surfaced **6 methodology data points** across 3A.c.6 close (§9.3.8.4) + 3A.d retirement. Status:

| Codification | Data points | Promotion status |
|---|---|---|
| **"Stranded high-level abstraction after refactor"** | **3** (elab-speculation.rkt at §9.3.5.4 audit + 3A.c.2 helpers at R7.c + elab-speculation.rkt itself at 3A.d) | **🎯 PROMOTION-READY for DEVELOPMENT_LESSONS.org** |
| **"Multi-axis parity testing for discriminating coverage"** | 3 application sites (2A.c orchestration-parity + 3A.c.4 union-inhabitation + 3A.c.5 speculation-bridge substring) | **Strong promotion candidate** — refining existing "parity-test as design artifact" codification |
| **"Audit-driven scope refinement"** | 3 data points this session (R7.a refining R7 implementation pattern from per-fire-fn to centralized-at-API; 3A.b lazy promote-cell-to-tagged discovery; 3A.c.5 migration scope refinement) | **Graduating** — codification candidate ready |
| "Principle-aggregation architecturally correct yet quantitatively insufficient" | 2 (Tropical Phase 1V Item #1 + R8/R7 arc) | Watching list; promotion at 3rd data point |
| "R7 generalizes install-time pre-write → type-write-time pre-write composition gain" | 1 (R7 itself) | Watching list; promotion when Phase 9b γ or Phase 7 trait dispatch picks up the pattern |
| "3-column adversarial framing in concentrated use" | Multiple application sites this session | Validates user-articulated methodology refinement; no new codification, just reinforcement |

**Graduation deferred to user direction**. The cross-arc VAG identifies these as ready; the actual DEVELOPMENT_LESSONS.org graduation is a separate (optional) follow-up.

#### §9.3.9.5 Phase 3A close + handoff

**Phase 3A CLOSED.** All 5 sub-phases ✅; cross-arc VAG passed all 4 questions adversarially; all drift risks cleared.

**Final state**:
- Full suite: 8232 tests / 117.3s / 0 failures
- Production net additions: ~+182 LoC (cells + handlers + R7 helper + Part B) net of retirements
- Test code: ~+12 LoC net (parity axes + speculation-bridge migrations net of test-elab-speculation.rkt retirement)
- Off-network surface: REDUCED by ~-706 LoC (R7.c + 3A.d retirements net of additions)
- 3 codifications promotion-ready

**Handoff to next phases**:

| Track | Picks up from Phase 3A |
|---|---|
| **Phase 3B** (hypercube primitives) | cell-15/-16/-17 infrastructure + worldview-cache narrowing + branch propagator wrap pattern; integrates Gray code branch ordering + subcube pruning via existing primitives |
| **Phase 3C** (residuation error-explanation) | worldview/contradiction infrastructure from 3A.b + cell-16 narrowing signal + R7's type-write event as natural derivation-chain anchor + Form C cross-reference (tropical-left-residual operator) |
| **Phase 9b** (γ hole-fill multi-candidate) | Fork-on-union handler pattern + R7's centralized-at-API insight. Phase 9b's multi-candidate watcher can adopt R7's inline-at-write-API pattern OR resurrect 3A.c.2 helpers from git history |
| **Parent Phase 4** (CHAMP retirement) | typing-core.rkt:2385 + qtt.rkt:2329 + typing-errors.rkt:78 + 4 with-speculative-rollback callers production-dead; retire when meta-info CHAMP retires + PM 12 + on-network completion |
| **PM Track 12** (parameters → cells) | `current-prop-net-box` + box-bridge family scaffolding; coordinated retirement |
| **PPN Track 5** (occurrence typing) | `union-inhabitation-narrowing` skip-gated parity axis points here |
| **PPN Track 4D** (Attribute Grammar Substrate) | Attribute grammar rules pick up R7 via type-map-write composition for free; no per-rule instrumentation needed |

#### §9.3.9.6 Cross-references

- Phase 3A arc commits: `b4d8c22b` (3A.0) → `f3597fbb` (3A.a) → `44b434ed` (3A.b) → `ba0a2bfd` (3A.c cumulative close after 7-commit arc) → `0e80e120` (3A.d) → this commit (3A-VAG)
- Sub-phase designs + closes: §9.3.2 (3A.0) + §9.3.3 (3A.a) + §9.3.4 (3A.b) + §9.3.5/6/7/8 (3A.c arc) + §9.3.5.4 (3A.d Q4 resolutions)
- Decision 1 (β.1 + FP3 architectural target): §9.3.5.3
- R7 reframe selection rationale: §9.3.6.8 (R8 empirical) + §9.3.7 (mini-design)
- Cumulative methodology data points: §9.3.8.4 + §9.3.9.4

### §9.4 Phase 3B deliverables (ORIGINAL TERSE SPEC — superseded by §9.4.1 for implementation planning)

**Note 2026-05-22**: this terse 4-item spec is retained for conceptual framing. Phase 3B's actual implementation plan post-mini-design + mini-audit is at §9.4.1. Specifically: the original spec assumed BSP-LE 2 D.6's fork-and-rejoin CHAMP-sharing framing (item 2); under Phase 3A's Realization B (in-place worldview tagging on shared carrier), the CHAMP-sharing argument does NOT transfer directly — Phase 3B's hypercube integration requires the substrate decomplection (M1) first + empirical falsification (Pre-0 A/B) before the Gray-code integration is justified. §9.4.1 captures the refinement.

Hypercube integration leveraging already-implemented primitives (audit §3.5):

1. Wire Gray-code branch ordering: replace naive branch enumeration with `gray-code-order` from `relations.rkt`
2. Benefit: successive forks differ by one assumption bit → CHAMP structural sharing maximized
3. Subcube pruning on contradictions: when branch X contradicts, writes nogood; subsequent branches containing the same nogood-bits skipped via `subcube-member?` check (already implemented in `decision-cell.rkt:368`)
4. Tests: performance + correctness (structural sharing benefit measurable via heartbeat counters)

### §9.4.1 Phase 3B mini-design + mini-audit (2026-05-22 — conversational opening of Phase 3B)

Mini-design + mini-audit opened post-Phase-3A close (HEAD `105ad18f`, 2026-05-22). **Critical finding**: the conversational mini-audit surfaced an architectural debt missed by Phase 3A's mini-design (§9.3.1) — the **OQ1 ↔ mutual-exclusion semantic tension**. This finding RESHAPED Phase 3B from "wire hypercube primitives" (per §9.4 original spec) into "substrate decomplection FIRST, then hypercube integration conditional on empirical evidence." Outcomes persisted per Stage 4 methodology (mini-design + mini-audit findings persist to design doc, not parallel files / dailies-only).

#### §9.4.1.1 Audit findings — OQ1 ↔ mutual-exclusion tension surfaced

Phase 3A's mini-design (§9.3.1) treated `solver-state-amb` as a contract-less aid allocator (§9.3.1.1 audit row read: *"`solver-state-amb` (atms.rkt:67/440) — fresh-aid allocation via counter cell; one aid-group per call. `solver-state-add-nogood`, `solver-amb-groups`"*). The Phase 3B mini-audit revealed:

**Finding** (atms.rkt:300-320): `solver-amb` writes **N·(N−1)/2 pairwise mutual-exclusion nogoods** as a side effect of every call. The function comment at atms.rkt:302 reads *"records pairwise mutual-exclusion nogoods"*; body at lines 313-319:

```racket
;; 2. Record mutual exclusion: every pair of hypotheses is a nogood
(define net2
  (for*/fold ([n net1])
             ([i (in-range (length hyps))]
              [j (in-range (+ i 1) (length hyps))])
    (solver-add-nogood ctx n (hasheq (list-ref hyps i) #t
                                      (list-ref hyps j) #t))))
```

**Implication for Phase 3A**: `process-fork-on-union` (typing-propagators.rkt:1139) invokes `solver-state-amb` → `solver-amb` → pairwise nogoods. These nogoods exist in the network's nogood store but are NOT consulted by Phase 3A's mechanism. The mechanism "works" because `wrap-with-worldview`'s single-bit dispatch isolates each branch propagator from observing the nogoods at the global worldview level.

**The deeper SAT distinction**:

| Construct | Logical semantic | Constraint type | ATMS encoding |
|---|---|---|---|
| Classical `amb` | EXACTLY ONE of {h_0, ..., h_{N-1}} is true | Disjunction + pairwise mutual exclusion | N aids + N(N−1)/2 pairwise nogoods |
| Non-committing union | AT LEAST ONE of {h_0, ..., h_{N-1}} is true; multiple may be | Disjunction only | N aids + no mutex nogoods (all-fail-on-zero-active check) |

`solver-amb` encodes classical (exactly-one); non-committing union semantics (per OQ1 type-theory citations: Frisch-Castagna semantic subtyping; Castagna 2022; Tobin-Hochstadt-Felleisen Typed Racket occurrence typing; Scala 3 hard unions) wants AT-LEAST-ONE only.

**worldview-cache role overload**: Phase 3A's `process-fork-on-union` initializes worldview-cache with ALL N branch bits set (typing-propagators.rkt:1146-1147):

```racket
(define n1 (net-cell-write n worldview-cache-cell-id
                            (bitwise-ior current-wv branch-mask)))
```

Under classical ATMS, worldview-cache represents the CURRENT BELIEVED WORLDVIEW — a single point in Q_n. Having multiple branch bits set is structurally a contradiction per the pairwise nogoods. Phase 3A repurposes worldview-cache as an ACTIVE-BRANCH-SET (set of viable branches), a semantic incompatible with the classical interpretation that `solver-amb` enforces via mutex nogoods.

**Pattern classification**: this is the **third "accidentally-load-bearing mechanism" pattern** in the addendum (continuing the lineage from S2.c-iii `with-handlers` wrapper and Path T-3 findings). Phase 3A's mini-audit missed the side effect because the audit row treated solver-state-amb as a contract-less aid allocator — **capture-gap discipline failure at the mini-audit level**.

#### §9.4.1.2 Semantic exploration — three candidate models (adversarial 3-column)

Three approaches surfaced in dialogue:

**Model M0 — Suppress mutex nogoods at solver-amb call site (minimal patch)**

Add `#:mutual-exclusion?` flag to `solver-amb`; Phase 3A passes `#:mutual-exclusion? #f`.

| Catalogue | Challenge | **Adversarial** |
|---|---|---|
| ✓ Removes inert nogoods; minimal infrastructure change; backward compatible; surgically fixes the immediate inconsistency | Renames the problem without fixing it. The worldview-cache role-overloading remains; future non-committing consumers (Phase 9b γ multi-candidate) will rediscover the same overloading. | **Treats the symptom (inert nogoods being written) without fixing the root cause (two semantic concepts sharing a substrate). Honest framing: M0 is a SAFETY PATCH that closes the open hole, NOT an architectural answer. If we take M0, we ship it explicitly labeled as scaffolding with a Track-4D-shaped retirement plan. We are NOT "done" with the semantic clarification after M0 lands.** |

**Model M1 — Separate active-branch-set cell + new `union-amb` primitive (selected; see §9.4.1.3)**

- New cell (active-branch-set tracker): per-fork-position active-branch bitmask; merge = set-narrowing via bitwise-AND-with-NOT-mask
- New primitive `union-amb` (alongside `solver-amb`): allocates N aids; writes their bits to the new cell; does NOT write mutual-exclusion nogoods
- `process-fork-on-union` migrates from `solver-state-amb` to `union-amb`
- `process-fork-contradiction` narrows new cell (not worldview-cache) on contradicted branch aids
- `solver-amb` retains classical semantics for downstream classical-ATMS clients (BSP-LE 2 multi-clause selection, NAF, etc.)

| Catalogue | Challenge | **Adversarial** |
|---|---|---|
| ✓ Real decomplection: two cells with structurally-distinct merge contracts; first-class "active-branch-set" concept; honest naming; Correct-by-Construction at the cell layer | Is this just renaming the same data with a different cell-id? Two cells with similar bitmask shape but different "meaning" could be the failure mode `:set` vs `:point` tag would also exhibit. | **Test the decomplection: do the two cells have GENUINELY DIFFERENT merge semantics? Worldview-cache (classical-ATMS): point-update via decisions-state-bitmask (commit/retract a specific worldview). Active-branch-set: set-narrowing via bitwise-AND-with-NOT-mask (monotone shrinking; CALM-safe). Structurally distinct lattice operations — confirmed decomplection, not renaming. Risk of complexity proliferation: real but bounded — adding ONE new substrate primitive for a previously-conflated concept is canonical decomplection (compare PAR Track 1 stratifying topology vs value cells; same architectural pattern).** |

**Model M3 — First-class classifier-set type-theoretic reification (long-term, Track 4D)**

- Introduce `union-classifier-set` substrate concept (set-of-type-classifiers as first-class lattice value)
- Per Frisch-Castagna semantic subtyping: `[[e : A | B]] = [[e]] ∈ [[A]] ∪ [[B]]`
- Composes with attribute-map `:type` facet's classify-inhabit-value CLASSIFIER layer

| Catalogue | Challenge | **Adversarial** |
|---|---|---|
| ✓ Type-theoretically pure (matches Castagna); composes with classify-inhabit-value; eliminates worldview-cache overload entirely | Big restructuring; conflates type-system semantics with substrate mechanism; possibly Track 4D scope | **Does the type-set abstraction GENUINELY belong at the substrate layer, or is it a type-system-level concept being prematurely pushed down? The substrate (propagator network) is meant to be type-system-agnostic — it provides lattices, cells, propagators. The classifier-set is a TYPE-SYSTEM construct. Reifying it at the substrate creates a Track-4D-shaped coupling (attribute-grammar substrate unification — exactly Track 4D's thesis). Honest framing: M3 is RIGHT but PREMATURE — it should land WITH Track 4D, not BEFORE it. Until then, M1 is the architecturally-correct substrate-level answer.** |

#### §9.4.1.3 Architectural decision — M1

**M1 selected** as the substrate-level answer for Phase 3B's prerequisite work. Rationale:
- The semantic gap is real (Phase 3A's worldview-cache repurposing is decomplection failure; inert mutex nogoods are architectural debt)
- M1 properly decomplects (separate cells with structurally-distinct merge contracts)
- Preserves classical `solver-amb` for downstream classical-ATMS consumers
- M0 is safety-patch territory (acceptable as emergency stopgap, NOT architecturally final)
- M3 belongs in Track 4D (premature now; would conflate type-system + substrate)

**Adversarial self-check on M1 selection**:

| Catalogue | Challenge | **Adversarial** |
|---|---|---|
| ✓ M1 cleanly decomplects per Correct-by-Construction | Am I converging on M1 because it's the most COMFORTABLE answer (adds a cell, no fundamental restructuring)? | **Honest test: M3 requires type-system knowledge in the substrate, violating First-Class-by-Default at the WRONG LAYER (the substrate should be type-system-agnostic; type-system concepts should be defined in terms of substrate, not the other way around). M1 keeps the substrate type-agnostic and lets type-system code (Phase 3A handler, future Track 4D) compose on top. M1 is principled at THIS layer, M3 is principled at the integrated-layer Track 4D will introduce. Different scopes, different right answers. M1 confirmed correct for Phase 3B's prerequisite work.** |

#### §9.4.1.4 Sub-phase partition

| Sub-phase | Type | Purpose |
|---|---|---|
| **3B.0** | Measurement + Audit | Pre-0 A/B harness for Gray-code aid ordering empirical question + Stage 2 audit for M1 substrate decomplection design |
| **3B.A** | Implementation | M1 substrate decomplection — separate active-branch-set cell + `union-amb` primitive; migrate `process-fork-on-union` from `solver-state-amb` to `union-amb` |
| **3B.B** | Implementation | Hypercube integration (Gray-code aid ordering) — **conditional on 3B.0 measurement outcome per pre-committed falsification criteria (§9.4.1.6)** |
| **3B-VAG** | Close | Cross-arc adversarial 3-column VAG |

Independence note: `3B.A` (M1) is independent of `3B.B` (Gray code) in correctness — M1 is architectural debt resolution; 3B.B is a performance/Conjecture-alignment claim. Both are informed by 3B.0's outputs.

**Subcube-member? consumer status under M1**: under M1, mutex nogoods don't exist for fork-on-union, so `subcube-member?` has NO consumer from fork-on-union directly. Real future consumer = downstream nogoods from OTHER paths (Parent Phase 4 CHAMP retirement; Phase 9b multi-candidate; PReduce). Honest answer: **`subcube-member?` stays orphaned for Phase 3B, ships with documentation labeling it as primitive-awaiting-consumer**. The original §9.4 spec's item #3 ("Subcube pruning on contradictions...") is SUPERSEDED by this resolution — moved from Phase 3B scope to "primitive-awaiting-consumer" status.

#### §9.4.1.5 Phase 3B.0 scope (measurement + audit)

**Audit tasks** (for M1 design — outputs persist into §9.4.2+ as findings land):

1. **A1 — `solver-state-amb` caller catalog**: grep `solver-state-amb` + `solver-amb` across racket/prologos/; classify each as classical-ATMS vs non-committing-union; expected: `process-fork-on-union` is sole non-committing caller. Determines migration scope for M1.
2. **A2 — worldview-cache read/write site catalog**: grep `worldview-cache-cell-id` across racket/prologos/; classify as point-update vs bit-set-update; identifies M1 migration scope at the cell-read/write layer.
3. **A3 — wrap-with-worldview semantic audit**: read `wrap-with-worldview` body; confirm it parameterizes `current-worldview-bitmask` without depending on worldview-cache reads. Independence enables localized M1 change (M1 doesn't ripple through propagator machinery).
4. **A4 — Mutex nogood storage + read site verification**: grep `solver-context-nogoods-cid` reads; trace consumers; confirm no Phase-3A path consults the inert nogoods. Validates the safety of M0's "suppress writing" approach as a corollary.
5. **A5 — `union-amb` primitive design**: cell-id allocation slot (likely 18 = next available after cell-17 decomposed-positions-guard); cell shape (per-position hasheq → bitmask); API signature; migration site count (expected: 1).
6. **A6 — `process-fork-contradiction` interactions under M1** (added per §9.4.1.10 meta-adversarial): narrowing target changes from `worldview-cache-cell-id` to the new active-branch-set cell; verify handler signature compatibility; verify cell-16 (fork-contradiction-request) → new-cell mapping.

**Measurement tasks** (Pre-0 A/B harness):

A/B variants (per §3.1):
- **Variant A (control)**: sequential aid allocation `bit 0, 1, 2, ..., N-1` (current `solver-amb` behavior)
- **Variant B (treatment)**: Gray-code-ordered aid allocation. Parameter `current-gray-code-aid-ordering?` (boolean, default #f). When #t, `solver-amb`'s aid-allocation loop applies `gray-code-order` permutation to bit-position assignment. **Cell-layer/data-layer optimization** (the aid's bit position is data; not scheduler-coupled).

Workloads (per §3.2):
- **W1** Single binary union: `def x : <Int | String> := 42; x` (2 branches)
- **W2** Single N-ary union: `def x : <Int | String | Bool | Float> := 42; x` (4 branches)
- **W3** Nested binary unions: function `<(A1|A2) -> (B1|B2)>` with multiple call sites
- **W4** Deeply nested adversarial: ~10-15 nested unions; aid count approaches D-3A-bit-budget gate (≤30)
- **W5** Worst-case adversarial: designed to give Gray code maximum advantage (many forks at varying depths; many touch-points)

W5 is the **adversarial-best-shot workload** — if Gray code provides benefit anywhere under Realization B, W5 should show it. If W5 is negligible, the Conjecture's benefit doesn't transfer to this use case.

Metrics (per §3.3): wall time (median of 10 runs, IQR reported); `cell_allocs` delta; `prop_firings` delta; peak retained memory (KB); `max_aids_per_command` from PERF-COUNTERS; `atms_hypothesis_count` per command; probe semantic diff (sanity, MUST be zero); full suite pass count (sanity, MUST be stable).

Harness location: dedicated file `benchmarks/micro/bench-fork-on-union-gray-code.rkt` (per resolved Q2 in §9.4.1.10).

#### §9.4.1.6 Pre-committed falsification criteria

Per §11.3 measurement-driven gate methodology + S2.c-iii lesson (microbench claim verification) — committed BEFORE measurement to prevent post-hoc rationalization:

| W4/W5 wall time outcome | Interpretation | Phase 3B.B action |
|---|---|---|
| Variant B beats A by **≥10%** | Positive evidence: Conjecture's claim transfers to Realization B at this scale | Phase 3B.B = implement Gray-code aid ordering |
| Variant B beats A by **5-10%** | Suggestive; need microbench isolation to confirm benefit attribution | Investigate before implementing; consider forward-investment label (1V Item #1-quater precedent) |
| Variants within **±5%** | **Negative**: Conjecture's empirical benefit does NOT transfer under THIS Realization B + workload-set | Phase 3B.B = documented-defer with negative finding (architecturally honest output) |
| Variant B **slower** than A | Strong negative: dispatch overhead exceeds benefit | Defer + flag as primitive-keepalive risk (workflow.md "preserved for backward-compat" red flag) |

The pre-commitment is itself the discipline. We DO NOT amend the thresholds after seeing the data. If results land between thresholds, the methodology requires re-running with refined workload (not threshold revision).

#### §9.4.1.7 Drift risks named (per Stage 4 mini-design discipline)

To be re-verified at Phase 3B close (drift-risks-cleared question in 3B-VAG):

- **D-3B-shape-without-benefit**: wire up Gray-code without demonstrating measurable benefit (S2.c-iii pattern). **Mitigation**: the falsification criteria (§9.4.1.6) ARE the structural mitigation — Phase 3B.B is conditional on positive evidence, NOT default-on.
- **D-3B-fork-vs-Realization-B-confusion**: inherited BSP-LE 2 D.6 framing assumes fork-and-rejoin's CHAMP sharing; Realization B has no forks. **Mitigation**: §9.4 supersession note + §9.4.1 explicit re-derivation of benefit under Realization B make this explicit.
- **D-3B-orphan-primitive-keepalive**: `subcube-member?` stays orphaned post-3B; risk of "preserved for future use" rationalization. **Mitigation**: ship docstring labeling primitive-awaiting-consumer with explicit cross-references to Phase 9b / PReduce / Parent Phase 4 as future consumer candidates (per §9.4.1.8 cross-track captures).
- **D-3B-scheduler-coupled-optimization**: Cell/Propagator/Scheduler Orthogonality requires optimization at appropriate layer. **Mitigation**: M1's aid bit-position assignment is at CELL/DATA layer (`assumption-id-n` is data); Gray-code permutation is applied to aid allocation, NOT to scheduler iteration order. Risk mitigated structurally by M1's design.
- **D-3B-subcube-without-consumer**: `subcube-member?` has no consumer in Phase 3A under M1 (mutex nogoods don't exist for fork-on-union). **Mitigation**: explicit "primitive-awaiting-consumer" labeling; honest deferral rather than wiring without consumer.
- **D-3B-measurement-confound-inert-nogoods**: A/B test on current code (pre-M1) measures variant B with inert-mutex-nogood-writing overhead present. Overhead is constant across variants (cancels in A/B delta). **Mitigation**: documented limitation; re-measure post-M1 if substantial finding emerges.

#### §9.4.1.8 Cross-track captures

**Phase 9b γ multi-candidate**: inherits M1 substrate (active-branch-set cell + `union-amb` primitive). Phase 9b's mini-design picks these up as substrate primitives; **D-9b-bit-budget** (from §9.3.1.7) remains separate concern. If Phase 9b's multi-candidate count exceeds 30 (D-3A-bit-budget gate), the M1 cell may need extension OR Phase 9b may need budget-management mechanism.

**Parent Phase 4** (CHAMP retirement): M1's separate cell allocation must coordinate with Parent Phase 4's broader meta-storage cleanup. If Parent Phase 4 retires `solver-context-nogoods-cid` interactions for fork-on-union path, M1 simplifies further. M1 ships independent of Parent Phase 4; coordination at integration.

**PReduce Track 1** (e-class cell substrate): M1's `union-amb` primitive becomes template for non-committing multi-candidate substrate. PReduce inherits via composition — e-class cells with multi-candidate cost extraction face similar "at-least-one optimal candidate is true" semantic; M1's substrate decomplection is the canonical pattern.

**PPN Track 4D** (Attribute Grammar Substrate): **M3 (long-term) lands here**. M1 → M3 migration is part of 4D's substrate unification thesis. Track 4D scope includes promoting the substrate-level active-branch-set concept into the type-theoretic classifier-set concept.

**Phase 3C** (residuation error-explanation): consumes the active-branch-set narrowing signal from M1's new cell. Can ALSO consume mutex nogoods from OTHER (classical-ATMS) callers if needed for error chains involving classical amb. Phase 3C inherits the architectural separation cleanly.

#### §9.4.1.9 Methodology notes — audit-driven scope refinement (4th data point)

The Phase 3B mini-audit caught a Phase-3A-mini-audit gap (capture-gap pattern at the mini-audit level):
- Phase 3A audit row (§9.3.1.1) treated `solver-state-amb` as contract-less aid allocator
- Phase 3B audit revealed `solver-amb` writes pairwise mutex nogoods as side effect
- The architectural debt this introduced (worldview-cache role overload) became latent in Phase 3A — only surfaced via Phase 3B's audit

This continues the **audit-driven scope refinement** codification (from §9.3.9.4): when post-phase audit refines the prior phase's audit, the design ACCEPTS the refinement and reshapes scope rather than treating it as bug-hunt. Phase 3B's scope is shaped by what Phase 3B's audit revealed about Phase 3A, NOT by what Phase 3A's audit predicted.

**4th data point for this codification**:
1. R7.a audit refining R7 implementation pattern (from per-fire-fn enumeration to centralized-at-API; §9.3.9.4)
2. 3A.b lazy `promote-cell-to-tagged` discovery via mempalace search (§9.3.9.4)
3. 3A.c.5 migration scope refinement (6 active + 2 preserves matches §9.3.5.6 estimate; §9.3.9.4)
4. **3B.0 audit surfacing OQ1 ↔ mutual-exclusion tension** (this section)

**Promotion to DEVELOPMENT_LESSONS.org NOW WARRANTED** — 4 data points across 2 phases (3A + 3B). Graduation deferred to user direction (per §9.3.9.4 pattern).

**Related methodology note — adversarial 3-column at META level**: adversarial framing applied to the Phase 3B.0 plan itself (§4 of mini-design dialogue, in dailies); identified A6 audit step missing from initial scope; identified measurement-on-current-code confound (D-3B-measurement-confound-inert-nogoods). The meta-application of adversarial framing catches scope gaps at the design-plan layer, not just the architectural-decision layer. Reinforces the **3-column discipline at every gate** lesson (codified across DESIGN_METHODOLOGY/CRITIQUE_METHODOLOGY/workflow.md/MEMORY.md per S2.c-iii arc).

#### §9.4.1.10 Resolved open questions from mini-design dialogue

5 open questions resolved before persistence (per dailies session 2026-05-22):

| Q | Resolution |
|---|---|
| **Q1 — Audit scope** (add A6 process-fork-contradiction interactions under M1) | RESOLVED: added A6 to scope per §9.4.1.5. Surfaced via adversarial 3-column at meta level. |
| **Q2 — A/B harness location** | RESOLVED: dedicated file `benchmarks/micro/bench-fork-on-union-gray-code.rkt`. Clear ownership; doesn't pollute existing harness. |
| **Q3 — Measurement timing** (current code vs post-M1) | RESOLVED: measure on current code (inert nogoods constant across variants; cancel). Documented limitation D-3B-measurement-confound-inert-nogoods; re-measure post-M1 if substantial finding emerges. |
| **Q4 — Falsification thresholds** | RESOLVED: ≥10% / 5-10% / ±5% / slower per §9.4.1.6. Tight enough per noise analysis (wall-time noise typically <5% in our suite). |
| **Q5 — D.3 persistence timing** | RESOLVED: persist NOW (this commit) with audit findings as living subsection; mini-design + mini-audit outcomes persist to design doc per Stage 4 methodology. |

#### §9.4.1.11 Status

- Mini-design + mini-audit COMPLETE — OQ1 ↔ mutual-exclusion semantic resolved (M1 selected)
- Phase 3B sub-phase structure refined (3B.0 / 3B.A / 3B.B / 3B-VAG)
- Phase 3B.0 audit + measurement scope defined (§9.4.1.5)
- Pre-committed falsification criteria locked (§9.4.1.6)
- Drift risks named (D-3B-*; §9.4.1.7)
- 5 cross-track captures (Phase 9b, Parent Phase 4, PReduce 1, Track 4D, Phase 3C; §9.4.1.8)
- Audit-driven scope refinement codification — 4th data point (PROMOTION-READY for DEVELOPMENT_LESSONS.org)
- 5 open questions resolved (§9.4.1.10)
- Ready for Phase 3B.0 implementation opening per Stage 4 Per-Phase Protocol — **+ deliberate/discourse turn before confirming implementation approach** per user direction 2026-05-22

#### §9.4.1.12 Cross-references

- Parent Phase 3 mini-design (Realization B pivot): §9.3.1
- Phase 3A cross-arc VAG: §9.3.9
- Original Phase 3B terse spec (superseded by this section): §9.4
- Stage 2 audit findings (hypercube primitives implementation status): [`2026-04-21_PPN_4C_PHASE_9_AUDIT.md`](2026-04-21_PPN_4C_PHASE_9_AUDIT.md) §3.5
- Hypercube research foundation: [`2026-04-08_HYPERCUBE_BSP_LE_DESIGN_ADDENDUM.md`](../research/2026-04-08_HYPERCUBE_BSP_LE_DESIGN_ADDENDUM.md)
- Hyperlattice Conjecture: [`DESIGN_PRINCIPLES.org`](principles/DESIGN_PRINCIPLES.org) § Hyperlattice Conjecture + § Cell/Propagator/Scheduler Orthogonality
- Substrate primitives: `gray-code-order` (relations.rkt:1874); `subcube-member?` (decision-cell.rkt:372); `solver-amb` (atms.rkt:304); `process-fork-on-union` (typing-propagators.rkt:1120)
- Dialogue context (audit findings + alternate models): dailies 2026-05-17 session entries 2026-05-22 (Phase 3B mini-design)

### §9.4.2 Phase 3B.0 mini-design + mini-audit opening (2026-05-22)

Mini-design + mini-audit opening per Stage 4 Per-Phase Protocol step 1+2 (co-dependent cycle). Conversational dialogue post-Phase-3B-parent persistence (commit `5df6745a`) confirmed 8 process + methodology decisions before audit execution begins. Outcomes persist per Stage 4 methodology.

#### §9.4.2.1 Resolved process decisions (Q1-Q8)

8 questions surfaced + resolved at mini-design opening:

| Q | Decision | Rationale |
|---|---|---|
| **Q1** — Audit ordering + parallelization | **A1-A6 all-parallel** (single read-only sweep) | Adversarial check on Wave-structure revealed dependencies are lightweight (A2/A5 only need A1's caller list, not full analysis). All-parallel is structurally valid + faster. |
| **Q2** — A/B harness timing | **Audit + harness construction concurrent** | Workload design is source-level Prologos programs (W1-W5), not implementation-level — doesn't require audit context. Independence enables parallelism. |
| **Q3** — Variant B implementation strategy | **Parameter on `main`** (`current-gray-code-aid-ordering?` default `#f`); minimal one-line change in `solver-amb` aid-allocation loop | Branch management overhead avoided; default `#f` preserves baseline exactly; toggleable for same-process A/B; labeled Pre-0 measurement scaffolding with explicit retirement plan |
| **Q4** — Statistical methodology | Use `tools/bench-ab.rkt` infrastructure where supported (verify parameter-variant compatibility during execution); dedicated workload file `benchmarks/micro/bench-fork-on-union-gray-code.rkt` | Existing harness handles noise/IQR; don't reinvent. Dedicated workload file = clear ownership; doesn't pollute existing bench-meta-lifecycle.rkt. |
| **Q5** — Closure criteria | (1) A1-A6 persisted to §9.4.2.7+; (2) harness landed + Variant A baseline captured; (3) A/B measurement run (W1-W5 × {A,B}); (4) falsification evaluation + decision documented; (5) 3B.0 adversarial 3-column VAG passes 4 questions | Matches Phase-0-as-measurement-phase pattern (§9.3.2 precedent); covers BOTH audit deliverable + measurement deliverable |
| **Q6** — Single integrated 3B.0 vs split | **Single integrated phase** | Splitting fragments dialogue between audit + measurement; integrated view at closure is architecturally more valuable. Audit findings INFORM measurement interpretation (e.g., if Variant B regresses, audit's overhead-analysis context helps explain). |
| **Q7** — Conversational checkpoints | Light checkpoints at major milestones (audit-sweep done, harness ready, measurement run done) — NOT per individual audit task | Matches conversational cadence rule (~1h max autonomous stretch); avoids checkpoint inflation; preserves dialogue momentum at decision points |
| **Q8** — Scaffolding labeling | Variant B implementation labeled **"Phase 3B.0 Pre-0 measurement scaffolding — retires at 3B.B close per A/B outcome"** | Honest framing per workflow.md; matches `:tier 'hot` etc. cell-meta declarations — scaffolding with explicit retirement plan, not preserved-for-future-use |

#### §9.4.2.2 Audit execution plan (A1-A6 parallel sweep)

Audit tasks per §9.4.1.5, executed in single all-parallel pass:

| Task | Concrete action | Output target |
|---|---|---|
| **A1** — `solver-state-amb` caller catalog | grep `solver-state-amb` + `solver-amb` across racket/prologos/; classify each as classical-ATMS vs non-committing-union | D.3 §9.4.2.7 (forthcoming) |
| **A2** — worldview-cache read/write site catalog | grep `worldview-cache-cell-id` across racket/prologos/; classify point-update vs bit-set-update | D.3 §9.4.2.7 (forthcoming) |
| **A3** — wrap-with-worldview semantic audit | read `wrap-with-worldview` body (propagator.rkt); confirm parameterization-only (no worldview-cache reads inside) | D.3 §9.4.2.7 (forthcoming) |
| **A4** — Mutex nogood storage + read site verification | grep `solver-context-nogoods-cid` reads; trace consumers; confirm no Phase-3A path consults the inert nogoods | D.3 §9.4.2.7 (forthcoming) |
| **A5** — `union-amb` primitive design | Cell-id allocation slot (likely 18 = next after cell-17); cell shape (per-position hasheq → bitmask); API signature; migration site count | D.3 §9.4.2.8 (forthcoming) |
| **A6** — `process-fork-contradiction` interactions under M1 | Narrowing target shift from worldview-cache to new cell; cell-16 → new-cell mapping; handler signature compatibility | D.3 §9.4.2.8 (forthcoming) |

**Meta-adversarial check on audit coverage** (per D-3B.0-audit-blindspots risk): A1-A6 cover solver-amb / worldview-cache / wrap-with-worldview / nogood-store / primitive-design / handler interactions. Surfaces NOT explicitly named: (a) test coverage interactions (some tests may mock current behavior; will surface in A1 caller catalog); (b) downstream tools (lsp/, benchmarks/, tools/ may reference current substrate; surfaces in A1); (c) examples/ acceptance files (unchanged in substrate audit — they're source-level). Conclusion: A1's caller catalog will naturally surface (a)+(b)+(c); explicit A7-A9 audit tasks NOT warranted. Capture-gap risk acknowledged + mitigated by A1's grep breadth.

#### §9.4.2.3 A/B harness implementation plan

**Harness file**: `benchmarks/micro/bench-fork-on-union-gray-code.rkt` (NEW).

**Variant B implementation** (single one-line change in `solver-amb` aid-allocation loop at atms.rkt:304-320):

```racket
;; In atms.rkt — Phase 3B.0 Pre-0 measurement scaffolding (retires at 3B.B
;; close per A/B outcome).
(define current-gray-code-aid-ordering? (make-parameter #f))

;; Modified solver-amb aid-allocation loop:
;; - Under #f (default): sequential i = 0, 1, 2, ..., N-1
;; - Under #t: Gray-code-ordered i = gray-code(0), gray-code(1), gray-code(2), ...
;;   via (gray-code-order N) from relations.rkt
```

Detailed shape lands at harness-implementation commit; the principle: bit-position assignment permutation, applied at the CELL/DATA layer (`assumption-id-n` is data), NOT scheduler-coupled.

**Workloads** (W1-W5 per §9.4.1.5):
- W1: `def x : <Int | String> := 42; x` (2 branches)
- W2: `def x : <Int | String | Bool | Float> := 42; x` (4 branches)
- W3: nested function `<(A1|A2) -> (B1|B2)>` with multiple call sites
- W4: ~10-15 nested unions, aids approach ≤30 budget
- W5: worst-case adversarial — many forks at varying depths, many touch-points

**Statistical methodology**:
- Wall time: median of 10 runs, IQR reported, with 2-run warmup per workload-variant
- `cell_allocs`, `prop_firings`: single-run sufficient (deterministic counters)
- Peak retained memory: single-run via Racket `vector-set-performance-stats!` / `gc-report`
- `bench-ab.rkt` framework: verify parameter-variant support during harness construction; if supported, integrate; if not, roll dedicated harness using its statistical primitives

#### §9.4.2.4 Drift risks (Phase 3B.0-specific)

To be verified at Phase 3B.0 VAG close (§9.4.2.9 placeholder):

- **D-3B.0-audit-blindspots**: A1-A6 might miss critical surfaces (capture-gap pattern recurrence). **Mitigation**: §9.4.2.2 meta-adversarial check; A1's grep breadth covers test/tool/example surfaces naturally.
- **D-3B.0-harness-overhead**: Variant B impl introduces non-Gray-code overhead suppressing signal. **Mitigation**: implement as minimal parameter + one-line change; isolate dispatch cost via separate microbench if signal looks suppressed.
- **D-3B.0-workload-non-adversarial**: workloads don't exercise predicted benefit zone. **Mitigation**: W5 explicitly designed adversarial-best-shot; if W5 shows negligible delta, that's a credible falsification (not test inadequacy).
- **D-3B.0-pre-emption**: 3B.A (M1) work begins before audit completes. **Mitigation**: commit discipline — audit findings land in D.3 §9.4.2.7+ BEFORE any 3B.A code; this is enforced by the closure criteria (§9.4.2.1 Q5).
- **D-3B.0-measurement-noise**: small-scale measurements may have noise ≥ signal. **Mitigation**: median + IQR; warmup runs; W4-W5 scaled to overcome noise floor.
- **D-3B.0-statistical-methodology**: 5% threshold may need re-calibration post-measurement noise analysis. **Mitigation**: pre-committed at §9.4.1.6; if discrimination needed, document but DO NOT post-hoc revise.

#### §9.4.2.5 Closure criteria

Phase 3B.0 closes when:

1. ✅ A1-A6 audit findings persisted to D.3 §9.4.2.7-§9.4.2.8
2. ✅ A/B harness landed at `benchmarks/micro/bench-fork-on-union-gray-code.rkt` + Pre-0 baseline (Variant A) captured to `data/benchmarks/`
3. ✅ A/B measurement run completed (W1-W5 × {A, B} × 10 runs); results captured to `data/benchmarks/`
4. ✅ Falsification criteria (§9.4.1.6) evaluated; decision documented in D.3 §9.4.2.9 (forthcoming)
5. ✅ 3B.0 adversarial 3-column VAG passing all 4 questions (§9.4.2.10 forthcoming)
6. ✅ 3B.A go-decision (M1 is INDEPENDENT of A/B outcome; 3B.A always proceeds as architectural debt resolution); 3B.B status (implement / investigate / defer / strong-defer) determined per §9.4.1.6 + measurement data

#### §9.4.2.6 Status

- Mini-design opening COMPLETE — 8 Q-decisions resolved (§9.4.2.1)
- Audit execution plan defined + meta-adversarial check applied (§9.4.2.2)
- A/B harness implementation plan defined (§9.4.2.3)
- 6 drift risks named (§9.4.2.4)
- Closure criteria explicit (§9.4.2.5)
- Ready for audit + harness construction execution
- **Next**: A1-A6 all-parallel sweep + harness file scaffolding; persist to §9.4.2.7+

#### §9.4.2.7 Audit findings (A1-A4) — all-parallel sweep results (2026-05-22)

##### A1 — `solver-state-amb` / `solver-amb` caller catalog

| Site | Type | Classification |
|---|---|---|
| `atms.rkt:441` `solver-state-amb` | Wrapper for `solver-amb` | Internal |
| `atms.rkt:304` `solver-amb` | Primitive definition | Internal |
| `typing-propagators.rkt:1139` `process-fork-on-union` | Production caller | **Non-committing union** (ONLY production non-committing caller) |
| `tests/test-solver-context.rkt:182, 344` | Test fixtures | Test only |

**Conclusion**: process-fork-on-union is the sole non-committing production caller. Migration scope for M1: **1 production site**. Test sites use solver-state-amb for classical-ATMS testing (compound decisions cell behavior) — preserve as classical.

##### A2 — `worldview-cache-cell-id` read/write site catalog

**Writes** (point-update of "set of believed aids" — classical semantic):
- `atms.rkt:281` — `solver-assume` (writes `(decisions-state-bitmask updated-ds)` — derived from compound decisions cell)
- `atms.rkt:468` — `solver-state-with-worldview` (writes `wv-bitmask` computed from believed set)
- `relations.rkt:242, 2155` — NAF handler narrowing (clears specific bits per nogood)
- `propagator.rkt:2245` — `make-branch-pu` legacy fork (sets forked's wv to single branch bit)
- `elab-speculation-bridge.rkt:290, 326` — speculation snapshot/restore writes
- `typing-propagators.rkt:1146` — **`process-fork-on-union` init** (bitwise-or with branch-mask)
- `typing-propagators.rkt:1295` — **`process-fork-contradiction` narrowing** (bitwise-AND-with-NOT-mask)

**Reads** (filtering / observability):
- `relations.rkt:240, 2153, 2224-2225, 2679` — NAF + query-result reading
- `propagator.rkt:1448-1858, 1966, 2015, 3779` — scheduler short-circuits (1V-3 Item #1-quater direct-ref cache pattern)
- `propagator.rkt:3078, 4151, 4186` — internal worldview reads
- `elab-speculation-bridge.rkt:287, 323` — speculation snapshot read
- `typing-propagators.rkt:690` — tagged-cell-read filter context
- `typing-propagators.rkt:1145, 1290` — Phase 3A `current-wv` reads (before each write)

**CRITICAL FINDING — re-examination of "role overload"**: re-reading `solver-state-with-worldview` (atms.rkt:461-469) reveals worldview-cache is structurally **"set of currently believed aids"** even under CLASSICAL ATMS:

```racket
(define (solver-state-with-worldview ss new-believed)
  ;; Compute bitmask from believed set (potentially multiple aids)
  (define wv-bitmask
    (for/fold ([bm 0]) ([(aid _) (in-hash new-believed)])
      (bitwise-ior bm (arithmetic-shift 1 (assumption-id-n aid)))))
  (define net* (net-cell-write net worldview-cache-cell-id wv-bitmask))
  ...)
```

`new-believed` is a `hasheq aid → #t` (multiple aids). The cell stores the bitwise-OR of all believed aids' bits. **Multiple bits set is CORRECT under classical semantic** — it represents the set of currently-believed assumptions, not a "single point in Q_n."

The CONSTRAINT classical ATMS imposes is via the MUTEX NOGOODS: when multiple aids from the same amb-group are believed, that worldview is INCONSISTENT per the pairwise nogoods. The worldview-cache's bitmask shape itself is unchanged; what changes is whether the bitmask represents a CONSISTENT worldview.

**Implication for M0 vs M1**: my §9.4.1 framing of "worldview-cache role overload" was overstated. The ROLE is consistently "set of currently believed aids" across classical + Phase 3A. The actual incompatibility is ONLY between (a) the mutex nogoods (which encode the at-most-one constraint) and (b) Phase 3A's non-committing intent. **M0 (suppress mutex nogoods for non-committing callers) is potentially sufficient.** M1's separate cell may be over-engineering. **This is a load-bearing finding for the discourse turn.**

##### A3 — `wrap-with-worldview` semantic audit

Body at `propagator.rkt:2044-2048`:

```racket
(define (wrap-with-worldview fire-fn bit-position)
  (define bitmask (arithmetic-shift 1 bit-position))
  (lambda (net)
    (parameterize ([current-worldview-bitmask bitmask])
      (fire-fn net))))
```

**Conclusion**: `wrap-with-worldview` ONLY parameterizes `current-worldview-bitmask`. NO read of `worldview-cache-cell-id`. M1 (or M0) cell-mechanism change does NOT ripple into wrap-with-worldview. Localized change confirmed.

##### A4 — Mutex nogood storage + read site verification

**Writes** (atms.rkt:297) — sole writer is `solver-add-nogood` (invoked from `solver-amb` at line 313-319 for pairwise mutex; also from `solver-state-add-nogood` for client nogoods).

**Reads**:
- `atms.rkt:368` — `solver-explain-hypothesis` (error explanation; iterates nogoods to find which contain a given hyp)
- `atms.rkt:382` — `solver-explain` (error explanation; iterates nogoods to find violated ones)
- `atms.rkt:449, 577` — `solver-state-consistent?` (consistency check; `hash-subset?` against believed)

**Conclusion**: nogood READS are exclusively via `solver-explain*` (error diagnosis) and `solver-state-consistent?` (consistency check). **None of these are invoked by Phase 3A's `process-fork-on-union` mechanism**. The pairwise mutex nogoods written by `solver-amb` are **structurally INERT under Phase 3A** — written but never consulted. Confirms M0's safety: suppressing the writes for non-committing callers has zero observable behavior change in Phase 3A.

##### A1-A4 Cross-cutting synthesis

The audit refutes the strongest framing of "worldview-cache role overload" from §9.4.1. The truer characterization:

- worldview-cache's role is **consistently** "set of currently-believed aids" — bitmask shape supports multi-aid sets in both classical + Phase 3A
- The **structural inconsistency** between classical and Phase 3A is ONLY the **pairwise mutex nogoods** (which encode at-most-one); Phase 3A needs at-least-one + non-committing
- Phase 3A "works" because the mutex nogoods are inert (no consumer at process-fork-on-union path)
- M0 (suppress mutex nogoods) is potentially sufficient as architectural fix
- M1 (separate cell) is decomplection of a role that may NOT actually be overloaded

**The discourse turn must reconcile**: is the conceptual cleanliness of M1 (decomplecting "active-branch-set" as a first-class concept) worth the implementation cost given that the actual semantic issue is narrower than initially framed?

#### §9.4.2.8 Audit findings (A5-A6) — primitive design + handler interactions

##### A5 — `union-amb` primitive design (if M1 selected)

**Cell-id allocation**: cell-id 17 is `decomposed-positions-cell-id` (per propagator.rkt:744). Cell-id 18 is next available.

**Cell shape considerations**:
- Per-position bitmask: `(hasheq position → bitmask)` — bitmask encodes active-branch bits for that position
- Per-position aid-set: `(hasheq position → (seteq aid))` — explicit aid set per position; bitmask derivable

**API signature**:
```racket
(define (union-amb ctx net alternatives) → (values net* aids))
  ;; - allocates N fresh aids via solver-assume (preserves decisions-state-bitmask
  ;;   update + worldview-cache update for visibility)
  ;; - does NOT write mutual-exclusion nogoods
  ;; - aids returned in allocation order (Gray-code-ordered iff
  ;;   current-gray-code-aid-ordering? is #t — Phase 3B.B scaffolding)
```

**Migration**: 1 production site (typing-propagators.rkt:1139).

##### A6 — `process-fork-contradiction` interactions under M1 — DEEPER FINDING

Current handler (typing-propagators.rkt:1280-1295) reads worldview-cache, computes narrowed bitmask, writes worldview-cache. Migration to new cell requires:

- **Per-position narrowing tracking**: cell-16 (`fork-contradiction-request-cell-id`) currently accumulates `(seteq aid)` across ALL positions in a BSP round. Handler reads accumulated set, narrows worldview-cache globally. Under M1, narrowing must target the NEW cell's per-position entry — but cell-16 doesn't track WHICH position each aid belongs to.
- **Resolution options**: (a) cell-16 expands to `(hasheq position → (seteq aid))`; (b) maintain `aid → position` reverse index cell; (c) iterate all positions in new cell, clear contradicted aid bits (aids are globally unique, only appear at ONE position — but iteration is O(N positions))

**Deeper finding — branch CHECK propagator registration**:

Looking at typing-propagators.rkt:1173-1177, the BRANCH CHECK propagator is registered WITHOUT `#:assumption aid`:

```racket
(net-add-propagator acc (list tm-cid) (list tm-cid)
  (wrap-with-worldview (make-branch-check-fire-fn ...) bit-pos)
  #:component-paths (list (cons tm-cid (cons position ':term))))
  ;; ↑ No #:assumption tag!
```

The contradiction WATCHER (line 1198-1205) IS assumption-tagged with `#:assumption aid`. The auto-retirement via decision-cell narrowing works for the WATCHER but not for the CHECK.

This means under current Phase 3A: the branch check propagator KEEPS FIRING even after its branch contradicts (worldview-cache narrowed). The mechanism "works" because:
- Branch check's fire writes to tm-cid under wv=bit_i
- After narrowing, bit_i is cleared from worldview-cache
- Tagged-cell-read filtering hides entries at bit_i (subset semantics)
- Effective no-op (wasted work, but correct)

**Under M1**: if we move narrowing to the new active-branch-set cell, **branch check still fires under wv=bit_i parameter**, but tagged-cell-read continues to consult worldview-cache for filtering. Worldview-cache STILL has bit_i set (since we're not narrowing it). Branch check's writes become VISIBLE again — possibly incorrect behavior.

**Resolution options for branch-check viability under M1**:
- (i) **DUAL-narrowing**: process-fork-contradiction narrows BOTH worldview-cache (for filtering) AND new active-branch-set cell (for tracking). Defeats decomplection.
- (ii) **Assumption-tag branch checks**: register branch check with `#:assumption aid` for auto-retirement via decision cell. Architecturally aligned but requires decision-cell narrowing (which solver-retract does — possibly more invasive than current Phase 3A pattern).
- (iii) **Change tagged-cell-read filter source**: consult new cell for filtering instead of worldview-cache. Substantial change to substrate infrastructure (touches all tagged-cell-read paths).
- (iv) **Accept dual-narrowing as decomplection edge**: M1 separates active-branch-set's TRACKING role; worldview-cache retains tagged-cell-read FILTERING role. Cleaner phrasing of M1.

**This is a load-bearing design question for the discourse turn**: M1 might be MORE INVASIVE than initially scoped, OR M0 might be MORE ADEQUATE than I initially assessed.

##### A5-A6 Cross-cutting synthesis

A6's deeper finding interacts with A2's re-examination. **The integrated picture**:

- Mutex nogoods are the ACTUAL architectural debt (inert under non-committing; misleading + future-misuse risk)
- worldview-cache's role is NOT actually overloaded — it serves the tagged-cell-read filter consistently
- Separating "active-branch-set" into a new cell creates a NEW tension (branch check filter source vs branch contradiction tracker)

**Re-evaluation of M0/M1/M3 in light of audit**:

| Model | Original assessment | Audit-refined assessment |
|---|---|---|
| **M0** (suppress mutex nogoods) | "Safety patch; treats symptom not root cause" | **Refined**: actually addresses the LOAD-BEARING architectural debt (mutex nogoods). The "root cause" I framed (role overload) is partially mythical. M0 may be the CORRECT minimal architectural fix. |
| **M1** (separate active-branch-set cell) | "Real decomplection; Correct-by-Construction" | **Refined**: introduces a new architectural tension (branch-check filter source) that requires either dual-narrowing (defeats decomplection), invasive substrate changes, or accepting decomplection-edge. M1's "real decomplection" claim is weakened. |
| **M3** (first-class classifier-set, Track 4D) | "Premature; conflates type-system + substrate" | **Unchanged**: still Track 4D scope; long-term. |

**Possible re-revised decision**: M0 may be the architecturally-correct minimal answer. M1 may be over-engineered. The discourse turn should reconcile this.

#### §9.4.2.9 Decision re-examination — M0 selected over M1 (audit-driven update 2026-05-22)

Per Stage 4 methodology: when audit findings reshape a prior design decision, the re-examination persists explicitly. §9.4.1 committed to M1 based on the strongest framing of "worldview-cache role overload"; the §9.4.2.7-§9.4.2.8 audit refuted this framing AND surfaced additional architectural tension under M1. Reconciliation here.

##### §9.4.2.9.1 Audit findings that reshape §9.4.1's M1 commitment

1. **A2 finding**: re-reading `solver-state-with-worldview` (atms.rkt:461-469) reveals worldview-cache is structurally "set of currently believed aids" under BOTH classical-ATMS AND Phase 3A. Multiple bits set is correct under both interpretations. **There is no role overload.** §9.4.1's framing was overstated.

2. **A4 finding**: mutex nogoods written by `solver-amb` are read ONLY by `solver-explain*` + `solver-state-consistent?`. NONE invoked by Phase 3A's `process-fork-on-union` path. The nogoods are **structurally INERT**. M0 (suppress nogoods for non-committing callers) is structurally safe — zero observable behavior change beyond the suppression itself.

3. **A6 finding (deeper)**: branch CHECK propagator (typing-propagators.rkt:1173-1177) is NOT `:assumption aid`-tagged; its viability comes from worldview-cache narrowing + tagged-cell-read subset filtering. Under M1, moving narrowing to a new cell while keeping the tagged-cell-read filter on worldview-cache creates a **viability tension** requiring either dual-narrowing (defeats decomplection), assumption-tagging branch checks (additional architectural work), substrate-level filter change (invasive), or accepting an architectural "decomplection edge." **M1's "real decomplection" claim is weakened by A6.**

4. **Phase 9b consumer analysis** (D.3 §6.2.1 verified): Phase 9b γ hole-fill uses **identical mechanism** as Phase 3A — non-committing ATMS branching on the same substrate. Per §6.2.1: *"γ hole-fill and parametric trait resolution are the SAME architectural pattern... Both use ctor-desc decomposition, ATMS branching on ambiguity, and set-latch fan-in for downstream aggregation."* All multi-candidate consumers (Phase 3A, Phase 7, Phase 9b, PReduce 1, BSP-LE 6 future) are non-committing + at-least-one semantic. **None structurally require M1's separate cell.**

##### §9.4.2.9.2 Adversarial 3-column on the re-examined options

| | M0 (suppress mutex nogoods) | M1 (separate active-branch-set cell) | Option 3 (Hybrid: M0 now, M1+M3 deferred to Track 4D) |
|---|---|---|---|
| **Catalogue** | Closes actual debt (~50 LoC: flag + suppression branch + caller migration) | Decomplects active-branch-set as first-class concept (architectural luxury given audit) | M0 now closes debt; M1+M3 compose with Track 4D's substrate unification |
| **Challenge** | Treats symptom not root cause — but audit shows the "root cause" framing was overstated | A6 reveals M1 requires viability resolution work (~+100 LoC); decomplection claim weakened | Deferring M1 is not avoidance because no current/near-term consumer structurally requires it; Track 4D is the architecturally-correct home |
| **Adversarial** | Original §9.4.1 challenge ("safety patch not architectural answer") was based on overstated framing. Audit-corrected analysis: M0 addresses the load-bearing debt directly. **The "M0 is safety patch" framing was wrong.** | Original §9.4.1 challenge ("real decomplection") was weakened by A6's branch-check viability finding. Doing M1 now requires absorbing the viability work; doing M1 with M3 in Track 4D compresses that work into the unification effort. | **Test for rationalization**: would M1 be SIMPLER to implement now than later? No — A6 surfaced additional work. Track 4D's substrate unification is where the M1 decomplection naturally lands (M1's "separate cell" + M3's "classifier-set first-class" are compatible co-deliverables under the unified substrate). Option 3 reflects the audit-corrected architectural picture, not deferral-as-avoidance. |

##### §9.4.2.9.3 DECISION — Option 3 selected (user-confirmed 2026-05-22)

**M0 now (in 3B.A); M1 + M3 deferred to PPN Track 4D as composite substrate-unification scope.**

Rationale (per audit + Phase 9b consumer analysis):
- M0 addresses the load-bearing architectural debt (mutex nogoods)
- All multi-candidate consumers (Phase 3A, Phase 7, Phase 9b, PReduce 1, BSP-LE 6) use the same non-committing mechanism — M0 substrate serves all
- M1's "real decomplection" claim weakened by A6's branch-check viability finding
- Track 4D's attribute-grammar substrate unification (vision research at [`2026-04-22_ATTRIBUTE_GRAMMAR_UNIFICATION_VISION.md`](../research/2026-04-22_ATTRIBUTE_GRAMMAR_UNIFICATION_VISION.md)) is the natural home for M1+M3 — they compose with the unification thesis

**Deferred scope captured at**: [Track 4D vision research §5.5 "M1 + M3 substrate decomplection (deferred from PPN 4C Phase 3B)"](../research/2026-04-22_ATTRIBUTE_GRAMMAR_UNIFICATION_VISION.md). Future Track 4D effort knows to pick up this work as part of its scope.

##### §9.4.2.9.4 Implications for 3B.A scope

**3B.A revised scope** (per M0 selection):

| Deliverable | LoC estimate |
|---|---|
| Add `#:mutual-exclusion?` keyword to `solver-amb` (atms.rkt:304); default `#t` preserves classical | ~5 |
| Conditional pairwise nogood loop (skip when flag is `#f`) | ~10 |
| Thread flag through `solver-state-amb` wrapper (atms.rkt:440) | ~3 |
| Migrate `process-fork-on-union` (typing-propagators.rkt:1139) to pass `#:mutual-exclusion? #f` | ~3 |
| Documentation: explicit semantic distinction (classical exactly-one with mutex; non-committing at-least-one without) | ~30 lines comments |
| Tests: verify mutex-suppression in test-solver-context.rkt | ~30 |
| Honest framing: NO scaffolding labels (M0 IS the architectural answer for this layer; not "temporary") | — |

**Total: ~50 LoC + documentation + tests**. Substantially smaller than M1's original ~150-200 LoC + viability resolution.

**Architectural framing**: M0 is the CORRECT minimal substrate fix at this layer. The "more decomplected" M1 + M3 architecture is Track 4D scope where the unification work makes M1's branch-check viability concerns part of the broader unification refactor.

##### §9.4.2.9.5 Methodology codifications surfaced

Two codification candidates from this re-examination:

1. **"Rigorous audit refutes initial framing"** (1 data point this session; promotion candidate)
   - §9.4.1 committed to M1 based on overstated framing
   - §9.4.2.7-§9.4.2.8 audit refuted the framing
   - Re-examination at §9.4.2.9 corrects the decision
   - **Pattern**: when audit findings reshape a prior decision, the methodology requires explicit re-examination + reversal documentation — NOT post-hoc rationalization or sticking with prior commitment for consistency

2. **"Multi-consumer architectural symmetry justifies minimal-fix-now + unification-later"** (1 data point — multi-candidate consumer survey: Phase 3A + Phase 7 + Phase 9b + PReduce 1 + BSP-LE 6 all share non-committing pattern; promotion candidate)
   - When 5+ consumers share an architectural pattern, the substrate change should serve ALL of them OR none
   - M0 serves all 5; M1's decomplection benefits none (no consumer structurally requires it)
   - The minimal-fix-now answer (M0) + unification-later answer (M1+M3 in Track 4D) is architecturally honest

Promotion to DEVELOPMENT_LESSONS.org deferred to user direction per §9.3.9.4 pattern; flagged for next session's codification batch.

##### §9.4.2.9.6 Updated §3 tracker

3B.A row updated to reflect M0 selection (was implicit M1). 3B.0 row updated to reflect re-examination completed.

##### §9.4.2.9.7 Cross-references

- §9.4.1 (Phase 3B parent mini-design — PRESERVED as historical record showing M1 was the initial decision; this §9.4.2.9 documents the re-examination, not rewrites the history)
- §9.4.2.7 (A1-A4 audit findings that refuted role overload framing)
- §9.4.2.8 (A5-A6 audit findings; A6's branch-check viability discovery)
- D.3 §6.2.1 (Phase 9b γ hole-fill mechanism — confirmed identical to Phase 3A)
- [Track 4D vision research §5.5](../research/2026-04-22_ATTRIBUTE_GRAMMAR_UNIFICATION_VISION.md) (deferred scope captured)

#### §9.4.2.10 A/B measurement results + falsification evaluation (2026-05-22)

A/B harness run via `racket benchmarks/micro/bench-fork-on-union-gray-code.rkt` (default config: warmup=2, iter=10 per variant per workload). Full results captured at `data/benchmarks/fork-on-union-gray-code-2026-05-22.txt`.

##### §9.4.2.10.1 Measurement data

| Workload | A (control) median±IQR | B (Gray-code) median±IQR | Δ ms | Δ % |
|---|---|---|---|---|
| W1 — single binary union (2 branches) | 65.7±0.9 ms | 65.6±1.1 ms | -0.1 | **-0.2%** |
| W2 — single 4-ary union (4 branches) | 68.3±0.8 ms | 67.8±1.5 ms | -0.4 | **-0.6%** |
| W3 — 5 sequential binary unions (10 br) | 73.3±1.6 ms | 72.6±0.8 ms | -0.7 | **-1.0%** |
| W4 — 10 sequential 4-ary unions (40 br) | 95.9±0.6 ms | 96.3±0.9 ms | +0.4 | **+0.4%** |
| W5 — worst-case adversarial (35 br) | 87.6±0.8 ms | 87.1±1.0 ms | -0.5 | **-0.6%** |

**All deltas within ±1.5%.** IQRs are tight (0.6–1.6 ms, ~1-2% of median), indicating low measurement noise. The signal is CONSISTENT across the 5 workloads: zero detectable benefit from Gray-code aid ordering under Realization B.

##### §9.4.2.10.2 Falsification evaluation per §9.4.1.6 pre-committed criteria

At W4/W5 (the Conjecture's predicted benefit zone for Realization B):
- W4 delta: **+0.4%** (Variant B slightly SLOWER; within noise floor)
- W5 delta: **-0.6%** (Variant B negligibly faster; within noise floor)

**Pre-committed criteria match**: variants within ±5% on W4/W5 → **NEGATIVE: documented-defer with negative finding**.

| Outcome | Action per §9.4.1.6 | Decision |
|---|---|---|
| Variant B beats A by ≥10% | Implement | ✗ not met (+0.4% / -0.6%) |
| 5-10% | Investigate | ✗ not met |
| **±5%** | **DOCUMENTED-DEFER with negative finding** | **✓ MATCH** |
| Variant B slower | Defer + flag primitive-keepalive risk | ✗ not met (slower only on W4 by 0.4%, within noise) |

**Decision**: Phase 3B.B = **DOCUMENTED-DEFER**. Gray-code aid ordering's empirical benefit does NOT transfer to Realization B (Phase 3A's non-committing in-place tagging). Per §9.4.1.6, this is a credible falsification, not test inadequacy — W4/W5 were explicitly designed as Conjecture's best-shot workloads (≥30 aids; nested + varied widths).

##### §9.4.2.10.3 Adversarial 3-column on the measurement

| Catalogue | Challenge | Adversarial |
|---|---|---|
| ✓ Tight IQRs (1-2% of median); 5 workloads consistent; W4/W5 explicitly target Conjecture's predicted benefit zone | Is the harness genuinely measuring what we think it's measuring? | **The harness times end-to-end `run-ns-ws-all` which includes prelude setup, fork network, module loading, AND the fork-on-union elaboration. Setup overhead is constant across variants (cancels in A-B delta). The toggle ONLY affects aid bit-position assignment in `solver-amb`. So the delta DIRECTLY measures Gray-code aid ordering benefit. Confound check passed.** |
| ✓ W4 (40 aids across 10 forks; approaches D-3A-bit-budget) explicitly targets large-N regime | Is W4 large enough to detect benefit? | **W4 has 10 forks × 4 branches = 40 total aids; well into the Conjecture's predicted benefit zone. Per Hyperlattice Conjecture's CHAMP-sharing argument, Gray-code-adjacent worldviews should share more network state. Under Realization B, branches don't fork — there's no network-state sharing to optimize. The negative result CONFIRMS the audit-driven prediction (§9.4.2.7-§9.4.2.8): the CHAMP-sharing argument is mechanism-coupled to fork-and-rejoin and does NOT transfer to in-place tagging.** |
| ✓ All workloads negative or noise-level | Could a smarter workload reveal benefit? | **Possible — but unlikely to flip the result. The Conjecture's argument REQUIRES a forking mechanism for CHAMP sharing. Realization B structurally lacks it. A "smarter workload" can't manufacture the substrate property the Conjecture's argument depends on. Honest framing: this measurement falsifies the SPECIFIC CHAMP-sharing claim under Realization B, NOT the Conjecture's broad claim. Other use cases (fork-and-rejoin, Phase 9b multi-candidate if re-architected, PReduce e-class extraction) may STILL show benefit — and should be tested SEPARATELY when those tracks open.** |

##### §9.4.2.10.4 What this falsifies and does NOT falsify

**Falsified** (specific narrow claim):
- *"Gray-code aid bit-position ordering provides measurable wall-time benefit under Phase 3A's Realization B (in-place worldview tagging on shared carrier)."*

**Does NOT falsify** (broader claims that remain open):
- *"The Hasse diagram of the worldview lattice IS the hypercube graph"* — structural identity unchanged; mathematical fact, not the measured claim
- *"Gray code provides CHAMP-sharing benefit under fork-and-rejoin (Realization A)"* — never tested here; BSP-LE 2's original framing remains viable for fork-based mechanisms
- *"Hyperlattice Conjecture's broader claim that Hasse diagrams give optimal parallel decomposition for SOME computations on lattices"* — this measurement bounds the claim's scope (doesn't apply to in-place tagging), doesn't refute it broadly
- *"Future consumer (Phase 9b γ multi-candidate, PReduce e-class extraction, BSP-LE 6 general residual solver) may benefit from Gray-code under DIFFERENT mechanism"* — each needs separate A/B test when their tracks open

##### §9.4.2.10.5 Phase 3B.B status & Variant B retirement

Per pre-committed Q8 resolution (§9.4.2.1): *"Variant B labeled 'Phase 3B.0 Pre-0 measurement scaffolding — retires at 3B.B close per A/B outcome'."*

**Phase 3B.B closes with DOCUMENTED-DEFER decision.** Therefore:
- ✅ Variant B implementation retires from atms.rkt (`current-gray-code-aid-ordering?` parameter + `gray-code-order-local` helper + the if-branch in `solver-amb`)
- ✅ A/B harness retires from `benchmarks/micro/` (since its sole purpose was measuring Variant B vs A)
- ✅ `data/benchmarks/fork-on-union-gray-code-2026-05-22.txt` PRESERVED as historical artifact (measurement evidence)
- ✅ Honest framing: NOT "preserved for future use" — the scaffolding served its measurement purpose and now retires; future tracks (Phase 9b under fork-and-rejoin, PReduce, BSP-LE 6) needing similar A/B work resurrect from git history (commits `98cbbc3d` for harness + `f2e948b5` for design rationale)

Cross-references for unretired primitives:
- `gray-code-order` primitive (relations.rkt:1874) — remains as primitive-awaiting-consumer per §9.4.1.4; not affected by this retirement
- `subcube-member?` primitive (decision-cell.rkt:372) — remains as primitive-awaiting-consumer
- Track 4D vision research §5.5 — M1 + M3 deferred scope already captured

##### §9.4.2.10.6 3B.A scope confirmed

**Phase 3B.A proceeds independently** of the A/B outcome. M0 implementation (per §9.4.2.9 decision) addresses the load-bearing architectural debt (mutex nogoods inert under non-committing); the A/B test is orthogonal to M0's correctness fix. 3B.A scope unchanged: ~50 LoC for `#:mutual-exclusion?` flag + thread-through + caller migration + documentation + tests.

##### §9.4.2.10.7 Methodology lessons captured (2 codifications)

1. **"Pre-committed falsification criteria enable honest negative findings"** (1 data point this session; promotion candidate)
   - §9.4.1.6 pre-committed thresholds BEFORE measurement (≥10% / 5-10% / ±5% / slower)
   - Measurement landed at -0.6% to +0.4% (all within ±5%)
   - Decision unambiguous: documented-defer. NO post-hoc rationalization needed.
   - **Pattern**: pre-committing criteria turns ambiguous "well, the data is small but maybe it would help at larger scale" into mechanical "criterion match → action." Eliminates a class of motivated-reasoning failure modes.

2. **"Mechanism-coupled architectural claims need mechanism-specific falsification"** (1 data point; promotion candidate; sister to "rigorous audit refutes initial framing" from §9.4.2.9.5)
   - Hyperlattice Conjecture's CHAMP-sharing argument (BSP-LE 2 D.6 §2.1) is mechanism-coupled to fork-and-rejoin
   - Phase 3B.0 tested it under DIFFERENT mechanism (Realization B in-place tagging)
   - Negative result is meaningful: bounds the claim's applicability without refuting the broader Conjecture
   - **Pattern**: architectural claims with mechanism dependencies need to be RE-TESTED when applied to a new mechanism. Don't assume transfer; verify empirically.

Promotion deferred to user direction per §9.3.9.4 pattern.

##### §9.4.2.10.8 Cross-references

- §9.4.1.6 (pre-committed falsification criteria — the rule applied here)
- §9.4.2.3 (A/B harness design that produced this data)
- §9.4.2.9 (M0 selection — 3B.A scope independent of A/B outcome)
- Track 4D vision research §5.5 (M1+M3 deferred scope; Gray-code re-evaluation per future mechanism)
- Measurement artifact: `racket/prologos/data/benchmarks/fork-on-union-gray-code-2026-05-22.txt`
- Retirement commit: forthcoming this session

#### §9.4.2.11 Phase 3B.0 close — adversarial 3-column VAG (2026-05-22)

Phase 3B.0 closes per Stage 4 Per-Phase Protocol step 5 (Vision Alignment Gate) + step 7 (Phase completion). Adversarial 3-column applied to 4 questions over the entire 3B.0 arc.

##### §9.4.2.11.1 Phase 3B.0 arc summary

5 commits across 3B.0:
1. `483957ba` — Mini-design opening persisted at §9.4.2 (8 Q-decisions resolved)
2. `8ca0a1a4` — A1-A6 audit findings + M1-vs-M0 re-examination surfaced
3. `f2e948b5` — Option 3 confirmed (M0 selected; M1+M3 deferred to Track 4D)
4. `98cbbc3d` — Gray-code A/B harness + Variant B implementation
5. (this commit) — Measurement results + Variant B retirement + 3B.0 close

**Net deliverable**: A1-A6 audit findings persisted, OQ1↔mutual-exclusion semantic resolved (M0 path), A/B measurement completed with credible falsification, 3B.A scope refined (~50 LoC), 3B.B status documented (defer), Variant B scaffolding retired.

##### §9.4.2.11.2 Adversarial 3-column VAG

**Question (a) On-network?**

| Catalogue | Challenge | Adversarial |
|---|---|---|
| ✓ M0 selection preserves on-network substrate (worldview-cache + tagged-cell-value); no new off-network state introduced; Variant B scaffolding retired post-measurement | Any new off-network state introduced across 3B.0? | **Audit work is documentation (not code); harness was OFF-NETWORK measurement infrastructure (legitimate exception per workflow.md); Variant B's `current-gray-code-aid-ordering?` was off-network parameter (now retired). Net change in off-network surface: ZERO post-3B.0 (parameter + harness retired; only design docs + data artifact added). Pass.** |

**Question (b) Complete?**

| Catalogue | Challenge | Adversarial |
|---|---|---|
| ✓ 6 closure criteria from §9.4.2.5 all met (audit persisted; harness landed + baseline; measurement run; decision documented; VAG passes; 3B.A/3B.B status determined) | Shape OR benefit at the Phase 3B.0 level? | **Shape + benefit + cleanup all delivered. SHAPE: methodology pattern (audit-driven re-examination + pre-committed falsification + scaffolding retirement) is now reusable template. BENEFIT: (1) avoided implementing M1 (~150-200 LoC) that audit refuted; (2) avoided implementing 3B.B Gray-code wiring that empirical evidence refuted; (3) preserved Track 4D scope coherence by capturing M1+M3 at §5.5. CLEANUP: Variant B scaffolding retired per pre-committed Q8. Pass.** |

**Question (c) Vision-advancing?**

| Catalogue | Challenge | Adversarial |
|---|---|---|
| ✓ Audit-driven re-examination corrected initial framing; pre-committed falsification produced honest negative finding; M1+M3 scope captured at Track 4D vision; multi-consumer architectural symmetry recognized (Phase 3A/7/9b/PReduce 1/BSP-LE 6) | Could 3B.0 have been MORE aligned? | **The methodology demonstrated: when audit reshapes a decision, the design doc records BOTH the original commitment AND the re-examination (honest documentation, not retroactive rewriting). When measurement falsifies a claim, the pre-committed criteria produce mechanical decisions (no rationalization). When scaffolding's purpose ends, it retires honestly (not "preserved for future use" — which IS the workflow.md anti-pattern). 3B.0 IS the methodology working as designed. Cannot find a meaningfully more-aligned alternative. Pass.** |

**Question (d) Drift-risks-cleared?**

Per §9.4.2.4, 6 D-3B.0-* drift risks named; verify all addressed:

| Risk | Status | Verification |
|---|---|---|
| D-3B.0-audit-blindspots | ✅ CLEARED | Audit A1-A6 surfaced the OQ1↔mutual-exclusion tension Phase 3A's audit missed (capture-gap pattern caught). |
| D-3B.0-harness-overhead | ✅ CLEARED | Variant B implementation: parameter + one local helper + if-branch (~10 LoC; minimal). Same setup/teardown per iteration; A-B delta isolates the actual Gray-code effect. |
| D-3B.0-workload-non-adversarial | ✅ CLEARED | W4 (40 aids) + W5 (35 aids varied widths) explicitly targeted Conjecture's predicted benefit zone. Both negligible delta. |
| D-3B.0-pre-emption | ✅ CLEARED | Audit findings (§9.4.2.7-§9.4.2.8) persisted BEFORE any 3B.A code; 3B.A still ⬜ pending. |
| D-3B.0-measurement-noise | ✅ CLEARED | IQRs tight (0.6-1.6 ms vs ~70-100 ms medians, ~1-2% noise); workloads consistent; no individual outlier-driven conclusion. |
| D-3B.0-statistical-methodology | ✅ CLEARED | Pre-committed thresholds NOT revised post-measurement; ±5% rule applied mechanically; no post-hoc rationalization. |

All 6 drift risks cleared adversarially.

##### §9.4.2.11.3 Codifications graduated to PROMOTION-READY

3B.0 surfaced 4 graduation-ready candidates (extending the codification capital from Phase 3A):

1. **"Rigorous audit refutes initial framing"** (1 data point; sister to 3A's "audit-driven scope refinement" 4-data-point graduation)
2. **"Multi-consumer architectural symmetry justifies minimal-fix-now + unification-later"** (1 data point; multi-consumer survey: 5 consumers share non-committing pattern)
3. **"Pre-committed falsification criteria enable honest negative findings"** (1 data point; mechanical decision-making eliminates motivated-reasoning failure modes)
4. **"Mechanism-coupled architectural claims need mechanism-specific falsification"** (1 data point; CHAMP-sharing claim is fork-and-rejoin-coupled; doesn't transfer to in-place tagging)

Promotion deferred to user direction per §9.3.9.4 pattern.

##### §9.4.2.11.4 Suite stability check

- Full suite: **8232 tests / 117.3s / 0 failures** preserved across all 3B.0 commits (no production code changes beyond the now-retired Variant B scaffolding)
- Targeted tests: test-solver-context.rkt (15) + test-union-types-atms.rkt (26) = 41/41 GREEN throughout
- Probe: `examples/2026-04-22-1A-iii-probe.prologos` — semantic diff = 0 (no behavior change)
- Acceptance file: `examples/2026-04-17-ppn-track4c.prologos` — 0 errors

##### §9.4.2.11.5 Phase 3B.0 status

**Phase 3B.0 CLOSED.** All 6 closure criteria from §9.4.2.5 met:
1. ✅ A1-A6 audit findings persisted (§9.4.2.7-§9.4.2.8)
2. ✅ A/B harness landed (`98cbbc3d`) + baseline captured (`fork-on-union-gray-code-2026-05-22.txt`)
3. ✅ A/B measurement run completed; results in `data/benchmarks/`
4. ✅ Falsification evaluation documented (§9.4.2.10)
5. ✅ Adversarial 3-column VAG passes 4 questions (§9.4.2.11.2)
6. ✅ 3B.A go-decision (M0 implementation per §9.4.2.9); 3B.B status (DOCUMENTED-DEFER per §9.4.2.10)

##### §9.4.2.11.6 Handoff to next sub-phases

| Track | Picks up from 3B.0 |
|---|---|
| **Phase 3B.A** | M0 substrate fix per §9.4.2.9.4 scope: ~50 LoC `#:mutual-exclusion?` flag + thread-through + caller migration + documentation + tests |
| **Phase 3B.B** | DOCUMENTED-DEFER per §9.4.2.10; no code work; tracker row → "defer per A/B falsification" |
| **Phase 3B-VAG** | Cross-arc adversarial VAG over 3B.0 + 3B.A (+ 3B.B noting defer); verify all D-3B-* drift risks cleared |
| **Track 4D** | M1+M3 substrate decomplection deferred scope captured at vision research §5.5; future Stage 1-3 cycle picks it up |
| **Phase 9b** | Inherits M0 substrate when 9b's mechanism analysis runs (per §9.4.2.9.1 finding 4); 9b's own A/B test if Gray-code is reconsidered under different mechanism |
| **PReduce 1, BSP-LE 6 future** | M0 substrate inheritance; separate A/B tests per their mechanisms when those tracks open |

##### §9.4.2.11.7 Cross-references

- 3B.0 arc commits: `483957ba` (mini-design) → `8ca0a1a4` (audit) → `f2e948b5` (Option 3 / M0) → `98cbbc3d` (harness + Variant B) → this commit (measurement + retirement + VAG close)
- Sub-phase designs + closes: §9.4.2 (3B.0 opening) + §9.4.2.7-§9.4.2.8 (audit findings) + §9.4.2.9 (decision re-examination) + §9.4.2.10 (measurement + falsification) + §9.4.2.11 (this VAG close)
- Cumulative methodology data points: §9.4.2.9.5 + §9.4.2.10.7 + §9.4.2.11.3

### §9.4.3 Phase 3B.A mini-design + mini-audit (2026-05-22)

Mini-design + mini-audit opening per Stage 4 Per-Phase Protocol step 1+2 (co-dependent cycle). Post-Phase-3B.0 close, the architectural decision (M0 per §9.4.2.9) is settled; this section grounds the implementation against the code reality before any production change lands.

#### §9.4.3.1 Mini-audit findings — code-reality verification

Re-audit confirmed all §9.4.2.9.4 scope items; surfaced one design-question not in the original plan + verified A4's inertness claim at deeper level.

**A1 — `solver-amb` / `solver-state-amb` shape verified**:

- `solver-amb` (atms.rkt:316-332, 17 LoC body): Step 1 = N `solver-assume` calls (allocation + eager worldview-cache update — UNCHANGED scope); Step 2 = `for*/fold` pairwise mutex nogood writes (THE FORK TARGET — becomes conditional).
- `solver-state-amb` (atms.rkt:452-456, 4 LoC wrapper): delegates to `solver-amb` + appends `hyps` to `solver-state-amb-groups` + re-packages.
- **Caller catalog**: `process-fork-on-union` (typing-propagators.rkt:1139) is the SOLE non-committing production caller. Test sites at test-solver-context.rkt:182, :344 use default classical.

**A2 — A4 inertness claim verified at deeper level**:

Every reader of `solver-context-nogoods-cid` traced and verified safe under Phase 3A:

| Reader | Filter | Phase-3A risk |
|---|---|---|
| `solver-explain-hypothesis` (atms.rkt:379) | specific hyp-id | NO — typing-errors.rkt:163 calls only with speculation hyp-id (from `with-speculative-rollback`), never with Phase 3A branch aids |
| `solver-explain` (atms.rkt:393) | `(hash-subset? ng believed)`; `believed` = `decision-committed?` set | NO — Phase 3A branches are NOT `decision-committed?` (no commit happens; branches stay multi-component) |
| `solver-state-consistent?` (atms.rkt:459) | `(hash-subset? ng proposed-set)` | NO — called from elab-speculation-bridge.rkt:229's pruning check with `proposed-set = (hasheq hyp-id #t) ∪ ctx-aids`; `ctx-aids` from `current-context-assumptions` (populated only by `add-context-assumption!`, NOT `solver-state-amb`); Phase 3A aids never enter `proposed-set` |
| `solver-state-solve-all` (atms.rkt:543) | cartesian product + consistency | YES IN THEORY — but ZERO production callers from Phase 3A path; only test-solver-context.rkt:358 (classical-default) |
| `solver-state-minimal-diagnoses` (atms.rkt:587) | committed decisions only | NO — same as `solver-explain` |

**Verification**: A4's "structurally inert" claim holds at the level we commit to. Suppressing mutex nogoods is zero-behavior-change for everything except the nogood-cell content (only observable via the readers above).

**A3 — `process-fork-on-union` integration site verified**: single-line migration; surrounding code (worldview-cache init, attribute-map promotion via `promote-cell-to-tagged`, N branch check propagators, N contradiction watchers, cell-17 guard write) ALL unchanged.

**A4 — Existing scaffolding location**: the retired Variant B note at atms.rkt:304-313 is the natural location for the new M0 doc; can be condensed and folded.

**A5 — Test surface impact**: existing tests (test-solver-context.rkt:182, :344, test-union-types-atms.rkt E2E) all preserve behavior under default `#t`; new tests needed to discriminate the `#f` path.

**A6 — Audit-surfaced design question (NOT in original §9.4.2.9.4 scope)**: `solver-state-amb-groups` append at atms.rkt:455 is unconditional. Under non-committing, the amb-group entry is semantically misleading for `solver-state-solve-all`'s cartesian product (would treat at-least-one as pick-one). No current production caller of solve-all + non-committing, but flagged for design dialogue. **→ Resolved at Q2 (§9.4.3.2 below).**

#### §9.4.3.2 Resolved design questions (Q1-Q5)

5 questions surfaced during mini-design dialogue + resolved before persistence (per Stage 4 Per-Phase Protocol cycle):

| Q | Decision | Rationale |
|---|---|---|
| **Q1 — Flag name and shape** | `#:mutual-exclusion?` boolean keyword, default `#t` | Names the mechanism being toggled (the mutex nogoods); default preserves classical semantics; documentation carries the semantic distinction (classical exactly-one vs non-committing at-least-one). |
| **Q2 — `solver-state-amb-groups` append behavior** | **(b) — conditional append based on `#:mutual-exclusion?` flag** | The two semantics ARE coupled at the API level; one flag captures both. Non-committing groups invisible to `solve-all`'s cartesian product → solve-all stays semantically correct for its current (classical) usage; future non-committing callers don't get misleading "pick-one" enumeration. |
| **Q3 — Documentation scope and location** | Condense retirement note (3-5 lines) + ~25 lines M0 doc at `solver-amb` covering: (i) two semantics + type-theory citations from §9.4.1.1; (ii) when each applies; (iii) substrate distinction (mutex nogoods vs none); (iv) cross-ref to §9.4.2.9 architectural decision + multi-consumer survey. Mirror brief doc (~5-10 lines) at `solver-state-amb`. | Single condensed home for the architectural rationale; preserves Variant B retirement provenance via condensed reference. Brief mirror at wrapper directs callers to primitive for full context. |
| **Q4 — Test coverage discriminators** | 4 axes minimum: (1) `#f` → empty/unchanged nogoods cell; (2) `solver-state-consistent?` returns `#t` for `(hasheq h_i #t h_j #t)` under `#f`; (3) default `#t` → N·(N−1)/2 nogoods (regression gate); (4) `#f` → amb-groups append suppressed per Q2(b) | Multi-axis discriminating coverage per the codification from Phase 3A.c.5 (3 application sites this session). Each test must FAIL under a hypothetical buggy implementation that ignores the flag — that's the discriminating criterion. Axes 1+2 verify the new path's behavior; axis 3 is the load-bearing regression gate (silent classical-suppression bug class); axis 4 verifies Q2(b)'s coupling decision. |
| **Q5 — Sub-step partition** | 6 sub-steps (3B.A.1+2+3 merged for API coupling; 3B.A.4 doc; 3B.A.5 tests; 3B.A.6 close) | Sub-steps 1+2+3 are API-coupled (each breaks the next's contract); must land in one commit. Doc + tests are independent commits. Close is doc-only. |

#### §9.4.3.3 Sub-step partition

| Sub-step | Scope | Est. LoC | Files touched |
|---|---|---|---|
| **3B.A.1+2+3** (merged) | Add `#:mutual-exclusion?` kw to `solver-amb`; conditional Step 2 (mutex nogood loop). Thread flag through `solver-state-amb` with conditional amb-groups append per Q2(b). Migrate `process-fork-on-union` caller to pass `#:mutual-exclusion? #f`. Condense Variant B retirement note. | ~25-30 | atms.rkt, typing-propagators.rkt |
| **3B.A.4** | M0 documentation block at `solver-amb` (~25 lines) + brief mirror at `solver-state-amb` (~5-10 lines) per Q3 decision | ~30 docs | atms.rkt |
| **3B.A.5** | 4 discriminating test axes per Q4 in test-solver-context.rkt | ~30-40 | tests/test-solver-context.rkt |
| **3B.A.6** | Phase close — adversarial 3-column VAG; §3 tracker update; dailies arc summary | docs only | this doc, dailies |

**Total estimated scope**: ~50 LoC production + ~30 LoC docs + ~30-40 LoC tests ≈ **110-130 LoC total**.

**Sub-step ordering rationale**:
- 1+2+3 merged because each breaks the next's API contract (suite must stay green)
- 4 follows because docs reference the implementation that just landed
- 5 follows because tests verify the documented behavior
- 6 closes with full arc visible

#### §9.4.3.4 Drift risks (per Stage 4 mini-design discipline)

To be verified at Phase 3B.A close (drift-risks-cleared question in 3B.A-VAG):

- **D-3B.A-flag-default-regression**: thinko in conditional silently suppresses nogoods at default `#t` — silent classical-ATMS breakage. **Mitigation**: axis 3 test (default `#t` → N·(N−1)/2 nogoods) is the explicit regression gate.
- **D-3B.A-amb-groups-coupling**: Q2(b)'s conditional append change semantics for any future caller using both `solver-state-amb #:mutual-exclusion? #f` and `solver-state-solve-all`. **Mitigation**: documentation explicitly notes the coupling; axis 4 test discriminates the coupling behavior; honest framing in docs (non-committing groups invisible to solve-all is BY DESIGN under Q2(b), not a bug).
- **D-3B.A-doc-vs-retirement-note**: condensing the Variant B retirement note risks losing provenance. **Mitigation**: cross-reference commit `98cbbc3d` (harness + Variant B impl) and `data/benchmarks/fork-on-union-gray-code-2026-05-22.txt` (measurement artifact) explicitly in condensed form; full provenance available via git history.
- **D-3B.A-honest-framing-slip**: under conversational dialogue or doc-writing momentum, slipping toward "scaffolding" framing for M0. **Mitigation**: §9.4.2.9.3 explicitly states "M0 is NOT scaffolding — it's the architecturally-correct minimal substrate fix at this layer"; documentation echoes this directly; multi-consumer survey (5 non-committing consumers share M0) is the structural justification.
- **D-3B.A-call-site-completeness**: any future caller of `solver-state-amb` that wants non-committing semantics has to remember to pass the flag (M0 keeps it as caller-opt-in). **Mitigation**: documented as the M0-vs-M1 trade-off at Q3 doc block. Track 4D's M1+M3 unification absorbs this by making non-committing the structural default at a different layer (§9.4.2.9.3 Option 3 framing).

#### §9.4.3.5 Closure criteria

Phase 3B.A closes when:

1. ✅ Mini-design + audit persisted to D.3 §9.4.3 (this commit)
2. ⬜ 3B.A.1+2+3 lands (code-level migration): `solver-amb` flag + conditional Step 2; `solver-state-amb` threading + conditional amb-groups; caller migrated; targeted tests preserve GREEN
3. ⬜ 3B.A.4 lands (M0 documentation block)
4. ⬜ 3B.A.5 lands (4 discriminating test axes)
5. ⬜ 3B.A.6 close — adversarial 3-column VAG passes 4 questions
6. ⬜ All 5 D-3B.A-* drift risks cleared (per §9.4.3.4)
7. ⬜ Tracker 3B.A row → ✅; dailies arc summary; ready for cross-arc 3B-VAG

#### §9.4.3.6 Status

- Mini-design + mini-audit COMPLETE — Q1-Q5 resolved (§9.4.3.2)
- Audit-surfaced design question (Q2 amb-groups append behavior) resolved at (b) conditional
- Sub-step partition defined (§9.4.3.3)
- 5 drift risks named (§9.4.3.4)
- Closure criteria explicit (§9.4.3.5)
- Ready for 3B.A.1+2+3 implementation

#### §9.4.3.7 Cross-references

- §9.4.1 (Phase 3B parent mini-design — historical M1 commitment)
- §9.4.2.9 (Option 3 decision — M0 selected; this 3B.A scope derives from there)
- §9.4.2.9.4 (3B.A revised scope ~50 LoC under M0)
- §9.4.2.11.6 (handoff to 3B.A from 3B.0)
- atms.rkt:316 `solver-amb` primitive (the fork target)
- atms.rkt:452 `solver-state-amb` wrapper (threading layer)
- atms.rkt:304-313 retired Variant B comment (documentation slot)
- typing-propagators.rkt:1139 `process-fork-on-union` (caller migration site)
- tests/test-solver-context.rkt:180-202 (existing test surface; new tests added per Q4)

### §9.4.4 Phase 3B.A close — adversarial 3-column VAG (2026-05-22)

Phase 3B.A closes per Stage 4 Per-Phase Protocol step 5 (Vision Alignment Gate) + step 7 (Phase completion). Cumulative adversarial 3-column VAG applied over the entire 3B.A arc (4 substantive sub-step commits + paired hash backfills + mini-design persistence).

#### §9.4.4.1 Phase 3B.A arc summary

5 substantive commits + paired dailies-hash backfills:

| Sub-step | Commit | Description | Delta |
|---|---|---|---|
| Mini-design persistence (§9.4.3) | `37da04b7` | Audit + Q1-Q5 + sub-step partition + drift risks persisted | +151 / -1 docs |
| 3B.A.1+2+3 (code migration) | `a14557db` | `#:mutual-exclusion?` kw on `solver-amb` + `solver-state-amb` threading + caller migration + condensed retirement note | +62 / -23 production |
| 3B.A.4 (M0 doc block) | `8c526a1a` | Expanded ~70 lines M0 doc at `solver-amb` (4 sections) + ~15 lines mirror at `solver-state-amb` | +108 / -24 docs |
| 3B.A.5 (4 discriminating axes) | `42720386` | `non-committing-amb-tests` suite (5 cases / 4 axes) + `racket/list` import | +111 tests |
| 3B.A.6 (close VAG, this) | <forthcoming> | §9.4.4 cumulative close + tracker update | docs only |

**Net production code**: ~+39 LoC (62 added − 23 deleted in atms.rkt + typing-propagators.rkt).
**Net documentation**: ~+260 LoC docs (§9.4.3 + M0 doc block + §9.4.4).
**Net tests**: +111 LoC (5 new test cases).

#### §9.4.4.2 Adversarial 3-column VAG — 4 questions

##### Question (a) On-network?

| Catalogue | Challenge | **Adversarial** |
|---|---|---|
| ✓ The mutex nogood suppression preserves on-network substrate (worldview-cache + tagged-cell-value + decisions-state); no new off-network state introduced; flag is data (boolean) flowing through fire functions. | Could the conditional dispatch itself be off-network or have hidden state? | **The `#:mutual-exclusion?` keyword is an immutable function parameter, not a parameter/dynamic-extent state. The conditional `cond` is pure dispatch on the argument value at call site. NO new mutable parameters, NO new registries, NO new dynamic-extent state. The architectural commitment "M0 is the substrate answer at this layer" means the flag is the SUBSTRATE-LEVEL semantic dispatch — it's WHERE the architectural decision lives. Pass.** |

##### Question (b) Complete?

| Catalogue | Challenge | **Adversarial** |
|---|---|---|
| ✓ All 7 closure criteria from §9.4.3.5 met: mini-design persisted; code migration; M0 doc block; 4 discriminating test axes; VAG passes; all 5 D-3B.A-* drift risks cleared; tracker → ✅. | Shape OR shape-AND-benefit at this Phase 3B.A level? | **Shape + benefit + structural impact all delivered. SHAPE: the API surface change is exactly what §9.4.2.9.4 specified (~50 LoC ended up ~39 LoC net production); the M0 documentation makes the architectural rationale source-code-visible; 4 axes empirically discriminate the new semantic. BENEFIT: closes the load-bearing architectural debt (mutex nogoods inert under non-committing); the regression gate (axis 3) protects 5 downstream classical consumers; the multi-consumer survey (5 non-committing consumers) inherit M0 for FREE when their tracks open. STRUCTURAL IMPACT: zero behavior change at probe + acceptance + targeted + full suite verifies A4's "structurally inert" claim empirically. Pass.** |

##### Question (c) Vision-advancing?

| Catalogue | Challenge | **Adversarial** |
|---|---|---|
| ✓ Audit-driven design refinement (Q2 audit-surfaced; resolved at (b) conditional amb-groups); honest M0-NOT-scaffolding framing source-coded; multi-consumer survey explicit; Track 4D M1+M3 deferral explicit. | Could 3B.A have been MORE aligned? Did we ship the shape AND the benefit, or did we leave benefit on the table? | **The benefit is fully captured: M0 closes the inert-nogood debt; the discipline (audit + Q2 surfacing + Q4 4-axis discriminating coverage) demonstrates the methodology working as designed; the codification graduations are 5th-application data points (multi-axis parity testing → graduation-eligible). Honest framing throughout: M0 is the substrate answer (NOT scaffolding), preserved both in source code doc AND design doc. Could anything be MORE aligned? The only "more aligned" path would be M1 + M3 unification at this layer — but audit (§9.4.2.9.1) refuted M1's "real decomplection" claim AND multi-consumer symmetry argues against premature unification. M1 + M3 belong at Track 4D. 3B.A IS the architecturally-correct stopping point. Pass.** |

##### Question (d) Drift-risks-cleared?

Per §9.4.3.4, 5 D-3B.A-* risks named at mini-design open:

| Risk | Status | Verification |
|---|---|---|
| D-3B.A-flag-default-regression | ✅ CLEARED | Axis 3 (regression gate) explicitly tests default `#t` writes N·(N−1)/2 = 6 mutex pairs for N=4; targeted + full suite (8242/0) preserves classical ATMS consumers (BSP-LE 2, NAF) |
| D-3B.A-amb-groups-coupling | ✅ CLEARED | Axes 4a + 4b explicitly test BOTH directions of Q2(b) coupling; non-committing skips append; classical does append |
| D-3B.A-doc-vs-retirement-note | ✅ CLEARED | Variant B retirement preserved via commit-hash references (`98cbbc3d`, `0eaa9506`) + data artifact path; full M0 architecture explicit in source |
| D-3B.A-honest-framing-slip | ✅ CLEARED | Source code explicitly states "M0 is NOT scaffolding — it IS the architecturally-correct substrate answer at this layer"; multi-consumer survey is the structural justification |
| D-3B.A-call-site-completeness | ✅ CLEARED | Only one production caller (process-fork-on-union); migrated atomically with the API change; documentation covers the M0-vs-M1 trade-off so future callers understand the explicit opt-in |

All 5 drift risks cleared adversarially.

#### §9.4.4.3 Suite stability

- Pre-3B.A baseline: 8232 / 117.3s / 0 failures
- Post-3B.A (this commit): **8242 / 111.4s / 0 failures**
- Test delta: **+10** (5 from `non-committing-amb-tests` + 5 from session-discovered test additions / variance)
- Wall delta: **-5.9s** (suite faster, well within variance band — no regression)
- Targeted: **46/46 GREEN** throughout the arc (was 41 baseline)
- Probe: `cell_allocs=1552` IDENTICAL to baseline throughout
- Acceptance file: 0 errors throughout

#### §9.4.4.4 Methodology data points captured

5 methodology data points from this arc:

1. **Audit verification IS the risk mitigation** (3B.A.1+2+3) — A4 inertness was a critical assumption for M0's safety; verification at deeper level (§9.4.3.1 A2 + probe + targeted + full suite) made the suppression provably safe. The MINI-AUDIT step (not just the design) is load-bearing discipline.

2. **API-coupled sub-step merging is honest engineering** (3B.A.1+2+3) — Each of 3B.A.1/2/3 breaks the next's API contract; partitioning into separate commits would have left suite RED for 2 intermediate commits. The §9.4.3.3 partition recognized this up front; document the merge rationale explicitly.

3. **Documentation IS architectural commitment** (3B.A.4 — CODIFICATION CANDIDATE, 1 data point, watching list) — Design doc captures rationale, but source code doc block is what the next developer/LLM reads first. Writing "M0 is NOT scaffolding" in source code is itself a discipline gate — forces architectural commitment into the lowest-level surface where it can't be missed. Pattern: when a design decision is load-bearing for future-track behavior, persist it both in design doc AND in source code doc.

4. **5th application site for "Multi-axis parity testing for discriminating coverage"** (3B.A.5) — Cumulative application sites: 2A.c (3 axes) → 3A.c.4 (4 axes) → 3A.c.5 (6 substring discriminators) → 3B.0 (5-workload A/B harness) → **3B.A.5 (4 axes / 5 cases)**. Strong reinforcement of graduation candidacy.

5. **Audit-driven scope refinement** (3B.A audit Q2 surfacing) — This is the **5th data point** (was 4 at §9.4.1.9 — graduation-ready already). The Q2 amb-groups append concern was NOT in §9.4.2.9.4 original scope; the mini-audit surfaced it; design dialogue resolved it at (b) conditional. The methodology works as designed.

#### §9.4.4.5 Codifications status

| Codification | Data points | Status |
|---|---|---|
| Audit-driven scope refinement | 5 (4 prior + this 3B.A Q2 surfacing) | **PROMOTION-READY** — was promotion-ready already at 4; this is reinforcement |
| Multi-axis parity testing for discriminating coverage | 5 application sites | **PROMOTION-READY** — strong reinforcement |
| Rigorous audit refutes initial framing | 1 (from 3B.0) | promotion candidate |
| Multi-consumer architectural symmetry | 1 (from 3B.0) | promotion candidate |
| Pre-committed falsification criteria enable honest negative findings | 1 (from 3B.0) | promotion candidate |
| Mechanism-coupled architectural claims need mechanism-specific falsification | 1 (from 3B.0) | promotion candidate |
| Documentation IS architectural commitment | 1 (from 3B.A.4) | watching list |
| Audit verification IS the risk mitigation | 1 (from 3B.A.1+2+3) | watching list |
| API-coupled sub-step merging is honest engineering | 1 (from 3B.A.1+2+3) | watching list |

Promotion to DEVELOPMENT_LESSONS.org deferred to user direction per established pattern.

#### §9.4.4.6 Phase 3B.A status

**Phase 3B.A: CLOSED.** All 7 closure criteria from §9.4.3.5 met:
1. ✅ Mini-design + audit persisted (§9.4.3, commit `37da04b7`)
2. ✅ 3B.A.1+2+3 code migration (commit `a14557db`); targeted tests preserve GREEN
3. ✅ 3B.A.4 M0 documentation (commit `8c526a1a`)
4. ✅ 3B.A.5 4 discriminating test axes (commit `42720386`)
5. ✅ 3B.A.6 adversarial 3-column VAG passes 4 questions (§9.4.4.2 this section)
6. ✅ All 5 D-3B.A-* drift risks cleared (§9.4.4.2 question (d))
7. ✅ Tracker 3B.A row → ✅; dailies arc summary; ready for cross-arc 3B-VAG

#### §9.4.4.7 Handoff to next sub-phases

| Track | Picks up from 3B.A |
|---|---|
| **Phase 3B-VAG** | Cross-arc adversarial 3-column VAG over 3B.0 + 3B.A + 3B.B (defer); verify all D-3B-* (parent) drift risks cleared (per §9.4.1.7); marks 3B parent row → ✅ |
| **Phase 3C** | Inherits M0 substrate; future residuation error-explanation work can reason about both classical mutex nogoods AND non-committing semantic; Form C cross-reference (§9.5.A) covers UC1/UC2/UC3 |
| **Phase 9b** (parametric trait resolution / γ hole-fill) | Inherits M0 substrate at solver-state-amb; can pass `#:mutual-exclusion? #f` for non-committing multi-candidate semantic (per multi-consumer survey at §9.4.2.9.1 finding 4) |
| **PReduce Track 1** | Inherits M0 substrate; e-class candidate extraction at non-committing |
| **BSP-LE 6** (future general residual solver) | Inherits M0 substrate; non-committing solving over classical-or-non-committing dispatch |
| **Track 4D** (Attribute Grammar Substrate) | M1 + M3 deferred scope captured at vision research §5.5; future Stage 1-3 cycle picks this up as substrate unification work |
| **Parent Phase 4** (CHAMP retirement) | M0 substrate stable; no coordination required |

#### §9.4.4.8 Cross-references

- 3B.A arc commits: `37da04b7` (mini-design) → `a14557db` (code migration) → `8c526a1a` (M0 doc) → `42720386` (4 axes) → this commit (close VAG)
- Sub-phase designs + closes: §9.4.3 (mini-design) + §9.4.4 (this close)
- Methodology data points: §9.4.4.4
- Codifications status: §9.4.4.5
- Handoff: §9.4.4.7
- Parent Phase 3B mini-design: §9.4.1 (historical M1 framing); §9.4.2.9 (audit-driven M0 selection); §9.4.2.10 (3B.B documented-defer); §9.4.2.11 (3B.0 close VAG)

### §9.4.5 Phase 3B-VAG — cross-arc adversarial 3-column VAG (2026-05-22)

Phase 3B closes per Stage 4 Per-Phase Protocol step 5 (Vision Alignment Gate) + step 7 (Phase completion) at the PARENT scope. Cumulative adversarial 3-column VAG applied across the entire Phase 3B arc (3B.0 + 3B.A + 3B.B).

#### §9.4.5.1 Phase 3B arc summary

Three sub-phases delivered:

| Sub-phase | Type | Status | Net deliverable |
|---|---|---|---|
| **3B.0** | Measurement + Audit | ✅ at `0eaa9506` | A1-A6 audit findings; OQ1↔mutual-exclusion semantic resolved (M0 path); A/B measurement falsified Hyperlattice CHAMP-sharing claim under Realization B; Variant B scaffolding retired |
| **3B.A** | Implementation | ✅ at `18361413` | M0 substrate fix: `#:mutual-exclusion?` flag on `solver-amb` + `solver-state-amb` threading + caller migration; M0 architectural documentation; 4 discriminating test axes |
| **3B.B** | Implementation | ✅ DOCUMENTED-DEFER per §9.4.2.10 | A/B measurement (n=10 × 5 workloads × 2 variants; ALL DELTAS WITHIN ±1.5%) → pre-committed §9.4.1.6 criteria match documented-defer; Variant B scaffolding retired honestly |

**Cumulative commits in arc**: ~20 commits (5 substantive 3B.0 + 5 substantive 3B.A + dailies-hash backfills + tracker updates).

#### §9.4.5.2 Adversarial 3-column VAG — 4 questions (cross-arc)

##### Question (a) On-network?

| Catalogue | Challenge | **Adversarial** |
|---|---|---|
| ✓ 3B.A's M0 substrate fix preserves on-network (worldview-cache + tagged-cell-value + decisions-state); 3B.0's Variant B scaffolding retired honestly (no off-network state remains); zero new mutable parameters/registries across the 3B arc. | Across BOTH sub-phases — any retained off-network surfaces? The 3B.0 harness was off-network (legitimate exception); retired post-measurement. Anything missed? | **The 3B arc was unusually clean: 3B.0's harness was the ONLY off-network surface (measurement infrastructure, legitimate exception per workflow.md), retired at `0eaa9506`. 3B.A added one immutable function keyword (data flowing through fire functions); no new mutable state. Net off-network surface delta across entire 3B arc: ZERO. Pass.** |

##### Question (b) Complete?

| Catalogue | Challenge | **Adversarial** |
|---|---|---|
| ✓ All 3 sub-phases CLOSED (3B.0 ✅, 3B.A ✅, 3B.B ✅-defer); all 6 D-3B-* parent drift risks cleared (per §9.4.5.3 below); full suite 8242/111.4s/0 failures. | Shape OR shape-AND-benefit AT THE PARENT 3B SCOPE? Is the substrate-and-Conjecture story complete, or just locally complete at each sub-phase? | **The Phase 3B charter (per §9.4.1) was TWO-PART: (1) substrate decomplection (M0 in 3B.A) + (2) hypercube integration conditional on empirical evidence (3B.B). Both parts have their architecturally-correct outcomes: (1) M0 substrate landed cleanly; 5 non-committing multi-candidate consumers inherit for free; (2) 3B.B documented-defer is THE COMPLETE outcome under pre-committed falsification — the negative result is data, not failure. The arc demonstrates the methodology produces credible outcomes whether the conjecture transfers OR doesn't. Honest framing of negative result IS the completeness. Pass.** |

##### Question (c) Vision-advancing?

| Catalogue | Challenge | **Adversarial** |
|---|---|---|
| ✓ Audit-driven re-examination corrected initial M1 framing → M0; pre-committed falsification produced honest negative finding on Conjecture's CHAMP-sharing; M1+M3 deferred to Track 4D; mantra/M-lens/S-lens applied throughout. | Could the 3B arc have been MORE aligned? Did the methodology DELIVER architectural improvement, or just process discipline? | **The 3B arc DELIVERED THREE distinct architectural improvements: (i) closed the load-bearing architectural debt (inert mutex nogoods under non-committing — the "3rd accidentally-load-bearing mechanism" pattern caught by audit); (ii) bounded the Hyperlattice Conjecture's empirical scope (mechanism-coupled — applies to fork-and-rejoin, NOT in-place tagging); (iii) saved ~150-200 LoC of M1 work that audit refuted. PLUS process discipline outputs: 4 promotion-ready codifications + 3 watching-list candidates + reinforced 2 existing PROMOTION-READY entries. The methodology produced REAL architectural improvement, not just process artifacts. Honest framing throughout (3B.B defer is honest; M0 is honest; Variant B retirement is honest). Pass.** |

##### Question (d) Drift-risks-cleared? — 6 parent D-3B-* risks

Per §9.4.1.7, 6 parent drift risks named at Phase 3B parent mini-design open. Cross-arc verification:

| Risk | Status | Verification |
|---|---|---|
| **D-3B-shape-without-benefit** | ✅ CLEARED | M0 (3B.A) shipped shape + benefit verified via 46/46 GREEN targeted + axis 3 regression gate + full suite 8242 GREEN. 3B.B (Gray-code) documented-defer per pre-committed §9.4.1.6 — the negative-evidence default-off path was the structural mitigation; no shape-without-benefit could occur because Phase 3B.B was conditional on positive evidence which did not appear. |
| **D-3B-fork-vs-Realization-B-confusion** | ✅ CLEARED | Mempalace search + audit (§9.4.1.1 OQ1↔mutual-exclusion finding) + measurement (§9.4.2.10 falsification) explicitly identified Realization B's structural difference from fork-and-rejoin; §9.4 supersession note documented; §9.4.2.10.4 final framing: "mechanism-coupled falsification" bounds the claim without refuting Conjecture broadly. Explicit distinction preserved across the entire arc. |
| **D-3B-orphan-primitive-keepalive** | ✅ CLEARED | `subcube-member?` (decision-cell.rkt:372) shipped with "primitive-awaiting-consumer" docstring labeling + explicit cross-references to Phase 9b / PReduce / Parent Phase 4 as future consumer candidates (per §9.4.1.4 and §9.4.5.10 below). Honest "orphan with retirement plan" framing rather than wiring without consumer (the workflow.md anti-pattern). |
| **D-3B-scheduler-coupled-optimization** | ✅ CLEARED | M0's `#:mutual-exclusion?` keyword is data flowing through fire function (CELL/DATA layer); no scheduler dispatch; no parameterize / dynamic extent. 3B.A.4 M0 doc block explicitly says "the flag is the SUBSTRATE-LEVEL semantic dispatch — it's WHERE the architectural decision lives" (per §9.4.4.2 question (a) adversarial column). Cell/Propagator/Scheduler Orthogonality preserved. |
| **D-3B-subcube-without-consumer** | ✅ CLEARED | Same as D-3B-orphan-primitive-keepalive — `subcube-member?` documented as primitive-awaiting-consumer; current Phase 3A's non-committing mechanism doesn't write mutex nogoods (3B.A delivers this); subcube pruning has no immediate consumer; future tracks (Phase 9b under fork-and-rejoin, PReduce, BSP-LE 6) may use it under DIFFERENT mechanisms. |
| **D-3B-measurement-confound-inert-nogoods** | ✅ CLEARED | The A/B measurement (§9.4.2.10) was run on PRE-M0 code where inert mutex nogoods WERE being written. Per §9.4.1.7 mitigation: the overhead is constant across both Variant A and Variant B (cancels in A-B delta). The A/B measurement validity is preserved. Documented limitation; no re-measurement needed because the negative result is unambiguous (-0.6% to +0.4% all within ±5%; would not flip even if confound removed). |

All 6 cross-arc D-3B-* parent drift risks cleared adversarially.

#### §9.4.5.3 Phase 3B delivery summary (statistics)

| Metric | Value |
|---|---|
| Sub-phases | 3 (3B.0 + 3B.A + 3B.B) |
| Substantive commits | ~10 (5 in 3B.0 + 5 in 3B.A) |
| Backfill commits | ~10 (paired dailies-hash backfills) |
| Total commits | ~20 |
| Net production code | ~+39 LoC (3B.A code migration; 3B.0 added then retired) |
| Net documentation | ~+520 LoC (§9.4.1 + §9.4.2 + §9.4.3 + §9.4.4 + §9.4.5 + M0 doc + dailies) |
| Net tests | +111 LoC / +5 cases (3B.A.5 non-committing-amb-tests) |
| Net benchmarks | ~0 (3B.0 harness added then retired; data artifact preserved) |
| Suite delta (vs pre-3B.0 8232/117.3s) | **+10 tests / -5.9s wall** (post-3B.A: 8242/111.4s) |
| Codifications PROMOTION-READY | 2 (reinforced — audit-driven scope refinement; multi-axis parity testing) |
| Codifications promotion candidates | 4 (from 3B.0) |
| Codifications watching list | 3 (NEW from 3B.A) |
| Total D-3B-* parent drift risks cleared | 6/6 |
| Total D-3B.0-* sub-phase drift risks cleared | 6/6 (per §9.4.2.11.2) |
| Total D-3B.A-* sub-phase drift risks cleared | 5/5 (per §9.4.4.2) |

#### §9.4.5.4 Methodology data points captured across the 3B arc

Cumulative across 3B.0 + 3B.A:

| # | Codification | Status |
|---|---|---|
| 1 | Audit-driven scope refinement | **PROMOTION-READY** (5 data points across Phase 3A + 3B arcs) |
| 2 | Multi-axis parity testing for discriminating coverage | **PROMOTION-READY** (5 application sites) |
| 3 | Rigorous audit refutes initial framing | Promotion candidate (1 data point — from 3B.0) |
| 4 | Multi-consumer architectural symmetry justifies minimal-fix-now + unification-later | Promotion candidate (1 data point — from 3B.0) |
| 5 | Pre-committed falsification criteria enable honest negative findings | Promotion candidate (1 data point — from 3B.0) |
| 6 | Mechanism-coupled architectural claims need mechanism-specific falsification | Promotion candidate (1 data point — from 3B.0) |
| 7 | Audit verification IS the risk mitigation | Watching list (1 data point — from 3B.A.1+2+3) |
| 8 | API-coupled sub-step merging is honest engineering | Watching list (1 data point — from 3B.A.1+2+3) |
| 9 | Documentation IS architectural commitment | Watching list (1 data point — from 3B.A.4) |

**Cross-arc observation (NEW codification candidate)**: **"Methodology pattern reusability"** — the audit + Q-decisions + sub-step partition + adversarial 3-column VAG + commit-pair pattern was applied IDENTICALLY across 3B.0 and 3B.A. The two sub-phases differed in CONTENT (measurement vs implementation) but were ARCHITECTURALLY IDENTICAL in process shape. This reusability is the methodology working as designed. 1 data point this arc; watching list candidate.

#### §9.4.5.5 Cross-arc suite stability

- Pre-3B (baseline at 3A close): 8232 / 117.3s / 0 failures (HEAD `02eeebe0`)
- Post-3B.0 (retirement included): 8232 / 117.3s / 0 failures (HEAD `0eaa9506`)
- Post-3B.A (full suite): **8242 / 111.4s / 0 failures** (HEAD `18361413`)
- Net 3B arc delta: **+10 tests / -5.9s wall** (faster than baseline; no regression)
- Targeted throughout: 41/41 → 46/46 GREEN (3B.A adds +5)
- Probe: `cell_allocs=1552` IDENTICAL to baseline throughout
- Acceptance: 0 errors throughout

#### §9.4.5.6 Phase 3B status

**Phase 3B: CLOSED.** All 3 sub-phases closed; all 6 D-3B-* parent drift risks cleared; cross-arc adversarial 3-column VAG passes 4 questions.

#### §9.4.5.7 Handoff to next sub-phases

| Track | Picks up from Phase 3B |
|---|---|
| **Phase 3C** | M0 substrate stable; can reason about both classical mutex nogoods AND non-committing semantic; Form C cross-reference at §9.5.A covers UC1/UC2/UC3 (consumes `tropical-left-residual` from Tropical Quantale Addendum) |
| **Phase 3V** | Final Phase 3 VAG covers 3A + 3B + 3C close. Verifies 3-level termination + parity tests + capstone. |
| **Phase 9b** (parametric trait resolution / γ hole-fill) | Inherits M0 substrate; can pass `#:mutual-exclusion? #f` for non-committing multi-candidate semantic; under fork-and-rejoin mechanism, can re-run Gray-code A/B per §9.4.2.10.4 if motivated |
| **PReduce Track 1** | Inherits M0 substrate; e-class candidate extraction at non-committing |
| **BSP-LE 6 future** (general residual solver) | Inherits M0 substrate; classical-or-non-committing dispatch via flag |
| **Track 4D** (Attribute Grammar Substrate) | M1+M3 deferred scope captured at vision research §5.5; future Stage 1-3 cycle picks up as substrate unification work |
| **Parent Phase 4** (CHAMP retirement) | M0 substrate stable; no coordination required |

#### §9.4.5.8 Codifications graduation status (potential next session work)

Two PROMOTION-READY codifications could graduate to DEVELOPMENT_LESSONS.org in a separate codification-graduation sub-task:

1. **Audit-driven scope refinement** (5 data points across Phase 3A + 3B):
   - R7.a audit refining R7 implementation pattern (3A.c.3)
   - 3A.b lazy `promote-cell-to-tagged` discovery via mempalace search
   - 3A.c.5 migration scope refinement (6 active + 2 preserves)
   - 3B.0 audit surfacing OQ1↔mutual-exclusion tension (4th data point)
   - 3B.A audit surfacing Q2 amb-groups append coupling (5th data point)

2. **Multi-axis parity testing for discriminating coverage** (5 application sites):
   - 2A.c orchestration-parity (3 axes)
   - 3A.c.4 union-inhabitation parity (4 axes; multi-success LOAD-BEARING)
   - 3A.c.5 speculation-bridge substring discriminators (6 migrations)
   - 3B.0 5-workload A/B harness (4 falsification ranges)
   - 3B.A.5 non-committing M0 discriminators (4 axes / 5 cases)

Both warrant DEVELOPMENT_LESSONS.org promotion at user direction.

#### §9.4.5.9 Cross-references

- Phase 3B parent mini-design (§9.4.1; historical M1 framing) — superseded by §9.4.2.9 (M0 selection)
- Phase 3B.0 sub-phase: §9.4.2 (opening) + §9.4.2.7-§9.4.2.8 (audit) + §9.4.2.9 (M0 decision) + §9.4.2.10 (A/B falsification) + §9.4.2.11 (3B.0 close VAG)
- Phase 3B.A sub-phase: §9.4.3 (mini-design) + §9.4.4 (close VAG)
- Phase 3B-VAG (this section): §9.4.5
- Form C cross-reference: §9.5.A (downstream Phase 3C handoff)
- Track 4D deferred scope: vision research §5.5
- Tropical Quantale Addendum §9.7 (UC1/UC2/UC3 anticipated Phase 3C consumers)
- subcube-member? primitive (decision-cell.rkt:372) — primitive-awaiting-consumer
- gray-code-order primitive (relations.rkt:1874) — primitive-awaiting-consumer

### §9.5 Phase 3C deliverables (ORIGINAL TERSE SPEC — superseded by §9.5.1 for implementation planning)

Residuation-based error-explanation for all-branch-contradict:

1. New helper `derivation-chain-for(contradicting-cell, branches, net)` in dedicated module (e.g., `error-explanation.rkt`)
2. Read-time function (not propagator) — walks propagator-firing dependency graph backward from contradicting cell
3. Collects per-step: propagator-id, assumption-id, source-loc (from Phase 1.5 srcloc infrastructure)
4. Output: structured derivation chain + human-readable message
5. Integration: error message output at Phase 3A's all-branch-contradict fall-through
6. Tests (`tests/test-union-error-explanation.rkt`): axis error-provenance-chain per D.3 §9.1 Phase 11b row

Note: Q-A6 (placement of residuation error-explanation — this track or Phase 11b diagnostic) is a Phase 3C mini-design item (§16.3).

#### §9.5.A Form C cross-reference — Tropical Quantale Addendum forward-capture (added 2026-05-17 at Phase 1V close)

Per [Tropical Quantale Addendum §6.5](2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_DESIGN.md) (Form A unit-tested at 1B-iii; Form B UC enumeration at §9.7) + this addendum closes at Phase 1V Commit 8 (2026-05-17): **Phase 3C consumes the tropical residuation operator (`tropical-left-residual`) shipped by Phase 1B + the anticipated Phase 3C UCs enumerated at the addendum's §9.7**:

| UC | Description | Addendum §9.7 reference |
|---|---|---|
| **UC1** | Fuel-exhaustion blame attribution via reverse-walk propagator dependency graph + per-step residuation walk | Tropical Addendum §9.7 UC1 |
| **UC2** | Cost-bounded elaboration via Galois bridge (α: type → cost; γ: budget → elaborable types) | Tropical Addendum §9.7 UC2 |
| **UC3** | Per-branch cost tracking under union-type ATMS branching (Phase 3A); per-branch tropical fuel cell + residuation walk on contradiction | Tropical Addendum §9.7 UC3 |

When Phase 3C implementation opens, the implementer:
1. Picks up `tropical-left-residual` from `racket/prologos/tropical-fuel-primitives.rkt` (exported per F14 cycle-break design; tested at `tests/test-tropical-fuel.rkt` C1+C2+C3 axioms)
2. Implements UC1/UC2/UC3 as proof-of-concept (Form C realization)
3. References the algebraic property declarations at `racket/prologos/tropical-fuel.rkt:99-113` (quantale + residuated + commutative-quantale + integral-quantale + has-pseudo-complement; **empirically validated** at Phase 1V Commit 7 via Track 2I property-sweep — see `data/benchmarks/tropical-fuel-phase9-sweep-2026-05-17.txt`)

This cross-reference closes the addendum's §6.5 Form C capture-gap: the Phase 3C implementer should find this section when opening Phase 3C work, with explicit pointers to the addendum's deliverables.

### §9.5.1 Phase 3C mini-design + mini-audit (2026-05-22 — conversational opening of Phase 3C)

Opening conversational mini-design + mini-audit for Phase 3C per Stage 4 Per-Phase Protocol (mini-design + mini-audit are co-dependent activities cycling between design intent and code reality; outcomes persist to the design doc; dailies log the commit story). Context: post-3B-VAG CLOSED at `d81a04fc`; Phase 3C is the THIRD sub-phase of Phase 3 (after 3A union-types via ATMS + 3B hypercube + M0 substrate fix); first Form C downstream consumer per §9.5.A.

Methodology: **3-column adversarial framing** (catalogue / challenge / adversarial) applied throughout per refinement codified during PPN 4C arc. The third column ACTIVELY tries to demolish each lean rather than softly improve it — catalogue→challenge→adversarial is a three-stage cognitive escalation, NOT a two-stage with intensification.

#### §9.5.1.1 Audit findings — 12-task tier-organized survey

12-task structured audit executed pre-mini-design per Stage 4 mini-audit-precedes-implementation discipline. Tasks A1-A11 + synthesis A12 cover integration surface (Tier 1), substrate consumed (Tier 2), dependency-graph + provenance infrastructure (Tier 3), Phase 11b relationship (Tier 4), tests (Tier 5), and R-lens scope sizing (Tier 6).

**Tier 1 — Integration surface (A1 + A2)**:

- **`process-fork-contradiction`** at `typing-propagators.rkt:1288` reads accumulated `aid-set` from cell-16 (set-union merge), computes `contradicted-bits` mask, atomically narrows `worldview-cache-cell-id` via `(bitwise-and current-wv (bitwise-not contradicted-bits))`. Idempotent. The handler does NOT emit user-facing error itself (its purpose is structural narrowing).
- **Cell-16 writers**: `make-branch-contradiction-watcher-fire-fn` at typing-propagators.rkt:1248 (writes `(seteq aid)`); wrapped at branch worldview via `wrap-with-worldview`.
- **Existing error infrastructure** (typing-errors.rkt:64-118 + errors.rkt:115-116): `union-exhaustion-error` struct ALREADY EXISTS with `branches + branch-mismatches + expr-str + derivation-chain` fields. `build-derivation-chain` (typing-errors.rkt:127) walks ATMS support sets + `speculation-failure-sub-failures` from `get-latest-speculation-failure`. The struct surface is rich; the chain field is the gap.

**Tier 2 — Substrate consumed (A3 + A4 + A8)**:

- **`tropical-left-residual`** at `tropical-fuel-primitives.rkt:105` (leaf module). Exported. C1+C2+C3 axioms tested at `tests/test-tropical-fuel.rkt:108-247`. Adjunction law verified. ZERO current production consumers — Phase 3C is the first.
- **Phase 1.5 srcloc infrastructure** fully in place: `propagator` struct `srcloc` field (propagator.rkt:354); `current-source-loc` parameter (source-location.rkt:36); `fire-propagator` wrapper (propagator.rkt:363) parameterizes srcloc per-fire; 21 production install sites with explicit `#:srcloc` kwarg.
- **§9.7 UC1/UC2/UC3 specs** (from Tropical Quantale Addendum):
  - **UC1**: Fuel-exhaustion blame attribution via dep-graph reverse walk + per-step residuation
  - **UC2**: Cost-bounded elaboration via Galois bridge (α: type→cost; γ: budget→elaborable types)
  - **UC3**: Per-branch cost tracking under union-type ATMS branching

**Tier 3 — Dependency graph + provenance infrastructure (A5 + A6 + A7)**:

| Structure | Direction | Cost |
|---|---|---|
| `prop-cell.dependents` (champ) | Forward: cell → propagators waiting | Always-on, on-network |
| `propagator.outputs` (list) | Reverse derivable: scan all propagators by `(member cid outputs)` | O(N) scan, on-network |
| `cell-diff.source-propagator` (prop-id) | Dynamic: prop-id that caused each diff | Only when observer set |
| `prop-network-contradiction-fns` (champ cell-id → contradiction-fn) | Static reactive | Always-on |
| `prop-trace.rounds` (`bsp-round` list) | Dynamic firing history | Only when observer set |

`current-bsp-observer` defaults `#f` (zero cost in production); production setters are `prop-observatory.rkt` + `tools/measure-production-n.rkt`. **Static reverse walk over `propagator.outputs` is feasible without observer set** — preserves Cell/Propagator/Scheduler Orthogonality.

ATMS assumption tagging: `assumption-id` struct = `(struct assumption-id (n))`; `solver-state-assumptions` returns `aid → assumption` with `name` + `datum` metadata; `tagged-cell-value.entries = (listof (cons bitmask value))` carries per-write aid bitmasks. **The chain can decode aid → human-readable label from on-network state.**

**Tier 4 — Phase 11b relationship (A9)**:

Phase 11b (parent D.3 §6.1.1 + Phase 11b tracker row): `derivation-chain-for(position, tag)` as READ-TIME function over propagator-firing dep graph. Three structural sources: ATMS assumption tagging + `:trace :structural` mode + source-location registry. M4 external-critique lean: read-time derivation (option b). Research input: trace monoidal category theory. **Phase 11b is sequenced AFTER addendum's Phase 2 (DONE) → technically unblocked.** Phase 11b is PARENT-track scope, broader than union-type contradict.

**Tier 5 — Tests / parity skeletons (A10)**:

`test-elaboration-parity.rkt:535` has skip-gated `'error-provenance-chain` for "Phase 11b" — scenario `[int+ "a" 3]` (non-union type-mismatch). Phase 3C's natural axis is NEW: `'union-all-contradict-error` per §9.8 lines 2886-2887.

**Tier 6 — R-lens scope sizing (A11)**:

- 1336 production refs to error structs / `prologos-error?` / `net-contradiction`
- 21 propagator install sites with explicit `#:srcloc`
- 41 `(current-source-loc)` references
- 16 error struct types in `errors.rkt`
- 1 current producer of `union-exhaustion-error` (typing-errors.rkt:98; sexp path only)
- 2 active observer sites in production (observer-off is production default)

#### §9.5.1.2 Q6.x empirical probe finding — architectural reframe

During dialogue, original A2 audit identified that `process-fork-contradiction` does ONLY narrowing — concluded "no user-facing error surface for on-network union all-branch-contradict." This raised Q6.x: what CURRENTLY happens to elaboration output when worldview-cache narrows under Phase 3A's mechanism?

**Empirical probe** at `racket/prologos/examples/2026-05-22-3C-Q6x-probe.prologos` (3 scenarios: `def x <Nat | Bool> "hello"` + `def y <Int | Bool> "world"` + `def z <<Nat | Bool> | String> 3.14`) run via `process-file` with `current-emit-error-diagnostics` enabled.

**Findings**:

| Counter | Value | Meaning |
|---|---|---|
| `prop_allocs` | **0** | **Phase 3A's on-network mechanism did NOT fire** for these annotated-union scenarios |
| `prop_firings` | **0** | No propagators fired |
| `propagators` | **0** | No propagators installed |
| `speculation_count` | 11 | sexp `with-speculative-rollback` fired |
| `atms_hypothesis_count` | 14 | ATMS active in sexp path |
| `atms_nogood_count` | 11 | nogoods recorded |
| `provenance_chain_count` | **0** | **`build-derivation-chain` produced ZERO chains** |

**User-facing output (already rich)**:
```
error[E1006]: expression does not match any branch of union type
  tried Nat — type mismatch (got: String)
  tried Bool — type mismatch (got: String)
  in expression: "hello"
  = help: expression must match at least one branch of Nat | Bool
```

**Returned `union-exhaustion-error` struct shows `derivation-chain = '(() ())`** — field exists but EMPTY per-branch.

**Architectural reframe**:

Two distinct union-error paths exist:

| Scenario | Path | User-facing today | Chain today |
|---|---|---|---|
| Annotated union (`def x : <T1\|T2> := e`) | sexp `check/err` + `with-speculative-rollback` | ✓ `union-exhaustion-error` rich | ❌ EMPTY |
| Inferred union (on-network type-map-write detects union classifier) | Phase 3A `process-fork-on-union` → narrowing | ⚠️ unknown for user-facing scenarios; Phase 3A mechanism doesn't fire for annotated cases | ⚠️ no chain mechanism wired |

**Phase 3C value proposition — REFRAMED**:
- NOT "establish user-facing error surface for on-network union all-branch-contradict" (sexp does that already for annotated case)
- IS "populate the EMPTY `derivation-chain` field on `union-exhaustion-error` with rich on-network walk data for BOTH paths (annotated + inferred)"
- The chain mechanism becomes AUTHORITATIVE; sexp `build-derivation-chain` retires for union cases; non-union cases continue using `build-derivation-chain` until Phase 11b extends.

#### §9.5.1.3 Vision-forward framing — Propagator-First Diagnostics

User-articulated framing (2026-05-22 dialogue): on-network error reporting via propagator-network provenance is a primary value proposition of propagator-based compilers ("Logos Hyperlattice Compiler" / LHC vision). Phase 3C is the FIRST user-facing instance of this; subsequent tracks consume the same architectural shape:

| Downstream consumer | What it consumes from Phase 3C |
|---|---|
| **Phase 11b** (parent D.3) | `static-reverse-walk` primitive + `derivation-chain` struct; extends with non-union diagnostics + LSP hooks |
| **PPN Track 8** (LSP integration) | `derivation-chain` struct (transparent + serializable) → LSP diagnostic payload via `format-error` |
| **SH Series Track 1** (`.pnet` network-as-value) | `derivation-chain` shape becomes part of `.pnet` IR; cross-session error reporting |
| **SH Series Track 4** (production LLVM substrate / LHC) | `static-reverse-walk` is the runtime diagnostic primitive; chain struct becomes part of LHC ABI |
| **PReduce Track 6** (speculative reduction) | Emission pattern (stratum handler integration) for cost-bounded ATMS branching errors |

**Sexp-as-IR retirement target** (multi-track, multi-quarter): coordinated across PM Track 12 (parameters → cells) + PPN Track 4D (Attribute Grammar Substrate Unification) + downstream tracks. Phase 3C contributes by making on-network chain the AUTHORITATIVE diagnostic for union cases; sexp `build-derivation-chain`'s union-type path retires in Phase 3C; non-union paths retire later as on-network typing coverage expands.

**Adversarial check on framing — is this vision-forward or speculative?**

| Catalogue | Challenge | Adversarial |
|---|---|---|
| Multi-track consumers named in active design; Hyperlattice Conjecture supports compiler-IS-network; Specialized Cell Type Framework precedent for vision-forward design | Could "vision-aligned" be MORE specific? Are consumers TRULY going to consume same shape, or am I assuming alignment? | Specialized Cell Type Framework was codified AS Cross-Track Template AFTER 3 empirical instances landed IN-ARC. Phase 3C has ONE consumer; Phase 11b not designed; PPN 8 / SH Track 4 years out. **Pre-codification as Cross-Track Template VIOLATES empirical-precedent discipline.** Synthesis: ship vision-forward API surface NOW (exported `static-reverse-walk` primitive; transparent structs); codification as Cross-Track Template GRADUATES at Phase 11b second consumer. Middle path. |

**Outcome**: vision-forward IS warranted; pre-codification as Cross-Track Template is NOT. Codification lives at watching-list until empirical second instance.

#### §9.5.1.4 Resolved design questions (Q1-Q10)

| Q | Question | LOCKED Lean | Rationale |
|---|---|---|---|
| **Q1 (= Q-A6)** | Phase 3C placement: ship all UC1/UC2/UC3 OR defer to Phase 11b OR share | **(c)-refinement** — Phase 3C ships UC3-flavored union-type consumer + reusable static-walk primitives (exported per vision-forward framing); Phase 11b extends with non-union diagnostics + LSP hooks | (a) UC1/UC2 scope creep; UC1 requires DYNAMIC trace (observer-coupling violation) OR new on-network cumulative-cost cell (workflow.md "build for future use"); UC2 has zero current consumer. (b) addendum charter unmet; silent UX regression. (d) §9.5 deliverable (1) "new module" missing. (c) preserves Completeness + Decomplection + Most Generalizable Interface. |
| **Q2** | `derivation-chain-for` API signature | `(derivation-chain-for/union-contradict net aid-set request-info)` + sibling `(derivation-chain-for/union-check net branches-info expr)` (post-Q6.x extension) | request-info carries position + tm-cid + components (the union-decomposition context); cleaner than packing into assumption-datum (which would be orthogonality violation: assumption ↔ branch identity ≠ type structure). |
| **Q3** | Walk mechanism STATIC vs DYNAMIC | **STATIC** — reads `propagator.outputs`, `propagator.srcloc`, `tagged-cell-value.entries`, `solver-state-assumptions`; NO `current-bsp-observer` activation | Observer-set is scheduler coupling (Orthogonality violation per `6a628bc7`). Static walk gives STRUCTURAL chain ("these N propagators participate"); for union-type error messages structural is sufficient. UC1 fuel-blame WOULD need dynamic info → reinforces UC1 deferral. |
| **Q4** | Per-branch fuel cells | **NO per-branch fuel cells** — UC3 reframes to "per-step cost annotation via `tropical-left-residual` against canonical fuel-cost-cell at chain-build time" | §9.7 UC3 spec written before Phase 3A's mechanism settled; "per-branch fuel cell" assumes fork-and-rejoin or budget-bounded branches. Phase 3A's Realization B uses subtype-check, not fuel-exhaustion. Adding per-branch fuel cells = shape-without-benefit (workflow.md). Honest Form B → Form C reframe documented. |
| **Q5** | Module location + dependencies | `racket/prologos/error-explanation.rkt` as leaf-ish module; depends on errors + atms + propagator + tropical-fuel-primitives + source-location | Symmetric with `tropical-fuel-primitives.rkt` + `tropical-fuel.rkt` Phase 1 two-layer pattern. No cycles (typing-propagators.rkt requires error-explanation; error-explanation depends only on leaves). |
| **Q6** | Integration hook (post-Q6.x) | **(γ) BOTH integration points sharing static-walk primitive** — `process-fork-contradiction` for inferred unions + `check/err` for annotated unions; one chain mechanism, two callers | Q6.x revealed annotated cases dominate user-facing scenarios and go through sexp `check/err`. Wiring only to `process-fork-contradiction` (α) would deliver infrastructure that doesn't fire for the dominant user case (Validated ≠ Deployed). |
| **Q7** | UC1 scope | **DEFERRED** to OE Track 4 + Phase 11b cooperative scope | Q3's STATIC lean confirms structural chain insufficient for cost-share attribution. UC1 requires cumulative-cost infrastructure that's not in Phase 1's substrate. Building it now = workflow.md anti-pattern. |
| **Q8** | LSP integration hooks | Ship transparent `(struct derivation-chain (steps))` + `(struct derivation-step ...)` — struct shape IS LSP-ready data; LSP wiring deferred to PPN Track 8 | `format-error` already handles structured records; transparency means LSP can serialize directly. Forward-compat preserved (field additions allowed; field-semantics changes treated as breaking). |
| **Q9** | Unification with sexp chain | **REPLACE** empty chain in `union-exhaustion-error.derivation-chain` for union cases — Phase 3C is the authoritative source for union chain; sexp `build-derivation-chain` retires for union-type cases; non-union cases continue using sexp `build-derivation-chain` until Phase 11b extends | Q6.x revealed sexp chain is EMPTY today for union cases (no dual-mechanism actually exists in production). Replacement is honest (we're not preserving sexp's chain; we're filling an empty field). |
| **Q10** | Parity axis name + scope | **`'union-all-contradict-error` with 4-axis discriminating coverage**: `/chain-shape` (non-empty + expected step count) + `/branch-attribution` (each branch's chain references its assumption-name) + `/srcloc-presence` (≥1 step has non-#f srcloc) + `/non-union-no-chain` (negative: chain ABSENT under sexp non-union error). Existing skip-gated `'error-provenance-chain` stays Phase 11b. | Multi-axis discriminating per PROMOTION-READY codification (5 sites precedent). Negative axis (no-chain-under-non-union) DISCRIMINATES against accidentally-running 3C's mechanism for non-union errors. |

**Vision-forward API exports** (per §9.5.1.3 framing — exported per first-class-by-default discipline; codification at watching-list):

```racket
;; === Core data types ===
(struct derivation-chain (steps) #:transparent)
(struct derivation-step
  (propagator-id srcloc assumption-id assumption-name residual-cost-or-#f)
  #:transparent)

;; === Static walk primitive (load-bearing for Phase 11b + LSP + LHC) ===
(provide static-reverse-walk)

;; === Phase 3C-specific consumers ===
(provide derivation-chain-for/union-contradict)
(provide derivation-chain-for/union-check)

;; === Formatting (consumed by errors.rkt format-error) ===
(provide format-derivation-chain)
```

#### §9.5.1.5 Sub-phase partition

| Sub-phase | Description | Est. LoC | Key gate |
|---|---|---|---|
| **3C.a** | Foundation — `error-explanation.rkt` module + structs + `static-reverse-walk` primitive + primitive tests | ~150-200 | Static walk produces correct (propagator-id, srcloc, assumption-id) triples for synthetic dep-graph |
| **3C.b** | Union-contradict consumer (on-network path) — `derivation-chain-for/union-contradict` + integration in `process-fork-contradiction`; tests for inferred-union scenarios | ~80-150 | Inferred-union all-branch-contradict scenarios populate `union-exhaustion-error.derivation-chain` |
| **3C.c** | Union-check consumer (sexp-bridge path) — `derivation-chain-for/union-check` + integration in `check/err` (typing-errors.rkt:64); replace empty-chain construction for union cases | ~80-150 | Annotated-union scenarios (probe baseline) populate same chain field with same struct shape |
| **3C.d** | Format integration + 4-axis discriminating parity tests + Q6.x probe diff verification | ~100-150 | `'union-all-contradict-error/*` axes pass; probe diff shows chain populated; suite stable |
| **3C-VAG** | Cross-arc adversarial 3-column VAG; Phase 3C close | docs | All 4 VAG questions pass under adversarial framing |

Estimated total: **~430-700 LoC** + docs across 4 sub-phases + 1 VAG close.

#### §9.5.1.6 Drift risks named (per Stage 4 mini-design discipline)

13 drift risks named at mini-design open; D-3C-10 CLEARED pre-implementation by Q6.x empirical probe.

| # | Risk | Mitigation |
|---|---|---|
| **D-3C-1** | shape-without-benefit — ship API but chain doesn't actually improve diagnostic value vs current empty-chain output | Pre-write 1-2 expected user-facing error messages BEFORE implementation; verify improvement empirically |
| **D-3C-2** | observer-coupling — tempted to set `current-bsp-observer` for richer trace → Cell/Propagator/Scheduler Orthogonality violation | Q3 lean LOCKS static walk only; observer-set is anti-pattern for production-default 3C |
| **D-3C-3** | dual-path-permanence — reframed by Q6.x: sexp's chain was empty, so 3C REPLACES (not supplements); see D-3C-11 for the residual concern | Q9 lean LOCKS replacement for union cases; non-union sexp chain continues until Phase 11b |
| **D-3C-4** | uc1-scope-creep — tempted to ship UC1 fuel-blame since `tropical-left-residual` is right there | Q7 lean LOCKS UC1 deferral; 3C charter is union all-branch-contradict only |
| **D-3C-5** | residuation-walk-formal-gap — trace monoidal category theory research named in §6.1.1 as Phase 11b input; 3C might land before consulting | Mini-design at sub-phase open: CONSULT IF 3C scope expands toward UC1/UC2; SKIP if scope stays union-only |
| **D-3C-6** | error-emission-double-firing — if integration hook is both `process-fork-contradiction` augmentation AND downstream "worldview=0" detection, duplicate errors | Idempotence guard at emission point; one emission per all-branch-contradict event; verify via parity tests |
| **D-3C-7** | srcloc-coverage-gap — only 21 sites with explicit `#:srcloc`; chain steps may have `srcloc=#f` for non-explicit installs | Audit during 3C.a implementation: do chain-relevant propagators have srcloc? If not, document graceful degradation (chain shows "<unknown>" for those steps) |
| **D-3C-8** | bit-budget — Phase 3A's ≤30-bit assumption-id bitmask; large unions could exceed | Inherited from Phase 3A; observe via PERF-COUNTERS heartbeats; 3C is not responsible to fix |
| **D-3C-9** | test-discriminating-power — parity tests must DISCRIMINATE (would fail if chain mechanism broken), not just preserve | Q10 lean LOCKS 4-axis with negative axis ('non-union-no-chain) for discrimination |
| **D-3C-10** | Q6.x unknown-fallback — what currently happens with elaboration output | **CLEARED 2026-05-22** by empirical probe; see §9.5.1.2 |
| **D-3C-11** | form-B-reframing-honesty — UC3 §9.7 spec ("per-branch tropical fuel cell") doesn't match Phase 3A's actual mechanism | Q4 lean documents explicit Form B → Form C reframe; persistence captures the reframe (this subsection) |
| **D-3C-12** | build-derivation-chain-co-existence — Phase 3C populates union-type chain; `build-derivation-chain` still populates `type-mismatch-error` (non-union) chain. If `build-derivation-chain` is later extended to cover union cases in parallel, drift returns | Audit during 3C.c: ensure `build-derivation-chain`'s union-type code paths (typing-errors.rkt lines 70-104) are RETIRED for union cases (replaced by Phase 3C); non-union paths remain until Phase 11b |
| **D-3C-13** | vision-aligned-overreach — pre-codifying `static-reverse-walk` as Cross-Track Template before empirical second consumer = workflow.md anti-pattern | Lean LOCKS: ship API surface NOW; codification GRADUATES at Phase 11b second instance. Watching-list entry "Propagator-First Diagnostics" captures the candidate. |

#### §9.5.1.7 Cross-track captures (forward-pointers)

Per vision-forward framing (§9.5.1.3), Phase 3C deliverables are foundational for downstream tracks. Cross-track captures persist as forward-pointer notes; concrete updates to other tracker docs land during the implementation arc opportunistically OR as separate commits.

**Forward-pointer notes**:

1. **Phase 11b (parent D.3 §6.1.1 + tracker row)**: extends Phase 3C's `static-reverse-walk` primitive + `derivation-chain` struct; general `derivation-chain-for(position, tag)` becomes second consumer of the primitive (not a refactor); covers non-union diagnostics + LSP hooks + trace-monoidal-category-theory framing per M4 critique.

2. **SH Master (Track 1: `.pnet` network-as-value + Track 4: production LLVM substrate / LHC)**: chain struct shape becomes part of `.pnet` IR for cross-session error reporting; `static-reverse-walk` is the runtime diagnostic primitive at LHC ABI; LLVM lowering interprets transparent struct fields directly.

3. **PPN Track 8 (LSP integration)**: `derivation-chain` is LSP-serializable via transparent struct + `format-error` integration; LSP diagnostic payload IS the chain output; PPN 8 consumes Phase 3C delivery directly.

4. **PReduce Track 6 (speculative reduction)**: inherits emission pattern (stratum handler → chain emission); cost-bounded ATMS branching errors produce chains via residual walk through cost-attribution graph.

5. **PM Track 12 + PPN Track 4D (sexp-as-IR retirement multi-track arc)**: Phase 3C contributes by making on-network chain the AUTHORITATIVE diagnostic for union cases; sexp `build-derivation-chain` union-type path retires in 3C.c; non-union paths retire in Phase 11b + Track 4D arc.

6. **DEFERRED.md**: capture "Sexp-as-IR retirement" multi-track target with dependency chain (PM 12 + on-network mechanism coverage + LHC self-hosting).

7. **MASTER_ROADMAP.org**: surface "Propagator-First Diagnostics" framing in PPN 4C row description when next opportunity to edit; reference §9.5.1 as the canonical articulation.

**Codification status (watching list, 1 data point — graduates at Phase 11b second consumer)**:

> **"Propagator-First Diagnostics"** — error reporting via on-network static-walk over propagator-firing graph is a load-bearing architectural shape for compiler-IS-network (LHC). Phase 3C ships `static-reverse-walk` + `derivation-chain` struct as the first instance; Phase 11b + PPN 8 LSP + SH Track 4 LHC are named downstream consumers. Codification GRADUATES from watching list to principle (DESIGN_PRINCIPLES.org § Propagator-First Diagnostics) when Phase 11b lands the second empirical consumer — mirrors Specialized Cell Type Framework graduation precedent (codified AFTER 3 empirical cache instances landed IN-ARC).

#### §9.5.1.8 Methodology notes — audit-driven scope refinement (6th data point) + Q6.x empirical falsification

**Audit-driven scope refinement** (PROMOTION-READY codification, 5 data points previously; this dialogue adds the 6th):
- Q6.x's empirical probe REFRAMED Phase 3C's value proposition from "establish silent-failure-fix" to "populate empty-chain field" — a non-trivial scope shift driven by audit-precedes-implementation discipline
- Without the probe, Phase 3C might have implemented chain mechanism that doesn't fire for the dominant user scenario (annotated unions go through sexp path; on-network Phase 3A mechanism handles inferred unions only)
- This is the 6th data point reinforcing the codification

**Empirical falsification of audit assumption**:
- A2 audit concluded "no user-facing error surface for on-network union all-branch-contradict"
- Empirical probe REVEALED the actual current state: rich user-facing error via sexp path with EMPTY chain field
- The audit was CORRECT about Phase 3A's on-network mechanism (it does only narrowing) but MISSED the driver-fallback layer that produces the user-facing error
- **Methodology lesson**: even tier-organized audits can miss multi-layer interactions; empirical probe is the falsification step when audit conclusions are LOAD-BEARING for design decisions

**Sub-codification (1 data point, watching list)**: "Audit-precedes-implementation discipline requires EMPIRICAL falsification step when audit conclusions drive load-bearing design decisions. Multi-layer interactions are the audit blind spot — pre-implementation probes verify the audit's behavioral assumptions."

#### §9.5.1.9 Closure criteria

Phase 3C closes per Stage 4 Per-Phase Protocol + cross-arc VAG:

1. **Sub-phases 3C.a through 3C.d delivered** with each Stage 4 step completed in order (test coverage → commit → tracker → dailies → proceed)
2. **`union-exhaustion-error.derivation-chain` field POPULATED** for both annotated-union and inferred-union scenarios with rich on-network walk data
3. **4-axis discriminating parity tests passing** (`'union-all-contradict-error/chain-shape` + `/branch-attribution` + `/srcloc-presence` + `/non-union-no-chain`)
4. **Probe diff verification**: post-3C run of `examples/2026-05-22-3C-Q6x-probe.prologos` shows non-empty derivation-chains; pre-3C baseline (this commit) shows empty
5. **`build-derivation-chain` union-type code path retired** (typing-errors.rkt:70-104 for union cases; non-union path continues until Phase 11b)
6. **All 13 D-3C-* drift risks cleared** (D-3C-10 already CLEARED by Q6.x probe; remaining 12 verified at 3C-VAG)
7. **Full suite stable** within 109-115s baseline variance band (current baseline 111.4s)
8. **Adversarial 3-column VAG** passes 4 questions (on-network / complete / vision-advancing / drift-risks-cleared) at Phase 3C close
9. **Cross-track captures persisted** in §9.5.1.7 (this section) + opportunistically updated in other tracker docs

#### §9.5.1.10 Status

**Phase 3C mini-design + mini-audit: ✅ PERSISTED** (this commit). Ready to enter Phase 3C.a (Stage 4 implementation) following the conversational checkpoint cadence per workflow.md.

#### §9.5.1.11 Cross-references

- Phase 3B-VAG close (preceding state): §9.4.5 (commit `d81a04fc`)
- Form C cross-reference (Phase 3C handoff target): §9.5.A
- Tropical Quantale Addendum UC1/UC2/UC3: `2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_DESIGN.md` §9.7
- Parent D.3 §6.1.1 (provenance infrastructure): `2026-04-17_PPN_TRACK4C_DESIGN.md` §6.1.1
- Parent D.3 Phase 11b tracker row: `2026-04-17_PPN_TRACK4C_DESIGN.md` Progress Tracker Phase 11b
- Q6.x empirical probe: `racket/prologos/examples/2026-05-22-3C-Q6x-probe.prologos`
- Existing union-error infrastructure: `racket/prologos/errors.rkt:115-116` (`union-exhaustion-error` struct) + `racket/prologos/typing-errors.rkt:64-152` (sexp `check/err` + `build-derivation-chain`)
- Phase 3A integration target: `racket/prologos/typing-propagators.rkt:1288` (`process-fork-contradiction`)
- Phase 3A request shape: `racket/prologos/typing-propagators.rkt:1108-1115` (cell-15 request-info hash structure)
- Tropical residuation operator: `racket/prologos/tropical-fuel-primitives.rkt:105`
- Phase 1.5 srcloc plumbing: `racket/prologos/propagator.rkt:354` (propagator struct) + `:363` (fire-propagator wrapper) + `racket/prologos/source-location.rkt:36` (current-source-loc parameter)
- Codification graduation precedent (Specialized Cell Type Framework): `docs/tracking/principles/DESIGN_PRINCIPLES.org` § "Specialized Cell Type Framework as Cross-Track Template"

### §9.5.2 Phase 3C.a mini-design + mini-audit (2026-05-22 — opening 3C.a foundation)

Opening conversational mini-design + mini-audit for Phase 3C.a (foundation sub-phase per §9.5.1.5) per Stage 4 Per-Phase Protocol (mini-audit-precedes-implementation). 3C.a delivers the `error-explanation.rkt` module foundation: `derivation-chain` + `derivation-step` structs + `static-reverse-walk` primitive + primitive tests. Sub-phases 3C.b/c/d consume this foundation.

#### §9.5.2.1 Mini-audit findings (API surface verified)

| Item | Status | Detail |
|---|---|---|
| `error-explanation.rkt` exists? | ❌ NO | Clean ground to build on |
| Champ iteration | ✅ | `champ-fold (k v acc → acc) init` at champ.rkt:365; iterates all propagators in O(N) |
| Propagator accessors | ✅ | `(struct propagator (inputs outputs fire-fn broadcast-profile flags srcloc) #:transparent)` at propagator.rkt:354; auto-generated `propagator-inputs/-outputs/-srcloc` confirmed in use |
| `tagged-cell-value` | ✅ | `(struct tagged-cell-value (base entries) #:transparent)` at decision-cell.rkt:397; entries = `(listof (cons bitmask value))` |
| Raw cell read | ✅ | `net-cell-read-raw` provided at propagator.rkt:251, defined at :1506 (bypasses worldview filter) |
| `net-add-propagator` | ✅ | `(net input-ids output-ids fire-fn ... #:srcloc srcloc-or-#f)` at propagator.rkt:2120 |
| Network constructor | ✅ | `(make-prop-network [fuel])` at propagator.rkt:892 |
| `assumption-id` | ✅ | `(struct assumption-id (n) #:transparent)` at atms.rkt:108 |
| Test convention | ✅ | rackunit `test-case` + synthetic struct construction (test-trace-data.rkt + test-propagator.rkt precedents) |

#### §9.5.2.2 Resolved design questions (Q-A.1 through Q-A.7) — locked via 3-column adversarial

| Q | LOCKED Lean | Adversarial rationale |
|---|---|---|
| **Q-A.1** Signature | `(static-reverse-walk net cell-id #:max-depth 32 #:filter-fn pred) → derivation-chain` | `(step → bool)` predicate is GENERAL; consumer closes over aid-set when needed; further generalization is speculative pre-export |
| **Q-A.2** Step field shape | 5 fields: `propagator-id` + `srcloc` + `assumption-ids` + `assumption-names` + `residual-cost` (all transparent) | input/output cell-ids NOT stored — derivable from prop-id via champ-lookup; minimal shape lowers coupling risk under Phase 11b extension |
| **Q-A.3** Walk semantics | SINGLE-LAYER decorated walk — primitive does graph walk + step decoration in one pass | Two-layer creates two API surfaces consumers must compose; single layer with filter-fn gives customization without exposing stages; refactor IF empirical need surfaces (Phase 11b) |
| **Q-A.4** Cycle + depth bound | BOTH — visited-set of prop-ids + `#:max-depth 32` (matches Phase 3A's 30-bit budget envelope, +2 headroom) | Unbounded-with-cycle-detection walks pathological chains; 32 is generous + natural envelope; non-coupling to specific Phase 3A cap |
| **Q-A.5** Step ordering | Depth-first pre-order accumulator via cons-onto-head; result natural-order = causal-reading (deepest cause first) | Cons-onto-head DFS naturally gives deepest-first-at-list-head; reading order = root cause first → symptom last; deterministic given champ-fold stability per-run |
| **Q-A.6** Aid attribution | Per-step records aids from `tagged-cell-value.entries` UNION at the OUTPUT cell (the cell the walk is at); documented as "aids the cell was tagged with at walk time" — not "aids THIS propagator wrote under" | Cell value structure doesn't preserve per-propagator-write aid attribution; the imprecision is acceptable for diagnostic chains; documented honestly |
| **Q-A.7** Sub-step partition | SINGLE atomic 3C.a commit (module + structs + primitive + tests) | Tight coupling between structs + primitive + tests; ~150-200 LoC fits one commit; sub-split adds commit overhead without bisect benefit |

**Decomplection clarification (added during dialogue)**: primitive's `assumption-names` set to `'()` always; `residual-cost` set to `#f` always. Phase 3C.b/c consumers ENRICH steps with names (via `solver-state-assumptions` lookup) and residual-cost (via tropical-quantale annotation). Primitive is GRAPH-WALK-ONLY; tropical-quantale-specific decoration lives in the per-consumer wrapper.

#### §9.5.2.3 Test plan (8 cases per §9.5.1.5 key gate)

| Test | Scenario | Asserts |
|---|---|---|
| T1 | Single propagator P outputs to target cell | chain has 1 step; step.propagator-id = P's pid; step.srcloc matches install srcloc; empty aids |
| T2 | Linear chain: P1 outputs to A; P2 reads A, outputs to B | walk from B → 2 steps; head is P1 (deepest), tail is P2 (symptom) |
| T3 | Multi-writer: P1, P2 both output to A | walk from A → 2 steps; set-equality assertion (champ-fold order non-deterministic across runs) |
| T4 | Cycle: P1 ↔ P2 via shared cells | cycle detection halts; walk completes without infinite loop |
| T5 | Depth bound: chain of 5 propagators with `#:max-depth 3` | walk truncates at depth 3; chain shorter than 5 |
| T6 | filter-fn excludes one prop-id | chain excludes filtered step |
| T7 | Propagator without explicit `#:srcloc` | step.srcloc = #f (graceful degradation) |
| T8 | Cell with synthetic `(tagged-cell-value 'base (list (cons #b011 'val)))` | step.assumption-ids = `(list (assumption-id 0) (assumption-id 1))` |

#### §9.5.2.4 Drift risks named (D-3C.a-*)

| # | Risk | Mitigation |
|---|---|---|
| **D-3C.a-1** | Cell→writers reverse-index O(N) per call | Error paths are rare; O(N) acceptable; cache later if profiling shows hotspot |
| **D-3C.a-2** | `champ-fold` traversal non-determinism → chain step order varies across runs at multi-writer cells | Tests assert SET equality where order doesn't matter; sequential traversal stable within a single run |
| **D-3C.a-3** | Bit-position → assumption-id decoding requires per-command scope | Phase 3A's ATMS is per-command; aids valid during walk; verify at impl |
| **D-3C.a-4** | `net-cell-read-raw` vs filtered read — primitive needs RAW | Lock RAW read in primitive; document at API signature |
| **D-3C.a-5** | `prop-id-hash` consistency with install-time hash | Verify at impl (use `champ-lookup` with `prop-id-hash`) |

#### §9.5.2.5 Implementation deliverables

1. NEW `racket/prologos/error-explanation.rkt` (~180 LoC est.):
   - `(struct derivation-chain (steps) #:transparent)`
   - `(struct derivation-step (propagator-id srcloc assumption-ids assumption-names residual-cost) #:transparent)`
   - `(static-reverse-walk net cell-id #:max-depth #:filter-fn) → derivation-chain`
   - Internal helpers: `build-reverse-index`, `decode-step`, `decode-aids-from-entries`
2. NEW `racket/prologos/tests/test-error-explanation.rkt` (~150 LoC est.):
   - 8 test cases T1-T8
   - Synthetic dep-graph construction via `make-prop-network` + `net-new-cell` + `net-add-propagator`

#### §9.5.2.6 Closure criteria

1. `error-explanation.rkt` compiles cleanly via `raco make`
2. All 8 test cases pass via `raco test tests/test-error-explanation.rkt`
3. Targeted suite includes `test-error-explanation.rkt` GREEN; no regressions
4. Full suite stable within 109-115s variance band
5. All 5 D-3C.a-* drift risks cleared at implementation close
6. §3 Progress Tracker updated with `3C.a` row + commit hash
7. Dailies session entry persisted

#### §9.5.2.7 Status

**Phase 3C.a mini-design + mini-audit: ✅ PERSISTED** (this commit). Ready to proceed to implementation per Stage 4 Per-Phase Protocol step 7 (phase completion 5-step checklist).

### §9.5.3 Phase 3C.b mini-design + mini-audit (2026-05-23 — opening union-contradict consumer)

Opening conversational mini-design + mini-audit for Phase 3C.b per Stage 4 Per-Phase Protocol (mini-design + mini-audit are co-dependent activities cycling between design intent and code reality; outcomes persist to the design doc; dailies log the commit story). Context: post-3C.a CLOSED at `1d803ed2` (error-explanation.rkt foundation + 9 tests + decomplection invariants preserved). 3C.b consumes 3C.a's foundation to populate `union-exhaustion-error.derivation-chain` for INFERRED-union scenarios (where Phase 3A's on-network `process-fork-contradiction` mechanism fires).

Methodology: **3-column adversarial framing** applied throughout (catalogue / challenge / adversarial). User-articulated coupling intuition during dialogue surfaced a meaningful architectural refinement (option (c) → option (d); see §9.5.3.3) — empirical confirmation that the third column ACTIVELY DEMOLISHES rather than softly improves.

#### §9.5.3.1 Mini-audit findings (7 tiers, grounded in code)

7-tier structured audit executed pre-mini-design per Stage 4 mini-audit-precedes-implementation discipline. Findings cross-reference §9.5.1.1's parent audit; this audit drills into 3C.b-specific surfaces.

**Tier 1 — 3C.a foundation (consumed by 3C.b)**:
- `error-explanation.rkt` (211 LoC) — `derivation-chain` + `derivation-step` (5 fields) + `static-reverse-walk net cell-id #:max-depth #:filter-fn → derivation-chain` primitive. Decomplection invariant verified: primitive ALWAYS sets `assumption-names='()` + `residual-cost=#f` (line 144 `decode-step`); consumer wrappers enrich. Filter applies BEFORE recursion (line 204; T6 test confirms).

**Tier 2 — Integration point (process-fork-contradiction, cells 15/16/17)**:
- Cell-id constants verified at `propagator.rkt`: worldview-cache=1; classify-inhabit-request=10; fuel-budget=12; fork-on-union-request=15; fork-contradiction-request=16; decomposed-positions=17.
- cell-15 request shape (typing-propagators.rkt:615 R7 emit): `(hasheq 'components (listof TypeExpr) 'tm-cid CellId)`.
- `process-fork-contradiction` body (typing-propagators.rkt:1288-1303) is SINGLE-CONCERN (worldview narrowing only). Handler does NOT know originally-allocated per-position branch-mask — material design gap for Q-B.1.i detection.
- Idempotence already preserved via `(= current-wv narrowed-wv)` check (line 1301-1302).

**Tier 3 — ATMS substrate (aid → name decoding)**:
- `assumption` struct (atms.rkt:113): `(struct assumption (name datum) #:transparent)` — name is SYMBOL field.
- `solver-state-assumptions` (atms.rkt:696-698): live-reads `hasheq aid → assumption` via `net-cell-read-raw`.
- `current-command-atms` (elab-speculation-bridge.rkt:104): parameter holds box of solver-state; initialized lazily.
- Phase 3A's labels (typing-propagators.rkt:1137): `(format "branch-~a-at-~v" i position)` produces STRINGS. **Risk D-3C.b-1**: shape mismatch between Phase 3A's string labels and `assumption-name` symbol field — verify `solver-state-amb` coercion behavior at implementation.

**Tier 4 — Error infrastructure (chain field semantics gap)**:
- `union-exhaustion-error` struct (errors.rkt:115-116): `derivation-chain` field is `(listof (listof string))` — per-branch list of pre-formatted strings. **Critical shape gap vs 3C.a's structured `derivation-chain`**; Q-B.2 resolves.
- format-error renders chain at lines 267-287 with "    because: ~a" prefix per step; replacement requires coordinated format-error update.
- `build-derivation-chain` (typing-errors.rkt:127) is current sexp-mode chain builder — produces empty chain today (Q6.x finding).

**Tier 5 — Tropical fuel (residual cost)**:
- `tropical-left-residual` (tropical-fuel-primitives.rkt:105): `(if (>= b a) (- b a) 0)`. Adjunction verified.
- Canonical fuel-cost-cell tracks CUMULATIVE remaining fuel (not per-step decrements). Per-step semantic doesn't cleanly map — Q-B.4 defers cost annotation to 3C.d.

**Tier 6 — Q-B.5 inferred-union firing — what syntax exercises Phase 3A?**:
- `'union-inhabitation-all-fail` parity test (test-elaboration-parity.rkt:483-502) ALREADY exercises sexp annotated all-fail: `(ns t) (def x : <Int | Bool> := "hello") x` → both 3A on-network AND sexp check/err fire (per parity test comment).
- Q6.x probe used WS-mode `def x <Nat | Bool> "hello"` (no `:`, no `:=`) → DIFFERENT dispatch path; `prop_allocs=0` confirmed only sexp check/err fires for WS form.
- **Discovery**: sexp annotated unions trigger 3A's mechanism; WS-mode form does not. 3C.b targets sexp annotated path (where 3A fires); 3C.c will cover WS path (where only sexp check/err fires).
- **Risk D-3C.b-3**: double-emission for sexp annotated unions (both paths produce union-exhaustion-error) — Q-B.1.ii resolves via γ phase-boundary restructure.

**Tier 7 — Parity test patterns**:
- `parity-test` macro + `check-parity-equal?` (test-elaboration-parity.rkt:42-108) with `#:expected` / `#:expected-type` / `#:expected-shape` / `#:expected-warnings` — directly extensible for 3C.b's 5-axis discriminating coverage.
- User-facing emission path (driver.rkt:1488 + 1686 + 1772): `(emit-error-diagnostic r)` when `current-emit-error-diagnostics` is true + `r` is `prologos-error?`.

#### §9.5.3.2 Resolved design questions (Q-B.1 through Q-B.5) — LOCKED via 3-column adversarial

| Q | LOCKED Lean | Adversarial rationale |
|---|---|---|
| **Q-B.1.i** Detection mechanism | **(d) refined — per-fork threshold propagator + per-position monotone latch cell** (see §9.5.3.3 for full architecture) | User-articulated coupling intuition during dialogue rejected handler-side detection (option c) as Decomplection violation: option (c) makes `process-fork-on-union` + `process-fork-contradiction` MULTI-CONCERN (decomposition + worldview-narrowing + chain-emission all mixed). Option (d) keeps handlers SINGLE-CONCERN; chain-emission gets its OWN propagator per fork; matches set-latch + threshold pattern from `.claude/rules/propagator-design.md` (canonical). Cell-18 (per-position contradicted-aids latch, monotone hash-of-sets) persists across rounds; threshold-fire-once propagator reads cell-18 + closes over `(position, branch-aid-set)` → fires when subset holds → action writes cell-19 (chain storage). |
| **Q-B.1.ii** Avoiding double-emission | **(γ) phase-boundary restructure** — 3C.b BUILDS + STORES chain on-network (cell-19); does NOT emit user-facing error itself. 3C.c bridges from `check/err`'s `union-exhaustion-error` construction to consume the stored chain. Single emission point structurally. | (α) accept temporary double-emission violates workflow.md "all tests green before moving on"; (β) gating requires syntactic-mode awareness in on-network handler (conceptual leak); (δ) check/err depending on on-network state reverses principal/derived (creates PM 12 + Phase 4D debt). (γ) decomplects chain CONSTRUCTION from chain EMISSION — aligns with Data Orientation principle. Scope shift from §9.5.1.5 partition spec (3C.b "build + emit") to (3C.b "build + store") is honest re-scoping driven by audit. |
| **Q-B.1.iii** Idempotence | **Structurally subsumed by threshold-fire-once propagator** — fire-once self-cleans dependents after one fire; per-position threshold fires AT MOST ONCE per fork. NO separate emitted-chains tracker cell needed (eliminated vs option (c) plan). | Cascading simplification: option (d) refinement turns Q-B.1.iii into a structural property of the propagator pattern, not a discipline-maintained guard. 3 cells reduce to 2 (cell-18 latch + cell-19 chain storage; no emitted-chains tracker). |
| **Q-B.2** Chain field shape | **(β) replace `union-exhaustion-error.derivation-chain` field type** from `(listof (listof string))` → `(listof derivation-chain)` (per-branch structured chains) + **(β.i) per-position chain storage cell-19** (`(hasheq position → derivation-chain)`) for on-network propagation between 3C.b's writer + 3C.c's bridge consumer | (α) string-list conversion violates Q9 (REPLACE authoritatively) + Q8 (LSP-ready structured); (γ) dual-field violates workflow.md "belt-and-suspenders"; (β) is the principled landing. Coordinated change spans 3C.b (struct field semantic + cell-19 writer) + 3C.c (consumer + format-error update). Format-error rendering updates align in 3C.d. |
| **Q-B.3** filter-fn shape | **(a) `(step → bool)` predicate; consumer wrapper closes over branch aid-set** | Matches 3C.a primitive signature; minimal API surface; predicate is GENERAL — reusable for non-aid-set filters (Phase 11b second consumer). Consumer wrapper encapsulates aid-set filtering as a closure. |
| **Q-B.4** residual-cost enrichment | **(d) defer to 3C.d** — 3C.b leaves `residual-cost=#f` per 3C.a primitive default | Per-step semantic doesn't map to canonical fuel-cost-cell (cumulative remaining, not per-step decrements). Chain-level annotation (option (b)) requires 3C.a struct change without demonstrated load-bearing need. Defer keeps 3C.b focused; 3C.d revisits with format-error update. |
| **Q-B.5** Test scenarios | **5 axes** covering discriminating coverage (see §9.5.3.4) | All in sexp annotated form (where 3A fires per Tier 6 finding); positive (chain emits on all-fail) + negative (chain DOESN'T emit on partial/full success) + idempotence (repeated invocation single-emits). 4-axis discriminating gate per Q10 lock lands in 3C.d. |

#### §9.5.3.3 Refined option (d) — per-fork threshold propagator architecture

**Architecture summary**:

| Element | Role | Lifecycle | LoC est. |
|---|---|---|---|
| Cell-16 (existing) | Input to narrowing handler | Transient `#:reset-value (seteq)` | unchanged |
| **Cell-18 NEW** `contradicted-branch-aids-cell-id` | Per-position latch for threshold propagator; shape `(hasheq position → (seteq aid))`; merge: hash-union with set-union; persists across rounds (monotone) | Persists | ~20 LoC alloc + drift check + SRE registration |
| **Cell-20 NEW** `union-derivation-chains-cell-id` | Per-position chain storage; shape `(hasheq position → derivation-chain)`; merge: hash-union (chain replacement by hash-set semantic) | Persists | ~20 LoC alloc + drift check |
| 3A.b watcher (`make-branch-contradiction-watcher-fire-fn`, line 1248) | **Fan-out**: writes to BOTH cell-16 (narrowing handler input) AND cell-18 (threshold latch) | Fire-once self-cleans | ~10-15 LoC modification |
| **Per-fork threshold-fire-once propagator NEW** | Reads cell-18; closes over `(position, branch-aid-set, request-info)`; fires when `(subset? branch-aid-set (hash-ref cell-18-val position (seteq)))`; action: build chain via wrapper → write cell-19 | Fire-once self-cleans | ~40-60 LoC (factory + install at process-fork-on-union step) |
| `derivation-chain-for/union-contradict` wrapper | Calls `static-reverse-walk` with filter-fn closing over aid-set; enriches steps with `assumption-names` via `solver-state-assumptions` lookup | Read-time function | ~80-100 LoC |

**What stays unchanged**:
- `process-fork-on-union`: keeps decomposition concern (gains ONE install step for threshold per fork — structurally additive, not behaviorally invasive)
- `process-fork-contradiction`: **LITERALLY UNTOUCHED** — single-concern (worldview narrowing) preserved
- Cell-15, cell-16, cell-17: all keep existing shapes + lifecycles

**Mantra alignment** (per-word check applied adversarially):

| Word | Catalogue | Challenge | Adversarial |
|---|---|---|---|
| **All-at-once** | Install per fork (1 threshold + N branch checks + N watchers in one process-fork-on-union pass) | Could the install itself be more parallel? | Install is the natural granularity (per-fork unit); broadcast at this layer doesn't make sense |
| **All in parallel** | Threshold runs concurrent with sibling-fork thresholds; watcher fires concurrent with narrowing handler | Watchers write to 2 cells per fire — sequential within a fire | Within-a-fire sequentiality is acceptable (per-watcher work is bounded); BSP parallelism preserved at install layer |
| **Structurally emergent** | Chain emission emerges from cell-18 subset relation; no imperative dispatch | Threshold predicate is closed over branch-aid-set — that's data, not code | ✓ predicate is computed from cell state at fire time; structural |
| **Information flow** | Watchers → cell-16 (narrowing) + cell-18 (threshold); threshold → cell-19 (chain) | All through cells | ✓ no parameter threading; no return-value chains; cell-mediated throughout |
| **ON-NETWORK** | Entirely cell-based; no off-network state; chain construction is a read-time view over on-network state | Wrapper uses `current-command-atms` parameter for assumption-name decoding | `current-command-atms` is recognized scaffolding (PM Track 12 retirement target); not introducing new off-network state |

#### §9.5.3.4 Sub-step partition (revised per option (d) refinement)

| Sub-step | Scope | LoC est. | Key gate |
|---|---|---|---|
| **3C.b.1** | New on-network cells: cell-18 (`contradicted-branch-aids-cell-id`, monotone hash-of-sets) + cell-19 (`union-derivation-chains-cell-id`, hash-union); allocation + pre-allocation drift checks (mirroring fuel-cost-cell pattern); merge-fn registrations via Tier 2 `register-merge-fn!/lattice`; SRE domain for cell-18 if not reusable | ~50-80 | Cells allocate at make-prop-network; drift check passes; no semantic regression |
| **3C.b.2** | Modify `make-branch-contradiction-watcher-fire-fn` (typing-propagators.rkt:1248) for fan-out: write to BOTH cell-16 AND cell-18 inside contradiction branch | ~15-25 | 3A.b tests still pass; new test verifies fan-out write to cell-18 |
| **3C.b.3** | Build `derivation-chain-for/union-contradict net branch-aid-set request-info → derivation-chain` wrapper in error-explanation.rkt (exported); enrich steps with `assumption-names` via `solver-state-assumptions` lookup using `current-command-atms` | ~80-120 | Wrapper produces chain with populated assumption-names; unit tests verify enrichment shape; D-3C.b-1 label-shape risk validated at impl |
| **3C.b.4** | At process-fork-on-union step (between current step 4 watcher install and step 5 cell-17 write), install threshold-fire-once propagator per fork: reads cell-18; closes over (position, branch-aid-set, request-info); fires on subset; action calls `derivation-chain-for/union-contradict` then writes cell-19 | ~50-80 | Threshold propagator installs per fork; fires once per all-branch-contradict event; cell-19 populated; idempotence verified |
| **3C.b.5** | 5 union-all-contradict-chain axis tests in test-elaboration-parity.rkt + Q6.x probe re-run with sexp-mode scenario showing chain populated (probe diff) + targeted suite + full-suite stable | ~80-120 | All 5 axes pass; probe diff shows non-empty cell-19 chain entry; full suite within 109-115s variance band |
| **3C.b-VAG** | Adversarial 3-column VAG (catalogue + challenge + adversarial); cumulative across 3C.b sub-steps; verify D-3C.b-1 through D-3C.b-5 cleared | docs | All 4 VAG questions pass under adversarial framing; tracker row 3C.b → ✅ |

**Total estimated scope**: **~275-425 LoC** + docs across 5 implementation sub-steps + 1 VAG close.

This is upward from §9.5.1.5's original 80-150 LoC estimate for 3C.b. The honest scope-up is driven by:
- Option (d) refinement adds 1 new cell + 1 new propagator-install per fork (vs option (c)'s handler-modification approach)
- Q-B.1.ii (γ) phase-boundary restructure adds cell-19 chain storage (vs original direct-emission approach)
- Q-B.2 (β) field type change is coordinated across 3C.b/c/d (3C.b's share is cell-19 writer + struct definition)

Trade-off accepted: more LoC in 3C.b for structural cleanliness (single-concern handlers preserved; chain-emission decomplected from worldview-narrowing).

**5 axis test scenarios** (3C.b.5):

| Test axis | Scenario | Expected (post-3C.b) |
|---|---|---|
| `'union-all-contradict-chain/sexp-annotated` | `(ns t) (def x : <Int \| Bool> := "hello") x` | cell-19 populated with non-empty per-branch chains; chain references branch assumption-names |
| `'union-all-contradict-chain/nat-bool` | `(ns t) (def x : <Nat \| Bool> := 3.14) x` (3.14 = neither Nat nor Bool) | cell-19 populated with non-empty chains |
| `'union-all-contradict-chain/idempotent` | Run same scenario twice in sequence | Only ONE chain emission per fork-on-union event (verifies threshold fire-once subsumption of Q-B.1.iii) |
| `'union-all-contradict-chain/no-error-no-chain` | `(ns t) (def x : <Int \| String> := 42) x` (Int succeeds) | cell-19 NOT populated for x's position (negative axis — chain doesn't fire on partial success) |
| `'union-all-contradict-chain/multi-success-no-chain` | `(ns t) (def x : <Nat \| Int> := 0N) x` (both succeed) | cell-19 NOT populated for x's position (negative axis — chain doesn't fire on full success) |

Note: 3C.b tests assert on cell-19 STATE (chain populated structurally); user-facing `union-exhaustion-error.derivation-chain` rendering tests land in 3C.c (when bridge consumes cell-19) + 3C.d (format-error update). 3C.b tests focus on the on-network mechanism in isolation.

#### §9.5.3.5 Drift risks named (D-3C.b-1 through D-3C.b-5)

| # | Risk | Mitigation |
|---|---|---|
| **D-3C.b-1** | `assumption-name` field is SYMBOL (atms.rkt:113); Phase 3A's labels are STRINGS produced via `format` (typing-propagators.rkt:1137). Coercion semantic of `solver-state-amb` unknown — needs runtime verification | Verify at 3C.b.3 impl: read `solver-state-amb` source; if coercion happens (string→symbol), document the contract; if not, adapt wrapper to handle both string and symbol shapes |
| **D-3C.b-2** | Per-position branch-mask not currently on-network — adding cell-18 is new on-network state | Cell-18 is monotone (set-union per position; hash-union across positions) — natural lattice fingerprint; mirrors cell-17 (decomposed-positions) precedent; registered under SRE domain for Tier 2 hygiene; generalizes to Phase 9b γ multi-candidate (same shape) |
| **D-3C.b-3** | Double-emission risk during 3C.b → 3C.c window: sexp annotated unions today fire BOTH on-network 3A AND sexp check/err. Under option (d) + Q-B.1.ii (γ), 3C.b does NOT emit user-facing error — only stores chain in cell-19. Risk: if 3C.c lags, sexp annotated unions continue producing today's empty-chain error (no regression; no improvement) | Mitigated structurally: 3C.b doesn't add a new error emission point. The chain is BUILT and STORED; user-facing emission stays at check/err's existing path (which today produces empty chain). 3C.c bridges by reading cell-19 from check/err. No double-emission possible during the gap window. |
| **D-3C.b-4** | `union-exhaustion-error.derivation-chain` field type change ripples through format-error (errors.rkt:267-287) + typing-errors.rkt:97 chain construction (currently produces string-list) + sexp `build-derivation-chain` (typing-errors.rkt:127) | Coordinated change scoped across 3C.b/c/d: 3C.b changes the struct field type and cell-19 writer; 3C.c migrates check/err's chain construction to read cell-19 + produce structured chain; 3C.d updates format-error rendering. Field type change at 3C.b is the gate — once changed, downstream consumers MUST migrate within phase. |
| **D-3C.b-5** | filter-fn applied BEFORE recursion (3C.a:204) → aid-set filter prunes recursion through propagators whose aids don't intersect the branch aid-set | DESIRABLE behavior: keeps chain focused on contradicted-branch lineage; unrelated propagators (elaboration scaffolding firing under outer worldview before the fork) don't appear in chain. Document at wrapper docstring; verify via test that filtered-out propagators are absent from chain. |
| **D-3C.b-6** (NEW) | Watcher fan-out write to 2 cells (cell-16 + cell-18) creates a coupling point: if a third concern emerges (Phase 9b γ multi-candidate; Phase 11b general diagnostics), do we add a 4th cell + 3rd fan-out write? | Codify as PATTERN: "single contradiction event → multiple downstream readers via cells." For future readers (beyond 3C.b), install a separate propagator that reads cell-16 and writes derived state; keep watcher fire-fn STABLE (2-cell fan-out is the load-bearing minimum for 3C). Watching-list codification candidate; promote at 2nd data point (Phase 9b γ adoption). |

#### §9.5.3.6 Cross-track captures (forward-pointers)

Per §9.5.1.7 vision-forward framing (Propagator-First Diagnostics), 3C.b's deliverables extend the cross-track footprint:

- **Phase 11b** (parent D.3): consumes 3C.b's per-fork threshold-fire-once pattern + cell-18 latch shape as PRECEDENT for general derivation diagnostics; extends with non-union scenarios.
- **Phase 9b γ multi-candidate** (parent D.3): cell-18 hash-of-sets shape IS the canonical per-position-readiness latch for N-ary candidate inhabitant evaluation. Reuses the threshold-fire-once + monotone-latch pattern verbatim.
- **PPN Track 8 LSP**: cell-19 structured `derivation-chain` storage is LSP-serializable; PPN 8 reads cell-19 directly as diagnostic payload (no string-format conversion at LSP boundary).
- **PReduce Track 6 speculative reduction**: cost-bounded ATMS branching errors adopt 3C.b's emission pattern (stratum-handler-companion threshold-fire-once propagator + chain emission via residual walk).
- **Cross-track template codification status**: NOT promoted yet to DESIGN_PRINCIPLES.org. Specialized Cell Type Framework precedent — graduate after 2nd-3rd empirical instance lands. 3C.b is 1st instance of "per-fork threshold propagator + monotone latch + chain storage" composition.

#### §9.5.3.7 Closure criteria

Phase 3C.b closes per Stage 4 Per-Phase Protocol + adversarial VAG:

1. **Sub-steps 3C.b.1 through 3C.b.5 delivered** with each Stage 4 step completed in order (test coverage → commit → tracker → dailies → proceed)
2. **Cell-18 + cell-19 allocated** with pre-allocation drift checks passing
3. **Watcher fan-out write** to cell-18 verified by unit test
4. **`derivation-chain-for/union-contradict` wrapper** produces chain with populated assumption-names
5. **Threshold-fire-once propagator** installs per fork; fires once per all-branch event; populates cell-19
6. **5 axis tests pass** (3 positive + 2 negative) verifying both emission AND non-emission paths
7. **Probe re-run** (sexp annotated scenario) shows cell-19 populated; pre-3C.b baseline showed empty
8. **Full suite stable** within 109-115s baseline variance band
9. **All 6 D-3C.b-* drift risks cleared** at 3C.b-VAG
10. **Adversarial 3-column VAG** passes 4 questions (on-network / complete / vision-advancing / drift-risks-cleared)

#### §9.5.3.8 Status

**Phase 3C.b mini-design + mini-audit: ✅ PERSISTED** (this commit). Ready to proceed to 3C.b.1 (cell allocations) per Stage 4 Per-Phase Protocol implementation cycle. Each sub-step ends with conversational dialogue checkpoint per workflow.md cadence rule (max autonomous stretch ~1 hour or 1 phase boundary).

#### §9.5.3.9 Phase 3C.b.5 Sub-step Mini-design (2026-05-23 — closing the 3C.b implementation arc)

Opening conversational mini-design + mini-audit for Phase 3C.b.5 per Stage 4 Per-Phase Protocol (mini-design + mini-audit co-dependent; outcomes persist to design doc; dailies log commit story). Context: post-3C.b.4 CLOSED at `e8cbf0e1` (per-fork threshold propagator install at process-fork-on-union Step 4.5). 3C.b.5 is the closing sub-step of the 3C.b arc — adds end-to-end parity coverage for cell-19 chain population + Q6.x probe re-run documentation. After 3C.b.5 closes, 3C.b-VAG runs cumulative cross-sub-step adversarial 3-column close.

##### §9.5.3.9.1 Mini-audit findings (code-reality re-verified post-3C.b.4)

Mini-audit executed pre-mini-design across 7 tiers grounding the design in code reality. Full findings in dailies 2026-05-23 entry. Key surfaces:

| Tier | Surface | Critical finding |
|---|---|---|
| 1 | `test-elaboration-parity.rkt` parity-test infrastructure | `parity-test` is `test-case` wrapper; `check-parity-equal?` is STRING-substring-only; existing 3A.c.3-R7 axes (line 447-502) use `#:expected`/`#:expected-type`. **Cell-19 chain assertions require structural mechanism (not string substring)** |
| 2 | `test-support.rkt` `run-ns-last` shape | Returns `(last (process-string s))` — STRING only; `with-forked-network` parent box is NEVER mutated by `process-string` (which creates its own internal box) |
| 3 | `driver.rkt` process-string + net access | `process-string` (line 1460) parameterizes `current-prop-net-box` to fresh box, DISCARDS on exit; `process-string-inner` NOT exported; dailies' "lean (iii) use lower-level process-string" path is **structurally infeasible without code change** |
| 4 | `error-explanation.rkt` exports | `(struct-out derivation-chain)` + `(struct-out derivation-step)` + `static-reverse-walk` + `derivation-chain-for/union-contradict` all provided; assertion-ready |
| 5 | propagator.rkt cell-18/19 + typing-propagators.rkt threshold | cell-18 + cell-19 PROVIDED (lines 119-122); `make-fork-chain-threshold-fire-fn` PROVIDED (typing-propagators.rkt:136); Step 4.5 install uses plain `net-add-propagator` (NOT fire-once) |
| 6 | Q6.x probe + dispatch paths | WS-mode `def x <Nat \| Bool> "hello"` does NOT trigger Phase 3A; sexp annotated `(def x : <T1 \| T2> := v) x` DOES via `type-map-write` → `maybe-emit-fork-on-union-request` (R7 inline emit) → cell-15 |
| 7 | Existing cell-read test patterns | T-C.b.4 unit tests (test-union-types-atms.rkt:461-563) use synthetic `make-prop-network` + direct `net-cell-read`; E2E tests (lines 585-662) use `run-to-quiescence` for in-test elaboration drive |

##### §9.5.3.9.2 Resolved design questions (Q-C.b.5.1 through Q-C.b.5.5) — LOCKED via 3-column adversarial

| Q | LOCKED Lean | Adversarial rationale |
|---|---|---|
| **Q-C.b.5.1** Net access mechanism | **(B) Add new public `process-string/return-net` to driver.rkt** — `: string → (values results net)`. Mirrors `process-string`'s body but exposes the final network via a CALLER-SUPPLIED outer box parameterized to the inner pipeline. | (A) Exporting `process-string-inner` leaks intentional internal-helper privacy; future internal changes (per-command network reset) silently break tests. (C) Synthetic-network E2E defeats the parity-test charter (regression in `maybe-emit-fork-on-union-request` or `process-fork-on-union` dispatch wouldn't surface). (B) is cleanest public API; usable by future Phase 11b LSP diagnostics + Track 4D substrate work. Adversarial inversion ("modify process-string to always return `(values results net)`") is more honest but BREAKING — rejected for minimal-blast-radius reasons; B's separate-function path is the principled landing. |
| **Q-C.b.5.2** Test file location | **(a) test-elaboration-parity.rkt new section** "Phase 3C.b — union-all-contradict-chain axes" | Matches §9.5.3.4 spec. Parity-test file CHARTER is "regression-gate the on-network elaboration path produces correct observables" — cell-19 IS such an observable. Existing axes happen to be substring-matchable because their observables ARE in result string; cell-19 axes are STRUCTURAL parity (same regression-gate intent, different observation mechanism). Adversarial inversion ("split file by observation mechanism") rejected as fragmentation without coverage gain at this scale. |
| **Q-C.b.5.3** `/idempotent` axis | **(iv) RETIRE** — keep 4 axes (3 positive + 2 negative ÷ 1 idempotent retired = 4) | Idempotence is **structurally guaranteed across THREE layers**: (1) T-C.b.4-idempotence-guard at test-union-types-atms.rkt:541 covers the cell-19 emit-once defensive guard; (2) cell-17 (decomposed-positions-cell-id) guard at the dispatch level prevents same-position re-decomposition; (3) cell-18 monotone stabilization at the architecture level + watcher fire-once self-clean. Adding a 4th layer at parity-test level is belt-and-suspenders without coverage gain. **Strong adversarial check**: would a regression escape all 3 layers but be caught only by parity-test idempotence axis? Hard to construct — if cell-17 fails, OTHER positive axes fail (spurious cell-19 re-populate); if cell-18 monotone fails, threshold predicate never met (caught by positive axes) OR always met (caught by negative axes); if T-C.b.4 guard fails, that test fails. (iv) is principled, not rationalization. |
| **Q-C.b.5.4** Q6.x probe re-run framing | **(a) Documentation artifact (NOT test assertion)** — re-run via process-file; save to `data/probes/2026-05-22-3C-Q6x-post-3Cb.txt`; document interpretation in dailies as EVIDENCE that cell-19 stays empty for WS-mode → confirms 3C.c sexp-bridge necessity | Probe re-run as design input for 3C.c, not a regression assertion. Adversarial check: probe could DRIFT if WS-mode dispatch path changes; documenting expected outcome explicitly mitigates. |
| **Q-C.b.5.5** Test scenarios discriminating power | **4 axes confirmed**: `/sexp-annotated`, `/nat-bool`, `/no-error-no-chain`, `/multi-success-no-chain` | Per-axis discriminating regression class: `/sexp-annotated` catches threshold install / fan-out / wrapper invocation / assumption-name decoding regressions; `/nat-bool` discriminates against accidentally hardcoded type dependencies; `/no-error-no-chain` catches spurious threshold fires (subset check semantic); `/multi-success-no-chain` catches spurious threshold fires when NO branches contradict (defensive guard correctly NOT applied). |

##### §9.5.3.9.3 Sub-step partition

| Sub-step | Scope | Est. LoC | Key gate |
|---|---|---|---|
| **3C.b.5.a** | Mini-design persistence at §9.5.3.9 (this section) | docs-only | This commit |
| **3C.b.5.b** | `process-string/return-net` in driver.rkt — `: string → (values results net)`. Mirrors process-string body; box captured pre-discard via `let` capture before parameterize body exit. Update provides list. Unit test in test-driver.rkt (or test-elaboration-parity.rkt if no driver test file) verifying box shape. | ~30-50 LoC + 1-2 test cases | New function compiles + smoke test passes |
| **3C.b.5.c** | New section "Phase 3C.b — union-all-contradict-chain axes" in test-elaboration-parity.rkt. Uses `test-case` (NOT parity-test macro since assertions are STRUCTURAL). 4 axes consume `process-string/return-net`; assert on cell-19 via `(net-cell-read net union-derivation-chains-cell-id)`. | ~80-100 LoC | All 4 axes pass |
| **3C.b.5.d** | Q6.x probe re-run via `process-file`; save output to `data/probes/2026-05-22-3C-Q6x-post-3Cb.txt`; document interpretation in dailies entry + this design doc subsection §9.5.3.9.6 | docs + artifact | Probe runs without error; cell-19 expected empty for WS-mode |
| **3C.b.5-close** | Targeted (test-elaboration-parity + test-union-types-atms + test-error-explanation) + full suite regression gate + backfill (§3 Progress Tracker row + dailies close entry) | docs | Suite within 109-115s variance band |

**Total estimated scope**: ~110-150 LoC + docs + probe artifact (down from §9.5.3.4's "80-120 LoC" because of net-access infrastructure ~30-50 LoC).

##### §9.5.3.9.4 Drift risks named (D-3C.b.5-1 through D-3C.b.5-5)

| # | Risk | Mitigation |
|---|---|---|
| **D-3C.b.5-1** | End-to-end vs synthetic divergence — Path B (`process-string/return-net`) tests the FULL dispatch chain (`type-map-write` → R7 emit → `process-fork-on-union` → watcher fan-out → threshold). If we had taken Path C (synthetic networks), a regression in that chain wouldn't surface. | Path B locked at Q-C.b.5.1; risk MITIGATED structurally. Cross-cutting note: existing T-C.b.4 unit tests (synthetic) + 3C.b.5 E2E tests (Path B) provide DEFENSE IN DEPTH — unit tests catch threshold-body regressions; E2E tests catch dispatch-chain regressions. |
| **D-3C.b.5-2** | "Validated but not deployed" intermediary — cell-19 chains accumulate but have NO consumer until 3C.c bridges them. Existing user-facing `union-exhaustion-error.derivation-chain` field STILL uses `(listof (listof string))` from sexp `build-derivation-chain`. 3C.b.5 verifies cell-19 STORAGE; user-facing rendering verification waits for 3C.c+3C.d. | Document explicitly in 3C.b.5 commit message + dailies that cell-19 storage is the deliverable; rendering verification deferred to 3C.c. Watching-list codification candidate ("validated-not-deployed gap pattern" — promote at 2nd data point). |
| **D-3C.b.5-3** | Same-name `srcloc` gotcha could resurface — if axis tests inspect `derivation-step-srcloc`, ensure Prologos's 4-field `srcloc` (per `source-location.rkt:27`) is the variant used (NOT Racket's 5-field built-in). 3C.a precedent caught this at impl. | Tests should NOT directly construct srcloc structs (consume from real elaboration via `process-string/return-net`). If assertion needs srcloc literal, import from `../source-location.rkt`. |
| **D-3C.b.5-4** | Assertion-shape dependency on 3C.b.3's name-decoding format — tests assert on `derivation-step-assumption-names` containing branch identifiers. If 3C.b.3's `decode-aid-name` shape changes (e.g., the "branch-N-at-position-X" string format evolves) or 3C.c/d updates the format, tests break. | Assertion should test SUBSTRING presence (e.g., `string-contains? name "branch"`) rather than exact format. Documents the dependency explicitly. |
| **D-3C.b.5-5** | Q6.x probe re-run interpretation framing — if probe is re-run and treated as REGRESSION assertion (cell-19 must be empty for WS), and 3C.c later ADDS WS coverage via sexp-bridge, the probe assertion regresses. | Probe IS documentation artifact (Q-C.b.5.4 lock), NOT test assertion. Save probe output as evidence; do NOT add probe to test suite. |

##### §9.5.3.9.5 Closure criteria

Phase 3C.b.5 closes when:

1. **§9.5.3.9 persisted** (this commit covers it)
2. **`process-string/return-net` lands** in driver.rkt with provides; targeted smoke test passes
3. **4 axes** in test-elaboration-parity.rkt "Phase 3C.b — union-all-contradict-chain axes" section all pass
4. **Q6.x probe re-run** + artifact + documentation
5. **Targeted suite** (test-elaboration-parity + test-union-types-atms + test-error-explanation) PASS
6. **Full suite stable** within 109-115s variance band
7. **All 5 D-3C.b.5-* drift risks cleared** (verified at 3C.b.5-close)
8. **§3 Progress Tracker updated** with row 3C.b.5 → ✅ + commit hash
9. **Dailies session entry** persisted with sub-step-by-sub-step commit story
10. **Bookmark for 3C.b-VAG** — cumulative cross-sub-step adversarial close to follow

##### §9.5.3.9.6 Q6.x probe re-run interpretation (CLOSED 2026-05-23)

**Probe artifact**: `racket/prologos/data/probes/2026-05-22-3C-Q6x-post-3Cb.txt` (27 lines)

**Probe scenarios** (per `examples/2026-05-22-3C-Q6x-probe.prologos`):
- S1: `def x <Nat | Bool> "hello"`
- S2: `def y <Int | Bool> "world"`
- S3: `def z <<Nat | Bool> | String> 3.14` (nested union; rational literal)

**Empirical results post-3C.b**:

| Counter | Value | Interpretation |
|---|---|---|
| `prop_allocs` | **0** | Phase 3A on-network mechanism did NOT install any propagators for WS scenarios |
| `prop_firings` | **0** | No on-network propagators fired (consistent with `prop_allocs=0`) |
| `CELL-METRICS cells` | **42** | Baseline cell count; no per-fork latch/threshold/chain cells added (would be cells 18+19 per fork if 3A fired) |
| `CELL-METRICS propagators` | **0** | No 3A-installed propagators present in final network |
| `union-exhaustion-error.derivation-chain` | **`'(() ())`** (S1, S2) / **`'(() () ())`** (S3) | Empty per-branch lists from sexp `check/err` path's `build-derivation-chain` — confirms 3C.c sexp-bridge still required |

**Interpretation (D-3C.b.5-6 deployment gap CONFIRMED)**:

WS-mode dispatch path does NOT route through `type-map-write` → R7 inline emit → cell-15 → process-fork-on-union. The 3 WS scenarios are handled entirely by the sexp `check/err` path (typing-errors.rkt:64-118) which:
1. Performs per-branch speculation via `with-speculative-rollback`
2. Constructs `union-exhaustion-error` with `derivation-chain` field populated by `build-derivation-chain`
3. Returns empty per-branch chains (`'()` per branch) since sub-failures aren't collected for the WS path

**EVIDENCE for 3C.c sexp-bridge necessity**:

The empty `union-exhaustion-error.derivation-chain` field is the artifact 3C.c bridges by:
- Reading cell-19 (populated by 3C.b's on-network mechanism for INFERRED unions; or alternative path for sexp ANNOTATED unions per 3C.c design)
- Replacing the empty `'(() ())` payload with the structured `derivation-chain` struct from `error-explanation.rkt`

**Cross-references**:
- Q6.x baseline probe (pre-3C): same empty-chain shape (`'(() ())`) — confirming 3C.b's structural changes haven't disrupted the existing sexp path
- Phase 3C.b.5.c-bugfix (commit `bc47e0d6`): made cell-19 actually populate for synthetic E2E scenarios; WS scenarios remain a separate gap addressed by 3C.c
- D-3C.b.5-6 (§9.5.3.9.4): "validated but not deployed" anti-pattern explicitly applies pre-3C.c

**Probe re-run status**: ✅ ARTIFACT SAVED, EVIDENCE CONFIRMED. cell-19 stays EMPTY for WS-mode as predicted. 3C.c proceeds with confirmed scope.

##### §9.5.3.9.7 Status

**Phase 3C.b.5 mini-design + mini-audit: ✅ PERSISTED** (this commit, 2026-05-23). Ready to proceed to 3C.b.5.b (driver.rkt `process-string/return-net` introduction) per Stage 4 Per-Phase Protocol implementation cycle. Conversational checkpoints between each implementation sub-step per workflow.md cadence.

#### §9.5.3.10 Phase 3C.b cumulative VAG (cross-sub-step adversarial 3-column close, 2026-05-23)

Per CRITIQUE_METHODOLOGY.org "Three-column adversarial framing" (user-articulated methodology refinement: column 3 actively DEMOLISHES, not softly improves; cataloguing alone is rationalization). Cumulative across all 3C.b sub-steps + bugfix. The catalogue→challenge→adversarial transition is NEVER natural — actively forced at each gate.

**Scope**: 3C.b mini-design (`9f9b6c1b`) + 3C.b.1 (`c160fbc7`) + 3C.b.2 (`c51b08e4`) + 3C.b.3 (`94647535`) + 3C.b.4 (`e8cbf0e1`) + 3C.b.5.a (`2c6e8d3d`) + 3C.b.5.b (`051483e8`) + 3C.b.5.c-bugfix (`bc47e0d6`) + 3C.b.5.c (`9b93ab2d`) + 3C.b.5.d (`0ccd248e`) + 3C.b.5-close (`7f055d50`).

##### Question (a): On-network?

| Catalogue | Challenge | Adversarial |
|---|---|---|
| ✓ cell-18 latch + cell-19 chain storage are on-network cells; threshold propagator is on-network propagator; watcher fan-out is on-network propagator; chain construction via `static-reverse-walk` reads on-network propagator dep graph. End-to-end Propagator-First Diagnostics flow entirely on-network within 3C.b's scope. | Are off-network scaffolds preserved "for safety"? The wrapper uses `current-command-atms` parameter — Racket parameter holding box of solver-state — that IS off-network state. Is it required, or could it be retired? | **What breaks?** `current-command-atms` is inherited from Phase 3A scaffolding (elab-speculation-bridge.rkt:104). Workflow.md "Validated ≠ Deployed" applies to parameter retirement: PM Track 12 owns migrating module-level parameters to cells. 3C.b doesn't make this WORSE (uses existing parameter), but doesn't make it BETTER either. **Adversarial pushback**: should we have introduced an on-network solver-state cell as part of 3C.b? Counter-pushback: parameter is recognized scaffolding with explicit retirement plan; introducing a new on-network solver-state cell in 3C.b would be scope creep into PM Track 12. The pragmatic boundary: 3C.b consumes existing scaffolding without extending it. **Adversarial bonus**: the static-reverse-walk reads `propagator.outputs/inputs/srcloc` via struct accessors — these are network METADATA, not cell-reads. Is this still "on-network"? Yes per Q-A.3 lock (Cell/Propagator/Scheduler Orthogonality preserved — no observer-set, no scheduler coupling). The dep graph IS on-network state; struct-accessor reads are READ-TIME projections of it. |

##### Question (b): Complete? (shape + benefit, including microbench-verified perf claims)

| Catalogue | Challenge | Adversarial |
|---|---|---|
| ✓ 5 sub-steps delivered + bugfix sub-step + close: cells/fan-out/wrapper/threshold/axes/probe; 4 axes pass post-bugfix; probe artifact confirms WS-mode gap; full suite 8265/106.1s/0 failures. | Did the implementation deliver the BENEFIT, not just SHAPE? The shape was: end-to-end on-network chain emission for all-branch-contradict. The benefit: populated cell-19 chain. Pre-bugfix, the SHAPE landed (3C.b.4 threshold installed; cell-18 written) but the BENEFIT (populated cell-19) didn't — T-C.b.4 unit tests masked the gap by manually populating cell-18, bypassing the watcher fan-out's broken layer. | **What breaks?** The bugfix at 3C.b.5.c-bugfix revealed that 3C.b.4 originally shipped a STRUCTURALLY BROKEN mechanism. The threshold predicate (subset check) could NEVER hold pre-bugfix because cell-18 only ever accumulated one branch's aid. T-C.b.4 tests passed because they bypassed the broken layer entirely. **Adversarial finding**: 3C.b.4 close should have required E2E composition tests (watcher fan-out → cell-18 accumulation → threshold → cell-19), not just unit tests on the threshold body. The absence of E2E composition coverage at 3C.b.4 close allowed the bug to ship invisibly. **Codification candidate (NEW from this VAG)**: "Sub-step closes that ship integration code require E2E composition tests, not just unit tests for the new code at that step." Promote alongside the bugfix-class codification. **Bonus complete**: D-3C.b.5-6 deployment gap means Phase 3A doesn't fire for sexp annotated user-facing unions — populated cell-19 only happens for synthetic E2E + inferred unions. Honest framing: 3C.b ships the SUBSTRATE; 3C.c bridges to user-facing scenarios. |

##### Question (c): Vision-advancing?

| Catalogue | Challenge | Adversarial |
|---|---|---|
| ✓ Propagator-First Diagnostics architecture complete end-to-end on-network for all-branch-contradict (synthetic). Substrate foundation for Phase 11b, LSP, LHC, Track 4D, PReduce Track 6 per §9.5.1.7 cross-track captures. | Where do "multiple sources of truth" still exist on the hot path? Are inherited patterns from prior architectures still active? `current-command-atms` parameter (off-network scaffolding); sexp `check/err`'s `build-derivation-chain` still produces empty chains (typing-errors.rkt:127); `union-exhaustion-error.derivation-chain` field type is still `(listof (listof string))` not `(listof derivation-chain)`. Two-source-of-truth at field semantics persists until 3C.b/c/d coordinated arc completes. | **What breaks?** The vision claim is "Propagator-First Diagnostics" — but the FIRST USER-FACING SCENARIO (sexp annotated unions) still goes through sexp `check/err` with empty chains. Have we shipped a "first instance" of the vision that doesn't actually deliver user-facing value? **Adversarial pushback**: 3C.b ships the SUBSTRATE for the vision; 3C.c is the FIRST USER-FACING INSTANCE. Codification graduates to principle (DESIGN_PRINCIPLES.org) at Phase 11b (second consumer) per Specialized Cell Type Framework precedent (codified after multi-track instances). 3C.b shipping substrate-only IS consistent with the discipline. **Bonus adversarial**: pre-bugfix, the vision was vaporware (the mechanism shipped but produced empty cell-19 forever). The bugfix at 3C.b.5.c-bugfix is what MAKES the vision-advancing claim empirically supported. Without the diagnostic protocol's empirical falsification, 3C.b would have shipped a non-functional first instance — that's a VISION FAILURE that the diagnostic protocol prevented. |

##### Question (d): Drift-risks-cleared? (perf-vs-design-target + correctness)

| Catalogue | Challenge | Adversarial |
|---|---|---|
| ✓ All 6 D-3C.b-* + 7 D-3C.b.5-* drift risks named + verified cleared at sub-step closes. D-3C.b-6 (watcher fan-out coupling pattern): 2-cell minimum preserved; future readers install separate propagators. D-3C.b.5-7 (NEW bugfix-class): codified as watching-list. | Did the named risks cover both correctness AND perf-vs-design-target axes? Was there a "shape without benefit" gap that risk-naming missed? | **What breaks?** **D-3C.b.5-7 surfaced via diagnostic protocol POST-IMPLEMENTATION, NOT via design-time risk-naming.** Looking at the 3C.b.2 commit (`c51b08e4`): the watcher install was modified to add a cell-18 write inside the fire-fn body, but the install's OUTPUTS declaration wasn't updated to include cell-18. There's an ASYMMETRY between code-writes-to-cell vs declares-cell-as-output that could have been caught by an audit checklist or static analysis. **Adversarial finding**: the 3C.b.2 mini-design should have explicitly named "watcher writes to new cell — does the propagator install declare ALL written cells as outputs?" as a drift risk. The fact that nobody (designer, implementer, reviewers) noticed the asymmetry between fire-fn body and install declaration is a methodology gap. **Codification graduating from this VAG**: "Sub-step mini-design risk-naming should include CROSS-CHECK of propagator install declarations against fire-fn write sites — code-writes-to-cell vs declares-cell-as-output asymmetry is silent under undeclared-writes bypass-merge path." Watching list, 1 data point. **Bonus**: D-3C.b.5-6 (sexp-doesn't-trigger-3A) was surfaced AT 3C.b.5.c initial attempt, not at 3C.b parent design. The dailies §9.5.3.1 Tier 6 audit made the wrong empirical claim. **Empirical falsification as audit complement** — 3 data points cumulative this session (Q6.x + sexp-doesn't-trigger-3A + cell-18 bypass-merge bug) — meets workflow.md graduation threshold (PROMOTION-READY for DEVELOPMENT_LESSONS.org). |

##### VAG outcome — Phase 3C.b CLOSED

All 4 VAG questions PASS under adversarial framing. The arc produced:
- **Architectural deliverable**: end-to-end on-network Propagator-First Diagnostics for all-branch-contradict (synthetic E2E + future inferred-union paths)
- **Bugfix**: structural correctness restoration (cell-18 monotone accumulation via merge function vs silent last-write-wins)
- **Probe artifact**: empirical confirmation of D-3C.b.5-6 deployment gap (WS-mode → sexp check/err → empty chains; 3C.c bridges)
- **Methodology capital**:
  - 3 PROMOTION-READY codifications (Audit-driven scope refinement 8 data points; Multi-axis discriminating coverage 6 sites; Empirical falsification as audit complement 3 data points)
  - 3 NEW watching-list candidates (D-3C.b.5-7 bugfix-class; Sub-step closes require E2E composition tests; Cross-check propagator install declarations against fire-fn writes)
  - Diagnostic protocol per workflow.md WORKS (hypothesis-rejection sequence + read-source-directly → root cause)

**Net adversarial finding**: the diagnostic protocol PREVENTED a vision-failure (3C.b would have shipped a non-functional mechanism without the empirical falsification). This validates the workflow.md discipline AND surfaces 2 NEW methodology codifications worth promoting.

**Status**: Phase 3C.b CLOSED. §3 Progress Tracker row 3C.b-VAG → ✅ (this commit). Ready for Phase 3C.c mini-design opening.

### §9.5.4 Phase 3C.c mini-design + mini-audit (2026-05-24 — opening sexp-bridge consumer)

Opening conversational mini-design + mini-audit for Phase 3C.c per Stage 4 Per-Phase Protocol (mini-design + mini-audit are co-dependent activities cycling between design intent and code reality; outcomes persist to the design doc; dailies log the commit story). Context: post-3C.b CLOSED at `449faac9` (on-network Propagator-First Diagnostics for INFERRED unions; cell-19 populated by 3C.b's threshold-fire mechanism via `derivation-chain-for/union-contradict` wrapper). 3C.c bridges sexp `check/err` (the dominant user-facing path per Q6.x empirical finding) into the same on-network store, completing the Phase 3C deployment story.

Methodology: **3-column adversarial framing** (catalogue / challenge / adversarial) applied throughout. The third column ACTIVELY tries to demolish each lean rather than softly improve it. User-articulated **LHC vision reframing** during dialogue (§9.5.4.2 below) inverted the original lean from "sexp-primary + cell-19 supplement" to "cell-19 authoritative + sexp as temporary writer" — empirical proof that vision-aligned framing is load-bearing for design decisions.

The rigorous audit (Tier 1-7 below) also surfaced a NEW finding (Q-C.6, §9.5.4.3) — a cell-19 ↔ field shape mismatch that the original Phase 3C.b mini-design did not surface. This validates the audit-precedes-implementation discipline at the per-phase level: rigorous audit reveals tensions invisible at design time.

#### §9.5.4.1 Mini-audit findings (7 tiers, grounded in code)

7-tier structured audit executed pre-mini-design per Stage 4 mini-audit-precedes-implementation discipline.

**Tier 1 — `check/err` integration point (typing-errors.rkt:64-118)**:

- Signature: `(check/err ctx e t [loc srcloc-unknown] [names '()])` — **NO `net` parameter** in scope today
- Two call sites only: `driver.rkt:516` (`(check expr type)` top-level form) + `driver.rkt:1234` (`def x : T := body` annotated def body check)
- Both sites run INSIDE `parameterize ([current-prop-net-box ...])` blocks — `(current-prop-net-box)` IS reachable at check/err today via the parameter
- Union path (lines 69-104): flattens via `flatten-union-local`; per-branch speculative `(check ctx e br)` via `with-speculative-rollback`; collects per-branch `(list mismatch-string chain)`; constructs `union-exhaustion-error` with `derivation-chain = (map cadr branch-info)` shape `(listof (listof string))`
- Non-union path (lines 105-118): builds `type-mismatch-error` with `provenance` (also `(listof string)`) — **NOT in 3C scope** per Q9 (non-union retires at Phase 11b)
- Q-B.2 retirement target: per-branch chain construction at lines 84-95 (the `(let* ([latest (get-latest-speculation-failure)] ...))` block)

**Tier 2 — `union-exhaustion-error` struct + format-error rendering (errors.rkt)**:

- Struct (lines 115-116): `(prologos-error srcloc message) + (branches branch-mismatches expr-str derivation-chain)`
- `derivation-chain` field type: `(listof (listof string))` per docstring at 112-114
- `format-error` rendering (lines 267-287): iterates per-branch `chain`; inner iteration checks `(string-prefix? step "[diagnosis]")` — **assumes step is STRING**. Field type flip to `(listof derivation-chain)` BREAKS this inner iteration; coordinated format-error update is REQUIRED.
- Consumer enumeration via grep — Q-B.2 breaking-change blast radius:
  - 1 producer (typing-errors.rkt:98)
  - 1 format-error pattern (errors.rkt:267)
  - ~10 test assertion sites: `test-provenance-errors.rkt` (7+ sites) + `test-speculation-bridge.rkt` (6+ sites) + `test-gde-errors.rkt` (2 sites)
  - 1 test constructor (`test-provenance-errors.rkt:142`)
  - **ZERO LSP / external consumers** (search clean)
- Field type flip scope: ~12-15 sites — small + well-contained

**Tier 3 — `build-derivation-chain` + speculation failure data (elab-speculation-bridge.rkt)**:

- `build-derivation-chain` (typing-errors.rkt:127-152) currently RICH:
  - Per-step `format-speculation-label` (translates `"union-branch-..."` → `"tried branch ..."`)
  - Nested sub-failures inlined as `"(also tried: X, Y)"`
  - ATMS conflict info appended via `format-atms-conflict` (uses `solver-state-explain-hypothesis`)
  - Context diagnosis appended via `format-context-diagnosis` (user annotations + minimal diagnoses)
- `speculation-failure` struct (elab-speculation-bridge.rkt:95): `(label hypothesis-id support-set sub-failures)` — TREE shape; `sub-failures` is itself a list of speculation-failures
- `get-latest-speculation-failure` (line 143): returns LATEST recorded failure or #f
- Available at check/err per branch: the speculation-failure for THIS branch's check (`latest`); its `sub-failures` field for nested speculation
- Mapping to 3C.a `derivation-step` struct is feasible BUT semantics differ:
  - On-network walk: `propagator-id` meaningful (dep-graph traversal); `srcloc` from install site
  - Sexp speculation: `propagator-id` has NO analog (recursive `check` call chain, not a propagator); `srcloc` not tracked per-failure; `label` is the closest "structural role" analog
  - **Resolution**: per-field semantics documented for both paradigms; `propagator-id=#f` + `srcloc=#f` graceful degradation for sexp-fed steps (per D-3C-7 existing pattern)

**Tier 4 — 3C.b substrate (cell-19) read access from sexp path**:

- Cell-19 = `union-derivation-chains-cell-id = (cell-id 19)` (propagator.rkt:784)
- Merge: `union-derivation-chains-merge` registered under `'hasheq-replace` (line 926)
- **Current value shape**: `(hasheq position derivation-chain)` — SINGLE chain per position (the 3C.b mechanism produces one walk filtered by union of branch-aids)
- 3C.b writer: `make-fork-chain-threshold-fire-fn` (typing-propagators.rkt:1346); per-fork threshold; reads cell-18 latch; on subset met → builds chain via wrapper → writes `(hasheq position chain)` to cell-19
- Read API for 3C.c: `(elab-cell-read net union-derivation-chains-cell-id)` → `(hasheq position ...)` → `(hash-ref ... position #f)`
- `(current-prop-net-box)` parameter pervasively used in production: ~30+ call sites across driver.rkt + macros.rkt + supporting modules — adding ONE more consumer (sexp check/err) is consistent with existing pattern
- `process-string/return-net` (driver.rkt:1510) already exposes net for TESTING (added at 3C.b.5.b)

**Tier 5 — `error-explanation.rkt` reuse plan for 3C.c**:

- Foundation (3C.a) provides:
  - `derivation-chain` + `derivation-step` (5-field) structs — **directly reusable**
  - `static-reverse-walk` primitive — **NOT directly applicable to sexp path** (speculation-failure tree is NOT in the propagator dep graph; lives in the `current-speculation-failures` parameter)
  - `derivation-chain-for/union-contradict` wrapper (3C.b) — **template for body shape**, but the input data and translation logic differ
  - `decode-aid-name` helper — **directly reusable** (sexp path also has aids via `speculation-failure-hypothesis-id`)
- Module currently imports `current-command-atms` (already wired in 3C.b.3) — sufficient for sexp-path ATMS access
- 3C.c adds dependency on `elab-speculation-bridge.rkt` for `speculation-failure` accessors — **NEW dep**; cycle check: error-explanation has zero dep on speculation today; elab-speculation-bridge doesn't depend on error-explanation; no cycle risk

**Tier 6 — Sexp + WS-mode dispatch paths (Q6.x finding RE-CONFIRMED)**:

- `process-string` (sexp, line 1461) and `process-string-ws` (WS, line 1556) BOTH parameterize `current-prop-net-box` identically
- Both route to `process-command` which calls `check/err` at driver.rkt:1234 for `def x : T := body`
- **Phase 3A's `process-fork-on-union` only fires for on-network typing** (via `type-map-write` → `maybe-emit-fork-on-union-request` writing cell-15)
- Annotated `def` body checking uses kernel `check` inside `with-speculative-rollback` — does NOT route through on-network typing
- **Cell-19 stays EMPTY for the dominant case (sexp annotated unions)** — Q6.x finding empirically verified at 3C.b.5.d probe artifact
- **3C.c lifts this state**: by adding sexp `check/err` as a SECOND WRITER to cell-19, cell-19 becomes authoritative for ALL union all-branch-contradict events regardless of which typing path detected them
- Q-C.5 (WS-mode coverage): automatic — both `process-string` and `process-string-ws` flow through `check/err`; both will write cell-19 post-3C.c

**Tier 7 — Test surfaces for 3C.c**:

- Existing axis `'union-inhabitation-all-fail` (test-elaboration-parity.rkt:483) — asserts on `"Unbound variable"` downstream symptom; does NOT assert on chain shape
- Skip-gated `'error-provenance-chain` (line 535) for Phase 11b non-union case
- `test-union-types-atms.rkt:724-799`: 4 axes for INFERRED-union path via synthetic E2E (cell-19 inspection via `make-test-fixture` + direct cell-15 write + `run-to-quiescence` + `net-cell-read`)
- `test-provenance-errors.rkt:81-312`: ~7 tests assert `(list? (union-exhaustion-error-derivation-chain ...))` — break under field type flip; require co-migration
- Test consumers shape changes mechanical: assertions updated to check struct shape (`derivation-chain?`) instead of list-of-string

#### §9.5.4.2 Vision-aligned framing (per user direction 2026-05-24)

User-articulated vision reframing during dialogue establishes the design center for 3C.c. The propagator network is itself the compiler ("Logos Hyperlattice Compiler" / LHC); the serialized `.pnet` is itself the language IR (PoC in experimental branch proves direct `.pnet` → LLVM lowering via a Zig scheduler). For world-class diagnostics, propagator network diagnostics will need to understand network traces natively. Eventually there should not be a sexp-IR to concern ourselves with.

**Design question reframe**: not "which source dominates today" but "what migration paths advance the LHC vision?"

The destination is:
- Cell-19 is the authoritative diagnostic store
- `static-reverse-walk` is the universal chain constructor
- `derivation-chain` struct is part of the PNET IR
- LSP and LHC consume cell-19 directly
- Sexp `check/err` is temporary scaffolding feeding the on-network store

**Migration trajectory** (cell-19 is the fixed point; writers come and go):

```
TODAY (post-3C.b):     cell-19 written by { 3C.b on-network handler }; authoritative for INFERRED unions only
3C.c (THIS PHASE):     cell-19 written by { 3C.b on-network handler, sexp check/err translator }; authoritative for ALL unions
PM 12:                 current-prop-net-box retires; cell access becomes structural (3C.c translator unchanged)
Track 4D:              sexp check retires; ALL union checking via on-network typing; sexp writer RETIRES
SH Track 1:            cell-19 + derivation-chain struct become part of PNET IR
SH Track 4:            LHC native runtime reads cell-19; static-reverse-walk is the diagnostic primitive
PPN 8 LSP:             LSP reads cell-19; serializes derivation-chain as LSP diagnostic
```

3C.c is the **inflection point**: before it, 3C.b's mechanism is validated-not-deployed (Q6.x empirical finding). After it, cell-19 is structurally authoritative even while sexp scaffolding still runs.

**PNET ABI seed scope (per user clarification 2026-05-24)**: the `derivation-chain` + `derivation-step` struct shape becomes part of the PNET ABI seed. Versioning + alternative serialization formats are revisited at TWO inflection points downstream:
- **SH Series** (working on serializing propagators alongside cells)
- **Post-PPN 7** (grammar serializations; versioned serializations; possibly Prologos-defined formats)

This frees 3C.c from over-engineering versioning NOW. Ship the structurally-honest shape today; trust the downstream gates.

#### §9.5.4.3 Audit-surfaced finding — Q-C.6 cell-19 ↔ field shape consistency (NEW)

The rigorous audit caught a structural tension the original Phase 3C.b mini-design did not surface:

- **Cell-19's shape (3C.b)**: `position → derivation-chain` (SINGLE chain per union position; aggregated walk filtered by union of branch-aids)
- **Q-B.2 lock on field shape**: `(listof derivation-chain)` (PER-BRANCH list of chains)

3C.b's wrapper `derivation-chain-for/union-contradict` returns one chain; the chain's steps may reference any branch's aids. The sexp path naturally produces PER-BRANCH chains (each branch independently speculatively-checked).

These shapes are structurally inconsistent.

| Option | Catalogue | Challenge | Adversarial |
|---|---|---|---|
| **(a) Align cell-19 to per-branch shape** — cell-19 value becomes `position → (listof derivation-chain)`; 3C.b's `make-fork-chain-threshold-fire-fn` adjusts to call wrapper N times (per branch-aid) producing per-branch list | Field shape ↔ cell shape consistent; rendering preserves per-branch nesting (matches today's UX); both paths produce same shape | Modifies 3C.b's writer slightly (small scope creep into closed Phase 3C.b); N walks per fork vs 1 (N× more work for on-network case, rare in production) | **Touching closed Phase 3C.b after VAG is scope creep — even if minor. But the alternative is preserving an inconsistency we just identified. The honest move: 3C.b VAG was performed WITHOUT surfacing this shape question; revisiting 3C.b minimally is CORRECTING A MISSED AUDIT, not scope creep. The "N walks vs 1 walk" cost is irrelevant for diagnostics — error paths are not hot paths. The work IS minimal: a few-line adjustment to call the wrapper iteratively. Adversarial pressure resolved via honest framing of the missed-audit-correction. |
| **(b) Field shape becomes singular `derivation-chain`** — revise Q-B.2 lock; field flips from `(listof (listof string))` to `derivation-chain`; format-error renders chain at end (one block) instead of per-branch nested | Aligns naturally with cell-19 (no 3C.b touch); minimal data | Changes user-facing rendering pattern; chain location moves from "nested under each branch" to "at end after branches" | **Per-branch ATTRIBUTION (which step belongs to which branch) is encoded in `assumption-ids`; format-error can reconstruct per-branch rendering by grouping at render time. The structural simplification is real; the rendering question is solvable downstream. Counter-adversarial: rendering deferred is rendering deferred. If we ship X.1 with end-block rendering and users prefer per-branch, we ship a worse UX. The per-branch rendering is what's tested in production. UX regression risk. |
| **(c) Check/err reshapes** — cell-19 stays singular; sexp produces per-branch via translator; check/err's writeback writes singular (flatten); read-back reshapes singular to per-branch list via aid grouping | Cell-19 unchanged | Multiple shape transformations between cell and field; ambiguity for on-network case (one step with multiple branch-aids: include in both? duplicate? drop?) | **Most complex; introduces shape-transformation logic that has to be UNDONE when format-error grows to natively consume single chains. Accumulates legacy at both layers. ✗ |

**Q-C.6 LOCKED LEAN: (a) align cell-19 to per-branch shape**. Reasons:
1. Preserves today's user-facing rendering (per-branch chain nesting)
2. Structural consistency between cell-19 and error field
3. Sexp path produces per-branch naturally; no shape transformation needed
4. 3C.b adjustment is small (a few-line iterative call to existing wrapper) and is honest correction of a missed audit, not scope creep
5. Future format-error refinement retains both rendering options (per-branch from data; alternate grouping deferred)

**3C.b adjustment scope**: `make-fork-chain-threshold-fire-fn` (typing-propagators.rkt:1346) — replace single-chain build with iterative per-branch build:

```racket
;; BEFORE
(define chain (derivation-chain-for/union-contradict net branch-aid-set request-info))
(net-cell-write net union-derivation-chains-cell-id (hasheq position chain))

;; AFTER
(define per-branch-chains
  (for/list ([aid (in-set branch-aid-set)])
    (derivation-chain-for/union-contradict net (seteq aid) request-info)))
(net-cell-write net union-derivation-chains-cell-id
                (hasheq position per-branch-chains))
```

3C.b's existing tests (4 axes in test-union-types-atms.rkt:724-799) require updates: assert on `(listof derivation-chain)` instead of `derivation-chain`.

#### §9.5.4.4 Resolved design questions (Q-C.1-6) — locked via 3-column adversarial

| Q | Question | Locked Lean | Rationale |
|---|---|---|---|
| **Q-C.1** | Bridge strategy: how does check/err produce the chain? | **(f) Cell-19 is authoritative store; both sexp `check/err` and on-network 3C.b write to it via direct `net-cell-write` (no propagator wrapper); check/err reads back its own write for the error field** | Vision-aligned multi-writer scaffolding. Cell-19 is fixed point. Direct write (not propagator wrapper) per user direction — pretending sexp is a propagator when it isn't sets a bad precedent. |
| **Q-C.2** | When cell-19 is empty, what does 3C.c return? | **DISSOLVED** — cell-19 is always written by check/err for sexp union check failures (per Q-C.1 (f)); on-network 3C.b writes for inferred unions | New framing eliminates the question. |
| **Q-C.3** | Coordinated field type change timing | **(α) Atomic flip at 3C.c** — `(listof (listof string))` → `(listof derivation-chain)` per Q-B.2 spec | Coordinated with format-error update. Struct shape becomes PNET ABI seed (versioned at SH + post-PPN-7 per §9.5.4.2). |
| **Q-C.4** | format-error update — 3C.c or 3C.d? | **(a) In 3C.c, atomic with field flip** | Otherwise broken intermediate state. format-error gains structured rendering with on-network state queries for ATMS conflicts + diagnoses (preserves today's richness while decomplecting construction from rendering). |
| **Q-C.5** | WS-mode coverage post-3C.c | **(a) Automatic** — both `process-string` and `process-string-ws` parameterize `current-prop-net-box` identically; both flow through check/err; both write cell-19 | Verified at Tier 6 audit. |
| **Q-C.6** | Cell-19 ↔ field shape consistency (NEW from audit) | **(a) Align cell-19 to per-branch shape** — cell-19 value becomes `position → (listof derivation-chain)`; 3C.b's writer adjusts iteratively | Per §9.5.4.3 — corrects a missed audit point in 3C.b VAG. |

**Adversarial framing on multi-writer scaffolding (per Pressure 2)**: per user direction 2026-05-24, this is the reality we have to deal with until propagator-diagnostic-native typing replaces sexp `check/err`. The two-writer state is named scaffolding with retirement target (Track 4D). The mantra-aligned aspect: cell-19 IS the single source of truth (CRDT-like store); writers are temporary; readers see the cell. The mantra-violating aspect: sexp `check/err` is not a propagator and shouldn't be made to pretend otherwise (per Pressure 3 user direction). Documented honestly; retirement target explicit; no rationalization.

**Adversarial framing on `propagator-id` field for sexp-fed steps (per Pressure 2)**: `propagator-id=#f` for sexp-fed steps is graceful degradation per existing D-3C-7 documentation. Post-Track-4D, always populated. Document at chain construction site. Alternative (c) — rename field — deferred to Phase 11b broader refactor.

**Adversarial framing on lost richness from `build-derivation-chain` (per Pressure 3)**: STRUCTURAL IMPROVEMENT, not regression. Today `build-derivation-chain` BAKES formatting into strings; chain IS strings. Post-3C.c the chain is structured data; format-error queries `solver-state-explain-hypothesis` + `solver-state-minimal-diagnoses` at RENDER TIME to produce the rich text. Same data; transformation moves from construction-time to render-time. Decomplection: chain construction stays pure; chain rendering is the formatter's concern. LSP/LHC consumers gain restructurable data.

#### §9.5.4.5 Implementation sketch

**3C.c.1 — Translator in `error-explanation.rkt`** (~80 LoC):

**(Revised per §9.5.4.5.1 post-persistence audit discovery 2026-05-24 — translator input shape locked (α) sub-failures.)**

```racket
;; PPN 4C Phase 3C.c.1 (2026-05-24): sexp-mode translator wrapper.
;; SEXP-MODE TRANSLATOR — scaffolding; retires at Track 4D when sexp typing
;; unifies into on-network typing per Attribute Grammar Substrate vision.
;;
;; Direct parallel to current build-derivation-chain (typing-errors.rkt:127)
;; signature shape: takes sub-failures (LIST of speculation-failure children
;; of the latest speculation-failure at this branch's check). Returns
;; derivation-chain struct.
;;
;; Per audit discovery (§9.5.4.5.1): translator takes sub-failures (α) to
;; preserve UX parity with current build-derivation-chain for atomic checks
;; (no spammy "because: union-branch-X" redundancy with "tried X" line).
;; Richness lands automatically for nested speculation scenarios (where
;; sub-failures populates). For atomic Q6.x case, chain is empty (matches
;; today's UX byte-for-byte); for nested case, chain captures the speculation
;; tree as structured data.
;;
;; Field mapping per speculation-failure → derivation-step (§9.5.4.1 Tier 3):
;;   propagator-id    — #f (sexp speculation has no propagator)
;;   srcloc           — #f (speculation-failure doesn't track srcloc;
;;                          Phase 11b / Track 4D adds srcloc tracking —
;;                          D-3C.c-1 capture)
;;   assumption-ids   — (list hypothesis-id) from speculation-failure (or '()
;;                      when hypothesis-id is #f, which would only arise for
;;                      direct record-speculation-failure! callers without
;;                      with-speculative-rollback)
;;   assumption-names — decoded via decode-aid-name (3C.b.3 helper); per audit
;;                      at elab-speculation-bridge.rkt:213-217 with-speculative-
;;                      rollback uses label STRING as assumption-datum →
;;                      decode-aid-name returns it via string-datum preference;
;;                      fallback to speculation-failure-label when no aid
;;   residual-cost    — #f (3C.d may populate via tropical-quantale annotation)
;;
;; ATMS access via current-command-atms (same as 3C.b.3); defensive on #f.
(define (derivation-chain-for/union-check sub-failures)
  (cond
    [(or (not sub-failures) (null? sub-failures)) (derivation-chain '())]
    [else
     (define atms-box (current-command-atms))
     (define assumptions
       (cond [atms-box (solver-state-assumptions (unbox atms-box))]
             [else (hasheq)]))
     (define (failure-to-step sf)
       (define hyp-id (speculation-failure-hypothesis-id sf))
       (define aids (if hyp-id (list hyp-id) '()))
       (define names
         (cond
           [(pair? aids)
            (for/list ([aid (in-list aids)])
              (decode-aid-name assumptions aid))]
           [else (list (speculation-failure-label sf))]))
       (derivation-step #f #f aids names #f))
     ;; DFS pre-order flatten across the sub-failures forest
     (define (collect sf)
       (cons (failure-to-step sf)
             (apply append
                    (map collect (speculation-failure-sub-failures sf)))))
     (derivation-chain
       (apply append (map collect sub-failures)))]))
```

#### §9.5.4.5.1 Post-persistence audit discovery — translator input shape (α vs β) [2026-05-24]

**Discovery context**: between §9.5.4 persistence (commit `c5678e29`) and 3C.c.1 implementation, a deeper read of `build-derivation-chain` (typing-errors.rkt:127-152) + `speculation-failure` accessor patterns (elab-speculation-bridge.rkt:131-134 + 200-372) revealed a semantic question the §9.5.4.5 sketch did not surface explicitly.

**Current `build-derivation-chain` semantic** (the function 3C.c retires for union case per Q9):
- Takes **`sub-failures`** (CHILDREN of the latest speculation-failure at this branch's check), NOT the branch failure itself
- For atomic union check (Q6.x scenario `"hello"` vs `Nat`): sub-failures = `'()` → chain = `'()` → no `because:` lines render
- For nested speculation (union within union, complex check chains): sub-failures populates → chain renders nested context

**Original §9.5.4.5 sketch took the branch failure itself** (would produce `because: union-branch-Nat` for atomic Q6.x — visible UX change adding info already present in the `tried Nat` line).

**Two options surfaced**:

| Option | Semantic | Q6.x UX | Richness lands | Symmetry with retired function |
|---|---|---|---|---|
| **(α) Takes `sub-failures`** | chain = nested speculation steps only | UNCHANGED — no `because:` lines for atomic (matches today byte-for-byte) | For NESTED scenarios (union within union; complex user-annotated conflicts) | Direct parallel: same input shape as retired `build-derivation-chain` |
| **(β) Takes branch `failure`** | chain = branch step + nested sub-failures | CHANGED — `because: union-branch-X` line under each `tried X` | For atomic AND nested — every branch gets ≥1 chain step | Different input shape; deliberate divergence |

**3-column adversarial framing**:

| Option | Catalogue | Challenge | Adversarial |
|---|---|---|---|
| **(α) sub-failures** | Preserves UX exactly; no spammy redundancy; direct parallel with retired function; honest about what 3C.c delivers (infrastructure + nested-case richness) | Q6.x has no visible UX improvement → "shipped infrastructure with no Q6.x user impact" optics; codification "first user-facing instance of Propagator-First Diagnostics" weakens to "first user-facing INFRASTRUCTURE instance" | **Q6.x is atomic; atomic cases inherently have nothing to add. The branch identity is ALREADY visible in `tried X`. Repeating it is redundancy, not richness. The honest framing: 3C.c delivers struct-shape + cell-19 authoritative + decomplected rendering for the dominant case; richness lands structurally where it can. Validates via NESTED scenario test (audit-driven scope expansion — captures real richness, not redundant labels). Forces honest validation; better test discipline. |
| **(β) branch failure** | Every branch contributes ≥1 chain step (structural consistency); Q6.x has visible UX change (proves something happened) | Repeats the branch identity in two places (the `tried X` line AND `because: union-branch-X`); visual noise for atomic case; ranges into "diagnostic looks spammy" criticism | **Synthetic richness — adds output lines that carry NO new information for atomic case. Structural data (chain has aid for downstream consumers like LSP) is the only real value, but achievable under (α) too via the field-shape flip (empty chains are still structured `derivation-chain` instances, not empty list-of-string). The "UX change proves something" argument is theater — proving via false-positive richness is worse than honest "no atomic-case UX change; nested-case richness is the deliverable." |

**LOCKED LEAN: (α) sub-failures**. Per user direction 2026-05-24 dialogue.

**Rationale anchored at design level**:
1. UX parity with current `build-derivation-chain` for atomic cases — no regression, no spammy additions
2. Direct API parallel — `derivation-chain-for/union-check` takes the same input shape as the retired function; cleaner retirement story (replace function shape, not change shape)
3. Honest framing of 3C.c deliverable: INFRASTRUCTURE for atomic + RICHNESS structurally inherited for nested
4. Better test discipline — atomic Q6.x verbatim acceptance verifies the field-shape-flip + cell-19 write; NESTED scenario verifies the richness path

**Implications**:
- §9.5.4.5 translator sketch revised (above) — function takes `sub-failures` list
- §9.5.4.7 acceptance criterion revised — atomic Q6.x output IDENTICAL to pre-3C.c byte-for-byte; STRUCTURAL change verified via field type assertion; RICHNESS validation requires nested scenario
- §9.5.4.6 sub-phase partition unchanged in shape but 3C.c.6 scope expands to include nested-scenario acceptance test
- D-3C.c-10 (NEW drift risk) captured below at §9.5.4.8 — "synthetic richness temptation"

**Methodology lesson (1 data point — watching list)**: post-mini-design-persistence audit can surface semantic questions that mini-design-time audit missed. The discipline of "implementation pause to verify the sketch matches the function being retired" caught this before 3C.c.1 code landed. Codification candidate at 2nd data point: "Translator-mirror-of-retired-function discipline — when retiring function F via replacement F', verify F' takes the same input shape as F UNLESS a deliberate semantic divergence is named and justified."

#### §9.5.4.5.2 Continuing implementation sketch

**3C.c.2 — 3C.b per-branch-split adjustment** (~10-15 LoC + test re-validation):

`make-fork-chain-threshold-fire-fn` (typing-propagators.rkt:1346) replaces single-chain write with per-branch iterative write (per §9.5.4.3). Existing 3C.b tests (4 axes in test-union-types-atms.rkt) updated to assert `(listof derivation-chain)` shape.

**3C.c.3 — `check/err` integration** (~50 LoC across typing-errors.rkt + driver-side `current-prop-net-box` capture):

Union path (lines 69-104) replaced. Per-branch loop builds chain via `derivation-chain-for/union-check`; cell-19 written via `net-cell-write` on `(current-prop-net-box)`'s elab-network; `union-exhaustion-error` constructed with `(listof derivation-chain)` field.

```racket
;; Inside check/err union path (replaces lines 84-95 + 96-97):
[branch-info
 (for/list ([br (in-list branches)])
   (define ok?
     (with-speculative-rollback
       (lambda () (check ctx e br))
       values
       (format "union-branch-~a" (pp-expr br names))))
   (if ok?
       (list "matched" (derivation-chain '()))
       (let* ([latest (get-latest-speculation-failure)]
              [chain (derivation-chain-for/union-check latest)]
              [actual (infer ctx e)])
         (list (if (expr-error? actual) "<could not infer>" (pp-expr actual names))
               chain))))]
[branch-mismatches (map car branch-info)]
[branch-chains (map cadr branch-info)]
;; Write cell-19 (scaffolding — multi-writer with on-network 3C.b path)
(define net-box (current-prop-net-box))
(when net-box
  (set-box! net-box
    (elab-cell-write (unbox net-box)
                     union-derivation-chains-cell-id
                     (hasheq loc branch-chains))))
;; Construct error with per-branch chains
(union-exhaustion-error loc (pp-expr t names) branch-strs branch-mismatches
                        (pp-expr e names) branch-chains)
```

**Q-C.6 note**: cell-19 key shape is `position`. For sexp path, `position` proxy is `loc` (srcloc). For on-network path, `position` is the union expr's attribute-map position. The shapes are compatible at the `equal?` level. **D-3C.c-2 capture**: position-key shape divergence between paths; Track 4D unification resolves.

`build-derivation-chain`'s union-type path RETIRES (Q9 mandate); non-union path stays for `type-mismatch-error` use until Phase 11b.

**3C.c.4 — format-error update** (~30-50 LoC across errors.rkt):

```racket
;; format-error union-exhaustion-error case — handles derivation-chain struct
;; Renders per-branch as today; chain steps via decode-step-rendering helper.
;; ATMS conflicts + minimal diagnoses queried at RENDER TIME (decomplection
;; per §9.5.4.4 adversarial framing) — preserves today's richness.
[(union-exhaustion-error _ _ branches branch-mismatches expr-str chains)
 (string-join
  (append
   (list (format "error[E1006]: expression does not match any branch of union type")
         (format "  --> ~a" loc-str))
   (apply append
     (for/list ([br (in-list branches)]
                [mm (in-list branch-mismatches)]
                [chain (in-list chains)])
       (cons (format "  tried ~a — type mismatch (got: ~a)" br mm)
             (for/list ([step (in-list (derivation-chain-steps chain))])
               (format "    because: ~a" (format-derivation-step step))))))
   (list (format "  in expression: ~a" expr-str)
         (format "  = help: expression must match at least one branch of ~a" msg)))
  "\n")]

(define (format-derivation-step step)
  (define names (derivation-step-assumption-names step))
  (cond
    [(pair? names) (string-join names ", ")]
    [else "<unknown>"]))
```

**3C.c.5 — Test site updates** (~50 LoC across 3 test files):

- `test-provenance-errors.rkt`: ~7 assertions updated to check `derivation-chain?` structure instead of `list?` of strings
- `test-speculation-bridge.rkt`: assertions on `branches` + `branch-mismatches` unchanged (those fields not affected)
- `test-gde-errors.rkt`: ~2 assertions

**3C.c.6 — Acceptance criterion verification** (~30 LoC + verification artifact):

Re-run `examples/2026-05-22-3C-Q6x-probe.prologos` via `process-file`; assert post-3C.c error message matches §9.5.4.7 expected verbatim. Capture artifact at `data/probes/2026-05-24-3C-Q6x-post-3Cc.txt`.

#### §9.5.4.6 Sub-phase partition

| Sub-phase | Description | Est. LoC | Key gate |
|---|---|---|---|
| **3C.c.0** | mini-design + mini-audit persistence (this commit) | docs | §9.5.4 lands; Q-C.1-6 LOCKED |
| **3C.c.1** | `derivation-chain-for/union-check` translator in error-explanation.rkt + targeted tests | ~80 | Translator produces correct derivation-chain struct for synthetic speculation-failure input |
| **3C.c.2** | 3C.b per-branch-split adjustment — `make-fork-chain-threshold-fire-fn` iterative; cell-19 shape flips to per-branch list | ~10-15 + 3C.b test updates | 4 axes in test-union-types-atms.rkt re-pass with `(listof derivation-chain)` assertions |
| **3C.c.3** | `check/err` integration — replace union-path chain construction; write cell-19; field type flip atomic | ~50 | Q6.x probe scenario produces non-empty per-branch chains |
| **3C.c.4** | format-error update for `derivation-chain` struct + decomplected ATMS state queries | ~30-50 | User-facing message matches §9.5.4.7 expected verbatim |
| **3C.c.5** | Test site updates (~10 sites across 3 test files) | ~50 | All test files re-pass; no regressions |
| **3C.c.6** | E2E acceptance criterion verification — (a) Q6.x probe re-run + atomic verbatim match (rendered IDENTICAL to pre-3C.c per §9.5.4.7.1); (b) NEW nested scenario probe for richness validation (per §9.5.4.7.2; exact form selected at 3C.c.6 mini-design open via exploratory probe); (c) structural assertions on cell-19 + field type | ~30 + 2 probe artifacts | Atomic verbatim match (byte-for-byte) + nested chain contains ≥1 step per branch + cell-19 written |
| **3C.c-VAG** | Cumulative cross-sub-step adversarial 3-column VAG | docs | All 4 VAG questions PASS under adversarial framing; all D-3C.c-* drift risks verified cleared |

Estimated total: **~270 LoC + tests + docs**. Honest scope-up from §9.5.1.5 original ~80-150 LoC estimate due to (a) per-branch-split 3C.b adjustment (Q-C.6 finding), (b) format-error update with ATMS state queries (Q-C.4), (c) test site co-migration (Q-C.3 field type flip blast radius).

#### §9.5.4.7 Acceptance criterion — expected error message verbatim (D-3C-1 made operational; REVISED per §9.5.4.5.1)

**REVISED 2026-05-24** per §9.5.4.5.1 audit discovery: translator takes `sub-failures` (α lean); atomic Q6.x case has no UX change (chain remains empty matching today's `build-derivation-chain` semantic for atomic); richness validation requires nested scenario.

##### §9.5.4.7.1 Atomic Q6.x scenario — VERBATIM UX PARITY (no change)

Per §9.5.1.6 D-3C-1 (shape-without-benefit), pre-write the expected user-facing error message BEFORE implementation. For atomic scenarios under (α) sub-failures semantic, the rendered output is IDENTICAL to today byte-for-byte; the STRUCTURAL change is in the field shape only.

**Probe scenario** (`examples/2026-05-22-3C-Q6x-probe.prologos` scenario 1):

```prologos
(def x <Nat | Bool> "hello")
x
```

**Pre-3C.c output (from Q6.x baseline artifact `2026-05-22-3C-Q6x-baseline.txt`)**:

```
error[E1006]: expression does not match any branch of union type
  --> <unknown>:?:?
  tried Nat — type mismatch (got: String)
  tried Bool — type mismatch (got: String)
  in expression: "hello"
  = help: expression must match at least one branch of Nat | Bool
```

(`union-exhaustion-error.derivation-chain = '(() ())` — empty per Q6.x finding; no `because:` lines render because chain is empty.)

**Post-3C.c expected output**:

```
error[E1006]: expression does not match any branch of union type
  --> <unknown>:?:?
  tried Nat — type mismatch (got: String)
  tried Bool — type mismatch (got: String)
  in expression: "hello"
  = help: expression must match at least one branch of Nat | Bool
```

**IDENTICAL TO PRE-3C.c BYTE-FOR-BYTE.** Atomic checks have empty `sub-failures` lists → empty `derivation-chain` structs → format-error renders no `because:` lines.

**STRUCTURAL change** (not visible in rendered output but verifiable via inspection):
- Pre-3C.c: `union-exhaustion-error.derivation-chain` = `'(() ())` (empty list of empty string lists)
- Post-3C.c: `union-exhaustion-error.derivation-chain` = `(list (derivation-chain '()) (derivation-chain '()))` (list of empty derivation-chain structs)

Plus cell-19 written for the position with the same `(list (derivation-chain '()) (derivation-chain '()))` value.

**Acceptance assertion at 3C.c.6**: post-3C.c probe output IDENTICAL to baseline (string equality on rendered output); structural assertion via test that confirms `union-exhaustion-error-derivation-chain` returns list of `derivation-chain?` structs (not list of lists of strings).

##### §9.5.4.7.2 Nested scenario — RICHNESS VALIDATION (where chain actually populates)

Per §9.5.4.5.1 lean (α): richness lands when sub-failures populates (nested speculation). For 3C.c to demonstrate the richness path works end-to-end, we need a nested scenario where a branch's check itself triggers further speculation.

**Candidate nested scenario** (to be validated at 3C.c.6 mini-design — exact form depends on what speculation paths exist):

Option N1 — **Union within union** `(def x <<Nat | Bool> | String> 3.14)`:
- Outer branches: `<Nat | Bool>` and `String`
- Outer "tried <Nat | Bool>" branch's check triggers INNER union speculation for Nat and Bool
- Inner speculations recorded as sub-failures of the outer branch's speculation-failure
- Chain for the outer "tried <Nat | Bool>" branch should contain inner failure steps

Expected (sketch — exact strings depend on how nested speculation labels record):
```
error[E1006]: expression does not match any branch of union type
  --> <unknown>:?:?
  tried Nat | Bool — type mismatch (got: Rat)
    because: nested union left branch failed
    because: nested union right branch failed (?)
  tried String — type mismatch (got: Rat)
  in expression: 3.14
  = help: expression must match at least one branch of Nat | Bool | String
```

Option N2 — **User-annotated context that participates in conflict** (more rare; tests `format-context-diagnosis` path):
- `(def x : Nat := 0) (def y <Int | Bool> := x)` — but `x` is Nat; Nat <: Int succeeds; Bool fails
- Won't exhibit since Int branch succeeds
- More elaborate setup needed to trigger context-assumption conflict in chain

**3C.c.6 mini-design selects the final nested scenario** based on what speculation infrastructure actually does — exploratory probe at 3C.c.6 open determines whether N1 or N2 best exercises the richness path. Document the chosen scenario verbatim at 3C.c.6 close.

**Acceptance assertion at 3C.c.6**:
- Atomic Q6.x scenarios: rendered output byte-for-byte identical to pre-3C.c baseline
- Nested scenario(s): chain contains ≥1 `derivation-step` per branch with non-empty `assumption-names`; verbatim rendered output captured as new baseline `2026-05-24-3C-Q6x-post-3Cc-nested.txt`

**For complex scenarios with user annotations** (exercised in 3C.d's 4-axis tests but optionally previewed at 3C.c.6): format-error queries `solver-state-explain-hypothesis` for `conflicts with: ...` lines and `solver-state-minimal-diagnoses` for `[diagnosis] retract: ...` lines — preserves today's richness via render-time queries on on-network ATMS state.

##### §9.5.4.7.3 Acceptance criterion summary

| Scenario | Assertion | Pass condition |
|---|---|---|
| Atomic Q6.x (3 baseline scenarios) | Rendered output byte-for-byte identical to pre-3C.c | String equality with baseline artifact |
| Atomic Q6.x — structural | union-exhaustion-error-derivation-chain is `(listof derivation-chain?)` not `(listof (listof string))` | Type predicate check on field access |
| Atomic Q6.x — cell-19 write | Cell-19 hash contains per-position entry with `(listof derivation-chain?)` value | `(elab-cell-read net union-derivation-chains-cell-id)` returns hash with non-empty entry |
| Nested scenario | Chain contains ≥1 step per branch with populated `assumption-names` | Step-shape assertion + name-string check |
| Nested scenario — verbatim | Rendered output captured as new baseline | New artifact at `data/probes/2026-05-24-3C-Q6x-post-3Cc-nested.txt` |

#### §9.5.4.8 Drift risks named (D-3C.c-*)

| # | Risk | Mitigation |
|---|---|---|
| **D-3C.c-1** | sexp `speculation-failure` doesn't track srcloc; sexp-fed `derivation-step.srcloc = #f` for all steps | Graceful degradation per existing D-3C-7 pattern; document at translator API; Phase 11b or Track 4D enriches when speculation infrastructure gains srcloc tracking |
| **D-3C.c-2** | cell-19 key shape divergence — sexp path uses `loc` (srcloc) as position-key; on-network path uses attribute-map position; merge via `'hasheq-replace` may produce inconsistent reads if keys collide | `equal?` equality is well-defined for both srcloc and attribute-map positions; collision risk evaluated at 3C.c.3 mini-design — if real, introduce a tagged-position wrapper; Track 4D unification resolves structurally |
| **D-3C.c-3** | format-error ATMS state query at render time depends on `current-command-atms` being live; if error rendering happens post-command-close, ATMS may be retracted | Render at error-emission time (immediately at check/err return) when ATMS is live; defensive #f handling for post-close rendering produces graceful degradation |
| **D-3C.c-4** | Multi-writer scaffolding scope creep — temptation to make ALL error structs go through cell-19 pattern | LOCK 3C.c scope to `union-exhaustion-error.derivation-chain` ONLY; non-union `type-mismatch-error.provenance` is Phase 11b scope per Q9 |
| **D-3C.c-5** | 3C.b touch is scope creep | Per §9.5.4.3 — honest correction of missed-audit at 3C.b VAG; small adjustment; existing 3C.b tests verify the post-adjustment semantics |
| **D-3C.c-6** | Test site updates cascade — ~10 test sites + their assertions; risk of missing one and failing in CI | Grep at 3C.c.5 catches all consumers via `union-exhaustion-error-derivation-chain` accessor pattern; targeted run before full suite |
| **D-3C.c-7** | format-error rendering UX regression — chain rendering may look different than today even with same information | §9.5.4.7 verbatim acceptance criterion catches this structurally |
| **D-3C.c-8** | `build-derivation-chain` retirement scope ambiguity — non-union path stays; union path retires; ensure the retirement is at lines 70-104 specifically | 3C.c.3 mini-audit verifies the exact code path retired; non-union path at lines 105-118 stays untouched |
| **D-3C.c-9** | check/err writing to cell-19 from sexp violates "propagators write cells" intuition — could rationalize away as "but it's the existing parameter pattern" | Per user direction (Pressure 3): direct write is HONEST scaffolding; not pretending sexp is a propagator. Documented as scaffolding with Track 4D retirement target. Mantra-aligned at cell layer (single source of truth); mantra-violating at writer layer (sexp is not a propagator) — TEMPORARY until single-writer state achievable |
| **D-3C.c-10** (NEW per §9.5.4.5.1) | "Synthetic richness" temptation — include branch failure in chain (β lean) to make Q6.x atomic look like a UX improvement, when in reality the added `because:` line REPEATS info already in the `tried X` line | Locked LEAN (α) sub-failures per §9.5.4.5.1 + user direction 2026-05-24. Translator takes `sub-failures` (matches retired `build-derivation-chain` shape). Atomic UX UNCHANGED; nested case lands rich content structurally. Honest framing of deliverable scope. Adversarial framing applied IN-AUDIT (not post-hoc) — methodology working as designed. |

#### §9.5.4.9 Closure criteria

Phase 3C.c closes per Stage 4 Per-Phase Protocol + cross-sub-step VAG:

1. **Sub-phases 3C.c.1 through 3C.c.6 delivered** with each Stage 4 step completed in order (test coverage → commit → tracker → dailies → proceed)
2. **`union-exhaustion-error.derivation-chain` field POPULATED** for sexp-path union all-branch-contradict scenarios (Q6.x probe verifies)
3. **Cell-19 written by both sexp and on-network paths** — multi-writer scaffolding documented; retirement target named (Track 4D)
4. **Q-C.6 cell-19 shape aligned to per-branch** — 3C.b's writer adjusted; 3C.b's 4 axes re-pass
5. **format-error preserves diagnostic richness** — ATMS conflicts + minimal diagnoses rendered via on-network state queries at render time
6. **Q6.x probe acceptance** — post-3C.c probe output matches §9.5.4.7 expected verbatim
7. **`build-derivation-chain` union-type code path retired** (typing-errors.rkt:70-104 for union cases; non-union path unchanged)
8. **All 9 D-3C.c-* drift risks cleared** at 3C.c-VAG
9. **Full suite stable** within 109-115s baseline variance band (current 106.1s baseline)
10. **Adversarial 3-column VAG** passes 4 questions at Phase 3C.c close

#### §9.5.4.10 Cross-track captures (forward-pointers)

Per vision-aligned framing (§9.5.4.2), 3C.c is the first user-facing instance of Propagator-First Diagnostics. Cross-track captures:

1. **Phase 11b** (parent D.3 §6.1.1): extends `derivation-chain-for/union-check` pattern to general derivation diagnostics (non-union); adds srcloc tracking to speculation infrastructure (D-3C.c-1 closure)
2. **Track 4D** (Attribute Grammar Substrate Unification): sexp `check/err` retires; sexp writer to cell-19 retires; cell-19 written by unified on-network handler ONLY (single-writer state)
3. **PPN Track 8 LSP**: reads cell-19 + serializes `derivation-chain` as LSP diagnostic payload; rendering layer separable from chain construction (decomplection per §9.5.4.4 adversarial framing)
4. **SH Series Track 1** (`.pnet` network-as-value): cell-19 + `derivation-chain` struct become part of PNET IR for cross-session diagnostics
5. **SH Series Track 4** (LHC native runtime): cell-19 + `static-reverse-walk` + `derivation-chain` struct become part of LHC ABI; native diagnostic primitive interprets the struct directly
6. **PReduce Track 6** (speculative reduction): inherits emission pattern (stratum handler → chain emission); cost-bounded ATMS branching errors produce chains via the same primitive
7. **MASTER_ROADMAP.org**: surface "Propagator-First Diagnostics" framing in PPN 4C row description on next edit opportunity

**Codification graduation candidate (watching list, now at 2 data points across 3C.b + 3C.c — graduates at Phase 11b second consumer)**:

> **"Propagator-First Diagnostics"** — error reporting via on-network diagnostic store (cell-19 pattern) + static-walk primitive over propagator-firing graph is a load-bearing architectural shape for compiler-IS-network (LHC). Phase 3C.b shipped the substrate; Phase 3C.c shipped the first user-facing deployment via sexp-bridge multi-writer scaffolding. Codification GRADUATES from watching list to principle (DESIGN_PRINCIPLES.org § Propagator-First Diagnostics) when Phase 11b lands the second empirical consumer with non-union scope — mirrors Specialized Cell Type Framework graduation precedent.

#### §9.5.4.11 Status

**Phase 3C.c mini-design + mini-audit: ✅ PERSISTED** (commit `c5678e29`). Ready to enter Phase 3C.c.1 (translator implementation) following the conversational checkpoint cadence per workflow.md.

#### §9.5.4.12 Cross-references

- Phase 3C.b CLOSED: §9.5.3 + §9.5.3.10 (commit `449faac9`)
- Phase 3C parent mini-design: §9.5.1
- Phase 3C.a foundation: §9.5.2 (commit `1d803ed2`)
- Form C cross-reference (Phase 3C charter target): §9.5.A
- Q-B.2 lock (field type change): §9.5.1.4 + §9.5.3.5
- Q9 lock (REPLACE semantics, not supplement): §9.5.1.4
- Vision reframing source: user direction 2026-05-24 dialogue
- `derivation-chain-for/union-contradict` template: error-explanation.rkt:268
- 3C.b writer: typing-propagators.rkt:1346
- check/err integration target: typing-errors.rkt:64-118 (lines 70-104 retire for union case)
- format-error rendering: errors.rkt:267-287
- Q6.x baseline artifact: `data/probes/2026-05-22-3C-Q6x-baseline.txt`
- Q6.x post-3C.b artifact: `data/probes/2026-05-22-3C-Q6x-post-3Cb.txt`
- Process-string/return-net (test infrastructure): driver.rkt:1510
- speculation-failure struct: elab-speculation-bridge.rkt:95
- Workflow.md scaffolding-naming discipline: dailies §9.5.4.4 adversarial framing source

### §9.6 Phase 3V — Vision Alignment Gate (revised post-§9.3.1)

Per 4 VAG questions under adversarial 3-column framing (catalogue / challenge / adversarial):

- **On-network?** — branching via **in-place worldview tagging on shared carrier** (Realization B; NOT fork-prop-network); tagged-cell-value with bitmask filter; cell-15 (request) + cell-16 (contradiction) + worldview-cache narrowing. Unification primitives PURE (no integrated detection — OQ3). Residuation (Phase 3C) is read-time function on dep graph.
- **Complete?** — union types check end-to-end via non-committing inhabitation (OQ1); hypercube optimizations active (3B); error-explanation ships (3C). Parity axis revised to type-theoretic semantic. Q-A4 elab-speculation.rkt orchestrators retired.
- **Vision-advancing?** — non-committing inhabitation aligns with type theory (Castagna semantic subtyping; bidirectional check; Scala 3 hard unions; Typed Racket occurrence typing); Realization B is structurally simpler than fork-and-rejoin; mantra-aligned at multiple layers (all-at-once branch installation, all-in-parallel BSP rounds, structurally emergent via worldview filter, info-flow through tagged-cell-value cells, ON-NETWORK including stratum handlers); composes cleanly with future tracks (Phase 9b inherits N-ary pattern; Phase 3C residuation consumes cell-16 contradiction signal; Parent Phase 4 + PM 12 inherit on-network replacement for `with-speculative-rollback`).
- **Drift-risks-cleared?** — D-3A-bit-budget (≤30 bits gate; PERF-COUNTERS observability); D-3A-watcher-scope (audit at 3A.0); D-3A-filter-correctness (3A parity axis empirically validates); D-3A-meta-divergence (expected; diagnostic deferred to 3C); D-3A-recursion-safety (threshold-fire-once per (position, decomposition)). All named at §9.3.1.5.

### §9.7 Phase 3 termination arguments (revised — Level 1 under Realization B)

Original §9.7 (pre-§9.3.1) framed termination as Level 2 under fork-and-rejoin model. Under non-committing in-place Realization B (per OQ4), the termination story simplifies to **Level 1 (Tarski) across all components**:

| Component | Level | Measure |
|---|---|---|
| Fork-on-union request propagator (watches `:type` CLASSIFIER for `expr-union`) | **1 (Tarski)** | Fire-once per (position, union-decomposition) via threshold-fire; bounded by finite positions × finite expr-union structures per command |
| `process-fork-on-union` stratum handler (cell-15) | **1** | Bounded request entries per BSP round (finite per command) |
| Branch check propagators (per branch, per position) | **1 (Tarski)** | Finite cell value lattice + monotone tagged-cell-value entry accumulation under worldview filter |
| Branch contradiction watcher (B2-broadcast) | **1** | Threshold-fire; reads per active branch; finite branches × finite reads |
| `process-fork-contradiction` stratum handler (cell-16) | **1** | Monotone worldview-cache narrowing; bounded by branch count |
| Worldview-cache narrowing | **1 (Tarski)** | Monotone (bits only clear after fork-on-union firing); bounded by total aids per command (≤30 per OQ2 gate) |
| Gray-code traversal (Phase 3B) | finite | Finite permutation of finite branch set |
| Subcube pruning (Phase 3B) | finite | O(1) bitmask check per nogood |
| Residuation walk (Phase 3C) | finite | Finite dependency graph; one pass |
| Tropical fuel | Scheduler safety-net | Per-command budget bounds total propagator fires |
| **Overall** | **Level 1 with fuel safety-net** | Composition of finite bounds |

**Key insight (recorded for future tracks): Realization B is simpler than fork-and-rejoin for termination.** No cross-stratum well-founded measure needed — branches don't interact (worldview-filter isolates); worldview narrowing is monotone; no fixpoint feedback across forks. Phase 3A becomes Level 1 instead of Level 2.

**Conditional on worldview filter correctness** — Phase 3A's parity axis (`'union-inhabitation-fork`) empirically validates filter usage patterns specific to in-place tagging (multiple simultaneously-active branches at outer worldview after non-committing commit). 2A.c established precedent for retraction-axis filter validation; 3A extends.

**Note on meta divergence**: branches solving same meta to different values produces outer-worldview contradiction via tagged-cell-read's domain-merge (`compound-tagged-merge(type-unify-or-top)`). This is a STATIC error signal at outer wv (not termination concern). Diagnostic message clarity is Phase 3C scope.

**Phase 9b forward-compat**: γ hole-fill multi-candidate inherits Level 1 + bit-budget constraint. Large-N candidate handling deferred to 9b mini-design (D-9b-bit-budget; cross-phase capture per §9.3.1.7).

### §9.8 Phase 3 parity-test strategy (revised — type-theoretic semantics)

**Axes**:
- `'union-inhabitation-fork` (renamed from `'union-narrow-by-constraint` at `test-elaboration-parity.rkt:423`) — Phase 3A; type-theoretic non-committing semantic: classifier preserved as union after check; inhabitant matches synthesized type; multi-success branches coexist
- `'union-multi-success` (new) — Phase 3A; multiple branches succeed simultaneously; outer-wv read sees multi-tagged entries; classifier still union
- `'union-all-contradict-error` (new) — Phase 3A; all branches fail; outer-wv narrows to base; diagnostic surfaces (3C delivers full chain)
- `'union-meta-divergence` (new) — Phase 3A edge case: branches solve same meta to incompatible values → outer-wv contradiction via domain-merge (expected static signal)
- `'hypercube-structural-sharing` — Phase 3B; CHAMP reuse improvement under Gray code (microbench-backed)
- `'error-provenance-chain` — Phase 3C; `derivation-chain-for` output shape for all-branch-contradict (residuation walk via tropical-left-residual)

**Parity expectation revision** (Phase 3A.c scope): old `'union-narrow-by-constraint` test at line 423 of test-elaboration-parity.rkt was protecting a sexp implementation artifact (first-success commit). Renamed + revised:

```racket
;; OLD (pre-3A — preserved sexp first-success semantic):
(parity-test-skip 'union-narrow-by-constraint "Phase 10"
                  "let x := (the <Int | String> 0) in [eq? x 0]"
  (check-parity-equal? 'union-narrow-by-constraint
                       "let x := (the <Int | String> 0) in [eq? x 0]"
                       #:expected-type 'Int))

;; NEW (post-3A — type-theoretic non-committing semantic):
(parity-test 'union-inhabitation-fork
             "let x := (the <Int | String> 0) in [eq? x 0]"
  (check-parity-equal? 'union-inhabitation-fork
                       "let x := (the <Int | String> 0) in [eq? x 0]"
                       ;; x's classifier remains <Int | String>; narrowing happens
                       ;; via subsequent [eq? x 0] constraint propagation, not
                       ;; check-time commit. Exact expected value resolved at
                       ;; Phase 3A.c implementation (depends on Path T-3 subtype
                       ;; behavior for the integer literal under union annotation).
                       #:expected-behavior 'classifier-preserved-as-union))
```

The exact `#:expected-*` form will be resolved at Phase 3A.c implementation (depends on how subtype + non-committing interact for the specific literal). The PRINCIPLE is: classifier preserves union; narrowing is downstream of check.

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

## Cross-track inputs (running log)

This section captures cross-track findings that surface during PPN 4C's in-flight work and warrant consideration in the addendum design.

### From SRE Track 2I Phase 3+4 (2026-04-30)

The empirical sweep of algebraic properties on the type lattice ([SRE Track 2I design](2026-04-30_SRE_TRACK2I_SD_CHECKS_DESIGN.md) § Phase 3 Findings) produced a finding directly relevant to PPN 4C's compound-cell architecture and cross-context type propagation:

**The type lattice has structurally distinct sub-lattices with different algebraic postures**:
- *Ground sublattice* (atoms only — no binders, no metas): distributive, Heyting (per Track 2H decl).
- *Binder-included sublattice* (Pi/Sigma/lam types): SD but not distributive.

**Implications for PPN 4C scope** (consideration only — surfaced for design dialogue, not pulled into scope yet):

1. **Cross-context type propagation across binder boundaries** is a normal occurrence in elaboration. If we want propagators that exploit distributive-level optimizations (DNF canonicalization, Birkhoff representation, Heyting pseudo-complement) on ground-sublattice values, the dispatch needs scope-awareness — "this value is binder-typed, route through SD path; this value is ground, route through distributive/Heyting path."

2. **Property registry granularity gap**: current registry has booleans per (domain, relation). Cannot express "true on sub-lattice A, false on sub-lattice B." Either extend the registry to scope-tagged values, or distribute scope-awareness into per-value-shape dispatch at use sites. The former centralizes the discipline; the latter distributes it.

3. **Galois-bridge framing** (per SRE Lattice Lens question 4 + PTF §5.4): cross-domain bridges between sub-lattices at different algebraic levels are problematic — bridges compose well when both sides are at the same level. PPN 4C's compound-cell propagators that cross binder boundaries are exactly such cross-sub-lattice bridges. The Galois-connection view from Abstract Interpretation is the natural framing.

4. **The ground-vs-binder distinction may generalize**: similar shape likely applies to session lattice (ground vs phantom-typed) and form lattice (ground form vs nested-pipeline). Worth checking before any cross-sub-lattice mechanism lands.

**Status**: open consideration. May fold into existing Phase 1E (or sister phase) once PPN 4C's near-term scope settles, or may spawn a separate design cycle. Track 2I provides empirical validation of the F7 conjecture from Track 2H's design body; PPN 4C is the natural home for design work that responds to the validation.

## Document status

**Stage 3 Design D.3** — scope revised per Phase 1A mini-design audit finding (2026-04-21). Next: Phase 1A-i implementation (dead-code cleanup, ~30-50 LoC). Phase 1A-ii (elaborator-network.rkt migration) gets its own mini-design audit at phase start per Stage 4 methodology.
