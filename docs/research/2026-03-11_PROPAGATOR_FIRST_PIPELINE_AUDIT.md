# Propagator-First Pipeline Audit

**Date**: 2026-03-11
**Status**: Complete
**Scope**: Whole-system audit of the Prologos compilation pipeline through the Propagator-First Infrastructure lens
**Principle**: See DESIGN_PRINCIPLES.org § "Propagator-First Infrastructure" and § "Correct by Construction"
**Related**: `2026-03-03_PROPAGATOR_NETWORK_FUTURE_OPPORTUNITIES.md` (theoretical applications), `2026-03-11_LSP_VSCODE_STAGE2_REFINEMENT.md` (LSP-specific propagator design)

---

## 1. Purpose

This document classifies every mutable state site in the Prologos compilation pipeline into one of four categories:

1. **Propagator-natural** — monotonic accumulation of partial information; should be a propagator cell
2. **Already-propagator** — uses the existing propagator/ATMS infrastructure
3. **Pure transformation** — stateless input→output; propagators would add ceremony without benefit
4. **Cache/fuel** — performance optimization (memoization, fuel counters); orthogonal to propagators

The goal is to produce a map that informs incremental adoption: which sites to migrate first for maximum composition synergy, and which to leave alone.

---

## 2. Pipeline Overview

```
Source Text
    │
    ▼
┌──────────┐
│  Reader   │  ws-reader.rkt (WS mode) or read (sexp mode)
└────┬─────┘
     ▼
┌──────────┐
│ Preparse  │  macros.rkt (register-preparse!, preparse-datum)
└────┬─────┘
     ▼
┌──────────┐
│  Parser   │  parser.rkt (parse-datum → AST)
└────┬─────┘
     ▼
┌──────────────┐
│  Elaborator   │  elaborator.rkt (elaborate, elaborate-top-level)
│  + Type Check │  typing-core.rkt (infer, check)
│  + Unify      │  unify.rkt (unify!)
│  + Traits     │  macros.rkt (resolve-trait-constraints!)
│  + Constraints│  constraint-propagators.rkt (P1–P4)
└────┬─────────┘
     ▼
┌──────────┐
│   Zonk    │  zonk.rkt (zonk-expr, zonk-level-default, zonk-mult-default)
└────┬─────┘
     ▼
┌──────────┐
│ Reduction │  reduction.rkt (whnf, nf, reduce-to-value)
└────┬─────┘
     ▼
  Result / Value
```

Orchestration: `driver.rkt` (`process-command` loop)

---

## 3. Mutable State Inventory

### 3.1 Metavariable Store (`metavar-store.rkt`)

The single largest concentration of mutable state in the system.

| State Site | Type | Current Impl | Classification | Notes |
|---|---|---|---|---|
| `current-meta-store` | `hasheq: id → meta-info` | Mutable hash in parameter | **Already-propagator** | Backed by CHAMP box (`current-prop-meta-info-box`); each meta has a propagator cell |
| `current-level-meta-store` | `hasheq: id → level-meta` | Mutable hash + CHAMP box | **Already-propagator** | Universe level metas with propagator backing |
| `current-mult-meta-store` | `hasheq: id → mult-meta` | Mutable hash + CHAMP box | **Already-propagator** | QTT multiplicity metas with propagator backing |
| `current-sess-meta-store` | `hasheq: id → sess-meta` | Mutable hash + CHAMP box | **Already-propagator** | Session type metas with propagator backing |
| `current-prop-net-box` | `box(elab-network)` | Box wrapping propagator network | **Already-propagator** | The network itself |
| `current-prop-id-map-box` | `box(CHAMP: meta-id → cell-id)` | Box wrapping persistent map | **Already-propagator** | Meta-to-cell mapping |
| `save-meta-state` / `restore-meta-state!` | Snapshot of all 6 boxes | Box read/write | **Already-propagator** | Speculative type-checking; should become ATMS assumption retraction |

