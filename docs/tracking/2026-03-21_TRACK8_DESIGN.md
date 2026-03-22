# PM Track 8: Propagator Infrastructure Migration — Stage 3 Design

**Date**: 2026-03-21
**Status**: Draft (D.1.1 — Part C added; awaiting critique)
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
| B2 | Root callback elimination | Inline `cell-read`/`cell-write` (63 sites) | ⬜ | | Depends on B1. Sub-phases B2a-B2d |
| B2e | Macros parameter write cleanup | Remove 24 dual-writes; cell-only writes after B2 | ⬜ | | Natural cleanup once cell reads are universal |
| B2f | Accumulate-during-quiescence | Owner-ID transient threading through cell-ops for quiescence loop | ⬜ | | Depends on B1-B2. Zero CHAMP allocation on hot path. See [CHAMP Performance](2026-03-21_CHAMP_PERFORMANCE_DESIGN.md) §Accumulate |
| B3 | HKT `impl` registration | `impl Seq List` works and registers in trait system | ⬜ | | Depends on B2 (needs direct trait-resolution access) |
| B4 | HKT trait resolution on propagator network | Readiness propagators resolve HKT constraints | ⬜ | | Depends on B3 |
| B5 | Sugar constraint generation | `surf-get` generates Indexed/Keyed constraints | ⬜ | | Depends on B4; validates CIU vision |
| B6 | Verification + benchmarks | Full suite + A/B comparison + acceptance | ⬜ | | |
| — | **Part C: All Constraint Resolution as Propagators** | | | | |
| C0 | Layered scheduler | Tag propagators with strata; worklist respects priority | ⬜ | | S0 drains before S1 fires, etc. Foundation for C1-C3 |
| C1 | Deterministic trait resolution as S0 propagators | Single-instance traits resolve directly in S0 | ⬜ | | Monotone: refines B4's readiness→S2 into direct S0 resolution |
| C2 | Hasmethod resolution as propagators | `hasmethod` constraints fire when type cell grounds | ⬜ | | Same pattern as C1 |
| C3 | Constraint retry as propagators | Deferred constraints watch dependency cells, fire when ground | ⬜ | | Replaces imperative retry loop |
| C4 | S2 scope reduction | S2 handles only genuinely non-monotone commitment | ⬜ | | Stratified loop: one S0 pass + rare S2, not iterative cycle |
| C5 | Verification + benchmarks | Resolution cycle count, fuel consumption, ordering stability | ⬜ | | Target: fewer iterations, same results |

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

Three categories of work remain, corresponding to three Parts:

**Part A — Infrastructure migration**: The elab-network's structural fields (`meta-info`, `id-map`, `next-meta-id`) are not TMS-managed. `restore-meta-state!` still exists as a box-snapshot mechanism. Mult/level/session meta stores are separate CHAMP boxes, not cells in the elab-network. This prevents clean speculation rollback and cross-domain bridges.

**Part B — HKT resolution + module restructuring**: 12 callback parameters exist to break circular module dependencies. The root callbacks (`cell-read`/`cell-write`, 63 sites) prevent `surf-get` from generating trait constraints that flow through the propagator network. And `impl` doesn't work for HKT traits — the critical gap identified by CIU Track 0 (F-6). Without HKT resolution, the CIU vision (trait-dispatched collection access) is structurally impossible.

**Part C — All constraint resolution as propagators**: The stratified quiescence loop (S0→S1→S2) dissolves into the propagator network for all monotone operations. Trait constraints, hasmethod checks, and deferred constraints become S0 propagators that fire when their dependencies are ground. The loop persists only for genuinely non-monotone commitment. This eliminates the ordering fragility between type inference and trait resolution that surfaced in the CIU acceptance file — constraints resolve in the same S0 pass as type solving, not on a subsequent loop iteration.

### Why This Order

Part A is prerequisite for Part B:
- `id-map` accessibility (A2) is needed for the cell-ops extraction (B1)
- TMS-aware meta-info (A1) is needed for clean speculation in the restructured module graph
- `restore-meta-state!` retirement (A4) simplifies the state model that B1-B2 must preserve

Part B is prerequisite for Part C:
- HKT `impl` registration (B3) provides the instances that Part C's resolution propagators look up
- Callback elimination (B2) provides the direct call paths that resolution propagators use
- Module restructuring (B1) provides the import structure that resolution propagators need

