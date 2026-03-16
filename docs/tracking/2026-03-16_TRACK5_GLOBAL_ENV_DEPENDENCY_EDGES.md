# Track 5: Global-Env Consolidation + Persistent Module Networks + Dependency Edges — Stage 2/3 Design

**Created**: 2026-03-16
**Status**: DESIGN (Stage 2/3)
**Depends on**: Track 3 ✅ (Cell-Primary Registries), Track 4 ✅ (ATMS Speculation)
**Enables**: Track 6 (Driver Simplification + Cleanup), Track 9 (GDE)
**Master roadmap**: `2026-03-13_PROPAGATOR_MIGRATION_MASTER.md` Track 5
**Prior art**: Track 3 PIR (elaboration guard pattern), Track 4 PIR (dual-write coherence)

---

## Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| D.1 | Initial design document | ✅ | `339fedb` |
| D.2 | Design discussion + rework | ✅ | `17142ec` — persistent networks, cross-module edges, lifecycle, TMS discussion |
| D.2+ | External critique incorporation | ✅ | `b0c63bc` — Shadow-cell pattern, staleness model, performance hypotheses, non-goals, rollback |
| D.3 | Self-critique (principle alignment) | ✅ | Principle alignment check: 6 aligned, 3 tensions noted; deferred items to Track 6 + LSP |
| 0 | Performance baseline + acceptance file | ✅ | `157f7aa` — 294 pass, 0 errors, 12 BUGs commented |
| 1 | Persistent module network infrastructure + cross-network prototype | ✅ | `7ad5b88` — lifecycle lattice, module-network-ref CRUD, shadow-cell prototype (15 tests) |
| 2 | Definition removal → cell-aware cleanup | ✅ | `085b77d` — `global-env-remove!`, `definition-cell-remove!`, 6 sites consolidated |
| 3 | Per-module network activation | ✅ | `011fe3f` — removed #f overrides, module-network-ref built per-module, dual-path validation (0 mismatches across 200+ modules) |
| 4 | Cross-module dependency edges | ✅ | `b70331a` — `record-cross-module-dep!`, same-file + module edges in lookup-type, dep-edges in module-network-ref |
| 5 | Write consolidation + `module-network-ref` cutover | ⬜ | Env-threading cleanup, drop materialized hash |
| 6 | Performance validation + PIR | ⬜ | Compare against hypotheses |

---

## Non-Goals

Track 5 does NOT deliver:

- **TMS-aware module definition cells** — designing for TMS-compatible API (Track 5), but implementation of parameterized module contexts is a Track 6 design concern (noted in master roadmap)
- **Automatic re-elaboration on staleness** — Track 5 wires the edges and marks staleness; the re-elaboration trigger is LSP scope
- **Definition-level incremental recompile** — Track 5 marks *which* definitions are stale; actually re-elaborating only those definitions is LSP scope
- **Dual-write parameter elimination** — Track 5 keeps belt-and-suspenders; Track 6 removes the parameter path
- **Elaboration guard removal** — Track 5 gives module loading networks (eliminating the root cause); Track 6 removes the now-unnecessary guards

---

## 1. Problem Statement

The global environment is the backbone of the Prologos compilation pipeline — every definition lookup, every module import, every name resolution flows through it. After four tracks of propagator migration, global-env is the last major subsystem with significant legacy parameter traffic.

Currently:
- **269 files** reference `(current-global-env)` (the Layer 2 parameter)
- **36+ references** in `driver.rkt` alone use the env-threading pattern `(current-global-env (global-env-add (current-global-env) ...))`
- **12 `hash-remove` calls** in `driver.rkt` clean up pre-registered definitions on elaboration failure
- **Module loading** runs with `current-global-env-prop-net-box = #f` — no network, parameter-only
- **Definition dependencies** are recorded informationally (`current-definition-dependencies`) but not wired as propagator edges
- **Module caching** materializes flat hasheq snapshots — dead copies with no live connection to the source module

The two-layer architecture (Migration Sprint Phase 3a–3d) was the right de-risking step: Layer 1 (per-file cells) handles elaboration-time definitions, Layer 2 (parameter) handles prelude/module definitions. But the two-context split means 28 cell-primary readers from Track 3 need elaboration guards, and module loading cannot benefit from any cell infrastructure.

**Scope reframing**: The master roadmap describes Track 5 as "convert remaining `(current-global-env)` reads." The actual audit reveals these are overwhelmingly *writes* (~23 via `global-env-add`), not reads — the reads already go through cell-primary `global-env-lookup-*` (Track 3a-d). Track 5's true scope is: **consolidate global-env interaction patterns, create persistent per-module networks, and wire cross-module dependency edges**.

### What Track 5 achieves

1. **Persistent per-module networks** — each loaded module gets its own persistent `prop-network` holding definition cells, cached as a live `module-network-ref` rather than a materialized hasheq. Consumers read from the module's cells, not dead copies.
2. **Module lifecycle lattice** — a `mod-status` cell per module network with states `loaded | stale | reloading`, giving the LSP a single cell to watch for invalidation.
3. **Cross-module dependency edges** — when file `foo` references `bar::map`, a shadow cell in `foo`'s network mirrors `bar`'s `map` cell. When `bar` changes, only definitions in `foo` that transitively depend on changed definitions are marked stale. Minimum recompute.
4. **Definition failure cleanup consolidation** — the 12 inline `hash-remove` sites become `global-env-remove!` operating on both layers.
5. **Env-threading write consolidation + `module-network-ref` cutover** — the 36+ `(current-global-env (global-env-add ...))` calls become direct `global-env-add`, and consumers migrate from materialized hasheq to cell-based reads.

