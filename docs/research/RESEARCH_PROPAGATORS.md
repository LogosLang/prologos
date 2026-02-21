# Research Report: Propagator Networks

## Sussman's Propagator Model, Lattice-Theoretic Formalisms, and Connections to Type Theory

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Historical Context and Antecedents](#2-historical-context-and-antecedents)
   - 2.1 [Stallman and Sussman's Constraint Propagation (1977)](#21-stallman-and-sussmans-constraint-propagation-1977)
   - 2.2 [Steele and Sussman's Constraint Languages (1976–1980)](#22-steele-and-sussmans-constraint-languages-19761980)
   - 2.3 [Truth Maintenance Systems: Doyle and de Kleer](#23-truth-maintenance-systems-doyle-and-de-kleer)
   - 2.4 [Waltz Filtering and Arc Consistency](#24-waltz-filtering-and-arc-consistency)
   - 2.5 [The Actor Model (Hewitt, 1973)](#25-the-actor-model-hewitt-1973)
3. [The Radul–Sussman Propagator Model](#3-the-radulsussman-propagator-model)
   - 3.1 [Core Architecture: Cells, Propagators, Scheduler](#31-core-architecture-cells-propagators-scheduler)
   - 3.2 [The Merge Operation](#32-the-merge-operation)
   - 3.3 [Partial Information and the "Nothing" Value](#33-partial-information-and-the-nothing-value)
   - 3.4 [Multidirectional Computation](#34-multidirectional-computation)
   - 3.5 [Supported Values and Dependency Tracking](#35-supported-values-and-dependency-tracking)
   - 3.6 [Contradiction, Nogood Sets, and Backtracking](#36-contradiction-nogood-sets-and-backtracking)
   - 3.7 [The "Everything is a Propagator" Philosophy](#37-the-everything-is-a-propagator-philosophy)
4. [Lattice-Theoretic Foundations](#4-lattice-theoretic-foundations)
   - 4.1 [Cells as Lattice Elements](#41-cells-as-lattice-elements)
   - 4.2 [Merge as Lattice Join](#42-merge-as-lattice-join)
   - 4.3 [Fixed-Point Semantics: Knaster-Tarski and Kleene Iteration](#43-fixed-point-semantics-knaster-tarski-and-kleene-iteration)
   - 4.4 [Monotonicity and Convergence Guarantees](#44-monotonicity-and-convergence-guarantees)
   - 4.5 [Domain Theory and Scott Continuity](#45-domain-theory-and-scott-continuity)
5. [Abstract Interpretation and Galois Connections](#5-abstract-interpretation-and-galois-connections)
   - 5.1 [Cousot and Cousot's Framework](#51-cousot-and-cousots-framework)
   - 5.2 [Propagators as Decentralized Abstract Interpreters](#52-propagators-as-decentralized-abstract-interpreters)
   - 5.3 [Widening and Narrowing for Infinite Lattices](#53-widening-and-narrowing-for-infinite-lattices)
6. [CRDTs, LVars, and Distributed Monotonic Computation](#6-crdts-lvars-and-distributed-monotonic-computation)
   - 6.1 [Conflict-Free Replicated Data Types (CRDTs)](#61-conflict-free-replicated-data-types)
   - 6.2 [LVars: Lattice Variables for Deterministic Parallelism](#62-lvars-lattice-variables-for-deterministic-parallelism)
   - 6.3 [Bloom and BloomL: Lattice-Based Distributed Programming](#63-bloom-and-blooml-lattice-based-distributed-programming)
   - 6.4 [The CALM Theorem](#64-the-calm-theorem)
7. [Datalog, Flix, and Monotone Fixed-Point Languages](#7-datalog-flix-and-monotone-fixed-point-languages)
   - 7.1 [Datalog and Bottom-Up Evaluation](#71-datalog-and-bottom-up-evaluation)
   - 7.2 [Flix: Lattice-Based Datalog Extension](#72-flix-lattice-based-datalog-extension)
   - 7.3 [Datafun: Functional Monotone Computation](#73-datafun-functional-monotone-computation)
   - 7.4 [Ascent: Datalog in Rust](#74-ascent-datalog-in-rust)
8. [Constraint Handling Rules (CHR)](#8-constraint-handling-rules)
9. [Unification as Propagation](#9-unification-as-propagation)
   - 9.1 [The Substitution Lattice](#91-the-substitution-lattice)
   - 9.2 [Type Inference as Constraint Propagation](#92-type-inference-as-constraint-propagation)
10. [Propagators and Type Systems](#10-propagators-and-type-systems)
    - 10.1 [Bidirectional Type Checking as Propagation](#101-bidirectional-type-checking-as-propagation)
    - 10.2 [Constraint-Based Type Inference](#102-constraint-based-type-inference)
    - 10.3 [Dependent Type Elaboration](#103-dependent-type-elaboration)
11. [Propagators and Concurrency](#11-propagators-and-concurrency)
    - 11.1 [Kahn Process Networks](#111-kahn-process-networks)
    - 11.2 [Deterministic Parallelism Through Monotonicity](#112-deterministic-parallelism-through-monotonicity)
    - 11.3 [Connection to the Actor Model](#113-connection-to-the-actor-model)
12. [Incremental and Reactive Computation](#12-incremental-and-reactive-computation)
    - 12.1 [Self-Adjusting Computation and Adapton](#121-self-adjusting-computation-and-adapton)
    - 12.2 [Differential Dataflow](#122-differential-dataflow)
    - 12.3 [Functional Reactive Programming](#123-functional-reactive-programming)
    - 12.4 [Spreadsheet Computation](#124-spreadsheet-computation)
13. [Modern Implementations](#13-modern-implementations)
    - 13.1 [Constraint Programming Systems](#131-constraint-programming-systems)
    - 13.2 [Language-Specific Libraries](#132-language-specific-libraries)
14. [Extensions and Variations](#14-extensions-and-variations)
    - 14.1 [Higher-Order Propagators](#141-higher-order-propagators)
    - 14.2 [Probabilistic Propagation and Belief Propagation](#142-probabilistic-propagation-and-belief-propagation)
    - 14.3 [Factor Graphs and Message Passing](#143-factor-graphs-and-message-passing)
    - 14.4 [SMT Solvers and Theory Propagation](#144-smt-solvers-and-theory-propagation)
    - 14.5 [Message Passing Neural Networks](#145-message-passing-neural-networks)
15. [Connections to Our Language Design](#15-connections-to-our-language-design)
    - 15.1 [Propagators for Type Inference and Elaboration](#151-propagators-for-type-inference-and-elaboration)
    - 15.2 [Session Type Verification as Propagation](#152-session-type-verification-as-propagation)
    - 15.3 [Linear Types and Resource Tracking](#153-linear-types-and-resource-tracking)
    - 15.4 [Propagators as a Runtime Model](#154-propagators-as-a-runtime-model)
    - 15.5 [Synthesis: Toward a Propagator-Aware Dependent Type System](#155-synthesis-toward-a-propagator-aware-dependent-type-system)
16. [References and Key Literature](#16-references-and-key-literature)

---

## 1. Introduction

This report presents an exhaustive survey of the Propagator computational model — from its origins in Sussman's constraint propagation work in the 1970s, through Radul and Sussman's 2009 formalization, to the broader ecosystem of lattice-theoretic formalisms that share its mathematical foundations. The investigation is motivated by our language design project: a programming language featuring dependent types as first-class citizens, session types for protocol correctness, and linear types for memory safety.

Propagators are of particular interest for several reasons. First, the propagator model is fundamentally built on lattice theory — the same mathematical structure that underlies abstract interpretation, type inference, and program analysis. Second, propagators offer a model of computation where information flows multidirectionally and accumulates monotonically, a property deeply connected to the CALM theorem in distributed systems and the determinism guarantees of LVars. Third, the propagator architecture — autonomous computational agents communicating through shared cells that accumulate partial information — offers a compelling substrate for type checking, elaboration, and constraint solving in a dependently typed language.

The report is organized in three arcs. Sections 2–6 cover the propagator model itself and its lattice-theoretic foundations. Sections 7–14 survey the ecosystem of related formalisms, implementations, and extensions. Section 15 synthesizes these threads into concrete connections for our language design.

---

## 2. Historical Context and Antecedents

### 2.1 Stallman and Sussman's Constraint Propagation (1977)

The propagator model traces its lineage directly to Richard Stallman and Gerald Jay Sussman's 1977 paper "Forward Reasoning and Dependency-Directed Backtracking in a System for Computer-Aided Circuit Analysis" (Artificial Intelligence, vol. 9, pp. 135–196). This work introduced constraint propagation for analyzing electrical circuits using the rule-based EL language. Each circuit element was expressed as a set of constraints; when one variable's value became known, it propagated through the constraint network, potentially determining other variables' values.

Critically, this 1977 work also introduced **dependency-directed backtracking** — the insight that when a contradiction is discovered, the system should track which assumptions led to the contradiction and backtrack specifically to those assumptions, rather than blindly reverting to the most recent choice point. This technique, later formalized as nogood recording, became a central feature of the propagator model three decades later.

### 2.2 Steele and Sussman's Constraint Languages (1976–1980)

Guy Lewis Steele Jr. and Gerald Jay Sussman developed constraint languages expressing hierarchical constraint networks in "CONSTRAINTS: A Language for Expressing Almost-Hierarchical Descriptions" (MIT AI Lab, 1980; earlier versions from 1976). This work demonstrated that constraint propagation could be practical and efficient. Steele's PhD thesis further developed algebraic constraint propagation with dependency analysis for inconsistency detection. The key contribution was showing that many engineering and scientific computations are naturally expressed as bidirectional constraint networks rather than unidirectional functions.

### 2.3 Truth Maintenance Systems: Doyle and de Kleer

The AI community's work on truth maintenance systems directly influenced the propagator model's handling of assumptions and contradictions.

**Jon Doyle's TMS (1979)** ("A Truth Maintenance System," Artificial Intelligence, vol. 12, pp. 231–272) introduced the concept of explicitly tracking justifications for beliefs, enabling non-monotonic reasoning by recording which beliefs support which conclusions and retracting conclusions when their support is invalidated.

**Johan de Kleer's ATMS (1986)** ("An Assumption-Based Truth Maintenance System," Artificial Intelligence, vol. 28, pp. 127–162) advanced this by working with assumption sets rather than individual justifications, enabling efficient handling of multiple consistent contexts simultaneously. The ATMS can maintain several alternative worldviews in parallel, switching between them without expensive retraction and re-derivation.

The propagator model integrates both traditions through its *supported values* — pairs of (value, supporting-premises) — enabling cells to hold contingent information that can be revised when premises are retracted.

### 2.4 Waltz Filtering and Arc Consistency

David Waltz's 1975 picture recognition algorithm introduced constraint propagation for computer vision, using local consistency to label line drawings. Alan Mackworth formalized this as **arc consistency** in his 1977 paper "The Complexity of Some Polynomial Network Consistency Algorithms for Constraint Satisfaction Problems." A pair of variables (X, Y) is arc-consistent if for every value in X's domain, there exists a compatible value in Y's domain.

The AC-3 algorithm maintains arc consistency by iteratively checking and pruning variable domains — a direct precursor to propagator-style computation. Propagators generalize this from domain pruning to arbitrary partial-information accumulation.

### 2.5 The Actor Model (Hewitt, 1973)

Carl Hewitt's Actor Model ("A Universal Modular ACTOR Formalism for Artificial Intelligence," 1973) provided conceptual foundations: autonomous computational agents with local state, communicating through message passing, without central control. While propagators are not explicitly actors, the architectural similarity — autonomous computation agents interconnected through shared storage — reflects this influence. The crucial distinction is that actors communicate through point-to-point messages, while propagators communicate through shared cells that accumulate information from multiple sources.

---

## 3. The Radul–Sussman Propagator Model

### 3.1 Core Architecture: Cells, Propagators, Scheduler

The propagator model, formalized by Alexey Radul and Gerald Jay Sussman in "The Art of the Propagator" (MIT-CSAIL-TR-2009-002, 2009) and expanded in Radul's PhD dissertation "Propagation Networks: A Flexible and Expressive Substrate for Computation" (2009), introduces a fundamentally different computational substrate built on two primary abstractions.

**Cells** are stateful storage entities that *remember things*. Unlike traditional memory locations that hold a single definitive value, cells accumulate **partial information** from multiple sources. A cell can be informed by any number of propagators simultaneously, and its contents represent the totality of what is known about the quantity it describes.

**Propagators** are stateless, autonomous machines that *compute things*. Each propagator watches one or more cells for changes, performs some computation when triggered, and writes results back to cells. Propagators are conceptually always running — they react to any new information in their input cells.

**The Scheduler** maintains a list of jobs (thunks) to execute. Jobs run serially and are presumed idempotent, so the scheduler need only track whether a job has been scheduled, not how many times. When a propagator writes new information to a cell, all propagators that read from that cell are scheduled for re-execution. The scheduler continues until quiescence — when no more jobs remain.

The relationship between cells and propagators is fundamentally different from the traditional procedure-memory relationship. In conventional computation, procedures are active and memory is passive. In propagator networks, both are active: cells actively manage their information state through merging, and propagators actively respond to information changes.

### 3.2 The Merge Operation

The merge operation is the central innovation of the propagator model. When a propagator writes information to a cell, the new information is not simply stored — it is *merged* with the cell's existing contents. Merge accepts two partial information structures and produces a third that encompasses all information from both.

Merge must satisfy three algebraic properties:

- **Commutativity**: merge(a, b) = merge(b, a)
- **Associativity**: merge(merge(a, b), c) = merge(a, merge(b, c))
- **Idempotency**: merge(a, a) = a

These properties ensure that the final cell state is independent of the order in which propagators execute. Regardless of scheduling decisions, the same information yields the same result — a property essential for deterministic semantics in a system with inherently concurrent execution.

### 3.3 Partial Information and the "Nothing" Value

Radul's key contribution was formalizing the concept of *partial information*. Cells do not hold complete values; they hold incomplete knowledge about values that can be incrementally refined. This partial information is structured as elements of a lattice (detailed in Section 4).

The **"nothing"** value represents complete absence of information — the lattice bottom. A cell containing nothing knows nothing about its quantity. As computation proceeds, propagators contribute information, moving the cell's state upward in the lattice. The cell can hold, for example, "this is an integer," then "this is a positive integer," then "this is the integer 42."

The information in a cell **never decreases**. This monotonicity is not merely a design choice — it is the mathematical foundation ensuring convergence and determinism.

### 3.4 Multidirectional Computation

Perhaps the most practically revolutionary aspect of the propagator model is that computation flows in *all directions simultaneously*. Consider the relationship between Celsius and Fahrenheit temperatures:

```
C = (F - 32) × 5/9
```

In traditional programming, this is a function from F to C. To compute in the reverse direction, one must write a separate function. In a propagator network, this constraint is expressed once, and the network automatically solves for whichever variable is unknown. Propagators implementing multiplication, addition, subtraction, and division work bidirectionally:

- Given F and needing C: propagators flow leftward
- Given C and needing F: propagators flow rightward
- Given both: propagators verify consistency

This arises naturally from the merge semantics. Each propagator contributes whatever information it can derive from its inputs, and merge reconciles all contributions. There is no concept of "input" and "output" — only "cells I read from" and "cells I write to," and many propagators both read from and write to the same cells.

### 3.5 Supported Values and Dependency Tracking

A supported value is a pair of (partial information, set of premises). Rather than recording absolute facts, cells can hold contingent values — information that is true given certain premises are believed. This enables reasoning under uncertainty and managing multiple hypothetical scenarios.

Each cell can contain a Truth Maintenance System (TMS): a set of supported values, where each entry pairs information with its supporting premises. The logical meaning of a TMS as information is the conjunction of all its contingent values. This architecture enables the propagator network to simultaneously maintain multiple consistent worldviews and reason about which assumptions lead to which conclusions.

### 3.6 Contradiction, Nogood Sets, and Backtracking

**Contradiction** represents the lattice top — the impossible state where incompatible information has been merged. When a cell discovers contradiction, the dependency structure enables intelligent recovery through dependency-directed backtracking:

1. The premises supporting the contradiction are extracted as a **nogood set** — a set of assumptions that cannot all be simultaneously true.
2. The system records this nogood and must retract at least one premise.
3. If some premises are derived from search (hypothetical choices), backtracking occurs automatically, targeting the actual culprits rather than blindly reverting to the most recent choice.

This dependency-directed backtracking, inherited from Stallman and Sussman's 1977 work and de Kleer's ATMS, is what transforms propagator networks from simple constraint propagation into a system capable of implicit, incremental, distributed search.

### 3.7 The "Everything is a Propagator" Philosophy

Radul and Sussman developed the propagator model on a unifying principle: all computational elements are propagators. This extends far beyond constraint solving:

- **Expression evaluation**: Traditional sequential computation is a degenerate case of propagation (unidirectional, single-write cells)
- **Constraint satisfaction**: Bidirectional constraints are the natural case
- **Search**: Hypothetical reasoning via TMS-backed cells with premise exploration
- **Inference**: Rule-based reasoning where each rule is a propagator
- **Type checking**: Type constraints flow through propagator networks

This philosophical stance makes the propagator model a flexible substrate accommodating logic programming, functional programming, constraint programming, and type inference within a unified framework.

---

## 4. Lattice-Theoretic Foundations

### 4.1 Cells as Lattice Elements

The partial information in a cell is formally an element of a lattice (L, ≤), where the ordering ≤ represents the "has at least as much information as" relation. A complete lattice (L, ≤) is a partially ordered set where every subset S ⊆ L has both a least upper bound (join, ⊔S) and a greatest lower bound (meet, ⊓S).

For propagator networks, the relevant structure is often a **join-semilattice** — a set with a binary join operation that is commutative, associative, and idempotent, with a least element ⊥. Cells hold elements of such semilattices, and the merge operation computes joins.

Key lattice elements:

- **Bottom (⊥)**: The "nothing" value, representing absence of information
- **Interior elements**: Partial information of varying specificity
- **Top (⊤)**: Contradiction, representing incompatible information

### 4.2 Merge as Lattice Join

The merge operation implements the lattice join (least upper bound). Given two partial information structures a and b, merge(a, b) = a ⊔ b — the least element that is at least as informative as both a and b.

The algebraic properties of merge follow directly from the lattice axioms:

```
Commutativity:  a ⊔ b = b ⊔ a
Associativity:  (a ⊔ b) ⊔ c = a ⊔ (b ⊔ c)
Idempotency:    a ⊔ a = a
Identity:       a ⊔ ⊥ = a
Annihilation:   a ⊔ ⊤ = ⊤
```

The identity law ensures that adding "nothing" to any information leaves it unchanged. The annihilation law ensures that once a contradiction is reached, no further information can rescue the cell — it remains contradictory.

### 4.3 Fixed-Point Semantics: Knaster-Tarski and Kleene Iteration

The mathematical guarantee that propagator networks converge rests on fixed-point theorems from lattice theory.

**The Knaster-Tarski Fixed-Point Theorem**: If (L, ≤) is a complete lattice and f : L → L is a monotone function (order-preserving), then the set of fixed points of f forms a complete lattice. In particular, the least fixed point exists:

```
lfp(f) = ⊓{x ∈ L | f(x) ≤ x}
```

**Kleene's Fixed-Point Theorem**: On a directed-complete partial order (dcpo) with a least element ⊥, the least fixed point of a Scott-continuous function f is computed by iterating from the bottom:

```
lfp(f) = ⊔{fⁿ(⊥) | n ∈ ℕ}
```

This produces an ascending chain ⊥ ≤ f(⊥) ≤ f²(⊥) ≤ ... converging to the least fixed point. Each iteration of the propagator network corresponds to one step in this Kleene iteration: propagators refine cell values, moving them upward in the lattice toward the stable state.

### 4.4 Monotonicity and Convergence Guarantees

Every propagator must be **monotone** with respect to the lattice ordering: if a cell's value increases (gains information), the propagator's output must not decrease. Formally, if c₁ ≤ c₂, then P(c₁) ≤ P(c₂) for every propagator P.

Monotonicity guarantees three critical properties:

1. **Termination**: On a lattice of finite height (no infinite ascending chains), the network reaches a fixed point in at most height(L) iterations.
2. **Determinism**: The final state is independent of propagator scheduling order — all execution orders reach the same fixed point.
3. **Consistency**: Partial results are always sound approximations of the final result.

For lattices of infinite height (e.g., the interval lattice over real numbers), **widening operators** are needed to ensure convergence in finite iterations, at the cost of some precision.

### 4.5 Domain Theory and Scott Continuity

The mathematical foundations connect to Dana Scott's domain theory. A function between partially ordered sets is **Scott-continuous** if it preserves directed joins (suprema of directed subsets). Propagators must be Scott-continuous: they preserve information ordering and produce output consistent with their input's information content.

**Scott domains** are partially ordered sets that represent partial algebraic data ordered by information content. Cells in a propagator network are conceptually Scott domains, storing elements ordered by "has at least as much information as." The Scott topology defines which information states are computationally observable: a property is observable if once it becomes true, it remains true as information increases — precisely the monotonicity property of propagator cells.

---

## 5. Abstract Interpretation and Galois Connections

### 5.1 Cousot and Cousot's Framework

Abstract interpretation, formalized by Patrick and Radhia Cousot in their foundational 1977 paper "Abstract Interpretation: A Unified Lattice Model for Static Analysis of Programs by Construction or Approximation of Fixpoints" (POPL 1977), uses lattice structures to compute sound approximations of program behavior. The framework rests on Galois connections between concrete and abstract domains.

A **Galois connection** (α, γ) between concrete lattice C and abstract lattice A consists of:

- **Abstraction function** α : C → A (maps concrete values to abstract approximations)
- **Concretization function** γ : A → C (maps abstract values to their concrete meanings)

satisfying: α(x) ≤_A y if and only if x ≤_C γ(y), for all x ∈ C, y ∈ A. This adjunction ensures that abstraction is sound: if an abstract value over-approximates a concrete value, the concretization of the abstract value contains the original concrete value.

### 5.2 Propagators as Decentralized Abstract Interpreters

A propagator network can be viewed as a **decentralized abstract interpreter**:

- **Cells** correspond to abstract domain elements at program points
- **Propagators** implement local transfer functions (abstract semantics of program operations)
- **Merge** computes joins in the abstract domain at control-flow merge points
- **The fixed point** represents the abstract interpretation result

This perspective unifies abstract interpretation theory with propagator networks. In a traditional abstract interpreter, a centralized worklist algorithm applies transfer functions and computes joins. In a propagator network, these operations are decentralized: each propagator independently monitors its inputs and contributes information to its outputs, with cells managing their own merging. The mathematical guarantees are identical — both compute least fixed points of monotone functions on lattices.

### 5.3 Widening and Narrowing for Infinite Lattices

On infinite-height lattices, Kleene iteration may not converge. Cousot and Cousot introduced **widening (∇)** and **narrowing (△)** operators:

**Widening** accelerates convergence by over-approximating:

```
a ∇ b ≥ a ⊔ b
```

For example, interval widening: [a,b] ∇ [a',b'] = [if a' < a then -∞ else a, if b' > b then +∞ else b]. This ensures finite convergence at the cost of precision.

**Narrowing** recovers precision after widening by computing better approximations from above:

```
a ≤ a △ b ≤ a    (when b ≤ a)
```

The two-phase strategy — widen to a coarse fixed point, then narrow to refine — is directly applicable to propagator networks operating over infinite-height lattices.

---

## 6. CRDTs, LVars, and Distributed Monotonic Computation

### 6.1 Conflict-Free Replicated Data Types

Conflict-Free Replicated Data Types (CRDTs), formalized by Shapiro, Preguiça, Baquero, and Zawirski (INRIA, 2011), are distributed data structures achieving **strong eventual consistency** without coordination. State-based CRDTs (CvRDTs) require their state to form a join-semilattice, with merge computing the lattice join — precisely the same algebraic structure required by propagator cells.

| CRDTs | Propagators |
|-------|-------------|
| State ∈ join-semilattice | Cell value ∈ lattice |
| Merge operation ⊔ | Propagator merge ⊔ |
| Commutativity of merge | Order-independence |
| Idempotency of merge | Safe re-execution |
| Monotonic state growth | Information only increases |

The structural isomorphism is exact: both models enforce convergence through the same lattice-theoretic mechanisms.

### 6.2 LVars: Lattice Variables for Deterministic Parallelism

LVars (Lattice Variables), introduced by Lindsey Kuper and Ryan Newton in "LVars: Lattice-Based Data Structures for Deterministic Parallelism" (FHPC 2013) and expanded in "Freeze After Writing: Quasi-Deterministic Parallel Programming with LVars" (POPL 2014, with Turon and Krishnaswami), generalize single-assignment variables to allow monotonically-increasing updates with respect to user-specified lattices.

**Core operations**:

- **put(lv, v)**: Write value v to LVar, merging with current value via ⊔. The state can only increase.
- **get(lv, threshold)**: Block until lv reaches or exceeds threshold, then return any value ≥ threshold.

**Determinism guarantee**: Because writes are monotonic and threshold reads reveal only lower bounds (not exact values), the observable behavior is independent of scheduling. Multiple writers are guaranteed not to create inconsistencies, and readers cannot observe the ordering of concurrent writes. This is the same determinism that propagator networks enjoy — and for the same lattice-theoretic reasons.

Kuper's PhD dissertation "Lattice-Based Data Structures for Deterministic Parallel and Distributed Programming" (UCSC) explicitly connected LVars to CRDTs, showing that the same mathematical structure ensures convergence in both parallel programming and distributed systems.

### 6.3 Bloom and BloomL: Lattice-Based Distributed Programming

The Bloom programming language (Alvaro, Conway, Hellerstein et al., 2011) is a declarative language for distributed computation based on Datalog. **BloomL** (Conway et al., "Logic and Lattices for Distributed Programming," SOCC 2012) extends Bloom to support user-defined lattices as first-class citizens, enabling distributed programs to work with monotonic data structures beyond simple relations.

BloomL enables expressing non-relational analyses (approximations, bounds), formal verification of consistency via CALM analysis, and efficient evaluation using logic-programming strategies — all grounded in the same lattice-theoretic semantics as propagator networks.

### 6.4 The CALM Theorem

The CALM theorem (Consistency As Logical Monotonicity), established by Hellerstein and Alvaro ("Keeping CALM: When Distributed Consistency is Easy," CACM, 2019; originally conjectured at PODS 2010), provides the theoretical bridge connecting monotonicity across all these frameworks:

> **Theorem**: A distributed program has a consistent, coordination-free implementation if and only if it can be expressed in monotonic logic.

Monotonic programs — those whose predicates only accumulate and never retract — can proceed safely despite missing information. Non-monotonic programs must wait for all information before producing results, requiring coordination (e.g., barriers, consensus protocols).

The CALM theorem connects directly to propagators: propagator networks are inherently monotonic (cells never lose information), and therefore they are inherently amenable to coordination-free distributed execution. This has profound implications for implementing propagator-based type checking in a distributed compilation system.

---

## 7. Datalog, Flix, and Monotone Fixed-Point Languages

### 7.1 Datalog and Bottom-Up Evaluation

Datalog's bottom-up evaluation directly implements Kleene iteration:

```
T⁰     = base facts
T^(n+1) = Tⁿ ∪ {consequences of rules applied to Tⁿ}
lfp     = fixed point reached when Tⁿ = T^(n+1)
```

**Semi-naive evaluation** optimizes this by tracking only **delta relations** (newly derived facts), avoiding redundant rule applications:

```
ΔTⁱ     = Tⁱ \ T^(i-1)
T^(i+1) = Tⁱ ∪ apply_rules(ΔTⁱ)
```

This incremental strategy — recomputing only what is affected by new facts — parallels the propagator scheduler's strategy of only re-executing propagators whose inputs have changed.

### 7.2 Flix: Lattice-Based Datalog Extension

Flix (Olhoták and Estrada, "From Datalog to Flix: A Declarative Language for Fixed Points on Lattices," PLDI 2016) extends Datalog from relations over atoms to relations over **arbitrary lattice values**. Instead of asking "does this fact hold?" (a Boolean lattice), Flix asks "what is the lattice value associated with this key?"

```flix
rel ShortestPath(src: City, dst: City, dist: MinInt)
```

The `MinInt` lattice computes shortest paths by taking minimums. Users define lattices with join operations, and Flix's fixed-point engine computes over them using semi-naive evaluation with widening support for infinite-height lattices. Flix has been applied to program analysis (IFDS, IDE frameworks), graph algorithms, and Datalog-based reasoning.

### 7.3 Datafun: Functional Monotone Computation

Datafun (Arntzenius and Krishnaswami, "Datafun: A Functional Datalog," ICFP 2016; "Seminaïve Evaluation for a Higher-Order Functional Language," POPL 2020) is a pure functional language integrating Datalog's fixed-point semantics with higher-order functions and a type system that distinguishes **monotone** from **discrete** contexts:

```
Discrete context Δ: Non-monotone variables
Monotone context Γ: Monotone variables
```

A term is monotone in Γ if x ≤ y in Γ implies t[x/z] ≤ t[y/z]. The type system statically guarantees that fixed-point computations are monotone, ensuring convergence by construction. The POPL 2020 paper shows how to incrementalize Datafun programs automatically through semi-naive evaluation — computing only the "delta" from each iteration.

Datafun is particularly relevant to our language design because it demonstrates how monotonicity can be tracked through a type system, suggesting that a dependently typed language could express and verify monotonicity properties at the type level.

### 7.4 Ascent: Datalog in Rust

Ascent (github.com/s-arash/ascent) embeds Datalog in Rust via macros, supporting lattice-based fixed-point computation, parallel execution via Rayon, custom data structures (BYODS), and stratified negation and aggregation. It demonstrates that lattice-based propagation can be efficiently embedded in a systems programming language.

---

## 8. Constraint Handling Rules

Constraint Handling Rules (CHR), introduced by Thom Frühwirth in 1991 and formalized in his Cambridge University Press monograph, provide a closely related formalism for constraint propagation. CHR defines two rule types:

**Simplification rules**: c₁, ..., cₙ ⟺ d₁, ..., dₘ — replace constraints on the left with constraints on the right, maintaining logical equivalence.

**Propagation rules**: c₁, ..., cₙ ⟹ d₁, ..., dₘ — add constraints on the right while keeping the left constraints (logically redundant but computationally useful propagation).

The operational semantics iterate: select a constraint and matching rule, apply the rule body, update the constraint store, and repeat until no rules apply (fixed point).

| CHR | Propagators |
|-----|-------------|
| Constraint store | Cell values |
| Simplification/propagation rules | Propagator functions |
| Fixed-point semantics | Information accumulation to quiescence |
| Rule application trigger | Cell-change scheduler trigger |
| Confluence property | Order-independent convergence |

CHR's confluence property (final constraint store independent of rule application order) directly parallels the order-independence of propagator networks. CHR has been integrated into Prolog systems (SWI-Prolog, SICStus, Ciao) and applied to type system implementations, abductive reasoning, and multi-agent systems.

---

## 9. Unification as Propagation

### 9.1 The Substitution Lattice

Unification can be viewed as propagation on a lattice of substitutions. The substitution lattice is ordered by generality:

```
σ ≤ τ  iff  ∃ρ : τ = σ ∘ ρ    (σ is more general than τ)
```

- **Elements**: Substitutions mapping variables to terms
- **Bottom**: The identity substitution (no information)
- **Join**: The most general unifier (mgu) of two substitutions
- **Top**: Failure (no unifier exists — contradiction)

Unification computes the join: given two partial substitutions, find their least common refinement. This is precisely the merge operation on a lattice of type substitutions.

### 9.2 Type Inference as Constraint Propagation

Hindley-Milner type inference can be reformulated as constraint propagation:

1. **Constraint generation**: Bottom-up traversal of the AST produces equality constraints on type variables.
2. **Constraint solving**: Unification resolves constraints by propagating type information.
3. **Fixed point**: When no new information can be derived, the principal type is found.

Each type equation is analogous to a propagator. Each type variable is analogous to a cell. Unification computes lattice joins on the substitution lattice. The principal type is the least fixed point of the constraint system.

This perspective, formalized by Pottier and Rémy in "The Essence of ML Type Inference" (2005), separates constraint generation from constraint solving, enabling modular analysis, better error reporting, and flexible solving strategies — all benefits that the propagator architecture provides.

---

## 10. Propagators and Type Systems

### 10.1 Bidirectional Type Checking as Propagation

Bidirectional type checking, as formalized by Dunfield and Krishnaswami ("Complete and Easy Bidirectional Typechecking for Higher-Rank Polymorphism," ICFP 2014; tutorial by Christiansen, 2022), provides a direct connection between propagation and type systems.

Bidirectional type checking operates in two modes:

- **Checking mode**: Given a term and a type, verify that the term has that type. Information flows *downward* from context to subterms.
- **Synthesis mode**: Given a term, infer its type. Information flows *upward* from subterms to context.

These two modes implement **bidirectional information propagation** — precisely the multidirectional computation that propagator networks provide. Type annotations serve as "seeds" that inject information into the network, and the checking/synthesis modes propagate this information in both directions through the syntax tree.

For dependently typed languages, bidirectional checking is essential because full type inference is undecidable. The propagator perspective suggests a generalization: rather than two fixed modes, use an arbitrary propagator network where type information flows in all available directions, converging to a fixed point.

### 10.2 Constraint-Based Type Inference

Constraint-based type inference (Pottier and Rémy, 2005; Heeren et al., 2002) explicitly separates constraint generation from constraint solving:

1. **Constraint generation**: Walk the AST, producing type equality constraints (analogous to building a propagator network).
2. **Constraint solving**: Solve the constraint system (analogous to running the propagator network to quiescence).

This separation enables better error messages (constraint source location is tracked), modular analysis (constraints from different modules can be combined), pluggable solving strategies (different unification algorithms can be used), and incremental solving (new constraints can be added without re-solving from scratch).

The connection to propagators is direct: each constraint is a propagator, each type variable is a cell, and the solution is the least fixed point of the constraint network.

### 10.3 Dependent Type Elaboration

Elaboration in dependent type theory — transforming partially-specified surface syntax into fully-specified core terms — is inherently a propagation process. The elaborator must resolve implicit arguments via higher-order unification, infer universe levels, resolve type class instances, insert coercions, and check and infer types bidirectionally. Each of these tasks produces partial information about the final term, and the elaborator must combine all these information sources into a consistent whole.

Kovács's "Elaboration Zoo" (github.com/AndrasKovacs/elaboration-zoo) provides minimal implementations showing how dependent type elaboration can be structured as iterative refinement — essentially, propagation. The elaborator maintains a set of metavariables (analogous to cells) and a set of constraints (analogous to propagators), and iteratively refines the metavariables until all constraints are satisfied.

---

## 11. Propagators and Concurrency

### 11.1 Kahn Process Networks

Kahn Process Networks (1974) provide a theoretical foundation for deterministic parallel dataflow computation. Processes communicate through FIFO channels with blocking reads and non-blocking writes. The crucial property: channel histories grow monotonically, and the network's output is deterministic regardless of execution timing.

The connection to propagators is direct: both models enforce monotonic growth of information content, both support natural parallelism through data dependencies, and both guarantee deterministic outcomes. Kahn networks can be viewed as a specialized class of propagator networks where cells are FIFO channels and propagators are sequential processes.

### 11.2 Deterministic Parallelism Through Monotonicity

The lattice structure of propagator cells provides a natural foundation for deterministic parallelism. Multiple propagators can write to the same cell concurrently because merge (join) is commutative, associative, and idempotent — the result is independent of the order in which writes arrive.

This is exactly the insight that Kuper and Newton exploited in LVars: by restricting writes to monotonic updates and reads to threshold queries, they guarantee deterministic outcomes in parallel programs. The CALM theorem further connects this to distributed systems: monotonic programs are inherently coordination-free.

For our language design, this means that propagator-based type checking could naturally parallelize: type constraints from different parts of a program can be propagated concurrently, with the lattice structure ensuring a deterministic result.

### 11.3 Connection to the Actor Model

Propagators share architectural similarities with actors — both are autonomous computational agents — but differ in communication pattern. Actors communicate through point-to-point messages; propagators communicate through shared cells. Propagators provide finer-grained coordination: multiple propagators can contribute to the same cell without explicit message routing, and the merge operation ensures consistency.

The cell can be viewed as a *shared mailbox* with a built-in conflict resolution strategy (lattice join), eliminating the need for explicit synchronization protocols that actors typically require.

---

## 12. Incremental and Reactive Computation

### 12.1 Self-Adjusting Computation and Adapton

Self-adjusting computation (Acar, "Self-Adjusting Computation," CMU-CS-05-129, 2005) automatically recomputes results when inputs change, minimizing redundant work. **Adapton** (Hammer et al., "Adapton: Composable, Demand-Driven Incremental Computation," PLDI 2014) refines this with demand-driven semantics: only computations whose results are actually demanded are recomputed.

Adapton's demanded computation graph has structural parallels to propagator networks: nodes represent computations, edges represent dependencies, and changes propagate through the graph. The key difference is directionality: Adapton is demand-driven (pull-based, lazy), while propagators are supply-driven (push-based, eager). A hybrid system could offer both modes.

### 12.2 Differential Dataflow

Differential dataflow (McSherry et al.) efficiently maintains computation results as inputs change by representing data as collections of *differences* rather than absolute values. Built on timely dataflow, it supports iterative computations, joins, aggregations, and complex query patterns with incremental maintenance.

Differential dataflow extends the propagator concept to streams: rather than propagating individual cell values, it propagates *changes* to collections, recomputing only affected portions of the computation. Materialize (a streaming database) and Differential Datalog (DDlog, by VMware) are production implementations of this approach.

### 12.3 Functional Reactive Programming

Functional Reactive Programming (FRP) integrates time-varying values (behaviors) and discrete events into functional programming. Signal values accumulate information over time (analogous to propagator cells), and event propagation through signal networks parallels propagator scheduling.

The connection is architectural rather than identical: FRP typically uses push-based or pull-based evaluation strategies, while propagators use a hybrid approach where cells accumulate information and propagators are triggered by changes.

### 12.4 Spreadsheet Computation

Spreadsheets are perhaps the most widely deployed propagator-like system: cells hold values, formulas propagate information between cells, and the spreadsheet engine re-evaluates affected formulas when inputs change. The key difference is that spreadsheet cells are typically single-valued (overwriting rather than merging), while propagator cells accumulate partial information via lattice join.

A dependently typed spreadsheet — where cell types depend on values in other cells, and type checking propagates through the formula graph — would be a natural application of propagator-based dependent type checking.

---

## 13. Modern Implementations

### 13.1 Constraint Programming Systems

**Gecode** (Generic Constraint Development Environment) is a production-quality constraint solver with propagators as the central computational mechanism. It features a priority-based propagation kernel with sophisticated scheduling, weakly monotonic propagators (the minimal property guaranteeing sound and complete propagation), and a rich library of global propagators (alldifferent, cumulative, circuit, etc.).

**Chuffed** is a lazy clause generation solver combining finite domain propagation with Boolean satisfiability (SAT). All propagators are instrumented for explanation, enabling conflict-driven clause learning (CDCL) at the constraint level — a sophisticated integration of propagation with search.

**MiniZinc** is a solver-independent constraint modeling language that compiles to FlatZinc. Its multi-pass compilation runs propagation during compilation to tighten variable bounds before dispatching to backend solvers (Gecode, Chuffed, OR-Tools, etc.).

**Ciao Prolog** provides a modular CLP(FD) library using attributed variables and propagators as reactive functional rules (indexicals). Its glass-box design allows user-defined constraints at multiple levels.

### 13.2 Language-Specific Libraries

**Haskell: Holmes** (github.com/i-am-tom/holmes) — A reference library implementing propagators with CDCL, featuring monadic interfaces and type-class-based lattice abstraction.

**Haskell: ekmett/propagators** — Edward Kmett's implementation using observable sharing to convert between direct programming style and propagator network representation, leveraging Haskell's type classes for lattice polymorphism.

**Clojure: Propaganda** (github.com/tgk/propaganda) — Implements the Radul-Sussman model with both STM-based and immutable-value approaches, working in both Clojure and ClojureScript.

**Scheme: Original MIT Implementation** — The reference implementation from Radul and Sussman's papers, available at the MIT ProjectMAC repository.

---

## 14. Extensions and Variations

### 14.1 Higher-Order Propagators

Higher-order propagators create new propagators dynamically, enabling meta-level constraint programming and dynamic network construction. Research has shown that generated propagators can achieve generalized arc consistency (GAC) for arbitrary constraints, with performance comparable to hand-optimized implementations. This "propagators creating propagators" pattern is analogous to higher-order functions in functional programming and meta-circular evaluation.

### 14.2 Probabilistic Propagation and Belief Propagation

Belief propagation, first formulated by Judea Pearl (1982), extends propagation concepts to probabilistic inference in graphical models. Nodes exchange real-valued function messages encoding probability distributions; iterative message updates converge to marginal distributions.

Belief propagation is exact on tree-structured graphs and approximate (but often effective) on loopy graphs. Applications include low-density parity-check codes, turbo codes, satisfiability solving, and computer vision. Belief Propagation Neural Networks (BPNN, NeurIPS 2020) learn better fixed-point computations while preserving BP's invariances and equivariances.

The mathematical connection to propagators is precise: both compute fixed points of local update rules on graphical structures, with convergence guaranteed by monotonicity properties (or approximate convergence in the loopy/non-monotone case).

### 14.3 Factor Graphs and Message Passing

Factor graphs are bipartite graphical models where variable nodes represent random variables and factor nodes represent local functions. The sum-product algorithm computes all marginals efficiently through message passing along edges — a direct instance of propagation.

The factored structure enables exponential speedups: rather than summing over all variable combinations, the sum-product algorithm decomposes computation into local operations. This factorization principle is analogous to how propagator networks decompose global constraint satisfaction into local propagation steps.

### 14.4 SMT Solvers and Theory Propagation

SMT (Satisfiability Modulo Theories) solvers integrate propagation with SAT solving through the DPLL(T) architecture. Theory solvers act as specialized propagators that communicate entailed literals to the SAT engine.

Modern SMT solvers (Z3, CVC5) support **user-defined propagators** through frameworks like "Satisfiability Modulo User Propagators" (Eisenhofer et al., JAIR), allowing custom first-order theories to be integrated into the solving process. Theory propagation can be exhaustive (all entailed literals propagated) or partial (only deduced literals during feasibility checking), trading off solver power against computational cost.

### 14.5 Message Passing Neural Networks

Message Passing Neural Networks (MPNNs) apply propagation concepts to deep learning on graph-structured data. Nodes compute messages from neighbors, aggregate them via permutation-invariant operations, and update their state — iterating for a fixed number of rounds. This architecture achieves state-of-the-art results on molecular property prediction, physical simulation, and network analysis.

The structural parallel to propagators is clear: nodes are cells, message computation is propagation, and aggregation is merge. The key difference is that MPNN message functions are learned (neural networks) rather than hand-specified, and the number of iterations is fixed rather than running to convergence.

---

## 15. Connections to Our Language Design

### 15.1 Propagators for Type Inference and Elaboration

Type inference in a dependently typed language is fundamentally a constraint propagation problem. Type variables are cells holding partial type information; typing rules are propagators that derive new type information from existing information; the principal type is the least fixed point of the constraint system.

For our language, a propagator-based elaborator would:

1. **Create cells** for each metavariable (unknown type, unknown term, unknown universe level).
2. **Create propagators** for each typing constraint (from function applications, pattern matches, annotations, etc.).
3. **Run the network** to quiescence, resolving as many metavariables as possible.
4. **Report errors** as unresolvable contradictions (type mismatches) or unsolved cells (ambiguous types needing annotation).

This architecture naturally supports the bidirectional, incremental, and partial nature of dependent type elaboration. It also opens the door to parallel type checking, since the lattice structure ensures determinism.

### 15.2 Session Type Verification as Propagation

Session type checking can be modeled as propagation on a lattice of protocol states. Each communication channel has a cell holding the current protocol state; each send/receive operation is a propagator that advances the state; protocol completion corresponds to reaching the `End` state.

The lattice ordering on protocol states is:

- **Bottom**: No protocol information (channel not yet constrained)
- **Interior**: Specific protocol state (e.g., "must send Int, then receive String")
- **Top**: Protocol violation (incompatible operations on the channel)

Duality checking (verifying that two endpoints have dual session types) becomes a propagation problem: constraints from both endpoints propagate through the session type lattice, and a contradiction indicates a protocol mismatch.

Dependent session types — where the protocol depends on communicated values — naturally fit this model: the type of subsequent messages depends on the value received, and this dependency propagates through the type lattice as values become known.

### 15.3 Linear Types and Resource Tracking

Linear types track resource usage — each linear resource must be used exactly once. This can be modeled as propagation on a lattice of usage multiplicities:

- **Bottom**: Resource not yet accounted for
- **1**: Resource used exactly once (valid)
- **ω**: Resource used unrestrictedly (valid for unrestricted bindings)
- **Top**: Resource used incorrectly (e.g., used twice when linear)

In Quantitative Type Theory (QTT), which our language is planned to use, multiplicities form a semiring. The propagator model can track multiplicities through the program: each variable binding creates a cell with a multiplicity, each use site is a propagator that decrements the multiplicity, and the final state must be consistent with the declared multiplicity.

### 15.4 Propagators as a Runtime Model

Beyond type checking, propagators offer a compelling *runtime* model for a language with dependent types and session types:

**Constraint-based computation**: Programs can express constraints declaratively, with the runtime solving them via propagation. This is especially natural for protocol negotiation, where parties exchange capabilities and the system determines a compatible protocol.

**Incremental recomputation**: When program inputs change, propagator networks recompute only affected cells — a natural fit for interactive development, live coding, and reactive systems.

**Concurrent execution**: The lattice-based determinism of propagator networks provides a safe foundation for parallel execution without locks, races, or nondeterminism.

### 15.5 Synthesis: Toward a Propagator-Aware Dependent Type System

The research surveyed in this report suggests a unified vision for our language:

**Type-level propagators**: The type checking and elaboration engine is itself a propagator network. Metavariables are cells; typing rules, unification constraints, and multiplicity constraints are propagators; the elaborated program is the fixed point.

**Term-level propagators**: Programs can construct and run propagator networks as first-class values. Cells are typed using dependent types (encoding their lattice structure), and propagators are typed using linear types (ensuring proper resource management) and session types (encoding their communication protocol with cells).

**Lattice types**: The language provides first-class lattice types with verified join operations, enabling users to define custom partial information domains. The type system verifies monotonicity of propagator functions and well-foundedness of lattice hierarchies.

**Convergence guarantees**: The type system ensures that user-defined propagator networks converge — either by verifying finite lattice height or by requiring widening operators for infinite lattices.

This synthesis positions propagators not as an external implementation detail, but as a first-class computational paradigm integrated into the language's type theory, runtime model, and tooling.

---

## 16. References and Key Literature

### Foundational Propagator Work

- Radul, A. and Sussman, G.J. (2009). "The Art of the Propagator." MIT-CSAIL-TR-2009-002.
- Radul, A. (2009). *Propagation Networks: A Flexible and Expressive Substrate for Computation*. PhD dissertation, MIT.
- Sussman, G.J. and Radul, A. (2011). "Revised Report on the Propagator Model." MIT.

### Historical Antecedents

- Stallman, R.M. and Sussman, G.J. (1977). "Forward Reasoning and Dependency-Directed Backtracking in a System for Computer-Aided Circuit Analysis." *Artificial Intelligence*, 9, 135–196.
- Steele, G.L. Jr. and Sussman, G.J. (1980). "CONSTRAINTS: A Language for Expressing Almost-Hierarchical Descriptions." *AI Journal*.
- de Kleer, J. and Sussman, G.J. (1978). "Propagation of Constraints Applied to Circuit Synthesis." MIT AI Lab TR-AIM-485.

### Truth Maintenance Systems

- Doyle, J. (1979). "A Truth Maintenance System." *Artificial Intelligence*, 12, 231–272.
- de Kleer, J. (1986). "An Assumption-Based Truth Maintenance System." *Artificial Intelligence*, 28, 127–162.

### Lattice Theory and Fixed Points

- Tarski, A. (1955). "A Lattice-Theoretical Fixpoint Theorem and Its Applications." *Pacific Journal of Mathematics*, 5(2), 285–309.
- Kleene, S.C. (1952). *Introduction to Metamathematics*. North-Holland.
- Scott, D.S. (1970). "Outline of a Mathematical Theory of Computation." Oxford University Computing Laboratory, Technical Monograph PRG-2.

### Abstract Interpretation

- Cousot, P. and Cousot, R. (1977). "Abstract Interpretation: A Unified Lattice Model for Static Analysis of Programs by Construction or Approximation of Fixpoints." POPL 1977.
- Cousot, P. and Cousot, R. (1992). "Comparing the Galois Connection and Widening/Narrowing Approaches to Abstract Interpretation." PLILP 1992, LNCS 631.

### CRDTs and Distributed Monotonic Computation

- Shapiro, M., Preguiça, N., Baquero, C., and Zawirski, M. (2011). "Conflict-Free Replicated Data Types." INRIA RR-7687.
- Kuper, L. and Newton, R.N. (2013). "LVars: Lattice-Based Data Structures for Deterministic Parallelism." FHPC 2013.
- Kuper, L., Turon, A., Krishnaswami, N., and Newton, R.N. (2014). "Freeze After Writing: Quasi-Deterministic Parallel Programming with LVars." POPL 2014.
- Conway, N., Marczak, W., Alvaro, P., Hellerstein, J.M., and Maier, D. (2012). "Logic and Lattices for Distributed Programming." SOCC 2012.
- Hellerstein, J.M. and Alvaro, P. (2019). "Keeping CALM: When Distributed Consistency is Easy." *Communications of the ACM*.

### Datalog and Monotone Fixed-Point Languages

- Olhoták, O. and Estrada, M. (2016). "From Datalog to Flix: A Declarative Language for Fixed Points on Lattices." PLDI 2016.
- Arntzenius, M. and Krishnaswami, N. (2016). "Datafun: A Functional Datalog." ICFP 2016.
- Krishnaswami, N. and Arntzenius, M. (2020). "Seminaïve Evaluation for a Higher-Order Functional Language." POPL 2020.

### Constraint Handling Rules

- Frühwirth, T. (2009). *Constraint Handling Rules*. Cambridge University Press.

### Constraint Programming Systems

- Schulte, C. and Stuckey, P.J. (2008). "Efficient Constraint Propagation Engines." *ACM Transactions on Programming Languages and Systems*, 31(1).
- Tack, G. (2009). *Constraint Propagation: Models, Techniques, Implementation*. PhD thesis.

### Type Systems and Bidirectional Checking

- Dunfield, J. and Krishnaswami, N. (2014). "Complete and Easy Bidirectional Typechecking for Higher-Rank Polymorphism." ICFP 2014.
- Pottier, F. and Rémy, D. (2005). "The Essence of ML Type Inference." In *Advanced Topics in Types and Programming Languages*, MIT Press.
- Christiansen, D. (2022). "Bidirectional Typing Rules: A Tutorial."

### Dependent Type Elaboration

- de Moura, L. and Ullrich, S. (2021). "The Lean 4 Theorem Prover and Programming Language." CADE-28.
- Kovács, A. (2022). "Elaboration Zoo." github.com/AndrasKovacs/elaboration-zoo.
- Gundry, A. (2013). *Type Inference, Haskell, and Dependent Types*. PhD thesis, University of Strathclyde.

### Incremental and Reactive Computation

- Acar, U.A. (2005). *Self-Adjusting Computation*. CMU-CS-05-129.
- Hammer, M., Phipps-Costin, V., Swamy, N., and Foster, J.S. (2014). "Adapton: Composable, Demand-Driven Incremental Computation." PLDI 2014.
- McSherry, F., Murray, D.G., Isaacs, R., and Isard, M. (2013). "Differential Dataflow." CIDR 2013.

### Concurrency Models

- Kahn, G. (1974). "The Semantics of a Simple Language for Parallel Programming." *Information Processing*, 74, 471–475.
- Hewitt, C. (1973). "A Universal Modular ACTOR Formalism for Artificial Intelligence." IJCAI 1973.

### Probabilistic Propagation

- Pearl, J. (1982). "Reverend Bayes on Inference Engines: A Distributed Hierarchical Approach." AAAI 1982.
- Kschischang, F.R., Frey, B.J., and Loeliger, H.-A. (2001). "Factor Graphs and the Sum-Product Algorithm." *IEEE Transactions on Information Theory*, 47(2).

### SMT Solving

- Eisenhofer, C. et al. (2023). "Satisfiability Modulo User Propagators." *Journal of Artificial Intelligence Research*.
- Barrett, C. and Tinelli, C. (2018). "Satisfiability Modulo Theories." In *Handbook of Model Checking*, Springer.

### Propagator Implementations

- Holmes constraint solver: github.com/i-am-tom/holmes
- Propaganda (Clojure): github.com/tgk/propaganda
- Kmett's propagators (Haskell): github.com/ekmett/propagators
- MIT Propagator reference implementation: github.com/ProjectMAC/propagators
- Ascent (Datalog in Rust): github.com/s-arash/ascent

### Session Types and Protocol Verification

- Toninho, B., Caires, L., and Pfenning, F. (2011). "Dependent Session Types via Intuitionistic Linear Type Theory." PPDP 2011.
- Honda, K., Yoshida, N., and Carbone, M. (2008). "Multiparty Asynchronous Session Types." POPL 2008.

---

*This report was compiled as part of a research initiative to inform the design of a new programming language featuring dependent types as first-class citizens, with session types for protocol correctness and linear types for memory-safety guarantees. The propagator model and its lattice-theoretic foundations offer compelling structures for both the type-checking infrastructure and the runtime semantics of such a language.*
