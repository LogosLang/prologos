# EigenTrust in Prologos — 7-way Implementation Comparison

_Session 2026-04-23 + 2026-04-29. Compares **seven** variants:
four Prologos surface implementations across the
`{List, PVec} × {Rat, Posit32}` grid, plus three Racket-direct
implementations that use Prologos's underlying propagator network
infrastructure but bypass the surface language. The propagator
variants split into:_

- _**rat-coarse**: chain-of-cells, exact rationals, one cell per iteration._
- _**rat-fine**: per-peer cells, exact rationals — K·n cells, K·n propagators._
- _**float**: chain-of-cells, hardware flonums (`flvector`)._
The algorithm uses the **column-stochastic** convention: the matrix
`M` is the operational "trust-flow" matrix where `M[i][j]` is the
fraction of peer j's outgoing trust that flows to peer i. Each
column sums to 1; rows have no such constraint. The update is:_

```
t_{k+1} = (1 - alpha) * M * t_k + alpha * p
```

_`eigentrust` enforces the column-stochastic invariant; violating
it panics (Prologos surface) or raises an error (Racket-direct)._

## The seven variants

| # | Variant | Source | Test |
|---|---|---|---|
| 1 | List + Rat (P) | `examples/eigentrust.prologos` | `tests/test-eigentrust.rkt` |
| 2 | List + Posit32 (P) | `examples/eigentrust-posit.prologos` | `tests/test-eigentrust-posit.rkt` |
| 3 | PVec + Rat (P) | `examples/eigentrust-pvec.prologos` | `tests/test-eigentrust-pvec.rkt` |
| 4 | PVec + Posit32 (P) | `examples/eigentrust-pvec-posit.prologos` | `tests/test-eigentrust-pvec-posit.rkt` |
| 5 | **rat-coarse** (propagator) | `benchmarks/.../eigentrust-propagators.rkt` | `tests/test-eigentrust-propagators.rkt` |
| 6 | **rat-fine** (propagator) | `benchmarks/.../eigentrust-propagators-fine.rkt` | `tests/test-eigentrust-propagators-fine.rkt` |
| 7 | **float** (propagator) | `benchmarks/.../eigentrust-propagators-float.rkt` | `tests/test-eigentrust-propagators-float.rkt` |

Shared benchmark runner for variants 5–7:
`benchmarks/comparative/eigentrust-propagators-bench.rkt`.

(P) = Prologos surface language. All variants enforce
`col-stochastic?` at the algorithm entry; the surface variants
panic, the Racket-direct ones `error`.

**Architectural breakdown** (5-7):
- _coarse_ (5, 7): one cell per iteration, holding the entire
  trust vector. K plain propagators (one per step).
- _fine_ (6): one cell per peer per iteration. K·n cells,
  K·n propagators. Each peer-step propagator reads all n cells
  of the previous iteration row + the 3 constants, writes one
  scalar.

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

### W3 (ring-4 / k=4 / α=3/10) — the reference workload

| Variant             | wall   | elaborate | type_check | qtt | reduce       | user sum | outside |
| ------------------- | -----: | --------: | ---------: | --: | -----------: | -------: | ------: |
| list + rat (P)      | 62 475 |      212  |       716  | 400 | **18 372**   |  19 702  |  42 772 |
| list + posit32 (P)  | 61 683 |      210  |       678  | 372 | **17 990**   |  19 252  |  42 431 |
| pvec + rat (P)      | 76 884 |      144  |       370  | 112 | **33 006**   |  33 634  |  43 250 |
| pvec + posit32 (P)  | 77 039 |      146  |       344  | 108 | **33 198**   |  33 798  |  43 241 |
| **rat-coarse** (5)  |   ~850 |       —   |         —  |  —  |  **0.12**    |   0.12   |    ~850 |
| **rat-fine** (6)    |   ~850 |       —   |         —  |  —  |  **0.23**    |   0.23   |    ~850 |
| **float** (7)       |   ~850 |       —   |         —  |  —  |  **0.10**    |   0.10   |    ~850 |

5-run median for variants 5–7 (single-process Racket; the wall ~850 ms
is shared across 9 runs of the bench harness, dominated by Racket
runtime startup). The four surface variants are 2-run median from
`tools/bench-phases.rkt`. `reduce_ms` is the actual algorithm time;
`outside` is everything else (prelude load + Racket startup + I/O).

For propagator variants, `reduce_ms = build_ms + bsp_ms + read_ms`:
```
              build_ms   bsp_ms    reduce_ms
rat-coarse    0.03       0.08      0.12
rat-fine      0.07       0.16      0.23
float         0.03       0.07      0.10
```

### W3-deep (ring-4 / k=10 / α=3/10) — chain depth scaling

| Variant       | reduce_ms | Notes |
| ------------- | --------: | ----- |
| rat-coarse    |     0.42  | linear in K (3.5× from k=4) |
| rat-fine      |     1.38  | linear in K·n (5.75× from k=4 — `n=4` per-step factor compounds) |
| float         |     0.37  | linear in K (3.7× from k=4) |
| (P) variants  | did not finish | O(k²) reducer blowup beyond k≈3 |

The propagator variants stay linear in K because each fire
function eagerly reduces to a normalised vector value; the
Prologos surface variants keep an unreduced
`tnew = [eigentrust-step c p α tnew]` term tree that grows
quadratically across budget rounds.

### Scaling across n — large-graph performance

