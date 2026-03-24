# SRE Track 1: Relation-Parameterized Structural Decomposition

**Stage**: 2/3 Combined (Audit + Design)
**Date**: 2026-03-23
**Series**: SRE (Structural Reasoning Engine)
**Depends on**: [SRE Track 0](2026-03-22_SRE_TRACK0_FORM_REGISTRY_DESIGN.md) ✅
**Enables**: SRE Track 2 (Elaborator-on-SRE), [CIU Series](2026-03-21_CIU_MASTER.md) Track 3
**SRE Master**: [SRE Series Roadmap](2026-03-22_SRE_MASTER.md)
**Master Roadmap**: [MASTER_ROADMAP](MASTER_ROADMAP.md)

## 0. Vision and Goal

**What we're solving**: The SRE (Track 0) currently handles one structural
relation: equality. But our codebase uses at least three structural
relations — equality, subtyping, and duality — each implemented as separate,
incompatible mechanisms (`unify` via SRE, `subtype?` as flat predicate,
`dual` as recursive function). This means:

- **Subtyping is not structural**: `List Nat` is not recognized as a subtype
  of `List Int`, even though List is covariant. The flat `subtype?` predicate
  only handles base types.
- **Duality is not on the network**: The `dual` function is synchronous and
  recursive — it doesn't participate in propagation. Session type inference
  can't benefit from incremental duality resolution.
- **User-defined types don't participate**: A user who defines `data Box A := box A`
  gets no structural subtyping. Subtyping is not first-class.

**What Track 1 delivers**: A single SRE that handles equality, subtyping,
AND duality via a relation parameter. Structural decomposition is
relation-aware: variance-driven for subtyping, constructor-pairing for
duality. User-defined types get automatic variance via polarity inference.
The three separate mechanisms unify into one.

**Why this matters for the infrastructure program**: SRE Track 2
(elaborator-on-SRE) needs the elaborator to express subtyping and duality
constraints via `structural-relate`. If Track 1 only handles equality, Track 2
must maintain separate paths for subtyping and duality — which is the
fragmented architecture we're trying to eliminate.

## Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| 1 | Relation type + variance + polarity inference infra | ⬜ | |
| 2 | Subtype-aware structural-relate + user-defined variance | ⬜ | |
| 3 | Duality-aware structural-relate + dependent sessions | ⬜ | |
| 4 | Integration: subtype? delegation | ⬜ | |
| 5 | Integration: session duality propagator | ⬜ | |
| 6 | Verification + benchmarks + PIR | ⬜ | |

**Baseline**: SRE Track 0 final (7358 tests, 236.7s, commit `86524d8`)

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
;; → equality: write unified to both, decompose symmetrically (PROPAGATION)
;; → subtype:  check a <: b, decompose with variance (CHECKING)
;; → duality:  check a ~ dual(b), decompose swapping pairs (PROPAGATION)
```

The `#:relation` parameter is an optional keyword argument defaulting to
`'equality`. This is backward-compatible: all existing call sites get
equality behavior without changes.

**Critical semantic distinction (D.4 clarification)**: Equality and duality
are *information propagators* — they write new values into cells, moving
them up the lattice. Subtyping is a *structural checker via propagation
infrastructure* — it fires when cells are sufficiently ground, verifies the
relationship holds, and signals contradiction on failure. It does NOT write
new information into either cell (only contradiction signals).

This asymmetry is a deliberate design decision:
- **Track 1**: Subtype-relate checks. Sufficient for our current `subtype?`
  use cases (2 call sites, both on ground types).
- **Track 2**: If the elaborator-on-SRE needs subtyping to guide inference
  (`?X <: Int` constrains `?X`), subtype-relate would need bounds propagation
  (cells carry intervals, not single values). This is a significant
  architectural change deferred to Track 2's design.

