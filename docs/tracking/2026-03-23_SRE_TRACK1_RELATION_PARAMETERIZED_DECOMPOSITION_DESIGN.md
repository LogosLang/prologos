# SRE Track 1: Relation-Parameterized Structural Decomposition

**Stage**: 2/3 Combined (Audit + Design)
**Date**: 2026-03-23
**Series**: SRE (Structural Reasoning Engine)
**Depends on**: SRE Track 0 (Form Registry) ✅
**Enables**: SRE Track 2 (Elaborator-on-SRE), CIU Track 3 (trait-dispatched access)

## Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| 0 | Acceptance baseline | ⬜ | |
| 1 | Relation type + variance on ctor-desc | ⬜ | |
| 2 | Subtype-aware structural-relate | ⬜ | |
| 3 | Duality-aware structural-relate | ⬜ | |
| 4 | Integration: subtype? delegation | ⬜ | |
| 5 | Integration: session duality propagator | ⬜ | |
| 6 | Verification + benchmarks | ⬜ | |

## 1. Stage 2 Audit: Relations in the Codebase

### 1.1 Subtyping

**Location**: `typing-core.rkt`, lines 98-114
**Function**: `(subtype? t1 t2)` — flat predicate, no structural decomposition
**Call sites**: 2
- `typing-core.rkt:2501` — check mode fallback: `(subtype? t1-w t-w)`
- `qtt.rkt:2401` — checkQ mode fallback: `(subtype? t1-w t-w)`

**Current implementation**: 9 hardcoded edges (Nat<:Int, Nat<:Rat, Int<:Rat,
Posit8<:16<:32<:64) + registry fallback for library-defined subtypes via
`subtype-pair?`. Returns `#t` or `#f`. No structural decomposition — if `List Nat`
and `List Int` are compared, `subtype?` doesn't decompose the List to check
`Nat <: Int` on the element. It just returns `#f`.

**Gap**: Structural subtyping is missing. `subtype?` only handles flat base types.
Compound types (Pi, List, Map, PVec) don't participate. This means:
- `List Nat` is NOT a subtype of `List Int` (should be, List is covariant)
- `(Nat -> Rat)` is NOT a subtype of `(Int -> Int)` (should be, Pi is
  contravariant in domain, covariant in codomain)

The SRE can fix this: `sre-structural-subtype(cell-a, cell-b)` decomposes
compound types with variance annotations, creating sub-cell subtyping constraints.

### 1.2 Duality

**Location**: `sessions.rkt`, lines 51-67
**Function**: `(dual s)` — recursive structural involution
**Call sites**: 6 (across 4 files)
- `session-propagators.rkt:264,272` — bidirectional duality propagator
- `typing-sessions.rkt:232,249,251,253` — session compatibility checking
- `elaborator.rkt:4033` — dual endpoint generation

**Current implementation**: Recursive match on session constructors:
Send↔Recv, DSend↔DRecv, AsyncSend↔AsyncRecv, Choice↔Offer, mu preserved,
svar/end unchanged, meta unchanged. This IS structural decomposition — it
recurses into sub-components and swaps paired constructors.

**Connection to SRE**: Duality is structural decomposition with a *different
structural relation*. Instead of "these two cells should be equal," it's
"these two cells should be duals." The SRE already handles structural
decomposition (constructor dispatch, sub-cell creation, propagator installation).
Adding duality means: when decomposing `Send(A, S)` against a duality
relation, create sub-cells where `A` is related by equality (payload type
is the same) but `S` is related by duality (continuation is dual).

### 1.3 Coercion

**Location**: `reduction.rkt`, lines 917-970; `elaborator.rkt`, line 3180
**Functions**: `try-coerce-to-int`, `try-coerce-to-rat`, `try-coerce-via-registry`,
`try-coerce-to-posit`, `coerce-fn`

**Current implementation**: Runtime value transformations. These convert values
between types (Nat→Int, Int→Rat) at reduction time, not at type-checking time.

