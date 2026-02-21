# Prologos Whole-Library Generification

**Created**: 2026-02-20
**Completed**: 2026-02-20
**Plan file**: `.claude/plans/buzzing-launching-pascal.md`
**Purpose**: Rewrite library functions with most generic types; add trait instances for all collection types; expand prelude.

---

## Status Legend

- ✅ **Done** — implemented, tested, merged

---

## Phase Summary

| Phase | Goal | Status | Tests | Commit |
|-------|------|--------|-------|--------|
| 3a | Reduction stubs (map-keys, map-vals, set-to-list) | ✅ | 8 new | b69ef62 |
| 3b | PVec trait instances + pvec-ops | ✅ | 8+17 new | 30e80da |
| 3c | Map/Set trait instances + ops | ✅ | 27 new | 095af9c |
| 3d | LSeq trait instances | ✅ | 11 new | 40c84c1 |
| 3e | Identity traits + generic numerics | ✅ | 22 new | 738b138 |
| 3f | Collection conversion functions | ✅ | 11 new | b3616e2 |
| 3g | Prelude expansion | ✅ | 17 new | 41c40a1 |
| 3h | Syntax verification + docs | ✅ | 5 new | (this) |

**Total new tests**: ~118
**Final test count**: 2912+ (up from ~2786)

---

## Key Design Decisions

1. **Identity traits**: `AdditiveIdentity` (zero) + `MultiplicativeIdentity` (one) as separate traits; Num bundle NOT updated (avoids requiring Posit identity instances)
2. **Map HKT limitation**: Map has `{C : Type -> Type -> Type}` (2 params), but Seqable/Foldable/Buildable expect `{C : Type -> Type}` (1 param). Decision: standalone `map-ops` functions only, no trait instances for Map Seqable/Buildable/Foldable
3. **Naming**: Prefixed unqualified (`pvec-map`, `set-filter`, `map-fold-entries`) — no collisions with List ops
4. **Conversions**: Named functions `vec`, `list-to-seq`, `pvec-to-seq`, `set-to-seq`, `into-vec`, `into-list`, `into-set`
5. **LSeq as hub**: All collections convert to/from LSeq (spoke-and-hub model)
6. **`set-from-list` multiplicity workaround**: `set-from-list` declares `A :w` but trait instances use `A :0`; all Set construction uses manual fold with `set-insert` instead

---

## New Files Created

### Trait Instance Files (lib/prologos/core/)
- `seqable-pvec.prologos` — Seqable PVec (via pvec-to-list → list-to-lseq)
- `buildable-pvec.prologos` — Buildable PVec (from-seq via pvec-from-list, empty = pvec-empty)
- `indexed-pvec.prologos` — Indexed PVec (bounds-checking nth, length, update)
- `foldable-pvec.prologos` — Foldable PVec (via pvec-to-list → foldr)
- `functor-pvec.prologos` — Functor PVec (map via to-list → list-map → from-list)
- `keyed-map.prologos` — Keyed Map (get/assoc/dissoc via AST keywords)
- `setlike-set.prologos` — Setlike Set (member/insert/delete)
- `seqable-set.prologos` — Seqable Set (set-to-list → list-to-lseq)
- `buildable-set.prologos` — Buildable Set (fold with set-insert, NOT set-from-list)
- `foldable-set.prologos` — Foldable Set (set-to-list → foldr)
- `seq-lseq.prologos` — Seq LSeq (first/rest/empty? via pattern match)
- `foldable-lseq.prologos` — Foldable LSeq (strict, via lseq-to-list → foldr)
- `seqable-lseq.prologos` — Seqable LSeq (identity)
- `buildable-lseq.prologos` — Buildable LSeq (identity)

### Operation Modules (lib/prologos/core/)
- `pvec-ops.prologos` — pvec-map, pvec-filter, pvec-fold, pvec-any?, pvec-all?, pvec-from-list-fn, pvec-to-list-fn
- `map-ops.prologos` — map-map-vals, map-filter-vals, map-fold-entries, map-keys-list, map-vals-list, map-merge
- `set-ops.prologos` — set-map, set-filter, set-fold, set-any?, set-all?, set-to-list-fn, set-from-list-fn

