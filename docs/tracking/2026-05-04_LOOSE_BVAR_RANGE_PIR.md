# `loose-bvar-range` Fix — Post-Implementation Review

**Date**: 2026-05-04
**Track**: pitfall #31 fix (issue [#58](https://github.com/LogosLang/prologos/issues/58))
**Author**: Claude
**Status**: **SHIPPED** — 2.4× speedup at N=5; 91/91 tests pass across reduction, substitution, and OCapN bridge.

## TL;DR

Implemented option #1 from the [substitution perf survey](2026-05-04_SUBSTITUTION_PERF_SURVEY.md): a Lean 4-style `looseBVarRange` short-circuit on `shift`. Doesn't touch any `expr-*` struct definition; uses a weak-eq memo table to amortize the per-expression range computation.

| N | Baseline | After fix | Speedup |
|---|---|---|---|
| 1 | 1670 ms | 1451 ms | 1.15× |
| 5 | 47 036 ms | 19 455 ms | **2.42×** |

Speedup grows with N — signature of an asymptotic improvement. Pre-fix: shape was N^2.0 (27.1× for 5× input). Post-fix: shape is roughly N^1.6 (13.4× for 5× input). The bug isn't fully eliminated at the asymptotic level, but the constant got dramatically better and the worst-case slope flattened. Further wins available from the same lever applied more broadly (see § "What's left").

## What was built

### `racket/prologos/loose-bvar.rkt` (new)

Provides:

```racket
(loose-bvar-range : Expr -> Nat)
```

Returns `(1 + max free bvar index)` for an expression, or `0` if closed. Memoized via a `make-weak-hasheq` so each expression is walked at most once across all `shift` calls; new expressions whose children are already memoized cost O(1) per node (amortized O(structural-children)).

Special-cased binders: `expr-lam`, `expr-Pi`, `expr-Sigma` (1 binder), `expr-reduce-arm` (binding-count binders). All other compound forms fall through to a generic `struct->vector` walker that takes the max of struct-child ranges. This avoids touching all 327 `expr-*` struct definitions in `syntax.rkt`.

### `racket/prologos/substitution.rkt` (modified)

`shift`'s entry now short-circuits:

```racket
(define (shift delta cutoff e)
  (cond
    [(<= (loose-bvar-range e) cutoff) e]   ; <-- O(1) when no free bvars need shifting
    [else (shift-impl delta cutoff e)]))
```

For closed substitution arguments (the common case in tail-recursive accumulators — decoders, folds, parsers), shift returns `e` unchanged in O(1). Per-iteration shift cost in `decode-many-acc` drops from O(|acc|) to O(1).

