# Track 4: ATMS Speculation — TMS-in-Network Design

**Created**: 2026-03-16
**Revised**: 2026-03-16 (D.5 — recursive CHAMP TMS cells, provenance-by-default)
**Status**: ✅ COMPLETE (Phase 4 deferred to Track 6 — see §Phase 4 Deferral Rationale)
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
| D.4 | Lattice-theoretic rework (TMS-in-network) | ✅ | Initial TMS-in-network design |
| D.5 | Recursive CHAMP cells + provenance-by-default | ✅ | This revision |
| 0 | Performance baseline + acceptance file | ✅ | 191.6s / 7096 tests, acceptance 76 speculations, commit `50b00d8` |
| 1 | TMS cell integration into prop-network | ✅ | tms-cell-value struct, tms-read/write/commit/merge, net-new-tms-cell, 27 unit tests, 197.0s / 7123 tests, commit `ecde661` |
| 2 | Per-meta cells → TMS cells | ✅ | TMS-transparent read/write, domain-aware merge, stack push deferred to Track 6, 196.1s / 7124 tests, commit `10ecb0c` |
| 3 | Level/mult/session metas → per-meta TMS cells | ✅ | Per-meta TMS cells for all 3, save/restore reduced 6→3 boxes, 188.2s / 7124 tests, commit `addaf46` |
| 4 | Meta-info CHAMP → write-once registry; eliminate from save/restore | ⏸️ | Deferred to Track 6 — requires speculation stack push + commit-on-success + TMS retraction pipeline (see §Deferral Rationale below) |
| 5 | Learned-clause integration (nogood reuse) | ✅ | atms-consistent? pruning before thunk execution, speculation-pruned counter, 187.1s / 7124 tests, commit `f0f72da` |
| 6 | Performance validation + cleanup | ✅ | 187.1s vs 191.6s baseline (2.4% faster), acceptance L3 0 errors, 76 speculations / 113 hypotheses / 32 nogoods / 0 pruned, Phase 4 deferred |
| 7 | Post-Implementation Review | ✅ | PIR at `2026-03-16_TRACK4_ATMS_SPECULATION_PIR.md` |

### Phase 4 Deferral Rationale

Phase 4 (meta-info CHAMP → write-once registry; save/restore → 1 box) is deferred to **Track 6 (Driver Simplification + Cleanup)**, not to a later phase within Track 4. The reasons:

1. **Removing id-map from save/restore risks stale cell references**: After `restore-meta-state!`, id-map entries created during speculation point to cell IDs that no longer exist in the restored network. Any subsequent read via those stale IDs would return incorrect values or crash. Solving this requires TMS retraction (where cell values are retracted rather than the network being replaced), which is a Track 6 concern.

2. **Removing meta-info from save/restore requires `all-unsolved-metas` migration**: Currently `all-unsolved-metas` walks the meta-info CHAMP to find unsolved entries. If meta-info becomes write-once (no status field), `all-unsolved-metas` must instead scan all per-meta TMS cells in the network — a different iteration pattern that depends on Track 5's network infrastructure.

3. **The prerequisite chain is**: speculation stack push → commit-on-success → TMS retraction → remove network-box restore → save/restore → 1 box. Each step depends on the prior. Stack push requires commit-on-success (otherwise depth-0 reads see stale base values after speculation success). Commit-on-success requires TMS retraction to replace network restore. All of this is Track 6 scope.

4. **The 3-box save/restore works correctly**: Phases 1–3 and 5 achieved the primary Track 4 goals (TMS cells for all 4 meta types, learned-clause pruning) with the 3-box pattern. The reduction from 6→3 boxes already eliminated the level/mult/session CHAMPs from the snapshot. Further reduction to 1 box is cleanup, not architectural.

**Impact**: Track 6's scope explicitly includes this work. See master roadmap §Deferrals.

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

#### 3.2.1 Cell Value Representation: Recursive CHAMP Tree

✓ DESIGN DECISION (D.5)

TMS cell values use a **recursive CHAMP-indexed tree** that mirrors the nesting structure of speculation. The data structure shape reflects the domain shape — speculation nests, so the data nests.

```
(struct tms-cell-value
  (base       ;; unconditional value (the ⊥ / ground truth, always visible at depth 0)
   branches)  ;; hasheq assumption-id → (value | tms-cell-value)
  #:transparent)
```