**Assessment**: The meta store is already 80% propagator-based. The remaining 20% is the mutable `meta-info` struct fields (`status`, `solution`) and the `hash-set!` operations on the hasheq stores. Full migration: make `meta-info` immutable, let cell content represent the solution state, eliminate the dual (hasheq + CHAMP) representation.

### 3.2 Constraint Tracking (`metavar-store.rkt`)

| State Site | Type | Current Impl | Classification | Notes |
|---|---|---|---|---|
| `current-constraint-store` | `list(constraint)` | Parameter (list accumulator) | **Propagator-natural** | Monotonic — constraints are added, never removed during elaboration |
| `current-wakeup-registry` | `hasheq: cell-id → (listof constraint)` | Mutable hash | **Propagator-natural** | Dependency edges; natural propagator wiring |
| `current-trait-constraint-map` | `hasheq: meta-id → trait-constraint-info` | Mutable hash | **Propagator-natural** | Monotonic accumulation; should be cells with trait-constraint content |
| `current-trait-wakeup-map` | `hasheq: meta-id → callback` | Mutable hash | **Propagator-natural** | Dependency edges for trait resolution |
| `current-trait-cell-map` | `hasheq: meta-id → cell-id` | Mutable hash | **Already-propagator** | Maps trait metas to propagator cells |
| `current-hasmethod-constraint-map` | `hasheq: meta-id → hasmethod-info` | Mutable hash | **Propagator-natural** | Single-method trait constraints |
| `current-capability-constraint-map` | `hasheq: meta-id → capability-info` | Mutable hash | **Propagator-natural** | Capability type constraints |
| `current-retry-trait-resolve` | `boolean` | Parameter | **Propagator-natural** | Dirty flag; would be eliminated by propagator wakeup |
| `current-retry-unify` | `boolean` | Parameter | **Propagator-natural** | Dirty flag; would be eliminated by propagator wakeup |

**Assessment**: Constraint tracking is the highest-value migration target. Currently uses explicit dirty flags (`current-retry-trait-resolve`, `current-retry-unify`) and manual wakeup registries. With propagator cells, constraints would fire automatically when dependent metas are solved — eliminating the retry loops and dirty-flag polling in `resolve-trait-constraints!`.

### 3.3 Global Environment (`global-env.rkt`)

| State Site | Type | Current Impl | Classification | Notes |
|---|---|---|---|---|
| `current-global-env` | `hasheq: symbol → (cons type value)` | Parameter (functional update) | **Propagator-natural** | Monotonic within a file; definitions accumulate. Non-monotonic across LSP edits (handled by ATMS assumptions) |
| `current-defn-param-names` | `hasheq: symbol → (listof symbol)` | Parameter (functional update) | **Propagator-natural** | Monotonic; accumulates parameter name metadata |

**Assessment**: `current-global-env` is the backbone of the pipeline. Converting each definition to a cell would enable: (1) automatic downstream invalidation when a definition changes (LSP), (2) incremental module loading — only re-elaborate definitions whose dependencies changed, (3) natural cycle detection — circular definitions produce contradiction.

### 3.4 Registry Parameters (`macros.rkt`)

