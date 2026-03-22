# PM Track 8: Propagator Infrastructure Migration — Stage 3 Design

**Date**: 2026-03-21
**Status**: Draft (D.4 — unified vision revision: all elaboration on the network)
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
| A0 | Acceptance file | Baseline canary + aspirational tests | ✅ | `68d1e7a` | 16 results 0 errors. §A baseline, §B-C commented out |
| A1 | Meta-info TMS-awareness | `meta-info` CHAMP → TMS-managed field | ✅ | `249bb2b` | Per-entry assumption tagging. 6 read sites unwrap. S(-1) retracts. 7330 tests 243.8s |
| A2 | Id-map accessibility | `id-map` accessible from prop-net layer | ✅ | (Track 6) | Already delivered by Track 6 Phase 1a: `current-prop-id-map-read` + `prop-meta-id->cell-id`. Confirmed accessible from prop fire functions. |
| A3 | Mult/Level/Session on elab-network | Merge CHAMP boxes into elab-network cells | ✅ | | A3a `85d5f96` (mult), A3b `898159f` (level), A3c `8e1ffab` (session), A3d `6e26d38` (mult bridge in decompose-pi) |
| A4 | `restore-meta-state!` retirement | Partial: retained (belt-and-suspenders with tagged CHAMPs) | ✅ | `474f006`, `9c05dbd` | A4b: id-map also tagged. Full retirement blocked by timing gap: S(-1) deferred, elaborator needs synchronous cleanup between speculation branches. |
| A5 | Resolution state simplification | Remove progress box; retain re-entrancy guard | ✅ | `4049908` | progress-box removed (dead code); re-entrancy flag retained (load-bearing). 7330 tests 238.8s |
| — | **Part B: Elaboration on the Network** | | | | |
| B0 | Module graph analysis | Map circular deps, design extraction | ⬜ | | |
| B1 | Cell-ops + worldview-aware reads | Factor cell ops with ATMS worldview filtering | ✅ | `fa76f00` | cell-ops.rkt created. worldview-visible? filters by speculation stack. All CHAMP reads worldview-aware. |
| B1b | `restore-meta-state!` full retirement | Worldview-aware reads make synchronous restore unnecessary | ✅ | `fa76f00` | THIRD attempt succeeds. save/restore REMOVED from with-speculative-rollback. S(-1) is GC only. |
| B2 | Root callback elimination | Inline callbacks via cell-ops + elab-network-types | ✅ | `58b2f5c` | 14/23 replaced. 9 remaining: 5 domain-injection (lattice fns), 3 legacy (fallback boxes), 1 state (net-box). These are architecturally correct as injection points, not structural callbacks. |
| B2e | Macros parameter write cleanup | Remove 24 dual-writes; cell-only writes after B2 | ⏸️ | | DEFERRED: module-load-time reads still use parameter fallback. Removing dual-writes breaks module loading context. |
| B2f | Accumulate-during-quiescence | Owner-ID transient threading through cell-ops | ⏸️ | `251f8a7` | DEFERRED post-C: Phase 0 instrumentation shows 0 prop_firings on process-file path; test path has N=3-8 changes/run (too low for transient payoff). Re-evaluate after Part C adds bridge propagators. |
| B3 | HKT `impl` registration | `impl Seq List` works and registers in trait system | ✅ | `ac25508` | Parser fixes: pattern-var exclusion, brace-params opacity, implicit Pi wrapping. HKT trait def + impl registration work. |
| B4 | HKT trait resolution on network | Existing resolution handles HKT natively | ✅ | `a08fd1c` | No code changes needed. normalize-for-resolution + expr->impl-key-str already handle tycon keys. 3 tests added. Known: sexp kind datum mismatch. |
| B5 | Sugar constraint generation | `surf-get` generates Indexed/Keyed constraints | → CIU T3 | | TRANSFERRED to CIU Track 3 (Phase 1). Track 8 delivered the infrastructure (B3/B4 + C1); content change belongs in CIU. |
| B6 | Verification + benchmarks | Full suite + A/B comparison + acceptance | ✅ | | Subsumed by C6. 7343 tests, 228.2s, all pass. CIU acceptance sections remain for CIU Track 3. |
| — | **Part C: The Phase Boundary Dissolves** | | | | |
| C0 | Bridge convergence prototype | Manual trait bridge on test network; measure depth-2/3 firing count | ✅ | `d86304d` | Depth 1: 4 firings, Depth 2: 8-10, Depth 3: 18. All well within thresholds. Core assumption validated. |
| C1 | Trait resolution as bridge propagators | Bridge fire fn in S0 via `elab-add-propagator` + enet box sync | ✅ | `e6d8901` | Uses `resolve-trait-constraint-pure` from resolution.rkt. Readiness propagators retained as fallback. 7343 tests 232.7s. |
| C2 | Hasmethod resolution as bridge propagators | Same bridge pattern as C1 | ✅ | `e6d8901` | Uses `resolve-hasmethod-constraint-pure`. Injected via `current-hasmethod-resolution-bridge-fn`. |
| C3 | Constraint retry as bridge propagators | Postponed constraints retry during S0 via bridge fire fn | ✅ | `467d318` | Same enet-box-sync pattern as C1/C2. Status guard: only retries 'postponed. 7343 tests 230.3s. |
| C4 | S2 scope reduction + S1 verification pass | Loop comments updated; bridges reduce S2 to safety net | ✅ | `40760fb` | 228.2s (4.5s faster). Loop structure unchanged — bridges naturally make S2 no-ops. |
| C5a | Scheduling model evaluation | Benchmark Gauss-Seidel vs BSP-sequential vs BSP+transient | ⏸️ | | DEFERRED: Bridge prop_firings = 12 per file; Gauss-Seidel sufficient. BSP only helps at N>>100. Re-evaluate when BSP-LE adds more propagation. |
| C5b | Priority scheduling (optimization) | Priority-ordered rounds/worklist based on C5a winner | ⏸️ | | DEFERRED: Depends on C5a. |
| C6 | Verification + benchmarks | Full suite pass, performance within budget | ✅ | | 7343 tests, 228.2s (≤250s budget met). 1.9% faster than pre-bridge 232.7s. C0 convergence validated. |
| C7 | B2f re-evaluation | Re-run quiescence instrumentation; decide on transient accumulation | ✅ | | Post-C: 5924-6067 writes total, dominated by prelude loading. Bridge prop_firings = 12 (N<10 per command). **B2f NOT justified** — same conclusion as pre-C. |

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

Three categories of work remain, corresponding to three Parts. The unifying vision: **bring all elaboration onto the propagator network, dissolving the boundary between elaboration and propagation, so that the phase separation between compile-time trait resolution and runtime dispatch disappears.**

**Part A — Infrastructure migration** (COMPLETE): Assumption-tagged CHAMP entries for all structural state. S(-1) retraction for value cleanup. `restore-meta-state!` simplified to belt-and-suspenders. Cross-domain mult bridges wired.

**Part B — Elaboration on the Network**: The fundamental architectural change. Currently, elaboration is an imperative AST walk that *calls into* the propagator network (via callbacks and box operations). After Part B, elaboration state — meta lifecycle, speculation, constraint emission — *lives in* the network. Reads are worldview-aware (the ATMS worldview filters retracted entries automatically). Callbacks dissolve (cell-ops provides direct access). `restore-meta-state!` is fully retired (worldview-aware reads make retracted speculation state invisible without synchronous restore). HKT `impl` resolution is a natural consequence: when all trait state is on the network with worldview-aware access, `impl Seq List` resolves through the same mechanism as `impl Eq Nat`.

