# Lattice Variety and Canonical Form: A Free-Lattice Lens on SRE

**Date**: 2026-04-30
**Stage**: 0/1 (deep research, vocabulary, theory grounding — not design)
**Series**: SRE (Structural Reasoning Engine)
**Status**: Research synthesis — no design commitments
**Author**: Claude (research synthesis from dialogue)

**Reading order**: This note is a Stage 0/1 artifact per [DESIGN_METHODOLOGY.org](../tracking/principles/DESIGN_METHODOLOGY.org) § Stage 1. Companion artifact: [2026-04-30_WIDENING_NARROWING_INFINITE_DOMAINS_FOR_UCS.md](2026-04-30_WIDENING_NARROWING_INFINITE_DOMAINS_FOR_UCS.md) covers the limit-case half of the picture (continuity, widening/narrowing). Read both together; they are complements.

**Source companion**: [Free Lattices Companion · Chapter I](../learning/freelat-companion-ch01.html), supplementing Freese, Ježek & Nation, *Free Lattices*, AMS Surveys 42 (1995). Anchor reading is Chapter I §3 (canonical form, Theorems 1.15–1.21) and §2 (Whitman's algorithm, Theorem 1.11).

---

## 0. Errata / prior-art corrections (added post-mempalace cross-check)

A mempalace semantic search on this note's topic surfaced load-bearing prior art my direct codebase grep missed. Four substantive corrections to the framing below — each tightens what's *new* in this note and what's already-committed prior work I should have cited rather than re-derived:

1. **The canonical-form ↔ Prologos-IR connection was already drawn in the Free Lattices companion.** [`freelat-companion-ch01.html`](../learning/freelat-companion-ch01.html) contains a "Prologos" callout box stating: *"Theorem 1.17's canonical form idea — minimum-length term, unique up to commutativity — is structurally equivalent to Prologos's compiler IR design. Each AST node has a normal-form (`nf`) case in `reduction.rkt`; reduction is confluent under definitional equality; the canonical form of a typed expression is the term Prologos uses for hash-consing, equality testing, and propagator-cell content. Whitman's word-problem algorithm and Prologos's WHNF-then-equality decision procedure share the same structural logic: recursive structural reduction terminating at irreducible leaves."* The companion already drew the lineage. The §5.1 PUnify ↔ Whitman correspondence I claimed as a research observation is *more specific* than the companion's framing (β/δ/ι reduction vs lattice-axiom reduction is the disambiguation §5.1 adds), but the foundational connection is already in our learning materials. Cite, don't re-derive.

2. **The variety-detection plan was already drafted.** [`docs/research/2026-03-28_ALGEBRAIC_EMBEDDINGS_LATTICES.md`](2026-03-28_ALGEBRAIC_EMBEDDINGS_LATTICES.md) §3.3 *Long-Term* contains an explicit "Automatic structure detection on user-defined lattices" plan with concrete tests for Distributive, Boolean, Heyting, Residuated, and Geometric properties. It also proposes a "Type system for lattices" with `DistributiveLattice`, `BooleanAlgebra`, `HeytingAlgebra`, `Quantale`, `GeometricLattice` kinds inferred from trait instances. And it proposes "Automatic Galois bridge derivation from algebraic properties." This note's §3 framing of "identify variety V per domain" is consistent with that prior plan; the *additional* contribution here is the free-lattice-quotient structural argument (cells are FL_V(X) elements, not absolutely-free elements) and the canonical-form theorems that follow from V-identification. Cross-reference the prior plan rather than presenting variety identification as a new direction.

3. **The "type lattice is not actually a lattice under subtype merge" diagnosis is already committed.** The [SRE Track 2H Stage 2 audit](../tracking/2026-04-02_SRE_TRACK2H_STAGE2_AUDIT.md) and [Track 2H design](../tracking/2026-04-02_SRE_TRACK2H_DESIGN.md) explicitly diagnose: *"the subtype ordering has a well-defined join for chains (Nat ⊔ Int = Int) but no join for incomparable types. A lattice requires joins for ALL pairs — this is not a lattice but a forest of chains under a common top."* They also note `build-union-type` does ACI normalization (associative-commutative-idempotent) — *that's canonical form already*, by another name. And the Track 2H Stage 2 audit explicitly notes `type-sre-domain-for-subtype` has `(hasheq)` for declared-properties — i.e., no algebraic properties declared for the subtype-merge domain. **§4 of this note's audit table mis-stated `union-types.rkt:124-131` as the canonicalization site; the actual canonical-form-bearing function is `build-union-type` at [`unify.rkt:843`](../../racket/prologos/unify.rkt), and it explicitly performs ACI normalization.** Cross-reference Track 2H rather than positioning this as new finding.

4. **The Freese-Nation algorithmic capstone (Ch XI) carries the complexity bounds.** mempalace surfaced [`freelat-companion-ch11.html`](../learning/freelat-companion-ch11.html) and the process notes' framing: *"the chapter is the monograph's algorithmic capstone. Every preceding chapter's structural theorem becomes an algorithmic specification: Whitman's condition becomes pseudocode, canonical form becomes a recursion, κ-bijection becomes a dependency table."* Specifically: Listing 11.12 (Whitman with selective memoization), Lemma 11.36 (at most twice-accessed nodes → O(1) minimum), Theorem 11.23 (O(can(s) + can(t)) on canonical input). This note's §5.1 PUnify-Whitman audit task should explicitly target Ch XI's algorithm (with memoization and the canonical-input fast path) rather than Ch I's basic six-case recursion — the practical implementation reference is Ch XI, not Ch I.

The §8 implementation note for SRE Master stands but with two adjustments: (a) Phase 1 (empirical V determination) should harvest the Track 2H Stage 2 audit's existing diagnosis as input; (b) Phase 2 (canonical-form algorithm) should target Ch XI's complexity bounds and memoization structure, not Ch I's bare algorithm.

Origin: cross-check via `mempalace_search` queries on 2026-04-30, after initial draft. Same staleness mode as Note B's errata: my draft was stale relative to the codebase + committed research, in ways that keyword grep missed because the prior art uses different vocabulary (this note: "canonical form"; prior art: also "ACI normalization", "WHNF", "definitional equality", "build-union-type", "auto-detect algebraic structure"). Per [`mempalace.md`](../../.claude/rules/mempalace.md) cross-check discipline.

---

## 1. Why this note exists

Two threads in our existing work converge on the same gap.

**Thread A: SRE Track 2G/2H finding.** Track 2G's algebraic-property registry discovered that "the type lattice [is] NOT distributive under equality merge — type lattice redesign needed for Heyting" ([SRE_MASTER §Track 2G notes](../tracking/2026-03-22_SRE_MASTER.md)). Track 2H delivered a Heyting redesign with union join, complete meet, tensor, and pseudo-complement scaffolding ([Track 2H PIR](../tracking/2026-04-03_SRE_TRACK2H_PIR.md)). What Track 2G did not do — because the vocabulary did not exist yet in our infrastructure — was name *which lattice variety V* the redesigned type lattice now lives in. We declared properties (Heyting, distributivity per relation) but not the variety, and we have no canonical-form algorithm derived from that variety.

**Thread B: Hyperlattice Conjecture optimality claim.** [`structural-thinking.md`](../../.claude/rules/structural-thinking.md) §1 states: "the Hasse diagram of the lattice IS the optimal parallel decomposition of that computation." Today the evidence for this claim is *one* worked example — the ATMS worldview space being Q_n with hypercube Hasse ([HYPERCUBE_BSP_LE_DESIGN_ADDENDUM](2026-04-08_HYPERCUBE_BSP_LE_DESIGN_ADDENDUM.md)). Boolean is the easy case. The conjecture asserts something across *all* lattices we work with. The gap between "asserted across all" and "evidenced for one" is a place we want to keep closing.

This note frames a research direction that addresses both: **identify the lattice variety V each SRE domain lives in, and use the canonical-form theory of FL_V(X) — the relatively free lattice in V — to give the Hyperlattice optimality claim a per-variety algebraic backbone.**

The note is Stage 0/1: vocabulary, theory grounding, system survey, gap identification, and an implementation-note-shape recommendation for the SRE Master. It does NOT propose a design. A Stage 3 design track would follow from this if we elect to pursue it; that decision is downstream.

---

## 2. Free lattices: the vocabulary

### 2.1 Definition

A *free lattice* on a set X, written **FL**(X), is the lattice freely generated by X. Concretely (Freese-Nation Ch I §2):

- T(X) = the absolutely free term algebra on X under join (∨) and meet (∧) — the set of all syntactic lattice terms.
- ∼ = the equivalence on T(X) defined by s ∼ t iff the equation s ≈ t holds in *every* lattice.
- **FL**(X) = T(X)/∼.

Each element of **FL**(X) is an equivalence class of terms; any term in the class *represents* the element. The defining universal property: every map from X into any lattice L extends uniquely to a lattice homomorphism **FL**(X) → L. **FL**(X) is unique up to isomorphism.

The only equations holding in **FL**(X) are those forced by the four lattice axioms:
1. Idempotence: x ∨ x = x, x ∧ x = x.
2. Commutativity: x ∨ y = y ∨ x, x ∧ y = y ∧ x.
3. Associativity: x ∨ (y ∨ z) = (x ∨ y) ∨ z, dual.
4. Absorption: x ∨ (x ∧ y) = x, x ∧ (x ∨ y) = x.

In particular, distributivity does **not** hold in **FL**(X) for |X| ≥ 3: the terms x ∧ (y ∨ z) and (x ∧ y) ∨ (x ∧ z) are *different* elements of **FL**(3).

### 2.2 The word problem and Whitman's algorithm

The *word problem*: given two terms s, t ∈ T(X), decide whether s ∼ t. Whitman 1941 gave a recursive decision procedure (Freese-Nation Theorem 1.11):

> If s, t are terms in variables x₁, …, xₙ ∈ X, then s ≤ t holds in **FL**(X) iff one of six recursive cases applies.

The six cases recurse on the structure of s and t; the non-trivial case — *Whitman's condition (W)* — covers v₁ ∧ ⋯ ∧ vᵣ ≤ u₁ ∨ ⋯ ∨ uₛ, which has only four trivial reasons (some vᵢ ≤ uⱼ, or s ≤ uⱼ for some j, or vᵢ ≤ t for some i, or X-overlap). The algorithm decides ≤; equality is two ≤ tests.

### 2.3 Canonical form (Theorem 1.17)

> **Theorem 1.17 (Freese-Nation).** For each w ∈ **FL**(X), there is a term of minimal rank representing w, unique up to commutativity. This term is the *canonical form* of w.

(Rank here is term length under flat n-ary form: x ∨ y ∨ z has rank 4, while (x ∨ y) ∨ z has rank 5. So canonical form is unique up to permutation of joinands/meetands at each level.)

**Theorem 1.18 (4-condition characterization).** A term t = t₁ ∨ ⋯ ∨ tₙ with n > 1 is in canonical form iff:
1. Each tᵢ is either in X or formally a meet (no nested joins).
2. Each tᵢ is itself in canonical form (recursive).
3. Joinands form an antichain: tᵢ ≰ tⱼ for i ≠ j.
4. If tᵢ = ⋀ tᵢⱼ, then no tᵢⱼ ≤ t.

(Dual conditions for canonical-form meets; x ∈ X is always in canonical form.)

**Theorem 1.19 (uniqueness as minimal join representation).** The canonical join representation is the unique *minimal* representation under the join-refinement quasiorder ≪. Any other way of writing w as a join is ≪-above the canonical one.

### 2.4 Semidistributivity (Theorem 1.21, Jónsson–Kiefer 1962)

A lattice L satisfies SD∨ if w = a ∨ b = a ∨ c implies w = a ∨ (b ∧ c). Dually for SD∧.

> **Theorem 1.21.** Free lattices are semidistributive.

The proof (Freese-Nation §3) is essentially: canonical form gives a unique minimal join representation; semidistributivity is the *equational shadow* of canonical-form structure. Reading-Speyer-Thomas 2019 extends this to a "fundamental theorem of finite SD lattices" — finite SD lattices have constructive canonical forms generalizing the free-lattice case ([Companion ch01 connection P3](../learning/freelat-companion-ch01.html#c3)).

### 2.5 Breadth-4 theorem (Jónsson–Kiefer 1962, Freese-Nation Cor 1.31)

Finite sublattices of free lattices have *breadth* at most 4. Breadth here is a generalized antichain-width: the maximum number of join-irreducibles in any minimal join representation.

This is potentially load-bearing for parallel decomposition: if a cell-dependency graph factors through a free-lattice sublattice, the antichain width at any Hasse level is bounded by 4 — a structural fan-out bound on parallel decomposition.

### 2.6 Continuity and incompleteness

Freese-Nation Theorem 1.22: free lattices are continuous (joins and meets commute with directed limits). Theorems 1.23–1.26: nevertheless, **FL**(3) contains an ascending chain without a least upper bound — a fixed-point-free unary polynomial. So **FL** has limits-of-elements that are not elements. Canonical form is a property of *elements*, not of limits. Limits are the subject of the companion note on widening/narrowing.

---

## 3. Quotients, varieties, and what cells actually are

### 3.1 The universal property in reverse

Any lattice L generated by a set X arises as a quotient of **FL**(X): there is a congruence θ on **FL**(X) such that L ≅ **FL**(X)/θ. The congruence θ encodes the *additional* equations holding in L beyond pure lattice axioms.

This is a structural fact, not a design choice. Some examples:

- **Distributive lattice on X**: θ_dist = the smallest congruence making distributivity hold. **FL**(X)/θ_dist is the *free distributive lattice* on X. For finite X, this is the Dedekind number M(|X|) — finite but very large.
- **Boolean lattice on X**: θ_bool = θ_dist + complementation. **FL**(X)/θ_bool ≅ 2^(2^X) — the powerset of the powerset.
- **Modular lattice**: θ_mod = the congruence making the modular law hold. Modular but not distributive.

### 3.2 Variety: the right level of abstraction

A *variety* V of lattices is a class closed under homomorphic images, sublattices, and direct products (Birkhoff's HSP theorem, 1935). Equivalently, V is defined by a set of equations Σ; V = the class of lattices where every equation in Σ holds. Examples of varieties of lattices:

- Trivial variety: just the one-element lattice.
- Distributive variety D.
- Modular variety M ⊃ D.
- Semidistributive (SD): NOT a variety (SD is not equational), but Reading-Speyer-Thomas analysis treats finite SD lattices in a quasi-variety frame.
- All lattices: the maximal variety.

For each variety V, there is a *relatively free lattice* **FL**_V(X) — the free algebra in V over X. **FL**_V(X) = **FL**(X)/θ_V where θ_V is the congruence enforcing V's equations. The canonical-form theory of **FL**(X) (Whitman, 1.17) generalizes:

- **V = distributive**: canonical form is essentially DNF or CNF; classical, well-known, easy.
- **V = modular**: harder; classical results due to Dedekind, more recent work by Freese.
- **V = semidistributive (finite)**: Reading-Speyer-Thomas 2019 gives a constructive canonical form via the fundamental theorem of finite SD lattices.
- **V = all lattices**: Whitman's algorithm directly.

### 3.3 SRE cells are FL_V(X) elements, not FL(X) elements

The structural fact above implies a design observation: **a cell value, viewed as a lattice element, lives in some FL_V(X) where V is determined by the domain's algebraic identities.** Going to **FL**(X) (the absolutely free case) would *strip* the equations we want — the type lattice's distributive identities, the capability lattice's set-theoretic identities, the session lattice's involutive duality. We would lose canonicalization, not gain it.

The right design target — to be honest, the current design target *implicitly* — is: each SRE-registered domain commits to a variety V, and the canonical-form theory of **FL**_V(X) tells us what canonicalization is *theoretically possible* in that domain.

What's missing in our infrastructure today is the explicit declaration. `sre-domain` has bot/top/merge and a property registry (post-Track 2G); it does NOT have a `:variety` field. Adding one — and making canonical-form algorithms parametric over the variety — is the path this research note flags.

---

## 4. Audit: where canonicalization already lives in Prologos

This is a faithful inventory based on a code survey on 2026-04-30, with status tags IMPLEMENTED / PARTIAL / ABSENT.

| Site | Concept | Variety implicit | Status |
|---|---|---|---|
| [`union-types.rkt:116-131`](../../racket/prologos/union-types.rkt) | Sort-flatten-dedup of union types | Distributive (under union/intersect) | IMPLEMENTED |
| [`reduction.rkt:5-10`](../../racket/prologos/reduction.rkt) | whnf / nf reduction | β/δ/ι reduction (different beast — term computation, not lattice axioms) | IMPLEMENTED |
| [`sre-core.rkt:108-142`](../../racket/prologos/sre-core.rkt) | Domain-parameterized merge registry | Per-relation, no variety declaration | PARTIAL (no canonical form derivation) |
| [`hasse-registry.rkt:56-90`](../../racket/prologos/hasse-registry.rkt) | Subsumption-ordered registration (Module Theory Realization B) | Implicit via subsumption | IMPLEMENTED (one specific registry) |
| [`infra-cell.rkt:46,187`](../../racket/prologos/infra-cell.rkt) | merge-set-union | Boolean (free Boolean lattice on element type) | IMPLEMENTED |
| [`type-lattice.rkt:152-221`](../../racket/prologos/type-lattice.rkt) | type-lattice-merge (post-Track 2H) | Heyting (per Track 2H PIR) | IMPLEMENTED (no canonical-form algorithm) |
| [`unify.rkt:268-379`](../../racket/prologos/unify.rkt) | PUnify decomposition — Pi/Sigma/multi-goal | Variety implicit; structurally Whitman-shaped | IMPLEMENTED |
| Hash-consing of structural values | True structural sharing | — | ABSENT |

**Observations**:

1. We have *ad-hoc* canonicalization in several places, but no unifying lattice-theoretic story. Each site implements canonicalization independently against its own implicit variety.
2. Track 2G's algebraic-property registry is the closest infrastructure to a variety declaration, but it tracks *individual properties* (distributivity, idempotence, semidistributivity-the-property) rather than *the variety* (which is the equational closure of those properties).
3. PUnify's recursive descent (`unify.rkt:268-379`) has the *structural* shape of Whitman's algorithm. Whether it *is* Whitman's algorithm is an audit-level question worth asking explicitly.
4. There is no hash-consing of lattice elements. CHAMP shares term structure incidentally; canonical-form-driven structure sharing on lattice values would be strictly more powerful.

---

## 5. Where canonical form would land if pursued

The following are research observations, not design proposals.

### 5.1 PUnify ↔ Whitman correspondence

PUnify's decomposition (Pi vs Pi → domain ~ domain′ AND codomain ~ codomain′; Sigma vs Sigma → similar) is structurally isomorphic to Whitman's recursion (s = s₁ ∨ s₂ ≤ t → s₁ ≤ t AND s₂ ≤ t). The differences:

- We test equality (≤ ∧ ≥); Whitman tests ≤ (one-directional). Splitting equality into two ≤ tests may give a cleaner story for the subtype relation where ≤ ≠ =.
- Whitman has no metavariable analogue; PUnify has metas. The right reframing — gated on PPN 4 closing per the source dialogue — is *metavar = hole in a lattice context*, with substitution preserving canonicality as a real correctness condition.
- PUnify's "stuck → suspend on propagator" is *not* Whitman's "stuck → fail." Operationally correct given lazy meta resolution; worth verifying that what we wait for is information that could change the (W) verdict, not impossible-to-satisfy constraints.

A specific audit task this enables: catalog PUnify's recursive cases against Whitman's six, identify where they correspond and where they diverge, and classify each divergence as principled (because the domain is in a variety where some Whitman cases collapse) or accidental (we never noticed Whitman was solving the same problem).

### 5.2 Cell equality via canonical hash

Today `(equal? cell-value-1 cell-value-2)` uses Racket structural equality. For lattice-valued cells, the *right* equality is "do they have the same canonical-form representative in their domain's FL_V(X)?" Implementing this for the type-lattice and subtype-lattice would:

- Eliminate a class of "logically equal but structurally distinct" bugs.
- Allow CHAMP to share canonical representatives — a kind of hash-consing on lattice elements rather than on raw terms.
- Make cell-value diffing across BSP rounds detect *actual* refinement rather than incidental representation churn.

Adjacent technology: *e-graphs* and equality saturation ([egg](https://egraphs-good.github.io/), Willsey thesis 2022). E-graphs maintain a canonical representation of equivalence classes via congruence closure with hash-consing. They are a *different* canonicalization mechanism (equality modulo a rewrite system rather than equality in a free lattice quotient), but the engineering pattern — hash-cons + congruence + invariant restoration — is directly relevant. SRE Track 2D's adhesive-DPO foundation is closer to e-graphs than I initially recognized; the canonical-form work would land alongside it.

### 5.3 Optimality from structural conjecture to algebraic theorem

The Hyperlattice Conjecture's optimality claim, restricted to a variety V where canonical form is computable, becomes:

> For any computation expressed as a fixpoint over FL_V(X)-valued cells, the Hasse diagram of FL_V(X) constructed from canonical-form covers determines parallel decomposition with no redundant communication, and Theorem 1.19's "unique minimal representation" guarantees no over-decomposition.

This is a *graded* refinement of the conjecture: per-variety, not universal. The aspirational statement remains; under variety-restricted scope it becomes a theorem we could state and (where the variety has worked-out canonical-form theory) prove.

### 5.4 Semidistributivity as an SRE algebraic-property check

SD∨ and SD∧ are local algebraic conditions (3-element samples), checkable by sample-checking the same way we currently check idempotence and commutativity in `sre-domain` properties. Implication: a small task that does NOT require a track-level redesign — adding SD-property sample-checks to existing SRE merge functions and reporting findings.

This is the smallest concrete near-term move. It's flagged separately for the close-out of the source dialogue.

### 5.5 Breadth-4 as a partitioning bound

Speculative: if a sub-class of our cell dependency graph factors through a free-lattice sublattice (e.g., the structural-unification domain on raw constructor trees, before quotienting by definitional equality), the breadth-4 theorem gives a structural fan-out bound on parallel decomposition at each Hasse level. This is *very* speculative; verifying that any real Prologos cell graph factors this way would require empirical work. Flagged as a research curiosity, not a load-bearing claim.

---

## 6. Adjacent technologies surveyed

Stage 1 requires 3-5 system surveys. Here is the relevant adjacent landscape.

### 6.1 E-graphs and equality saturation

[Willsey thesis 2022](https://www.mwillsey.com/thesis/thesis.pdf), [egg](https://egraphs-good.github.io/), [E-graphs Modulo Theories (EMT, 2024)](https://arxiv.org/html/2504.14340).

- **What**: Data structure representing a congruence-closed set of equivalent expressions. E-classes (equivalence classes) and e-nodes (canonical representatives within each class), with hash-consing maintaining canonicity.
- **Relevance**: Engineering pattern for canonical-form-driven structure sharing. The hash-cons-plus-congruence-plus-rebuilding architecture is directly transferable. Equality saturation is a rewrite-system-driven canonicalization, complementary to free-lattice canonical form.
- **Difference**: E-graphs canonicalize modulo a *rewrite system*, not a *lattice variety*. The two converge if the rewrite system is a complete confluent set of equations defining the variety, but in general they're different mechanisms.
- **Bridge to us**: SRE Track 2D's adhesive-DPO framework is structurally close to e-graphs. Arsac 2025 confirmed e-graphs are adhesive (cited in Track 2D PIR). A unified treatment is plausible.

### 6.2 Reading-Speyer-Thomas finite SD lattice fundamental theorem (2019)

Generalizes free-lattice canonical form to all finite SD lattices via a constructive map from elements to canonical join representations. Most directly relevant if our SRE domains are SD but not free.

### 6.3 Term rewriting normal forms

Standard λ-calculus normal forms (whnf, nf) — what `reduction.rkt` does. These are normal forms with respect to *β/δ/ι reduction* (computation), not with respect to *lattice axioms*. The two are different and shouldn't be conflated; both are relevant for different cells. Whether they should ever interact (e.g., a reduce-then-canonicalize pipeline at the type-lattice merge) is an open design question.

### 6.4 Galois extensions / canonical extensions of lattices

[Dahlqvist-Pym 2024](http://www.cs.ucl.ac.uk/fileadmin/UCL-CS/research/Research_Notes/DahlqvistPym_RN.pdf): canonical extensions of bounded lattices via Galois connections. A different *kind* of canonical form (extension to a complete, completely distributive lattice) more relevant to logic-system completeness theorems than to cell representation, but potentially relevant if the UCS series wants a unified semantic substrate.

### 6.5 Jipsen-Rose, *Varieties of Lattices* (1992, [PDF](https://www1.chapman.edu/~jipsen/Jipsen%20Rose%201992%20Varieties%20of%20Lattices.pdf))

The standard reference on the lattice of lattice varieties. Useful as a map: where does our type lattice's variety sit in the variety lattice? Distributive ⊊ Modular ⊊ … — knowing where we are constrains what canonical-form theory applies.

---

## 7. Open questions

1. **Which variety is the type lattice in, post-Track 2H?** Track 2G found "not distributive under equality merge"; Track 2H made it Heyting (which implies distributive in the bounded-lattice frame). Empirically determining V — by counterexample search across realistic Prologos type values for the candidate equations — is Phase 1 of any future track.

2. **Is the subtype lattice in the same variety as the equality-merge type lattice, or a different one?** Different relations may produce different effective varieties on the same underlying carrier.

3. **Does PUnify's recursive descent compute the same answer as Whitman's algorithm on closed terms?** Empirical question; would benefit from a parity test.

4. **Can semidistributivity (SD∨, SD∧) be sample-checked at the SRE registration site, the way idempotence/commutativity already are?** Yes (small task, flagged in §5.4); the question is whether we've already done it accidentally somewhere or not.

5. **What is the relationship between SRE Track 2D's adhesive-DPO framework and e-graphs?** Arsac 2025 says e-graphs are adhesive; does the SRE Track 2D infrastructure subsume e-graph-style canonicalization, or are they parallel?

6. **Is the breadth-4 bound applicable to any real Prologos cell graph?** Empirical; only worth pursuing if §5.5 turns out to be more than speculation.

---

## 8. Implementation note for SRE Master series

If the project elects to pursue this research direction, the track shape would be roughly:

**Track [TBD]: Lattice Variety Identification + Canonical Form (Type Lattice Pilot)**

- *Phase 0 (Acceptance)*: A `.prologos` acceptance file exercising the type-lattice merge across realistic types — unions, intersections, function types, dependent products, GADT variants. Run before and after each phase.
- *Phase 1 (Empirical V determination)*: For the type lattice as constructed in Track 2H, empirically determine which equations hold by counterexample search. Output: a declaration of the type lattice's variety V, recorded in `sre-domain` via a new `:variety` field.
- *Phase 2 (Canonical-form algorithm)*: Implement the canonical-form algorithm appropriate for V. For distributive: DNF/CNF. For Heyting (which is bounded distributive + relative pseudo-complement): canonical extensions or DNF with pseudo-complement normalization. For SD: Reading-Speyer-Thomas. Provide as a per-domain hook: `sre-domain-canonicalize : sre-domain × element → element`.
- *Phase 3 (Cell-equality wiring)*: Replace structural-equality cell comparison for type cells with canonical-form-based equality. Hash on canonical form. Measure CHAMP sharing improvement.
- *Phase 4 (Retire ad-hoc)*: Retire `union-types.rkt`'s ad-hoc canonicalization in favor of the registered canonical-form algorithm. Verify behavioral equivalence.
- *Phase T (Test track)*: Per the workflow rule "dedicated test phase is MANDATORY," `test-sre-canonical-form.rkt` covering the algorithm, edge cases, and parity with prior canonicalization.

Track gating: **PPN 4 must close first.** The type lattice's interaction with metavariables is the load-bearing concern, and PPN 4 is the work that puts cross-domain meta decorations on-network. Pre-PPN-4 the design has too many implicit boundaries.

Estimated scope: 1-2 weeks of design (Stage 2/3) plus 2-3 weeks of implementation (Stage 4), assuming the V determination in Phase 1 lands in a known variety. Riskiest phase is 2 if V turns out to be exotic (e.g., SD-but-not-modular with specific further constraints).

---

## 9. References

### Primary
- Freese, R., Ježek, J., Nation, J. B. (1995). *Free Lattices.* AMS Mathematical Surveys and Monographs 42. [Source PDF](../../outside/UH%20Professor%20-%20JB%20Nation%20-%20Lattices,%20Publications/Free%20Lattices%20%28Ralph%20Freese%20Nation%29.pdf).
- [Free Lattices Companion · Chapter I](../learning/freelat-companion-ch01.html) — pedagogical companion to Freese-Nation Ch I.

### Adjacent canonical-form / e-graph
- Willsey, M. (2022). *Practical and Flexible Equality Saturation.* PhD thesis, U Washington. [PDF](https://www.mwillsey.com/thesis/thesis.pdf)
- [E-graph (nLab)](https://en.wikipedia.org/wiki/E-graph) ; [awesome-egraphs](https://github.com/philzook58/awesome-egraphs)
- E-graphs Modulo Theories (2024). [arXiv:2504.14340](https://arxiv.org/html/2504.14340)

### Lattice variety theory
- Jipsen, P., Rose, H. (1992). *Varieties of Lattices.* Lecture Notes in Mathematics 1533. [PDF](https://www1.chapman.edu/~jipsen/Jipsen%20Rose%201992%20Varieties%20of%20Lattices.pdf)
- Reading, N., Speyer, D., Thomas, H. (2019). The fundamental theorem of finite semidistributive lattices.
- Dedekind, R. (1900). On the calculation of FL_M(3). [Historical]
- Whitman, P. M. (1941, 1942). *Free Lattices I, II.* Annals of Mathematics 42, 43.

### Related Prologos artifacts
- [`structural-thinking.md`](../../.claude/rules/structural-thinking.md) — Hyperlattice Conjecture, SRE lattice lens
- [SRE Master](../tracking/2026-03-22_SRE_MASTER.md) — Track 2G (algebraic foundation), Track 2H (type lattice Heyting redesign)
- [Track 2H Design](../tracking/2026-04-02_SRE_TRACK2H_DESIGN.md), [Track 2H PIR](../tracking/2026-04-03_SRE_TRACK2H_PIR.md)
- [HYPERCUBE_BSP_LE_DESIGN_ADDENDUM](2026-04-08_HYPERCUBE_BSP_LE_DESIGN_ADDENDUM.md) — current evidence base for Hasse optimality
- [Adhesive Categories and Parse Trees](2026-04-03_ADHESIVE_CATEGORIES_PARSE_TREES.md) — SRE Track 2D foundation
- Companion note: [2026-04-30_WIDENING_NARROWING_INFINITE_DOMAINS_FOR_UCS.md](2026-04-30_WIDENING_NARROWING_INFINITE_DOMAINS_FOR_UCS.md) — limit-case half of the picture

---

## 10. One-paragraph executive summary

Free-lattice theory (Freese-Nation 1995) gives us three load-bearing tools that are absent from current SRE infrastructure: (i) Whitman's algorithm as a known-correct decision procedure for ≤ in FL(X), structurally isomorphic to PUnify's recursive descent and worth auditing as such; (ii) canonical form (Theorem 1.17, unique-up-to-commutativity minimal-rank representative; Theorem 1.19, unique minimal join representation under refinement) which would let us canonicalize lattice values for cell equality, hash-consing, and optimality arguments; (iii) variety-relative free lattices FL_V(X) (Birkhoff HSP) which are the *correct* design target for SRE cells — cells are quotient elements in some FL_V(X) where V is the domain's variety, not absolutely-free elements. The Hyperlattice Conjecture's optimality claim, restricted to a variety where canonical form is computable, becomes a per-variety algebraic theorem rather than a structural conjecture. Concrete next moves: (a) sample-check SD∨/SD∧ as algebraic properties on existing SRE merges (small, immediate, mirrors Track 2G); (b) audit PUnify's recursive cases against Whitman's six (research task); (c) gated on PPN 4 closing, propose an SRE track for type-lattice variety identification + canonical-form algorithm. This note is Stage 0/1; no design commitments.