**Assessment**: Coercion is a runtime/reduction concern, not a compile-time
structural relation. The SRE operates during elaboration (type checking), not
during reduction. Coercion insertion (where the elaborator wraps expressions
with coercion functions) IS an elaboration concern — but it requires the
elaborator-on-SRE architecture (Track 2). **Defer coercion to Track 2.**

### 1.4 Summary

| Relation | Where | Structural? | SRE Track 1 scope? |
|----------|-------|-------------|-------------------|
| Equality | sre-core.rkt | Yes (Track 0) | Already done |
| Subtyping | typing-core.rkt | No (flat predicate) | **Yes** — add structural |
| Duality | sessions.rkt | Yes (recursive) | **Yes** — integrate with SRE |
| Coercion | reduction.rkt | No (runtime) | Defer to Track 2 |
| Isomorphism | (not yet) | N/A | Defer |

## 2. Design: Relation-Parameterized SRE

### 2.1 Core Change: Relation as Parameter

The key insight: `sre-make-structural-relate-propagator` currently hardcodes
equality semantics (merge both cells to unified value, decompose recursively).
Track 1 parameterizes this by relation:

```
;; Track 0 (current):
(sre-make-structural-relate-propagator domain cell-a cell-b)
;; → equality: write unified to both, decompose symmetrically

;; Track 1 (new):
(sre-make-structural-relate-propagator domain cell-a cell-b #:relation rel)
;; → equality: write unified to both, decompose symmetrically
;; → subtype:  check a <: b, decompose with variance
;; → duality:  check a ~ dual(b), decompose swapping pairs
```

The `#:relation` parameter is an optional keyword argument defaulting to
`'equality`. This is backward-compatible: all existing call sites get
equality behavior without changes.

### 2.2 Variance on ctor-desc

For subtyping, each component of a constructor has a variance:
- **Covariant** (+): `List A` — if `A <: B` then `List A <: List B`
- **Contravariant** (-): Pi domain — if `B <: A` then `(A -> C) <: (B -> C)`
- **Invariant** (=): mutable containers — must be equal, not sub/super
- **Phantom** (ø): unused type parameter — any subtyping holds

Add a `component-variances` field to `ctor-desc`:

```racket
(struct ctor-desc
  (tag arity recognizer-fn extract-fn reconstruct-fn
   component-lattices binder-depth domain
   component-variances)  ;; NEW: '(+ - = ø) per component, or #f for default
  #:transparent)
```

When `component-variances` is `#f`, all components default to invariant
(equality). This preserves Track 0 behavior. When specified, the SRE uses
variance to determine the relation for sub-cell pairs:

| Variance | Sub-cell relation (when parent relation is subtype) |
|----------|-----------------------------------------------------|
| `+` (covariant) | sub-a <: sub-b (same direction) |
| `-` (contravariant) | sub-b <: sub-a (reversed direction) |
| `=` (invariant) | sub-a = sub-b (equality) |
| `ø` (phantom) | no constraint |

### 2.3 Duality Relation: Constructor Pairing

For duality, the SRE needs to know which constructors are duals:
- Send ↔ Recv
- DSend ↔ DRecv
- AsyncSend ↔ AsyncRecv
- Choice ↔ Offer

This is a property of the domain, not of individual constructors. Add
a `dual-pairs` field to `sre-domain`:

```racket
(struct sre-domain
  (name lattice-merge contradicts? bot? bot-value
   meta-recognizer meta-resolver
   dual-pairs)       ;; NEW: '((Send . Recv) (DSend . DRecv) ...) or #f
  #:transparent)
```

When `dual-pairs` is `#f` (default), duality relation is not supported
for that domain. When specified, the SRE uses it during duality-relate:
if cell-a has tag `Send`, look up its dual (`Recv`), extract components,
create sub-cells with the appropriate sub-relations.

Sub-relations under duality:
- Payload type: equality (both endpoints communicate the same type)
- Continuation: duality (the rest of the protocol is dual)
- mu/svar: equality (recursion points are shared)

### 2.4 sre-relation Struct

```racket
;; A first-class relation value
(struct sre-relation
  (name           ; symbol: 'equality, 'subtype, 'duality
   propagate-fn   ; (domain cell-a cell-b va vb → net*) — how to propagate
   sub-relation-fn ; (relation parent-variance → relation) — sub-cell relation
   )
  #:transparent)
```

