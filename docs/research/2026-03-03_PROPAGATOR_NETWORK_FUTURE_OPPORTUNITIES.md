# Propagator Networks: Future Opportunities Research

**Date**: 2026-03-03
**Status**: Deep Research Complete
**Scope**: Advanced applications of lattice-based propagator networks with Galois connections
**Context**: Prologos's Logic Engine (LE) already implements persistent propagator networks,
ATMS, union-find, tabling, Galois connections, and widenable lattices. This research explores
future domains to which this infrastructure may be applied.

---

## Table of Contents

- [1. Abstract Interpretation via Propagator Networks](#1-abstract-interpretation)
- [2. Theorem Proving: ATMS Meets Abstract CDCL](#2-theorem-proving)
- [3. Constraint Solving: Finite Domains, Reals, and Beyond](#3-constraint-solving)
- [4. Session Types as Lattice Constraints](#4-session-types)
- [5. Actor Model Subsumption and OTP-Style Supervision](#5-actor-model)
- [6. Multi-Agent Distributed Propagation](#6-multi-agent)
- [7. Testing and Debugging via Provenance](#7-testing-debugging)
- [8. Novel Applications: Incremental Compilation, Live Programming, Solver-Aided Design](#8-novel-applications)
- [9. Cross-Cutting Synthesis: Combinations That Create New Capabilities](#9-synthesis)
- [10. References](#10-references)

---

<a id="1-abstract-interpretation"></a>

## 1. Abstract Interpretation via Propagator Networks

### 1.1 Background

Abstract interpretation (Cousot & Cousot, 1977) is the theory of computing sound
approximations of program behavior over abstract domains. The core structure:

- **Concrete domain** C: the actual semantics (e.g., all possible values at each program point)
- **Abstract domain** A: an approximation (e.g., sign, interval, pointer alias set)
- **Galois connection** (alpha, gamma): a pair of monotone functions
  `alpha: C -> A` (abstraction) and `gamma: A -> C` (concretization) satisfying
  `alpha(gamma(a)) <= a` and `c <= gamma(alpha(c))`
- **Fixpoint computation**: iterate abstract transfer functions to a fixed point

The key theorem: if the abstract transfer function is a sound approximation of the
concrete transfer function (connected via the Galois connection), then the abstract
fixpoint over-approximates the concrete collecting semantics.

### 1.2 The Mapping to Prologos

This mapping is remarkably direct. Prologos already has every piece:

| Abstract Interpretation | Prologos LE |
|------------------------|-------------|
| Abstract domain A | `Lattice` trait instance |
| Concrete domain C | Another `Lattice` trait instance |
| Galois connection (alpha, gamma) | `GaloisConnection {C A}` trait (Phase 6b) |
| Transfer function | Propagator fire-fn |
| Fixpoint iteration | `run-to-quiescence` |
| Widening for infinite domains | `Widenable` trait + `run-to-quiescence-widen` (Phase 6a) |
| Reduced product (combining domains) | Cross-domain propagators (Phase 6c) |
| Collecting semantics | `SetLattice A` instance |

A propagator-based abstract interpreter is: a network where each program point has
a cell holding an abstract value, each program statement is a propagator computing
transfer functions, and `run-to-quiescence` computes the analysis fixpoint.

### 1.3 What It Would Look Like in Prologos

```prologos
;; An abstract domain for sign analysis
type Sign := Bot | Neg | Zero | Pos | NonNeg | NonPos | Top

impl Lattice Sign where
  bot = Bot
  join = sign-join
  leq = sign-leq

;; Galois connection: Interval -> Sign
impl GaloisConnection Interval Sign where
  alpha iv = interval-to-sign iv
  gamma s  = sign-to-interval s

;; Building an analysis:
;; 1. Create cells for each program point
;; 2. Create propagators for each statement (transfer functions)
;; 3. Cross-domain propagators between Interval and Sign cells
;; 4. run-to-quiescence computes the fixpoint over BOTH domains simultaneously
```

### 1.4 Key Benefits

1. **Modular domain composition**: Adding a new analysis domain (parity, pointer aliasing,
   string length bounds) is just defining a `Lattice` instance and wiring Galois connections
   to existing domains. The reduced product is automatic.

2. **Parallel analysis**: The BSP scheduler parallelizes fixpoint iteration. Traditional
   abstract interpreters use sequential worklist algorithms; Prologos gets Jacobi-parallel
   iteration for free.

3. **Speculative refinement via ATMS**: Try a coarse domain first; if too imprecise, refine.
   The ATMS enables branching on analysis precision without recomputing from scratch.

4. **Widening is built-in**: The `Widenable` trait + two-phase fixpoint
   (`run-to-quiescence-widen`) handles infinite-height domains like intervals. The
   implementation already exists (Phase 6a-6e).

### 1.5 Concrete Opportunities for Prologos

- **Nullability analysis**: `FlatLattice (Nullable | NonNull | Bot | Top)` domain with
  Galois connection to the type domain. Detects potential nil-pointer uses at compile time.
- **Capability bound analysis**: Use `IntervalLattice` to track "how many times is this
  capability exercised?" Detect unused authorities or excessive authority use.
- **Termination analysis**: Use an ordinal-valued lattice to track recursive call depths.
  Galois connection from program structure to ordinal bounds.

### 1.6 Key Papers

- Cousot & Cousot, "Abstract Interpretation: A Unified Lattice Model for Static Analysis" (POPL 1977)
- Cousot & Cousot, "A Galois Connection Calculus for Abstract Interpretation" (POPL 2014)
- Darais & Van Horn, "Constructive Galois Connections: Taming the Galois Connection Framework
  for Mechanized Metatheory" (ICFP 2016, JFP 2018) — Shows useful Galois connections are
  computable and can be mechanized in dependently-typed languages
- Madsen, Yee, Lhotak, "From Datalog to Flix: A Declarative Language for Fixed Points on
  Lattices" (PLDI 2016) — Extends Datalog with lattice values; 15x speedup over pure Datalog
- Arntzenius & Krishnaswami, "Datafun: A Functional Datalog" (ICFP 2016) — Semilattice types
  with monotonicity tracking; directly relevant to Prologos's `Lattice` trait design

---

<a id="2-theorem-proving"></a>

## 2. Theorem Proving: ATMS Meets Abstract CDCL

### 2.1 The CDCL Connection

Modern SAT/SMT solvers use CDCL (Conflict-Driven Clause Learning), which consists of:

1. **Decision**: Choose an unassigned variable and assign it (assumption)
2. **Unit propagation**: Deduce forced assignments from clauses (propagation)
3. **Conflict analysis**: When contradiction found, learn a conflict clause (nogood)
4. **Non-chronological backjumping**: Jump back to the most relevant decision level

The ATMS in Prologos already implements these concepts:

| CDCL Concept | ATMS/Propagator Equivalent |
|-------------|---------------------------|
| Decision literal | `atms-assume` (new assumption) |
| Unit propagation | `run-to-quiescence` (propagator firing) |
| Conflict clause | `atms-add-nogood` (inconsistent assumption set) |
| Non-chronological backjump | Dependency-directed backtracking (ATMS tracks which assumptions caused which values) |
| Theory solver T | Domain-specific propagators |
| Learned clause | New propagator encoding the nogood |

### 2.2 Abstract CDCL (ACDCL)

D'Silva, Kroening, et al. at Oxford/Microsoft Research have shown that CDCL can be
**lifted from the Boolean lattice to arbitrary lattice-based abstract domains**. The
insight: model search (decisions) is over-approximate deduction, and conflict analysis
is under-approximate abduction. Both are lattice operations.

This is directly applicable to Prologos: the LE already operates over arbitrary lattices
via the `Lattice` trait. Abstract CDCL means Prologos could implement a theorem prover
where:

- Variables are cells in any lattice domain
- Clauses are propagators
- Conflict analysis uses ATMS dependency chains
- Learned clauses become new propagators (persistent, enriching future iterations)

### 2.3 Lazy Clause Generation

Stuckey et al. (CP 2007) showed that finite domain propagators can be treated as
clause generators for a SAT solver. Rather than statically compiling constraints to SAT,
the Boolean representation is built lazily: when a propagator fires and narrows a cell,
it generates an explanatory clause.

In Prologos, the ATMS justification mechanism IS this lazy clause generation. When a
propagator fires and writes to a cell, the ATMS records the justification (which
assumptions and which previous cell values justified this write). These justifications
ARE the lazily generated clauses.

### 2.4 What It Would Look Like

```prologos
;; Theorem prover as a propagator network
;; Each formula variable is a cell, each clause is a propagator

defn prove-sat [clauses]
  let net := [new-prop-network 10000N]
  ;; Create cells for variables
  let [net2 cells] := [create-var-cells net clauses]
  ;; Create propagators for clauses (unit propagation)
  let net3 := [add-clause-propagators net2 clauses cells]
  ;; ATMS manages decisions, nogoods, and backtracking
  let atms := [atms-new net3]
  ;; Search: make decisions, propagate, learn from conflicts
  [atms-solve-all atms]
```

### 2.5 Concrete Opportunities

- **Type-level theorem proving**: Prove properties about types (e.g., "this function
  always returns a non-empty list"). The type lattice is the domain; type constraints
  are propagators; the ATMS searches for a consistent assignment.
- **Capability verification**: Prove that a program's capability requirements are
  satisfied. The capability lattice + ATMS search = automated capability verification.
- **Editor-connected backend**: IDE sends proof obligations; Prologos LE solves them
  using ACDCL; results flow back with derivation chains for display.

### 2.6 Key Papers

- D'Silva et al., "Abstract Conflict Driven Learning" (SAS 2013) — CDCL over lattices
- D'Silva et al., "Lifting CDCL to Template-Based Abstract Domains for Program
  Verification" (SAS 2017)
- Duck, "SMCHR: Satisfiability Modulo Constraint Handling Rules" (TPLP 2012) — CHR rules
  as SMT theory solvers; goals are quantifier-free formulae over CHR constraints
- Holmes (Haskell library) — Reference implementation combining propagators + CDCL
- Stuckey et al., "Propagation = Lazy Clause Generation" (CP 2007) — Propagator firings
  generate explanatory clauses for SAT solver
- de Kleer, "An Assumption-Based TMS" (AI Journal, 1986) — The ATMS foundation

---

<a id="3-constraint-solving"></a>

## 3. Constraint Solving: Finite Domains, Reals, and Beyond

### 3.1 Finite Domain Constraint Propagation

Traditional finite domain CP solvers (Gecode, CHR, Choco) ARE propagator networks:
variables have domains (lattice of subsets), propagators narrow domains by removing
infeasible values, a worklist schedules propagator execution.

Prologos's propagator network has the same architecture but with a different state model:

| Traditional CP | Prologos LE |
|----------------|-------------|
| Mutable domains, trail-based undo | Persistent cells, O(1) backtrack |
| Propagators narrow domains (remove values) | Propagators monotonically increase lattice values |
| Search = depth-first + trail | Search = ATMS worldview branching |
| Global mutable constraint store | Network is a persistent value |

### 3.2 The Persistent Advantage

Prologos's persistent/immutable design gives significant advantages for constraint solving:

1. **O(1) backtracking**: Traditional CP pays O(trail-length) per backtrack. Prologos
   keeps the old network reference — structural sharing makes this free.

2. **Parallel search**: Fork the network value and explore multiple branches concurrently.
   Each branch operates on its own persistent copy. No locking, no trail synchronization.

3. **Constraint learning survives branches**: A nogood learned in one ATMS branch is
   visible to all branches (the ATMS is shared). This is more powerful than traditional
   CP's clause learning.

4. **Mixed-domain solving**: Combine FD constraints (powerset lattice), interval constraints
   (interval lattice), type constraints (type lattice), and capability constraints (cap-set
   lattice) in a single network. Galois connections handle cross-domain information flow.

### 3.3 Interval Constraint Propagation

Constraints over real numbers use interval arithmetic with hull consistency. The
"contractor programming" paradigm (Chabert & Jaulin) treats constraint propagators as
"contractors" that narrow interval domains.

Prologos already has `IntervalLattice` and `Widenable`. Interval constraint propagation
is: define contractors as propagators, run to quiescence with widening for convergence.

### 3.4 What It Would Look Like

```prologos
;; Finite domain constraint solving
type FiniteDomain := FD (Set Nat)

impl Lattice FiniteDomain where
  bot = [FD [set-empty]]
  join [FD a] [FD b] = [FD [set-union a b]]
  leq [FD a] [FD b] = [set-subset? a b]

;; Sudoku: 81 cells, each domain {1..9}
;; all-different constraint generates propagators
;; solve via ATMS assumption branching

;; Interval constraints over reals
;; x^2 + y^2 <= 1 (unit circle)
;; Uses IntervalLattice + Widenable for convergence
```

### 3.5 User-Defined Constraint Domains

Because `Lattice` is a trait, Prologos users can define their own constraint domains
and propagators at the library level. This is unprecedented — in Gecode or MiniZinc,
adding a new domain requires C++ implementation. In Prologos, it's a trait instance:

```prologos
;; User-defined abstract domain for string length bounds
type StringBound := SB Nat Nat  ;; min, max

impl Lattice StringBound where
  bot = [SB 0N inf]
  join [SB lo1 hi1] [SB lo2 hi2] = [SB [min lo1 lo2] [max hi1 hi2]]
  leq [SB lo1 hi1] [SB lo2 hi2] = [and [le lo2 lo1] [le hi1 hi2]]
```

### 3.6 Key Papers

- Schulte & Stuckey, "Efficient Constraint Propagation Engines" (TOPLAS 2008) — Gecode's
  propagator architecture; formalizes propagator correctness as monotone, contracting,
  idempotent functions
- Fruhwirth, "Constraint Handling Rules" (1994) — Declarative constraint solver language;
  simplification, propagation, and simpagation rules
- Chabert & Jaulin, "Contractor Programming" (Artificial Intelligence, 2009) — Interval
  narrowing operators with set-theoretic combinators
- Stuckey et al., Chuffed solver — Lazy clause generation for FD constraint solving

---

<a id="4-session-types"></a>

## 4. Session Types as Lattice Constraints

### 4.1 The Curry-Howard Connection

Caires & Pfenning (CONCUR 2010) established a Curry-Howard correspondence between
session types and intuitionistic linear logic:

| Linear Logic | Session Types |
|-------------|---------------|
| Proposition A | Session type S |
| Cut rule | Parallel composition |
| Cut elimination | Communication (send/receive) |
| Identity | Channel forwarding |
| Tensor (A * B) | Send A, then continue as B |
| Lolli (A -o B) | Receive A, then continue as B |
| Plus (A + B) | Internal choice (select) |
| With (A & B) | External choice (offer/branch) |
| Bang (!A) | Reusable server (unlimited sessions) |

Linear logic's resource sensitivity (each hypothesis used exactly once) corresponds to
session types' guarantee that each channel endpoint follows its protocol exactly.

### 4.2 Session Types as Lattice Values

Session types form a lattice under the subtyping relation:

```
   top (any protocol)
    |
  S1 + S2 (choice: S1 or S2)
   / \
  S1   S2
   \ /
  S1 & S2 (must handle both)
    |
   bot (dead protocol)
```

Subtyping: `S1 <: S2` means "any process that follows protocol S1 also follows S2."
For sends: covariant (can send a subtype). For receives: contravariant (must accept
a supertype).

### 4.3 QTT Integration

Prologos already has QTT with multiplicities `{0, 1, omega}`. Session types interact:

- `:1` multiplicity = linear channel (used exactly once in each protocol step)
- `:0` multiplicity = erased type information (protocol type, not a runtime value)
- `:w` multiplicity = shared/reusable channel (corresponds to `!A` in linear logic)

The multiplicity lattice and session type lattice can be connected via Galois connection:
- alpha: session type -> required multiplicity (linear protocol -> :1, shared -> :w)
- gamma: multiplicity constraint -> session type restriction

### 4.4 Session Type Inference as Propagation

Instead of a dedicated session type inference algorithm, session types can be inferred
via propagator network:

1. Each channel endpoint is a cell in the `SessionLattice`
2. Each `send`/`receive` operation is a propagator that constrains the channel cell
3. Duality constraint: client and server channel cells must be duals
   (a bidirectional propagator: `dual(client-type) = server-type`)
4. `run-to-quiescence` infers session types
5. Contradiction = protocol violation (with ATMS derivation chain for error messages)

### 4.5 Refinement Session Types

Toninho & Yoshida (2025) showed that session types with arithmetic refinements
(e.g., "send exactly n messages") can be inferred using Z3 constraints. In Prologos,
this maps to `IntervalLattice` constraints composed with session type constraints via
Galois connections.

### 4.6 What It Would Look Like

```prologos
;; Session type lattice
type SessionStep := Send Type | Recv Type | Choose (List SessionStep)
                  | Offer (List SessionStep) | End | SessionBot | SessionTop

impl Lattice SessionStep where
  bot = SessionBot
  join = session-join  ;; subtyping-based join
  leq = session-subtype

;; Galois connection to multiplicity
impl GaloisConnection SessionStep Multiplicity where
  alpha [Send _] = M1      ;; sending requires linear use
  alpha [Recv _] = M1      ;; receiving requires linear use
  alpha End = M0            ;; ended channel is erased
  gamma M1 = SessionBot     ;; linear -> any session type
  gamma MW = ...            ;; unrestricted -> must be !-prefixed

;; Protocol checking: client and server must be duals
;; Duality propagator connects two session-type cells
```

### 4.7 Key Papers

- Caires & Pfenning, "Session Types as Intuitionistic Linear Propositions" (CONCUR 2010)
- Pfenning & Griffith, "Linear Logic Propositions as Session Types" (MSCS 2013)
- Toninho & Yoshida, "Practical Refinement Session Type Inference" (2025) — Inference via
  Z3 constraints; transitivity elimination; polynomial templates for arithmetic search

---

<a id="5-actor-model"></a>

## 5. Actor Model Subsumption and OTP-Style Supervision

### 5.1 Propagators vs Actors

Radul's PhD thesis (MIT, 2009) established propagator networks as "continuous-time,
general-purpose models for concurrent and distributed computation." The key elements:
autonomous machines (propagators) interconnected by shared cells. Each machine
continuously examines cells and adds information.

The relationship to actors is not "propagators = actors" but rather
"propagators are actors with a monotonicity discipline":

| Dimension | Actor Model | Propagator Model |
|-----------|-------------|------------------|
| Communication | Async messages (arbitrary) | Monotonic writes to shared cells |
| State | Per-actor mutable state | Shared cells accumulate info (lattice join) |
| Determinism | **Non-deterministic** (msg ordering) | **Deterministic** (join is commutative, associative, idempotent) |
| Convergence | No guarantee | Guaranteed (finite lattice = termination) |
| Fault model | Supervision trees, let-it-crash | Contradiction detection + ATMS nogood recording |

The lattice constraint on cell values is what buys determinism — unlike actors, the
order of propagator execution does not affect the final result (confluence).

### 5.2 LVars: The Bridge

Kuper & Newton (FHPC 2013) formalized the connection via LVars (Lattice Variables):
shared mutable variables that only allow monotonic writes and "threshold reads" (block
until a lower bound is reached). This guarantees deterministic parallelism.

Prologos's propagator cells ARE LVars. `net-cell-write` performs lattice join (monotonic
write). Propagators fire when their input cells change (threshold read). Kmett (2016-2019)
blended Radul's propagator model with Kuper's LVars to derive sufficient conditions for
propagator termination, showing that propagators, CRDTs, Datalog, SAT solving, and FRP
all share the same lattice-fixpoint structure.

### 5.3 OTP-Style Supervision via Propagators

Erlang's OTP supervision model maps to propagators:

| OTP Concept | Propagator Equivalent |
|-------------|----------------------|
| Process crash | Cell reaching contradiction (`contradicts?` fires) |
| Exit reason | ATMS dependency chain (WHY the contradiction occurred) |
| Supervisor | Parent network / sub-network boundary |
| one-for-one restart | Re-fire propagators affected by contradiction |
| one-for-all restart | Reset and re-propagate entire sub-network |
| rest-for-one restart | Reset downstream propagators only |
| Max restarts | Fuel limit on sub-network |
| Let it crash | Contradiction detection is "let it crash" — no defensive coding |

**Key advantage over OTP**: The ATMS provides CAUSAL EXPLANATION for failures. OTP gives
you "process X died with reason Y." Propagator ATMS gives you "cell X reached contradiction
BECAUSE assumption A1 (from source S1) and assumption A2 (from source S2) are jointly
inconsistent. Minimum fix: retract A1 or A2."

### 5.4 What a Propagator-Based Service Framework Would Look Like

```prologos
;; Service as a propagator sub-network
;; Requests are cell writes; responses are downstream cell reads
;; Supervision = contradiction handling with ATMS diagnosis

schema service-config
  :max-fuel Nat                ;; max propagator firings per request
  :restart-strategy RestartPolicy  ;; one-for-one, one-for-all, etc.

;; A service cell: holds current service state (lattice value)
;; Incoming requests are monotonic state transitions
;; Contradiction = service failure
;; ATMS records which requests caused which state transitions
;; Supervisor reads contradiction + ATMS chain, decides restart strategy
```

### 5.5 The Non-Monotonic Escape Hatch

Propagators subsume actors for computations that can be expressed as lattice fixpoints.
But some operations are inherently non-monotonic: I/O, user interaction, network
communication, time-dependent behavior. These require an actor-like escape hatch.

Prologos's capability system provides this: I/O operations require linear capabilities
(`:1` multiplicity), which ensures they happen exactly once and in a controlled order.
The propagator network handles the pure, deterministic core; capabilities gate the
non-monotonic boundary.

### 5.6 Key Papers

- Radul, "Propagation Networks: A Flexible and Expressive Substrate for Computation"
  (MIT PhD, 2009)
- Sussman & Radul, "The Art of the Propagator" (MIT TR, 2008) — Argues propagation is
  more fundamental than lambda calculus
- Kuper & Newton, "LVars: Lattice-based Data Structures for Deterministic Parallelism"
  (FHPC 2013)
- Kmett, "Propagators" (FnConf 2019, YOW! 2016) — Unifying propagators, LVars, CRDTs,
  Datalog, SAT, FRP
- Hewitt, "Actor Model of Computation" (1973, extended 2010)

---

<a id="6-multi-agent"></a>

## 6. Multi-Agent Distributed Propagation

### 6.1 From CRDTs to Distributed Propagation

State-based CRDTs (Conflict-Free Replicated Data Types) are join-semilattices with a
merge function that is commutative, associative, and idempotent. This is EXACTLY the
cell merge semantics of Prologos's propagator network.

A distributed propagator network is: the same network partitioned across nodes, where
boundary cells are replicated and synchronized via lattice merge. Because merge is a
semilattice operation, message delivery order doesn't matter — the system achieves
strong eventual consistency by construction.

### 6.2 Concurrent Constraint Programming

Saraswat's Concurrent Constraint Programming (CCP, 1993) formalized this model:
concurrently executing agents communicate by `tell` (add constraint = cell write)
and `ask` (block until constraint entailed = threshold read). The constraint store
is a lattice; `tell` is monotonic join. This is precisely Prologos's cell model.

### 6.3 Distributed Type Checking

In a multi-module compilation, each module's type constraints are a sub-network.
Exported types are boundary cells shared across module boundaries:

1. Module A exports `f : Int -> String` — this is a cell visible to importers
2. Module B imports `f` and uses it — creates propagators constraining `f`'s type
3. If A changes `f`'s type, the cell update propagates to B's sub-network
4. B's propagators re-fire; contradiction = type error across module boundary

This gives incremental, distributed type checking. Only boundary cells need
synchronization; internal module constraints are local.

### 6.4 Multi-Agent Belief Propagation

Multiple agents with different knowledge bases contributing to a shared propagator
network. Each agent's local knowledge is an ATMS assumption set. Cross-agent
communication adds constraints to shared boundary cells.

The ATMS handles conflicting beliefs: if agent A believes X and agent B believes
not-X, the contradiction is recorded as a nogood. The system can explore worldviews
where different agents' beliefs are accepted or rejected.

### 6.5 Distributed Constraint Optimization (DCOPs)

DCOPs partition a constraint satisfaction problem across agents, each owning some
variables. The Max-Sum algorithm (belief propagation on factor graphs) maps directly
to a distributed propagator network where each agent runs local propagation and
shares boundary cell updates.

### 6.6 Key Papers

- Saraswat, "Concurrent Constraint Programming" (MIT Press, 1993) — `tell`/`ask` on
  lattice store = cell write/threshold read
- Shapiro et al., "Conflict-Free Replicated Data Types" (2011) — Join-semilattice
  merge = propagator cell merge
- Fioretto et al., "Distributed Constraint Optimization Problems and Applications: A
  Survey" (JAIR 2018)
- Ma et al., "Multi-Agent Decentralized Belief Propagation on Graphs" (2020)
- Yin et al., "Gaussian Belief Propagation for Multi-Agent Path Planning" (2025)

---

<a id="7-testing-debugging"></a>

## 7. Testing and Debugging via Provenance

### 7.1 The General Diagnostic Engine (GDE)

De Kleer & Williams's GDE (1987) couples constraint propagation with an ATMS for
model-based diagnosis: given a model (constraint network) and observations (expected
behavior), identify which components are faulty by finding minimal assumption sets
whose removal eliminates contradictions.

This applies directly to programming:
- The "system model" is the type/constraint network
- "Components" are type annotations, function signatures, variable bindings
- "Observations" are test assertions
- "Diagnosis" = minimal set of assumptions (code points) that need to change

### 7.2 Provenance-Rich Error Messages

With ATMS-backed type inference, every inferred type has a derivation chain — the set
of assumptions and propagator firings that produced it. Error messages transform from:

```
Type mismatch: expected String, got Int at line 42
```

to:

```
Type mismatch at line 42:
  x was inferred to be Int because:
    - x := 42                      [line 5, assumption A1]
    - propagated through: y = x + 1  [line 6, propagator P3]
    - propagated through: z = y      [line 7, propagator P4]
  f expects String because:
    - spec f : String -> Bool      [line 10, assumption A7]
  Minimal conflict: {A1, A7}
  Suggestion: Change the assignment at line 5 or the spec at line 10
```

### 7.3 Provenance Semirings

Green, Karvounarakis & Tannen (2007) developed a framework for tracking data provenance
using commutative semirings. Provenance polynomials encode HOW inputs combine to produce
outputs. Different semirings answer different questions:

| Semiring | Question |
|----------|----------|
| Boolean | "Was input X used?" (lineage) |
| Natural numbers | "How many derivations use X?" (multiplicity) |
| Why-provenance | "Which inputs justify this output?" (set of witnesses) |
| How-provenance | "How were inputs combined?" (polynomial) |
| Security | "What is the trust level?" (lattice of trust levels) |

In Prologos, propagator firings can be annotated with semiring values. The semiring
composes with the lattice merge to answer provenance questions about any cell value.

### 7.4 Property-Based Test Shrinking via Nogoods

A failing property-based test produces a counterexample: a set of input constraints
that leads to contradiction. The ATMS's nogood mechanism identifies the MINIMAL failing
subset:

- Full input: `{x: 100, y: [1,2,3], z: "hello"}`
- ATMS analysis: the contradiction depends only on `{x: 100}` (assumption A1)
- Minimal counterexample: `{x: 100}` — automatically shrunk

This is more principled than type-based shrinking (QuickCheck, Hypothesis) because it
uses the constraint structure of the actual computation, not domain-specific shrinkers.

### 7.5 Regression Diagnosis

When a code change breaks tests, ATMS dependency chains identify:
1. Which propagators (code paths) were affected by the change
2. Which test assertions depend on those propagators
3. What the minimal "blame set" is (which part of the change caused the failure)

This is incremental testing with causal explanation — qualitatively better than
"these 47 tests failed after your commit."

### 7.6 Key Papers

- de Kleer & Williams, "Diagnosing Multiple Faults" (AI Journal, 1987) — GDE
- Doyle, "A Truth Maintenance System" (AI Journal, 1979) — Justification-based TMS
- Green et al., "Provenance Semirings" (PODS 2007) — Algebraic provenance framework
- de Kleer, "A Comparison of ATMS and CSP Techniques" (1989) — ATMS vs backtracking

---

<a id="8-novel-applications"></a>

## 8. Novel Applications

### 8.1 Bidirectional / Omnidirectional Type Inference

Dunfield & Krishnaswami (ACM Computing Surveys, 2021) survey bidirectional typing:
splitting inference into checking (known type -> term) and synthesis (term -> inferred type).

Leijen (2025) goes further with "Omnidirectional Type Inference for ML": typing constraints
advance dynamically, suspending when information is insufficient and resuming when other
constraints supply it. This is EXACTLY propagator semantics — each typing rule is a
propagator that fires when its input cells have enough information.

Pacak et al. (POPL 2025) implement "Incremental Bidirectional Typing via Order
Maintenance" where type updates flow bidirectionally through pointers connecting
bound variables to binding locations. These pointers ARE propagator input/output wires.

**For Prologos**: The omnidirectional insight means we don't need to distinguish check
and synth modes. Just fire all propagators and let lattice merge handle information
flow in whatever direction is productive. Suspended constraints resume automatically
when their input cells gain information. This subsumes bidirectional checking.

### 8.2 Incremental Compilation

Acar's "Self-Adjusting Computation" (CMU, 2005) and the Adapton framework (PLDI 2014)
provide foundations for incremental computation via dependency tracking.

Salsa (used by rust-analyzer) implements this for Rust: programs are query sets, results
are memoized, input changes trigger selective recomputation.

**For Prologos**: An incremental compiler as a propagator network:

1. Source file -> cell (value = parsed AST)
2. Parse -> elaborate -> type-check -> codegen = propagator chain per module
3. File change -> cell update -> `run-to-quiescence` recomputes only affected cells
4. Persistent network gives O(1) "previous version" access for delta computation
5. Tabling memoizes sub-computations (trait resolution, import resolution)

**Novel advantage**: Multidirectional propagation means a type signature change can
propagate BACKWARDS to callers, not just forwards. "What if I change this type?" =
"set this cell and run-to-quiescence."

### 8.3 Live Programming Environments

Reed (LIVE/SPLASH 2024) demonstrated "Scoped Propagators" for spatial computing: propagators
scoped to specific events, crossing siloed system boundaries.

Thompson (2014) used propagators for FRP-style UI programming: UI elements are cells,
user interactions are propagators, changes propagate reactively.

**For Prologos**: A live editor where:

1. Each token/expression is a cell
2. Type-checking rules are propagators
3. Editing updates cells; `run-to-quiescence` incrementally re-typechecks
4. Error diagnostics accumulate in `SetLattice ErrorMessage` cells
5. ATMS enables "tentative edits" — type-check a hypothetical change without committing

### 8.4 Solver-Aided Programming

Torlak & Bodik's Rosette (Onward! 2013) extends Racket with symbolic execution:
programs are symbolically evaluated, generating constraints solved by SMT.

Prologos's propagator network IS a constraint solver. The Rosette model (symbolic
execution -> constraint generation -> solving) is subsumed by Prologos's model
(constraint declaration -> propagation -> quiescence/ATMS search). But Rosette's
user-facing abstractions are valuable:

- `verify`: "prove this property holds for all inputs" = prove no contradiction exists
- `synthesize`: "find an expression satisfying this spec" = find cell values satisfying all propagators
- `debug`: "explain this failure" = ATMS dependency chain
- `repair`: "fix this failure" = minimal nogood retraction

### 8.5 Key Papers

- Dunfield & Krishnaswami, "Bidirectional Typing" (ACM Surveys 2021)
- Leijen, "Omnidirectional Type Inference for ML" (2025) — Suspend/resume constraints
- Pacak et al., "Incremental Bidirectional Typing" (POPL 2025) — Order maintenance
- Acar, "Self-Adjusting Computation" (CMU PhD, 2005)
- Hammer et al., "Adapton: Composable, Demand-Driven Incremental Computation" (PLDI 2014)
- Salsa (Rust) — Incremental compilation framework for rust-analyzer
- Reed, "Scoped Propagators" (LIVE/SPLASH 2024)
- Thompson, "Functional Reactive User Interfaces with Propagators" (2014)
- Torlak & Bodik, "Growing Solver-Aided Languages with Rosette" (Onward! 2013, PLDI 2014)

---

<a id="9-synthesis"></a>

## 9. Cross-Cutting Synthesis: Combinations That Create New Capabilities

The most exciting opportunities come from combining multiple areas. Prologos's unified
infrastructure makes these combinations natural.

### 9.1 ATMS + Abstract CDCL = Propagator-Native Theorem Prover

Prologos's ATMS is structurally identical to CDCL's implication graph + nogood database.
The Abstract CDCL work shows this generalizes from Booleans to arbitrary lattices.
Combining them:

- **Model search** = `run-to-quiescence` with ATMS assumptions
- **Conflict analysis** = ATMS dependency-directed backtracking
- **Clause learning** = new propagator derived from nogood
- **Widening** = `Widenable` trait for infinite-height domains

This gives Prologos a built-in theorem prover: sound, complete (for decidable domains),
and efficient (CDCL's power on top of domain-specific propagation). No external SMT
solver needed.

### 9.2 Galois Connections + Provenance Semirings = Explained Multi-Domain Analysis

Cross-domain propagation with provenance annotations. Not only does information flow
between domains, but the derivation chain tracks which domain contributed what:

"This type error was detected by the interval analysis domain (the value is negative,
but the function expects NonNeg) which was connected to the type domain via the
NonNeg -> Interval Galois connection."

### 9.3 Session Types + ATMS = Protocol Verification with Counterexamples

Session type checking as propagation, with ATMS recording assumptions about protocol
states. When a protocol violation is detected (contradiction), the ATMS provides a
minimal counterexample: the specific sequence of send/receive steps that violates
the protocol.

### 9.4 Incremental Compilation + Distributed Propagation = IDE-Scale Type Checking

Combine incremental bidirectional typing with distributed multi-module propagation.
Each module = sub-network; cross-module constraints = boundary cells. Editing a file
triggers local propagation; boundary cells propagate changes to dependent modules.
IDE-scale responsiveness for project-wide type checking.

### 9.5 Self-Adjusting Computation + Tabling = Incremental Logic Programming

Tabling caches relation answers. Self-adjusting computation invalidates only affected
entries on change. Together: incremental Datalog with lattice values — more powerful
than Flix (which recomputes from scratch).

### 9.6 Contractor Programming + Galois Connections = Modular Interval Analysis

Interval constraint propagators ("contractors") composed with Galois connections to
other domains (sign, parity, type). New analyses plug in without modifying existing
contractors. The reduced product is automatic.

### 9.7 Summary: The Propagator Network as Unified Infrastructure

The deepest insight from this research is that propagator networks with Galois connections
provide a **single computational substrate** that subsumes:

| Traditionally separate system | Propagator formulation |
|-------------------------------|----------------------|
| Type inference engine | Cells = metas, propagators = typing rules |
| Constraint solver | Cells = variables, propagators = constraints |
| Abstract interpreter | Cells = abstract values, propagators = transfer functions |
| SAT/SMT solver | Cells = literals, propagators = clauses, ATMS = CDCL |
| Theorem prover | Cells = propositions, propagators = inference rules |
| Session type checker | Cells = channel types, propagators = protocol rules |
| Incremental compiler | Cells = module exports, propagators = compilation steps |
| Test diagnostic engine | ATMS derivations = error explanations |
| CRDT-based distributed system | Cells = replicated state, merge = CRDT join |

In traditional language implementations, each of these is a separate, bespoke system.
In Prologos, they can all be instances of the same infrastructure: define a `Lattice`,
define propagators, wire Galois connections, run to quiescence.

This is not just an implementation convenience. It means these systems **compose for free**:
type inference talks to session type checking talks to capability verification talks to
abstract interpretation — all through the Galois connection mechanism. The whole is
genuinely greater than the sum of its parts.

---

<a id="10-references"></a>

## 10. References

### Foundational

- Radul, A. "Propagation Networks: A Flexible and Expressive Substrate for Computation." MIT PhD Thesis, 2009.
- Sussman, G.J. and Radul, A. "The Art of the Propagator." MIT TR 2008-003, 2008.
- Steele, G.L. "The Definition and Implementation of a Computer Programming Language Based on Constraints." MIT PhD Thesis, 1980.
- Kmett, E. "Propagators." FnConf 2019 / YOW! 2016.

### Abstract Interpretation

- Cousot, P. and Cousot, R. "Abstract Interpretation: A Unified Lattice Model for Static Analysis of Programs by Construction or Approximation of Fixpoints." POPL 1977.
- Cousot, P. and Cousot, R. "A Galois Connection Calculus for Abstract Interpretation." POPL 2014.
- Darais, D. and Van Horn, D. "Constructive Galois Connections: Taming the Galois Connection Framework for Mechanized Metatheory." ICFP 2016 / JFP 2018.
- Madsen, M., Yee, M.-H., and Lhotak, O. "From Datalog to Flix: A Declarative Language for Fixed Points on Lattices." PLDI 2016.
- Arntzenius, M. and Krishnaswami, N.R. "Datafun: A Functional Datalog." ICFP 2016.

### Theorem Proving / SMT

- D'Silva, V. et al. "Abstract Conflict Driven Learning." SAS 2013.
- D'Silva, V. et al. "Lifting CDCL to Template-Based Abstract Domains for Program Verification." SAS 2017.
- Duck, G.J. "SMCHR: Satisfiability Modulo Constraint Handling Rules." Theory and Practice of Logic Programming, 2012.
- Stuckey, P.J. et al. "Propagation = Lazy Clause Generation." CP 2007.
- de Kleer, J. "An Assumption-Based TMS." Artificial Intelligence 28(2), 1986.

### Constraint Solving

- Schulte, C. and Stuckey, P. "Efficient Constraint Propagation Engines." ACM TOPLAS 30(1), 2008.
- Fruhwirth, T. "Constraint Handling Rules." Constraint Programming: Basics and Trends, 1994.
- Chabert, G. and Jaulin, L. "Contractor Programming." Artificial Intelligence, 2009.

### Session Types / Linear Logic

- Caires, L. and Pfenning, F. "Session Types as Intuitionistic Linear Propositions." CONCUR 2010.
- Pfenning, F. and Griffith, D. "Linear Logic Propositions as Session Types." MSCS, 2013.
- Toninho, B. and Yoshida, N. "Practical Refinement Session Type Inference." 2025.

### Actor Model / Concurrency

- Hewitt, C. "Actor Model of Computation." 1973 (extended 2010).
- Kuper, L. and Newton, R.R. "LVars: Lattice-based Data Structures for Deterministic Parallelism." FHPC 2013.
- Kuper, L. "Lattice-based Data Structures for Deterministic Parallel and Distributed Programming." Indiana University PhD Dissertation, 2015.

### Distributed Systems

- Saraswat, V. "Concurrent Constraint Programming." MIT Press, 1993.
- Shapiro, M. et al. "Conflict-Free Replicated Data Types." SSS 2011.

### Testing / Debugging / Provenance

- de Kleer, J. and Williams, B. "Diagnosing Multiple Faults." Artificial Intelligence 32(1), 1987.
- Doyle, J. "A Truth Maintenance System." Artificial Intelligence 12(3), 1979.
- Green, T.J., Karvounarakis, G., and Tannen, V. "Provenance Semirings." PODS 2007.

### Novel Applications

- Dunfield, J. and Krishnaswami, N.R. "Bidirectional Typing." ACM Computing Surveys 54(5), 2021.
- Leijen, D. "Omnidirectional Type Inference for ML." 2025.
- Pacak, A. et al. "Incremental Bidirectional Typing via Order Maintenance." POPL 2025.
- Acar, U.A. "Self-Adjusting Computation." CMU PhD Thesis, 2005.
- Hammer, M.A. et al. "Adapton: Composable, Demand-Driven Incremental Computation." PLDI 2014.
- Reed, O. "Scoped Propagators." LIVE/SPLASH 2024.
- Torlak, E. and Bodik, R. "Growing Solver-Aided Languages with Rosette." Onward! 2013.