**Part C — The Phase Boundary Dissolves**: Trait resolution is not a separate "compile-time phase" running in a stratified loop. It's propagation in the same network, with the same ATMS worldview management, using the same cross-domain bridge pattern (session-type-bridge.rkt). The stratified loop (S0→S1→S2) simplifies because monotone resolution happens within S0 as bridge propagators. The "phase separation" between type inference and trait resolution — the root cause of the CIU acceptance file issues — dissolves because both are propagation in the same S0 pass.

### The Unified Vision

The three Parts form a progression:
- Part A: the *data* is on the network (tagged CHAMPs, TMS cells)
- Part B: the *operations* are on the network (worldview-aware reads, ATMS-managed speculation, direct cell-ops)
- Part C: the *control flow* is on the network (resolution as bridge propagators, not as imperative loop iterations)

After all three Parts, the elaborator is a thin driver that walks the AST and emits constraints into the propagator network. Type inference, trait resolution, constraint checking, and speculation are all propagation events within the same network, managed by the same ATMS, observed through the same worldview. The "compile-time / runtime" phase separation is replaced by a single propagation phase where constraints resolve as soon as their dependencies are ground — which is exactly what runtime dispatch does, just at compile time.

### Why This Order

Part A is prerequisite for Part B:
- Assumption tagging (A1-A4b) is the foundation for worldview-aware reads (B1)
- TMS cells and tagged CHAMPs provide the data model that B1's cell-ops API exposes

Part B is prerequisite for Part C:
- Worldview-aware reads (B1) make ATMS-managed speculation the universal model (no restore-meta-state!)
- Callback elimination (B2) provides direct call paths for bridge propagators
- HKT `impl` (B3-B4) provides the instances that resolution bridges look up

Part B delivers capabilities (HKT traits work, speculation is clean). Part C delivers the architectural capstone (the phase boundary dissolves).

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
                                   restore-meta-state! (→ worldview-aware reads)
                                   mult/level/session CHAMP boxes (→ cells)
                                   12 callback parameters (→ direct cell-ops)
                                 Added:
                                   Worldview-aware CHAMP reads (ATMS-managed)
                                   HKT impl registration in trait system
                                   Trait resolution as cross-domain bridge propagators
                                   surf-get generates Indexed/Keyed constraints
```

---

## 3. Part A: Infrastructure Migration

### Phase A0: Acceptance File

Create `examples/2026-03-21-track8-acceptance.prologos` with concrete sections per Part:

```prologos
;; §A — Part A: Infrastructure Migration (regression canary)

;; A1: Speculation rollback — Church folds and union types
def church-two := [fn [f : [Int -> Int]] [fn [x : Int] [f [f x]]]]
def result := [church-two [fn [y : Int] [int+ y 1]] 0]
;; Should elaborate + reduce correctly after TMS migration

;; A3: Cross-domain constraints
;; (expressions exercising type → mult → session bridges)

;; §B — Part B: HKT Resolution

;; B3: HKT impl registration
;; impl Seq List        ;; uncomment when B3 delivers
;; impl Indexed PVec    ;; uncomment when B3 delivers

;; B5: Sugar constraint generation
;; def pv := @[10 20 30]
;; pv[0]                ;; should use Indexed dispatch, not expr-get

;; §C — Part C: Bridge Resolution

;; C0: Bridge convergence (validated by prototype, not acceptance file)

;; C1: Trait resolution via bridge
;; [gfold [fn [x : Int] [int+ x 1]] 0 @[1 2 3]]
;; Should resolve Foldable PVec via bridge propagator in S0

;; C1-depth-2: Nested trait resolution
;; (expressions requiring Seq resolution that triggers Indexed resolution)

;; C4: S1 verification pass finds nothing
;; (all constraints resolved by bridges — S1 confirms)
```

### Phase A1: Meta-Info TMS-Awareness

**Goal**: Make `elab-network.meta-info` (CHAMP: meta-id → meta-info) TMS-managed.

**Current state**: `meta-info` is a struct field of `elab-network`. `save-meta-state` captures it via box snapshot. `restore-meta-state!` reinstates the old snapshot. This is the JTMS-style single-context pattern that Track 4's TMS was supposed to replace.

**Design**: Convert `meta-info` to a TMS-aware field. Options:
1. **Dedicated TMS cell** holding the entire CHAMP. Writes go through `net-cell-write` with a merge function that unions meta-info entries. Retraction via S(−1) tagged entries.
2. **Per-meta TMS tagging** within the existing CHAMP. Each meta-info entry tagged with an assumption-id. Retraction filters by tag (same pattern as scoped infrastructure cells).

Option 2 is more granular and aligns with Track 7's assumption-tagging discipline. The scoped cells already use `tagged-entry` structs with assumption IDs — the same pattern applies to meta-info entries.

**Key constraint**: `meta-info` is read by `meta-solution`, `ground-expr?`, and `solve-meta!` — all hot-path operations. The TMS tagging must not add measurable overhead to reads. The current `champ-lookup` is O(log₃₂ n); adding a tag check is O(1) per lookup. Acceptable.

**Tag lifecycle** (D.2 critique item): Tags do NOT accumulate. In our architecture, `net-commit-assumption` (propagator.rkt) promotes tagged entries to unconditional (depth-0) on speculation success. S(−1) retraction cleans entries tagged with retracted assumptions. So after 10 speculation attempts with 8 retracted: 2 committed entries (untagged), 0 retracted entries (cleaned), 0 stale tags. Commit is a monotone operation (promoting conditional → unconditional) within the `with-speculative-rollback` path.

**Files**: `metavar-store.rkt` (meta-info access), `elab-speculation-bridge.rkt` (save/restore), `elaborator-network.rkt` (struct definition)

### Phase A2: Id-Map Accessibility

**Goal**: Make `elab-network.id-map` (CHAMP: meta-id → cell-id) accessible from the `prop-net` layer.

**Current state**: `id-map` is an `elab-network` struct field. Code at the `prop-net` level (propagator fire functions, decomposition) cannot access it without going through callbacks. This blocks mult bridge wiring in `decompose-pi` (Track 7 PIR §10.3).

**Design**: Extract `id-map` into a shared location accessible from both `elab-network` and `prop-net` contexts. Options:
1. **Add `id-map` to `prop-network` struct**. Simple but widens the prop-net abstraction beyond its current scope.
2. **Dedicated parameter** `current-id-map` alongside `current-prop-net-box`. Populated from elab-network during `process-command`.
3. **Cell-ops module** (see B1) that provides `meta-id->cell-id` as a function, reading from whichever context is active.

Option 2 is simplest for Part A — it unblocks mult bridge wiring immediately. Option 3 is the principled solution that Part B will deliver. Part A can use Option 2 as a stepping stone.

**Lifecycle** (D.2 critique item): `id-map` is a live reference, not a snapshot. It grows during elaboration as `elab-fresh-meta` creates new meta-to-cell mappings. The parameter reads the current elab-network's id-map CHAMP at the time of the read — same semantics as all other elab-network field reads during propagation (propagator fire functions unbox `current-prop-net-box` to get the current elab-network). Not a pure snapshot.

**Two-context audit** (D.3, per pipeline.md): The `current-id-map` parameter must be verified in both elaboration context (inside `process-command`, network active) and module-loading context (outside `process-command`, no network). In the module-loading context, `id-map` may not exist yet. The parameter should default to `#f` or empty CHAMP, with readers guarding appropriately.

