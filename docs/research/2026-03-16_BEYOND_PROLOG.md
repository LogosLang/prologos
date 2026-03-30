- [1. Introduction and Motivation](#orgc3f478b)
- [2. Mode Prefixes &#x2014; From Annotations to Optimisation Engine](#org10df6cc)
  - [Current State](#org8e688b8)
  - [Mercury's Mode System: The Gold Standard](#orgc75044a)
  - [How Modes Enable Optimisation in Prologos](#org2db8d3d)
    - [Argument Indexing](#orged0fd77)
    - [Goal Reordering](#orgc4d2295)
    - [Determinism Inference](#org0c83c12)
    - [Compile-Time Mode Checking](#org632c8ef)
    - [Propagator Cell Selection](#orgfebbc0b)
  - [Future: Surface-Level Determinism Annotations](#orgc9ae77e)
  - [Connection to Abstract Interpretation](#org37a497a)
- [3. Domain Constraints &#x2014; From Types to Constraint Domains](#org21a96a5)
  - [Current Design](#orgdf8496f)
  - [The Key Insight: A Type IS a Constraint Domain](#org0175f30)
  - [CLP(L): Constraint Logic Programming over Any Lattice](#org857dbf7)
  - [The Elaboration Bridge](#org5a17f7c)
  - [Widening for Infinite-Height Lattices](#orgaec8388)
  - [Generalisation and Composition](#org19d6c60)
  - [Surface Syntax](#orge2b1d20)
- [4. Coinduction and Greatest Fixed Points](#org90688f2)
  - [4.1 LFP vs GFP in Logic Programming](#org04b47e1)
  - [4.2 What Coinduction Buys Us](#org5c2b5f9)
  - [4.3 co-SLD and Coinductive Logic Programming](#org1337121)
  - [4.4 Surface Syntax](#orgdb59044)
  - [4.5 Implementation via Propagators](#orgb80ddab)
- [5. Rule Learning and Inductive Logic Programming](#org9cc7336)
  - [5.1 The Vision](#org479fd72)
  - [5.2 Modern ILP Systems](#org9e6c17c)
  - [5.3 Surface Syntax for Rule Learning](#orge00ba65)
  - [5.4 Mapping to the Propagator Architecture](#org19616d2)
  - [5.5 Predicate Invention as Metavariable Solving](#org0d077c4)
  - [5.6 Differentiable ILP and Neural-Symbolic Integration](#orgfefbbca)
  - [5.7 `learn` as Dual of `defr`](#org2925c9f)
- [6. Probabilistic and Weighted Logic Programming](#orgbfa2e8a)
  - [6.1 The Semiring Abstraction](#org3ee4ccc)
  - [6.2 Surface Syntax: The `^Weight` Annotation](#org1a16df8)
  - [6.3 Probabilistic Propagators](#orgf99c0f8)
  - [6.4 The Distributional Lattice](#org6f23976)
  - [6.5 Tropical Semiring and Optimization](#orge82a4a0)
  - [6.6 Composing Probability with Other Features](#orgcdf2527)
  - [6.7 Implementation Roadmap](#orge3ac96a)
- [7. Category Theory &#x2014; New Mathematical Structures for Logic Programming](#org00a8fb0)
  - [7.1 Propagator Networks as Enriched Categories](#org15b268d)
  - [7.2 Sheaves and Local-to-Global Reasoning](#org9be7ae0)
  - [7.3 Fibered Categories and Dependent Types in LP](#orgfb2308e)
  - [7.4 Profunctors as Generalized Relations](#orgdb4c3b7)
  - [7.5 Kan Extensions and Query Optimization](#orgf392b98)
  - [7.6 Quantales: Beyond Lattices](#orgc26748e)
  - [7.7 Galois Connections and Abstract Interpretation](#orgac6c6fe)
- [8. The Frontier &#x2014; What No Existing System Has](#orge9e5a15)
  - [8.1 The Quantale-Parameterized Logic Engine](#orgf898417)
  - [8.2 Coinductive-Probabilistic-Dependent Relations](#org85e1966)
  - [8.3 Sheaf-Theoretic Distributed Reasoning](#org004b256)
  - [8.4 The Egglog Connection](#org722db4e)
  - [8.5 Learn as Dual of Defr](#org8c0cbd8)



<a id="orgc3f478b"></a>

# 1. Introduction and Motivation

Prologos's relational sublanguage is, at its current stage, a well-typed port of Prolog augmented with two features that most logic programming systems lack: SLG-style tabling and propagator-network-based execution over persistent, CHAMP-backed immutable data structures. Relations are defined with `defr` and `rel`, rule clauses are introduced by `&>`, fact blocks by `||`, and variables carry mode prefixes (`+var` for input, `-var` for output, `?var` for free). A configurable solver supports strategy selection, threshold tuning, tabling policy, provenance tracking, and timeouts. The propagator network is fully persistent: every cell write produces a new network via structural sharing, enabling speculative execution and backtracking without mutation.

This is a solid foundation. But it is also, fundamentally, conservative. The mode prefixes are parsed and stored in `param-info` structs but ignored by the solver at runtime &#x2014; every argument is searched linearly regardless of binding state. The planned `?var:Type` domain constraint syntax is designed but unimplemented. The solver uses DFS backtracking, which is correct but leaves enormous optimisation potential on the table. Tabling prevents infinite loops in recursive relations but does not exploit the richer structure that dependent types and the lattice trait system make available.

Prologos is not merely a Prolog. It is a language where types are first-class, where linearity is tracked by QTT, where session types govern protocol conformance, and where a lattice trait hierarchy provides abstract interpretation infrastructure as a library. These features, taken together, open doors that traditional logic programming never had access to.

This document explores six such doors &#x2014; frontiers where the existing infrastructure, extended with targeted new machinery, could produce capabilities that go well beyond what Prolog, Mercury, or even modern CLP systems offer:

1.  **Mode prefixes &#x2014; from annotations to optimisation engine.** The `+/-/?` annotations already live in the AST. Mercury demonstrated decades ago that mode and determinism information can yield order-of-magnitude speedups over Prolog. We examine how to activate these annotations: argument indexing, goal reordering, determinism inference, compile-time mode checking, and directional propagator cell selection.

2.  **Domain constraints &#x2014; from types to constraint domains.** The planned `?var:Type` syntax is not mere syntactic sugar for typing logic variables. A type that implements `Lattice` *is* a constraint domain. This insight collapses the distinction between type annotation and CLP domain declaration, yielding `CLP(L)` for any lattice `L` &#x2014; a parameterised constraint logic programming framework where the trait system serves as the plugin API.

3.  **Coinduction and greatest fixed points.** Standard Prolog computes least fixed points; coinduction computes greatest fixed points, enabling reasoning about infinite structures, bisimulation, and liveness properties. The tabling infrastructure (SLG resolution) is already halfway to coinductive tabling.

4.  **Rule learning and inductive reasoning.** Given ground facts and a hypothesis space, can the relational engine learn new rules? Inductive Logic Programming (ILP) has a long history, but Prologos's dependent types provide a novel mechanism for constraining the hypothesis space via type-directed search.

5.  **Probabilistic and weighted logic programming.** Extending relations with weights or probability distributions enables statistical relational learning, Bayesian inference, and soft constraint satisfaction. The provenance system (already configurable in `solver-config`) provides the accounting infrastructure.

6.  **Category-theoretic foundations for novel logical constructs.** Dependent types give us access to categorical semantics. Kan extensions, adjunctions, and profunctors have computational content that maps onto logic programming patterns in ways that are only beginning to be explored.

Each section is self-contained but builds on the same architectural substrate: the propagator network as execution engine, the lattice trait system as abstraction mechanism, and the dependent type system as static guarantor. The goal is not to propose a development roadmap (that belongs in tracking documents) but to map the intellectual landscape &#x2014; to understand what becomes *possible* when a logic programming engine is embedded in a language of this richness.


<a id="org10df6cc"></a>

# 2. Mode Prefixes &#x2014; From Annotations to Optimisation Engine


<a id="org8e688b8"></a>

## Current State

Prologos parses mode prefixes on relational parameters and stores them in `param-info` structs (defined in `relations.rkt`):

```racket
(struct param-info (name mode) #:transparent)
;; mode: 'free | 'in | 'out
```

When a `defr` form is elaborated, each parameter's mode annotation (`+`, `-`, or `?`) is preserved through the AST pipeline into the runtime `variant-info`:

```racket
(param-info (expr-logic-var-name p)
            (or (expr-logic-var-mode p) 'free))
```

But that is where the story ends. The solver's DFS backtracking engine treats every parameter identically: it attempts unification against each clause in declaration order, regardless of which arguments are ground, which are free, and which pattern of bindings the caller provides. The mode information is dead weight &#x2014; parsed, stored, and ignored.

This is the gap between Prolog and Mercury.


<a id="orgc75044a"></a>

## Mercury's Mode System: The Gold Standard

Mercury, developed by Somogyi, Henderson, and Conway at the University of Melbourne, demonstrated that mode and determinism information can transform logic programming performance. Mercury's mode system classifies each predicate call into determinism categories:

-   `det`: exactly one solution, no choice points
-   `semidet`: zero or one solution
-   `multi`: one or more solutions (at least one)
-   `nondet`: zero or more solutions
-   `failure`: no solutions (always fails)
-   `cc_multi` / `cc_nondet`: committed-choice variants (first solution only)

These categories are not merely documentation. Mercury uses them to:

1.  **Statically reorder conjunctions** so that goals binding variables are scheduled before goals consuming those bindings.
2.  **Select indexing strategies** &#x2014; a `det` predicate with a ground first argument can use hash-based indexing instead of linear search.
3.  **Eliminate choice points** entirely for `det` and `semidet` predicates, avoiding the overhead of backtracking bookkeeping.
4.  **Compile to direct calls** when determinism is known, bypassing the search machinery.

The result: Mercury benchmarks show performance that is significantly faster than mature Prolog implementations (SICStus, SWI, YAP) on equivalent programs. The speedup comes not from cleverer unification or faster term representation but from *not doing unnecessary search*.


<a id="org2db8d3d"></a>

## How Modes Enable Optimisation in Prologos

Prologos can exploit mode information at multiple levels, each building on the previous:


<a id="orged0fd77"></a>

### Argument Indexing

When a parameter is marked `+` (input), the solver knows it will be ground at the call site. Ground arguments can be *indexed*: rather than scanning all clauses linearly, the solver can hash on the first ground argument and jump directly to matching clauses. This is the single highest-impact optimisation in Prolog compilers (WAM first-argument indexing), and Prologos currently lacks it entirely.

For a relation with *n* clauses, linear search is O(n) per call. Hash-based indexing on a `+` argument reduces this to amortised O(1). For fact tables &#x2014; which Prologos already stores separately as `fact-row` lists &#x2014; this transformation is straightforward: build a hash map keyed on the indexed argument positions at registration time.


<a id="orgc4d2295"></a>

### Goal Reordering

The constraint-programming insight is: *schedule the most constrained goals first*. In a conjunction of goals, those with more `+` (ground) arguments are more constrained &#x2014; they have smaller search spaces. The solver should execute these first, binding variables that subsequent goals can then use as inputs.

Currently, Prologos executes goals in declaration order. With mode information, the solver can statically reorder a conjunction:

```prologos
defr path [+from -to]
  &> (edge from ?mid)     ;; from is +, mid is ?: semi-constrained
     (path ?mid to)        ;; mid now bound from edge: effectively + -
```

Here the declaration order happens to be optimal. But in general, the programmer may write goals in a logical order that is not the best execution order. Mode analysis enables automatic reordering without changing semantics.


<a id="org0c83c12"></a>

### Determinism Inference

A relation where all parameters are `+` and exactly one clause matches is `det`: it produces exactly one answer with no backtracking. The solver can compile such a call to a direct Racket function call, bypassing the entire search infrastructure (no choice points, no trailing, no worklist management).

More subtly, a relation with `n` clauses whose first `+` argument has `n` distinct constant patterns is also `det` under first-argument indexing &#x2014; each call matches at most one clause.

Determinism inference composes with tabling: a tabled relation that is `det` on its input pattern needs only a memo table, not the full SLG completion machinery.


<a id="org632c8ef"></a>

### Compile-Time Mode Checking

With modes as part of the type signature, the elaborator can verify at compile time that `+` arguments are ground at every call site. This catches a class of bugs &#x2014; "instantiation errors" in Prolog terminology &#x2014; before runtime:

```prologos
defr lookup [+key -val] :det
  &> (table key val)

;; Compile error: 'key' is not ground at call site
;; query (lookup ?k ?v)   ;; ?k has mode +, but is free here
```

This is a strict improvement over Prolog, where instantiation errors surface only at runtime (and often deep in a search tree).


<a id="orgfebbc0b"></a>

### Propagator Cell Selection

The propagator network does not inherently know which cells are inputs and which are outputs. Mode annotations provide this information directly: `+` cells are populated by the caller and should trigger forward propagation; `-` cells are targets for narrowing and should receive propagated values. This enables *directional propagation* strategies that avoid wasted work &#x2014; an output cell does not need to fire propagators back towards already-ground input cells.


<a id="orgc9ae77e"></a>

## Future: Surface-Level Determinism Annotations

The natural next step is to expose Mercury-style determinism categories as surface syntax:

```prologos
defr lookup [+key -val] :det
  &> (table key val)

defr member [+elem +list] :semidet
  &> (match list
       (cons elem _) => true
       (cons _ ?rest) => (member elem ?rest))

defr append [-x -y +z] :multi
  &> ...
```

The `:det`, `:semidet`, `:multi`, and `:nondet` annotations serve both as documentation and as checked contracts: the compiler infers the determinism from mode analysis and clause structure, then verifies it matches the declared category. A mismatch is a compile-time error.


<a id="org37a497a"></a>

## Connection to Abstract Interpretation

There is a deeper theoretical point here. Modes are an *abstract domain* over the binding states of logic variables. The concrete domain is the set of all possible binding states (ground, free, partially instantiated, etc.). The abstract domain is the three-point lattice `+/-/?`:

-   `+` (input / ground): the variable is bound to a value.
-   `-` (output): the variable is free but will be bound by this relation.
-   `?` (free): the variable's binding state is unknown.

The abstraction function maps a concrete binding state to its mode; the concretisation function maps a mode to the set of concrete states it represents. This pair forms a Galois connection:

```
concrete: { ground, free, partial-struct, ... }
    α ↕ γ
abstract: { + , - , ? }
```

Mode inference *is* abstract interpretation over this lattice. A fixed-point computation propagates mode information through the call graph until it stabilises. This is exactly what Prologos's propagator network is designed to compute &#x2014; fixed points of monotone functions over lattices.

The implication is striking: mode inference can be implemented *as a Prologos program* using the propagator network, with each relation's mode signature as a cell and each call site as a propagator. The language analyses itself using its own execution model. This self-hosting property is a strong signal that modes are not an ad hoc annotation but a natural part of the language's semantic framework.


<a id="org21a96a5"></a>

# 3. Domain Constraints &#x2014; From Types to Constraint Domains


<a id="orgdf8496f"></a>

## Current Design

The `?var:Type` syntax is planned as an extension of the mode prefix system. Where `?x` declares a free logic variable, `?x:Interval` would declare a free logic variable whose domain is the `Interval` type. The parser is designed to accept this syntax (the `:Type` suffix is a natural extension of the existing `?var` prefix), but the elaborator does not yet process domain annotations.

At first glance this appears to be syntactic sugar &#x2014; a convenience for adding type annotations to logic variables. It is far more than that.


<a id="org0175f30"></a>

## The Key Insight: A Type IS a Constraint Domain

Consider what it means for a type to implement the `Lattice` trait in Prologos. A type `L` with a `Lattice` instance provides:

-   `bot`: the bottom element (least information / unconstrained)
-   `join`: the merge operation (combine two pieces of information)
-   A partial order where `join` is monotone

Now consider what a constraint domain is in the CLP (Constraint Logic Programming) tradition. CLP(X) parameterises logic programming by a constraint domain X, which provides:

-   A set of values (the domain)
-   Constraint operations that narrow the domain
-   A test for satisfiability (non-empty domain)

The parallel is exact. A `Lattice` instance *is* a constraint domain. The `bot` element represents the unconstrained state. The `join` operation merges constraints. A contradiction (the `top` element or an empty set) signals unsatisfiability. The propagator network already computes fixed points over lattice-valued cells.

This means that `?x:Interval` is not a type annotation. It is a *constraint domain declaration*. It tells the solver: "Create a propagator cell for `x` whose merge function is `Interval`'s `join`, whose initial value is `Interval`'s `bot` (the full interval `[-inf, +inf]`), and whose contradiction test is `Interval`'s emptiness check."


<a id="org857dbf7"></a>

## CLP(L): Constraint Logic Programming over Any Lattice

Traditional CLP systems are parameterised by specific, hardcoded domains:

-   **CLP(FD)**: Finite domain constraints, as in SICStus Prolog's `clpfd` library or SWI-Prolog's `clpz`. Variables range over finite integer sets. Constraints like `X in 1..10`, `X #\` Y=, and `all_different` narrow domains via arc consistency.
-   **CLP(R)** / **CLP(Q)**: Real or rational number constraints. Variables range over numeric intervals. Linear arithmetic constraints are solved via simplex.
-   **CLP(B)**: Boolean constraints. Variables are 0/1. Constraints are propositional formulas solved via BDDs or SAT.
-   **CLP(Sets)**: Set constraints. Variables range over sets. Constraints include membership, subset, intersection.

Each of these is implemented as a separate library with its own solver, its own data structures, and its own integration hooks. Mixing domains (e.g., using finite-domain constraints alongside interval constraints in the same query) requires explicit bridging code.

Prologos's architecture collapses this tower. Instead of `CLP(FD)`, `CLP(R)`, `CLP(B)`, and `CLP(Sets)` as separate systems, we have `CLP(L)` for any type `L` implementing `Lattice`. The trait system is the plugin API:

-   `?x:FlatVal[Nat]` gives flat-lattice behaviour: a variable is either unconstrained or bound to a single value, with contradiction on conflicting bindings. This is classical Prolog-style unification, recast as a lattice operation.
-   `?x:SetOf[Nat]` gives powerset-lattice behaviour: the variable ranges over a set of possible natural numbers. Constraints narrow the set. Emptiness is contradiction.
-   `?x:Interval` gives interval-lattice behaviour: the variable ranges over a numeric interval. Constraints narrow the interval. An empty interval is contradiction.
-   `?x:FD[1..100]` (with appropriate `FD` type) gives finite-domain behaviour.

The programmer does not need to import a separate CLP library or learn a separate constraint syntax. They annotate a variable with a type, and the type's `Lattice` instance determines the constraint semantics. New constraint domains are added by implementing a trait, not by modifying the solver.


<a id="org5a17f7c"></a>

## The Elaboration Bridge

When the elaborator encounters `?x:Interval` in a relational parameter, the following sequence occurs:

1.  **Cell creation.** A propagator cell is created in the network with `Interval`'s lattice `join` as its merge function and `Interval`'s `bot` (the full interval `[-inf, +inf]`) as its initial value.

2.  **Contradiction registration.** The cell's contradiction function is set to `Interval`'s emptiness check: a cell is contradictory when its interval has been narrowed to the empty set.

3.  **Propagation.** Constraint goals in the relation body (e.g., `(end is [interval-add start [interval-const duration]])`) become propagators attached to the relevant cells. When an input cell's interval narrows, the propagator fires and computes a new interval for the output cell. The merge function incorporates this new information monotonically.

4.  **Quiescence.** The network runs to quiescence. If no contradiction is detected, the cells' final values represent the tightest intervals consistent with all constraints. If a contradiction is detected, the solver backtracks (or reports failure).

This is already how the propagator network operates for its existing use cases. The domain constraint feature requires no new execution machinery &#x2014; only a new elaboration path that connects the `:Type` annotation to cell initialisation parameters.

The existing `prop-network` struct already carries per-cell merge functions (`merge-fns`) and contradiction functions (`contradiction-fns`) as CHAMP maps. The infrastructure is in place; the elaboration bridge wires it to the surface syntax.


<a id="orgaec8388"></a>

## Widening for Infinite-Height Lattices

Not all lattices have finite height. The `Interval` lattice, for example, admits infinite ascending chains: `[0, 100] ⊑ [0, 50] ⊑ [0, 25] ⊑ ...` converges, but `[0, 1] ⊑ [0, 2] ⊑ [0, 3] ⊑ ...` diverges. Without intervention, the propagator network would iterate forever.

The standard solution from abstract interpretation is *widening*: a binary operator ∇ that accelerates convergence by overshooting. Critically, Prologos's propagator network already has widening support. Phase 6a introduced:

-   `net-set-widen-point`: designate a cell as a widening point
-   `net-new-cell-widen`: create a cell with an associated widening function
-   `net-cell-write-widen`: write to a cell with widening applied
-   `run-to-quiescence-widen`: a scheduler variant that applies widening at designated cells

When a domain constraint uses an infinite-height lattice, the elaborator designates the cell as a widening point and attaches the lattice's widening operator. The existing `run-to-quiescence-widen` scheduler then handles convergence automatically. No new machinery is needed.


<a id="org19d6c60"></a>

## Generalisation and Composition

The `CLP(L)` approach generalises naturally in several directions:

**Product domains.** A relation with `?x:Interval` and `?y:SetOf[Nat]` uses two different constraint domains simultaneously, with no special bridging. Each cell has its own merge function; the propagator network handles heterogeneous lattices natively. The existing cross-domain propagation support (Phase 6c, `net-add-cross-domain-propagator`) enables propagators that read from an Interval cell and write to a SetOf cell, or vice versa.

**Derived domains.** A type like `SignedInterval` (extending `Interval` with sign tracking) can implement `Lattice` with a more refined merge, gaining the precision benefits of a richer domain without any changes to the solver.

**User-defined domains.** Because `Lattice` is a trait, users can define custom constraint domains for their specific problem. A scheduling application might define a `TimeSlot` lattice; a compiler might define a `RegisterSet` lattice. Each participates in CLP(L) automatically.


<a id="orge2b1d20"></a>

## Surface Syntax

The proposed surface syntax integrates domain constraints seamlessly into existing relational definitions:

```prologos
defr schedule [?task:String ?start:Interval ?end:Interval ?duration:Nat]
  &> (end is [interval-add start [interval-const duration]])
     (no-overlap task start end)

defr colour-map [?region:String ?colour:FD]
  &> (colour in '[red green blue yellow])
     (adjacent region ?neighbour)
     (colour-map ?neighbour ?neighbour-colour)
     (colour neq ?neighbour-colour)

defr type-check [+expr -type:SetOf[Type]]
  &> (infer-candidates expr type)
     (filter-by-context expr type)
```

In the scheduling example, `?start:Interval` and `?end:Interval` declare interval-domain variables. The constraint `(end is [interval-add start [interval-const duration]])` becomes a propagator relating the three cells. The `no-overlap` sub-goal adds further interval constraints. The solver runs the propagator network to quiescence, narrowing the intervals until either a solution is found or a contradiction is detected.

In the graph colouring example, `?colour:FD` declares a finite-domain variable. The `in` constraint initialises its domain; `neq` narrows it. This is textbook CLP(FD), but expressed using the same trait-based machinery as every other constraint domain.

In the type-checking example, `type:SetOf[Type]` declares a set-valued logic variable. The type-checker relation narrows the candidate set via constraints. This is a natural encoding of type inference as constraint solving &#x2014; an approach that connects the relational sublanguage to the type-checking pipeline itself.

The domain constraint feature, when realised, will transform Prologos's relational sublanguage from "Prolog with propagators" into a general-purpose constraint programming framework &#x2014; one where the trait system provides unlimited extensibility and the propagator network provides the execution model.


<a id="org90688f2"></a>

# 4. Coinduction and Greatest Fixed Points


<a id="org04b47e1"></a>

## 4.1 LFP vs GFP in Logic Programming

Traditional logic programming languages &#x2014; Prolog, Datalog, and their descendants &#x2014; operate under least fixed point (LFP) semantics. The meaning of a program is the smallest set of facts that is closed under the rules. Computation starts from the empty set and applies rules iteratively until no new facts can be derived. This is induction: we build up from base cases, and every derivation must eventually bottom out in a fact.

Coinduction inverts this perspective. The greatest fixed point (GFP) starts from the universal set of all possible facts and removes those that are inconsistent with the rules. What remains is the largest set of facts that the rules cannot refute. This is the world of codata &#x2014; potentially infinite structures that are well-defined not because they have base cases, but because they are *productive*: every observation yields a result in finite time.

Prologos's propagator network already computes to quiescence &#x2014; the network fires propagators until no cell changes, at which point a fixed point has been reached. The question is: which fixed point? The answer, drawing on lattice-propagator research, reveals a nested structure. **Propagation to quiescence computes the greatest post-fixpoint of the propagator equations.** Each propagator monotonically narrows cell values within the lattice, and quiescence is reached when no further narrowing is possible &#x2014; this is GFP over the lattice ordering. Simplification rules (non-monotonic operations that remove constraints or replace them with simpler forms) use LFP semantics: they fire only when their preconditions are stably met and produce the least change necessary. The overall computation therefore has a nested fixpoint structure: an outer LFP for simplification wrapping an inner GFP for propagation, analogous to the stratified negation of Datalog or the alternating fixpoints of the well-founded semantics.

This nested structure is not an accident of implementation. It reflects a fundamental duality: *building up* (induction, simplification, LFP) and *narrowing down* (coinduction, propagation, GFP) are complementary modes of computation. Prologos's architecture supports both natively.


<a id="org5c2b5f9"></a>

## 4.2 What Coinduction Buys Us

Coinduction opens the door to a range of programming patterns that are awkward or impossible under pure inductive semantics:

-   **Infinite and circular data structures.** Streams, infinite trees, and cyclic graphs are naturally coinductive. A stream is not defined by its base case (there is none) but by the observation that taking its head produces a value and taking its tail produces another stream. In a purely inductive setting, defining `ones = scons 1 ones` is a non-terminating loop. Under coinductive semantics, it is a perfectly well-defined productive codata value.

-   **Bisimulation.** Two processes are bisimilar if every transition of one can be matched step-by-step by the other. Bisimulation is the canonical coinductive relation: it is the greatest relation satisfying the simulation property. Checking bisimulation requires GFP reasoning &#x2014; assuming two states are equivalent and checking that no observation can distinguish them.

-   **Session type duality.** Prologos already defines session type duality coinductively: `dual(send A S) = recv A (dual S)` is not constructed from base cases but defined by mutual observation. The dual of a protocol is the protocol that, at every step, does the opposite. This is inherently coinductive and already present in the type system.

-   **Lazy and productive relations.** A coinductive relation can generate an infinite stream of answers, producing them on demand. Rather than computing all solutions and returning a finite set (LFP), a coinductive query produces answers lazily, one at a time, as the consumer requests them.

-   **Verification of reactive systems.** A server that responds to requests forever satisfies its specification coinductively. We cannot prove by induction that it handles all requests (there are infinitely many), but we can prove coinductively that it handles *each* request correctly and then continues operating.


<a id="org1337121"></a>

## 4.3 co-SLD and Coinductive Logic Programming

Gupta, Bansal, and others developed coinductive logic programming (coLP) as an extension of standard SLD resolution. The key idea is a *coinductive hypothesis rule*: if a goal `G` appears in its own derivation &#x2014; that is, the proof tree is circular &#x2014; then `G` is accepted as proven, provided the circularity is *guarded* (passes through at least one coinductive predicate). This is the proof- theoretic analog of the greatest fixed point: the circular proof witnesses membership in the GFP.

Ancona, Dagnino, and Zucca extended this with *flexible coinduction*: coclauses that allow fine-grained control over the interpretation of individual predicates. Not every predicate needs to be fully inductive or fully coinductive. A relation might be inductive in some arguments and coinductive in others, or individual clauses might carry different interpretations. This flexibility is essential for real programs where inductive and coinductive reasoning intermingle.

In Prologos, we propose that a `defr` can be annotated `:coinductive` to signal that the relation uses GFP semantics. More fine-grained control is also possible: individual clauses could be marked coinductive while others remain inductive.


<a id="orgdb59044"></a>

## 4.4 Surface Syntax

```prologos
;; Coinductive stream membership
defr member-stream [?x ?stream] :coinductive
  &> (= stream [scons x _])
  &> (= stream [scons _ rest]) (member-stream x rest)

;; Bisimulation checking
defr bisimilar [?p ?q] :coinductive
  &> (forall-transitions p (fn [a p']
       (exists-transition q a (fn [q']
         (bisimilar p' q')))))
```

The `:coinductive` annotation changes the resolution strategy for the relation. When `member-stream` encounters a cycle (e.g., checking membership in an infinite stream), it treats the cycle as success rather than failure. The `bisimilar` relation is the textbook coinductive definition: two processes are bisimilar if every transition of one can be matched by the other, recursing coinductively.


<a id="orgb80ddab"></a>

## 4.5 Implementation via Propagators

The propagator architecture provides a natural substrate for coinductive computation:

-   **Coinductive tabling.** Standard tabling (memoization of relation results) detects loops and treats them as failure &#x2014; the LFP interpretation. Coinductive tabling inverts this: loops are treated as success. When a goal is encountered that is already on the call stack, instead of failing or suspending, we provisionally assume it holds and check whether this assumption leads to contradiction.

-   **ATMS integration.** The Assumption-based Truth Maintenance System planned for Phase 5 provides exactly the machinery needed for coinductive hypotheses. Each coinductive assumption (\`\`this goal holds'') is recorded as an ATMS assumption. If the assumption leads to no contradiction (no nogood is derived), the assumption is valid and the coinductive proof succeeds. If a nogood is derived, the assumption is retracted and the goal fails. This is precisely the proof-theoretic characterization of GFP: accept unless contradicted.

-   **Lattice duality.** In the GFP interpretation, computation starts at the top of the lattice (all information, all facts assumed true) and narrows downward by removing contradictions. This is dual to the LFP approach (start at bottom, add information). In the propagator network, supporting GFP means initializing cells at `top` rather than `bot` for coinductive relations, then allowing propagators to narrow toward consistency. The merge operation, already defined on every lattice in Prologos, works in both directions: merging toward `bot` (adding information, LFP) and merging toward `top` (removing contradiction, GFP) are both monotonic with respect to the information ordering.

The nested fixpoint structure &#x2014; outer LFP for simplification, inner GFP for propagation &#x2014; means that coinductive reasoning is not a bolt-on extension but a natural consequence of the existing architecture. The propagator network already computes GFP; making it accessible at the language level requires only the annotation machinery and the tabling strategy switch.


<a id="org9cc7336"></a>

# 5. Rule Learning and Inductive Logic Programming


<a id="org479fd72"></a>

## 5.1 The Vision

Consider the standard way to define a relation in Prologos: the programmer writes `defr ancestor [?x ?y] &> (parent x z) (ancestor z y)`, encoding domain knowledge as explicit clauses. This is the deductive direction &#x2014; from rules to consequences.

Inductive Logic Programming (ILP) inverts the direction. The programmer provides positive examples (facts that should hold), negative examples (facts that should not hold), and background knowledge (existing relations). The system synthesizes rules that entail the positive examples, are consistent with the negative examples, and use the background knowledge as building blocks. This is the inductive direction &#x2014; from examples to rules.

The promise for Prologos is that `defr` and `learn` become dual operations: one writes rules explicitly, the other synthesizes them from data. Both produce the same `relation-info` struct. Learned rules are first-class: queryable, composable, and explainable via provenance tracking.


<a id="org9e6c17c"></a>

## 5.2 Modern ILP Systems

The ILP landscape has matured significantly in recent years, moving beyond the classical FOIL and Progol systems:

-   **Popper** (Cropper & Morel, 2021) introduced the \`\`learning from failures'' paradigm. Rather than searching through the hypothesis space blindly, Popper generates a candidate hypothesis, tests it against examples, and when it fails, analyzes *why* it failed to derive constraints that prune the search space. The hypothesis generator uses Answer Set Programming (ASP), and failure analysis produces *hypothesis constraints* &#x2014; generalizations, specializations, and eliminations &#x2014; that prevent entire classes of incorrect hypotheses from being considered. This transforms ILP from generate-and-test into a constraint-satisfaction process.

-   **Metagol** uses meta-interpretive learning (MIL): higher-order metarules serve as templates with predicate variables. A metarule like `P(X,Y) :- Q(X,Z), R(Z,Y)` is instantiated by binding `P`, `Q`, and `R` to concrete predicates. Crucially, Metagol supports *predicate invention* &#x2014; it can introduce helper predicates that were not in the original vocabulary, discovering modular decompositions of the target concept.

-   **ILASP** extends ILP to learn full Answer Set Programs, including constraints, preferences, and weak constraints. This enables learning of non-monotonic rules, default reasoning, and optimization criteria.

-   **Propper** (2024) extends Popper to the probabilistic setting, learning rules from noisy or probabilistic data. This bridges the gap between symbolic ILP and statistical learning.


<a id="orge00ba65"></a>

## 5.3 Surface Syntax for Rule Learning

```prologos
;; Learn a relation from examples
learn ancestor : ParentChild
  :positive '[(ancestor "alice" "carol") (ancestor "alice" "dave")]
  :negative '[(ancestor "bob" "alice")]
  :background [parent-child]
  :max-clauses 3
  :max-vars 4

;; The system synthesizes:
;; defr ancestor [?x ?y]
;;   &> (parent-child x y)
;;   &> (parent-child x z) (ancestor z y)
```

The `learn` form declares intent to synthesize a relation. The `:positive` and `:negative` annotations provide the examples that define the target concept extensionally. The `:background` list names existing relations available as building blocks. The `:max-clauses` and `:max-vars` parameters bound the hypothesis space, controlling the complexity of the search. The type annotation (`ParentChild`) anchors the learned relation in the type system, ensuring that synthesized rules are well-typed.


<a id="org19616d2"></a>

## 5.4 Mapping to the Propagator Architecture

The propagator architecture is remarkably well-suited to ILP:

-   **Hypothesis space as a lattice.** Hypotheses (candidate rule sets) are naturally ordered by subsumption: a more general hypothesis covers more examples and sits above a more specific one in the lattice. The lattice of hypotheses, ordered by theta-subsumption, provides the domain for propagator cells. Each cell holds the current set of viable hypotheses, and propagators narrow this set as evidence accumulates.

-   **Generate-test-constrain as propagation.** Popper's learning-from- failures paradigm maps directly to constraint propagation. A failed hypothesis generates a nogood that propagates through the hypothesis lattice, pruning not just the specific hypothesis but all hypotheses that share the same failure mode. Generalization constraints (\`\`every specialization of H also fails'') and specialization constraints (\`\`every generalization of H also fails'') are exactly the kind of monotonic narrowing that propagators perform.

-   **ATMS for hypothesis tracking.** Each candidate rule is an ATMS assumption. A derivation of a negative example from a set of candidate rules creates a nogood. The ATMS maintains which combinations of rules are consistent with all examples. The minimal consistent sets are the candidate solutions. This reuses the same ATMS infrastructure planned for Phase 5's dependency-directed backtracking, extending it from constraint solving to rule learning.


<a id="org0d077c4"></a>

## 5.5 Predicate Invention as Metavariable Solving

One of the deepest connections between ILP and type inference lies in predicate invention. Metagol's metarules contain *meta-predicates* &#x2014; predicate variables `P`, `Q`, `R` that must be instantiated to concrete predicates during learning. This is structurally identical to metavariable instantiation in type inference: an unknown that must be solved by constraint propagation.

In Prologos, metavariables already have a rich infrastructure: `solve-meta!` for instantiation, constraint postponement when insufficient information is available, and retry callbacks that re-fire when new information arrives. Predicate invention repurposes this infrastructure: a meta-predicate is a metavariable whose domain is the space of predicates rather than the space of types. The same unification and constraint machinery that resolves type metavariables can resolve predicate metavariables, with the hypothesis lattice replacing the type lattice as the constraint domain.

A metarule `P(X,Y) :- Q(X,Z), R(Z,Y)` becomes a constraint: \`\`there exist predicates `P`, `Q`, `R` such that the rule entails all positive examples and no negative examples.'' The propagator network solves this constraint by the same process it uses for type inference &#x2014; propagation to quiescence with backtracking on contradiction.


<a id="orgfefbbca"></a>

## 5.6 Differentiable ILP and Neural-Symbolic Integration

The frontier of ILP research integrates symbolic rule learning with neural computation:

-   **DeepProbLog** and **NeurASP** embed neural network outputs as probabilistic facts in a logic program. A neural classifier's output becomes a weighted fact `0.93 :: digit(img42, 7)` that participates in logical reasoning.

-   **GLIDR** (2025) introduces graph-based differentiable ILP, where the hypothesis search is differentiable and can be trained end-to-end with gradient descent.

The connection to Prologos is forward-looking: if probabilistic annotations are added to the relational sublanguage (as explored in Section 6), then differentiable ILP becomes expressible within the language. Neural network outputs become weighted facts that feed into the propagator network, and gradient information can flow backward through the lattice merge operations (which, being join/meet on a lattice, have well-defined subgradients). The propagator network becomes a differentiable reasoning engine &#x2014; a bridge between connectionist learning and symbolic logic.


<a id="org2925c9f"></a>

## 5.7 `learn` as Dual of `defr`

The `learn` keyword completes a symmetry in Prologos's relational sublanguage:

| Form    | Direction | Input        | Output       |
|------- |--------- |------------ |------------ |
| `defr`  | Deductive | Rules        | Answers      |
| `learn` | Inductive | Examples     | Rules        |
| `query` | Abductive | Observations | Explanations |

All three produce or consume `relation-info` structs. A learned relation is indistinguishable from a hand-written one: it can be queried, composed with other relations, used as background knowledge for further learning, and inspected via provenance to understand *why* each clause was included. The provenance tracks which positive examples necessitated each clause and which negative examples constrained the search, providing a form of explainability that is absent from black-box learning systems.

This triad &#x2014; deduction, induction, abduction &#x2014; represents the three fundamental modes of logical reasoning, all unified under the propagator architecture and all producing the same first-class relation values.


<a id="orgbfa2e8a"></a>

# 6. Probabilistic and Weighted Logic Programming

Standard logic programming operates in the Boolean domain: a goal either succeeds or fails, a fact is true or false. But many real-world problems demand quantitative reasoning &#x2014; probabilities, costs, counts, provenance. Rather than building separate systems for each, we observe that the same program structure supports all of these through a single algebraic abstraction: the semiring. This section develops Prologos's approach to semiring-parameterized logic programming, showing how it emerges naturally from the lattice-based propagator infrastructure already in place.


<a id="org3ee4ccc"></a>

## 6.1 The Semiring Abstraction

The Dyna language (Eisner, Filardo, and collaborators at Johns Hopkins University) demonstrated a powerful insight: logic programming can be parameterized by a semiring, and the choice of semiring determines the semantics of "combining evidence" without changing the program's logical structure. A semiring &lang;&oplus;, &otimes;, \bar{0}, \bar{1}&rang; provides two operations &#x2014; an additive operation &oplus; for combining alternative derivations and a multiplicative operation &otimes; for combining conjunctive subgoals &#x2014; along with their respective identity elements.

The classical examples illustrate the range:

-   **Boolean semiring** &lang;&or;, &and;, \bot, \top&rang; yields standard Prolog and Datalog. A goal succeeds if any derivation exists; conjunction requires all subgoals to succeed.
-   **Probability (sum-product) semiring** &lang;+, &times;, 0, 1&rang; over the reals yields probabilistic inference. Alternative derivations contribute additive probability mass; conjunctive subgoals multiply their probabilities (assuming independence).
-   **Tropical (Viterbi) semiring** &lang;min, +, &infin;, 0&rang; yields shortest-path and most-likely-derivation computations. Alternatives compete by minimum cost; conjunction accumulates cost additively.
-   **Counting semiring** &lang;+, &times;, 0, 1&rang; over the natural numbers counts the number of distinct derivations rather than merely confirming existence.
-   **Provenance semirings** (Green, Karvounarakis, and Tannen, 2007) track database lineage &#x2014; which base facts contributed to each derived fact, and how.

The essential observation is that all of these are *the same program* with different algebraic interpretations. A shortest-path query and a most-probable-path query share identical clause structure; only the semiring differs.

The connection to Prologos is direct. A semiring decomposes into an additive commutative monoid and a multiplicative monoid, where multiplication distributes over addition. Our existing `Lattice` trait provides the additive part: the join operation serves as semiring addition (combining alternative evidence), and bottom serves as the additive identity (no evidence). What the lattice alone lacks is the multiplicative monoid &#x2014; the operation that combines evidence from conjunctive subgoals. A companion `Semiring` trait extends `Lattice` with this multiplicative structure:

```prologos
trait Semiring L :extends Lattice L :=
  spec one : L                      ;; multiplicative identity
  spec mul : <(x : L) -> (y : L) -> L>  ;; multiplicative operation
  ;; Laws: mul distributes over join, mul is associative, one is identity for mul
```

Every semiring instance automatically inherits the lattice infrastructure &#x2014; cells, propagators, monotonic merge &#x2014; and gains the ability to combine conjunctive evidence through multiplication.


<a id="org1a16df8"></a>

## 6.2 Surface Syntax: The `^Weight` Annotation

Existing probabilistic logic languages each introduce their own annotation syntax. ProbLog prefixes facts with probabilities (`0.3::edge(a,b).`). PRISM uses explicit probabilistic switch primitives (`msw(coin, X)`). ICL and LPADs annotate disjunctive clauses (`0.6::heads ; 0.4::tails :- toss(X).`). Each approach is ad hoc, tightly coupling the probability to a specific syntactic position.

Prologos proposes a uniform postfix annotation: `^Weight` appears after a fact row, where `Weight` is a first-class expression evaluated in the ambient semiring.

```prologos
;; Probabilistic facts with ^weight annotation
defr edge [?from:Node ?to:Node]
  || "a" "b" ^0.3
     "a" "c" ^0.7
     "b" "c" ^0.4

;; Rules combine weights via semiring multiplication
defr path [?x:Node ?y:Node]
  &> (edge x y)
  &> (edge x z) (path z y)

;; Query returns weighted answer set
let results := (solve-with :semiring probability (path "a" "c"))
;; => [{x: "a", y: "c", weight: 0.82}]
;;    (0.7 + 0.3*0.4 = 0.82 via sum-product)
```

Several design decisions merit discussion. First, the postfix position `^Weight` keeps weights visually close to the data they annotate without disrupting the columnar alignment of fact tables &#x2014; a practical concern when relations have many columns. Second, weights are first-class values: they may be literals, variables, or arbitrary expressions, enabling computed weights and weight polymorphism. Third, the semiring is specified at query time via the `:semiring` key in solver configuration, not baked into the relation definition. The same `edge` relation can be queried under the probability semiring (sum-product), the tropical semiring (shortest path), or the counting semiring (number of paths) without modification. Fourth, when no `^Weight` annotation is present and no `:semiring` is specified, the solver defaults to the Boolean semiring, recovering standard logic programming. This ensures full backward compatibility.


<a id="orgf99c0f8"></a>

## 6.3 Probabilistic Propagators

The integration of semiring weights with the propagator network requires extending the notion of what a cell holds. In standard Prologos propagation, a cell holds a lattice value that grows monotonically toward a fixed point. Under a semiring parameterization, cells hold *weighted values*: either a single (value, weight) pair or, more generally, a distribution &#x2014; a mapping from values to semiring weights.

The merge function generalizes accordingly. Under the probability semiring, merging two distributions combines weights for identical values via addition (accumulating probability mass from alternative derivations) and retains all distinct values. Under the tropical semiring, merging retains the minimum-weight entry for each value. The key invariant is preserved: merge is monotonic with respect to the semiring's additive ordering, so propagation still converges to a fixed point.

Propagators themselves perform semiring operations:

-   **Conjunction** (rule body with multiple subgoals): the propagator multiplies the weights of its inputs using semiring &otimes;. If a rule body is `p(X)^w1, q(X,Y)^w2`, the derived fact carries weight `w1 \otimes w2`.
-   **Disjunction** (multiple clauses deriving the same conclusion): the cell merges incoming weights using semiring &oplus;. Two derivations of `path("a","c")` with weights 0.7 and 0.12 produce a combined weight of 0.82.
-   **Marginalization**: summing over an eliminated variable is semiring addition over the marginalized dimension, implemented as a specialized propagator that projects a multi-variable distribution down to fewer variables.

This architecture reveals a deep structural correspondence with belief propagation on factor graphs. A factor graph is a bipartite graph connecting variable nodes to factor nodes; messages pass between them iteratively until convergence. A propagator network is a bipartite graph connecting cells to propagators; values flow between them iteratively until quiescence. These are the *same* computational structure. The sum-product algorithm &#x2014; the workhorse of probabilistic graphical model inference &#x2014; is precisely constraint propagation over the probability semiring. Prologos does not merely *support* belief propagation; belief propagation is a special case of what the propagator network already does.


<a id="org6f23976"></a>

## 6.4 The Distributional Lattice

For probabilistic propagation to be well-founded, probability distributions must themselves form a lattice under an appropriate information ordering. They do.

Consider the space of sub-probability distributions over a finite domain `D` (distributions whose total mass is at most 1). This space admits a natural lattice structure:

-   **Bottom**: the zero distribution (all masses are 0), representing complete absence of information.
-   **Top**: a designated contradiction element, representing inconsistent evidence (analogous to the top element in type lattices).
-   **Join**: pointwise maximum of probability masses. Given distributions `d1` and `d2`, their join assigns each element `x \in D` the weight `max(d1(x), d2(x))`. This is a conservative upper bound &#x2014; it represents "at least as much evidence as either source provides."
-   **Ordering**: `d1 \le d2` if `d1(x) \le d2(x)` pointwise for all `x \in D`.

An alternative ordering based on information content uses entropy: `d1 \le d2` if `d2` can be obtained from `d1` by conditioning on evidence (i.e., `d2` is more informed, with lower entropy). Under this ordering, the bottom element is the uniform distribution (maximum entropy, minimum information) and join corresponds to Bayesian update.

Either formulation satisfies the critical requirement: distributions can serve as cell values in a propagator network, and probabilistic inference becomes monotonic propagation to quiescence. This is not merely an analogy. It means that type inference (propagation over type lattices) and probabilistic inference (propagation over distributional lattices) are instances of the *same* computational mechanism. A single propagator network can mix type cells and probability cells, performing simultaneous type checking and probabilistic reasoning.


<a id="orge82a4a0"></a>

## 6.5 Tropical Semiring and Optimization

The tropical semiring &lang;min, +, &infin;, 0&rang; reinterprets logic programs as optimization problems. Addition becomes minimization (selecting the best alternative), and multiplication becomes ordinary addition (accumulating costs along a derivation path).

```prologos
;; Shortest path via tropical semiring
defr distance [?from:Node ?to:Node ?d:Nat]
  || "a" "b" 1 ^1
     "a" "c" 4 ^4
     "b" "c" 2 ^2

;; With tropical semiring, solve finds SHORTEST path
let result := (solve-with :semiring tropical (distance "a" "c" ?d))
;; => [{d: 3}]  (path a->b->c, total distance 1+2=3, beating direct a->c at 4)
```

The same relation, queried under different semirings, answers different questions without any change to the program:

| Semiring    | &oplus; | &otimes; | Question answered                   |
|----------- |------- |-------- |----------------------------------- |
| Boolean     | &or;    | &and;    | Is there any path?                  |
| Probability | +       | &times;  | What is the total path probability? |
| Tropical    | min     | +        | What is the shortest path?          |
| Counting    | +       | &times;  | How many distinct paths exist?      |
| Viterbi     | max     | &times;  | What is the most probable path?     |
| Provenance  | &cup;   | \bowtie  | Which base facts were used?         |

This unification is not merely elegant &#x2014; it is practical. A network routing system, a natural language parser, a database provenance tracker, and a probabilistic reasoner can all share the same relation definitions and solver infrastructure, differing only in the semiring passed at query time.


<a id="orgcdf2527"></a>

## 6.6 Composing Probability with Other Features

The power of the semiring approach is amplified by its composition with Prologos's other features.

**With modes.** The mode annotation `+var:Type` (input) and `-var:Type` (output) composes cleanly with weights: `+x:Node^0.5` indicates an input whose presence carries a known prior weight. Mode checking ensures that weight annotations on inputs are constants or ground expressions, while outputs may carry computed weights.

**With domain constraints.** A variable `?x:Interval^Weight` constrains the variable to an interval domain while attaching a semiring weight. Probabilistic interval reasoning &#x2014; computing the probability that a value falls within a range &#x2014; emerges naturally from this combination.

**With tabling.** Tabling (memoization of relation results) already supports lattice answer modes, where repeated derivations of the same fact are merged via the lattice join. Under a semiring, tabled answers accumulate weights: each new derivation of a tabled fact merges its weight into the stored entry via semiring addition. This provides automatic aggregation &#x2014; probability accumulation, cost minimization, or count accumulation &#x2014; without any special-purpose aggregation syntax.

**With provenance.** Each derivation in Prologos can carry a proof tree (Section 5). Under a semiring, derivations additionally carry weights. The weight of a complete derivation is the semiring product of all clause weights along the proof path. Provenance semirings (polynomial semirings over base fact identifiers) make this explicit: the "weight" is a polynomial expression recording exactly which base facts were combined and how.

**With session types.** Probabilistic session types (Imai et al.) extend session type theory with quantitative reasoning about expected message frequencies and channel capacities. In Prologos, a session-typed channel carrying probabilistic data would have its session type annotated with expected message rates, enabling static reasoning about throughput and resource usage.

**With coinduction.** Standard coinductive logic programming handles infinite structures (streams, greatest fixed points). Probabilistic coinduction extends this to infinite stochastic processes: Markov chains, probabilistic automata, and recursive probabilistic models. The combination of coinductive reasoning with semiring weights enables reasoning about long-run properties of stochastic systems &#x2014; steady-state distributions, expected hitting times, and absorption probabilities.


<a id="orge3ac96a"></a>

## 6.7 Implementation Roadmap

The implementation proceeds in six stages, each building on the previous:

1.  **Semiring trait definition.** Define the `Semiring` trait extending `Lattice` with `one` and `mul`, plus standard instances (Boolean, probability, tropical, counting). This parallels the existing `Lattice` trait hierarchy and reuses its infrastructure.

2.  **Weighted fact storage.** Extend the fact-row representation in the relation store with an optional weight field. Unweighted facts implicitly carry the semiring identity weight \bar{1}. The parser is extended to recognize the `^Weight` postfix annotation.

3.  **Semiring-parameterized solver.** The core `solve-goals` loop is parameterized by a semiring, threading the &oplus; and &otimes; operations through goal combination. Conjunction applies &otimes;; disjunction (backtracking over clauses) applies &oplus; to the weights of alternative derivations. The solver-config map gains a `:semiring` key.

4.  **Distributional cell type.** A new cell variant `DistCell` holds a mapping from values to semiring weights. Its merge function applies pointwise semiring addition. Propagators that write to distributional cells automatically produce weighted outputs.

5.  **Solver-config integration.** The `solve-with` surface form wires the `:semiring` configuration through to the solver, propagator network, and tabling subsystem. When no semiring is specified, the Boolean semiring is used, preserving existing behavior.

6.  **Marginalization and conditioning.** Built-in goal types `marginalize` and `condition` are added. Marginalization sums (via semiring &oplus;) over a set of variables, projecting a joint distribution to a marginal. Conditioning multiplies (via semiring &otimes;) by an evidence factor and renormalizes where appropriate.

This roadmap ensures that each stage delivers independently testable functionality, weighted facts can be used before the full distributional cell machinery is in place, and the Boolean-semiring default guarantees that no existing programs are affected until weights are explicitly introduced.


<a id="org00a8fb0"></a>

# 7. Category Theory &#x2014; New Mathematical Structures for Logic Programming

Classical logic programming rests on first-order logic and fixed-point semantics. These foundations served Prolog well for four decades, but they cannot express the multi-domain, information-flowing, dependently-typed reasoning that Prologos targets. Category theory offers a richer vocabulary. This section identifies categorical structures that could give Prologos expressive power no existing logic programming system possesses.


<a id="org15b268d"></a>

## 7.1 Propagator Networks as Enriched Categories

A propagator network is a directed graph where objects are cells (holding lattice values) and morphisms are propagators (monotone transformers of information between cells). Composition is propagator chaining: the output of one propagator feeds the input of the next. This is naturally a category *enriched* over a lattice.

In an enriched category, hom-sets are replaced by objects from a monoidal category V. Rather than asking whether a morphism exists between two objects, we ask *how much* structure connects them. Lawvere's 1973 insight made this concrete: a generalized metric space is a category enriched over the tropical semiring ([0, &infin;], &ge;, +). The triangle inequality d(x,z) &le; d(x,y) + d(y,z) is precisely the enriched composition law.

For Prologos, the enrichment base is a quantale (Section 7.6). If we enrich over a quantale (Q, &le;, &otimes;), we obtain:

-   The lattice order captures information refinement &#x2014; a cell's value can only increase.
-   The tensor &otimes; captures information combination &#x2014; evidence from independent sources is combined, not merely compared.
-   Enriched functors are monotone information transformers, which *are* propagators.
-   Enriched natural transformations are coherent families of information transfers &#x2014; exactly the global consistency condition that running a propagator network to quiescence enforces.

This framing turns propagator scheduling into enriched colimit computation, opening the door to applying results from enriched category theory (Kelly, 1982) to prove convergence, optimality, and completeness properties of propagator networks.


<a id="org9be7ae0"></a>

## 7.2 Sheaves and Local-to-Global Reasoning

Sheaf theory (Leray, Grothendieck) formalizes how local data patches together into global data. The defining property: if local sections agree on overlaps, they glue to a unique global section.

This maps directly onto constraint propagation. Each propagator enforces a *local* constraint over a small cluster of cells. Running the network to quiescence checks whether all local constraints are globally compatible. Contradiction means the sheaf condition fails &#x2014; no global section exists. Stable quiescence means a consistent global section has been found (or, more precisely, the greatest such section in the information ordering).

The novel direction for Prologos is **sheaves of constraint domains**. Different regions of a program naturally use different constraint domains: interval arithmetic for numerical bounds, finite domains for combinatorial search, Boolean constraints for logical structure, tropical semirings for optimization. A sheaf over the program's dependency graph would formalize how these heterogeneous domains interact at their boundaries, with restriction maps translating between domains and the gluing condition ensuring cross-domain consistency.

Recent work on sheaves of residuated lattices (arXiv, 2025) establishes a functorial correspondence between algebraic etale spaces and logical sheaves, providing categorical machinery for context-sensitive reasoning. Applications already appear in sensor fusion, distributed databases, and spatial AI &#x2014; all domains where Prologos's multi-agent reasoning features (Section 8.3) would benefit from a sheaf-theoretic foundation.


<a id="orgfb2308e"></a>

## 7.3 Fibered Categories and Dependent Types in LP

Jacobs's *Categorical Logic and Type Theory* (1999) demonstrates that dependent types have categorical semantics as fibrations. A fibration p: E &rarr; B consists of a base category B (contexts, specifying which variables are in scope), a total category E (types-in-context), fibers p<sup>-1</sup>(&Gamma;) (types available in a given context &Gamma;), and reindexing functors (substitution, pulling types back along context morphisms).

For Prologos's relational layer, a relation `defr R [?x:A ?y:B]` lives in the fiber over the context (x:A, y:B). Substituting a ground value for `x` reindexes to a smaller fiber &#x2014; this is precisely what unification accomplishes when it moves between fibers by binding variables.

The novel insight is **logic programming over a fibered category**, yielding dependent relations whose arity and parameter types depend on values of earlier parameters. This transcends Mercury's mode system and Datalog's fixed schemas:

```prologos
;; A dependent relation: the type of val depends on the value of key
defr typed-lookup [+key:String -val:(type-of-key key)]
  || "name" "Alice"       ;; val : String
     "age"  42N            ;; val : Nat
     "active" true         ;; val : Bool
```

The fibered perspective also clarifies sigma types in the relational setting: an existential query `(solve (typed-lookup key val))` with `key` unbound computes a dependent sum &Sigma;<sub>k:String</sub> (type-of-key k) &#x2014; the fiber over each possible key, bundled together.


<a id="orgdb4c3b7"></a>

## 7.4 Profunctors as Generalized Relations

A profunctor P : A \nrightarrow B is a functor P : B<sup>op</sup> &times; A &rarr; Set. Profunctors generalize relations: a relation R \subseteq A &times; B is a profunctor where P(b,a) is a proposition (a set with at most one element). Proof-relevant relations, where P(b,a) can have multiple elements corresponding to distinct derivations, are full profunctors.

This is directly relevant to Prologos. Relations with provenance *are* proof-relevant relations. Each distinct derivation of (a,b) in a relation R constitutes a separate element of P(b,a), and the provenance system already tracks these derivation witnesses.

Profunctor composition via coend is illuminating: (Q &circ; P)(c,a) = &int;<sup>b</sup> Q(c,b) &times; P(b,a). The coend sums over the intermediate variable b. This is *exactly* relational join &#x2014; the fundamental operation of the relational engine. Prologos's relational composition is profunctor composition, whether or not we use the categorical vocabulary.

Profunctor optics (Clarke et al., *Compositionality*, 2024) formalize bidirectional data accessors &#x2014; lenses, prisms, traversals &#x2014; as profunctor transformations. For Prologos, schema field access could be realized as profunctor optics, providing a categorical foundation for the bridge between schemas (record-like types) and relations (sets of tuples).


<a id="orgf392b98"></a>

## 7.5 Kan Extensions and Query Optimization

Left and right Kan extensions are the universal solution to extending a functor along another functor. Mac Lane's slogan &#x2014; "All concepts are Kan extensions" &#x2014; is not hyperbole; (co)limits, adjunctions, and ends are all special cases.

For logic programming, the connection is direct. Left Kan extension corresponds to existential quantification (projection in relational queries). Right Kan extension corresponds to universal quantification. Both are computed as (co)limits, which the lattice structure provides natively.

The application to query optimization is compelling. A query plan is a functor from a query graph (the shape of the query) to a data graph (the shape of the database). Optimizing the plan means finding a better factorization through intermediate structures. Kan extensions give the *universal* such factorization &#x2014; the best possible plan in a precisely defined sense. This suggests that a Kan-extension-based query planner could produce provably optimal plans for Prologos's relational queries, rather than relying on heuristic cost models.


<a id="orgc26748e"></a>

## 7.6 Quantales: Beyond Lattices

A quantale is a complete lattice (Q, &le;) equipped with an associative binary operation &otimes; distributing over arbitrary joins: a &otimes; (\bigvee<sub>i</sub> b<sub>i</sub>) = \bigvee<sub>i</sub> (a &otimes; b<sub>i</sub>). Quantales subsume both lattices (&otimes; = &and;) and semirings (&le; is the natural order of the additive monoid). They are the *right* algebraic structure for propagator networks that combine information from multiple sources.

The critical distinction is between join (\bigvee), which merges information from *different* derivation paths, and tensor (&otimes;), which combines information from the *same* derivation. For probabilistic reasoning this distinction is essential: join is disjunction (or, corresponding to +), while tensor is conjunction (and, corresponding to &times;). A quantale captures both operations and their interaction in a single algebraic structure.

Quantale-valued logics, following Lawvere, show that any quantale &Omega; gives rise to a generalized &Omega;-valued logic whose models are categories enriched over &Omega;. Parameterizing Prologos's logic engine by a quantale rather than just a lattice would subsume Boolean LP, probabilistic LP, tropical (optimization) LP, and fuzzy LP in a single unified framework (Section 8.1).


<a id="orgac6c6fe"></a>

## 7.7 Galois Connections and Abstract Interpretation

A Galois connection (&alpha;, &gamma;) between lattices C and A consists of an abstraction function &alpha;: C &rarr; A and a concretization function &gamma;: A &rarr; C satisfying &alpha;(c) &le; d \iff c &le; &gamma;(d). Abstract interpretation (Cousot & Cousot, 1977) exploits Galois connections to analyze programs by computing in an abstract domain A rather than the concrete domain C, with soundness guaranteed by the connection.

For Prologos, mode inference *is* abstract interpretation. The concrete domain is {ground values} &cup; {unbound}. The abstract domain is the three-element lattice {+, -, ?}. The Galois connection maps ground values to +, unbound to -, and the join to ?. Concretization maps + to the set of all ground values, - to {unbound}, and ? to everything.

This means mode inference can be implemented as a propagator network over the mode lattice, flowing mode information through rules and checking consistency at call sites &#x2014; which the existing propagator infrastructure handles automatically. More ambitiously, domain constraints like `?x:Interval` are abstract interpretation where the abstract domain is the Interval lattice. Prologos could support arbitrary user-defined abstract domains as `Lattice` trait instances, making extensible abstract interpretation a first-class language feature rather than an external tool.


<a id="orge9e5a15"></a>

# 8. The Frontier &#x2014; What No Existing System Has

The categorical structures of Section 7 are not merely descriptive. They point toward concrete language features that no existing logic programming system provides. This section synthesizes the theoretical threads into a design vision for Prologos.


<a id="orgf898417"></a>

## 8.1 The Quantale-Parameterized Logic Engine

The central proposal: Prologos's logic engine should be parameterized not by a lattice but by a quantale Q. This single generalization subsumes every semiring-based LP extension in the literature:

-   Q provides join (\bigvee) for combining alternative derivations (disjunction).
-   Q provides tensor (&otimes;) for combining evidence within a single derivation (conjunction).
-   Q provides residuation (&otimes; \multimap), the right adjoint of tensor, for constraint propagation &#x2014; the ability to "undo" combination and extract residual information.

Instantiations recover known systems: Q = **2** (the two-element Boolean algebra) gives classical Datalog. Q = [0,1] with (max, &times;) gives probabilistic logic programming (ProbLog, DeepProbLog). Q = (\mathbb{R} &cup; \\{&infin;\\}, min, +), the tropical semiring, gives optimization (shortest-path, Viterbi). Q = ([0,1], max, min) gives fuzzy logic programming. The key insight is that all four are instantiations of the *same* enriched-categorical framework, not separate language features requiring separate implementations.


<a id="org85e1966"></a>

## 8.2 Coinductive-Probabilistic-Dependent Relations

No existing system combines coinduction, probability, and dependent types. Each pair has been explored &#x2014; coinductive logic programming (CoLP), probabilistic LP (ProbLog), dependently-typed LP (loosely, Mercury's type system) &#x2014; but the triple combination opens genuinely new territory: reasoning about infinite stochastic processes with type-level guarantees on their structure.

```prologos
;; A probabilistic coinductive relation over dependent types
defr markov-stable [?state:(Vec n Prob)] :coinductive :semiring probability
  &> (transition state next ^prob)
     (markov-stable next)
     (close-enough state next)
```

Here the dependent type `(Vec n Prob)` ensures the state vector has the correct dimensionality and entries in [0,1]. The `:coinductive` annotation permits infinite derivation trees (the Markov chain runs forever). The `:semiring probability` annotation weights derivations by their probability. The combination expresses: "find a stationary distribution of a Markov chain, tracking probabilities, with type-level dimensional correctness." No existing system can state this, let alone solve it.


<a id="org004b256"></a>

## 8.3 Sheaf-Theoretic Distributed Reasoning

Relations distributed across agents, with sheaf conditions ensuring that locally consistent knowledge assembles into globally consistent conclusions:

```prologos
;; Each agent maintains local knowledge
defr local-fact [?agent:AgentId ?key ?val] :distributed
  ;; Facts reside on the agent that owns them
  ;; Queries automatically route to the relevant agent

;; Global consistency via sheaf condition
defr global-view [?key ?val]
  :consistency sheaf   ;; local agreement implies global section
  &> (local-fact _ key val)
```

The `:consistency sheaf` annotation means the engine checks the sheaf condition: if two agents both have facts for the same key, their values must agree (or be reconcilable via the lattice merge). If the condition holds, the global view is well-defined. If it fails, the engine reports a contradiction with provenance tracing back to the conflicting agents &#x2014; analogous to a failed sheaf gluing condition identifying the obstruction cocycle.


<a id="org722db4e"></a>

## 8.4 The Egglog Connection

Egglog (Zhang et al., PLDI 2023) unifies Datalog with equality saturation. Relations become partial functions stored in e-graphs, and congruence closure maintains equational invariants incrementally. Prologos's propagator network combined with union-find (planned for Phase 4) provides the exact computational substrate that egglog requires. Equality saturation could be exposed as a solver strategy:

```prologos
(solve-with :strategy equality-saturation
  (rewrite (add (S n) m) (S (add n m)))
  (rewrite (mul Z n) Z)
  (simplify (add (S (S Z)) (mul Z (S Z)))))
```

The propagator network handles monotone information flow; the union-find handles equational merging; the lattice trait ensures that merged values are consistent. The combination gives Prologos a term-rewriting engine for free, with the same provenance tracking and dependent-type guarantees as the rest of the relational layer.


<a id="org8c0cbd8"></a>

## 8.5 Learn as Dual of Defr

The full vision completes the symmetry of the relational language. Four operations form a closed cycle over relation-info values:

-   **defr** asserts rules (introduces structure).
-   **solve** queries rules (eliminates structure via search).
-   **learn** synthesizes rules from data (introduces structure from evidence).
-   **explain** justifies derivations (eliminates structure into human-readable form).

`learn` is the categorical dual of `defr`: where `defr` maps a programmer's intent into the relation store, `learn` maps observed data back into the relation store via inductive inference. Both produce the same relation-info values. Both are subject to the same type discipline and provenance tracking. The relational language thereby becomes not merely a query language but a knowledge acquisition language &#x2014; one where the type system guarantees that learned rules are well-typed, the provenance system traces every learned rule back to its evidential basis, and the quantale parameterization weights learned rules by confidence.

This is the frontier: a language where types, logic, probability, linearity, and learning share a single categorical semantics, grounded in quantale-enriched fibered categories with sheaf-theoretic consistency. No existing system occupies this space. Prologos aims to.
