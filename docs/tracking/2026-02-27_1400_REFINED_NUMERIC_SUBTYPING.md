# Refined Numeric Subtyping

**Date**: 2026-02-27
**Status**: COMPLETE

## Summary

Added registry-based subtype declarations and runtime coercion for refined
numeric types (PosInt, NegInt, Zero, PosRat, NegRat). Functions accepting `Int`
now seamlessly accept `PosInt`, `NegInt`, and `Zero`; functions accepting `Rat`
accept `PosRat` and `NegRat` — supporting the core value of "most-generic
interfaces".

## Subtype Lattice

```
           Rat
          / | \
    NegRat  |  PosRat
         \  |  /
          Int
        / | \
  NegInt Zero PosInt
          |
         Nat
```

## Architecture

### Two Registries (macros.rkt)

- **Subtype registry**: `(hash (cons sub-key super-key) → #t)` — queried by
  `subtype?` in typing-core.rkt
- **Coercion registry**: `(hash (cons sub-key super-key) → (expr → expr))` —
  queried by `try-coerce-via-registry` in reduction.rkt
- Both use `hash` (not `hasheq`) because keys are `cons` pairs requiring
  `equal?` comparison
- Both are `make-parameter` values, threaded through module loading

### Surface Syntax

New `subtype` declaration:
```prologos
subtype PosInt Int          ;; auto-inferred: unwrap single-field constructor
subtype Zero Int via zero-to-int  ;; explicit: nullary ctor needs via function
```

### Dual-Key Registration

Registry entries are stored under **both** FQN and short-name keys:
- FQN (e.g., `prologos::data::refined-int::PosInt`) — for `subtype?` in
  typing-core, since `type-key` extracts FQN from `(expr-fvar name)`
- Short name (e.g., `PosInt`) — for `try-coerce-via-registry` in reduction,
  since `ctor-meta-type-name` stores short names

### Transitive Closure

Computed at registration time: when `PosInt <: Int` is declared and `Int <: Rat`
already exists, `PosInt <: Rat` is automatically registered with composed
coercion (unwrap + int→rat conversion).

## Files Modified

| File | Change |
|------|--------|
| `macros.rkt` | Subtype/coercion registries, built-in subtype registrations, `surf-subtype` pass-through in `expand-top-level` |
| `typing-core.rkt` | `type-key` helper, `subtype?` registry fallback, `base-numeric-type`, extended `numeric-join` |
| `reduction.rkt` | `try-coerce-via-registry`, extended `try-coerce-to-int` and `try-coerce-to-rat` |
| `surface-syntax.rkt` | `surf-subtype` struct |
| `parser.rkt` | `subtype` keyword clause |
| `elaborator.rkt` | `process-subtype-declaration` (~90 lines) |
| `driver.rkt` | `subtype` command handler, registry threading in module loading |
| `refined-int.prologos` | 3 `subtype` declarations (PosInt, NegInt, Zero) |
| `refined-rat.prologos` | 2 `subtype` declarations (PosRat, NegRat) |
| `grammar.ebnf` | `subtype-decl` rule |
| `grammar.org` | Subtype Declarations section |

## Files Created

| File | Description |
|------|-------------|
| `tests/test-refined-subtyping.rkt` | 18 tests: type checker acceptance, runtime coercion, function parameter subtyping, rejection tests, backward compatibility |

## Key Bugs Found & Fixed

1. **`hasheq` vs `hash`**: Registries initially used `hasheq`, but keys are `cons`
   pairs — `eq?` compares identity, not structure. Fixed to `hash` (`equal?`).
2. **`expand-top-level` missing `surf-subtype?` clause**: Without it, subtype
   declarations fell through to the `[else` case and got wrapped in `surf-eval`,
   causing "Cannot elaborate" errors.
3. **`qualify` using raw `ns-context` struct**: The `process-subtype-declaration`
   used `(format "~a::~a" ns-prefix name)` where `ns-prefix` was the full
   `ns-context` struct. Fixed to `(qualify-name name (ns-context-current-ns ns-ctx))`.
4. **Short vs FQN key mismatch**: `lookup-type-ctors` uses short names (from
   `process-data`), `type-key` returns FQN (from `expr-fvar`), `ctor-meta-type-name`
   returns short names. Solved with dual-key registration + `ctor-short-name`
   fallback in `try-coerce-via-registry`.

## Test Count

18 new tests in `test-refined-subtyping.rkt`:
- **A**: Type checker acceptance (6 tests) — PosInt/NegInt/Zero as Int, PosInt as Rat (transitive), PosRat/NegRat as Rat
- **B**: Runtime coercion (5 tests) — int+, rat+, rat* with refined operands
- **C**: Function parameter subtyping (2 tests)
- **D**: Rejection tests (1 test) — Int NOT subtype of PosInt
- **E**: Backward compatibility (4 tests) — Nat<:Int, Eq instances, extractors, smart constructors
