# Track 7: Persistent Registry Cells + Stratified Propagator Network + QTT Multiplicity Cells — Stage 2/3 Design

**Created**: 2026-03-18
**Status**: DESIGN (Stage 2/3 — awaiting critique)
**Depends on**: Track 3 ✅, Track 4 ✅, Track 5 ✅, Track 6 ✅
**Enables**: Track 8 (Unification as Propagators), Track 9 (GDE), Track 10 (LSP)
**Master roadmap**: `2026-03-13_PROPAGATOR_MIGRATION_MASTER.md` Track 7
**Audit**: `2026-03-18_STRATIFIED_ARCHITECTURE_AUDIT.md`
**Prior PIRs**: Track 4 (TMS cell architecture), Track 5 (persistent module networks), Track 6 (stratified prop-net insight, dual-write reframing, context-loss risk)
**Principle references**: DESIGN_PRINCIPLES.org § "Stratified Propagator Networks", DEVELOPMENT_LESSONS.org § "Callbacks Are a Propagator-First Anti-Pattern", GÖDEL_COMPLETENESS.org (termination guarantee hierarchy)

---

## Progress Tracker

| Phase | Description | Status | Termination | Notes |
|-------|-------------|--------|-------------|-------|
| D.1 | Initial design document | 🔄 | — | This document |
| D.2 | External critique | ⬜ | — | |
| D.3 | Self-critique (principle alignment) | ⬜ | — | |
| 0 | Performance baseline + acceptance file | ⬜ | — | |
| 1 | Persistent registry network infrastructure | ⬜ | L1 (finite registries) | WS-C: separate persistent network for registries |
| 2 | Registry cell persistence migration | ⬜ | L1 (monotone merge) | WS-C: migrate 24 macros + 3 warning + 2 narrowing cells |
| 3 | Dual-write elimination | ⬜ | — (no new propagators) | WS-C: remove parameter writes from register functions |
| 4 | Assumption-tagged scoped cells | ⬜ | L1 (finite assumptions) | WS-B: tag constraint/wakeup/warning writes with assumption IDs |
| 5 | S(-1) retraction stratum | ⬜ | L1 (assumption set ↓) | WS-B: retraction propagator, cleanup to fixpoint |
| 6 | Belt-and-suspenders retirement | ⬜ | — (removal, not addition) | WS-B: remove network-box restore (Phase 5b gate) |
| 7 | Callback inlining + resolution.rkt extraction | ⬜ | — (restructuring only) | WS-B: module restructuring, direct calls |
| 8a | Readiness propagators (L1) | ⬜ | L1 (fire once per dep) | WS-B: replace O(total) S1 scanning with per-constraint readiness cells |
| 8b | Resolution propagators (L2) | ⬜ | L2 (type depth ↓) | WS-B: replace `execute-resolution-actions!` loop with propagators |
| 8c | Stratified loop elimination | ⬜ | L1+L2 (composed) | WS-B: `run-stratified-resolution!` → layered network quiescence |
| 9 | QTT multiplicity cells + cross-domain bridges | ⬜ | L1 (3-element lattice) | WS-A: mult lattice in network |
| 10 | Performance validation + PIR | ⬜ | — | |

---

## Non-Goals

Track 7 does NOT deliver:

- **LSP integration** — persistent cells and retraction benefit the LSP, but LSP-specific concerns (file watching, incremental re-elaboration triggers) are Track 10.
- **Cross-module shadow-cell consistency** — Track 5's shadow-cell pattern is batch-correct. Multi-invocation consistency is Track 10 (LSP).
- **Persistent definition cells** — definition cells already persist via `current-definition-cells-content` (Track 5 pattern). Track 7 extends this pattern to registries only.
- **GDE minimal diagnoses** — Track 7 builds the propagator infrastructure that GDE will consume (Track 9).

---

## 1. Problem Statement

After six tracks of propagator migration, the architecture carries three forms of transitional debt:

**1. Per-command cell recreation**: Every command recreates 29+ registry cells from parameters via `register-macros-cells!`, `register-warning-cells!`, and `register-narrow-cells!`. The parameters are the persistent store; cells are ephemeral propagation shadows. This means:
- 29 cell allocations + network insertions per command (~7000 tests × 29 = ~200K cell creations during a test run)
- The dual-write pattern (param + cell) in every `register-*!` function exists because cells aren't persistent
- Cell-id parameters are reset every command, making cell references unstable

Track 6 PIR §5.2 identified this correctly: "parameter writes are the persistent data store; cell writes are for propagation." But this is transitional — the propagator-first architecture says cells should BE the persistent store.

**2. No retraction for infrastructure cells**: TMS retraction (Track 6 Phases 2+3, 4) works for value-level cells (metavariables) but not for infrastructure cells (constraints, wakeups, warnings) that use monotonic accumulation (`merge-hasheq-union`, `merge-list-append`). The Phase 5b belt-and-suspenders retirement is blocked because `restore-meta-state!` must still snapshot/restore the network box for infrastructure cells.

**3. Imperative scanning and callback indirection**: The stratified resolution loop's Stratum 1 iterates all constraints/traits/hasmethods each cycle (O(total)). Resolution logic is injected via 3 callback parameters that break circular module dependencies. Both patterns work but violate propagator-first principles — readiness should be a cell value, resolution should be structural.

### Workstream ordering: hard thing first

Following the principle established in Tracks 4-6, Track 7 orders workstreams by architectural significance:

- **WS-C (Persistent Registry Cells)** — most foundational. Changes the persistence model from parameters to cells. All other workstreams benefit from stable cell references.
- **WS-B (Stratified Retraction + Readiness Propagators)** — depends on WS-C for stable cell infrastructure. S(-1) retraction and readiness propagators need cells that persist across commands.
- **WS-A (QTT Multiplicity Cells)** — smallest, lowest risk. Can proceed independently once the network architecture is stable.

---

## 2. Architectural Foundation

### 2.1 Two-network architecture: persistent + ephemeral

The key insight from Track 5's definition cell pattern: `current-definition-cells-content` (persistent hasheq) + per-command cell recreation in `register-global-env-cells!`. Definitions persist; their cells are recreated each command. This works but creates unstable cell references.

Track 7 introduces a **persistent network** that lives alongside the per-command elab-network:

```
┌─────────────────────────────────────────────────────────┐
│  Per-File Persistent State                               │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │  Persistent Registry Network (NEW in Track 7)     │   │
│  │  • 24 macros registry cells                       │   │
│  │  • 3 warning accumulator cells                    │   │
│  │  • 2 narrowing constraint cells                   │   │
│  │  • Created once at file/prelude load time         │   │
│  │  • Survives across commands                       │   │
│  │  • Cell IDs are STABLE (never recreated)          │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
│  current-definition-cells-content (existing — Track 5)   │
│  current-module-definitions-content (existing — Track 6) │
│  current-prelude-env (existing — belt-and-suspenders)    │
│                                                          │
├─────────────────────────────────────────────────────────┤
│  Per-Command Ephemeral State                             │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │  Elab-Network (existing — created by reset-meta)  │   │
│  │  • Metavariable cells (per-meta)                  │   │
│  │  • Constraint infrastructure cells (12)           │   │
│  │  • Definition cells (recreated from content)      │   │
│  │  • TMS cells for speculation                      │   │
│  │  • Cleared per command via reset-meta-store!      │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
│  current-meta-store, current-constraint-store, etc.      │
└─────────────────────────────────────────────────────────┘
```

