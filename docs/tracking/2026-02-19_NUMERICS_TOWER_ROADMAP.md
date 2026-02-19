# Prologos Numerics Tower — Roadmap & Work Log

**Created**: 2026-02-19
**Implementation guide**: `IMPLEMENTATION_GUIDE_PROLOGOS_NUMERICS.md` (1527 lines)
**Memory roadmap**: `memory/numerics-tower-roadmap.md`
**Lessons learned**: `memory/numerics-lessons.md`
**Purpose**: Track implementation progress for the numerics tower. Cross-referenced against commit history, implementation guide, and test counts.

---

## Status Legend

- ✅ **Done** — implemented, tested, merged
- 🔧 **In Progress** — actively being worked on
- ⬜ **Not Started** — planned but no work yet
- ⏭️ **Deferred** — consciously postponed with rationale

---

## Architecture Overview

The Prologos numerics tower follows three design principles:

1. **Peano at type-level, BigInt at runtime** — Type-level `Nat` uses Peano for dependent typing; QTT erases it. Runtime uses Racket's GMP-backed arbitrary-precision integers.
2. **Exact by default** — `42` is Nat (parsed as Peano), `3.14` is Rat. Use `~` prefix for approximate (`~3.14` → Posit32).
3. **Posit as default approximate type** — Not IEEE float. Tapered precision (2022 Standard, es=2) for scientific computing. IEEE Float types are separate, for C FFI interop.

**Numeric Families:**
- **Exact:** `Nat <: Int <: Rat` (lossless widening)
- **Posit:** `Posit8 <: Posit16 <: Posit32 <: Posit64` (tapered precision)
- **Float:** `Float32 <: Float64` (IEEE 754, NOT default — for C FFI interop only)

**Traits for operations** — No ad-hoc overloading. Each operation (Add, Mul, Eq, Ord, etc.) is a single-method trait. Bundles (Num, Fractional) compose traits.

**Within-family automatic, cross-family explicit** — `Nat→Int→Rat` automatic subtyping. `Rat↔Posit` requires explicit `From`/`TryFrom`/`Into`.

---

## Phase 1: Posit8 ✅ COMPLETE

**Goal**: First approximate numeric type — 8-bit posit (2022 Standard).
**Commit**: `2401a6e` (initial posit8 — exact hash from early development)
**Guide reference**: Section 6 (Posit Arithmetic)

### What was built

- 13 AST nodes: `expr-Posit8`, `expr-posit8`, `expr-p8-add/sub/mul/div`, `expr-p8-neg/abs/sqrt`, `expr-p8-lt/le`, `expr-p8-from-nat`, `expr-p8-if-nar`
- `posit-impl.rkt` — pure Racket decode→rational→compute→encode implementation
  - Posit 2022 Standard format: sign + regime + exponent (es=2) + fraction
  - NaR (Not a Real) represented by MSB-only set bit pattern
  - All arithmetic through exact rational intermediary (no floating-point contamination)
- Full 14-file pipeline integration: syntax → surface-syntax → parser → elaborator → typing-core → qtt → reduction → substitution → zonk → pretty-print

### Tests

- 18 unit tests in `test-posit-impl.rkt` (pure Racket posit decode/encode)
- 23 pipeline tests in `test-posit8.rkt` (type formation, literals, operations, e2e)
- **Total tests after phase**: 41 (posit-specific)

---

## Phase 2: Int + Rat ✅ COMPLETE

**Goal**: Arbitrary-precision exact arithmetic types.
**Commits**: `c043b49` (Int), `b215722` (Rat), `1cac097` (match patterns)
**Guide reference**: Section 5 (Exact Arithmetic)

### What was built

**Int (arbitrary-precision integers):**
- 11 AST nodes: `expr-Int`, `expr-int`, `expr-int-add/sub/mul/div/mod`, `expr-int-neg/abs`, `expr-int-lt/le/eq`
- Conversion: `expr-from-nat` (Nat→Int)
- Racket exact-integer backed (GMP arbitrary precision, no overflow)

