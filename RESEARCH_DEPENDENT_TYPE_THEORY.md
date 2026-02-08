# Research Report: Dependent Type Theory

## Foundations, Implementations, and Design Considerations for a Language with Dependent Types, Session Types, and Linear Types

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Historical Development](#2-historical-development)
3. [Core Formal Theory](#3-core-formal-theory)
   - 3.1 [Dependent Function Types (Π-types)](#31-dependent-function-types-π-types)
   - 3.2 [Dependent Pair Types (Σ-types)](#32-dependent-pair-types-σ-types)
   - 3.3 [Identity Types and Propositional Equality](#33-identity-types-and-propositional-equality)
   - 3.4 [Universes and Universe Polymorphism](#34-universes-and-universe-polymorphism)
   - 3.5 [Inductive Types and Inductive Families](#35-inductive-types-and-inductive-families)
4. [The Lambda Cube and Pure Type Systems](#4-the-lambda-cube-and-pure-type-systems)
   - 4.1 [Barendregt's Lambda Cube](#41-barendregts-lambda-cube)
   - 4.2 [Pure Type Systems as Generalization](#42-pure-type-systems-as-generalization)
5. [Propositions as Types (Curry-Howard-Lambek)](#5-propositions-as-types-curry-howard-lambek)
   - 5.1 [Extension to Dependent Types](#51-extension-to-dependent-types)
   - 5.2 [Proof Terms and Evidence](#52-proof-terms-and-evidence)
   - 5.3 [Proof Irrelevance](#53-proof-irrelevance)
   - 5.4 [Decidability of Type Checking vs. Completeness](#54-decidability-of-type-checking-vs-completeness)
6. [Homotopy Type Theory and Univalent Foundations](#6-homotopy-type-theory-and-univalent-foundations)
   - 6.1 [The Univalence Axiom](#61-the-univalence-axiom)
   - 6.2 [Higher Inductive Types](#62-higher-inductive-types)
   - 6.3 [Cubical Type Theory](#63-cubical-type-theory)
7. [Proof Assistants and Their Type Theories](#7-proof-assistants-and-their-type-theories)
   - 7.1 [Coq/Rocq](#71-coqrocq-calculus-of-inductive-constructions)
   - 7.2 [Agda](#72-agda-intensional-martin-löf-type-theory)
   - 7.3 [Lean 4](#73-lean-4)
   - 7.4 [Idris 2](#74-idris-2-quantitative-type-theory)
   - 7.5 [F*](#75-f-f-star)
   - 7.6 [Dafny](#76-dafny)
   - 7.7 [Isabelle/HOL](#77-isabellehol)
8. [Dependent Types in Mainstream-Adjacent Languages](#8-dependent-types-in-mainstream-adjacent-languages)
   - 8.1 [Haskell](#81-haskell)
   - 8.2 [Scala 3](#82-scala-3)
   - 8.3 [Rust](#83-rust)
   - 8.4 [TypeScript](#84-typescript)
9. [Key Implementation Challenges](#9-key-implementation-challenges)
   - 9.1 [Decidability of Type Checking](#91-decidability-of-type-checking)
   - 9.2 [Elaboration](#92-elaboration-from-surface-syntax-to-core-terms)
   - 9.3 [Unification and Higher-Order Unification](#93-unification-and-higher-order-unification)
   - 9.4 [Normalization Strategies](#94-normalization-strategies)
   - 9.5 [Termination Checking](#95-termination-checking)
   - 9.6 [Compilation Strategies](#96-compilation-strategies)
   - 9.7 [Bidirectional Type Checking](#97-bidirectional-type-checking)
10. [Linear Type Theory](#10-linear-type-theory)
    - 10.1 [Girard's Linear Logic](#101-girards-linear-logic)
    - 10.2 [Substructural Type Systems](#102-substructural-type-systems)
    - 10.3 [Rust's Ownership Model](#103-rusts-ownership-model)
    - 10.4 [Linear Haskell](#104-linear-haskell)
    - 10.5 [Memory Safety Through Linearity](#105-memory-safety-through-linearity)
11. [Session Types](#11-session-types)
    - 11.1 [Honda's Binary Session Types](#111-hondas-binary-session-types)
    - 11.2 [Multiparty Session Types (MPST)](#112-multiparty-session-types)
    - 11.3 [Deadlock Freedom and Cut Elimination](#113-deadlock-freedom-and-cut-elimination)
    - 11.4 [Session Types as π-Calculus Typing](#114-session-types-as-π-calculus-typing)
12. [Combining Dependent Types with Linear and Session Types](#12-combining-dependent-types-with-linear-and-session-types)
    - 12.1 [Quantitative Type Theory (QTT)](#121-quantitative-type-theory)
    - 12.2 [Graded Modal Type Theory](#122-graded-modal-type-theory)
    - 12.3 [The Granule Language](#123-the-granule-language)
    - 12.4 [Dependent Session Types](#124-dependent-session-types)
    - 12.5 [The Dependency-Through-Linearity Problem](#125-the-dependency-through-linearity-problem)
13. [Protocol Verification and Correctness](#13-protocol-verification-and-correctness)
    - 13.1 [Behavioral Types](#131-behavioral-types)
    - 13.2 [Typestate Programming](#132-typestate-programming)
    - 13.3 [Refinement Types for Protocols](#133-refinement-types-for-protocols)
14. [Memory Safety Through Type Systems](#14-memory-safety-through-type-systems)
    - 14.1 [Linear/Affine Types for Memory Safety](#141-linearaffine-types-for-memory-safety)
    - 14.2 [Region-Based Memory Management](#142-region-based-memory-management)
    - 14.3 [Capabilities and Separation Logic](#143-capabilities-and-separation-logic)
15. [Design Considerations for a New Language](#15-design-considerations-for-a-new-language)
    - 15.1 [Making Dependent Types Practical](#151-making-dependent-types-practical)
    - 15.2 [Balancing Expressiveness with Decidability](#152-balancing-expressiveness-with-decidability)
    - 15.3 [Integration Strategies](#153-integration-strategies)
    - 15.4 [Full Dependent Types vs. Refinement Types](#154-full-dependent-types-vs-refinement-types)
16. [References and Key Literature](#16-references-and-key-literature)

---

## 1. Introduction

This report presents an extensive survey of Dependent Type Theory — its mathematical foundations, practical implementations, and the design space for integrating dependent types with session types and linear types in a new programming language. The goal is to inform the design of a language where dependent types are first-class citizens, session types enforce protocol correctness, and linear types provide memory-safety guarantees.

Dependent Type Theory represents one of the most significant developments in mathematical logic and computer science, unifying logic and computation through the Curry-Howard correspondence, enabling types to express arbitrary mathematical properties, and providing a foundation for program verification that is simultaneously a programming paradigm.

The report is organized in three major arcs. The first arc (Sections 2–9) covers Dependent Type Theory itself: its history, formal theory, the landscape of implementations, and the key engineering challenges. The second arc (Sections 10–14) covers linear types and session types: their foundations, their guarantees, and the state of the art in combining them with dependent types. The third arc (Section 15) synthesizes these threads into concrete design considerations for a new language.

---

## 2. Historical Development

### 2.1 Origins: Martin-Löf's Intuitionistic Type Theory (1971–1984)

Dependent Type Theory emerged from Per Martin-Löf's groundbreaking work on Intuitionistic Type Theory (ITT). Martin-Löf's journey began with MLTT71, a 1971 preprint that attempted to create the first type theory generalizing Girard's System F. This initial system proved inconsistent due to Girard's paradox, revealing that one cannot simultaneously have a type of types (`Type : Type`), impredicativity, and polymorphic quantification.

The critical breakthrough came with MLTT79 (presented in 1979, published in 1982), which introduced the four fundamental forms of judgment that underpin all subsequent dependent type systems:

- **Type judgments**: Γ ⊢ A : 𝒰 (A is a well-formed type in context Γ)
- **Term judgments**: Γ ⊢ a : A (a is a term of type A)
- **Equality judgments**: Γ ⊢ a ≡ b : A (a and b are definitionally equal)
- **Type equality judgments**: Γ ⊢ A ≡ B : 𝒰 (A and B are the same type)

Martin-Löf's innovation was extending the Curry-Howard isomorphism to predicate logic through dependent types. While simple type theory could express propositional logic, the introduction of types that depend on values enabled the expression of first-order logic and stronger systems.

The 1984 Bibliopolis book solidified the philosophical foundations through Martin-Löf's *meaning explanation* — a proof-theoretic semantics justifying predicative type theory. A crucial distinction emerged: the 1984 theory was **extensional** (treating propositional equality as definitional equality), while subsequent developments produced an **intensional** type theory more amenable to implementation. This distinction remains central to all modern developments.

### 2.2 De Bruijn's Automath (1967–1968)

Nicolaas Govert de Bruijn's Automath system, conceived in 1967–1968, was one of the earliest practical implementations of dependent types. Automath was the first proof assistant actually used in practice and the first theorem prover to check specimens of real mathematical content. It pioneered dependent types as a core feature for type-checking mathematical expressions, the Curry-Howard correspondence applied practically (propositions represented as sets of their proofs), and proof checking via type checking as a reduction principle. De Bruijn's syntactic ideas directly inspired Thierry Coquand and Gérard Huet to develop the Calculus of Constructions.

### 2.3 The Curry-Howard Correspondence and Its Extension

The Curry-Howard correspondence, established by Haskell Curry and William Howard, provides the fundamental connection: programs correspond to proofs, and types correspond to propositions. In simple type theory, simple function types (α → β) correspond to logical implication (α ⊃ β), lambda abstractions correspond to proof constructions, and function application corresponds to modus ponens.

Howard and de Bruijn independently extended this to dependent types:

- Universal quantifier ∀x : A. P(x) maps to Π(x : A). P(x)
- Existential quantifier ∃x : A. P(x) maps to Σ(x : A). P(x)

This extension was revolutionary because it allowed types to express arbitrary mathematical properties — for instance, "for all vectors v of length n, their transpose has length n."

### 2.4 Coquand and the Calculus of Constructions (1985–1988)

The Calculus of Constructions (CoC), introduced by Thierry Coquand in his 1985 PhD thesis under Gérard Huet and published in 1988, synthesizes Martin-Löf type theory with higher-order polymorphism. The CoC occupies the apex of Barendregt's Lambda Cube — the highest point of expressivity in the systematized hierarchy of typed lambda calculi. It combines Martin-Löf's dependent types, System F's polymorphic types, and higher-order quantification over types. When supplemented with inductive types, it becomes the Calculus of Inductive Constructions (CIC), the theoretical foundation of the Coq (now Rocq) proof assistant.

### 2.5 The Edinburgh Logical Framework (1986–1987)

Robert Harper, Furio Honsell, and Gordon Plotkin developed the Edinburgh Logical Framework (LF), introducing the "judgments as types" principle: each logical judgment is identified with the type of its proofs, and rules are viewed as proofs of higher-order judgments. The LF became the basis for the Twelf system and exemplified how dependent types could serve as a meta-language for formal systems themselves.

---

## 3. Core Formal Theory

### 3.1 Dependent Function Types (Π-types)

A dependent function type represents a function whose return type varies with its input value. Given A : 𝒰 and a type family B : A → 𝒰, the dependent product type Π(x : A). B(x) denotes the type of functions f such that for each a : A, we have f(a) : B(a). When B does not depend on x, this reduces to the simple function type A → B.

**Typing Rules:**

```
Formation:
  Γ ⊢ A : 𝒰ᵢ    Γ, x : A ⊢ B : 𝒰ᵢ
  ─────────────────────────────────────
  Γ ⊢ Π(x : A). B : 𝒰ᵢ

Introduction (λ-abstraction):
  Γ, x : A ⊢ b : B[x]
  ─────────────────────────────
  Γ ⊢ λ(x : A). b : Π(x : A). B

Elimination (application):
  Γ ⊢ f : Π(x : A). B    Γ ⊢ a : A
  ──────────────────────────────────
  Γ ⊢ f(a) : B[a/x]

Computation (β-reduction):
  (λ(x : A). b)(a) ≡ b[a/x]
```

In the Curry-Howard interpretation, Π-types directly correspond to universal quantification. A proof of ∀x : A. P(x) is a dependent function that, given any a : A, produces a proof of P(a).

### 3.2 Dependent Pair Types (Σ-types)

A dependent pair type represents a pair whose second component's type depends on the first component's value. Given A : 𝒰 and B : A → 𝒰, the dependent sum Σ(x : A). B(x) represents pairs (a, b) where a : A and b : B(a).

**Typing Rules:**

```
Formation:
  Γ ⊢ A : 𝒰ᵢ    Γ, x : A ⊢ B : 𝒰ᵢ
  ──────────────────────────────────
  Γ ⊢ Σ(x : A). B : 𝒰ᵢ

Introduction (pairing):
  Γ ⊢ a : A    Γ ⊢ b : B[a/x]
  ────────────────────────────────
  Γ ⊢ (a, b) : Σ(x : A). B

Elimination (projections):
  Γ ⊢ p : Σ(x : A). B
  ───────────────────
  Γ ⊢ π₁(p) : A
  Γ ⊢ π₂(p) : B[π₁(p)/x]

Computation:
  π₁((a, b)) ≡ a
  π₂((a, b)) ≡ b
```

The Curry-Howard correspondence identifies Σ-types with existential quantification: a proof of ∃x : A. P(x) is a witness a : A paired with evidence p : P(a).

### 3.3 Identity Types and Propositional Equality

The identity type Id_A(a, b) represents proofs of equality between elements a and b of type A. Unlike definitional equality (syntactic reduction), identity types formalize *propositional* equality — equality as evidence that can be passed around and reasoned about. It is defined inductively with a single constructor:

```
refl : Id_A(a, a)
```

**The J-Eliminator:** The fundamental elimination principle, proposed by Martin-Löf in 1975. Given P : (y : A) → (p : Id_A(a, y)) → 𝒰 and base_case : P(a, refl(a)), the J-eliminator produces:

```
J : (y : A) → (p : Id_A(a, y)) → P(y, p)
```

with computation rule J(a, refl(a), base_case) ≡ base_case. To prove a property P holds for all equalities p : Id_A(a, y), it suffices to prove it for reflexivity.

**Transport:** A key consequence is the transport operation. If P is a type family over A and p : Id_A(a, b), then:

```
transport(P, p) : P(a) → P(b)
```

This formalizes the intuition that if a and b are equal, any property holding of a should hold of b.

**Intensional vs. Extensional Type Theory:**

- **Intensional**: Identity is not identified with definitional equality. Type checking is decidable, but standard facts like function extensionality require explicit axioms.
- **Extensional**: Identity is identified with definitional equality through the reflection rule. Type checking becomes undecidable, but mathematical reasoning is simplified.

This choice represents a fundamental trade-off between computational efficiency (decidability) and mathematical expressivity.

### 3.4 Universes and Universe Polymorphism

**The Type : Type Problem:** The naive approach of allowing Type : Type leads to Girard's paradox (1972), showing that one cannot simultaneously have a type of types, impredicativity, and polymorphic quantification. Martin-Löf's response was to introduce a predicative hierarchy:

```
Type₀ : Type₁ : Type₂ : Type₃ : ...
```

Universe cumulativity ensures Type₀ ⊆ Type₁ ⊆ Type₂, allowing elements of lower universes to be used in higher ones. **Universe polymorphism** allows definitions to be parametric over universe levels:

```
List : (ℓ : Level) → Type ℓ → Type ℓ
```

This enables a single definition to work uniformly across all universe levels without duplication.

### 3.5 Inductive Types and Inductive Families

Inductive types are defined by their constructors and induction principles. The type is the least fixed point containing exactly those values constructible through its constructors. The **strict positivity** requirement is critical to consistency: if a type T occurs in a constructor's argument, it must appear only strictly positively (never to the left of a function arrow at top level), preventing paradoxes.

**W-types** (well-founded types) provide a general encoding mechanism. Given A : Type and B : A → Type, the W-type W(A, B) represents well-founded trees where nodes are labeled by A and a node with label a has B(a) children. Any strictly positive inductive type can be represented using W-types.

**Indexed inductive families** simultaneously define a family of mutually-dependent types indexed by another type:

```
Vec : ℕ → Type → Type
nil  : ∀ {A} → Vec 0 A
cons : ∀ {n A} → A → Vec n A → Vec (n + 1) A
```

Each constructor specifies which indices are produced, enabling type-level invariants to be encoded directly.

---

## 4. The Lambda Cube and Pure Type Systems

### 4.1 Barendregt's Lambda Cube

Henk Barendregt's Lambda Cube organizes typed lambda calculi along three independent dimensions of type dependency, yielding 2³ = 8 systems:

- **Dimension 1 — Types depending on terms (Π)**: Types like "vectors of length n" where the type depends on a term value.
- **Dimension 2 — Terms depending on types (∀)**: Polymorphic functions like `identity : ∀α. α → α`.
- **Dimension 3 — Types depending on types (λ)**: Type operators like `List : Type → Type`.

The eight vertices:

| System | Name | Features |
|--------|------|----------|
| λ→ | Simply Typed Lambda Calculus | Terms depending on terms only |
| λ2 | System F | + Polymorphism (terms on types) |
| λω_ | Weak ω | + Type operators (types on types) |
| λΠ | LF | + Dependent types (types on terms) |
| λ2ω | System Fω | Polymorphism + type operators |
| λΠ2 | — | Dependent types + polymorphism |
| λΠω_ | — | Dependent types + type operators |
| λΠ2ω / λC | Calculus of Constructions | All three dimensions combined |

The Calculus of Constructions sits at the apex, combining all three forms of dependency.

### 4.2 Pure Type Systems as Generalization

Pure Type Systems (PTS) generalize the Lambda Cube by parameterizing over:

- **S**: An arbitrary set of sorts
- **A ⊆ S × S**: Axioms specifying valid sort ascriptions
- **R ⊆ S × S × S**: Rules specifying valid Π-type formations

```
(s₁, s₂) rule: If Γ ⊢ A : s₁ and Γ, x : A ⊢ B : s₂,
                then Γ ⊢ Π(x : A). B : s₂
```

All eight Lambda Cube systems are expressible as PTS with S = {*, □} and appropriate axiom/rule sets. A key property: all Lambda Cube systems are strongly normalizing (all computations terminate), making type checking decidable. Arbitrary PTS need not satisfy this property.

---

## 5. Propositions as Types (Curry-Howard-Lambek)

### 5.1 Extension to Dependent Types

The Curry-Howard correspondence, generalized through dependent types, establishes:

| Logic | Type Theory |
|-------|-------------|
| ∀x : A. P(x) | Π(x : A). P(x) |
| ∃x : A. P(x) | Σ(x : A). P(x) |
| P ∧ Q | P × Q |
| P ∨ Q | P + Q |
| P ⊃ Q | P → Q |
| ⊥ (Falsehood) | ∅ (Empty type) |
| ⊤ (Truth) | () (Unit type) |

This identification is deep: constructive proofs in intuitionistic logic are literally programs, and logical rules correspond to typing rules.

Joachim Lambek demonstrated that intuitionistic propositional logic, the typed λ-calculus, and Cartesian closed categories share a common equational theory — the Curry-Howard-Lambek correspondence unifying logic, computation, and category theory.

### 5.2 Proof Terms and Evidence

A proof term is a computational object encoding not just *that* a proposition is true, but precisely *how* it is true. For example, the proposition ∀n : ℕ. ∃m : ℕ. m > n corresponds to:

```
witness : (n : ℕ) → (m : ℕ) × (m > n)
witness n = (n + 1, proof_that_succ_n_gt_n)
```

Running this program produces concrete evidence — the constructive content of the proof.

### 5.3 Proof Irrelevance

In some contexts, we care only that a proposition has a proof (proof irrelevance), while in others, proof terms carry computational content (proof relevance). For instance, in a sorting algorithm, the proof that the output is sorted might directly encode the permutation (relevant), while a proof that a list is non-empty for safe `head` access only needs to exist (irrelevant).

Modern systems like Rocq and Agda support definitional proof irrelevance, where certain proofs are erased at runtime while maintaining decidable type checking.

### 5.4 Decidability of Type Checking vs. Completeness

In **intensional type theory**, type checking is decidable: definitional equality is decided through syntactic reduction (β, η), which always terminates. In **extensional type theory**, the reflection rule makes type checking undecidable — determining definitional equality may require infinite search. Most implemented systems choose intensional type theory, then extend it with compatible axioms (function extensionality, quotient types) while preserving decidability.

---

## 6. Homotopy Type Theory and Univalent Foundations

### 6.1 The Univalence Axiom

Homotopy Type Theory (HoTT) reinterprets Martin-Löf type theory through homotopy theory: types as spaces, terms as points, equalities as paths, and higher equalities as homotopies. The univalence axiom, due to Vladimir Voevodsky, states:

```
univalence : (A =𝒰 B) ≃ (A ≃ B)
```

For any two types A and B in a universe 𝒰, the identity type (A =𝒰 B) is equivalent to the type of equivalences (A ≃ B). This formalizes the mathematical practice of treating isomorphic structures as equal. Voevodsky proved that univalence implies function extensionality.

### 6.2 Higher Inductive Types

Higher Inductive Types (HITs) extend ordinary inductive types by allowing constructors for equalities themselves. For example, the circle S¹:

```
data S¹ : Type where
  base : S¹
  loop : base = base
```

This has one point (`base`) and a non-trivial loop, directly encoding topological structure. HITs enable direct definition of cell complexes, quotient types, homotopy colimits, and algebraic topology constructions.

### 6.3 Cubical Type Theory

Cubical Type Theory, developed by Coquand and collaborators, provides a computational interpretation of univalence. Rather than abstract paths, it uses explicit paths through an interval type [0,1]:

- Path types are functions from the interval
- Equality checking exploits interval structure
- Univalence is implemented through transport operations

Key benefits: **canonicity** (closed terms reduce to canonical forms), **decidability** (type checking remains decidable despite univalence), and **computability** of higher inductive types. Implementations include Cubical Agda and redtt.

---

## 7. Proof Assistants and Their Type Theories

### 7.1 Coq/Rocq: Calculus of Inductive Constructions

Coq (recently rebranded as Rocq) is founded on the Calculus of Inductive Constructions (CIC), extending the Calculus of Constructions with inductive types. The system features confluence, strong normalization, and subject reduction. Coq is notably tactic-based: rather than writing proofs as terms directly, users manipulate proof state step-by-step. Its extraction capability converts verified programs to efficient OCaml, Haskell, or Scheme code. The CompCert certified C compiler is among its landmark applications. Recent developments include a verified extraction pipeline through an untyped intermediate representation (λ□) to OCaml bytecode.

### 7.2 Agda: Intensional Martin-Löf Type Theory

Agda is based on intensional Martin-Löf type theory extended with dependent pattern matching, termination checking, and universe polymorphism. Pattern matching in Agda is dependent, enabling type-level reasoning. The termination checker verifies that recursive calls are made on structurally smaller arguments, maintaining totality and type system consistency. Universe polymorphism uses a primitive `Level` type, allowing functions to be polymorphic in universe level. Cubical Agda adds native support for univalence, higher inductive types, and direct manipulation of n-dimensional cubes and paths.

### 7.3 Lean 4

Lean 4 is built on a variant of the Calculus of Constructions with a non-cumulative universe hierarchy (Prop, Type 0, Type 1, ...) and native inductive types. Its metaprogramming architecture is organized around monads (CoreM, MetaM, TermElabM, TacticM), enabling extension of the parser, elaborator, tactics, and code generator. The mathlib library contains over 210,000 formalized theorems with broad mathematical coverage. Lean compiles to C code, enabling efficient execution.

### 7.4 Idris 2: Quantitative Type Theory

Idris 2 introduces Quantitative Type Theory (QTT), integrating linearity into the dependent type system through multiplicities:

- **0**: Erased at runtime (compile-time only)
- **1**: Linear (used exactly once)
- **ω**: Unrestricted (any number of uses)

This enables reasoning about runtime relevance, resource consumption, and state changes within a unified framework. QTT avoids the traditional bifurcation between "dependent types" and "linear types" by making both instances of the same multiplicity-based framework. Idris 2 supports elaborator reflection — metaprogramming where the elaboration machinery is directly available to user code.

### 7.5 F* (F-star)

F* is a dependently typed, higher-order, call-by-value language integrating primitive effects (state, exceptions, divergence, I/O). Programmers specify effect granularity through monadic predicate transformer semantics, enabling efficient weakest precondition computation. F* uses refinement types — regular types endowed with predicates restricting admissible values — combined with SMT solvers to discharge verification conditions automatically. It has verified critical cryptographic implementations and supports extraction to OCaml, C, F#, and WebAssembly.

### 7.6 Dafny

Dafny is a verification-aware language using the Boogie intermediate verification language and the Z3 SMT solver. It supports subset types (a form of dependent typing with predicate-restricted types) and automatic verification through SMT solving. Verification conditions are generated via weakest precondition calculus and encoded in first-order logic. Dafny provides mathematical integers, reals, bit-vectors, sequences, sets, induction, co-induction, and calculational proofs.

### 7.7 Isabelle/HOL

Isabelle is a higher-order logic theorem prover featuring the Isar proof language ("intelligible semi-automated reasoning"), which enables declarative proofs specifying actual mathematical operations. It combines efficient automatic reasoning (term rewriting, tableaux proving) with decision procedures and the Sledgehammer interface to external SMT solvers and automated theorem provers.

---

## 8. Dependent Types in Mainstream-Adjacent Languages

### 8.1 Haskell

Haskell emulates dependent types through GADTs (type constructors that depend on type parameters), type families (type-level functions), DataKinds (promoting data types to the kind level), and the singletons pattern (bridging term and type levels). Active proposals for full dependent type support ("Dependent Haskell") exist but face challenges with GHC's type theory, compilation/runtime representation, and backward compatibility.

### 8.2 Scala 3

Scala 3 introduced match types (type-level pattern matching), dependent function types (return types depending on value arguments), path-dependent types, and opaque types (type abstraction without runtime overhead). These enable practical dependent typing while maintaining JVM interoperability.

### 8.3 Rust

Rust's const generics parameterize types by constant values at compile-time (e.g., array types parameterized by length). The typestate pattern moves state properties into the type level, using generics to parameterize objects over state and traits to define state-associated behavior. Combined with Rust's ownership model, this provides significant compile-time guarantees with zero runtime overhead.

### 8.4 TypeScript

TypeScript's template literal types, conditional types, and mapped types enable sophisticated type-level computation. Template literals expand string literal types via unions; conditional types support type-level if-then-else; mapped types transform properties of existing types. These features enable statically typing highly dynamic JavaScript patterns, though TypeScript remains fundamentally runtime-erased.

---

## 9. Key Implementation Challenges

### 9.1 Decidability of Type Checking

Dependent types make type inference undecidable in general (reducible to the Post Correspondence Problem), since deciding type equality may require executing arbitrary programs. Practical approaches include termination restrictions (only total, terminating code in types), effect restrictions (terms in types must be effect-free), and size annotations for decidable constraint solving.

### 9.2 Elaboration: From Surface Syntax to Core Terms

Elaboration transforms partially-specified surface expressions into completely precise core terms. It must infer implicit information, resolve ambiguities, and convert convenient surface syntax to formal core theory. State-of-the-art elaborators (e.g., Lean's) employ higher-order unification, type class inference, ad hoc overloading, coercions, tactic invocation, nonchronological backtracking, and heuristics for unfolding definitions.

### 9.3 Unification and Higher-Order Unification

Type checking and inference in dependent type systems rely heavily on unification. **Miller's pattern unification** identifies a decidable fragment of higher-order unification where metavariables are applied to distinct bound variables only, maintaining decidability, unarity (unique solutions), and type-freeness. The **Functions-as-Constructors (FCU)** extension allows arguments constructed from bound variables using term constructors, increasing expressiveness while preserving decidability.

### 9.4 Normalization Strategies

**Normalization by Evaluation (NbE)** obtains normal forms by evaluating terms semantically and then reifying the results back to syntax. It is more efficient than naive substitution-based reduction, avoids capture-avoiding substitution complexity, and produces η-long normal forms for easier equality checking. Many systems use **weak-head normal form (WHNF)** for practical efficiency, stopping reduction early and deferring full normalization.

### 9.5 Termination Checking

Ensuring recursive programs terminate is critical for type system consistency. Approaches include **structural recursion** (recursive calls on strict subexpressions), **sized types** (type annotations encoding size information), and **well-founded relations** (recursion on custom well-founded orderings proven terminating). Each represents a different trade-off between simplicity and generality.

### 9.6 Compilation Strategies

Key approaches to compiling dependently typed programs:

- **Proof erasure**: Remove logical content that cannot affect computation (proofs, compile-time-only data with multiplicity 0)
- **Extraction** (Coq/Rocq): Transform to high-level language with minimal structural alteration; verified pipeline through λ□ to OCaml
- **Direct compilation** (Lean): Compile to C code for better performance optimization
- **Type-preserving compilation**: Preserve dependent type information through compilation, enabling type checking at link time

### 9.7 Bidirectional Type Checking

Bidirectional checking distinguishes between **checking mode** (context, term, and type are inputs → verify term has type) and **synthesis mode** (context and term are inputs → derive type). This provides a framework for managing type inference complexity, handling implicit arguments via pattern unification, and resolving type class instances. It is the practical key to making dependent type inference usable.

---

## 10. Linear Type Theory

### 10.1 Girard's Linear Logic

Linear Logic, introduced by Jean-Yves Girard in 1987, treats logical assumptions as finite resources consumed during proof. Its connectives are organized as:

- **Multiplicatives** (⊗, ⅋, 1, ⊥): Real consumption/production of resources
- **Additives** (&, ⊕, ⊤, 0): Choice operators
- **Exponentials** (!, ?): Control replication of resources

Variables are used exactly once because the contraction rule (duplication) and weakening rule (discard) are absent. The cut-elimination theorem in linear logic corresponds to meaningful operational semantics — in the context of session types, cut elimination translates directly to process reduction in concurrent systems.

### 10.2 Substructural Type Systems

Substructural type systems form a family where one or more structural rules are controlled:

- **Linear types**: A resource must be used *exactly once*. No contraction, no weakening. Strongest guarantees for resource tracking.
- **Affine types**: A resource can be used *at most once* (0 or 1). Allows weakening but not contraction. Rust uses this model.
- **Relevant types**: A resource must be used *at least once*. Allows contraction but not weakening. Ensures all resources are accessed.
- **Ordered types**: Variables must be used in the order introduced. No exchange, contraction, or weakening. Corresponds to noncommutative logic.

**Clean's uniqueness types** pioneered a practical variant of linear types: the compiler guarantees that only one reference to a data structure exists at runtime, enabling safe in-place mutation for concurrency and I/O.

### 10.3 Rust's Ownership Model

Rust implements an affine type system through its ownership model:

1. Each value has a single, unique owner
2. When the owner goes out of scope, the value is automatically deallocated
3. Ownership can be transferred (moved) but not duplicated
4. Borrowing allows temporary access without ownership transfer; mutable references are exclusive

This prevents use-after-free (references cannot outlive their owning value), double-free (free is called exactly once), and data races (mutable access is exclusive). The compiler automatically inserts deallocation code at the precise point where ownership ends.

### 10.4 Linear Haskell

Linear Haskell extends the type system by attaching linearity to function arrows:

```haskell
f :: a %1 -> b
```

A function is linear if, when its result is consumed exactly once, its argument is consumed exactly once. GHC treats non-variable lazy patterns as consuming their scrutinee with multiplicity Many (unrestricted), allowing lazy evaluation and linear types to coexist. The `linear-base` library provides resource-safe file/socket I/O and safe in-place array mutation.

### 10.5 Memory Safety Through Linearity

Linear and affine types prevent memory errors at the type level:

- **Use-after-free**: A linear pointer can only be used once; any attempt to reuse a consumed pointer is a type error.
- **Double-free**: `free` is called exactly once per allocation by typing it as consuming a linear capability.
- **Memory leaks**: Values leaving scope without being consumed are type errors, forcing explicit resource accounting.

Many systems pair pointers with linear capabilities:

```
malloc : ∀(n : Nat) → 1.(Ptr, Capability n)
free   : ∀(n : Nat) → Capability n → Ptr → 1.()
```

---

## 11. Session Types

### 11.1 Honda's Binary Session Types

Session types, introduced by Kohei Honda, provide a type discipline for enforcing communication protocols in concurrent, message-passing systems. A binary session type involves exactly two participants, specifying the direction of each message, the type of the message, and the subsequent session type.

**Type duality** is fundamental: if one process has session type T, its communication partner has the dual type T̄ with sends and receives swapped:

```
T  = !Int.?String.end
T̄  = ?Int.!String.end
```

Binary session types guarantee type safety (messages match expected types), session fidelity (communication follows the specified protocol), and progress (well-typed processes don't get stuck).

### 11.2 Multiparty Session Types

Multiparty Session Types (MPST), introduced by Honda, Yoshida, and Carbone (POPL 2008), generalize binary session types to systems with more than two participants. The protocol is first specified as a **global type**:

```
G = A → B : int . B → C : string . end
```

From the global type, **local types** are derived for each participant through endpoint projection. MPST guarantee protocol compliance, deadlock freedom, and session fidelity across multi-party interactions.

### 11.3 Deadlock Freedom and Cut Elimination

The connection between cut elimination in linear logic and deadlock-freedom in session types is profound and operational. Cut elimination in linear logic corresponds to process reduction — two processes communicating along a channel synchronize and reduce.

Approaches to deadlock avoidance include cycle prohibition (communication forms a DAG), Kobayashi's type system (allows cyclic interconnections without cyclic communication dependencies), and subtyping-based approaches controlling communication order.

### 11.4 Session Types as π-Calculus Typing

Session types can be understood as a typing discipline for the π-calculus that enforces protocol compliance. A session type assigns to each channel the type of values it carries, the direction and order of communications, and whether further communications are expected. Type checking at the session level is simpler than full π-calculus verification while providing strong guarantees.

---

## 12. Combining Dependent Types with Linear and Session Types

### 12.1 Quantitative Type Theory

Quantitative Type Theory (QTT), the foundation of Idris 2, unifies dependent types with resource tracking through multiplicities. Each variable binding has a multiplicity — a semiring element describing how the variable can be used:

- **0**: Erased at compile-time (not used at runtime)
- **1**: Used exactly once (linear)
- **ω**: Unrestricted (any number of times)

QTT works over an arbitrary semiring, allowing simple binary (0/1/ω) systems, counting multiplicities (natural numbers), or custom resource algebras. Dependent-type arguments typically have multiplicity 0 (erased), while linear resources have multiplicity 1:

```idris
process : {0 prf : Proof P} → (1 x : Resource) → Result
```

QTT demonstrates how to unify dependent types with resource tracking without bifurcating the type system. Rather than "dependent types OR linear types," it provides a single framework where both are instances of a more general principle.

### 12.2 Graded Modal Type Theory

Graded modal type theory extends modal type theory by parameterizing modalities over a *grade* — an element of an ordered structure (semiring, lattice, etc.). While modal type theory provides a single modality, graded modalities allow fine-grained resource analysis. Applications include variable usage tracking, execution cost quantification, privacy/information flow tracking, and stateful protocol modeling.

Coeffects (the dual of effects) describe how computations depend on their context. Graded modalities provide a type-theoretic foundation for coeffect systems: a coeffect type describes not what a computation does (effects) but what it requires from its context.

### 12.3 The Granule Language

Granule is a functional programming language implementing graded modal types combined with linear types. Based on the linear λ-calculus augmented with graded modal types, it uses resource algebras to track fine-grained resource information. Resource algebras in Granule include natural numbers (counting variable uses), custom algebras (stateful protocols), and compositions of multiple algebras.

Granule demonstrates that graded modalities are practical: type inference remains feasible, and real programs benefit from fine-grained resource tracking for privacy reasoning, stateful protocols, cost analysis, and controlled non-linearity.

### 12.4 Dependent Session Types

Dependent session types extend session types so that protocol specifications can depend on communicated values. Many real protocols have structure that depends on runtime values:

- **Length-prefixed messages**: "Send N, then N strings"
- **Variant protocols**: "Send a command, then behave differently based on it"
- **Negotiated protocols**: "Send capabilities, then receive a matching protocol"

```
ProcessMessages : Nat → SessionType
ProcessMessages 0     = End
ProcessMessages (n+1) = Recv Int (λ_ → ProcessMessages n)
```

Dependent session types guarantee type safety, session fidelity, progress, and enable proof exchange (processes can exchange proof objects verifying protocol properties). However, decidability of type checking, inference complexity, and deadlock-freedom verification all become harder with dependent structure.

### 12.5 The Dependency-Through-Linearity Problem

A fundamental challenge arises when a type depends on a linear value: what happens to the dependency when the linear value is consumed?

```
f : (1 x : τ) → (T x) → Result
```

Here, the type of the second argument depends on x, but x is consumed by the first argument. Solutions include:

1. **Restrict dependency**: Disallow types from depending on linear values (simpler but less expressive).
2. **Dependency erasure**: Allow dependency but erase dependent arguments at runtime (maintains expressiveness but complicates theory).
3. **Separation**: Keep dependent and linear types in separate fragments (proven to work in Idris 2 and Granule).

The Idris 2 approach resolves this elegantly: dependent arguments typically have multiplicity 0 (erased), while linear arguments have multiplicity 1. This separation avoids the problem while maintaining expressiveness in practice.

---

## 13. Protocol Verification and Correctness

### 13.1 Behavioral Types

Behavioral types track how an object or process evolves over time, describing not just available operations but the order in which they can be invoked, what state transitions occur, and what operations are invalid in certain states. Session types are a specific instance focused on communication protocols. Behavioral types provide the "sweet spot" for protocol verification: sufficient expressiveness for practical properties while remaining decidable and efficient.

### 13.2 Typestate Programming

Typestate analysis, introduced by Rob Strom in 1983, models each type as a finite-state machine where each state has a distinct set of permitted operations. With dependent types, typestate is natural to express:

```
File : FileState → Type
open  : File Closed → File Open
read  : File Open → Bytes × File Open
close : File Open → File Closed
```

The type system prevents reading from a closed file or closing an already-closed file at compile time.

### 13.3 Refinement Types for Protocols

Refinement types combine a base type with a logical predicate restricting admissible values: `{x : τ | P(x)}`. They remain decidable (via SMT solvers) while providing significant expressive power for protocol properties. LiquidHaskell uses Z3 for automatic verification; F* combines refinement types with theorem proving for properties beyond decidable fragments. Refinement types offer simpler type checking, better automation, and more predictable behavior than full dependent types, but cannot express arbitrary dependent properties.

---

## 14. Memory Safety Through Type Systems

### 14.1 Linear/Affine Types for Memory Safety

Linear and affine types prevent memory errors at the type level:

- **Use-after-free**: Consumed pointers cannot be reused (type error).
- **Double-free**: `free` consumes a linear capability, callable only once.
- **Memory leaks**: Unconsumed values at scope exit are type errors.

Capability-based approaches pair pointers with linear capabilities, ensuring only the holder can deallocate, the capability is unique, and the capability cannot be duplicated.

### 14.2 Region-Based Memory Management

Region-based memory management divides the heap into regions deallocated as units, typically following a stack discipline. MLKit pioneered region inference for Standard ML. Cyclone extended C with region-based management combined with linear types, ensuring pointers don't outlive their regions. Benefits include predictable memory layout, efficient usage, and no runtime GC overhead. Linear types prevent following pointers into deallocated regions and mixing pointers from different regions.

### 14.3 Capabilities and Separation Logic

**Fractional permissions** (Boyland) use rational numbers to model access rights:

- Full permission (1.0): Exclusive write access
- Fractional permission (0.5): Shared read access (can split)
- Combining: 0.5 + 0.5 = 1.0 (two readers rejoin to enable writing)

**Separation logic** (O'Hearn) extends Hoare logic with the separating conjunction (⊛): P ⊛ Q means P and Q hold on *disjoint* heap regions. Resources follow linear logic rules — they cannot be duplicated or discarded. This provides a verification methodology for heap-based programs with mutable state, complementing type-based memory safety with logical reasoning about dynamic properties.

---

## 15. Design Considerations for a New Language

### 15.1 Making Dependent Types Practical

The key challenge is that type checking may require running arbitrary programs. Practical strategies:

- **Proof irrelevance**: Properties (Prop) are erased and not computed.
- **Universe levels**: Separate the universe hierarchy to control computation at type-checking time.
- **Erasure via multiplicities**: Mark erased arguments with multiplicity 0 so they don't exist at runtime.
- **Decidable equality on indices**: Restrict dependent indices to types with decidable equality (Nat, Bool, etc.).
- **Lazy type checking**: Postpone equality checks; support incremental compilation.
- **Interactive development**: Allow `?holes` that are filled incrementally.

### 15.2 Balancing Expressiveness with Decidability

The spectrum of type systems trades expressiveness for decidability:

| Fragment | Decidability | Expressiveness | Examples |
|----------|-------------|----------------|----------|
| Simple types | Decidable, fast | Limited | ML, early Haskell |
| Polymorphic types | Decidable (via unification) | Generic code | System F, modern Haskell |
| Refinement types | Semi-decidable (via SMT) | Predicates on values | LiquidHaskell, F* |
| Dependent types | Undecidable in general | Arbitrary properties | Agda, Coq, Idris |

A recommended strategy:

1. **Core calculus**: Start with decidable bases (STLC + products/sums, add polymorphism).
2. **Dependent extension**: Allow dependence primarily on erased arguments; require annotations where undecidable.
3. **Refinement layer**: Restrict logic to decidable fragments; use SMT for verification.
4. **Extension mechanism**: Allow advanced users to go beyond decidable fragments with interactive proof development.

### 15.3 Integration Strategies

Three proven strategies for combining dependent + linear + session types:

**Strategy 1 — Multiplicities as Foundation (Recommended, Idris 2 approach):**

Build the entire system on multiplicities:

```
(μ x : τ) → ...
  μ = 0 : Erased at compile time
  μ = 1 : Linear (exactly once)
  μ = ω : Unrestricted
```

Advantages: unified framework, clear semantics, multiplicities control both erasure and linearity. The type system operates on terms with multiplicities; type checking enforces multiplicity rules; compilation erases multiplicity-0 terms.

**Strategy 2 — Layered Type System:**

Keep three layers distinct but integrated:

- Layer 1 (Dependent Core): Full dependent type system, unrestricted
- Layer 2 (Linear Extension): Linear types over Layer 1, enforcing single-use
- Layer 3 (Session Extension): Session types over Layer 2, adding protocol specifications

Each layer can be understood independently, enabling gradual adoption.

**Strategy 3 — Syntax + Semantics Separation:**

Use rich surface syntax that desugars to a simpler core. This adds compilation complexity but allows intuitive syntax while keeping the core manageable.

**Recommended approach**: Adopt QTT-based multiplicities as the foundation. This provides a unified framework where dependent types, linear types, and session types are all expressible within the same core calculus. Surface syntax can be designed for ergonomics, with elaboration handling the translation to the multiplicity-annotated core.

### 15.4 Full Dependent Types vs. Refinement Types

| Dimension | Full Dependent Types | Refinement Types |
|-----------|---------------------|------------------|
| Expressiveness | Arbitrary properties | Decidable predicates only |
| Type checking | Undecidable in general | Decidable (via SMT) |
| Error messages | Can be cryptic | Generally clearer |
| Learning curve | Steep | More accessible |
| Automation | Requires tactics/proofs | SMT-based, more automatic |
| Proof objects | First-class values | External (not values) |

**Recommended hybrid approach for the new language:**

1. **Core dependent types**: For data structures and basic properties (decidable indices, universe levels, multiplicities).
2. **Refinement layer**: For quantitative properties (linear arithmetic, set constraints, SMT-based verification).
3. **Linear types**: Built on multiplicity framework, enforcing session invariants and preventing memory errors.
4. **Extension mechanism**: Interactive theorem proving mode for advanced users, accepting user-provided proofs for properties beyond automation.

---

## 16. References and Key Literature

### Foundational Theory

- Martin-Löf, P. (1984). *Intuitionistic Type Theory*. Bibliopolis.
- Coquand, T. & Huet, G. (1988). "The Calculus of Constructions." *Information and Computation*, 76(2-3), 95–120.
- Harper, R., Honsell, F. & Plotkin, G. (1993). "A Framework for Defining Logics." *Journal of the ACM*, 40(1), 143–184.
- Barendregt, H. (1991). "Introduction to Generalized Type Systems." *Journal of Functional Programming*, 1(2), 125–154.
- Girard, J.-Y. (1987). "Linear Logic." *Theoretical Computer Science*, 50(1), 1–102.

### Curry-Howard Correspondence

- Howard, W.A. (1980). "The Formulae-as-Types Notion of Construction." In *To H.B. Curry: Essays on Combinatory Logic, Lambda Calculus and Formalism*.
- Wadler, P. (2015). "Propositions as Types." *Communications of the ACM*, 58(12), 75–84.
- Lambek, J. (1972). "Deductive Systems and Categories III." In *Toposes, Algebraic Geometry and Logic*, Lecture Notes in Mathematics 274.

### Homotopy Type Theory

- The Univalent Foundations Program (2013). *Homotopy Type Theory: Univalent Foundations of Mathematics*. Institute for Advanced Study.
- Coquand, T., Cohen, C., Huber, S. & Mörtberg, A. (2018). "Cubical Type Theory: A Constructive Interpretation of the Univalence Axiom." *Journal of Automated Reasoning*, 60, 391–455.

### Proof Assistants

- The Coq/Rocq Development Team. *The Rocq Prover Reference Manual*. https://rocq-prover.org
- Norell, U. (2009). "Dependently Typed Programming in Agda." *AFP 2008*, LNCS 5832.
- de Moura, L. & Ullrich, S. (2021). "The Lean 4 Theorem Prover and Programming Language." *CADE-28*, LNAI 12699.
- Brady, E. (2021). "Idris 2: Quantitative Type Theory in Practice." *ECOOP 2021*, LIPIcs 194.
- Swamy, N. et al. (2016). "Dependent Types and Multi-Monadic Effects in F*." *POPL 2016*.

### Session Types

- Honda, K. (1993). "Types for Dyadic Interaction." *CONCUR 1993*, LNCS 715.
- Honda, K., Yoshida, N. & Carbone, M. (2008). "Multiparty Asynchronous Session Types." *POPL 2008*.
- Wadler, P. (2012). "Propositions as Sessions." *ICFP 2012*.
- Dardha, O. & Gay, S. (2018). "A New Linear Logic for Deadlock-Free Session-Typed Processes." *FoSSaCS 2018*, LNCS 10803.

### Linear Types

- Girard, J.-Y. (1995). "Linear Logic: Its Syntax and Semantics." In *Advances in Linear Logic*.
- Bernardy, J.-P. et al. (2018). "Linear Haskell: Practical Linearity in a Higher-Order Polymorphic Language." *POPL 2018*.
- Wadler, P. (1993). "A Taste of Linear Logic." *MFCS 1993*, LNCS 711.

### Quantitative and Graded Type Theory

- Atkey, R. (2018). "Syntax and Semantics of Quantitative Type Theory." *LICS 2018*.
- Orchard, D., Liepelt, V.B. & Eades III, H. (2019). "Quantitative Program Reasoning with Graded Modal Types." *ICFP 2019*.
- Orchard, D. et al. (2020). "The Granule Project." https://granule-project.github.io/

### Dependent Session Types

- Toninho, B., Caires, L. & Pfenning, F. (2011). "Dependent Session Types via Intuitionistic Linear Type Theory." *PPDP 2011*.
- Toninho, B. & Yoshida, N. (2021). "A Decade of Dependent Session Types." https://doi.org/10.1145/3479394.3479398

### Memory Safety and Separation Logic

- Grossman, D. et al. (2002). "Region-Based Memory Management in Cyclone." *PLDI 2002*.
- Boyland, J. (2003). "Checking Interference with Fractional Permissions." *SAS 2003*, LNCS 2694.
- O'Hearn, P.W. (2019). "Separation Logic." *Communications of the ACM*, 62(2), 86–95.

### Practical Implementation

- Christiansen, D. (2016). *Practical Reflection and Metaprogramming for Dependent Types*. PhD thesis, IT University of Copenhagen.
- Abel, A., Vezzosi, A. & Winterhalter, T. (2017). "Normalization by Evaluation for Sized Dependent Types." *ICFP 2017*.
- Kovács, A. (2022). "smalltt: an elaboration zoo." https://github.com/AndrasKovacs/smalltt
- Bowman, W.J. (2019). *Compiling with Dependent Types*. PhD thesis, Northeastern University.

### Behavioral Types and Typestate

- Strom, R.E. & Yemini, S. (1986). "Typestate: A Programming Language Concept for Enhancing Software Reliability." *IEEE Transactions on Software Engineering*, SE-12(1).
- Ancona, D. et al. (2016). "Behavioral Types in Programming Languages." *Foundations and Trends in Programming Languages*, 3(2-3).
- Aldrich, J., Sunshine, J., Saini, D. & Sparks, Z. (2009). "Typestate-Oriented Programming." *OOPSLA 2009*.

---

*This report was compiled as part of a research initiative to inform the design of a new programming language featuring dependent types as first-class citizens, with session types for protocol correctness and linear types for memory-safety guarantees.*
