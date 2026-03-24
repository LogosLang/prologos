# PUnify Part 3: The Multiverse Multiplexer — ATMS-World Solver on Propagators

**Created**: 2026-03-19
**Revised**: 2026-03-20 (deep overhaul — grounded in Logic Engine Design, Track 7 taxonomy, narrowing design)
**Status**: Design (pre-implementation)
**Parent**: Track 8 — Propagator Infrastructure Migration

**Lineage**:
- **Logic Engine Design** (`2026-02-24_LOGIC_ENGINE_DESIGN.org`): Phases 4-7 — the comprehensive blueprint. This document IS those phases realized on Track 7/8 infrastructure.
- **Part 1**: `2026-03-19_PUNIFY_STRUCTURAL_UNIFICATION_PROPAGATORS.org` (surface wiring + baselines)
- **Part 2**: `2026-03-19_PUNIFY_PART2_CELL_TREE_ARCHITECTURE.md` (cell-tree unification substrate)
- **Track 7**: `2026-03-18_TRACK7_PERSISTENT_CELLS_STRATIFIED_RETRACTION.md` (propagator taxonomy, stratified architecture)
- **Narrowing Design**: `2026-03-07_FL_NARROWING_DESIGN.org` (definitional trees, residuation-first, term lattice)
- **Vision**: `RELATIONAL_LANGUAGE_VISION.org` (three-layer model, solver language)
- **Audit**: `2026-03-18_TRACK8_PROPAGATOR_INFRASTRUCTURE_AUDIT.org` (allocation efficiency concerns)
- **Solver config**: `solver.rkt` (existing `solver-config` with all knobs already designed)

---

## 1. Purpose: The Logic Engine, Realized

PUnify Part 3 completes the logic engine that was designed in the Logic Engine Design document (Phases 4-7) and partially implemented (Phases 1-3). Where Phases 1-3 built the algebraic and network foundations — lattice traits, persistent PropNetwork, BSP parallel execution, PropNetwork as Prologos type — Part 3 builds the **search and reasoning layer**: ATMS-world exploration, tabling, and the integration of all three layers into a unified solver.

This is not merely replacing DFS backtracking with ATMS. It is the realization of the full propagator-first vision for logic programming: **clauses as assumptions, goals as propagators, conjunction as worklist scheduling, backtracking as nogood accumulation, tabling as cell quiescence, and parallel worldview exploration via BSP** — all composed from the building blocks Track 7 established.

### 1.1 What This Document Covers

| Logic Engine Phase | What | Status Before Part 3 | Part 3 Delivers |
|---|---|---|---|
| Phase 4 | UnionFind (persistent disjoint sets) | NOT STARTED | UF + PropNetwork dual for solver state |
| Phase 5 | Persistent ATMS (hypothetical reasoning) | IMPLEMENTED (`atms.rkt`) | Solver integration: clause-as-assumption, N-ary speculation, worldview enumeration |
| Phase 6 | Tabling (SLG memoization) | NOT STARTED | Table registry, producer/consumer propagators, completion detection |
| Phase 7 | Surface Syntax (solver language) | PARTIALLY IMPLEMENTED | Connect `solver-config` knobs to ATMS/tabling/BSP engine |

### 1.2 What Changes

- DFS backtracking (`solve-goals` at `relations.rkt:600` threading substitutions through recursive `append-map`) becomes ATMS-world exploration
- Sequential clause iteration (`solve-app-goal` at `relations.rkt:825`) becomes `atms-amb` over clause assumptions
- Explicit substitution threading (`hasheq` passed through every call) becomes implicit propagation through cell-trees + UF
- `DEFAULT-DEPTH-LIMIT` (100) as termination guard becomes tabling + ATMS nogood pruning
- The `solver-config` knobs (`:strategy`, `:execution`, `:threshold`, `:tabling`) become operational — currently they exist but the engine ignores most of them

### 1.3 What Doesn't Change

- Cell-tree unification substrate (Part 2)
- Constructor descriptor registry (Part 2)
- User-facing `solve`/`defr`/`explain` syntax
- Relation registration and clause storage
- `is` goal evaluation, guard predicates, mode annotations
- The `solver-config` struct and its key set (already complete in `solver.rkt`)

### 1.4 Success Criteria

- Solve-adversarial benchmark (14.3s baseline) does not regress >15%
- Left-recursive `defr` relations terminate (tabling)
- All acceptance file solver sections pass at Level 3
- `solve` returns all solutions; `solve-one` returns first
- `:strategy :auto` starts in Tier 1 (PropNetwork only), upgrades on first `amb`
- `:strategy :depth-first` preserves exact DFS semantics for backward compatibility
- `:execution :parallel` enables BSP worldview exploration above `:threshold`

---

## 2. Current Architecture: DFS Search

### 2.1 The DFS Loop

The current solver (`relations.rkt:600-893`) is a clean, ~300-line DFS implementation:

```
solve-goals(goals, subst):                    ;; relations.rkt:600
  if null(goals): [subst]                      ;; base case: all goals satisfied
  append-map over solve-single-goal(first, subst):
    (λ s → solve-goals(rest, s))               ;; thread substitution through

solve-single-goal(goal, subst):                ;; relations.rkt:612
  dispatch on kind:
    app   → solve-app-goal(rel, args, subst)
    unify → unify-terms(lhs, rhs, subst) → [subst'] | []
    is    → evaluate + unify result
    not   → NAF: if solve fails → [subst], else []
    guard → evaluate predicate

solve-app-goal(rel, args, subst):              ;; relations.rkt:825
  for each variant:
    for each clause:
      fresh-vars = α-rename(clause)
      subst' = unify-terms(args, fresh-params, subst)
      if subst': solve-goals(clause-body, subst')
  append all results                            ;; ALL solutions, not first-only
```

### 2.2 What DFS Gets Right

- **Simple**: ~300 lines for the complete solver
- **Predictable**: Clause ordering = exploration order. Matches Prolog semantics.
- **Low overhead**: No infrastructure cost beyond the substitution `hasheq`
- **All-solutions**: Already returns `(listof hasheq)`, not just first

### 2.3 What DFS Gets Wrong

**No termination guarantee.** Left-recursive relations diverge — `DEFAULT-DEPTH-LIMIT` (100) is a crude guard that produces an error, not a graceful result.

**Redundant computation.** Shared subgoals across clauses are re-solved from scratch. If 10 clauses all need `(type ?x)`, that subgoal is evaluated 10 times.

**No constraint interaction across branches.** Unification in one clause can't inform another clause. Each clause starts from the parent substitution independently.

**Sequential-only.** Each clause is tried one at a time via `append-map`. No opportunity for concurrent exploration or early cross-branch pruning.

