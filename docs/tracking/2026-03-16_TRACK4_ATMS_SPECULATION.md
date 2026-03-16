# Track 4: ATMS Speculation — TMS-in-Network Design

**Created**: 2026-03-16
**Revised**: 2026-03-16 (D.4 — lattice-theoretic rework: TMS integrated into prop-network)
**Status**: DESIGN (Stage 2/3)
**Depends on**: Track 3 (Cell-Primary Registries) — ✅ COMPLETE
**Enables**: Track 5 (Global-Env + Dependency Edges), Track 9 (GDE)
**Research basis**: `2026-03-11_WHOLE_SYSTEM_PROPAGATOR_MIGRATION.md` §2.3 (Dependency-Directed Backjumping), `2026-02-24_LOGIC_ENGINE_DESIGN.md` §5 (ATMS Integration)
**Prior implementation**: Migration Sprint Phase 0b (ATMS infrastructure), Phase 4a–4e (speculation audit + ATMS mandatory)
**Master roadmap**: `2026-03-13_PROPAGATOR_MIGRATION_MASTER.md` Track 4

---

## Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| D.1 | Design analysis and speculation audit | ✅ | Initial document |
| D.2 | Design iteration (external critique) | ✅ | 8 accepted, 2 accepted-with-modification, 5 rejected-with-rationale |
| D.3 | Internal self-critique (principle alignment) | ✅ | 5 items resolved |
| D.4 | Lattice-theoretic rework (TMS-in-network) | ✅ | This revision |
| 0 | Performance baseline + acceptance file | ⬜ | |
| 1 | TMS cell integration into prop-network | ⬜ | |
| 2 | Per-meta cells → TMS cells | ⬜ | |
| 3 | Level/mult/session metas → per-meta TMS cells | ⬜ | |
| 4 | Meta-info CHAMP → write-once registry; eliminate from save/restore | ⬜ | |
| 5 | Learned-clause integration (nogood reuse) | ⬜ | |
| 6 | Performance validation + cleanup | ⬜ | |
| 7 | Post-Implementation Review | ⬜ | |

---

## §1. Context

### 1.1 What Exists

Two parallel speculation mechanisms exist in the codebase:

**Mechanism A: Imperative bridge** (`elab-speculation-bridge.rkt`)
- `with-speculative-rollback` wraps a thunk in save/restore
- `save-meta-state` snapshots 6 immutable CHAMP references (network, id-map, meta-info, level-meta, mult-meta, sess-meta) — O(1) via structural sharing
- `restore-meta-state!` swaps box references back — O(1)
- Phase D added ATMS hypothesis creation per speculation, but only for error tracking (nogoods recorded on failure)
- **This is the active mechanism**: 6 call sites (4 `typing-core.rkt`, 1 `qtt.rkt`, 1 `typing-errors.rkt`)

**Mechanism B: Network-level speculation** (`elab-speculation.rkt`)
- `speculation-begin` forks the elab-network per alternative, creates ATMS `amb` group
- Full ATMS integration (assumptions, nogoods, mutual exclusion)
- **Not used by the type checker** — available infrastructure from Migration Sprint Phase 4

**The gap**: Mechanism A uses ATMS only for error tracking, not for state management. Mechanism B has full ATMS-backed state management, but operates on `elab-network`, not on the metavar store.

### 1.2 The Key Discovery: Per-Meta Cells Already Exist

The original design proposed "move meta-info CHAMP into a network cell." Deep investigation reveals this is the wrong abstraction. The production code paths show:

```racket
;; meta-solved? — PRODUCTION path (when network exists)
(define cid (prop-meta-id->cell-id id))    ;; CHAMP lookup #1: id-map
(let ([v (read-fn (unbox net-box) cid)])   ;; CHAMP lookup #2: cells
  (and (not (prop-type-bot? v)) (not (prop-type-top? v))))
```

`meta-solved?` and `meta-solution` **already read from per-meta cells in the propagator network**. Each metavariable gets its own cell at creation time (`fresh-meta!` → `elab-fresh-meta`), initialized to `type-bot`, solved to a concrete type. The cell value IS the lattice element.

The meta-info CHAMP stores `meta-info(id, ctx, type, status, solution, constraints, source)`. In production:
- **status/solution** → derivable from cell value (bot=unsolved, non-bot=solved, the value IS the solution)
- **ctx, type, source** → immutable, set at creation, never modified
- **constraints** → already live in constraint cells (Track 1)

The meta-info CHAMP is **largely redundant with the per-meta cells**. The mutable parts shadow what's already in the network. The immutable parts don't need speculation rollback.

### 1.3 What This Track Does

**Core goal**: Make existing per-meta cells TMS-aware, integrating assumption-tagged values into the propagator network itself. When speculation writes to a meta, the write is tagged with the speculation's assumption. On failure, assumption retraction makes the write invisible — no imperative save/restore needed for meta state.

**Structural goal**: Integrate TMS cells into `prop-network` (not as a separate ATMS layer) for total system observability. Every piece of state that participates in type-checking lives in one network, is capturable in one snapshot, and is inspectable through one mechanism.

**Meta-info simplification**: The meta-info CHAMP becomes a write-once registry for immutable metadata (ctx, type, source). It exits the speculation snapshot entirely — only TMS cells in the network need rollback/retraction.

