# Track 6: Driver Simplification + Cleanup — Stage 2/3 Design

**Created**: 2026-03-16
**Status**: DESIGN (D.1+ — revised after initial critique)
**Depends on**: Track 3 ✅ (Cell-Primary Registries), Track 4 ✅ (ATMS Speculation), Track 5 ✅ (Global-Env + Module Networks)
**Enables**: Track 7 (QTT Multiplicity Cells)
**Master roadmap**: `2026-03-13_PROPAGATOR_MIGRATION_MASTER.md` Track 6
**Prior art**: Track 3 PIR (elaboration guard discovery), Track 4 PIR (dual-write coherence), Track 5 PIR (belt-and-suspenders retirement, test infrastructure divergence)
**Absorbed deferrals**: Track 3 Phase 6, Track 4 Phase 4, Track 5 rename + dual-write removal

---

## Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| D.1 | Initial design document | ✅ | This document |
| D.1+ | Design critique + refinement | ✅ | Data orientation, ordering, retirement gate, id-map cell, test-support migration |
| D.2 | External critique + rework | ⬜ | |
| D.3 | Self-critique (principle alignment) | ⬜ | |
| 0 | Performance baseline + acceptance file | ⬜ | |
| 1a | id-map → infrastructure cell (3→2 box) | ⬜ | Workstream A — early win |
| 1b | meta-info `#:mutable` removal (already write-once in practice) | ⬜ | Workstream A |
| 1c | constraint status → functional CHAMP updates | ⬜ | Workstream A — data orientation |
| 1d | `all-unsolved-metas` → infrastructure cell | ⬜ | Workstream A |
| 2 | Speculation stack push activation | ⬜ | Workstream A |
| 3 | Commit-on-success machinery | ⬜ | Workstream A |
| 4 | TMS retraction (replace network-box restore) | ⬜ | Workstream A |
| 5 | save/restore 2→1 box + belt-and-suspenders retirement | ⬜ | Workstream A — concrete retirement gate |
| 6 | batch-worker.rkt migration to cell-based state | ⬜ | Workstream B |
| 7a | test-support.rkt → network-based isolation (shadow phase) | ⬜ | Workstream B |
| 7b | Dual-write elimination: macros.rkt (23 registries) | ⬜ | Workstream B |
| 7c | Dual-write elimination: warnings.rkt (3) + global-constraints.rkt (2) | ⬜ | Workstream B |
| 7d | Dual-write elimination: global-env.rkt | ⬜ | Workstream B |
| 8 | Elaboration guard + callback cleanup | ⬜ | Workstream B |
| 9 | `current-global-env` → `current-prelude-env` rename | ⬜ | Workstream B |
| 10 | Driver simplification | ⬜ | Workstream B |
| 11 | Performance validation + PIR | ⬜ | |

---

## §1. Problem Statement

### 1.1 Current State

After five tracks of propagator migration, Prologos has a fully-functional cell-primary architecture with per-module networks, TMS cells for speculation, ATMS for dependency tracking, and cross-module dependency edges. But the system carries significant transitional debt:

- **Dual-write overhead**: All 28+ registries write to both parameters AND cells. The cell path is authoritative during elaboration; the parameter path exists solely for `batch-worker.rkt` isolation and `save-meta-state` compatibility.
- **3-box save/restore**: `save-meta-state` snapshots three immutable CHAMPs (network + id-map + meta-info). The network snapshot already captures all cell state; id-map and meta-info are vestigial.
- **Elaboration guards**: Two boolean parameters (`current-macros-in-elaboration?`, `current-narrow-in-elaboration?`) gate cell reads — readers check whether they're inside `process-command` before trusting cells. This was the right de-risking pattern (Track 3 PIR §4.1), but with Track 5's per-module persistent networks, all contexts now have valid cells.
- **Vestigial callback parameters**: Three retry callbacks (`current-retry-trait-resolve`, `current-retry-hasmethod-resolve`, `current-retry-unify`) break circular deps between `metavar-store.rkt` and `driver.rkt`. These are superseded by Track 2's stratified quiescence reactive resolution.
- **266-reference rename pending**: `current-global-env` should be `current-prelude-env` to reflect its actual semantics (it holds prelude definitions, not the full global environment which is now cell-based).

### 1.2 What Track 6 Achieves

- **Single write path** (cells only) for all registries — parameters become read-only historical API
- **1-box save/restore** — network snapshot is the sole source of truth for speculation
- **No elaboration guards** — every context has valid cells; the guard parameters are removed
- **Clean driver** — per-command `parameterize` block shrinks from ~30 parameters to ~5
- **TMS retraction** — speculation failure retracts assumptions rather than restoring entire network snapshot, enabling incremental rollback

### 1.3 Why Now

Track 5's per-module persistent networks resolved the last structural blocker. Before Track 5, module loading ran without a network (`current-global-env-prop-net-box = #f`), requiring the parameter fallback path. Now every module has a `module-network-ref` with its own cells. The dual-write path has no remaining consumers that can't be migrated.

---

## §2. Infrastructure Audit

### 2.1 Dual-Write Registries

All registries follow the same dual-write pattern established in the Migration Sprint:

```racket
;; Pattern: write to cell (if available) AND parameter (always)
(define (register-X! name val)
  (when (current-X-cell-id)
    (net-write! (current-X-cell-id)
                (hash-set (cell-value ...) name val)
                merge-X))
  (current-X (hash-set (current-X) name val)))
```