**Backtracking destroys information.** When a clause fails, the attempted substitution extensions are lost. There's no record of *why* it failed — no dependency tracking, no learned clauses. The same failed combination may be re-explored in a different context.

---

## 3. The Solver Language: What's Already Designed

The Logic Engine Design (Phase 7) and `solver.rkt` already define the complete solver configuration language. Part 3's job is to make these knobs operational, not to reinvent them.

### 3.1 The `solver-config` (Already Implemented)

`solver.rkt:58-88` defines the configuration struct and defaults:

| Key | Values | Default | Semantics |
|---|---|---|---|
| `:execution` | `:parallel`, `:sequential` | `:parallel` | BSP (Jacobi) vs Gauss-Seidel |
| `:threshold` | Nat | `4` | Parallelize when ≥N runnable propagators |
| `:strategy` | `:auto`, `:depth-first`, `:atms` | `:auto` | Two-tier activation (see §3.2) |
| `:tabling` | `:by-default`, `:off` | `:by-default` | All defr predicates tabled unless `:tabled false` |
| `:provenance` | `:none`, `:summary`, `:full`, `:atms` | `:none` | Provenance tracking level |
| `:timeout` | Nat (ms) or `#f` | `#f` | Query timeout |
| `:semantics` | `:stratified`, `:well-founded` | `:stratified` | WFS vs stratified negation |
| `:narrow-search` | `:all`, `:first` | `:all` | Narrowing answer mode |
| `:narrow-value-order` | `:source-order`, `:smallest-domain` | `:source-order` | Variable ordering heuristic |
| `:max-derivation-depth` | Nat | `50` | Explain derivation tree depth |

### 3.2 Two-Tier ATMS Activation (Logic Engine §5.5)

The key insight from the Logic Engine Design: ATMS adds overhead for every cell operation (label management, support tracking, consistency checks). For *deterministic* queries (no `amb`, no choice points), this overhead is pure waste.

**Tier 1 — PropNetwork Only (default)**: No ATMS. Just a `prop-network` with pure propagation. Cells hold simple values, not supported values. `run-to-quiescence` operates directly. This is sufficient for Datalog evaluation, deterministic constraint propagation, and simple tabled predicates.

**Tier 2 — Full ATMS (activated on first `amb`)**: When the solver encounters its first choice point (multiple clauses match), it upgrades to full ATMS by wrapping the current network in an `atms` struct. From that point, all cell values become supported values (tagged with assumption sets). Nogoods, worldview switching, and DDB become available.

This is what `:strategy :auto` does — and it's the default. `:strategy :depth-first` stays in Tier 1 forever (no ATMS, chronological backtracking via DFS). `:strategy :atms` starts in Tier 2 immediately.

### 3.3 Pre-Defined Solver Configurations (Logic Engine §7.6.2)

```prologos
solver default-solver
  :execution   :parallel       ;; BSP parallel
  :threshold   4               ;; parallelize when ≥4 runnable propagators
  :strategy    :auto           ;; Tier 1 → Tier 2 on first amb
  :tabling     :by-default     ;; all defr tabled unless :tabled false
  :provenance  :none
  :timeout     :none

solver sequential-solver
  :execution   :sequential
  :strategy    :auto
  :tabling     :by-default

solver debug-solver
  :execution   :sequential
  :strategy    :auto
  :provenance  :full           ;; derivation trees always
  :timeout     10000

solver depth-first-solver
  :execution   :sequential
  :strategy    :depth-first    ;; no ATMS, chronological backtracking
  :tabling     :off            ;; user opts in with :tabled true
```

### 3.4 No `cut`

`cut` exists in Prolog to control chronological backtracking — it's a hack to prune the search tree that DFS would otherwise explore. With ATMS-based exploration:

- **Dependency-directed backtracking** via nogoods already prunes exactly the right branches. You don't need to manually control what gets explored.
- **Deterministic clause commitment** is the structural property of having a single-clause match (no `amb` created).
- **Prolog-compatible semantics** are provided by `:strategy :depth-first`, which preserves clause ordering + first-solution behavior without ATMS.

Part 3 does NOT implement `cut`. The `goal-desc` kind `'cut` in the current solver can be deprecated or mapped to a no-op warning.

---

## 4. Existing Infrastructure: What's Built

### 4.1 ATMS Data Structure (`atms.rkt`)

A **persistent, immutable ATMS** backed by CHAMP maps. All operations pure.

| Operation | What | Returns |
|---|---|---|
| `atms-assume` | Create new assumption | `(values atms* assumption-id)` |
| `atms-retract` | Remove from believed set | `atms*` |
| `atms-add-nogood` | Record inconsistent set | `atms*` |
| `atms-consistent?` | Check set vs all nogoods | `boolean` |
| `atms-amb` | N mutually exclusive assumptions + pairwise nogoods | `(values atms* hyp-list)` |
| `atms-write-cell` | Write under current worldview | `atms*` |
| `atms-read-cell` | Read filtering by worldview | `value` |
| `atms-with-worldview` | Switch believed set | `atms*` (O(1) struct-copy) |
| `atms-solve-all` | Cartesian product over amb-groups + consistency filter | `(listof value)` |

### 4.2 TMS Cell Infrastructure (`propagator.rkt`)

- `tms-cell-value` wraps values with branch metadata (CHAMP tree)
- `current-speculation-stack` — stack of assumption-ids
- `net-cell-write` routes to TMS branches when under speculation
- `net-cell-read` unwraps through TMS branches using worldview
- `net-commit-assumption` / `net-retract-assumption` — promote/remove

### 4.3 Speculation Framework (`elab-speculation-bridge.rkt`)

`with-speculative-rollback` already implements the ATMS pattern for type checking (Church fold attempts, union types). **The pattern is identical** to solver clause exploration — the only difference is arity: type speculation is binary (one branch at a time), solver exploration is N-ary. Extension to N-ary is the straightforward generalization.

The existing learned-clause pruning (check if proposed assumption set subsumes any known nogood before running a branch) carries over directly.

### 4.4 Stratified Resolution (Track 7)

Track 7 delivered the complete stratified architecture:

```
S(-1): Retraction — clean scoped cells of non-believed entries
  ↓
S0:    Type propagation — monotone cell writes, unification propagators
  ↓
L1:    Readiness detection — fan-in propagators, countdown latch, ready-queue
  ↓
L2:    Resolution commitment — consume from ready-queue, commit resolution actions
  ↓
Feedback: if L2 wrote to S0 cells, restart from S(-1)
```

### 4.5 Well-Founded NAF (`wf-engine.rkt`, `bilattice.rkt`)

