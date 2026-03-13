# Track 2: Reactive Constraint Resolution — Design Document

**Date**: 2026-03-13
**Status**: DESIGN (pre-implementation)
**Predecessor**: Track 1 (Cell-Primary Constraint Tracking) — COMPLETE
**Design reference**: Track 1 PIR §7.2, `EFFECTFUL_COMPUTATION_ON_PROPAGATORS.org`

## Summary

Track 2 replaces the imperative retry loops and batch post-passes in the type
checker with propagator-driven reactive resolution. When a metavariable's type
becomes known, resolution propagators fire *during* network quiescence rather
than *after* it in explicit call chains.

This document captures the design analysis, formal grounding, and open
questions that must be resolved before implementation.

## Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| D.1 | Design analysis and formal grounding | ✅ | commit 061455e |
| D.2 | Design iteration (review feedback) | ✅ | commit 4edfa80 |
| D.3 | Principles capture (data orientation) | ✅ | commit 5a9bf3f |
| D.4 | Phase 1 dependency mapping | ✅ | |
| D.5 | Performance baseline capture | ⬜ | Before Phase 1 implementation |
| D.6 | External review integration | ✅ | |
| 1 | Instance registry — cell reader infrastructure | ✅ | `read-impl-registry` + 4 read conversions; parameter write stays for cross-command |
| 2 | Constraint status cells (pending/resolved) | ✅ | commit `b4cdb1e`; cid field on constraint, enet9 status cell, dual-write in unify.rkt |
| 3 | Stratified quiescence architecture | ✅ | commit `4c0c927`; solve-meta! split into core + stratified loop, fuel=100 |
| 4 | Data-oriented solve-meta! (action descriptors) | ✅ | commit `e6aeafc`; 3 descriptor structs, 5 scan fns, interpreter with re-check guards |
| 5 | Trait resolution propagators | ✅ | Already covered by Phase 4 `collect-ready-traits-via-cells` scan; trait-cell-map from Track 1 |
| 6 | HasMethod resolution propagators | ✅ | commit `4a91b24`; hasmethod-cell-map cell (enet10), `collect-ready-hasmethods-via-cells` scan wired into S1 |
| 7 | Error cell + grouped error reporting | ⬜ | Set-union merge keyed on constraint ID; includes HKT-7 |
| 8 | Post-pass elimination | ⬜ | Compare performance against D.5 baseline |
| 9 | Confluence verification | ⬜ | Prerequisite: HKT-7 (Phase 7); randomized-order property tests |

---

## §1. What Exists Today

### 1.1 The Imperative Call Chain

When `solve-meta!` is called (23 call sites in `typing-core.rkt`), it executes
a four-layer imperative sequence:

```
solve-meta!(id, solution)
  1. Write meta cell                     [PURE: network value transform]
  2. Run quiescence                      [PURE: net → net]
  3. retry-constraints-via-cells!        [EFFECT: mutates constraint status,
                                          calls retry-fn → unify → solve-meta!]
  4. retry-traits-via-cells!             [EFFECT: calls resolve-fn → solve-meta!]
     retry-trait-for-meta!(id)           [EFFECT: targeted wakeup]
  5. retry-hasmethod-for-meta!(id)       [EFFECT: targeted wakeup → solve-meta!]
```

Steps 1-2 are pure network transformations. Steps 3-5 are effectful and
re-entrant: each can trigger `solve-meta!` recursively.

### 1.2 The Batch Post-Pass

After type-checking completes, `driver.rkt` calls:

1. `resolve-hasmethod-constraints!` — walks ALL hasmethod constraints, zonks
   type-args, performs two-stage resolution (known trait → direct, unknown
   trait → search all traits for matching method). 5 call sites.

2. `check-unresolved-trait-constraints` — error reporting only. Returns list
   of `no-instance-error` structs. 5 call sites.

Note: the trait resolution post-pass (`resolve-trait-constraints!`) was already
removed — comments in `driver.rkt` say "handled by propagator cell-path in
solve-meta!" The hasmethod post-pass is the last batch resolver standing.

### 1.3 The Effect Inventory

Every effect in the current `solve-meta!` call chain:

| Step | Operation | Effect Type | Captured by save/restore? |
|------|-----------|-------------|--------------------------|
| Cell write | `set-box! net-box (write-fn ...)` | State mutation (boxed network) | YES |
| Quiescence | `run-fn pnet` → `set-box!` | Pure + state mutation | YES |
| Constraint status | `set-constraint-status! c 'retrying` | Struct mutation | NO |
| Retry unify | `(retry-fn c)` | Calls unify → may call solve-meta! | Partially |
| Trait resolve | `(resolve-fn dict-id tc-info)` | Calls resolution → may call solve-meta! | Partially |
| Hasmethod resolve | `(resolve-fn meta-id hm-info)` | Same | Partially |

**Critical gap**: the in-place `set-constraint-status!` mutation is NOT
captured by `save-meta-state`/`restore-meta-state!`. During speculation,
constraint status can leak across branches.

---

## §2. The Data-Oriented Imperative

### 2.1 The Principle

**Data orientation**: prefer structures where behavior is derived from data
transformations rather than embedded in imperative control flow. Effects
become first-class descriptions of intent, interpreted at explicit control
boundaries rather than executed in-line.

This principle is the natural extension of several existing Prologos design
choices:

- **Propagator-First Infrastructure** (DESIGN_PRINCIPLES.org): "default to
  propagator cells over mutable hash tables" — data over state mutation
- **Correct by Construction**: "correctness is a structural property of the
  architecture" — data structures that make wrong states unrepresentable
- **Layered Recovery Principle** (EFFECTFUL_COMPUTATION_ON_PROPAGATORS.org):
  "reasoning about effects happens monotonically... executing effects happens
  at a control boundary" — separate effect description from effect execution

What data orientation adds: the explicit recognition that *control flow with
embedded effects is itself a form of incidental complexity*. The four-layer
call chain in `solve-meta!` braids together pure computation (cell writes,
quiescence) with effectful operations (constraint retry, trait resolution,
recursive solve-meta! calls). The braid makes the system hard to reason about,
hard to observe, and hard to test in isolation.

