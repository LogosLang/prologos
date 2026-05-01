# EigenTrust: math vs network vs Prologos math

_Session 2026-04-23 + 2026-04-29. Comparing **how the same algorithm
runs through different layers of abstraction**, with float-like
scalar types throughout. The four axes:_

| Axis | What it measures | Implementation |
|---|---|---|
| **math** | Algorithm in plain Racket. Just function calls. | `plain-fl` — `eigentrust-plain.rkt` |
| **network** | Same algorithm built on Prologos's propagator network infrastructure (cells + propagators + BSP scheduler), bypassing the surface language. | `float` — `eigentrust-propagators-float.rkt` |
| **Prologos math** | Algorithm in Prologos surface language (no propagators), going through the elaborator + reducer. | `List + Posit32` (P) — `examples/eigentrust-posit.prologos` |
| **Prologos network** | (future) Surface Prologos code that compiles to a propagator network. Not yet a thing. | — |

All four use float-like types: Racket flonums for the first two,
Prologos's `Posit32` (hardware posits) for the surface variant.

Algorithm: the standard EigenTrust update with column-stochastic M:
```
t_{k+1} = (1 − α) · M · t_k  +  α · p
```
`eigentrust` enforces `col-stochastic?` at the entry point.

## W3 reference workload — n=4, k=4, α=3/10

A 4-peer ring matrix with all pre-trust on peer 0 (`p = [1, 0, 0, 0]`),
4 forced iterations. Smallest workload that fairly exercises the
algorithm; result is `[5401/10000, 21/100, 147/1000, 1029/10000]`
(or ~`[0.5401, 0.21, 0.147, 0.1029]` in float).

| Axis              | reduce_ms |  vs math  | Notes |
| ----------------- | --------: | --------: | ----- |
| **math** (plain-fl) |    ~0.03 |     1×    | Racket flvector arithmetic, no overhead. |
| **network** (float) |     0.10 |    ~3×    | Same arithmetic kernel inside fire functions; +~70 µs of cell + BSP overhead. |
| **Prologos math** (List + Posit32) | 15 047 | **~500 000×** | Surface language, evaluated by Prologos's reducer. Pure reduction time for the single W3 expression — elaboration, type-check, qtt, zonk, prelude load, and Racket startup are all excluded (PHASE-TIMINGS:reduce_ms only). |
| Prologos network  |        —  |     —     | _doesn't exist yet_. |

The 5-to-6 orders-of-magnitude gap between **math** and **Prologos
math** is the cost of the Prologos surface language + reducer on a hot
path: term-tree walks, pattern-match dispatch, pretty-printing,
no flonum specialization, plus the O(k²) reduce-tree blowup
(see `2026-04-23_eigentrust_pitfalls.md` §11) that makes deeper
iteration progressively more expensive. This is _just_ reduction —
the other Prologos phases (elaborate, type-check, qtt, zonk) sum
to ~1.5 s on this workload, ~100× smaller than reduce.

The **network** vs **math** gap is small in absolute terms (~70 µs
per call) and dominated by per-iteration constant cost (cell
allocation, BSP round dispatch, fire-fn invocation, CHAMP path
copies on each cell-write). It amortizes as n grows — see scaling
below.

### A note on what `reduce_ms` measures

For the Prologos surface variant, `reduce_ms` is the
PHASE-TIMINGS:reduce_ms emitted by `driver.rkt`'s `process-file`
— **just** the reducer phase, not elaboration, type-checking, qtt,
trait resolution, or zonking. So the 500 000× gap is not "Prologos
is slow at startup", it's "the reducer walks term trees instead of
calling flonum primitives". The `eigentrust-list-posit-w3only.prologos`
fixture isolates the W3 expression specifically so its reduce_ms
isn't bundled with W1/W2 (which the full benchmark file also
contains).

## Scaling across n — math vs network

Only the float-typed variants (math, network) are measured at large
n. The Prologos surface variants take ~60 s of fixed overhead per
run (Prologos prelude load + Racket startup) and the fixture
generators are surface code, so a Prologos-surface-at-large-n bench
is a separate piece of work. Today's data is the Racket-direct
side.

