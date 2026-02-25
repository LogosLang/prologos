# Lattice Trait + Standard Instances (Logic Engine Phase 1 + 1b)

**Created**: 2026-02-24
**Completed**: 2026-02-24
**Plan file**: `.claude/plans/buzzing-launching-pascal.md`
**Purpose**: Establish the `Lattice` trait as the algebraic foundation for monotonic computation (propagators, ATMS, tables in later phases).

---

## Status Legend

- ✅ **Done** — implemented, tested, passing

---

## Summary

| Component                    | Status | Details                                        |
|------------------------------|--------|------------------------------------------------|
| `lattice-trait.prologos`     | ✅     | 3-method trait: `bot`, `join`, `leq`           |
| `lattice-instances.prologos` | ✅     | 2 data types + 5 instances + helpers (clean WS)|
| `namespace.rkt`              | ✅     | Lattice added to prelude tiers 2+3             |
| `dep-graph.rkt`              | ✅     | Lib deps + test deps added                     |
| Zero-arg `defn`              | ✅     | Language feature: `defn name [] <T> body`      |
| `test-lattice.rkt`           | ✅     | 28 tests, all passing                          |
| Full suite                   | ✅     | 3688 tests, 166 files, all pass                |

---

## Phase 1: Lattice Trait + Standard Instances ✅

### Files Created

| File | Description |
|------|-------------|
| `lib/prologos/core/lattice-trait.prologos` | Lattice trait definition (3 methods) |
| `lib/prologos/core/lattice-instances.prologos` | Data types, helpers, 5 lattice instances |
| `tests/test-lattice.rkt` | 28 tests (9.7s runtime) |

### Files Modified

| File | Change |
|------|--------|
| `namespace.rkt` | Tier 2: Lattice trait; Tier 3f: lattice instances |
| `tools/dep-graph.rkt` | Library deps + test deps for lattice files |
| `macros.rkt` | Eta-expansion fix for multi-method parametric trait dicts |

---

## Phase 1b: Zero-arg `defn` + Clean Surface Syntax ✅

Phase 1 used three workarounds due to language limitations:
1. Manual sexp dicts for Bool/Interval `impl` (zero-arg `defn` rejected)
2. Raw `(def ... (Pi ...))` for map helpers (QTT closure issue — now resolved)
3. Curried spec style (`A -> B -> C`) where uncurried (`A B -> C`) is cleaner

Phase 1b fixed all three: enabled zero-arg `defn` as a language feature and rewrote `lattice-instances.prologos` to use clean surface syntax throughout — no sexp fallbacks, no raw Pi types.

### Changes Made

| File | Change |
|------|--------|
| `macros.rkt` | Remove `(not (null?))` guard from `spec-bare-param-list?` |
| `parser.rkt` | Remove 3 guards rejecting empty param brackets (lines 2580, 2655, 2876) |
| `lattice-instances.prologos` | Full rewrite: clean spec/defn, uncurried specs, `impl` blocks for all 5 instances |
| `test-lattice.rkt` | +3 zero-arg defn regression tests (28 total) |

### Zero-arg `defn` — 4 Guard Fixes

All four changes removed `(not (null? ...))` checks that rejected empty param brackets `[]`. The downstream code (`decompose-spec-type`, `inject-spec-into-defn`, `parse-defn-bare-params`) already handled zero params correctly.

| Location | Guard Removed | What It Enables |
|----------|--------------|-----------------|
| `macros.rkt` `spec-bare-param-list?` | `(not (null? lst))` | Empty bracket recognized as bare param list |
| `parser.rkt` bare-params dispatch | `(not (null? elems))` | `defn name [] <T> body` dispatches correctly |
| `parser.rkt` `parse-defn-with-implicits` | `(not (null? elems))` | `defn name {A} [] <T> body` — zero explicit + implicits |
| `parser.rkt` `parse-defn-binders` | Error on `(null? parts)` → return `'()` | Defensive: empty binders instead of error |

