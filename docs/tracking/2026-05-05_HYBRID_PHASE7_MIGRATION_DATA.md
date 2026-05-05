# Hybrid Kernel Phase 7 — Migration Target Data

**Date**: 2026-05-05 (initial OCapN-only data); **2026-05-05 PM** (expanded
with 42-program shape battery)
**Scope**: data collection only — no implementation in this commit.
**Branch**: `claude/prologos-layering-architecture-Pn8M9`

## Question

Which callback shapes consume the most fire-time across realistic
Prologos programs, and which are the most attractive migration targets
for native fire-fns in `runtime/prologos-runtime-hybrid.zig`?

## Update — 42-program shape battery (2026-05-05 PM)

The original analysis used only the 12 OCapN hybrid programs, which
gave 23 native fires (12.3%) vs 164 callback fires (87.7%). User
feedback: "we need to massively increase the battery of example
programs run on the hybrid kernel to determine what racket kernel
calls they make vs native fire fns."

A focused battery (`examples/hybrid-battery/{A1..L5}.prologos`) was
authored with each program a small (≤15 LOC) probe of one shape:
int-binary (A1–A8), pair (B1–B4), Nat (C1–C4), Bool (D1–D3),
Vec (E1–E3, **failed — see below**), Fin (F1, **failed**),
lifters (G1–G2), lambdas (H1–H4), user-ctor + match (I1–I5),
equality (J1–J2), CHAMP collections (K1–K5), and realistic
combinations (L1–L5: factorial, fib, etc.).