Part A is plumbing (changes how the system works). Part B adds capabilities (changes what the system can do). Part C is the architectural capstone (unifies type inference and constraint resolution under a single propagator-driven model).

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

**Design-for note — accumulate-during-quiescence pattern** (from [CHAMP Performance Design](2026-03-21_CHAMP_PERFORMANCE_DESIGN.md) §Accumulate-During-Quiescence): After B2 eliminates callbacks, the quiescence loop can thread an owner-ID transient through `cell-write` — enabling in-place cell mutation during quiescence with O(modified-nodes) freeze at exit. The `cell-ops.rkt` API should accommodate an optional transient parameter (or a thread-local `current-quiescence-transient` parameter) so this pattern can be implemented as a follow-on without re-designing the API. This is the highest-value application of the owner-ID transient infrastructure (CHAMP Performance Phases 4-6).

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

### Phase B2e: Macros Parameter Write Cleanup

**Goal**: Remove 24 dual-writes (cell + parameter) in `macros.rkt` registry functions. After B2's callback elimination, cell reads are universal — the parameter writes are dead code.

**Current state**: Track 7 retained parameter writes for module-load-time seeding. Each `register-*!` function writes to both the persistent cell and the Racket parameter. After B2, all reads go through `cell-ops.rkt` → cell reads. The parameter writes serve no consumer.

**Design**: For each of the 24 registry functions (`register-schema!`, `register-ctor!`, `register-type-meta!`, etc.): remove the `(current-*-registry (hash-set ...))` parameter write. Retain the cell write. Verify that no module-load-time code path reads the parameter directly — Track 3 PIR confirmed all computation reads are cell-primary, and B2 converts the remaining callback-based reads.

**Files**: `macros.rkt` (24 sites), `test-support.rkt` (verify no parameter reads remain)

### Phase B2f: Accumulate-During-Quiescence

**Goal**: The quiescence loop operates on an owner-ID transient of the cells CHAMP. Cell writes mutate in place during quiescence; freeze produces the persistent result at exit. Zero CHAMP allocation on the hot path.

**Prerequisite**: B1 (cell-ops extraction) + B2 (callback elimination). Without callbacks, `cell-write` in `cell-ops.rkt` can accept a transient parameter directly.

**Design** (from [CHAMP Performance Design](2026-03-21_CHAMP_PERFORMANCE_DESIGN.md) §Accumulate-During-Quiescence):

1. Enter `run-to-quiescence-drain` → convert cells CHAMP to owned transient (O(1) — get edit token)
2. Quiescence loop: propagator fire functions call `cell-write` → `tchamp-insert-owned!` (in-place mutation of owned nodes)
3. On quiescence exit → `tchamp-freeze-owned` clears edit fields (O(modified nodes))
4. Return persistent network with frozen cells

**Threading approach** (Option A — same pattern as Track 0 Phase 3c mutable worklist): The owned-transient cells reference is held as a local mutable in the quiescence loop, NOT stored in the `prop-network` struct. `cell-ops.cell-write` reads the transient from a thread-local parameter `(current-quiescence-transient)`. Fire functions are unaware of the transient — they call `cell-write` normally; the transient threading is internal to the quiescence infrastructure.

**Impact**: BSP-LE Track 0 measured 0ms GC during quiescence (from the mutable worklist). B2f extends this to the cells CHAMP — the last remaining source of per-cell-write allocation in the quiescence loop. Combined with CHAMP Performance's owner-ID transients (16× faster than hash-table transients), this is the path to the wall-time improvement that Track 0 targeted.

**Files**: `propagator.rkt` (quiescence loop), `cell-ops.rkt` (transient-aware cell-write), `champ.rkt` (owner-ID transient API — already implemented)

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

## 5. Part C: All Constraint Resolution as Propagators

### Thesis

The stratified quiescence loop (S0→S1→S2, iterated with fuel) dissolves into the propagator network for all monotone operations. The loop persists only for genuinely non-monotone commitment (ambiguous instance selection). This is the architectural capstone of the Propagator Migration Series — the type checker becomes a single propagator network where trait constraints, hasmethod checks, and deferred constraints are propagators alongside type unification.

### Categorical Motivation: Kan Extensions

The BSP-LE categorical analysis ([BSP-LE Master Roadmap](2026-03-21_BSP_LE_MASTER.md), standup 2026-03-21 §Outside Conversation) identified two adjoint mechanisms from the Kan extension framework:

**Left Kan extension (speculative forwarding)**: Given partial information at stratum n, compute the best possible information at stratum n+1 without waiting for n to complete. Monotonicity guarantees the speculative result is a sound lower bound — it never needs retraction, only refinement.

**Right Kan extension (demand-driven computation)**: Given a requirement at stratum n+1, compute the minimal sufficient computation at stratum n. Only propagate what downstream actually needs, not everything.

Part C instantiates both:
- **C1 (resolution in S0) IS the left Kan extension**: A resolution propagator fires on partial fixpoint information (a type cell just solved, but S0 hasn't fully quiesced). Monotonicity of the non-overlapping instance invariant guarantees the result is sound — resolution produces the correct dict even if other type cells haven't been solved yet, because the dict depends only on the type constructor (which is ground), not on the full type (which may have unsolved arguments).
- **C0 (layered scheduler with demand-driven quiescence) instantiates the right Kan extension**: The scheduler doesn't need to drain all S0 propagators before checking if demanded cells have stabilized. If a resolution propagator's dependency is already ground, it fires immediately — S0 doesn't need to fully quiesce for constraints whose dependencies are already met.

The Kan extensions are adjoint — speculative forwarding of demanded cells gives the same result as waiting for completion and extracting what's needed. This adjunction is the categorical proof that Part C's interleaved scheduling produces identical results to the current sequential S0→S1→S2 loop.

### Why This Matters

The S0→S1→S2 cycle introduces ordering fragility: a type cell solved in S0 triggers readiness in S1, which triggers resolution in S2, which may solve another type cell that triggers another S0 pass. For nested constraints (e.g., `Seq (List Int)` where resolving `Seq` depends on `List`'s type constructor), this multi-cycle resolution can fail to converge within the fuel limit. Making resolution propagator-driven eliminates the cycles — constraints resolve as soon as their dependencies are ground, within the same S0 pass.

This directly addresses the acceptance file issues that motivated the CIU Series: `surf-get` generating trait constraints needs those constraints to resolve reliably. With Part B, they resolve through the S1→S2 loop (correct but fragile). With Part C, they resolve as S0 propagators (correct and robust).

### Phase C0: Layered Scheduler

**Goal**: Replace the flat worklist with a priority-ordered layered scheduler. Propagators tagged with their stratum; the worklist drains higher-priority (lower-numbered) strata before lower-priority ones.

**Current state**: `run-to-quiescence-inner` pops propagators from a flat list. The stratified behavior is implemented *outside* the quiescence loop — `run-stratified-resolution-pure` in `metavar-store.rkt` calls S0 quiescence, then manually processes S1 (readiness), then S2 (resolution), then loops.

**Design**: Each propagator gets a `stratum` tag at creation time:
- Stratum 0: Type unification, decomposition, reconstruction propagators
- Stratum 1: Readiness detection propagators (threshold cells)
- Stratum 2: Resolution commitment propagators (after C1-C3, only ambiguous cases)

`run-to-layered-quiescence` drains the worklist in priority order: all S0 propagators fire before any S1 propagator fires. Within a stratum, order is unspecified (same as current Gauss-Seidel scheduling). When an S1 propagator adds S0 propagators to the worklist (e.g., resolution solves a meta, triggering new unification), the scheduler drops back to S0.

**Implementation**: The worklist becomes a vector of per-stratum lists (3 lists for S0/S1/S2). `net-cell-write` enqueues dependents into their respective stratum lists. The drain loop checks S0 first, S1 when S0 is empty, S2 when S1 is empty.

**Right Kan refinement — demand-driven quiescence**: The basic layered scheduler drains all of S0 before checking higher strata. The right Kan extension refines this: resolution propagators (C1-C3, tagged at S0) register *demand* on specific type cells. The scheduler can interleave S0 type propagation with S0 resolution by tracking which cells have pending demand:

```
run-to-layered-quiescence:
  loop:
    if S0 worklist non-empty:
      pop and fire S0 propagator
      if fired propagator solved a demanded cell:
        immediately fire waiting resolution propagators (still S0)
    elif S2 worklist non-empty:
      pop and fire S2 propagator (rare: ambiguous commitment)
    else:
      quiescent — exit
```

The key insight: resolution propagators don't need full S0 quiescence. They need their *specific dependency cells* to be ground. A type cell being ground is a local property (that cell's value ≠ bot), not a global property (all cells stable). So a resolution propagator can fire as soon as its watched cell is ground, even if other S0 propagators are still in the worklist.

This is naturally implemented by the existing threshold propagator mechanism: resolution propagators are threshold propagators watching a type cell. When `net-cell-write` updates the type cell, the threshold fires and adds the resolution propagator to the S0 worklist. The layered scheduler fires it in the same S0 pass — no waiting for full quiescence.

The demand-driven quiescence has a concrete performance benefit: for a command with 20 type metas and 5 trait constraints, the current loop runs S0 (solve all 20 metas) → S1 (detect 5 ready) → S2 (resolve 5) → loop back. With demand-driven scheduling, each trait constraint resolves as soon as its dependency meta is solved — potentially 5 resolution firings interleaved within the single S0 pass, with zero S1/S2 iterations.

**Interaction with Track 0's mutable worklist**: The mutable worklist box from BSP-LE Track 0 Phase 3c becomes a mutable vector of boxes (one per stratum). Same drain pattern, same pure data-in/data-out contract at the quiescence boundary.

**Files**: `propagator.rkt` (scheduler), `metavar-store.rkt` (stratum tagging for existing propagators), `elaborator-network.rkt` (propagator creation with stratum tags)

### Phase C1: Deterministic Trait Resolution as S0 Propagators

**Goal**: Trait constraints with a single matching instance resolve directly in S0, not through the S1→S2 cycle.

**Categorical grounding — left Kan extension**: C1 is the concrete instantiation of the left Kan extension along the pushforward from type propagation to constraint resolution. The resolution propagator speculatively processes partial S0 fixpoint information: when a type cell is solved (partial fixpoint — other cells may still be unsolved), the resolution propagator fires immediately with that information. Monotonicity guarantees the result is sound: the dict depends only on the type constructor (which is ground once the cell is solved), not on the full network state. The left Kan extension's universal property ensures this is the *best possible* early result — no alternative scheduling would produce a better answer sooner.

**Current flow** (after Part B):
1. Elaborator emits `Indexed ?C` constraint
2. S0: type propagation solves `?C` → `PVec`
3. S1: readiness propagator detects `?C` is ground → adds to ready-queue
4. S2: resolution loop processes ready-queue → looks up `impl Indexed PVec` → solves dict meta
5. Loop back to S0 (dict solution may trigger more unification)

**Target flow** (Part C):
1. Elaborator emits `Indexed ?C` constraint → creates resolution propagator at S0 watching `?C`'s type cell
2. S0: type propagation solves `?C` → `PVec`; resolution propagator fires → looks up `impl Indexed PVec` → solves dict meta → triggers dependent unification — **all within the same S0 pass**

The resolution propagator is monotone under the non-overlapping instance invariant: adding type information can refine which instance matches but cannot change a committed choice (there's only one valid choice). This is why it belongs in S0 (monotone stratum), not S2 (non-monotone commitment).

**Design**: A `make-trait-resolution-propagator` function:
```
(make-trait-resolution-propagator
  trait-name        ;; e.g., 'Indexed
  type-cell-id      ;; the cell to watch
  dict-meta-id      ;; the meta to solve with the resolved dict
  stratum: 0)       ;; fires in S0
```

When the type cell becomes ground:
1. Extract type constructor (e.g., `PVec Int` → `PVec`)
2. Look up `impl Indexed PVec` in the instance registry
3. If exactly one match: solve the dict meta immediately (`solve-meta!`)
4. If zero matches: leave as unsolved (will error later in constraint checking)
5. If ambiguous: escalate to S2 (non-monotone commitment needed)

Case 3 is the common case (non-overlapping invariant ensures it). Case 5 is rare and preserves correctness.

**Key architectural requirement**: The resolution propagator must be able to call `solve-meta!` from within S0. Currently, `solve-meta!` triggers the stratified resolution chain, which is the outer loop. After Part C, `solve-meta!` within S0 simply writes to a cell — the propagator network handles the consequences.

**Files**: `trait-resolution.rkt` (resolution propagator), `metavar-store.rkt` (propagator creation at constraint emission), `elaborator.rkt` (constraint emission creates propagator)

### Phase C2: Hasmethod Resolution as Propagators

**Goal**: `hasmethod` constraints (does type T have method M?) become S0 propagators.

**Current state**: `hasmethod` constraints are accumulated in a scoped cell and resolved during S2 by iterating the constraint list and checking each against the now-ground type. This is the same pattern as trait resolution.

**Design**: Same as C1 but for `hasmethod`:
1. When a `hasmethod` constraint is emitted, create a resolution propagator watching the relevant type cell
2. When the type becomes ground, the propagator checks whether the type has the method
3. If yes: mark the constraint as satisfied
4. If no: mark as failed (error)

**Files**: `metavar-store.rkt` (hasmethod propagator creation), `trait-resolution.rkt` (hasmethod checking)

### Phase C3: Constraint Retry as Propagators

**Goal**: Deferred/postponed constraints (currently retried by the S2 loop when metas are solved) become propagators watching their dependency cells.

**Current state**: When a constraint cannot be resolved because its type arguments are unsolved metas, it's added to a "postponed" list. The S2 loop periodically retries postponed constraints. This is polling — wasteful when most constraints are still not ready.

**Design**: Each postponed constraint becomes a propagator:
1. Identify the unsolved metas that the constraint depends on
2. Create a propagator watching those meta cells
3. When all dependencies become ground, the propagator fires and evaluates the constraint
4. If the constraint is satisfied, remove it. If not, it remains as an error.

This is demand-driven (propagator fires when ready) instead of polling (retry everything each S2 cycle). The scheduling is automatic — the propagator network knows when dependencies change.

**Files**: `metavar-store.rkt` (constraint→propagator conversion), `propagator.rkt` (multi-cell threshold propagators)

### Phase C4: S2 Scope Reduction

**Goal**: After C1-C3, S2 handles only genuinely non-monotone operations.

**What remains in S2**:
- **Ambiguous instance selection**: When multiple trait instances match and specificity-based disambiguation is needed. This is rare (non-overlapping invariant prevents it for most traits).
- **Overlapping constraint arbitration**: If any future extension relaxes the non-overlapping invariant, S2 is where the arbitration happens.

**What moves to S0**:
- All deterministic trait resolution (C1)
- All hasmethod resolution (C2)
- All constraint retry (C3)
- Readiness detection (S1) — with C1-C3 doing resolution directly in S0, S1's ready-queue becomes vestigial. Readiness is implicit in the propagator firing.

**Design**: The stratified loop simplifies from:
```
loop (fuel ≤ 100):
  S(-1): retraction
  S0: propagation to quiescence
  S1: readiness → ready-queue
  S2: process ready-queue → commit resolutions
  check progress
```

To:
```
loop (fuel ≤ 100):
  S(-1): retraction
  S0: propagation to quiescence (includes trait/hasmethod/constraint resolution)
  S2: non-monotone commitment (rare — only when ambiguous)
  check progress
```

S1 is eliminated. The loop iteration count drops because S0 now resolves monotone constraints in the same pass as type solving, rather than waiting for the next iteration.

**Files**: `metavar-store.rkt` (simplified loop), `resolution.rkt` (S2 reduced to ambiguous cases)

### Memo Cache Correctness Under Interleaved Resolution

Part C's interleaved resolution (C1-C3 firing in S0 alongside type propagation) introduces a correctness concern: reduction memo caches (`current-whnf-cache`, `current-nf-cache`, `current-nat-value-cache`) assume referential transparency, but reduction depends on meta solutions. A cache entry computed before a trait dict is resolved may be stale after resolution.

**Within-Track-8 solution (Option D)**: Disable memo caches during S0 propagation. Enable only during zonk (final reduction pass, all metas solved). The boundary is principled: "caching is valid only when the meta-solution context is final." During S0, the context is in flux; during zonk, it's final.

Implementation: `(current-reduction-caching-enabled?)` parameter, `#f` during `run-to-layered-quiescence`, `#t` during `zonk-final`. Cache lookups check the parameter; cache writes are gated.

**Principled long-term solution (Track 9)**: Reduction results as propagator cells with dependency-tracked invalidation. When a meta that a reduction depends on is solved, the reduction cell automatically recomputes. No memo cache needed — the propagator network IS the cache. See [Track 9: Reduction as Propagators](2026-03-21_TRACK9_REDUCTION_AS_PROPAGATORS.md) for the full vision.

**C5 verification item**: Test cases that exercise reduction before and after trait resolution within a single S0 pass. Verify that Option D produces correct results (no stale cache entries) and that the performance cost of uncached S0 reduction is acceptable.

### Phase C5: Verification + Benchmarks

- Full test suite — identical results (behavioral parity)
- Resolution cycle count: measure fuel consumption before/after. Target: significant reduction in loop iterations (fewer S0→S1→S2 cycles)
- Ordering stability: test cases with nested constraints that depend on resolution order
- **Memo cache correctness**: test cases exercising reduction before/after resolution within S0
- A/B benchmarks: wall-time improvement from fewer resolution cycles
- Acceptance file: all CIU aspirational sections pass at Level 3

---

## 6. Design Decisions

| # | Decision | Resolution | Rationale |
|---|----------|------------|-----------|
| D1 | Network architecture | Option C: two networks + domain tags | Proven by Track 7; persistent vs per-command is the right lifecycle split |
| D2 | Meta-info TMS mechanism | Per-entry assumption tagging (not dedicated cell) | Aligns with Track 7's tagged-entry pattern; granular retraction |
| D3 | Id-map accessibility (Part A) | Dedicated parameter (stepping stone) | Unblocks mult bridge immediately; Part B's cell-ops extraction is the permanent solution |
| D4 | Module restructuring | Cell-ops extraction (Option 1 from audit) | Minimal extraction that breaks all cycles; no module merge, no parameter pollution |
| D5 | HKT impl key | `(trait-name, type-constructor)` extracted from solved type | Natural extension of existing `expr->impl-key-str`; constructor extraction from `PVec Int` → `PVec` |
| D6 | Backward compatibility | `expr-get` fallback during B5 migration | Gradual — sugar generates constraints when possible, falls back to constructor dispatch otherwise |
| D7 | Part A/B/C ordering | A before B before C; each Part builds on the previous | A provides TMS-clean state; B provides module structure + HKT; C leverages both for propagator-driven resolution |
| D8 | Deterministic resolution in S0 | Monotone under non-overlapping instance invariant | Adding type information refines but doesn't change committed choice; safe for S0 |
| D9 | S1 elimination | Readiness detection subsumed by C1-C3 resolution propagators | Resolution propagators watch type cells directly; ready-queue becomes vestigial |
| D10 | Layered scheduler as C0 foundation | Propagators tagged with strata; worklist respects priority | C1-C3 need strata to work correctly; C0 provides the scheduling infrastructure |
| D11 | Ambiguous cases remain in S2 | Non-monotone commitment preserved for rare overlapping cases | Correctness requires the barrier; Part C moves monotone work out of S2, not into it |

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

### Part C

| Phase | Level 1 | Level 2 | Level 3 |
|-------|---------|---------|---------|
| C0 | Layered scheduler: priority ordering verified | — | Full suite (behavioral parity) |
| C1 | Trait resolution in S0: single-instance resolves | Nested constraints | Acceptance: `impl` resolution |
| C2 | Hasmethod in S0: ground type check | — | Full suite regression |
| C3 | Constraint retry as propagators | Deferred constraint fires on ground | Full suite regression |
| C4 | S2 reduced: loop iterations measured | — | Fuel consumption comparison |
| C5 | A/B benchmarks, ordering stability, full suite | — | All CIU aspirational sections |

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
| `cell-ops.rkt` API shaped for transient threading | — | — (CHAMP Performance follow-on) | B1 |
| Module restructuring | All (elaborator ↔ trait-resolution access) | — | B1 |
| TMS-clean speculation | — | Track 2 (worldview management) | A4 |
| Layered scheduler | — | All (propagators fire in correct priority order) | C0 |
| Deterministic resolution in S0 | Tracks 3-5 (trait constraints resolve without S2 cycle) | Track 2 (ATMS solver trait resolution) | C1 |
| Ordering stability for nested constraints | Tracks 3-5 (nested Indexed/Keyed/Seq constraints) | — | C1-C3 |

---

## 10. Deferred / Out of Scope

- **Reduction as propagators** (Track 8 audit §5.7): Term rewriting on-network. Research territory.
- **Elaboration context as cells** (Track 8 audit §5.8): Typing contexts as cell values. Research territory.
- **Memo caches as cells** (Track 8 audit §1.9): Not constraint-like; keep imperative.
- **Map HKT partial application** (`Map K` as `Type -> Type`): Important for Map to implement Foldable/Seq, but a separate type-system feature. Not Track 8 scope.
- **Observation cells** (P3 in audit): Performance counters and observatory as cells for LSP. Future Track 9/10 scope.
