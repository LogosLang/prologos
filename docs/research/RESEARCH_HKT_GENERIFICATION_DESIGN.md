# HKT-Based Whole-Library Generification: Research & Design

**Date**: 2026-02-20
**Status**: Research / Pre-implementation
**Revision**: 2 (incorporates critique feedback)
**Scope**: Higher-Kinded Type resolution infrastructure, type-preserving collection operations, clean surface syntax for generic functions

---

## 1. Executive Summary

Prologos's library generification (Phases 3a-3h) established trait instances for all collection types and prefixed operation modules, but revealed a fundamental gap: **there is no automatic HKT dispatch**. All higher-kinded trait instances (Seqable, Foldable, Buildable for List/PVec/Set/LSeq) are defined as manual `def` forms using naming conventions and called explicitly. Generic functions like `coll-map` are hard-coded to `List`.

This document proposes a principled infrastructure for HKT-dispatched generic functions. The end-state user experience is:

```prologos
;; User writes -- no dicts, no kind annotations, no boilerplate:
defn transform [f xs]
  |> xs to-seq |> map f |> from-seq

;; Or equivalently:
defn transform [f xs]
  from-seq [map f [to-seq xs]]

;; Works on any collection:
transform inc @[1 2 3]       ;; PVec Int -> PVec Int
transform inc '[1 2 3]        ;; List Int -> List Int
transform inc ~[1 2 3]        ;; LSeq Int -> LSeq Int
```

The compiler infers the kind of `C` from the trait constraint, resolves the Seqable/Buildable instances for the concrete type, and inserts the dictionaries automatically.

**Key insight**: The solution requires a single new AST node (`expr-tycon`) and a normalization layer in the unifier, plus targeted enhancements to the elaborator for kind inference and constraint inference.

---

## 2. Current State: Complete Library Audit

### 2.1 Numeric Tower (COMPLETE -- No HKT Needed)

The numeric tower is fully generified via ground-type trait dispatch:

| Bundle | Constraints | Applicable Types |
|--------|------------|------------------|
| `Num` | Add, Sub, Mul, Neg, Eq, Ord, Abs, FromInt | Int, Rat, Posit8/16/32/64 |
| `Fractional` | Num + Div, FromRat | Rat, Posit8/16/32/64 |

Nat is correctly excluded from Num (lacks Neg, Abs, FromInt) and reserved for the type system. **No further generification needed for numerics.**

### 2.2 Collection Types (5 types, mixed generification)

| Type | Kind | Backend | Trait Status |
|------|------|---------|--------|
| List A | `Type -> Type` | Inductive (fvar+cons) | 50+ functions; manual trait instances |
| PVec A | `Type -> Type` | RRB-tree (`expr-rrb`) | Manual trait instances + prefixed ops |
| Set A | `Type -> Type` | CHAMP-trie (`expr-hset`) | Manual trait instances + prefixed ops |
| LSeq A | `Type -> Type` | Lazy cell (inductive) | Manual trait instances; hub for conversions |
| Map K V | `Type -> Type -> Type` | CHAMP-trie (`expr-champ`) | Keyed trait + prefixed ops |

### 2.3 Collection Traits: Audit Results

| Trait | Kind Param | Methods | Instances | Declared As |
|-------|-----------|---------|-----------|-------------|
| Seqable | `{C : Type -> Type}` | `to-seq` | List, PVec, Set, LSeq | **`trait`** |
| Buildable | `{C : Type -> Type}` | `from-seq`, `empty-coll` | List, PVec, Set, LSeq | **`trait`** |
| Foldable | `{F : Type -> Type}` | `foldr` | List, PVec, Set, LSeq | **`deftype`** (needs conversion) |
| Functor | `{F : Type -> Type}` | `fmap` | List, PVec | **`deftype`** (needs conversion) |
| Seq | `{S : Type -> Type}` | `seq-first`, `seq-rest`, `seq-empty?` | List, LSeq | **`trait`** |
| Indexed | `{C : Type -> Type}` | `idx-nth`, `idx-length`, `idx-update` | List, PVec | **`trait`** |
| Keyed | `{C : Type -> Type -> Type}` | `kv-get`, `kv-assoc`, `kv-dissoc` | Map | **`trait`** |
| Setlike | `{C : Type -> Type}` | `set-member?`, `set-insert`, `set-remove` | Set | **`trait`** |

**Only Foldable and Functor** need conversion from `deftype` to `trait`. All others are already `trait`.

### 2.4 The HKT Gap: All Instances Are Manual

Every HKT instance is a manual `def` following a naming convention, not registered in the impl registry, not discoverable by `resolve-trait-constraints!`:

```prologos
;; Manual def -- not in impl registry:
def List--Seqable--dict : [Seqable List] := list-to-lseq

;; Hard-coded dict name at call site:
defn coll-map [f xs]
  List--Buildable--from-seq B [lseq-map A B f [List--Seqable--dict A xs]]
```