The data-oriented alternative: `solve-meta!` returns (or accumulates) a
*description* of what should happen next — a worklist of resolution actions.
A separate interpreter loop processes the worklist, producing new network
states and new action descriptors, until the worklist is empty.

### 2.2 The Free Monad Analogy

Categorically, this is the **free monad** pattern. Instead of:

```
solve-meta! id val = do
  write-cell id val
  run-quiescence
  for each constraint c:
    retry c  -- EFFECT: may call solve-meta! recursively
```

We have:

```
solve-meta id val = do
  write-cell id val
  run-quiescence
  return [RetryConstraint c | c <- woken-constraints]  -- DATA: action descriptors
```

The interpreter loop:

```
run-to-resolution net actions =
  case actions of
    [] -> net  -- fixpoint reached
    (RetryConstraint c : rest) ->
      let (net', new-actions) = retry c net
      run-to-resolution net' (rest ++ new-actions)
    (ResolveTraitDict id info : rest) ->
      let (net', new-actions) = resolve-trait id info net
      run-to-resolution net' (rest ++ new-actions)
```

The action descriptors form a **free algebra** over the effect signature.
The interpreter is the **fold** that evaluates the algebra. This separation
gives us:

1. **Inspectability**: the worklist is data — it can be logged, counted,
   visualized in the observatory, validated for confluence
2. **Testability**: resolution logic can be unit-tested with mock action
   descriptors without running the full elaborator
3. **Ordering control**: the interpreter chooses evaluation order, enabling
   stratification without modifying the resolution logic itself
4. **Totality**: the interpreter can enforce fuel limits, detect cycles, and
   guarantee termination — structurally, not by convention

### 2.3 The Semi-Naive Evaluation Connection

This is also the **semi-naive evaluation** pattern from Datalog. Naive
evaluation re-scans all rules on every iteration. Semi-naive evaluation tracks
the *delta* (newly derived facts) and only applies rules that could be
affected by the delta.

Today's `retry-constraints-via-cells!` is naive: it scans ALL postponed
constraints checking if any meta cell became non-bot. The propagator-driven
alternative is semi-naive: resolution propagators fire *only* for constraints
whose input cells changed.

The formal correspondence:
- **Datalog tables** ↔ propagator cells
- **Datalog rules** ↔ propagators
- **Derived facts** ↔ resolution actions (solve-meta! calls)
- **Semi-naive delta** ↔ propagator worklist (only fire propagators whose
  inputs changed)

This connection is explicitly noted in Kmett's propagator framework:
"Datalog rules are propagators and Datalog tables are cells."

---

## §3. Stratified Quiescence

### 3.1 The Layered Recovery Principle Applied to Type Checking

The existing Layered Recovery Principle (from `EFFECTFUL_COMPUTATION_ON_PROPAGATORS.org`)
applies to two domains:

| Domain | Monotone Core | Non-Monotone Barrier |
|--------|--------------|---------------------|
| `rel` (logic engine) | Unification propagation | Stratified negation evaluation |
| `proc` (session runtime) | Session advancement + ordering closure | Effect execution |

Type checking is the **third** application:

| Domain | Monotone Core | Non-Monotone Barrier |
|--------|--------------|---------------------|
| Type checker | Type/meta cell propagation + readiness detection | Resolution commitment (solve-meta!) |

### 3.2 The Strata

```
Stratum 0: Type Propagation (MONOTONE)
  - Cell writes (meta solutions → type cells)
  - Unify propagators (bidirectional type flow)
  - Cross-domain bridges (type ↔ multiplicity, type ↔ capability)
  - Fixed point: all type information has flowed through the network

Stratum 1: Readiness Detection (MONOTONE)
  - Constraint-readiness propagators (watch meta cells → produce "constraint C
    is ready to retry" when inputs become non-bot)
  - Trait-readiness propagators (watch type-arg cells → produce "trait dict D
    is ready to resolve" when all type-args are ground)
  - HasMethod-readiness propagators (same pattern)
  - Fixed point: all readiness information has been derived

Stratum 2: Resolution Commitment (NON-MONOTONE BARRIER)
  - Consume readiness signals from Stratum 1
  - Execute resolution (retry constraint, resolve trait dict, solve meta)
  - New solve-meta! calls feed back to Stratum 0
  - Loop: Stratum 0 → 1 → 2 → 0 → ... until global fixpoint
```

This is the same three-layer architecture as `rel` and `proc`:

| Layer | `rel` | `proc` | Type Checker |
|-------|-------|--------|-------------|
| Propagation (monotone) | Unification cells | Session cells | Type/meta cells |
| Detection (monotone) | — | Data-flow analysis | Readiness cells |
| Barrier (non-monotone) | Negation eval | Effect execution | solve-meta! commitment |

### 3.3 Why Stratification Resolves the Re-Entrancy Problem

Today's `solve-meta!` is re-entrant: resolution in step 3-5 can recursively
call `solve-meta!`, which runs quiescence again, which may fire more
propagators. This is a recursive call stack whose depth depends on the
constraint graph — unbounded in principle.

With stratified quiescence, re-entrancy becomes iteration:

```
loop:
  S0: run type propagation to fixpoint
  S1: run readiness detection to fixpoint
  S2: collect all ready resolutions
      for each resolution:
        execute it (may produce new S0 work)
  if S0 worklist non-empty: goto loop
  else: global fixpoint
```

The key insight: Stratum 2 produces *all* its resolution actions before
feeding any of them back to Stratum 0. This eliminates the recursive call
stack — the loop is always flat. Each iteration of the outer loop may
produce new work for Stratum 0, but the strata are evaluated in sequence,
never recursively.

### 3.4 Categorical Perspective

Each stratum is a **functor** between lattices:

- S0 → S1: the functor α extracts readiness information from type cell states
- S1 → S2: the functor maps readiness signals to resolution actions
- S2 → S0: the functor maps committed resolutions back to type cell writes