Three built-in relations:

```racket
(define sre-equality
  (sre-relation
   'equality
   ;; Propagate: merge both cells to unified, decompose symmetrically
   sre-propagate-equality
   ;; Sub-relation: always equality (no variance under equality)
   (λ (rel variance) sre-equality)))

(define sre-subtype
  (sre-relation
   'subtype
   ;; Propagate: check a ≤ b (no merge — subtyping is directional)
   sre-propagate-subtype
   ;; Sub-relation: apply variance
   (λ (rel variance)
     (case variance
       [(+) sre-subtype]          ;; covariant: same direction
       [(-) sre-subtype-reverse]  ;; contravariant: flip
       [(=) sre-equality]         ;; invariant: equality
       [(ø) sre-phantom]))))      ;; phantom: no constraint

(define sre-duality
  (sre-relation
   'duality
   ;; Propagate: decompose with dual constructor pairing
   sre-propagate-duality
   ;; Sub-relation: payload=equality, continuation=duality
   (λ (rel variance)
     ;; For duality, variance is replaced by per-component sub-relation:
     ;; payload → equality, continuation → duality
     ;; This comes from the ctor-desc's component-sub-relations field
     ;; (see §2.5 below)
     rel)))
```

### 2.5 Per-Component Sub-Relations for Duality

Variance handles subtyping. But duality needs per-component sub-relation
specification (payload=equality, continuation=duality). This is different
from variance — it's a mapping from component position to relation.

Option A: Add `component-sub-relations` to ctor-desc (a list of relation
symbols per component, used when the parent relation is duality).

Option B: Encode in the relation's `sub-relation-fn`, using the component
index.

**Decision**: Option A is more data-oriented. The ctor-desc for `Send` would be:

```racket
(ctor-desc
  'Send 2 sess-send? (λ (s) (list (sess-send-type s) (sess-send-cont s)))
  (λ (vals) (sess-send (first vals) (second vals)))
  '(type-lattice session-lattice)  ;; component-lattices
  0  ;; binder-depth
  'session  ;; domain
  '(= +)   ;; component-variances (for subtyping if ever needed)
  '(equality duality))  ;; component-sub-relations (for duality)
```

The `component-sub-relations` field says: under duality, the first component
(payload type) uses equality, and the second (continuation) uses duality.