The WF engine provides a 3-valued NAF oracle (succeed/fail/defer) using bilattice-based tracking and SCC-based stratification analysis (`preds-with-negation`). `current-naf-oracle` parameter already used in `solve-single-goal` (relations.rkt:651-666).

### 4.6 Solver Config (`solver.rkt`)

Fully implemented: `solver-config` struct, all knobs, accessors, merge function, validation. Used by `solve-goal` and `explain-goal` in `relations.rkt`.

### 4.7 What Needs to Be Built

| Component | Status | Source | What's Missing |
|---|---|---|---|
| ATMS data structure | ✅ | `atms.rkt` | — |
| TMS-branched cells | ✅ | `propagator.rkt` | — |
| Speculation framework | ✅ | `elab-speculation-bridge.rkt` | N-ary extension |
| Worldview enumeration | ✅ | `atms-solve-all` | Bridge to logic var cells |
| WF NAF oracle | ✅ | `wf-engine.rkt` | Multi-world context |
| Solver config | ✅ | `solver.rkt` | Operational wiring to engine |
| BSP parallel scheduler | ✅ | `propagator.rkt` | Worldview-level parallelism |
| Cell-tree unification | 🔄 | Part 2 | Solver-side cell-trees |
| UnionFind | ❌ | Logic Engine §4 | Persistent disjoint sets |
| Clause-as-assumption | ❌ | — | `atms-amb` orchestration |
| Goal-as-propagator | ❌ | — | Propagator dispatch per goal type |
| Tabling | ❌ | Logic Engine §6 | Table registry, producer/consumer, completion |
| NAF + ATMS worlds | ❌ | — | Worldview-aware WF oracle |
| Solution enumeration bridge | ❌ | — | ATMS worldviews → binding maps |

---

## 5. Propagator Taxonomy: Compositional Building Blocks

Track 7 (§2.6) established a propagator taxonomy. Every Part 3 component is composed from these patterns. This section maps the taxonomy to solver components — the "categorical composition" across architectural building blocks.

### 5.1 Structural Patterns

| Track 7 Pattern | Part 3 Component | How It's Used |
|---|---|---|
| **Transform** (1→1) | Unify-goal propagator | Cell-tree decomposition: parent cell → child cells via descriptor |
| **Fan-in** (N→1) | Conjunction readiness | N subgoal cells → conjunction-satisfied cell. Countdown latch: conjunction fires when all subgoals have values. O(1) per subgoal completion. |
| **Fan-out** (1→N) | **The Multiverse Multiplexer** | One decision point (which clause?) fans out into N ATMS worlds. `atms-amb` creates N assumptions; each world gets its own propagator installation under its assumption. |
| **Bridge** (net A → net B) | Solver↔Elab bridge | Solver network is isolated per `solve` invocation. Results bridge back to elaboration context via cell reads after quiescence. |

### 5.2 Lifecycle Patterns

| Track 7 Pattern | Part 3 Component | How It's Used |
|---|---|---|
| **Value cell** (monotone merge) | Logic variable cells | Solver variables are cells with `FlatLattice` merge (or term lattice merge). Unification writes refine them monotonically. |
| **Accumulator cell** (set-union merge) | **Table answer cells** | Each tabled predicate has an accumulator cell with `SetLattice` merge. Producer propagators write answers; the set only grows. Completion = quiescence. |
| **Channel cell** (produce-consume) | Ready-queue for solver constraints | When a solver constraint (e.g., numeric domain narrowing) becomes ready, its L1 readiness propagator writes an action descriptor to the channel cell. L2 consumes it. |
| **Shadow cell** (mirror from source) | Fact cells | Ground facts from `defr` fact blocks (`||`) are written once to persistent cells. Solver reads them via shadow cells in the per-query network. |

### 5.3 Scheduling Patterns

| Track 7 Pattern | Part 3 Component | How It's Used |
|---|---|---|
| **Stratum propagator** (tagged S-level) | All solver propagators are S0 (monotone). NAF is L1 (fires after S0 quiesces). Resolution commitment is L2. |
| **Threshold propagator** (cross-layer gate) | Tabling completion gate: fire only after lower stratum quiesces and no new table answers appeared. |

### 5.4 The Assumption Taxonomy (Extended)

Track 7 identified two assumption kinds (speculation + lifecycle). Part 3 adds a third:

| Kind | Created by | Retracted by | Tags | Purpose |
|---|---|---|---|---|
| **Speculation** | `with-speculative-rollback` | Rollback on failure | Value cells (TMS) | Type-checking speculation |
| **Lifecycle** | L1 readiness propagator | L2 after consumption | Channel cell entries | Ready-queue produce/consume |
| **Clause** (NEW) | `atms-amb` in solver | Never retracted — survives as nogood | All solver cells under that world | Clause exploration world |

Clause assumptions are fundamentally different from speculation assumptions: they are **persistent** (never individually retracted) and **mutually exclusive** (pairwise nogoods from `atms-amb`). Failed clause worlds are pruned by nogood accumulation, not by assumption retraction. This is the key shift from chronological backtracking to dependency-directed backtracking.

### 5.5 Categorical Composition: Lattices, Functors, and Strata

The architecture composes along three axes:

**Axis 1: Lattice domains connected by Galois connections (bridge propagators).**

| Source Lattice | Target Lattice | Connection | Direction |
|---|---|---|---|
| Type lattice (elaboration) | Term lattice (solver) | Type constrains term domain: if `?x : Int`, solver cell for `?x` can only hold Int constructors | Type → Term (monotone restriction) |
| Term lattice (solver) | UnionFind (structural equality) | UF handles var-var bindings (`?x = ?y`); term lattice handles var-value bindings | Bidirectional: UF find → cell read; cell write → UF update |
| Interval lattice (narrowing) | Term lattice (solver) | Numeric narrowing constrains which concrete values a solver variable can take | Interval → Term (domain restriction) |

Each connection is a **bridge propagator**: a propagator that reads from one lattice domain's cell and writes to another's, maintaining the monotone abstraction/concretization maps. This is the Galois connection realized as a propagator — the lower adjoint maps concrete values up; the upper adjoint maps abstract constraints down.

**Axis 2: Strata as a tower of fixpoint computations (Knaster-Tarski, composed).**

```
S(-1):  Retraction fixpoint     (assumption set ↓, finite)
  ↓     Galois connection: retracted assumptions → cleaned cells
S0:     Propagation fixpoint    (cell values ↑, finite lattice height)
  ↓     Observation: quiescent S0 state
L1:     Readiness fixpoint      (ready-queue ↑, finite constraints)
  ↓     Observation: ready actions
L2:     Resolution fixpoint     (resolved constraints ↓, finite)
  ↓     Feedback: new S0 cell writes
```

