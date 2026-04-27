# Issue #18 — compile-match-tree Field-Name Alias Bug

**Date**: 2026-04-27
**Issue**: [LogosLang/prologos#18](https://github.com/LogosLang/prologos/issues/18)
**Status**: Fixed.
**Branch**: `claude/fix-match-tree-alias-issue18`
**Commits**: `e0c0475` (acceptance) · `6d5f9d1` (fix) · `23b39fd` (tests)
**Files**:
- `racket/prologos/macros.rkt` (one-line fix in `compile-match-tree`)
- `racket/prologos/examples/2026-04-27-match-tree-alias-bug.prologos` (Phase 0 acceptance)
- `racket/prologos/tests/test-match-tree-alias.rkt` (15 rackunit cases)

---

## §1 Summary

A multi-clause `defn` whose pattern decomposes a compound parameter (e.g.
`cons r rest`) and whose body recurses on a sub-binding silently produced
**wrong** results when a sibling clause further dispatched the same
constructor (e.g. `cons r nil` alongside `cons r rest`):

```prologos
spec sum-rows [List Nat] -> Nat
defn sum-rows
  | [nil]            -> 0N
  | [[cons r nil]]   -> r
  | [[cons r rest]]  -> [+ r [sum-rows rest]]

[sum-rows '[1N 2N 3N]]   ;; pre-fix: 5N (WRONG). post-fix: 6N.
```

The bug was silent — no error, no contradiction, no type failure — so any
production code with this shape returned wrong answers. The
`5N`-vs-`6N` discrepancy is in fact `outer-head + inner-head` (1+2+2)
folded over the recursion depth, which is highly diagnostic of the
underlying alias mechanism.

---

## §2 Root Cause — the Alias Mechanism

`compile-match-tree` (in `racket/prologos/macros.rkt`) lowers pattern
clauses to nested `surf-reduce` forms. For each constructor dispatch, it
generates field-binding names for the constructor's arguments:

```racket
;; OLD (broken):
(define field-names
  (for/list ([i (in-range n-fields)])
    (string->symbol (format "__~a_~a" ctor i))))
```

The names are derived **purely** from `(ctor-name + field-index)`. Across
nested dispatches on the **same** constructor, these names are
**identical Racket symbols**.

The compiler also emits `(let v := <param-at-col> in body)` inside
`specialize-rows` BEFORE the inner dispatch is constructed: the symbol
`<param-at-col>` (e.g. `__cons_1`) survives in the body. When that body
is then wrapped inside an inner `(reduce-arm cons (__cons_0 __cons_1) ...)`,
the inner `reduce-arm` rebinds the same symbols. `elaborate-reduce-arm`
walks lexically; the deeper rebinding shadows the outer one. The let's
reference to the OUTER `__cons_1` silently re-resolves to the INNER
cons-tail. The recursive call therefore operates on the wrong sub-list.

The minimal failing arrangement:
1. Two or more clauses dispatch on the same outer constructor (e.g. `cons`).
2. At least two of those clauses further dispatch on the same constructor
   in the same column (e.g. `cons r nil` and `cons r rest` share an inner
   column).
3. The body of one clause references a variable bound at the outer level
   (e.g. `r` in `[+ r [sum-rows rest]]`).

Without (2), the second dispatch never happens and the alias never
manifests — which is why the canonical 2-clause shape (`nil` /
`cons r rest`) used throughout the prelude never tripped the bug. That
is also why the regression went unobserved before the issue: every
recursive list traversal in the standard library uses the 2-clause
form with explicit `match xs`, not multi-clause `defn`.

---

## §3 Fix

`gensym` each dispatch site's field names so they are globally unique.
The recursive elaborator's lexical resolution then always picks up the
intended outer/inner scope.

```racket
;; NEW:
(define field-names
  (for/list ([i (in-range n-fields)])
    (gensym (string->symbol (format "__~a_~a_" ctor i)))))
```

No caller depends on the specific symbol format — the names are private
to `compile-match-tree`. The fix is one diff hunk at
`racket/prologos/macros.rkt:9236-9255`.

### Why not capture-and-let?

An alternative would be to eagerly bind a copy of every constructor
field into a fresh symbol in `specialize-rows` BEFORE the inner dispatch
can shadow. That is more code (every dispatch site gains a let chain
even when it's not needed) and does not address the underlying defect:
the field-name generator was producing **non-fresh** names contrary to
its own comment ("Generate fresh field binding names"). The right fix is
at the source — make the names actually fresh.

---

## §4 Diagnostic Anchors (Pre-Fix Symptoms)

Stripped from the failure logs of running the test file with the fix
reverted:

| Input | Expected | Pre-fix | Mechanism |
|---|---|---|---|
| `sum-rows '[1N 2N 3N]` | `6N` | `5N` | `r` rebound to inner cons-head; tail dispatch loses 1 elem |
| `sum-rows '[1N..5N]` | `15N` | `11N` | Several elements lost across recursion |
| `my-length '[10N..40N]` | `4N` | `2N` | Each recursive step loses one element |
| `product-rows '[2N 3N 4N]` | `24N` | `12N` | `r` is the wrong factor |
| `take3-sum '[1N..5N]` | `6N` | `9N` | Three-deep cons binding all aliased |

The pattern across all five: any time a head-binding flows into a
recursion that re-dispatches the same constructor, the head value is
re-aliased.

---

## §5 Test Coverage

`tests/test-match-tree-alias.rkt` — 15 cases, partitioned:

- **A. Original reproducer**: 4 cases (varying input lengths + edges).
- **B. Length-style traversal idioms**: 2 cases.
- **C. 2-clause regression controls** (alias does NOT trigger): 2 cases.
- **D. Shadowed variable names across clauses**: 2 cases.
- **E. Three-deep nested decomposition**: 1 case.
- **F. Non-recursive multi-clause**: 3 cases.
- **G. Nat dispatch (zero/suc) regression sanity**: 1 case.

All 15 pass with the fix; 5 fail with the fix reverted (exactly the
cases that exercise nested same-ctor dispatch, as expected).

Uses the shared-fixture pattern (`process-string "(ns ...)"` to load
prelude once, then `process-file` via temp file for WS).

---

## §6 Out of Scope

- **PR #16 / #17 (parser bare-token compound patterns)**: the bare-form
  syntax `| nil` / `| cons r rest` (without brackets) is a parser
  concern — the WS reader doesn't auto-pack bare tokens into pat-compound
  in this position. All tests in #18 use the bracketed form
  `[[cons r rest]]`, which the parser already handles.
- **`pattern-is-simple-flat?` fast-path classifier**: untouched. The
  fast path only applies when ALL arms are flat constructor patterns
  with no guards and no nested compounds; it generates `reduce-arm`
  bindings using the user's variable names directly (no `__cons_N`
  symbols), so the alias mechanism does not apply there.
- **`compile-int-dispatch`**: also untouched. It uses `param-names`
  directly (no synthetic `__cons_N` names) and does not have nested
  same-ctor dispatch on its dispatch column.

---

## §7 What This Reveals

1. The "Generate fresh field binding names" comment had been silently
   wrong since the compiler's introduction. The lesson: **a comment
   describing an invariant that the code does not enforce is a bug
   waiting to surface** — the comment ratified our wrong mental model.
2. The 2-clause `nil`/`cons r rest` shape is canonical in the prelude
   (every `match`-style list traversal). The 3-clause shape with
   `cons r nil` middle-clause optimization is uncommon enough that the
   bug went unobserved despite the compiler being years old.
3. **Silent-wrong-results bugs deserve regression coverage as soon as
   diagnosed.** The new test file specifically exercises the alias
   mechanism rather than just checking "the recursion works" — the
   3-clause shape with `cons r nil` middle case is the load-bearing
   regression test.

---

## §8 Follow-ups (None blocking)

- The `__cons_N` legacy comment was removed in the Phase 1 commit.
- The fix is local and minimal; no architectural debt introduced.
- The acceptance file and rackunit tests serve as the long-term
  regression gate. No further work needed for this issue.
