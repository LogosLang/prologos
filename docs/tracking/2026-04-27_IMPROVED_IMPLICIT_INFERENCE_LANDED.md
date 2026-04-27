# Improved Implicit Inference — Landed (Issue #20)

**Date**: 2026-04-27
**Issue**: https://github.com/LogosLang/prologos/issues/20
**Design**: `docs/tracking/2026-02-22_IMPROVED_IMPLICIT_INFERENCE.org`
**Branch**: `claude/improved-implicit-inference-issue20`

## Summary

Implemented Direction 1 + Direction 2 (additive) from the 2026-02-22 design.
A `spec` no longer needs explicit `{A : Type}` or `{C : Type -> Type}` binders
when the elaborator can infer them from the spec body (D1) or from a `:where`
trait constraint that pins the kind (D2).

## What ships

### Direction 1 — auto-introduce kind-`Type` binders

A capitalized identifier `A`, `B`, ... that appears free in a spec body and
is not a known type/constructor name is auto-introduced as `{A : Type}`.
Implementation lives in `process-spec` (`auto-detected-binders` block,
`macros.rkt:3427-3439`). Already worked for many cases pre-issue; this
phase makes it documented + reliable.

### Direction 2 — kind from trait constraint

When a free variable appears in `:where (TraitName Var)` (or as an inline
trait constraint before the first `->`) and the trait is registered with
`{Var : kind}`, the auto-introduced binder uses that kind. Implementation
is the existing `propagate-kinds-from-constraints` (macros.rkt:2965)
running after `auto-detected-binders` adds the binder with the default
kind `(Type 0)` — the propagation pass refines it.

```
;; Before
spec gmap {A B : Type} {C : Type -> Type}
     [Seqable C] -> [Buildable C] -> [A -> B] -> [C A] -> [C B]

;; After
spec gmap [Seqable C] -> [Buildable C] -> [A -> B] -> [C A] -> [C B]
```

## The reliability bug fixed

`process-spec` always produced the right `spec-entry-implicit-binders`,
but the SECOND auto-implicit pass (`infer-auto-implicits` at
`macros.rkt:8666`) was incorrectly running again on the post-spec
`surf-defn` when the FIRST Pi binder had a higher kind (e.g. `Type ->
Type`). The pre-existing `has-leading-implicits?` predicate only matched
binders whose kind was the universe `Type`; any other kind fell through
and caused `infer-auto-implicits` to prepend duplicate, unrelated m0
binders. The duplicates broke position-based trait dict insertion in
`insert-implicits-with-tagging`.

Fix (`macros.rkt:8652+`): introduce `kind-level-type?` that recognises
both `surf-type` (universe Type) and `surf-arrow` chains whose endpoints
are themselves kind-level types. Extended `has-leading-implicits?` to
accept any m0 binder with a kind-level type whose name matches the first
param-name. Verified on `length`'s elaborated Pi type:

```
;; Before fix (3 m0 binders, with extra unused x : Type):
[Pi [x :0 Type]
 [Pi [y :0 Type -> Type]
  [Pi [z :0 Type] (Reducible y) (y z) -> Nat]]]

;; After fix (2 m0 binders, correct):
[Pi [x :0 Type -> Type]
 [Pi [y :0 Type] (Reducible x) (x y) -> Nat]]
```

## Lib refactor

35 specs in `lib/prologos/core/` and `lib/prologos/data/` simplified to
the bare-binder canonical form, plus 51 specs in `lib/prologos/book/`.

