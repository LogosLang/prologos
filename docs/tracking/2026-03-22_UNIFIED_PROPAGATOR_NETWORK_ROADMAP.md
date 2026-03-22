# Unified Propagator Network Infrastructure — Comprehensive Roadmap

**Date**: 2026-03-22
**Type**: Stage 2 Architectural Audit + Roadmap
**Source**: Track 8 PIR §12 Principles Audit → "What would it take to bring everything on-network?"

---

## 1. The Vision

Every piece of state that participates in elaboration, type inference, constraint solving, or module loading lives as cells on a propagator network. No mutable boxes. No parameter-based registries. No dual-writes. No `zonk`.

The propagator network becomes the **single source of truth** for all compilation state. The elaborator is a thin AST walker that creates cells and installs propagators. All derived state — type solutions, trait resolutions, constraint status, reduction results — emerges from propagation. The "compilation pipeline" is not a sequence of passes but a network reaching fixpoint.

### What "Disappears"

| Current Infrastructure | What Replaces It | Why It Disappears |
|----------------------|-----------------|-------------------|
| **`zonk`** (recursive meta substitution) | Cell reads — cell values ARE the current solutions | No `expr-meta` nodes in live expressions; metas are cell references |
| **`current-prop-net-box`** (mutable box) | Value-threaded network or network-as-environment | No box means no unbox/set-box! discipline |
| **Dual-writes** (parameter + cell) | Cell-only writes; module loading creates network first | No parameter path means no sync to maintain |
| **`restore-meta-state!`** | Already retired (Track 8 B1) | Worldview-aware reads handle speculation |
| **`solve-meta!` re-entrant chain** | Cell write triggers propagator cascade | No imperative chain; resolution is propagation |
| **S2 scan loop** | Bridge propagators in S0 (Track 8 C1-C3, corrected in 8D) | Readiness is structural (propagator fires when deps solved) |
| **Callback parameters** (35+) | Direct function calls or propagator installation | No injection indirection needed when everything is on-network |
| **Per-command cache reset** | Cell invalidation via dependency tracking | Cache entries are cells; source changes propagate to invalidate |

### What Remains (Correctly Off-Network)

| System | Why Off-Network Is Correct |
|--------|---------------------------|
| **I/O state** (`fio-port-table`) | External system interaction; not compilaton state |
| **Performance counters** | Observational, not semantic |
| **Parser state** (`current-qq-depth`, etc.) | Syntactic phase, pre-network |
| **Command-line flags** | Configuration, not compilation state |

---

## 2. Current State: The 205-Parameter Landscape

A comprehensive audit found **205 Racket parameters** across the production codebase, categorized by their relationship to the network:

### Category A: Should Become Cells (Primary Migration Targets)

| Group | Parameters | Current Storage | Track |
|-------|-----------|-----------------|-------|
| **Registries** (20) | impl, trait, param-impl, constructor, schema, capability, selection, session, strategy, macro, etc. | Hash in parameter + cell-ID pointer + callback | PM 8D (3 registries) → PM 8E (remaining 17) |
| **Meta stores** (4) | meta, mult, level, session | hasheq in parameter | PM 8F |
| **Constraint stores** | narrow-constraints, narrow-var-constraints, narrow-intervals | hasheq in parameter | BSP-LE Track 2+ |
| **Warning accumulators** (9) | capability, coercion, deprecation warnings + cell-IDs | list in parameter | PM 8E |
| **Resolution state** | resolution bridges, retry callbacks, executor | callback in parameter | PM 8D (3 bridges) → PM 8E |
| **Caches** (3) | nf-cache, whnf-cache, nat-value-cache | hasheq in parameter | PM Track 9 |

### Category B: Architectural Redesign Required

| Group | Parameters | Challenge | Track |
|-------|-----------|-----------|-------|
| **`current-prop-net-box`** | 1 (but 197 access sites) | Central seam; requires value-threading the network | PM 8D (bridges) → PM Track 10 (full) |
| **Global env** (5) | definitions, prelude, module content | Persistent across commands; needs cross-command network | PM Track 10 |
| **Module registry** (8) | module loading, namespaces | Must load before network exists (chicken-and-egg) | PM Track 10 |
| **Elaboration state** (6) | typing context, session depth, relational env | Per-command ephemeral; may stay as parameters | Evaluate |
| **Unification** | reads/writes through box | Algorithm replacement (propagator-based) | BSP-LE Track 2 |
| **Reduction** | reads metas through box | Algorithm replacement (e-graph / propagator) | PM Track 9 |

### Category C: Correctly Off-Network (No Action)

| Group | Parameters | Reason |
|-------|-----------|--------|
| **I/O** (2) | fio-port-table, fio-read-cache | External system |
| **Performance** (6) | counters, observers, verbose mode | Observational |
| **Parser/reader** (5) | qq-depth, parsing-relational?, tycon-arity | Pre-network syntactic phase |
| **Scheduler** (3) | bsp-scheduler?, speculation-stack, observer | Network infrastructure, not data |
| **Configuration** (5) | misc flags and toggles | Static per-session |

