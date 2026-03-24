# SRE Track 2: Elaborator-on-SRE — Stage 2/3 Design

**Stage**: 2 (Audit) + 3 (Design), combined
**Date**: 2026-03-23
**Series**: SRE (Structural Reasoning Engine)
**Status**: D.2 — incorporating Pre-0 benchmark findings
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
| Pre-0 | Micro-benchmark + adversarial baseline | ✅ | **Critical finding**: linear scan 4-200× slower than struct predicates |
| 0 | O(1) struct-type dispatch (`prop:ctor-desc`) | ⬜ | Foundation: makes SRE dispatch competitive with hardcoded match |
| 1 | Unify classifier → SRE ctor-desc dispatch | ⬜ | The core migration (non-binder cases) |
| 2 | Binder handling via SRE | ⬜ | Pi codomain, Sigma snd-type, lam body |
| 3 | Meta handling verification | ⬜ | Verify SRE dispatch doesn't interfere with flex cases |
| 4 | Subtype/conversion fallback via SRE | ⬜ | Track 1's structural-subtype-ground? + cumulativity |
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
- Unification wall time: ≤ 0% regression (O(1) prop:ctor-desc lookup FASTER than linear cond chain)
- Full suite wall time: potential IMPROVEMENT (4ns dispatch vs 123-342ns cond chain)
- Memory: neutral (same cell/propagator count — SRE lookup replaces hardcoded match, doesn't add cells)
- Phase 0 (O(1) dispatch) should deliver measurable speedup on unification-heavy benchmarks

---

## 1b. Pre-0 Benchmark Findings (D.2)

Micro-benchmarks revealed a critical performance issue that CHANGES the design:

### Raw Data

| Operation | Time (ns/call) | Notes |
|-----------|---------------|-------|
| Direct struct predicate (`expr-Pi?`) | 4 | The performance floor |
| Classifier Pi-vs-Pi | 162 | ~10 cond branches before structural match |
| Classifier app-vs-app | 330 | Later in cond chain |
| Classifier atom-vs-atom | 123 | Falls through to `'conv` |
| SRE `sre-constructor-tag` Pi | 357 | Linear scan of 28 recognizers |
| SRE `sre-constructor-tag` app | 96 | Registered early |
| SRE `sre-constructor-tag` atom | 825 | Scans ALL 28, finds none |

### Key Findings

1. **`ctor-tag-for-value` does a LINEAR SCAN** of all registered recognizer
   closures. With 28 descriptors, worst case is 28 function calls (~825ns).
   This is 200× slower than a struct predicate (4ns).

2. **Registration order determines performance.** `Eq` (43ns, registered early)
   vs `suc` (320ns, registered late). Fragile and non-deterministic.

3. **Atoms are catastrophic.** Most common expressions in the type checker
   (expr-Int, expr-Nat, expr-Bool) have NO ctor-desc. Every atom pays the
   full 28-recognizer scan. This would make SRE dispatch 7× slower than
   the classifier for the most common case.

4. **The classifier's cond chain is also suboptimal.** It tests ~10 branches
   (equal?, 4 hole checks, same-meta, 2 meta checks) before reaching
   structural predicates. The structural predicates themselves are 4ns each,
   but the cond overhead is 120-330ns.

### Architectural Insight: Static Dispatch vs Dynamic Reasoning

**Not everything needs to be on the network.**

The key distinction is between STRUCTURAL KNOWLEDGE (static configuration)
and STRUCTURAL REASONING (dynamic computation):

| Concern | Character | Where it belongs |
|---------|-----------|-----------------|
| "What form is this value?" | Static routing decision | O(1) dispatch (off-network) |
| "Decompose into sub-cells" | Dynamic computation | On-network (propagators) |
| "Relate sub-cells structurally" | Dynamic computation | On-network (propagators) |
| "Reconstruct from sub-cells" | Dynamic computation | On-network (propagators) |
| "Detect contradiction" | Dynamic computation | On-network (cell writes) |

**NF-Narrowing precedent**: The definitional tree is a pre-computed dispatch
structure — given a constructor tag, the DT immediately knows which branch
to take (O(1)). But the NARROWING itself (creating logic variables,
propagating constraints) is fully on-network. Nobody would put DT traversal
on the propagator network — it's a routing decision, not a computation.

**The SRE form dispatch is the same pattern**: "what structural form does this
value have?" is a routing decision (static, O(1)). "Decompose it and propagate
relationships" is the computation (dynamic, on-network). Provenance starts at
decomposition, not at dispatch. The reasoning is on-network; the routing is
compiled infrastructure.

### Design Consequence: `prop:ctor-desc` Struct-Type Property

The solution: attach ctor-desc directly to each AST struct definition via
Racket's struct-type property mechanism.

```racket
;; Define the property
(define-values (prop:ctor-desc ctor-desc-has? ctor-desc-ref)
  (make-struct-type-property 'ctor-desc))

;; AST struct carries its own descriptor
(struct expr-Pi (mult domain codomain)
  #:property prop:ctor-desc <pi-desc>)

;; O(1) lookup — single vtable access
(define (ctor-tag-for-value-fast v)
  (and (ctor-desc-has? v) (ctor-desc-ref v)))
```

**Expected performance**: ~4ns per lookup (vtable access, same as struct predicate).
This makes SRE dispatch FASTER than the classifier's cond chain (4ns vs 123-342ns).

**Data Orientation**: The value carries its own structural identity. No external
registry scanning. The ctor-desc IS the NTT's structural type annotation,
attached to the data itself.

**First-Class by Default**: Structural identity is a property of the value,
not of the lookup context. Any function can determine a value's structural
form in O(1) without importing the registry.

**Blast radius**: Modifying syntax.rkt struct definitions touches the entire
pipeline. Mitigation: the property is ADDITIVE — existing struct fields,
pattern matching, and serialization are unaffected. The property adds a slot
to the struct type descriptor (compile-time), not to struct instances (runtime).

**Challenge**: ctor-descs reference functions from elaborator-network.rkt
(extract-fn, reconstruct-fn). These can't be available at syntax.rkt
definition time (circular dependency). Resolution: the property is set to
a THUNK or PARAMETER that's populated at registration time, not at struct
definition time. Or: the property holds a TAG (symbol), and the registry
maps tags to full ctor-descs. Lookup is: property → tag (O(1)), then
tag → ctor-desc (O(1) hash-ref). Two O(1) lookups = still O(1).

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

### Phase Pre-0: Micro-Benchmark + Adversarial Baseline ✅

**Completed.** See §1b above for full results.

**Key findings that changed the design**:
1. `ctor-tag-for-value` linear scan is 4-200× slower than struct predicates
2. Atom case is catastrophic (825ns for a "not found" scan)
3. The classifier's cond chain is also suboptimal (123-342ns for routing)
4. O(1) struct-type dispatch would make SRE FASTER than the classifier

**Benchmark file**: `benchmarks/micro/bench-classify-vs-sre.rkt`

### Phase 0: O(1) Struct-Type Dispatch

**Rationale**: Pre-0 benchmark proved that the SRE cannot replace the
classifier with the current linear-scan `ctor-tag-for-value`. O(1)
dispatch is a PREREQUISITE for the migration, not an optimization.

**Approach**: Two-level O(1) dispatch via struct-type property:

1. Define `prop:ctor-desc-tag` as a struct-type property in syntax.rkt.
   The property holds a SYMBOL tag (not the full ctor-desc — avoids
   circular dependency with elaborator-network.rkt).

2. Each AST struct in syntax.rkt that has structural form gets the
   property:
   ```racket
   (struct expr-Pi (mult domain codomain)
     #:property prop:ctor-desc-tag 'Pi)
   ```

3. `ctor-tag-for-value` becomes O(1):
   ```racket
   (define (ctor-tag-for-value-fast v)
     (and (ctor-desc-tag-has? v)
          (let ([tag (ctor-desc-tag-ref v)])
            (lookup-ctor-desc tag))))
   ```
   Property access (~4ns) → hash-ref (~15ns) = ~19ns total.
   vs current: linear scan of 28 closures (~300-825ns).

4. `sre-constructor-tag` updated to use `ctor-tag-for-value-fast`.

5. The existing `register-ctor!` function continues to populate the
   hash tables — the property provides the TAG, the hash provides the
   full ctor-desc. Registration is unchanged.

**Deliverables**:
1. `prop:ctor-desc-tag` property definition in syntax.rkt
2. Property added to all 23+ structural AST structs
3. `ctor-tag-for-value` updated to use property-first dispatch
4. Fallback to linear scan for non-AST types (term-value, session types)
   that may not have the property
5. Micro-benchmark confirmation: ~19ns per lookup (vs 300-825ns)
6. Full suite passes — no behavioral change

**Blast radius mitigation**:
- The property is ADDITIVE: existing struct fields, pattern matching,
  and serialization are unaffected
- Property adds to struct type descriptor (compile-time), not instances (runtime)
- Backward compatible: `ctor-tag-for-value` falls back to linear scan
  for values without the property
- `raco make driver.rkt` recompiles all dependents (standard after syntax.rkt change)

**What this enables**: All subsequent phases use O(1) SRE dispatch.
The classifier migration (Phase 1) becomes unambiguously faster than
the current cond chain.

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

| Metric | Baseline (Pre-0 measured) | Target | Rationale |
|--------|--------------------------|--------|-----------|
| Full suite wall time | 236.7s | ≤ 236.7s (0% regression, possible improvement) | O(1) dispatch is faster than cond chain |
| Classifier dispatch (hot) | 162-342 ns/call | ≤ 50 ns/call | prop:ctor-desc (~4ns) + hash-ref (~15ns) + pre-checks (~20ns) |
| Atom dispatch (failure case) | 123-825 ns/call | ≤ 30 ns/call | Property check returns #f in ~4ns; no scan |
| `ctor-tag-for-value` | 43-825 ns/call | ≤ 19 ns/call | O(1) replaces O(N) linear scan |
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
| syntax.rkt struct property blast radius | HIGH | Property is additive (no field changes). `raco make driver.rkt` recompiles all. Run full suite immediately after Phase 0. |
| Circular dependency: ctor-desc at syntax.rkt time | HIGH | Two-level dispatch: property holds TAG (symbol), hash holds full ctor-desc. Tags are constants; descs are registered later. |
| Pi binder regression | HIGH | Migrate Pi LAST among binders (most tested); full suite after each sub-migration |
| nat-val cross-representation cases | LOW | Semantic equalities (nat-val(0) = zero). Persist as hardcoded cases — these are CONVERSION rules, not structural decomposition |
| HKT normalization retry cases | LOW | Preprocessing, not decomposition. Persist as-is in classifier |
| Polarity inference for recursive types | MEDIUM | Fixpoint convergence proven for small lattice; test on actual codebase types |
| Property not present on non-AST types | LOW | Fallback to linear scan for term-value, session types. These are low-frequency paths. |

---

## 7. Principles Alignment (Challenge, Not Catalogue)

### Propagator-First
**Challenge**: Does this migration put more on the network? Is O(1)
dispatch "off-network" and therefore a principles violation?
**Answer**: No. The distinction is between STRUCTURAL KNOWLEDGE (static
configuration — "what form is this value?") and STRUCTURAL REASONING
(dynamic computation — "decompose, relate, propagate"). Structural
knowledge is the dispatch table; structural reasoning is the propagator
network. The dispatch table is analogous to NF-Narrowing's definitional
tree — a pre-computed routing structure that nobody would put on the
propagator network because it never changes. The network handles the
REASONING that follows dispatch: sub-cell creation, relationship
propagation, contradiction detection. All provenance and inter-network
intelligence come from the reasoning, not from the dispatch.

This is a principled architectural boundary: static dispatch (O(1),
compiled) feeds into dynamic reasoning (on-network, propagator-based).
The boundary is clean and explicit.

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
