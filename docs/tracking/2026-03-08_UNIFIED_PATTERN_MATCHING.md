# Unified Pattern Matching

**Date**: 2026-03-08
**Status**: COMPLETE

## Summary

Unified the two separate pattern matching systems in Prologos so that `match` arms support the same rich patterns as `defn` pattern clauses. Added `defn f [params] | arms` syntax for Haskell-style pattern definitions with named params declaring arity.

## Components

### Component 1: Rich Patterns in `match` Arms
Previously, `parse-reduce-arm` used flat extraction: `| suc zero -> body` treated `zero` as a variable binding. Now `parse-single-pattern` + `normalize-pattern` + `compile-match-tree` handles all match arm patterns.

**New capabilities in match**:
- Nested constructor patterns: `| suc zero -> ...` (zero recognized as ctor)
- Deeply nested: `| suc [suc k] -> k`
- Numeric literals: `| 0N -> ... | 1N -> ...`
- Head-tail: `| [x | rest] -> x`
- Wildcards: `| _ -> default`
- Option/Bool ctors: `| some v -> v | none -> default`

### Component 2: `defn f [params] | arms` Syntax
Named params declare arity; each arm provides bare positional patterns.

```prologos
defn pred [n]
  | suc zero    -> zero
  | suc [suc k] -> suc k
  | zero        -> zero

defn add [m n]
  | zero n      -> n
  | [suc m'] n' -> suc [add m' n']
```

Supports typed params and return types:
```prologos
defn safe-head [xs : List Nat] : Option Nat
  | [x | rest] -> some x
  | nil        -> none
```

## Architecture

New surface AST node `surf-match-patterns` (with `match-pattern-arm`). Parser produces it; `expand-expression` in macros.rkt compiles it via `compile-match-expression` which calls existing `compile-match-tree`. Downstream (elaborator, typing, reduction) sees only `surf-reduce`.

**Pipeline**: reader -> preparse -> parser (`surf-match-patterns`) -> macros (`compile-match-expression` -> `compile-match-tree` -> `surf-reduce`) -> elaborator -> typing -> reduction

## Files Modified

| File | Changes |
|------|---------|
| `surface-syntax.rkt` | Added `match-pattern-arm`, `surf-match-patterns` structs |
| `parser.rkt` | Replaced `parse-reduce-arm` pipeline with `parse-match-pattern-arm`; added `parse-defn-params-and-patterns`; added `$nat-literal` handling in `parse-single-pattern`; handle typed params+ret-type in detection |
| `macros.rkt` | Added `surf-match-patterns` clause in `expand-expression`; added `compile-match-expression`; updated `defn-has-any-pattern-clauses?` |
| `tests/test-unified-match-01.rkt` | NEW: 15 tests (sexp + WS) for rich match patterns |
| `tests/test-pattern-defn-01.rkt` | Extended: 6 new tests for params+arms syntax |
| `tools/dep-graph.rkt` | Added new test entry |
| `docs/spec/grammar.ebnf` | Updated match pattern + defn params grammar |
| `docs/spec/grammar.org` | Updated match + defn sections |

## Key Functions Reused (unchanged)

| Function | Location | Purpose |
|----------|----------|---------|
| `parse-single-pattern` | parser.rkt | Recursive pattern parsing |
| `normalize-pattern` | macros.rkt | Ctor disambiguation + normalization |
| `compile-match-tree` | macros.rkt | Decision-tree compilation |
| `make-let-binding` | macros.rkt | Let-binding wrapper |
| `compile-pattern-group` | macros.rkt | Defn pattern clause compilation |

## Commits

- `99f97ef` — Unify pattern matching: rich patterns in match arms + defn params|arms
- `5b59169` — Add test-unified-match-01.rkt + fix $nat-literal in pattern parsing
- `983a7a5` — Add params+arms tests + handle typed params in defn detection
- `1ad02e8` — Add test-unified-match-01.rkt to dep-graph
- `88eed86` — Update grammar docs + create tracking doc
- `c88811b` — Add unified-matching.prologos demo file

## Known Issues Uncovered

1. **`:=` body parsing** (DEFERRED): `def x := cons 1N [cons 2N nil]` fails — `expand-def-assign` expects single form after `:=` but WS reader produces multiple inline elements. Fix: wrap as implicit application.
2. **Multi-bracket defn** (DEFERRED): `defn f [a] [b] body` doesn't work (pre-existing). Standard is uncurried `defn f [a b] body`.
3. **NOT a bug**: Polymorphic nullary ctors (`none`, `nil`) at call sites — actually works via auto-apply + unification.

## Bugs Fixed During Implementation

1. **$nat-literal sentinel**: WS reader produces `($nat-literal 0)` for `0N` — `parse-single-pattern` needed a case for this, with proper syntax unwrapping of the car.
2. **Typed params detection**: `parse-defn-multi` needed to skip return type tokens (`: RetType`) between param bracket and `$pipe` arms.
3. **Typed param arity**: Extract arity by counting param names (before `:` separators), not total bracket elements.
4. **Spec injection gatekeeper**: `defn-has-any-pattern-clauses?` updated to recognize params+patterns form.