**Rat (exact rationals):**
- 13 AST nodes: `expr-Rat`, `expr-rat`, `expr-rat-add/sub/mul/div`, `expr-rat-neg/abs`, `expr-rat-lt/le/eq`, `expr-rat-numer/denom`
- Conversion: `expr-from-int` (Int→Rat)
- Racket exact-rational backed (GMP canonicalized numerator/denominator)

**Numeric literal patterns in match:**
- Int and Rat literals work in `match` expressions
- Commit `1cac097` added pattern support

### Tests

- 29 tests in `test-int.rkt` (type formation, literals, operations, match patterns)
- 31 tests in `test-rat.rkt` (type formation, literals, operations, numer/denom extraction)

---

## Phase 3: Extended Posit Widths + Numeric Infrastructure ✅ ALL COMPLETE

### Phase 3a: Posit16/32/64 Core Types ✅ COMPLETE

**Goal**: Complete posit type family across all standard widths.
**Commit**: `616e689` — "Add Posit16, Posit32, Posit64 types and generalize posit-impl.rkt"
**Guide reference**: Section 6

#### What was built

- 39 AST nodes per width (13 × 3): same pattern as Posit8 — type, literal, add/sub/mul/div, neg/abs/sqrt, lt/le, from-nat, if-nar
- Generalized `posit-impl.rkt` — width-parameterized `posit-decode`/`posit-encode` with thin per-width wrappers
- Each width follows the exact same 14-file pipeline pattern

#### Tests

- 23 tests each in `test-posit16.rkt`, `test-posit32.rkt`, `test-posit64.rkt`
- 69 new tests total
- **Test count after phase**: 2009 total passing

---

### Phase 3b: Quire Accumulators ✅ COMPLETE

**Goal**: Exact dot-product accumulation via extended-precision registers.
**Commit**: `ae59ca8` — "Numerics Phase 3b+3c: Quire accumulators and ~ approximate literals"
**Guide reference**: Section 6

#### What was built

- 16 AST nodes (4 per width): `expr-Quire{8,16,32,64}`, `expr-quire{N}-val`, `expr-quire{N}-fma`, `expr-quire{N}-to`
- Exact rational accumulation using big integer sums
- FMA (fused multiply-add) primitives — accumulate without rounding until final conversion

**Quire widths:**

| Posit | Quire | Bits | Use Case |
|-------|-------|------|----------|
| Posit8 | Quire8 | 32 | Embedded/IoT |
| Posit16 | Quire16 | 128 | DSP/Fixed-point |
| Posit32 | Quire32 | 512 | Scientific computing |
| Posit64 | Quire64 | 2048 | High-precision |

#### Tests

- 31 tests in `test-quire.rkt` (quire creation, FMA accumulation, conversion to posit)

---

### Phase 3c: `~` Approximate Literal Syntax ✅ COMPLETE

**Goal**: Ergonomic syntax for approximate numeric literals.
**Commit**: `ae59ca8` (same as 3b — combined implementation)
**Guide reference**: Section 10

#### What was built

- `~3.14` → Posit32 (default approximate type)
- `(~3.14 : Posit16)` narrows to specific posit width
- Reader support: `~` prefix in both WS and sexp modes produces `($approx-literal val)` sentinel
- Preparse macro expands to posit literal construction

#### Tests

- 16 tests in `test-approx-literal.rkt`

---

### Phase 3d: Numeric Traits ✅ COMPLETE

**Goal**: Trait-based polymorphic arithmetic and comparison operations.
**Commit**: `8e017db` — "Phase 3d: Numeric traits — Add/Sub/Mul/Div/Neg/Abs with Int/Rat/Posit instances"
**Guide reference**: Section 4 (Core Numeric Traits)
**Dependencies**: Implicit Trait Resolution (Phases A–E) must be complete

#### What was built