| State Site | Type | Current Impl | Classification | Notes |
|---|---|---|---|---|
| `current-preparse-registry` | `hasheq` | Parameter | **Propagator-natural** | Monotonic — macros registered, never unregistered |
| `current-spec-store` | `hasheq` | Parameter | **Propagator-natural** | Spec declarations accumulate |
| `current-propagated-specs` | `seteq` | Parameter | **Propagator-natural** | Set of propagated specs grows monotonically |
| `current-schema-registry` | `hasheq` | Parameter | **Propagator-natural** | Schema registrations accumulate |
| `current-ctor-registry` | `hasheq` | Parameter | **Propagator-natural** | Constructor registrations accumulate |
| `current-type-meta` | `hasheq` | Parameter | **Propagator-natural** | Type metadata accumulates |
| `current-subtype-registry` | `hash` | Parameter | **Propagator-natural** | Subtype relations accumulate |
| `current-coercion-registry` | `hash` | Parameter | **Propagator-natural** | Coercion rules accumulate |
| `current-trait-registry` | `hasheq` | Parameter | **Propagator-natural** | Trait definitions accumulate |
| `current-trait-laws` | `hasheq` | Parameter | **Propagator-natural** | Trait laws accumulate |
| `current-impl-registry` | `hasheq` | Parameter | **Propagator-natural** | Trait instances accumulate |
| `current-param-impl-registry` | `hasheq` | Parameter | **Propagator-natural** | Parametric instances accumulate |
| `current-bundle-registry` | `hasheq` | Parameter | **Propagator-natural** | Bundle registrations accumulate |
| `current-specialization-registry` | `hash` | Parameter | **Propagator-natural** | Specializations accumulate |
| `current-capability-registry` | `hasheq` | Parameter | **Propagator-natural** | Capability types accumulate |
| `current-selection-registry` | `hasheq` | Parameter | **Propagator-natural** | Selections accumulate |
| `current-session-registry` | `hasheq` | Parameter | **Propagator-natural** | Session registrations accumulate |
| `current-strategy-registry` | `hasheq` | Parameter | **Propagator-natural** | Strategy registrations accumulate |
| `current-process-registry` | `hasheq` | Parameter | **Propagator-natural** | Process registrations accumulate |
| `current-property-store` | `hasheq` | Parameter | **Propagator-natural** | Property metadata accumulates |
| `current-functor-store` | `hasheq` | Parameter | **Propagator-natural** | Functor registrations accumulate |
| `current-user-precedence-groups` | `hasheq` | Parameter | **Propagator-natural** | Operator precedence accumulates |
| `current-user-operators` | `hasheq` | Parameter | **Propagator-natural** | User operators accumulate |
| `current-macro-registry` | `hasheq` | Parameter | **Propagator-natural** | User macros accumulate |

**Assessment**: All 24 registry parameters are monotonic accumulators. They share an identical pattern: start empty, grow via registration, never shrink during batch compilation. In the LSP context, they shrink when a file is re-edited (non-monotonic), which ATMS assumptions handle. Converting these to propagator cells is *structurally simple* — each registry becomes a cell whose content is the hash, with a monotonic merge (hash union). The composition synergy is significant: trait resolution propagators can wire directly to the `current-impl-registry` cell, firing when new instances are registered rather than requiring an explicit resolution pass.

### 3.5 Module System (`namespace.rkt`)

| State Site | Type | Current Impl | Classification | Notes |
|---|---|---|---|---|
| `current-module-registry` | `hasheq: ns-sym → module-info` | Parameter | **Propagator-natural** | Modules accumulate; natural cell content |
| `current-ns-context` | `ns-context` struct | Parameter | **Propagator-natural** | Grows via import/export declarations |
| `current-lib-paths` | `(listof path)` | Parameter | **Pure transformation** | Set once at startup, never changes |
| `current-loading-set` | `seteq` | Parameter | **Pure transformation** | Cycle detection; scoped to a single load operation |
| `current-module-loader` | `callback` | Parameter | **Pure transformation** | Set once at startup |
| `current-spec-propagation-handler` | `callback` | Parameter | **Pure transformation** | Set once at startup |
| `current-foreign-handler` | `callback` | Parameter | **Pure transformation** | Set once at startup |

**Assessment**: `current-module-registry` and `current-ns-context` are natural propagator cells. The three callback parameters and `current-lib-paths` are configuration set once at startup — no propagator benefit. `current-loading-set` is per-operation cycle detection — leave as-is.

### 3.6 Elaborator Context (`elaborator.rkt`)

| State Site | Type | Current Impl | Classification | Notes |
|---|---|---|---|---|
| `current-relational-env` | `hasheq: sym → logic-var` | Parameterize-scoped | **Pure transformation** | Scoped within `elaborate` calls; no accumulation |
| `current-relational-fallback?` | `boolean` | Parameterize-scoped | **Pure transformation** | Context flag; no accumulation |
| `current-where-context` | `list(where-entry)` | Parameterize-scoped | **Pure transformation** | Scoped within where-clause elaboration |
| `current-infer-constraints-mode?` | `boolean` | Parameterize-scoped | **Pure transformation** | Feature flag; no accumulation |
| `current-sess-expr-env` | `list` | Parameterize-scoped | **Pure transformation** | Session expression context; scoped |
| `current-sess-expr-depth` | `integer` | Parameterize-scoped | **Pure transformation** | Depth counter; scoped |
| `current-capability-scope` | `list` | Parameterize-scoped | **Pure transformation** | Scoped within capability blocks |

