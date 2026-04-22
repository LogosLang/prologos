# PPN Track 4C Phase 9+10 — Stage 2 Audit

**Date**: 2026-04-21
**Stage**: 2 — Reality-check audit per [`DESIGN_METHODOLOGY.org`](principles/DESIGN_METHODOLOGY.org) Stage 2
**Status**: Audit complete; feeds Phase 9+10 Design document (to follow)
**Scope**: Combined PPN 4C Phase 9+10+11 (cell-based TMS substrate reconciliation + hypercube algorithms integration + union types via ATMS + tropical fuel cell cross-cutting + elaborator strata to BSP scheduler orchestration unification) — Phase 11 added 2026-04-21 during design dialogue per user direction; see §3.9.
**Prior research**: [`2026-04-21_TROPICAL_QUANTALE_RESEARCH.md`](../research/2026-04-21_TROPICAL_QUANTALE_RESEARCH.md) (Stage 1 foundational research, commit `de357aa1`)

---

## §1 Purpose and methodology

### §1.1 Audit purpose

Stage 2 audit per the design methodology: grounds the Phase 9+10 design in concrete code reality. Produces reconciliation maps, retirement candidates with call-site counts, and substrate-vs-relational-layer classification — all grep-backed, all file+line-cited.

### §1.2 Scope

Combined PPN 4C Phase 9+10+11 per framing B (2026-04-20), the 9+10 combination decision (2026-04-21), and the Phase 11 inclusion decision (2026-04-21). Covers:

- **9A**: substrate reconciliation (three worldview paths → one bitmask substrate)
- **9B**: hypercube algorithms integration (Gray code, bitmask subcube, all-reduce)
- **9C**: union types via ATMS (fork-on-union, tagged branches, S(-1) retract)
- **11**: elaborator strata → BSP scheduler orchestration unification (per D.3 §6.7)
- **Cross-cutting**: tropical fuel cell (integrates with 9A cell infrastructure, 9B cost-per-branch, 9C cost-bounded branching)
- **Not in scope** (downstream): Phase 9b γ hole-fill (consumes Phase 9+10+11 output but is its own phase row)

Phase 11 included because the architectural theme is the same (unify mechanisms): Phase 9+10 unifies the speculation substrate; Phase 11 unifies the scheduler orchestration. Both use `register-stratum-handler!` as the bridge — designing them together ensures consistency across the ~9-12 stratum handlers the combined track produces.

### §1.3 Methodology

Grep-backed findings. Every claim has a file:line reference. No speculation on "what might exist" — only what was found in code.

Queries performed (consolidated): worldview paths, speculation APIs, ATMS infrastructure, stratum handlers, hypercube primitives, union types, tagged-cell-value, fork-prop-network, decisions-state / commitments-state, goal-desc / clause-info (relational boundary), prop-network-fuel.

### §1.4 Deliverables per section

- §3: per-target state findings (what exists, what's partial, what's missing)
- §4: three-worldview-path reconciliation map + retirement candidates
- §5: Phase 9A/9B/9C scoping with dependencies
- §6: open design questions for Stage 3
- §7: references

---

## §2 Research inputs and prior art

### §2.1 Stage 1 research
- [`docs/research/2026-04-21_TROPICAL_QUANTALE_RESEARCH.md`](../research/2026-04-21_TROPICAL_QUANTALE_RESEARCH.md) — 1000 lines, 12 sections, foundational tropical-quantale theory + Prologos synthesis

### §2.2 Prior design notes and addenda
- [`docs/research/2026-04-06_CELL_BASED_TMS_DESIGN_NOTE.md`](../research/2026-04-06_CELL_BASED_TMS_DESIGN_NOTE.md) — 2026-04-06 TMS design note. **SUPERSEDED IN PART** by BSP-LE Track 2B (see §3.1 finding).
- [`docs/research/2026-04-08_HYPERCUBE_BSP_LE_DESIGN_ADDENDUM.md`](../research/2026-04-08_HYPERCUBE_BSP_LE_DESIGN_ADDENDUM.md) — hypercube structure + Gray code + bitmask subcube design; **LARGELY IMPLEMENTED** (see §3.5).
- [`docs/research/2026-03-28_MODULE_THEORY_LATTICES.md`](../research/2026-03-28_MODULE_THEORY_LATTICES.md) — module-theoretic foundations

### §2.3 Completed-track PIRs (state-of-the-art baseline)
- [`docs/tracking/2026-04-10_BSP_LE_TRACK2_PIR.md`](2026-04-10_BSP_LE_TRACK2_PIR.md) — BSP-LE 2 completion. Claims `current-speculation-stack` RETIRED (residual sites remain per §3.1).
- [`docs/tracking/2026-04-16_BSP_LE_TRACK2B_PIR.md`](2026-04-16_BSP_LE_TRACK2B_PIR.md) — BSP-LE 2B closure. Decision-cells-primary + tagged-cell-value + hypercube pattern established.
- [`docs/tracking/2026-04-07_PPN_TRACK4B_PIR.md`](2026-04-07_PPN_TRACK4B_PIR.md) — Track 4B speculation state.

### §2.4 PPN 4C current design
- [`docs/tracking/2026-04-17_PPN_TRACK4C_DESIGN.md`](2026-04-17_PPN_TRACK4C_DESIGN.md) — D.3 design. §6.10 Phase 9 scope; §6.11.3 hypercube; §6.15.6 Phase 3+9 joint item.
- [`docs/tracking/handoffs/2026-04-20_PPN_4C_PHASE_9_HANDOFF.md`](handoffs/2026-04-20_PPN_4C_PHASE_9_HANDOFF.md) — pre-mini-design handoff.

### §2.5 Prior handoffs
- [`docs/tracking/handoffs/2026-04-20_PPN_4C_PHASE_3C_HANDOFF.md`](handoffs/2026-04-20_PPN_4C_PHASE_3C_HANDOFF.md) — Phase 3c pre-implementation handoff.
- [`docs/tracking/handoffs/2026-04-19_PPN_4C_PHASE_1D_MID_HANDOFF.md`](handoffs/2026-04-19_PPN_4C_PHASE_1D_MID_HANDOFF.md) — Phase 1d mid-campaign handoff.

---

## §3 State of the art — survey findings

### §3.1 Three worldview paths in propagator.rkt

**Key finding**: the three paths exist simultaneously with clear priority ordering. BSP-LE Track 2 Phase 11 claimed retirement of `current-speculation-stack`, but **residual sites persist**. The parameter IS NOT fully dead; it has 3 active READ sites in `propagator.rkt` fallback paths and 1 active WRITE site in `typing-propagators.rkt`.

#### §3.1.1 Path A: `current-speculation-stack` (legacy, partially retired)

- **Definition**: [`propagator.rkt:1621`](../../racket/prologos/propagator.rkt) — `(make-parameter '())`
- **Export**: [`propagator.rkt:155`](../../racket/prologos/propagator.rkt)
- **Read sites in propagator.rkt fallback paths**:
  - [`propagator.rkt:995`](../../racket/prologos/propagator.rkt) — `net-cell-read` fallback: `(tms-read v (current-speculation-stack))`
  - [`propagator.rkt:1251`](../../racket/prologos/propagator.rkt) — `net-cell-write` fallback: `(tms-write old-val (current-speculation-stack) new-val)`
  - [`propagator.rkt:3225`](../../racket/prologos/propagator.rkt) — `net-cell-write-widen` fallback (same pattern)