**Arithmetic traits** (single-method, dict IS the function):
- `Add {A}` — `A -> A -> A` (binary addition)
- `Sub {A}` — `A -> A -> A` (binary subtraction)
- `Mul {A}` — `A -> A -> A` (binary multiplication)
- `Div {A}` — `A -> A -> A` (binary division)
- `Neg {A}` — `A -> A` (unary negation)
- `Abs {A}` — `A -> A` (absolute value)

**Comparison traits:**
- `Eq {A}` — `A -> A -> Bool`
- `Ord {A}` — `A -> A -> Ordering`

**Conversion traits (1-param):**
- `FromInt {A}` — `Int -> A`
- `FromRat {A}` — `Rat -> A`

**Instances** (per trait): Nat, Int, Rat, Posit8, Posit16, Posit32, Posit64

**Bundles:**
- `Num` — Add + Sub + Mul + Neg + Eq + Ord + Abs + FromInt (8 traits)
- `Fractional` — Num + Div + FromRat (10 traits)

**Stdlib files** (in `lib/prologos/core/`):
- Trait definitions: `add-trait.prologos`, `sub-trait.prologos`, `mul-trait.prologos`, `div-trait.prologos`, `neg-trait.prologos`, `abs-trait.prologos`
- Instance files: `add-instances.prologos`, `sub-instances.prologos`, etc. (one per trait, covers all 6 numeric types)
- Comparison: `eq-numeric-instances.prologos`, `ord-numeric-instances.prologos`
- Bundles: `numeric-bundles.prologos`

#### Key Lessons

- `expr->impl-key-str` must handle ALL numeric types (Int/Rat/Posit8-64/Keyword) — without these, falls through to `(format "~a" e)` producing `#(struct:expr-Int)--Add`
- Posit equality derived from `le`: no `p{N}-eq` primitives, derive `eq?(x,y) = and(le(x,y), le(y,x))`
- Instance files use `:refer []` to trigger side-effect registration without namespace pollution
- Single-method trait dict IS the function: `Add A` → `A → A → A` (no wrapper struct)

#### Tests

- 36 tests in `test-numeric-traits.rkt`
- **Test count after phase**: 2361 total passing

---

### Phase 3e: Within-Family Subtyping ✅ COMPLETE

**Goal**: Automatic widening within numeric families.
**Commit**: `d0a5f5f` — "Add within-family subtyping for numeric types (Phase 3e)"
**Guide reference**: Section 3 (Numeric Type Hierarchy)

#### What was built

**9 subtype edges:**
- Exact family: `Nat <: Int`, `Nat <: Rat`, `Int <: Rat`
- Posit family: `Posit8 <: Posit16`, `Posit8 <: Posit32`, `Posit8 <: Posit64`, `Posit16 <: Posit32`, `Posit16 <: Posit64`, `Posit32 <: Posit64`

**Dual-layer implementation:**
- **Type-level**: `subtype?` predicate in `typing-core.rkt` — `check` and `checkQ` fallbacks: after unification fails AND cumulativity fails, try `subtype?`
- **Runtime**: Coercion helpers in `reduction.rkt` — `try-coerce-to-int`, `try-coerce-to-rat`, `try-coerce-to-posit`
- All 10 `reduce-*-binary` helpers + 3 quire FMA handlers updated for coercion
- `posit-widen` function in `posit-impl.rkt`: decode→encode through exact rational

#### Key Lessons

- `rackunit` exports `check` which conflicts with typing-core's `check` — use `(prefix-in tc: "../typing-core.rkt")`
- `checkQ` had a latent inconsistency — only had cumulativity fallback, not subtype. Fixed alongside `check`

#### Tests

- 44 tests in `test-subtyping.rkt`
- **Test count after phase**: 2405 total passing

---

### Phase 3f: Cross-Family Conversions ✅ COMPLETE

**Goal**: Explicit, type-safe conversion between numeric families.
**Commit**: `4e0c74c` — "Phase 3f: Cross-family conversions — From/TryFrom/Into traits + 12 AST primitives"
**Guide reference**: Section 7 (Conversion System)
**Dependencies**: Phase 3e (subtyping), Trait Resolution (Phases A-E)

