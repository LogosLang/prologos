# PPN Track 4C Addendum: Substrate + Orchestration Unification (Phases 1-3) — Design

**Date**: 2026-04-21
**Stage**: 3 — Design per [DESIGN_METHODOLOGY.org](principles/DESIGN_METHODOLOGY.org) Stage 3
**Version**: D.1 — initial draft, subject to iterative P/R/M/S critique
**Scope**: PPN 4C Phase 9+10+11 combined addendum (renumbered to Phase 1, 2, 3 for this addendum)
**Prior stages**:
- Stage 1 (research): [`docs/research/2026-04-21_TROPICAL_QUANTALE_RESEARCH.md`](../research/2026-04-21_TROPICAL_QUANTALE_RESEARCH.md) (commit `de357aa1`)
- Stage 2 (audit): [`docs/tracking/2026-04-21_PPN_4C_PHASE_9_AUDIT.md`](2026-04-21_PPN_4C_PHASE_9_AUDIT.md) (commits `62ce9f83`, `28208613`)

**Parent design**: [PPN 4C D.3](2026-04-17_PPN_TRACK4C_DESIGN.md). This addendum refines Phase 9+10+11 as a coherent sub-track; D.3 §6.7 (Phase 11), §6.10 (Phase 9+10), §6.11.3 (hypercube) are superseded by this document for implementation planning. D.3's Progress Tracker Phase 9 and Phase 11 rows point here.

---

## §1 Thesis and scope

### §1.1 Addendum thesis

PPN 4C's charter (D.3 §1) is to bring elaboration completely on-network. Phase 9+10+11 is the **substrate and orchestration unification chapter** of that charter. Three architectural moves, all instances of the same pattern ("unify the mechanisms"):

1. **Substrate**: retire legacy speculation-stack + migrate fuel-counter to tropical-quantale primitive, leaving one substrate story (bitmask worldview cell + per-propagator override + tropical fuel primitive)
2. **Orchestration**: retire the sequential `run-stratified-resolution-pure` in favor of BSP scheduler's uniform stratum iteration via `register-stratum-handler!`
3. **Features**: ship union types via ATMS branching (D.3 §6.10) atop the unified substrate + orchestration, exploiting already-implemented hypercube primitives (Gray code, Hamming, subcube-member?, tree-reduce)

### §1.2 Phase scope

**Phase 1 — Substrate reconciliation + tropical fuel primitive** (~300-500 LoC)
- Retire `current-speculation-stack` parameter + 3 fallback sites in propagator.rkt + 1 active `wrap-with-assumption-stack` in typing-propagators.rkt
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

**Total estimate**: 650-1150 LoC across 3 phases + their sub-phases.

### §1.3 Out of scope (explicit deferrals)

- **Deprecated `atms` struct retirement + `atms-believed` field** (Q-A3 resolution Option A): substrate reconciliation and ATMS API retirement are separable architectural concerns; ATMS retirement becomes a named future track. See §5.3 for detailed scope reasoning + deferral tracking.
- **Surface ATMS AST migration** (`expr-atms-*` forms in parser/elaborator/reduction/zonk): pipeline-wide change gated on the atms struct retirement; deferred alongside.
- **Phase 9b γ hole-fill propagator**: downstream consumer; interface specified here (§14), detailed design in Phase 9b's own cycle.
- **PReduce cost-guided rewriting**: future consumer of the tropical fuel primitive; out-of-scope design.
- **Self-hosted language-level surface for tropical quantale** (Polynomial Lawvere Logic, Rational Lawvere Logic per research §4.4): out of scope; infrastructure-only.
- **General residual solver** (BSP-LE Track 6 forward reference): out of scope; Phase 9+10+11 consumes BSP-LE 2B substrate without coupling to relational layer.

### §1.4 Relationship to PPN 4C D.3

This document is an addendum to D.3, not a replacement. D.3's Progress Tracker continues to own track-level state; the Phase 9 row and Phase 11 row point to this document. D.3 §6.10 (Phase 9 design text), §6.11.3 (hypercube), §6.15.6 (Phase 3+9 joint item), and §6.7 (Phase 11) are SUPERSEDED by this document for implementation planning — but retain their conceptual framing.

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

---

## §3 NTT Model — post-Phase-1-3 state

Per DESIGN_METHODOLOGY Stage 3 NTT Model Requirement, here is the NTT speculative syntax for the architectural substrate after Phase 1-3.

### §3.1 Tropical fuel primitive (Phase 1 delivery)

```ntt
;; Tropical fuel lattice (Lawvere quantale — research doc §4.3, §9.1)
type TropicalFuel := Nat | +inf
  :lattice :structural
  :properties '(Quantale Integral Residuated Commutative)
  :preserves [Join Tensor Residual]

;; Tropical merge = min-join on extended non-negative reals
spec tropical-fuel-merge TropicalFuel TropicalFuel -> TropicalFuel
defn tropical-fuel-merge
  | +inf   _   -> +inf
  | _      +inf -> +inf
  | a      b   -> (nat-min a b)

;; Canonical fuel cell factory (consumer-instantiable primitive)
spec net-new-tropical-fuel-cell
  :reads  []
  :writes [Cell TropicalFuel :init 0]
  PropNetwork Nat -> [PropNetwork * CellId]

;; Canonical budget cell factory (paired with fuel cell)
spec net-new-tropical-budget-cell
  :reads  []
  :writes [Cell TropicalFuel :init Budget]
  PropNetwork TropicalFuel -> [PropNetwork * CellId]

;; Threshold propagator (installed per fuel/budget pair)
propagator tropical-fuel-threshold
  :reads  [Cell TropicalFuel (at fuel-cid)
           Cell TropicalFuel (at budget-cid)]
  :writes [Cell Contradiction]
  :fires-once-at-threshold (ge? fuel-cost budget)
  fire-fn: if (ge? cost budget) then write-contradiction else net
```