This field is `#f` for most constructors (equality relation doesn't need it).
It's only populated for constructors in domains that support duality.

**Combined ctor-desc expansion**: Two new fields:

```racket
(struct ctor-desc
  (tag arity recognizer-fn extract-fn reconstruct-fn
   component-lattices binder-depth domain
   component-variances       ;; NEW: '(+ - = ø) or #f
   component-sub-relations)  ;; NEW: '(equality duality ...) or #f
  #:transparent)
```

This brings ctor-desc to 10 fields. Per the D.2 critique, we're monitoring
for god-struct. At 10, we're at the boundary. If Track 2 adds more, factor
into core + capabilities.

### 2.6 NTT Speculative Syntax

What Track 1 implements, expressed in NTT:

```prologos
;; Level 0: Type lattice with structural subtyping
data TypeExpr
  := type-bot | type-top
   | expr-pi [domain : TypeExpr :variance -]     ;; contravariant
             [codomain : TypeExpr :variance +]   ;; covariant
   | expr-app [fn : TypeExpr :variance =]        ;; invariant
              [arg : TypeExpr :variance +]        ;; covariant
   | expr-list [elem : TypeExpr :variance +]      ;; covariant
  :lattice :structural
  :bot type-bot
  :top type-top

;; Level 0: Session lattice with duality
data SessionExpr
  := sess-bot | sess-top
   | sess-send [payload : TypeExpr :under-duality equality]
               [cont : SessionExpr :under-duality duality]
   | sess-recv [payload : TypeExpr :under-duality equality]
               [cont : SessionExpr :under-duality duality]
   | sess-choice [branches : ...]
   | sess-offer  [branches : ...]
  :lattice :structural
  :bot sess-bot
  :top sess-top
  :dual-pairs [[sess-send sess-recv]
               [sess-choice sess-offer]]

;; The SRE automatically derives:
;; - For TypeExpr: structural-relate with equality (Track 0)
;;                 structural-relate with subtype (Track 1, using :variance)
;; - For SessionExpr: structural-relate with equality (Track 0)
;;                    structural-relate with duality (Track 1, using :dual-pairs + :under-duality)

;; Usage in type checking (what Track 2 would generate):
;; structural-relate cell-a cell-b :relation subtype
;; → SRE decomposes with variance, creating sub-cell subtype constraints

;; Correspondence table:
;; NTT                          | Racket (Track 1)
;; -----------------------------|----------------------------------
;; :variance + on field         | component-variances '(... + ...)
;; :variance - on field         | component-variances '(... - ...)
;; :under-duality equality      | component-sub-relations '(... equality ...)
;; :dual-pairs [[Send Recv]]    | sre-domain dual-pairs
;; :relation subtype            | #:relation sre-subtype
```

## 3. Phase Design

### Phase 0: Acceptance Baseline

Run full test suite + Track 8D acceptance file. Record baseline.

### Phase 1: Relation Type + Variance on ctor-desc

**Deliverables**:
1. `sre-relation` struct in `sre-core.rkt`
2. Three built-in relations: `sre-equality`, `sre-subtype`, `sre-duality`
3. `component-variances` field on `ctor-desc` (default `#f`)
4. `component-sub-relations` field on `ctor-desc` (default `#f`)
5. `dual-pairs` field on `sre-domain` (default `#f`)
6. Update all existing ctor-desc registrations with `#f #f` for new fields
7. Update all existing sre-domain instantiations with `#f` for dual-pairs

**Test**: Existing tests pass unchanged (new fields default to Track 0 behavior).

**Risk**: Low. All changes are additive. Defaults preserve existing behavior.

### Phase 2: Subtype-Aware structural-relate

**Deliverables**:
1. `sre-propagate-subtype` function in `sre-core.rkt`
   - Directional: checks `a ≤ b` (join(a,b) = b means a ≤ b)
   - No symmetric merge — subtyping is directional
   - Decomposes compound types using variance from ctor-desc
2. `sre-make-structural-relate-propagator` accepts `#:relation` parameter
3. `sre-decompose-generic` propagates relation to sub-cell propagators
4. `sre-subtype-reverse` — subtype with flipped direction (for contravariant)
5. `sre-phantom` — no constraint (for phantom variance)
6. Variance annotations on type-domain constructors:
   - Pi: `'(- +)` (contravariant domain, covariant codomain)
   - Sigma: `'(+ +)` (covariant both)
   - App: `'(= +)` (invariant function, covariant argument)
   - List/PVec/Set: `'(+)` (covariant element)
   - Map: `'(= +)` (invariant key, covariant value)

**Test**: New test file `test-sre-subtype.rkt` with cases:
- `Nat <: Int` via flat subtype? (existing)
- `List Nat <: List Int` via SRE structural subtyping (NEW)
- `(Int -> Nat) <: (Nat -> Int)` via Pi variance (NEW)
- `Map String Nat <: Map String Int` via Map variance (NEW)
- NOT: `List Int <: List Nat` (variance prevents reversal)

**Risk**: Medium. Subtype propagation semantics are new — need to verify
the directional propagation doesn't break the termination argument.

**Termination argument for subtype relation**: The subtype propagator does
NOT merge cells bidirectionally (equality does). It checks `join(a,b) = b`
(is a ≤ b?). If yes, no cell write needed. If no, it signals a subtyping
violation (contradiction). Since no cell writes occur on success, the only
writes are contradiction signals — which are monotone (once contradicted,
always contradicted). Termination preserved.

### Phase 3: Duality-Aware structural-relate

**Deliverables**:
1. `sre-propagate-duality` function in `sre-core.rkt`
   - Reads cell-a, applies dual constructor pairing, writes to cell-b
   - Bidirectional: cell-b changes → apply inverse dual → write cell-a
   - Decomposes using component-sub-relations from ctor-desc
2. `dual-pairs` on session-sre-domain
3. `component-sub-relations` on session constructor descriptors:
   - Send/Recv: `'(equality duality)` (payload=equal, continuation=dual)
   - DSend/DRecv: `'(equality duality)`
   - AsyncSend/AsyncRecv: `'(equality duality)`
   - Choice/Offer: dual with branch sub-relations
   - mu: `'(duality)` (body is dual)
   - svar/end: self-dual (no decomposition)
4. Session constructor descriptors registered in ctor-registry

**Test**: New test file `test-sre-duality.rkt` with cases:
- `Send Int S ~ Recv Int (dual S)` — basic duality
- `dual(dual(S)) = S` — involution property
- Nested: `Send Int (Recv Bool End) ~ Recv Int (Send Bool End)`

**Risk**: Medium. Duality propagation is bidirectional (like equality) but
with constructor swapping. Need to verify that the propagator doesn't enter
an infinite loop when both cells are updated simultaneously.

**Termination argument for duality**: Similar to equality. The dual
propagator writes `dual(v)` to the opposite cell. If the cells already
satisfy duality (`dual(va) = vb`), no write occurs (net-cell-write's
identity check). If they don't, the write triggers convergence. Monotonicity
is preserved because `dual` is an involution on the session lattice (it
preserves the lattice ordering). Fuel guards provide the hard bound.

### Phase 4: Integration — subtype? Delegation

**Deliverables**:
1. `subtype?` in `typing-core.rkt` delegates structural cases to SRE
2. Flat cases (Nat<:Int, Posit8<:Posit16) remain as fast path
3. Compound cases dispatch to `sre-structural-subtype-check`
4. `sre-structural-subtype-check`: creates temporary cells for the two
   types, installs a subtype-relate propagator, runs to quiescence,
   checks for contradiction

**Design note**: This is a "query" pattern — create a temporary sub-network,
propagate, read the result. The temporary cells don't persist beyond the
query. This is similar to how we'd implement occurs-check on the network.

**Test**: `test-subtyping.rkt` extended with structural cases.

**Risk**: Low. Flat fast path unchanged. New structural path is additive.

### Phase 5: Integration — Session Duality Propagator

**Deliverables**:
1. Session duality propagator in `session-propagators.rkt` delegates to SRE
2. `(dual v)` calls replaced by SRE duality-relate propagators
3. The manual recursive `dual` function in `sessions.rkt` remains as
   a utility (used in error messages, pretty-printing) but is no longer
   the source of truth for duality checking — the SRE is.

**Test**: Existing session tests pass. New test verifying SRE-based duality.

**Risk**: Medium. The session propagator currently calls `dual` synchronously
and writes the result. The SRE-based version installs propagators that fire
asynchronously. Need to verify that the session type checking pipeline handles
this asynchrony correctly (it should — it already uses propagators for
session type inference).

### Phase 6: Verification + Benchmarks

**Deliverables**:
1. Full test suite pass
2. Track 8D acceptance file pass
3. Comparative benchmark (bench-ab.rkt)
4. New test count and timing
5. Design doc progress tracker updated

## 4. Principles Alignment (Challenge, Not Catalogue)

### 4.1 Propagator-First

**Challenge**: The subtype "query" pattern (Phase 4) creates temporary cells
and propagators for a one-shot check. Is this propagator-first, or is it
using propagators as a heavy-weight implementation of a simple predicate?

**Response**: The query pattern IS propagator-first because it handles the
structural case (List Nat <: List Int) that the flat predicate can't. For
compound types, the SRE's structural decomposition is genuinely needed —
you can't flatten `List Nat <: List Int` into a table lookup. The temporary
cells are the right abstraction: they represent the structural components
that need to be checked. The "heavy-weight" concern is addressed by the
flat fast path: Nat<:Int never creates cells.

### 4.2 Data Orientation

**Challenge**: `sre-relation` is a struct with function fields. Is this
data-oriented, or is it functions-as-data?

**Response**: The functions on sre-relation are monotone lattice operations —
they're the data-orientation interpretation of "what this relation does."
The alternative (a case dispatch on relation name) would be code-oriented,
not data-oriented. The struct makes relations first-class, composable,
inspectable. This is the same justification as sre-domain in Track 0.

### 4.3 Correct-by-Construction

**Challenge**: Variance annotations are per-constructor, manually specified.
What prevents a wrong variance annotation (marking Pi domain as covariant)?

**Response**: This is correct-by-contract, not correct-by-construction.
The programmer specifies variance. The SRE trusts it. A wrong annotation
produces unsound subtyping. This is the same gap as Track 0's monotonicity
trust. The NTT type system (future) would verify variance from polarity
analysis. For now, the test suite is the safety net.

**Mitigation**: The variance annotations for built-in types (Pi, Sigma,
List, etc.) are well-established (textbook results). The risk is for
user-defined types — but user-defined structural subtyping is not in
Track 1 scope.

### 4.4 Completeness

**Challenge**: We're adding subtyping and duality but not coercion or
isomorphism. Is Track 1 complete?

**Response**: Track 1 delivers the two compile-time structural relations
(subtyping, duality). Coercion is a runtime concern (Track 2). Isomorphism
has no current use case. Delivering subtyping + duality is complete for the
current architecture's needs. The relation infrastructure is extensible —
adding coercion or isomorphism in a future track requires only a new
`sre-relation` instance and appropriate ctor-desc annotations.

### 4.5 Decomplection

**Challenge**: Adding `component-variances` AND `component-sub-relations`
to ctor-desc — are these two separate concerns being braided?

**Response**: They serve different relations: variances for subtyping,
sub-relations for duality. They're orthogonal — a constructor can have
variances without sub-relations, or sub-relations without variances. Keeping
them as separate fields is the decomplected design. The alternative
(a single `component-relation-behavior` that handles both) would braid them.

## 5. Open Questions

1. **Structural subtyping for user-defined types**: Not in Track 1 scope.
   When users define `data Wrapper A := wrap A`, should `Wrapper Nat <:
   Wrapper Int`? This requires inferring variance from the definition
   (covariant because A appears only in positive position). Defer to
   Track 2 or NTT integration.

2. **Subtype transitivity**: `Nat <: Int <: Rat` implies `Nat <: Rat`.
   The flat path handles this. The structural path handles it via
   propagation: if `List Nat <: List Int` and `List Int <: List Rat`,
   does `List Nat <: List Rat` follow? Yes — by separate subtype queries.
   But should the SRE compose them? Probably not in Track 1.

3. **Duality for dependent sessions**: `DSend(x:A, S(x))` — the payload
   is a binder. Under duality, `DSend(x:A, S(x)) ~ DRecv(x:A, dual(S(x)))`.
   The binder handling interacts with duality. Track 1 handles simple
   (non-dependent) sessions. Dependent session duality is Track 1 stretch
   goal or Track 2.

4. **Performance of subtype queries**: Creating temporary cells for each
   `subtype?` call on compound types has overhead. The flat fast path
   avoids this for base types. For compound types, the first call creates
   cells; subsequent calls for the same pair should be cached. The
   decomp registry already handles this caching for equality — verify it
   works for subtyping.

## 6. Source Documents

| Document | Relationship |
|----------|-------------|
| [SRE Track 0 Design](2026-03-22_SRE_TRACK0_FORM_REGISTRY_DESIGN.md) | Foundation: domain-parameterized decomposition |
| [SRE Research](../research/2026-03-22_STRUCTURAL_REASONING_ENGINE.md) | §3: Structural Relation Engine concept |
| [NTT Syntax Design](2026-03-22_NTT_SYNTAX_DESIGN.md) | `:variance`, `:under-duality`, `:dual-pairs` syntax |
| [NTT Case Study: Type Checker](../research/2026-03-22_NTT_CASE_STUDY_TYPE_CHECKER.md) | Subtyping impedance mismatch |
| [NTT Case Study: Sessions](../research/2026-03-22_NTT_CASE_STUDY_TYPE_CHECKER.md) | Duality as involution |
| [SRE Master](2026-03-22_SRE_MASTER.md) | Series tracking |
| [Master Roadmap](MASTER_ROADMAP.org) | Cross-series dependencies |