### 2.5 Current User Experience for Trait-Constrained Functions

**Critical finding**: Users currently pass trait dicts **explicitly** at call sites:

```prologos
;; User must pass nat-eq explicitly:
elem Nat nat-eq [suc [suc zero]] my-list

;; User must pass comparator explicitly:
sort Nat le? my-list
```

There is **no automatic constraint inference** from usage. The elaborator creates metas for implicit `:m0` params and tags trait-constraint positions, but the user-visible args (`:mw` params) include the dict. This is the status quo that HKT dispatch must improve upon.

---

## 3. Gap Analysis: Why HKT Dispatch Fails Today

### Gap 1: Dual AST Representation of Types

User-defined types and built-in types have incompatible AST representations:
```
User-defined:  List A  =  (expr-app (expr-fvar 'List) A)
Built-in:      PVec A  =  (expr-PVec A)          -- dedicated AST node
Built-in:      Set A   =  (expr-Set A)
Built-in:      Map K V =  (expr-Map K V)
```

The unifier cannot decompose `(expr-app ?F ?A)` vs `(expr-PVec A)` because they are structurally different.

### Gap 2: No Type Constructor as First-Class Value

No AST expression represents an unapplied type constructor. `(Seqable PVec)` expands via deftype into a Pi type, losing the identity of `PVec`.

### Gap 3: `impl` Macro Only Handles Ground Types

`process-impl` has no concept of kinds. `impl Seqable List` would need `List` recognized as a type constructor.

### Gap 4: Pattern Matching in Trait Resolution is Incomplete

`match-one` handles `expr-Nat`, `expr-Bool`, `expr-fvar`, `expr-app` chains. Missing: `expr-PVec`, `expr-Map`, `expr-Set`, `expr-Int`, `expr-Rat`, `expr-Posit*`, `expr-Keyword`.

### Gap 5: Two HKT Traits Are Raw `deftype`

`Foldable` and `Functor` are raw `deftype`, not `trait`. `impl` requires registered trait metadata.

### Gap 6: No Coherence Guarantees

`register-impl!` silently overwrites duplicate entries. `try-parametric-resolve` uses `for/or` (first match wins). No orphan restrictions, no overlap detection, no ambiguity errors.

---

## 4. Design: Two-Layer Architecture

The design separates **elaborated form** (explicit dictionaries, for the compiler) from **surface form** (implicit resolution, for users). This distinction was missing from the v1 document.

### 4.1 Surface Syntax (What Users Write)

```prologos
;; Clean trait definitions
trait Seqable {C : Type -> Type}
  to-seq : C A -> LSeq A

trait Buildable {C : Type -> Type}
  from-seq : LSeq A -> C A
  empty : C A

;; Clean instances
impl Seqable PVec
  defn to-seq [v] pvec-to-lseq v

impl Buildable PVec
  defn from-seq [s] lseq-to-pvec s
  defn empty @[]

;; Clean bundle
bundle Collection := (Seqable, Buildable, Foldable)

;; Clean generic function -- NO dict params visible
spec transform {A B : Type} {C : Type -> Type} [Seqable C] -> [Buildable C] -> [A -> B] -> [C A] -> [C B]
defn transform [f xs]
  from-seq [lseq-map f [to-seq xs]]

;; Or with pipe:
defn transform [f xs]
  |> xs to-seq |> lseq-map f |> from-seq

;; Clean call site -- NO dicts, NO annotations
transform inc @[1 2 3]        ;; PVec Int -> PVec Int
transform inc '[1 2 3]         ;; List Int -> List Int
```

### 4.2 Elaborated Form (What the Compiler Produces)

```prologos
;; After elaboration, the function has explicit dict params:
;; transform : Pi(A :0 Type) Pi(B :0 Type) Pi(C :0 (-> Type Type))
;;             Pi(seq :mw (Seqable C)) Pi(build :mw (Buildable C))
;;             (A -> B) -> C A -> C B
;;
;; Call site elaborates to:
;; (transform Int Int (tycon PVec) PVec--Seqable--dict PVec--Buildable--dict inc xs)
```

### 4.3 The Gap Between Surface and Elaborated

Today, users write the elaborated form. The HKT work bridges this gap:

| Feature | Today | After HKT |
|---------|-------|-----------|
| Trait dict params | Visible to user (`defn foo [eq-dict x y]`) | Invisible (implicit `:mw` with auto-resolution) |
| Method access | `Seqable-to-seq dict A xs` | `to-seq xs` (bare method name) |
| Kind annotations | N/A (no HKT) | Inferred from trait constraints |
| Constraint inference | Must declare in `spec` | Inferred from method usage (future) |
| Call-site dicts | Passed explicitly | Resolved automatically |

---

## 5. Core Design: The `expr-tycon` Approach

### 5.1 New AST Node

