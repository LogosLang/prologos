# Widening, Narrowing, and Continuity: Infinite-Domain Reasoning for UCS

**Date**: 2026-04-30
**Stage**: 0/1 (deep research, vocabulary, theory grounding — not design)
**Series**: UCS (Universal Constraint Solving), with cross-cutting concerns to SRE
**Status**: Research synthesis — no design commitments
**Author**: Claude (research synthesis from dialogue)

**Reading order**: Stage 0/1 artifact per [DESIGN_METHODOLOGY.org](../tracking/principles/DESIGN_METHODOLOGY.org) § Stage 1. Companion: [2026-04-30_LATTICE_VARIETY_AND_CANONICAL_FORM_FOR_SRE.md](2026-04-30_LATTICE_VARIETY_AND_CANONICAL_FORM_FOR_SRE.md) covers the element-level half (canonical form). Read both together; canonical form addresses elements, widening/narrowing addresses limits. They are complements.

**Source companion**: [Free Lattices Companion · Chapter I](../learning/freelat-companion-ch01.html) §4–5 (continuity Theorem 1.22, incompleteness 1.23–1.26). Anchor reading on widening/narrowing: Cousot & Cousot, *Abstract Interpretation: A Unified Lattice Model for Static Analysis of Programs by Construction or Approximation of Fixpoints* (POPL 1977).

---

## 0. Errata / prior-art corrections (added post-mempalace cross-check)

A mempalace semantic search on this note's topic surfaced load-bearing prior art my direct codebase grep missed. Three substantive corrections to the framing below:

1. **Widening primitives already exist in the codebase.** [`racket/prologos/propagator.rkt`](../../racket/prologos/propagator.rkt) lines 129–133, 322–337 implement: `net-set-widen-point`, `net-widen-point?`, `net-cell-write-widen`, `run-to-quiescence-widen`, plus per-cell `widen-fn` and `narrow-fn` storage on the cold-network struct. [`syntax.rkt:720`](../../racket/prologos/syntax.rkt) defines `expr-net-new-cell-widen` as a first-class AST node. The substrate is in place. What is missing is per-domain continuity declaration and UCS dispatch using these primitives — *not* the primitives themselves. §6.2 below mis-framed widening as "to be implemented as a stratum"; correction is that widening is already a propagator-network primitive, and the open work is *registering* widening operators per-domain and wiring `#=` dispatch to use them.

2. **The AI ↔ PPN mapping was already drafted.** [`docs/research/2026-03-26_LATTICE_FOUNDATIONS_PPN.md`](2026-03-26_LATTICE_FOUNDATIONS_PPN.md) §1.5 contains a mapping table from abstract-interpretation concepts to PPN infrastructure — including `Widening → Fuel limits / meta-variable defaulting` and `Narrowing → ATMS nogood retraction`. The S(-1) retraction stratum is *already cast* as the narrowing mechanism in that doc. This note's §6.2 narrowing-as-stratum claim is consistent with that prior framing but should cite it, not present it as new.

3. **Specific Prologos widening examples are already documented.** [`docs/tracking/principles/GÖDEL_COMPLETENESS.org`](../tracking/principles/GÖDEL_COMPLETENESS.org) documents two concrete cases: (a) integer range analysis — concrete domain ℤ (infinite height), widen to sign domain {neg, zero, pos, top} (finite height 2); (b) resource bound analysis — concrete usage counts unbounded, widen to multiplicity lattice {m0, m1, mw} (height 2). Both with stated proof obligations on the widening operator's finite-height target. These are not hypothetical: they are committed completeness arguments. §6.1's "iteration profile" table should incorporate the multiplicity lattice example as already-handled, not as a future case.