**Why two networks, not one?** Metavariables and constraints are genuinely per-command — they're created, solved, and discarded within a single type-checking pass. Registries are genuinely per-file — a `type` or `trait` defined in command 1 must be visible in command 2. Mixing them in one network means either (a) the whole network is recreated per command (current approach — destroys registry cell stability), or (b) the network persists but metas/constraints must be selectively cleared (complex, error-prone).

Two networks with different lifecycles is the clean separation. The elab-network handles per-command inference. The persistent network handles cross-command state. Reads can consult both; writes go to the appropriate network based on the data's lifecycle.

### 2.2 The CHAMP advantage

Both networks are CHAMP-based (`prop-network`). Two separate `prop-network` instances share no CHAMP structure by default, but this is fine — the persistent network is small (~29 cells) and its cost is amortized across many commands. The elab-network is the large, per-command structure with potentially hundreds of metavariable cells.

### 2.3 Cell stability enables downstream architecture

With persistent cells, cell IDs become stable file-level identifiers. This enables:
- **Readiness propagators** (WS-B Phase 8): a propagator watching a registry cell doesn't need to be recreated each command
- **S(-1) retraction** (WS-B Phase 5): the retraction propagator watches persistent cells, not ephemeral ones
- **LSP observation** (Track 10): the LSP can watch registry cells for changes without needing per-command cell-id rediscovery
- **Dual-write elimination** (WS-C Phase 3): once cells persist, parameters are unnecessary for persistence — cells ARE the persistent store

### 2.4 Stratified retraction: S(-1) as the dual of NAF-LE aggregation

The stratified architecture audit (§4.4) established that retraction is the dual of aggregation in stratified semantics. Both are non-monotonic operations made safe by stratification — computing to fixpoint before downstream strata observe the result.

The S(-1) stratum handles retraction for **scoped cells** — cells that participate in speculation:

| Cell Class | Examples | Retraction | Persistence |
|------------|----------|------------|-------------|
| **Permanent** | 24 macros registries | Not retractable | Persistent network |
| **Scoped** | 8 constraint, 3 wakeup, 3 warning cells | S(-1) retraction | Elab-network (per-command) |
| **Value** | Metavariable cells | TMS retraction (existing) | Elab-network (per-command) |

Permanent cells (registries) don't participate in speculation — a `type` definition isn't created speculatively. Scoped cells (constraints, wakeups, warnings) are created during elaboration and may be created under speculative assumptions. Value cells (metas) already have TMS retraction from Track 4/6.

### 2.5 The complete stratified propagator network

Track 7 delivers the **full stratified propagator network** — not just readiness propagators and retraction, but also resolution propagators and the elimination of the hand-written stratified loop. The complete architecture:

```
┌──────────────────────────────────────────────────────────────────────┐
│  Layered Network Quiescence (replaces run-stratified-loop!)          │
│                                                                       │
│  S(-1): Retraction Layer                                              │
│    Watches: believed-assumptions cell                                 │
│    Fires: cleanup propagators for scoped cells                        │
│    Non-monotone, contained below S0                                   │
│                                                                       │
│  S0: Type Propagation Layer                                           │
│    Existing: unification propagators, meta cells                      │
│    Fires: when meta cell values change                                │
│    Monotone (type lattice)                                            │
│                                                                       │
│  L1: Readiness Detection Layer                                        │
│    New: fan-in readiness propagators (1 per constraint)               │
│    Countdown latch: O(1) readiness check via ground-count             │
│    Writes: action descriptors to ready-queue channel cell             │
│    O(changed), not O(total) — no scanning                             │
│                                                                       │
│  L2: Resolution Commitment Layer                                      │
│    New: resolution propagator watching ready-queue                    │
│    Fire function IS the resolution logic                              │
│    Output: solve-meta! → writes to meta cells → perturbs S0          │
│    No callbacks — logic is structural                                 │
│                                                                       │
│  Scheduling: Hybrid BSP/Gauss-Seidel                                  │
│    WITHIN each stratum: BSP (all dirty propagators fire per round)    │
│    BETWEEN strata: Gauss-Seidel (S(-1)→S0→L1→L2, sequential)         │
│    Justified by CALM: intra-stratum propagation is monotone (safe     │
│    for BSP/no coordination). Inter-stratum transitions are non-       │
│    monotone from the higher stratum's perspective (need coordination  │
│    = barrier = Gauss-Seidel ordering).                                │
│    Feedback: if L2 wrote to S0 cells, restart from S(-1)             │
│                                                                       │
│  Termination: quiescence across ALL layers                            │
│  (replaces fuel counter in hand-written loop)                         │
│                                                                       │
│  Bridge Propagators (Galois Connection)                               │
│    Persistent registry network ←→ Elab-network                       │
│    One-way bridge per registry cell: persistent cell is source,       │
│    shadow cell in elab-network is target. Created once per command    │
│    (lazy — fired once on initial sync). Cheaper than recreating 29   │
│    cells and seeding from parameters.                                 │
└──────────────────────────────────────────────────────────────────────┘
```

This is the architectural completion of the propagator-first vision for constraint resolution. After Track 7, adding a new constraint type means adding an L1 readiness propagator (fan-in) and an L2 resolution propagator — no loop modifications, no scanning functions, no callbacks.

### 2.6 Propagator Taxonomy

Track 7 introduces several propagator patterns beyond the basic "cell A → propagator → cell B" transform. This taxonomy classifies the granular patterns used across the architecture:

**Structural patterns** (how propagators connect cells):

| Pattern | Inputs | Outputs | Description | Example |
|---------|--------|---------|-------------|---------|
| **Transform** | 1 cell | 1 cell | Monotone map between lattice values | Type substitution propagator |
| **Fan-in** | N cells | 1 cell | Combines N inputs to produce one output. Enables countdown latch optimization: maintain a ground-count per output; each input transition from ⊥ increments count; output fires when `count == N`. O(1) per input change, O(1) readiness check. Under BSP, fires once per round (checking all N inputs in one pass). | L1 readiness propagator |
| **Fan-out** | 1 cell | N cells | Broadcasts one value to N targets | Shadow cell population from module network |
| **Bridge** | 1 cell (net A) | 1 cell (net B) | Cross-network Galois connection. Lower adjoint: source → target. Upper adjoint: identity (read-only bridge) or merge (bidirectional). | Persistent registry → elab-network shadow |

**Lifecycle patterns** (how cells participate in state management):

| Pattern | Write | Read | Consume | Description | Example |
|---------|-------|------|---------|-------------|---------|
| **Value cell** | Monotone merge | Current value | — | Standard lattice cell. Value only grows. | Meta cell, type cell |
| **Accumulator cell** | List-append / hash-union | Full collection | S(-1) retraction by assumption | Collects entries tagged with assumptions. Retraction removes non-believed entries. | Constraint store, wakeup index |
| **Channel cell** | Tagged write (L1) | Read (L2) | Retract assumption (L2) → S(-1) cleanup | Produce-consume pattern. Writer tags entries with fresh assumptions; consumer reads entries and retracts their assumptions; S(-1) cleans retracted entries. All on-network. | Ready-queue between L1 and L2 |
| **Shadow cell** | Mirror from source (bridge) | Same as source | Follows source lifecycle | Read-only projection of a cell in another network. | Elab-network view of persistent registry cell |

**Scheduling patterns** (how propagators interact with the layered scheduler):

