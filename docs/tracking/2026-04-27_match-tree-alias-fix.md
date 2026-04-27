# 2026-04-27: compile-match-tree variable bindings aliased outer-param storage

GitHub issue: https://github.com/LogosLang/prologos/issues/18
Branch: `claude/fix-match-tree-alias-issue18-v2`
Commits: `9105e5c` (acceptance), `c64e7e3` (fix), `952622a` (rackunit tests)

## Summary

A multi-clause `defn` whose pattern dispatch decomposes a compound parameter
(e.g. `cons r rest`) and whose body recurses on a sub-binding silently
produced wrong results. The canonical reproducer:

```
spec sum-rows [List Nat] -> Nat
defn sum-rows
  | nil           -> 0N
  | cons r nil    -> r
  | cons r rest   -> [+ r [sum-rows rest]]
[sum-rows '[1N 2N 3N]]   ;; pre-fix: 5N, expected 6N
```

The bug was silent: no error, no contradiction, no type mismatch. Several
canonical idioms (recursive sum, recursive length) returned values
off by one or more, accumulating into widely-wrong totals on longer
inputs.

## Root cause: lexical shadowing in nested compound dispatch

`compile-match-tree` (in `racket/prologos/macros.rkt`) lowers each
constructor dispatch into a `reduce-arm` whose binders are derived
from the constructor name and field index:

```racket
(define field-names
  (for/list ([i (in-range n-fields)])
    (string->symbol (format "__~a_~a" ctor i))))
```

These symbols play two simultaneous roles:

1. **Racket binders** in the emitted reduce-arm — bound at runtime to
   the concrete sub-values when that arm fires.
2. **References by name** in let-bindings emitted by `specialize-rows`:
   when the pattern at a dispatch column is a variable, the body is
   wrapped with `(let v := <param-at-col>)`, where `<param-at-col>` is
   one of those same symbols.

When `compile-match-tree` recurses on a new dispatch column whose
constructor matches the outer dispatch's constructor — the canonical
case is any recursive list traversal that decomposes
`cons r rest` AND has a separate clause that further dispatches the
structure of `rest` (e.g. `cons r nil` vs `cons r rest`) — the inner
reduce-arm's `field-names` re-use the same Racket symbols. The inner
binders lexically SHADOW the outer ones.

The let-bindings emitted at the outer specialization step reference
`__cons_1` (the outer tail). At runtime, those references resolve
inside the inner reduce-arm to the INNER tail (a sub-list). The
recursive call on `rest` then operates on the wrong sub-list — typically
losing one element per recursion depth.

### Trace: `[sum-rows '[1N 2N 3N]]` pre-fix

- Outer cons arm binds `__cons_0=1N`, `__cons_1=[2N 3N]`.
- Inner dispatch on `__cons_1`: it is also `cons`, so the inner cons
  reduce-arm binds `__cons_0=2N`, `__cons_1=[3N]` — shadowing the outer.
- The third clause's body is wrapped:
    `let r := __cons_0 in let rest := __cons_1 in [+ r [sum-rows rest]]`
  At runtime, `__cons_0`/`__cons_1` resolve to the INNER bindings:
  `r = 2N`, `rest = [3N]`.
- Result: `2 + sum-rows([3N]) = 2 + 3 = 5N`. Expected `6N`.

### Why some shapes don't trigger

`dbl-all` (`| nil -> '[] | cons x rest -> [cons [+ x x] [dbl-all rest]]`)
and `last-elem` work correctly because they have only ONE cons clause.
Their inner `compile-match-tree` recursion lands on an "all variable"
row, lowers via `wrap-variable-bindings` directly, and never builds
an inner reduce-arm whose binders shadow the outer's. The bug requires
TWO cons-shaped clauses where the inner column dispatches on a sub-pattern
of the same constructor. The canonical case is `cons r nil` + `cons r rest`.

## Fix

Make the field-name symbols globally unique per dispatch site by using
`gensym`:

```racket
(define field-names
  (for/list ([i (in-range n-fields)])
    (gensym (string->symbol (format "__~a_~a_" ctor i)))))
```

The field names are internal artifacts of the compiler — never user-visible,
never inter-arm-shared. Global uniqueness is the structurally correct
identity, and the Racket lexical resolver always picks up the intended
outer/inner scope.

