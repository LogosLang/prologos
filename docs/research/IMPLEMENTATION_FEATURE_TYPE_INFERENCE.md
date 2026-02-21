# Implementation Feature: Type Inference for Πρόλογος

## From Fully Explicit to Effortlessly Inferred: A Phased Plan for Adding Type Inference to the Racket Prototype Without Leaking Church Encodings

---

## Table of Contents

1. [Introduction: The Problem and the Vision](#1-introduction-the-problem-and-the-vision)
   - 1.1 [What the Prototype Does Today](#11-what-the-prototype-does-today)
   - 1.2 [Where Church Encodings Leak](#12-where-church-encodings-leak)
   - 1.3 [The Vision: What Πρόλογος Should Feel Like](#13-the-vision-what-prologos-should-feel-like)
   - 1.4 [Scope of This Document](#14-scope-of-this-document)
2. [Research Foundations: Type Inference for Dependent Types](#2-research-foundations-type-inference-for-dependent-types)
   - 2.1 [Why Hindley-Milner Cannot Work Here](#21-why-hindley-milner-cannot-work-here)
   - 2.2 [Bidirectional Type Checking: The Right Foundation](#22-bidirectional-type-checking-the-right-foundation)
   - 2.3 [Elaboration with Metavariables](#23-elaboration-with-metavariables)
   - 2.4 [Pattern Unification: The Decidable Sweet Spot](#24-pattern-unification-the-decidable-sweet-spot)
   - 2.5 [Constraint Postponement and Retry](#25-constraint-postponement-and-retry)
   - 2.6 [Multiplicity Inference in QTT](#26-multiplicity-inference-in-qtt)
   - 2.7 [Session Type Inference](#27-session-type-inference)
   - 2.8 [Universe Level Inference](#28-universe-level-inference)
3. [Audit of the Current Prototype](#3-audit-of-the-current-prototype)
   - 3.1 [Architecture Overview](#31-architecture-overview)
   - 3.2 [What Already Works Well](#32-what-already-works-well)
   - 3.3 [Specific Church Encoding Leaks](#33-specific-church-encoding-leaks)
   - 3.4 [The Annotation Burden: A Catalogue](#34-the-annotation-burden-a-catalogue)
   - 3.5 [The `expr-hole` Stub: Foundation for Metavariables](#35-the-expr-hole-stub-foundation-for-metavariables)
4. [Design: The Inference Architecture](#4-design-the-inference-architecture)
   - 4.1 [The Three-Phase Elaboration Pipeline](#41-the-three-phase-elaboration-pipeline)
   - 4.2 [Metavariable Store Design](#42-metavariable-store-design)
   - 4.3 [Constraint Generation Rules](#43-constraint-generation-rules)
   - 4.4 [The Unifier: Pattern Unification with Postponement](#44-the-unifier-pattern-unification-with-postponement)
   - 4.5 [Zonking: Substituting Solutions](#45-zonking-substituting-solutions)
   - 4.6 [Native Pattern Matching: Replacing Church Folds](#46-native-pattern-matching-replacing-church-folds)
   - 4.7 [Error Recovery and Reporting](#47-error-recovery-and-reporting)
5. [Sprint 1: Metavariable Infrastructure (Week 1)](#5-sprint-1-metavariable-infrastructure-week-1)
6. [Sprint 2: Unification Engine (Weeks 2–3)](#6-sprint-2-unification-engine-weeks-23)
7. [Sprint 3: Implicit Argument Inference (Weeks 4–5)](#7-sprint-3-implicit-argument-inference-weeks-45)
8. [Sprint 4: Native Pattern Matching — Eliminating Church Folds (Weeks 6–7)](#8-sprint-4-native-pattern-matching--eliminating-church-folds-weeks-67)
9. [Sprint 5: Constraint Postponement and Dependent Unification (Weeks 8–9)](#9-sprint-5-constraint-postponement-and-dependent-unification-weeks-89)
10. [Sprint 6: Universe Level Inference (Week 10)](#10-sprint-6-universe-level-inference-week-10)
11. [Sprint 7: Multiplicity Inference for QTT (Weeks 11–12)](#11-sprint-7-multiplicity-inference-for-qtt-weeks-1112)
12. [Sprint 8: Session Type Annotation Reduction (Weeks 13–14)](#12-sprint-8-session-type-annotation-reduction-weeks-1314)
13. [Sprint 9: Error Messages for Inference Failures (Weeks 15–16)](#13-sprint-9-error-messages-for-inference-failures-weeks-1516)
14. [Sprint 10: Ergonomic Surface Syntax Polish (Weeks 17–18)](#14-sprint-10-ergonomic-surface-syntax-polish-weeks-1718)
15. [Before and After: The Complete Transformation](#15-before-and-after-the-complete-transformation)
16. [Logic Programming and Type Inference Integration](#16-logic-programming-and-type-inference-integration)
17. [Cross-Cutting Concerns and Pitfalls](#17-cross-cutting-concerns-and-pitfalls)
18. [Post-Sprint Work: Features Beyond the 18-Week Plan](#18-post-sprint-work-features-beyond-the-18-week-plan)
19. [References](#19-references)

---

## 1. Introduction: The Problem and the Vision

### 1.1 What the Prototype Does Today

The Πρόλογος Racket prototype (v0.2.0, located at `racket/prologos/`) is a working implementation of a dependently-typed language with QTT multiplicities, bidirectional type checking, Posit8 arithmetic, and a two-layer macro system. The codebase comprises approximately 6,000 lines of Racket across 20+ modules, with a PLT Redex formal specification. It successfully type-checks and evaluates programs with dependent types, length-indexed vectors, finite types, equality proofs, and quantitative usage tracking.

The prototype's type checker already uses bidirectional checking — the `infer` function synthesizes types and the `check` function verifies terms against expected types. This is the correct foundation. However, the prototype lacks **metavariable-based inference**, meaning it cannot solve for unknown types, implicit arguments, or universe levels. Every type annotation must be explicit.

### 1.2 Where Church Encodings Leak

The most severe usability problem is that the internal representation of inductive types leaks into the surface language. There are six specific leaks:

**Leak 1: Eliminators instead of pattern matching.** To define a function on natural numbers, the user must write `natrec` — the Church-style recursor — with an explicit *motive* (a function from `Nat` to `Type`):

```
;; CURRENT: Church fold leaks through natrec
(defn double [x <Nat>] <Nat>
  (natrec (the (-> Nat (Type 0)) (fn [_ <Nat>] Nat))
          zero
          (fn [_ <Nat>] (fn [r <Nat>] (inc (inc r))))
          x))
```

The user must understand that `natrec` takes a motive, a base case, a step function (with accumulator semantics), and a target. This is the Church encoding of natural number recursion — the fold operation `Nat → ∀P. P → (P → P) → P` exposed directly.

**Leak 2: Explicit type indices on constructors.** Vector operations require passing type and length arguments that should be inferred:

```
;; CURRENT: Type indices leaked
(vhead Nat zero (the (Vec Nat (inc zero))
                     (vcons Nat zero (inc zero) (vnil Nat))))
```

The user must write `Nat` and `zero` explicitly to `vhead`, `vcons`, and `vnil`. These should be inferred from context.

**Leak 3: Explicit type application for polymorphic functions.** The polymorphic identity requires passing the type argument:

```
;; CURRENT: explicit type application
(id Nat zero)    ;; must pass Nat explicitly
(id Bool true)   ;; must pass Bool explicitly
```

**Leak 4: Motive functions for boolean elimination.** `boolrec` requires an explicit motive:

```
;; CURRENT: boolrec with explicit motive
(if Nat true (inc zero) zero)
;; Expands to: (boolrec (fn [_ <Bool>] Nat) (inc zero) zero true)
```

The `if` macro hides some of this, but the motive (the `Nat` argument specifying the return type) is still user-visible.

**Leak 5: The `J` eliminator for equality.** Proof by path induction requires passing a motive function — the most complex eliminator to use:

```
;; CURRENT: J eliminator with explicit motive
(J motive base left right proof)
```

**Leak 6: Fin type constructor arguments.** The finite type constructors `fzero` and `fsuc` require explicit bound arguments that should be inferrable from the result type:

```
;; CURRENT: explicit bound on Fin constructors
(fzero n)        ;; n is the upper bound — should be inferred
(fsuc n inner)   ;; n is explicit — should be inferred from inner's type
```

The elaborator (`elaborator.rkt`, lines 326–334) processes `surf-fzero` and `surf-fsuc` with these explicit arguments. Like Vec constructors, these index arguments are fully determined by the expected type and should never appear in user code.

### 1.3 The Vision: What Πρόλογος Should Feel Like

After implementing type inference, the same programs should look like this:

```
;; AFTER: clean pattern matching, no church folds
(defn double [x] Nat
  (match x
    zero       -> zero
    (inc n)    -> (inc (inc (double n)))))

;; AFTER: type indices inferred
(vhead (vcons 1 vnil))

;; AFTER: type application inferred
(id zero)       ;; Nat inferred from zero
(id true)       ;; Bool inferred from true

;; AFTER: if just works
(if true 1 0)   ;; return type Nat inferred from branches

;; AFTER: polymorphic identity, zero annotations
(def id (fn [x] x))
;; Infers: (forall (A : Type) (-> A A))
```

The guiding principle: **simple programs require zero type annotations.** Annotations appear only when the programmer introduces genuine ambiguity (higher-rank polymorphism, non-obvious multiplicity, complex dependent types) — and even then, the compiler provides a clear, actionable error message explaining exactly what needs annotation and why.

### 1.4 Scope of This Document

This document provides an 18-week, 10-sprint implementation plan for adding type inference to the existing Racket prototype. Each sprint is 1–2 weeks and produces a working, testable increment. The plan is ordered by dependency — each sprint builds on the previous one — and is designed to be achievable by a single developer familiar with the codebase.

The plan does NOT cover: adding type inference to the Rust/LLVM production compiler (that is a separate effort, informed by this prototype work), adding new type system features (session types are already designed; this adds inference), or changes to the Redex formalization (that can follow the Racket implementation).

---

## 2. Research Foundations: Type Inference for Dependent Types

### 2.1 Why Hindley-Milner Cannot Work Here

Hindley-Milner type inference (the algorithm underlying ML, Haskell 98, and Rust's local inference) computes principal types for the simply-typed lambda calculus with parametric polymorphism. It works because the constraint language — first-order equational constraints over type constructors — has most general unifiers.

For dependent types, full inference is **undecidable**. The constraint language becomes higher-order (types depend on values, which are lambda terms), and higher-order unification has no decision procedure (Goldfarb, 1981). Specifically: to infer the type of `f x`, one must know the type of `f`, which may be `(Pi (a : A) (B a))` where `B` depends on the value of `a`. Solving for `B` given usage patterns requires higher-order unification.

The practical consequence is not that inference is impossible — it is that **complete** inference is impossible. Every practical system infers *some* types and requires annotations for the rest. The art is in choosing the boundary.

### 2.2 Bidirectional Type Checking: The Right Foundation

The prototype already implements bidirectional checking, which is the correct foundation. Dunfield & Krishnaswami's comprehensive survey (ACM Computing Surveys, 2021) establishes the framework:

**Synthesis mode** (`infer`): Given an expression `e`, compute its type `T`. Works for variables (look up in context), applications (infer function type, apply elimination), annotations (`(the T e)`), and type constructors.

**Checking mode** (`check`): Given an expression `e` and an expected type `T`, verify that `e` has type `T`. Works for lambda abstractions (check body against codomain), pairs (check components against Sigma type), and constructors (check against expected inductive type).

The key insight is that **type information flows bidirectionally**: synthesis pushes types upward (from subexpressions to expressions), while checking pushes types downward (from expected types to subexpressions). This flow eliminates many annotations: when checking `(fn [x] (inc x))` against `(-> Nat Nat)`, the expected domain `Nat` flows down to `x`, so no annotation on `x` is needed.

### 2.3 Elaboration with Metavariables

The missing piece in the prototype is **metavariables** (also called unification variables, holes, or existential type variables). The elaboration approach, used by Idris 2 (Brady, 2021), Agda (Norell, 2007), and Lean 4 (de Moura & Ullrich, 2021), works as follows:

**Step 1: Generate metavariables.** When the elaborator encounters an unknown — an omitted type annotation, an implicit argument, an inferred universe level — it creates a fresh metavariable `?m` in a global store. The metavariable represents "a term I don't know yet, but I know its type and the context in which it makes sense."

**Step 2: Generate constraints.** During bidirectional checking, type mismatches become unification constraints: `?m ≡ Nat` (metavariable must equal Nat), `?m₁ → ?m₂ ≡ Nat → Bool` (decompose into `?m₁ ≡ Nat` and `?m₂ ≡ Bool`). Constraints are stored alongside metavariables.

**Step 3: Solve constraints.** The unifier attempts to solve each constraint. Simple constraints (metavariable equals concrete type) are solved immediately. Complex constraints (metavariable applied to arguments, higher-order patterns) are attempted via pattern unification. Unsolvable constraints are postponed for later.

**Step 4: Zonk.** After all constraints are processed, the elaborator walks the entire term, replacing every solved metavariable with its solution. This "zonking" pass produces the fully explicit core term that the type checker and evaluator expect.

### 2.4 Pattern Unification: The Decidable Sweet Spot

Miller's pattern fragment (1991) identifies a decidable subset of higher-order unification that covers the vast majority of practical inference problems. A **pattern** is a metavariable applied to distinct bound variables: `?X x y z`. The restriction is that the arguments must be distinct variables — not repeated variables (`?X x x`), not applications (`?X (f x)`), and not constants.

Pattern unification is decidable in linear time and always produces most general unifiers. McBride (2003) showed that first-order unification can be implemented as a structurally recursive function in a dependently-typed language. Cockx et al. (2016) extended this to proof-relevant unification, ensuring soundness in dependent type systems.

For the Πρόλογος prototype, pattern unification is the recommended strategy: it handles implicit argument inference, universe level solving, and most type-level computation, while remaining decidable and producing clear error messages when it fails.

### 2.5 Constraint Postponement and Retry

When a constraint cannot be solved immediately — because it involves unsolved metavariables, non-pattern higher-order terms, or underdetermined types — it is **postponed**. The constraint store holds postponed constraints along with metadata about why they were postponed and what information might unblock them.

When a metavariable is solved (by another constraint), all postponed constraints involving that metavariable are **retried**. This wakeup mechanism enables a cascade of solutions: solving `?A ≡ Nat` might unblock `?B Nat ≡ List ?A`, which solves to `?B ≡ (fn [x] (List x))`.

If all constraints have been processed and some metavariables remain unsolved, the elaborator reports an error — but not the cryptic "could not unify ?X with ?Y" that plagues some systems. Instead, it reports in terms the user understands: "I couldn't determine the type of `x` in `(fn [x] (inc x))`. Please add a type annotation: `(fn [x : Nat] (inc x))`."

### 2.6 Multiplicity Inference in QTT

Atkey's QTT (2018) and Brady's Idris 2 (2021) establish that multiplicities can be **partially inferred**. The strategy:

**In function signatures**: multiplicities are typically annotated. The user writes `(-> (1 FileHandle) Unit)` to indicate linear usage. When omitted, the default is ω (unrestricted).

**In function bodies**: multiplicities are **inferred** from usage. If a variable `x` is used once, it has multiplicity 1; if used multiple times, it has multiplicity ω; if not used, it has multiplicity 0.

**Multiplicity checking**: The QTT layer verifies that the inferred usage is compatible with the declared multiplicity. Using a 1-multiplicity variable twice is an error; using a 0-multiplicity variable at runtime is an error.

For the prototype, this means: keep multiplicity annotations in function types (where they are meaningful API documentation) but infer them in bodies (where they are obvious from usage).

### 2.7 Session Type Inference

Session types describe communication protocols on channels. Research (Gay & Hole, 2005; Scalas & Yoshida, 2019; Lindley & Morris, 2016) shows that session types can be **partially inferred**:

**Locally inferred**: The sequence of send/receive operations determines the local session type. If a function calls `(send ch 42)` then `(recv ch)`, the local type is `!Int.?T.S` for some `T` and `S`.

**Globally annotated**: The overall protocol (the session type of the channel) must be explicitly declared. This is analogous to function type signatures — the protocol is API documentation.

For the prototype, session type annotations remain in channel types, but the local type at each use point is inferred by matching against the protocol.

### 2.8 Universe Level Inference

Universe levels (`Type 0 : Type 1 : Type 2 : ...`) can be almost entirely inferred. The strategy (used by Agda, Lean 4, and Coq):

**Step 1**: Create a fresh universe-level metavariable `?l` wherever a universe level is needed.

**Step 2**: Generate ordering constraints: `?l₁ < ?l₂` (from `Pi (A : Type l₁) (Type l₂)` forming `Type (max l₁ l₂)`).

**Step 3**: Solve the constraint system (a simple graph problem on universe levels).

The user almost never writes universe levels explicitly. The prototype's current `(Type 0)` annotations can be replaced with just `Type`, with the level inferred.

---

## 3. Audit of the Current Prototype

### 3.1 Architecture Overview

The prototype pipeline is:

```
Source text → Reader (reader.rkt)
           → S-expressions
           → Macro Expansion (macros.rkt, Layer 1: datum→datum)
           → Surface AST (surface-syntax.rkt)
           → Macro Expansion (macros.rkt, Layer 2: surf→surf)
           → Elaboration (elaborator.rkt, named→de Bruijn)
           → Core AST (syntax.rkt, 31+ constructors)
           → Bidirectional Type Checking (typing-core.rkt)
           → QTT Usage Checking (qtt.rkt)
           → Reduction/Evaluation (reduction.rkt)
```

### 3.2 What Already Works Well

**Bidirectional checking** (`typing-core.rkt`): The `infer`/`check` split is correctly implemented. Lambda checking against Pi types (line 287) correctly propagates the expected domain to the body. The `expr-hole` in lambda domain position (line 289) already accepts unknown domains when a Pi type is pushing the expected type downward — this is precisely the behavior we want to generalize.

**QTT tracking** (`qtt.rkt`): The usage-context parallel to the type context correctly tracks variable usage with `m0`/`m1`/`mw` multiplicities. The `check-all-usages` function verifies compatibility at the end.

**Implicit argument insertion** (`elaborator.rkt`): The `maybe-auto-apply-implicits` function (line 70) already inserts `expr-hole` values for fully-implicit (all-m0) functions. The `implicit-holes-needed` function (line 83) counts leading m0 parameters and inserts the right number of holes. The `collect-pi-mults` (line 47) and `leading-m0-count` (line 54) functions provide the analysis infrastructure. This constitutes a **significant partial implementation** of implicit argument inference — the hole *insertion* mechanism is complete, but hole *solving* (constraint generation and unification) is missing. Sprints 1–3 upgrade this existing infrastructure from "holes that match anything" to "metavariables solved by unification," preserving the elaborator's insertion logic while adding the solving backend.

**Macro system** (`macros.rkt`): The two-layer macro system provides `let`, `if`, `defn`, `deftype`, and `data` macros that desugar complex surface forms into core expressions. The `data` macro registers constructor metadata used by pattern matching.

### 3.3 Specific Church Encoding Leaks

Examining the codebase reveals six specific places where the internal representation leaks:

**1. `natrec` (typing-core.rkt, line 178)**: The natural number recursor takes a motive `(-> Nat Type)`, a base case, a step function, and a target. This is the catamorphism — the Church fold — for natural numbers. Users should never see `natrec`; they should write `match`.

**2. `boolrec` (typing-core.rkt, line 166)**: The boolean recursor takes a motive `(-> Bool Type)` and two branches. Users should write `if` without specifying the return type.

**3. `J` (typing-core.rkt, line 191)**: The equality eliminator takes a motive function with three arguments, a base case for `refl`, and the equality proof. Users should write `rewrite` or pattern-match on `refl`.

**4. `expr-reduce` (typing-core.rkt, line 341)**: The general pattern matching form compiles to Church fold application. The `check-reduce` function (defined later in the file) builds `(scrutinee T arm1 arm2 ...)` — applying the scrutinee as a Church-encoded value to the motive and arms. This means pattern matching only works with Church fold semantics, not true structural matching.

**5. Constructor type arguments for Vec** (throughout): `vnil`, `vcons`, `vhead`, `vtail`, `vindex` all require explicit type and length index arguments that should be inferrable from context.

**6. Constructor type arguments for Fin** (elaborator.rkt, lines 326–334): `fzero(n)` and `fsuc(n, inner)` require the explicit bound `n` even though it is fully determined by the result type `Fin(suc n)`. These index arguments mirror the Vec leak and follow the same resolution: implicit argument inference (Sprint 3) solves them automatically.

### 3.4 The Annotation Burden: A Catalogue

Here is every annotation the user currently must write, with an assessment of whether inference can eliminate it:

| Annotation | Example | Inferrable? |
|---|---|---|
| Type on `def` binding | `(def one <Nat> ...)` | Yes — infer from body |
| Type on lambda parameter | `(fn [x <Nat>] ...)` | Yes — from checking context |
| Type on `defn` parameters | `(defn f [x <Nat>] <Nat> ...)` | Partially — params from usage, return from body |
| Multiplicity on lambda | `(fn [A :0 <(Type 0)>] ...)` | Partially — `:0` can be inferred from usage |
| Type application | `(id Nat zero)` | Yes — Nat inferred from zero |
| Constructor type args (Vec) | `(vcons Nat zero x xs)` | Yes — Nat and zero from element/tail types |
| Constructor type args (Fin) | `(fzero n)`, `(fsuc n i)` | Yes — n from expected Fin type |
| Universe level | `(Type 0)` | Yes — from usage constraints |
| Motive for natrec | `(the (-> Nat (Type 0)) ...)` | Eliminated — replaced by pattern matching |
| Motive for boolrec | Implicit in `(if Nat ...)` | Eliminated — replaced by pattern matching |
| Motive for J | Complex 3-arg function | Eliminated — replaced by `rewrite`/match on refl |
| `the` annotation | `(the T e)` | Reduced — needed only for disambiguation |

### 3.5 The `expr-hole` Stub: Foundation for Metavariables

The prototype already has `expr-hole` (syntax.rkt, line 65), used in two places:

**Lambda checking** (typing-core.rkt, line 289): When a lambda `(fn [x] body)` is checked against `Pi(m, A, B)`, and the lambda's domain is `expr-hole`, the checker uses the Pi's domain `A` and multiplicity `m`. This is exactly bidirectional type propagation.

**Implicit application** (elaborator.rkt, line 70): The `maybe-auto-apply-implicits` function inserts `expr-hole` for each implicit parameter.

**But holes are never solved.** The `check` function (typing-core.rkt, line 346) accepts `expr-hole` against any type — `[((expr-hole) _) #t]` — but never records what type the hole should be. The elaborator inserts holes but has no mechanism to fill them with solved values.

The inference plan transforms `expr-hole` from a "wildcard that matches anything" into a **named metavariable** that is solved by unification and substituted back by zonking.

---

## 4. Design: The Inference Architecture

### 4.1 The Three-Phase Elaboration Pipeline

The current elaboration is a single pass. The inference architecture adds three phases:

```
Phase 1: ELABORATE
  Surface AST → Core AST with metavariables
  - Named variables → de Bruijn indices (existing)
  - Implicit argument insertion → fresh metavariables (new)
  - Type annotation holes → fresh metavariables (new)

Phase 2: SOLVE
  Constraints → Solutions
  - Pattern unification (new)
  - Constraint postponement and retry (new)
  - Universe level solving (new)
  - Multiplicity inference (new)

Phase 3: ZONK
  Core AST with metavariables → Core AST fully resolved
  - Walk term, replace solved metavariables (new)
  - Report unsolved metavariables as errors (new)
```

### 4.2 Metavariable Store Design

The metavariable store is a mutable hash table mapping metavariable IDs to their status:

```racket
;; metavar-store.rkt (new module)
(struct meta-info
  (id          ; unique integer ID
   ctx         ; the context in which this metavar is valid
   type        ; the expected type of the solution
   status      ; 'unsolved | 'solved
   solution    ; #f or the solved term
   constraints ; list of constraints involving this metavar
   source      ; source location for error reporting
   ) #:mutable #:transparent)

;; Global store (parameter for easy reset in tests)
(define current-meta-store (make-parameter (make-hasheq)))

;; Create a fresh metavariable
(define (fresh-meta ctx type source)
  (define id (gensym 'meta))
  (define info (meta-info id ctx type 'unsolved #f '() source))
  (hash-set! (current-meta-store) id info)
  (expr-meta id))  ; new expression type

;; Solve a metavariable
(define (solve-meta! id solution)
  (define info (hash-ref (current-meta-store) id))
  (set-meta-info-status! info 'solved)
  (set-meta-info-solution! info solution)
  ;; Wake up postponed constraints involving this metavar
  (retry-constraints! id))
```

The key new expression constructor is `expr-meta`:

```racket
;; In syntax.rkt: add
(struct expr-meta (id) #:transparent)  ; metavariable reference
```

### 4.3 Constraint Generation Rules

Constraints are generated during elaboration and checking:

**Rule 1: Application with unknown function type.** When `infer(ctx, (f x))` finds that `f` has type `?m` (a metavariable), generate: `?m ≡ Pi(?m₁, ?m₂, ?m₃)` — the function must have Pi type.

**Rule 2: Lambda checked against unknown type.** When `check(ctx, (fn [x] body), ?m)`, generate: `?m ≡ Pi(?m₁, ?m₂, ?m₃)` and check body against `?m₃`.

**Rule 3: Implicit argument insertion.** When `infer(ctx, f)` finds `f : Pi(m0, A, B)` (an implicit parameter), generate fresh `?m` and elaborate `f` as `(app f ?m)`. Then `?m` is constrained by `?m : A` and by later usage of the result.

**Rule 4: Type annotation hole.** When user writes `(fn [x] body)` without a type on `x`, and no Pi type is pushing down from checking context, generate `?m : Type` and elaborate `x : ?m`.

**Rule 5: Constructor type argument.** When `vnil` is checked against `Vec A n`, the implicit `A` argument to `vnil` is constrained to equal `A`.

### 4.4 The Unifier: Pattern Unification with Postponement

```racket
;; unify.rkt (new module)

;; Attempt to unify two terms in context ctx.
;; Returns #t if successful (may assign metavars as side effect),
;; #f if definitely fails, or 'postpone if underdetermined.
(define (unify ctx t1 t2)
  (let ([t1 (whnf t1)] [t2 (whnf t2)])
    (match* (t1 t2)
      ;; Both are the same metavar → trivially equal
      [((expr-meta id1) (expr-meta id2))
       #:when (equal? id1 id2)
       #t]

      ;; Metavar on one side: solve (pattern check)
      [((expr-meta id) t)
       (solve-meta-with! id t ctx)]
      [(t (expr-meta id))
       (solve-meta-with! id t ctx)]

      ;; Structural: decompose
      [((expr-Pi m1 a1 b1) (expr-Pi m2 a2 b2))
       (and (eq? m1 m2) (unify ctx a1 a2) (unify (ctx-extend ctx a1 m1) b1 b2))]

      [((expr-app f1 a1) (expr-app f2 a2))
       (and (unify ctx f1 f2) (unify ctx a1 a2))]

      ;; ... similar cases for Sigma, Vec, Fin, etc.

      ;; Atoms: definitional equality
      [(_ _) (conv t1 t2)])))

;; Solve a metavariable: assign id := solution, with occur check
(define (solve-meta-with! id solution ctx)
  (cond
    ;; Occur check: solution must not contain id
    [(occurs? id solution) #f]
    ;; Pattern check: if metavar was applied to args, verify pattern
    [else
     (assign-meta! id solution)
     #t]))
```

### 4.5 Zonking: Substituting Solutions

```racket
;; zonk.rkt (new module)

;; Walk a term, replacing solved metavariables with their solutions.
(define (zonk e)
  (match e
    [(expr-meta id)
     (let ([info (hash-ref (current-meta-store) id #f)])
       (if (and info (eq? (meta-info-status info) 'solved))
           (zonk (meta-info-solution info))  ; recursively zonk the solution
           e))]  ; unsolved: leave as-is (will be reported as error)

    [(expr-lam m a body) (expr-lam m (zonk a) (zonk body))]
    [(expr-app f x) (expr-app (zonk f) (zonk x))]
    [(expr-Pi m a b) (expr-Pi m (zonk a) (zonk b))]
    ;; ... all other constructors ...
    [_ e]))

;; After elaboration, check for unsolved metavariables
(define (report-unsolved-metas!)
  (for ([(id info) (in-hash (current-meta-store))])
    (when (eq? (meta-info-status info) 'unsolved)
      (report-inference-error! info))))
```

### 4.6 Native Pattern Matching: Replacing Church Folds

The critical DX transformation: replace Church-fold eliminators (`natrec`, `boolrec`, `J`) with native pattern matching that does NOT expose fold semantics.

**Surface syntax for pattern matching:**

```
(match scrutinee
  pattern₁ -> body₁
  pattern₂ -> body₂
  ...)
```

**Elaboration of match:**

1. Infer the type of the scrutinee.
2. Look up constructor information for that type (from the constructor metadata registry in `macros.rkt`).
3. For each arm, bind pattern variables in the context with their types (inferred from the constructor).
4. Check each body against the expected return type (pushing down from checking context, or creating a metavariable if in synthesis mode).
5. Verify exhaustiveness — all constructors of the scrutinee's type must be covered.

**Compilation of match to core eliminators:**

For the prototype, `match` compiles to the existing eliminators:

- `(match n zero -> e₁ | (inc k) -> e₂)` compiles to `(natrec motive e₁ (fn [k] (fn [_] e₂)) n)` — but the motive is inferred, not user-written.
- `(match b true -> e₁ | false -> e₂)` compiles to `(boolrec motive e₁ e₂ b)` — motive inferred.
- For user-defined data types, `match` compiles to `reduce` with the structural flag set.

The user never sees `natrec`, `boolrec`, or `J`. These remain as internal core expressions, invisible in the surface language.

### 4.7 Error Recovery and Reporting

When inference fails, the error message must:

1. **Name the unknowable.** "I couldn't determine the type of `x`" — not "failed to unify ?m₃₇ with ?m₄₂."

2. **Locate the ambiguity.** Point to the source span where the unknown was introduced.

3. **Suggest the fix.** "Add a type annotation: `(fn [x : Nat] ...)`" — not "provide more information."

4. **Show the constraints.** "I know `x` is used with `inc`, which expects `Nat`, but `x` is also used with `concat`, which expects `String`. These conflict." — show the contradiction.

Implementation: Each metavariable carries a `source` field (source location of the expression that generated it) and a list of constraints with their own source locations. When reporting an unsolved or contradictory metavariable, the error printer traces back to the user's code.

---

## 5. Sprint 1: Metavariable Infrastructure (Week 1)

### 5.1 Objective

Add the metavariable store, the `expr-meta` constructor, and the zonking pass to the prototype. At the end of this sprint, the existing `expr-hole` behavior is replicated by `expr-meta` — no new inference capability yet, just infrastructure.

### 5.2 Deliverables

**New file: `metavar-store.rkt`**

- `(fresh-meta ctx type source) → expr-meta` — create a new metavariable.
- `(solve-meta! id solution)` — assign a solution.
- `(meta-solved? id) → bool` — check if solved.
- `(meta-solution id) → expr or #f` — retrieve solution.
- `(reset-meta-store!)` — clear all metavariables (for REPL reset).
- `(all-unsolved-metas) → list` — list unsolved metavariables.

**New file: `zonk.rkt`**

- `(zonk expr) → expr` — substitute solved metavariables throughout a term.
- `(zonk-ctx ctx) → ctx` — zonk all types in a context.

**Modifications to `syntax.rkt`:**

- Add `(struct expr-meta (id) #:transparent)` to the expression type.
- Export `expr-meta` and `expr-meta?`.

**Modifications to `substitution.rkt`, `reduction.rkt`, `pretty-print.rkt`:**

- Handle `expr-meta` in shift, subst, whnf, nf, conv, and pretty-printing.
- `whnf` of `expr-meta`: if solved, reduce to `whnf(solution)`; if unsolved, return as-is.
- `conv` of `expr-meta`: if solved, compare solutions; if unsolved, check if same metavar.

**Test: `test-metavar.rkt`**

- Create metavariables, solve them, verify zonking substitutes correctly.
- Verify that `whnf` follows solved metavariables.
- Verify that `conv` treats two unsolved metavariables as unequal (unless same ID).

### 5.3 Key Decision

**Named metavariables vs. indexed.** Use `gensym` for IDs (producing readable symbols like `meta42`) rather than integer indices. This makes debugging easier — error messages can say "?meta42" rather than "?37."

---

## 6. Sprint 2: Unification Engine (Weeks 2–3)

### 6.1 Objective

Implement a unification algorithm that can solve constraints between terms, assigning metavariables as side effects. This is the most foundational new module — the prototype has no existing unification engine (only `conv` for definitional equality in `reduction.rkt`). Given the complexity of binder-aware unification with dependent types, this sprint is allocated two weeks and split into two sub-sprints.

### 6.1a Sprint 2a: Core Structural Unification (Week 2)

Implement occur check, metavariable assignment, and basic structural decomposition. At the end of this sub-sprint, the unifier can solve simple constraints like `?m ≡ Nat` and `Pi(?m₁, ?m₂) ≡ Pi(Nat, Bool)`.

### 6.1b Sprint 2b: Pattern Condition and Binder Handling (Week 3)

Add Miller's pattern condition checking: when encountering `(app (expr-meta id) (expr-bvar k))`, verify that the argument is a distinct bound variable (not repeated, not an application, not a constant). Add binder-aware traversal for occur check and substitution composition — when `?m₁ := (fn [x] ?m₂)` is solved and later `?m₂` is solved, the substitution must be composed correctly under the binder. This is the subtle part that McBride (2003) shows can be made structurally recursive, but requires care.

### 6.2 Deliverables

**New file: `unify.rkt`**

- `(unify ctx t1 t2) → #t | #f` — attempt to unify two terms, solving metavariables.
- `(occurs? id expr) → bool` — binder-aware occur check (prevent infinite types).
- `(unify-spine ctx args1 args2) → #t | #f` — unify argument lists.
- `(pattern-check id args) → bool` — verify Miller's pattern condition on metavariable arguments.
- `(invert-args args body) → expr` — construct lambda abstraction from pattern solution.

The unifier handles all expression constructors:

- `expr-meta` on one side: solve (with occur check).
- `expr-Pi` vs `expr-Pi`: unify domains and codomains.
- `expr-Sigma` vs `expr-Sigma`: unify components.
- `expr-Vec` vs `expr-Vec`: unify element type and length.
- `expr-Fin` vs `expr-Fin`: unify bound.
- `expr-app` vs `expr-app`: unify function and argument.
- `expr-suc` vs `expr-suc`: unify predecessors.
- Atoms (`expr-Nat`, `expr-Bool`, `expr-zero`, `expr-true`, etc.): equality check.
- Otherwise: fall back to `conv` (definitional equality).

**Modifications to `typing-core.rkt`:**

- Replace `(conv a t-dom)` in lambda checking with `(unify ctx a t-dom)`.
- Replace `(conv n (expr-zero))` in vnil checking with `(unify ctx n (expr-zero))`.
- Similarly for all `conv` calls in `check` and `infer`.

**Test: `test-unify.rkt`**

- `(unify ctx ?m (expr-Nat))` solves `?m := Nat`.
- `(unify ctx (Pi ?m1 ?m2) (Pi Nat Bool))` solves `?m1 := Nat`, `?m2 := Bool`.
- Occur check: `(unify ctx ?m (Pi ?m Nat))` fails.
- Already-solved metavar: `(unify ctx ?m Nat)` after `?m := Nat` succeeds.
- Conflicting solution: `(unify ctx ?m Nat)` after `?m := Bool` fails.

---

## 7. Sprint 3: Implicit Argument Inference (Weeks 4–5)

### 7.1 Objective

Make implicit (m0-multiplicity) arguments automatically inferred from usage context. After this sprint, `(id zero)` works — the `Nat` type argument is inferred.

### 7.2 Deliverables

**Modifications to `elaborator.rkt`:**

Replace the current `maybe-auto-apply-implicits` (which only works for fully-implicit functions) with a general implicit insertion pass:

```racket
;; When elaborating (f a1 a2 ... an):
;; 1. Infer the type of f
;; 2. Count leading m0 (implicit) parameters
;; 3. Insert fresh metavariables for each implicit parameter
;; 4. Elaborate explicit arguments a1...an against remaining parameters
;; 5. Unification from checking explicit args solves the implicit metavars
```

The key change: implicit holes are no longer `expr-hole` (which matches anything); they are `expr-meta` (which must be solved by unification).

**New elaboration for `def`:**

```racket
;; (def name body) — no type annotation
;; Elaborate body in synthesis mode, infer type
;; (def name <Type> body) — with type annotation
;; Elaborate body in checking mode against Type
```

Currently `def` requires a type annotation. After this sprint, `(def one (inc zero))` works — the type `Nat` is inferred from `inc` and `zero`.

**New elaboration for lambda:**

```racket
;; (fn [x] body) — no type on parameter
;; In synthesis mode: create ?m for x's type, elaborate body, return Pi(?m, body-type)
;; In checking mode against Pi(m, A, B): use A for x's type (already works via expr-hole)
```

**Modifications to `typing-core.rkt`:**

In `infer` for `expr-app`: when the function has a Pi type with m0 multiplicity, and the elaborator has inserted a metavariable, the unifier will solve the metavariable from the argument type:

```
infer(ctx, app(id, zero))
  → infer(ctx, app(app(id, ?A), zero))   [?A inserted for implicit]
  → id : Pi(A :0, A → A)
  → app(id, ?A) : ?A → ?A
  → check(ctx, zero, ?A) → unify(?A, Nat) → ?A := Nat ✓
  → result type: Nat
```

**Test file: `test-implicit-inference.rkt`**

```
;; These should all work after Sprint 3:
(def id (fn [A :0 (Type 0)] (fn [x] x)))
(eval (id zero))        ;; Nat inferred
(eval (id true))        ;; Bool inferred
(eval (id (inc zero)))  ;; Nat inferred

;; Vector operations with implicit type args
(check (vnil) <(Vec Nat zero)>)  ;; Nat inferred from context
(check (vcons (inc zero) (vnil)) <(Vec Nat (inc zero))>)
```

---

## 8. Sprint 4: Native Pattern Matching — Eliminating Church Folds (Weeks 6–7)

### 8.1 Objective

Replace user-visible `natrec`, `boolrec`, and `J` with `match` expressions that compile to these eliminators internally. After this sprint, no Church encodings are visible in the surface language.

### 8.2 Deliverables

**New Layer 1 macro: `match`**

```racket
;; In macros.rkt: add match macro
;; (match scrutinee
;;   pattern1 -> body1
;;   pattern2 -> body2)
;; Desugars based on scrutinee type (inferred or annotated)
```

**Match compilation for Nat:**

```
(match n
  zero    -> e₁
  (inc k) -> e₂)

Compiles to:
(natrec ?motive e₁ (fn [k] (fn [_rec] e₂)) n)

Where ?motive is a metavariable that will be solved from the
expected return type (pushed down from checking context).
```

**Match compilation for Bool:**

```
(match b
  true  -> e₁
  false -> e₂)

Compiles to:
(boolrec ?motive e₁ e₂ b)
```

**Match compilation for user-defined data types:**

Use the constructor metadata registry (already in `macros.rkt`) to determine constructors, field types, and recursive positions. Compile to `expr-reduce` with the structural flag.

**Motive inference:**

The motive — the function from scrutinee value to return type — is the key piece that inference eliminates. In checking mode:

```
check(ctx, match n { zero -> 0 | inc k -> ... }, T)
  → motive = (fn [_] T)  ;; constant motive: every branch returns T
```

In synthesis mode:

```
infer(ctx, match n { zero -> e₁ | inc k -> e₂ })
  → infer(ctx, e₁) = T₁
  → check if T₁ works for all branches
  → motive = (fn [_] T₁)
```

For dependent motives (where the return type depends on the scrutinee value):

```
;; Return type depends on n
(match n
  zero    -> vnil       ;; : Vec A zero
  (inc k) -> (vcons ...) ;; : Vec A (inc k))
```

This requires a dependent motive `(fn [n] (Vec A n))`. The metavariable for the motive is constrained by each branch: `?motive(zero) ≡ Vec A zero` and `?motive(inc k) ≡ Vec A (inc k)`. Pattern unification solves: `?motive ≡ (fn [n] (Vec A n))`.

**Exhaustiveness checking:**

After compiling the match, verify that all constructors of the scrutinee's type are covered. For Nat: both `zero` and `inc` must appear. For Bool: both `true` and `false`. For user-defined types: all constructors registered in the metadata.

Non-exhaustive matches produce a warning (not an error in the prototype, since the type checker ensures safety via the dependent motive).

**Tests:**

```
;; After Sprint 4:
(defn double [x] Nat
  (match x
    zero    -> zero
    (inc n) -> (inc (inc (double n)))))

(eval (double (inc (inc zero))))  ;; => (inc (inc (inc (inc zero))))

(eval (match true
  true  -> (inc zero)
  false -> zero))                 ;; => (inc zero)
```

---

## 9. Sprint 5: Constraint Postponement and Dependent Unification (Weeks 8–9)

### 9.1 Objective

Handle cases where constraints cannot be solved immediately — because they involve unsolved metavariables or dependent types that require more information.

### 9.2 Deliverables

**Constraint store in `metavar-store.rkt`:**

```racket
(struct constraint
  (lhs rhs ctx source status)
  #:mutable #:transparent)
;; status: 'active | 'postponed | 'solved | 'failed

(define (add-constraint! lhs rhs ctx source)
  (define c (constraint lhs rhs ctx source 'active))
  (attempt-solve! c)
  (when (eq? (constraint-status c) 'postponed)
    (register-wakeup! c)))
```

**Wakeup mechanism:**

When a metavariable is solved, all postponed constraints that mention it are retried:

```racket
(define (retry-constraints! meta-id)
  (for ([c (in-list (meta-constraints meta-id))])
    (when (eq? (constraint-status c) 'postponed)
      (let ([lhs (zonk (constraint-lhs c))]
            [rhs (zonk (constraint-rhs c))])
        (attempt-solve! (struct-copy constraint c
                          [lhs lhs] [rhs rhs] [status 'active]))))))
```

**Pattern unification extension:**

Move from pure first-order unification to Miller's pattern fragment. When encountering `(expr-app (expr-meta id) (expr-bvar k))`, check if the argument is a distinct bound variable (pattern condition), and if so, solve:

```
?m x ≡ t   where x is a bound variable distinct from other args
Solution: ?m := (fn [x] t)   provided x ∉ FV(other args of ?m)
```

**Tests:**

```
;; Constraint that must be postponed then retried:
(def apply-id (fn [f] (fn [x] (f x))))
;; f : ?A → ?B, x : ?A, result : ?B
;; When (apply-id id zero) is evaluated:
;; ?A unified with Nat from zero
;; ?B unified with Nat from id's return type
```

---

## 10. Sprint 6: Universe Level Inference (Week 10)

### 10.1 Objective

Eliminate explicit universe levels. After this sprint, users write `Type` instead of `(Type 0)`, and the elaborator infers the level.

### 10.2 Deliverables

**Universe level metavariables:**

```racket
;; New: level-meta — a metavariable specifically for universe levels
(struct level-meta (id) #:transparent)

;; When the user writes Type (without a level), elaborate to:
(expr-Type (level-meta (gensym 'level)))
```

**Level constraint solving:**

Generate constraints from Pi type formation:
- `Pi(A : Type l₁, B : Type l₂)` forms `Type (lmax l₁ l₂)`
- Generate: `l ≡ lmax(l₁, l₂)`

Solve by: assigning the minimum valid level to each level metavariable, working from the leaves of the constraint graph upward.

**Modifications to `typing-core.rkt`:**

In `infer-level`, handle `level-meta` by creating constraints rather than requiring concrete levels.

**Tests:**

```
;; After Sprint 6:
(def id (fn [A :0 Type] (fn [x : A] x)))
;; Level of Type inferred as 0 (or whatever is needed)

(def List (fn [A : Type] ...))
;; Level inferred
```

---

## 11. Sprint 7: Multiplicity Inference for QTT (Weeks 11–12)

### 11.1 Objective

Infer multiplicities in function bodies and reduce the annotation burden on lambda parameters. After this sprint, `(fn [x] x)` has multiplicity ω inferred for `x`, and `(fn [x] (close x))` has multiplicity 1 inferred for `x` when `close` expects a linear argument.

### 11.2 Deliverables

**Multiplicity metavariables:**

```racket
;; When the user omits multiplicity, default to a metavariable
(struct mult-meta (id) #:transparent)
```

**Inference strategy:**

In `checkQ`, when a lambda parameter has a multiplicity metavariable:

1. Elaborate the body, tracking usage.
2. The actual usage of the variable determines its multiplicity.
3. Assign the multiplicity metavariable to the observed usage.
4. Verify compatibility with any constraints from the checking context.

**Default multiplicity:**

When no annotation is given and no checking context provides one, the default multiplicity is ω (unrestricted). This follows Idris 2's convention and matches user expectations — most values are unrestricted.

Linear (`1`) and erased (`0`) multiplicities must be explicitly annotated in function **signatures** (where they serve as API documentation), but are inferred in function **bodies**.

**Tests:**

```
;; Multiplicity inferred from usage
(def use-once (fn [x :1 Nat] x))  ;; :1 still required in signature
;; But in the body, usage tracking verifies x is used exactly once

;; Default: unrestricted
(def double (fn [x] (+ x x)))  ;; x used twice → ω inferred
```

---

## 12. Sprint 8: Session Type Annotation Reduction (Weeks 13–14)

### 12.1 Objective

Reduce annotation burden for session-typed channels by inferring the local protocol state from send/receive operations. This sprint is allocated two weeks due to the interaction between session type continuations, linear channel usage, and dependent session types.

### 12.2 Sub-Sprints

**Sprint 8a (Week 13): Monomorphic session type state tracking.**

When a channel `ch : Chan S` is used in a sequence of operations, the elaborator tracks the protocol state by threading metavariables through the continuation:

```
(send ch 42)   ;; ch was at state !Int.S', now at S'
(recv ch)      ;; ch was at S' = ?T.S'', infer T from usage
```

Session type continuations are represented as **type metavariables** (not a separate kind). When the user writes `(send ch 42)`, the elaborator:
1. Verifies `ch : Chan (!Int.?S')` — the protocol expects a send of `Int`.
2. Creates `?S'` as a fresh type metavariable for the continuation.
3. Updates the channel's local type to `Chan ?S'`.
4. Subsequent operations on `ch` constrain `?S'`.

**Sprint 8b (Week 14): Dependent session types.**

When session types depend on values — e.g., `!n:Nat.Vec(n)` (send a number, then send a vector of that length) — the continuation type `Vec(n)` depends on the value `n` sent in the previous step. The elaborator must:
1. Track the value sent (not just its type) and substitute it into the continuation.
2. Create dependent metavariables: `?S'(n)` where `n` is the sent value.
3. Solve via pattern unification when the dependent continuation is determined by usage.

Dependent session types that are not solvable by pattern unification require explicit protocol annotations — the user specifies the full session type, and the elaborator verifies compliance.

### 12.3 Deliverables

**Modifications to session type checking:**

Create metavariables for unknown continuation types in the protocol. Solve them from the actual operations performed. The interaction with QTT is critical: channels are linear (`m1`), so each operation consumes the current session state and produces a new one.

**The protocol type itself remains annotated.** The user writes the session type in the channel declaration (it's API documentation), but within a function that uses the channel, individual operations are checked against the protocol without additional annotations.

---

## 13. Sprint 9: Error Messages for Inference Failures (Weeks 15–16)

### 13.1 Objective

Produce excellent, human-readable error messages when inference fails. This is the "VERY IMPORTANT" requirement from NOTES.org.

### 13.2 Error Reporting Architecture

Before implementing specific messages, the inference engine requires a structured error reporting pipeline that maps internal constraint failures back to user-facing source locations.

**Metavariable-to-source mapping.** Every `meta-info` carries a `source` field containing the source span (file, line, column, length) of the expression that generated it. When a metavariable is created by implicit argument insertion, the source is the *application site* (where the user wrote `(id zero)`), not the function definition. When created by a type annotation hole, the source is the parameter position (`[x]` in `(fn [x] body)`).

**Constraint provenance chain.** Every constraint records a chain of provenance entries:

```racket
(struct constraint-provenance
  (source-span   ; where in user code this constraint arose
   description   ; human-readable: "because x is passed to inc, which expects Nat"
   parent        ; #f or another provenance (for constraints derived from earlier ones)
   ) #:transparent)
```

When a derived constraint fails (e.g., `?m₃ ≡ Bool` derived from `?m₁ ≡ Pi(?m₂, ?m₃)` derived from the user writing `(f true)`), the error printer walks the provenance chain to reconstruct the user-facing explanation: "I expected `f` to return `Nat` (line 5) but you passed `true` which has type `Bool` (line 8)."

**De Bruijn index recovery.** For error display, convert de Bruijn indices back to the user's original variable names. The elaborator must record a *name map* during elaboration: `bvar(0) → "x"`, `bvar(1) → "n"`, etc. This map is stored per-definition and consulted during error printing.

**Noise filtering.** Internal constraints (e.g., universe level ordering, multiplicity compatibility) are suppressed unless they are the *direct cause* of the failure. The error printer categorizes constraints as:
- *Primary*: directly involving user-written expressions → always shown.
- *Secondary*: arising from implicit elaboration → shown only with `--verbose`.
- *Internal*: infrastructure constraints (meta-to-meta) → never shown to users.

### 13.3 Deliverables

**Error message templates:**

```
error[E1001]: cannot infer type of parameter
  --> src/main.prologos:5:10
   |
5  |   (def add (fn [x] (fn [y] (+ x y))))
   |                 ^
   |
   = help: add a type annotation: (fn [x : Nat] ...)
   = note: I know x is used with (+), which expects Nat,
           but I need an explicit annotation to be sure

error[E1002]: conflicting type constraints
  --> src/main.prologos:8:3
   |
8  |   (let result (if condition (inc zero) "hello"))
   |   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
   |
   = true branch: (inc zero) has type Nat (line 8, col 30)
   = false branch: "hello" has type String (line 8, col 41)
   = these must be the same type
   = help: ensure both branches return the same type

error[E1003]: unsolved implicit argument
  --> src/main.prologos:12:3
   |
12 |   (eval (id (p8-from-nat 42)))
   |          ^^^^^^^^^^^^^^^^^^
   |
   = I couldn't determine the type argument for 'id'
   = the expression (p8-from-nat 42) has type Posit8,
     but 'id' needs its type parameter resolved to proceed
   = help: provide the type explicitly: (id Posit8 (p8-from-nat 42))
   = note: consider annotating the definition:
           (def x : Posit8 (p8-from-nat 42))
```

**Implementation:**

Modify `errors.rkt` to support structured diagnostics with source spans, labels, help text, and notes. Each metavariable carries provenance information — the source expression that created it — enabling the error printer to trace back to user code.

**Constraint provenance:**

Every constraint records:
- The source location where it was generated.
- A human-readable description: "because `x` is used as an argument to `inc`, which expects `Nat`."
- The two sides of the constraint with their own source locations.

When a constraint fails, the error printer displays both sides with their provenance.

---

## 14. Sprint 10: Ergonomic Surface Syntax Polish (Weeks 17–18)

### 14.1 Objective

Polish the surface syntax to take full advantage of inference. After this sprint, the Πρόλογος surface language feels clean and modern.

### 14.2 Deliverables

**Simplified `def` syntax:**

```
;; No annotation needed for simple definitions
(def one (inc zero))          ;; type Nat inferred
(def id (fn [x] x))          ;; type (forall A. A → A) inferred

;; Annotation only when needed
(def head : (forall (n : Nat) (-> (Vec Nat (inc n)) Nat))
  (fn [n] (fn [v] (vhead v))))
```

**Simplified `defn` syntax:**

```
;; Parameters without types when inferrable from return type
(defn double [x] Nat
  (match x
    zero    -> zero
    (inc n) -> (inc (inc (double n)))))

;; With types when ambiguous
(defn apply [f : (-> Nat Nat)] [x : Nat] Nat
  (f x))
```

**Type-ascription shorthand:**

```
;; Instead of (the Nat 42), allow:
42 : Nat
;; Or in binding position:
(let [x : Nat 42] ...)
```

**Where clauses for local definitions:**

```
(defn fib [n] Nat
  (match n
    zero       -> zero
    (inc zero) -> (inc zero)
    (inc (inc k)) -> (+ (fib (inc k)) (fib k))))
```

**Wildcard patterns:**

```
(match pair
  (pair _ y) -> y)    ;; _ is a wildcard, no binding
```

---

## 15. Before and After: The Complete Transformation

### 15.1 Polymorphic Identity

```
;; BEFORE (current prototype):
(def id <(Pi [A :0 <(Type 0)>] (-> A A))>
  (fn [A :0 <(Type 0)>] (fn [x <A>] x)))
(eval (id Nat zero))
(eval (id Bool true))

;; AFTER (with inference):
(def id (fn [x] x))
(eval (id zero))
(eval (id true))
```

### 15.2 Doubling a Natural Number

```
;; BEFORE: natrec with explicit motive (Church fold leaks)
(defn double [x <Nat>] <Nat>
  (natrec (the (-> Nat (Type 0)) (fn [_ <Nat>] Nat))
          zero
          (fn [_ <Nat>] (fn [r <Nat>] (inc (inc r))))
          x))

;; AFTER: clean pattern matching, no church encoding
(defn double [x] Nat
  (match x
    zero    -> zero
    (inc n) -> (inc (inc (double n)))))
```

### 15.3 Vector Operations

```
;; BEFORE: explicit type indices everywhere
(check (vnil Nat) <(Vec Nat zero)>)
(check (vcons Nat zero (inc zero) (vnil Nat)) <(Vec Nat (inc zero))>)
(eval (vhead Nat zero
  (the (Vec Nat (inc zero))
       (vcons Nat zero (inc zero) (vnil Nat)))))

;; AFTER: type indices inferred
(check vnil <(Vec Nat zero)>)
(check (vcons 1 vnil) <(Vec Nat 1)>)
(eval (vhead (vcons 1 vnil)))
```

### 15.4 Boolean Elimination

```
;; BEFORE: explicit return type in if
(eval (if Nat true (inc zero) zero))

;; AFTER: return type inferred from branches
(eval (if true 1 0))
```

### 15.5 Dependent Pairs

```
;; BEFORE: explicit types
(check (pair zero true) <(Sigma [x <Nat>] Bool)>)

;; AFTER: component types inferred from checking context
(check (pair zero true) <(Sigma [x : Nat] Bool)>)
;; Or in synthesis mode with annotation:
(def p : (Sigma [x : Nat] Bool) (pair zero true))
```

### 15.6 Type-Checker-as-a-Relation (Logic Programming)

```
;; AFTER: inference makes logic programming clean
(relation (type-of ctx expr ty)
  (clause (type-of ctx (var x) ty)
    (member (pair x ty) ctx))
  (clause (type-of ctx (app f a) result-ty)
    (type-of ctx f (arrow arg-ty result-ty))
    (type-of ctx a arg-ty)))
;; All type variables are inferred by the logic engine
```

---

## 16. Logic Programming and Type Inference Integration

Πρόλογος is a functional-*logic* language. The inference plan above addresses the functional layer (dependent types, pattern matching, implicit arguments), but the logic programming layer introduces distinct inference challenges that must be accounted for.

### 16.1 Logic Variables vs. Type Metavariables

Logic variables (used in Prolog-style clauses and `relation` definitions) and type metavariables (used during elaboration) are *different kinds of unknowns* that operate in different phases:

**Type metavariables** are solved at compile time during elaboration. They represent unknown types, universe levels, or implicit arguments. They are solved by pattern unification and disappear after zonking.

**Logic variables** are solved at runtime during proof search. They represent unknown values in a logic query. They are solved by SLD resolution (or its Πρόλογος equivalent using propagator-backed constraint solving).

These two should never be conflated in the implementation. The type checker solves type metavariables; the runtime solver solves logic variables. However, they *interact* at the boundary:

### 16.2 Typing Relations and Proof Search

When the user defines a relation:

```
(relation (append xs ys zs)
  (clause (append nil ys ys))
  (clause (append (cons x xs') ys (cons x zs'))
    (append xs' ys zs')))
```

The type checker must infer the types of `xs`, `ys`, `zs`, `x`, `xs'`, `zs'` from the clause structure. This follows the same bidirectional pattern as functional type inference — the relation's declared type (if annotated) pushes expected types downward into clause bodies.

**Key interaction**: Each clause in a relation introduces *both* logic variables (for runtime unification) and type metavariables (for compile-time type inference). The elaborator must:
1. Create type metavariables for each clause variable's type.
2. Generate type constraints from the clause body (e.g., `cons x xs'` implies `x : A` and `xs' : List A`).
3. Solve type constraints at compile time via the unification engine from Sprint 2.
4. Emit runtime logic variables (with their solved types) into the compiled clause.

### 16.3 Non-Determinism and Type Ambiguity

Logic queries can produce multiple solutions. For type inference, this raises a question: if a query `(append ?xs ?ys (cons 1 (cons 2 nil)))` has multiple valid decompositions, do they all have the same type?

Yes — by parametricity and the type system's consistency. All solutions to a well-typed query must have the types determined by the query's type. The type inference engine does *not* need to enumerate solutions; it need only verify that the *schema* of the relation is type-consistent. This is handled by checking each clause independently (as in functional definition checking) and verifying that all clauses agree on the relation's type.

### 16.4 Dependent Types in Logic Clauses

When logic programming involves dependent types — e.g., a relation over length-indexed vectors — the type arguments may depend on logic variables whose values are not known at compile time:

```
(relation (vappend (v1 : Vec A n) (v2 : Vec A m) (result : Vec A (+ n m)))
  (clause (vappend vnil v2 v2))
  (clause (vappend (vcons x xs) v2 (vcons x zs))
    (vappend xs v2 zs)))
```

Here `n` and `m` are *runtime* values — they are logic variables in queries. But `(+ n m)` appears in a *type* (`Vec A (+ n m)`). The type checker must handle this by:
1. Treating `n` and `m` as opaque bound variables in the type.
2. Verifying that each clause is type-consistent for *all possible* values of `n` and `m` (i.e., parametrically typed).
3. Deferring computation of `(+ n m)` to runtime, where the logic solver determines concrete values.

This is the standard dependent-type approach to polymorphic relations and requires no new inference machinery beyond what Sprints 1–5 provide.

### 16.5 References for Logic-Type Integration

Pfenning, F. & Schürmann, C. (1999). System Description: Twelf — A Meta-Logical Framework for Deductive Systems. CADE-16.

Miller, D. & Nadathur, G. (1986). Higher-Order Logic Programming. ICLP 1986.

Schrijvers, T. et al. (2009). Constraint Handling Rules for Type Inference. Constraints, 14(3).

---

## 17. Cross-Cutting Concerns and Pitfalls

### 17.1 Normalization and Metavariables

When normalizing a term that contains unsolved metavariables, the normalizer must handle them gracefully:

- `whnf(expr-meta id)`: if solved, follow to `whnf(solution)`; if unsolved, return `expr-meta id` (it is in weak head normal form by definition — it cannot be reduced further).
- `conv(expr-meta id, t)`: if solved, compare `conv(solution, t)`; if unsolved, they are convertible only if `t` is the same metavariable.
- `nf(expr-meta id)`: if solved, normalize `nf(solution)`; if unsolved, return `expr-meta id`.

**Pitfall**: Never normalize *into* a metavariable. If `?m` is unsolved and appears as `(app ?m x)`, do NOT try to reduce the application — it is stuck. This is called a **stuck term** or **neutral term**. The normalizer must recognize stuck terms and leave them alone.

### 17.2 Let-Generalization and Dependent Types

In Hindley-Milner, `let` introduces polymorphism: `(let [id (fn [x] x)] ...)` generalizes `id` to `∀a. a → a`. In dependent types, generalization is more nuanced because types can depend on values.

For the prototype, adopt the **no-generalization** approach (used by Agda and Idris 2): let-bound variables have monomorphic types unless explicitly annotated with a polymorphic type. This avoids the complexity of let-generalization in a dependent type system and is sufficient for practical programming.

### 17.3 The Annotation Budget

The research consistently shows that dependent type systems require *some* annotations. The goal is not zero annotations — it is **the right annotations in the right places**:

- **Function signatures**: Always annotate (they are documentation). `(def f : (-> Nat Nat) ...)`.
- **Lambda parameters in checking mode**: Never annotate (pushed from expected type). `(fn [x] (inc x))` checked against `(-> Nat Nat)`.
- **Lambda parameters in synthesis mode**: May need annotation if ambiguous. `(fn [x : Nat] (inc x))`.
- **Implicit arguments**: Never annotate (inferred from usage). `(id zero)` not `(id Nat zero)`.
- **Universe levels**: Never annotate (inferred from constraints). `Type` not `(Type 0)`.
- **Multiplicities in signatures**: Annotate when non-default (0 or 1). `:0`, `:1`.
- **Multiplicities in bodies**: Never annotate (inferred from usage).
- **Session types on channels**: Annotate (they are protocol documentation).
- **Local session type state**: Never annotate (tracked automatically).

### 17.4 Interaction with the Macro System

The macro system expands before elaboration, so macros produce surface syntax that the elaborator sees. Macros should generate expressions **without** type annotations wherever possible, relying on inference to fill them in.

The `match` macro (Sprint 4) is the most important macro: it desugars to core eliminators with inferred motives, completely hiding Church encodings. The `data` macro (already existing) continues to register constructor metadata needed by `match`.

### 17.5 Incremental vs. Batch Inference

The prototype processes definitions sequentially (in `driver.rkt`). Each `def` is type-checked and added to the global environment before the next one is processed. This means inference is **local to each definition** — metavariables from one `def` do not leak into another.

This is the right design for the prototype. Global inference (solving metavariables across definitions) is fragile, order-dependent, and produces hard-to-understand errors. Keep inference local.

### 17.6 Regression Safety

Every sprint must maintain backward compatibility: existing test programs must continue to work. The new inference features are strictly additive — they allow omitting annotations that were previously required, but still accept fully-annotated programs.

Test strategy: run the existing test suite (`test-typing.rkt`, `test-lang.rkt`, `test-qtt.rkt`, etc.) after every sprint. Any regression is a bug.

### 17.7 Performance

The prototype is not performance-critical (it's a research prototype), but inference should not make type checking pathologically slow. The key concern is constraint postponement creating an exponential retry cascade. Mitigation: limit the number of retries per constraint (e.g., 100), and report an error if the limit is exceeded.

### 17.8 Comparison with Idris 2's Elaboration

The design follows Idris 2's approach closely:

| Feature | Idris 2 | Πρόλογος Prototype (After) |
|---|---|---|
| Bidirectional checking | Yes | Yes (already) |
| Metavariables | Contextual metas | Named metas with ctx |
| Unification | Pattern + postponement | Pattern + postponement |
| Implicit args | `{x : T}` syntax | `:0` multiplicity syntax |
| Match | Case trees | Compiled to eliminators |
| Universe inference | Full | Full |
| Multiplicity inference | Partial (bodies) | Partial (bodies) |
| Error messages | Good | Target: excellent |

---

## 18. Post-Sprint Work: Features Beyond the 18-Week Plan

The 10 sprints above cover the core inference features for the functional layer and basic logic programming integration. The following Πρόλογος features require additional inference work that builds on the completed sprints:

### 18.1 Actor Concurrency Type Inference

Actor mailbox types are session-like (a protocol of expected messages), and the inference machinery from Sprint 8 (session types) can be extended to infer mailbox protocol states. Specifically:
- **Mailbox type inference**: When an actor's `receive` pattern matches messages of type `A`, infer `Mailbox(!A.S)`.
- **Spawn-site inference**: When `(spawn actor-fn)` is called, infer the actor function's mailbox type from its body's send/receive pattern.
- **Supervision tree types**: Infer that a supervisor's child type matches the spawned actor's protocol.

This requires extending Sprint 8's channel tracking to multi-party actor protocols, which is a 2–3 week effort after the base plan.

### 18.2 Propagator Network Type Constraints

Propagator cells have types (`Cell A`) and propagators have type signatures (`Propagator (Cell A) (Cell B)`). Inference for propagator networks involves:
- **Cell type inference**: When a cell is connected to multiple propagators, its type is constrained by all connected propagators — similar to how a variable's type is constrained by all usage sites.
- **Network consistency**: Verify that a propagator network's cell types form a consistent assignment. This is a constraint satisfaction problem solvable by the same unification engine from Sprint 2.
- **Scheduler interaction**: The propagator scheduler doesn't affect types, but the type of a network's output cells should be inferrable from the network definition.

This is a 1–2 week effort after the base plan, reusing the unification engine.

### 18.3 LLVM Compilation Implications

The inference plan affects the production compiler in two ways:
- **Erasure**: Solved implicit arguments that are erased (multiplicity 0) produce no LLVM code. The zonking pass in the prototype (Sprint 1) should tag which metavariable solutions are erased, providing metadata for the LLVM backend.
- **Monomorphization**: For polymorphic functions where the type argument is inferred, the LLVM backend must still monomorphize at call sites. The elaborated core term (after zonking) contains fully explicit type arguments, so monomorphization sees the same input regardless of whether the user wrote the type or inference filled it in.

---

## 19. References

Atkey, R. (2018). The Syntax and Semantics of Quantitative Type Theory. LICS 2018.

Brady, E. (2021). Idris 2: Quantitative Type Theory in Practice. ECOOP 2021.

Cockx, J., Devriese, D., & Piessens, F. (2016). Unifiers as Equivalences: Proof-Relevant Unification of Dependently Typed Data. ICFP 2016.

Dunfield, J. & Krishnaswami, N. (2021). Bidirectional Typing. ACM Computing Surveys, 54(5).

Dunfield, J. & Krishnaswami, N. (2013). Complete and Easy Bidirectional Typechecking for Higher-Rank Polymorphism. ICFP 2013.

Gay, S. & Hole, M. (2005). Subtyping for Session Types in the Pi Calculus. Acta Informatica, 42(2/3).

Goldfarb, W. (1981). The Undecidability of the Second-Order Unification Problem. Theoretical Computer Science, 13.

Kovács, A. (2024). smalltt: A Minimal, Efficient Elaborator. github.com/AndrasKovacs/smalltt.

McBride, C. (2003). First-Order Unification by Structural Recursion. Journal of Functional Programming, 13(6).

McBride, C. (2016). I Got Plenty o' Nuttin'. A List of Successes That Can Change the World.

Miller, D. (1991). A Logic Programming Language with Lambda-Abstraction, Function Variables, and Simple Unification. Journal of Logic and Computation, 1(4).

de Moura, L. & Ullrich, S. (2021). The Lean 4 Theorem Prover and Programming Language. CADE-28.

Norell, U. (2007). Towards a Practical Programming Language Based on Dependent Type Theory. PhD Thesis, Chalmers University.

Pierce, B.C. & Turner, D.N. (2000). Local Type Inference. ACM TOPLAS, 22(1).

Scalas, A. & Yoshida, N. (2019). Less Is More: Multiparty Session Types Revisited. POPL 2019.

Ziliani, B. & Sozeau, M. (2015). A Unification Algorithm for Coq Featuring Universe Polymorphism and Overloading. ICFP 2015.
