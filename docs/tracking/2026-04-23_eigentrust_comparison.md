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
Medians across 2 measured runs (plus one warmup) via
`tools/bench-phases.rkt`, which parses the `PHASE-TIMINGS:{json}` line
that `driver.rkt` already emits on stderr.

**First-round disclaimer.** An earlier version of this doc reported
PVec as 4.6× *slower* than List. Those numbers were an artifact of
pitfall #15 in the pitfalls doc: the benchmark fixtures used multi-line
`def c-asym-3 : TYPE \n := BODY` syntax, which silently suppresses
evaluation of downstream top-level expressions. The W3 workload
(3 forced iterations of power iteration) never actually ran, so
`reduce_ms` reflected only the trivial converging W1/W2 workloads.
After collapsing every `def` to one physical line, real reduce times
reveal the opposite conclusion.

### Workloads

Every benchmark runs the same W1..W8 set:
* **W1.** `eigentrust c-uniform-4 p-uniform-4 α=1/10 ε=1/1000 50` —
  uniform matrix; converges in one step (uniform is the fixed point).
* **W2.** `eigentrust c-others-3 p-uniform-3 α=1/10 ε=1/1000 50` —
  symmetric 3×3; uniform is also the stationary distribution.
* **W3.** `eigentrust c-asym-3 p-uniform-3 α=3/10 ε=0 3` — asymmetric
  3×3, forced 3 iterations (`ε=0` prevents convergence). This is the
  workload that dominates `reduce_ms`. `α=3/10` follows the standard
  EigenTrust convention (`t_new = (1−α)·Cᵀt + α·p`): 70% network
  weight, 30% pre-trust anchor. Larger budgets grow the term tree as
  O(k²) in Prologos's reducer (pitfall #11), so k=3 is the sweet spot.
* **W4.** `eigentrust-step c-uniform-4 p-uniform-4 α p-uniform-4`
* **W5.** `ct-times-vec c-uniform-4 p-uniform-4`
* **W6–W8.** `scale-vec`, `add-vec`, `linf-norm ∘ sub-vec` on small
  vectors.

### Phase breakdown

| Variant        | wall  | elaborate | type_check | qtt | reduce      | user sum | outside |
| -------------- | ----: | --------: | ---------: | --: | ----------: | -------: | ------: |
| list + rat     | 86599 |      208  |       748  | 412 | **33 699**  |  35 070  |  51 529 |
| list + posit32 | 87847 |      200  |       664  | 384 | **34 874**  |  36 124  |  51 723 |
| pvec + rat     | 76472 |      138  |       355  | 140 | **22 260**  |  22 896  |  53 576 |
| pvec + posit32 | 78226 |      142  |       334  | 136 | **22 428**  |  23 042  |  55 184 |

All values are median ms of 2 measured runs. The `reduce_ms` column is
the actual algorithm runtime — the reducer evaluating W1..W8.
"outside" is the residual (wall − sum of phases): prelude load +
Racket startup + I/O, roughly constant across variants.

### Observations

* **PVec is ~35 % faster than List on `reduce_ms`** (22 s vs 34 s).
  For the 3-iter workload, the index-based PVec iteration with a
  `pvec-push` accumulator shapes the reducer's work better than
  structural `cons`-chain recursion — the `cons`-chain version
  passes an unreduced `tnew = [eigentrust-step ... (prev-tnew)]`
  that the reducer has to walk deeper on each round.
* **Posit32 vs Rat at `reduce_ms` is within noise** (~3 % difference
  in both containers). At α=3/10 each W3 iteration does roughly 20
  Rat operations; the hardware-posit vs arbitrary-precision-rat gap
  doesn't materially matter for denominators as small as `10×` those
  of the input (α=3/10 means denominators compound only by factor 10
  per step; after 3 steps they're in the thousands — still tiny).
* **Elaboration is cheaper for PVec** (user sum ~23 s vs 35 s) —
  `type_check_ms` halves (334 vs 748) and `qtt_ms` thirds (140 vs
  412). The PVec helpers use `Nat`-indexed counters and build one
  uniform accumulator; the List helpers use nested structural
  patterns that the type/multiplicity checkers work harder on.
* **"outside phases" is ~52 s and near-constant.** Racket startup
  (~2 s) plus Prologos prelude load (~50 s) are the dominant
  costs at any given wall time.

### What this implies for the "which is fastest?" question

* **Wall time** is dominated by the ~52 s prelude-load overhead. All
  four variants complete in 76–88 s. Pick based on ergonomics or
  on an amortised-startup-cost model.
* **Algorithm runtime** (`reduce_ms` — what you'd pay per call in a
  REPL with the prelude already loaded): **PVec beats List by
  ~1.5× at these matrix sizes.** This is the opposite of the
  earlier reading.
* **Container choice matters more than scalar choice.** `list+rat`
  vs `pvec+rat` differs by 11 s of reduce time. `list+rat` vs
  `list+posit32` differs by ~1 s. For this shape of algorithm,
  the data structure dominates.
* **Scalability caveat:** the O(k²) reduce-tree growth (pitfall #11)
  makes budgets larger than 3 impractical for all four variants.
  Real-world EigenTrust runs (hundreds of iterations on thousand-
  peer networks) would need either a strict-tail-recursion
  primitive in Prologos or a compiled implementation.

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