4. **Adjacent prior design.** [`docs/research/2026-03-07_NARROWING_ABSTRACT_INTERPRETATION_DESIGN.md`](2026-03-07_NARROWING_ABSTRACT_INTERPRETATION_DESIGN.md) and [`docs/research/2026-03-07_NARROWING_AND_SEARCH_HEURISTICS.md`](2026-03-07_NARROWING_AND_SEARCH_HEURISTICS.md) constitute prior Stage 0/1 work specifically on narrowing-with-abstract-interpretation, including DD-9 (narrowing over the pure fragment via QTT capability binders). This note overlaps that work and should be read alongside it; the specific *Stage 0/1 contribution of this note* is the cross-cutting concern to UCS dispatch and to SRE per-domain continuity declaration, not the foundational widening/narrowing design (which is older and more developed than I initially recognized).

The track-shape sketch in §9 stands but is reframed as "wire existing primitives through UCS, declare continuity per-domain" rather than "implement widening substrate." Estimated scope is correspondingly smaller (the substrate exists).

Origin: cross-check via `mempalace_search` queries on 2026-04-30, after initial draft. Per [`mempalace.md`](../../.claude/rules/mempalace.md) cross-check discipline — staleness flag was on the *original* draft's understatement of readiness, not on a mempalace hit. The lesson: mempalace surfaces semantic-adjacent prior art that keyword grep misses when the prior art uses different vocabulary (this note: "widening"; prior art: also "fuel limits", "S(-1) retraction", "narrowing", "well-founded measure on infinite abstract").

---

## 1. Why this note exists

UCS_MASTER.md states the vision: "any domain with sufficient algebraic structure supports automatic constraint solving via propagators. A domain-polymorphic `#=` operator selects solving strategy based on the domain's algebraic class." The strategy table is dispatched by algebraic class — Boolean → SAT/CDCL, Heyting → intuitionistic solving, residuated → backward propagation, quantale → resource-aware, distributive → efficient join/meet, free → Robinson-Martelli-Montanari unification.

The strategy table is silent on a question that becomes load-bearing the moment we leave finite domains: **how does the solver behave when the cell domain has no ACC (ascending chain condition) — when iteration could in principle never terminate?**

This note frames the answer the static-analysis community arrived at over four decades: *widening* and *narrowing* operators (Cousot & Cousot 1977) on top of *continuity* (Scott 1969, Kahn 1974). The contribution to UCS is a complementary axis to the algebraic-class dispatch: every UCS-registered domain declares not only its algebraic class but its *iteration profile* (finite, ACC-discrete, continuous-but-non-ACC, requires-widening, …), and the solver dispatches sound strategies accordingly.

The note is Stage 0/1: theory grounding, system survey (Cousot foundations, CLP(R), CLP(FD), CHR, Maude narrowing, Astrée), and gap identification. No design commitments. A future Stage 3 design track would follow if pursued.

There is also a cross-cutting concern to SRE: continuity is a *per-domain property* in the same registration sense Track 2G already established. Adding it is a small surface-level change to `sre-domain` with potentially large soundness consequences for UCS dispatch.

---

## 2. The problem: limit cases canonical form cannot handle

