# Prologos Prelude System

**Date**: 2026-02-20
**Status**: COMPLETE

## Summary

Implemented a Haskell/Clojure-style prelude so that `ns foo` auto-imports all essential types, functions, traits, and instances without explicit `require` statements. Modeled after Haskell Prelude, Clojure core, Lean 4 Init, and Idris Prelude.

## Architecture

**Approach**: Racket-side prelude requires list in `namespace.rkt` (NOT a `.prologos` re-export module). The module system's `:refer-all` re-export path has an FQN mismatch problem, so the prelude is defined as a Racket-side list of require specs that get emitted directly into the user's namespace context.

## Prelude Contents (4 Tiers)

### Tier 0: Foundation
- `prologos.core` — id, const, compose, apply, flip, on, when, unless, pipe2, pipe3, twice
- `prologos.data.nat` — add, mult, double, pred, zero?, sub, pow, le?, lt?, gt?, ge?, nat-eq?, min, max, bool-to-nat, clamp
- `prologos.data.bool` — not, and, or, xor, bool-eq, implies, nand, nor
- `prologos.data.pair` — swap, map-fst, map-snd, bimap, dup, uncurry
- `prologos.data.ordering` — Ordering, lt-ord, eq-ord, gt-ord
- `prologos.data.eq` — sym, cong, trans

### Tier 1: Containers
- `prologos.data.option` (as `opt`) — Option, none, some, some?, none?, flatten (+ qualified: opt::unwrap-or, opt::map, etc.)
- `prologos.data.result` (as `result`) — Result, ok, err, ok?, err? (+ qualified: result::map, result::and-then, etc.)
- `prologos.data.list` — List, nil, cons, foldr, reduce, length, map, filter, append, head, tail, singleton, reverse, sum, product, any?, all?, find, nth, last, replicate, range, concat, concat-map, take, drop, split-at, take-while, drop-while, partition, zip-with, zip, unzip, intersperse, sort, elem, dedup, count, scanl, iterate-n, intercalate, sort-on, reduce1, foldr1, init, span, break, prefix-of?, suffix-of?, delete, find-index

### Tier 2: Core Traits
- Eq, eq-neq, nat-eq, Ord, nat-ord, ord-lt/le/gt/ge/eq/min/max
- Add, Sub, Mul, Neg, Abs, FromInt, Num, Fractional

### Tier 3: Instance Registration (side-effect only)
- eq-instances, eq-numeric-instances, ord-instances, ord-numeric-instances
- add-instances, sub-instances, mul-instances, neg-instances, abs-instances

## Name Conflict Resolution

| Name | Modules | Resolution |
|------|---------|------------|
| map | list, option, result | List wins; use opt::map, result::map |
| filter | list, option | List wins |
| unwrap-or | option, result | Via opt::unwrap-or, result::unwrap-or |
| or-else | option, result | Via opt::or-else, result::or-else |

## Key Features

- **`:no-prelude` opt-out**: `ns foo :no-prelude` loads only `prologos.core`
- **Circularity guard**: `prologos.data.*` and `prologos.core.*` modules skip the prelude (get only `prologos.core`)
- **Own-definition shadowing**: User's `def map` in `ns foo` creates `foo::map` which takes priority over the prelude's `prologos.data.list::map`
- **Qualified aliases**: `opt::unwrap-or`, `result::and-then` etc. for disambiguating

## Performance

| Metric | Value |
|--------|-------|
| Test files | 91 |
| Total tests | 2748 |
| Wall time (10 jobs) | ~283s |
| New test file time | ~72s (loads all prelude modules) |

## Files Modified/Created

| Action | File | Purpose |
|--------|------|---------|
| MODIFY | `namespace.rkt` | Add `prelude-requires`, `prelude-dependency?`, update `process-ns-declaration` |
| MODIFY | `elaborator.rkt` | Add own-namespace priority check in `elaborate-var` |
| MODIFY | `tests/test-trait-resolution.rkt` | Add `:no-prelude` to tests that need missing Eq instance |
| MODIFY | `tools/dep-graph.rkt` | Add test-prelude-system.rkt entries |
| CREATE | `tests/test-prelude-system.rkt` | 31 tests for prelude system |
| CREATE | `docs/tracking/2026-02-20_0227_PRELUDE_SYSTEM.md` | This tracking doc |

## What's NOT in the Prelude

Too specialized for automatic inclusion:
- Either, LSeq, LSeq-Ops, Transducers, Set, Datum
- Div, FromRat, From, TryFrom, Hashable traits
- Functor, Foldable, Seq, Buildable, Indexed, Keyed, Setlike traits
- Collection-Ops