### Identity Traits + Generic Numerics (lib/prologos/core/)
- `additive-identity-trait.prologos` — trait AdditiveIdentity {A}, zero : A
- `multiplicative-identity-trait.prologos` — trait MultiplicativeIdentity {A}, one : A
- `identity-instances.prologos` — Int/Rat/Nat instances (dict IS the value)
- `generic-numeric-ops.prologos` — sum, product, int-range

### Collection Conversions (lib/prologos/core/)
- `collection-conversions.prologos` — vec, list-to-seq, pvec-to-seq, set-to-seq, into-list, into-vec, into-set

### Test Files (tests/)
- `test-pvec-traits.rkt` (17 tests)
- `test-map-set-traits.rkt` (27 tests)
- `test-lseq-traits.rkt` (11 tests)
- `test-identity-generic-ops.rkt` (22 tests)
- `test-collection-conversions.rkt` (11 tests)
- `test-prelude-collections.rkt` (17 tests)
- `test-syntax-verify.rkt` (5 tests)

---

## Implementation Notes

### Phase 3a — Reduction Stubs (DONE)
- Added `racket-list->prologos-list` and `racket-pairs->prologos-pair-list` helpers to reduction.rkt
- Completed `map-keys`, `map-vals`, `set-to-list` reduction stubs
- Fixed typing-core.rkt and qtt.rkt for correct result types

### Phase 3b — PVec Trait Instances (DONE)
- 2 new AST nodes: `expr-pvec-to-list`, `expr-pvec-from-list` (full 14-file pipeline each)
- `list-type-fvar` helper for resolving qualified `prologos.data.list::List`
- QTT fix: `inferQ` must return result type, not input type, for AST keyword nodes
- 5 trait instance files + pvec-ops module

### Phase 3c — Map/Set Trait Instances (DONE)
- QTT fix: same result-type bug for `expr-map-keys`, `expr-map-vals`, `expr-set-to-list`
- `map-has-key?` parser keyword needs `?` suffix (not `map-has-key`)
- `set-from-list` `:w` vs `:0` multiplicity conflict: replaced with manual fold
- 7 new .prologos files + 27 tests

### Phase 3d — LSeq Trait Instances (DONE)
- 4 new .prologos files — all worked on first try (no bugs!)
- Identity pattern for Seqable/Buildable (LSeq IS a lazy sequence)

### Phase 3e — Identity Traits + Generic Numerics (DONE)
- Single-method traits: dict IS the value (zero/one element itself)
- `(def ... : [AdditiveIdentity Int] 0)` pattern — not `impl`/`defn`
- `sum`/`product` pass `reduce` with explicit type args `A A`
- `int-range` uses `int-lt` (exclusive end) and explicit `cons Int` / `nil Int`

### Phase 3f — Collection Conversions (DONE)
- 7 conversion functions in one module
- `into-set` uses manual fold (same `:w`/`:0` workaround)

### Phase 3g — Prelude Expansion (DONE)
- Added ~45 new `require` lines to namespace.rkt prelude
- Type constructor names (`AdditiveIdentity`) are deftypes, not terms — `(infer X)` doesn't work; use `(def x : (X A) val)` to test accessibility
- All existing tests continue to pass (prelude is backwards-compatible)

### Phase 3h — Syntax Verification (DONE)
- Verified: `@[...]` (PVec), `~[...]` (LSeq), `{:k v}` (Map), `~1.5` (Posit32), `'[...]` (List)
- PVec/Map literals require type annotations for inference

---

## Key Lessons

1. **QTT result types**: For AST keyword nodes in `qtt.rkt inferQ`, always return the RESULT type (via `infer ctx (expr-...)`) not the INPUT type. This was the single most common bug across Phases 3b-3c.
2. **`:w` vs `:0` multiplicity**: Library functions with `(Pi (A :w Type) ...)` can't be called from trait instances where type arg is `A :0 (erased)`. Workaround: manual fold with AST keywords that have erased type args.
3. **Parser keyword naming**: `set-member?`, `map-has-key?` — the `?` is part of the name.
4. **Single-method trait dict IS the function/value**: No wrapper struct. `Add A = A -> A -> A`.
5. **process-string uses sexp reader**: Test preambles must use sexp syntax `(ns test)`, `(require (...))`.
6. **Prelude error swallowing**: `process-ns-declaration` has `(with-handlers ([exn:fail? void]) ...)` — prelude loading errors are silent.
7. **Type constructors vs terms**: `(infer Add)` doesn't work because `Add` is a deftype. Test with `(def x : (Add Nat) ...)`.