**Assessment**: All elaborator-local parameters are scoped context that flows down the elaboration tree via `parameterize`. These are the typing *context*, not accumulated *state*. Propagator cells would add overhead without benefit — the information flows strictly top-down, never bottom-up or laterally.

### 3.7 Reduction and Caching (`reduction.rkt`)

| State Site | Type | Current Impl | Classification | Notes |
|---|---|---|---|---|
| `current-whnf-cache` | `hash: expr → expr` | Mutable hash | **Cache/fuel** | Memoization for WHNF reduction |
| `current-nf-cache` | `hash: expr → expr` | Mutable hash | **Cache/fuel** | Memoization for NF reduction |
| `current-nat-value-cache` | `hash: expr → nat` | Mutable hash | **Cache/fuel** | Memoization for nat extraction |
| `current-reduction-fuel` | `box(integer)` | Mutable box | **Cache/fuel** | Termination guarantee; decremented per step |

**Assessment**: Caches and fuel counters are performance infrastructure orthogonal to propagators. WHNF/NF caches could be propagator cells in the LSP context (invalidated when definitions change), but for batch compilation they're simple memoization tables. Leave as-is in the batch pipeline; the LSP propagator network subsumes them.

### 3.8 Warnings (`warnings.rkt`)

| State Site | Type | Current Impl | Classification | Notes |
|---|---|---|---|---|
| `current-coercion-warnings` | `list` | Parameter (list accumulator) | **Propagator-natural** | Monotonic accumulation |
| `current-deprecation-warnings` | `list` | Parameter (list accumulator) | **Propagator-natural** | Monotonic accumulation |
| `current-capability-warnings` | `list` | Parameter (list accumulator) | **Propagator-natural** | Monotonic accumulation |

**Assessment**: Warnings are monotonic accumulators. In the LSP context, they feed directly into diagnostic cells. Propagator cells here compose naturally with the diagnostic emission system.

### 3.9 Narrowing Constraints (`global-constraints.rkt`)

| State Site | Type | Current Impl | Classification | Notes |
|---|---|---|---|---|
| `current-narrow-constraints` | `list` | Parameter | **Propagator-natural** | Logic programming constraints accumulate |
| `current-narrow-var-constraints` | `hasheq` | Parameter (setter) | **Propagator-natural** | Cross-phase constraint threading; currently uses setter (not parameterize) |

**Assessment**: The narrowing system's constraints are monotonic during search. `current-narrow-var-constraints` is notable for being one of the few sites that uses a *setter* (not `parameterize`), meaning it persists across phase boundaries. A propagator cell is the natural representation — it would replace the ad-hoc setter pattern with explicit cell content.

### 3.10 Parser State (`parser.rkt`)

| State Site | Type | Current Impl | Classification | Notes |
|---|---|---|---|---|
| `current-parsing-relational-goal?` | `boolean` | Parameter | **Pure transformation** | Context flag for parser |

**Assessment**: Single context flag. Pure transformation — leave as-is.

### 3.11 Reader (`ws-reader.rkt`)

No parameters or mutable state audited. The WS reader is a pure transformation from character stream to datum. **Classification: Pure transformation.**

### 3.12 Zonking (`zonk.rkt`)

No parameters or mutable state. Pure recursive traversal that reads meta solutions. **Classification: Pure transformation.**

### 3.13 Unification (`unify.rkt`)

No local mutable state. Reads/writes metas via `metavar-store.rkt` API. **Classification: Pure transformation** (the state is in the meta store, not in unify itself).

### 3.14 Constraint Propagators (`constraint-propagators.rkt`)

No local mutable state. Constructs propagator closures that operate on the network. **Classification: Already-propagator.**