Concretely:
- TMS cell infrastructure integrated into `prop-network`
- Per-meta type cells become TMS cells (assumption-tagged writes, worldview-filtered reads)
- Level/mult/session metas get per-meta TMS cells (paralleling type metas)
- Meta-info CHAMP becomes write-once registry, removed from `save-meta-state`
- `save-meta-state` reduces from 6 boxes to 1 (network only)
- Speculation rollback shifts from imperative restore to TMS retraction

### 1.4 Why This Matters

**Total system observability**: TMS in the network means every speculative value, every assumption, every retraction is visible through the network's cell inspection API. If TMS lives outside the network (in a separate ATMS struct), we lose provenance and explainability for the most important operations in the type checker. This is not acceptable.

**Fragility elimination**: The 6-box snapshot pattern requires updating `save-meta-state`/`restore-meta-state!` whenever new mutable state is added. With TMS-in-network, all mutable state is in network cells — new cells are automatically captured.

**Lattice-theoretic coherence**: Speculation is a lattice operation on a product lattice, not a temporal save/restore. Each meta cell lives in the type lattice (⊥=unsolved, concrete type=solved, ⊤=contradiction). Speculation creates a sub-lattice ("pocket universe" — α: abstraction). Success projects results back (γ: concretization). Failure discards the pocket. TMS cells implement this directly: assumption-tagged values form sub-lattices filtered by worldview.

**Learned clauses**: With ATMS nogoods as permanent learned clauses, the same assumption combination is never re-tried — pruning the speculation tree.

**GDE foundation**: Track 9 (General Diagnostic Engine) requires multi-hypothesis conflict analysis via ATMS. This requires speculation state to be ATMS-managed within the network.

---

## §2. Speculation Audit

### 2.1 Call Sites

| # | File | Line | Label | Thunk | Success? | Context |
|---|------|------|-------|-------|----------|---------|
| 1 | `typing-core.rkt` | 1198 | `"map-value-widening"` | `(check ctx v vt)` | `values` | Map value fits existing type? |
| 2 | `typing-core.rkt` | 1284 | `"union-map-get-component"` | `(check ctx k ...)` | `values` | Key matches union map component? |
| 3 | `typing-core.rkt` | 1318 | `"union-nil-safe-get-component"` | `(check ctx k ...)` | `values` | Key matches nil-safe map component? |
| 4 | `typing-core.rkt` | 2432 | `"union-check-left"` | `(check ctx e l)` | `values` | Expression checks against union left? |
| 5 | `qtt.rkt` | 2348 | `"union-checkQ-left"` | `(checkQ ctx e l)` | Custom `bu-ok?` | QTT check against union left? |
| 6 | `typing-errors.rkt` | 78 | `"union-branch-N"` | `(check ctx e br)` | `values` | Per-branch error enrichment |

**Pattern**: All 6 sites use `(with-speculative-rollback thunk success? label)`. The thunk runs `check`/`checkQ`/`infer` which mutate meta-state. On failure, state is restored. On success, mutations persist.

**Call site #6** (`typing-errors.rkt`) is special: error enrichment, not type-checking logic. Despite being "diagnostic," each speculative `(check ctx e br)` creates metas and solves constraints. Rollback correctly discards these mutations.

**Nested speculation**: Call sites #4 and #5 (union check) can nest arbitrarily. If `l` of `(union l r)` is itself `(union l2 r2)`, the inner `check` triggers inner speculation. Current implementation handles this: each level independently saves/restores, inner failures extracted as `sub-failures` (Phase D2).

### 2.2 State Captured by save-meta-state

| # | Parameter | CHAMP Box | Content | Purpose |
|---|-----------|-----------|---------|---------|
| 1 | `current-prop-net-box` | network | `prop-network` | All propagator cells (constraints, registries, per-meta type cells) |
| 2 | `current-prop-id-map-box` | id-map | `hasheq(meta-id → cell-id)` | Maps meta-ids to cell-ids |
| 3 | `current-prop-meta-info-box` | meta-info | `CHAMP(meta-id → meta-info)` | Primary metavar store: type, status, solution |
| 4 | `current-level-meta-champ-box` | level-meta | `CHAMP(id → solution)` | Universe level metavariables |
| 5 | `current-mult-meta-champ-box` | mult-meta | `CHAMP(id → solution)` | Multiplicity metavariables |
| 6 | `current-sess-meta-champ-box` | sess-meta | `CHAMP(id → solution)` | Session type metavariables |

**Post-Track-4 target**: Only box #1 (network) in `save-meta-state`. Boxes #2–6 either absorbed into the network (TMS cells), made write-once (meta-info), or eliminated (id-map monotonic).

### 2.3 Existing ATMS Infrastructure

From Migration Sprint Phase 0b (`atms.rkt`, `infra-cell.rkt`):

