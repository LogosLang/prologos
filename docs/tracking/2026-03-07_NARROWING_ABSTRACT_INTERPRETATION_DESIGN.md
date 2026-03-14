- [Abstract](#orgf08d9b9)
- [Progress Tracker](#orgfcdd78e)
- [1. Phase 2: Abstract Interpretation for Narrowing](#org6c4f03a)
  - [1.1 The Problem: Infinite Constructor Universes](#org07a9bb9)
  - [1.2 Architecture: Galois Connections as Cross-Domain Propagators](#orgde7f178)
  - [1.3 Phase 2a: Interval Abstract Domain](#orgb59317b)
    - [1.3.1 Design](#orgae4bb61)
    - [1.3.2 Galois Connection: Term Cells $\leftrightarrow$ Interval Cells](#orgece87ed)
    - [1.3.3 Integration with Narrowing Propagator](#org328e75b)
    - [1.3.4 Implementation](#orga4010f9)
    - [1.3.5 Tests](#org1b5c0de)
  - [1.4 Phase 2b: Size-Based Termination Analysis](#org1e97073)
    - [1.4.1 The Problem](#org456cbcc)
    - [1.4.2 Size-Based Abstract Domain](#org4fe497d)
    - [1.4.3 Analysis Algorithm](#orgfe92f9e)
    - [1.4.4 Integration with Narrowing](#orgfae1f81)
    - [1.4.4a Domain-Bounded Fuel Estimation (2a + 2b Interaction)](#org86e7ed8)
    - [1.4.5 Widening for Non-Terminating Abstract Fixpoints](#org125deac)
    - [1.4.6 Implementation](#orgb497377)
    - [1.4.7 Tests](#orgfeec2d4)
  - [1.5 Phase 2c: Critical Pair Analysis for Confluence](#orge5fc4b8)
    - [1.5.1 The Problem: Church-Rosser Property](#org2d23638)
    - [1.5.2 Critical Pair Analysis](#org88408eb)
    - [1.5.3 Analysis Algorithm](#orgffc86ab)
    - [1.5.4 Integration](#orgf5803bb)
    - [1.5.5 Implementation](#orga0f48a4)
    - [1.5.6 Tests](#orgcc4df8d)
  - [1.6 Phase 2 Summary](#org0839413)
  - [1.7 Phase 2 Dependencies and Ordering](#org6414e59)
- [2. Phase 3: Advanced Extensions](#org1459c1e)
  - [2.1 Phase 3a: 0-CFA Closure Analysis for Auto-Defunctionalization](#org8a56d23)
    - [2.1.1 The Problem: Higher-Order Narrowing](#org4a1a21d)
    - [2.1.2 0-CFA Overview](#org49f1712)
    - [2.1.3 Connection to Defunctionalization](#org078d3c0)
    - [2.1.4 Implementation](#orgce23896)
    - [2.1.5 Scope: Demand-Driven Analysis](#org602fbad)
    - [2.1.6 Implementation](#org756c390)
    - [2.1.7 Tests](#org7f4637c)
  - [2.2 Phase 3b: Configurable Search Heuristics](#org4650d55)
    - [2.2.1 Design: Three Orthogonal Axes](#orgb363df0)
    - [2.2.2 Variable Ordering Strategies](#org256ded1)
    - [2.2.3 Value Ordering Strategies](#org7a1fe35)
    - [2.2.4 Search Strategies](#orgef46ce7)
    - [2.2.5 Search Strategy Integration](#orgb89d3e3)
    - [2.2.6 Implementation](#orgc75e4d6)
    - [2.2.7 Tests](#orgd326a0f)
  - [2.3 Phase 3c: Global Constraints and Optimization](#orgf3162b3)
    - [2.3.1 Global Constraint Propagators](#org9ba6640)
    - [2.3.2 `all-different` Implementation](#org334d799)
    - [2.3.3 Branch-and-Bound Optimization](#orgf8aa29c)
    - [2.3.4 Implementation](#orgb508d0d)
    - [2.3.5 Tests](#orgb19d450)
  - [2.4 Phase 3 Summary](#org8133ef1)
  - [2.5 Phase 3 Dependencies and Ordering](#org8bfb9f7)
- [3. Unified Roadmap: Phases 1&#x2013;3](#org7bee722)
  - [3.1 Complete Implementation Table](#org0fe4e17)
  - [3.2 Dependency Graph](#org06c860d)
  - [3.3 Recommended Implementation Sequence](#org6b187a6)
- [4. Surface Syntax for Extended Features](#orgb923ca4)
  - [4.1 Solver Configuration](#orgca72f34)
  - [4.2 Constraint Syntax](#org431544e)
  - [4.3 Static Analysis Feedback](#org67bcb58)
- [5. Interaction Between Phases](#org47f7c4e)
  - [5.1 Interval Domains + Search Heuristics (2a + 3b)](#orgf2c4209)
  - [5.2 Termination Analysis + Interval Domains (2b + 2a)](#org9e6e63d)
  - [5.3 0-CFA + Narrowing Propagator (3a + 1c)](#org8afec32)
  - [5.4 Confluence + Termination (2c + 2b)](#orgc813c91)
  - [5.5 Global Constraints + Narrowing (3c + 1c)](#orgbaff0f7)
  - [5.6 Narrowing and Effects (Pure Fragment Only)](#orgea79cf7)
- [6. Open Research Questions](#orge773441)
  - [6.1 Phase 2 Open Questions](#orge6157e0)
  - [6.2 Phase 3 Open Questions](#org680527c)
- [7. Connection to Existing Research Documents](#org2d71d78)
- [8. Design Decisions](#orga73c4ef)
  - [DD-1: Interval Domain as First Abstract Domain](#orgef034c7)
  - [DD-2: LJBA Termination over Dependency Pairs](#orgc55f88e)
  - [DD-3: Demand-Driven 0-CFA](#org44c506c)
  - [DD-4: Bound Consistency for `all-different`](#orge489597)
  - [DD-5: Existing Widening Infrastructure](#orgdf0088f)
  - [DD-6: Existing Cross-Domain Propagator Infrastructure](#org29618b8)
  - [DD-7: Search Heuristics as Solver Config Extensions](#orgb409ab4)
  - [DD-8: Static Analyses at Elaboration Time](#orgd0d1909)
  - [DD-9: Narrowing Over the Pure Fragment](#org88093dc)
- [9. Related Work](#org0e9070c)
  - [Abstract Interpretation](#org6ede2fa)
  - [Termination Analysis](#orgf8a3c6b)
  - [Confluence and Critical Pairs](#org2797e10)
  - [Control Flow Analysis](#org6a81392)
  - [Constraint Programming](#orgae94f21)
  - [Functional-Logic Programming](#org529feb4)
- [10. Conclusion](#org1aab061)



<a id="orgf08d9b9"></a>

# Abstract

This document is the Phase 2&#x2013;3 implementation design companion to the FL Narrowing Phase 0&#x2013;1 design document. Where Phase 1 establishes the core narrowing machinery (definitional trees, term lattice, narrowing propagator, solver integration), Phases 2&#x2013;3 extend it with:

-   **Phase 2: Abstract Interpretation for Narrowing** &#x2014; Galois connections between concrete term cells and abstract domain cells, interval abstract domains for infinite constructor universes, size-based termination analysis, and confluence checking via critical pair analysis.

-   **Phase 3: Advanced Extensions** &#x2014; 0-CFA closure analysis for auto-defunctionalization of higher-order narrowing, configurable search heuristics (variable ordering, value selection, search strategy), global constraints, and branch-and-bound optimization.

Together, Phases 1&#x2013;3 deliver a unified solver where every `defn` is a relation, constraints flow from types, search is configurable, and abstract interpretation tames infinite domains and guarantees termination.

**Prerequisites**: Phase 1 (core FL narrowing) must be complete before Phase 2. Phase 2 and Phase 3 are largely independent and can proceed in parallel, except that 0-CFA (Phase 3a) builds on the narrowing propagator from Phase 1c.


<a id="orgfcdd78e"></a>

# Progress Tracker

| Phase | Sub-phase | Description                           | Status | Commit    | Notes                                                                                                       |
|----- |--------- |------------------------------------- |------ |--------- |----------------------------------------------------------------------------------------------------------- |
| 1     | 1a        | Definitional Tree Extraction          | ✅     | `99e56a8` | `definitional-tree.rkt` ~200 lines, 39 tests                                                                |
| 1     | 1a+       | Pattern defn → DT integration         | ✅     | `3bd6cc8` | Verified: pattern clauses produce correct DTs                                                               |
| 1     | 1b        | Term Lattice                          | ✅     | `4a7e215` | `term-lattice.rkt` 226 lines, 49 tests                                                                      |
| 1     | 1c        | Narrowing Propagator                  | ✅     | `77f4a5d` | `narrowing.rkt` 275 lines, 31 tests                                                                         |
| 1     | 1d        | Solver Integration                    | ✅     | `36831ed` | `narrowing.rkt` +400 lines, `reduction.rkt` +30, `elaborator.rkt` +15; 22+24 tests                          |
| 1     | 1e        | WS-Mode Syntax (`?` variables, `=\=`) | ✅     | `3062b4c` | 13 files, 24 tests; syntax pipeline only                                                                    |
| 2     | 2a        | Interval Abstract Domain              | ✅     | `6301d69` | `interval-domain.rkt` ~250 lines, `narrowing-abstract.rkt` ~130 lines, `narrowing.rkt` +90 lines, 43 tests  |
| 2     | 2a+       | Length-Interval Domain (List/String)  | ⬚      |           | Future enhancement                                                                                          |
| 2     | 2b        | Size-Based Termination (LJBA)         | ✅     | `bae2fb4` | `termination-analysis.rkt` ~300 lines, `narrowing.rkt` +50, 45 tests                                        |
| 2     | 2c        | Critical Pair / Confluence Analysis   | ✅     | `3d3c0ce` | `confluence-analysis.rkt` ~200 lines, `narrowing.rkt` +20, 58 tests                                         |
| 3     | 3a        | 0-CFA Auto-Defunctionalization        | ✅     | `cdb6176` | `cfa-analysis.rkt` ~285 lines, `narrowing.rkt` +110, `solver.rkt` +11, `definitional-tree.rkt` +8; 23 tests |
| 3     | 3b        | Configurable Search Heuristics        | ✅     | `fdda370` | `search-heuristics.rkt` ~140 lines, `solver.rkt` +12, `narrowing.rkt` +20, 41 tests                         |
| 3     | 3c        | Global Constraints + BB Optimization  | ✅     | `16dd1ac` | `global-constraints.rkt` ~200 lines, `bb-optimization.rkt` ~100 lines, `narrowing.rkt` +40, 49 tests        |

**Totals**: Phase 1 ~950 lines / ~200 tests. Phase 2 ~1,270 lines / ~250 tests. Phase 3 ~1,560 lines / ~270 tests. Grand total ~3,780 lines / ~720 tests.


<a id="org6c4f03a"></a>

# 1. Phase 2: Abstract Interpretation for Narrowing


<a id="org07a9bb9"></a>

## 1.1 The Problem: Infinite Constructor Universes

Phase 1's narrowing machinery works cleanly for finite ADTs: when a branch node in the definitional tree encounters a variable, it creates an `amb` over all constructors. For `Bool` (2 constructors) or `[List A]` (2: `Nil`, `Cons`), this is tractable.

But for `Nat`, `Int`, `String`, or any type with infinitely many inhabitants, enumerating all constructors is impossible. Without abstract interpretation:

-   `[add ?x ?y] = 13N` would try `?x :` Zero=, `?x :` Suc(Zero)=, `?x :` Suc(Suc(Zero))=, &#x2026; up to 14 alternatives for just the first argument.
-   `[mul ?x ?y] = 100N` would enumerate 100+ alternatives.
-   Functions over `String` or `Int` would be completely impractical.

Abstract interpretation solves this: instead of enumerating concrete values, we work in an *abstract domain* that finitely over-approximates the concrete domain, then narrow the abstract domain using constraint propagation.


<a id="orgde7f178"></a>

## 1.2 Architecture: Galois Connections as Cross-Domain Propagators

The key insight: Prologos already implements Galois connections as cross-domain propagators (`net-add-cross-domain-propagator` in `propagator.rkt`). The existing pattern:

```
net-add-cross-domain-propagator(net, concrete-cell, abstract-cell, alpha, gamma)
  creates two propagators:
    alpha: concrete-cell -> abstract-cell   (abstraction)
    gamma: abstract-cell -> concrete-cell   (concretization)
```

This is used today for the Type $\leftrightarrow$ Multiplicity bridge (`elaborator-network.rkt` line 894). For abstract interpretation in narrowing, we use the same pattern:

```
Term Cell (concrete)  <--alpha/gamma-->  Interval Cell (abstract)

alpha: Ctor(Suc, [Ctor(Suc, [Ctor(Zero)])]) --> [2, 2]
gamma: [3, 7] --> {Ctor(Suc^n, [Ctor(Zero)]) | 3 <= n <= 7}

Cross-domain propagation:
  When the interval cell narrows [0, 100] to [3, 7]:
    gamma fires, writes constrained constructor set to term cell
  When the term cell learns Ctor(Suc, _):
    alpha fires, writes [1, infinity) to interval cell (at least 1)
```

The Galois connection requirements ($\alpha \circ \gamma \geq id$ and $\gamma \circ \alpha \leq id$) ensure soundness: no valid solutions are lost, and abstract information correctly constrains concrete narrowing.


<a id="orgb59317b"></a>

## 1.3 Phase 2a: Interval Abstract Domain


<a id="orgae4bb61"></a>

### 1.3.1 Design

A new module `interval-domain.rkt` implementing:

```racket
;; Interval bounds (extended integers)
;; -inf, +inf for unbounded; concrete integers for bounded
(struct interval (lo hi) #:transparent)

;; Lattice operations
interval-bot       ;; = entire type domain (no constraint)
interval-top       ;; = empty (contradiction)
interval-merge     ;; intersection: [max(lo1,lo2), min(hi1,hi2)]
interval-contradicts?  ;; lo > hi

;; Arithmetic operations (interval arithmetic)
interval-add       ;; [a,b] + [c,d] = [a+c, b+d]
interval-sub       ;; [a,b] - [c,d] = [a-d, b-c]
interval-mul       ;; [a,b] * [c,d] = [min(ac,ad,bc,bd), max(ac,ad,bc,bd)]
interval-negate    ;; -[a,b] = [-b,-a]

;; Domain operations
interval-split     ;; [a,b] -> ([a,mid], [mid+1,b]) for search branching
interval-singleton? ;; lo = hi (determined)
interval-size      ;; hi - lo + 1 (for first-fail heuristic)
interval-contains? ;; value in [lo, hi]

;; Constraint propagators (installed as propagator functions)
interval-eq-propagator   ;; X = Y: intersect domains
interval-neq-propagator  ;; X /= Y: if one is singleton, remove from other
interval-leq-propagator  ;; X <= Y: X.hi := min(X.hi, Y.hi), Y.lo := max(Y.lo, X.lo)
interval-add-propagator  ;; X + Y = Z: narrow all three using interval arithmetic
interval-mul-propagator  ;; X * Y = Z: narrow all three
```


<a id="orgece87ed"></a>

### 1.3.2 Galois Connection: Term Cells $\leftrightarrow$ Interval Cells

For numeric types (`Nat`, `Int`, `PosInt`, `Rat`):

```racket
;; Alpha: Term -> Interval
;; Given a term cell value, compute the interval it represents
(define (term->interval-alpha term-val type-info)
  (match term-val
    ['bot  (type-initial-interval type-info)]  ;; full domain from type
    [(term-var _) (type-initial-interval type-info)]
    [(term-ctor 'Zero '()) (interval 0 0)]
    [(term-ctor 'Suc (list sub))
     (let ([sub-int (term->interval-alpha sub type-info)])
       (interval-add sub-int (interval 1 1)))]
    ;; Literal integers
    [(? integer? n) (interval n n)]
    ;; Unknown constructor — full domain
    [_ (type-initial-interval type-info)]))

;; Gamma: Interval -> Term constraint
;; Given an interval, constrain what constructors are valid
(define (interval->term-gamma int-val type-info)
  (cond
    [(interval-singleton? int-val)
     ;; Exactly one value — construct the concrete term
     (integer->nat-term (interval-lo int-val))]
    [(interval-contradicts? int-val)
     'top]  ;; contradiction
    [else
     ;; Range — can't determine exact constructor, but can
     ;; constrain: if [3, 7], then at least Suc(Suc(Suc(_)))
     ;; This partial information narrows the term cell
     (interval-to-partial-term int-val type-info)]))

;; Type-specific initial intervals
(define (type-initial-interval type-info)
  (match (type-info-name type-info)
    ['Nat    (interval 0 +inf.0)]
    ['PosInt (interval 1 +inf.0)]
    ['Int    (interval -inf.0 +inf.0)]
    ['Rat    (interval -inf.0 +inf.0)]
    [_ (error "no interval domain for type")]))
```


<a id="org328e75b"></a>

### 1.3.3 Integration with Narrowing Propagator

When a narrowing propagator encounters a branch on a numeric type:

1.  Instead of creating an `amb` over infinitely many constructors, create an *interval cell* for the variable via the Galois connection.
2.  Install interval constraint propagators based on the function body.
3.  Run propagation to narrow the interval.
4.  At the branching phase:
    -   If the interval is a singleton: bind the variable directly (no search).
    -   If the interval is finite and small ($|D| \leq$ threshold): create `amb` over the concrete values.
    -   If the interval is large: use `interval-split` (binary search) via `amb` with two alternatives: $[lo, mid]$ and $[mid+1, hi]$.
    -   If the interval is infinite: widen to force convergence, then narrow.

```
narrowing-add(?x, ?y, 13):
  1. Create interval cells: ix = [0, +inf), iy = [0, +inf)
  2. Install: interval-add-propagator(ix, iy, iz=[13,13])
  3. Propagation narrows: ix = [0, 13], iy = [0, 13]
  4. Branching: split ix → [0, 6] | [7, 13]
     Each branch propagates further...
  5. Eventually: 14 solutions found, each with ix=[k,k], iy=[13-k,13-k]
```


<a id="orga4010f9"></a>

### 1.3.4 Implementation

| Component                                           | File                     | Lines (est.) | Tests (est.) |
|--------------------------------------------------- |------------------------ |------------ |------------ |
| Interval struct + lattice ops                       | `interval-domain.rkt`    | 120          | 25           |
| Interval arithmetic                                 | `interval-domain.rkt`    | 80           | 20           |
| Interval constraint propagators                     | `interval-domain.rkt`    | 100          | 20           |
| Galois connection (term $\leftrightarrow$ interval) | `narrowing-abstract.rkt` | 150          | 25           |
| Narrowing propagator integration                    | `narrowing.rkt` (modify) | 80           | 15           |
| **Sub-total Phase 2a**                              | **2 new + 1 modified**   | **~530**     | **~105**     |


<a id="org1b5c0de"></a>

### 1.3.5 Tests

-   Interval lattice properties: idempotent, commutative, associative merge
-   Interval arithmetic: add, sub, mul correctness with boundary cases
-   Galois connection soundness: $\alpha(\gamma(x)) \geq x$ and $\gamma(\alpha(t)) \leq t$
-   `[add ?x ?y] = 13N` with interval narrowing → 14 solutions
-   `[mul ?x ?y] = 12N` with interval narrowing → 6 solutions (1\*12, 2\*6, etc.)
-   PosInt domain: `[add ?x ?y] = 5N` with `spec ... : PosInt -> PosInt -> PosInt` → only 4 solutions (1+4, 2+3, 3+2, 4+1)
-   Interval splitting for large domains
-   Singleton detection and direct binding


<a id="org1e97073"></a>

## 1.4 Phase 2b: Size-Based Termination Analysis


<a id="org456cbcc"></a>

### 1.4.1 The Problem

Recursive narrowing may not terminate. Consider:

```prologos
defn f [x] := [f [Suc x]]    ;; diverges on any input
```

Narrowing `[f ?x] = 5N` would recurse infinitely. We need to *statically* detect potential non-termination and either: (a) reject the function as non-narrowable, or (b) insert fuel bounds, or (c) use widening to force convergence.


<a id="org4fe497d"></a>

### 1.4.2 Size-Based Abstract Domain

Following Chin & Khoo (2001) and Lee, Jones & Ben-Amram (2001), we define a *size-based abstract domain* that tracks how argument sizes change across recursive calls:

```racket
;; Size abstraction
(struct size-info (dimension change) #:transparent)
;; dimension: which argument
;; change: 'decreasing | 'non-increasing | 'increasing | 'unknown

;; Size order: a partial order on size-info
;; decreasing < non-increasing < unknown
;; increasing is incomparable with decreasing

;; Size matrix for a function: rows = recursive calls, cols = arguments
;; M[i,j] = how argument j changes in recursive call i
;; Example for add:
;;   add(Suc(n), y) → add(n, y)
;;   M = [[decreasing, non-increasing]]
;;   Column 1 strictly decreases → termination guaranteed
```


<a id="orgfe92f9e"></a>

### 1.4.3 Analysis Algorithm

```
analyze-termination(def-tree, clauses):
  1. For each recursive call in each clause:
     a. Compare actual args with formal params
     b. Determine size change per argument:
        - Ctor(tag, [x]) where x is a subterm of param → 'decreasing
        - Same variable as param → 'non-increasing
        - Ctor wrapping param → 'increasing
        - Otherwise → 'unknown
  2. Build the size-change matrix M
  3. Check the Lee-Jones-Ben-Amram (LJBA) criterion:
     For every idempotent matrix in the transitive closure of M,
     at least one diagonal entry must be 'decreasing
  4. Verdict:
     - LJBA satisfied → definitely terminates (safe for unrestricted narrowing)
     - Not satisfied → potentially non-terminating:
       a. If some column is non-increasing: use fuel (bounded narrowing)
       b. If all columns are unknown: reject as non-narrowable
```


<a id="orgfae1f81"></a>

### 1.4.4 Integration with Narrowing

The termination analysis is a *compile-time* static analysis, run once per `defn` during elaboration (alongside definitional tree extraction):

```racket
;; Stored in function metadata alongside the definitional tree
(struct narrowing-info
  (def-tree           ;; definitional tree (from Phase 1a)
   termination-class  ;; 'terminating | 'bounded | 'non-narrowable
   size-matrix        ;; the size-change matrix
   fuel-bound)        ;; #f or Nat (estimated bound for 'bounded class)
  #:transparent)
```

When the narrowing propagator encounters a recursive call:

-   `terminating`: proceed normally (guaranteed to finish).
-   `bounded`: decrement fuel counter; fail (contradiction) if fuel exhausted.
-   `non-narrowable`: residuate (don't narrow; wait for the variable to be bound by another constraint). Emit a warning/note if the user explicitly requested narrowing.


<a id="org86e7ed8"></a>

### 1.4.4a Domain-Bounded Fuel Estimation (2a + 2b Interaction)

When Phase 2a's interval domain is available, `bounded` functions can compute *dynamic* fuel bounds from the concrete domain size rather than using a fixed default. If a function's argument has interval domain $[a, b]$ with finite $b - a$, and the size-change matrix shows non-increasing recursion on that argument, then the maximum recursion depth is bounded by $b - a + 1$.

```
defn f [x] := [f [sub x 1N]]   ;; size-change: non-increasing (not structurally decreasing)
                                ;; classified as 'bounded

;; Without interval domain: fuel = fixed default (e.g., 1000)
;; With interval domain ?x ∈ [3, 7]: fuel = 7 - 3 + 1 = 5
```

This is computed at narrowing time (not elaboration time) since the interval domain is only known after constraint propagation narrows it. The narrowing propagator checks: if the function is `bounded` AND the relevant argument has a finite interval domain, compute fuel from the domain size. Otherwise, fall back to the default fuel bound.


<a id="org125deac"></a>

### 1.4.5 Widening for Non-Terminating Abstract Fixpoints

When interval constraint propagation itself involves recursion (e.g., propagators that reference each other cyclically), the abstract fixpoint may not converge. Widening forces convergence:

```
Widening for intervals:
  widen([a1, b1], [a2, b2]) =
    [if a2 < a1 then -inf else a1,
     if b2 > b1 then +inf else b1]
```

Prologos already has the widening infrastructure:

-   `net-set-widen-point` marks a cell for widening.
-   `run-to-quiescence-widen` implements the two-phase widen→narrow iteration.

For narrowing, we mark interval cells at recursive narrowing positions as widening points. The existing `run-to-quiescence-widen` handles the rest: Phase 1 (widen) over-approximates for convergence, Phase 2 (narrow) recovers precision.


<a id="orgb497377"></a>

### 1.4.6 Implementation

| Component                       | File                       | Lines (est.) | Tests (est.) |
|------------------------------- |-------------------------- |------------ |------------ |
| Size-change analysis            | `termination-analysis.rkt` | 200          | 35           |
| LJBA criterion check            | `termination-analysis.rkt` | 100          | 20           |
| Integration with narrowing-info | `narrowing.rkt` (modify)   | 40           | 10           |
| Fuel bounds for bounded class   | `narrowing.rkt` (modify)   | 30           | 10           |
| Warning/note for non-narrowable | `narrowing.rkt` (modify)   | 20           | 5            |
| **Sub-total Phase 2b**          | **1 new + 1 modified**     | **~390**     | **~80**      |


<a id="orgfeec2d4"></a>

### 1.4.7 Tests

-   Size matrix extraction for `add`, `append`, `map`, `fib`, `ack`
-   `add`: column 1 decreasing → `terminating`
-   `append`: column 1 decreasing → `terminating`
-   `fib`: both calls decrease arg 1 → `terminating`
-   `ack`: lexicographic decrease → `terminating` (LJBA handles this)
-   `loop x :` loop x=: no decreasing column → `non-narrowable`
-   `f x :` f (Suc x)=: column 1 increasing → `non-narrowable`
-   `collatz`: column 1 unknown → `bounded` with fuel
-   Integration: narrowing with fuel bounds respects limit
-   Integration: non-narrowable function residuates, emits warning


<a id="orge5fc4b8"></a>

## 1.5 Phase 2c: Critical Pair Analysis for Confluence


<a id="org2d23638"></a>

### 1.5.1 The Problem: Church-Rosser Property

Narrowing's completeness relies on the term rewriting system being *confluent* (Church-Rosser): if a term can be rewritten in two different ways, both paths must converge to a common reduct. For inductively sequential functions (Phase 1), confluence holds automatically (the definitional tree ensures non-overlapping rules). But for non-deterministic functions (Or-branches, D7 in Phase 1 design), confluence may fail.

Confluence matters because:

-   If non-confluent, narrowing may miss solutions (incompleteness).
-   If non-confluent, narrowing may find spurious solutions (unsoundness for some strategies).


<a id="org88408eb"></a>

### 1.5.2 Critical Pair Analysis

Two rules $l_1 \to r_1$ and $l_2 \to r_2$ form a *critical pair* if their left-hand sides overlap (unify at some position). The critical pair is: $(r_1\sigma, r_2\sigma)$ where $\sigma = mgu(l_1|_p, l_2)$ for some position $p$ in $l_1$.

A TRS is confluent if and only if all critical pairs are *joinable*: both elements can be rewritten to a common term (Knuth-Bendix, 1970).


<a id="orgffc86ab"></a>

### 1.5.3 Analysis Algorithm

The analysis is *lazy*: inductively sequential functions (those whose definitional tree has no Or-branches) are confluent by construction and skip critical pair analysis entirely. Only functions with Or-branches (non-deterministic, overlapping rules) trigger the full analysis.

```
check-confluence(def-tree, clauses):
  0. FAST PATH: If def-tree has no Or-branches → 'confluent (skip analysis)
     This covers the common case (add, append, map, filter, etc.) at O(tree-size)
  1. SLOW PATH (Or-branches present):
     For each pair of clauses (c1, c2) (including c1 with itself):
     a. Rename variables to be disjoint
     b. For each non-variable position p in lhs(c1):
        Try to unify lhs(c1)|_p with lhs(c2)
     c. If unifiable with mgu sigma:
        Compute critical pair (rhs(c1)*sigma, rhs(c2)*sigma)
        Try to join: reduce both sides and check convergence
  2. Classification:
     - All critical pairs joinable → confluent (optimal narrowing applies)
     - Some non-joinable → non-confluent:
       a. Warn the user
       b. Use more conservative (complete but less optimal) narrowing strategy
       c. Or: require the user to add rules to resolve the overlap
```


<a id="orgf5803bb"></a>

### 1.5.4 Integration

Confluence analysis is another *compile-time* static analysis stored in `narrowing-info`:

```racket
(struct narrowing-info
  (def-tree
   termination-class
   size-matrix
   fuel-bound
   confluence-class     ;; 'confluent | 'non-confluent | 'unknown
   critical-pairs)      ;; list of critical-pair structs (for diagnostics)
  #:transparent)
```

The narrowing propagator checks `confluence-class`:

-   `confluent`: use optimal needed narrowing (Phase 1 strategy).
-   `non-confluent`: use *basic narrowing* (explore all overlaps), which is complete but not optimal. Emit a compiler note suggesting the user either make the function inductively sequential or add resolving rules.
-   `unknown`: joinability is undecidable in general; treat as potentially non-confluent.


<a id="orga0f48a4"></a>

### 1.5.5 Implementation

| Component                         | File                      | Lines (est.) | Tests (est.) |
|--------------------------------- |------------------------- |------------ |------------ |
| Critical pair computation         | `confluence-analysis.rkt` | 180          | 30           |
| Joinability checking (reduction)  | `confluence-analysis.rkt` | 120          | 20           |
| Integration with narrowing-info   | `narrowing.rkt` (modify)  | 30           | 10           |
| Compiler notes for non-confluence | `narrowing.rkt` (modify)  | 20           | 5            |
| **Sub-total Phase 2c**            | **1 new + 1 modified**    | **~350**     | **~65**      |


<a id="orgcc4df8d"></a>

### 1.5.6 Tests

-   Inductively sequential functions (`add`, `append`): no critical pairs → confluent
-   Non-deterministic `insert`: critical pair exists but joinable → confluent
-   Deliberately non-confluent function: critical pair detected → `non-confluent`
-   Self-overlap detection (a rule overlapping with itself)
-   Nested overlap detection
-   Compiler note emission for non-confluent functions


<a id="org0839413"></a>

## 1.6 Phase 2 Summary

| Sub-phase                      | Module                                          | Lines (est.) | Tests (est.) |
|------------------------------ |----------------------------------------------- |------------ |------------ |
| 2a: Interval Abstract Domain   | `interval-domain.rkt`, `narrowing-abstract.rkt` | 530          | 105          |
| 2b: Size-Based Termination     | `termination-analysis.rkt`                      | 390          | 80           |
| 2c: Critical Pair / Confluence | `confluence-analysis.rkt`                       | 350          | 65           |
| **Phase 2 Total**              | **4 new + 1 modified**                          | **~1,270**   | **~250**     |


<a id="org6414e59"></a>

## 1.7 Phase 2 Dependencies and Ordering

```
Phase 1 (complete)
  |
  +-- Phase 2a (Interval Domain)
  |     |
  |     +-- Narrowing propagator integration (reads interval cells)
  |
  +-- Phase 2b (Termination Analysis)  [independent of 2a]
  |     |
  |     +-- narrowing-info extended with termination-class
  |
  +-- Phase 2c (Confluence Analysis)   [independent of 2a, 2b]
        |
        +-- narrowing-info extended with confluence-class
```

Phases 2a, 2b, and 2c are mutually independent and can be implemented in any order. All three modify `narrowing.rkt` to integrate their results into the narrowing propagator.


<a id="org1459c1e"></a>

# 2. Phase 3: Advanced Extensions


<a id="org8a56d23"></a>

## 2.1 Phase 3a: 0-CFA Closure Analysis for Auto-Defunctionalization


<a id="org4a1a21d"></a>

### 2.1.1 The Problem: Higher-Order Narrowing

Phase 1 (D10) specifies: when a higher-order function argument is *known* (a specific `defn`), narrow through the application. When *unknown*, residuate.

But often a higher-order argument isn't statically known at the narrowing call site yet could be determined by analysis. Consider:

```prologos
defn apply-op [f x y]
  | [f x y] := [f x y]

;; Usage:
[apply-op add 3N ?y] = 10N     ;; f = add, known at this call site
[apply-op ?f 3N 7N] = 10N      ;; f is unknown — which functions could it be?
```

For the second query, we need to determine the set of functions that could flow to `?f`. This is exactly what 0-CFA (zeroth-order Control Flow Analysis) computes.


<a id="org49f1712"></a>

### 2.1.2 0-CFA Overview

0-CFA (Shivers 1991) is an abstract interpretation that computes, for each expression in the program, the set of *closures* (lambda abstractions or named functions) that could be its value at runtime.

For Prologos, 0-CFA would compute:

```
0-CFA Analysis:
  For each variable/expression of function type:
    Compute the set of defn names that could flow to it

  If the set is finite: the HO argument can be defunctionalized
    → create an amb over the functions in the set
    → for each function, install narrowing propagators
  If the set is infinite/unknown: residuate (don't narrow)
```


<a id="org078d3c0"></a>

### 2.1.3 Connection to Defunctionalization

Reynolds (1972) showed that any higher-order program can be transformed to first-order by *defunctionalization*:

1.  Each lambda/function becomes a constructor of a function-type ADT.
2.  An `apply` function pattern-matches on the constructor to dispatch.

0-CFA determines the set of functions at each call site, which is exactly the constructor universe for the defunctionalized ADT. This connects narrowing to defunctionalization:

```
If 0-CFA determines f ∈ {add, mul, sub} at a call site:

Defunctionalized:
  type Op := Add | Mul | Sub
  defn apply-op [op x y]
    | [Add x y] := [add x y]
    | [Mul x y] := [mul x y]
    | [Sub x y] := [sub x y]

Narrowing: amb over {Add, Mul, Sub}
  → try narrowing each function separately
```


<a id="orgce23896"></a>

### 2.1.4 Implementation

The 0-CFA analysis is a *whole-program* static analysis, run at module boundary (or lazily on demand for narrowing):

```racket
;; 0-CFA result for a module
(struct cfa-result
  (flow-sets)  ;; hasheq: expr-id → (setof defn-name)
  #:transparent)

;; Key operations
(define (cfa-analyze module-env)
  ;; 1. Build constraint graph from all defn/defr definitions
  ;; 2. Compute fixpoint (iterate until flow sets stabilize)
  ;; 3. Return cfa-result
  ...)

(define (cfa-lookup result expr-id)
  ;; Returns the set of functions that could flow to expr-id
  (hash-ref (cfa-result-flow-sets result) expr-id (set)))

;; Integration with narrowing
(define (narrow-higher-order net f-cell arg-cells result-cell cfa)
  (define flow-set (cfa-lookup cfa (cell->expr-id f-cell)))
  (cond
    [(set-empty? flow-set)
     ;; No functions flow here — residuate
     net]
    [(= 1 (set-count flow-set))
     ;; Exactly one function — narrow through it directly
     (install-narrowing-propagators net (set-first flow-set) arg-cells result-cell)]
    [else
     ;; Multiple functions — create amb over the set
     (atms-amb net (set->list flow-set)
       (lambda (net fn-name)
         (install-narrowing-propagators net fn-name arg-cells result-cell)))]))
```


<a id="org602fbad"></a>

### 2.1.5 Scope: Demand-Driven Analysis

0-CFA can be scoped at different granularities:

| Scope         | Precision                    | Cost                        | When                  |
|------------- |---------------------------- |--------------------------- |--------------------- |
| Per-function  | Low (only local calls)       | O(n) per function           | Phase 3a initial      |
| Per-module    | Medium (all calls in module) | O(n<sup>2</sup>) per module | Phase 3a+ (optional)  |
| Whole-program | High (all calls)             | O(n<sup>3</sup>) worst case | Phase 3a++ (optional) |

For Phase 3a, the analysis is *demand-driven*: 0-CFA runs only when the elaborator encounters a higher-order argument in a narrowing context (signaled by the presence of `?`-prefixed variables). This avoids analyzing functions that are never narrowed through.

```
Demand-driven 0-CFA trigger:
  1. Elaborator encounters [apply-op ?f 3N ?y] = 10N
  2. ?f is HO (function type) and ?-prefixed → narrowing context
  3. Check 0-CFA cache for apply-op's first argument → miss
  4. Run 0-CFA for apply-op, scoped to current module
  5. Cache result: f ∈ {add, mul, sub}
  6. Install narrowing propagators via amb over {add, mul, sub}
```

This is neither fully module-level (avoids analyzing unused functions) nor fully lazy (the elaborator signals demand at the right granularity). Results are cached per-module, so repeated narrowing through the same HO argument pays the analysis cost only once. Cross-module flows are handled conservatively: imported functions with unknown flow sets residuate.


<a id="org756c390"></a>

### 2.1.6 Implementation

| Component                      | File                     | Lines (est.) | Tests (est.) |
|------------------------------ |------------------------ |------------ |------------ |
| 0-CFA constraint graph builder | `cfa-analysis.rkt`       | 250          | 30           |
| 0-CFA fixpoint solver          | `cfa-analysis.rkt`       | 150          | 25           |
| Integration with narrowing     | `narrowing.rkt` (modify) | 60           | 15           |
| **Sub-total Phase 3a**         | **1 new + 1 modified**   | **~460**     | **~70**      |


<a id="org7f4637c"></a>

### 2.1.7 Tests

-   Simple call sites: `f = add` (direct assignment) → flow set = `{add}`
-   Conditional: `let f = if b then add else mul` → flow set = `{add, mul}`
-   Higher-order parameter: `defn apply [f x] :` [f x]= with call `[apply add 3]` → `f` flows `{add}`
-   Multiple call sites: same parameter receives different functions → union
-   Narrowing with defunctionalized amb: `[apply-op ?f 3N 7N] = 10N` finds `f = add`
-   Unknown function residuates (no 0-CFA info available)


<a id="org4650d55"></a>

## 2.2 Phase 3b: Configurable Search Heuristics


<a id="orgb363df0"></a>

### 2.2.1 Design: Three Orthogonal Axes

Following ECLiPSe's `search/6` design and Gecode's clean propagate/branch separation, we extend the `solver` configuration with three axes:

```prologos
solver my-solver
  :variable-order  first-fail     ;; which variable to branch on
  :value-order     bisect         ;; which value/split to try
  :search          complete       ;; how to traverse the search tree
  :tabling         by-default
  :timeout         30
```


<a id="org256ded1"></a>

### 2.2.2 Variable Ordering Strategies

Determines which unresolved variable to branch on next after propagation reaches quiescence:

| Strategy              | Implementation                                 | Cost      |
|--------------------- |---------------------------------------------- |--------- |
| `input-order`         | First unresolved variable in declaration order | O(n)      |
| `first-fail`          | Variable with smallest domain                  | O(n) scan |
| `most-constrained`    | Smallest domain, tiebreak by propagator count  | O(n) scan |
| `max-weighted-degree` | Highest failure-weighted constraint degree     | O(n) scan |
| `random`              | Random unresolved variable                     | O(1)      |

In the propagator/ATMS architecture:

```racket
;; Variable ordering is a function: (net, unresolved-cells) → cell-id
(define (first-fail-select net cells)
  (argmin (lambda (cid) (domain-size (net-cell-read net cid))) cells))

(define (most-constrained-select net cells)
  (argmin (lambda (cid)
            (let ([dom (domain-size (net-cell-read net cid))]
                  [deg (length (cell-dependents net cid))])
              (cons dom (- deg))))  ;; tiebreak by degree (higher = preferred)
          cells))

;; Adaptive: max-weighted-degree (dom/wdeg, Boussemart et al. 2004)
;; Requires maintaining a weight counter per propagator, incremented on
;; domain wipeout (contradiction). Higher weight → more failure-prone.
(define (max-weighted-degree-select net cells weight-table)
  (argmin (lambda (cid)
            (let ([dom (domain-size (net-cell-read net cid))]
                  [wdeg (sum-weighted-degree cid weight-table)])
              (/ dom (max 1 wdeg))))
          cells))
```


<a id="org7a1fe35"></a>

### 2.2.3 Value Ordering Strategies

Determines which value to try for the selected variable:

| Strategy       | Implementation           | Split                         |
|-------------- |------------------------ |----------------------------- |
| `indomain-min` | Try minimum value first  | Enumerate: lo, lo+1, &#x2026; |
| `indomain-max` | Try maximum value first  | Enumerate: hi, hi-1, &#x2026; |
| `bisect`       | Binary domain split      | [lo,mid] vs [mid+1,hi]        |
| `random`       | Random value from domain | Random element                |

In the propagator/ATMS architecture:

```racket
;; Value ordering creates the amb alternatives
(define (bisect-value net cid)
  (define dom (net-cell-read net cid))
  (define mid (quotient (+ (interval-lo dom) (interval-hi dom)) 2))
  ;; Returns two alternative domain restrictions
  (list (interval (interval-lo dom) mid)
        (interval (+ mid 1) (interval-hi dom))))

(define (indomain-min-value net cid)
  (define dom (net-cell-read net cid))
  ;; Returns: try lo first, then [lo+1, hi]
  (list (interval (interval-lo dom) (interval-lo dom))
        (interval (+ (interval-lo dom) 1) (interval-hi dom))))
```


<a id="orgef46ce7"></a>

### 2.2.4 Search Strategies

Determines how the search tree is traversed:

| Strategy                    | Description                                   | ATMS Mapping                                                             |
|--------------------------- |--------------------------------------------- |------------------------------------------------------------------------ |
| `complete`                  | Exhaustive DFS                                | Default `atms-solve-all`                                                 |
| `(lds N)`                   | Limited discrepancy search (max N deviations) | Prioritize consistent worldviews with fewer non-first-choice assumptions |
| `(bb-min expr)`             | Branch-and-bound minimization                 | Cost-bound cell as propagator                                            |
| `(restart (luby K))`        | Luby restart sequence                         | Reset assumptions after K conflicts                                      |
| `(restart (geometric K G))` | Geometric restart                             | Reset after K\*G<sup>i</sup> conflicts                                   |


<a id="orgb89d3e3"></a>

### 2.2.5 Search Strategy Integration

The search strategy modifies the *outer solve loop* (Phase 1d's `narrowing-solve`):

```racket
;; Complete search (default)
(define (search-complete net goals)
  (atms-solve-all net goals))

;; Limited discrepancy search
(define (search-lds net goals max-discrepancy)
  ;; Filter worldviews by discrepancy count
  ;; Discrepancy = number of non-first-choice assumptions
  (define all (atms-solve-all net goals))
  (filter (lambda (wv) (<= (discrepancy-count wv) max-discrepancy)) all))

;; Branch-and-bound minimization
(define (search-bb-min net goals cost-expr)
  (define cost-cell (net-new-cell net +inf.0 min-merge))
  ;; Install propagator: when cost-cell improves, prune branches
  ;; where cost lower bound > current best
  ...)

;; Restart-based search
(define (search-restart net goals cutoff-fn)
  (let loop ([attempt 0] [best #f] [nogoods '()])
    (define cutoff (cutoff-fn attempt))
    ;; Add accumulated nogoods
    ;; Search until cutoff conflicts
    ;; Record new nogoods
    ;; Restart with fresh assumptions
    ...))
```


<a id="orgc75e4d6"></a>

### 2.2.6 Implementation

| Component                             | File                     | Lines (est.) | Tests (est.) |
|------------------------------------- |------------------------ |------------ |------------ |
| Variable ordering strategies          | `search-heuristics.rkt`  | 120          | 25           |
| Value ordering strategies             | `search-heuristics.rkt`  | 80           | 20           |
| Search strategies (LDS, BB, restart)  | `search-strategies.rkt`  | 250          | 35           |
| Extended `solver` config parsing      | `solver.rkt` (modify)    | 80           | 15           |
| Integration with narrowing solve loop | `narrowing.rkt` (modify) | 60           | 10           |
| **Sub-total Phase 3b**                | **2 new + 2 modified**   | **~590**     | **~105**     |


<a id="orgd326a0f"></a>

### 2.2.7 Tests

-   Variable ordering: first-fail selects tightest domain
-   Variable ordering: most-constrained tiebreaks correctly
-   Value ordering: bisect splits evenly
-   Value ordering: indomain-min enumerates in order
-   Search: complete finds all solutions
-   Search: LDS finds solutions reachable within discrepancy bound
-   Search: BB-min finds optimal solution
-   Search: restart with Luby sequence finds solution
-   Solver config: parsing new axes from `solver` form
-   Integration: same problem with different heuristics → same solutions, different ordering/performance


<a id="orgf3162b3"></a>

## 2.3 Phase 3c: Global Constraints and Optimization


<a id="org9ba6640"></a>

### 2.3.1 Global Constraint Propagators

Global constraints are specialized propagators that achieve stronger consistency than decomposition into binary constraints. Each is a *propagator factory*: given constraint parameters, it creates propagators with the appropriate cell dependencies and narrowing behavior.

```prologos
;; Surface syntax for global constraints
all-different [x y z w]     ;; all variables must have distinct values
cumulative tasks 5           ;; task scheduling with capacity 5
element i xs v               ;; v = xs[i] (array element constraint)
```


<a id="org334d799"></a>

### 2.3.2 `all-different` Implementation

The `all-different` constraint uses *bound consistency* (Puget 1998):

```racket
;; all-different propagator: when a variable is assigned value v,
;; remove v from all other variables' domains
(define (all-different-propagator net cells)
  ;; For each cell:
  ;;   If singleton [v,v]: remove v from all other cells
  ;;   If domain size = count of remaining cells:
  ;;     Hall set detection → prune
  (for/fold ([net net])
            ([c cells])
    (define val (net-cell-read net c))
    (if (interval-singleton? val)
        (let ([v (interval-lo val)])
          (for/fold ([net net])
                    ([other (remove c cells)])
            (net-cell-write net other
              (interval-remove (net-cell-read net other) v))))
        net)))
```

For stronger consistency (matching-based filtering, Regin 1994), a more sophisticated implementation using value graphs and maximum matching is needed. This can be deferred to Phase 3c+ if bound consistency suffices for initial use cases.


<a id="orgf8aa29c"></a>

### 2.3.3 Branch-and-Bound Optimization

Optimization problems use branch-and-bound: maintain a best-known solution and prune branches that can't improve on it.

```prologos
;; Surface syntax
solver opt-solver
  :search (bb-min cost)

solve [find ?x ?y]
  [add ?x ?y] = 100N
  [mul ?x ?y] = ?cost
  :minimize ?cost
```

1.  ATMS Interaction: Global Cost Bound

    The cost bound is *global* across all ATMS worldviews, consistent with the ATMS's global nogood semantics (D9 in Phase 1 design: nogoods are shared, unconditional facts are shared). When a solution with cost $c$ is found in any worldview, *all* worldviews are immediately pruned to cost $< c$.
    
    This is strictly more efficient than per-worldview bounds: a solution in worldview $W_1$ prunes the search space of worldview $W_2$ without $W_2$ having to independently discover that bound.
    
    Implementation: the cost-bound cell lives outside any specific worldview (it is part of the search state, not the propagator network state). The `atms-solve-all` loop updates it on each solution found.
    
    ```racket
    ;; Branch-and-bound with global cost bound
    (define (search-bb-min net goals cost-cell)
      ;; Global bound: shared across all worldviews
      (define global-bound (box +inf.0))
      (atms-solve-all net goals
        ;; Prune worldviews whose cost lower bound exceeds global best
        #:prune-fn (lambda (wv)
                     (define cost-lo (interval-lo (worldview-cell-read wv cost-cell)))
                     (< cost-lo (unbox global-bound)))
        ;; On each solution found: update the global bound
        #:on-solution (lambda (wv)
                        (define cost (interval-lo (worldview-cell-read wv cost-cell)))
                        (when (< cost (unbox global-bound))
                          (set-box! global-bound cost)))))
    
    ;; Additionally, install a pruning propagator within each worldview:
    (define (install-bb-pruning-propagator net cost-cell global-bound)
      (net-add-propagator net (list cost-cell) (list cost-cell)
        (lambda (net)
          (define cost (net-cell-read net cost-cell))
          (define bound (unbox global-bound))
          (if (> (interval-lo cost) bound)
              ;; Prune: this branch can't improve on current best
              (struct-copy prop-network net [contradiction #t])
              ;; Tighten cost domain
              (net-cell-write net cost-cell
                (interval (interval-lo cost) (min (interval-hi cost) bound)))))))
    ```


<a id="orgb508d0d"></a>

### 2.3.4 Implementation

| Component                           | File                             | Lines (est.) | Tests (est.) |
|----------------------------------- |-------------------------------- |------------ |------------ |
| `all-different` (bound consistency) | `global-constraints.rkt`         | 120          | 25           |
| `cumulative` (timetable filtering)  | `global-constraints.rkt`         | 150          | 20           |
| `element` (array element)           | `global-constraints.rkt`         | 60           | 15           |
| Branch-and-bound optimization       | `search-strategies.rkt` (extend) | 100          | 20           |
| Surface syntax for constraints      | parser, elaborator (modify)      | 80           | 15           |
| **Sub-total Phase 3c**              | **1 new + 3 modified**           | **~510**     | **~95**      |


<a id="orgb19d450"></a>

### 2.3.5 Tests

-   `all-different`: singleton propagation removes value from peers
-   `all-different`: Hall set detection (3 vars, 3 values → all determined)
-   `all-different`: contradiction when domain too small for constraint
-   `cumulative`: task scheduling with capacity bound
-   `element`: index determines value, value constrains index
-   BB-min: finds optimal solution for simple optimization
-   BB-min: prunes suboptimal branches (count backtracks, verify reduction)
-   Integration with narrowing: `[add ?x ?y] = 10N` with `all-different [?x ?y]`


<a id="org8133ef1"></a>

## 2.4 Phase 3 Summary

| Sub-phase                             | Module                                           | Lines (est.) | Tests (est.) |
|------------------------------------- |------------------------------------------------ |------------ |------------ |
| 3a: 0-CFA Auto-Defunctionalization    | `cfa-analysis.rkt`                               | 460          | 70           |
| 3b: Configurable Search Heuristics    | `search-heuristics.rkt`, `search-strategies.rkt` | 590          | 105          |
| 3c: Global Constraints + Optimization | `global-constraints.rkt`                         | 510          | 95           |
| **Phase 3 Total**                     | **4 new + 3 modified**                           | **~1,560**   | **~270**     |


<a id="org8bfb9f7"></a>

## 2.5 Phase 3 Dependencies and Ordering

```
Phase 1 (complete)
  |
  +-- Phase 3a (0-CFA)
  |     Depends on: narrowing propagator (Phase 1c)
  |     Independent of: Phases 2a-2c, 3b, 3c
  |
  +-- Phase 3b (Search Heuristics)
  |     Depends on: solver integration (Phase 1d)
  |     Independent of: Phases 2a-2c, 3a, 3c
  |     (Enhanced by Phase 2a: interval domains enable bisect strategy)
  |
  +-- Phase 3c (Global Constraints)
        Depends on: interval domain (Phase 2a) for numeric constraints
        Enhanced by: search heuristics (Phase 3b) for optimization
```

Recommended ordering: 3b → 3a → 3c (search heuristics are highest impact and most independent; 0-CFA is moderately complex; global constraints benefit from both interval domains and search heuristics).


<a id="org7bee722"></a>

# 3. Unified Roadmap: Phases 1&#x2013;3


<a id="org0fe4e17"></a>

## 3.1 Complete Implementation Table

| Phase | Sub-phase | Description                       | Lines      | Tests    | New Files                                        | Modified Files                              |
|----- |--------- |--------------------------------- |---------- |-------- |------------------------------------------------ |------------------------------------------- |
| 1     | 1a        | Definitional Trees                | 200        | 40       | `definitional-tree.rkt`                          |                                             |
| 1     | 1b        | Term Lattice                      | 150        | 30       | `term-lattice.rkt`                               |                                             |
| 1     | 1c        | Narrowing Propagator              | 300        | 50       | `narrowing.rkt`                                  |                                             |
| 1     | 1d        | Solver Integration                | 200        | 50       |                                                  | `relations.rkt`, `solver.rkt`               |
| 1     | 1e        | WS-Mode Syntax                    | 100        | 30       |                                                  | parser, WS reader                           |
| 2     | 2a        | Interval Abstract Domain          | 530        | 105      | `interval-domain.rkt`, `narrowing-abstract.rkt`  | `narrowing.rkt`                             |
| 2     | 2b        | Termination Analysis              | 390        | 80       | `termination-analysis.rkt`                       | `narrowing.rkt`                             |
| 2     | 2c        | Confluence Analysis               | 350        | 65       | `confluence-analysis.rkt`                        | `narrowing.rkt`                             |
| 3     | 3a        | 0-CFA Auto-Defunctionalization    | 460        | 70       | `cfa-analysis.rkt`                               | `narrowing.rkt`                             |
| 3     | 3b        | Search Heuristics                 | 590        | 105      | `search-heuristics.rkt`, `search-strategies.rkt` | `solver.rkt`, `narrowing.rkt`               |
| 3     | 3c        | Global Constraints + Optimization | 510        | 95       | `global-constraints.rkt`                         | `search-strategies.rkt`, parser, elaborator |
|       |           | **Grand Total**                   | **~3,780** | **~720** | **11 new**                                       | **~6 modified**                             |


<a id="org06c860d"></a>

## 3.2 Dependency Graph

```
                  Phase 1
        (Core FL Narrowing, ~950 lines)
       /          |           \
      /           |            \
 Phase 2a      Phase 2b      Phase 2c
(Interval)   (Termination)  (Confluence)
 ~530 lines   ~390 lines     ~350 lines
     |            |              |
     +-----+------+------+------+
           |             |
        Phase 3a      Phase 3b
        (0-CFA)      (Heuristics)
        ~460 lines   ~590 lines
           |             |
           +------+------+
                  |
              Phase 3c
        (Global Constraints)
            ~510 lines
```


<a id="org6b187a6"></a>

## 3.3 Recommended Implementation Sequence

1.  **Phase 1** (1a → 1b → 1c → 1d → 1e): Core narrowing. ~950 lines, ~200 tests. Duration estimate: major implementation phase.

2.  **Phase 2b** (Termination Analysis): Static analysis, independent of other Phase 2 work. ~390 lines, ~80 tests. High value: prevents infinite loops.

3.  **Phase 2a** (Interval Abstract Domain): Enables numeric narrowing. ~530 lines, ~105 tests. High value: handles Nat/Int/PosInt.

4.  **Phase 3b** (Search Heuristics): User-configurable search. ~590 lines, ~105 tests. High value: performance improvement.

5.  **Phase 2c** (Confluence Analysis): Static analysis for soundness. ~350 lines, ~65 tests. Important for correctness of non-deterministic functions.

6.  **Phase 3a** (0-CFA): Auto-defunctionalization. ~460 lines, ~70 tests. Enables higher-order narrowing without manual defunctionalization.

7.  **Phase 3c** (Global Constraints + Optimization): Advanced constraint solving. ~510 lines, ~95 tests. Enables practical optimization problems.

Rationale: Phase 1 is prerequisite for everything. Then 2b (termination) gives safety, 2a (intervals) gives expressiveness, 3b (heuristics) gives performance, 2c (confluence) gives correctness guarantees, 3a (0-CFA) gives HO support, and 3c (global constraints) gives full constraint programming capability.


<a id="orgb923ca4"></a>

# 4. Surface Syntax for Extended Features


<a id="orgca72f34"></a>

## 4.1 Solver Configuration

```prologos
;; Full solver configuration with all axes
solver constraint-solver
  :variable-order  first-fail
  :value-order     bisect
  :search          (bb-min cost)
  :tabling         by-default
  :timeout         60

;; Using a solver for narrowing
let solutions = with-solver constraint-solver
  [add ?x ?y] = 100N
  all-different [?x ?y]
```


<a id="org431544e"></a>

## 4.2 Constraint Syntax

```prologos
;; Interval domain constraints (implicit from types)
spec add : <(x : PosInt) -> (y : PosInt) -> PosInt>
;; PosInt → interval [1, +inf)

;; Global constraints
all-different [?x ?y ?z]       ;; distinct values
element ?i ?xs ?v              ;; array element
;; cumulative tasks cap         ;; resource scheduling (future)

;; Optimization
solve :minimize [cost ?x ?y]
  [profit ?x] = ?px
  [profit ?y] = ?py
  let ?total = [add ?px ?py]
```


<a id="org67bcb58"></a>

## 4.3 Static Analysis Feedback

```prologos
;; Termination analysis feedback (compiler messages)
;; INFO: add is terminating (size decrease on arg 1)
;; INFO: fib is terminating (size decrease on arg 1, both calls)
;; WARN: collatz is bounded-narrowable (fuel limit: 1000)
;; ERROR: loop is non-narrowable (no decreasing argument)

;; Confluence analysis feedback
;; INFO: add is confluent (inductively sequential)
;; WARN: insert has overlapping rules — using basic narrowing
;;       Consider making clauses non-overlapping for optimal narrowing
```


<a id="org47f7c4e"></a>

# 5. Interaction Between Phases


<a id="orgf2c4209"></a>

## 5.1 Interval Domains + Search Heuristics (2a + 3b)

Interval domains enable the `bisect` value ordering strategy:

```
Variable ?x with domain [1, 100]:
  bisect → amb([1, 50], [51, 100])

  After propagation with [1, 50]:
    Further narrowing may determine ?x = [23, 23]

  With first-fail variable ordering:
    Select the variable with smallest domain → most constrained → fewest
    backtracks needed
```


<a id="org9e6e63d"></a>

## 5.2 Termination Analysis + Interval Domains (2b + 2a)

Termination analysis can use interval domain sizes for fuel estimation:

```
Function f : PosInt -> PosInt -> Nat
  Size decrease on arg 1
  With interval domain [1, K] for arg 1:
    Max recursion depth = K
    Fuel bound = K (not infinite)
```

When the interval domain is finite, the termination analysis can compute a precise fuel bound instead of using a fixed default.


<a id="org8afec32"></a>

## 5.3 0-CFA + Narrowing Propagator (3a + 1c)

0-CFA results feed directly into the narrowing propagator's handling of higher-order arguments:

```
narrowing-propagator at Branch node, argument is HO function:
  1. Check: is the cell a known function? → narrow directly
  2. Check: does 0-CFA give a finite flow set? → amb over set
  3. Otherwise: residuate
```


<a id="orgc813c91"></a>

## 5.4 Confluence + Termination (2c + 2b)

A non-confluent function that is also non-terminating is particularly dangerous: narrowing may loop AND produce inconsistent results. The combination of both analyses gives a clear classification:

| Confluent | Terminating | Classification                              |
|--------- |----------- |------------------------------------------- |
| Yes       | Yes         | Safe for unrestricted narrowing             |
| Yes       | No          | Use fuel bounds                             |
| No        | Yes         | Use basic narrowing (sound but not optimal) |
| No        | No          | Non-narrowable (residuate only)             |


<a id="orgbaff0f7"></a>

## 5.5 Global Constraints + Narrowing (3c + 1c)

Global constraints and narrowing propagators coexist in the same propagator network and run to quiescence together:

```
solve
  [add ?x ?y] = 10N       ;; narrowing propagator
  all-different [?x ?y]   ;; global constraint propagator

  1. Narrowing: ?x ∈ [0,10], ?y ∈ [0,10]
  2. all-different: if ?x = 5, then ?y ≠ 5
  3. Combined: 10 solutions instead of 11 (5+5 excluded)
```


<a id="orgea79cf7"></a>

## 5.6 Narrowing and Effects (Pure Fragment Only)

Narrowing operates exclusively over the *pure fragment* of Prologos. Functions with capability requirements (QTT resource usage, IO effects, session types) are automatically non-narrowable.

The QTT system makes this distinction explicit at the type level:

-   **Pure functions** (`spec f : A -> B` with no capability binders): the function body can be symbolically executed via narrowing. These are narrowable.

-   **Capability-bearing functions** (`spec f {Cap} : A -> B`): the erased capability binder indicates the function body may perform effects. Even though `Cap` is erased at runtime, the function *semantically* depends on external state. Narrowing would require symbolically executing the effect, which is nonsensical. These are non-narrowable; the narrowing propagator residuates.

-   **Session-typed processes** (`proc` definitions): narrowing does not apply to processes — they are communicating entities, not term-rewriting functions. No interaction needed.

This classification requires no additional analysis: the elaborator already knows whether a function has capability binders from its type. A function's `narrowing-info` simply inherits `non-narrowable` when capability binders are present, before termination or confluence analysis even runs.

```
spec read-config {ReadCap} : <(path : String) -> Config>
;; narrowing-info: non-narrowable (capability-bearing)
;; [read-config ?path] = some-config  →  residuates (waits for ?path to be bound)

spec add : <(x : Nat) -> (y : Nat) -> Nat>
;; narrowing-info: terminating, confluent (pure)
;; [add ?x ?y] = 13N  →  narrows to 14 solutions
```


<a id="orge773441"></a>

# 6. Open Research Questions


<a id="orge6157e0"></a>

## 6.1 Phase 2 Open Questions

1.  **Length-interval domain for structured types** (Phase 2a+): For `List`, `String`, and other recursive types, a *length-interval* Galois connection abstracts the structure to its size: `alpha(Cons(_, Cons(_, Nil))) = [2, 2]`, `gamma([2, 4]) = "at least 2 and at most 4 elements"`. This enables propagation like `length(?xs) + length(?ys) = length(zs)` for `append` queries. Note that for finite constructor ADTs (`List` has 2 constructors: `Nil`, `Cons`), Phase 1's needed narrowing handles the common case directly &#x2014; the length domain adds value primarily when propagating size constraints across multiple list variables to prune the search space without enumerating. For `Vec n A` (dependently typed), the type index `n` *is* the size &#x2014; the type system provides the abstraction for free.

2.  **Widening precision**: Standard interval widening loses significant precision. *Widening with thresholds* (set of landmark values that the widened interval preserves) may recover precision. Implementation cost is minimal (extend the widen function with a threshold set).

3.  **Size-change termination vs. dependency pairs**: The LJBA criterion handles most practical functions but not all terminating ones. *Dependency pairs* (Arts & Giesl 2000) are strictly more powerful but more complex to implement. Defer to Phase 2b+ if needed.

4.  **Confluence checking decidability**: Joinability is undecidable for general TRS. Our scope is limited to inductively sequential functions with finite constructor sets, where decidability is not an issue. For non-IS functions, we conservatively classify as `unknown`.


<a id="org680527c"></a>

## 6.2 Phase 3 Open Questions

1.  **0-CFA precision**: 0-CFA may be imprecise for polymorphic higher-order functions (merges flow sets across all call sites). *1-CFA* (call-site sensitive) improves precision at higher cost. Start with 0-CFA; upgrade to k-CFA if precision is insufficient in practice.

2.  **Adaptive heuristics state**: `max-weighted-degree` requires maintaining weight counters across search. In a persistent/immutable propagator network, this means threading weight state through the search. The ATMS's persistent nature makes this natural (weights are part of the ATMS state).

3.  **Global constraint strength**: Bound consistency for `all-different` is weaker than matching-based GAC (Regin 1994). For most Prologos use cases, bound consistency suffices. GAC implementation can be deferred.

4.  **Branch-and-bound with restarts**: Combining optimization with restart search requires careful handling of incumbent solutions across restarts. The ATMS's persistent nature helps (the best-known solution is a cell value that persists across restarts).


<a id="org2d71d78"></a>

# 7. Connection to Existing Research Documents

This design document is part of a coherent research arc:

1.  **Effectful Propagators** (`2026-03-06_EFFECTFUL_PROPAGATORS.org`): Established propagator networks as the computational substrate.

2.  **Session Types as Effect Ordering** (`2026-03-06_SESSION_EFFECT_ORDERING.org`): Showed session types as causal ordering over effects on the propagator substrate.

3.  **Propagators as Model Checkers** (`2026-03-07_PROPAGATORS_AS_MODEL_CHECKERS.org`): Showed the structural isomorphism between propagator fixpoints and CTL model checking. Narrowing-based symbolic reachability (§5.4 of the Search Heuristics research doc) is the narrowing side of this isomorphism.

4.  **Narrowing and Search Heuristics** (`2026-03-07_NARROWING_AND_SEARCH_HEURISTICS.org`): General research survey of the three converging lines. This document and the Phase 0&#x2013;1 design document are the implementation-oriented refinements.

5.  **FL Narrowing Phase 0&#x2013;1 Design** (`2026-03-07_FL_NARROWING_DESIGN.org`): Core narrowing machinery. This document (Phase 2&#x2013;3) is its direct companion.

The arc: propagators → effects → ordering → model checking → narrowing → abstract interpretation → search → constraints → optimization. Each builds on the previous, all unified on the propagator substrate.


<a id="orga73c4ef"></a>

# 8. Design Decisions


<a id="orgef034c7"></a>

## DD-1: Interval Domain as First Abstract Domain

Start with intervals for numeric types. This covers the most common infinite constructor universe (`Nat`, `Int`, `PosInt`). Other abstract domains (set domain for `List` length, string length domain) can be added incrementally using the same Galois connection infrastructure.


<a id="orgc55f88e"></a>

## DD-2: LJBA Termination over Dependency Pairs

Lee-Jones-Ben-Amram (2001) is simpler to implement and handles most practical functions. Dependency pairs (Arts & Giesl 2000) are strictly more powerful but require more infrastructure (dependency graph, usable rules, argument filterings). Start with LJBA; upgrade if needed.


<a id="org44c506c"></a>

## DD-3: Demand-Driven 0-CFA

0-CFA is triggered on demand when the elaborator encounters a higher-order argument in a narrowing context (`?`-prefixed variables). Results are cached per-module. This avoids analyzing functions that are never narrowed through, while still capturing all intra-module function flows when needed. Cross-module flows are handled conservatively: imported functions with unknown flow sets residuate.


<a id="orge489597"></a>

## DD-4: Bound Consistency for `all-different`

Start with bound consistency (O(n log n) per invocation). GAC via maximum matching (Regin 1994) is O(n<sup>3/2</sup>) and achieves strictly stronger pruning but is more complex. Defer GAC to Phase 3c+ if bound consistency proves insufficient.


<a id="orgdf0088f"></a>

## DD-5: Existing Widening Infrastructure

Reuse `net-set-widen-point` and `run-to-quiescence-widen` for abstract interpretation widening. No new widening infrastructure needed. Mark interval cells at recursive narrowing positions as widening points; the existing two-phase widen→narrow iteration handles convergence.


<a id="org29618b8"></a>

## DD-6: Existing Cross-Domain Propagator Infrastructure

Reuse `net-add-cross-domain-propagator` for Galois connections between term cells and interval cells. The alpha/gamma pair pattern from the Type $\leftrightarrow$ Multiplicity bridge (`elaborator-network.rkt`) transfers directly.


<a id="orgb409ab4"></a>

## DD-7: Search Heuristics as Solver Config Extensions

Extend the existing `solver` surface syntax with `:variable-order`, `:value-order`, `:search` axes. The solver config already supports `:execution`, `:threshold`, `:strategy`, `:tabling`, `:provenance`, `:timeout`. Three new axes follow the same pattern.


<a id="orgd0d1909"></a>

## DD-8: Static Analyses at Elaboration Time

Termination analysis and confluence analysis are compile-time (elaboration time) analyses stored in `narrowing-info` alongside the definitional tree. They run once per `defn` and do not affect runtime performance. Confluence analysis is lazy: it skips the full critical pair computation for inductively sequential functions (no Or-branches in the definitional tree), covering the common case at O(tree-size). 0-CFA runs on demand when the elaborator encounters HO arguments in narrowing contexts, with per-module caching.


<a id="org88093dc"></a>

## DD-9: Narrowing Over the Pure Fragment

Functions with capability binders (`\{Cap\}`) are automatically non-narrowable. The QTT system distinguishes pure from effectful at the type level; no additional analysis is needed. Session-typed processes (`proc`) are not subject to narrowing. This ensures narrowing never attempts to symbolically execute side effects.


<a id="org0e9070c"></a>

# 9. Related Work


<a id="org6ede2fa"></a>

## Abstract Interpretation

-   Cousot, Cousot. "Abstract Interpretation: A Unified Lattice Model for Static Analysis of Programs." *POPL* 1977.
-   Cousot, Cousot. "Systematic Design of Program Analysis Frameworks." *POPL* 1979.
-   Mine. "The Octagon Abstract Domain." *HOSC* 19(1), 2006.


<a id="orgf8a3c6b"></a>

## Termination Analysis

-   Lee, Jones, Ben-Amram. "The Size-Change Principle for Program Termination." *POPL* 2001.
-   Arts, Giesl. "Termination of Term Rewriting Using Dependency Pairs." *TCS* 236(1-2), 2000.
-   Chin, Khoo. "Calculating Sized Types." *HOSC* 14(2-3), 2001.


<a id="org2797e10"></a>

## Confluence and Critical Pairs

-   Knuth, Bendix. "Simple Word Problems in Universal Algebras." 1970.
-   Huet. "Confluent Reductions: Abstract Properties and Applications to Term Rewriting Systems." *JACM* 27(4), 1980.


<a id="org6a81392"></a>

## Control Flow Analysis

-   Shivers. "Control-Flow Analysis of Higher-Order Languages, or Taming Lambda." *CMU Tech Report* CMU-CS-91-145, 1991.
-   Reynolds. "Definitional Interpreters for Higher-Order Programming Languages." *ACM National Conference* 1972.


<a id="orgae94f21"></a>

## Constraint Programming

-   Boussemart et al. "Boosting Systematic Search by Weighting Constraints." *ECAI* 2004.
-   Harvey, Ginsberg. "Limited Discrepancy Search." *IJCAI* 1995.
-   Regin. "A Filtering Algorithm for Constraints of Difference in CSPs." *AAAI* 1994.
-   Puget. "A Fast Algorithm for the Bound Consistency of alldiff Constraints." *AAAI* 1998.
-   Schulte, Stuckey. "Efficient Constraint Propagation Engines." *TOPLAS* 30(1), 2008.


<a id="org529feb4"></a>

## Functional-Logic Programming

-   Antoy, Echahed, Hanus. "A Needed Narrowing Strategy." *JACM* 47(4), 2000.
-   Antoy, Hanus. "Functional Logic Programming." *CACM* 53(4), 2010.
-   Fernandez et al. "Constraint Functional Logic Programming over Finite Domains." *TPLP* 7(1-2), 2007.


<a id="org1aab061"></a>

# 10. Conclusion

Phases 2&#x2013;3 transform the core FL narrowing engine (Phase 1) from a prototype into a production-grade unified solver. The key contributions:

-   **Abstract interpretation** (Phase 2a) tames infinite constructor universes by computing in an abstract interval domain, connected to concrete term cells via Galois connections using existing cross-domain propagator infrastructure.

-   **Termination analysis** (Phase 2b) provides static guarantees that narrowing will terminate, using the size-change principle with LJBA criterion.

-   **Confluence analysis** (Phase 2c) detects non-confluent rewrite systems and adjusts the narrowing strategy accordingly, ensuring soundness for non-deterministic functions.

-   **Auto-defunctionalization** (Phase 3a) via 0-CFA enables higher-order narrowing by statically determining the finite set of functions at each call site.

-   **Configurable search heuristics** (Phase 3b) give the user control over the three orthogonal axes of search: variable ordering, value selection, and search strategy.

-   **Global constraints and optimization** (Phase 3c) bring practical constraint programming capabilities: `all-different`, `cumulative`, and branch-and-bound optimization.

The total implementation across Phases 1&#x2013;3 is estimated at ~3,780 lines of source and ~720 tests across 11 new files and 6 modified files. All phases build on the same propagator+ATMS substrate, and all design decisions reuse existing infrastructure wherever possible (cross-domain propagators for Galois connections, widening points for abstract fixpoint convergence, `amb` for search branching, `solver` config for heuristic selection).

The result: a language where functional evaluation, logic programming, constraint solving, abstract interpretation, and configurable search are unified on a single algebraic substrate &#x2014; monotone refinement on a lattice, guided by demand, branched by heuristic choice, abstracted by Galois connection, and verified by type.
