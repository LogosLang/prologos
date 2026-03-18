# Stratified Architecture Audit

**Date**: 2026-03-18
**Purpose**: Deep audit of callback, scanning, sync, and accumulation patterns in the Prologos codebase to inform Track 7 design. Identifies sites where stratified propagator networks could replace imperative patterns.
**Scope**: All `.rkt` files in `racket/prologos/`
**Prior art**: Pipeline Audit (`2026-03-11_PROPAGATOR_FIRST_PIPELINE_AUDIT.md`), Track 6 PIR (§5.6, §6.4)

---

## 1. Callback Parameter Inventory

### 1.1 Resolution Callbacks (3 parameters — vestigial indirection)

| Parameter | File | Injected From | Circular Dep Broken |
|-----------|------|---------------|---------------------|
| `current-retry-unify` | metavar-store.rkt:471 | unify.rkt:748 | unify ↔ metavar-store |
| `current-retry-trait-resolve` | metavar-store.rkt:306 | driver.rkt:2108 | driver ↔ metavar-store |
| `current-retry-hasmethod-resolve` | metavar-store.rkt:381 | driver.rkt:2129 | driver ↔ metavar-store |

**Assessment**: All three are invoked FROM the stratified resolution loop's Stratum 2. The loop IS the replacement for what these callbacks were originally designed for (pre-Track-2 imperative retry). They exist as indirection to break circular module dependencies. Track 6 Phase 8d removed the immediate resolution paths at registration time and the dead functions that called them directly.

**Stratified prop-net alternative**: Each callback's logic becomes a propagator fire function. When S1's readiness cell transitions to `ready`, the propagator fires directly — no callback indirection. The circular dep is broken by the cell network itself (data flows through cells, not function calls through parameters).

**Risk**: Low. The callbacks are well-understood, tested, and narrow in scope.

### 1.2 Module System Callbacks (3 parameters — structural)

| Parameter | File | Injected From | Purpose |
|-----------|------|---------------|---------|
| `current-module-loader` | namespace.rkt:414 | driver.rkt:1718 | Module loading (imports) |
| `current-spec-propagation-handler` | namespace.rkt:420 | driver.rkt:1723 | Spec import after module load |
| `current-foreign-handler` | namespace.rkt:781 | driver.rkt:1719 | Foreign (Racket) imports |

**Assessment**: These break namespace.rkt ↔ driver.rkt circular deps. They are NOT resolution-related and do NOT participate in the stratified loop. Module loading is an imperative side-effect (file I/O, parsing, elaboration) that doesn't naturally fit the propagator model.

**Stratified prop-net alternative**: Module loading could be modeled as a cell state transition (module-status lattice: `unloaded → loading → loaded`), with the loading logic as a propagator that fires when `loading` is written. But this is Track 10 (LSP) scope — batch mode doesn't benefit.

**Risk**: Medium. Module loading has complex side effects (file I/O, recursive elaboration).

### 1.3 Propagator Network Callbacks (18 parameters — structural coupling)

| Parameter | Purpose |
|-----------|---------|
| `current-prop-make-network` | Create fresh elab-network |
| `current-prop-fresh-meta` | Allocate metavariable + cell |
| `current-prop-cell-write` / `current-prop-cell-read` | Core cell operations |
| `current-prop-add-unify-constraint` | Register unification constraint |
| `current-prop-new-infra-cell` | Create infrastructure cell |
| `current-prop-id-map-read` / `current-prop-id-map-set` | Id-map access |
| `current-prop-meta-info-read` / `current-prop-meta-info-set` | Meta-info access |
| `current-prop-reset-network-command-state` | Per-command reset |
| `current-prop-fresh-mult-cell` / `current-prop-mult-cell-write` | Multiplicity cells |
| `current-prop-fresh-level-cell` / `current-prop-fresh-sess-cell` | Level/session cells |
| `current-prop-has-contradiction?` | Contradiction detection |
| `current-prop-run-quiescence` | Run network to fixpoint |
| `current-prop-unwrap-net` / `current-prop-rewrap-net` | elab-network ↔ prop-network |

**Assessment**: These break elaborator-network.rkt ↔ metavar-store.rkt circular deps. They form the "propagator API" that metavar-store uses to interact with the network without importing the network module. This is the largest callback cluster (18 parameters).

**Stratified prop-net alternative**: If metavar-store.rkt could import the network module directly (via module restructuring), all 18 callbacks become direct function calls. This is a mechanical refactoring, not an architectural change. The functions already exist in elaborator-network.rkt — the callbacks are pure indirection.

