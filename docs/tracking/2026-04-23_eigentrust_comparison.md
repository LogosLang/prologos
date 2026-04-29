# EigenTrust in Prologos — 5-way Implementation Comparison

_Session 2026-04-23 + 2026-04-29. Compares **five** variants:
four Prologos surface implementations across the
`{List, PVec} × {Rat, Posit32}` grid, plus a fifth Racket-direct
implementation that uses Prologos's underlying propagator network
infrastructure but bypasses the surface language entirely.
The algorithm uses the **column-stochastic** convention: the matrix
`M` is the operational "trust-flow" matrix where `M[i][j]` is the
fraction of peer j's outgoing trust that flows to peer i. Each
column sums to 1; rows have no such constraint. The update is:_

```
t_{k+1} = (1 - alpha) * M * t_k + alpha * p
```

_`eigentrust` enforces the column-stochastic invariant; violating
it panics (Prologos surface) or raises an error (Racket-direct)._

## The five variants

| Container / Scalar | Example / source                          | Test file                              | Benchmark                               |
| ------------------ | ----------------------------------------- | -------------------------------------- | --------------------------------------- |
| List + Rat (P)     | `examples/eigentrust.prologos`            | `tests/test-eigentrust.rkt`            | `benchmarks/.../eigentrust-list-rat`    |
| List + Posit32 (P) | `examples/eigentrust-posit.prologos`      | `tests/test-eigentrust-posit.rkt`      | `benchmarks/.../eigentrust-list-posit`  |
| PVec + Rat (P)     | `examples/eigentrust-pvec.prologos`       | `tests/test-eigentrust-pvec.rkt`       | `benchmarks/.../eigentrust-pvec-rat`    |
| PVec + Posit32 (P) | `examples/eigentrust-pvec-posit.prologos` | `tests/test-eigentrust-pvec-posit.rkt` | `benchmarks/.../eigentrust-pvec-posit`  |
| **Racket on Propagators** | `benchmarks/.../eigentrust-propagators.rkt` | `tests/test-eigentrust-propagators.rkt` | `benchmarks/.../eigentrust-propagators-bench.rkt` |

(P) = Prologos surface language. The four (P) variants enforce
`col-stochastic?` at the entry of `eigentrust`; the Racket-direct
version raises an error in `build-eigentrust-network` if M isn't
column-stochastic.

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

Measured 2026-04-23 via `tools/bench-phases.rkt --runs 2`. Medians
across 2 measured runs (plus one warmup).

| Variant            | wall   | elaborate | type_check | qtt | reduce       | user sum | outside |
| ------------------ | -----: | --------: | ---------: | --: | -----------: | -------: | ------: |
| list + rat (P)     | 62 475 |      212  |       716  | 400 | **18 372**   |  19 702  |  42 772 |
| list + posit32 (P) | 61 683 |      210  |       678  | 372 | **17 990**   |  19 252  |  42 431 |
| pvec + rat (P)     | 76 884 |      144  |       370  | 112 | **33 006**   |  33 634  |  43 250 |
| pvec + posit32 (P) | 77 039 |      146  |       344  | 108 | **33 198**   |  33 798  |  43 241 |
| **propagators**    |    ~600 |       —   |         —  |  —  |  **0.16**    |    0.16  |    ~600 |

The first four are Prologos surface (P). The fifth is the
Racket-direct propagator-network implementation: 5-run median
on `racket benchmarks/comparative/eigentrust-propagators-bench.rkt`,
with `build_ms` (network construction) + `bsp_ms` (run to
quiescence) + `read_ms` (final cell read) summing into `reduce_ms`.
There is no Prologos elaboration / type-check / qtt phase — those
columns don't apply. `outside` is dominated by Racket runtime
startup (no Prologos prelude to load).

All values are median ms of measured runs. `reduce_ms` is the
actual algorithm runtime.

### Observations