| Component | Status | Notes |
|-----------|--------|-------|
| `atms` struct (assumptions, nogoods, believed, amb-groups) | ✅ Ready | Pure value semantics |
| `atms-assume` / `atms-retract` | ✅ Ready | Assumption lifecycle |
| `atms-add-nogood` / `atms-consistent?` | ✅ Ready | Consistency checking |
| `atms-read-cell` / `atms-write-cell` (TMS cells) | ✅ Ready | Assumption-tagged I/O |
| `infra-assume` / `infra-retract` / `infra-commit` | ✅ Ready | Bridge API |
| `infra-write-assumed` / `infra-read-believed` | ✅ Ready | TMS cell I/O through infra-state |

### 2.3.1 Two-Level Rollback Semantics

The per-command ATMS lives in `current-command-atms` — a boxed parameter in `elab-speculation-bridge.rkt`, **NOT** in the propagator network. This is intentional for error tracking: ATMS hypotheses and nogoods accumulate across all speculation branches within a command, surviving rollback.

**Two levels (must be preserved)**:
1. **Logic-level rollback**: Meta-state (metas, constraints, network) rolls back
2. **Error-tracking persistence**: ATMS hypotheses and nogoods accumulate, NOT rolled back

**After Track 4**: TMS cells in the network handle logic-level rollback via assumption retraction. The `current-command-atms` becomes a shared reference to the ATMS data that lives within the network (see §3.2). Error-tracking state (hypothesis tree, nogoods) persists across rollback because TMS retraction doesn't delete — it marks as disbelieved.

### 2.4 What's NOT in the Network (Status Quo)

1. **Meta-info CHAMP** — primary metavar store. `fresh-meta!` writes, `solve-meta!` writes. **However**: `meta-solved?` and `meta-solution` already read from per-meta cells, not from this CHAMP. The CHAMP is the write-of-record, but cells are the read-of-record.

2. **Level/mult/session CHAMPs** — no per-meta cells today. All reads go through the CHAMP. These need per-meta cells.

3. **ID-map CHAMP** — maps meta-ids to cell-ids. Monotonic (only grows). Needed for `prop-meta-id->cell-id` lookup. Could be a network cell, but monotonic → rollback not needed.

4. **ATMS struct** — lives in `current-command-atms`. Hypotheses, nogoods, believed set. Must move into (or be referenced from) the network for total observability.

---

## §3. Design

### 3.1 Architectural Principle: TMS in the Network

✓ DESIGN DECISION

TMS cells must live in the prop-network, not in a separate ATMS struct. This is the whole goal: total system observability. If speculation state lives outside the network, we lose provenance and explainability.

**What this means concretely**: The `prop-network` struct gains TMS awareness. A cell can be either:
- **Monotonic** (existing): standard merge function, single value, captured by network snapshot
- **TMS** (new): assumption-tagged values, worldview-filtered reads, still captured by network snapshot

Both cell types live in the same `cells` CHAMP in `prop-network`. The distinction is in how reads/writes work, governed by a per-cell flag or type tag.

### 3.2 TMS Cell Design

#### 3.2.1 Cell Value Representation

A TMS cell's value in the network is a `tms-cell-value`:

```
(struct tms-cell-value (entries) #:transparent)
;; entries: (listof supported-entry) — newest first
;; Each entry: value + support set (which assumptions justify it)

(struct supported-entry (value support) #:transparent)
;; value: any (the lattice element — e.g., a type for per-meta cells)
;; support: hasheq assumption-id → #t
```

A TMS cell is stored in `prop-network-cells` just like any other cell. The difference is its merge function and how reads filter by worldview.

**Why in the network cells CHAMP**: This means `save-meta-state` (which snapshots the network box) automatically captures TMS cell state. The CHAMP is immutable — the snapshot shares structure. New assumption-tagged writes create new CHAMP nodes. Restoring the snapshot makes new writes invisible (same as current rollback for monotonic cells).

**Important**: This means we get BOTH rollback mechanisms:
- **Network-box restore** (imperative, current mechanism): works for TMS cells too, since they're in the network
- **TMS retraction** (structural, new mechanism): marks values as disbelieved without box restore

During the transitional phase, both coexist. Once TMS retraction is proven correct, network-box restore becomes a no-op for TMS cells (retraction already handled it), and `save-meta-state` simplifies to 1 box.

#### 3.2.2 ATMS Metadata in the Network

The ATMS tracks metadata that must persist across rollback:
- **Assumptions registry**: `hasheq assumption-id → assumption` — which hypotheses exist
- **Nogoods**: `(listof hasheq)` — known-inconsistent assumption sets
- **Believed set**: `hasheq assumption-id → #t` — current worldview
- **Next-assumption counter**: monotonic Nat

This metadata is stored in a **dedicated ATMS cell** in the network with a `merge-atms-metadata` function. The cell is monotonic for some fields (assumptions, nogoods — only grow) and non-monotonic for believed (changes on retract/assume).

**But**: if the believed set is in the network and the network is snapshot-restored on speculation failure, the believed set would also revert. This conflicts with error-tracking persistence (nogoods must accumulate).

**Resolution**: The ATMS metadata cell uses **merge-accumulate semantics**: the merge function is a union that never discards. Network-box restore replaces the cell value with the saved snapshot, but the `with-speculative-rollback` code re-applies accumulated nogoods/hypotheses after restore. This is a small amount of bookkeeping:

```
;; Pseudocode
(define pre-atms (read-atms-metadata))
(define saved-net (unbox net-box))
(define result (thunk))
(cond
  [(success? result) result]
  [else
   (set-box! net-box saved-net)
   ;; Re-apply ATMS accumulations that occurred during the thunk
   (define post-atms (read-atms-metadata-from saved-net)) ;; doesn't have new nogoods
   (write-atms-metadata! (merge-atms-accumulated pre-atms current-atms post-atms))
   ...])
```

**Alternative (simpler)**: Keep the ATMS metadata in its own dedicated box (`current-command-atms`) that is NOT snapshot-restored. Only TMS cell *values* (the `tms-cell-value` structs) live in the network. The ATMS box is the "control plane" (which assumptions exist, which are believed), while TMS cell values in the network are the "data plane" (what values are tagged with which assumptions). The control plane persists; the data plane snapshots.

This alternative is simpler, preserves the existing two-level rollback semantics, and still achieves total observability — TMS cell values are in the network (inspectable), and the ATMS box is a well-defined parameter (inspectable via `current-command-atms`).

✓ DESIGN DECISION: **ATMS metadata stays in `current-command-atms` (control plane). TMS cell values live in the network (data plane).** The control plane is append-only during a command (hypotheses and nogoods only grow), so it doesn't need snapshot/restore. The data plane snapshots with the network.

#### 3.2.3 Worldview for Cell Reads

TMS cell reads filter by the currently believed assumptions. The believed set comes from the ATMS control plane (`current-command-atms`).

```
;; Reading a TMS cell
(define (tms-cell-read net cid believed)
  (define cell-val (net-cell-read net cid))  ;; returns tms-cell-value
  (cond
    [(tms-cell-value? cell-val)
     ;; Find newest entry whose support ⊆ believed
     (for/or ([entry (in-list (tms-cell-value-entries cell-val))])
       (and (hash-subset? (supported-entry-support entry) believed)
            (supported-entry-value entry)))]
    [else cell-val]))  ;; non-TMS cell, return as-is
```

**Cost on hot path**: `meta-solved?` currently does 2 CHAMP lookups (id-map + cells). With TMS, it does 2 CHAMP lookups + iterate supported entries (typically 1 at speculation depth 0, 2 at depth 1). The `hash-subset?` check on small support sets (1-2 assumptions) is effectively O(1).

**Optimization**: At speculation depth 0, no TMS filtering needed. A `current-speculation-depth` counter (incremented on speculation entry) can skip TMS filtering entirely when depth=0.

#### 3.2.4 TMS Cell Merge Function

```
(define (merge-tms-cell old new)
  (cond
    [(eq? old 'infra-bot) new]
    [(eq? new 'infra-bot) old]
    [(and (tms-cell-value? old) (tms-cell-value? new))
     ;; Merge entry lists: union of supported entries
     ;; Same (value, support) pair → deduplicate
     ;; Different values with same support → keep both (worldview resolves)
     (tms-cell-value (append (tms-cell-value-entries new)
                             (tms-cell-value-entries old)))]
    ;; Transition from plain value to TMS: wrap the old value with empty support
    [(tms-cell-value? new)
     (tms-cell-value (cons (supported-entry old (hasheq))
                           (tms-cell-value-entries new)))]
    [else new]))
```

**Note on monotonicity**: Within a single speculation branch, meta solving is monotone (unsolved→solved, never reversed). Across branches, TMS handles non-monotonicity structurally (retraction = disbelief, not deletion). The merge function doesn't need to handle conflict between branches — worldview filtering resolves which branch's values are visible.

### 3.3 Per-Meta TMS Cell Architecture

#### 3.3.1 Type Metas (Existing Cells → TMS)

Per-meta type cells already exist. The change:

**Before**: `fresh-meta!` creates a cell with initial value `type-bot`. `solve-meta!` writes the solution directly. `meta-solved?` reads the cell and checks for non-bot.

**After**: `fresh-meta!` creates a TMS cell with initial entry `(supported-entry type-bot (hasheq))` (unconditional bot). `solve-meta!` writes `(supported-entry solution current-assumption)`. `meta-solved?` reads the TMS cell filtered by believed set — sees the solution if its assumption is believed, or bot if not.

**When not in speculation** (depth 0): The assumption is empty (`(hasheq)`), meaning the entry is unconditionally visible. No filtering overhead.

**When in speculation**: The write carries the speculation's assumption-id. On retraction, the entry is no longer visible under the new worldview. The old `type-bot` entry (with empty support) becomes visible again — the meta appears unsolved.

#### 3.3.2 Level/Mult/Session Metas (New Per-Meta Cells)

These currently use aggregate CHAMPs (`current-level-meta-champ-box`, etc.) with no per-meta cells. Track 4 adds per-meta TMS cells:

- `fresh-level-meta!` creates a TMS cell (value = `'unsolved`, later solved to a level)
- `solve-level-meta!` writes to TMS cell under current assumption
- Level/mult/session reads filter by worldview

Same pattern as type metas, different value lattice.

**Alternative**: Keep aggregate CHAMP cells (one cell for all level metas, one for all mult metas, one for all session metas) but make them TMS cells. This avoids creating many small cells but makes the merge function more complex (per-key assumption tracking within a CHAMP).