---

## 3. The Zonk Question

### Does Zonk Disappear?

**During elaboration: yes.** If metas are cell references (not `expr-meta` AST nodes), then reading an expression reads current cell values. There's nothing to substitute — the cell IS the meta's current value. `zonk` exists because the expression tree contains `expr-meta id` placeholders that must be replaced with solutions. If expressions reference cells instead, "the solution" is just the cell value.

**At command boundaries: it transforms into "freeze."** When a definition is finalized and stored in the global env, cell values must be snapshot into a ground expression (no cell references). This is conceptually zonk — but it's a single-pass read at a well-defined boundary, not a recursive substitution scattered across the codebase.

**The architectural shift**:

```
CURRENT:
  expr-meta id  →  meta-solution id  →  box  →  cell  →  value
  (scattered, recursive, any time, through box)

FUTURE:
  cell-ref cid  →  net-cell-read net cid  →  value
  (direct, one-step, during elaboration, from network)

  freeze(expr, net)  →  walk expr, read all cell-refs  →  ground expr
  (once, at command boundary, for storage in global env)
```

**Impact on codebase**:
- `zonk.rkt` (~1300 lines): Replaced by `freeze` (~200 lines estimated)
- `zonk-at-depth` (depth-shifting): Moves to `freeze` — same logic, but only at boundaries
- `zonk-final` (defaulting unsolved metas): Moves to `freeze-final`
- 200+ call sites of `zonk`: Eliminated during elaboration; `freeze` called only at command boundary in `process-command`

### Does `ground-expr?` Disappear?

**For bridges: yes** (Track 8D, §3.4). Cell values are either solutions or bottom. Bridges check for non-bottom.

**For elaboration: transforms.** Instead of "does this expression contain `expr-meta`?", the question becomes "are all referenced cells solved?" — which is a cell-level query, not an expression walk.

---

## 4. Track Series Roadmap

### PM Track 8D: Principled Resolution Infrastructure (IMMEDIATE)
*Scope: Bridges + 3 registries. Design complete.*
- Phase 1: Impl/trait/param-impl registry cells
- Phase 3: Pure α/γ bridge fire functions
- Phase 4: Callback retirement (6 symptomatic)
- Phase 7: Verification

### PM Track 8E: Registry Consolidation
*Scope: Remaining 17 registries + warning accumulators + resolution state.*
- The 3-tuple pattern (hash parameter, cell-ID pointer, callback) → single cell per registry
- Consolidate: constructor, schema, capability, selection, session, strategy, macro, termination, confluence, multi-defn, def-tree registries
- Warning cells: capability, coercion, deprecation → accumulative cells
- Elimination of dual-write pattern (B2e) for all registries
- **Depends on**: Track 8D proving the registry-cell pattern

### PM Track 8F: Meta-Info as Network State
*Scope: Meta-info CHAMP, id-map CHAMP, meta stores → cells or eliminated.*
- **Key question**: Can meta-info become cells without O(N) wakeup cost per fresh-meta?
  - Option A: One cell per meta (meta-info IS the cell info) — eliminates the CHAMP
  - Option B: Batched meta-info cell (write once per command, not per fresh-meta)
  - Option C: Meta-info stays as struct field (current, with worldview-aware reads) — acceptable if not the bottleneck
- Id-map may be eliminated: if metas ARE cells, the "id-map" is identity
- **Risk**: High — meta-info is the most-accessed structure. Performance regression possible.
- **Depends on**: Track 8E completing registry consolidation (reduces parameter count, simplifies initialization)

### PM Track 9: Reduction as Propagators
*Scope: Reduction/normalization on the network.*
- Research basis: e-graph rewriting, interaction nets, Geometry of Interaction, optimization lattices
- `reduce` and `whnf` become propagator-driven
- Normal form cache becomes the network itself — cell values ARE normal forms
- `nf-cache`, `whnf-cache`, `nat-value-cache` eliminated (redundant with cells)
- **Depends on**: Track 8F (metas as cells — reduction needs to read meta solutions)
- **This may be a Track Series** given the scope and research depth

### PM Track 10: Network-First Initialization
*Scope: Module loading on-network. Global env as persistent cells. Box elimination.*
- **The chicken-and-egg problem**: Currently, module loading happens without a network (parameters only), and the network is created per-command. Track 10 inverts this: the network is created at startup, module loading writes to it, and per-command elaboration is a subgraph.
- Global env → persistent cells spanning commands
- Module registry → persistent cells
- Definition cells → persistent (already partially there via `current-definition-cell-ids`)
- `current-prop-net-box` → **eliminated**. The network is the environment.
- Dual-writes eliminated: module loading writes to cells directly
- Testing infrastructure: `with-fresh-meta-env` creates a subnetwork, not a parameterize block
- **This is the culminating track** — it removes the last off-network compilation state
- **Depends on**: Tracks 8D, 8E, 8F, 9 (all state must be on-network first)
- **This may be a Track Series** given the module-loading redesign scope