Each stratum reaches its own Knaster-Tarski fixpoint before the next observes it. The strata compose as a **chain of adjunctions**: each lower stratum's fixpoint is the input to the upper stratum's computation. Feedback (L2 → S0) creates an outer fixpoint loop, but each inner stratum is independently monotone and convergent.

**Axis 3: The ATMS as a fiber bundle over the base propagator network.**

The base network holds unconditional facts (empty support set = believed in all worlds). Each ATMS worldview is a **fiber** over this base — a projection that includes the base facts plus the assumptions specific to that world. The `atms-with-worldview` operation selects a fiber. `atms-read-cell` reads from the selected fiber.

This is a fiber bundle structure:
- **Base space**: The prop-network with all unconditional cell values
- **Fiber at assumption A**: The restriction of cell values to worldview {A} ∪ base
- **Projection**: `atms-with-worldview` → read cells → extract bindings
- **Section**: A consistent worldview (one choice per amb-group) that survives nogood filtering

Learnings (nogoods) ARE shared across fibers — a contradiction discovered in one world prunes that assumption combination from ALL worlds. Only assumption-dependent facts are fiber-local. This is strictly better than chronological backtracking, which shares nothing.

---

## 6. The Multiverse Multiplexer: ATMS-World Exploration

### 6.1 Core Model: Clauses as Assumptions

When `solve-app-goal` encounters a relation with N clauses (currently `relations.rkt:825-893`), the ATMS solver replaces the `append-map` over clauses with `atms-amb`:

```
solve-app-goal(rel, arg-cells, solver-state):
  clauses = lookup-relation(rel)
  if |clauses| = 1:
    ;; Deterministic: no amb needed (Tier 1 fast path)
    install-clause-propagators(clauses[0], arg-cells, solver-state)
  else if |clauses| = 0:
    ;; No clauses: contradiction
    record-contradiction(solver-state)
  else:
    ;; The Multiverse Multiplexer: fan-out over N clause worlds
    (atms*, clause-hyps) = atms-amb(solver-state.atms, clause-labels)
    for each (clause, hyp) in zip(clauses, clause-hyps):
      under hyp:
        fresh-cells = create-fresh-logic-var-cells(clause.params)
        ;; Unify goal args with clause params (Part 2 cell-tree)
        for each (arg, param) in zip(arg-cells, fresh-cells):
          add-unify-propagator(arg, param)
        ;; Schedule body goals as propagators
        for each sub-goal in clause.body:
          install-goal-propagator(sub-goal, clause-var-cells)
    run-to-layered-quiescence()
```

The **single-clause fast path** is critical for performance: most `defr` relations have one or two clauses for a given arity. When there's only one matching clause, no ATMS overhead is incurred. This is the Tier 1 → Tier 2 upgrade at the granularity of individual relation calls, not just the entire query.

### 6.2 `atms-amb` as Fan-Out

`atms-amb` (atms.rkt:196-216) creates N assumptions with pairwise mutual-exclusion nogoods. Each assumption represents the hypothesis "this clause is the one that matches." The pairwise nogoods ensure that at most one clause is believed in any consistent worldview.

What `atms-amb` produces:
- N new assumption-ids (h₁, h₂, ..., hₙ)
- N×(N-1)/2 pairwise nogoods: {hᵢ, hⱼ} for all i≠j
- All hᵢ initially believed (all worlds alive)

What quiescence + nogood accumulation produces:
- Some worlds contradicted → their assumption sets recorded as nogoods
- Surviving worlds = consistent assumption sets = solutions
- Answer collection via `atms-solve-all` (Cartesian product over amb-groups + consistency filter)

### 6.3 Goal Ordering: Data-Driven, Not Syntactic

Current DFS folds goals left-to-right (`solve-goals` at relations.rkt:600-609). The ATMS solver schedules goals as propagators — they fire when their watched cells have information, regardless of textual position.

**Default**: Left-to-right scheduling within a conjunction (emulate DFS ordering). Each goal propagator has a priority derived from its position in the clause body. When multiple goals are ready, lower-position goals fire first. This preserves Prolog-compatible semantics.

**Opt-in**: Data-driven ordering. When `:narrow-value-order :smallest-domain` is set in the solver config, the scheduler prioritizes goals whose input cells have the most information (most constrained variable heuristic). This is the standard constraint-propagation optimization.

### 6.4 Residuation-First (from Narrowing Design)

The FL Narrowing Design (§6.2, D1) established a principle that applies equally to the solver: **residuate by default, narrow/search on demand**.

In propagator terms: a goal propagator whose input cell is ⊥ (no information) **doesn't fire**. This IS residuation — the propagator suspends until information arrives from another source. Only when the search phase (ATMS amb creation) explicitly instantiates a variable does the propagator wake up.

This principle means:
- Deterministic goals (all inputs known) fire immediately → no search overhead
- Under-constrained goals suspend → no premature choice points
- Choice points are created only when the search heuristic decides they're needed
- The propagator network naturally implements the "demand-driven" evaluation strategy from Antoy's needed narrowing

---

## 7. The Solver State: UF + PropNetwork Dual

### 7.1 Complementary Data Structures (Logic Engine §4.4)

The Logic Engine Design identified that union-find and propagator cells serve **complementary** roles:

| Operation | Uses UF | Uses PropNetwork Cell |
|---|---|---|
| `?x = ?y` (var-var) | `uf-union x y` | — |
| `?x = 42` (var-value) | `uf-find x` → set value | — |
| `?x = f(?y, ?z)` (complex) | `uf-union` + subterm cells | Cell per subterm for propagation |
| Lattice-valued accumulation | — | `net-cell-write` with join |
| Table answer sets | — | Cell with `SetLattice` merge |
| Numeric constraints | — | Cell with `IntervalLattice` |
| Backtracking | Keep old `uf-store` | Keep old `prop-network` |

**UnionFind**: structural equality — discovering that two variables must refer to the same term. Fast path for standard Prolog-style unification. O(log n) find-with-path-splitting.

**PropNetwork cells**: lattice-valued accumulation — aggregating information that can only grow (sets of answers, numeric intervals, constraint domains). The general path for constraint propagation.

### 7.2 The Solver State Tuple

```racket
(struct solver-state
  (kind        ;; 'tier-1 | 'tier-2
   uf-store    ;; persistent union-find (variable bindings)
   network     ;; prop-network (constraint cells, table cells, logic var cells)
   atms        ;; #f (Tier 1) | atms struct (Tier 2)
   table-store ;; table-store (tabling registry — maps goal patterns to cell-ids)
   config)     ;; solver-config
  #:transparent)
```

Both `uf-store` and `network` are persistent/immutable. Both support O(1) backtracking (keep old reference). The solver threads this tuple through computation.

