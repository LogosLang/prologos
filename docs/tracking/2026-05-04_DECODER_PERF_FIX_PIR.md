# Decoder Perf Fix — Post-Implementation Review

**Date**: 2026-05-04
**Track**: pitfall #31 fix attempt (follow-up to `2026-05-04_DECODER_PERF_INVESTIGATION.md`)
**Author**: Claude
**Status**: **NEGATIVE RESULT** — three localized fixes attempted, none reduced the O(N²) scaling. The investigation refines the root-cause model and clarifies what the real fix has to look like.

## What was tried

The investigation document hypothesized that the WHNF/NF caches' use of `equal-hash-code` over deeply-nested transparent expr structs caused O(N²) behavior: each cache lookup hashes the key recursively, so for an expression containing a growing accumulator, hash cost is O(size). Three localized interventions tested this:

### Attempt 1 — Custom-hash with eq-memoized hash function

Wrote `racket/prologos/expr-hash.rkt` providing `make-memoized-expr-hash`: a `make-custom-hash` with a custom hash function (`expr-fast-hash`) that walks the struct tree once per expression and memoizes the result in a weak `make-weak-hasheq`. Wired it into `driver.rkt` for `current-whnf-cache` and `current-nf-cache`. Changed `reduction.rkt`'s `whnf` and `nf` to use `dict-ref` / `dict-set!` (since `make-custom-hash` returns a dict, not a hash).

**Result**: N=5 still **48s**. No change. The memo only helps when the SAME struct (eq-identical) is hashed twice. In `decode-many-acc`, each iteration's accumulator is a freshly-allocated struct (because `subst` rebuilds expressions), so memo always misses on the outer wrappers. Sub-expression memo hits don't help because the dominant cost is the outer wrapper hash, which has to walk down to find leaves.

### Attempt 2 — Eq-preserving substitution for common forms

Modified `subst` in `substitution.rkt` for `expr-app`, `expr-pair`, `expr-fst`, `expr-snd`, `expr-ann` to short-circuit when both children are eq-equal to the originals (return the original `e` unchanged). The intent: if subst preserves identity for unchanged subtrees, the eq-memoized hash from Attempt 1 starts hitting on subtrees.

**Result**: N=5 still **48.6s**. Same story. The body of `decode-many-acc` always references the bvar that gets substituted, so `subst` ALWAYS rebuilds the function body. Eq-preservation can't kick in when the substitution is non-trivial. And even when it COULD (for sub-subtrees), the dominant cost is in the outer expression which by definition has changed.

### Attempt 3 — eq?-cache (lossy memoization, O(1) lookup)

Replaced `make-hash` with `make-hasheq` for the WHNF/NF caches. Cache hits ONLY when the exact same struct instance is whnf'd twice. Loses most of the structural memoization but each lookup is genuinely O(1).

**Result**: N=1 took **4.5s** (vs 1.7s with equal-cache, vs 6.4s with no cache). N=5 still running past 4 minutes — actually SLOWER than equal-cache. So eq-cache loses memoization without buying anything.

## What the data tells us (refined model)

| Variant | N=1 reduce_steps | N=1 wall | ms/step | N=5 wall |
|---|---|---|---|---|
| no cache | 5240 | 6.4s | 1.2 | (killed) |
| equal cache (baseline) | 360 | 1.7s | 4.9 | 47s |
| eq cache | 1940 | 4.5s | 2.3 | >4 min |
| custom-hash + memo | 360 | 1.8s | 5.0 | 48s |
| custom-hash + memo + eq-subst (5 cases) | 360 | 1.9s | 5.3 | 49s |

Observations:
1. **The cache is genuinely beneficial** — without it, work explodes (14.5x more reduce_steps for N=1).
2. **The per-step cost growth is the problem**, not the cache lookup specifically. Equal-cache N=1 is 4.9 ms/step; N=5 is 50 ms/step. **10x growth for 5x input.**
3. **Custom-hash makes no measurable difference.** That contradicts the original hypothesis that hashing was the bottleneck.
4. **Eq-cache loses the memoization win without solving the per-step growth.** Confirms the per-step growth is NOT in cache lookup.

## Refined root-cause hypothesis

