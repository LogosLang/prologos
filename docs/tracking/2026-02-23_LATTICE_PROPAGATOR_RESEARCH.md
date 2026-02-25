# Lattice-Based Propagator Networks as a General Logic Engine: Research Survey

**Date**: 2026-02-23
**Status**: Research complete

---

## 1. Lindsey Kuper's LVars Work

### Key References

1. **Kuper, L. & Newton, R.R.** "LVars: Lattice-based Data Structures for Deterministic Parallelism." *FHPC 2013* (co-located with ICFP). [PDF](https://users.soe.ucsc.edu/~lkuper/papers/lvars-fhpc13.pdf)
2. **Kuper, L., Turon, A., Krishnaswami, N.R. & Newton, R.R.** "Freeze After Writing: Quasi-Deterministic Parallel Programming with LVars." *POPL 2014*. [PDF](https://users.soe.ucsc.edu/~lkuper/papers/lvish-popl14.pdf)
3. **Kuper, L.** "Lattice-based Data Structures for Deterministic Parallel and Distributed Programming." *PhD Dissertation, Indiana University*, 2015. [PDF](https://users.soe.ucsc.edu/~lkuper/papers/lindsey-kuper-dissertation.pdf)
4. **LVish library** (Haskell): [Hackage](https://hackage.haskell.org/package/lvish), [GitHub](https://github.com/iu-parfunc/lvars)
5. **LVar examples**: [GitHub](https://github.com/lkuper/lvar-examples)

### Formal Definition

An **LVar** is a mutable shared variable whose states form an element of a user-specified *join-semilattice* (D, <=, bot, join). The key operations are:

- **put(lv, d)**: Updates the LVar to `join(current_state, d)`. This is *inflationary* -- the state can only grow (move upward in the lattice). If the result is `top` (the error element), a "put after freeze" error is raised.
- **get(lv, T)**: A *threshold read*. Given a **threshold set** T (a subset of D), blocks until the LVar's state reaches or exceeds some element t in T, then returns t. The critical constraint: every pair of elements in T must have their meet equal to `bot` -- they must be *pairwise incompatible*. This ensures that at most one element of T can be reached by any execution, guaranteeing deterministic observations.
- **freeze(lv)**: (POPL 2014 extension) Freezes the LVar, making its exact state observable but preventing further writes. Any subsequent put raises an error.

### Determinism Guarantees

- **Strong determinism** (FHPC 2013 model): With only `put` and threshold `get`, *every execution of a program produces the same result*. The proof relies on the Church-Rosser property: because puts are commutative/associative/idempotent (they compute joins) and gets can only observe lattice-theoretic properties that are invariant under reordering, the observable behavior is scheduling-independent.

- **Quasi-determinism** (POPL 2014 model): With freeze, programs are *quasi-deterministic*: every execution either produces the same answer or raises an error (due to a write racing with a freeze). The program never silently gives different answers. Formally: for any two terminating runs r1 and r2, either both produce value v, or at least one raises a `PutAfterFreezeError`.

### Threshold Read Mechanics

A threshold set T must satisfy: for all t1, t2 in T with t1 != t2, there is no element d in D such that d >= t1 and d >= t2 (equivalently, meet(t1, t2) = bot). This "pairwise incompatibility" constraint is what ensures determinism. It means the lattice state can only ever reach *one* of the threshold elements, so the get always returns the same value regardless of scheduling.

Example: For a set-lattice (powerset with union as join), a threshold set might be `{{a}, {b}, {c}}` -- you block until *at least one* of a, b, or c is in the set, and return which one. But `{{a}, {a,b}}` would be illegal because `{a} meet {a,b} = {a} != bot`.

### LVish Implementation Details

LVish is a Haskell library providing:
- A work-stealing scheduler for Par monad computations
- Lattice-based data structures: `IVar` (single-assignment), `ISet` (grow-only set), `IMap` (grow-only map), `SatMap`, `NatArray`
- Effect levels indexed in the type system: `Det` (deterministic) vs `QuasiDet` (quasi-deterministic, allows freezing)
- Event handlers: `addHandler` triggers callbacks when LVar state changes, enabling event-driven composition
- The `Par` monad with `runPar :: Par Det s a -> a` (guaranteed pure) and `runParQuasiDet :: Par QuasiDet s a -> a` (may throw)

### Limitations for Logic Programming

The fundamental tension: **LVars guarantee determinism, but logic programming requires nondeterminism (search/choice).**

1. **No retraction**: LVars are monotonically increasing. You cannot backtrack (undo a put). This directly conflicts with Prolog-style depth-first search with backtracking.
2. **No observation of exact state**: Threshold reads can only detect that the state *exceeds* a threshold, not observe the exact state. This prevents the kind of "inspect and branch" needed for unification-based search.
3. **No choice/disjunction**: There is no built-in `amb` or choice operator. Every execution path converges to the same result.
4. **Freeze is destructive**: The freeze operation provides exact observation but at the cost of preventing further evolution -- it's a one-shot operation, not suitable for repeated inspection during search.

**Recovering nondeterminism**: Possible approaches include:
- **Freeze + fork**: Freeze an LVar to observe its state, then fork independent computations for each choice. This sacrifices determinism (becomes quasi-deterministic at best).
- **Powerset lattice of solutions**: Represent the *set of all solutions* as the LVar value. This is monotonic (adding solutions only grows the set) but may require computing all solutions eagerly.
- **Layering a search monad**: Use LVars for the constraint store but layer a search/backtracking monad on top, with the LVar state representing the "shared knowledge" that grows monotonically across all branches.

---

## 2. Lattice Forks / Forking Lattice State

### The Core Problem

How do you introduce *choice points* into a monotonic lattice-based computation? If the lattice can only grow, how do you explore alternative branches that make *different* (incompatible) assumptions?

### Approach A: ATMS Worldview Branching

**Key References:**
1. **de Kleer, J.** "An Assumption-based TMS." *Artificial Intelligence* 28(2), 1986, pp. 127-162. [Semantic Scholar](https://www.semanticscholar.org/paper/An-Assumption-Based-TMS-Kleer/ed3f9263e936a879092ad7a2bf27e0f94089ccd8)
2. **de Kleer, J. & Reiter, R.** "Foundations of Assumption-based Truth Maintenance Systems: Preliminary Report." *AAAI 1987*. [PDF](https://www.researchgate.net/publication/221603091)
3. **Wotawa, F.** "ATMS -- Assumption-based Truth Maintenance Systems." [Tutorial PDF](https://www.dbai.tuwien.ac.at/staff/wotawa/atmschapter1.pdf)

**How it works**: The ATMS maintains *all* possible worldviews simultaneously. Each derived fact is labeled with the *set of assumptions* (called an "environment") that justify it. A **worldview** is a consistent subset of assumptions. Key properties:

- **No backtracking needed**: All possible solutions are computed simultaneously, labeled by their assumptions. "Context switching" between worldviews is free -- you just change which assumptions you believe.
- **Nogood sets**: When a contradiction is discovered, the set of assumptions responsible is recorded as a "nogood." All worldviews containing a nogood subset are invalidated.
- **Lattice structure**: The environments form a lattice under subset ordering. The set of consistent environments (those not containing any nogood) forms a sub-poset.
- **Relevance to propagators**: The Radul-Sussman propagator model directly incorporates ATMS-style truth maintenance. Each cell can hold *contingent values* -- partial information tagged with the assumptions supporting it. The `amb` operator creates fresh hypothetical premises, and contradiction detection + nogood recording provides dependency-directed backtracking.

### Approach B: OR-Parallelism in Logic Programming

**Key References:**
1. **Lusk, E. et al.** "The Aurora Or-Parallel Prolog System." *New Generation Computing* 7(2,3), 1990, pp. 243-271.
2. **Ali, K. & Karlsson, R.** "The Muse Or-Parallel Prolog Model and its Performance." *NACLP 1990*.
3. **Gupta, G. et al.** "Parallel Execution of Prolog Programs: A Survey." *ACM TOPLAS* 23(4), 2001. [PDF](https://cliplab.org/papers/partut-toplas.pdf)
4. **Rocha, R. et al.** "YapDss: An Or-Parallel Prolog System for Scalable Beowulf Clusters." 2003.

**Environment copying model (MUSE)**: Each worker maintains its own copy of the WAM stacks. When a worker runs out of work, it copies the environment from a busy worker at a shared choice point, creating an independent copy that can diverge. This is precisely *forking lattice state*:
- The "lattice state" is the binding environment (substitution)
- "Forking" = copying the environment at a choice point
- Each fork evolves independently (different clause alternatives)
- No merge is needed -- each branch either succeeds (producing an answer) or fails

**Stack-splitting** (improvement over MUSE): Instead of copying the entire stack, the work is split at a choice point, with each worker getting a portion of the untried alternatives.

### Approach C: CRDT Fork-Join Pattern

**Key References:**
1. **Shapiro, M. et al.** "A comprehensive study of Convergent and Commutative Replicated Data Types." *INRIA TR 7506*, 2011.
2. **Shapiro, M. et al.** "Conflict-Free Replicated Data Types." *SSS 2011*.
3. **Laddad, S. & Power, C.** "Keep CALM and CRDT On." *VLDB 2023*. [PDF](https://www.vldb.org/pvldb/vol16/p856-power.pdf)

**Fork-join in CRDTs**: Each replica independently updates its local copy (divergence/forking). When replicas communicate, they merge using the lattice join (convergence). The join-semilattice structure guarantees that merge is:
- Commutative: merge(a, b) = merge(b, a)
- Associative: merge(a, merge(b, c)) = merge(merge(a, b), c)
- Idempotent: merge(a, a) = a

**Relevance to logic programming search**: CRDTs show that forking is *natural* in lattice systems -- you fork by creating independent copies, let them evolve, and join to reconcile. The key insight: **for logic programming, you typically do NOT want to join the forks** (different search branches should remain independent). Instead, you collect answers from all branches into a result set.

### Approach D: Speculative Execution in Constraint Solvers

Constraint solvers (especially SAT/SMT) routinely fork state:
- **DPLL/CDCL**: Fork at decision points, propagate constraints in each branch, learn conflict clauses (nogoods) that prune future branches.
- **S2E (Selective Symbolic Execution)**: Performs *speculative forking* -- at every branch depending on symbolic input, S2E forks a new state, deferring feasibility checks to when a state is selected for execution.

### Synthesis: Lattice Forking as a Design Pattern

The pattern that emerges across all these systems:

1. **Snapshot** the current lattice state at a choice point
2. **Fork** into independent copies (one per alternative)
3. Each copy **evolves monotonically** within its branch
4. Branches that reach contradiction are **pruned** (recorded as nogoods in ATMS-style, or simply abandoned in OR-parallel style)
5. Surviving branches either **produce answers** (collected into a solution set) or are **joined** back (CRDT-style reconciliation)

The ATMS approach is the most elegant for logic programming because it avoids physical copying by labeling everything with assumptions and maintaining all worldviews virtually.

---

## 3. Lattice Embeddings

### Formal Definitions

**Key References:**
1. **Davey, B.A. & Priestley, H.A.** *Introduction to Lattices and Order*, 2nd ed. Cambridge University Press, 2002.
2. **Nation, J.B.** "Notes on Lattice Theory." University of Hawaii. [PDF](https://math.hawaii.edu/~jb/math618/Nation-LatticeTheory.pdf)
3. **Cousot, P. & Cousot, R.** "Abstract Interpretation: A Unified Lattice Model for Static Analysis of Programs by Construction or Approximation of Fixpoints." *POPL 1977*.
4. **Cousot, P. & Cousot, R.** "A Galois Connection Calculus for Abstract Interpretation." *POPL 2014*. [ACM DL](https://dl.acm.org/doi/10.1145/2535838.2537850)

#### Lattice Homomorphism

A function f: L -> M between lattices is a **lattice homomorphism** if it preserves meets and joins:
```
f(a join_L b) = f(a) join_M f(b)
f(a meet_L b) = f(a) meet_M f(b)
```
Any lattice homomorphism is automatically monotone (order-preserving).

#### Lattice Embedding

An **embedding** is an *injective* lattice homomorphism f: L -> M. The image f(L) is then a sublattice of M isomorphic to L. This captures the idea of L being faithfully represented inside M.

#### Sublattice

A subset S of a lattice L is a **sublattice** if it is closed under the meet and join operations of L:
- For all a, b in S: a join_L b in S and a meet_L b in S

Sublattices inherit the partial ordering from the parent lattice. Note: not every subset closed under the order is a sublattice -- it must be closed under the *operations*.

#### Galois Connection

Given posets (A, <=) and (B, <=), a pair of monotone functions alpha: A -> B and gamma: B -> A form a **Galois connection** (written alpha -| gamma) if:
```
For all a in A, b in B:  alpha(a) <= b  iff  a <= gamma(b)
```
Equivalently:
- a <= gamma(alpha(a)) for all a in A  (gamma . alpha is extensive / a closure)
- alpha(gamma(b)) <= b for all b in B  (alpha . gamma is reductive / a kernel)

A **Galois insertion** is a Galois connection where alpha is surjective (equivalently, gamma is injective), meaning every abstract element models some concrete element(s).

### Abstract Interpretation's Use of Galois Connections

**Key References:**
1. **Cousot, P. & Cousot, R.** "Abstract Interpretation: A Unified Lattice Model..." *POPL 1977*. [ACM DL](https://dl.acm.org/doi/10.1145/512950.512973)
2. **Cousot, P. & Cousot, R.** "Comparing the Galois Connection and Widening/Narrowing Approaches to Abstract Interpretation." *PLILP 1992*. [PDF](https://www.di.ens.fr/~cousot/publications.www/CousotCousot-PLILP-92-LNCS-n631-p269--295-1992.pdf)
3. **Cousot, P. & Cousot, R.** "Abstract Interpretation and Application to Logic Programs." *JLP* 2(4), 1992. [PDF](https://www.di.ens.fr/~cousot/publications.www/CousotCousot-JLP-v2-n4-p511--547-1992.pdf)
4. **Cousot, P.** "Types as Abstract Interpretations." *POPL 1997*. [PDF](https://pcousot.github.io/publications/Cousot-POPL97-p316-331-1997.pdf)

In abstract interpretation, the **concrete domain** (C, <=_C) and **abstract domain** (A, <=_A) are connected by a Galois connection (alpha, gamma):
- **alpha** (abstraction): maps concrete values to their best abstract approximation
- **gamma** (concretization): maps abstract values to the set of concrete values they represent
- The abstract domain is a *sound overapproximation* of the concrete domain

This is the formal basis for "pocket universes" / sub-lattice isolation:
- The abstract domain is a simpler lattice embedded into a relationship with the concrete domain
- Computations in the abstract domain *soundly approximate* computations in the concrete domain
- **Widening** (nabla) accelerates fixpoint convergence when the abstract domain has infinite ascending chains
- **Narrowing** (delta) recovers precision after widening stabilizes

### Sub-lattice Isolation in Practice

1. **Domain embeddings in denotational semantics**: Scott domains are structured as lattices of partial information. A subdomain embedding d: D -> E (where D is a retract of E) allows treating a simpler domain as a "pocket" within a larger one.

2. **Distributed systems**: In CRDTs, each data type defines its own lattice. Composite CRDTs embed component lattices into a product lattice. The Bloom^L approach allows different lattice types to interact through **cross-lattice morphisms** -- monotone functions between different lattice types.

3. **Propagator networks**: Radul's thesis describes how different partial information types can coexist in the same network. Each cell's merge operation defines a local lattice, and propagators that connect cells of different types must respect the lattice structure of both endpoints. This is effectively a network of lattice embeddings.

### Relevance to Logic Engine Design

For a lattice-based logic engine, lattice embeddings provide the mechanism for:
- **Modular constraint domains**: Each type of constraint (equality, ordering, arithmetic, set membership) lives in its own lattice, embedded into the global state via Galois connections
- **Abstraction hierarchies**: Coarser lattices for fast, approximate reasoning; finer lattices for precise answers
- **Scoped computation**: A "pocket universe" is a sub-lattice carved out for a particular sub-computation (e.g., a tabled call), with results projected back into the outer lattice via a lattice homomorphism

---

## 4. Recovering SLD/SLG Resolution Semantics on Lattices

### SLD Resolution Background

**SLD resolution** (Selective Linear Definite clause resolution) is the standard operational semantics of Prolog:
- Maintains a *goal stack* (conjunction of atoms to prove)
- At each step, selects the leftmost atom, finds matching clauses
- Creates a **choice point** for each matching clause
- Applies unification, adds new subgoals
- On failure, backtracks to the most recent choice point
- This produces a depth-first left-to-right search of the SLD tree

**Key Reference:** Kowalski, R. & Kuehner, D. "Linear Resolution with Selection Function." *Artificial Intelligence* 2, 1971.

### SLG Resolution and Tabling

**Key References:**
1. **Chen, W. & Warren, D.S.** "Tabled Evaluation with Delaying for General Logic Programs." *JACM* 43(1), 1996.
2. **Swift, T. & Warren, D.S.** "XSB: Extending Prolog with Tabled Logic Programming." *TPLP* 12(1-2), 2012. [arXiv](https://arxiv.org/abs/1012.5123)
3. **Swift, T. & Warren, D.S.** "An Abstract Machine for Tabled Execution of Fixed-Order Stratified Logic Programs." *ICLP 1994*.

**SLG resolution** adds *tabling* (memoization) to SLD:
- First call to a tabled predicate creates a **producer** that stores answers in a table
- Subsequent (variant) calls create **consumers** that wait for the producer's answers
- Cycle detection is intrinsic: when a consumer encounters itself as a producer, it knows to wait
- Complete answer sets are computed via **fixpoint iteration**: the producer-consumer loop iterates until no new answers are produced
- This evaluates programs according to the **well-founded semantics** (handles negation through cycles)

### Mapping SLD onto Lattice-Based Computation

The challenge: SLD resolution is inherently *non-monotonic* (backtracking retracts bindings), while lattice computation is monotonic. Several mappings are possible:

#### Choice Points as Lattice Branching (ATMS/Propagator Approach)

In the Radul-Sussman propagator model:
- A **choice point** corresponds to an `amb` cell that creates fresh hypothetical premises
- Each clause alternative is a contingent value tagged with a distinct hypothesis
- Propagation proceeds for all branches simultaneously (ATMS maintains all worldviews)
- **Backtracking** = detecting a nogood set and retracting the responsible hypothesis
- **Dependency-directed backtracking** = the nogood set identifies *which* choice was responsible, skipping irrelevant choices

This mapping preserves the logical completeness of SLD resolution while replacing chronological backtracking with dependency-directed backtracking. The lattice structure is the ATMS's lattice of environments (assumption sets ordered by subset inclusion).

#### Choice Points as Powerset/Stream Elements

Alternative: represent the search tree *as data* within the lattice:
- The lattice is `Powerset(Substitution)` -- the set of all answer substitutions found so far
- Each resolution step *adds* new substitutions (monotonic growth)
- Choice = exploring multiple clauses = adding answers from each
- This naturally produces Datalog-style bottom-up evaluation

#### Tabling as Lattice Memoization

**Key References:**
1. **Swift, T. & Warren, D.S.** XSB's answer subsumption with lattice mode. [SWI-Prolog tabling docs](https://www.swi-prolog.org/pldoc/man?section=tabling-mode-directed)
2. **Madsen, M. et al.** "From Datalog to Flix: A Declarative Language for Fixed Points on Lattices." *PLDI 2016*.
3. **Zucker, P.** "Aggregates, Lattices, and Subsumption." [Blog](https://www.philipzucker.com/datalog-book/lattices.html)

XSB Prolog's `lattice(PI)` tabling mode directly connects tabling to lattice operations:
- Each tabled predicate has a **lattice answer mode** where answers are aggregated using a user-defined join
- Instead of storing all individual answers, the table stores the *least upper bound* of all answers seen
- New answers are only "new" if they are not <= the current table entry
- Convergence = reaching a fixpoint of the immediate consequence operator on the lattice

This is exactly the bridge between SLG resolution and Flix/Datafun-style lattice fixpoints:
- **SLG tabling** = computing the least fixpoint of the immediate consequence operator T_P on the lattice of Herbrand interpretations
- **Flix evaluation** = computing the least fixpoint of a monotone function on user-defined lattices
- Both use **semi-naive evaluation** to avoid redundant computation

#### Cut as Threshold/Freeze

(See Section 6 for detailed treatment.)

### Connections to Datalog with Lattices

#### Flix

**Madsen, M., Yee, M.-H. & Lhot'ak, O.** "From Datalog to Flix: A Declarative Language for Fixed Points on Lattices." *PLDI 2016*. [PDF](https://plg.uwaterloo.ca/~olhotak/pubs/pldi16.pdf)

Flix extends Datalog by:
- Associating predicate symbols with lattice types
- Rules can include **monotone filter functions** (phi: lattice -> Bool) and **monotone transfer functions** (f: lattice -> lattice)
- Evaluation computes the least fixpoint using adapted semi-naive evaluation
- Non-monotonicity handled by stratification (same as Datalog with negation)

Flix's model-theoretic semantics: a **Flix model** is a minimal interpretation I such that I satisfies all rules and I is a fixpoint of the immediate consequence operator. This directly extends the minimal-model semantics of Datalog.

#### Datafun

**Arntzenius, M. & Krishnaswami, N.R.** "Datafun: A Functional Datalog." *ICFP 2016*. [PDF](https://www.cl.cam.ac.uk/~nk480/datafun.pdf)
**Arntzenius, M. & Krishnaswami, N.R.** "Seminaive Evaluation for a Higher-Order Functional Language." *POPL 2020* (Distinguished Paper). [PDF](https://www.rntz.net/files/seminaive-datafun.pdf)

Datafun takes a type-theoretic approach:
- **Monotonicity tracked in the type system**: `A ->+ B` is the type of monotone functions from A to B
- Semilattice types have `bot` (bottom) and `join` (least upper bound)
- `fix : (A ->+ A) -> A` computes the least fixpoint of a monotone endofunction on a semilattice
- Higher-order: first-class functions, sets, datatypes
- Seminaive evaluation extended to higher-order setting via *change structures* (derivatives of monotone functions)

### Approximation Fixpoint Theory (AFT)

**Key References:**
1. **Denecker, M., Marek, V. & Truszczynski, M.** "Approximations, Stable Operators, Well-Founded Fixpoints and Applications in Nonmonotonic Reasoning." *2000*.
2. **Denecker, M., Marek, V. & Truszczynski, M.** "Approximation Fixpoint Theory and the Semantics of Logic and Answer Set Programs." *2012*. [Springer](https://link.springer.com/chapter/10.1007/978-3-642-30743-0_13)

AFT provides a *unified algebraic framework* for logic programming semantics:
- Works on a **bilattice** L^2 = L x L (pairs of elements from a complete lattice L)
- An operator O: L -> L is approximated by an operator A: L^2 -> L^2 where A(x,y) approximates O(z) for any z in [x,y]
- **Kripke-Kleene fixpoint**: least fixpoint of A (starting from (bot, top))
- **Stable fixpoints**: fixpoints x of O such that x = lfp(A(., x))
- **Well-founded fixpoint**: the iterated application of A's "stable revision operator"

This is directly relevant: AFT shows how to define *all* major logic programming semantics (well-founded, stable models, Kripke-Kleene) as different fixpoints of lattice operators. It provides the theoretical foundation for mapping arbitrary logic programs onto lattice computation.

---

## 5. Comparison of Lattice-Based Propagator Systems

### Radul-Sussman Propagators (2008-2009)

**References:**
- **Radul, A. & Sussman, G.J.** "The Art of the Propagator." *MIT CSAIL TR-2009-002*, 2008. [PDF](https://groups.csail.mit.edu/mac/users/gjs/propagators/)
- **Radul, A.** "Propagation Networks: A Flexible and Expressive Substrate for Computation." *PhD Thesis, MIT*, 2009. [PDF](https://dspace.mit.edu/handle/1721.1/49525)
- **Radul, A. & Sussman, G.J.** "Revised Report on the Propagator Model." 2009. [Web](https://groups.csail.mit.edu/mac/users/gjs/propagators/)

| Aspect | Detail |
|--------|--------|
| **Lattice structure** | User-defined per cell. The `merge` operation must form a join-semilattice (commutative, associative, idempotent). Partial information types include: intervals, sets, supported values (value + provenance), TMS contingent values. |
| **Non-monotonicity** | Handled via ATMS-style truth maintenance. The `amb` operator creates hypothetical premises; contradiction detection records nogoods. Worldview changes (retracting a hypothesis) are non-monotonic but managed *outside* the lattice (in the TMS layer). |
| **Parallelism** | Implicit: propagators are autonomous, stateless machines that fire whenever their input cells change. Naturally parallel with data-driven scheduling. No formal determinism guarantee (depends on TMS worldview management). |
| **Search** | Built-in via `amb` + TMS. Dependency-directed backtracking emerges from nogood recording. The `amb` propagator maintains the invariant that exactly one of its hypothetical premises is believed; contradiction triggers retraction and alternative exploration. |
| **Key insight** | The merge operation on cells is the lattice join. Propagators are monotone functions between cells. The TMS layer provides a non-monotonic "control plane" over the monotonic "data plane." |

### LVars / LVish (2013-2015)

| Aspect | Detail |
|--------|--------|
| **Lattice structure** | User-specified join-semilattice per LVar type. Standard library provides: IVar (flat lattice), ISet (powerset), IMap (key -> lattice value). |
| **Non-monotonicity** | Strictly prohibited in the deterministic fragment. Freeze operation introduces quasi-determinism. No backtracking, no retraction. |
| **Parallelism** | Strong guarantee: deterministic parallelism (same answer on every run). Work-stealing scheduler. Haskell type system enforces effect levels. |
| **Search** | Not supported. LVars are designed for deterministic parallel programming, not logic programming. |
| **Key insight** | Threshold reads are the mechanism for *deterministic observation* of growing lattice state. The pairwise-incompatibility constraint on threshold sets is what makes this work. |

### CRDTs (2011-present)

**References:**
- **Shapiro, M. et al.** "A comprehensive study of Convergent and Commutative Replicated Data Types." *INRIA TR*, 2011.

| Aspect | Detail |
|--------|--------|
| **Lattice structure** | Each CRDT type defines a join-semilattice. State-based CRDTs (CvRDTs) require a merge function = lattice join. Examples: G-Counter (vector of max), PN-Counter (pair of G-Counters), G-Set (union), OR-Set (add-wins set), LWW-Register. |
| **Non-monotonicity** | Distinguished *internal* lattice state (metadata, monotonically growing) from *external* query result (may be non-monotonic). E.g., a PN-Counter's internal state only grows, but `value()` = increments - decrements can decrease. |
| **Parallelism** | Designed for distributed replicas. Strong Eventual Consistency (SEC): replicas that have received the same set of updates (in any order) have the same state. Coordination-free by construction. |
| **Search** | Not applicable. CRDTs are for distributed state convergence, not search. |
| **Key insight** | The distinction between monotonic internal state and non-monotonic external queries. This pattern is directly applicable to logic programming: the constraint store (internal) grows monotonically, while query answers (external) may involve non-monotonic projection. |

### Flix (2016-present)

**References:**
- **Madsen, M. et al.** "From Datalog to Flix." *PLDI 2016*.

| Aspect | Detail |
|--------|--------|
| **Lattice structure** | User-defined lattices associated with predicate symbols. Built-in lattices include: flat lattices, powersets, intervals, constant propagation lattice, parity lattice. |
| **Non-monotonicity** | Stratified negation and non-monotonic lattice operations. The program is stratified: within a stratum, all operations are monotone; between strata, negation/non-monotonic operations are allowed after the lower stratum reaches its fixpoint. |
| **Parallelism** | Semi-naive evaluation strategy allows parallelization of rule application within a stratum. No formal parallelism guarantees published. |
| **Search** | Not traditional search/backtracking. Computes the *minimal model* (least fixpoint). All solutions satisfying the rules are found by forward chaining. |
| **Key insight** | Extends Datalog's model-theoretic semantics to lattices. Filter functions (monotone predicates on lattice values) and transfer functions (monotone transformations) bridge the relational and lattice worlds. |

### Datafun (2016-2020)

| Aspect | Detail |
|--------|--------|
| **Lattice structure** | Semilattice types with `bot` and `join`. Types track monotonicity: `A ->+ B` = monotone function type. Set types are semilattices with union as join. |
| **Non-monotonicity** | Handled by distinguishing monotone (tone +) and non-monotone (tone -) function types. Non-monotone operations exist but cannot be used inside fixpoint computations. |
| **Parallelism** | Not a focus. Denotational semantics is sequential. Seminaive evaluation provides efficiency but not parallelism. |
| **Search** | Fixpoints of monotone maps on semilattices. `fix f` computes the least fixpoint by iterating f from `bot`. No backtracking. |
| **Key insight** | Monotonicity as a *type-level* property. The type system statically enforces that fixpoint computations are monotone, preventing non-termination. Seminaive evaluation via change structures (derivatives of monotone functions) provides efficient incremental computation. |

### Ascent (2021-present)

**References:**
- **Sahebolamri, A. et al.** "Seamless Deductive Inference via Macros." [PDF](https://thomas.gilray.org/pdf/seamless-deductive.pdf)
- [GitHub](https://github.com/s-arash/ascent), [Docs](https://s-arash.github.io/ascent/)

| Aspect | Detail |
|--------|--------|
| **Lattice structure** | User-defined via `Lattice` trait in Rust. The `lattice` keyword defines a lattice relation where the final column has lattice semantics (facts with same keys are joined). |
| **Non-monotonicity** | Stratified negation and aggregation. The program is decomposed into SCCs, topologically sorted into strata. |
| **Parallelism** | Rust's ownership model provides memory safety. No inherent parallel evaluation (single-threaded fixpoint iteration). |
| **Search** | Bottom-up fixpoint computation. No backtracking. |
| **Key insight** | Datalog-with-lattices embedded as a Rust procedural macro, enabling zero-cost integration with host language. Lattice relations provide a natural way to express abstract interpretation within a Datalog framework. |

### CHR -- Constraint Handling Rules (1991-present)

**References:**
- **Fruhwirth, T.** *Constraint Handling Rules.* Cambridge University Press, 2009.
- **Fruhwirth, T.** "Constraint Handling Rules." *JLP* 37(1-3), 1998.
- **Schrijvers, T. et al.** "Abstract Interpretation for Constraint Handling Rules." *PPDP 2005*. [PDF](https://www.comp.nus.edu.sg/~gregory/papers/ppdp05.pdf)

| Aspect | Detail |
|--------|--------|
| **Lattice structure** | The constraint store forms a lattice under entailment. Propagation rules add logically redundant but useful constraints (moving up the lattice). Simplification rules replace constraints with simpler equivalent forms. |
| **Non-monotonicity** | Simplification rules are non-monotonic (they remove constraints). The interaction of simplification and propagation rules is characterized by *nested fixpoints*: the inner fixpoint for propagation (greatest fixpoint / coinductive), the outer for simplification (least fixpoint / inductive). |
| **Parallelism** | Theoretical operational semantics is highly nondeterministic. Confluent CHR programs can be parallelized. |
| **Search** | Not built-in; typically embedded in a host language (Prolog) that provides search. CHR provides constraint propagation; the host provides search/choice. |
| **Key insight** | The dual nature of propagation (monotonic, greatest fixpoint) and simplification (non-monotonic, least fixpoint) provides a clean framework for combining constraint propagation with constraint simplification. |

### Bloom / Bloom^L (2010-2012)

**References:**
- **Conway, N. et al.** "Logic and Lattices for Distributed Programming." *SoCC 2012*. [PDF](https://dsf.berkeley.edu/papers/UCB-lattice-tr.pdf)
- **Alvaro, P. et al.** "Consistency Analysis in Bloom: a CALM and Collected Approach." *CIDR 2011*.

| Aspect | Detail |
|--------|--------|
| **Lattice structure** | Bloom operates on sets (relational model). Bloom^L extends to arbitrary lattices with user-defined types. Built-in lattice types: `lmax`, `lmin`, `lset`, `lbool`, `lmap`. Cross-lattice morphisms connect different lattice types. |
| **Non-monotonicity** | CALM theorem: monotone programs are coordination-free. Non-monotone operations (negation, aggregation, non-monotone lattice methods) are stratified. Bloom^L's analysis identifies which program points require coordination. |
| **Parallelism** | Designed for distributed execution. The CALM theorem provides the theoretical guarantee: monotone programs are safe to run without coordination across distributed nodes. |
| **Search** | Not applicable. Bloom is for distributed programming, not search. |
| **Key insight** | The **CALM theorem** (Hellerstein, 2010): a problem has a consistent, coordination-free distributed implementation *if and only if* it is monotonic. This is the deepest connection between lattice theory and distributed computation. |

### Additional Systems

- **Lasp** (Meiklejohn, 2015): Distributed programming with CRDTs as lattice variables. Combinators (map, filter, fold) over CRDT streams. [PDF](https://christophermeiklejohn.com/publications/ppdp-2015-preprint.pdf)
- **Kmett's guanxi** (2019-present): Propagator-based relational programming in Haskell, blending LVars + Radul-Sussman + Datalog. Aims for a general logic programming framework. [GitHub](https://github.com/ekmett/guanxi)
- **Differential Datalog (DDlog)**: Incremental Datalog based on McSherry's differential dataflow. [GitHub](https://github.com/vmware-archive/differential-datalog)

---

## 6. Cut/Pruning on Lattices

### The Problem

Prolog's **cut** (`!`) is a control operator that:
1. Succeeds immediately when reached
2. Discards all choice points created since entering the predicate containing the cut
3. Commits to the current clause, preventing backtracking to alternative clauses

Cut is fundamentally *non-monotonic*: it removes possibilities from the search space. How can this be mapped to a lattice-based system where information only grows?

### Approach A: Threshold Reads and Freeze (LVars)

**Connection to cut**: The LVars `freeze` operation shares cut's commitment semantics:
- **freeze**: "I've seen enough; commit to the current state and prevent further evolution"
- **cut**: "I've found a satisfactory clause; commit to it and prevent further alternatives"

Both are *destructive* in the sense that they close off future possibilities.

**Threshold reads as soft cut**: A threshold read blocks until *some* threshold element is reached, then returns it. This is analogous to `once/1` in Prolog (succeed at most once): you wait for the first satisfactory answer and commit to it.

**Limitation**: LVars freeze is coarser than cut. Freeze prevents *all* further writes, while cut only prevents backtracking to specific choice points. A more surgical "partial freeze" would be needed.

### Approach B: Lattice Freezing/Sealing

A **sealed lattice** is one where a subset of elements are marked as "frozen" -- no further joins that would change the value are permitted. Formally:

- `seal(lv)` at state s: future `put(lv, d)` is a no-op if `join(s, d) = s`, and raises an error otherwise
- This is a "monotone seal" -- you can still put values that don't change the current state

This models Prolog's cut more precisely:
- When cut is executed, the current binding environment is "sealed" against the specific choice points being discarded
- Future computation can still *extend* the bindings (unify further variables) but cannot *retract* them

### Approach C: ATMS Worldview Commitment

In the Radul-Sussman propagator model, the `amb` operator creates hypothetical premises {h1, h2, ...} for a choice. **Cut corresponds to**:

1. When a clause succeeds, **retract all alternative hypotheses** for that choice point's amb
2. Record a nogood: {h_alt_1}, {h_alt_2}, ... (each alternative hypothesis individually is nogood)
3. This permanently commits to the chosen hypothesis

More precisely, when `amb` discovers that its chosen branch succeeds and cut is invoked:
- The amb *signals a new nogood set* that excludes the alternative branches
- The TMS propagates this, potentially triggering further pruning
- This is *dependency-directed*: only the specific alternatives are pruned, not unrelated choices

### Approach D: Committed Choice (Concurrent Logic Programming)

**Key References:**
1. **Clark, K.L. & Gregory, S.** "PARLOG: Parallel Programming in Logic." *ACM TOPLAS* 8(1), 1986. [ACM DL](https://dl.acm.org/doi/10.1145/5001.5390)
2. **Ueda, K.** "Guarded Horn Clauses." *FGCS 1986*.
3. **Shapiro, E.** "Concurrent Prolog: A Progress Report." *Computer*, 1986.

Concurrent logic languages replace cut with **committed choice**:
- Each clause has a **guard** (condition tested before commitment)
- Multiple clauses may match; their guards execute in parallel
- When a guard succeeds, the system **commits** to that clause
- Alternative clauses are *discarded* (don't care nondeterminism)
- No backtracking ever occurs

**Lattice interpretation**: Committed choice is a *monotone* operation on a lattice of *commitments*:
- The lattice has elements: `uncommitted`, `committed(clause_i)`, `failed`
- `uncommitted < committed(clause_i) < failed` for all i (with appropriate incompatibility)
- Guard evaluation = threshold read on the commitment lattice
- Commitment = putting a `committed(clause_i)` value into a commitment LVar
- This is a one-shot, monotone operation -- once committed, always committed

### Approach E: Stratified Cut / Once Semantics

**`once/1`** in Prolog: `once(Goal)` calls Goal and succeeds at most once (cuts away remaining choice points for Goal).

**Lattice mapping**: `once` over a lattice computation:
- Execute the subcomputation until the first answer is produced
- **Freeze** the relevant portion of the lattice state
- Return the single answer

This can be implemented via:
1. A threshold read with a singleton threshold set (wait for any answer)
2. Freeze the answer channel after reading
3. Clean up (garbage collect) the unreachable branches

### Approach F: Nogood-Based Pruning

In modern constraint solvers (SAT/SMT), pruning is achieved through **clause learning**:
- When a contradiction is found, the solver learns a **conflict clause** (nogood) that prevents the same combination of decisions from recurring
- This is monotone: the set of nogoods only grows
- The effect is equivalent to cut: once a conflict clause is learned, certain search branches are permanently pruned

**Lattice structure**: The set of learned nogoods forms a lattice (powerset of nogood clauses, ordered by subset inclusion). Pruning = joining a new nogood into this lattice. This is fully monotonic.

### Synthesis: Cut on Lattices

The key insight across all approaches: **cut can be decomposed into monotone operations on appropriate lattices**:

| Prolog Operation | Lattice Equivalent | Lattice Type |
|---|---|---|
| Choice point | `amb` / hypothetical premises | Power lattice of assumption sets |
| Cut (!) | Nogood recording / hypothesis retraction | Monotonically growing nogood set |
| once/1 | Threshold read + freeze | LVar with commitment lattice |
| Committed choice | Guard-triggered monotone commitment | Flat commitment lattice |
| if-then-else | Threshold read on condition + branch selection | Product of condition and result lattices |
| Negation-as-failure | Stratified computation (lower stratum complete before negation evaluated) | Stratified lattice fixpoint |

The unifying principle: **non-monotonicity in the search space is reified as monotonicity in a meta-lattice**. The search decisions themselves (which branches to explore, which to prune) are tracked in a monotonically-growing structure (nogood set, commitment lattice, frozen LVar set), even though the effect on the *search tree* is pruning (reduction).

---

## Cross-Cutting Themes and Key Insights

### 1. The Monotonicity/Search Tension

Every system in this survey faces the same fundamental tension: lattice-based computation is inherently monotonic (information only grows), but logic programming search requires non-monotonic operations (backtracking, retraction, pruning). The resolution strategies fall into three categories:

- **Encode search as monotonic accumulation**: Represent the set of all answers as the lattice value (Flix, Datafun, Datalog). No backtracking needed because you compute everything bottom-up.
- **Layer non-monotonic control over monotonic data**: Use a TMS/ATMS to manage worldviews above the monotonic cell layer (Radul-Sussman propagators, Kmett's guanxi).
- **Stratify non-monotonicity**: Allow non-monotonic operations only at stratum boundaries, after lower strata have reached fixpoints (Bloom^L, Flix, CHR).

### 2. The CALM Principle Applied to Logic Programming

The CALM theorem (Hellerstein 2010) states that monotone programs are exactly those that can be computed without coordination. For a logic engine:
- **Pure Datalog/Horn clauses** (no negation, no cut) are monotone -- can be fully parallelized
- **Negation, aggregation, cut** require coordination (stratification provides the minimal coordination structure)
- **The lattice framework makes this explicit**: monotone operations live within a stratum; coordination points (stratum boundaries) are where non-monotonic operations occur

### 3. Propagators as the Universal Substrate

The Radul-Sussman propagator model is the most general framework in this survey, subsuming:
- **LVars**: Propagators with threshold reads, no TMS
- **CRDTs**: Propagators where each cell is a replica, merge = lattice join
- **Datalog**: Propagators implementing the immediate consequence operator
- **Constraint solvers**: Propagators with domain-specific merge operations

The key additions needed for a full logic engine:
- **TMS layer** for managing hypothetical reasoning (amb, worldviews, nogoods)
- **Tabling/memoization** for termination and completeness (SLG-style)
- **Stratification** for negation and non-monotonic operations

### 4. Lattice Embeddings as the Modularity Mechanism

Galois connections provide the formal basis for:
- Connecting different constraint domains (each with its own lattice)
- Abstract interpretation (approximate reasoning in a simpler lattice)
- Tabling (the table is a sub-lattice of the full computation state)
- Scoped computation (pocket universes for sub-problems)

---

## Summary Table of Key References

| # | Authors | Title | Venue | Year |
|---|---------|-------|-------|------|
| 1 | Kuper, Newton | LVars: Lattice-based Data Structures for Deterministic Parallelism | FHPC | 2013 |
| 2 | Kuper, Turon, Krishnaswami, Newton | Freeze After Writing: Quasi-Deterministic Parallel Programming with LVars | POPL | 2014 |
| 3 | Kuper | Lattice-based Data Structures for Deterministic Parallel and Distributed Programming (PhD) | Indiana U. | 2015 |
| 4 | Radul, Sussman | The Art of the Propagator | MIT TR | 2008 |
| 5 | Radul | Propagation Networks (PhD) | MIT | 2009 |
| 6 | de Kleer | An Assumption-based TMS | AI Journal | 1986 |
| 7 | Shapiro et al. | Conflict-Free Replicated Data Types | SSS | 2011 |
| 8 | Conway et al. | Logic and Lattices for Distributed Programming (Bloom^L) | SoCC | 2012 |
| 9 | Madsen, Yee, Lhotak | From Datalog to Flix | PLDI | 2016 |
| 10 | Arntzenius, Krishnaswami | Datafun: A Functional Datalog | ICFP | 2016 |
| 11 | Arntzenius, Krishnaswami | Seminaive Evaluation for a Higher-Order Functional Language | POPL | 2020 |
| 12 | Swift, Warren | XSB: Extending Prolog with Tabled Logic Programming | TPLP | 2012 |
| 13 | Cousot, Cousot | Abstract Interpretation: A Unified Lattice Model | POPL | 1977 |
| 14 | Cousot, Cousot | A Galois Connection Calculus for Abstract Interpretation | POPL | 2014 |
| 15 | Fruhwirth | Constraint Handling Rules (book) | CUP | 2009 |
| 16 | Hellerstein | Keeping CALM: When Distributed Consistency is Easy | CACM | 2020 |
| 17 | Denecker, Marek, Truszczynski | Approximation Fixpoint Theory and Logic Program Semantics | 2012 | 2012 |
| 18 | Gupta et al. | Parallel Execution of Prolog Programs: A Survey | TOPLAS | 2001 |
| 19 | Clark, Gregory | PARLOG: Parallel Programming in Logic | TOPLAS | 1986 |
| 20 | Meiklejohn, Roy | Lasp: A Language for Distributed, Coordination-Free Programming | PPDP | 2015 |
| 21 | Sahebolamri et al. | Ascent: Seamless Deductive Inference via Macros | CC | 2023 |
| 22 | Laddad, Power | Keep CALM and CRDT On | VLDB | 2023 |
| 23 | Kmett | Guanxi / Propagators (talks + code) | FnConf | 2019 |