The composition S0 → S1 → S2 → S0 is an **endofunctor** on the type lattice.
The global fixpoint is the least fixed point of this endofunctor — computed
by Kleene iteration (the outer loop).

The Galois connection between strata mirrors the session ↔ effect connection:
- α : TypeCells → Readiness (abstraction: extract what's ready)
- γ : Readiness → TypeCells (concretization: commit resolutions)

Both are monotone. The adjunction guarantees that the stratified fixpoint
equals the unstratified fixpoint (when it exists) — i.e., stratification
doesn't change the result, only the evaluation strategy.

---

## §4. Confluence Analysis

### 4.1 Stratum 0: Confluent by Construction

The propagator network guarantees confluence when:
1. Merge is commutative, associative, idempotent (lattice join)
2. All propagators are monotone

Our type lattice merge satisfies all properties. The BSP scheduler comment
(`propagator.rkt` line 492-495) explicitly states this. This is a structural
guarantee — no ordering assumptions needed.

### 4.2 Stratum 1: Confluent by Construction

Readiness detection is a monotone function of cell state: once a cell becomes
non-bot, readiness is signaled. Readiness is monotone (once ready, always
ready — cell values only grow in a lattice). Multiple readiness propagators
firing in different orders produce the same readiness set.

### 4.3 Stratum 2: Confluent Under Non-Overlapping Instances

Resolution commitment is confluent IF each constraint has at most one valid
resolution. Today this holds because:

1. **Trait resolution**: for a given `(TraitName, TypeArgs)`, at most one
   instance matches (monomorphic lookup by key string, or parametric
   most-specific-wins with tie-breaking).
2. **HasMethod resolution**: for a given `(method-name, TypeArgs)`, the search
   returns a result only when exactly one trait matches (line 519 of
   `trait-resolution.rkt`: `(and (= (length candidates) 1) (car candidates))`).
3. **Constraint retry**: unification is confluent (same result regardless of
   order).

**This confluence is contingent, not structural.** It depends on the
non-overlapping instance invariant.

### 4.4 Overlapping Instances — The Haskell Lesson

#### What Haskell Does

GHC's `OverlappingInstances` extension allows multiple instances to match a
constraint, resolving ambiguity via specificity: the most specific instance
wins. For example:

```haskell
instance Show a => Show [a]          -- general
instance {-# OVERLAPPING #-} Show [Char]  -- specific (String)
```

When resolving `Show [Char]`, both instances match, but the second is more
specific (fewer type variables), so it wins.

#### Why Haskell Supports It

Pragmatic motivation: expressing "special case" optimizations for general
type class instances. The canonical example is `Show String` — the general
`Show [a]` instance renders `['h','e','l','l','o']` with constructor syntax,
but the `Show [Char]` instance renders `"hello"` directly.

Other use cases:
- Optimized implementations for specific types (e.g., `nub` specialized for
  `Eq` types with a hashable fast-path)
- Default behavior with opt-out (a general instance provides defaults; more
  specific instances override)

#### The Problems It Creates

1. **Incoherence**: different parts of a program may resolve the same
   constraint to different instances, depending on which modules are imported.
   This breaks the property that adding an instance in one module cannot
   change behavior in another.

2. **Non-confluence**: resolution order affects results when specificity is
   ambiguous. GHC papers over this with tie-breaking rules, but the
   underlying nondeterminism is real.

3. **Fragile reasoning**: users cannot reason locally about which instance
   will be selected — they must consider the entire import graph.

#### Prologos's Position

Prologos currently enforces non-overlapping instances:
- Monomorphic: one impl per `(TraitName, ConcreteType)` key
- Parametric: most-specific-wins with specificity count; same-specificity
  ambiguity returns the first match (TODO: proper ambiguity error — HKT-7)

**The design question**: do we need overlapping instances at all?

**Arguments against** (the Prologos position):
- Non-overlapping instances guarantee confluence — a structural property
  we want for the propagator model
- Bundles provide the compositionality that Haskell gets from superclasses +
  overlapping defaults — without the coherence problems
- Specialization (narrowing, type-class specialization) can handle the
  performance optimization use case without instance overlap — the compiler
  can specialize at call sites without changing resolution semantics

**What if there are multiple solutions?** Today, parametric resolution with
multiple same-specificity matches silently picks the first. This should be an
error — ambiguous resolution is a type error, not a nondeterministic choice.
The fix (HKT-7) should:
1. Detect ambiguity (multiple matches at same specificity)
2. Report a clear error with the conflicting instances listed
3. Never silently pick a winner

**Nondeterminism belongs in the relational space** (`rel`, `defr`), where
ATMS worldviews handle alternatives and backtracking is first-class. The
type checker's resolution should be deterministic — one constraint, one
resolution, verified structurally.

#### Providing Overlapping-Like Behavior Without Overlap

For the use cases Haskell's overlapping instances serve:

1. **Special-case optimization**: use compile-time specialization. The general
   instance provides semantics; the compiler can specialize at monomorphic
   call sites. This is the rewrite-specialization pass we already have.

2. **Default with override**: use bundles with explicit opt-out. A bundle
   provides the default set of traits; a type implements specific traits
   differently. No instance overlap — different traits, composed via bundles.

3. **Conditional behavior**: use type-level dispatch via `match` on types in
   dependent Prologos. `(fn {A : Type} -> ...)` with pattern matching on `A`
   gives type-directed behavior without instance resolution ambiguity.

---

## §5. The Post-Pass: Elimination via Incremental Instance Registration

### 5.1 What the Post-Pass Actually Does

`resolve-hasmethod-constraints!` runs after type-checking completes and:
1. Walks all hasmethod constraints
2. Zonks type-args, checks groundness
3. For ground type-args: attempts resolution (known trait → direct, unknown
   trait → search all registered traits)
4. On success: solves evidence meta, trait variable meta, dict meta

The critical dependency: step 3's trait search depends on the **full set of
registered trait instances**. During elaboration, instances are registered
incrementally as `impl` declarations are processed. A reactive propagator
firing mid-elaboration might miss an instance that hasn't been registered yet.

The post-pass isn't special because of its logic — it's special because of its
*timing*. It runs after all declarations have been processed, meaning all
instances are registered.

### 5.2 Incremental Instance Registration via Cell Writes

The conservative approach would gate resolution propagators on a
"registration-complete" threshold signal. But this is a workaround for batch
processing. The principled approach is to make instance registration itself
incremental and cell-backed.

**Instance Registry Cell**: starts at `(hasheq)` (empty). Each `process-impl`
writes `(hasheq key impl-entry)` to the cell. The merge function is
`merge-hasheq` (hash map union, backed by CHAMP). The cell monotonically
accumulates the full instance registry as declarations are processed.

**Resolution propagators watch the registry cell**:

```
HasMethod Resolution Propagator:
  Inputs: [type-arg-cell-1, type-arg-cell-2, ..., instance-registry-cell]
  Fire: if all type-arg cells non-bot AND registry has matching instance:
          perform resolution, write solution to evidence meta cell
        else:
          return net unchanged (no-op, will re-fire on next change)
```

When type-arg cells are solved before matching instances are registered, the
propagator fires but finds no match — it returns `net` unchanged. Later, when
`process-impl` writes the matching instance to the registry cell, the cell
changes, the propagator fires again, and this time resolution succeeds.

**This is the standard propagator pattern**: partial information, monotone
refinement, eventual convergence. No registration-complete threshold needed.

### 5.3 Why This Aligns with Our Principles

**Propagator-First Infrastructure**: instance registries should be cells, not
mutable hash tables. This is the same principle that motivated Track 1.

**Layered Recovery**: "careful registration order" sounds like it needs
coordination — but under non-overlapping instances, instance registration is
monotone (adding instances only grows the registry) and resolution is monotone
in the registry (more instances can only enable more resolutions, never
invalidate one). The composition is monotone. The CALM theorem says: no
coordination needed. Registration order doesn't matter.

**CHAMP-backed incrementalism**: the instance registry cell's merge is CHAMP
hash map union — O(log₃₂ n) insertion with structural sharing. Each write
creates minimal allocation. Immutable snapshots are captured by save/restore
for free. This is a core value proposition of our propagator infrastructure.

**Partial state is what propagators do**: propagators are designed for
incomplete information. A resolution propagator that fires with an incomplete
registry simply produces no result — the same as a type propagator that fires
with an unsolved meta. The lattice handles partial state natively.

### 5.4 The Post-Pass Becomes Unnecessary

With incremental registration, resolution propagators fire throughout
elaboration as information becomes available. By the time all declarations are
processed, all instances are in the registry cell and all resolution
propagators have had the opportunity to fire. The batch post-pass has no
remaining work to do.

The post-pass can be eliminated entirely. What remains:
1. `check-unresolved-trait-constraints` — error reporting (stays as read-only sweep)
2. `check-unresolved-capability-constraints` — error reporting (stays)
3. `zonk-final` — defaulting unsolved metas (orthogonal)
4. `rewrite-specializations` — optimization pass (orthogonal)

Any constraint still unsolved after the network reaches its global fixpoint is
an error — the program is ill-typed. This is not a diagnostic ("the reactive
path missed something") — it is a definitive type error. If the full instance
registry is in the cell and the propagator still couldn't resolve, no
resolution exists.

### 5.5 Threshold Propagator Design Note

The `net-add-barrier` primitive in `propagator.rkt` implements threshold
propagators as **stateless, pure fire functions**. The fire function
(`make-barrier-fire-fn`) reads cell values on every invocation, checks
predicates, and either runs the body or returns `net` unchanged. No internal
state accumulation.

This is architecturally correct for provenance: every readiness signal is a
cell value, every cell value change is observable by the observatory, every
snapshot captures the full state. The propagator itself is `net → net` — pure.

The monotonicity guarantee makes this work: once a threshold is met on a
monotone lattice, it stays met. A stateless "check threshold every time"
propagator and a stateful "fire once" propagator are observationally identical.
But the stateless version keeps all state in cells (observable, capturable,
speculation-safe).

**Design invariant for Track 2**: propagators read cells, write cells, and
compute pure transformations. Any state that matters for provenance or
speculation must live in cells. Resist the temptation to stash state inside
closures — that state becomes invisible to the observatory and leaks during
speculation.

### 5.6 Strata Revised

With incremental registration, the separate "registration-complete" stratum
collapses. The architecture simplifies:

```
Stratum 0: Type Propagation (monotone)
  - Cell writes, unify propagators, cross-domain bridges
Stratum 1: Readiness Detection (monotone)
  - Constraint readiness, trait readiness, hasmethod readiness
  - Instance registry changes also trigger readiness re-evaluation
Stratum 2: Resolution Commitment (non-monotone barrier)
  - Consume readiness signals, execute resolutions, feed back to S0
  [Loop S0-S2 until global fixpoint]
Post-Fixpoint Error Sweep (after global fixpoint):
  - Sweep unsolved constraints, report errors
  - Read-only: does not participate in the fixpoint iteration
```

Three strata during elaboration (S0-S2), one post-fixpoint error sweep.
No separate registration barrier needed.

---

## §6. Constraint Status as Cell State

### 6.1 The Gap

Constraint status (`'postponed | 'retrying | 'resolved | 'failed`) is stored
as a mutable struct field (`set-constraint-status!`). This is the last piece
of type-checker state that lives outside the propagator network. It is:

- **Not captured** by `save-meta-state`/`restore-meta-state!`
- **Not observable** by the observatory
- **Not subject** to confluence guarantees
- **Invisible** to propagator-driven readiness detection

### 6.2 The Fix

Each constraint gets a **status cell** in the propagator network. With
stratified quiescence eliminating re-entrancy, the `retrying` guard state
has no purpose. The lattice simplifies to two elements:

```
pending → resolved
```

- `pending`: constraint created, not yet resolved (analogous to current
  `'postponed`)
- `resolved`: solution committed (terminal)

Constraints that never reach `resolved` after the global fixpoint are errors
— detected by the post-fixpoint error sweep.

Status transitions become cell writes:
- Creating a constraint writes `pending`
- Successful resolution writes `resolved`
- Failed resolution leaves `pending` (the constraint simply never resolves)

If retry-count provenance is needed later (how many times was this constraint
examined?), that would be a separate counter cell — not a status flag.

Benefits:
- **Speculation safety**: status captured by network snapshot
- **Observability**: observatory can show constraint lifecycle
- **Readiness propagation**: a propagator can watch the status cell and gate
  on `'pending` (don't retry already-resolved constraints)
- **Confluence**: `pending → resolved` is trivially monotone
- **Simplicity**: two-element lattice, no re-entrancy guard needed

### 6.3 Total Network Observability

With constraint status cells, **every piece of type-checker state** lives in
the propagator network:

| State | Cell Type | Achieved |
|-------|-----------|----------|
| Meta solutions | Type cells | Phase 0 (original propagator work) |
| Constraint store | List cell | Track 1 Phase 1c |
| Wakeup registry | Map cell | Track 1 Phase 3a |
| Trait constraints | Map cell | Track 1 Phase 2a |
| Trait wakeup | Map cell | Track 1 Phase 3b |
| Trait cell-map | Map cell | Track 1 Phase 7b |
| HasMethod constraints | Map cell | Track 1 Phase 2b |
| HasMethod wakeup | Map cell | Track 1 Phase 7a |
| Capability constraints | Map cell | Track 1 Phase 2c |
| **Constraint status** | **Status cell (pending/resolved)** | **Track 2 Phase 2** |
| **Instance registry** | **Map cell (CHAMP-backed)** | **Track 2 Phase 1** |
| **Error descriptors** | **Set cell (constraint-ID-keyed union)** | **Track 2 Phase 7** |

This completes the vision of total network observability: the propagator
network is the single source of truth for the entire type-checking state,
including instance registration and resolution errors.

---

## §7. Formal Grounding

### 7.1 Propagator Networks (Radul & Sussman 2009)

Monotone fixed-point computation on lattice-valued cells. Our computational
substrate. The key guarantee: if merge is a lattice join and propagators are
monotone, the network converges to a unique fixpoint regardless of evaluation
order (confluence).

**Direct relevance**: Strata 0-1 are pure propagator computation. Confluence
is guaranteed by construction.

### 7.2 Stratified Datalog (Apt, Blair, Walker 1988)

Stratification of logic programs with negation: divide predicates into strata
such that negation only references lower strata. Each stratum is computed to
a fixpoint before the next stratum begins. Sound and complete for stratifiable
programs.

**Direct relevance**: our Strata 0-2 are exactly stratified evaluation. Type
propagation (S0) is the base stratum. Readiness detection (S1) references S0.
Resolution commitment (S2) is the non-monotone stratum that feeds back to S0.
The loop S0→S1→S2→S0 is the stratified fixpoint iteration.

### 7.3 Semi-Naive Evaluation (Bancilhon 1986)

Optimization of fixpoint iteration: track the delta (new facts) and only
apply rules that could produce new derivations from the delta. Avoids
redundant re-computation.

**Direct relevance**: propagator-driven resolution is inherently semi-naive.
Propagators fire only when their input cells change — the network's worklist
is the delta. No full scan of all constraints needed.

### 7.4 LVars (Kuper & Newton 2013)

Lattice-based data structures for deterministic parallelism. Values in an
LVar can only increase (monotone writes). Reads block until a threshold is
met. Determinism is guaranteed by lattice monotonicity.

**Direct relevance**: our cells are LVars. The threshold propagator
(`net-add-threshold`, `net-add-barrier`) is the LVar threshold read. The
registration-complete cell is an LVar whose threshold is `true`.

### 7.5 CALM Theorem (Hellerstein 2011)

Consistency And Logical Monotonicity: a program has a consistent,
coordination-free implementation if and only if it is monotonic. Non-monotone
operations require coordination.

**Direct relevance**: Strata 0-1 are monotone — they can execute in parallel,
in any order, without coordination. Stratum 2 (resolution commitment) is the
non-monotone boundary where coordination (sequencing) is required. The CALM
theorem says this is the minimum coordination needed.

### 7.6 Effect Quantales (Katsumata 2014, Gordon 2021)

Lattice-ordered monoids with sequential composition. Both session types and
effect positions form effect quantales. The Galois connection is a quantale
morphism.

**Direct relevance**: the type lattice and the readiness lattice are both
quantale-structured. The functors between strata (§3.4) are quantale
morphisms preserving both ordering and composition. This gives formal
grounding for the claim that stratification doesn't change the fixpoint.

### 7.7 Free Monads (Swierstra 2008)

Separating effect description from effect interpretation. The free monad over
an effect signature F builds a tree of effect descriptions; an interpreter
folds the tree into a target monad.

**Direct relevance**: the data-oriented `solve-meta!` returns action
descriptors (the free algebra) rather than executing effects directly. The
stratified interpreter loop (§3.3) is the fold that evaluates the algebra.

### 7.8 Kmett's Propagator Framework (guanxi, 2016)

Blends Radul/Sussman propagators with LVars and Datalog-style scheduling.
Key insight: non-monotone propagators are permissible when they don't
participate in cycles — the same condition that makes stratified Datalog
sound.

**Direct relevance**: validates our stratification approach. Resolution
commitment (S2) is non-monotone but acyclic (it only references lower strata).
The cycle-freedom condition is satisfied structurally.

---

## §8. Design Decisions (Resolved)

### 8.1 Granularity of Action Descriptors → Option A (Fine-Grained)

**Decision**: One action type per resolution kind:
- `RetryConstraint(constraint)`
- `ResolveTraitDict(dict-id, trait-constraint-info)`
- `ResolveHasMethod(meta-id, hasmethod-constraint-info)`
- `SolveMeta(meta-id, solution)`

**Rationale through principles**:

- **Decomplection**: Option A separates *what* should happen (action type)
  from *when* it happens (interpreter scheduling). Option B braids resolution
  logic inside propagator fire functions — mixing what with when.

- **First-Class by Default**: granular action descriptors are reusable data.
  A `ResolveTraitDict` descriptor can be: inspected by the observatory for
  resolution provenance, replayed in testing, serialized for debugging,
  counted for performance analysis. A `SolveMeta` descriptor loses the *why*.

- **Correct by Construction**: the interpreter can validate action descriptors
  before executing them — check that the constraint is still unsolved, verify
  the resolution is still valid, detect conflicts between concurrent
  resolutions. With Option B, validation must happen inside the propagator
  fire function, mixing validation with execution.

- **Computational cost**: negligible. Action descriptors are small structs
  (a tag + a few IDs). The dominant cost is resolution logic (zonking,
  instance lookup, unification), which is identical in both options.

### 8.2 Stratum 2 Execution Strategy → Batch

**Decision**: commit all ready resolutions in one batch before re-entering S0.

Under non-overlapping instances, resolution is confluent (§4.3), so order
doesn't matter. Batch commitment is more efficient (one S0 quiescence pass
for N resolutions) and produces the same result. Single-step commitment adds
N-1 unnecessary quiescence passes with no correctness benefit.

### 8.3 Ambiguity Detection Timing → Resolution-Time, with Cell-Based Collection

**Decision**: detect ambiguity at resolution time (Stratum 2), but accumulate
error descriptors in an **error cell** for grouped presentation.

Resolution propagators write error descriptors to an error cell (another
infrastructure cell, merge function = set-union keyed on constraint ID).
Keying on constraint ID deduplicates: if a resolution propagator fires
multiple times for the same constraint (due to related cell changes), only
one error descriptor survives. The error cell monotonically accumulates all
resolution errors. The post-fixpoint error sweep reads the error cell and
presents grouped, provenance-rich diagnostics.

This gives the best of both approaches:
- **Detection at source**: ambiguity is caught when it occurs, preserving
  full provenance (which constraint, which competing instances, which
  type-args triggered it)
- **Grouped presentation**: errors from related constraints (e.g., `(Eq A)`
  and `(Ord A)` from the same function call) can be presented together
- **Propagator-natural**: error descriptors are data in a cell, not thrown
  exceptions. They are observable, capturable by save/restore, and subject
  to the same confluence guarantees as everything else

With propagators, the usual argument for "throw early" loses its force.
Provenance is structural — the observatory traces any error back to the cell
that caused it. We can wait to collect more errors AND still know exactly
where each came from. This is a capability that imperative control flow
doesn't naturally provide.

### 8.4 Incremental Instance Registration → Yes, Cell-Based

**Decision**: make instance registration a cell write from the start.

See §5.2-5.3 for the full argument. In summary:
- Registration is monotone under non-overlapping instances (CALM: no
  coordination needed)
- CHAMP-backed cells handle partial state and incrementalism natively
- Eliminates the need for a registration-complete threshold
- Resolution propagators fire throughout elaboration as information arrives
- Aligns with Propagator-First Infrastructure and Layered Recovery principles

This is not an advanced extension — it is the principled approach. A
registration-complete threshold would be a workaround for batch processing,
adding complexity to avoid a cell migration that we should do anyway.

### 8.5 Constraint Status Lattice → Two-Element (pending/resolved)

**Decision**: `pending → resolved`.

Stratified quiescence eliminates re-entrancy, so the `retrying` guard state
has no purpose. The two-element lattice is trivially monotone and sufficient.
See §6.2 for details.

---

## §9. Relationship to Existing Principles

This design extends and concretizes several principles from
`DESIGN_PRINCIPLES.org`:

| Principle | How Track 2 Applies It |
|-----------|----------------------|
| Correct by Construction | Stratification makes confluence structural, not contingent |
| Propagator-First Infrastructure | Constraint status → cells; resolution → propagators |
| First-Class by Default | Resolution actions are first-class data, not embedded effects |
| Layered Architecture | Strata 0-2 + post-fixpoint sweep are composable layers |
| Decomplection | Separates effect description from effect execution |

**New principle to capture**: **Data Orientation** — prefer data
transformations over imperative control flow with embedded effects. Effects
become first-class descriptions, interpreted at explicit control boundaries.
This is the missing principle that unifies Propagator-First Infrastructure
(data over state), Layered Recovery (description over execution), and the
free monad pattern (algebra over side effects).

---

## §10. Phased Implementation Plan

Phase ordering reflects dependency structure: infrastructure cells first
(enabling propagator wiring), then resolution propagators, then elimination
of the legacy paths.

### Phase D.3: Capture Data Orientation Principle
Amend `DESIGN_PRINCIPLES.org` with the Data Orientation principle.

### Phase D.5: Performance Baseline
Before Phase 1 implementation, capture timing baseline:
`racket tools/run-affected-tests.rkt --all` to record per-file timings in
`data/benchmarks/timings.jsonl`. Compare after Phase 8 to verify no
regression from the architectural migration.

### Phase 1: Instance Registry — Cell Reader Infrastructure

**Key finding**: The instance registry cell *already exists*. Phase 2b of Track 1
created `current-impl-registry-cell-id` with `merge-hasheq-union`, seeded from
the parameter value at network initialization (`macros.rkt` line 515).
`register-impl!` dual-writes to BOTH the parameter AND the cell. All readers
use the parameter.

Phase 1 = add a cell reader, convert elaboration-time reads to use it,
establish `current-macros-prop-cell-read` callback. The parameter write stays
because it serves as the cross-command accumulator (prelude loading writes to
the parameter before any network exists; the parameter seeds the cell at each
`register-macros-cells!` call). Full dual-write elimination is deferred to a
later phase when cross-command state management is rearchitected.

#### Two Read Paths

Analysis during implementation revealed two distinct read contexts:

1. **Registration-time reads** (`lookup-impl`, `build-trait-constraint`,
   `maybe-register-trait-dict-def`): called during instance registration and
   constraint construction, where the parameter is the correct source. These
   are often called from unit tests that parameterize `current-impl-registry`
   without a full network. **Stay on parameter.**

2. **Elaboration-time reads** (`collect-available-instances`, `instances-of`,
   `satisfies?`): called during/after type checking to query the full registry.
   These benefit from seeing the cell's monotone accumulation. **Converted to
   `read-impl-registry`.**

3. **Cross-command state management** (LSP session save/restore, batch-worker
   snapshot, test fixture seeding): manage the parameter as a persistent
   accumulator across commands. **Stay on parameter.**

#### What Was Done

1. Added `current-macros-prop-cell-read` parameter in `macros.rkt` (parallel
   to existing `current-macros-prop-cell-write`), installed in `driver.rkt`
   with `elab-cell-read`.

2. Added `read-impl-registry` function: reads cell when network is available,
   falls back to parameter otherwise. Exported from `macros.rkt`.

3. Converted 4 elaboration-time read sites:
   - `trait-resolution.rkt` `collect-available-instances`: `(read-impl-registry)`
   - `driver.rkt` `instances-of` command: `(read-impl-registry)`
   - `driver.rkt` `satisfies?` command: `(read-impl-registry)`
   - `repl.rkt` `:instances` and `:satisfies` commands: `(read-impl-registry)`

4. `lookup-impl` and `build-trait-constraint` stay on the parameter — they
   are called in registration paths and unit test contexts where the parameter
   is authoritative.

5. LSP, batch-worker, and test fixture sites stay on the parameter — they
   manage cross-command state, not mid-elaboration queries.

#### What This Enables

With `read-impl-registry` available as the cell-authoritative reader:
- Phase 5 resolution propagators can read the registry cell directly
- The cell path is established for future phases to wire threshold propagators
  that watch for new instance registrations
- `save-meta-state`/`restore-meta-state!` already captures registry via the
  network snapshot (the cell was created in Track 1 Phase 2b)
- The registry is observable through the propagator network

### Phase 2: Constraint Status Cells

**Implementation** (commit `b4cdb1e`):

Single constraint-status-map cell (not per-constraint cells). Maps constraint-id → `'pending | 'resolved`.

1. **Constraint IDs**: Added `cid` field (first position) to constraint struct, gensym'd at creation in `add-constraint!`. Updated 4 direct constructor sites (1 production, 3 test).
2. **Merge function**: `merge-constraint-status-map` in `infra-cell.rkt` — per-key monotone merge where `'resolved` wins over `'pending`. Handles `'infra-bot` for initial state.
3. **Cell creation**: `enet9` in `reset-meta-store!` after hasmethod wakeup cell (enet8). Parameter: `current-constraint-status-cell-id`.
4. **Reader/writer**: `read-constraint-status-map` (standard pattern with fallback to `(hasheq)`) and `write-constraint-status-cell!` (writes single-entry hasheq delta).
5. **Dual-write sites**:
   - `add-constraint!`: writes `'pending` at creation
   - `unify.rkt` retry callback: writes `'resolved` on `solved` or `failed`
   - `retrying`/`postponed` transitions are NOT written to cell — these are transient re-entrancy guards that don't change the monotone status
6. **Wiring**: Added to `with-fresh-meta-env` parameterize, `reset-constraint-store!`, provide list.

**Key design choice**: `'resolved` covers both `'solved` and `'failed`. The cell lattice only needs to distinguish "needs work" from "terminal". The fine-grained status stays on the struct until Phase 3 eliminates the imperative retry chain. The cell's monotonicity means speculation rollback (via network snapshot restore) correctly reverts status transitions from failed branches.

### Phase 3: Stratified Quiescence Architecture

**Implementation** (commit `4c0c927`):

Split `solve-meta!` into `solve-meta-core!` (write only) + `run-stratified-resolution!` (flat loop).

1. **solve-meta-core!**: CHAMP write + cell write + P-U2b consistency check. No retry logic. Sets progress flag (via `current-stratified-progress-box`) when solving a meta during S2.
2. **run-stratified-resolution!**: Flat S0→S1+S2 loop:
   - S0: Run network to quiescence (type propagation)
   - S1+S2: Scan + retry ready constraints (`retry-constraints-via-cells!`), traits (`retry-traits-via-cells!` + `retry-trait-for-meta!`), hasmethods (`retry-hasmethod-for-meta!`)
   - Progress check: box flag set by nested `solve-meta-core!` calls
   - Repeat until no progress or fuel exhausted (100 iterations)
3. **Re-entrancy prevention**: `current-in-stratified-resolution?` parameter. When `#t`, `solve-meta!` calls only `solve-meta-core!` (no loop). The outer loop handles further rounds. Call stack is always flat.
4. **Test fallback**: When no propagator network exists (test contexts), uses `retry-constraints-for-meta!` instead of cell-state scan. Same stratified structure.

The `retrying` guard on constraint structs is now structurally dead code — re-entrancy is eliminated by the flag. Kept as safety net until Phase 4 removes the imperative retry chain entirely.

### Phase 4: Action Descriptors

**Implementation** (commit `e6aeafc`):

Separate S1 (readiness scan) from S2 (resolution commitment) using action descriptors.

1. **Descriptor structs**: `action-retry-constraint`, `action-resolve-trait`, `action-resolve-hasmethod` — transparent, data-only.
2. **S1 scan functions** (pure, return lists):
   - `collect-ready-constraints-via-cells` / `collect-ready-constraints-for-meta`
   - `collect-ready-traits-via-cells` / `collect-ready-traits-for-meta`
   - `collect-ready-hasmethods-for-meta`
3. **S2 interpreter**: `execute-resolution-action!` dispatches on descriptor type via `match`. Re-checks readiness before executing (actions can become stale when prior actions in the same batch solve shared metas — first discovered via "metavariable already solved" errors in `test-eq-let-surface-01.rkt`).
4. **Loop integration**: `run-stratified-resolution!` now does S0 (quiescence) → S1 (collect via `append`) → S2 (execute batch) → progress check → repeat.

The old fused scan+execute functions (`retry-constraints-via-cells!`, `retry-traits-via-cells!`, etc.) remain as legacy code — they're no longer called from the stratified loop but are still available for test fallback.

### Phase 5: Trait Resolution Propagators
- Add propagator edges from type-arg cells to trait resolution fire functions
- Resolution propagators also watch the instance registry cell
- Fires when type-args are ground AND matching instance exists in registry
- Produces `ResolveTraitDict` action descriptors

### Phase 6: HasMethod Resolution Propagators
- Same pattern as Phase 5 for hasmethod constraints
- Watches type-arg cells + instance registry cell + trait registry cell
- Replaces `resolve-hasmethod-constraints!` batch pass

### Phase 7: Error Cell + Grouped Error Reporting
- Add error descriptor cell (set-union merge, keyed on constraint ID —
  deduplicates across repeated propagator firings for the same constraint)
- Resolution propagators write error descriptors on failure/ambiguity;
  only write for constraints whose status cell is still `pending`
- Convert `check-unresolved-trait-constraints` to read error cell + sweep
  unsolved constraints in the post-fixpoint error sweep
- Implement HKT-7 ambiguity detection at resolution time

### Phase 8: Post-Pass Elimination
- Remove `resolve-hasmethod-constraints!` calls from `driver.rkt` (5 sites)
- Verify all resolution happens through propagators
- The post-fixpoint error sweep is the only remaining post-elaboration pass

### Phase 9: Confluence Verification
- **Prerequisite**: HKT-7 ambiguity detection (Phase 7) must be complete.
  Without ambiguity errors for same-specificity parametric instance ties,
  confluence tests would pass vacuously (silent first-match is deterministic
  but not for the right reason).
- **Randomized-order property tests**: shuffle the Stratum 2 ready set,
  resolve in shuffled order, assert same fixpoint. This surfaces any hidden
  ordering dependencies that the non-overlapping invariant should prevent.
- Verify non-overlapping instance invariant is enforced at registration time
- Ambiguity detection tests for HKT-7 edge cases (same-specificity ties,
  overlapping parametric patterns)

---

## §11. External Review Disposition (2026-03-13)

Design submitted for independent review. Reviewer had no full project context.
Disposition of each critique point:

| # | Critique | Verdict | Rationale |
|---|----------|---------|-----------|
| 1 | HKT-7 ambiguity as Phase 0 | **Partial accept** | HKT-7 noted as Phase 9 prerequisite; not blocking Phases 1-8. Non-overlapping policy means ambiguity is academic until pathological input. |
| 2 | Registry cell fallback window | **Reject** | Reviewer misunderstands lifecycle. Module loading → parameter; `register-macros-cells!` → seeds cell from parameter; elaboration → cell only. No window for lost instances. Same pattern as all 13 other registry cells, battle-tested across 5400+ tests. |
| 3 | Error cell duplicate descriptors | **Accept** | Changed error cell merge from list-append to set-union keyed on constraint ID. Resolution propagators also gate on `status = pending`. |
| 4 | Batch S2 hides ordering bugs | **Partial accept** | Randomized-order property tests added to Phase 9. Dedicated debug mode rejected — it tests a property guaranteed by non-overlapping instances, which the property tests already verify. |
| 5 | Phase 2/3 retrying removal timing | **Reject** | Reviewer inferred a sequencing we don't have. Phase 2 adds status cells *alongside* struct field; `retrying` stays until Phase 3 eliminates re-entrancy. Clarified in Phase 2 description. |
| 6 | Missing fuel limits / cycle detection | **Accept** | Fuel counter added to Phase 3 spec. The `retrying` guard is a local cycle breaker; the fuel counter is its global replacement. |
| 7 | Observatory integration | **Reject** | Observatory is future unbuilt infrastructure. Cells are observable by construction — no per-cell-type integration needed. Adding a phase for unbuilt dependencies violates Completeness Over Deferral in the wrong direction. |
| 8 | Performance baseline | **Accept** | Added D.5 (baseline capture before Phase 1) and note on Phase 8 (compare after migration). We already have `benchmark-tests.rkt` infrastructure. |
| 9 | Stratum vs Phase naming | **Reject** | "Stratum" matches Datalog literature; "Phase" is implementation steps. Renaming to "Layer" or "Stage" would conflict with Layered Recovery Principle terminology. |
| 10 | S3 is not a stratum | **Accept** | Renamed to "Post-Fixpoint Error Sweep" throughout. It runs after fixpoint, not as part of the stratified iteration. |
| 11 | Action descriptor struct detail | **Partial accept** | Deferred to Phase 4 implementation. Design doc intentionally stays conceptual; struct layouts emerge from code. |
| 12 | Observability table placement | **Accept** | Editorial improvement for a future pass. |

---

## §12. References

- Radul & Sussman, "The Art of the Propagator" (2009) — propagator substrate
- Kmett, "Propagators" (YOW! Lambda Jam 2016) — stratified non-monotone extension
- Kmett, propagators resource collection: https://gist.github.com/gwils/edb26e4b975c2438189f6414cdeb33b0
- Kuper & Newton, "LVars: Lattice-based Data Structures for Deterministic
  Parallelism" (2013) — threshold reads, determinism guarantee
- Hellerstein, "The CALM Theorem" (2011) — monotonicity ↔ coordination-freedom
- Bancilhon, "Semi-Naive Evaluation" (1986) — incremental fixpoint via delta tracking
- Apt, Blair & Walker, "Stratified Negation" (1988) — non-monotone operations via strata
- Katsumata, "Effect Quantales" (2014) — categorical grounding for stratified effects
- Swierstra, "Data Types a la Carte" (2008) — free monads for effect description
- GHC User's Guide, "Instance Resolution" — overlapping instances and coherence
  https://ghc.gitlab.haskell.org/ghc/doc/users_guide/exts/instances.html
- Kseo, "Avoid Overlapping Instances with Closed Type Families" (2017)
  https://kseo.github.io/posts/2017-02-05-avoid-overlapping-instances-with-closed-type-families.html
- Prologos `EFFECTFUL_COMPUTATION_ON_PROPAGATORS.org` — Layered Recovery Principle
- Prologos `DESIGN_PRINCIPLES.org` — Propagator-First Infrastructure, Correct by Construction
- Track 1 PIR: `2026-03-12_TRACK1_CELL_PRIMARY_PIR.md` — predecessor analysis
