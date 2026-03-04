# Phase 4c: Structural Decomposition Propagators

**Created**: 2026-03-04
**Status**: IN PROGRESS
**Depends on**: P-Unify Phases 1a–4b (commits `b34e716`–`f944d2c`)

## Motivation

The propagator network is currently a flat constraint graph: cells connected by
bidirectional unify propagators. `type-lattice-merge`/`try-unify-pure` do structural
decomposition inline during merge, but results stay in the cell value — they don't
create sub-constraints in the network. Individual metas embedded within compound types
are NOT solved through propagation; only the imperative `unify` path solves them.

### What This Unlocks

**Transitive structural resolution**: When cell A holds `Pi(Nat, ?M)` and cell B holds
`Pi(?N, Bool)`, the network decomposes into domain and codomain sub-cells, directly
solving `?N=Nat` and `?M=Bool` through propagation. Three-way chains (A-B-C) where
domain info enters at A and codomain info enters at C both resolve at B, purely through
the network — no imperative retry needed.

### Formal Foundation

Radul/Sussman constructor/accessor pattern: compound partial information decomposes
into sub-cells. `merge(Pi(A1,B1), Pi(A2,B2)) = Pi(merge(A1,A2), merge(B1,B2))`.
Sub-cells persist within a computation branch (monotone). CHAMP snapshot rollback
discards speculative sub-cells automatically.

## Architecture

Two CHAMP-backed registries on `prop-network` prevent duplicate work:
1. `cell-decomps`: `cell-id → (cons constructor-tag (listof cell-id))` — per-cell sub-cells
2. `pair-decomps`: `(cons cell-id cell-id) → #t` — per-pair dedup

Decomposition is lazy: happens inside the unify propagator's fire function when both
cells have concrete values with the same head constructor.

Information flow: downward (decompose → sub-cells), lateral (sub-cell ↔ sub-cell unify
propagators), upward (reconstructor propagators rebuild compound → write to parent).

### Sub-Cell Identification

- **Bare meta**: Reuse the meta's existing propagator cell (key mechanism!)
- **Ground**: Fresh cell initialized to ground value
- **Compound with metas**: Fresh cell initialized as-is; further decomposition recursive

## Sub-Phases

### 4c-a: Infrastructure
- [x] Add `cell-decomps` + `pair-decomps` CHAMP fields to `prop-network`
- [x] Registry helper functions in `propagator.rkt`
- [x] `current-structural-meta-lookup` parameter in `elaborator-network.rkt`
- [x] Install callback from `driver.rkt`
- [x] Unit tests for registry operations

### 4c-b: Core Structural Decomposition (Pi + app)
- [ ] `make-structural-unify-propagator` (replaces `make-unify-propagator`)
- [ ] `maybe-decompose`, `get-or-create-sub-cells`, `identify-sub-cell`
- [ ] `decompose-pi` + `make-pi-reconstructor`
- [ ] `decompose-app` + `make-app-reconstructor`
- [ ] Update `elab-add-unify-constraint` slow path
- [ ] ~25 tests in `test-structural-decomp.rkt`

### 4c-c: Extended Constructors
- [ ] Sigma, Eq, Vec, PVec, Set, Map, pair, suc, lam decomposers
- [ ] +10-15 tests

### 4c-d: Full Validation + PIR Update
- [ ] Full test suite pass
- [ ] Benchmark within 15% of baseline
- [ ] Update PIR document

## Key Files

| File | Changes |
|------|---------|
| `racket/prologos/propagator.rkt` | `prop-network` +2 fields, +6 helpers |
| `racket/prologos/elaborator-network.rkt` | Structural propagator, decomposers, reconstructors |
| `racket/prologos/driver.rkt` | Install meta-lookup callback |
| NEW `tests/test-structural-decomp.rkt` | ~40 tests |

## Lessons Learned

(To be filled as implementation progresses)