### §3.2 Worldview substrate post-retirement (Phase 1 delivery)

```ntt
;; Post-Phase-1 worldview architecture: TWO LAYERS (not three paths)

;; Layer 1: on-network authoritative cell (unchanged from BSP-LE 2B)
cell worldview-cache
  :type Bitmask  ;; Q_n Boolean lattice
  :merge worldview-cache-merge  ;; equality-check replacement
  :cell-id 1

;; Layer 2: per-propagator override (parameter, scoped inside fire functions)
parameter current-worldview-bitmask :type Bitmask
  :default 0
  :scope fire-function

;; Retired: current-speculation-stack (legacy, Phase 1 retires)
;; Retired: tms-read/tms-write fallback paths in net-cell-read/write
```

### §3.3 Stratum handler topology post-unification (Phase 2 delivery)

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

### §3.4 Union-type branching via ATMS (Phase 3 delivery)

```ntt
;; Union type A | B elaboration via ATMS fork-on-⊕

;; Branching mechanism
propagator fork-on-union
  :reads  [(meta-pos :type)  ;; classifier cell (sees union)
           Cell Bitmask (at worldview-cache-cell-id)]
  :writes [Cell Assumption :tagged branch-a-aid
           Cell Assumption :tagged branch-b-aid
           Cell TropicalFuel (per-branch cost)]
  :fires-once-when (union-ctor-desc? classifier)
  fire-fn:
    let [a, b] = ctor-desc-decompose ⊕ classifier
    let aid-a = fresh-assumption-id
    let aid-b = fresh-assumption-id
    let branch-a = tag-worldview aid-a
    let branch-b = tag-worldview aid-b
    ;; Per-branch elaboration happens structurally via worldview-filtered reads
    ;; Cost accumulation via tropical fuel primitive per-branch

;; Gray-code branch traversal (Phase 3B integration)
spec traverse-branches
  :reads  [list-of-branches]
  :execution :gray-code-order
  ;; Successive branches differ by 1 assumption bit → O(affected cells) fork
  
;; Subcube pruning on nogood (Phase 3B integration)
spec prune-nogood-subcube
  :reads  [nogood-bitmask, worldview-bitmask]
  :predicate (= (bitwise-and wv ng) ng)
  ;; O(1) bitmask check; prunes whole subcube of worldviews containing nogood

;; Residuation-based error-explanation (Phase 3C)
spec derivation-chain-for
  :reads  [contradicting-cell, all-branches]
  :output ErrorChain
  ;; Backward-residuation walk on Module-Theoretic dependency graph
  ;; per research §10.3
```

### §3.5 NTT Observations

Per the NTT methodology "Observations" subsection requirement:

1. **Everything on-network?** Yes, with one fully-documented scaffolding: `current-worldview-bitmask` parameter remains as a per-fire-function override of the `worldview-cache` cell. Retirement plan: PM Track 12 (module loading on network), which migrates the scoping model. Not Phase 1-3 scope.

2. **Architectural impurities revealed by the NTT model?**
   - `tropical-fuel-threshold` requires `fires-once-at-threshold` behavior — NTT models this via `:fires-once-when`. Matches existing Phase 3c-iii residuation propagator pattern.
   - Fork-on-union propagator writes multiple tagged cells — reveals need for NTT's `:writes :tagged` syntax (not currently formalized). Persisted as NTT refinement candidate (deferred).
   - Tropical fuel primitive writes to multiple cells (cost + budget) — NTT models as two separate cell factories. Clean.

3. **NTT syntax gaps surfaced?**
   - `:writes :tagged branch-aid` — branch-tagging annotation for fork propagators. Flagged for NTT design resumption.
   - `:execution :gray-code-order` — execution-order annotation for branch traversal. Flagged.
   - `:preserves [Residual]` was already flagged in PPN 4C D.3 §15; confirmed relevant for tropical fuel.

4. **Components the NTT cannot express?** None at D.1 level. P/R/M/S critique (§10) may surface more.

---

## §4 Design Mantra Audit (Stage 0 gate)

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

**Findings**: all components satisfy mantra. `current-worldview-bitmask` parameter is scoped-inside-fire-fn scaffolding (§3.2 note), with retirement plan to PM Track 12.

---

## §5 Architectural decisions

Each architectural question (Q-A1 through Q-A8) gets an explicit resolution here, with lens justifications. Phase-specific decisions (Q-A3 ATMS retirement scope, Q-A6 residuation placement details) committed here as D.1 baseline, subject to phase mini-design refinement.

### §5.1 Q-A1 — Phase partitioning (RESOLVED 2026-04-21)

**Decision**: 3 phases, sequential, sub-phases labeled A-Z as needed. Phase names: 1 (substrate + tropical fuel), 2 (orchestration), 3 (union types + hypercube). Hypercube embedded in Phase 3 (not standalone) because primitives already implemented per audit §3.5.

