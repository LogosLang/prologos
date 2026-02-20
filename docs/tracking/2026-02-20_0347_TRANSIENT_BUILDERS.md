# Phase 2d: Mutable Transient Builders

**Date**: 2026-02-20
**Status**: COMPLETE
**Roadmap**: Core Data Structures Phase 2d
**Dependencies**: Phase 1a (PVec/RRB), Phase 1b (Map/CHAMP), Phase 2a (Set)

## Problem

Building persistent collections element-by-element is O(n log n). Each `pvec-push` / `map-assoc` / `set-insert` performs copy-on-write: `vector-copy` at each node along the path. For batch construction of large collections (10k+ elements), this is a performance bottleneck.

## Solution: Transient Builders

Clojure-style transient pattern: create a mutable "transient" version of a persistent collection, perform O(1) amortized mutations, then "freeze" (persist) back to an immutable persistent collection. Total cost: O(n) for n operations.

## Design Decisions

### Approach B: Thin AST Bridge
- Racket-layer transient implementations in `rrb.rkt` and `champ.rkt`
- 18 new AST nodes exposed to Prologos type system
- Generic `transient`/`persist!` keywords dispatch on collection type
- QTT: `zero-usage` initially (linear enforcement deferred)

### Why not Approach A (Full Pipeline)?
Same result, just larger scope. Approach B *is* the pipeline approach, scoped to essential operations.

### Why not Approach C (Racket-only batch)?
Only helps `from-list`/`from-seq`. Doesn't enable incremental transient building from Prologos user code.

### RRB Transient Strategy: Flat Mutable Buffer
Simple amortized-doubling array rather than Clojure-style owner-id trie sharing. The RRB tree's tail-buffer optimization already makes persistent push amortized O(1), but constant factors are still high due to struct allocation. A flat mutable vector gives true O(1) worst-case push.

### CHAMP Transient Strategy: Mutable Hash Table
Uses Racket's `make-hash` as the transient buffer rather than implementing the full Clojure owner-id CHAMP mutation. O(1) amortized insert/delete, O(n) freeze (rebuild CHAMP from hash entries). Simpler, correct, and still achieves O(n) total for batch construction. The owner-id optimization can be added later if benchmarks show freeze cost is a bottleneck.

## New Types

| Type | Persistent Counterpart | Description |
|------|----------------------|-------------|
| `TVec A` | `PVec A` | Transient persistent vector |
| `TMap K V` | `Map K V` | Transient persistent hash map |
| `TSet A` | `Set A` | Transient persistent hash set |

## New Operations

| Operation | Type Signature | Description |
|-----------|---------------|-------------|
| `transient` | `PVec A -> TVec A` (generic) | Create transient from persistent |
| `persist!` | `TVec A -> PVec A` (generic) | Freeze transient to persistent |
| `tvec-push!` | `TVec A -> A -> TVec A` | Append element |
| `tvec-update!` | `TVec A -> Nat -> A -> TVec A` | Update at index |
| `tmap-assoc!` | `TMap K V -> K -> V -> TMap K V` | Insert/update key-value |
| `tmap-dissoc!` | `TMap K V -> K -> TMap K V` | Remove key |
| `tset-insert!` | `TSet A -> A -> TSet A` | Insert element |
| `tset-delete!` | `TSet A -> A -> TSet A` | Remove element |

## Convenience Macro

```prologos
with-transient @[]
  fn [t]
    let t = [tvec-push! t 1N]
    let t = [tvec-push! t 2N]
    t
;; => @[1N 2N]
```

Desugars to: `(persist! ((fn [t] ...) (transient coll)))`

## QTT Safety Note

Transient handles should be used linearly (used exactly once, then frozen). Currently enforced by convention, not the type system. Future work: enforce with m1 (linear) multiplicity on transient type params. The existing QTT infrastructure supports m0/m1/mw multiplicities — adding linear enforcement for TVec/TMap/TSet is orthogonal.

## Files Modified/Created

| Action | File | Purpose |
|--------|------|---------|
| MODIFY | `rrb.rkt` | trrb struct, rrb-transient, trrb-push!, trrb-freeze |
| MODIFY | `champ.rkt` | tchamp-root struct, champ-transient, tchamp-insert!, tchamp-freeze |
| MODIFY | `syntax.rkt` | 18 new AST node definitions |
| MODIFY | `substitution.rkt` | shift/subst for 18 nodes |
| MODIFY | `zonk.rkt` | zonk/zonk-at-depth/default-metas for 18 nodes |
| MODIFY | `typing-core.rkt` | infer/check rules |
| MODIFY | `qtt.rkt` | inferQ/checkQ rules |
| MODIFY | `reduction.rkt` | iota rules + stuck-term fallbacks |
| MODIFY | `unify.rkt` | impl-key strings |
| MODIFY | `pretty-print.rkt` | pp-expr + uses-bvar0? |
| MODIFY | `surface-syntax.rkt` | 8 new surface structs |
| MODIFY | `parser.rkt` | New keywords |
| MODIFY | `elaborator.rkt` | Surface -> core elaboration |
| MODIFY | `macros.rkt` | with-transient preparse macro |
| CREATE | `tests/test-transient.rkt` | ~40 tests |
| MODIFY | `tools/dep-graph.rkt` | Test dependencies |

## Sub-phase Progress

- [x] 2d-a: Racket-layer transients (rrb.rkt + champ.rkt)
- [x] 2d-b: AST nodes + pipeline wiring (20 nodes across 10 files)
- [x] 2d-c: Surface syntax + parser + elaborator
- [x] 2d-d: with-transient macro
- [x] 2d-e: Tests (38 tests, all pass)

## Implementation Notes

### Generic Dispatch
`transient` and `persist!` are generic keywords that dispatch on the collection type.
Since the elaborator cannot access the type checker (circular dependency), we added
two lightweight generic AST nodes (`expr-transient`, `expr-persist`) that the type
checker and reducer resolve into collection-specific nodes at type-check/reduction time.

### Actual Node Count: 20 (not 18)
Added 2 extra generic nodes (`expr-transient`, `expr-persist`) beyond the 18 planned,
for a total of 20 new AST nodes. These enable the `transient`/`persist!` keywords to
work generically across PVec, Map, and Set.

### Test Results
- 92 test files, 2786 tests (38 new), all pass
- Full suite: 307.9s wall time (10 jobs)
- New test file: well under 30s (not a whale)