- **Active parameterize site** (production):
  - [`typing-propagators.rkt:316-328`](../../racket/prologos/typing-propagators.rkt) — `wrap-with-assumption-stack` helper pushes onto the stack via `(parameterize ([current-speculation-stack (cons assumption-id (current-speculation-stack))]) …)`
- **Test usage** (9 sites in [`tests/test-tms-cell.rkt`](../../racket/prologos/tests/test-tms-cell.rkt): 273, 279, 292, 296, 305, 321, 329, 333, etc.)
- **Documentary references** in [`cell-ops.rkt`](../../racket/prologos/cell-ops.rkt) comments (lines 62, 103) — comments acknowledge the parameter; not active reads

**Classification**: LEGACY FALLBACK. Read only when `current-worldview-bitmask` returns 0 AND the cell read/write path enters the `tms-read`/`tms-write` branch (the old TMS tree representation, pre-BSP-LE-2B). Under current production flows, this branch is mostly unreachable — but not structurally guaranteed.

#### §3.1.2 Path B: `current-worldview-bitmask` (primary active path)

- **Definition**: [`propagator.rkt:1629`](../../racket/prologos/propagator.rkt) — `(make-parameter 0)` (0 = no speculation)
- **Export**: [`propagator.rkt:160`](../../racket/prologos/propagator.rkt)
- **Wrap helper**: [`propagator.rkt:1631-1637`](../../racket/prologos/propagator.rkt) — `wrap-with-worldview` parameterizes per fire function
- **Priority in net-cell-read/write**: set by `wrap-with-worldview`, consulted FIRST:
  - [`propagator.rkt:963-995`](../../racket/prologos/propagator.rkt) — `net-cell-read` body
  - [`propagator.rkt:1229-1251`](../../racket/prologos/propagator.rkt) — `net-cell-write` body
  - [`propagator.rkt:3211-3225`](../../racket/prologos/propagator.rkt) — `net-cell-write-widen` body
- **Active production sites** (~20 across):
  - [`relations.rkt`](../../racket/prologos/relations.rkt): 12 sites (1889-2325, NAF + guards + clause firing + commitments + query scope)
  - [`typing-propagators.rkt:1925-1946`](../../racket/prologos/typing-propagators.rkt) — union branching
  - [`elab-speculation-bridge.rkt:240-245`](../../racket/prologos/elab-speculation-bridge.rkt) — `with-speculative-rollback` sets it from tagged-cell-value
  - [`metavar-store.rkt:1324`](../../racket/prologos/metavar-store.rkt) — Phase 9b meta-solution per-worldview read
  - [`cell-ops.rkt:83`](../../racket/prologos/cell-ops.rkt) — cell-ops reads it

**Classification**: PRIMARY ACTIVE PATH. BSP-LE 2B's per-propagator worldview mechanism. Fire functions set the bitmask via `wrap-with-worldview`; `net-cell-read`/`write` consult it with highest priority.

**Known hazard** (BSP-LE 2B PIR §6, propagator-design.md): after fire function returns, `current-worldview-bitmask` is 0 (parameterize scope ended). BSP `fire-and-collect-writes` MUST use `net-cell-read-raw` (not `net-cell-read`) for snapshot/result diffing — otherwise worldview filtering silently drops writes. This bug class is flagged; Phase 9A migration must preserve the `raw` read discipline.

#### §3.1.3 Path C: `worldview-cache-cell-id = (cell-id 1)` (on-network, derived)

- **Definition**: [`propagator.rkt:516`](../../racket/prologos/propagator.rkt) — `(define worldview-cache-cell-id (cell-id 1))`
- **Export**: [`propagator.rkt:181`](../../racket/prologos/propagator.rkt)
- **Pre-allocated in make-prop-network**: [`propagator.rkt:627`](../../racket/prologos/propagator.rkt) with initial value `0`
- **Merge function**: [`propagator.rkt:592-593`](../../racket/prologos/propagator.rkt) — `worldview-cache-merge` (equality-check replacement, not bitwise-or — replacement is correct for retraction)
- **Projection from decisions-state**: [`propagator.rkt:596-615`](../../racket/prologos/propagator.rkt) — `install-worldview-projection` watches decisions cell, writes derived bitmask

**Writers** (~15 production sites):
- [`atms.rkt:564, 750`](../../racket/prologos/atms.rkt) — `solver-context`-based writes; `solver-state-with-worldview`
- [`elab-speculation-bridge.rkt:234-269`](../../racket/prologos/elab-speculation-bridge.rkt) — `with-speculative-rollback` writes on speculation-entry/commit
- [`relations.rkt:240-242, 2153-2155, 2224-2225, 2679`](../../racket/prologos/relations.rkt) — NAF handler, guard clearing, query
- [`typing-propagators.rkt:1929, 1941`](../../racket/prologos/typing-propagators.rkt) — union branching per-branch worldview
- [`propagator.rkt:1834`](../../racket/prologos/propagator.rkt) — fork operations

**Readers**: called via `net-cell-read-raw net worldview-cache-cell-id` (many sites in tests, tagged-cell-value operations, propagator.rkt:2595 Tier-detection).

**Classification**: ON-NETWORK AUTHORITATIVE SOURCE of the worldview. Derived from decisions-state via projection propagator. The `current-worldview-bitmask` parameter is set inside fire functions FROM this cell (via `wrap-with-worldview`).

#### §3.1.4 Priority ordering

In `net-cell-read` and `net-cell-write`:

```
1. If current-worldview-bitmask > 0  →  use per-propagator bitmask (Path B)
2. Else if tagged-cell-value stored   →  read worldview-cache-cell-id (Path C)
3. Else fall back to tms-read/write   →  use current-speculation-stack (Path A, LEGACY)
```

Paths B and C are the active layers; Path A is the fallback for the old TMS-tree cell representation. Phase 9A's reconciliation work: retire Path A by eliminating both the old TMS tree code path AND the `current-speculation-stack` parameter definition.

#### §3.1.5 Phase 9A implications

- Retiring Path A requires:
  - Eliminating `wrap-with-assumption-stack` in `typing-propagators.rkt:316` (or migrating its one use)
  - Eliminating the 3 fallback READ sites in `propagator.rkt` (995, 1251, 3225)
  - Retiring the parameter definition (1621) and export (155)
  - Updating `test-tms-cell.rkt` (9 test sites)
- Path B and Path C continue as the unified two-layer substrate:
  - Path C = authoritative state (on-network)
  - Path B = per-propagator override (parameter, read inside fire functions)
- The architectural consolidation is NOT "one bitmask path" — it is "two layers of the same bitmask: on-network cell + per-fire-function override parameter"

---

### §3.2 elab-speculation.rkt — dead library code

**Key finding**: [`elab-speculation.rkt`](../../racket/prologos/elab-speculation.rkt) (189 lines) exports speculation API (`speculation-begin`, `speculation-try-branch`, `speculation-commit`, `speculate-first-success`) but is **NOT USED IN PRODUCTION**. Only `tests/test-elab-speculation.rkt` references it.

#### §3.2.1 File contents

