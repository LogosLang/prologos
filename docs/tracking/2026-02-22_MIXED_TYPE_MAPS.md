# Mixed-Type Maps

**Date**: 2026-02-22
**Status**: COMPLETE (Phases 1-5)

## Summary

Extended `Map K V` to support heterogeneous value types via union type inference. Map literals with values of different types now auto-infer the value type as a union (e.g., `{:name "Alice" :age zero}` infers `Map Keyword (Nat | String)`). `map-assoc` widens the value type via union when the new value doesn't fit the existing type.

## Changes

### Phase 1: `build-union-type` helper (`unify.rkt`)
- New public function that constructs canonical union types from a list of types
- Reuses existing `flatten-union`, `union-sort-key`, `dedup-union-components`
- Flattens nested unions, sorts, deduplicates

### Phase 2: Widening `infer` rule for `expr-map-assoc` (`typing-core.rkt`)
- Modified infer rule (lines 728-749) to use speculative checking
- If value fits existing value type: no widening (backward compatible)
- If value doesn't fit: infer value type, widen via `build-union-type`
- Uses `save-meta-state`/`restore-meta-state!` for speculative check
- Uses `whnf` to resolve solved metas before building union

### Phase 2b: `infer-level` meta support (`typing-core.rkt`)
- Added `expr-meta` case to `infer-level`: solved metas follow solution chain, unsolved metas default to `just-level(lzero)`
- This enables `is-type` to accept unsolved metas in type position (e.g., map-empty's key/value type args from the elaborator)
- Previously, `(infer {:x zero})` failed because `is-type` couldn't validate fresh metas; now map literal inference works end-to-end

### Phase 2c: `map-get` on union types (`typing-core.rkt`)
- Extended `infer` rule for `expr-map-get` to handle union types
- When the map expression has a union type, extracts Map components via `flatten-union`
- Checks key against each Map component's key type (speculative, with meta state save/restore)
- Returns union of matching value types via `build-union-type`
- Enables chained dot-access on nested mixed maps: `m.address.street` works when `m` is a mixed map containing a nested Map value

### Phase 3: Check rule (no changes needed)
- Existing check rule for `map-assoc` works with union types via speculative union checking (line 1184)

### Phase 4: Tests (`tests/test-mixed-map.rkt`)
- 19 test cases across categories:
  - A. `build-union-type` unit tests (5 tests)
  - B. AST-level infer tests (2 tests)
  - C. Surface sexp mode tests (5 tests)
  - D. Backward compatibility (2 tests)
  - E. Namespace mode tests (2 tests)

### Phase 5: Documentation & Infrastructure
- `tools/dep-graph.rkt`: Added `test-mixed-map.rkt` entry
- `docs/spec/grammar.org`: Added mixed-type map literal examples
- `docs/tracking/DEFERRED.md`: Added future phases

## Files Modified

| File | Change |
|---|---|
| `racket/prologos/unify.rkt` | Added `build-union-type` helper + export |
| `racket/prologos/typing-core.rkt` | Modified `infer` for `expr-map-assoc`; added `infer-level` meta case |
| `racket/prologos/tests/test-mixed-map.rkt` | New: 16 tests |
| `racket/prologos/tools/dep-graph.rkt` | Added test-mixed-map entry |
| `docs/spec/grammar.org` | Added mixed-type map examples |
| `docs/tracking/DEFERRED.md` | Added future phases |

## Design Decisions

1. **Union widening, not record types**: Reuses existing union type infrastructure rather than adding a separate Record type
2. **Speculative check pattern**: Established pattern in the codebase (line 1184) for union checking
3. **whnf for meta resolution**: Solved metas must be resolved via `whnf` before `build-union-type` to avoid raw meta references in union components
4. **Unsolved metas as types**: `infer-level` now treats unsolved metas as valid types (level 0), enabling map literal inference through the full pipeline

## Future Phases (deferred to DEFERRED.md)

- Type narrowing for `map-get` with statically-known keys
- `A?` nilable union syntax (`String?` as sugar for `(String | Nil)`)
- Pattern matching convenience forms for union values
