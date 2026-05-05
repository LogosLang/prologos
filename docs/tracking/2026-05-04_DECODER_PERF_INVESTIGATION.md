# Decoder Performance Investigation — Pitfall #31 Root Cause

**Date**: 2026-05-04
**Investigator**: Claude (Phase 24 follow-up)
**Triggered by**: OCapN bridge-driven interop test taking 8+ minutes for a 50-byte input.

## Empirical findings

Diagnostic test: `racket/prologos/tests/test-bridge-perf.rkt` decodes a Syrup
`syrup-list` of N elements (each `5"hello`, 7 bytes each) wrapped in `[ ... ]`.

| N | bytes | reduce_steps | wall time | ms / step |
|---|---|---|---|---|
| 1 | 9 | 360 | 1,765 ms | **4.9** |
| 5 | 37 | 949 | 47,036 ms | **49.6** |

Time grew **26.6x** for **5x input** — almost exactly N² (predicted 25x).

The split is the smoking gun:
- `reduce_steps` grew 2.6x → roughly linear in input.
- **Per-step cost grew 10x** → super-linear, proportional to N.

A reduce step is normally a constant-time operation. Per-step cost growing
with the size of the *workload* points to a per-step operation whose cost
depends on the size of the data flowing through the reducer.

## Root cause

`whnf` (weak-head normal form) and `nf` (normal form) use a per-command
memoization cache. The cache is created in `driver.rkt:482-483`:

```racket
[current-nf-cache (make-hash)]         ;; per-command nf memoization
[current-whnf-cache (make-hash)]       ;; per-command whnf memoization
```

`make-hash` produces an `equal?`-based hash table. The cache key is the
*entire* expression being whnf'd:

```racket
(define (whnf e)
  (define cache (current-whnf-cache))
  (cond
    [(and cache (hash-ref cache e #f))    ;; ← O(size(e)) hash + O(size(e)) equal?
     => values]
    [else
     (define result (whnf-impl e))
     (when cache
       (hash-set! cache e result))         ;; ← O(size(e)) hash
     result]))
```

The expression types (`expr-app`, `expr-lam`, `expr-Pi`, `expr-reduce`, etc.,
defined in `syntax.rkt`) are declared `#:transparent`. For transparent
structs, Racket's default `equal?` and `equal-hash-code` recurse through
**all** fields, so:

- Hashing an `expr-app` whose argument is a deep cons-list (size N) is **O(N)**.
- Looking up that expression in the cache is therefore **O(N)** per call.

The decoder `decode-many-acc` in `lib/prologos/ocapn/syrup-wire.prologos`
has shape:

```prologos
defn decode-many-acc [dec s i terminator acc]
  match ... | true -> some [decoded-many [reverse acc] ...]
            | false -> ...
                       decode-many-acc dec s end terminator [cons v acc]
```

Each iteration calls itself with a *larger* `acc`. The reducer's whnf calls
on each iteration's body see `acc` as an O(N) cons-list. Hashing that key
into the cache is O(N). Over N iterations:

> **Total cache cost: N × O(N) = O(N²).**

Net: the decoder algorithm is O(N), but the elaborator's caching subsystem
turns it into O(N²) at runtime.

## Why this only bites the decoder

Other workloads in the OCapN test suite don't hit pathological depths because
they don't accumulate large cons-lists through deep recursion. The bridge
unit tests in `test-ocapn-bridge.rkt` use 4-element ops with hand-coded
constructors — the accumulator never grows past size 1 in any single call.

The decoder is uniquely exposed because:
1. Inputs are byte-strings of arbitrary size (~50 bytes is small but
   already pushes total reduce-step count to ~1000).
2. `decode-many-acc` accumulates one cons cell per parsed sub-value.
3. Records nest (e.g., `op:deliver` contains `desc:export` and `desc:answer`),
   so accumulator depth can be deep.

Encoder is fast because it walks the input list once and string-appends —
never substitutes a growing accumulator into a function body via subst.

## Fix plan

### Recommended: precomputed content-hash on expr structs (`gen:equal+hash`)

Each expr struct gains a precomputed `content-hash` field. `gen:equal+hash`
uses this slot for the hash and short-circuits structural `equal?` via a
hash check.

Existing precedent in `syntax.rkt:975`: `expr-meta` already uses the pattern,
hashing on its `id` field for O(1) lookup.

#### Phase 1 — schema change

For each expr struct (~50 in `syntax.rkt`), add:

```racket
(struct expr-app (func arg content-hash)
  #:transparent
  #:guard (lambda (func arg ch _name)
            (values func arg
                    (or ch (combine-hash 'app (expr-content-hash func)
                                              (expr-content-hash arg)))))
  #:methods gen:equal+hash
  [(define (equal-proc a b rec)
     (and (eq? (expr-app-content-hash a) (expr-app-content-hash b))
          (rec (expr-app-func a) (expr-app-func b))
          (rec (expr-app-arg  a) (expr-app-arg  b))))
   (define (hash-proc  a _rec) (expr-app-content-hash a))
   (define (hash2-proc a _rec) (+ 1031 (expr-app-content-hash a)))])
```

