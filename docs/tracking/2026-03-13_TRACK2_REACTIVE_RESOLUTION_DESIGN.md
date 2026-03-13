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
| D.1 | Design analysis and formal grounding | 🔄 | This document |
| D.2 | Principles capture (data orientation) | ⬜ | New DESIGN_PRINCIPLES section |
| 1 | Stratified quiescence architecture | ⬜ | |
| 2 | Data-oriented solve-meta! (action descriptors) | ⬜ | |
| 3 | Trait resolution propagators | ⬜ | |
| 4 | HasMethod resolution propagators | ⬜ | |
| 5 | Constraint status cells | ⬜ | |
| 6 | Registration-complete threshold | ⬜ | |
| 7 | Post-pass elimination | ⬜ | |
| 8 | Confluence verification | ⬜ | |

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

## §5. The Post-Pass: Elimination via Registration-Complete Threshold

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

### 5.2 The Registration-Complete Threshold

The post-pass isn't special because of its logic — it's special because of its
*timing*. It runs after all declarations have been processed, meaning all
instances are registered. The propagator equivalent of this timing is a
**threshold propagator** gated on a "registration complete" signal.

Architecture:

```
Registration-Complete Cell: starts at bot (false)
  Set to true when driver.rkt finishes processing all top-level declarations.

HasMethod Resolution Propagator:
  Inputs: [type-arg cells..., registration-complete cell]
  Threshold: all type-arg cells non-bot AND registration-complete = true
  Fire: perform hasmethod resolution (search traits, resolve dict)
```

The `net-add-barrier` primitive already exists in `propagator.rkt` for exactly
this pattern — a propagator that fires only when ALL conditions are met.

### 5.3 Implications for Error Handling

With a registration-complete threshold, the propagator fires exactly once per
hasmethod constraint, at the right time, with the full instance registry
available. Two outcomes:

1. **Resolution succeeds**: propagator solves the evidence meta. Done.
2. **Resolution fails**: the constraint remains unsolved.

Unsolved constraints after the registration-complete signal are **errors** —
not diagnostics, not "the reactive path missed something." If the full
instance registry is available and resolution still fails, the program is
ill-typed. This is a stronger guarantee than the current system, where the
post-pass silently leaves constraints unsolved and relies on
`check-unresolved-trait-constraints` to report them.

**The post-pass can be eliminated entirely.** The error-reporting pass
(`check-unresolved-trait-constraints`) remains, but it becomes: "after
registration-complete propagators have all fired and the network is quiescent,
any unsolved trait/hasmethod constraint is an error." No batch resolution
pass needed.

### 5.4 What Else the Post-Pass Position Touches

Beyond hasmethod resolution, the post-elaboration position in `driver.rkt`
does:
1. `check-unresolved-trait-constraints` — error reporting (stays)
2. `check-unresolved-capability-constraints` — error reporting (stays)
3. `zonk-final` — defaulting unsolved metas (orthogonal)
4. `rewrite-specializations` — optimization pass (orthogonal)

The error-reporting passes don't need to be propagator-driven — they're
read-only sweeps over cell state. The registration-complete signal just needs
to precede them.

### 5.5 Is the Registration-Complete Threshold Its Own Layer?

Yes — it naturally forms **Stratum 3** in the stratified architecture:

```
Stratum 0: Type Propagation (monotone)
Stratum 1: Readiness Detection (monotone)
Stratum 2: Resolution Commitment (non-monotone barrier)
  [Loop S0-S2 until fixpoint within elaboration]
Stratum 3: Registration-Complete Resolution (non-monotone barrier)
  [Fires once after all declarations processed]
Stratum 4: Error Reporting (read-only)
  [Sweeps unsolved constraints, reports errors]
```

Strata 0-2 operate *during* elaboration (the inner fixpoint loop). Stratum 3
fires *between* elaboration and evaluation (the outer pipeline). Stratum 4 is
the final error check.

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

Each constraint gets a **status cell** in the propagator network. The status
lattice:

```
    postponed
    /       \
retrying   resolved
    \       /
     failed
```

(Or simply: `bot → postponed → retrying → resolved/failed`, where resolved
and failed are top-like terminal states.)

Status transitions become cell writes:
- Creating a constraint writes `postponed`
- Retry attempt writes `retrying`
- Successful retry writes `resolved`
- Failed retry writes back `postponed` (or `failed` if terminal)