#### What was built

**12 new AST primitives:**
- `expr-p{8,16,32,64}-to-rat` — decode posit to exact rational
- `expr-p{8,16,32,64}-from-rat` — encode exact rational to posit
- `expr-p{8,16,32,64}-from-int` — convert integer to posit

**3 new 2-param traits:**
- `From {A B}` — `A -> B` (lossless conversion, single-method)
- `TryFrom {A B}` — `A -> Option B` (fallible conversion)
- `Into {A B}` — `A -> B` (reversed From, blanket parametric impl)

**Instances:**
- 13 `From` instances: 3 exact (Nat→Int, Int→Rat, Nat→Rat) + 6 posit widening (P8→P16/32/64, P16→P32/64, P32→P64) + 4 posit→rat (P8/16/32/64→Rat)
- 8 `TryFrom` instances: 4 rat→posit (Rat→P8/16/32/64) + 4 int→posit (Int→P8/16/32/64)
- 8 `FromInt`/`FromRat` posit instances (bridge 2-param From to 1-param for Num/Fractional bundles)

**Stdlib files:**
- `from-trait.prologos`, `tryfrom-trait.prologos`, `into-trait.prologos` (trait definitions)
- `from-instances.prologos` (13 From instances)
- `tryfrom-instances.prologos` (8 TryFrom instances)
- `fromint-posit-instances.prologos`, `fromrat-posit-instances.prologos` (bridging)

#### Key Lessons

- WS reader `$` is quote operator — users never write dict param names (`$From-A-B`) in `.prologos` files; Phase D resolves bare method names
- Posit widening uses `p{N2}-from-rat (p{N1}-to-rat x)` — decode→encode through exact rational
- NaR handling: `p{N}-to-rat` returns `expr-error` when `posit-decode` returns `'nar`
- `p{N}-from-rat`/`p{N}-from-int` always succeed (clamp to representable range)
- `Into` blanket impl uses parametric constraint resolution: `impl Into A B where (From A B)` → `from x`
- 12 new primitives follow unary pattern — reuse existing stuck-term handlers
- No changes to `posit-impl.rkt`, `macros.rkt`, or `trait-resolution.rkt` — infrastructure already supported 2-param traits

#### Tests

- 48 tests in `test-cross-family-conversions.rkt`
- **Test count after phase**: 2453 total passing

---

## Phase 4: Float32/Float64 ⬜ NOT STARTED

**Goal**: IEEE 754 floating-point types for C FFI interop.
**Guide reference**: Section 3.3
**Dependencies**: Phase 3a pattern (13 AST nodes per width), Phase 3e (subtyping), Phase 3f (From/TryFrom)

### Planned work