| Pattern | Layer | Scheduling | Description | Example |
|---------|-------|------------|-------------|---------|
| **Stratum propagator** | Tagged S(-1)/S0/L1/L2 | BSP within layer, Gauss-Seidel between layers | Standard layer-tagged propagator. Fires during its layer's BSP round. | All Track 7 propagators |
| **Threshold propagator** | Cross-layer | Fires at stratum transition (quiescence of lower layer) | Activates when lower layer reaches fixpoint. Used for stratum boundary logic. | S(-1) → S0 transition, L1 → L2 transition |

This taxonomy is a starting point. A richer taxonomy — including patterns for distributed/concurrent runtimes, temporal propagators, and higher-order propagators — is deferred to future research (see DEFERRED.md).

### 2.7 Readiness propagators: O(changed) replaces O(total)

The audit (§2.1) identified 6 scanning functions in S1 that iterate all constraints/traits/hasmethods each cycle. The replacement:

- At constraint registration time, create a **readiness propagator** that watches the constraint's dependency cells
- When all dependencies become non-bot, the propagator writes an action descriptor to a **ready-queue cell**
- S1 becomes a cell read (pop from ready-queue) instead of a scan

This is the standard propagator-network approach: instead of polling for readiness, react to it.

---

## 3. Infrastructure Gap Analysis

### What we have (from Tracks 1–6)

| Infrastructure | Status | Source |
|----------------|--------|--------|
| Per-definition persistent cells | ✅ | Track 5 (`current-definition-cells-content`) |
| Module-network-ref (persistent per-module) | ✅ | Track 5 |
| TMS cells for metavariables | ✅ | Track 4/6 |
| TMS retraction for value cells | ✅ | Track 6 Phases 2+3, 4 |
| Speculation stack push + commit | ✅ | Track 6 Phases 2+3 |
| Elaboration guard removal | ✅ | Track 6 Phase 8b-c |
| Net-box scoping to command | ✅ | Track 6 Phase 8b-c |
| Cell-primary readers (unconditional) | ✅ | Track 3 + Track 6 |
| Stratified resolution loop (S0-S1-S2) | ✅ | Track 2 |
| Action descriptor pattern | ✅ | Track 2 Phase 4 |

### What we need

| Gap | Required For | Phase | Complexity |
|-----|-------------|-------|-----------|
| Persistent registry network | Stable cell IDs, dual-write elimination | WS-C Phase 1 | Medium |
| Registry cell migration | Move 29 cells to persistent network | WS-C Phase 2 | Medium |
| Assumption tagging on scoped cell writes | S(-1) retraction | WS-B Phase 4 | Low |
| Believed-assumptions cell | S(-1) trigger | WS-B Phase 5 | Low |
| S(-1) retraction propagator | Cleanup non-believed entries | WS-B Phase 5 | Medium |
| Ready-queue cell + per-constraint readiness propagators | Replace S1 scanning | WS-B Phase 8 | Medium |
| Module restructuring for callback inlining | Direct resolution calls | WS-B Phase 7 | Low |
| Mult lattice + cells | QTT in network | WS-A Phase 9 | Low |
| Type ↔ mult bridge propagators | Cross-domain reasoning | WS-A Phase 9 | Low |

---

## 4. Design: WS-C — Persistent Registry Cells

### Phase 1: Persistent Registry Network Infrastructure

**Goal**: Create the persistent network and the lifecycle management around it.

**New parameter**: `current-persistent-registry-net-box` — holds a `box` containing the persistent `prop-network` for registry cells. Created once per file/prelude load, survives across commands.

**New function**: `init-persistent-registry-network!`
```racket
(define (init-persistent-registry-network!)
  ;; Create a fresh prop-network for persistent registries
  (define net (make-net))  ;; via current-prop-make-network
  (current-persistent-registry-net-box (box net)))
```

Called once at file start (in `process-file`/`load-module`), not per command. The box is parameterized at file scope — batch-worker's parameterize restores it to the post-prelude snapshot per test file.

**Cell-id stability**: Registry cell-id parameters (`current-schema-registry-cell-id`, etc.) are set once during init, not reset per command. They become file-scoped stable references.

**Integration via bridge propagators**: The elab-network (per-command) and persistent-registry-network (per-file) are separate `prop-network` instances. Rather than routing reads to the correct network via conditionals, we use **bridge propagators** (Galois connections) to project persistent registry values into the elab-network as shadow cells:

```racket
;; Per-command: create shadow cells in elab-network bridged from persistent network
(define (bridge-registries-to-elab!)
  (for ([persistent-cid (in-list persistent-registry-cell-ids)])
    (define shadow-cid (net-add-cell! elab-net (cell-read persistent-cid)))
    (add-bridge-propagator! persistent-cid shadow-cid)))
```

This means:
- **Writes** go to the persistent network (via `macros-cell-write!` pointing to persistent net-box)
- **Reads during elaboration** go through shadow cells in the elab-network (same network as metas — no cross-network routing needed)
- **Bridge propagators** keep shadows in sync (lazy — only fire when persistent cell changes during the command)
- **Shadow cells auto-clean** when the elab-network is cleared per command — no explicit cleanup

This is the same cross-network bridge pattern Track 5 uses for module→file definition shadowing. The existing `macros-cell-read-safe` helpers read from the shadow cell in the elab-network, not from the persistent cell directly.

### Phase 2: Registry Cell Persistence Migration

**Goal**: Migrate 29 registry cells from per-command creation to persistent creation.

**Changes to `register-macros-cells!`**:
- Currently: creates 24 cells in the elab-network per command
- After: creates 24 cells in the persistent network ONCE (at init time)
- `register-macros-cells!` becomes `init-macros-cells!`, called from `init-persistent-registry-network!`
- Per-command `register-macros-cells!` call in `process-command` is removed

**Same treatment for**:
- `register-warning-cells!` → `init-warning-cells!` (3 cells)
- `register-narrow-cells!` → `init-narrow-cells!` (2 cells)

**Cell initialization**: Cells are initialized from current parameter values at init time — same data, different lifecycle. The persistent network's cells hold the accumulated state; subsequent `register-*!` calls write to the persistent cell.

**Belt-and-suspenders**: During Phase 2, keep parameter writes (dual-write). Validate that persistent cell reads match parameter reads after each command.

### Phase 3: Dual-Write Elimination

**Goal**: Remove parameter writes from all `register-*!` functions. Cells are now the sole persistent store.

**Changes to 22 macros register functions**: Remove the parameter write line. Each function now writes ONLY to the persistent cell:

```racket
;; BEFORE:
(define (register-trait! name meta)
  (current-trait-registry (hash-set (current-trait-registry) name meta))
  (macros-cell-write! (current-trait-registry-cell-id) (hasheq name meta)))

;; AFTER:
(define (register-trait! name meta)
  (macros-cell-write! (current-trait-registry-cell-id) (hasheq name meta)))
```

**Read functions**: `read-trait-registry` reads from the persistent cell unconditionally. No parameter fallback needed — the cell IS the persistence.

**Parameter elimination**: The 24 macros registry parameters (`current-schema-registry`, `current-ctor-registry`, ...) become unnecessary for persistence. They may be retained temporarily for batch-worker snapshot/restore compatibility, but their writes are removed.

**batch-worker impact**: The batch-worker currently snapshots 24 macros parameters and restores them per test. With persistent cells, the batch-worker instead snapshots/restores `current-persistent-registry-net-box` — one box instead of 24 parameters. This is simpler AND more correct (captures all registry state in one snapshot).

**Module loading**: Module loading accumulates definitions by calling `register-*!` functions during `process-command`. With persistent cells, these writes go directly to the persistent network. The per-file parameterize initializes a fresh persistent network; module loading fills it naturally.

---