✓ DESIGN DECISION: **Per-meta TMS cells for level/mult/session**, paralleling type metas. The per-meta approach is simpler (each cell is a single lattice element with assumption tags), avoids complex per-key-in-CHAMP TMS tracking, and aligns with the existing per-meta architecture for type metas. The additional cell count is bounded by the number of level/mult/session metas created (typically small — a few dozen per command at most).

#### 3.3.3 Meta-Info CHAMP → Write-Once Registry

The meta-info CHAMP currently stores `meta-info(id, ctx, type, status, solution, constraints, source)`. After Track 4:

- **status, solution**: derivable from per-meta TMS cells (no longer stored in CHAMP)
- **constraints**: in constraint cells (Track 1 — already complete)
- **ctx, type, source**: immutable metadata set at creation time

The meta-info CHAMP becomes a write-once registry of immutable metadata:

```
(struct meta-registry-entry (id ctx type source) #:transparent)
```

Write-once means: `fresh-meta!` inserts an entry, and no operation ever modifies it. The CHAMP grows monotonically. **It does not need to participate in speculation rollback.**

**However**: `fresh-meta!` during a failed speculation creates registry entries for metas that should "disappear." These entries are harmless — they're orphaned metadata with no corresponding solved cell. `all-unsolved-metas` would need to skip orphaned entries (check if the meta's cell exists and is visible under the current worldview).

**Refinement**: On speculation failure, orphaned meta-registry entries remain but are invisible because their TMS cells show `type-bot` under the current worldview. `all-unsolved-metas` already filters by status — bot means unsolved, and the meta was never used for anything. The post-fixpoint error sweep can safely ignore metas whose cells were never written under the current worldview.

#### 3.3.4 ID-Map

The id-map (`meta-id → cell-id`) is monotonic (IDs are only added). Like the meta-info registry, it doesn't need speculation rollback. Orphaned entries from failed speculation are harmless (the cell exists but shows bot under the worldview).

**Decision**: Keep id-map as a standalone monotonic CHAMP box. It could be a network cell, but there's no benefit (it doesn't need merge semantics, TMS, or propagator wiring). Including it in the network adds overhead without value. It's a pure lookup index.

### 3.4 Speculation Rewrite

#### 3.4.1 New `with-speculative-rollback`

```
;; Design sketch — Phase 2+ implementation
(define (with-speculative-rollback thunk success? label)
  (perf-inc-speculation!)
  ;; 1. Create ATMS assumption (control plane — persists across rollback)
  (define atms-box (current-command-atms))
  (define-values (_a* hyp-id) (atms-assume (unbox atms-box) ...))
  (set-box! atms-box _a*)
  ;; 2. Enter speculation context
  (define prev-assumption (current-speculation-assumption))
  (define prev-depth (current-speculation-depth))
  ;; 3. Snapshot for belt-and-suspenders (Phase 2 transitional; Phase 4 removes)
  (define saved-net (unbox (current-prop-net-box)))
  ;; 4. Run thunk under assumption
  (define result
    (parameterize ([current-speculation-assumption hyp-id]
                   [current-speculation-depth (add1 prev-depth)])
      (thunk)))
  (cond
    [(success? result) result]  ;; Commit: assumption stays believed
    [else
     ;; 5a. Retract assumption (TMS cells' tagged values become invisible)
     (set-box! atms-box (atms-retract (unbox atms-box) hyp-id))
     ;; 5b. Restore network snapshot (belt-and-suspenders for monotonic cells)
     (set-box! (current-prop-net-box) saved-net)
     ;; 5c. Record failure (as today)
     (record-speculation-failure! label hyp-id ...)
     #f]))
```

**Transitional**: During Phase 2, both TMS retraction AND network-box restore are used. This is belt-and-suspenders: TMS handles per-meta cells, network restore handles monotonic cells (constraints, registries). Once all mutable speculation state is in TMS cells, the network restore becomes redundant for speculation (but may remain for other purposes).

#### 3.4.2 Nested Speculation

Nesting works naturally with TMS. Each nesting level creates its own assumption. Inner writes are tagged with the inner assumption. Inner retraction makes inner writes invisible without affecting outer writes.

Example: union-of-unions `check e (union (union A B) C)`:
1. Outer speculation: assume H1 ("try union left = (union A B)")
2. Inner speculation: assume H2 ("try inner left = A")
3. Inner check fails → retract H2 (inner writes invisible)
4. Inner speculation: assume H3 ("try inner right = B")
5. Inner check succeeds → H3 stays believed, inner writes visible
6. Outer check succeeds → H1 stays believed, outer writes visible
7. Final worldview: {H1, H3} believed; H2 retracted

The sub-failure extraction (Phase D2) continues to work: inner failures are captured as sub-failures of the outer failure.

#### 3.4.3 Worked Example: Union Type Speculation

**Scenario**: `check expr against (union (Map String Int) (Map String String))`

**Before Track 4 (current):**
1. `save-meta-state` → snapshot 6 boxes
2. `check expr (Map String Int)` → `fresh-meta` M1 in meta-info CHAMP + cell; `solve-meta` M1; type fails
3. `restore-meta-state!` → restores all 6 boxes (M1 gone from meta-info; network cells rolled back)
4. `check expr (Map String String)` → `fresh-meta` M2, succeeds
5. Commit — M2 persists