- 13 AST nodes per width (same pattern as Posit): type, literal, add/sub/mul/div, neg/abs/sqrt, lt/le, from-nat, if-nan
- Special values: ±Inf, NaN (multiple bit patterns — unlike Posit's single NaR)
- Subtyping: `Float32 <: Float64`
- Cross-family conversions: `Float64↔Posit64`, `Float→Rat` (exact for finite), `Float→Int` (truncating)
- `From`/`TryFrom`/`Into` instances for Float↔Posit, Float↔Rat, Float↔Int
- Numeric trait instances: Add/Sub/Mul/Div/Neg/Abs/Eq/Ord for Float32/Float64

### Open Design Decisions

- **Default numeric literal types**: The guide says `42` defaults to Int and `3.14` defaults to Rat. Currently `42` is parsed as Peano Nat. Changing this default is a breaking change that affects dependent type machinery.
- **Float literal syntax**: Should `3.14` be Rat or Float? Current design: `3.14` is Rat (exact), `~3.14` is Posit32 (approximate). Adding IEEE floats needs a distinct literal form or explicit annotation.

---

## AST Node Inventory

**Total numeric AST nodes: ~130**

| Family | Nodes | Description |
|--------|-------|-------------|
| Int | 12 | Type, literal, 6 ops, neg/abs, lt/le/eq, from-nat |
| Rat | 14 | Type, literal, 4 ops, neg/abs, lt/le/eq, from-int, numer/denom |
| Posit8 | 16 | Type, literal, 4 ops, neg/abs/sqrt, lt/le, from-nat, if-nar, to-rat/from-rat/from-int |
| Posit16 | 16 | Same pattern as Posit8 |
| Posit32 | 16 | Same pattern as Posit8 |
| Posit64 | 16 | Same pattern as Posit8 |
| Quire8 | 4 | Type, val, fma, to |
| Quire16 | 4 | Same pattern as Quire8 |
| Quire32 | 4 | Same pattern as Quire8 |
| Quire64 | 4 | Same pattern as Quire8 |

---

## Dependency Graph

```
Phase 1 (Posit8) ✅
  |---> Phase 3a (Posit16/32/64)   ✅
        |---> Phase 3b (Quire)     ✅
        |---> Phase 3c (~syntax)   ✅
        |---> Phase 3d (Traits)    ✅
        '---> Phase 3e (Subtyping) ✅
              '---> Phase 3f (Cross-family) ✅
                    '---> Phase 4 (Float32/Float64)

Phase 2 (Int+Rat) ✅ ---> Phase 3d, 3e, 3f ✅

Implicit Trait Resolution ✅ ---> Phase 3d, 3f ✅
```

---

## Test Summary

| Test File | Count | Phase | Purpose |
|-----------|-------|-------|---------|
| `test-posit-impl.rkt` | 18 | 1 | Pure Racket posit decode/encode |
| `test-posit8.rkt` | 23 | 1 | Posit8 pipeline integration |
| `test-int.rkt` | 29 | 2 | Int type, literals, operations |
| `test-rat.rkt` | 31 | 2 | Rat type, literals, operations |
| `test-posit16.rkt` | 23 | 3a | Posit16 pipeline integration |
| `test-posit32.rkt` | 23 | 3a | Posit32 pipeline integration |
| `test-posit64.rkt` | 23 | 3a | Posit64 pipeline integration |
| `test-quire.rkt` | 31 | 3b | Quire accumulators, FMA |
| `test-approx-literal.rkt` | 16 | 3c | `~` approximate literal syntax |
| `test-numeric-traits.rkt` | 36 | 3d | Trait instances, bundles |
| `test-subtyping.rkt` | 44 | 3e | Within-family subtyping |
| `test-cross-family-conversions.rkt` | 48 | 3f | From/TryFrom/Into |

**Total numerics-specific tests: ~345**

---

## Stdlib File Inventory

### Trait Definitions (`lib/prologos/core/`)

| File | Trait | Type Params | Signature |
|------|-------|-------------|-----------|
| `add-trait.prologos` | Add | `{A}` | `A -> A -> A` |
| `sub-trait.prologos` | Sub | `{A}` | `A -> A -> A` |
| `mul-trait.prologos` | Mul | `{A}` | `A -> A -> A` |
| `div-trait.prologos` | Div | `{A}` | `A -> A -> A` |
| `neg-trait.prologos` | Neg | `{A}` | `A -> A` |
| `abs-trait.prologos` | Abs | `{A}` | `A -> A` |
| `eq-trait.prologos` | Eq | `{A}` | `A -> A -> Bool` |
| `ord-trait.prologos` | Ord | `{A}` | `A -> A -> Ordering` |
| `fromint-trait.prologos` | FromInt | `{A}` | `Int -> A` |
| `fromrat-trait.prologos` | FromRat | `{A}` | `Rat -> A` |
| `from-trait.prologos` | From | `{A B}` | `A -> B` |
| `tryfrom-trait.prologos` | TryFrom | `{A B}` | `A -> Option B` |
| `into-trait.prologos` | Into | `{A B}` | `A -> B` (blanket from From) |
| `numeric-bundles.prologos` | Num, Fractional | `{A}` | Constraint conjunctions |

### Instance Files (`lib/prologos/core/`)

| File | Types Covered |
|------|---------------|
| `add-instances.prologos` | Int, Rat, Posit8/16/32/64 |
| `sub-instances.prologos` | Int, Rat, Posit8/16/32/64 |
| `mul-instances.prologos` | Int, Rat, Posit8/16/32/64 |
| `div-instances.prologos` | Int, Rat, Posit8/16/32/64 |
| `neg-instances.prologos` | Int, Rat, Posit8/16/32/64 |
| `abs-instances.prologos` | Int, Rat, Posit8/16/32/64 |
| `eq-numeric-instances.prologos` | Int, Rat, Posit8/16/32/64 |
| `ord-numeric-instances.prologos` | Int, Rat, Posit8/16/32/64 |
| `from-instances.prologos` | 13 instances (exact + posit widening + posit→rat) |
| `tryfrom-instances.prologos` | 8 instances (rat→posit + int→posit) |
| `fromint-posit-instances.prologos` | Posit8/16/32/64 |
| `fromrat-posit-instances.prologos` | Posit8/16/32/64 |

---

## Cross-References

| Document | Contents |
|----------|----------|
| `IMPLEMENTATION_GUIDE_PROLOGOS_NUMERICS.md` | Full specification — 14 sections, 1527 lines |
| `memory/numerics-tower-roadmap.md` | Concise phase status + dependency graph |
| `memory/numerics-lessons.md` | Key lessons from Phases 3d–3f |
| `MEMORY.md` | Living project state — test counts, architectural patterns |
| `docs/tracking/2026-02-19_CORE_DATA_STRUCTURES_ROADMAP.md` | Companion tracking doc for data structures |
| `docs/tracking/2026-02-19_HOMOICONICITY_ROADMAP.md` | Homoiconicity roadmap (related: sentinel symbols for `~`) |

---

## Session Log

### Phase 1: Posit8
- **Posit8 implementation**: 13 AST nodes, pure Racket `posit-impl.rkt`, full pipeline
- **18 + 23 tests**: posit-impl unit tests + pipeline integration tests

### Phase 2: Int + Rat
- **Commit `c043b49`**: Int type — arbitrary-precision integers, 11 AST nodes
- **Commit `b215722`**: Rat type — exact rationals, 13 AST nodes
- **Commit `1cac097`**: Numeric literal patterns in match expressions
- **29 + 31 tests**: Int + Rat pipeline tests

### Phase 3a: Posit16/32/64
- **Commit `616e689`**: "Add Posit16, Posit32, Posit64 types and generalize posit-impl.rkt"
- 39 AST nodes per width, generalized posit-impl with width parameterization
- **69 new tests, 2009 total passing**

### Phase 3b+3c: Quire + ~ Syntax
- **Commit `ae59ca8`**: "Numerics Phase 3b+3c: Quire accumulators and ~ approximate literals"
- Quire accumulators (16 nodes) + `~` approximate literal syntax
- **31 + 16 tests**

### Phase 3d: Numeric Traits
- **Commit `8e017db`**: "Phase 3d: Numeric traits — Add/Sub/Mul/Div/Neg/Abs with Int/Rat/Posit instances"
- 6 arithmetic traits + 2 comparison traits + 2 conversion traits + 2 bundles
- All instances across 7 numeric types (Nat + Int + Rat + Posit8/16/32/64)
- **36 tests, 2361 total passing**

### Phase 3e: Within-Family Subtyping
- **Commit `d0a5f5f`**: "Add within-family subtyping for numeric types (Phase 3e)"
- Dual-layer: type-level `subtype?` + runtime coercion helpers
- 9 subtype edges, 10 binary reduce helpers + 3 quire FMA handlers updated
- **44 tests, 2405 total passing**

### Phase 3f: Cross-Family Conversions
- **Commit `4e0c74c`**: "Phase 3f: Cross-family conversions — From/TryFrom/Into traits + 12 AST primitives"
- 12 new AST primitives, 3 new 2-param traits, 29 trait instances
- `Into` blanket impl via parametric constraint resolution
- **48 tests, 2453 total passing**
