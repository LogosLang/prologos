# Lowering: argv input + stdout output (Designs A + C)

Status: design accepted; implementation in progress.
Branch: `lowering-yolo`.
Author: lowering-yolo session, 2026-05-02.

## Problem

The lowering perf suite (`tools/bench-lowering.rkt`) reports `Rounds=0`
for 7 of 12 benchmarks. Static-eval (Gate 2) folds any closed-form
program at compile time, leaving only the LLVM-emitted constant in
`@main`. The reported wall time for those rows is binary startup cost,
not kernel throughput.

Root cause: every program in the suite has a closed `def main`. The
elaborator sees no opaque inputs, so `try-static-eval`'s `lit-env`
never contains a non-folded sentinel, and the entire body collapses
to a literal.

We need a way to feed an opaque value into `main` at runtime so the
kernel actually has to compute. Symmetrically we need a way to *print*
results larger than 8 bits, so we can validate `fib(30) = 832040`
instead of `fib(30) mod 256 = 40`.

## Solution: parameterised main + stdout printing

Two complementary additions:

### Design A — parameterised `main`

Allow `def main : Int -> Int := λx. body`. Treat `x` the same way C
treats `int main(int argc, char** argv)`: a runtime-bound value that
the elaborator must not fold through.

Plumbing:

- `@main` becomes `i32 @main(i32 %argc, i8** %argv)`.
- One designated *input cell* per main-parameter, allocated up-front
  with init=0.
- A new runtime helper `prologos_argv_i64(argv, idx) -> i64` parses
  one decimal integer from `argv[idx]` and the lowering pass emits a
  `prologos_cell_write` to the input cell with that value, *before*
  `prologos_run_to_quiescence`.

Static-eval interaction:

- The existing `'unknown` sentinel in `lit-env` already returns
  `UNFOLDABLE` from `try-static-eval-impl`. Seeding the top-level
  `current-static-env` with `'unknown` per main-parameter is sufficient
  — UNFOLDABLE bubbles through `static-bin`, `try-eval-ctor-app`, and
  `try-eval-sctor-arm`.

### Design C — stdout printing

Add `prologos_print_i64(value: i64) -> void` to the runtime. Emit a
call after `prologos_cell_read` of the entry cell, before `ret`. The
process still exits with the same value (for back-compat with existing
`:expect-exit` benchmarks), but the *full* i64 result is also printed
to stdout, suffixed with a newline, with no other framing.

Why both: A alone defeats static-eval, but exit codes are still
masked to a u8. C alone gives full results but doesn't help us
exercise the kernel. Together they let us write benchmarks like
`fib(N)` that take their input on the command line and print the
exact 64-bit answer.

## Out of scope (deferred)

- Multi-argument `main` (>1 parameter). Single-arg covers every
  benchmark we want to convert and removes the need to design how
  argv parsing handles errors per-slot.
- Generic `foreign input` declarations (Design D from the discussion
  thread). Worth doing once we have a non-benchmark consumer.
- stdin reads. Same plumbing as argv but adds a libc dependency and
  composes worse with shell scripting (have to pipe).
- Real input types other than Int. `bool` could come for free
  (parse "true"/"false") but no benchmark needs it; defer.

## IR encoding

No new IR node. Reuse the existing `meta-decl` mechanism:

  (meta-decl main-arity 1)
  (meta-decl input-cell-0 17)   ; cell-id 17 receives argv[1]

The lowering pass scans for these, generates the argv-walking code,
and emits one `prologos_cell_write(input-cell-id, parsed-value)` per
input cell before quiescence. Choosing meta-decls over a new
`input-decl` IR node keeps the IR backward compatible — all existing
.pnet fixtures remain byte-stable, the validator needs no V13 rule.

Output: signaled by `(meta-decl main-prints-result #t)`. When present,
the LLVM emitter inserts the `prologos_print_i64` call. Always emitted
when the lowering pass detects parameterised main; manually-authored
.pnet fixtures (with no main-arity meta) keep the existing exit-code-only
behavior.

## Validation strategy

1. **Runtime unit tests**: Zig kernel tests for `prologos_argv_i64`
   (positive, negative, leading whitespace, garbage) and
   `prologos_print_i64` (zero, positive, negative, max/min i64).
2. **Lowering unit tests**: round-trip + LLVM emission tests assert
   the new meta-decls + their lowered `@main` shape.
3. **End-to-end**: a new benchmark `13-argv-fib-N.prologos` parameterised
   on `n`, run at n ∈ {10, 30, 50}, validates printed output equals
   the expected fib value.
4. **Static-eval inhibition**: explicit unit test: feed
   `λx. [int+ x 1]` through `ast-to-low-pnet`, assert the resulting
   IR has a propagator (i.e., did NOT fold to a literal).
5. **Backwards compat**: every existing benchmark continues to
   compile, link, exit-code-validate. The `bench-lowering.rkt` harness
   accepts both legacy `:expect-exit N` and new `:inputs … :expect-stdout-for …`
   annotations.

## Implementation sequencing

Each milestone is one commit.

1. **M1 (runtime)**: Add `prologos_argv_i64` + `prologos_print_i64`
   to `runtime/prologos-runtime.zig`. Add unit tests. Build the
   `.o`. Verify exports via `nm`.
2. **M2 (IR)**: Document the new meta-decl keys; no struct changes
   needed but the round-trip golden fixtures get refreshed to assert
   they survive.
3. **M3 (ast-to-low-pnet)**: Detect parameterised main, allocate input
   cells, seed `'unknown` static env, emit meta-decls. Add unit tests
   that assert static-eval was inhibited.
4. **M4 (low-pnet-to-llvm)**: Recognise the meta-decls, change `@main`
   signature, emit `prologos_argv_i64` writes, emit `prologos_print_i64`
   call. Add LLVM-IR-text unit tests.
5. **M5 (driver)**: Update `pnet-compile.rkt` to allow parameterised
   main and propagate the input args to the run step.
6. **M6 (benchmarks)**: Rewrite `01..06, 08, 12` to take their input
   on the command line. Keep `09..11` (string / bool / nested-Maybe)
   in folded form — they demonstrate the optimiser, which is a
   feature.
7. **M7 (harness)**: Extend `bench-lowering.rkt` to parse `:inputs`
   and `:expect-stdout-for` annotations and sweep across input sizes.
   Capture stdout, validate against expected values.
8. **M8 (CI)**: Wire the new argv benchmarks into
   `.github/workflows/network-lower.yml`.

## Open questions

None at this time. The Pi/lambda peeling for parameterised main has
one ambiguity (curried multi-arg vs. tupled single-arg), resolved by
the "single argument only" scope decision.

## Acceptance

- `racket tools/bench-lowering.rkt` shows non-zero `Rounds` for the
  argv-driven benchmarks at non-trivial input sizes.
- The static-fold benchmarks still report `Cells=1, Props=0, Rounds=0`
  — they're a regression gate for the optimiser.
- All 65 round-trip-acceptance examples continue to pass.
- All Gate 1/2/3/4 native-binary CI checks (n8 through n12) continue
  to pass.
- New Zig runtime tests pass (`zig test runtime/prologos-runtime.zig`).