The "biggest payoff" from the Pipeline Audit: incremental module re-elaboration. Combined with Track 4's ATMS, the LSP can retract a definition assumption and let propagation settle rather than re-elaborating an entire file.

---

## 2. Architectural Foundation: Persistent Module Networks

### 2.1 Key insight: networks are CHAMP-based

The existing `prop-network` is built on immutable CHAMP maps. All operations create new network structs with modified CHAMP references — O(1) snapshots via structural sharing. This means:

- **"Separate network per module" and "shared pointers to common structure" are the same thing at the CHAMP level.** Two module networks that share common definitions (e.g., both import the prelude) share CHAMP nodes for those cells. Logically separate (`prop-network` structs), physically sharing.
- **Persistence is free.** Keeping a module's network alive is just keeping the CHAMP references alive instead of discarding them.

### 2.2 What persists vs. what's ephemeral

The network holds **definition cells** — the stable part:
- Type cells (definition's inferred/checked type)
- Value cells (definition's elaborated body)
- Dependency edge propagators (wired between definition cells)
- `mod-status` cell (lifecycle state)

Per-command state is **ephemeral** and lives outside the module network:
- `current-mult-meta-store` — fresh per-command (meta variables are local)
- `current-constraint-store` — fresh per-command
- Various flags: `current-macros-in-elaboration?`, elaboration depth, etc.
- The per-command elab-network created by `reset-meta-store!`

This separation is already the architecture: `reset-meta-store!` creates a fresh elab-network per command for metas/constraints, while `current-definition-cells-content` persists across commands. Track 5 makes this explicit: the module network persists in the cache; the per-command network is created and discarded as before.

### 2.3 Cross-module reads: the shadow-cell pattern

**The problem**: Propagators exist WITHIN a single `prop-network`. A propagator registered in network X fires when cells in network X change, and writes to cells in network X. There is no built-in cross-network scheduling — `net-add-cross-domain-propagator` operates within one network, bridging different lattice domains, not different network instances.

**The solution: shadow cells + invalidation callbacks**.

When file `foo` imports definition `bar::map`:

1. `foo`'s network creates a **local shadow cell** initialized from `bar`'s `map` cell value
2. Within `foo`'s network, all propagators reference the local shadow cell — normal within-network propagation
3. The dependency is recorded: "foo's shadow-bar-map mirrors bar's map cell"

In **batch mode**, the shadow cell is initialized once. `bar` doesn't change during batch. No callbacks fire.

In **LSP mode**, when `bar` reloads:
1. The LSP iterates `bar`'s dependents (via `dep-edges` in `module-network-ref`)
2. For each dependent, the LSP updates the shadow cell with `bar`'s new cell value
3. The shadow cell write triggers normal within-network propagation in `foo`'s network
4. Only definitions in `foo` that transitively depend on `bar::map` (via propagators wired to the shadow cell) are affected

This is the right design — not a compromise. Cross-network propagation in the scheduler sense (one run loop spanning multiple networks) would be a complexity explosion. Module dependencies form a DAG. The LSP walks the DAG. Within each network, propagation is local and uses proven infrastructure.

**Correctness scope**: Shadow-cell consistency is correct-by-construction for batch mode (single invocation — initialize once, never update). For multi-invocation contexts (LSP), a correct-by-construction sync mechanism is needed to prevent divergence between shadow cells and source cells. This is a Track 6 design concern (see §13.2). Track 5's shadow cells are correct for batch; the LSP track must provide structural consistency guarantees.

```
┌─────────────────────────┐         ┌─────────────────────────┐
│  Module bar             │         │  File foo               │
│  (module-network-ref)   │         │  (per-file network)     │
│                         │         │                         │
│  ┌───────────────┐      │  init   │  ┌───────────────┐      │
│  │ cell: map     │──────┼─────────┼─▶│ shadow: b.map │      │
│  │ type: A → B   │      │         │  │ (local cell)  │      │
│  │ value: <fn>   │      │         │  └───────┬───────┘      │
│  └───────────────┘      │         │          │ propagator   │
│                         │         │          ▼              │
│  ┌───────────────┐      │         │  ┌───────────────┐      │
│  │ mod-status    │      │         │  │ cell: usesMap │      │
│  │ = loaded      │      │         │  │ (depends on   │      │
│  └───────────────┘      │         │  │  shadow)      │      │
│                         │         │  └───────────────┘      │
└─────────────────────────┘         └─────────────────────────┘
        │                                      │
        │  On bar reload (LSP):                │
        │  1. LSP reads new bar::map value     │
        │  2. LSP writes to foo's shadow cell  │
        │  3. foo's propagators fire locally   │
        └──────────────────────────────────────┘
```

### 2.4 `module-network-ref`: the new module cache type

Currently `module-info` stores `env-snapshot` as a flat `hasheq` of `symbol → (cons type value)`. Track 5 replaces this with a `module-network-ref` struct:

```racket
(struct module-network-ref
  (prop-net          ;; the persistent prop-network
   cell-id-map       ;; hasheq: symbol → cell-id (for definition lookup)
   mod-status-cell   ;; cell-id of the mod-status cell
   dep-edges)        ;; hasheq: symbol → (listof dep-edge-info)
  #:transparent)
```

**Backwards compatibility strategy** (Phase 3 → Phase 5 migration):

Audit of all `env-snapshot` consumers reveals two usage patterns:
- `(for ([(k v) (in-hash snapshot)])` — iteration (driver.rkt:1523, driver.rkt:1344)
- `(hash-ref snapshot name)` — point lookup (capability-inference.rkt, cap-type-bridge.rkt, tests)

No consumers use `hash-keys`, `hash-values`, `hash-count`, `equal?`, or pattern matching.

**Phase 3 (belt-and-suspenders)**: `module-network-ref` contains BOTH the live network AND a materialized hash. Consumers use the materialized hash. Assertions verify agreement between cell reads and hash reads.

**Phase 5 (cutover)**: Migrate consumers to `module-network-ref-lookup` (cell read) and `in-module-network-ref` (iteration sequence). Drop the materialized hash. This completes the transition to live cell reads.

### 2.5 Definition cell value schema

```racket
;; Definition cell value — one of:
;;   #f                         — removed/uninitialized (sentinel)
;;   (cons Type #f)             — type-only (forward declaration)
;;   (cons Type Value)          — fully elaborated definition
```

`global-env-lookup-type` and `global-env-lookup-value` already check for `#f` and return `#f` (not found). The sentinel value is the same whether the cell was never written or was explicitly cleared by `definition-cell-remove!`.

Future (Track 6+, if TMS-aware module cells): cells may hold `(tms-cell-value ...)` wrapping the above schema. The `#:tms?` flag on `make-module-network` controls this.

### 2.6 Module lifecycle lattice

Drawing on the lifecycle patterns across existing domain sub-graphs:

| Domain | Lifecycle | Lattice | Bridge mechanism |
|--------|-----------|---------|-----------------|
| Session | `sess-bot → send/recv/... → sess-top` | `session-lattice-merge` | cross-domain propagator (α/γ) |
| Effect | `eff-bot → eff-position → eff-top` | unidirectional α from session | `add-session-effect-bridge` |
| IO | `io-bot → io-opening → io-open → io-closed → io-top` | `io-lattice-merge` | Gauss-Seidel scheduler |
| **Module** | `mod-loading → mod-loaded → mod-stale` | `mod-status-merge` | shadow-cell invalidation callbacks |

The module lifecycle lattice:
- `mod-loading` → module is being elaborated (definitions being added)
- `mod-loaded` → all definitions elaborated successfully, network stable
- `mod-stale` → a dependency changed, module needs re-elaboration

**Staleness is monotonic**: once a dependency changes, the module is stale until explicitly reloaded. The `mod-status` cell uses a merge function where `stale` dominates `loaded` (once stale, stays stale). Reloading resets to `mod-loading` (non-monotonic — requires a fresh network or cell reset).

### 2.7 Staleness model

Two distinct staleness concepts interact:

**Definition staleness** (implicit): A definition's shadow cell value differs from the source module's cell value. This is detected by the propagator infrastructure — `net-cell-write` compares `(merge old new)` against `old`. If the merged value equals the old value, no change occurred and no propagators fire. This means: if `bar` is reloaded and `bar::map`'s type+value are identical, `foo`'s shadow cell write is a no-op. `foo` is NOT marked stale. Correct behavior — identical definitions don't trigger recomputation.

**Module staleness** (explicit): The `mod-status` cell tracks whether the module as a whole needs re-elaboration. When any definition cell in a module receives a value-changing write via an incoming cross-module edge, a propagator writes `mod-stale` to that module's `mod-status` cell.

The relationship: definition staleness is fine-grained (per-definition, implicit in cell values). Module staleness is coarse-grained (per-module, explicit in `mod-status` cell). The LSP watches `mod-status` for coarse invalidation, then inspects individual definition cells for fine-grained recompute decisions.

---

## 3. Infrastructure Gap Analysis

### What we have (from Tracks 1–4)

| Infrastructure | Status | Location |
|----------------|--------|----------|
| Per-definition cells in prop-network | ✅ | `global-env.rkt` Phase 3a — `definition-cell-write!`, `register-global-env-cells!` |
| Two-layer lookup (`global-env-lookup-type`/`value`) | ✅ | `global-env.rkt` — Layer 1 first, Layer 2 fallback |
| Definition dependency recording | ✅ | `global-env.rkt` Phase 3b — `record-definition-dependency!`, informational edges |
| Elaboration guard pattern | ✅ | Track 3 — `current-macros-in-elaboration?`, `current-narrow-in-elaboration?` |
| TMS cells for speculation | ✅ | Track 4 — `tms-cell-value`, depth-0 fast path |
| Cross-domain propagators | ✅ | `propagator.rkt` — `net-add-cross-domain-propagator` with α/γ (within one network) |
| Error descriptor cell | ✅ | Track 2 Phase 7 — `current-error-descriptor-cell-id`, `read-error-descriptors` |
| Cell-primary readers for all registries | ✅ | Track 3 — 28 readers across macros.rkt, warnings.rkt, global-constraints.rkt |
| merge-replace for definition cells | ✅ | `infra-cell.rkt` — last-write-wins for non-monotonic definitions |
| CHAMP structural sharing | ✅ | `propagator.rkt` — all network operations are O(log N), O(1) snapshots |

### What we need

| Gap | Required for | Complexity |
|-----|-------------|-----------|
| `module-network-ref` struct | Persistent module cache (Phase 1) | Medium — new struct, dual hash+network during transition |
| `mod-status` cell + lifecycle lattice | Module invalidation (Phase 1) | Low — new merge fn, single cell per module |
| Shadow-cell creation + callback registration | Cross-module reads (Phase 1 prototype, Phase 4 full) | Medium — new pattern, prototype early |
| `global-env-remove!` helper | Failure cleanup consolidation (Phase 2) | Low — mirror `global-env-add` for removal |
| Remove `#f` overrides in module loading | Module loading cell path (Phase 3) | Medium — behavior change, wide test coverage |
| Consumer migration to cell reads | `module-network-ref` cutover (Phase 5) | Low — 2 iteration sites, 3 lookup sites |

---

## 4. Audit: `(current-global-env)` References in driver.rkt

### Category A: Writes via `global-env-add` / `global-env-add-type-only` (~23 sites)

Pattern:
```racket
(current-global-env
 (global-env-add (current-global-env) name zonked-type zonked-body))
```

These are **already routed through the two-layer dispatch**. `global-env-add` checks `current-global-env-prop-net-box`:
- When network present (elaboration): writes to Layer 1 cells, returns env UNCHANGED
- When no network (module loading): writes to Layer 2 parameter, returns updated hasheq

The `(current-global-env ...)` wrapper updates Layer 2, but during elaboration it's a no-op (the return value equals the input). During module loading it correctly updates the parameter.

**Conversion**: Once module loading has networks (Phase 3), the wrapper becomes redundant everywhere. Cleaned up in Phase 5.

### Category B: Failure cleanup via `hash-remove` (~12 sites)

Pattern:
```racket
(current-definition-cells-content (hash-remove (current-definition-cells-content) name))
(current-global-env (hash-remove (current-global-env) name))
```

These remove pre-registered definitions when elaboration, type-checking, or constraint resolution fails. They operate on both layers. There is no `global-env-remove!` helper — the removal is inline.

**Conversion**: Extract `global-env-remove!` in Phase 2.

### Category C: Module loading setup (~5 sites)

Pattern:
```racket
(parameterize ([current-global-env (hasheq)] ...)
  ...)
```

Module loading creates a fresh Layer 2 env, processes module commands, then snapshots the result. `process-command` is called inside module loading, which already sets up a per-command network (via `reset-meta-store!`), but `current-global-env-prop-net-box` is parameterized to `#f`, forcing the legacy path.

**Key insight**: Module loading already calls `process-command`, which already creates a per-command network. The two-context split exists because the outer `parameterize` sets `current-global-env-prop-net-box = #f`. Removing this override is the core of Phase 3.

### Category D: Foreign function registration (~2 sites)

Same as Category A — `global-env-add` already dispatches. Foreign registration happens inside `process-command` scope.

---

## 5. Design: Phased Implementation

### Phase 0: Performance Baseline + Acceptance File

**Goal**: Establish baseline, create acceptance file, state performance hypotheses.

- Run full test suite, record timing and test count
- Create `examples/2026-03-16-track5-acceptance.prologos` exercising:
  - Definitions that reference prior definitions (dependency edges)
  - Module imports with re-exported definitions
  - Cross-module dependency chains (A imports B imports C)
  - Definition failure cases (type error in body → cleanup visible)
  - All prelude features (regression net)
- Record acceptance file baseline (L3 via `process-file`)

**Performance hypotheses** (to be validated in Phase 6 PIR):

| Operation | Current | Track 5 | Expected change |
|-----------|---------|---------|-----------------|
| Definition lookup | `hasheq` O(1) | Cell read O(1) | Equivalent — both are hash lookups (CHAMP vs hasheq) |
| Module load | Accumulate in hasheq | Accumulate in cells | Equivalent — same number of writes, different target |
| Module snapshot | Materialize hasheq | Return `module-network-ref` | Faster — no copy, just wrap reference |
| Cross-module lookup | `hash-ref` on snapshot | Local shadow cell read | Equivalent — shadow cell initialized once, reads are local O(1) |
| Module import (caller) | `in-hash` iteration + `hash-set` per entry | Shadow cell creation per used definition | Potentially faster — lazy (only used defs), not eager (all defs) |
| Memory (15 prelude modules) | 15 flat hasheq snapshots | 15 persistent networks | Comparable — CHAMP sharing means networks share structure |
| Dependency edge wiring | N/A (informational only) | One propagator per cross-def reference | Small overhead — only value-changing lookups wire edges |

Overall hypothesis: **Track 5 should be performance-neutral or slightly faster** due to eliminating snapshot materialization and making module imports lazy (shadow cells created only for actually-referenced definitions, vs current eager copy of all module definitions).

### Phase 1: Persistent Module Network Infrastructure + Cross-Network Prototype

**Goal**: Create the new primitives and validate the cross-network pattern early.

**Files**: `global-env.rkt`, `namespace.rkt`, `infra-cell.rkt`, `elaborator-network.rkt`

**1a: Module lifecycle lattice** in `infra-cell.rkt`:

```racket
;; Module lifecycle states
(define mod-loading 'mod-loading)
(define mod-loaded  'mod-loaded)
(define mod-stale   'mod-stale)

;; Merge: stale dominates loaded; loading < loaded < stale
(define (mod-status-merge old new)
  (cond
    [(eq? new mod-stale) mod-stale]   ;; stale always wins
    [(eq? old mod-stale) mod-stale]   ;; once stale, stays stale
    [(eq? new mod-loaded) mod-loaded] ;; loaded beats loading
    [else old]))
```

**1b: `module-network-ref` struct** in `namespace.rkt` (or new `module-network.rkt`):

```racket
(struct module-network-ref
  (prop-net          ;; persistent prop-network with definition cells
   cell-id-map       ;; hasheq: symbol → cell-id
   mod-status-cell   ;; cell-id for lifecycle monitoring
   dep-edges         ;; hasheq: symbol → (listof dep-edge-info)
   snapshot-hash)    ;; hasheq or #f — materialized hash (belt-and-suspenders, Phase 3-4)
  #:transparent)
```

`make-module-network` factory:
1. Creates a fresh `prop-network`
2. Creates a `mod-status` cell initialized to `mod-loading`
3. Returns a `module-network-ref` with empty cell-id-map, dep-edges, and snapshot-hash = `#f`

**1c: Shadow-cell prototype** — validate the cross-network pattern before building on it:

```racket
;; Prototype test (unit test, not wired into pipeline):
;; 1. Create two prop-network instances (A = "module bar", B = "file foo")
;; 2. Create cell in A: bar-map-cell with value (cons type value)
;; 3. Create shadow cell in B: shadow-bar-map initialized from A's cell value
;; 4. Create propagator in B: when shadow-bar-map changes, write to foo-result-cell
;; 5. Simulate "bar reloads": read new value from A, write to B's shadow cell
;; 6. Verify: foo-result-cell updated via normal propagation in B's network
```

This prototype resolves the key architectural uncertainty early. If the pattern doesn't work, we redesign before Phase 2.

**Phase 1 is infrastructure-only** — no behavior change. Module loading still uses the parameter path.

**Deliverable**: New primitives, unit tests for lifecycle merge, `module-network-ref` lookup, shadow-cell prototype passing.

### Phase 2: Definition Removal → Cell-Aware Cleanup

**Goal**: Extract `global-env-remove!` helper; consolidate 12 failure cleanup sites.

**Files**: `global-env.rkt`, `driver.rkt`

New helper in `global-env.rkt`:

```racket
(define (global-env-remove! name)
  ;; Layer 1: remove from per-file definitions content
  (current-definition-cells-content
   (hash-remove (current-definition-cells-content) name))
  ;; Layer 1: write sentinel to cell (not delete — cell stays, value = #f)
  (definition-cell-remove! name)
  ;; Layer 2: remove from prelude env parameter
  (current-global-env
   (hash-remove (current-global-env) name)))
```

`definition-cell-remove!` writes `#f` (sentinel) to the cell. `global-env-lookup-type`/`value` already handle `#f` entries (return `#f`).

Convert all 12 failure cleanup sites from inline `hash-remove` × 2 layers to `(global-env-remove! name)`.

**Deliverable**: Helper extracted, 12 sites consolidated, failure test suite passes.

### Phase 3: Per-Module Network Activation

**Goal**: Remove `#f` overrides so module loading runs with networks. Dual-path validation.

**Files**: `driver.rkt`, `namespace.rkt`, `global-env.rkt`

**3a: Remove network overrides** in module loading:

```racket
;; BEFORE (current):
[current-prop-net-box #f]
[current-global-env-prop-net-box #f]

;; AFTER (Track 5):
;; Remove these overrides. process-command will create per-command networks
;; and set up global-env-prop-net-box via its own parameterize.
```

**3b: Create module network at load start**: Before the module's command loop, call `make-module-network`. As `process-command` processes each module form, definitions are written to both the per-command network cells (ephemeral) and the module's persistent network cells (via `definition-cell-write!` targeting the module network).

**3c: Module env snapshot → dual-path `module-network-ref`**: At the end of module loading, store the `module-network-ref` in `module-info`'s `env-snapshot` field. Set `mod-status` to `mod-loaded`. **Also materialize the snapshot hash** (same as current behavior) and store it in `module-network-ref`'s `snapshot-hash` field. Consumers continue reading from the hash.

**3d: Dual-path validation**: After storing the `module-network-ref`, assert that every entry in `snapshot-hash` agrees with the corresponding cell read:

```racket
(for ([(name entry) (in-hash (module-network-ref-snapshot-hash mnr))])
  (define cell-val (module-network-ref-lookup mnr name))
  (unless (equal? entry cell-val)
    (error 'module-load "Cell/hash mismatch for ~a: cell=~a hash=~a"
           name cell-val entry)))
```

This assertion runs during testing and catches any dual-write divergence immediately.

**Accumulation semantics**: Module loading currently accumulates definitions in `(current-global-env)` across commands. With networks, definitions accumulate in `current-definition-cells-content` (Layer 1), which also persists across commands. Accumulation behavior is preserved — now through cells.

**Belt-and-suspenders**: During Phase 3, keep Layer 2 writes (dual-write). Module loading writes to both cells and parameters. The validation assertion catches any divergence.

**Risk**: High. Module loading is exercised by every test using `(ns test-X)` — 200+ test files. But this wide coverage is also the mitigation: regressions surface immediately.

**Rollback plan**: If >10% of tests fail after Phase 3 dual-write and the failures aren't readily diagnosable, revert by restoring the `#f` overrides. Phase 3 changes should be a single commit for easy revert. Define abort criteria: if a fundamental incompatibility is discovered between per-command network semantics and module loading semantics (e.g., `reset-meta-store!` side effects that break module accumulation), pause Track 5 and redesign.

### Phase 4: Cross-Module Dependency Edges

**Goal**: Wire dependency edges both within a file and across module boundaries. This is the high-value deliverable.

**Files**: `global-env.rkt`, `driver.rkt`, `elaborator-network.rkt`

**4a: Same-file dependency edges** (the simpler case):

When elaboration references a prior definition via `global-env-lookup-*`, wire a propagator edge from the source definition's cell to the current definition's cell:

```racket
(when (and elab-name (current-global-env-prop-net-box))
  (define dep-cell-id (hash-ref (current-definition-cell-ids) name #f))
  (define elab-cell-id (hash-ref (current-definition-cell-ids) elab-name #f))
  (when (and dep-cell-id elab-cell-id)
    (definition-dep-wire! dep-cell-id elab-cell-id name elab-name)))
```

**4b: Cross-module dependency edges** (the high-value case):

When file `foo` looks up `bar::map`, the definition lives in `bar`'s persistent `module-network-ref`. Create a shadow cell in `foo`'s network, initialized from `bar`'s cell value, and wire within-network propagators from the shadow cell:

```racket
;; foo's network gets a local shadow cell for bar::map
(define bar-mnr (module-info-env-snapshot bar-module-info))
(define bar-map-val (module-network-ref-lookup bar-mnr 'map))
(define shadow-cell-id (create-shadow-cell! bar-map-val))
;; Record cross-module edge for LSP invalidation
(register-cross-module-edge! bar-mnr 'map shadow-cell-id)
;; Wire within-network: shadow cell → foo's dependent definition cell
(definition-dep-wire! shadow-cell-id elab-cell-id 'bar::map elab-name)
```

**4c: TMS-ready edge API**:

There is one edge type. Every edge has an `assumption` field. `#f` means unconditional (always believed). This avoids future migration — Track 6 or LSP can pass real TMS assumptions without changing the edge type.

```racket
(define (definition-dep-wire! src-cell dst-cell src-name dst-name
                              #:assumption [assumption #f])
  ;; Create propagator: when src-cell changes, mark dst-cell stale
  ;; If assumption is non-#f, propagator only fires when assumption is believed
  ...)
```

**4d: Staleness propagation to `mod-status`**:

When any definition cell in a module receives a value-changing write via an incoming cross-module edge, a propagator writes `mod-stale` to that module's `mod-status` cell. The LSP watches one cell per module, not every definition cell.

**What the edges provide immediately** (batch mode):
- Observable dependency graph via cell inspection (tooling, debugging)
- Validation that dependency recording matches cell wiring (any missed edge = a bug)
- Foundation for incremental re-elaboration (LSP — connect a re-elaboration trigger to the shadow cell callback)

### Phase 5: Write Consolidation + `module-network-ref` Cutover

**Goal**: Clean up env-threading, migrate consumers from materialized hash to cell reads.

**Files**: `driver.rkt`, `capability-inference.rkt`, `cap-type-bridge.rkt`

**5a: Env-threading cleanup**: With module loading running through networks (Phase 3), the `(current-global-env (global-env-add ...))` wrapper is truly redundant everywhere. Simplify all 23 Category A sites to just `(global-env-add ...)`.

**5b: Consumer migration**: The dual-path validation (Phase 3d) has been running since Phase 3. With confidence established:

- `driver.rkt:1523` — `(for ([(k v) (in-hash (module-info-env-snapshot cached))])` → iterate via `module-network-ref` cells
- `driver.rkt:1344` — `(for ([(name entry) (in-hash (global-env-snapshot))])` → iterate via cell-based snapshot
- `capability-inference.rkt`, `cap-type-bridge.rkt` — use `module-network-ref-lookup` for env reads
- Tests — update `global-env-snapshot` calls

**5c: Drop materialized hash**: Set `module-network-ref`'s `snapshot-hash` to `#f` (no longer materialized). Remove the dual-path validation assertion. The transition is complete.

**Deliverable**: All env-threading wrappers removed. All consumers reading from cells. Acceptance file passes at L3. Full test suite 0 failures.

### Phase 6: Performance Validation + PIR

- Run full suite, compare against Phase 0 baseline and performance hypotheses
- Run acceptance file at L3
- Measure specifically:
  - Module load time (cell writes vs hasheq accumulation)
  - Module snapshot time (network-ref wrapping vs hasheq materialization)
  - Cross-module lookup time (shadow cell read vs hasheq read)
  - Memory footprint (15 persistent networks vs 15 hasheq snapshots)
  - Propagator count per typical file compilation (how many dependency edges?)
- Compare measured values against Phase 0 hypotheses table
- Write PIR following methodology

---

## 6. Design Decision: TMS-Awareness

### Dependency edges: TMS-ready API, plain implementation

There is one edge type: `definition-dep-wire!` with `#:assumption` parameter. In Track 5, all edges pass `#f` (unconditional — always believed). The API is ready for Track 6 or LSP to pass real TMS assumptions.

This is the belt-and-suspenders principle applied forward: **design for TMS, implement with plain edges, upgrade is adding one argument**.

### Module definition cells: TMS-compatible API, plain cells

The `module-network-ref` API is TMS-cell-compatible. `make-module-network` can take an optional `#:tms?` flag that creates TMS cells instead of plain cells. Default is plain cells in Track 5.

### TMS-aware parameterized modules: Track 6 design concern

The broader question of TMS-aware module definition cells — where the same module has different definitions under different assumptions (e.g., different parameter contexts in the LSP) — is a Track 6 design concern. This is the right future architecture, but today module caching is deterministic (same source → same definitions). The ATMS approach shines when there are multiple simultaneous parameter contexts (LSP scenario). Noted in master roadmap for Track 6 design consideration.

---

## 7. Risk Analysis

### High risk: Module loading behavior change (Phase 3)

Module loading touches every test (via `ns` declarations). The change from "no network" to "network present" affects:
- `global-env-add` dispatch (writes to cells vs parameter)
- Registry cell readers (guards check for elaboration context)
- `reset-meta-store!` behavior (creates per-command networks)

**Mitigation**: Belt-and-suspenders — dual-write continues during Phase 3. Dual-path validation assertion catches divergence. Explicit rollback plan with abort criteria.

### Medium risk: `module-network-ref` consumer compatibility (Phase 5)

Migrating consumers from `(in-hash snapshot)` to cell-based iteration. If any consumer relies on hasheq ordering or other hasheq-specific behavior, migration may break subtly.

**Mitigation**: Phase 3 dual-path validation catches behavioral differences. Phase 5 migration is gradual — one consumer at a time, test suite between each. Only 5 consumer sites to migrate (2 iteration, 3 lookup).

### Medium risk: Definition removal correctness (Phase 2)

Failed definitions must be completely invisible after cleanup. Cell-aware removal must clear the cell value, or a subsequent cell-primary read would see stale data.

**Mitigation**: Write sentinel `#f` to cell on removal. `global-env-lookup-type`/`value` already handle `#f`. Verify with existing error test suite.

### Medium risk: Shadow-cell pattern correctness (Phase 4)

The shadow-cell pattern is new — no existing usage in the codebase. Edge cases: what if a shadow cell is created for a definition that doesn't exist in the source module? What if the source module is reloaded while the consumer is mid-elaboration?

**Mitigation**: Phase 1 prototype validates the pattern in isolation. Phase 4 builds on proven prototype. Source-module-doesn't-exist is `#f` (sentinel) — same as "definition not found." Mid-elaboration reload doesn't happen in batch mode; in LSP mode, re-elaboration is sequenced after reload completes.

### Low risk: Persistent network memory (Phase 1)

CHAMP structural sharing means persistent networks share nodes. 15 module networks for the prelude should be negligible.

**Mitigation**: Measure in Phase 6 against hypothesis.

---

## 8. Learnings from Prior Tracks Applied Here

### From Track 3 PIR: Elaboration guard is the structural boundary

Track 3 discovered that any cell readable outside `process-command` needs an elaboration guard. Track 5 Phase 3 eliminates the root cause by giving module loading a network. Guards remain in place for safety (Track 6 removes them).

### From Track 4 PIR: Dual-write coherence breaks under branching

Track 4 discovered that dual-write (CHAMP + cell) creates coherence issues under TMS branching. Track 5's module definition cells aren't speculative in batch mode, so this doesn't apply directly. But the TMS-ready edge API ensures future TMS branching won't require edge type migration.

### From Track 3 PIR: First-one-is-the-hardest

Phase 1 (module network infrastructure + shadow-cell prototype) will take the most time — it's a new primitive and a new pattern. Phases 2-5 apply patterns established by Phase 1.

### From Track 4 PIR: Belt-and-suspenders is standard practice

Keep both paths (cell + parameter, materialized hash + live network) operational during Phases 1-4. Phase 5 cuts over. Clear validation at each stage.

### From existing architecture: Cross-domain propagators inform the shadow-cell design

Session→effect bridges use `net-add-cross-domain-propagator` with α/γ Galois connections within one network. The shadow-cell pattern applies the same principle (one domain bridges to another) but across networks via explicit initialization + callback rather than scheduler-driven propagation.

### From DEFERRED.md triage

- **Track 3 Phase 6** (dual-write parameter elimination) — partially addressed by Track 5's per-module networks. Full elimination remains Track 6 scope.
- **Phase 3e** (reduction cache cells) — LSP-specific, remains deferred.
- **Phase 5a-5b** (driver simplification) — remains Track 6 scope.
- **`current-global-env` → `current-prelude-env` rename** — Phase 3d alias already exists. Bulk rename (266 files) still deferred. Not blocking.

---

## 9. Files Modified

| File | Changes |
|------|---------|
| `racket/prologos/infra-cell.rkt` | Phase 1: `mod-status-merge` lifecycle lattice |
| `racket/prologos/namespace.rkt` | Phase 1: `module-network-ref` struct, `make-module-network` factory; Phase 3: module cache migration; Phase 5: consumer cutover |
| `racket/prologos/global-env.rkt` | Phase 2: `global-env-remove!`, `definition-cell-remove!`; Phase 4: shadow-cell creation, edge wiring in lookups |
| `racket/prologos/driver.rkt` | Phase 2: consolidated failure cleanup; Phase 3: remove `#f` overrides, dual-path validation; Phase 5: env-threading cleanup, consumer migration |
| `racket/prologos/elaborator-network.rkt` | Phase 1: shadow-cell prototype; Phase 4: `definition-dep-wire!`, `create-shadow-cell!`, `register-cross-module-edge!` |
| `racket/prologos/capability-inference.rkt` | Phase 5: `module-network-ref-lookup` migration |
| `racket/prologos/cap-type-bridge.rkt` | Phase 5: `module-network-ref-lookup` migration |

---

## 10. Verification

1. **Per-phase**: `racket tools/run-affected-tests.rkt --all 2>&1 | tail -30` — 0 failures after each phase
2. **Acceptance file**: Run via `process-file` at L3 after each phase
3. **Shadow-cell prototype**: Unit tests in Phase 1 validate the cross-network pattern in isolation
4. **Module loading**: Every test using `(ns test-X)` exercises module loading — 200+ test files provide integration coverage
5. **Dual-path validation**: Phase 3 assertion verifies cell reads match hash reads for every module definition
6. **Failure cleanup**: `test-error-messages.rkt`, `test-trait-resolution.rkt`, `test-trait-impl-*.rkt` exercise definition failure → error paths
7. **Cross-module edges**: Compare `definition-dependencies-snapshot` edge count against cell-wired edge count — they must agree
8. **Performance**: Compare total wall time against 187.1s baseline; compare measured values against Phase 0 hypothesis table; investigate if >25% regression

---

## 11. Batch-Worker Isolation: Resolved

The batch-worker (`tools/batch-worker.rkt`) saves post-prelude state and restores it per-test via `parameterize`. Specifically:
- Line 90: `ready-module-registry` captures `(current-module-registry)` after prelude loads
- Line 195: restores `[current-module-registry ready-module-registry]` per-test
- Lines 204-211: fresh `current-definition-cells-content`, `current-definition-cell-ids`, etc.

Persistent module networks in Track 5 live inside `module-info` structs, which live inside `current-module-registry`. When the batch-worker restores `current-module-registry` to the post-prelude ready state, module networks are restored too (since the registry is immutable — pointing to the post-prelude `module-info` structs).

Test-specific modules (loaded during a test) are added to the test's parameterized registry copy and discarded after the test. Prelude module networks are read-only (shared by all tests).

**No additional save/restore needed.**

---

## 12. Open Questions

### Q1: TMS-aware module definition cells

Noted as Track 6 design concern. See §6.

### Q2: Cross-network propagator mechanics

Resolved: shadow-cell + callback pattern. Prototype in Phase 1. See §2.3.

### Q3: Batch-worker isolation

Resolved: `current-module-registry` save/restore covers persistent module networks. See §11.

---

## 13. D.3 Self-Critique: Principle Alignment

Systematic check against `DESIGN_PRINCIPLES.org`.

| Principle | Alignment | Notes |
|-----------|-----------|-------|
| Propagator-First Infrastructure | ✅ Strong | Core purpose of Track 5 |
| Correct by Construction | ⚠️ Mostly | Shadow-cell consistency is batch-only; Track 6 must address |
| Decomplection | ✅ Strong | Clean separation of concerns throughout |
| Data Orientation | ⚠️ Minor | Module networks should be first-class pure data; LSP invalidation should use descriptors |
| First-Class by Default | ✅ Aligned | All new constructs are first-class values |
| Most Generalizable Interface | ✅ Aligned | Shadow-cell pattern generalizes beyond modules |
| Simplicity of Foundation | ⚠️ Moderate | Shadow cells = plain cells + metadata, not a new primitive |
| Open Extension, Closed Verification | ✅ Aligned | Monotonic lattice preserves verification |
| Propagator Statelessness | ✅ Check | Verify during implementation |

### 13.1 Propagator-First Infrastructure — ✅ STRONG ALIGNMENT

This is the core principle Track 5 serves. The design converts the last major parameter-based subsystem (global-env) to cell-based infrastructure:

- **Persistent module networks** replace materialized hasheq snapshots with live cell references
- **Dependency edges as propagators** make definition dependencies a structural property of network topology, not informational metadata
- **Shadow cells** for cross-module reads mean module consumers participate in the propagator paradigm across network boundaries

### 13.2 Correct by Construction — ⚠️ MOSTLY ALIGNED, ONE GAP

**Where we align**: The staleness model is correct-by-construction — `net-cell-write`'s merge-then-compare means no-op writes structurally cannot trigger false staleness. The module lifecycle lattice structurally prevents `loaded → loading` (monotonic merge).

**The gap**: The shadow-cell + callback pattern is NOT correct-by-construction for cross-invocation consistency. In batch mode it's trivially correct (initialize once, never update). But the design describes LSP invalidation as a future callback — the *mechanism* for keeping shadow cells consistent with source modules is deferred.

**Decision**: Accepted for Track 5. Batch mode doesn't need the sync mechanism, and designing it without the LSP trigger would be untestable. **Track 6 must provide a correct-by-construction approach** — the current shadow-cell + callback pattern's potential for divergence is a known liability. Noted in master roadmap as a Track 6 design concern.

### 13.3 Decomplection — ✅ STRONG ALIGNMENT

The design decomplects several previously braided concerns:

- **Module cache representation** decoupled from **module lookup mechanism** (network-ref vs hasheq is transparent during belt-and-suspenders)
- **Definition persistence** decoupled from **per-command elaboration state** (§2.2's ephemeral vs persistent)
- **Same-file edges** decoupled from **cross-module edges** (different mechanisms for the same dependency concept)
- **Staleness detection** decoupled from **staleness response** (Track 5 detects; LSP responds)

### 13.4 Data Orientation — ⚠️ MINOR TENSION, NOTED FOR FUTURE

Two data orientation considerations:

1. **Module networks as first-class pure data**: The `module-network-ref` struct is a first-class value, but we want module networks to be *pure data* — reusable and composable in ways we can't yet foresee. The CHAMP-based `prop-network` is already immutable/persistent, which supports this. The LSP track should treat module networks as first-class data for unforeseen reuse and composition. Noted in master roadmap as an LSP track design concern.

2. **LSP invalidation mechanism**: The current design sketches the LSP invalidation as imperative ("LSP iterates dependents and writes to shadow cells"). A more data-oriented design would use invalidation *descriptors* (e.g., `(stale-module bar '(map filter fold))`) interpreted at explicit control boundaries — enabling logging, batching, deduplication. This is an LSP track concern; Track 5 doesn't implement the callback.

### 13.5 First-Class by Default — ✅ ALIGNED

- Module networks are first-class values (`module-network-ref` struct)
- Dependency edges are first-class data (`dep-edges` field)
- `mod-status` cell is a first-class observable value
- TMS `#:assumption` parameter on edges is first-class metadata

### 13.6 Most Generalizable Interface — ✅ ALIGNED

The shadow-cell pattern is more general than cross-network propagators — it works for ANY cross-network dependency, not just module→file. The TMS-ready edge API serves future use cases without migration.

### 13.7 Simplicity of Foundation — ⚠️ MODERATE TENSION

Track 5 introduces three mechanisms:
1. `module-network-ref` — composition (wraps existing `prop-network` + `cell-id-map`)
2. Module lifecycle lattice — composition (existing `net-new-cell-with-merge` + new merge fn)
3. Shadow cells — conceptually new pattern

**Resolution**: Shadow cells are structurally just plain cells with an initialization value. The "shadow" is a conceptual label + cross-module edge metadata (`register-cross-module-edge!`), not a new cell type or primitive. Implementation must keep this clear: no `shadow-cell` struct, just a regular cell + metadata tracking.

### 13.8 Propagator Statelessness — ✅ VERIFY DURING IMPLEMENTATION

`definition-dep-wire!` propagators must be stateless pure fire functions: capture only cell-IDs (immutable) in closures, no mutable state. Shadow-cell initialization is not a propagator — it's one-time setup.

### 13.9 Deferred Principle Concerns → Future Tracks

| Concern | Deferred To | Description |
|---------|-------------|-------------|
| Shadow-cell divergence | Track 6 | Correct-by-construction cross-network consistency mechanism |
| TMS-aware parameterized modules | Track 6 | Module definition cells as TMS cells for multi-context sharing |
| First-class module network data | LSP Track | Pure data composition for unforeseen reuse |
| Data-oriented invalidation | LSP Track | Invalidation descriptors instead of imperative callbacks |
