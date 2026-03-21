# PM Track 8: Propagator Infrastructure Migration — Stage 3 Design

**Date**: 2026-03-21
**Status**: Draft (D.1 — awaiting critique)
**Parent**: Propagator Migration Series ([Master Roadmap](2026-03-13_PROPAGATOR_MIGRATION_MASTER.md))
**Audit**: [Track 8 Infrastructure Audit](2026-03-18_TRACK8_PROPAGATOR_INFRASTRUCTURE_AUDIT.org)
**Informed by**: [CIU Track 0 Trait Hierarchy Audit](2026-03-21_CIU_TRACK0_TRAIT_HIERARCHY_AUDIT.md), [Allocation Audit](2026-03-20_CELL_PROPAGATOR_ALLOCATION_AUDIT.md)
**Prior art**: Tracks 1–7 (complete), PUnify Parts 1–2 (cell-tree unification)
**Supersedes**: Track 8 audit §5 (architectural vision) — this document makes it concrete

---

## Progress Tracker

| # | Phase | Description | Status | Commit | Notes |
|---|-------|-------------|--------|--------|-------|
| — | **Part A: Infrastructure Migration** | | | | |
| A0 | Acceptance file | Baseline canary + aspirational tests | ⬜ | | |
| A1 | Meta-info TMS-awareness | `meta-info` CHAMP → TMS-managed field | ⬜ | | Enables `restore-meta-state!` retirement |
| A2 | Id-map accessibility | `id-map` accessible from prop-net layer | ⬜ | | Unblocks mult bridge wiring |
| A3 | Mult/Level/Session on elab-network | Merge CHAMP boxes into elab-network cells | ⬜ | | Per-meta domain cells |
| A4 | `restore-meta-state!` retirement | Replace box snapshot with TMS rollback | ⬜ | | Depends on A1-A3 |
| A5 | Resolution state simplification | Remove imperative flags | ⬜ | | Low-risk cleanup |
| — | **Part B: HKT Resolution + Module Restructuring** | | | | |
| B0 | Module graph analysis | Map circular deps, design extraction | ⬜ | | |
| B1 | Cell-ops extraction | Factor cell operations into importable module | ⬜ | | Breaks metavar-store ↔ elab-network cycle |
| B2 | Root callback elimination | Inline `cell-read`/`cell-write` (63 sites) | ⬜ | | Depends on B1 |
| B3 | HKT `impl` registration | `impl Seq List` works and registers in trait system | ⬜ | | Depends on B2 (needs direct trait-resolution access) |
| B4 | HKT trait resolution on propagator network | Readiness propagators resolve HKT constraints | ⬜ | | Depends on B3 |
| B5 | Sugar constraint generation | `surf-get` generates Indexed/Keyed constraints | ⬜ | | Depends on B4; validates CIU vision |
| B6 | Verification + benchmarks | Full suite + A/B comparison + acceptance | ⬜ | | |

---

## 1. Problem Statement

### What Tracks 1–7 Delivered

Seven tracks systematically migrated elaboration state onto the propagator network:
- 42 state sites have cells (Foundation Sprint)
- Constraint tracking is cell-primary (Track 1)
- Resolution is reactive via stratified quiescence S0→S1→S2 (Track 2)
- 28 registry readers are cell-primary (Track 3)
- Speculation uses TMS cells with learned-clause pruning (Track 4)
- Global-env is cell-backed with dependency edges (Track 5)
- Driver simplified, callbacks identified as anti-pattern (Track 6)
- 29 persistent registry cells, S(−1) retraction, readiness propagators, pure resolution (Track 7)

### What Remains

Two categories of work remain, corresponding to the two Parts:

**Part A — Infrastructure migration**: The elab-network's structural fields (`meta-info`, `id-map`, `next-meta-id`) are not TMS-managed. `restore-meta-state!` still exists as a box-snapshot mechanism. Mult/level/session meta stores are separate CHAMP boxes, not cells in the elab-network. This prevents clean speculation rollback and cross-domain bridges.

**Part B — HKT resolution + module restructuring**: 12 callback parameters exist to break circular module dependencies. The root callbacks (`cell-read`/`cell-write`, 63 sites) prevent `surf-get` from generating trait constraints that flow through the propagator network. And `impl` doesn't work for HKT traits — the critical gap identified by CIU Track 0 (F-6). Without HKT resolution, the CIU vision (trait-dispatched collection access) is structurally impossible.