### 3.15 Driver Orchestration (`driver.rkt`)

| State Site | Type | Current Impl | Classification | Notes |
|---|---|---|---|---|
| Per-command `parameterize` block | 15+ parameters | Lines 374–400 | **Orchestration** | Resets caches, constraints, warnings per form |
| `reset-meta-store!` | Wipes all meta stores | Line 367 | **Orchestration** | Fresh state per top-level command |
| Module-level `set!` captures | 10 variables | Lines 1516–1525 | **Orchestration** | Module loading state capture |

**Assessment**: The driver's per-command `parameterize` block is the manual orchestration that propagator cells would replace. Instead of "reset everything, elaborate, resolve traits, zonk" — the network would be: "update the source cell, let propagation settle." The `reset-meta-store!` call at command entry would become "retract assumptions for the previous form" in the ATMS.

---

## 4. Classification Summary

### By Count

| Classification | Sites | % |
|---|---|---|
| **Propagator-natural** | ~42 | 52% |
| **Already-propagator** | ~10 | 12% |
| **Pure transformation** | ~16 | 20% |
| **Cache/fuel** | 4 | 5% |
| **Orchestration** | ~8 | 10% |
| **Total** | ~80 | 100% |

### By Impact

```
High Impact (migrate first):
  ┌─────────────────────────────────────────────────────────┐
  │  Constraint tracking (§3.2)     — eliminates retry loops │
  │  Global environment (§3.3)      — enables incremental    │
  │  Module registry (§3.5)         — enables incremental    │
  │  Impl/trait registries (§3.4)   — auto trait resolution  │
  └─────────────────────────────────────────────────────────┘

Medium Impact (migrate for LSP):
  ┌─────────────────────────────────────────────────────────┐
  │  Remaining registries (§3.4)    — uniform cell model     │
  │  Warnings (§3.8)                — feed diagnostic cells  │
  │  Narrowing constraints (§3.9)   — cleaner cross-phase    │
  └─────────────────────────────────────────────────────────┘

Low Impact (leave as-is):
  ┌─────────────────────────────────────────────────────────┐
  │  Elaborator context (§3.6)      — top-down flow only     │
  │  Caches/fuel (§3.7)             — orthogonal to props    │
  │  Parser flag (§3.10)            — trivial                │
  │  Reader, zonk, unify (§3.11-13) — pure transformations   │
  └─────────────────────────────────────────────────────────┘
```

---

## 5. Composition Synergies

The value of propagator-first infrastructure exceeds the sum of individual cell migrations. Here are the synergies that emerge when multiple sites are migrated together:

### 5.1 Trait Resolution Becomes Reactive

**Current**: Elaboration creates trait constraint → explicit `resolve-trait-constraints!` pass → retry loop with dirty flag → manual wakeup

**After**: Meta cell solved → propagator fires → trait constraint cell checks impl registry cell → if instance exists, trait dict cell gets content → dependent elaboration cells update

**Requires migrating**: meta store (done) + constraint tracking (§3.2) + impl registry (§3.4)

**Eliminates**: `current-retry-trait-resolve` dirty flag, `retry-traits-via-cells!` manual loop, the explicit `resolve-trait-constraints!` call in the driver

### 5.2 Incremental Module Re-elaboration

**Current**: `process-file` elaborates all forms sequentially, threading global-env through each

**After**: Each top-level definition is a cell. When file source changes (LSP `didChange`), only definitions whose source text changed get new assumptions. Downstream definitions that reference changed cells re-propagate. Unchanged definitions keep their existing cell content.

**Requires migrating**: global environment (§3.3) + module registry (§3.5) + spec store (§3.4)

**Eliminates**: Full re-elaboration on every file save; the driver's sequential `process-command` loop becomes thin event dispatch

### 5.3 Cross-Module Dependency Propagation

**Current**: Module A exports type `Foo`. Module B imports `Foo`. If A is re-elaborated, B has stale information.

**After**: Module A's export cell for `Foo` feeds into Module B's import cell. When A's cell updates, B's dependent cells re-fire.

