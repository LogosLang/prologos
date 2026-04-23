# EigenTrust in Prologos — 4-way Implementation Comparison

_Session 2026-04-23. Compares four variants across the
`{List, PVec} × {Rat, Posit32}` grid. The algorithm uses the
**column-stochastic** convention: the matrix `M` is the operational
"trust-flow" matrix where `M[i][j]` is the fraction of peer j's
outgoing trust that flows to peer i. Each column sums to 1; rows
have no such constraint. The update is:_

```
t_{k+1} = (1 - alpha) * M * t_k + alpha * p
```

_`eigentrust` enforces the column-stochastic invariant via
`col-stochastic?`; violating it panics._

## The four variants

| Container / Scalar | Example file                              | Test file                              | Benchmark                               |
| ------------------ | ----------------------------------------- | -------------------------------------- | --------------------------------------- |
| List + Rat         | `examples/eigentrust.prologos`            | `tests/test-eigentrust.rkt`            | `benchmarks/.../eigentrust-list-rat`    |
| List + Posit32     | `examples/eigentrust-posit.prologos`      | `tests/test-eigentrust-posit.rkt`      | `benchmarks/.../eigentrust-list-posit`  |
| PVec + Rat         | `examples/eigentrust-pvec.prologos`       | `tests/test-eigentrust-pvec.rkt`       | `benchmarks/.../eigentrust-pvec-rat`    |
| PVec + Posit32     | `examples/eigentrust-pvec-posit.prologos` | `tests/test-eigentrust-pvec-posit.rkt` | `benchmarks/.../eigentrust-pvec-posit`  |

All four enforce `col-stochastic?` at the entry of `eigentrust`.

## Shared benchmark workload

Every benchmark runs the same W1..W9 set:

* **W1.** `eigentrust m-uniform-4 p-uniform-4 α=1/10 ε=1/1000 50` —
  uniform matrix; converges in one step (uniform is the fixed point).
* **W2.** `eigentrust m-others-3 p-uniform-3 α=1/10 ε=1/1000 50` —
  symmetric 3×3; uniform is also the stationary distribution.
* **W3.** `eigentrust m-ring-4 p-seed-0 α=3/10 ε=0 3` — **4-peer ring
  with concentrated pre-trust (all mass on peer 0)**, forced 3 iters.
  The ring permutation has |eigenvalue| = 1 on the unit circle; only
  the damping `α·p` term pulls the iterate toward uniform. Concentrated
  pre-trust amplifies the settling pattern; this is the only workload
  that produces non-trivial `reduce_ms`.
* **W4.** `col-stochastic? m-uniform-4` — single invariant check.
* **W5.** `eigentrust-step m-uniform-4 p-uniform-4 α p-uniform-4` —
  one step on the uniform matrix.
* **W6.** `mat-vec-mul m-uniform-4 p-uniform-4` — one matrix-vector
  multiply.
* **W7–W9.** `scale-vec`, `add-vec`, `linf-norm ∘ sub-vec` on small
  vectors.

`α=3/10` follows the standard EigenTrust convention: 70% network
weight, 30% pre-trust anchor. Deeper budgets scale as O(k²) in
Prologos's reducer (pitfall #11), so k=3 is the sweet spot.

## Ergonomic differences

| Concern                                          | List + Rat                         | List + Posit32    | PVec + Rat                       | PVec + Posit32    |
| ------------------------------------------------ | ---------------------------------- | ----------------- | -------------------------------- | ----------------- |
| Matrix literal zero element                      | `rz : Rat := 0/1` splice           | `~0.0` direct     | `0/1` direct in `@[...]`          | `~0.0` direct     |
| Matrix literal one element                       | `ro : Rat := 1/1` splice           | `~1.0` direct     | `1/1` direct in `@[...]`          | `~1.0` direct     |
| Indexing type                                    | List has `nth-int`                 | Same              | PVec is Nat-only                 | Same              |
| Element-wise zip                                 | structural recursion on two lists  | Same              | index loops via `pvec-nth`       | Same              |
| Source file size (example)                       | 250 LOC                            | 160 LOC           | 200 LOC                          | 200 LOC           |
| `col-stochastic?` check cost (relative)          | baseline                           | baseline          | ~2× (needs `zeros` builder)      | ~2×               |

## Phase breakdown

_Will be populated by `tools/bench-phases.rkt --runs 2` (running in
the background)._

## What we learned

* **The operational matrix is column-stochastic.** That was initially
  wrong in this codebase: the first version took a row-stochastic
  matrix and computed `C^T * t` internally. Switching to explicit
  column-stochastic `M` eliminates the `sum-rows`/`scale-rows` helper
  pair in favor of a standard `dot`-based `mat-vec-mul`.
* **Invariant enforcement via panic works.** Prologos supports
  `(the T [panic "msg"])` which returns a runtime error string. The
  `eigentrust` entry point checks `col-stochastic? m` and panics
  if false. Overhead is ~O(n²), dominated once by the check versus
  O(n² * k) for iteration.
* **Ring + concentrated pre-trust is the right slow-settling
  fixture.** The ring permutation matrix is doubly stochastic so
  uniform is stationary, but starting `p` (and hence `t0 = p`) on a
  single node means every step pushes trust one hop around the ring
  while damping slowly averages it out. With `α=3/10` the settling
  rate is the dominant eigenvalue magnitude (≈0.7), giving visible
  asymmetry in `t` even after 3 iterations.
* **The initial state vector doesn't matter much** (as long as it
  sums to 1). The code uses `t0 = p` for simplicity: any valid
  distribution converges to the same stationary solution.
* **PVec vs List rankings are workload-dependent.** On the earlier
  `c-asym-3` (non-sparse, row-stochastic) workload PVec was ~35%
  faster. On the ring (sparse, column-stochastic) List is faster.
  The comparison isn't a simple "PVec wins" or "List wins"; it's
  "measure your workload".

## How to reproduce

```
racket tools/bench-phases.rkt --runs 2 \
  benchmarks/comparative/eigentrust-list-rat.prologos \
  benchmarks/comparative/eigentrust-list-posit.prologos \
  benchmarks/comparative/eigentrust-pvec-rat.prologos \
  benchmarks/comparative/eigentrust-pvec-posit.prologos

raco test tests/test-eigentrust.rkt        # 13 tests
raco test tests/test-eigentrust-posit.rkt  # 6 tests
raco test tests/test-eigentrust-pvec.rkt   # 6 tests
raco test tests/test-eigentrust-pvec-posit.rkt  # 6 tests
```
