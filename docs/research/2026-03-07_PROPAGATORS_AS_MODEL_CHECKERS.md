- [Abstract](#org82295fd)
- [1. The Correspondence](#org283047b)
  - [1.1 Two Fields, One Structure](#org62deea9)
  - [1.2 Why This Is Not a Metaphor](#orgaa51496)
- [2. The Modal &mu;-Calculus Connection](#org277f965)
  - [2.1 What the &mu;-Calculus Is](#orgab1b93f)
  - [2.2 Mapping to Propagators](#org7873374)
  - [2.3 The Alternation Hierarchy](#org9823ef5)
- [3. What Prologos Already Has](#org3906452)
  - [3.1 Safety Verification (AG &not; bad)](#orgc7d11cf)
  - [3.2 Weak Liveness Verification (AF end)](#orgc7ace51)
  - [3.3 Counterexample Traces (Derivation Chains)](#org148ac75)
  - [3.4 Branching Exploration (ATMS Worldviews)](#org3a2c608)
  - [3.5 Abstract Interpretation (Galois Connections)](#org9db554c)
  - [3.6 Effect Ordering (Causal Model)](#org8dd720d)
- [4. What Would Complete the Picture](#org86a90a8)
  - [4.1 Temporal Property Specification Language](#org49738dc)
  - [4.2 Temporal Property Propagator Factory](#org204d194)
  - [4.3 Greatest Fixpoint Support](#org5fa90a1)
  - [4.4 State Labeling for Session Types](#org9d422f8)
- [5. The ATMS as Universal Path Quantifier](#orgb578e17)
  - [5.1 Paths and Worldviews](#org652dd5d)
  - [5.2 Nogoods as Impossible Paths](#org03b0371)
  - [5.3 Dependency-Directed Backtracking](#org0adc237)
- [6. Abstract Model Checking via Galois Connections](#orgdd33927)
  - [6.1 The Infinite-State Problem](#org6245d38)
  - [6.2 Prologos Already Has the Infrastructure](#org87f0619)
  - [6.3 Application: Recursive Session Type Verification](#orgc504162)
- [7. Incremental Model Checking](#orga3cdaa1)
  - [7.1 The Classical Problem](#org3d6e6a7)
  - [7.2 Propagator Networks Are Incremental](#orgd3088f9)
  - [7.3 Connection to Reactive Verification](#orgafa2d00)
- [8. Tier-Level Accessibility](#org84dd085)
  - [8.1 The Current Landscape](#org637f7e8)
  - [8.2 The Prologos Tier Mapping](#org9025cee)
  - [8.3 What "Invisible" Looks Like](#org1de9f93)
- [9. Concrete Examples from the Endo Analysis](#org262cf68)
  - [9.1 Pin Never Leaked](#org65a1f47)
  - [9.2 GC Ordering Safety](#org437046b)
  - [9.3 Revocation Eventually Propagated](#orga3bbc19)
  - [9.4 Mutex Non-Reentrant](#orgb648827)
- [10. The Propagator Network as Universal Verification Substrate](#org1a8ae00)
  - [10.1 The Composability Principle](#org13bae47)
  - [10.2 Cross-Domain Verification](#org9285e3d)
  - [10.3 The Verification Layer Cake](#org44d0d78)
- [11. Research Program](#orgae440c4)
  - [11.1 Immediate Questions](#orgb732ef8)
  - [11.2 Medium-Term Research](#org22f741e)
  - [11.3 Long-Term Vision](#org5a82694)
- [12. Related Work](#org7deadd3)
  - [12.1 Model Checking as Abstract Interpretation](#orge4a3961)
  - [12.2 Behavioral Types and Verification](#orgf974c5b)
  - [12.3 Multi-Valued Model Checking](#orge63a64a)
  - [12.4 Constraint-Based Model Checking](#orgeebdbba)
- [13. Conclusion](#orgb4b2f88)
- [References](#orgdaf03bf)



<a id="org82295fd"></a>

# Abstract

This document identifies and formalizes a structural isomorphism between propagator-based session type checking (as implemented in Prologos) and temporal-logic model checking (as formalized in CTL, LTL, and the modal &mu;-calculus). The core observation: *both are monotone fixpoint computations over lattices*. Session type decomposition propagators are transition-relation propagators. The ATMS is a path-quantifier. Galois connections are abstract model checking. `run-to-quiescence` is the fixpoint loop. These are not analogies &#x2014; they are the same mathematical structures, arrived at from different starting points.

The consequence is that Prologos's propagator network, originally designed for type inference and session type verification, is simultaneously a general-purpose model checking engine. Every propagator added to the network &#x2014; for type inference, effect ordering, session duality, or constraint solving &#x2014; also contributes to the model checking capability. This document develops this observation into a concrete research program: temporal property specifications that compile to propagator wiring, bringing CTL model checking from Tier 4+ (expert-only TLA+/SPIN tools) to Tier 2 (property annotations on session types, automatically verified).


<a id="org283047b"></a>

# 1. The Correspondence


<a id="org62deea9"></a>

## 1.1 Two Fields, One Structure

Model checking and propagator-based type checking developed independently, but they share a common mathematical substrate:

| Concept                | Model Checking                       | Prologos Propagators                 |
|---------------------- |------------------------------------ |------------------------------------ |
| State space            | Kripke structure `(S, R, L)`         | Session type continuations           |
| State                  | Element of `S`                       | Session cell value                   |
| Transition             | Edge in `R`                          | Session decomposition propagator     |
| State labeling         | `L : S \to 2^{AP}`                   | Session struct type tags             |
| Safety property        | `AG \neg bad`                        | Contradiction detection (`sess-top`) |
| Weak liveness          | `AF end`                             | `check-session-completeness`         |
| Counterexample         | Trace violating property             | ATMS derivation chain                |
| Branching              | Nondeterministic choice              | `+>/&>` session choice               |
| Universal path (`A`)   | Property holds on *all* paths        | All ATMS worldviews satisfy          |
| Existential path (`E`) | Property holds on *some* path        | At least one worldview satisfies     |
| Fixpoint computation   | Tarski-Knaster iteration             | `run-to-quiescence`                  |
| Lattice element        | Subset of states (`2^S`)             | Session lattice value                |
| Join (\sqcup)          | Set union                            | `session-lattice-merge`              |
| Bottom (\bot)          | Empty set                            | `sess-bot`                           |
| Top (\top)             | Full state set / contradiction       | `sess-top`                           |
| Abstract interp.       | Galois connection `(\alpha, \gamma)` | `GaloisConnection` trait instances   |


<a id="orgaa51496"></a>

## 1.2 Why This Is Not a Metaphor

The correspondence is exact, not merely suggestive:

1.  **CTL model checking IS fixpoint computation**. The standard CTL model checking algorithm (Clarke, Emerson, Sistla 1986) computes the denotation of each CTL subformula as a fixpoint over the powerset lattice `2^S`. Specifically:
    
    -   `EF \phi` = `lfp X. \phi \cup pre(X)` &#x2014; least fixpoint
    -   `AG \phi` = `gfp X. \phi \cap pre^{-1}(X)` &#x2014; greatest fixpoint
    -   `A(\phi U \psi)` = `lfp X. \psi \cup (\phi \cap pre^{-1}(X))`
    
    Each of these is a monotone function over a complete lattice, iterated to a fixpoint. This is *exactly* what `run-to-quiescence` does.

2.  **Propagator decomposition IS transition-relation computation**. When `add-send-prop` examines a session cell and writes the continuation to a new cell, it is computing `pre^{-1}({send})` &#x2014; the set of states from which the next transition is a send. The propagator *is* the transition relation, reified as a monotone function between cells.

3.  **The ATMS IS a path quantifier**. The ATMS maintains multiple consistent worldviews (assumption sets), each representing a possible execution path. Checking a property under *all* worldviews is the universal path quantifier (`A`). Checking under *any* worldview is the existential quantifier (`E`). De Kleer's ATMS was designed for exactly this kind of multi-hypothesis reasoning.

4.  **Galois connections ARE abstract model checking**. Clarke, Grumberg, and Long (1992) showed that abstract model checking works by abstracting the concrete state space through a Galois connection `(\alpha, \gamma)` to a smaller abstract state space, model checking on the abstract space, and mapping results back. Prologos already has a `GaloisConnection` trait with `\alpha/\gamma` maps and cross-domain propagators &#x2014; this IS the abstract model checking infrastructure.


<a id="org277f965"></a>

# 2. The Modal &mu;-Calculus Connection

The deepest connection is through the modal &mu;-calculus, which subsumes both CTL and LTL as fragments.


<a id="orgab1b93f"></a>

## 2.1 What the &mu;-Calculus Is

The modal &mu;-calculus (Kozen 1983) extends modal logic with least (&mu;) and greatest (&nu;) fixpoint operators. It can express any property expressible in CTL\*, and many beyond. A &mu;-calculus formula is built from:

-   Atomic propositions: `p, q, r`
-   Boolean connectives: `\phi \land \psi`, `\phi \lor \psi`, `\neg \phi`
-   Modal operators: `\langle a \rangle \phi` (some successor satisfies &phi;), `[a] \phi` (all successors satisfy &phi;)
-   Fixpoint operators: `\mu X. \phi(X)` (least fixpoint), `\nu X. \phi(X)` (greatest fixpoint)

The key insight (Bradfield and Walukiewicz): the &mu;-calculus can be viewed as *an algebra of monotonic functions over a complete lattice*, with operators consisting of functional composition plus the least and greatest fixpoint operators. The lattice is the powerset `2^S` of the state space.


<a id="org7873374"></a>

## 2.2 Mapping to Propagators

Each &mu;-calculus construct maps to a propagator network pattern:

| &mu;-Calculus            | Propagator Pattern                                   |
|------------------------ |---------------------------------------------------- |
| Atomic proposition `p`   | Cell initialized with `p`                            |
| `\phi \land \psi`        | Meet (intersection) propagator                       |
| `\phi \lor \psi`         | Join (union) propagator                              |
| `\langle a \rangle \phi` | Existential transition propagator                    |
| `[a] \phi`               | Universal transition propagator                      |
| `\mu X. \phi(X)`         | Least fixpoint: cell starts at \bot, refines up      |
| `\nu X. \phi(X)`         | Greatest fixpoint: cell starts at \top, refines down |

The fixpoint operators are the critical piece. Currently, Prologos propagators compute *only* least fixpoints (cells start at `sess-bot` and refine upward). Adding greatest fixpoint support would require cells that start at a top value and refine *downward* &#x2014; the dual lattice direction. This is a well-understood extension to the propagator model (it corresponds to over-approximation in abstract interpretation).


<a id="org9823ef5"></a>

## 2.3 The Alternation Hierarchy

The &mu;-calculus has an *alternation hierarchy* &#x2014; formulas with nested alternating least and greatest fixpoints are strictly more expressive than those without. The hierarchy levels correspond to increasing complexity of temporal properties:

| Level | Example Property                               | Formula Pattern              |
|----- |---------------------------------------------- |---------------------------- |
| 0     | State property (no fixpoint)                   | `p`                          |
| 1     | Safety (`AG \phi`) or reachability (`EF \phi`) | `\nu X.\phi` or `\mu X.\phi` |
| 2     | Response (`AG(\phi \to AF \psi)`)              | `\nu X. \mu Y. \ldots`       |
| 3+    | Fairness, complex liveness                     | Deeper alternation           |

Our current session type checker operates at Level 1: contradiction detection is safety (Level 1 greatest fixpoint), session completeness is reachability (Level 1 least fixpoint). The response property (Level 2) &#x2014; "every request eventually gets a response" &#x2014; requires nested fixpoints, which our propagator network can compute but does not yet have an interface for specifying.


<a id="org3906452"></a>

# 3. What Prologos Already Has


<a id="orgc7d11cf"></a>

## 3.1 Safety Verification (AG &not; bad)

When the session type checker detects a contradiction (a cell reaches `sess-top`), it has verified that a process violates its protocol. The *absence* of contradiction is a proof that `AG \neg protocol-violation` holds: on all execution paths, the protocol is never violated.

This is exactly what `check-session-via-propagators` does:

1.  Initialize root session cell with the declared session type
2.  Compile the process tree to propagators (transition relation)
3.  Run to quiescence (fixpoint)
4.  Check for contradictions (safety property violation)


<a id="orgc7ace51"></a>

## 3.2 Weak Liveness Verification (AF end)

`check-session-completeness` verifies that all terminal cells (those constrained by `proc-stop`) have reached `sess-end`. A terminal cell *not* at `sess-end` means the process stopped but the protocol has remaining steps &#x2014; a potential deadlock.

This checks `AF end` in a restricted sense: "if the process terminates, the session is at end." It does not verify that the process *will* terminate (strong liveness), but it verifies that termination implies protocol completion.


<a id="org148ac75"></a>

## 3.3 Counterexample Traces (Derivation Chains)

When a property is violated, the ATMS derivation chain provides a counterexample: the sequence of operations that led to the contradiction. This is the propagator equivalent of the counterexample trace in classical model checking. The `build-session-error` function extracts the derivation from the trace map.


<a id="org3a2c608"></a>

## 3.4 Branching Exploration (ATMS Worldviews)

The ATMS (Phase 5 of the Logic Engine) supports multiple simultaneous worldviews. Each worldview is a set of assumptions that are believed to hold. `solve-all` enumerates all consistent assumption sets. This is the mechanism for exploring the computation tree: each `+>/&>` branch becomes an assumption, and the ATMS explores all consistent combinations.


<a id="org9db554c"></a>

## 3.5 Abstract Interpretation (Galois Connections)

The `GaloisConnection` trait and cross-domain propagators (Phase 6 of the Logic Engine) provide the infrastructure for abstract model checking:

-   `\alpha : Concrete \to Abstract` &#x2014; abstraction map
-   `\gamma : Abstract \to Concrete` &#x2014; concretization map
-   `net-add-cross-domain-propagator` &#x2014; bridges concrete and abstract cells
-   Widening (`Widenable` trait) &#x2014; accelerates fixpoint convergence for infinite-height lattices

This is precisely the Clarke-Grumberg-Long framework for abstract model checking, implemented as a composable propagator pattern.


<a id="org8dd720d"></a>

## 3.6 Effect Ordering (Causal Model)

The effect position lattice (Architecture A+D, recently completed) tracks causal ordering of effects through session type structure. The positions form a lattice with data-flow edges capturing cross-channel dependencies. Transitive closure over these edges detects cycles &#x2014; which are *deadlocks*.

This is a form of causal model checking: verifying that the causal ordering of events in a protocol does not contain cycles. The CALM theorem (Hellerstein

1.  tells us that non-monotone operations require coordination &#x2014; and the

effect ordering lattice makes the coordination requirements explicit and checkable.


<a id="org86a90a8"></a>

# 4. What Would Complete the Picture


<a id="org49738dc"></a>

## 4.1 Temporal Property Specification Language

The immediate gap is a way for users to *specify* temporal properties beyond the structural properties implicit in session types. The goal is a property language that:

1.  Uses familiar Prologos syntax (not raw &mu;-calculus)
2.  Compiles to propagator wiring (not a separate engine)
3.  Composes with existing session types (not a parallel system)

```prologos
;; --- Hypothetical temporal property syntax ---

;; Safety: "the pin is never held while GC is running"
property pin-gc-safe
  :session Pin-Guard
  :always [not [and :pinned :gc-collecting]]

;; Liveness: "every pin acquisition is eventually followed by release"
property pin-released
  :session Pin-Guard
  :always [implies :pinned [eventually :unpinned]]

;; Response: "every request eventually gets exactly one response"
property request-response
  :session CapTP-Steady
  :always [implies [sent :call] [eventually [received :return]]]

;; Fairness: "every offered branch is eventually selected"
property fair-scheduling
  :session Worker-Protocol
  :fair [offered :evaluate :terminate]

;; Bounded liveness: "the pin is released within 100 steps"
property pin-bounded
  :session Pin-Guard
  :within 100 [implies :pinned :unpinned]
```

Each property keyword maps to a temporal operator:

| Property Keyword | Temporal Logic      | &mu;-Calculus                            | Fixpoint |
|---------------- |------------------- |---------------------------------------- |-------- |
| `:always`        | `AG`                | `\nu X. \phi \land [a]X`                 | Greatest |
| `:eventually`    | `AF`                | `\mu X. \phi \lor [a]X`                  | Least    |
| `:never`         | `AG \neg`           | `\nu X. \neg \phi \land [a]X`            | Greatest |
| `:implies`       | `AG(\phi \to \psi)` | `\nu X. (\neg\phi \lor \psi) \land [a]X` | Greatest |
| `:until`         | `A(\phi U \psi)`    | `\mu X. \psi \lor (\phi \land [a]X)`     | Least    |
| `:within N`      | Bounded `AF`        | Unrolled `N` times                       | Bounded  |
| `:fair`          | Fairness constr.    | Nested alternation                       | Level 2+ |


<a id="org204d194"></a>

## 4.2 Temporal Property Propagator Factory

A function that takes a temporal property specification and generates the corresponding propagator wiring:

```
add-temporal-prop : Network -> SessionCell -> TemporalFormula -> Network
```

The construction follows the standard CTL model checking algorithm, but expressed as propagator creation rather than set iteration:

1.  **`AG \phi`**: Create a cell `C_\phi` initialized at the lattice top. Add a greatest-fixpoint propagator that refines `C_\phi` downward: at each step, `C_\phi :` &phi; \sqcap \bigcap<sub>s' &isin; succ(s)</sub> C<sub>&phi;</sub>(s')=. When quiescent, `C_\phi` contains exactly the states satisfying `AG \phi`.

2.  **`EF \phi`**: Create a cell `C_\phi` initialized at `\bot`. Add a least-fixpoint propagator that refines `C_\phi` upward: at each step, `C_\phi :` &phi; \sqcup \bigcup<sub>s' &isin; succ(s)</sub> C<sub>&phi;</sub>(s')=. When quiescent, `C_\phi` contains exactly the states from which &phi; is reachable.

3.  **`AG(\phi \to AF \psi)`**: Nested fixpoints. First compute `AF \psi` (least fixpoint), then check `AG(\phi \to result)` (greatest fixpoint). The propagator network handles this naturally &#x2014; the inner fixpoint stabilizes first, then the outer fixpoint uses the stabilized inner result.

4.  **Bounded `AF \psi` within N**: Unroll the fixpoint `N` times instead of iterating to convergence. Create `N` cells, each representing one step of the unrolling. This is bounded model checking, expressed as a fixed-depth propagator chain.


<a id="org5fa90a1"></a>

## 4.3 Greatest Fixpoint Support

Currently, all propagator cells start at `sess-bot` and refine upward (least fixpoint). Safety properties (greatest fixpoints) require the dual: cells that start at a top value and refine *downward*.

The extension is straightforward:

1.  Add a `cell-direction` flag: `:ascending` (least fixpoint, default) or `:descending` (greatest fixpoint)
2.  For descending cells, `net-cell-write` uses `meet` instead of `join`
3.  Contradiction for descending cells is reaching \bot (the dual of ascending cells reaching \top)

The session lattice already has both join (`session-lattice-merge`) and the implicit meet structure. The extension is adding the dual direction to the scheduler.


<a id="org9d422f8"></a>

## 4.4 State Labeling for Session Types

Classical model checking labels states with atomic propositions. In the session type context, the "states" are session continuations and the "labels" are structural properties:

| Atomic Proposition | Session Type Condition                                 |
|------------------ |------------------------------------------------------ |
| `:sending`         | Cell value is `sess-send` or `sess-async-send`         |
| `:receiving`       | Cell value is `sess-recv` or `sess-async-recv`         |
| `:choosing`        | Cell value is `sess-choice`                            |
| `:offering`        | Cell value is `sess-offer`                             |
| `:ended`           | Cell value is `sess-end`                               |
| `:pinned`          | A `Pin-Guard` session is in `Pin-Protected` state      |
| `:holding X`       | Linear resource `X` has been acquired but not consumed |
| `:branch :label`   | Currently in a specific choice/offer branch            |

These propositions are computed by *labeling propagators* &#x2014; propagators that watch session cells and write boolean labels to proposition cells. The temporal property propagators then reference the proposition cells.


<a id="orgb578e17"></a>

# 5. The ATMS as Universal Path Quantifier


<a id="org652dd5d"></a>

## 5.1 Paths and Worldviews

In CTL, the path quantifiers `A` (for all paths) and `E` (there exists a path) distinguish between properties that must hold on every possible execution and those that need hold on only one.

In Prologos, paths through the session type state machine correspond to different selections at `+>/&>` choice points. Each selection is an ATMS *assumption*. A complete path is a *worldview* &#x2014; a consistent set of assumptions covering every choice point.

The mapping:

-   `A \phi` (for all paths, &phi;) = for all consistent worldviews in the ATMS, the property cell for &phi; is not at \bot
-   `E \phi` (exists a path, &phi;) = there exists a consistent worldview where the property cell for &phi; is not at \bot


<a id="org03b0371"></a>

## 5.2 Nogoods as Impossible Paths

ATMS nogoods represent inconsistent assumption sets &#x2014; combinations of choices that cannot coexist. In the model checking context, these are *impossible paths*: execution traces that the system cannot actually follow because of state constraints.

When a choice at `+>` excludes another choice (because they share a linear resource, or because a dependent type constraint rules out the combination), the ATMS records a nogood. The model checker then does not explore those impossible paths, reducing the state space.


<a id="org0adc237"></a>

## 5.3 Dependency-Directed Backtracking

When a temporal property violation is found under a specific worldview, the ATMS derivation chain identifies the *minimal set of assumptions* that caused the violation. This is the minimal counterexample &#x2014; the smallest set of choices that leads to the property violation. Classical model checkers produce a single counterexample trace; the ATMS produces a *minimal diagnosis*.


<a id="orgdd33927"></a>

# 6. Abstract Model Checking via Galois Connections


<a id="org6245d38"></a>

## 6.1 The Infinite-State Problem

Session types with recursion (`rec`) can describe infinite-state protocols. Classical CTL model checking works only on finite Kripke structures. The combination of abstract interpretation and model checking (Clarke, Grumberg, Long 1992; Cousot 1999) solves this by abstracting the infinite state space to a finite one.


<a id="org87f0619"></a>

## 6.2 Prologos Already Has the Infrastructure

The infrastructure for abstract model checking is already implemented:

1.  **`GaloisConnection` trait**: `\alpha : C \to A` (abstraction) and `\gamma : A \to C` (concretization), with the adjunction property `\alpha(c) \leq_A a \iff c \leq_C \gamma(a)`.

2.  **Cross-domain propagators**: `net-add-cross-domain-propagator` bridges cells in different lattice domains. When a concrete cell refines, the cross-domain propagator applies &alpha; and writes to the abstract cell; when the abstract cell refines, &gamma; maps back to the concrete cell.

3.  **Widening**: The `Widenable` trait provides widening operators that accelerate fixpoint convergence for infinite-height lattices. This corresponds to widening in abstract interpretation &#x2014; ensuring that the fixpoint computation terminates in finite time.


<a id="orgc504162"></a>

## 6.3 Application: Recursive Session Type Verification

A recursive session type like:

```prologos
session PingPong
  rec PP
    ! Ping
    ? Pong
    PP
```

has an infinite unfolding. Direct model checking would not terminate. But the abstract model checking approach:

1.  Abstract the session type through a Galois connection to a finite abstract domain (e.g., the *prefix abstraction* that tracks only the first `k` steps, or the *state-set abstraction* that tracks which session constructors appear but not their nesting depth)
2.  Model check on the finite abstract domain
3.  If the property holds on the abstract domain, it holds on the concrete domain (soundness of abstraction)
4.  If the property fails on the abstract domain, refine the abstraction (CEGAR &#x2014; CounterExample-Guided Abstraction Refinement)

The cross-domain propagators already implement steps 1-3. Step 4 (CEGAR) would be a new addition, but it follows the same pattern: create a finer abstraction, add new cross-domain propagators, re-run to quiescence.


<a id="orga3cdaa1"></a>

# 7. Incremental Model Checking


<a id="org3d6e6a7"></a>

## 7.1 The Classical Problem

Classical model checkers (SPIN, NuSMV) operate in batch mode: they take a complete model and a complete specification, explore the entire state space, and report results. Changing the model or specification requires a full re-run.


<a id="orgd3088f9"></a>

## 7.2 Propagator Networks Are Incremental

Propagator networks are inherently incremental:

1.  **Adding a propagator** triggers only the propagators that depend on the modified cells. Unchanged cells retain their values.
2.  **Modifying a cell** (e.g., changing a session type annotation) propagates changes only through affected propagators.
3.  **Adding a temporal property** creates new propagators and cells, which compute their values by reading existing cells &#x2014; no re-computation of unaffected properties.

This means model checking can run *continuously* during development:

```
Developer writes session type    → Propagators created
Developer writes process         → More propagators added
Model checker runs (quiescence)  → Properties verified
Developer modifies one branch    → Only affected cells re-evaluated
Developer adds a property        → New propagators created, run incrementally
```

The total cost is proportional to the *change*, not the total model size. This is the difference between a 20-minute batch model checking run and sub-second incremental feedback.


<a id="orgafa2d00"></a>

## 7.3 Connection to Reactive Verification

The incremental nature of propagator-based model checking aligns with *reactive verification* &#x2014; verification that happens continuously as the code changes, providing immediate feedback. This is the Tier 1-2 vision: the developer writes code, and temporal properties are verified in the background, with violations surfaced as type errors.


<a id="org84dd085"></a>

# 8. Tier-Level Accessibility


<a id="org637f7e8"></a>

## 8.1 The Current Landscape

| Tier | Tools                | Who Uses Them     | What They Require          |
|---- |-------------------- |----------------- |-------------------------- |
| 4+   | SPIN, NuSMV, TLA+    | Researchers       | Separate spec language,    |
|      |                      |                   | temporal logic expertise,  |
|      |                      |                   | Kripke structure knowledge |
| 4    | Alloy, Dafny         | Formal methods    | Specification idioms,      |
|      |                      | engineers         | bounded model checking     |
| 3    | Property-based       | Software eng.     | Test-level thinking,       |
|      | testing (QuickCheck) | w/ formal methods | property specification     |
| 2    | Type systems         | All developers    | Type annotations           |
| 1    | Linters, IDE checks  | All developers    | Nothing (automatic)        |

Model checking currently sits at Tier 4+. The contribution of this research is to show how to bring it down to Tier 2-3 in Prologos.


<a id="org9025cee"></a>

## 8.2 The Prologos Tier Mapping

| Tier | What the User Writes                 | What Happens                                   |
|---- |------------------------------------ |---------------------------------------------- |
| 4    | Raw &mu;-calculus formula on session | Translated to propagators, full counterexample |
|      | type (`:mu X. \phi \land [a] X`)     | with derivation chain                          |
| 3    | `property` annotation with temporal  | Compiled to fixpoint propagators, checked      |
|      | keywords (`:always`, `:eventually`)  | automatically, violation shown as error        |
| 2    | Session type with linear resources   | Inferred properties: linear resource implies   |
|      | (`[1]`) and `rec`                    | `AF consumed`, recursive session implies       |
|      |                                      | termination check, `end` is reachable          |
| 1    | Ordinary session type                | Safety (no protocol violation) verified        |
|      |                                      | automatically. Completeness checked.           |
|      |                                      | No user input needed.                          |

The key insight: **Tiers 1 and 2 are already implemented.** Session type checking (Tier 1 safety) and session completeness (Tier 1 weak liveness) happen today. Linear resource tracking (Tier 2) partially happens through QTT.

Tier 3 is the achievable next step: a `property` keyword that compiles temporal specifications to propagator wiring. Tier 4 is the full &mu;-calculus interface, useful for researchers but not required for practical developers.


<a id="org1de9f93"></a>

## 8.3 What "Invisible" Looks Like

The most exciting tier is where model checking becomes invisible:

```prologos
session FileProtocol
  ? [Cap FileCap] [1]          ;; receive linear file capability
  ! OpenRequest
  ? FileHandle [1]             ;; receive linear file handle
  rec ReadLoop
    +>
      | :read ->
          ! ReadRequest
          ? Chunk
          ReadLoop
      | :close ->
          ! CloseRequest       ;; consumes the linear handle
          end
```

From this session type alone, the system can *automatically* infer and verify:

1.  `AG \neg (open \land \neg holding-cap)` &#x2014; never open without capability (*safety from capability annotation*)
2.  `AF close` &#x2014; the file is eventually closed (*liveness from linearity* &#x2014; the `[1]` handle must be consumed, and the only consumption point is `:close`)
3.  `AG (holding-handle \to AF close)` &#x2014; if holding the handle, eventually close (*response from linear resource tracking*)
4.  No deadlock in `ReadLoop` (*completeness check*)

None of these properties need to be written by the user. They fall out of the session type structure, linear annotations, and capability types. The model checker runs invisibly, and violations appear as type errors:

```
Error: Linear resource FileHandle [1] may not be consumed.
  In session FileProtocol, branch :read may loop indefinitely
  without reaching :close.
  Property violated: AF close
  Counterexample: :read → :read → :read → ... (infinite loop)
  Suggestion: Ensure ReadLoop always eventually selects :close.
```


<a id="org262cf68"></a>

# 9. Concrete Examples from the Endo Analysis

The Endo research document (`2026-03-07_ENDO_AS_SESSION_TYPES.org`) identified several protocol properties. Each maps directly to a temporal formula that a propagator-based model checker could verify:


<a id="org65a1f47"></a>

## 9.1 Pin Never Leaked

```prologos
property pin-never-leaked
  :session Pin-Guard
  :always [implies :pinned [eventually :unpinned]]
```

CTL: `AG(pinned \to AF unpinned)`

This is a Level 2 alternation (nested `\nu/\mu`). The propagator construction:

1.  Compute `AF unpinned` as a least fixpoint (cell starts at \bot, refines up)
2.  Compute `AG(pinned \to result)` as a greatest fixpoint (cell starts at \top, refines down)


<a id="org437046b"></a>

## 9.2 GC Ordering Safety

```prologos
property gc-edge-before-status
  :session Promise-Resolution-Safe
  :always [not [:status-written :until :edge-written]]
```

CTL: `AG \neg (\neg edge-written\; U\; status-written)`

This uses the `Until` operator to express "status is never written before edge is written." The propagator translates the `Until` to a least fixpoint with a guard.


<a id="orga3bbc19"></a>

## 9.3 Revocation Eventually Propagated

```prologos
property revocation-propagated
  :session Retention-Protocol
  :always [implies :revoked [eventually :peer-notified]]
```

CTL: `AG(revoked \to AF peer-notified)`

This is the liveness property that the CRDT retention protocol (§19 of the Endo document) is designed to guarantee. With a CRDT, the property becomes: "revocation is local, peer notification happens on reconnection merge."


<a id="orgb648827"></a>

## 9.4 Mutex Non-Reentrant

```prologos
property mutex-no-reentry
  :session Mutex-Protocol
  :always [implies :held [always [not :acquire]]]
```

CTL: `AG(held \to AG \neg acquire)`

Nested safety: while the mutex is held, it is never acquired again. This is a Level 1 property (single greatest fixpoint) that can be checked efficiently.


<a id="org1a8ae00"></a>

# 10. The Propagator Network as Universal Verification Substrate


<a id="org13bae47"></a>

## 10.1 The Composability Principle

Every propagator added to the network makes the entire system more capable. This is a direct consequence of the monotone, composable structure:

-   A *type inference* propagator constrains type cells.
-   A *session decomposition* propagator constrains session cells.
-   An *effect ordering* propagator constrains effect position cells.
-   A *temporal property* propagator constrains property cells.

All share the same network, the same scheduler, the same ATMS for hypothetical reasoning, the same Galois connections for abstraction. Adding a temporal property propagator does not require a new engine &#x2014; it adds cells and propagators to the existing network, and `run-to-quiescence` processes everything together.


<a id="org9285e3d"></a>

## 10.2 Cross-Domain Verification

The most powerful consequence is cross-domain verification: temporal properties that span type checking, session checking, and effect ordering simultaneously.

Example: "If a function has a `FileCap` requirement (type domain), and the session type specifies an `open` step (session domain), and the effect ordering places `open` before `read` (effect domain), then on all execution paths, the file is eventually closed (temporal property)."

This crosses four domains (types, sessions, effects, temporal properties), and the propagator network handles all four in a single `run-to-quiescence` pass because all four are cells and propagators in the same network.


<a id="org44d0d78"></a>

## 10.3 The Verification Layer Cake

Prologos's verification stack, viewed through the model checking lens:

```
Layer 5: Temporal Properties    (CTL/LTL: safety, liveness, fairness)
     |
Layer 4: Effect Ordering        (Causal model: Galois connection to sessions)
     |
Layer 3: Session Types          (Protocol state machines: duality, completeness)
     |
Layer 2: Linear Types (QTT)     (Resource tracking: use-once, use-many)
     |
Layer 1: Dependent Types        (Value-dependent properties: indexed types)
     |
Layer 0: Propagator Network     (Monotone fixpoint computation: the universal substrate)
```

Each layer builds on the ones below. Layer 0 provides the computation model. Layers 1-4 provide domain-specific reasoning. Layer 5 provides temporal reasoning that spans all lower layers. And all of it is propagators, cells, and lattices.


<a id="orgae440c4"></a>

# 11. Research Program


<a id="orgb732ef8"></a>

## 11.1 Immediate Questions

1.  **Greatest fixpoint propagators**: What changes to `propagator.rkt` are needed to support descending cells? Is the dual of `run-to-quiescence` well-defined for mixed ascending/descending networks?

2.  **State labeling extraction**: How to automatically extract atomic propositions from session type structure? Can the labeling be derived from the session constructors, or does the user need to specify which session states correspond to which propositions?

3.  **Alternation depth in practice**: Do real-world session type properties require Level 2+ alternation, or is Level 1 (pure safety/reachability) sufficient for most practical use cases?


<a id="org22f741e"></a>

## 11.2 Medium-Term Research

1.  **CEGAR for session types**: When abstract model checking produces a spurious counterexample, how is the abstraction refined? What is the "session type refinement" analog of state-space refinement in classical CEGAR?

2.  **Fairness as a propagator constraint**: Can fairness conditions (every enabled branch is eventually taken) be expressed as propagator constraints on the ATMS assumption scheduling? This would connect fairness to the `strategy` keyword designed for the logic engine.

3.  **Multi-party session types**: Multiparty session types (Honda, Yoshida, Carbone 2008) describe protocols with more than two participants. The model checking approach generalizes: each participant's session type is a component of a larger Kripke structure, and temporal properties span the composed system.


<a id="org5a82694"></a>

## 11.3 Long-Term Vision

1.  **Runtime monitoring**: Temporal properties that cannot be verified statically (due to undecidability or state-space explosion) can be compiled to *runtime monitors* &#x2014; propagator networks that run alongside the program and raise alerts when properties are violated. This is the model checking equivalent of runtime contracts.

2.  **Synthesis**: Given a temporal specification, *synthesize* a session type that satisfies it. This inverts the verification problem: instead of "does this protocol satisfy this property?", ask "what protocol satisfies this property?" Propagator networks support this through their bidirectional nature &#x2014; constraints flow in both directions.

3.  **Verified distributed systems**: The combination of CRDT-aware retention protocols (§19 of the Endo document), session types, and temporal model checking provides a path toward verified distributed systems. The session type describes the protocol, the CRDT ensures convergence, and the temporal properties verify liveness and safety across network partitions.


<a id="org7deadd3"></a>

# 12. Related Work


<a id="orge4a3961"></a>

## 12.1 Model Checking as Abstract Interpretation

Cousot (1999, 2000) unified model checking and abstract interpretation, showing that model checking algorithms can be expressed as abstract interpretation over temporal domains. Our approach inverts this: we show that abstract interpretation infrastructure (Galois connections, widening, cross-domain propagators) can be used *directly* for model checking, without building a separate model checker.


<a id="orgf974c5b"></a>

## 12.2 Behavioral Types and Verification

Kobayashi's type system for deadlock-freedom in the &pi;-calculus uses session-like types with usage annotations. Our approach extends this with temporal properties beyond deadlock-freedom, using the same propagator infrastructure that checks the types.


<a id="orge63a64a"></a>

## 12.3 Multi-Valued Model Checking

Chechik, Devereux, Easterbrook, and Gurfinkel (2003) extended CTL model checking to multi-valued lattices (not just Boolean). Our approach is naturally multi-valued because propagator cells hold lattice values, not Boolean values. The session lattice `sess-bot < concrete < sess-top` is a three-valued lattice (unknown, known, contradictory), and richer lattices are possible through the `Lattice` trait.


<a id="orgeebdbba"></a>

## 12.4 Constraint-Based Model Checking

Constraint-based approaches to model checking (using SAT, SMT, or constraint propagation) are well-established in bounded model checking (Biere et al. 1999) and IC3/PDR (Bradley 2011). Our contribution is to observe that Radul-Sussman propagator networks &#x2014; originally designed for constraint propagation in a different context &#x2014; provide the same fixpoint computation substrate, with the additional benefits of incrementality, composability, and built-in ATMS support.


<a id="orgb4b2f88"></a>

# 13. Conclusion

The structural isomorphism between propagator-based session type checking and CTL model checking is not accidental. Both arise from the same mathematical foundation: monotone fixpoint computation over complete lattices. Prologos's propagator network, ATMS, and Galois connection infrastructure collectively implement the core algorithms of model checking &#x2014; but labeled as type inference, session verification, and abstract interpretation.

Making this connection explicit opens a concrete research program: temporal property specifications that compile to propagator wiring, bringing formal verification from expert-only tools to developer-accessible type annotations. The key enabler is the composability of propagator networks: every domain (types, sessions, effects, temporal properties) shares the same substrate, and every new propagator makes the entire system more capable.

The vision is a language where writing a session type with a linear resource IS writing a liveness specification, and the propagator network verifies it alongside type checking &#x2014; invisibly, incrementally, and automatically.


<a id="orgdaf03bf"></a>

# References

-   Bradfield, J. and Walukiewicz, I. "The mu-calculus and Model Checking." In *Handbook of Model Checking*, Springer, 2018. <https://link.springer.com/chapter/10.1007/978-3-319-10575-8_26>

-   Clarke, E., Grumberg, O., and Long, D. "Model checking and abstraction." *ACM TOPLAS* 16(5), 1994. <https://dl.acm.org/doi/10.1145/186025.186051>

-   Clarke, E., Emerson, E., and Sistla, A. "Automatic verification of finite-state concurrent systems using temporal logic specifications." *ACM TOPLAS* 8(2), 1986. <https://dl.acm.org/doi/10.1145/5397.5399>

-   Cousot, P. and Cousot, R. "Abstract interpretation: a unified lattice model for static analysis of programs by construction or approximation of fixpoints." *POPL* 1977. <https://dl.acm.org/doi/10.1145/512950.512973>

-   Cousot, P. and Cousot, R. "Refining model checking by abstract interpretation." *Automated Software Engineering* 6(1), 1999. <https://link.springer.com/article/10.1023/A:1008649901864>

-   Cousot, P. and Cousot, R. "Temporal abstract interpretation." *POPL* 2000. <https://dl.acm.org/doi/10.1145/325694.325699>

-   Cousot, P. "Model checking as program verification by abstract interpretation." *CONCUR* 2025.

-   De Kleer, J. "An assumption-based TMS." *Artificial Intelligence* 28(2), 1986. <https://www.sciencedirect.com/science/article/abs/pii/0004370286900809>

-   Hellerstein, J. "The Declarative Imperative: Experiences and Conjectures in Distributed Logic (CALM)." *SIGMOD Record* 39(1), 2010.

-   Honda, K., Yoshida, N., and Carbone, M. "Multiparty asynchronous session types." *POPL* 2008.

-   Kozen, D. "Results on the propositional &mu;-calculus." *TCS* 27(3), 1983.

-   Radul, A. "Propagation Networks: A Flexible and Expressive Substrate for Computation." PhD Thesis, MIT, 2009. <https://dspace.mit.edu/handle/1721.1/54635>

-   Radul, A. and Sussman, G. "The Art of the Propagator." MIT CSAIL, 2009. <https://groups.csail.mit.edu/mac/users/gjs/propagators/>

-   Chechik, M., Devereux, B., Easterbrook, S., and Gurfinkel, A. "Multi-valued model checking via classical model checking." *CONCUR* 2003.

-   Prologos Project. "Effectful Computation on Propagators: The Layered Recovery Principle." `docs/tracking/principles/EFFECTFUL_COMPUTATION_ON_PROPAGATORS.org`. 2026.

-   Prologos Project. "Endo's Formula Graph and Capability Protocols as Session Types." `docs/research/2026-03-07_ENDO_AS_SESSION_TYPES.org`. 2026.