**After Track 4:**
1. `atms-assume` H1 → hypothesis for "try Map String Int"
2. `check expr (Map String Int)` → `fresh-meta` M1 with TMS cell tagged {H1}; `solve-meta` M1 writes solution tagged {H1}; type fails
3. `atms-retract` H1 → M1's TMS entries invisible (meta-info registry has orphaned entry — harmless)
4. Network-box restore (belt-and-suspenders) — restores monotonic cells
5. `atms-assume` H2 → hypothesis for "try Map String String"
6. `check expr (Map String String)` → `fresh-meta` M2 with TMS cell tagged {H2}; succeeds
7. Commit — H2 believed, M2's solution visible; H1 retracted, M1's entries invisible
8. Nogood {H1} recorded for GDE error chains

### 3.5 Phase Structure

#### Phase 0: Performance Baseline + Profiling

- Acceptance file: `examples/2026-03-16-track4-acceptance.prologos` (user-managed)
- Baseline: full suite timing, cell count metrics
- **Profiling**: Instrument `meta-solved?`/`meta-solution` call frequency and cost. Measure TMS filtering overhead via microbenchmark (create TMS cell, write 1-3 entries, filter by worldview).
- Pre-flight: verify all 6 call sites with grep, confirm no new ones since Track 3

#### Phase 1: TMS Cell Integration into prop-network

**Scope**: Add TMS cell support to the propagator network. No meta cells converted yet — this is pure infrastructure.

**Files**: `propagator.rkt`, `atms.rkt` (or new `tms-cell.rkt`)