**Files**: `elaborator-network.rkt`, `metavar-store.rkt`, `propagator.rkt` (if adding field)

### Phase A3: Mult/Level/Session on Elab-Network

**Goal**: Merge `current-mult-meta-champ-box`, `current-level-meta-champ-box`, `current-sess-meta-champ-box` into per-meta cells on the elab-network.

**Current state**: Each domain has its own CHAMP box (`make-hasheq`), populated and read independently. `save-meta-state` captures all three boxes. They are not cells — they don't participate in propagation.

**Design**: When `elab-fresh-meta` creates a type meta, also create corresponding mult/level/session cells in the same elab-network. Cross-domain bridges (type → mult, type → level) become propagators within the network.

**Sub-phases**:
- **A3a**: Mult cells on elab-network. `elab-fresh-mult-cell` already exists (Track 4) — wire it into `elab-fresh-meta`. Remove `current-mult-meta-champ-box`.
- **A3b**: Level cells on elab-network. Similar to A3a.
- **A3c**: Session cells on elab-network. Similar but more complex — session cells have their own lattice and decomposition.
- **A3d**: Wire cross-domain bridges. `decompose-pi` can now create mult bridge propagators (A2 provided id-map access). **Note** (D.2 critique): `decompose-pi` is a propagator fire function — it creates bridges mid-quiescence. This is safe: `net-add-propagator` enqueues newly created propagators on the worklist immediately (`[worklist (cons pid ...)]`), so bridge propagators fire in the current S0 pass. If input cells already have non-bottom values, the bridge produces output immediately. Same mechanism the session-type bridge relies on.

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
6. `current-speculation-failures` — diagnostic only (error messages, not constraints). **Resolution** (D.2 critique): remains as a separate box, cleared on speculation commit/retract alongside the assumption. Not TMS-tagged — adding tagging overhead for purely diagnostic data has zero correctness benefit.

**Files**: `elab-speculation-bridge.rkt`, `metavar-store.rkt`, `batch-worker.rkt`, `test-support.rkt`

### Phase A5: Resolution State Simplification

**Goal**: Remove `current-in-stratified-resolution?` flag and `current-stratified-progress-box`.

**Current state**: These are re-entrancy guards and progress signals for the stratified resolution loop. Track 7 Phase 7b introduced `eq?` identity detection on the network struct, making the progress box redundant. The re-entrancy flag guards against recursive resolution, which should be structurally prevented by the layered scheduler.

**Design**: Remove both. Verify no re-entrancy via test cases.

**Files**: `metavar-store.rkt`, `resolution.rkt`

---

## 4. Part B: Elaboration on the Network

### The Architectural Change

Part B transforms the relationship between elaboration and propagation. Currently, elaboration is an imperative AST walk that *calls into* the propagator network through callback parameters. The network is a tool that elaboration uses. After Part B, elaboration state *lives in* the network. The network is the substrate that elaboration operates within.

The key mechanism: **worldview-aware reads**. When any code reads a meta-info entry, an id-map entry, or a CHAMP store value, the read checks the current ATMS worldview. Entries tagged with retracted assumptions are invisible — not because S(-1) cleaned them, but because the *read* filters them. This makes speculation cleanup automatic: retract an assumption, and all state created under that assumption vanishes from all subsequent reads. No `restore-meta-state!`, no synchronous cleanup, no timing gaps.

This is the same mechanism the TMS cells already use for type values — a TMS-cell read under a given worldview returns only the value from the matching branch. Part B extends this mechanism from "type cell values" to "all structural state" (meta-info, id-map, mult, level, session, infrastructure cells).

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

### Phase B1: Cell-Ops Extraction with Worldview-Aware Reads

**Goal**: Extract cell operations into a standalone `cell-ops.rkt` module. The API is **worldview-aware**: all reads filter by the current ATMS worldview. This is the architectural change that makes `restore-meta-state!` retirement possible.

**Design** (D.2 critique: dual API): `cell-ops.rkt` provides two API surfaces:

**Pure API** (for propagator fire functions — take network, return network):
**Pure API** (for propagator fire functions — take network, return network):
- `cell-read : elab-network → cell-id → value` — **worldview-aware**: filters tagged entries by current ATMS worldview
- `cell-write : elab-network → cell-id → value → elab-network` — tags entries with current speculation assumption
- `cell-replace : elab-network → cell-id → value → elab-network`
- `meta-id->cell-id : elab-network → meta-id → cell-id` — **worldview-aware**: retracted id-map entries are invisible
- `meta-info-read : elab-network → meta-id → meta-info` — **worldview-aware**: retracted meta-info entries are invisible
- `meta-info-write : elab-network → meta-id → meta-info → elab-network` — tags with current assumption

**Boxed API** (for elaboration code — read/mutate current-prop-net-box):
- `cell-read! : cell-id → value` — worldview-aware
- `cell-write! : cell-id → value → void`
- `meta-lookup! : meta-id → meta-info` — worldview-aware

**Worldview-aware read mechanism**: Every tagged-entry read checks whether the entry's assumption-id is in the current ATMS worldview's believed set. If not (retracted or in a different branch), the entry is invisible (returns `#f` or `type-bot`). This is the same mechanism TMS cells use for type values, extended to all structural state.

The worldview check is O(1): `(set-member? believed-set assumption-id)`. The believed set is the ATMS's current worldview (maintained by `with-speculative-rollback`'s assumption push/pop). At depth-0 (no speculation), all untagged entries are visible (fast path).

**Consequence: `restore-meta-state!` retirement.** With worldview-aware reads, entries from retracted speculation branches are automatically invisible to subsequent reads. No synchronous restore needed. The timing gap that blocked A4's full retirement disappears: the second speculation branch's reads filter the first branch's tagged entries by worldview, regardless of whether S(-1) has run. S(-1) becomes a garbage-collection pass (cleaning entries that will never be visible again), not a correctness mechanism.

No circular dependency — `cell-ops.rkt` depends only on `propagator.rkt` and `elab-network struct definitions` (which can be factored into a separate types module if needed).

**Design-for note — accumulate-during-quiescence pattern** (from [CHAMP Performance Design](2026-03-21_CHAMP_PERFORMANCE_DESIGN.md) §Accumulate-During-Quiescence): The `cell-ops.rkt` API accommodates an optional transient parameter for owner-ID transient threading during quiescence.

**Design-for note — worldview threading**: The current ATMS worldview (believed assumption set) is threaded via `(current-speculation-stack)`. The `cell-ops` API reads the stack to determine the worldview. No additional parameter needed — the existing `parameterize` in `with-speculative-rollback` provides the worldview context.

**Files**: New `cell-ops.rkt`; `metavar-store.rkt` (replace callback calls + worldview-aware reads); `elaborator-network.rkt` (delegate)

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

