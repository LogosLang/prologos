# Gate 1 rev 1.5 — Static-eval extension to ctor values
**Date**: 2026-05-02
**Status**: Design (rev 1.5, ctor static-eval variant)
**Branch**: `lowering-yolo`
**Predecessor**:
- [Gate 1 rev 1.0](2026-05-02_GATE1_TAGGED_UNION_DESIGN.md)
- [Gate 2 rev 1.0](2026-05-02_GATE2_NONTAIL_REC_DESIGN.md) — the static-eval substrate

## 1. The remaining gap

After Gate 1 rev 1.0 + Gate 2 rev 1.0, two acceptance examples remain
unsupported:

  - `n9-sums/list-sum-3.prologos` — `cons : A → List A → List A` (recursive)
  - `n9-sums/nested-maybe.prologos` — `some Int (some Int 5)` (nested ctor)

`build-ctor-application` rejects both:
  (a) recursive ctors hard-fail on `(ormap values is-recursive)`
  (b) nested ctors fail `assert-scalar!` because the field arg lowers
      to a `ctor-vt`, not an Int/Bool cell.

Both programs are **fully concrete** — their main definition has no
runtime input. The natural lowering (per Gate 2's pattern) is to fold
the entire match cascade at compile time.

## 2. Approach: extend static-eval with ctor values

Just as Gate 2 extended static-eval to fold concrete-arg recursive
function calls to a literal Int/Bool, Gate 1 rev 1.5 extends it to
fold concrete-arg ctor applications + nested matches to a literal.

  - Add a Racket struct `sctor (name branch fields)` for static-eval
    ctor values. `name` is the ctor symbol, `branch` is its branch
    index, `fields` is a list of statically-evaluated field values
    (Int / Bool / sctor — recursive).
  - Extend `try-static-eval-impl`:
      * `(expr-app ctor-name arg1 ... argk)` where `ctor-name` is a
        registered ctor: build sctor with field values from
        evaluating arg1..argk. Type args are filtered.
      * Bare `expr-fvar` for a nullary ctor: build sctor with no
        fields.
      * `expr-reduce` over an sctor: pick the matching arm by branch
        index, push the arm's field values onto lit-env (mirroring
        build-ctor-match's reverse-cons), recurse on the arm body.
  - Bool/Nat-shaped 2-arm reduces continue to short-circuit on
    boolean/integer scrutinees as today.

## 3. What this enables

For `nested-maybe`:
```
match (some (some 5))
  | none      -> 100
  | some inner -> match inner
                    | none -> 1
                    | some x -> x
```
Folds:
  - `(some (some 5))` → `(sctor 'some 1 [(sctor 'some 1 [5])])`
  - Outer match: branch 1 wins → push `(sctor 'some 1 [5])`
  - Inner match scrutinee = bvar 0 = `(sctor 'some 1 [5])` → branch 1
  - Inner body = bvar 0 = `5`. Result: `5`.

For `list-sum-3`:
```
match (cons 1 (cons 2 (cons 3 nil)))
  | nil       -> 0
  | cons a r  -> match r
                   | nil       -> a
                   | cons b s  -> match s
                                    | nil       -> int+ a b
                                    | cons c _  -> int+ a (int+ b c)
```
Folds: outermost cons → branch 1 → bind a=1, r=cons-2-3-nil; inner
match → bind b=2, s=cons-3-nil; innermost match → cons-arm → bind
c=3, _=nil; body = int+ 1 (int+ 2 3) = 6. Result: `6`.

## 4. Scope (rev 1.5)

  In scope:
    - All Gate 1 rev 1.0 cases (non-recursive ctors).
    - Recursive ctors when the entire program folds at compile time
      (no runtime ctor allocation needed).
    - Nested ctors when the entire program folds at compile time.
    - Match cascades over nested / recursive sctors.
    - Mixed: ctor + arithmetic + recursive function calls all in the
      same fold.

  Out of scope (deferred to rev 2):
    - Runtime construction of recursive ctors (e.g., `cons x ys`
      where `x` is a runtime-cell value).
    - Programs whose result is a ctor value (e.g., `def main : List
      Int := cons 1 nil`).
    - Heap-backed runtime representation.

## 5. Implementation in `ast-to-low-pnet.rkt`

  - Add `(struct sctor (name branch fields) #:transparent)`.
  - Add `sctor?` predicate.
  - Extend `foldable?` (sctors are foldable).
  - Extend `try-static-eval-impl`:
      * For `(expr-fvar n)` not in lit-env scope: if `n` is a
        registered nullary ctor, return `(sctor n branch '())`.
      * For `(expr-app head args...)` where `peel-fvar-app-chain`
        returns a ctor name: filter out type args, evaluate value
        args, and return `(sctor name branch field-vals)`.
      * For `(expr-reduce s arms _)` where the scrutinee folds to an
        sctor: find the arm whose ctor-name matches `(sctor-name sv)`,
        push field values (in REVERSE, mirroring build-ctor-match) to
        lit-env, recurse on body.
  - Extend the build dispatch top of `build`: if static-eval
    succeeds with an sctor, fall through to the existing build-uncached
    pipeline (since we don't yet emit ctor literals as runtime cells —
    only scalars). Programs whose main result is a ctor still error
    cleanly.
  - Update `build-ctor-application`'s "scalar fields only" assertion:
    if static-eval can fold the field expression to a literal scalar
    (or further-foldable sctor that resolves to a scalar via match),
    accept it; otherwise keep the rev 1.0 error.

## 6. Acceptance: existing n9-sums suite, no new files needed

  - `nested-maybe.prologos` should now PASS (was unsupported).
  - `list-sum-3.prologos` should now PASS (was unsupported).
  - All other n9-sums (4 of 6) continue to PASS (no regression).

If both pass round-trip + native, **Gate 1 rev 1.5 is met**, and the
`unsupported` count in `tools/round-trip-acceptance.rkt` drops from 2
to 0.

## 7. What rev 1.5 still doesn't enable

Programs with runtime ctor construction. For example:
```
defn add-to-list [x xs] -> List Int
  cons x xs

def main : Int := length (add-to-list 1 (cons 2 nil))
```
The `add-to-list 1 (cons 2 nil)` could fold (rev 1.5), but a real
runtime use-case looks more like:
```
defn build-list [n] -> List Int
  match n
    | 0 -> nil
    | _ -> cons n (build-list (int- n 1))
```
For runtime `n`, this needs Gate 2 rev 2 (PReduce / runtime call
stack) AND Gate 1 rev 2 (heap-backed runtime ctors). Both deferred.

## 8. Risk assessment

  - **Compile-time blowup**: list-sum-3 has ~3 cons cells and ~3 match
    levels — well within the existing `MAX-STATIC-EVAL-STEPS=200000`
    budget. Pathological cases (constructing a 100k-element list
    statically) will abort cleanly and fall through.
  - **Wrong-result risk**: the static-eval semantics for
    ctor-application + match must match build-ctor-application +
    build-ctor-match. We mirror the field-binding order convention
    (reverse onto env so bvar 0 = first-declared field).
  - **Type-arg filtering**: `cons Int 1 (cons Int 2 ...)` has the
    leading `Int` (an `expr-Int`) that must be filtered out. Use the
    same `type-arg?` predicate that `build-ctor-application` uses.