Structs:
- `speculation` (atms + base-enet + branches + next-id)
- `branch` (hypothesis-id + enet + status + contradiction + label)
- `speculation-result` (status + enet + winner-index + nogoods + atms-val)
- `nogood-info` (branch-index + branch-label + contradiction + hypothesis-id)

API:
- `speculation-begin` — creates speculation context via `make-solver-state` + `solver-state-amb`
- `speculation-try-branch` — forks network, applies try-fn, checks contradiction, updates status
- `speculation-commit` — selects first 'ok branch; returns result
- `speculate-first-success` — sequential try-until-success convenience wrapper

Consumer grep:
- `speculation-begin | speculation-try-branch | speculation-commit | speculate-first-success` ONLY found in 2 files: `elab-speculation.rkt` (definitions) + `tests/test-elab-speculation.rkt` (~35 test sites)

#### §3.2.2 Production speculation uses `elab-speculation-bridge.rkt` instead

- **File**: [`elab-speculation-bridge.rkt`](../../racket/prologos/elab-speculation-bridge.rkt) (separate from elab-speculation.rkt)
- **Primary API**: `with-speculative-rollback(thunk, success?, label)`
- **Production callers**:
  - [`qtt.rkt:2425`](../../racket/prologos/qtt.rkt)
  - [`typing-errors.rkt:78`](../../racket/prologos/typing-errors.rkt)
  - [`typing-core.rkt:1205, 1291, 1325, 2439`](../../racket/prologos/typing-core.rkt) — 4 sites
- Uses `save-meta-state` / `restore-meta-state!` from metavar-store.rkt + bitmask worldview (Path B)

#### §3.2.3 Phase 9 implications

- The Phase 9 handoff documented `elab-speculation.rkt` as the "speculation bridge" Phase 9 migration target. **This is WRONG**: the production file is `elab-speculation-bridge.rkt`.
- `elab-speculation.rkt` is LIBRARY CODE, orphaned — tests exercise it but no production code does
- Phase 9 decision: delete `elab-speculation.rkt` + `test-elab-speculation.rkt` as dead library, OR retain as a documented unused-but-supported API for future union-type ATMS branching (which may want the structured speculation API)
- **Lean**: retain with explicit documentation that it's library, migrate to pure-bitmask semantics for consistency, treat as "union-type branching primitives" for Phase 9C integration

---

### §3.3 ATMS infrastructure state

#### §3.3.1 Two parallel ATMS APIs (deprecated + modern)

**Deprecated (Phase 5.6 retirement)** — [`atms.rkt:37-49`](../../racket/prologos/atms.rkt):
- `atms` struct — marked DEPRECATED
- `atms-empty` — marked DEPRECATED
- `atms-assume`, `atms-retract`, `atms-amb` — still exported

**Modern (Phase 5.6 replacement)** — [`atms.rkt:72-102`](../../racket/prologos/atms.rkt):
- `solver-context` struct (immutable phone book of cell-ids)
- `make-solver-context`, `make-solver-state`
- `solver-state-assume`, `solver-state-retract`, `solver-state-add-nogood`, `solver-state-amb`
- `solver-state-read-cell`, `solver-state-write-cell`, `solver-state-consistent?`
- `solver-state-with-worldview`, `solver-state-explain-hypothesis`, `solver-state-explain`

#### §3.3.2 `atms-believed` field — BSP-LE 2B D.1 finding state