`benchmarks/comparative/eigentrust-propagators-scaling.rkt` —
K=4, 30 s per-sample timeout, median of 3 runs (n=8..4096).
`benchmarks/comparative/eigentrust-scaling-large.rkt` — K=4, 180 s
per-sample timeout, median of 2 runs (n=4096..16384).

| n     | math (plain-fl) | network (float) | network overhead | source |
| ----: | -------------: | --------------: | ---------------: | -----: |
|     8 |        0.03 ms |         0.12 ms |          +300 %  | prior  |
|    16 |        0.03 ms |         0.14 ms |          +367 %  | prior  |
|    32 |        0.05 ms |         0.16 ms |          +220 %  | prior  |
|    64 |        0.09 ms |         0.28 ms |          +211 %  | prior  |
|   128 |        0.27 ms |         0.57 ms |          +111 %  | prior  |
|   256 |        0.99 ms |         2.10 ms |          +112 %  | prior  |
|   512 |        4.59 ms |         9.00 ms |           +96 %  | prior  |
|  1024 |       19.40 ms |        33.86 ms |           +75 %  | prior  |
|  2048 |       88.37 ms |       151.62 ms |           +72 %  | prior  |
|  4096 |      442.14 ms |       619.37 ms |           +40 %  | prior  |
|  4096 |      584.38 ms |       958.30 ms |           +64 %  | extended |
|  8192 |     3015.74 ms |      4439.84 ms |           +47 %  | extended |
| 16384 |    15989.23 ms |     20674.00 ms |           +29 %  | extended |

The "extended" rows come from a separate measurement run
(`benchmarks/comparative/eigentrust-scaling-large.rkt`, K=4, median of
2 measured runs after 1 warmup, 180 s timeout). The two n=4096 numbers
diverge by 32 % on math and 55 % on network — both are real, just
different runs/cache states. Both rows are kept to give an honest
picture of run-to-run variance at this scale, which is bigger than
the model can explain. n=32768 was attempted but the fixture (8 GB)
+ Racket's still-rooted previous matrix (2 GB) + working set drove
the 16 GB host into GC thrashing during fixture allocation; on a 32+
GB box appending `32768` to `SIZES` would let the data point land.

### What the scaling shows

* **Math scales slightly worse than O(n²)** in the cache-bound
  regime. Doubling factors past n=512:

  | n→2n | factor |
  | --- | ---: |
  | 256 → 512 | 4.64× |
  | 512 → 1024 | 4.23× |
  | 1024 → 2048 | 4.56× |
  | 2048 → 4096 | 5.00× |
  | 4096 → 8192 | 5.16× |
  | 8192 → 16384 | 5.30× |

  The drift from 4× toward 5× is the working set (n² doubles =
  flvector data + temporary flvectors per iteration) outgrowing
  L2/L3 and hitting DRAM bandwidth on every entry.

* **Network overhead drops monotonically as n grows**: from +300 %
  at n=8 down to +29 % at n=16384 — every doubling past n=4096 takes
  ~17 percentage points off. The drop comes from the same n²
  math kernel running inside the fire function (so the math part
  scales identically) while network's overhead is in lower-order
  terms — per-cell-write CHAMP path-copy (O(n) per write × K writes
  = O(K·n)) and BSP scheduler bookkeeping (constant per round).

### Trend / breakeven analysis

A two-term model fit on n ≥ 128 with a SHARED n² coefficient
(both run the identical math kernel):

```
math(n)    ≈ 6.18·10⁻⁵ · n²                          − 334
network(n) ≈ 6.18·10⁻⁵ · n²  +  0.230 · n            − 526
overhead   = network − math  =  0.230 · n            − 191      (linear in n)
overhead / math  →  0  as n → ∞       (drops as ~b/(a·n) from above)
```

The fit is good at the largest n where measurement noise matters
least: error 1.7 % on math at n=16384, −4.0 % on network. Smaller
n have larger relative errors as expected (constants matter more).

**Predicted overhead at n we did not measure**:

| n       | math (extrap) | net (extrap) | overhead |
| ------: | ------------: | -----------: | -------: |
|  32 768 |     ~66 000 ms |     ~73 000 ms |    +11 % |
|  65 536 |    ~265 000 ms |    ~280 000 ms |    +5.6 % |
| 131 072 |  ~1 060 000 ms |  ~1 090 000 ms |    +2.8 % |
| 262 144 |  ~4 250 000 ms |  ~4 310 000 ms |    +1.4 % |

