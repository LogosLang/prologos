# Research: Recovering Order-Dependent Effects on a Propagator Substrate

**Date**: 2026-03-06
**Context**: IO Implementation PIR §4a — "Propagator Networks Cannot Order Side Effects"
**Status**: Research document — explores architectural paths forward
**Prerequisite Reading**: `2026-03-06_IO_IMPLEMENTATION_PIR.md` §4a, `2026-02-24_LOGIC_ENGINE_DESIGN.org` Appendix B

---

## 1. The Problem, Precisely

Propagator networks compute monotone fixed points. During `run-to-quiescence`,
propagators fire in worklist order — effectively nondeterministic from the
programmer's perspective. This is a feature, not a bug: it's what makes
propagators composable, parallelizable, and amenable to confluence proofs.

But IO operations are inherently order-dependent:

```
write "hello" to file
write " world" to file
close file
```

These three effects must execute in exactly this sequence. Reordering produces
different (incorrect) results. A propagator that writes "hello" and a propagator
that writes " world" have no lattice-theoretic relationship that determines
which fires first. The worklist is a FIFO queue, not a causal ordering.

### What We Tried

The IO bridge propagator (`io-bridge.rkt`) was designed to watch session cells
and fire IO side effects as sessions advance: `io-opening → io-open → io-closed`.
The IO state lattice is genuinely monotone — each transition moves up the
lattice, never down. But the *within-state* effects (multiple writes while in
`io-open`) have no lattice ordering. Two write propagators in the same `io-open`
state are concurrent from the lattice's perspective.

### What We Did Instead

Direct IO execution during `compile-live-process`. The compilation walk visits
process AST nodes in syntactic order (which is sequential), executing IO inline.
The propagator network handles type-level session advancement; the effects
themselves bypass propagation entirely.

### The Question

Is this fundamental? Or can we design a multi-layered propagator architecture
that *recovers* sequential effect ordering on a convergent substrate — the way
the logic engine recovered choice-point semantics and non-monotonic negation
on the same substrate through layered controls?

---

## 2. What the IOPropNet Serves Today

Even with direct effect execution, the IO infrastructure on the propagator
network provides real value:

### 2a. IO State Tracking

The `io-state` lattice (`io-bot → io-opening → io-open → io-closed → io-top`)
tracks the lifecycle of a file handle as a lattice element. This gives us:

- **Contradiction detection**: Attempting to write to a closed file pushes
  `io-closed ⊔ io-open → io-top` — a contradiction. The propagator network
  detects this automatically, without explicit error-checking code.
- **Completeness checking**: After process execution, cells stuck at `io-open`
  indicate unclosed resources — a resource leak. This is type-level, not
  runtime-level.

### 2b. Session Protocol Enforcement

The session type propagators (`session-propagators.rkt`) enforce that IO
operations follow declared protocols. A `FileRead` protocol expects
`?String . end` — the session cell tracks this contract independently
of the actual IO execution. If the process sends a write on a read-only
protocol, the session cell reaches `sess-top` (contradiction) before any
file operation occurs.

### 2c. Cross-Domain Bridging

The session-type bridge (Galois connection) links session advancement to
type checking. When a process sends a `String` on a channel, the session
propagator verifies the type matches the protocol's expected type.
This bridging works precisely because it's convergent — the bridge
propagator doesn't care about ordering, only about the final lattice state.

### 2d. Capability Verification

Capability types flow through the propagator network as erased `:0` binders.
The elaborator's `insert-implicits-with-tagging` resolves capability
requirements from `current-capability-scope`. This is pure type-level
reasoning — no effects, no ordering needed. The propagator network is
exactly the right tool here.

### Summary

The IOPropNet today handles everything *except* effect sequencing — which is
exactly what propagators are bad at, and exactly what sequential execution
is good at. The current split (propagators for verification, sequential walk
for execution) is coherent, not accidental.

---

## 3. The Logic Engine Precedent

The Prologos logic engine faced an analogous challenge: propagator networks
are monotone, but logic programming requires non-monotonic operations
(negation-as-failure, aggregation, cut) and nondeterministic search
(choice points, backtracking). These seem fundamentally incompatible with
a convergent fixed-point computation.

The solution was a three-layer architecture with increasing expressive power:

### Layer 1: PropNetwork (Monotone Fixed Points)

Pure Datalog-style computation. Facts accumulate monotonically in table
cells via set-union merge. Propagators compute transitive closures, join
operations, and base-case instantiation. Everything converges. No
ordering needed.

### Layer 2: ATMS (Hypothetical Reasoning)