The practical implication: the structural decomposition in subtype-relate
creates sub-cells and sub-constraints, but these sub-constraints are ALSO
checkers. The whole thing is a structured recursive check expressed as a
propagator network. The network gives us: decomp caching, termination via
fuel, composable sub-checks — without requiring information-flow semantics.

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
   ;; Sub-relation: derived from component lattice type (§2.5)
   ;; Same domain as parent → duality. Different domain → equality.
   ;; The sub-relation-fn receives the component's lattice-spec and
   ;; the parent domain name to determine this.
   (λ (rel component-lattice parent-domain-name)
     (if (eq? component-lattice parent-domain-name)
         sre-duality    ;; same domain: recurse duality
         sre-equality)) ;; cross-domain: equality
   ))
```

### 2.5 Duality Sub-Relations: Derived, Not Declared

Variance handles subtyping. Duality needs per-component sub-relation
determination (payload=equality, continuation=duality).

**Original design (D.1)**: A `component-sub-relations` field on ctor-desc.

**Revised design (D.3 self-critique)**: Derive sub-relations from existing
data. The ctor-desc already has `component-lattices` which names the lattice
for each component. The duality relation's `sub-relation-fn` checks: if a
component's lattice matches the parent domain → duality. If it's a different
domain → equality.

For `Send(payload: TypeExpr, cont: SessionExpr)`:
- `payload` lattice = `type-lattice` ≠ session domain → equality
- `cont` lattice = `session-lattice` = session domain → duality

This derivation is correct because duality only applies within a domain —
cross-domain components are structurally equal (both endpoints send/receive
the same type).

**ctor-desc expansion**: One new field only:

```racket
(struct ctor-desc
  (tag arity recognizer-fn extract-fn reconstruct-fn
   component-lattices binder-depth domain
   component-variances)   ;; NEW: '(+ - = ø) or #f
  #:transparent)
```

9 fields total. The D.2 critique threshold of 10 is not reached.

**Documented assumption (D.4)**: The derivation rule assumes that
same-domain components are continuations (should get duality). If a future
constructor has same-domain non-continuation components (e.g., session
polymorphism: sending a session type as a value), the derivation would give
the wrong sub-relation. In that case, an optional `component-sub-relations`
override field can be added backward-compatibly (`#f` default, explicit list
when needed). No current constructor triggers this — all session constructors
have cross-domain payloads and same-domain continuations.

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
;; NOTE: No :under-duality annotations needed — the duality relation
;; DERIVES sub-relations from component lattice types:
;;   - payload : TypeExpr (cross-domain) → equality
;;   - cont : SessionExpr (same domain) → duality
data SessionExpr
  := sess-bot | sess-top
   | sess-send [payload : TypeExpr] [cont : SessionExpr]
   | sess-recv [payload : TypeExpr] [cont : SessionExpr]
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
;;                    structural-relate with duality (Track 1, using :dual-pairs
;;                    + component lattice types for sub-relation derivation)

;; Usage in type checking (what Track 2 would generate):
;; structural-relate cell-a cell-b :relation subtype
;; → SRE decomposes with variance, creating sub-cell subtype constraints

;; Correspondence table:
;; NTT                          | Racket (Track 1)
;; -----------------------------|----------------------------------
;; :variance + on field         | component-variances '(... + ...)
;; :variance - on field         | component-variances '(... - ...)
;; :dual-pairs [[Send Recv]]    | sre-domain dual-pairs
;; :relation subtype            | #:relation sre-subtype
;; (sub-relation derived from   | duality sub-relation-fn checks
;;  component lattice type)     |  component-lattices on ctor-desc
```

## 3. Phase Design

### Phase 1: Relation Type + Variance + Polarity Inference Infrastructure

**Deliverables**:
1. `sre-relation` struct in `sre-core.rkt`
2. Three built-in relations: `sre-equality`, `sre-subtype`, `sre-duality`
3. `component-variances` field on `ctor-desc` (default `#f`)
4. `dual-pairs` field on `sre-domain` (default `#f`)
5. `binder-open-fn` field on `ctor-desc` (default `#f`) — scaffolded in
   Track 0, now needed for Phase 3 dependent duality
6. Polarity inference function: `infer-variance : type-def → (listof variance)`
   - Walks constructor fields, tracks type parameter positions
   - Positive position → covariant (+), negative → contravariant (-),
     both → invariant (=), absent → phantom (ø)
   - Applied during `data` elaboration to automatically fill
     `component-variances` on user-defined ctor-desc entries
