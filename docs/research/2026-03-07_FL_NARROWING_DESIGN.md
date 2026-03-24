- [Abstract](#org8b99ed3)
- [1. Motivation: The defn/defr Divide](#org5a13848)
  - [1.1 The Current State](#org35cb33c)
  - [1.2 The Vision](#org30cf048)
  - [1.3 Why This Matters for Prologos](#org9f6490d)
- [2. Surface Syntax](#orgd266508)
  - [2.1 `=` as Universal Unification](#orgfbc206a)
  - [2.2 Implicit Narrowing via `?` Variables](#org3b1d8df)
  - [2.3 Bidirectional `=` in Functional Contexts](#org9b55fbb)
  - [2.4 The `spec` as Solution Schema](#org159513e)
- [3. Formal Foundations](#org48cdd29)
  - [3.1 Term Rewriting Systems](#orge1b4d61)
  - [3.2 Narrowing](#org0f6abc3)
  - [3.3 Completeness](#orgae83726)
  - [3.4 Definitional Trees](#org45bef54)
    - [Definition (Antoy 1992)](#org7216827)
    - [Example: `add`](#orge3b271d)
    - [Example: `last` (nested branching)](#orga8dea3b)
  - [3.5 Inductively Sequential Functions](#org2ac8275)
  - [3.6 The Needed Narrowing Strategy](#org15a97ff)
    - [Optimality (Antoy, Echahed, Hanus 2000)](#orgda65472)
  - [3.7 Non-Deterministic Functions](#orgc1aa618)
  - [3.8 Residuation](#orge59b3be)
- [4. Constraints from the Type System](#org3c02875)
  - [4.1 No `where` Clause &mdash; Types ARE Constraints](#org92cabbb)
  - [4.2 Types as Domain Constraints](#org9b9d287)
  - [4.3 Subtypes as Refined Domains](#org524b720)
  - [4.4 Properties as Constraint Strengtheners](#org6d6ad89)
  - [4.5 Traits as Capability Constraints](#orgcf5a689)
- [5. Mapping to Prologos Infrastructure](#orgb4b2193)
  - [5.1 Definitional Trees from `defn`](#orgc84c509)
    - [Pattern Structure in Prologos AST](#org2b86676)
    - [Extraction Algorithm](#org9f7dff3)
    - [Handling Prologos-Specific Features](#org72720f1)
  - [5.2 Constructor Universe](#org1b82db1)
  - [5.3 The Propagator Connection](#orgb3e24ce)
  - [5.4 Term Cells](#org0ea8515)
- [6. Narrowing Propagator Design](#org8636554)
  - [6.1 The Narrowing Propagator](#orgfa418f7)
  - [6.2 Demand-Driven Evaluation](#orgd5b8d29)
  - [6.3 Interaction with the Solver Loop](#org73f4c29)
  - [6.4 Backward Compatibility](#orge71aa44)
- [7. Design Decisions](#orge5ad6af)
  - [D1: Residuation by Default, Narrowing on Demand](#orga6a5328)
  - [D2: `=` as Sole Unification Operator](#orgd52be77)
  - [D3: `spec` as Solution Schema](#org1291a61)
  - [D4: Constraints from Types, Not from `where`](#org9038e4d)
  - [D5: Definitional Tree Extraction at Elaboration Time](#org26398d7)
  - [D6: Constructor Universe from Type Definitions](#orge754614)
  - [D7: Non-Deterministic Functions Create Or-Branches](#org35b4111)
  - [D8: Term Lattice for Variable Cells](#orgec757f4)
  - [D9: ATMS Worldview Semantics for Linearity](#orgc5ffdae)
  - [D10: Higher-Order &mdash; Narrow on Application](#org5f8fe9c)
  - [D11: Backward-Compatible with `defr`](#org2f3c918)
- [8. Implementation Roadmap](#org9d0ea7e)
  - [Phase 1: Core FL Narrowing](#orge9e6848)
    - [Phase 1a: Definitional Tree Infrastructure](#org0b4a22d)
    - [Phase 1b: Term Lattice](#orge080ecd)
    - [Phase 1c: Narrowing Propagator](#org8f88095)
    - [Phase 1d: Solver Integration](#org8c2920b)
    - [Phase 1e: WS-Mode Surface Syntax](#orga2feaec)
    - [Phase 1 Summary](#orgfa402d8)
  - [Phase 2: Abstract Interpretation for Narrowing (see companion design doc)](#org1c4ffb7)
  - [Phase 3: Advanced Extensions (see companion design doc)](#org5843ed0)
- [9. Related Work](#orgcc7184f)
- [10. Conclusion](#org3d5b816)



<a id="org8b99ed3"></a>

# Abstract

This document is a Phase 0 (Research) and Phase 1 (Implementation Design) artifact for bringing functional-logic (FL) narrowing into Prologos as a core language feature. The goal: every `defn` function should be automatically usable as a relation&mdash;queryable with unbound variables&mdash; without the programmer writing a separate `defr` definition.

This is achieved through *narrowing*: the combination of unification and term rewriting, guided by *definitional trees* extracted from function definitions and driven by *needed demand analysis*.

The document covers:

1.  The formal foundations of narrowing and definitional trees
2.  Surface syntax: `=` as unification and implicit narrowing via `?` variables
3.  How definitional trees map to Prologos's existing `defn` infrastructure
4.  Constraints derived from types, specs, traits, and properties&mdash;not a separate constraint language
5.  A concrete design for the narrowing propagator
6.  Resolved design decisions (including linearity, termination, infinite constructors)
7.  A phased implementation roadmap (Phases 1&ndash;3)

**Implementation tracking**: See companion document `docs/tracking/2026-03-07_NARROWING_ABSTRACT_INTERPRETATION_DESIGN.org`.


<a id="org5a13848"></a>

# 1. Motivation: The defn/defr Divide


<a id="org35cb33c"></a>

## 1.1 The Current State

Prologos currently maintains two separate worlds:

-   **`defn`** (functions): Define computations by pattern matching and reduction. Given ground inputs, produce ground outputs. Evaluated by the reducer (`reduction.rkt`).

-   **`defr`** (relations): Define logical relationships with multiple clauses. Given goals with potentially unbound variables, search for all satisfying substitutions. Evaluated by the solver (`relations.rkt`, `solver.rkt`).

These share syntax (both use pattern matching, both support multiple clauses) but have completely separate evaluation mechanisms. A function `add` defined with `defn` cannot be used in a relational query. If you want to query "which pairs X, Y satisfy `add X Y = 5`?", you must write a separate `defr` definition that mirrors the function's logic.


<a id="org30cf048"></a>

## 1.2 The Vision

With FL narrowing, the divide disappears:

```prologos
spec add : <(x : Nat) -> (y : Nat) -> Nat>

defn add [x y]
  | [Zero y]    := y
  | [(Suc n) y] := [Suc [add n y]]

;; Use it forwards (rewriting):
eval [add [Suc Zero] [Suc Zero]]   ;; => Suc (Suc Zero)

;; Use it backwards (narrowing) — implicit via ? variables and =
let s = [add 5N ?y] = 13N
s.y   ;; => 8
;; s = ~[{:x 5 :y 8}]  — :x, :y from spec parameter names
```

Every `defn` is automatically a `defr`. The programmer writes the function once; the system derives the relational behavior through narrowing.


<a id="org9f6490d"></a>

## 1.3 Why This Matters for Prologos

Prologos's design thesis is the *unification of paradigms*: dependent types, linear types, session types, logic programming, and propagators on a single substrate. FL narrowing is the natural bridge between the functional and logic paradigms. Without it, the language has two separate evaluation models that don't interoperate. With it, the boundary dissolves.

Moreover, FL narrowing enables:

-   **Program synthesis**: Given a specification as a goal, narrowing searches for programs that satisfy it.
-   **Test generation**: Given a postcondition, narrowing generates inputs.
-   **Constraint solving**: Numeric functions become constraint propagators automatically.
-   **Symbolic execution**: Functions evaluated symbolically for verification (connects to our model checking research).


<a id="orgd266508"></a>

# 2. Surface Syntax


<a id="orgfbc206a"></a>

## 2.1 `=` as Universal Unification

Prologos reserves `=` for unification (bidirectional pattern matching). In the narrowing context, `=` is the single operator that triggers narrowing when logic variables (`?`-prefixed) appear in functional expressions:

```prologos
;; Bidirectional unification — triggers narrowing when ?vars present
[add ?x ?y] = 13N

;; In a let binding — binds the solution
let s = [add 5N ?y] = 13N
s.y   ;; => 8

;; Multiple solutions — sequence access
let s = [add ?x ?y] = 3N
s[0]   ;; => {:x 0 :y 3}
s[1]   ;; => {:x 1 :y 2}

;; Iteration over solutions
for [{:x x :y y}] in [add ?x ?y] = 13N
  [println [str x " + " y " = 13"]]
```

No `=>` operator is needed. `=` is sufficient:

-   Left side is a functional expression (possibly with `?` variables)
-   Right side is the target value (possibly with `?` variables)
-   `=` asserts they unify, triggering narrowing to find substitutions


<a id="org3b1d8df"></a>

## 2.2 Implicit Narrowing via `?` Variables

The presence of `?`-prefixed variables in a functional context IS the narrowing trigger. No separate `solve` keyword or `where` clause is needed. The system recognizes that the expression contains unbound logic variables and automatically engages narrowing.

```prologos
;; ?y triggers narrowing — solve is implicit
let result = [add 5N ?y] = 13N

;; Desugars internally to:
;; solve (= [add 5N ?y] 13N) → bindings

;; When all args are ground, = is just equality check (no narrowing)
[add 5N 8N] = 13N   ;; => true, no search needed
```


<a id="org9b55fbb"></a>

## 2.3 Bidirectional `=` in Functional Contexts

Beyond narrowing, `=` serves as a general bidirectional destructuring/ unification operator in functional contexts:

```prologos
;; Constructor destructuring (left-to-right)
let [Cons h t] = my-list
;; h and t bound from my-list

;; With logic variables (right-to-left / narrowing)
let [Cons ?h ?t] = [Cons 1N [Cons 2N Nil]]
;; ?h = 1, ?t = [Cons 2N Nil]

;; Mixed — partial binding with narrowing
let [Pair ?x 5N] = [make-pair 3N 5N]
;; ?x = 3
```

The `=` operator's direction of information flow is determined by what is bound and what is free. This is the fundamental FL narrowing principle: unification subsumes both pattern matching (one direction) and synthesis (the other direction).


<a id="org159513e"></a>

## 2.4 The `spec` as Solution Schema

When narrowing produces results, the binding keys come from the `spec` definition's parameter names:

```prologos
spec add : <(x : Nat) -> (y : Nat) -> Nat>

let s = [add 5N ?y] = 13N
;; s = ~[{:x 5 :y 8}]
;; :x from spec's first parameter name (bound value included)
;; :y from spec's second parameter name (narrowed value)
```

This parallels how `schema` provides field names for relational facts. The `spec` IS the schema for narrowing solutions. Parameter names provide named access; all known bounds are collected alongside the solved unknowns.

For functions without a `spec`, positional access is used instead:

```prologos
;; No spec — positional result
defn add [x y]
  | [Zero y]    := y
  | [(Suc n) y] := [Suc [add n y]]

let s = [add 5N ?y] = 13N
;; s = ~[{:arg0 5 :arg1 8}]   or just positional access s[0].1
```


<a id="org48cdd29"></a>

# 3. Formal Foundations


<a id="orge1b4d61"></a>

## 3.1 Term Rewriting Systems

A *term rewriting system* (TRS) $R$ is a set of rules $l \to r$ where $l$ (the left-hand side) is a term with variables and $r$ (the right-hand side) is a term whose variables are a subset of $l$'s variables.

A *rewrite step* $s \to_R t$ replaces a subterm of $s$ that matches some rule's LHS with the corresponding RHS:

-   Find position $p$ in $s$ and rule $l \to r$ in $R$ such that $s|_p = l\sigma$ for some substitution $\sigma$.
-   Then $t = s[r\sigma]_p$.

Key: rewriting requires the subterm to already be an *instance* of the LHS (pattern matching).


<a id="org0f6abc3"></a>

## 3.2 Narrowing

A *narrowing step* $s \leadsto_{R,\sigma} t$ generalizes rewriting by allowing *unification* instead of matching:

-   Find position $p$ in $s$ (where $s|_p$ is not a variable) and a renamed copy of rule $l \to r$ in $R$ (sharing no variables with $s$).
-   Compute the most general unifier $\sigma = mgu(s|_p, l)$.
-   Then $t = s\sigma[r\sigma]_p$.

Key difference: $\sigma$ may instantiate variables in $s$. The term is simultaneously *rewritten* (the rule is applied) and *narrowed* (variables are constrained).


<a id="orgae83726"></a>

## 3.3 Completeness

The *Narrowing Lemma* (Hullot 1980, Middeldorp & Hamoen 1994):

If $s\theta \to^*_R t$ for some substitution $\theta$, then there exists a narrowing derivation $s \leadsto^*_{R,\sigma} s'$ and rewriting $t \to^*_R t'$ such that $t'$ is an instance of $s'$ and $\sigma$ is more general than $\theta$ (restricted to $s$'s variables).

In plain language: *every rewriting solution can be found by narrowing*. This makes narrowing a complete method for solving equational goals over a TRS.


<a id="org45bef54"></a>

## 3.4 Definitional Trees


<a id="org7216827"></a>

### Definition (Antoy 1992)

Let $f$ be a function of arity $n$ defined by a set of rules $R_f$. A *definitional tree* of $f$ is a hierarchical case analysis structure $T$ where:

1.  **Rule node** $\text{Rule}(l \to r)$: A leaf containing a rewrite rule. The pattern $l$ is a linear term of the form $f(c_1, \ldots, c_n)$ where each $c_i$ is a constructor pattern.

2.  **Branch node** $\text{Branch}(\pi, p, [T_1, \ldots, T_k])$: An interior node with:
    
    -   $\pi$: a *pattern* (partially instantiated term $f(t_1, \ldots, t_n)$).
    -   $p$: the *inductive position* &mdash; the argument position being case- analyzed.
    -   $T_1, \ldots, T_k$: child trees, one per constructor of the type at position $p$.
    
    Each child's pattern extends $\pi$ by instantiating the variable at position $p$ to the corresponding constructor.

3.  **Exempt node** $\text{Exempt}(\pi)$: A leaf marking a position where no rule applies (partial function&mdash;the function is undefined for this pattern). May raise an error or suspend.


<a id="orge3b271d"></a>

### Example: `add`

For the function:

```prologos
defn add [x y]
  | [Zero y]    := y
  | [(Suc n) y] := [Suc [add n y]]
```

The definitional tree is:

```
Branch(position=arg1, [
  Zero   → Rule: add(Zero, y) = y
  Suc(n) → Rule: add(Suc(n), y) = Suc(add(n, y))
])
```


<a id="orga8dea3b"></a>

### Example: `last` (nested branching)

```prologos
defn last [xs]
  | [[Cons x Nil]]         := x
  | [[Cons x [Cons y ys]]] := [last [Cons y ys]]
```

Definitional tree:

```
Branch(position=arg1, [
  Nil         → Exempt (last [] is undefined)
  Cons(x, xs) → Branch(position=arg1.2, [
    Nil         → Rule: last(Cons(x, Nil)) = x
    Cons(y, ys) → Rule: last(Cons(x, Cons(y, ys))) = last(Cons(y, ys))
  ])
])
```


<a id="org2ac8275"></a>

## 3.5 Inductively Sequential Functions

A function $f$ is *inductively sequential* if its defining rules can be organized into a definitional tree. Equivalently: the case analysis of $f$'s arguments is *uniform* (at each level, the same argument position is analyzed for all patterns) and *non-overlapping* (each input matches at most one rule).

Most functions written in natural pattern-matching style are inductively sequential. Functions with overlapping rules (non-deterministic functions) or guards are not, but can be handled by generalizations (or-branches, conditional branches).


<a id="org15a97ff"></a>

## 3.6 The Needed Narrowing Strategy

Given a goal $f(t_1, \ldots, t_n) = t$:

1.  Look up the definitional tree $T$ for $f$.
2.  At a **Branch** node on position $p$:
    -   Let $s$ be the subterm at position $p$ in the current arguments.
    -   If $s$ is a *constructor* $c(\ldots)$: follow the child for $c$ (deterministic step).
    -   If $s$ is a *variable* $X$: create a *choice point* over all constructors $c_1, \ldots, c_k$ of the appropriate type. For each $c_i$, bind $X := c_i(\text{fresh vars})$ and continue down child $i$.
    -   If $s$ is a *function application* $g(\ldots)$: recursively *demand* the evaluation of $g$&mdash;narrow $g$ first, then retry.
3.  At a **Rule** node $l \to r$: apply the rule. Unify $r\sigma$ with the target $t$ to further constrain variables.
4.  At an **Exempt** node: fail (this branch has no solution).


<a id="orgda65472"></a>

### Optimality (Antoy, Echahed, Hanus 2000)

For inductively sequential functions:

-   **Minimal length**: No narrowing derivation to the same result is shorter.
-   **Independent solutions**: Computed substitutions are pairwise incomparable (no redundant generalizations).
-   **Subsumption**: When all arguments are ground, needed narrowing reduces to lazy evaluation (no choice points created). When all functions are constructors, it reduces to SLD resolution.


<a id="orgc1aa618"></a>

## 3.7 Non-Deterministic Functions

When a function has overlapping rules (multiple clauses match the same input), it is *non-deterministic*. This is the bridge to `defr`:

```prologos
defn insert [x xs]
  | [x xs]           := [Cons x xs]
  | [x [Cons y ys]]  := [Cons y [insert x ys]]
```

Both clauses match `insert 3 [Cons 1 [Cons 2 Nil]]`. In the functional- logic paradigm, both results are returned non-deterministically. The definitional tree has an *or-branch* at the root:

```
Or([
  Rule: insert(x, xs) = Cons(x, xs),
  Branch(position=arg2, [
    Nil         → Exempt,
    Cons(y, ys) → Rule: insert(x, Cons(y, ys)) = Cons(y, insert(x, ys))
  ])
])
```

Non-deterministic functions in narrowing directly correspond to relations in logic programming. This is the formal justification for treating `defn` with overlapping rules as automatically generating a `defr`.


<a id="orge59b3be"></a>

## 3.8 Residuation

An alternative to narrowing for functions with unbound arguments:

-   **Narrowing**: Guess the constructor (create choice point), then continue.
-   **Residuation**: Suspend evaluation until the variable is bound by another constraint. If never bound, the goal remains suspended (residual).

Residuation is deterministic (no choice points) but incomplete (may miss solutions if nothing binds the variable). Narrowing is complete but may create exponentially many choice points.

In Prologos, residuation is *already implemented* by the propagator network: a propagator whose input cell is `bot` doesn't fire. When the cell is written, the propagator fires. This is exactly residuation.


<a id="org3c02875"></a>

# 4. Constraints from the Type System


<a id="org92cabbb"></a>

## 4.1 No `where` Clause &mdash; Types ARE Constraints

A key design decision: Prologos does not need a separate constraint syntax for narrowing. The constraint information already lives in the type system:

-   **Types** are domain constraints.
-   **Subtypes** are refined domains.
-   **Traits** are capability constraints.
-   **Properties** on `spec` definitions are axioms/rewrite rules.

This means the constraint system is the type system, repurposed for narrowing. No new constraint language is needed.


<a id="org9b9d287"></a>

## 4.2 Types as Domain Constraints

```prologos
spec add : <(x : PosInt) -> (y : PosInt) -> PosInt>

;; PosInt carries the constraint x > 0
;; Narrowing automatically restricts domain to positive integers
[add ?x ?y] = 13N
;; Domain of ?x: PosInt = [1, ∞)
;; Domain of ?y: PosInt = [1, ∞)
;; After constraint propagation: ?x ∈ [1, 12], ?y ∈ [1, 12]
```


<a id="org524b720"></a>

## 4.3 Subtypes as Refined Domains

```prologos
subtype PosInt Int via pos-to-int
;; PosInt ⊂ Int → domain of PosInt is [1, ∞)
;; The subtype registry (already implemented) provides this information
```

The subtype registry, already used for coercion and type-checking, doubles as the constraint domain specification. When narrowing encounters a variable of type `PosInt`, it reads the subtype bounds from the registry.


<a id="org6d6ad89"></a>

## 4.4 Properties as Constraint Strengtheners

```prologos
spec add
  :property commutative     ;; add x y = add y x
  :property associative     ;; add (add x y) z = add x (add y z)
  :property (identity Zero) ;; add Zero x = x
```

Properties are *axioms* that the narrowing engine can use as additional rewrite rules:

-   `commutative` means the narrowing propagator can try arguments in either order.
-   `identity Zero` means `[add Zero ?x] = ?x` can be resolved without search (the identity rule applies directly).
-   Properties become *constraint strengtheners*&mdash;they narrow the search space before enumeration begins.


<a id="orgcf5a689"></a>

## 4.5 Traits as Capability Constraints

```prologos
spec sort {A : Type} [Ord A] : <(xs : [List A]) -> [List A]>
;; [Ord A] tells the narrowing engine:
;; A must have an Ord instance. When narrowing over A's constructors,
;; only types with Ord instances are valid.
```

Trait constraints restrict the constructor universe at narrowing time. The trait instance registry (already implemented) provides the valid set.


<a id="orgb4b2193"></a>

# 5. Mapping to Prologos Infrastructure


<a id="orgc84c509"></a>

## 5.1 Definitional Trees from `defn`

A Prologos `defn` definition is parsed and elaborated into a list of clauses, each with a pattern (LHS) and body (RHS). The definitional tree can be extracted by analyzing the pattern structure:


<a id="org2b86676"></a>

### Pattern Structure in Prologos AST

After elaboration, each clause has:

-   `args`: a list of patterns (one per parameter)
-   Each pattern is: a variable (`expr-fvar`), a constructor application (`expr-app` of a `expr-ctor`), a literal, or a wildcard


<a id="org9f7dff3"></a>

### Extraction Algorithm

```
extract-definitional-tree(clauses, arg-positions):
  1. If clauses is a singleton: return Rule(clause)
  2. Find the first arg position p where clauses disagree on the
     outermost constructor:
     a. For each position, collect the set of top-level constructors
        across all clauses
     b. The "inductive position" is the first position with >1 distinct
        constructors (or a mix of constructor and variable)
  3. If no such position: clauses overlap → return Or(clauses)
  4. Group clauses by the constructor at position p
  5. For each group: recursively extract the subtree (after peeling one
     layer of pattern at position p)
  6. Return Branch(p, [(ctor1, subtree1), ..., (ctorK, subtreeK)])
```

This is a compile-time analysis&mdash;the definitional tree is computed once during elaboration and stored alongside the function definition.


<a id="org72720f1"></a>

### Handling Prologos-Specific Features

| Feature                         | Definitional Tree Mapping                                   |
|------------------------------- |----------------------------------------------------------- |
| Wildcard (`_`)                  | Variable (matches any constructor)                          |
| Literal (`42N`, `"hello"`)      | Constructor (nullary; one child per literal value)          |
| Guard (`\vert [pred x] := ...`) | Conditional branch (evaluate guard after constructor match) |
| Higher-order args               | Opaque (treat as variable; residuate — don't branch)        |


<a id="org1b82db1"></a>

## 5.2 Constructor Universe

Needed narrowing requires knowing *all constructors* of a type at each branch point (to enumerate the alternatives for a variable). In Prologos:

-   ADT definitions (`type Nat := Zero \vert [Suc Nat]`) provide the complete constructor set.
-   The type checker already tracks constructor info (stored in the global environment during elaboration).
-   At each branch node, the definitional tree records the type at the inductive position, which gives the constructor universe.
-   For types with infinite constructors (Nat, Int, String), abstract interpretation provides finite over-approximation (see §8).


<a id="orgb3e24ce"></a>

## 5.3 The Propagator Connection

Each element of the narrowing evaluation maps to a propagator network operation:

| Narrowing Concept                      | Propagator Network Operation                              |
|-------------------------------------- |--------------------------------------------------------- |
| Variable (unknown)                     | Cell at `bot`                                             |
| Known constructor                      | Cell contains constructor tag + subcells                  |
| Narrowing step (instantiate var)       | `net-cell-write` (refine cell value)                      |
| Choice point (multiple constructors)   | `atms-amb` with mutual exclusion                          |
| Deterministic step (known constructor) | Direct branch in narrowing propagator                     |
| Residuation (wait for input)           | Propagator doesn't fire (input cell is `bot`)             |
| Recursive demand                       | Chain of narrowing propagators (fire in dependency order) |
| Unification (`=`)                      | `net-cell-write` with lattice merge                       |
| Failure (exempt/no match)              | Contradiction in cell                                     |
| Solution                               | All cells at fixpoint with consistent values              |


<a id="org0ea8515"></a>

## 5.4 Term Cells

For narrowing, we need cells that hold *partial term information*. We define a *Term Lattice*:

```
TermLattice:
  bot          — nothing known
  Var(id)      — logic variable (may be unified later)
  Ctor(tag, [cell-id, ...])  — constructor with subcells
  top          — contradiction (incompatible constructors)

Merge:
  bot ⊔ x = x
  x ⊔ bot = x
  Var(a) ⊔ Var(b) = unify(a, b)  ;; union-find
  Var(a) ⊔ Ctor(t, cs) = bind(a, Ctor(t, cs))
  Ctor(t1, cs1) ⊔ Ctor(t2, cs2) =
    if t1 = t2: Ctor(t1, [merge(c1i, c2i) ...])
    else: top  ;; contradiction
```

This is a lattice: `bot` is bottom, `top` is top, and merge is a monotone join operation. Contradiction (incompatible constructors) is detected immediately.


<a id="org8636554"></a>

# 6. Narrowing Propagator Design


<a id="orgfa418f7"></a>

## 6.1 The Narrowing Propagator

For each function `f` with definitional tree `T`, we create a *narrowing propagator factory* that, given argument cells and a result cell, installs propagators implementing needed narrowing:

```
install-narrowing-propagators(net, f, arg-cells, result-cell, def-tree):
  match def-tree:
    Rule(lhs → rhs):
      ;; Install propagator: when arg-cells match lhs, write rhs to result-cell
      net-add-propagator(net, arg-cells, [result-cell], fire-rule(lhs, rhs))

    Branch(pos, children):
      ;; Install propagator watching cell at position `pos`
      let watched-cell = arg-cells[pos]
      net-add-propagator(net, [watched-cell], [],
        lambda(net):
          let val = net-cell-read(net, watched-cell)
          match val:
            bot → net  ;; residuate (wait for info)
            Ctor(tag, sub-cells) →
              ;; Deterministic: follow the branch for `tag`
              let child = lookup(children, tag)
              install-narrowing-propagators(...)
            Var(id) →
              ;; Non-deterministic: create amb over constructors
              let ctors = all-constructors-of-type-at(pos)
              atms-amb(net, ctors, ...)
              ;; For each constructor alternative, install child propagators
              ...)

    Or(branches):
      ;; Non-deterministic function: try all branches via amb
      atms-amb(net, branches, ...)

    Exempt(pattern):
      ;; Mark contradiction (function undefined for this pattern)
      net-cell-write(net, result-cell, 'top)
```


<a id="orgd5b8d29"></a>

## 6.2 Demand-Driven Evaluation

The narrowing propagator's behavior at a Branch node with a `bot` cell implements *residuation*: it simply doesn't fire, waiting for information. This is the default behavior for Prologos's propagator network (propagators don't fire until their input cells change).

When narrowing (not residuation) is desired, the search phase creates `amb` choices. This happens at the *branching phase* of the propagate→branch→propagate loop:

1.  Propagation runs to quiescence.
2.  If unresolved demands remain (cells at `bot` that narrowing propagators are waiting on): the search heuristic selects one such cell and creates an `amb` over its possible constructors.
3.  Propagation resumes, possibly resolving other demands.


<a id="org73f4c29"></a>

## 6.3 Interaction with the Solver Loop

The narrowing propagator integrates into the existing solver architecture:

```
narrowing-solve(goal, strategy):
  1. Create fresh arg cells and result cell
  2. Install narrowing propagators for the goal function
  3. Unify result cell with goal target (=)
  4. Read domain constraints from spec types/subtypes
  5. LOOP:
     a. run-to-quiescence
     b. IF result cell determined AND all arg cells determined:
        project spec parameter names → RETURN binding map
     c. IF contradiction: BACKTRACK
     d. Find unresolved demands (bot cells with waiting propagators)
     e. SELECT demand to resolve (variable ordering heuristic)
     f. SELECT constructor for that demand (value ordering heuristic)
     g. CREATE amb choice point
     h. GOTO 5a
```


<a id="orge71aa44"></a>

## 6.4 Backward Compatibility

The narrowing propagator is *additive*: it doesn't change how `defn` functions evaluate when called with ground arguments. In that case:

1.  All arg cells are immediately written with ground values.
2.  The narrowing propagator fires deterministically at each branch (no `amb` needed&mdash;the constructor is known).
3.  The result cell receives the function's output.
4.  This is exactly equivalent to the existing reducer behavior.

The narrowing mechanism is only activated when `?` variables appear in a functional context with `=`.


<a id="orge5ad6af"></a>

# 7. Design Decisions


<a id="orga6a5328"></a>

## D1: Residuation by Default, Narrowing on Demand

Functions *residuate* by default (wait for input). Narrowing is activated only when:

(a) A `?` variable appears in a functional expression with `=`, OR (b) The function is annotated as `:narrowable`, OR (c) The search phase encounters an unresolved demand.

Rationale: residuation is deterministic and avoids unnecessary search. Narrowing creates choice points and should only be used when search is intended.


<a id="orgd52be77"></a>

## D2: `=` as Sole Unification Operator

`=` is the single operator for unification/narrowing. No `=>` needed. The direction of information flow is determined by what is bound (ground) vs. free (`?` variable). This is consistent with Prologos's reservation of `=` for the `unify` operation and avoids adding a redundant operator.

The `=` operator's semantics in context:

-   Both sides ground: equality check (no search)
-   One side has `?` variables: narrowing (search for substitutions)
-   Both sides have `?` variables: full bidirectional unification


<a id="org1291a61"></a>

## D3: `spec` as Solution Schema

`spec` parameter names provide the keys in narrowing result bindings. All known bounds are collected alongside solved unknowns. This parallels `schema` providing field names for relational facts.


<a id="org9038e4d"></a>

## D4: Constraints from Types, Not from `where`

No `where` clause or separate constraint language. Constraints are drawn from:

-   Type annotations (domain bounds)
-   Subtypes (refined domains via subtype registry)
-   Traits (capability constraints)
-   Properties on `spec` (axioms / additional rewrite rules)


<a id="org26398d7"></a>

## D5: Definitional Tree Extraction at Elaboration Time

The definitional tree is computed during elaboration (not at query time). This is a static analysis with cost proportional to the number of clauses. The tree is stored as part of the function's metadata in the global environment.


<a id="orge754614"></a>

## D6: Constructor Universe from Type Definitions

The constructor universe at each branch point is drawn from the ADT definition. For types with infinite constructors, abstract interpretation narrows to a finite domain (Phase 2&mdash;see §8).

For polymorphic functions, the constructor universe is parameterized by the type argument. At narrowing time, the type argument must be resolved (either from the goal type or by constraint propagation) before `amb` alternatives can be created.


<a id="org35b4111"></a>

## D7: Non-Deterministic Functions Create Or-Branches

Functions with overlapping rules are treated as non-deterministic: the definitional tree has Or-branches, and narrowing creates `amb` over the alternatives. This is consistent with Curry's semantics and Prologos's existing `defr` behavior.


<a id="orgec757f4"></a>

## D8: Term Lattice for Variable Cells

Narrowing variables are represented as cells in a *Term Lattice* (§5.4). This is a new lattice type alongside the existing ones (FlatLattice, SetLattice, IntervalLattice). It integrates with the existing propagator infrastructure via the standard `net-new-cell` + merge function interface.


<a id="orgc5ffdae"></a>

## D9: ATMS Worldview Semantics for Linearity

Linear variables (QTT multiplicity 1) in narrowing branches use ATMS worldview semantics:

-   Each `amb` branch is a separate worldview under a distinct assumption.
-   Linearity is checked *per-worldview*: in each consistent worldview, the linear variable is used exactly once.
-   **Learnings ARE shared across worldviews**: nogoods are global (contradictions discovered in one branch prune all worldviews containing that assumption set), and unconditional facts (empty assumption label) are shared by all worldviews.
-   Only assumption-dependent facts are isolated (which is exactly the right isolation for linearity).

This is strictly better than chronological backtracking:

-   Backtracking forgets everything when it backtracks (no learning).
-   ATMS remembers contradictions (learning via nogoods).
-   ATMS shares unconditional derivations (no redundant computation).


<a id="org5f8fe9c"></a>

## D10: Higher-Order &mdash; Narrow on Application

When a higher-order function argument is *known* (a specific `defn`), narrow through the application. The cost is equivalent to `defr` clause resolution (one unification attempt per clause). With definitional trees: O(tree depth), typically O(log N) for balanced case analysis.

When the function argument is *unknown*, residuate (wait for it to be determined by another constraint). If it cannot be determined, the goal remains suspended.

Auto-defunctionalization via 0-CFA closure analysis is a Phase 3 extension (see §8.3).


<a id="org2f3c918"></a>

## D11: Backward-Compatible with `defr`

FL narrowing does not replace `defr`. Relations defined with `defr` continue to work as before. The new capability is that `defn` functions *also* work as relations. For cases where the programmer explicitly wants relational semantics (e.g., multi-mode predicates, recursive relations with tabling), `defr` remains the right tool.


<a id="org9d0ea7e"></a>

# 8. Implementation Roadmap


<a id="orge9e6848"></a>

## Phase 1: Core FL Narrowing


<a id="org0b4a22d"></a>

### Phase 1a: Definitional Tree Infrastructure

-   [ ] Define `def-tree` Racket struct hierarchy (`dt-rule`, `dt-branch`, `dt-or`, `dt-exempt`)
-   [ ] Implement `extract-definitional-tree` from elaborated `defn` clauses
-   [ ] Store definitional tree in function metadata (global env)
-   [ ] Test: extract trees for `add`, `append`, `map`, `last`, `insert`
-   [ ] Test: detect and handle overlapping rules (Or-branches)
-   [ ] Test: detect and handle exempt positions (partial functions)

Estimated: `200 lines in new ~definitional-tree.rkt`, ~40 tests


<a id="orge080ecd"></a>

### Phase 1b: Term Lattice

-   [ ] Define `term-lattice` types (`term-bot`, `term-var`, `term-ctor`, `term-top`)
-   [ ] Implement `term-merge` (lattice join with unification semantics)
-   [ ] Implement `term-contradiction?` (top detection)
-   [ ] Implement `term-walk` (transitive variable resolution)
-   [ ] Integrate with `net-new-cell` (term cells in propagator network)
-   [ ] Test: merge bot/var, var/var (unification), var/ctor (binding), ctor/ctor (recursive merge vs. contradiction)

Estimated: `150 lines in new ~term-lattice.rkt`, ~30 tests


<a id="org8f88095"></a>

### Phase 1c: Narrowing Propagator

-   [ ] Implement `install-narrowing-propagators` factory function
-   [ ] Handle Branch nodes (deterministic constructor following)
-   [ ] Handle Rule nodes (rewrite application → cell write)
-   [ ] Handle Exempt nodes (contradiction)
-   [ ] Handle Or-branches (non-deterministic `amb`)
-   [ ] Handle recursive function calls (chain narrowing propagators)
-   [ ] Residuation behavior (bot → don't fire)
-   [ ] Test: narrowing `add`, `append`, `map` with unbound args
-   [ ] Test: deterministic evaluation (ground args → same result as reducer)
-   [ ] Test: non-deterministic functions (`insert`)
-   [ ] Test: nested narrowing (recursive functions)

Estimated: `300 lines in new ~narrowing.rkt`, ~50 tests


<a id="org8c2920b"></a>

### Phase 1d: Solver Integration

-   [ ] Extend `solve` to recognize `defn` functions in goals
-   [ ] Install narrowing propagators for function goals
-   [ ] Implement demand-driven narrowing in the search loop
-   [ ] Project `spec` parameter names into binding maps
-   [ ] Connect to variable/value ordering heuristics (if available)
-   [ ] Test: narrowing with `=` in functional contexts
-   [ ] Test: `spec` parameter name projection in results
-   [ ] Test: mixed `defn~/~defr` goals
-   [ ] Test: narrowing with constraints (`leq`, `neq`)
-   [ ] Test: encapsulated search (returns all solutions as sequence)

Estimated: `200 lines modifying ~relations.rkt` + `solver.rkt`, ~50 tests


<a id="orga2feaec"></a>

### Phase 1e: WS-Mode Surface Syntax

-   [ ] `=` operator syntax in WS reader for unification
-   [ ] `?` variable detection in functional contexts → narrowing trigger
-   [ ] Solution binding access: `s.y`, `s[0].y` syntax
-   [ ] `for` iteration over narrowing results
-   [ ] WS-mode integration tests
-   [ ] Error messages for non-narrowable functions (if any)

Estimated: ~100 lines, ~30 tests


<a id="orgfa402d8"></a>

### Phase 1 Summary

| Sub-phase                | Files                         | Lines (est.) | Tests (est.) |
|------------------------ |----------------------------- |------------ |------------ |
| 1a: Definitional Trees   | `definitional-tree.rkt`       | 200          | 40           |
| 1b: Term Lattice         | `term-lattice.rkt`            | 150          | 30           |
| 1c: Narrowing Propagator | `narrowing.rkt`               | 300          | 50           |
| 1d: Solver Integration   | `relations.rkt`, `solver.rkt` | 200          | 50           |
| 1e: WS-Mode Syntax       | parser, WS reader             | 100          | 30           |
| **Total**                | **3 new + 3 modified**        | **~950**     | **~200**     |


<a id="org1c4ffb7"></a>

## Phase 2: Abstract Interpretation for Narrowing (see companion design doc)

-   [ ] Interval abstract domain for numeric types (Nat → [lo, hi])
-   [ ] Galois connection: concrete term cells ↔ abstract interval cells
-   [ ] Finite solution cardinality analysis (compile-time)
-   [ ] Size-based termination analysis for recursive narrowing
-   [ ] Widening for fixpoint convergence on abstract domains
-   [ ] Critical pair analysis for confluence detection

See: `docs/tracking/2026-03-07_NARROWING_ABSTRACT_INTERPRETATION_DESIGN.org`


<a id="org5843ed0"></a>

## Phase 3: Advanced Extensions (see companion design doc)

-   [ ] 0-CFA closure analysis for auto-defunctionalization
-   [ ] Configurable search heuristics (variable ordering, value selection)
-   [ ] Global constraints (`all-different`, `cumulative`)
-   [ ] Branch-and-bound optimization (`minimize`, `maximize`)

See: `docs/tracking/2026-03-07_NARROWING_ABSTRACT_INTERPRETATION_DESIGN.org`


<a id="orgcc7184f"></a>

# 9. Related Work

-   Antoy, Echahed, Hanus. "A Needed Narrowing Strategy." *JACM* 47(4), 2000.
-   Antoy. "Definitional Trees." *ALP* 1992.
-   Antoy, Hanus. "Functional Logic Programming." *CACM* 53(4), 2010.
-   Antoy. "Evaluation Strategies for FL Programming." *JSC* 40(1), 2005.
-   Hanus et al. "Curry: A Truly Integrated Functional Logic Language." <https://www.curry-lang.org/>
-   Brassel et al. "KiCS2: A New Compiler from Curry to Haskell." *PADL* 2011.
-   Fernandez et al. "Constraint Functional Logic Programming over Finite Domains." *TPLP* 7(1-2), 2007.
-   Escobar, Meseguer. "Symbolic Model Checking Using Narrowing." *RTA* 2007.
-   Radul, Sussman. "The Art of the Propagator." MIT TR, 2009.
-   de Kleer. "An Assumption-Based TMS." *AIJ* 28(2), 1986.
-   Reynolds. "Definitional Interpreters for Higher-Order Languages." 1972. (defunctionalization)
-   Cousot, Cousot. "Abstract Interpretation: A Unified Lattice Model." 1977.
-   Shivers. "Control-Flow Analysis of Higher-Order Languages." 1991. (0-CFA)


<a id="org3d5b816"></a>

# 10. Conclusion

FL narrowing is the missing bridge between Prologos's functional (`defn`) and relational (`defr`) worlds. The surface syntax is minimal: `=` for unification, `?` for logic variables, `spec` for solution schemas. Constraints come from the type system, not a separate language.

The infrastructure for implementing it already exists: propagator cells are the narrowing substrate, the ATMS provides choice-point management with shared learning, and `defn`'s multi-clause syntax provides the definitional tree structure.

The implementation decomposes into three phases: core narrowing (Phase 1, ~950 lines, ~200 tests), abstract interpretation for infinite domains and termination (Phase 2), and advanced extensions including auto- defunctionalization and configurable search heuristics (Phase 3).

The resulting system would be, to our knowledge, the first language that implements FL narrowing on a *propagator network* substrate, combining:

-   The optimality of needed narrowing (Antoy et al.)
-   The parallelism and incrementality of propagator networks
-   The hypothetical reasoning of ATMS (vs. chronological backtracking)
-   The integration with dependent types, linear types, and session types
-   Abstract interpretation for handling infinite constructor universes

This positions Prologos not just as a language that supports multiple paradigms, but as a language where the paradigms are *unified*&mdash;functional computation, logic programming, and constraint solving are all instances of monotone refinement on a lattice, guided by demand, branched by heuristic choice, and verified by type.