## 5. Design: WS-B — Stratified Retraction + Readiness Propagators

### Phase 4: Assumption-Tagged Scoped Cells

**Goal**: Tag writes to scoped cells (constraints, wakeups, warnings) with the creating assumption ID.

**Which cells are scoped** (14 total):
- 8 constraint cells (constraint store, trait/hasmethod/capability constraints, trait/hasmethod cell-maps, constraint status)
- 3 wakeup cells (wakeup registry, trait wakeup, hasmethod wakeup)
- 3 warning cells (coercion, deprecation, capability)

**Tagging mechanism**: Each entry written to a scoped cell carries an `assumption-id` field. At speculation depth 0 (no speculation), the assumption-id is `#f` (unconditional — always believed). During speculation, the assumption-id is the current speculation hypothesis.

```racket
;; Tagged entry for constraint store:
(struct tagged-constraint (constraint assumption-id) #:transparent)

;; Write: tag with current assumption
(define (add-constraint-tagged! c)
  (define aid (current-speculation-assumption))  ;; #f at depth 0
  (write-constraint-to-store! (tagged-constraint c aid)))
```

**Merge functions**: `merge-hasheq-union` and `merge-list-append` work unchanged — they accumulate tagged entries the same way they accumulate untagged entries. The tagging is transparent to accumulation.

**Read functions**: For now, reads return all entries (tagged + untagged). S(-1) retraction removes non-believed entries. Between S(-1) and S0, reads see only believed entries. At depth 0 (no speculation), all entries have `#f` assumption-id (always believed) — zero overhead.

### Phase 5: S(-1) Retraction Stratum

**Goal**: Implement the retraction stratum that cleans scoped cells before S0 fires.

**New cell**: `current-believed-assumptions-cell-id` — holds the set of currently-believed assumption IDs. Updated by `with-speculative-rollback` when an assumption is retracted.

**S(-1) retraction propagator**: Watches the believed-assumptions cell. When the set shrinks (assumption retracted):

```racket
(define (run-retraction-stratum!)
  (define believed (read-believed-assumptions))
  (define prev-believed (current-prev-believed-assumptions))
  (define retracted (set-subtract prev-believed believed))
  (unless (set-empty? retracted)
    ;; Clean all scoped cells
    (for ([cell-id (in-list scoped-cell-ids)])
      (retract-entries! cell-id retracted))
    (current-prev-believed-assumptions believed)))

(define (retract-entries! cell-id retracted-set)
  ;; Read current cell value, remove entries tagged with retracted assumptions
  (define current-val (cell-read cell-id))
  (define cleaned (remove-retracted current-val retracted-set))
  (when (not (equal? current-val cleaned))
    (cell-write! cell-id cleaned)))
```

For `merge-hasheq-union` cells: filter entries by `(not (set-member? retracted-set (tagged-entry-assumption-id entry)))`.

For `merge-list-append` cells: filter list elements similarly.

**Integration with stratified loop**: S(-1) runs at the START of each `run-stratified-resolution!` iteration, before S0:

```racket
(let loop ([fuel fuel] [meta-id trigger-meta-id])
  (when (> fuel 0)
    ;; S(-1): Retraction — clean scoped cells
    (run-retraction-stratum!)
    ;; S0: Type propagation (existing)
    (run-quiescence!)
    ;; S1: Readiness scan (existing, then replaced by Phase 8)
    (define actions (collect-ready-actions))
    ;; S2: Resolution commitment (existing)
    (execute-resolution-actions! actions)
    (when (unbox progress-box)
      (loop (sub1 fuel) meta-id))))
```

**Depth-0 fast path**: At speculation depth 0, no assumptions are retracted. `run-retraction-stratum!` checks `(set-empty? retracted)` and returns immediately. Zero overhead for the common case.

### Phase 6: Belt-and-Suspenders Retirement (Phase 5b Gate)

**Goal**: Remove the network-box restore from `save-meta-state`/`restore-meta-state!`.

**Precondition**: With S(-1) retraction handling scoped cells and TMS retraction handling value cells, the network-box snapshot is redundant.

**Belt-and-suspenders validation**: Run the full test suite with BOTH mechanisms active, comparing results. Then disable network-box restore and verify identical results.

**Changes to `save-meta-state`**: Remove the network box save. `save-meta-state` becomes a no-op (all state is TMS-managed or retracted by S(-1)).

**Changes to `restore-meta-state!`**: Remove the network box restore. Retraction happens through S(-1) and TMS.

**Result**: `save-meta-state`/`restore-meta-state!` reduce from 1 box to 0 boxes. Speculation is now fully managed by the TMS + S(-1) architecture.

### Phase 7: Callback Inlining

**Goal**: Replace 3 callback parameters with direct function calls.

**Module restructuring**: The callbacks exist to break circular deps:
- `current-retry-unify` (metavar-store ← unify)
- `current-retry-trait-resolve` (metavar-store ← driver)
- `current-retry-hasmethod-resolve` (metavar-store ← driver)

**Approach**: Extract resolution logic from driver.rkt into a new `resolution.rkt` module that both metavar-store and driver can import. The resolution functions (`try-monomorphic-resolve`, `try-parametric-resolve`) move from driver.rkt to resolution.rkt. `execute-resolution-actions!` calls them directly.

**Validation**: Remove callback parameters. Any test that previously required callback injection now works through direct imports.

### Phase 8a: Readiness Propagators (L1)

**Goal**: Replace the 6 O(total) S1 scanning functions with per-constraint fan-in readiness propagators.

**New infrastructure**:

**Ready-queue channel cell**: A channel cell (see §2.6 taxonomy) that accumulates action descriptors for constraints whose dependencies became ready. Entries are assumption-tagged for on-network produce-consume:

```racket
(define current-ready-queue-cell-id (make-parameter #f))
;; Merge: list append (monotonic accumulation of ready actions)
;; Lifecycle: channel cell — L1 writes, L2 reads + retracts, S(-1) cleans
```

**Fan-in readiness propagator with countdown latch**: One propagator per constraint (NOT per dependency). Uses a countdown latch for O(1) readiness detection:

```racket
(define (register-trait-constraint-with-readiness! meta-id info dep-cell-ids)
  ;; ... existing registration ...
  ;; NEW: fan-in readiness propagator watching ALL deps
  (define total-deps (length dep-cell-ids))
  (define ground-count (box 0))  ;; countdown latch

  ;; Termination: Level 1 (Tarski). Each dep transitions at most once
  ;; (⊥ → solved). Fan-in fires at most once per dep per BSP round.
  ;; Countdown latch: O(1) readiness check (compare count == total).
  (net-add-propagator!
    dep-cell-ids  ;; fan-in: ALL deps as inputs
    (lambda dep-vals
      ;; Under BSP: fires once per round with all current dep values
      ;; Count non-bot deps
      (define n-ground (count (lambda (v) (not (prop-type-bot? v))) dep-vals))
      (when (and (= n-ground total-deps)
                 (not (meta-solved? meta-id)))
        ;; All deps ground — write action to ready-queue channel cell
        ;; Tagged with fresh assumption for on-network consume pattern
        (define assumption-id (make-fresh-assumption!))
        (cell-write! (current-ready-queue-cell-id)
                     (list (tagged-action assumption-id
                             (action-resolve-trait meta-id info))))))))
```

**Countdown latch optimization**: In BSP scheduling, the fan-in propagator fires once per round with ALL current dep values. The `count` of non-⊥ values is computed in a single pass. When `count == total-deps`, the constraint is ready. No per-dep tracking needed — the BSP round gives us all inputs simultaneously.