Nesting is structural: if `(hash-ref branches H1)` returns a `tms-cell-value`, that means H1's speculation itself had sub-speculations. If it returns a plain value, it's a leaf. The tree IS the data — no flattened lists, no backpointers.

**Example** — nested union speculation:

```
;; check expr against (union (union A B) C)
;; Outer H1 ("try union-left = (union A B)"), inner H2 ("try A"), inner H3 ("try B"), outer H4 ("try C")
(tms-cell-value
  type-bot                              ;; base: unconditional ⊥
  {H1 → (tms-cell-value
           Int                          ;; H1's base: solved to Int
           {H2 → Nat                   ;; nested: tried Nat under H2 (failed)
            H3 → Int})                 ;; nested: tried Int under H3 (succeeded)
   H4 → String})                       ;; alternative: solved to String under H4
```

**Why recursive CHAMP over flat list + backpointers**: The flat list approach requires O(k) scan with subset checks on the hot path. The recursive CHAMP gives O(d) indexed traversal (d = speculation depth, d ≤ k always). Each level is a CHAMP `hash-ref` — the same O(1) primitive we use everywhere. The tree structure also directly supports all provenance queries without reconstruction.

**Query pattern analysis:**

| Query | Recursive CHAMP cost | Flat list cost |
|-------|---------------------|---------------|
| Hot path: "value under current worldview" | O(d) CHAMP lookups via speculation stack | O(k) scan + subset checks |
| Tooling: "what was written under H2?" | O(1) — `hash-ref branches H2` | O(k) scan for H2 |
| Provenance: "path from root to current value" | O(d) — traverse from root through believed | O(d) — walk parent links |
| Full tree enumeration | Natural recursive traversal | Reconstruct from backpointers |

**Reading via speculation stack**: `with-speculative-rollback` maintains a `current-speculation-stack` parameter (a list of assumption-ids, pushed on speculation entry, popped on exit). Reads traverse the tree following the stack:

```
;; Read: follow the speculation stack through the tree
(define (tms-read cell-val stack)
  (cond
    [(null? stack) (tms-cell-value-base cell-val)]
    [else
     (define branch (hash-ref (tms-cell-value-branches cell-val)
                               (car stack) #f))
     (cond
       [(not branch) (tms-cell-value-base cell-val)]   ;; no write at this depth
       [(tms-cell-value? branch) (tms-read branch (cdr stack))]  ;; recurse
       [else branch])]))  ;; leaf value
```

**Writing via speculation stack**: Writes navigate to the correct nesting depth and insert:

```
;; Write: nested CHAMP insert at the current speculation depth
(define (tms-write cell-val stack value)
  (cond
    [(null? stack)
     ;; Unconditional write — update base
     (struct-copy tms-cell-value cell-val [base value])]
    [(null? (cdr stack))
     ;; Leaf of stack — insert/update in branches
     (struct-copy tms-cell-value cell-val
       [branches (hash-set (tms-cell-value-branches cell-val)
                           (car stack) value)])]
    [else
     ;; Deeper — recurse into existing branch or create new sub-tree
     (define existing (hash-ref (tms-cell-value-branches cell-val)
                                (car stack)
                                (tms-cell-value 'tms-bot (hasheq))))
     (define sub-tree (if (tms-cell-value? existing) existing
                          (tms-cell-value existing (hasheq))))
     (struct-copy tms-cell-value cell-val
       [branches (hash-set (tms-cell-value-branches cell-val)
                           (car stack)
                           (tms-write sub-tree (cdr stack) value))])]))
```

Write cost: O(d) nested CHAMP updates. Each creates a new CHAMP node (structural sharing preserves old state). For d=1-2, this is negligible — and still cheaper than the current dual-write (meta-info CHAMP + cell).

**CHAMP structural sharing for snapshots**: Each level of the tree is a CHAMP. The network snapshot shares structure across the entire tree. A speculative write at depth 2 modifies only the inner CHAMP — outer CHAMPs share structure with pre-write state. Same structural sharing property as current save/restore.

**Depth-0 fast path**: At speculation depth 0, `(current-speculation-stack)` is `'()`, so `tms-read` returns `base` directly. Zero traversal, zero filtering — the common case pays no TMS overhead beyond a `null?` check.

#### 3.2.2 Commit Semantics: Lazy Base Promotion