```racket
(struct expr-tycon (name) #:transparent)
;; name : symbol -- 'PVec, 'Map, 'Set, 'List, 'LSeq
```

### 5.2 Kind Table

```racket
(define builtin-tycon-table
  (hasheq 'PVec  (list 1 (lambda (a) (expr-PVec a)))
          'Set   (list 1 (lambda (a) (expr-Set a)))
          'Map   (list 2 (lambda (k v) (expr-Map k v)))
          'List  (list 1 #f)   ;; user-defined (fvar)
          'LSeq  (list 1 #f)   ;; user-defined (fvar)
          'Vec   (list 2 (lambda (a n) (expr-Vec a n)))
          'TVec  (list 1 (lambda (a) (expr-TVec a)))
          'TMap  (list 2 (lambda (k v) (expr-TMap k v)))
          'TSet  (list 1 (lambda (a) (expr-TSet a)))))
```

### 5.3 Normalization Layer

```racket
(define (normalize-to-app e)
  (match e
    [(expr-PVec a)   (expr-app (expr-tycon 'PVec) a)]
    [(expr-Set a)    (expr-app (expr-tycon 'Set) a)]
    [(expr-Map k v)  (expr-app (expr-app (expr-tycon 'Map) k) v)]
    [(expr-TVec a)   (expr-app (expr-tycon 'TVec) a)]
    [(expr-TSet a)   (expr-app (expr-tycon 'TSet) a)]
    [(expr-TMap k v) (expr-app (expr-app (expr-tycon 'TMap) k) v)]
    [_ e]))
```

Normalization is idempotent (calling it twice produces the same result) and only fires when there is a structural mismatch between `expr-app` and a built-in type node.

### 5.4 Typing Rule

```racket
[(expr-tycon name)
 ;; Build kind: Type -> Type -> ... -> Type (arity arrows)
 (define arity (car (hash-ref builtin-tycon-table name)))
 (for/fold ([ty (expr-Type (lzero))])
           ([_ (in-range arity)])
   (expr-Pi 'm0 (expr-Type (lzero)) (shift 1 ty)))]
```

`(expr-tycon 'PVec)` has type `Pi(:0 Type, Type)` = `Type -> Type`.

### 5.5 Unifier Enhancement

In `unify-whnf`, before the existing `app-vs-app` case:

```racket
;; Normalize built-in types for HKT matching
[(and (can-normalize-to-app? a) (or (expr-app? b) (expr-meta? b) (flex-app? b)))
 (unify-whnf ctx (normalize-to-app a) b)]
[(and (or (expr-app? a) (expr-meta? a) (flex-app? a)) (can-normalize-to-app? b))
 (unify-whnf ctx a (normalize-to-app b))]
[(and (expr-tycon? a) (expr-tycon? b))
 (eq? (expr-tycon-name a) (expr-tycon-name b))]
```

### 5.6 14-File Pipeline for `expr-tycon`

| File | Change |
|------|--------|
| `syntax.rkt` | Add `(struct expr-tycon (name) #:transparent)`, provide, kind table |
| `substitution.rkt` | `[(expr-tycon _) e]` -- identity |
| `zonk.rkt` | `[(expr-tycon _) e]` -- identity for all 3 variants |
| `typing-core.rkt` | `infer`: return kind from table |
| `qtt.rkt` | `inferQ`: `[(expr-tycon _) 'm0]` |
| `reduction.rkt` | `[(expr-tycon _) e]` -- normal form |
| `pretty-print.rkt` | `[(expr-tycon name) (symbol->string name)]` |
| `unify.rkt` | Normalization + tycon-vs-tycon |
| `surface-syntax.rkt` | No change |
| `parser.rkt` | No change |
| `elaborator.rkt` | Kind inference from constraints (see Section 6) |
| `foreign.rkt` | No change |
| `macros.rkt` | No change initially |
| `trait-resolution.rkt` | Extend key-str, match-one, ground-expr? |

---

## 6. Elaborator Enhancements for Clean Surface Syntax

### 6.1 Kind Inference from Trait Constraints

**Critique point**: `{C : Type -> Type}` should be inferred when `[Seqable C]` is declared.

**Current state**: `parse-brace-param-list` (macros.rkt line 2848) defaults bare params `{C}` to `Type`. The elaborator's `insert-implicits-with-tagging` creates metas with `(expr-hole)` as type hint.

**Proposed enhancement**: After parsing brace params in a `spec`, walk the where-constraints and propagate kinds:

```racket
;; In process-spec (macros.rkt):
;; 1. Parse brace params: {A B C} -> ((A . (Type 0)) (B . (Type 0)) (C . (Type 0)))
;; 2. Walk where-constraints: [Seqable C] -> look up Seqable's trait params
;; 3. Seqable has {C : Type -> Type} -> update C's kind to (-> (Type 0) (Type 0))
;; Result: ((A . (Type 0)) (B . (Type 0)) (C . (-> (Type 0) (Type 0))))
```

