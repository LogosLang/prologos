- [The Core Idea: Relations as First-Class Duals of Functions](#org8674234)
- [Syntax Decisions](#org64f3260)
  - [Delimiter Distinction: `(...)` vs `[...]`](#org66d44fb)
  - [`defr` / `rel` Keywords](#orgef4816b)
  - [`&>` Conjunction Syntax](#org7661600)
  - [Logic Variables: `?var` Prefix](#org93eedf2)
  - [Mode Prefixes: `?`, `-`, `+`](#org6e03491)
- [The `solve` / `solve-with` Bridge](#orga62065a)
  - [`solve`: Functional-Relational Bridge](#org0da1363)
  - [`solve-with`: Solver-as-Metadata-Entity](#org9e97d54)
  - [Solver Architecture](#org8bedc57)
- [Tabling by Default](#orgf402cbc)
  - [Lattice Answer Modes](#org21cd7b8)
- [Provenance as First-Class](#org9b38d52)
- [First-Class Propagators and Network Mobility](#orgb6aff6f)
- [Integration with Functional Language](#org2cbbc76)
  - [Relations in Functional Code](#orgec692fd)
  - [Functions in Relational Code](#org295657c)
- [Design Principles Summary](#org5296c9e)
- [What This Document Does NOT Cover](#org890eb39)



<a id="org8674234"></a>

# The Core Idea: Relations as First-Class Duals of Functions

The relational paradigm in Prologos is not an add-on or embedded DSL &#x2014; it is a first-class language paradigm, co-equal with functional programming. Just as `fn` creates anonymous functions and `defn` creates named functions, `rel` creates anonymous relations and `defr` creates named relations.

| Paradigm   | Named     | Anonymous | Application | Delimiter |
|---------- |--------- |--------- |----------- |--------- |
| Functional | `defn`    | `fn`      | `[f x y]`   | `[...]`   |
| Relational | `defr`    | `rel`     | `(R ?x ?y)` | `(...)`   |
| Process    | `defproc` | `proc`    | indentation | indent    |

The parenthetical `(...)` delimiter is the visual sigil for relational forms, just as `[...]` is for functional application. This is not arbitrary &#x2014; it reflects a genuine semantic distinction: functional forms *compute values*, relational forms *constrain search spaces*.


<a id="org64f3260"></a>

# Syntax Decisions


<a id="org66d44fb"></a>

## Delimiter Distinction: `(...)` vs `[...]`

The reader dispatches differently based on the opening delimiter:

-   **`[map inc xs]`:** Functional application. Evaluate `map` with arguments `inc` and `xs`. Returns a value.

-   **`(parent ?x ?y)`:** Relational goal. Assert or query the `parent` relation with logic variables `?x` and `?y`. Returns a stream of substitutions.

This delimiter distinction is visible, mechanical, and unambiguous. A human reader can instantly tell whether a subexpression is functional or relational by looking at the bracket type. The s-expression representation preserves the distinction: `($rel-app parent ?x ?y)` vs `($app map inc xs)`.


<a id="orgef4816b"></a>

## `defr` / `rel` Keywords

`defr` is the relational counterpart of `defn`:

```prologos
;; Named relation with multiple clauses
defr ancestor [?x ?y]
  &> (parent ?x ?y)
  &> (parent ?x ?z) (ancestor ?z ?y)

;; Anonymous relation (first-class, passable, composable)
let reachable := (rel [?from ?to ?path]
  &> (= ?from ?to) (= ?path '[?to | nil])
  &> (edge ?from ?mid)
     (reachable ?mid ?to ?rest)
     (= ?path '[?from | ?rest]))
```

No existing logical or logical-functional language has a true anonymous relation (`rel`) that can be bound to names and passed between contexts like a lambda. This is Prologos's key innovation for logic-functional fusion.


<a id="org7661600"></a>

## `&>` Conjunction Syntax

The `&>` operator introduces a clause (disjunctive alternative) within a relation definition. Within a clause, goals are implicitly conjoined (sequential conjunction, left to right).

```prologos
;; Two clauses, each with implicit conjunction
defr ancestor [?x ?y]
  &> (parent ?x ?y)                          ;; clause 1: base case
  &> (parent ?x ?z) (ancestor ?z ?y)        ;; clause 2: recursive
  ;;                 ^--- conjoined goals within clause 2
```

Design rationale:

-   `&>` is visually distinct from functional operators (`|>`, `>>`)
-   It reads as "and also, by this rule&#x2026;" &#x2014; each `&>` is a logical OR
-   Within a clause, goals are conjoined by whitespace juxtaposition (AND)
-   The visual structure mirrors Prolog's clause-based semantics


<a id="org93eedf2"></a>

## Logic Variables: `?var` Prefix

Logic variables are distinguished by the `?` prefix. This is the default "free" mode &#x2014; the variable may be bound or unbound at entry, and unification determines its value.

```prologos
(ancestor ?who "carol")    ;; ?who is a logic variable
[map inc xs]               ;; xs is a functional variable (no ?)
```

The `?` prefix serves multiple purposes:

1.  Visual distinction from functional variables
2.  Reader-level dispatch (the reader emits `($logic-var who)`)
3.  Scope delimitation (logic vars are scoped to their enclosing `rel~/~defr`)
4.  Mode annotation carrier (see below)


<a id="org6e03491"></a>

## Mode Prefixes: `?`, `-`, `+`

Mercury-inspired mode annotations provide optimization hints to the solver:

| Mode | Symbol | Meaning                        |
|---- |------ |------------------------------ |
| Free | `?var` | May be bound or unbound        |
| In   | `-var` | Must be bound on entry         |
| Out  | `+var` | Unbound, will be bound by goal |

```prologos
;; Mode-annotated relation
defr append [-xs -ys +zs]
  &> (= -xs nil) (= +zs -ys)
  &> (= -xs [cons ?h ?t]) (append ?t -ys ?rest) (= +zs [cons ?h ?rest])
```

Modes are *optional* &#x2014; the default `?` works for all cases. When provided, modes enable the solver to choose more efficient strategies (e.g., indexing on bound arguments, generating rather than checking unbound arguments).


<a id="orga62065a"></a>

# The `solve` / `solve-with` Bridge


<a id="org0da1363"></a>

## `solve`: Functional-Relational Bridge

`solve` is the bridge from the relational world back to the functional world. It evaluates a relational goal and returns results as a functional value.

```prologos
;; Basic solve: returns Seq of substitution maps
let results := (solve [ancestor "alice" ?who])
;; results : Seq (Map Symbol Value)
;; => [{?who: "bob"}, {?who: "carol"}, {?who: "dave"}]

;; With destructuring
match (solve [ancestor "alice" ?who])
  | [some bindings] -> [map-get bindings :who]
  | none -> "nobody"
```

The return type of `solve` is `Seq (Map Symbol Value)` &#x2014; a lazy sequence of substitution maps. This integrates naturally with the functional collection system: results can be mapped, filtered, folded, taken, etc.


<a id="org9e97d54"></a>

## `solve-with`: Solver-as-Metadata-Entity

`solve-with` parameterizes the solver itself, allowing different search strategies, constraint domains, and resource limits:

```prologos
;; Using a specific solver configuration
let results := (solve-with
  :strategy depth-first
  :timeout 5000          ;; milliseconds
  :max-solutions 10
  [ancestor "alice" ?who])

;; Using a custom constraint domain
let results := (solve-with
  :domain interval-arithmetic
  :widening standard
  [constraint ?x ?y])
```

The solver configuration is a map of metadata keys. This follows the established Prologos pattern: structured metadata attached to operations. The solver is not a fixed runtime but a configurable entity.


<a id="org8bedc57"></a>

## Solver Architecture

The solver is layered, following the three-layer propagator architecture:

1.  **Propagator Network** (Layer 1): Cells hold lattice values. Unification is a join on the substitution lattice. Deterministic, order-independent.

2.  **ATMS Layer** (Layer 2): Hypothetical reasoning for nondeterminism. `amb` creates choice points. Nogoods prune search space. Dependency-directed backtracking.

3.  **Stratification** (Layer 3): Negation-as-failure and aggregation. Evaluated stratum-by-stratum. Non-monotonic operations observe completed lower strata.

The default solver uses all three layers. `solve-with` allows selecting subsets (e.g., pure Datalog only needs Layer 1, no ATMS).


<a id="orgf402cbc"></a>

# Tabling by Default

All `defr` relations are tabled by default. This is a departure from Prolog's untabled default, motivated by correctness:

-   Left-recursive rules terminate (no infinite loops)
-   Redundant computation is eliminated (memoization)
-   Completeness is guaranteed (all answers found)

The tabling implementation follows XSB Prolog's SLG resolution, extended with lattice answer modes for Datalog-style aggregate computation.

```prologos
;; Tabled by default
defr ancestor [?x ?y]
  &> (parent ?x ?y)
  &> (parent ?x ?z) (ancestor ?z ?y)
  ;; Left-recursive call to ancestor is safe --- tabling prevents loops

;; Opt-out for performance-critical untabled relations
defr fast-lookup [?x ?y]
  :tabled false
  &> (fact-table ?x ?y)
```


<a id="org21cd7b8"></a>

## Lattice Answer Modes

Tabled predicates can aggregate answers via lattice operations:

```prologos
;; Standard tabling: collect all answers
defr reachable [?x ?y]
  :answer-mode all

;; Lattice tabling: aggregate via min
defr shortest-distance [?x ?y ?d]
  :answer-mode (lattice min)

;; First-answer tabling: stop after one
defr any-path [?x ?y ?path]
  :answer-mode first
```


<a id="org9b38d52"></a>

# Provenance as First-Class

Every derivation in the relational language produces a *provenance trace* &#x2014; a record of which rules fired, which unifications succeeded, and which assumptions were made. Provenance is first-class data that can be:

-   **Inspected**: "Show me why this answer was derived"
-   **Logged**: Audit trails for compliance and debugging
-   **Serialized**: Machine-readable derivation trees for external tools
-   **Compared**: "Are these two derivations isomorphic?"

```prologos
;; Solve with provenance tracking
let (results, provenances) := (solve-with
  :provenance true
  [ancestor "alice" ?who])

;; Each provenance is a derivation tree
;; ancestor("alice", "carol")
;;   ├── parent("alice", "bob")   [fact]
;;   └── ancestor("bob", "carol")
;;       └── parent("bob", "carol") [fact]
```

Provenance is built on the ATMS's support sets. Each derived fact carries the set of assumptions that justify it. This is not an add-on &#x2014; it is inherent in the propagator architecture.


<a id="orgb6aff6f"></a>

# First-Class Propagators and Network Mobility

Propagator networks are not just an implementation detail &#x2014; they are first-class values that can be:

-   **Created**: Build a propagator network from a relation definition
-   **Connected**: Wire networks together via shared cells
-   **Migrated**: Send a network to another actor/process
-   **Snapshotted**: Freeze a network's state for later resumption
-   **Composed**: Combine two networks into a larger one

```prologos
;; Create a propagator network from a relation
let net := (make-network [ancestor facts])

;; Add new facts dynamically
(network-add! net [parent "eve" "alice"])

;; Query the updated network
let results := (network-solve net [ancestor "eve" ?who])
;; Incremental: only re-propagates from the new fact

;; Snapshot for later
let frozen := (network-snapshot net)
;; frozen can be serialized, sent to another actor, resumed
```

Network mobility is essential for distributed AI agent architectures. An agent can construct a knowledge base, derive conclusions, then ship the entire network to another agent for further reasoning. Session types ensure the transfer protocol is correct.


<a id="org2cbbc76"></a>

# Integration with Functional Language


<a id="orgec692fd"></a>

## Relations in Functional Code

Relational goals appear naturally within functional code via `solve`:

```prologos
;; Functional function that uses a relation internally
spec find-path : Graph Node Node -> [List Node]?
defn find-path [graph start end]
  match (solve [path-in graph start end ?p])
    | [some bindings] -> [just [map-get bindings :p]]
    | none            -> nothing
```


<a id="org295657c"></a>

## Functions in Relational Code

Functional expressions can appear in relational goals via `is`:

```prologos
;; Relational rule that calls functional code
defr factorial [?n ?result]
  &> (= ?n 0) (= ?result 1)
  &> (> ?n 0)
     (is ?n1 [sub ?n 1])
     (factorial ?n1 ?partial)
     (is ?result [mul ?n ?partial])
```

The `is` keyword evaluates a functional expression and binds the result to a logic variable. This is the standard Prolog/Mercury approach, but in Prologos, the functional expression is a full Prologos expression (type-checked, trait-resolved, etc.).


<a id="org5296c9e"></a>

# Design Principles Summary

1.  **Delimiter-based paradigm distinction**: `[...]` functional, `(...)` relational
2.  **Dual keywords**: `defn~/~fn` for functions, `defr~/~rel` for relations
3.  **First-class anonymous relations**: `rel` is the relational lambda
4.  **`&>` clause syntax**: Visually distinct disjunction within relations
5.  **Mode prefixes**: `?` (free), `-` (in), `+` (out) &#x2014; optional, Mercury-inspired
6.  **Tabling by default**: Correctness over performance as the default
7.  **`solve` bridge**: Returns `Seq Map` for functional consumption
8.  **`solve-with` configuration**: Solver as parameterizable metadata entity
9.  **Provenance tracking**: Built on ATMS support sets, first-class data
10. **Network mobility**: Propagator networks as first-class, transferable values
11. **Bidirectional embedding**: Functions in relations via `is`, relations in functions via `solve`


<a id="org890eb39"></a>

# What This Document Does NOT Cover

-   Implementation details of the propagator network (see logic engine design doc)
-   Concrete AST node definitions (deferred to implementation phase)
-   Grammar EBNF additions (deferred to Phase 5 of logic engine)
-   Error message design for relational type errors
-   Interaction between logic variables and QTT multiplicities (research question)