**Lens justification**:
- **P (Principles)**: Decomplection — Phase 1 substrate, Phase 2 orchestration, Phase 3 features are separable. Most Generalizable Interface — Phase 1 substrate stabilizes first so 3 consumes.
- **R (Reality)**: Work-volume per audit §8.3 fits ~200-400 LoC per sub-phase at this partitioning.
- **M (Mindspace)**: dependency ordering is substrate → consumers; Phase 2 independent subsystem but sequenced for single-agent process constraint.
- **S (Structural)**: Hasse of sub-phase dependencies has 9A below 9C, 11 independent — 3 sub-phase partition captures this faithfully.

### §5.2 Q-A2 — Tropical fuel cell placement (RESOLVED 2026-04-21)

**Decision**: Option 3 with canonical instance. Substrate-level tropical quantale registered as SRE domain; primitive API for consumer instantiation; canonical BSP scheduler instance allocated in `make-prop-network` using the primitive.

**Concretely**:
- `'tropical-fuel` SRE domain (Tier 1) with tropical quantale properties
- `net-new-tropical-fuel-cell` + `net-new-tropical-budget-cell` + threshold propagator factory (primitive API)
- Canonical BSP instance at well-known cell-ids (fuel-cost = cell-id 11, budget = cell-id 12)
- Consumer instances (future PReduce, Phase 9b) allocate their own cells via primitive — no well-known IDs needed

**Lens justification**:
- **P**: First-Class by Default (primitive is reified); Decomplection (substrate algebra separated from consumer cell placement).
- **R**: Matches hasse-registry pattern (Phase 2b) + well-known cell-id pattern (substrate cells 0-10).
- **M**: Information flow via per-consumer cells, all consuming the same quantale algebra; cross-consumer reasoning via Galois bridges in quantale module theory.
- **S**: Module Theory — each fuel cell is a quantale-module over shared tropical quantale; cross-consumer cost queries are module morphisms. Research doc §6.5-§6.7 codifies this.

### §5.3 Q-A3 — Retirement scope for Phase 1

**Decision**: Option A — pure substrate retirement. ATMS retirement (deprecated struct + `atms-believed` + surface AST migration) deferred as its own future track.

**Scope IN Phase 1**:
- Retire `current-speculation-stack` parameter + 3 fallback read sites + 1 active `wrap-with-assumption-stack`
- Retire `prop-network-fuel` field + 15+ decrement/check sites
- Migrate both to substrate tropical fuel + worldview-bitmask-only flow

**Scope OUT Phase 1 (deferred)**:
- Deprecated `atms` struct
- `atms-believed` field (gated on struct retirement)
- Surface AST `expr-atms-*` forms (pipeline-wide migration)

**Deferral tracking**:
- Add to DEFERRED.md: "ATMS Retirement — post-PPN-4C Phase 1-3" with Q-A3 reasoning
- Future candidates for this work: dedicated ATMS retirement track, OR absorbed into BSP-LE general residual solver track when that lands
- BSP-LE 2B D.1 self-critique finding remains tracked; deferred alongside atms-believed

**Mini-design item for Phase 1 start**: grep for remaining internal consumers of deprecated ATMS API (atms-assume, atms-retract, atms-amb outside surface-AST evaluation). If any found, decide opportunistic-migrate vs leave-with-deferral.

**Lens justification**:
- **P**: Decomplection — substrate and ATMS API are separable concerns; Simplicity of Foundation — smaller sub-phase scope; Scope discipline per D.3 §1 charter.
- **R**: ATMS retirement is ~300-400 additional LoC (struct + pipeline); bundling expands Phase 1 substantially.
- **M**: Not a mindspace issue — both substrate and ATMS are architecturally defensible; decomplection drives separation.
- **S**: Module-theoretic — deprecated `atms` and modern `solver-context` are parallel module implementations; consolidation is a natural track but independent from substrate reconciliation.

### §5.4 Q-A4 — elab-speculation.rkt disposition

**Decision**: Retain and migrate to pure-bitmask semantics in Phase 3. Treat as library primitives for union-type ATMS branching.

**Rationale**: the file provides structured speculation API (`speculation-begin`, `speculation-try-branch`, `speculation-commit`, `speculate-first-success`) built on `solver-state`. Phase 3's union-type branching naturally consumes this — fork-on-union creates one branch per union component, tries each, commits the viable one. The API is designed for exactly this use case.

**Migration in Phase 3**:
- `speculation-try-branch` currently uses `branch-hypothesis-id` (assumption-id) and forked networks. Migrate to bitmask-first semantics (worldview-cache-cell-id writes, `current-worldview-bitmask` parameterize).
- Keep `speculation` / `branch` / `speculation-result` structs; they're natural descriptors.
- Make the file's tests actually exercise production paths by wiring union-type branching through this API.

**Lens justification**:
- **P**: Completeness Over Deferral — 189 lines of designed-API dead code is debt; migrate rather than delete.
- **R**: No production consumers today; tests exist; migration surface known.
- **M**: structured speculation API matches fork-on-union's operational shape.
- **S**: Module Theory — `speculation` struct is a container over `solver-state`; Phase 3 branching naturally maps onto it.

### §5.5 Q-A5 — atms-believed retirement timing

**Decision**: Coupled to Q-A3 Option A (deferred). `atms-believed` retires when the deprecated `atms` struct retires, which is future-track work.

**Rationale**: structural coupling — the field is used by the deprecated struct's methods; cannot retire independently.

### §5.6 Q-A6 — Residuation for error-explanation placement

**Decision**: Phase 3C (final sub-phase of Phase 3). Ships residuation-based error-explanation for all-branch-contradict case, leveraging union-type branching's structural information.

**Rationale**: union-type ATMS branching is exactly where residuation-based error-explanation has immediate applicability — when all branches contradict, the user deserves a principled "why" via the backward residual walk over the dependency graph (research §10.3, Module Theory §5).