Supported forms:
- `defn name [] <RetType> body` — inline return type
- `spec name -> RetType` + `defn name [] body` — spec-provided return type
- `defn name {A : Type} [] <A> body` — zero explicit params with implicit type params

### `lattice-instances.prologos` Rewrite

**Before (Phase 1)**: Three styles of definitions mixed together:
- Clean `impl` blocks (FlatVal, Set, Map — parametric, zero-arg `bot` worked due to injected constraint dict param)
- Manual sexp dicts `(def Bool--Lattice--dict (pair ...))` (Bool, Interval — monomorphic, zero-arg blocked)
- Raw Pi types `(def map-merge-with : (Pi (K :0 (Type 0)) ...))` (map helpers — QTT workaround)

**After (Phase 1b)**: All clean surface syntax:
- All 5 instances use `impl Lattice T` blocks
- All helpers use `spec`/`defn` with uncurried specs
- No sexp fallbacks, no raw Pi types, no manual dict construction

Uncurried spec style:
```
spec rat-max Rat Rat -> Rat           -- was: Rat -> Rat -> Rat
spec set-subset? {A : Type} [Set A] [Set A] -> Bool
spec map-merge-with {K V : Type} [V V -> V] [Map K V] [Map K V] -> [Map K V]
spec interval-intersect Rat Rat Rat Rat -> Interval
```

---

## Data Types

```
data FlatVal {A}       -- Three-point flat lattice
  flat-bot             -- bottom
  flat-val : A         -- concrete value
  flat-top             -- top (conflicting values)

data Interval          -- Numeric interval lattice (monomorphic over Rat)
  interval-bot         -- unconstrained (bottom)
  mk-interval : Rat -> Rat   -- [lo, hi] interval
  interval-top         -- empty/contradiction (top)
```

## Lattice Instances

| Instance                                | `bot`          | `join`              | `leq`          | Style             |
|-----------------------------------------|----------------|---------------------|----------------|-------------------|
| `(Lattice Bool)`                        | `false`        | `or`                | `implies`      | Monomorphic `impl`|
| `(Lattice (FlatVal A)) where (Eq A)`    | `flat-bot`     | same→keep, diff→top | ordering check | Parametric `impl` |
| `(Lattice (Set A)) where (Eq A)`        | `#{}`          | `set-union`         | `set-subset?`  | Parametric `impl` |
| `(Lattice (Map K V)) where (Lattice V)` | `{}`           | pointwise join      | pointwise leq  | Parametric `impl` |
| `(Lattice Interval)`                    | `interval-bot` | intersection        | subsumes       | Monomorphic `impl`|

## Helper Functions

- `rat-max`, `rat-min` — rational comparisons via `rat-le`
- `set-subset?` — fold-based subset check
- `map-merge-with` — merge two maps with value-joining function
- `map-lattice-leq` — pointwise leq over map entries
- `interval-intersect` — interval intersection returning `interval-top` on empty
- `interval-join`, `interval-leq` — full interval lattice operations

---

## Key Design Decisions

1. **All instances use `impl` blocks**: Both monomorphic (Bool, Interval) and parametric (FlatVal, Set, Map) instances use the `impl` macro — no manual sexp dict construction.

2. **Clean spec/defn for all helpers**: `map-merge-with` and `map-lattice-leq` use standard `spec`/`defn` with implicit type params `{K V : Type}`. The QTT closure issue that originally forced raw Pi defs is resolved.

3. **Uncurried spec style**: All specs use the cleaner uncurried form (`A B -> C`) rather than curried (`A -> B -> C`). Both produce the same Pi type underneath.

4. **Data constructor annotations list FIELDS only**: `mk-interval : Rat -> Rat` means two Rat fields; the return type `Interval` is automatically added by the `data` macro.

---

## Key Lessons

### Phase 1