For Gauss-Seidel scheduling (fallback), a stateful countdown latch is more efficient: maintain `ground-count` as a box; each dep transition increments it; readiness fires when `ground-count == total-deps`. Either approach is O(1) for the readiness check itself.

**Propagator count**: 1 fan-in propagator per constraint (not 1 per dependency). For 50 constraints: 50 propagators total, regardless of dependency fan-out. This is the fan-in pattern from §2.6.

**S1 replacement**: Instead of scanning, L1 readiness propagators write to the ready-queue channel cell. S1 disappears as a separate phase — readiness detection is now structural (propagator-driven), not imperative (scan-driven).

**Ordering**: Readiness propagators are tagged as L1 layer. Under the hybrid BSP/Gauss-Seidel scheduler, they fire after S0 reaches quiescence. The ready-queue accumulates during L1's BSP rounds. L2 reads the queue after L1 quiesces. This preserves stratum ordering.

**Belt-and-suspenders**: During Phase 8a, run BOTH the old scanning functions and the ready-queue, assert identical action descriptor sets. Remove scanning functions after validation.

### Phase 8b: Resolution Propagators (L2)

**Goal**: Replace the imperative `execute-resolution-actions!` loop with resolution propagators that fire when the ready-queue has entries.

**Current architecture** (post-Phase 8a):
```
S0: run-to-quiescence (propagators fire, readiness propagators populate ready-queue)
S1: read ready-queue (cell read — O(1))
S2: execute-resolution-actions! (imperative loop over action descriptors, calls resolution functions)
    → may call solve-meta! → sets progress-box → outer loop iterates
```

**Target architecture**:
```
Layered network quiescence:
  S(-1): retraction propagators fire (clean scoped cells)
  S0:    type propagators fire (solve metas)
  L1:    readiness propagators fire (populate ready-queue)
  L2:    resolution propagators fire (consume ready-queue, call resolution logic)
         → resolution writes to meta cells → perturbs S0 → cascade continues
```

**Resolution propagator**: A single propagator that watches the ready-queue channel cell. Its fire function IS the resolution logic. Consumption uses the on-network channel cell pattern (§2.6): after processing each entry, retract its assumption so S(-1) cleans it on the next cycle.

```racket
(define (install-resolution-propagator! ready-queue-cell-id)
  ;; Termination: Level 2 (well-founded). Each resolution either produces a
  ;; concrete dictionary (terminal) or creates metas at strictly smaller type
  ;; depth. Type depth is well-founded → finite resolution chains.
  (net-add-propagator!
    (list ready-queue-cell-id)
    (lambda (queue-val)
      (for ([tagged-entry (in-list queue-val)])
        (define action (tagged-action-value tagged-entry))
        (define assumption-id (tagged-action-assumption-id tagged-entry))
        ;; Execute resolution
        (match action
          [(action-retry-constraint c)
           (retry-unify-constraint! c)]
          [(action-resolve-trait dict-meta-id tc-info)
           (resolve-trait-constraint! dict-meta-id tc-info)]
          [(action-resolve-hasmethod hm-meta-id hm-info)
           (resolve-hasmethod-constraint! hm-meta-id hm-info)])
        ;; Consume: retract the entry's assumption → S(-1) will clean it
        (retract-assumption! assumption-id)))))
```

**On-network queueing lifecycle**: The ready-queue is a channel cell (§2.6 taxonomy). The full lifecycle:
1. **L1 (produce)**: Readiness propagator writes a tagged action to the channel cell
2. **L2 (consume)**: Resolution propagator reads the action, executes resolution, retracts the entry's assumption
3. **S(-1) (clean)**: On the next cycle, the retraction stratum removes retracted entries from the channel cell

All queueing state lives on the network. No off-network clearing. The channel cell pattern composes naturally with the layered scheduler — production (L1) and consumption (L2) happen in different strata, with S(-1) garbage collection.

**Feedback mechanism**: Resolution may call `solve-meta!`, which writes to a meta cell. This cell write is detected by the network's dirty-flag mechanism — the network is NOT quiescent, so propagation continues. The readiness propagators may fire again (new metas solved → new constraints ready). The cycle continues until the network reaches true quiescence across all layers.

**The progress-box becomes unnecessary**: Currently, `execute-resolution-actions!` sets `progress-box` when `solve-meta!` is called, and the outer loop checks it. With L2 as a propagator, progress is detected structurally — a cell write during L2 means the network isn't quiescent, so `run-to-quiescence` continues. No box, no loop variable.

**Re-entrancy safety**: Currently `current-in-stratified-resolution?` prevents recursive `run-stratified-resolution!` calls when L2 callbacks call `solve-meta!`. With the propagator architecture, this is structural — `solve-meta!` writes to a cell, which triggers S0 propagators within the SAME quiescence run. No re-entrancy because there's no recursive function call; it's all within the network scheduler.

**Stratum ordering**: The hybrid BSP/Gauss-Seidel scheduler (§2.5) processes layers in order:
1. Fire all S(-1) retraction propagators to BSP fixpoint
2. Fire all S0 type propagators to BSP fixpoint
3. Fire all L1 readiness propagators to BSP fixpoint
4. Fire all L2 resolution propagators to BSP fixpoint
5. If any L2 propagator wrote to an S0 cell (meta solution), go back to step 1

