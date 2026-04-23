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
| **T-3 COMPLETE** | — | ✅ | **DONE** 2026-04-22. 4 commits, staged A→B. Set-union merge live; contradiction signal preserved via Role A/B decomplection chain. Unblocks T-1, T-2, 1A-iii-a-wide Step 2. |
| Path T-1 | Speculation mechanism consolidation (correct-by-construction on worldview) | ⬜ UNBLOCKED | T-3 complete (`e07b809f`). Now ready: audit 4 `with-speculative-rollback` callers; many likely become unnecessary (set-union merge handles map-assoc type-incompatibility naturally). |
| Path T-2 | Map type inference open-world realignment | ⬜ UNBLOCKED | T-3 complete. `build-union-type` in typing-core.rkt:1196-1217 likely redundant (merge does it) OR migrate to `_` open-world per ergonomics design. |
| 1A-iii-a-wide | Type cell migration + union-inference adaptation + PU refactor | ⬜ UNBLOCKED | T-3 complete. Type cells already Role B (B6 migrated in Commit B). Step 2 PU refactor (4 per-domain universes + shared hasse-registry + elab-meta-read/write API) now ready. |
| 1A-iii-b | Tier 2: Deprecated `atms` struct + `atms-believed` + deprecated internal API retirement | ⬜ | Independent of Path T; can proceed in parallel |
| 1A-iii-c | Tier 3: Surface ATMS AST retirement (14-file pipeline) | ⬜ | Independent of Path T; can proceed in parallel |
| 1B | Tropical fuel primitive + SRE registration | ⬜ | |
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

Per Q-PU-1–Q-PU-5 resolutions.

**New infrastructure**:
1. **4 per-domain PU compound cells** allocated in `make-prop-network` or equivalent setup:
   - `type-meta-universe-cell-id` — value `(hasheq meta-id → tagged-cell-value-of-type)`, merge `compound-tagged-merge(type-lattice-merge)`, classification `'structural`
   - `mult-meta-universe-cell-id` — analogous, `mult-lattice-merge`
   - `level-meta-universe-cell-id` — analogous, `merge-meta-solve-identity`
   - `session-meta-universe-cell-id` — analogous, `merge-meta-solve-identity`

2. **`compound-tagged-merge`** merge-function factory — new (per Q-PU-1 Architecture B). Takes a domain-merge, returns a merge function for `(hasheq meta-id → tagged-cell-value)`. For each meta-id in the union of keys, merges per-meta tagged-cell-values via `make-tagged-merge(domain-merge)` at the base level. Zero propagation cost for untouched metas.

3. **Shared hasse-registry-handle** — one instance, used by reads across all 4 universes for worldview-bitmask subset check. Q_n subsume-fn specialized per `hasse-registry.rkt` lines 28-31 + 88.

**API migration**:
4. **`elab-meta-read enet meta-id domain`**, **`elab-meta-write enet meta-id domain value`** — new domain-parameterized meta-access API. Internally dispatches on `domain` to select the right universe cell-id.
5. **`elab-fresh-meta`** etc. now register meta-id in the universe cell (component initialization) instead of allocating new cells. Returns meta-id (no more cell-id per meta).
6. **`prop-meta-id->cell-id`** — retires OR returns universe-cell-id with meta-id as component-path component. Call sites updated.

**Call-site migration** across ~5-10 files:
- `solve-meta-core!` / `solve-meta-core-pure` in metavar-store.rkt
- `elab-cell-read` / `elab-cell-write` callers (propagator fire functions, typing-propagators.rkt, etc.)
- Propagator installations that reference meta cell-ids — update `:component-paths` declarations to `(cons universe-cell-id meta-id)`

**SRE registration for `'worldview` domain** (if not already registered) — provides Q_n lattice identity for hasse-registry's `:l-domain`.

**Deliverables**:
- 4 per-domain PU cells
- Shared hasse-registry-handle
- `elab-meta-read/write` API + call-site migration complete
- Propagator dependency indexing uses compound paths
- Pre-0 probe + acceptance file + full suite all pass post-step-2
- Cell count reduction: per-domain from N → 1 (~hundreds → 4 total cells for meta state)

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