7. Built-in type variance annotations (hardcoded, textbook):
   - Pi: `'(- +)`, Sigma: `'(+ +)`, App: `'(= +)`, List/PVec/Set: `'(+)`,
     Map: `'(= +)`
8. Update all existing ctor-desc registrations with `#f #f` for new fields
9. Update all existing sre-domain instantiations with `#f` for dual-pairs

**Design note: No `component-sub-relations` field** (D.3 self-critique).
The original design had a per-component sub-relation annotation for duality
(payload=equality, continuation=duality). This is redundant: the duality
relation can DERIVE sub-relations from component lattice types — a component
whose lattice is the same domain as the parent gets duality, a component on
a different domain gets equality. The `component-lattices` field already
carries this information. This keeps ctor-desc at 9 fields (with variance)
instead of 10.

**Polarity inference dependency ordering**: Types must be analyzed in
dependency order — `List`'s variance must be known before `data Nested A
:= nested (List A)` can determine that `A` is covariant. Our module loading
system already elaborates `data` definitions in dependency order. Variance
annotations are written to ctor-desc at registration time, so downstream
types can query them. Verify this ordering holds in the implementation.

**Polarity inference edge cases**:
- **Recursive types**: `data List A := nil | cons A (List A)` — polarity
  inference is a fixpoint computation on the 4-element lattice `{ø, +, -, =}`.
  Start with ø, propagate polarity through fields (including recursive
  occurrences), reach fixpoint. Converges in 2-3 iterations for any type.
  Example: `data Strange A := mk (Strange A -> A)` → A is invariant (=)
  because it appears in both positive (codomain) and negative (domain via
  recursive negative position) positions.
- **Mutual recursion**: `data Even A := ... (Odd A) ...` and vice versa.
  Iterate fixpoint over all types in the mutual group simultaneously. Our
  module system already groups mutual recursion for elaboration.
- **GADTs**: Out of scope. We don't support GADTs. If added, variance
  inference becomes significantly more complex (equational constraints,
  not just position). Document as future concern.

**Test**: Existing tests pass unchanged (new fields default to Track 0 behavior).
New test: polarity inference for `data Pair A B := pair A B` → `'(+ +)`.
New test: polarity inference for `data Fn A B := fn (A -> B)` → `'(- +)`.
New test: polarity inference for nested `data Nested A := nested (List A)` → `'(+)`.
New test: recursive `data List A := nil | cons A (List A)` → `'(+)` (fixpoint).
New test: invariant `data Strange A := mk (Strange A -> A)` → `'(=)` (fixpoint).

**Risk**: Low-medium. Polarity inference is well-understood but touches the
elaboration pipeline for `data` definitions. Need to verify it doesn't affect
elaboration of existing types.

### Phase 2: Subtype-Aware structural-relate + User-Defined Variance

**Deliverables**:
1. `sre-propagate-subtype` function in `sre-core.rkt`
   - Directional: checks `a ≤ b` (join(a,b) = b means a ≤ b)
   - No symmetric merge — subtyping is directional
   - Decomposes compound types using variance from ctor-desc
2. `sre-make-structural-relate-propagator` accepts `#:relation` parameter
3. `sre-decompose-generic` propagates relation to sub-cell propagators,
   using `(sre-relation-sub-relation-fn rel variance)` to determine the
   sub-cell relation for each component
4. `sre-subtype-reverse` — subtype with flipped direction (for contravariant)
5. `sre-phantom` — no constraint (for phantom variance)
6. Built-in variance annotations on type-domain constructors (from Phase 1)
7. User-defined types get automatic variance via polarity inference (Phase 1)
   - Verify: `data Wrapper A := wrap A` → variance `'(+)` → structural
     subtyping works: `Wrapper Nat <: Wrapper Int`
8. **Decomp cache relation-awareness**: The decomp registry key must
   include the relation type, not just the cell pair. A cell pair
   decomposed for equality (`cell-a = cell-b`) is a different
   decomposition than for subtyping (`cell-a <: cell-b`) — equality
   creates symmetric propagators, subtyping creates directional ones.
   The `decomp-key` function (in `sre-maybe-decompose`) must be extended:
   `(decomp-key cell-a cell-b relation-name)`. Verify that existing
   equality decompositions are not confused with subtyping decompositions.