### 7.3 Tier Upgrade (Logic Engine §5.5)

```racket
(define (solver-upgrade-to-tier-2 state)
  (if (eq? (solver-state-kind state) 'tier-2)
      state  ;; already upgraded
      (struct-copy solver-state state
        [kind 'tier-2]
        [atms (atms-from-network (solver-state-network state))])))

;; atms-from-network: wraps existing network, converting all cell values
;; to unconditionally supported values (support = ∅ = always true)
```

This upgrade happens automatically on the first `atms-amb` call (when the solver encounters a multi-clause relation). The `:strategy :auto` config controls this. `:strategy :depth-first` never upgrades.

---

## 8. Goal-as-Propagator Framework

### 8.1 Goal Propagator Dispatch

Each goal type maps to a propagator pattern:

| Goal Type | Propagator Pattern | Watched Cells | Output | Stratum |
|---|---|---|---|---|
| **App-goal** | Recursive solve (nested multiverse) | arg-cells | New propagators + cells | S0 |
| **Unify-goal** | Part 2 cell-tree unification | lhs-cell, rhs-cell | Sub-cell propagators | S0 |
| **Is-goal** | Transform propagator (evaluate + bind) | expr var-cells | var-cell write | S0 |
| **Not-goal** | NAF oracle consultation | sub-goal completion cell | succeed/fail | L1 (stratified) |
| **Guard-goal** | Threshold propagator (predicate gate) | guard input cells | pass/fail | S0 |

### 8.2 App-Goal: Recursive Multiverse

The app-goal propagator is the recursive case — it calls `solve-app-goal` to create a nested multiverse for the sub-relation. This is where tabling becomes critical: without tabling, recursive app-goals create unbounded nesting. With tabling, the second call to the same relation pattern becomes a table consumer (watching the table cell) instead of a recursive producer.

### 8.3 Is-Goal: Transform Propagator

```racket
is-goal-propagator(var-cell, expr, var-cells):
  watched: var-cells used in expr
  fire(net):
    vals = [net-cell-read(net, vc) for vc in watched]
    if all vals ≠ ⊥:
      result = evaluate(expr, vals)      ;; uses current-is-eval-fn
      net-cell-write(net, var-cell, result)
    else:
      net                                 ;; residuate: wait for inputs
```

