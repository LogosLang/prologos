# Module Theory on Lattices: Unifying Lens for Propagator Networks

**Date**: 2026-03-28
**Series**: PRN (theory home), with touch-points to PPN, SRE, PTF, PAR, BSP-LE, CIU, NTT, PM
**Status**: Stage 0/1 research — foundational theory with immediate architectural implications
**Cross-references**:
- PRN Master: `docs/tracking/2026-03-26_PRN_MASTER.md`
- PPN Master: `docs/tracking/2026-03-26_PPN_MASTER.md`
- SRE Master: `docs/tracking/2026-03-22_SRE_MASTER.md`
- PTF Master: `docs/tracking/2026-03-28_PTF_MASTER.md`
- PAR Master: `docs/tracking/2026-03-27_PAR_MASTER.md`
- BSP-LE Master: `docs/tracking/2026-03-21_BSP_LE_MASTER.md`
- CIU Master: `docs/tracking/2026-03-21_CIU_MASTER.md`
- PM Master: `docs/tracking/2026-03-13_PROPAGATOR_MIGRATION_MASTER.md`
- NTT Syntax Design: `docs/research/2026-03-20_NTT_SYNTAX_DESIGN.md`
- Hyperlattice Conjecture: confirmed findings in PRN Master
- CALM topology lesson: `docs/tracking/principles/DEVELOPMENT_LESSONS.org`

---

## 1. Core Insight

The Prologos propagator network is a **module over the endomorphism ring of its lattice transformations**. Module elements are cell values. Ring elements are propagators. The module structure (lattice join = addition, propagator application = scalar action) governs all interactions.

This is not a metaphor — it is a precise algebraic characterization that provides decomposition theorems, composition laws, residuation (backward reasoning), quotient structures (e-graphs), and canonical uniqueness results (Krull-Schmidt) that directly apply to our architecture.

The module-theoretic lens unifies insights that currently live in separate subsystems: SRE's four relation types, PPN's domain filtration, narrowing's constructor enumeration, e-graph extraction, Galois bridges, QTT multiplicities, and module loading — all are instances of module-theoretic operations on the same substrate.

---

## 2. The Propagator Network as Module

### Definition

A **lattice-ordered module** (l-module) is a module M that is also a lattice, where:
- M is a lattice under partial order ≤
- Addition is order-preserving: m₁ ≤ m₂ ⟹ m₁ + n ≤ m₂ + n
- Scalar action by positive elements is order-preserving: r ≥ 0 ∧ m₁ ≤ m₂ ⟹ r·m₁ ≤ r·m₂

### In Prologos

- **Module elements**: cell values (type expressions, term values, constraint sets, session states)
- **Ring**: the endomorphism ring End(M) — all structure-preserving transformations on cell values
- **Ring multiplication**: propagator composition (applying two propagators in sequence)
- **Ring addition**: pointwise lattice join of propagator outputs
- **Scalar action**: propagator application — propagator f applied to cell value m gives f(m)

The lattice ordering on cell values (⊥ ≤ concrete ≤ ⊤ for each domain) is compatible with the module operations: applying a propagator to a "more defined" input gives a "more defined" output (monotonicity = order-preserving scalar action).

### Stronger structure: Quantale module

A **quantale module** is a complete lattice M with an action of a quantale Q:
- Q ⊗ M → M
- q ⊗ (⊔ S) = ⊔ {q ⊗ s | s ∈ S} (distributes over arbitrary joins)
- (q₁ ⊗ q₂) ⊗ m = q₁ ⊗ (q₂ ⊗ m) (associative)
- e ⊗ m = m (unit acts as identity)

Prologos already has quantale structure in effect ordering and session types. The session quantale acts on the type lattice — session steps transform which types are valid. This is the quantale module action: Q (session algebra) ⊗ M (type lattice) → M.

---

## 3. The Endomorphism Ring Decomposition (SRE)

### The four sub-rings

The SRE's four relation types correspond to four sub-rings of End(M):

| Relation | Algebraic kind | Property | Sub-ring |
|----------|---------------|----------|----------|
| Equality | Identity | f(x) = x | Kernel of "distance from identity" |
| Subtyping | Monotone | x ≤ y ⟹ f(x) ≤ f(y) | Order-preserving endomorphisms |
| Duality | Antitone | x ≤ y ⟹ f(x) ≥ f(y) | Order-reversing endomorphisms |
| Rewriting | Idempotent | f(f(x)) = f(x) | Projection-like endomorphisms |

