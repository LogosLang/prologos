# The Lattice Hierarchy: What Each Algebraic Property Gives a Propagator Network

**Date**: 2026-04-30
**Stage**: 0/1 (deep research, vocabulary, theory grounding)
**Series**: [PTF (Propagator Theory Foundations)](../tracking/2026-03-28_PTF_MASTER.md)
**Companion notes**:
- [Lattice Variety and Canonical Form for SRE](2026-04-30_LATTICE_VARIETY_AND_CANONICAL_FORM_FOR_SRE.md) (element-level theory)
- [Widening, Narrowing, and Continuity for UCS](2026-04-30_WIDENING_NARROWING_INFINITE_DOMAINS_FOR_UCS.md) (limit-level theory)
- [Algebraic Embeddings on Lattices](2026-03-28_ALGEBRAIC_EMBEDDINGS_LATTICES.md) (PTF's existing piece on this; this note refines and extends)

**Status**: Research synthesis. No design commitments. Anchored on the SRE Track 2I Phase 3c (2026-04-30) bonus discovery — that the type lattice's distributivity status flipped under principled per-relation dispatch — as a worked example of why the lattice-hierarchy posture matters in practice.

---

## 1. Why this note exists

The propagator network's correctness, optimization potential, and expressivity all turn on **what algebraic properties hold of the lattices the cells live in**. This is not a peripheral concern — it is the substrate of every architectural decision about how propagators compose, what canonical forms apply, what dispatch strategies are sound, and what error-reporting capabilities are unlocked.

PTF's [Algebraic Embeddings on Lattices](2026-03-28_ALGEBRAIC_EMBEDDINGS_LATTICES.md) (2026-03-28) establishes the catalog. This note refines: **the lattice hierarchy from free at the top to Boolean at the bottom is itself a precise framework that tells us, per algebraic property, what concrete capabilities and optimizations become available.**

Two recent project events motivated writing this:

1. **SRE Track 2I research note** (2026-04-30) framed cells as elements of FL_V(X) — relatively free lattices in variety V. The variety V *is* the algebraic property cluster. Identifying V tells us which canonical-form algorithm applies.
2. **SRE Track 2I Phase 3c** (commit `d4e8c811`, 2026-04-30) surfaced an algebraic-status flip: the type lattice under equality merge changed from "not distributive" (Track 2G finding) to "distributive" (Phase 3c discovery, after the always-installed callback was retired). The flip was real — Track 2H's union-aware merge had restored distributivity, but the callback was hiding it. **This kind of flip changes what propagator kinds and optimizations are available, and the project benefits from a clear map of what each level of the hierarchy unlocks.**

---

## 2. The hierarchy

Lattices form a hierarchy by which equations they satisfy. Each step *adds* axioms, which means: more algorithms become available (the structure is more constrained, decision procedures get cheaper) but *fewer lattices live there* (the equations restrict the model class).

```
Free lattice (FL)
    ⊃ SD (semidistributive)
        ⊃ Modular
            ⊃ Distributive
                ⊃ Heyting (distributive + relative pseudo-complement)
                    ⊃ Boolean (Heyting + complement)
```

Plus orthogonal enrichments that compose with any of these:
- **Quantale** (multiplicative monoid distributing over joins) — for resource constraints
- **Residuated lattice** (left/right adjoints to multiplication) — for automatic backward propagation
- **Algebraic / continuous** — for limit cases (see [WIDENING_NARROWING note](2026-04-30_WIDENING_NARROWING_INFINITE_DOMAINS_FOR_UCS.md))

Each level deserves its own row. What follows is not exhaustive lattice theory; it's the **operational catalog of "if your domain lives at level X, you can do Y."**

---

## 3. What each level gives you

### 3.1 Free lattice (FL_V(X) where V is just lattice axioms)

**Equations**: only the four lattice axioms — idempotence, commutativity, associativity, absorption.

**What you get**:
- **Whitman's six-case algorithm** (Freese-Nation Theorem 1.11): decision procedure for ≤ on closed terms in FL(X).
- **Canonical form** (Freese-Nation Theorem 1.17): every element has a unique-up-to-commutativity minimal-rank term representative. Equality is decidable via canonical-form structural equality.
- **Semidistributivity** (Theorem 1.21, Jónsson-Kiefer 1962): SD∨ and SD∧ both hold (free lattices are SD even though not distributive).
- **Breadth-4** (Jónsson-Kiefer): finite sublattices of FL(X) have antichain width ≤ 4 — a structural fan-out bound for parallel decomposition.

**What you don't get**:
- No DNF/CNF (distributivity fails — `x ∧ (y ∨ z) ≠ (x ∧ y) ∨ (x ∧ z)` in FL(3)).
- No pseudo-complement, no complement.

**Operational profile for propagators**:
- Cells live in the most non-collapsing case; merge functions enforce only the four axioms.
- Canonical form gives O(can(s) + can(t)) equality once both terms are canonicalized (Freese-Nation Theorem 11.23).
- Propagator dispatch on equal-element lookup is content-hashable: hash on canonical form.

**Where this lives in Prologos**: structural-unification cells on raw constructor trees before quotienting by definitional equality. PUnify's recursive descent (`unify.rkt:268-379`) is structurally isomorphic to Whitman's algorithm operating on the free lattice over our type/term ctors (research note §5.1).

### 3.2 Semidistributive (SD)

**Equations**: lattice axioms + SD∨ ((a ∨ b = a ∨ c) ⇒ a ∨ b = a ∨ (b ∧ c)) + SD∧ (dual).

**What you get** (in addition to FL):
- **Reading-Speyer-Thomas constructive canonical form** (2019, "fundamental theorem of finite SD lattices") — extends Freese-Nation's free-lattice canonical form to all finite SD lattices.
- **Robinson-style most-general unifier exists**: SD is part of why structural unification produces MGUs (most-general unifiers) cleanly.
- **Convex geometries** (Adaricheva-Gorbunov-Tumanov 2003): SD lattices are the algebraic counterpart of convex geometries — useful for combinatorial reasoning over closure systems.

**What you don't get**:
- No DNF (distributivity still fails for many SD lattices, including FL itself).
- No pseudo-complement / complement directly.

**Operational profile**:
- Same as FL operationally; SD is "the tightest distributivity-like property that holds in this wider class." The Reading-Speyer-Thomas algorithm is the practical canonical-form mechanism.
- SD is **the equational shadow of free-lattice canonical form** (Freese-Nation §3 proof of Theorem 1.21): if your lattice's elements can be put in canonical form via Whitman-style minimal rank, SD follows automatically.

**Where this lives in Prologos**:
- All distributive lattices (everything below) are SD by inclusion.
- Free lattices over our ctor registries (pre-quotient) are SD.
- Worth empirically checking other SRE-registered domains (Phase 3 sweep target).

### 3.3 Modular (intermediate)

**Equations**: lattice axioms + modular law (a ≤ c ⇒ a ∨ (b ∧ c) = (a ∨ b) ∧ c).

**What you get**:
- **Dedekind / Freese canonical form** for modular lattices (more complex than distributive; Freese 1989).
- **Subgroup-lattice-style structure**: every group's subgroup lattice is modular. Useful when modeling algebraic structures with substructure relations.
- **Jordan-Hölder theorem** has a lattice-theoretic abstraction (chains of equal length under refinement).

**What you don't get**:
- Still not distributive in general (the diamond M₃ is modular non-distributive).
- No pseudo-complement / complement directly.

**Operational profile for propagators**:
- Canonical-form algorithms exist but are heavier. Less practically attractive than going straight to distributive when possible.
- Useful as a *characterization* of certain natural lattices (subgroup, congruence) more than as a target for propagator design.

**Where this lives in Prologos**:
- Not a daily concern — most of our cells are either way more constrained (distributive or above) or way less (free/SD on raw structures).
- Could be relevant if we ever model substructure/congruence lattices for algebraic-data-type analysis.

### 3.4 Distributive

**Equations**: modular + distributive law (a ∧ (b ∨ c) = (a ∧ b) ∨ (a ∧ c)). The two distributive laws (∧/∨ and ∨/∧) are equivalent in lattices — having one gives the other.

**What you get**:
- **Birkhoff representation** (1933, finite case): every finite distributive lattice is isomorphic to the lattice of order-ideals of its poset of join-irreducibles. **Distributive lattices are essentially set lattices.** This is enormous.
- **DNF / CNF canonical form**: every element has a canonical disjunctive (or conjunctive) normal form. Decidable equality via structural equality on canonical forms.
- **Stone duality** (1936, generalized to distributive lattices): finite distributive lattices ↔ finite posets, structure-preserving in both directions.
- **Variable elimination / quantifier elimination patterns** work cleanly. Substitution preserves the algebraic structure.
- **Galois connection composition is well-behaved**: cross-domain bridges between two distributive lattices compose without subtle pathologies.

**Operational profile for propagators**:
- Cells over distributive lattices admit structural-set semantics. CHAMP-shareable canonical forms enable hash-cons-like equality checking.
- Set-union merge is the prototypical distributive-lattice merge; works for capability sets, type unions, multi-fact accumulation.
- DNF canonicalization integrates cleanly with propagator-network quiescence (canonicalize at merge time, equality check is structural).

**Where this lives in Prologos**:
- Set cells (`infra-cell.rkt:46`): `merge-set-union` over the powerset is *Boolean* (distributive + complement), hence distributive.
- Form cells (`form-cells.rkt:503`): declared distributive, has-pseudo-complement → Heyting (Track 2H).
- **Type lattice under equality merge** (Phase 3c discovery): post-Track-2H + flat meet, distributive on the test sample. **This is the new finding being validated by Phase 3 sweep.**
- Type lattice under subtype merge: declared distributive (Track 2H Heyting redesign).

**The Heyting / Boolean step is small from here** — distributive + pseudo-complement = Heyting; + complement = Boolean. Most of the practical capability comes from getting to distributive. The further axioms unlock specific further optimizations (intuitionistic error reporting, SAT-style solving).

### 3.5 Heyting

**Equations**: distributive + relative pseudo-complement (for every a, b, the set {x | x ∧ a ≤ b} has a maximum, written a → b).

**What you get** (in addition to distributive):
- **Pseudo-complement-based error reporting**: "expected T₁, got T₂" can compute the precise type-incompatibility witness via T₂ → T₁ (or its dual). Track 2H's `type-pseudo-complement` exemplifies this.
- **Intuitionistic logic semantics**: Heyting algebras are the algebraic counterpart of intuitionistic propositional logic. Useful for "proof-relevant" reasoning where existence ≠ classical existence.
- **Bidirectional propagation patterns**: pseudo-complement gives a backward-flow operator that's the right shape for "what would T have to be for this constraint to hold?"

**Operational profile for propagators**:
- Heyting domains support precise-incompatibility queries: when a propagator constraint fails, the Heyting algebra computes exactly *which* part of the lattice is incompatible.
- Pseudo-complement propagators (forward) + bidirectional dispatch (backward) become available.

**Where this lives in Prologos**:
- Type lattice under subtype merge (Track 2H, declared Heyting via `'has-pseudo-complement prop-confirmed`).
- Form cells equality merge (declared Heyting).
- **Phase 3 sweep would validate whether type×equality also reaches Heyting** — distributive is confirmed; needs has-pseudo-complement check too.

### 3.6 Boolean

**Equations**: Heyting + complement (every element has a complement; pseudo-complement coincides with classical complement).

**What you get** (in addition to Heyting):
- **SAT solving**: the lattice is a Boolean algebra; SAT/CDCL with watched literals, conflict-driven learning, etc., applies. UCS Master flags this as the dispatch target for Boolean domains.
- **Stone duality (full form)**: Boolean algebras ↔ Stone spaces (totally disconnected compact Hausdorff). The algebra-topology correspondence enables certain meta-theoretic moves.
- **Classical excluded middle**: a ∨ ¬a = ⊤ for all a. Useful when the domain genuinely has a complement (set algebras: complement is set difference from universe).

**Operational profile for propagators**:
- Boolean cells get SAT-machine dispatch. Watched-literals can replace generic merge-fixpoint for boolean-shaped constraints.
- ATMS (Assumption-based Truth Maintenance) is naturally a Boolean-algebra construction over assumption sets — already on-network in BSP-LE Track 2.

**Where this lives in Prologos**:
- ATMS worldview space (BSP-LE Track 2): explicit Boolean lattice (powerset of assumptions). Hypercube structure exploited per `HYPERCUBE_BSP_LE_DESIGN_ADDENDUM`.
- Capability sets with closed-world complement (less common; capability sets typically lack a meaningful complement and stay at distributive/Heyting).
- Form cells: declared has-complement = REFUTED — explicitly Heyting-not-Boolean.
- Type lattice: not Boolean (no meaningful complement of arbitrary types in an open-world type universe).

### 3.7 Orthogonal enrichments

These compose with the hierarchy above; a lattice can be (e.g.) "distributive quantale" or "Heyting residuated lattice."

#### Quantale

A complete lattice with associative multiplication that distributes over arbitrary joins (Mulvey 1986, Rosenthal 1990).

**What you get**:
- Resource-aware composition: multiplicative structure for QTT multiplicities, session linearity, effect ordering.
- Tropical / weighted reasoning: tropical quantales enable shortest-path and cost-bounded reasoning natively.
- Probabilistic propagators: probability semirings as quantales enable weighted constraint propagation (DistCell, BEYOND_PROLOG §6).

**Where this lives in Prologos**:
- Multiplicity cells (m0, m1, mw): a small quantale (3 elements, multiplication = mult composition).
- Session lattice (post-Track 2H tensor): quantale-leaning.
- DistCell research direction (probability/weight semirings): future.

#### Residuated lattice

A lattice with multiplication ⊗ that has both left and right adjoints (residuals): a ⊗ b ≤ c iff b ≤ a \ c iff a ≤ c / b.

**What you get**:
- **Automatic backward propagation**: from a forward propagator computing a ⊗ b, residuation gives the backward propagators "given the result and one input, what was the other input?" UCS Master flags this as the dispatch target for residuated domains.
- **Implication-as-residual**: in Heyting, the implication a → b is the residual of meet — gives the algebraic foundation for the pseudo-complement story.

**Where this lives in Prologos**:
- Heyting algebras are residuated (the implication is the residual of meet).
- Quantale + residuation = Linear Logic semantics — relevant to QTT.
- PTF Track 1 mentioned residuation as a propagator-kind enabler.

---

## 4. The distributivity-status flip — a worked example

The SRE Track 2I Phase 3c discovery (commit `d4e8c811`) is a useful concrete illustration of why the hierarchy posture matters in practice. Three distinct points in time:

**Track 2G (2026-03-30)**: discovered "type lattice not distributive under equality merge."
- *State of the world*: equality merge produced `type-top` for distinct atoms (flat M3-shaped lattice with three incomparable atoms above a shared top and bot).
- *Algebraic posture*: not even distributive. Heyting and Boolean foreclosed.
- *Implication*: pseudo-complement-based error reporting unavailable for equality contexts; SAT-style dispatch unavailable; Reading-Speyer-Thomas SD canonical form might apply but not investigated.

**Track 2H + PPN 4C T-3 Commit B (2026-04-22)**: changed equality merge to produce union types for incompatible atoms.
- *State of the world*: equality merge now produces `(expr-union Int Nat)` instead of `type-top` for incompatible atoms. The union type IS the join. Plus Track 2H made the meet distribute over unions explicitly (via the union-distribute branch in `type-lattice-meet`).
- *Algebraic posture*: distributive by construction. Heyting (with pseudo-complement) by Track 2H scaffolding.
- *Implication*: should have unlocked Heyting capabilities for equality contexts. But the always-installed `current-lattice-subtype-fn` callback was making the meet *subtype-aware regardless of which join was being checked*, causing mixed semantics that broke distributivity in measurements. The actual algebraic posture was hidden.

**Phase 3c (2026-04-30)**: retired the callback in favor of per-relation `meet-registry`.
- *State of the world*: meet's behavior is now per-relation. Equality relation gets flat meet; subtype relation gets subtype-aware meet via explicit `#:subtype-fn` keyword.
- *Algebraic posture surfaces*: equality lattice IS distributive (216/216 triples confirmed on test samples). Track 2G's "not distributive" finding was correct then; Track 2H's redesign restored distributivity; the callback hid that restoration; Phase 3c surfaces the truth.

**The lesson generalizes**:
- An algebraic posture is **a property of the lattice's actual semantics under principled dispatch**, not a property "as observed under whatever scaffolding is currently in place."
- Off-network state injection (callbacks, parameters, defensive guards) can hide the true algebraic posture by mixing semantics across what should be separate concerns. Surface findings can change as scaffolding gets retired.
- Track-by-track discipline: when a track changes core merge/meet semantics, the algebraic-property declarations should be re-validated, not just inherited from prior status. **A merge-changing track is implicitly a property-status-changing track.** Worth codifying as a Stage 2 audit obligation: "if this track changes a merge or meet function, re-run the property inference on the affected domain at Stage 4 close."

---

## 5. Implications for Prologos's propagator network

### 5.1 Per-domain algebraic-class declarations are load-bearing

The SRE Track 2G Algebraic Domain Awareness work established the framework: each `sre-domain` declares its algebraic properties (distributive, has-meet, has-pseudo-complement, etc.). Phase 1 of Track 2I extended this with SD checks; Phase 3c added per-relation meet-registry; the broader vision (UCS Master) is that these declarations drive solver dispatch.

The hierarchy in §3 maps directly onto this. Each declaration is a *commitment to an algebraic level*, and that level *unlocks specific propagator-kind optimizations*:

| Level | Unlocks (propagator-side) |
|---|---|
| SD | Canonical-form-based equality check; structural-unification MGU correctness |
| Distributive | DNF canonicalization; set-algebra-shaped optimizations; clean Galois bridge composition |
| Heyting | Pseudo-complement propagators (precise-incompatibility error reporting); intuitionistic backward dispatch |
| Boolean | SAT/CDCL; watched-literals; ATMS-shaped reasoning; Stone duality moves |
| + Quantale | Resource-aware merge; tropical / probability semirings; multiplicative composition |
| + Residuated | Automatic backward propagator derivation; implication-as-residual |

### 5.2 Propagator-kind dispatch by algebraic level

PTF's [Propagator Taxonomy](2026-03-28_PROPAGATOR_TAXONOMY.md) identifies 5 propagator kinds (Map, Reduce, Broadcast, Scatter, Gather). The algebraic level of the cell domain *constrains and enriches* which kinds are well-defined:

- **Map** (monotone endomorphism): requires the merge to be monotone — works at any level (lattice axioms suffice).
- **Reduce** (n-ary fold to single value): requires associativity + commutativity — works at any level.
- **Broadcast**: requires the lattice to have a join — works at any level.
- **Scatter** (decompose into components): meaningful when the lattice has a structural decomposition (typically distributive or above; SRE's structural domains).
- **Gather** (recompose components): same as Scatter.

Beyond the 5 kinds, *distributive* unlocks:
- **DNF-rewrite propagators**: canonicalize during merge.
- **Subset-membership propagators**: efficient lookup via Birkhoff representation.

*Heyting* unlocks:
- **Pseudo-complement propagators**: produce precise-incompatibility witnesses.
- **Backward-implication propagators** (proto-residuation).

*Boolean* unlocks:
- **SAT-style propagators**: watched literals, conflict-driven learning.
- **Hypercube-traversal propagators**: BSP-LE Track 2's hypercube primitives (Gray code, subcube pruning, all-reduce).

*Quantale* unlocks:
- **Tensor propagators**: cost / probability / linearity composition.
- **Tropical-merge propagators**: shortest-path-style accumulation.

*Residuated* unlocks:
- **Backward-derived propagators**: from any forward propagator, automatically derive the backward dispatch.

### 5.3 The Hyperlattice Conjecture restated per algebraic level

The Hyperlattice Conjecture (`structural-thinking.md`):

> Every computable function is expressible as a fixpoint computation on lattices. The Hasse diagram of the lattice IS the optimal parallel decomposition of that computation.

Combined with the hierarchy, this becomes a *graded* claim:

- For **Boolean** lattices: optimal parallel decomposition is the hypercube algorithm (Gray code, subcube pruning, hypercube all-reduce). Already exploited for ATMS in BSP-LE Track 2.
- For **distributive** lattices: optimal parallel decomposition is via Birkhoff's poset-of-join-irreducibles representation. Sub-poset-parallel computation by component.
- For **Heyting** lattices: distributive optimization + pseudo-complement-based pruning. Failure paths short-circuit via incompatibility computation.
- For **SD** lattices: Reading-Speyer-Thomas canonical form structure; parallel decomposition along canonical joinands.
- For **free** lattices: Whitman-algorithm structure; parallel decomposition along the recursion tree.

Each level **inherits the parallel decomposition of more-specialized levels** when applicable. The Hyperlattice Conjecture is a statement about the optimal-decomposition mapping; the hierarchy tells us which optimization variants apply at each level.

### 5.4 Cross-domain bridge composition

Galois bridges between domains (SRE Lattice Lens question 3) compose well when both sides are *the same algebraic level* or when one is *more specialized than the other*.

Concrete pattern:
- Boolean → Boolean: Galois adjunction is well-behaved (e.g., the worldview cache projection in BSP-LE Track 2).
- Distributive → Distributive: composition is associative; bridge chains can be optimized into single bridges.
- Heyting → Distributive (downward): the Heyting structure projects to the distributive level cleanly.
- Distributive → Heyting (upward): requires the upward map to *preserve pseudo-complement*; not automatic. Bridge needs to be a *Heyting morphism*, not just a lattice morphism.

When designing cross-domain bridges (e.g., type ↔ session, type ↔ multiplicity), the algebraic level of each side determines what bridge laws need to hold. A bridge from a quantale (session with tensor) to a distributive lattice (type without tensor) won't preserve the multiplicative structure.

This connects to the [Algebraic Embeddings note](2026-03-28_ALGEBRAIC_EMBEDDINGS_LATTICES.md): "the algebraic structure of the lattice is a type-level property that constrains and enriches the propagator kinds." Cross-domain bridges inherit constraints from both sides.

---

## 6. Connection to other research lines

### 6.1 SRE Track 2G/2H — algebraic-property registry

The hierarchy IS the framework Track 2G+2H were building toward: per-domain declarations of algebraic properties drive propagator-kind dispatch. Phase 3c's per-relation `meet-registry` extension fits naturally.

What's missing today (from the hierarchy perspective):
- No `:variety` declaration (Track 2G has individual properties; the variety is implicit in the equation cluster).
- No automatic implication chain from low-level properties to high-level varieties (Phase 1's `distributive ⇒ sd-vee` is a step in this direction; would generalize to `distributive + has-pseudo-complement ⇒ heyting` already done, but lower-level synthesis like `commutative + associative + idempotent + has-meet ⇒ bounded-lattice` not done).
- No per-level optimization dispatch infrastructure (UCS targets this; PTF should specify it).

### 6.2 UCS — Universal Constraint Solving

UCS Master's vision: domain-polymorphic `#=` dispatched by algebraic class. The hierarchy IS the dispatch axis:

```
#= dispatch table (UCS):
  Boolean      → SAT/CDCL (watched literals, conflict learning)
  Heyting      → intuitionistic constraint solving (pseudo-complement)
  Residuated   → backward propagation (automatic residual computation)
  Quantale     → resource-aware solving (multiplicative)
  Distributive → join/meet propagation (efficient via DNF)
  SD           → structural unification (Robinson/MGU via SD)
  Free         → Whitman six-case algorithm (with memoization)
```

This is the operational table the hierarchy makes precise. Each level has an associated dispatch strategy. UCS's value is *making this mechanical*.

### 6.3 NTT — Network Type Theory

NTT's `:lattice` declaration on cells should accept variety-level annotations:

```
(cell :type Type :lattice :heyting ...)
(cell :type Mult :lattice :quantale ...)
(cell :type Constraint :lattice :boolean ...)
```

The hierarchy provides the vocabulary. NTT's typechecker can then verify that propagators on a cell are compatible with the cell's algebraic level (e.g., a SAT propagator on a non-Boolean cell is a type error).

### 6.4 Free Lattices research note (companion)

The companion research note ([2026-04-30_LATTICE_VARIETY_AND_CANONICAL_FORM_FOR_SRE.md](2026-04-30_LATTICE_VARIETY_AND_CANONICAL_FORM_FOR_SRE.md)) makes the variety-relative free-lattice argument: cells are FL_V(X) where V is the variety. The hierarchy is the catalog of which V's matter and what their canonical-form theory gives.

This note is the "what each level gives" framing; that one is the "how to identify which V applies" framing. They're complementary.

### 6.5 PPN 4C T-3 Commit B (the union-merge change)

The PPN 4C T-3 Commit B (2026-04-22) framing was: "type-top is reserved for REAL contradictions, not the absence of structural unification." The algebraic implication wasn't called out at the time, but it was:

> Changing the equality merge from "incompatible-atoms-go-to-top" to "incompatible-atoms-go-to-union" is a **lattice-structure change** that affects which algebraic level the lattice lives at. The flat-with-shared-top lattice (M3 in part) is not distributive. The union-aware lattice IS distributive (per Phase 3c discovery).

A discipline that would have caught this earlier: **whenever a track changes a merge or meet function, the algebraic-property declarations should be re-validated.** This is a Phase 3c/Stage-2-audit-obligation candidate worth codifying.

---

## 7. Open questions

These are research observations, not design proposals.

1. **Where does each SRE-registered domain sit in the hierarchy?** Phase 3 sweep will produce empirical findings table; the hierarchy provides the answer-space.
2. **Can we automate variety detection?** The Algebraic Embeddings note's §3.3 proposes "Automatic structure detection on user-defined lattices" — given Lattice + Meet + Top + Bottom traits, sample-test for distributive / Boolean / Heyting / Residuated / Geometric. The hierarchy IS the answer-space for that detection.
3. **What's the right type-system encoding of algebraic level?** NTT could promote algebraic level to a kind: `DistributiveLattice <: Lattice`, `HeytingAlgebra <: DistributiveLattice`, `BooleanAlgebra <: HeytingAlgebra`. Then propagator types specify their domain's required level.
4. **How does the hierarchy interact with continuity?** A continuous distributive lattice (Scott domain) gives different optimization opportunities than a non-continuous one. Companion widening/narrowing note covers this.
5. **Is there a propagator-kind taxonomy refinement per algebraic level?** PTF Track 0's 5 kinds (Map, Reduce, Broadcast, Scatter, Gather) are level-agnostic. A more refined taxonomy might be: kinds × levels, with each cell unlocking specific (kind, level) combinations.
6. **The "track-changes-merge implies re-validate" discipline** — should this be codified as a workflow rule? Pattern observed at Phase 3c (post-PPN 4C T-3 Commit B's merge change, the algebraic posture flipped but wasn't re-measured until 8 days later). 1 data point so far; codify when more accumulate.

---

## 8. References

### Primary
- Freese, R., Ježek, J., Nation, J. B. (1995). *Free Lattices.* AMS Mathematical Surveys and Monographs 42.
- Birkhoff, G. (1933, 1967). Lattice theory representation theorems.
- Stone, M. H. (1936). Stone duality.
- Reading, N., Speyer, D., Thomas, H. (2019). The fundamental theorem of finite semidistributive lattices.
- Mulvey, C. J. (1986). Quantales (introducing the structure).
- Rosenthal, K. I. (1990). *Quantales and Their Applications.* Longman Scientific.
- Adaricheva, K., Gorbunov, V. A., Tumanov, V. I. (2003). Convex geometries and SD lattices.

### Prologos artifacts referenced
- [PTF Master](../tracking/2026-03-28_PTF_MASTER.md) — series home
- [Propagator Taxonomy — Parallel Profiles](2026-03-28_PROPAGATOR_TAXONOMY.md) — PTF Track 0
- [Algebraic Embeddings on Lattices](2026-03-28_ALGEBRAIC_EMBEDDINGS_LATTICES.md) — PTF's existing piece on this; this note extends
- [Lattice Variety and Canonical Form for SRE](2026-04-30_LATTICE_VARIETY_AND_CANONICAL_FORM_FOR_SRE.md) — companion (element-level theory)
- [Widening, Narrowing, and Continuity for UCS](2026-04-30_WIDENING_NARROWING_INFINITE_DOMAINS_FOR_UCS.md) — companion (limit-level theory)
- [SRE Track 2G Design](../tracking/2026-03-30_SRE_TRACK2G_DESIGN.md), [PIR](../tracking/2026-03-30_SRE_TRACK2G_PIR.md) — algebraic-property registry
- [SRE Track 2H Design](../tracking/2026-04-02_SRE_TRACK2H_DESIGN.md), [PIR](../tracking/2026-04-03_SRE_TRACK2H_PIR.md) — type lattice Heyting redesign
- [SRE Track 2I Design](../tracking/2026-04-30_SRE_TRACK2I_SD_CHECKS_DESIGN.md) — SD checks + Phase 3c per-relation meet-registry (this note's motivating discovery)
- [UCS Master](../tracking/2026-03-28_UCS_MASTER.md) — universal constraint solving by algebraic class
- [PPN 4C T-3 Commit B](../tracking/2026-04-21_PPN_4C_PHASE_9_DESIGN.md) — the merge change that unwittingly flipped distributivity
- [`structural-thinking.md`](../../.claude/rules/structural-thinking.md) — Hyperlattice Conjecture; SRE Lattice Lens

### One-line summary

The lattice hierarchy from free at the top to Boolean at the bottom is a precise framework: each algebraic level *adds equations* (constraining the model class) and *unlocks specific propagator-kind capabilities and optimizations* — distributive enables DNF and Birkhoff representation, Heyting enables pseudo-complement-based error reporting, Boolean enables SAT/CDCL, plus orthogonal enrichments (quantale for resources, residuation for backward propagation). Identifying which level each Prologos cell domain lives at is the per-domain commitment that drives propagator-kind dispatch (UCS's vision) and validates which optimizations apply (PTF's design space). The SRE Track 2I Phase 3c bonus discovery — that the type lattice's distributivity status flipped from "refuted" (Track 2G) to "confirmed" (Phase 3c) under principled per-relation dispatch — is a worked example of why getting the hierarchy posture *right* matters: defensive scaffolding can hide the true algebraic posture, and the propagator-kind capabilities that follow from each level depend on getting the posture correct, not on whatever the scaffolding accidentally enables.
