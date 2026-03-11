# Generic Numerics Sprint

**Created**: 2026-03-11
**Audit**: [2026-03-11_GENERIC_NUMERICS_AUDIT.md](2026-03-11_GENERIC_NUMERICS_AUDIT.md)

## Context

The Generic Numerics Audit (commit `d61669f`) cataloged systematic Nat misuse across
the codebase. This sprint shifts from **Nat-first** to **generic/Int-first** for
computation, preserving Nat for induction, proofs, and type-level indices.

**Guiding principles:**
- `Num` (or individual traits) for generic; `Int` as practical computational default
- Nat only for structural recursion, dependent types, and proofs
- Stdlib modules use explicit `require`, not prelude — safe to change prelude exports

---

## Phase Tracker

| # | Sub-phase | Effort | Status | Commit | Notes |
|---|-----------|--------|--------|--------|-------|
| **Phase 1: Prelude Rebalancing** | | | | | |
| 1a | Move Nat arithmetic behind `nat::` alias | M | ✅ | `35a989d` | namespace.rkt; also fixed dead peel-lambda-names ref |
| 1b | Fix sum/product shadowing | S | ✅ | `87fcfa9` | Removed from list `:refer`; algebra generic wins |
| 1c | Fix min/max shadowing | S | ✅ | (done by 1a) | min/max aliases in ord caused type errors; deferred |
| 1d | Expose generic wrappers unqualified | S | ✅ | (verified) | plus/minus/times/divide/int-range all resolve via :refer-all |
| 1e | Add int convenience names | S | ⏭️ | | int+/int-/int*/int/ already sufficient |
| **Phase 2: Collection API** | | | | | |
| 2a | Int-indexed list ops | M | ✅ | `8158a08` | nth-int, take-int, drop-int; match-on-Bool not if |
| 2b | `length-int` alternative | S | ✅ | `8158a08` | `List A -> Int` in same commit |
| 2c | Harmonize generic collection ops | M | ⏭️ | | Too broad; List Int-ops sufficient for now |
| 2d | Document index type strategy | S | ✅ | | PATTERNS_AND_CONVENTIONS.org: index type strategy section |
| **Phase 3: Examples & Docs** | | | | | |
| 3a | Rewrite numerics-tutorial-demo | M | ✅ | `481ead5` | Shrunk Nat from ~115→~30 lines; added mixfix, Int-indexed ops |
| 3b | Rewrite surface-ergonomics demo | M | ✅ | `b34e010` | Int for configs/computation; narrowing sections kept Nat |
| 3c | Generic numerics showcase | M | ✅ | `bc53655` | New file: generic-numerics.prologos |
| 3d | Reframe narrowing demo | S | ✅ | (pre-existing) | Header already present at lines 26-33 |
| 3e | Update PATTERNS_AND_CONVENTIONS | S | ✅ | | Done as part of 2d |
| **Phase 4: Trait Gaps** | | | | | |
| 4a | Verify Posit Num bundle | S | ⬜ | | End-to-end `.{p + q}` |
| 4b | Hashable Int instance | M | ⬜ | | core/hashable.prologos |
| 4c | Expose `int-range` in prelude | S | ⬜ | | Verify `:refer-all` covers it |

**Legend**: ⬜ Not started · 🔨 In progress · ✅ Done · ⏭️ Skipped

---

## Phase 1: Prelude Rebalancing

### 1a: Move Nat Arithmetic Behind `nat::` Alias

**File**: `racket/prologos/namespace.rkt` line 334-336

Change:
```scheme
(imports [prologos::data::nat :refer [add mult double pred zero? sub pow
                                       le? lt? gt? ge? nat-eq? min max
                                       bool-to-nat clamp]])
```
To:
```scheme
(imports [prologos::data::nat :as nat :refer [zero?]])
```

- `zero?` stays unqualified (Nat predicate, no generic equivalent)
- Everything else → `nat::add`, `nat::mult`, `nat::sub`, etc.
- Stdlib safe (uses explicit `require`, not prelude)
- Tests using bare `add` with Nat args through prelude will break — fix by adding explicit require or switching to generics

### 1b: Fix sum/product Shadowing

Remove `sum` and `product` from `prologos::data::list :refer [...]` (line 356-366).
Generic versions from `prologos::core::algebra` (`:refer-all`) will win.

Note: Generic `sum`/`product` require 2 dict args `(Add A) -> (AdditiveIdentity A) -> List A -> A`.
Verify elaborator auto-resolves constraints.

### 1c: Fix min/max Shadowing

Already removed from nat `:refer` in 1a. Verify `ord-min`/`ord-max` from
`prologos::core::ord` are accessible. Consider renaming to `min`/`max`.

### 1d: Expose Generic Wrappers

Verify `plus`, `minus`, `times`, `divide`, `negate-fn`, `abs-fn` from
`prologos::core::algebra` (`:refer-all`) resolve correctly after 1a.

### 1e: Int Convenience Names

Evaluate if `int-add`/`int-sub`/`int-mul`/`int-div` wrappers are needed beyond
mixfix `.{x + y}` and generic `plus`/`minus`. Skip if unnecessary.

---

## Validation

| After | Run |
|-------|-----|
| Phase 1a | Full test suite (namespace changes affect everything) |
| Phase 1b-e | Full test suite |
| Phase 2 | Targeted + full suite |
| Phase 3 | `process-file` on all example files |
| Phase 4 | Targeted trait tests |
| Sprint complete | Full suite + all examples |

**Run**: `"/Applications/Racket v9.0/bin/racket" racket/prologos/tools/run-affected-tests.rkt --all 2>&1 | tail -30`

---

## Metrics (Baseline)

| Metric | Value |
|--------|-------|
| Tests | 6733 |
| Test files | 349 |
| Wall time | 188.4s |
