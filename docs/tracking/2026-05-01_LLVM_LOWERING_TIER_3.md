# LLVM Lowering — Tier 3 (SH Series Track 2)

**Date**: 2026-05-01
**Status**: Stage 4 implementation (T3.A investigation complete; design firm enough to proceed)
**Series**: SH (Self-Hosting) — second track, building on Track 1 (Tiers 0–2)
**Cross-references**:
- [Track 1 plan + tracker](2026-04-30_LLVM_LOWERING_TIER_0_2.md)
- Track 1 commits: `9f84490` (T0), `307e995` (T1), `ab5513a` (T2), `a6de14d` (post-validation fixes)

## 1. Summary

Add control flow + recursion to the lowering pass. The smallest meaningful program — `defn fact | 0 -> 1 | n -> [int* n [fact [int- n 1]]]` plus `def main : Int := [fact 5]` — compiles to native and exits with 120.

## 2. T3.A — Elaborator output (resolved)

The `defn | pat -> body | pat -> body` pattern compiler emits two AST families:

- **`expr-reduce <scrutinee> (list (expr-reduce-arm tag arity body) ...) <exhaustive?>`** for *constructor* patterns. For Bool: `'true` and `'false` arm tags, both with `arity = 0`.
- **`expr-boolrec <motive> <true-case> <false-case> <target>`** for *Int-literal* patterns. The target is the synthesized `(expr-int-eq <scrutinee> <literal>)` test. Motive is erased at runtime.

Plus a third common shape:

- **`(expr-app (expr-lam mult type body) arg)`** — a beta-redex used as an *implicit let-binding* by the pattern compiler when binding a parameter inside an arm. Tier 2 didn't hit this shape; Tier 3 must lower it.

No additional eliminators (`expr-natrec`, `expr-J`, etc.) appear in the recursive Int test programs. Defer those to later tiers.

## 3. Progress Tracker

| Phase | Description | Status | Notes |
|---|---|---|---|
| T3.A | Investigate elaborator output for `defn` patterns | ✅ | findings in § 2 |
| T3.B | `expr-Bool`, `expr-true`, `expr-false` lowering | ⬜ | Bool encoded as i64 0/1 |
| T3.C | `expr-int-lt`/`expr-int-le`/`expr-int-eq` lowering | ⬜ | `icmp` + `zext i1 to i64` |
| T3.D | Multi-block SSA builder refactor | ⬜ | per-block instr lists + cur-block pointer |
| T3.E | `(expr-app (expr-lam ...) arg)` as let-binding | ⬜ | extend bvar-env, no LLVM op |
| T3.F | `expr-boolrec` lowering | ⬜ | `icmp ne i64, 0` → `br i1` → 2 arms → phi |
| T3.G | `expr-reduce` on Bool | ⬜ | shares mechanism with boolrec; dispatch on `'true` / `'false` arm tags |
| T3.H | Tier 3 acceptance programs + CI step | ⬜ | fact, fib, choose, is-positive |

## 4. Scope

### In scope

- `expr-Bool`, `expr-true`, `expr-false`
- `expr-int-lt`, `expr-int-le`, `expr-int-eq`
- `expr-boolrec`
- `expr-reduce` *only* when the scrutinee has type `Bool` and arm tags are `'true` / `'false`
- `(expr-app (expr-lam ...) arg)` — let-binding via env extension
- Recursive top-level functions whose recursion terminates within the OS stack
- `def main : Bool` (zext is a no-op since Bool is already i64)

### Out of scope (explicit)

- `expr-reduce` on non-Bool ADTs (List, Option, user data) → Tier 4
- `expr-natrec`, `expr-J`, dependent eliminators → Tier 4+
- Tail-call optimization. Stack overflow on deep recursion is **accepted**: `fact(20)` likely fine, `fact(10000)` will SO and that's documented behavior. Test programs use small inputs to stay within ~1000 recursion depth.
- Closures with free variables → Tier 4
- Arbitrary `expr-lam` at non-top-level positions other than the let-binding shape
- Strings, chars, heap-allocated values

### Failure mode (carried forward from Track 1)

Closed pass. Any AST node not in the Tier-3-extended supported set raises `unsupported-llvm-node`.