Of 46 programs authored, **42 ran successfully**. Vec (E1–E3, F1) failed
with `unbound-variable: vnil/vcons/fzero` — those primitives are not
exposed by the default prelude. That is itself a Phase 7 finding (the
kernel's `compile-expr` has cases for them but the WS-mode surface
syntax can't reach them) and is filed in the failure column rather
than the migration-target analysis.

### Per-group totals across the 42-program battery

| group | description | progs | nat fires | cb fires | cb ns | run ns |
|---|---|---:|---:|---:|---:|---:|
| A | int-binary (7-of-8 native) + int-mod | 8 | 7 | 1 | 17,438 | 41,220 |
| B | Pair construction + selectors | 4 | 4 | 5 | 33,478 | 35,507 |
| C | Nat ctors + natrec | 4 | 16 | 74 | 282,523 | 293,144 |
| D | Bool + boolrec | 3 | 4 | 13 | 110,423 | 121,195 |
| G | Lifters (from-int / from-nat) | 2 | 0 | 2 | 30,947 | 31,537 |
| H | Lambdas + apply | 4 | 4 | 16 | 97,703 | 101,224 |
| I | User-ctor + match dispatch | 5 | 13 | 32 | 252,608 | 258,783 |
| J | Equality (refl + J) | 2 | 0 | 0 | 0 | 326 |
| K | CHAMP collections (Map/Set/PVec) | 5 | 0 | 7 | 97,076 | 99,115 |
| L | Combinations (factorial, fib, recursive match) | 5 | 383 | 497 | 1,729,702 | 1,792,876 |
| **Σ** | (42 programs) | 42 | **431** | **647** | **2,651,898** | **2,774,927** |

**Native fire fraction**: 431 / (431+647) = **40.0%** of fires across
the battery (vs 12.3% for OCapN-only).
**Native ns fraction**: 49,354 / 2,701,252 ≈ **1.8%** of in-fire time
(vs 0.4% for OCapN-only).

The native path fires 6 × more (relatively) than the OCapN-only sample
suggested — recursive int-arithmetic in the L group (esp. `L2-fib`)
exercises native int-add hundreds of times. Yet **native ns is still
<2% of total fire time**: each native fire averages ~115 ns, each
callback fire averages ~4,100 ns — a **~36× per-fire cost gap**.

### Programs with **zero** runtime fires (compile-time-only)

A surprising finding — five programs do no kernel work at all:

| program | shape | why it has no fires |
|---|---|---|
| `B1-pair-fst` | `[fst [the <Int*Int> [pair 17 23]]]` | static β: pair-construct + fst collapse at elaboration |
| `B2-pair-snd` | `[snd [the <Int*Int> [pair 17 23]]]` | same |
| `H1-id-lambda` | `[[fn [x : Int] x] 42]` | static β: identity lambda + concrete arg → literal |
| `J1-refl-only` | `def proof : [Eq Int 5 5] := refl` | refl construction is compile-time |
| `J2-J-trivial` | `def proof : [Eq Int 5 5] := refl ; def main := 42` | dead-code; main is a literal |

Implication: **the elaborator's static β + ann-erasure paths absorb
shape-1, shape-2, and shape-J fully**. Phase 7 should NOT prioritize
these — they have nothing to migrate. Conversely, programs that
DEFEAT static β (recursion, fvar self-reference, dynamic match
discrimination) are where the kernel pays its runtime cost, and where
Phase 7 leverage lives.

### Top callback-time consumers (single programs)

| rank | program | cb ns | % of all cb ns |
|---:|---|---:|---:|
| 1 | `L2-fib` (naive Fibonacci `n=8`) | 1,375,873 | **51.9%** |
| 2 | `L1-fact-iter` (factorial `n=6`) | 214,532 | 8.1% |
| 3 | `C4-natrec-sum` (sum 0..4 via natrec) | 156,998 | 5.9% |
| 4 | `I5-userctor-recursive` (Tree leaf-count) | 119,534 | 4.5% |
| 5 | `C3-natrec-shallow` (count up via natrec) | 94,341 | 3.6% |
| 6 | `L4-natrec-and-bool` | 74,472 | 2.8% |
| 7 | `D3-boolrec-nested` | 69,706 | 2.6% |
| 8 | `H3-apply-twice` (HOF) | 50,152 | 1.9% |
| 9 | `L5-deep-match` (6-arm dec + 6-arm to-int) | 45,852 | 1.7% |
| 10 | `I3-userctor-4arg` (4-arg ctor + selectors) | 38,297 | 1.4% |

**The single-program top 5 account for 73.9% of all callback time
across the battery.** All 5 are recursive — the dominant callback
shape across realistic Prologos programs is the **recursive function
dispatch loop** (expr-fvar + expr-app + expr-natrec/boolrec + match).

### Revised Phase 7 ranking

The original (OCapN-only) ranking put **ctor-N construction** first
(50% of OCapN cb fires). The expanded battery shows that's a
shape-frequency leader for *data-construction* workloads but NOT a
time-leader once recursion is in the mix. Updated table:

| # | shape | cb ns share (battery) | kernel difficulty | rationale |
|---|---|---:|---|---|
| 1 | **`expr-fvar` + `expr-app` recursive call apparatus** (the function-dispatch loop) | ~65% (estimated from L1+L2+L3+L5 + portions of C/I/H groups) | high — kernel needs closures or trampoline + a stable ABI for boxed-arg passing. This is the highest-payoff but largest piece of work. | dominant in recursive programs; L2-fib alone is 51.9% of all cb time. |
| 2 | **`expr-natrec` step** (the per-iteration body installer) | ~17% (C3+C4+L4) | medium — the step closure already runs Racket-side; a native iterative loop with Int counter could replace it for the common `motive=Int` case. | second-largest after fvar/app. |
| 3 | **`expr-reduce` match dispatch** | ~10% (I4 + L5 + portions of I/L) | medium-high — kernel needs tag-comparison + per-arm cell selection; per-arity (1-arm, 2-arm, 7-arm) variants. | hot in OCapN-style enums and recursive sum types. |
| 4 | **ctor-N construction** | ~5% in this battery; **~50% in OCapN-only** workloads | medium — kernel-side tagged-tuple ABI design needed. | dominant for data-construction-heavy code; secondary for compute-heavy code. |
| 5 | **`expr-boolrec`** | ~4% (D3 + L4 + parts of L1) | low — boolrec dispatches on a Bool result; native fire could pick a precompiled arm. | small but cheap to migrate. |
| 6 | **`expr-int-mod`** | <1% but standalone single-fire = 17 µs | trivial — add to NATIVE-OP-TAGS + native fire-fn. | the one int-binary not yet routed; closes the gap. |
| 7 | **CHAMP collection ops** (map/set/pvec primitives) | ~4% across K group (single ops in trivial programs — likely amortized differently for real workloads) | high — kernel-side persistent-collection storage required. | low priority until real workloads exercise these heavily. |
| 8 | **selector-1** (`fst`, `snd`, `vhead`, `vtail`) | ≈ 0% (all collapsed by static β when input is statically known) | low | Phase 7 should NOT migrate; static β eats them. |
| 9 | **identity passthrough** | (corrected — see § "Misread fixed" below) | n/a | **Withdrawn**: my earlier ranking had this at "quick win"; it was based on misreading `expr-ann?` (predicate, used inside other fire-fns) for `expr-ann` (the AST node, which is fully erased at compile time). No `expr-ann` fire-fn exists to migrate. |

### Misread fixed (2026-05-05 PM)

The original 2026-05-05 AM analysis listed "route `expr-ann` through
`#:native-op 'identity`" as a quick win. That recommendation was based
on a misread of grep output: the matches for `expr-ann?` (the runtime
predicate, appearing as patterns inside other fire-fns) were
mistakenly correlated with `expr-ann` (the AST node, which is fully
erased at compile time at preduce.rkt:384–385: `(compile-expr inner
env net)`). There is no `expr-ann` fire-fn to migrate. The other
candidates (ctor-N, selectors, match-7arm, int-mod) stand.

### Failures, and what they tell us

4 of 46 battery programs failed at elaboration time:

| program | error | finding |
|---|---|---|
| `E1-vec-vnil` | `unbound-variable: vnil` | Vec ctors have `compile-expr` cases (preduce.rkt:636+) but `vnil`/`vcons` aren't surfaced by the default prelude. Surface-syntax users can't construct Vec literals. |
| `E2-vec-cons-head` | same | same |
| `E3-vec-cons-3` | same | same |
| `F1-fzero` | `unbound-variable: fzero` | Same gap for Fin. |

These aren't migration targets — they're missing-prelude bugs (or
deliberately kernel-internal types). The fact that **`compile-expr`
has Vec/Fin compile cases that no surface-syntax program can reach**
is itself a finding worth filing.

### What this analysis settles vs leaves open

**Settles**:
- The OCapN-only number (12.3% native by fires) was an artifact of the
  data-construction-heavy workload. The realistic battery shows 40%.
- Recursive expr-app + expr-fvar dispatch is the dominant callback
  shape by **time**, not ctor-N construction.
- Several "obvious" migration targets (selectors, identity) are
  already absorbed by static β — no kernel work would help them.

**Leaves open**:
- Whether kernel-side recursive-call apparatus is feasible — the
  fvar+app+closure path is the largest and most architecturally
  invasive change. Needs a design pass on its own.
- Whether the per-shape ranking holds at programs >10x larger than
  the battery (largest here is L2-fib at 423 cb fires; real programs
  could be 10,000+ fires).
- Whether the elaborator's static β scope can be extended (e.g., to
  cover one more layer of recursion unfolding) — that would shift cost
  from kernel to elaborator without any kernel work.

## Original analysis (2026-05-05 AM, OCapN-only — kept for context)

The text below is the original 12-OCapN-program analysis. The
expanded battery above supersedes its rankings but its data table
remains a useful narrow sample.

---

## Question (original)

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