**macros.rkt** — 23 registries:
- `current-preparse-registry`, `current-spec-store`, `current-propagated-specs`
- `current-ctor-registry`, `current-type-meta`, `current-subtype-registry`
- `current-coercion-registry`, `current-trait-registry`, `current-trait-laws`
- `current-impl-registry`, `current-param-impl-registry`, `current-bundle-registry`
- `current-specialization-registry`, `current-capability-registry`
- `current-property-store`, `current-functor-store`
- `current-user-precedence-groups`, `current-user-operators`
- `current-macro-registry`
- `current-schema-store`, `current-selection-store`, `current-session-type-store`
- `current-strategy-registry`, `current-process-registry`

**warnings.rkt** — 3 accumulators:
- `current-coercion-warnings`, `current-deprecation-warnings`, `current-capability-warnings`

**global-constraints.rkt** — 2 registries:
- `current-narrow-constraints`, `current-narrow-var-constraints`

### 2.2 Consumers Blocking Dual-Write Removal

| Consumer | Reads Parameters? | Blocking? | Resolution |
|----------|------------------|-----------|------------|
| `save-meta-state` / `restore-meta-state!` | No (reads network box) | No | Already cell-based via network CHAMP snapshot |
| `batch-worker.rkt` | Yes — saves/restores 26 parameter values | **Yes** | Phase 6: migrate to cell-based per-file state |
| Module loading | Was parameter-only | **Resolved by Track 5** | Per-module `module-network-ref` provides cells |
| `test-support.rkt` | Yes — `parameterize` block for test isolation | **Yes** | Phase 7: update alongside registry changes |

### 2.3 Elaboration Guards

Two parameters create a structural boundary between elaboration (cells valid) and non-elaboration (parameter fallback):

- `current-macros-in-elaboration?` (macros.rkt:488) — checked by 23 cell readers
- `current-narrow-in-elaboration?` (global-constraints.rkt:86) — checked by 2 cell readers

Pattern in each reader:
```racket
(define (read-X)
  (cond
    [(and (current-macros-in-elaboration?) (current-X-cell-id))
     (hash-ref (net-read (current-X-cell-id)) key 'not-found)]
    [else (hash-ref (current-X) key 'not-found)]))
```

**Track 3 PIR discovery**: Guards exist because `register-macros-cells!` uses direct mutation (`(current-X val)`) rather than `parameterize`. Without the guard, cell readers outside elaboration see stale data from a previous command's cells.

**Track 5 resolution**: Per-module persistent networks mean every context now has valid cells. But `register-*-cells!` still uses direct mutation for cell-id parameters — removing guards requires either: (a) confirming that stale cell-id values never cause reads to see wrong data outside elaboration, or (b) migrating cell-id registration to `parameterize` scope.

### 2.4 save-meta-state / restore-meta-state!

Location: `metavar-store.rkt:1821–1835`

Current 3-box pattern:
```racket
(define (save-meta-state)
  (list (unbox (current-prop-net-box))       ;; box 1: network CHAMP
        (unbox (current-meta-id-map-box))    ;; box 2: id-map CHAMP
        (unbox (current-meta-info-box))))    ;; box 3: meta-info CHAMP

(define (restore-meta-state! saved)
  (set-box! (current-prop-net-box)    (first saved))
  (set-box! (current-meta-id-map-box) (second saved))
  (set-box! (current-meta-info-box)   (third saved)))
```

Used by `with-speculative-rollback` at 5 call sites (4 in `typing-core.rkt`, 1 in `qtt.rkt`). O(1) capture and restore via immutable CHAMP structural sharing.

**Target**: 1-box pattern (network CHAMP only). Requires:
1. id-map moves into network (or becomes unnecessary after TMS retraction)
2. meta-info becomes write-once (status tracked by TMS cell value, not mutable field)

### 2.5 meta-info Struct — Already Write-Once in Practice

Location: `metavar-store.rkt:200–209`

```racket
(struct meta-info (id ctx type status solution constraints source)
  #:transparent #:mutable)
```

Declared `#:mutable`, but **no code calls `set-meta-info-status!` or `set-meta-info-solution!`** (zero grep hits across the entire codebase). The actual `solve-meta-core!` (line 1210–1213) already does functional update:

```racket
(define updated (meta-info id (meta-info-ctx info) (meta-info-type info)
                            'solved solution
                            (meta-info-constraints info) (meta-info-source info)))
(set-box! mi-box (champ-insert (unbox mi-box) (prop-meta-id-hash id) id updated))
```

This creates a new immutable `meta-info` value and inserts it into the CHAMP. The `#:mutable` annotation is vestigial. Phase 1b is therefore trivial: remove `#:mutable` and confirm compilation.

**The actual data-orientation gap is in `constraint`** (see §2.8).

### 2.8 constraint Struct — Genuine In-Place Mutation

Location: `metavar-store.rkt:218–227`

```racket
(struct constraint (cid lhs rhs ctx source status cell-ids)
  #:transparent #:mutable)
```

Unlike `meta-info`, the constraint struct **is genuinely mutated in place** (~10 call sites):

- `set-constraint-status!` — used in `retry-constraints-for-meta!` (lines 641, 645), `retry-constraints-via-cells!` (lines 669, 672), `retry-constraints-for-typearg!` (lines 777, 780), and `unify.rkt` (lines 754, 758) for the `'postponed → 'retrying → 'solved/'failed/'postponed` state machine
- `set-constraint-cell-ids!` — used in `postpone-constraint!` (line 623)