[Companion ch01 §4–5](../learning/freelat-companion-ch01.html#s4) summarizes Freese-Nation Theorems 1.22–1.26:

- **Theorem 1.22.** Free lattices are *continuous*: for every up-directed set D and every a ∈ FL(X), a ∧ ⋁D = ⋁{a ∧ d : d ∈ D}, dually for joins.
- **Theorem 1.23 + Example 1.24.** Despite continuity, FL(3) contains an ascending chain a₁ ≤ a₂ ≤ ⋯ that has *no least upper bound* as an element of FL(3). The witness is a fixed-point-free unary polynomial p with p(x) > x for all x and no fixpoint.
- **Theorems 1.25–1.26.** The Galvin-Jónsson "no uncountable chain" theorem; FL(X) is incomplete despite being continuous.

The lesson: **canonical form is a property of elements, not of limits.** If a cell value is approached by an ascending chain whose supremum is not in the lattice, no canonical-form algorithm has anything to say. The fixpoint iteration that would compute the supremum simply does not terminate.

For most current Prologos cells — closed-world type inference over a finite program, finite capability sets, finite session protocols — this never bites. ACC is satisfied trivially because the lattice is finite or quotient-finite. But the moment we go to:

- Open-world type inference where types can be infinitely refined (recursive type schemas; coinductive data; subtyping over an infinite type universe).
- Capability inference through dynamic dispatch where the dispatch table itself grows unboundedly.
- Quantale-valued cells with continuous parameters (real-valued probabilities, tropical costs, density functions).
- Relational/CSP solving over infinite integer or real ranges (UCS's stated direction).
- Constraint domains with countable ascending chains (string lengths, multiset cardinalities).

…ACC can fail and naive iteration diverges. UCS's `#=` operator, dispatching by algebraic class without considering iteration profile, would silently do the wrong thing on these domains — either non-terminating (worst) or losing soundness through ad-hoc iteration cutoffs (also bad).

---

## 3. Continuity: the structural precondition

A complete lattice L is *upper continuous* if for every up-directed set D ⊆ L and every a ∈ L:

  a ∧ ⋁D = ⋁{a ∧ d : d ∈ D}

*Lower continuous* is dual. *Continuous* means both. Equivalently (Scott 1972, Kahn 1974): meets and joins commute with directed limits.

**Why this matters for propagators.** Our propagator network's quiescence is a fixpoint computation. Kleene's fixpoint theorem says: *for monotone continuous functions on continuous lattices, the least fixpoint is reachable by ω-iteration from ⊥.* Continuity is the algebraic hypothesis that makes BSP iteration converge to the right answer. For *finite* lattices, continuity is automatic (every directed set has a maximum, which is its supremum). For our actual cells over infinite type universes or quantale carriers, it is a *non-trivial property* that must be declared per-domain.

**Where this lands as a per-domain property.** Track 2G's algebraic-property registry already records boolean / distributive / Heyting / quantale per domain. Adding *continuity classification* — `:complete`, `:continuous`, `:upper-continuous`, `:lower-continuous`, `:none` — is a parallel small-surface addition. Soundness consequence: when UCS dispatches a `#=` constraint to a strategy that uses Kleene iteration, it can check that the domain's continuity declaration is sufficient for the strategy's hypotheses. Pre-emptive soundness, not after-the-fact divergence diagnosis.

---

## 4. Widening and narrowing: Cousot's mechanism for non-ACC domains

### 4.1 The 1977 framing

Cousot and Cousot, *Abstract Interpretation: A Unified Lattice Model for Static Analysis of Programs by Construction or Approximation of Fixpoints* (POPL 1977, [PDF on Cousot's page](https://www.di.ens.fr/~pcousot/publications.www/Cousot-FSP-2024.pdf), [foundational survey](https://faculty.sist.shanghaitech.edu.cn/faculty/songfu/cav/AIF.pdf)).

The setup: we want to compute the least fixpoint lfp(F) of a monotone F : L → L on a (possibly infinite, possibly non-ACC) lattice L. Naive Kleene iteration F(⊥), F²(⊥), … may not stabilize. *Widening* accelerates convergence to a sound over-approximation of lfp(F); *narrowing* refines the over-approximation back toward (but not below) lfp(F).

### 4.2 Widening operator ∇

A *widening* on L is a binary operator ∇ : L × L → L satisfying:

1. **Upper bound.** a ∇ b ≥ a ∨ b for all a, b.
2. **Termination.** For any sequence x₀, x₁, x₂, … with x_{n+1} = x_n ∇ y_{n+1} (where the y's come from arbitrary subsequent iterates), the sequence is eventually stationary.

Used in iteration: instead of x_{n+1} = F(x_n), compute x_{n+1} = x_n ∇ F(x_n). The sequence stabilizes in finitely many steps at some x* ≥ lfp(F). x* is a *post-fixpoint* of F (F(x*) ≤ x*) and an *over-approximation* of lfp(F).

The art is in choosing ∇: tighter widenings give more precise over-approximations; looser widenings stabilize faster. Halbwachs's thesis (1979) and Bagnara et al. ([widening operators survey](https://www.sciencedirect.com/science/article/abs/pii/S1477842410000254)) catalog widening operators for specific domains (intervals, polyhedra, congruences, octagons).

### 4.3 Narrowing operator Δ

A *narrowing* is a dual refinement operator Δ : L × L → L satisfying:

1. **Lower bound on refinement.** For a ≥ b, b ≤ (a Δ b) ≤ a.
2. **Termination.** Iteration with narrowing terminates.

Used post-widening: starting from x* = post-fixpoint, iterate x_{n+1} = x_n Δ F(x_n). Converges in finitely many steps to a refined over-approximation of lfp(F), still sound but tighter.

### 4.4 The 1992 reframing: Cousot vs Galois connections

Cousot 1992 (*Comparing the Galois Connection and Widening/Narrowing Approaches to Abstract Interpretation*, [Springer](https://link.springer.com/chapter/10.1007/3-540-55844-6_142)) shows that the widening/narrowing approach is *strictly more powerful* than the Galois-connection-on-finite-lattices approach. Concretely: widenings allow infinite abstract domains (intervals, polyhedra) where Galois-connection abstract interpretation is restricted to finite lattices satisfying ACC. Most modern industrial static analyzers (Astrée, Frama-C, Sparrow) use widening/narrowing on infinite domains.

**Implication for us.** Our existing Galois-bridge framework (the SRE lattice lens question 3 — bridges as α/γ adjunctions) is the finite/ACC-restricted case. Extending UCS to infinite domains via widening/narrowing is *strictly more powerful* and complementary. The two coexist; widening kicks in when the domain is non-ACC, Galois bridges keep their role for inter-domain refinement.

### 4.5 Open problems and 2020s state of the art

Recent work flagged for context, not load-bearing:

- *Dissecting Widening: Separating Termination from Information* ([Springer 2019](https://link.springer.com/chapter/10.1007/978-3-030-34175-6_6)) — disentangles the two roles of widening (forcing termination, encoding precision policy).
- *Selective widening* ([POPL 2024](https://dl.acm.org/doi/10.1145/3763083)) — applying widening only at strategically-chosen program points.
- *Widening for equation systems with infinitely many unknowns* — strict ascending/descending phase separation may give up unrecoverable precision.

The field is still active. Importing widening into UCS is a 1977 idea, but the engineering choices around *which* widening, *where* to apply it, and *how* to interleave it with narrowing have continued to evolve.

---

## 5. System survey

Stage 1 requires 3-5 system surveys.

### 5.1 CLP(R) — Constraint Logic Programming over the Reals

Continuous, dense, infinite. Uses Simplex-method linear-arithmetic decision procedures. Domain is structured (linear arithmetic over ℝ), decision procedure is domain-specific, *not* a generic widening framework. Lesson for UCS: domain-specific decision procedures are sometimes preferable to generic widening, when the domain admits one.

### 5.2 CLP(FD) — Constraint Logic Programming over Finite Domains

[SWI-Prolog CLP(FD) reference](https://www.swi-prolog.org/man/clpfd.html), [Triska](https://www.metalevel.at/swiclpfd.pdf). Domain is finite (or, with `inf`/`sup` as infinity sentinels, conceptually infinite-but-interval-bounded). Internal representation: interval trees with `inf`/`sup`. Constraint propagation by AC-3-style arc consistency; enumeration as fallback. The system supports unbounded-domain reasoning by *symbolic interval representation* — values are intervals with possibly-infinite endpoints, propagation operates symbolically — combined with enumeration when narrowing forces concrete values.

Lesson for UCS: *symbolic representation of infinite values via intervals* is a practical encoding that side-steps widening for one specific kind of infinite domain (totally-ordered numeric). Combined with narrowing-via-enumeration, it gives complete or near-complete behavior on a class of constraints. This pattern is directly applicable to integer/numeric SRE domains.

### 5.3 CHR — Constraint Handling Rules

[CHR overview](https://en.wikipedia.org/wiki/Constraint_Handling_Rules), [SWI CHR](https://www.swi-prolog.org/pldoc/man?section=chr). Multi-headed guarded rules that rewrite constraints into simpler ones. Architecturally: a *rewrite system on the constraint store*, with rules dispatched by head-pattern matching. Termination is the user's responsibility — CHR rules can non-terminate.

Lesson for UCS: rewrite-system-driven solving is a *parallel* mechanism to lattice-fixpoint solving; e-graph-style canonicalization (via SRE Track 2D's adhesive-DPO foundation) and CHR-style rewriting share theory. CHR's "user responsibility for termination" is what widening would mechanize for us — turning a termination-by-vigilance system into a termination-by-construction system.

### 5.4 Maude — narrowing-modulo-theory and equational abstraction

[Variants, Unification, Narrowing, and Symbolic Reachability in Maude 2.6 (2011)](https://drops.dagstuhl.de/entities/document/10.4230/LIPIcs.RTA.2011.31), [Symbolic Computation in Maude (Meseguer)](https://courses.grainger.illinois.edu/cs576/fa2021/maude-tapas.pdf), [Twenty Years of Rewriting Logic](https://www.csl.sri.com/~clt/MaudePapers/20-years-latest.pdf).

Maude's `vu-narrow` performs narrowing-based symbolic reachability analysis: solves ∃x. t(x) →* t'(x) by lifting rewriting to terms-with-variables and using unification at each step. When the reachable state space is infinite, *equational abstraction* transforms the rewrite theory by adding equations that quotient the state space to a finite one — a manual widening, in effect. Termination of the abstracted system gives soundness for the original.

Lesson for UCS: equational abstraction is a *theory-driven widening*. The user (or analyzer) introduces equations that quotient an infinite state space to a finite one, and termination follows. This is closely related to free-lattice canonical form in the companion note: a quotient FL(X)/θ where θ encodes the abstraction equations. Widening + narrowing in UCS could be *parameterized by user-declared theories* in the Maude style — making UCS's solver dispatch include "which abstraction theory applies."

### 5.5 Astrée — industrial widening on polyhedra

The canonical industrial deployment of Cousot abstract interpretation. Used on Airbus flight control software. Domain combinations: intervals, octagons, polyhedra, ellipsoids — each with its own widening operator, composed via reduced products. Soundness-by-construction is the load-bearing property; precision is achieved by domain selection and selective widening, not by tightening individual operators.

Lesson for UCS: domain *combination* is a real engineering concern. UCS's `#=` works across domains; when constraints couple two domains (a session-typed channel carrying a probabilistic value), the widening must handle the product. Reduced products (Cousot-Cousot 1979) and pairs-of-widenings are the relevant prior art.

### 5.6 E-graphs and equality saturation

Mentioned in the companion note (canonical form) for completeness, with a different angle here: equality saturation can *diverge* on infinite rewrite systems, and modern e-graph implementations use *fuel limits*, *cost-bounded extraction*, and *lemma-extraction termination heuristics* — all of which are widening-like in spirit (force termination, accept approximation). Bridge to us: SRE Track 2D's adhesive-DPO framework with critical-pair confluence already addresses *some* termination concerns; what it doesn't address is the *unbounded-rewriting* case where confluence holds but ω-iteration is required.

---

## 6. Where this lands in UCS

### 6.1 Per-domain iteration profile declaration

Add to UCS-registered domains (alongside the algebraic-class declaration):

| Iteration profile | Meaning | Solver strategy implication |
|---|---|---|
| `:finite` | Lattice is finite | Naive Kleene iteration; canonical form via free-quotient theory |
| `:ACC-quotientable` | Has ACC under some natural quotient | Canonical form on the quotient; no widening |
| `:continuous` | Upper or lower continuous | Kleene iteration converges; widening optional for speed |
| `:non-continuous` | Neither | Widening required for soundness; declare explicitly |
| `:requires-widening :operator W :narrowing N` | Domain provides its own ∇, Δ | UCS dispatches with declared operators |

This sits *parallel* to the algebraic-class declaration. Domains can be (Boolean, finite), (Heyting, ACC-quotientable), (quantale, continuous), or (custom, requires-widening). UCS's `#=` dispatch reads both axes and selects a sound strategy.

### 6.2 Widening as a stratum

Per [`stratification.md`](../../.claude/rules/stratification.md), strata are first-class: S0 monotone, S(-1) retraction, topology, S1 NAF, etc. Widening is naturally a stratum — it sits *above* S0 (operates on the result of S0 iteration), and below any decision stratum that needs the over-approximation as its starting point. Narrowing is a separate stratum, dual.

Concretely: for a domain that requires widening, BSP iteration runs S0 with iteration cap; if cap is hit, transfer control to the widening stratum, which applies ∇ to the cap-limited iterate; resume S0 with the widened state; repeat until ∇-fixpoint; then optionally enter the narrowing stratum to refine.

This is the same mechanism the topology stratum uses — request-cell + handler — adapted to the widening request. Engineering shape is known; semantics is the contribution.

### 6.3 Connection to canonical form (companion note)

Canonical form (companion §5) handles *elements* — finite, in-the-lattice, well-defined representatives. Widening handles *limits* — the case where iteration's would-be-supremum is not in the lattice. They are *complementary*:

- Cell value is in the lattice, finite domain → canonical form for equality, hash-cons, optimality.
- Cell value is approached by a chain whose limit is in the lattice → continuity ensures Kleene converges; canonical form applies to the limit element.
- Cell value is approached by a chain whose limit is *not* in the lattice → widening produces a sound over-approximation in the lattice; canonical form applies to the over-approximation.

The cleanest unification: UCS dispatches by (algebraic-class, iteration-profile). The strategy table becomes 2D. SRE's per-domain registry holds both axes. The companion note's variety-canonical-form work and this note's widening-narrowing work are two halves of the same per-domain declaration.

### 6.4 Quantale-valued domains: noted, deferred

The source dialogue flagged quantale-valued domains as a separate research thread. They are doubly affected by this note: continuity is a non-trivial property on quantales (most quantales are continuous in the order-theoretic sense, but the *multiplication* may not commute with directed limits in the way meet/join do); widening on quantales is largely unstudied. Flagged as a separate Stage 0/1 follow-up if the project elects to push the quantale frontier.

---

## 7. Cross-cutting concern to SRE

**Continuity declaration is a Track 2G-style addition.** Track 2G already established the precedent: per-domain algebraic properties are declared in `sre-domain` and sample-checked. Continuity is structurally identical in implementation:

- Add `:continuity-class` to `sre-domain` (default `:finite`, since most current cells are).
- Add a sample-check: for declared `:continuous`, randomly sample directed sets and verify a ∧ ⋁D = ⋁{a ∧ d}.
- Add an optional `:widening-operator` and `:narrowing-operator` for `:non-continuous` declared domains.

The check is small. The soundness consequence for UCS is large. This is the kind of move that mirrors §5.4 of the companion note (SD∨/SD∧ as algebraic-property checks): low engineering cost, high architectural payoff, no need to wait for a full track design.

---

## 8. Open questions

1. **Which current SRE domains are non-continuous?** Empirical question. Most are finite. The type lattice (post-Track 2H Heyting) is plausibly continuous (Heyting ⊃ distributive ⊃ continuous on bounded lattices) but worth verifying. The session lattice with quantale tensor is the most uncertain.

2. **Is the propagator-network quiescence semantics already implicitly assuming continuity?** Almost certainly yes. The question is whether any current cell's merge violates the continuity hypothesis silently. Audit-shape question.

3. **What is the right interaction between widening and the BSP scheduler?** Widening is naturally a stratum, but the *decision* to widen (cap S0 iteration count, transfer to widening stratum) is a heuristic that the scheduler must implement. Selective widening (POPL 2024) suggests this is a non-trivial choice.

4. **Can UCS's `#=` operator be soundly dispatched on a domain with no declared iteration profile?** Probably no: undeclared = potentially non-continuous = potential silent divergence. The declaration would need to be mandatory for UCS-eligible domains.

5. **Does Maude's equational-abstraction pattern fit our SRE Track 2D adhesive-DPO framework?** They're structurally close — both are theory-driven quotients of a rewrite system. A research follow-up on the unification could yield a single framework for both abstraction and canonicalization.

6. **What about quantale-valued domains?** Genuinely deferred (§6.4); a separate Stage 0/1 note when the project wants to push there.

---

## 9. Implementation note for UCS Master series

If the project elects to pursue this research direction, the track shape would be roughly:

**Track [TBD]: Per-Domain Iteration Profile + Widening Stratum**

- *Phase 0 (Acceptance)*: A `.prologos` acceptance file exercising UCS `#=` across both finite and infinite domains. Includes deliberately-non-terminating cases for the infinite-domain examples to verify widening kicks in.
- *Phase 1 (Continuity audit)*: Empirically determine continuity classification for every existing SRE-registered domain. Output: a `:continuity-class` field added to `sre-domain` with declared values per domain.
- *Phase 2 (Widening stratum infrastructure)*: Implement widening as a stratum on the BSP scheduler. Request-accumulator cell, handler, integration with S0 iteration cap. No domain-specific widening operators yet; just the substrate.
- *Phase 3 (Interval domain pilot)*: Implement a numeric/interval domain with declared widening operator (CLP(FD)-style symbolic intervals with `inf`/`sup`). UCS `#=` over intervals dispatches via the widening stratum.
- *Phase 4 (Narrowing stratum)*: Add narrowing as a complementary stratum. Refine over-approximations from Phase 3 toward the true fixpoint.
- *Phase 5 (Type-lattice non-continuity, if any)*: Apply Phase 2-4 infrastructure to any type-lattice extensions that turn out to be non-continuous (e.g., recursive type schemas, coinductive types).
- *Phase T (Test track)*: `test-ucs-widening.rkt` covering termination, soundness (over-approximation property), and parity with naive iteration on cases where naive terminates.

Track gating: The companion note's "PPN 4 must close first" gating applies here too — type-lattice extensions are downstream. The widening *substrate* (Phases 0-4) can proceed independently once UCS R0/R1/R2 (research foundations) close.

Estimated scope: 1 week design (Stage 2/3), 2-3 weeks implementation (Stage 4). Riskiest phase is 3 if the interval domain has interactions with existing SRE registrations we haven't anticipated.

---

## 10. References

### Foundational abstract interpretation
- Cousot, P., Cousot, R. (1977). *Abstract Interpretation: A Unified Lattice Model for Static Analysis of Programs by Construction or Approximation of Fixpoints.* POPL '77.
- Cousot, P., Cousot, R. (1992). *Comparing the Galois Connection and Widening/Narrowing Approaches to Abstract Interpretation.* PLILP '92. [Springer link](https://link.springer.com/chapter/10.1007/3-540-55844-6_142)
- Cousot, P. (2024). *A Personal Historical Perspective on Abstract Interpretation.* [PDF](https://cs.nyu.edu/~pcousot/publications.www/Cousot-FSP-2024.pdf)
- Cousot, P., Cousot, R. (1992). *Abstract Interpretation and Application to Logic Programs.* J. Logic Programming. [PDF](https://www.di.ens.fr/~cousot/publications.www/CousotCousot-JLP-v2-n4-p511--547-1992.pdf)

### Widening operators
- Bagnara, R., et al. *Widening Operators for Powerset Domains.* [Survey](https://www.sciencedirect.com/science/article/abs/pii/S1477842410000254)
- Halbwachs, N. (1979). *Détermination automatique de relations linéaires vérifiées par les variables d'un programme.* [PhD thesis]
- *Dissecting Widening: Separating Termination from Information.* [Springer 2019](https://link.springer.com/chapter/10.1007/978-3-030-34175-6_6)
- *Efficient Abstract Interpretation via Selective Widening.* PACMPL 2024. [DL](https://dl.acm.org/doi/10.1145/3763083)

### CLP / CHR
- Triska, M. *The Finite Domain Constraint Solver of SWI-Prolog.* [PDF](https://www.metalevel.at/swiclpfd.pdf)
- [SWI-Prolog CLP(FD) Manual](https://www.swi-prolog.org/man/clpfd.html)
- [SWI-Prolog Constraint Handling Rules](https://www.swi-prolog.org/pldoc/man?section=chr)
- *Compiling constraints in clp(FD).* [ScienceDirect](https://www.sciencedirect.com/science/article/pii/0743106695001212)
- *Constraint Logic Programming over Infinite Domains with an Application to Proof.* [arXiv 2017](https://arxiv.org/pdf/1701.00629)

### Maude
- *Variants, Unification, Narrowing, and Symbolic Reachability in Maude 2.6* (2011). [Dagstuhl](https://drops.dagstuhl.de/entities/document/10.4230/LIPIcs.RTA.2011.31)
- Meseguer, J. *Symbolic Computation in Maude: Some Tapas.* [Lecture notes](https://courses.grainger.illinois.edu/cs576/fa2021/maude-tapas.pdf)
- *Twenty Years of Rewriting Logic.* [PDF](https://www.csl.sri.com/~clt/MaudePapers/20-years-latest.pdf)

### Continuity / order theory
- Scott, D. (1972). *Continuous lattices.* In Toposes, Algebraic Geometry and Logic.
- Kahn, G. (1974). *The Semantics of a Simple Language for Parallel Programming.*
- Freese, R., Ježek, J., Nation, J. B. (1995). *Free Lattices,* Theorem 1.22 (continuity).

### Related Prologos artifacts
- [UCS Master](../tracking/2026-03-28_UCS_MASTER.md) — algebraic-class dispatch vision
- [`stratification.md`](../../.claude/rules/stratification.md) — stratum mechanism on BSP base
- [`structural-thinking.md`](../../.claude/rules/structural-thinking.md) — Galois bridges (the finite/ACC-restricted complement)
- [SRE Track 2G PIR](../tracking/2026-03-30_SRE_TRACK2G_PIR.md) — algebraic-property registry precedent
- [SRE Track 2D PIR](../tracking/2026-04-03_SRE_TRACK2D_PIR.md) — adhesive-DPO foundation
- Companion note: [2026-04-30_LATTICE_VARIETY_AND_CANONICAL_FORM_FOR_SRE.md](2026-04-30_LATTICE_VARIETY_AND_CANONICAL_FORM_FOR_SRE.md)
- [Universal Constraint Solving research](2026-03-28_UNIVERSAL_CONSTRAINT_SOLVING.md) — UCS R0 source material

---

## 11. One-paragraph executive summary

Cousot abstract interpretation (1977; updated through 2024) gives the static-analysis community four decades of theory for reasoning soundly over infinite lattices: *continuity* as the structural precondition that makes Kleene fixpoint iteration converge; *widening* operators ∇ that force convergence to a sound over-approximation when ACC fails; *narrowing* operators Δ that refine the over-approximation back toward the true fixpoint; and the 1992 result that widening/narrowing on infinite domains is strictly more powerful than Galois-connection abstract interpretation on finite ones. UCS's vision of a domain-polymorphic `#=` dispatched by algebraic class (Boolean, Heyting, residuated, quantale, distributive, free) is silent on the *iteration profile* of each domain; the moment we leave finite domains — recursive types, coinductive data, quantale-valued probabilistic cells, integer/real CSP — naive iteration may diverge silently. The cross-cutting move to SRE is small: add `:continuity-class` to `sre-domain`, sample-check it the way Track 2G already sample-checks distributivity. The cross-cutting move to UCS is medium: implement widening and narrowing as strata on the BSP scheduler, with per-domain `:widening-operator` declarations, and dispatch `#=` by both axes (algebraic class × iteration profile). Survey of CLP(R), CLP(FD), CHR, Maude narrowing-modulo-theory, and Astrée locates the engineering precedents. The companion note on canonical form covers the *element* level (finite, in-lattice values); this note covers the *limit* level (values approached by chains whose suprema may not exist). They are complementary halves of the same per-domain declaration. Stage 0/1; no design commitments.
