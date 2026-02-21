# Implementation Guidance:
Πρόλογος (Prologos)

## A Functional-Logic Language with Dependent Types, Session Types, and Homoiconic Syntax

---

## Table of Contents

1. [Introduction and Scope](#1-introduction-and-scope)
2. [Language Overview and Design Principles](#2-language-overview-and-design-principles)
3. [The Elaboration Pipeline](#3-the-elaboration-pipeline)
   - 3.1 [Pipeline Architecture](#31-pipeline-architecture)
   - 3.2 [Bidirectional Type Checking](#32-bidirectional-type-checking)
   - 3.3 [Normalization by Evaluation (NbE)](#33-normalization-by-evaluation-nbe)
   - 3.4 [Metavariable Solving and Higher-Order Unification](#34-metavariable-solving-and-higher-order-unification)
   - 3.5 [The Elaboration Monad Stack](#35-the-elaboration-monad-stack)
4. [Dependent Type System Implementation](#4-dependent-type-system-implementation)
   - 4.1 [Core Type Theory: Π, Σ, Identity, Universes](#41-core-type-theory-π-σ-identity-universes)
   - 4.2 [Universe Hierarchy](#42-universe-hierarchy)
   - 4.3 [Inductive Families and Dependent Pattern Matching](#43-inductive-families-and-dependent-pattern-matching)
   - 4.4 [Termination Checking](#44-termination-checking)
5. [Quantitative Type Theory and Linear Resources](#5-quantitative-type-theory-and-linear-resources)
   - 5.1 [Multiplicities: 0, 1, ω](#51-multiplicities-0-1-ω)
   - 5.2 [Usage Tracking in the Elaborator](#52-usage-tracking-in-the-elaborator)
   - 5.3 [The Dependency-Through-Linearity Problem](#53-the-dependency-through-linearity-problem)
   - 5.4 [Erasure and Runtime Optimization](#54-erasure-and-runtime-optimization)
6. [Session Types Implementation](#6-session-types-implementation)
   - 6.1 [Binary Session Type Checking and Duality](#61-binary-session-type-checking-and-duality)
   - 6.2 [Dependent Session Types](#62-dependent-session-types)
   - 6.3 [Deadlock Freedom Guarantees](#63-deadlock-freedom-guarantees)
   - 6.4 [Runtime Representation of Channels](#64-runtime-representation-of-channels)
   - 6.5 [Asynchronous Semantics and Buffering](#65-asynchronous-semantics-and-buffering)
   - 6.6 [Multiparty Session Types](#66-multiparty-session-types)
7. [Logic Programming Engine](#7-logic-programming-engine)
   - 7.1 [Unification and Substitution](#71-unification-and-substitution)
   - 7.2 [Proof Search: SLD Resolution and Beyond](#72-proof-search-sld-resolution-and-beyond)
   - 7.3 [Tabling for Termination and Performance](#73-tabling-for-termination-and-performance)
   - 7.4 [Constraint Handling Rules](#74-constraint-handling-rules)
   - 7.5 [Integration of Proof Search with Session Types](#75-integration-of-proof-search-with-session-types)
8. [Homoiconic Syntax and Parsing](#8-homoiconic-syntax-and-parsing)
   - 8.1 [The Universal Term Structure](#81-the-universal-term-structure)
   - 8.2 [Parsing Hybrid Syntax: Brackets plus Indentation](#82-parsing-hybrid-syntax-brackets-plus-indentation)
   - 8.3 [Quoting, Splicing, and Metaprogramming](#83-quoting-splicing-and-metaprogramming)
9. [Propagator-Based Architecture](#9-propagator-based-architecture)
   - 9.1 [Propagators for Type Inference and Elaboration](#91-propagators-for-type-inference-and-elaboration)
   - 9.2 [Session Type Verification as Propagation](#92-session-type-verification-as-propagation)
   - 9.3 [Linear Resource Tracking as Propagation](#93-linear-resource-tracking-as-propagation)
   - 9.4 [Propagators as a Runtime Computational Model](#94-propagators-as-a-runtime-computational-model)
10. [Compilation and Runtime](#10-compilation-and-runtime)
    - 10.1 [LLVM Target: Architecture and Strategy](#101-llvm-target-architecture-and-strategy)
    - 10.2 [Closure Conversion and ANF](#102-closure-conversion-and-anf)
    - 10.3 [Garbage Collection](#103-garbage-collection)
    - 10.4 [Process Runtime and Concurrency](#104-process-runtime-and-concurrency)
11. [Prototyping Strategy](#11-prototyping-strategy)
    - 11.1 [Racket as a Prototyping Platform](#111-racket-as-a-prototyping-platform)
    - 11.2 [Alternative: Haskell or Rust Prototype](#112-alternative-haskell-or-rust-prototype)
    - 11.3 [Maude for Formal Verification of the Design](#113-maude-for-formal-verification-of-the-design)
12. [Phased Implementation Plan](#12-phased-implementation-plan)
13. [Key Challenges and Open Problems](#13-key-challenges-and-open-problems)
14. [References and Key Literature](#14-references-and-key-literature)

---

## 1. Introduction and Scope

This document provides comprehensive implementation guidance for Πρόλογος (Prologos), a programming language that seeks to unify three powerful paradigms — dependent type theory, session-typed concurrent programming, and logic programming — within a homoiconic, syntactically minimal framework. The guidance is intended for an implementer approaching this design from first principles, and covers the major architectural decisions, algorithmic strategies, pitfalls, and phased development plan required to bring Prologos from formal specification to working prototype and eventually to a production-quality compiler.

The design of Prologos draws from several traditions: the proof-theoretic foundations of Martin-Löf type theory and the Curry-Howard-Lambek correspondence; the propositions-as-sessions interpretation connecting linear logic to process calculi; the relational and search-oriented computation of logic programming; and the propagator model of Radul and Sussman, which provides a lattice-theoretic substrate for constraint solving, type inference, and concurrent execution. The language aims to target LLVM for native compilation while maintaining a homoiconic syntax inspired by Lisp/Clojure's code-as-data philosophy, TCL's prefix notation, and Python/Haskell's significant whitespace.

This report synthesizes the research presented in our earlier reports on Dependent Type Theory and Propagator Networks, the Maude formal specifications developed in exploratory conversations, and the project desiderata documented in NOTES.org.

---

## 2. Language Overview and Design Principles

Prologos is organized around five core design principles, each of which imposes specific requirements on the implementation.

**Principle 1: Propositions, Types, and Sessions are Unified.** In Prologos, the Curry-Howard correspondence is extended to encompass not only propositions-as-types but also propositions-as-sessions (following Caires, Pfenning, and Toninho). A predicate in the logic programming sense is simultaneously a type (whose inhabitants are proof terms) and a session specification (whose realizations are communicating processes). The core judgment forms reflect this unification: `Γ ⊢ P` asserts that P is a well-formed proposition or type; `Γ ⊢ e : P` asserts that e is a proof term or value of type P; and `Γ ; Δ ⊢ M :: S` asserts that process M implements session S using linear channels Δ and unrestricted bindings Γ.

**Principle 2: Dependent Types as First-Class Citizens.** Types can depend on values through Π-types (dependent functions) and Σ-types (dependent pairs). This enables expressing rich invariants — length-indexed vectors, protocol-correct communication, sorted-list certificates — directly in the type system, making "if it compiles, it is correct" achievable for a broad class of properties.

**Principle 3: Quantitative Type Theory for Resource Control.** Following Idris 2, Prologos adopts Quantitative Type Theory (QTT) with three multiplicities — 0 (erased at runtime), 1 (linear, used exactly once), and ω (unrestricted) — to unify dependent types with linear resource management. This enables both compile-time erasure of proof-irrelevant terms and linear ownership for memory safety and protocol integrity.

**Principle 4: Homoiconic Syntax with Minimal Punctuation.** All program elements — types, terms, sessions, processes, goals — share a single AST representation: atoms, numbers, and compound terms delimited by square brackets with prefix operators. Significant whitespace provides visual structure without excessive bracketing. The `$` operator quotes terms for metaprogramming, enabling the code-as-data paradigm.

**Principle 5: Propagator-Informed Architecture.** The propagator model informs both the compile-time infrastructure (type inference as constraint propagation over lattices) and the runtime model (processes as propagator-like agents communicating through typed channels). Lattice-theoretic properties — monotonicity, convergence, determinism — provide formal guarantees for both type checking and concurrent execution.

---

## 3. The Elaboration Pipeline

### 3.1 Pipeline Architecture

The compiler pipeline transforms surface syntax into executable code through a series of well-defined stages. Each stage has a clear input, output, and set of responsibilities.

**Stage 1 — Parsing.** Surface syntax (brackets, indentation, annotations) is parsed into a raw AST. The parser handles both bracket-delimited forms (`[op arg1 arg2 ...]`) and indentation-significant control flow. Output: raw, unelaborated AST with source locations.

**Stage 2 — Elaboration.** The raw AST is transformed into a fully explicit core term. This stage resolves implicit arguments, inserts type annotations, checks types bidirectionally, and generates metavariables for unknown terms. The elaborator uses Normalization by Evaluation (NbE) for equality checking and pattern unification for metavariable solving. Output: core terms with all types explicit, metavariables solved or reported as errors.

**Stage 3 — Constraint Solving.** Unification constraints, universe level constraints, and multiplicity constraints generated during elaboration are solved. Pattern unification handles the decidable fragment; non-pattern constraints are postponed and retried as more information becomes available. Output: a substitution mapping all metavariables to concrete terms.

**Stage 4 — Termination and Totality Checking.** After elaboration, recursive definitions are checked for termination (structural recursion or sized types) and coverage (all patterns handled). Output: verified core terms, or error reports for non-terminating or incomplete definitions.

**Stage 5 — Erasure and Optimization.** Terms with multiplicity 0 are erased. Proof-irrelevant arguments, type parameters, and compile-time-only computations are removed. ANF (A-normal form) conversion and closure conversion prepare the code for compilation. Output: an optimized intermediate representation.

**Stage 6 — Code Generation.** The optimized IR is lowered to LLVM IR (or interpreted directly during prototyping). Algebraic data types become tagged unions, closures become function-pointer-plus-environment pairs, and processes become runtime tasks. Output: native executable or interpreted result.

### 3.2 Bidirectional Type Checking

Bidirectional type checking is the recommended algorithmic strategy for dependent type systems because it balances annotation burden against decidability. It operates in two complementary modes.

In **synthesis mode** (written Γ ⊢ e ⇒ A), the elaborator derives a type from the term. Variables synthesize their type from the context; function applications synthesize by synthesizing the function type and then checking the argument. In **checking mode** (written Γ ⊢ e ⇐ A), the elaborator verifies that a term has a given type. Lambda abstractions are checked against Π-types; constructors are checked against their inductive type.

For Prologos, bidirectional checking is essential because full type inference for dependent types is undecidable. The key architectural decision is determining which terms synthesize and which check. The recommended defaults are: variables, annotated terms, and applications synthesize; lambdas, constructors, and pattern matches check. When synthesis and checking meet (e.g., an application where the argument type must be checked), the elaborator generates a unification constraint rather than immediately failing.

The bidirectional discipline also provides a natural hook for propagator-based type inference. Rather than using exactly two modes, the elaborator can be generalized to a propagator network where type information flows in all available directions, converging to a fixed point. This generalization is discussed further in Section 9.

### 3.3 Normalization by Evaluation (NbE)

Dependent type checking requires determining when two types are equal (e.g., to verify that a function argument has the expected type). Since types contain arbitrary computations, this equality check requires normalizing terms. Normalization by Evaluation is the recommended strategy for its efficiency and elegance.

NbE operates in two phases. The **evaluation phase** maps syntactic terms into semantic values by interpreting them in a domain of closures, neutral terms (stuck computations), and canonical values. The **read-back phase** (reification) converts semantic values back into syntactic normal forms by applying them to fresh variables and recursively quoting the results. Two terms are definitionally equal if and only if their normal forms are syntactically identical (up to alpha-equivalence, handled automatically by de Bruijn indices).

The recommended implementation uses **untyped NbE** for simplicity, with de Bruijn indices throughout. The semantic domain contains: `VNeutral` (neutral terms — variables applied to a spine of arguments), `VLam` (closures pairing a function body with its environment), `VPi` and `VSigma` (dependent type formers), and constructor values. Closures should be implemented as actual host-language closures (in Haskell or Rust) rather than explicit substitutions, for performance.

A critical optimization is **glued evaluation**, as demonstrated in András Kovács's `smalltt`. Glued evaluation stores both the evaluated form and the original syntax of each term, computing the reduced form only when syntactic comparison fails. This dramatically reduces normalization work in practice, since most equality checks succeed syntactically.

### 3.4 Metavariable Solving and Higher-Order Unification

When the elaborator encounters an unknown — an implicit argument, an inferred type, a hole — it creates a **metavariable** (also called a unification variable or existential). Solving metavariables is the central algorithmic challenge of elaboration.

The recommended approach is **pattern unification** in the sense of Miller. A constraint is in pattern form when a metavariable is applied to a list of distinct bound variables: `?m x₁ x₂ ... xₙ = rhs`. Pattern unification is decidable, produces unique most general unifiers, and runs in linear time. The vast majority of constraints arising in practice fall within the pattern fragment.

For constraints that fall outside the pattern fragment (e.g., metavariables applied to non-variable terms), the recommended strategy is **constraint postponement**: store the constraint and retry it after more metavariables have been solved. This avoids the undecidability of full higher-order unification while handling most practical cases through iterative refinement.

Each metavariable entry should store: a unique identifier, the type of the metavariable, the scope of variables it may depend on, the solution (once found), and a source location for error reporting. When a metavariable is solved, all constraints that mention it should be re-examined — this is the propagator-like behavior of the elaborator.

### 3.5 The Elaboration Monad Stack

Following the architecture of Lean 4 and Idris 2, the elaborator is organized as a stack of monads, each providing specific capabilities.

The **CoreM** monad provides access to the global environment (defined types, functions, axioms), compiler options, and error reporting. The **MetaM** monad extends CoreM with a metavariable context — the mutable state of unsolved metavariables and constraints. The **TermElabM** monad extends MetaM with term-elaboration context: the current type being checked against, the current binding depth, source location tracking, and implicit argument handling. An optional **TacticM** monad extends TermElabM with proof-goal state, enabling tactic-based proof construction.

For Prologos, the monad stack should also include session-type-specific state: the current linear context (channels in scope and their session types), the usage counts for multiplicity checking, and the process-typing judgment being verified.

---

## 4. Dependent Type System Implementation

### 4.1 Core Type Theory: Π, Σ, Identity, Universes

The core type theory of Prologos includes: **Π-types** (dependent functions), where the return type may depend on the input value; **Σ-types** (dependent pairs), where the type of the second component depends on the value of the first; **identity types** (propositional equality), enabling proofs that two values are equal; **inductive families** (dependent data types), generalizing algebraic data types to families indexed by values; and a **universe hierarchy** with Type₀ : Type₁ : Type₂ : ... to avoid paradoxes.

The implementation represents these types using de Bruijn indices for variables (eliminating alpha-equivalence concerns), with NbE for normalization. Each typing rule becomes a case in the bidirectional type checker: Π-introduction (lambda) checks against a Π-type; Π-elimination (application) synthesizes by synthesizing the function type and checking the argument; Σ-introduction (pair) checks against a Σ-type; and so on.

### 4.2 Universe Hierarchy

The recommended approach is **non-cumulative universe polymorphism** in the style of Lean 4. Each definition is parameterized by universe level variables, and the type checker maintains constraints of the form `u₁ + 1 ≤ u₂` between level expressions. Level expressions are built from level variables, zero, successor, and max. The constraint solver uses linear arithmetic on these expressions — significantly simpler than type-level unification.

Starting non-cumulative is important: it produces simpler, more predictable semantics. Cumulativity (where Type₀ values can be used at Type₁) can be added later if user demand warrants it, but it complicates the metatheory and should not be attempted initially.

### 4.3 Inductive Families and Dependent Pattern Matching

Inductive families are the workhorses of dependent type theory. The Prologos types `Vec A n`, `Fin n`, `IsSorted xs`, and `Append xs ys zs` are all inductive families — data types indexed by values that encode invariants in their structure.

Implementing dependent pattern matching requires: (1) **unification of indices** — when matching a constructor, the type indices must unify with the constructor's index pattern, potentially refining the context; (2) **impossible case detection** — when unification of indices fails (e.g., matching `Nil` against `Vec A (S n)`), the case is impossible and can be omitted; and (3) **with-abstraction** or **case splitting** — when matching requires discriminating on an index, the elaborator must generalize the goal.

The recommended reference for implementing dependent pattern matching is Jesper Cockx's work on "Elaborating Dependent (Co)pattern Matching" (JFP, 2019), which provides a clear algorithm based on case trees and unification.

### 4.4 Termination Checking

Prologos should employ a combination of termination strategies. **Structural recursion** should be the default: verify that recursive calls use structurally smaller arguments (subterms of the input). This handles the vast majority of definitions (list operations, tree traversals, arithmetic) with zero annotation burden. For definitions that structural recursion cannot handle (e.g., functions that restructure their input before recursing), **sized types** provide a more expressive alternative: types are annotated with abstract size ordinals, and the type checker verifies that recursive calls operate on smaller sizes. Sized types are modular and compositional, making them suitable for library code.

The recommendation is to implement structural recursion first (it covers most cases), add sized types as an advanced feature when needed, and avoid requiring explicit well-founded recursion proofs (which impose too much annotation burden on users). Termination checking should run as a separate pass after elaboration, operating on fully elaborated core terms.

---

## 5. Quantitative Type Theory and Linear Resources

### 5.1 Multiplicities: 0, 1, ω

Following Idris 2, every variable binding in Prologos carries a multiplicity annotation from the semiring {0, 1, ω}. Multiplicity 0 means the binding is erased at runtime — it exists only for type checking. Multiplicity 1 means the binding is linear — it must be used exactly once. Multiplicity ω means the binding is unrestricted — it may be used any number of times. These multiplicities are carried on Π-binders: `(π x : A) → B` where π ∈ {0, 1, ω}.

The semiring structure means multiplicities compose: using a 1-multiplicity variable inside a function called with multiplicity ω results in ω usage overall. The ordering 0 ≤ 1 ≤ ω provides subusumption: a variable with multiplicity ω can be used in a context requiring multiplicity 1 or 0 (by simply using it once or not at all).

### 5.2 Usage Tracking in the Elaborator

During elaboration, the type checker maintains a **usage context** — a mapping from variable names to (declared multiplicity, actual usage count) pairs. After elaborating a term, the checker verifies that each variable's actual usage is consistent with its declared multiplicity: a 0-multiplicity variable must not be used in runtime positions; a 1-multiplicity variable must be used exactly once; an ω-multiplicity variable may be used freely.

The implementation should track usages as an additive counter during elaboration. When elaborating a function application `f x`, the usage of `x` is incremented. When elaborating a lambda `λx. body`, a fresh usage counter for `x` is created and checked after elaborating `body`. For `let` bindings and case expressions, the elaborator must split the linear context appropriately — each branch of a case expression gets its own copy of the usage counts, and the results are combined (each linear variable must be used in exactly one branch, or used in all branches exactly once).

Error messages for multiplicity violations should be clear and actionable: "Variable `x` is used 3 times but declared with multiplicity 1 (linear). Consider changing to unrestricted multiplicity (ω), or restructure the code to use `x` exactly once."

### 5.3 The Dependency-Through-Linearity Problem

A fundamental tension arises when types depend on linear values. If `d : Door` has multiplicity 1, the type `IsOpen d` depends on `d` — but `d` will be consumed during execution, and the type checker still needs it for type-level computation.

The recommended solution is **separation of the linear and intuitionistic contexts** combined with multiplicity-based phase separation. Types are checked in the unrestricted (intuitionistic) context only. Linear variables cannot appear in types. This is enforced by checking that when elaborating a type expression, all free variables have multiplicity 0 or ω. In the QTT framework, type-level occurrences of a variable count as multiplicity-0 uses, which do not conflict with a multiplicity-1 runtime use — the type is erased at runtime, so the linear variable is still used exactly once in the generated code.

The practical recommendation is to start with the strict separation (linear variables cannot appear in types), which is simple and sound. If user feedback indicates that a more permissive approach is needed, computational irrelevance (marking type-level uses as 0-multiplicity) can be added later.

### 5.4 Erasure and Runtime Optimization

Multiplicity 0 provides a powerful optimization: all 0-multiplicity bindings are erased from the compiled code. This includes: type parameters (e.g., the `A` in `Vec A n`); proof arguments (e.g., the `IsSorted xs` evidence); and any term used only at the type level. Erasure is performed after elaboration and before code generation, producing a substantially smaller runtime representation.

For Prologos, erasure interacts with the logic programming engine: proof terms constructed by proof search are first-class values during type checking but may be erased at runtime if their multiplicity is 0. The implementer must carefully track which proof terms are needed at runtime (for inspection, explanation, or further computation) and which are purely compile-time.

---

## 6. Session Types Implementation

### 6.1 Binary Session Type Checking and Duality

Session types govern communication on channels. The core session type constructors, as specified in the Prologos Maude modules, are: `send(A, S)` (send a value of type A, continue as S); `recv(A, S)` (receive a value of type A, continue as S); `dsend(x, A, S)` (dependent send — continuation S may mention the sent value x); `drecv(x, A, S)` (dependent receive); `choice(branches)` (internal choice — the process selects a branch); `offer(branches)` (external choice — the environment selects); `mu(X, S)` (recursive session); and `endS` (session completion).

Every session type has a **dual** — what the other endpoint sees. Duality is defined coinductively: the dual of send is receive, choice becomes offer, and recursion and end are self-dual. The Maude specification already captures these equations. In the implementation, duality checking is a simple structural traversal of the session type.

Session type checking verifies that a process correctly implements its session type. For each process construct, there is a corresponding typing rule: `send e on c then P` requires that `c` has type `!A.S`, that `e : A`, and that `P` correctly implements `S`. After a send, the channel type progresses from `!A.S` to `S`. After a receive, the channel type progresses from `?A.S` to `S` and the received value enters the context.

### 6.2 Dependent Session Types

The distinctive feature of Prologos's session types is that they can depend on communicated values. The dependent send `!(x:A).S` means: send a value of type A, binding it as x, where the continuation S may mention x. Similarly, dependent receive `?(x:A).S` receives a value and makes it available in the continuation's type.

After a dependent receive `recv c (x : A)`, the type checker must perform **substitution** in the remaining session type: replace all occurrences of x with the received value. This requires the same normalization machinery (NbE) used for dependent types. The implementation must ensure that received values are available for type-level computation while respecting linearity constraints. An important clarification: in dependent session types, the dependency is on the *value* communicated, not on the *channel*. The received value `x` is bound with multiplicity ω (unrestricted) for type-level purposes — its appearance in the continuation type `S` counts as a multiplicity-0 (erased) use, compatible with the QTT framework. The channel itself remains linear (multiplicity 1), but the data flowing through it enters the unrestricted context. This resolves the apparent tension with Section 5.3's guidance on the dependency-through-linearity problem: it is the *channel* that is linear, not the *data*, and types depend on data, not on channels.

The Maude specification includes a `substS` operation for session-type substitution, and the typing rule for dependent send checks that the process correctly implements `S[e/x]` after sending value `e`. The practical challenge is that the received value may not be statically known — in that case, the type checker must treat it as a symbolic variable and track the dependency.

### 6.3 Deadlock Freedom Guarantees

Ensuring that well-typed Prologos programs are deadlock-free requires a discipline on process composition. Three approaches exist, in increasing expressiveness.

The **linear logic foundation** (Caires-Pfenning) achieves deadlock freedom by forbidding cyclic process structures entirely. The typing rules for parallel composition require that the linear contexts of the two processes are disjoint (no shared channels beyond the one being cut). This rules out circular dependencies by construction. The approach is simple and the guarantee is strong, but it rejects some safe concurrent patterns.

**Priority-based typing** (Dardha-Gay) annotates session types with priority levels and allows cyclic structures provided the priorities form a consistent ordering. Lower-priority sends must happen before higher-priority sends, preventing circular wait conditions. This is more expressive but requires maintaining priority annotations.

**Kobayashi's usage analysis** infers constraints on communication operations and checks for genuine circular dependencies via reachability analysis. It is the most expressive but also the most complex to implement (the constraint solving is NP-complete in general).

The recommended approach for Prologos is to start with the linear logic foundation (matching the formal Maude specification's structure), then add priority-based typing if users need more expressive concurrency patterns.

### 6.4 Runtime Representation of Channels

At runtime, session-typed channels need a concrete representation. The recommended pattern is **dual endpoints**: each channel is a pair of endpoints, with each process holding one endpoint. Endpoints contain a channel identifier, a polarity (positive or negative), and an internal communication buffer.

After each communication operation, the endpoint's type state advances to the session continuation. In a language with linear types, the old endpoint is consumed and a new one (at the continuation type) is returned. This type-state progression is enforced statically; at runtime, it is simply a pointer update.

For a prototype, channels can be implemented as shared queues protected by mutexes. For a production system, consider lock-free FIFO queues or actor-style message passing (following the Erlang model, which the Maude specifications already hint at).

### 6.5 Asynchronous Semantics and Buffering

Prologos should support **asynchronous session semantics**, where sends return immediately (enqueuing the message) and receives block until a message is available. This is more practical than synchronous semantics for distributed and concurrent programs.

Each channel endpoint maintains an input buffer (messages received, pending local processing) and an output buffer (messages sent, pending transmission). Messages are transferred from one endpoint's output buffer to the other's input buffer. The FIFO ordering of the buffer ensures that session type progression is respected — messages arrive in the order they were sent.

The type-theoretic property of **asynchronous subtyping** ensures that the asynchronous execution faithfully implements the synchronous specification. The key insight is that a sequence of sends `!A₁.!A₂....!Aₙ.?B.S` can execute all sends before waiting for the receive, because the sends do not depend on the receive's result.

### 6.6 Multiparty Session Types

While binary session types cover two-party interactions, many protocols involve three or more participants. Multiparty session types (MPST) extend the framework with a **global type** specifying the entire protocol from a bird's-eye view, and a **projection** operation that extracts each participant's local view.

For Prologos, MPST support would enable expressing complex coordination patterns — e.g., a three-party authentication protocol involving a client, server, and identity provider. The implementation follows the Scribble toolchain pattern: parse a global protocol specification, validate its well-formedness, project to local session types, and type-check each endpoint against its local type.

MPST is recommended as an advanced feature for a later implementation phase. Binary session types with dependent types already cover a wide range of protocols, and MPST adds significant complexity (global type validation, projection algorithms, merging of projected types).

---

## 7. Logic Programming Engine

### 7.1 Unification and Substitution

Unification — finding a substitution that makes two terms equal — is the fundamental operation of logic programming. The standard algorithm walks two terms in parallel: if both are the same atom, succeed; if one is a variable, bind it to the other (after an occurs check to prevent infinite terms); if both are compound terms with the same functor and arity, unify their arguments pairwise; otherwise, fail.

For Prologos, the unification engine serves double duty: it underlies both the logic programming proof search and the type-level metavariable solving. The implementation should use an efficient union-find data structure for variable bindings, with path compression and union by rank for near-constant-time operations.

The substitution representation is critical for performance. A global substitution table (mapping variables to terms) with lazy application (terms are walked through the substitution on demand) avoids the cost of eagerly applying substitutions to large terms. This is the approach used by most Prolog implementations and by the WAM.

### 7.2 Proof Search: SLD Resolution and Beyond

SLD resolution (Selective Linear Definite clause resolution) is the standard proof search strategy for logic programming. Given a goal, the engine selects a clause whose head unifies with the goal, applies the resulting substitution, and recursively solves the clause body. Backtracking occurs when unification fails or when all clauses for a goal have been exhausted.

For a prototype, a simple depth-first search with choice points (saved states for backtracking) is sufficient. Each choice point records the current substitution, the remaining clauses to try, and the continuation goals. On backtracking, the engine restores the choice point's substitution and tries the next clause.

For production quality, the Warren Abstract Machine (WAM) provides efficient compiled execution of logic programs. The WAM uses registers, a heap for terms, an environment stack for clause activations, and a trail for recording variable bindings (enabling efficient backtracking by untrailing). First-argument indexing provides jump tables for fast clause selection. The reference text is Hassan Aït-Kaci's "Warren's Abstract Machine: A Tutorial Reconstruction."

An alternative for the prototype phase is the **miniKanren** approach: represent goals as functions from substitutions to streams of substitutions, with conjunction as stream interleaving and disjunction as stream concatenation. This is compact (a few hundred lines of code), easily embedded in the host language, and naturally handles fair search (interleaving avoids the depth-first bias that causes SLD resolution to diverge on some programs).

### 7.3 Tabling for Termination and Performance

Tabling (memoization of proof search results) addresses two problems: non-termination of left-recursive predicates and redundant recomputation of shared subgoals. When a tabled predicate is called, the engine first checks if the same subgoal has been seen before. If so, it returns the previously computed answers (or suspends if computation is still in progress). If not, it records the subgoal and begins computation, storing answers as they are found.

Tabling transforms the evaluation strategy from depth-first to bottom-up fixed-point computation — connecting directly to the propagator model's fixed-point semantics and to Datalog's evaluation strategy. For Prologos, tabling is essential: dependent type checking may generate circular constraints (e.g., type-level recursion), and tabling ensures that the proof search engine terminates on these cases.

The recommended implementation is **SLG resolution** (as implemented in XSB Prolog and SWI-Prolog's `table/1` directive), which combines tabling with SLD resolution and handles negation via the well-founded semantics.

### 7.4 Constraint Handling Rules

Constraint Handling Rules (CHR), introduced by Thom Frühwirth, extend logic programming with multi-headed rules that operate on a constraint store. CHR rules come in two forms: **simplification rules** (replace constraints with simpler equivalents) and **propagation rules** (add new constraints without removing existing ones).

For Prologos, CHR provides a natural mechanism for expressing and solving type-level constraints, arithmetic constraints (CLP(FD)), and domain-specific constraints. The constraint store corresponds to the set of unresolved type constraints during elaboration, and CHR rules correspond to type inference heuristics that combine multiple constraints to derive new information.

The implementation integrates CHR with the proof search engine: the constraint store is maintained alongside the substitution, CHR rules fire whenever new constraints are added, and the resulting fixed-point computation produces the inferred types and session specifications.

### 7.5 Integration of Proof Search with Session Types

The `solve` construct is the key integration point between logic programming and session-typed processes. When a process encounters `solve G as (x : A) ; P`, it invokes the proof search engine to find a witness `x` satisfying goal `G`, then continues as process `P` with `x` bound.

The critical question is: what happens to the linear context during proof search? The answer depends on the nature of the goal. If the goal is purely propositional (no session types involved), the linear context is preserved unchanged — proof search operates only in the unrestricted context. If the goal involves session-typed channels (e.g., "find a process that implements session S using channels Δ"), then the linear context is consumed by the resulting process.

The implementation must ensure that the proof search engine respects linearity: each linear channel is used exactly once in the resulting proof term. This is achieved by threading the linear context through the proof search as an additional parameter, splitting it at each conjunction and merging at each disjunction. The search fails if the linear context cannot be distributed appropriately.

---

## 8. Homoiconic Syntax and Parsing

### 8.1 The Universal Term Structure

All Prologos program elements share a single syntactic form:

```
Term ::= Atom                    -- identifier (e.g., foo, Nat, x)
       | Qualified               -- namespaced identifier (e.g., std/list/append)
       | Number                  -- numeric literal
       | [Op Term ...]           -- compound term
       | [Term ...]              -- vector literal (EDN-style)
       | {Key Term ...}          -- hashmap literal (EDN-style)
       | $Term                   -- quoted (unevaluated) term
       | Term : Term             -- annotation (x : Type)
```

Types, expressions, session types, processes, and goals are all terms. The distinction between these categories is made during elaboration (by the type checker), not during parsing. This uniformity is what enables homoiconicity: code can be quoted, inspected, and manipulated as ordinary data.

**EDN-Style Collections.** Following the desiderata, Prologos supports EDN (Extensible Data Notation) collections as first-class syntax: vectors `[1 2 3]` (when no leading operator is present, the bracket form is a vector literal) and hashmaps `{:name "Alice" :age 30}`. These map to built-in types `Vec` and `Map` in the type system. The parser distinguishes vector literals from compound terms by checking whether the first element in a bracket form is an operator or a value.

**Fully Qualified Namespaces.** Identifiers use `/` as the namespace separator (e.g., `std/list/append`, `my-project/auth/validate`). This enables unambiguous imports and avoids name collisions. The parser treats `/` within an atom as a namespace delimiter, producing a `Qualified` AST node containing the namespace path and the local name.

The AST representation should be a recursive enum (or algebraic data type) with variants for atoms, qualified names, numbers, compound terms, vector literals, hashmap literals, quoted terms, and annotations. All variants should support equality comparison, hashing, and cloning — these operations are needed for unification, tabling, and metaprogramming.

### 8.2 Parsing Hybrid Syntax: Brackets plus Indentation

Prologos uses a hybrid syntax combining bracket-delimited forms and significant whitespace. The parser must handle both modes and their interaction.

For bracket-delimited forms, parsing is straightforward: consume `[`, parse the operator and arguments, consume `]`. For indentation-significant blocks, the parser tracks indentation levels and treats deeper indentation as continuation (child terms) and shallower indentation as termination (closing implicit brackets).

The recommended parser architecture uses a **Megaparsec-style** parser combinator library (for Haskell prototypes) or a **recursive descent parser with indentation tracking** (for Rust or OCaml implementations). The key combinators are: `indentBlock` (parse a block where children are more indented than the parent), `lineFold` (parse a logical line that may be continued on the next line if more indented), and `nonIndented` (parse a top-level declaration with no indentation).

For IDE integration and error recovery, a **Tree-sitter** grammar can be developed in parallel. Tree-sitter supports incremental parsing (reparsing only the changed portion of the file), error recovery (producing partial ASTs for incomplete programs), and external scanners (C code for custom lexical rules like indentation tracking).

### 8.3 Quoting, Splicing, and Metaprogramming

The `$` operator quotes a term, preventing its evaluation and producing a first-class AST value. `$[Pi x Nat [Vec Bool x]]` evaluates to a `Term` value representing the dependent function type Π(x:Nat).Vec Bool x. Pattern matching on quoted terms enables compile-time code generation and inspection.

For type-safe metaprogramming, Prologos should adopt **elaborator reflection** in the style of Idris 2: metaprograms are ordinary Prologos functions that have access to the elaborator's internal state (type context, metavariable context, constraint set). They can create new definitions, resolve metavariables, and invoke the type checker — all within the language itself, with full type safety.

The implementation requires two components: (1) a `Code` type representing quoted terms, with constructors for each AST variant; and (2) an `ElabM` monad (or its equivalent) exposed to user code, providing operations like `elaborate : Code → ElabM Type`, `unify : Type → Type → ElabM ()`, and `emit : Definition → ElabM ()`.

---

## 9. Propagator-Based Architecture

### 9.1 Propagators for Type Inference and Elaboration

The propagator model offers a compelling architecture for the Prologos elaborator. Rather than a traditional top-down or bottom-up type checker, the elaborator constructs a **constraint network** where cells hold partial type information and propagators represent typing rules.

For each metavariable, create a cell initialized to bottom (no information). For each typing constraint (from function applications, pattern matches, annotations), create a propagator that reads from its input cells and writes derived information to its output cells. Run the network to quiescence — when all propagators have stabilized, the cells contain the inferred types.

This architecture naturally supports: **bidirectional information flow** (type information propagates both from annotations downward and from uses upward); **incremental elaboration** (adding new constraints triggers only the affected propagators); **parallel type checking** (the lattice structure ensures deterministic results regardless of propagator scheduling); and **graceful degradation** (unsolved cells indicate where more type annotations are needed).

The merge operation on type cells should compute the lattice join of partial type information. For simple types, this is unification. For dependent types, the merge involves NbE normalization and comparison. For session types, the merge checks that the partial protocol information is consistent.

### 9.2 Session Type Verification as Propagation

Session type checking naturally maps onto propagator networks. Each channel has a cell holding its current protocol state (a partial session type). Each send/receive operation is a propagator that advances the protocol state. Protocol completion corresponds to the cell reaching `end`. Protocol violation corresponds to the cell reaching contradiction (top of the lattice).

Duality checking becomes a propagation problem: constraints from both endpoints of a channel propagate through the session type lattice, and a contradiction indicates a protocol mismatch. Dependent session types — where the protocol depends on communicated values — naturally fit this model: the type of subsequent messages depends on the value received, and this dependency propagates through the type lattice as values become known.

### 9.3 Linear Resource Tracking as Propagation

Multiplicity tracking can be modeled as propagation on a lattice of usage counts. Each variable binding has a cell tracking its multiplicity usage. Each use site is a propagator that increments the usage count. After elaboration, the final usage counts are checked against the declared multiplicities.

The usage lattice is: bottom (not yet accounted for) ≤ 0 ≤ 1 ≤ ω ≤ top (contradiction — e.g., a linear variable used twice). The merge operation on the usage lattice takes the maximum usage count. This formulation allows the propagator network to track usages incrementally as the term is elaborated.

### 9.4 Propagators as a Runtime Computational Model

Beyond type checking, propagators offer a compelling runtime model for Prologos. Programs can construct and run propagator networks as first-class values. Cells are typed using dependent types (encoding their lattice structure), and propagators are typed using linear types (ensuring proper resource management) and session types (encoding their communication protocol with cells).

This connects to the language's constraint-solving heritage: a logic program that declares constraints and searches for solutions is, operationally, constructing a propagator network and running it to a fixed point. The monotonicity of the propagator model ensures that this execution is deterministic and convergent — properties inherited directly from the CALM theorem.

The runtime can leverage the lattice structure for deterministic parallelism: multiple propagators can execute concurrently on different cores, with the lattice join ensuring conflict-free merging of results. This is the same insight exploited by LVars and CRDTs, applied now to a programming language runtime.

---

## 10. Compilation and Runtime

### 10.1 LLVM Target: Architecture and Strategy

Compiling Prologos to LLVM requires bridging the gap between a high-level functional-logic language and LLVM's low-level imperative IR. The compilation pipeline follows the standard functional-language approach: elaborate → optimize → ANF convert → closure convert → emit LLVM IR → link with runtime.

For LLVM IR generation, use a binding library appropriate to the implementation language: `llvm-hs` for Haskell, `inkwell` for Rust, or the LLVM C API directly. Each Prologos function becomes an LLVM function; algebraic data types become tagged unions (a tag byte followed by a union of constructor payloads); and closures become pairs of function pointers and environment pointers.

Tail call optimization is critical for both functional recursion and logic programming backtracking. LLVM supports the `tail` attribute on call instructions in tail position, enabling jump-based recursion without stack growth. Ensure that all recursive calls in tail position are annotated with `tail`.

### 10.2 Closure Conversion and ANF

Before LLVM emission, Prologos code is transformed into A-normal form (all intermediate results are named, all arguments to function calls are atomic) and closures are made explicit (free variables are captured in environment structs).

ANF conversion is a standard transformation that names all intermediate results:

Before: `f (g x) (h y)`
After: `let a = g x in let b = h y in f a b`

Closure conversion replaces lambda abstractions with closure objects:

Before: `λy. x + y` (where x is free)
After: `make_closure(λenv.λy. env.x + y, {x = x})`

These transformations produce code that maps directly to LLVM IR: `let` bindings become LLVM `alloca`/`store` instructions, function calls become LLVM `call` instructions, and closure objects become LLVM structs.

### 10.3 Garbage Collection

LLVM does not provide garbage collection; the Prologos runtime must implement its own. Two options are recommended.

For the prototype, use the **Boehm conservative garbage collector** — a drop-in replacement for `malloc` that scans the stack and heap conservatively (treating any word that looks like a pointer as a potential reference). Boehm GC is simple to integrate (link against `libgc`, replace all allocations with `GC_malloc`) and requires no changes to the LLVM IR.

For production, implement a **precise garbage collector** using LLVM's `gc.statepoint` intrinsics. The compiler emits safepoint metadata at each function call, recording which registers and stack slots contain live pointers. The GC runtime uses this metadata to walk the stack precisely, collecting only truly unreachable objects. This is more complex but eliminates the overhead and imprecision of conservative collection.

### 10.4 Process Runtime and Concurrency

The process runtime implements Prologos's session-typed concurrency. Each process is a lightweight task (green thread or coroutine) with its own stack and a set of channel endpoints. Processes communicate through typed channels, with the runtime managing message buffers and scheduling.

For the prototype, processes can be implemented as OS threads with channel endpoints backed by mutexes and condition variables. For production, a work-stealing scheduler (similar to Tokio or Go's goroutine scheduler) with lightweight cooperative multitasking is recommended.

The runtime must also implement the proof search engine (for `solve` constructs), which can be a separate component invoked synchronously by the process. The proof search engine maintains its own state (clause database, substitution table, choice point stack) and returns results to the calling process.

---

## 11. Prototyping Strategy

### 11.1 Racket as a Prototyping Platform

Racket is the recommended platform for rapid prototyping of Prologos. Its `#lang` facility allows defining new languages with custom syntax, semantics, and IDE integration. The Turnstile library provides declarative syntax for writing type systems alongside macro expansion — type checking happens during compilation, and type errors appear as syntax errors with source locations.

The recommended workflow is:

1. Define Prologos syntax as a `#lang` in Racket, using macros for surface-to-core translation.
2. Implement the type checker using Turnstile's typed syntax rules.
3. Formalize the operational semantics using PLT Redex — Racket's tool for testing reduction semantics with random term generation and property checking.
4. Use Redex's `redex-check` to verify key properties (type preservation, progress, determinism) before committing to a production implementation.

The Racket prototype serves as a living specification: it validates the design, catches subtle issues early, and provides a reference implementation for testing the production compiler.

### 11.2 Alternative: Haskell or Rust Prototype

If the implementer prefers a more performant prototype or a language with stronger static guarantees, Haskell or Rust are viable alternatives.

**Haskell** excels for type-checker implementation due to its algebraic data types, pattern matching, and monadic effect handling. The `elaboration-zoo` repository by András Kovács provides a series of progressively more complex dependent type checker implementations in Haskell, from simple evaluation to full elaboration with implicit arguments — an ideal starting point. The `pi-forall` implementation by Stephanie Weirich (used in OPLSS lectures) provides a pedagogical dependent type checker with clear code and documentation.

**Rust** offers better performance and memory control, which matters for the LLVM compilation pipeline. The `inkwell` crate provides safe LLVM IR bindings, and Rust's ownership system naturally models linear resource management. However, implementing a type checker in Rust is more verbose than in Haskell due to the lack of algebraic effects and the borrow checker's constraints on recursive data structures (requiring `Box`, `Rc`, or arena allocation).

### 11.3 Maude for Formal Verification of the Design

The Maude formal specification modules developed in the exploratory conversations (PROLOGOS-TYPES, PROLOGOS-SESSIONS, PROLOGOS-PROCESSES, PROLOGOS-TYPING) provide a formal reference for the type system. These specifications can be executed in Maude to test typing judgments, verify duality properties, and explore the design space.

The recommended use of Maude is as a **design oracle**: when the implementation produces a result that seems surprising, check it against the Maude specification. If the implementation and specification disagree, investigate — the specification may need refinement, or the implementation may have a bug. This dual-track approach (formal specification plus implementation) catches errors early and builds confidence in the design.

---

## 12. Phased Implementation Plan

The implementation is organized into six phases, each producing a usable artifact and building on the previous phase.

**Phase 0: Formal Foundations (2–4 weeks).** Refine the Maude specifications. Test typing judgments on example programs. Formalize the operational semantics in Redex. Establish the metatheoretic properties (type preservation, progress) on paper or in a proof assistant. Deliverable: verified formal specification.

**Phase 1: Core Dependent Type Checker (4–6 weeks).** Implement the parser for bracket-delimited syntax (without indentation initially). Implement the core type checker with bidirectional checking, NbE, and pattern unification. Support Π-types, Σ-types, identity types, natural numbers, and a single universe. Test against the Maude specification. Deliverable: a type checker that can check simple dependently-typed programs (vectors, finite sets, equality proofs).

**Phase 2: Logic Programming Engine (3–4 weeks).** Implement unification, SLD resolution, and basic proof search. Integrate the `solve` construct with the type checker. Add tabling for termination. Test: express append, sorting, and other standard predicates; verify that proof search finds correct witnesses. Deliverable: a dependently-typed logic programming language (without sessions).

**Phase 3: Session Types and Linearity (4–6 weeks).** Add QTT multiplicities (0, 1, ω) to the type checker. Implement session type checking (send, receive, choice, offer, recursion, end). Implement duality checking and linear context splitting. Add dependent session types (substitution in session continuations). Test: express ATM protocols, vector protocols, authentication sessions. Deliverable: a dependently-typed, session-typed logic programming language.

**Phase 4: Homoiconic Syntax and Metaprogramming (3–4 weeks).** Add indentation-sensitive parsing. Implement quoting ($) and elaborator reflection. Build the metaprogramming API (inspect types, generate code, invoke the elaborator). Add syntax sugar (`def`, `clause`, `defproc`). Deliverable: a language with full Prologos surface syntax and metaprogramming capabilities.

**Phase 5: Compilation and Runtime (6–8 weeks).** Implement erasure, ANF conversion, and closure conversion. Build the LLVM IR emitter. Integrate garbage collection (Boehm initially). Implement the process runtime with channel communication. Test: compile and run example programs natively. Deliverable: a compiled Prologos with native performance.

**Phase 6: Optimization and Polish (ongoing).** Add sized types for advanced termination checking. Optimize the propagator-based elaborator. Add MPST support. Improve error messages. Build IDE integration (Tree-sitter, LSP). Develop the standard library.

---

## 13. Key Challenges and Open Problems

Several significant challenges remain open and require careful attention during implementation.

**Decidability of dependent session type checking.** Full dependent session types push type checking toward undecidability (since session continuations contain arbitrary dependent types). The practical mitigation is to require annotations at key points (channel creation, session type declarations) and use bidirectional checking to propagate these annotations. The implementer should monitor where undecidable cases arise in practice and add annotation requirements as needed.

**Interaction between proof search and linearity.** When `solve` is invoked in a linear context, the proof search engine must respect the linear discipline — each channel is used exactly once in the resulting proof term. This requires threading the linear context through proof search, which may significantly complicate the search strategy and reduce performance. The implementer should consider restricting `solve` to unrestricted goals initially, adding linear proof search as an advanced feature.

**Performance of NbE with large terms.** Dependent type checking normalizes terms frequently, and large programs can produce large normal forms. Glued evaluation (computing normal forms lazily) mitigates this, but the implementer should profile early and optimize hot paths. Consider memoizing normalization results and using hash-consing for structural sharing.

**Compilation of logic programs to efficient native code.** The WAM is well-understood for pure Prolog, but compiling a dependently-typed, session-typed logic language is less explored. The interaction of backtracking with linear resources requires careful handling — backtracking must restore the linear context to its state before the failed branch. The implementation should use trailing (recording linear context changes on a stack for efficient restoration).

**Ergonomics and error reporting.** Dependent type errors are notoriously difficult to understand. Prologos's combination of dependent types, linear types, session types, and logic programming creates a rich but complex error landscape. Investment in high-quality error messages — with source locations, expected-vs-actual type comparisons, and suggestions for fixes — is essential for the language's usability.

---

## 14. References and Key Literature

### Core Type Theory

- Christiansen, D. (2022). "Checking Dependent Types with Normalization by Evaluation: A Tutorial." Accessible pedagogical introduction to NbE.
- Kovács, A. (2022). "Elaboration Zoo." github.com/AndrasKovacs/elaboration-zoo. Progressive implementations of dependent type elaboration.
- Kovács, A. "smalltt." github.com/AndrasKovacs/smalltt. High-performance elaboration with glued evaluation.
- Weirich, S. "pi-forall." github.com/sweirich/pi-forall. Pedagogical dependent type checker.
- Dunfield, J. and Krishnaswami, N. (2021). "Bidirectional Typing." ACM Computing Surveys, 54(5). Comprehensive survey of bidirectional type checking.
- de Moura, L. et al. (2015). "Elaboration in Dependent Type Theory." Lean's constraint-based elaboration.
- Gundry, A. (2013). "Type Inference, Haskell, and Dependent Types." PhD thesis, University of Strathclyde.
- Abel, A. and Pientka, B. (2011). "Higher-Order Dynamic Pattern Unification for Dependent Types and Records." Extensions to Miller's pattern unification.
- Cockx, J. et al. (2019). "Elaborating Dependent (Co)pattern Matching." Journal of Functional Programming. Algorithm for dependent pattern matching.

### Quantitative Type Theory

- Brady, E. (2021). "Idris 2: Quantitative Type Theory in Practice." Essential reference for QTT implementation.
- Atkey, R. (2018). "Syntax and Semantics of Quantitative Type Theory." LICS 2018. Formal foundations of QTT.
- McBride, C. (2016). "I Got Plenty o' Nuttin'." In "A List of Successes That Can Change the World," Springer. Motivating work on resource-aware type theory.

### Session Types

- Honda, K. (1993). "Types for Dyadic Interaction." CONCUR 1993. Original binary session types.
- Honda, K., Yoshida, N., and Carbone, M. (2008). "Multiparty Asynchronous Session Types." POPL 2008. MPST foundations.
- Wadler, P. (2012). "Propositions as Sessions." ICFP 2012. Linear logic and session types correspondence.
- Caires, L. and Pfenning, F. (2010). "Session Types as Intuitionistic Linear Propositions." CONCUR 2010. Propositions-as-sessions interpretation.
- Toninho, B., Caires, L., and Pfenning, F. (2011). "Dependent Session Types via Intuitionistic Linear Type Theory." PPDP 2011. Dependent session types.
- Dardha, O. and Gay, S.J. (2018). "A New Linear Logic for Deadlock-Free Session-Typed Processes." FoSSaCS 2018. Priority-based deadlock freedom.
- Fowler, S. et al. (2019). "Exceptional Asynchronous Session Types." POPL 2019. Session types in Links.

### Logic Programming

- Aït-Kaci, H. (1991). "Warren's Abstract Machine: A Tutorial Reconstruction." MIT Press. Comprehensive WAM reference.
- Friedman, D., Byrd, W., and Kiselyov, O. (2005). "The Reasoned Schemer." MIT Press. miniKanren introduction.
- Frühwirth, T. (2009). "Constraint Handling Rules." Cambridge University Press. CHR monograph.
- Swift, T. and Warren, D.S. (2012). "XSB: Extending Prolog with Tabled Logic Programming." Theory and Practice of Logic Programming. SLG resolution and tabling.

### Propagator Model

- Radul, A. and Sussman, G.J. (2009). "The Art of the Propagator." MIT-CSAIL-TR-2009-002.
- Radul, A. (2009). "Propagation Networks: A Flexible and Expressive Substrate for Computation." PhD dissertation, MIT.
- Kuper, L. and Newton, R.N. (2013). "LVars: Lattice-Based Data Structures for Deterministic Parallelism." FHPC 2013. Lattice-based deterministic parallelism.
- Hellerstein, J.M. and Alvaro, P. (2019). "Keeping CALM: When Distributed Consistency is Easy." Communications of the ACM. CALM theorem.

### Compilation

- GHC LLVM Backend. downloads.haskell.org/ghc/latest/docs/users_guide/codegens.html. Reference for compiling functional languages to LLVM.
- LLVM Garbage Collection. llvm.org/docs/GarbageCollection.html. LLVM GC infrastructure documentation.

### Prototyping and Tools

- Felleisen, M. et al. "PLT Redex." redex.racket-lang.org. Operational semantics testing.
- Chang, S. et al. "Turnstile." docs.racket-lang.org/turnstile. Type system DSL for Racket.
- Clavel, M. et al. (2007). "All About Maude." Springer. Maude formal specification language.

---

*This implementation guidance was compiled as part of the Πρόλογος (Prologos) language design project, synthesizing research on dependent type theory, propagator networks, session types, and logic programming with the formal specifications and design notes developed across multiple exploratory sessions.*