The status mutation serves as a re-entrancy guard: setting `'retrying` prevents recursive retry loops, then resetting to `'postponed` if the retry didn't resolve. This is a side-effect-based protocol that doesn't compose with TMS branching — during speculation, constraint status mutations happen unconditionally at depth 0, invisible to the branch/retract lifecycle.

**Data-oriented resolution**: Convert constraint status transitions to CHAMP functional updates (create new constraint, insert into constraint store cell). The re-entrancy guard becomes a value check on the store rather than in-place mutation. This aligns the constraint subsystem with TMS branching — speculation can snapshot and restore constraint state as part of the network.

### 2.6 Callback Parameters ("Dirty Flags")

Three callback parameters in `metavar-store.rkt` break circular dependencies with `driver.rkt`:

| Parameter | Purpose | References | Superseded by |
|-----------|---------|------------|---------------|
| `current-retry-trait-resolve` | Trigger trait constraint re-resolution | 14 refs | Track 2 stratified quiescence |
| `current-retry-hasmethod-resolve` | Trigger HasMethod constraint re-resolution | ~8 refs | Track 2 stratified quiescence |
| `current-retry-unify` | Trigger unification retry | ~6 refs | Track 2 stratified quiescence |

These are event callbacks, not dirty flags. They were the pre-propagator mechanism for "something changed, re-check constraints." Track 2's reactive resolution handles this automatically via cell wakeup.

### 2.7 batch-worker.rkt State Management

Location: `tools/batch-worker.rkt:67–225`

**Phase 1** (lines 67–99): Saves 26 parameter values post-prelude as "ready state":
- 19 from macros.rkt (preparse, spec-store, ctor, type-meta, subtype, coercion, trait, trait-laws, impl, param-impl, bundle, specialization, capability, property, functor, user-precedence-groups, user-operators, macro, propagated-specs)
- 7 from namespace.rkt (module-registry, ns-context, lib-paths, loading-set, module-loader, spec-propagation-handler, foreign-handler)
- 1 from global-env.rkt (global-env)

**Phase 2** (lines 173–225): Per-file `parameterize` restores all 26 to ready state, plus:
- Fresh `(hasheq)` for definition-cells-content, definition-cell-ids, definition-dependencies
- Fresh `'()` for cross-module-deps
- `#f` for all prop-net-boxes and cell-ids
- Fresh `(make-hasheq)` for mult-meta-store
- `#t` for current-emit-error-diagnostics
- `file-dir` for current-load-relative-directory
- Captured I/O ports

---

## §3. Two Workstreams

Track 6 has two workstreams with different risk profiles. **Workstream A executes first** — it delivers the architectural foundation (TMS retraction, data-oriented state) that makes every Workstream B cleanup trivially justified. This follows the pattern established across Tracks 3–5: do the hard thing first, mechanical cleanup follows naturally.

### Workstream A: Data Orientation + TMS Retraction Pipeline (High Risk)

The prerequisite chain, expanded from Track 4 Phase 4 deferral to include data-orientation alignment:

```
Phase 1a: id-map → infrastructure cell (3→2 box, early win)
    ↓
Phase 1b: meta-info #:mutable removal (vestigial — already write-once)
    ↓
Phase 1c: constraint status → functional CHAMP updates (genuine data-orientation fix)
    ↓ (eliminates all in-place mutation in meta/constraint subsystem)
Phase 1d: all-unsolved-metas → infrastructure cell (incremental tracking)
    ↓
Phase 2: speculation stack push
    ↓ (routes cell writes to TMS branches)
Phase 3: commit-on-success
    ↓ (promotes branch values to base on success)
Phase 4: TMS retraction
    ↓ (replaces network-box restore on failure)
Phase 5: save/restore 2→1 box + belt-and-suspenders retirement
```

**Critical ordering constraint** (Track 4 Phase 2c): All in-place mutations (meta-info, constraint) must be eliminated (Phases 1a–1d) before speculation stack push (Phase 2). If stack push routes TMS writes to branches but CHAMP mutations still happen at depth 0, the two views diverge. Data-oriented conversion is therefore a prerequisite for TMS, not a nice-to-have.

**Belt-and-suspenders strategy** (Track 5 PIR lesson): During Phases 2–4, keep network-box restore as a fallback alongside TMS retraction.

**Concrete retirement gate** (Correct by Construction): Phase 5 is the defined retirement point for the secondary path. The gate criteria:
- 0 divergences between TMS retraction and network-box restore across full suite + batch mode
- Acceptance file passes at L3 with 0 errors
- Speculation stats (hypotheses, nogoods, pruning) match Phase 0 baseline

Phase 5 cannot proceed until Phase 4's belt-and-suspenders validation passes this gate. The secondary path is removed as a defined step — not gradually deprecated, not left as optional dead code.

### Workstream B: Dual-Write Elimination + Cleanup (Low-Medium Risk)

1. **Phase 6**: `batch-worker.rkt` migration — parameter save/restore → cell-based per-file state
2. **Phase 7a**: `test-support.rkt` → network-based isolation (shadow phase with dual-path validation)
3. **Phase 7b–d**: Dual-write removal for all 28+ registries
4. **Phase 8**: Elaboration guard removal + callback parameter cleanup
5. **Phase 9**: `current-global-env` → `current-prelude-env` rename (266 references)
6. **Phase 10**: Driver `parameterize` simplification

### Workstream Ordering Rationale

