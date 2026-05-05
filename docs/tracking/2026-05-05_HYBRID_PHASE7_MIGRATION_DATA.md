# Hybrid Kernel Phase 7 — Migration Target Data

**Date**: 2026-05-05
**Scope**: data collection only — no implementation in this commit.
**Branch**: `claude/prologos-layering-architecture-Pn8M9` (post-refactor;
fresh post-D mini-PIR + post-E upstream-OCapN sync)

## Question

Now that the hybrid kernel runs all 12 OCapN programs end-to-end, which
callback shapes consume the most fire-time and are the most attractive
migration targets for the next round of native fire-fns in
`runtime/prologos-runtime-hybrid.zig`?

## Data: per-program profile (12 OCapN programs)

Captured via `dist/prologos-hybrid-bundle/bin/prologos --profile` against
each `examples/ocapn/ocapn-hybrid-N.prologos`. Native = kernel tags 0–7
(int-add, int-sub, int-mul, int-div, int-eq, int-lt, int-le, identity-on-0).
Callback = tag ≥ 8 (Racket fire-fn dispatched via C trampoline).

| prog | nat fires | cb fires | nat ns | cb ns | run ns | distinct cb tags | max fires/tag |
|---|---|---|---|---|---|---|---|
| 1 | 0 | 2 | 0 | 56,932 | 57,847 | 2 | 1 |
| 2 | 0 | 5 | 0 | 42,082 | 42,585 | 4 | 2 |
| 3 | 0 | 6 | 0 | 28,200 | 28,890 | 6 | 1 |
| 4 | 0 | 5 | 0 | 35,273 | 35,720 | 4 | 2 |
| 5 | 0 | 18 | 0 | 146,614 | 148,302 | 18 | 1 |
| 6 | 0 | 16 | 0 | 49,893 | 51,202 | 12 | 2 |
| 7 | 0 | 10 | 0 | 33,816 | 35,255 | 10 | 1 |
| 8 | 3 | 6 | 2,370 | 23,470 | 26,746 | 6 | 1 |
| 9 | 20 | 42 | 744 | 122,111 | 126,284 | 22 | 7 |
| 10 | 0 | 44 | 0 | 169,484 | 171,860 | 32 | 2 |
| 11 | 0 | 4 | 0 | 22,578 | 23,104 | 4 | 1 |
| 12 | 0 | 6 | 0 | 28,710 | 29,221 | 6 | 1 |
| **Σ** | **23** | **164** | **3,114** | **759,163** | **777,016** | — | — |

**Native-fire fraction**: 23 / (23 + 164) = **12.3%** of fires.
**Native-time fraction**: 3,114 ns / 762,277 ns ≈ **0.4%** of in-fire time.

The native path is exercised only by program 8 (single int-add) and
program 9 (20 int-adds inside a Nat recursion). Every other OCapN
program is 100% callback by both fire count and ns. **The OCapN
workload is dominated by data-construction + match-dispatch, not int
arithmetic** — exactly the inverse of the preduce-lite micro-suite.

## Where do callback fires come from?

`preduce.rkt`'s `b-install-fire-once` install sites, grouped by the
SHAPE of the fire-fn (read-pattern × write-pattern):

| shape | examples | install sites in `preduce.rkt` | already native? |
|---|---|---|---|
| **constant load** (0→1) | `expr-int`, `expr-nat-val` literal alloc | several | no |
| **identity passthrough** (1→1) | `expr-ann` body unwrap | 1 | yes (tag 0) but not routed there |
| **predicate-1** (1→1, tag-test) | `expr-zero?`, `expr-suc?`, `expr-int?`, `expr-pair?`, `expr-vcons?`, `expr-refl?`, `expr-champ?`, `expr-rrb?`, `expr-hset?`, `expr-fzero` | ≥10 | no |
| **selector-1** (1→1, field-pick) | `expr-fst`, `expr-snd`, `expr-vhead`, `expr-vtail` | 4 | no |
| **constructor-1** (1→1, lift) | `expr-suc`, `expr-fsuc`, `expr-from-int`, `expr-from-nat` | 4 | no |
| **constructor-N** (N→1) | `expr-pair`, `expr-vcons`, generic ctor-app build | several | no |
| **match dispatch** (N+1→1) | `expr-reduce` 7-arm, etc. | 1 (multi-arm) | no |
| **rec principles** (4→1) | `expr-natrec`, `expr-boolrec`, `expr-J` | 3 | no |
| **int binary** (2→1) | `expr-int-add` etc. | 8 | **yes** (7 of 8; mod is missing) |

Currently native-routed via `#:native-op`: int-add, int-sub, int-mul,
int-div, int-eq, int-lt, int-le. Conspicuously NOT routed: `int-mod`
(only int-binary without `#:native-op`). Identity is in the table but
unused by anything outside the int-arith zero-rhs reuse.

## Across the 12 programs, the SHAPE distribution is:

Hand-correlating each program's `def`s with the install-site list:

- programs 1–4 (light): mostly **ctor-N** (pair, syrup-tagged build).
- program 5 (18 fires): **9 ctor-build + 9 match-7arm** = 18.
- program 6 (16 fires): **3 ctor-build + 3 selector + 3 match-7arm + 7 ann/lifters** ≈ 16.
- program 7 (10 fires): mix of **ctor-build + match**.
- program 8 (9 fires): **3 native int-add + 6 ctor-N**.
- program 9 (62 fires): **20 native int-add + ≥3 natrec + ~19 ctor + ~20 ann/lifters**.
- program 10 (44 fires): **arity-4 ctor + 4× match-7arm + 4× selector + 4× ctor-build** ≈ 44.
- programs 11–12 (4–6 fires): per-ctor predicates / single-defn dispatch.

The two recurring fire-fn shapes that dominate cb-time across all
programs:

1. **ctor-N construction** — read N inputs, write a `(preduce-ctor-app
   tag args...)`. Pure data movement, no logic. Present in **every**
   program. Largest absolute count in programs 5, 9, 10.
2. **match-against-N-arm-tag** — read scrutinee, compare its top
   ctor-tag against each arm's pattern-tag, write the matching arm's
   body cell or apply its arm-fn. Present in programs 5, 6, 7, 9, 10.

Selectors (3) and identity-passthrough (4) are next-tier, low-hanging
because they're 1→1 and trivially native.

## Recommended Phase 7 ordering

Ranked by **leverage** (count of programs hit × cb-ns absorbed if
moved native) and **kernel-impl difficulty**:

| # | shape | est cb fires migratable across 12 programs | kernel difficulty | rationale |
|---|---|---|---|---|
| 1 | **ctor-N construction** | ~80 of 164 (≈50%) | medium — kernel needs a generic "boxed N-tuple with tag" ABI; `b-write` already passes tagged values. The fire-fn is data-movement only. | dominant shape; every program hits it; payoff is largest. |
| 2 | **match-7arm dispatch** | ~25 of 164 (≈15%) | medium-high — kernel needs tag-comparison + per-arm cell selection. Programs 5, 6, 7, 10 all hit this. | hot in OCapN-style data programs; but the 7-arm wide table is awkward to inline as a single native fn (7 native variants vs 1 generic). |
| 3 | **selector-1** (fst/snd/vhead/vtail) | ~15 of 164 (≈9%) | low — kernel reads a tuple cell, writes its k-th field. | lowest difficulty / next-best target after ctor-N. |
| 4 | **identity passthrough for `expr-ann`** | ~15 of 164 (≈9%) | trivial — `expr-ann` already routes through the same code path as `int-add` w/ zero rhs. Add `#:native-op 'identity` at the install site. | nearly free; no kernel work. |
| 5 | **predicate-1** (zero?/suc?/etc.) | ~10 of 164 (≈6%) | medium — per-ctor-tag native variants OR generic "tag = T?" comparator. | individually small; collectively meaningful. |
| 6 | **`expr-int-mod`** (already in int-binary family) | rare | trivial — kernel already has int-add through int-le; just add int-mod to the 0–7 tag bank. | the one int-arith op missed by the existing native cluster; closes a small gap. |

**Most attractive single migration**: **ctor-N construction** (#1). It's
the shape most heavily exercised by every OCapN program; the fire-fn is
pure data-movement (no Racket-side logic to port); and once it's native,
all 12 OCapN programs see a meaningful native-fraction jump (current
12.3% by fires would jump toward ~60%).

**Quickest win (no kernel code change)**: route `expr-ann` through
`#:native-op 'identity` in `preduce.rkt`. Frees ~15 fires across the 12
programs.

**Smallest discrete kernel addition**: add `'int-mod` to NATIVE-OP-TAGS
+ a Zig native fire-fn. Bookkeeping size ≈ that of int-add.

## What this analysis does NOT settle

- **Whether ctor-N native is ABI-feasible**: the kernel currently boxes
  ints. Boxing arbitrary tagged tuples requires either a kernel-side
  tagged-tuple representation or a stable "opaque cell pointer" passed
  through the ABI. Needs an actual design pass — the data here only
  argues that the fire-time payoff justifies the effort.
- **Whether match-7arm should be inline-native or stay callback**: the
  cost-per-fire of a 7-arm match (≈3,800 ns/fire averaged across
  programs 5/6/10 at the largest tag-fan-out) suggests yes, but the
  kernel-side implementation is more involved than ctor-N.
- **Sensitivity of the native int fraction at scale**: program 9's
  recursion gives the only meaningful native fire count (20). Real
  programs that lean on int loops (e.g. fib, factorial) will skew the
  fraction much higher. The 12.3% figure is a property of the
  **OCapN test suite**, not of "Prologos programs at large".

## Files / artifacts referenced

- `racket/prologos/preduce-backend-hybrid.rkt:64–72` — `NATIVE-OP-TAGS`
- `racket/prologos/preduce.rkt` — 30 `b-install-fire-once` sites; the 8
  with `#:native-op` are the int-binary cluster.
- `runtime/prologos-runtime-hybrid.zig` — current native fire-fns (per
  comment in preduce-backend-hybrid.rkt:62)
- `racket/prologos/examples/ocapn/ocapn-hybrid-{1..12}.prologos` —
  12 programs profiled here.
- `/tmp/all-profiles.txt` (this session) — raw per-program by_tag +
  ns_by_tag arrays. Not committed.
