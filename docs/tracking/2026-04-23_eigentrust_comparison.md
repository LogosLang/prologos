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

## Performance

Measured 2026-04-23 on the machine that built this repo's Racket 9.0.
Three runs per variant plus one warmup, reported as median.

### Wall time (initial view, misleading)

| Variant        | median wall | vs list+rat |
| -------------- | ----------: | ----------: |
| list + rat     |    47.66 s  |      0.0 %  |
| list + posit32 |    44.86 s  |     −5.9 %  |
| pvec + rat     |    44.32 s  |     −7.0 %  |
| pvec + posit32 |    44.78 s  |     −6.0 %  |

On its face this suggests PVec+Rat wins and Posit32 gives a modest
edge. But wall time is a poor signal here because each run is a cold
start that spends most of its time outside user code.

### Phase breakdown (the real story)

Obtained via `tools/bench-phases.rkt` which parses the
`PHASE-TIMINGS:{json}` that `driver.rkt` already emits to stderr, and
aggregates medians across runs. All numbers are median ms of 3 runs.

| Variant        | wall   | elaborate | type_check | qtt  | reduce     | all user | outside (prelude+startup) |
| -------------- | -----: | --------: | ---------: | ---: | ---------: | -------: | -----------------------:  |
| list + rat     | 47 657 |      109  |       372  | 105  |    **250** |    837   |               46 820      |
| list + posit32 | 44 856 |      104  |       337  |  91  |    **245** |    778   |               44 078      |
| pvec + rat     | 44 319 |      109  |       311  | 108  |  **1 144** |  1 673   |               42 646      |
| pvec + posit32 | 44 779 |      111  |       314  | 105  |  **1 134** |  1 665   |               43 114      |

The `reduce_ms` column is the algorithm runtime (Prologos's reducer
evaluating the W1–W7 workload); everything else is compile-time work
or fixed-cost overhead.

Observations:
* **~95–98 % of wall time is "outside phases"**: prelude load, Racket
  startup, I/O. This is a fixed cost independent of the variant.
  Wall-time comparisons are dominated by noise in this bucket.
* **All four variants elaborate in ~800–1 700 ms.** Elaboration cost
  is nearly identical across (container, scalar) combinations —
  `elaborate_ms` is ~110 ms in all four; `type_check_ms` is 310–370
  ms in all four. The container and scalar choice do not
  materially change elaboration cost for this algorithm.
* **Algorithm runtime (`reduce_ms`) tells a totally different story
  than wall time:**
  - List + Rat: 250 ms (baseline)
  - List + Posit32: 245 ms (2 % faster than List+Rat — posit and
    rat are essentially equivalent here because the workloads
    converge in one step, so only ~8 arithmetic ops per workload
    actually fire)
  - PVec + Rat: **1 144 ms — 4.6× slower than List+Rat**
  - PVec + Posit32: **1 134 ms — 4.5× slower than List+Rat**
* The **PVec variants are substantially slower at the algorithm
  level**, despite being faster at wall time. The wall-time win
  was noise in prelude/startup; the algorithm itself pays for
  index-based access and `pvec-push`-per-element accumulator
  construction, which costs ~900 ms more than structural
  list-recursion at n=3 and n=4. PVec's `O(log₃₂ n)` asymptotic
  advantage doesn't pay off until much larger n.
* **Posit32 vs Rat at the algorithm level is a wash** for these
  workloads — within 5 ms in both containers. The workloads all
  converge in one iteration so only a handful of arithmetic ops
  fire. For iter-budget-driven workloads (disabled because of
  pitfall #11) the picture would likely differ — but those don't
  complete for Posit32 at all.
* The `bench-ab.rkt` framework timed out (20 min budget) trying to
  do full A/B stability across all 4 benchmarks: the per-run
  overhead plus its git-stash/checkout cycle ate the budget, and
  it wouldn't have given phase data anyway. `tools/bench-phases.rkt`
  is the right tool for phase-level comparison.

### What this implies for the "which is fastest?" question

* **If the question is wall time** (someone clicks a button and
  waits): all four are within 5 s of each other, dominated by
  fixed-cost startup. Pick based on ergonomics.
* **If the question is algorithm runtime** (amortised across many
  calls, e.g. running from the REPL with the prelude already
  loaded): **List + Rat (or List + Posit32) wins 4.5× over PVec**
  at these matrix sizes. PVec is the wrong data structure for
  small-n matrix algebra in Prologos right now.
* **If the question is scalability**: none of these have been
  tested at larger n because the lazy-argument-reduction issue
  (pitfall #11) makes deep iteration infeasible for all variants.

## When to pick which

* **List + Rat** — correctness-first: exact arithmetic, golden-output
  testing is trivial. **Also the fastest algorithm runtime** per
  `tools/bench-phases.rkt`. The canonical reference implementation.
  Limited to small matrices (denominators compound across deep
  iterations).
* **List + Posit32** — hardware-speed arithmetic, statistically tied
  with List + Rat on `reduce_ms` here (250 vs 245 ms). The `~0.0`
  literal is immune to the `0/1 → Int 0` reader quirk, which is a
  nice ergonomic win. But Prologos's lazy argument reduction makes
  the iteration loop unusable for non-converging workloads (§11 in
  pitfalls doc).
* **PVec + Rat** — ~4.6× slower algorithm runtime than List + Rat
  at n=3 and n=4, despite identical elaboration cost. The
  index-based `-go` helpers + `pvec-push` accumulator construction
  have higher constants than structural list recursion for small n.
  PVec would pay off only at much larger n (and probably requires
  `pvec-nth-int` / `pvec-zip-with` primitives to be competitive).
* **PVec + Posit32** — same 4.5× algorithm-runtime penalty as
  PVec + Rat. Only useful as the fourth corner of the grid for
  comparison.

## How to run the phase-breakdown yourself

```
racket tools/bench-phases.rkt --runs 3 \
  benchmarks/comparative/eigentrust-list-rat.prologos \
  benchmarks/comparative/eigentrust-list-posit.prologos \
  benchmarks/comparative/eigentrust-pvec-rat.prologos \
  benchmarks/comparative/eigentrust-pvec-posit.prologos
```

The tool is ~170 lines. It shells out to `racket driver.rkt FILE`
N times per program, greps the cumulative `PHASE-TIMINGS:{json}`
that `process-file` emits to stderr, and computes the median of
each phase across runs. No modification to the algorithm files,
no edits to `driver.rkt` — all the data was already being emitted,
just not aggregated. See `tools/bench-phases.rkt` for details.

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