**Requires migrating**: module registry (§3.5) + global environment (§3.3) + ns-context (§3.5)

**Eliminates**: Manual module dependency tracking; `current-loading-set` cycle detection is subsumed by propagator cycle detection (contradiction)

### 5.4 Diagnostic Emission Without Explicit Collection

**Current**: Errors accumulate in exception handlers, warnings in list accumulators, then the driver collects and emits them

**After**: Each form has a diagnostic cell. Errors propagate to it from elaboration cells. Warnings propagate from warning cells. The LSP server reads diagnostic cells directly. The batch driver reads diagnostic cells at the end.

**Requires migrating**: warnings (§3.8) + error infrastructure integration

**Eliminates**: `current-coercion-warnings` / `current-deprecation-warnings` / `current-capability-warnings` list accumulators; explicit warning collection in the driver

### 5.5 Speculative Type-Checking Becomes ATMS Assumptions

**Current**: `save-meta-state` snapshots 6 boxes. `restore-meta-state!` restores them. Used for Church fold attempts, union type checking.

**After**: Speculative elaboration creates a fresh ATMS assumption. If the speculation succeeds, the assumption is committed. If it fails, the assumption is retracted — all cells that depended on it revert to their prior content.

**Requires migrating**: Full meta store to ATMS-backed cells (partially done)

**Eliminates**: `save-meta-state` / `restore-meta-state!` box snapshot pattern; the 6-box save/restore is fragile and must be updated whenever new state is added

---

## 6. Migration Strategy

### Phase 0: Unified Cell Abstraction (Prerequisite)

Define a single `propagator-cell` abstraction that works for both the existing elaborator network and the new infrastructure cells. Currently, the elaborator network uses `elab-network` from `elaborator-network.rkt` with `net-cell-write`/`net-cell-read`. The new cells need the same API but may live outside the per-command network (e.g., module registry cells persist across commands).

**Design decision**: Single network with scoped assumptions, or layered networks (per-command + per-file + per-session)? Recommend: single network with ATMS assumption scoping, matching the LSP architecture from the Stage 2 document.

### Phase 1: Constraint Tracking → Cells (Highest Synergy)

Migrate `current-constraint-store`, `current-trait-constraint-map`, `current-hasmethod-constraint-map`, `current-capability-constraint-map` to propagator cells. Wire trait resolution as propagators on meta cells + impl registry cell.

**Files touched**: `metavar-store.rkt`, `constraint-propagators.rkt`, `macros.rkt` (trait resolution)
**Risk**: Medium — trait resolution is well-tested but the wiring is intricate
**Test strategy**: Existing 6733 tests must all pass; trait resolution behavior must be identical

### Phase 2: Registry Parameters → Cells

Migrate the 24 registry parameters (§3.4) to propagator cells in a shared network. Each registration becomes `cell-add-content!` with monotonic hash merge.

**Files touched**: `macros.rkt` (primary), `namespace.rkt`
**Risk**: Low — registries are write-once-read-many; the migration is mechanical
**Test strategy**: Module loading and prelude tests cover all registries

### Phase 3: Global Environment → Cells

Convert `current-global-env` from a threaded hasheq to per-definition cells. Each `def`/`defn`/`type` creates a cell. References to prior definitions wire propagator edges.

**Files touched**: `global-env.rkt`, `driver.rkt`, `elaborator.rkt`, `namespace.rkt`
**Risk**: High — global-env is read in nearly every pipeline stage
**Test strategy**: Full test suite + manual `.prologos` file validation

### Phase 4: ATMS Integration for Speculation

Replace `save-meta-state`/`restore-meta-state!` with ATMS assumption creation/retraction. Speculative type-checking (Church folds, union types) creates named assumptions.

**Files touched**: `metavar-store.rkt`, `elaborator.rkt`, `elab-speculation-bridge.rkt`
**Risk**: Medium — speculation is used in ~5 code paths, all well-tested
**Test strategy**: Speculation-heavy tests (Church folds, union types, bare params)

### Phase 5: Driver Simplification

