# Lowering Perf Suite — design + program inventory
**Date**: 2026-05-02
**Track**: lowering-yolo (continuation)
**Branch**: `lowering-yolo`
**Tool**: `tools/bench-lowering.rkt`
**Programs**: `racket/prologos/benchmarks/lowering/*.prologos`

## 1. What this suite is for

Two intertwined goals, both at the .prologos source level:

  1. **Correctness**: every program in the suite must compile cleanly
     and the resulting native binary's exit code must match the
     program's `:expect-exit` annotation. The suite is also a
     regression gate: a future change to the lowering pipeline that
     produces wrong answers fails here loudly.

  2. **Performance**: for each program, measure compile time,
     end-to-end native wall time (across N runs), and — when the
     program reaches the BSP scheduler — kernel-side ns / iter,
     fires, rounds, cells, props.

There is a deliberate mix of:

  - **Static-folded programs** (Gate 2 / Gate 1 rev 1.5 / Gate 3 /
    Gate 4) whose runtime is dominated by LLVM startup (~5-6 ms on
    macOS). These verify that the lowering pipeline reduces them to
    a single literal cell and that the literal value is correct.

  - **Propagator-network programs** (tail-rec with multi-leaf state)
    that DO exercise the kernel BSP scheduler. These are the real
    perf measurements: ns/fire, ns/round, ns/iter.

## 2. Departures from the previous bench-{native,suite}.rkt

The old harness:

  - swept `N ∈ {10, 40, 100, 400, 1000}` per algorithm, generating
    Prologos source on-demand from `tools/gen-fib.rkt` (unrolled let-
    binding chains) and `tools/gen-iter.rkt` (tail-rec patterns), and
  - separated "unrolled" (hand-rolled) and "iterative" forms for the
    same algorithm.

The new harness:

  - has **no N-sweep** — each program ships at one fixed input size,
    chosen to be representative of its category;
  - uses **only checked-in `.prologos` source files** (no on-the-fly
    generation, no hand-rolled propagator-network skeletons); and
  - treats **correctness as a first-class column** — a program that
    runs in 6 ms but returns the wrong exit code is a `FAIL`, not a
    `PASS`.

Removed files (this commit):

  - `tools/bench-native.rkt`
  - `tools/bench-suite.rkt`
  - `tools/gen-fib.rkt`
  - `tools/gen-iter.rkt`

## 3. Program inventory

12 programs, organized by which lowering feature each exercises.

### Group A — Tail-rec with pair-state (RUN through BSP)

These programs do NOT static-fold (pair construction is opaque to
the static-eval pass). They allocate a small fixed network and
iterate it in the kernel.

| File | What it tests |
|---|---|
| `01-tailrec-pair-fib-30.prologos` | Iterative fib(30) via pair-state. Canonical "real runtime" benchmark. ~92 BSP rounds, 14 cells. |
| `02-tailrec-helpered-fib-30.prologos` | fib(30) with two-level helper inlining (Sprint F.1). Same network shape as 01 — verifies inlining composes cleanly. |
| `03-tailrec-pell-15.prologos` | Pell(15). Depth-2 step expression `[int+ [int* 2 b] a]`; tests Sprint F.5's per-propagator alignment + pre-select uniform lift. |
| `04-tailrec-dual-acc-8.prologos` | Pair-state tail-rec computing `(sum 1..N + product 1..N)`. Two simultaneously-evolving leaves per iteration. |

### Group B — Static-folded (verify compile-time reduction)

These programs lower to a single literal cell at compile time.
Their wall time is ~LLVM startup (~5-6 ms); their exit code MUST
match `:expect-exit` for the fold to be considered correct.

