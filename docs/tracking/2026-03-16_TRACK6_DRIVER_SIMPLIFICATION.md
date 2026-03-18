# Track 6: Driver Simplification + Cleanup — Stage 2/3 Design

**Created**: 2026-03-16
**Status**: DESIGN (D.3 — self-critique principle alignment complete)
**Depends on**: Track 3 ✅ (Cell-Primary Registries), Track 4 ✅ (ATMS Speculation), Track 5 ✅ (Global-Env + Module Networks)
**Enables**: Track 7 (QTT Multiplicity Cells)
**Master roadmap**: `2026-03-13_PROPAGATOR_MIGRATION_MASTER.md` Track 6
**Prior art**: Track 3 PIR (elaboration guard discovery), Track 4 PIR (dual-write coherence), Track 5 PIR (belt-and-suspenders retirement, test infrastructure divergence)
**Absorbed deferrals**: Track 3 Phase 6, Track 4 Phase 4, Track 5 rename + dual-write removal

---

## Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| **Design** | | | |
| D.1 | Initial design document | ✅ | This document |
| D.1+ | Design critique + refinement | ✅ | Data orientation, ordering, retirement gate, id-map cell, test-support migration |
| D.2 | External critique + rework | ✅ | 10 critiques addressed — see §6b |
| D.3 | Self-critique (principle alignment) | ✅ | 6 principles aligned, 0 tensions, 6 observations — see §12 |
| **WS-A** | **Data Orientation + TMS Retraction** | | |
| 0 | Performance baseline + acceptance file | ✅ | 278 evals, 0 errors, 6 BUGs (commit `7cd1ad6`) |
| 1a | id-map → elab-network struct field (3→2 box) | ✅ | commit `9677970` — 7148 tests, 224.3s |
| 1b | meta-info `#:mutable` removal | ✅ | commit `39421e6` — vestigial, zero mutator call sites |
| 1c | constraint status → functional CHAMP updates | ✅ | commit `e88c2b2` — store: list→hasheq, 7148 tests, 210.8s |
| 1d | `all-unsolved-metas` → infrastructure cell | ✅ | commit `a82e4d2` — 7148 tests, 207.4s, acceptance 0 errors |
| 2+3 | Speculation stack push + commit-on-success | ✅ | commit `4a08db6` — depth-0 only; 7148 tests, 199.6s, acceptance 0 errors |
| 4 | TMS retraction (replace network-box restore) | ✅ | commit `acc76e4` — nested TMS, tms-read fix, tms-commit flatten; 7154 tests, 207.9s, acceptance 302/0 |
| 5a | meta-info CHAMP → elab-network field (2→1 box) | ✅ | commit `9358b67` — 7148 tests, 210.5s, acceptance 0 errors |
| 5b | Belt-and-suspenders retirement gate | ⏸️ | **Blocked**: TMS retraction insufficient — infra cells + meta-info not TMS-managed. See §4 Phase 5b notes |
| **WS-B** | **Dual-Write Elimination + Cleanup** | | |
| 6 | batch-worker.rkt → snapshot-based state (19→1 vector + 8 param) | ✅ | commit `25d7b20` — 7154 tests, 208.9s. Per-file timeout: `9a600c3` |
| 7a | test-support.rkt → network-based isolation | ✅ | commit `92a27b0` — 7 network params added to 5 helpers + prelude block. Shadow: 0 divergences (7154 tests, 203.5s, same 3 ATMS) |
| 7b | macros.rkt dual-write: existing pattern correct | ✅ | Reverted `e10f5f3` sync-back pattern (commit `70063b9`). Natural dual-write (param persistence + cell propagation) matches Track 5's `global-env-add` pattern — NOT redundant. |
| 7c | warnings.rkt dual-write: existing pattern correct | ✅ | Reverted `b618c78` sync-back pattern (commit `70063b9`). Same reasoning as 7b. |
| 7d | Global-env lookup → module-network-ref cutover | ✅ | commit `cd54a9f` (belt-and-suspenders population), `78bba78` (lookup cutover). `current-module-definitions-content` sourced from Track 5 module-network-ref cells. 250 test files updated. 7154 tests, 2 ATMS. Layer 2 retained as fallback. |
| 8a | Exhaustive cell-reader audit + categorization | ✅ | 24 macros readers + 2 narrow readers audited. 3 call sites outside elaboration (driver post-compilation, repl :trait/:satisfies) → switched to param reads. |
| 8b | Remove `current-macros-in-elaboration?` guard | ✅ | commit `6fa6240` — guard removed from macros-cell-read-safe. Net-boxes scoped to process-command parameterize (auto-revert to #f). |
| 8c | Remove `current-narrow-in-elaboration?` guard | ✅ | commit `6fa6240` — guard removed from narrow-cell-read-safe. Same net-box scoping. |
| 8d | Callback cleanup + dead code removal | ✅ | commit `6793ce5` — immediate resolution paths removed (stratified loop handles), 3 dead functions removed, 2 guard params removed. Callbacks retained as stepping stone; inlining into execute-resolution-actions! scoped to stratified prop-net architecture (Track 7+). Principles annotated (commit `f66809e`). |
| 9 | `current-global-env` → `current-prelude-env` rename | ✅ | commit `36588ee` — 994 occurrences across 271 files. Zero remaining references. |
| 10 | Driver `parameterize` simplification | ✅ | Assessed: 13 bindings remain (5 net-boxes, 3 caches, fuel, narrow-constraints, 3 warning resets). All necessary — reduced from ~30 through Phases 7-8. |
| **Post-Phase 10** | **Deferred items (required before PIR)** | | |
| 5b | Belt-and-suspenders retirement gate | ⏸️ | Blocked on infra cells + meta-info not TMS-managed |
| BUG | ATMS initialization in test speculation paths | ✅ | commit `ebc781e` — lazy ATMS init in `with-speculative-rollback` replaces hard error. Tests using `with-fresh-meta-env` bypass `process-command`; lazy init creates ATMS on demand. **All 7154 tests pass. 0 failures.** |
| **Final** | | | |
| 11 | Performance validation + PIR | ⬜ | Graduated criteria: <5% ship, 5–15% investigate, >15% block. BUG fixed (commit `ebc781e`). 5b deferred to Track 7. PIR can proceed noting 5b as open. |

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

**Done when**:
- [ ] id-map stored as infrastructure cell in network
- [ ] `save-meta-state` returns 2-element list (network + meta-info), not 3
- [ ] `restore-meta-state!` restores 2 boxes, not 3
- [ ] Full suite passes
- [ ] Speculation stats unchanged

### Phase 1b: meta-info `#:mutable` Removal (Workstream A)

**Goal**: Remove vestigial `#:mutable` annotation from `meta-info` struct.

**Code audit finding**: `solve-meta-core!` already creates new `meta-info` values via functional CHAMP insert (line 1210–1213). Zero call sites use `set-meta-info-status!` or `set-meta-info-solution!`. The `#:mutable` annotation is dead weight.

**Change**: Remove `#:mutable` from the struct declaration. Confirm `raco make driver.rkt` succeeds (would catch any hidden setter usage).

**Risk**: Trivial — no behavioral change. This is removing dead capability.

**Test strategy**: Compilation check + full suite (should be bit-identical behavior).

**Done when**:
- [ ] `#:mutable` removed from `meta-info` struct
- [ ] `raco make driver.rkt` succeeds (catches any hidden setter usage)
- [ ] Full suite passes (bit-identical behavior)

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

**Concurrency safety** (D.2 critique): The read-modify-write cycle is safe because constraint resolution is **strictly single-threaded**. `run-stratified-resolution!` runs in `parameterize ([current-in-stratified-resolution? #t])` and processes constraints sequentially. The BSP parallel mode (`run-to-quiescence-bsp`) fires type propagators in parallel (Stratum 0) but constraint resolution (Stratum 2) is always sequential. No concurrent constraint retry exists.

**Why not lattice merge?** (D.2 critique): Constraint status transitions are **non-monotonic**: `'retrying → 'postponed` is a demotion. The re-entrancy guard explicitly cycles status downward. This doesn't fit a lattice join — `join('retrying, 'postponed)` cannot simultaneously equal `'postponed` and `'retrying`. The state machine is a protocol, not a lattice.

**cid stability contract** (D.2 critique): Constraint cid is a gensym, stable and unique for the lifetime of the constraint. No code path creates, deletes, or re-adds a constraint with an existing cid. This invariant ensures the functional pattern's cid lookup correctly identifies the "same" constraint that the old object-identity pattern relied on.

**Consumers to update**:
- `retry-constraints-for-meta!` (metavar-store.rkt:633–645)
- `retry-constraints-via-cells!` (metavar-store.rkt:652–672)
- `retry-constraints-for-typearg!` (metavar-store.rkt:~770–780)
- `unify.rkt:754–758` (marking constraints solved/failed)
- `postpone-constraint!` (metavar-store.rkt:~620, `set-constraint-cell-ids!`)

**Also remove `#:mutable` from `constraint` struct** after all mutation sites are converted.

**Risk**: Medium — touches the constraint retry hot path. The state machine must behave identically.

**Done when**:
- [ ] Zero call sites use `set-constraint-status!` or `set-constraint-cell-ids!`
- [ ] `#:mutable` removed from constraint struct
- [ ] `raco make driver.rkt` succeeds
- [ ] Full suite passes
- [ ] Constraint resolution counts match Phase 0 baseline
- [ ] Speculation stats (hypotheses, nogoods) unchanged

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

**Done when**:
- [ ] Infrastructure cell tracks unsolved meta set incrementally
- [ ] `fresh-meta` adds to cell, `solve-meta-core!` removes from cell
- [ ] Dual-path validation: 0 divergences between CHAMP scan and cell read across full suite
- [ ] Old CHAMP scan removed
- [ ] Full suite passes

### Phase 2: Speculation Stack Push Activation (Workstream A)

**Goal**: Activate the speculation stack (deferred since Track 4 Phase 2). Cell writes during speculation go to TMS branches rather than the base network.

**Current state**: `current-speculation-stack` exists (defined in `propagator.rkt`, re-exported from `elab-speculation-bridge.rkt`) but is never pushed. All cell writes go to depth 0 (base).

**Mechanism**:
1. `with-speculative-rollback` pushes an assumption onto `current-speculation-stack` before running the thunk
2. `net-write!` checks stack depth; if > 0, writes go to the current TMS branch
3. `tms-read` at depth 0 still returns the base value (fast path)

**Critical**: Reads at depth 0 must NOT see branch values. The TMS cell `tms-read` function already handles this (Track 4 Phase 1 implemented depth-aware reads). What's new is that `net-write!` during speculation actually routes to branches.

**Belt-and-suspenders** (D.2 clarification): During Phases 2–4, **network-box restore is the production mechanism**. TMS retraction is being validated in shadow mode. A failure in any of Phases 2–4 does not leave the system in an inconsistent state — it means the TMS shadow path isn't ready yet, and network-box restore continues to handle all speculation correctly. The TMS path is being *observed* for correctness, not *relied upon*.

Keep network-box restore as fallback. After thunk execution, compare TMS branch values against network-box diff — log divergences.

**Risk**: High — changes what speculation sees. Any error in TMS write routing breaks type-checking. Mitigated by network-box restore remaining the production path.

**Test strategy**: Full suite + acceptance file. Divergence counter must be 0.

**Done when**:
- [ ] `with-speculative-rollback` pushes assumption before thunk
- [ ] `net-write!` routes to TMS branch when stack depth > 0
- [ ] Depth-0 reads do NOT see branch values
- [ ] 0 divergences between TMS shadow and network-box restore across full suite
- [ ] Speculation stats unchanged from Phase 0

### Phase 3: Commit-On-Success Machinery (Workstream A)

**Goal**: When speculation succeeds, promote TMS branch values to the base level rather than relying on the fact that all writes went to the base.

**Mechanism**:
1. On `(success? result)` in `with-speculative-rollback`, call `tms-commit` to promote branch values to base
2. Pop the speculation stack
3. The committed values are now visible at depth 0

**This is necessary because**: With stack push active (Phase 2), successful writes went to the branch. Without commit-on-success, those values are invisible at depth 0 after the stack pops. The pre-Phase-2 behavior worked because writes went directly to base — now they don't.

**Belt-and-suspenders**: Compare base values after commit against what the base would have been without stack push.

**Risk**: High — incorrect commit means solved metas are invisible after speculation success.

**Done when**:
- [ ] `tms-commit` promotes branch values to base on success
- [ ] Speculation stack pops after commit
- [ ] Base values after commit match pre-Phase-2 behavior (belt-and-suspenders check)
- [ ] Full suite passes
- [ ] 0 divergences between TMS commit and direct-write baseline

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

**Done when**:
- [ ] `tms-retract` called on failure with speculation's hypothesis-id
- [ ] Speculation stack pops after retraction
- [ ] ATMS nogood recorded for failed assumption
- [ ] 0 divergences between TMS retraction and network-box restore across full suite
- [ ] Acceptance file passes at L3
- [ ] Retirement gate criteria met for Phase 5b

### Phase 5a: meta-info CHAMP → Infrastructure Cell (Workstream A)

**Goal**: Move the meta-info CHAMP from a separate box into an infrastructure cell in the network. Reduces `save-meta-state` from 2-box (network + meta-info) to 1-box (network only).

This mirrors Phase 1a's id-map migration — same pattern, same risk profile.

**Prerequisites**:
- Phase 1a complete: id-map already migrated (pattern established)
- Phase 1b complete: meta-info is immutable (CHAMP entries are values)
- Phase 1d complete: `all-unsolved-metas` reads from infrastructure cell (no CHAMP scan dependency on meta-info box)

**Changes**:
```racket
;; Before (2-box, after Phase 1a):
(define (save-meta-state)
  (list (unbox net-box) (unbox info-box)))

;; After (1-box):
(define (save-meta-state)
  (unbox net-box))
```

**Risk**: Low — mechanical, mirrors Phase 1a. The meta-info CHAMP becomes a cell in the network; all consumers read via `net-read` instead of `unbox`. Network snapshot automatically captures it.

**Done when**:
- [ ] `current-prop-meta-info-box` replaced by infrastructure cell
- [ ] `save-meta-state` returns single value (network CHAMP)
- [ ] `restore-meta-state!` sets single box
- [ ] Full suite passes
- [ ] Speculation stats unchanged

### Phase 5b: Belt-and-Suspenders Retirement Gate (Workstream A) — BLOCKED

**Goal**: **Retire the network-box restore secondary path**. This is the concrete retirement gate for belt-and-suspenders.

**Status**: ⏸️ BLOCKED — TMS retraction alone is insufficient for full rollback.

**Finding (Phase 4 validation attempt)**:

Removing `restore-meta-state!` from the failure path produces 2 test failures:

1. **Constraint store leaks**: Infrastructure cells (constraint store, unsolved-metas set) use accumulative merge functions, not TMS branches. Constraints added during a failed speculation persist after TMS retraction because `net-retract-assumption` only removes TMS branches — it doesn't undo non-TMS cell merges.

2. **Meta-info leaks**: The `meta-info` CHAMP is a field in `elab-network`, not a TMS-managed cell. When a meta is solved during a failed speculation, `meta-info` retains the "solved" status. Subsequent attempts to solve the same meta hit "already solved" errors.

**Root cause**: TMS manages VALUE-level branching (cell read/write through `tms-read`/`tms-write`), but STRUCTURAL state (new cells, infrastructure cell accumulations, elab-network fields like meta-info/id-map/next-meta-id) isn't TMS-managed. Full retirement requires:
- Infrastructure cells (constraint store, unsolved-metas) → TMS-aware accumulation (retraction removes entries added under the retracted assumption)
- meta-info, id-map, next-meta-id → either TMS-managed or separate rollback mechanism

**Current state**: Belt-and-suspenders remains active. TMS retraction handles branch cleanup, `restore-meta-state!` handles structural rollback. Both run on every failure path.

**Forward path**: Making infrastructure cells TMS-aware requires extending the TMS model to support set-like accumulation with retraction (currently only supports value replacement). This work is tracked as a concrete DEFERRED item: "TMS-Aware Infrastructure Cells + Structural State" in `DEFERRED.md` § Propagator-First Elaboration Migration. Target placement: prerequisite phase in Track 7 (QTT Multiplicity Cells) or standalone mini-track between Track 6 and Track 7. **Must be resolved before Track 8** (Unification as Propagators) where incremental rollback correctness becomes load-bearing. See DEFERRED.md for the two-part fix path (infra cells → TMS-aware, structural fields → TMS cells).

**Done when** (deferred):
- [ ] Infrastructure cells support TMS-aware accumulation with retraction
- [ ] meta-info, id-map, next-meta-id are TMS-managed or have separate rollback
- [ ] No network-box restore code remains in `with-speculative-rollback`
- [ ] Full suite passes without `restore-meta-state!`
- [ ] Acceptance file L3 with 0 errors

### Phase 6: batch-worker.rkt Migration (Workstream B)

**Goal**: Replace batch-worker's parameter save/restore with hybrid cell-based + parameter state management.

**Current**: batch-worker saves 26 parameter values after prelude load, restores per-file via `parameterize`.

**Parameter categorization** (D.2 critique — not all 26 are cell-based):

| Category | Count | Parameters | Migration |
|----------|-------|------------|-----------|
| **Cell-based** (in network) | 20 | 19 macros.rkt registries + 1 global-env | Captured by network CHAMP snapshot |
| **Runtime config** (NOT in network) | 7 | module-registry, ns-context, lib-paths, loading-set, module-loader, spec-propagation-handler, foreign-handler | Keep as `parameterize` — these are genuinely per-file runtime configuration, not elaboration state |

The 7 namespace.rkt parameters are runtime configuration values that control how module loading, spec propagation, and FFI work. They have no corresponding cells and are not part of the propagator network — they configure the environment in which elaboration runs. Moving them to cells would be architecturally wrong (they're not reactive state, they're configuration).

**Target**: Hybrid approach:
- **Network snapshot** for the 20 cell-based parameters: save post-prelude network CHAMP, restore per-file by swapping the network box (O(1) via CHAMP structural sharing)
- **`parameterize`** for the 7 runtime config parameters: keep exactly the current pattern

This means batch-worker's per-file restore becomes: swap network box + parameterize 7 values, instead of parameterize 26+ values.

**Risk**: Medium — batch-worker processes the entire test suite. Any isolation failure cascades.

**Test strategy**: Run full suite in batch mode after each sub-step. Compare results file-by-file against standalone `raco test` baseline.

**Done when**:
- [ ] Network CHAMP snapshot replaces 20 cell-based parameter saves
- [ ] 7 namespace.rkt parameters remain as `parameterize`
- [ ] Full suite in batch mode matches standalone `raco test` results
- [ ] No file-by-file divergences

### Phase 7a: test-support.rkt → Network-Based Isolation (Workstream B)

**Goal**: Migrate test-support.rkt from parameter-based isolation to network-based isolation. This must happen BEFORE dual-write removal — once parameters are no longer written, tests relying on parameter overrides silently break.

**Current**: `test-support.rkt` uses `parameterize` to set registry parameters for test isolation. Each test file gets clean parameter state. This works because dual-write keeps parameters in sync with cells.

**Target**: test-support.rkt creates per-test network state (similar to batch-worker's per-file pattern from Phase 6). Tests read from cells, not parameters.

**Shadow phase** (correctness over deferral): Run the full suite with BOTH old (parameter-based) and new (network-based) isolation. Each test runs twice — once with each isolation strategy. Compare results file-by-file. Any divergence is a bug in the migration, not a regression. This is the same dual-path validation pattern Track 5 used for global-env writes (0 mismatches across 200+ modules before removing the old path).

**The shadow phase is tedious but non-negotiable**: 370 test files × 2 isolation strategies. If even one test depends on a subtle parameter-vs-cell ordering difference, the shadow phase catches it before dual-write removal makes the old path unavailable.

**Time budget** (D.2 critique): The shadow phase doubles the full suite run — approximately **~7 minutes one-time cost** (200s baseline × 2). This is a single validation run, not a per-phase ongoing cost. The investment is small relative to the risk of discovering parameter-vs-cell divergences after dual-write removal.

**Risk**: Medium — test infrastructure touches every test. The shadow phase contains the risk.

**Test strategy**: Shadow comparison across full suite. 0 divergences before proceeding to 7b.

**Done when**:
- [ ] test-support.rkt creates per-test network state
- [ ] Shadow validation: 0 divergences across 370 test files × 2 isolation strategies
- [ ] No test file depends on parameter-based isolation only

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

**Done when**:
- [ ] Phase 7b: 23 macros.rkt registry functions write to cells only (parameter write removed)
- [ ] Phase 7c: 3 warning + 2 constraint registries write to cells only
- [ ] Phase 7d: global-env dual-write removed
- [ ] Full suite passes after each sub-phase
- [ ] Batch mode passes after each sub-phase

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
- 8a: **Exhaustive cell-reader + callback audit** — categorize EVERY cell reader call site AND every callback parameter reference into one of three contexts:
  - **Elaboration context** (inside `process-command` / `with-speculative-rollback`): cells always valid, guards unnecessary; callbacks superseded by reactive scheduler
  - **Module-loading context** (inside `load-module` / `process-file`): Track 5 gave per-module networks, cells valid; callbacks may not have reactive scheduler active
  - **Other context** (test setup, batch-worker init, REPL): may lack network — if any readers are called here, guard removal is blocked until the context is migrated

  This exhaustive categorization (not sampling) is the decision-making deliverable of Phase 8. If any readers fall into the "other" category, the phase plan must be revised before proceeding. Callback references (D.3 self-critique T-3) must be included in the audit — the 3 retry callbacks may be invoked from module-loading or other contexts where the stratified quiescence scheduler isn't active.
- 8b: Remove `current-macros-in-elaboration?` guard — readers unconditionally use cells
- 8c: Remove `current-narrow-in-elaboration?` guard
- 8d: Remove callback parameters (or mark deprecated if edge cases found)

**Risk**: Medium — guard removal is the riskiest part. Track 3 PIR specifically warns that guards are mandatory for cells readable outside `process-command`.

**Done when**:
- [ ] Phase 8a: exhaustive categorization table for all 25 guarded readers (23 macros + 2 constraints) + 3 callback parameters (~28 references)
- [ ] Phase 8b: zero references to `current-macros-in-elaboration?`
- [ ] Phase 8c: zero references to `current-narrow-in-elaboration?`
- [ ] Phase 8d: zero references to callback parameters (or documented edge cases)
- [ ] Full suite passes
- [ ] Batch mode passes

### Phase 9: `current-global-env` → `current-prelude-env` Rename (Workstream B)

**Goal**: Rename the parameter to reflect its actual semantics. The parameter holds prelude definitions; the full global environment is cell-based since Track 5.

**Scope**: ~266 references across the codebase.

**Approach**: Automated find-replace + `raco make driver.rkt` to catch all compilation errors.

**Risk**: Low — purely mechanical. The compiler catches any missed references.

**Done when**:
- [ ] Zero references to `current-global-env` (grep returns 0)
- [ ] `raco make driver.rkt` succeeds
- [ ] Full suite passes

### Phase 10: Driver Simplification (Workstream B)

**Goal**: Simplify the per-command `parameterize` block in `driver.rkt`.

**Current** (driver.rkt `process-command`): ~30 parameter bindings including registries, guards, cell-ids, network boxes, meta-stores.

**Target**: ~5 parameter bindings — only those that are genuinely per-command (meta-store, maybe load-relative-directory, I/O ports).

**Depends on**: All prior phases (dual-write removal, guard removal, batch-worker migration).

**Note** (D.3 self-critique T-2): The "~5 bindings" target depends on Phase 8's outcome. If the Phase 8a audit finds cell readers in "other" contexts that require guards, some guard bindings remain in `parameterize`. The target is "only genuinely per-command bindings" — the exact count depends on what Phase 8 discovers.

**Risk**: Low — removing parameter bindings from `parameterize` is mechanical once the parameters are no longer written.

**Done when**:
- [ ] `process-command` `parameterize` block has ≤ 5 bindings (or documented justification if higher)
- [ ] Removed bindings are not referenced anywhere under `process-command`
- [ ] Full suite passes
- [ ] Acceptance file L3 with 0 errors

### Phase 11: Performance Validation + PIR

**Goal**: Verify no performance regression. Write Post-Implementation Review.

**Graduated performance criteria** (D.2 critique — not a binary pass/fail):

| Regression | Action |
|------------|--------|
| **< 5%** | Ship. Normal variance / acceptable cost of cleaner architecture. |
| **5–15%** | Investigate. Profile to identify which phase introduced the regression. If attributable to a specific CHAMP lookup pattern or TMS overhead, optimize before shipping. If distributed across many phases, document as architectural cost. |
| **> 15%** | Block. Do not merge Track 6. Profile, identify, and fix. The Track 3 pattern-kind regression (850s from a single missing fast-path) shows that large regressions have discrete causes. |

**Full acceptance criteria**:
- Full suite wall time within graduated criteria above
- Acceptance file passes at L3 with 0 errors
- Speculation stats (hypotheses, nogoods, pruning) match Phase 0
- All deferred items from Tracks 3, 4, 5 confirmed resolved
- PIR written following `POST_IMPLEMENTATION_REVIEW.org` methodology (all 16 questions)

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

---

## §10. Phase Dependency DAG

```
                    Phase 0 (baseline)
                         │
            ┌────────────┼────────────┐
            ↓            ↓            ↓
        Phase 1a     Phase 1b     Phase 1c
        (id-map)     (#:mutable)  (constraint)
            │            │            │
            └────────┬───┘            │
                     ↓                │
                 Phase 1d ←───────────┘
                 (unsolved-metas)
                     │
                     ↓
                 Phase 2
                 (stack push)
                     │
                     ↓
                 Phase 3
                 (commit)
                     │
                     ↓
                 Phase 4
                 (retraction)
                     │
              ┌──────┴──────┐
              ↓             ↓
          Phase 5a      Phase 6 ←──── (independent of 5a)
          (2→1 box)     (batch-worker)
              │             │
              ↓             ↓
          Phase 5b      Phase 7a
          (retirement)  (test-support)
                            │
                     ┌──────┼──────┐
                     ↓      ↓      ↓
                   7b      7c     7d
                   (macros)(warn) (g-env)
                     └──────┬──────┘
                            ↓
                        Phase 8a
                        (audit)
                     ┌──────┼──────┐
                     ↓      ↓      ↓
                   8b      8c     8d
                   (guard) (guard)(callback)
                     └──────┬──────┘
                            ↓
                        Phase 9 ←──── (could also run after 1b)
                        (rename)
                            │
                            ↓
                        Phase 10
                        (driver simplify)
                            │
                            ↓
                        Phase 11
                        (PIR)
```

**Key observations**:
- Phases 1a, 1b, 1c are independent of each other (can run in any order)
- Phase 1d depends on all three Phase 1 sub-phases
- Workstream A (1→5) is strictly sequential after Phase 1d
- Phase 6 (batch-worker) can start after Phase 4, independent of Phase 5a/5b
- Phase 9 (rename) has minimal ordering constraints — could run after Phase 1b
- The critical path is: 0 → 1c → 1d → 2 → 3 → 4 → 6 → 7a → 7b → 8a → 8b → 10 → 11

---

## §11. Rollback Procedures

Each phase has a defined rollback strategy. Since phases are committed individually, rollback is always to the previous phase's commit.

### General Rollback Protocol

1. **Detect**: Full suite or acceptance file fails after phase completion
2. **Diagnose**: Identify whether the failure is in the phase's changes or pre-existing
3. **Revert**: `git revert <phase-commit>` — creates a new commit, preserving history
4. **Validate**: Full suite passes after revert
5. **Root-cause**: Fix the issue in a new commit before re-attempting the phase

### Phase-Specific Rollback Notes

**Phases 1a–1d (data orientation)**: Each sub-phase is independently revertable. Phase 1a (id-map) can be reverted without affecting 1b (meta-info) or 1c (constraint). Phase 1d depends on all three, so reverting 1d also reverts the infrastructure cell but leaves 1a–1c intact.

**Phase 2 (stack push)**: Revert deactivates stack push — writes return to depth-0 base. Since network-box restore is still the production mechanism during this phase, the revert leaves the system in a known-good state.

**Phases 3–4 (commit/retract)**: Same as Phase 2 — network-box restore is production. Revert removes TMS shadow path, system continues functioning via network-box restore.

**Phase 5b (retirement)**: **Most critical rollback**. If post-retirement regression found, revert re-enables network-box restore as production. This is why Phase 5b has the strictest entry gate (0 divergences). However: reverting Phase 5b alone may not restore the validation code removed in that phase — the rollback may need to also revert Phase 5a if the meta-info infrastructure cell interacts with the issue.

**Phases 7b–d (dual-write removal)**: Revert re-enables dual-write. Since Phase 7a validated network isolation, this should only be needed if an undiscovered parameter consumer exists. Diagnosis: check which test fails, identify what it reads, trace to the parameter path.

**Phase 9 (rename)**: Trivially revertable — automated find-replace in both directions.

### Emergency Rollback

If multiple phases interact to produce a failure that no single revert fixes:
1. Identify the earliest phase where the failure first appears (bisect using phase commits)
2. Revert to that phase's predecessor
3. Re-analyze the design for that phase before re-attempting

This has not been needed in Tracks 1–5, but the protocol exists for completeness.

---

## §6b. D.2 Critique Resolution

The following critiques were raised in external review and resolved in the D.2 revision:

### CR-1: Phase 1c concurrency safety

**Critique**: The read-modify-write cycle in the functional constraint pattern could be unsafe under concurrent access.

**Resolution**: Constraint resolution is **strictly single-threaded**. `run-stratified-resolution!` runs in `parameterize ([current-in-stratified-resolution? #t])` and processes constraints sequentially. BSP parallel mode fires type propagators (Stratum 0) but constraint resolution (Stratum 2) is always sequential. No concurrent constraint retry exists. Added to Phase 1c.

### CR-2: Phase 1c lattice merge vs. non-monotonic status

**Critique**: Could constraint status use propagator-style lattice merge semantics?

**Resolution**: **No — constraint status is non-monotonic.** `'retrying → 'postponed` is a demotion, not a lattice join. The re-entrancy guard explicitly cycles status downward. `join('retrying, 'postponed)` has no valid definition. The state machine is a protocol, not a lattice. Added to Phase 1c.

### CR-3: Phase 1c cid stability

**Critique**: The functional pattern relies on cid lookups. Is cid stable?

**Resolution**: Constraint cid is a gensym, stable and unique for the lifetime of the constraint. No code path creates, deletes, or re-adds a constraint with an existing cid. This invariant ensures the functional pattern's cid lookup correctly identifies the "same" constraint. Added to Phase 1c.

### CR-4: Phase 2–4 belt-and-suspenders clarification

**Critique**: The relationship between TMS and network-box restore during Phases 2–4 was unclear.

**Resolution**: **Network-box restore is the production mechanism during Phases 2–4.** TMS is being validated in shadow mode — observed for correctness, not relied upon. A failure in TMS does not leave the system in an inconsistent state; network-box restore handles all speculation correctly while TMS is being proven. Added to Phase 2.

### CR-5: Phase 5 split into 5a/5b

**Critique**: Phase 5 conflated mechanical box reduction with the retirement gate.

**Resolution**: Split into Phase 5a (meta-info CHAMP → infrastructure cell, mechanical, mirrors Phase 1a) and Phase 5b (belt-and-suspenders retirement gate, concrete criteria). The retirement is a defined step with hard criteria, not a side-effect of box reduction.

### CR-6: Phase 6 parameter categorization

**Critique**: The design assumed all 26 batch-worker parameters are cell-based.

**Resolution**: Only 20 are cell-based (19 macros + 1 global-env). The 7 namespace.rkt parameters are runtime configuration (module-registry, ns-context, lib-paths, etc.) — genuinely per-file config, not reactive state. Hybrid approach: network snapshot for 20, `parameterize` for 7. Added to Phase 6.

### CR-7: Phase 7a time budget

**Critique**: The shadow phase lacked a concrete cost estimate.

**Resolution**: ~7 minutes one-time cost (200s baseline × 2). Single validation run, not ongoing. Small investment relative to the risk of discovering divergences after dual-write removal. Added to Phase 7a.

### CR-8: Phase 8a exhaustive categorization

**Critique**: The guard removal audit should be exhaustive, not sampled.

**Resolution**: Phase 8a now requires categorizing **every** cell reader call site into elaboration / module-loading / other contexts. If any reader falls into "other" (lacks network), guard removal is blocked until that context is migrated. This is the decision-making deliverable — everything after 8a is mechanical based on the categorization table. Updated Phase 8.

### CR-9: Phase 11 graduated performance criteria

**Critique**: The 25% performance threshold was binary — no guidance for intermediate regressions.

**Resolution**: Graduated criteria: <5% ship, 5–15% investigate and profile, >15% block. The Track 3 850s regression proves large regressions have discrete causes. Updated Phase 11.

### CR-10: Rollback procedures

**Critique**: No rollback plan for individual phases.

**Resolution**: Added §11 (Rollback Procedures) covering general rollback protocol, per-phase rollback notes, and emergency multi-phase rollback. Key insight: Phases 2–4 are inherently safe to revert because network-box restore remains the production mechanism. Phase 5b (retirement) is the most critical rollback scenario.

---

## §12. D.3 Self-Critique: Principle Alignment

Systematic check of Track 6 design against each principle in `DESIGN_PRINCIPLES.org`, plus tensions and gaps identified.

### Principle-by-Principle Assessment

#### Correct by Construction ✅ STRONG ALIGNMENT

Track 6's central arc is moving from a discipline-maintained dual-write system to a structurally correct single-write architecture. The current system requires discipline to keep parameters and cells in sync — every `register-X!` call must write to both, every save/restore must capture all three boxes, every elaboration guard must be checked. Track 6 eliminates the discipline requirement:

- **Single write path**: After Phase 7, cells are the sole write path. It's structurally impossible to forget the parameter write because there is no parameter write.
- **1-box save/restore**: After Phase 5a, network snapshot captures all state. It's structurally impossible to miss a box because there's only one box.
- **TMS retraction**: After Phase 5b, speculation correctness is a structural property of the TMS branch/retract mechanism, not a property maintained by correctly-ordered box swaps.

The belt-and-suspenders retirement gate (Phase 5b) is itself correct-by-construction thinking: don't remove the secondary path until the primary path has been structurally proven correct (0 divergences).

**No tension identified.**

#### Propagator-First Infrastructure ✅ STRONG ALIGNMENT

Track 6 completes the propagator-first migration started in the Migration Sprint. Every change moves state from parameters/boxes into the propagator network:

- Phase 1a: id-map → infrastructure cell
- Phase 1d: unsolved-metas → infrastructure cell
- Phase 5a: meta-info CHAMP → infrastructure cell
- Phases 7b–d: remove parameter write path entirely

After Track 6, the propagator network is the single source of truth for all elaboration state. `save-meta-state` becomes a single network CHAMP snapshot. This is the full realization of the principle: infrastructure as network-resident values with automatic dependency propagation.

**No tension identified.**

#### Data Orientation ✅ STRONG ALIGNMENT

Phase 1c is explicitly data-oriented: converting constraint status from in-place mutation (side effects embedded in control flow) to functional CHAMP updates (data transformations). The re-entrancy guard becomes a value check on the store rather than a mutation protocol. This aligns constraints with the propagator network's data-oriented model — constraint state transitions become cell writes, visible to TMS branching and network snapshots.

The design explicitly rejected the lattice merge approach (CR-2) because constraint status transitions are non-monotonic. This is the right call — data orientation means representing effects as data, not forcing everything into a lattice. The state machine is a protocol expressed as data transformations, not embedded in mutable control flow.

**No tension identified.**

#### First-Class by Default ⬜ NOT APPLICABLE

Track 6 is an infrastructure cleanup track — it removes transitional machinery, it doesn't introduce new language constructs. There are no new reification decisions. The principle doesn't apply directly.

**Observation**: Track 6 does make infrastructure cells more first-class in the network (id-map, unsolved-metas, meta-info become cells rather than separate boxes). This is the infrastructure corollary of first-class-by-default: state that participates in the network is more composable than state in ad-hoc boxes.

#### Simplicity of Foundation ✅ ALIGNMENT

Track 6 simplifies: 3 boxes → 1 box, 28+ dual-write paths → 28 single-write paths, ~30 `parameterize` bindings → ~5, 2 elaboration guard parameters → 0, 3 callback parameters → 0. Every change reduces the surface area of the infrastructure. The driver becomes simpler to understand and modify.

**No tension identified.**

#### Decomplection ✅ ALIGNMENT

The current system has coupled concerns:
- Parameter writes coupled with cell writes (dual-write)
- Elaboration context coupled with cell validity (guards)
- Speculation coupled with manual box management (3-box save/restore)
- Batch isolation coupled with parameter semantics (save/restore 26 params)

Track 6 decomplects each pair:
- Cell writes stand alone (Phases 7b–d)
- Cell reads are unconditional (Phase 8)
- Speculation uses TMS (Phase 5b)
- Batch isolation uses network snapshot (Phase 6)

**No tension identified.**

### Tensions and Gaps

#### T-1: Phase 6 Hybrid Approach — Partial Migration ⚠️ MINOR TENSION

Phase 6 introduces a hybrid: 20 cell-based parameters captured by network snapshot, 7 runtime config parameters kept as `parameterize`. This is pragmatically correct — the 7 namespace.rkt parameters are genuinely per-file configuration, not reactive state. But it means the batch-worker still has a `parameterize` block, just smaller (7 instead of 26+). The "clean driver" goal (§1.2) is partially met.

**Assessment**: Acceptable. Moving configuration into cells would be architecturally wrong (violating propagator-first's "When Not To Use Propagators" section — the access pattern is pure lookup with no dependency tracking). The tension is cosmetic, not structural. The 7 remaining parameters are correctly categorized as configuration, not elaboration state.

#### T-2: Phase 8 Guard Removal — Open Question Remains ⚠️ DESIGN RISK

The §6 "Remaining Open Questions" section identifies that elaboration guard removal depends on Phase 8a's exhaustive audit. If the audit finds cell readers called in "other" contexts (test setup, batch-worker init, REPL) that lack networks, guard removal is blocked.

**Assessment**: The design correctly identifies this as a runtime discovery, not a design-time decision. Phase 8a is the decision-making deliverable — everything after it is conditional on the categorization results. The risk is properly managed. But the design should acknowledge the **fallback**: if guards can't be removed for some readers, the cleanup is partial, and the driver simplification (Phase 10) target of "~5 bindings" may be higher.

**Action**: Add a note to Phase 10 that the binding count target depends on Phase 8's outcome.

#### T-3: Callback Parameter Removal — Insufficient Analysis ⚠️ GAP

Phase 8d says "remove callback parameters (or mark deprecated if edge cases found)" but the §2.6 analysis only identifies 3 callbacks with reference counts. It doesn't trace each reference to confirm whether the stratified quiescence scheduler handles every case. The callbacks might be invoked from code paths outside the standard elaboration loop (e.g., module loading, batch processing) where the reactive scheduler isn't active.

**Assessment**: The Phase 8a audit (strengthened in D.2 to exhaustive categorization) should cover this — callback usage sites fall into the same elaboration/module-loading/other categorization. But the design should explicitly note that callback references must be traced as part of 8a, not just guard references.

**Action**: Add callback reference tracing to Phase 8a's scope.

#### T-4: Speculation Stats as Correctness Metric — Necessary but Insufficient ⚠️ SUBTLE RISK

Multiple phases use "speculation stats (hypotheses, nogoods, pruning) match Phase 0 baseline" as a correctness criterion. This catches divergences where TMS produces different branching behavior. But it doesn't catch the case where TMS produces the **same stats but different values** — e.g., the same number of hypotheses but with different cell values in the committed branch.

**Assessment**: The belt-and-suspenders comparison (Phases 2–4) catches value divergences, not just stat divergences. The stats metric is an additional fast-check, not the sole correctness criterion. The done-when checklists correctly list "0 divergences" as the primary criterion and "stats unchanged" as a secondary sanity check. No action needed — the design is correct, but the distinction should be understood: stats match is a necessary but not sufficient correctness condition. The sufficient condition is the 0-divergence belt-and-suspenders comparison.

#### T-5: WS-Mode Validation — Track 6 Is Infrastructure, Not Syntax ⬜ LOW RISK

Track 6 adds no new user-facing syntax. The three-level WS validation protocol's Level 3 testing is addressed by the acceptance file (run before and after each phase), but there's no new WS syntax to validate. The acceptance file is a regression net, not a feature showcase.

**Assessment**: Correct approach. The acceptance file catches regressions introduced by infrastructure changes (e.g., if removing dual-write breaks something that test-support relied on, the acceptance file at L3 catches it). No WS Impact section is needed because there are no WS changes.

#### T-6: Phase Ordering Optimality — Could Phase 9 Run Earlier? ⬜ OBSERVATION

The dependency DAG (§10) notes that Phase 9 (rename) "could also run after Phase 1b." The current plan places it after Phase 8, which means it's blocked by the entire Workstream B chain. Running it earlier would provide a quick win and reduce the pending rename debt.

**Assessment**: Phase 9 is purely mechanical (find-replace + compile check) and has no interactions with any other phase except that `current-global-env` references exist throughout the codebase. Running it after Phase 1b is safe and would reduce cognitive overhead during subsequent phases (the correct name `current-prelude-env` makes the code clearer). Consider opportunistically running Phase 9 early if there's a natural break between Phase 1d and Phase 2.

### Methodology Alignment

#### Design Methodology Stage 3 Checklist

| Requirement | Status |
|-------------|--------|
| Comprehensive first draft (data structures, phases, tests) | ✅ D.1 |
| Adversarial critique invited | ✅ D.1+ (internal) + D.2 (external) |
| Phase dependencies are architecture | ✅ §10 DAG |
| Concrete over abstract (examples, code) | ✅ §2 code snippets, §4 before/after patterns |
| Test strategies per phase | ✅ Every phase has test strategy + done-when |
| Tradeoff matrices | ✅ §5 Risk Analysis |
| Principle alignment check | ✅ This section (D.3) |
| Record of critique and responses | ✅ §6 (D.1+) + §6b (D.2) |

#### Development Lessons Applied

| Lesson | Application |
|--------|-------------|
| Completeness over deferral | Track 6 absorbs 9 deferred items from Tracks 3–5 |
| Phase-gated with sub-phases | 17 sub-phases (1a–1d, 5a–5b, 7a–7d, 8a–8d) |
| Tracking document before code | This document |
| Deferred work triaged | §7 — 9 absorbed, 3 remain deferred |
| Three-level WS validation | Acceptance file at L3 per-phase |
| Performance baseline comparison | Phase 0 + Phase 11 graduated criteria |
| Shared fixture pattern | Not directly applicable (Track 6 doesn't add tests, it migrates infrastructure) |

### Summary

**6 principles aligned, 0 tensions with principles, 6 observations/gaps identified:**

1. T-1 (Phase 6 hybrid): Cosmetic, not structural — correct categorization of config vs. state
2. T-2 (Phase 8 guard removal): Risk properly managed by Phase 8a audit, but Phase 10 target should note dependency
3. T-3 (Callback tracing): Phase 8a scope should explicitly include callback references
4. T-4 (Stats metric): Necessary but not sufficient — belt-and-suspenders comparison is the sufficient condition
5. T-5 (WS validation): Not applicable — infrastructure track, acceptance file is the right approach
6. T-6 (Phase 9 ordering): Opportunistic early execution is safe and provides quick clarity win
