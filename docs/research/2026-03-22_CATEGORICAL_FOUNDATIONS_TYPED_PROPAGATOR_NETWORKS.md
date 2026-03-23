# Categorical Foundations of Typed Propagator Networks

**Stage**: 0-1 Research
**Date**: 2026-03-22
**Series**: NTT (Network Type Theory) — Research Document 1 of 4
**Feeds into**: SRE Series scoping, NTT Research Doc 2 (Network Type Theory for Prologos)

## Abstract

This document establishes the categorical foundations for typing propagator
networks. We examine three candidate categorical frameworks — operads,
PROPs, and polynomial functors — and argue that **polynomial functors
(Spivak's Poly)** are the most natural fit for propagator networks due to
their native support for dependent fan-out, compositional wiring, and
mode-dependent dynamics. We then characterize the stratified architecture as
a **Grothendieck fibration** over the stratum poset, with inter-stratum
interactions captured by **Kan extensions**. Finally, we show how the
Structural Reasoning Engine (SRE) insight — that PUnify's structural
decomposition is a universal primitive — unifies the categorical treatment
across all five subsystems.

The goal is not to impose category theory on the implementation, but to
identify the *structures that already exist* in our codebase and give them
precise names. This precision enables a typing discipline (NTT Research Doc
2) where composition errors become type errors.

---

## 1. The Categorical Question

Our propagator network has several dimensions of structure:

| Dimension | What it governs | Current implementation |
|-----------|----------------|----------------------|
| **Substrate** | What values cells hold, how they combine | Lattice merge functions in `infra-cell.rkt` (6 merge operators: union, append, set-union, replace, etc.) |
| **Connectivity** | Which cells a propagator reads/writes | Propagator dependency registration in `propagator.rkt` |
| **Monotonicity** | Whether propagators preserve information ordering | Implicit contract — not checked |
| **Bridging** | How different lattice domains communicate | Galois connections (α/γ) in session-propagators, pure bridge fire functions in `resolution.rkt` |
| **Stratification** | How non-monotone operations interleave with monotone ones | S(-1)→S0→S1→S2 loop in `metavar-store.rkt` |
| **Interaction** | Speculative vs demand-driven inter-stratum flow | Left Kan (readiness propagators forward partial results) / Right Kan (demand thresholds) |

The categorical question is: **what single framework captures all six
dimensions in a way that makes composition type-safe?**

---

## 2. Three Candidate Frameworks

### 2.1 Operads

An operad captures "operations with multiple inputs and one output, that
compose by plugging outputs into inputs." Colors (types) label the
input/output ports; composition is well-defined when colors match.

**Fit for propagators**: Operads handle the multi-input aspect of
propagators naturally — a propagator reading from 3 cells and writing to 1
is an operation in the operad with 3 inputs and 1 output.

**Limitation**: Operads are *single-output*. A propagator that writes to
multiple cells (fan-out) — which is common in our architecture (structural
decomposition propagators write to domain cell AND codomain cell) — doesn't
fit the operad framework directly. One can encode fan-out via auxiliary
"tuple" outputs, but this is unnatural and obscures the actual connectivity.

**Verdict**: Operads capture the composition grammar but not the fan-out
topology. They are a useful *sub-structure* (the SRE's form registry is
operad-like) but not the right *foundation*.

### 2.2 PROPs (PROducts and Permutations)

A PROP is a symmetric strict monoidal category whose objects are natural
numbers (representing port counts) and whose tensor product is addition.
Morphisms have multiple inputs AND multiple outputs. Composition is wiring:
outputs of one morphism connect to inputs of another, with symmetric
monoidal structure handling routing.

**Fit for propagators**: PROPs handle fan-out natively. A propagator
reading 3 cells and writing 2 is a morphism 3 → 2 in the PROP. Composition
by wiring matches how we compose propagator subnetworks.

**Limitation**: PROPs have *fixed arity*. A structural decomposition
propagator's fan-out depends on the constructor tag: decomposing a Pi
produces 2 sub-cells (domain, codomain); decomposing an App produces 2
different sub-cells (function, argument); decomposing a PVec produces 1
sub-cell (element type). The arity is data-dependent, not fixed. PROPs
can't express this without resorting to "maximum arity with unused ports,"
which is wasteful and semantically wrong.

**Verdict**: PROPs capture connectivity and fan-out but not dependent arity.
Better than operads but still not the right foundation for our architecture.

### 2.3 Polynomial Functors (Spivak's Poly)

A polynomial functor `p(y) = Σ_{i∈I} y^{B_i}` describes a system with:
- **Positions** I: the output interface (one position per output)
- **Directions** B_i: the input interface *at each position* (what inputs
  are needed to compute output i)

The category **Poly** of polynomial endofunctors on Set has remarkable
structure: four interacting monoidal products, a rich theory of
composition, and native support for *mode-dependent dynamics* — systems
whose interface topology changes based on their state.

**Fit for propagators**: Polynomial functors handle dependent fan-out
natively. A structural decomposition propagator is a polynomial functor
whose positions depend on the constructor tag:

```
p_decompose(y) = y^{domain, codomain}     when input is Pi
               + y^{function, argument}    when input is App
               + y^{element}              when input is PVec
               + ...
```

The Σ (coproduct) handles the case split. Each summand has its own set of
directions (sub-cell types). This IS what `punify-dispatch-sub` does in our
codebase — it case-splits on the constructor tag and produces different
numbers of sub-cells for each case.

**Composition** in Poly corresponds to wiring: plugging one system's outputs
into another's inputs. This is exactly how we compose propagator
subnetworks — connect output cells to input cells. The polynomial functor
composition handles the bookkeeping of which outputs go where.

**Mode-dependent dynamics**: Spivak's framework natively handles systems
whose interface changes during execution. Our elaboration network does this
— the number of cells and propagators grows as elaboration proceeds. Each
`fresh-meta` call adds a new cell to the network's interface. Polynomial
functors model this growth as a change of "mode" (the current interface
state).

**Verdict**: Polynomial functors are the right foundation. They capture
dependent fan-out (structural decomposition), compositional wiring (network
composition), mode-dependent dynamics (growing networks), and have a rich
categorical theory that connects to our other structures.

### 2.4 Summary

| Framework | Multi-input | Multi-output | Dependent arity | Mode-dependent | Verdict |
|-----------|------------|-------------|----------------|---------------|---------|
| Operad | ✓ | ✗ | ✗ | ✗ | Sub-structure only |
| PROP | ✓ | ✓ | ✗ | ✗ | Better, not sufficient |
| Poly | ✓ | ✓ | ✓ | ✓ | **Foundation** |

---

## 3. The Propagator Network as Polynomial Functor

### 3.1 The Basic Correspondence

A propagator network with interface (input cells I, output cells O, internal cells hidden) corresponds to a polynomial functor:

```
Network(y) = Σ_{o ∈ O} y^{deps(o)}
```

where `deps(o)` is the set of cells that output cell `o` depends on
(transitively, through propagators). Each output position `o` needs
information from its dependency set `deps(o)` — these are the "directions"
at that position.

**In our codebase**: The `elab-network` struct bundles:
- `prop-net`: the underlying propagator network (cells + propagators + worklist)
- `cell-info`: per-cell metadata (type, lattice, merge function)
- `id-map`: meta-id → cell-id mapping
- `meta-info`: per-meta registration records

The `prop-net` inside `elab-network` is the carrier of the polynomial
functor. The `cell-info` map provides the typing information (what lattice
each position lives in). The propagator dependency edges encode the
function `deps(o)`.

### 3.2 Propagators as Natural Transformations

A propagator that reads cells `(c1, c2, c3)` and writes cell `c4` is a
natural transformation between polynomial functors:

```
fire: p_input → p_output
```

where `p_input(y) = y^{c1} × y^{c2} × y^{c3}` (read three cells) and
`p_output(y) = y^{c4}` (write one cell). The naturality condition is
**monotonicity**: the fire function respects the lattice ordering on cell
values.

**In our codebase**: Each propagator's fire function in `propagator.rkt` is
a `(prop-network → prop-network)` function that reads dependency cells and
writes result cells. The monotonicity contract is implicit — we don't check
it. A typing discipline (NTT Doc 2) would make this explicit as a `:where
Monotone` constraint.

### 3.3 Structural Decomposition as Polynomial Dispatch

The SRE insight connects here directly. PUnify's `punify-dispatch-sub`
performs case analysis on a cell value's constructor tag and creates
different sub-cell configurations for each case. This is precisely a
**polynomial functor with mode-dependent interface**:

```
p_structural(y) = Σ_{tag ∈ Constructors} y^{sub-cells(tag)}
```

The case split over constructors is the Σ (coproduct). For each constructor
tag, the sub-cells are the directions. The SRE form registry would be
the catalog of these polynomial functor summands — each registered
structural form adds a summand to the polynomial.

**Example from our codebase**: `get-or-create-sub-cells` in
`punify-dispatch.rkt` returns different numbers of sub-cells depending
on the constructor:

| Constructor | Sub-cells | Polynomial summand |
|------------|-----------|-------------------|
| Pi | domain, codomain | y² |
| Sigma | fst-type, snd-type | y² |
| App | fn, arg | y² |
| PVec | element | y¹ |
| Map | key, val | y² |
| Set | element | y¹ |

The polynomial functor for our current type decomposition is:

```
p_type-decompose(y) = y² + y² + y² + y¹ + y² + y¹ + ...
                       Pi   Sigma App  PVec Map  Set
```

Adding a new constructor to the SRE form registry adds a new summand.
The polynomial functor grows as the language grows. This is the
mathematical content of "domain-parameterized structural decomposition."

---

## 4. Stratification as Grothendieck Fibration

### 4.1 The Stratum Poset

Our stratification has four strata ordered as:

```
S(-1) → S0 → S1 → S2
  ↑                 |
  └─────────────────┘ (cycle, fuel-bounded)
```

This is a poset B = {S(-1), S0, S1, S2} with the ordering
S(-1) < S0 < S1 < S2 (within one cycle). The cycle S2 → S(-1) is
fuel-bounded to ensure termination.

### 4.2 Fibers

Each stratum has a **fiber** — the category of networks that operate at
that stratum level:

| Stratum | Fiber | Monotonicity | Our implementation |
|---------|-------|-------------|-------------------|
| S(-1) | Retraction networks | Non-monotone (cell values can decrease) | `run-retraction-stratum!` — cleans scoped infrastructure cells |
| S0 | Base propagation | Monotone | `run-to-quiescence` — type inference, structural unification, bridge propagators |
| S1 | Readiness detection | Monotone | Ready-queue: checks if all dependency cells are ground |
| S2 | Action execution | Non-monotone (commits speculative branches, creates new constraints) | Stratified resolution: trait resolution, HasMethod, constraint retry |

**Post-Track 8D**: Bridge propagators (trait, hasmethod) fire in S0 as
pure `pnet → pnet` functions. S2 becomes a safety net for cases where
bridges didn't fire (missing impl, unresolved dependency). This means
S0's fiber has expanded to include resolution — the "phase boundary" between
type inference and constraint resolution has dissolved within S0.

### 4.3 The Fibration Structure

A Grothendieck fibration p: E → B assigns to each object b ∈ B a
fiber category E_b, and to each morphism f: a → b in B a reindexing
functor f*: E_b → E_a.

In our system:
- B = stratum poset
- E_b = category of networks at stratum b
- Morphisms in B = stratum transitions
- Reindexing = how a network "appears" when viewed from a different stratum

**Cartesian lifts**: When S1 detects a "ready" constraint (a cell whose
dependencies are all ground), this uniquely determines what happened in S0
— the type propagation that grounded those dependencies. The readiness
cell is a cartesian lift: it lifts the S1 observation back to a unique
S0 history. This is the defining property of a fibration.

**Opcartesian lifts**: When S2 commits a resolution (e.g., selects the
`List--Eq` impl for an `Eq (List Int)` constraint), this pushes forward
into S(-1) retraction — failed alternatives are retracted. The commitment
uniquely determines the retraction. This is the defining property of an
opfibration.

Together: the stratification is a **bifibration** (both fibration and
opfibration) — but with an important caveat from our 2026-03-21 Five
Systems analysis: the opfibration structure is genuine for the type checker
(System III) but aspirational for others. The SRE would make it genuine
for all systems by giving them the same structural reasoning substrate.

### 4.4 Relationship to Prior Analysis

Our 2026-03-21 "Categorical Structure of Five Systems" document found:

- **System I (NAF-LE)**: Sequential endomorphism composition, NOT an
  opfibration — lacks cartesian lifts because clause ordering breaks
  uniqueness.
- **System II (WF-LE)**: Iterative Kleene chain on product bilattice —
  ordered fixed-point computation, not a fibration.
- **System III (Type checker)**: Two-barrier opfibration over cylindrical
  base [4]×[n] — the ONLY genuine fibration in the current implementation.
- **System IV (QTT + Sessions)**: Two independent domains — traced monoidal
  (sessions) || functor (QTT). Galois connection aspirational.
- **System V (S(-1) Retraction)**: Non-monotone endomorphism — phase of
  System III, not standalone.

**How the SRE changes this**: When all five systems use the same structural
decomposition primitive (SRE forms), they all inhabit the same polynomial
functor category. The fibration structure becomes uniform — each system's
"fiber" is a subcategory of the SRE's structural form category, restricted
to the domain-specific forms. The cartesian/opcartesian lifts are provided
by the SRE's propagation semantics (structural decomposition propagators
fire uniformly across domains).

