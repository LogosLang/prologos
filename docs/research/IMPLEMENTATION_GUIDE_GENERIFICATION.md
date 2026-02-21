# Implementation Guide: HKT-Based Whole-Library Generification

## A Complete, Phased Implementation for Higher-Kinded Type Dispatch, Kind Inference, Coherence, Specialization, and Clean Surface Syntax

**Date**: 2026-02-20
**Companion document**: `RESEARCH_HKT_GENERIFICATION_DESIGN.md`
**Status**: Implementation-ready

---

## Table of Contents

1. [Introduction and Scope](#1-introduction-and-scope)
2. [Architectural Foundations](#2-architectural-foundations)
   - 2.1 [The Type Constructor Representation Problem](#21-the-type-constructor-representation-problem)
   - 2.2 [Dictionary Passing as Runtime Strategy](#22-dictionary-passing-as-runtime-strategy)
   - 2.3 [Comparison with Other Language Implementations](#23-comparison-with-other-language-implementations)
3. [Phase HKT-1: `expr-tycon` AST Node and Normalization Layer](#3-phase-hkt-1-expr-tycon-ast-node-and-normalization-layer)
   - 3.1 [The `expr-tycon` Struct](#31-the-expr-tycon-struct)
   - 3.2 [Kind Table](#32-kind-table)
   - 3.3 [14-File AST Pipeline Changes](#33-14-file-ast-pipeline-changes)
   - 3.4 [Normalization Layer](#34-normalization-layer)
   - 3.5 [Unifier Enhancements](#35-unifier-enhancements)
   - 3.6 [Trait Resolution Extensions](#36-trait-resolution-extensions)
   - 3.7 [Testing Strategy for HKT-1](#37-testing-strategy-for-hkt-1)
4. [Phase HKT-2: Kind Inference from Trait Constraints](#4-phase-hkt-2-kind-inference-from-trait-constraints)
   - 4.1 [The Kind Inference Problem](#41-the-kind-inference-problem)
   - 4.2 [Algorithm: Pre-Parse Kind Propagation](#42-algorithm-pre-parse-kind-propagation)
   - 4.3 [Implementation in `process-spec`](#43-implementation-in-process-spec)
   - 4.4 [Kind Inference from Multiple Constraints](#44-kind-inference-from-multiple-constraints)
   - 4.5 [Kind Consistency Checking](#45-kind-consistency-checking)
   - 4.6 [Testing Strategy for HKT-2](#46-testing-strategy-for-hkt-2)
5. [Phase HKT-3: Convert Traits, Instances, and `impl` Macro Extensions](#5-phase-hkt-3-convert-traits-instances-and-impl-macro-extensions)
   - 5.1 [Converting `deftype` Traits to `trait`](#51-converting-deftype-traits-to-trait)
   - 5.2 [Extending `process-impl` for Type Constructors](#52-extending-process-impl-for-type-constructors)
   - 5.3 [Rewriting Manual `def` Instances to `impl`](#53-rewriting-manual-def-instances-to-impl)
   - 5.4 [Map Partial Application via `impl`](#54-map-partial-application-via-impl)
   - 5.5 [Testing Strategy for HKT-3](#55-testing-strategy-for-hkt-3)
6. [Phase HKT-4: Coherence and Instance Safety](#6-phase-hkt-4-coherence-and-instance-safety)
   - 6.1 [The Coherence Problem](#61-the-coherence-problem)
   - 6.2 [Lessons from Other Languages](#62-lessons-from-other-languages)
   - 6.3 [Prologos Coherence Rules](#63-prologos-coherence-rules)
   - 6.4 [Duplicate Instance Detection](#64-duplicate-instance-detection)
   - 6.5 [Most-Specific-Wins Resolution](#65-most-specific-wins-resolution)
   - 6.6 [Orphan Instance Warnings](#66-orphan-instance-warnings)
   - 6.7 [Overlap Detection at Registration Time](#67-overlap-detection-at-registration-time)
   - 6.8 [Testing Strategy for HKT-4](#68-testing-strategy-for-hkt-4)
7. [Phase HKT-5: Elaborator Enhancements for Clean Surface Syntax](#7-phase-hkt-5-elaborator-enhancements-for-clean-surface-syntax)
   - 7.1 [Bare Method Name Resolution for Implicit Dicts](#71-bare-method-name-resolution-for-implicit-dicts)
   - 7.2 [End-to-End HKT Trait Resolution](#72-end-to-end-hkt-trait-resolution)
   - 7.3 [Testing Strategy for HKT-5](#73-testing-strategy-for-hkt-5)
8. [Phase HKT-6: Generic Operations and the Collection Bundle](#8-phase-hkt-6-generic-operations-and-the-collection-bundle)
   - 8.1 [Collection Bundle Definition](#81-collection-bundle-definition)
   - 8.2 [Generic Operation Implementations](#82-generic-operation-implementations)
   - 8.3 [Map-Specific Instances via Partial Application](#83-map-specific-instances-via-partial-application)
   - 8.4 [Prelude Integration](#84-prelude-integration)
   - 8.5 [Testing Strategy for HKT-6](#85-testing-strategy-for-hkt-6)
9. [Phase HKT-7: Error Messages](#9-phase-hkt-7-error-messages)
   - 9.1 [Error Taxonomy](#91-error-taxonomy)
   - 9.2 [Implementation Details](#92-implementation-details)
   - 9.3 [Testing Strategy for HKT-7](#93-testing-strategy-for-hkt-7)
10. [Phase HKT-8: Specialization Framework](#10-phase-hkt-8-specialization-framework)
    - 10.1 [The Specialization Problem](#101-the-specialization-problem)
    - 10.2 [Lessons from GHC's RULES and SPECIALISE](#102-lessons-from-ghcs-rules-and-specialise)
    - 10.3 [Prologos Specialization Design](#103-prologos-specialization-design)
    - 10.4 [The `specialize` Macro](#104-the-specialize-macro)
    - 10.5 [Call-Site Rewriting During Resolution](#105-call-site-rewriting-during-resolution)
    - 10.6 [Phase Interaction: Specialization vs Inlining](#106-phase-interaction-specialization-vs-inlining)
    - 10.7 [Stream Fusion Integration](#107-stream-fusion-integration)
    - 10.8 [Testing Strategy for HKT-8](#108-testing-strategy-for-hkt-8)
11. [Phase HKT-9: Constraint Inference from Usage](#11-phase-hkt-9-constraint-inference-from-usage)
    - 11.1 [The Constraint Inference Problem](#111-the-constraint-inference-problem)
    - 11.2 [Lessons from GHC and Lean 4](#112-lessons-from-ghc-and-lean-4)
    - 11.3 [Algorithm: Method-Triggered Constraint Generation](#113-algorithm-method-triggered-constraint-generation)
    - 11.4 [Ambiguity Resolution](#114-ambiguity-resolution)
    - 11.5 [Implementation Plan](#115-implementation-plan)
    - 11.6 [Testing Strategy for HKT-9](#116-testing-strategy-for-hkt-9)
12. [Future Work: Deriving Mechanism](#12-future-work-deriving-mechanism)
    - 12.1 [The Deriving Problem](#121-the-deriving-problem)
    - 12.2 [Derivable Traits and Structural Recursion](#122-derivable-traits-and-structural-recursion)
    - 12.3 [Design Sketch](#123-design-sketch)
13. [Performance Analysis and Benchmarking](#13-performance-analysis-and-benchmarking)
    - 13.1 [Dictionary Passing Overhead Model](#131-dictionary-passing-overhead-model)
    - 13.2 [The Seq Roundtrip Cost](#132-the-seq-roundtrip-cost)
    - 13.3 [Benchmark Plan](#133-benchmark-plan)
14. [Dependency Graph and Critical Path](#14-dependency-graph-and-critical-path)
15. [Summary Table](#15-summary-table)
16. [References and Key Literature](#16-references-and-key-literature)

---

## 1. Introduction and Scope

This guide provides a complete, implementation-ready blueprint for enabling Higher-Kinded Type (HKT) dispatch in Prologos. It addresses every deferred item, blocking gap, and future work item identified in the companion research document (`RESEARCH_HKT_GENERIFICATION_DESIGN.md`), providing sufficient detail for each phase to be implemented without further design work.

### What This Guide Covers

The research document identified 9 deferred or blocking items:

| # | Item | Status in Research Doc | Status Here |
|---|------|----------------------|-------------|
| 1 | `expr-tycon` + normalization (core HKT infra) | Designed | **Full implementation spec** |
| 2 | Kind inference from trait constraints | Designed but sparse | **Complete algorithm** |
| 3 | `impl` macro for type constructors | Outlined | **Full implementation spec** |
| 4 | Coherence rules | 4 rules proposed | **Complete implementation with algorithms** |
| 5 | Bare method name resolution | Outlined | **Full implementation spec** |
| 6 | Generic operations + Collection bundle | Outlined | **Complete with all signatures** |
| 7 | Error messages | 4 cases listed | **Full implementation with code** |
| 8 | Specialization framework | Framework only | **Complete design with rewrite rules** |
| 9 | Constraint inference from usage | "Future work" | **Complete algorithm design** |
| 10 | Deriving mechanism | "Not in scope" | **Design sketch provided** |
| 11 | Performance validation | "Needs benchmarks" | **Benchmark plan with methodology** |

### Target Implementation

All code changes target the Racket prototype at `racket/prologos/`. The standard library at `lib/prologos/` contains `.prologos` source files. Tests live in `tests/`.

### Prerequisites

- Library generification (Phases 3a-3h): COMPLETE
- Trait system (Phases A-E): COMPLETE
- Numerics tower (Phases 1-3f): COMPLETE
- All 2912+ existing tests pass

---

## 2. Architectural Foundations

### 2.1 The Type Constructor Representation Problem

Prologos has a fundamental representation mismatch between user-defined and built-in types:

```
User-defined types:     (expr-app (expr-fvar 'List) A)     -- application of fvar
Built-in types:         (expr-PVec A)                       -- dedicated AST node
                        (expr-Set A)                        -- dedicated AST node
                        (expr-Map K V)                      -- dedicated AST node
```

The unifier's `app-vs-app` decomposition (unify.rkt line 192-194) can decompose `(expr-app f1 a1)` vs `(expr-app f2 a2)` by unifying `f1=f2` and `a1=a2`. But when one side is `(expr-app ?F ?A)` (with a metavariable head) and the other is `(expr-PVec A)` (a built-in node), no decomposition case exists.

**The solution**: Introduce `expr-tycon` as a canonical representation for unapplied type constructors, and a normalization layer that converts built-in applications to `expr-app`/`expr-tycon` form before unification.

### 2.2 Dictionary Passing as Runtime Strategy

Prologos uses dictionary passing for trait dispatch, following the Wadler-Blott approach (1989). Each trait constraint becomes an implicit parameter carrying a dictionary (function value or nested pair of functions) at runtime.

**Performance model**: Dictionary passing adds O(1) per call site (passing 1-3 extra arguments). The dictionary is a concrete function pointer, so no vtable indirection or virtual dispatch occurs. When the type is statically known, the dictionary is a known constant — inlining can eliminate the indirection entirely.

**Comparison with alternatives**:

| Strategy | Runtime Cost | Code Size | Flexibility | Used By |
|----------|-------------|-----------|-------------|---------|
| Dictionary passing | O(1) per call | 1x | Full polymorphism | GHC Haskell (default), Prologos |
| Monomorphization | 0 (specialized) | O(n × types) | No polymorphic recursion | Rust, C++ templates |
| Vtable dispatch | O(1) per call + indirection | 1x | Full | Java interfaces, Go |
| JIT specialization | Amortized 0 | Dynamic | Full | Julia, V8 |

Dictionary passing is the correct choice for Prologos because:
1. It supports polymorphic recursion (e.g., `gmap` calling itself on differently-typed sub-collections)
2. It preserves code sharing (one copy of `gmap` works for all types)
3. Specialization can be added later as an optimization without changing semantics

### 2.3 Comparison with Other Language Implementations

#### GHC Haskell

GHC's typeclass system uses **dictionary passing** at the Core level. Each typeclass constraint `(Ord a) =>` becomes an explicit dictionary parameter. GHC's constraint solver (`GHC.Tc.Solver`) uses Constraint Handling Rules (CHR) internally to solve wanted constraints against given constraints and top-level instances.

Key implementation details relevant to Prologos:
- **Instance lookup**: GHC uses a **discrimination tree** (trie indexed by type constructor) for fast instance lookup. For `Eq (List Nat)`, it first looks up `List` in the `Eq` discrimination tree, finding `instance (Eq a) => Eq [a]`, then recursively solves `Eq Nat`.
- **Specialization**: GHC's `SPECIALISE` pragma and auto-specialization generate monomorphic copies of polymorphic functions when type arguments are statically known. The simplifier inlines dictionary arguments into these copies, eliminating dispatch overhead.
- **Kind inference**: GHC infers kinds from typeclass constraints. `class Functor (f :: * -> *)` tells GHC that `f` has kind `* -> *`. When a user writes `instance Functor MyType`, GHC checks that `MyType` has the correct kind.

#### Lean 4

Lean 4's typeclass system uses **discrimination trees** for instance lookup, implemented in `Lean.Meta.SynthInstance`. The algorithm:
1. Given a goal like `Monad ?m`, index into the discrimination tree using the head symbol.
2. For each candidate instance, attempt to unify the instance head with the goal.
3. Recursively solve sub-goals (the instance's premises).
4. Uses a **depth limit** (default 32) to prevent infinite loops.
5. Results are cached in a `SynthInstanceCache` keyed by the goal expression.

Lean's approach differs from GHC in that typeclasses are first-class — they're just structures with a `[instance]` attribute. Resolution is unified with general elaboration, not a separate system.

#### Idris 2

Idris 2 resolves interfaces (its term for typeclasses) during elaboration. Since Idris has full dependent types, interfaces can be parameterized by values, not just types. The elaborator uses a proof search mechanism: given a goal `Eq Nat`, it searches for terms of that type in the context and registered instances. The search is essentially the same as typeclass resolution but unified with the type checker.

**Relevance to Prologos**: Prologos has dependent types but uses a simpler resolution strategy (registry lookup, not proof search). This is sufficient for the Phase 0 implementation and avoids the complexity of Idris's search. The registry approach is closer to GHC's and Lean's.

---

## 3. Phase HKT-1: `expr-tycon` AST Node and Normalization Layer

### 3.1 The `expr-tycon` Struct

Add to `syntax.rkt`:

```racket
;; Unapplied type constructor — represents PVec, Map, Set, etc. as first-class
;; type-level values of kind Type -> Type (or Type -> Type -> Type for Map).
;; Created during unifier normalization and trait resolution, NOT by the parser.
(struct expr-tycon (name) #:transparent)
;; name : symbol — e.g., 'PVec, 'Map, 'Set, 'List, 'LSeq
```

This struct must be:
- Added to the `provide` block alongside other expression constructors
- Added to `expr?` if there is a custom predicate (currently Racket's `struct?` handles this)

### 3.2 Kind Table

Add to `syntax.rkt` (after the struct definitions):

```racket
;; Arity table for built-in type constructors.
;; Used by: typing-core.rkt (kind inference), unify.rkt (normalization guard),
;;          trait-resolution.rkt (key generation), macros.rkt (impl validation)
(define builtin-tycon-arity
  (hasheq 'PVec  1    ;; PVec : Type -> Type
          'Set   1    ;; Set  : Type -> Type
          'Map   2    ;; Map  : Type -> Type -> Type
          'List  1    ;; List : Type -> Type (user-defined but special)
          'LSeq  1    ;; LSeq : Type -> Type
          'Vec   2    ;; Vec  : Type -> Nat -> Type
          'TVec  1    ;; TVec : Type -> Type
          'TMap  2    ;; TMap : Type -> Type -> Type
          'TSet  1))  ;; TSet : Type -> Type

;; Normalization constructors: given args, rebuild the built-in AST node.
;; Only for built-in types with dedicated expr structs.
(define builtin-tycon-constructor
  (hasheq 'PVec  (lambda (args) (expr-PVec (car args)))
          'Set   (lambda (args) (expr-Set (car args)))
          'Map   (lambda (args) (expr-Map (car args) (cadr args)))
          'TVec  (lambda (args) (expr-TVec (car args)))
          'TMap  (lambda (args) (expr-TMap (car args) (cadr args)))
          'TSet  (lambda (args) (expr-TSet (car args)))))
;; List, LSeq, Vec are NOT in this table — List/LSeq use expr-fvar,
;; Vec uses expr-Vec which has different semantics (length-indexed).

(provide builtin-tycon-arity builtin-tycon-constructor)
```

### 3.3 14-File AST Pipeline Changes

Each file in the AST pipeline needs a case for `expr-tycon`. Since `expr-tycon` has no subexpressions (it's a leaf node wrapping a symbol), all cases are trivial identity transformations:

#### `syntax.rkt`
```racket
;; Already handled above: struct definition + provide + kind table
```

#### `substitution.rkt`
```racket
;; In the main substitution function:
[(expr-tycon _) e]  ;; No bvars inside, identity
```

#### `zonk.rkt`
```racket
;; In zonk (intermediate), zonk-default (final), and zonk-at-depth:
[(expr-tycon _) e]  ;; No metas inside, identity
```

#### `typing-core.rkt`
```racket
;; In the 'infer' function:
[(expr-tycon name)
 ;; Build kind: Type -> Type -> ... -> Type (arity arrows)
 ;; PVec has arity 1: Pi(:0 Type, Type) = Type -> Type
 ;; Map has arity 2:  Pi(:0 Type, Pi(:0 Type, Type)) = Type -> Type -> Type
 (define arity (hash-ref builtin-tycon-arity name
                  (lambda () (error 'infer "Unknown type constructor: ~a" name))))
 (for/fold ([ty (expr-Type (lzero))])
           ([_ (in-range arity)])
   (expr-Pi 'm0 (expr-Type (lzero)) (shift 1 ty)))]
```

**Note**: The `shift 1 ty` is critical — each additional Pi binder shifts the de Bruijn indices of the result type. For arity 1: `Pi(:0 (Type 0), (Type 0))`. For arity 2: `Pi(:0 (Type 0), Pi(:0 (Type 0), (Type 0)))`.

#### `qtt.rkt`
```racket
;; In the 'inferQ' function:
[(expr-tycon _) 'm0]  ;; Type constructors are erased at runtime
```

#### `reduction.rkt`
```racket
;; In the 'whnf' function (or wherever reduction patterns are matched):
[(expr-tycon _) e]  ;; Already in normal form
```

Additionally, if `expr-tycon` appears as the head of an `expr-app`, we may want to "de-normalize" back to the built-in form during reduction. This is **not required** for correctness but aids pretty-printing and consistency:

```racket
;; Optional: in whnf, after app reduction, if the result is
;; (expr-app (expr-tycon 'PVec) A), convert to (expr-PVec A).
;; This keeps the reduction output in canonical form.
;; Decision: DO NOT do this in Phase HKT-1. Normalization is only
;; for unification; reduction should not produce expr-tycon.
```

#### `pretty-print.rkt`
```racket
;; In pp-expr:
[(expr-tycon name) (symbol->string name)]

;; In uses-bvar0?:
[(expr-tycon _) #f]
```

#### `unify.rkt`
See Section 3.5 below for detailed changes.

#### `surface-syntax.rkt`
No change needed. `expr-tycon` is internal — never produced by the surface syntax parser.

#### `parser.rkt`
No change needed. `expr-tycon` is created by normalization, not parsing.

#### `elaborator.rkt`
No change in Phase HKT-1. Kind inference changes come in Phase HKT-2. The elaborator does not need to produce `expr-tycon` directly — it's created during unification normalization.

#### `foreign.rkt`
No change needed.

#### `macros.rkt`
No change in Phase HKT-1. `impl` macro extensions come in Phase HKT-3.

### 3.4 Normalization Layer

The normalization function converts built-in type applications to `expr-app`/`expr-tycon` form. It is used in two contexts:

1. **Unifier**: When one side of a unification is a built-in type application and the other is an `expr-app` (possibly with a meta head), normalize the built-in side to enable decomposition.

2. **Trait resolution**: When extracting the type constructor from a resolved type argument for impl key generation.

```racket
;; In unify.rkt or a shared utility module:

;; Predicate: can this expression be normalized to expr-app/expr-tycon form?
(define (can-normalize-to-app? e)
  (match e
    [(expr-PVec _) #t]
    [(expr-Set _) #t]
    [(expr-Map _ _) #t]
    [(expr-TVec _) #t]
    [(expr-TMap _ _) #t]
    [(expr-TSet _) #t]
    [_ #f]))

;; Normalize a built-in type application to expr-app/expr-tycon form.
;; (expr-PVec A)   → (expr-app (expr-tycon 'PVec) A)
;; (expr-Map K V)  → (expr-app (expr-app (expr-tycon 'Map) K) V)
;; (expr-Set A)    → (expr-app (expr-tycon 'Set) A)
;; Idempotent: calling on an already-normalized expr returns it unchanged.
(define (normalize-to-app e)
  (match e
    [(expr-PVec a)   (expr-app (expr-tycon 'PVec) a)]
    [(expr-Set a)    (expr-app (expr-tycon 'Set) a)]
    [(expr-Map k v)  (expr-app (expr-app (expr-tycon 'Map) k) v)]
    [(expr-TVec a)   (expr-app (expr-tycon 'TVec) a)]
    [(expr-TMap k v) (expr-app (expr-app (expr-tycon 'TMap) k) v)]
    [(expr-TSet a)   (expr-app (expr-tycon 'TSet) a)]
    [_ e]))  ;; identity for everything else
```

**Critical property**: `normalize-to-app` is **idempotent**. Applying it twice produces the same result. The output (`expr-app`/`expr-tycon`) does NOT match `can-normalize-to-app?`, so there is no risk of infinite normalization loops.

### 3.5 Unifier Enhancements

Add to `unify-whnf` in `unify.rkt`, **before** the existing `app-vs-app` case (line 192) and **after** the structural decomposition of Pi/Sigma/suc:

```racket
;; --- HKT normalization: built-in type vs app/meta ---
;; When one side is a built-in type application (e.g., expr-PVec)
;; and the other is an expr-app or a meta (possibly flex-app),
;; normalize the built-in side to expr-app/expr-tycon form
;; so standard app-vs-app decomposition can proceed.
;;
;; This fires BEFORE app-vs-app (line 192) so that:
;;   (expr-PVec Int) vs (expr-app ?F Int)
;; becomes:
;;   (expr-app (expr-tycon 'PVec) Int) vs (expr-app ?F Int)
;; which decomposes to ?F = (expr-tycon 'PVec), Int = Int.

[(and (can-normalize-to-app? a) (or (expr-app? b) (expr-meta? b)))
 (unify-whnf ctx (normalize-to-app a) b)]
[(and (or (expr-app? a) (expr-meta? a)) (can-normalize-to-app? b))
 (unify-whnf ctx a (normalize-to-app b))]

;; Both sides are built-in type applications of different kinds:
;; (expr-PVec A) vs (expr-Set B) → normalize both
[(and (can-normalize-to-app? a) (can-normalize-to-app? b))
 (unify-whnf ctx (normalize-to-app a) (normalize-to-app b))]

;; expr-tycon vs expr-tycon: same name = equal
[(and (expr-tycon? a) (expr-tycon? b))
 (eq? (expr-tycon-name a) (expr-tycon-name b))]
```

**Also handle flex-app normalization**: When `flex-app?` fires on one side and the other is a built-in type, normalize:

```racket
;; After the existing flex-app cases (line 199-202):
;; When flex-app meets a built-in type, normalize the built-in side
[(and (flex-app? a) (can-normalize-to-app? b))
 (unify-whnf ctx a (normalize-to-app b))]
[(and (can-normalize-to-app? a) (flex-app? b))
 (unify-whnf ctx (normalize-to-app a) b)]
```

**Ordering within `unify-whnf`**: The new cases must be placed **after** the meta-solving cases (lines 151-156) but **before** the existing app-vs-app case (line 192). The exact insertion point is after the suc-vs-suc case (line 188-189):

```
[suc vs suc]          ;; line 188-189
[HKT normalization]   ;; NEW: lines ~190a-190f
[app vs app]          ;; line 192-194
[flex-app]            ;; line 196-202
[HKT flex-app norm]   ;; NEW: after line 202
```

### 3.6 Trait Resolution Extensions

Extend `trait-resolution.rkt` with new cases:

#### `ground-expr?` (line 37-54)

Add cases for built-in types that may appear as resolved type args:

```racket
[(expr-tycon _) #t]
[(expr-Int) #t]
[(expr-Rat) #t]
[(expr-Posit8) #t]
[(expr-Posit16) #t]
[(expr-Posit32) #t]
[(expr-Posit64) #t]
[(expr-Keyword) #t]
[(expr-PVec a) (ground-expr? a)]
[(expr-Set a) (ground-expr? a)]
[(expr-Map k v) (and (ground-expr? k) (ground-expr? v))]
```

#### `expr->impl-key-str` (line 62-81)

Add case for `expr-tycon`:

```racket
[(expr-tycon name) (symbol->string name)]
```

#### `match-one` (line 128-157)

Add cases for `expr-tycon` and all built-in numeric/collection types:

```racket
;; In the concrete-symbol matching branch (after the existing Nat/Bool/fvar cases):
[(expr-Int) (and (eq? pattern 'Int) bindings)]
[(expr-Rat) (and (eq? pattern 'Rat) bindings)]
[(expr-Posit8) (and (eq? pattern 'Posit8) bindings)]
[(expr-Posit16) (and (eq? pattern 'Posit16) bindings)]
[(expr-Posit32) (and (eq? pattern 'Posit32) bindings)]
[(expr-Posit64) (and (eq? pattern 'Posit64) bindings)]
[(expr-Keyword) (and (eq? pattern 'Keyword) bindings)]
[(expr-tycon name) (and (symbol? pattern) (symbol-matches? pattern name) bindings)]
```

#### `resolve-trait-constraints!` (line 231-241)

Add normalization of type args before resolution:

```racket
(define (resolve-trait-constraints!)
  (for ([(meta-id tc-info) (in-hash (current-trait-constraint-map))])
    (unless (meta-solved? meta-id)
      (define trait-name (trait-constraint-info-trait-name tc-info))
      ;; NEW: normalize type args through expr-tycon for HKT resolution
      (define type-args
        (map (lambda (e)
               (define z (zonk e))
               ;; If the zonked type arg is a solved meta containing a tycon,
               ;; or an fvar that's a known type constructor, normalize it.
               (normalize-type-arg-for-resolution z))
             (trait-constraint-info-type-arg-exprs tc-info)))
      (when (andmap ground-expr? type-args)
        (define dict-expr
          (or (try-monomorphic-resolve trait-name type-args)
              (try-parametric-resolve trait-name type-args)))
        (when dict-expr
          (solve-meta! meta-id dict-expr))))))

;; Helper: normalize a type arg for resolution.
;; If it's an expr-fvar that's a known type constructor, promote to expr-tycon.
;; If it's a built-in type application, this doesn't change it (we want the
;; constructor name, not the applied form).
(define (normalize-type-arg-for-resolution e)
  (match e
    [(expr-fvar name)
     (if (hash-has-key? builtin-tycon-arity name)
         (expr-tycon name)
         e)]
    [(expr-tycon _) e]  ;; already normalized
    [_ e]))
```

### 3.7 Testing Strategy for HKT-1

Create `tests/test-tycon.rkt` with ~20 tests:

1. **AST pipeline round-trips** (5 tests):
   - `expr-tycon` survives substitution, zonk, pretty-print
   - `expr-tycon` has correct kind via `infer`
   - `expr-tycon` returns `'m0` from `inferQ`

2. **Unifier decomposition** (8 tests):
   - `(expr-PVec Int)` unifies with `(expr-app ?F Int)` → `?F = (expr-tycon 'PVec)`
   - `(expr-Set Bool)` unifies with `(expr-app ?F Bool)` → `?F = (expr-tycon 'Set)`
   - `(expr-Map K V)` unifies with `(expr-app (expr-app ?F K) V)` → `?F = (expr-tycon 'Map)`
   - `(expr-tycon 'PVec)` unifies with `(expr-tycon 'PVec)` → `#t`
   - `(expr-tycon 'PVec)` does NOT unify with `(expr-tycon 'Set)` → `#f`
   - `(expr-app (expr-fvar 'List) Int)` unifies with `(expr-app ?F Int)` → `?F = (expr-fvar 'List)`
   - `(expr-PVec A)` unifies with `(expr-PVec A)` → `#t` (no normalization needed)
   - `(expr-PVec (expr-meta ?a))` where `?a` is solved to `Int` normalizes correctly

3. **Trait resolution key generation** (4 tests):
   - `expr->impl-key-str (expr-tycon 'PVec)` = `"PVec"`
   - `expr->impl-key-str (expr-tycon 'Map)` = `"Map"`
   - `ground-expr? (expr-tycon 'PVec)` = `#t`
   - `match-one (expr-tycon 'PVec) 'PVec '() (hasheq)` = `(hasheq)`

4. **Normalization properties** (3 tests):
   - Idempotency: `normalize-to-app (normalize-to-app (expr-PVec Int))` = `normalize-to-app (expr-PVec Int)`
   - Non-built-in passthrough: `normalize-to-app (expr-app (expr-fvar 'List) Int)` = unchanged
   - `can-normalize-to-app?` returns `#f` for `expr-app`, `expr-tycon`, `expr-fvar`

**Estimated**: 20 tests, ~150 lines of test code

---

## 4. Phase HKT-2: Kind Inference from Trait Constraints

### 4.1 The Kind Inference Problem

When a user writes:

```prologos
spec gmap {C} [Seqable C] -> [Buildable C] -> [A -> B] -> [C A] -> [C B]
```

The `{C}` brace param defaults to kind `Type` (via `parse-brace-param-list`). But `Seqable` is declared with `{C : Type -> Type}`, so `C` must have kind `Type -> Type`.

**Current behavior**: The elaborator creates a meta `?C` with kind `Type`. When it encounters `(Seqable ?C)` and tries to apply `?C` to `A`, the kind mismatch causes a type error.

**Desired behavior**: The compiler infers `C : Type -> Type` from the `[Seqable C]` constraint, before elaboration begins.

### 4.2 Algorithm: Pre-Parse Kind Propagation

The algorithm runs during `process-spec` in `macros.rkt`, after brace params are parsed but before the type expression is built:

```
Input:  brace-params = ((C . (Type 0)) (A . (Type 0)) (B . (Type 0)))
        where-constraints = ((Seqable C) (Buildable C))

Step 1: For each where-constraint (TraitName Var1 Var2 ...):
          a. Look up TraitName in the trait registry
          b. Get the trait's declared params: ((C . (-> (Type 0) (Type 0))))
          c. For each (Var_i, TraitParam_i), if Var_i is in brace-params
             and the brace-param's current kind is (Type 0),
             update it to TraitParam_i's kind.

Step 2: Check consistency: if the same variable gets different kinds
        from different constraints, error.

Output: brace-params = ((C . (-> (Type 0) (Type 0))) (A . (Type 0)) (B . (Type 0)))
```

### 4.3 Implementation in `process-spec`

In `macros.rkt`, the `spec` processing pipeline currently works as:

1. `extract-implicit-binders` — strips leading `($brace-params ...)` groups
2. `build-spec-type` — constructs the Pi chain from binders and arrow type
3. Registers the spec entry with where-constraints

The kind propagation step inserts between step 1 and step 2:

```racket
;; In process-spec, after extract-implicit-binders:
(define propagated-brace-params
  (propagate-kinds-from-constraints brace-params where-constraints))

;; New function:
(define (propagate-kinds-from-constraints brace-params where-constraints)
  ;; brace-params: ((name . kind-datum) ...)
  ;; where-constraints: ((TraitName Var1 Var2 ...) ...)
  (define param-table (make-hasheq))  ;; name -> kind-datum (mutable for updates)
  (for ([bp (in-list brace-params)])
    (hash-set! param-table (car bp) (cdr bp)))

  (for ([wc (in-list where-constraints)])
    (define trait-name (car wc))
    (define constraint-vars (cdr wc))
    (define tm (lookup-trait trait-name))
    (when tm
      (define trait-params (trait-meta-params tm))
      ;; Match constraint vars to trait params positionally
      (for ([cv (in-list constraint-vars)]
            [tp (in-list trait-params)]
            #:when (hash-has-key? param-table cv))
        (define current-kind (hash-ref param-table cv))
        (define trait-kind (cdr tp))  ;; e.g., (-> (Type 0) (Type 0))
        (cond
          ;; Current kind is default (Type 0) — upgrade to trait's kind
          [(and (list? current-kind)
                (= (length current-kind) 2)
                (eq? (car current-kind) 'Type)
                (equal? (cadr current-kind) 0))
           (hash-set! param-table cv trait-kind)]
          ;; Current kind already set — verify consistency
          [(not (equal? current-kind trait-kind))
           (error 'spec
             "Kind mismatch for ~a: constraint ~a requires kind ~a, but already inferred ~a"
             cv trait-name (datum->kind-string trait-kind) (datum->kind-string current-kind))]
          ;; Same kind — no action needed
          [else (void)]))))

  ;; Rebuild brace-params list with updated kinds
  (for/list ([bp (in-list brace-params)])
    (cons (car bp) (hash-ref param-table (car bp)))))

;; Helper to format kind for error messages
(define (datum->kind-string d)
  (cond
    [(and (list? d) (eq? (car d) 'Type)) "Type"]
    [(and (list? d) (eq? (car d) '->) (= (length d) 3))
     (format "~a -> ~a" (datum->kind-string (cadr d)) (datum->kind-string (caddr d)))]
    [else (format "~a" d)]))
```

### 4.4 Kind Inference from Multiple Constraints

When multiple constraints reference the same variable, they must agree on the kind:

```prologos
;; Both Seqable and Buildable have {C : Type -> Type}
spec transform {C} [Seqable C] -> [Buildable C] -> ...
;; Result: C : Type -> Type (both agree)

;; Error case:
spec bad {X} [Seqable X] -> [Eq X] -> ...
;; Error: Kind mismatch for X: Seqable requires Type -> Type, but Eq requires Type
```

The algorithm handles this naturally: the first constraint sets the kind; subsequent constraints verify consistency.

### 4.5 Kind Consistency Checking

An additional check: when `{C : Type -> Type}` is explicitly annotated AND a constraint implies the same kind, no error — the explicit annotation is confirmed. When they disagree, error:

```prologos
;; OK: explicit annotation matches constraint
spec foo {C : Type -> Type} [Seqable C] -> ...

;; Error: explicit annotation conflicts with constraint
spec bad {C : Type} [Seqable C] -> ...
;; Error: Kind mismatch for C: Seqable requires Type -> Type, but explicitly annotated as Type
```

**Implementation**: The consistency check in `propagate-kinds-from-constraints` handles this — it checks whether the current kind (which may be explicit or default) matches the trait's requirement.

### 4.6 Testing Strategy for HKT-2

Create tests in `test-kind-inference.rkt` (~15 tests):

1. **Basic kind inference** (5 tests):
   - `{C} [Seqable C]` infers `C : Type -> Type`
   - `{A} [Eq A]` keeps `A : Type` (Eq has `{A : Type}`)
   - `{F} [Foldable F]` infers `F : Type -> Type`
   - `{C} [Keyed C]` infers `C : Type -> Type -> Type`
   - `{A B C} [Seqable C] [Eq A]` infers only `C : Type -> Type`

2. **Multi-constraint consistency** (4 tests):
   - `{C} [Seqable C] [Buildable C]` — both agree on `Type -> Type`
   - `{X} [Seqable X] [Eq X]` — kind conflict error
   - `{C} [Collection C]` — bundle expands to 3 constraints, all agree

3. **Explicit annotation interaction** (3 tests):
   - `{C : Type -> Type} [Seqable C]` — explicit matches inferred, OK
   - `{C : Type} [Seqable C]` — explicit conflicts, error
   - `{A : Type} [Eq A]` — explicit matches, OK

4. **End-to-end with elaboration** (3 tests):
   - Function with `{C} [Seqable C]` elaborates correctly with `C` at kind `Type -> Type`
   - Kind-inferred `C` works in `[C A]` position in the type signature

**Estimated**: 15 tests, ~120 lines

---

## 5. Phase HKT-3: Convert Traits, Instances, and `impl` Macro Extensions

### 5.1 Converting `deftype` Traits to `trait`

Two HKT traits are currently raw `deftype`, not `trait`:

**Foldable** (`foldable-trait.prologos`):
```prologos
;; CURRENT (deftype):
deftype [Foldable $F] [Pi [A :0 <Type>] [Pi [B :0 <Type>] [-> [-> A [-> B B]] [-> B [-> [$F A] B]]]]]

;; NEW (trait):
trait Foldable {F : Type -> Type}
  fold : [Pi [A :0 <Type>] [Pi [B :0 <Type>] [-> [-> A [-> B B]] [-> B [-> [F A] B]]]]]
```

Note: The trait method type uses `F` (bare param) where the deftype used `$F` (pattern var). The `trait` macro handles this conversion automatically via `pvarify`.

**Functor** (if `functor-trait.prologos` exists as deftype):
```prologos
;; CURRENT:
deftype [Functor $F] [Pi [A :0 <Type>] [Pi [B :0 <Type>] [-> [-> A B] [-> [$F A] [$F B]]]]]

;; NEW:
trait Functor {F : Type -> Type}
  fmap : [Pi [A :0 <Type>] [Pi [B :0 <Type>] [-> [-> A B] [-> [F A] [F B]]]]]
```

**Migration strategy**:
1. Replace the `deftype` form with `trait` form in the `.prologos` file
2. The `trait` macro generates the same `deftype` expansion plus accessor defs
3. The accessor `Foldable-fold` is generated automatically
4. Existing code using `Foldable` as a type should continue working (same expansion)
5. `impl Foldable List` becomes possible (trait is registered in trait registry)

### 5.2 Extending `process-impl` for Type Constructors

The `process-impl` function (macros.rkt line 3509) needs to recognize type constructor arguments. Currently, when it encounters `impl Seqable PVec`, it treats `PVec` as a bare symbol type argument and generates key `"PVec--Seqable"`.

**The key insight**: This already works for the key generation! The type-arg-str at line 3597-3604 converts symbols to strings. `PVec` as a symbol produces `"PVec"`, which is exactly the key we need.

**What needs to change**:

1. **Applied trait type generation** (line 3610-3616): Currently builds `(TraitName TypeArg)`. For `impl Seqable PVec`, this produces `(Seqable PVec)`. After deftype expansion, this becomes the correct Pi type. **No change needed.**

2. **Type-arg validation**: Currently, `process-monomorphic-impl` doesn't validate that the type arg has the correct kind. For HKT, we should verify that `PVec` (used with `Seqable {C : Type -> Type}`) is indeed a type constructor of kind `Type -> Type`. This is a kind-checking enhancement:

```racket
;; In process-monomorphic-impl, after parsing type-args:
;; Validate kind compatibility between type args and trait params
(define trait-params (trait-meta-params tm))
(when (= (length type-args) (length trait-params))
  (for ([ta (in-list type-args)]
        [tp (in-list trait-params)])
    (define expected-kind (cdr tp))
    ;; If the type arg is a known type constructor, check its arity against expected kind
    (when (and (symbol? ta) (hash-has-key? builtin-tycon-arity ta))
      (define actual-arity (hash-ref builtin-tycon-arity ta))
      (define expected-arity (kind->arity expected-kind))
      (unless (= actual-arity expected-arity)
        (error 'impl "impl ~a ~a: ~a has kind ~a (arity ~a), but ~a expects kind ~a (arity ~a)"
               trait-name ta ta (arity->kind-string actual-arity) actual-arity
               trait-name (datum->kind-string expected-kind) expected-arity)))))

;; Helper: count the arity of a kind datum
(define (kind->arity kind)
  (cond
    [(and (list? kind) (eq? (car kind) '->)) (+ 1 (kind->arity (caddr kind)))]
    [else 0]))
```

3. **Registration for HKT types**: The existing `register-impl!` call at line 3647 uses `impl-key` = `"PVec--Seqable"`. This is correct. The `impl-entry` stores `type-args = '(PVec)` and `dict-name = 'PVec--Seqable--dict`. **No change needed.**

### 5.3 Rewriting Manual `def` Instances to `impl`

All HKT instances currently use manual `def` forms. They must be rewritten to use `impl`:

| File | Current | New |
|------|---------|-----|
| `seqable-list.prologos` | `def List--Seqable--dict : [Seqable List] := list-to-lseq` | `impl Seqable List` / `defn to-seq [xs] list-to-lseq A xs` |
| `seqable-pvec.prologos` | `def PVec--Seqable--dict : [Seqable PVec] (fn ...)` | `impl Seqable PVec` / `defn to-seq [v] list-to-lseq A [pvec-to-list v]` |
| `seqable-set.prologos` | Similar manual def | `impl Seqable Set` / `defn to-seq [s] list-to-lseq A [set-to-list s]` |
| `seqable-lseq.prologos` | Similar manual def | `impl Seqable LSeq` / `defn to-seq [s] s` (identity) |
| `buildable-list.prologos` | Manual def | `impl Buildable List` / `defn from-seq [s] lseq-to-list s` / `defn empty nil A` |
| `buildable-pvec.prologos` | Manual def | `impl Buildable PVec` / `defn from-seq [s] pvec-from-list [lseq-to-list s]` / `defn empty pvec-empty A` |
| `buildable-set.prologos` | Manual def | `impl Buildable Set` / ... |
| `buildable-lseq.prologos` | Manual def | `impl Buildable LSeq` / `defn from-seq [s] s` / `defn empty lseq-nil A` |
| `foldable-list.prologos` | `def list-foldable foldr` | `impl Foldable List` / `defn fold [f z xs] foldr A B f z xs` |
| `foldable-pvec.prologos` | Manual def | `impl Foldable PVec` / `defn fold [f z v] foldr A B f z [pvec-to-list v]` |
| `foldable-set.prologos` | Manual def | `impl Foldable Set` / ... |
| `foldable-lseq.prologos` | Manual def | `impl Foldable LSeq` / ... |
| `functor-list.prologos` | Manual def | `impl Functor List` / `defn fmap [f xs] list-map f xs` |
| `functor-pvec.prologos` | Manual def | `impl Functor PVec` / ... |

**Important**: After rewriting, each instance is registered in the impl registry. The old `def List--Seqable--dict` name is STILL generated by `process-monomorphic-impl` (as the `dict-name`), so existing code that references these names continues to work.

**Backward compatibility**: Code that calls `List--Seqable--dict` directly still works because the `impl` macro generates a `def` with the same naming convention.

### 5.4 Map Partial Application via `impl`

Map requires partial application because it has kind `Type -> Type -> Type`:

```prologos
;; In macros.rkt, this parses as a parametric impl:
;; type-arg = (Map K), which is a compound type
;; K is a pattern variable (not a known type)
impl Seqable (Map K) where (Hashable K)
  defn to-seq [m] map-entries-to-lseq m
```

The existing `process-parametric-impl` (macros.rkt line 3657) already handles compound type arguments like `(Map K)`:

1. `collect-pattern-var-candidates` extracts `K` from `(Map K)` as a candidate
2. `K` is not a `known-name?`, so it becomes a pattern variable
3. `type-arg-str` generates `"Map-K"` (or similar)
4. The parametric impl entry is registered with pattern `(Map K)` and pvar `K`

**What may need adjustment**: The `type-arg-str` for compound types currently joins with `-`. For `(Map K)` this produces `"Map-K"`. The dict-name becomes `"Map-K--Seqable--dict"`. This is fine for internal naming.

**For resolution**: When `try-parametric-resolve('Seqable, [(expr-app (expr-tycon 'Map) (expr-Int))])` is called:
1. The type arg is `(expr-app (expr-tycon 'Map) (expr-Int))`
2. `match-type-pattern` decomposes this against pattern `(Map K)`
3. `match-one` on `(expr-app (expr-tycon 'Map) (expr-Int))` vs `(Map K)`:
   - Compound pattern `(Map K)` → decompose app: head = `(expr-tycon 'Map)`, args = `[(expr-Int)]`
   - Match head: `(expr-tycon 'Map)` vs `Map` → `match-one` with symbol `'Map` vs `expr-tycon 'Map` → **needs the new `expr-tycon` case in `match-one`** ✓ (added in Phase HKT-1)
   - Match arg: `(expr-Int)` vs `K` (pattern var) → binds `K = (expr-Int)` ✓
4. Sub-constraint `(Hashable K)` → resolves with `K = Int` → `try-monomorphic-resolve('Hashable, [(expr-Int)])` → key `"Int--Hashable"` → found ✓

### 5.5 Testing Strategy for HKT-3

Create `tests/test-hkt-impl.rkt` (~25 tests):

1. **Trait conversion** (5 tests):
   - `Foldable` as `trait` generates correct deftype expansion
   - `Foldable-fold` accessor exists and has correct type
   - `Functor` as `trait` generates correct deftype expansion
   - Existing code using `Foldable` type still compiles

2. **Monomorphic HKT impl** (8 tests):
   - `impl Seqable List` registers with key `"List--Seqable"`
   - `impl Seqable PVec` registers with key `"PVec--Seqable"`
   - `impl Foldable List` registers with key `"List--Foldable"`
   - Dict name follows convention: `PVec--Seqable--dict`
   - Dict value is correct (single-method: bare function)
   - Kind validation: `impl Seqable Int` errors (Int has kind Type, not Type -> Type)
   - All existing collection tests still pass (backward compatibility)

3. **Parametric HKT impl** (6 tests):
   - `impl Seqable (Map K) where (Hashable K)` registers correctly
   - Pattern vars extracted from `(Map K)`: `{K}`
   - Dict generated correctly with type params and sub-constraint dicts
   - Resolution of `Seqable (Map Int)` succeeds (finds parametric impl, resolves `Hashable Int`)
   - Resolution of `Seqable (Map NoHash)` fails (can't resolve `Hashable NoHash`)

4. **Instance rewrite backward compatibility** (6 tests):
   - Old name `List--Seqable--dict` still exists after `impl` rewrite
   - `List--Seqable--dict` has type `(Seqable List)` as before
   - Existing collection-ops code compiles without changes
   - All seqable/buildable/foldable trait instance tests pass

**Estimated**: 25 tests, ~200 lines

---

## 6. Phase HKT-4: Coherence and Instance Safety

### 6.1 The Coherence Problem

Coherence means that for any given type and trait, there is at most one canonical instance. Without coherence, the same expression can have different behavior depending on which instance the compiler picks — this breaks equational reasoning.

**Current state in Prologos**:
- `register-impl!` (called from `process-monomorphic-impl`) silently overwrites entries with the same key. If two modules both define `impl Eq Nat`, the second silently wins.
- `try-parametric-resolve` uses `for/or` (line 217) — first match wins, with no defined ordering.
- No orphan restrictions exist.

### 6.2 Lessons from Other Languages

**GHC Haskell**:
- **Coherence**: Guaranteed by the combination of: (a) no overlapping instances by default, (b) at most one instance per type per typeclass in scope, (c) orphan instance warnings.
- **Overlapping instances**: Opt-in via `{-# OVERLAPPING #-}`, `{-# OVERLAPPABLE #-}`, `{-# OVERLAPS #-}`. GHC uses a "most specific wins" rule: an instance is more specific if its head is a substitution instance of another's.
- **Orphan instances**: GHC warns (but doesn't error) when an instance is defined in a module that defines neither the class nor the type. Orphans can lead to incoherence because different modules might import different orphan instances.

**Rust traits**:
- **Strict coherence**: The orphan rule is enforced as an error, not a warning. You can only implement a trait for a type if either the trait or the type (or a "fundamental" type wrapping it) is defined in the current crate.
- **No overlapping impls**: Rust forbids overlapping implementations entirely (with narrow exceptions via `specialization`, still unstable).

**Scala 3 givens**:
- **Priority-based resolution**: Uses a specificity ordering — more specific givens take priority. If two givens are equally specific, it's ambiguous and errors.
- **No orphan restriction**: Any module can define givens for any type/typeclass.

**Lean 4**:
- **No coherence enforcement**: Lean doesn't enforce coherence — the user is responsible for ensuring instances don't conflict. The instance search picks the first match from the discrimination tree.
- **Priority annotations**: `@[instance, priority 100]` allows explicit priority control.

### 6.3 Prologos Coherence Rules

Based on the analysis of other languages, Prologos should implement:

| Rule | Strictness | Rationale |
|------|-----------|-----------|
| R1: No silent overwrites | Error | Prevents accidental instance replacement |
| R2: Most-specific-wins | Automatic | Follows GHC/Scala 3; natural for parametric instances |
| R3: Orphan warnings | Warning (not error) | Follows GHC; Rust's strict rule is too restrictive for Prologos's module system |
| R4: Overlap detection | Warning at registration | Follows Lean 4's approach; explicit overlap is rare in Prologos |

### 6.4 Duplicate Instance Detection

In `macros.rkt`, modify `register-impl!` (currently called from `process-monomorphic-impl`):

```racket
;; Current (macros.rkt, wherever register-impl! is defined):
(define (register-impl! key entry)
  (current-impl-registry (hash-set (current-impl-registry) key entry)))

;; NEW:
(define (register-impl! key entry)
  (define existing (hash-ref (current-impl-registry) key #f))
  (when existing
    ;; Check if it's the same definition (benign re-registration from prelude loading)
    (unless (eq? (impl-entry-dict-name existing) (impl-entry-dict-name entry))
      (error 'impl
        "Duplicate instance: ~a already registered (dict ~a), cannot re-register (dict ~a)"
        key (impl-entry-dict-name existing) (impl-entry-dict-name entry))))
  (current-impl-registry (hash-set (current-impl-registry) key entry)))
```

**Note**: We allow **benign re-registration** (same key, same dict name) because the prelude may load the same instance module multiple times. Only different dict names constitute a conflict.

### 6.5 Most-Specific-Wins Resolution

Modify `try-parametric-resolve` (trait-resolution.rkt line 215) to collect ALL matches and pick the most specific:

```racket
(define (try-parametric-resolve trait-name type-args)
  (define param-impls (lookup-param-impls trait-name))
  ;; Collect ALL matching entries with their bindings and sub-dicts
  (define matches
    (for/fold ([acc '()])
              ([pentry (in-list param-impls)])
      (define bindings (match-type-pattern type-args pentry))
      (if (not bindings)
          acc
          (let ([sub-dicts (resolve-sub-constraints
                             (param-impl-entry-where-constraints pentry)
                             bindings)])
            (if (not sub-dicts)
                acc
                (cons (list pentry bindings sub-dicts) acc))))))

  (cond
    [(null? matches) #f]
    [(= (length matches) 1)
     (apply build-parametric-dict-expr (car matches))]
    [else
     ;; Multiple matches: pick most specific (fewest pattern vars)
     (define sorted
       (sort matches <
         #:key (lambda (m)
                 (length (param-impl-entry-pattern-vars (car m))))))
     (define best (car sorted))
     (define second (cadr sorted))
     ;; If the two most specific have the same number of pattern vars, ambiguous
     (if (= (length (param-impl-entry-pattern-vars (car best)))
            (length (param-impl-entry-pattern-vars (car second))))
         ;; Ambiguity error — but for now, fall through with first match
         ;; (full ambiguity errors come in Phase HKT-7)
         (apply build-parametric-dict-expr best)
         (apply build-parametric-dict-expr best))]))
```

### 6.6 Orphan Instance Warnings

An orphan instance is one where neither the trait nor the type is defined in the current module. Detection requires tracking the "defining module" for traits and types.

**Implementation**: In `process-impl`, after generating the dict def, check:

```racket
;; Orphan check (warning only)
(define current-ns (current-namespace-name))  ;; e.g., 'prologos.core.my-module
(define trait-ns (trait-defining-module trait-name))
(define type-ns (type-defining-module (car type-args)))
(when (and trait-ns type-ns
           (not (eq? current-ns trait-ns))
           (not (eq? current-ns type-ns)))
  (displayln (format "Warning: Orphan instance 'impl ~a ~a' in module ~a\n  Neither ~a (from ~a) nor ~a (from ~a) is defined in this module."
                      trait-name (car type-args) current-ns
                      trait-name trait-ns (car type-args) type-ns)))
```

**Note**: `trait-defining-module` and `type-defining-module` require augmenting the trait registry and type metadata with module provenance. This is a minor enhancement to `register-trait!` and the type-meta system.

**Decision**: Defer orphan detection to Phase HKT-7 (error messages). For Phase HKT-4, focus on duplicate detection and most-specific-wins, which are the critical safety features.

### 6.7 Overlap Detection at Registration Time

When a new parametric impl is registered, check if it could overlap with existing entries:

```racket
;; In register-param-impl!:
(define (register-param-impl! trait-name entry)
  (define existing (lookup-param-impls trait-name))
  ;; Check for potential overlap with existing entries
  (for ([ex (in-list existing)])
    (when (could-overlap? entry ex)
      (displayln (format "Warning: Potentially overlapping instances for ~a:\n  ~a\n  ~a"
                         trait-name
                         (format-param-impl entry)
                         (format-param-impl ex)))))
  ;; Register
  (current-param-impl-registry
    (hash-update (current-param-impl-registry) trait-name
                 (lambda (lst) (cons entry lst))
                 '())))

;; Two parametric impls overlap if neither's type pattern is a strict substitution
;; instance of the other. E.g.:
;; impl Eq (List A)  — matches List of anything
;; impl Eq (List Nat) — matches List Nat specifically
;; These overlap on (List Nat), but the second is more specific.
;; They DON'T overlap if one requires more pattern vars than the other.
;;
;; Conservative check: patterns overlap if they could unify.
(define (could-overlap? e1 e2)
  (define p1 (param-impl-entry-type-pattern e1))
  (define p2 (param-impl-entry-type-pattern e2))
  ;; If patterns have different lengths, no overlap
  (and (= (length p1) (length p2))
       ;; If both are identical patterns, overlap
       ;; If one is a strict specialization, overlap (but resolved by most-specific)
       ;; Conservative: return #t if any pattern pair could match
       (patterns-could-unify? p1 p2
         (param-impl-entry-pattern-vars e1)
         (param-impl-entry-pattern-vars e2))))

(define (patterns-could-unify? p1 p2 pvars1 pvars2)
  ;; Conservative: two patterns can unify if for each position,
  ;; at least one side is a pattern variable OR they're structurally equal
  (andmap (lambda (a b)
            (or (and (symbol? a) (memq a pvars1))
                (and (symbol? b) (memq b pvars2))
                (equal? a b)))
          p1 p2))
```

### 6.8 Testing Strategy for HKT-4

Create `tests/test-coherence.rkt` (~15 tests):

1. **Duplicate detection** (4 tests):
   - Two `impl Eq Nat` in same scope → error
   - Same impl loaded twice (prelude) → benign, no error
   - `impl Seqable PVec` twice → error

2. **Most-specific-wins** (5 tests):
   - `impl Eq (List A)` and `impl Eq (List Nat)` — resolution picks `(List Nat)` for `Eq (List Nat)`
   - `impl Eq (List A)` alone — resolution works for `Eq (List Bool)` via parametric
   - Three candidates: picks the one with fewest pattern vars
   - Equal specificity (same pvar count) — currently picks first (future: ambiguity error)

3. **Overlap warnings** (3 tests):
   - `impl Eq (List A)` then `impl Eq (List Nat)` → warning emitted
   - `impl Eq (List A)` then `impl Eq (PVec A)` → no warning (different constructors)
   - `impl Eq (Map K V)` then `impl Eq (Map String V)` → warning

4. **Backward compatibility** (3 tests):
   - All existing trait instance tests pass
   - Prelude loads without duplicate errors
   - Numeric traits (Add/Sub/Mul for Int/Rat/Posit*) all register correctly

**Estimated**: 15 tests, ~130 lines

---

## 7. Phase HKT-5: Elaborator Enhancements for Clean Surface Syntax

### 7.1 Bare Method Name Resolution for Implicit Dicts

**Goal**: When a function has an implicit trait-constraint parameter (from `spec`), its methods should be available as bare names in the function body.

**Current state**: Bare method names only work when the user explicitly names a `$`-prefixed dict parameter in the `defn`:

```prologos
;; Today: explicit dict param required for bare method names
defn foo [$Eq-A x y] [eq? x y]   ;; eq? resolves via where-context
```

**Desired state**: Implicit dict params (from `spec` where-constraints) also populate the where-context:

```prologos
;; After HKT-5: implicit dict, bare method names work
spec foo {A} [Eq A] -> A -> A -> Bool
defn foo [x y] [eq? x y]   ;; eq? resolves via where-context
```

**Implementation in `insert-implicits-with-tagging`** (elaborator.rkt line 225):

After creating trait-constraint metas (lines 278-306), populate the where-context:

```racket
;; After tagging the trait constraint (inside the 'when trait?' block):
;; Populate where-context with method entries for bare name resolution
(when trait?
  (define resolved-trait-name
    (cond
      [trait-from-dom? (let-values ([(tn _) (decompose-trait-type dom)]) tn)]
      [trait-from-spec? (car (list-ref where-constraints constraint-idx))]
      [else #f]))
  (when resolved-trait-name
    (define tm (lookup-trait resolved-trait-name))
    (when tm
      ;; Create where-method-entries for each method in this trait
      ;; The type-var-names come from the spec's where-constraint
      ;; The dict-param-name is a synthetic name for the meta
      (define synthetic-dict-name
        (string->symbol
          (format "$~a-~a"
            resolved-trait-name
            (string-join
              (map (lambda (e)
                     (cond
                       [(expr-meta? e) (format "?~a" (expr-meta-id e))]
                       [(expr-fvar? e) (symbol->string (expr-fvar-name e))]
                       [else "?"]))
                   (if trait-from-spec?
                       (let ([wc (list-ref where-constraints constraint-idx)])
                         (map (lambda (tv-name i)
                                (if (< i (vector-length type-var-metas))
                                    (vector-ref type-var-metas i)
                                    (expr-hole)))
                              (cdr wc) (range (length (cdr wc)))))
                       (let-values ([(_ type-args) (decompose-trait-type dom)])
                         type-args)))
              "-"))))
      (define new-entries
        (for/list ([method (in-list (trait-meta-methods tm))])
          (where-method-entry
            (trait-method-name method)
            (string->symbol
              (string-append (symbol->string resolved-trait-name)
                             "-"
                             (symbol->string (trait-method-name method))))
            resolved-trait-name
            ;; type-var-names: these map to the type-var metas we created earlier
            (if trait-from-spec?
                (let ([wc (list-ref where-constraints constraint-idx)])
                  (cdr wc))
                (let-values ([(_ type-args) (decompose-trait-type dom)])
                  (for/list ([ta (in-list type-args)])
                    (if (expr-fvar? ta) (expr-fvar-name ta) (gensym 'tv)))))
            synthetic-dict-name)))
      ;; Push entries into where-context
      (current-where-context
        (append new-entries (current-where-context))))))
```

**Critical design issue**: The where-context mechanism at line 133-165 resolves bare method names by looking up de Bruijn indices for type vars and dict params in the current environment. For implicit dict params (metas), the "dict param" isn't in the environment as a named binder — it's a meta.

**Solution**: Instead of relying on de Bruijn lookup for implicit dicts, use the meta itself directly. When `resolve-method-from-where` encounters an implicit dict entry, it builds:

```racket
;; (app (app (fvar accessor) type-arg-meta) dict-meta)
;; where type-arg-meta and dict-meta are the metavariables from insert-implicits-with-tagging
```

This requires storing the meta expressions (not just names) in the `where-method-entry`:

```racket
;; Extended where-method-entry for implicit dict support:
(struct where-method-entry
  (method-name      ;; symbol — bare method name
   accessor-name    ;; symbol — full accessor name
   trait-name       ;; symbol — the trait
   type-var-names   ;; (listof symbol) — for explicit dicts (de Bruijn lookup)
   dict-param-name  ;; symbol — for explicit dicts (de Bruijn lookup)
   ;; NEW: direct meta references for implicit dicts
   type-arg-metas   ;; (or/c #f (listof expr?)) — meta exprs for type args
   dict-meta        ;; (or/c #f expr?) — meta expr for dict
  ) #:transparent)
```

And `resolve-method-from-where` is extended:

```racket
(define (resolve-method-from-where name env depth)
  (define ctx (current-where-context))
  (define matches
    (filter (lambda (e) (eq? (where-method-entry-method-name e) name)) ctx))
  (cond
    [(null? matches) #f]
    [(> (length matches) 1)
     (ambiguous-method-error #f
       (format "Ambiguous method '~a'" name)
       name (map where-method-entry-trait-name matches))]
    [else
     (define entry (car matches))
     (cond
       ;; Implicit dict: use stored metas directly
       [(where-method-entry-dict-meta entry)
        (define accessor (expr-fvar (where-method-entry-accessor-name entry)))
        (define with-types
          (foldl (lambda (meta acc) (expr-app acc meta))
                 accessor
                 (where-method-entry-type-arg-metas entry)))
        (expr-app with-types (where-method-entry-dict-meta entry))]
       ;; Explicit dict: existing de Bruijn lookup path
       [else
        ;; ... existing code from lines 147-165 ...
        ])]))
```

### 7.2 End-to-End HKT Trait Resolution

After Phases HKT-1 through HKT-5, the full resolution chain works:

1. User writes `spec transform {C} [Collection C] -> [A -> B] -> [C A] -> [C B]`
2. **Kind inference** (HKT-2): `C` gets kind `Type -> Type` from `Seqable` constraint
3. **Bundle expansion**: `[Collection C]` → `[Seqable C] [Buildable C] [Foldable C]`
4. **Elaboration** (HKT-5): Creates metas `?A`, `?B`, `?C`, `?seq`, `?build`, `?fold`. Populates where-context with `to-seq`, `from-seq`, `fold` as bare method names pointing to the respective metas.
5. **Type checking**: Argument `xs : PVec Int` unifies `?C A` with `PVec Int`. **Normalization** (HKT-1): `(expr-PVec Int)` → `(expr-app (expr-tycon 'PVec) Int)`. App decomposition: `?C = (expr-tycon 'PVec)`, `?A = Int`.
6. **Trait resolution**: `?seq` has type args `[(expr-tycon 'PVec)]`. `expr->impl-key-str` produces `"PVec"`. Key `"PVec--Seqable"` found. `?seq` solved.
7. **Zonk and codegen**: All metas resolved. Code is fully specialized.

### 7.3 Testing Strategy for HKT-5

Create `tests/test-bare-methods.rkt` (~20 tests):

1. **Bare method resolution with explicit dicts** (5 tests):
   - Existing `$Eq-A` dict param resolves `eq?` — regression test
   - `$Ord-A` resolves `lt?`, `le?`
   - Ambiguous method name across two dicts → error

2. **Bare method resolution with implicit dicts** (8 tests):
   - `spec foo {A} [Eq A] -> A -> A -> Bool` / `defn foo [x y] [eq? x y]` compiles
   - `spec bar {A} [Ord A] -> A -> A -> Bool` / `defn bar [x y] [lt? x y]` compiles
   - Multi-trait: `spec baz {A} [Eq A] -> [Ord A] -> A -> A -> Bool` / both `eq?` and `lt?` work
   - HKT: `spec qux {C} [Seqable C] -> [C A] -> [LSeq A]` / `to-seq` works as bare name
   - HKT multi: `spec tr {C} [Seqable C] -> [Buildable C] -> ...` / both `to-seq` and `from-seq` work
   - Bundle: `spec tr {C} [Collection C] -> ...` / all three methods work

3. **End-to-end HKT resolution** (7 tests):
   - `spec transform {C} [Seqable C] -> [Buildable C] -> [A -> B] -> [C A] -> [C B]` with `PVec Int` arg
   - Same with `List Int` arg
   - Same with `Set Int` arg
   - Same with `LSeq Int` arg
   - `Foldable` constraint with fold operation
   - `Functor` constraint with fmap operation
   - Resolution failure: no instance of `Seqable` for `Nat` → clear error

**Estimated**: 20 tests, ~180 lines

---

## 8. Phase HKT-6: Generic Operations and the Collection Bundle

### 8.1 Collection Bundle Definition

Create `lib/prologos/core/collection-bundle.prologos`:

```prologos
ns prologos.core.collection-bundle :no-prelude

require [prologos.core.seqable-trait :refer [Seqable]]
require [prologos.core.buildable-trait :refer [Buildable]]
require [prologos.core.foldable-trait :refer [Foldable]]

;; Collection bundle: expands to (Seqable C, Buildable C, Foldable C)
bundle Collection := (Seqable, Buildable, Foldable)
```

### 8.2 Generic Operation Implementations

Create `lib/prologos/core/generic-ops.prologos`:

```prologos
ns prologos.core.generic-ops :no-prelude

require [prologos.core.seqable-trait :refer [Seqable to-seq]]
require [prologos.core.buildable-trait :refer [Buildable from-seq]]
require [prologos.core.foldable-trait :refer [Foldable fold]]
require [prologos.core.collection-bundle :refer [Collection]]
require [prologos.data.lseq :refer [LSeq]]
require [prologos.data.lseq-ops :refer [lseq-map lseq-filter lseq-length lseq-append lseq-reverse]]

;; ========================================
;; Generic Collection Operations
;; ========================================
;; These operate on any Collection type via the Seq roundtrip:
;;   to-seq → LSeq transform → from-seq

;; gmap : (A -> B) -> C A -> C B
;; Map a function over any collection, preserving the collection type.
spec gmap {A B : Type} {C : Type -> Type} [Seqable C] -> [Buildable C] -> [A -> B] -> [C A] -> [C B]
defn gmap [f xs]
  from-seq [lseq-map f [to-seq xs]]

;; gfilter : (A -> Bool) -> C A -> C A
;; Filter elements of any collection, preserving the collection type.
spec gfilter {A : Type} {C : Type -> Type} [Seqable C] -> [Buildable C] -> [A -> Bool] -> [C A] -> [C A]
defn gfilter [pred xs]
  from-seq [lseq-filter pred [to-seq xs]]

;; gfold : (B -> A -> B) -> B -> C A -> B
;; Left fold over any foldable collection.
spec gfold {A B : Type} {C : Type -> Type} [Foldable C] -> [A -> B -> B] -> B -> [C A] -> B
defn gfold [f z xs]
  fold f z xs

;; glength : C A -> Nat
;; Length of any sequenceable collection.
spec glength {A : Type} {C : Type -> Type} [Seqable C] -> [C A] -> Nat
defn glength [xs]
  lseq-length [to-seq xs]

;; greverse : C A -> C A
;; Reverse any collection (preserving type).
spec greverse {A : Type} {C : Type -> Type} [Seqable C] -> [Buildable C] -> [C A] -> [C A]
defn greverse [xs]
  from-seq [lseq-reverse [to-seq xs]]

;; gconcat : C A -> C A -> C A
;; Concatenate two collections of the same type.
spec gconcat {A : Type} {C : Type -> Type} [Seqable C] -> [Buildable C] -> [C A] -> [C A] -> [C A]
defn gconcat [xs ys]
  from-seq [lseq-append [to-seq xs] [to-seq ys]]

;; gany? : (A -> Bool) -> C A -> Bool
;; True if any element satisfies the predicate.
spec gany? {A : Type} {C : Type -> Type} [Foldable C] -> [A -> Bool] -> [C A] -> Bool
defn gany? [pred xs]
  fold [fn a acc [if [pred a] true acc]] false xs

;; gall? : (A -> Bool) -> C A -> Bool
;; True if all elements satisfy the predicate.
spec gall? {A : Type} {C : Type -> Type} [Foldable C] -> [A -> Bool] -> [C A] -> Bool
defn gall? [pred xs]
  fold [fn a acc [if [pred a] acc false]] true xs

;; gto-list : C A -> List A
;; Convert any sequenceable collection to a List.
spec gto-list {A : Type} {C : Type -> Type} [Seqable C] -> [C A] -> [List A]
defn gto-list [xs]
  lseq-to-list [to-seq xs]
```

### 8.3 Map-Specific Instances via Partial Application

Create `lib/prologos/core/seqable-map.prologos`:

```prologos
ns prologos.core.seqable-map :no-prelude

require [prologos.core.seqable-trait :refer [Seqable]]
require [prologos.data.map :refer [Map map-to-list]]
require [prologos.data.lseq :refer [LSeq list-to-lseq]]
require [prologos.data.pair :refer [Pair]]

;; Seqable instance for (Map K), producing LSeq (Pair K V)
;; The element type of the sequence is Pair K V.
impl Seqable (Map K) where (Hashable K)
  defn to-seq [m] list-to-lseq [map-to-list m]
```

**Note**: This requires that `map-to-list` returns `List (Pair K V)` and `list-to-lseq` converts it to `LSeq (Pair K V)`. The existing `map-ops.prologos` already has `map-keys-list` and `map-vals-list` — we need to add or verify `map-to-list` which returns key-value pairs.

### 8.4 Prelude Integration

In `namespace.rkt`, add to the prelude requires list:

```racket
;; Collection bundle + generic ops
(require [prologos.core.collection-bundle :refer-all])
(require [prologos.core.generic-ops :refer [gmap gfilter gfold glength
                                             greverse gconcat gany? gall?
                                             gto-list]])
```

### 8.5 Testing Strategy for HKT-6

Create `tests/test-generic-ops.rkt` (~30 tests):

1. **gmap** (6 tests):
   - `gmap inc @[1 2 3]` = `@[2 3 4]` (PVec)
   - `gmap inc '[1 2 3]` = `'[2 3 4]` (List)
   - `gmap inc ~[1 2 3]` = `~[2 3 4]` (LSeq)
   - `gmap inc #{1 2 3}` produces a Set (order may vary)
   - `gmap show {:x 1 :y 2}` — Map with partial application (if Map Seqable is done)
   - `gmap` preserves collection type (PVec in → PVec out)

2. **gfilter** (4 tests):
   - `gfilter even? @[1 2 3 4]` = `@[2 4]`
   - `gfilter even? '[1 2 3 4]` = `'[2 4]`
   - `gfilter` preserves collection type

3. **gfold** (4 tests):
   - `gfold add 0 '[1 2 3]` = `6`
   - `gfold add 0 @[1 2 3]` = `6`
   - `gfold` on empty collection = initial value

4. **glength** (4 tests):
   - `glength @[1 2 3]` = `3`
   - `glength '[]` = `0`
   - `glength #{1 2 3}` = `3`

5. **greverse, gconcat** (4 tests):
   - `greverse '[1 2 3]` = `'[3 2 1]`
   - `gconcat '[1 2] '[3 4]` = `'[1 2 3 4]`
   - `gconcat @[1 2] @[3 4]` = `@[1 2 3 4]`

6. **gany?, gall?** (4 tests):
   - `gany? even? '[1 3 5]` = `false`
   - `gany? even? '[1 2 3]` = `true`
   - `gall? even? '[2 4 6]` = `true`
   - `gall? even? '[2 3 4]` = `false`

7. **Collection bundle** (4 tests):
   - `spec foo [Collection C] -> ...` expands correctly
   - `spec foo {C} [Collection C] -> ...` with kind inference
   - Generic function using `Collection` bundle works with PVec, List, Set, LSeq

**Estimated**: 30 tests, ~250 lines

---

## 9. Phase HKT-7: Error Messages

### 9.1 Error Taxonomy

Four distinct error cases for HKT dispatch:

**Case 1: No instance exists**
```
Error: No instance of Seqable for MyCustomType
  The function 'gmap' requires (Seqable MyCustomType) but no matching impl was found.
  Available instances: Seqable List, Seqable PVec, Seqable Set, Seqable LSeq
  Hint: Define 'impl Seqable MyCustomType' with a 'to-seq' method.
```

**Case 2: Kind mismatch**
```
Error: Kind mismatch in constraint (Seqable Int)
  Seqable expects a type constructor of kind 'Type -> Type',
  but Int has kind 'Type'.
  Hint: Seqable works with collection types like List, PVec, Set, not ground types.
```

**Case 3: Ambiguous instances**
```
Error: Ambiguous instances for Eq (Option Nat)
  Candidate 1: impl Eq (Option A) where (Eq A)  [parametric]
  Candidate 2: impl Eq (Option Nat)              [monomorphic]
  Both match equally. Use a more specific type annotation to disambiguate.
```

**Case 4: Instance not in scope** (deferred — requires module tracking)
```
Error: No instance of Seqable for PVec
  An instance exists in prologos.core.seqable-pvec but is not imported.
  Hint: Add 'require [prologos.core.seqable-pvec :refer []]' to load it.
```

### 9.2 Implementation Details

Extend `check-unresolved-trait-constraints` (trait-resolution.rkt line 250-268):

```racket
(define (check-unresolved-trait-constraints)
  (for/list ([(meta-id tc-info) (in-hash (current-trait-constraint-map))]
             #:when (not (meta-solved? meta-id))
             #:when (andmap ground-expr?
                           (map zonk (trait-constraint-info-type-arg-exprs tc-info))))
    (define trait-name (trait-constraint-info-trait-name tc-info))
    (define type-args (map zonk (trait-constraint-info-type-arg-exprs tc-info)))
    (define type-args-str
      (string-join (map expr->impl-key-str type-args) " "))

    ;; Recover source location
    (define minfo (meta-lookup meta-id))
    (define src (and minfo (meta-info-source minfo)))
    (define loc
      (if (and src (meta-source-info? src))
          (meta-source-info-loc src)
          srcloc-unknown))

    ;; NEW: Enhanced error with available instances and kind check
    (define available-instances (collect-available-instances trait-name))
    (define kind-mismatch? (detect-kind-mismatch trait-name type-args))

    (define message
      (cond
        ;; Kind mismatch
        [kind-mismatch?
         (format "Kind mismatch in constraint (~a ~a)\n  ~a expects a type constructor of kind '~a',\n  but ~a has kind '~a'."
                 trait-name type-args-str
                 trait-name (trait-expected-kind-str trait-name)
                 type-args-str (actual-kind-str (car type-args)))]
        ;; No instance
        [else
         (define avail-str
           (if (null? available-instances)
               ""
               (format "\n  Available instances: ~a"
                       (string-join (map (lambda (i) (format "~a ~a" trait-name i))
                                        available-instances) ", "))))
         (format "No instance of ~a for ~a~a\n  Hint: Define 'impl ~a ~a' with the required method(s)."
                 trait-name type-args-str avail-str
                 trait-name type-args-str)]))

    (no-instance-error loc message trait-name type-args-str)))

;; Collect all registered instances for a trait
(define (collect-available-instances trait-name)
  (define mono-keys
    (for/list ([(k v) (in-hash (current-impl-registry))]
               #:when (let ([ks (symbol->string k)])
                        (string-suffix? ks (string-append "--" (symbol->string trait-name)))))
      ;; Extract the type part from key "TypeArg--TraitName"
      (define ks (symbol->string k))
      (define suffix-len (+ 2 (string-length (symbol->string trait-name))))
      (substring ks 0 (- (string-length ks) suffix-len))))
  (define param-patterns
    (for/list ([pe (in-list (lookup-param-impls trait-name))])
      (format "~a" (param-impl-entry-type-pattern pe))))
  (append mono-keys param-patterns))

;; Detect kind mismatch
(define (detect-kind-mismatch trait-name type-args)
  (define tm (lookup-trait trait-name))
  (and tm
       (not (null? (trait-meta-params tm)))
       (let ([expected-kind (cdr (car (trait-meta-params tm)))])
         ;; If expected kind is (-> Type Type) but type arg is a ground type, mismatch
         (and (list? expected-kind)
              (eq? (car expected-kind) '->)
              (not (null? type-args))
              (let ([ta (car type-args)])
                (and (not (expr-tycon? ta))
                     (not (expr-fvar? ta))
                     (not (expr-app? ta))
                     ;; It's a ground type like expr-Int, expr-Nat, etc.
                     #t))))))
```

### 9.3 Testing Strategy for HKT-7

Create `tests/test-hkt-errors.rkt` (~12 tests):

1. **No instance** (3 tests):
   - `gmap inc 42` → "No instance of Seqable for Int"
   - Missing instance for user-defined type
   - Error lists available instances

2. **Kind mismatch** (3 tests):
   - `[Seqable Int]` → kind mismatch error
   - `[Seqable Nat]` → kind mismatch error
   - `[Seqable Bool]` → kind mismatch error

3. **Existing errors still work** (3 tests):
   - `[Eq MyType]` without impl → "No instance of Eq for MyType"
   - `[Add NoType]` → standard no-instance error
   - Error includes source location

4. **Clean error formatting** (3 tests):
   - Error messages are readable
   - Available instances listed correctly
   - Hints are actionable

**Estimated**: 12 tests, ~100 lines

---

## 10. Phase HKT-8: Specialization Framework

### 10.1 The Specialization Problem

Generic operations via the Seq roundtrip (`to-seq → transform → from-seq`) incur overhead: each conversion allocates intermediate `LSeq` cells. For List, this overhead is minimal (List→LSeq is O(1) lazy). For PVec and Set, it involves converting to List first, then to LSeq — an O(n) materialization.

Specialization eliminates this overhead by rewriting `gmap f @[1 2 3]` to `pvec-map f @[1 2 3]` when the type constructor is statically known.

### 10.2 Lessons from GHC's RULES and SPECIALISE

**GHC Rewrite Rules** (`{-# RULES #-}`):
- Rules are term-level rewrite rules: `{-# RULES "map/map" forall f g xs. map f (map g xs) = map (f . g) xs #-}`
- Rules fire during the simplifier, after inlining but interleaved with other optimizations
- Phase control: `{-# RULES "rule" [2] forall ... #-}` means "fire in phase 2 and later"
- GHC's simplifier runs multiple iterations; rules can fire in any iteration
- Rules must be manually verified for correctness (GHC doesn't check termination or confluence)
- Key use case: **foldr/build fusion** — `foldr k z (build g) = g k z` eliminates intermediate lists

**GHC SPECIALISE pragma**:
- `{-# SPECIALISE foo :: Int -> Int -> Int #-}` generates a monomorphic copy of `foo` with `Int` dictionaries inlined
- Auto-specialization: GHC auto-specializes at call sites when the type args are known, for functions marked `INLINEABLE`
- Cross-module: requires `INLINEABLE` or `SPECIALISE` pragmas in the defining module; the unfolding is exported in the `.hi` interface file

**Stream fusion** (Coutts, Leshchinskiy, Stewart 2007):
- Replaces `foldr/build` with `stream/unstream` — a stream is `data Stream a = forall s. Stream (s -> Step a s) s`
- More robust than `foldr/build`: handles `zip`, `filter`, `concatMap` that `foldr/build` cannot fuse
- Key rewrite rule: `stream (unstream s) = s` (stream/unstream cancellation)
- GHC's `vector` library uses stream fusion for unboxed vectors

### 10.3 Prologos Specialization Design

Prologos's specialization uses a registry-based approach, simpler than GHC's RULES:

```
Specialization = (generic-fn-name, type-constructor) → specialized-fn-name
```

When the compiler resolves trait constraints and the type constructor is statically known, it checks the specialization registry. If a match is found, the call is rewritten.

### 10.4 The `specialize` Macro

Surface syntax:

```prologos
specialize gmap for List
  defn gmap [f xs] list-map f xs

specialize gmap for PVec
  defn gmap [f xs] pvec-map f xs

specialize gmap for Set
  defn gmap [f xs] set-map f xs
```

The `specialize` macro generates:

1. A specialized function definition (scoped name like `gmap--List--specialized`)
2. A registry entry: `(gmap, List) → gmap--List--specialized`

```racket
;; In macros.rkt:
(define current-specialization-registry (make-parameter (hasheq)))
;; key: (cons 'gmap 'List) → value: 'gmap--List--specialized

(define (process-specialize datum)
  ;; (specialize fn-name for TypeCon (defn ...))
  (define fn-name (cadr datum))
  (define type-con (cadddr datum))  ;; after 'for
  (define method-defns (cddddr datum))

  ;; Generate specialized function
  (define spec-name
    (string->symbol
      (string-append (symbol->string fn-name) "--"
                     (symbol->string type-con) "--specialized")))

  ;; Rewrite defn with specialized name
  (define spec-defn
    `(defn ,spec-name ,@(cddr (car method-defns))))

  ;; Register
  (define key (cons fn-name type-con))
  (current-specialization-registry
    (hash-set (current-specialization-registry) key spec-name))

  (list spec-defn))
```

### 10.5 Call-Site Rewriting During Resolution

After `resolve-trait-constraints!` solves all trait metas, check for specializations:

```racket
;; In a new function called after resolve-trait-constraints!:
(define (apply-specializations!)
  ;; Walk the expression tree looking for calls to generic functions
  ;; where the type constructor argument is known.
  ;; This is a post-resolution optimization pass.
  ;;
  ;; Implementation: during zonking, when we encounter:
  ;;   (app (app (app (app (app (fvar 'gmap) (tycon 'PVec)) seq-dict) build-dict) f) xs)
  ;; and (gmap, PVec) is in the specialization registry → rewrite to:
  ;;   (app (app (fvar 'gmap--PVec--specialized) f) xs)
  ;;
  ;; This is a targeted rewrite, not a general-purpose term rewriting engine.
  (void))  ;; Placeholder — full implementation is a post-HKT optimization
```

**Decision**: Phase HKT-8 implements the `specialize` macro and registry only. The call-site rewriting pass is deferred to a performance optimization sprint, since the generic Seq-roundtrip path is correct and the Tier 2 ops (`pvec-map`, `set-filter`) provide zero-overhead alternatives.

### 10.6 Phase Interaction: Specialization vs Inlining

Specialization should fire **after** trait resolution but **before** inlining. If the specialization is applied first, then inlining can further optimize the specialized call. This is similar to GHC's phase control:

```
Phase 1: Type check + trait resolution
Phase 2: Specialization rewriting (if applicable)
Phase 3: Inlining and simplification (future)
```

### 10.7 Stream Fusion Integration

The pipe operator `|>` already has fusion for List-specific ops. Extending to generic ops:

```prologos
;; Current (fuses for List):
|> xs list-map f |> list-filter p |> list-fold add 0

;; Future (fuses for generic):
|> xs gmap f |> gfilter p |> gfold add 0
```

For this to fuse, the pipe optimizer needs to recognize `gmap`/`gfilter`/`gfold` and apply the stream fusion rules:

```
gmap f (gmap g xs) = gmap (f . g) xs           ;; map/map fusion
gfilter p (gfilter q xs) = gfilter (and p q) xs ;; filter/filter fusion
gfold f z (gmap g xs) = gfold (f . g) z xs      ;; fold/map fusion
```

**Decision**: Stream fusion for generic ops is a future optimization. The framework is designed to support it (rewrite rules keyed by function pairs), but implementation is deferred.

### 10.8 Testing Strategy for HKT-8

Create `tests/test-specialization.rkt` (~10 tests):

1. **Macro parsing** (3 tests):
   - `specialize gmap for List` generates `gmap--List--specialized`
   - Registry entry created with correct key
   - Specialized function compiles

2. **Registry lookup** (3 tests):
   - `(gmap, List)` → `gmap--List--specialized`
   - `(gmap, PVec)` → `gmap--PVec--specialized`
   - `(gmap, UnknownType)` → `#f`

3. **Correctness** (4 tests):
   - Specialized `gmap` for List produces same result as generic `gmap`
   - Specialized `gmap` for PVec produces same result as generic `gmap`
   - Specialization of `gfilter`, `gfold`

**Estimated**: 10 tests, ~80 lines

---

## 11. Phase HKT-9: Constraint Inference from Usage

### 11.1 The Constraint Inference Problem

When a user writes:

```prologos
defn transform [f xs]
  from-seq [lseq-map f [to-seq xs]]
```

Without a `spec`, the compiler should infer:
- `to-seq` requires `Seqable C` where `xs : C A`
- `from-seq` requires `Buildable C`
- `f : A -> B` from `lseq-map`
- Result type: `{A B : Type} {C : Type -> Type} [Seqable C] -> [Buildable C] -> (A -> B) -> C A -> C B`

### 11.2 Lessons from GHC and Lean 4

**GHC**: Does NOT infer constraints from usage. Haskell requires all constraints to be declared in the type signature (or inferred via `let` bindings with the monomorphism restriction). The closest mechanism is GHC's constraint simplification, which can figure out that `Num a, Eq a` can be simplified to `Num a` (since `Num` implies `Eq`).

**Lean 4**: Also does NOT infer typeclass constraints from usage. Type signatures must declare all constraints explicitly. However, Lean's `auto_bound_implicit_local` pragma can infer implicit type parameters from usage, and the elaborator propagates constraints through unification.

**Scala 3**: Context bounds (`[F[_]: Functor]`) must be declared explicitly.

**The consensus**: No mainstream language infers typeclass constraints from method usage. All require explicit declaration. This validates Prologos's decision to support explicit `spec` declarations and defer constraint inference.

### 11.3 Algorithm: Method-Triggered Constraint Generation

Despite the consensus, Prologos could implement constraint inference as an optional feature for concise definitions:

```
Algorithm: Method-Triggered Constraint Generation

Input: Function body containing bare method names
Output: Set of inferred trait constraints

1. During elaboration, when a bare name `to-seq` is encountered:
   a. Check the current where-context → not found
   b. Search the trait registry for a method named `to-seq`
   c. Find: Seqable has method `to-seq`
   d. The containing trait has parameter {C : Type -> Type}
   e. Create a fresh type meta ?C with kind Type -> Type
   f. Create a fresh dict meta ?dict with type (Seqable ?C)
   g. Register trait constraint: (?dict, Seqable, [?C])
   h. Add where-context entry: to-seq → Seqable-to-seq ?C ?dict
   i. Resolve `to-seq` to (app (app (fvar Seqable-to-seq) ?C) ?dict)
   j. Continue elaboration — ?C will be solved via unification

2. After type checking, resolve-trait-constraints! solves the generated constraints.

3. The inferred constraints are collected and added to the function's type.
```

### 11.4 Ambiguity Resolution

**Problem**: What if two traits have a method with the same name?

```prologos
trait Seqable {C : Type -> Type}
  to-seq : C A -> LSeq A

trait MyTrait {T : Type}
  to-seq : T -> String    ;; name collision!
```

**Resolution strategies**:
1. **Error on ambiguity**: If multiple traits have the same method name, error and require `spec`.
2. **Context-based disambiguation**: Use the argument types to disambiguate. If `xs : PVec Int`, then `to-seq xs` must be `Seqable` (since `PVec` has kind `Type -> Type`), not `MyTrait` (which expects kind `Type`).
3. **Qualification**: Require `Seqable/to-seq` or `MyTrait/to-seq`.

**Decision**: Use strategy 1 (error on ambiguity) with fallback to strategy 3 (qualification). This is the safest approach and avoids complex type-directed disambiguation.

### 11.5 Implementation Plan

1. **Method registry**: Augment the trait registry with a reverse index: method-name → list of (trait-name, method-index) pairs. Currently, `lookup-trait` returns `trait-meta` which contains methods. Add a global `method-name->traits` hash.

2. **Elaborator hook**: In the `elaborate` function, when `resolve-method-from-where` returns `#f` (method not in where-context) and the name is in the method registry, trigger constraint generation.

3. **Kind propagation**: When creating the type meta for the inferred constraint, propagate the kind from the trait parameter.

4. **Constraint collection**: After elaboration, collect all auto-generated constraints and attach them to the function's type. This is needed for cross-module usage — the calling module needs to know the constraints.

5. **Optional feature flag**: Gate constraint inference behind a flag (e.g., `:infer-constraints`) so it doesn't affect existing behavior.

```racket
;; In elaborator.rkt, extend the name resolution fallback:
(define (elaborate-var name env depth loc)
  ;; ... existing code ...
  ;; After checking env and global-env, before erroring:
  (define where-result (resolve-method-from-where name env depth))
  (cond
    [where-result where-result]
    ;; NEW: try method-triggered constraint generation
    [(and (current-infer-constraints-mode?)
          (hash-has-key? (method-name->traits-registry) name))
     (generate-constraint-from-method name env depth loc)]
    [else
     ;; ... existing error handling ...
     ]))
```

### 11.6 Testing Strategy for HKT-9

Create `tests/test-constraint-inference.rkt` (~15 tests):

1. **Basic inference** (5 tests):
   - `defn f [xs] [to-seq xs]` infers `[Seqable C]`
   - `defn f [xs] [from-seq [to-seq xs]]` infers `[Seqable C] [Buildable C]`
   - `defn f [f xs] [from-seq [lseq-map f [to-seq xs]]]` infers full type

2. **Ambiguity** (3 tests):
   - Two traits with same method name → error
   - Qualification resolves ambiguity: `Seqable/to-seq`

3. **Kind propagation** (3 tests):
   - Inferred constraint propagates correct kind to type meta
   - Kind mismatch in inferred constraint → error

4. **Interaction with explicit spec** (4 tests):
   - Explicit spec + constraint inference should agree
   - Explicit spec with missing constraint + inference fills it in
   - Feature flag off → no inference, bare method names error

**Estimated**: 15 tests, ~120 lines

---

## 12. Future Work: Deriving Mechanism

### 12.1 The Deriving Problem

For user-defined inductive types, manually implementing `Functor`, `Foldable`, `Eq`, etc. is boilerplate. A `deriving` mechanism would auto-generate these instances.

### 12.2 Derivable Traits and Structural Recursion

| Trait | Derivation Strategy |
|-------|-------------------|
| Eq | Structural equality: compare constructor tags, recursively compare fields |
| Ord | Lexicographic ordering of constructors and fields |
| Functor | Map over the type parameter in positive position |
| Foldable | Fold over the type parameter, accumulating results |
| Show/Display | Pretty-print constructors and fields |

**Functor derivation** requires tracking the type parameter's position:
```prologos
data Tree {A}
  leaf : A -> Tree A                  ;; A in positive position
  node : Tree A -> Tree A -> Tree A   ;; A in positive position (via Tree)

;; Derived:
impl Functor Tree
  defn fmap [f t]
    match t
      | leaf a    -> leaf [f a]
      | node l r  -> node [fmap f l] [fmap f r]
```

**Negative position detection**: If `A` appears in a function argument position (e.g., `Cont A = (A -> Bool) -> Bool`), `Functor` cannot be derived. The derivation algorithm must detect this and error.

### 12.3 Design Sketch

```prologos
;; Surface syntax:
data Tree {A}
  leaf : A -> Tree A
  node : Tree A -> Tree A -> Tree A
  deriving (Eq, Functor, Foldable)

;; The 'deriving' clause triggers:
;; 1. For each trait in the deriving list:
;;    a. Look up the trait's derivation generator (registered with the trait)
;;    b. Analyze the data type's constructors
;;    c. Generate an impl form
;;    d. Process the generated impl
```

**Implementation requires**:
1. A derivation generator registry: `trait-name → (data-type-info → impl-datum)`
2. Data type constructor analysis: extract constructor names, field types, identify type parameter positions
3. Position polarity analysis: track whether the type parameter appears in positive or negative position

**Decision**: Deriving is a substantial feature (estimated ~500 lines) that depends on HKT infra being stable. It should be implemented after HKT Phases 1-7 are complete and validated.

---

## 13. Performance Analysis and Benchmarking

### 13.1 Dictionary Passing Overhead Model

Dictionary passing adds a constant overhead per polymorphic call:

```
Extra arguments per call:
  - Type parameters (erased at runtime via QTT): 0 cost
  - Dict params (:mw): 1 pointer per trait constraint
  - For (Seqable C, Buildable C, Foldable C): 3 extra args

Function call overhead (Racket):
  - Each extra arg: ~2ns (register load + push)
  - 3 dict args: ~6ns per call
  - Relative to a typical O(n) collection operation: negligible
```

### 13.2 The Seq Roundtrip Cost

```
gmap f xs (where xs : PVec Int, 1000 elements):

Path 1: Direct (pvec-map)
  - pvec-to-list: O(n) — traverse RRB tree, build list
  - list-map f: O(n) — map over list
  - pvec-from-list: O(n) — build new RRB tree
  Total: 3n allocations, ~3x memory

Path 2: Seq roundtrip (gmap)
  - to-seq (Seqable PVec): pvec-to-list → list-to-lseq: O(n) + O(1)
  - lseq-map f: O(1) (lazy — creates thunked cells)
  - from-seq (Buildable PVec): lseq-to-list → pvec-from-list: O(n) + O(n)
  Total: 3n allocations + n thunk allocations, ~4x memory

Overhead: ~33% more allocations vs direct path.
```

For List, the overhead is minimal:
```
gmap f xs (where xs : List Int, 1000 elements):

Path 1: Direct (list-map)
  - list-map f: O(n) — single pass
  Total: n allocations

Path 2: Seq roundtrip (gmap)
  - to-seq (list-to-lseq): O(1) (lazy conversion)
  - lseq-map f: O(1) (lazy)
  - from-seq (lseq-to-list): O(n) (forces all thunks)
  Total: n allocations + n thunk allocations, ~2x memory

Overhead: ~2x memory (thunk cells).
```

### 13.3 Benchmark Plan

Create `tests/bench-generic-ops.rkt`:

```racket
;; Benchmark methodology:
;; 1. Warm up: run each operation 100 times, discard
;; 2. Measure: run 1000 times, record total time
;; 3. Report: median, mean, stddev, relative overhead

;; Benchmarks:
;; 1. gmap vs list-map on List (1000 elements) — baseline
;; 2. gmap vs pvec-map on PVec (1000 elements) — overhead
;; 3. gmap vs set-map on Set (1000 elements) — overhead
;; 4. gfilter vs list-filter on List — baseline
;; 5. gfold vs foldr on List — baseline
;; 6. Chained operations: gmap f |> gfilter p |> gfold add 0
;;    vs list-map f |> list-filter p |> list-fold add 0

;; Expected results:
;; - List: <2x overhead (lazy conversion is cheap)
;; - PVec: 2-3x overhead (pvec-to-list + list-to-lseq materialization)
;; - Set: 2-3x overhead (set-to-list + list-to-lseq materialization)
;; - Chained: closer to 1x for List (LSeq fusion), 3-4x for PVec/Set
```

---

## 14. Dependency Graph and Critical Path

```
HKT-1: expr-tycon + normalization
  │
  ├── HKT-2: Kind inference from constraints
  │     │
  │     └── HKT-3: Convert traits + impl extensions
  │           │
  │           ├── HKT-4: Coherence rules
  │           │
  │           └── HKT-5: Elaborator enhancements (bare method names)
  │                 │
  │                 └── HKT-6: Generic ops + Collection bundle
  │                       │
  │                       ├── HKT-7: Error messages
  │                       │
  │                       └── HKT-8: Specialization framework
  │
  └── HKT-9: Constraint inference (independent, can start after HKT-5)
```

**Critical path**: HKT-1 → HKT-2 → HKT-3 → HKT-5 → HKT-6

**Parallelizable**:
- HKT-4 (coherence) can run in parallel with HKT-5 (after HKT-3)
- HKT-7 (errors) can run in parallel with HKT-8 (after HKT-6)
- HKT-9 (constraint inference) can run independently after HKT-5

---

## 15. Summary Table

| Phase | Goal | Files Modified | Files Created | Tests | Lines | Depends On |
|-------|------|---------------|--------------|-------|-------|------------|
| HKT-1 | `expr-tycon` + normalization | syntax, substitution, zonk, typing-core, qtt, reduction, pretty-print, unify, trait-resolution (9 files) | test-tycon.rkt | ~20 | ~200 | — |
| HKT-2 | Kind inference | macros.rkt | test-kind-inference.rkt | ~15 | ~120 | HKT-1 |
| HKT-3 | Trait conversion + impl extensions | macros.rkt, ~14 .prologos files | test-hkt-impl.rkt | ~25 | ~350 | HKT-2 |
| HKT-4 | Coherence rules | macros.rkt, trait-resolution.rkt | test-coherence.rkt | ~15 | ~150 | HKT-3 |
| HKT-5 | Bare method names | elaborator.rkt | test-bare-methods.rkt | ~20 | ~250 | HKT-3 |
| HKT-6 | Generic ops + bundle | namespace.rkt | collection-bundle.prologos, generic-ops.prologos, seqable-map.prologos, test-generic-ops.rkt | ~30 | ~300 | HKT-5 |
| HKT-7 | Error messages | trait-resolution.rkt | test-hkt-errors.rkt | ~12 | ~120 | HKT-6 |
| HKT-8 | Specialization framework | macros.rkt | test-specialization.rkt | ~10 | ~100 | HKT-6 |
| HKT-9 | Constraint inference | elaborator.rkt | test-constraint-inference.rkt | ~15 | ~150 | HKT-5 |
| **Total** | | **~15 Racket files, ~14 .prologos** | **~9 test files, ~3 .prologos** | **~162** | **~1740** | |

---

## 16. References and Key Literature

### Type Constructor Representation

- **Wadler, P. and Blott, S.** (1989). "How to make ad-hoc polymorphism less ad hoc." *POPL '89*. — The foundational paper on typeclass dictionary passing.

### Kind Inference

- **Jones, M. P.** (1995). "A system of constructor classes: overloading and implicit higher-order polymorphism." *J. Functional Programming*. — Constructor classes (higher-kinded type parameters in typeclasses).
- **Vytiniotis, D., Peyton Jones, S., and Schrijvers, T.** (2011). "OutsideIn(X): Modular type inference with local assumptions." *JFP*. — GHC's constraint solver with CHR.

### Coherence

- **Bottu, G.-J., Karachalias, G., Schrijvers, T., Oliveira, B., and Wadler, P.** (2019). "Quantified Class Constraints." *Haskell Symposium*. — Extends GHC's coherence to quantified constraints.
- **Breitner, J., Eisenberg, R. A., Peyton Jones, S., and Weirich, S.** (2016). "Safe zero-cost coercions for Haskell." *JFP*. — Coherence implications of `Coercible` and `newtype` deriving.

### Specialization and Rewrite Rules

- **Peyton Jones, S., Tolmach, A., and Hoare, T.** (2001). "Playing by the rules: rewriting as a practical optimisation technique in GHC." *Haskell Workshop*. — GHC rewrite rules design.
- **Gill, A., Launchbury, J., and Peyton Jones, S. L.** (1993). "A short cut to deforestation." *FPCA '93*. — foldr/build fusion.
- **Coutts, D., Leshchinskiy, R., and Stewart, D.** (2007). "Stream Fusion: From Lists to Streams to Nothing at All." *ICFP '07*. — Stream fusion for lists and vectors.

### Lean 4 Typeclass System

- **de Moura, L. and Ullrich, S.** (2021). "The Lean 4 Theorem Prover and Programming Language." *CADE-28*. — Lean 4's typeclass system with discrimination trees.

### Scala 3 Type Constructors

- **Odersky, M. et al.** (2022). "Implementing Higher-Kinded Types in Dotty." *Scala Symposium*. — Type lambdas and HKT in Scala 3.

### Idris 2

- **Brady, E.** (2021). "Idris 2: Quantitative Type Theory in Practice." *ECOOP '21*. — Interface resolution in a dependently-typed language with QTT.