The `atms-believed` field in the deprecated `atms` struct (hasheq of assumption-id → #t) is STILL USED by the deprecated API:
- [`atms.rkt:213-225`](../../racket/prologos/atms.rkt) — `atms-assume` populates it, `atms-retract` removes
- [`atms.rkt:302`](../../racket/prologos/atms.rkt) — `atms-read-cell` filters supported-values by `atms-believed`
- [`atms.rkt:334`](../../racket/prologos/atms.rkt) — `atms-solve-all` reads `atms-amb-groups`
- [`atms.rkt:371-456`](../../racket/prologos/atms.rkt) — `atms-minimal-diagnoses` etc. read `atms-believed`

**BSP-LE 2B D.1 self-critique** flagged the `atms-believed` field as unnecessary (decision cells are primary; worldview is derived). This retirement HAS NOT LANDED. Modern `solver-state` does not use `believed`; reads the on-network cells via `solver-context` directly.

**Consequence**: deprecated ATMS struct is a parallel mechanism to the modern `solver-context`. Not a belt-and-suspenders within production (they are used in different call paths), but the deprecated API is still live for surface AST (see §3.3.3).

#### §3.3.3 Surface AST uses deprecated API

Surface `(atms-* …)` forms at the language level:
- AST structs in [`syntax.rkt:204-206, 752-755`](../../racket/prologos/syntax.rkt): `expr-atms-new`, `expr-atms-assume`, `expr-atms-retract`, `expr-atms-amb`, `expr-atms-solve-all`, `expr-atms-nogood`
- Parser in [`parser.rkt:2537-2574`](../../racket/prologos/parser.rkt) handles keywords
- Elaborator in [`elaborator.rkt:2438-2466`](../../racket/prologos/elaborator.rkt) elaborates the surface forms
- Reduction in [`reduction.rkt:2842-3635`](../../racket/prologos/reduction.rkt) evaluates them via deprecated `atms-assume` etc.
- Zonk in [`zonk.rkt:358-1258`](../../racket/prologos/zonk.rkt) traverses them

**Finding**: surface ATMS forms use the deprecated API, not the modern solver-context. This is a latent migration target (not Phase 9+10 scope). Phase 9+10 interacts with the **internal** speculation mechanism (solver-state / elab-speculation-bridge), not the surface AST evaluation.

#### §3.3.4 Phase 9+10 implications

- Phase 9A retirement targets (ATMS side):
  - `atms-believed` field — retired when the deprecated `atms` struct itself is retired
  - `atms` struct + `atms-empty` — formal retirement awaits all consumers migrating to solver-context
- Phase 9C (union types via ATMS) USES the modern solver-context API; not gated on deprecated-API retirement
- Surface ATMS forms migration is SEPARATE WORK (not in Phase 9+10 scope) — they currently work, no urgency

---

### §3.4 BSP-LE 2B substrate surface

**Key finding**: the substrate is MATURE and PRODUCTION-READY. Phase 9+10 has a rich foundation to consume.

#### §3.4.1 Stratum handler infrastructure

- **API definition**: [`propagator.rkt:2536-2551`](../../racket/prologos/propagator.rkt)
- **`register-stratum-handler!`**: [`propagator.rkt:2538`](../../racket/prologos/propagator.rkt) — accepts `request-cell-id`, `handler-fn`, `#:tier ('topology | 'value)`, `#:reset-value`
- **BSP outer-loop integration**: [`propagator.rkt:2746-2790`](../../racket/prologos/propagator.rkt)

**Registered stratum handlers** (6 total):

| Handler | Location | Tier | Purpose |
|---|---|---|---|
| constraint-propagators-topology | [propagator.rkt:2558](../../racket/prologos/propagator.rkt) | topology | Topology-request dispatch (callbacks) |
| elaborator-topology | [elaborator-network.rkt:1087](../../racket/prologos/elaborator-network.rkt) | topology | Elaborator-specific topology |
| narrowing-topology | [narrowing.rkt:79](../../racket/prologos/narrowing.rkt) | topology | Narrowing topology |
| sre-topology | [sre-core.rkt:1249](../../racket/prologos/sre-core.rkt) | topology | SRE topology |
| naf-pending (S1 NAF) | [relations.rkt:246](../../racket/prologos/relations.rkt) | value | NAF evaluation (fork + BSP + nogood) |
| classify-inhabit-request | [typing-propagators.rkt:898](../../racket/prologos/typing-propagators.rkt) | value | Phase 3c-iii residuation (PPN 4C) |

**Phase 9 implication**: if tropical fuel cell adds a stratum handler (for threshold-based fuel-exhaustion detection), it's a natural addition following the established pattern.

#### §3.4.2 Tagged-cell-value (Module Theory Realization B carrier)

- **Struct**: `tagged-cell-value` with `entries` field (list of `(assumption-id . value)` pairs)
- **Merge**: tagged-merge preserves per-assumption values; worldview-bitmask filtering selects visible entries
- **Usage**: widely used across [`relations.rkt`](../../racket/prologos/relations.rkt) (2024-2706, NAF + clause + query scope), [`elab-speculation-bridge.rkt:240-241`](../../racket/prologos/elab-speculation-bridge.rkt), [`typing-propagators.rkt:1919-1923`](../../racket/prologos/typing-propagators.rkt) (union branching)
- **Tests**: [`tests/test-tagged-cell-value.rkt`](../../racket/prologos/tests/test-tagged-cell-value.rkt) (many test sites, production-mature)
- **Promote-cell-to-tagged helpers**:
  - [`propagator.rkt:1154`](../../racket/prologos/propagator.rkt) — `promote-cell-to-tagged`
  - [`typing-propagators.rkt:334`](../../racket/prologos/typing-propagators.rkt) — `promote-cell-to-tms` (deprecated, related)

#### §3.4.3 Compound cells (decisions-state, commitments-state)

- **Definitions**: [`decision-cell.rkt:632, 733`](../../racket/prologos/decision-cell.rkt)
- **Merge functions**: `decisions-state-merge`, `commitments-state-merge`, both SRE-registered under `'decisions-state` / `'commitments-state` (progressive classification candidates per PPN 4C Phase 13)
- **Usage count**: 167 total occurrences across 7 files — `atms.rkt` (17), `decision-cell.rkt` (59), `tests/test-solver-context.rkt` (74), `propagator.rkt` (8), `phase1d-registrations.rkt` (5), `relations.rkt` (2), `tests/test-infra-cell-atms-01.rkt` (2)
- **Projection to worldview-cache**: `install-worldview-projection` (propagator.rkt:596-615) watches decisions cell, recomputes bitmask via `recompute-bitmask`

#### §3.4.4 fork-prop-network

- **Used extensively** in [`relations.rkt`](../../racket/prologos/relations.rkt) (NAF handler at 128, query initialization at 2916, etc.)
- **Cost**: O(1) structural sharing via CHAMP
- **Benchmark**: [`benchmarks/micro/bench-track2b-solver.rkt:152-199`](../../racket/prologos/benchmarks/micro/bench-track2b-solver.rkt) — "fork-prop-network (50 cells) x20000" confirms cheap operation
- **Phase 9C implication**: union-type branching via `fork-prop-network` follows the NAF handler pattern

#### §3.4.5 Assumption-tagged dependents (filter-dependents-by-paths)

- Filter at [`propagator.rkt:1117`](../../racket/prologos/propagator.rkt) — check `(memq #f paths)` fast-path for whole-cell watchers
- Used by BSP scheduler to skip propagators whose input component didn't change
- Phase 9+10 consumes as-is; no modifications needed

---

### §3.5 Hypercube algorithms — LARGELY IMPLEMENTED

**Key finding**: The hypercube primitives from the 2026-04-08 addendum are IMPLEMENTED. Phase 9B is integration and polish, not primary implementation.

#### §3.5.1 Gray code — IMPLEMENTED

- **Definition**: [`relations.rkt:1866`](../../racket/prologos/relations.rkt) — `(define (gray-code i) (bitwise-xor i (arithmetic-shift i -1)))`
- **Order generator**: [`relations.rkt:1874-1883`](../../racket/prologos/relations.rkt) — `gray-code-order m` produces permutation of `0..m-1` in Gray-code adjacency order (handles non-power-of-2 by skip-and-collect)
- **Export**: [`relations.rkt:96`](../../racket/prologos/relations.rkt)
- **Tests**: [`tests/test-propagator-solver.rkt:259-325`](../../racket/prologos/tests/test-propagator-solver.rkt) — 3+ test cases (M=2, M=4, M=3 non-power-of-2)
- **Provenance**: BSP-LE Track 2 Phase 6d-ii

#### §3.5.2 Hamming distance — IMPLEMENTED

- **Definition**: [`decision-cell.rkt:361`](../../racket/prologos/decision-cell.rkt) — `(define (hamming-distance a b) ...)`
- **Export**: [`decision-cell.rkt:70`](../../racket/prologos/decision-cell.rkt)
- **Tests**: [`tests/test-decision-cell.rkt:416`](../../racket/prologos/tests/test-decision-cell.rkt)

#### §3.5.3 Bitmask subcube membership — IMPLEMENTED

- **Definition**: [`decision-cell.rkt:368-371`](../../racket/prologos/decision-cell.rkt) — `(define (subcube-member? wv-bitmask ng-bitmask) (= (bitwise-and wv-bitmask ng-bitmask) ng-bitmask))`
- **Export**: [`decision-cell.rkt:72`](../../racket/prologos/decision-cell.rkt)
- **Used for**: O(1) nogood containment check in worldview-filtered reads

#### §3.5.4 Hypercube all-reduce — IMPLEMENTED (tree-reduce)

- **Pairwise merge**: [`propagator.rkt:2433-2448`](../../racket/prologos/propagator.rkt) — `merge-fire-results`
- **Tree-reduce**: [`propagator.rkt:2450-2495`](../../racket/prologos/propagator.rkt) — `tree-reduce-fire-results` (parallel & sequential variants)
- **Integration in BSP scheduler**: [`propagator.rkt:2661-2672`](../../racket/prologos/propagator.rkt) — `tree-threshold` (parameterized) enables/disables tree-reduce
- **Provenance**: BSP-LE 2B Phase 2b "Hypercube All-Reduce"

#### §3.5.5 Hasse-registry Q_n override pattern — IMPLEMENTED

- **Primitive**: [`hasse-registry.rkt`](../../racket/prologos/hasse-registry.rkt) (commit `c669db51`, Phase 2b)
- **Q_n bitmask subsume-fn override**: exposed via consumer-provided `subsume-fn`; `(lambda (pos query) (= (bitwise-and pos query) query))`
- **Test**: [`tests/test-hasse-registry.rkt:238`](../../racket/prologos/tests/test-hasse-registry.rkt) — demonstrates Q_n pattern

#### §3.5.6 Phase 9B implications

Phase 9B does NOT implement Gray code + hamming + subcube-member? + tree-reduce — those are done. Phase 9B's work:
- **Integration**: wire Gray code into ATMS branch traversal (currently Gray code exists as a primitive; union-type branching in typing-propagators.rkt:1919-1946 does NOT use Gray code order)
- **Subcube pruning in nogood processing**: decision-cell's `subcube-member?` exists; current nogood filtering uses it partially — audit for complete coverage
- **Tree-reduce scope**: currently opt-in via `tree-threshold` parameter; evaluate for default-on

This is substantially LESS WORK than originally scoped. Revision to phase partitioning may be warranted (§5).

---

### §3.6 Union types via ATMS mechanism

#### §3.6.1 Union-type infrastructure

- **Canonical construction**: [`union-types.rkt`](../../racket/prologos/union-types.rkt) (SRE Track 2H extraction)
- **Per-branch PUnify**: `unify-union-components` in [`unify.rkt`](../../racket/prologos/unify.rkt) (line 777 per D.3 §6.10)
- **Branch mechanism in typing-propagators**: [`typing-propagators.rkt:1919-1946`](../../racket/prologos/typing-propagators.rkt)
  - Reads left and right component bitmasks
  - Parameterizes `current-worldview-bitmask` per branch
  - Writes `worldview-cache-cell-id` per branch
  - Uses `promote-cell-to-tagged` for shared cells

#### §3.6.2 Fork mechanism

- [`relations.rkt:2916`](../../racket/prologos/relations.rkt) — query-scope fork pattern
- [`relations.rkt:128`](../../racket/prologos/relations.rkt) — NAF fork pattern (`fork-prop-network` + `net-cell-reset`)
- Used as template for Phase 9C's union-type fork

#### §3.6.3 Contradiction → nogood flow

- S1 NAF handler at [`relations.rkt:116-243`](../../racket/prologos/relations.rkt) — demonstrates the pattern:
  1. Fork network (O(1) CHAMP share)
  2. Install inner goal + quiesce fork
  3. Check provability
  4. Write nogood to main network worldview-cache if contradiction
- Phase 9C follows this pattern for union branches

#### §3.6.4 Phase 9C implications

- Infrastructure is mostly in place
- Gap list for production-ready Phase 9C:
  1. Gray-code branch ordering (currently branches fire in arbitrary order; Phase 9B integrates)
  2. Per-branch cost tracking (cross-cut with tropical fuel cell)
  3. Subcube pruning on nogood propagation across branches
  4. Error-explanation when all branches contradict (residuation via Module Theory §5)

---

### §3.7 Substrate vs relational-layer classification

**Key finding**: the boundary is clear. Substrate = lattice-agnostic; relational-layer = goal-desc / clause-info / unify-terms / discrimination. Phase 9+10 consumes substrate, must not couple to relational-layer.

#### §3.7.1 SUBSTRATE (Phase 9+10 consumes)

| Piece | Location | Status |
|---|---|---|
| `worldview-cache-cell-id` + projection | propagator.rkt:516, 596-615 | Production |
| `current-worldview-bitmask` + `wrap-with-worldview` | propagator.rkt:1629-1637 | Production |
| `tagged-cell-value` + merge + filter | propagator.rkt / decision-cell.rkt | Production |
| `fork-prop-network`, `net-cell-reset` | propagator.rkt | Production |
| `solver-context`, `solver-state` API | atms.rkt:490-820 | Production |
| `register-stratum-handler!` + BSP integration | propagator.rkt:2536-2790 | Production |
| `decisions-state`, `commitments-state` | decision-cell.rkt:632, 733 | Production |
| Hypercube: `gray-code-order`, `hamming-distance`, `subcube-member?` | relations.rkt, decision-cell.rkt | Production |
| Tree-reduce (hypercube all-reduce) | propagator.rkt:2433-2495 | Production |
| `promote-cell-to-tagged` | propagator.rkt:1154 | Production |
| `hasse-registry` primitive | hasse-registry.rkt | Production (Phase 2b) |

#### §3.7.2 RELATIONAL-LAYER (Phase 9+10 must not couple)

| Piece | Locations | Total occurrences |
|---|---|---|
| `goal-desc`, kinds | relations.rkt (164), others | 423 total |
| `clause-info` | wf-engine.rkt (5) | 5 |
| `unify-terms` | stratified-eval.rkt (16), others | ~20 |
| discrimination | relations.rkt, reduction.rkt | scattered |
| `solve-goal`, clause-body execution | relations.rkt | heavy |
| NAF semantics (`current-naf-oracle`) | relations.rkt:256 | 1 param |
| Tabling infrastructure | tabling.rkt | full file |

**Classification boundary**: substrate pieces are CELL-LEVEL and SCHEDULER-LEVEL operations independent of what the cell values represent. Relational-layer pieces are SPECIFIC to the relational-facts-with-logic-variables model (clauses, unification over terms with logic variables, goal resolution).

**Forward reference**: BSP-LE Track 6 (future, not yet designed) will lift the relational layer into a general residual solver parameterized by lattice. Phase 9+10 consumes the substrate and ships typing/cost machinery on top — this is independent of the general-solver track.

---

### §3.8 prop-network-fuel counter — tropical migration target

#### §3.8.1 Current state

- **Field**: on `prop-net-cold` struct (part of `prop-network`)
- **Accessor**: [`propagator.rkt:402`](../../racket/prologos/propagator.rkt) — `(define-syntax-rule (prop-network-fuel net) ...)` (syntax rule for fast access)
- **Export**: [`propagator.rkt:65`](../../racket/prologos/propagator.rkt)

#### §3.8.2 Decrement sites

- [`propagator.rkt:2655`](../../racket/prologos/propagator.rkt) — BSP scheduler decrement: `[fuel (- (prop-network-fuel net) n)]` (decrement by number of propagators fired)
- [`propagator.rkt:3272, 3325`](../../racket/prologos/propagator.rkt) — widen variants, `(sub1 (prop-network-fuel net))`

#### §3.8.3 Check sites (exhaustion detection)

Lines 2088, 2143, 2600, 2637, 2644, 3264, 3317, 3404, 3407, 3414 — all `(<= (prop-network-fuel net) 0)` threshold checks. When fuel <= 0, run-to-quiescence exits.

#### §3.8.4 Test usage (read-only measurement)

- `tests/test-propagator-bsp.rkt:146`, `tests/test-abstract-interpretation-e2e.rkt` (4 sites), `tests/test-widening-fixpoint.rkt` (2 sites), `tests/test-trait-resolution-bridge.rkt` (3 sites), `tests/test-cross-domain-propagator.rkt`, `tests/test-infra-cell-atms-01.rkt`, `tests/test-tabling.rkt`, `tests/test-propagator-solver.rkt`, `benchmarks/micro/bench-alloc.rkt` (2 sites)

#### §3.8.5 Tropical migration target (per research doc §10.8)

Replace decrementing counter with tropical fuel cell:
- Introduce `fuel-cost-cell-id` (new well-known cell-id, e.g., cell-id 11), initial value `0`, merge `min` (tropical join)
- Introduce `fuel-budget-cell-id` holding the budget constant
- Threshold propagator watches both, writes contradiction when `cost > budget`
- Propagator firings write `cost_after = cost_before + Δ` via `net-cell-write`
- Retire `prop-network-fuel` field, all decrement sites, all check sites

Phase 9+10 scope includes the tropical-fuel-cell migration as cross-cutting work.

---

### §3.9 Phase 11 — elaborator strata → BSP scheduler orchestration

**Added 2026-04-21** per user direction to include Phase 11 in this addendum track. Architectural parallel to §3.1-§3.8: Phase 9+10 unifies the speculation SUBSTRATE; Phase 11 unifies the scheduler ORCHESTRATION. Same move, different subsystem.

#### §3.9.1 Current orchestration state

The elaborator has THREE strata (S(-1), L1, L2) executed by a sequential Racket function, NOT registered as BSP stratum handlers.

- **Production orchestrator**: `run-stratified-resolution-pure` at [`metavar-store.rkt:1915`](../../racket/prologos/metavar-store.rkt)
  - Called from [`metavar-store.rkt:1699`](../../racket/prologos/metavar-store.rkt) (primary production path)
  - Signature: `(run-stratified-resolution-pure enet trigger-meta-id resolution-executor)`
  - Sequential outer loop: S(-1) → S0 (monotone) → L1 (readiness scan) → L2 (action execution) → repeat until quiescence
- **Dead code sibling**: `run-stratified-resolution!` at [`metavar-store.rkt:1863`](../../racket/prologos/metavar-store.rkt)
  - Marked at line 1860: "Mostly dead code — superseded by run-stratified-resolution-pure"
  - Zero production callers confirmed by grep
  - R3 external critique finding (D.3): both retire in Phase 11

#### §3.9.2 Three elaborator strata — current implementations

| Stratum | Function | Location | Mechanism |
|---|---|---|---|
| S(-1) retraction | `run-retraction-stratum!` | [`metavar-store.rkt:1392`](../../racket/prologos/metavar-store.rkt) | Side-effecting Racket function, called sequentially from `run-stratified-resolution-pure:1876` |
| L1 readiness | `collect-ready-constraints-via-cells` | [`metavar-store.rkt:904`](../../racket/prologos/metavar-store.rkt) | Pure scan function; reads ready-queue cell; produces action descriptors |
| L2 resolution | `execute-resolution-actions!` | [`metavar-store.rkt:998`](../../racket/prologos/metavar-store.rkt) | Action interpreter (dispatches to `resolution.rkt` for action execution) |

**Request-accumulator cells already exist**:
- `retracted-assumptions` box at [`metavar-store.rkt:1332`](../../racket/prologos/metavar-store.rkt) — set of retracted aids; `record-assumption-retraction!` (line 1336) adds; `run-retraction-stratum!` (line 1392) consumes
- `current-ready-queue-cell-id` parameter at [`metavar-store.rkt:1510`](../../racket/prologos/metavar-store.rkt) — cell-id for the ready-queue; populated by readiness propagators (Track 7 Phase 8a)

#### §3.9.3 What's missing for Phase 11

- **Stratum handler registrations** for the three elaborator strata
  - S(-1): register `run-retraction-stratum!` as handler for a new retraction-request cell-id (currently: set-box! + side-effect)
  - L1: register readiness action collection as handler for `current-ready-queue-cell-id`
  - L2: register action execution as handler (may be same cell as L1, or chained)
- **Retirement of `run-stratified-resolution-pure`** — once handlers are registered, BSP outer loop iterates them uniformly (per [`propagator.rkt:2746-2790`](../../racket/prologos/propagator.rkt))
- **Retirement of `run-stratified-resolution!`** dead code

#### §3.9.4 Relationship to Phase 9+10 substrate

The retraction stratum (S(-1)) integrates with speculation-rollback:
- [`elab-speculation-bridge.rkt:272`](../../racket/prologos/elab-speculation-bridge.rkt) calls `record-assumption-retraction!` on failed speculation
- Phase 9+10 substrate reconciliation (retiring `current-speculation-stack`) does NOT change retraction semantics — the retracted-assumption set accumulation is orthogonal to the worldview bitmask
- Phase 11 migrating S(-1) to a stratum handler preserves this integration; no coupling change

**Parameter coupling**: `current-ready-queue-cell-id` is a Racket parameter (#f by default, set per elaboration). This is OFF-network state — candidate for further retirement (PM Track 12 territory, NOT Phase 11 scope). Phase 11 preserves current parameter shape.

#### §3.9.5 Phase 11 scope and work estimate

Scope:
- Add 3 stratum handler registrations (~50-100 lines)
- Retire `run-stratified-resolution-pure` (~50 lines deleted + callers updated)
- Delete `run-stratified-resolution!` dead code (~50 lines deleted)
- Preserve retraction semantics (no functional change in S(-1))
- Preserve readiness + action execution semantics (no functional change in L1/L2)

Estimated: **~150-250 lines** work-volume, modest risk.

**Dependencies**:
- Phase 11 independent of Phase 9+10 substrate work (different subsystem)
- Phase 9+10's speculation-bridge integration with S(-1) (`record-assumption-retraction!`) is preserved
- Phase 11 and Phase 9A are architecturally INDEPENDENT — can proceed in parallel or either order

#### §3.9.6 Existing stratum handler count — revised

Pre-Phase-11: 6 registered stratum handlers (per §3.4.1)
Post-Phase-11: 9 registered stratum handlers (adding S(-1), L1, L2)

BSP scheduler iterates all handlers per `#:tier` ('topology or 'value) per outer-loop iteration. Adding 3 more follows the established pattern.

---

## §4 Reconciliation and migration plan

### §4.1 Three worldview paths → two-layer bitmask substrate

**Target state** (post-Phase-9A):

```
Path C (cell) → authoritative on-network state (worldview-cache-cell-id)
Path B (parameter) → per-propagator override inside fire functions (current-worldview-bitmask)
Path A (parameter) → RETIRED (current-speculation-stack removed)
```

The "one bitmask" reconciliation is NOT "one path" — it is two layers of the same bitmask (cell + parameter), with the parameter scoped to fire-function execution.

### §4.2 Retirement candidates (consolidated)

| Target | Location(s) | Priority | Notes |
|---|---|---|---|
| `current-speculation-stack` parameter | propagator.rkt:1621, 155 | Phase 9A | Has 3 residual read sites, 1 active parameterize |
| `tms-read` / `tms-write` fallback code paths | propagator.rkt:995, 1251, 3225 | Phase 9A | Only reachable via Path A; retire with parameter |
| `wrap-with-assumption-stack` | typing-propagators.rkt:316-328 | Phase 9A | 1 active consumer; migrate or retire |
| `atms` struct (deprecated) | atms.rkt:159 | Phase 9A? (optional) | Parallel to solver-context; surface AST still uses |
| `atms-believed` field | atms.rkt:159 (within atms struct) | Phase 9A? (with atms struct) | BSP-LE 2B D.1 finding |
| `atms-empty` | atms.rkt | Phase 9A? (optional) | With atms struct retirement |
| `prop-network-fuel` field + decrement/check sites | propagator.rkt (15+ sites) | Phase 9 cross-cutting | Replaced by tropical fuel cell |
| `elab-speculation.rkt` (dead library code) | elab-speculation.rkt (189 lines) + test-elab-speculation.rkt | Phase 9C? (optional) | Either delete or migrate to pure-bitmask |
| `run-stratified-resolution-pure` | metavar-store.rkt:1915 | Phase 11 | Retire once stratum handlers registered |
| `run-stratified-resolution!` (dead code) | metavar-store.rkt:1863 | Phase 11 | Delete; zero production callers (R3 external critique) |

### §4.3 Migration sequencing (dependency graph)

```
Phase 9A (substrate reconciliation)
  ├── Retire current-speculation-stack + tms-read/write fallbacks
  ├── Retire wrap-with-assumption-stack (or migrate to bitmask)
  ├── Migrate prop-network-fuel → tropical fuel cell (cross-cut with 9B)
  └── [optional] Retire deprecated atms struct

Phase 9B (hypercube integration)
  ├── Wire Gray code into ATMS branch traversal
  ├── Complete subcube-pruning coverage in nogood flow
  └── Tropical-quantale integration (cost-per-branch)

Phase 9C (union types via ATMS)
  ├── Fork-on-union following S1 NAF pattern
  ├── Tagged branches + S(-1) retract
  └── Cost-bounded branching (tropical fuel budget applies per-branch)

Phase 9b γ hole-fill (DOWNSTREAM, separate phase row)
Phase 11 (elaborator strata → BSP) — follows 9+10
```

### §4.4 Risk map

- **R1: BSP-LE 2B PIR overclaim** — PIR says "current-speculation-stack RETIRED" but code shows residual sites. Phase 9A retirement is the actual completion of this claim.
- **R2: Silent-write-drop (known)** — per propagator-design.md, `fire-and-collect-writes` must use `net-cell-read-raw` (not `net-cell-read`) for diffing. Phase 9A must preserve this discipline when touching net-cell-read/write bodies.
- **R3: elab-speculation.rkt orphan status** — 189 lines of dead library code. Decision at Phase 9C: delete, retain-as-library, or migrate to current patterns.
- **R4: atms-believed retirement scope** — retiring the deprecated `atms` struct requires migrating surface AST (expr-atms-*) which is separate work. Phase 9A treats `atms-believed` retirement as optional; may defer.
- **R5: Tropical fuel migration concurrent with substrate reconciliation** — cross-cutting work increases coordination complexity. Sub-phase ordering at Phase 9 Design stage.

---

## §5 Phase partitioning (revised post-audit)

Given audit findings (hypercube largely implemented; substrate reconciliation smaller than expected), the A/B/C split may reshape. Proposing two possible partitionings:

### §5.1 Partition Option 1: A/B/C as originally scoped

- **9A (substrate reconciliation)**: retire stack, migrate fuel to tropical cell, retire atms-believed (optional)
- **9B (hypercube algorithms)**: wire Gray code into branch traversal, complete subcube-pruning coverage, tropical cost-per-branch
- **9C (union types via ATMS)**: fork-on-union, tagged branches, S(-1) retract, error explanation on all-fail

### §5.2 Partition Option 2: Consolidated

Since hypercube is mostly implemented and union-types branching already has 90% infrastructure, the traditional 3-sub-phase split may over-scope. Alternative:

- **9A (substrate reconciliation + tropical fuel)**: retire stack, migrate fuel to tropical cell. Largest work.
- **9B (union types via ATMS, integrating hypercube)**: fork-on-union + Gray-code ordering + subcube pruning + cost-bounded branching in one coherent effort. Hypercube not a separate phase; applied within 9B.

**Design decision deferred** to Stage 3 (Design document). Audit surfaces both options; Design resolves.

### §5.3 Cross-cutting: tropical fuel cell

Regardless of partitioning, tropical fuel cell work spans sub-phases:
- Cell infrastructure (in 9A)
- Cost-per-branch integration (in 9B or 9C depending on partition)
- Residuation for error-explanation (in 9C or deferred to Phase 11b)

Design document treats tropical fuel as a vertical concern woven through the horizontal phase structure.

### §5.4 Phase 9b γ hole-fill boundary

Phase 9b γ hole-fill (§6.2.1 of D.3) is:
- A reactive propagator on the attribute-map
- Fires at CLASSIFIER-ground + INHABITANT-bot threshold
- Consumes Phase 9+10 substrate (tagged-cell-value for multi-candidate ATMS branching) + Phase 2b Hasse-registry + Phase 3 :type facet tag-layers + Phase 4 β2

It is DOWNSTREAM of Phase 9+10 and has its own design concerns (inhabitant catalog registration path — M1 external critique; catalog-growth re-firing — M3 external critique). Phase 9+10 audit captures only the substrate interface that Phase 9b consumes (tagged-cell-value, ATMS branching mechanism, worldview-filtered reads).

---

## §6 Open design questions for Phase 9+10 Design (Stage 3)

These are genuine design decisions — not resolved here.

### §6.1 Phase partitioning (§5.1 vs §5.2)
Original 9A/9B/9C split (three focused sub-phases) vs consolidated 9A + 9B (substrate + union-types-with-hypercube). Lean depends on work-volume estimates.

### §6.2 Tropical quantale sub-class (from research §11.1)
Commutative unital integral residuated (maximally rich) vs simpler variants. Integration with PReduce guides the choice.

### §6.3 Fuel granularity (from research §11.2)
Per-propagator-firing (current), per-cell-write, per-BSP-round, per-subsystem. Audit shows current is per-firing; tropical migration preserves by default but may offer alternatives.

### §6.4 Retirement scope within Phase 9A
- Must retire: `current-speculation-stack` + fallback paths
- Optional retire: deprecated `atms` struct + `atms-believed` + `atms-empty`
- Defer to separate track: surface ATMS AST forms migration
Design decides whether to scope the atms-struct retirement in 9A or defer.

### §6.5 elab-speculation.rkt disposition
Delete (189 lines dead code + test file), retain-as-library, or migrate to pure-bitmask patterns. Audit lean: retain and migrate, since Phase 9C may want the structured speculation primitives for union-type branching. Design decides.

### §6.6 Hypercube integration depth
- Gray code into ATMS branch traversal (clearly in scope)
- Subcube pruning completeness (audit within scope)
- Tree-reduce default-on (optional optimization — may belong to parallel-scheduler track)
- Hypercube all-reduce for BSP barriers (is implemented — just need to validate adoption defaults)

### §6.7 ATMS-believed retirement timing
BSP-LE 2B D.1 finding: `atms-believed` is redundant with decision cells. Retirement blocked by continued deprecated-API usage. Options:
- (a) Retire in 9A alongside `atms` struct — expands scope
- (b) Retire after surface-AST migration completes (separate track) — preserves deprecated API
- (c) Partial retirement: internal uses migrate to solver-context; struct + field retained for surface AST only
Design decides.

### §6.8 Residuation for error-explanation
Per research §10.3: fuel-exhaustion error messages via backward-residuation walk. Implementation decision: in Phase 9+10, or defer to Phase 11b (diagnostic infrastructure)?

### §6.9 Parity test strategy for Phase 9+10
Per D.3 §9.1: each phase enables its parity-axis tests. Phase 9+10 doesn't have a clear single parity axis — it touches substrate. Options:
- (a) No new parity tests (substrate migration preserves behavior)
- (b) Tropical-fuel parity tests (fuel-exhaustion scenarios equivalent pre/post)
- (c) Union-types parity tests (union-type elaboration identical pre/post)
Lean: (b) + (c) minimal parity, targeted.

### §6.10 Drift risks for Phase 9+10 (VAG 5d checklist scaffold)
Audit captures candidate risks; Design finalizes named list for VAG:
- Silent-write-drop from worldview-filter (R2)
- Belt-and-suspenders (retired stack + retained fallback = smell)
- Tropical fuel semantic subtleties (min-merge correctness under speculation)
- Hypercube over-scoping (Phase 9B consumption of mostly-done infrastructure)
- BSP-LE relational coupling regression (Phase 9+10 accidentally depending on relational-layer primitives)

---

## §7 References

### §7.1 Prologos internal
- [`docs/research/2026-04-21_TROPICAL_QUANTALE_RESEARCH.md`](../research/2026-04-21_TROPICAL_QUANTALE_RESEARCH.md) (commit `de357aa1`)
- [`docs/research/2026-04-06_CELL_BASED_TMS_DESIGN_NOTE.md`](../research/2026-04-06_CELL_BASED_TMS_DESIGN_NOTE.md)
- [`docs/research/2026-04-08_HYPERCUBE_BSP_LE_DESIGN_ADDENDUM.md`](../research/2026-04-08_HYPERCUBE_BSP_LE_DESIGN_ADDENDUM.md)
- [`docs/research/2026-03-28_MODULE_THEORY_LATTICES.md`](../research/2026-03-28_MODULE_THEORY_LATTICES.md)
- [`docs/tracking/2026-04-17_PPN_TRACK4C_DESIGN.md`](2026-04-17_PPN_TRACK4C_DESIGN.md) § 6.10, 6.11.3, 6.15.6
- [`docs/tracking/2026-04-10_BSP_LE_TRACK2_PIR.md`](2026-04-10_BSP_LE_TRACK2_PIR.md)
- [`docs/tracking/2026-04-16_BSP_LE_TRACK2B_PIR.md`](2026-04-16_BSP_LE_TRACK2B_PIR.md)
- [`docs/tracking/handoffs/2026-04-20_PPN_4C_PHASE_9_HANDOFF.md`](handoffs/2026-04-20_PPN_4C_PHASE_9_HANDOFF.md)
- [`.claude/rules/propagator-design.md`](../../.claude/rules/propagator-design.md) (silent-write-drop hazard)
- [`.claude/rules/stratification.md`](../../.claude/rules/stratification.md) (stratum handler pattern)

### §7.2 Codebase files audited
- [`racket/prologos/propagator.rkt`](../../racket/prologos/propagator.rkt) — worldview paths, stratum handlers, tree-reduce, prop-network-fuel
- [`racket/prologos/relations.rkt`](../../racket/prologos/relations.rkt) — Gray code, NAF handler, fork-prop-network, tagged-cell-value
- [`racket/prologos/decision-cell.rkt`](../../racket/prologos/decision-cell.rkt) — Hamming, subcube, decisions-state, commitments-state
- [`racket/prologos/atms.rkt`](../../racket/prologos/atms.rkt) — deprecated atms + modern solver-context
- [`racket/prologos/elab-speculation.rkt`](../../racket/prologos/elab-speculation.rkt) — dead library code
- [`racket/prologos/elab-speculation-bridge.rkt`](../../racket/prologos/elab-speculation-bridge.rkt) — production with-speculative-rollback
- [`racket/prologos/typing-propagators.rkt`](../../racket/prologos/typing-propagators.rkt) — union branching, wrap-with-assumption-stack, classify-inhabit stratum
- [`racket/prologos/hasse-registry.rkt`](../../racket/prologos/hasse-registry.rkt) — Q_n override pattern
- [`racket/prologos/union-types.rkt`](../../racket/prologos/union-types.rkt) — canonical union construction
- [`racket/prologos/metavar-store.rkt`](../../racket/prologos/metavar-store.rkt) — save/restore speculation bridge
- [`racket/prologos/narrowing.rkt`](../../racket/prologos/narrowing.rkt) — stratum handler registration
- [`racket/prologos/sre-core.rkt`](../../racket/prologos/sre-core.rkt) — stratum handler registration
- [`racket/prologos/elaborator-network.rkt`](../../racket/prologos/elaborator-network.rkt) — stratum handler registration

---

## §8 Summary — what the audit tells us about Phase 9+10

### §8.1 Good news

- **Hypercube primitives are implemented** — Phase 9B is integration, not primary development
- **BSP-LE 2B substrate is production-ready** — tagged-cell-value, fork-prop-network, solver-context, stratum handlers all mature
- **Clear substrate vs relational-layer boundary** — Phase 9+10 can consume substrate without coupling to relational-layer
- **Union-types infrastructure is 90% in place** — Phase 9C is completion + integration, not foundational

### §8.2 Less-good news

- **BSP-LE 2B PIR overclaimed** — `current-speculation-stack` is not fully retired; residual sites persist
- **Parallel API surfaces** — deprecated `atms` struct + modern `solver-context`; surface AST uses the deprecated API
- **elab-speculation.rkt is dead library code** — 189 lines + test file with no production consumers
- **prop-network-fuel is heavily coupled** — 15+ decrement/check sites throughout propagator.rkt; migration non-trivial

### §8.3 Phase 9+10 work-volume estimate (revised)

Pre-audit (per handoff + design note): ~450 lines new infrastructure, 4 sub-phases.

Post-audit revision:
- Substrate reconciliation: ~200-300 lines of cleanup (retire stack + fallbacks, migrate wrap-with-assumption-stack)
- Tropical fuel cell: ~150-250 lines (new cell, new threshold propagator, retire counter + 15 sites)
- Hypercube integration: ~50-100 lines (wire Gray code, complete subcube coverage)
- Union-types via ATMS: ~100-200 lines (branch ordering + error-explanation)
- **Phase 11 orchestration** (added 2026-04-21): ~150-250 lines (3 stratum handler registrations; retire `run-stratified-resolution-pure`; delete dead code)
- **Total: ~650-1100 lines** — higher than pre-audit estimate because substrate reconciliation has more residual sites than the handoff suggested, plus Phase 11 inclusion

### §8.4 What Design (Stage 3) should produce

1. Phase partitioning decision (§5.1 vs §5.2)
2. Tropical quantale sub-class + granularity decisions (§6.2, §6.3)
3. Retirement scope decision for `atms` struct / believed field (§6.4, §6.7)
4. elab-speculation.rkt disposition (§6.5)
5. Residuation-for-error-explanation placement (§6.8)
6. Parity test strategy (§6.9)
7. VAG drift-risk finalized list (§6.10)
8. Sub-phase dependency graph with commit targets
9. Tropical fuel cell specific design (min-merge semantics, budget cell shape, threshold propagator, residuation mechanism)
10. Open-question resolutions from tropical research §11.1-§11.7

---

## Document status

**Stage 2 audit complete**. Ready for Stage 3 design dialogue.

Next deliverable: [`docs/tracking/2026-04-21_PPN_4C_PHASE_9_DESIGN.md`](2026-04-21_PPN_4C_PHASE_9_DESIGN.md) (TBD — after design dialogue resolves the open questions in §6).

The audit reframes the Phase 9+10 scope based on code reality: less foundational development, more reconciliation and polish. The tropical fuel cell is the largest new-development item; everything else is integration of substrate that BSP-LE Track 2+2B shipped.
