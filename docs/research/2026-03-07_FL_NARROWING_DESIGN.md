- [Abstract](#org7ea070e)
- [1. Motivation: The defn/defr Divide](#org0869041)
  - [1.1 The Current State](#org1c0fad5)
  - [1.2 The Vision](#org81d200b)

Implementation Design Document


<a id="org7ea070e"></a>

# Abstract

This document is a Phase 0 (Research) and Phase 1 (Implementation Design) artifact for bringing functional-logic (FL) narrowing into Prologos as a core language feature. The goal: every `defn` function should be automatically usable as a relation&#x2014;queryable with unbound variables&#x2014; without the programmer writing a separate `defr` definition.

This is achieved through *narrowing*: the combination of unification and term rewriting, guided by *definitional trees* extracted from function definitions and driven by *needed demand analysis*.

The document covers:

1.  The formal foundations of narrowing and definitional trees
2.  Surface syntax: `=` as unification and implicit narrowing via `?` variables
3.  How definitional trees map to Prologos's existing `defn` infrastructure
4.  Constraints derived from types, specs, traits, and properties&#x2014;not a separate constraint language
5.  A concrete design for the narrowing propagator
6.  Resolved design decisions (including linearity, termination, infinite constructors)
7.  A phased implementation roadmap (Phases 1&#x2013;3)

**Implementation tracking**: See companion document `docs/tracking/2026-03-07_NARROWING_ABSTRACT_INTERPRETATION_DESIGN.org`.


<a id="org0869041"></a>

# 1. Motivation: The defn/defr Divide


<a id="org1c0fad5"></a>

## 1.1 The Current State

Prologos currently maintains two separate worlds:

-   **`defn`** (functions): Define computations by pattern matching and reduction. Given ground inputs, produce ground outputs. Evaluated by the reducer (`reduction.rkt`).

-   **`defr`** (relations): Define logical relationships with multiple clauses. Given goals with potentially unbound variables, search for all satisfying substitutions. Evaluated by the solver (`relations.rkt`, `solver.rkt`).

These share syntax (both use pattern matching, both support multiple clauses) but have completely separate evaluation mechanisms. A function `add` defined with `defn` cannot be used in a relational query. If you want to query "which pairs X, Y satisfy `add X Y = 5`?", you must write a separate `defr` definition that mirrors the function's logic.


<a id="org81d200b"></a>

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