1. Define `tms-cell-value` and `supported-entry` structs
2. Add `merge-tms-cell` merge function
3. Add `net-new-tms-cell` factory: creates a cell with `merge-tms-cell` and initial `(tms-cell-value '())`
4. Add `net-tms-cell-read`: reads cell value, filters by believed set
5. Add `net-tms-cell-write`: creates `supported-entry` with current assumption, writes via standard cell write (merge appends)
6. Add `current-speculation-assumption` parameter (assumption-id | #f)
7. Add `current-speculation-depth` parameter (Nat, 0 = not speculating)

**Verification**: Unit tests for TMS cell operations. No production code changes — existing behavior unchanged.

#### Phase 2: Per-Meta Type Cells → TMS Cells

**Scope**: Convert existing per-meta type cells from monotonic to TMS. This is the core speculation change.

**Files**: `metavar-store.rkt`, `driver.rkt` (cell creation in `elab-fresh-meta`)

1. `elab-fresh-meta` creates TMS cells instead of monotonic cells (initial value: `(tms-cell-value (list (supported-entry type-bot (hasheq))))`)
2. `solve-meta-core!` writes through `net-tms-cell-write` with current assumption
3. `meta-solved?` reads through `net-tms-cell-read` with current believed set
4. `meta-solution` reads through `net-tms-cell-read`
5. Update `with-speculative-rollback` to set `current-speculation-assumption` and use TMS retraction on failure (retain network-box restore as belt-and-suspenders)

**Critical invariant**: At speculation depth 0, all TMS reads must return the same values as current monotonic reads. This is verified by the full test suite (which doesn't exercise manual speculation).

**Risk**: This is the highest-risk phase. `meta-solved?` and `meta-solution` are the hottest operations. TMS filtering adds cost. Mitigated by: (a) depth-0 fast path (skip filtering), (b) small support sets (O(1) subset check), (c) profile before/after.

**Contingency**: If TMS read overhead >15%: investigate caching the worldview-filtered result per cell per worldview version (a "TMS read cache" that's invalidated on assume/retract). This avoids repeated filtering of the same cell within a speculation context.

#### Phase 3: Level/Mult/Session Metas → Per-Meta TMS Cells

**Scope**: Add per-meta TMS cells for level, mult, and session metavariables. Currently these use aggregate CHAMPs with no per-meta cells.

**Files**: `metavar-store.rkt`

1. `fresh-level-meta!` creates a TMS cell (paralleling `elab-fresh-meta`)
2. `solve-level-meta!` writes through TMS cell write
3. Level/mult/session reads go through TMS cell reads with worldview filtering
4. Remove level/mult/session CHAMPs from `save-meta-state` (their state is now in TMS cells in the network)

**After Phase 3**: `save-meta-state` captures 3 boxes: network + id-map + meta-info. Down from 6.

#### Phase 4: Meta-Info CHAMP → Write-Once Registry; Simplify save/restore

**Scope**: Remove mutable fields from meta-info. Simplify save/restore to 1 box.

**Files**: `metavar-store.rkt`, `elab-speculation-bridge.rkt`

1. Define `meta-registry-entry(id, ctx, type, source)` struct — no status, solution, or constraints
2. `fresh-meta!` writes `meta-registry-entry` to the CHAMP (write-once)
3. Remove `solve-meta-core!`'s write to meta-info CHAMP (cell is the sole record of solution)
4. `meta-lookup` returns `meta-registry-entry` (immutable metadata only)
5. `all-unsolved-metas` reads from meta-info registry + checks each meta's TMS cell for unsolved status
6. Remove meta-info CHAMP from `save-meta-state`
7. Remove id-map from `save-meta-state` (monotonic, no rollback needed)
8. `save-meta-state` = `(unbox (current-prop-net-box))` — 1 box
9. `restore-meta-state!` = `(set-box! (current-prop-net-box) saved)` — 1 box

**After Phase 4**: The 6-box fragility is eliminated. Network snapshot is the single source of truth.

#### Phase 5: Learned-Clause Integration (Nogood Reuse)

**Scope**: When speculation fails and a nogood is recorded, use it to prune future speculations.

1. Before creating an assumption for a speculation branch, check if the proposed assumption (combined with current context assumptions) subsumes any known nogood
2. If so, skip the branch entirely (no thunk execution)
3. Performance: `atms-consistent?` is O(N×M) where N=nogoods, M=assumption set size. For typical type checking (few nogoods, small sets), this is negligible.

**Prerequisite**: Phase 2 (TMS cells operational). Nogoods from TMS retraction provide the learned clauses.

#### Phase 6: Performance Validation + Cleanup

- Full suite timing comparison against baseline
- Remove belt-and-suspenders network-box restore (if TMS retraction is sole rollback mechanism and is stable)
- Remove vestigial dual-write paths (meta-info CHAMP writes for solved status)
- Update PIR process doc references
- Clean up temporary instrumentation

#### Phase 7: Post-Implementation Review

Standalone PIR document following established template.

### 3.6 File-to-Phase Mapping

| File | Phase | Nature |
|------|-------|--------|
| `propagator.rkt` or new `tms-cell.rkt` | 1 | TMS cell structs, merge, read/write |
| `metavar-store.rkt` | 2, 3, 4 | TMS cell creation/read/write for metas; registry refactor; save/restore simplification |
| `driver.rkt` | 2 | `elab-fresh-meta` creates TMS cells |
| `elab-speculation-bridge.rkt` | 2, 4 | Assumption parameterization, TMS retraction, save/restore simplification |
| `infra-cell.rkt` | 1 | TMS merge function |
| `atms.rkt` | 1 | Possibly extended for network-integrated TMS |

### 3.7 Parallelism Interaction

Speculation is **single-threaded** within the current architecture. Each `with-speculative-rollback` is sequential: try left, if fail restore, try right. There is no parallel speculation.

BSP parallel propagation applies within a single speculation context, not across branches. During a speculative thunk, propagators may fire in parallel (BSP supersteps), but the speculation boundary is a sequential decision point.

**After Track 4**: This doesn't change. TMS cells theoretically enable parallel speculation (each branch uses its own assumption, reads filter by worldview), but this is far-future scope.

**Merge safety**: Multiple propagators writing to different TMS cells during BSP cannot cause corruption — each per-meta cell is written by at most one propagator/operation at a time (propagators are scoped to specific metas).

### 3.8 Two-Context Architecture Impact

Track 3 established: elaboration reads cells, module loading reads parameters.

- **Meta reads during elaboration**: Go through TMS cell reads (worldview-filtered)
- **Meta reads outside elaboration**: Fall back to TMS cell read with empty believed set (sees unconditionally-supported values only — equivalent to current behavior)

The elaboration guard pattern is not needed for per-meta TMS cells because the TMS read with empty believed returns the same result as a plain cell read (unconditional entries are always visible).

---

## §4. Risk Analysis

### 4.1 Risk Assessment: Medium-High (Overall)

Track 4 introduces TMS cells on the hottest read path in the type checker. However:
- The depth-0 fast path eliminates TMS overhead for the common case (no active speculation)
- TMS filtering on small support sets (1-2 entries) is effectively O(1)
- The architecture is proven (ATMS infrastructure exists, TMS cells are tested)
- Belt-and-suspenders approach (TMS + network restore) provides safety net during transition

### 4.2 Known Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| TMS read overhead on `meta-solved?`/`meta-solution` | Medium | High | Depth-0 fast path; profile before/after Phase 2 |
| TMS cell value growth (many entries per cell) | Low | Medium | Entries bounded by speculation depth × branches; typical: 1-3 |
| ATMS believed set update cost | Low | Low | Set is small (bounded by speculation depth); hash-subset? is O(k) for k=set size |
| Orphaned meta-registry entries | Low | Low | Harmless — unsolved metas with invisible cells; filtered by `all-unsolved-metas` |
| Belt-and-suspenders divergence (TMS and box-restore disagree) | Medium | Medium | Assertion checking in Phase 2: verify TMS-retracted state matches box-restored state |
| Level/mult/session cell count explosion | Low | Low | These metas are few per command (dozens, not thousands) |
| Interaction with batch-worker isolation | Low | Medium | batch-worker saves/restores parameters; network box is already in that list |
| ATMS state synchronization | Low | Low | Control plane stays in `current-command-atms` (intentionally outside snapshot). Data plane (TMS cells) in network (snapshot). Two-level semantics preserved. |

### 4.3 Open Questions

1. **Should `tms-cell-value` use a vector instead of list for entries?** Lists are simpler but vectors would allow indexed access. For typical entry counts (1-3), list is fine. Defer optimization.

2. **What happens to `batch-worker.rkt`?** After Phase 4, it saves/restores the network box (1 box). This is mechanical. The `current-command-atms` parameter also needs save/restore for worker isolation.

3. **Can Phase 5 (learned clauses) prune enough to be measurable?** Depends on speculation patterns. Union-of-unions creates the most speculation. Profile in Phase 0 to count how often the same branch patterns recur.

---

## §5. Principle Alignment

| Principle | How This Track Upholds It |
|-----------|--------------------------|
| **Data Orientation** | TMS cell values are pure data (supported entries with value + support set). No procedures or closures. |
| **Propagator-First Infrastructure** | All type-checking state flows through the propagator network — including speculative state via TMS cells. No off-network shortcuts. |
| **Correct by Construction** | TMS retraction structurally ensures speculative writes become invisible. No box list to maintain. 1-box save/restore is structurally complete. |
| **Decomplection** | Eliminates the 6-box coupling. Separates immutable metadata (registry) from mutable speculation state (TMS cells). |
| **Compositionality** | TMS assumptions compose for nested speculation. Each level's assumption is independent. |
| **Total System Observability** | Every speculative value is in the network. Every assumption tag is inspectable. Error derivation chains (ATMS nogoods) connect to the values that produced them. Nothing hides outside the network. |

**No honest tension**: Unlike the previous design where Phases 1–3 achieved consolidation but not structural ATMS, this design commits to TMS throughout. Phase 4 is not conditional.

---

## §6. Effort Estimate

| Phase | Scope | Est. Effort | Risk |
|-------|-------|-------------|------|
| 0 | Baseline + profiling | 1 hour | Low |
| 1 | TMS cell infrastructure in prop-network | 2–3 hours | Low-Medium |
| 2 | Per-meta type cells → TMS | 3–5 hours | Medium-High |
| 3 | Level/mult/session → per-meta TMS cells | 2–3 hours | Medium |
| 4 | Meta-info → write-once; save/restore → 1 box | 2–3 hours | Medium |
| 5 | Learned-clause integration | 2–3 hours | Medium |
| 6 | Performance validation + cleanup | 1–2 hours | Low |
| 7 | PIR | 1 hour | Low |

**Total**: ~14–21 hours. No conditional phases — all are committed.

Phase 2 estimate is highest because it touches the hottest code path and requires the most verification/profiling.

### 6.1 Success Metrics

| Metric | Target |
|--------|--------|
| save/restore box count | 1 (was 6) |
| Performance delta | <15% regression (depth-0 fast path should keep it <10%) |
| Test regressions | 0 |
| Speculation bugs | 0 |
| TMS read overhead at depth 0 | <5% vs current `meta-solved?` |
| Nogood reuse rate (Phase 5) | >0 observed in speculation-heavy tests |

---

## §7. Composition Synergies

### 7.1 GDE Foundation (Track 9)

TMS-in-network means every speculative type-checking step is tagged with its assumption. The GDE can compute minimal diagnoses by analyzing which assumptions lead to nogoods. Error messages can trace derivation chains through the network.

### 7.2 Incremental Re-elaboration (Track 5)

Track 5 needs definition retraction. With TMS cells, "retract a definition" means retracting its assumption — all type-checking results that depended on it become invisible. The network shows the pre-definition state without imperative restore.

### 7.3 Driver Simplification (Track 6)

After Track 4, the dual-write pattern for metas (CHAMP + cell) is eliminated. `solve-meta-core!` writes only to the TMS cell. The meta-info CHAMP is write-once. Track 6 can remove the CHAMP write entirely.

### 7.4 Dependency-Directed Backjumping

From the Whole-System Migration Thesis §2.3: when speculation fails, the ATMS nogood identifies the minimal set of assumptions responsible. Phase 5's learned-clause integration enables automatic pruning.

---

## §8. Design Iteration History

### D.1: Initial Design (2026-03-16)
- Options A–D analysis
- Recommended Option A (CHAMP-in-cell)
- Phase 4 conditional

### D.2: External Critique Response (2026-03-16)
- 8 accepted, 2 accepted-with-modification, 5 rejected-with-rationale
- Added: worked example, parallelism analysis, success metrics, nested speculation semantics

### D.3: Internal Self-Critique (2026-03-16)
- 5 items resolved: data orientation, propagator-first, correct-by-construction, deferral justification, PIR focus

### D.4: Lattice-Theoretic Rework (2026-03-16)
Major rework based on collaborative design discussion. Key insights:
1. **Per-meta cells already exist** — `meta-solved?`/`meta-solution` read from them in production. The CHAMP-in-cell approach adds indirection on a redundant structure.
2. **TMS must be in the network** — total system observability requires every speculative value to be inspectable through the network. Off-network TMS loses provenance.
3. **Phase 4 is not conditional** — commit to TMS cells as the speculation mechanism.
4. **Lattice embedding framing** — speculation as sub-lattice creation (pocket universes), not temporal save/restore. TMS cells implement this directly.
5. **Meta-info CHAMP → write-once registry** — immutable metadata exits the speculation snapshot.
6. **ATMS control/data plane split** — ATMS metadata (hypotheses, nogoods, believed) stays in `current-command-atms` (control plane, persists across rollback). TMS cell values live in the network (data plane, snapshots with network).

---

## §9. Post-Implementation Review

*Reference to standalone PIR document (to be created after implementation).*