## 5. Mantra alignment (carried forward)

The lowering pass remains a Racket function, not a propagator stratum. Same scaffolding statement as Track 1 § 5. Tier 3 introduces no new mantra decisions; it extends the existing function form.

## 6. Design notes

### 6.1 Multi-block builder

State per `lower-function`:
- `instrs : Hash[Symbol → ListOf String]` — block name to reverse-instr-list
- `cur-block : Symbol | #f` — name of block currently emitting; #f after a `br` (next op must `start-block!`)
- `block-counter : Box Integer` — for `fresh-label!`
- `ssa-counter : Box Integer` — for `fresh!`

API:
- `(emit! str)` — appends to `cur-block`
- `(start-block! name)` — sets `cur-block`, ensures `instrs` has the key
- `(branch label)` — emits `br label %label`, sets `cur-block` to #f
- `(branch-cond cond-i1 lt-label lf-label)` — emits `br i1 …`, sets `cur-block` to #f
- `(fresh-label! prefix)` — returns a fresh block name like `"true_3"`
- `(emit-fn-body)` — concatenates blocks in entry-first declaration order with their `name:\n` prefixes and instrs

### 6.2 i64-uniform ABI

Every Prologos value is `i64`. Bool: 0 = false, 1 = true. Comparisons: `icmp <op> i64, i64 → i1`, then `zext i1 to i64`. Conditional branches: `icmp ne i64 %v, 0 → i1`, then `br i1`. Redundant in some cases; LLVM's `instcombine` eliminates the round trips.

### 6.3 `expr-boolrec` lowering

```
(expr-boolrec motive true-case false-case target)
  ↓
  ;; lower target → %t (i64)
  %tc = icmp ne i64 %t, 0
  br i1 %tc, label %true_N, label %false_N

true_N:
  ;; lower true-case → %tv, last block = true_end
  br label %join_N

false_N:
  ;; lower false-case → %fv, last block = false_end
  br label %join_N

join_N:
  %r = phi i64 [%tv, %true_end], [%fv, %false_end]
```

Motive is ignored (erased).

### 6.4 `expr-reduce` on Bool

```
(expr-reduce target (list (arm 'true 0 t-body) (arm 'false 0 f-body)) exh?)
  ↓ (semantically same as boolrec)
```

Lowered identically to boolrec, dispatched by examining the arms list. Arm order may be `'true` first or `'false` first; we look up by tag, not by position. `arity = 0` is required (non-zero means a constructor with fields, which is Tier 4).

### 6.5 Let-binding via `(expr-app (expr-lam mult type body) arg)`

Recognized in `lower-int-expr`'s `expr-app` clause: if the head is an `expr-lam`, treat as let. Lower `arg` in current env → `%av`. Push `%av` onto bvar-env. Lower `body` in extended env. Pop. Return body's value.

The lambda's `mult` is honored: `m0` arg means we lower the arg's body NOT (skip the arg evaluation), push `'erased` onto env, and continue. (Practically rare for top-level let, but needed for completeness when type-level binders are interleaved.)

## 7. Commit cadence

- **C1 (T3.B + T3.C + T3.D + T3.E)**: foundation. Bool + comparisons + multi-block builder + let-binding. No conditional acceptance program yet but Tier 0–2 acceptance still passes. New unit tests for each piece.
- **C2 (T3.F + T3.G)**: conditionals. `expr-boolrec` and `expr-reduce` on Bool. First Tier 3 acceptance program (`choose`).
- **C3 (T3.H)**: recursion. `fact` + `fib` acceptance programs, CI step for Tier 3, all tracker rows ✅.

## 8. Risk register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Multi-block refactor regresses Tier 0–2 | Medium | High | Keep Tier 0–2 paths working through a thin entry-block-only shim; verify all existing acceptance tests after C1. |
| Phi source block tracking gets stale | Medium | High (silently wrong IR) | Track `cur-block` rigorously; assert `cur-block ≠ #f` before every emit. |
| Stack overflow on `fact` at unexpected n | Low | Low | Test programs use n ≤ 10. Document in plan doc. |
| Pattern compiler emits a fourth shape we haven't seen | Low | Medium | Closed-pass design catches this with a clear error pointing at the unsupported AST node. |