**Test**: New test file `test-sre-subtype.rkt` with cases:
- `Nat <: Int` via flat subtype? (existing behavior preserved)
- `List Nat <: List Int` via SRE structural subtyping (NEW)
- `(Int -> Nat) <: (Nat -> Int)` via Pi variance (NEW)
- `Map String Nat <: Map String Int` via Map variance (NEW)
- NOT: `List Int <: List Nat` (covariance prevents reversal)
- NOT: `(Nat -> Int) <: (Int -> Nat)` (contravariant domain prevents)
- User-defined: `data Box A := box A` then `Box Nat <: Box Int` (NEW)
- Invariant: mutable container equality-only (if applicable)
- Cache: decompose same pair for equality then subtype — both work independently

**Risk**: Medium. Subtype propagation semantics are new — need to verify
the directional propagation doesn't break the termination argument. Cache
key extension touches a hot path.

**Termination argument for subtype relation**: The subtype propagator does
NOT merge cells bidirectionally (equality does). It checks `a ≤ b` via
the lattice ordering. For compound types, it decomposes with variance and
installs sub-cell subtype constraints. Each sub-constraint is strictly
smaller than the parent (sub-cells have lower lattice height). Since no
bidirectional merging occurs, the only cell writes are contradiction signals
(monotone: once contradicted, always contradicted). Fuel guards provide the
hard bound. Decomp registry prevents duplicate sub-cell creation.

Transitivity falls out of propagation naturally: if `cell-a <: cell-b` and
`cell-b <: cell-c` are both installed, information flows through cell-b.
No additional mechanism needed.

**Equality + subtype interaction test**: If a cell pair has both an
equality-relate and a subtype-relate decomposition, verify soundness:
equality makes cells equal → subtyping trivially holds. Add explicit
test: create cell pair, install both relations, quiesce, verify no
contradiction.

**Meta-interaction boundary** (known limitation): Subtype-relate decomposes
compound types structurally, but leaf-level subtype checks only fire when
BOTH sub-cells are ground. If one sub-cell is a meta (unsolved), the
propagator waits. The meta gets solved by equality constraints from
elaboration, THEN the subtype check fires. This means subtyping cannot
GUIDE meta solving — `?X <: Int` has multiple solutions (Nat, Int, etc.)
and the SRE doesn't pick one. This is correct for our current architecture
(where `subtype?` is only called on ground types). It becomes a limitation
in Track 2 (elaborator-on-SRE), where subtyping constraints would
participate in inference. Document as known boundary for Track 2 design.

### Phase 3: Duality-Aware structural-relate + Dependent Sessions

**Deliverables**:
1. `sre-propagate-duality` function in `sre-core.rkt`
   - Reads cell-a, applies dual constructor pairing, writes to cell-b
   - Bidirectional: cell-b changes → apply inverse dual → write cell-a
   - Decomposes using component-sub-relations from ctor-desc
2. `dual-pairs` on session-sre-domain
3. `component-sub-relations` on session constructor descriptors:
   - Send/Recv: `'(equality duality)` (payload=equal, continuation=dual)
   - DSend/DRecv: `'(equality duality)` with binder-depth=1
   - AsyncSend/AsyncRecv: `'(equality duality)`
   - Choice/Offer: dual with branch sub-relations
   - mu: `'(duality)` (body is dual)
   - svar/end: self-dual (no decomposition)
