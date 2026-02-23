# Numeric Coercion (Phases 3a-3c)

**Date**: 2026-02-22
**Status**: COMPLETE

## Summary

Added implicit numeric coercion to generic arithmetic operators via a type join
function, with informational warnings for lossy (exact→approximate) coercions.

## Phase 3a: Numeric Type Join

Added `numeric-join` to `typing-core.rkt` — the least upper bound of two numeric types.

### Rules
- **Same type**: identity (only for concrete numeric types; non-numeric returns `#f`)
- **Within exact** (Nat < Int < Rat): wider wins
- **Within posit** (P8 < P16 < P32 < P64): wider wins
- **Cross-family** (exact × posit): posit wins, minimum P32 width

### Helpers
- `exact-numeric-type?` — matches Nat, Int, Rat
- `posit-type?` — matches Posit8, Posit16, Posit32, Posit64
- `exact-rank`, `posit-rank` — ordinal within family
- `exact-type-at-rank`, `posit-type-at-rank` — inverse

## Phase 3b: Coercion in Generic Operators

Updated generic operator type-checking and reduction to accept mixed-type operands.

### typing-core.rkt
- Generic ops now infer both operand types independently and use `numeric-join` for the result type
- Division additionally requires the join type to be divisible
- Replaces the old same-type-only restriction

### reduction.rkt
- `literal->rational`: extract Racket number from any concrete numeric literal
- `literal-type-tag`: classify literal as 'nat, 'int, 'rat, 'p8, 'p16, 'p32, 'p64
- `rational->literal`: construct AST literal from Racket number + target tag
- `type-tag-join`: reduction-level join (mirrors numeric-join logic)
- `reduce-generic-binary`: when operands differ, coerce both to join type and retry

### Examples
```
(+ 3N 4)     → 7 : Int        (Nat coerced to Int)
(+ 3 1/2)    → 7/2 : Rat      (Int coerced to Rat)
(+ 42 ~1.0)  → Posit32        (Int coerced to Posit32)
(lt 3N 4)    → true : Bool    (Nat coerced to Int)
```

## Phase 3c: Coercion Warnings

Added `warnings.rkt` module and integrated into the type-checking pipeline.

### warnings.rkt
- `current-coercion-warnings` — parameter accumulating warning structs per command
- `emit-coercion-warning!` — push a warning (from-type-str, to-type-str)
- `format-coercion-warning` — renders as `"warning: implicit coercion from X to Y (loss of exactness)"`

### typing-core.rkt
- `numeric-join/warn!` — wrapper around `numeric-join` that emits a warning for cross-family coercion

### driver.rkt
- `process-command` resets `current-coercion-warnings` per command
- After result computation, appends formatted warnings as separate lines

### Warning policy
- **Warns**: exact (Nat/Int/Rat) → approximate (Posit) coercion
- **Silent**: same-type, within-exact (Nat→Int, Int→Rat), within-posit (P8→P32)

## Files Modified

| File | Phase |
|------|-------|
| `typing-core.rkt` | 3a, 3b, 3c |
| `reduction.rkt` | 3b |
| `driver.rkt` | 3c |
| `warnings.rkt` | 3c (new) |

## Test Files

- `tests/test-numeric-join.rkt` — 26 tests (Phase 3a)
- `tests/test-numeric-coercion.rkt` — 24 tests (Phase 3b, updated for 3c warnings)
- `tests/test-coercion-warnings.rkt` — 14 tests (Phase 3c)