The Assumption-Based Truth Maintenance System adds *choice points* (`amb`)
without breaking monotonicity. Each assumption creates a labeled branch;
values are tagged with their support sets (which assumptions justify them).
The ATMS doesn't choose between alternatives — it tracks *all* alternatives
simultaneously, filtering inconsistent combinations via nogoods.

Key insight: **the ATMS is still monotone**. Adding an assumption never
removes one. Adding a nogood never removes one. The supported-value lattice
grows monotonically. What changes is the *worldview* — a filter over the
fixed point. Worldview switching is O(1) (`struct-copy` the `believed` set).

### Layer 3: Stratification (Non-Monotonic Barriers)

Negation-as-failure (`not`) requires reading a predicate's *complete*
extension — impossible during monotone propagation because more facts might
arrive. The solution: stratify the program into layers, evaluate each
layer to its fixed point, then *freeze* its tables before the next layer
reads them.

This is the critical precedent. Stratification introduces **barriers**
between monotone phases. Within each stratum, computation is purely
convergent. Between strata, there's a sequential ordering enforced by the
stratification schedule. Negation crosses strata — it reads frozen results
from a lower stratum.

### The Pattern

```
Monotone computation (within strata)  ← propagators handle this
  +
Sequential barriers (between strata)  ← stratification schedule handles this
  +
Nondeterministic search (across worldviews) ← ATMS handles this
  =
Full logic programming on a propagator substrate
```

The logic engine didn't make propagators non-monotone. It *layered*
additional control structures *on top of* the monotone substrate,
recovering the needed expressiveness at each layer while keeping the
substrate's guarantees intact.

---

## 4. External Research: What Others Have Found

### 4a. The CALM Theorem (Hellerstein, Alvaro, Conway et al.)

The CALM theorem (Consistency As Logical Monotonicity) states:

> A program has a consistent, coordination-free distributed implementation
> if and only if it is monotonic.

Non-monotonic operations are "points of order" — locations where
coordination (locks, barriers, consensus) is required. The Bloom language
makes this analysis automatic: the compiler identifies non-monotonic
operators and warns the programmer that coordination is needed there.

**Implication for Prologos**: IO effects are inherently non-monotonic
(writing to a file is not idempotent; order matters). By CALM, any
propagator-based system handling IO *must* introduce coordination at
effect boundaries. The question is what form that coordination takes.

