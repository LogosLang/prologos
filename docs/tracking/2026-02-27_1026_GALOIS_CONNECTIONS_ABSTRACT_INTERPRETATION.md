# Galois Connections & Abstract Interpretation on the Logic Engine

**Date**: 2026-02-27
**Status**: ✅ COMPLETE — Phases 6a–6e implemented

---

## What It Is

A **Galois connection** is a pair of monotone functions `(α, γ)` between two ordered domains:

```
α : Concrete → Abstract     (abstraction — "forget detail")
γ : Abstract → Concrete     (concretization — "what does this abstract value represent?")
```

with the adjunction property: `α(c) ≤ a ⟺ c ≤ γ(a)` for all concrete `c` and abstract `a`.

This is the mathematical backbone of **abstract interpretation** (Cousot & Cousot, 1977): you take a computation over a "big" concrete domain, and systematically approximate it in a smaller, cheaper abstract domain. Crucially, the Galois connection guarantees **soundness** — anything you prove in the abstract domain also holds in the concrete domain. You may lose precision (the abstract domain can't distinguish things the concrete domain can), but you never get wrong answers.

---

## What We Already Have

The lattice engine is already structured to support this. The concrete infrastructure:

| Component | Status | Role in Abstract Interpretation |
|---|---|---|
| `Lattice` trait (`bot`, `join`, `leq`) | ✅ | Defines the abstract domain interface — any AI domain is a lattice instance |
| `PropNetwork` (persistent, immutable) | ✅ | The fixpoint engine — computes least fixpoints via run-to-quiescence |
| `FlatVal A` | ✅ | The simplest useful abstract domain: ⊥ → concrete value → ⊤ |
| `Interval` | ✅ | A classic AI domain (interval arithmetic) — already implemented as a Lattice instance |
| `Set A` / `Map K V` lattices | ✅ | Powerset domain (collecting semantics) and pointwise map domain |
| ATMS (hypothetical reasoning) | ✅ | Enables speculative analysis with worldview branching |
| Stratified evaluation | ✅ | Handles negation/non-monotonic operations between fixpoint strata |
| BSP parallel scheduler | ✅ | Parallelizes fixpoint computation within a stratum |
| Tabling (SLG memoization) | ✅ | The "pocket universe" mechanism — sub-computations with memoized results |

The missing piece is the **glue** that connects these domains to each other: the `α`/`γ` functions themselves, plus widening/narrowing operators for domains of infinite height.

---

## What It Would Give Us

Three categories of payoff, from most immediate to most ambitious:

### 1. Modular Constraint Domains (Medium-term, High Value)

Right now, if a propagator cell holds an `Interval`, every propagator on that cell must speak the language of intervals. There's no clean way for a type-checking propagator (which speaks `FlatVal Type`) to interact with a numeric constraint propagator (which speaks `Interval`).

With Galois connections, you define:

```
α_type : Interval → FlatVal Type
  -- "this interval constrains an Int/Rat value" → FlatVal (Int | Rat)

γ_range : FlatVal Type → Interval
  -- FlatVal Int → Interval [min-int, max-int]
  -- FlatVal Rat → Interval(-∞, +∞)
  -- FlatVal Bool → ⊤ (intervals don't apply)
```

Each constraint domain becomes a **module** with its own lattice, connected to other domains via these pairs. Adding a new analysis domain (sign analysis, parity, pointer aliasing) doesn't require modifying existing domains — you just define the Galois connections to the domains you interact with.

This is the "pocket universe" mechanism from the design docs, made first-class.

### 2. Program Analysis on Prologos Programs (Longer-term, High Value)

Abstract interpretation is *the* framework for static program analysis. With Galois connections in the logic engine, we could build:

- **Interval analysis**: Given `spec foo Int -> Int`, automatically infer that if input ∈ [0, 100], output ∈ [0, 200]. The `Interval` lattice already supports this; what's missing is the `α`/`γ` wiring and a widening operator for convergence.

- **Definite-initialization analysis**: A `FlatVal (Initialized | Uninitialized)` domain to statically verify that all variables are assigned before use. Trivial domain, major ergonomic win.

- **Nullability analysis**: Given `Option A`, track which branches have unwrapped the option. This connects directly to the `A?` nilable union syntax (deferred item).

- **Termination hints**: A lattice of "decreasing measure" annotations, propagated through recursion, to identify obviously-terminating functions.

Each of these is a new `impl Lattice MyDomain` plus a pair of `α`/`γ` functions. The fixpoint engine, tabling, ATMS — all reused unchanged.

### 3. Abstract Interpretation of Relational Programs (Research-level)

The `defr`/`rel`/`solve` surface syntax defines relational programs. Abstract interpretation on these programs means:

- **Mode analysis**: Which arguments are ground (input) vs. unbound (output) at each call site? This is classic Mercury-style mode inference, expressible as a Galois connection from the substitution lattice to a simpler "ground/free/any" lattice.

- **Determinism analysis**: Does a relation produce exactly one answer, at most one, or many? Important for optimization (avoid ATMS overhead when deterministic).

- **Cardinality bounds**: Abstract the answer set to its cardinality — "this query produces at most 3 answers" enables bounded search without full ATMS.

---

## What It Applies To

The scope is broader than you might expect. Every fixpoint computation in Prologos is a candidate:

| Computation | Concrete Domain | Potential Abstract Domain |
|---|---|---|
| Type inference (elaborator) | Substitution lattice (type → type) | Coarser type lattice (e.g., "numeric", "collection", "function") |
| Trait resolution | Instance lattice | Reachability lattice (is there *some* path to an instance?) |
| Propagator network evaluation | Product of all cell lattices | Projected sub-lattice of "interesting" cells |
| Relational query (`solve`) | Set of answer substitutions | Cardinality/mode approximation |
| Tabled predicate | Table of all answers | Aggregate properties of answers |
| Numeric constraints | Exact `Rat` values | Interval, sign, parity, congruence domains |

---

## The Widening/Narrowing Question

The `Interval` lattice has **infinite ascending chains**: `[0,100] ≤ [0,200] ≤ [0,300] ≤ ...`. A naive fixpoint iteration would never converge. Abstract interpretation solves this with:

- **Widening (∇)**: At certain "widening points" (loop headers, recursive calls), instead of computing `join(old, new)`, compute `old ∇ new` which deliberately over-approximates to ensure convergence. Classic interval widening: if the upper bound increased, jump to +∞.

- **Narrowing (Δ)**: After widening stabilizes (giving a post-fixpoint that's sound but imprecise), iterate with `old Δ new = join(old ∩ new)` to recover some precision without losing soundness.

This is the one piece that requires new infrastructure beyond what `Lattice` provides. We'd want:

```prologos
trait Widenable {A} where (Lattice A)
  widen : A A -> A     ;; ∇ operator
  narrow : A A -> A    ;; Δ operator (optional, defaults to join)
```

The `run-to-quiescence` loop would need a variant that applies widening at designated "loop head" cells instead of plain join.

---

## How It Fits the Architecture

The design doc (`2026-02-24_TOWARDS_A_GENERAL_LOGIC_ENGINE_ON_PROPAGATORS.md`) already identified this as **Phase 6** of the logic engine, after stratified evaluation. The phasing makes sense:

1. Tabling provides the "pocket universe" mechanism that Galois connections formalize
2. Stratification provides the inter-stratum boundaries where abstract/concrete domains can be switched
3. The ATMS provides worldview branching for speculative abstract interpretation (try a coarse domain; if it's too imprecise, refine)

All of Phases 1–7 plus the elaborator refactoring (8+A-E) are complete. Stratified evaluation is done. The infrastructure is ready — what remains is the `domain` declaration surface syntax, the `α`/`γ` trait definitions, and the widening-aware fixpoint variant.

---

## Summary

Galois connections on the logic engine are the formalization of something already implicit in the architecture: different parts of the system reason at different levels of abstraction, and results must be soundly transferred between levels. Making this explicit gives us modular analysis domains, program analysis for Prologos code, and the theoretical foundation to prove that our approximations are correct. The infrastructure is built; the concept is well-understood from 50 years of Cousot's work; the question is when the pain is sufficient to justify the implementation cost.

---

## Key References

| # | Authors | Title | Venue | Year |
|---|---------|-------|-------|------|
| 1 | Cousot, Cousot | Abstract Interpretation: A Unified Lattice Model for Static Analysis of Programs | POPL | 1977 |
| 2 | Cousot, Cousot | A Galois Connection Calculus for Abstract Interpretation | POPL | 2014 |
| 3 | Cousot | Types as Abstract Interpretations | POPL | 1997 |
| 4 | Cousot, Cousot | Comparing the Galois Connection and Widening/Narrowing Approaches | PLILP | 1992 |
| 5 | Radul, Sussman | The Art of the Propagator | MIT TR | 2008 |
| 6 | Madsen, Yee, Lhoták | From Datalog to Flix: Fixed Points on Lattices | PLDI | 2016 |
| 7 | Arntzenius, Krishnaswami | Datafun: A Functional Datalog | ICFP | 2016 |
| 8 | Denecker, Marek, Truszczynski | Approximation Fixpoint Theory | 2012 | 2012 |

## Implementation Summary (Complete)

All five sub-phases implemented and tested:

| Phase | Deliverables | Tests | Files |
|-------|-------------|-------|-------|
| 6a | `Widenable` trait, `impl Widenable Interval`, widening-aware fixpoint (`run-to-quiescence-widen`), `new-widenable-cell` | 23 | 2 .prologos, 2 test, propagator.rkt, propagator.prologos, namespace.rkt |
| 6b | `GaloisConnection {C A}` trait, `impl GaloisConnection Interval Bool` | 15 | 2 .prologos, 1 test |
| 6c | `net-add-cross-domain-propagator` (bidirectional α/γ), BSP+widening compatibility | 8 | propagator.rkt, 1 test |
| 6d | `Sign` (5-element), `Parity` (4-element) data types + `Lattice`/`HasTop` instances | 19 | 4 .prologos, 1 test |
| 6e | `specialize new-widenable-cell for Interval`, grammar docs, integration tests | 17 | propagator.prologos, grammar.org, 2 tests |

**Total**: ~82 new tests across 7 test files, 9 new .prologos files, propagator.rkt extended.

### Key Design Decisions

- **Constraint ordering for Interval**: Widening jumps *toward* bot (unconstrained), not away. This is correct for constraint semantics where join = intersect.
- **Cross-domain propagation**: Pure combinator over `net-add-propagator` — no new struct fields. Creates two unidirectional propagators (C→A via α, A→C via γ).
- **2-type-param trait**: `GaloisConnection {C A}` generates dict names like `Interval-Bool--GaloisConnection--dict`. No special handling needed.
- **Sign-galois.prologos deferred**: The `impl GaloisConnection Interval Sign` requires Rat comparison functions and negative literal handling that needs future work.
- **Prologos-level `connect-domains` deferred**: Exposing cross-domain propagation at the Prologos type level requires either a new AST keyword or a foreign function interface; deferred to a future phase.

### Deferred Items

1. `sign-galois.prologos` — `impl GaloisConnection Interval Sign` (Rat comparison complexity)
2. `connect-domains` Prologos wrapper — needs AST keyword or FFI approach
3. Additional abstract domains (Congruence, Pointer, etc.) — extend as needed

## See Also

- `docs/tracking/2026-02-23_LATTICE_PROPAGATOR_RESEARCH.md` — § 3 "Lattice Embeddings" (Galois connections formal defs)
- `docs/tracking/2026-02-24_TOWARDS_A_GENERAL_LOGIC_ENGINE_ON_PROPAGATORS.md` — § 6 "Pocket Universe", Phase 6 design
- `docs/tracking/2026-02-24_LOGIC_ENGINE_DESIGN.md` — 7-phase architecture
- `docs/tracking/DEFERRED.md` — "Post-Phase 7: Galois Connections + Domain Embeddings"
