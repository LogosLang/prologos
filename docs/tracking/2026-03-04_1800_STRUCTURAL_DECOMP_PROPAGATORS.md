# Phase 4c: Structural Decomposition Propagators

**Created**: 2026-03-04
**Status**: COMPLETE
**Depends on**: P-Unify Phases 1a-4b (commits `b34e716`-`f944d2c`)
**Commits**: `8624a33` (4c-a), `3094aa1` (4c-b), `2785e09` (4c-c)

## Motivation

The propagator network is currently a flat constraint graph: cells connected by
bidirectional unify propagators. `type-lattice-merge`/`try-unify-pure` do structural
decomposition inline during merge, but results stay in the cell value -- they don't
create sub-constraints in the network. Individual metas embedded within compound types
are NOT solved through propagation; only the imperative `unify` path solves them.

### What This Unlocks

**Transitive structural resolution**: When cell A holds `Pi(Nat, ?M)` and cell B holds
`Pi(?N, Bool)`, the network decomposes into domain and codomain sub-cells, directly
solving `?N=Nat` and `?M=Bool` through propagation. Three-way chains (A-B-C) where
domain info enters at A and codomain info enters at C both resolve at B, purely through
the network -- no imperative retry needed.

### Formal Foundation

Radul/Sussman constructor/accessor pattern: compound partial information decomposes
into sub-cells. `merge(Pi(A1,B1), Pi(A2,B2)) = Pi(merge(A1,A2), merge(B1,B2))`.
Sub-cells persist within a computation branch (monotone). CHAMP snapshot rollback
discards speculative sub-cells automatically.

## Architecture

Two CHAMP-backed registries on `prop-network` prevent duplicate work:
1. `cell-decomps`: `cell-id -> (cons constructor-tag (listof cell-id))` -- per-cell sub-cells
2. `pair-decomps`: `(cons cell-id cell-id) -> #t` -- per-pair dedup

Decomposition is lazy: happens inside the unify propagator's fire function when both
cells have concrete values with the same head constructor.

Information flow: downward (decompose -> sub-cells), lateral (sub-cell <-> sub-cell unify
propagators), upward (reconstructor propagators rebuild compound -> write to parent).

### Sub-Cell Identification

- **Bare meta**: Reuse the meta's existing propagator cell (key mechanism!)
- **Ground**: Fresh cell initialized to ground value
- **Compound with metas**: Fresh cell initialized as-is; further decomposition recursive

## Sub-Phases

### 4c-a: Infrastructure (commit `8624a33`)
- [x] Add `cell-decomps` + `pair-decomps` CHAMP fields to `prop-network`
- [x] Registry helper functions in `propagator.rkt`
- [x] `current-structural-meta-lookup` parameter in `elaborator-network.rkt`
- [x] Install callback from `driver.rkt`
- [x] Unit tests for registry operations

### 4c-b: Core Structural Decomposition (Pi + app) (commit `3094aa1`)
- [x] `make-structural-unify-propagator` (replaces `make-unify-propagator`)
- [x] `maybe-decompose`, `get-or-create-sub-cells`, `identify-sub-cell`
- [x] `decompose-pi` + `make-pi-reconstructor`
- [x] `decompose-app` + `make-app-reconstructor`
- [x] Update `elab-add-unify-constraint` fast path (check `has-unsolved-meta?`)
- [x] Update `elab-add-unify-constraint` slow path (use structural propagator)
- [x] 24 tests in `test-structural-decomp.rkt`

### 4c-c: Extended Constructors (commit `2785e09`)
- [x] Sigma, Eq, Vec decomposers + reconstructors
- [x] Generic `decompose-1` + `make-1-reconstructor` for 1-component types (PVec, Set, suc)
- [x] Map, pair, lam decomposers + reconstructors
- [x] Fix pre-existing bug: `try-unify-pure` lam case missing mult argument
- [x] 19 new tests (9 tag tests + 10 decomposition tests)

### 4c-d: Full Validation + PIR Update
- [x] Full test suite pass: 5277 tests, 259 files, all pass
- [x] Benchmark within 15% of baseline (142.6s total, no regressions)
- [x] Update tracking document

## Key Files

| File | Changes |
|------|---------|
| `racket/prologos/propagator.rkt` | `prop-network` +2 fields, +6 helpers |
| `racket/prologos/elaborator-network.rkt` | ~350 lines: structural propagator, 11 decomposers, 8 reconstructors |
| `racket/prologos/type-lattice.rkt` | Fix lam arity bug in `try-unify-pure` |
| `racket/prologos/driver.rkt` | Install meta-lookup callback |
| `tests/test-structural-decomp.rkt` | 43 tests |

## Supported Constructors

| Constructor | Sub-cells | Pattern |
|-------------|-----------|---------|
| Pi(mult, dom, cod) | 2 (dom, cod) | Dedicated decomposer; mult via imperative path |
| app(func, arg) | 2 (func, arg) | Dedicated decomposer |
| Sigma(fst, snd) | 2 (fst, snd) | Dedicated decomposer |
| Eq(type, lhs, rhs) | 3 (type, lhs, rhs) | Dedicated decomposer |
| Vec(elem, len) | 2 (elem, len) | Dedicated decomposer |
| Map(k, v) | 2 (k, v) | Dedicated decomposer |
| pair(fst, snd) | 2 (fst, snd) | Dedicated decomposer |
| lam(mult, type, body) | 2 (type, body) | Dedicated decomposer; mult via imperative path |
| PVec(elem) | 1 (elem) | Generic `decompose-1` |
| Set(elem) | 1 (elem) | Generic `decompose-1` |
| suc(pred) | 1 (pred) | Generic `decompose-1` |

## Benchmark Results

```
Last run (3094aa1, 2026-03-04):
  Total: 142.6s (259 files, 5277 tests, 10 jobs, all pass)
  No regressions vs baseline (8624a33): +-5% noise on individual files
```

## Lessons Learned

1. **`current-lattice-meta-solution-fn` is essential for structural decomposition tests**.
   Without it, `has-unsolved-meta?` returns `#f` for all expressions, causing the fast path
   in `elab-add-unify-constraint` to fire for ALL non-bot/non-top values (even those with
   metas), bypassing structural decomposition entirely. Tests must set
   `(current-lattice-meta-solution-fn (lambda (id) #f))` for meta detection to work.

2. **Parent cells may retain meta references after sub-cell solving**. `try-unify-pure` for
   Pi returns `(expr-Pi m1 dom (expr-Pi-codomain a))` -- preserving first side's codomain
   structure. When first side has a meta, the merge result equals the old value (no change).
   Parent cells can't be updated to fully concrete values by reconstructors alone. Meta
   references are resolved during the zonking phase. The key assertion is that meta CELLS
   are solved to concrete values.

3. **Pre-existing bug in `try-unify-pure` lam case**: `(expr-lam ty (expr-lam-body a))`
   was missing the `mult` argument. Fixed to `(expr-lam (expr-lam-mult a) ty (expr-lam-body a))`.
   This bug was latent because lam unification rarely occurs in practice (lam values are
   usually reduced before unification).

4. **Generic `decompose-1` + `make-1-reconstructor` eliminates boilerplate** for single-component
   types (PVec, Set, suc). The pattern is clean: pass predicate, accessor, and constructor.

5. **Same-cell guard prevents self-unification**: When both sides decompose to the same
   meta cell (e.g., both hold `?M`), the guard `(if (equal? sub-a sub-b) (values net #f) ...)`
   prevents creating a propagator that unifies a cell with itself.