**Workstream A first, then B.** Every prior track followed this pattern — architectural decisions first, mechanical cleanup second. The batch-worker migration (B.6) is mechanically independent but doesn't teach us anything that helps with TMS. Conversely, completing TMS retraction gives absolute confidence that the cell path is the sole authority, which makes every subsequent dual-write removal trivially justified.

The rename (Phase 9) is purely mechanical and has no ordering constraints — it could be done anytime after Phase 1b.

---

## §4. Phase Design

### Phase 0: Performance Baseline + Acceptance File

**Goal**: Establish Track 6 baseline and write acceptance `.prologos` file.

**Acceptance file**: `examples/2026-MM-DD-track6-acceptance.prologos` — broad exercise of Prologos features (speculation, modules, traits, pattern matching, generic arithmetic) as a regression safety net. Run before and after each phase.

**Baseline**: Record full suite wall time, test count, speculation stats (hypotheses, nogoods, pruning).

### Phase 1a: id-map → Infrastructure Cell (Workstream A)

**Goal**: Move the meta-id → cell-id mapping from a separate box into an infrastructure cell in the network. Immediate win: `save-meta-state` drops from 3 boxes to 2.

**Current**: `current-prop-id-map-box` is a separate `(box champ)` alongside the network box. Written during `fresh-meta` (meta creation), read during `solve-meta!` (to find cell-id for a meta). Both happen during elaboration, so always in network context — no guard issues.