This is a **pre-parse time** enhancement -- no changes to the type checker needed.

**Implementation**: Add a `propagate-kinds-from-constraints` pass after `extract-implicit-binders` in the spec processing pipeline. For each where-constraint `(TraitName Var)`, look up the trait's registered metadata and extract the param kind.

**User experience after this change**:
```prologos
;; This works (explicit kind):
spec transform {C : Type -> Type} [Seqable C] -> ...

;; This ALSO works (kind inferred from Seqable):
spec transform {C} [Seqable C] -> ...
```

### 6.2 Bare Method Name Resolution

**Critique point**: Users should write `to-seq xs`, not `Seqable-to-seq dict A xs`.

**Current state**: Bare method names only resolve inside function bodies with dict params in scope (the `where-context` mechanism in elaborator.rkt lines 68-165).

**Proposed enhancement**: Extend the where-context mechanism so that when a function has implicit trait-constraint params (`:mw`), their methods are available as bare names in the function body.

**How it works today for explicit dict params**:
1. User writes `defn foo [$Eq-A x y] [eq? x y]`
2. Elaborator sees `$Eq-A` (dollar-prefix), parses as dict param
3. Populates where-context: `eq?` -> `[Eq-eq? A $Eq-A]`
4. When `eq?` is encountered in the body, resolves via where-context

**How it should work for implicit dict params**:
1. User writes `spec foo {A} [Eq A] -> A -> A -> Bool` / `defn foo [x y] [eq? x y]`
2. The spec declares `[Eq A]` as a where-constraint
3. The elaborator knows the function has an implicit dict param for `Eq A`
4. Populates where-context: `eq?` -> `[Eq-eq? ?A ?dict-meta]`
5. When `eq?` is encountered in the body, resolves via where-context

**Implementation**: In `insert-implicits-with-tagging`, after creating trait-constraint metas, populate the where-context with method entries for each resolved trait. This requires:
1. Looking up the trait's registered methods from `trait-meta`
2. Creating where-method-entry structs mapping method names to accessor applications
3. Pushing these into the `current-where-context` during body elaboration

**User experience after this change**:
```prologos
;; BEFORE (today):
spec transform {A B : Type} {C : Type -> Type} [Seqable C] -> [Buildable C] -> [A -> B] -> [C A] -> [C B]
defn transform [seq-dict build-dict f xs]
  Buildable-from-seq build-dict B [lseq-map A B f [Seqable-to-seq seq-dict A xs]]

;; AFTER:
spec transform {A B : Type} {C : Type -> Type} [Seqable C] -> [Buildable C] -> [A -> B] -> [C A] -> [C B]
defn transform [f xs]
  from-seq [lseq-map f [to-seq xs]]
```

The dict params are still there in the elaborated form, but invisible to the user.

### 6.3 Constraint Inference from Usage (Future Work)

**Critique point**: When a user calls `to-seq xs`, the compiler should infer `[Seqable C]`.

**Current state**: No constraint inference exists. All constraints must be declared in `spec`.

**Proposed design** (for future implementation):

```prologos
;; User writes (no spec, no constraints):
defn transform [f xs]
  from-seq [lseq-map f [to-seq xs]]

;; Compiler infers:
;; 1. to-seq requires (Seqable C) where xs : C A
;; 2. from-seq requires (Buildable C)
;; 3. lseq-map requires A, B from f : A -> B
;; Result: transform : {A B} {C : Type -> Type} [Seqable C] [Buildable C] (A -> B) -> C A -> C B
```

**Implementation sketch**:
1. During elaboration, when a bare method name is encountered that is NOT in the where-context:
   - Search registered traits for a method with that name
   - If found, create a fresh meta for the trait dict
   - Add a new trait constraint to the constraint map
   - Propagate kind constraints to any related type metas
2. After type checking, `resolve-trait-constraints!` resolves these auto-inferred constraints

**Decision**: **Defer to a future phase.** This is a significant elaborator enhancement that requires careful design around ambiguity (what if two traits have a method named `map`?). The explicit `spec` declaration is sufficient for the initial HKT release.

---

## 7. Naming and Disambiguation

### 7.1 Trait Method Naming

**Critique point**: `Buildable-from-seq` is verbose; use bare `from-seq`.

**Decision**: Bare method names are the user-facing form (via enhanced where-context). The `TraitName-method` accessor remains available for explicit access. This parallels Haskell where `fmap` is used directly, not `Functor.fmap`.

| Form | When to use |
|------|------------|
| `to-seq xs` | In function bodies with `[Seqable C]` constraint |
| `Seqable-to-seq dict A xs` | In fully explicit/elaborated code |
| `List--Seqable--dict` | Implementation detail (internal naming) |

### 7.2 Bundle Naming: `Collection` vs `Seq`

**Critique point**: Naming conflict between the `Seq` bundle and the `Seq` trait.

