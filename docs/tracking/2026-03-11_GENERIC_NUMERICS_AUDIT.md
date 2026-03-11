# Generic Numerics Audit

## Context

Prologos's design principle (codified in grammar.md, PATTERNS_AND_CONVENTIONS, DEFERRED.md)
is that **Nat is for type-level infrastructure** (induction, length-indexed vectors, proofs)
and **Int/Rat/Posit are the computational numeric types**. The `Num` bundle
(`Add Sub Mul Neg Eq Ord Abs FromInt`) provides generic dispatch.

In practice, Nat has leaked into computational contexts throughout the codebase — examples,
library APIs, prelude defaults, and documentation. This audit catalogs every instance of
this anti-pattern and identifies the trait coverage gaps that make generic numerics harder
to use than type-specific Nat functions.

**Goal**: Produce an actionable inventory for a Generic Numerics Sprint that shifts
the codebase from Nat-first to Num-first (or Int-first where generic isn't possible).

**Scope**: Library APIs, prelude exports, examples, documentation. NOT the narrowing
engine (which legitimately requires Nat for structural recursion) or type-level indices.

---

## Classification Scheme

| Code | Meaning |
|------|---------|
| **NAT-API** | Library function with Nat in its signature where Int or generic would be better |
| **NAT-EXAMPLE** | Example/demo using Nat for computation instead of Int or generic |
| **NAT-PRELUDE** | Prelude export that pushes users toward Nat |
| **MISSING-INST** | Missing trait instance that forces users to drop to type-specific code |
| **SHADOW** | Name collision where Nat-specific version shadows generic version |
| **NAT-OK** | Nat usage that is correct/intentional (induction, proofs, narrowing) |
| **DESIGN** | Design decision that could be revisited |

---

## A. Library API Findings

### A1. Collection Indexing — Nat Locks

All collection operations that take or return indices/counts use Nat:

| Function | File | Signature | Issue |
|----------|------|-----------|-------|
| `length` | data/list.prologos:39 | `List A -> Nat` | NAT-API: returns Nat |
| `nth` | data/list.prologos:159 | `Nat -> List A -> Option A` | NAT-API: takes Nat index |
| `drop` | data/list.prologos:224 | `Nat -> List A -> List A` | NAT-API: takes Nat count |
| `take` | data/list.prologos:215 | `Nat -> List A -> List A` | NAT-API: takes Nat count |
| `split-at` | data/list.prologos | `Nat -> List A -> ...` | NAT-API: takes Nat index |
| `replicate` | data/list.prologos | `Nat -> A -> List A` | NAT-API: takes Nat count |
| `iterate-n` | data/list.prologos | `Nat -> (A -> A) -> A -> List A` | NAT-API: takes Nat count |
| `find-index` | data/list.prologos | `(A -> Bool) -> List A -> Option Nat` | NAT-API: returns Nat |
| `count` | data/list.prologos | `(A -> Bool) -> List A -> Nat` | NAT-API: returns Nat |
| `range` | data/list.prologos:195 | `Nat -> List Nat` | NAT-API: Nat-only range |
| `glength` | core/generic-ops.prologos:46 | `Seqable C -> C A -> Nat` | NAT-API: generic collection but Nat return |
| `length` | core/collections.prologos:57 | `Reducible C -> C A -> Nat` | NAT-API: generic collection but Nat return |
| `take` | core/collections.prologos:103 | `... -> Nat -> C A -> C A` | NAT-API: generic but Nat index |
| `drop` | core/collections.prologos:108 | `... -> Nat -> C A -> C A` | NAT-API: generic but Nat index |
| `pvec-nth` | reduction.rkt:1758 | uses `nat-value` internally | NAT-API: PVec indexing is Nat |
| `pvec-length` | reduction.rkt:1775 | returns `nat->expr` | NAT-API: PVec length is Nat |

**Impact**: Any user working with collections must use Nat for indexing, even when their
data comes from Int computations. Forces `from : Int -> Nat` conversions everywhere.

**Note**: String operations (`str::take`, `str::drop`) already use **Int**, not Nat.
This inconsistency is confusing — strings use Int indices but lists/pvecs use Nat.

### A2. Nat-Specific Arithmetic in Prelude

| Function | File | Signature | Issue |
|----------|------|-----------|-------|
| `add` | data/nat.prologos | `Nat -> Nat -> Nat` | NAT-PRELUDE: unqualified in prelude |
| `mult` | data/nat.prologos | `Nat -> Nat -> Nat` | NAT-PRELUDE: unqualified in prelude |
| `double` | data/nat.prologos | `Nat -> Nat` | NAT-PRELUDE: unqualified in prelude |
| `pred` | data/nat.prologos | `Nat -> Nat` | NAT-PRELUDE: unqualified in prelude |
| `sub` | data/nat.prologos | `Nat -> Nat -> Nat` | NAT-PRELUDE: unqualified in prelude |
| `pow` | data/nat.prologos | `Nat -> Nat -> Nat` | NAT-PRELUDE: unqualified in prelude |
| `le?` | data/nat.prologos | `Nat -> Nat -> Bool` | NAT-PRELUDE: unqualified |
| `lt?` | data/nat.prologos | `Nat -> Nat -> Bool` | NAT-PRELUDE: unqualified |
| `gt?` | data/nat.prologos | `Nat -> Nat -> Bool` | NAT-PRELUDE: unqualified |
| `ge?` | data/nat.prologos | `Nat -> Nat -> Bool` | NAT-PRELUDE: unqualified |
| `nat-eq?` | data/nat.prologos | `Nat -> Nat -> Bool` | NAT-PRELUDE: unqualified |
| `min` | data/nat.prologos | `Nat -> Nat -> Nat` | NAT-PRELUDE: shadows generic `ord-min` |
| `max` | data/nat.prologos | `Nat -> Nat -> Nat` | NAT-PRELUDE: shadows generic `ord-max` |
| `clamp` | data/nat.prologos | `Nat -> Nat -> Nat -> Nat` | NAT-PRELUDE: unqualified |
| `bool-to-nat` | data/nat.prologos | `Bool -> Nat` | NAT-PRELUDE: unqualified |

**Impact**: Users see `add`, `sub`, `min`, `max` as top-level names. Natural instinct
is to use them, not realizing they're Nat-specific. The generic `.{x + y}` path exists
but is less discoverable than bare `add`.

**Critical**: `min`/`max` from `data/nat` **shadow** the generic `ord-min`/`ord-max`
from `core/ord`. Users calling `min` get the Nat version, not the generic Ord version.

### A3. sum/product Name Collision

| Function | File | Signature | Issue |
|----------|------|-----------|-------|
| `sum` | data/list.prologos:114 | `List Nat -> Nat` | SHADOW: Nat-specific |
| `sum` | core/algebra.prologos:105 | `(Add A) -> (AdditiveIdentity A) -> List A -> A` | Generic version |
| `product` | data/list.prologos:119 | `List Nat -> Nat` | SHADOW: Nat-specific |
| `product` | core/algebra.prologos:116 | `(Mul A) -> (MultiplicativeIdentity A) -> List A -> A` | Generic version |

**Impact**: The prelude imports `sum`/`product` from `data/list` (line 356-358 of
namespace.rkt) which **shadows** the generic versions from `core/algebra` (imported
via `:refer-all` on line 375). Users calling `sum` get the Nat-only version.

### A4. Hash Functions — Nat Return (Intentional)

| Function | File | Issue |
|----------|------|-------|
| `hash-combine` | core/hashable.prologos | NAT-OK: hash values are non-negative by nature |
| `hash-list` | core/hashable.prologos | NAT-OK: same |
| `hash-option` | core/hashable.prologos | NAT-OK: same |

These are correct — hash values are inherently non-negative natural numbers.

---

## B. Trait Instance Coverage

### B1. Full Trait Instance Matrix

| Trait | Nat | Int | Rat | Posit8 | Posit16 | Posit32 | Posit64 |
|-------|:---:|:---:|:---:|:------:|:-------:|:-------:|:-------:|
| Eq | Y | Y | Y | Y | Y | Y | Y |
| Ord | Y | Y | Y | Y | Y | Y | Y |
| Add | Y | Y | Y | Y | Y | Y | Y |
| Sub | Y* | Y | Y | Y | Y | Y | Y |
| Mul | Y | Y | Y | Y | Y | Y | Y |
| Div | - | Y | Y | Y | Y | Y | Y |
| Neg | - | Y | Y | Y | Y | Y | Y |
| Abs | - | Y | Y | Y | Y | Y | Y |
| FromInt | - | Y | Y | Y | Y | Y | Y |
| FromRat | - | - | Y | Y | Y | Y | Y |
| AdditiveIdentity | Y | Y | Y | Y | Y | Y | Y |
| MultiplicativeIdentity | Y | Y | Y | Y | Y | Y | Y |
| **Num bundle** | **NO** | **YES** | **YES** | **?** | **?** | **?** | **?** |
| **Fractional bundle** | **NO** | **NO** | **YES** | **?** | **?** | **?** | **?** |

\* Nat Sub is saturating (sub 3 5 = 0, not -2)

**Key finding**: Nat cannot satisfy the `Num` bundle (lacks Neg, Abs, FromInt). This is
correct by design — Nat isn't a signed type. But it means generic `Num`-constrained
functions can't be called with Nat, which is actually what we want.

**Question**: Do Posit types satisfy the full `Num` bundle? They have all the individual
instances but it depends on whether the bundle resolution finds them. Need to verify.

### B2. Missing/Weak Instances

| Gap | Description | Priority |
|-----|-------------|----------|
| MISSING-INST | No `Int -> Nat` conversion (intentional — lossy/partial) | Low |
| MISSING-INST | No `Hashable Int` instance | Medium |
| MISSING-INST | No `Hashable Rat` instance | Low |
| MISSING-INST | No `Show` / `Showable` instances for numeric types | Medium |
| DESIGN | `int-range` hardcoded to Int (no generic range) | Low |

### B3. Reduction-Level Coercion

The reduction engine (reduction.rkt) has automatic widening coercion:
- `Nat -> Int` via `try-coerce-to-int`
- `Nat/Int -> Rat` via `try-coerce-to-rat`
- Narrower Posit -> Wider Posit via `posit-widen`

This means `.{1N + 2}` (Nat + Int) works at runtime via coercion even without
explicit conversion. But the type checker may reject it at compile time if the
types don't match. The coercion is a safety net, not a feature to rely on.

---

## C. Example & Documentation Findings

### C1. Examples Using Nat for Computation

| File | Lines | Pattern | Issue |
|------|-------|---------|-------|
| `numerics-tutorial-demo.prologos` | 66-180 | Pass 1: 114 lines of Nat arithmetic after "NOT for computation" disclaimer | NAT-EXAMPLE |
| `2026-03-10-surface-ergonomics.prologos` | 48-66 | `[add 2N 3N] = 5N`, `3N = 3N` | NAT-EXAMPLE |
| `2026-03-10-surface-ergonomics.prologos` | 116-145 | `spec sum-of-doubles Nat -> Nat` | NAT-EXAMPLE |
| `2026-03-10-surface-ergonomics.prologos` | 249-355 | Config maps: `:port 8080N :timeout 30N` | NAT-EXAMPLE |
| `narrowing-demo.prologos` | throughout | All narrowing uses Nat (add ?x ?y = 5N) | NAT-OK (narrowing requires Nat) |
| `2026-03-09-fc-trait-rel-dom.prologos` | throughout | Capstone demo uses Nat throughout | NAT-EXAMPLE (partially) |
| Audit files (audit-01, 08, 09) | throughout | Nat arithmetic tests | NAT-OK (testing Nat features) |

### C2. Documentation That Addresses the Issue

| Document | Status |
|----------|--------|
| `docs/spec/grammar.md` line 177 | CORRECT: "Nat is for type-level, not computation" |
| `docs/tracking/principles/PATTERNS_AND_CONVENTIONS` | CORRECT: Shows BAD (Nat) vs GOOD (Int) |
| `docs/tracking/DEFERRED.md` line 571-582 | CORRECT: Explicitly calls this an audit target |
| `docs/standups/standup-2026-03-03.org` §11.4 | CORRECT: "We really need to stop using Nat in computations" |
| `docs/tracking/2026-02-21_NUMERICS_PERF.md` | CORRECT: "Nat is for type-level, NOT computation" |
| `docs/tracking/2026-02-19_NUMERICS_TOWER_ROADMAP.md` line 304 | DESIGN: Notes `42` defaults to Nat, changing is breaking |

### C3. The Default Literal Problem

Currently:
- `42N` → Nat (explicit)
- `42` → Int (via `expr-int`)
- `1/2` → Rat (via `expr-rat`)
- `~3.14` → Posit (via `expr-posit*`)

The literal system itself is fine — `42` IS already Int, not Nat. The problem isn't
the literal parser; it's that:
1. Examples use `42N` (Nat) instead of `42` (Int)
2. Library APIs take/return Nat, forcing users to use Nat literals
3. The prelude makes Nat functions more accessible than generic alternatives

---

## D. Root Cause Clusters

### D1. Prelude Overexposure of Nat Functions
- 15 Nat-specific functions imported unqualified
- `min`/`max` shadow generic `ord-min`/`ord-max`
- `sum`/`product` from data/list shadow generic versions from core/algebra
- **Fix**: Move Nat functions behind a `nat::` qualifier; expose generic versions unqualified

### D2. Collection APIs Hardcoded to Nat Indices
- `length`, `nth`, `drop`, `take`, `find-index`, `count` all use Nat
- `glength`, generic `take`/`drop` in collections.prologos also use Nat
- `pvec-nth`, `pvec-length` use Nat at the reduction level
- String ops use Int (inconsistency)
- **Fix**: Change to Int (matching string ops), or provide Int-indexed alternatives

### D3. Examples Teach Nat-First
- Tutorial starts with 114 lines of Nat arithmetic
- Surface ergonomics demo uses Nat for configs, counts, function signatures
- Capstone demo uses Nat throughout
- **Fix**: Rewrite examples to use Int/generic by default, Nat only for proofs

### D4. No Int Arithmetic in Prelude (Unqualified)
- Int operations (`int+`, `int-`, `int*`, `int/`) are builtins, not pretty names
- Generic trait functions (`plus`, `minus`, `times`, `divide`) exist in algebra but
  aren't as discoverable as bare `add`
- Users need `.{x + y}` mixfix or trait-qualified names for Int arithmetic
- **Fix**: Either expose generic wrappers unqualified or add Int-named alternatives

### D5. Narrowing Is Nat-Only (Legitimate but Confusing)
- Narrowing requires structural recursion (Peano constructors)
- This forces all narrowing demos to use Nat
- Users may generalize this to think Nat is the "default" numeric type
- **Fix**: Better documentation framing; long-term: constraint-based Int narrowing

---

## E. Repair Backlog (Prioritized)

### Priority 1: Prelude Rebalancing (High Impact, Low Risk)

| # | Task | Effort | Description |
|---|------|--------|-------------|
| P1a | Qualify Nat arithmetic in prelude | M | Move `add`, `mult`, `sub`, `pow`, `double`, `pred` behind `nat::` qualifier |
| P1b | Expose generic wrappers unqualified | S | `plus`, `minus`, `times`, `divide`, `negate-fn`, `abs-fn` already exist in algebra — ensure unqualified |
| P1c | Fix sum/product shadowing | S | Remove `sum`/`product` from data/list prelude export; generic versions from algebra win |
| P1d | Fix min/max shadowing | S | Remove `min`/`max` from data/nat prelude export; `ord-min`/`ord-max` win (or rename to `min`/`max`) |
| P1e | Expose Int convenience functions | M | Add `int-add`, `int-sub`, etc. as prelude names, or ensure mixfix `+`/`-` works cleanly |

### Priority 2: Collection API Harmonization (Medium Impact, Medium Risk)

| # | Task | Effort | Description |
|---|------|--------|-------------|
| P2a | Add Int-indexed list ops | M | `nth-int : Int -> List A -> Option A` (with bounds check) alongside existing Nat versions |
| P2b | Change `length` return to Int | M-L | Breaking: `length : List A -> Int`; or add `length-int` alternative |
| P2c | Change generic length/take/drop | M | Update `glength`, generic `take`/`drop` in collections.prologos |
| P2d | PVec Int indexing | M | Add Int-indexed `pvec-nth-int` at reduction level, or coerce |
| P2e | Harmonize with String ops | S | Document that strings use Int, collections use Nat (or fix the inconsistency) |

### Priority 3: Example & Documentation Rewrite (Medium Impact, Low Risk)

| # | Task | Effort | Description |
|---|------|--------|-------------|
| P3a | Rewrite numerics-tutorial-demo | M | Shrink Pass 1 (Nat), expand Pass 2 (Int), add generic Num section |
| P3b | Rewrite surface-ergonomics demo | M | Replace Nat with Int in config/computation examples |
| P3c | Add generic numerics showcase | M | New example showing Num-constrained functions, trait dispatch, multi-type usage |
| P3d | Reframe narrowing demo | S | Add header explaining Nat is required for narrowing; separate forward-computation examples |
| P3e | Update PATTERNS_AND_CONVENTIONS | S | Add "Numeric Type Selection Guide" section |

### Priority 4: Trait Coverage Gaps (Low Impact, Medium Effort)

| # | Task | Effort | Description |
|---|------|--------|-------------|
| P4a | Verify Posit Num bundle | S | Confirm Posit8-64 satisfy full Num bundle after Phase 3f instances |
| P4b | Add Hashable Int | M | Instance for `Hashable Int` (needed for Int-keyed maps) |
| P4c | Generic `range` | M | `range : (Num A) (Ord A) -> A -> A -> List A` or similar |
| P4d | `int-range` in prelude | S | Ensure `int-range` is accessible without qualification |

### Priority 5: Design Decisions (Deferred)

| # | Task | Effort | Description |
|---|------|--------|-------------|
| P5a | Polymorphic numeric literals | L | `42` infers as `(FromInt A) => A` (Haskell-style); major type inference change |
| P5b | Int narrowing via constraints | L | Constraint propagation for Int narrowing (not structural) |
| P5c | Deprecate Nat-specific `sum`/`product` | S | Remove from data/list; users use generic from algebra |

---

## F. Recommended Sprint Order

**Phase 1: Prelude & Naming** (P1a-e) — Highest leverage. Changes what users see by
default. No semantic changes, just import reorganization.

**Phase 2: Examples** (P3a-e) — Second highest leverage. Changes what users learn from.
Pure documentation/example changes, no code risk.

**Phase 3: Collection APIs** (P2a-e) — Most invasive. Requires careful thought about
backwards compatibility and the Nat-vs-Int design trade-off for indices.

**Phase 4: Trait Gaps** (P4a-d) — Fill in missing instances to make generic code work
in more contexts.

**Phase 5: Design** (P5a-c) — Long-term improvements. Polymorphic literals and Int
narrowing are substantial projects, not sprint-sized.

---

## G. Key Design Question

**Should collection indices be Nat or Int?**

Arguments for **keeping Nat**:
- Natural numbers are the natural type for indices (non-negative by construction)
- Dependent types benefit from Nat indices (length-indexed vectors)
- No bounds-checking needed (Nat can't be negative)

Arguments for **switching to Int**:
- Matches string ops (already Int-indexed)
- Matches most other languages
- Avoids forced Nat→Int conversions in mixed code
- `int-range` returns `List Int`, but `range` returns `List Nat` — mixing is awkward

**Recommendation**: Keep Nat for type-level indices (Vec, dependent types). Add Int
alternatives for the common case (`nth-int`, `length-int`, or overloaded via trait).
Long-term, consider a `Size` type alias for `Nat` in index positions.

---

## H. Metrics

| Category | Count |
|----------|-------|
| NAT-API findings | 16 functions |
| NAT-PRELUDE findings | 15 functions |
| SHADOW findings | 4 (min, max, sum, product) |
| NAT-EXAMPLE findings | 5 files |
| MISSING-INST findings | 4 gaps |
| NAT-OK (correct usage) | ~8 locations |
| Total repair tasks | 22 (across 5 priority levels) |