✓ DESIGN DECISION (D.5)

When speculation succeeds and commits, the speculative value is **promoted to `base`** while **keeping the branch entry for provenance**.

```
;; On commit of assumption H1 with value V:
;; Before: (tms-cell-value old-base {H1 → V, H4 → String})
;; After:  (tms-cell-value V       {H1 → V, H4 → String})
```

- The branch entry `{H1 → V}` remains — it records that V came from speculation H1. Full provenance preserved.
- `base` is updated to V — future depth-0 reads hit `base` directly. Micro-optimization without losing provenance.
- The invariant: `base` always equals what you'd get by traversing the believed branches from root. It's a materialized view, not a separate source of truth. The tree is the source of truth; `base` is a cache.

Cost: one extra CHAMP update at commit time. Commits are rare compared to reads (one commit per successful speculation, vs thousands of reads during the speculation thunk).

#### 3.2.3 Retraction Semantics: Data Preserved, Path Blocked

Retraction of assumption H1 means "don't follow branch H1 in reads." The branch entry is never deleted. This is fundamental for provenance:

- **Retracted branches are negative knowledge** — proof certificates of failed paths
- **Nogoods reference retracted assumptions** — if the branch data were deleted, nogoods would point to nothing
- **Tools can enumerate all branches** (including retracted) to show the full speculation tree
- **The type checker only follows believed branches** — retracted branches are invisible on the hot path

Retraction cost: O(1) — update the believed set in the ATMS control plane. No tree modification needed.

#### 3.2.4 ATMS Control Plane

The ATMS tracks metadata that must persist across rollback:
- **Assumptions registry**: `hasheq assumption-id → assumption` — which hypotheses exist
- **Nogoods**: `(listof hasheq)` — known-inconsistent assumption sets (proof certificates of failure)
- **Believed set**: `hasheq assumption-id → #t` — current worldview
- **Next-assumption counter**: monotonic Nat

✓ DESIGN DECISION: **ATMS metadata stays in `current-command-atms` (control plane). TMS cell values live in the network (data plane).**

The control plane is append-only for assumptions and nogoods (they only grow), and mutated for believed (changes on assume/retract). It does not need snapshot/restore — it's the accumulation layer for error tracking, provenance, and GDE.

The data plane (TMS cell values in network cells) snapshots with the network. Both rollback mechanisms coexist during implementation:
- **Network-box restore** (imperative): works for TMS cells since they're in the network
- **TMS retraction** (structural): marks branches as disbelieved without box restore

Belt-and-suspenders through implementation phases; cleanup in Track 6 after proving TMS retraction sufficient.

#### 3.2.5 TMS Cell Merge Function

```
(define (merge-tms-cell old new)
  (cond
    [(eq? old 'infra-bot) new]
    [(eq? new 'infra-bot) old]
    [(and (tms-cell-value? old) (tms-cell-value? new))
     ;; Merge trees: union branches, recurse on shared keys
     (define merged-branches
       (for/fold ([acc (tms-cell-value-branches old)])
                 ([(k v) (in-hash (tms-cell-value-branches new))])
         (define existing (hash-ref acc k #f))
         (hash-set acc k
           (cond
             [(not existing) v]
             [(and (tms-cell-value? existing) (tms-cell-value? v))
              (merge-tms-cell existing v)]  ;; recursive merge
             [else v]))))  ;; leaf: latest write wins
     (tms-cell-value (tms-cell-value-base new) merged-branches)]
    [else new]))
```