**Risk**: Low-medium. Large surface area (50+ call sites) but each transformation is mechanical.

### 1.4 Relational System Callbacks (2 parameters — domain-specific)

| Parameter | File | Purpose |
|-----------|------|---------|
| `current-is-eval-fn` | relations.rkt:66 | Evaluate functional sub-expressions in relational goals |
| `current-naf-oracle` | relations.rkt:75 | Well-founded semantics NAF oracle |

**Assessment**: These are domain-specific hooks for the relational/logic programming subsystem. `current-is-eval-fn` is parameterized per-goal with `whnf` (the normalizer). `current-naf-oracle` enables well-founded semantics. Neither participates in type-checking resolution.

**Stratified prop-net alternative**: Not applicable. Relational goals are demand-driven (DFS search), not reactive (propagation). The callbacks are used at goal evaluation time, not constraint resolution time.

**Risk**: N/A — out of scope for stratified architecture.

---

## 2. Imperative Scanning Patterns

### 2.1 Stratum 1: Readiness Collection (6 functions)

| Function | Scans | Complexity | Cell-Driven? |
|----------|-------|------------|--------------|
| `collect-ready-constraints-via-cells` | Constraint store cell | O(constraints) | Partially — reads cells but iterates ALL |
| `collect-ready-constraints-for-meta` | Wakeup registry for one meta | O(per-meta) | No — fallback path |
| `collect-ready-traits-via-cells` | Trait cell-map | O(trait-constraints) | Partially — reads cells but iterates ALL |
| `collect-ready-traits-for-meta` | Trait wakeup map for one meta | O(per-meta) | No — targeted wakeup |
| `collect-ready-hasmethods-via-cells` | HasMethod cell-map | O(hasmethod-constraints) | Partially — reads cells but iterates ALL |
| `collect-ready-hasmethods-for-meta` | HasMethod wakeup map for one meta | O(per-meta) | No — targeted wakeup |

**Key insight**: The "via-cells" functions are O(total) — they iterate ALL constraints/traits/hasmethods each stratum cycle, checking each one's dependency cells. In a system with many constraints, this is the scanning bottleneck.

**Stratified prop-net alternative**: Replace scanning with **readiness propagators**. When a constraint's dependency cell transitions from bot to non-bot, a propagator fires and writes to a "ready queue" cell. S1 becomes a cell read (O(1)) instead of a scan (O(total)).

**Estimated impact**: Constraint-heavy programs (generic arithmetic, deeply polymorphic code) would see the largest benefit. Current fuel limit is 100 iterations × O(total) = O(100 × total) per command.

### 2.2 Post-Command Scanning (2 functions)