---

## 5. Inter-Stratum Interaction: Kan Extensions

### 5.1 Left Kan Extension (Speculative Forwarding)

A left Kan extension Lan_F G computes the "best approximation from below"
of a functor G along a functor F. In our system:

- F: S0 fiber → stratum poset (embedding S0 networks into the global view)
- G: the "partial fixpoint" functor (what S0 has computed so far)
- Lan_F G: the best approximation of the eventual S0 result, available
  to S1 *before* S0 reaches quiescence

**In our implementation**: Readiness propagators in S0 forward partial
results to S1 as they become available. When a dependency cell is solved,
the readiness propagator immediately checks if the constraint is ready —
without waiting for full S0 quiescence. This IS speculative forwarding:
S1 gets an early approximation (the readiness check) based on S0's partial
fixpoint.

Post-Track 8C: Bridge propagators make this even more direct — trait
resolution fires in S0 itself, not waiting for S1→S2. The "speculative
forwarding" has collapsed into "S0 does more work," reducing the need for
cross-stratum Kan extensions. The left Kan extension is still the right
categorical description of what's happening (partial fixpoint → best
approximation), but the implementation has internalized it.

### 5.2 Right Kan Extension (Demand-Driven Evaluation)

A right Kan extension Ran_F G computes the "best approximation from above."
In our system, this captures demand-driven evaluation:

- G: the "what S1 needs" functor (which cells need to be ground for
  readiness checks)
- Ran_F G: the minimal S0 computation needed to satisfy S1's demands

**In our implementation**: Threshold propagators (from Track 7) express
demand: "don't fire until this cell transitions from ⊥ to a non-⊥ value."
The threshold is a Right Kan demand — S0 computes only what's needed to
satisfy the threshold, not the entire fixpoint.

### 5.3 The Adjoint Pair

Left and Right Kan extensions form an adjoint pair: Lan_F ⊣ Ran_F. The
adjunction says: speculative forwarding and demand-driven evaluation are
*dual* — they're two perspectives on the same inter-stratum interaction.

**In our implementation**: The combination of bridge propagators (left Kan —
speculatively resolve when dependencies are ready) and threshold propagators
(right Kan — only fire when demanded) gives us both perspectives
simultaneously. A constraint is resolved when either:
1. Its dependencies become ground and the bridge speculatively resolves it
   (left Kan), OR
2. Something downstream demands the resolution and triggers computation
   (right Kan)

The adjunction guarantees: both paths reach the same result. This is the
formal justification for our "bridges + thresholds" architecture.

---

## 6. Quantale Enrichment and QTT

### 6.1 Quantale Structure on the Type Lattice

A quantale is a complete lattice equipped with an associative binary
operation (tensor) that distributes over arbitrary joins. Our type lattice
has this structure:

- The lattice: type expressions ordered by subtyping (⊥ < Int < Num < ⊤)
- The tensor: type-level application (→ is a tensor on types)
- Distribution: application distributes over union types
  (`f (A | B) = f A | f B`)

**In our implementation**: The `type-lattice.rkt` merge function implements
the join. Subtyping (from refined numeric subtyping, Phase E) provides the
ordering. The quantale structure is implicit — we use it when checking
function types against union argument types — but it's there.

### 6.2 QTT Multiplicities as Quantale Morphisms

QTT (Quantitative Type Theory) assigns multiplicities to variable usages:
0 (erased), 1 (linear), ω (unrestricted). These multiplicities form a
quantale:

```
{0, 1, ω} with ordering: 0 ≤ 1 ≤ ω
tensor: multiplicity multiplication (1·1=1, 1·ω=ω, 0·anything=0)
```

A well-typed program is a **quantale morphism** from the multiplicity
quantale to the type quantale — it maps multiplicity annotations to
type-level constraints that preserve the quantale structure.

**In our implementation**: `qtt.rkt` tracks multiplicities alongside types.
The `mult-lattice-merge` in `infra-cell.rkt` handles the multiplicity
lattice. Cross-domain bridges between the type lattice and the multiplicity
lattice (Track 8 A3a: `type->mult-alpha` / `mult->type-gamma`) are
quantale morphisms — they preserve the tensor structure.