| File | What it tests |
|---|---|
| `05-fold-fib-non-tail-15.prologos` | Non-tail-recursive fib(15). Gate 2 (PReduce-as-static-eval) over a branching factor 2 recursion. |
| `06-fold-factorial-non-tail-7.prologos` | Non-tail-recursive 7!. Gate 2. |
| `07-fold-list-sum-10.prologos` | 10-cell `cons` list summed by a non-tail recursive `sum-list`. Combined Gate 1 rev 1.5 (recursive ctor + match folding) + Gate 2 (recursion folding). |
| `08-fold-tree-sum-balanced-4.prologos` | Balanced binary tree, 4 leaves. Two-recursive-field constructor (`branch : Tree A -> Tree A`) — exercises the binding-order fix shipped with rev 1.5. |
| `09-fold-bool-truth-table.prologos` | Compound expression of `and / or / xor / not / implies` from `prologos::data::bool`. Gate 4 functional sub-gate. |
| `10-fold-string-pipeline.prologos` | `length (append (append "ab" "cde") "fg")`. Gate 3 (compile-time foreign-call folding) over a chain of foreign calls. |
| `11-fold-nested-maybe-cascade.prologos` | Three-level nested `Maybe` literal matched by a triple-nested cascade. Gate 1 rev 1.5, single-field ctor, max-depth fanout. |

### Group C — Combined showcase

| File | What it tests |
|---|---|
| `12-showcase-tailrec-and-bool.prologos` | Tail-rec pair-fib feeds its result into a Bool comparison + match dispatch. Tail-rec subgraph + comparison + match are wired into a single propagator network. |

## 4. Sample report

A typical run with `--runs 5` looks like:

```
| Program | Compile ms | Wall min/avg/max ms | Kernel ns/iter | Cells | Props | Rounds | Exit | OK |
|---|---|---|---|---|---|---|---|---|
| `01-tailrec-pair-fib-30.prologos`     | 2909 | 5.1 / 7.3 / 11.4 | 1.6ms | 14 | 12 | 92 | 40/40   | ✓ |
| `02-tailrec-helpered-fib-30.prologos` | 2942 | 5.2 / 5.3 / 5.4  | 1.3ms | 14 | 12 | 92 | 40/40   | ✓ |
| `03-tailrec-pell-15.prologos`         | 2872 | 5.3 / 5.4 / 5.5  | 1.1ms | 21 | 18 | 63 | 209/209 | ✓ |
| `04-tailrec-dual-acc-8.prologos`      | 2866 | 5.2 / 5.3 / 5.4  | 608μs | 16 | 14 | 26 | 164/164 | ✓ |
| `05-fold-fib-non-tail-15.prologos`    | 2957 | 5.6 / 5.7 / 5.8  | 0ns   |  1 |  0 |  0 |  98/98  | ✓ |
| `06-fold-factorial-non-tail-7.prologos`| 2922 | 5.2 / 5.6 / 5.8  | 0ns   |  1 |  0 |  0 | 176/176 | ✓ |
| `07-fold-list-sum-10.prologos`        | 2941 | 5.6 / 5.7 / 5.9  | 0ns   |  1 |  0 |  0 |  55/55  | ✓ |
| `08-fold-tree-sum-balanced-4.prologos`| 2947 | 5.3 / 5.6 / 5.7  | 0ns   |  1 |  0 |  0 |  10/10  | ✓ |
| `09-fold-bool-truth-table.prologos`   | 2885 | 5.3 / 5.6 / 5.8  | 0ns   |  1 |  0 |  0 |   1/1   | ✓ |
| `10-fold-string-pipeline.prologos`    | 2872 | 5.7 / 5.7 / 5.8  | 0ns   |  1 |  0 |  0 |   7/7   | ✓ |
| `11-fold-nested-maybe-cascade.prologos`| 2902 | 5.4 / 5.5 / 5.8  | 0ns   |  1 |  0 |  0 |   7/7   | ✓ |
| `12-showcase-tailrec-and-bool.prologos`| 2940 | 5.0 / 5.0 / 5.1  | 2.1ms | 35 | 28 | 62 |  65/65  | ✓ |

PASS: 12 / 12, FAIL: 0 / 12.
Static-folded: 7 programs.
Propagator-network: 5 programs.
```

