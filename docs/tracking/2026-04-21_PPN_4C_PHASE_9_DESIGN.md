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
| 1A-ii-b | Type cell migration + union-inference adaptation (pulled into 1A-iii scope) | ⬜ | Root cause: TMS dispatch at net-cell-write:1248 is load-bearing for union semantics (see 2026-04-19 dailies 2026-04-22 section) |
| 1A-iii | Retire TMS mechanism + `current-speculation-stack` + fallback paths + test-tms-cell.rkt + **type cell migration (1A-ii-b)** + **union-inference adaptation at typing-propagators.rkt:1878+** | ⬜ | Expanded scope per 1A-ii root-cause finding |
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

### §7.5 Phase 1A-iii deliverables (TMS mechanism retirement)

**Retirement targets**:
1. Delete `current-speculation-stack` parameter definition at `propagator.rkt:1621` and export at `:155`
2. Delete `tms-read`/`tms-write` fallback branches at `propagator.rkt:995` (net-cell-read), `:1251` (net-cell-write), `:3225` (net-cell-write-widen)
3. Delete `net-new-tms-cell` factory at `propagator.rkt:1593-1607`
4. Delete `tms-cell-value` struct (if nothing else references it post-1A-ii)
5. Delete `tms-read` / `tms-write` function definitions (if net-cell-read fallback is the sole consumer post-1A-ii)
6. Delete `tms-commit`, `merge-tms-cell`, `make-tms-merge` if their sole consumers were the retired mechanism
7. Update `test-tms-cell.rkt` (9 parameterize sites, lines 273-333) — rewrite tests to use `worldview-cache-cell-id` / `current-worldview-bitmask` semantics, OR retire entirely if redundant with `test-tagged-cell-value.rkt`

**Mini-design items at Phase 1A-iii start**:
- **Q-1A-3** (test-tms-cell.rkt disposition): rewrite, partial-retire, or full-retire. Depends on coverage analysis.
- Dependency grep: what else transitively depends on `tms-cell-value`, `tms-read`, `tms-write`, `tms-commit`, `merge-tms-cell`, `make-tms-merge` post-1A-ii? If anything unexpected, it becomes a follow-up migration target OR a scope expansion decision.
- **Q-1A-4** safety-net approach: use error-stub on `current-speculation-stack` for one commit to catch missed callers.

**Deliverables**:
- Full TMS-cell mechanism retired from production
- `current-speculation-stack` parameter deleted
- Fallback paths removed from `net-cell-read` / `net-cell-write` / `net-cell-write-widen`
- `test-tms-cell.rkt` resolved (per mini-design Q-1A-3)
- Affected-tests GREEN
- Lint suite clean
- Acceptance file clean via `process-file`

### §7.6 Phase 1B deliverables

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

### §7.7 Phase 1C deliverables

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

### §7.8 Phase 1V — Vision Alignment Gate

4 VAG questions per DESIGN_METHODOLOGY Step 5:
- **On-network?** — yes; substrate retired; tropical fuel lives in cells; primitive registered at SRE.
- **Complete?** — all retirement targets + primitive + canonical instance delivered.
- **Vision-advancing?** — substrate unified; tropical fuel enables cross-consumer cost reasoning.
- **Drift-risks-cleared?** — named in Phase 1 mini-design.

### §7.9 Phase 1 termination arguments

Per GÖDEL_COMPLETENESS Phase 1's new propagators/cells:
- Tropical fuel cell — Level 1 (Tarski fixpoint): finite lattice (bounded by budget or +∞); monotone merge (min); per-BSP-round cost accumulation bounded.
- Threshold propagator — Level 1: fires once at threshold (monotone; cost only increases); contradicts-or-no-op.
- No new strata added; no cross-stratum feedback; no well-founded measure needed.

### §7.10 Phase 1 parity-test strategy

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
