# Logic Engine Subsystem Audit

**Date**: 2026-03-03
**Status**: Audit Complete
**Scope**: Every Prologos subsystem evaluated for propagator network mapping

---

## Table of Contents

- [1. Executive Summary](#1-executive-summary)
- [2. Current LE Infrastructure](#2-current-le-infrastructure)
- [3. Subsystems Already on Propagator Networks](#3-subsystems-on-networks)
  - [3.1 Capability Inference](#31-capability-inference)
  - [3.2 Cross-Domain Bridge (Cap <-> Type)](#32-cross-domain-bridge)
  - [3.3 Elaboration Network (Ready, Not Adopted)](#33-elaboration-network)
  - [3.4 Tabling / SLG Memoization](#34-tabling)
  - [3.5 ATMS Provenance](#35-atms)
  - [3.6 Union-Find](#36-union-find)
- [4. Subsystems NOT on Propagator Networks](#4-subsystems-not-on-networks)
  - [4.1 Unification](#41-unification)
  - [4.2 Type Inference (Core Elaborator)](#42-type-inference)
  - [4.3 QTT Multiplicity Checking](#43-qtt)
  - [4.4 Trait Resolution](#44-trait-resolution)
  - [4.5 Reduction Engine](#45-reduction)
  - [4.6 Schema Validation](#46-schema-validation)
  - [4.7 Module System / Namespace](#47-module-system)
  - [4.8 Test Runner / Dependency Tracking](#48-test-runner)
  - [4.9 Session Type Checking](#49-session-types)
- [5. Cross-Network Topology: What Talks to What](#5-cross-network-topology)
- [6. The Testing Infrastructure Question](#6-testing-infrastructure)
- [7. The Dependent Types / Unification Question](#7-dependent-types-unification)
- [8. Recommendations](#8-recommendations)
- [9. Priority Matrix](#9-priority-matrix)

---

<a id="1-executive-summary"></a>

## 1. Executive Summary

Prologos has a mature, persistent/immutable propagator network infrastructure (`propagator.rkt`)
that is production-proven through capability inference (Phase 5-8c) and has ready-but-unadopted
support for type inference (`elaborator-network.rkt`). The infrastructure includes:

- **Core**: Persistent cells with per-cell lattice merge, monotone propagators, fuel-bounded
  quiescence scheduling (Gauss-Seidel sequential + BSP parallel)
- **Cross-domain**: Bidirectional Galois connections via `net-add-cross-domain-propagator`
- **Provenance**: ATMS assumption tracking, nogood recording, dependency-directed backtracking
- **Search**: Union-find for equivalence classes, tabling for memoization
- **Domains**: `Lattice` trait, `Widenable` trait, `GaloisConnection` trait, `HasTop` trait

**Key findings**:

| Category | Subsystems | Verdict |
|----------|-----------|---------|
| Already on LE | Capability inference, cross-domain bridge, tabling, ATMS, union-find | Healthy, production-ready |
| Should migrate | Type inference (elaborator), testing provenance | High value, infrastructure ready |
| Could benefit | Unification, trait resolution, session types | Medium value, design work needed |
| Not beneficial | Reduction engine, QTT checking, module system, schema validation | Leave as-is |

The single highest-impact opportunity is **ATMS-backed type inference with provenance-rich error
diagnostics**, which would transform error messages from "expected X, got Y" to full derivation
chains explaining WHY each type was inferred. The infrastructure for this already exists in
`elaborator-network.rkt` and `atms.rkt`.

---

<a id="2-current-le-infrastructure"></a>

## 2. Current LE Infrastructure

### 2.1 Core Propagator Network (`propagator.rkt`)

The fundamental data model:

```
prop-network (persistent, immutable):
  cells:          CHAMP(cell-id -> prop-cell)      ;; lattice-valued cells
  propagators:    CHAMP(prop-id -> propagator)      ;; monotone fire functions
  worklist:       [prop-id]                         ;; scheduled propagators
  merge-fns:      CHAMP(cell-id -> merge-fn)        ;; per-cell lattice join
  contradiction-fns: CHAMP(cell-id -> contradicts?) ;; per-cell bottom detection
  widen-fns:      CHAMP(cell-id -> (widen . narrow)) ;; for infinite-height lattices
  fuel:           Nat                                ;; step limit
  contradiction:  #f | cell-id                       ;; early exit on inconsistency
```

Key operations: `net-new-cell`, `net-cell-read`, `net-cell-write` (lattice join),
`net-add-propagator`, `run-to-quiescence`, `run-to-quiescence-bsp`,
`net-add-cross-domain-propagator`.

### 2.2 Performance Characteristics

| Operation | Cost | Notes |
|-----------|------|-------|
| Cell read/write | O(log n) | CHAMP trie |
| Add propagator | O(k log n) | k = input count |
| Quiescence (sequential) | O(p * m) | p = propagators, m = avg merge |
| Quiescence (BSP) | O(h) rounds | h = lattice height |
| **Backtrack** | **O(1)** | Keep old network reference |
| **Snapshot** | **O(1)** | Network is a value |

### 2.3 Lattice Trait Ecosystem (Prologos-level)

Implemented lattice instances:
- `FlatLattice A` — flat domain (bot, value, top)
- `SetLattice A` — powerset with union join
- `MapLattice K V` — pointwise join over maps
- `IntervalLattice` — numeric intervals with hull join
- `BoolLattice` — three-valued Boolean
- `Sign`, `Parity` — abstract numeric domains
- `CapabilitySet` — powerset of capability names (Racket-level)
- `Type` — type lattice (bot/concrete/top) via `type-lattice.rkt`

Implemented Galois connections:
- `GaloisConnection Interval Bool` — interval -> truthiness
- `GaloisConnection Interval Sign` — interval -> sign
- Type <-> Capability bridge (`cap-type-bridge.rkt`)

---

<a id="3-subsystems-on-networks"></a>

## 3. Subsystems Already on Propagator Networks

### 3.1 Capability Inference

**Files**: `capability-inference.rkt`, `cap-type-bridge.rkt`
**Status**: PRODUCTION READY

**Architecture**:
- One cell per function -> `CapabilitySet` (powerset lattice)
- One propagator per call edge -> propagates callee's caps to caller
- Declared capabilities seeded as initial cell values
- `run-to-quiescence` computes transitive closure

**ATMS integration**: Each (function, capability) declaration is an ATMS assumption.
Support sets propagate to explain "why does f require cap C?" with full derivation chains.

**Cross-domain bridge**: `cap-type-bridge.rkt` implements alpha/gamma between Type domain
and CapabilitySet domain. Enables overdeclared-authority detection (function declares caps
it never exercises).

**Assessment**: Fully realized. Template for future subsystem migrations.

### 3.2 Cross-Domain Bridge (Cap <-> Type)

**File**: `cap-type-bridge.rkt`
**Status**: PRODUCTION READY

Bidirectional abstraction:
- alpha: `type-expr -> cap-set` (extract capability type names)
- gamma: `cap-set -> type-expr` (convert cap-set to type union)
- Uses `net-add-cross-domain-propagator` for auto-synchronization
- Termination guaranteed by monotone alpha/gamma + no-change guard

**Novel application**: Overdeclared analysis — identifies capabilities a function declares
but never needs, by comparing declared set with propagated set.

### 3.3 Elaboration Network (Ready, Not Adopted)

**File**: `elaborator-network.rkt`
**Status**: IMPLEMENTED, NOT YET USED BY CORE ELABORATOR

Wraps `prop-network` with type-inference semantics:
- `elab-fresh-meta` -> allocate cell initialized to `type-bot`
- `elab-add-unify-constraint` -> bidirectional unification propagator
- `elab-solve` -> `run-to-quiescence` + contradiction check
- Fast-path: if both cells already ground, eager merge (skip propagator)

**Why not adopted yet**: The core elaborator (`typing-core.rkt`) uses older `metavar-store.rkt`
with imperative `solve-meta!`. Migration is Phase E3 (deferred) of the elaborator refactoring.
The infrastructure is proven; the refactoring is a large but low-risk effort.

### 3.4 Tabling / SLG Memoization

**File**: `tabling.rkt`
**Status**: IMPLEMENTED

Answer sets live in propagator cells:
- `all` mode: list-based set-union merge (dedup on insert)
- `first` mode: keep first answer, freeze cell

Backed by `table-store` wrapping `prop-network`. Used by stratified evaluation
for tabled relation answers.

### 3.5 ATMS Provenance

**File**: `atms.rkt`
**Status**: IMPLEMENTED

Records assumptions, support sets, nogoods, worldviews. Used by capability inference
for audit trails. Key operations: `atms-assume`, `atms-retract`, `atms-add-nogood`,
`atms-amb`, `atms-solve-all`.

**This is the key enabler for testing/debugging provenance** (see Section 6).

### 3.6 Union-Find

**File**: `union-find.rkt`
**Status**: IMPLEMENTED

Persistent disjoint sets with path splitting. Complementary to propagator network
(tracks equivalence classes). O(log n) amortized with persistence.

---

<a id="4-subsystems-not-on-networks"></a>

## 4. Subsystems NOT on Propagator Networks

### 4.1 Unification (`unify.rkt`)

**Current approach**: Imperative side-effectful unification.

```
unify(ctx, t1, t2):
  1. WHNF-reduce both sides
  2. If structurally equal -> #t
  3. If meta on one side -> solve-meta!(id, rhs) [MUTATES metavar-store]
  4. If decomposable -> recurse on subterms
  5. Otherwise -> #f or 'postponed (for constraint retry)
```

**Can this be put on a propagator network?** YES.

**How?** Each metavariable becomes a cell in the type lattice (bot/concrete/top).
Unification constraints become bidirectional propagators: when either cell gains information,
propagate to the other. `elaborator-network.rkt` already implements this as
`elab-add-unify-constraint`.

**Benefits**:
- **O(1) backtracking**: Current `save-meta-state`/`restore-meta-state!` deep-copies the
  entire metavar hash (O(n)). Propagator network backtracking is O(1) — just keep the old
  network reference.
- **Parallel unification**: Independent unification constraints can fire concurrently via BSP.
- **Provenance**: ATMS tracks WHY each metavariable was solved, enabling richer error messages.
- **Speculative type checking**: Current Church fold / union type speculation uses
  save/restore. Propagator approach: ATMS worldview branching, with nogood learning.

**Costs**:
- O(log n) per cell operation (CHAMP trie) vs O(1) for hash mutation.
- Requires benchmarking to confirm net benefit.
- Large refactoring effort (touches typing-core.rkt, elaborator.rkt, constraint handling).

**Shared network?** YES — should share network with type inference (Section 4.2) since
unification IS type inference. Same cells, same lattice.

**Cross-domain bridges**: Unification network <-> capability inference (existing bridge).
Unification network <-> QTT multiplicity (new bridge, see Section 4.3).

**Assessment**: HIGH VALUE. The infrastructure (`elaborator-network.rkt`) already exists.
This is the single most impactful migration.

### 4.2 Type Inference (Core Elaborator)

**Current approach**: `typing-core.rkt` uses `metavar-store.rkt` (mutable hash) +
`solve-meta!` for metavar instantiation + `constraint` structs for deferred constraints +
`resolve-trait-constraints!` as post-inference pass.

**Can this be put on a propagator network?** YES — this IS the planned Phase E3 migration.

**How?** Replace `metavar-store` with `elaborator-network`:
- `fresh-meta!` -> `elab-fresh-meta`
- `solve-meta!` -> `net-cell-write` (lattice join)
- `save-meta-state`/`restore-meta-state!` -> keep old network (O(1))
- Deferred constraints -> propagators that fire when input cells gain information
- Trait resolution -> propagator that watches the type cell and fires when ground

**Benefits** (same as unification, plus):
- **Constraint wakeup for free**: Currently `solve-meta!` runs `run-to-quiescence` after
  each cell write (Phase E2). On a real propagator network, this is the natural behavior.
- **Trait resolution as propagation**: A trait constraint "Eq A" becomes a propagator on
  cell A. When A is solved to `Int`, the propagator fires and resolves the constraint.
  Currently this is a separate post-inference pass.
- **Multi-phase inference**: Different inference phases (check, solve traits, zonk) become
  different sets of propagators on the same network. No need for separate passes.

**Shared network?** YES — unified with unification (same cells).

**Cross-domain bridges**:
- Type <-> Capability (existing)
- Type <-> QTT multiplicity (new)
- Type <-> Session type (future)

**Assessment**: HIGH VALUE. Planned migration (Phase E3). Infrastructure ready.

### 4.3 QTT Multiplicity Checking (`qtt.rkt`)

**Current approach**: `UsageCtx` (list of multiplicities parallel to typing context).
`inferQ`/`checkQ` track multiplicities imperatively during type inference.

**Can this be put on a propagator network?** PARTIALLY.

**How?** Multiplicities form a lattice: `0 <= 1 <= omega`. Each variable's multiplicity
could be a cell. Usage propagators would accumulate actual usage. Final check: compare
inferred usage with declared multiplicity.

**Benefits**:
- **Multiplicity inference via propagation**: Instead of tracking usage imperatively,
  let the network infer multiplicities. Fresh multiplicity metas are cells; each use
  writes to the cell; final check is "did cell reach contradiction?"
- **Cross-domain with type inference**: A Galois connection between type domain and
  multiplicity domain could propagate "this type is linear, so its multiplicity must be 1"
  information bidirectionally.

**Costs**:
- QTT's current context-threading approach is natural and efficient for the common case.
- Propagator overhead may not pay off for the typical (small context, few linear vars) case.
- The multiplicity lattice is tiny (3 elements) — minimal benefit from parallel propagation.

**Shared network?** If migrated, should share with type inference network (same context).

**Assessment**: MEDIUM VALUE. The multiplicity lattice is too small for propagation to
shine. Consider only as part of the larger type inference migration.

### 4.4 Trait Resolution (`trait-resolution.rkt`)

**Current approach**: Registry-walk search. Walk trait registry, attempt monomorphic then
parametric resolution, solve metas in resolved dict expression.

**Can this be put on a propagator network?** YES, but it's a different kind of benefit.

**How?** Trait constraints become propagator cells. A trait constraint `Eq A` is a cell
whose value is either `unsolved`, `resolved(dict-expr)`, or `contradiction`. A propagator
watches cell A (the type of the constrained variable). When A is solved, the propagator
attempts trait resolution and writes to the constraint cell.

**Benefits**:
- **Automatic wakeup**: No need for explicit constraint retry loop. When a type variable
  is solved, all trait constraints watching it are automatically re-examined.
- **Speculative resolution**: ATMS can try multiple trait instances and learn nogoods.
- **Interaction with type inference**: Trait resolution can feed information BACK to
  type inference (e.g., resolving `Num A` to `Num Int` constrains A to Int).

**Current partial implementation**: Phase E2 already has `solve-meta!` running
`run-to-quiescence` for transitive propagation. Phase C has incremental trait resolution
via wakeup callbacks. These are steps TOWARD full propagator-based trait resolution.

**Costs**:
- Current registry-walk is fast and well-tested.
- Propagator-based resolution adds architectural complexity.

**Assessment**: MEDIUM VALUE. Natural complement to type inference migration.
Don't migrate independently — migrate as part of Phase E3.

### 4.5 Reduction Engine (`reduction.rkt`)

**Current approach**: Pure functions. `whnf(e)` and `nf(e)` are deterministic term rewriting.

**Can this be put on a propagator network?** NO meaningful benefit.

**Why not**: Reduction is a deterministic, forward-only computation. No search, no
constraint propagation, no multi-directional information flow. A single forward pass
is optimal. Adding a propagator network would only add overhead.

**Exception**: Lazy/incremental reduction (memoize normal forms in cells, re-reduce only
when substitution changes) could use a propagator-like cache. But `current-nf-cache`
already provides this. No architectural change needed.

**Assessment**: NO VALUE. Leave as-is.

### 4.6 Schema Validation (`macros.rkt`)

**Current approach**: Compile-time validation in preparse (`:closed` field checking,
`:check` assertion wrapping, `:default` injection). Runtime assertions via `if/panic`.

**Can this be put on a propagator network?** Not the current static validation.
But runtime schema checking as constraint propagation is interesting (see Section 8).

**Assessment**: NO VALUE for current implementation. Future consideration for
runtime constraint checking (see Recommendations).

### 4.7 Module System / Namespace

**Current approach**: Hash-based registries. Topological module loading.

**Can this be put on a propagator network?** YES, for incremental compilation.

**How?** Each module's exports are a cell. Importing module watches exporter's cell.
When source file changes, the module cell is updated; dependent modules re-elaborate.
This is the "incremental compilation via propagators" opportunity.

**Benefits**: Only re-type-check affected modules. Currently, changing a library file
re-runs all dependent tests from scratch.

**Costs**: Significant architectural investment. Module loading is not a bottleneck today.

**Assessment**: LOW VALUE NOW, HIGH VALUE AT SCALE. Defer until compilation time
becomes a bottleneck (likely when the standard library grows 10x).

### 4.8 Test Runner / Dependency Tracking

**Current approach**: `dep-graph.rkt` defines static test -> source dependencies.
`run-affected-tests.rkt` runs affected tests in parallel via thread pool.

**Can this be put on a propagator network?** YES — and this is the **central concern**
of this audit. See Section 6 for detailed analysis.

### 4.9 Session Type Checking (Not Yet Implemented)

**Current status**: Session types are in the grammar and design docs but not yet
implemented beyond parsing.

**Should this go on a propagator network?** YES — from the start.

**How?** Session types form a lattice (subtyping gives the ordering). Protocol checking
is constraint propagation: each channel endpoint's session type must be dual to the
other. Linear resource tracking (QTT :1 multiplicity) integrates via Galois connection
to the multiplicity domain.

**Benefits**: Session type inference, protocol verification, and linear resource tracking
all compose naturally in a single network with multiple domains connected by Galois
connections.

**Assessment**: HIGH VALUE. Design session types ON the propagator network from day one.

---

<a id="5-cross-network-topology"></a>

## 5. Cross-Network Topology: What Talks to What

### Current Topology

```
Type Inference Network          Capability Inference Network
(elaborator-network.rkt)        (capability-inference.rkt)
        |                                |
        +------- Galois Connection ------+
                (cap-type-bridge.rkt)
                alpha: type -> cap-set
                gamma: cap-set -> type
```

### Proposed Expanded Topology

```
                    +--- Session Type Network ---+
                    |   (session-lattice)         |
                    |                             |
                    | Galois: session <-> type    |
                    |                             |
+--- QTT Mult ---+ |                             | +--- Abstract Interp ---+
| (mult-lattice) |-+                             +-| (interval/sign/etc)   |
|                 | |                               |                       |
| Galois:         | |   Type Inference Network      | Galois:               |
| mult <-> type   +-+-- (type-lattice)          ---+| type <-> abstract     |
|                   |                               |                       |
+-------------------+                               +-----------------------+
                    |
                    +------- Galois Connection ------+
                    |                                |
                    |   Capability Inference Network |
                    |   (cap-set-lattice)            |
                    |                                |
                    | Galois: type <-> cap-set       |
                    +--------------------------------+
                    |
                    +------- Galois Connection ------+
                    |                                |
                    |   Testing/Provenance Network   |
                    |   (provenance-semiring)        |
                    |                                |
                    | Galois: type <-> provenance    |
                    +--------------------------------+
```

### What Each Bridge Enables

| Bridge | alpha direction | gamma direction | Novel capability |
|--------|----------------|-----------------|------------------|
| Type <-> Cap | Extract cap types | Cap set -> type union | Overdeclared authority |
| Type <-> QTT | Type linearity -> mult | Mult constraint -> type | Linear type inference |
| Type <-> Session | Extract protocol | Protocol -> channel type | Session type inference |
| Type <-> Abstract | Concretize to intervals | Interval -> refinement | Static analysis |
| Type <-> Provenance | Derivation chain | (read-only) | Error explanation |

---

<a id="6-testing-infrastructure"></a>

## 6. The Testing Infrastructure Question

This is the central concern of the audit. Can our testing infrastructure benefit from
the propagator network, particularly via ATMS provenance for error diagnosis?

### 6.1 Current Testing Architecture

```
dep-graph.rkt:     Static mapping (test-file -> [source-file])
run-affected-tests.rkt:  Detect changed files -> compute affected tests -> run in parallel
benchmark-tests.rkt:     Timing collection and reporting
```

Tests are independent processes. No cross-test information flow. No explanation of
WHY a test fails beyond the Racket stack trace.

### 6.2 What Propagator-Based Testing Could Look Like

**Layer 1: Provenance-Rich Type Errors (Highest Priority)**

Currently, a type error says:
```
Type mismatch: expected String, got Int at line 42
```

With ATMS-backed type inference, the error says:
```
Type mismatch at line 42:
  x was inferred to be Int because:
    - x := 42                    [line 5, assumption A1]
    - propagated through: y = x + 1  [line 6, propagator P3]
  f expects String because:
    - spec f : String -> Bool    [line 10, assumption A7]
  Minimal conflict: {A1, A7}
  Suggestion: Change line 5 (assign a String) or line 10 (accept Int)
```

**Implementation path**: This requires the type inference migration to the elaborator
network (Phase E3). The ATMS infrastructure already exists. Wire them together.

**Layer 2: Test Dependency Propagation**

Replace `dep-graph.rkt` with a propagator network where:
- Each source file is a cell (value = content hash)
- Each test file is a cell (value = pass/fail/unknown)
- Propagators encode dependencies: when source cell changes, dependent test cells
  are invalidated (set to `unknown`)
- `run-to-quiescence` identifies exactly which tests need re-running

**Benefits over current approach**:
- Dynamic dependency tracking (no manual `dep-graph.rkt` maintenance)
- Transitive invalidation (A depends on B depends on C; changing C invalidates A)
- Incremental: only compute the affected set, don't re-scan everything

**Layer 3: Failure Explanation via ATMS**

When a test fails, the ATMS dependency chain identifies:
- Which specific type/constraint assumptions led to the failure
- Which source file change introduced the breaking assumption
- Minimal set of changes needed to fix (minimal nogood)

This is the **General Diagnostic Engine (GDE)** applied to programming:
- The "system model" is the type/constraint network
- The "observations" are test assertions
- The "diagnosis" is the minimal set of assumptions to retract

**Layer 4: Property-Based Test Shrinking via Nogoods**

For property-based tests, a failing input is a set of constraints that leads to
contradiction. The ATMS's nogood recording identifies the MINIMAL failing subset:
- Full input: `{x: 100, y: [1,2,3], z: "hello"}`
- Nogood: `{x: 100}` (only x matters)
- Shrunk counterexample: `{x: 100}` (automatically minimal)

This is more principled than QuickCheck/Hypothesis's type-based shrinking because
it uses the constraint structure rather than domain-specific shrinkers.

### 6.3 Assessment

| Layer | Value | Effort | Dependency |
|-------|-------|--------|------------|
| 1: Provenance errors | **VERY HIGH** | Medium | Phase E3 (type inference migration) |
| 2: Dep propagation | Medium | Low | Independent |
| 3: Failure explanation | **HIGH** | Medium | Layer 1 |
| 4: Property shrinking | Medium | High | Layer 1 + property testing framework |

**Recommendation**: Layer 1 (provenance-rich errors) is the killer feature. It requires
the type inference migration (Phase E3) but produces dramatically better error messages.
Prioritize this.

---

<a id="7-dependent-types-unification"></a>

## 7. The Dependent Types / Unification Question

### 7.1 What Still Uses the Old Unify Infrastructure?

**Everything in the core type checker**. The old infrastructure is:

| Component | File | Mechanism |
|-----------|------|-----------|
| `unify` | `unify.rkt` | Imperative `solve-meta!` mutation |
| `metavar-store` | `metavar-store.rkt` | Mutable hash of meta solutions |
| `save-meta-state` / `restore-meta-state!` | `metavar-store.rkt` | O(n) deep copy for speculation |
| `constraint` | `typing-core.rkt` | Deferred constraint structs |
| `resolve-trait-constraints!` | `trait-resolution.rkt` | Post-inference pass |
| `check-unresolved` | `typing-core.rkt` | Leftover meta detection |
| `zonk` | `zonk.rkt` | Walk tree replacing metas with solutions |

### 7.2 What Has Been Partially Migrated?

Phase E1-E2 of the elaborator refactoring created a hybrid:

- **Phase E1**: `try-unify-pure` — pure unification that follows solved metas via
  read-only callback (no mutation). Used by type lattice merge.
- **Phase E2**: `solve-meta!` now runs `run-to-quiescence` after cell writes for
  transitive propagation. The old infrastructure triggers propagator-style wakeup.
- **Phase C**: Incremental trait resolution via wakeup callbacks.

The current system is a **hybrid**: the old imperative metavar store is wrapped with
propagator-network-style wakeup behavior, but the core data structures are still
mutable hashes.

### 7.3 What Would Full Migration Look Like?

Replace `metavar-store.rkt` entirely with `elaborator-network.rkt`:

```
Before:                              After:
fresh-meta! -> new hash entry        elab-fresh-meta -> new cell (type-bot)
solve-meta!(id, val) -> hash-set!    net-cell-write(id, val) -> lattice join
lookup-meta(id) -> hash-ref          net-cell-read(id)
save-meta-state -> deep copy O(n)    keep old network O(1)
restore-meta-state! -> hash-set! O(n) use old network O(1)
```

**Dependent type interactions**: Dependent types require reduction during unification
(to check definitional equality: `conv(nf(t1), nf(t2))`). This doesn't change with
the propagator migration — `type-lattice-merge` already calls `conv` internally.
The dependent type infrastructure is orthogonal to the store mechanism.

### 7.4 Performance Implications

| Operation | Current (mutable hash) | Propagator (CHAMP) | Notes |
|-----------|----------------------|---------------------|-------|
| Fresh meta | O(1) amortized | O(log n) | Slightly slower |
| Solve meta | O(1) | O(log n) | Slightly slower |
| Lookup meta | O(1) | O(log n) | Slightly slower |
| **Backtrack** | **O(n) deep copy** | **O(1) keep ref** | **Major win** |
| **Speculation** | **O(n) save + O(n) restore** | **O(1) + O(1)** | **Major win** |

The O(1) backtracking is the key benefit. Speculative type checking (Church folds,
union type attempts) currently pays O(n) per attempt. With the propagator approach,
speculation is free. For programs with many speculative attempts (e.g., heavily
overloaded functions), this could be a significant speedup.

### 7.5 Assessment

The dependent type infrastructure (Pi types, substitution, reduction, conversion checking)
is fine as-is. It's the **storage mechanism** (metavar-store) that benefits from migration.
The dependent type features work on top of whichever store is used.

**Recommendation**: Migrate metavar-store to elaborator-network (Phase E3). This is the
single most impactful change for both performance (O(1) backtracking) and diagnostics
(ATMS provenance).

---

<a id="8-recommendations"></a>

## 8. Recommendations

### Tier 1: High Value, Infrastructure Ready

**8.1 Type Inference on Propagator Network (Phase E3)**
- Replace `metavar-store.rkt` with `elaborator-network.rkt`
- O(1) backtracking, ATMS provenance, parallel unification
- Infrastructure exists; effort is refactoring, not invention
- Unlocks: provenance-rich error messages (Section 6 Layer 1)

**8.2 Session Types on Propagator Network (from day one)**
- When implementing session types, use the propagator network as the inference engine
- Session type lattice + QTT multiplicity lattice + type lattice = single network
- Cross-domain Galois connections for linear resource tracking
- Avoids building session type infrastructure that later needs migration

### Tier 2: Medium Value, Design Work Needed

**8.3 Trait Resolution as Propagators**
- Trait constraints become propagator cells
- Auto-wakeup when type variables are solved
- Natural integration with type inference network
- Migrate as part of Phase E3, not independently

**8.4 Test Dependency as Propagator Network**
- Replace static `dep-graph.rkt` with dynamic dependency propagation
- Transitive invalidation, incremental affected-test computation
- Low effort, moderate payoff

**8.5 Abstract Interpretation Framework**
- Use existing `Lattice` + `GaloisConnection` + `Widenable` traits
- Each analysis domain = new lattice instance
- Cross-domain propagators compose analyses automatically
- Value increases as the language matures and needs static analysis

### Tier 3: Future Considerations

**8.6 Constraint Solving (FD/Reals)**
- `FiniteDomain A` lattice for Sudoku-style CSPs
- `IntervalLattice` already exists for real constraints
- ATMS search replaces traditional backtracking
- More relevant for the relational language than the functional core

**8.7 Incremental Compilation**
- Module exports as propagator cells
- Source changes trigger selective re-elaboration
- High value at scale, low value today
- Defer until compilation time is a bottleneck

**8.8 Distributed / Multi-Agent Propagation**
- Persistent network cells are CRDTs by construction
- Distributed type checking for multi-module projects
- Multi-agent reasoning for collaborative verification
- Far future; requires distributed runtime infrastructure

---

<a id="9-priority-matrix"></a>

## 9. Priority Matrix

| Subsystem | On LE? | Should Migrate? | Value | Effort | Priority |
|-----------|--------|-----------------|-------|--------|----------|
| Capability inference | YES | — | — | — | DONE |
| Cap <-> Type bridge | YES | — | — | — | DONE |
| ATMS provenance | YES | — | — | — | DONE |
| Tabling | YES | — | — | — | DONE |
| Union-find | YES | — | — | — | DONE |
| **Type inference** | NO | **YES** | **Very High** | **Medium** | **1** |
| **Unification** | NO | **YES** | **Very High** | **Medium** | **1** (same as above) |
| **Session types** | N/A | **YES (day one)** | **High** | **Low** (design choice) | **2** |
| Trait resolution | NO | YES | Medium | Low | 3 (with E3) |
| Test dependencies | NO | Maybe | Medium | Low | 4 |
| QTT multiplicities | NO | Maybe | Low-Medium | Medium | 5 (with E3) |
| Abstract interp | N/A | YES (future) | High (future) | Medium | 6 |
| Module system | NO | Future | High (at scale) | High | 7 |
| Schema validation | NO | No | Low | — | — |
| Reduction engine | NO | No | None | — | — |

---

## Appendix: Files Referenced

| File | Lines | Role |
|------|-------|------|
| `propagator.rkt` | ~763 | Core propagator network |
| `elaborator-network.rkt` | ~241 | Type inference bridge (ready) |
| `type-lattice.rkt` | ~300 | Type domain lattice |
| `capability-inference.rkt` | ~800 | Capability propagation |
| `cap-type-bridge.rkt` | ~600 | Galois connection bridge |
| `atms.rkt` | ~500 | Assumption-based TMS |
| `union-find.rkt` | ~200 | Persistent disjoint sets |
| `tabling.rkt` | ~200 | SLG memoization |
| `unify.rkt` | ~600 | Imperative unification |
| `metavar-store.rkt` | ~250 | Mutable metavar store |
| `typing-core.rkt` | ~3000 | Core type checker |
| `qtt.rkt` | ~800 | Multiplicity checking |
| `trait-resolution.rkt` | ~1000 | Trait instance search |
| `reduction.rkt` | ~1000 | Term reduction |
| `macros.rkt` | ~7000 | Preparse + schema validation |
| `namespace.rkt` | ~400 | Module system |
| `driver.rkt` | ~800 | Top-level orchestration |
| `tools/run-affected-tests.rkt` | ~300 | Test runner |
| `tools/dep-graph.rkt` | ~200 | Test dependency graph |