`benchmarks/comparative/eigentrust-propagators-scaling.rkt` runs
the three propagator variants on random column-stochastic matrices
at sizes n = 8..128 (all three variants), then float-only at
n = 256..4096 (rat is intractable beyond 128). K=4, 3 measured runs
per (variant, n), median.

**All three variants, n = 8..128:**

| n   | rat-coarse | rat-fine    | float    | fine/coarse | rat/float |
| --: | ---------: | ----------: | -------: | ----------: | --------: |
|   8 |     5.3 ms |       6.9 ms |  0.14 ms |        1.3× |       38× |
|  16 |    56.7 ms |      75.8 ms |  0.14 ms |        1.3× |      392× |
|  32 |   669.5 ms |     687.8 ms |  0.19 ms |        1.0× |    3 496× |
|  64 |    10.0 s  |      10.2 s  |  0.42 ms |        1.0× |   23 647× |
| 128 |   138.2 s  |     138.7 s  |  1.11 ms |        1.0× |  124 088× |

**Float only, n = 256..4096:** _to be filled in_

### Observations on scaling

* **Exact-rat is exponential in n.** Each doubling of n is roughly
  10-15× slower for both rat variants. The cause: at iteration k,
  every entry of `M·t_k` is a sum of n products of rationals. With
  random-rational inputs, the numerator/denominator both grow as
  `O(n^k)` worst case; arithmetic on bigints is O(d log d) in the
  digit count d. The compound effect (n^4 = 268M at n=128) makes
  arithmetic itself dominant. **Exact-rat is not viable beyond
  n ≈ 64 in this implementation.**
* **Float scales sub-quadratically** from n=8 to n=128: 16× dimension
  growth, only ~8× time growth. Pure mat-vec-mul is O(n²); the
  observed sub-n² growth suggests memory bandwidth dominates over
  flop count at these sizes (the n=8 row fits in L1 cache; larger
  rows stream from L2/L3 but still well within bandwidth).
* **rat-fine/rat-coarse converges to 1.0× as n grows.** At n=8
  per-cell overhead makes fine 30% slower than coarse; by n=32
  they're statistically tied. The fine variant's K·n cells amortize
  better as the per-fire work (a single dot product) grows. At n=128
  there's no measurable difference — both are bottlenecked on
  rational arithmetic, not on cell-handling overhead.
* **rat/float ratio explodes from 38× to 124 088×** between n=8 and
  n=128. For any "real" trust graph (hundreds of peers and up),
  float is the only viable option; the rat variants are useful for
  correctness verification at small n only.

### Observations

* **All three propagator variants are 5+ orders of magnitude faster
  than the surface variants on W3 reduce_ms.** rat-coarse: 0.12 ms
  vs List+Rat 18 372 ms (~150 000×). The Prologos reducer's overhead
  (term-tree walk, pattern-match dispatch, exact-Rat normalisation)
  dwarfs the arithmetic. Both versions perform identical
  Racket-level arithmetic on identical exact-rational values; the
  gap measures Prologos elaboration + reduction overhead.
* **Float beats rat-coarse by ~17%** at W3 (0.10 vs 0.12 ms), in
  line with hardware double-precision being faster than exact
  rational arithmetic for n=4. At larger n the gap widens.
* **Fine-grained loses to coarse by ~2× at n=4**: 0.23 vs 0.12 ms
  for W3, 1.38 vs 0.42 ms for W3-deep. Per-cell overhead (CHAMP
  insert, dependent registration, scheduler bookkeeping) for K·n
  cells exceeds the benefit of finer-grained per-fire work at this
  matrix size. The fine variant might cross over for larger n
  (or under parallel BSP execution where the per-iteration peers
  fire concurrently), but for n=4 the constants dominate.
* **Iteration depth scales linearly for all 3 propagator variants**:
  rat-coarse k=2→0.08, k=4→0.12, k=10→0.42 ms. The Prologos surface
  variants exhibit O(k²) reduce blowup beyond k≈3 (an unreduced
  `tnew = [eigentrust-step c p α tnew]` term tree grows
  quadratically across forced iterations). The propagator variants
  eagerly reduce in each fire function, so the term tree stays
  flat — k=10 is fast where the surface versions don't terminate
  within minutes.
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

# Three Racket-direct propagator variants (rat-coarse, rat-fine, float)
racket benchmarks/comparative/eigentrust-propagators-bench.rkt

# Tests (4 surface + 3 propagator)
raco test tests/test-eigentrust.rkt                       # 13 tests
raco test tests/test-eigentrust-posit.rkt                 #  6 tests
raco test tests/test-eigentrust-pvec.rkt                  #  6 tests
raco test tests/test-eigentrust-pvec-posit.rkt            #  6 tests
raco test tests/test-eigentrust-propagators.rkt           # 13 tests (rat-coarse)
raco test tests/test-eigentrust-propagators-fine.rkt      #  6 tests (rat-fine)
raco test tests/test-eigentrust-propagators-float.rkt     #  9 tests (float)
```

## Pitfalls surfaced

- Surface-language pitfalls: `2026-04-23_eigentrust_pitfalls.md` (16 entries).
- Propagator-track pitfalls: `2026-04-29_eigentrust_propagators_pitfalls.md` (5 entries — fire-once vs chain, cell-merge during initial reads, float `equal?`, `for/sum` exact 0 vs 0.0, fine-grained cell-id lookup overhead).