### Why This Order

Part A is prerequisite for Part B:
- `id-map` accessibility (A2) is needed for the cell-ops extraction (B1)
- TMS-aware meta-info (A1) is needed for clean speculation in the restructured module graph
- `restore-meta-state!` retirement (A4) simplifies the state model that B1-B2 must preserve

Part B is the capability-adding part — it changes what the system can *do* (resolve HKT traits, generate sugar constraints). Part A is plumbing — it changes how the system *works* internally.

---

## 2. Architecture: Option C (Confirmed)

The Track 8 audit recommended **Option C: Two networks with domain tags**. This design confirms that recommendation based on Track 7's success with the two-network architecture.

### Current Architecture (Post-Track 7)

```
persistent-registry-net-box    elab-network (per-command)
  29 cells (macros,              prop-net: type cells, unify propagators
   warnings, narrowing)          cell-info, meta-info, id-map
  file-scoped, monotone          14 scoped infra cells (constraints, readiness)
                                 next-meta-id counter
                                 ───────────────────
                                 NOT on network:
                                   mult CHAMP box
                                   level CHAMP box
                                   session CHAMP box
                                   restore-meta-state! box snapshot
```

### Target Architecture (Post-Track 8)

```
persistent-registry-net-box    elab-network (per-command)
  29 cells (unchanged)           prop-net: type cells, unify propagators
  file-scoped, monotone                    mult cells (per-meta)
                                           level cells (per-meta)
                                           session cells (per-meta)
                                 meta-info: TMS-managed CHAMP
                                 id-map: accessible from prop-net layer
                                 14 scoped infra cells (unchanged)
                                 ───────────────────
                                 Removed:
                                   restore-meta-state! (→ TMS rollback)
                                   mult/level/session CHAMP boxes (→ cells)
                                   12 callback parameters (→ direct calls)
                                 Added:
                                   HKT impl registration in trait system
                                   surf-get generates Indexed/Keyed constraints
```

---

## 3. Part A: Infrastructure Migration

### Phase A0: Acceptance File

Extend an existing acceptance file (or create a new one) with sections that exercise:
- Speculation rollback (Church folds, union types) — should work identically post-TMS migration
- Cross-domain constraints (type → mult, type → level) — should resolve without separate CHAMP boxes
- Trait resolution (existing non-HKT traits) — regression canary

### Phase A1: Meta-Info TMS-Awareness

**Goal**: Make `elab-network.meta-info` (CHAMP: meta-id → meta-info) TMS-managed.

**Current state**: `meta-info` is a struct field of `elab-network`. `save-meta-state` captures it via box snapshot. `restore-meta-state!` reinstates the old snapshot. This is the JTMS-style single-context pattern that Track 4's TMS was supposed to replace.

**Design**: Convert `meta-info` to a TMS-aware field. Options:
1. **Dedicated TMS cell** holding the entire CHAMP. Writes go through `net-cell-write` with a merge function that unions meta-info entries. Retraction via S(−1) tagged entries.
2. **Per-meta TMS tagging** within the existing CHAMP. Each meta-info entry tagged with an assumption-id. Retraction filters by tag (same pattern as scoped infrastructure cells).

Option 2 is more granular and aligns with Track 7's assumption-tagging discipline. The scoped cells already use `tagged-entry` structs with assumption IDs — the same pattern applies to meta-info entries.

**Key constraint**: `meta-info` is read by `meta-solution`, `ground-expr?`, and `solve-meta!` — all hot-path operations. The TMS tagging must not add measurable overhead to reads. The current `champ-lookup` is O(log₃₂ n); adding a tag check is O(1) per lookup. Acceptable.

**Files**: `metavar-store.rkt` (meta-info access), `elab-speculation-bridge.rkt` (save/restore), `elaborator-network.rkt` (struct definition)

### Phase A2: Id-Map Accessibility

**Goal**: Make `elab-network.id-map` (CHAMP: meta-id → cell-id) accessible from the `prop-net` layer.