**Decision**: Rename the bundle to `Collection`:

```prologos
bundle Collection := (Seqable, Buildable, Foldable)
```

The `Seq` trait (with `seq-first`, `seq-rest`, `seq-empty?`) remains as the minimal sequence interface. `Collection` is the full-featured bundle for generic operations.

### 7.3 Generic Operation Naming

**Decision**: Use bare names for the most common operations, since they will live in their own module and can be qualified on import if needed:

```prologos
;; In prologos.core.generic-ops:
spec gmap {A B : Type} {C : Type -> Type} [Collection C] -> [A -> B] -> [C A] -> [C B]
spec gfilter {A : Type} {C : Type -> Type} [Collection C] -> [A -> Bool] -> [C A] -> [C A]
spec gfold {A B : Type} {C : Type -> Type} [Foldable C] -> [B -> A -> B] -> B -> [C A] -> B
spec glength {A : Type} {C : Type -> Type} [Seqable C] -> [C A] -> Nat
```

Users who want to avoid collision with `list/map` can use qualified imports:
```prologos
require [prologos.core.generic-ops :as g :refer [gmap gfilter]]
```

**Alternative considered**: `seq-map`, `seq-filter`. More explicit but less elegant. The `g` prefix is shorter and signals "generic".

**Open question**: Should we use `map`, `filter` directly and shadow the List-specific versions in the prelude? This would be the most ergonomic but could break existing code. **Recommend deferring this decision** until we have usage experience with the `g`-prefixed versions.

---

## 8. Map Integration via Partial Application

### 8.1 The Problem

Map has kind `Type -> Type -> Type`. `Seqable` expects `Type -> Type`. The v1 document excluded Map entirely.

### 8.2 Proposed Solution: Partial Application

With `expr-tycon`, partial application is natural:

```
Map Int    = (expr-app (expr-tycon 'Map) (expr-Int))
```

This expression has kind `Type -> Type` and can implement `Seqable`:

```prologos
;; Seqable instance for (Map K), producing LSeq (Pair K V)
impl Seqable (Map K) where (Hashable K)
  defn to-seq [m] map-entries-to-lseq m
```

The `expr-tycon` + `expr-app` representation handles this naturally. The unifier can decompose:
- `(expr-app ?F ?V)` vs `(expr-Map K V)` = `(expr-app (expr-app (expr-tycon 'Map) K) V)`
- Solves `?F = (expr-app (expr-tycon 'Map) K)`, `?V = V`

### 8.3 Implementation Considerations

**What works already**: The `expr-tycon` approach naturally represents partial application. `(expr-app (expr-tycon 'Map) K)` is a valid expression of kind `Type -> Type`.

**What needs work**: The `impl` macro needs to handle compound type arguments like `(Map K)`. The parametric impl system already supports this: `impl Seqable (List A)` works via `process-parametric-impl`. Extending to `impl Seqable (Map K)` follows the same pattern.