Expression construction stays the same: existing `(expr-app f x)` calls
work because the `#:guard` computes the missing `content-hash` field
automatically. (Or pass `#f` and let the guard fill it in.)

`combine-hash` is a small helper that mixes hashes deterministically
(any of fxxor/fnv1a/equal-hash-code-on-a-pair).

`expr-content-hash` is a generic accessor that dispatches on the struct
kind and returns its `content-hash` field. (Or define a generic
`gen:content-hashed` interface.)

#### Phase 2 — migrate every expr struct

About 50 struct definitions in `syntax.rkt` (lines 327, 328, 988, 992,
plus all the ctor variants). Atomic per pipeline.md co-migration discipline:
either ALL expr types have content-hash or NONE do (otherwise mixed hash
keys mean the same expression can hash differently depending on construction
path).

#### Phase 3 — verify

1. Re-run the scaling test (`tests/test-bridge-perf.rkt`):
   - N=1 should stay near 1.7s.
   - N=5 should drop from 47s to ~9s (linear in N).
   - N=20 should be ~36s (was projected at 752s = O(N²)).
2. Re-run `test-ocapn-bridge-interop.rkt`: should drop from 8+ min to <30s.
3. Full suite: confirm zero regressions. Memo cache hits should be identical.
4. Microbench: confirm individual `whnf` call latency is unchanged for small
   expressions and dramatically improved for large ones.

### Estimated effort

| Phase | Work | Estimate |
|---|---|---|
| 1 | Add content-hash field + guard + gen:equal+hash to one representative struct | 1-2 h |
| 2 | Migrate all ~50 expr structs in syntax.rkt | 3-5 h |
| 3 | Verify scaling + suite + microbench | 1-2 h |
| | **Total** | **5-9 h focused work** |

### Risk

- **Memory**: 1 word per expr instance for the hash slot. For a typical
  workload (~10⁶ live exprs), ~8 MB extra. Acceptable.
- **Construction cost**: `#:guard` runs once per construction. Hash combine
  is O(1) since it consumes the children's already-precomputed hashes.
  Net construction cost: roughly unchanged (hash is computed once instead
  of on every cache lookup).
- **Correctness**: Hash collisions are possible. The `equal-proc` still
  does structural comparison after a hash match, so collisions only cost
  one extra O(size) comparison rather than producing wrong results. Use a
  good hash combiner (e.g., FNV-1a on child hashes, mixed with a
  per-struct-kind nonce).

### Alternative quick-win: gate cache by expr size

If full fix is too much work for the immediate need:

```racket
(define MAX-CACHE-SIZE 64)

(define (small-enough? e)
  (define n (box 0))
  (let walk ([e e])
    (cond
      [(> (unbox n) MAX-CACHE-SIZE) #f]
      [(expr-app? e) (set-box! n (+ (unbox n) 1)) (walk (expr-app-func e)) (walk (expr-app-arg e))]
      ;; ... etc
      [else (set-box! n (+ (unbox n) 1)) #t])))

(define (whnf e)
  (define cache (current-whnf-cache))
  (cond
    [(and cache (small-enough? e) (hash-ref cache e #f)) => values]
    [else ...]))
```

Drawback: `small-enough?` itself walks the tree, costing O(min(size, threshold))
per call. Loses memoization for large expressions (where it might most matter).
But caps cache lookup cost at O(64) regardless of input.

Effort: ~1 hour. Risk: memoization may regress on large unifier states.

### Why NOT eq?-cache (`make-hasheq`)

`make-hasheq` would be O(1) per lookup BUT only hits when the *exact same
struct instance* is whnf'd twice. After `subst` returns a fresh struct,
the cache misses every time. Cache effectively becomes useless. Likely
makes things slower overall, not faster.

### Why NOT hash-cons (struct interning)

Hash-consing would unify `equal?` instances into one identity, making
`make-hasheq` work correctly. But it requires every expr construction
site to go through an interning table — major architectural change. Save
for a future general-purpose optimization track if needed.

## Concrete next step

If approved: open a PM-series track (or a SRE-series sub-track) titled
"Content-hash on expr structs for O(1) cache keys" with:

- Design doc covering the schema change for all ~50 expr structs.
- Pre-0 microbench measuring cache lookup cost at expression sizes
  10, 100, 1000, 10000.
- Atomic implementation phase (one big commit per pipeline.md
  co-migration discipline).
- Re-run the OCapN bridge-interop test as the regression gate.

This would unblock not only OCapN's interop CI gate but every future
test that drives a parser/decoder via `process-string`.