Intra-stratum: BSP (all dirty propagators in the layer fire per round — safe by CALM, as intra-stratum propagation is monotone). Inter-stratum: Gauss-Seidel (each layer reaches fixpoint before the next activates — required because higher strata need lower strata's complete fixpoint).

**Implementation approach**: Tag propagators with a layer identifier when created:
- S(-1) propagators: layer = -1 (retraction)
- S0 propagators: layer = 0 (type propagation, unification)
- L1 propagators: layer = 1 (readiness detection)
- L2 propagators: layer = 2 (resolution commitment)

The scheduler processes layers in order, re-entering from the lowest layer when a higher layer writes to a lower layer's cells.

### Phase 8c: Stratified Loop Elimination

**Goal**: Remove `run-stratified-resolution!` entirely. The hand-written loop becomes layered network quiescence.

**What disappears**:
- `run-stratified-resolution!` function (the hand-written S0→S1→S2 loop)
- `current-in-stratified-resolution?` parameter (re-entrancy guard)
- `current-stratified-progress-box` parameter (progress detection)
- `stratified-resolution-fuel` constant (loop fuel)
- 6 `collect-ready-*` scanning functions (replaced by L1)
- `execute-resolution-actions!` function (replaced by L2)

**What `solve-meta!` becomes**:

```racket
;; BEFORE:
(define (solve-meta! id solution)
  (solve-meta-core! id solution)
  (unless (current-in-stratified-resolution?)
    (run-stratified-resolution! id)))

;; AFTER:
(define (solve-meta! id solution)
  (solve-meta-core! id solution)
  ;; Cell write triggers network propagation automatically.
  ;; No explicit loop call needed — the network scheduler handles it.
  (run-layered-quiescence!))
```

**`run-layered-quiescence!`**: The new entry point that replaces both `run-to-quiescence` (S0 only) and `run-stratified-resolution!` (S0+S1+S2). It runs the full layered scheduler:

```racket
(define (run-layered-quiescence!)
  ;; Run the network scheduler with layer priorities:
  ;; S(-1) → S0 → L1 → L2, re-entering from S(-1) on feedback
  (define net (unbox (current-prop-net-box)))
  (define net* (run-to-layered-quiescence net))
  (set-box! (current-prop-net-box) net*))
```

**Fuel / termination**: The hand-written loop had explicit fuel (100 iterations). The layered scheduler has the network's native termination: quiescence = no dirty cells across any layer. For pathological cases (infinite solving cycles), the scheduler can track iteration count and bail at a configurable threshold — same semantics, but structural rather than a loop counter.

**The architectural payoff**: After Phase 8c, constraint resolution is a structural property of the propagator network. Adding a new constraint type (e.g., a new kind of trait constraint, or a narrowing constraint) means adding a readiness propagator (L1) and a resolution propagator (L2). No changes to a hand-written loop. No new scanning function. No new callback. The network handles scheduling, ordering, and termination.

**Belt-and-suspenders**: During Phase 8b, keep `run-stratified-resolution!` as a fallback. Compare its results against layered quiescence for every `solve-meta!` call. Phase 8c removes the fallback after validation.

---

## 6. Design: WS-A — QTT Multiplicity Cells

### Phase 9: Mult Lattice + Cross-Domain Bridges

**Goal**: Bring QTT multiplicity operations into the elaboration network.

**Mult lattice**: `m0 < m1 < mw` (erased < linear < unrestricted). Already implemented as a comparison function in `qtt.rkt`. Track 7 adds a merge function and cell infrastructure.

```racket
(define (mult-lattice-merge old new)
  (cond
    [(eq? old 'mw) 'mw]
    [(eq? new 'mw) 'mw]
    [(eq? old 'm1) (if (eq? new 'm0) 'm1 new)]
    [(eq? new 'm1) 'm1]
    [else old]))  ;; both m0
```

**Cross-domain bridge propagators**: When a type metavariable is solved, its QTT usage annotations may constrain multiplicity metavariables. The bridge propagator connects type cells to mult cells:

```racket
;; Type cell solution triggers mult constraint checking
(net-add-cross-domain-propagator!
  type-cell-id
  mult-cell-id
  (lambda (type-val) (extract-mult-constraint type-val))  ;; α: type → mult
  (lambda (mult-val) mult-val))                           ;; γ: identity
```

**Scope**: Multiplicity cells already exist (Track 4 — `elab-fresh-mult-cell`). Track 7 adds the lattice merge function and bridge propagators so that type-level reasoning can inform multiplicity inference.

---

## 7. Risk Analysis

### High risk: Persistent network lifecycle (WS-C Phase 1-2)

The persistent network must survive across commands but be correctly scoped to files. batch-worker must snapshot/restore it. Module loading must initialize it.

**Mitigation**: Follow the Track 5 pattern for `current-definition-cells-content` — proven lifecycle management. Belt-and-suspenders validation during Phase 2.

### Medium risk: S(-1) retraction correctness (WS-B Phase 5)

S(-1) must remove exactly the entries tagged with retracted assumptions, no more, no less. Over-retraction loses valid constraints; under-retraction leaves orphaned entries.

**Mitigation**: Belt-and-suspenders comparison against current network-box restore (Phase 6). Existing speculation test suite (Track 4/6) exercises the exact scenarios. Depth-0 fast path ensures zero overhead for the common case.

### Medium risk: Readiness propagator ordering (WS-B Phase 8)

Readiness propagators fire during S0 quiescence. If a readiness propagator writes to the ready-queue before a dependency meta is fully propagated, it may produce a stale action descriptor.

**Mitigation**: Readiness propagators fire AFTER the network reaches quiescence for the triggering write. The ready-queue is read by S1, which runs after S0 quiesces. The stratum ordering guarantees consistency.

### Medium risk: Resolution propagators + loop elimination (WS-B Phase 8b-8c)

Converting `execute-resolution-actions!` from an imperative loop to a propagator changes the control flow of constraint resolution. The re-entrancy semantics change from explicit guards (`current-in-stratified-resolution?`) to structural cell-write detection.

**Mitigation**: Belt-and-suspenders during Phase 8b — run BOTH the hand-written loop and the layered scheduler, compare results. Phase 8c removes the loop only after validation. The existing Track 4/6 speculation test suite exercises the exact re-entrancy scenarios.

### Medium risk: Layered scheduler implementation (WS-B Phase 8b)

The Gauss-Seidel scheduler across 4 layers (S(-1), S0, L1, L2) with feedback from L2→S(-1) is new infrastructure. The scheduler must respect layer ordering and correctly detect when a higher layer's write perturbs a lower layer.

**Mitigation**: The pattern is proven — effect-bridge propagators (Architecture A+D) already use priority-based scheduling within `run-to-quiescence`. Track 7 extends this to 4 explicit layers. The scheduler extension can be validated independently with unit tests before wiring into constraint resolution.

### Low risk: Callback inlining (WS-B Phase 7)

Mechanical module restructuring. The resolution functions already exist; they just move to a new module.

**Mitigation**: 3 callback parameters, well-understood call sites. Track 6 Phase 8d deep audit confirmed all are vestigial indirection.

### Low risk: QTT multiplicity cells (WS-A Phase 9)

Tiny lattice (3 elements). Cross-domain bridges follow the proven session↔effect bridge pattern.

**Mitigation**: Track 4 already created mult cells. Track 7 adds merge function and bridges — incremental.

---

## 7b. Expected Performance Characteristics

### Current baseline (post-Track 6)

| Metric | Value | Source |
|--------|-------|--------|
| Total suite time | 235.2s | Track 6 Phase 11 |
| Test count | 7154 | Track 6 Phase 11 |
| Per-command cell creations | ~29 registry + ~12 infra = ~41 | `register-macros-cells!` + `register-warning-cells!` + `register-narrow-cells!` |
| Cell creations per suite | ~7154 × 41 ≈ 293K | Estimated from test count × per-command |
| S1 scanning per `solve-meta!` | O(total constraints) × 6 functions | `collect-ready-*` in metavar-store.rkt |
| Speculation save/restore | 1 network box + TMS retraction | Track 6 Phases 2+3, 4 |

### Per-phase expected impact

**WS-C: Persistent Registry Cells (Phases 1-3)**

| Operation | Before | After | Change |
|-----------|--------|-------|--------|
| Registry cell creation | 29 cells × ~7154 commands ≈ 208K/suite | 29 cells × 1 (per file) ≈ 29/file | ~7000× fewer allocations |
| Registry cell-id lookup | Parameter read per command | Stable reference (no lookup) | Eliminates parameter overhead |
| Register write path | Param write + cell write (dual) | Cell write only | 1 write instead of 2 |
| Parameter write overhead | 24 `hash-set` per registration | 0 | Eliminated |
| Bridge propagator cost | N/A | 29 bridge propagators per command (fire once) | New cost, but cheaper than 29 cell recreations |
| batch-worker snapshot | Save/restore 24+ parameters | Save/restore 1 box pointer | Simpler, atomic |

**Net effect**: Significant reduction in per-command overhead. The ~293K cell creations per suite drop to ~29 per file plus bridge propagator wiring. The dual-write elimination removes ~50% of registration write cost. Bridge propagators are lazy (fire once on initial sync) — cheaper than eager cell recreation + parameter seeding.

**WS-B: Stratified Retraction + Stratified Prop-Net (Phases 4-8c)**

| Operation | Before | After | Change |
|-----------|--------|-------|--------|
| S1 readiness scan | O(total constraints) × 6 functions per cycle | O(1) ready-queue read | Orders of magnitude for constraint-heavy commands |
| Readiness detection | Scan all, filter ready | Fan-in propagator fires on dep change | O(changed) not O(total) |
| Readiness check per constraint | Iterate dep list, check each | Countdown latch: compare `count == N` | O(1) vs O(deps) |
| Resolution dispatch | Callback indirection (3 parameter reads + guard checks) | Direct function call (Phase 7) → propagator fire (Phase 8b) | Eliminates indirection |
| Speculation rollback (scoped cells) | Network box restore (copy entire network snapshot) | S(-1) retraction (remove tagged entries from affected cells) | Proportional to speculated entries, not total network size |
| Speculation depth-0 overhead | Network box save (snapshot entire network) | No-op (no assumptions to track) | Eliminated for common case |
| Stratified loop fuel | Fixed 100 iterations, checked per cycle | Layered quiescence (structural termination) | Correct by construction |
| Progress detection | Box read + set per cycle | Dirty-flag on network (structural) | Eliminates box |

**Net effect**: The readiness scan elimination is the biggest win — currently O(total constraints) per `solve-meta!` cycle, which compounds for commands with many constraints. For a command with 50 constraints and 10 resolution cycles, that's 50 × 6 × 10 = 3000 scans. With L1 readiness propagators, it's 50 fan-in propagators that fire O(1) when deps change. The scanning functions become dead code.

S(-1) retraction for speculation is proportional to entries created under the retracted assumption, not to total network size. For a typical speculative branch creating 3-5 constraints, retraction touches 3-5 entries. The current network-box restore copies the entire network snapshot regardless of speculation size.

**WS-A: QTT Multiplicity Cells (Phase 9)**

Minimal performance impact. 3-element lattice, bridge propagators fire at most once per meta solve. The mult cell infrastructure already exists (Track 4); Track 7 adds merge + bridges.

### Performance risk factors

1. **Bridge propagator wiring per command**: 29 bridge propagators created per command. Each is a simple one-input propagator that fires once (initial sync from persistent cell). The cost is ~29 `net-add-propagator!` calls — comparable to the current ~29 `register-macros-cells!` cell creations, but the propagators are simpler (no parameter seeding, no cell-id parameter writes).

2. **Fan-in propagator memory**: One propagator object per constraint. For commands with hundreds of constraints (e.g., complex trait resolution), this is hundreds of propagator objects in the network. The CHAMP-based network handles this efficiently, but measure in Phase 0.

3. **Assumption tagging overhead**: Every scoped cell write gets an assumption-id field. At depth 0 (common case), this is `#f` — a single cons cell added per entry. Track 4's depth-0 fast path precedent suggests negligible overhead.

4. **Layered scheduler overhead**: The 4-layer Gauss-Seidel scheduler iterates layers in order, checking for dirty propagators in each. For layers with no dirty propagators (common for S(-1) at depth 0), the check is O(1). The BSP within each layer is the existing `run-to-quiescence` mechanism — no new overhead within a layer.

5. **Channel cell retraction overhead**: Each consumed ready-queue entry requires an assumption retraction + S(-1) cleanup. For typical commands with 5-20 resolved constraints per solve cycle, this is 5-20 retraction operations. The retraction itself is a set-subtract on the assumption set (O(log n) in CHAMP).

### Performance targets

| Metric | Target | Rationale |
|--------|--------|-----------|
| Suite wall time | ≤ 250s (≤ 6% regression from 235.2s) | Track 5's +14% was acceptable; Track 7 adds infrastructure but removes scanning overhead |
| Per-command overhead | ≤ current (no regression) | Bridge propagators ≤ cell recreation cost |
| S1 scan elimination | Measurable improvement for constraint-heavy tests | Directly proportional to constraint count |
| Speculation depth-0 | Zero new overhead | Fast path: no assumptions, S(-1) is no-op |
| Adversarial benchmark | Layered scheduler ≤ 1.5× hand-written loop | Conservative target; structural advantages may yield improvement |

### Measurement approach

Phase 0 captures the baseline. Each subsequent phase runs the full suite with timing recorded to `timings.jsonl`. Per-file regressions trigger investigation (>2× rolling median AND median >3s). Suite-level regression >15% triggers investigation before proceeding.

The adversarial benchmark (§13 Q5) provides a focused measurement of the scheduler and readiness propagator performance independent of the broader suite.

---

## 8. Learnings from Prior Tracks Applied Here

### From Track 6 PIR: Context loss causes architectural divergence

Track 6's 7b-c sync-back pattern was implemented without the context of Track 5's persistence model. **Before each phase, re-read this design doc and the audit.** Plan files capture WHAT, not WHY.

### From Track 6 PIR: "Dual-write elimination" was the wrong framing

The parameter + cell writes serve different purposes (persistence + propagation). Track 7 WS-C eliminates the parameter by making cells persistent — this is the correct framing. We're not "eliminating writes"; we're "unifying persistence into the cell layer."

### From Track 5 PIR: Belt-and-suspenders is standard practice

Every migration phase keeps both old and new paths active. Phase 6 (retirement) is the explicit gate where the old path is removed after validation.

### From Track 4 PIR: Depth-0 fast path is essential

TMS cells add zero overhead at speculation depth 0 thanks to the fast path. S(-1) retraction must have the same property: at depth 0, no assumptions are retracted, so the stratum is a no-op.

### From Track 6 PIR: Lazy initialization > mandatory initialization

The ATMS lazy-init fix taught us that infrastructure should work regardless of entry path. The persistent network should be lazily initialized if `process-command` is called without prior `init-persistent-registry-network!`.

### From Stratified Architecture Audit: Retraction is aggregation's dual

The same mathematical structure (stratified fixpoint semantics) underlies both NAF-LE aggregation and TMS retraction. S(-1) is not a new theory — it's a known structure applied to the dual problem.

---

## 9. Principle Alignment (D.3 Preview)

| Principle | Alignment | Notes |
|-----------|-----------|-------|
| Propagator-First Infrastructure | ✅ Strong | Core purpose: cells become the persistent store |
| Correct by Construction | ✅ Strong | S(-1) stratification, structural scoping, depth-0 fast path |
| Data Orientation | ✅ Strong | Retraction is data (assumption sets), not imperative cleanup |
| Decomplection | ✅ Strong | Clean separation: persistent registries vs ephemeral inference state |
| Simplicity of Foundation | ⚠️ Moderate | Two networks adds complexity; justified by lifecycle separation |
| First-Class by Default | ✅ Aligned | Ready-queue, assumption sets, retraction descriptors are all first-class |

### Key tensions to address in D.3

1. **Two-network complexity** — **RESOLVED in D.2 discussion**: Two networks is the right design. Better correctness reasoning, propagator-first, data-oriented, decomplected. Bridge propagators (Galois connections) provide clean cross-network integration. The alternative (one network with selective reset) is harder to reason about and mixes lifecycle concerns.

2. **Scoped cell tagging overhead**: Every constraint/wakeup/warning write gets an assumption-id field. At depth 0 (no speculation), this is always `#f`. Is the per-write cost measurable? Track 4's depth-0 fast path suggests it's negligible.

3. **Readiness propagator count** — **RESOLVED in D.2 discussion**: Fan-in propagators (1 per constraint, not 1 per dependency) reduce count from N×D to N. For 50 constraints: 50 propagators total. Countdown latch optimization: O(1) readiness check. Under BSP scheduling, fires once per round with all current dep values — even more advantageous than Gauss-Seidel.

4. **Layered scheduler complexity** — **PARTIALLY RESOLVED in D.2 discussion**: Hybrid BSP/Gauss-Seidel is justified by CALM (monotone intra-stratum = safe for BSP; non-monotone inter-stratum = needs Gauss-Seidel barrier). Correctness follows from stratified fixpoint semantics. Phase 0 adversarial benchmark (Q5) will validate empirically. The scheduler extension can be unit-tested independently before wiring into constraint resolution.

5. **Loop elimination completeness**: After Phase 8c, `run-stratified-resolution!` is gone. Every scenario currently handled by the hand-written loop must be handled by layered quiescence. The risk is edge cases in the loop that aren't exercised by the test suite — need to audit the loop's special-case handling before removal.

6. **Gödel Completeness per layer**: Each phase in the progress tracker now has a termination guarantee level. Cross-layer feedback (L2→S0) terminates via well-founded measure (type depth × unsolved meta count). See `GÖDEL_COMPLETENESS.org` for the full hierarchy. Fuel retained as defense-in-depth behind the structural argument.

---

## 10. Files Modified

| File | Phase | Changes |
|------|-------|---------|
| `metavar-store.rkt` | 1, 4, 5, 8a-c | Persistent network init, assumption tagging, S(-1) stratum, ready-queue, resolution propagator, loop elimination |
| `macros.rkt` | 2, 3 | Cell persistence migration, dual-write elimination |
| `warnings.rkt` | 2, 3, 4 | Cell persistence migration, assumption tagging |
| `global-constraints.rkt` | 2, 4 | Cell persistence migration, assumption tagging |
| `driver.rkt` | 1, 3, 7, 8c | Persistent network lifecycle, dual-write removal, callback elimination, solve-meta! simplification |
| `infra-cell.rkt` | 4, 9 | Assumption-tagged entries, mult lattice merge |
| `propagator.rkt` | 8b, 8c | Layer-aware propagator tagging, `run-to-layered-quiescence` scheduler |
| `elaborator-network.rkt` | 5, 8a, 8b, 9 | S(-1) integration, readiness propagators, resolution propagator, mult bridge propagators |
| `elab-speculation-bridge.rkt` | 4, 5, 6 | Assumption tracking, S(-1) trigger, retire network-box restore |
| `resolution.rkt` (NEW) | 7 | Extracted resolution logic from driver.rkt |
| `qtt.rkt` | 9 | Mult lattice merge function |
| `batch-worker.rkt` | 1, 3 | Persistent network snapshot/restore |
| `test-support.rkt` | 1, 3 | Persistent network isolation |

---

## 11. Verification Strategy

1. **Per-phase**: `racket tools/run-affected-tests.rkt --all` — 0 new failures after each phase
2. **Acceptance file**: `examples/2026-03-18-track7-acceptance.prologos` — run via `process-file` after each phase
3. **Adversarial benchmark** (Phase 0): Synthetic constraint graph with deep resolution chains (depth 5+), wide fan-out (20+ constraints per meta), nested speculation (3+ levels), cyclic feedback. Compare hand-written loop vs layered scheduler on iteration count, wall time, correctness.
4. **Belt-and-suspenders**:
   - Phase 2: persistent cell reads vs parameter reads (0 divergences)
   - Phase 5: S(-1) retraction vs network-box restore (identical results)
   - Phase 6: retire network-box restore, verify suite still passes
4. **Performance**:
   - Phase 0 baseline: total suite time, per-command cell allocation count
   - Phase 3: measure dual-write elimination impact (fewer parameter writes)
   - Phase 8: measure S1 scanning time before vs. after readiness propagators
   - Phase 10: compare against Phase 0 baseline; investigate if >15% regression
5. **Speculation coverage**: Track 4/6 speculation tests exercise the exact rollback scenarios. Phase 5 must pass all existing speculation tests with S(-1) as the sole retraction mechanism for scoped cells.

---

## 12. Absorbed Deferrals

| Source | Item | Track 7 Phase |
|--------|------|---------------|
| Track 6 Phase 5b | Belt-and-suspenders retirement gate (TMS-aware infra cells) | WS-B Phase 6 |
| Track 6 Phase 8d | Callback inlining (module restructuring) | WS-B Phase 7 |
| Track 6 PIR §14 | `current-prelude-env-prop-net-box` rename | Deferred (low priority) |
| Track 3 Phase 6 | Dual-write parameter elimination for registries | WS-C Phase 3 |
| Master roadmap | QTT multiplicity cells (P5) | WS-A Phase 9 |

---

## 13. Open Questions

### Q1: One persistent network or per-subsystem persistent networks? — **RESOLVED: Option A**

Option A: One persistent registry network holding all 29 cells.
Option B: Separate networks per subsystem (macros, warnings, narrowing).

**Resolution**: Option A. All share similar lifecycle concerns. One network, better correctness reasoning, propagator-first, data-oriented, decomplected. 29 cells is small; subsystem separation adds management overhead without clear benefit.

### Q2: Warning cells — scoped with full observability — **RESOLVED**

Warnings are accumulated per-command and reported at command end. They don't persist across commands.

**Resolution**: Scoped (in elab-network) with full assumption-tagged cell treatment. This gives maximum observability: warnings as cell values with assumption tags, provenance (source location, triggering constraint, elaboration phase), and source annotations. The LSP watches warning cells; when entries are added/retracted, it updates diagnostics in real time. This is the same observability architecture as definition cells — the network IS the observable state. The principles check (observability + expressiveness through to end tooling) guided this resolution.

### Q3: Ready-queue consumption semantics — **RESOLVED: On-network channel cell**

**Resolution**: The ready-queue is a **channel cell** (§2.6 taxonomy). The consumption pattern is entirely on-network using assumption-tagged produce-consume:

1. **L1 (produce)**: Readiness propagator writes a tagged action descriptor to the channel cell
2. **L2 (consume)**: Resolution propagator reads the action, executes resolution, retracts the entry's assumption
3. **S(-1) (clean)**: On the next cycle, retraction stratum removes retracted entries

No off-network clearing. No imperative queue manipulation. The queueing lifecycle is structural — write, read, retract, clean — all through existing cell + assumption infrastructure. This pattern will be useful in distributed/concurrent runtime designs (same produce-consume semantics across processes/nodes).

### Q4: Batch-worker persistent network snapshot — **RESOLVED: 1 box**

**Resolution**: Yes, 1 box is sufficient. If the same snapshot serves all consumers, 1 box. If different modules need different views in the future, each gets its own box pointing to a different CHAMP subtree — structural sharing makes this cheap. For now, 1 box covers all 29 registry cells atomically.

### Q5: Adversarial benchmark for Phase 0 — **NEW**

Phase 0 should include a synthetic adversarial constraint graph alongside the standard suite baseline:
- Deep resolution chains (depth 5+, trait→trait→trait)
- Wide fan-out (one meta used by 20+ constraints)
- Nested speculation (3+ levels deep)
- Cyclic feedback (L2 solving metas that enable other L2 constraints)

Run both the current hand-written loop and the layered scheduler against this graph. Compare iteration counts, wall time, and correctness. This validates the hybrid BSP/Gauss-Seidel scheduler under adversarial conditions.

### Q6: Propagator taxonomy as a design artifact — **NEW**

The granular taxonomy in §2.6 (transform, fan-in, fan-out, bridge; value, accumulator, channel, shadow; stratum, threshold) is a starting point. A richer taxonomy should include:
- **Temporal propagators**: fire after a delay or on a schedule (for reactive/streaming)
- **Higher-order propagators**: propagators that create/remove other propagators
- **Distributed propagators**: cross-process/cross-node with eventual consistency semantics

This research is deferred (see DEFERRED.md) but the Track 7 taxonomy provides the foundation.