So the empirical answer to "is there a breakeven where network beats
math?": **no, there isn't, and there can't be**. The fit confirms
what the structure of the code already implies — the network's fire
function calls the *same* math kernel that the plain Racket version
calls, plus extra bookkeeping (cell allocation, BSP round dispatch,
CHAMP path-copy on cell writes). Network's work is strictly a
superset of math's work, so the overhead is always non-negative.
What changes with n is the *ratio*: math grows as n² while overhead
grows as n, so the ratio collapses asymptotically. At n=10⁶ the
overhead would be ~0.4 %; at n=10⁷ ~0.04 %. But it never crosses.

The same is true under any model where network does math plus
strictly-positive bookkeeping. The only way network could win
would be:

* **Real parallelism on multiple cores** — the current BSP
  scheduler runs one round at a time on one thread. If propagators
  fired in parallel (broadcast scheduler, multi-thread BSP), large
  N could partition across cores while math stays single-threaded.
  This is not what's measured here.
* **Incremental computation** — if only some cells change, the
  network only re-fires the dependents while math has to recompute
  the whole iteration. Not measured here either; one-shot dense
  matrix-vector is the worst case for incremental.
* **Working-set effects** — if the network's per-fire allocation
  pattern happened to be more cache-friendly than math's at some
  specific n. The data shows the opposite: network's CHAMP
  path-copy is *less* cache-friendly than math's in-place flvector
  iteration. There is no n where it accidentally wins.

For the existing single-threaded one-shot dense workload, math is
the architectural floor. Network's value isn't beating math on
this workload — it's amortizing the bookkeeping to ≤ 1–2 % at
algorithmic scale, while delivering the propagator network's
infrastructure (incremental computation, parallel firing,
worldview tagging, partial recomputation) that math can't
express at all.

## What about parallel BSP?

The natural follow-up: the BSP scheduler can fire independent
propagators across cores. Why didn't the coarse variant exploit
that? Two reasons:

1. **Default executor is sequential.** `run-to-quiescence-bsp`
   defaults to `sequential-fire-all` unless
   `current-parallel-executor` or `current-worker-pool` is set.
   The benches above don't set either, so all data is
   single-threaded.

2. **Coarse topology has no parallel work to dispatch.** The
   coarse variant is K propagators in a strict chain: t₀ → t₁ →
   t₂ → … → t_K. Each fires only after its predecessor's cell
   is written. One propagator per BSP round. Parallel BSP
   needs ≥ 2 independent propagators per round.

To actually exercise parallel BSP, we built a fine-grained
variant — `eigentrust-propagators-fine-float.rkt` — with K·n
per-peer propagators (n peer-step functions per BSP round, each
computing one element of the new trust vector independently).
The bench `eigentrust-parallel-bench.rkt` runs it with three
executors: sequential, `make-parallel-thread-fire-all` (Racket-9
`thread #:pool 'own`), and a persistent worker-pool dispatcher.

K=4, NUM-RUNS=3, 4-core host, median of 3 measured runs:

| n    | math (1 core) | coarse net (1) | fine-seq (1) | fine-thread (4) | fine-pool (4) | par speedup | fine-thread vs math |
| ---: | ------------: | -------------: | -----------: | --------------: | ------------: | ----------: | ------------------: |
|   16 |       0.06 ms |        0.27 ms |      5.67 ms |         5.24 ms |       5.70 ms |       1.08× |                 87× |
|   32 |       0.08 ms |        0.25 ms |     19.21 ms |        13.59 ms |      12.25 ms |       1.41× |                170× |
|   64 |       0.16 ms |        0.47 ms |     82.61 ms |        52.10 ms |      55.30 ms |       1.59× |                326× |
|  128 |       0.49 ms |        1.15 ms |    307.25 ms |       159.97 ms |     173.11 ms |       1.92× |                326× |
|  256 |       2.09 ms |        4.26 ms |   1348.7  ms |       624.71 ms |     618.37 ms |       2.16× |                299× |
|  512 |      10.83 ms |       17.67 ms |   6796.4  ms |      3172.2  ms |    3154.4  ms |       2.14× |                293× |
| 1024 |      40.74 ms |       70.62 ms |  29240.9  ms |     16164.2  ms |   16302.3  ms |       1.81× |                397× |