With Phases 1–4 complete, the driver's per-command `parameterize` block shrinks dramatically. `reset-meta-store!` becomes assumption management. The sequential `process-command` loop becomes "add source to network, read results."

**Files touched**: `driver.rkt`
**Risk**: Low (by this point, all the hard work is done)
**Test strategy**: Full suite + `.prologos` file acceptance tests

---

## 7. What NOT to Migrate

The following should remain as-is:

| Component | Reason |
|---|---|
| WS reader | Pure char→datum transformation; no partial information |
| Parser | Pure datum→AST transformation; no accumulation |
| Zonking | Pure traversal reading cell content; becomes simpler with cells but doesn't need to be one |
| Unification | Pure algorithm operating on cells; the cells are in metavar-store, not in unify |
| Reduction caches | Performance optimization; memoization tables are appropriate |
| Reduction fuel | Termination guarantee; a counter in a box is the right abstraction |
| Elaborator context params | Top-down context flow via `parameterize`; no bottom-up or lateral propagation |
| Parser context flag | Trivial; single boolean |
| Startup callbacks | Set once, never change; configuration, not state |

---

## 8. Relationship to LSP Architecture

The Stage 2 LSP document (`2026-03-11_LSP_VSCODE_STAGE2_REFINEMENT.md` §9) designs a propagator network for LSP state management. This audit reveals that **the LSP network and the batch pipeline network should be the same network** — just with different scoping:

- **Batch mode**: Network is created fresh per file, forms are added sequentially, results are read at the end
- **LSP mode**: Network persists across edits, forms are added/updated via ATMS assumptions, results are published as diagnostics/types/completions

The cell abstraction, the propagator wiring, and the ATMS integration are identical. The difference is lifecycle management:

```
Batch:   create network → add all forms → read all results → discard network
LSP:     create network → add forms → publish results → [edit] → retract+add → re-publish → ...
```

This is the deepest composition synergy: **building propagator-first infrastructure for the batch pipeline IS building the LSP infrastructure.** They share cells, propagators, and ATMS — just with different assumption management.

---

## 9. Effort Estimates

| Phase | Scope | Est. Effort | Prerequisite |
|---|---|---|---|
| Phase 0 | Unified cell abstraction | 2–3 days | None |
| Phase 1 | Constraint tracking → cells | 3–5 days | Phase 0 |
| Phase 2 | Registry parameters → cells | 2–3 days | Phase 0 |
| Phase 3 | Global environment → cells | 5–8 days | Phase 0 |
| Phase 4 | ATMS speculation | 3–5 days | Phases 1, 3 |
| Phase 5 | Driver simplification | 2–3 days | Phases 1–4 |
| **Total** | | **17–27 days** | |

These estimates assume the existing test suite provides sufficient regression coverage (it does — 6733 tests across 349 files).

---

## 10. Decision Framework

### Migrate Now (Before LSP Implementation)

**Argument for**: Building propagator-first infrastructure in the batch pipeline means the LSP server can reuse it directly. The LSP Tier 1 (Syntax & Static) doesn't need it, but Tiers 2–5 all benefit. Starting early means the infrastructure is proven before LSP needs it.

**Argument against**: The batch pipeline works. 6733 tests pass. Migrating introduces risk with no immediate user-facing benefit. The LSP can build its own network initially and the batch pipeline can migrate later.

### Migrate During LSP (Opportunistically)

**Argument for**: Each LSP tier introduces new propagator requirements. Phase 0 (cell abstraction) happens naturally during Tier 2 (diagnostics). Phases 1–2 happen during Tier 3 (type intelligence). Phase 3 happens during Tier 4 (eval). This spreads the migration cost across LSP development.

**Argument against**: Mixing infrastructure migration with feature development increases cognitive load. Each LSP tier would involve both "build new thing" and "retrofit old thing" work.

### Recommended: Hybrid

1. **Phase 0 now** — define the cell abstraction as a standalone module, tested in isolation
2. **Phases 1–2 during LSP Tier 2–3** — constraint cells and registry cells directly serve diagnostics and type intelligence
3. **Phase 3 during LSP Tier 4** — global-env cells directly serve incremental eval
4. **Phases 4–5 after LSP Tier 5** — ATMS speculation and driver simplification are quality-of-life improvements that benefit from LSP experience