**Scope**:
- `derivation-chain-for(contradicting-cell, all-branches)` helper (read-time, not propagator — per D.3 §6.1.1 M4 critique lean)
- Walks the propagator-firing dependency graph backward from contradiction
- Uses Phase 1.5 srcloc infrastructure + ATMS assumption tagging + `:trace :structural` mode
- Outputs both human-readable message + machine-readable structured chain

**What about non-union contradictions?** The mechanism generalizes, but Phase 3C ships it only for the union-type all-branch-contradict case. Broader applicability (fuel exhaustion, type contradictions in general) is Phase 11b (diagnostic infrastructure) territory — referenced but not duplicated here.

**Mini-design item for Phase 3C**: API signature for `derivation-chain-for` per Phase 11b cross-reference; human-readable vs machine-readable output format; LSP integration hooks (forward reference).

**Lens justification**:
- **P**: Completeness — union-type branching without error-explanation ships an incomplete experience; Correct-by-Construction — structural explanation from dependency graph is principled, not ad-hoc.
- **R**: Infrastructure already in place (ATMS assumption tags, source-loc registry, `:trace :structural` mode from Phase 1.5).
- **M**: Information flow — backward walk on existing dep graph, not new mechanism.
- **S**: Module Theory §5 — "backward chaining IS residuation" applies directly.

### §5.7 Q-A7 — Phase 4 β2 substrate contract

**Decision**: Specify the contract here (§13). Phase 4 β2 consumes:
- The tropical fuel primitive (meta-elaboration cost tracking optional)
- The `worldview-cache-cell-id` (meta entries bitmask-tagged per branch for ATMS speculation)
- `classify-inhabit-value` Module Theory Realization B tag-dispatch (already shipped in Phase 3 of PPN 4C)
- `solver-context` / `solver-state` API (no deprecated `atms` dependencies)

Phase 4 β2 does NOT consume:
- `current-speculation-stack` (retired by Phase 1)
- `prop-network-fuel` field (retired by Phase 1)
- Deprecated `atms` struct (retained for surface AST but not for β2)

### §5.8 Q-A8 — Phase 9b interface specification

**Decision**: HIGH-level specification in §14; detailed design owned by Phase 9b's own design cycle.

Phase 9b γ hole-fill consumes from Phase 1-3:
- Tagged-cell-value for multi-candidate ATMS branching (Phase 3 deliverable, on-network)
- Tropical fuel primitive (if γ wants cost-bounded hole-fill — optional)
- Phase 2b Hasse-registry primitive (from PPN 4C Phase 2b, already shipped)

---

## §6 Phase 1 — Substrate + Tropical Fuel

### §6.1 Scope and rationale

Phase 1 is the foundational sub-phase — retires legacy substrate (current-speculation-stack, prop-network-fuel counter) and ships the tropical fuel primitive that Phase 2, Phase 3, and downstream consumers build on.

### §6.2 Sub-phase partition

- **Phase 1A — Retire `current-speculation-stack` + fallback paths** (~100-150 LoC)
- **Phase 1B — Tropical fuel primitive + SRE registration** (~150-200 LoC)
- **Phase 1C — Migrate `prop-network-fuel` → canonical tropical fuel cell** (~100-200 LoC)
- **Phase 1V — Vision Alignment Gate**

### §6.3 Phase 1A deliverables

**Retirement targets** (per audit §3.1.5):
1. Delete `current-speculation-stack` parameter definition at `propagator.rkt:1621` and export at `:155`
2. Delete `tms-read`/`tms-write` fallback branches at `propagator.rkt:995` (net-cell-read), `:1251` (net-cell-write), `:3225` (net-cell-write-widen)
3. Delete `wrap-with-assumption-stack` helper in `typing-propagators.rkt:316-328`
4. Migrate its single active site (find during Phase 1A mini-design)
5. Delete comment-only references in `cell-ops.rkt:62, 103`
6. Update `test-tms-cell.rkt` (9 active parameterize sites, lines 273-333) — rewrite tests to use `worldview-cache-cell-id` or `current-worldview-bitmask`