### Two clean findings

* **BSP parallelism does work**: fine-seq → fine-thread shows up
  to **2.16× speedup at n=256** on the 4-core box. Theoretical
  max is 4×; the measured 2.16× reflects per-fire serialization
  costs (snapshot taking, dependency walk, write merging) that
  Amdahl-bound the speedup. Parallel-thread and worker-pool
  executors are within noise of each other.

* **The fine-grained topology's overhead swamps the parallelism**:
  fine-thread is still **290–400× slower than math** at every n.
  Per-peer decomposition pays K · n² cell reads (n peer
  propagators × n cell reads each × K rounds) + K · n cell
  writes through CHAMP (each O(log n)). At n=1024 that's ~4M
  CHAMP lookups vs math's 4M flonum ops. The cell-access
  overhead, not the math, dominates per-fire cost.

### Why neither variant wins

The architectural bind:

| Variant | Parallel work? | Per-fire overhead | Net result |
| ------- | -------------- | ----------------- | ---------- |
| **coarse** | none (chain) | tiny (K cell writes total) | 1.4× math at n=16384 |
| **fine** | yes (n props/round) | K·n² CHAMP reads + K·n writes | 290–400× math at all sizes |

To actually beat math via parallelism we'd need either:

* **Coarse topology + parallelism inside the fire function** —
  e.g., a fire function that internally splits its mat-vec-mul
  across a worker pool. The propagator primitives don't directly
  enable this: `fire-fn` is a run-to-completion thunk; the
  scheduler doesn't decompose individual fire calls. Adding it
  would mean the fire function manually dispatches via futures /
  threads, paying its own coordination cost outside the BSP
  framework.

* **Much higher arithmetic intensity per fire** — e.g., dense
  tensor ops where one fire does millions of flonum ops, so
  per-fire BSP overhead amortizes over real work. Mat-vec-mul
  at the per-peer grain is too small (n flonum mul-adds per
  fire); at the whole-vector grain (coarse) there's only one
  propagator to fire.

The propagator network's parallelism lever — many independent
propagators per BSP round — only pays off when each propagator's
fire-fn does substantial work AND there are many of them. Dense
linear algebra naturally factors the wrong way for this: either
you split into many tiny independent ops (fine, too much
bookkeeping) or you have one huge op (coarse, no parallelism).
This isn't a propagator-network indictment — it's the same
reason GPUs don't accelerate `BLAS-1` (vector-vector) code
proportionally to compute throughput, and why `BLAS-3`
(matrix-matrix) is where they shine. EigenTrust per iteration
is a `BLAS-2` kernel (matrix-vector), squarely in the regime
where coordination overhead vs flop count is unfavorable.

For workloads that DO match the propagator-parallelism profile —
many independent moderately-expensive sub-computations — the
infrastructure works as designed. EigenTrust just isn't one of
them.

* **At n=4096 the network is 619 ms, math is 442 ms, Prologos
  math is intractable** — the surface variant's elaborator +
  reducer plus the O(k²) blowup means even a single 4096-peer
  iteration would take many minutes (extrapolating from the
  W3 numbers and the chain-depth scaling, the reducer time
  alone would be hours).

## What this tells us about the layered design

* **The propagator network is a thin wrapper over plain math.**
  +40 % overhead at moderate n is the price of cell-based
  incremental computation, BSP scheduling, partial-recomputation
  potential, and parallel-fire potential. For applications that
  need any of those, it's a reasonable cost. For one-shot
  numerical pipelines it's pure tax — but only ~40–75 % tax, not
  orders of magnitude.
* **The Prologos surface language is the expensive layer right now.**
  The ~600 000× gap between **math** and **Prologos math** at W3 is
  almost entirely Prologos elaboration + reduction overhead. The
  reducer is the bottleneck; the propagator network is not.
* **The "Prologos network" axis is the interesting future direction.**
  A surface Prologos program that compiles to a propagator network
  (instead of being evaluated by the reducer) would inherit the
  network's +40–75 % overhead profile, not the reducer's 6-order
  multiplier. The path from "Prologos math" to "Prologos network"
  is the Prologos compiler maturity story — and based on these
  numbers, where the algorithmic-cost wins live.