The per-step cost grows with input size, but cache lookup is NOT the cause. Plausible alternatives the data supports:

- **`subst` reallocates every node on every call.** For a body of size B, subst is O(B). It's called once per beta-reduction. If the function body itself contains the substituted argument multiple times, those copies multiply the total work. As accumulator grows, the substituted-into body grows (each bvar reference sees a bigger acc), and subsequent beta-reductions see a bigger function value to substitute into.
- **Result-tree NF cost.** At the end of `process-string`, the result is fully normalized for printing. NF walks the result tree, which has size O(N). NF on a tree of size N costs O(N), but each NF step might trigger more whnf calls on subterms — and those subterms' whnf inputs grow with depth.
- **Structural pattern matching in `whnf-impl`.** The big match in whnf-impl tries arms in order. If many arms have `(? predicate?)` guards or do destructuring, each whnf call could walk into the struct multiple times.

What we know: the bottleneck IS scaled with the size of the structure flowing through the reducer, but the WHNF cache lookup specifically is not the cause.

## What the real fix probably needs

The investigation document's recommendation (content-hash on all 327 expr structs) might still help — but only if the actual hot path involves redundant hashing. The data here suggests the hashing isn't the dominant cost. Other plausible fixes:

1. **Eq-preserving substitution everywhere.** Modify ALL `subst` cases (including binders) to return `e` unchanged when no replacement was needed in any subtree. Combined with structural sharing, this would let large unchanged subexpressions stay eq-identical across reduction steps. Big change to substitution.rkt but localized to one file.

2. **Lazy evaluation of the result tree.** Don't NF the entire result before returning to Racket. Just whnf the top, return a thunk for subterms. Caller (Racket pretty-printer) walks lazily. Might be hard to retrofit.

3. **Re-architect `decode-many-acc` to not accumulate via a Prologos cons-list.** Use a foreign Racket mutable buffer pushed via FFI. Workaround at the OCapN layer, not a fix.

4. **Profile the actual hot path.** Use Racket's `errortrace` or a sampling profiler to find where the per-step time actually goes. Without this, further interpreter changes are guesses.

## Honest accounting

This was a failed fix. The hypothesis (cache hashing) sounded right and the data initially looked like it confirmed it (per-step cost growing with N is exactly what O(N) hash would produce). But three interventions targeting that hypothesis didn't move the needle, which means the model was wrong.

The real bottleneck is somewhere else in the reducer/substitution path. Profiling would identify it, but I didn't reach for that step before trying the three interventions.

What I learned that I didn't know before:
- The WHNF cache is genuinely load-bearing (14.5x reduction in steps).
- Custom hash functions in `make-custom-hash` don't impact perf measurably here, so the hash isn't the dominant cost in the cache lookup.
- Eq-preserving substitution for a few forms isn't sufficient to recover identity sharing — the body itself rebuilds even when no fields change in the immediate children.

## Recommended next step

Profile before fixing. Use `errortrace` / `racket/profile` to identify the actual hot function. If it IS in `subst` or `whnf-impl`, the fix is bounded. If it's in something I haven't considered (NF? pretty-print? something in the parser path?), the fix lands somewhere else.

Estimated profile + fix cycle: 2-4 hours for profile, then variable for fix depending on what shows up.

## Files touched and reverted

All experimental changes were reverted; the repo is clean except for the test-bridge-perf.rkt scaling test (already committed as the perf baseline).

- `racket/prologos/driver.rkt` — temporarily added `(require "expr-hash.rkt")` and changed cache initializers; reverted.
- `racket/prologos/reduction.rkt` — temporarily added `racket/dict` require and changed `hash-ref`/`hash-set!` to `dict-ref`/`dict-set!`; reverted.
- `racket/prologos/substitution.rkt` — temporarily added eq-preserving short-circuits to 5 subst cases; reverted.
- `racket/prologos/expr-hash.rkt` — created and deleted.

## Cross-reference

- Investigation: `docs/tracking/2026-05-04_DECODER_PERF_INVESTIGATION.md`
- Pitfall: `docs/tracking/2026-04-27_GOBLIN_PITFALLS.md` #31
- Test: `racket/prologos/tests/test-bridge-perf.rkt`