This is a standard **transform propagator** (1→1 in Track 7 taxonomy). Note the residuation: if any input is ⊥, the propagator returns the network unchanged (doesn't fire).

### 8.4 Not-Goal: Stratified NAF

```racket
not-goal-propagator(sub-goal):
  stratum: L1                              ;; fires only after S0 quiesces
  fire(net):
    ;; Option 1: Use WF NAF oracle (if available)
    oracle = current-naf-oracle
    if oracle:
      result = oracle(sub-goal-predicate)
      case result:
        'succeed → write success to not-goal cell
        'fail    → write failure
        'defer   → residuate (3-valued: unknown)
    ;; Option 2: ATMS worldview check
    else if tier-2:
      if no consistent world for sub-goal: succeed
      else: fail
    ;; Option 3: DFS fallback (depth-first strategy)
    else:
      solve sub-goal; succeed if no solutions
```

The WF engine (`wf-engine.rkt`) already provides the bilattice-based oracle. In ATMS context, the extension is making the oracle **worldview-aware**: the bilattice truth value of a predicate may differ across worldviews. The oracle consults the bilattice under the current worldview's assumptions.

---

## 9. Tabling: SLG on Propagator Cells

Tabling is the largest new component. This section expands the Logic Engine Design (§6) with concrete propagator-level design grounded in Track 7's taxonomy.

### 9.1 Design Principle: Tables are Accumulator Cells

The key insight from the Logic Engine Design (§6.2-6.4): a table IS a PropNetwork cell with `SetLattice` merge. The `table-store` is merely an **index** mapping goal patterns to cell-ids — the actual answers live in the network.

| Tabling Concept | Propagator Realization |
|---|---|
| Table | Cell with `SetLattice` merge (accumulator pattern from Track 7 §2.6) |
| Producer | Propagator that solves the relation and writes answers to the table cell |
| Consumer | Propagator watching the table cell, re-fires when set grows |
| Completion | Quiescence: no producer can add new answers → all table cells stable |
| Answer mode `:all` | `SetLattice` merge = set-union |
| Answer mode `:lattice` | Custom lattice merge (join) on a single aggregated value |
| Answer mode `:first` | Cell frozen after first write (monotone: ⊥ → value → done) |

### 9.2 Table Lifecycle

```
1. First call to tabled relation R with args A
   → Create table cell C_R_A in solver network (SetLattice merge)
   → Register (R, abstract(A)) → C_R_A in table-store
   → Install PRODUCER propagator:
       Watches: arg cells
       Fire: solve R's clauses, write each answer to C_R_A
   → This call is the LEADER

2. Recursive call to same R with compatible args
   → table-store lookup: (R, abstract(A)) → C_R_A already exists
   → Install CONSUMER propagator:
       Watches: C_R_A
       Fire: for each answer in C_R_A, unify with caller's cells
   → This call is a CONSUMER (no new solving, just reads)

3. Producer fires, writes answers to C_R_A
   → C_R_A value grows (SetLattice: new answers union with existing)
   → Consumer propagators watching C_R_A re-fire (worklist scheduling)
   → Consumers propagate new answers to their callers

4. Network reaches quiescence
   → No producer can add new answers
   → All table cells stable
   → COMPLETION: all tables are complete

5. Subsequent queries for R with same args
   → table-store lookup finds C_R_A
   → Read directly from quiescent cell: O(1)
```

### 9.3 BSP Integration (Logic Engine §6.7)

Table producers and consumers are standard propagators — they participate naturally in BSP:

- **Parallel producer firing**: Multiple producers for different tables fire in parallel within a BSP round. Each writes to its own table cell; bulk-merge unions the results.
- **Self-referencing tables** (recursive predicates): BSP's Jacobi iteration handles this correctly — the producer sees the snapshot from the *previous* round, not in-progress writes. New answers appear in the next round. This matches SLG resolution's stratified evaluation.
- **Completion = quiescence**: When no new answers appear in a BSP round → all tables complete.

```
BSP Round 1: producer fires → ancestor cell gets {(a,b), (b,c), (b,d)}
BSP Round 2: producer re-fires (cell grew) → derives {(a,c), (a,d)}
BSP Round 3: producer re-fires → no new answers → quiescence = completion
```

### 9.4 Answer Modes (Logic Engine §6.5)

| Mode | Cell Merge | Behavior | Use Case |
|---|---|---|---|
| `:all` (default) | `SetLattice` (set-union) | Collect all distinct answer substitutions | General querying |
| `:lattice` | Custom lattice join | Single aggregated value; new answers only "new" if they improve | Min/max aggregation |
| `:first` | Freeze after first | Table frozen after first answer | Deterministic predicates |

Declared via spec metadata: `spec ancestor ... :tabled true :answer-mode all`

### 9.5 Table Key Abstraction

The table key determines when two calls are "the same" for tabling purposes. Following XSB:

- **Variant-based tabling** (default): Two calls are the same if they have the same predicate name and the same pattern of ground/variable arguments (up to variable renaming). `ancestor("alice", ?x)` and `ancestor("alice", ?y)` share a table. `ancestor("alice", ?x)` and `ancestor("bob", ?x)` have different tables.
- **Subsumptive tabling** (future): A more general call subsumes a more specific one. `ancestor(?x, ?y)` subsumes `ancestor("alice", ?y)`. Requires answer filtering at read time. More complex but reduces redundant computation.

Part 3 implements variant-based tabling. Subsumptive tabling is a future optimization.

### 9.6 Interaction with ATMS Worlds

In Tier 2 (ATMS active), table answer cells participate in the worldview mechanism:

- **Unconditional answers** (derived without any clause assumptions): support set = ∅. Believed in ALL worldviews. These are facts and ground-derivable answers.
- **Conditional answers** (derived under clause assumptions): support set = {h₃, h₇, ...}. Believed only in worldviews that include those assumptions.
- **Table reads are worldview-filtered**: A consumer propagator reading the table cell under worldview W sees only answers whose support set is consistent with W.

This means tabling and ATMS compose correctly: shared subgoal answers are memoized across worlds (unconditional answers), while world-specific answers are properly isolated.

---

## 10. Stratified Resolution in Multi-World Context

### 10.1 The Complete Layered Architecture

Part 3 integrates the ATMS solver layer into Track 7's stratified architecture. The three-layer model from RELATIONAL_LANGUAGE_VISION maps directly:

```
┌─────────────────────────────────────────────────────────────────┐
│  Solver Layered Quiescence (per solve invocation)               │
│                                                                  │
│  S(-1): Retraction                                               │
│    • Clean scoped cells of non-believed entries                  │
│    • ATMS nogood-pruned worlds: entries tagged with failed       │
│      clause assumptions are cleaned                              │
│                                                                  │
│  S0: Monotone Propagation                                        │
│    • Cell-tree unification propagators (Part 2)                  │
│    • Is-goal evaluation propagators                              │
│    • UF find/union operations                                    │
│    • Table producer propagators (write new answers)              │
│    • Table consumer propagators (propagate answers to callers)   │
│    • ATMS clause-world propagators (per-world cell writes)       │
│                                                                  │
│  L1: Readiness + NAF                                             │
│    • Conjunction readiness (fan-in: all subgoals satisfied?)     │
│    • NAF evaluation (WF oracle or ATMS worldview check)          │
│    • Tabling completion gate (threshold: no new answers?)        │
│                                                                  │
│  L2: Resolution + Answer Collection                              │
│    • Resolve ready constraints (numeric narrowing, etc.)         │
│    • Collect answers from table cells per worldview              │
│    • Project bindings into result maps                           │
│                                                                  │
│  Scheduling: Hybrid BSP/Gauss-Seidel (from Track 7)             │
│    WITHIN each stratum: BSP (parallel when above :threshold)     │
│    BETWEEN strata: Gauss-Seidel (sequential barrier)             │
│    Feedback: L2 → S0 restarts from S(-1)                        │
│                                                                  │
│  Parallel Worldview Exploration (Logic Engine §5.8)              │
│    When :execution :parallel and worldview count > :threshold:   │
│    Each worldview gets its own run-to-quiescence-bsp call.       │
│    Persistent network = no interference. Structural sharing      │
│    via CHAMP. Answers collected and deduped after all complete.  │
└─────────────────────────────────────────────────────────────────┘
```

### 10.2 NAF + ATMS Interaction

The existing `wf-engine.rkt` provides single-world NAF. In multi-world context:

1. The WF engine's bilattice tracks truth values per predicate.
2. In Tier 2, truth values become **worldview-dependent**: a predicate may be true in world W₁ but false in world W₂.
3. The NAF oracle is extended to accept a worldview parameter: `(naf-oracle pred-name worldview)`.
4. At L1, the NAF propagator consults the oracle under the current worldview.
5. If the oracle returns `'defer`, the NAF goal residuates (3-valued unknown) — consistent with WFS.

---

## 11. Allocation Efficiency

The recent propagator/cell allocation audit (`2026-03-18_TRACK8_PROPAGATOR_INFRASTRUCTURE_AUDIT.md`) identified `struct-copy` on `prop-network` as the dominant allocation cost. ATMS-world exploration amplifies this: each clause world creates fresh cells (per-clause α-renamed variables) and propagators.

### 11.1 Quantitative Concern

For a relation with K clauses, D recursion depth, and V variables per clause:
- Cells created: O(K × D × V) per `solve-app-goal`
- Each cell creation: 1 `struct-copy` of `prop-network` (13-field struct)
- Each propagator addition: 1 `struct-copy` of `prop-network`
- Total struct-copies per query: O(K × D × V × 2) + worklist scheduling overhead

For the solve-adversarial benchmark (~14.3s), this could be significant.

### 11.2 Mitigation Strategies

**M1: Batched cell creation.** Instead of one `struct-copy` per cell, batch all cells for a clause into a single network update. `net-new-cells` (plural) takes a list of initial values and merge functions, returns the network with all cells added in one `struct-copy`.

**M2: BSP snapshot reuse.** The BSP scheduler already takes a snapshot of the network at the start of each round. All propagator firings within a round read from the same snapshot. This means cell reads during a round are O(1) in the snapshot — no per-read struct-copy. Writes are collected and bulk-merged. This is already implemented.

**M3: Single-clause fast path.** When a relation has exactly one matching clause, no ATMS overhead: no `atms-amb`, no pairwise nogoods, no worldview management. The propagators are installed directly on the base network. This covers the majority of solver calls (most relations have 1-2 clauses per arity).

**M4: Tabling as memoization.** Tabled relations compute each answer once. Subsequent queries read from the table cell — no re-solving, no re-allocation. For recursive relations, this bounds the total allocation to O(|answer set| × V) instead of O(K^D × V).

**M5: UF for var-var bindings.** Variable-to-variable unification (`?x = ?y`) goes through the union-find, not through cell writes. This avoids creating propagators for the most common unification case.

**M6: Deferred — incremental GC for solver cells.** After quiescence, cells that are no longer watched by any propagator can be reclaimed. This is a post-Part 3 optimization, tracked in DEFERRED.md.

---

## 12. Implementation Phases

### Phase 0: Prerequisites and Bridge Retirement

**What**: Remove Part 2 deferred bridges. Verify solver-config operational readiness.

- Retire `normalize-term-deep` (relations.rkt:256-275)
- Retire `solver-term->prologos-expr` (reduction.rkt:218-230)
- Retire `ground->prologos-expr` (reduction.rkt:260-277)
- Verify `solver-config` knobs are accessible from `solve-goal`/`explain-goal`

**Gate**: Part 2 complete, `current-punify-enabled?` is System 2 default.

### Phase 1: UnionFind (Logic Engine Phase 4)

**What**: Persistent disjoint sets for structural unification.

- `union-find.rkt`: `uf-store`, `uf-make-set`, `uf-find` (path splitting), `uf-union` (rank merge), `uf-value`
- All operations pure: take store, return new store
- Backtracking = keep old reference (O(1))
- Integration test: use as substitution store for simple unification

**Estimated**: ~120 lines, ~30 tests

### Phase 2: Solver State + Goal-as-Propagator

**What**: Create `solver-state` tuple. Map each goal type to a propagator. Implement under `:strategy :depth-first` first (no ATMS, just propagator-based DFS).

- `solver-propagators.rkt`: goal-propagator structs, dispatch, watched cells, fire functions
- Unify-goal: delegates to Part 2 cell-tree propagators
- Is-goal: transform propagator (evaluate + bind)
- Guard-goal: threshold propagator (predicate gate)
- App-goal: for DFS mode, sequential clause iteration via propagators (same semantics as current, different mechanism)
- Not-goal: NAF via existing WF oracle
- Solver state threading: `(solver-state uf-store network #f table-store config)`

**Test**: All existing solve tests pass through propagator-based goals. Performance within 2× of DFS baseline (propagator overhead is acceptable at this stage).

**Estimated**: ~400 lines, ~60 tests

### Phase 3: The Multiverse Multiplexer (ATMS Clause Exploration)

**What**: Replace DFS clause iteration with `atms-amb`. Tier 1 → Tier 2 upgrade. This is the core architectural shift.

- `atms-amb` over clause alternatives in `solve-app-goal`
- Per-clause propagator installation under assumptions
- Single-clause fast path (no amb)
- Tier upgrade on first multi-clause call
- Nogood accumulation from contradictions (dependency-directed backtracking)
- Solver state: `(solver-state uf-store network atms table-store config)`

**Test**: Multi-clause relations produce correct all-solutions. Nogoods prune invalid combinations. `:strategy :depth-first` still works (Phase 2 path).

### Phase 4: Solution Enumeration

**What**: Bridge `atms-solve-all` to logic variable cells. Extract bindings from surviving worldviews.

- For each consistent worldview: `atms-with-worldview` → read all logic var cells → project into binding maps
- `solve-one`: early-exit variant (first consistent worldview)
- Order preservation: clause ordering determines assumption preference → worldview enumeration follows clause order for `solve-one`
- Integration with `explain-goal`: derivation trees from ATMS support sets

**Test**: `solve` returns all solutions. Order matches DFS for `solve-one`. `explain` returns provenance.

### Phase 5: Tabling (SLG Core)

**What**: Table registry, producer/consumer propagators, completion detection. Left-recursive relations terminate.

Sub-phases:
- **5a**: Table-store index + table cell creation (accumulator cells with SetLattice)
- **5b**: Producer propagators (solve clauses, write answers to table cell)
- **5c**: Consumer propagators (watch table cell, propagate answers)
- **5d**: Completion detection (quiescence = no new answers)
- **5e**: Answer modes (`:all`, `:lattice`, `:first`)
- **5f**: Spec metadata integration (`:tabled`, `:answer-mode`)
- **5g**: ATMS interaction (worldview-filtered table reads)

**Test**: `ancestor` terminates. Fibonacci tabling. SLG completion tests from XSB literature. `:answer-mode :lattice` for aggregation. Tabling + ATMS for recursive search.

**Estimated**: Largest phase — ~500 lines, ~80 tests

### Phase 6: NAF in ATMS Context

**What**: Extend WF NAF oracle to multi-world context. Worldview-aware bilattice consultation.

- NAF oracle accepts worldview parameter
- Bilattice truth values per-worldview
- L1 stratum: NAF propagators fire after S0 quiesces
- 3-valued (succeed/fail/defer) preserved

**Test**: NAF with tabling produces correct WFS answers. Multi-world NAF correctly differs across worldviews.

### Phase 7: BSP Parallel Worldview Exploration

**What**: When `:execution :parallel` and worldview count ≥ `:threshold`, explore worldviews in parallel.

- Each worldview gets its own `run-to-quiescence-bsp` call
- Persistent network = no interference (CHAMP structural sharing)
- Answers collected and deduped after all complete
- `make-parallel-fire-all` executor from Logic Engine §2.5

**Test**: Parallel produces same results as sequential. Performance improvement for large search spaces.

### Phase 8: Integration, Performance, and Acceptance

**What**: End-to-end validation. Acceptance file at Level 3. Performance tuning.

- Full solve-adversarial benchmark: ≤ 15% regression budget
- Acceptance file: all solver sections pass
- Solver-config knobs operational: all combinations of `:strategy`, `:execution`, `:tabling` work correctly
- Bridge `solve-with` / `explain-with` to new engine

---

## 13. Risk Analysis

### HIGH: Tabling Complexity

**Risk**: SLG resolution is complex. Leader/consumer distinction, completion detection, and ATMS interaction are subtle. Bugs produce silently wrong answers.

**Mitigation**: Extensive test suite from XSB/SWI-Prolog literature. Sub-phased development (5a-5g). Positive tabling before ATMS interaction.

### HIGH: Performance Regression for Simple Queries

**Risk**: ATMS + propagator overhead makes simple ground-term lookups slower than DFS.

**Mitigation**: Three-level fast path: (1) single-clause → no amb. (2) `:strategy :depth-first` → no ATMS ever. (3) Tabling → memoized answers for repeated queries. Benchmarking after each phase.

### MEDIUM: Allocation Pressure

**Risk**: `struct-copy` cost from audit multiplied by solver cell creation.

**Mitigation**: Batched cell creation (M1), BSP snapshot reuse (M2), single-clause fast path (M3), UF for var-var (M5). Monitor via `process-file #:verbose` cell_allocs counter.

### MEDIUM: Goal Ordering Semantics

**Risk**: Data-driven ordering changes behavior for programs depending on left-to-right.

**Mitigation**: Default to left-to-right (priority-ordered propagators). Data-driven ordering is opt-in via `:narrow-value-order :smallest-domain`.

### LOW: Part 2 Cell-Tree Stability

**Risk**: Bugs in Part 2's data constructor descriptors propagate to Part 3.

**Mitigation**: Part 2 is strict prerequisite. Part 3 doesn't start until Part 2's acceptance file passes at Level 3.

---

## 14. Previously Open Questions — Resolved

These questions from the original draft are answered by the Logic Engine Design and solver-config:

**Q1: Tabling granularity?** — Resolved: `:tabling :by-default` in `default-solver-config`. All `defr` predicates tabled unless `:tabled false` in spec metadata. This is the Logic Engine §6.6 design.

**Q2: DFS compatibility mode?** — Resolved: `:strategy :depth-first` preserves exact DFS semantics. `depth-first-solver` config is pre-defined. For `:strategy :auto`, clause ordering determines assumption preference → `solve-one` returns first-clause answer first.

**Q3: ATMS per-command or persistent?** — Resolved: Per `solve` invocation. Each `solve` call creates a fresh solver-state (network + UF + ATMS + tables). No cross-query state. This is the Logic Engine §7.4.2 design: "creates a fresh (network, uf-store) pair scoped to the query."

**Q4: Solver network isolation?** — Resolved: Separate solver network per `solve`. Part 2's Phase 5a already creates solver-specific prop-networks. Solver cell state doesn't pollute the elaborator's type cells.

---

## 15. Theoretical Connections

### 15.1 Forbus & de Kleer (1993)

*Building Problem Solvers* Ch. 11: ATMS-based logic programming. Each clause is an assumption. Conjunction creates compound labels. Nogoods implement intelligent backtracking. Our implementation follows this architecture with modern persistent data structures (CHAMP).

### 15.2 XSB Prolog / SLG Resolution

Swift & Warren (1994): SLG resolution provides the tabling algorithm. Our propagator network naturally handles the table-consumer wake-up pattern (table entries are cells, consumers are propagators watching those cells).

### 15.3 Well-Founded Semantics (WFS)

The three-stratum model aligns with WFS's three-valued logic: true (proven in S0), false (negation succeeds in L1), unknown (neither stratum produces a definitive answer). Already identified in the WF-LE architecture (Layered Recovery Principle). The bilattice (`bilattice.rkt`) provides the algebraic substrate.

### 15.4 Constraint Logic Programming (CLP)

The ATMS-world solver naturally supports CLP: constraints are propagators on solver cells. The `#=` narrowing operator is already a constraint propagator. Part 3 brings the search strategy into alignment — CLP's constraint-and-search model IS propagators + ATMS.

### 15.5 Needed Narrowing (Antoy et al.)

The FL Narrowing Design's definitional trees, needed demand analysis, and residuation-first principle map directly onto the solver's goal-as-propagator framework. Definitional tree Branch nodes ↔ amb choice points. Rule nodes ↔ unification propagators. Exempt nodes ↔ contradictions. This positions the future narrowing integration (defn-as-defr) as a natural extension of Part 3's architecture.

### 15.6 Fiber Bundles and Galois Connections

The ATMS worldview structure is a fiber bundle over the base network (§5.5). Cross-lattice bridges are Galois connections realized as propagators. The stratified fixpoint tower is Knaster-Tarski applied compositionally. These categorical structures provide the "snap-together lego blocks" for reasoning about network-of-networks composition.

---

## 16. Dependencies and Enabling

**Depends on**:
- Part 2 complete (cell-tree unification, descriptor registry)
- Track 7 complete (two-network architecture, stratified resolution, propagator taxonomy)
- Track 4 complete (TMS/ATMS infrastructure)

**Does NOT depend on**:
- Track 8 second half (mult bridges, id-map migration)
- Track 9 (GDE) — but GDE will consume Part 3's ATMS infrastructure
- Track 10 (LSP)

**Enables**:
- **Tabling** → scalable Datalog-style queries, left-recursion termination
- **Well-Founded Semantics** → three-valued logic for the relational sublanguage
- **CLP integration** → constraints compose with ATMS-world search
- **Provenance** → ATMS support sets give every derived fact a justification chain
- **FL Narrowing integration** → `defn` functions usable as relations (Narrowing Design Phases 1-3)
- **`solve-with`** → solver-configuration combinator with all knobs operational
- **Graph-query database patterns** → from RELATIONAL_LANGUAGE_VISION

---

## 17. Key Files

| File | Role in Part 3 |
|------|---------------|
| `union-find.rkt` | **NEW** — Persistent disjoint sets |
| `solver-propagators.rkt` | **NEW** — Goal-as-propagator framework |
| `tabling.rkt` | **NEW** — Table registry, producer/consumer propagators |
| `relations.rkt` | Primary target — DFS solver → propagator-based solver |
| `solver.rkt` | Solver config (existing — wire knobs to engine) |
| `atms.rkt` | ATMS data structure (existing) |
| `elab-speculation-bridge.rkt` | N-ary speculation extension |
| `wf-engine.rkt` | NAF oracle (extend for multi-world) |
| `propagator.rkt` | TMS cells, worklist, BSP scheduler |
| `resolution.rkt` | Stratified resolution loop |
| `elaborator-network.rkt` | Cell creation, decomposition registry |
| `ctor-registry.rkt` | Constructor descriptors (from Part 2) |
| `benchmarks/comparative/solve-adversarial.prologos` | End-to-end benchmark (14.3s) |
| `benchmarks/micro/bench-solve-pipeline.rkt` | Micro-benchmarks |
| `examples/2026-03-19-punify-acceptance.prologos` | Acceptance file |

---

## 18. Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| 0 | Bridge retirement (from Part 2 5d) | ⬜ | Retire normalize-term-deep, solver-term->prologos-expr, ground->prologos-expr |
| 1 | UnionFind (Logic Engine Phase 4) | ⬜ | Persistent disjoint sets, path splitting, rank merge |
| 2 | Solver state + goal-as-propagator | ⬜ | DFS-mode first (`:strategy :depth-first`), then ATMS |
| 3 | Multiverse multiplexer (ATMS clause exploration) | ⬜ | `atms-amb`, Tier 1→2 upgrade, nogood accumulation |
| 4 | Solution enumeration | ⬜ | `atms-solve-all` bridge, solve-one, explain integration |
| 5 | Tabling (SLG core) | ⬜ | Largest phase — 7 sub-phases (5a-5g) |
| 6 | NAF in ATMS context | ⬜ | Worldview-aware WF oracle |
| 7 | BSP parallel worldview exploration | ⬜ | `:execution :parallel` operational |
| 8 | Integration, performance, acceptance | ⬜ | Adversarial benchmark, Level 3, all solver-config knobs |