Benefits:
- **Speculation safety**: status captured by network snapshot
- **Observability**: observatory can show constraint lifecycle
- **Readiness propagation**: a propagator can watch the status cell and gate
  on `'postponed` (don't retry already-resolved constraints)
- **Confluence**: status transitions are monotone (information only grows)

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
| **Constraint status** | **Status cell** | **Track 2 Phase 5** |

This completes the vision of total network observability: the propagator
network is the single source of truth for the entire type-checking state.

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

## §8. Open Questions and Design Decisions

### 8.1 Granularity of Action Descriptors

How fine-grained should the resolution action descriptors be?

**Option A**: One action type per resolution kind:
- `RetryConstraint(constraint)`
- `ResolveTraitDict(dict-id, trait-constraint-info)`
- `ResolveHasMethod(meta-id, hasmethod-constraint-info)`
- `SolveMeta(meta-id, solution)`

**Option B**: A single `SolveMeta` action — all resolution logic runs in
Stratum 2 and produces only `SolveMeta` actions that feed back to Stratum 0.

Option A is more observable. Option B is simpler. The choice affects how much
of the resolution logic lives inside propagator fire functions (B) vs.
outside them in the interpreter (A).

### 8.2 Stratum 2 Execution Strategy

When multiple resolution actions are ready simultaneously, does the order
matter?

Under non-overlapping instances, resolution is confluent (§4.3), so order
doesn't matter. But:
- Should we commit all ready resolutions in one batch before re-entering S0?
- Or commit one at a time, re-entering S0 after each?

Batch commitment is more efficient (one S0 quiescence pass for N resolutions).
Single commitment is more conservative (each resolution sees the latest type
information). Under confluence, both produce the same result — so batch is
preferred for performance.

### 8.3 Ambiguity Detection Timing

The HKT-7 ambiguity error (multiple same-specificity matches) should be
detected and reported. When?

- **At resolution time** (Stratum 2): detect during parametric resolution,
  produce an error action descriptor
- **At error-reporting time** (Stratum 4): sweep unsolved constraints, detect
  ambiguity as a sub-case of "no resolution found"

Resolution-time detection is more immediate and provides better error
messages ("ambiguous: these two instances both match" vs. "no instance found").

### 8.4 Incremental Instance Registration

Should instance registration itself be a cell write?

Currently, `process-impl` writes to mutable hash tables (`current-impl-registry`).
Making instance registration a cell write would:
- Allow propagators to react to new instances (resolution retries on registration)
- Eliminate the need for a registration-complete threshold (propagators fire
  incrementally as instances become available)
- But: require careful handling of registration order and partial state

This is an advanced extension — the registration-complete threshold is simpler
and more conservative for the initial implementation.

### 8.5 Constraint Status Lattice Shape

Is the status lattice `bot → postponed → retrying → resolved` the right shape?

Alternative: a two-element lattice `pending | resolved`. The `retrying`
status is a re-entrancy guard for the current imperative loop — with
stratified quiescence and data-oriented resolution, re-entrancy is eliminated,
so the guard may not be needed.

The simpler lattice would be: `pending → resolved`, where `pending` means
"not yet resolved" and `resolved` means "solution committed." Failed
resolution would leave the constraint as `pending` (it never resolves) and
the error pass detects it.

---

## §9. Relationship to Existing Principles

This design extends and concretizes several principles from
`DESIGN_PRINCIPLES.org`:

| Principle | How Track 2 Applies It |
|-----------|----------------------|
| Correct by Construction | Stratification makes confluence structural, not contingent |
| Propagator-First Infrastructure | Constraint status → cells; resolution → propagators |
| First-Class by Default | Resolution actions are first-class data, not embedded effects |
| Layered Architecture | Strata 0-4 are composable layers |
| Decomplection | Separates effect description from effect execution |

**New principle to capture**: **Data Orientation** — prefer data
transformations over imperative control flow with embedded effects. Effects
become first-class descriptions, interpreted at explicit control boundaries.
This is the missing principle that unifies Propagator-First Infrastructure
(data over state), Layered Recovery (description over execution), and the
free monad pattern (algebra over side effects).

---

## §10. Phased Implementation Sketch

Pending design iteration, the rough phase structure:

1. **Capture data orientation as a design principle** (amend DESIGN_PRINCIPLES.org)
2. **Stratified quiescence loop** — modify `solve-meta!` to use a
   two-phase loop: network quiescence (S0) then readiness scan (S1)
3. **Action descriptors** — make resolution produce data instead of effects
4. **Trait resolution propagators** — add propagator edges from type-arg
   cells to trait resolution fire functions
5. **Constraint status cells** — migrate `set-constraint-status!` to cell writes
6. **Registration-complete threshold** — add registration cell, gate hasmethod
   resolution propagators on it
7. **Hasmethod resolution propagators** — replace `resolve-hasmethod-constraints!`
8. **Post-pass elimination** — remove `resolve-hasmethod-constraints!` calls from
   `driver.rkt`; verify all resolution happens via propagators
9. **Confluence testing** — property-based tests verifying resolution order
   independence
10. **Ambiguity detection** — implement HKT-7 proper ambiguity errors

---

## §11. References

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