**Decision**: Include Map partial application in Phase HKT-1 (it's a natural consequence of `expr-tycon`). The impl for `Seqable (Map K)` goes in Phase HKT-2 alongside other instance conversions.

---

## 9. Instance Coherence

### 9.1 Current State

**No coherence checking exists.** `register-impl!` silently overwrites. `try-parametric-resolve` takes first match via `for/or`. No orphan restrictions.

### 9.2 Proposed Coherence Rules

**Rule 1: No silent overwrites.** `register-impl!` should error if an entry with the same key already exists:
```racket
(define (register-impl! key entry)
  (when (hash-has-key? (current-impl-registry) key)
    (error 'impl "Duplicate instance: ~a already registered" key))
  (current-impl-registry (hash-set (current-impl-registry) key entry)))
```

**Rule 2: Most-specific-wins for parametric resolution.** When multiple parametric impls match, prefer the most specific one (fewer pattern variables). If equally specific, error with an ambiguity message.

```racket
;; Example: Both match Eq (List Nat)
impl Eq (List A) where (Eq A)    ;; pattern vars: {A}
impl Eq (List Nat)                ;; pattern vars: {} -- more specific
;; Resolution: Eq (List Nat) wins (fewer pattern vars)
```

**Rule 3: Orphan instance warning (not error).** An instance can be defined in any module, but if neither the trait nor the type is defined in the current module, emit a warning:
```
Warning: Orphan instance 'impl Eq ForeignType' in module my-app
  Neither Eq nor ForeignType is defined in this module.
  Consider defining this instance in prologos.core.eq-trait or the module defining ForeignType.
```

**Rule 4: No overlapping instances without explicit opt-in.** If two parametric impls could match the same type, error at registration time.

### 9.3 Implementation Phase

Coherence checking should be added in **Phase HKT-2** alongside the `impl` macro extensions, since that's where instances get registered. The changes are localized to `register-impl!` and `register-param-impl!` in `macros.rkt`.

---

## 10. Specialization Framework

### 10.1 Design (Even if Deferred)

**Critique point**: Design the specialization framework now, even if implemented later.

```prologos
;; Specialization rules: when the type constructor is known,
;; bypass the Seq roundtrip and use the direct implementation.

specialize gmap for List
  defn gmap [f xs] list-map f xs

specialize gmap for PVec
  defn gmap [f xs] pvec-map f xs

specialize gmap for Set
  defn gmap [f xs] set-map f xs
```

### 10.2 Implementation Sketch

Specialization rules would be stored in a registry keyed by `(function-name, type-constructor)`:

```racket
(define current-specialization-registry (make-parameter (hasheq)))
;; key: (cons 'gmap 'PVec) -> value: 'pvec-gmap--specialized
```

During `resolve-trait-constraints!`, after resolving all constraints, check if the function being called has a specialization for the resolved type constructor. If so, rewrite the call to use the specialized version.

**Decision**: Define the framework now but **defer implementation** to a post-HKT optimization phase. The generic Seq-roundtrip path is correct and sufficient for initial release.

### 10.3 Performance Expectations

The `to-seq -> transform -> from-seq` pattern involves:
1. Converting to LSeq: O(1) for lazy conversion, O(n) when forced
2. Transformation: O(n) (lazy, fused with step 1)
3. Converting back: O(n) (builds new collection)

**Expected overhead vs direct**: 2-3x for eager collections (PVec, Set), ~1x for List (LSeq conversion is cheap). Actual benchmarks needed before finalizing -- this is an estimate based on allocation patterns.

**Mitigation**: Users can always use Tier 2 prefixed ops (`pvec-map`, `set-filter`) for zero-overhead type-specific operations.

---

## 11. Error Messages

### 11.1 Error Cases

The v1 document had an inconsistent error example. Here are the correct error cases:

**Case 1: No instance exists**
```
Error: No instance of Seqable for MyCustomType
  The function 'gmap' requires (Seqable MyCustomType) but no matching impl was found.
  Hint: Define 'impl Seqable MyCustomType' with a 'to-seq' method.
```

**Case 2: Instance exists but not in scope**
```
Error: No instance of Seqable for PVec
  An instance exists in prologos.core.seqable-pvec but is not imported.
  Hint: Add 'require [prologos.core.seqable-pvec :refer []]' to load it.
```

**Case 3: Ambiguous instances (with overlapping)**
```
Error: Ambiguous instances for Eq (Option Nat)
  Candidate 1: Eq (Option A) where (Eq A)  [from prologos.core.eq-derived]
  Candidate 2: Eq (Option Nat)              [from my-module]
  Hint: Remove one instance or use explicit type annotation to disambiguate.
```

**Case 4: Kind mismatch**
```
Error: Kind mismatch in constraint (Seqable Int)
  Seqable expects a type constructor of kind 'Type -> Type',
  but Int has kind 'Type'.
```

### 11.2 Implementation

Extend `check-unresolved-trait-constraints` (trait-resolution.rkt) to:
1. Enumerate available impls for the unresolved trait (both registries)
2. Check if any exist but aren't loaded (requires tracking available-but-unloaded modules)
3. Check kind mismatches by comparing the trait's declared param kind with the actual type arg

---

## 12. Resolution Trace: End-to-End Example

User writes:
```prologos
ns my-app

spec transform {A B} [Collection C] -> [A -> B] -> [C A] -> [C B]
defn transform [f xs]
  from-seq [lseq-map f [to-seq xs]]

(def xs : (PVec Int) @[1 2 3])
transform [fn x [int+ x 1]] xs
```

**Step 1: Spec Processing (pre-parse)**
- `{A B}` -> bare params, default kind `Type`
- `[Collection C]` expands bundle -> `[Seqable C] [Buildable C] [Foldable C]`
- Kind propagation: `Seqable` has `{C : Type -> Type}` -> updates C's kind to `Type -> Type`
- Result binders: `{A : Type}`, `{B : Type}`, `{C : Type -> Type}`, `[Seqable C]`, `[Buildable C]`, `[Foldable C]`

**Step 2: Elaboration**
- Creates metas: `?A`, `?B`, `?C` (kinds Type, Type, Type->Type)
- Creates trait metas: `?seq`, `?build`, `?fold`
- Tags constraints: `(Seqable, [?C])`, `(Buildable, [?C])`, `(Foldable, [?C])`
- Populates where-context with methods: `to-seq` -> Seqable-to-seq, `from-seq` -> Buildable-from-seq
- Body `from-seq [lseq-map f [to-seq xs]]` resolves bare methods via where-context

**Step 3: Type Checking**
- Argument `xs : PVec Int` = `(expr-PVec (expr-Int))`
- Must unify with `?C ?A` = `(expr-app ?C ?A)`
- **Normalization fires**: `(expr-PVec (expr-Int))` -> `(expr-app (expr-tycon 'PVec) (expr-Int))`
- App decomposition: `?C = (expr-tycon 'PVec)`, `?A = (expr-Int)`
- From `f : A -> B` and usage: `?B = (expr-Int)`

**Step 4: Trait Resolution**
- `?seq`: trait = Seqable, type-args = [(expr-tycon 'PVec)]
- `expr->impl-key-str((expr-tycon 'PVec))` = `"PVec"`
- Key = `"PVec--Seqable"` -> found -> `?seq = (expr-fvar 'PVec--Seqable--dict)`
- Similarly: `?build` -> `"PVec--Buildable"` -> found
- Similarly: `?fold` -> `"PVec--Foldable"` -> found

**Step 5: Zonk & Codegen**
- All metas resolved. User code is fully specialized with no remaining dispatch.

---

## 13. Implementation Phases (Revised)

### Phase HKT-1: `expr-tycon` + Normalization + Kind Propagation (~250 lines, ~20 tests)
- Add `expr-tycon` AST node (14-file pipeline)
- Add kind table
- Add normalization in unifier
- Add kind propagation from trait constraints in spec processing
- Add `expr-tycon` handling in trait resolution
- Tests: tycon round-trips, unifier decomposition, kind propagation

### Phase HKT-2: Convert Traits + Instances + Coherence (~400 lines, ~25 tests)
- Convert `Foldable` and `Functor` from `deftype` to `trait`
- Rewrite all manual `def` instances to use `impl`
- Add coherence checking (duplicate detection, overlap warning)
- Verify `impl` handles type-constructor arguments
- Tests: impl registration, coherence errors, backward compatibility

### Phase HKT-3: Elaborator Enhancements (~300 lines, ~25 tests)
- Extend where-context for implicit dict params (bare method names)
- Trait resolution for HKT constraints end-to-end
- Handle Map partial application (`Map K` as `Type -> Type`)
- Tests: bare method resolution, HKT resolution, Map integration

### Phase HKT-4: Generic Operations + Bundle (~300 lines, ~30 tests)
- Define `Collection` bundle
- Create `generic-ops.prologos` (gmap, gfilter, gfold, etc.)
- Create Map-specific `Seqable (Map K)` instance
- Add to prelude
- Tests: generic ops on all collection types, Map integration

### Phase HKT-5: Polish (~150 lines, ~15 tests)
- Error messages (case 1-4 above)
- Specialization framework design (registry, no rewriting yet)
- Full test suite regression
- Documentation

**Total**: ~1400 lines, ~115 tests, 5 sequential phases

---

## 14. Three-Tier Collection Architecture

```
Tier 1: Direct AST keyword ops (pvec-nth, map-get, set-insert, etc.)
        -- Built-in reduction, zero overhead, type-specific

Tier 2: Prefixed library ops (pvec-map, set-filter, map-fold-entries, etc.)
        -- .prologos functions, no trait dispatch, type-preserving
        -- O(n) with minimal constant factor

Tier 3: Generic ops (gmap, gfilter, gfold, etc.)
        -- HKT-dispatched via Collection bundle
        -- to-seq -> transform -> from-seq
        -- O(n) with ~2-3x constant factor vs Tier 2
        -- Specializable to Tier 2 performance (future)
```

---

## 15. Surface Syntax Vision (Final)

```prologos
ns my-app

;; ========================================
;; Trait Definition (Clean)
;; ========================================
trait Seqable {C : Type -> Type}
  to-seq : C A -> LSeq A

trait Buildable {C : Type -> Type}
  from-seq : LSeq A -> C A
  empty : C A

;; ========================================
;; Instance Definition (Clean)
;; ========================================
impl Seqable PVec
  defn to-seq [v] pvec-to-lseq v

impl Buildable PVec
  defn from-seq [s] lseq-to-pvec s
  defn empty @[]

;; ========================================
;; Bundle (Clean)
;; ========================================
bundle Collection := (Seqable, Buildable, Foldable)

;; ========================================
;; Generic Function (Clean -- no dicts visible)
;; ========================================
spec transform [Collection C] -> [A -> B] -> [C A] -> [C B]
defn transform [f xs]
  from-seq [lseq-map f [to-seq xs]]

;; With pipe syntax:
defn transform [f xs]
  |> xs to-seq |> lseq-map f |> from-seq

;; ========================================
;; Call Sites (Clean -- zero boilerplate)
;; ========================================
transform inc @[1 2 3]        ;; PVec Int -> PVec Int
transform inc '[1 2 3]         ;; List Int -> List Int
transform inc ~[1 2 3]         ;; LSeq Int -> LSeq Int

;; Map via partial application:
gmap show {:x 1 :y 2}          ;; Map Keyword Int -> Map Keyword String

;; ========================================
;; Conversions (Explicit)
;; ========================================
vec '[1 2 3]                    ;; List -> PVec
into-list @[1 2 3]              ;; PVec -> List
into-set '[1 2 3]               ;; List -> Set

;; ========================================
;; Type-Specific (Zero Overhead)
;; ========================================
pvec-map inc @[1 2 3]           ;; Direct, no trait dispatch
set-filter even? #{1 2 3 4}     ;; Direct
```

---

## 16. Open Questions for Future Work

### FQ1: Deriving Mechanism

For user-defined inductive types, automatic derivation of Functor, Foldable, etc.:

```prologos
data Tree {A}
  leaf : A
  node : Tree A -> Tree A -> Tree A
  deriving (Functor, Foldable)
```

**Status**: Not in scope for HKT phases. Requires a separate design (structural recursion analysis).

### FQ2: Instance Chains / Overlapping Instances with Explicit Priority

```prologos
;; More specific wins:
impl Eq (List A) where (Eq A)       ;; general
impl Eq (List Nat)                    ;; specific -- wins for List Nat
```

**Status**: Basic "most specific wins" in Phase HKT-2. Full instance chains (explicit priority ordering) deferred.

### FQ3: Constraint Inference from Usage

```prologos
;; Compiler infers constraints from method usage:
defn transform [f xs]
  from-seq [lseq-map f [to-seq xs]]
;; Inferred: {A B} {C : Type -> Type} [Seqable C] [Buildable C] (A -> B) -> C A -> C B
```

**Status**: Deferred. Requires significant elaborator work. Explicit `spec` declarations are sufficient initially.

### FQ4: Loop Fusion for Generic Operations

Compose multiple generic operations without materializing intermediate collections:

```prologos
;; Should fuse into a single pass:
|> xs gmap f |> gfilter p |> gfold add 0
```

**Status**: The pipe operator already has fusion for List-specific ops. Extending to generic ops requires the specialization framework from Section 10.

---

## 17. Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Unifier normalization creates infinite loops | High | `can-normalize-to-app?` is a strict predicate on specific AST nodes; `normalize-to-app` produces `expr-app`/`expr-tycon` which don't match the predicate. Idempotent by construction. |
| `expr-tycon` breaks existing type inference | High | tycon only created during normalization in unifier and resolution. Normal elaboration paths unchanged. |
| Kind propagation interacts with implicit arg insertion | Medium | Kind propagation happens at spec-processing time (pre-parse); implicit insertion at elaboration time. Separated by design. |
| Coherence checking breaks existing code with duplicate instances | Medium | Start with warnings, escalate to errors after migration period. |
| Bare method name conflicts between traits | Medium | Require qualification when ambiguous: `Seqable/to-seq` vs `MyTrait/to-seq`. |
| Map partial application adds unifier complexity | Low | Natural consequence of existing app-vs-app decomposition. No new unifier cases needed. |

---

## Appendix A: Completeness Assessment (Addressing Critique)

| Area | V1 Status | V2 Status | Notes |
|------|-----------|-----------|-------|
| Core HKT dispatch | Addressed | Addressed | `expr-tycon` + normalization |
| Surface syntax | Verbose | **Addressed** | Bare methods, implicit dicts, kind inference |
| Kind inference | Deferred | **Designed** | Propagation from trait constraints |
| Constraint inference | Missing | **Designed** (deferred impl) | Framework described, implementation future |
| Coherence rules | Missing | **Addressed** | Duplicate detection, overlap handling |
| Specialization | Deferred | **Designed** (deferred impl) | Framework described, registry designed |
| Error messages | Inconsistent | **Addressed** | Four distinct error cases |
| Performance | Unvalidated | **Acknowledged** | Needs benchmarks; 3-tier gives user control |
| Map integration | Excluded | **Addressed** | Partial application via `expr-tycon` |
| Naming conflicts | Not addressed | **Addressed** | `Collection` bundle, `g`-prefix ops |
| Deriving | Missing | **Noted** as future | Not in scope |

## Appendix B: Trait Instance Matrix

| Trait | List | PVec | Set | LSeq | Map K |
|-------|------|------|-----|------|-------|
| Seqable | Manual -> impl | Manual -> impl | Manual -> impl | Manual -> impl (id) | **NEW** (partial app) |
| Buildable | Manual -> impl | Manual -> impl | Manual -> impl | Manual -> impl (id) | Future |
| Foldable | Manual -> impl | Manual -> impl | Manual -> impl | Manual -> impl | Future |
| Functor | Manual -> impl | Manual -> impl | - | - | Future |
| Indexed | Manual -> impl | Manual -> impl | - | - | N/A |
| Seq | Manual -> impl | - | - | Manual -> impl | N/A |
| Keyed | N/A | N/A | N/A | N/A | Manual -> impl |
| Setlike | N/A | N/A | N/A | N/A | N/A |
| Eq | impl | - | - | - | - |

All "Manual -> impl" entries will be converted during Phase HKT-2.