**Cells created during quiescence** (D.2 critique): If `net-new-cell` creates a cell during quiescence (e.g., `decompose-pi` creating sub-cells), the new cell exists in the persistent cells CHAMP but not in the transient (which was forked from the pre-creation state). `cell-read` through the transient must fall back to the persistent base for cells not in the transient. `cell-write` through the transient inserts the new cell as a new entry (the owner-ID `tchamp-insert-owned!` handles absent keys by adding them). The cold CHAMP (merge functions, contradiction functions) is separate and persistent — always has the new cell's merge function. This works but must be verified with tests covering mid-quiescence cell creation.

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

**Constructor extraction boundary** (D.2 critique): B3 supports extraction of the outermost type application head: `(expr-app f args)` → `f`. This covers `PVec Int` → `PVec`, `Map String Int` → `Map`, `Result (List Int) String` → `Result`. B3 does NOT support partially-applied constructors (`Map String` as `Type → Type`). Partial application is a separate type-system feature listed in Deferred (Map HKT partial application). Test cases must explicitly verify the supported forms and document the unsupported boundary.

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

**Fallback selection** (D.2 critique): Option 1 — compile-time registry check. `surf-get` reads the persistent impl registry cell (Track 7) to check whether the type's constructor has an `impl Indexed`. This is a cell read during elaboration, not a resolution — checking registry existence, not resolving a constraint. If the registry has the impl, generate the constraint. If not, fall back to `expr-get`. No error-path performance concern (Option 2) and no behavioral split (Option 3).
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

## 5. Part C: The Phase Boundary Dissolves

### Thesis

The "phase separation" between compile-time trait resolution and runtime dispatch — the root cause of the CIU acceptance file issues — dissolves. Trait resolution is not a separate compile-time phase running in a stratified loop. It's propagation in the same network, with the same ATMS worldview management, using the same cross-domain bridge pattern. The stratified quiescence loop (S0→S1→S2) simplifies because monotone resolution happens within S0 as bridge propagators. The type checker becomes a single propagator network where type inference, trait resolution, and constraint checking are all propagation events — just like runtime dispatch resolves through the same trait system, just at compile time.

### Existing Infrastructure: Cross-Domain Bridge Propagators

**The mechanism already exists.** Two cross-domain bridges in the codebase demonstrate the exact pattern Part C needs:

**1. Session-Type Bridge** (`session-type-bridge.rkt`): Session cell → α (extract message type) → Type cell. Uses `net-add-cross-domain-propagator`. The α function (`send-type-alpha`) is pure and monotone. The γ function returns `sess-bot` (no reverse flow). Constraints are collected during the walk (`msg-type-constraint` descriptors), checked post-quiescence (`check-type-constraints`).

**2. Capability-Type Bridge** (`cap-type-bridge.rkt`): Type cell ↔ Capability cell via bidirectional α/γ. The α function (`type-to-cap-set`) extracts capability names from type expressions. The γ function (`cap-set-to-type`) converts capability sets back to type expressions. Full Galois adjunction: α∘γ∘α = α, γ∘α∘γ = γ.

**Both work within the existing flat S0 quiescence loop.** No layered scheduler needed. The bridge propagator fires as part of normal S0 propagation — when the source cell changes, the α propagator fires and writes to the target cell. Dependent propagators on the target cell fire in the same S0 pass.

**Part C's trait resolution follows the same pattern:**

| Component | Session-Type Bridge | Trait Resolution Bridge |
|-----------|-------------------|----------------------|
| Source cell | Session cell (`sess-send(A, S)`) | Type cell (`PVec Int`) |
| α function | `send-type-alpha`: extract message type A | `trait-resolve-alpha`: extract constructor `PVec`, look up `impl Indexed PVec`, return dict |
| Target cell | Type cell (receives A) | Dict meta cell (receives resolved dict) |
| γ function | `type-to-session-gamma`: returns `sess-bot` | `dict-to-type-gamma`: returns `type-bot` (no reverse flow) |
| Constraint descriptors | `msg-type-constraint` (collected during walk) | `trait-constraint` (collected during elaboration) |
| Post-quiescence check | `check-type-constraints` | `check-unresolved-constraints` |
| Bridge constructor | `add-send-type-bridge` | `add-trait-resolution-bridge` |
| Infrastructure | `net-add-cross-domain-propagator` | `net-add-cross-domain-propagator` (same) |

This means Part C is NOT inventing a new mechanism. It's applying the session-type-bridge pattern to a new domain.

