# Property Keyword — Phase 1 Hardening

**Date**: 2026-02-24
**Status**: COMPLETE

## Context

The Extended Spec Design (`docs/tracking/2026-02-22_EXTENDED_SPEC_DESIGN.md`, Part IV)
defines `property` as named, parameterized conjunction of propositions — analogous to
`bundle` for traits. Phase 1 parsing/storage was already implemented in `macros.rkt`
(structs, registry, parser). This work hardens Phase 1 by closing 6 identified gaps.

## What Was Done

### Stage A: `:includes` Flattening + `/`-Qualified Names
- `flatten-property` function in `macros.rkt` — recursively resolves `:includes`,
  produces flat list of `property-clause` structs with `/`-qualified names
- Cycle detection via visited set
- Missing include reference → error
- Name convention: `monoid-laws/left-identity`, `semigroup-laws/associativity`

### Stage B: Cross-Validation + Accessor Functions
- `spec-properties` accessor — returns `:properties` metadata from spec entry
- `trait-laws-flattened` accessor — returns flat clause list from trait's `:laws` refs
- Graceful handling: missing property ref in `:laws` returns `'()` (not error)

### Stage C: Standard Library Property Declarations
- `lib/prologos/core/algebraic-laws.prologos` — 4 property declarations:
  - `semigroup-laws` (1 clause: associativity)
  - `monoid-laws` (2 clauses + includes semigroup-laws → 3 flattened)
  - `functor-laws` (2 clauses: identity, composition)
  - `commutative-add-laws` (1 clause: commutativity)
- These are metadata-only (no code generation) — Phase 2 will execute `:holds`

### Stage D: WS-Mode Integration + `rewrite-implicit-map` Fix
- Fixed `rewrite-implicit-map` for `property` forms: dash-headed children (clauses)
  are preserved as body forms; keyword-headed children become `$brace-params` metadata
- Flattens internal keyword-headed children of dash clauses:
  `(- :name "refl" (:holds expr))` → `(- :name "refl" :holds expr)`
- Applied rewrite at both public and private-form dispatch points in `preparse-expand-all`

### Stage E: Tracking Updates
- Updated `DEFERRED.md`: property keyword Phase 1 marked COMPLETE
- Created this tracking document

## Test Summary
- `test-extended-spec.rkt`: 61 tests (43 existing + 18 new)
  - 10 flatten-property tests (simple, include, transitive, cycle, missing, multiple)
  - 3 spec-properties accessor tests
  - 3 trait-laws-flattened tests
  - 2 misc (holds-expr preservation, empty property)
- `test-property-ws.rkt`: 12 tests (NEW)
  - 4 WS-mode property declaration tests
  - 2 sexp spec/trait with :properties/:laws tests
  - 6 stdlib algebraic-laws.prologos integration tests
- **Total new tests**: 30

## Files Modified
| File | Changes |
|------|---------|
| `racket/prologos/macros.rkt` | `flatten-property`, `spec-properties`, `trait-laws-flattened`, property-specific `rewrite-implicit-map` branch, rewrite applied at dispatch |
| `racket/prologos/tests/test-extended-spec.rkt` | 18 new tests |
| `racket/prologos/tests/test-property-ws.rkt` | NEW: 12 tests |
| `racket/prologos/lib/prologos/core/algebraic-laws.prologos` | NEW: 4 property declarations |
| `docs/tracking/DEFERRED.md` | Updated property status |

## What Remains (Phase 2+)
- **Phase 2**: QuickCheck-style execution of `:holds` clauses as randomized tests
  - `Gen` trait for type-directed random generation
  - Property checking for `:properties` and `:laws` on trait instances
  - Contract wrapping: `:pre`/`:post` generate runtime checks with blame
- **Phase 3**: Refinement types — `:properties` → compile-time proof obligations
- **Phase 4**: Interactive theorem proving — editor protocol for `??` holes

## Key Lessons
- WS reader wraps keyword children as lists: `:holds expr` → `(:holds expr)`.
  `rewrite-implicit-map` must flatten these for property clauses.
- `preparse-expand-all` dispatches consumed forms (property, trait, spec, bundle)
  BEFORE `preparse-expand-subforms` — rewrite must be applied at dispatch point.
- `/`-qualified names parallel trait method scoping: `functor-laws/identity` etc.
- `seteq` (not `set`) for eq?-based set in Racket — cycle detection.