1. **Elaborator implicit-hole insertion**: When a function has N total params (including implicits), calling it with exactly N-explicit args triggers insertion of all implicit holes. This caused Map dict join/leq helper calls to get spurious `?meta` args. **Fix**: Eta-expand helper calls in dict body to provide ALL args (total count), preventing insertion.

2. **Eta-expansion name collisions**: Using original method param names (`a`, `b`) in eta-wrappers shadowed constraint dict variables in scope. **Fix**: Use deterministic unique names (`$eta-0`, `$eta-1`, ...).

3. **`$angle-type` form is FLAT**: The WS reader produces `($angle-type FlatVal A)` not `($angle-type (FlatVal A))`. Type extraction must handle both single and compound type expressions in the flat list.

4. **sexp `spec`/`defn` combo**: In sexp mode, `(spec name (-> A B))` followed by `(defn name ...)` triggers "spec type has no arrow" because `inject-spec-into-defn` looks for `->` symbols at the top level. Tests avoid this by using direct accessor calls instead of spec/defn wrappers.

5. **Integer literals in sexp mode are Int**: Bare `42` is `Int`, not `Nat`. Tests use `Int--Eq--dict` for FlatVal instances.

6. **Map empty display**: Empty maps display as `{map ...}` (opaque), not `{}`. Tests verify map operations via `map-get`/`map-has-key?` on bound results.

### Phase 1b

7. **Zero-arg guards were the only blocker**: All downstream code (`decompose-spec-type`, `inject-spec-into-defn`, `parse-defn-bare-params`) already handles zero params correctly. The four `(not (null?))` guards were defensive checks from Sprint 10 that assumed params are always non-empty.

8. **Parametric `impl` masks zero-arg issue**: For parametric impls (FlatVal, Set, Map), `process-parametric-impl` injects constraint dict params into the bracket, making `[]` become `[$dict]`. This is why zero-arg `bot` worked in parametric impls but not monomorphic ones.

9. **QTT closure issue was already resolved**: The spec/defn interaction with closures capturing higher-order function params inside `map-fold-entries` — which originally forced raw Pi defs — works correctly now. The fix likely came from earlier QTT or elaborator improvements.

---

## Test Categories

| Category           | Count  | What's Verified                                      |
|--------------------|--------|------------------------------------------------------|
| Trait registration | 2      | Accessor works with Bool dict                        |
| BoolLattice        | 4      | bot=false, join=or, leq=implies, idempotency         |
| FlatLattice        | 5      | Data constructors, bot identity, diff-value→top      |
| SetLattice         | 4      | bot=empty, join=union, leq=subset (pos+neg)          |
| MapLattice         | 4      | bot=empty, pointwise join, empty leq, disjoint merge |
| IntervalLattice    | 4      | bot type-check, mk-interval, join, leq               |
| Laws               | 2      | Join commutativity, bot identity                     |
| Zero-arg defn      | 3      | Inline ret type, spec ret type, impl bot accessor    |
| **Total**          | **28** |                                                      |

---

## `macros.rkt` Change: Eta-Expansion for Parametric Trait Dicts

For traits with >1 method (like Lattice with 3 methods), the `process-parametric-impl` function now eta-expands helper calls in the dict body. This prevents the elaborator from inserting unwanted implicit holes when the helper has implicit type parameters.

**Before** (broken for multi-method traits):
```racket
(pair (bot-helper V K $Lattice-V)
  (pair (join-helper V K $Lattice-V)        ;; 3 args = n-explicit → inserts 2 metas!
        (leq-helper V K $Lattice-V)))
```

**After** (correct):
```racket
(pair (bot-helper V K $Lattice-V)
  (pair (fn ($eta-0 :w (Map K V)) (fn ($eta-1 :w (Map K V))
          (join-helper V K $Lattice-V $eta-0 $eta-1)))    ;; 5 args = total → no insertion
        (fn ($eta-0 :w (Map K V)) (fn ($eta-1 :w (Map K V))
          (leq-helper V K $Lattice-V $eta-0 $eta-1)))))
```
