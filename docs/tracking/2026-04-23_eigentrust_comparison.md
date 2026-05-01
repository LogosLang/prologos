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
| **Prologos math** (List + Posit32) | 17 990 | **~600 000×** | Surface language, evaluated by Prologos's reducer. |
| Prologos network  |        —  |     —     | _doesn't exist yet_. |

The 6-orders-of-magnitude gap between **math** and **Prologos math**
is the cost of the Prologos surface language + reducer on a hot
path: term-tree walks, pattern-match dispatch, pretty-printing,
no flonum specialization, plus the O(k²) reduce-tree blowup
(see `2026-04-23_eigentrust_pitfalls.md` §11) that makes deeper
iteration progressively more expensive.

The **network** vs **math** gap is small in absolute terms (~70 µs
per call) and dominated by per-iteration constant cost (cell
allocation, BSP round dispatch, fire-fn invocation, CHAMP path
copies on each cell-write). It amortizes as n grows — see scaling
below.

## Scaling across n — math vs network

Only the float-typed variants (math, network) are measured at large
n. The Prologos surface variants take ~60 s of fixed overhead per
run (Prologos prelude load + Racket startup) and the fixture
generators are surface code, so a Prologos-surface-at-large-n bench
is a separate piece of work. Today's data is the Racket-direct
side.

`benchmarks/comparative/eigentrust-propagators-scaling.rkt` —
K=4, 30 s per-sample timeout, median of 3 runs.

| n    | math (plain-fl) | network (float) | network overhead |
| ---: | -------------: | --------------: | ---------------: |
|    8 |        0.03 ms |         0.12 ms |          +300 %  |
|   16 |        0.03 ms |         0.14 ms |          +367 %  |
|   32 |        0.05 ms |         0.16 ms |          +220 %  |
|   64 |        0.09 ms |         0.28 ms |          +211 %  |
|  128 |        0.27 ms |         0.57 ms |          +111 %  |
|  256 |        0.99 ms |         2.10 ms |          +112 %  |
|  512 |        4.59 ms |         9.00 ms |           +96 %  |
| 1024 |       19.40 ms |        33.86 ms |           +75 %  |
| 2048 |       88.37 ms |       151.62 ms |           +72 %  |
| 4096 |      442.14 ms |       619.37 ms |           +40 %  |

### What the scaling shows

* **Math scales ~O(n²)** as expected for K rounds of n×n mat-vec.
  Doublings of n give ~3.5–5× time growth past the cache-resident
  regime (n ≥ 128).
* **Network adds a roughly constant absolute overhead per call.**
  At n=8 the overhead is most of the time (0.09 ms of overhead vs
  0.03 ms of math). At n=4096 it's 40 % (177 ms of overhead vs
  442 ms of math). The overhead amortizes against per-fire work
  but doesn't disappear — it asymptotes to "the cost of K BSP
  rounds with K cell-writes of large flvectors", which is roughly
  per-cell-write CHAMP path-copies + scheduler bookkeeping.
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