*Sources*:
- [CALM: Consistency as Logical Monotonicity](http://bloom-lang.net/calm/)
- [Keeping CALM: When Distributed Consistency is Easy](https://arxiv.org/pdf/1901.01930)
- [Consistency Analysis in Bloom](https://people.ucsc.edu/~palvaro/cidr11.pdf)

### 4b. BloomL: Logic and Lattices for Distributed Programming (Conway et al.)

BloomL extends Bloom with user-defined lattices and cross-lattice morphisms.
Programs compose lattice operations via monotone functions; the CALM
analysis verifies that the composition remains coordination-free.

Key concepts:
- **Morphisms**: Structure-preserving maps between lattices (monotone +
  preserve joins). More restrictive than general monotone functions, but
  enable compositional reasoning.
- **Monotone functions**: Weaker than morphisms but still safe for
  coordination-free execution.
- **Points of order**: Identified automatically where non-monotonic
  operations require coordination.

**Implication for Prologos**: IO operations that are internally monotone
(append-only logs, accumulating counters) can be modeled as lattice
morphisms and executed via propagators without coordination. Only
truly order-dependent operations (overwriting writes, file truncation,
close-then-reopen) require barriers.

*Sources*:
- [Logic and Lattices for Distributed Programming](https://www.neilconway.org/docs/socc2012_bloom_lattices.pdf)
- [BloomL](https://dsf.berkeley.edu/bloom-lattice/)

### 4c. LVars: Lattice-Based Deterministic Parallelism (Kuper & Newton)

LVars are shared mutable variables with lattice-ordered writes (put = join)
and **threshold reads** (block until a lower bound is crossed). This
ensures determinism: every execution produces the same result regardless
of scheduling.

Extensions add expressiveness without breaking determinism:
- **Event handlers**: Callbacks fired when an LVar's value crosses a
  threshold. These enable an event-driven programming style within the
  lattice framework.
- **Freeze**: After all puts are done, the LVar is frozen, allowing
  a direct read of its contents. Programs with freeze are
  **quasi-deterministic**: they either produce the same answer or raise
  an error, but never silently produce different answers.

The freeze operation is directly analogous to stratification barriers:
it marks the boundary between monotone accumulation and non-monotone
observation.

**Key innovation**: The `Par` monad in LVish (the Haskell implementation)
is *indexed by an effect level*. Different computations are allowed
different effects (put-only, put+get, put+get+freeze). This effect-level
indexing provides static guarantees about which operations a computation
may perform.

**Implication for Prologos**: Our session types already function as a
kind of effect-level index. A `FileRead` protocol permits reads but not
writes. The session type system is doing, at the type level, what LVar
effect levels do at the computation level. The missing piece is connecting
session advancement to a scheduling discipline that respects ordering.

*Sources*:
- [LVars: Lattice-based Data Structures for Deterministic Parallelism](https://users.soe.ucsc.edu/~lkuper/papers/lvars-fhpc13.pdf)
- [Freeze After Writing: Quasi-Deterministic Parallel Programming with LVars](https://users.soe.ucsc.edu/~lkuper/papers/lvish-popl14.pdf)
- [Kuper Dissertation](https://users.soe.ucsc.edu/~lkuper/papers/lindsey-kuper-dissertation.pdf)

### 4d. Timely Dataflow and Differential Dataflow (McSherry et al.)

Timely dataflow stamps every datum with a **logical timestamp** from a
partially ordered set. The system tracks **progress**: which timestamps
can still appear in the future. An operator knows it can safely process
all data at timestamp *t* when it's guaranteed no more data at timestamps
≤ *t* will arrive.

This is lattice-ordered time: timestamps form a lattice (product of
loop-counter × epoch × ...), and progress is a monotone function over
this lattice. The effect ordering emerges from the timestamp partial
order, not from physical scheduling.

Differential dataflow builds on this by tracking *differences* between
collections at different timestamps, enabling incremental recomputation.

**Implication for Prologos**: Timestamps are a way to introduce ordering
into a lattice-based system without abandoning the lattice structure.
Each IO effect could carry a timestamp; the IO bridge could batch and
execute effects in timestamp order at barriers. This is essentially
"propagators with logical time."

*Sources*:
- [Differential Dataflow](http://www.frankmcsherry.org/differential/dataflow/2015/04/07/differential.html)
- [Timely Dataflow (Rust)](https://github.com/TimelyDataflow/timely-dataflow)
- [Naiad/Timely Dataflow Model](https://link.springer.com/chapter/10.1007/978-3-319-19195-9_9)

### 4e. Radul & Sussman: The Revised Report on the Propagator Model

The foundational propagator work acknowledges the side-effect question
explicitly. Effects in the propagator model are handled through the
`merge` function — when new information arrives at a cell, `merge`
determines what happens. All built-in effects "commute" — their
execution order doesn't matter.

For non-commutative effects, Radul's thesis notes that propagators are
not the right execution model. The propagator model is a *constraint*
model, not an *imperative* model. Effects that must be ordered require
an imperative layer.

**Implication for Prologos**: This confirms our PIR §4a finding from
first principles. The propagator model's designers explicitly excluded
non-commutative effects from the model's scope.

*Sources*:
- [Revised Report on the Propagator Model](https://groups.csail.mit.edu/mac/users/gjs/propagators/)
- [The Art of the Propagator](https://dspace.mit.edu/handle/1721.1/44215)
- [Radul PhD Thesis](https://groups.csail.mit.edu/genesis/papers/radul%202009.pdf)

### 4f. Kmett's Propagators and the CRDTs Connection

Edward Kmett's propagator library connects propagators to CRDTs, Datalog,
SAT solving, and FRP — all domains where convergent fixed-point iteration
is the core computation pattern. His key insight: propagators are the
*computational* analog of CRDTs' *data* convergence. Both achieve
eventual consistency through monotone lattice operations.

The `guanxi` project (a logic programming framework in Haskell) extends
this with relational programming, leaning on propagators and algebraic
structures. This is the closest existing work to Prologos's approach.

**Implication for Prologos**: CRDTs and propagators share the same
mathematical foundation (monotone functions on join-semilattices).
This means CRDT techniques for handling causal ordering (vector clocks,
dotted version vectors) could potentially be adapted for propagator
effect scheduling.

*Sources*:
- [Kmett's Propagators (GitHub)](https://github.com/ekmett/propagators)
- [Propagators talk, FnConf 2019](https://confengine.com/functional-conf-2019/proposal/12713/propagators)

### 4g. CRDTs and Causal Ordering

State-based CRDTs (CvRDTs) achieve convergence through a merge function
that's a lattice join — identical to propagator cell merge. But CRDTs
face the same ordering problem: concurrent updates from different replicas
may need causal ordering to make semantic sense.

Solutions in the CRDT literature:
- **Vector clocks**: Each replica maintains a vector of logical timestamps.
  Updates carry the vector, enabling causal ordering reconstruction.
- **Dotted version vectors**: More compact causal context tracking.
- **Causal CRDTs**: The state has two components — a *dot store*
  (lattice-ordered data) and a *causal context* (version vector tracking
  the causal history). The dot store is monotone; the causal context
  provides ordering metadata.

**Key insight**: CRDTs separate the *data plane* (monotone, convergent)
from the *ordering plane* (causal context, version vectors). The data
converges independently of order; the ordering metadata enables
reconstruction of causal history when needed.

*Sources*:
- [CRDTs (Wikipedia)](https://en.wikipedia.org/wiki/Conflict-free_replicated_data_type)
- [Conflict-free Replicated Data Types (Shapiro et al.)](https://inria.hal.science/hal-00932836/document)
- [Vector Clocks (Wikipedia)](https://en.wikipedia.org/wiki/Vector_clock)

### 4h. Reactive Programming and Glitch-Free Propagation

Reactive programming systems face a version of the ordering problem:
when a source value changes, dependent computations must update in the
right order to avoid "glitches" (momentary inconsistencies where some
values reflect the new input and others still reflect the old).

The solution: **topological sort** of the dependency graph. Propagate
changes in topological order — a node is updated only after all its
dependencies have been updated.

**Implication for Prologos**: If IO effects are modeled as nodes in a
dependency graph with explicit ordering edges, the propagator scheduler
could use topological sort to determine firing order — at least for
the effect-producing subset of propagators.

*Sources*:
- [Reactive Programming (Wikipedia)](https://en.wikipedia.org/wiki/Reactive_programming)
- [Topologica (dataflow library)](https://github.com/datavis-tech/topologica)

### 4i. Algebraic Effects and Handlers

Algebraic effect handlers provide a principled way to introduce effects
into pure computation. Effects are typed operations; handlers give them
semantics. Critically, handlers are *non-monotone* — they can transform
an effectful computation into a pure one, deleting effects from types.

Sequential effect systems use "effect quantales" — ordered monoids with
a partial order. Sequential composition respects the partial order,
providing a lattice-compatible notion of effect ordering.

**Implication for Prologos**: Algebraic effect handlers suggest that
effects and their ordering can be separated from the computation that
produces them. The computation is pure (propagators); the handler
provides the sequential ordering (stratification/barriers).

*Sources*:
- [Handlers of Algebraic Effects (Plotkin & Pretnar)](https://homepages.inf.ed.ac.uk/gdp/publications/Effect_Handlers.pdf)
- [Polymorphic Iterable Sequential Effect Systems](https://dl.acm.org/doi/fullHtml/10.1145/3450272)

### 4j. Flix: Datalog Extended with Lattices

Flix is a language for fixed-point computations on lattices, extending
Datalog with user-defined lattice types and monotone transfer functions.
Like BloomL, Flix enforces monotonicity as a core requirement —
non-monotone operations are rejected at compile time.

Flix uses semi-naive evaluation (incremental fixed point), with lattice
elements merged via join at each iteration. The evaluation is inherently
unordered within each iteration.

**Implication for Prologos**: Flix validates that lattice-based
fixed-point computation is a viable foundation for a practical language.
But Flix handles effects the way we do: outside the lattice framework
entirely, via a separate effect system.

*Sources*:
- [From Datalog to Flix (PLDI 2016)](https://plg.uwaterloo.ca/~olhotak/pubs/pldi16.pdf)
- [Flix Documentation](https://doc.flix.dev/fixpoints.html)

---

## 5. Synthesis: Three Candidate Architectures

Drawing from the logic engine precedent and the external research, here
are three candidate architectures for recovering effect ordering on the
propagator substrate. They represent increasing ambition and complexity.

### Architecture A: Stratified Effect Barriers (Most Conservative)

**Analogy**: Logic engine stratification — barriers between monotone phases.

**Mechanism**: Organize IO effects into *strata*, just as negation-as-failure
uses strata for non-monotonic reads.

```
Stratum 0: Pure computation (type checking, session verification)
  → propagator fixed point
  → BARRIER (freeze all type/session cells)

Stratum 1: Effect collection
  → walk process AST, collect effect descriptors into an ordered list
  → no propagation — just accumulation

Stratum 2: Effect execution
  → execute collected effects in order
  → update IO state cells with results

Stratum 3: Post-effect verification
  → propagator fixed point over IO state cells
  → detect resource leaks (unclosed handles), protocol violations
```

**Advantages**:
- Directly reuses the stratification infrastructure we already have
- Clean separation between verification (propagators) and execution (sequential)
- No modification to the propagator core
- Already essentially what we do today, just formalized

**Disadvantages**:
- Effects cannot interleave with computation (no "read file, compute on
  contents, write result" as a single propagation)
- Limited to batch-style IO: collect all effects, execute all at once

**Assessment**: This is roughly what we have today, formalized. It's
correct but not ambitious. It doesn't answer the deeper question of
whether the propagator substrate itself can handle effects.

### Architecture B: Timestamped Effect Cells (Moderate Ambition)

**Analogy**: Timely dataflow — logical timestamps on data, progress tracking.
Also: CRDTs with causal context separation.

**Mechanism**: Extend propagator cells with a *timestamp lattice* that
encodes causal ordering. Effect cells carry timestamps; the scheduler
respects timestamp order when executing side effects.

```
Cell types:
  - Pure cell:    value ∈ Lattice (existing)
  - Effect cell:  (timestamp × effect-descriptor) ∈ Timestamped-Effect-Lattice
  - IO state cell: io-state ∈ IO-Lattice (existing)

Timestamp lattice:
  - Elements: Natural numbers (totally ordered) or vectors (partially ordered)
  - Join: max (for total order) or component-wise max (for vector)
  - Timestamps are assigned by the process AST walk (syntactic position)

Effect cell merge:
  - Accumulates effects into a timestamp-ordered sequence
  - merge(effects₁, effects₂) = sort(effects₁ ∪ effects₂) by timestamp
  - This IS monotone: adding more effects only grows the sequence

Execution:
  - After propagation reaches quiescence, read all effect cells
  - Execute effects in timestamp order
  - Feed results back into the network (new propagation round)
```

**Example**:
```
Process AST:                     Effect cells after propagation:
  (send "hello" ch)              → effect-cell-1: (t=1, write "hello")
  (send " world" ch)             → effect-cell-2: (t=2, write " world")
  (recv result ch)               → effect-cell-3: (t=3, read)
  stop                           → effect-cell-4: (t=4, close)

Execution phase: execute in timestamp order → correct IO sequence
```

**Key insight from CRDTs**: The effect *descriptors* accumulate monotonically
(that's the data plane). The *timestamps* provide causal context (that's
the ordering plane). The two concerns are separated, just as in causal
CRDTs.

**Advantages**:
- Effects are first-class lattice values — they participate in propagation
- Timestamp ordering is deterministic (derived from syntax, not scheduling)
- Supports interleaved computation and IO: compute → collect effects →
  execute → feed results → compute more
- Progressive: can implement in stages

**Disadvantages**:
- Adds complexity to the cell and merge infrastructure
- The "execute in timestamp order after quiescence" step is still
  sequential — the substrate doesn't execute effects itself
- Timestamp assignment for dynamically spawned processes is non-trivial
  (vector timestamps may be needed for `proc-par`)

**Assessment**: This is a genuine extension of the propagator model.
It separates the monotone accumulation of effect descriptors (what
propagators are good at) from the sequential execution of those
effects (what a scheduler is good at). The effect cells participate
in type checking and protocol verification as lattice values; the
execution phase respects their ordering metadata.

### Architecture C: Reactive Effect Streams with Topological Scheduling (Most Ambitious)

**Analogy**: Reactive programming (glitch-free propagation via topological
sort) + LVars (threshold reads with event handlers) + algebraic effects
(computation-handler separation).

**Mechanism**: Model IO operations as nodes in a directed acyclic graph
(DAG) with explicit ordering edges. The propagator scheduler uses the
DAG's topological order to determine firing sequence for effect-producing
propagators.

```
IO-DAG construction:
  - Each IO operation in the process AST becomes a node
  - Sequential operations get ordering edges: op₁ → op₂
  - Parallel operations (proc-par) get no ordering edges (concurrent)
  - Dependencies (output of read used by write) get data-flow edges

Scheduling:
  - Non-effect propagators: fire in any order (existing behavior)
  - Effect propagators: fire in topological order of the IO-DAG
  - After each effect propagator fires, feed results back into the network
  - Run non-effect propagators to quiescence between effect firings

Execution model:
  run_to_quiescence(non-effect propagators)
  while IO-DAG has unfired nodes:
    fire next effect node in topological order
    run_to_quiescence(non-effect propagators)  // may trigger new constraints
```

This is essentially the **reactive programming glitch-free** model
applied to the propagator network: effect propagators are the "sources,"
non-effect propagators are the "derived values," and the IO-DAG provides
the scheduling discipline.

**Freeze semantics (from LVars)**: After an IO operation completes, its
result cell is *frozen* — no more writes allowed. This prevents later
propagation from invalidating a result that has already been used for
an IO decision. Freeze provides quasi-determinism: the program either
produces the correct answer or raises an error if a frozen cell receives
a conflicting write.

**Handler semantics (from algebraic effects)**: Effect-producing
propagators don't *perform* effects directly. They *describe* effects
(as data). The IO handler interprets these descriptions, executing them
in the topologically-determined order. This separates the propagator's
concern (what effect is needed) from the handler's concern (when and
how to execute it).

**Advantages**:
- Effects are fully integrated into the propagator network
- Ordering is derived from the process structure, not imposed externally
- Supports interleaving: computation ↔ IO within a single propagation
- The IO-DAG is a compile-time artifact — scheduling overhead is minimal
- Freeze provides a formal safety guarantee (quasi-determinism)

**Disadvantages**:
- Significant complexity: two-class scheduler (effect vs. non-effect),
  IO-DAG construction, freeze semantics
- The IO-DAG must be constructed before propagation begins —
  dynamically-determined IO operations (IO in loops, conditional IO)
  require the DAG to be extended at runtime
- Freeze violations (writing to a frozen cell) may surface non-obvious
  errors in complex programs

**Assessment**: This is the most expressive architecture and the most
faithful to the "propagator as universal substrate" vision. It doesn't
make propagators sequential — it adds a scheduling layer that respects
ordering constraints for the effect subset while preserving unordered
convergence for everything else. But the implementation complexity is
high, and the benefits over Architecture B are marginal for Phase 0.

---

## 6. The CRDT Connection: Deeper Analysis

The user specifically asked whether CRDTs give us clues. They do, but
the connection is more structural than operational.

### 6a. Shared Foundation

Both CRDTs and propagator cells are based on join-semilattices with
monotone merge. The mathematical structure is identical:

| Concept | CRDT | Propagator Cell |
|---------|------|-----------------|
| State | Lattice element | Cell value |
| Update | State merge (join) | Cell write (merge) |
| Convergence | All replicas converge to same join | Network reaches fixed point |
| Ordering guarantee | Eventually consistent | Quiescent |
| Causal metadata | Vector clocks / dotted version vectors | None (today) |

### 6b. The Causal Context Lesson

CRDTs separate *data* from *causality metadata*. A G-Counter CRDT stores
both the count (lattice value) and the version vector (causal context).
The count converges independently of the vector; the vector enables
reconstructing the causal history.

Prologos could adopt this pattern: **effect cells carry both a lattice
value (the effect descriptor, monotonically accumulated) and a causal
context (a timestamp or position marker, monotonically accumulated)**.
The data plane converges via propagation; the causal plane provides
ordering metadata for execution.

### 6c. What CRDTs Can't Tell Us

CRDTs handle *data convergence* — making sure all replicas agree on the
final state. They don't handle *effect ordering* directly. An OR-Set
CRDT handles concurrent adds and removes, but it doesn't tell you
*when* to execute a side effect that depends on the set's contents.

The CRDT insight for Prologos is about **metadata architecture** (separate
data from ordering), not about **effect execution** (how to sequence
side effects). The execution model must come from elsewhere —
stratification barriers, topological scheduling, or explicit handlers.

---

## 7. The Logic Engine Lesson, Generalized

The logic engine's three-layer architecture recovered non-monotonic
semantics on a monotone substrate through a principle that can be
generalized:

### The Layered Recovery Principle

> Non-monotone behavior can be recovered on a monotone substrate by
> introducing **control layers** that operate *between* phases of monotone
> computation, not *within* them. Each layer adds one form of non-monotone
> expressiveness while preserving the substrate's convergence guarantees
> within each phase.

Applied to the logic engine:
- **Layer 1** (PropNetwork): Monotone fixed point → Datalog
- **Layer 2** (ATMS): Hypothetical branching → nondeterministic search
- **Layer 3** (Stratification): Freeze + barrier → negation-as-failure

Applied to effect ordering:
- **Layer 1** (PropNetwork): Monotone fixed point → type checking, session verification
- **Layer 2** (Timestamp/Effect cells): Causal metadata → effect ordering reconstruction
- **Layer 3** (Barriers/Handlers): Sequential execution → actual IO

The pattern is the same: the substrate remains monotone; the layers
add progressively more powerful control without compromising the
substrate's guarantees.

### Is There a Layer 2 Analog for Effects?

In the logic engine, Layer 2 (ATMS) adds the ability to *track
alternatives without choosing*. The analog for effects would be to
*describe effects without executing them* — to accumulate effect
descriptors monotonically in cells, with ordering metadata, and
defer execution to a handler that respects the ordering.

This is exactly Architecture B (Timestamped Effect Cells). The effect
cell accumulates descriptions monotonically (join = union); the handler
executes them in timestamp order. The effect cell is the "ATMS" of the
IO layer — it tracks what needs to happen without doing it, deferring
the "doing" to a separate execution phase.

### Is There a Layer 3 Analog for Effects?

In the logic engine, Layer 3 (Stratification) introduces barriers
between monotone phases. The analog for effects is already present
in Architecture A (Stratified Effect Barriers): verify first, collect
effects, execute sequentially, verify post-conditions.

The barrier approach is the simplest correct solution. It's what we
do today, and it works.

---

## 8. Proposed Path Forward

### Phase 0 (Current): Stratified Barriers — Already Implemented

The current `compile-live-process` approach is essentially Architecture A
without the formal stratum language. Effects execute sequentially during
the AST walk; propagators handle verification. This is correct and
sufficient for Phase 0.

**No changes needed.**

### Phase 1 (Near-term): Formalize the Architecture

Document the current approach as "Stratified Effect Barriers" in the
architectural principles. Make the implicit strata explicit:

1. Pre-execution stratum: type checking, capability verification, protocol enforcement
2. Execution stratum: sequential effect execution via AST walk
3. Post-execution stratum: resource leak detection, protocol completion checking

This costs nothing to implement — it's documentation of what we already do.

### Phase 2 (Medium-term): Timestamped Effect Cells

When the concurrent runtime is built (deferred from S8b), Architecture B
becomes relevant. Concurrent processes produce effects on independent
timelines; timestamps (vector clocks for concurrent processes) provide
the causal ordering needed to sequence their execution.

Key design questions for Phase 2:
- Are timestamps syntactic positions (simple, static) or logical clocks
  (dynamic, more expressive)?
- How do `proc-par` effects interleave? (Vector timestamps suggest
  partial order — concurrent effects from independent branches can
  execute in either order if they don't conflict)
- Does the effect cell merge function need to handle conflicts?
  (Concurrent writes to the same file from parallel processes)

### Phase 3 (Long-term): Full Reactive Effect Integration

Architecture C — topological scheduling of effect propagators with
freeze semantics — is the end goal if we want effects to be fully
integrated into the propagator substrate. This would enable:
- Effect-aware propagation: a propagator that produces an effect *and*
  consumes the effect's result in a single network
- Compile-time effect ordering analysis (the IO-DAG is a static artifact)
- Formal quasi-determinism guarantees via freeze

This is a research problem, not an engineering task. It should be
explored in a prototype before being integrated into the main system.

---

## 9. Open Questions

### 9a. Can Append-Only Effects Be Propagator-Native?

Some IO operations are inherently monotone: appending to a log, incrementing
a counter, adding to a set. These could potentially be executed *during*
propagation (not deferred to a barrier) because their ordering doesn't
matter — appending "hello" then " world" and appending " world" then
"hello" produce the same log (if the log is a multiset, not a sequence).

For truly append-only semantics, a propagator that appends to a file
on every firing is safe — the file's contents form a multiset lattice.
This is a special case but a practically useful one (audit logs, event
streams, message queues).

### 9b. What About Idempotent Effects?

An HTTP PUT is idempotent — calling it multiple times with the same
payload has the same result as calling it once. Idempotent effects
commute and are safe for unordered propagator execution. The propagator
model explicitly supports this: "all effects built into Scheme-Propagators
are independent, in that their executions commute" (Radul).

Can we partition IO operations into idempotent (safe for propagators)
and non-idempotent (require barriers), and use different scheduling
strategies for each?

### 9c. How Does This Interact with Session Types?

Session types already encode a sequential protocol: `!String . ?Int . end`.
The session advancement is monotone (the session cell moves from `sess-send`
to `sess-recv` to `sess-end`), but the advancement encodes ordering.

Could session types serve as the "causal context" for IO effects? Instead
of separate timestamps, the session protocol itself provides the ordering:
effect₁ is at session position `!String`, effect₂ is at session position
`?Int`. The session lattice already tracks this advancement monotonically.

This would unify the session type system and the effect ordering system
— the session IS the timeline of effects. This is architecturally elegant
but needs careful formalization.

### 9d. What's the Role of the ATMS for Effects?

The ATMS handles *speculative* computation — tracking multiple possible
worlds. Could speculative IO be useful? For example:
- "If the file exists, read it; otherwise, create it" — two possible
  effect sequences depending on a condition
- The ATMS could track both possibilities until the condition is resolved,
  then execute only the consistent one

This would extend Architecture B with hypothetical effects — effect
descriptors tagged with assumption support sets, executed only for the
consistent worldview. It's the IO analog of `amb` in logic programming.

---

## 10. Conclusions

### 10a. The Fundamental Answer

Propagator networks *cannot* natively order side effects. This is confirmed
by both our empirical experience (PIR §4a) and the foundational literature
(Radul & Sussman explicitly exclude non-commutative effects from the
model's scope). The CALM theorem further confirms that non-monotonic
operations (which order-dependent effects are) require coordination.

### 10b. But Recovery Is Possible

The logic engine precedent demonstrates that non-monotone behavior *can*
be recovered on a monotone substrate through layered controls. The same
principle applies to effects:

1. **Barriers** (Architecture A): Sequential execution between monotone
   verification phases. Already implemented. Correct and sufficient.
2. **Timestamped cells** (Architecture B): Monotone accumulation of
   effect descriptors with causal metadata. Executes in metadata order
   at barriers. Natural extension for concurrent processes.
3. **Topological scheduling** (Architecture C): Full integration of
   effects into the propagator network via DAG-ordered scheduling and
   freeze semantics. Research-level ambition.

### 10c. The Guiding Principle

> **The propagator substrate handles convergent reasoning about effects.
> A control layer handles sequential execution of effects.**

This separation is not a compromise — it's the correct architectural
decomposition. Just as the ATMS doesn't *choose* between alternatives
(it tracks all of them), the propagator network doesn't *execute*
effects (it reasons about their types, capabilities, and protocols).
Execution is a separate concern with a separate scheduling discipline.

### 10d. What This Enables

Understanding this decomposition opens up concrete research directions:
- Session types as causal timelines for effect ordering (§9c)
- Monotone-safe effects (append-only, idempotent) as native propagator
  operations (§9a, §9b)
- Hypothetical effects via ATMS integration (§9d)
- Formal quasi-determinism guarantees via LVar-style freeze (Architecture C)

Each of these can be explored independently, building on the stable
foundation of the current stratified barrier approach.

---

## References

### Prologos Internal
- IO Implementation PIR: `docs/tracking/2026-03-06_IO_IMPLEMENTATION_PIR.md`
- Logic Engine Design: `docs/tracking/2026-02-24_LOGIC_ENGINE_DESIGN.org`
- Propagator Research: `docs/tracking/2026-02-24_TOWARDS_A_GENERAL_LOGIC_ENGINE_ON_PROPAGATORS.org`
- Session Type PIR: `docs/tracking/2026-03-04_SESSION_TYPE_PIR.md`

### External
- [Revised Report on the Propagator Model](https://groups.csail.mit.edu/mac/users/gjs/propagators/) — Radul & Sussman
- [Radul PhD Thesis: Propagation Networks](https://groups.csail.mit.edu/genesis/papers/radul%202009.pdf) — MIT 2009
- [The Art of the Propagator](https://dspace.mit.edu/handle/1721.1/44215) — Radul & Sussman
- [CALM: Consistency as Logical Monotonicity](http://bloom-lang.net/calm/) — Hellerstein
- [Keeping CALM](https://arxiv.org/pdf/1901.01930) — Hellerstein 2019
- [Logic and Lattices for Distributed Programming](https://www.neilconway.org/docs/socc2012_bloom_lattices.pdf) — Conway et al. (BloomL)
- [LVars: Lattice-based Deterministic Parallelism](https://users.soe.ucsc.edu/~lkuper/papers/lvars-fhpc13.pdf) — Kuper & Newton
- [Freeze After Writing: Quasi-Deterministic LVars](https://users.soe.ucsc.edu/~lkuper/papers/lvish-popl14.pdf) — Kuper et al. (POPL 2014)
- [Kuper Dissertation](https://users.soe.ucsc.edu/~lkuper/papers/lindsey-kuper-dissertation.pdf) — UC Santa Cruz
- [Differential Dataflow](http://www.frankmcsherry.org/differential/dataflow/2015/04/07/differential.html) — McSherry
- [Timely Dataflow (Rust)](https://github.com/TimelyDataflow/timely-dataflow) — McSherry et al.
- [Kmett Propagators (GitHub)](https://github.com/ekmett/propagators) — Kmett
- [From Datalog to Flix](https://plg.uwaterloo.ca/~olhotak/pubs/pldi16.pdf) — Madsen et al. (PLDI 2016)
- [Handlers of Algebraic Effects](https://homepages.inf.ed.ac.uk/gdp/publications/Effect_Handlers.pdf) — Plotkin & Pretnar
- [Polymorphic Iterable Sequential Effect Systems](https://dl.acm.org/doi/fullHtml/10.1145/3450272) — Gordon
- [CRDTs (Wikipedia)](https://en.wikipedia.org/wiki/Conflict-free_replicated_data_type)
- [CRDTs (Shapiro et al.)](https://inria.hal.science/hal-00932836/document)
- [Vector Clocks (Wikipedia)](https://en.wikipedia.org/wiki/Vector_clock)
- [Consistency Analysis in Bloom](https://people.ucsc.edu/~palvaro/cidr11.pdf) — Alvaro et al.
- [A Monad for Deterministic Parallelism](https://dl.acm.org/doi/10.1145/2034675.2034685) — Marlow et al.
- [Reactive Programming (Wikipedia)](https://en.wikipedia.org/wiki/Reactive_programming)
