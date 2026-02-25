# Phase 4: UnionFind — Persistent Disjoint Sets

**Date**: 2026-02-25
**Status**: COMPLETE
**Design Reference**: `docs/tracking/2026-02-24_LOGIC_ENGINE_DESIGN.org` §4

## Summary

Implements a persistent union-find data structure (Conchon & Filliâtre 2007) as a first-class Prologos type, following the same pattern established by Phase 3 (PropNetwork). This is the core data structure for unification in the logic engine — persistent UF supports efficient backtracking for search, unlike the current mutable metavar store.

## Design Decisions

- **IDs are `Nat`** — no separate `UfId` type constructor. Simpler than PropNetwork's `CellId`/`PropId` approach.
- **`uf-union` has 3 fields** at AST level (no merge-fn). Default: keep higher-rank root's value. Logic engine calls Racket API directly with custom merge when needed.
- **`uf-value` returns `expr-hole`** — type-unsafe by design (heterogeneous values). Same pattern as `net-cell-read`.
- **`uf-find` returns `[Nat * UnionFind]`** — path splitting modifies the store, so Sigma pair returns both root-id and updated store.
- **Path splitting** (not path compression) preserves persistence. O(log n) amortized find.
- **Backed by `hasheq`** — persistent hash map with structural sharing.

## AST Nodes (7)

| Node | Fields | Type |
|------|--------|------|
| `expr-uf-type` | — | `Type 0` |
| `expr-uf-store` | `store-value` | Runtime wrapper |
| `expr-uf-empty` | — | `UnionFind` |
| `expr-uf-make-set` | `store id val` | `UnionFind → Nat → A → UnionFind` |
| `expr-uf-find` | `store id` | `UnionFind → Nat → [Nat * UnionFind]` |
| `expr-uf-union` | `store id1 id2` | `UnionFind → Nat → Nat → UnionFind` |
| `expr-uf-value` | `store id` | `UnionFind → Nat → _` (type-unsafe) |

## Sub-phases

### 4a: Racket Module — COMPLETE
- `union-find.rkt`: ~150 lines, persistent union-find with path splitting + rank-based union
- 19 unit tests covering construction, find, union, value, persistence, same-set?, path splitting, chains, performance (100 elements)

### 4b: AST + Mechanical Traversals — COMPLETE
- 7 struct definitions in `syntax.rkt` + provide + is-value?
- Threaded through 6 mechanical files: substitution, zonk, pretty-print, unify, trait-resolution

### 4c: Type Rules + QTT — COMPLETE
- `typing-core.rkt`: infer + check + infer-level for all 7 nodes
- `qtt.rkt`: inferQ + checkQ clauses
- 23 type-level tests (formation, inference, errors, QTT, substitution, pretty-print)

### 4d: Reduction Rules — COMPLETE
- `reduction.rkt`: `racket-nat->expr` helper, whnf iota rules for all operations, nf clauses
- 6 eval tests (uf-empty, make-set, find, value, union, persistence)

### 4e: Surface Syntax + Integration — COMPLETE
- `surface-syntax.rkt`: 6 surf-* structs
- `parser.rkt`: keywords + case clauses
- `elaborator.rkt`: surf-* → expr-* match clauses
- 9 integration tests (type-check, eval, find, value, union, persistence, chain)

## Files Changed

| File | Action | Lines |
|------|--------|-------|
| `union-find.rkt` | NEW | ~150 |
| `syntax.rkt` | MODIFY | +23 |
| `substitution.rkt` | MODIFY | +22 |
| `zonk.rkt` | MODIFY | +33 |
| `pretty-print.rkt` | MODIFY | +25 |
| `unify.rkt` | MODIFY | +1 |
| `trait-resolution.rkt` | MODIFY | +1 |
| `typing-core.rkt` | MODIFY | +47 |
| `qtt.rkt` | MODIFY | +51 |
| `reduction.rkt` | MODIFY | +97 |
| `surface-syntax.rkt` | MODIFY | +12 |
| `parser.rkt` | MODIFY | +48 |
| `elaborator.rkt` | MODIFY | +37 |
| `dep-graph.rkt` | MODIFY | +9 |
| `grammar.ebnf` | MODIFY | +27 |
| `grammar.org` | MODIFY | +4 |
| `test-union-find.rkt` | NEW | ~270 |
| `test-union-find-types.rkt` | NEW | ~214 |
| `test-union-find-integration.rkt` | NEW | ~126 |

## Test Results

- **57 new tests**: 19 unit + 29 type-level + 9 integration
- **Full suite**: 3872 tests, 176 files, all pass
- **No whale files**: max 15.9s (well under 30s threshold)

## Lessons Learned

- `uf-value` is type-unsafe (returns `expr-hole` / `_`) — integration tests must use `check-not-false (member "true : _" result)` not `"true : Bool"`
- Sexp mode uses `first`/`second` keywords, not `fst`/`snd`
- `nat-eq?` requires prelude — integration tests needing it must use `(ns test)` wrapper
- `check-true` with `member` fails because `member` returns list tail (truthy but not `#t`) — use `check-not-false`
- Stale compiled files after surface-syntax changes cause linklet instantiation errors — `raco make driver.rkt` fixes