### Krull-Schmidt uniqueness

For modules with both ascending and descending chain conditions (our lattices have finite height, our networks are finite), the direct sum decomposition into irreducible sub-rings is **unique up to isomorphism and reordering** (Krull-Schmidt theorem).

**Implication**: The four SRE relations are the canonical decomposition. A fifth relation type exists only if the endomorphism ring has a fifth irreducible summand.

### Variance as algebraic kind

Constructor field variance annotations are the endomorphism ring decomposition made local:
- **Covariant** field: uses the monotone sub-ring (same-direction subtyping)
- **Contravariant** field: uses the antitone sub-ring (reversed subtyping)
- **Invariant** field: uses the identity sub-ring (equality only)

This is currently implicit in `ctor-desc` variance annotations. Making it explicit as an **algebraic-kind** annotation would collapse per-relation special cases into generic kind-dispatched decomposition.

### Why duality is hardest

Antitone maps don't distribute over direct sums the way monotone maps do. For M = A ⊕ B:
- Monotone f decomposes as f = f_A ⊕ f_B (apply independently per component)
- Antitone f may mix components: f maps A into B and B into A

Session duality does exactly this: dual(Send) = Recv, dual(Recv) = Send — cross-component mapping. This mixing is algebraically fundamental, not an implementation artifact.

### Practical touch-point

**SRE `ctor-desc` enhancement**: Add `algebraic-kind` derivation from (variance, relation). The decomposition algorithm becomes:

```
(define (decompose-field desc field-idx relation)
  (define kind (algebraic-kind desc field-idx relation))
  (case kind
    [(monotone)   relation]
    [(antitone)   (dual relation)]
    [(identity)   'equality]
    [(idempotent) 'rewriting]))
```

Four lines replace dozens of per-relation cases across `sre-decompose-generic`, `sre-duality-decompose-dual-pair`, and the PAR Track 1 topology handler.

---

## 4. The PPN Filtration

### Filtration structure

The PPN's parse domains form a filtration of the parse module:

```
M₀ = Token lattice (characters → tokens)
M₁ = Surface lattice (tokens → bracketed structure + whitespace)
M₂ = Core lattice (surface → fully elaborated AST)
M_D = Demand lattice (elaboration requirements flowing backward)
```

M₀ ⊆ M₁ ⊆ M₂, with M_D branching into M₂.

### Associated graded module

The graded pieces gr_i = M_i / M_{i-1} capture what each level adds:
- gr₀ = Token (lexing)
- gr₁ = structural grouping (brackets, indent, whitespace significance)
- gr₂ = type annotations, macro expansion, name resolution
- gr_D = elaboration requirements

**Key property**: graded pieces are independent. Lexing reaches fixpoint independently of surface parsing. The propagator network allows all levels to propagate simultaneously with cross-level homomorphisms.

### The 14-stage pipeline collapse

The current 14-file pipeline (syntax.rkt → surface-syntax.rkt → parser.rkt → elaborator.rkt → ...) computes successive approximations of the same module element. The filtration perspective: these are not independent stages but overlapping views of one module, connected by the filtration structure.

The propagator network collapses this into: four lattice domains, cross-domain bridges (module homomorphisms), within-domain propagators. Bidirectional information flow between levels.

### Practical touch-point

PPN Tracks 2-4 should be designed as **new graded pieces** in the filtration, not as new pipeline stages. Cross-level propagators are module homomorphisms. The module theory guarantees adding a new graded piece doesn't invalidate existing ones (independence of associated graded).

The backward flow (Core → Surface → Token) is the residuation of the filtration homomorphism. When the type checker disambiguates `<` as comparison (not angle bracket), it's computing the residual of the Surface → Core homomorphism.

---

## 5. Residuation as Narrowing

### The algebraic structure

A **residuated lattice** has multiplication (·) and two division operations:

```
a · b ≤ c  ⟺  a ≤ c / b  ⟺  b ≤ a \ c
```

The divisions (residuals) are the "best approximation of undoing" the multiplication.

### For Prologos

