- [Abstract](#org63db71c)
- [1. Narrowing: Two Senses, One Convergence](#orgd495469)
  - [1.1 Functional-Logic Narrowing](#orgecdc89d)
    - [Definition](#org40d2ebb)
    - [Example](#org0312167)
    - [The Narrowing Lemma](#org268c100)
  - [1.2 Needed Narrowing](#orga1dd1d2)
    - [Definitional Trees](#orgf73f6c1)
    - [Inductively Sequential Functions](#org1881c4d)
    - [The Needed Narrowing Strategy](#org2db1409)
    - [Optimality Results](#org2c51ec5)
  - [1.3 Non-Deterministic Functions and Overlapping Rules](#orga7ce436)
  - [1.4 Constraint Propagation Narrowing](#org36ad397)
    - [Arc Consistency (AC-3)](#org31eabe1)
    - [The Structural Parallel](#org54d1362)
    - [Convergence on the Propagator Substrate](#org545a610)
- [2. Search Heuristics: The Third Axis](#org50657a4)
  - [2.1 ECLiPSe's search/6: A Design Template](#org6331368)
    - [Variable Selection (Select)](#orgcd5d2ca)
    - [Value Selection (Choice)](#orga4b504a)
    - [Search Strategy (Method)](#orgb81e3f8)
    - [Options](#org72f4ff8)
  - [2.2 Gecode's Architecture: Propagate + Branch](#org3897ee6)
  - [2.3 MiniZinc: Declarative Search Annotations](#org8e8c0e4)
- [3. Current Prologos Architecture](#org7417b27)
  - [3.1 The Three Layers](#org79c7fa9)
  - [3.2 Current Search Strategy](#org4d55145)
  - [3.3 What Already Exists for Narrowing/Constraints](#org5a6a871)
- [4. Synthesis: A Unified Solver Architecture](#orgd0fbd10)
  - [4.1 The Vision](#org07a47bd)
  - [4.2 Architecture: Propagate → Branch → Propagate](#org695a353)
  - [4.3 Extended Solver Configuration](#org4304cb8)
  - [4.4 Where Heuristics Live in the Stack](#orgc425788)
  - [4.5 Domain Cells for CLP(FD)](#org659a69e)
    - [Finite Domain Cell](#orgd04246c)
    - [Interval Cell](#orgcb8b2c7)
    - [Constraint Propagators](#org3e49f1d)
  - [4.6 Narrowing Propagators for FL Functions](#org3f3a393)
- [5. Advanced Topics](#org335aac8)
  - [5.1 Residuation vs. Narrowing](#org495be55)
  - [5.2 Encapsulated Search](#org10018b8)
  - [5.3 CFLP(FD): Constraint Functional Logic Programming](#org719468b)
  - [5.4 Narrowing as Symbolic Model Checking](#org3285b76)
  - [5.5 Global Constraints](#orgb88d723)
  - [5.6 Optimization and Branch-and-Bound](#orgeb104cd)
- [6. Research Connections](#orgeda2994)
  - [6.1 Narrowing and the Propagator Network](#orgd8723b6)
  - [6.2 Connection to Abstract Interpretation](#orgefc968d)
  - [6.3 Connection to Session Types](#org903d170)
- [7. Toward Implementation: Phasing](#orgab72ac3)
  - [Phase 0: Foundations (Current)](#orge1c641f)
  - [Phase 1: Constraint Domains + Search Heuristics](#org70b3ad1)
  - [Phase 2: FL Narrowing](#orgec032c6)
  - [Phase 3: Global Constraints + Optimization](#org4064f08)
  - [Phase 4: Advanced Integration](#org20eedcb)
- [8. Related Work](#orgabc0400)
  - [Languages and Systems](#org38b4d4a)
  - [Key Papers](#org1d1eef4)
- [9. Conclusion](#org4398473)



<a id="org63db71c"></a>

# Abstract

This document surveys three converging lines of work and explores how they unify on Prologos's propagator substrate:

1.  **Narrowing** in the functional-logic programming sense (Antoy, Hanus, Curry): unification-driven evaluation of functions, enabling functions to be used as relations.
2.  **Constraint propagation and domain narrowing** in the CLP/CSP sense (arc consistency, bound consistency, global constraints): lattice-based reduction of variable domains to a fixpoint.
3.  **Configurable search heuristics** in the constraint programming sense (ECLiPSe, Gecode, MiniZinc): variable ordering, value selection, and search strategy as orthogonal, user-configurable axes.

The central thesis: Prologos's propagator network + ATMS + lattice cells already provide the computational substrate for all three. What is needed is the *connective tissue*&#x2014;the abstractions that wire narrowing steps, domain reductions, and search decisions into the existing infrastructure.


<a id="orgd495469"></a>

# 1. Narrowing: Two Senses, One Convergence


<a id="orgecdc89d"></a>

## 1.1 Functional-Logic Narrowing

Narrowing in the functional-logic (FL) programming tradition is the mechanism that unifies functional evaluation (rewriting) with logic programming (resolution/unification).


<a id="org40d2ebb"></a>

### Definition

Given a term rewriting system $R$ and a term $s$, a **narrowing step** consists of:

1.  Select a non-variable subterm $s|_p$ of $s$ at position $p$.
2.  Find a rule $l \to r$ in $R$ (renamed to share no variables with $s$).
3.  Compute the most general unifier $\sigma = mgu(s|_p, l)$.
4.  The result is $s&sigma;[r&sigma;]<sub>p</sub>$&#x2014;the term $s\sigma$ with the subterm at position $p$ replaced by $r\sigma$.

The key distinction from rewriting: rewriting requires $s|_p$ to *match* $l$ (the subterm must already be an instance of the left-hand side). Narrowing allows $s|_p$ to *unify* with $l$, which may *instantiate variables* in $s$ as a side effect.


<a id="org0312167"></a>

### Example

Consider the function:

```prologos
defn add [x y]
  | [Zero y]    := y
  | [(Suc n) y] := [Suc [add n y]]
```

**Rewriting** can evaluate `[add [Suc Zero] [Suc Zero]]` by matching the second clause and reducing step by step to `[Suc [Suc Zero]]`.

**Narrowing** can solve `[add ?X ?Y] = [Suc [Suc Zero]]` by:

-   Trying to unify `[add ?X ?Y]` with the first clause head `[add Zero ?y]`. This gives $\sigma_1 = \{X \mapsto Zero, Y \mapsto Suc(Suc(Zero))\}$. Checking: `add Zero [Suc [Suc Zero]]` reduces to `[Suc [Suc Zero]]`. Solution found.
-   Trying the second clause head `[add [Suc ?n] ?y]`. This gives $\sigma_2 = \{X \mapsto Suc(?n)\}$ and a residual goal `[Suc [add ?n ?y]] = [Suc [Suc Zero]]`, which narrows to `[add ?n ?y] = [Suc Zero]`. Recursion continues, yielding $\{X \mapsto Suc(Zero), Y \mapsto Suc(Zero)\}$ and $\{X \mapsto Suc(Suc(Zero)), Y \mapsto Zero\}$.

The function `add` has been *inverted*&#x2014;used as a relation&#x2014;without any additional definitions.


<a id="org268c100"></a>

### The Narrowing Lemma

If $s\sigma \to^*_R t$ (an instance of $s$ rewrites to $t$ in zero or more steps), then there exist terms $s'$ and $t'$ such that $s \leadsto^*_R s'$ (narrowing), $t \to^*_R t'$ (rewriting), and $t'$ is an instance of $s'$.

This ensures narrowing is *complete* for finding solutions to equational goals: any solution discoverable by rewriting is also discoverable by narrowing.


<a id="orga1dd1d2"></a>

## 1.2 Needed Narrowing

Basic narrowing is complete but wildly inefficient&#x2014;it tries all possible subterm positions and all possible rules at each step, leading to a combinatorial explosion. *Needed narrowing* (Antoy, Echahed, Hanus 1994/2000) restricts this to only the steps that are *demanded* by the computation.


<a id="orgf73f6c1"></a>

### Definitional Trees

The key data structure is the **definitional tree**, which encodes the case-analysis structure of a function definition. A definitional tree for a function $f$ of arity $n$ is a finite tree where:

-   **Rule nodes** are leaves containing a rewrite rule $l \to r$.
-   **Branch nodes** contain a *pattern variable* (the inductive position) and a set of children, one per constructor of that variable's type.
-   (Optionally) **Exempt nodes** mark positions where no rule applies.

For the `add` function above, the definitional tree is:

```
branch on arg 1:
  |
  +-- Zero    --> rule: add Zero y = y
  |
  +-- Suc n   --> rule: add (Suc n) y = Suc (add n y)
```

This tree says: "to evaluate `add X Y`, first inspect the outermost constructor of argument 1. If it's `Zero`, apply rule 1. If it's `Suc`, apply rule 2."


<a id="org1881c4d"></a>

### Inductively Sequential Functions

A function is **inductively sequential** if its defining rules can be organized into a definitional tree (i.e., the case analysis is uniform and non-overlapping). Most naturally-written functions are inductively sequential. All functions definable by nested pattern matching (without overlapping clauses or guards) are inductively sequential.


<a id="org2db1409"></a>

### The Needed Narrowing Strategy

Given a definitional tree and a goal `f(t1, ..., tn)`:

1.  Traverse the tree from root.
2.  At a branch node on position $p$: examine the subterm at position $p$.
    -   If it's a constructor: follow the matching child branch.
    -   If it's a variable: *narrow* by trying all constructors of that type (creating choice points), then continue down each branch.
    -   If it's a function application: *demand* its evaluation first (recursive narrowing).
3.  At a rule node: apply the rule (rewrite).


<a id="org2c51ec5"></a>

### Optimality Results

For inductively sequential functions, needed narrowing achieves:

1.  **Minimal derivation length**: no derivation computes a shorter successful sequence.
2.  **Independent solutions**: computed answers are pairwise incomparable (no redundant, more-general solutions).
3.  **Subsumption**: needed narrowing subsumes both lazy functional evaluation (when all arguments are ground) and SLD resolution (when functions are just constructors).

These results are proven in Antoy, Echahed, Hanus, "A Needed Narrowing Strategy," *JACM* 47(4):776&#x2013;822, 2000.


<a id="orga7ce436"></a>

## 1.3 Non-Deterministic Functions and Overlapping Rules

When function definitions have *overlapping* rules (the same input matches multiple clauses), the function is *non-deterministic*. For example:

```prologos
defn insert [x xs]
  | [x xs]       := [Cons x xs]
  | [x [Cons y ys]] := [Cons y [insert x ys]]
```

Both clauses apply when `xs` is a `Cons`. In Curry, this is handled by trying both alternatives non-deterministically (creating a choice point). The definitional tree for overlapping rules requires a generalization: the tree may have *or-nodes* where multiple branches are explored.

This is directly analogous to the `defr` semantics in Prologos, where multiple clauses create alternative derivations. Non-deterministic functions via overlapping rules are the bridge between `defn` and `defr`.


<a id="org36ad397"></a>

## 1.4 Constraint Propagation Narrowing

In constraint logic programming (CLP), "narrowing" refers to the reduction of variable domains through constraint propagation. This is a distinct but structurally analogous concept:


<a id="org31eabe1"></a>

### Arc Consistency (AC-3)

Given a constraint $C(X, Y)$ and domains $D_X$, $D_Y$:

-   For each value $x \in D_X$, check if there exists $y \in D_Y$ such that $C(x, y)$ holds.
-   Remove $x$ from $D_X$ if no such $y$ exists.
-   Repeat until no domain changes (fixpoint).

This is *domain narrowing*&#x2014;the domain shrinks monotonically until a fixpoint is reached.


<a id="org54d1362"></a>

### The Structural Parallel

| FL Narrowing                    | Constraint Narrowing                  |
|------------------------------- |------------------------------------- |
| Unify goal with rule LHS        | Constraint removes values from domain |
| Definitional tree guides choice | Arc consistency guides propagation    |
| Non-determinism $\to$ backtrack | Domain splitting $\to$ search         |
| Needed narrowing = optimal      | AC-3/BC = sound & complete            |
| `defn` clause = rewrite rule    | Constraint = propagator               |
| Variable instantiation          | Domain reduction                      |


<a id="org545a610"></a>

### Convergence on the Propagator Substrate

Both FL narrowing and constraint narrowing are instances of the same abstract operation: *monotone refinement of information about variables*. In Prologos:

-   A propagator cell holds a lattice value representing knowledge about a variable.
-   FL narrowing writes a more-specific value ("this variable has constructor `Suc`") to a cell.
-   Constraint narrowing writes a reduced domain ("[1,6] instead of [1,10]") to a cell.
-   `run-to-quiescence` propagates both kinds of refinement to a fixpoint.
-   When propagation alone can't determine a unique value, search (ATMS `amb`) introduces choice points&#x2014;analogous to both backtracking in FL narrowing and domain splitting in constraint solving.


<a id="org50657a4"></a>

# 2. Search Heuristics: The Third Axis

The previous section established that narrowing (both FL and constraint) maps naturally to propagator cell writes + quiescence. But when propagation reaches a fixpoint without fully determining all variables, *search* is needed. How search is conducted&#x2014;which variable to branch on, which value to try, how to traverse the search tree&#x2014;dramatically affects performance.


<a id="org6331368"></a>

## 2.1 ECLiPSe's search/6: A Design Template

ECLiPSe CLP's `search/6` predicate factors search into three orthogonal axes, providing a clean, composable interface:

```
search(+Vars, +Arg, +Select, +Choice, +Method, +Options)
```


<a id="orgcd5d2ca"></a>

### Variable Selection (Select)

Determines which variable to branch on next:

| Strategy                     | Description                                      |
|---------------------------- |------------------------------------------------ |
| `input_order`                | Declaration order (naive, deterministic)         |
| `first_fail`                 | Smallest domain first (most constrained)         |
| `anti_first_fail`            | Largest domain first                             |
| `most_constrained`           | Smallest domain, tiebreak by constraint count    |
| `most_constrained_per_value` | Ratio: constraint count / domain size            |
| `max_regret`                 | Largest gap between best and second-best value   |
| `max_weighted_degree`        | Learned from failures (adaptive, dom/wdeg)       |
| `max_activity`               | Most recently active in propagation (VSIDS-like) |
| `random`                     | Random selection (useful for restarts)           |

The *first-fail principle* ("to succeed, try first where you are most likely to fail") is the dominant heuristic. The intuition: if a variable has only 2 possible values, branching on it creates a binary tree. If another has 100, branching creates 100 children. Resolving the tight variable first prunes much more of the search space.

*Adaptive* heuristics like `max_weighted_degree` (dom/wdeg, Boussemart et al.

1.  learn from failures: each constraint has a weight incremented on domain

wipeout. Variables connected to high-weight constraints are preferred. This captures problem structure that static heuristics miss.


<a id="orga4b504a"></a>

### Value Selection (Choice)

Determines which value to try for the selected variable:

| Strategy                   | Description                                    |
|-------------------------- |---------------------------------------------- |
| `indomain_min`             | Try smallest value first                       |
| `indomain_max`             | Try largest value first                        |
| `indomain_median`          | Try median value                               |
| `indomain_split`           | Binary split: try $[lo, mid]$ then $(mid, hi]$ |
| `indomain_reverse_split`   | Reverse binary split                           |
| `indomain_random`          | Random value selection                         |
| `from_smaller(Pos, Hints)` | Try hinted values first (smallest bias)        |
| `from_larger(Pos, Hints)`  | Try hinted values first (largest bias)         |

The *succeed-first principle* applies here: choose values likely to appear in solutions. Binary splitting (`indomain_split`) is particularly effective for numeric domains because it reduces domains geometrically.


<a id="orgb81e3f8"></a>

### Search Strategy (Method)

Determines how the search tree is traversed:

| Strategy                    | Description                                                        |
|--------------------------- |------------------------------------------------------------------ |
| `complete`                  | Exhaustive depth-first search                                      |
| `lds(D)`                    | Limited discrepancy search (at most $D$ deviations from heuristic) |
| `bb_min(Cost)`              | Branch-and-bound minimization                                      |
| `restart(Cutoff)`           | Restart-based search (luby, geometric, random sequences)           |
| `restart_min(Cost, Cutoff)` | Optimization with restarts                                         |


<a id="org72f4ff8"></a>

### Options

Additional configuration:

| Option              | Description                            |
|------------------- |-------------------------------------- |
| `tiebreak(Select2)` | Secondary variable selection criterion |
| `timeout(Seconds)`  | Search time limit                      |
| `backtrack(N)`      | Returns number of backtracks           |
| `ldsb_syms(Syms)`   | Lightweight Dynamic Symmetry Breaking  |


<a id="org3897ee6"></a>

## 2.2 Gecode's Architecture: Propagate + Branch

Gecode cleanly separates propagation from search via *branchers*:

1.  **Propagation phase**: All propagators run to fixpoint (domain narrowing).
2.  **Branch phase**: A *brancher* examines the current state and makes a *decision* (e.g., $X \leq 5$ vs. $X > 5$). This is *not* a propagator&#x2014; it's a separate mechanism that introduces a binary choice.
3.  The solver creates two child nodes (one for each branch), and recursively applies propagation + branching.

The key insight: *propagation is deterministic and monotone*; *branching is non-deterministic and creates the search tree*. Keeping them separate allows independent optimization of each.

This maps directly to Prologos's architecture:

-   Propagation = `run-to-quiescence`
-   Branching = `atms-amb` (creates mutually exclusive assumptions)


<a id="org8e8c0e4"></a>

## 2.3 MiniZinc: Declarative Search Annotations

MiniZinc provides declarative search annotations that separate the model from the search strategy:

```minizinc
solve :: int_search(x, first_fail, indomain_min, complete)
      minimize cost;
```

This annotates the solve statement with: use `first_fail` variable ordering, `indomain_min` value selection, `complete` (DFS) tree search, and minimize `cost` via branch-and-bound. The model is independent of the search&#x2014;the same model can be solved with different strategies.


<a id="org7417b27"></a>

# 3. Current Prologos Architecture


<a id="org79c7fa9"></a>

## 3.1 The Three Layers

Prologos's logic/constraint infrastructure has three layers:

1.  **Propagator Network** (`propagator.rkt`): Pure, persistent, immutable. Cells hold lattice values with monotone merge functions. `run-to-quiescence` computes the least fixpoint.

2.  **ATMS** (`atms.rkt`): Assumption-Based Truth Maintenance. `atms-amb` creates choice points with mutually exclusive alternatives. `atms-solve-all` enumerates consistent worldviews. Nogoods prune inconsistent combinations.

3.  **Solver** (`relations.rkt` + `stratified-eval.rkt`): DFS-based relation solver. Unification, backtracking, tabling, stratified negation.


<a id="org4d55145"></a>

## 3.2 Current Search Strategy

The current solver uses:

| Component       | Strategy                         | Configurable?       |
|--------------- |-------------------------------- |------------------- |
| Clause ordering | Top-to-bottom (reader order)     | No                  |
| Fact matching   | Linear scan, try all matching    | No                  |
| Backtracking    | Exhaustive DFS via append-map    | No                  |
| Depth control   | Hard limit (100)                 | In code only        |
| Fuel limit      | 1,000,000 propagator firings     | In code only        |
| Negation        | Negation-as-failure (stratified) | No                  |
| Tabling         | SLG by default                   | Via `solver` config |
| Execution       | Sequential or BSP parallel       | Via `solver` config |

The `solver` top-level form provides some configuration:

```prologos
solver default-solver
  :execution   'parallel
  :threshold   4
  :strategy    'auto
  :tabling     'by-default
  :provenance  'none
  :timeout     #f
```

But the three ECLiPSe axes (variable ordering, value selection, search method) are entirely absent.


<a id="org5a6a871"></a>

## 3.3 What Already Exists for Narrowing/Constraints

1.  **Lattice cells**: `net-new-cell` takes arbitrary merge functions and contradiction predicates. Any lattice can be used.

2.  **Widening/narrowing support**: `net-set-widen-point`, `net-cell-write-widen`, `run-to-quiescence-widen` implement the two-phase widening→narrowing fixpoint iteration from abstract interpretation.

3.  **Cross-domain propagation**: `net-add-cross-domain-propagator` can bridge between different lattice domains (e.g., type domain ↔ multiplicity domain).

4.  **ATMS amb**: `atms-amb` already creates choice points with mutual exclusion. This is the branching mechanism.

5.  **Pattern matching infrastructure**: `defn` multi-clause syntax with `|` arms provides the definitional tree structure implicitly.

6.  **Unification**: `relations.rkt` has a Robinson unification algorithm (walk-based, substitution as hasheq).


<a id="orgd0fbd10"></a>

# 4. Synthesis: A Unified Solver Architecture


<a id="org07a47bd"></a>

## 4.1 The Vision

Unify FL narrowing, constraint propagation, and configurable search into a single architecture where:

-   **Functions are relations**: Any `defn` definition can be queried with unbound variables (via narrowing).
-   **Constraints are propagators**: CLP(FD) constraints compile to propagators on domain cells.
-   **Search is configurable**: Variable ordering, value selection, and search strategy are user-specifiable via `solver` configuration or search annotations.
-   **Everything runs on the propagator network**: Narrowing steps, constraint propagation, and search branching all expressed as operations on the persistent propagator network + ATMS.


<a id="org695a353"></a>

## 4.2 Architecture: Propagate → Branch → Propagate

The core loop, following Gecode's clean separation:

```
solve(goals, strategy):
  1. Install constraints as propagators on domain cells
  2. Install narrowing propagators for function goals
  3. LOOP:
     a. run-to-quiescence (propagation phase)
     b. IF all variables determined: RETURN solution
     c. IF contradiction: BACKTRACK (or FAIL)
     d. SELECT variable to branch on (variable ordering heuristic)
     e. SELECT value/split for that variable (value ordering heuristic)
     f. CREATE choice point via atms-amb
     g. GOTO 3a
```

Each iteration of the loop alternates between deterministic propagation (narrowing + constraint propagation running together to fixpoint) and non-deterministic branching (search heuristic picks a variable and value).


<a id="org4304cb8"></a>

## 4.3 Extended Solver Configuration

```prologos
solver my-solver
  :variable-order  first-fail    ;; or most-constrained, max-activity, ...
  :value-order     bisect        ;; or min, max, random, ...
  :search          complete      ;; or (lds 3), (bb-min cost), (restart (luby 100)), ...
  :tabling         by-default
  :provenance      full
  :timeout         30
```

This extends the existing `solver` form with the three ECLiPSe axes. The search strategy, in particular, replaces the hardcoded DFS in `solve-goals` with a pluggable control structure.


<a id="orgc425788"></a>

## 4.4 Where Heuristics Live in the Stack

| Heuristic              | Layer              | Mechanism                                  |
|---------------------- |------------------ |------------------------------------------ |
| Variable ordering      | ATMS               | Which `amb` group to resolve first         |
| Value ordering         | `amb` call         | Order of alternatives in `atms-amb`        |
| Search strategy        | Outer solve loop   | Control structure for solution enumeration |
| Constraint propagation | Propagator network | Propagators on domain cells                |
| FL narrowing           | Propagator network | Narrowing propagators on term cells        |


<a id="org659a69e"></a>

## 4.5 Domain Cells for CLP(FD)

Constraint domains require concrete lattice instantiations:


<a id="orgd04246c"></a>

### Finite Domain Cell

```racket
;; Domain: set of integers
;; Merge: intersection (narrowing = removing impossible values)
;; Contradiction: empty set
(define (fd-merge d1 d2) (set-intersect d1 d2))
(define (fd-contradiction? d) (set-empty? d))
(define fd-cell (net-new-cell net (set 1 2 3 4 5 6 7 8 9) fd-merge fd-contradiction?))
```


<a id="orgcb8b2c7"></a>

### Interval Cell

```racket
;; Domain: [lo, hi] interval
;; Merge: intersection (tighten bounds)
;; Contradiction: lo > hi
(define (interval-merge i1 i2)
  (interval (max (interval-lo i1) (interval-lo i2))
            (min (interval-hi i1) (interval-hi i2))))
(define (interval-contradiction? i)
  (> (interval-lo i) (interval-hi i)))
```


<a id="org3e49f1d"></a>

### Constraint Propagators

```racket
;; X + Y = Z: propagator watching all three cells
;; On change to any: narrow the others
(define (add-constraint-propagator net x-cell y-cell z-cell)
  (net-add-propagator net
    (list x-cell y-cell z-cell)  ;; inputs
    (list x-cell y-cell z-cell)  ;; outputs (all may be narrowed)
    (lambda (net)
      (let ([x (net-cell-read net x-cell)]
            [y (net-cell-read net y-cell)]
            [z (net-cell-read net z-cell)])
        ;; Narrow x to [z.lo - y.hi, z.hi - y.lo]
        ;; Narrow y to [z.lo - x.hi, z.hi - x.lo]
        ;; Narrow z to [x.lo + y.lo, x.hi + y.hi]
        ...))))
```


<a id="org3f3a393"></a>

## 4.6 Narrowing Propagators for FL Functions

A narrowing propagator for a `defn` function:

1.  Watches the cells for the function's arguments.
2.  Reads the definitional tree.
3.  At a branch node: checks if the argument cell has a known constructor.
    -   If yes: follows the matching branch deterministically.
    -   If no: creates an `amb` over all constructors of the argument's type.
4.  At a rule node: applies the rewrite (writes to the result cell).

```racket
;; Narrowing propagator for add(X, Y) = Z
(define (narrowing-add net x-cell y-cell z-cell)
  ;; Definitional tree: branch on x
  (let ([x-val (net-cell-read net x-cell)])
    (cond
      [(eq? x-val 'bot)
       ;; x unknown: create amb over {Zero, Suc(?)}
       ;; (deferred to search phase — install demand marker)
       net]
      [(equal? x-val 'Zero)
       ;; Rule 1: add Zero y = y → unify z with y
       (net-cell-write net z-cell (net-cell-read net y-cell))]
      [(and (pair? x-val) (equal? (car x-val) 'Suc))
       ;; Rule 2: add (Suc n) y = Suc (add n y)
       ;; Create recursive narrowing for add(n, y) = z'
       ;; Then z = Suc z'
       ...])))
```


<a id="org335aac8"></a>

# 5. Advanced Topics


<a id="org495be55"></a>

## 5.1 Residuation vs. Narrowing

Curry supports two evaluation strategies for functions with unbound arguments:

-   **Narrowing**: Non-deterministically instantiate the variable and continue. Sound and complete, but may create many choice points.
-   **Residuation**: *Suspend* evaluation until the variable is bound by another part of the computation. Deterministic but may deadlock if the variable is never bound.

Prologos's propagator network naturally supports *residuation*: a propagator whose input cell is `bot` simply doesn't fire. When another propagator writes to that cell, the first propagator fires. This is demand-driven evaluation via the propagator dependency graph.

The combination of residuation (wait for information) and narrowing (guess when waiting would deadlock) is the operational strategy used by Curry's PAKCS system. In Prologos, this could be:

1.  During propagation: residuate (don't narrow; wait for information).
2.  At the branching phase (after quiescence): if unresolved demands remain, narrow by creating `amb` choices.


<a id="org10018b8"></a>

## 5.2 Encapsulated Search

Curry's `allValues` and `oneValue` provide encapsulated search: the non-determinism of narrowing is captured as a data structure rather than leaking into the caller. This is analogous to Prologos's `solve` form, which returns a sequence of all solutions.

The interaction between encapsulated search and constraint solving is subtle: constraints inside an encapsulated search should be local to that search scope. Prologos's persistent propagator network handles this naturally: each search branch gets an immutable snapshot of the network, and local modifications don't affect other branches.


<a id="org719468b"></a>

## 5.3 CFLP(FD): Constraint Functional Logic Programming

The CFLP framework (Fernandez, Hortala-Gonzalez, et al.) unifies all three paradigms: functional evaluation, logic programming, and finite domain constraints. The key innovation is the *Constraint Lazy Narrowing Calculus* (CLNC), which extends needed narrowing with constraint propagation:

-   Narrowing steps may generate constraints (e.g., narrowing `X + Y = 7` generates the constraint $X + Y = 7$ rather than enumerating all pairs).
-   Constraint propagation narrows domains (e.g., $X \in [1,6]$).
-   The search phase splits domains when propagation reaches fixpoint.

This is exactly the architecture described in §4.2, instantiated with FD constraints.


<a id="org3285b76"></a>

## 5.4 Narrowing as Symbolic Model Checking

Maude uses narrowing for *symbolic reachability analysis*: given a rewrite theory $R$ and an initial pattern $t$ with variables, narrowing computes all terms reachable from any instance of $t$. This is symbolic model checking&#x2014; the state space is explored symbolically rather than enumeratively.

This connects directly to our "Propagators as Model Checkers" research: the propagator network's fixpoint computation IS narrowing IS model checking. Adding explicit narrowing to Prologos would make the model checking capability more explicit and more powerful:

-   *Safety properties* (AG $\phi$): checked by propagation to fixpoint (already implemented).
-   *Reachability* (EF $\phi$): checked by narrowing from a pattern with variables (new).
-   *Bounded liveness* (AF $\phi$): checked by fuel-indexed narrowing (new).


<a id="orgb88d723"></a>

## 5.5 Global Constraints

Modern constraint solvers achieve practical performance through *global constraints*&#x2014;specialized propagators that exploit problem structure:

| Constraint               | Propagation                                            | Application             |
|------------------------ |------------------------------------------------------ |----------------------- |
| `all-different(Xs)`      | Bound consistency (Puget 1998) / matching (Regin 1994) | Scheduling, assignment  |
| `cumulative(Tasks, Cap)` | Timetable, energetic reasoning                         | Resource scheduling     |
| `table(Xs, Tuples)`      | GAC via bit-set intersection                           | Extensional constraints |
| `element(I, List, V)`    | AC on index→value                                      | Array access            |
| `circuit(Xs)`            | SCC-based filtering                                    | TSP, routing            |

These compile to specialized propagators that achieve stronger consistency than decomposition into binary constraints. In Prologos, each global constraint would be a propagator factory: given the constraint parameters, it creates a propagator with the appropriate cell dependencies and narrowing behavior.


<a id="orgeb104cd"></a>

## 5.6 Optimization and Branch-and-Bound

For optimization problems (`minimize`, `maximize`), the search strategy changes fundamentally: instead of finding all solutions, we maintain a *best-so-far* bound and prune branches that can't improve on it.

In the propagator architecture:

1.  Maintain a `cost-bound` cell (initially $+\infty$).
2.  When a solution is found with cost $c$: write $c$ to `cost-bound` (monotone decrease).
3.  Propagators watching `cost-bound` narrow the cost variable's domain to $[lo, c-1]$, which may trigger further domain narrowing.
4.  If the cost variable's domain becomes empty: prune this branch.

The propagator network makes branch-and-bound natural: the cost bound IS a lattice cell, and cost-pruning IS just another propagator.


<a id="orgeda2994"></a>

# 6. Research Connections


<a id="orgd8723b6"></a>

## 6.1 Narrowing and the Propagator Network

The deep connection: a propagator network running to quiescence IS narrowing.

-   Each cell represents partial knowledge about a variable.
-   Each propagator is a rewrite rule that fires when its inputs have sufficient information.
-   `run-to-quiescence` computes the narrowing derivation to normal form.
-   `atms-amb` introduces choice points when narrowing is non-deterministic.

The difference from Curry's implementation (PAKCS compiles to Prolog, KiCS2 compiles to Haskell) is that Prologos's narrowing would be *parallel and incremental* by construction&#x2014;propagators can fire in any order (BSP parallel scheduler), and adding new constraints only re-evaluates affected propagators.


<a id="orgefc968d"></a>

## 6.2 Connection to Abstract Interpretation

The widening/narrowing operators in `propagator.rkt` implement a two-phase iteration from abstract interpretation:

1.  **Widening phase**: over-approximate to force convergence (ascending Kleene chain with widening at limit points).
2.  **Narrowing phase**: recover precision by descending from the widened fixpoint.

This is the *lattice-theoretic* sense of narrowing, distinct from both FL narrowing and constraint narrowing, but all three share the same algebraic structure: monotone refinement on a lattice toward a fixpoint.


<a id="org903d170"></a>

## 6.3 Connection to Session Types

Session types provide *ordering* on effects (see "Session Types as Causal Timelines"). Narrowing provides *instantiation* of symbolic terms. Combined:

-   A session type `!A . ?B . end` with type variables `A`, `B` can be *narrowed* to find all valid instantiations (useful for protocol synthesis).
-   Constraint propagation can narrow the valid session types for a channel based on observed behavior (useful for session type inference).
-   The propagator network serves as the shared substrate for both temporal ordering (session types) and value refinement (narrowing).


<a id="orgab72ac3"></a>

# 7. Toward Implementation: Phasing


<a id="orge1c641f"></a>

## Phase 0: Foundations (Current)

What exists today:

-   Propagator cells with lattice merge (*constraint narrowing substrate*)
-   ATMS with `amb` (*search branching substrate*)
-   `defn` multi-clause syntax (*definitional tree structure, implicit*)
-   Unification in `relations.rkt` (*FL narrowing primitive*)
-   Widening/narrowing operators (*abstract interpretation integration*)
-   `solver` configuration (*extensible framework*)


<a id="org70b3ad1"></a>

## Phase 1: Constraint Domains + Search Heuristics

-   Finite domain cells (set-based and interval-based)
-   Basic constraint propagators (equality, inequality, arithmetic)
-   Variable ordering: first-fail, most-constrained
-   Value ordering: min, max, bisect
-   Search strategies: complete, LDS, branch-and-bound
-   Extended `solver` configuration with three new axes


<a id="orgec032c6"></a>

## Phase 2: FL Narrowing

-   Definitional tree extraction from `defn` definitions
-   Narrowing propagator factory (definitional tree → propagator)
-   Residuation support (propagators that wait for input)
-   Integration of narrowing with constraint propagation
-   `defn` functions usable in `solve` goals


<a id="org4064f08"></a>

## Phase 3: Global Constraints + Optimization

-   `all-different`, `cumulative`, `table` global constraint propagators
-   Branch-and-bound optimization (`minimize`, `maximize`)
-   Restart-based search with learning (dom/wdeg, activity)
-   LDSB symmetry breaking


<a id="org20eedcb"></a>

## Phase 4: Advanced Integration

-   CFLP(FD): unified constraint-functional-logic evaluation
-   Narrowing-based symbolic model checking (reachability analysis)
-   Partial evaluation / narrowing-driven specialization
-   Custom propagator definition in Prologos (user-defined constraints)


<a id="orgabc0400"></a>

# 8. Related Work


<a id="org38b4d4a"></a>

## Languages and Systems

-   **Curry** (Hanus et al.): The canonical functional-logic language. PAKCS compiles to Prolog; KiCS2 compiles to Haskell. Supports needed narrowing, residuation, encapsulated search, and finite domain constraints.
-   **ECLiPSe** (IC-Parc): CLP system with `search/6` providing configurable search. Integration of finite domains, interval arithmetic, and global constraints.
-   **Gecode** (Schulte, Tack, Lagerkvist): C++ constraint programming library. Clean propagator/brancher separation. Used as backend for MiniZinc.
-   **MiniZinc** (Nethercote et al.): Constraint modeling language with solver- independent search annotations.
-   **Maude** (Clavel et al.): Rewriting logic system with narrowing for symbolic reachability and model checking.
-   **Mercury** (Somogyi et al.): Logic/functional language with mode and determinism declarations.
-   **TOY(FD)** (Fernandez et al.): CFLP(FD) implementation integrating functional-logic programming with finite domain constraints.
-   **Oz/Mozart**: Multiparadigm language with constraint programming, search strategies (first-fail, etc.), and spaces (encapsulated search).


<a id="org1d1eef4"></a>

## Key Papers

-   Antoy, Echahed, Hanus. "A Needed Narrowing Strategy." *JACM* 47(4), 2000.
-   Antoy. "Definitional Trees." *ALP* 1992.
-   Antoy. "Evaluation Strategies for Functional Logic Programming." *JSC* 2005.
-   Antoy, Hanus. "Functional Logic Programming." *CACM* 53(4), 2010.
-   Fernandez et al. "Constraint Functional Logic Programming over Finite Domains." *TPLP* 7(1-2), 2007.
-   Boussemart et al. "Boosting Systematic Search by Weighting Constraints." *ECAI* 2004. (dom/wdeg heuristic)
-   Schulte, Stuckey. "Efficient Constraint Propagation Engines." *TOPLAS* 2008.
-   Escobar, Meseguer. "Symbolic Model Checking of Infinite-State Systems Using Narrowing." *RTA* 2007.
-   Harvey, Ginsberg. "Limited Discrepancy Search." *IJCAI* 1995.
-   Regin. "A Filtering Algorithm for Constraints of Difference." *AAAI* 1994. (`all-different` global constraint)


<a id="org4398473"></a>

# 9. Conclusion

Narrowing, constraint propagation, and search heuristics are three perspectives on the same fundamental problem: how to efficiently explore a space of possible variable assignments subject to constraints. Prologos's propagator network + ATMS provides the right substrate for all three:

-   Propagation = deterministic narrowing (both FL and constraint).
-   Branching = non-deterministic narrowing (choice points via ATMS `amb`).
-   Search heuristics = branching *policy* (which variable, which value, which tree traversal).

The path forward is incremental: constraint domains and search heuristics (Phase 1) can be added without changing the core architecture. FL narrowing (Phase 2) requires definitional tree extraction and narrowing propagators but builds on the same substrate. The full CFLP integration (Phases 3&#x2013;4) extends both, making Prologos a language where every function is a relation, every relation is a constraint network, and every constraint network is searched with user-configurable heuristics.

This is the vision of a language that doesn't choose between functional, logic, and constraint programming&#x2014;it unifies them on a single, well-understood, algebraically principled substrate.