4. Session constructor descriptors registered in ctor-registry
5. `binder-open-fn` implemented for DSend/DRecv descriptors:
   - Opens the binder: creates fresh variable, substitutes into continuation
   - Under duality: `DSend(x:A, S(x)) ~ DRecv(x:A, dual(S(x)))`
   - The fresh variable is shared (same on both sides — duality applies
     to the continuation's structure, not to the binding variable)
   - Uses `sre-decompose-binder` (new function) that handles binder
     opening before creating sub-cells, then installs the appropriate
     sub-relation on the opened continuation
6. `sre-decompose-binder` in `sre-core.rkt`:
   - Generic binder decomposition for any relation
   - Opens binder via descriptor's `binder-open-fn`
   - Creates sub-cells for opened components
   - Installs sub-relation propagators (equality for binder variable,
     parent relation for opened body)
   - This also enables Pi/Sigma binder decomposition on the SRE
     (currently handled by PUnify dispatch layer — can migrate in Track 2)

**Test**: New test file `test-sre-duality.rkt` with cases:
- `Send Int S ~ Recv Int (dual S)` — basic duality
- `dual(dual(S)) = S` — involution property
- Nested: `Send Int (Recv Bool End) ~ Recv Int (Send Bool End)`
- Dependent: `DSend(x:Int, S(x)) ~ DRecv(x:Int, dual(S(x)))` (NEW)
- Choice/Offer branch correspondence
- **Binder generality**: test `sre-decompose-binder` with EQUALITY relation
  on Pi (binder-depth=1). Validates that the function works for both duality
  and equality, proving generality before Track 2 needs it for PUnify migration.

**Risk**: Medium-high. Dependent duality combines binder handling with
constructor pairing. The `sre-decompose-binder` function is new infrastructure
that also serves Phase 2 migration of Pi/Sigma (future Track 2 use). Need
to verify that binder opening under duality correctly shares the binding
variable across both sides.

**Termination argument for duality**: Similar to equality. The dual
propagator writes `dual(v)` to the opposite cell. If the cells already
satisfy duality (`dual(va) = vb`), no write occurs (net-cell-write's
identity check). If they don't, the write triggers convergence. Monotonicity
is preserved because `dual` is an involution on the session lattice (it
preserves the lattice ordering). For dependent sessions, the binder
opening is a one-time operation (decomp registry prevents re-opening).
Fuel guards provide the hard bound.

### Phase 4: Integration — subtype? Delegation

**Deliverables**:
1. `subtype?` in `typing-core.rkt` delegates structural cases to SRE
2. Flat cases (Nat<:Int, Posit8<:Posit16) remain as fast path
3. Compound cases dispatch to `sre-structural-subtype-check`

**Query pattern** (concrete sketch):

```racket
(define (sre-structural-subtype-check domain t1 t2)
  ;; Create a mini-network for the query
  (define net0 (make-prop-network))
  ;; Create cells initialized to the two types
  (define-values (net1 cell-a)
    (net-new-cell net0 t1
      (sre-domain-lattice-merge domain)
      (sre-domain-contradicts? domain)))
  (define-values (net2 cell-b)
    (net-new-cell net1 t2
      (sre-domain-lattice-merge domain)
      (sre-domain-contradicts? domain)))
  ;; Install a subtype-relate propagator
  (define-values (net3 _pid)
    (net-add-propagator net2 (list cell-a cell-b) (list cell-a cell-b)
      (sre-make-structural-relate-propagator domain cell-a cell-b
        #:relation sre-subtype)))
  ;; Run to quiescence
  (define net4 (run-to-quiescence net3))
  ;; Check: no contradiction = subtype holds
  (not (or (net-contradiction? net4)
           ((sre-domain-contradicts? domain) (net-cell-read net4 cell-a))
           ((sre-domain-contradicts? domain) (net-cell-read net4 cell-b)))))
```

The mini-network is GC'd after the check — no persistent state. This
pattern generalizes to any SRE query: create cells, install relation
propagator, quiesce, read result. Occurs-check, well-formedness, etc.
can all follow this pattern.

**Performance**: The mini-network is only created for compound types
(the flat fast path handles base types without cells). For compound
types, cell creation + one quiescence run. The decomp registry within
the mini-network caches sub-decompositions, so nested types (e.g.,
`List (List Nat) <: List (List Int)`) don't re-decompose.

**Frequency counter**: Add a `current-subtype-check-count` parameter
incremented on each `subtype?` call. Measure across the full test suite
to establish: (a) how often `subtype?` is called, (b) what fraction
are compound (trigger mini-network), (c) what the actual wall-time
overhead is. If compound checks are >1000 per suite run, evaluate
persistent subtype network as a Track 2 optimization.

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

**Challenge**: Variance annotations are per-constructor. For built-in types
they're manually specified (textbook). For user-defined types, polarity
inference derives them. What prevents a wrong variance annotation?

**Response**: Two tiers of correctness:
- **User-defined types**: Correct-by-construction. Polarity inference derives
  variance from the type definition. If `A` appears only in positive position,
  it's covariant. The user doesn't specify variance — the compiler infers it.
- **Built-in types**: Correct-by-contract. Pi's `'(- +)` is textbook, but
  the compiler trusts the hardcoded annotation. A wrong annotation produces
  unsound subtyping. Mitigated by: (a) these are well-established results,
  (b) the test suite validates, (c) NTT enforcement (future) would verify.

This is strictly better than Track 0's monotonicity trust: user-defined types
get correct-by-construction variance; only built-in types remain by-contract.

### 4.4 Completeness

**Challenge**: We're adding subtyping and duality but not coercion or
isomorphism. Is Track 1 complete?

**Response**: Track 1 delivers the two compile-time structural relations
(subtyping, duality) with first-class support for ALL types (user-defined
included, via polarity inference). Coercion is a runtime/reduction concern
that requires the elaborator-on-SRE architecture (Track 2). Isomorphism
has no current use case. The relation infrastructure is extensible —
adding coercion or isomorphism in a future track requires only a new
`sre-relation` instance and appropriate ctor-desc annotations.

The Completeness revision (D.2) incorporated user-defined structural
subtyping and dependent session duality — both were originally deferred
but identified as Completeness violations. Track 1 now makes subtyping
and duality genuinely first-class.

### 4.5 Decomplection

**Challenge**: The original design added both `component-variances` AND
`component-sub-relations` to ctor-desc. The D.3 self-critique identified
that `component-sub-relations` is redundant — duality can derive
sub-relations from component lattice types (same-domain → duality,
cross-domain → equality). Removing it keeps concerns separated.

**Response**: Only `component-variances` is added. Each relation's
`sub-relation-fn` derives sub-cell relations from existing data:
- Equality: always equality (no variance needed)
- Subtyping: uses `component-variances` from ctor-desc
- Duality: uses `component-lattices` from ctor-desc (same domain → duality,
  different domain → equality)

One field serves one concern. No braiding.

## 5. Open Questions (Revised after Completeness review)

The original draft deferred user-defined structural subtyping, transitivity
composition, and dependent session duality. Review against the Completeness
principle revealed these were not genuine "open questions" — they were
Completeness violations. Building the relation infrastructure without making
relations first-class for all types is building an incomplete foundation.

**Resolved (incorporated into phases)**:
1. ~~User-defined structural subtyping~~ → Phase 1 (polarity inference) +
   Phase 2 (user-defined types get automatic variance)
2. ~~Subtype transitivity~~ → Falls out of propagation. Not a question.
3. ~~Dependent session duality~~ → Phase 3 (`sre-decompose-binder` +
   `binder-open-fn` on DSend/DRecv descriptors)
4. ~~Subtype query caching~~ → Phase 2 deliverable #8 (decomp cache key
   includes relation type)

**Remaining open questions**:

1. **Polarity inference for higher-kinded types**: `data App F A := app (F A)`
   — the variance of `A` depends on the variance of `F`. If `F = List`
   (covariant), then `A` is covariant. If `F = Fn _ ` (contravariant in
   first arg), `A` is contravariant. Full HKT variance requires
   variance-polymorphism. For Track 1, treat HKT parameters as invariant
   (safe default). Refinement in SRE Track 2 or NTT integration.

2. **Branch duality for Choice/Offer**: Choice and Offer have branch lists,
   not positional components. Duality requires matching branches by label
   and dualizing each. This is structural decomposition over a map-like
   structure, not a fixed-arity constructor. May need a `branch-decompose-fn`
   on the descriptor, or a special case in `sre-propagate-duality`.

3. **Relation composition**: Can we compose subtyping and duality?
   E.g., `Send Nat S <:~ Recv Int (dual S)` (subtyping on payload, duality
   on continuation). This would require a "composed relation" construct.
   Not needed for current use cases — subtyping and duality operate on
   different domains. Monitor for future need.

## 6. Expectations (PIR checkpoints)

### 6.1 Performance

- **No regression on equality path**: The `#:relation` parameter defaults to
  equality. Existing structural unification must not get slower. Benchmark
  target: ≤ 2% wall-time increase on bench-ab comparative suite.
- **Flat subtype fast path preserved**: `Nat <: Int` should be O(1) table
  lookup, no cell creation. The structural path only activates for compound
  types.
- **Structural subtype query overhead**: Creating a mini-network for compound
  subtype checks has overhead vs the flat predicate. Target: < 100μs per
  compound subtype check. Measure via micro-benchmark.
- **Suite time**: Baseline 236.7s. Target: ≤ 245s (< 4% increase, accounting
  for new tests).

### 6.2 Correctness

- **Soundness**: No false positives — if `sre-structural-subtype-check`
  returns true, the subtype relationship genuinely holds. Test with known
  counterexamples: `List Int` is NOT a subtype of `List Nat`.
- **Variance accuracy**: Polarity inference for all existing `data` definitions
  produces the expected variance annotations. Cross-check against textbook
  results for Pi, Sigma, List.
- **Duality involution**: `dual(dual(S)) = S` for all session types. Test
  with nested, dependent, and recursive sessions.
- **No behavioral change on existing tests**: 7358 tests must pass unchanged.

### 6.3 Architecture

- **SRE core changes are domain-neutral**: `sre-core.rkt` must not contain
  any type-domain-specific or session-domain-specific code. All domain
  specificity lives in domain specs and ctor-descs.
- **ctor-desc field count**: ≤ 9 (with variance, without sub-relations).
  If we exceed 9, document why in the PIR.
- **Zero new Racket parameters**: Relations are data (structs), not ambient
  state (parameters).

## 7. Completion Criteria

Track 1 is DONE when:

1. **All 6 phases complete** with progress tracker updated
2. **All tests pass** (existing + new subtype/duality tests)
3. **Structural subtyping works for user-defined types**: `data Box A := box A`
   → `Box Nat <: Box Int` without any user annotation
4. **Dependent session duality works**: `DSend(x:Int, S(x)) ~ DRecv(x:Int, dual(S(x)))`
5. **Performance expectations met** (§6.1)
6. **bench-ab comparative suite shows no regression**
7. **PIR written** following POST_IMPLEMENTATION_REVIEW.org methodology,
   covering:
   - Was the query pattern the right choice for subtype integration?
   - Did polarity inference handle all existing `data` definitions correctly?
   - What was the actual overhead of structural subtype checks?
   - Were there surprises in duality propagation termination?
   - Does the meta-interaction boundary (§Phase 2) need Track 2 attention?
   - Architecture assessment: is ctor-desc growing too heavy?
   - What's next: does Track 2 (elaborator-on-SRE) need design changes
     based on Track 1 learnings?

## 8. Source Documents

| Document | Relationship |
|----------|-------------|
| [SRE Track 0 Design](2026-03-22_SRE_TRACK0_FORM_REGISTRY_DESIGN.md) | Foundation: domain-parameterized decomposition |
| [SRE Research](../research/2026-03-22_STRUCTURAL_REASONING_ENGINE.md) | §3: Structural Relation Engine concept |
| [NTT Syntax Design](2026-03-22_NTT_SYNTAX_DESIGN.md) | `:variance`, `:under-duality`, `:dual-pairs` syntax |
| [NTT Case Study: Type Checker](../research/2026-03-22_NTT_CASE_STUDY_TYPE_CHECKER.md) | Subtyping impedance mismatch |
| [NTT Case Study: Sessions](../research/2026-03-22_NTT_CASE_STUDY_TYPE_CHECKER.md) | Duality as involution |
| [SRE Master](2026-03-22_SRE_MASTER.md) | Series tracking |
| [Master Roadmap](MASTER_ROADMAP.org) | Cross-series dependencies |
