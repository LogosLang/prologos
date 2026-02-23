# Generic Arithmetic Operators (Phase 2a)

**Date**: 2026-02-22
**Status**: COMPLETE

## Summary

Added 9 generic arithmetic operator AST nodes that dispatch on concrete numeric types
at reduction time. These provide type-polymorphic `+`, `-`, `*`, `/`, `<`, `<=`, `=`,
`negate`, and `abs` operators across all 7 numeric types (Nat, Int, Rat, Posit8/16/32/64).

## New AST Nodes

### Binary operators (7)
- `expr-generic-add` / `surf-generic-add` -- addition
- `expr-generic-sub` / `surf-generic-sub` -- subtraction
- `expr-generic-mul` / `surf-generic-mul` -- multiplication
- `expr-generic-div` / `surf-generic-div` -- division
- `expr-generic-lt` / `surf-generic-lt` -- less-than comparison
- `expr-generic-le` / `surf-generic-le` -- less-or-equal comparison
- `expr-generic-eq` / `surf-generic-eq` -- equality comparison

### Unary operators (2)
- `expr-generic-negate` / `surf-generic-negate` -- negation
- `expr-generic-abs` / `surf-generic-abs` -- absolute value

## Parser Keywords

- `+`, `-`, `*`, `/` -- binary arithmetic (sexp: `(+ a b)`)
- `<`, `<=`, `=` -- binary comparison (sexp only, since `<` is angle-bracket in WS mode)
- `negate`, `abs` -- unary operators (sexp: `(negate a)`, `(abs a)`)

## Type Restrictions

- **Nat**: No `div`, no `negate` (natural numbers). `sub` uses truncated subtraction.
- **All numeric types**: `add`, `sub`, `mul`, `lt`, `le`, `eq`, `abs`
- **Int, Rat, Posit8-64**: `div`, `negate`

## Files Modified

1. `syntax.rkt` -- 9 struct definitions + provide + expr? predicate
2. `surface-syntax.rkt` -- 9 surface struct definitions + provide
3. `parser.rkt` -- 9 keywords + sexp dispatch cases
4. `elaborator.rkt` -- 9 elaboration cases
5. `typing-core.rkt` -- Type checking with `concrete-numeric-type?` helpers
6. `qtt.rkt` -- Quantitative type tracking for all 9 nodes
7. `reduction.rkt` -- Iota rules for all concrete types + stuck-term + nf
8. `substitution.rkt` -- Shift + subst for all 9 nodes
9. `zonk.rkt` -- All 3 zonk functions (zonk, zonk-at-depth, default-metas)
10. `pretty-print.rkt` -- Display + uses-bvar0? for all 9 nodes

## Reduction Strategy

- **Int/Rat/Posit**: Direct pattern matching on literal structs (e.g., `expr-int`, `expr-rat`, `expr-positN`)
- **Nat**: Handled in `reduce-generic-binary`/`reduce-generic-unary` helpers using `nat-value` + `nat->expr` (since Nat uses suc/zero chains, not a single struct)
- **Stuck terms**: Reduce operands and retry via `reduce-generic-binary`/`reduce-generic-unary`

## Design Decisions

- Generic operators infer operand types and require both operands to have the same concrete numeric type
- No automatic coercion (unlike type-specific operators which coerce Nat->Int, Int->Rat, etc.)
- Division by zero for Int returns the expression unchanged (stuck); Rat division by zero also stuck
- Posit division by zero produces NaR (handled by posit-impl.rkt)
