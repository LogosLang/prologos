# SRE Track 2: Elaborator-on-SRE — Stage 2/3 Design

**Stage**: 2 (Audit) + 3 (Design), combined
**Date**: 2026-03-23
**Series**: SRE (Structural Reasoning Engine)
**Status**: D.1 — awaiting critique
**Depends on**: [SRE Track 0](2026-03-22_SRE_TRACK0_FORM_REGISTRY_DESIGN.md) ✅, [SRE Track 1](2026-03-23_SRE_TRACK1_RELATION_PARAMETERIZED_DECOMPOSITION_DESIGN.md) ✅
**Enables**: SRE Track 3 (Trait Resolution), Track 4 (Sessions), Track 5 (Patterns), PM 8F (metas as cells)
**Source Documents**:
- [SRE Master](2026-03-22_SRE_MASTER.md) — series tracking, cross-dependencies
- [SRE Research](../research/2026-03-22_STRUCTURAL_REASONING_ENGINE.md) — founding insight
- [NTT Case Study: Type Checker](../research/2026-03-22_NTT_CASE_STUDY_TYPE_CHECKER.md) — impedance mismatch analysis
- [NTT Architecture Survey](../research/2026-03-22_NTT_ARCHITECTURE_SURVEY.md) — gap analysis
- [Categorical Foundations](../research/2026-03-22_CATEGORICAL_FOUNDATIONS_TYPED_PROPAGATOR_NETWORKS.md) — polynomial functor grounding
- [SRE Track 0 PIR](2026-03-22_SRE_TRACK0_PIR.md) — form registry lessons
- [SRE Track 1 PIR](2026-03-23_SRE_TRACK1_PIR.md) — relation engine lessons

---

## Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| Pre-0 | Micro-benchmark + adversarial baseline | ⬜ | Informs design iteration |
| 1 | Unify classifier → SRE ctor-desc dispatch | ⬜ | The core migration |
| 2 | Binder handling via SRE | ⬜ | Pi codomain, Sigma snd-type, lam body |
| 3 | Meta handling (flex-rigid, flex-app) via SRE | ⬜ | Cell-based meta resolution |
| 4 | Subtype/conversion fallback via SRE | ⬜ | Track 1's subtype-relate + cumulativity |
| 5 | Polarity inference integration | ⬜ | User-defined types get automatic variance |
| 6 | Verification + benchmarks + PIR | ⬜ | |

---

## 1. Vision and Goals

**High-level goal**: Make the SRE the SINGLE mechanism for all structural
type reasoning in the elaborator. Currently, `classify-whnf-problem` in
`unify.rkt` is a manual form registry — it pattern-matches on ~20 expression
struct types and returns decomposition instructions. This is exactly what the
SRE's ctor-desc registry does, but hardcoded. The migration replaces hardcoded
pattern matching with SRE ctor-desc lookups.

**What we're solving for**:
1. **Eliminate the parallel registry**: `classify-whnf-problem` (37 cases) duplicates
   the structural knowledge in ctor-desc (23 descriptors). Every new AST node requires
   updating BOTH. After Track 2, only ctor-desc matters.
2. **Enable relation-parameterized unification at the elaboration level**: The classifier
   currently only handles equality. With the SRE, subtyping and duality share the
   same dispatch. The check function's conversion fallback (`subtype? t1-w t-w`) and
   the Pi domain check could use `structural-relate` with the appropriate relation.
3. **Prepare for PM 8F (metas as cells)**: When metas become cells, `classify-whnf-problem`'s
   `flex-rigid` case changes fundamentally — instead of "unsolved meta vs concrete," it's
   "cell with bot vs cell with value." The SRE handles this naturally (bot sub-cells).
4. **Validate the SRE under real load**: Track 0 validated extraction (same behavior, different
   module). Track 1 validated relations (new behavior). Track 2 validates that the SRE
   works as the elaborator's PRIMARY mechanism for 7000+ test cases.