The merge is recursive — matching the tree structure. Per-branch, latest write wins (same assumption can't produce two different values at the same depth). Cross-branch, the tree preserves both — worldview determines which is visible.

**Note on monotonicity**: Within a single speculation branch, meta solving is monotone (unsolved→solved, never reversed). Across branches, TMS handles non-monotonicity structurally (retraction = disbelief, not deletion).

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

#### 3.3.4 ID-Map: Assumption-Tagged for Provenance

✓ DESIGN DECISION (D.5): **ID-map entries get assumption tags**, same pattern as per-meta cells. Provenance-by-default: every piece of infrastructure should be observable and explainable, even if hot paths optimize around it.

The id-map (`meta-id → cell-id`) records which cell was created for which meta. With assumption tags, `prop-meta-id->cell-id` becomes worldview-aware: a meta created during retracted speculation H2 is only visible if H2 is believed.

**Implementation**: The id-map becomes a TMS cell in the network (same recursive CHAMP structure). At depth 0, `tms-read` returns `base` directly — single `null?` check, negligible overhead. During speculation, lookups follow the stack (O(d) CHAMP lookups, d=1-2).

**Provenance benefit**: Tools can query "this meta was created during speculation H2, which failed" — the assumption tag on the id-map entry connects meta creation to speculation context. Without assumption tags, orphaned id-map entries are invisible state that breaks the observability promise.

**Cost on hot path**: `prop-meta-id->cell-id` is called on every `meta-solved?`/`meta-solution`. The depth-0 fast path (return `base`) keeps the common-case cost to a `null?` check beyond what exists today.

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
  ;; 2. Push assumption onto speculation stack
  (define prev-stack (current-speculation-stack))
  ;; 3. Snapshot for belt-and-suspenders (Phases 2-5; Track 6 removes)
  (define saved-net (unbox (current-prop-net-box)))
  ;; 4. Run thunk under assumption (stack-based: reads/writes navigate tree)
  (define result
    (parameterize ([current-speculation-stack (cons hyp-id prev-stack)])
      (thunk)))
  (cond
    [(success? result)
     ;; Commit: promote base for committed TMS cells (lazy base promotion)
     result]
    [else
     ;; 5a. Retract assumption (control plane: H removed from believed)
     (set-box! atms-box (atms-retract (unbox atms-box) hyp-id))
     ;; 5b. Restore network snapshot (belt-and-suspenders for monotonic cells)
     (set-box! (current-prop-net-box) saved-net)
     ;; 5c. Record failure (as today)
     (record-speculation-failure! label hyp-id ...)
     #f]))
```

**Transitional**: During Phase 2, both TMS retraction AND network-box restore are used. This is belt-and-suspenders: TMS handles per-meta cells, network restore handles monotonic cells (constraints, registries). Once all mutable speculation state is in TMS cells, the network restore becomes redundant for speculation (but may remain for other purposes).

#### 3.4.2 Nested Speculation

Nesting is handled by the speculation stack and recursive tree structure. Each nesting level pushes its assumption onto the stack. Reads/writes navigate the tree to the stack's depth.

**Example**: union-of-unions `check e (union (union A B) C)`:

1. Outer: push H1. Stack = `(H1)`. Cell tree: `(tms-cell-value ⊥ {})`
2. Inner: push H2. Stack = `(H2 H1)`. Thunk solves meta M1 → tree: `(tms-cell-value ⊥ {H1 → (tms-cell-value ⊥ {H2 → Nat})})`
3. Inner fails → retract H2, pop stack back to `(H1)`. H2's branch preserved in tree (negative knowledge) but read navigates only through H1, finding ⊥ (no write at H1 leaf level)
4. Inner: push H3. Stack = `(H3 H1)`. Thunk solves M1 → tree: `(tms-cell-value ⊥ {H1 → (tms-cell-value ⊥ {H2 → Nat, H3 → Int})})`
5. Inner succeeds → H3 stays, base promoted: `{H1 → (tms-cell-value Int {H2 → Nat, H3 → Int})}`
6. Outer succeeds → H1 stays, base promoted: `(tms-cell-value Int {H1 → (tms-cell-value Int {H2 → Nat, H3 → Int})})`

**Final tree state** (complete provenance):
```
M1: (tms-cell-value
      Int                                    ;; base: committed result
      {H1 → (tms-cell-value
               Int                           ;; H1's committed result
               {H2 → Nat                    ;; ❌ retracted: tried Nat, failed
                H3 → Int})})                 ;; ✅ believed: tried Int, succeeded
```

The tree preserves the full speculation history. H2's branch (Nat) is the proof certificate that "trying Nat under the inner-left speculation failed." Tools can enumerate all branches; the type checker only follows the believed path.

The sub-failure extraction (Phase D2) continues to work: inner failures are captured as sub-failures of the outer failure, cross-referencing the tree branches.

#### 3.4.3 Worked Example: Simple Union Speculation

**Scenario**: `check expr against (union (Map String Int) (Map String String))`

**Before Track 4 (current):**
1. `save-meta-state` → snapshot 6 boxes
2. `check expr (Map String Int)` → `fresh-meta` M1 in meta-info CHAMP + cell; `solve-meta` M1; type fails
3. `restore-meta-state!` → restores all 6 boxes (M1 gone from meta-info; network cells rolled back)
4. `check expr (Map String String)` → `fresh-meta` M2, succeeds
5. Commit — M2 persists

**After Track 4:**
1. `atms-assume` H1. Stack = `(H1)`. M1 TMS cell: `(tms-cell-value ⊥ {})`
2. `solve-meta` M1 under `(H1)` → M1 tree: `(tms-cell-value ⊥ {H1 → Int})`; type fails
3. `atms-retract` H1. Nogood {H1} recorded. M1's tree unchanged but read at stack `()` returns ⊥
4. Network-box restore (belt-and-suspenders) — restores monotonic cells
5. `atms-assume` H2. Stack = `(H2)`. `fresh-meta` M2 → TMS cell: `(tms-cell-value ⊥ {H2 → String})`
6. M2 succeeds → base promoted: `(tms-cell-value String {H2 → String})`
7. H1 retracted, M1's tree preserved (provenance: "tried Int, failed")
8. Nogood {H1} available for GDE error chains and learned-clause pruning

### 3.5 Phase Structure

#### Phase 0: Performance Baseline + Profiling

- Acceptance file: `examples/2026-03-16-track4-acceptance.prologos` (user-managed)
- Baseline: full suite timing, cell count metrics
- **Profiling**: Instrument `meta-solved?`/`meta-solution` call frequency and cost. Measure TMS filtering overhead via microbenchmark (create TMS cell, write 1-3 entries, filter by worldview).
- Pre-flight: verify all 6 call sites with grep, confirm no new ones since Track 3

#### Phase 1: TMS Cell Integration into prop-network

**Scope**: Add TMS cell support to the propagator network. No meta cells converted yet — this is pure infrastructure.

**Files**: `propagator.rkt` or new `tms-cell.rkt`, `infra-cell.rkt`

1. Define `tms-cell-value` struct (base + branches hasheq) — the recursive CHAMP tree node
2. Add `merge-tms-cell` merge function (recursive tree merge, per-branch latest-write-wins)
3. Add `net-new-tms-cell` factory: creates a cell with `merge-tms-cell` and initial `(tms-cell-value initial-value (hasheq))`
4. Add `tms-read`: navigate tree via speculation stack, return value at current depth (O(d) CHAMP lookups)
5. Add `tms-write`: nested CHAMP insert at current stack depth (O(d) CHAMP updates)
6. Add `current-speculation-stack` parameter (`(listof assumption-id)`, `'()` = not speculating)
7. Unit tests for: depth-0 read/write, depth-1 branch creation, nested depth-2, retraction (branch preserved but read returns base), commit (base promotion)

**Verification**: Unit tests for TMS cell operations. No production code changes — existing behavior unchanged.

#### Phase 2: Per-Meta Type Cells → TMS Cells

**Scope**: Convert existing per-meta type cells from monotonic to TMS. This is the core speculation change.

**Files**: `metavar-store.rkt`, `driver.rkt` (cell creation in `elab-fresh-meta`)

1. `elab-fresh-meta` creates TMS cells instead of monotonic cells (initial value: `(tms-cell-value type-bot (hasheq))`)
2. `solve-meta-core!` writes through `tms-write` with `current-speculation-stack`
3. `meta-solved?` reads through `tms-read` with `current-speculation-stack` — at depth 0, returns `base` directly
4. `meta-solution` reads through `tms-read`
5. Update `with-speculative-rollback` to push/pop `current-speculation-stack` and use TMS retraction on failure (retain network-box restore as belt-and-suspenders)
6. On successful commit: lazy base promotion — update `base` to committed value while keeping branch entry for provenance

**Critical invariant**: At speculation depth 0, all TMS reads must return the same values as current monotonic reads. This is verified by the full test suite (which doesn't exercise manual speculation).

**Risk**: This is the highest-risk phase. `meta-solved?` and `meta-solution` are the hottest operations. TMS filtering adds cost. Mitigated by: (a) depth-0 fast path (skip filtering), (b) small support sets (O(1) subset check), (c) profile before/after.

**Contingency**: If TMS read overhead >15%: the recursive CHAMP already minimizes overhead (O(d) indexed lookups vs O(k) scan), but we could add a per-cell read cache invalidated on write. Alternatively, investigate whether the overhead is in the CHAMP lookups or the struct allocation/matching.

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
| `propagator.rkt` or new `tms-cell.rkt` | 1 | `tms-cell-value` struct (recursive CHAMP tree), `tms-read`/`tms-write`, merge |
| `metavar-store.rkt` | 2, 3, 4 | TMS cell creation/read/write for metas; registry refactor; save/restore simplification |
| `driver.rkt` | 2 | `elab-fresh-meta` creates TMS cells |
| `elab-speculation-bridge.rkt` | 2, 4 | Speculation stack push/pop, TMS retraction, base promotion on commit, save/restore simplification |
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
| TMS read overhead on `meta-solved?`/`meta-solution` | Low-Medium | High | Depth-0 returns `base` (null? check). In speculation: O(d) CHAMP lookups vs current O(1) — d=1-2. Profile before/after Phase 2. |
| TMS cell value growth (many entries per cell) | Low | Medium | Entries bounded by speculation depth × branches; typical: 1-3 |
| ATMS believed set update cost | Low | Low | Set is small (bounded by speculation depth); hash-subset? is O(k) for k=set size |
| Orphaned meta-registry entries | Low | Low | Harmless — unsolved metas with invisible cells; filtered by `all-unsolved-metas` |
| Belt-and-suspenders divergence (TMS and box-restore disagree) | Medium | Medium | Assertion checking in Phase 2: verify TMS-retracted state matches box-restored state |
| Level/mult/session cell count explosion | Low | Low | These metas are few per command (dozens, not thousands) |
| Interaction with batch-worker isolation | Low | Medium | batch-worker saves/restores parameters; network box is already in that list |
| ATMS state synchronization | Low | Low | Control plane stays in `current-command-atms` (intentionally outside snapshot). Data plane (TMS cells) in network (snapshot). Two-level semantics preserved. |

### 4.3 Open Questions

1. **What happens to `batch-worker.rkt`?** After Phase 4, it saves/restores the network box (1 box). This is mechanical. The `current-command-atms` parameter also needs save/restore for worker isolation. The `current-speculation-stack` parameter resets to `'()` per worker (workers don't inherit speculation context).

2. **Can Phase 5 (learned clauses) prune enough to be measurable?** Depends on speculation patterns. Union-of-unions creates the most speculation. Profile in Phase 0 to count how often the same branch patterns recur.

3. **Should base promotion on commit be eager or lazy?** Current design: eager (update `base` immediately on commit). Alternative: lazy (only update `base` when the outer-most speculation commits). Eager is simpler and gives better depth-0 read performance. Lazy avoids unnecessary base updates for intermediate commits in nested speculation. Start eager; revisit if profiling shows commit overhead.

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

### D.5: Recursive CHAMP Cells + Provenance-by-Default (2026-03-16)
Refinement of TMS cell representation and provenance design principles. Key decisions:
1. **Recursive CHAMP tree** replaces flat list + backpointers. Data structure shape mirrors domain shape (speculation nests → data nests). Hot path: O(d) indexed CHAMP traversal via speculation stack, not O(k) scan with subset checks. Tooling queries: O(1) per assumption via `hash-ref`.
2. **Speculation stack** (`current-speculation-stack`) replaces `current-speculation-assumption` + `current-speculation-depth`. Single parameter, pushed/popped by `with-speculative-rollback`. Reads/writes navigate tree by following the stack.
3. **Lazy base promotion on commit** — `base` field updated to committed value (micro-optimization for future depth-0 reads) while branch entry preserved (provenance: "this value came from speculation H").
4. **ID-map assumption-tagged** — provenance-by-default design principle. Every piece of infrastructure should be observable and explainable. ID-map entries track which speculation created which meta→cell mapping.
5. **Retraction preserves data** — retracted branches are never deleted. They're negative knowledge (proof certificates of failed paths). Tools enumerate all branches; type checker follows only believed path.
6. **Belt-and-suspenders through all implementation phases**, cleanup in Track 6 after proving TMS retraction correct across full test suite.
7. **Provenance-by-default as design principle** — observability/correctness/explainability over micro-optimization. Infrastructure must support self-hosting, proof techniques, tooling, and error reporting. Hot paths optimize via fast paths (depth-0 base return), not by dropping provenance.

---

## §9. Post-Implementation Review

*Reference to standalone PIR document (to be created after implementation).*