**Target**: The id-map becomes a cell in the network (similar to Track 3's registry cells). `save-meta-state` captures 2 boxes (network + meta-info) instead of 3. The network CHAMP snapshot automatically includes the id-map cell.

**Changes**:
- Add `current-prop-id-map-cell-id` parameter (or use a well-known key)
- `fresh-meta` writes to id-map cell via `net-write!` instead of `set-box!`
- `prop-meta-id->cell-id` reads from the id-map cell via `net-read` instead of `unbox`
- `save-meta-state` drops the id-map box from its snapshot

**Risk**: Low — id-map is read/written only during elaboration where networks are always available.

**Test strategy**: Full suite. save/restore behavior unchanged (network snapshot captures id-map cell).

### Phase 1b: meta-info `#:mutable` Removal (Workstream A)

**Goal**: Remove vestigial `#:mutable` annotation from `meta-info` struct.

**Code audit finding**: `solve-meta-core!` already creates new `meta-info` values via functional CHAMP insert (line 1210–1213). Zero call sites use `set-meta-info-status!` or `set-meta-info-solution!`. The `#:mutable` annotation is dead weight.

**Change**: Remove `#:mutable` from the struct declaration. Confirm `raco make driver.rkt` succeeds (would catch any hidden setter usage).

**Risk**: Trivial — no behavioral change. This is removing dead capability.

**Test strategy**: Compilation check + full suite (should be bit-identical behavior).

### Phase 1c: constraint Status → Functional CHAMP Updates (Workstream A)

**Goal**: Eliminate in-place mutation of constraint status. Convert the `'postponed → 'retrying → 'solved/'failed/'postponed` state machine to create new constraint values in the constraint store cell, aligning with data-oriented design.

**Current** (~10 mutation sites):
```racket
;; Re-entrancy guard via in-place mutation
(set-constraint-status! c 'retrying)
(retry-fn c)
(when (eq? (constraint-status c) 'retrying)
  (set-constraint-status! c 'postponed))
```

**Target**:
```racket
;; Re-entrancy guard via value check on store
(define store (read-constraint-store))
(define updated-c (struct-copy constraint c [status 'retrying]))
(write-constraint-store! (hash-set store (constraint-cid c) updated-c))
(retry-fn updated-c)
;; Read fresh from store — retry-fn may have written 'solved/'failed
(define post-c (hash-ref (read-constraint-store) (constraint-cid c)))
(when (eq? (constraint-status post-c) 'retrying)
  (write-constraint-store! (hash-set (read-constraint-store) (constraint-cid c)
                                      (struct-copy constraint post-c [status 'postponed]))))
```

**Key insight**: The re-entrancy guard works by value identity — checking whether the constraint is still in the state we set it to. This composes with functional updates: read from store, check status, write back. No mutation needed.

**Consumers to update**:
- `retry-constraints-for-meta!` (metavar-store.rkt:633–645)
- `retry-constraints-via-cells!` (metavar-store.rkt:652–672)
- `retry-constraints-for-typearg!` (metavar-store.rkt:~770–780)
- `unify.rkt:754–758` (marking constraints solved/failed)
- `postpone-constraint!` (metavar-store.rkt:~620, `set-constraint-cell-ids!`)

**Also remove `#:mutable` from `constraint` struct** after all mutation sites are converted.

**Risk**: Medium — touches the constraint retry hot path. The state machine must behave identically.

**Test strategy**: Full suite + acceptance file. Constraint retry counts must match Phase 0 baseline. Speculation stats unchanged.

### Phase 1d: `all-unsolved-metas` → Infrastructure Cell (Workstream A)

**Goal**: Replace the O(n) CHAMP scan in `all-unsolved-metas` with an incrementally-maintained infrastructure cell.

**Current** (metavar-store.rkt:1839–1846):
```racket
(define (all-unsolved-metas)
  (champ-fold (unbox mi-box)
              (lambda (k v acc)
                (if (eq? (meta-info-status v) 'unsolved)
                    (cons v acc)
                    acc))
              '()))
```

**Target**: An "unsolved metas set" infrastructure cell, maintained incrementally:
- `fresh-meta` adds the meta-id to the set (cell write)
- `solve-meta-core!` removes the meta-id from the set (cell write)
- `all-unsolved-metas` reads the set (cell read) — O(1)

This matches the infrastructure cell pattern from Track 3. The cell participates in network snapshots, so speculation automatically captures/restores the unsolved set.

**Risk**: Low — the cell is written at exactly two sites (creation and solution). Correctness is easy to verify: the set must equal the CHAMP scan result at all times.

**Test strategy**: Dual-path validation during phase: run both old CHAMP scan and new cell read, assert identical results across full suite. Remove old path after 0 divergences.

### Phase 2: Speculation Stack Push Activation (Workstream A)

**Goal**: Activate the speculation stack (deferred since Track 4 Phase 2). Cell writes during speculation go to TMS branches rather than the base network.

**Current state**: `current-speculation-stack` exists (defined in `propagator.rkt`, re-exported from `elab-speculation-bridge.rkt`) but is never pushed. All cell writes go to depth 0 (base).

**Mechanism**:
1. `with-speculative-rollback` pushes an assumption onto `current-speculation-stack` before running the thunk
2. `net-write!` checks stack depth; if > 0, writes go to the current TMS branch
3. `tms-read` at depth 0 still returns the base value (fast path)

**Critical**: Reads at depth 0 must NOT see branch values. The TMS cell `tms-read` function already handles this (Track 4 Phase 1 implemented depth-aware reads). What's new is that `net-write!` during speculation actually routes to branches.

**Belt-and-suspenders**: Keep network-box restore as fallback. After thunk execution, compare TMS branch values against network-box diff — log divergences.

**Risk**: High — changes what speculation sees. Any error in TMS write routing breaks type-checking.

**Test strategy**: Full suite + acceptance file. Divergence counter must be 0.

### Phase 3: Commit-On-Success Machinery (Workstream A)

**Goal**: When speculation succeeds, promote TMS branch values to the base level rather than relying on the fact that all writes went to the base.

**Mechanism**:
1. On `(success? result)` in `with-speculative-rollback`, call `tms-commit` to promote branch values to base
2. Pop the speculation stack
3. The committed values are now visible at depth 0

**This is necessary because**: With stack push active (Phase 2), successful writes went to the branch. Without commit-on-success, those values are invisible at depth 0 after the stack pops. The pre-Phase-2 behavior worked because writes went directly to base — now they don't.

**Belt-and-suspenders**: Compare base values after commit against what the base would have been without stack push.

**Risk**: High — incorrect commit means solved metas are invisible after speculation success.

### Phase 4: TMS Retraction (Workstream A)

**Goal**: Replace network-box restore with TMS assumption retraction on speculation failure.

**Current**: On failure, `restore-meta-state!` swaps the entire network CHAMP back — O(1) but coarse-grained. All cells revert, even those unrelated to the failed speculation.

**Target**: On failure, retract the speculation's ATMS assumption. TMS cells that wrote under that assumption lose those values. Cells unrelated to the speculation are unaffected.

**Mechanism**:
1. On failure in `with-speculative-rollback`, call `tms-retract` with the speculation's hypothesis-id
2. Pop the speculation stack
3. The ATMS nogood is already recorded (Phase D from Migration Sprint)

**Retirement criteria for network-box restore**:
- 0 divergences between TMS retraction and network-box restore across full suite
- Maintained for ≥2 consecutive phases
- Acceptance file passes at L3

**Risk**: High — incorrect retraction means stale speculation data leaks into subsequent type-checking.

### Phase 5: save/restore 2→1 Box + Belt-and-Suspenders Retirement (Workstream A)

**Goal**: Two deliverables in one phase:
1. Reduce `save-meta-state` from 2-box (network + meta-info, after Phase 1a reduced 3→2) to 1-box (network only)
2. **Retire the network-box restore secondary path** — the concrete retirement gate for belt-and-suspenders

**Prerequisites (all must be met)**:
- Phase 1a complete: id-map is an infrastructure cell in the network (3→2 already done)
- Phase 1b complete: meta-info is immutable (CHAMP entries captured by network snapshot)
- Phase 1d complete: `all-unsolved-metas` reads from infrastructure cell (no CHAMP scan dependency)
- Phase 4 complete: TMS retraction handles all speculation failure paths
- **Retirement gate passed**: 0 divergences between TMS retraction and network-box restore across full suite + batch mode for Phase 4

**Changes**:
```racket
;; Before (2-box, after Phase 1a):
(define (save-meta-state)
  (list (unbox net-box) (unbox info-box)))

;; After (1-box):
(define (save-meta-state)
  (unbox net-box))
```

**meta-info CHAMP disposition**: After this phase, the meta-info CHAMP either:
- (a) becomes an infrastructure cell in the network (mirroring Phase 1a's id-map migration), or
- (b) is removed entirely if all consumers now read from per-meta TMS cells + the unsolved-metas infrastructure cell

Option (a) is simpler and preserves the existing `meta-info` lookup pattern. Option (b) is cleaner but requires migrating every `champ-lookup` on the meta-info box.

**This phase also removes**:
- `restore-meta-state!`'s network-box restore path (replaced by TMS retraction)
- The belt-and-suspenders divergence counter and validation code from Phases 2–4
- Any fallback logic in `with-speculative-rollback` that kept both paths

**Risk**: Medium — the retirement is gated by concrete criteria from Phase 4. The 2→1 box reduction is mechanical once retirement passes.

**Test strategy**: Full suite + batch mode + acceptance file at L3. The system now has exactly one speculation mechanism (TMS retraction). Any regression is immediately attributable.

### Phase 6: batch-worker.rkt Migration (Workstream B)

**Goal**: Replace batch-worker's parameter save/restore with cell-based per-file state management.

**Current**: batch-worker saves 26 parameter values after prelude load, restores per-file via `parameterize`.

**Target**: batch-worker creates a fresh network per file (similar to how `process-command` creates per-command state) with all prelude registrations pre-loaded as cell values.

**Approach options**:
- (a) **Network snapshot**: Save the post-prelude network CHAMP (not just parameters), restore per file by swapping the network box. This is essentially what `save-meta-state` does for speculation.
- (b) **Fresh network + prelude replay**: Create a fresh network per file, replay prelude registrations into it. More expensive but cleaner isolation.
- (c) **Parameter → cell migration**: Keep the batch-worker structure but read from cells instead of parameters. Simplest change, but preserves the parameter dependency.

Option (a) is recommended — O(1) restore via CHAMP structural sharing, matches existing infrastructure, provides clean isolation without replay cost.

**Risk**: Medium — batch-worker processes the entire test suite. Any isolation failure cascades.

**Test strategy**: Run full suite in batch mode after each sub-step. Compare results file-by-file against standalone `raco test` baseline.

### Phase 7a: test-support.rkt → Network-Based Isolation (Workstream B)

**Goal**: Migrate test-support.rkt from parameter-based isolation to network-based isolation. This must happen BEFORE dual-write removal — once parameters are no longer written, tests relying on parameter overrides silently break.

**Current**: `test-support.rkt` uses `parameterize` to set registry parameters for test isolation. Each test file gets clean parameter state. This works because dual-write keeps parameters in sync with cells.

**Target**: test-support.rkt creates per-test network state (similar to batch-worker's per-file pattern from Phase 6). Tests read from cells, not parameters.

**Shadow phase** (correctness over deferral): Run the full suite with BOTH old (parameter-based) and new (network-based) isolation. Each test runs twice — once with each isolation strategy. Compare results file-by-file. Any divergence is a bug in the migration, not a regression. This is the same dual-path validation pattern Track 5 used for global-env writes (0 mismatches across 200+ modules before removing the old path).

**The shadow phase is tedious but non-negotiable**: 370 test files × 2 isolation strategies. If even one test depends on a subtle parameter-vs-cell ordering difference, the shadow phase catches it before dual-write removal makes the old path unavailable.

**Risk**: Medium — test infrastructure touches every test. The shadow phase contains the risk.

**Test strategy**: Shadow comparison across full suite. 0 divergences before proceeding to 7b.

### Phase 7b–d: Dual-Write Elimination (Workstream B)

**Goal**: Remove parameter writes from all 28+ registry functions. Cells become the sole write path.

**Approach**: For each registry function:
```racket
;; Before:
(define (register-X! name val)
  (when (current-X-cell-id) (net-write! ...))
  (current-X (hash-set (current-X) name val)))

;; After:
(define (register-X! name val)
  (net-write! (current-X-cell-id) ...))
```

**Sub-phases** (following Track 3's proven incremental strategy):
- 7b: macros.rkt registries (23) — largest batch, but all follow identical pattern
- 7c: warnings.rkt accumulators (3) + global-constraints.rkt registries (2)
- 7d: global-env.rkt (remaining dual-write from Track 5)

**Dependency**: Requires Phase 6 (batch-worker no longer reads parameters) and Phase 7a (test-support.rkt no longer reads parameters).

**Risk**: Low — mechanical transformation. The cell path is already the primary read path (Track 3). Phase 7a's shadow validation confirmed all tests work with network-based isolation.

### Phase 8: Elaboration Guard + Callback Cleanup (Workstream B)

**Goal**: Remove the two elaboration guard parameters and three callback parameters.

**Elaboration guard removal** requires verifying:
1. All contexts where readers are called have valid cell-ids (Track 5 delivered per-module networks)
2. `register-*-cells!` direct mutation of cell-id parameters doesn't cause stale reads outside elaboration
3. No test file calls readers directly with `parameterize` overrides and no cell setup

**Callback removal** requires verifying:
- All callsites of `current-retry-trait-resolve`, `current-retry-hasmethod-resolve`, `current-retry-unify` are either dead or superseded by reactive propagation
- The stratified quiescence scheduler handles all re-resolution cases

**Sub-phases**:
- 8a: Audit all guard and callback usage
- 8b: Remove `current-macros-in-elaboration?` guard — readers unconditionally use cells
- 8c: Remove `current-narrow-in-elaboration?` guard
- 8d: Remove callback parameters (or mark deprecated if edge cases found)

**Risk**: Medium — guard removal is the riskiest part. Track 3 PIR specifically warns that guards are mandatory for cells readable outside `process-command`.

### Phase 9: `current-global-env` → `current-prelude-env` Rename (Workstream B)

**Goal**: Rename the parameter to reflect its actual semantics. The parameter holds prelude definitions; the full global environment is cell-based since Track 5.

**Scope**: ~266 references across the codebase.

**Approach**: Automated find-replace + `raco make driver.rkt` to catch all compilation errors.

**Risk**: Low — purely mechanical. The compiler catches any missed references.

### Phase 10: Driver Simplification (Workstream B)

**Goal**: Simplify the per-command `parameterize` block in `driver.rkt`.

**Current** (driver.rkt `process-command`): ~30 parameter bindings including registries, guards, cell-ids, network boxes, meta-stores.

**Target**: ~5 parameter bindings — only those that are genuinely per-command (meta-store, maybe load-relative-directory, I/O ports).

**Depends on**: All prior phases (dual-write removal, guard removal, batch-worker migration).

**Risk**: Low — removing parameter bindings from `parameterize` is mechanical once the parameters are no longer written.

### Phase 11: Performance Validation + PIR

**Goal**: Verify no performance regression. Write Post-Implementation Review.

**Acceptance criteria**:
- Full suite wall time within 25% of Phase 0 baseline
- Acceptance file passes at L3 with 0 errors
- Speculation stats (hypotheses, nogoods, pruning) match Phase 0
- All deferred items from Tracks 3, 4, 5 confirmed resolved

---

## §5. Risk Analysis

| Risk | Severity | Mitigation |
|------|----------|------------|
| TMS retraction breaks speculation correctness | High | Belt-and-suspenders during Phases 2–4. Concrete retirement gate at Phase 5: 0 divergences across full suite + batch mode. |
| Constraint status functional conversion breaks retry state machine | High | Phase 1c: dual-path validation — run both old (in-place) and new (functional) status updates, assert identical constraint resolution counts across full suite. |
| Speculation stack push makes branch values invisible | High | Commit-on-success (Phase 3) immediately follows stack push (Phase 2). Belt-and-suspenders validates correct promotion. |
| batch-worker migration breaks test isolation | Medium | Run full suite in batch mode after each sub-phase. File-by-file comparison against standalone `raco test`. |
| test-support.rkt migration misses subtle parameter-vs-cell difference | Medium | Phase 7a shadow phase: full suite × 2 isolation strategies, 0 divergences before dual-write removal. |
| Elaboration guard removal exposes stale cells | Medium | Phase 8 audit of ALL reader call sites. Track 3 PIR §4.1 warns guards are mandatory for cells readable outside `process-command` — verify this constraint is lifted by Track 5's per-module networks. |
| `all-unsolved-metas` infrastructure cell out of sync | Low | Phase 1d dual-path validation: old CHAMP scan vs. new cell read, assert identical sets across full suite. Remove old path after 0 divergences. |
| Rename across 266 files introduces typos | Low | `raco make driver.rkt` catches all compilation errors. Automated find-replace. |
| Test infrastructure divergence | Medium | Track 5 PIR lesson: explicitly audit `run-ns-last` path for each phase. Test both production and test code paths. |

---

## §6. Design Decisions (D.1+ Critique Resolution)

The following questions were raised in D.1 and resolved in the D.1+ critique discussion:

### DD-1: Data-oriented approach to mutations

**Question**: Can a more data-oriented approach be brought into scope to align with the first-class data-oriented design principle?

**Resolution**: Yes. Code audit revealed two distinct situations:
- `meta-info` is **already write-once in practice** — `solve-meta-core!` creates new structs and inserts into the CHAMP. Zero call sites use the mutable setters. Phase 1b simply removes the vestigial `#:mutable`.
- `constraint` has **genuine in-place mutation** (~10 sites) for the status state machine. Phase 1c converts these to functional CHAMP updates, aligning the entire meta/constraint subsystem with data orientation.

This broadens Phase 1 but delivers a structurally cleaner foundation for TMS branching — constraint state transitions now compose with speculation snapshots.

### DD-2: Workstream ordering — hard thing first

**Question**: Should Workstream A (TMS) or Workstream B (cleanup) go first?

**Resolution**: Workstream A first. Every prior track followed this pattern — architectural decisions first, mechanical cleanup second. The batch-worker migration is mechanically independent but doesn't teach anything that helps with TMS. Completing TMS retraction gives absolute confidence that the cell path is the sole authority, making every subsequent dual-write removal trivially justified.

### DD-3: Belt-and-suspenders retirement — concrete phaseout point

**Question**: How do we prevent drift between primary (TMS retraction) and secondary (network-box restore) paths?

**Resolution**: Phase 5 is the **concrete retirement gate**. The secondary path is removed as a defined step with hard criteria:
- 0 divergences between TMS retraction and network-box restore across full suite + batch mode
- Acceptance file passes at L3 with 0 errors
- Speculation stats match Phase 0 baseline

Phase 5 cannot proceed until Phase 4 passes this gate. No gradual deprecation, no optional dead code.

### DD-4: `all-unsolved-metas` replacement strategy

**Question**: Walk all cells (O(n)) or infrastructure cell (O(1))?

**Resolution**: Infrastructure cell (option b). Maintained incrementally — `fresh-meta` adds, `solve-meta!` removes. Matches the Track 3 infrastructure cell pattern. Participates in network snapshots automatically. Implemented as Phase 1d.

### DD-5: id-map as infrastructure cell

**Question**: Can id-map move to an infrastructure cell early?

**Resolution**: Yes — Phase 1a, the first implementation sub-phase. Immediate win: save/restore drops from 3→2 boxes. The id-map is only read/written during elaboration where networks are always available, so no guard issues. This front-loads an easy structural improvement.

### DD-6: test-support.rkt migration

**Question**: Does test-support.rkt need to switch to network-based isolation?

**Resolution**: Yes, with a shadow phase (Phase 7a). Run full suite with both old (parameter-based) and new (network-based) isolation, compare results. 0 divergences before proceeding to dual-write removal. Tedious but non-negotiable — correctness over deferral.

### Remaining Open Questions for D.2

1. **Are elaboration guards still needed?** Track 5 gave module loading persistent networks, but `register-*-cells!` uses direct mutation (`(current-X-cell-id val)`) rather than `parameterize`. These mutations persist beyond scope. Phase 8 audit must determine whether guards serve a remaining purpose.

2. **Should callback parameters be removed or absorbed?** The retry callbacks (`current-retry-trait-resolve`, etc.) are superseded by stratified quiescence but may have edge-case uses outside the standard elaboration path. Phase 8 audit will determine full removal vs. keeping as dead code.

3. **Phase 5 meta-info CHAMP disposition**: After save/restore drops to 1 box, does the meta-info CHAMP become an infrastructure cell (simpler) or get removed entirely (cleaner)?

---

## §7. DEFERRED.md Triage

Items absorbed by Track 6:

| Deferred Item | Source | Track 6 Phase |
|---------------|--------|---------------|
| Propagator-First Phase 3d: Full `current-global-env` Rename | Migration Sprint | Phase 9 |
| Migration Sprint Phases 5a–5b: Driver simplification | Migration Sprint | Phase 10 |
| Track 3 Phase 6: Dual-write parameter elimination | Track 3 | Phase 7 |
| Track 3 Phase 6: Elaboration guard removal | Track 3 | Phase 8 |
| Track 4 Phase 4: Meta-info → write-once | Track 4 | Phase 1 |
| Track 4 Phase 4: save/restore 3→1 box | Track 4 | Phase 5 |
| Track 4 Phase 4: TMS retraction pipeline | Track 4 | Phases 2–4 |
| Track 5: `current-global-env` → `current-prelude-env` | Track 5 | Phase 9 |
| Track 5: Dual-write removal for global-env | Track 5 | Phase 7d |

Items NOT absorbed (remain deferred):
- Reduction cache cells (Phase 3e) — LSP-specific, deferred to Track 10
- TMS-aware module definition cells — Track 7+ scope
- Automatic re-elaboration on staleness — Track 10 (LSP) scope

---

## §8. Learnings Applied from Prior PIRs

### From Track 3 PIR
- **Elaboration guards are mandatory for cells readable outside `process-command`** (§4.1). Guard removal (Phase 8) requires verifying all read contexts have valid cells. This is the highest-risk item in Workstream B.
- **Module-local guards avoid circular dependencies** (§6.1). If guard removal exposes new circular-dep issues, the local guard pattern is the fallback.
- **Incremental strategy works**: Track 3 did 28 registries in sub-phases (a/b/c/d/e). Track 6 Phase 7 follows the same pattern.

### From Track 4 PIR
- **Meta-info dual-write creates coherence issues with TMS branching** (Phase 2c discovery). This is why all in-place mutations (Phases 1a–1d) must precede stack push (Phase 2). The ordering is non-negotiable.
- **3-box save/restore works correctly as-is**. The reduction from 3→1 is optimization, not correctness. Belt-and-suspenders can keep multi-box until TMS retraction is proven.

### From D.1+ Critique (Data Orientation)
- **Audit before assuming mutation exists**. The D.1 draft assumed `meta-info` was genuinely mutated; code audit revealed it was already functionally write-once. `constraint` was the actual mutation site. Always verify assumptions against code before designing around them.
- **Data-oriented conversion is a TMS prerequisite, not a nice-to-have**. In-place mutations at depth 0 are invisible to TMS branching. Functional updates through the CHAMP compose naturally with speculation snapshots. This reframes Phase 1 from "cleanup" to "architectural prerequisite."
- **Concrete retirement gates prevent drift**. Belt-and-suspenders without a defined retirement point becomes permanent dead code. Phase 5 is the gate with hard criteria — Correct by Construction means one correct path, not two hedged paths.

### From Track 5 PIR
- **Belt-and-suspenders with explicit retirement criteria**. Define upfront when network-box restore can be removed. The criteria: 0 divergences for ≥2 consecutive phases.
- **Test infrastructure (`run-ns-last`) diverges from production**. Audit both paths for every phase. Track 5 found that `run-ns-last` makes different infrastructure assumptions than `process-command`.
- **Self-updating functions beat caller-side wrappers**. Apply this when consolidating driver patterns in Phase 10 — functions should update their own cells rather than requiring callers to coordinate.
- **First phase = all decisions, subsequent = mechanical**. Budget Phase 1 at 2–3× time of subsequent phases.

### From All PIRs
- **Commit after each phase**. Uncommitted work is invisible work.
- **Run acceptance file after each phase**. Late L3 validation causes cascading fixes.
- **Performance baseline comparison**. If wall time exceeds baseline by >25%, investigate before committing.

---

## §9. Key Files

| File | Role in Track 6 |
|------|-----------------|
| `metavar-store.rkt` | meta-info struct (l.200), save-meta-state (l.1821), all-unsolved-metas (l.1839), solve-meta! |
| `elab-speculation-bridge.rkt` | with-speculative-rollback (l.171), speculation stack, ATMS integration |
| `macros.rkt` | 23 dual-write registries, elaboration guard (l.488), register-macros-cells! |
| `global-constraints.rkt` | 2 narrowing registries, elaboration guard (l.86) |
| `warnings.rkt` | 3 warning accumulators |
| `driver.rkt` | per-command parameterize, register-*-cells! calls, process-command |
| `tools/batch-worker.rkt` | parameter save/restore (l.67–225) |
| `propagator.rkt` | current-speculation-stack, net-write!, TMS cell infrastructure |
| `global-env.rkt` | two-layer architecture, rename target (266 refs) |
| `tests/test-support.rkt` | test isolation parameterize block |
| `atms.rkt` | ATMS tracking, assumption retraction |