**Performance expectations** (to check against in PIR):
- Unification wall time: ≤ 5% regression (ctor-desc lookup vs hardcoded match)
- Full suite wall time: ≤ 3% regression (236.7s baseline)
- Memory: neutral (same cell/propagator count — SRE lookup replaces hardcoded match, doesn't add cells)
- If the SRE lookup is FASTER than hardcoded match (possible: hash lookup vs linear match*), note as positive finding

**What "done" looks like**:
- `classify-whnf-problem` delegates ALL structural cases to `sre-constructor-tag` + ctor-desc extraction
- No hardcoded `(and (expr-Pi? a) (expr-Pi? b))` patterns in the classifier
- All 7392+ tests pass
- Acceptance file passes
- Performance within bounds
- PIR written per methodology

---

## 2. Stage 2 Audit: What The Elaborator Actually Does

### 2.1 Key Finding: The Elaborator is Already Store-Agnostic

The elaborator (`typing-core.rkt`) does NOT install propagators directly. It calls
`unify`, which dispatches to PUnify/SRE. The "SRE migration" is NOT about changing
158 infer/check cases in typing-core — it's about changing the dispatch in `unify.rkt`.

**typing-core.rkt** (158 cases):
- 0 cases manually install propagators
- 3 cases create fresh metas
- 40+ cases call `unify` (which goes through SRE)
- 4 cases use speculative rollback
- The rest are trivial (type wrappers, arithmetic checks, delegation)

**unify.rkt** (the actual migration target):
- `classify-whnf-problem` (line 456): 37 cases, the manual form registry
- `unify-core` (line 383): orchestrator (zonk → classify → dispatch)
- `unify-whnf` (line 606+): dispatcher for classified problems
- `punify-dispatch-*` (lines 700+): PUnify structural decomposition

### 2.2 The Classifier IS a Manual Form Registry

`classify-whnf-problem` returns tagged decomposition instructions:

| Tag | Count | SRE Equivalent |
|-----|-------|---------------|
| `'ok` | 8 cases | Identity: structurally equal, holes, same meta |
| `'flex-rigid` | 2 cases | Meta cell with bot value |
| `'flex-app` | 2 cases | Applied meta (spine-headed by unsolved meta) |
| `'sub` | 8 cases | SRE structural decomposition (Eq, Vec, Fin, app, pair, suc, nat-val) |
| `'pi` | 1 case | SRE structural decomposition with binder (Pi) |
| `'binder` | 2 cases | SRE structural decomposition with binder (Sigma, lam) |
| `'level` | 1 case | Level lattice merge |
| `'union` | 1 case | Union component matching |
| `'retry` | 7 cases | HKT normalization, annotation stripping |
| `'conv` | 5 cases | Conversion fallback (mismatch) |

The `'sub` cases (8) and `'binder` cases (2) are EXACTLY what the SRE handles.
The `'pi` case is a specialized `'binder` with multiplicity.

**The 10 structural cases** (`'sub` + `'pi` + `'binder`) map 1:1 to ctor-desc:

| Classifier case | ctor-desc tag |
|----------------|---------------|
| Pi vs Pi | `'Pi` (arity 2, binder-depth 1, has mult) |
| Sigma vs Sigma | `'Sigma` (arity 2, binder-depth 1) |
| lam vs lam | `'lam` (arity 2, binder-depth 1) |
| app vs app | `'app` (arity 2) |
| pair vs pair | `'pair` (arity 2) |
| Eq vs Eq | `'Eq` (arity 3) |
| Vec vs Vec | `'Vec` (arity 2) |
| Fin vs Fin | `'Fin` (arity 1) |
| suc vs suc | `'suc` (arity 1) |
| nat-val vs nat-val | `'nat-val` (arity 0, value-based) |

All 10 already have ctor-descs registered in Track 0. The migration is: instead
of pattern-matching `(and (expr-Pi? a) (expr-Pi? b))`, call `(sre-constructor-tag domain a)`
and `(sre-constructor-tag domain b)`, check if tags match, and extract components
via the ctor-desc.

### 2.3 Non-Structural Cases (Persist As-Is)

| Classifier tag | Count | Why it stays |
|---------------|-------|-------------|
| `'ok` (identity) | 8 | Pre-structural check: equal? / holes / same-meta |
| `'flex-rigid` | 2 | Meta solving — persists until PM 8F |
| `'flex-app` | 2 | Applied meta — persists until PM 8F |
| `'level` | 1 | Level lattice — different domain, own merge |
| `'union` | 1 | Union matching — iterative, not structural decomposition |
| `'retry` | 7 | HKT normalization — preprocessing, not decomposition |
| `'conv` | 5 | Conversion fallback — last resort |

These cases are NOT structural decomposition — they're meta-variable handling,
preprocessing, or fallback. They persist through Track 2 and get addressed
by later tracks (PM 8F for flex cases, SRE Track 3 for union matching).

### 2.4 Supporting Infrastructure Assessment

| Component | Track 2 impact | When it changes |
|-----------|---------------|-----------------|
| `zonk` | Unchanged | PM 8F (metas as cells → cell reads) |
| `ground-expr?` | Unchanged | PM 8F |
| `meta-solution` | Unchanged | PM 8F |
| `fresh-meta` | Unchanged | PM 8F |
| `solve-meta!` | Unchanged | PM 8F (cell writes) |
| `whnf` (normalization) | Unchanged | SRE Track 6 (reduction-on-SRE) |
| `unify-core` | Modified: classifier dispatch | This track |
| `classify-whnf-problem` | Modified: structural → SRE | This track |
| `unify-whnf` | Modified: SRE dispatch | This track |
| `punify-dispatch-*` | Already uses SRE (Track 0) | Already done ✅ |

---

## 3. NTT Speculative Syntax

**What this migration looks like in NTT terms:**

Before (hardcoded classifier):
```
;; Manual form registry as pattern match
;; Each case is a hardcoded polynomial summand
classify-whnf-problem : TypeExpr × TypeExpr → DecompositionTag
```

After (SRE-based dispatch):
```prologos
;; The type lattice as a structural lattice — ALL structural knowledge
;; lives in the data definition
data TypeExpr
  := type-bot | type-top
   | expr-pi [domain : TypeExpr] [codomain : TypeExpr]
   | expr-sigma [fst : TypeExpr] [snd : TypeExpr]
   | expr-app [fn : TypeExpr] [arg : TypeExpr]
   | expr-pair [fst : TypeExpr] [snd : TypeExpr]
   | expr-eq [type : TypeExpr] [lhs : TypeExpr] [rhs : TypeExpr]
   | expr-vec [elem : TypeExpr] [len : TypeExpr]
   | ...
  :lattice :structural
  :bot type-bot
  :top type-top

;; The SRE derives decomposition from the data definition.
;; No separate classifier needed — the form registry IS the data definition.
;; unify(a, b) = structural-relate(cell-a, cell-b)
;; The SRE handles: same tag → decompose, different tag → contradiction,
;; meta → wait for information.
```

**The key NTT insight**: `classify-whnf-problem` is the MANUAL implementation of
what `:lattice :structural` would auto-derive. Track 2 replaces the manual
implementation with the SRE's automatic dispatch. The 37-case classifier
becomes: "check tags via SRE, decompose via ctor-desc, handle metas separately."

---

## 4. Phased Implementation

### Phase Pre-0: Micro-Benchmark + Adversarial Baseline

**Rationale**: Track 1B's lesson — benchmark before changing reveals whether
the optimization target is correct. Measure BEFORE the migration to know
what we're working with.

**Deliverables**:
1. Micro-benchmark: `classify-whnf-problem` dispatch time for each tag type
   (Pi, app, Eq, Vec, Fin, suc, pair, Sigma, lam)
2. Micro-benchmark: `sre-constructor-tag` lookup time for same expressions
3. Compare: is SRE lookup faster or slower than hardcoded match*?
4. Adversarial: deeply nested types (Pi^10, App^10) — does SRE decomposition
   create more overhead than hardcoded decomposition?
5. Frequency counter: how many times is each classifier tag hit during full suite?

This data tells us:
- Whether SRE dispatch is faster/slower (may be FASTER: hash lookup vs linear match)
- Which tags are hot (Pi and app are likely dominant — optimize those)
- Whether adversarial nesting is a concern

### Phase 1: Unify Classifier → SRE Dispatch

**The core migration.** Replace structural cases in `classify-whnf-problem`
with SRE ctor-desc dispatch.

**Current flow:**
```
unify-core → zonk → classify-whnf-problem → (match* on struct types) → tag
           → unify-whnf → (dispatch on tag) → recursive unify-core
```

**New flow:**
```
unify-core → zonk → sre-classify-problem → (SRE tag lookup) → decomposition
           → unify-whnf-sre → (dispatch on SRE result) → recursive unify-core
```

**Deliverables**:
1. `sre-classify-problem`: New function that replaces `classify-whnf-problem`'s
   structural cases. For each pair (a, b):
   - Pre-check: equal? / holes / same-meta → `'ok` (unchanged)
   - Meta check: `expr-meta?` → `'flex-rigid` or `'flex-app` (unchanged)
   - **SRE dispatch**: `(sre-constructor-tag type-sre-domain a)` and
     `(sre-constructor-tag type-sre-domain b)` → if same tag, extract
     components via ctor-desc → return `'sre-decompose` with components
   - Level check: both `expr-Type?` → `'level` (unchanged)
   - Union check: both `expr-union?` → `'union` (unchanged)
   - Retry: normalizable-builtin?, ann → `'retry` (unchanged)
   - Fallback: `'conv` (unchanged)

2. `unify-whnf` updated: new `'sre-decompose` tag dispatches to
   recursive `unify-core` on component pairs extracted by the SRE.
   Pi/Sigma/lam binder handling moved to Phase 2.

3. **Non-binder structural cases migrated first**: app, pair, Eq, Vec, Fin,
   suc. These are simple: same tag → extract components → recurse on
   component pairs. No binder opening needed.

4. Test: full suite passes. Acceptance file passes.

**What doesn't change yet**: Pi, Sigma, lam (binder cases — Phase 2).
flex-rigid, flex-app (meta cases — Phase 3). Union matching (future track).
Level unification (separate lattice). Retry/conv (preprocessing/fallback).

### Phase 2: Binder Handling via SRE

Migrate Pi, Sigma, and lam cases. These require binder opening: the
codomain/snd-type/body contains a bound variable that must be opened
with a fresh fvar before component decomposition.

**Deliverables**:
1. `sre-decompose-binder` integration: The binder-open-fn field on
   ctor-desc (scaffolded in Track 0, binder-depth used in Track 1)
   gets a real implementation for Pi, Sigma, lam.
2. Pi case: extract domain + mult, open codomain with fresh fvar,
   recurse on (domain-a, domain-b) and (opened-codomain-a, opened-codomain-b).
   Mult handling: `unify-mult` on (mult-a, mult-b).
3. Sigma case: extract fst-type, open snd-type with fresh fvar, recurse.
4. Lam case: extract domain, open body with fresh fvar, recurse.
5. **Validation**: Phase 2 is the highest-risk phase (Pi is the most
   common binder, any regression is visible). Run full suite after each
   sub-migration (Pi first, then Sigma, then lam).

### Phase 3: Meta Handling Integration

The `flex-rigid` and `flex-app` cases are NOT structural decomposition —
they're meta-variable resolution. They persist as-is through Track 2.
However, we should ensure the SRE dispatch doesn't interfere with meta
handling.

**Deliverables**:
1. Verify: `sre-constructor-tag` returns `#f` for `expr-meta` (it should —
   metas are not structural forms). This means the SRE dispatch falls
   through to the meta check. Confirm this explicitly.
2. Verify: `sre-constructor-tag` returns `#f` for `expr-fvar` (free
   variables — not structural forms). Confirm.
3. **Edge case**: What if one side is structural and the other is a meta?
   e.g., `(expr-Pi ...)` vs `(expr-meta ?X)`. The classifier should see
   `?X` first (before SRE dispatch) and return `'flex-rigid`. The ordering
   in `sre-classify-problem` must check metas BEFORE SRE tags.
4. Test: specifically test meta-vs-structural cases.

### Phase 4: Subtype/Conversion Fallback via SRE

The `check` function's conversion fallback (line 2462) currently:
```racket
(or (unify-ok? (unify ctx t t1))
    (match* ((whnf t) (whnf t1))
      [((expr-Type l1) (expr-Type l2)) (level<=? l2 l1)]
      [(t-w t1-w) (subtype? t1-w t-w)]))
```

Track 1 delivered `structural-subtype-ground?` (direct recursive checker).
This phase wires it into the conversion fallback.

**Deliverables**:
1. Replace `(subtype? t1-w t-w)` with `(structural-subtype-ground? type-sre-domain t1-w t-w)`
   in the conversion fallback. This uses the SRE's ctor-desc + variance
   for compound subtype checking.
2. The `subtype?` function in `subtype-predicate.rkt` is the flat predicate
   for atoms. `structural-subtype-ground?` already calls it for leaf cases.
   The conversion fallback delegates to the SRE, which handles both compound
   (via variance) and atomic (via flat predicate) cases.
3. Cumulativity (`level<=?`) persists — it's a level-lattice concern, not
   a type-lattice concern.
4. Test: subtype cases in test suite + adversarial compound subtype queries.

### Phase 5: Polarity Inference Integration

User-defined types currently get `#f` variance (no structural subtyping).
This phase wires polarity inference into `data` elaboration.

**Deliverables**:
1. During `data` definition elaboration (in `elaborator.rkt`), after
   creating ctor-descs for each constructor, run polarity inference on the
   type parameters. Fill in `component-variances` automatically.
2. Polarity inference algorithm: iterative fixpoint on `{ø, +, -, =}` lattice.
   Walk constructor fields, track type parameter positions (positive = covariant,
   negative = contravariant, both = invariant). Handle recursive types via
   fixpoint iteration. Handle mutual recursion by iterating over the full group.
3. Test: `data Box A := box A` → variance `(+)` (covariant). `Box Nat <: Box Int`
   should hold. `data Fn A B := fn (A -> B)` → variance `(- +)`.
   `Fn Int Nat <: Fn Nat Int` should hold (contravariant domain, covariant codomain).
4. GADT edge case: document that GADT-constrained constructors produce
   invariant (`=`) variance. Not implemented but the `=` case is handled
   correctly (equality check, not subtype).

### Phase 6: Verification + Benchmarks + PIR

**Deliverables**:
1. Full test suite: all pass, within performance bounds
2. Acceptance file: all pass
3. Micro-benchmark comparison: classify dispatch time before vs after
4. A/B benchmark: `bench-ab.rkt` on comparative suite
5. Frequency data: SRE tag hits vs hardcoded tag hits (should be identical)
6. PIR written per methodology (16 questions)

---

## 5. Performance Expectations

| Metric | Baseline | Target | Rationale |
|--------|----------|--------|-----------|
| Full suite wall time | 236.7s | ≤ 244s (3%) | SRE lookup replaces match*; overhead is ctor-desc hash lookup vs linear pattern match |
| Unify dispatch (hot path) | TBD (Pre-0) | ≤ 1.1× | Hash lookup may be FASTER for 23-entry registry vs 37-case match* |
| Memory | 7392 tests | ≤ 7400 tests | No new cells/propagators from dispatch change |
| Compound subtype check | 0.5μs (Track 1B) | ≤ 0.5μs | structural-subtype-ground? unchanged |

**How we know we're done** (completion criteria):
1. `classify-whnf-problem` has zero hardcoded structural pattern matches
   (all `'sub`, `'pi`, `'binder` cases replaced by SRE dispatch)
2. All 7392+ tests pass
3. Performance within bounds (measured, not assumed)
4. Polarity inference produces correct variance for a test suite of
   user-defined types (Box, Fn, List, Strange, mutual recursion)
5. PIR written with §1-§16

---

## 6. Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|------------|
| Pi binder regression | HIGH | Migrate Pi LAST among binders (most tested); full suite after each sub-migration |
| SRE tag lookup slower than match* | MEDIUM | Pre-0 benchmark answers this; if slower, optimize ctor-desc lookup to use struct-predicate directly |
| nat-val cross-representation cases | LOW | These aren't pure structural decomposition (nat-val(0) = zero requires value comparison). May need special handling in SRE or persist as hardcoded cases |
| HKT normalization retry cases | LOW | These are preprocessing, not decomposition. Persist as-is in the classifier |
| Polarity inference for recursive types | MEDIUM | Fixpoint convergence proven for small lattice; test on actual codebase types |

---

## 7. Principles Alignment (Challenge, Not Catalogue)

### Propagator-First
**Challenge**: Does this migration actually put MORE on the network?
**Answer**: No — it reorganizes how structural knowledge is accessed (from
hardcoded match to ctor-desc registry) but doesn't add new propagators or
cells. The network-level behavior is unchanged. This is a CODE organization
improvement, not an architectural one. The architectural improvements come
from what this ENABLES (PM 8F, SRE Track 3-5).

### Data Orientation
**Challenge**: Is the ctor-desc registry more data-oriented than the match?
**Answer**: Yes — the classifier's 37 cases are CODE. The ctor-desc registry
is DATA (structs with fields). Data is inspectable, composable, extensible
without modifying the dispatcher. New AST nodes register a ctor-desc; the
classifier doesn't need modification.

### Correct-by-Construction
**Challenge**: The nat-val cross-representation cases (nat-val(0) = zero,
nat-val(n) = suc(n-1)) are not pure structural decomposition. They require
value comparison. Should they be ctor-descs or hardcoded?
**Answer**: They're SEMANTIC equalities between different representations
of the same value. They're not structural decomposition — they're conversion
rules. Keep them as hardcoded cases in the retry/conv path. The SRE handles
STRUCTURAL decomposition; conversion between representations is a different
concern (Track 6/PM 9: reduction-on-SRE).

### Completeness
**Challenge**: Are we deferring anything that should be done now?
**Answer**: flex-rigid/flex-app (meta handling) are deferred to PM 8F. This
is a genuine dependency, not a rationalization — meta cells don't exist yet.
Union matching is deferred to SRE Track 3. Level unification is a separate
lattice concern. All deferrals have clear dependency justifications.

### Composition
**Challenge**: Does the SRE dispatch compose with the existing classifier
for non-structural cases?
**Answer**: Yes — the new `sre-classify-problem` checks metas first, then
SRE tags, then falls through to non-structural cases (level, union, retry,
conv). The composition is: identity → metas → SRE → non-structural → fallback.

---

## 8. What This Opens Up

After Track 2:
- **SRE Track 3 (Trait Resolution)**: The SRE is proven under full elaboration load.
  Trait resolution can use the same ctor-desc dispatch for impl pattern matching.
- **SRE Track 4 (Sessions)**: Session duality already uses SRE (Track 1). Track 4
  retires the imperative `dual` function and uses SRE for all session verification.
- **SRE Track 5 (Patterns)**: Pattern compilation can use ctor-desc for scrutinee
  decomposition, sharing the same structural knowledge.
- **PM 8F (metas as cells)**: The elaborator's meta handling is isolated to
  flex-rigid/flex-app cases. When metas become cells, only those cases change.
- **Polarity inference**: User-defined types get automatic structural subtyping,
  making subtyping truly first-class.