- **Forward**: propagator f applied to input a gives f(a)
- **Backward (residual)**: given desired output b, the residual f \ b is the greatest input that produces output ≤ b
- **Guarantee**: monotone propagators on finite lattices always have computable residuals

### Narrowing IS residuation

Current narrowing (in `narrowing.rkt`): enumerate constructors C₁, C₂, ..., try each, backtrack on failure.

Residuation-based narrowing: compute `f \ v` structurally. For pattern-matching functions:

```
f(Zero)  = 0       ⟹  f \ 0 = Zero
f(Suc n) = 1 + f(n) ⟹  f \ 1 = Suc(f \ 0) = Suc(Zero)
```

No enumeration. No backtracking. The answer is computed directly by following the pattern match clauses in reverse.

### Existing bidirectional propagators ARE residuals

The `infer`/`check` duality in type checking is already residuation:
- `infer`: forward direction — given inputs, compute output type
- `check`: backward direction — given output type, constrain input types

Each manually-implemented backward propagator is the residual of its forward direction. Making this explicit (deriving backward from forward via residuation) would be analogous to automatic differentiation — computing the backward pass automatically.

### Practical touch-points

1. **Type inference**: `int+ \ (Int, 3, Int)` for argument 1 = `Int`. Already done manually; could be derived.
2. **Narrowing**: `f \ v` replaces constructor enumeration with structural residual computation.
3. **Logic engine**: backward chaining IS residuation. `solve(goal)` computes the residual of the forward derivation at `goal`.
4. **SRE decomposition**: `PVec \ (Int, Nat)` = decompose componentwise, respecting variance-as-algebraic-kind.

---

## 6. E-Graphs as Quotient Modules

### The quotient structure

An e-graph is the quotient module M/N where N is the equivalence relation generated by rewrite rules. Two terms in the same e-class are equivalent modulo rewrites.

- **Quotient map** π : M → M/N sends each term to its e-class
- **Section** s : M/N → M picks a representative from each class
- **Extraction** = finding the section that minimizes cost (tropical semiring)

### For PReductions

Current `reduction.rkt`: sequential step-by-step rewriting to normal form. No sharing, no parallel rewrites.

E-graph approach: build the quotient (saturate with all applicable rewrites), then extract the normal form (find the optimal section). Saturation is a lattice fixpoint (the e-graph grows monotonically). Extraction is a single pass.

### For PPN

Parse ambiguity is an e-graph: different parse trees for the same source are in the same e-class. Disambiguation is extraction — picking the best parse using precedence/associativity as cost.

**PPN's ambiguity resolution is e-graph extraction on the parse quotient module.**

### The saturation-as-fixpoint connection

E-graph saturation (applying all rewrites until no new e-classes form) IS a monotone fixpoint computation on a lattice:
- Elements: sets of e-classes (ordered by inclusion)
- Monotone: each rewrite adds e-class members (never removes)
- Fixpoint: no more rewrites produce new members

This is CALM-compliant. E-graph saturation can be parallelized under BSP. Each rewrite rule is a propagator. Independent rewrites fire concurrently. The PAR infrastructure we just built handles this.

### Practical touch-point

When we build the e-graph infrastructure (BSP-LE Track 3+, PRN), it should be:
1. A propagator network where each rewrite rule is a propagator
2. Cells hold e-class values (sets of equivalent terms)
3. Merge function is set-union (monotone)
4. BSP scheduler fires all applicable rewrites per round
5. Extraction uses tropical semiring (already researched)

The module theory guarantees: the quotient is well-defined (rewrite rules respect congruence), the saturation terminates (if rewrites are terminating, the quotient is Noetherian), and the extraction has a unique optimum (if the cost function is a semiring valuation).

---

## 7. Submodule Lattice as Architecture Validator

### The decomposition theorem

