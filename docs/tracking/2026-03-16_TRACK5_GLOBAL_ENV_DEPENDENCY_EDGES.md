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
| D.2 | Design discussion + rework | 🔄 | Persistent networks, cross-module edges, lifecycle, TMS discussion |
| D.3 | Self-critique (principle alignment) | ⬜ | |
| 0 | Performance baseline + acceptance file | ⬜ | |
| 1 | Persistent module network infrastructure | ⬜ | New primitive: `module-network-ref`, `mod-status` cell |
| 2 | Definition removal → cell-aware cleanup | ⬜ | `global-env-remove!` helper |
| 3 | Per-module network activation | ⬜ | Remove `#f` overrides in module loading |
| 4 | Cross-module dependency edges | ⬜ | Cross-network propagators, identity α/γ |
| 5 | Write consolidation + validation | ⬜ | Env-threading cleanup, full validation |
| 6 | Performance validation + PIR | ⬜ | |

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
3. **Cross-module dependency edges** — when file `foo` references `bar::map`, a cross-network propagator wires `bar`'s `map` cell to `foo`'s dependency tracking. When `bar` changes, only definitions in `foo` that transitively depend on changed definitions are marked stale. Minimum recompute.
4. **Definition failure cleanup consolidation** — the 12 inline `hash-remove` sites become `global-env-remove!` operating on both layers.
5. **Env-threading write consolidation** — the 36+ `(current-global-env (global-env-add ...))` calls become direct `global-env-add` once module loading has networks.

The "biggest payoff" from the Pipeline Audit: incremental module re-elaboration. Combined with Track 4's ATMS, the LSP can retract a definition assumption and let propagation settle rather than re-elaborating an entire file.

---

## 2. Architectural Foundation: Persistent Module Networks

### 2.1 Key insight: networks are CHAMP-based

The existing `prop-network` is built on immutable CHAMP maps. All operations create new network structs with modified CHAMP references — O(1) snapshots via structural sharing. This means:

- **"Separate network per module" and "shared pointers to common structure" are the same thing at the CHAMP level.** Two module networks that share common definitions (e.g., both import the prelude) share CHAMP nodes for those cells. Logically separate (`prop-network` structs), physically sharing.
- **Persistence is free.** Keeping a module's network alive is just keeping the CHAMP references alive instead of discarding them.
- **Cross-network reads are cell reads.** No new primitive needed — read a cell from network A while executing in network B.

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

### 2.3 `module-network-ref`: the new module cache type

Currently `module-info` stores `env-snapshot` as a flat `hasheq` of `symbol → (cons type value)`. Track 5 replaces this with a `module-network-ref` struct:

```racket
(struct module-network-ref
  (prop-net          ;; the persistent prop-network
   cell-id-map       ;; hasheq: symbol → cell-id (for definition lookup)
   mod-status-cell   ;; cell-id of the mod-status cell
   dep-edges))       ;; hasheq: symbol → (listof dep-edge) (outbound edges)
```

**Backwards compatibility**: `module-network-ref` can implement `prop:dict` (or provide a `module-network-ref-ref` function matching `hash-ref` signature) so existing code that does `(hash-ref snapshot name)` keeps working — but actually reads from live cells underneath.

### 2.4 Module lifecycle lattice

Drawing on the lifecycle patterns across existing domain sub-graphs:

| Domain | Lifecycle | Lattice | Bridge mechanism |
|--------|-----------|---------|-----------------|
| Session | `sess-bot → send/recv/... → sess-top` | `session-lattice-merge` | cross-domain propagator (α/γ) |
| Effect | `eff-bot → eff-position → eff-top` | unidirectional α from session | `add-session-effect-bridge` |
| IO | `io-bot → io-opening → io-open → io-closed → io-top` | `io-lattice-merge` | Gauss-Seidel scheduler |
| **Module** | `mod-loading → mod-loaded → mod-stale` | `mod-status-merge` | dependency edge propagators |

The module lifecycle lattice:
- `mod-loading` → module is being elaborated (definitions being added)
- `mod-loaded` → all definitions elaborated successfully, network stable
- `mod-stale` → a dependency changed, module needs re-elaboration