**Current state**: `id-map` is an `elab-network` struct field. Code at the `prop-net` level (propagator fire functions, decomposition) cannot access it without going through callbacks. This blocks mult bridge wiring in `decompose-pi` (Track 7 PIR §10.3).

**Design**: Extract `id-map` into a shared location accessible from both `elab-network` and `prop-net` contexts. Options:
1. **Add `id-map` to `prop-network` struct**. Simple but widens the prop-net abstraction beyond its current scope.
2. **Dedicated parameter** `current-id-map` alongside `current-prop-net-box`. Populated from elab-network during `process-command`.
3. **Cell-ops module** (see B1) that provides `meta-id->cell-id` as a function, reading from whichever context is active.

Option 2 is simplest for Part A — it unblocks mult bridge wiring immediately. Option 3 is the principled solution that Part B will deliver. Part A can use Option 2 as a stepping stone.

**Files**: `elaborator-network.rkt`, `metavar-store.rkt`, `propagator.rkt` (if adding field)

### Phase A3: Mult/Level/Session on Elab-Network

**Goal**: Merge `current-mult-meta-champ-box`, `current-level-meta-champ-box`, `current-sess-meta-champ-box` into per-meta cells on the elab-network.

**Current state**: Each domain has its own CHAMP box (`make-hasheq`), populated and read independently. `save-meta-state` captures all three boxes. They are not cells — they don't participate in propagation.

**Design**: When `elab-fresh-meta` creates a type meta, also create corresponding mult/level/session cells in the same elab-network. Cross-domain bridges (type → mult, type → level) become propagators within the network.

**Sub-phases**:
- **A3a**: Mult cells on elab-network. `elab-fresh-mult-cell` already exists (Track 4) — wire it into `elab-fresh-meta`. Remove `current-mult-meta-champ-box`.
- **A3b**: Level cells on elab-network. Similar to A3a.
- **A3c**: Session cells on elab-network. Similar but more complex — session cells have their own lattice and decomposition.
- **A3d**: Wire cross-domain bridges. `decompose-pi` can now create mult bridge propagators (A2 provided id-map access).

**Files**: `metavar-store.rkt`, `elaborator-network.rkt`, `qtt.rkt` (mult reads), `session-propagators.rkt`

### Phase A4: `restore-meta-state!` Retirement

**Goal**: Remove `save-meta-state`/`restore-meta-state!` box-snapshot mechanism. Replace with TMS-based rollback.

**Prerequisite**: A1 (meta-info TMS-aware), A3 (mult/level/session on network — so all four domains are TMS-managed).