The submodules of a module M form a lattice under inclusion. The irreducible submodules (those that can't be further decomposed as direct sums) are the natural "units" of the system.

### For Prologos

Our ~10 subsystems (type inference, QTT, sessions, effects, traits, patterns, narrowing, logic, reduction, modules) should correspond to irreducible submodules.

**Computable validation**: given a network snapshot, compute connected components (cells connected if any propagator reads one and writes the other). Connected components = irreducible submodules. Compare to our subsystem boundaries.

If they match: architecture is canonically justified by Krull-Schmidt.
If they don't: the discrepancy reveals subsystems that should be merged (same component) or split (independent components within one subsystem).

### For parallelism (PAR)

Independent submodules (trivial meet — no shared cells) can fire concurrently with zero coordination. The submodule lattice IS the parallel partition. This gives the `:auto` heuristic a formal basis: compute the submodule decomposition, partition propagators by submodule, fire independent submodules in parallel.

### Practical touch-point

A small experiment: instrument one representative program's elaboration. After quiescence, dump the cell→propagator graph. Compute connected components. Compare to our subsystem list. This takes ~1 hour and provides architectural validation or architectural feedback.

---

## 8. QTT as Module Structure

The multiplicity semiring R = {0, 1, ω} with (max, ×) acts on the type lattice. A type used with multiplicity m is the scalar action m · T.

- **Submodule of linear types** (m = 1): types used exactly once
- **Submodule of erased types** (m = 0): types used zero times (compile-time only)
- **Submodule of unrestricted types** (m = ω): types used any number of times

The submodule lattice organizes all usage patterns. The residuation gives usage inference: if you know the result type and function type, the residual tells you the required argument multiplicity.

**Tensor product**: M ⊗_R N captures how two QTT-typed terms interact through the multiplicity semiring. Two linear resources combined have usage that's the tensor product of their individual usages.

---

## 9. Module Loading as Module Composition

The `.pnet` cached module system is literally module theory:

- **Modules form a lattice** under "contains" ordering
- **Module composition** is module sum (loading A then B = A + B)
- **Module interfaces** are quotient modules (public API = module modulo internals)
- **Cached loading** is module memoization
- **Parallel loading** is safe when modules commute (symmetric tensor product)

Making this explicit gives formal tools for reasoning about module compatibility, incremental compilation, and parallel loading.

---

## 10. Connections to Other Series

### PRN (Propagator-Rewriting-Network) — Theory home

Module theory IS the algebraic foundation for PRN. The confirmed findings in PRN (hypergraph rewriting, tree rewriting = structural unification, tropical optimization) are all instances of module-theoretic operations:
- Hypergraph rewriting = endomorphism application on the network module
- Tree rewriting = SRE's rewriting sub-ring
- Tropical optimization = section extraction from quotient modules

### PPN (Propagator-Parsing-Network)

- Filtration structure (§4): four domains are a module filtration
- Cross-level bridges are module homomorphisms
- Parse ambiguity resolution is quotient-module extraction
- Backward flow (type checker → parser) is filtration residuation

### SRE (Structural Reasoning Engine)

- Endomorphism ring decomposition (§3): four relations are four sub-rings
- Variance as algebraic kind: ctor-desc enhancement
- Duality hardness is algebraically fundamental (antitone mixing)
- Future: generic kind-dispatched decomposition

### PTF (Propagator Theory Foundations)

- Propagator kinds gain algebraic grounding:
  - Map = monotone endomorphism
  - Reduce = meet operation (dual of join)
  - Broadcast = lattice homomorphism (preserves joins)
  - Scatter = decomposition homomorphism
  - Gather = composition (tensor product) homomorphism
- Parallel profiles derive from algebraic kind: independent sub-ring elements commute → parallel-safe

### PAR (Parallel Scheduling)

- Submodule independence = parallelizability (§7)
- CALM theorem IS the monotone-endomorphism fixpoint theorem applied to the module
- The `:auto` heuristic has formal basis: partition by submodule decomposition
- Stratification IS the handling of non-monotone endomorphisms (antitone, non-idempotent)

### BSP-LE (Logic Engine on Propagators)

- E-graphs as quotient modules (§6)
- Residuation as narrowing replacement (§5)
- Tabling = memoized sections of the quotient map
- ATMS = module over a Boolean algebra of assumptions (each assumption is a ring element)

### CIU (Collection Interface Unification)

- Collection traits are module morphisms between container-specific lattices
- `Seq` protocol: module homomorphism from container module to abstract sequential module
- `Foldable`, `Traversable`: natural transformations (module morphisms) between container functors
- Trait dispatch: selecting which module morphism to apply

### NTT (Network Type Theory)

- New syntax declarations for module structure:
  - `:lattice :module R` — declares a cell as an R-module
  - `:relation :monotone`, `:relation :antitone`, `:relation :idempotent` — algebraic kinds
  - `:bridge :homomorphism` — module homomorphism between lattices
  - `:quotient :rewrite-rules` — e-graph quotient module
- Module-theoretic typing of the network: the NTT type system types the module structure, not just cell values

### PM (Propagator Migration)

- Each subsystem being migrated onto the network is a submodule
- The migration IS computing the direct sum decomposition: identify the submodule, define its lattice, register its endomorphisms, connect via bridges
- The migration order follows the filtration: lower-level submodules first (parsing), then higher-level (elaboration), then cross-cutting (trait dispatch, effects)

---

## 11. Immediate Architectural Implications

### Near-term (current tracks)

1. **SRE algebraic-kind annotation**: Add to `ctor-desc`. Collapse per-relation special cases. Directly simplifies PAR Track 1's topology handler complexity.

2. **PPN graded-piece design**: PPN Tracks 2-4 designed as filtration levels, not pipeline stages. Cross-level propagators are module homomorphisms.

3. **Submodule validation experiment**: Compute irreducible decomposition of a representative network. Compare to subsystem boundaries. ~1 hour.

### Medium-term (next series)

4. **Residuation for narrowing**: Implement structural residual computation. Narrowing becomes computation, not search. Collapses `narrowing.rkt` from search+backtrack to residual evaluation.

5. **E-graph propagator for reduction**: Replace sequential reduction with quotient-module saturation. Parallel-friendly, sharing-exploiting, produces optimal normal forms.

### Longer-term (bootstrap/Logos)

6. **Module-theoretic type system**: NTT types the module structure itself. Cell values are typed. Propagators are typed endomorphisms. Bridges are typed homomorphisms. The type system ensures module-theoretic well-formedness.

7. **Automatic residuation**: Derive backward propagators from forward propagators algebraically. Analogous to automatic differentiation. Every forward propagator gets a free backward direction.

---

## 12. Relationship to Hyperlattice Conjecture

The Hyperlattice Conjecture states: "Any computation can be expressed as a fixpoint over interconnected lattice structures."

Module theory refines this to: **"Any computation is a fixpoint of an endomorphism on a module over a lattice-ordered ring."**

- The **ring** captures the transformations (propagators)
- The **module** captures the state (cell values)
- The **fixpoint** is the module-theoretic stable element under the ring action
- **CALM** becomes: monotone endomorphisms on a fixed module converge to a unique fixpoint (Tarski applied to the module setting)
- **Stratification** is the handling of non-monotone endomorphisms: isolate them between strata where the module is fixed

The module-theoretic formulation is more precise than the original conjecture because it distinguishes between the lattice of values (the module) and the algebra of transformations (the ring). The conjecture conflated them. The module theory separates them, which is why it provides decomposition (Krull-Schmidt), composition (tensor products), backward reasoning (residuation), and quotients (e-graphs) that the bare lattice formulation doesn't.

---

## 13. Open Research Questions

1. **Is our propagator algebra residuated?** Empirically, bidirectional propagators work. Algebraically, monotone propagators on finite lattices have residuals. But do ALL our propagators satisfy the residuation laws? Specifically: are our non-monotone operations (negation-as-failure, retraction) compatible with residuation at the stratum level?

2. **Is the Krull-Schmidt decomposition computable in practice?** For small networks (10-100 cells), yes. For the full elaboration network (1000+ cells during prelude loading), the computation might be too expensive. Can we approximate?

3. **Does the filtration extend beyond parsing?** The Token → Surface → Core filtration is clear. But does elaboration → type checking → QTT → zonk form another filtration? If so, the entire compilation pipeline is a single module filtration, and the propagator network computes all levels simultaneously.

4. **Can we formalize the `:auto` heuristic as submodule partition?** The submodule decomposition gives us the parallel partition. But computing it per-quiescence-call might be too expensive. Can we precompute it at network construction time (when propagators are registered)?

5. **What is the homological dimension of our type lattice?** Higher Ext groups classify increasingly complex failure modes. If Ext¹ classifies simple type mismatches and Ext² classifies interaction failures, this could drive a principled error taxonomy.
