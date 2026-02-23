# Phase 2b: Generic Conversion Keywords (from-integer, from-rational)

**Date**: 2026-02-22
**Status**: COMPLETE

## Summary

Added `from-integer` and `from-rational` as generic type-directed conversion keywords.
These are 2-arity keywords: `(from-integer TargetType value)` and `(from-rational TargetType value)`.

## Design

Unlike Phase 2a's generic arithmetic (which infers the type from operands), these conversions
require an explicit target type because the output type differs from the input type:

- `from-integer`: Int -> T where T in {Int, Rat, Posit8, Posit16, Posit32, Posit64}
- `from-rational`: Rat -> T where T in {Rat, Posit8, Posit16, Posit32, Posit64}

The target type is passed as the first argument (a type expression), making these
fully resolvable at both type-check and reduction time without architectural changes.

## AST Nodes (2 new)

- `expr-generic-from-int (target-type arg)` -- Int -> T conversion
- `expr-generic-from-rat (target-type arg)` -- Rat -> T conversion

## Files Modified (10)

1. `syntax.rkt` -- 2 structs + provide + expr?
2. `surface-syntax.rkt` -- 2 surface structs + provide
3. `parser.rkt` -- 2 keyword cases (arity 2)
4. `elaborator.rkt` -- 2 elaboration cases (elaborate both fields)
5. `typing-core.rkt` -- infer cases + 2 helper predicates (from-int-target-type?, from-rat-target-type?)
6. `qtt.rkt` -- 2 inferQ cases (target-type erased, usage from arg)
7. `reduction.rkt` -- iota rules (11 concrete cases) + stuck-term reduction + NF cases
8. `substitution.rkt` -- shift + subst for both fields
9. `zonk.rkt` -- zonk + zonk-at-depth + default-metas for both fields
10. `pretty-print.rkt` -- pp-expr + uses-bvar0? for both fields

## Usage Examples

```
(from-integer Posit32 42)    ;; Int -> Posit32
(from-integer Rat 42)        ;; Int -> Rat (lossless)
(from-integer Int 42)        ;; Int -> Int (identity)
(from-rational Posit32 3/7)  ;; Rat -> Posit32
(from-rational Rat 3/7)      ;; Rat -> Rat (identity)
```

## Reduction Rules

- `from-integer Int (int v)` -> `(int v)` (identity)
- `from-integer Rat (int v)` -> `(rat v)` (lossless promotion)
- `from-integer PositN (int v)` -> `(positN (positN-encode v))` (lossy conversion)
- `from-rational Rat (rat v)` -> `(rat v)` (identity)
- `from-rational PositN (rat v)` -> `(positN (positN-encode v))` (lossy conversion)
- Stuck terms: reduce arg, retry

## QTT

Target type is erased (zero usage). Usage accounting comes from the value argument only.