### 6.3 Session Types and Traced Monoidal Structure

Session types in our system have a traced monoidal structure:

- Objects: session protocol types (Send A ; S, Recv A ; S, End)
- Tensor: parallel composition of sessions (S1 ⊗ S2)
- Trace: recursion/feedback (μX. S[X])

The duality checking (`sess-dual?`) is an involution in this category,
and the session-type bridge propagators in `session-propagators.rkt`
implement the Galois connection between the type domain and the session
domain.

**Connection to Poly**: Each session protocol is a polynomial functor
where positions are the communication actions (send/receive) and directions
are the payloads (the types being communicated). Protocol composition is
polynomial functor composition. Duality is the *dual polynomial* (swapping
positions and directions). This gives session types a direct interpretation
in the Poly framework.

---

## 7. The SRE as Universal Structural Functor

### 7.1 Structural Forms as Polynomial Summands

The SRE insight (Research Doc: Structural Reasoning Engine, 2026-03-22)
says: PUnify's structural decomposition is a universal primitive. In
categorical terms:

**Each structural form in the SRE form registry is a summand of a
polynomial functor.**

The SRE's form registry is:

```
p_SRE(y) = Σ_{form ∈ Registry} y^{sub-cells(form)}
```

Adding a new form to the registry adds a new summand. The SRE's
`structural-relate(cell, Form(sub-cells))` call instantiates the
appropriate summand — creating sub-cells and installing decomposition
propagators.

### 7.2 Cross-Domain Unification via Bridges

When the SRE operates across domains (type domain ↔ session domain ↔ mult
domain), the cross-domain interaction is a **Galois connection between
polynomial functors**:

```
α: p_type → p_session     (type information → session constraints)
γ: p_session → p_type     (session information → type constraints)
```

The adjunction α ⊣ γ guarantees soundness: information flowing from types
to sessions and back to types doesn't lose information (the round-trip
is inflationary, not deflationary).

**In our implementation**: Track 8D's pure bridge fire functions are
the concrete realization:
- `make-pure-trait-bridge-fire-fn`: reads type cells → resolves trait
  constraint → writes dict cells. This is α: type domain → trait domain.
- The reverse direction (dict availability informs type inference) is γ.

### 7.3 The SRE Unifies All Five Systems

With the SRE as universal structural functor:

| System | Pre-SRE categorical structure | Post-SRE categorical structure |
|--------|------------------------------|-------------------------------|
| NAF-LE | Sequential endomorphism | Polynomial functor fiber (inductive structural forms) |
| WF-LE | Kleene chain on bilattice | Polynomial functor fiber (bilattice structural forms) |
| Type checker | Opfibration over stratum poset | Polynomial functor fiber (type structural forms) — the SRE IS the fiber |
| QTT + Sessions | Independent domains with aspired Galois connection | Galois connection between polynomial functors (realized via pure bridges) |
| S(-1) Retraction | Non-monotone endomorphism | Non-monotone endomorphism on the polynomial functor's state (reindexing) |