## Verification

### Acceptance file (Phase 0)

`racket/prologos/examples/2026-04-27-match-tree-alias-bug.prologos`
exercises the broken patterns and asserts expected outputs. Pre-fix,
multiple expressions returned wrong values silently; post-fix all are
correct (`6N`, `15N`, `3N`, `0N`, `'[2N 4N 6N]`, `3N`).

### Rackunit tests (Phase 2)

`racket/prologos/tests/test-match-tree-alias.rkt` — 14 tests covering:

| Section | Coverage |
|---|---|
| A | Canonical reproducer (`sum-rows`): 3-elem, 5-elem, singleton, empty |
| B | List length: 3-elem, 7-elem |
| C | Head-binding correctness on summed rows |
| D | Triple-nested decomposition (`cons _ [cons _ rest]`) |
| E | Edge case: shadowed variable name `rest` in two clauses |
| F | Recursive map (single cons clause — regression for the simpler path) |
| G | Non-recursive compound patterns (regression coverage) |
| H | Larger payload (10-element list) |
| I | Multi-arg defn with cons on both args (`zip-sum`) |

All 14 pass with the fix; tests A1, A2, B1, B2, C, D, E, H, and I would
silently produce wrong values without it.

### Test suite

Full suite (`racket tools/run-affected-tests.rkt --all`) shows 13
pre-existing failures, all confirmed against `origin/main` (`c769e62`)
and unrelated to this fix:

- 7 tests fail with `prologos/propagator: collection not found`
- 2 tests fail with `rackcheck: collection not found`
- 3 tests fail with `current-mult-meta-store: unbound identifier`
  (retired symbol per `metavar-store.rkt` PPN 4C S2.e-iv-c, 2026-04-25)
- 1 test (`test-pvec.rkt:292`) had a pre-existing `def + eval with PVec`
  failure
- 2 failures in `test-rat-literal-in-list.rkt` were pre-existing

The targeted match/pattern test files all pass with the fix:
`test-pattern-defn-01`, `test-pattern-defn-02`, `test-int-patterns-01`,
`test-match-builtins`, `test-multi-body-defn`, `test-unified-match-01`,
plus the new `test-match-tree-alias`.

## Files touched

- `racket/prologos/macros.rkt` — single 3-line edit to `compile-match-tree`'s
  `field-names` generation (lines ~9251).
- `racket/prologos/examples/2026-04-27-match-tree-alias-bug.prologos` — new.
- `racket/prologos/tests/test-match-tree-alias.rkt` — new.
- `docs/tracking/2026-04-27_match-tree-alias-fix.md` — this doc.

## Follow-ups

1. **`test-defn-multiarg-patterns.rkt` retired-symbol failure** (out of
   scope here): the `current-mult-meta-store` parameter was retired in
   PPN 4C S2.e-iv-c (commit on 2026-04-25). Three tests still reference
   it. Removing the now-unbound `parameterize` clause unblocks them. With
   that done, the file's `marg/eigentrust-sum-rows-*` tests — which
   currently work around the bug at empty + singleton inputs — should be
   strengthened to also exercise the multi-element case (`'[1N 2N 3N]`)
   that the fix unlocks. The comments around line 170 reference this
   "latent compile-match-tree bug" as orthogonal; with the fix landed,
   that paragraph can be deleted.

2. **Pattern compiler architectural follow-up**: the field-names live
   in two roles (Racket binders + symbol references in let-bindings).
   A purely structural fix would lift the variable bindings BEFORE the
   inner dispatch is constructed — capturing the value into a fresh
   binder at the outer scope so no shadowing is possible regardless
   of name choice. The `gensym` fix is correct and minimal; the
   structural refactor is a nice-to-have, not a requirement.

3. **`pattern-is-simple-flat?` audit**: per `.claude/rules/pipeline.md`'s
   "New Pattern Kind" checklist, the fast-path classifier and slow-path
   compiler should always be updated together. This fix touches only
   the slow path (`compile-match-tree`); confirmed the fast path
   (`pattern-is-simple-flat?`) does not produce nested compound dispatch
   and thus is not affected by the same bug.
