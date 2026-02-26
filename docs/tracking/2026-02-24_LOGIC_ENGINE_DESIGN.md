- [Executive Summary](#org124e7c6)
  - [Infrastructure Gap Analysis](#org29ad66d)
  - [Critical Path](#org6f714c1)
- [Phase 1: Lattice Trait + Standard Instances](#orgaae7395)
  - [1.1 Goal](#orgb385780)
  - [1.2 The `Lattice` Trait](#org652f9fe)
  - [1.3 Standard Lattice Instances](#org11382f3)
    - [1.3.1 `FlatLattice A` — Three-Point Lattice](#org9d5e315)
    - [1.3.2 `SetLattice A` — Powerset Lattice (Set Union)](#org16f309b)
    - [1.3.3 `MapLattice K V` — Pointwise Map Lattice](#org75cad5c)
    - [1.3.4 `IntervalLattice` — Numeric Intervals](#org6e6c4ec)
    - [1.3.5 `BoolLattice` — Two-Point Lattice](#org712fb6a)
  - [1.4 Racket-Level Implementation](#orga37afef)
  - [1.5 `champ-insert-join` — Racket-Level Helper](#org09c6f94)
  - [1.6 New Files](#org9fa6751)
  - [1.7 Tests (~25)](#org2751182)
  - [1.8 Dependencies](#orgbee70cf)
- [Phase 2: Persistent Propagator Network](#orgc5d44ce)
  - [2.1 Goal](#org9e1711f)
  - [2.2 Architecture](#org83ff905)
  - [2.3 Core Data Structures (All Persistent)](#org4c045b5)
    - [2.3.1 Identity Types](#org568b217)
    - [2.3.2 `prop-cell` — Propagator Cell (Immutable)](#orgfbd5322)
    - [2.3.3 `propagator` — Monotone Function (Immutable)](#org6598151)
    - [2.3.4 `prop-network` — The Network as Value](#org1bbdbb8)
  - [2.4 Pure Operations](#org4bee1dd)
  - [2.5 Concrete `fire-fn` Example: Adder Propagator](#orgfe282f9)
  - [2.6 `run-to-quiescence` — Pure Loop](#org062315c)
  - [2.7 Contradiction Handling (Per-Cell `contradicts?` Predicate)](#orgdb1154c)
  - [2.8 LVars Are Subsumed by Cells](#org3a126b3)
  - [2.9 AST Nodes (~12)](#org99b8f86)
  - [2.10 New/Modified Files](#org07545ba)
  - [2.11 Tests (~60)](#org671390d)
  - [2.12 Dependencies](#org33adad2)
- [Phase 2.5: BSP Parallel Execution ✅](#org6520742)
  - [2.5.1 Goal](#orgf7b7ef2)
  - [2.5.2 BSP Scheduler (Jacobi Iteration)](#org121ec1e)
  - [2.5.3 Threshold Propagators](#orgf5f09f3)
  - [2.5.4 Parallel Executor](#org546844c)
  - [2.5.5 Implications for Later Phases](#org5a25bf8)
  - [2.5.6 New Functions](#orgbcfe26d)
  - [2.5.7 Files and Tests](#org4b4a002)
  - [2.5.8 Key Design Decisions](#orgdea9325)
- [Phase 3: PropNetwork as Prologos Type](#orga9e67d2)
  - [3.1 Goal](#orgcf777fe)
  - [3.2 Why a Separate Phase](#orgf575e8f)
  - [3.3 Type Signatures](#orgd04dba6)
  - [3.4 LVar Operations as Library Functions](#org19c173c)
  - [3.5 AST Nodes (12)](#org93ba670)
  - [3.6 New/Modified Files](#org641ddda)
  - [3.7 Tests (~50)](#org16a376d)
  - [3.8 Dependencies](#orgc14bf10)
- [Phase 4: UnionFind — Persistent Disjoint Sets](#org7ff11df)
  - [4.1 Goal](#org193596f)
  - [4.2 Design](#orga14f7dc)
  - [4.3 Key Properties](#org4ccdc13)
  - [4.4 Integration with Logic Engine: UF vs Cell Division of Labor](#org1f08a5e)
  - [4.5 AST Nodes (~6)](#orgbaa7020)
  - [4.6 New/Modified Files](#orgc33c545)
  - [4.7 Tests (~30)](#orgb7fa741)
  - [4.8 Dependencies](#orgd3b77db)
- [Phase 5: Persistent ATMS Layer — Hypothetical Reasoning](#org26e178f)
  - [5.1 Goal](#orgb3b710c)
  - [5.2 Core Data Structures (All Persistent)](#orgf7efe02)
    - [`assumption` — Hypothetical Premise](#org5677a82)
    - [`supported-value` — Value + Justification](#org948654a)
    - [`tms-cell` — Truth-Maintained Cell (Immutable)](#org941292b)
    - [`atms` — The Persistent ATMS](#orgdb7b5ab)
  - [5.3 Pure Operations](#org61f5b56)
  - [5.4 The `amb` Operator (Pure)](#org16fabb3)
  - [5.5 Two-Tier Mode: Lazy ATMS Activation](#org9f7c58c)
  - [5.6 Contradiction Handler (Dependency-Directed Backtracking)](#org0dd5c88)
  - [5.7 Answer Collection (Pure)](#orga129ebe)
  - [5.8 BSP Integration: Parallel Worldview Exploration](#orgc244715)
  - [5.9 AST Nodes (~10)](#org9c5d78d)
  - [5.10 New/Modified Files](#orgfc81bee)
  - [5.11 Tests (~50)](#org9dc490d)
  - [5.12 Dependencies](#org6f854e3)
- [Phase 6: Tabling — SLG-Style Memoization](#org5c2c4f8)
  - [6.1 Goal](#org80fc14d)
  - [6.2 Design (XSB-Style SLG Resolution)](#org99a17d3)
  - [6.3 Table Lifecycle](#org40ce4d8)
  - [6.4 Core Data Structures (Persistent)](#org68d001c)
  - [6.5 Lattice Answer Modes](#org8cbb45a)
  - [6.6 Spec Metadata Integration](#org902500d)
  - [6.7 BSP Integration: Parallel Table Evaluation](#org867ebcf)
  - [6.8 AST Nodes (~8)](#orgad8bd3e)
  - [6.9 New/Modified Files](#orgec43d36)
  - [6.10 Tests (~40)](#org1f490d4)
  - [6.11 Dependencies](#orgf49ba81)
- [Phase 7: Surface Syntax — `schema`, `defr`, `rel`, `solve`, `explain`, `solver`, `&>`, `||`, `|`](#orga255cad)
  - [7.1 Goal](#org34f7386)
  - [7.2 Reader Changes](#org4ce6c81)
  - [7.3 Parser Changes](#orgbe7eae5)
    - [Multi-arity `|` dispatch](#org0e141ec)
    - [`||` fact blocks](#orgbf216c0)
    - [`solve~/~explain` use `(...)` for goals](#org07a32cc)
  - [7.4 Elaboration](#orgb2a761f)
    - [7.4.1 `defr` Elaboration](#org87360c2)
    - [7.4.2 `solve` Elaboration (Functional-Relational Bridge)](#org781b1a7)
    - [7.4.3 `solve-with` Elaboration (Map Merge Override)](#org60404e7)
    - [7.4.4 `explain` Elaboration (Provenance-Bearing Bridge)](#org9c3e1ac)
  - [7.5 Grammar Updates](#orgeb58176)
  - [7.6 Solver, Solve, and Explain — Unified Design](#org53a33bd)
    - [7.6.1 Design Overview](#org487e68f)
    - [7.6.2 The `solver` Top-Level Form](#org2925b22)
    - [7.6.3 The `Answer` Type](#orge021d27)
    - [7.6.4 Dispatch: `solve` / `explain` and `default-solver`](#org5dcc7cc)
    - [7.6.5 Map Merge Overrides with `{...}`](#org3571fb9)
    - [7.6.6 `default-solver` Shadowing](#orgd2ce54e)
    - [7.6.7 `solver` Elaboration](#orga8b1a34)
    - [7.6.8 Default-Parallel Tradeoffs](#orgd94c86b)
  - [7.7 Compile-Time Stratification Check](#orgd079b74)
  - [7.8 AST Nodes (~26)](#orgf2758f8)
    - [Relational Core (~14)](#orgcccf6e4)
    - [Solve Family (~4)](#orgd413d68)
    - [Explain Family (~2)](#orgb07e64a)
    - [Solver Config (~2)](#org8a2fee2)
    - [Answer + Provenance Types (~2)](#orgca62489)
    - [Control (~2)](#org914bcff)
  - [7.9 New/Modified Files](#org4e3f23c)
  - [7.10 Tests (~110)](#orge02c100)
    - [Relations and Goals (~20)](#org9b63e3e)
    - [Solve Family (~15)](#org5ea3769)
    - [Explain Family (~20)](#orgbcec60c)
    - [Solver Config (~15)](#orgf252428)
    - [Stratification (~5)](#org83c4073)
  - [7.11 Dependencies](#orgf27b500)
- [Phase Summary](#org386a244)
- [Interaction with Existing Infrastructure](#org95d5a07)
  - [Metavar System](#org27dca65)
  - [Trait System](#org63ef183)
  - [Spec Metadata](#org1becdd8)
  - [Warnings](#org5610ad7)
  - [QTT / Multiplicities](#org7e88606)
  - [Collections](#org10fd3c5)
- [Appendix A: Resolution by Example — `ancestor` as Propagators](#org87d675f)
  - [A.1 Source Program](#orgb2ba45e)
  - [A.2 Step 1: Table Creation](#org5b63781)
  - [A.3 Step 2: Clause 1 → Producer Propagator](#org567fbb3)
  - [A.4 Step 3: Clause 2 → Producer Propagator](#org17ee63d)
  - [A.5 Step 4: Run to Quiescence](#orgb05ed58)
  - [A.6 Step 5: Answer Extraction](#orga4498e0)
- [Appendix B: End-to-End Query Walkthrough (All Three Layers)](#orgffbd5a2)
  - [B.1 Source Program](#orgc9790cc)
  - [B.2 Compile-Time: Stratification Check](#orge7b5651)
  - [B.3 Runtime: Layer 1 — PropNetwork (Stratum 0)](#org8378108)
  - [B.4 Runtime: Layer 3 — Stratum Boundary](#org09efae6)
  - [B.5 Runtime: Layer 2 — ATMS (if needed)](#orge5091de)
  - [B.6 Summary: Which Layer Handles What](#org232af21)
- [Performance Expectations](#org3d38bc9)
  - [Cost Model](#org8432cca)
  - [Benchmark Targets (to validate during implementation)](#orgcca3680)
  - [When Performance Matters Most](#orgb525003)
- [What This Design Does NOT Cover](#org8f922c4)
  - [Elaborator Refactoring (Phase 1 of Research Doc)](#org583eba7)
  - [Galois Connections / Domain Embeddings (Phase 6 of Research Doc)](#org444bd3e)
  - [Full Stratified Evaluation Runtime (Phase 4 of Research Doc)](#org62b069c)
  - [CRDTs / Distributed Logic](#orgcffa97b)
  - [QuickCheck / Property Testing](#orgfea50ae)
- [Architectural Decision: Persistent Networks](#org2297b9a)
  - [The Problem with Mutable Propagator Networks](#org3adb2ff)
  - [The Persistent Solution](#org8a34dde)
  - [LVar Elimination](#orge2e673c)
- [Key Lessons from Prior Work](#org7fdffc0)
- [References](#orgd04e4cf)
  - [Phase 1 (Lattice)](#org1c4eabd)
  - [Phase 2 (Propagators)](#org183b14d)
  - [Phase 3 (LVars)](#orga01deb5)
  - [Phase 4 (UnionFind)](#org83feb69)
  - [Phase 5 (ATMS)](#org5c37e4b)
  - [Phase 6 (Tabling)](#org08bcd06)
  - [Phase 7 (Surface)](#orga1de54e)



<a id="org124e7c6"></a>

# Executive Summary

This document is the implementation guide for Prologos's logic engine — the substrate on which the relational language (`defr`, `rel`, `solve`) will run. It follows the research-design-implementation methodology that produced the Extended Spec Design (<2026-02-22_EXTENDED_SPEC_DESIGN.md>).

The design is grounded in two research documents:

-   [Towards a General Logic Engine on Propagators](2026-02-24_TOWARDS_A_GENERAL_LOGIC_ENGINE_ON_PROPAGATORS.md) — three-layer architecture
-   [Implementation Guide: Core Data Structures](../research/IMPLEMENTATION_GUIDE_CORE_DS_PROLOGOS.md) — Section 8 (lattice integration)

And the relational language vision:

-   [Relational Language Vision](principles/RELATIONAL_LANGUAGE_VISION.md) — surface syntax decisions

The engine is built bottom-up in 8 phases:

1.  **Lattice Trait + champ-insert-join** — the algebraic foundation ✅
2.  **Persistent PropNetwork** (Racket-level) — the monotonic data plane as value ✅

2.5. **BSP Parallel Execution** — Jacobi scheduler, threshold propagators, parallel executor ✅

1.  **PropNetwork as Prologos Type** — expose network ops to the type system ✅
2.  **UnionFind** — persistent disjoint sets for unification
3.  **Persistent ATMS** — hypothetical reasoning as value
4.  **Tabling** — SLG-style memoization for completeness
5.  **Surface Syntax** — `schema`, `defr`, `rel`, `solve`, `explain`, `solver`, `&>`, `||`, `|`

Key architectural decision: the entire propagator network and ATMS are **persistent/immutable values** backed by CHAMP maps. Backtracking = keep old reference (O(1)). Snapshots = free. Network mobility = serialize value. LVars are subsumed by PropNetwork cells (join-on-write semantics).

Phases 1-4 are infrastructure with no surface syntax changes. Phase 5-6 add runtime logic capabilities. Phase 7 adds the user-facing language.


<a id="org29ad66d"></a>

## Infrastructure Gap Analysis

| Component                 | Status           | What Exists                                    | What's Needed                                   |
|------------------------- |---------------- |---------------------------------------------- |----------------------------------------------- |
| Persistent collections    | COMPLETE         | PVec, Map, Set, List, LSeq                     | —                                               |
| CHAMP lattice helper      | COMPLETE         | `champ-insert-join` in champ.rkt               | —                                               |
| Transient builders        | COMPLETE         | TVec, TMap, TSet, with-transient               | —                                               |
| Trait system              | COMPLETE         | Registry, resolution, bundles                  | Lattice trait + instances                       |
| Property system           | Phase 1 COMPLETE | Storage, flattening, accessors                 | QuickCheck for :holds (Phase 2+)                |
| Spec metadata             | Phase 1 COMPLETE | :examples, :deprecated, :doc                   | :tabled, :answer-mode, :strategy                |
| Metavar system            | COMPLETE         | 4 parallel stores, constraints                 | Refactor to propagator cells (later)            |
| Lattice trait             | COMPLETE         | Lattice + HasTop traits, BoundedLattice bundle | 5 instances (FlatVal, Bool, Interval, Set, Map) |
| BSP parallel execution    | COMPLETE         | BSP scheduler, threshold props, parallel exec  | ~18 tests, Jacobi iteration                     |
| Persistent PropNetwork    | COMPLETE         | Immutable network, pure ops, CHAMP             | 55 tests, 9 core operations                     |
| PropNetwork Prologos type | COMPLETE         | 14 AST nodes, full pipeline                    | 56 tests, library wrappers                      |
| UnionFind                 | NOT STARTED      | —                                              | Persistent disjoint sets                        |
| Persistent ATMS           | NOT STARTED      | —                                              | Immutable ATMS, worldview switching             |
| Tabling                   | NOT STARTED      | —                                              | Producer/consumer, table cells                  |
| Stratification            | NOT STARTED      | —                                              | SCC decomposition, stratum evaluation           |
| Logic syntax              | NOT STARTED      | —                                              | defr, rel, solve, &>, ?var                      |


<a id="org6f714c1"></a>

## Critical Path

```
Phase 1 (Lattice + champ-insert-join)                          ✅
  ↓
Phase 2 (Persistent PropNetwork, Racket-level)                 ✅
  ↓
Phase 2.5 (BSP Parallel Execution)                             ✅
  ↓
Phase 3 (PropNetwork as Prologos Type)                         ✅
  ↓                    ↓
Phase 4 (UnionFind) ←─ can proceed in parallel with Phase 5
  ↓                    ↓
Phase 5 (Persistent ATMS) ←── depends on Phase 3
  ↓       uses BSP scheduler for parallel worldview exploration
Phase 6 (Tabling) ←── depends on Phase 3, Phase 5
  ↓       table producers/consumers are BSP-compatible propagators
Phase 7 (Surface Syntax) ←── depends on ALL previous phases
          solver keyword, default-parallel via BSP
```


<a id="orgaae7395"></a>

# Phase 1: Lattice Trait + Standard Instances


<a id="orgb385780"></a>

## 1.1 Goal

Establish the `Lattice` trait — the algebraic foundation for monotonic computation. Every propagator cell, LVar, and ATMS label set requires a lattice domain. By defining `Lattice` as a standard Prologos trait, we get automatic dictionary resolution at both compile-time and runtime.


<a id="org652f9fe"></a>

## 1.2 The `Lattice` Trait

```prologos
;; in lib/prologos/core/lattice.prologos
(ns prologos::core::lattice :no-prelude)

trait Lattice {A : Type}
  bot  : A                     ;; bottom element (no information)
  join : A -> A -> A           ;; least upper bound (merge information)
  leq  : A -> A -> Bool        ;; lattice ordering

;; Laws (to be checked via property testing in Phase 2+):
;;   join is commutative:  join a b = join b a
;;   join is associative:  join (join a b) c = join a (join b c)
;;   join is idempotent:   join a a = a
;;   bot is identity:      join bot a = a
;;   leq is consistent:    leq a b = (join a b == b)
```


<a id="org11382f3"></a>

## 1.3 Standard Lattice Instances


<a id="org9d5e315"></a>

### 1.3.1 `FlatLattice A` — Three-Point Lattice

The simplest useful lattice: bottom → exactly one value → top (contradiction). Used for basic unification cells where a variable is either unknown, bound to exactly one value, or in conflict.

```prologos
;; in lib/prologos/core/lattice-instances.prologos

;; FlatLattice wraps any Eq type into a flat lattice
;; ⊥ → value → ⊤
functor FlatLattice {A : Type}
  :where (Eq A)
  :unfolds <(Option [Either A Unit])>
  ;; none = ⊥, some (left v) = value, some (right unit) = ⊤

instance Lattice [FlatLattice A] where (Eq A)
  bot  = none
  join = flat-join
  leq  = flat-leq

defn flat-join [a b]
  match [a b]
    | [none _]                     -> b
    | [_ none]                     -> a
    | [[some [left v1]] [some [left v2]]]
      -> if [eq? v1 v2] a [some [right unit]]
    | _                            -> [some [right unit]]
```


<a id="org16f309b"></a>

### 1.3.2 `SetLattice A` — Powerset Lattice (Set Union)

Growing sets: elements can only be added, never removed. Join = union. Used for Herbrand interpretations (sets of ground facts) and LVar-Sets.

```prologos
;; SetLattice: growing sets with union as join
functor SetLattice {A : Type}
  :unfolds [Set A]

instance Lattice [SetLattice A]
  bot  = #{}
  join = set-union
  leq  = set-subset?
```


<a id="org75cad5c"></a>

### 1.3.3 `MapLattice K V` — Pointwise Map Lattice

Maps where each key has an independent lattice-valued value. Join = pointwise join of values. Used for LVar-Maps and substitution stores.

```prologos
;; MapLattice: pointwise lattice on maps
functor MapLattice {K V : Type}
  :where (Lattice V)
  :unfolds [Map K V]

instance Lattice [MapLattice K V] where (Lattice V)
  bot  = {}
  join = map-lattice-join
  leq  = map-lattice-leq

defn map-lattice-join [m1 m2]
  ;; For keys in both: join values. For keys in one: include.
  [merge-with join m1 m2]
```


<a id="org6e6c4ec"></a>

### 1.3.4 `IntervalLattice` — Numeric Intervals

Intervals `[lo, hi]` with intersection as meet, hull as join. Used for numeric constraint propagation (CLP(R/FD)).

```prologos
;; IntervalLattice for numeric constraints
deftype Interval
  mk-interval : Rat -> Rat -> Interval    ;; lo, hi (lo <= hi)
  ;; Special: bot = (-∞, +∞) = unconstrained
  ;; Special: top = empty = contradicted

instance Lattice Interval
  bot  = interval-unconstrained
  join = interval-intersect    ;; narrowing: more constrained = higher
  leq  = interval-subsumes?   ;; [a,b] ⊑ [c,d] iff [c,d] ⊆ [a,b]
```


<a id="org712fb6a"></a>

### 1.3.5 `BoolLattice` — Two-Point Lattice

The simplest non-trivial lattice: false < true. Join = OR. Used as building block and for boolean constraint propagation.

```prologos
instance Lattice Bool
  bot  = false
  join = bool-or
  leq  = bool-implies?
```


<a id="orga37afef"></a>

## 1.4 Racket-Level Implementation

At the Racket level, lattice operations are dispatched via the existing trait system. The `Lattice` trait follows the standard pattern:

| Component       | How                                                    |
|--------------- |------------------------------------------------------ |
| Trait struct    | `trait-meta` in `current-trait-registry`               |
| Instances       | `(impl-entry 'Lattice ...)` in `current-impl-registry` |
| Dictionary type | Sigma type: `(bot . (join . leq))` (3 methods)         |
| Resolution      | Standard `resolve-trait-constraints!` pipeline         |

No new AST nodes needed for Phase 1. The trait and instance declarations use existing infrastructure.


<a id="org09c6f94"></a>

## 1.5 `champ-insert-join` — Racket-Level Helper

A lattice-aware CHAMP insert that joins on collision, rather than replacing. This is the foundational Racket-level helper that enables the PropNetwork's cells map to do lattice merge natively.

```racket
;; In racket/prologos/champ.rkt (already implemented)

;; champ-insert-join : champ-root hash key val (val val → val) → champ-root
(define (champ-insert-join root hash key val join-fn)
  (let ([existing (champ-lookup root hash key)])
    (if (eq? existing 'none)
        (champ-insert root hash key val)
        (champ-insert root hash key (join-fn existing val)))))
```

This enables the propagator network to store cell values in a CHAMP map with join-on-write semantics: writing to a cell computes `merge-fn(old-value, new-value)` and inserts the result.


<a id="org9fa6751"></a>

## 1.6 New Files

| File                                           | Purpose                      |
|---------------------------------------------- |---------------------------- |
| `lib/prologos/core/lattice.prologos`           | `Lattice` trait declaration  |
| `lib/prologos/core/lattice-instances.prologos` | Standard instances           |
| `tests/test-lattice.rkt`                       | Trait resolution + law tests |


<a id="org2751182"></a>

## 1.7 Tests (~25)

-   Lattice trait registered correctly
-   FlatLattice: bot is identity, join of same values, join of different → top
-   SetLattice: bot = empty, join = union, leq = subset
-   MapLattice: pointwise join, partial maps merge correctly
-   BoolLattice: basic operations
-   Trait resolution: `(Lattice [FlatLattice Nat])` resolves correctly
-   Laws: commutativity, associativity, idempotency of join (6 tests per instance)


<a id="orgbee70cf"></a>

## 1.8 Dependencies

-   Existing trait system (`process-trait`, `process-impl`)
-   Existing collection types (`Set`, `Map` for SetLattice, MapLattice)
-   `Eq` trait (for `FlatLattice`)
-   `champ-insert-join` in `champ.rkt` (already implemented)
-   **No new AST nodes**
-   **No changes to typing-core.rkt**

&#x2014;


<a id="orgc5d44ce"></a>

# Phase 2: Persistent Propagator Network


<a id="org9e1711f"></a>

## 2.1 Goal

Implement the monotonic data plane as a **persistent, immutable value**. The entire propagator network — cells, propagators, worklist, and metadata — is a single Racket struct backed by CHAMP maps. All operations are pure functions: they take a network and return a new network.

This is a critical design choice: the propagator network is a **first-class value** that can be snapshotted (free), backtracked (O(1) — keep old reference), migrated (serialize and send), and compared (structural equality).


<a id="org83ff905"></a>

## 2.2 Architecture

```
┌───────────────────────────────────────┐
│  prop-network (persistent value)      │
│                                       │
│  cells : champ-root (cell-id → cell)  │
│  propagators : champ-root (prop-id)   │
│  worklist : list of prop-id           │
│  merge-fns : champ-root (cell-id → fn)│
│  fuel : Nat                           │
│  contradiction : #f | cell-id         │
│  next-cell-id : Nat                   │
│  next-prop-id : Nat                   │
│                                       │
│  All operations return NEW networks:  │
│  net-new-cell   : Net → ... → (Net,Id)│
│  net-cell-write : Net → Id → V → Net  │
│  run-to-quiescence : Net → Net        │
└───────────────────────────────────────┘
```

Backtracking model:

```
let net0 = (make-prop-network)
let net1 = (net-cell-write net0 cell-a 42)
let net2 = (net-cell-write net1 cell-b 99)

;; Backtrack to net1: simply use the old reference
;; net0 and net1 are unchanged — structural sharing via CHAMP
```


<a id="org4c045b5"></a>

## 2.3 Core Data Structures (All Persistent)


<a id="org568b217"></a>

### 2.3.1 Identity Types

```racket
;; In racket/prologos/propagator.rkt

;; Deterministic counters (no gensym — no global state)
(struct cell-id (n) #:transparent)
(struct prop-id (n) #:transparent)
```

Cell and propagator identities are monotonic counters *inside* the network. This makes networks deterministic (no gensym side effects) and serializable.


<a id="orgfbd5322"></a>

### 2.3.2 `prop-cell` — Propagator Cell (Immutable)

```racket
(struct prop-cell
  (value        ;; Expr — current lattice value (starts at bot)
   dependents)  ;; champ-root (set of prop-id → #t)
  #:transparent)
```

Note: no `id` field in the cell struct itself — the identity is the key in the network's cells map. No `domain` field — the merge function is stored in the network's `merge-fns` map, keyed by cell-id.


<a id="org6598151"></a>

### 2.3.3 `propagator` — Monotone Function (Immutable)

```racket
(struct propagator
  (inputs      ;; list of cell-id
   outputs     ;; list of cell-id
   fire-fn)    ;; (prop-network → prop-network) — pure state transformer
  #:transparent)
```

The `fire-fn` is a **pure function** from network to network. It reads input cells from the network, computes new values, and returns a network with updated output cells. No side effects.


<a id="org1bbdbb8"></a>

### 2.3.4 `prop-network` — The Network as Value

```racket
(struct prop-network
  (cells            ;; champ-root : cell-id → prop-cell
   propagators      ;; champ-root : prop-id → propagator
   worklist         ;; list of prop-id (ephemeral; empty at quiescence)
   next-cell-id     ;; Nat — monotonic counter for cell ids
   next-prop-id     ;; Nat — monotonic counter for propagator ids
   fuel             ;; Nat — step limit to prevent runaway
   contradiction    ;; #f | cell-id — first contradiction encountered
   merge-fns        ;; champ-root : cell-id → (Expr Expr → Expr)
   contradiction-fns) ;; champ-root : cell-id → (Expr → Bool), optional
  #:transparent)
```

Key design choices:

-   **CellId = Nat counter**: deterministic, no gensym, serializable
-   **merge-fns** stored per-cell: captures the lattice's `join` at cell creation
-   **contradiction-fns** stored per-cell: optional predicate that detects if a cell value represents contradiction (`top`). This avoids requiring a `top?` method in the `Lattice` trait or introducing a `BoundedLattice` sub-trait (Prologos has **no trait hierarchies** — see DESIGN<sub>PRINCIPLES.org</sub>). Instead, contradiction detection is a per-cell concern supplied at cell creation time.
-   **worklist** is a plain Racket list: ephemeral within `run-to-quiescence`, always empty in saved snapshots (quiescent networks have empty worklists)
-   **All CHAMP-backed**: O(log₃₂ n) ≈ O(C) where C ≤ 7 for practical n


<a id="org4bee1dd"></a>

## 2.4 Pure Operations

All operations take a network and return a new network. The old network is never modified.

```racket
;; Create empty network
(define (make-prop-network [fuel 1000000])
  (prop-network champ-empty    ;; cells
                champ-empty    ;; propagators
                '()            ;; worklist
                0              ;; next-cell-id
                0              ;; next-prop-id
                fuel           ;; fuel
                #f             ;; no contradiction
                champ-empty    ;; merge-fns
                champ-empty))  ;; contradiction-fns

;; Add a new cell: returns (values new-network cell-id)
;; contradicts? is optional (#f = no contradiction detection at this cell)
(define (net-new-cell net initial-value merge-fn [contradicts? #f])
  (define id (cell-id (prop-network-next-cell-id net)))
  (define cell (prop-cell initial-value champ-empty))
  (define net*
    (struct-copy prop-network net
      [cells (champ-insert (prop-network-cells net)
                            (equal-hash-code id) id cell)]
      [merge-fns (champ-insert (prop-network-merge-fns net)
                                (equal-hash-code id) id merge-fn)]
      [next-cell-id (+ 1 (prop-network-next-cell-id net))]))
  (values
   (if contradicts?
       (struct-copy prop-network net*
         [contradiction-fns
          (champ-insert (prop-network-contradiction-fns net*)
                        (equal-hash-code id) id contradicts?)])
       net*)
   id))

;; Read a cell's value
(define (net-cell-read net cid)
  (define cell (champ-lookup (prop-network-cells net)
                              (equal-hash-code cid) cid))
  (if (eq? cell 'none)
      (error 'net-cell-read "unknown cell: ~a" cid)
      (prop-cell-value cell)))

;; Write a cell: computes merge-fn(old, new), enqueues dependents if changed
(define (net-cell-write net cid new-val)
  (define cells (prop-network-cells net))
  (define cell (champ-lookup cells (equal-hash-code cid) cid))
  (when (eq? cell 'none)
    (error 'net-cell-write "unknown cell: ~a" cid))
  (define merge-fn (champ-lookup (prop-network-merge-fns net)
                                  (equal-hash-code cid) cid))
  (define old-val (prop-cell-value cell))
  (define merged (merge-fn old-val new-val))
  (if (equal? merged old-val)
      net  ;; No change — return same network
      (let* ([new-cell (struct-copy prop-cell cell [value merged])]
             [new-cells (champ-insert cells (equal-hash-code cid) cid new-cell)]
             ;; Enqueue dependents
             [deps (champ-keys (prop-cell-dependents cell))]
             [new-wl (append deps (prop-network-worklist net))])
        (struct-copy prop-network net
          [cells new-cells]
          [worklist new-wl]))))

;; Add a propagator: returns (values new-network prop-id)
(define (net-add-propagator net input-ids output-ids fire-fn)
  (define pid (prop-id (prop-network-next-prop-id net)))
  (define prop (propagator input-ids output-ids fire-fn))
  ;; Register pid as dependent of each input cell
  (define new-cells
    (for/fold ([cells (prop-network-cells net)])
              ([cid (in-list input-ids)])
      (define cell (champ-lookup cells (equal-hash-code cid) cid))
      (if (eq? cell 'none) cells
          (let ([new-deps (champ-insert (prop-cell-dependents cell)
                                         (equal-hash-code pid) pid #t)])
            (champ-insert cells (equal-hash-code cid) cid
                          (struct-copy prop-cell cell [dependents new-deps]))))))
  (values
   (struct-copy prop-network net
     [cells new-cells]
     [propagators (champ-insert (prop-network-propagators net)
                                 (equal-hash-code pid) pid prop)]
     [next-prop-id (+ 1 (prop-network-next-prop-id net))]
     ;; Schedule initial firing
     [worklist (cons pid (prop-network-worklist net))])
   pid))
```


<a id="orgfe282f9"></a>

## 2.5 Concrete `fire-fn` Example: Adder Propagator

To ground the abstract `fire-fn` concept, here is a concrete example: a propagator that adds two cells and writes the result to a third.

```racket
;; adder-fire-fn : cell-id cell-id cell-id → (prop-network → prop-network)
;; Reads cells A and B, writes A+B to cell C
(define (make-adder-fire-fn a-id b-id c-id)
  (lambda (net)
    (define a-val (net-cell-read net a-id))
    (define b-val (net-cell-read net b-id))
    ;; Only propagate if both inputs are known (not bot)
    (if (and (not (eq? a-val 'bot)) (not (eq? b-val 'bot)))
        (net-cell-write net c-id (+ a-val b-val))
        net)))  ;; No change — return same network

;; Usage: wire up an adder network
(define net0 (make-prop-network))
(define-values (net1 cell-a) (net-new-cell net0 'bot flat-join))
(define-values (net2 cell-b) (net-new-cell net1 'bot flat-join))
(define-values (net3 cell-c) (net-new-cell net2 'bot flat-join))
(define-values (net4 adder-pid)
  (net-add-propagator net3
    (list cell-a cell-b)   ;; inputs
    (list cell-c)          ;; outputs
    (make-adder-fire-fn cell-a cell-b cell-c)))

;; Write to inputs, run to quiescence
(define net5 (net-cell-write net4 cell-a 3))
(define net6 (net-cell-write net5 cell-b 4))
(define net7 (run-to-quiescence net6))
(net-cell-read net7 cell-c) ;; → 7
```

Key observations:

-   The `fire-fn` is a **closure** capturing cell-ids, returning a **pure function** from network to network
-   It reads inputs via `net-cell-read` (from the network argument, not side effects)
-   It writes via `net-cell-write` (returns new network, not mutation)
-   If inputs are insufficient (`bot`), it returns the network unchanged (idempotent)
-   The same `fire-fn` works correctly regardless of scheduling order

For the logic engine (Phase 7), a typical `fire-fn` will be a *clause propagator* that attempts unification and writes answer substitutions to a table cell. See Appendix A: Resolution by Example for a worked walkthrough.


<a id="org062315c"></a>

## 2.6 `run-to-quiescence` — Pure Loop

The scheduler is not a separate struct — it is the `worklist` field of the network itself. `run-to-quiescence` is a pure tail-recursive function.

```racket
(define (run-to-quiescence net)
  (cond
    ;; Already contradicted — stop
    [(prop-network-contradiction net) net]
    ;; Fuel exhausted — stop
    [(<= (prop-network-fuel net) 0) net]
    ;; Worklist empty — quiescent (fixed point reached)
    [(null? (prop-network-worklist net)) net]
    ;; Fire next propagator
    [else
     (let* ([pid (car (prop-network-worklist net))]
            [rest (cdr (prop-network-worklist net))]
            [net* (struct-copy prop-network net
                    [worklist rest]
                    [fuel (sub1 (prop-network-fuel net))])]
            [prop (champ-lookup (prop-network-propagators net*)
                                (equal-hash-code pid) pid)])
       (if (eq? prop 'none)
           ;; Propagator removed or unknown — skip
           (run-to-quiescence net*)
           ;; Fire: pure function from network to network
           (run-to-quiescence ((propagator-fire-fn prop) net*))))]))
```

Properties:

-   **Pure**: input is a `prop-network`, output is a `prop-network`
-   **Deterministic**: same inputs → same fixed point (lattice commutativity)
-   **Convergent**: finite-height lattices guarantee termination
-   **Fuel-limited**: prevents runaway; configurable via `fuel` field
-   **Backtrackable**: keep old `net` reference = instant O(1) backtrack


<a id="orgdb1154c"></a>

## 2.7 Contradiction Handling (Per-Cell `contradicts?` Predicate)

Contradiction is detected via a **per-cell predicate**, not a trait method. Each cell may optionally have a `contradicts?` function (supplied at creation time via `net-new-cell`) that checks if a value represents inconsistency.

This design avoids requiring `top?` in the `Lattice` trait (which would force every lattice to define it, even those without a sensible top element) and avoids introducing a `BoundedLattice` sub-trait (Prologos has no trait hierarchies — see DESIGN<sub>PRINCIPLES.org</sub> § "No Trait Hierarchies").

```racket
;; In net-cell-write, after computing merged:
(define (net-cell-write net cid new-val)
  ;; ... (merge as before) ...
  ;; After merge, check for contradiction:
  (define cfn (champ-lookup (prop-network-contradiction-fns net)
                             (equal-hash-code cid) cid))
  (define contradicted?
    (and (not (eq? cfn 'none))   ;; cell has a contradicts? fn
         (cfn merged)))          ;; the merged value is contradictory
  (if contradicted?
      (struct-copy prop-network net* [contradiction cid])
      net*))

;; Example contradiction predicates for standard lattices:
;; FlatLattice: (lambda (v) (and (some? v) (right? (unwrap v))))  ;; some(right(unit)) = top
;; IntervalLattice: (lambda (v) (interval-empty? v))              ;; empty interval = contradicted
;; SetLattice: #f  ;; no contradiction (sets only grow, never contradict)
```

At the pure-network level, contradiction simply records which cell was contradicted. The ATMS layer (Phase 5) interprets this and performs dependency-directed backtracking. Without ATMS, contradiction halts the network.


<a id="org3a126b3"></a>

## 2.8 LVars Are Subsumed by Cells

A key simplification: **LVars are just cells in a persistent network**.

| LVar operation | Network equivalent                             |
|-------------- |---------------------------------------------- |
| `lvar-new`     | `net-new-cell` with appropriate `merge-fn`     |
| `lvar-put`     | `net-cell-write` (already does join-on-write)  |
| `lvar-get`     | `net-cell-read` (synchronous in single-thread) |
| `lvar-freeze`  | Read cell value from a quiescent network       |
| `lvar-set-add` | `net-cell-write` on cell with `SetLattice`     |
| `lvar-map-put` | `net-cell-write` on cell with `MapLattice`     |

This elimination removes the need for a separate LVar module and ~10 dedicated LVar AST nodes. The propagator network *is* the lattice-compatible collection — its cells natively do join-on-write via the `merge-fn`.

Threshold reads: for the synchronous logic engine (not parallel), threshold reads are implemented as propagators that check conditions after quiescence. True blocking threshold reads (for parallel LVar-style programming) are deferred to when actor/place integration is built.


<a id="org99b8f86"></a>

## 2.9 AST Nodes (~12)

New `expr-*` structs in `syntax.rkt`:

| Node                   | Fields               | Semantics                    |
|---------------------- |-------------------- |---------------------------- |
| `expr-prop-network`    | net-value            | Runtime wrapper for network  |
| `expr-cell-id`         | n                    | Cell identity (Nat counter)  |
| `expr-net-new`         | fuel-expr            | Create empty network         |
| `expr-net-new-cell`    | net, init-val, merge | Add cell, return (net, id)   |
| `expr-net-cell-read`   | net, cell-id         | Read cell value              |
| `expr-net-cell-write`  | net, cell-id, val    | Write (merge) value          |
| `expr-net-add-prop`    | net, ins, outs, fn   | Add propagator               |
| `expr-net-run`         | net                  | Run to quiescence            |
| `expr-net-snapshot`    | net                  | Snapshot (identity — free)   |
| `expr-net-contradict?` | net                  | Check for contradiction      |
| `expr-net-type`        | —                    | Type constructor PropNetwork |
| `expr-cell-id-type`    | —                    | Type constructor CellId      |


<a id="org07545ba"></a>

## 2.10 New/Modified Files

| File                                   | Changes                           |
|-------------------------------------- |--------------------------------- |
| `racket/prologos/propagator.rkt`       | NEW: Persistent network, pure ops |
| `racket/prologos/syntax.rkt`           | +12 AST nodes                     |
| `racket/prologos/typing-core.rkt`      | Infer/check rules for network ops |
| `racket/prologos/reduction.rkt`        | Reduction rules for network ops   |
| `racket/prologos/elaborator.rkt`       | Surface → core for network ops    |
| `racket/prologos/zonk.rkt`             | Zonk cases for new nodes          |
| `racket/prologos/pretty-print.rkt`     | PP cases for new nodes            |
| `racket/prologos/qtt.rkt`              | Multiplicity for network ops      |
| `racket/prologos/substitution.rkt`     | Subst cases for new nodes         |
| `racket/prologos/unify.rkt`            | Unify cases for new nodes         |
| `tests/test-propagator.rkt`            | NEW                               |
| `tests/test-propagator-network.rkt`    | NEW                               |
| `tests/test-propagator-quiescence.rkt` | NEW                               |


<a id="org671390d"></a>

## 2.11 Tests (~60)

-   Network creation: empty, with fuel
-   Cell creation: returns new network + cell-id
-   Cell read: returns value
-   Cell write: merge produces join (FlatLattice, SetLattice)
-   Cell write: no change when value doesn't increase → same network returned
-   Cell write: enqueues dependents
-   Propagator: two cells connected, write propagates
-   Propagator: diamond network (A → B, A → C, B+C → D)
-   run-to-quiescence: fires to fixed point
-   run-to-quiescence: fuel limit prevents runaway
-   run-to-quiescence: contradiction recorded in network
-   Persistence: old network unchanged after write
-   Persistence: old network unchanged after run-to-quiescence
-   Snapshot: identity operation (`net` is already persistent)
-   Backtracking: use old reference after contradiction
-   LVar-style: cell with SetLattice merge, add elements, freeze via read
-   LVar-style: cell with MapLattice merge, pointwise join
-   Integration: lattice instances work through network cells


<a id="org33adad2"></a>

## 2.12 Dependencies

-   Phase 1 (Lattice trait and instances)
-   `champ-insert-join` in `champ.rkt` (used internally for cell merge)
-   Existing trait resolution for Lattice dictionary dispatch
-   12+ files modified (standard AST node pipeline)

&#x2014;


<a id="org6520742"></a>

# Phase 2.5: BSP Parallel Execution ✅


<a id="orgf7b7ef2"></a>

## 2.5.1 Goal

Add a BSP (Bulk Synchronous Parallel) scheduler to the propagator network, enabling parallel-ready execution before Phase 3 type integration. This phase also adds threshold propagators (gated downstream computation) and a pluggable parallel executor using `racket/future`.

See [BSP Parallel Propagator Tracking Doc](2026-02-24_BSP_PARALLEL_PROPAGATOR.md) for full implementation details.


<a id="org121ec1e"></a>

## 2.5.2 BSP Scheduler (Jacobi Iteration)

The existing `run-to-quiescence` uses **Gauss-Seidel iteration** — fire one propagator at a time, each seeing the latest state. The new `run-to-quiescence-bsp` uses **Jacobi iteration**:

```
Round k:
  1. Deduplicate worklist (CHAMP-based set)
  2. Clear worklist, snapshot the network, decrease fuel by N
  3. Fire ALL propagators against the SAME snapshot
  4. Collect writes by diffing output cells
  5. Bulk-merge all writes into snapshot via net-cell-write
  6. Repeat until contradiction / fuel / empty worklist
```

**Same fixpoint** as Gauss-Seidel, guaranteed by the CALM theorem: lattice join is commutative, associative, and idempotent → any scheduling order produces the same result.

| Property               | Gauss-Seidel (existing) | BSP (Jacobi)     |
|---------------------- |----------------------- |---------------- |
| Convergence (chain N)  | 1–N passes              | Exactly N rounds |
| Convergence (fan-out)  | 2–3 passes              | 1–2 rounds       |
| Parallelizable         | No                      | Yes (per round)  |
| Fuel usage             | ≤ BSP                   | ≥ Gauss-Seidel   |
| Deterministic ordering | Worklist order          | Round-based      |


<a id="orgf5f09f3"></a>

## 2.5.3 Threshold Propagators

Threshold propagators gate downstream computation until a cell's value crosses a lattice threshold. They are standard propagators whose `fire-fn` checks a predicate before executing the body.

-   **`make-threshold-fire-fn`**: Watches a single cell, fires body when threshold predicate is true
-   **`make-barrier-fire-fn`**: Multi-cell barrier, fires when ALL predicates are satisfied
-   **`net-add-threshold` / `net-add-barrier`**: Convenience wrappers

For monotonic lattices, once a threshold is met it stays met → the body fires at most once after crossing. This is push-based and reactive.


<a id="org546844c"></a>

## 2.5.4 Parallel Executor

`make-parallel-fire-all` creates a pluggable executor for `run-to-quiescence-bsp`:

```racket
;; Sequential (default)
(run-to-quiescence-bsp net)

;; Parallel
(run-to-quiescence-bsp net #:executor (make-parallel-fire-all))

;; Parallel with custom threshold
(run-to-quiescence-bsp net #:executor (make-parallel-fire-all 8))
```

-   Below threshold (default: 4 propagators): falls back to sequential
-   Above threshold: creates one `future` per propagator, `touch` to collect
-   **Future-safe**: CHAMP operations are pure struct/vector — no mutation

**Contract**: fire-fns MUST be pure for parallel execution.


<a id="org5a25bf8"></a>

## 2.5.5 Implications for Later Phases

The BSP scheduler becomes the **default execution model** for the logic engine:

-   **Phase 5 (ATMS)**: Each worldview exploration can use `run-to-quiescence-bsp`. Independent worldviews are embarrassingly parallel — the BSP executor fires all propagators in a worldview's network simultaneously per round.
-   **Phase 6 (Tabling)**: Producer and consumer propagators are standard propagators — they participate in BSP rounds naturally. Table cell growth triggers re-firing of consumer propagators in the next BSP round.
-   **Phase 7 (Surface Syntax)**: The `solver` keyword controls which scheduler is used. The default solver uses BSP with parallel executor for networks above the threshold.


<a id="orgbcfe26d"></a>

## 2.5.6 New Functions

| Function                  | Purpose                                       |
|------------------------- |--------------------------------------------- |
| `dedup-pids`              | CHAMP-based deduplication (internal)          |
| `fire-and-collect-writes` | Fire against snapshot, diff output cells      |
| `bulk-merge-writes`       | Fold `net-cell-write` over collected writes   |
| `sequential-fire-all`     | Map fire-and-collect-writes over all pids     |
| `run-to-quiescence-bsp`   | BSP loop with pluggable executor              |
| `make-threshold-fire-fn`  | Gated fire-fn (single cell watch)             |
| `make-barrier-fire-fn`    | Multi-cell gated fire-fn                      |
| `net-add-threshold`       | Convenience: threshold + add-propagator       |
| `net-add-barrier`         | Convenience: barrier + add-propagator         |
| `make-parallel-fire-all`  | Creates parallel executor via `racket/future` |


<a id="org4b4a002"></a>

## 2.5.7 Files and Tests

| File                        | Description                                 |
|--------------------------- |------------------------------------------- |
| `propagator.rkt` (modified) | +~120 lines, 9 new exports                  |
| `test-propagator-bsp.rkt`   | 18 tests: 10 BSP + 5 threshold + 3 parallel |


<a id="orgdea9325"></a>

## 2.5.8 Key Design Decisions

1.  **BSP coexists with Gauss-Seidel**: Both produce same fixpoint for monotone networks. Users (and the solver) choose the scheduler.
2.  **Write collection via diffing**: Clean, composable, no changes to existing propagator contract.
3.  **Executor as parameter**: Default = sequential. Swap in parallel. Scheduler logic independent of execution strategy.
4.  **Threshold propagators are standard propagators**: No special scheduler support. Works with both Gauss-Seidel and BSP.
5.  **Future safety**: CHAMP operations are pure → `racket/future` is safe.

&#x2014;


<a id="orga9e67d2"></a>

# Phase 3: PropNetwork as Prologos Type


<a id="orgcf777fe"></a>

## 3.1 Goal

Expose the Racket-level persistent PropNetwork to Prologos's type system. This phase adds the 12 AST nodes defined in Phase 2's design, threading them through the full 12-file pipeline (syntax → typing-core → reduction → elaborator → zonk → pretty-print → qtt → substitution → unify → tests).


<a id="orgf575e8f"></a>

## 3.2 Why a Separate Phase

Phase 2 implements the Racket-level data structures and algorithms. Phase 3 wires them into Prologos as first-class values. This separation follows the established pattern: Racket infrastructure first, then Prologos type system integration.


<a id="orgd04dba6"></a>

## 3.3 Type Signatures

```prologos
;; PropNetwork is an opaque type wrapping the persistent network
deftype PropNetwork
  mk-prop-network : PropNetwork

;; CellId identifies a cell within a network
deftype CellId
  mk-cell-id : Nat -> CellId

;; Operations as typed functions
spec net-new : Nat -> PropNetwork
spec net-new-cell : {A : Type} where (Lattice A)
  PropNetwork -> A -> (A -> A -> A) -> [PropNetwork * CellId]
spec net-cell-read : {A : Type} PropNetwork -> CellId -> A
spec net-cell-write : {A : Type} PropNetwork -> CellId -> A -> PropNetwork
spec net-add-propagator : PropNetwork -> [List CellId] -> [List CellId]
  -> [PropNetwork -> PropNetwork] -> [PropNetwork * PropId]
spec net-run : PropNetwork -> PropNetwork
spec net-snapshot : PropNetwork -> PropNetwork
spec net-contradict? : PropNetwork -> Bool
```


<a id="org19c173c"></a>

## 3.4 LVar Operations as Library Functions

LVar-style operations are library functions on top of PropNetwork, not separate AST nodes:

```prologos
;; A "growing set" = a cell with SetLattice merge
spec make-set-cell : {A : Type} where (Eq A)
  PropNetwork -> [PropNetwork * CellId]
defn make-set-cell [net]
  [net-new-cell net #{} set-union]

;; A "growing map" = a cell with MapLattice merge
spec make-map-cell : {K V : Type} where (Eq K) (Lattice V)
  PropNetwork -> [PropNetwork * CellId]
defn make-map-cell [net]
  [net-new-cell net {} [merge-with join]]
```


<a id="org93ba670"></a>

## 3.5 AST Nodes (12)

Same 12 nodes as Phase 2 design (`expr-prop-network`, `expr-cell-id`, `expr-net-new`, `expr-net-new-cell`, `expr-net-cell-read`, `expr-net-cell-write`, `expr-net-add-prop`, `expr-net-run`, `expr-net-snapshot`, `expr-net-contradict?`, `expr-net-type`, `expr-cell-id-type`).


<a id="org641ddda"></a>

## 3.6 New/Modified Files

| File                                    | Changes                               |
|--------------------------------------- |------------------------------------- |
| `racket/prologos/syntax.rkt`            | +12 AST nodes                         |
| `racket/prologos/typing-core.rkt`       | Infer/check rules for network ops     |
| `racket/prologos/reduction.rkt`         | Reduction rules (delegate to .rkt)    |
| `racket/prologos/elaborator.rkt`        | Surface → core translation            |
| `racket/prologos/zonk.rkt`              | Zonk cases                            |
| `racket/prologos/pretty-print.rkt`      | PP cases                              |
| `racket/prologos/qtt.rkt`               | Multiplicity (:w for networks)        |
| `racket/prologos/substitution.rkt`      | Subst cases                           |
| `racket/prologos/unify.rkt`             | Unify cases                           |
| `lib/prologos/core/propagator.prologos` | NEW: Library wrappers (set/map cells) |
| `tests/test-propagator-types.rkt`       | NEW                                   |
| `tests/test-propagator-integration.rkt` | NEW                                   |
| `tests/test-propagator-lvar.rkt`        | NEW: LVar-style cell tests            |


<a id="org16a376d"></a>

## 3.7 Tests (~50)

-   Type checking: `net-new` returns `PropNetwork`
-   Type checking: `net-cell-read` returns correct element type
-   Type checking: `net-cell-write` returns `PropNetwork`
-   Eval: create network, add cells, read values
-   Eval: write value, verify merge
-   Eval: propagator fires on cell write
-   Eval: diamond network (A → B, A → C, B+C → D)
-   Eval: run-to-quiescence reaches fixed point
-   Eval: fuel exhaustion
-   Eval: contradiction detection
-   Persistence: old network unchanged after operations
-   LVar-style: set cell grows via union
-   LVar-style: map cell does pointwise join
-   LVar-style: freeze = read from quiescent network
-   Integration: Lattice trait resolution for cell merge functions


<a id="orgc14bf10"></a>

## 3.8 Dependencies

-   Phase 2 (Racket-level PropNetwork implementation)
-   Phase 1 (Lattice trait for type-level merge function constraints)

&#x2014;


<a id="org7ff11df"></a>

# Phase 4: UnionFind — Persistent Disjoint Sets


<a id="org193596f"></a>

## 4.1 Goal

Implement a persistent union-find data structure (Conchon & Filliâtre 2007) with backtracking support. This is the core data structure for unification in the logic engine. Unlike the current metavar store (mutable hash table), a persistent union-find supports efficient backtracking for search.


<a id="orga14f7dc"></a>

## 4.2 Design

The union-find uses path splitting (not path compression) to maintain persistence. Each node stores a parent reference and a rank. Find follows parent pointers to the root. Union merges by rank.

```racket
;; In racket/prologos/union-find.rkt

(struct uf-store
  (nodes)     ;; persistent map: id → uf-node
  #:transparent)

(struct uf-node
  (parent     ;; id (self = root)
   rank       ;; natural number
   value)     ;; optional payload (for unification: the term)
  #:transparent)

;; Create empty store
(define (uf-empty) (uf-store (hasheq)))

;; Make a new set with one element
(define (uf-make-set store id value)
  (uf-store
   (hash-set (uf-store-nodes store) id
             (uf-node id 0 value))))

;; Find root of id (with path splitting for amortized cost)
(define (uf-find store id)
  ;; Returns (values root-id updated-store)
  ;; Path splitting: point each node to its grandparent
  ...)

;; Union two sets, merge by rank
(define (uf-union store id1 id2 merge-fn)
  ;; Find roots, merge smaller into larger
  ;; merge-fn combines values if both have payload
  ;; Returns updated store
  ...)

;; Snapshot for backtracking
(define (uf-snapshot store) store)  ;; Already persistent!
```


<a id="org4ccdc13"></a>

## 4.3 Key Properties

-   **Persistent**: Union/find return new stores, old stores unchanged
-   **Backtrackable**: Save a reference to the old store = instant backtrack
-   **Efficient**: O(log n) find and union (path splitting without compression)
-   **Value-carrying**: Nodes carry optional payloads (unified terms)


<a id="org1f08a5e"></a>

## 4.4 Integration with Logic Engine: UF vs Cell Division of Labor

The union-find and propagator cells serve **complementary** roles in the logic engine. They are not alternatives — both are needed:

| Operation                   | Uses UF                    | Uses PropNetwork Cell            |
|--------------------------- |-------------------------- |-------------------------------- |
| `?x = ?y` (var-var)         | `uf-union x y`             | —                                |
| `?x = 42` (var-value)       | `uf-find x` → set value    | —                                |
| `?x = f(?y, ?z)` (complex)  | `uf-union` + subterm cells | Cell per subterm for propagation |
| Lattice-valued accumulation | —                          | `net-cell-write` with join       |
| Table answer sets           | —                          | Cell with `SetLattice` merge     |
| Numeric constraints         | —                          | Cell with `IntervalLattice`      |
| Backtracking                | Keep old `uf-store`        | Keep old `prop-network`          |

The division of labor:

-   **UnionFind**: structural equality — discovering that two variables must refer to the same term. This is the fast path for standard Prolog-style unification. O(log n) find-with-path-splitting.
-   **PropNetwork cells**: lattice-valued accumulation — aggregating information that can only grow (sets of answers, numeric intervals, constraint domains). This is the slow-but-general path for constraint propagation.

In practice, a logic engine query creates *both*:

1.  A `uf-store` for the substitution (logic variable bindings)
2.  A `prop-network` for constraint cells (tables, aggregates, numeric domains)

Both are persistent, both support O(1) backtracking. The solver threads both through computation as a pair: `(uf-store, prop-network)`.


<a id="orgbaa7020"></a>

## 4.5 AST Nodes (~6)

| Node               | Fields          | Semantics                  |
|------------------ |--------------- |-------------------------- |
| `expr-uf-empty`    | —               | Create empty union-find    |
| `expr-uf-make-set` | store, id, val  | Add new singleton set      |
| `expr-uf-find`     | store, id       | Find root of set           |
| `expr-uf-union`    | store, id1, id2 | Union two sets             |
| `expr-uf-value`    | store, id       | Get value at id's root     |
| `expr-uf-type`     | —               | Type constructor UnionFind |


<a id="orgc33c545"></a>

## 4.6 New/Modified Files

| File                             | Changes                     |
|-------------------------------- |--------------------------- |
| `racket/prologos/union-find.rkt` | NEW: Persistent UF          |
| `racket/prologos/syntax.rkt`     | +6 AST nodes                |
| + standard pipeline files        | Type rules, reduction, etc. |
| `tests/test-union-find.rkt`      | NEW                         |


<a id="orgb7fa741"></a>

## 4.7 Tests (~30)

-   Empty store creation
-   Make-set: adds node
-   Find: returns self for singleton
-   Union: merges two sets
-   Union: rank-based merging
-   Find after union: both ids → same root
-   Value: retrieve payload after union
-   Persistence: old store unchanged after union
-   Backtracking: restore snapshot works
-   Performance: 1000 unions, find all roots
-   Integration: as substitution store for simple unification


<a id="orgd3b77db"></a>

## 4.8 Dependencies

-   None (self-contained data structure)
-   Can proceed in parallel with Phase 3

&#x2014;


<a id="org26e178f"></a>

# Phase 5: Persistent ATMS Layer — Hypothetical Reasoning


<a id="orgb3b710c"></a>

## 5.1 Goal

Implement the Assumption-Based Truth Maintenance System (ATMS) as a **persistent, immutable value**. Like the propagator network, the ATMS is backed entirely by CHAMP maps. Backtracking = use old reference. Switching worldviews = `struct-copy` with new `believed` set.

This validates the "Multiverse Mechanism" from the propagator research: choice-point forking maps directly onto ATMS worldview management.


<a id="orgf7efe02"></a>

## 5.2 Core Data Structures (All Persistent)


<a id="org5677a82"></a>

### `assumption` — Hypothetical Premise

```racket
;; In racket/prologos/atms.rkt

(struct assumption-id (n) #:transparent)

(struct assumption
  (name       ;; symbol (for display)
   datum)     ;; optional: the value this assumption asserts
  #:transparent)
```


<a id="org948654a"></a>

### `supported-value` — Value + Justification

```racket
(struct supported-value
  (value      ;; the lattice value
   support)   ;; champ-root : assumption-id → #t (set of assumptions)
  #:transparent)
```


<a id="org941292b"></a>

### `tms-cell` — Truth-Maintained Cell (Immutable)

A TMS cell holds multiple contingent values, each justified by a different assumption set. It generalizes a prop-cell to handle nondeterminism.

```racket
(struct tms-cell
  (values        ;; list of supported-value
   dependents)   ;; champ-root (set of prop-id → #t)
  #:transparent)

;; Note: immutable. Update returns new tms-cell via struct-copy.
;; The cell identity (tms-cell-id) is the key in the ATMS's cells map.
```


<a id="orgdb7b5ab"></a>

### `atms` — The Persistent ATMS

```racket
(struct atms
  (network         ;; prop-network (the underlying persistent network)
   assumptions     ;; champ-root : assumption-id → assumption
   nogoods         ;; list of champ-root (each a set of assumption-ids → #t)
   tms-cells       ;; champ-root : cell-id → tms-cell
   next-assumption ;; Nat — monotonic counter
   believed)       ;; champ-root : assumption-id → #t (current worldview)
  #:transparent)
```

Key design choices:

-   **All CHAMP-backed**: assumptions, nogoods (as frozen sets), tms-cells, believed
-   **Worldview switching**: `(struct-copy atms a [believed new-set])` — O(1)
-   **Backtracking**: keep old `atms` reference — O(1), structural sharing
-   **No mutable state**: all operations return new `atms` values


<a id="org61f5b56"></a>

## 5.3 Pure Operations

```racket
;; Create a new assumption: returns (values new-atms assumption-id)
(define (atms-assume atms name datum)
  (define aid (assumption-id (atms-next-assumption atms)))
  (define a (assumption name datum))
  (values
   (struct-copy atms atms
     [assumptions (champ-insert (atms-assumptions atms)
                                 (equal-hash-code aid) aid a)]
     [next-assumption (+ 1 (atms-next-assumption atms))]
     [believed (champ-insert (atms-believed atms)
                              (equal-hash-code aid) aid #t)])
   aid))

;; Record a nogood: returns new atms with pruned worldview
(define (atms-add-nogood atms nogood-set)
  (struct-copy atms atms
    [nogoods (cons nogood-set (atms-nogoods atms))]))

;; Check consistency of an assumption set
(define (atms-consistent? atms assumption-set)
  (not (for/or ([ng (in-list (atms-nogoods atms))])
         (champ-subset? ng assumption-set))))

;; Switch worldview: returns new atms with different believed set
(define (atms-with-worldview atms new-believed)
  (struct-copy atms atms [believed new-believed]))
```


<a id="org16fabb3"></a>

## 5.4 The `amb` Operator (Pure)

`amb` creates a choice point with n alternatives. Returns new ATMS.

```racket
(define (atms-amb atms alternatives)
  ;; 1. Create fresh hypotheses h1..hn
  (define-values (atms* hyps)
    (for/fold ([a atms] [hs '()])
              ([alt (in-list alternatives)]
               [i (in-naturals)])
      (define-values (a* hid) (atms-assume a (format "h~a" i) alt))
      (values a* (cons hid hs))))
  ;; 2. Record mutual exclusion: any pair is a nogood
  (define atms**
    (for*/fold ([a atms*])
               ([h1 (in-list hyps)]
                [h2 (in-list hyps)]
                #:when (not (equal? h1 h2)))
      (atms-add-nogood a (champ-insert (champ-insert champ-empty
                                          (equal-hash-code h1) h1 #t)
                                        (equal-hash-code h2) h2 #t))))
  ;; 3. Create TMS cell with supported values
  (values atms** hyps))
```


<a id="org9f7c58c"></a>

## 5.5 Two-Tier Mode: Lazy ATMS Activation

The ATMS adds overhead for every cell operation: label management, support set tracking, consistency checking. For **deterministic** queries (no `amb`, no choice points), this overhead is pure waste.

Design requirement: the ATMS operates in two tiers:

**Tier 1 — PropNetwork Only (default)**:

-   No ATMS overhead. Just a `prop-network` with pure propagation.
-   Cells hold simple values, not supported values.
-   `run-to-quiescence` operates directly on the persistent network.
-   This is sufficient for Datalog evaluation, deterministic constraint propagation, and simple tabled predicates.

**Tier 2 — Full ATMS (activated on first `amb`)**:

-   When the solver encounters its first choice point (`amb`), it upgrades to full ATMS mode by wrapping the current network in an `atms` struct.
-   From that point on, all cell values become supported values (tagged with assumption sets).
-   Nogoods, worldview switching, and DDB become available.

```racket
;; The solver state is either a bare network or a full ATMS
;; (struct solver-state (kind data) #:transparent)
;; kind is 'network | 'atms

;; On first amb:
(define (solver-upgrade-to-atms state)
  (if (eq? (solver-state-kind state) 'atms)
      state  ;; already upgraded
      (solver-state 'atms
        (atms-from-network (solver-state-data state)))))

;; atms-from-network : prop-network → atms
;; Wraps existing network, converting all cell values to
;; unconditionally supported values (support = ∅ = always true)
```

The `solve-with` configuration supports:

-   `:strategy :auto` (default) — starts in Tier 1, upgrades on first `amb`
-   `:strategy :depth-first` — pure PropNetwork, no ATMS, chronological choice
-   `:strategy :atms` — full ATMS from the start

This addresses the research doc's §14.1 concern: "For simple deterministic programs, the ATMS layer is pure cost." Lazy activation means deterministic programs never pay ATMS overhead.


<a id="org0dd5c88"></a>

## 5.6 Contradiction Handler (Dependency-Directed Backtracking)

When the underlying prop-network detects contradiction (a cell's merged value = top):

1.  Extract the support set from the contradicted cell's TMS values
2.  Record as a nogood in the ATMS
3.  The nogood automatically prunes that worldview from future exploration
4.  Return new ATMS with nogood recorded

This is pure: each step returns a new `atms` value. Dependency-directed backtracking identifies *which* choice was wrong, not just the most recent.


<a id="orga129ebe"></a>

## 5.7 Answer Collection (Pure)

```racket
;; Enumerate all consistent worldviews and extract answers
(define (atms-solve-all atms goal-cell-id)
  ;; 1. Enumerate maximal consistent assumption sets
  ;; 2. For each worldview, run the network to quiescence
  ;; 3. Extract goal cell value under that worldview
  ;; 4. Collect distinct answers
  ;; Returns: list of answer values
  ...)
```


<a id="orgc244715"></a>

## 5.8 BSP Integration: Parallel Worldview Exploration

The BSP parallel execution model (Phase 2.5) directly benefits ATMS answer collection. Each consistent worldview can be explored in parallel:

1.  **Worldview enumeration**: Generate the set of maximal consistent assumption sets.
2.  **Parallel propagation**: Each worldview gets its own `run-to-quiescence-bsp` call. Since the PropNetwork is persistent/immutable, each worldview starts from a shared snapshot — no copying, just CHAMP structural sharing.
3.  **Answer merge**: Collect answers from all worldview runs and deduplicate.

```racket
;; Parallel worldview exploration using BSP executor
(define (atms-solve-all-parallel atms goal-cell-id
                                 #:executor [exec (make-parallel-fire-all)])
  (define worldviews (enumerate-consistent-worldviews atms))
  ;; Each worldview can run independently — persistent network means
  ;; no interference between parallel explorations
  (define answers
    (for/fold ([acc (set)])
              ([wv (in-list worldviews)])
      (define atms* (atms-with-worldview atms wv))
      (define net* (run-to-quiescence-bsp (atms-network atms*) #:executor exec))
      (define val (net-cell-read net* goal-cell-id))
      (set-union acc (if (eq? val 'bot) (set) (set val)))))
  answers)
```

Key insight: the persistent architecture makes parallel worldview exploration trivially safe. Each future operates on its own immutable snapshot. No locks, no coordination beyond the final answer merge. The BSP executor's threshold parameter (default 4) naturally applies — small ATMS problems with few worldviews run sequentially; large search spaces parallelize automatically.


<a id="org9c5d78d"></a>

## 5.9 AST Nodes (~10)

| Node                  | Fields                   | Semantics                    |
|--------------------- |------------------------ |---------------------------- |
| `expr-atms-new`       | network                  | Create ATMS wrapping network |
| `expr-amb`            | atms, alternatives       | Create choice point          |
| `expr-assume`         | atms, name, datum        | Create hypothesis            |
| `expr-retract`        | atms, assumption-id      | Retract hypothesis           |
| `expr-nogood`         | atms, assumption-set     | Record nogood                |
| `expr-solve-all`      | atms, goal               | Collect all solutions        |
| `expr-tms-read`       | atms, cell, worldview    | Read under worldview         |
| `expr-tms-write`      | atms, cell, val, support | Write supported value        |
| `expr-atms-type`      | —                        | Type constructor ATMS        |
| `expr-supported-type` | val-type                 | Type of SupportedValue       |


<a id="orgfc81bee"></a>

## 5.10 New/Modified Files

| File                             | Changes                        |
|-------------------------------- |------------------------------ |
| `racket/prologos/atms.rkt`       | NEW: Persistent ATMS           |
| `racket/prologos/syntax.rkt`     | +10 AST nodes                  |
| `racket/prologos/propagator.rkt` | Contradiction → record in ATMS |
| + standard pipeline files        | Type rules, reduction, etc.    |
| `tests/test-atms.rkt`            | NEW                            |
| `tests/test-atms-search.rkt`     | NEW                            |
| `tests/test-atms-backtrack.rkt`  | NEW                            |


<a id="org9dc490d"></a>

## 5.11 Tests (~50)

-   ATMS creation from network
-   Assumption creation: returns new atms + id
-   Supported value: value + support set
-   TMS cell: multiple contingent values
-   Consistency check: no nogood subsets
-   amb: creates mutual exclusion nogoods
-   amb: different alternatives under different worldviews
-   Nogood recording: prunes invalid worldviews
-   Dependency-directed backtracking: contradiction identifies cause
-   Worldview switching: `atms-with-worldview` — O(1)
-   Backtracking: keep old atms reference — O(1)
-   Persistence: old atms unchanged after assume/nogood
-   solve-all: enumerates all consistent answers
-   solve-all: deduplicates answers
-   Integration: persistent network + persistent ATMS
-   Performance: 100-alternative amb, solve-all


<a id="org6f854e3"></a>

## 5.12 Dependencies

-   Phase 2 (Persistent PropNetwork — ATMS wraps a network)
-   Phase 3 (PropNetwork as Prologos type — for typed ATMS operations)

&#x2014;


<a id="org5c2c4f8"></a>

# Phase 6: Tabling — SLG-Style Memoization


<a id="org80fc14d"></a>

## 6.1 Goal

Implement tabling for completeness. Without tabling, left-recursive rules cause infinite loops. Tabling memoizes intermediate results and detects fixed-point completion.


<a id="org99a17d3"></a>

## 6.2 Design (XSB-Style SLG Resolution)

| Concept     | Implementation                                     |
|----------- |-------------------------------------------------- |
| Table       | PropNetwork cell with SetLattice merge             |
| Producer    | Propagator computing new answers for table cell    |
| Consumer    | Propagator reading from table cell                 |
| Completion  | Table cell quiescent when no new answers propagate |
| Answer mode | `all` (collect all) or `lattice` (join)            |


<a id="org40ce4d8"></a>

## 6.3 Table Lifecycle

```
1. First call to tabled predicate → create table cell (SetLattice of answers)
2. Launch producer propagator → evaluates rules, writes answers to table cell
3. Recursive call to same predicate → create consumer propagator
   - Consumer reads from table cell
   - Re-fires when table cell's value grows (new answers appear)
4. Network reaches quiescence → no new answers propagate
5. Table cell value is the complete answer set
6. Subsequent calls → read from quiescent network (already computed)
```


<a id="org68d001c"></a>

## 6.4 Core Data Structures (Persistent)

The `table-store` is an **index**, not a store. It maps predicate call patterns to cell-ids in the PropNetwork. The actual answer data lives in PropNetwork cells with `SetLattice` merge — the table-store merely tells you *which* cell to look in.

```racket
;; In racket/prologos/tabling.rkt

(struct table-entry
  (predicate-name  ;; symbol
   call-pattern    ;; the specific instantiation pattern
   cell-id         ;; cell-id in the prop-network (answers live here)
   status)         ;; 'active | 'complete
  #:transparent)   ;; immutable — update via struct-copy

;; NOTE: no `answers` field — answers are stored in the PropNetwork cell
;; identified by `cell-id`. The cell uses SetLattice merge, so writing
;; a new answer to it computes set-union with existing answers.

(struct table-store
  (tables)     ;; champ-root : table-key → table-entry
  #:transparent)

;; Table key: predicate name + call pattern (up to renaming)
(define (table-key name args)
  (cons name (abstract-call-pattern args)))

;; Tables are backed by CHAMP for structural sharing.
;; Backtracking = keep old table-store reference + old prop-network.
;;
;; The lifecycle:
;; 1. First call → create table-entry + new cell in network
;; 2. Producer propagator writes answers to the cell
;; 3. Consumer propagators read from the cell (re-fire when it grows)
;; 4. Quiescence → mark table-entry status as 'complete
;; 5. Subsequent calls → read from the cell (already computed)
```


<a id="org8cbb45a"></a>

## 6.5 Lattice Answer Modes

Following XSB Prolog:

-   **`all`**: Table stores set of all distinct answer substitutions (`SetLattice` on substitutions)
-   **`lattice f`**: Table stores lattice join of all answers via `f` (single aggregated value, new answers only "new" if they improve)
-   **`first`**: Table frozen after first answer (`once` semantics)


<a id="org902500d"></a>

## 6.6 Spec Metadata Integration

Tabling is declared via spec metadata:

```prologos
spec ancestor : String -> String -> Prop
  :tabled true
  :answer-mode all        ;; default
```

This requires adding `:tabled` and `:answer-mode` cases to `parse-spec-metadata` in `macros.rkt` (following the `:examples` pattern).


<a id="org867ebcf"></a>

## 6.7 BSP Integration: Parallel Table Evaluation

Table producers and consumers are standard propagators — they participate naturally in the BSP execution model from Phase 2.5. This means:

1.  **Parallel producer firing**: When multiple producers are runnable in the same BSP round, they fire in parallel against a shared snapshot. Each writes new answers to its table cell; the bulk-merge step unions them.

2.  **Independent tables parallelize automatically**: Tables for different predicates have independent cells. Propagators reading/writing to different table cells have no ordering dependency — the BSP scheduler fires them all in the same round.

3.  **Self-referencing tables (recursive predicates)**: A producer that reads AND writes its own table cell (e.g., `ancestor`'s clause 2) is handled correctly by BSP's Jacobi iteration: the producer sees the snapshot from the *previous* round, not the in-progress writes. New answers appear in the next round. This matches SLG resolution's stratified evaluation.

4.  **Completion detection**: Quiescence in BSP (no dirty cells after a round) is exactly the completion condition for tabling. When no new answers are produced in a round, all tables are complete.

```
BSP Round 1: producer fires → ancestor cell gets {(a,b), (b,c), (b,d)}
BSP Round 2: producer re-fires (cell grew) → derives {(a,c), (a,d)}
BSP Round 3: producer re-fires → no new answers → quiescence = completion
```

This is the same execution trace as the Appendix A walkthrough, but now each round's propagators fire in parallel when the BSP threshold is met.


<a id="orgad8bd3e"></a>

## 6.8 AST Nodes (~8)

| Node                   | Fields            | Semantics                  |
|---------------------- |----------------- |-------------------------- |
| `expr-table-lookup`    | name, args        | Check if answer in table   |
| `expr-table-new`       | name, answer-mode | Create new table           |
| `expr-table-add`       | table, answer     | Add answer to table        |
| `expr-table-freeze`    | table             | Freeze table               |
| `expr-table-answers`   | table             | Get all answers            |
| `expr-table-complete?` | table             | Check if table is complete |
| `expr-tabled`          | spec-name         | Mark predicate as tabled   |
| `expr-table-type`      | answer-type       | Type of table              |


<a id="orgec43d36"></a>

## 6.9 New/Modified Files

| File                             | Changes                        |
|-------------------------------- |------------------------------ |
| `racket/prologos/tabling.rkt`    | NEW: Table store, lifecycle    |
| `racket/prologos/macros.rkt`     | :tabled, :answer-mode metadata |
| `racket/prologos/syntax.rkt`     | +8 AST nodes                   |
| + standard pipeline files        | Type rules, reduction, etc.    |
| `tests/test-tabling.rkt`         | NEW                            |
| `tests/test-tabling-lattice.rkt` | NEW                            |


<a id="org1f490d4"></a>

## 6.10 Tests (~40)

-   Table creation: cell with SetLattice merge in PropNetwork
-   Table answer insertion: cell write grows answer set
-   Network quiescence: table complete when no new answers propagate
-   Producer: generates answers from rules, writes to table cell
-   Consumer: reads from table cell, re-fires on growth
-   Left-recursion: tabling terminates (the critical test)
-   Lattice answer mode: min aggregation
-   Lattice answer mode: set union aggregation
-   First answer mode: stops after one
-   Multiple tables: independent cells in same network
-   Backtracking: persistent network, old table state preserved
-   Spec metadata: :tabled parsed and stored
-   Integration: tabling + persistent ATMS for recursive search


<a id="orgf49ba81"></a>

## 6.11 Dependencies

-   Phase 3 (PropNetwork cells — tables are cells with SetLattice merge)
-   Phase 5 (ATMS — tabling + nondeterminism interact)

&#x2014;


<a id="orga255cad"></a>

# Phase 7: Surface Syntax — `schema`, `defr`, `rel`, `solve`, `explain`, `solver`, `&>`, `||`, `|`


<a id="org34f7386"></a>

## 7.1 Goal

Implement the user-facing relational language as described in [RELATIONAL<sub>LANGUAGE</sub><sub>VISION.org</sub>](principles/RELATIONAL_LANGUAGE_VISION.md).

This phase includes:

-   **`schema`**: The relational specification form that completes the `spec~/~defn`, `schema~/~defr`, `session~/~defproc` triple. Declares a named, closed, validated map type for typed facts, session messages, and closed records.

-   **Dual clause sigils**: `||` for fact blocks (ground data), `&>` for rule clauses (logic with goals). See vision doc § Dual Clause Syntax.

-   **Multi-arity `|` dispatch**: Structural dispatch on arity and head pattern, consistent with functional `defn`. See vision doc § Multi-Arity Relations.

-   **Bare-name logic variables**: Mode annotations (`?~/~+~/`-`) appear only in parameter lists (signature-level contracts). Body variables are bare; the ~(...)` delimiter establishes relational context.

-   **Corrected mode conventions**: `+` = input (bound on entry), `-` = output (will be bound), `?` = free. Standard Prolog/Mercury convention.

See [RELATIONAL<sub>LANGUAGE</sub><sub>VISION.org</sub>](principles/RELATIONAL_LANGUAGE_VISION.md) for the full design.


<a id="org4ce6c81"></a>

## 7.2 Reader Changes

The reader must handle:

| Syntax       | Reader Output                                      |
|------------ |-------------------------------------------------- |
| `?var`       | `(logic-var var)` (free mode, signature only)      |
| `+var`       | `(mode-var in var)` (input mode, signature only)   |
| `-var`       | `(mode-var out var)` (output mode, signature only) |
| `&>`         | `($clause-sep)`                                    |
| `\vert\vert` | `($facts-sep)`                                     |
| `(goal ...)` | `(goal ...)` (parenthetical = relational)          |

Note: Mode prefixes (`?`, `+`, `-`) are recognized only in parameter lists (`defr=/=rel` signatures and `|` variant heads). In relational bodies, bare lowercase names are logic variables — no prefix needed. The reader does not need to special-case body positions; the parser/elaborator handles the distinction between signature-level mode annotations and body-level bare variable references.


<a id="orgbe7eae5"></a>

## 7.3 Parser Changes

New surface AST nodes:

| Form                                          | Surface AST                                  |
|--------------------------------------------- |-------------------------------------------- |
| `defr name [args] body`                       | `(surf-defr name args clauses)`              |
| `defr name \vert [...] body \vert [...] body` | `(surf-defr name #f variants)` (multi-arity) |
| `(rel [args] body)`                           | `(surf-rel args clauses)`                    |
| `&> g1 g2 ...`                                | `(surf-clause (g1 g2 ...))` within defr/rel  |
| `\vert\vert term1 term2 ...`                  | `(surf-facts ((t1 t2) ...))` (fact block)    |
| `(solve (goal))`                              | `(surf-solve goal)`                          |
| `(solve-with solver (goal))`                  | `(surf-solve-with solver #f goal)`           |
| `(solve-with solver {overrides} (goal))`      | `(surf-solve-with solver overrides goal)`    |
| `(solve-with {overrides} (goal))`             | `(surf-solve-with #f overrides goal)`        |
| `(explain (goal))`                            | `(surf-explain goal)`                        |
| `(explain-with solver (goal))`                | `(surf-explain-with solver #f goal)`         |
| `(explain-with solver {overrides} (goal))`    | `(surf-explain-with solver overrides goal)`  |
| `(explain-with {overrides} (goal))`           | `(surf-explain-with #f overrides goal)`      |
| `solver name opts ...`                        | `(surf-solver name opts)`                    |
| `(` x y)=                                     | `(surf-unify x y)`                           |
| `(is x [expr])`                               | `(surf-is var expr)`                         |
| `schema name fields ...`                      | `(surf-schema name fields)`                  |


<a id="org0e141ec"></a>

### Multi-arity `|` dispatch

`defr` supports multi-arity dispatch via `|`, consistent with functional `defn`:

```prologos
defr sum-list
  | [+list -sum]
    (sum-list list 0 sum)
  | [[] +acc -sum]
    &> (= acc sum)
  | [[+x|+xs] +acc -sum]
    &> (new-acc is [+ acc x])
       (sum-list xs new-acc sum)
```

Each `|` introduces a *variant* with its own parameter list and body. The parser collects variants into `(surf-defr-variant params clauses)` structs. Dispatch is on arity and head structure (pattern matching).


<a id="orgbf216c0"></a>

### `||` fact blocks

`||` introduces a block of ground facts (positional or dictionary):

```prologos
defr parent-child : ParentChild
  || "Alice" "Bob"
     "Bob"   "Carol"
     "Bob"   "Dave"
```

The parser collects continuation lines (same indentation) as additional rows in the fact block. Each row is a `(surf-fact-row terms)` within the `(surf-facts rows)` node.


<a id="org07a32cc"></a>

### `solve~/~explain` use `(...)` for goals

Note: `solve` and `explain` take relational goals in `(...)` parentheses, not `[...]` brackets, consistent with the delimiter-based paradigm distinction:

```
(solve (ancestor "alice" who))          ;; (goal) in parens
(solve-with solver (goal))
(solve-with solver {map} (goal))
(solve-with {map} (goal))
```

The `{...}` braces are unambiguous: they cannot appear as a goal (goals use parentheses) or as a solver name (identifiers). This eliminates multi-arity parsing complexity.


<a id="orgb2a761f"></a>

## 7.4 Elaboration

Relations elaborate to propagator networks. Here is the concrete Racket-level translation for both `defr` and `solve`:


<a id="org87360c2"></a>

### 7.4.1 `defr` Elaboration

```racket
;; defr ancestor [?x ?y]
;;   &> (parent x y)
;;   &> (parent x z) (ancestor z y)
;;
;; elaborates to:
;; 1. Create table for ancestor (tabled by default)
;; 2. For each clause, create a propagator that:
;;    a. Unifies arguments with clause head
;;    b. Resolves subgoals (recursively, via table)
;;    c. If all succeed, adds answer to table
;; 3. Register in relation store
```


<a id="org781b1a7"></a>

### 7.4.2 `solve` Elaboration (Functional-Relational Bridge)

The `solve` form is the bridge from relational goals back to functional values. It always returns `Seq (Map Keyword Value)` — bare bindings, no provenance.

```prologos
;; Source: functional code using solve
defn find-ancestors [person]
  (solve (ancestor person who))
;; Returns: Seq (Map Keyword Value)
;; => '[{:who "bob"} {:who "carol"} {:who "dave"}]
```

Elaborates to:

```racket
;; Racket-level translation of (solve (ancestor person who))
(define (solve-ancestor-query person)
  (let* (;; 1. Resolve solver config (default-solver from current namespace)
         [config (resolve-solver-config 'default-solver)]

         ;; 2. Create solver state (network + uf-store)
         [net0 (make-prop-network)]
         [uf0  (uf-empty)]

         ;; 3. Create logic variable cells
         ;;    who is the query variable; person is ground (bound)
         [net1+who (net-new-cell net0 'bot flat-join flat-top?)]
         [net1 (car net1+who)]
         [who-id (cdr net1+who)]

         ;; 4. Look up 'ancestor in the relation registry
         ;;    (registered by defr elaboration)
         [ancestor-rel (relation-lookup 'ancestor)]

         ;; 5. Create query propagators:
         ;;    - Instantiate ancestor's clauses with (person, who)
         ;;    - Wire table cell for ancestor
         [net2 (relation-instantiate ancestor-rel net1 uf0
                  (list (ground-val person) who-id))]

         ;; 6. Build executor from solver config
         [executor (config->executor config)]

         ;; 7. Run to quiescence (BSP or sequential per config)
         [net3 (run-to-quiescence* net2 executor)]

         ;; 8. Extract answers from the table cell
         [answers (table-answers net3 'ancestor)]

         ;; 9. Project query variable bindings into Maps
         [results (for/list ([subst (in-set answers)])
                    (hash ':who (substitution-lookup subst who-id)))])
    ;; Return as lazy sequence of keyword maps
    (list->lseq results)))
```


<a id="org60404e7"></a>

### 7.4.3 `solve-with` Elaboration (Map Merge Override)

The `-with` forms accept a solver name and/or a `{...}` override map. The elaborator resolves the config via map merge:

```racket
;; (solve-with default-solver {:timeout 5000} [goal])
;; elaborates to:
(let* ([base-config (resolve-solver-config 'default-solver)]
       [overrides (hash ':timeout 5000)]
       [config (solver-config-merge base-config overrides)])
  (solve-impl config goal-thunk))

;; (solve-with {:execution :sequential :timeout 5000} [goal])
;; elaborates to:
(let* ([base-config (resolve-solver-config 'default-solver)]  ;; implicit default
       [overrides (hash ':execution 'sequential ':timeout 5000)]
       [config (solver-config-merge base-config overrides)])
  (solve-impl config goal-thunk))
```

`solver-config-merge` is shallow map merge — overrides win per key:

```racket
(define (solver-config-merge base overrides)
  ;; overrides is a Prologos Map (CHAMP-backed)
  ;; shallow merge: each key in overrides replaces the same key in base
  (for/fold ([cfg base])
            ([(k v) (in-champ overrides)])
    (solver-config-set cfg k v)))
```


<a id="org9c3e1ac"></a>

### 7.4.4 `explain` Elaboration (Provenance-Bearing Bridge)

`explain` returns `Seq (Answer Value)` — each answer bundles bindings AND provenance together. Provenance tracking is forced on (defaulting to `:full` if the solver config doesn't specify a level).

```prologos
;; Source: debugging code using explain
defn debug-ancestors [person]
  (explain (ancestor person who))
;; Returns: Seq (Answer Value)
;; Each Answer has:
;;   .bindings   : Map Keyword Value    — the what
;;   .derivation : DerivationTree       — the why
;;   .depth      : Nat                  — derivation depth
;;   .support    : Option (Set Keyword) — ATMS support (if :provenance :atms)
```

The elaboration is identical to `solve` except:

1.  The solver config's `:provenance` key is forced to at least `:full` (if it was `:none`, override to `:full`; otherwise respect the level)
2.  The executor is wrapped in a provenance-recording decorator
3.  The result projection builds `Answer` records instead of bare `Map`

```racket
;; explain elaboration — differs from solve in 3 places
(define (explain-impl config goal-thunk)
  ;; 1. Force provenance on
  (define prov-level
    (let ([cfg-prov (solver-config-provenance config)])
      (if (eq? cfg-prov 'none) 'full cfg-prov)))

  ;; 2. Build provenance-recording executor
  (define executor (config->executor config))
  (define recording-executor
    (make-provenance-executor executor prov-level))

  ;; 3. Run to quiescence with provenance tracking
  (define-values (net-final trace)
    (run-to-quiescence-traced net recording-executor))

  ;; 4. Project into Answer records (bindings + derivation together)
  (define results
    (for/list ([subst (in-set (table-answers net-final table-id))])
      (make-answer
       #:bindings   (project-bindings subst query-vars)
       #:derivation (extract-derivation trace subst)
       #:depth      (derivation-depth trace subst)
       #:support    (and (eq? prov-level 'atms)
                         (extract-support trace subst)))))
  (list->lseq results))
```

`explain-with` follows the same map-merge pattern as `solve-with`:

```prologos
;; All of these work:
(explain-with debug-solver (ancestor "alice" who))
(explain-with default-solver {:provenance :atms} (ancestor "alice" who))
(explain-with {:provenance :summary :timeout 5000} (ancestor "alice" who))
```

Key points:

-   `solve` creates a fresh `(network, uf-store)` pair scoped to the query
-   Ground arguments are injected directly; logic variables become cells
-   The relation's propagators run to quiescence in the fresh network
-   `solve` projects into `Seq (Map Keyword Value)` — bare bindings
-   `explain` projects into `Seq (Answer Value)` — bindings + provenance
-   Both forms dispatch to `default-solver` (or a named/merged solver)
-   Both accept `{...}` map overrides for per-call config
-   The entire operation is **pure** — no side effects, no global state


<a id="orgeb58176"></a>

## 7.5 Grammar Updates

Both grammar files must be updated:

-   `docs/spec/grammar.ebnf` — EBNF production rules
-   `docs/spec/grammar.org` — Prose companion with examples

New productions:

```ebnf
(* --- Relations --- *)
relation-def  = "defr" , identifier , [ ":" , type-expr ] ,
                ( single-arity | multi-arity ) ;
single-arity  = param-list , clause-body ;
multi-arity   = variant+ ;
variant       = "|" , param-list , clause-body ;
clause-body   = ( fact-block | rule-clause | bare-goal )+ ;
fact-block    = "||" , fact-row+ ;                    (* ground data block *)
fact-row      = expression+ ;                         (* positional or dict *)
rule-clause   = "&>" , goal+ ;                        (* rule with goals *)
bare-goal     = goal ;                                (* single goal, no &> *)
anonymous-rel = "(" , "rel" , param-list , clause-body , ")" ;
goal          = "(" , goal-head , goal-arg* , ")" ;
goal-head     = identifier | "=" | "is" | "not" ;
goal-arg      = identifier | expression ;             (* bare names = logic vars *)

(* --- Mode annotations (signature-level only) --- *)
logic-var     = "?" , identifier ;                    (* free mode *)
mode-var-in   = "+" , identifier ;                    (* input mode *)
mode-var-out  = "-" , identifier ;                    (* output mode *)
param         = logic-var | mode-var-in | mode-var-out | identifier ;

(* --- Schema --- *)
schema-def    = "schema" , identifier , schema-field+ ;
schema-field  = keyword , type-expr ;

(* --- Solve family (returns Seq Map — bare bindings) --- *)
solve-expr    = "(" , "solve" , goal , ")" ;
solve-with    = "(" , "solve-with" , with-args , goal , ")" ;

(* --- Explain family (returns Seq Answer — bindings + provenance) --- *)
explain-expr  = "(" , "explain" , goal , ")" ;
explain-with  = "(" , "explain-with" , with-args , goal , ")" ;

(* --- Shared -with argument patterns --- *)
with-args     = identifier                           (* solver name only *)
              | identifier , map-literal             (* solver + {overrides} *)
              | map-literal ;                        (* {overrides} only, merge into default-solver *)

(* --- Solver definition --- *)
solver-def    = "solver" , identifier , solver-opt+ ;
solver-opt    = ":" , solver-key , solver-value ;
solver-key    = "execution" | "threshold" | "strategy"
              | "tabling" | "timeout" | "provenance" ;
```


<a id="org53a33bd"></a>

## 7.6 Solver, Solve, and Explain — Unified Design

This section describes the complete design for how relational queries are configured, dispatched, and how results (with or without provenance) are returned to functional code.


<a id="org487e68f"></a>

### 7.6.1 Design Overview

Two verb families, one config form:

| Form           | Returns                   | Provenance            | Config source     |
|-------------- |------------------------- |--------------------- |----------------- |
| `solve`        | `Seq (Map Keyword Value)` | Always off            | `default-solver`  |
| `solve-with`   | `Seq (Map Keyword Value)` | Always off            | Named + `{merge}` |
| `explain`      | `Seq (Answer Value)`      | Forced on             | `default-solver`  |
| `explain-with` | `Seq (Answer Value)`      | On, level from config | Named + `{merge}` |

-   `solve` is the fast path: bare bindings, zero provenance overhead.
-   `explain` is the observation path: each answer bundles the *what* (bindings) with the *why* (derivation tree, support sets).
-   Both dispatch to the same solver engine; the difference is purely what gets projected into the result.


<a id="org2925b22"></a>

### 7.6.2 The `solver` Top-Level Form

`solver` defines a Prologos-level configuration object — a self-documenting, inspectable value. It carries both execution config and provenance defaults.

```prologos
;; Built-in solver definitions (in lib/prologos/core/solver.prologos)
solver default-solver
  :execution   :parallel     ;; BSP parallel (Phase 2.5)
  :threshold   4             ;; parallelize when ≥4 runnable propagators
  :strategy    :auto         ;; Tier 1 (PropNetwork) → Tier 2 (ATMS) on first amb
  :tabling     :by-default   ;; all defr predicates tabled unless :tabled false
  :provenance  :none         ;; no provenance overhead by default
  :timeout     :none

solver sequential-solver
  :execution   :sequential   ;; Gauss-Seidel single-thread
  :strategy    :auto
  :tabling     :by-default
  :provenance  :none
  :timeout     :none

solver debug-solver
  :execution   :sequential   ;; sequential for reproducible traces
  :strategy    :auto
  :provenance  :full         ;; derivation trees always
  :timeout     10000

solver depth-first-solver
  :execution   :sequential
  :strategy    :depth-first  ;; no ATMS, chronological backtracking
  :tabling     :off          ;; user must opt-in with :tabled true
  :provenance  :none
  :timeout     :none
```

Solver config keys:

| Key           | Values                                | Default       | Semantics                              |
|------------- |------------------------------------- |------------- |-------------------------------------- |
| `:execution`  | `:parallel`, `:sequential`            | `:parallel`   | BSP (Jacobi) vs Gauss-Seidel           |
| `:threshold`  | `Nat`                                 | `4`           | Parallel fire threshold                |
| `:strategy`   | `:auto`, `:depth-first`, `:atms`      | `:auto`       | ATMS tier (auto upgrades on first amb) |
| `:tabling`    | `:by-default`, `:off`                 | `:by-default` | Tabling for defr predicates            |
| `:provenance` | `:none`, `:summary`, `:full`, `:atms` | `:none`       | Provenance tracking level              |
| `:timeout`    | `Nat` (ms) or `:none`                 | `:none`       | Query timeout                          |

Provenance levels:

| Level      | What's recorded                                       | Cost     |
|---------- |----------------------------------------------------- |-------- |
| `:none`    | Nothing — bindings only                               | Zero     |
| `:summary` | Clause-id + depth per answer (no tree)                | Low      |
| `:full`    | Complete derivation tree per answer                   | Moderate |
| `:atms`    | Derivation tree + ATMS support sets (assumption sets) | High     |


<a id="orge021d27"></a>

### 7.6.3 The `Answer` Type

When `explain` is used, each result is an `Answer` — a record bundling the bindings (the what) with the provenance (the why). These are never separated: if you want to understand *why* an answer was derived, you always see *which* answer it is.

```prologos
;; In lib/prologos/core/solver.prologos
deftype Answer {V : Type}
  :bindings    (Map Keyword V)           ;; the substitution — the what
  :derivation  (Option DerivationTree)   ;; present at :full and :atms
  :clause-id   (Option Keyword)          ;; which clause produced this
  :depth       Nat                       ;; derivation depth
  :support     (Option (Set Keyword))    ;; ATMS support set — at :atms only

deftype DerivationTree
  :goal      Keyword                     ;; relation name
  :args      (List Value)                ;; instantiated arguments
  :rule      Keyword                     ;; clause identifier
  :children  (List DerivationTree)       ;; sub-derivations
```

At `:summary` level, `.derivation` is `nothing` but `.clause-id` and `.depth` are populated. At `:full`, the derivation tree is present. At `:atms`, both the tree and the support set are present.

The bindings are always present, at every level. Ignoring provenance data you don't need is just ignoring record fields — the data is immutable and the fields carry no ceremony.


<a id="org5dcc7cc"></a>

### 7.6.4 Dispatch: `solve` / `explain` and `default-solver`

`solve` is sugar that expands to `solve-with default-solver`:

```prologos
;; User code:
(solve (ancestor "alice" who))
;; Desugars to:
(solve-with default-solver (ancestor "alice" who))
;; Returns: Seq (Map Keyword Value)
;; => '[{:who "bob"} {:who "carol"} {:who "dave"}]
```

`explain` similarly desugars to `explain-with default-solver`:

```prologos
;; User code:
(explain (ancestor "alice" who))
;; Desugars to:
(explain-with default-solver (ancestor "alice" who))
;; Returns: Seq (Answer Value)
;; Each answer carries .bindings AND .derivation
```

The semantic difference:

-   `solve` / `solve-with` *always* behaves as if `:provenance :none`, regardless of the solver config. Provenance keys on the solver are ignored. Return type is `Seq (Map Keyword Value)`.
-   `explain` / `explain-with` reads `:provenance` from the (possibly merged) solver config. If the solver says `:none` or doesn't specify, `explain` defaults to `:full`. Return type is `Seq (Answer Value)`.

This means `solve` and `explain` encode the **caller's intent**, not the solver's config. The solver's `:provenance` key is a *default level for explain*, not a gate on whether provenance happens.


<a id="org3571fb9"></a>

### 7.6.5 Map Merge Overrides with `{...}`

Both `-with` forms accept an explicit `{...}` map literal that merges as overrides into the solver config. The `{...}` syntax disambiguates parsing and eliminates multi-arity complexity:

```prologos
;; --- solve-with ---
(solve-with debug-solver (goal))                             ;; named solver
(solve-with default-solver {:timeout 5000} (goal))           ;; solver + overrides
(solve-with {:execution :sequential :timeout 5000} (goal))   ;; overrides into default-solver

;; --- explain-with ---
(explain-with debug-solver (goal))                           ;; named solver
(explain-with default-solver {:provenance :atms} (goal))     ;; upgrade provenance
(explain-with {:provenance :summary :timeout 5000} (goal))   ;; overrides into default-solver
```

The merge semantics are shallow map merge — each key in `{overrides}` replaces the same key in the base solver config. This is just our existing map merge semantics applied to solver configs. The merged config is transient to that one call — it is not a named entity and does not persist.


<a id="orgd2ce54e"></a>

### 7.6.6 `default-solver` Shadowing

`default-solver` is a module-level binding. Users shadow it in their namespace with a local `solver` definition:

```prologos
;; In a performance-sensitive module:
solver default-solver
  :execution   :sequential
  :strategy    :depth-first
  :timeout     5000

;; All (solve ...) and (explain ...) calls in this module
;; use the local default-solver
(solve (expensive-query x))
(explain (expensive-query x))  ;; uses :full provenance (explain's default)
```

No global mutation. Normal name resolution.


<a id="orga8b1a34"></a>

### 7.6.7 `solver` Elaboration

A `solver` definition elaborates to a record value backed by a Prologos Map:

```racket
;; solver default-solver :execution :parallel :threshold 4 ...
;; elaborates to:
(define default-solver
  (make-solver-config
   (hash ':execution 'parallel
         ':threshold 4
         ':strategy 'auto
         ':tabling 'by-default
         ':provenance 'none
         ':timeout #f)))
```

The solver config is a Map under the hood, which is why `{...}` merge works naturally — it's map-merge-with-last-writer-wins.


<a id="orgd94c86b"></a>

### 7.6.8 Default-Parallel Tradeoffs

Defaulting to parallel (BSP) execution is justified because:

| Factor              | Parallel (BSP)                                 | Sequential (Gauss-Seidel) |
|------------------- |---------------------------------------------- |------------------------- |
| Correctness         | Same fixpoint (CALM theorem)                   | Same fixpoint             |
| Small problems (<4) | Falls back to sequential (threshold)           | Native                    |
| Large problems      | Near-linear speedup on propagator-heavy rounds | Single-thread bound       |
| Memory              | One snapshot per round + futures               | Single mutable pass       |
| Determinism         | Round-level deterministic (Jacobi)             | Firing-order sensitive    |
| Debugging           | Reproducible (same round = same result)        | Order-dependent traces    |

The threshold parameter (default 4) is the key: below threshold, BSP delegates to sequential fire — so small queries pay zero parallel overhead. Above threshold, the persistent CHAMP architecture makes parallelism trivially safe (no locks, no shared mutable state). The only cost is per-round snapshot creation, which is O(1) for persistent data.


<a id="orgd079b74"></a>

## 7.7 Compile-Time Stratification Check

Any program using `not` (negation-as-failure) must pass a stratification check at compile time. This is the minimum viable safety guarantee for negation:

1.  **Build the predicate dependency graph**: For each `defr`, record which predicates it calls positively and negatively (via `not`).

2.  **Compute SCCs**: Strongly connected components via Tarjan's algorithm. Each SCC is a group of mutually recursive predicates.

3.  **Classify negative edges**: An edge `A --not--> B` is:
    -   **Safe** if `B` is in a *lower* SCC than `A` (B is fully computed before A uses its negation)
    -   **Unsafe** if `B` is in the *same* SCC as `A` (cyclic negation — the truth of `not B` depends on `A` which depends on `not B`)

4.  **Reject unstratifiable programs**: If any negative edge is within an SCC, emit a compile-time error: "Cyclic negation detected: `A` and `B` are mutually recursive through negation. Consider restructuring."

5.  **Assign strata**: Each SCC gets a stratum number (topological order of the condensation DAG). Lower strata are evaluated first; their results are frozen before higher strata use them via `not`.

```racket
;; In racket/prologos/stratify.rkt (NEW)

;; stratify : (Listof defr-info) → (Listof (Listof defr-info))
;; Returns a list of strata (each stratum = list of defrs to evaluate together)
;; Raises compile-time error if program is unstratifiable

(define (stratify defr-infos)
  (define dep-graph (build-dependency-graph defr-infos))
  (define sccs (tarjan-scc dep-graph))
  (define condensation (condense dep-graph sccs))
  ;; Check: no negative edge within any SCC
  (for ([scc (in-list sccs)])
    (for ([pred (in-list scc)])
      (for ([neg-dep (in-list (negative-dependencies pred))])
        (when (member neg-dep scc)
          (raise-stratification-error pred neg-dep scc)))))
  ;; Return strata in topological order
  (topological-sort condensation))
```

This check runs during elaboration of `defr` forms. Programs without `not` are trivially stratifiable (single stratum) and incur no analysis cost.


<a id="orgf2758f8"></a>

## 7.8 AST Nodes (~26)


<a id="orgcccf6e4"></a>

### Relational Core (~14)

| Node                 | Fields                 | Semantics                                 |
|-------------------- |---------------------- |----------------------------------------- |
| `expr-defr`          | name, schema, variants | Named relation (multi-arity)              |
| `expr-defr-variant`  | params, body           | Single arity/pattern variant              |
| `expr-rel`           | params, clauses        | Anonymous relation                        |
| `expr-clause`        | goals                  | Single rule clause (&> &#x2026;)          |
| `expr-fact-block`    | rows                   | Ground fact block (&vert;&vert; &#x2026;) |
| `expr-fact-row`      | terms                  | Single fact row                           |
| `expr-goal-app`      | name, args             | Relational goal application               |
| `expr-logic-var`     | name, mode             | Logic variable (signature only)           |
| `expr-unify-goal`    | lhs, rhs               | Unification goal (= x y)                  |
| `expr-is-goal`       | var, expr              | Functional evaluation in relation         |
| `expr-not-goal`      | goal                   | Negation-as-failure                       |
| `expr-relation-type` | param-types            | Type of a relation                        |
| `expr-schema`        | name, fields           | Named closed validated map                |
| `expr-schema-type`   | name                   | Type constructor for schema               |


<a id="orgd413d68"></a>

### Solve Family (~4)

| Node              | Fields                  | Semantics                                                   |
|----------------- |----------------------- |----------------------------------------------------------- |
| `expr-solve`      | goal                    | Solve → `Seq (Map Keyword Value)`                           |
| `expr-solve-with` | solver, overrides, goal | Parameterized solve (solver may be #f, overrides may be #f) |
| `expr-solve-one`  | goal                    | Solve returning first answer only                           |
| `expr-goal-type`  | —                       | Type of a goal                                              |


<a id="orgb07e64a"></a>

### Explain Family (~2)

| Node                | Fields                  | Semantics                                              |
|------------------- |----------------------- |------------------------------------------------------ |
| `expr-explain`      | goal                    | Explain → `Seq (Answer Value)`                         |
| `expr-explain-with` | solver, overrides, goal | Parameterized explain (same -with arity as solve-with) |


<a id="org8a2fee2"></a>

### Solver Config (~2)

| Node                 | Fields     | Semantics                               |
|-------------------- |---------- |--------------------------------------- |
| `expr-solver-config` | config-map | Solver configuration value (Map-backed) |
| `expr-solver-type`   | —          | Type constructor `Solver`               |


<a id="orgca62489"></a>

### Answer + Provenance Types (~2)

| Node                   | Fields   | Semantics                         |
|---------------------- |-------- |--------------------------------- |
| `expr-answer-type`     | val-type | Type constructor `Answer V`       |
| `expr-derivation-type` | —        | Type constructor `DerivationTree` |


<a id="org914bcff"></a>

### Control (~2)

| Node         | Fields          | Semantics               |
|------------ |--------------- |----------------------- |
| `expr-cut`   | —               | Committed choice (once) |
| `expr-guard` | condition, goal | Guard evaluation        |


<a id="org4e3f23c"></a>

## 7.9 New/Modified Files

| File                                   | Changes                                     |
|-------------------------------------- |------------------------------------------- |
| `racket/prologos/reader.rkt`           | ?var, +var, -var, &>, &vert;&vert; handling |
| `racket/prologos/surface-syntax.rkt`   | New surface AST structs                     |
| `racket/prologos/parser.rkt`           | Parse defr, rel, solve, explain, solver, &> |
| `racket/prologos/macros.rkt`           | process-defr, process-rel, process-solver   |
| `racket/prologos/elaborator.rkt`       | Elaborate relations → propagators           |
| `racket/prologos/stratify.rkt`         | NEW: SCC + stratification check             |
| `racket/prologos/solver.rkt`           | NEW: Solver config, dispatch, map merge     |
| `racket/prologos/provenance.rkt`       | NEW: Provenance executor, derivation trees  |
| `racket/prologos/syntax.rkt`           | +21 AST nodes                               |
| `racket/prologos/typing-core.rkt`      | Type rules for relational + explain forms   |
| + standard pipeline files              | All 12+ consuming modules                   |
| `docs/spec/grammar.ebnf`               | New productions (solve, explain, solver)    |
| `docs/spec/grammar.org`                | New sections                                |
| `lib/prologos/core/solver.prologos`    | NEW: Built-in solver definitions            |
| `lib/prologos/core/answer.prologos`    | NEW: Answer + DerivationTree types          |
| `lib/prologos/core/relations.prologos` | NEW: Standard relations                     |
| `tests/test-relations-basic.rkt`       | NEW                                         |
| `tests/test-relations-tabling.rkt`     | NEW                                         |
| `tests/test-relations-search.rkt`      | NEW                                         |
| `tests/test-relations-ws.rkt`          | NEW: WS-mode integration                    |
| `tests/test-solve.rkt`                 | NEW: solve, solve-with, map merge           |
| `tests/test-explain.rkt`               | NEW: explain, explain-with, Answer type     |
| `tests/test-solver-config.rkt`         | NEW: solver def, shadowing, merge           |


<a id="orge02c100"></a>

## 7.10 Tests (~110)


<a id="org9b63e3e"></a>

### Relations and Goals (~20)

-   Reader: ?var, +var (in), -var (out) parsed correctly
-   Parser: defr, rel, &>, ||, |, solve, explain, solver, schema parsed correctly
-   WS-mode: defr with indentation-based clauses
-   Sexp-mode: defr with explicit (defr &#x2026;) form
-   Basic relation: parent facts, query
-   Recursive relation: ancestor with tabling
-   Unification goal: = ?x ?y
-   Functional evaluation: is ?x [expr]
-   Multiple clauses: &> separator
-   Anonymous relation: (rel [?x ?y] &> &#x2026;)
-   Multi-arity defr: | dispatch on arity/pattern
-   Fact blocks: || ground data, continuation lines
-   Schema: definition, typed defr annotation
-   Negation: not (goal)
-   Mode annotations: -var, +var optimization hints
-   Integration with functional code: solve in defn body
-   Integration with traits: relation using trait methods


<a id="org5ea3769"></a>

### Solve Family (~15)

-   Solve: returns `Seq (Map Keyword Value)`
-   Solve: empty result for unsatisfiable goal
-   Solve: ignores `:provenance` key on solver config
-   Solve-with: named solver dispatch
-   Solve-with: solver + `{overrides}` map merge
-   Solve-with: `{overrides}` only (merge into default-solver)
-   Solve-with: `:strategy` override
-   Solve-with: `:timeout` override
-   Solve-with: `:execution :sequential` override
-   Solve-with: merged config does not persist after call
-   Solve-one: returns first answer only (`Option (Map Keyword Value)`)
-   Integration: solve in defn body with map/filter on results


<a id="orgbcec60c"></a>

### Explain Family (~20)

-   Explain: returns `Seq (Answer Value)`
-   Explain: each Answer has `.bindings` AND `.derivation`
-   Explain: defaults to `:provenance :full` when solver says `:none`
-   Explain: respects solver's `:provenance` level when set
-   Explain-with: named solver dispatch
-   Explain-with: solver + `{overrides}` map merge
-   Explain-with: `{overrides}` only (merge into default-solver)
-   Explain-with: `{:provenance :atms}` includes support sets
-   Explain-with: `{:provenance :summary}` has clause-id/depth but no tree
-   Answer.bindings: same data as solve returns (just bundled)
-   Answer.derivation: tree structure for recursive derivation
-   Answer.depth: correct depth count
-   Answer.support: present only at `:atms` level
-   DerivationTree: .goal, .args, .rule, .children correctly populated
-   DerivationTree: recursive relation shows chain of rule applications
-   Explain: ancestor example matches Appendix A derivation trace
-   Performance: explain overhead proportional to provenance level


<a id="orgf252428"></a>

### Solver Config (~15)

-   Solver: definition elaborates to Map-backed config value
-   Solver: default-solver uses `:parallel` execution
-   Solver: sequential-solver uses `:sequential` execution
-   Solver: debug-solver uses `:provenance :full`
-   Solver: depth-first-solver uses `:depth-first` strategy
-   Solver: user-defined solver shadows default-solver in namespace
-   Solver: solve desugars to solve-with default-solver
-   Solver: explain desugars to explain-with default-solver
-   Solver: `{...}` merge produces shallow map merge (last writer wins)
-   Solver: `:threshold` option controls parallel/sequential cutoff
-   Solver: solver config is inspectable Prologos value
-   Solver: all keys (:execution, :threshold, :strategy, :tabling, :provenance, :timeout) parsed
-   Solver: invalid key raises compile-time error


<a id="org83c4073"></a>

### Stratification (~5)

-   Stratification: non-negated program = single stratum (trivial)
-   Stratification: negated program with valid stratification compiles
-   Stratification: cyclic negation detected and rejected at compile time
-   Error messages: undefined relation, arity mismatch
-   Performance: 100-fact database, recursive query


<a id="orgf27b500"></a>

## 7.11 Dependencies

-   ALL previous phases (Lattice, Cells, LVars, UF, ATMS, Tabling)

&#x2014;


<a id="org386a244"></a>

# Phase Summary

| Phase | Name                        | New AST | New Files | New Tests | Deps      | Size   | Status |
|----- |--------------------------- |------- |--------- |--------- |--------- |------ |------ |
| 1     | Lattice + champ-insert-join | 0       | 3         | 25        | None      | Small  | ✅ DONE |
| 2     | Persistent PropNetwork      | 0       | 3         | 60        | Ph 1      | Medium | ✅ DONE |
| 2.5   | BSP Parallel Execution      | 0       | 1         | 18        | Ph 2      | Small  | ✅ DONE |
| 3     | PropNetwork Prologos Type   | 12      | 3         | 50        | Ph 2      | Medium | ✅ DONE |
| 4     | UnionFind                   | 6       | 2         | 30        | None (∥3) | Small  |        |
| 5     | Persistent ATMS             | 10      | 3         | 50        | Ph 3      | Large  |        |
| 6     | Tabling                     | 8       | 3         | 40        | Ph 3,5    | Medium |        |
| 7     | Surface + Solve/Explain     | 21      | 16+       | 110       | All       | Large  |        |
| TOTAL |                             | 57      | 34+       | 383       |           |        |        |

Estimated total: ~57 new AST nodes, ~34+ new files, ~383 new tests.

Key changes from the original design:

-   **Persistent architecture**: All structs are `#:transparent` (not `#:mutable`)
-   **LVars subsumed**: 10 LVar AST nodes eliminated (LVars = network cells)
-   **Phase 2 split**: Racket-level implementation (Phase 2) separated from Prologos type exposure (Phase 3)
-   **Free backtracking**: O(1) via structural sharing (CHAMP maps)
-   **Free snapshots**: Networks are values — keeping a reference IS a snapshot
-   **Per-cell contradiction detection**: `contradicts?` predicate per cell, not in Lattice trait (no trait hierarchies — see DESIGN<sub>PRINCIPLES.org</sub>)
-   **ATMS two-tier mode**: Lazy activation on first `amb` — deterministic programs never pay ATMS overhead
-   **Compile-time stratification**: SCC + negative edge check rejects unstratifiable programs at compile time
-   **Phase 2.5 (BSP)**: Jacobi-iteration scheduler, threshold propagators, parallel executor. Implications threaded through Phases 5-7.
-   **Default-parallel solver**: `solve` dispatches to `default-solver` which uses BSP by default. User-shadowable. Threshold (default 4) ensures small problems run sequentially — zero overhead for simple queries.
-   **Solve/Explain split**: `solve` returns `Seq (Map Keyword Value)` (bare bindings, zero provenance overhead). `explain` returns `Seq (Answer Value)` (bindings + derivation bundled together). Provenance config lives on the solver; `solve` ignores it, `explain` respects it.
-   **Map merge overrides**: `-with` forms accept `{...}` map literals for per-call config overrides. Shallow map merge into the base solver. Unambiguous parse (`{...}` is always a single syntactic unit).

&#x2014;


<a id="org95d5a07"></a>

# Interaction with Existing Infrastructure


<a id="org27dca65"></a>

## Metavar System

The current metavar system (`current-meta-store`, `save/restore-meta-state!`) is *not* replaced by Phase 2's propagator network. The elaborator continues to use its existing metavar system for type inference. The propagator network is a *separate, parallel* system used by the logic engine at runtime.

The persistent PropNetwork architecture was directly motivated by the `save/restore-meta-state!` problem: the metavar store requires O(n) deep copies for speculative type checking, and restore requires explicit undo. The persistent approach avoids this entirely — backtracking is O(1) (keep old reference). In the future (post-Phase 7), the elaborator's metavar system could be refactored to use propagator cells internally.


<a id="org63ef183"></a>

## Trait System

The `Lattice` trait (Phase 1) uses the existing trait infrastructure with no modifications. Lattice instances resolve via `resolve-trait-constraints!` like any other trait.


<a id="org1becdd8"></a>

## Spec Metadata

Phase 6 adds `:tabled` and `:answer-mode` to `parse-spec-metadata`. This follows the same pattern as `:examples` (Stage C of Extended Spec Hardening): explicit case in the metadata parser using `collect-constraint-values` or direct value capture.


<a id="org5610ad7"></a>

## Warnings

The logic engine may emit new warning types (e.g., "tabled predicate exceeded table size limit", "negation in unstratifiable position"). These follow the `warnings.rkt` pattern: new struct + parameter + emit/format.


<a id="org7e88606"></a>

## QTT / Multiplicities

Logic variables live at multiplicity `:w` (unrestricted). They are shared across multiple goals and clauses. The binding environment (the substitution store) is functional/persistent and does not consume resources linearly.

Open question: should cells be linear (`:1`)? A cell created and consumed exactly once (write, then read, then discard) could be linear. For now, cells are unrestricted (`:w`).


<a id="org10fd3c5"></a>

## Collections

The entire propagator network is backed by CHAMP maps (`champ.rkt`):

-   `cells` map: `cell-id → prop-cell`
-   `propagators` map: `prop-id → propagator`
-   `merge-fns` map: `cell-id → merge-fn`
-   ATMS `assumptions`, `tms-cells`, `believed`: all CHAMP maps
-   Table stores: CHAMP map of table entries

The `champ-insert-join` helper (added in Phase 1) enables lattice-aware insert-with-merge at the CHAMP level. SetLattice cells use `set-union` as their merge function. MapLattice cells use `merge-with join`.

No separate LVar-Set or LVar-Map types are needed — these are simply cells in a PropNetwork with appropriate merge functions.

&#x2014;


<a id="org87d675f"></a>

# Appendix A: Resolution by Example — `ancestor` as Propagators

This appendix shows the complete elaboration of a `defr` definition into propagator network operations. It bridges the gap between the surface syntax (Phase 7) and the propagator substrate (Phases 2-6).


<a id="orgb2ba45e"></a>

## A.1 Source Program

```prologos
schema ParentChild
  :parent String
  :child  String

;; Facts (using || fact block)
defr parent : ParentChild
  || "alice" "bob"
     "bob"   "carol"
     "bob"   "dave"

;; Recursive relation (tabled by default)
defr ancestor [?x ?y]
  &> (parent x y)                        ;; clause 1: base case
  &> (parent x z) (ancestor z y)         ;; clause 2: recursive
```


<a id="org5b63781"></a>

## A.2 Step 1: Table Creation

`ancestor` is tabled by default. The elaborator:

1.  Creates a table entry in the `table-store` index: `(table-entry 'ancestor <call-pattern> cell-42 'active)`
2.  Creates a PropNetwork cell for the table's answer set: `(net-new-cell net 'empty-set set-union)` → `cell-42`
3.  The cell's merge function is `set-union` (`SetLattice`) — answers accumulate.


<a id="org567fbb3"></a>

## A.3 Step 2: Clause 1 → Producer Propagator

Clause 1: `&> (parent x y)` (base case)

The elaborator creates a propagator that:

```racket
;; Clause-1 fire-fn for ancestor(x, y):
;;   For each parent fact matching (x, y), write to ancestor's table cell
(define (make-ancestor-clause1-fire-fn table-cell-id)
  (lambda (net)
    ;; For each fact in parent's table:
    (define parent-answers
      (net-cell-read net parent-table-cell-id))
    ;; Each parent answer is an ancestor answer (base case)
    ;; Write each to the ancestor table cell
    (for/fold ([net* net])
              ([ans (in-set parent-answers)])
      (net-cell-write net* table-cell-id
                      (set-add (set) ans)))))
```

Inputs: `parent`'s table cell. Outputs: `ancestor`'s table cell.


<a id="org17ee63d"></a>

## A.4 Step 3: Clause 2 → Producer Propagator

Clause 2: `&> (parent x z) (ancestor z y)` (recursive case)

This creates a propagator that:

```racket
;; Clause-2 fire-fn for ancestor(x, y):
;;   Join parent(x, z) with ancestor(z, y) → ancestor(x, y)
(define (make-ancestor-clause2-fire-fn table-cell-id)
  (lambda (net)
    (define parent-facts (net-cell-read net parent-table-cell-id))
    (define ancestor-facts (net-cell-read net table-cell-id))
    ;; For each parent(x, z) and ancestor(z, y), derive ancestor(x, y)
    (define new-answers
      (for*/set ([p (in-set parent-facts)]
                 [a (in-set ancestor-facts)]
                 #:when (equal? (subst-lookup p '?y)    ;; z in parent
                                (subst-lookup a '?x)))  ;; z in ancestor
        (make-subst '?x (subst-lookup p '?x)
                    '?y (subst-lookup a '?y))))
    (net-cell-write net table-cell-id new-answers)))
```

Inputs: `parent`'s table cell AND `ancestor`'s table cell (self-reference!). Outputs: `ancestor`'s table cell.

The self-reference is what makes tabling essential: the propagator reads from the cell it writes to. Tabling ensures this reaches a fixed point rather than looping infinitely.


<a id="orgb05ed58"></a>

## A.5 Step 4: Run to Quiescence

```
Iteration 1:
  parent table cell = {(alice,bob), (bob,carol), (bob,dave)}
  clause-1 fires → ancestor cell ∪= {(alice,bob), (bob,carol), (bob,dave)}
  clause-2 fires → join parent × ancestor:
    parent(alice,bob) ∧ ancestor(bob,carol) → ancestor(alice,carol)
    parent(alice,bob) ∧ ancestor(bob,dave) → ancestor(alice,dave)
  ancestor cell ∪= {(alice,carol), (alice,dave)}

Iteration 2:
  clause-2 fires again (ancestor cell grew):
    parent(alice,bob) ∧ ancestor(bob,carol) → ancestor(alice,carol) — already present
    parent(alice,bob) ∧ ancestor(bob,dave) → ancestor(alice,dave) — already present
    No new answers added.

Quiescence reached. ancestor cell = {(alice,bob), (bob,carol), (bob,dave),
                                      (alice,carol), (alice,dave)}
```


<a id="orga4498e0"></a>

## A.6 Step 5: Answer Extraction

A query `(solve (ancestor "alice" who))` reads the ancestor table cell, filters for entries where `x = "alice"`, and projects the `y` values:

```
Results: who ∈ {"bob", "carol", "dave"}
```

&#x2014;


<a id="orgffbd5a2"></a>

# Appendix B: End-to-End Query Walkthrough (All Three Layers)

This appendix shows a single query that exercises all three layers of the architecture: PropNetwork (Layer 1), ATMS (Layer 2), and Stratification (Layer 3).


<a id="orgc9790cc"></a>

## B.1 Source Program

```prologos
defr edge [?from ?to]
  || "a" "b"
     "b" "c"
     "a" "c"

defr reachable [?x ?y]
  &> (edge x y)
  &> (edge x z) (reachable z y)

;; Negation triggers stratification (Layer 3)
defr unreachable [?x ?y]
  &> (node x) (node y) (not (reachable x y))

;; Query with nondeterminism (triggers ATMS, Layer 2)
;; "Find a node that is unreachable from 'a'"
let result := (solve (unreachable "a" target))
```


<a id="orge7b5651"></a>

## B.2 Compile-Time: Stratification Check

The predicate dependency graph:

```
edge         (no deps)         → Stratum 0
reachable    → edge (+)        → Stratum 0 (same SCC, all positive)
node         (no deps)         → Stratum 0
unreachable  → reachable (−)   → Stratum 1 (negative edge crosses strata)
```

The stratification checker (§7.6) verifies: the negative edge `unreachable --not--> reachable` crosses from Stratum 1 to Stratum 0 — safe.


<a id="org8378108"></a>

## B.3 Runtime: Layer 1 — PropNetwork (Stratum 0)

Evaluate `edge`, `reachable`, and `node` to fixed point:

```
1. edge table cell:
   {(a,b), (b,c), (a,c)}

2. reachable table cell (iterate to fixpoint):
   Iteration 1: {(a,b), (b,c), (a,c)} — from edge base case
   Iteration 2: {(a,b), (b,c), (a,c), (a,c)} — (a,b)+(b,c)→(a,c), already present
   Fixpoint: {(a,b), (b,c), (a,c)}

3. node table cell (derived from edge endpoints):
   {a, b, c}
```

All purely monotonic. No ATMS overhead. Layer 1 only.


<a id="org09efae6"></a>

## B.4 Runtime: Layer 3 — Stratum Boundary

Stratum 0 is complete. Now the runtime evaluates Stratum 1.

`unreachable` uses `not (reachable x y)`. This reads the *frozen* reachable table from Stratum 0:

```
For each pair (x, y) in node × node:
  (a, a): reachable(a, a) = not found → unreachable(a, a) ✓
  (a, b): reachable(a, b) = found → skip
  (a, c): reachable(a, c) = found → skip
  (b, a): reachable(b, a) = not found → unreachable(b, a) ✓
  (b, b): reachable(b, b) = not found → unreachable(b, b) ✓
  (b, c): reachable(b, c) = found → skip
  (c, a): reachable(c, a) = not found → unreachable(c, a) ✓
  (c, b): reachable(c, b) = not found → unreachable(c, b) ✓
  (c, c): reachable(c, c) = not found → unreachable(c, c) ✓
```


<a id="orge5091de"></a>

## B.5 Runtime: Layer 2 — ATMS (if needed)

In this example, the query is deterministic (no `amb`). Under the two-tier mode (§5.5), the solver stays in Tier 1 (PropNetwork only) — no ATMS overhead.

If we modified the program to include a choice point:

```prologos
;; "Pick a starting node and find what's unreachable from it"
defr mystery-query [?start ?target]
  &> (node start) (unreachable start target)
```

Now `node start` produces 3 alternatives → `amb` activates, upgrading to Tier 2 (full ATMS):

```
Hypothesis h1: start = "a"
  → unreachable("a", target) under h1
  → Answers: {(a,a)} under h1

Hypothesis h2: start = "b"
  → unreachable("b", target) under h2
  → Answers: {(b,a), (b,b)} under h2

Hypothesis h3: start = "c"
  → unreachable("c", target) under h3
  → Answers: {(c,a), (c,b), (c,c)} under h3

All hypotheses are consistent (no nogoods).
Final answers: union of all worldviews.
```


<a id="org232af21"></a>

## B.6 Summary: Which Layer Handles What

| Query Aspect                   | Layer Used        | Phase  |
|------------------------------ |----------------- |------ |
| `edge`, `reachable` tables     | 1: PropNetwork    | Ph 2,6 |
| `not (reachable ...)`          | 3: Stratification | Ph 7   |
| Stratum evaluation order       | 3: Stratification | Ph 7   |
| `node ?start` choice points    | 2: ATMS           | Ph 5   |
| Backtracking on contradictions | 2: ATMS           | Ph 5   |
| Table answer accumulation      | 1: PropNetwork    | Ph 2,6 |

&#x2014;


<a id="org3d38bc9"></a>

# Performance Expectations


<a id="org8432cca"></a>

## Cost Model

The persistent architecture adds a constant factor vs. mutable implementations. Here are the expected costs for each operation:

| Operation              | Cost (Persistent)       | Cost (Mutable)   | Ratio        |
|---------------------- |----------------------- |---------------- |------------ |
| Cell read              | O(log₃₂ n) ≈ O(C), C≤7  | O(1) hash lookup | ~3x          |
| Cell write (no change) | O(log₃₂ n) comparison   | O(1)             | ~3x          |
| Cell write (changed)   | O(log₃₂ n) + alloc path | O(1)             | ~5x          |
| Add propagator         | O(log₃₂ n) × inputs     | O(1) × inputs    | ~3-5x        |
| Backtrack              | O(1) — keep old ref     | O(n) — deep copy | 100x+ better |
| Snapshot               | O(1) — identity         | O(n) — deep copy | 100x+ better |
| run-to-quiescence      | O(k × log₃₂ n) per step | O(k) per step    | ~3-5x        |

Where:

-   n = number of cells in the network (typically 100-10,000)
-   k = number of propagator firings to quiescence
-   log₃₂(10,000) ≈ 2.7 — so the "constant" is truly small


<a id="orgcca3680"></a>

## Benchmark Targets (to validate during implementation)

| Benchmark                              | Target      | Validates     |
|-------------------------------------- |----------- |------------- |
| Create 1000-cell network               | < 50ms      | CHAMP scaling |
| Write 1000 values, run to quiescence   | < 200ms     | Propagation   |
| Backtrack 100 times over 1000-cell net | < 1ms total | Persistence   |
| 100-fact ancestor query (tabled)       | < 100ms     | Tabling       |
| 1000-fact Datalog transitive closure   | < 500ms     | Scalability   |
| `solve` with 100 alternatives (ATMS)   | < 1s        | ATMS overhead |
| Same 100 alternatives, Tier 1 only     | < 200ms     | Two-tier skip |

These targets are order-of-magnitude estimates. Actual benchmarks will be added to `tools/benchmark-tests.rkt` as each phase is implemented. The key comparison is: persistent overhead vs. backtracking savings. For any program with search (>1 choice point), the persistent approach wins because each backtrack is O(1) instead of O(n) deep copy.


<a id="orgb525003"></a>

## When Performance Matters Most

For the logic engine's intended use cases:

-   **Type checking**: The elaborator's current metavar system is fast for deterministic type inference. The PropNetwork adds overhead here. The elaborator refactoring (post-Phase 7) should only proceed after benchmarking confirms acceptable overhead.
-   **Logic queries**: Search-heavy programs (Prolog-style) benefit enormously from free backtracking. The persistent overhead is amortized over the many backtracks avoided.
-   **Datalog**: Bottom-up evaluation with tabling is inherently monotonic — no backtracking needed. Performance depends on propagation efficiency and set operations.

&#x2014;


<a id="org8f922c4"></a>

# What This Design Does NOT Cover


<a id="org583eba7"></a>

## Elaborator Refactoring (Phase 1 of Research Doc)

Refactoring `current-meta-store` to use a persistent PropNetwork internally is recommended by the research document but deferred. The persistent network architecture makes this refactoring simpler: replace the mutable meta store with a PropNetwork value threaded through elaboration. But it is still a large internal change that can proceed independently after the logic engine exists.


<a id="org444bd3e"></a>

## Galois Connections / Domain Embeddings (Phase 6 of Research Doc)

Modular constraint domains connected via Galois connections are an advanced feature deferred until the basic engine is operational.


<a id="org62b069c"></a>

## Full Stratified Evaluation Runtime (Phase 4 of Research Doc)

Phase 7 includes a compile-time stratification *check* (§7.6): SCC decomposition, negative edge classification, and rejection of unstratifiable programs. The runtime evaluation of strata (evaluating lower strata to fixpoint before proceeding to higher strata) is also included as part of the solver's query evaluation loop. Full support for aggregation operators (`count`, `min`, `max`, `sum`) between strata is deferred to a follow-up phase.


<a id="orgcffa97b"></a>

## CRDTs / Distributed Logic

CRDT-backed collections for distributed actors are long-term goals not addressed here.


<a id="orgfea50ae"></a>

## QuickCheck / Property Testing

Executing `:holds` clauses and `:examples` entries requires the logic engine (for proof search). Once the engine exists, this becomes a natural Phase 2 of the Extended Spec Design.

&#x2014;


<a id="org2297b9a"></a>

# Architectural Decision: Persistent Networks


<a id="org3adb2ff"></a>

## The Problem with Mutable Propagator Networks

The original design proposed mutable Racket structs for PropCell, PropNetwork, TMSCell, and ATMS. This creates the same save/restore problem that plagues the current metavar store:

-   **Snapshotting** requires deep copies — O(n) for n cells
-   **Backtracking** requires explicit undo — O(mutations) to restore
-   **Network mobility** requires serialization — custom ser/deser code
-   **Debugging** is harder — state is invisible without explicit inspection


<a id="org8a34dde"></a>

## The Persistent Solution

Making the entire network a persistent value backed by CHAMP maps:

-   **Snapshotting** = free (keep a reference — structural sharing)
-   **Backtracking** = O(1) (use old reference)
-   **Network mobility** = serialize the value (all data is in the struct)
-   **Debugging** = the network IS the state (print it, compare it)
-   **Cost**: O(log₃₂ n) per cell write instead of O(1)

Since log₃₂(n) ≤ 7 for any practical n (up to ~34 billion cells), the cost is bounded by a small constant. For the typical logic engine workload (hundreds to thousands of cells), this is 2-3 levels of CHAMP trie traversal — effectively O(1).


<a id="orge2e673c"></a>

## LVar Elimination

A further simplification: LVars are subsumed by PropNetwork cells. An LVar is just a cell-id in a persistent prop-network, since `net-cell-write` already does join-on-write (inflationary) via the per-cell `merge-fn`. This eliminates ~10 dedicated LVar AST nodes and the separate `lvar.rkt` module.

| Before                            | After                             |
|--------------------------------- |--------------------------------- |
| 61 AST                            | 51 AST                            |
| 32 files                          | 27+ files                         |
| Separate LVar, LVar-Set, LVar-Map | Cells with SetLattice, MapLattice |
| Mutable cells + scheduler         | Persistent network, pure loop     |
| `save/restore` for backtracking   | Keep old reference                |

&#x2014;


<a id="org7fdffc0"></a>

# Key Lessons from Prior Work

(Gathered from CLAUDE.md MEMORY and implementation experience)

1.  **12+ file pipeline for new AST nodes** — every new `expr-*` touches syntax.rkt, typing-core.rkt, reduction.rkt, elaborator.rkt, zonk.rkt, pretty-print.rkt, qtt.rkt, substitution.rkt, unify.rkt, + tests.

2.  **Per-command parameter isolation** — all runtime state (meta stores, warning accumulators, table stores) must be parameterized and reset per-command in `driver.rkt`.

3.  **Trait dictionary dispatch** — single-method traits: dict IS the function. Multi-method: nested Sigma. Dict names: `TypeArg--TraitName--dict`.

4.  **`collect-constraint-values`** — the right collector for list-valued metadata like `:examples`, `:laws`, `:tabled`.

5.  **Generic `rewrite-implicit-map` branch** — WS-mode keyword blocks need to call `rewrite-implicit-map` at dispatch. The property/functor bugs taught this lesson.

6.  **Transient pattern** — generic wrappers (`expr-transient`, `expr-persist`)
    -   type-specific variants. Follow this for cell/lvar generics.

7.  **Test file size** — keep under ~20 cases / ~30s for parallel execution. Split large test files into -01, -02 parts.

8.  **Update dep-graph.rkt** — every new .rkt file needs an entry in `tools/dep-graph.rkt` for incremental testing to work.

&#x2014;


<a id="orgd04e4cf"></a>

# References

Organized by phase relevance:


<a id="org1c4eabd"></a>

## Phase 1 (Lattice)

-   Cousot & Cousot, "Abstract Interpretation: A Unified Lattice Model" (POPL, 1977)
-   Tarski, "A Lattice-Theoretical Fixpoint Theorem" (Pacific J. Math., 1955)


<a id="org183b14d"></a>

## Phase 2 (Propagators)

-   Radul & Sussman, "The Art of the Propagator" (MIT TR, 2009)
-   Radul, *Propagation Networks* (PhD thesis, MIT, 2009)
-   Hellerstein, "Keeping CALM" (CACM, 2020)


<a id="orga01deb5"></a>

## Phase 3 (LVars)

-   Kuper & Newton, "LVars: Lattice-Based Data Structures for Deterministic Parallelism" (FHPC, 2013)
-   Kuper et al., "Freeze After Writing" (POPL, 2014)


<a id="org83feb69"></a>

## Phase 4 (UnionFind)

-   Conchon & Filliâtre, "A Persistent Union-Find Data Structure" (ML Workshop, 2007)


<a id="org5c37e4b"></a>

## Phase 5 (ATMS)

-   de Kleer, "An Assumption-Based TMS" (AI Journal, 1986)


<a id="org08bcd06"></a>

## Phase 6 (Tabling)

-   Swift & Warren, "XSB: Extending Prolog with Tabled Logic Programming" (TPLP, 2012)
-   Chen & Warren, "Tabled Evaluation with Delaying" (JACM, 1996)
-   Madsen et al., "From Datalog to Flix" (PLDI, 2016)


<a id="orga1de54e"></a>

## Phase 7 (Surface)

-   Arntzenius & Krishnaswami, "Datafun: A Functional Datalog" (ICFP, 2016)
-   Fruhwirth, *Constraint Handling Rules* (CUP, 2009)