| Function | Scans | Complexity | Purpose |
|----------|-------|------------|---------|
| `all-postponed-constraints` | Constraint store (filter by 'postponed) | O(total) | Error reporting |
| `all-failed-constraints` | Constraint store (filter by 'failed) | O(total) | Error reporting |

**Assessment**: Used once per command for error reporting. Low frequency, acceptable overhead. Could be replaced by maintaining "postponed" and "failed" accumulator cells that receive writes when constraint status changes.

### 2.3 Meta Scanning (2 functions)

| Function | Scans | Complexity | Purpose |
|----------|-------|------------|---------|
| `all-unsolved-metas` | CHAMP or unsolved-metas cell | O(total) or O(1) | Error reporting |
| `primary-unsolved-metas` | all-unsolved-metas → filter | O(total) | Error reporting |

**Assessment**: Track 6 Phase 1d added `unsolved-metas-cell-id` for O(1) access. CHAMP fallback remains for backward compatibility. Fallback should be eliminated.

---

## 3. Sync/Reconciliation Patterns

### 3.1 Per-Command Cell Registration (5 functions)

| Function | Source → Target | When |
|----------|-----------------|------|
| `register-macros-cells!` | 24 params → 24 cells | Per command |
| `register-warning-cells!` | 3 params → 3 cells | Per command |
| `register-narrow-cells!` | 2 params → 2 cells | Per command |
| `register-global-env-cells!` | definition-cells-content → per-name cells | Per command |
| `register-namespace-cells!` | ns-context, module-registry → cells | Per command |

**Assessment**: These recreate cells each command because the elab-network is created fresh by `reset-meta-store!`. The cells are ephemeral (per-command); the parameters are persistent (cross-command). The registration is a sync from persistent store → ephemeral propagation layer.

**Stratified prop-net alternative**: If macros/warnings/narrowing cells were **persistent across commands** (living outside the per-command elab-network), registration would happen once at prelude load time, not per-command. This is the architectural change discussed in Track 6's 7b/7c reassessment — making cells the persistence layer, not just the propagation layer.

**Dependency**: Requires separating persistent cells (registries, definitions) from per-command cells (metas, constraints) in the network architecture.

### 3.2 Speculation Save/Restore

| Pattern | Boxes | Content |
|---------|-------|---------|
| `save-meta-state` / `restore-meta-state!` | 1 (network) | Immutable CHAMP snapshot of elab-network |

**Assessment**: Post-Track 6, only the network box is saved/restored. TMS retraction handles value-level rollback. The network snapshot remains because infrastructure cells aren't TMS-managed (Phase 5b blocker).

**Stratified prop-net alternative**: If infrastructure cells used assumption-tagged accumulation, `restore-meta-state!` would become a no-op — all state would be retracted via TMS. This eliminates the network box entirely, making speculation a pure ATMS operation.

### 3.3 Batch-Worker State Isolation

**Pattern**: Parameterize all registry/env parameters to post-prelude snapshot per test file. Network isolation via `[current-prop-net-box #f]`.

**Assessment**: Already the cleanest isolation pattern in the codebase. Uses structural scoping (parameterize auto-revert). No imperative sync needed.

### 3.4 Module Import Materialization

**Pattern**: `global-env-import-module` reads from `module-network-ref` cells, writes to `current-module-definitions-content` parameter.

**Assessment**: This is the Track 5 → Track 6 cutover. Module network is authoritative; the parameter is a read cache for O(1) lookup. Not a true sync — it's a one-directional population.

---

## 4. Infrastructure Cell Accumulation Patterns

### 4.1 Merge Function Taxonomy

| Merge Function | Cells | Monotone | Invertible | TMS-Aware |
|----------------|-------|----------|------------|-----------|
| `merge-hasheq-union` | 33 | Yes | No | No |
| `merge-hasheq-list-append` | 3 | Yes | No | No |
| `merge-list-append` | 4 | Yes | No | No |
| `merge-set-union` | 1 | Yes | No | No |
| `merge-replace` / `merge-last-write-wins` | N+2 | No | Yes (locally) | No |
| `merge-constraint-status-map` | 1 | Partial | No | No |
| `merge-error-descriptor-map` | 1 | No | No | No |
| `merge-mod-status` | per-module | Partial | No | No |
| `session-lattice-merge` | per-process | Yes | No | No |

### 4.2 TMS Retraction Support Matrix

| Cell Category | Count | Current TMS Support | Retraction Behavior |
|---------------|-------|---------------------|---------------------|
| **Registry cells** (macros) | 24 | None | Entries persist across retractions |
| **Constraint cells** (metavar-store) | 8 | None | Constraints persist, wakeups fire orphaned handlers |
| **Warning cells** | 3 | None | Warnings persist |
| **Wakeup cells** | 3 | None | Handlers persist |
| **Narrowing cells** | 2 | None | Constraints persist |
| **Definition cells** | N+1 | None | Per-command, not assumption-scoped |
| **Level/session meta cells** | 2 | TMS (via `net-new-tms-cell`) | Values retractable per assumption |
| **Error descriptor cell** | 1 | None | Last-write-wins persists |
| **Unsolved-metas cell** | 1 | None | Monotonic accumulation |

**Key finding**: Only level and session meta cells have TMS support. All infrastructure cells (41+) are monotonic accumulators with no retraction capability. This is the Phase 5b blocker.

### 4.3 Options for TMS-Aware Accumulation

**Option A: Assumption-Tagged Values**
Replace `merge-hasheq-union` with assumption-scoped writes. Each entry tagged with its creating assumption. Reads filter by believed assumptions. Retraction hides entries from non-believed assumptions.
- Pro: Clean semantics, integrates with existing ATMS
- Con: Every reader must filter; performance overhead on hot paths

**Option B: Assumption-Scoped Overlays**
Keep monotonic base, add per-assumption removal set. Retraction adds to removal set instead of modifying base.
- Pro: Base reads unchanged for common case (no speculation)
- Con: O(n) removal tracking; complex merge semantics

**Option C: Segregated Cell Classes**
Split cells into permanent (registries) and scoped (constraints, warnings). Only scoped cells get TMS awareness.
- Pro: Minimal change to registries (which are genuinely permanent within a command)
- Con: Dual-cell reads; constraint→registry interactions cross boundaries

**Option D: Nogood-Based Constraint Filtering**
Leverage ATMS nogoods to mark "retracted" constraints. Readers check nogoods before accepting values.
- Pro: Leverages existing ATMS infrastructure
- Con: Requires integrating nogood semantics with cell reads; potentially expensive filtering

**Recommendation**: Option C (segregated classes) for Track 7 initial scope, with Option A as the long-term architecture. Registries are genuinely permanent — a `def` or `type` doesn't get un-defined during speculation. Constraints and warnings are genuinely per-assumption — a constraint added during a speculative branch should be retracted if the branch fails.

---

## 5. Inter-Stratum Data Flow Map

### 5.1 Current Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                  run-stratified-resolution!                   │
│                                                               │
│  ┌──────────── S0: Propagator Quiescence ──────────────┐    │
│  │  • Unwrap elab-network → prop-network               │    │
│  │  • run-to-quiescence (propagators fire)             │    │
│  │  • Rewrap prop-network → elab-network               │    │
│  │  Reads:  meta cells, constraint cells               │    │
│  │  Writes: meta cells (via propagator fire)           │    │
│  └─────────────────────────────────────────────────────┘    │
│                          │                                    │
│                    quiescence                                 │
│                          ▼                                    │
│  ┌──────────── S1: Readiness Scan ─────────────────────┐    │
│  │  • collect-ready-constraints-via-cells  (O(total))  │    │
│  │  • collect-ready-traits-via-cells       (O(total))  │    │
│  │  • collect-ready-hasmethods-via-cells   (O(total))  │    │
│  │  • + targeted wakeup for trigger meta               │    │
│  │  Reads:  constraint store, trait/hm maps, cell vals │    │
│  │  Writes: NONE (pure observation)                    │    │
│  │  Output: (listof action-descriptor)                 │    │
│  └─────────────────────────────────────────────────────┘    │
│                          │                                    │
│                   action descriptors                          │
│                          ▼                                    │
│  ┌──────────── S2: Resolution Commitment ──────────────┐    │
│  │  For each action:                                    │    │
│  │    action-retry-constraint → (current-retry-unify)  │    │
│  │    action-resolve-trait    → (current-retry-trait-*) │    │
│  │    action-resolve-hasmethod → (current-retry-hm-*)  │    │
│  │  Reads:  constraint, tc-info, hm-info, type-args   │    │
│  │  Writes: constraint status, error descriptors       │    │
│  │  Side effects: solve-meta! (sets progress-box)      │    │
│  └─────────────────────────────────────────────────────┘    │
│                          │                                    │
│                   progress-box?                               │
│                    ┌─────┴─────┐                             │
│                    │ #t        │ #f                           │
│                    ▼           ▼                              │
│               loop(fuel-1)   EXIT                             │
└─────────────────────────────────────────────────────────────┘
```

### 5.2 Target Architecture (Stratified Prop-Net)

```
┌─────────────────────────────────────────────────────────────┐
│              Stratified Propagator Network                    │
│                                                               │
│  ┌──────────── Layer 0: Type Propagation ──────────────┐    │
│  │  Meta cells + unification propagators (existing)     │    │
│  │  Fires when: meta cell value changes                │    │
│  │  Outputs: solved metas → Layer 1 readiness cells    │    │
│  └─────────────────────────────────────────────────────┘    │
│         │          Galois connection (upper adjoint)          │
│         ▼                                                     │
│  ┌──────────── Layer 1: Readiness Propagators ─────────┐    │
│  │  Per-constraint readiness cell (pending → ready)     │    │
│  │  Propagator: watches dependency cells from Layer 0   │    │
│  │  Fires when: all deps non-bot → writes 'ready       │    │
│  │  NO SCANNING — purely reactive                       │    │
│  │  Output: ready-queue cell accumulates ready actions  │    │
│  └─────────────────────────────────────────────────────┘    │
│         │          Galois connection (upper adjoint)          │
│         ▼                                                     │
│  ┌──────────── Layer 2: Resolution Propagators ────────┐    │
│  │  Per-action-type resolution propagator               │    │
│  │  Fires when: ready-queue has entries                 │    │
│  │  Resolution logic IS the fire function               │    │
│  │  Output: solve-meta! → perturbs Layer 0             │    │
│  │  NO CALLBACKS — logic is structural                  │    │
│  └─────────────────────────────────────────────────────┘    │
│         │                                                     │
│         └───── S2 output perturbs S0 (lower adjoint) ──────→│
│                                                               │
│  Termination: all readiness cells stable, no new actions     │
└─────────────────────────────────────────────────────────────┘
```

### 5.3 What Must Become Cells

| Current Form | Current Location | Target Cell | Layer |
|--------------|-----------------|-------------|-------|
| Action descriptor list | Stack variable in loop | Ready-queue cell | L1→L2 |
| Progress flag | Racket box parameter | Implicit (network dirty flag) | L2→L0 |
| Fuel counter | Loop variable | Not needed (network quiescence = termination) |  |
| Per-constraint readiness | Computed by scan | Per-constraint readiness cell | L1 |
| Resolution logic | Callback parameter | Propagator fire function | L2 |

---

## 6. Classified Inventory: Candidates for Stratified Prop-Net Migration

### Priority 1: Resolution Callbacks → Propagators (Track 7 WS-B)

| Item | Current | Target | Risk | Dependencies |
|------|---------|--------|------|-------------|
| `current-retry-unify` | Callback from unify.rkt | L2 propagator: fires on constraint readiness | Low | Module restructuring |
| `current-retry-trait-resolve` | Callback from driver.rkt | L2 propagator: fires on trait readiness | Low | Module restructuring |
| `current-retry-hasmethod-resolve` | Callback from driver.rkt | L2 propagator: fires on hasmethod readiness | Low | Module restructuring |
| S1 readiness scan (6 functions) | O(total) iteration | L1 readiness propagators (per-constraint) | Medium | Readiness cell infrastructure |

### Priority 2: Infrastructure Cell TMS (Track 7 WS-B)

| Item | Current | Target | Risk | Dependencies |
|------|---------|--------|------|-------------|
| Constraint cells (8) | Monotonic, no retraction | Assumption-scoped accumulation | Medium | TMS accumulation design |
| Warning cells (3) | Monotonic, no retraction | Assumption-scoped (or segregated) | Low | Option C design |
| Wakeup cells (3) | Monotonic, no retraction | Assumption-scoped (orphan cleanup) | Medium | Depends on constraint TMS |

### Priority 3: Persistent Registry Cells (Track 7 or later)

| Item | Current | Target | Risk | Dependencies |
|------|---------|--------|------|-------------|
| 24 macros registry cells | Recreated per-command from params | Persistent across commands | High | Network architecture change |
| 3 warning accum cells | Recreated per-command from params | Persistent across commands | Medium | Same as above |
| 2 narrowing cells | Recreated per-command from params | Persistent across commands | Medium | Same as above |

### Priority 4: Network API Callbacks (Track 7 or later)

| Item | Current | Target | Risk | Dependencies |
|------|---------|--------|------|-------------|
| 18 prop-network callbacks | Parameter indirection | Direct function calls | Low-Med | Module restructuring |

### Out of Scope

| Item | Reason |
|------|--------|
| Module system callbacks (3) | Side-effectful (file I/O); LSP scope |
| Relational callbacks (2) | Domain-specific; demand-driven, not reactive |
| Batch-worker isolation | Already correct (parameterize-based) |

---

## 7. Risk Assessment Summary

| Change | Files Affected | Test Risk | Performance Risk |
|--------|---------------|-----------|------------------|
| Callback inlining (3 resolution) | metavar-store, driver, unify | Low | Neutral |
| Readiness propagators (replace S1 scan) | metavar-store, elaborator-network | Medium | Positive (O(changed) vs O(total)) |
| TMS-aware constraint cells | metavar-store, infra-cell | Medium | Slight negative (filtering overhead) |
| Persistent registry cells | macros, warnings, global-constraints, driver | High | Unknown (CHAMP sharing?) |
| Network API callback elimination (18) | metavar-store, elaborator-network | Low | Neutral |

---

## 8. Recommendations for Track 7 Design

1. **Start with callback inlining** — lowest risk, breaks the circular deps that all other changes need to navigate. Module restructuring is the prerequisite for everything else.

2. **Readiness propagators as the architectural proof-of-concept** — implementing L1 readiness cells for trait constraints demonstrates the stratified prop-net pattern on a well-understood subsystem. If it works for traits, the same pattern applies to constraints and hasmethods.

3. **Segregated cell classes (Option C) for TMS** — don't TMS-ify registries (they're permanent). Focus TMS-aware accumulation on constraints and warnings (the cells that actually participate in speculation).

4. **Defer persistent registry cells** — this requires a network architecture change (separating persistent from per-command cells) that's larger than Track 7's scope. The current dual-write (param persistence + cell propagation) is the correct pattern until the architecture supports persistent cells.

5. **Belt-and-suspenders retirement as validation gate** — Phase 5b's blocker is the success criterion for TMS-aware infrastructure cells. If constraints, warnings, and wakeups can be retracted via TMS, the network-box restore becomes unnecessary.