The key simplification: instead of each system having its own categorical
character (the mess our Five Systems analysis documented), all five share
the same polynomial functor foundation. Domain-specific behavior comes from
which structural forms are registered, not from different categorical
structures.

---

## 8. Implications for the Type Tower

The categorical foundations established here directly inform the 7-level
type tower proposed in the network type theory discussion:

| Level | Type | Categorical structure (from this document) |
|-------|------|------------------------------------------|
| 0 | Lattice | Complete lattice (possibly quantale-enriched) |
| 1 | Cell | Parameterized by lattice type: `Cell L` |
| 2 | Propagator | Natural transformation between polynomials with monotonicity constraint |
| 3 | Network | Polynomial functor `p(y) = Σ_{i∈I} y^{B_i}` with typed interface |
| 4 | Bridge | Galois connection between polynomial functors (adjunction α ⊣ γ) |
| 5 | Stratification | Grothendieck (bi)fibration over stratum poset |
| 6 | Fixpoint/Interaction | lfp (inductive) / gfp (coinductive) as initial/terminal algebras; Kan extensions as inter-stratum interaction |

Each level's type system is grounded in the categorical structure from
this document. The typing rules at each level enforce the categorical
laws (monotonicity = naturality, bridge soundness = adjunction laws,
stratification well-foundedness = fibration condition).

---

## 9. Open Questions

### 9.1 Dependent Polynomial Functors

Our structural decomposition has *dependent* sub-cell types — the sub-cell
lattice types depend on the constructor tag. Standard polynomial functors
handle this via the Σ (coproduct), but the internal type dependency suggests
we may need *dependent polynomial functors* — polynomial functors in a
dependent type theory. Spivak's framework operates in Set; we may need to
lift it to the slice category Set/U for a universe U of lattice types.

### 9.2 Non-Monotone Strata and the Fibration

The bifibration characterization works for monotone strata (S0, S1) but
S(-1) and S2 are non-monotone. Non-monotone functors don't preserve the
fibration structure. The resolution may be: S(-1) and S2 are *phase
transitions* (reindexing functors) rather than fibers. The fibration is
over the monotone strata; the non-monotone strata are the reindexing
morphisms. This needs formalization.

### 9.3 Quantale Enrichment Across Domains

The type lattice, multiplicity lattice, and session lattice each have
quantale structure. The bridges between them should be quantale morphisms
(preserving tensor). We assert this but haven't verified it for all bridges
— particularly the session-type bridge, where the tensor structures are
quite different (parallel session composition vs function type application).

### 9.4 E-Graph Layer and Equality Saturation

The proposed reduction-as-propagation architecture (Track 9 research) adds
an e-graph layer where cells hold *sets of equivalent forms*. The
categorical structure of e-graphs is a *congruence closure* — a quotient of
the free term algebra. How this quotient interacts with the polynomial
functor structure is an open question. One possibility: e-classes are
polynomial functors with position equivalence (positions in the same
e-class are identified), and saturation is the colimit over rewrite rules.

### 9.5 Tropical Semiring and Optimization

The proposed tropical semiring optimization layer (min-plus algebra for
cost-based e-graph extraction) introduces a second quantale enrichment
alongside the existing lattice structure. How two quantale enrichments
interact on the same polynomial functor is a question for the type theory
(NTT Doc 2): can a cell be simultaneously lattice-enriched (for
correctness) and tropical-enriched (for optimization)?

---

## 10. Relationship to Existing Research

### 10.1 Spivak's Poly Framework

Our polynomial functor characterization draws directly from Spivak and
Niu's "Polynomial Functors: A Mathematical Theory of Interaction"
(arXiv:2312.00990, Cambridge University Press 2024). Their framework for
mode-dependent dynamical systems maps closely to our growing-network
semantics. The key insight we import: polynomial functors compose by
*wiring* — plugging outputs into inputs — which is exactly how we compose
propagator subnetworks.