**Design**: `with-speculative-rollback` already uses TMS assumptions for type cells. After A1-A3, meta-info and all domain stores are also TMS-managed. `save-meta-state` becomes: push an assumption onto the speculation stack. `restore-meta-state!` becomes: retract the assumption (S(−1) handles cleanup). `commit` becomes: keep the assumption (no-op — it's already in the network).

**Risk**: `save-meta-state` currently captures 6 boxes. All 6 must be TMS-managed before this phase. Verify each:
1. `current-prop-net-box` — already TMS-managed (Track 4)
2. `current-meta-store` — covered by A1
3. `current-mult-meta-champ-box` — covered by A3a
4. `current-level-meta-champ-box` — covered by A3b
5. `current-sess-meta-champ-box` — covered by A3c
6. `current-speculation-failures` — diagnostic, not constraint-like (can be excluded or handled separately)

**Files**: `elab-speculation-bridge.rkt`, `metavar-store.rkt`, `batch-worker.rkt`, `test-support.rkt`

### Phase A5: Resolution State Simplification

**Goal**: Remove `current-in-stratified-resolution?` flag and `current-stratified-progress-box`.

**Current state**: These are re-entrancy guards and progress signals for the stratified resolution loop. Track 7 Phase 7b introduced `eq?` identity detection on the network struct, making the progress box redundant. The re-entrancy flag guards against recursive resolution, which should be structurally prevented by the layered scheduler.

**Design**: Remove both. Verify no re-entrancy via test cases.

**Files**: `metavar-store.rkt`, `resolution.rkt`

---

## 4. Part B: HKT Resolution + Module Restructuring

### Phase B0: Module Graph Analysis

**Goal**: Map the circular dependency graph between metavar-store.rkt, elaborator-network.rkt, type-lattice.rkt, reduction.rkt, and trait-resolution.rkt. Identify the minimal extraction that breaks all cycles.

**Output**: A module dependency diagram showing: current cycles, proposed extraction points, and the target acyclic graph.

**Key analysis from the Track 8 audit (§5.2.2)**:
```
metavar-store.rkt ←needs cell ops← elaborator-network.rkt
      ↑                                    |
      └──── provides meta infrastructure ──┘
```

The audit recommended: extract cell-operation API into a `cell-ops.rkt` that both can import.

### Phase B1: Cell-Ops Extraction

**Goal**: Extract `elab-cell-read`, `elab-cell-write`, `elab-cell-replace`, and `id-map` access into a standalone `cell-ops.rkt` module.

**Design**: `cell-ops.rkt` provides:
- `cell-read : net-box → cell-id → value`
- `cell-write : net-box → cell-id → value → void`
- `cell-replace : net-box → cell-id → value → void`
- `meta-id->cell-id : net-box → meta-id → cell-id`

All read from `(current-prop-net-box)` and unwrap elab-network → prop-network. No circular dependency — `cell-ops.rkt` depends only on `propagator.rkt` and `elab-network struct definitions` (which can be factored into a separate types module if needed).

**Files**: New `cell-ops.rkt`; `metavar-store.rkt` (replace callback calls); `elaborator-network.rkt` (delegate)

### Phase B2: Root Callback Elimination

**Goal**: Remove 12 callback parameters. Replace all 63 `current-prop-cell-read` call sites and 15 `current-prop-cell-write` call sites with direct calls to `cell-ops.rkt`.

**Sub-phases**:
- **B2a**: Replace `cell-read`/`cell-write` calls in `metavar-store.rkt` (48 + 15 sites)
- **B2b**: Replace remaining callbacks (make-network, fresh-meta, add-propagator, etc.)
- **B2c**: Remove `install-prop-network-callbacks!` from `driver.rkt`
- **B2d**: Remove all 12 callback parameter definitions

**Risk**: High site count (63). Mechanical but error-prone. Use grep-driven replacement with per-file test validation.

**Files**: `metavar-store.rkt`, `driver.rkt`, `cell-ops.rkt`

### Phase B3: HKT `impl` Registration

**Goal**: Make `impl Seq List`, `impl Indexed PVec`, `impl Keyed Map` syntactically valid and semantically operational.

**Current state**: `impl` works for non-HKT traits (e.g., `impl Eq Nat`). The elaborator's `elaborate-impl` produces a dict binding and registers it in the trait resolution system. For HKT traits, the type constructor argument (`List` in `impl Seq List`) needs to be handled as a `Type -> Type` argument, not a concrete type.

**Design areas**:
1. **Parser**: `impl` with a type constructor argument (already works syntactically — `impl Trait Constructor`).
2. **Elaborator**: `elaborate-impl` must recognize HKT trait parameters and produce the correct dict binding. The dict type is `Seq List` (applying the trait's HKT parameter to the constructor).
3. **Trait resolution**: `resolve-trait-constraints!` must match `Seq ?C` against `impl Seq List` when `?C` is solved to `List`. The readiness propagator watches the type cell for `?C`; when it becomes ground (`List`), resolution fires and looks up `impl Seq List`.
4. **Instance store**: The trait instance registry (`current-trait-impl-registry` or equivalent persistent cell) must store HKT instances keyed by `(trait-name, constructor-name)`.

**This is the architecturally novel phase.** Non-HKT resolution keys on `(trait-name, concrete-type)`. HKT resolution keys on `(trait-name, type-constructor)`. The type constructor must be extracted from the solved type: `PVec Int` → constructor is `PVec`. This extraction already happens in `expr->impl-key-str` (trait-resolution.rkt) for non-HKT types — it needs to handle constructor extraction for compound types.

**Files**: `elaborator.rkt`, `trait-resolution.rkt`, `metavar-store.rkt` (registry cells)

### Phase B4: HKT Trait Resolution on Propagator Network

**Goal**: HKT trait constraints (`Seq ?C` where `?C` is an unsolved meta) resolve automatically when `?C` becomes ground.

**Design**: This uses the existing Track 7 readiness propagator infrastructure:
1. When the elaborator encounters a `Seq C` constraint (from a `where` clause or generated by sugar):
   - If `C` is ground → resolve immediately (lookup `impl Seq C`)
   - If `C` is an unsolved meta → create a readiness propagator watching `C`'s type cell
2. When `C`'s type cell becomes ground (e.g., solved to `List`):
   - The readiness propagator fires
   - The resolution propagator looks up `impl Seq List`
   - The dict meta is solved with the instance dict
3. The elaborated code receives the dict through normal meta solution — just like any other trait resolution.

**Key question**: Does the readiness propagator need to extract the type constructor from a compound type? E.g., if the constraint is `Indexed ?C` and `?C` is solved to `PVec Int`, the readiness propagator needs to recognize that the constructor is `PVec` and look up `impl Indexed PVec`. This constructor extraction is the same operation identified in B3 item 4.

**Files**: `trait-resolution.rkt`, `metavar-store.rkt`

### Phase B5: Sugar Constraint Generation

**Goal**: `surf-get` generates `Indexed C` or `Keyed C K V` constraints instead of producing dict-free `expr-get`.

**Design** (from [CIU Unification Design](2026-03-20_COLLECTION_INTERFACE_UNIFICATION_DESIGN.md) §3):

```
surf-get coll key
  → infer type of coll
  → if type constructor implements Indexed: generate Indexed constraint,
    elaborate to [idx-nth $dict coll key]
  → if type constructor implements Keyed: generate Keyed constraint,
    elaborate to [kv-get $dict coll key]
  → if Schema/Selection: preserve expr-map-get (schema narrowing)
  → if type is unsolved meta: generate deferred constraint
    (readiness propagator fires when type arrives)
  → fallback: expr-get (backward compat during migration)
```

**This is a validation phase, not a new mechanism.** B3 and B4 provide the infrastructure; B5 wires it into the existing `surf-get` elaboration site. The actual change to `elaborator.rkt` is small — replace `(expr-get ec ek)` with constraint generation + dict-dispatched method call.

**Files**: `elaborator.rkt` (surf-get), `typing-core.rkt` (expr-get typing — becomes vestigial)

### Phase B6: Verification + Benchmarks

- Full test suite (7308+ tests, target ≤200s)
- A/B benchmark comparison: `bench-ab.rkt` vs pre-Track 8 baseline
- Acceptance file: all sections pass at Level 3
- CIU validation: `xs[0]` on a user-defined `impl Indexed MyVec` works
- Speculation validation: Church folds and union types still resolve correctly (TMS-based rollback)

---

## 5. Design Decisions

| # | Decision | Resolution | Rationale |
|---|----------|------------|-----------|
| D1 | Network architecture | Option C: two networks + domain tags | Proven by Track 7; persistent vs per-command is the right lifecycle split |
| D2 | Meta-info TMS mechanism | Per-entry assumption tagging (not dedicated cell) | Aligns with Track 7's tagged-entry pattern; granular retraction |
| D3 | Id-map accessibility (Part A) | Dedicated parameter (stepping stone) | Unblocks mult bridge immediately; Part B's cell-ops extraction is the permanent solution |
| D4 | Module restructuring | Cell-ops extraction (Option 1 from audit) | Minimal extraction that breaks all cycles; no module merge, no parameter pollution |
| D5 | HKT impl key | `(trait-name, type-constructor)` extracted from solved type | Natural extension of existing `expr->impl-key-str`; constructor extraction from `PVec Int` → `PVec` |
| D6 | Backward compatibility | `expr-get` fallback during B5 migration | Gradual — sugar generates constraints when possible, falls back to constructor dispatch otherwise |
| D7 | Part A/B ordering | A before B; A4 (restore retirement) before B1 (cell-ops extraction) | TMS-clean state model simplifies module restructuring |

---

## 6. Test Strategy

### Part A

| Phase | Level 1 | Level 2 | Level 3 |
|-------|---------|---------|---------|
| A1 | Meta-info TMS: speculation rollback | — | Acceptance file: Church folds |
| A2 | Id-map reads from prop-net context | — | — |
| A3 | Mult/level/session cells: cross-domain bridges | — | Acceptance file: session types |
| A4 | Speculation without `restore-meta-state!` | — | Full suite regression |
| A5 | Resolution loop without flags | — | Full suite regression |

### Part B

| Phase | Level 1 | Level 2 | Level 3 |
|-------|---------|---------|---------|
| B1-B2 | Cell ops: read/write through extracted module | — | Full suite (behavioral parity) |
| B3 | `impl Seq List` registers in trait system | `impl Indexed PVec` | — |
| B4 | HKT constraint resolves on ground type | `where (Seq C)` in spec | Acceptance: generic Seq ops |
| B5 | `xs[0]` generates Indexed constraint | `pv[0]` on PVec | Acceptance: user-defined Indexed |
| B6 | A/B benchmarks, full suite, acceptance | — | Level 3 on all acceptance sections |

---

## 7. Key Files

| File | Part A | Part B |
|------|--------|--------|
| `metavar-store.rkt` | A1: meta-info TMS, A4: restore retirement | B2: callback elimination (63 sites) |
| `elaborator-network.rkt` | A2: id-map access, A3: mult/level/session cells | B1: cell-ops delegate |
| `elab-speculation-bridge.rkt` | A1, A4: TMS-based speculation | — |
| `propagator.rkt` | — | — (sufficient from Track 7) |
| `resolution.rkt` | A5: flag removal | — |
| `qtt.rkt` | A3a: mult reads from elab-network | — |
| `session-propagators.rkt` | A3c: session cells on elab-network | — |
| `driver.rkt` | — | B2c: remove callback installation |
| `trait-resolution.rkt` | — | B3: HKT impl lookup, B4: HKT readiness |
| `elaborator.rkt` | — | B5: surf-get constraint generation |
| `typing-core.rkt` | — | B5: expr-get becomes vestigial |
| New: `cell-ops.rkt` | — | B1: extracted cell operations |
| `batch-worker.rkt` | A4: simplified (fewer params to snapshot) | B2: simplified (fewer params) |
| `test-support.rkt` | A4: simplified | B2: simplified |

---

## 8. Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| A1 TMS tagging adds overhead to hot-path meta-info reads | Low | Medium | Benchmark before/after; tag check is O(1) |
| A4 `restore-meta-state!` retirement exposes hidden state | Medium | High | Comprehensive speculation tests before removing |
| B2 63-site callback replacement introduces regressions | Medium | Medium | Per-file test validation; mechanical replacement |
| B3 HKT `impl` interacts badly with existing trait resolution | Medium | High | Isolated test file for HKT resolution before wiring into production |
| B5 Deferred constraints (unsolved meta) create ordering issues | Low | Medium | Track 7's readiness propagators handle this; test with delayed type solving |
| Performance regression from trait dispatch vs. hardcoded dispatch | Low | Medium | A/B benchmarks; `expr-get` fallback preserves performance for known types |

---

## 9. Cross-Track Requirements (Provided to CIU and BSP-LE)

Track 8 provides the following to downstream Series:

| Capability | CIU Track | BSP-LE Track | Phase |
|------------|-----------|--------------|-------|
| HKT `impl` registration | Track 1 (Seq-as-trait) | — | B3 |
| HKT trait resolution on network | Tracks 3-5 (trait-dispatched dispatch) | — | B4 |
| Sugar constraint generation | Track 3 (surf-get Indexed/Keyed) | — | B5 |
| Callback elimination | All (cleaner elaboration paths) | Track 2 (ATMS solver integration) | B2 |
| Module restructuring | All (elaborator ↔ trait-resolution access) | — | B1 |
| TMS-clean speculation | — | Track 2 (worldview management) | A4 |

---

## 10. Deferred / Out of Scope

- **Reduction as propagators** (Track 8 audit §5.7): Term rewriting on-network. Research territory.
- **Elaboration context as cells** (Track 8 audit §5.8): Typing contexts as cell values. Research territory.
- **Memo caches as cells** (Track 8 audit §1.9): Not constraint-like; keep imperative.
- **Map HKT partial application** (`Map K` as `Type -> Type`): Important for Map to implement Foldable/Seq, but a separate type-system feature. Not Track 8 scope.
- **Observation cells** (P3 in audit): Performance counters and observatory as cells for LSP. Future Track 9/10 scope.
