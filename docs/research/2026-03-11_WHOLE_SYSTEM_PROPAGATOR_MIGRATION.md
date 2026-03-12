# Whole-System Propagator Migration: From Shadow Network to Transparent Proof Object

**Date**: 2026-03-11
**Status**: Design Document (Pre-Implementation)
**Depends on**: Propagator-First Migration Sprint (Phases 0-4 COMPLETE), infra-cell.rkt, atms.rkt, propagator.rkt
**Informs**: Self-hosting path, LSP architecture, formal verification strategy, AI agent infrastructure

---

## 1. Thesis

The Prologos compiler currently maintains a **dual-write architecture**: elaboration state flows through both legacy Racket parameters (the primary read path) and propagator cells (a shadow network that proves correctness but isn't queried). This document proposes migrating the entire compilation pipeline to use the propagator network as the **single source of truth**, transforming the compiler from an opaque pipeline that produces results into a **transparent proof object** that explains *why* those results hold, *under what assumptions*, and *what would change* if any assumption were different.

This is not an optimization. It is an architectural thesis: **when the compiler's internal reasoning flows through the same propagator/ATMS infrastructure that the language provides to users, the gap between "writing a program" and "reasoning about a program" collapses.** The compiler becomes inspectable, verifiable, and queryable using the language's own tools -- the foundation for self-hosting, formal verification, and proof-carrying AI agents.

### 1.1 Motivation: The K-Framework Lesson

Formal verification of the MakerDAO smart contract ecosystem required three separate systems (paper model, K-Framework/KEVM spec, Solidity implementation), fifteen-plus engineers, and a dedicated research team. The verification was painstaking because each semantic gap between layers had to be bridged by hand: paper math to K rewrite rules, K rewrite rules to EVM bytecode, bytecode equivalence to Solidity source.

Prologos aims to eliminate these gaps:

- The **paper model** is the language's own dependent type system and logic engine
- The **operational semantics** are propagator networks computing fixpoints over lattices -- the same substrate the compiler uses internally
- The **implementation** is the program itself, type-checked and elaborated by the same propagator infrastructure
- The **verification** is a query against the ATMS: "under what assumptions does this property hold?"

When all four layers share one substrate, the 15-person verification effort becomes a single-person query.

### 1.2 What Exists Today

| Layer | Component | Writes to Cell? | Reads from Cell? | Status |
|-------|-----------|-----------------|-------------------|--------|
| 1 | Metavar store (6 CHAMP boxes) | Yes (dual-write) | No (reads parameter) | Phase 1 |
| 2 | Global env, namespace, module registry | Yes (dual-write) | No (reads parameter) | Phase 2 |
| 3 | Trait resolution, constraint store | Yes (dual-write) | No (reads parameter) | Phase 3 |
| Bridge | Speculation (save/restore + ATMS) | Yes | Yes (ATMS nogoods) | Phase 4 |
| Infra | ATMS, prop-network, infra-cell | -- | -- | Phase 0 (complete) |

The cells are **correct** (6826 tests pass with dual-write). They are not yet **primary**.

---

## 2. The Information-Theoretic Argument

### 2.1 Parameters Are Black Holes

A Racket parameter holds a value. You can read the current value. You cannot ask:

| Question | Parameter | ATMS-Backed Cell |
|----------|-----------|------------------|
| What is the current value? | Yes | Yes |
| How did it get this value? | No | **Yes** (support set) |
| What assumptions does it rest on? | No | **Yes** (assumption IDs) |
| What else depends on this value? | No | **Yes** (dependent propagators) |
| What combinations of inputs are inconsistent? | No | **Yes** (nogood database) |
| What would change if I retracted one input? | No | **Yes** (ATMS retraction + re-propagation) |

Every "No" in the parameter column is a question that formal verification, model checking, static analysis, runtime verification, and AI explainability all need answered.

### 2.2 The Lattice of Lattices

Prologos already has multiple lattice domains connected by propagators:

- **Type lattice**: Types ordered by subtyping, refined by unification
- **Multiplicity lattice**: QTT quantities (0, 1, w) with join/meet
- **Level lattice**: Universe levels with max/lzero
- **Session lattice**: Protocol states refined by decomposition
- **Capability lattice**: Effect capabilities refined by composition
- **Abstract domains**: Sign, parity, intervals (Phase 6 Galois connections)

The propagator network connects these via cross-domain propagators (Phase 6c). When the compiler reads from cells, these connections become **queryable**: "this value has type `Nat` (type cell) with multiplicity `1` (mult cell) at universe level `0` (level cell) -- here are the three assumptions that jointly determine this."

The "network of networks" vision: each domain's lattice is a sub-network; cross-domain propagators form the inter-network edges; the ATMS provides the assumption structure that spans all domains. **One unified substrate for all reasoning.**

### 2.3 Nogoods as Learned Clauses

Each ATMS nogood says "assumptions {A1, A2, ..., An} are jointly inconsistent." This is precisely a **learned clause** in the CDCL (Conflict-Driven Clause Learning) sense:

- Elaboration discovers inconsistencies (type mismatches, trait resolution failures, linearity violations)
- Each inconsistency is recorded as a nogood with its minimal assumption set
- The nogood database grows monotonically across the entire compilation
- Future reasoning can check `atms-consistent?` before exploring a branch -- **dependency-directed backjumping**

Today, the elaboration pipeline discovers inconsistencies but forgets their structure (parameters don't carry justifications). With cell-based flow, the nogood database becomes a **persistent knowledge base** of everything the compiler has learned about why certain combinations of definitions/annotations/instances are impossible.

This is the bridge to SAT/SMT: the elaboration process is constraint solving; making the constraint structure explicit enables automated theorem proving techniques on the compiler's own reasoning.

---

## 3. What Whole-System Migration Unlocks

### 3.1 Provenance: Error Explanation as Derivation Chains

**Current state**: Type error at line 12: "expected Nat, got Bool."

**With cell provenance**: Type error at line 12 because:
1. User annotated `x : Nat` at line 3 (assumption A1, context assumption via GDE-1)
2. Function `foo` returns `Bool` at line 8 (assumption A2, from elaboration of `foo`)
3. Assignment `let y := [foo x]` at line 12 creates constraint `Bool <: Nat` (propagator P7)
4. `{A1, A2}` is a recorded nogood -- `Bool` is not a subtype of `Nat`
5. Minimal diagnosis: either change the annotation at line 3 OR change the return type of `foo`

This isn't hypothetical -- `atms-minimal-diagnoses` and `atms-explain-hypothesis` already exist in `atms.rkt`. They just need the read path to go through cells so every intermediate result carries its support set.

### 3.2 Counterfactual Analysis: What-If Queries

With ATMS retraction, the compiler can answer counterfactual questions **without re-running elaboration**:

- **"What if `map` had a different type?"** -- Retract the assumption backing `map`'s definition cell, write a new value under a new assumption, re-propagate. Only transitive dependents recompute.
- **"What if this trait instance didn't exist?"** -- Retract the instance assumption. The trait resolution cell re-propagates. Dependent elaboration cells update.
- **"What definitions are redundant?"** -- Find assumptions with no dependents (dead code at the assumption level, not just syntax level).

This is the foundation for **incremental recompilation** (LSP), **refactoring safety** (what breaks if I change this?), and **design exploration** (which of these three approaches produces fewer constraints?).

### 3.3 Model Checking via Propagator Networks

Per the existing research (`PROPAGATORS_AS_MODEL_CHECKERS.md`), propagator-based session type checking IS model checking. The correspondence is mathematically exact:

| Model Checking | Propagator Network |
|---|---|
| Kripke structure (S, R, L) | Session type continuations |
| State transition | Session decomposition propagator |
| Safety (AG ~bad) | Contradiction detection (sess-top) |
| Liveness (AF end) | check-session-completeness |
| Counterexample trace | ATMS derivation chain |
| Fixpoint iteration | run-to-quiescence |
| Learned clause (CDCL) | ATMS nogood |

**What whole-system migration adds**: When ALL state (not just session types) flows through cells, the model-checking infrastructure generalizes beyond sessions:

- **Type-level model checking**: "Does this program ever produce a value whose type violates invariant P?" = safety property over the type lattice
- **Resource model checking**: "Does this program ever use a linear resource twice?" = safety property over the multiplicity lattice
- **Capability model checking**: "Does this program ever perform an effect outside its declared capabilities?" = safety property over the capability lattice

Each is a property over a lattice, checked by the same propagator/ATMS infrastructure.

### 3.4 Runtime Verification via Assumption Certificates

If compilation artifacts carry their support sets (the assumptions under which they were elaborated):

- **Link-time verification**: "This module was compiled assuming module X provides trait instance Y for type Z" -- verify at load time that the assumption still holds
- **Hot-reload safety**: When a definition changes (LSP edit, REPL redefinition), the ATMS identifies exactly which downstream results are invalidated -- no need to re-elaborate everything
- **Session monitors**: Runtime protocol monitors can verify that the assumptions the type-checker relied on (protocol conformance, capability bounds) still hold during execution

The key insight: **assumptions are the interface between static and dynamic verification.** The type-checker establishes them; the runtime can check that they're maintained.

### 3.5 Automated Theorem Proving

The elaboration pipeline is already doing constraint solving. Making the constraint structure explicit (via cells) enables:

1. **Proof search as propagation**: A theorem is a type; a proof is a value of that type. Finding the proof is searching for a consistent assignment in the ATMS that satisfies the type constraint. `atms-solve-all` already does this.

2. **Conflict-driven learning**: Each failed proof attempt records a nogood. Future proof search avoids the same dead end. This is exactly CDCL -- the most successful technique in modern SAT solving.

3. **Interpolation**: Given a nogood {A1, A2, A3}, an interpolant is a formula that separates the assumptions into "this part is the caller's fault" and "this part is the callee's fault." Cell-based provenance makes interpolant extraction mechanical.

4. **Dependent type proofs as ATMS derivations**: A dependent type proof `(p : x = y)` is, in the ATMS, a supported value whose support set contains exactly the assumptions needed to derive `x = y`. The proof IS the support set. Making this correspondence explicit means dependent type proofs and ATMS derivations are the same data structure.

### 3.6 Self-Hosting Convergence

**Current state**: The compiler is written in Racket. It uses propagators internally. Users write programs that use propagators. These are different codebases.

**After whole-system migration**: The compiler's propagator network and the user's propagator network use the same `propagator.rkt` and `atms.rkt`. The compiler's cells and the user's cells are the same data structures. The compiler's merge functions and the user's merge functions are the same functions.

**Self-hosting then means**: Rewriting the Racket-side propagator orchestration in Prologos itself. Since:
- Homoiconicity (Phases I-III complete) means Prologos code is data
- The propagator infrastructure is already Prologos-compatible (pure, persistent, no Racket-specific magic)
- The Maude formal spec (10 modules, 33 tests) provides the verification target

...the self-hosting path becomes: implement each Maude rewrite rule as a Prologos propagator. Verify each propagator against its Maude counterpart using the ATMS derivation = dependent type proof correspondence. The compiler verifies itself using its own infrastructure.

### 3.7 AI Agents with Proof-Carrying Assurance

An AI agent built on Prologos would have:

- **Proof-carrying actions**: Every action justified by an ATMS support set. "I did X because of assumptions {A1...An}." Retract any assumption -> the agent knows which conclusions are invalidated.

- **Self-rewriting with verification**: Homoiconicity means the agent's code is data. Dependent types mean modifications carry type-level proofs of invariant preservation. The ATMS tracks why the modification was justified.

- **Explainable reasoning**: "Why do you believe X?" -> `atms-explain-hypothesis` returns the minimal set of assumptions. "What would change your mind?" -> `atms-minimal-diagnoses` returns the assumptions whose retraction would invalidate X.

- **Capability containment**: Foreign interface calls are session-typed channels with capability annotations. The type system proves the agent can't exceed its capabilities. The proof is carried by the ATMS.

- **Probabilistic belief**: Assumptions can carry confidence weights (see Section 6). A propagator that merges weighted assumptions produces belief-weighted conclusions. The ATMS support set becomes a probabilistic justification -- exactly what Bayesian agents need but can never currently explain.

---

## 4. Migration Architecture

### 4.1 Principles

1. **Query-driven migration**: Don't migrate reads for the sake of it. Identify the questions we want to answer (provenance, dependency, counterfactual), then migrate the reads that enable those answers.

2. **Cell-primary, parameter-compat**: After migration, cells are the source of truth. Parameters become a compatibility shim that reads from cells (inverting the current dual-write direction). Eventually parameters are removed entirely.

3. **Monotonic progress**: Each migration step must pass all 6826+ tests. No big-bang cutover.

4. **Self-hosting alignment**: Prefer migration orderings that move toward structures expressible in Prologos itself. Avoid Racket-specific patterns that would need to be un-done during self-hosting.

### 4.2 Migration Stages

#### Stage 1: Query Interface Design

Before migrating reads, define the query protocol -- what questions should be answerable after elaboration?

**Provenance queries**:
- `(why-type expr)` -> support set for expr's type assignment
- `(why-constraint c)` -> assumptions that produced constraint c
- `(why-instance trait type)` -> assumptions that resolved this trait instance

**Dependency queries**:
- `(depends-on def)` -> set of definitions whose cells transitively depend on def
- `(dependents-of def)` -> set of definitions that def's cell transitively affects
- `(dead-assumptions)` -> assumptions with no dependent cells (dead code)

**Counterfactual queries**:
- `(what-if-retracted assumption)` -> set of cells that would change
- `(what-if-changed def new-type)` -> preview of re-elaboration results

**Consistency queries**:
- `(all-nogoods)` -> complete nogood database
- `(conflicting-assumptions)` -> assumption sets known to be inconsistent
- `(minimal-diagnoses error)` -> minimal sets of assumptions to retract to resolve error

**Verification queries**:
- `(assumption-certificate def)` -> the assumption set under which def was elaborated
- `(verify-assumption a)` -> runtime check that assumption a still holds

#### Stage 2: Read Migration (Cells Become Primary)

Migrate reads from parameters to cells, prioritized by information payoff:

**Tier 1 -- Highest payoff** (trait resolution, constraints):
- **Trait resolution reads**: "Why was this instance selected?" is the most common elaboration question. The ATMS support set on the trait-resolution cell answers it directly. Currently in `trait-resolution.rkt`, reads go through `current-trait-constraint-map` (parameter). Migration: read from the Layer 3 cell instead.
- **Constraint store reads**: Enables derivation chains for all type errors, not just speculation failures. Currently in `metavar-store.rkt`, reads go through `current-constraint-store` (parameter). Migration: read from the constraint cell.

**Tier 2 -- Structural payoff** (metavar store, unification):
- **Metavar solution reads**: Every metavar solution carries its support set. Type inference becomes a proof. Currently in `metavar-store.rkt`, 6 CHAMP boxes read directly. Migration: read from Layer 1 cells.
- **P-Unify integration**: Make the propagator network the authority for unification (currently observer-only). This is the existing "P-Unify" deferred item -- it becomes a natural consequence of cell-primary reads. Enables bidirectional cross-domain inference and incremental re-solving.

**Tier 3 -- Completeness** (global env, registries):
- **Global env reads**: Definition-level dependency tracking. Foundation for incremental everything. Currently reads from `current-global-env` (parameter). Migration: read from Layer 2 cells.
- **Registry reads**: Type registries, schema registries, capability registries. Currently 27 parameters. Migration: read from Layer 2 cells.

**Tier 4 -- Removal** (eliminate dual-write):
- Once reads are migrated, remove the parameter writes. Parameters become dead code.
- The dual-write pattern served its purpose (proving cell correctness). It is not the end state.

#### Stage 3: The Self-Hosting Bridge

Once the compiler reads from cells:

1. **Maude spec alignment**: Each rewrite rule in the Maude formal spec corresponds to a propagator. Verify correspondence: the propagator computes the same function as the rewrite rule. The ATMS derivation of the propagator's output IS the proof of correctness.

2. **Prologos-level cell API**: Expose `infra-cell.rkt`'s cell factories, merge functions, and ATMS operations as Prologos-level constructs. Users (and the future self-hosted compiler) use the same API.

3. **Compiler-as-library**: The elaboration pipeline becomes a Prologos library -- a collection of propagators wired into a network. Self-hosting means replacing the Racket orchestration with Prologos orchestration. The propagators themselves are already pure functions over lattices.

4. **Verification bootstrap**: The self-hosted compiler verifies itself: each propagator's behavior is checked against the Maude spec using the ATMS. The compiler's own type system proves that its propagators are monotonic. The compiler's own logic engine searches for proofs that its elaboration rules are sound.

---

## 5. Interaction with Existing Deferred Work

### 5.1 P-Unify (Propagator-Driven Unification)

**Status**: NOT STARTED, no blockers.

**Relationship**: P-Unify is the natural consequence of Stage 2 Tier 2. When metavar reads go through cells and cells are ATMS-backed, unification becomes cell-driven solving where the propagator network is the authority. The "observer" pattern (current `unify*` writes to parameters, cells shadow) inverts: cells are primary, parameters observe.

**Key capability unlocked**: Bidirectional cross-domain inference. A constraint in the type domain narrows a cell in the multiplicity domain via cross-domain propagator. Currently requires explicit "retry" loops; with cell-primary flow, it's automatic propagation.

### 5.2 Session Type Runtime (Concurrent Execution)

**Status**: Phase 0 only (single atomic network). Real concurrency deferred.

**Relationship**: Whole-system migration doesn't require concurrent sessions, but it provides the infrastructure. Multiple agents on separate networks cross-referencing via cross-network propagators (Phase 8d) requires cell-primary reads -- you can't cross-reference parameters across networks.

### 5.3 Effectful Computation on Propagators (Architecture A+D)

**Status**: Phase 1 COMPLETE (stratified effect barriers). Phase 2 NOT STARTED.

**Relationship**: Effect ordering analysis requires provenance. "This effect must happen before that effect because of session type constraint S" is an ATMS derivation chain. Cell-primary reads make this derivation queryable.

### 5.4 Extended Spec System (Verification Phases 2-4)

**Status**: Tier 1-2 COMPLETE. Phases 2-4 (QuickCheck, refinement types, ITP) NOT STARTED.

**Relationship**: Refinement types (Phase 3) require the type-checker to verify predicates. With cell-primary flow, refinement verification is a query against the ATMS: "is there a consistent assumption set under which this refinement holds?" Interactive theorem proving (Phase 4) is proof search over the ATMS -- `atms-solve-all` generalized to dependent types.

### 5.5 Homoiconicity Phase IV (Runtime Eval & Read)

**Status**: NOT STARTED (requires embedding compiler at runtime).

**Relationship**: If the compiler is a collection of propagators wired into a network, "embedding the compiler at runtime" means instantiating that network. Cell-primary architecture makes this feasible -- the network IS the compiler, not an opaque Racket procedure.

---

## 6. Probabilistic Extensions (Research Direction)

### 6.1 Confidence-Weighted Assumptions

The ATMS assumption structure supports an extension to probabilistic reasoning:

- Each assumption carries a **confidence weight** in [0, 1] (or a probability distribution)
- When multiple assumptions support a value, the support set's confidence is the product (under independence) or a more sophisticated combination
- Nogoods carry the confidence of their most uncertain assumption -- "this inconsistency is 0.7 certain because assumption A3 has confidence 0.7"
- `atms-minimal-diagnoses` with confidence weights identifies the most cost-effective assumptions to investigate

### 6.2 Lattice-Valued Propositions

Merge functions can be extended to carry confidence:

```
merge-with-confidence : (value * confidence) * (value * confidence) -> (value * confidence)
```

Where the merged confidence reflects the strength of evidence for the merged value. This turns the propagator network into a **probabilistic reasoning engine** without changing its fundamental architecture.

### 6.3 Bayesian Belief Networks as Propagator Networks

A Bayesian network is a DAG of random variables with conditional probability tables. A propagator network is a DAG of cells with merge functions. The correspondence:

- Random variable = cell with probability distribution as value
- Conditional probability table = propagator that computes posterior from prior + evidence
- Belief propagation (Pearl's algorithm) = run-to-quiescence over probability-valued cells

This means Prologos's propagator infrastructure can, in principle, support Bayesian reasoning as a special case of lattice-valued propagation. An AI agent's beliefs would be cells; evidence updates would be writes; inference would be propagation; explanation would be ATMS support sets with confidence weights.

### 6.4 Connection to Dependent Types

The type `Belief A p` (a value of type A with confidence p) is a dependent type where p is a universe-polymorphic confidence value. The type system can track confidence through computation:

- `f : <(x : Belief Nat 0.9) -> Belief Bool 0.85>` -- this function degrades confidence
- Linearity (QTT) prevents double-counting evidence
- Session types ensure that probabilistic protocol participants agree on confidence semantics

This is deeply speculative but architecturally enabled: the lattice infrastructure, ATMS, dependent types, and QTT all compose naturally with probabilistic extensions.

---

## 7. Sequencing and Dependencies

### 7.1 Critical Path

```
Stage 1: Query Interface Design
  |
  v
Stage 2 Tier 1: Trait resolution + constraint reads from cells
  |
  v
Stage 2 Tier 2: Metavar reads + P-Unify integration
  |
  v
Stage 2 Tier 3: Global env + registry reads from cells
  |
  v
Stage 2 Tier 4: Remove dual-write (parameters become dead code)
  |
  v
Stage 3: Self-hosting bridge (Prologos-level cell API + compiler-as-library)
```

### 7.2 Parallel Tracks

These can proceed independently of the main migration:

- **Probabilistic extensions** (Section 6): Research track, informs but doesn't block
- **LSP architecture**: Consumes cell-primary reads but doesn't produce them
- **Session runtime**: Requires cell-primary for cross-network (Phase 8d) but can proceed on single-network
- **Effectful computation Phase 2**: Benefits from provenance but doesn't require full migration
- **Extended spec system**: Phases 2-4 benefit from ATMS queries but can start with current infrastructure

### 7.3 Estimated Scope

| Stage | Estimated Effort | Files Affected | New Tests |
|-------|-----------------|----------------|-----------|
| 1: Query interface design | 1-2 weeks (design doc + prototype API) | New file: `query.rkt` | ~20 (API tests) |
| 2 Tier 1: Trait + constraint reads | 1 week | trait-resolution.rkt, metavar-store.rkt, typing-core.rkt | ~15 |
| 2 Tier 2: Metavar reads + P-Unify | 2-3 weeks | metavar-store.rkt, unify.rkt, elaborator.rkt | ~40 |
| 2 Tier 3: Global env + registries | 1-2 weeks | namespace.rkt, driver.rkt, ~8 registry files | ~20 |
| 2 Tier 4: Remove dual-write | 1 week | All Layer 1-3 files | 0 (removals) |
| 3: Self-hosting bridge | 3-4 weeks | New files: Prologos-level cell API, compiler-as-library | ~50 |
| **Total** | **~10-13 weeks** | | **~145** |

### 7.4 Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Performance regression (cell reads slower than parameter reads) | Medium | High | Benchmark at each tier; cell reads should be O(1) CHAMP lookup |
| Circular dependency introduction | Low | High | infra-cell.rkt has zero Prologos-syntax deps by design |
| Test suite instability during migration | Low | Medium | Monotonic progress: each step passes all tests |
| P-Unify complexity exceeds estimate | Medium | Medium | P-Unify can be staged: observer-primary first, authority later |
| Self-hosting bridge scope creep | High | Medium | Stage 3 is a separate track; gate on Stage 2 completion |

---

## 8. Design Philosophy: Why Now?

### 8.1 The Completeness-Over-Deferral Principle

From `DEVELOPMENT_LESSONS.org`: "When you have clarity, vision, and full context -- finish the work now. Half-built pieces that get deferred are half-built pieces that get forgotten."

The dual-write architecture has given us clarity: the cells work. The vision is articulated: transparent proof object, self-hosting convergence, proof-carrying AI agents. The context is fresh: Phases 0-4 are complete, the infrastructure is battle-tested with 6826 tests, and the research documents map the theoretical foundations.

Deferring the read migration means maintaining two parallel state systems indefinitely -- a maintenance burden that grows with every new feature. The dual-write pattern was always meant to be transitional. It's time to transition.

### 8.2 The Self-Hosting Imperative

Every feature built on Racket parameters is a feature that must be re-implemented during self-hosting. Every feature built on propagator cells is a feature that transfers directly. The migration is not just about information surveillance -- it's about reducing the self-hosting surface area.

### 8.3 The Verification Ecosystem

The K-Framework experience shows that formal verification's bottleneck is semantic gaps between layers. Prologos's thesis is that those gaps can be eliminated by construction. But "by construction" means the construction must actually use the unified substrate. As long as the compiler reads from parameters, there's a gap between "what the compiler does" and "what the propagator network knows." Closing that gap is the prerequisite for everything else: model checking, ATP, runtime verification, proof-carrying agents.

---

## 9. Relationship to Prior Documents

| Document | Relationship |
|----------|-------------|
| `PROPAGATOR_NETWORKS.md` | Theoretical foundation: lattices, monotonicity, ATMS, fixpoints |
| `PROPAGATORS_AS_MODEL_CHECKERS.md` | Application: CTL/LTL/mu-calculus over propagator networks |
| `PROPAGATOR_FIRST_MIGRATION.md` | Predecessor: Phases 0-4 built the dual-write infrastructure this document proposes to complete |
| `LSP_VSCODE_STAGE2_REFINEMENT.md` | Consumer: LSP architecture benefits from cell-primary reads (especially SS9.1-9.4) |
| `PROPAGATOR_FIRST_PIPELINE_AUDIT.md` | Inventory: identified 42 propagator-natural sites across the compilation pipeline |
| `EFFECTFUL_COMPUTATION_ON_PROPAGATORS.md` | Parallel track: stratified effects require provenance from cell-primary reads |
| `ATP_AS_SESSION_TYPES.md` | Application: ATP protocols as session-typed channels over propagator network |
| `FL_NARROWING_DESIGN.md` | Application: narrowing as propagator-driven search with ATMS backtracking |
| `HOMOICONICITY_ROADMAP.md` | Enabler: Phases I-III (complete) provide code-as-data for self-hosting; Phase IV (runtime eval) enabled by compiler-as-library |

---

## 10. Open Questions

1. **Should Stage 1 (query interface) be a Prologos-level API or a Racket-level API?** Prologos-level aligns with self-hosting but requires more infrastructure. Racket-level ships faster but must be redone during self-hosting.

2. **Should probabilistic extensions (Section 6) be designed into the query interface from the start, or added later?** Designing them in avoids breaking changes but increases Stage 1 scope.

3. **What is the right granularity for ATMS assumptions?** Per-definition (current Phase 3 design) is sufficient for LSP and incremental compilation. Per-expression would enable finer-grained provenance but creates more assumptions. Per-type-check-step would enable full proof reconstruction but may be prohibitively expensive.

4. **How should the migration interact with the Numerics Tower Phase 4 (not started) and Core Data Structures Phase 2e+ (not started)?** These add new AST nodes and type rules. Should they be built on cell-primary infrastructure from the start, or migrated later?

5. **What is the performance budget?** Cell reads via CHAMP lookup should be O(1), but the constant factor matters. What regression is acceptable? The current 182.9s test suite time is the baseline.

---

## 11. Summary

The whole-system propagator migration transforms Prologos from a language that happens to use propagators internally into a language whose compilation IS propagation, whose type-checking IS constraint solving, whose verification IS ATMS queries, and whose self-hosting IS the identity function on its own infrastructure.

The dual-write pattern (Phases 0-4) proved the infrastructure works. The read migration (this document) makes it primary. The self-hosting bridge makes it self-referential. The verification story makes it trustworthy. The AI agent architecture makes it explainable.

The pieces are in place. The thesis is clear. The context is fresh.

It's time.