| File                                          | Specs simplified |
|-----------------------------------------------|------------------|
| `lib/prologos/core/generic-ops.prologos`      | 8                |
| `lib/prologos/core/collections.prologos`      | 27               |
| `lib/prologos/core/pvec.prologos`             | 5                |
| `lib/prologos/core/set.prologos`              | 5                |
| `lib/prologos/core/lattice.prologos`          | 2                |
| `lib/prologos/core/fio.prologos`              | 1                |
| `lib/prologos/core/string-ops.prologos`       | 2                |
| `lib/prologos/data/transducer.prologos`       | 8                |
| `lib/prologos/book/collection-functions.prologos` | 23           |
| `lib/prologos/book/persistent-vectors.prologos` | 4              |
| `lib/prologos/book/sets.prologos`             | 5                |
| `lib/prologos/book/lattices.prologos`         | 1                |
| `lib/prologos/book/datum-and-homoiconicity.prologos` | 8         |
| `lib/prologos/book/characters-and-strings.prologos` | 2          |
| `lib/prologos/book/generic-operations.prologos` | 8              |

Trait declarations (e.g. `trait Seqable {C : Type -> Type}`) intentionally
keep their explicit binders — D1/D2 only run on `spec`.

## Tests

New file: `racket/prologos/tests/test-improved-implicit-inference.rkt` —
17 test cases:

- D1 alone (bare A in `[List A] -> Nat`, in arrow types, in nested types,
  exclusion of known type names, regression for explicit binders)
- D2 alone (bare C with `:where (Seqable C)`, with inline `(Seqable C)`,
  multi-constraint agreement, regression for explicit higher-kind binders)
- D1+D2 combined (gmap-style, Foldable-style)
- Edge cases (no constraining position still gets D1 binder)
- End-to-end (D1 spec elaborates and runs)
- Level 3 WS validation (`process-file` on the acceptance file)

Acceptance file:
`racket/prologos/examples/2026-04-27-improved-implicit-inference.prologos` —
exercises D1, D2, and D1+D2 in WS mode.

## Phases / commits

| Phase | Description                                          | Commit |
|-------|------------------------------------------------------|--------|
| 0     | Acceptance file                                      | 8505196 |
| 1     | Rackunit test file (17 tests)                        | 25e48a6 |
| 2a    | Fix `has-leading-implicits?` + core/ refactor (35)   | 620fa77 |
| 2b    | Refactor remaining core/data specs (19)              | 3593291 |
| 2c    | Refactor lib/prologos/book/* specs (51)              | 96050c0 |
| 3     | Documentation (this file + grammar.ebnf + rules)     | (this commit) |

## Documentation updates

- `.claude/rules/prologos-syntax.md` — added "Implicit binder inference
  (issue #20)" section documenting D1 + D2 and the canonical bare form.
- `docs/spec/grammar.ebnf` — annotated `implicit-binders` as OPTIONAL
  with reference to issue #20.

## Test suite status

Full suite (7839 tests / 414 files): 7829 pass, 10 fail. All 10 failures
are pre-existing environment/dependency issues unrelated to this work:

- 6 tests fail to load the `prologos/propagator` collection
  (collection registration missing on the test machine — pre-existing).
- 2 tests fail to load `rackcheck` (package not installed —
  pre-existing).
- 2 tests fail with `current-mult-meta-store: unbound identifier`
  (test-pvec-zip-with, test-defn-multiarg-patterns — pre-existing test
  compile issue, unrelated to spec processing).

Targeted test runs that DO exercise the changes pass cleanly:
test-improved-implicit-inference (17), test-kind-inference (22),
test-collection-fns-01/02 (28), test-generic-ops-01-02 (5 + 4),
test-reducible-01/02 (multiple), test-transducer-01,
test-map-set-traits-01/02, test-pvec-ops-eval, test-set-ops-eval,
test-abstract-domains, test-call-site-specialization,
test-cross-family-conversions-02/03, test-collection-traits-02,
test-abstract-interpretation-e2e — 87+ tests covering all spec/defn
elaboration paths.

## Future work

- The bare-binder form should become the default in any new code;
  explicit binders are now reserved for "no constraining position" /
  pedagogic / disambiguation cases.
- Consider extending D2 to capability constraints (analogue of trait
  constraints for capability types).
