# EigenTrust in Prologos — 4-way Implementation Comparison

_Session 2026-04-23 addendum. The initial EigenTrust implementation
was List + exact Rat. This doc compares four variants across the
`{List, PVec} × {Rat, Posit32}` grid to make performance and
ergonomics tradeoffs visible._

## The four variants

| Container / Scalar | File                                           | Test file                            | Benchmark                              |
| ------------------ | ---------------------------------------------- | ------------------------------------ | -------------------------------------- |
| List + Rat         | `examples/eigentrust.prologos`                 | `tests/test-eigentrust.rkt`          | `benchmarks/.../eigentrust-list-rat`    |
| List + Posit32     | `examples/eigentrust-posit.prologos`           | `tests/test-eigentrust-posit.rkt`    | `benchmarks/.../eigentrust-list-posit`  |
| PVec + Rat         | `examples/eigentrust-pvec.prologos`            | `tests/test-eigentrust-pvec.rkt`     | `benchmarks/.../eigentrust-pvec-rat`    |
| PVec + Posit32     | `examples/eigentrust-pvec-posit.prologos`      | `tests/test-eigentrust-pvec-posit.rkt` | `benchmarks/.../eigentrust-pvec-posit`  |

## Shared benchmark workload

All four benchmarks run the same workload (W1–W7):

1. `eigentrust c-uniform-4 p-uniform-4 α ε 50` — convergence on a 4×4 uniform stochastic matrix.
2. `eigentrust c-others-3 p-uniform-3 α ε 50` — convergence on a 3×3 symmetric "uniform-on-others" matrix.
3. `eigentrust-step c-uniform-4 p-uniform-4 α p-uniform-4` — one step operator on 4×4 uniform.
4. `ct-times-vec c-uniform-4 p-uniform-4` — one matrix-vector multiply.
5. `scale-vec s v` — scalar-vector multiply on a 3-element vector.
6. `add-vec v v` — elementwise add on a 2-element vector.
7. `linf-norm (sub-vec a b)` — difference norm on a 2-element vector.

The two `eigentrust` workloads both converge after one step (the
iterator's `ε > 0` convergence test exits immediately), which keeps
all four variants in the same ~40–50 s envelope. See the pitfalls doc
(§11) for why iter-budget-driven workloads are unsafe to compare here.

## Ergonomic differences

| Concern                                       | List + Rat                          | List + Posit32    | PVec + Rat                      | PVec + Posit32    |
| --------------------------------------------- | ----------------------------------- | ----------------- | ------------------------------- | ----------------- |
| Matrix literal for zero element               | Needs `rz : Rat := 0/1` splice      | `~0.0` direct     | `0/1` direct in `@[...]`         | `~0.0` direct     |
| Primitive operators passable to higher-order? | No (gotcha #1)                      | No                | No                              | No                |
| Closure in `map`/`pvec-map`?                  | QTT multiplicity error (#2)         | Same              | Same                            | Same              |
| Indexing type                                 | List has `nth-int` (Int-indexed)    | Same              | PVec is Nat-only (#12)          | Same              |
| Element-wise zip                              | `zip-with` exists (but see #1)      | Same              | No `pvec-zip-with` → index loops (#13) | Same          |
| Lines of prim helpers                         | ~60                                 | ~60               | ~120 (extra `-go` functions)    | ~120              |
| Source file size                              | 234 LOC                             | 192 LOC           | 176 LOC                         | 176 LOC           |

## Performance (3 direct runs of `racket driver.rkt FILE.prologos`)

Measured 2026-04-23 on the machine that built this repo's Racket 9.0.
Each run is a cold start: prelude load + user-code elaboration +
example evaluation. Most of the wall time is prelude + elaboration
(~40 s); the actual EigenTrust workload is the tail ~3–5 s.

| Variant        | run 1   | run 2   | run 3   | median  | vs list+rat |
| -------------- | ------: | ------: | ------: | ------: | ----------: |
| list + rat     | 47.28 s | 47.91 s | 48.01 s | 47.91 s |      0.0 %  |
| list + posit32 | 45.45 s | 46.04 s | 44.07 s | 45.45 s |     −5.1 %  |
| pvec + rat     | 43.94 s | 42.95 s | 43.58 s | 43.58 s |     −9.0 %  |
| pvec + posit32 | 44.88 s | 43.57 s | 46.51 s | 44.88 s |     −6.3 %  |

Observations (careful — these wall times are dominated by ~40 s of
fixed-cost elaboration; the variable algorithm cost is a few seconds):
* List + Rat is the slowest. Exact rational arithmetic on nested
  lists is the reference baseline.
* Posit32 alone (same List container) saves ~2.5 s — consistent with
  the expectation that `p32+/-/*` is a single hardware op vs Rat's
  numerator/denominator simplification.
* PVec wins over List despite the index-based inner loops. The RRB
  tree is presumably cheaper to reduce than chains of `cons` cells
  for the workload sizes here (n=3 and n=4).
* PVec + Posit32 is NOT strictly the fastest — it's within noise of
  PVec + Rat and slightly slower than PVec alone. Possibly the
  Posit32 reducer has higher per-op overhead than Rat on these
  small vectors where denominators stay small. With larger matrices
  or deeper iteration the ordering would likely flip.
* The bench-ab.rkt framework timed out (20 min budget) trying to do
  the full A/B stability test across all 4 benchmarks — the per-run
  overhead plus git-stash/checkout cycle ate the budget. Direct
  timing is used instead.

## When to pick which

* **List + Rat** — correctness-first: exact arithmetic, golden-output
  testing is trivial. Limited to small matrices (denominators compound
  across deep iterations). The canonical reference implementation.
* **List + Posit32** — hardware-speed arithmetic, but Prologos's lazy
  argument reduction makes the iteration loop unusable for
  non-converging workloads (§11 in pitfalls doc). For converging
  cases it's as fast as Rat and has cleaner literals.
* **PVec + Rat** — if the algorithm needed `O(log n)` random access
  (e.g. gradient descent with sparse updates), PVec would win. For
  this algorithm (linear scans of small vectors) the extra `-go`
  helpers add overhead for no asymptotic benefit.
* **PVec + Posit32** — same inheritance: PVec's index-loop style +
  Posit's lazy-reduction issue. Useful only as the fourth corner of
  the grid for comparison.

## Lessons / pointers

* Bracket discipline (from `prologos-syntax.md`): sub-expression
  applications need `[...]`, but tail-position applications at the
  end of a `defn` or match arm can be bare. The four files here
  follow this minimal-bracket style consistently.
* The `eigentrust` entry point seeds the iterator with one `step`
  call so the `(t, tnew)` pair is well-defined from round 1. This
  single-function loop avoids both mutual recursion (not supported
  in Prologos, #4) and the broken WS-mode `let` (#5).
* For every new combination (new scalar type, new container) there
  are 2–3 fresh elaboration-level papercuts. Documented in the
  pitfalls doc.