* **The Racket-direct propagator implementation is ~115 000× faster
  on `reduce_ms`** than List+Rat for the W3 ring workload (0.16 ms
  vs 18 372 ms). The Prologos reducer's overhead (term-tree walk,
  pattern-match dispatch, exact-Rat normalisation) dwarfs the
  actual arithmetic. The Racket version has the same arithmetic
  cost (Racket's exact rationals are byte-identical to Prologos's
  Rat, since Prologos uses Racket's underlying rational ops) but no
  reducer ceremony — direct vector arithmetic and a 4-propagator
  chain.
* **Among the four Prologos surface variants, on the ring workload
  List beats PVec by ~80%** on `reduce_ms` (18 s vs 33 s). The ring
  matrix is very sparse — each column has a single non-zero — so
  dot-product cost is dominated by traversal overhead, not
  arithmetic. List's structural recursion produces cleaner reducible
  terms than PVec's nested `pvec-nth` + `pvec-push` accumulator
  construction.
* **Posit32 vs Rat is within 2%** in both Prologos containers for
  the ring workload. With the ring's sparse structure, even Rat's
  denominator growth is bounded (only the damping factor α=3/10
  introduces the factor 10 per step), so exact-rational arithmetic
  stays cheap.
* **Prologos elaboration is cheaper for PVec** (user sum ~33 s has
  most of its time in reduce, not elaborate): `type_check_ms` halves
  for PVec (344–370 vs 678–716 ms), `qtt_ms` drops by 3× (108–112 vs
  372–400). The index-based PVec helpers type-check with Nat
  counters, which are simpler for the checkers than List's nested
  structural patterns.
* **Earlier asymmetric-matrix result reversed:** on the previous
  `c-asym-3` workload (non-sparse, row-stochastic row-weighted sum)
  PVec was ~35% faster. On the ring (sparse, column-stochastic
  dot-product) List is ~80% faster. Different reducer traversal
  patterns prefer different data structures.
* **Iteration depth scales linearly for the propagator version**:
  k=2 → 0.11 ms, k=4 → 0.16 ms, k=10 → 0.56 ms. The Prologos
  surface variants exhibit O(k²) reduce blowup beyond k≈3 (an
  unreduced `tnew = [eigentrust-step c p alpha tnew]` term tree
  grows quadratically across forced iterations). The propagator
  version eagerly reduces in each fire function, so the term tree
  stays flat — k=10 is fast where the surface versions don't
  terminate within minutes.

### What this implies

* **Data structure choice depends on the workload shape, not on
  abstract asymptotics.** For this algorithm at n=3 or n=4, neither
  container dominates across all fixtures. Dense matrices with
  heterogeneous values favor PVec's index-based traversal; sparse
  matrices with repetitive values favor List's structural recursion.
* **Posit32 vs Rat at small n is noise** — the arithmetic is a tiny
  fraction of reducer work at these matrix sizes.
* **The `col-stochastic?` check cost is visible but not dominant.**
  Each benchmark runs it 4× (inside `eigentrust` for W1, W2, W3 plus
  W4 standalone). For List+Rat that's ~600 ms of the 18 s reduce
  budget; for PVec+Rat it's ~1.5 s (PVec needs the `zeros` builder
  + more iteration). Removing the enforcement would shave a few
  percent off reduce_ms, but at the cost of losing the invariant
  check — not worth the trade.

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

## What the comparison tells us about Prologos

* **The propagator infrastructure is fast.** When the Prologos
  surface language and reducer are stripped away, the underlying
  cell + propagator machinery handles the same algorithm in
  microseconds. The 5-orders-of-magnitude gap between the
  surface and direct versions is mostly Prologos elaboration +
  reduction overhead, not propagator network overhead.
* **Apples-to-oranges, but informative.** The Racket-direct
  implementation is what the surface implementation should
  approach as the Prologos compiler matures (lowering Prologos
  surface code to fast propagator network operations). The gap
  is a measure of "how much Prologos costs you on a hot path
  today" — useful as a yardstick for compiler optimization
  work.
* **The propagator chain pattern works.** Each iteration is one
  cell holding the trust vector at that step; one plain
  propagator per step reads the previous cell and writes the
  next. After K BSP rounds the chain has settled. Plain (not
  fire-once) propagators are required: the chain depends on
  inter-round propagation through cell writes, which is exactly
  how non-fire-once propagators chain.

## How to reproduce

```
# Four Prologos surface variants
racket tools/bench-phases.rkt --runs 2 \
  benchmarks/comparative/eigentrust-list-rat.prologos \
  benchmarks/comparative/eigentrust-list-posit.prologos \
  benchmarks/comparative/eigentrust-pvec-rat.prologos \
  benchmarks/comparative/eigentrust-pvec-posit.prologos

# Fifth: Racket-direct on propagators
racket benchmarks/comparative/eigentrust-propagators-bench.rkt

# Tests
raco test tests/test-eigentrust.rkt              # 13 tests (List+Rat)
raco test tests/test-eigentrust-posit.rkt        #  6 tests (List+Posit32)
raco test tests/test-eigentrust-pvec.rkt         #  6 tests (PVec+Rat)
raco test tests/test-eigentrust-pvec-posit.rkt   #  6 tests (PVec+Posit32)
raco test tests/test-eigentrust-propagators.rkt  # 13 tests (propagator)
```