## 5. What the columns mean

  - **Compile ms** — wall time of the `pnet-compile` subprocess
    (parse → elaborate → ast-to-low-pnet → low-pnet-to-llvm →
    `clang` link). Dominated today by Racket startup + module load
    (~2.5 s) and `clang` invocation; the lowering pipeline itself
    is sub-second on every program in the suite.

  - **Wall min/avg/max ms** — end-to-end wall time for invoking
    the produced binary (5 runs after one warm-up). For static-
    folded programs this is essentially LLVM startup + `atexit`;
    for propagator-network programs it's startup + (kernel work).

  - **Kernel ns/iter** — `run_ns / iter_count` from the kernel's
    PNET-STATS line, average across runs. This is the real per-
    iteration cost of the BSP scheduler — the most resilient
    cross-machine perf number, since it excludes process startup.
    Reported as `0ns` for static-folded programs (no iteration).

  - **Cells / Props / Rounds** — propagator-network metrics from
    PNET-STATS. `Cells = 1, Props = 0, Rounds = 0` is the static-
    fold signature.

  - **Exit / OK** — `actual / expected` exit code; `✓` means every
    measured run matched, `✗` means at least one diverged.

## 6. Running the suite

  ```sh
  racket tools/bench-lowering.rkt                # default --runs 5
  racket tools/bench-lowering.rkt --runs 10
  racket tools/bench-lowering.rkt --filter tailrec
  racket tools/bench-lowering.rkt --out /tmp/bench.md
  racket tools/bench-lowering.rkt --run-timeout 30 --compile-timeout 120
  ```

The harness exits non-zero if any program fails correctness or hits
a timeout. Suitable for CI gating; consider adding it to
`.github/workflows/benchmark.yml` once perf-band thresholds are
established.

## 7. Design choices and trade-offs

  - **Why drop the N-sweep?** Most algorithms in the previous suite
    static-folded to a literal regardless of N (Gate 2 lifted the
    runtime cost to compile time). The N-sweep was reporting LLVM
    startup overhead in 5 different rows; one row is enough to
    convey that. For the propagator-network programs, the N value
    is fixed at a "representative" size (30 for fib, 15 for Pell,
    8 for dual-acc) — large enough to amortize overhead but small
    enough to keep wall time under 100 ms.

  - **Why keep `01` and `02` if they have the same network shape?**
    `02` exercises Sprint F.1 helper inlining; `01` does not. They
    should produce the same network — and the bench confirms that
    (same cell / prop / round counts). A future regression that
    inlines incorrectly would surface as divergence here.

  - **Why no programs that intentionally fail?** Negative tests live
    in the unit test suite (`racket/prologos/tests/test-ast-to-low-
    pnet.rkt`). The bench suite is for things that ship.

  - **Why not measure LLVM IR size?** Could be added to a future
    column. The current focus is wall time + correctness.

## 8. Adding a program

To add a new program to the suite:

  1. Create `racket/prologos/benchmarks/lowering/NN-<category>-<name>.prologos`.
     Use a 2-digit numeric prefix to control sort order in the report.
  2. Include an `;; :expect-exit N` comment somewhere in the file.
     The harness reads this to check correctness.
  3. Run `racket tools/bench-lowering.rkt --filter <name>` to verify
     the program compiles and runs correctly.
  4. (Optional) Add a row to the table in section 3 of this doc.

The categorization (folded vs propagator-network) is derived
automatically from `Cells = 1, Rounds = 0` — no manual tagging.

## 9. What's deliberately NOT in this suite

  - **Hand-rolled propagator-network skeletons** (the old `gen-fib.rkt`
    pattern of nested `[(fn [a0] ...) 0]` chains). These bypass the
    elaborator's normal recursion-lowering paths and don't represent
    realistic Prologos source. The runtime tests for that shape live
    in `runtime/test-bsp-feedback.c`.

  - **Micro-benchmarks of internal kernel APIs** (e.g., scope_enter
    cycles). Those live in `runtime/bench-scope-enter.c` and the
    `racket/prologos/benchmarks/micro/` directory.

  - **Cross-language comparisons** (e.g., Prologos vs. Racket vs.
    C). Out of scope for the lowering perf track; could be added as
    a separate `bench-comparative.rkt` later.

  - **Allocator pressure / heap profiling**. The current lowering
    targets are scalar-only at runtime (no heap), so there's nothing
    to profile yet. Becomes relevant once Gate 1 rev 2 (heap
    recursive ctors) ships.