**Structural difference from session bridge** (D.2 critique): The session bridge has clean unidirectional flow — session domain to type domain, no feedback. Trait resolution bridges create an *indirect* feedback loop within the type domain: type cell solves → trait bridge fires → dict cell populated → dict used in elaborated code → new type unification constraints fire → may solve more type cells → may trigger more trait bridges. This cycle lives within the propagator network (not through elaboration — the elaborated code is already wired before quiescence). The propagator network handles cycles via Kleene iteration and the no-change guard (finite lattice height ensures termination). For depth-2 resolution (`Seq (List Int)` — resolving Seq triggers resolving List's Indexed), the cycle is ~6 propagator firings within a single S0 pass. C6 must include depth-2 and depth-3 cycle test cases to verify convergence.

### Categorical Motivation: Kan Extensions

The BSP-LE categorical analysis ([BSP-LE Master Roadmap](2026-03-21_BSP_LE_MASTER.md), standup 2026-03-21 §Outside Conversation) identified two adjoint mechanisms:

**Left Kan extension (speculative forwarding)**: The cross-domain bridge fires on partial S0 fixpoint information — a type cell just solved, but S0 hasn't fully quiesced. Monotonicity guarantees soundness. The trait resolution bridge IS the left Kan extension: it speculatively resolves the dict as soon as the type constructor is known, without waiting for all type cells to stabilize.

**Right Kan extension (demand-driven computation)**: The bridge propagator only fires when its source cell changes — demand-driven by the dependency graph. Type propagation doesn't need to solve all metas; only the ones with dependent resolution bridges need to be ground. This is the existing threshold mechanism applied to resolution.

The Kan extensions are adjoint — speculative forwarding of demanded cells gives the same result as waiting for completion and extracting what's needed. This adjunction, already validated by the session-type bridge's correctness, guarantees Part C produces identical results to the sequential S0→S1→S2 loop.

### Why This Matters

The S0→S1→S2 cycle introduces ordering fragility: a type cell solved in S0 triggers readiness in S1, which triggers resolution in S2, which may solve another type cell that triggers another S0 pass. For nested constraints (e.g., `Seq (List Int)` where resolving `Seq` depends on `List`'s type constructor), this multi-cycle resolution can fail to converge within the fuel limit.

The cross-domain bridge pattern eliminates the cycles. The session-type bridge already proves this: session → type propagation happens within a single `run-to-quiescence` call, with no multi-cycle iteration. Trait resolution bridges work the same way.

### Prior Art Patterns Applied

Three patterns from prior design tracks directly inform Part C (see §11 for full analysis):

1. **Session-Type Bridge as template** (Architecture A+D): The `add-send-type-bridge` / `net-add-cross-domain-propagator` pattern is structurally identical to trait resolution bridges. Session bridge watches session cell → extracts type → writes to type cell. Trait bridge watches type cell → extracts constructor + looks up impl → writes to dict cell.

2. **Residuation from FL-Narrowing**: Narrowing's definitional trees implement "needed demand analysis" — pause until needed information arrives. Trait constraints residuate identically: the bridge propagator sleeps until the type cell is ground, then fires. The propagator network provides residuation natively via the no-change guard.

3. **Intra-walk threading from Architecture A+D**: During elaboration walks, constraint information should be collected as descriptors (not immediately wired as propagators). The session-type bridge demonstrates this: `msg-type-constraint` structs are accumulated during `compile-proc-with-type-bridges`, then checked post-quiescence. Part B5's `surf-get` should follow the same pattern.

### Gödel Completeness: Termination Arguments for Part C

Per [GÖDEL_COMPLETENESS.org](../principles/GÖDEL_COMPLETENESS.org), every computation added to the propagator network must state its termination argument explicitly. Part C moves three classes of constraint resolution from the imperative loop INTO the network as S0 propagators. Each must be decidable.

| Phase | Propagator | Termination Level | Argument |
|-------|-----------|-------------------|----------|
| C1 | Trait resolution bridge (α) | Level 1 (Tarski) | α fires when type cell transitions bot→ground. Each type cell transitions at most once (monotone lattice, finite metas). α produces a deterministic result (single impl lookup). |
| C1 | Trait resolution feedback loop | Level 2 (well-founded) | Dict solution → new type constraints → new type cells → new bridge firings. Each cycle resolves at strictly smaller type depth (admissibility condition, checked at `impl` registration). Type depth is a natural number (well-founded). |
| C2 | Hasmethod bridge (α) | Level 1 (Tarski) | Same as C1 — fires once per type cell grounding. Boolean result (has/hasn't method). |
| C3 | Constraint retry threshold | Level 1 (Tarski) | Multi-cell threshold fires when ALL dependency cells are ground. Each cell transitions at most once. Threshold fires at most once. |
| C4 | S2 (ambiguous commitment) | Level 2 + Level 5 | Non-overlapping invariant prevents ambiguity for most traits. Rare ambiguous cases: type depth decreases per resolution cycle (Level 2). Fuel retained as defense-in-depth (Level 5). |
| C5a/b | Scheduling model + priority | Same as underlying propagators | Scheduling order doesn't affect termination — only affects convergence speed. CALM theorem: monotone + commutative merge = confluent regardless of order. |

**The critical argument**: C1's feedback loop. When a trait bridge resolves `Indexed PVec` and writes the dict, the dict may be used in elaborated code that generates new type constraints (e.g., the dict's method types contain type parameters that need unification). These new type cells may trigger new trait bridges. The well-founded measure is: the sum of type depths across all unsolved trait constraints decreases on each resolution cycle. This is the same Level 2 argument currently used for L2→S0 feedback — Part C moves it from "across strata" to "within S0," but the mathematical argument is unchanged.

**Fuel retained as defense-in-depth**: The stratified loop's fuel (100 iterations) persists even with Part C's bridge propagators handling monotone resolution. The fuel catches bugs in the termination argument, not bugs in the code. If the feedback loop ever fails to decrease type depth (violating the admissibility condition), fuel catches it before divergence.

### Phase C0: Bridge Convergence Prototype

**Goal**: Validate that the cross-domain bridge pattern converges for nested trait resolution before committing to C1-C6.

**Design**: Manually wire a trait resolution bridge using `net-add-cross-domain-propagator` on a test propagator network. The test network has:
- Type cells for `?C` (unsolved) and a compound type `PVec Int`
- A trait bridge: type cell → α (extract constructor, lookup impl) → dict cell
- A depth-2 test: resolving `Seq ?C` triggers resolving `Indexed (List ?A)` when `?C` = `List`
- A depth-3 test: three levels of dependent trait resolution

**Measurement**: Count propagator firings to reach quiescence for each depth level. Thresholds:
- Depth 1: < 10 firings → expected
- Depth 2: < 20 firings → acceptable
- Depth 3: < 50 firings → acceptable
- Any depth > 100 firings → redesign needed (layered scheduler becomes mandatory, or bridge approach is unsuitable)

**Implementation note**: This can run alongside Part A — it's a standalone test, not dependent on A1-A5 or B1-B5. Early validation prevents investing in 10+ prerequisite phases before discovering the core assumption is wrong.

**Files**: New test file `tests/test-trait-resolution-bridge.rkt`

### Phase C1: Trait Resolution as Cross-Domain Bridge Propagators

**Goal**: Trait constraints with a single matching instance resolve as cross-domain bridge propagators in S0, using the existing `net-add-cross-domain-propagator` infrastructure.

**Design**: A `add-trait-resolution-bridge` function following the session-type bridge pattern:

```racket
(define (add-trait-resolution-bridge net type-cell trait-name)
  ;; Create a dict cell to receive the resolved dict
  (define-values (net1 dict-cell)
    (net-new-cell net type-bot type-lattice-merge type-lattice-contradicts?))
  ;; Wire cross-domain bridge: type cell → dict cell
  (define-values (net2 _pid-alpha _pid-gamma)
    (net-add-cross-domain-propagator net1 type-cell dict-cell
      (make-trait-resolve-alpha trait-name)   ;; α: extract constructor, lookup impl
      (lambda (_) type-bot)))                 ;; γ: no reverse flow
  (values net2 dict-cell))

(define (make-trait-resolve-alpha trait-name)
  (lambda (type-val)
    (cond
      [(type-bot? type-val) type-bot]         ;; not yet solved
      [(type-top? type-val) type-top]         ;; contradiction
      [else
       ;; Extract type constructor, look up impl
       (define ctor (extract-type-constructor type-val))
       (define impl (lookup-impl trait-name ctor))
       (cond
         [(not impl) type-bot]                ;; no impl found — leave unsolved
         [else (impl-dict impl)])])))         ;; resolved dict
```

**Key properties** (shared with session-type bridge):
- α is pure and monotone (bot → bot, ground type → dict, top → top)
- **Termination**: Level 1 (Tarski) — fires at most once per type cell grounding. Feedback loop: Level 2 (type depth decreases per resolution cycle). See §Gödel Completeness above.
- Fires within normal S0 quiescence — no layered scheduler needed
- The dict cell is readable by any dependent propagator (e.g., `surf-get`'s elaborated code references the dict cell)
- Post-quiescence check verifies all trait constraints resolved (analogous to `check-type-constraints`)

**The "ambiguous" case** (multiple matching instances): The α function returns `type-bot` (unresolved) when disambiguation is needed. The post-quiescence check detects unresolved trait constraints and either reports an error or escalates to S2 commitment. This mirrors the session bridge's handling of `type-bot` in `check-type-constraints` (line 336: "no type info yet, skip").

**Critical: `solve-meta!` re-entrancy** (D.3 self-critique): The current `solve-meta!` (metavar-store.rkt) triggers the stratified resolution chain — it writes to `meta-info`, then calls resolution functions that may trigger further `solve-meta!` calls. If a C1 bridge propagator's α function calls `solve-meta!` during S0 propagation, this could re-enter the stratified loop from within a propagator fire function.

**Resolution**: C1's α function does NOT call `solve-meta!`. It writes the dict value to the dict cell via `net-cell-write` — a pure network operation. The propagator network handles the consequences (dependent propagators fire, including any that would have been triggered by `solve-meta!`). The `solve-meta!` function must be refactored as part of C1: its "write to meta-info + trigger resolution" behavior splits into (a) cell write (done by the bridge propagator) and (b) resolution triggering (done by the network's dependency graph). This is the architectural change that makes Part C work — resolution is driven by the network, not by `solve-meta!`'s imperative chain.

This refactoring is not a new phase — it's internal to C1's implementation. The bridge α function replaces `solve-meta!`'s resolution triggering with cell writes; the propagator network replaces the imperative chain with dependency-driven propagation.

**Files**: New `trait-resolution-bridge.rkt` (following `session-type-bridge.rkt` structure), `elaborator.rkt` (constraint emission), `metavar-store.rkt` (bridge creation, `solve-meta!` refactoring)

### Phase C2: Hasmethod Resolution as Bridge Propagators

**Goal**: `hasmethod` constraints become cross-domain bridge propagators.

**Design**: Same bridge pattern. α function: type-val → has-method check → boolean cell. **Termination**: Level 1 — fires once per type cell grounding, boolean result.

```racket
(define (add-hasmethod-bridge net type-cell method-name)
  (define-values (net1 result-cell)
    (net-new-cell net 'unknown hasmethod-merge))
  (define-values (net2 _ __)
    (net-add-cross-domain-propagator net1 type-cell result-cell
      (make-hasmethod-alpha method-name)
      (lambda (_) 'unknown)))
  (values net2 result-cell))
```

**Files**: `trait-resolution-bridge.rkt` (alongside trait bridge)

### Phase C3: Constraint Retry as Bridge Propagators

**Goal**: Deferred/postponed constraints become bridge propagators watching their dependency cells.

**Design**: Each postponed constraint creates a multi-input threshold propagator (already exists in `propagator.rkt`) that fires when ALL dependency cells are ground. This is the multi-cell generalization of the single-cell bridge pattern.

The threshold propagator reads all dependency cells, checks if all are ground, and if so evaluates the constraint. This replaces the S2 polling loop with demand-driven firing. **Termination**: Level 1 (Tarski) — each dependency cell transitions bot→ground at most once; the threshold condition is satisfied at most once; the propagator fires at most once.

**Files**: `metavar-store.rkt`, `propagator.rkt` (existing `make-threshold-fire-fn`)

### Phase C4: S2 Scope Reduction + S1 Elimination

**Goal**: After C1-C3, the stratified loop simplifies.

**What moves to S0 (as bridge propagators)**: All deterministic trait resolution (C1), all hasmethod resolution (C2), all constraint retry (C3).

**S1 becomes a no-op verification pass** (D.2 critique): Rather than eliminating S1 entirely, convert it to a verification pass that checks whether any constraints that should have been resolved by bridge propagators are still unresolved. If S1 finds unresolved constraints, it's a bug in bridge coverage — not a reason to fall through to S2. This is a safety net during migration: catches missing bridge types without breaking anything. Once all constraint types are verified covered, S1 can be fully eliminated in a future cleanup.

**What remains in S2**: Only genuinely non-monotone commitment — ambiguous instance selection. The α function returns `type-bot` for ambiguous cases; the post-quiescence check escalates these to S2.

**Simplified loop**:
```
loop (fuel ≤ 100):
  S(-1): retraction
  S0: propagation to quiescence (type inference + resolution bridges + hasmethod + constraint retry)
  S2: non-monotone commitment (rare)
  check progress
```

**Files**: `metavar-store.rkt` (simplified loop), `resolution.rkt` (S2 reduced to ambiguous cases)

### Phase C5a: Scheduling Model Evaluation

**Goal**: Data-driven decision on the default quiescence scheduler for the post-Part-C network.

The production path currently uses Gauss-Seidel (serial, one propagator at a time). The BSP scheduler (`run-to-quiescence-bsp`) exists but is unused in production. Part C increases the network size (~100+ propagators per command with bridges). The question: does BSP scheduling + owner-ID transient accumulation outperform Gauss-Seidel + persistent writes at this scale?

**Benchmark candidates**:
1. **Gauss-Seidel** (current default): serial firing, persistent CHAMP writes per propagator
2. **BSP-sequential**: BSP rounds with serial firing within each round, persistent writes
3. **BSP-sequential + transient**: BSP rounds with owner-ID transient accumulation per round — all writes within a round mutate the transient in place, freeze once at round end

**Measurement**: Wall-time, GC pressure, round count, fuel consumption. Representative workloads: prelude load, adversarial benchmark, CIU acceptance file.

**Decision criterion**: If BSP+transient is faster (wall-time) or lower GC (pressure) without regression on chain-heavy workloads (where Gauss-Seidel converges in fewer iterations than Jacobi/BSP), switch default. Otherwise keep Gauss-Seidel.

**Note**: The CALM theorem guarantees all three produce identical results. This is purely a performance decision, not a correctness decision.

**Files**: `propagator.rkt` (scheduler selection), `benchmarks/micro/bench-alloc.rkt` (scheduling benchmarks)

### Phase C5b: Priority Scheduling (Optimization)

**Goal**: Add priority-ordered scheduling to whichever scheduler wins C5a.

**Design**: Propagators tagged with priority. The scheduler drains higher-priority propagators first. Type unification propagators (highest priority) fire before resolution bridges (medium) fire before readiness detection (lowest, now vestigial).

**Right Kan refinement**: The scheduler interleaves type propagation with resolution bridge firing — when a type cell becomes ground, its dependent resolution bridge fires immediately, before other type propagators. This is demand-driven quiescence: resolution happens as soon as demanded information is available.

**Open questions** (D.2 critique — to be resolved at C5b implementation time):
- Priority assignment: static (type unification = high, bridges = medium) or dynamic (based on dependency analysis)?
- Interleaving behavior: when a high-priority propagator enqueues both high and medium priority work, does the scheduler finish all high-priority before touching medium, or interleave?
- Data structure: multiple flat lists (one per priority) vs priority queue? Interacts with Track 0 Phase 3c's mutable worklist boxes.

**Files**: `propagator.rkt` (priority worklist), `elaborator-network.rkt` (priority tagging)

### Memo Cache Correctness Under Interleaved Resolution

Part C's interleaved resolution (C1-C3 firing in S0 alongside type propagation) introduces a correctness concern: reduction memo caches (`current-whnf-cache`, `current-nf-cache`, `current-nat-value-cache`) assume referential transparency, but reduction depends on meta solutions. A cache entry computed before a trait dict is resolved may be stale after resolution.

**Option D — Disable caching during S0**: `(current-reduction-caching-enabled?)` parameter, `#f` during quiescence, `#t` during zonk. The boundary is principled: "caching is valid only when the meta-solution context is final." Simple, correct, but potentially expensive if uncached S0 reduction is a hot path.

**Option E — Solve-meta generation counter** (D.2 critique, refined): A monotonic counter incremented on each `solve-meta!` call (~5-15 times per command). Each cache entry is tagged with the counter value at computation time. On lookup, if the current counter matches the entry's tag, the entry is valid. If not (a meta was solved since computation), the entry is stale and must be recomputed.

Cost model:
- Counter increment: one `set-box!` per `solve-meta!` call — negligible
- Cache lookup: one `(= counter entry-gen)` per WHNF/NF call — ~0.5ns per check, ~0.1μs total per command for 200 lookups
- Expected hit rate: between two `solve-meta!` calls, cache is fully valid. With ~50 WHNF calls between solves and ~60% repeat rate, saves ~30-150μs per command
- Worst case: if `solve-meta!` fires after every propagator firing, degrades to Option D. Unlikely: most firings are type unification (no `solve-meta!`)

**Note**: The initial D.2 proposal used `eq?` on the elab-network struct as the generation stamp. This is wrong — the network changes on every cell write (immutable struct), invalidating the entire cache on every write (functionally identical to Option D). The solve-meta counter is the correct granularity: only meta solutions invalidate reduction results, not arbitrary cell writes.

**Recommendation**: Option E (solve-meta counter) first. Fall back to Option D if counter overhead is measurable or if edge cases arise where cell writes (not just meta solutions) invalidate reduction. C6 benchmarks both. C6 should benchmark both.

**Principled long-term solution (Track 9)**: Reduction results as propagator cells with dependency-tracked invalidation. When a meta that a reduction depends on is solved, the reduction cell automatically recomputes. No memo cache needed — the propagator network IS the cache. See [Track 9: Reduction as Propagators](2026-03-21_TRACK9_REDUCTION_AS_PROPAGATORS.md) for the full vision.

**C5 verification item**: Test cases that exercise reduction before and after trait resolution within a single S0 pass. Verify that Option D produces correct results (no stale cache entries) and that the performance cost of uncached S0 reduction is acceptable.

### Phase C5: Verification + Benchmarks

- Full test suite — identical results (behavioral parity)
- Resolution cycle count: measure fuel consumption before/after. Target: significant reduction in loop iterations (fewer S0→S1→S2 cycles)
- Ordering stability: test cases with nested constraints that depend on resolution order
- **Memo cache correctness**: test cases exercising reduction before/after resolution within S0; benchmark Option D vs Option E
- **Trait resolution cycle depth**: test cases with depth-2 (Seq of List) and depth-3 (nested compound trait resolution) verifying convergence within single S0 pass
- A/B benchmarks: wall-time improvement from fewer resolution cycles
- Acceptance file: all CIU aspirational sections pass at Level 3; Part C-specific acceptance for bridge resolution independent of CIU
- **Performance budget**: suite ≤250s (8% tolerance from 232s baseline); per-command elaboration ≤15% increase. If Part C's bridge propagators add overhead exceeding savings from fewer loop iterations, C5 (layered scheduler) becomes mandatory rather than optional.

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
| D8 | Resolution as cross-domain bridge propagators | Use existing `net-add-cross-domain-propagator` (same as session-type-bridge and cap-type-bridge) | Proven mechanism — two existing implementations validate the pattern. No new propagator infrastructure needed |
| D9 | S1 elimination | Readiness detection subsumed by bridge propagators' natural firing | Bridge propagators fire when source cell changes; ready-queue becomes vestigial |
| D10 | Layered scheduler as optimization, not prerequisite | Session-type bridge works within flat S0; trait bridges will too | C1-C4 proven correct without layered scheduler; C5 adds scheduling efficiency |
| D11 | Ambiguous cases remain in S2 | α returns `type-bot` for ambiguous; post-quiescence escalates to S2 | Mirrors session bridge's `type-bot` handling in `check-type-constraints` |
| D12 | Constraint collection during walk, check post-quiescence | Follow session-type-bridge's `msg-type-constraint` descriptor pattern | Elaboration walk collects descriptors; bridges wired at cell creation; checked after quiescence |

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
| C0 | Manual bridge on test network: depth 1/2/3 firing count | — | Standalone (no acceptance file) |
| C1 | Trait bridge resolves in S0: single-instance | Nested constraints (Seq of List) | Acceptance: `impl` resolution across collection types |
| C2 | Hasmethod bridge resolves in S0 | — | Full suite regression |
| C3 | Constraint retry fires on ground dependencies | Multi-dependency constraint | Full suite regression |
| C4 | S1 eliminated, S2 reduced: loop iterations measured | — | Fuel consumption comparison |
| C5a | Gauss-Seidel vs BSP-sequential vs BSP+transient | — | A/B benchmarks on post-Part-C network |
| C5b | Priority scheduling on C5a winner | — | Demand-driven quiescence A/B benchmarks |
| C6 | Full suite, ordering stability, memo cache, benchmarks | — | All CIU aspirational sections |

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
| C1 α function needs access to trait instance registry from propagator fire context | Medium | Medium | Registry is already a persistent cell (Track 7); `cell-read` from fire fn via cell-ops |
| C1-C3 bridge propagators increase cell/propagator count per command | Low | Low | Mitigated by CHAMP Performance owner-ID transients + BSP-LE Track 0 struct split |
| Memo cache staleness under interleaved resolution (C1-C3 in S0) | Medium | High | Option E (solve-meta counter); Track 9 provides principled solution |
| C1 `solve-meta!` re-entrancy: bridge α triggering stratified loop from within S0 | High | High | α function writes to dict cell only (no `solve-meta!`); `solve-meta!` refactored as part of C1 to split cell-write from loop-triggering |

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
| Trait resolution bridges in S0 | Tracks 3-5 (trait constraints resolve without S2 cycle) | Track 2 (ATMS solver trait resolution) | C1 |
| Ordering stability for nested constraints | Tracks 3-5 (nested Indexed/Keyed/Seq constraints) | — | C1-C3 |
| Layered scheduler (optimization) | — | All (better scheduling efficiency) | C5 |

---

## 10. Deferred / Out of Scope

- **Reduction as propagators** (Track 8 audit §5.7): Term rewriting on-network. Research territory.
- **Elaboration context as cells** (Track 8 audit §5.8): Typing contexts as cell values. Research territory.
- **Memo caches as cells** (Track 8 audit §1.9): Not constraint-like; keep imperative.
- **Map HKT partial application** (`Map K` as `Type -> Type`): Important for Map to implement Foldable/Seq, but a separate type-system feature. Not Track 8 scope.
- **Observation cells** (P3 in audit): Performance counters and observatory as cells for LSP. Future Track 9/10 scope.

---

## 11. Prior Work Patterns Informing This Design

Three completed tracks provide direct architectural templates for Track 8:

### Session-Type Bridge → Part C Trait Resolution

`session-type-bridge.rkt` implements the exact cross-domain bridge pattern that Part C needs. The mapping: session cell → α (extract message type) → type cell is isomorphic to type cell → α (extract constructor + lookup impl) → dict cell. Both use `net-add-cross-domain-propagator`. Both collect constraint descriptors during the walk and check them post-quiescence. Both work within the existing flat S0 quiescence loop.

**Key design insight from session bridge**: The γ direction returns lattice bottom (no reverse flow). This makes the bridge effectively unidirectional while using the bidirectional `net-add-cross-domain-propagator` infrastructure. Trait resolution bridges follow the same pattern — dict information doesn't flow back to constrain the type.

**Key implementation insight**: `compile-proc-with-type-bridges` threads constraint accumulation through the walk, creating bridge propagators alongside process compilation. Part B5's `surf-get` should follow the same pattern — create trait resolution bridges during elaboration, accumulate constraint descriptors, wire bridges when cells exist.

### FL-Narrowing Residuation → Part C Demand-Driven Resolution

FL-Narrowing's definitional trees implement "needed demand analysis" — which variable must be instantiated for progress. The narrowing engine residuates (pauses) until the needed variable is bound. This is the same mechanism as Part C's trait resolution bridges: a bridge propagator sleeps (via the no-change guard) until its dependency type cell becomes ground.

**Key insight**: The propagator network provides residuation natively. No custom "sleep until ready" mechanism is needed — the threshold propagator + no-change guard IS the residuation mechanism. FL-Narrowing validated this: the narrowing engine didn't need a custom constraint solver because the propagator network already provides the "wait for information" pattern.

### Architecture A+D Intra-Walk Threading → Part B5 Constraint Collection

Architecture A+D's effect ordering engine threads state through bindings during the elaboration walk, then writes to cells at walk completion. The key insight: "propagator cells are for inter-quiescence communication; intra-walk state must use the threading medium."

Part B5's `surf-get` should follow this: during elaboration, collect `trait-constraint` descriptors in the elaboration context (like A+D's `'__effect_acc` binding key). After the elaborated expression is wired into the network, create the bridge propagators and let propagation handle resolution. This avoids premature cell reads during the walk.

### Capability-Type Bridge → Bidirectional α/γ Template

`cap-type-bridge.rkt` demonstrates the full Galois adjunction (α∘γ∘α = α, γ∘α∘γ = γ) for cases where bidirectional flow is needed. If future trait resolution requires reverse flow (e.g., a dict constraint refining the type), the cap-type-bridge provides the template for upgrading unidirectional trait bridges to bidirectional ones.

---

## 12. Principles Alignment (D.3 Self-Critique)

### Strongly Aligned

| Principle | How Track 8 Serves It |
|-----------|-----------------------|
| **Propagators as Universal Substrate** | Track 8 explores constraint resolution as the next domain on the propagator network. The central thesis in action. |
| **Propagator-First Infrastructure** | Part A: meta-info, id-map, mult/level/session → network citizens. Part B: callbacks → direct cell-ops. Part C: resolution → bridge propagators. Callbacks and scan loops are symptoms of resolution outside the network (DESIGN_PRINCIPLES §Stratified Propagator Networks) — Part C eliminates them. |
| **Correct by Construction** | Part A: TMS-based speculation replaces imperative snapshot (structural rollback). Part C: constraints resolve when dependencies are ground — structurally emergent, not imperatively discovered. Resolution is a property of the network topology, not a property maintained by a scan loop. |
| **The Most Generalizable Interface** | Part B: HKT `impl` + sugar constraint generation enables `xs[0]` to dispatch through `Indexed` (the most general interface) rather than hardcoded `expr-rrb`. |
| **Decomplection** | Part C decouples constraint *readiness detection* from constraint *resolution execution*. Currently both are in the imperative loop. After Part C, readiness is implicit in the bridge propagator firing (the type cell becoming ground IS the readiness signal); resolution is the α function producing the dict value. Decoupled by the network architecture. |
| **Open Extension, Closed Verification** | HKT `impl` enables open extension (users add `impl Seq MyCollection`). Verification remains closed (non-overlapping invariant, type-depth admissibility). |
| **First-Class by Default** | Part C makes constraint resolution a first-class participant in the propagator network. Bridge propagators are observable, composable, retractable. Currently resolution is an opaque imperative loop. After Part C, resolution state is visible in cells — any tool (observatory, LSP, debugger) can observe which constraints are pending, resolved, or failed. |
| **Data Orientation** | C1's α function IS the data-oriented replacement for the imperative resolution callback. The α function is a pure data transformation (type-val → dict-val). The imperative `resolve-trait-constraint!` is an effect-in-control-flow (lookup + `solve-meta!` + loop triggering). Part C replaces effects-in-control-flow with data-in-cells. |
| **Gödel Completeness** | Termination arguments stated for all Part C propagators (§Gödel Completeness section). Level 1 for individual bridges; Level 2 for feedback loops; Level 5 fuel as defense-in-depth. |
| **Layered Recovery** | Part C's simplified loop (S0 with bridges + rare S2) is the layered recovery principle applied: monotone reasoning (S0 bridges) to fixpoint, then non-monotone commitment (S2) at the barrier. |

### Honest Tensions

| Principle | Tension |
|-----------|---------|
| **Correct by Construction** | Memo cache correctness (Option D/E) is NOT correct-by-construction. It relies on timing discipline (disable during S0) or generation stamping. Track 9 (reduction as propagators) is the correct-by-construction answer. Acknowledged as a within-scope compromise. |
| **Simplicity of Foundation** | Part C adds bridge propagators per constraint, increasing network size. For a command with 20 trait constraints, that's 20 additional propagators + 20 additional cells. The trade-off: simpler control flow (no S1, reduced S2) at the cost of larger network. Measurement in C6 determines whether the trade-off is favorable. |

### D.4 Self-Critique: Prior Design Failed to Apply Principles

The D.1–D.3 design treated `restore-meta-state!` partial retirement as an acceptable outcome. The "belt-and-suspenders" framing (TMS + S(-1) for values, synchronous restore for structure) rationalized keeping an imperative mechanism alongside the propagator infrastructure.

This was a failure to steadfastly apply three load-bearing principles:

1. **Propagator-First Infrastructure** (§Stratified Propagator Networks): "Callbacks and scan loops are symptoms of resolution logic living outside the network." The imperative save/restore pattern IS a callback-like mechanism for state management. If the state is on the network (which A1-A4b achieved), the network's own mechanisms (ATMS worldviews, TMS retraction) should handle it. Designing a "belt-and-suspenders" workaround instead of making the network's mechanisms sufficient was a failure to trust the architecture.

2. **Data Orientation**: "Effects become first-class descriptions of intent, interpreted at explicit control boundaries." The box-snapshot mechanism makes speculation cleanup an *effect* (swap the box), not *data* (read the worldview). Worldview-aware reads make cleanup a data property: the read checks the worldview, and retracted entries are structurally invisible. No effect needed.

3. **Correct by Construction**: "Prefer designs where correctness is a structural property of the architecture, not maintained by discipline." The belt-and-suspenders timing — S(-1) runs at loop start, restore runs synchronously — is maintained by *timing discipline*, not structural properties. The A4 failure (ghost metas between retraction and S(-1)) was a direct consequence of timing-dependent correctness. Worldview-aware reads make correctness structural: the read either sees the entry (in worldview) or doesn't (retracted). No timing matters.

**The D.3 principles alignment check listed these principles but failed to challenge the workaround.** It asked "does this principle apply?" but not "does this design *violate* this principle?" The D.4 revision applies the principles: worldview-aware reads are propagator-first (reads through the network's ATMS), data-oriented (worldview is data, not an effect), and correct-by-construction (visibility is structural, not timing-dependent).

**Lesson for future PIRs and alignment checks**: When a principles check lists alignment without challenging workarounds, the check is cosmetic. The question must be: "does this design VIOLATE this principle, and if so, is the violation *necessary* or a failure of imagination?"

### Network Size Growth (D.3 finding)

Part C creates one bridge propagator + one dict cell per trait/hasmethod/deferred constraint. For a typical command with ~15 trait constraints + ~5 hasmethod constraints + ~10 deferred constraints, that's ~30 additional propagators and ~30 additional cells per command. The existing network for a typical command has ~50 cells and ~20 propagators (type metas + unification). Part C roughly doubles the network size.

This is the same scale increase that Track 7 introduced (29 persistent registry cells + readiness propagators). Track 7's measurements showed no performance regression from the additional cells. The CHAMP Performance work (owner-ID transients, value-only fast path) makes cell operations cheaper, mitigating the size increase.

Measurement in Phase C6 will determine if the network size growth affects wall-time within the ≤250s budget.