**Staleness is monotonic**: once a dependency changes, the module is stale until explicitly reloaded. The `mod-status` cell uses a merge function where `stale` dominates `loaded` (once stale, stays stale). Reloading resets to `mod-loading` (non-monotonic — requires a fresh network or cell reset).

The LSP watches `mod-status` cells. When a `.prologos` library file changes, its module's status is set to `stale`, which propagates to all dependent modules via cross-module edges.

In batch mode, the lifecycle is trivially `loading → loaded` per module (no invalidation during a single compilation run).

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
| Cross-domain propagators | ✅ | `propagator.rkt` — `net-add-cross-domain-propagator` with α/γ Galois connections |
| Error descriptor cell | ✅ | Track 2 Phase 7 — `current-error-descriptor-cell-id`, `read-error-descriptors` |
| Cell-primary readers for all registries | ✅ | Track 3 — 28 readers across macros.rkt, warnings.rkt, global-constraints.rkt |
| merge-replace for definition cells | ✅ | `infra-cell.rkt` — last-write-wins for non-monotonic definitions |
| CHAMP structural sharing | ✅ | `propagator.rkt` — all network operations are O(log N), O(1) snapshots |

### What we need

| Gap | Required for | Complexity |
|-----|-------------|-----------|
| `module-network-ref` struct | Persistent module cache (Phase 1) | Medium — new struct + `prop:dict` wrapper |
| `mod-status` cell + lifecycle lattice | Module invalidation (Phase 1) | Low — new merge fn, single cell per module |
| `global-env-remove!` helper | Failure cleanup consolidation (Phase 2) | Low — mirror `global-env-add` for removal |
| Remove `#f` overrides in module loading | Module loading cell path (Phase 3) | Medium — behavior change, wide test coverage |
| Cross-network dependency propagators | Cross-module edges (Phase 4) | Medium — identity α/γ via existing `net-add-cross-domain-propagator` |
| Module snapshot → network-ref conversion | Module cache migration (Phase 3) | Medium — `global-env-snapshot` returns `module-network-ref` |

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

**Goal**: Establish baseline and create acceptance file.

- Run full test suite, record timing and test count
- Create `examples/2026-03-16-track5-acceptance.prologos` exercising:
  - Definitions that reference prior definitions (dependency edges)
  - Module imports with re-exported definitions
  - Cross-module dependency chains (A imports B imports C)
  - Definition failure cases (type error in body → cleanup visible)
  - All prelude features (regression net)
- Record acceptance file baseline (L3 via `process-file`)

### Phase 1: Persistent Module Network Infrastructure

**Goal**: Create the new primitives — `module-network-ref`, `mod-status` cell, lifecycle lattice.

**Files**: `global-env.rkt`, `namespace.rkt`, `infra-cell.rkt`

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
   dep-edges)        ;; hasheq: symbol → (listof dep-edge-info)
  #:transparent)
