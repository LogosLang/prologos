# Int Literal Patterns, Guard Clauses, and Cond Macro

**Status**: COMPLETE
**Date**: 2026-03-08

## Overview

Three features to enable equational-style definitions on `Int`:

1. **Int literal patterns** (`| 0 -> ...`) - bare integers compile to equality dispatch
2. **Guard clauses** (`| pat when guard -> body`) - boolean conditions on pattern arms
3. **Cond macro** (`cond | guard -> body | ...`) - multi-way conditional dispatch

## Design Decisions

### Int Patterns vs Nat Patterns

- `0N`, `1N`, `42N` are **Nat literal patterns** (kind `'numeric`) - desugar to `zero`/`suc` constructor chains
- `0`, `1`, `-1`, `42` are **Int literal patterns** (kind `'int-lit`) - compile to `int-eq` equality checks
- The WS reader distinguishes: `0N` produces `($nat-literal 0)`, bare `0` produces integer `0`
- Nat is for inductive/structural reasoning; Int is for computational code

### Guard Compilation

Guards compile to nested `boolrec` (if/then/else) checks:
- Pattern match fires first
- If pattern matches, guard is checked
- If guard fails, falls through to next arm
- Guard expression may reference pattern-bound variables

### Cond as Sugar

`cond` is a preparse macro that expands to nested `if`:
```
cond | g1 -> b1 | g2 -> b2 | true -> default
==> if g1 b1 (if g2 b2 (if true default __cond-fail))
```

## Implementation

### Files Modified

| File | Changes |
|------|---------|
| `parser.rkt` | `'int-lit` pattern kind for bare integers; `when` guard parsing; inline type spec registration |
| `surface-syntax.rkt` | `guard` field on `match-pattern-arm` and `defn-pattern-clause` |
| `macros.rkt` | Int-lit normalization pass-through; `compile-int-dispatch`; guard threading in `compile-match-tree`; `expand-cond` macro |
| `qtt.rkt` | Lambda hole-domain fix; `expr-hole`/`expr-typed-hole` checkQ cases |
| `driver.rkt` | Debug print cleanup |

### Key Commits

- `8df17c1` - cond macro
- `e16015b` - Int literal patterns
- `ec039dc` - Guard clauses (+ QTT lambda hole fix + inline spec registration)
- `ccfafbe` - Tests + QTT hole handling fix

### Test Files

- `test-int-patterns-01.rkt` - 9 tests
- `test-guards-01.rkt` - 11 tests
- `test-cond-01.rkt` - 9 tests

## Bugs Found and Fixed

1. **QTT lambda hole domain**: When lambda domain was `expr-hole`, QTT checker extended context with hole type instead of Pi domain, causing false multiplicity failures. Fix: mirror `typing-core.rkt` behavior — use Pi domain when lambda domain is a hole.

2. **Inline type spec registration**: `defn f [n : Int] : Int | ...` inline annotations weren't registered as specs, so `compile-pattern-group` got `_ -> _` types. Fix: register spec in `parse-defn-params-and-patterns` when typed params AND return type are present.

3. **QTT typed-hole handling**: `expr-typed-hole` (from cond's `__cond-fail`) had no `checkQ` case, causing QTT failure. Fix: add `checkQ` cases for `expr-hole` and `expr-typed-hole` to succeed with zero usage.

4. **Spec + inline conflict**: Explicit `spec` line combined with `defn f [n : Int] : Int` inline annotation caused "both spec and inline type" error. The inline annotation auto-registers a spec, so the explicit spec is redundant.