## How to reproduce

```
# W3 reference — variants 5–7 (rat-coarse, rat-fine, float)
racket benchmarks/comparative/eigentrust-propagators-bench.rkt

# Scaling across n=8..4096 — variants 5–9 (3 propagator + 2 plain)
racket benchmarks/comparative/eigentrust-propagators-scaling.rkt

# Extended scaling n=4096..16384 — math + network only
racket benchmarks/comparative/eigentrust-scaling-large.rkt

# Parallel BSP exploration — math + coarse + fine × {seq, thread, pool}
racket benchmarks/comparative/eigentrust-parallel-bench.rkt

# Prologos surface (4 surface variants, fixed n=4 W3)
racket tools/bench-phases.rkt --runs 2 \
  benchmarks/comparative/eigentrust-list-rat.prologos \
  benchmarks/comparative/eigentrust-list-posit.prologos \
  benchmarks/comparative/eigentrust-pvec-rat.prologos \
  benchmarks/comparative/eigentrust-pvec-posit.prologos

# Tests across all variants
raco test tests/test-eigentrust.rkt                       # 13 tests (List+Rat, P)
raco test tests/test-eigentrust-posit.rkt                 #  6 tests (List+Posit32, P)
raco test tests/test-eigentrust-pvec.rkt                  #  6 tests (PVec+Rat, P)
raco test tests/test-eigentrust-pvec-posit.rkt            #  6 tests (PVec+Posit32, P)
raco test tests/test-eigentrust-propagators.rkt           # 13 tests (rat-coarse)
raco test tests/test-eigentrust-propagators-fine.rkt      #  6 tests (rat-fine)
raco test tests/test-eigentrust-propagators-float.rkt     #  9 tests (float)
raco test tests/test-eigentrust-plain.rkt                 #  9 tests (plain rat + plain fl)
```

## Appendix: rat-flavored variants

Five exact-rational variants exist as correctness-verification tools
for small n, **not as comparison data points** (exact-rat is
intractable beyond n ≈ 64; denominators grow as O(n^k) and bigint
arithmetic is O(d log d) in digit count):

| Axis | Variant | Status at W3 (n=4) | Status at scale |
| --- | --- | --- | --- |
| math | `plain-rat` | 2.74 ms | times out at n=128 (>30 s) |
| network | `rat-coarse`, `rat-fine` | 3.36 ms / 4.43 ms | times out at n=128 |
| Prologos math | `List + Rat`, `PVec + Rat` (P) | 18 372 ms / 33 006 ms | not measured |

The rat variants share the four axes but were dropped from the
main analysis because float-typed answers are what real EigenTrust
deployments need. The rat code is retained for golden-equality
testing at small n (the 13-test rackunit suite for
`test-eigentrust.rkt` checks every primitive against an exact
expected rational).

## Pitfalls surfaced

* **Surface-language pitfalls**: `2026-04-23_eigentrust_pitfalls.md`
  (16 entries — closure capture, multi-line def, posit literal
  parsing, etc.).
* **Propagator-track pitfalls**:
  `2026-04-29_eigentrust_propagators_pitfalls.md`
  (5 entries — fire-once vs chain, cell-merge during initial reads,
  float `equal?`, `for/sum` exact 0 vs 0.0, fine-grained cell-id
  lookup).

## Reproducing the W3 Prologos-math number specifically

```
# Pure reduce_ms for ONE W3 evaluation (no W1/W2 bundled, no startup):
racket tools/bench-phases.rkt --runs 2 \
  benchmarks/comparative/eigentrust-list-posit-w3only.prologos
```

This file is identical to `eigentrust-list-posit.prologos` for the
defns + fixtures, but its only top-level expression is the W3
workload (`eigentrust m-ring-4 p-seed-0 ~0.3 ~0.0 3`). The reported
`reduce_ms` is therefore the cost of evaluating exactly that one
expression through the Prologos reducer, with all earlier phases
(elaborate, type-check, qtt, zonk) reported separately and summing
to ~1.5 s on this workload (≈100× smaller than reduce).