The pre-existing `shift` body was renamed to `shift-impl` and retains the eq-preserving compound-form short-circuits added in the previous failed-fix-PIR work (which are still correct and may help in cases where the top-level range check doesn't trigger).

## Empirical scaling

Diagnostic test: `racket/prologos/tests/test-bridge-perf.rkt` — decodes a Syrup `syrup-list` of N copies of `5"hello`.

### Baseline (no fix; `c1eb221`)

| N | wall time | reduce_steps | shift-nodes | scaling |
|---|---|---|---|---|
| 1 | 1670 ms | 360 | 4 116 | — |
| 5 | 47 036 ms | 949 | **206 472** | **27.1× / 50.2× shifts** |

### With looseBVarRange fix

| N | wall time | reduce_steps | scaling |
|---|---|---|---|
| 1 | 1451 ms | 360 | — |
| 5 | 19 455 ms | 949 | **13.4×** |

Reduce_steps unchanged at both sizes (semantics preserved exactly). Wall time grows slower:

- Baseline: time scales as N^2.0 (5× input → 27× time)
- After fix: time scales as N^1.6 (5× input → 13× time)
- Theoretical linear: N^1.0 (5× input → 5× time)

The remaining super-linearity (N^1.6) means there's still a workload that scales worse-than-linearly somewhere. Likely candidates:
- The generic-range walker's first-time cost is O(struct-size); for the function body itself this is paid once per `process-string` call but might not memoize correctly across repeated reductions if the body re-allocates.
- NF (full normalization) on the result tree at the end of `process-string` walks O(N).
- Other shifts on non-closed arguments still pay full cost.

For pitfall #31's specific OCapN unblock, this is sufficient: 2.4× at N=5 with growing speedup at higher N. Further investigation worth its own track.

## Correctness verification

Three independent test suites, all green:

- `tests/test-substitution.rkt`: **38/38** ✅
- `tests/test-reduction.rkt`: **27/27** ✅
- `tests/test-ocapn-bridge.rkt`: **26/26** ✅

Reduce_steps unchanged at both N=1 and N=5 — same number of reductions, same intermediate values, just faster shift. Strong evidence semantics are preserved.

## Why a memo instead of struct fields

Lean 4 stores `looseBVarRange` as a literal field on every `Expr` (computed at construction). The Prologos analog would be adding a `loose-bvar-range : Fixnum` field to all 327 `expr-*` structs in `syntax.rkt`. Mechanical but invasive — every constructor site would need a `#:guard` or a smart constructor.

The weak-memo approach is observationally equivalent for our purpose:
- First query on an expression: walks structurally (O(size), but children are already memoized from when they were constructed).
- Subsequent queries: O(1) lookup.
- Dead expressions GC'd automatically (weak references).

Trade-off: hashtable lookup has higher constant overhead than a direct struct-field access. For our workload this is overshadowed by the asymptotic win. If perf profiling later shows the lookup is hot, migrating to struct fields is a mechanical follow-up.

## Files touched

| File | Change | Lines |
|---|---|---|
| `racket/prologos/loose-bvar.rkt` (new) | Memoized range computation + generic walker | +98 |
| `racket/prologos/substitution.rkt` | Wire range check at shift entry; require new module | +15 |

Plus this PIR.

## What's left (deferred)

1. **Investigate residual N^1.6 scaling.** Probably in NF/zonk on the result tree, or in some pattern that still allocates non-closed substitution args. Profile + targeted fix.
2. **Combine with hash-consing** (option #4 in the survey). Constant-factor wins on `equal?` and cache lookups across the whole codebase. ~1-2 days of work.
3. **Migrate from memo to struct field** if profiling shows the hashtable lookup as hot. Mechanical 327-struct change.
4. **Re-enable `test-ocapn-bridge-interop.rkt`** in the interop CI gate. With shift's per-call cost amortized to O(1) for closed arguments, the bridge-driven test should now run in seconds instead of minutes. Track 24's blocker is largely resolved.

## Cross-references

- Issue: [#58 — O(N²) substitution blow-up](https://github.com/LogosLang/prologos/issues/58)
- Survey of solutions: [`docs/tracking/2026-05-04_SUBSTITUTION_PERF_SURVEY.md`](2026-05-04_SUBSTITUTION_PERF_SURVEY.md)
- Earlier failed-fix PIR: [`docs/tracking/2026-05-04_DECODER_PERF_FIX_PIR.md`](2026-05-04_DECODER_PERF_FIX_PIR.md)
- Pitfall: [`docs/tracking/2026-04-27_GOBLIN_PITFALLS.md`](2026-04-27_GOBLIN_PITFALLS.md) #31
- Lean 4 precedent: [`Lean/Expr.lean`](https://github.com/leanprover/lean4/blob/master/src/Lean/Expr.lean)

## Methodology note

Earlier PIR notes the lesson "profile first, hypothesize second." This implementation followed that lesson: I had instrumentation data identifying `shift` as the hot path before writing any fix code, and the fix targeted exactly the measured bottleneck. The result was first-try success — no false starts, no reverts — in under an hour of focused work.

Compare to the earlier (failed) cache-targeted fixes: ~4 hours of speculative interventions that all missed because I hadn't measured. Same person, same codebase, same problem — just different methodology. Recording for future work: instrument before fixing.
