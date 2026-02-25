# Extended Spec Design — Comprehensive Phase 1 Hardening

**Date**: 2026-02-24
**Status**: COMPLETE

## Context

The Extended Spec Design (`docs/tracking/2026-02-22_EXTENDED_SPEC_DESIGN.md`) defines
4 coordinated features. Property keyword hardening was completed earlier this day.
This work addresses the remaining 5 implementable features that require no new R&D
infrastructure.

## What Was Done

### Stage A: `??` Enhanced Typed Hole Diagnostics
- Enhanced `check` handler for `expr-typed-hole` in `typing-core.rkt`
- Pretty-printed expected type via `pp-expr` (instead of raw `format "~a"`)
- Context bindings shown with synthetic names from name supply
- Each binding shows type (pretty-printed with correct name stack) and multiplicity
- Example output:
  ```
  Hole ??goal : Nat
  Context:
    x : Nat  (w)
    y : Nat  (w)
  ```
- Added `require "pretty-print.rkt"` and `racket/string` to typing-core.rkt

### Stage B: `functor` WS-Mode Fix + Hardening
- **Bug fix**: `process-functor` dispatch did NOT call `rewrite-implicit-map` at either
  dispatch point (private line ~987, public line ~1101) — WS-mode functor declarations
  would fail to parse keyword metadata
- Fixed both dispatch points: `(process-functor (rewrite-implicit-map ...))`
- Generic `rewrite-implicit-map` branch (line ~2779) already handles functor correctly —
  no functor-specific branch needed (unlike property, functor has no dash-headed clauses)
- Created `tests/test-functor-ws.rkt` with 11 tests (WS-mode + sexp regression + stdlib)
- Created `lib/prologos/core/type-functors.prologos` with 2 functor declarations:
  - `Xf {A B : Type}` — transducer type
  - `AppResult {A : Type}` — application result type

### Stage C: `:examples` Parsing + Accessor
- Added explicit `:examples` case in `parse-spec-metadata` using `collect-constraint-values`
  — properly collects all parenthesized example forms `(expr => result)` as a list
- Added `:see-also` case (same pattern)
- Added `spec-examples` accessor — returns list of example forms or `#f`
- Added `spec-doc` accessor — returns `:doc` string or `#f`
- Added `spec-deprecated` accessor — returns `:deprecated` message/flag or `#f`
- All exported from `macros.rkt`

### Stage D: `:deprecated` Warnings
- Added `deprecation-warning` struct to `warnings.rkt` with `emit-deprecation-warning!`
  and `format-deprecation-warning`
- Extended `expr-fvar` handler in `typing-core.rkt` to check spec metadata for
  `:deprecated` — emits warning during type inference
- Updated `driver.rkt` to reset `current-deprecation-warnings` per-command and
  append formatted warnings to result output
- Example output:
  ```
  caller : Nat -> Nat defined.
  warning: old-fn is deprecated — use new-fn
  ```

### Stage E: Tracking Updates
- Updated `DEFERRED.md`: all 5 features marked Phase 1 COMPLETE
- Created this tracking document

## Test Summary
- `test-extended-spec.rkt`: 78 tests (65 existing + 13 new)
  - 4 enhanced typed hole tests (context, named, empty context, multi-arg)
  - 4 `:examples` parsing tests (single, multiple, no-examples, => symbol)
  - 2 `:doc` accessor tests
  - 1 combined metadata coexistence test
  - 3 `:deprecated` metadata tests (message, flag, no-deprecated)
  - 1 deprecation warning emission test (end-to-end)
  - 2 `format-deprecation-warning` tests
- `test-functor-ws.rkt`: 11 tests (NEW)
  - 6 WS-mode functor declaration tests
  - 2 sexp-mode regression tests
  - 3 stdlib integration tests
- **Total new tests**: 24

## Files Modified
| File | Changes |
|------|---------
| `racket/prologos/typing-core.rkt` | Enhanced `??` diagnostic, `expr-fvar` deprecation check, added requires |
| `racket/prologos/macros.rkt` | Functor dispatch fix, `:examples`/`:see-also` cases, accessor functions, exports |
| `racket/prologos/warnings.rkt` | `deprecation-warning` struct + emit/format |
| `racket/prologos/driver.rkt` | Reset + display deprecation warnings |
| `racket/prologos/tests/test-extended-spec.rkt` | 13 new tests |
| `racket/prologos/tests/test-functor-ws.rkt` | NEW: 11 tests |
| `racket/prologos/lib/prologos/core/type-functors.prologos` | NEW: Xf + AppResult functor declarations |
| `docs/tracking/DEFERRED.md` | Updated 5 feature statuses |

## What Remains (Phase 2+)
- **QuickCheck**: Executing `:holds` clauses as randomized tests (requires `Gen` trait)
- **Example checking**: Type-checking and running `:examples` entries
- **Proof obligations**: `:properties` → compile-time verification
- **Editor protocol**: Structured hole reports to editor (JSON)
- **Type-aware suggestions**: Matching global bindings for `??` holes
- **Inline law normalization**: Converting trait inline `:laws` to work with `trait-laws-flattened`

## Key Lessons
- `process-command` parameterizes warnings per-command — test deprecation via result
  string, not outer accumulator.
- `process-functor` parses only the FIRST `$brace-params` as params — multi-param
  functors use a single group: `{A B : Type}`, not separate `{A : Type} {B : Type}`.
- `collect-constraint-values` is the right collector for `:examples` — example entries
  are parenthesized forms just like constraints and includes.
- typing-core.rkt already requires macros.rkt and warnings.rkt — no circular dep risk
  for accessing `lookup-spec` and `emit-deprecation-warning!`.
- Adding `require "pretty-print.rkt"` to typing-core.rkt is safe (no cycle).
