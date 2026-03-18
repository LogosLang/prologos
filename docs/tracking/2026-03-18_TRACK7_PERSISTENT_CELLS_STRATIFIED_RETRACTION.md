# Track 7: Persistent Registry Cells + Stratified Retraction + QTT Multiplicity Cells — Stage 2/3 Design

**Created**: 2026-03-18
**Status**: DESIGN (Stage 2/3 — awaiting critique)
**Depends on**: Track 3 ✅, Track 4 ✅, Track 5 ✅, Track 6 ✅
**Enables**: Track 8 (Unification as Propagators), Track 9 (GDE), Track 10 (LSP)
**Master roadmap**: `2026-03-13_PROPAGATOR_MIGRATION_MASTER.md` Track 7
**Audit**: `2026-03-18_STRATIFIED_ARCHITECTURE_AUDIT.md`
**Prior PIRs**: Track 4 (TMS cell architecture), Track 5 (persistent module networks), Track 6 (stratified prop-net insight, dual-write reframing, context-loss risk)
**Principle references**: DESIGN_PRINCIPLES.org § "Stratified Propagator Networks", DEVELOPMENT_LESSONS.org § "Callbacks Are a Propagator-First Anti-Pattern"

---

## Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| D.1 | Initial design document | 🔄 | This document |
| D.2 | External critique | ⬜ | |
| D.3 | Self-critique (principle alignment) | ⬜ | |
| 0 | Performance baseline + acceptance file | ⬜ | |
| 1 | Persistent registry network infrastructure | ⬜ | WS-C: separate persistent network for registries |
| 2 | Registry cell persistence migration | ⬜ | WS-C: migrate 24 macros + 3 warning + 2 narrowing cells |
| 3 | Dual-write elimination | ⬜ | WS-C: remove parameter writes from register functions |
| 4 | Assumption-tagged scoped cells | ⬜ | WS-B: tag constraint/wakeup/warning writes with assumption IDs |
| 5 | S(-1) retraction stratum | ⬜ | WS-B: retraction propagator, cleanup to fixpoint |
| 6 | Belt-and-suspenders retirement | ⬜ | WS-B: remove network-box restore (Phase 5b gate) |
| 7 | Callback inlining | ⬜ | WS-B: module restructuring, direct calls |
| 8 | Readiness propagators | ⬜ | WS-B: replace O(total) S1 scanning with per-constraint readiness cells |
| 9 | QTT multiplicity cells + cross-domain bridges | ⬜ | WS-A: mult lattice in network |
| 10 | Performance validation + PIR | ⬜ | |

---

## Non-Goals

Track 7 does NOT deliver:

- **Full stratified propagator network** — Track 7 implements readiness propagators (L1) and retraction stratum (S(-1)), but does NOT convert S2 resolution into propagators. S2 remains imperative (with callbacks inlined to direct calls). Full L2 resolution propagators are Track 8+ scope.
- **LSP integration** — persistent cells and retraction benefit the LSP, but LSP-specific concerns (file watching, incremental re-elaboration triggers) are Track 10.
- **Cross-module shadow-cell consistency** — Track 5's shadow-cell pattern is batch-correct. Multi-invocation consistency is Track 10 (LSP).
- **Persistent definition cells** — definition cells already persist via `current-definition-cells-content` (Track 5 pattern). Track 7 extends this pattern to registries only.

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

### 2.5 Readiness propagators: O(changed) replaces O(total)

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

**Integration with existing infrastructure**: The elab-network (per-command) and persistent-registry-network (per-file) are separate `prop-network` instances. Cell reads need to know which network to consult:
- Registry reads → persistent network
- Meta/constraint reads → elab-network

The existing `macros-cell-read-safe` and `macros-cell-write!` helpers already reference `current-macros-prop-net-box`. We change this to point to the persistent network box instead of the per-command elab-network box.

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

### Phase 8: Readiness Propagators

**Goal**: Replace the 6 O(total) S1 scanning functions with per-constraint readiness propagators.

**New infrastructure**:

**Ready-queue cell**: Accumulates action descriptors for constraints whose dependencies became ready.

```racket
(define current-ready-queue-cell-id (make-parameter #f))
;; Merge: list append (monotonic accumulation of ready actions)
```

**Per-constraint readiness propagator**: Created at constraint registration time:

```racket
(define (register-trait-constraint-with-readiness! meta-id info dep-cell-ids)
  ;; ... existing registration ...
  ;; NEW: create readiness propagator
  (for ([dep-cid (in-list dep-cell-ids)])
    (add-readiness-propagator! dep-cid meta-id info)))

(define (add-readiness-propagator! dep-cell-id dict-meta-id tc-info)
  ;; Propagator: when dep-cell becomes non-bot, check if all deps ready
  ;; If ready, write action descriptor to ready-queue cell
  (net-add-propagator!
    (list dep-cell-id)
    (lambda (dep-val)
      (when (and (not (prop-type-bot? dep-val))
                 (not (meta-solved? dict-meta-id))
                 (all-deps-non-bot? dict-meta-id))
        (cell-write! (current-ready-queue-cell-id)
                     (list (action-resolve-trait dict-meta-id tc-info)))))))
```