---

## 11. Open Questions

1. **Single network or layered networks?** The audit suggests a single network with ATMS scoping. But per-command state reset (`reset-meta-store!`) currently wipes everything — does a single persistent network require rethinking the per-command boundary?

2. **CHAMP box migration path**: The existing CHAMP boxes in `metavar-store.rkt` are a proto-propagator pattern. Should Phase 1 preserve them (adding cell wrappers around boxes) or replace them (cells with CHAMP content)?

3. **Circular dependency breaking**: The callback pattern (`current-prop-make-network`, `current-prop-cell-write`, etc.) exists to break `metavar-store → elaborator-network → type-lattice → reduction → metavar-store` cycles. A unified cell module might resolve this — or might make it worse.

4. **Performance**: Propagator cell overhead vs. raw `hash-set!`. For batch compilation where incrementality doesn't matter, cells add indirection. Is the overhead acceptable? (Likely yes — the existing propagator network for elaboration hasn't caused measurable slowdown, and the constraint propagators are already cell-based.)

---

## Appendix A: Complete Parameter Inventory

For reference, here is every `current-*` parameter in the pipeline, grouped by classification:

### Propagator-Natural (migrate to cells)
```
;; metavar-store.rkt — constraint tracking
current-constraint-store
current-wakeup-registry
current-trait-constraint-map
current-trait-wakeup-map
current-hasmethod-constraint-map
current-capability-constraint-map
current-retry-trait-resolve          ; dirty flag → eliminated by propagation
current-retry-unify                  ; dirty flag → eliminated by propagation

;; global-env.rkt
current-global-env
current-defn-param-names

;; namespace.rkt
current-module-registry
current-ns-context

;; macros.rkt — all 24 registries
current-preparse-registry
current-spec-store
current-propagated-specs
current-schema-registry
current-ctor-registry
current-type-meta
current-subtype-registry
current-coercion-registry
current-trait-registry
current-trait-laws
current-impl-registry
current-param-impl-registry
current-bundle-registry
current-specialization-registry
current-capability-registry
current-selection-registry
current-session-registry
current-strategy-registry
current-process-registry
current-property-store
current-functor-store
current-user-precedence-groups
current-user-operators
current-macro-registry

;; warnings.rkt
current-coercion-warnings
current-deprecation-warnings
current-capability-warnings

;; global-constraints.rkt
current-narrow-constraints
current-narrow-var-constraints
```

### Already-Propagator (in existing network)
```
;; metavar-store.rkt — meta stores + network
current-meta-store
current-level-meta-store
current-mult-meta-store
current-sess-meta-store
current-prop-net-box
current-prop-id-map-box
current-prop-meta-info-box
current-level-meta-champ-box
current-mult-meta-champ-box
current-sess-meta-champ-box
current-trait-cell-map
```

### Pure Transformation / Context (leave as-is)
```
;; elaborator.rkt — scoped context
current-relational-env
current-relational-fallback?
current-where-context
current-infer-constraints-mode?
current-sess-expr-env
current-sess-expr-depth
current-capability-scope

;; namespace.rkt — configuration
current-lib-paths
current-loading-set
current-module-loader
current-spec-propagation-handler
current-foreign-handler

;; parser.rkt
current-parsing-relational-goal?

;; errors.rkt
current-emit-error-diagnostics
```

### Cache/Fuel (performance; orthogonal)
```
;; reduction.rkt
current-whnf-cache
current-nf-cache
current-nat-value-cache
current-reduction-fuel
```

### Propagator Callbacks (break circular deps; resolved by unified module)
```
;; metavar-store.rkt
current-prop-make-network
current-prop-fresh-meta
current-prop-cell-write
current-prop-cell-read
current-prop-add-unify-constraint
current-prop-fresh-mult-cell
current-prop-mult-cell-write
current-prop-has-contradiction?
current-prop-run-quiescence
current-prop-unwrap-net
current-prop-rewrap-net
```