### BSP-LE Track 2+: Propagator-Based Unification
*Scope: `unify-core` as propagator network operations.*
- Already partially scoped in BSP-LE Series (Track 2: UnionFind on propagators)
- Structural unification as propagator decomposition (existing `decompose-pi` pattern)
- Constraint retry as propagator cascade (no S2 scan)
- **Intersects with**: PM Track 9 (reduction during unification) and PM Track 10 (box elimination)

---

## 5. Dependency Graph

```
PM Track 8D ──→ PM Track 8E ──→ PM Track 8F
(3 registries)   (17 registries)   (meta-info)
     │                                  │
     │                                  ↓
     │                            PM Track 9
     │                          (reduction on network)
     │                                  │
     │                                  ↓
     └────────────────────────→ PM Track 10
                              (network-first init,
                               box elimination,
                               module loading on network)

BSP-LE Track 2 ─────────────→ PM Track 10
(propagator unification)       (converges here)
```

### The Convergence Point: Track 10

Track 10 is where everything converges. After Track 10:
- No mutable box
- No parameter-based registries
- No dual-writes
- No `zonk` during elaboration
- Module loading writes to cells
- Global env is persistent cells
- Testing uses subnetworks, not parameterize blocks
- The elaborator is a thin walker that creates cells and installs propagators

### Estimated Scope

| Track | Estimated Phases | Estimated Effort | Risk |
|-------|-----------------|------------------|------|
| 8D | 4 core + 3 deferred | 1-2 sessions | Low (design complete) |
| 8E | 5-7 phases | 2-3 sessions | Low (repetitive pattern) |
| 8F | 3-5 phases | 2-3 sessions | High (performance-sensitive) |
| 9 | 8-12 phases (or sub-series) | 4-8 sessions | High (algorithm change) |
| 10 | 10-15 phases (or sub-series) | 6-12 sessions | Very High (architectural inversion) |
| BSP-LE T2 | 6-8 phases | 3-5 sessions | Medium (well-researched) |

Total: **~20-40 sessions** to full network-first architecture. This is a multi-month effort, but each track delivers standalone value:
- Track 8D: Correct bridges (unblocks CIU)
- Track 8E: Simplified initialization (fewer parameters, fewer bugs)
- Track 8F: Streamlined meta management
- Track 9: Incremental compilation groundwork
- Track 10: The architectural payoff — everything is one system

---

## 6. The Architectural Endpoint

After all tracks complete, the Prologos compilation model is:

```
Source text
    ↓
Parser (off-network, syntactic)
    ↓
Elaborator (thin walker)
    ├── Creates meta cells for unknowns
    ├── Installs type propagators for constraints
    ├── Installs bridge propagators for trait resolution
    ├── Installs reduction propagators for normalization
    └── Writes to registry cells for definitions
    ↓
Propagator Network (single fixpoint)
    ├── Type cells reach fixpoint (inference)
    ├── Trait resolution via bridge propagators (α/γ)
    ├── Reduction via e-graph propagators
    ├── Constraint satisfaction via BSP scheduling
    └── Session verification via cross-domain bridges
    ↓
Freeze (command boundary)
    ├── Read all cell values → ground expressions
    ├── Store in persistent registry cells
    └── Report errors from contradiction cells
    ↓
Global persistent network (cross-command)
    ├── Module definitions as persistent cells
    ├── Impl/trait registries as persistent cells
    └── Next command's elaboration network extends this
```

The compilation "pipeline" becomes:
1. **Parse** (sequential, off-network)
2. **Elaborate** (creates network topology)
3. **Propagate** (network reaches fixpoint — ALL inference, resolution, reduction)
4. **Freeze** (snapshot cell values at boundary)

Steps 2-3 are not separate passes — elaboration emits constraints, propagation resolves them, and the interleaving is controlled by the network's quiescence semantics.

---

## 7. Principles Alignment

| Principle | How the Endpoint Serves It |
|-----------|---------------------------|
| **Propagator-First** | Everything IS propagators. No alternative paths. |
| **Data Orientation** | All state is cells (data). All computation is propagators (pure functions on data). |
| **Correct-by-Construction** | Derived state is always consistent — the network enforces it. No manual invalidation. |
| **First-Class by Default** | Cells are first-class values. Propagators are first-class functions. Composable with every other cell/propagator. |
| **Decomplection** | Type inference, trait resolution, reduction, constraint solving are separate propagator layers — each independently replaceable. |
| **Completeness** | The hard thing (propagator network for everything) makes the easy thing (incremental compilation, correct speculation, cache invalidation) fall out structurally. |
| **Composition** | Every new domain (sessions, capabilities, effects) plugs in as bridge propagators between its cells and the existing network. Emergent cross-domain inference. |
| **Progressive Disclosure** | Users see `spec`/`defn`/`impl`. The propagator network is invisible infrastructure. |
| **Ergonomics** | No zonk. No dual-writes. No callback installation ritual. |
| **Most General Interface** | The propagator network IS the most general interface — any monotone lattice, any domain, any Galois connection. |
