# Phase 6: SLG-Style Tabling — Memoization

**Date**: 2026-02-25
**Status**: COMPLETE

## Overview

Persistent table store for tabled predicates, following SLG resolution. Tables are indices into PropNetwork cells — the actual answer data lives in cells with list-based set-merge. The table-store maps predicate names to table-entries, each pointing to a cell-id in the wrapped PropNetwork. Fixed-point detection via `run-to-quiescence`.

## Design Decisions

- **Table-store wraps a PropNetwork** — same pattern as ATMS wrapping a PropNetwork
- **Backed by `hasheq`** — consistent with Phases 4-5
- **List-based answer sets** — `remove-duplicates` + `append` for set-merge; `racket/set` NOT used
- **Answer modes: `all` and `first`** — `all` uses list-based set-union; `first` freezes after one answer
- **Lattice answer mode deferred** — requires bridging Prologos merge function to Racket
- **Name-based API** — operations use keyword symbols to identify tables; cell-ids are internal
- **`table-answers` returns `expr-hole`** — type-unsafe, consistent with `atms-read` and `net-cell-read`
- **No `:tabled`/`:answer-mode` spec metadata** — belongs to Phase 7 surface syntax (`defr`)
- **No parameterized type** — simplified to `TableStore : Type 0`
- **`merge-fn-for-mode` accepts both `'all` and `':all`** — handles keyword extraction from AST

## Files Modified/Created

| File | Action | ~Lines |
|------|--------|--------|
| `racket/prologos/tabling.rkt` | NEW | ~170 |
| `racket/prologos/syntax.rkt` | MODIFY | +20 |
| `racket/prologos/substitution.rkt` | MODIFY | +22 |
| `racket/prologos/zonk.rkt` | MODIFY | +33 |
| `racket/prologos/pretty-print.rkt` | MODIFY | +25 |
| `racket/prologos/unify.rkt` | MODIFY | +1 |
| `racket/prologos/trait-resolution.rkt` | MODIFY | +1 |
| `racket/prologos/typing-core.rkt` | MODIFY | +55 |
| `racket/prologos/qtt.rkt` | MODIFY | +75 |
| `racket/prologos/reduction.rkt` | MODIFY | +110 |
| `racket/prologos/surface-syntax.rkt` | MODIFY | +15 |
| `racket/prologos/parser.rkt` | MODIFY | +70 |
| `racket/prologos/elaborator.rkt` | MODIFY | +50 |
| `racket/prologos/tools/dep-graph.rkt` | MODIFY | +6 |
| `tests/test-tabling.rkt` | NEW | ~185 |
| `tests/test-tabling-types.rkt` | NEW | ~295 |
| `tests/test-tabling-integration.rkt` | NEW | ~95 |
| `docs/spec/grammar.ebnf` | MODIFY | +14 |
| `docs/spec/grammar.org` | MODIFY | +1 |
| `docs/tracking/DEFERRED.md` | MODIFY | +5 |

## AST Nodes (10)

| Node | Fields | Type Signature |
|------|--------|----------------|
| `expr-table-store-type` | -- | `TableStore : Type 0` |
| `expr-table-store-val` | `store-value` | Runtime wrapper (Racket `table-store`) |
| `expr-table-new` | `network` | `PropNetwork -> TableStore` |
| `expr-table-register` | `store name mode` | `TableStore -> Keyword -> Keyword -> [TableStore * CellId]` |
| `expr-table-add` | `store name answer` | `TableStore -> Keyword -> A -> TableStore` |
| `expr-table-answers` | `store name` | `TableStore -> Keyword -> List _` (type-unsafe) |
| `expr-table-freeze` | `store name` | `TableStore -> Keyword -> TableStore` |
| `expr-table-complete` | `store name` | `TableStore -> Keyword -> Bool` |
| `expr-table-run` | `store` | `TableStore -> TableStore` |
| `expr-table-lookup` | `store name answer` | `TableStore -> Keyword -> A -> Bool` |

## Test Summary

- **test-tabling.rkt**: 20 unit tests (Racket-level table-store operations)
- **test-tabling-types.rkt**: 31 tests (type formation, inference, QTT, substitution, pretty-print, reduction/eval)
- **test-tabling-integration.rkt**: 12 tests (surface syntax through full pipeline)
- **Total**: 63 new tests

## Full Suite

- 4009 tests across 182 files, all pass
- No whale files (max 20.0s)
