- [Executive Summary](#orgea4ebe0)
- [Part I: Lattice Foundations](#orgb523028)
  - [1. Why Lattices?](#org5ac2c1c)
  - [2. Crash Course: The Lattice Zoo](#org47c4f9d)
    - [2.1 Partial Orders](#orgbfae6e3)
    - [2.2 Join-Semilattices](#org60a9c1b)
    - [2.3 Complete Lattices and Top](#org48322c7)
    - [2.4 Fixed Points: Why Lattices Guarantee Convergence](#org07f205d)
    - [2.5 Finite Height and Termination](#orgafcae1d)
  - [3. Key Lattice Structures for Logic Programming](#org5ebabd9)
    - [3.1 The Substitution Lattice](#org5198fcf)
    - [3.2 The Herbrand Interpretation Lattice](#orgd041627)
    - [3.3 The Interval Lattice](#org966b98b)
    - [3.4 The Protocol State Lattice (Session Types)](#org882e906)
    - [3.5 The Multiplicity Semiring (QTT)](#orgb8153bd)
- [Part II: The Architectural Recommendation](#orgcd077c0)
  - [4. The Three-Layer Architecture](#org5fe482f)
    - [Layer 1: The Propagator Network (Monotonic Data Plane)](#org79f86b8)
    - [Layer 2: ATMS / Truth Maintenance (Non-Monotonic Control Plane)](#org4b15d28)
    - [Layer 3: Stratification (Controlled Non-Monotonicity)](#org735f20b)
  - [5. Validating the Multiverse Mechanism](#org10d608f)
    - [Why ATMS over Physical Forking](#orgcefc575)
    - [The Multiverse in Practice: A Worked Example](#org9e943ac)
  - [6. Validating the Pocket Universe Mechanism](#org78338d3)
    - [Applications in the Logic Engine](#org52ae2d2)
  - [7. Recovering SLD/SLG Semantics](#orgae60f60)
    - [7.1 SLD Resolution on Propagators](#orgbce1a29)
    - [7.2 SLG Resolution (Tabling) on Propagators](#org391a7ce)
    - [7.3 Cut and Pruning](#orgbc489c5)
  - [8. Tabling: The Completeness Mechanism](#orgd7bb753)
    - [8.1 Design for Prologos](#org7c5fa21)
    - [8.2 Lattice Answer Modes](#org259c3a3)
    - [8.3 Tabling as Pocket Universe](#org792b005)
  - [9. Connecting to Existing Prologos Infrastructure](#org0222e6e)
    - [9.1 The Elaborator as a Propagator Network (Today)](#org24bbce6)
    - [9.2 Session Types as Protocol Propagation](#org56e18b6)
    - [9.3 QTT Multiplicity Checking as Propagation](#org95da124)
- [Part III: The Concrete Architecture](#org4ceeeba)
  - [10. Core Data Types](#org66b9ce8)
    - [10.1 Lattice Trait](#org1ca4618)
    - [10.2 Propagator Cell](#orge3428e1)
    - [10.3 Supported Values (ATMS Integration)](#org9fe8d6a)
    - [10.4 LVar (Lattice Variable)](#org8c1eecc)
  - [11. The Propagator Network Runtime](#org354e2fe)
    - [11.1 Scheduler](#org1b66b50)
    - [11.2 Contradiction Handler](#orge7a7ecb)
    - [11.3 The `amb` Operator](#org7d257c2)
    - [11.4 Answer Collection](#org546b93c)
  - [12. Phased Implementation Plan](#org0b1a252)
    - [Phase 0: Lattice Trait + Basic Cells (Foundation)](#orge2aaae0)
    - [Phase 1: Elaborator Propagators (Compile-Time Use)](#org848259a)
    - [Phase 2: LVars + Tabling (Runtime Foundation)](#orgdf0f0d3)
    - [Phase 3: ATMS Layer (Nondeterministic Search)](#org6fb3523)
    - [Phase 4: Stratified Evaluation (Negation + Aggregation)](#org7c6253e)
    - [Phase 5: Surface Syntax + Integration (User-Facing Logic Programming)](#orgea19d67)
    - [Phase 6: Galois Connections + Domain Embeddings (Advanced)](#orgd37f7d1)
- [Part IV: Critique and Open Questions](#orgeed1905)
  - [13. What This Architecture Does Well](#org5440340)
  - [14. What This Architecture Doesn't Solve (Yet)](#orgd199c6f)
  - [15. Open Research Questions](#orgeaeb0c9)
- [Summary of Recommendations](#org26517fa)
- [References](#org9c6f2a3)
  - [Foundational (Must-Read)](#org6c8847e)
  - [Tabling and Logic Programming](#org6f3ded2)
  - [Lattice-Based Languages](#orge736efd)
  - [Theoretical Foundations](#orgdb0c9a3)
  - [Constraint Systems](#orge74ee42)
  - [Type Systems](#orgf767bb0)
  - [Implementations](#orgc96c0e3)



<a id="orgea4ebe0"></a>

# Executive Summary

This document synthesizes two extensive research surveys &#x2014; the Lattice-Based Propagator Networks survey and the Propagator Networks research report &#x2014; into a concrete architectural recommendation for Prologos's logic engine. The central thesis:

> Prologos should build its logic engine as a **stratified propagator network** with an ATMS worldview layer, using lattice-compatible data structures (LVars) as the monotonic data plane and assumption-based truth maintenance as the non-monotonic control plane. Tabling provides completeness; stratification provides negation. The same substrate should serve both compile-time (type checking, elaboration) and runtime (logic programming, constraint solving) use cases.

The two user-proposed mechanisms &#x2014; the "Multiverse Mechanism" (choice-point forking via ATMS worldviews) and the "Pocket Universe Mechanism" (scoped computation via lattice embeddings) &#x2014; are both **validated** by the research and directly implementable. The Multiverse Mechanism maps onto ATMS's simultaneous worldview maintenance, recovering nondeterminism atop a monotonic substrate. The Pocket Universe Mechanism maps onto Galois connections between abstract and concrete domains, enabling modular constraint domains and scoped sub-computations.

**Key architectural choices:**

1.  **Propagator cells** with user-defined lattice merge (Radul-Sussman model)
2.  **ATMS layer** for hypothetical reasoning, `amb`, and dependency-directed backtracking
3.  **Tabling** for termination and completeness (SLG-style, with lattice answer modes)
4.  **Stratified evaluation** for negation, aggregation, and non-monotonic operations
5.  **Galois-connected domain embeddings** for modular constraint solvers
6.  **Phased implementation** starting with compile-time use (elaborator propagators), then extending to runtime logic programming


<a id="orgb523028"></a>

# Part I: Lattice Foundations


<a id="org5ac2c1c"></a>

## 1. Why Lattices?

A **lattice** is an algebraic structure that captures the notion of *partial information* and *refinement*. In programming language theory, lattices appear everywhere:

-   **Type inference**: the substitution lattice (from most general to most specific)
-   **Abstract interpretation**: concrete/abstract domain pairs connected by Galois connections
-   **Constraint propagation**: cell values that accumulate knowledge monotonically
-   **Distributed systems**: CRDTs converging through lattice joins

For a logic engine, lattices provide the mathematical guarantee that computation **converges** &#x2014; that iteratively refining partial answers eventually reaches a stable fixed point.


<a id="org47c4f9d"></a>

## 2. Crash Course: The Lattice Zoo


<a id="orgbfae6e3"></a>

### 2.1 Partial Orders

A **partial order** $(S, \leq)$ is a set $S$ with a binary relation $\leq$ that is:

-   **Reflexive**: $a \leq a$
-   **Antisymmetric**: $a \leq b$ and $b \leq a$ implies $a = b$
-   **Transitive**: $a \leq b$ and $b \leq c$ implies $a \leq c$

The ordering represents "has at least as much information as." In a type inference context: `Int` $\leq$ `?a` means "knowing the type is `Int` is more informative than knowing nothing (metavariable `?a`)."

Not all elements need be comparable &#x2014; this is the "partial" in partial order. Two type constraints might be independent (neither implies the other).


<a id="org60a9c1b"></a>

### 2.2 Join-Semilattices

A **join-semilattice** $(L, \leq, \bot, \sqcup)$ adds:

-   A **bottom** element $\bot$ (least informative &#x2014; "nothing")
-   A **join** operation $\sqcup$ (least upper bound &#x2014; "combine information")

The join is:

-   **Commutative**: $a \sqcup b = b \sqcup a$
-   **Associative**: $(a \sqcup b) \sqcup c = a \sqcup (b \sqcup c)$
-   **Idempotent**: $a \sqcup a = a$

Join is the *merge* operation in propagator networks. When two propagators contribute information to the same cell, join combines them. Commutativity means the order doesn't matter; idempotency means duplicate contributions are harmless.


<a id="org48322c7"></a>

### 2.3 Complete Lattices and Top

A **complete lattice** also has:

-   A **top** element $\top$ (maximally informative &#x2014; *contradiction*)
-   **Meet** operation $\sqcap$ (greatest lower bound)

Top represents incompatible information merged together. When a type checker discovers that a variable must be both `Int` and `String`, the result is $\top$ &#x2014; contradiction. The propagator network must handle this by backtracking or reporting an error.


<a id="org07f205d"></a>

### 2.4 Fixed Points: Why Lattices Guarantee Convergence

**Knaster-Tarski theorem**: Every monotone function $f : L \to L$ on a complete lattice has a least fixed point:

$\mathrm{lfp}(f) = \bigsqcap \{ x \in L \mid f(x) \leq x \}$

**Kleene iteration**: On a dcpo with $\bot$, the least fixed point of a Scott-continuous $f$ is computed by iterating from bottom:

$\mathrm{lfp}(f) = \bigsqcup_{n \in \mathbb{N}} f^n(\bot)$

This is exactly what propagator networks do: start with all cells at $\bot$ (no information), iterate propagators (apply $f$), and converge to the least fixed point (the most general solution).


<a id="orgafcae1d"></a>

### 2.5 Finite Height and Termination

If the lattice has **finite height** (longest ascending chain is bounded), then Kleene iteration terminates in at most $h$ steps, where $h$ is the height. For infinite-height lattices (e.g., intervals over reals), **widening** operators accelerate convergence:

$a \nabla b \geq a \sqcup b$

Widening over-approximates to ensure termination; **narrowing** then recovers precision:

$a \leq a \triangle b \leq a \quad \text{when } b \leq a$


<a id="org5ebabd9"></a>

## 3. Key Lattice Structures for Logic Programming


<a id="org5198fcf"></a>

### 3.1 The Substitution Lattice

Unification operates on a lattice of substitutions:

-   $\bot$ = identity substitution (no bindings)
-   $\sigma \leq \tau$ iff $\tau$ is a specialization of $\sigma$ (more bindings)
-   $\sigma \sqcup \tau$ = most general unifier (mgu) of $\sigma$ and $\tau$
-   $\top$ = failure (no unifier exists)

This is the fundamental lattice for Prolog-style logic programming: every resolution step computes a join on the substitution lattice.


<a id="orgd041627"></a>

### 3.2 The Herbrand Interpretation Lattice

For Datalog/bottom-up evaluation:

-   Elements are sets of ground atoms (Herbrand interpretations)
-   $\bot$ = empty set
-   $I_1 \leq I_2$ iff $I_1 \subseteq I_2$
-   $I_1 \sqcup I_2 = I_1 \cup I_2$
-   The immediate consequence operator $T_P$ maps an interpretation to its one-step derivation

The least fixed point of $T_P$ gives the minimal Herbrand model &#x2014; all provable ground facts.


<a id="org966b98b"></a>

### 3.3 The Interval Lattice

For numeric constraint propagation:

-   Elements are intervals $[a, b]$ over $\mathbb{R}$
-   $\bot$ = $\mathbb{R}$ (no constraint)
-   $[a_1, b_1] \sqcap [a_2, b_2] = [\max(a_1, a_2), \min(b_1, b_2)]$ (intersection = more constrained)
-   $\top$ = $\emptyset$ (contradictory constraints)


<a id="org882e906"></a>

### 3.4 The Protocol State Lattice (Session Types)

For Prologos's session type verification:

-   $\bot$ = unconstrained channel
-   Interior elements = specific protocol states (e.g., "send Int then receive String")
-   $\top$ = protocol violation
-   Duality checking: two endpoints' protocol states must be lattice-dual


<a id="orgb8153bd"></a>

### 3.5 The Multiplicity Semiring (QTT)

For Prologos's quantitative type theory:

-   Elements: $\{0, 1, \omega\}$ (erased, linear, unrestricted)
-   Addition: resource usage accumulation
-   Multiplication: usage in composed contexts
-   This forms a *semiring*, not a lattice per se, but the ordering $0 \leq 1 \leq \omega$ creates a lattice structure useful for propagation


<a id="orgcd077c0"></a>

# Part II: The Architectural Recommendation


<a id="org5fe482f"></a>

## 4. The Three-Layer Architecture

We recommend a three-layer architecture for Prologos's logic engine:

```
┌─────────────────────────────────────────────────────┐
│  Layer 3: STRATIFICATION                            │
│  Negation, aggregation, non-monotone operations     │
│  Evaluated stratum-by-stratum (lower strata first)  │
└─────────────┬───────────────────────────┬───────────┘
              │                           │
┌─────────────▼───────────────────────────▼───────────┐
│  Layer 2: ATMS / TRUTH MAINTENANCE                  │
│  Hypothetical reasoning (amb, worldviews)           │
│  Nogood recording, dependency-directed backtracking  │
│  Non-monotonic control over monotonic data           │
└─────────────┬───────────────────────────┬───────────┘
              │                           │
┌─────────────▼───────────────────────────▼───────────┐
│  Layer 1: PROPAGATOR NETWORK                        │
│  Cells (lattice values) + Propagators (monotone fns)│
│  Merge = lattice join                               │
│  Deterministic, order-independent, parallelizable   │
└─────────────────────────────────────────────────────┘
```


<a id="org79f86b8"></a>

### Layer 1: The Propagator Network (Monotonic Data Plane)

The foundation. Cells hold partial information (lattice elements); propagators compute monotone functions between cells. When a cell's value increases (via merge/join), all downstream propagators are scheduled for re-execution. This layer guarantees:

-   **Determinism**: same inputs $\to$ same fixed point, regardless of scheduling
-   **Convergence**: finite-height lattices terminate; widening handles infinite ones
-   **Parallelism**: propagators can execute concurrently (CALM theorem)

This is the layer where type inference, constraint propagation, and dataflow computation live. It is purely monotonic.


<a id="org4b15d28"></a>

### Layer 2: ATMS / Truth Maintenance (Non-Monotonic Control Plane)

The innovation. The ATMS maintains *all possible worldviews simultaneously*. Each derived fact is labeled with the set of assumptions that justify it.

-   **`amb`** creates fresh hypothetical premises: $\{h_1, h_2, \ldots\}$
-   Each branch's facts are *contingent* on its hypothesis
-   **Nogoods**: when a contradiction is detected, the responsible assumption set is recorded as a nogood &#x2014; permanently invalidating that worldview
-   **Dependency-directed backtracking**: nogoods identify *which* choice was wrong, skipping irrelevant alternatives

This layer provides nondeterministic search *without backtracking* in the traditional sense. All branches exist simultaneously in the ATMS; "exploring a branch" = believing a hypothesis; "backtracking" = recording a nogood.

Key insight from the research: **the ATMS's set of nogoods is itself a monotonically growing lattice**. Non-monotonicity in the search space is reified as monotonicity in the meta-lattice of learned constraints.


<a id="org735f20b"></a>

### Layer 3: Stratification (Controlled Non-Monotonicity)

Some operations are genuinely non-monotonic: negation-as-failure, aggregation (`count`, `min`, `max`), and finalization. These are handled by **stratification**:

1.  Decompose the program into strata (strongly connected components of the dependency graph, with non-monotonic edges crossing strata)
2.  Evaluate strata bottom-up: within each stratum, run the propagator network to its fixed point
3.  Between strata, non-monotonic operations observe the *completed* lower stratum

This is the established technique from Datalog with negation, Flix, Bloom<sup>L</sup>, and CHR. The CALM theorem confirms: within a stratum, computation is coordination-free; stratum boundaries are the minimal coordination points.


<a id="org10d608f"></a>

## 5. Validating the Multiverse Mechanism

The user's proposed "Multiverse Mechanism" &#x2014; forking lattice state at choice points, exploring branches independently &#x2014; is *directly validated* by the research. It maps cleanly onto the ATMS worldview model:

| Multiverse Concept    | ATMS Implementation                            |
|--------------------- |---------------------------------------------- |
| Choice point          | `amb` creating hypothetical premises $\{h_i\}$ |
| Fork                  | Each $h_i$ labels a worldview                  |
| Independent evolution | Facts derived under $h_i$ are contingent       |
| Branch contradiction  | Nogood set $\{h_i, \ldots\}$ recorded          |
| Branch success        | Answer extracted from worldview $h_i$          |
| All branches at once  | ATMS maintains all worldviews simultaneously   |


<a id="orgcefc575"></a>

### Why ATMS over Physical Forking

The research reveals two approaches to forking:

1.  **Physical forking** (MUSE/OR-parallelism): Copy the entire state at each choice point. Each copy evolves independently.
    -   Pro: Simple, naturally parallel
    -   Con: O(state<sub>size</sub>) per fork; no shared learning between branches

2.  **Virtual forking** (ATMS): Tag all facts with their supporting assumptions. All worldviews coexist in a single data structure.
    -   Pro: O(1) context switching; nogoods shared across worldviews; dependency-directed backtracking
    -   Con: More complex bookkeeping; label management overhead

**Recommendation for Prologos: ATMS (virtual forking).** The reasons:

-   Prologos already has contingent information in its type checker (metavariables with constraints that may be retracted)
-   Dependency-directed backtracking produces dramatically better error messages ("this constraint fails because of *these* assumptions") vs chronological backtracking ("something went wrong somewhere")
-   The learning effect: nogoods discovered in one branch prune other branches. This is exactly CDCL (Conflict-Driven Clause Learning), which revolutionized SAT solving
-   Memory efficiency: shared structure between worldviews rather than full copies


<a id="org9e943ac"></a>

### The Multiverse in Practice: A Worked Example

```prologos
;; A Prologos logic program (hypothetical syntax)
relation parent : String -> String -> Prop
parent "alice" "bob"
parent "bob" "carol"
parent "bob" "dave"

relation ancestor : String -> String -> Prop
rule ancestor X Y :- parent X Y
rule ancestor X Y :- parent X Z, ancestor Z Y

query ancestor "alice" ?who
;; Expected: ?who = "bob", ?who = "carol", ?who = "dave"
```

Under ATMS:

1.  Create cell for `?who`, initially $\bot$
2.  First rule: `parent "alice" ?who` unifies, producing `?who = "bob"` under assumption $h_1$
3.  Second rule: `parent "alice" ?Z`, `ancestor ?Z ?who`
    -   `?Z = "bob"` under $h_2$; then `ancestor "bob" ?who`
    -   First rule: `parent "bob" ?who` → `?who = "carol"` under $h_3$ or `?who = "dave"` under $h_4$ (`amb` on matching clauses)
4.  All answers coexist: `{h_1: "bob", h_3: "carol", h_4: "dave"}`
5.  Collecting answers = iterating over consistent worldviews


<a id="org78338d3"></a>

## 6. Validating the Pocket Universe Mechanism

The "Pocket Universe Mechanism" &#x2014; isolating a sub-computation in a smaller lattice, then projecting results back &#x2014; maps onto **Galois connections** from abstract interpretation:

| Pocket Universe Concept | Formal Mapping                                              |
|----------------------- |----------------------------------------------------------- |
| Outer lattice (full)    | Concrete domain $C$                                         |
| Inner lattice (pocket)  | Abstract domain $A$                                         |
| Enter pocket            | Abstraction function $\alpha : C \to A$                     |
| Compute in pocket       | Fixed point in $A$ (cheaper/faster)                         |
| Exit pocket             | Concretization $\gamma : A \to C$                           |
| Soundness guarantee     | Galois connection: $\alpha(x) \leq y \iff x \leq \gamma(y)$ |


<a id="org52ae2d2"></a>

### Applications in the Logic Engine

1.  **Tabling as pocket universes**: When a tabled predicate is called, a sub-computation is launched in a "pocket" (the table). Intermediate results are accumulated in the table's lattice. When complete, the table's answers are projected back into the calling context via the consumer mechanism.

2.  **Modular constraint domains**: Each constraint domain (equality, ordering, arithmetic, set membership) lives in its own lattice. They are embedded into the global propagator network via Galois connections. Each domain solver is a "pocket universe" that receives projections of the global state and returns refined constraints.

3.  **Scoped hypothetical reasoning**: An `amb` creates a pocket universe for each alternative. Within each pocket, propagation proceeds independently. Nogoods discovered in one pocket prune others via the ATMS label mechanism.

4.  **Abstract interpretation for type checking**: The type checker operates in an abstract domain (types as lattice elements) connected to the concrete domain (values) via a Galois connection. This is already implicit in Prologos's bidirectional type checking; making it explicit with propagators would improve composability and error reporting.


<a id="orgae60f60"></a>

## 7. Recovering SLD/SLG Semantics


<a id="orgbce1a29"></a>

### 7.1 SLD Resolution on Propagators

SLD resolution (Prolog's execution model) maps onto propagators as follows:

| SLD Concept      | Propagator Implementation                |
|---------------- |---------------------------------------- |
| Goal stack       | Worklist of pending propagator firings   |
| Clause selection | `amb` over matching clauses              |
| Unification      | Join on the substitution lattice         |
| New subgoals     | New propagators added to the network     |
| Backtracking     | Nogood recording + hypothesis retraction |
| Answer           | Fixed point of the substitution cell     |

The key difference: SLD's depth-first, left-to-right search becomes the ATMS's breadth-first, dependency-directed search. This is *more complete* (no infinite loops from left-recursion) and *more efficient* (nogoods prune the search space globally).


<a id="org391a7ce"></a>

### 7.2 SLG Resolution (Tabling) on Propagators

SLG resolution extends SLD with memoization. The propagator mapping:

| SLG Concept            | Propagator Implementation                             |
|---------------------- |----------------------------------------------------- |
| Table (memo store)     | LVar with lattice answer mode                         |
| Producer               | Propagator computing new answers                      |
| Consumer               | Propagator waiting for table answers (threshold read) |
| Completion             | Table LVar frozen; no more answers                    |
| Well-founded semantics | Stratified evaluation of cyclic dependencies          |

**Lattice answer modes** (from XSB Prolog): instead of storing all individual answers, the table stores the lattice join of all answers. This subsumes Datalog evaluation and connects directly to Flix's lattice-valued relations.

```
;; SLG-style tabling with lattice answer mode
;; shortest_path(A, B, D) — D is a MinNat lattice value
table shortest_path : String -> String -> MinNat -> Prop
  :answer-mode lattice  ;; join answers via min

rule shortest_path A B 1 :- edge A B
rule shortest_path A C .{D1 + D2}
  :- edge A B, shortest_path B C D2, .{D1 = 1}
```


<a id="orgbc489c5"></a>

### 7.3 Cut and Pruning

Cut maps onto ATMS operations:

| Cut Variant                | Propagator Implementation                          |
|-------------------------- |-------------------------------------------------- |
| `!` (hard cut)             | Retract alternative hypotheses for this `amb`      |
| `once/1`                   | Threshold read + freeze on first answer            |
| `if-then-else`             | Conditional propagator (threshold on condition)    |
| Committed choice           | Guard evaluation + monotone commitment             |
| `\+` (negation-as-failure) | Stratified: evaluate goal in lower stratum, negate |

The ATMS approach is superior to Prolog's chronological backtracking because cut's *dependency-directed* counterpart (nogood recording) naturally identifies *which* choices to prune, avoiding the well-known pitfalls of "red cuts" that silently change program semantics.

**Recommendation**: Prologos should support `once` (deterministic commit) and `committed-choice` (guard-based), but NOT raw `!` (Prolog-style cut). Cut is too low-level and error-prone; the ATMS provides better alternatives.


<a id="orgd7bb753"></a>

## 8. Tabling: The Completeness Mechanism

Tabling is *essential* for a practical logic engine. Without it, left-recursive rules cause infinite loops (in SLD) or redundant computation (in naive bottom-up evaluation).


<a id="org7c5fa21"></a>

### 8.1 Design for Prologos

```prologos
;; Tabling declaration via spec metadata
spec ancestor : String -> String -> Prop
  :tabled true
  :answer-mode all  ;; or :answer-mode lattice for aggregate answers

;; Implementation is just regular rules
rule ancestor X Y :- parent X Y
rule ancestor X Y :- parent X Z, ancestor Z Y
```

Under the hood:

1.  First call to `ancestor` creates a *producer* propagator
2.  The producer evaluates rules, pushing answers into a table (LVar)
3.  Subsequent calls create *consumer* propagators that read from the table via threshold reads
4.  When the producer reaches a fixed point (no new answers), the table is frozen
5.  Consumers receive all answers


<a id="org259c3a3"></a>

### 8.2 Lattice Answer Modes

Following XSB Prolog's design, each tabled predicate can specify an answer mode:

-   **`all`**: Store all distinct answers (standard tabling). The lattice is the powerset of substitutions.
-   **`lattice(f)`**: Aggregate answers via a user-specified lattice join `f`. New answers are only "new" if they improve the current aggregate. This subsumes Datalog with lattices (Flix-style).
-   **`first`**: Store only the first answer (`once` semantics, table frozen after first answer).


<a id="org792b005"></a>

### 8.3 Tabling as Pocket Universe

Each tabled predicate's table is a "pocket universe" in the Galois connection sense:

-   **Abstraction**: project the calling context's substitution onto the tabled predicate's argument positions
-   **Computation**: evaluate the tabled predicate's rules within the pocket
-   **Concretization**: lift the table's answers back into the calling context

This ensures that tabled sub-computations are modular and can be incrementally updated when the calling context provides new information.


<a id="org0222e6e"></a>

## 9. Connecting to Existing Prologos Infrastructure


<a id="org24bbce6"></a>

### 9.1 The Elaborator as a Propagator Network (Today)

Prologos's elaborator *already* implements propagator-like behavior:

| Current Elaborator           | Propagator Equivalent               |
|---------------------------- |----------------------------------- |
| Metavariables                | Cells (lattice of types/terms)      |
| Unification constraints      | Propagators (join on subst lattice) |
| `resolve-trait-constraints!` | Propagators resolving dict params   |
| `save/restore-meta-state!`   | Speculative execution (worldviews)  |
| `check-unresolved`           | Detecting unsolved cells            |
| Zonking                      | Reading final fixed-point state     |

The gap: these are *ad hoc* rather than *architected*. The metavar store is a mutable hash table, not a lattice-structured cell. Trait resolution uses a worklist, but doesn't record nogoods or do dependency-directed backtracking. Speculative execution (`save/restore-meta-state!`) copies the entire state, rather than using ATMS-style contingent values.

**Phase 1 recommendation**: Refactor the elaborator's metavar system to use proper propagator cells with lattice merge semantics. This would immediately improve:

-   Error messages (dependency tracking shows *why* a constraint failed)
-   Implicit argument inference (more information from bidirectional flow)
-   Speculative type checking (ATMS worldviews instead of full state copy)


<a id="org56e18b6"></a>

### 9.2 Session Types as Protocol Propagation

Session type checking already propagates protocol state. Making this explicit with propagator cells would enable:

-   Multi-party session typing (currently only binary)
-   Dependent session types (protocol depends on values)
-   Better error messages for protocol violations


<a id="org95da124"></a>

### 9.3 QTT Multiplicity Checking as Propagation

Multiplicity inference (Sprint 7) already propagates multiplicity constraints. With proper propagator cells:

-   Multiplicity inference becomes a standard fixpoint computation
-   Multiplicity errors get dependency tracking
-   The semiring structure ($0, 1, \omega$) is naturally a lattice


<a id="org4ceeeba"></a>

# Part III: The Concrete Architecture


<a id="org66b9ce8"></a>

## 10. Core Data Types


<a id="org1ca4618"></a>

### 10.1 Lattice Trait

```prologos
;; The fundamental lattice abstraction
trait Lattice {A : Type}
  bot   : A
  join  : A -> A -> A
  leq   : A -> A -> Bool

;; Laws (checked via property testing):
;;   join is commutative:  join a b = join b a
;;   join is associative:  join (join a b) c = join a (join b c)
;;   join is idempotent:   join a a = a
;;   bot is identity:      join bot a = a
;;   leq is consistent:    leq a b = (join a b == b)
```


<a id="orge3428e1"></a>

### 10.2 Propagator Cell

```prologos
;; A cell holds a lattice value, tracks dependents
deftype Cell (A : Type)
  :where (Lattice A)
  mk-cell : A -> Cell A

;; Core operations
spec cell-read  : {A : Type} where (Lattice A) [Cell A] -> A
spec cell-write : {A : Type} where (Lattice A) [Cell A] -> A -> Unit
  ;; cell-write c v = merge(current, v); schedule dependents if changed

spec cell-watch : {A : Type} where (Lattice A) [Cell A] -> [A -> Unit] -> Unit
  ;; Register a callback (propagator) triggered on cell value change
```


<a id="org9fe8d6a"></a>

### 10.3 Supported Values (ATMS Integration)

```prologos
;; A supported value pairs information with its justification
deftype Supported (A : Type)
  mk-supported : A -> [Set Assumption] -> Supported A

;; A TMS cell holds multiple contingent values
deftype TMSCell (A : Type)
  :where (Lattice A)
  mk-tms-cell : [Set [Supported A]] -> TMSCell A
```


<a id="org8c1eecc"></a>

### 10.4 LVar (Lattice Variable)

```prologos
;; LVar: monotonic lattice variable with threshold reads
deftype LVar (A : Type)
  :where (Lattice A)
  mk-lvar : A -> LVar A

spec lvar-put : {A : Type} where (Lattice A)
  [LVar A] -> A -> Unit
  ;; Inflationary: new_state = join(current, value)

spec lvar-get : {A : Type} where (Lattice A)
  [LVar A] -> [Set A] -> A
  ;; Threshold read: block until state >= some element of threshold set
  ;; Threshold elements must be pairwise incompatible

spec lvar-freeze : {A : Type} where (Lattice A)
  [LVar A] -> A
  ;; Freeze and return exact state (quasi-deterministic)
```


<a id="org354e2fe"></a>

## 11. The Propagator Network Runtime


<a id="org1b66b50"></a>

### 11.1 Scheduler

```
┌──────────────────────────────┐
│       Scheduler              │
│  ┌───────────────────────┐   │
│  │  Worklist (queue)     │   │
│  │  [prop1, prop3, ...]  │   │
│  └───────────────────────┘   │
│                              │
│  Loop:                       │
│    1. Dequeue propagator     │
│    2. Execute (read inputs)  │
│    3. Write outputs (merge)  │
│    4. If cell changed:       │
│       enqueue dependents     │
│    5. If cell = top:         │
│       contradiction handler  │
│    6. Repeat until empty     │
└──────────────────────────────┘
```

Properties:

-   Jobs are idempotent (safe to re-execute)
-   Scheduling order doesn't affect the final result (lattice determinism)
-   Parallelizable: independent propagators can execute concurrently


<a id="orge7a7ecb"></a>

### 11.2 Contradiction Handler

When a cell reaches $\top$ (contradiction):

1.  Extract the *support set* (assumptions that led to contradiction)
2.  Record as a **nogood** in the ATMS
3.  Retract the most recently chosen hypothesis in the nogood set
4.  Re-propagate with the retracted hypothesis disbelieved

This is dependency-directed backtracking. It avoids the exponential blowup of chronological backtracking by targeting the actual cause.


<a id="org7d257c2"></a>

### 11.3 The `amb` Operator

```prologos
;; amb creates a choice point with n alternatives
spec amb : {A : Type} [List A] -> A

;; Under the hood:
;; 1. Create fresh hypotheses h1, h2, ..., hn
;; 2. For each hi, create supported value (ai, {hi})
;; 3. Add mutual exclusion: exactly one hi is believed
;; 4. Return the cell containing the contingent value
```


<a id="org546b93c"></a>

### 11.4 Answer Collection

```prologos
;; Collect all solutions from a nondeterministic computation
spec solve-all : {A : Type} [Unit -> A] -> [List A]

;; Under the hood:
;; 1. Run the computation with ATMS
;; 2. Iterate over all consistent worldviews at quiescence
;; 3. For each worldview, extract the answer
;; 4. Return list of all answers (duplicates removed)
```


<a id="org0b1a252"></a>

## 12. Phased Implementation Plan


<a id="orge2aaae0"></a>

### Phase 0: Lattice Trait + Basic Cells (Foundation)

**Goal**: Establish the lattice trait and basic propagator cell infrastructure at the Racket level.

-   Define `Lattice` trait in Prologos
-   Provide instances: `FlatLattice` (bottom/value/top), `SetLattice` (powerset with union), `IntervalLattice`
-   Implement `Cell` as a Racket-level struct with mutable value and dependent list
-   Implement basic scheduler (worklist, fire-till-quiescence)
-   **~15 AST nodes** (cell-new, cell-read, cell-write, cell-watch, &#x2026;)
-   **~40 tests**

**Dependencies**: None (builds on existing trait system) **Estimated effort**: Medium


<a id="org848259a"></a>

### Phase 1: Elaborator Propagators (Compile-Time Use)

**Goal**: Refactor the metavar system to use propagator cells internally.

-   Replace `current-meta-store` with propagator cells
-   Unification constraints become propagators between type cells
-   Trait resolution constraints become propagators
-   Add dependency tracking to metavar refinements
-   Improve error messages using dependency information
-   **No new surface syntax** &#x2014; this is internal refactoring
-   **~60 tests** (regression + new dependency-tracking tests)

**Dependencies**: Phase 0 **Estimated effort**: Large (touches elaborator + typing-core + unify) **Key risk**: This is a significant refactoring of the elaborator core


<a id="orgdf0f0d3"></a>

### Phase 2: LVars + Tabling (Runtime Foundation)

**Goal**: LVar data structures and tabled evaluation.

-   Implement `LVar` with `put`, threshold `get`, and `freeze`
-   Implement `LVar-Set`, `LVar-Map` (grow-only collections)
-   Implement tabling framework: producer/consumer pattern, table LVars, completion detection
-   Add `:tabled` spec metadata handling
-   **~20 AST nodes** (lvar-new, lvar-put, lvar-get, lvar-freeze, table-lookup, &#x2026;)
-   **~50 tests**

**Dependencies**: Phase 0, Phase 2d of Core DS roadmap (transient builders) **Estimated effort**: Large


<a id="org6fb3523"></a>

### Phase 3: ATMS Layer (Nondeterministic Search)

**Goal**: Assumption-based truth maintenance for hypothetical reasoning.

-   Implement `Assumption`, `Supported`, `TMSCell` types
-   Implement nogood recording and management
-   Implement `amb` operator with hypothesis creation
-   Implement contradiction handler with dependency-directed backtracking
-   Implement `solve-all` answer collection
-   **~15 AST nodes** (amb, assume, retract, nogood, &#x2026;)
-   **~60 tests**

**Dependencies**: Phase 0, Phase 2 **Estimated effort**: Large (most complex phase)


<a id="org7c6253e"></a>

### Phase 4: Stratified Evaluation (Negation + Aggregation)

**Goal**: Support negation-as-failure and aggregation via stratification.

-   Implement SCC decomposition of rule dependency graphs
-   Implement stratum-by-stratum evaluation
-   Support `not` (negation-as-failure) between strata
-   Support lattice aggregation (`count`, `min`, `max`, `sum`) between strata
-   **~10 AST nodes**
-   **~40 tests**

**Dependencies**: Phase 3 **Estimated effort**: Medium


<a id="orgea19d67"></a>

### Phase 5: Surface Syntax + Integration (User-Facing Logic Programming)

**Goal**: Prologos surface syntax for logic programming.

-   `relation` declarations
-   `rule` and `query` syntax
-   Pattern matching integration with unification
-   `defn` bodies that can contain logic variables
-   Integration with the prelude and module system
-   **Grammar updates** (grammar.ebnf, grammar.org)
-   **~80 tests**

**Dependencies**: All previous phases **Estimated effort**: Large


<a id="orgd37f7d1"></a>

### Phase 6: Galois Connections + Domain Embeddings (Advanced)

**Goal**: Modular constraint domains connected via Galois connections.

-   `domain` declarations with abstraction/concretization functions
-   Cross-domain propagation
-   Abstract interpretation framework for program analysis
-   **~30 tests**

**Dependencies**: Phase 5 **Estimated effort**: Medium-Large


<a id="orgeed1905"></a>

# Part IV: Critique and Open Questions


<a id="org5440340"></a>

## 13. What This Architecture Does Well

1.  **Unification of paradigms**: The same propagator substrate serves type checking, constraint solving, and logic programming. This is not merely aesthetic &#x2014; it means improvements to the propagator infrastructure benefit all three use cases.

2.  **Sound theoretical basis**: Every component has well-understood lattice-theoretic foundations. Convergence, determinism, and soundness are not hoped for but *proven* by the mathematical framework.

3.  **Incremental by construction**: Propagator networks naturally support incremental computation. When a constraint is added or retracted, only affected cells re-propagate. This is essential for interactive development (IDE integration, REPL).

4.  **Parallelizable by the CALM theorem**: Within a stratum, all propagation is monotonic and therefore coordination-free. This provides a natural path to parallel type checking and parallel logic evaluation.

5.  **Better error messages**: Dependency tracking in the ATMS means every derived fact carries its provenance. Type errors can show exactly *which* constraints are in tension and *where* they originated.


<a id="orgd199c6f"></a>

## 14. What This Architecture Doesn't Solve (Yet)

1.  **Performance**: ATMS label management has overhead. For simple deterministic programs, the ATMS layer is pure cost. We need a *bypass* for deterministic code paths that avoids the TMS entirely.

2.  **Infinite domains**: Widening operators are needed for lattices of infinite height (intervals, numeric constraints). Choosing the right widening strategy is domain-specific and sometimes tricky.

3.  **Efficiency of lattice answer modes**: When the lattice is large or the join is expensive, tabling with lattice answer modes can be slow. XSB Prolog's experience shows this requires careful implementation.

4.  **Surface syntax design**: How should logic programming syntax look in Prologos? The document proposes `relation` / `rule` / `query` but this needs design iteration. Should it integrate with `match`? With `where` constraints? With mixfix `.{...}`?

5.  **Interaction with QTT**: Logic variables are inherently shared (multiple references). How does this interact with linear types? Preliminary answer: logic variables live at multiplicity $\omega$ (unrestricted), but the *binding environment* can be linear.


<a id="orgeaeb0c9"></a>

## 15. Open Research Questions

1.  **Can ATMS label management be made zero-cost for deterministic programs?** The "speculative ATMS" idea: don't create labels until the first `amb`. Deterministic programs never pay the ATMS overhead.

2.  **How do Prologos's dependent types interact with tabling?** Tabling requires comparing calls for "variance" (same query up to renaming). With dependent types, this comparison involves type equality, which may itself require propagation. Circularity risk.

3.  **Can propagator-based elaboration subsume the current ad-hoc metavar system without performance regression?** The current system is fast because it's specialized. A general propagator system may be slower without careful optimization.

4.  **What is the right granularity for stratification?** Per-predicate? Per-SCC? Per-module? Finer granularity allows more parallelism but increases analysis cost.

5.  **How do pocket universes compose?** Can a tabled predicate call another tabled predicate? (Yes, but completion detection becomes more complex &#x2014; this is the "scheduling dependency" problem in SLG resolution.)


<a id="org26517fa"></a>

# Summary of Recommendations

| #  | Recommendation                                                   | Confidence         |
|--- |---------------------------------------------------------------- |------------------ |
| 1  | Radul-Sussman propagator model as the substrate                  | High               |
| 2  | ATMS for hypothetical reasoning (validates Multiverse Mech.)     | High               |
| 3  | Galois connections for domain modularity (validates Pocket U.)   | High               |
| 4  | SLG-style tabling with lattice answer modes                      | High               |
| 5  | Stratified evaluation for negation and aggregation               | High               |
| 6  | Start with compile-time use (elaborator), then extend to runtime | High               |
| 7  | No raw Prolog-style `!` cut; use `once` and committed choice     | Medium             |
| 8  | "Speculative ATMS" for zero-cost deterministic bypass            | Medium             |
| 9  | `Lattice` trait as foundation (user-extensible domains)          | High               |
| 10 | Surface syntax: `relation` / `rule` / `query` keywords           | Low (needs design) |

**Overall assessment**: The research strongly supports the proposed architecture. The Multiverse and Pocket Universe mechanisms are not speculative &#x2014; they are well-established techniques (ATMS worldviews and Galois connections respectively) with decades of theoretical grounding and practical implementation experience. The main risk is implementation complexity, mitigated by the phased approach starting with the elaborator refactoring.


<a id="org9c6f2a3"></a>

# References

Organized by relevance to the recommended architecture:


<a id="org6c8847e"></a>

## Foundational (Must-Read)

-   Radul & Sussman, "The Art of the Propagator" (MIT TR, 2009)
-   Radul, *Propagation Networks* (PhD thesis, MIT, 2009)
-   de Kleer, "An Assumption-Based TMS" (*AI Journal*, 1986)
-   Kuper & Newton, "LVars: Lattice-Based Data Structures for Deterministic Parallelism" (FHPC, 2013)
-   Kuper et al., "Freeze After Writing" (POPL, 2014)


<a id="org6f3ded2"></a>

## Tabling and Logic Programming

-   Swift & Warren, "XSB: Extending Prolog with Tabled Logic Programming" (*TPLP*, 2012)
-   Chen & Warren, "Tabled Evaluation with Delaying" (*JACM*, 1996)
-   Gupta et al., "Parallel Execution of Prolog Programs: A Survey" (*TOPLAS*, 2001)


<a id="orge736efd"></a>

## Lattice-Based Languages

-   Madsen et al., "From Datalog to Flix" (PLDI, 2016)
-   Arntzenius & Krishnaswami, "Datafun: A Functional Datalog" (ICFP, 2016)
-   Arntzenius & Krishnaswami, "Seminaive Evaluation for a Higher-Order Functional Language" (POPL, 2020)


<a id="orgdb0c9a3"></a>

## Theoretical Foundations

-   Tarski, "A Lattice-Theoretical Fixpoint Theorem" (*Pacific J. Math.*, 1955)
-   Cousot & Cousot, "Abstract Interpretation: A Unified Lattice Model" (POPL, 1977)
-   Denecker et al., "Approximation Fixpoint Theory" (2012)
-   Hellerstein, "Keeping CALM" (*CACM*, 2020)


<a id="orge74ee42"></a>

## Constraint Systems

-   Fruhwirth, *Constraint Handling Rules* (CUP, 2009)
-   Shapiro et al., "Conflict-Free Replicated Data Types" (INRIA, 2011)
-   Conway et al., "Logic and Lattices for Distributed Programming" (SoCC, 2012)


<a id="orgf767bb0"></a>

## Type Systems

-   Dunfield & Krishnaswami, "Bidirectional Typechecking for Higher-Rank Polymorphism" (ICFP, 2014)
-   Pottier & Remy, "The Essence of ML Type Inference" (2005)
-   Kovacs, *Elaboration Zoo* (2022)


<a id="orgc96c0e3"></a>

## Implementations

-   Holmes (Haskell): `github.com/i-am-tom/holmes`
-   Propaganda (Clojure): `github.com/tgk/propaganda`
-   Ascent (Rust): `github.com/s-arash/ascent`
-   Guanxi (Haskell): `github.com/ekmett/guanxi`