### 10.2 Lafont's Interaction Nets

The interaction net framework (Lafont, 1990) provides the graph-rewriting
semantics for reduction on propagator networks. Interaction nets are
themselves polynomial functors (each agent type is a polynomial summand),
and interaction rules are natural transformations. This connects our SRE
(structural decomposition) to our reduction plans (Track 9): both are
polynomial functor operations.

### 10.3 Girard's Geometry of Interaction

The GoI execution formula `EX(σ) = (1 - σπ)^{-1} · σ · (1-π)` is a
fixpoint computation — and fixpoint computation is what propagator networks
do (run-to-quiescence). This connection was identified in the standup
discussion on reduction: propagation to quiescence IS the GoI iteration
`I + σπ + (σπ)² + ...`. The categorical home for this is the traced
monoidal category (where the trace operation captures feedback/recursion),
which our session type domain already inhabits.

### 10.4 Hinze's Kan Extensions for Program Optimization

Hinze's work on Kan extensions for program optimization (2012) shows how
left and right Kan extensions capture fusion and accumulation patterns. Our
inter-stratum interaction patterns (speculative forwarding = left Kan,
demand-driven = right Kan) are instances of Hinze's framework applied to
the stratum poset rather than to program transformations. The adjunction
Lan ⊣ Ran guarantees that speculative and demand-driven approaches agree.

---

## 11. Summary and Next Steps

### Key Results

1. **Polynomial functors (Poly) are the right foundation** for typing
   propagator networks. They handle dependent fan-out, compositional
   wiring, and mode-dependent dynamics — all essential features of our
   architecture.

2. **The stratification is a Grothendieck (bi)fibration** over the stratum
   poset. Cartesian lifts capture readiness detection; opcartesian lifts
   capture resolution commitment. Post-Track 8C, the bifibration is
   genuine for the type checker; the SRE would make it genuine for all
   systems.

3. **Inter-stratum interactions are Kan extensions.** Left Kan = speculative
   forwarding (bridge propagators fire on partial fixpoints). Right Kan =
   demand-driven evaluation (threshold propagators fire on demand). The
   adjunction guarantees both paths agree.

4. **The SRE unifies all five systems** under one polynomial functor
   framework. Domain-specific behavior comes from registered structural
   forms (polynomial summands), not different categorical structures.

5. **Quantale enrichment captures QTT, sessions, and (future) tropical
   optimization** as compatible enrichment layers on the same polynomial
   functor foundation.

### Next Steps

- **NTT Research Doc 2** (Network Type Theory for Prologos): Define the
  typing rules at each level of the type tower, grounded in the categorical
  structures from this document. Key deliverable: what does a `Monotone`
  constraint look like as a dependent type? How does the compiler verify
  adjunction laws?

- **NTT Research Doc 3** (Language Design: Network Type Ergonomics):
  Surface syntax for `lattice`, `cell`, `propagator`, `network`, `bridge`,
  `stratification`. Progressive disclosure: which categorical structure is
  visible at each user level?

- **SRE Series Track 0 scoping**: The form registry's data model should
  carry polynomial functor typing information from day one. Each registered
  form is a polynomial summand with typed positions and directions.

---

## References

- Spivak, D. & Niu, N. (2024). *Polynomial Functors: A Mathematical Theory
  of Interaction*. Cambridge University Press. arXiv:2312.00990
- Spivak, D. (2020). "Poly: An abundant categorical setting for
  mode-dependent dynamics." arXiv:2005.01894
- Lafont, Y. (1990). "Interaction Nets." POPL 1990.
- Girard, J.-Y. (1989). "Geometry of Interaction I: Interpretation of
  System F." Logic Colloquium '88.
- Hinze, R. (2012). "Kan Extensions for Program Optimisation."
  Mathematics of Program Construction 2012.
- Grothendieck, A. (1971). "Revêtements étales et groupe fondamental"
  (SGA 1). Lecture Notes in Mathematics 224.
- Curien, P.-L. (1993). *Categorical Combinators, Sequential Algorithms
  and Functional Programming*. Birkhäuser.