**S1 replacement**: Instead of scanning, S1 reads from the ready-queue cell:

```racket
;; BEFORE (O(total)):
(define actions (append (collect-ready-constraints-via-cells) ...))

;; AFTER (O(ready)):
(define actions (read-ready-queue))
(clear-ready-queue!)
```

**Ordering concern**: Readiness propagators fire during S0 quiescence (they're normal propagators). The ready-queue accumulates during S0. S1 reads the queue. This preserves the stratum ordering — readiness detection (S1) only observes what S0 produced.

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

### Low risk: Callback inlining (WS-B Phase 7)

Mechanical module restructuring. The resolution functions already exist; they just move to a new module.

**Mitigation**: 3 callback parameters, well-understood call sites. Track 6 Phase 8d deep audit confirmed all are vestigial indirection.

### Low risk: QTT multiplicity cells (WS-A Phase 9)

Tiny lattice (3 elements). Cross-domain bridges follow the proven session↔effect bridge pattern.

**Mitigation**: Track 4 already created mult cells. Track 7 adds merge function and bridges — incremental.

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

1. **Two-network complexity**: Is the lifecycle separation worth the added network management? Alternative: one network with selective reset (clear metas/constraints, preserve registries). Trade-off: simpler management vs. harder to reason about partial reset correctness.

2. **Scoped cell tagging overhead**: Every constraint/wakeup/warning write gets an assumption-id field. At depth 0 (no speculation), this is always `#f`. Is the per-write cost measurable? Track 4's depth-0 fast path suggests it's negligible.

3. **Readiness propagator count**: One propagator per constraint × dependency. For a command with 50 constraints averaging 2 dependencies each, that's 100 readiness propagators. Is this within the network's performance envelope? Measure in Phase 0.

---

## 10. Files Modified

| File | Phase | Changes |
|------|-------|---------|
| `metavar-store.rkt` | 1, 4, 5, 8 | Persistent network init, assumption tagging, S(-1) stratum, ready-queue |
| `macros.rkt` | 2, 3 | Cell persistence migration, dual-write elimination |
| `warnings.rkt` | 2, 3, 4 | Cell persistence migration, assumption tagging |
| `global-constraints.rkt` | 2, 4 | Cell persistence migration, assumption tagging |
| `driver.rkt` | 1, 3, 7 | Persistent network lifecycle, dual-write removal, callback elimination |
| `infra-cell.rkt` | 4, 9 | Assumption-tagged entries, mult lattice merge |
| `elaborator-network.rkt` | 5, 8, 9 | S(-1) integration, readiness propagators, mult bridge propagators |
| `elab-speculation-bridge.rkt` | 4, 5, 6 | Assumption tracking, S(-1) trigger, retire network-box restore |
| `resolution.rkt` (NEW) | 7 | Extracted resolution logic from driver.rkt |
| `qtt.rkt` | 9 | Mult lattice merge function |
| `batch-worker.rkt` | 1, 3 | Persistent network snapshot/restore |
| `test-support.rkt` | 1, 3 | Persistent network isolation |

---

## 11. Verification Strategy

1. **Per-phase**: `racket tools/run-affected-tests.rkt --all` — 0 new failures after each phase
2. **Acceptance file**: `examples/2026-03-18-track7-acceptance.prologos` — run via `process-file` after each phase
3. **Belt-and-suspenders**:
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

### Q1: One persistent network or per-subsystem persistent networks?

Option A: One persistent registry network holding all 29 cells.
Option B: Separate networks per subsystem (macros, warnings, narrowing).

**Tentative**: Option A. 29 cells is small. Subsystem separation adds management overhead without clear benefit. If a subsystem needs different lifecycle semantics, we can split later.

### Q2: Warning cells — persistent or scoped?

Warnings are accumulated per-command and reported at command end. They don't persist across commands. Should they be in the persistent network (accumulated, then read/cleared per command) or the elab-network (current behavior)?

**Tentative**: Scoped (in elab-network) with assumption tagging. Warnings are per-command, not per-file. S(-1) retraction applies to speculative warnings.

### Q3: Ready-queue consumption semantics

Should the ready-queue cell be consumed (cleared after S1 reads it) or accumulated (S1 reads new entries since last read)?

**Tentative**: Consumed. S1 reads the queue and clears it. S0 on the next iteration may produce new readiness events. Accumulation risks processing stale events.

### Q4: Batch-worker persistent network snapshot

The batch-worker currently snapshots 24+ macros parameters. With persistent cells, it should snapshot the persistent network box. Is one box sufficient?

**Tentative**: Yes. The persistent network box contains the CHAMP-based prop-network, which is immutable — the snapshot IS the box dereference. Restoring the box pointer restores all registry state atomically.
