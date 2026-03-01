# Clause-Style Constraint Matching — Design Document

## Overview

A proposed extension to the trait resolver that enables **prioritized dispatch
over disjoint trait constraints** using clause-style pattern matching — the same
`|` syntax already used for multi-clause `defn` and `match`.

This is the mechanism for **Layer 2: Trait-Level Specialization** in the
collection generics redesign, but it's a general language feature applicable
wherever "try this constraint first, fall back to that" is needed.

## Motivation

Generic collection operations want to dispatch differently based on which traits
a type implements:

- If `Mappable C` is available → use the native `map-native` (e.g., `pvec-map`)
- Otherwise, if `Reducible C` + `Buildable C` → use fold+build generic path

This is **not** union types (value-level), **not** bundles (conjunction of constraints),
and **not** trait aliasing. It's pattern matching at the constraint level.

## Design: Clause-Style spec/defn

```prologos
spec map {A B} {C}
  | (Mappable C) -> (A -> B) -> C A -> C B
  | (Reducible C) -> (Buildable C) -> (A -> B) -> C A -> C B

defn map
  | [$mappable f xs] [map-native $mappable f xs]
  | [$red $build f xs] [reduce $red [fn [acc x] [conj acc [f x]]] [empty-coll $build] xs]
```

### Semantics

1. The trait resolver tries clauses **top-to-bottom**
2. For each clause, attempt to resolve all trait constraints
3. First clause whose constraints are **fully satisfiable** wins
4. If no clause matches, report error with all attempted alternatives

This is Prolog-style clause ordering applied to constraint resolution.

### Why This Shape

Three alternatives were considered:

| Approach | How It Works | Pros | Cons |
|---|---|---|---|
| **Default methods** (Haskell/Rust) | Trait provides default body using supertraits | Clean, well-understood | Requires supertrait infrastructure; all-or-nothing |
| **Instance priority** (Scala 3) | Instances have explicit priority numbers | Explicit control | Essentially overlapping instances with numbers |
| **Clause-style matching** | Function declares alternative constraint signatures | Reuses existing `\|` syntax; logic-programming-native; user-extensible | Requires fallible trait resolution |

Clause-style matching is most aligned with Prologos's identity as a
functional-logic language. The `|` clause syntax is already familiar to users
from `defn` and `match`. The resolver's try/fail behavior mirrors Prolog's
backtracking on clause alternatives.

## Implementation Requirements

### Core Change: Fallible Trait Resolution

Currently: unsatisfiable trait constraint → hard error.
Required: unsatisfiable trait constraint → **backtrackable failure** (within a
clause-level try block).

This means the trait resolver needs a `try-resolve-constraints` variant that
returns `#f` (or an empty result) instead of signaling an error. The
`save-meta-state`/`restore-meta-state!` infrastructure for speculative
type-checking (already used for Church fold attempts and union types) provides
the foundation.

### Parser/Elaborator Changes

- `spec` with `|` clauses: parse as list of `(constraints, type-signature)` pairs
- `defn` with `|` clauses already works — just need to associate each clause
  with its constraint set
- Elaborator: iterate clauses, attempt constraint resolution for each,
  select first success

### Trait Resolver Changes

- `resolve-trait-constraints!` needs a non-fatal mode
- Meta-state save/restore around each attempt (speculative resolution)
- On success: commit meta-state and proceed with winning clause
- On failure: restore meta-state and try next clause

## Dependencies

- **Not blocked by Layer 1**: fold+build generic ops use a single constraint
  set (Reducible + Buildable) and don't need clause matching
- **Blocked on**: Nothing fundamental. The speculative type-checking infrastructure
  (`save-meta-state`/`restore-meta-state!`) already exists. The main work is
  parser support for multi-clause specs with different constraints per clause,
  and wiring the fallible resolution into the elaborator.

## Scope of Applicability

Beyond collections, clause-style constraint matching enables:

- **Numeric operations**: Prefer `Fractional` if available, fall back to `Num`
- **Serialization**: Use `ToJSON` if available, fall back to `Show`
- **Comparison**: Prefer `Ord` for sorting, fall back to `Eq` for dedup-only
- **User-defined dispatch**: Any user function can have alternative constraint clauses

## Status

| Item | Status |
|---|---|
| Design discussion | Complete (2026-02-28) |
| Syntax proposal | Drafted (above) |
| Implementation | Not started |
| Layer 1 dependency | None (Layer 1 proceeds independently) |

## Related

- `docs/tracking/standups/2026-02-28_dailies.md` — design discussion notes
- `docs/tracking/DEFERRED.md` — Collections — Ergonomics section
- Layer 1 tracking: TBD (implementation plan pending)