**Deliverables**:
- All 6 retirement targets completed
- `tms-read`/`tms-write` functions themselves RETAIN (they're pure functions over stack argument; used internally by TMS cell mechanisms for parameter-free call sites)
- Affected-tests suite GREEN
- Per-phase regression: acceptance file clean via `process-file`

**Mini-design items for Phase 1A start**:
- Exact grep of `wrap-with-assumption-stack` call sites (1 known; confirm count)
- Decision: migrate or delete if single caller can be replaced by direct bitmask parameterize
- `test-tms-cell.rkt` rewrite: update to bitmask semantics OR retire if redundant with `test-tagged-cell-value.rkt`

### §6.4 Phase 1B deliverables

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

**Mini-design items for Phase 1B start**:
- Decision on API names (`net-new-tropical-fuel-cell` vs `net-new-fuel-cell` vs other)
- Decision on whether threshold propagator contradiction is separate cell or reuses `prop-network-contradiction`
- Representation: use Racket's `+inf.0` directly, or a sentinel like `'tropical-fuel-exhausted`? (Lean: `+inf.0` — native Racket representation, clean arithmetic)

### §6.5 Phase 1C deliverables

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

**Mini-design items for Phase 1C start**:
- A/B microbench: old decrement counter vs new cell-based min-merge. Target: performance-neutral (within 5% noise). If regression >5%, investigate before committing (per Post-Implementation Protocol).
- Decision: do the 15+ decrement sites all switch to cell writes, or can some be consolidated via the BSP scheduler writing fuel at round-end? (Lean: keep per-firing decrement for compatibility; scheduler writes aggregated cost per round.)

### §6.6 Phase 1V — Vision Alignment Gate

4 VAG questions per DESIGN_METHODOLOGY Step 5:
- **On-network?** — yes; substrate retired; tropical fuel lives in cells; primitive registered at SRE.
- **Complete?** — all retirement targets + primitive + canonical instance delivered; deferrals explicit.
- **Vision-advancing?** — substrate unified; tropical fuel enables cross-consumer cost reasoning.
- **Drift-risks-cleared?** — named in Phase 1 mini-design (audit; silent-write-drop; belt-and-suspenders).

### §6.7 Phase 1 termination arguments

Per GÖDEL_COMPLETENESS Phase 1's new propagators/cells:
- Tropical fuel cell — Level 1 (Tarski fixpoint): finite lattice (bounded by budget or +∞); monotone merge (min); per-BSP-round cost accumulation bounded.
- Threshold propagator — Level 1: fires once at threshold (monotone; cost only increases); contradicts-or-no-op.
- No new strata added; no cross-stratum feedback; no well-founded measure needed.

### §6.8 Phase 1 parity-test strategy

Axis: tropical-fuel parity (new axis). One-two tests confirming tropical fuel exhausts at same point as decrementing counter for representative workloads. Per D.3 §9.1 convention, wire into `test-elaboration-parity.rkt`.

---

## §7 Phase 2 — Orchestration Unification

### §7.1 Scope and rationale

Phase 2 consolidates the elaborator strata (S(-1) retraction, L1 readiness, L2 resolution) into BSP stratum handler registrations, retiring the sequential `run-stratified-resolution-pure` orchestrator. Architectural parallel to Phase 1: unify the mechanisms.

### §7.2 Sub-phase partition

- **Phase 2A — Register S(-1), L1, L2 as stratum handlers** (~75-125 LoC)
- **Phase 2B — Retire orchestrators** (~50-100 LoC)
- **Phase 2V — Vision Alignment Gate**

### §7.3 Phase 2A deliverables

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

**Mini-design items for Phase 2A start**:
- Exact cell-id allocation (13, 14, 15 proposed; confirm next available)
- Invariant: retraction-handler clears request set after processing (precedent: S1 NAF handler `net-cell-reset`)
- Decision: L1 / L2 may share a single request cell, OR separate for clarity. Lean: separate (explicit strata).

### §7.4 Phase 2B deliverables

1. Delete `run-stratified-resolution-pure` at `metavar-store.rkt:1915` (after confirming no test callers)
2. Delete `run-stratified-resolution!` at `metavar-store.rkt:1863` (dead code; R3 external critique finding)
3. Simplify the entry point at `metavar-store.rkt:1699` to rely on BSP scheduler outer loop
4. Clean up exports at `metavar-store.rkt:172, 218, 221-222`
5. Update performance-counters.rkt:137 reference

**Mini-design items for Phase 2B start**:
- A/B microbench: sequential orchestrator vs BSP-scheduler-iterated handlers. Target: performance-neutral.
- Decision: if scheduler iteration is slower, investigate tier grouping OR keep sequential internally but make it handler-registered (still unifies API)

### §7.5 Phase 2 termination arguments

- S(-1) retraction handler — Level 1: finite assumption set; narrowing only.
- L1 readiness handler — Level 1 (Tarski): pure scan, observation only.
- L2 resolution handler — Level 2 (well-founded): cross-stratum feedback decreases type depth (inherited from current implementation).
- BSP scheduler outer loop — finite because fuel-budgeted (Phase 1 tropical fuel).

### §7.6 Phase 2 parity-test strategy

Axis: orchestration parity. Confirm elaboration results identical pre-Phase-2 and post-Phase-2 for representative workloads. Parity tests wire into `test-elaboration-parity.rkt`.

---

## §8 Phase 3 — Union Types via ATMS + Hypercube Integration

### §8.1 Scope and rationale

Phase 3 ships union types via ATMS branching (D.3 §6.10), exploiting already-implemented hypercube primitives (audit §3.5) and residuation-based error-explanation (research §10.3, Q-A6 resolution).

### §8.2 Sub-phase partition

- **Phase 3A — Fork-on-union basic mechanism** (~100-150 LoC)
- **Phase 3B — Hypercube integration (Gray code, subcube pruning)** (~50-100 LoC)
- **Phase 3C — Residuation error-explanation** (~75-150 LoC)
- **Phase 3V — Vision Alignment Gate**

### §8.3 Phase 3A deliverables

1. Fork-on-union propagator: watches `:type` facet (classifier layer) per position; when classifier is a ⊕ compound, SRE ctor-desc decomposes into components
2. For each component: fresh assumption-id via ATMS, tag worldview, elaborate per-branch with worldview-filtered reads
3. Per-branch cost tracking: allocate per-branch fuel cell via tropical primitive (Phase 1 dependency)
4. Contradiction in branch → nogood on main network worldview-cache (S1 NAF handler pattern)
5. All branches contradict → fall through to error-explanation (Phase 3C)
6. Winning branch → commit (worldview narrows; tagged entries become authoritative)
7. Migrate `elab-speculation.rkt` to pure-bitmask semantics per Q-A4 resolution; wire union-type branching through its API
8. Tests (`tests/test-union-types-atms.rkt`): axis 7 parity (union branch elaboration)

**Mini-design items for Phase 3A start**:
- Decision: per-branch fuel cells use separate budget OR shared budget with per-branch cost accumulation into shared? (Lean: separate per-branch; cross-branch aggregation is future generalization)
- Decision: tagged cells for per-branch state — which cells promote to tagged-cell-value? (Follow `promote-cell-to-tagged` precedent from relations.rkt)
- Integration point: which elaboration function dispatches to fork-on-union? (Lean: `infer`/`check` dispatch recognizes union-classifier positions)

### §8.4 Phase 3B deliverables

Hypercube integration leveraging already-implemented primitives (audit §3.5):

1. Wire Gray-code branch ordering: replace naive branch enumeration with `gray-code-order` from `relations.rkt`
2. Benefit: successive forks differ by one assumption bit → CHAMP structural sharing maximized
3. Subcube pruning on contradictions: when branch X contradicts, writes nogood; subsequent branches containing the same nogood-bits skipped via `subcube-member?` check (already implemented in `decision-cell.rkt:368`)
4. Tests: performance + correctness (structural sharing benefit measurable via heartbeat counters)

**Mini-design items for Phase 3B start**:
- A/B microbench: Gray-code ordering vs naive ordering — target CHAMP-reuse improvement per hypercube addendum
- Decision: bitmask subcube representation — does 9-bit limit (2^9 = 512 worldviews) suffice, or extend to bitvector? Lean: 9-bit for Phase 3 (matches BSP-LE 2 decisions-state bitmask), bitvector as future extension

### §8.5 Phase 3C deliverables

Residuation-based error-explanation for all-branch-contradict:

1. New helper `derivation-chain-for(contradicting-cell, branches, net)` in dedicated module (e.g., `error-explanation.rkt`)
2. Read-time function (not propagator) — walks propagator-firing dependency graph backward from contradicting cell
3. Collects per-step: propagator-id, assumption-id, source-loc (from Phase 1.5 srcloc infrastructure)
4. Output: structured derivation chain + human-readable message
5. Integration: error message output at Phase 3A's all-branch-contradict fall-through
6. Tests (`tests/test-union-error-explanation.rkt`): axis error-provenance-chain per D.3 §9.1 Phase 11b row

**Mini-design items for Phase 3C start**:
- API signature: `derivation-chain-for` exact inputs/outputs (chain structure shape)
- Human-readable format: per-line, markdown, or structured JSON with renderer?
- LSP integration hooks: forward-reference for Phase 11 or PM Track 11

### §8.6 Phase 3V — Vision Alignment Gate

Per 4 VAG questions:
- **On-network?** — branching via fork-prop-network (O(1) CHAMP share); tagged-cell-value worldview; residuation via on-network dep graph.
- **Complete?** — union types work end-to-end; hypercube optimizations active; error-explanation ships.
- **Vision-advancing?** — union types via ATMS is exactly the Track 4B blocked feature; hypercube + tropical + ATMS compose naturally per Hyperlattice Conjecture.
- **Drift-risks-cleared?** — named at Phase 3 mini-design start.

### §8.7 Phase 3 termination arguments

- Fork-on-union propagator — Level 2: branch count bounded by union component count; per-branch cost-bounded via tropical fuel primitive.
- Gray-code traversal — finite permutation of finite branch set.
- Residuation walk — finite dependency graph; walk terminates when all deps traversed.

### §8.8 Phase 3 parity-test strategy

Axes: union (per D.3 §9.1); error-provenance-chain (added). Parity: pre-Phase-3 union-type elaboration currently fails (not supported); post-Phase-3 succeeds. Parity tests verify narrow-by-constraint cases (`<Int | String>` narrowed by `eq?` to `Int`) per D.3 §9 §9.1.

---

## §9 Tropical quantale — implementation details

(Consolidates the tropical-specific design across all three phases)

### §9.1 SRE domain registration

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

### §9.2 Primitive API

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

### §9.3 Canonical BSP scheduler instance

```racket
;; In make-prop-network (propagator.rkt)
(define-values (net1 fuel-cid) (net-new-tropical-fuel-cell base-net))
(define-values (net2 budget-cid) (net-new-tropical-budget-cell net1 fuel))
(define threshold-prop (make-tropical-fuel-threshold-propagator fuel-cid budget-cid))
(net-add-propagator net2 (list fuel-cid budget-cid) '() threshold-prop)
;; Export fuel-cost-cell-id = 11, fuel-budget-cell-id = 12
```

### §9.4 Migration of `prop-network-fuel` decrement sites

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

### §9.5 Residuation for error-explanation

Per research §10.3. When threshold propagator writes contradiction (fuel exhausted), the `derivation-chain-for` helper can be invoked (from Phase 3C) to walk backward. For pure fuel exhaustion (outside union-branching context), the chain is the sequence of propagators that consumed fuel — in order, with per-step costs. Production use: Phase 11b diagnostic.

Phase 1-3 ships `derivation-chain-for` for union-branch contradictions; broader applicability (pure fuel exhaustion, general type contradictions) is Phase 11b territory per Q-A6.

### §9.6 Future multi-quantale composition

Primitive API supports cross-consumer cost queries via shared quantale algebra (Module Theory §6.4 tensor products). Not shipped in Phase 1-3; primitive enables without requiring. Future PReduce or other tracks can allocate their own fuel cells and reason about combined costs via quantale morphisms.

---

## §10 P/R/M/S Self-Critique

Applied inline during decision-making; consolidated here per DESIGN_METHODOLOGY Stage 3 requirement.

### §10.1 P — Principles challenged

Decisions reviewed against the 10 load-bearing principles:

| Decision | Principle served | Potential conflict | Resolved? |
|---|---|---|---|
| Substrate-level tropical fuel primitive (Q-A2) | Most Generalizable Interface, First-Class by Default | — | ✓ |
| Option A retirement scope (Q-A3) | Decomplection, Simplicity of Foundation | Completeness — ATMS retirement defers | ✓ deferred tracking explicit |
| Retain + migrate `elab-speculation.rkt` (Q-A4) | Completeness Over Deferral | — | ✓ |
| Residuation in Phase 3C (Q-A6) | Completeness, Correct-by-Construction | — | ✓ |
| 3-phase sequential partition (Q-A1) | Decomplection | "all in parallel" mantra — not a process concern | ✓ (per user clarification) |

**Red-flag scrutiny**: no "temporary bridge," "belt-and-suspenders," "pragmatic shortcut" in Phase 1-3 scope. Deferrals (ATMS retirement) are explicit with tracking.

### §10.2 R — Reality check (code audit)

Audit §3 (Stage 2) grounded the design in concrete code. Highlights:
- Q-A3 Option A justified by audit §3.3 (surface AST migration is pipeline-wide)
- Q-A6 Phase 3C placement justified by audit §3.6 (union-type infrastructure 90% in place)
- Phase 2 scope matches audit §3.9 findings (3 strata, 1 orchestrator to retire)
- Phase 1C migration sites count matches audit §3.8 (15+ `prop-network-fuel` sites)

Scope claims tied to grep-backed audit data; no speculation floats above the codebase.

### §10.3 M — Propagator mindspace

Design mantra check (§4) passed for all components. Highlights:
- Tropical fuel cell: pure cell-based, merge via `min`; no hidden state
- Threshold propagator: fires once at threshold; monotone
- Fork-on-union: all-at-once decomposition via ctor-desc; per-branch elaboration structurally emergent
- Gray-code ordering: structural hypercube adjacency, not imposed
- Subcube pruning: O(1) bitmask check, not scan
- Residuation chain: read-time walk on existing dep graph; not new propagator

No "scan" / "walk" / "iterate" in propagator design (all operations are cell reads/writes or structural decomposition).

### §10.4 S — SRE Structural Thinking (new lens)

PUnify, SRE, Hyperlattice/Hasse, Module-theoretic, Algebraic-structure-on-lattices applied:

**PUnify**:
- Per-branch union elaboration invokes `unify-union-components` (audit §3.6); reuses existing PUnify infrastructure (research doc §6.4)
- No new unification algorithm

**SRE**:
- Tropical fuel is an SRE-registered domain (§9.1); property inference runs at registration
- Union-type branching uses SRE ctor-desc decomposition (D.3 §6.10); no hand-rolled pattern matcher

**Hyperlattice / Hasse**:
- Worldview lattice IS Q_n hypercube; Gray code + subcube pruning exploit this structural identity
- Phase 2's stratum handler topology Hasse: 9 handlers in 2 tiers, BSP scheduler iterates uniformly

**Module theoretic**:
- Cells are Q-modules (research §6.5); propagators are Q-module morphisms
- Tropical fuel cell is a trivial 1-dim tropical-quantale module
- Cross-consumer fuel cells compose via quantale tensor products

**Algebraic structure on lattices**:
- Tropical quantale registered with full property declaration (Quantale, Integral, Residuated, Commutative)
- Residuation native (research §5.1, §9.3); error-explanation uses the quantale residual
- TypeFacet quantale (SRE 2H) + tropical fuel quantale compose via Galois bridges (future work; primitive enables)

---

## §11 Parity test skeleton

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

## §12 Termination arguments

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

## §13 Phase 4 β2 substrate contract

Per Q-A7 resolution. Phase 4 (PPN 4C CHAMP retirement with β2 scope — attribute-map becomes sole meta store) consumes from Phase 1-3 the following:

**Consumes (read-only or read-write per-meta)**:
- `worldview-cache-cell-id` + per-propagator `current-worldview-bitmask` (for meta worldview-tagging)
- Tropical fuel primitive (optional — if per-meta elaboration cost tracking desired; not required)
- `classify-inhabit-value` Module Theory Realization B tag-dispatch (already shipped Phase 3 of PPN 4C)
- `solver-context` / `solver-state` (modern ATMS API)
- Phase 2 stratum handler substrate (if meta-specific stratification desired; not required)

**Does NOT consume (retired by Phase 1-3)**:
- `current-speculation-stack` (retired Phase 1)
- `prop-network-fuel` field (retired Phase 1C)
- Deprecated `atms` struct (retained but β2 uses modern API only)

**Invariants Phase 1-3 guarantees for Phase 4**:
- Substrate worldview bitmask read/write is stable and cell-based
- Tropical fuel primitive API is stable (mini-design for Phase 4 may decide per-meta instance allocation)
- Stratum handler API is stable post-Phase-2
- Union-type ATMS branching (Phase 3) supports meta-level union types (per-meta classifier may be a union)

**Mini-design items for Phase 4 start**:
- Decision: per-meta fuel tracking (via primitive) or inherit canonical BSP fuel?
- Decision: meta-specific stratum handler (if any) or reuse existing strata?

---

## §14 Phase 9b interface specification

Per Q-A8 resolution. Phase 9b γ hole-fill propagator (D.3 §6.2.1, §6.10) consumes from Phase 1-3:

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

## §15 Open questions — mini-design scope (not blockers)

Per user direction: phase-specific questions deferred to mini-design at phase start. Listed here for traceability; each question has its mini-design trigger point.

### §15.1 Phase 1 mini-design items
- Option A retirement scope: grep remaining internal ATMS consumers; decide opportunistic migrate or leave
- API naming for tropical fuel primitive
- Representation: `+inf.0` vs sentinel for fuel-exhausted
- `wrap-with-assumption-stack` migration: single caller replacement strategy
- A/B microbench: decrement counter vs min-merge cell (fuel cost migration)

### §15.2 Phase 2 mini-design items
- Request cell-id allocation (13, 14, 15 proposed; confirm next available)
- Retraction handler request-clearing invariant
- L1 / L2 shared cell vs separate cells
- A/B microbench: sequential orchestrator vs BSP-iterated handlers

### §15.3 Phase 3 mini-design items
- Per-branch fuel: separate budget vs shared
- Cell-to-tagged promotion discipline
- `infer`/`check` dispatch integration point for union fork
- Bitmask subcube: 9-bit vs bitvector
- `derivation-chain-for` API signature + output format
- LSP integration hooks (forward ref)

### §15.4 Cross-phase (all)
- Drift risks per phase (named at phase start per VAG step 5d)
- Parity test detailed cases per axis

---

## §16 Progress tracker

Per DESIGN_METHODOLOGY Stage 3 requirement. Initial state:

| Phase | Description | Status | Notes |
|---|---|---|---|
| Stage 1 | Research doc | ✅ | commit `de357aa1` |
| Stage 2 | Audit doc | ✅ | commits `62ce9f83`, `28208613` |
| Stage 3 | Design doc (this) | 🔄 D.1 | Iterating via P/R/M/S |
| 0 | Acceptance file + Pre-0 + parity skeleton | ⬜ | Follow D.3 §9.1 parity skeleton pattern |
| 1A | Retire `current-speculation-stack` + fallbacks | ⬜ | Mini-design at phase start |
| 1B | Tropical fuel primitive | ⬜ | |
| 1C | Canonical BSP fuel instance migration | ⬜ | A/B bench required |
| 1V | Vision Alignment Gate Phase 1 | ⬜ | |
| 2A | Register S(-1), L1, L2 as stratum handlers | ⬜ | |
| 2B | Retire orchestrators | ⬜ | |
| 2V | Vision Alignment Gate Phase 2 | ⬜ | |
| 3A | Fork-on-union basic mechanism | ⬜ | |
| 3B | Hypercube integration | ⬜ | |
| 3C | Residuation error-explanation | ⬜ | |
| 3V | Vision Alignment Gate Phase 3 | ⬜ | |
| V | Capstone + PIR | ⬜ | |

---

## §17 References

### §17.1 Stage 1/2 artifacts (this track)
- [`docs/research/2026-04-21_TROPICAL_QUANTALE_RESEARCH.md`](../research/2026-04-21_TROPICAL_QUANTALE_RESEARCH.md)
- [`docs/tracking/2026-04-21_PPN_4C_PHASE_9_AUDIT.md`](2026-04-21_PPN_4C_PHASE_9_AUDIT.md)

### §17.2 Parent and adjacent design docs
- [`docs/tracking/2026-04-17_PPN_TRACK4C_DESIGN.md`](2026-04-17_PPN_TRACK4C_DESIGN.md) (D.3)
- [`docs/research/2026-04-06_CELL_BASED_TMS_DESIGN_NOTE.md`](../research/2026-04-06_CELL_BASED_TMS_DESIGN_NOTE.md)
- [`docs/research/2026-04-08_HYPERCUBE_BSP_LE_DESIGN_ADDENDUM.md`](../research/2026-04-08_HYPERCUBE_BSP_LE_DESIGN_ADDENDUM.md)
- [`docs/research/2026-03-28_MODULE_THEORY_LATTICES.md`](../research/2026-03-28_MODULE_THEORY_LATTICES.md)

### §17.3 Completed-track PIRs
- BSP-LE Track 2 PIR — worldview substrate foundations
- BSP-LE Track 2B PIR — Module Theory Realization B, hypercube addendum
- PPN Track 4B PIR — Phase 8 union types blocked on cell-based TMS

### §17.4 Methodology and rules
- [`docs/tracking/principles/DESIGN_METHODOLOGY.org`](principles/DESIGN_METHODOLOGY.org) Stage 3
- [`docs/tracking/principles/DESIGN_PRINCIPLES.org`](principles/DESIGN_PRINCIPLES.org)
- [`docs/tracking/principles/CRITIQUE_METHODOLOGY.org`](principles/CRITIQUE_METHODOLOGY.org)
- [`.claude/rules/on-network.md`](../../.claude/rules/on-network.md)
- [`.claude/rules/propagator-design.md`](../../.claude/rules/propagator-design.md)
- [`.claude/rules/stratification.md`](../../.claude/rules/stratification.md)
- [`.claude/rules/structural-thinking.md`](../../.claude/rules/structural-thinking.md)

---

## Document status

**Stage 3 Design D.1** — initial draft. Subject to P/R/M/S critique iteration. User feedback welcome on:
- Phase scope and sub-phase partition (§6, §7, §8)
- Architectural decisions in §5 (especially Q-A3, Q-A6)
- NTT model adequacy (§3)
- Termination arguments (§12)
- Interface specifications (§13, §14)

Next step: user review → D.2 refinement if needed → Phase 0 artifact setup (acceptance file + Pre-0 bench + parity skeleton) → Phase 1A implementation mini-design.