```

Provide a `module-network-ref-lookup` that reads from cells:
```racket
(define (module-network-ref-lookup mnr name)
  (define cell-id (hash-ref (module-network-ref-cell-id-map mnr) name #f))
  (and cell-id
       (net-cell-read (module-network-ref-prop-net mnr) cell-id)))
```

**1c: Module network creation**: Factory function `make-module-network` that:
1. Creates a fresh `prop-network`
2. Creates a `mod-status` cell initialized to `mod-loading`
3. Returns a `module-network-ref` with empty cell-id-map and dep-edges

**Phase 1 is infrastructure-only** — no behavior change. Module loading still uses the parameter path. The new structs exist but aren't wired in yet.

**Deliverable**: New primitives, unit tests for lifecycle merge, module-network-ref lookup.

### Phase 2: Definition Removal → Cell-Aware Cleanup

**Goal**: Extract `global-env-remove!` helper; consolidate 12 failure cleanup sites.

**Files**: `global-env.rkt`, `driver.rkt`

New helper in `global-env.rkt`:

```racket
(define (global-env-remove! name)
  ;; Layer 1: remove from per-file definitions content
  (current-definition-cells-content
   (hash-remove (current-definition-cells-content) name))
  ;; Layer 1: write sentinel to cell (not delete — cell stays, value cleared)
  (definition-cell-remove! name)
  ;; Layer 2: remove from prelude env parameter
  (current-global-env
   (hash-remove (current-global-env) name)))
```

`definition-cell-remove!` writes a sentinel value (`#f` or `(cons #f #f)`) to the cell. `global-env-lookup-type`/`value` already handle `#f` entries (return `#f`).

Convert all 12 failure cleanup sites from inline `hash-remove` × 2 layers to `(global-env-remove! name)`.

**Deliverable**: Helper extracted, 12 sites consolidated, failure test suite passes.

### Phase 3: Per-Module Network Activation

**Goal**: Remove `#f` overrides so module loading runs with networks. Wire module definitions to persistent `module-network-ref`.

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

**3b: Create module network at load start**: Before the module's command loop, call `make-module-network`. Pass the resulting `module-network-ref` to the module loading context. As `process-command` processes each module form, definitions are written to both the per-command network cells (ephemeral) and the module's persistent network cells (via `definition-cell-write!` targeting the module network).

**3c: Module env snapshot → network-ref**: At the end of module loading, instead of `global-env-snapshot` materializing a flat hasheq, store the `module-network-ref` in `module-info`'s `env-snapshot` field. Set `mod-status` to `mod-loaded`.

**Accumulation semantics**: Module loading currently accumulates definitions in `(current-global-env)` across commands. With networks, definitions accumulate in `current-definition-cells-content` (Layer 1), which also persists across commands. Accumulation behavior is preserved — now through cells.

**Belt-and-suspenders**: During Phase 3, keep Layer 2 writes (dual-write). Module loading writes to both cells and parameters. Validate that cell-based reads produce identical results to parameter-based reads before any caller switches.

**Risk**: High. Module loading is exercised by every test using `(ns test-X)` — 200+ test files. But this wide coverage is also the mitigation: regressions surface immediately.

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

When file `foo` looks up `bar::map`, the definition lives in `bar`'s persistent `module-network-ref`. Wire a cross-network propagator using the existing `net-add-cross-domain-propagator` with identity α/γ (same type domain, different network):

```racket
;; foo's network watches bar's map cell
(define bar-map-cell (module-network-ref-cell-id bar-mnr 'map))
(define foo-dep-cell (hash-ref (current-definition-cell-ids) elab-name))
;; Cross-network edge: bar's cell → foo's staleness tracking
(cross-module-dep-wire! bar-mnr bar-map-cell foo-dep-cell elab-name)
```

When `bar`'s `map` cell changes (module reloaded), the cross-network propagator fires, marking `foo`'s dependent definitions as stale. Only definitions in `foo` that transitively depend on `bar::map` are affected — everything else in `foo` is untouched. **Minimum recompute**.

**4c: Staleness propagation to `mod-status`**:

When any definition cell in a module is marked stale (via incoming cross-module edge), a propagator writes `mod-stale` to that module's `mod-status` cell. The LSP watches one cell per module, not every definition cell.

**What the edges provide immediately** (batch mode):
- Observable dependency graph via cell inspection (tooling, debugging)
- Validation that dependency recording matches cell wiring (any missed edge = a bug)
- Foundation for incremental re-elaboration (LSP — just connect a re-elaboration trigger to the propagator)

### Phase 5: Write Consolidation + Validation

**Goal**: Clean up the now-redundant env-threading pattern. Full validation.

**Files**: `driver.rkt`

With module loading running through networks (Phase 3), the `(current-global-env (global-env-add ...))` wrapper is truly redundant everywhere. Simplify all 23 Category A sites to just `(global-env-add ...)`.

Also: annotated audit of all remaining `(current-global-env)` references. Document which references are still needed (Layer 2 initialization, snapshot reads) vs. which are legacy.

**Deliverable**: All env-threading wrappers removed. Acceptance file passes at L3. Full test suite 0 failures.

### Phase 6: Performance Validation + PIR

- Run full suite, compare against Phase 0 baseline
- Run acceptance file at L3
- Per-module network creation adds ~1 persistent network per module load. With prelude loading ~15 modules, this is 15 persistent networks. Measure: memory footprint (CHAMP sharing should keep it small) and lookup time (cell read vs hasheq lookup).
- Cross-module edge count: how many propagators per typical file compilation? Profile.
- Write PIR following methodology

---

## 6. Design Discussion: TMS-Awareness of Dependency Edges

**Status**: Under active discussion. Design the API for TMS-aware edges now; implementation decision to be finalized in D.3.

### The case for TMS-aware edges in Track 5

Dependency edges are *created* in Track 5 Phase 4. Designing them without TMS-awareness means Track 6 has to retrofit it — the "late L3 validation causes cascading fixes" anti-pattern. The design cost is low: when wiring an edge, check if the source definition was created under a TMS assumption; if so, the edge inherits that assumption's label.

### The architectural fit

Track 4's TMS cells already support assumption-tagged values. A dependency edge is conceptually a propagator — it already lives in the network. Making it TMS-aware means the propagator's firing is conditional on its assumption being believed.

```racket
;; Edge wiring with optional TMS label:
(define (definition-dep-wire! src-cell dst-cell src-name dst-name
                              #:assumption [assumption #f])
  ;; If assumption provided, edge only fires when assumption is believed
  ...)
```

### Where TMS edges pay off

1. **LSP completion**: if the LSP speculatively elaborates a definition to check completion candidates, edges from that speculative definition should retract when the speculation is abandoned.
2. **Conditional compilation** (future): if a module's definitions are parameterized by a compile-time flag (an assumption), edges from flag-dependent definitions retract when the flag changes.
3. **Multi-context sharing**: different open files in the LSP with different configurations are different assumption contexts. A module's network serves all contexts; edges resolve per-context.

### Current recommendation

Design the `definition-dep-wire!` API with an optional `#:assumption` parameter. In Track 5 Phase 4, pass `#f` (no assumption — unconditional edges). The API is ready for Track 6 or the LSP track to pass real assumptions. This is the belt-and-suspenders principle applied forward: **design for TMS, implement with plain edges, upgrade is adding one argument**.

The broader question of TMS-aware module definition cells (where the same module has different definitions under different assumptions) remains open for further discussion — see Open Questions.

---

## 7. Risk Analysis

### High risk: Module loading behavior change (Phase 3)

Module loading touches every test (via `ns` declarations). The change from "no network" to "network present" affects:
- `global-env-add` dispatch (writes to cells vs parameter)
- Registry cell readers (guards check for elaboration context)
- `reset-meta-store!` behavior (creates per-command networks)

**Mitigation**: Belt-and-suspenders — dual-write continues during Phase 3. Module loading writes to BOTH cells and parameters. Existing parameter-based reads remain as fallback.

### Medium risk: `module-network-ref` backwards compatibility (Phase 3)

Changing `module-info`'s `env-snapshot` from `hasheq` to `module-network-ref` affects every call site that reads from the snapshot. If the `prop:dict` wrapper has subtle behavioral differences from plain `hasheq`, callers may break.

**Mitigation**: Audit all `env-snapshot` consumers before Phase 3. Consider a transition period where `module-network-ref` stores both the live network and a materialized snapshot, with an assertion that they agree.

### Medium risk: Definition removal correctness (Phase 2)

Failed definitions must be completely invisible after cleanup. Cell-aware removal must clear the cell value, or a subsequent cell-primary read would see stale data.

**Mitigation**: Write sentinel value to cell on removal. `global-env-lookup-type`/`value` already handle `#f` entries. Verify with existing error test suite.

### Medium risk: Cross-network propagator correctness (Phase 4)

Cross-module edges wire propagators between separate `prop-network` structs. The existing `net-add-cross-domain-propagator` was designed for sub-graphs within a single network, not across networks. May need a new variant.

**Mitigation**: Prototype the cross-network wiring early in Phase 4. If `net-add-cross-domain-propagator` doesn't work across networks, implement a lightweight cross-network watcher (monitor source cell, write to destination cell via callback).

### Low risk: Persistent network memory (Phase 1)

CHAMP structural sharing means persistent networks share nodes. 15 module networks for the prelude should be negligible. But verify empirically.

---

## 8. Learnings from Prior Tracks Applied Here

### From Track 3 PIR: Elaboration guard is the structural boundary

Track 3 discovered that any cell readable outside `process-command` needs an elaboration guard. Track 5 Phase 3 eliminates the root cause by giving module loading a network. Guards remain in place for safety (Track 6 removes them).

### From Track 4 PIR: Dual-write coherence breaks under branching

Track 4 discovered that dual-write (CHAMP + cell) creates coherence issues under TMS branching. Track 5's module definition cells aren't speculative in batch mode, so this doesn't apply directly. But if we introduce TMS-aware edges, the edge propagators must respect TMS branching semantics.

### From Track 3 PIR: First-one-is-the-hardest

Phase 1 (module network infrastructure) will take the most time — it's a new primitive. Phases 2-5 apply patterns established by Phase 1. Budget accordingly.

### From Track 4 PIR: Belt-and-suspenders is standard practice

Keep both paths (cell + parameter) operational during Phases 1-4. Don't remove the parameter path in Track 5.

### From existing architecture: Cross-domain propagators already exist

Session→effect bridges use `net-add-cross-domain-propagator` with α/γ Galois connections. Module→file bridges use the same mechanism with identity α/γ. The infrastructure exists — Track 5 applies it to a new domain.

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
| `racket/prologos/namespace.rkt` | Phase 1: `module-network-ref` struct, `make-module-network` factory; Phase 3: module cache migration |
| `racket/prologos/global-env.rkt` | Phase 2: `global-env-remove!`, `definition-cell-remove!`; Phase 4: cross-module edge wiring in lookups |
| `racket/prologos/driver.rkt` | Phase 2: consolidated failure cleanup; Phase 3: remove `#f` overrides; Phase 5: env-threading cleanup |
| `racket/prologos/elaborator-network.rkt` | Phase 4: `definition-dep-wire!`, `cross-module-dep-wire!` propagator factories |
| `racket/prologos/propagator.rkt` | Phase 4: cross-network propagator variant (if needed) |

---

## 10. Verification

1. **Per-phase**: `racket tools/run-affected-tests.rkt --all 2>&1 | tail -30` — 0 failures after each phase
2. **Acceptance file**: Run via `process-file` at L3 after each phase
3. **Module loading**: Every test using `(ns test-X)` exercises module loading — 200+ test files provide integration coverage
4. **Failure cleanup**: `test-error-messages.rkt`, `test-trait-resolution.rkt`, `test-trait-impl-*.rkt` exercise definition failure → error paths
5. **Cross-module edges**: Compare `definition-dependencies-snapshot` edge count against cell-wired edge count — they must agree
6. **Module network-ref**: Assert `module-network-ref` lookup results match old `hasheq` snapshot results during Phase 3 belt-and-suspenders
7. **Performance**: Compare total wall time against 187.1s baseline; investigate if >25% regression

---

## 11. Open Questions

### Q1: TMS-aware module definition cells (beyond TMS-aware edges)

Should module definition cells themselves be TMS cells, allowing different parameter contexts to produce different definitions from the same module? This enables multi-context module sharing in the LSP (different open files with different configs share one module network, reading definitions under different assumption contexts).

**Current thinking**: The right future architecture, but potentially premature. Today module caching is deterministic — same source → same definitions. Parameters like `current-fuel` affect elaboration effort, not definition semantics. The ATMS approach shines when there are multiple simultaneous parameter contexts (LSP scenario).

**Design principle**: The `module-network-ref` API should be TMS-cell-compatible. `make-module-network` can take an optional `#:tms?` flag that creates TMS cells instead of plain cells. Default is plain cells in Track 5; flipped for LSP.

### Q2: Cross-network propagator mechanics

Does `net-add-cross-domain-propagator` work across separate `prop-network` structs, or only within one network? If the latter, we need a lightweight cross-network callback mechanism. Investigate during Phase 4 prototyping.

### Q3: Module network persistence under batch-worker isolation

The batch-worker (`batch-worker.rkt`) saves/restores state for test isolation. Persistent module networks need to be included in save/restore, or they'll leak across tests. Check the batch-worker's state list.
