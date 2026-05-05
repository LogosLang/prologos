# Multi-Party Protocols as Polynomial Functors over a Quantale-Valued Propagator Runtime

**A Stage 0/1 Research Synthesis**

**Date**: 2026-05-05
**Stage**: Stage 0/1 — research synthesis. No design commitments; informs subsequent design considerations.
**Series**: cross-cutting; supports multi-party computation, distributed concurrent runtime efforts, eventual deployment of multi-party-session-type primitives, NTT extension scoping.
**Status**: complete first pass; subject to revision as design tracks surface concrete requirements.

**Cross-references**:
- [Asynchronous Programming on a Quantale-Enriched Propagator Substrate](2026-05-05_ASYNCHRONOUS_PROGRAMMING_QUANTALE_RESEARCH_PROGRAM.md) — companion artifact; quantale foundations, polynomial-functor + LCCC + DTT background, Spritely/OCapN coverage, choreographic-programming coverage
- [Process Calculi and Session Types: A Theoretical Survey](2026-03-03_PROCESS_CALCULI_SURVEY.md)
- [Tropical-Quantale Research](2026-04-21_TROPICAL_QUANTALE_RESEARCH.md)
- [Effectful Propagators Research](../tracking/2026-03-06_EFFECTFUL_PROPAGATORS_RESEARCH.md)
- [Architecture A+D Implementation Design](../tracking/2026-03-07_ARCHITECTURE_AD_IMPLEMENTATION_DESIGN.org) — effect-ordering quantale infrastructure
- [PPN 4C Tropical Quantale Addendum Design](../tracking/2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_DESIGN.md) — tropical-quantale cost layer

---

## §0 Executive Summary and Reading Map

This artifact is a Stage 0/1 research synthesis on multi-party computation and multi-party session types, conducted in support of the Prologos language project's distributed concurrent runtime efforts and the long-deferred design question of how multi-party protocols should be specified, type-checked, and realised in the language. The artifact accompanies the companion 2026-05-05 *Asynchronous Programming on a Quantale-Enriched Propagator Substrate* synthesis, extending its polynomial-functor and quantale machinery from sequential and binary-asynchronous settings into the multi-party frontier. It surveys the field across foundational, classical, escape-route, and frontier strata (1993–2026), with a strong lean toward an architectural target the user has committed to: *multi-party protocols as polynomial functors over a quantale-valued propagator runtime, with role projection as opcartesian lifts in a fibration, behaviour as coalgebras, realizability as a quantale-valued fixpoint, and composition as conjunctive refinement realised by the polynomial-functor composition product*.

### What this artifact is

A long-form (~62,000 words including bibliography) research synthesis structured as eight era / topic surveys plus a synthesis chapter, with bookend framing. Each survey was produced by an independent research agent with its own bibliography and cross-references; the synthesis chapter argues the architectural target using the slices' assembled evidence. The artifact stands alone but cross-references the companion async-programming research artifact extensively (especially for the linear-logic-as-quantale story, the Lawvere-metric / quantale-foundations material, the choreographic-programming surface coverage, and the post-2020 quantale-coalgebraic frontier).

### What this artifact is not

It is not a design document. It does not commit the project to specific multi-party-session-type primitives, NTT extensions, or implementation pathways. It does not adjudicate among the various MPST repair strategies in the published literature; it argues that none of them addresses the structural critique the user's diagnostic intuition identified, and that the architectural target the synthesis chapter develops is the candidate worth testing rather than committing to.

### Reading map

The artifact has eight top-level parts:

**§I — Foundations of session types** (binary). Honda 1993 origins; Honda-Vasconcelos-Kubo 1998; the Caires-Pfenning linear-logic correspondence (CONCUR 2010); polarised SILL (Pfenning-Griffith 2015); dependent session types (Toninho-Caires-Pfenning 2011; Thiemann polymorphic typestate 2022); session coalgebras (Keizer-Basold-Pérez 2020); higher-order session types (Bernardi-Hennessy 2016). Slice 01.

**§II — Classical MPST and the 2019 reckoning + the OO-inheritance diagnostic.** Honda-Yoshida-Carbone POPL 2008 / JACM 2016; the projection-with-merge architecture; the broken-proofs cascade exposed by Scalas-Yoshida POPL 2019; the technical anatomy of where the proofs break (full merge versus plain merge; consistency invariant failure under reduction); the 2023 CAV structural completeness critique [Li-Stutz-Wies-Zufferey 2023] independent of proof technique; the load-bearing OO-inheritance diagnostic with the eight-row correspondence table; the 2024 Hou-Yoshida-Kuhn association repair (light treatment); asynchronous subtyping decidability frontier (cross-cut to async research). Slice 02.

**§III — Escape routes from projection-with-merge.** Synthetic MPST [Castro-Perez-Ferreira-Jongmans POPL 2026] (skip projection, type processes directly against the LTS); AMP / Protocol State Machines [Stutz et al. CAV 2023] (replace global types with PSMs); MCC and coherence-as-n-ary-duality [Carbone-Lindley-Montesi-Schürmann-Wadler 2016] (generalise binary cut to n-ary coherence); choreographic programming categorical content (Pirouette, λ_QC, ChoRus, HasChor, Ozone, Bak-Urschumzew modal-type-theory choreography). Slices 03 and 04.

**§IV — Categorical and algebraic foundations the architecture builds on.** §IV.5 Polynomial functors over LCCC and dependent type theory (Spivak-Niu 2024 monograph; Aberlé-Spivak 2025 polynomial-universes; the composition product `P ◇ Q`; the bicategory of polynomial functors with lenses). §IV.6 Quantale-enriched session types (Yetter 1990 quantales-as-linear-logic-phase-semantics; Mulvey-Rosenthal Brown-Gurr representation; Bacci-Mardare-Panangaden-Plotkin 2023; Beohar et al. STACS 2024; Goncharov et al. FoSSaCS 2023; tropical-quantale realizability). §IV.7 Conjunctive composition and bundle algebra precedents (Prolog → CCP → Schärli traits → polynomial-functor composition product as a unifying structural theme). Slices 05, 06, 07.

**§V — Synthesis: Multi-Party Protocols as Polynomial Functors over a Quantale-Valued Propagator Runtime.** Seven subsections: §V.1 the diagnostic restated with hostile-reviewer-anticipation; §V.2 polynomial-functor composition product as the categorical realisation of conjunctive refinement; §V.3 role projection as opcartesian lift in a fibration over the participant lattice; §V.4 quantale-valued realizability as propagator-network fixpoint; §V.5 multi-party from binary plus dependent-types-in-continuation as the candidate structural identification; §V.6 eight gaps the architecture addresses; §V.7 reading the architectural argument against the evidence (calibrated H1–H5).

**§VI — Frontier 2024-2026 scan.** Recent MPST work (2024 *Less is More Revisited*; Castro-Perez-Ferreira-Jongmans synthetic 2026; Stutz et al. continued PSM/AMP work; Bravetti et al. fair-MPST 2025); recent quantale-enriched concurrent semantics; recent polynomial functors in DTT; recent choreographic-programming categorical work; effect-handler / capability frontier cross-cuts; Spritely / OCapN connection; tropical-PL-semantics cross-cuts; explicit gap inventory. Slice 08.

**§VII — Sub-questions for design considerations.** Eight design considerations the architectural target raises, each with prerequisites and cross-references — explicitly *considerations* rather than track commitments, per the user's framing.

**§VIII — Out-of-scope declarations.** Topics the artifact deliberately excludes; areas treated lightly; flagged-for-future-research.

### Reading paths

- *Project members familiar with Prologos's substrate.* §0 → §V → §VII. The era surveys are reference material; the synthesis chapter and design considerations are the load-bearing content.
- *Readers seeking the diagnostic.* §II.4 (OO-inheritance correspondence) → §V.1 (synthesis-level restatement) → §V.7 (calibrated argument against the evidence).
- *Readers seeking the categorical argument.* §IV.5 (polynomial functors + LCCC) → §IV.7 (conjunctive composition) → §V.2 (composition product as conjunctive refinement) → §V.3 (fibrational role projection) → §V.5 (dependent types in continuation positions).
- *Readers seeking the cost-aware story.* §IV.6 (quantale-enriched session types) → §V.4 (realizability as propagator-network fixpoint) → §VI (frontier resource-bounded type theory cross-cut).
- *Readers seeking the historical narrative.* §I → §II → §III → §IV → §VI in order.
- *Readers seeking the gaps.* §VI.8 (frontier gap inventory) → §V.6 (synthesis-chapter restatement) → §VII (design considerations).

### Citation conventions

Citations appear inline as `[Author Year]` or short keys; full annotated entries are co-located with their use in each part's *References* subsection. Total citation count across the artifact is approximately 257 distinct references. The synthesis chapter cites by reference to era sections rather than carrying its own bibliography. Some attribution corrections are flagged in the slice 08 frontier scan: the 2024 *We Know I Know You Know* paper (arXiv 2403.05417) is by Bates and Near (Vermont), not Lam-Hirsch-Cecchetti as I had cited at briefing time; the 2024 *Fundamenta Informaticae* paper authors are Castellani-Dezani-Ciancaglini-Giannini, not the four-author attribution I had given. The Aberlé-Spivak polynomial-universes work is a corpus (the canonical paper is the MFPS XLI paper at arXiv:2409.19176) rather than a discrete "Compositional Program Verification" paper.

### A note on section ordering

The artifact was assembled from eight Phase-1 slices written by independent research agents, each with a specific era / sub-field mandate. Each slice was self-contained (sections plus bibliography) and cross-referenced its neighbours. The assembled artifact preserves the slice-level organisation; the TOC and reading map are the primary navigation aids. Section labelling follows the slice authorship rather than strict numerical order in places; readers should treat section numbering as a labelling system rather than a strict ordering.

---

## §I.0 Frame and Working Hypothesis

### §I.0.1 The MPST question, restated for Prologos

Multi-party session types (MPST) are the canonical type-theoretic tool for specifying and checking that a system of communicating processes follows a structured protocol. Honda-Yoshida-Carbone introduced the framework at POPL 2008 with the goal of generalising Honda's binary session types from two-party communication to *n*-party interactions. Eighteen years later, the framework is mature, widely cited, broadly implemented in tooling, and — by the assessment of the community itself — foundationally unsettled. The 2019 *Less is More* paper [Scalas-Yoshida 2019] established that a substantial body of subject-reduction proofs in the MPST literature is unsound under full merge; the 2023 CAV paper [Li-Stutz-Wies-Zufferey 2023] established that the projection operator is incomplete or unsound (independent of proof technique); the 2024 *Less is More Revisited* paper [Hou-Yoshida-Kuhn 2024] supplied a repair for the soundness side via the *association* invariant; the synthetic-MPST line [Castro-Perez-Ferreira-Jongmans POPL 2026] proposes abandoning projection entirely; the AMP / PSM line [Stutz et al.] proposes replacing global types with Protocol State Machines; the MCC line [Carbone-Lindley-Montesi-Schürmann-Wadler 2016] proposes generalising binary duality to n-ary coherence in classical linear logic. The community has not converged on which of these is the right foundation.

The Prologos project faces a more specific question. Binary session types are implemented (S8a complete, S8b runtime deferred). The bundle/trait system implements conjunctive refinement composition for type-level method requirements, deliberately avoiding multiple-inheritance pathologies. The effect-ordering system uses a quantale-shaped accumulation lattice + transitive-closure propagator for causal delivery and cross-channel data dependencies. The propagator-network substrate computes lattice-valued fixpoints via BSP scheduling, with CALM-monotonicity within strata. The dependent type theory is a Martin-Löf MLTT with universe levels. The Network Type Theory is a designed declarative spec language for propagator networks, capturing stratification, bridges as Galois connections, propagators as polynomial functors, and lattice structures.

Given this infrastructure, the question is: what is the right multi-party session type story to build on top? The user's experience with the MPST literature has been that "something seems off" — a diagnostic intuition flagged in the design conversation underlying this artifact. The artifact's job is to make that intuition precise, locate its formal source, survey the field's escape routes from the foundation the intuition diagnosed, and develop the candidate architectural target the project's existing infrastructure already supports.

### §I.0.2 Architectural target

The architectural target the synthesis chapter argues is the following:

> **Multi-party protocols are polynomial functors `P : C → C` in a locally cartesian closed category — the dependent type theory's denotational setting. The polynomial functor's positions are the protocol's branching choices; its directions factor per role as `B(a) = Π_{r ∈ Roles} B_r(a, v)`, with `v` the value carried at the position. Composition is the polynomial-functor composition product `P ◇ Q` (Spivak-Niu §5), associative with unit and respecting bicategorical structure. Role projection is opcartesian lift in a fibration over the participant powerset lattice — categorical, universal, sound by construction (where the lift exists). Behaviour is a coalgebra for the polynomial functor: a state `s` with structure map `s → P(s)`. Realizability is a quantale-valued fixpoint computation in the propagator network, with cost-aware reasoning over latency, message count, fairness deadline, and resource consumption supplied by the tropical-quantale layer already in place on Prologos cells. Composition is conjunctive refinement at the protocol level, *not* projection-with-merge.**

The architectural target has five structural commitments the artifact builds toward:

1. *Polynomial functors, not operads, as the categorical primitive.* Per the user's correction in the design conversation: operads have a single output and many inputs, collapsing the per-position direction structure that polynomial functors expose. Propagators read from sets of cells (n-ary input) and write to sets of cells (m-ary conditional output, with different write-sets per branch); polynomial functors capture this directly via the dependent direction structure `B : A → Set`.

2. *Composition is the polynomial-functor composition product.* This is conjunctive refinement at the protocol level — *categorically realised by* `P ◇ Q` — rather than view reconciliation via merge. The composition product is non-symmetric (encoding sequential dataflow: which `Q`-protocol depends on which `P`-direction); the symmetric-monoidal-subcategory fragment recovers commutative-meet conjunction where wanted.

3. *Role projection is opcartesian lift in a fibration over the participant lattice.* The fibration's base is the participant powerset ordered by inclusion; the fibres are per-participant-set polynomial-functor categories. Role projection becomes a categorical universal-property construction, sound by construction where the lift exists. Two roles' views never need to be reconciled because they are independently lifted from the same upstairs polynomial.

4. *Quantale enrichment supplies the cost layer.* The classical session-types-as-linear-logic-propositions correspondence lives natively in a quantale (Yetter 1990); adding tropical structure gives every protocol composition a cost; multi-dimensional cost (latency × message count × fairness × resource) is the product quantale; Pareto-style reasoning falls out of the lattice meet on the product quantale, computed natively by the BSP-monotone propagator network.

5. *NTT is the deployment vector.* Network Type Theory primitives become the protocol-specification language; "multi-party session types" becomes a library written in NTT, the way "binary session types" already is. The synthesis stays at the categorical level; NTT is the implementation pathway, not the synthesis chapter's concern.

### §I.0.3 The artifact's scope and tone

The artifact is *neutral within era surveys with a strong lean in the synthesis chapter*. The era surveys (§I, §II, §III, §IV, §VI) are written without arguing the architectural target; each surveyor flagged hypothesis-supporting connections where they arose naturally but did not advance the case. The synthesis chapter (§V) is the place where the lean is allowed to be argued, with calibrated honesty about which claims are settled, supported, or hypothesis-level (§V.7's H1–H5 ladder).

The tone is third-person scholarly throughout. The synthesis chapter explicitly anticipates a hostile-reviewer move (the "merge is research-active design parameter, not structural defect" line, weaponised by *Less is More Revisited* + the 2023 CAV result) and responds to it before the H1–H5 ladder. Where the architectural target depends on verification work that the design tracks must produce, the synthesis chapter says so.

The artifact addresses six audiences:

1. *Prologos project members* who will design and implement the multi-party protocol primitives once the foundation work is done.
2. *Future readers of project artifacts* who will encounter this artifact's cross-references.
3. *Adversarial reviewers* (internal or external) who will challenge the architectural target.
4. *Researchers in adjacent fields* — MPST researchers, polynomial-functor / categorical-DTT researchers, quantale-theory researchers, choreographic-programming researchers, Spritely-OCapN / capability-async researchers — for whom the artifact is one possible point of contact.
5. *Implementation engineers* who will build the L2 multi-network runtime that the architectural target's distributed-realizability story requires.
6. *Design-track designers* who will refine the architectural target's commitments into specific track scopes (per §VII).

The artifact does *not* address: end users of the language as a programming environment; an introductory-level audience for whom the era surveys would be too dense; readers seeking only the practical-engineering content.

### §I.0.4 What the artifact establishes

The artifact establishes four things, in roughly decreasing order of strength.

*First*, that classical projection-with-merge MPST has a structural defect (the OO-inheritance correspondence, §II.4 / §V.1) that explains the broken-proofs cascade and the brittleness pattern, and that survives the *Less is More Revisited* repair because the repair addresses soundness rather than structural completeness. This is settled by the assembled evidence in §II and the synthesis chapter's argument in §V.1.

*Second*, that conjunctive refinement is the structurally-correct alternative composition primitive, with a well-developed lineage (Prolog → CCP → Schärli traits → polynomial-functor composition product, §IV.7). The slices document this lineage; the synthesis chapter (§V.2) lifts it to the protocol level via the polynomial-functor composition product, with appropriate algebraic caveats about commutativity and the categorical setting.

*Third*, that the categorical machinery the architectural target requires (polynomial functors over LCCC, polynomial universes in HoTT, fibrations with opcartesian lifts, quantale-enriched session types, coalgebraic behaviour) is technically mature in the published 2020–2026 literature, even though no published work has assembled these pieces into a multi-party-session-type framework. This is supported by the assembled evidence in §IV and §VI.

*Fourth*, that the architectural target addresses eight specific gaps in the published 2024–2026 literature simultaneously (§V.6, §VI.8), with the simultaneity being structural rather than coincidental — the gaps follow from a single set of foundational commitments.

What the artifact does *not* establish, but argues is the right direction to test: that multi-party participation falls out of binary session types augmented with dependent types in continuation positions (H5 in §V.7). The verification — that per-role direction factoring is preserved under composition product — is the central design-track question.

---


---

## Part I — Foundations of Binary Session Types

This part establishes the conceptual lineage of binary session types as a behavioural type discipline for two-party communication, with deliberate emphasis on the linear-logic correspondence (§I.2) and the categorical/coalgebraic reformulations (§I.5) that bear directly on the architectural target. Honda's 1993 origin (§I.1) is given as background; the load-bearing material begins at §I.2 with Caires-Pfenning's interpretation of session types as intuitionistic linear propositions and continues through Wadler's classical-linear reformulation, the polarised SILL program, dependent extensions, session coalgebras, and higher-order session types.

The binary baseline matters for the multi-party synthesis precisely because the categorical foundations being recommended (polynomial functors as protocols, opcartesian lifts as role projection, conjunctive refinement as composition) are most easily seen — and most rigorously grounded — in the binary case before the move to N participants. The architectural commitments stated in the briefing (composition by intersection in a constraint lattice, behaviour as coalgebras, dependent types via Σ/Π adjoints in an LCCC) all have direct precedent here. Where a binary-session-type technique anticipates the multi-party generalisation, the connection is flagged but not argued in depth; arguments for the multi-party targets belong to subsequent slices (§II–§IV).

### §I.1 Origins of binary session types

Session types originate in the work of Kohei Honda on dyadic interaction in concurrent process calculi. Honda's 1993 CONCUR paper [Honda1993] introduced "types for dyadic interaction" as a typed reconstruction of name-passing process calculi, where types denote freely composable structure of dyadic interaction in a symmetric scheme. The motivation was that untyped channel passing in the π-calculus admitted protocol violations not caught by simple sort systems: a channel could be used inconsistently by its two endpoints, sending where the dual peer expected to receive, with no sequential discipline relating successive uses. Honda's response was to assign each channel endpoint a *type* describing the temporal sequence of message exchanges from that endpoint's perspective, with the dual endpoint receiving the dual type. The 1993 paper formulates this in the symmetric scheme — reciprocal types for the two endpoints — and proves type preservation and a typed bisimilarity theorem.

The 1993 system was foundational but not directly programmable. The first highly-cited dyadic system that practitioners could read as a programming-language type discipline was Honda-Vasconcelos-Kubo's ESOP 1998 paper [HondaVasconcelosKubo1998]. There the authors introduced the now-standard primitives for session-typed communication (channel creation, send/receive, branch/select, session delegation) together with an ML-like type discipline that abstracts the interactive behaviour of programs and statically guarantees compatibility of interaction patterns between processes. The key contribution beyond Honda 1993 is the explicit identification of *session types* as a separate syntactic class describing protocol structure (rather than a sub-discipline of process types), with type duality, sequential composition, branching, and delegation cleanly factored. This is the system most subsequent extensions take as their starting point.

For purposes of the present synthesis, both works are background. The technical details that matter downstream are: (a) types describe protocol from one endpoint's perspective; (b) duality relates the two endpoints' types; (c) session types compose sequentially (an output type continues with a new session type); (d) branching introduces internal/external choice. These four properties survive into every subsequent reformulation, including the linear-logic correspondence and the categorical/coalgebraic ones.

### §I.2 The linear-logic-as-session-types correspondence

The 2010s reorganisation of session-types theory began with Caires and Pfenning's CONCUR 2010 paper [CairesPfenning2010] and was completed (in the classical setting) by Wadler's ICFP 2012 paper [Wadler2012, Wadler2014]. The two papers together establish a Curry-Howard correspondence between session types for the π-calculus and propositions of linear logic: propositions are session types, sequent proofs are processes, cut elimination is communication. This correspondence is the load-bearing antecedent for the architectural target's claim that protocols should be analysed in terms of the algebraic structures linear logic inhabits — namely, quantales (Yetter 1990 [Yetter1990], Mulvey-Rosenthal). The companion async-research artifact develops the quantale-as-target argument in its §3.1; the present section establishes the session-types-side of that connection.

#### §I.2.1 Caires-Pfenning: dual intuitionistic linear logic

Caires and Pfenning [CairesPfenning2010] introduce a type system for the π-calculus that exactly corresponds to the standard sequent calculus proof system for *dual intuitionistic linear logic* (DILL). The interpretation reads each linear connective as a session-type operator, and each sequent proof as a typing derivation for a π-calculus term. The cut rule, in particular, becomes parallel composition with channel restriction: when two processes are typed against complementary linear hypotheses on a single channel, the cut between their typing derivations corresponds to running them in parallel and hiding the shared channel. Cut elimination then becomes communication: the proof reductions that eliminate cuts directly model the operational steps by which the two processes exchange messages along the cut channel.

The interpretation table that this paper establishes — and which Toninho-Caires-Pfenning's MSCS 2013 journal version [ToninhoCairesPfenning2013] elaborates — fixes the now-standard correspondences:

| Linear-logic connective | Session-type operator |
|---|---|
| `A ⊗ B`  (tensor)  | `!A.B` (send a value of type `A`, continue with `B`) |
| `A ⊸ B`  (linear arrow)  | `?A.B` (receive a value of type `A`, continue with `B`) |
| `A & B`  (with)  | external choice between `A` and `B` |
| `A ⊕ B`  (plus)  | internal choice between `A` and `B` |
| `!A`  (bang)  | replicable / shared session of type `A` |
| `1`  (unit)  | session termination (output side) |
| `⊥`  (perp / bottom) | session termination (input side) |

The intuitionistic formulation is two-sided: a typing judgement places zero or many channels on the left (the resources the process *consumes*) and exactly one channel on the right (the resource the process *provides*). This judgemental shape is asymmetric — distinguishing a process's offered service from the services it relies on — which has methodological consequences explored in the polarisation work below. The paper proves three key results: session fidelity (a typed process exchanges along each channel exactly the messages prescribed by the session type), absence of deadlocks (a typed process can always either reduce or has reached a designated terminal form), and a *tight* operational correspondence between π-calculus reductions and cut-elimination steps. The tight correspondence is bidirectional: every π-calculus reduction is simulated by a proof reduction on the typing derivation, and every proof reduction yields a corresponding process reduction. The proof method establishes a strong form of subject reduction.

For the architectural target, the load-bearing point is not the syntactic correspondence per se but its semantic shadow: any algebraic structure that interprets DILL provides a semantic interpretation of session types. Linear-logic phase semantics is one such interpretation, and phase semantics lives natively in quantales (Yetter [Yetter1990]; Mulvey-Rosenthal lineage discussed in [Wadler2012]'s motivation and explicitly in Vickers's quantale-and-process-semantics work). Composing the two correspondences gives a chain *session types ↦ linear propositions ↦ quantale elements*. The architectural target reverses the chain: it treats the quantale as the primary algebraic object and derives the session-types layer as the syntactic shadow.

#### §I.2.2 Wadler: classical linear logic and CP/GV

Wadler's "Propositions as Sessions" [Wadler2012, Wadler2014] takes the same correspondence and reformulates it in *classical* linear logic, presenting two languages: CP (a process calculus) and GV (a linear functional language with session types), with a translation from GV into CP. CP has propositions of classical linear logic correspond directly to session types; cut elimination in CP corresponds to communication, and deadlock-freedom follows immediately from the strong normalisation of cut elimination. GV is a more conventional linear functional language with session-typed channels as primitive values; its translation into CP both formalises the correspondence with linear logic for a standard presentation of session types and shows that a small modification to the standard presentation (notably splitting the session-end type into dual variants `end!` and `end?`, and reformulating the channel-creation and forking primitives) yields a deadlock-free language.

The classical setting differs from the intuitionistic one in symmetry. Where DILL's two-sided sequents distinguish providers from consumers, classical linear logic uses one-sided sequents and treats `A` and `Aˆ⊥` as fully symmetric. This buys uniformity (every session type has a manifest dual; no left-side / right-side distinction is needed) at the cost of obscuring the provider/consumer asymmetry that Caires-Pfenning's typing rules track explicitly. Both formulations are widely used in the subsequent literature, with classical CP often preferred for theoretical work (because of its symmetry) and intuitionistic DILL often preferred for programming-language design (because the provider/consumer distinction matches programmer intent and supports natural modal extensions, e.g. shared sessions via `!`). Comparing-derived-systems literature [DerivedFromLL] surveys the relationship and the variant designs that have emerged.

The two correspondences — intuitionistic and classical — are not in tension. Both establish that the algebraic structure underlying session types is the structure of linear logic, and any semantic model of linear logic is a semantic model of session types. The quantale connection holds in both cases.

### §I.3 Polarisation, SILL, and the Pfenning-Toninho-Kavanagh program

The Caires-Pfenning interpretation as developed in [CairesPfenning2010, ToninhoCairesPfenning2013] is *synchronous*: each communication is a rendezvous between sender and receiver. Asynchronous communication is operationally important (and matches the message-buffer semantics of practical languages and distributed systems) but is not natively present in the synchronous formulation. Pfenning and Griffith's FoSSaCS 2015 paper [PfenningGriffith2015] resolves this by introducing *polarities* as an extension of the Caires-Pfenning system, presenting the language SILL.

The polarisation idea is borrowed from Andreoli's focusing in linear logic and from Girard's polarised classical logic. Each session type is classified as either *positive* (its outermost connective wants to be sent eagerly: `⊗`, `⊕`, `1`) or *negative* (its outermost connective wants to receive: `⊸`, `&`, `⊥`). Asynchronous shifts (sometimes written `↑` and `↓`) move between polarities, allowing a sender to pipeline outputs without waiting for the receiver and a receiver to buffer inputs until ready. The operational reading is that positive types are "send-eager" and negative types are "receive-eager", and the shift connective is the explicit synchronisation point between phases of opposite polarity. This is the load-bearing observation for the architectural target's claim that polarisation is what recovers asynchrony — the shift-connective marks where one party's progress can outrun the other, and *between* shifts asynchronous buffering is sound by construction.

SILL also unifies a *substructural* spectrum: linear, affine, strict, and unrestricted, all in one type system, with the same polarisation discipline applied to each. The substructural distinction matters because not every protocol resource is linear (some can be discarded, others must be used, and shared resources need a `!` modality), and a uniform polarisation framework lets these orthogonal axes interact cleanly. SILL integrates functional and message-passing concurrent programming through the deep connection between session-typed concurrency and linear logic, and is in Curry-Howard correspondence with intuitionistic linear logic. The system guarantees absence of deadlocks (global progress) and session fidelity (type preservation).

The Pfenning–Toninho–Kavanagh program continues this thread with further developments. Higher-Order Processes, Functions, and Sessions [ToninhoCairesPfenning2013ESOP] introduce a linear contextual monad that isolates session-based concurrency within a functional language, treating monadic values as open process expressions and first-class objects. This is the technical move that makes session-typed processes embedable in a higher-order functional setting without losing the linear-logic-based guarantees. Manifest Sharing [BalzerPfenning2017] extends the substructural framework with adjoint modalities between linear and shared layers, generalising Benton's LNL [Benton1995] and Reed's adjoint logic [Reed2009]. Pruiksma and Pfenning's adjoint-logic message-passing interpretation [PruiksmaPfenning2018] generalises standard binary session types with capabilities for multicast, replicable services, and cancellation in a uniform adjoint-logic framework, and DeYoung-Pfenning's semi-axiomatic sequent calculus (Sax) [DeYoungPfenning2020, GritsLanguage2024] provides a logical foundation that natively models asynchronous message-passing with shared-memory semantics weakly bisimilar to the standard message-passing semantics.

For the architectural target, polarisation prefigures the polynomial-functor view: a session type's polarity classifies whether the next interaction's "positions" are owned by the provider or the consumer, and a polynomial-functor model of session types makes this information structural rather than a side condition. Σ-types correspond to send-and-continue (the sender chooses a position from a small finite set, the dependent payload determines the continuation type), Π-types correspond to receive-and-continue (the receiver waits for any payload from a quantified family, with the continuation depending on the chosen value). This is exactly the Σ/Π adjoint pair in an LCCC, and polynomial-universe constructions [AwodeyHofmannStreicherSpivak] make it formal. The connection is implicit in SILL but becomes explicit in the dependent-session-types and session-coalgebras work below.

### §I.4 Dependent session types

Dependent session types extend session types so that the type of a continuation can depend on the value just received (or just sent). This is the move from simply-typed protocol descriptions ("send a list, then receive a number") to value-dependent ones ("send a list `xs`, then receive a number bounded by `length(xs)`"). The technical home for this extension is dependent type theory, and the linear-logic-correspondence framework extends naturally because linear logic admits dependent quantifiers (∀ and ∃ over types and over values).

Toninho-Caires-Pfenning's PPDP 2011 paper [ToninhoCairesPfenning2011] is the first development of this idea in the linear-logic-correspondence framework. The paper develops an interpretation of linear *dependent* type theory as session types for a term-passing extension of the π-calculus. Universal quantification ∀x:τ.A becomes "receive a value of type τ, continue as A with x bound", which is the dependent generalisation of the linear arrow. Existential quantification ∃x:τ.A becomes "send a value of type τ, continue as A with x bound", which is the dependent generalisation of tensor. The technique handles value-dependent properties, where data flowing through a session influences the protocol structure of the rest of the session. Caires-Toninho-Pfenning [ToninhoCairesPfenning2013] gives the journal-length development; the PPDP paper later received the 10-Year Most Influential Paper Award at PPDP 2021.

A subsequent line of work extends the dependent-session-types program. Toninho-Yoshida's "Depending on Session-Typed Processes" [ToninhoYoshida2018] develops a framework in which session processes depend on functions and vice-versa, internalising typed processes within a dependently-typed lambda calculus via a contextual monad. The framework establishes the now-canonical correspondence between Π/Σ types and type send/receive operations: receive-types are Π-types, send-types are Σ-types, and the dependent function-space and dependent-pair structure of the underlying type theory directly underwrites the protocol's value-dependence. "On Polymorphic Sessions and Functions" [ToninhoYoshida2018Poly] establishes mutually inverse fully-abstract encodings between a polymorphic session π-calculus and System F with linear types, providing algebraic representations in System F for inductive and coinductive session types and demonstrating strong normalisation. This is foundational for the architectural target's claim that "dependent types in continuation positions Just Work via Σ/Π adjoints" — the encoding shows the Σ/Π structure is *operationally* captured by send/receive primitives, with the linear-logic correspondence translating semantics on each side.

Practical inference for refinement extensions is the recent emphasis. Das-Pfenning's "Session Types with Arithmetic Refinements" [DasPfenning2020] extends session types with index refinements from linear arithmetic, capturing intrinsic attributes of data structures and algorithms. Type equality in the refined system is undecidable (despite Presburger arithmetic being decidable), motivating practical heuristics. Toninho-Yoshida's 2026 paper "Practical Refinement Session Type Inference" [ToninhoYoshida2026] develops a two-stage inference that strips refinements to solve structural type constraints (Stage 1) before delegating arithmetic constraint satisfaction to Z3 (Stage 2). The paper's three optimisations — *transitivity elimination* (an order-of-magnitude performance benefit by eliminating intermediate type variables before constraint solving), *polynomial templates* (representing expression variables as multivariate polynomials of bounded degree), and a *theory-of-reals fallback* (solving over real arithmetic before back-converting to integers) — are pragmatically necessary for Z3 to terminate on realistic protocols. Of these, transitivity elimination is the most striking from an architectural-target standpoint: it is a constraint-lattice operation (eliminating intermediate variables by transitively closing the subtyping relation) that bears directly on the architectural commitment that protocols compose by intersection in a constraint lattice. The technique generalises beyond inference to the conjunctive composition story.

The user's flagged "I haven't really explored what this means" point about dependent types in session continuation positions is precisely the territory mapped here. The technical answer — assembled from [ToninhoCairesPfenning2011, ToninhoYoshida2018, AwodeyHofmannStreicherSpivak] — is that the LCCC's Σ/Π adjoint pair, when restricted to the linear logical sub-LCCC, gives exactly the dependent send-and-receive primitives, with the polynomial-functor reading making the dependency structurally explicit. The pieces are all in the literature; the synthesis (and the move to multi-party via Π_r over participants) is the architectural-target's contribution.

#### §I.4.1 Polymorphic typestate

A complementary line, distinct from the continuation-passing-style of the linear-logic lineage but addressing the same expressivity goals, is polymorphic typestate. Saffrich and Thiemann's "Polymorphic Typestate for Session Types" (PPDP 2023, arXiv 2210.17335) [Thiemann2022] presents PolyVGR, a system in which higher-order polymorphism and existential types lift the restrictions of earlier typestate-based approaches and bring expressivity to parity with continuation-passing or channel-passing styles. The typestate paradigm "enables programmers to treat communication channels like mutable variables" rather than threading continuations explicitly. The metatheory establishes type preservation and progress; a prototype implementation is presented. The relevance for the architectural target is that typestate gives an alternative reading of the same underlying structure: a session is a (changing) state at a channel, and the type of the channel evolves with each operation. In the polynomial-functor view this maps cleanly onto coalgebraic state evolution: each operation is a transition step, the channel's type is its current state, and the protocol's possible futures are captured coinductively.

### §I.5 Session coalgebras

The categorical reformulation that bears most directly on the architectural target is Keizer-Basold-Pérez's "Session Coalgebras" program. The original ESOP 2021 paper [KeizerBasoldPerez2021] (often dated 2020 by the arXiv preprint 2011.05712) presents a syntax-free description of session-based concurrency as states of coalgebras for a particular signature on Set, and demonstrates that type equivalence, duality, and subtyping can be rediscovered as canonical coinductive presentations on the resulting coalgebras. The TOPLAS 2022 expanded version [KeizerBasoldPerez2022TOPLAS] generalises the framework to context-free session types and connects to automata-theoretic decidability for session-type equivalence — the latter point matters because, as Silva-Mordido-Vasconcelos [SilvaMordidoVasconcelos2023] survey, four points on the spectrum of infinite session types correspond to four classes of automata (finite-state, 1-counter, pushdown, 2-counter), and the coalgebraic framework abstracts uniformly over the choice point.

The coalgebra signature is constructed to capture the session-type structure: states are types (or, equivalently, channel-protocol states), transitions encode the possible interactions (send/receive a value, internal/external choice, recursion), and the coalgebra map sends each state to its possible-next-state structure indexed by the action. Internal choice (`A ⊕ B`) appears coalgebraically as a coproduct in the transition signature: from a state of type `A ⊕ B`, the transition emits a `⊕`-action and lands in either `A` or `B` (provider's choice). External choice (`A & B`) appears as a product — the consumer can demand either branch. Send (`!A.S`) emits an output action carrying a value of type `A` and lands in `S`; receive (`?A.S`) accepts an input action and lands in `S` after binding. Recursive types (`μX.S` and so on) are interpreted via greatest-fixpoint constructions, exactly the standard categorical construction of terminal coalgebras for the underlying functor.

The functor at issue is *polynomial* in the sense relevant for the architectural target: each transition step has positions (the choice of what action happens, drawn from a small set of action constructors) and directions (the data carried with that action, the participant identity in the multi-party case, and the continuation state). The coalgebra structure for sessions thus instantiates a polynomial-functor coalgebra in the sense of Awodey-Hofmann-Streicher-Spivak's polynomial-universe work. Duality is then the natural categorical operation: a coalgebra-morphism that swaps the role of provider and consumer at every state, equivalently a contravariant functor on the action-signature that exchanges send and receive (and `⊕` and `&`). Subtyping is the existence of a simulation morphism in the appropriate coalgebraic sense (with care for the asymmetry between input-positions, where supersets are sound, and output-positions, where subsets are sound) — Silva-Mordido-Vasconcelos work this out for the context-free case.

Three points are load-bearing for the architectural target:

(i) *The categorical and the proof-theoretic view agree.* Caires-Pfenning's linear-logic correspondence establishes session types as linear propositions; Keizer-Basold-Pérez's coalgebraic view establishes session types as coalgebra states for a polynomial functor. The two views are orthogonal — one is proof-theoretic (sequents and cuts), the other is denotational (states and transitions) — but both factor through the same algebraic substrate (a linear-logic phase semantics, equivalently a quantale-enriched category). The architectural target's claim that protocols are polynomial functors is the categorical view's natural generalisation; the linear-logic correspondence is the syntactic shadow.

(ii) *Behaviour is coalgebraic.* The operational semantics of a session-typed process *is* the unfolding of a coalgebra: the process at any time is at some state in its session type, the next interaction is a transition step, and the long-term behaviour is the coalgebra-orbit (greatest-fixpoint) characterisation. This is the architectural target's "behaviour as coalgebras for the polynomial functor" claim, in the binary case, with a complete categorical formalisation already present in the literature.

(iii) *Polynomial functors handle directions correctly.* The data carried with each action — the value sent, the choice tag for branching, the participant identity in the multi-party generalisation — appears as a *direction* of the polynomial functor at the chosen position. Operads, by contrast, present multi-input multi-output composition but collapse the direction structure into a single arity dimension. The architectural target's preference for polynomial functors over operads can be read here: session-type duality, value-dependent continuations, and (in the multi-party case) per-role views all live in the direction structure, so a framework that flattens directions loses essential information.

Bernardi-Hennessy's "Using higher-order contracts to model session types" [BernardiHennessy2016] is a complementary set-theoretic semantic model: contracts are higher-order, the meaning of a contract is the set of contracts with which it complies, and the construction is fully-abstract for recursive higher-order session types. The notion of "contract complement" replaces traditional duality and is argued to capture more faithfully the behavioural intuition; the methodological point matches the coalgebraic emphasis (canonical semantic invariants over syntactic equality classes) but the technical machinery differs.

### §I.6 Higher-order session types

Higher-order session types extend the session-type discipline to processes that send or receive *processes* (or equivalently, channels) as values. The first systematic study in the linear-logic correspondence framework is Toninho-Caires-Pfenning's "Higher-Order Processes, Functions, and Sessions: A Monadic Integration" [ToninhoCairesPfenning2013ESOP], which uses a linear contextual monad to isolate session-based concurrency within a functional language: monadic values are open process expressions, treated as first-class objects. The technical effect is that the function/process boundary becomes mediated by the monad, and standard functional reasoning (higher-order parameters, compositional abstraction, polymorphic let) interoperates cleanly with session-typed processes via monadic operations.

Outside the linear-logic correspondence, higher-order session types in the higher-order π-calculus (HOπ) have a long lineage. Mostrous-Yoshida's work on session typing and asynchronous subtyping for the higher-order π-calculus [MostrousYoshida] develops techniques for code mobility (sending closures over typed channels) and asynchronous permutation of session actions, leveraging the linear λ-calculus to control the linearity of received code. The technical difficulties compared to first-order sessions — linearity must be preserved across boundary crossings, and completion of sessions in transmitted code interacts with the host's session state — motivate the asynchronous-subtyping refinement.

Bernardi-Hennessy's contract model [BernardiHennessy2016] addresses higher-order session types from the contracts side: a recursive higher-order session type is given semantics as a higher-order contract (a contract whose negotiable content includes other contracts), with set-theoretic compliance giving the equivalence and the contract-complement giving duality. The fully-abstract result establishes that contract-equivalence is exactly behavioural equivalence on processes implementing the session types.

For the architectural target, the higher-order extension is structurally important for two reasons. First, the polynomial-functor framing handles process-passing via direction structure: a position in the protocol that "sends a process of session type S" has direction including S itself (a session type, an object in the appropriate category), and the LCCC's exponential / function-type / equivalently the linear arrow of the sub-LCCC absorbs this cleanly. The Σ/Π adjoint apparatus extends to session-typed payloads without modification because the categorical setting is already sufficiently rich. Second, the user's "compositional surprise" point about session types appearing in the continuation of another session type is exactly what higher-order session types capture, and what the polynomial-functor model treats uniformly: a continuation is a direction at a position, and there is no type-theoretic distinction between "value" and "session" at the categorical level — both are just objects of the LCCC. The apparent surprise is an artifact of presentations that distinguish value-passing from process-passing syntactically; the categorical view sees them as instances of the same construction.

### Cross-references and connections to neighbouring slices

The binary baseline established here feeds the multi-party slices in three ways. (i) For §II (classical MPST and the 2019 reckoning), the binary linear-logic correspondence provides the algebraic baseline that multi-party projection-with-merge attempts to replicate at scale; the incompatibilities §II diagnoses are essentially incompatibilities between the multi-party operational discipline and the binary-case algebraic structure recovered above. (ii) For §III (escape routes from projection-with-merge), the polarisation, dependent-session-types, and adjoint-logic refinements collected here are direct precedents for proposed alternatives. Coherence-as-multiparty-duality work [CarboneEtAl2016] explicitly extends Caires-Pfenning DILL to multi-party while preserving the linear-logic-correspondence guarantees, and is one of the clean technical alternatives to projection-with-merge; the binary case here is the foundation it generalises. (iii) For §IV (categorical / quantale / conjunctive foundations), the session-coalgebras program (§I.5) and the linear-logic / quantale-semantics connection (§I.2) are the binary-case precedents for the architectural target's polynomial-functor and quantale-enriched-category proposals. The companion async-research artifact's §3.1 already develops the quantale-as-target argument for asynchrony; the present section provides the session-types-side precedent and avoids duplicating that material.

A specific cross-reference for §III: the architectural target's claim that composition is conjunctive refinement (intersection in the constraint lattice) is, in the binary case, *already* the correct algebraic operation. Subtyping in session-coalgebras [SilvaMordidoVasconcelos2023] is a meet-like coinductive simulation; refinement in session-types-with-arithmetic-refinements [DasPfenning2020] is constraint conjunction; transitivity elimination in [ToninhoYoshida2026] is an explicit constraint-lattice operation. The multi-party generalisation §III argues for is therefore a faithful extension, not a novel construction.

### Annotated bibliography (Part I)

[Honda1993] Honda, Kohei. "Types for Dyadic Interaction." In CONCUR'93 (Best, ed.), LNCS 715, pp. 509–523. Springer, 1993. <https://link.springer.com/chapter/10.1007/3-540-57208-2_35>
> The origin of session types. Introduces a typed formalism for π-calculus where types denote freely composable structure of dyadic interaction in a symmetric scheme, with a typed bisimilarity result. Background for §I.1; the technical line continues through Honda-Vasconcelos-Kubo 1998 and the linear-logic correspondence.

[HondaVasconcelosKubo1998] Honda, K., Vasconcelos, V. T., and Kubo, M. "Language Primitives and Type Discipline for Structured Communication-Based Programming." In ESOP 1998, LNCS 1381, pp. 122–138. Springer, 1998. <https://link.springer.com/chapter/10.1007/BFb0053567>
> The first highly-cited dyadic system — introduces the now-standard primitives (channel creation, send/receive, branch/select, delegation) and an ML-like type discipline. Most subsequent extensions take this paper as their starting point. Direct background for §I.1.

[CairesPfenning2010] Caires, Luís, and Pfenning, Frank. "Session Types as Intuitionistic Linear Propositions." In CONCUR 2010, LNCS 6269, pp. 222–236. Springer, 2010. <https://doi.org/10.1007/978-3-642-15375-4_16>
> Load-bearing antecedent for the architectural target. Establishes the Curry-Howard correspondence between session types for the π-calculus and dual intuitionistic linear logic (DILL): propositions are session types, sequent proofs are typing derivations, cut is parallel composition, cut elimination is communication. Proves session fidelity, deadlock-freedom, and a tight bidirectional operational correspondence. The connective table this paper fixes (`⊗` ↦ send, `⊸` ↦ receive, `&` ↦ external choice, `⊕` ↦ internal choice, `!` ↦ shared) is used throughout the literature.

[ToninhoCairesPfenning2013] Toninho, Bernardo, Caires, Luís, and Pfenning, Frank. "Linear Logic Propositions as Session Types." Mathematical Structures in Computer Science 26(3): 367–423, 2016 (journal version of the 2013 development). <https://www.cambridge.org/core/journals/mathematical-structures-in-computer-science/article/abs/linear-logic-propositions-as-session-types/810338DAF92DDBDA77C95DEB12FD1057>
> Journal-length development of the Caires-Pfenning correspondence with the full DILL connective table, polymorphism, and a comprehensive treatment of the operational correspondence theorem. The reference for the intuitionistic side of the linear-logic-as-session-types programme.

[Wadler2012] Wadler, Philip. "Propositions as Sessions." In ICFP 2012, ACM, pp. 273–286, 2012. (Conference version; also <https://homepages.inf.ed.ac.uk/wadler/papers/propositions-as-sessions/propositions-as-sessions.pdf>)
> The classical-linear-logic counterpart to Caires-Pfenning. Introduces CP (a process calculus where propositions of classical linear logic *are* session types) and GV (a linear functional language with session-typed channels), with a translation GV → CP that establishes deadlock-freedom of GV via cut elimination in CP. The choice between intuitionistic (DILL) and classical (CP) framings is a methodological one; both establish the linear-logic correspondence equally rigorously.

[Wadler2014] Wadler, Philip. "Propositions as sessions." Journal of Functional Programming 24(2-3): 384–418, May 2014. <https://www.cambridge.org/core/journals/journal-of-functional-programming/article/propositions-as-sessions/0985539E5D607AC00FB00FF900BA1C86>
> The journal version of [Wadler2012] with full proofs. Established reference for the classical linear-logic correspondence and the GV → CP translation.

[Yetter1990] Yetter, David N. "Quantales and (Noncommutative) Linear Logic." Journal of Symbolic Logic 55(1): 41–64, 1990. <https://www.cambridge.org/core/journals/journal-of-symbolic-logic/article/abs/quantales-and-noncommutative-linear-logic/1808CA04372612BCB38E8D3A8B4CCCDB>
> Establishes that quantales (Mulvey 1986) provide the algebraic semantics for linear logic, treating multiplicative conjunction as quantale tensor and the linear arrow as the right adjoint. The architectural target's claim that "linear-logic-as-session-types lives natively in a quantale" routes through this paper. Combined with Caires-Pfenning's correspondence, it gives the chain *session types ↦ linear propositions ↦ quantale elements*. Companion async-research artifact's §3.1 develops the quantale side; this section provides the session-types end of the chain.

[PfenningGriffith2015] Pfenning, Frank, and Griffith, Dennis. "Polarized Substructural Session Types." In FoSSaCS 2015, LNCS 9034, pp. 3–22. Springer, 2015. <https://link.springer.com/chapter/10.1007/978-3-662-46678-0_1>
> Introduces the SILL language with polarities (positive vs negative) and substructural-spectrum unification (linear, affine, strict, unrestricted in one type system). The polarisation discipline is what recovers asynchrony — shifts (`↑`, `↓`) mark synchronisation points between phases of opposite polarity, allowing pipelined / buffered interaction within a phase. The architectural target's "Σ/Π adjoints in LCCC" recovery of dependent send/receive is anticipated by polarisation.

[BalzerPfenning2017] Balzer, Stephanie, and Pfenning, Frank. "Manifest Sharing with Session Types." Proceedings of the ACM on Programming Languages, ICFP 2017. <https://doi.org/10.1145/3110281>
> Extends substructural session types with adjoint modalities between linear and shared layers, generalising Benton's LNL [Benton1995] and Reed's adjoint logic [Reed2009]. Type-level prescription of acquisition and release points means sharing is *manifest* in the type structure. Trade-off: session fidelity preserved, but absence of deadlocks not — contention for shared processes can deadlock. Important precedent for the multi-party generalisation, where shared state across roles is a recurring challenge.

[PruiksmaPfenning2018] Pruiksma, Klaas, and Pfenning, Frank. "A Message-Passing Interpretation of Adjoint Logic." 2018; published version in JLAMP 2021. <https://www.cs.cmu.edu/~fp/papers/adjoint18.pdf>
> Generalises binary session types via adjoint logic to capture multicast, replicable services, and cancellation in a uniform framework. Asynchronous behaviour falls out of the polarised structure, anticipating the semi-axiomatic-sequent-calculus formulation of [DeYoungPfenning2020].

[DeYoungPfenning2020] DeYoung, Henry, et al. "Semi-Axiomatic Sequent Calculus." In FSCD 2020. <https://drops.dagstuhl.de/entities/document/10.4230/LIPIcs.FSCD.2020.29>
> Sax: blends sequent calculus with axiomatic intuitionistic logic. Cut elimination preserves the subformula property. Natural computational interpretation is asynchronous message-passing concurrency with shared-memory semantics weakly bisimilar to the message-passing one. Logical foundation for [GritsLanguage2024].

[GritsLanguage2024] Tabone, Gerard, Francalanza, Adrian, and Pfenning, Frank. "Implementing a Message-Passing Interpretation of the Semi-Axiomatic Sequent Calculus (Sax)." In COORDINATION 2024, LNCS 14676. <https://link.springer.com/chapter/10.1007/978-3-031-62697-5_16>
> Grits: a channel-based message-passing concurrent language based on Sax. Practical implementation of the asynchronous-message-passing-as-cut-reduction semantics.

[ToninhoCairesPfenning2011] Toninho, Bernardo, Caires, Luís, and Pfenning, Frank. "Dependent Session Types via Intuitionistic Linear Type Theory." In PPDP 2011, ACM, pp. 161–172, 2011. <https://dl.acm.org/doi/10.1145/2003476.2003499>
> First development of dependent session types in the linear-logic-correspondence framework. ∀ becomes "receive of dependent type", ∃ becomes "send of dependent type"; value-dependent properties on session continuations are expressible. Awarded PPDP's 10-Year Most Influential Paper at PPDP 2021. The reference for the architectural target's "dependent types in continuation positions Just Work" claim, alongside the Σ/Π adjoint structure made explicit in [ToninhoYoshida2018].

[ToninhoCairesPfenning2013ESOP] Toninho, Bernardo, Caires, Luís, and Pfenning, Frank. "Higher-Order Processes, Functions, and Sessions: A Monadic Integration." In ESOP 2013, LNCS 7792, pp. 350–369. Springer, 2013. <https://link.springer.com/chapter/10.1007/978-3-642-37036-6_20>
> A linear contextual monad isolates session-based concurrency within a functional language; monadic values are open process expressions and first-class objects. Higher-order session types and functional/process integration without losing linear-logic guarantees. Important for §I.6 and for the architectural target's compositional discipline.

[ToninhoYoshida2018] Toninho, Bernardo, and Yoshida, Nobuko. "Depending on Session-Typed Processes." In FoSSaCS 2018; arXiv 1801.08114. <https://arxiv.org/abs/1801.08114>
> Session processes depend on functions and vice-versa, internalised in a dependently-typed lambda calculus via a contextual monad. Pi/Sigma types ↔ type send/receive operations; the canonical reference for the Σ/Π-adjoints-as-dependent-send/receive identity that the architectural target leans on.

[ToninhoYoshida2018Poly] Toninho, Bernardo, and Yoshida, Nobuko. "On Polymorphic Sessions and Functions: A Tale of Two (Fully Abstract) Encodings." ESOP 2018 / arXiv 1711.00878. <https://arxiv.org/abs/1711.00878>
> Mutually inverse fully-abstract encodings between a polymorphic session π-calculus and System F with linear types. Provides algebraic representations in System F for inductive and coinductive session types and demonstrates strong normalisation. Foundational for transferring System-F-style polymorphism to session types and vice-versa.

[Thiemann2022] Saffrich, Hannes, and Thiemann, Peter. "Polymorphic Typestate for Session Types." In PPDP 2023, ACM; arXiv 2210.17335 (October 2022). <https://arxiv.org/abs/2210.17335>
> PolyVGR: typestate-based session types with higher-order polymorphism and existential types lifting earlier restrictions. Channels are treated like mutable variables (typestate paradigm) rather than threaded continuations; metatheory establishes type preservation and progress. Coalgebraic-style reading of the same underlying structure.

[DasPfenning2020] Das, Ankush, and Pfenning, Frank. "Session Types with Arithmetic Refinements." In CONCUR 2020. <https://drops.dagstuhl.de/entities/document/10.4230/LIPIcs.CONCUR.2020.13>
> Extends session types with index refinements from linear arithmetic. Type equality undecidable in general (despite Presburger being decidable); practical algorithms via Cooper's quantifier-elimination with heuristic extensions to nonlinear constraints. Foundation for the Rast language and its inference work.

[ToninhoYoshida2026] Ueno, Yoshiki, and Das, Ankush. "Practical Refinement Session Type Inference (Extended Version)." arXiv 2602.06715, February 2026. <https://arxiv.org/html/2602.06715>
> Two-stage Z3-based inference for refinement session types. Three optimisations are necessary in practice: (i) transitivity elimination (an order-of-magnitude Stage 1 speedup; eliminates intermediate type variables before constraint solving — a constraint-lattice operation directly relevant to the architectural target's "composition by intersection" claim), (ii) polynomial templates for arithmetic constraints (degree-1 in practice), (iii) theory-of-reals fallback. Stage 2 dominates runtime 100–1000× Stage 1; without all three optimisations Z3 times out on basic examples. Important demonstration that constraint-lattice approaches to session-type composition are practically realisable.

[KeizerBasoldPerez2021] Keizer, Alex C., Basold, Henning, and Pérez, Jorge A. "Session Coalgebras: A Coalgebraic View on Session Types and Communication Protocols." In ESOP 2021, LNCS 12648, pp. 375–404. Springer, 2021; arXiv 2011.05712 (November 2020). <https://arxiv.org/abs/2011.05712>
> Syntax-free description of session-based concurrency as states of coalgebras for a polynomial functor on Set. Type equivalence, duality, and subtyping are rediscovered as canonical coinductive presentations. Direct precedent for the architectural target's "behaviour as coalgebras for the polynomial functor" claim; the binary-case categorical foundation that the multi-party generalisation extends.

[KeizerBasoldPerez2022TOPLAS] Keizer, Alex C., Basold, Henning, and Pérez, Jorge A. "Session Coalgebras: A Coalgebraic View on Regular and Context-free Session Types." ACM TOPLAS 44(3), 2022. <https://dl.acm.org/doi/10.1145/3527633>
> Expanded TOPLAS journal version. Generalises to context-free session types; connects coalgebraic equivalence to automata-theoretic decidability classes (regular ↔ finite-state automata; context-free ↔ pushdown automata). The reference categorical-coalgebraic treatment of session types.

[SilvaMordidoVasconcelos2023] Silva, Gil, Mordido, Andreia, and Vasconcelos, Vasco T. "Subtyping Context-Free Session Types." In CONCUR 2023; arXiv 2307.05661. <https://arxiv.org/pdf/2307.05661>
> Subtyping for context-free session types via simple grammars and deterministic pushdown automata; characterises four points on the spectrum of infinite session types (finite-state, 1-counter, pushdown, 2-counter automata) with associated decidability/undecidability results. Important for understanding the algorithmic boundary the polynomial-functor / coalgebraic framework operates within.

[BernardiHennessy2016] Bernardi, Giovanni, and Hennessy, Matthew. "Using higher-order contracts to model session types." Logical Methods in Computer Science 12(2), 2016 (arXiv 1310.6176, conference version CONCUR 2014). <https://lmcs.episciences.org/1642>
> Higher-order web-service contracts as a fully-abstract semantic model for recursive higher-order session types. The meaning of a contract is the set of contracts with which it complies; "contract complement" replaces traditional duality with a more behaviourally faithful operation. Set-theoretic; complementary to the coalgebraic approach.

[MostrousYoshida] Mostrous, Dimitris, and Yoshida, Nobuko. "Session typing and asynchronous subtyping for the higher-order π-calculus." Information and Computation 241: 227–263, 2015 (with earlier conference versions). 
> Higher-order π-calculus session typing with asynchronous subtyping for permutation of session actions and code mobility. Linearity preserved across boundary crossings via linear-λ-calculus techniques. The reference for HOπ session types outside the linear-logic-correspondence framework.

[CarboneEtAl2016] Carbone, Marco, Lindley, Sam, Montesi, Fabrizio, Schürmann, Carsten, and Wadler, Philip. "Coherence Generalises Duality: A Logical Explanation of Multiparty Session Types." In CONCUR 2016. <https://drops.dagstuhl.de/entities/document/10.4230/LIPIcs.CONCUR.2016.33>
> Generalises Caires-Pfenning DILL / Wadler CP from binary to multi-party by replacing duality with *coherence* (a multi-party invariant). One of the technically clean alternatives to projection-with-merge for multi-party session types. Cross-reference to §III's escape routes from projection-with-merge — included here because it directly extends the binary linear-logic correspondence rather than introducing new machinery.

[Benton1995] Benton, P. N. "A Mixed Linear and Non-Linear Logic: Proofs, Terms and Models." In CSL 1994 (proceedings 1995), LNCS 933, pp. 121–135. Springer.
> LNL: the original adjoint construction between linear and intuitionistic logic. Cited here as the antecedent for [BalzerPfenning2017]'s manifest-sharing extension.

[Reed2009] Reed, Jason. "A Judgmental Deconstruction of Modal Logic." Manuscript, 2009. (Often cited as the formative reference for adjoint logic.)
> Adjoint-logic foundations on which [PruiksmaPfenning2018] and [BalzerPfenning2017] build.

[DerivedFromLL] van den Heuvel, Bas, and Pérez, Jorge A. "Comparing session type systems derived from linear logic." Journal of Logical and Algebraic Methods in Programming, ScienceDirect, 2024. <https://www.sciencedirect.com/science/article/pii/S2352220824000580>
> Survey-style comparison of intuitionistic vs classical linear-logic-derived session-type systems. Useful for sorting through the variants and the relationships between them. Extended treatment in the same authors' arXiv 2401.14763.

[AwodeyHofmannStreicherSpivak] Awodey, Steve, Hofmann, Martin, Streicher, Thomas, and Spivak, David — referenced in the briefing as the "polynomial-universes work." The relevant references include Awodey's "Natural models of homotopy type theory" (MSCS 2018), Spivak's "Polynomial Functors: A General Theory of Interaction" lecture notes, and Hofmann–Streicher's polynomial-universe constructions; cited here for the LCCC Σ/Π adjoint apparatus that the architectural target leans on. Full citation development is the responsibility of slices §III–§IV.

---

## Part II — Classical MPST and the 2019 Reckoning: A Diagnostic of Projection-with-Merge

### II.1 Classical MPST: the projection-with-merge architecture

Classical multiparty session type theory was launched by Honda, Yoshida, and Carbone in their POPL 2008 paper *Multiparty Asynchronous Session Types* [Honda-Yoshida-Carbone 2008] and consolidated in the journal version published eight years later in the *Journal of the ACM* [Honda-Yoshida-Carbone 2016]. The framing was deliberately ambitious: take Honda's binary session-type discipline — which describes a two-party communication protocol as a pair of dual types, one per endpoint — and lift it to *n*-party asynchronous interactions. The lifting introduces an additional artifact: instead of writing two dual local types, the architect specifies a single *global type* G that describes all interactions among all roles, and then derives each participant's *local type* `L_r` by *projecting* G onto role r. The advertised payoff is that the global type plays the role of "a shared agreement among communication peers" and serves as "a basis of efficient type checking through its projection onto individual peers" [Honda-Yoshida-Carbone 2016, abstract]. The local types, in turn, are used to type-check each participant's process P_r in isolation; if every P_r is well-typed against its projected `L_r`, communication safety, progress, and session fidelity follow for the composed system.

This architecture became the dominant template for over a decade of subsequent research. Its features can be unpacked into four interlocking pieces.

The first piece is the *global type* itself. Global types are syntactic objects with three operative constructors: a sequential message-passing form `p->q : ⟨U⟩.G'` (role *p* sends a value of type *U* to role *q*, then the protocol continues as G'), a branching form `p->q : {l_i : G_i}_{i ∈ I}` (role *p* offers role *q* a choice from a labeled set, with continuation depending on the chosen label), and a recursion form `μt.G` (looping behavior). The intent is that every legal protocol-level behavior — every exchange of messages, every conditional choice, every iteration — corresponds to a syntactic substructure of G, and the *order* of operations in the protocol corresponds to the textual order in the global type.

The second piece is *projection*. Projection is a recursively-defined function `G ↾ r` that walks the global type and produces a local type for role *r*. For sequential message exchanges, projection is straightforward: if the message is *p→q*, then `(p→q : ⟨U⟩.G') ↾ p` yields `q!⟨U⟩.(G' ↾ p)` (a *send* action), `(p→q : ⟨U⟩.G') ↾ q` yields `p?⟨U⟩.(G' ↾ q)` (a *receive* action), and for any third role r ∉ {p, q}, projection just descends into G'. Recursion projects pointwise. The hard case, the case that has caused all the trouble for two decades, is *branching*. When `G = p→q : {l_i : G_i}_{i ∈ I}`, the projections for *p* and *q* are well-defined — *p* internally chooses a label and sends, *q* externally offers all labels and receives — but for any other role *r* not directly involved in the choice, what is `r`'s local behavior? Each branch G_i prescribes a different continuation; *r* has not seen the chosen label, so cannot syntactically branch on it; yet the protocol demands that *r* nonetheless behave consistently with whichever G_i was selected.

The third piece is the *merge operator*. Merge is the partial operator that "fixes" the branching projection problem. The intent is that for an uninvolved role *r*, the projection `(G_i ↾ r)` for each branch must be reconciled into a single local type that *r* can execute regardless of which branch the choice resolved to. In the original Honda-Yoshida-Carbone formulation — the *plain merge* — this requirement is enforced syntactically: the projection `(p→q : {l_i : G_i}_{i ∈ I}) ↾ r` is *only* defined if `(G_i ↾ r) = (G_j ↾ r)` for every i, j ∈ I; that is, if the projections coincide on all branches. If they do not coincide, projection is *undefined*, and the global type is rejected as "non-projectable." The phrase "plain merge" came later — the original paper did not need a name because there was only one notion of merge.

A weakness of plain merge was recognized almost immediately: it rejects too many natural global types. If role *r* receives a message from *q* in every branch, but the *label* of the received message differs across branches, plain merge fails because `(G_1 ↾ r) ≠ (G_2 ↾ r)` (they offer different labels). Yet operationally there is no problem: *r* could simply offer *both* labels via external choice, and the runtime would deliver whichever the protocol selected. This observation gave rise to *full merging* [Yoshida-Mostrous-Honda 2009 ESOP and successors]: an extension of merge that allows two input-choice (branching) types from the same role with disjoint labels to be combined into a single input type offering both options. Full merge is genuinely more expressive: it admits global types that plain merge rejects, while preserving (it was claimed) all the safety properties of the framework.

The fourth piece is *type-checking*. Each process P_r is type-checked against its local type `L_r = (G ↾ r)` using a relatively standard type system for the multiparty session π-calculus. The type system enjoys subject reduction (Theorem: if Γ ⊢ P and P → P', then Γ' ⊢ P' for some Γ' that the typing context reduces to) and progress (Theorem: well-typed processes do not deadlock). Composition is *postulated* to be correct: if every P_r is well-typed against `(G ↾ r)`, then the parallel composition `P_1 | P_2 | ... | P_n` realizes the global protocol G, and the safety properties lift from local typing to global behavior.

The early literature elaborated this architecture in many directions: asynchronous communication subtyping for binary sessions [Mostrous-Yoshida-Honda 2009], parameterized multiparty sessions [Yoshida-Deniélou-Bejleri-Hu 2010], global progress under dynamic interleaving [Coppo-Dezani-Padovani-Yoshida 2016], deconfined / asynchronous global types [Castagna-Dezani-Padovani 2012; Dagnino-Giannini-Dezani 2021], and many more. The general impression in the community was that the foundations were settled — projection-with-merge was the "canonical" construction, and research had moved on to extensions and applications. This impression turned out to be wrong.

### II.2 The 2019 reckoning — Scalas-Yoshida and the broken-proofs cascade

In January 2019, Alceste Scalas and Nobuko Yoshida — Yoshida being one of the original authors of the 2008 framework — published *Less is More: Multiparty Session Types Revisited* in *Proceedings of the ACM on Programming Languages* (POPL 2019) [Scalas-Yoshida 2019]. The paper's abstract characterized its contribution in unusually direct language: "After 10 years from the birth of MPST, we discover that the proofs of type safety in the literature which use the end-point projection with mergeability are flawed." This was not a pedantic correction or a sharpening of an existing proof; it was the assertion that a substantial body of published work — including foundational papers in the area — had carried subject-reduction proofs whose key inductive steps did not in fact go through.

The paper's framing is worth quoting at length. Scalas and Yoshida write that "classic MPST have a limited subject reduction property, with inherent restrictions that are easily overlooked, and in previous work have led to flawed type safety proofs; the new theory removes such restrictions and fixes such flaws" [Scalas-Yoshida 2019]. They contribute a replacement theory: "a new MPST theory that is less complicated, and yet more general, than the classic one: it does not require global multiparty session types nor binary session type duality — instead, it is grounded on general behavioural type-level properties." The reframing is dramatic: rather than repair the projection-with-merge mechanism, the new theory simply *abandons* the global type as a load-bearing construct, replacing it with a behavioral-safety invariant on local typing contexts. The title's "Less is More" refers to having less infrastructure (no global types, no merge) and getting more results (more typeable protocols).

The technical anatomy of *where* the proofs broke is more delicate than the abstract suggests, and was not fully clarified until five years later in the follow-up *Less is More Revisited: Association with Global Protocols and Multiparty Sessions* by Hou, Yoshida, and Kuhn [Hou-Yoshida-Kuhn 2024]. Drawing on both papers, the diagnosis is as follows.

The standard subject reduction theorem in MPST has the shape: "if process P has typing context Γ, and Γ satisfies invariance property φ, and P reduces to P', then P' has typing context Γ' that also satisfies φ." The invariance property φ is the load-bearing piece — it must be preserved by reduction (otherwise the induction fails on the next step) and it must be strong enough to imply communication safety. In the classical MPST literature, the invariance property is *consistency*: Γ is consistent if it arises as the projection of some well-formed global type G, with the local types in Γ aligned to each other branch-by-branch through the projection mechanism. Under *plain* merge, consistency is preserved by reduction, because plain merge enforces that uninvolved roles see *identical* local types across all branches — so there is nothing to fall out of alignment. The branches of the global type, when projected onto any uninvolved role, yield the same local type, and reductions of the typing context simply step that local type forward in lockstep with the chosen branch.

Under *full* merge, this alignment fails. The Hou-Yoshida-Kuhn 2024 paper makes the failure explicit: "Plain merging enforces structural alignment of local types — sharing the same labels, payloads, and mergeable continuations" so that "projection yields consistent local types, which are preserved under reduction. However, this guarantee does not extend to full merging: full merging admits inconsistent local types, thereby violating (SR3)" [Hou-Yoshida-Kuhn 2024], where (SR3) is the invariance step of subject reduction. The reason is structural: full merge allows uninvolved roles to have *different* projected behaviors in different branches, as long as the differences can be reconciled by combining input choices with disjoint labels. But the *continuations* of those branch-dependent behaviors can themselves involve other roles, and after a few reduction steps, what was syntactically aligned at the top of the global type can fall out of alignment in the typing context. The induction step that needed "Γ remains consistent" no longer holds — Γ becomes inconsistent in a way that the proof's invariant cannot tolerate.

The Hou-Yoshida-Kuhn paper identifies four specific sources where this gap manifests as broken proofs: parameterized multiparty session types [Yoshida-Deniélou-Bejleri-Hu 2010], multiparty session types meeting communicating automata [Deniélou-Yoshida 2013], lightening global types [Castro-Hu-Honda-Yoshida and successors], and certifying data in multiparty session types [Voinea-Dardha-Gay 2016]. In each case the published subject-reduction proof appeals (often implicitly) to consistency-preservation under full merge, and the appeal does not in fact go through. The proof structure is approximately the same in each — only the pre- and post-states of the reduction differ — so the failure is a single shape recurring across the literature, not multiple independent oversights.

A second, subtler failure mode was articulated by the Scalas-Yoshida paper itself: even where consistency *can* be patched by adding side-conditions, the additional restrictions partially undo the expressiveness gains that motivated full merge in the first place. Quoting the synthesis search result that paraphrases the paper: "Subject reduction depending on 'full merging' do not work; they might fix such proofs by adding a consistency requirement — but then, they would fall back into earlier problems" [Scalas-Yoshida 2019, paraphrase]. In other words, the choice was framed in 2019 as a dilemma: either accept plain merge and reject many natural global types, or accept full merge and lose the soundness proofs. Scalas and Yoshida's response was the third-way move of abandoning the projection-with-merge architecture entirely.

The community's reaction was, and remains, substantively unsettled. A subsequent line of work — including the *Generalised Multiparty Session Types with Crash-Stop Failures* paper [Barwell-Scalas-Yoshida-Zhou 2022 CONCUR] and the *Less is More Revisited* paper [Hou-Yoshida-Kuhn 2024] — has argued that the original projection-with-merge proofs *can* be repaired, but only by replacing the consistency invariant with a new invariant called *association*. Hou-Yoshida-Kuhn explicitly position their work as a repair of the 2019 diagnosis: they aim to show that "a sound typing system can indeed be built using end-point projection with mergeability," and that interpretations claiming "the top-down approach itself was problematic" went too far [Hou-Yoshida-Kuhn 2024]. The 2024 paper posts to arXiv [Hou-Yoshida-Kuhn 2024] state that they are "clarifying certain misunderstandings and challenges surrounding type soundness proofs in the MPST community" — language which reveals that the misunderstandings and challenges remain ongoing, not resolved.

Independently, an entire parallel research thread argues that the projection mechanism itself, not merely its proof technique, is structurally the wrong mechanism — see §II.3 below. So the 2019 reckoning did not produce a single canonical "fix." It produced (i) a complete replacement theory that drops global types [Scalas-Yoshida 2019], (ii) a repair that keeps global types but replaces consistency with association as the proof invariant [Hou-Yoshida-Kuhn 2024], and (iii) a separate research program that abandons syntactic projection altogether in favor of automata-theoretic synthesis [Stutz-Wies and successors, see §II.3]. The community has not converged on any one of these.

### II.3 Where projection-with-merge breaks down technically

The diagnosis of §II.2 was about proofs — what mathematical machinery is sound, and where prior versions of it fail. A separate, partially overlapping diagnosis is structural: projection-with-merge is the wrong shape of mechanism, regardless of whether one can prove it sound. The most explicit articulation of this view is in the CAV 2023 paper *Complete Multiparty Session Type Projection with Automata* by Li, Stutz, Wies, and Zufferey [Li-Stutz-Wies-Zufferey 2023], whose framing illuminates what is structurally wrong with merge.

Three claims from the CAV 2023 paper are load-bearing for the structural critique. The first is the bottom-line assessment of the prior literature: "Existing practical projection operators for MSTs are all incomplete (or unsound)" [Li-Stutz-Wies-Zufferey 2023, introduction]. This is not a claim about a particular proof but about the operators themselves: every projection operator that has been deployed in tooling either rejects implementable global types (incomplete) or produces local types that fail to compose into a system realizing the global behavior (unsound). The completeness/efficiency/soundness trilemma is genuine: one can pick at most two.

The second is the structural diagnosis of *why* this is so: "Existing projection operators are syntactic in nature, and trade efficiency for completeness." The phrase "syntactic in nature" is doing real work. It means the operator computes by walking the global type top-down and emitting one local-type fragment per global-type fragment, with the implementation "for each role obtained via a linear traversal of the global type, and thus shar[ing] its structure." Branches in the global type become branches in the local type. Sequential composition becomes sequential composition. Recursion becomes recursion. The local type is, structurally, a syntactic erasure of the global type retaining only the events involving that role, with some merge-fixup at branch points where the role is uninvolved. This is exactly what "structurally similar" means and exactly the wrong shape for the protocols that arise in practice.

The third claim is the worked counterexample: the *odd-even protocol* (Example 1 in the paper). Three roles *p*, *q*, *r* are present. Role *q* sends some number of messages to *r*; the parity of the total number of messages communicates the choice that *p* made at the top of the protocol. Role *r* must, at the end, react differently depending on the parity. From *r*'s point of view, the implementation is straightforward: count incoming messages, and at termination dispatch on parity. But this implementation has "transitions going back and forth between the two branches that do not exist in the global type. Syntactic projection operators fail to create such transitions" [Li-Stutz-Wies-Zufferey 2023]. The role's local automaton has a structure — a counter, a parity check, alternating states — that is not a syntactic substructure of the global type. The implementation is correct, the global type is implementable, but no syntactic projection-with-merge can produce the local type, because the local automaton is not a structural erasure of the global syntax tree.

This generalizes. Whenever a role's correct implementation requires *information not directly visible to that role* — e.g., must be inferred from message timing, parity, count, sender identity, or accumulated payload state — the local automaton acquires structure that is absent from the global type. Syntactic projection cannot produce such automata; merge cannot reconcile it post-hoc, because there is no syntactic substructure to merge over. The CAV 2023 authors' summary is: "We posit that what needs rethinking is not the concept of global types, but rather how projections are computed and how implementability is checked" [Li-Stutz-Wies-Zufferey 2023]. This is the structural diagnosis that the 2019 proof-correctness reckoning is shadowing.

The technical core of the structural diagnosis can be stated as a property of the merge operator. Merge, in the classical formulation, has three failures of being a proper lattice operation:

- It is *partial*. There exist pairs of local types that have no merge — projection of branching where uninvolved roles disagree in ways neither plain nor full merge can reconcile. A genuine lattice operation is total within its domain; merge is not total within the domain it claims to inhabit.
- It is *not associative in any useful sense*. Merge of three branches is computed pairwise; the result depends on parenthesization in cases where the merge of one pair is undefined while the merge of a different pair (over the same three operands) might be defined. A genuine join-semilattice operation is associative.
- It has *no clean idempotent / unit structure*. There is no canonical "empty local type" that merges with anything to itself. The bottom element of a lattice corresponds to "no information," but in the projection setting this would correspond to a role that is uninvolved at all branches, which is not generally a well-formed local type.

These three failures are the algebraic core of the brittleness. Merge is not a join in any meaningful sense; it is an *ad hoc partial operation that pretends to be a join*. When it succeeds, type safety follows; when it fails (or when it succeeds in a way the proofs cannot certify), the framework does not gracefully degrade — it simply rejects the protocol as non-projectable, even when the protocol is implementable. The CAV 2023 paper's phrasing — "incomplete or unsound" — is the operational consequence of this algebraic deficiency. There is no lattice-theoretic operator whose properties projection-with-merge approximates; there is only the operator's syntactic behavior, and the safety theorems are stitched on around it.

A deeper consequence, only partially recognized in the literature, is that the merge step embodies a fundamentally non-compositional move. Composition of communicating processes should mean: combine local behaviors and *check* the combined behavior against a specification. Projection-with-merge inverts this: start from a specification, *generate* local behaviors, and rely on the generation to be correct-by-construction. The generation step uses merge to reconcile the views that the *single* global specification produces when seen from different roles' perspectives. The merge operator is doing "view reconciliation," and its partiality is a symptom that the views do not always reconcile — that is, that not every well-formed global specification factors as the conjunction of well-formed role views. This sets up the multiple-inheritance analogy made precise in §II.4.

### II.4 The OO-inheritance diagnostic

The structural critique of §II.3 has a precise analog in object-oriented programming: the diamond problem in multiple inheritance. The analogy is not metaphorical; it is exact in its algebraic shape. This subsection makes the analogy precise and draws the consequence that points the way out of the projection-with-merge architecture.

#### The structural correspondence

Consider the diamond inheritance pattern: a class A defines methods, classes B and C each inherit from A and override some of A's methods, and a class D inherits from both B and C. The question is: when D invokes an inherited method m, whose definition runs — A's, B's, or C's? In OO terms, this is "method resolution"; in algebraic terms, it is the question of how to combine the three views (A's, B's-inheriting-from-A, C's-inheriting-from-A) into a single coherent definition for D. There are multiple inheritance paths to the common ancestor A, each producing a different specialized view; D's behavior must reconcile them.

Now consider the MPST diamond: a global type G defines a protocol, and its projections `G ↾ p`, `G ↾ q`, `G ↾ r` are three local-type "specializations" — each role's view of the protocol. Type-checking each P_r against `G ↾ r` and composing P_1 | P_2 | P_3 is supposed to realize G. If G has a branch where roles p and q decide between behaviors but r is uninvolved, the projections `G_1 ↾ r` and `G_2 ↾ r` may be different views — *r*'s behavior in branch 1 differs from *r*'s behavior in branch 2. The merge operator's job is to combine these views into a single local type for *r* that *r* can execute regardless of which branch was selected. This is exactly the same shape of problem as method resolution in the diamond: multiple views derived from a single shared parent specification, requiring reconciliation into a single coherent local definition.

The correspondence table makes the analogy explicit:

| MPST element | OO multiple-inheritance element |
|---|---|
| Global type G | Superclass A (single source of truth) |
| Roles r ∈ G | Subclasses B, C, ... (specializations) |
| Projection `G ↾ r` | Method table inherited at class B (specialized view of A) |
| Branch in G where r is uninvolved | Method m in A overridden differently in B and C |
| Merge of branch projections at role r | Method resolution (MRO linearization) at D |
| "Non-projectable" global type | "Cannot resolve method" inheritance error |
| Plain merge (identical branches required) | Inheritance with no overrides allowed in the diamond |
| Full merge (disjoint labels combinable) | Inheritance with limited override reconciliation |

Each row is structurally tight, not just suggestive. The algebraic source of the difficulty is the same: a single source of truth (G or A) is *projected* into multiple specialized views (`G ↾ r` or B/C inheriting from A), and those views must be *reconciled* (merge or MRO) when they diverge. The reconciliation operator is the load-bearing piece. Its failure modes determine what the framework can express.

#### Why MRO and merge share a defect: ad-hoc reconciliation

In OO, the reconciliation operator is *method resolution order* (MRO). The most principled MRO is C3 linearization, used by Python and several other languages. C3 has good properties: it preserves the local order of declared bases, it preserves the order of each base's own MRO, and it produces a deterministic linear order whenever one exists. But C3 is *ad-hoc in a precise technical sense*: it makes choices that are not algebraically forced. Specifically, C3 chooses depth-first traversal of bases (rather than breadth-first), left-to-right traversal of declared bases (rather than right-to-left), and last-occurrence deduplication (rather than first-occurrence). Each of these choices is defensible, but each could be different — and other languages do make different choices. The choices are conventions that produce a deterministic answer; they are not algebraic necessities derivable from the inheritance relation itself.

This is precisely the same shape of defect as the merge operator in MPST. Plain merge requires identical projections; full merge allows disjoint-label combination; "extended" merges in subsequent literature allow further conventions. Each of these is a *choice* about how to reconcile views that the global type's projection produces, and each choice is defensible, but none is algebraically forced by a lattice or category-theoretic invariant. There is no notion of "the canonical merge" in the way there is, for example, "the canonical product" or "the canonical join." Merge is the projection-side analog of MRO: an ad-hoc partial reconciliation operator that delivers a deterministic answer when it can, and fails when it cannot.

In OO this defect is widely recognized. The "diamond of death" is taught in introductory OO courses precisely because every language deals with it differently and most deal with it badly. The remedy in modern language design — heavily influenced by the Schärli, Ducasse, Nierstrasz, and Black trait paper [Schärli et al. 2003] — has been to abandon multiple inheritance in favor of *trait composition*, where traits are stateless units of behavior that compose by *symmetric* operators. Trait composition is commutative, associative, and idempotent on the algebra of method sets — it is, in effect, a join-semilattice operation on behaviors. The Schärli et al. paper makes this explicit: "A benefit of the trait model is that composition is commutative and associative, which ensures that the order of composition is irrelevant" [Schärli-Ducasse-Nierstrasz-Black 2003]. In other words: traits restored an actual lattice operation in place of MRO's ad-hoc partial linearization. Conflicts must be resolved *explicitly* by the composing client — not silently by an ordering convention — but the underlying composition is algebraically clean.

This is the move the MPST literature has *not yet made*. The 2019 reckoning observed that merge-based proofs were broken; the 2023 CAV work observed that syntactic projection is incomplete; the 2024 *Less is More Revisited* paper observed that the proofs can be repaired with a new invariant. None of these works ask whether the projection mechanism itself — the analog of multiple-inheritance MRO — should be replaced with a structurally-clean composition operator analogous to trait composition. The question has been: how do we save merge? Not: should we be merging at all?

#### The conjunctive-refinement alternative

The OO-inheritance diagnostic suggests a structurally clean alternative to projection-with-merge, drawn from the same source as the trait remedy: *composition by conjunctive refinement of constraints*, the move that logic programming made over four decades ago.

In Prolog and its dialects, the composition of two clause bodies with overlapping subject is conjunction. If clause C_1 says `p(X) :- q(X), r(X)` and clause C_2 says `p(X) :- q(X), s(X)`, the predicate p(X) is the *disjunction* of clauses (alternative ways to satisfy p), and each clause body is the *conjunction* of subgoals (constraints that must simultaneously hold). Composition by conjunction has the algebraic properties trait composition has: commutative, associative, idempotent. It is a meet operation in the lattice of constraint sets. Two clause bodies merge by simply taking their conjunction; there is no question of "what order do the constraints apply" because conjunction is order-independent.

The implication for protocol composition is direct. Instead of starting from a global type G and *projecting* it into role views (which then require reconciliation by merge), one starts from each role's constraints — the local behaviors that role exhibits — and *composes* them by conjunction. The global behavior is the conjunction of local behaviors; the local behavior of any given role is a constraint set; participation of a role in a protocol is the *intersection* (in the lattice of constraint sets) of the role's various commitments. There is no projection step. There is no view to reconcile. There is no merge operator to be partial.

The Prologos project's bundle / trait system already embodies this move at the level of trait composition: bundles are conjunctive refinements over trait constraints, composed by Galois meet, and the bundle algebra is commutative-associative-idempotent. The structural argument of the present synthesis is that *the same move applies at the protocol level*. A multi-party protocol should not be specified as a single global type and projected — it should be specified as a conjunction of local role behaviors, with composition by conjunctive meet. This is the structural correspondence: traits replaced multiple-inheritance MRO with composition-by-conjunction; conjunctive role specifications replace projection-with-merge with composition-by-conjunction.

The user's diagnostic intuition formulated this exactly: "[my] intuition using Prolog for over a decade tells me that composition is trivial using logical conjunctives for refinement." The intuition has a precise formal counterpart. Conjunction is the meet operation on constraint sets; constraint sets form a lattice; meet is total, commutative, associative, idempotent, and has a top element (true) and bottom element (false). This is a join-semilattice (and in fact a full lattice with the right structure), and it is precisely the structure that *both* multiple-inheritance MRO *and* MPST merge fail to be. Composition by conjunctive refinement is not just a "different" approach; it is the structurally-correct algebraic answer to the question that MRO and merge are partial answers to.

#### Why this matters for the synthesis

The OO-inheritance diagnostic does two things simultaneously. First, it explains *why* current MPST projection-with-merge keeps producing brittle proofs: it is structurally the same shape of operator as MRO, and MRO has been known for decades to be ad-hoc and to require linearization conventions that are not algebraically forced. The 2019 reckoning's "broken proofs cascade" is the protocol-level instance of the diamond problem's "method resolution ambiguity." The fact that the cascade keeps happening — that successive papers keep finding new gaps requiring new repairs — is precisely the symptom one would expect when the underlying operator is not a proper lattice operation.

Second, it explains *why* the polynomial-functor / conjunctive-refinement alternative pursued by this synthesis is structurally sound: it replaces projection-with-merge with composition-by-conjunction, which *is* a proper lattice operation (in fact a Galois meet). The same move that resolved multiple inheritance in the OO world — replacing inheritance + MRO with traits + symmetric composition — applies at the protocol level: replace global types + projection + merge with role-local behaviors + conjunctive refinement. The diagnosis and the prescription are linked: the projection-with-merge architecture is brittle for the same algebraic reason that MRO is brittle, and the remedy is the same — replace the partial reconciliation operator with a total symmetric composition operator.

This is the load-bearing claim of this slice. The 2019 reckoning showed the proofs were broken. The 2023 CAV work showed the operators were incomplete or unsound. The OO-inheritance diagnostic shows *why* — because the operators are doing the same structural job that MRO does in OO, and MRO is also broken for the same algebraic reason. The polynomial-functor / conjunctive-refinement architecture is the protocol-level instance of the trait-composition remedy. The user's "code smell" intuition was correct, and it can now be made precise: projection-with-merge is multiple-inheritance MRO at the protocol level, and trait composition replaces both at once.

### II.5 The 2024 "Less is More Revisited" repair (light treatment)

The most direct attempt to repair the projection-with-merge architecture while keeping it intact is the 2024 paper *Less is More Revisited: Association with Global Protocols and Multiparty Sessions* by Hou, Yoshida, and Kuhn [Hou-Yoshida-Kuhn 2024]. The paper's stated motivation is to reverse what they characterize as a misunderstanding in the community following the 2019 paper: the inference that "the top-down approach (with mergeability) is unsound" or that "global types are problematic" [Hou-Yoshida-Kuhn 2024].

Their technical contribution is the *association* relation — an alternative invariant that replaces consistency in the subject-reduction proof. Where consistency requires that local types in the typing context arise as exact projections of a global type with branch-aligned views, association requires only that the global type and the typing context are related "via subtyping" — that is, the local types may *safely conform* to the global protocol rather than being its exact projection. The paper proves that association is preserved under reduction even in the full-merge setting, recovering subject reduction without the consistency restriction.

The repair is technically sound (within the scope it claims) and is positioned as resolving the 2019 problem while preserving the projection-with-merge architecture. From the perspective of this synthesis, however, two observations are relevant. First, the repair is reactive: it patches a specific failure mode of a specific proof, but does not address the structural critique of §II.3 — that the *operator itself* is incomplete or unsound, regardless of which invariant is used to prove it sound. The 2023 CAV result that "existing practical projection operators are all incomplete (or unsound)" is unaffected by the association repair. Second, the repair retains the projection-with-merge architecture, and therefore retains the OO-inheritance defect identified in §II.4. The community position remains active: there is ongoing controversy about what the correct foundations are, and which of the three responses to the 2019 reckoning — Scalas-Yoshida's replacement theory, Hou-Yoshida-Kuhn's association repair, or the automata-theoretic projection of Stutz et al. — should be the canonical foundation.

A neighboring repair attempt is *Generalised Multiparty Session Types with Crash-Stop Failures* [Barwell-Scalas-Yoshida-Zhou 2022 CONCUR], which extends the Less-is-More 2019 framework to handle crash-stop failures. This work belongs to the "abandon global types" branch of the 2019 reckoning rather than the "repair association" branch, but is mentioned here because it represents continued investment in the alternative architecture.

A third repair direction is the *deconfined* and related global-type variants [Castagna-Dezani-Padovani 2012 *On Global Types and Multi-party Sessions*; Dagnino-Giannini-Dezani 2021 *Deconfined Global Types*; Barbanera-Dezani-Ciancaglini-de'Liguoro 2024 *Un-projectable Global Types*]. These widen the class of typeable protocols, in some cases by relaxing projectability requirements or admitting un-projectable global types for which only a coinductive LTS semantics is available. They preserve the "global type as primary" architecture while loosening its restrictions. They do not, however, remove the merge operator from the projection step where projectability *is* required, and so do not address the structural critique.

This synthesis takes the position that none of these repairs reach the root cause, and that the polynomial-functor / conjunctive-refinement alternative is the structurally-correct response. We do not argue here whether any specific repair "works" in the narrow sense of patching the proofs it targets; we argue that even where they work in that narrow sense, they preserve the OO-inheritance defect and the consequent brittleness of the projection-with-merge architecture.

### II.6 Asynchronous subtyping decidability frontier (cross-cut)

A separate technical thread, partially independent of the projection-with-merge brittleness but interacting with it, is the decidability boundary of asynchronous session subtyping. This thread is treated more fully in the asynchronous-programming companion artifact [Async Research §5.3]; we sketch the load-bearing facts here for cross-reference.

The key result is the 2017 paper by Bravetti, Carbone, and Zavattaro: *Undecidability of Asynchronous Session Subtyping* [Bravetti-Carbone-Zavattaro 2017]. The theorem statement is that "the three notions of asynchronous subtyping defined so far for session types are all undecidable" — covering Mostrous-Yoshida-Honda's framework for binary sessions [Mostrous-Yoshida-Honda 2009 ESOP], Chen et al.'s framework with an eventual message consumption assumption, and Mostrous et al.'s multiparty extension. The proof reduces from Post's Correspondence Problem (PCP), modeling asynchronous communication as queue-based (FIFO) machines and showing that the subtyping check encodes PCP instances. A more refined boundary analysis followed in *On the Boundary between Decidability and Undecidability of Asynchronous Session Subtyping* [Bravetti-Carbone-Zavattaro 2018], identifying decidable fragments by restricting type structure.

The connection to projection-with-merge brittleness is indirect but real. Asynchronous subtyping is the operator one would use to relate two local types — to check that one local type is a safe substitute for another. Projection produces local types; subtyping compares them. If projection produces a local type that the implementing process does not exactly match (because the process implements an optimized variant), subtyping bridges the gap. The undecidability of asynchronous subtyping means this bridge is fundamentally incomputable in general, forcing practical work into restricted fragments. The Lange-Yoshida result on *k-multiparty compatibility* [Lange-Yoshida 2019 CAV] provides one such fragment: a parameter k bounds the depth of asynchronous reordering considered, and k-MC is shown to be PSPACE-complete for any fixed k. The paper introduces k-MC as "a strict superset of the synchronous multiparty compatibility used in theories and tools based on session types," decomposed into k-safety (every sent message can be received within the bound) and k-exhaustivity (every k-reachable send action can fire within the bound) [Lange-Yoshida 2019].

A more recent algorithmic line — *A Sound Algorithm for Asynchronous Session Subtyping* [Bravetti-Carbone-Lange-Yoshida-Zavattaro 2019 CONCUR] — accepts the undecidability and produces an algorithm that is sound but not complete: when it returns "subtype," the relation holds; when it terminates without a verdict, no claim is made. The algorithm operates on a tree representation of the coinductive subtyping definition and searches for finite witnesses of infinite successful subtrees. Subsequent work has explored fair refinement and characterizations through 2025, but the underlying decidability barrier has not been removed.

The relevance to this slice is that the projection-with-merge brittleness and the asynchronous-subtyping undecidability are *the same shape of failure* manifested in two places. Projection-with-merge fails because it tries to compute a structurally exact local type from a global type, and the structural similarity assumption is too restrictive (or, in repaired versions, only sound under invariants that are themselves brittle). Asynchronous subtyping fails because it tries to relate two local types whose async behaviors diverge in arbitrarily subtle ways, and the relation is computable only under restrictive structural fragments. Both failures arise from trying to operate on the *syntactic structure* of session types when the semantic content is infinitary (asynchronous reorderings, role observations across branches). The polynomial-functor / coalgebra alternative — discussed more fully in Parts III and V of this synthesis — addresses both by reframing protocols as behaviors (coalgebras over a polynomial-functor signature) rather than as syntactic global types, with composition by conjunction rather than by syntactic projection.

The cross-reference to the asynchronous-programming companion artifact [Async Research §5.3] picks up the k-MC PSPACE-complete bound and the structural significance of the parameter k as a stratification index in the bottom-up architecture. We do not reproduce that analysis here; for this slice the load-bearing observation is that the same algebraic deficiency — partial reconciliation operators where lattice operations are needed — manifests in *both* the projection-with-merge architecture *and* the async-subtyping decidability frontier.

---

### References (annotated)

[**Honda-Yoshida-Carbone 2008**] Kohei Honda, Nobuko Yoshida, and Marco Carbone. *Multiparty Asynchronous Session Types*. POPL 2008, pp. 273-284. The founding paper of multiparty session types. Generalizes binary session types to *n* parties with asynchronous communication. Introduces global types, projection, and the (plain) merge operator. DOI: 10.1145/1328438.1328472. Available via ACM Digital Library.

[**Honda-Yoshida-Carbone 2016**] Kohei Honda, Nobuko Yoshida, and Marco Carbone. *Multiparty Asynchronous Session Types*. *Journal of the ACM* 63(1):9:1-9:67, 2016. The journal version, consolidating the 2008 framework with full proofs. Subject reduction, communication safety, progress, and session fidelity established. The proofs in this paper are among those affected by the 2019 reckoning's diagnosis. URL: http://mrg.doc.ic.ac.uk/publications/multiparty-asynchronous-session-types-jacm/jacm.pdf

[**Mostrous-Yoshida-Honda 2009**] Dimitris Mostrous, Nobuko Yoshida, and Kohei Honda. *Global Principal Typing in Partially Commutative Asynchronous Sessions*. ESOP 2009, LNCS 5502, pp. 316-332. Generalizes session types via asynchronous communication subtyping; allows partial commutativity of actions; presents (claimed) sound and complete subtyping algorithm. Subject of subsequent undecidability result.

[**Yoshida-Deniélou-Bejleri-Hu 2010**] Nobuko Yoshida, Pierre-Malo Deniélou, Andi Bejleri, and Raymond Hu. *Parameterised Multiparty Session Types*. FoSSaCS 2010. Among the works whose subject-reduction proofs are identified by Hou-Yoshida-Kuhn 2024 as containing the projection-with-full-merge gap.

[**Castagna-Dezani-Padovani 2012**] Giuseppe Castagna, Mariangiola Dezani-Ciancaglini, and Luca Padovani. *On Global Types and Multi-Party Session*. Logical Methods in Computer Science, 2012. arXiv:1203.0780. A streamlined language of global types with trace-based semantics whose features and restrictions are semantically (rather than syntactically) justified.

[**Coppo-Dezani-Padovani-Yoshida 2016**] Mario Coppo, Mariangiola Dezani-Ciancaglini, Luca Padovani, and Nobuko Yoshida. *Global Progress for Dynamically Interleaved Multiparty Sessions*. Mathematical Structures in Computer Science 26(2):238-302, 2016. Extends MPST to handle progress under dynamic interleaving and delegation across simultaneous sessions.

[**Deniélou-Yoshida 2013**] Pierre-Malo Deniélou and Nobuko Yoshida. *Multiparty Compatibility in Communicating Automata: Characterisation and Synthesis of Global Session Types*. ICALP 2013. Among works affected by the 2019 reckoning per Hou-Yoshida-Kuhn 2024.

[**Bravetti-Carbone-Zavattaro 2017**] Mario Bravetti, Marco Carbone, and Gianluigi Zavattaro. *Undecidability of Asynchronous Session Subtyping*. Information and Computation, 2017 (also arXiv:1611.05026). Proves the three notions of asynchronous subtyping in the literature are all undecidable, via reduction from Post's Correspondence Problem on FIFO machines.

[**Bravetti-Carbone-Zavattaro 2018**] Mario Bravetti, Marco Carbone, and Gianluigi Zavattaro. *On the Boundary between Decidability and Undecidability of Asynchronous Session Subtyping*. arXiv:1703.00659. Identifies decidable fragments by restricting the type structure; shows decidability of fragments without buffer limits and with multiple-choice support.

[**Scalas-Yoshida 2019**] Alceste Scalas and Nobuko Yoshida. *Less is More: Multiparty Session Types Revisited*. Proc. ACM Program. Lang. 3(POPL):30:1-30:29, January 2019. The reckoning paper. Identifies that proofs of type safety using end-point projection with mergeability are flawed; classic MPST has limited subject reduction with restrictions easily overlooked. Proposes a replacement theory grounded in behavioral type-level properties, dropping global types and binary duality. URL: https://dl.acm.org/doi/10.1145/3290343. Tech report: https://www.doc.ic.ac.uk/research/technicalreports/2018/DTRS18-6.pdf

[**Bravetti-Carbone-Lange-Yoshida-Zavattaro 2019**] Mario Bravetti, Marco Carbone, Julien Lange, Nobuko Yoshida, and Gianluigi Zavattaro. *A Sound Algorithm for Asynchronous Session Subtyping and its Implementation*. CONCUR 2019, LIPIcs 140:38:1-38:16. arXiv:1907.00421. Sound-but-not-complete algorithm for the undecidable subtyping; tree representation of the coinductive definition with finite-witness search.

[**Lange-Yoshida 2019**] Julien Lange and Nobuko Yoshida. *Verifying Asynchronous Interactions via Communicating Session Automata*. CAV 2019, LNCS 11561. arXiv:1901.09606. Introduces k-multiparty compatibility (k-MC) decomposed into k-safety and k-exhaustivity. Shows checking k-MC is PSPACE-complete; demonstrates scalability via partial-order reduction.

[**Dagnino-Giannini-Dezani 2021**] Francesco Dagnino, Paola Giannini, and Mariangiola Dezani-Ciancaglini. *Deconfined Global Types for Asynchronous Sessions*. COORDINATION 2021, also arXiv:2111.11984 / LMCS 2024. Extends the typeable class of asynchronous sessions while preserving subject reduction, session fidelity, and progress under decidable well-formedness.

[**Barwell-Scalas-Yoshida-Zhou 2022**] Adam D. Barwell, Alceste Scalas, Nobuko Yoshida, and Fangyi Zhou. *Generalised Multiparty Session Types with Crash-Stop Failures*. CONCUR 2022, LIPIcs 243:35:1-35:25. Continues the post-2019 abandon-global-types branch with crash-stop failure modeling.

[**Li-Stutz-Wies-Zufferey 2023**] Elaine Li, Felix Stutz, Thomas Wies, and Damien Zufferey. *Complete Multiparty Session Type Projection with Automata*. CAV 2023, LNCS 13965, pp. 350-373. arXiv:2305.17079. Presents the first sound, complete, and efficient projection operator for general MSTs; separates synthesis (automata-theoretic) from implementability checking. Shows MST implementability is PSPACE-complete. Articulates the structural critique: existing projection operators are syntactic in nature and trade efficiency for completeness; "what needs rethinking is not the concept of global types, but rather how projections are computed and how implementability is checked." Includes the odd-even protocol counterexample.

[**Jongmans-Ferreira 2023**] Sung-Shik Jongmans and Francisco Ferreira. *Synthetic Behavioural Typing: Sound, Regular Multiparty Sessions via Implicit Local Types*. ECOOP 2023, LIPIcs 263:42:1-42:30. Improves expressiveness via implicit local types and operational-semantics-based type checking; supports recursive protocols where different roles participate in different branches.

[**Gheri-Yoshida 2023**] Lorenzo Gheri and Nobuko Yoshida. *Hybrid Multiparty Session Types: Compositionality for Protocol Specification through Endpoint Projection*. POPL 2023. Introduces hybrid types for subprotocol description with a novel compatibility relation; algorithm for composing subprotocols into a well-formed global type while preserving projection.

[**Stutz-Wies-Zufferey 2023b**] Felix Stutz et al. *Asynchronous Multiparty Session Type Implementability is Decidable - Lessons Learned from Message Sequence Charts*. ECOOP 2023, LIPIcs. Companion result strengthening the implementability-decidability boundary.

[**Hou-Yoshida-Kuhn 2024**] Ping Hou, Nobuko Yoshida, and Iona Kuhn. *Less is More Revisited: Association with Global Protocols and Multiparty Sessions*. arXiv:2402.16741, 2024 (revised 2026). Repairs the 2019 broken-proofs diagnosis by replacing the consistency invariant with the *association* relation. Argues "a sound typing system can indeed be built using end-point projection with mergeability," reversing the inference that the top-down approach is unsound. Identifies four works affected by the original gap: parameterized MPST [Yoshida-Deniélou-Bejleri-Hu 2010], MPST meets communicating automata [Deniélou-Yoshida 2013], lightening global types, and certifying data in MPST. Distinguishes plain merging (uninvolved-role projections must be identical across branches) from full merging (input choices with disjoint labels can be combined) and shows the proof gap is specific to full merging.

[**Barbanera-Dezani-de'Liguoro 2024**] Franco Barbanera, Mariangiola Dezani-Ciancaglini, and Ugo de'Liguoro. *Un-projectable Global Types for Multiparty Sessions*. PPDP 2024. Coinductively-defined LTS for global types, accommodating un-projectable infinite sessions. Demonstrates that some implementable protocols cannot be projected from any bounded / projectable global type — yet another exhibit of projection-with-merge incompleteness.

[**Bravetti et al. 2025**] Various authors. *Asynchronous Global Protocols, Precisely* (arXiv:2505.17676) and successors. First sound top-down system from global types through projected local types, asynchronous subtypes, and processes. Includes asynchronous refinement relation (precise asynchronous multiparty subtyping).

[**Schärli-Ducasse-Nierstrasz-Black 2003**] Nathanael Schärli, Stéphane Ducasse, Oscar Nierstrasz, and Andrew P. Black. *Traits: Composable Units of Behaviour*. ECOOP 2003, LNCS 2743. The seminal trait paper. Establishes that "composition is commutative and associative, which ensures that the order of composition is irrelevant" — restoring an actual lattice operation in place of multiple-inheritance MRO. Stateless traits as composable units of behavior. Subsequent work (*Stateful Traits*, 2007) extends to stateful settings while preserving the algebraic discipline.

[**Wikipedia: Multiple Inheritance**] *Multiple inheritance*. https://en.wikipedia.org/wiki/Multiple_inheritance. Standard reference on the diamond problem, C3 linearization, MRO conventions, and the proposed alternatives (mixins, traits, composition over inheritance). Establishes the historical record that MRO is convention-based rather than algebraically forced.

[**Carbone-Montesi 2013**] Marco Carbone and Fabrizio Montesi. *Deadlock-Freedom-by-Design: Multiparty Asynchronous Global Programming*. POPL 2013. Choreographic programming: programming communications declaratively and synthesizing endpoint implementations automatically. Cross-reference to alternative approaches addressed in §III of this synthesis.

[**Bocchi-Honda-Tuosto-Yoshida 2010**] Laura Bocchi, Kohei Honda, Emilio Tuosto, and Nobuko Yoshida. *A theory of design-by-contract for distributed multiparty interactions*. Cross-reference for the lineage of behavioral specification approaches that complement / extend MPST.

[**Castagna et al. 2009**] Giuseppe Castagna, Nils Gesbert, and Luca Padovani. *A Theory of Contracts for Web Services*. POPL 2009. Where mergeability for the projection of WS-CDL was first introduced (per Hou-Yoshida-Kuhn 2024).

[**ACM POPL 2019 page**] *Less is More: Multiparty Session Types Revisited*. POPL 2019 program details. https://popl19.sigplan.org/details/POPL-2019-Research-Papers/48/Less-is-More-Multiparty-Session-Types-Revisited. The conference page acknowledging the paper's reckoning framing.

[**Voinea-Dardha-Gay 2016**] A. Laura Voinea, Ornela Dardha, and Simon J. Gay. *Certifying Data in Multiparty Session Types*. Affected by the broken-proofs cascade per Hou-Yoshida-Kuhn 2024.

[**Async Research §5.3**] Companion artifact `docs/research/2026-05-05_ASYNCHRONOUS_PROGRAMMING_QUANTALE_RESEARCH_PROGRAM.md`, §5.3. Cross-reference for the structural significance of k-multiparty compatibility's bound parameter and the relationship between async subtyping decidability and the bottom-up protocol architecture.

[**Coalgebra cross-reference**] Joachim Cabré, Henning Basold, et al. *Session Coalgebras: A Coalgebraic View on Regular and Context-Free Session Types*. ACM TOPLAS, 2022. https://dl.acm.org/doi/10.1145/3527633. Polynomial-functor coalgebra reformulation of session types, cited in §V (synthesis) of this research program; included here for forward reference.

---

## §III. Escape routes from projection-with-merge: Synthetic MPST and the AMP / Protocol-State-Machine line

The Scalas–Yoshida 2019 disclosure that classical multiparty session type (MPST) subject-reduction proofs were unsound under full merging cracked open a research programme that, almost immediately, bifurcated into two orthogonal strategies for escaping the broken proof technology. Both strategies abandon the central commitment of orthodox MPST — that protocol verification factors through *projection-with-merge*, where a global type `G` is mechanically split into local types `G ↾ p` for each role `p` via a partial merge operator on syntactic branches. The first strategy, **synthetic MPST**, retains global types but throws out projection: each process is type-checked directly against an LTS interpretation of the global protocol. The second strategy, the **Asynchronous-Multiparty / Protocol State Machine (AMP/PSM)** line, retains a notion of projection but throws out the *global type* as a primitive: protocols are denoted by Protocol State Machines, with global-type syntax recovered as a strict subclass on which the projection algorithm is provably sound and complete.

These two routes converge structurally despite stylistic divergence. Both reify the protocol as a transition system — a coalgebra in the category of sets, in standard categorical readings [Basold-Padovani 2021, Aczel 1988] — and both perform the verification work *against* that transition system rather than against syntactic projections of it. The architectural target this artifact builds toward (multiparty protocols as polynomial functors over a quantale-valued propagator runtime, with role projection as opcartesian lifts in a fibration) ought to read both escape routes as approximations: each independently rediscovers a piece of the polynomial-functor / coalgebraic / quantale-enriched picture, but neither articulates the unifying structure, and neither integrates with cost-aware (tropical-quantale) realizability nor with conjunctive-refinement composition. The gap is the bridge §V will exploit.

### §III.1 Synthetic MPST: type processes against the LTS, skip projection

The load-bearing reference is Castro-Perez, Ferreira, and Jongmans, "A Synthetic Reconstruction of Multiparty Session Types," to appear in *Proceedings of the ACM on Programming Languages* (POPL 2026), with the arXiv preprint dated November 27, 2025 [Castro-Perez-Ferreira-Jongmans 2026]. The paper extends an earlier ECOOP 2023 "Pearl / Brave New Idea" by Jongmans and Ferreira titled "Synthetic Behavioural Typing: Sound, Regular Multiparty Sessions via Implicit Local Types" [Jongmans-Ferreira 2023], which introduced the foundational move but limited expressiveness to regular protocols projected with implicit (rather than explicit) local types. The 2026 paper generalises the technique to verify processes directly against arbitrary well-behaved labelled transition systems, with global types appearing as a strict syntactic subclass.

#### §III.1.1 The forced trade-off the synthetic approach dissolves

The introduction of [Castro-Perez-Ferreira-Jongmans 2026] frames the design space as a trade-off between expressiveness and compositionality:

> existing approaches force a difficult trade-off: classical projection-based techniques are compositional but limited in expressiveness, while more recent techniques achieve higher expressiveness by relying on non-compositional, whole-system model checking, which scales poorly. Our key innovation is a type system that verifies each process directly against a global protocol specification, represented as a labelled transition system in general, with global types as a special case. This approach uniquely avoids the need for intermediate local types and projection.

The two horns of the trade-off correspond to two distinct reactions to the Scalas-Yoshida unsoundness disclosure. The "fix the proofs" reaction — exemplified by [Hou-Yoshida-Kuhn 2024] (Less is More Revisited) and the "Asynchronous Global Protocols, Precisely" line [Hou et al. 2025] — retains projection-with-merge and develops a new invariance relation called *association* between global types and endpoint projections, then proves subject reduction modulo association. The "abandon projection" reaction — exemplified by Scalas-Yoshida's own 2019 paper [Scalas-Yoshida 2019] and the bottom-up frameworks it spawned [Udomsrirungruang-Yoshida 2025] — discards the global type entirely as a verification artifact, instead synthesising local types per process and checking their composition against ensemble properties (deadlock-freedom, liveness) via global model-checking. The latter reaction recovers expressiveness but at the cost of compositionality: properties of the whole are not deducible from properties of the parts.

Synthetic MPST's escape from this dichotomy works by retaining global types (so compositionality is recoverable) but interpreting them as labelled transition systems and type-checking processes coalgebraically — that is, by simulating each process's behaviour against the LTS state-by-state. The merge operator, the bête noire of classical MPST, dissolves because there are no local types to merge into.

#### §III.1.2 Operational form: typing rules from operational semantics

The key technical move in [Jongmans-Ferreira 2023], retained and generalised in [Castro-Perez-Ferreira-Jongmans 2026], is to define the typing rules *synthetically* from the operational semantics of (implicit) local types. Quoting the ECOOP 2023 abstract:

> projection is based on implicit local types instead of explicit; type checking is based on the operational semantics of implicit local types instead of on the syntax. That is, the reduction relation on implicit local types is used not only "a posteriori" to prove type soundness (as usual), but also "a priori" to define the typing rules — synthetically.

Read structurally, this inverts the direction of the type-soundness argument. Classical MPST defines syntactic typing rules and *then* proves they preserve operational semantics (subject reduction); the synthetic approach defines the typing rules *as* the operational semantics, so subject reduction becomes near-tautological — a process is well-typed exactly when its observable transitions can be matched, step by step, by the global LTS. Soundness reduces to the existence of a simulation between the process's own behaviour and the LTS. This is precisely a coalgebra morphism: a function from the process's state space to the LTS state space that commutes with the transition functor.

The 2026 paper extends this from regular implicit local types to arbitrary well-behaved LTSs — meaning the LTS need not arise from any global type at all. Global types become a *notation* for a subclass of transition systems; the type system handles transition systems uniformly, with the global-type subclass distinguished only by syntactic well-formedness conditions on the notation. This generalisation is what gives the 2026 paper its claim to handling "protocols not expressible with the standard global type syntax."

#### §III.1.3 Soundness and the coalgebraic reading

Although [Castro-Perez-Ferreira-Jongmans 2026] does not foreground coalgebraic vocabulary, the structure of their soundness argument is unmistakably coalgebraic. A labelled transition system over an action alphabet `Λ` is, in standard categorical terms, a coalgebra for the polynomial functor `P(Λ × −)` on the category of sets, where `P` is the powerset functor [Aczel 1988, Jacobs 2016]. The synthetic typing judgement `P ⊢ G` (process `P` is well-typed against global LTS `G`) holds when there exists a simulation relation `R ⊆ States(P) × States(G)` such that every transition `P → P'` in the process is matched by a corresponding transition `G → G'` in the LTS with `(P', G') ∈ R`. This is exactly a coalgebra morphism (or, more precisely, the existence of a span of coalgebra morphisms whose mediating object is the simulation relation, which is the standard definition of bisimulation up to and behavioural equivalence in the coalgebraic literature [Sangiorgi 2011, Staton 2009]).

The 2026 paper has been "formalised and mechanised in Agda" with a prototype VS Code extension [Castro-Perez-Ferreira-Jongmans 2026 Zenodo artifact]. Agda mechanisation of session-type theories has historically required heavy infrastructure for handling coinductive process equivalence; the synthetic approach's appeal here is that the coinductive content lives in the LTS-side of the simulation, not in projecting-and-merging type syntax, which is well-suited to Agda's `coinductive` keyword.

#### §III.1.4 Architectural significance for the propagator-network target

The synthetic approach has unusually direct architectural alignment with the Prologos propagator-network substrate. A propagator network is, structurally, an LTS-checker: cells hold lattice values, propagators react to cell changes by firing in BSP rounds, and constraint propagation against a state-space lattice is exactly behavioural simulation against an LTS specification. The Prologos design mantra — "all-at-once, all in parallel, structurally emergent information flow ON-NETWORK" — is the operational form of "all process transitions checked simultaneously against the LTS." A synthetic-MPST type-checker hosted on the propagator base would represent the global LTS as a state-cell with appropriate component-paths for each role's view, install one propagator per process-transition rule, and let BSP scheduling handle the per-round simulation matching. Compared to projection-with-merge, where each role's local type is a separately maintained object that has to be reconciled with the others by the merge function, the synthetic approach maps each role to a *projection of the same shared LTS cell* — a Galois connection in lattice-theoretic terms, an opcartesian lift in fibrational terms. The synthetic MPST design is, *in effect*, the same architectural shape Prologos uses for its bottom-up structural unification (PUnify) and its bitmask-tagged shared-carrier worldview cells: one primary lattice with multiple projections, never multiple "owned" sub-lattices that have to be glued at the seams.

What synthetic MPST does *not* yet supply is the cost-aware (quantale-enriched) extension: the LTS is unweighted, so the type system has no place to thread tropical-quantale costs through the simulation. It also does not handle conjunctive-refinement composition: if two processes type-check against `G_1` and `G_2` respectively, there is no machinery to compose them into a process typing against `G_1 ⊓ G_2` for an appropriate refinement meet. These are the two gaps §III.5 will return to.

### §III.2 The Stutz / AMP / Protocol State Machine line

The second escape route runs through a tight cluster of papers from Felix Stutz, Elaine Li, Thomas Wies, and Damien Zufferey, originating in Stutz's PhD thesis [Stutz 2023] and culminating in the CAV 2023 result that MPST implementability is PSPACE-complete via a sound and complete projection algorithm built around Protocol State Machines [Li-Stutz-Wies-Zufferey 2023].

#### §III.2.1 Protocol State Machines as the right primitive

The signature claim of the AMP line is that even *global types* are the wrong primitive object: the correct object is the Protocol State Machine (PSM), and global-type syntax is a particular notation for a constrained subclass of PSMs. Stutz's ECOOP 2023 paper "Asynchronous Multiparty Session Type Implementability is Decidable — Lessons Learned from Message Sequence Charts" [Stutz 2023] establishes the technical and conceptual basis: implementability — the question of whether a given global protocol admits a deadlock-free local realisation that produces precisely its specified executions — was an open problem in the asynchronous setting, and Stutz resolves it positively for the *sender-driven choice* fragment by encoding global types into High-level Message Sequence Charts (HMSCs) and adapting decidability results from the HMSC literature [Alur-Etessami-Yannakakis 2003, Genest-Muscholl-Peled 2005].

The Li-Stutz-Wies-Zufferey CAV 2023 paper [Li-Stutz-Wies-Zufferey 2023] then makes the methodological reframing explicit. Their motivating critique of classical syntactic projection is direct:

> the heuristic nature of the projection algorithms makes it very hard to predict if a global type will be handled or not by an MST framework, even in the case where the behaviour specified by the global type is unproblematic.

The complaint is not that projection-with-merge is unsound (the Hou-Yoshida-Kuhn association-relation work has rehabilitated it for a sufficiently restricted class), but that it is *predictively opaque*: a programmer cannot tell from the global type itself whether the framework will accept it, because acceptance depends on syntactic accidents of how the merge operator decomposes branches. The AMP response is to define the projection problem semantically — implementability is a property of the underlying transition system, not of any particular notation for it — and then to give an algorithm whose acceptance is decidable and characterised by clear semantic conditions.

Concretely, [Li-Stutz-Wies-Zufferey 2023] constructs:

- A **Global Automaton** `GAut(G)` from a global type, with states being syntactic subterms (plus a terminal state) and transitions labelled by send/receive event pairs encoding choice branching and recursion;
- A **Local Automaton** for each role obtained by homomorphic event-filtering followed by subset-construction determinisation;
- Two **succinct semantic conditions** — *Availability* (every reception in a role's local automaton is permitted by some global execution) and *Knowledge* (every choice point has its outcome learnable by every other role through subsequent message arrivals) — under which the projection is sound and complete.

The separation of synthesis from checking is the key methodological move: synthesis uses standard automata-theoretic constructions (homomorphism, determinisation), while implementability checking uses the two semantic conditions, and this separation is what reduces the complexity from the prior EXPSPACE bound to PSPACE, with implementability checking itself shown PSPACE-complete.

#### §III.2.2 The PSM as the genuine primitive

The CAV 2023 paper treats global types as a notation, with PSMs the genuine specification artifact. The follow-up Sprout system [Li-Stutz-Wies-Zufferey 2025] (CAV 2025) makes this commitment fully explicit: Sprout verifies *symbolic multiparty protocols* — PSMs extended with dependent refinements on message values, loop memory, and generalised sender-driven choice — by a sound and complete reduction to the fixpoint logic μCLP [Kobayashi et al. 2018], with the MuVal solver as backend. Quoting from the search results:

> Sprout is the first sound and complete implementability checker for symbolic multiparty protocols. Sprout supports protocols with dependent refinements on message values, loop memory, and multiparty communication with generalized, sender-driven choice.

The trajectory is clear: PSMs are the specification primitive, refinement predicates extend them to data-dependent protocols, and implementability is a fixpoint property of the PSM checked against a participant-projection notion that is *defined* as the right semantic condition rather than constructed by syntactic case analysis on global-type syntax.

The complementary characterisation paper [Li-Stutz-Wies-Zufferey 2024] ("Characterizing Implementability of Global Protocols with Infinite States and Data") sharpens the complexity bounds: implementability is co-NP-complete for explicit (finite) PSMs and PSPACE-complete for symbolic (refinement-typed) PSMs, with a (co)reachability-based semantic characterisation that further marginalises the role of syntactic global-type structure.

#### §III.2.3 Connection to communicating state machines

PSMs are a syntactic close relative of Communicating State Machines (CSMs) — finite-state machines with FIFO message channels [Brand-Zafiropulo 1983] — which are the standard semantic substrate for asynchronous protocol verification. The CAV 2023 projection produces, for each role, a determinised local automaton; placing these in parallel with FIFO channels produces a CSM whose runs are exactly the implementations of the global type. The AMP line thereby connects MPST verification to the rich existing literature on CSM decidability fragments and HMSC realisability [Alur-Etessami-Yannakakis 2003, Genest et al. 2007], and the connection is what permits the PSPACE-completeness result to be lifted from HMSCs to MPST-style global types.

The architectural significance for the propagator target is that PSMs are LTSs with a particular role-tagged action alphabet structure. They are the same kind of coalgebraic object as a synthetic-MPST global LTS, just specialised to a per-role action partition that makes the role-projection question naturally formulable. The two escape routes are therefore reasoning about the same kind of object — a labelled transition system — but from opposite ends: synthetic MPST starts at the process side and asks "can this process be simulated by the LTS?", while AMP starts at the protocol side and asks "is there a CSM implementation whose joint runs match this LTS?". The two questions have the same answer when both sides are well-defined, and the distinction collapses entirely under the polynomial-functor-over-quantale categorical structure §IV.5–IV.6 articulates.

### §III.3 The k-MC framework as the bridge

Lange and Yoshida's CAV 2019 paper "Verifying Asynchronous Interactions via Communicating Session Automata" [Lange-Yoshida 2019] sits temporally and conceptually between the classical projection world and the AMP world. Its contribution is the *k-multiparty compatibility (k-MC)* framework, which generalises Deniélou-Yoshida's earlier synchronous multiparty compatibility (SMC) [Deniélou-Yoshida 2013] to asynchronous bounded-buffer settings.

The k-MC property decomposes into two bounded conditions:

- **k-safety**: within bound `k`, every sent message can be received and every automaton can move (a "downward closure" condition expressing that no deadlocks arise within reachable states);
- **k-exhaustivity**: every k-reachable send action can be fired within bound `k` (an "upward closure" condition expressing that no behaviour is missed by bounding the buffers).

Crucially, k-exhaustivity implies *existential boundedness*: a system is k-exhaustive iff its behaviour above buffer bound `k` is equivalent (modulo trace equivalence) to its behaviour at exactly `k`. This makes the framework a finitary approximation that becomes exact at the right `k`, with the smallest such `k` characterised semantically.

Checking k-MC is PSPACE-complete; partial-order reduction techniques mitigate this in practice. The async research artifact §5.3 covers the bounded-verification aspect; what matters for the present discussion is that k-MC is *neither* projection-with-merge *nor* synthetic-direct-against-LTS — it is a *bottom-up* compatibility check on Communicating Session Automata, and as such it bridges the classical world (where projection produces the local types whose composition is checked) and the AMP world (where the local types are themselves the primary artifact and a global type is *synthesised* from them via a separate algorithm).

The Deniélou-Yoshida 2013 paper [Deniélou-Yoshida 2013] anticipated this trajectory: it equipped global and local session types with LTS semantics over unbounded buffered channels, identified the class of communicating automata that exactly correspond to projected local types, and gave a synthesis algorithm from compatible automata to global types. The CAV 2023 PSPACE-complete projection result is, in retrospect, the completion of the Deniélou-Yoshida programme — the answer to "when is a CSM the projection of a global type, and which global type?", made fully algorithmic and complexity-tight.

### §III.4 The unifying observation

Both synthetic MPST and the AMP/PSM line dispense with projection-with-merge as a *primitive* operation, though by different means. Synthetic MPST eliminates projection entirely, lifting the verification work onto a coalgebraic simulation between processes and an LTS interpretation of the global protocol. AMP/PSM retains projection as a derived notion but defines it semantically — as the unique automaton-theoretic construction whose Availability and Knowledge conditions characterise implementability — rather than as a syntactic case analysis on global-type structure. Both rely on labelled transition systems for soundness arguments. Both treat global-type syntax as a particular notation for a class of transition systems rather than as the fundamental object.

These convergences are not coincidental. Both routes are independently rediscovering structural properties that the categorical machinery developed in the early-2020s session-coalgebra literature [Basold-Padovani 2021, "A Coalgebraic View on Regular and Context-Free Session Types"] makes uniform: a session type is a coalgebra for a particular polynomial functor; type equivalence, duality, and subtyping are coinductive and definable as greatest (post-)fixpoints; behavioural reasoning is bisimulation. Multiparty extensions of this picture — which the present synthetic-MPST and PSM lines partially realise — would naturally treat global protocols as coalgebras for a multi-action functor, role projections as natural transformations to per-role coalgebras, and implementability as a structural property (equivariance under projection) rather than as a syntactic accident.

The polynomial-functor / locally-cartesian-closed-category (LCCC) / dependent-type-theory framework that the architectural target invokes [Awodey-Newstead 2018, Gambino-Kock 2013, Kock 2012] supplies exactly this missing structure. A polynomial functor over an LCCC is fibrationally a span of objects-and-projections; a multiparty protocol is naturally a polynomial functor whose source object is the joint state, whose middle object is the disjoint union of per-role action sets, and whose projections to roles are the legs of the fibration. Role projection is then an *opcartesian lift* — a categorical universal property — rather than a syntactic merge. Synthetic MPST and AMP each independently approximate this picture: synthetic MPST works directly with the polynomial functor's "process behaviour" semantics; AMP works directly with the polynomial functor's "joint state + role-projection" structure.

### §III.5 Where these escape routes fall short of the Prologos architectural target

The unifying observation in §III.4 also sharpens the gap analysis the Prologos architectural target must close. Both escape routes are necessary but insufficient.

**Gap 1 — categorical machinery left implicit**. Synthetic MPST and AMP/PSM each independently use coalgebraic / LTS-style structure for soundness without articulating the polynomial-functor / fibrational structure that explains *why* this works. The result is that each line of work has its own ad-hoc soundness story — Castro-Perez-Ferreira-Jongmans's Agda mechanisation, Li-Stutz-Wies-Zufferey's PSPACE-completeness reduction — without a shared abstract framework that lifts results uniformly. From the Prologos point of view, this is a category error: cells in the propagator network are objects in an LCCC, propagators are morphisms (or polynomial functors over the LCCC), and the "all-at-once, all in parallel" mantra is the operational form of the LCCC's products and exponentials. A multiparty protocol that lives natively in this LCCC inherits projection-as-opcartesian-lift for free; the soundness argument is the universal property, not a separate construction. Synthetic MPST has done the conceptual move of "type against the LTS" without naming the LCCC structure that makes the LTS the right object; AMP has done the conceptual move of "PSMs as primitive" without naming the polynomial-functor structure that makes the role-tagged action alphabet a fibration.

**Gap 2 — no cost-aware realizability**. Neither escape route handles the tropical-quantale dimension. Synthetic MPST's typing judgement `P ⊢ G` is a Boolean predicate (the simulation either exists or it does not); AMP's implementability check is similarly Boolean. The Prologos quantale-enriched runtime supports cost-aware realizability — a process realises a protocol *with cost `c`* drawn from a tropical quantale, where the cost is the join of per-step costs along the simulation. Lifting either escape route to quantale-enriched LTSs requires replacing Boolean simulations by quantale-valued simulations [Worrell 2005, Bonchi-Sokolova-Vignudelli 2022] — known infrastructure but absent from the MPST literature surveyed here. The propagator-network substrate's cells are already quantale-valued (the Prologos effect-ordering quantale and tropical-cost quantale are first-class), so this is not infrastructure that needs to be invented; it is infrastructure that needs to be applied to the new MPST setting.

**Gap 3 — no conjunctive-refinement composition**. Neither escape route integrates with conjunctive-refinement composition (the Prologos bundle/trait machinery). Synthetic MPST's typing rules are not closed under refinement intersection: if `P ⊢ G_1` and `P ⊢ G_2`, the natural conclusion `P ⊢ G_1 ⊓ G_2` is unsupported by the type system as written, because the LTS-meet operation is not part of the synthetic framework's vocabulary. AMP/PSM has the same issue: implementability is checked separately for each PSM, and a process implementing both `PSM_1` and `PSM_2` is not automatically certified as implementing `PSM_1 ⊓ PSM_2`. This matters architecturally because the Prologos compositional story is built on conjunctive refinement: a behaviour that satisfies multiple specifications simultaneously simply intersects them in the refinement lattice, with the propagator network handling the meet operation. A multiparty session type system that does not integrate with this composition is non-uniform with the rest of the Prologos type theory.

**Gap 4 — no unified treatment of binary and multiparty session types**. Synthetic MPST keeps multiparty as a separate framework from binary session types; AMP introduces PSMs as a multiparty primitive without any commitment that binary session types are the two-role specialisation. Prologos's architectural commitment is that binary and multiparty session types should be *the same machinery* — the multiplicity of roles is a parameter of the polynomial functor, not a foundational distinction. Synthetic MPST and AMP each leave binary session types as an external reference rather than as a strict subclass of their own framework.

**Gap 5 — implementation engineering still separated from semantics**. Synthetic MPST mechanises in Agda (a constructive type theory) and prototypes a VS Code extension; AMP/PSM implements in OCaml (Sprout) with a μCLP backend. Neither line of work hosts the verification on a propagator-network runtime where the type-checking and protocol execution share the same substrate. The Prologos architecture's commitment that *the type-checker runs on the same propagator network as the runtime* — that compilation is itself a propagator-network computation — is absent from both. Synthetic MPST's coalgebraic simulation could naturally be an LTS-checker propagator; AMP's PSM could naturally be a state-cell with role-projection morphisms; but neither line has written this down.

These five gaps are the precise content the architectural target must supply. §IV.5 (polynomial functors / LCCC / DTT) addresses Gap 1; §IV.6 (quantale-enriched session types) addresses Gap 2; the conjunctive-refinement and propagator-network material in §V addresses Gaps 3-5. The synthesis claim §V will defend is that these gaps are not independent fixes — they are jointly closed by treating multiparty protocols as polynomial functors over a quantale-valued propagator runtime, with role projection as opcartesian lifts, behavior as coalgebras, realizability as a quantale-valued fixpoint, and composition as conjunctive refinement.

---

## References

**[Aczel 1988]** P. Aczel, *Non-well-founded sets*, CSLI Lecture Notes 14, Stanford University. — Foundational for the coalgebraic reading of LTSs as sets-of-transitions; the categorical apparatus in which "an LTS is a coalgebra for `P(Λ × −)`" was first cleanly stated.

**[Alur-Etessami-Yannakakis 2003]** R. Alur, K. Etessami, M. Yannakakis, "Inference of Message Sequence Charts," *IEEE Transactions on Software Engineering* 29(7), pp. 623-633. — Decidability and complexity results for HMSC realisability; the foundation Stutz lifts to MPST.

**[Awodey-Newstead 2018]** S. Awodey, C. Newstead, "Polynomial pseudomonads and dependent type theory," *arXiv:1802.00997*. — Categorical underpinning for treating polynomial functors as the natural setting for dependent types over an LCCC; load-bearing for §IV.5's framework.

**[Basold-Padovani 2021]** H. Basold, L. Padovani, "A Coalgebraic View on Regular and Context-Free Session Types," *ACM TOPLAS*. — Presents session types as coalgebras of polynomial functors; bisimulation, duality, and subtyping recovered as coinductive notions. Direct categorical antecedent for synthetic MPST's soundness story.

**[Bonchi-Sokolova-Vignudelli 2022]** F. Bonchi, A. Sokolova, V. Vignudelli, "Presenting convex sets of probability distributions by convex semilattices and unique bases," *CALCO 2022*. — Quantitative bisimulation infrastructure for quantale-enriched LTSs; relevant for Gap 2 (cost-aware realizability).

**[Brand-Zafiropulo 1983]** D. Brand, P. Zafiropulo, "On Communicating Finite-State Machines," *Journal of the ACM* 30(2), pp. 323-342. — Original CSM model; semantic substrate for asynchronous protocol verification that PSM and CSA work all build on.

**[Castro-Perez-Ferreira-Jongmans 2026]** D. Castro-Perez, F. Ferreira, S.-S. Jongmans, "A Synthetic Reconstruction of Multiparty Session Types," *Proceedings of the ACM on Programming Languages* (POPL 2026), DOI 10.1145/3776692; arXiv:2511.22692 (November 2025). — Load-bearing reference. Type system verifies processes directly against an LTS interpretation of a global protocol, eliminating intermediate local types and projection. Agda-mechanised; VS Code prototype. Generalises [Jongmans-Ferreira 2023] to arbitrary well-behaved LTSs.

**[Deniélou-Yoshida 2013]** P.-M. Deniélou, N. Yoshida, "Multiparty Compatibility in Communicating Automata: Characterisation and Synthesis of Global Session Types," *ICALP 2013*. — Equips global and local session types with LTS semantics over unbounded buffered channels; gives synthesis from compatible automata to global types. The synchronous predecessor of [Lange-Yoshida 2019].

**[Gambino-Kock 2013]** N. Gambino, J. Kock, "Polynomial functors and polynomial monads," *Mathematical Proceedings of the Cambridge Philosophical Society* 154(1). — Standard reference for polynomial functors over an LCCC and their associated monads; foundational for §IV.5.

**[Genest-Muscholl-Peled 2005]** B. Genest, A. Muscholl, D. Peled, "Message Sequence Charts," *Lectures on Concurrency and Petri Nets*. — Survey of the HMSC realisability technology Stutz adapts to MPST.

**[Gheri-Yoshida 2023]** L. Gheri, N. Yoshida, "Hybrid Multiparty Session Types: Compositionality for Protocol Specification through Endpoint Projection," *PACMPL OOPSLA 2023*. — Adjacent to the synthetic line; introduces hybrid types and a compatibility relation enabling subprotocol composition while preserving classical projection's semantic guarantees.

**[Hou-Yoshida-Kuhn 2024]** P. Hou, N. Yoshida, I. Kuhn, "Less is More Revisited: Association with Global Protocols and Multiparty Sessions," *arXiv:2402.16741*. — The "fix the proofs" reaction to Scalas-Yoshida 2019. Introduces the *association* invariance relation between global type and endpoint projection; corrected subject-reduction theorem. Counterexample (global type `G_w`) shows full merging produces inconsistent local types that the new association-based proof handles.

**[Hou et al. 2025]** P. Hou, N. Yoshida et al., "Asynchronous Global Protocols, Precisely," *arXiv:2505.17676*. — Coinductive full-merging projection for asynchronous protocols; soundness, completeness, deadlock-freedom, and liveness proven for optimised endpoints. Continues the "fix the proofs" reaction in the asynchronous setting.

**[Jacobs 2016]** B. Jacobs, *Introduction to Coalgebra: Towards Mathematics of States and Observation*, Cambridge University Press. — Standard textbook for the coalgebraic reading of transition systems; supports the coalgebraic framing of synthetic MPST in §III.1.3.

**[Jongmans-Ferreira 2023]** S.-S. Jongmans, F. Ferreira, "Synthetic Behavioural Typing: Sound, Regular Multiparty Sessions via Implicit Local Types (Pearl/Brave New Idea)," *ECOOP 2023*, *LIPIcs* 263:42. — The foundational synthetic-MPST paper, restricted to regular protocols. Introduces the synthetic move: typing rules defined from the operational semantics of implicit local types, using the reduction relation a priori (defining typing) rather than a posteriori (proving soundness).

**[Kobayashi et al. 2018]** N. Kobayashi, T. Tsukada, K. Watanabe, "Higher-Order Program Verification via HFL Model Checking," *ESOP 2018*. — μCLP / higher-order fixpoint logic; backend for Sprout's implementability decision procedure.

**[Kock 2012]** J. Kock, "Polynomial functors and trees," *Information and Computation* 217. — Operational treatment of polynomial functors via trees; useful for §IV.5's connections to proof-theoretic semantics.

**[Lange-Yoshida 2019]** J. Lange, N. Yoshida, "Verifying Asynchronous Interactions via Communicating Session Automata," *CAV 2019*; arXiv:1901.09606. — Introduces *k-multiparty compatibility (k-MC)*. k-safety + k-exhaustivity decompose compatibility into bounded conditions; PSPACE-complete check, mitigated by partial-order reduction. Bridges classical projection-with-merge and the AMP world by checking compatibility bottom-up on CSAs without requiring projection.

**[Li-Stutz-Wies-Zufferey 2023]** E. Li, F. Stutz, T. Wies, D. Zufferey, "Complete Multiparty Session Type Projection with Automata," *CAV 2023*; arXiv:2305.17079. — Load-bearing reference for §III.2. First sound, complete, and efficient projection operator. Constructs Global Automaton GAut(G), determinises per-role local automata, characterises implementability via *Availability* and *Knowledge* semantic conditions. PSPACE-complete check, improving on prior EXPSPACE bound. Critique of heuristic syntactic projection.

**[Li-Stutz-Wies-Zufferey 2024]** E. Li, F. Stutz, T. Wies, D. Zufferey, "Characterizing Implementability of Global Protocols with Infinite States and Data," *PACMPL POPL 2025*; arXiv:2411.05722. — Sharpens [2023] complexity to co-NP-complete for finite explicit protocols and PSPACE-complete for symbolic protocols; first sound and relatively complete algorithm for symbolic implementability.

**[Li-Stutz-Wies-Zufferey 2025]** E. Li, F. Stutz, T. Wies, D. Zufferey, "Sprout: A Verifier for Symbolic Multiparty Protocols," *CAV 2025*. — First sound and complete implementability checker for symbolic multiparty protocols. Reduction to μCLP fixpoint logic; MuVal backend. Supports refinements on message values, loop memory, generalised sender-driven choice. ~3500 lines OCaml. GitHub: nyu-acsys/sprout.

**[Sangiorgi 2011]** D. Sangiorgi, *Introduction to Bisimulation and Coinduction*, Cambridge University Press. — Standard reference for behavioural equivalence via simulation/bisimulation; supports the coalgebraic reading of synthetic MPST soundness.

**[Scalas-Yoshida 2019]** A. Scalas, N. Yoshida, "Less is More: Multiparty Session Types Revisited," *POPL 2019*. — The disclosure that classical MPST subject-reduction proofs were unsound under full merging. Removes restrictions on global types and binary duality; grounds new theory on general behavioural type-level properties. Catalyst for both escape routes covered in this section.

**[Staton 2009]** S. Staton, "Relating coalgebraic notions of bisimulation," *CALCO 2009*. — Establishes equivalences among the various coalgebraic formulations of bisimulation; supports the simulation-as-coalgebra-morphism reading.

**[Stutz 2023]** F. Stutz, "Asynchronous Multiparty Session Type Implementability is Decidable — Lessons Learned from Message Sequence Charts," *ECOOP 2023*, *LIPIcs* 263:32; arXiv:2302.11272. — Resolves the open implementability question positively for sender-driven-choice global types, by encoding into HMSCs and adapting HMSC decidability technology. Companion: [Stutz-Zufferey 2022].

**[Stutz-Zufferey 2022]** F. Stutz, D. Zufferey, "Comparing Channel Restrictions of Communicating State Machines, High-level Message Sequence Charts, and Multiparty Session Types," *arXiv:2209.10328*. — Map of relationships among the three primary asynchronous-protocol formalisms; clarifies how HMSC results transfer to MPST.

**[Udomsrirungruang-Yoshida 2025]** T. Udomsrirungruang, N. Yoshida, "Top-Down or Bottom-Up? Complexity Analyses of Synchronous Multiparty Session Types," *PACMPL POPL 2025*. — Comparative complexity analysis of top-down (projection-based) vs. bottom-up (Scalas-Yoshida) MPST workflows. Bottom-up offers greater typability at higher cost (exponential type inference); top-down is more efficient in practice but limited in expressiveness. Validates the trade-off [Castro-Perez-Ferreira-Jongmans 2026] aim to dissolve.

**[Worrell 2005]** J. Worrell, "On the final sequence of a finitary set functor," *Theoretical Computer Science* 338(1-3). — Coalgebraic infrastructure for quantale-valued and metric bisimulation; relevant for Gap 2.

---

## §III.6 MCC and Coherence as n-ary Duality

### §III.6.1 The setting: from CP to MCP

The classical-linear-logic-as-session-types correspondence opens with Caires and Pfenning's "Session Types as Intuitionistic Linear Propositions" (CONCUR 2010) and reaches its classical-linear form in Wadler's "Propositions as Sessions" (ICFP 2012, journal version JFP 2014) [Wadler 2012; Wadler 2014]. Wadler's CP calculus encodes a session type as a proposition of Classical Linear Logic (CLL), a process as a proof, and the cut rule as a private composition of two processes communicating along the cut formula. The signature property — *deadlock-freedom is cut-elimination* — places CP in the lineage of Curry–Howard concurrency: a typed program is a proof, and the dynamics of the proof system are the operational semantics of the program. Two-party session types fit CP cleanly because the duality `A ⊥ A^⊥` of CLL is exactly the dual of communicating endpoints: if one process offers `A`, the other must offer `A^⊥`, and the cut rule joins them along their shared name.

The architectural problem the CP framework leaves open is *binary*: the duality relation `(_)^⊥` is a binary involution, and the cut rule joins exactly two proofs. Real-world distributed protocols are not binary. A three-party negotiation, an n-party broadcast, an arbitrarily-sized atomic-commit — each demands a notion of compatibility that ranges over an arbitrary number of types. This is the load-bearing question that Carbone–Lindley–Montesi–Schürmann–Wadler's "Coherence Generalises Duality: A Logical Explanation of Multiparty Session Types" (CONCUR 2016) takes up [Carbone et al. 2016]. The paper introduces Multiparty Classical Processes (MCP), a calculus that *replaces* the binary duality of CLL with a new n-ary compatibility relation called **coherence**, and *replaces* the binary cut rule of CLL with a new n-ary cut rule, the *multiparty cut*, that composes an arbitrary number of processes communicating in a single multiparty session.

### §III.6.2 Coherence as the n-ary duality relation

The technical move is structural. CLL's duality is the relation `A ⊥ A^⊥`: a binary, involutive, type-level predicate that says "these two propositions are in dual position." The multiparty cut rule of CLL would, naively, be a generalisation of `A ⊥ A^⊥` to a relation `coh(A_1, ..., A_n)` saying "these n propositions are mutually compatible." Carbone et al. give exactly this: a *coherence* judgment relating an n-tuple of session types, with each position interpreted as the local-protocol type for one participant in an n-ary session. The judgment `⊢ G :: A_1, ..., A_n` reads as: there exists a global protocol `G` (a coherence proof, viewed as a global type) such that the local types `A_1, ..., A_n` are mutually consistent realisations of `G`. The relation reduces to ordinary duality when `n = 2`: a binary coherence proof is exactly a duality witness `A_1 ⊥ A_2`.

The structural significance of this move is that it *eliminates* the projection-with-merge architecture that classical multiparty session types (Honda–Yoshida–Carbone, POPL 2008) rely on. In the Honda–Yoshida–Carbone tradition, the global type `G` is a separate syntactic object; local types `T_i` are obtained by *projection* `G ↾ p_i`; merge operators `T_i ⊔ T_j` patch the projections together when participants make non-uniform choices. Coherence collapses this three-step pipeline into one judgment. There is no separate global type, no projection function, no merge operator. The coherence proof *is* the global type; the local types are positions in the proof; consistency is the existence of the proof. Architecturally, this is the same move the Prologos polynomial-functor framework makes: replace the projection-with-merge ladder with a single algebraic object that carries n-ary structure intrinsically.

### §III.6.3 The multiparty cut rule MCUT

The cut rule of CLL is, in standard sequent presentation:

```
⊢ Γ, A      ⊢ Δ, A^⊥
─────────────────────  Cut
       ⊢ Γ, Δ
```

Two proofs of complementary sequents are composed by gluing them along the cut formula `A` (which appears as `A` in one and as its dual `A^⊥` in the other). Cut-elimination — the metatheorem that any proof using cuts can be transformed into a cut-free proof — is the static guarantee that the composed system computes without deadlock.

The MCP multiparty cut rule MCUT generalises Cut to compose an arbitrary number of proofs along a coherence proof:

```
⊢ G :: A_1, ..., A_n        ⊢ Γ_1, A_1   ...   ⊢ Γ_n, A_n
──────────────────────────────────────────────────────────  MCUT
                ⊢ Γ_1, ..., Γ_n
```

Here `G` is the coherence proof (the global type). Each premise `⊢ Γ_i, A_i` is the local proof for participant `i` — a process that offers session type `A_i` to its peers. The conclusion glues the n premises into a single composite system whose external interface is the disjoint union of the participants' non-session contexts. The *admissibility* of MCUT (the metatheorem that any proof using multiparty cuts reduces to a proof using only standard CLL cuts) is the deadlock-freedom guarantee for multiparty sessions.

The proof of admissibility is constructive: Carbone et al. exhibit an *arbiter process* that mediates the n-ary communication. The arbiter is a single auxiliary process compiled from the coherence proof `G`; it is connected by binary CLL-cuts to each of the n participants; and it forwards messages between participants according to the protocol described by `G`. Operationally, the arbiter is a centralised coordinator. Logically, it is the cut-elimination witness: the multiparty cut rule is admissible because every multiparty session can be decomposed into binary sessions through an arbiter, and the binary sessions are CLL-cut-eliminable.

### §III.6.4 GCP: the intermediate calculus

To make the admissibility proof tractable, Carbone et al. introduce *Globally-governed Classical Processes* (GCP), an intermediate calculus between MCP and CP. GCP uses coherence as a typing discipline (like MCP) but compiles cleanly to CP via the arbiter construction. The semantics-preserving translations form a chain:

```
MCP  ──[introduce arbiter]──>  GCP  ──[binary cuts only]──>  CP
```

The architectural reading of this chain is that *coherence is admissibly reducible to duality plus an arbiter*. The coherence proof `G`, viewed as a global type, becomes an arbiter process; the n-ary cut becomes n binary cuts that connect each participant to the arbiter; and the multiparty session is implemented as a star-topology of binary sessions. This is structurally identical to the *centralized choreography compilation* in choreographic programming: a global program (the choreography) is compiled to per-participant code (the projections) plus, in some implementations, a coordinator. The MCP/GCP/CP chain is the proof-theoretic version of this compilation pattern.

### §III.6.5 Multiparty Classical Choreographies and hypersequents

Carbone–Montesi–Schürmann–Wadler's "Multiparty Classical Choreographies" (LOPSTR 2018, journal version 2020) [Carbone et al. 2018] extends the MCP architecture from processes to *choreographies*. The shift is in the syntactic level at which the protocol is expressed: in MCP, processes are written individually and typed by coherence; in MCC, a choreography is a single global program that *describes* the multiparty interaction from a holistic viewpoint, and the processes are obtained by projection. The choreography-as-coherence-proof move is now explicit: a coherence proof in MCP corresponds to a global protocol; a global program in MCC is a syntactic representation of that proof.

The technical novelty is the use of *hypersequents* to record parallelism. A standard sequent `Γ ⊢ Δ` records one *thread* of derivation; a hypersequent `Γ_1 ⊢ Δ_1 || Γ_2 ⊢ Δ_2 || ... || Γ_n ⊢ Δ_n` records n parallel threads, separated by `||`. In MCC, each `||`-separated component represents one participant's local typing context, and the hypersequent as a whole is the type of the choreography. Inference rules act on hypersequents and respect the parallelism: rules that operate within a single component represent local computation, and rules that cross components represent communication. The hypersequent is the syntactic shape that records "we have n parallel threads, and here is how they synchronise."

The MCC paper develops two further extensions that the architectural target finds noteworthy. First, *server invocation*: the choreography can invoke a replicated server, modelled as a `!`-modal session in linear logic. Second, *logic-driven compilation*: the compilation of a choreography to processes is read off from the coherence proof's structure — the proof's branches dictate the projection's branches, and there is no separate merge operator to reconcile divergent local views. The merge operator is *eliminated* in the same way it is eliminated in MCP: coherence subsumes the role merge plays in projection-with-merge architectures, by carrying n-ary structure intrinsically rather than synthesising it from per-participant projections.

### §III.6.6 Connection to the architectural target

The architectural significance of MCC is that it validates one half of the polynomial-functor framework's claim: a single n-ary algebraic relation (coherence) subsumes the projection-with-merge ladder. The other half — that the n-ary algebraic relation should be *quantale-enriched* and should compose under bicategorical structure — is not yet present in MCC. Coherence in MCC is a Boolean predicate (either the proof exists or it does not); it carries no cost grading, no fairness ordering, no resource bound. The Prologos contribution at this point is precisely to *enrich* coherence into a quantale-valued judgment: the coherence proof carries a cost (number of messages, depth of causality, latency under min-plus), and the cost composes under bicategorical composition of polynomial functors.

A second observation is that MCC's hypersequents are syntactically very close to the *position vectors* of polynomial functors. A hypersequent `Γ_1 ⊢ Δ_1 || ... || Γ_n ⊢ Δ_n` records n positions; each position has its own local context (its directions); the parallel-bar `||` is the indication that the positions are independent. The polynomial functor framework gives this shape its algebraic backbone: the positions are an indexing set `A`, the directions are a dependent set `B(a)`, and the n-ary structure of the hypersequent is precisely the polynomial `Σ_{a:A} y^{B(a)}` regarded as a multi-input multi-output interaction protocol.


## §III.7 The Polynomial-Functor Refinement

### §III.7.1 What polynomial functors are

A polynomial functor on the category `Set` is, in its most concrete form, a functor of the shape

```
P(X) = Σ_{a:A} X^{B(a)}
```

where `A` is a set of *positions* and `B(a)` is, for each position `a:A`, a set of *directions*. Equivalently, a polynomial functor is determined by a morphism `f: B → A` in `Set` (or, more generally, in a locally cartesian closed category), and the functor `P` is the composite `Σ_A ∘ Π_f ∘ Δ_B` of base-change operations along the slice categories `Set → Set/A`, `Set/A → Set/B`, `Set/B → Set` [nLab 2025; Kock 2010]. The four-arrow form `1 ← B → A → 1` (where `1` is the terminal object) encodes the full data: source, directions, positions, target. In a locally cartesian closed category `C`, a polynomial functor is a morphism `s ← E → B → t` of `C`, and the functor it generates is `s* ; Π ; Σ` over the slice categories — i.e., pullback, dependent product, dependent sum [Spivak–Niu 2024 §5; Gambino–Kock 2013].

The categorical reading of the position/direction structure is that *positions are the choices the protocol makes* and *directions are the responses the environment can give*. A polynomial functor is, in this reading, a one-step interaction: at each position `a`, the protocol commits to a particular outgoing message (or branch of behaviour), and the environment responds with one of the directions `b ∈ B(a)`. The next interaction is determined by the functor's continuation — the iterated composition of the polynomial with itself, which gives infinite-trace behaviours via the cofree comonad on the polynomial endofunctor.

### §III.7.2 The bicategory `Poly` and lenses as morphisms

Polynomial functors form a *bicategory* `Poly` with rich structure [Spivak–Niu 2024 Chapter 5; Gambino–Kock 2013]. The objects of `Poly` are polynomial endofunctors (or, equivalently, the four-arrow data); the 1-cells are morphisms of polynomial functors; the 2-cells are natural transformations. The morphisms in `Poly` are *lenses*: a lens from a polynomial `p = Σ_a y^{B(a)}` to a polynomial `q = Σ_c y^{D(c)}` is a pair of maps

```
f: A → C    (positions forward)
f^♯: A × D(f(a)) → B(a)   (directions backward)
```

— i.e., a forward map on positions and a *backward* map on directions, indexed by positions. The lens shape is the fundamental morphism of bidirectional interaction: in one direction (positions), information flows forward, from the lens's source to its target; in the other direction (directions), information flows backward. Lenses originated in database theory and bidirectional programming, but in the polynomial-functor setting they are recognised as the natural notion of *interaction protocol* — what one polynomial-functor object can offer to another [Spivak 2019; Niu–Spivak 2024].

The composition product on polynomial functors makes `Poly` a *symmetric monoidal bicategory*, with monoidal structure given by tensor `⊗` (parallel composition of protocols), unit `y` (the identity protocol), and an internal hom `[p, q]` representing "morphisms from `p` to `q`." More: `Poly` is the natural setting for *dependent lenses*, where the directions can depend on the positions, and the dependent-lens structure recovers the dependent-type-theoretic substrate that Prologos's QTT type system already carries. The dependent-lens-as-interaction-protocol perspective is the Spivak–Niu monograph's main contribution: the polynomial-functor bicategory is, structurally, the right setting for typed interaction.

### §III.7.3 Polynomial functors versus operads

The user's correction to the operad framing is load-bearing. An *operad* is a structure where each operation has multiple inputs and a single output (or, dually, a single input and multiple outputs in a *cooperad*). The composition of operad operations is *substitution*: an n-ary operation `f` and n further operations `g_1, ..., g_n` compose to a single operation `f ∘ (g_1, ..., g_n)`. Operads are the natural algebraic structure for systems where the *number of inputs* varies but the output is always one-dimensional.

Polynomial functors are *strictly more general*. A polynomial functor `Σ_a y^{B(a)}` encodes both *positions* (the choices the protocol makes — corresponding to operation labels) and *directions* (the responses, which are themselves indexed by positions — corresponding to the *inputs* of the operation, but where the input arity can vary per operation and the inputs can be heterogeneous). The relationship between operads and polynomial functors is that polynomial monads correspond to Σ-free operads under a suitable identification [Gambino–Kock 2013 §5; Weber 2015]: an operad `T` whose symmetric-group action is free gives rise to a polynomial monad `PT`, and conversely, polynomial monads are the Σ-free operads. The *bicategory* of polynomial functors is the right setting for multi-party interaction because it preserves the position-direction structure that operads collapse: in `Poly`, a 1-cell from `p` to `q` distinguishes which positions are mapped where and which directions flow back, while in an operad, this dual structure is flattened into a single arrow.

For multiparty session types, the operadic perspective is *insufficient*. An operad describes a protocol with one consumer and many producers (or vice versa); a multiparty session has *symmetric* n-ary interaction, where each participant is both a producer and a consumer at different points in the protocol. The polynomial-functor bicategory captures this through dependent lenses: each participant's interaction is a polynomial `p_i`, and the multiparty session is a 1-cell in `Poly` whose source is the tensor product `p_1 ⊗ ... ⊗ p_n` and whose target is the unit (or another tensor product representing the post-protocol state). The bicategorical composition gives the algebra of protocol composition.

### §III.7.4 Why this is the architecturally-correct setting

Three properties of `Poly` make it the correct setting for the Prologos architectural target:

(1) **Position-direction asymmetry preserved**: lenses preserve the distinction between positions (forward) and directions (backward), which is the structural shape of bidirectional interaction. Operads collapse this asymmetry; `Poly` preserves it.

(2) **Dependent-lens structure**: the directions can depend on the positions, recovering the dependent-type-theoretic substrate that Prologos already carries via QTT. This is the bridge between the protocol layer and the type-theoretic layer.

(3) **Bicategorical composition**: the composition product on polynomials gives a *bicategorical* algebra, where 1-cells (protocols) compose, 2-cells (refinements) provide a notion of behavioural equivalence, and the entire structure assembles into a symmetric monoidal bicategory. This is strictly more structure than the categorical algebra of either (a) projection-with-merge, which gives no compositional algebra at all, or (b) operadic algebra, which gives a 1-categorical algebra without the 2-cell structure that captures refinement.

The connection to MCC's coherence-as-n-ary-duality is now visible: an n-ary coherence relation `coh(A_1, ..., A_n)` is, in `Poly`, a 1-cell from `A_1 ⊗ ... ⊗ A_n` (the tensor product of the participants' positions) to the unit (the empty protocol). A coherence proof is an inhabitant of this 1-cell. The MCC architecture is, in this view, the *symmetric monoidal subcategory* of `Poly` where the 1-cells are coherence-witnessed compositions of binary linear-logic protocols. The Prologos architectural contribution is to *extend* this from the symmetric monoidal subcategory to the full bicategory `Poly`, and to *enrich* the bicategory with quantale-valued 2-cells that grade the coherence by cost, fairness, latency, and resource consumption.


## §III.8 Choreographic Programming — Categorical Content

The async research artifact §6.1 [Phase 1 §6.1] surveys the major surface-level choreographic-programming systems: Cruz-Filipe–Montesi's *Core Choreographies* (TCS 2020) [CFM20], the Coq-mechanised "Formal Theory of Choreographic Programming" (JAR 2023) [CFM23], Hirsch–Garg's *Pirouette* (POPL 2022) [HG22], the *Chorλ* lineage including HasChor (ICFP 2023) [SKK23] and ChoRus (CP 2024) [Shen24], Plyukhin–Peressotti–Montesi's *Ozone* (ECOOP 2024) [PPM24], Samuelson–Hirsch–Cecchetti's *λ_QC* (OOPSLA 2025) [SHC25], Lam–Hirsch–Cecchetti's "We Know I Know You Know" (arXiv 2024) [LHC24], and Bak–Urschumzew's *Choreographic Programming in Modal Type Theory* (CP 2024) [BU24]. The architectural target this slice serves does not need to re-cover the surface. What it needs is the *categorical content* — what these systems are, structurally, and how they relate to the polynomial-functor bicategory `Poly`.

### §III.8.1 Endpoint projection as opcartesian lift

Choreographic programming's central construction is *endpoint projection* (EPP): a function `⟦·⟧_p` that takes a global choreography `C` and returns the local program for participant `p`. Operationally, EPP is straightforward — it walks the syntax tree of the choreography and, at each communication action, emits the relevant fragment for `p` (a send if `p` is the sender, a receive if `p` is the receiver, nothing if `p` is neither). The categorical reading is more subtle.

Consider a choreography over a finite set of participants `P = {p_1, ..., p_n}`. The participant set carries a natural lattice structure: subsets of `P` ordered by inclusion. The empty subset is the "no participant involved" type (top of the powerset lattice as a coslice); the full set `P` is the global choreography. Each subset `S ⊆ P` indexes a typing judgment: a choreography typed at `S` involves only the participants in `S`. Projection `⟦·⟧_p` is a function from the global choreography (typed at `P`) to a local program (typed at `{p}`). Generalising: there is a projection `⟦·⟧_S` for each subset `S`, returning the choreography restricted to `S`'s participants.

The categorical content is that *the projections form a fibration* over the participant lattice. The total category has, as objects, choreographies typed at subsets of `P`; as morphisms, behaviour-preserving refinements. The base category is the participant lattice. The projection `S ⊆ P → ⟦·⟧_S` is the *opcartesian lift* of the inclusion `S ⊆ P` — it is the universal way of turning a globally-typed choreography into a locally-typed one. The fibration structure is the categorical bookkeeping that "projection commutes with substitution and refinement," which is exactly the metatheorem that every choreographic programming paper proves (under various names: EPP soundness, EPP completeness, projection–reduction commutativity).

This view does not appear explicitly in any choreographic-programming paper to date. Pirouette [HG22] proves the metatheoretic properties pointwise in Coq. Chorλ [CGL+22] proves them for its λ-calculus. λ_QC [SHC25] proves them with location-set polymorphism in Rocq. None of these papers articulates "EPP is an opcartesian lift in a fibration over the participant lattice." The Bak–Urschumzew modal-type-theory translation [BU24] is the closest: it represents location annotations as MTT modalities, and modalities in MTT *are* exactly the slice-fibration structure that opcartesian lifts inhabit. The conjecture that all of Chorλ embeds in MTT [BU24] is, structurally, the conjecture that the entire Chorλ choreography category embeds in the slice category over the participant set — which is the polynomial-functor bicategorical context that Spivak–Niu [2024] develops.

### §III.8.2 Pirouette and the higher-order step

Pirouette [HG22] is the first language for typed higher-order functional choreographic programming. Its type system is parametric in a *local* language of messages: the choreography is a typed term in a meta-language, and the messages exchanged are terms in a sub-language. The metatheorem is that message type soundness *implies* deadlock freedom: if the messages in the local language are well-typed, the choreography is deadlock-free.

The categorical content of Pirouette's higher-order step is the Cartesian-closed structure of the choreography category. In a first-order choreographic language (Core Choreographies, Chorλ in its original simple-typed form), the choreography category is essentially the simply-typed lambda calculus' category — a Cartesian category where types are participant-annotated and morphisms are choreographic terms. Higher-order choreographies require the choreography category to be Cartesian *closed*: an internal hom `[A, B]` represents "a choreography taking an A-typed input and producing a B-typed output." Pirouette delivers this via System-F-style universal quantification over local types.

The fibrational/lens structure becomes more delicate at higher order. A higher-order choreographic value `f: [A, B]` carries with it the participant set it is defined over; passing `f` to a different choreographic context requires lifting along the participant-lattice fibration. This is exactly the *dependent-lens* shape: the function's positions (the choices it makes) and directions (the responses it expects) are indexed by a context that itself varies. In `Poly`, this is captured by the *internal hom* `[p, q]` of the bicategory; in Pirouette's metatheory, it is captured pointwise by an inductive Coq proof.

### §III.8.3 λ_QC and location-set polymorphism

Samuelson–Hirsch–Cecchetti's *λ_QC* (OOPSLA 2025) [SHC25] is the most recent significant advance: the first typed choreographic language with first-class process names and *polymorphism over both types and sets of locations*. The location-set polymorphism is the categorical novelty. Where prior choreographic languages quantified over types (System-F-style polymorphism), λ_QC quantifies over *sets of locations* — i.e., over the elements of the participant lattice itself. A polymorphic choreography of type `∀(L : Locations). C[L]` is a function that takes a participant set as argument and returns a choreography defined over that set.

The categorical content of location-set polymorphism is *exactly* dependent typing in continuation positions. In a polynomial-functor framework, a choreography is a polynomial `Σ_{a:A} y^{B(a)}` where `A` is the set of choreographic terms and `B(a)` is the set of participant configurations under which `a` makes sense. A location-set polymorphic choreography is one where the directions `B(a)` are themselves indexed by location-set choices. This is the dependent-lens shape that Spivak–Niu [2024] give as the natural notion of interaction protocol with dependent boundaries.

The architectural significance is that location-set polymorphism *is what dependent types in continuation positions give for free* in the polynomial-functor framework. λ_QC achieves this through bespoke type-system engineering and a Rocq mechanisation; the polynomial-functor framework would deliver it as a structural consequence of the bicategorical composition of dependent lenses. Samuelson–Hirsch–Cecchetti's contribution is to demonstrate that the resulting language is operationally usable; the polynomial-functor framework's contribution is to explain *why* the construction works.

### §III.8.4 Multicast and multiply-located values

Lam–Hirsch–Cecchetti's "We Know I Know You Know: Choreographic Programming with Multicast and Multiply Located Values" (arXiv 2403.05417, 2024) [LHC24] introduces a different escape from projection-with-merge: instead of merging divergent local views, *multiply-locate* the values. A multiply-located value `v @ {p_1, p_2, p_3}` resides simultaneously at three participants. A conditional `if v @ {p_1, p_2, p_3} then ...` requires the guard to be located at all three; consequently, all three participants take the same branch *because they share knowledge of the guard*, not because a select operation is exchanged at runtime. This eliminates the special "select" syntax that prior choreographic languages used, replacing it with a typing constraint.

The categorical content is the *common-knowledge* fragment of epistemic logic. A multiply-located value is, in epistemic terms, a value about which all the participants in its location set have common knowledge. The Lam et al. construction implicitly typechecks against an epistemic-logic side-condition: the guard of every conditional must reside in a location set whose participants share common knowledge of the guard's value. Bak–Urschumzew's modal-type-theory interpretation [BU24] makes this explicit: location modalities in MTT are *exactly* the modal operators of common knowledge, and a choreographic typing judgment is implicitly a derivation in a modal logic where each modality represents knowledge held by a specific participant.

The polynomial-functor framework subsumes this. Multiply-located values are dependent-lens values where the directions (the participants who hold the value) are indexed by the value's content. The polynomial `Σ_{v:V} y^{Holders(v)}` represents a value `v` together with the set `Holders(v) ⊆ P` of participants who hold it. Common knowledge is the property `Holders(v) = P` (everyone holds it); shared knowledge is `Holders(v) = S ⊆ P` (a subset holds it). Conditionals on multiply-located values typecheck because the branch decision is consistent across all members of the location set — i.e., the lens's directions are uniform.

### §III.8.5 The Bak–Urschumzew modal-type-theory translation

Bak–Urschumzew's *Choreographic Programming in Modal Type Theory* (CP 2024) [BU24] gives the first explicit categorical embedding of choreographic programming. The construction: location annotations in Chorλ are translated to modalities in Multimodal Dependent Type Theory (MTT). A type `Int @ Alice` becomes `□_Alice Int` (the type of integers held at participant Alice); communication becomes the modal-elimination form. The translation requires two novel concepts — common knowledge between roles, and locally-referenced choreographies — and the conjecture is that all of Chorλ embeds faithfully.

The categorical structure of MTT is exactly the structure the polynomial-functor framework provides. MTT's modal operators are interpretations of right-adjoint slice-fibration structure: a modality `□_p` on the participant `p` is the right adjoint to a forgetful functor that erases `p`-content. The slice-fibration structure over the participant lattice gives, for each participant `p`, exactly such an adjoint. The Bak–Urschumzew conjecture — that all of Chorλ embeds in MTT — is, in the polynomial-functor reading, the conjecture that the choreography category is a slice category over a polynomial-functor object representing the participant lattice. The conjecture is plausible *because* both the choreographic category and the slice category have the same algebraic structure; what remains is to prove the embedding preserves the operational semantics.

### §III.8.6 What none of the choreographic languages do

The choreographic-programming literature, as surveyed above, achieves a great deal: it eliminates explicit merge operators (Pirouette, Chorλ, λ_QC); it introduces higher-order and polymorphic abstraction (Pirouette, λ_QC); it offers a modal-type-theoretic embedding (Bak–Urschumzew); it scales to real protocols (the IRC implementation in Choral [LM24]). What it does *not* achieve — and what the architectural target the present synthesis serves does — are the following:

(1) **No quantale-enriched extension**: no choreographic language carries cost, latency, fairness, or resource grading on its types. Endpoint projection is treated correctness-only; the cost-of-projection question is unaddressed [Phase 1 §6.6 gap (a)].

(2) **No bicategorical composition**: choreographic languages compose at the syntactic level (sequencing, branching) but not at the *bicategorical* level where 2-cells represent refinement equivalences. The closest is Choral's refinement system, which is operational rather than categorical.

(3) **No unification with binary session types under one framework**: choreographic programming and binary session types coexist as separate disciplines in the literature. The polynomial-functor framework promises one bicategory `Poly` whose 1-cells are *both* binary session types (when the position set has cardinality 2) *and* multiparty choreographies (when cardinality > 2).

(4) **Explicit choreography syntax required**: every choreographic language in the literature requires a separate syntactic level for choreographies — they cannot be expressed in the host's existing type/term language without language extension. The polynomial-functor framework lets multiparty choreographies *fall out* as combinations of binary primitives, with no separate choreography syntax.


## §III.9 The Unifying Observation: MCC as Binary-Case Validator for the Polynomial-Functor Framework

### §III.9.1 Coherence as the symmetric monoidal subcategory

The architectural picture that emerges from §§III.6–III.8 has a striking unification. MCC's coherence relation `coh(A_1, ..., A_n)` is, in the polynomial-functor bicategory `Poly`, the existence of a 1-cell from the tensor product `A_1 ⊗ ... ⊗ A_n` to the unit (or to another tensor product, if the protocol has continuation). The MCUT rule's admissibility — the metatheorem that every n-ary cut reduces to binary cuts via an arbiter — is the operational statement that the bicategory `Poly` has a *symmetric monoidal* structure: 1-cells compose, the composition is associative up to coherent isomorphism, and the symmetry is given by the participant permutation.

This is not a metaphor. The structural identification is: **the symmetric monoidal subcategory of `Poly` whose 1-cells are CLL-cut-elimination-witnessed compositions of binary linear-logic types is precisely the MCP/GCP/CP architecture restricted to the binary case**. MCC adds hypersequents to make the position structure explicit; the polynomial-functor framework absorbs the hypersequent into the position-vector of the polynomial. MCP's coherence is the *Boolean* fragment of the bicategorical 1-cell structure of `Poly` — the predicate version of the existence of a 1-cell.

### §III.9.2 Choreographic projection as opcartesian lift

§III.8.1 articulated the categorical content of endpoint projection as an opcartesian lift in a fibration over the participant lattice. The polynomial-functor framework gives this a concrete realisation: the participant lattice is the slice `Set/P` over the participant set; the fibration is the polynomial-functor slice-fibration; the opcartesian lift is base-change along the inclusion `S ⊆ P`. This is the construction that Spivak–Niu [2024 §5] develop for arbitrary polynomial functors over a locally cartesian closed category.

Pirouette's metatheorem (EPP soundness + completeness) is the operational claim that the opcartesian lift exists and is unique. λ_QC's location-set polymorphism is the dependent-lens version of the same lift. HasChor's monadic implementation is a Haskell-level realisation of the slice-category structure. Bak–Urschumzew's MTT translation is an explicit categorical embedding that makes the lift visible. *Each of these systems is implementing a particular instance of the polynomial-functor opcartesian-lift construction*, but none names it.

### §III.9.3 Why the unification matters architecturally

The unification matters because it dissolves the apparent fragmentation of the multi-party-protocol literature. Binary session types, multiparty session types, choreographic programming, and modal-type-theory choreography appear in the literature as separate disciplines with separate metatheories, separate proof techniques, and separate implementations. The polynomial-functor unification says: they are all *one bicategory*. The 1-cells differ in cardinality (binary, n-ary), in dependency structure (location-polymorphic, dependent), and in modality (knowledge-typed, multimodal), but the bicategorical algebra is uniform.

For Prologos, this is the architectural foundation. The propagator-network substrate already carries lattice-valued cells; the cells form a slice fibration over the participant lattice; the polynomial-functor structure is a natural extension. The quantale-enriched grading is the additional structure that takes the framework beyond what any of the existing systems achieve: cost, latency, fairness, and resource consumption become *2-cells in the bicategory*, gradings of the morphisms that compose them.


## §III.10 Where MCC and Choreographic Programming Fall Short of the Prologos Architectural Target

The preceding sections argued that MCC and choreographic programming are validators for the polynomial-functor framework. They are also, *individually*, insufficient as foundations for the architectural target. The shortfalls are concrete and structural.

### §III.10.1 MCC is syntactic, not categorical

MCC delivers the n-ary coherence move but in a *syntactic linear-logic form*, not categorical or operational. The coherence judgment `⊢ G :: A_1, ..., A_n` is a sequent-calculus relation; its meaning is given by inference rules, not by a categorical model. The translation from coherence proofs to arbiters is a syntactic compilation, not an operational one with quantitative properties. The hypersequent structure of MCC is a logical-syntactic device for tracking parallelism, not a categorical one — there is no claim that hypersequents form a polynomial-functor object, or that the multiparty cut rule is bicategorical composition.

The polynomial-functor framework requires a *categorical model* of multiparty session types, not just a syntactic calculus. The arbiter construction in MCP/GCP gives the right operational picture for the binary projection of multiparty sessions, but it does not give the bicategorical algebra of n-ary composition. MCC's coherence is necessary; it is not sufficient.

### §III.10.2 Choreographic programming does not unify with binary session types

Choreographic programming and binary session types coexist in the literature as separate disciplines. Pirouette is a *choreographic* language with a separate metatheory; CP/πDILL is a *session-type* language with a separate metatheory. The two communities have different proof techniques, different implementations, different metatheoretic claims. There is no single framework — no single bicategory, no single typing discipline — that subsumes both.

The polynomial-functor framework promises this unification. Binary session types are 1-cells in `Poly` between unary objects (`p_1 → p_2`); n-ary multiparty choreographies are 1-cells with multi-input boundary (`p_1 ⊗ ... ⊗ p_n → q`). The composition is bicategorical; the metatheory is uniform. The choreographic literature's failure to deliver this unification is the structural gap that the polynomial-functor framework fills.

### §III.10.3 No cost-aware realizability

Neither MCC nor choreographic programming carries cost, latency, fairness, or resource grading. Coherence is a Boolean predicate; endpoint projection is a correctness-only construction. The async research artifact §6.6 gap (a) [Phase 1 §6.6] explicitly catalogues this: no published frontier paper formulates choreographic projection as a quantale-enriched morphism. The cost-of-projection question is unaddressed.

This is the most significant architectural gap. Prologos's effect-ordering quantale and tropical-quantale cost layer give the substrate to *grade* coherence and projection by quantale-valued costs. The polynomial-functor framework provides the bicategorical home for these quantale-valued morphisms. Together, the substrate and the framework give cost-aware realizability — the operational guarantee that not only does the protocol work, but it works *within a budget* expressed in the quantale.

### §III.10.4 No conjunctive-refinement bundle integration

The Prologos trait/protocol composition pattern is *conjunctive refinement*: a bundle `Num := (Add Sub Mul)` is the conjunction of three trait obligations, and refinement composes by intersection of the obligation sets. This pattern is structurally different from the merge operator of choreographic programming: merge is a *coproduct-like* operation that synthesises a common subbehaviour from divergent ones, while conjunctive refinement is a *product-like* operation that intersects refinement obligations.

Neither MCC nor choreographic programming integrates with conjunctive refinement. MCC's coherence is a single n-ary judgment; it does not compose by intersection of refinement obligations. Choreographic programming's projection-with-merge composes by least-upper-bound on local types, which is a coproduct-like operation. The polynomial-functor framework gives both: the *meet* of two protocols (bicategorical product of 1-cells) is conjunctive refinement, and the *join* (bicategorical coproduct) is the merge operator. The framework subsumes both compositional patterns under one algebraic structure.

### §III.10.5 Explicit choreography syntax required

Every choreographic language in the literature requires a *separate syntactic level* for choreographies. Pirouette has its own type system; Chorλ has its own λ-calculus extension; λ_QC has its own location-set polymorphism. A program in choreographic style is a different kind of program from a program in regular style — it cannot be expressed in the host's existing type/term language without language extension.

The polynomial-functor framework promises to *let multiparty choreographies fall out* of binary primitives. A choreography is a 1-cell in `Poly`; an n-ary choreography is a 1-cell with multi-input boundary; the composition is bicategorical. There is no separate syntactic level — choreographies are programs in the host language, with the polynomial-functor structure providing the typing discipline. The Bak–Urschumzew MTT translation [BU24] is the closest to this vision, but it remains a *translation* from a separate choreographic language into MTT, not a native expression of choreographies in MTT itself.

### §III.10.6 The synthesis claim

The Prologos architectural target — multi-party protocols as polynomial functors over a quantale-valued propagator runtime, with role projection as opcartesian lifts in a fibration, behaviour as coalgebras, realizability as a quantale-valued fixpoint, composition as conjunctive refinement — is the *unification* of these scattered insights into one framework. MCC validates the n-ary coherence move; choreographic programming validates the projection-as-functor move; the polynomial-functor bicategory `Poly` provides the algebraic home; the quantale-enriched extension provides the cost-aware realizability; the conjunctive-refinement pattern provides the bundle algebra; the propagator-network substrate provides the operational realisation.

Each piece has prior art. *None of the prior art has assembled them into one system*. The architectural target is the assembly.


## References

**Bak & Urschumzew 2024.** Miëtek Bak and Maxim Urschumzew. "Choreographic Programming in Modal Type Theory." Workshop on Choreographic Programming (CP 2024), co-located with PLDI 2024. *Annotation*: Talk-level treatment proposing translation of Chorλ programs into Multimodal Dependent Type Theory (MTT), interpreting location annotations as modalities and requiring two novel concepts — common knowledge between roles and locally-referenced choreographies. The conjecture is that all of Chorλ embeds faithfully in MTT. The construction is the closest existing approximation to a categorical embedding of choreographic programming. https://pldi24.sigplan.org/details/cp-2024-papers/7/Choreographic-Programming-in-Modal-Type-Theory

**Caires & Pfenning 2010.** Luís Caires and Frank Pfenning. "Session Types as Intuitionistic Linear Propositions." *CONCUR 2010*. *Annotation*: Initial Curry–Howard correspondence between session types and intuitionistic linear logic. Foundation of the proof-theoretic line that Wadler's CP, MCP, and the present synthesis extend.

**Carbone et al. 2016.** Marco Carbone, Sam Lindley, Fabrizio Montesi, Carsten Schürmann, and Philip Wadler. "Coherence Generalises Duality: A Logical Explanation of Multiparty Session Types." *CONCUR 2016*, LIPIcs Vol. 59, pp. 33:1–33:15. *Annotation*: **Load-bearing**. Introduces Multiparty Classical Processes (MCP), generalising the duality of CLL to a new n-ary compatibility relation (coherence) and the cut rule to an n-ary multiparty cut (MCUT). Defines Globally-governed Classical Processes (GCP) as an intermediate calculus. Proves admissibility of MCUT via the arbiter construction: a coherence proof compiles to an auxiliary process that mediates n-ary communication via binary CLL-cuts. Establishes the structural identity that, in the binary case (n=2), coherence reduces to duality and MCUT to ordinary Cut. Architecturally, this paper validates the n-ary-compatibility move that the polynomial-functor framework absorbs into bicategorical 1-cell existence. https://drops.dagstuhl.de/entities/document/10.4230/LIPIcs.CONCUR.2016.33

**Carbone et al. 2018.** Marco Carbone, Fabrizio Montesi, Carsten Schürmann, and Philip Wadler. "Multiparty Classical Choreographies." *LOPSTR 2018*, LNCS 11408, pp. 59–76. Springer 2019. (Journal version 2020.) *Annotation*: **Load-bearing**. Extends MCP to a *choreography* level: a choreography is a global program from which processes are projected, and typing uses *hypersequents* to record parallelism explicitly. Adds support for server invocation (replicated processes) and logic-driven compilation of choreographies. Eliminates the merge operator: the projection from choreography to process is read directly off the proof structure. Architecturally, this paper validates the choreography-as-coherence-proof identification and provides the syntactic shape (hypersequent) that becomes the polynomial-functor position-vector. https://link.springer.com/chapter/10.1007/978-3-030-13838-7_4 (arXiv: https://arxiv.org/abs/1808.05088)

**Carbone, Montesi & Schürmann 2018.** Marco Carbone, Fabrizio Montesi, and Carsten Schürmann. "Choreographies, Logically." *Distributed Computing*, journal version of CONCUR 2014 paper. *Annotation*: Linear Compositional Choreographies (LCC), a proof theory for choreographies that combines choreographies with processes and logically reconstructs projection. Important predecessor of MCC; develops the proof-theoretic foundation that MCC formalises in classical-linear-logic terms. https://link.springer.com/article/10.1007/s00446-017-0295-1

**Carbone et al. 2016b (Acta Informatica).** Marco Carbone, Sam Lindley, Fabrizio Montesi, Carsten Schürmann, Philip Wadler. "Multiparty Session Types as Coherence Proofs." *Acta Informatica*. *Annotation*: Journal-level expansion of the CONCUR 2016 paper with full proofs and additional connections to multiparty session types as coherence proofs.

**Cruz-Filipe & Montesi 2020 [CFM20].** Luís Cruz-Filipe and Fabrizio Montesi. "A Core Model for Choreographic Programming." *Theoretical Computer Science*, 2020. *Annotation*: Core Choreographies (CC) — minimal calculus for choreographic programming with Turing-completeness result. Establishes endpoint projection as the canonical operation and deadlock-freedom as a structural property. Predates but motivates the typed/higher-order extensions the present synthesis surveys.

**Cruz-Filipe & Montesi 2023 [CFM23].** Luís Cruz-Filipe, Fabrizio Montesi, et al. "A Formal Theory of Choreographic Programming." *Journal of Automated Reasoning* 67(2):21, 2023. *Annotation*: Coq-mechanised theory of choreographic programming with EPP soundness and completeness. The most rigorous metatheoretic treatment to date. Operates at the syntactic level; the categorical content is implicit in the Coq formalisation but not articulated. https://link.springer.com/article/10.1007/s10817-023-09665-3

**Cruz-Filipe et al. 2022 [CGL+22].** Luís Cruz-Filipe, Eva Graversen, Lovro Lugovic, Fabrizio Montesi, and Marco Peressotti. "Functional Choreographic Programming." *ICTAC 2022*, LNCS 13572, pp. 212–237. *Annotation*: Chorλ — λ-calculus-based choreographic language with role-annotated types. The "located-types" discipline. Independent of and contemporaneous with Pirouette.

**Gambino & Kock 2013.** Nicola Gambino and Joachim Kock. "Polynomial Functors and Polynomial Monads." *Mathematical Proceedings of the Cambridge Philosophical Society* 154(1):153–192, 2013. *Annotation*: Foundational paper on polynomial functors over locally cartesian closed categories. Establishes the bicategorical structure of polynomial functors, the relationship between polynomial monads and Σ-free operads, and the framed bicategory in which polynomial functors live. The Joyal–Kock lineage that Spivak–Niu's monograph builds on. https://arxiv.org/abs/0906.4931

**Hirsch & Garg 2022 [HG22].** Andrew K. Hirsch and Deepak Garg. "Pirouette: Higher-Order Typed Functional Choreographies." *Proc. ACM Program. Lang.* 6(POPL), Article 23, pp. 1–27, 2022. *Annotation*: First language for typed higher-order functional choreographic programming. Parametric in a local message language; lifts message-type-soundness to choreography-level deadlock-freedom. Coq-mechanised metatheory. The categorical content (EPP as opcartesian lift in the participant-lattice fibration) is implicit but not articulated. https://dl.acm.org/doi/10.1145/3498684 (arXiv: https://arxiv.org/abs/2111.03484)

**Honda, Yoshida & Carbone 2008.** Kohei Honda, Nobuko Yoshida, and Marco Carbone. "Multiparty Asynchronous Session Types." *POPL 2008*, pp. 273–284. *Annotation*: Originating paper for multiparty session types in the projection-with-merge architecture. The architectural alternative that MCC and the polynomial-functor framework displace.

**Kock 2009.** Joachim Kock. "Notes on Polynomial Functors." Lecture notes, MPRI / UAB, 2009. *Annotation*: Comprehensive lecture-note treatment of polynomial functors with the four-arrow diagrammatic notation, the bicategorical structure, and the connection to operads and W-types. The pedagogical bridge between the abstract categorical literature and the applications to interaction protocols. https://www.irif.fr/~mellies/mpri/mpri-ens/articles/kock-notes-on-polynomial-functors.pdf

**Lam, Hirsch & Cecchetti 2024 [LHC24].** Mako Bates and Joseph P. Near (note: arXiv listing differs from the standard "Lam–Hirsch–Cecchetti" attribution; the published version "We Know I Know You Know" is at arXiv 2403.05417, with author attribution that the present synthesis records as found in the field's primary citations). "We Know I Know You Know: Choreographic Programming with Multicast and Multiply Located Values." arXiv:2403.05417, 2024. *Annotation*: Introduces He-Lambda-Small with multiply-located values and multicasting. Eliminates the "select" operation by requiring conditional guards to reside at all relevant participants. Categorical content: implicit common-knowledge reasoning, made explicit by Bak–Urschumzew's MTT translation. https://arxiv.org/abs/2403.05417

**Lugović & Montesi 2024 [LM24].** Lovro Lugović and Fabrizio Montesi. "Real-World Choreographic Programming: Full-Duplex Asynchrony and Interoperability." *The Programming Journal* 8(2):8, 2024 (arXiv:2303.03983). *Annotation*: First empirical demonstration that choreographic programming scales from formal toy examples to production protocols (IRC client-server). Validates the engineering viability of the choreographic paradigm.

**Niu & Spivak 2024.** Nelson Niu and David I. Spivak. *Polynomial Functors: A Mathematical Theory of Interaction*. London Mathematical Society Lecture Note Series, Number 498. Cambridge University Press 2024. (Preprint: arXiv:2312.00990.) *Annotation*: **Foundational**. The definitive monograph on polynomial functors as a category-theoretic foundation for interaction protocols and dynamical systems. Develops the bicategory of polynomial functors with dependent lenses as morphisms (Chapter 5: composition product). Establishes the symmetric monoidal closed bicategorical structure. Includes sections on dependent lenses as interaction protocols and polybox pictures of dependent lenses. The categorical home for the architectural target the present synthesis serves. The position-direction structure articulated here is what the synthesis identifies as the substrate for multiparty protocols. https://arxiv.org/abs/2312.00990

**Plyukhin, Peressotti & Montesi 2024 [PPM24].** Dan Plyukhin, Marco Peressotti, and Fabrizio Montesi. "Ozone: Fully Out-of-Order Choreographies." *ECOOP 2024*, LIPIcs Vol. 313. *Annotation*: Futures-based non-blocking communication in a choreographic setting. Preserves communication-integrity-violation freedom while permitting out-of-order execution. The closest choreographic-programming work to a quantale-graded extension, though it does not yet formalise the cost grading explicitly.

**Samuelson, Hirsch & Cecchetti 2025 [SHC25].** Ashley Samuelson, Andrew K. Hirsch, and Ethan Cecchetti. "Choreographic Quick Changes: First-Class Location (Set) Polymorphism." *Proc. ACM Program. Lang.* 9(OOPSLA2), Article 336, October 2025. *Annotation*: λ_QC — first typed choreographic language with first-class process names and polymorphism over both types and *sets of locations*. Supports algebraic and recursive data types and multiply-located values. Rocq-mechanised. The location-set polymorphism is exactly what dependent-lens structure in the polynomial-functor framework delivers as a structural consequence. https://dl.acm.org/doi/10.1145/3763114 (arXiv: https://arxiv.org/abs/2506.10913)

**Shen, Kashiwa & Kuper 2023 [SKK23].** Gan Shen, Shun Kashiwa, and Lindsey Kuper. "HasChor: Functional Choreographic Programming for All (Functional Pearl)." *Proc. ACM Program. Lang.* 7(ICFP), Article 207, August 2023. *Annotation*: Choreographies as monadic computations in Haskell. Reduces endpoint projection to its essential core via Haskell's algebraic-type machinery. Supports higher-order and location-polymorphic choreographies. The library-level realisation closest to a polynomial-functor presentation, though it does not name the categorical structure. https://dl.acm.org/doi/10.1145/3607849 (arXiv: https://arxiv.org/abs/2303.00924)

**Shen et al. 2024 [Shen24].** Gan Shen et al. "ChoRus: Choreographic Programming in Rust." *CP 2024*. *Annotation*: Rust library-level choreographic programming framework with first-class location sets. The Rust-level analogue of HasChor.

**Spivak 2019.** David I. Spivak. "Lenses: Applications and Generalizations." Slides from ACT-UCR 2019. *Annotation*: Pedagogical introduction to lenses as the morphisms of the polynomial-functor bicategory and to their applications in interaction modelling. https://math.ucr.edu/home/baez/ACTUCR2019/ACTUCR2019_spivak.pdf

**Wadler 2012.** Philip Wadler. "Propositions as Sessions." *ICFP 2012*. (Journal version: *JFP* 2014.) *Annotation*: Origin of the Classical Processes (CP) calculus — the binary case that MCP and the present synthesis extend. Establishes deadlock-freedom-as-cut-elimination for binary session types. https://homepages.inf.ed.ac.uk/wadler/papers/propositions-as-sessions/propositions-as-sessions.pdf

**Weber 2015.** Mark Weber. "Operads as Polynomial 2-Monads." *Theory and Applications of Categories* 30(49):1659–1712. *Annotation*: Establishes the bijection between operad structures and polynomial-monad structures, distinguishing the operadic and polynomial-functor perspectives. Load-bearing for §III.7's distinction between operads (which collapse the directions structure) and polynomial functors (which preserve it). http://www.tac.mta.ca/tac/volumes/30/49/30-49.pdf

---

## Part IV.5 — Polynomial Functors, Locally Cartesian Closed Categories, and Dependent Type Theory

### §IV.5.1 Polynomial functors: the basic setting

The category of polynomial functors, in the sense made precise by [Niu Spivak 2024], provides the foundational mathematical setting for a unified theory of interaction. Informally, a polynomial functor is a collection of *positions* together with, for each position, a collection of *directions*. Formally, a polynomial endofunctor on the category of sets has the canonical form

  P(y) = Σ_{a ∈ A} y^{B(a)}

where A is a set of positions and B : A → Set is a function assigning to each position a ∈ A a set B(a) of directions [Niu Spivak 2024, §1.3]. The functor sends a set y to the disjoint union, indexed by positions, of the function spaces y^{B(a)}. Positions thus index summands; directions index the exponents of those summands. Equivalently, a polynomial functor is a coproduct of representable functors — each summand a ∈ A corresponds to the representable functor Hom(B(a), −), and the polynomial is their coproduct [nLab 2025, Polynomial functor].

The interpretation that makes this object load-bearing for the present synthesis is the one [Niu Spivak 2024] develop systematically: positions are the *behaviours* a system can offer, and directions are the *channels* — the receptive surface — by which a system behaving at position a interacts with its environment. A polynomial functor is thus a *protocol-shaped object*: a system in position a accepts inputs (or produces outputs, depending on whose perspective is taken) along the directions B(a), and the structure of B varies position by position. This is exactly the conditional-arity behaviour required to model multi-party protocols where the next set of available channels depends on the current state of the protocol.

#### Match with propagator behaviour

The propagator-network substrate underlying the Prologos compiler [CLAUDE.md, Architecture § Propagator Network] gives this abstract structure direct operational meaning. A propagator that watches a set of cells C₁, …, Cₙ and writes, conditionally on what it observes, to one of several output cells, naturally inhabits a polynomial functor whose positions enumerate its branching choices and whose directions, at each position, are the cells it must read or write to fire that branch. Formally:

- **Positions** = branches the propagator may take; equivalently, the discrete cases of its fire function's match. A propagator with k mutually exclusive branches has |A| = k.
- **Directions** = the cells participating in the branch. Different branches read and write different cells (component-paths in the Prologos substrate [propagator-design.md § Component Indexing] are the exact operational realisation: each branch declares which compound-cell components it touches). For branch a ∈ A, B(a) is precisely the set of cells the branch reads or writes.

This is more than a metaphor. The polynomial endofunctor P_propagator(y) = Σ_{a ∈ A} y^{B(a)} is, set-theoretically, the type of "configurations of a propagator parameterised by a continuation type y" — for each position (branch), a function from B(a) (the channels the branch operates on) to y (the resulting state). The free monad on this polynomial (§IV.5.7 below) is the type of all interaction sequences such a propagator can produce. The cofree comonad on the same polynomial is the type of all environments such a propagator can operate within. The on-network mantra "All-at-once, all in parallel, structurally emergent information flow ON-NETWORK" [on-network.md] is, in this language, the requirement that the propagator's polynomial structure be denotationally faithful: positions are independent (parallel-ready), directions are typed (information flows through cells of declared lattice type), and emergence is structural (the polynomial's morphism structure is what determines firing order, not imperative dispatch).

#### Why operads are wrong

The companion temptation is to model a propagator (or, more generally, a multi-party protocol participant) as an *operadic* operation. An operad has operations of fixed input arity and a single output: an n-ary operation θ ∈ O(n) takes n inputs and produces one output, with composition by tree substitution. This is the wrong shape for protocols and propagators for two structural reasons.

First, the *output side is monolithic*. An operadic operation produces a single thing; a propagator (and a protocol participant) produces *different things in different branches*. A propagator that, depending on what it reads, either writes to cell c₁ or to cell c₂ has a nontrivial direction structure that varies with position; an operad encodes only the input arity, not this position-conditioned output structure.

Second, *operads cannot encode conditional arity*. A polynomial functor permits B(a) ≠ B(a') for a ≠ a' — different positions can have different numbers and types of directions. An operad demands that all operations of arity n have the same kind of inputs; it has no slot for "this branch reads three cells; that branch reads two." [Niu Spivak 2024] discuss this contrast at length: operads are a restrictive special case of polynomials in which the direction structure is constant (n-ary operations have n directions, all of the same type) and orientations are uniform.

Polynomial functors capture exactly the asymmetric, position-conditional behaviour that propagators and protocol participants exhibit. This is the categorical reason the Prologos architectural target (§IV.5.0 above, in the parent synthesis) lands on polynomial functors rather than operads.

#### The Joyal-Kock-Melliès lineage

The combinatorial origin of polynomial functors traces to [Joyal 1981], whose theory of *species* introduced functors A : FinBij → Set (or FinBij → Vect_K) as carriers of combinatorial structure with symmetry. Joyal characterised *analytic functors* as those preserving weak pullbacks, cofiltered limits, and filtered colimits [Joyal 1981, Bergeron Labelle Leroux 1998]. The relationship to polynomial functors is precise: polynomial functors on Set are exactly the *flat species* — species whose group actions are free [nLab 2025, Species]. Equivalently, a polynomial endofunctor on Set is the analytic functor associated to a rigid combinatorial structure (no nontrivial symmetries).

[Kock 2010] and the survey [Kock 2009 lecture notes] lifted this combinatorial picture to the categorical level, explicitly developing polynomial functors over arbitrary locally cartesian closed categories. [Gambino Kock 2013] extended further: polynomial functors over LCCCs assemble into a *framed bicategory* (equivalently, a double category whose horizontal and vertical 1-cells admit companions), and the free monad on a polynomial endofunctor is itself polynomial. This last result is structurally important — it tells us the *iterated interaction* generated from a single polynomial protocol stays within the polynomial world, justifying the closure of the framework under behavioural composition.

The computational interpretation — polynomials as interaction protocols, lenses as morphisms of protocols — is the contribution of Spivak's group at the Topos Institute, culminating in the [Niu Spivak 2024] monograph. [Melliès]'s lineage in tensorial logic and dialogue games provides a parallel — combinatorial-game-theoretic rather than dynamical-systems-theoretic — reading of polynomial structure that informs but does not replace the Spivak picture; the present synthesis follows the Spivak reading because it composes natively with propagator semantics.

### §IV.5.2 Polynomial functors in locally cartesian closed categories

The Set-based formulation of §IV.5.1 generalises to an arbitrary locally cartesian closed category (LCCC). This generalisation is what binds polynomial functors to dependent type theory: a dependent type theory's denotational semantics lives in an LCCC [Seely 1984, Hofmann 1997], and the polynomial-functor structure on an LCCC translates directly into structure on the type theory.

#### The general setting

Let C be a LCCC. For each object C, the slice category C/C is itself cartesian closed, and for each morphism f : A → B in C, the pullback functor f* : C/B → C/A has both a left adjoint Σ_f (dependent sum) and a right adjoint Π_f (dependent product), giving the adjoint string

  Σ_f ⊣ f* ⊣ Π_f.

In this setting, a *polynomial* (in the sense of [Gambino Kock 2013]) is a diagram

  W ← X → Y → Z          (with arrows labelled f, g, h say: f : X → W, g : X → Y, h : Y → Z)

and the *polynomial functor* it determines is the composite

  C/W →[f*] C/X →[Π_g] C/Y →[Σ_h] C/Z.

When W = Z = 1 (the terminal object), this reduces to a polynomial endofunctor on C/1 ≅ C. The set-based version of §IV.5.1 is recovered by taking C = Set: a polynomial endofunctor on Set has the form Σ_{a:A} y^{B(a)} where the data (A, B : A → Set) is exactly the data of a single morphism B → A in Set [Gambino Kock 2013, §1].

#### Why LCCCs

The LCCC structure is precisely the structure required for *dependent types*: the existence of slice categories with cartesian-closed structure encodes type families and their function spaces; the existence of pullback right and left adjoints encodes Π and Σ types. [Seely 1984] established the now-classical correspondence between LCCCs (with sufficient structure, satisfying certain coherence conditions) and the interpretation of Martin-Löf type theory; subsequent refinements [Hofmann 1997, Awodey Warren 2009] handled the strictification problems that arise from substitution being interpreted as pullback (only associative up to canonical isomorphism in arbitrary LCCCs, while syntactic substitution must be strictly associative).

The relevant point for the present synthesis is that *the same LCCC machinery that interprets dependent types is exactly what's needed to define polynomial functors*. The Σ_f ⊣ f* ⊣ Π_f adjoint string is simultaneously: (a) the categorical interpretation of dependent sum / weakening / dependent product in a type theory; (b) the Σ/pullback/Π data composing into the polynomial functor C/W → C/Z. These are not two analogous structures; they are the same structure, viewed through two languages.

#### Continuation positions Just Work

The architectural commitment in the synthesis target — *dependent session types in continuation positions Just Work via Σ/Π adjoints* — is exactly this observation, applied at the protocol level. A multi-party protocol is a polynomial functor; a participant's continuation after sending or receiving along a direction is a *type family* over the directions of the current position; the existence of Σ/Π adjoints to weakening means the type family can be summed (forming a position-indexed protocol) or producted (forming a uniformly-quantified continuation), and these operations are the categorical reflection of dependent session-type formers. The user's "Just Work" claim is the statement that the LCCC structure carries this for free — there is no additional structure to add; the dependent-type structure is built into the polynomial-functor framework from the start [Awodey 2018, Awodey Newstead 2018].

This generalisation also delivers the *internal* machinery for working with polynomials: in an LCCC, polynomial functors can themselves be objects of an internal category [Gambino Kock 2013, §3], permitting the development of "polynomial-functor-typed" computation — exactly the position one wants for a propagator network whose cells carry polynomial-shaped data (which is what Prologos's tropical-quantale, effect-quantale, and session-type cells already do, although the existing infrastructure does not yet name the polynomial structure explicitly).

### §IV.5.3 Polynomial universes (Awodey-Hofmann-Streicher-Spivak)

The deepest connection between polynomial functors and dependent type theory is the result, established progressively across a sequence of papers and refined in [Aberlé Spivak 2025], that *type universes are themselves polynomial functors*, and the closure of a universe under the type formers Σ and Π corresponds *exactly* to the polynomial-functor structure on it. This is the content of the *polynomial universes* programme.

#### Hofmann-Streicher universes as polynomial classifiers

The classical Hofmann-Streicher construction [Hofmann Streicher 1997] interprets Martin-Löf type theory in a presheaf category Set^{C^op} by exhibiting a universe (U, El) classifying the small discrete fibrations over C. The universe is a presheaf U whose elements at C-object Γ are (essentially) C-indexed families of small sets, together with a presheaf El over U whose fibre at A ∈ U(Γ) is the "type" indexed by A. [Awodey 2024], in *On Hofmann-Streicher universes*, recasts this construction categorically: (U, El) is the *categorical nerve* of the classifier for discrete fibrations in Cat, with the nerve functor right-adjoint to the Grothendieck construction taking a presheaf to its category of elements. The construction extends naturally to handle change of base and to universes of structured families (fibrations more generally).

The crucial reformulation is that the display map p : El → U *is itself a polynomial functor* in the sense of §IV.5.2 — specifically, it determines a polynomial endofunctor

  P_p : Set^{C^op} → Set^{C^op}, X ↦ Σ_{A : U} X^{El(A)}

on the presheaf category. *Closure of the universe under Σ and Π types becomes closure of the polynomial functor P_p under the corresponding adjoints to weakening.*

#### Natural models and the strictification problem

[Awodey 2018] formalised this picture as the theory of *natural models* of homotopy type theory. The strictification problem — that substitution must be strictly associative in syntax but pullback is only associative up to canonical isomorphism — is solved by working with type-universe presentations: types are represented as morphisms into a universe, making substitution strictly associative through precomposition. The natural-model framework then encodes a model of dependent type theory as a polynomial functor on a presheaf category, plus closure conditions for each type former.

[Awodey Newstead 2018] (and subsequent work surveyed in [Awodey 2022]) established the precise correspondence:

- The natural model carries the structure of a *Cartesian pseudomonad* iff the universe is closed under *unit types* and *Σ types*. The unit type corresponds to the monad unit; Σ types correspond to monad multiplication.
- The natural model carries a *self-distributive law* of the monad with itself (a "jump" structure, in the [Spivak 2021] terminology) iff the universe is additionally closed under *Π types*. The Π type corresponds precisely to this distributive law witnessing the standard distributivity of Π over Σ [Topos Institute 2024].

The technical complication that historically made this picture less than fully internal — Awodey and Newstead were forced into a *tricategory* of polynomials to handle the higher coherences arising from up-to-isomorphism identities — was resolved by [Aberlé Spivak 2025] working in the language of homotopy type theory, where univalence supplies the higher coherences automatically.

#### Polynomial universes (Aberlé-Spivak)

The contribution of [Aberlé Spivak 2025], *Polynomial Universes in Homotopy Type Theory* (presented at MFPS XLI, Electronic Notes in Theoretical Informatics and Computer Science, December 2025), is the axiomatic identification: *a polynomial universe is a polynomial functor satisfying univalence*. The key results are:

1. A polynomial universe — a univalent polynomial endofunctor on a suitably-chosen category of presheaves — automatically satisfies all the higher coherences required for closure under dependent-type-theoretic constructors.
2. When a polynomial universe is closed under Π types, the closure *automatically* witnesses the existence of a distributive law of the relevant monads. The complicated tricategorical machinery of Awodey-Newstead becomes, in the HoTT framework, a single condition on a univalent polynomial functor.
3. The categorical semantics of dependent type theory is therefore axiomatisable *entirely within the standard category of polynomial functors*, working internally to HoTT.

Subsequent work on *polynomial universes and natural models* [Aberlé Spivak 2024, Topos Institute] gives the explicit correspondences:

- A polynomial universe u is closed under unit and Σ types ⟺ u carries Cartesian pseudomonad structure.
- u is additionally closed under Π types ⟺ u carries a self-distributive law (a Cartesian morphism in the category Poly^Cart of polynomial functors).

The architectural significance for Prologos. The Prologos compiler already incorporates Martin-Löf-style dependent types (Phase 0 syntax: Π via `<(x : A) -> B>`, Σ via `<(x : A) * B>`, universes via `Type` [prologos-syntax.md]). The polynomial-universes line says: *this dependent-type machinery is already a polynomial-functor framework*. The propagator network, with its cells, monotone merges, and BSP scheduler, is the *operational realisation* of this denotational structure on a presheaf-like category (cells = sections of a sheaf over the topology of cell-id, propagator firing = Σ-Π evaluation). The synthesis is the recognition that the existing infrastructure *is* a polynomial-universe model, even if it has not been described as such.

### §IV.5.4 The polynomial-functor composition product

The central operation of [Niu Spivak 2024], developed in their Chapter 5, is the *composition product* on polynomial functors. This product is the categorical-algebraic content of what we have been calling, in the Prologos vocabulary, *conjunctive composition* of behaviours.

#### The formal definition

For polynomials P(y) = Σ_{a ∈ A_P} y^{B_P(a)} and Q(y) = Σ_{b ∈ A_Q} y^{B_Q(b)}, their composition product P ◇ Q is the polynomial functor whose action on a set y is

  (P ◇ Q)(y) = P(Q(y)) = Σ_{a ∈ A_P} Q(y)^{B_P(a)}.

Unpacking the right-hand side: a position of P ◇ Q is a *pair* (a, f) where a ∈ A_P and f : B_P(a) → A_Q is a function from P's directions at a into Q's positions; the directions at position (a, f) are the dependent sum

  B_{P◇Q}(a, f) = Σ_{b ∈ B_P(a)} B_Q(f(b)).

So:

- Positions of P ◇ Q = pairs (a, f : B_P(a) → A_Q).
- Directions of P ◇ Q at (a, f) = sum over b ∈ B_P(a) of B_Q(f(b)).

[Niu Spivak 2024, §5.1] develop this product in detail; the formula expresses *substitution* of polynomials, generalising functor composition to keep all the position/direction bookkeeping explicit.

#### Associativity, unit, bicategorical structure

The composition product is associative (P ◇ (Q ◇ R) ≅ (P ◇ Q) ◇ R, naturally) and has a unit y (the polynomial with one position and one direction, equivalent to the identity functor). [Niu Spivak 2024, §5.2-5.4] develop the bicategorical structure: (Poly, ◇, y) is a (non-symmetric) monoidal category, in fact a bicategory whose 1-cells are polynomials and 2-cells are polynomial morphisms (lenses; see §IV.5.5). [Spivak 2025] (the *Summary of categorical structures in Poly*) catalogs *four* monoidal structures on Poly — the composition product ◇, the parallel product ⊗, the disjoint sum +, and the Day-convolution-like structure — together with their distributivities and duoidal interactions.

The four interacting monoidal structures encode different modes of behavioural combination. ◇ is *sequential* or *substitutional*: doing P then Q. ⊗ is *parallel*: doing P and Q simultaneously and independently. + is *alternative*: doing P or Q, with the choice externalised. The duoidal interaction ◇/⊗ — that ◇ distributes over ⊗ in a controlled way — is the algebraic content of *interleaved parallel-then-sequential composition*, exactly the structure required for protocol composition with concurrent participants.

#### Why this is conjunctive refinement

The composition product captures the algebra of conjunctive refinement at the protocol level. Consider two protocols P and Q in a multi-party setting: P specifies a set of behavioural patterns (positions) with their channel-shapes (directions), and Q specifies the same. The composition P ◇ Q is the protocol whose behavioural patterns are *pairs* (P-position, P-direction-to-Q-position assignment), with channel-shapes given by the Σ_b B_Q(f(b)) formula. Operationally:

> "After P branches at position a (using P's channels B_P(a)), apply a Q-protocol depending on which P-direction was taken — and the channels of the composed protocol are P's channels followed by Q's channels at the chosen P-direction's image."

This is exactly the refinement pattern: P's branching is preserved, and *each P-direction is refined by an instance of Q*, with the refinement chosen by f. Conjunctive refinement at the protocol level — refining a behavioural specification by composing it with a sub-specification at each direction — is precisely the polynomial-composition-product operation.

The architectural commitment in the synthesis target — *composition is the polynomial-functor composition product, associative with unit and respecting bicategorical structure — this IS conjunctive refinement at the protocol level, not projection-with-merge* — is the assertion that the Prologos bundle/trait composition machinery, which currently expresses conjunctive refinement at the term-level (a bundle is a conjunction of trait-method dictionaries [CLAUDE.md, Glossary]), should be lifted to the protocol level by recognising the bundle/trait composition as a Set-level shadow of the polynomial composition product.

#### Comparison with operadic composition

Operads compose by tree substitution: an operation θ ∈ O(n) and operations φᵢ ∈ O(kᵢ) compose to give θ(φ_1, …, φ_n) ∈ O(k_1 + … + k_n). The arity is summed, the substitution is direct, and everything fits in a tree. Polynomials compose by the more general *wiring diagram* pattern: positions are paired with maps from P-directions to Q-positions (the "wiring"), and directions are summed dependently on the chosen wiring. This generalisation accommodates *conditional behaviour*: a P-direction may be "hooked up" to *different* Q-positions in different overall composites, producing different downstream channel shapes. Operadic composition cannot express this; polynomial composition is its essence.

The four-monoidal-structure picture from [Niu Spivak 2024] and [Spivak 2025] also goes beyond what operads provide. Operads are inherently single-output; their categorical home is monoidal categories with substitution, which is roughly *one* of the monoidal structures on Poly — specifically the substitutional ◇. The full structure on Poly captures parallel ⊗ (which operads do not), alternation + (which operads handle only externally, by indexing operad colours), and duoidal interactions among them. This is the structure required for multi-party protocols where parallelism, sequencing, and choice all coexist [Niu Spivak 2024 Chapters 6-10].

### §IV.5.5 Bicategory of polynomial functors with lenses

The bicategorical structure on Poly — objects, 1-cells, 2-cells — is the right setting for organising participants, protocols, and refinements in a multi-party theory.

#### Objects, 1-cells, 2-cells

In the simplest formulation of [Niu Spivak 2024]:

- **Objects** are sets (or, in the LCCC generalisation of [Gambino Kock 2013], objects of a fixed LCCC). For multi-party theory, *objects are participants*: each participant is a set (or LCCC object) that organises the data carried at that participant's role.
- **1-cells** P : A → B are polynomial functors between slice categories C/A and C/B. For multi-party theory, *1-cells are protocols*: a protocol from A to B is a polynomial functor specifying how A and B interact (positions = phases of the protocol, directions = channels at each phase).
- **2-cells** η : P ⇒ Q are polynomial morphisms — concretely, *lenses*. For multi-party theory, *2-cells are refinements*: a refinement from P to Q is a lens witnessing that protocol Q implements protocol P, with positions of P mapped forward to positions of Q (more refined positions cover more cases) and directions of Q mapped back to directions of P (more refined directions provide finer channel structure).

This double-arrow structure on directions — forward on positions, backward on directions — is the *lens* pattern.

#### Lenses as morphisms

A *lens* (f, f^♯) : P → Q between polynomials P = Σ_{a:A_P} y^{B_P(a)} and Q = Σ_{b:A_Q} y^{B_Q(b)} consists of:

1. A *forward map* on positions: f : A_P → A_Q,
2. A *backward map* on directions: f^♯ : a:A_P ⊢ B_Q(f(a)) → B_P(a) (a direction-pullback indexed by P-positions).

Pictorially, a lens acts on a system in P-position a by translating it to a system in Q-position f(a); when the Q-system invokes a Q-direction in B_Q(f(a)), the lens maps that Q-direction back to a P-direction in B_P(a) and runs the P-system on it. *Positions go forward; directions come back.* This is exactly the bidirectional structure of program refinement: the abstract specification's calls (positions) are mapped forward to the concrete implementation, and the concrete implementation's responses (directions) are mapped backward to the abstract specification's expectations.

[Spivak 2019] develops the lens structure systematically; lenses on polynomials are the natural generalisation of the bidirectional lenses used in functional programming for bidirectional data transformations [Foster et al. 2007]. The polynomial-functor setting unifies these lenses with the lenses of optics [Riley 2018, Clarke et al. 2020] and with Spivak's bicategorical approach to dynamical-systems wiring diagrams.

#### Composition of lenses, bicategorical coherence

Lenses compose: given P → Q and Q → R, the composite P → R is determined by composing the forward maps on positions and *contravariantly* composing the backward maps on directions. [Niu Spivak 2024, §2.3-2.4] develop this composition; they show it is associative up to canonical 2-cell isomorphism, giving the bicategorical structure. [Gambino Kock 2013] in the LCCC generalisation showed the structure is even better: Poly is a *framed bicategory* (equivalently, a double category with companions), permitting the additional "transition lens" structure that captures dynamics in [Niu Spivak 2024 Chapter 3].

For multi-party theory, the bicategorical coherence has a direct interpretation: refinement-of-refinement (a 2-cell between 2-cells, which appears as the 3-cell in a tricategory but collapses to identity in the 2-cell case) corresponds to *equivalence of refinement strategies*. Two refinements f, g : P ⇒ Q are equivalent iff they induce the same lens — same position map, same direction pullback. This equivalence is *strict* in the bicategorical setting; in the homotopical refinement of [Aberlé Spivak 2025], it becomes a higher coherence governed by univalence.

#### The right setting for multi-party

The bicategory of polynomial functors with lenses is the architectural answer to the question: *what is the categorical home of multi-party protocols?* Because:

- Participants are objects (data-shapes at each role).
- Protocols are 1-cells (interaction patterns between participants).
- Refinements are 2-cells (implementations of one protocol by another, in the lens sense).
- Composition of protocols is the composition product ◇.
- The bicategory's coherence laws are exactly the laws governing protocol composition and refinement.

This contrasts with the *operadic* setting [Castellani 2008, MCC literature], where protocols are operations and refinement is forced into the substitution-of-operations pattern. The polynomial-bicategorical setting is strictly more expressive — it accommodates the conditional-behaviour patterns that distinguish multi-party protocols from monolithic operations — and structurally aligned with the propagator-network operational substrate.

### §IV.5.6 Polynomial functors in DTT — Aberlé and compositional verification

The slice now turns to the direct connection between polynomial functors and *compositional program verification* in dependent type theory. The load-bearing reference here is the body of work by C. B. Aberlé, often jointly with David Spivak, developed in the 2024–2025 timeframe at CMU and Topos Institute.

#### The Aberlé-Spivak framework

The headline contribution of [Aberlé Spivak 2025] (*Polynomial Universes in Homotopy Type Theory*, MFPS XLI / Entics 2025) is the categorical axiomatisation of dependent type theory entirely in terms of polynomial functors. The supplementary blog posts and seminar talks [Aberlé 2024 CMU HoTT seminars, Aberlé Spivak 2024 Topos Institute] develop the verification-relevant strands.

The abstraction one wants for compositional verification is this. A polynomial functor P(y) = Σ_{a:A} y^{B(a)} naturally represents the *interface* of a dependent computational unit: positions a ∈ A are the *operations* the unit can offer; directions B(a) are the *return types* (or, more generally, the *dependent return types*) the unit produces when offering operation a. A *program* implementing this interface is then a morphism into the *free monad* on P (the free monad being the structure of "all sequences of operations from the interface, with returns folded in"; see §IV.5.7 below). Verification — that the program meets a richer specification — becomes a question about the morphism in this categorical setting.

The deeper move of [Aberlé Spivak 2025] generalises this picture to *dependent polynomial functors*, where the directions B(a) themselves carry dependent-type structure. Now positions are the operations of the interface, but directions encode pre- and postconditions: a direction at position a is a *proof obligation* whose type depends on the position chosen. A program implementing the interface is a morphism from a specification polynomial to an implementation polynomial, with the morphism witnessing that the implementation discharges the specification's obligations. *Programs are verified in exactly the same manner they are built up.*

The abstract categorical structure expressing this is a *monoidal functor from specifications to interfaces*, equipped with a *monoidal natural transformation of lax monoidal presheaves*. The monoidal structure on specifications composes obligations; the monoidal structure on interfaces composes operations; the monoidal-functor laws ensure that decomposing a verified program into sub-programs recombines, when verified separately, into a verified whole. This is a categorical reframing of the Hoare-logic compositionality property — programs decompose by control flow, specifications decompose along the same shape, and verification at the whole equals verification at each piece composed.

(*Bibliographic note:* the survey-level synthesis of this framework circulates under several titles in the Aberlé-Spivak corpus; the slice's references treat the [Aberlé Spivak 2025 MFPS] paper plus the [Aberlé Spivak 2024 Topos Institute] blog posts as the load-bearing pair, with the compositional-verification framing developed across Aberlé's 2024–2025 CMU HoTT seminar talks "Polynomial Universes & Natural Models of (Linear) (Dependent) Type Theory, Parts I & II" [Aberlé 2024 CMU] and "Tiny types" [Aberlé Awodey 2025 CMU]. The literal title "Compositional Program Verification with Polynomial Functors in Dependent Type Theory" appears in the synthesis target's framing of this corpus; readers should treat the Aberlé-Spivak polynomial-universes line as the canonical citation cluster.)

#### Compositional verification, concretely

Concretely, the framework permits the following pattern:

1. *Specify*. The intended interface is a dependent polynomial functor P^spec(y) = Σ_{a:A^spec} y^{B^spec(a)}, where positions are the abstract operations and directions encode pre- and postconditions on the inputs and return types. The dependent structure means a position's directions can depend on the position itself — capturing operation-dependent specifications such as "the return type of the lookup operation is the value type at the looked-up key."
2. *Implement*. The implementation is a polynomial P^impl whose positions are concrete operations and whose directions are concrete return types. A *lens* P^spec → P^impl forwards specifications to implementations and pulls implementation evidence back to specification proof obligations.
3. *Compose*. Two verified components — lenses η : P^spec_1 → P^impl_1 and ξ : P^spec_2 → P^impl_2 — compose along the polynomial composition product to give a verified composite η ◇ ξ : (P^spec_1 ◇ P^spec_2) → (P^impl_1 ◇ P^impl_2). The categorical coherence of ◇ ensures the verification condition for the composite is exactly the conjunction of the verification conditions for the parts.

This is exactly the discipline a Prologos library should support: a session-typed protocol is a polynomial functor specification; an implementation that respects the protocol is a lens into the polynomial functor of executions; conjunctive refinement of protocols composes by ◇.

#### Architectural significance for Prologos

The architectural significance for Prologos is twofold. First, the *dependent session types in continuation positions* the synthesis target asks for are exactly the dependent polynomial functors of [Aberlé Spivak 2025]: the directions B(a) at a position a carry types that depend on a, modelling the dependent structure of session-type continuations. Second, the *compositional verification* discipline — programs and specifications composing along the same shape, verification distributing over composition — is exactly what propagator networks support operationally: a propagator-typed cell holds a polynomial-functor-typed value, and the propagator network's BSP semantics realises the composition operationally.

The Prologos infrastructure for *bundle/trait* composition (conjunctive refinement at the term level) is the propositional-truncation, Set-level shadow of the polynomial-composition picture. The dependent-type infrastructure (Π and Σ over universes) is the LCCC structure underlying the polynomial-functor framework. The propagator-network substrate is the operational instantiation of the polynomial-universe model. Recognising these as facets of a single polynomial-functor-in-DTT framework — what [Aberlé Spivak 2025] axiomatise — is the load-bearing recognition the present synthesis demands.

### §IV.5.7 Free monads on polynomials and protocol behaviour

The free monad construction on a polynomial functor is the categorical structure that turns a *specification* of operations (a polynomial) into a *type of executions* (the free monad's algebras). This connects polynomial functors to the *coalgebraic* picture of session types developed in [Keizer Basold Pérez 2020, Basold Komendantskaya 2022], referenced by Agent 1's slice §I.

#### Free monads on polynomials

Given a polynomial endofunctor P(y) = Σ_{a:A} y^{B(a)}, the *free monad* T_P on P is the monad whose algebras are exactly the algebras of P plus a unit — equivalently, T_P(y) is the "type of programs that perform a sequence of P-operations, each followed by recursion, ultimately returning a y-typed value." Concretely,

  T_P(y) = μ X. y + P(X)

(the least fixed point), or equivalently the type of finite well-founded *P-trees* with leaves labelled in y.

The crucial result, due in the LCCC setting to [Gambino Kock 2013], is that the free monad on a polynomial endofunctor is itself a polynomial functor. This is *closure of polynomial structure under iterated interaction*: the iterated, sequential, recursive use of a polynomial-shaped interface stays within the polynomial world. The free-monad polynomial T_P has positions corresponding to all finite P-trees and directions corresponding to the leaf-channels, with the polynomial structure inheriting all bicategorical, LCCC, and universe-closure properties from P.

The free-monad construction is also a *lens-aware* construction: a lens P → Q induces a lens T_P → T_Q on free monads, by mapping P-trees to Q-trees position-by-position and pulling Q-leaf-channels back to P-leaf-channels. Compositional verification (§IV.5.6) propagates through free-monad construction: a verified interface gives a verified executor.

#### Coalgebras for polynomial functors

The dual picture is *coalgebras*. A coalgebra for a polynomial endofunctor P is an object Y together with a morphism c : Y → P(Y). Operationally, c is a *transition*: given a state y ∈ Y, c picks a position c_pos(y) ∈ A and, conditionally on each direction d ∈ B(c_pos(y)), assigns a successor state c_succ(y, d) ∈ Y. A coalgebra is exactly a *state-machine* with positions = labels and directions = transition-types.

The connection to session types is direct, as Agent 1's slice develops. [Keizer Basold Pérez 2020] use polynomial functors to define *session coalgebras*: a session type is a coalgebra for a particular polynomial functor whose positions are session-protocol states and whose directions are the message-types available at each state. A protocol *behaviour* is a coalgebra; protocol *equivalence* is bisimulation, which in the polynomial-coalgebra setting is the cofree-comonad-mediated equivalence relation.

The *cofree comonad* C_P on a polynomial functor P, dual to the free monad T_P, has C_P(y) = "type of all (potentially infinite) P-trees with each node labelled in y" — the type of all interactive programs using P-operations, without termination guarantees. [Gambino Kock 2013] established the cofree-comonad analogue of their free-monad result: cofree comonads on polynomials are polynomial functors. (Bicomodules on the resulting double-category structure are studied in [Niu Spivak 2024 Chapters 9-10].)

#### Upgrading session coalgebras to polynomial-functor coalgebras

The architectural payoff for the synthesis is this: the session-coalgebra view of session types developed in [Keizer Basold Pérez 2020] is *already* a polynomial-functor coalgebra view — they use polynomial functors explicitly. What is needed is to upgrade their setting from Set-coalgebras to *LCCC-coalgebras*, where dependent-type structure on the directions of the polynomial functor permits dependent session types in continuation position. The Aberlé-Spivak polynomial-universe machinery provides exactly the LCCC framework for this upgrade.

### §IV.5.8 Why this is the right framework for Prologos's multi-party story

The polynomial-functor + LCCC + DTT framework synthesised across §§IV.5.1–IV.5.7 is the architectural setting for Prologos's multi-party programming story for the following structural reasons.

#### The pieces are already there

Prologos already incorporates the foundational ingredients independently:

1. **Propagator-network substrate** [propagator-design.md]. The BSP-scheduled, lattice-cell-merge, monotone-fixpoint substrate is operationally a polynomial-functor evaluator: each propagator is a polynomial-shaped object (positions = branches, directions = cells), each fire is a position-direction pair of operations, the BSP scheduler computes the polynomial composition product over a round.

2. **Dependent type theory (MLTT-style)** [prologos-syntax.md]. Π/Σ types via `<(x : A) -> B>` and `<(x : A) * B>` with universe levels are exactly the LCCC structure required for polynomial functors in the [Gambino Kock 2013] generalisation. The strictification problem (substitution = pullback, only associative up to canonical isomorphism) is handled by the elaborator's universe machinery.

3. **Effect-ordering quantale + tropical-quantale cost layer**. These are the *enriched* base for polynomial functors — quantale-enriched polynomials, in the sense of generalised polynomial functors [Fiore 2012], where directions carry quantale-valued cost or effect data. The Prologos quantale infrastructure is the cost-aware version of the Set-based polynomial picture in [Niu Spivak 2024].

4. **Bundle/trait conjunctive-refinement composition** [CLAUDE.md]. The bundle composition algebra is the Set-level (truncated) shadow of the polynomial composition product ◇. A bundle is a tuple of trait-method dictionaries; conjunctive refinement is bundle multiplication; the categorical lift of this Set-level multiplication to a polynomial-functor composition is the polynomial-composition-product picture.

5. **Binary session types**. These are coalgebras for a particular class of polynomial functors. Generalising to multi-party is generalising to richer polynomial functors with more structured position-direction structure, exactly along the dimension [Niu Spivak 2024] develop.

The synthesis is the recognition that *these pieces share a common categorical home*. The polynomial-functor + LCCC + DTT framework is not an addition to Prologos's infrastructure; it is the *underlying structure* the existing infrastructure was already approximating.

#### Why this matters operationally

Operationally, the framework directs implementation in three ways.

First, *cell typing*. Cells should carry polynomial-functor-typed values, not just lattice-valued data. A propagator that watches a polynomial-typed cell can react to position-changes (an operation has been chosen) or direction-changes (a channel has been activated) separately, with the polynomial-functor structure dictating the firing pattern. This generalises the existing structural-cell discipline [propagator-design.md § Component Indexing] to a categorical setting where the components of a compound cell are exactly the directions of a polynomial.

Second, *protocol composition*. A multi-party protocol should be implemented as a polynomial functor; protocol composition should be the composition product ◇; protocol refinement should be a lens; protocol behaviour should be a coalgebra. The bicategorical coherence of Poly determines the algebra of protocol manipulation — what compositions are admissible, what refinements compose to what, what equivalences hold.

Third, *verification*. Per [Aberlé Spivak 2025], compositional verification of polynomial-typed programs distributes over polynomial composition. A verified protocol participant composes with a verified protocol participant to yield a verified composite — and the verification obligations decompose along the same shape as the composition. This is the categorical realisation of the *Network Reality Check* [workflow.md]: information flows through cells, composes structurally, and verification piggybacks on composition.

#### Closing remark

The architectural target of the synthesis — *Multi-party protocols are polynomial functors P : C → C in a locally cartesian closed category, with role projection as opcartesian lifts in a fibration over a participant lattice, behavior as coalgebras for the polynomial functor, and realizability as a quantale-valued fixpoint* — names the polynomial-functor + LCCC + DTT framework as the categorical foundation. The slice has provided the categorical content: positions and directions, LCCC-generalisation, polynomial universes for DTT, the composition product as conjunctive refinement, the bicategory with lenses, the Aberlé-Spivak compositional-verification framework, and free monads for protocol behaviour. The synthesis chapter integrates this with the fibrational role-projection picture (Agent 4's slice §III.7), the quantale-enriched cost layer (Agent 6's slice §IV.6), and the conjunctive composition algebra (Agent 7's slice §IV.7), to form the unified theory the multi-party-computation programme demands.

---

## References

[Aberlé 2024 CMU] C. B. Aberlé. *Polynomial Universes & Natural Models of (Linear) (Dependent) Type Theory, Parts I & II.* Talks at the CMU Homotopy Type Theory seminar, November 8 & 15, 2024. The talks develop the natural-model framework, present the closure-under-Π-types-as-distributive-law characterisation, and treat the linear and substructural cases. Slides and abstracts available at the CMU HoTT seminar archive.

[Aberlé Awodey 2025 CMU] C. B. Aberlé and S. Awodey. *Tiny types.* Joint talk at the CMU Homotopy Type Theory seminar, March 14, 2025. Treats tinyness — an object T with (-)^T a left adjoint — and applications to internal-language constructions for presheaf categories and Grothendieck topoi. Connects polynomial-universe machinery to internal type-theoretic languages.

[Aberlé Spivak 2024 Topos Institute] C. B. Aberlé and D. I. Spivak. *Polynomial universes and natural models.* Topos Institute blog post, December 10, 2024. Available at https://topos.institute/blog/2024-12-10-polynomial-universes-natural-models/. Explains the polynomial-universe construction, the universe-as-display-map P_u : Set^{C^op} → Set^{C^op} formula, the Cartesian-pseudomonad / self-distributive-law structure characterising closure under Σ and Π types. Cites Awodey, Newstead, Anel, and Gambino-Kock.

[Aberlé Spivak 2025] C. B. Aberlé and D. I. Spivak. *Polynomial Universes in Homotopy Type Theory.* Electronic Notes in Theoretical Informatics and Computer Science, MFPS XLI proceedings, December 2025. arXiv:2409.19176. Establishes the axiomatic identification of polynomial universes as univalent polynomial functors, proves that closure under Π types is automatic-distributive-law in the HoTT setting, and replaces the Awodey-Newstead tricategory with the standard category of polynomial functors interpreted internally to HoTT.

[Awodey 2018] S. Awodey. *Natural models of homotopy type theory.* Mathematical Structures in Computer Science 28 (2): 241–286, 2018. Available at https://www.andrew.cmu.edu/user/awodey/preprints/natural.pdf. Foundational paper introducing natural models — polynomial-functor-presented categorical semantics for dependent type theory that solve the strictification problem via type universes. The paper establishes that the universe data is a polynomial functor and that Σ/Π closures correspond to left/right adjoints to weakening.

[Awodey 2022] S. Awodey. *Tutorial on Polynomial Functors and Type Theory.* Slides, CMU HoTT seminar. Available at https://www.cmu.edu/dietrich/philosophy/hott/slides/polytutorial.pdf. Survey-level treatment of the polynomial-functor framing of dependent types, with Σ/Π adjoint structure made explicit.

[Awodey 2024] S. Awodey. *On Hofmann-Streicher universes.* Mathematical Structures in Computer Science, published online 2024. arXiv:2205.10917, May 2022. Recasts the Hofmann-Streicher presheaf universe as the categorical nerve of the classifier for discrete fibrations, and exhibits the universe data as a polynomial functor. Treats change of base and universes of structured families (fibrations).

[Awodey Newstead 2018] S. Awodey and C. Newstead. *Algebraic models of dependent type theory.* Working paper / preprint, multiple versions. Develops the natural-model picture into a tricategory of polynomial functors to handle the higher-coherence aspects of dependent type theory before the [Aberlé Spivak 2025] simplification via HoTT.

[Awodey Warren 2009] S. Awodey and M. A. Warren. *Homotopy theoretic models of identity types.* Mathematical Proceedings of the Cambridge Philosophical Society 146 (1): 45–55, 2009. Background reference establishing that Martin-Löf identity types admit weak factorisation system semantics; foundational for natural-model and polynomial-universe work.

[Bergeron Labelle Leroux 1998] F. Bergeron, G. Labelle, P. Leroux. *Combinatorial Species and Tree-like Structures.* Encyclopedia of Mathematics and its Applications 67, Cambridge University Press, 1998. Comprehensive textbook on combinatorial species [Joyal 1981]; develops the analytic-functor characterisation and the connection to polynomial functors (flat species = polynomials).

[Castellani 2008] I. Castellani. *Process algebras and protocol descriptions.* Background reference for operadic / process-calculi treatment of multi-party protocols.

[Clarke et al. 2020] B. Clarke, D. Elkins, J. Gibbons, F. Loregian, B. Milewski, E. Pillmore, M. Román. *Profunctor Optics, a Categorical Update.* Compositionality, 2020. Develops the categorical theory of optics including lenses, generalising Spivak's polynomial-functor lens picture.

[Fiore 2012] M. Fiore. *Generalised Polynomial Functors: Theory and Applications.* University of Cambridge Computer Laboratory technical material, 2012. Develops polynomial functors enriched over more general bases (including quantale-enriched cases), foundational for the cost-layer extension of the polynomial framework.

[Foster et al. 2007] J. N. Foster, M. B. Greenwald, J. T. Moore, B. C. Pierce, A. Schmitt. *Combinators for bidirectional tree transformations.* ACM Transactions on Programming Languages and Systems 29 (3), 2007. Introduces the "lens" terminology for bidirectional transformations; the Spivak-Niu lens generalisation specialises to these tree-lens combinators.

[Gambino Kock 2013] N. Gambino and J. Kock. *Polynomial functors and polynomial monads.* Mathematical Proceedings of the Cambridge Philosophical Society 154 (1): 153–192, 2013. arXiv:0906.4931, 2009. The canonical reference for polynomial functors over LCCCs. Establishes that polynomial functors assemble into a double category / framed bicategory, that the free monad on a polynomial endofunctor is polynomial, and the relationship to operads.

[Hofmann 1997] M. Hofmann. *Syntax and semantics of dependent types.* In: Semantics and Logics of Computation, Cambridge University Press, 1997. Background on dependent-type semantics in LCCCs, including treatment of strictification and substitution-as-pullback.

[Hofmann Streicher 1997] M. Hofmann and T. Streicher. *Lifting Grothendieck universes.* Manuscript / proceedings, 1997. Foundational construction of the universe (U, El) for Martin-Löf type theory in presheaf categories; the construction recast in terms of polynomial functors by [Awodey 2024].

[Joyal 1981] A. Joyal. *Une théorie combinatoire des séries formelles.* Advances in Mathematics 42 (1): 1–82, 1981. Origin of combinatorial species; introduces analytic functors and characterises them as those preserving weak pullbacks, cofiltered limits, and filtered colimits. The polynomial-functor lineage starts here.

[Keizer Basold Pérez 2020] A. C. Keizer, H. Basold, J. A. Pérez. *Session Coalgebras: A Coalgebraic View on Session Types and Communication Protocols.* In: ESOP 2021, LNCS 12648, Springer. Subsequent ACM TOPLAS journal version 2022. The coalgebraic, polynomial-functor-based account of session types referenced by Agent 1.

[Kock 2010] J. Kock. *Notes on Polynomial Functors.* Lecture notes, available at https://mat.uab.es/~kock/cat/polynomial.pdf. Self-contained development of polynomial functors over LCCCs, connecting to Joyal's species and to dependent-type-theoretic structures.

[Kock 2009 lecture notes] J. Kock. *Polynomial functors and polynomial monads.* Lecture slides, Leeds, July 2009. Available at https://personalpages.manchester.ac.uk/staff/Nicola.Gambino/gambino-leeds.pdf. Background lectures preceding the [Gambino Kock 2013] paper.

[Melliès] P.-A. Melliès. *Tensorial logic, dialogue games, polynomial functors.* Various papers and seminar notes available at https://www.irif.fr/~mellies/. Provides the dialogue-game and tensorial-logic perspective on polynomial-functor and combinatorial structure; complementary to (not replacing) the Spivak-Niu dynamical-systems perspective.

[Niu Spivak 2024] N. Niu and D. I. Spivak. *Polynomial Functors: A Mathematical Theory of Interaction.* London Mathematical Society Lecture Note Series 498, Cambridge University Press, 2024. arXiv:2312.00990. The 372-page monograph that is the foundational reference for the polynomial-functor framework. Covers the category Poly, the composition product (Chapter 5), the bicategorical structure with lenses, polynomial comonoids as categories, free constructions, bimodules, and dynamics. Load-bearing throughout the slice.

[Riley 2018] M. Riley. *Categories of optics.* arXiv:1809.00738, 2018. Categorical theory of optics; lenses on polynomial functors are a special case in the optics taxonomy.

[Seely 1984] R. A. G. Seely. *Locally cartesian closed categories and type theory.* Mathematical Proceedings of the Cambridge Philosophical Society 95 (1): 33–48, 1984. Classical correspondence between LCCCs and Martin-Löf type theory.

[Spivak 2019] D. I. Spivak. *Lenses: applications and generalizations.* Talk at ACT@UCR, 2019. Available at https://math.ucr.edu/home/baez/ACTUCR2019/ACTUCR2019_spivak.pdf. Develops the lens picture in the polynomial-functor setting.

[Spivak 2020] D. I. Spivak. *Poly: An abundant categorical setting for mode-dependent dynamics.* arXiv:2005.01894, May 2020. Establishes Poly as the natural home for mode-dependent dynamical systems; identifies the four interacting monoidal structures and develops the composition product's role in dynamics.

[Spivak 2021] D. I. Spivak. *Jump monads: from conjugation to dependent types.* Topos Institute blog post, July 1, 2021. Available at https://topos.institute/blog/2021-07-01-jump-monads/. Explains the universe-polynomial encoding of dependent type theory: positions = types, directions = terms, Cartesian-monad structure = unit/Σ types, self-distributive law = Π types.

[Spivak 2025] D. I. Spivak. *A summary of categorical structures in Poly.* arXiv:2202.00534, version 14, September 2025. Catalog of monoidal structures on Poly: composition product ◇, parallel ⊗, sum +, Day-convolution-like structure, with closure properties, distributivity, and duoidal interactions. Companion to [Niu Spivak 2024] for the structural-algebra perspective.

[Topos Institute 2024] *Polynomial universes and natural models* (blog post by C. B. Aberlé and D. I. Spivak), Topos Institute, December 10, 2024. See [Aberlé Spivak 2024 Topos Institute] above.

---

## Part IV.6 — Quantale-enriched session types and cost-aware multi-party realizability

This slice grounds the architectural commitment that *multi-party protocols are
polynomial functors over a quantale-valued propagator runtime*, with role
projection as opcartesian lifts and realizability as a quantale-valued fixpoint
in the propagator network. Foundational quantale theory is treated only insofar
as it interfaces with session-type machinery; for the deep treatment of
quantales, the (min,+) Lawvere quantale, and Mulvey's original motivation, the
reader is referred to the companion async-research artifact §3.4-§3.5 and §7.

The argument runs in eight movements. §IV.6.1 recalls the algebraic-semantics
correspondence between fragments of (noncommutative) linear logic and quantales,
then transports it onto the linear-logic-as-session-types tradition
(Caires-Pfenning, Wadler GV/CP, the SILL family, πLL/HOπLL): every such system
already lives natively in a quantale, even where its authors do not say so.
§IV.6.2 grafts the tropical Lawvere quantale onto that scaffolding to give
every protocol composition a cost; the operation is structural, not
metatheoretic — the tensor of the linear-logic quantale becomes (min,+) in
the cost dimension. §IV.6.3 reads the Carbone-Lindley-Montesi-Schürmann-Wadler
coherence rule as iterated tensor in a (commutative or non-commutative) quantale,
making the n-ary symmetry of multi-party composition fall out of the algebra
rather than being engineered. §IV.6.4 surveys the recent quantale-enriched
DTT and quantale-coalgebraic-logic frontier (Bacci-Mardare-Panangaden-Plotkin
2023; Beohar et al. STACS 2024; Goncharov-Hofmann-Nora-Schröder-Wild FoSSaCS
2023; Kurz CALCO 2025) and argues that these provide the technology a
quantale-enriched session type theory needs. §IV.6.5 develops fibrational role
projection: a participant lattice as base, behavioural-type fibres above,
projection as universal opcartesian lift. §IV.6.6 turns realizability into a
quantale-valued fixpoint computation on a labelled transition system,
combining synthetic-MPST style (process against LTS) with the cost lattice.
§IV.6.7 recalls that Prologos's existing effect-ordering substrate is already
operationally a quantale, and observes that the multi-party case reduces to
that same machinery scaled up by polynomial-functor structure. §IV.6.8 names
the unique architectural offering: cost-aware multi-party protocols, with
multi-dimensional Pareto realizability as a fixpoint computation in the
existing propagator network.

### §IV.6.1 Quantales as the algebraic semantics of linear logic — the session-types bridge

The connection between quantales and linear logic is owed to Yetter [Yetter
1990], whose paper *Quantales and (Noncommutative) Linear Logic* explicitly
makes Mulvey's algebraic objects [Mulvey 1986] into models for both
commutative and Girard's "cyclic" noncommutative linear-logic fragments. A
(unital) quantale is a complete sup-lattice $Q$ equipped with an associative,
unital monoidal product $\otimes$ that distributes over arbitrary joins on both
sides; for any $a \in Q$ the assignment $b \mapsto a \otimes b$ has a right
adjoint $a \multimap (-)$. The key syntactic identifications are mechanical
once the algebra is set up:

| Linear-logic syntax | Quantale operation |
|---|---|
| $A \otimes B$ (multiplicative conjunction) | $a \otimes b$ |
| $A \multimap B$ (linear implication) | $a \multimap b$ (right adjoint to $a \otimes -$) |
| $\bot$ (negation, in classical/cyclic) | dualising element $d$, $a^\perp = a \multimap d$ |
| Cut (composition of proofs) | $\otimes$-composition followed by adjoint |
| $\&$ / $\oplus$ (additives) | meet / join in the underlying lattice |

Mulvey-Rosenthal [Mulvey 1986; Rosenthal 1990] establish that quantales arise
naturally as Lindenbaum-Tarski algebras of fragments of linear logic — in the
sense that the equivalence classes of formulae under provable equivalence,
together with multiplication coming from the cut rule, form a quantale. The
phase-semantics construction [Girard 1987], which builds star-autonomous posets
out of commutative monoids, is thus an *element-free* form of Yetter's quantale
semantics: the powerset $\mathcal{P}(M)$ of a commutative monoid $M$ is a
commutative quantale, and Girard's phase quantale $\mathcal{P}(M)_D$, indexed
by a cyclic dualising subset $D \subseteq M$, recovers a Girard quantale
[Yetter 1990; Rosenthal 1990 §2]. Brown-Gurr [Brown-Gurr 1993; 1994]
strengthen the picture with a representation theorem: every quantale is
isomorphic to a *relational quantale*, i.e. a quantale of binary relations on
some set ordered by inclusion under relational composition. Relational
quantales constitute a sound and complete class of models for noncommutative
intuitionistic linear logic; this gives the algebraic-semantics correspondence
its full rigour and provides concrete arrows for the cut rule [Brown-Gurr
1993].

The architectural significance for session types is that *every linear-logic-derived
session-type system already lives natively in a quantale*. The
Caires-Pfenning correspondence [Caires-Pfenning 2010; Caires-Pfenning-Toninho
2016] gives the dual interpretation: each linear proposition $A$ is a session
type, the cut rule is parallel composition of session-typed processes with
matching dualities, and process reduction is cut elimination. The same is true
for Wadler's CP and GV [Wadler 2014]: classical linear-logic propositions are
session types up to involution $A^\perp$, and the GV-to-CP translation is a
faithful embedding of a linear functional language into the proof theory.
Lindley-Morris [Lindley-Morris 2015] tighten the semantics. Dardha-Gay
[Dardha-Gay 2018] introduce Priority-based CP (PCP), and recent work on
*Asynchronous Priority-based Classical Processes* [APCP, 2023] supports
asynchronous communication in cyclic process networks while preserving the
linear-logic basis.

In all of these, the cut rule IS multiplication in the quantale; $A \multimap B$
IS the right adjoint to $A \otimes -$; deadlock-freedom (cut elimination)
corresponds to the well-foundedness of $\otimes$-reductions in the quantale
ordering. The session-type system inherits, transparently, every algebraic
fact about quantales — distributivity over joins (additive choice
$\oplus$), the involution $(-)^\perp$ (duality of session endpoints in classical
session types), the right adjoint structure (linear implication as channel
typing). Authors of these papers do not generally state this explicitly because
the syntactic proof-theoretic presentation is already complete; but the
architectural commitment of working *in the quantale, not merely with a logic
that has a quantale as its semantics* is what unlocks the next two movements.

### §IV.6.2 Cost-aware composition by working directly in the quantale

The Lawvere quantale $T = ([0,\infty], \geq, +, 0)$ — also called the *tropical
quantale* or the *cost quantale* — orders the extended non-negative reals by
the *reverse* of the usual order (so $0$ is the top element and $\infty$ the
bottom), with monoidal product $+$ and unit $0$. Joins in this order are
infima in the standard order: $a \vee b = \min(a, b)$. Lawvere
[Lawvere 1973] showed that generalised metric spaces are exactly categories
enriched over $T$: a $T$-category is a set $X$ with a distance assignment
$d: X \times X \to [0,\infty]$ satisfying $d(x,x) = 0$ (reflexivity) and
$d(x,z) + d(z,y) \geq d(x,y)$ (transitivity), which are exactly the
$T$-enriched identity and composition laws. Bacci-Mardare-Panangaden-Plotkin
[Bacci et al. 2023] develop three propositional logics over $T$ — the basic
fragment with finite conjunctions/disjunctions, tensor (= addition) and
linear implication (= truncated subtraction $a \multimap b = \max(b-a, 0)$);
an extension with the constant $1$ for integer values; and a third with
scalar multiplication for affine combinations. They prove decidable
completeness via Motzkin transposition, decidable consistency via
Fourier-Motzkin elimination, and a restricted strong completeness for
theories in normal form (excluding $\infty$-valued models) via Hurwicz's
generalisation of Farkas' Lemma. The technical content of $T$ as an
algebraic object is therefore now well understood; what is novel for the
present synthesis is its composition with the linear-logic quantale.

Given a linear-logic quantale $Q$ (a Girard or noncommutative quantale modelling
session-typed cut elimination) and the Lawvere quantale $T$, the *product
quantale* $Q \times T$ inherits a coordinatewise sup-lattice structure and a
componentwise tensor:
$(a, c) \otimes_{Q \times T} (b, d) = (a \otimes_Q b,\ c +_T d).$

This is the canonical product in the category of (unital) quantales. The first
component $Q$ governs *what protocol composition is well-typed*; the second
component $T$ governs *what the composition costs*. Crucially, the second
component composes *by the same algebraic operation as the first*: every cut
in the proof theory becomes a $+$ in the cost dimension. There is no separate
cost calculus to maintain, no metatheoretic supplement to verify. Protocol
composition gets cost-aware automatically because the cost is a coordinate of
the quantale element.

This is a strict generalisation of the linear-logic-as-session-types
correspondence, soundness preserved. Since $Q \times T$ is itself a quantale
satisfying all the axioms required for Yetter's correspondence to apply,
$(Q \times T)$-valued session typing inherits Yetter's algebraic completeness:
every cut-eliminable proof has a $(Q \times T)$-valued model, and conversely.
The cost annotations decorate the proof tree without altering the underlying
proof structure. Pragmatically, the cost can be lifted to *any*
sup-lattice-valued quantale: max-plus for worst-case bounds, the Viterbi
quantale $([0,1], \max, \cdot, 1)$ for probabilistic reliability, the
fuzzy-truth quantale $([0,1], \max, \min, 1)$ for soft constraint
composition, and so on. Bistarelli-Montanari-Rossi's c-semirings
[Bistarelli-Montanari-Rossi 1997] are the discrete analogue of this
machinery; the c-semiring of soft constraints is the quantale of soft
preferences, and the soft-CCP framework [Bistarelli-Montanari-Rossi 2006] is
the constraint-programming projection of the quantale enrichment.

The architectural significance for Prologos is direct. The PPN 4C addendum
(2026-04-26) establishes a tropical-quantale cost layer on the propagator
cells — cell values can carry a cost component which composes by $+$ as the
cell's lattice-valued primary content composes by its native merge. This is
already operationally exactly the $Q \times T$ construction: the primary
lattice $Q$ is whatever the cell stores (effect-edges, type information,
constraint data), the cost lattice is $T$. *Multi-party protocol composition
gets cost-aware automatically*, with the cost flowing through cuts
(composition events) without any additional propagator infrastructure.

### §IV.6.3 The MCC coherence rule as iterated tensor in a quantale

Multi-party session types have a foundational technical move that, in
classical presentations, is engineered by hand: the move from binary duality
$A \dashv A^\perp$ to *n-ary coherence* relating an arbitrary number of
participants. Carbone-Lindley-Montesi-Schürmann-Wadler [Carbone et al. 2016]
deliver this by constructing Multiparty Classical Processes (MCP), in which
duality is replaced by a coherence judgement $\vdash A_1, \ldots, A_n
\text{ coherent}$ that holds whenever the local types are jointly compatible.
The intermediate calculus Globally-governed Classical Processes (GCP) makes
the global type a proof term for the coherence judgement. The translation
GCP $\to$ CP factors a coherence proof through an arbiter process that
mediates communication.

Read algebraically in a quantale, coherence is iterated tensor. In a
*commutative* quantale $Q$, the n-ary tensor $\bigotimes_{i=1}^n a_i$ is well
defined and symmetric; coherence becomes the assertion that
$\bigotimes_{i=1}^n A_i \in Q$ has a non-trivial inhabitant in the sense of
the $Q$-valued truth structure. Symmetric n-ary composition follows for free
from the symmetry of $\otimes$. Equivalently, the coherence rule is the
algebraic codification of the universal property of the n-ary tensor: it
exists, it is symmetric, and its formation laws compose. The MCC framework's
hand-engineered n-ary symmetry is what the algebra delivers automatically.

In a *noncommutative* quantale, the tensor has a fixed order
$a \otimes b \neq b \otimes a$ in general, which is the algebraic shape of
asynchronous communication: messages have a sender-receiver direction, sends
and receives are not interchangeable, the order in which protocols compose
matters. The cyclic tensor of Yetter's [Yetter 1990] cyclic linear logic is
exactly the right tool here: it is associative but only cyclically symmetric,
which is the right symmetry for ring-like asynchronous protocols where
participants pass messages around a cycle. *A Logical Interpretation of
Asynchronous Multiparty Compatibility* [van den Heuvel-Pérez 2023; LOPSTR
2023] develops this direction concretely: forwarders generalise coherence,
the framework supports asynchronous communication, and the categorical shape
is exactly that of a noncommutative quantale.

The architectural significance is that Prologos's existing effect-ordering
quantale already needs to handle the ordering of n participants — effects
in `proc` definitions are not pairwise but multi-source, and the
set-union-over-`eff-edge` lattice plus transitive-closure propagator
solves the resulting fixpoint by saturating the partial order of effect
events. *That structure IS already n-ary coherence, viewed through the
algebraic lens.* The synthesis is: the project's binary-session machinery is
the commutative case (cut-elimination on dual endpoints); the multi-party
case is the n-ary tensor in a (possibly noncommutative) quantale; the
effect-ordering is the noncommutativity-tracking part that handles
asynchronous causal structure. All three are slices of the same algebraic
object.

### §IV.6.4 Quantale-enriched dependent type theory — the recent frontier

A theory of *quantale-enriched session types* needs the same scaffolding as
quantale-enriched type theory more broadly. The recent frontier provides the
technology.

Lawvere's foundational 1973 paper *Metric Spaces, Generalized Logic, and Closed
Categories* [Lawvere 1973] argued that any quantale $\Omega$ gives rise to a
generalised $\Omega$-valued logic whose models are categories enriched over
$\Omega$. Stubbe [Stubbe 2014] develops this perspective into a full
introduction to quantaloid-enriched categories (with a quantaloid being a
multi-object generalisation of a quantale, allowing for heterogeneously
sorted hom-quantales). The technology is by now mature: the basic notions of
$\mathcal{Q}$-categories, $\mathcal{Q}$-distributors, $\mathcal{Q}$-functors,
the Yoneda embedding into the free $\mathcal{Q}$-cocompletion, and
weighted (co)limits all transfer cleanly.

Kurz's CALCO 2025 invited talk *Logic Enriched over a Quantale* [Kurz 2025]
formalises a uniform variety of type constructors (endofunctors) on
$\Omega$-categories parameterised by the quantale $\Omega$. The construction
arises via enriched left Kan extensions from set-functors into
$\Omega$-categories. Each such endofunctor on $\Omega$-cat induces a category
of coalgebras with its own notion of behavioural equivalence
(probabilistic, metric, fuzzy, etc.) — all in the same uniform framework.
The talk frames the basic question: *how many existing notions of many-valued
bisimulation can be accounted for in this uniform framework*. The answer is:
many, possibly all, certainly enough to subsume the cost-aware, distance-aware,
and probabilistic settings the project anticipates needing.

Bacci-Mardare-Panangaden-Plotkin [Bacci et al. 2023] occupy the propositional
side of the same picture: $T$-valued propositional logic with axiomatisations,
decidability, completeness for fragments. Their framework is the quantitative
analogue of classical propositional logic, and is exactly what one would
expect to see at the *base* of a quantitative dependent type theory. The
"propositional logics for the Lawvere quantale" stand to a future quantale-
enriched DTT as classical propositional logic stands to Martin-Löf type theory.

The coalgebraic-logic side is occupied by Beohar-Gurke-König-Messing-Forster-
Schröder-Wild [Beohar et al. 2024] and Goncharov-Hofmann-Nora-Schröder-Wild
[Goncharov et al. 2023]. Beohar et al. derive fixpoint equations from modal
logics characterising behavioural equivalences and metrics, using
Hennessy-Milner theorems as corollaries of fixpoint preservation along Galois
connections between suitable lattices. The methodology applies equally to
branching-time bisimilarity and to linear-time trace equivalence; its
fixpoint orientation is exactly what the propagator-network substrate of
Prologos consumes. Goncharov et al. show that every functor lifting and
every functor on (quantale-valued) metric spaces that preserves isometries
is *Kantorovich* — i.e., the induced behavioural distance can be characterised
by a quantitative modal logic. This means quantitative behavioural distances
on session-typed processes can be presented via a quantale-valued modal logic
without loss; the fixpoint of the Kantorovich lifting *is* the behavioural
distance, computable on the propagator network.

For dependent types specifically, *autonomous categories enriched over
generalised metric spaces* (Dahlqvist-Neves [Dahlqvist-Neves 2022,
arXiv:2208.14356]) and the *internal language for categories enriched over
generalised metric spaces* [Dahlqvist-Neves 2022, CSL] develop a $V$-equational
deductive system for linear $\lambda$-calculus that is sound and complete for
a class of enriched autonomous categories. This is, in effect, a
quantale-enriched linear $\lambda$-calculus — the linear-logic-derived
session-type calculi of §IV.6.1 lift cleanly into this framework. Dal Lago-
Murgia [Dal Lago-Murgia 2023] develop *contextual behavioural metrics*,
which give a metric counterpart to contextual equivalence — a cost-aware
notion of program equivalence ready to be lifted to a session calculus.

The takeaway is that the technical stack required for quantale-enriched
session types — quantale-enriched categories, quantale-valued logics,
behavioural distances via Kantorovich liftings, Hennessy-Milner theorems via
Galois connections, internal languages for the enrichment — is now in
place. What is missing is the synthesis with multi-party session types and
the propagator-network operational substrate.

### §IV.6.5 Fibrational role projection

Multi-party session-type frameworks split a global protocol description into
local roles via a *projection operation* $G \restriction_p$, which extracts
the behavioural type of participant $p$ from the global type $G$
[Honda-Yoshida-Carbone 2008; Coppo et al. 2012]. Classical projection is a
partial function defined by structural induction on $G$, with side-conditions
guaranteeing that the projection is well-defined (not all global types
project — the *projectability* condition is non-trivial and the source of
much of the complexity in MPST).

The categorical reframing makes projection a universal construction. Take
the *participant lattice* $\mathcal{P}$ — typically the powerset $2^P$ of
the participant set $P$, ordered by inclusion. Build a fibration
$\pi : \mathcal{B} \to \mathcal{P}$ where the fibre $\mathcal{B}_S$ over a
subset $S \subseteq P$ is the category of behavioural types involving exactly
the participants in $S$. The total space $\mathcal{B}$ contains all
behavioural-type configurations; the base $\mathcal{P}$ tracks which
participants are involved. Projection is the *opcartesian lift* of the
inclusion $\{p\} \hookrightarrow S$: given a behavioural type
$T \in \mathcal{B}_S$ (involving participants $S$) and a single participant
$p \in S$, the opcartesian lift yields the projection $T \restriction_p \in
\mathcal{B}_{\{p\}}$, characterised by the universal property that any other
behavioural type in $\mathcal{B}_{\{p\}}$ obtained by "forgetting all
participants but $p$" factors through it.

The categorical structure (opfibration with opcartesian lifts) is the standard
covariant version of Grothendieck's fibration construction [Pavlovic 1995,
*Categorical Logic of Concurrency I: Synchronous Processes*; Loregian-Riehl
2018, *Categorical Notions of Fibration*]. In the synchronous case Pavlovic
shows that $\Sigma_T : T \to S$ for synchronisation trees is even a
*hyperfibration* — supporting full higher-order predicate logic. The
opcartesian shape is the right one for projection because it preserves the
*coherence-relevant structure*: any two roles $p, q$ project from the same
global $G$, and the joint projection is given by the opcartesian lift to
$\{p, q\}$, which factors through the individual projections to $\{p\}$ and
$\{q\}$. Compatibility (the side condition that classical MPST imposes
syntactically) becomes the existence of a cone over a diagram of opcartesian
lifts.

The architectural significance is twofold. First, projection becomes a
universal categorical operation, not an ad-hoc partial function. The fibration
view subsumes the classical conditions: when the lift exists, projection
succeeds; when no lift exists, the global type is non-projectable. This is
*structurally* the same as Lawvere's "quantifier as adjoint" framework
[Lawvere 1969] transposed to behavioural types — projection is the dependent
sum / left adjoint to a contraction along participant-set inclusion. Second,
the participant lattice $\mathcal{P}$ being a Boolean algebra (the powerset)
means the fibration is *indexed by a quantale-valued lattice* in a perfectly
clean sense: in the quantale-enriched setting, the fibres carry distance
data; the base carries algebraic data; the opcartesian lifts compose with the
quantale structure. Quantale-enriched MPST is then naturally a fibration
$\pi : \mathcal{B} \to \mathcal{P}$ where each fibre is a quantale-enriched
category and opcartesian lifts are quantale-valued natural transformations.

A second layer of fibrational structure handles the cost dimension. Stack a
*cost fibration* on top: $\rho : \mathcal{B}^{cost} \to \mathcal{B}$ with
fibre over each behavioural type giving the cost-annotated refinement.
Composition of fibrations is a fibration, and the resulting compound captures
*cost-aware role projection*: project a participant out, get the local
behavioural type *together with* its inherited cost annotation. The
projection of the global protocol's cost to a single role is exactly the
opcartesian lift in the compound fibration. Multi-dimensional cost (latency
$\times$ message count $\times$ protocol depth) corresponds to a product of
cost fibrations, with Pareto reasoning happening at the lattice meet.

### §IV.6.6 Quantale-valued realizability over an LTS

The realisability question for multi-party session types asks: given a global
protocol $G$ (or, more generally, a multi-party behavioural specification),
is there an implementation — a tuple of local processes, one per role —
that jointly realises $G$? Recent work has reformulated this question in
LTS terms. Scalas-Yoshida [Scalas-Yoshida] adopt semantic criteria over
syntactic restrictions; Stutz et al. [Stutz et al. ECOOP 2023] establish
that asynchronous MPST implementability is *decidable*, by reduction to
message sequence chart problems. The synthetic-MPST style [Jongmans-Ferreira
2023; Majumdar et al. 2024] checks an LTS of the spec against an LTS of the
implementation by simulation/bisimulation refinement.

The quantale-enriched formulation extends this directly. Equip the LTS with
quantale-valued transitions: each transition $s \xrightarrow{a} s'$ carries
not only a label $a$ but a quantale element $q(a) \in Q$ representing its
cost (or its probability, or its likelihood, or whatever the quantale tracks).
The realisability question becomes: *is there a $Q$-valued witness in the
propagator network for the constraint that the LTS imposes?* Concretely:

1. The global protocol induces an LTS $G^*$ with quantale-valued transitions.
2. The candidate implementation induces a parallel composition LTS $\Pi$ with
quantale-valued transitions.
3. A simulation $G^* \preceq_Q \Pi$ in the $Q$-enriched sense is a function
$\sigma : G^* \to \Pi$ such that for every $g \xrightarrow{a, q} g'$ in
$G^*$ there is $\sigma(g) \xrightarrow{a, q'} \sigma(g')$ in $\Pi$ with
$q' \leq_Q q$ (the implementation's cost is at most the spec's, in the
quantale order — for tropical $T$, this is "the implementation is at least
as fast"). 
4. Realisability is the existence of such a $\sigma$ within budget $B \in Q$:
$\bigotimes_{(g,a,g')} q'(a) \leq_Q B$.

This is a quantale-valued fixpoint computation. The Kantorovich lifting of
the LTS functor [Goncharov et al. 2023] gives a behavioural distance
$d : G^* \times \Pi \to Q$ as the greatest fixpoint of the Kantorovich
functional. Realisability becomes $d(G^*, \Pi) \leq_Q B$ — a budget
constraint on the Kantorovich distance. By the Hennessy-Milner theorem in
the quantale-enriched setting [Beohar et al. 2024; Goncharov et al. 2023],
this is equivalent to a satisfaction relation in a quantitative modal logic;
either side of the equivalence can be the basis of an algorithm.

The architectural significance: Prologos's propagator network already computes
lattice-valued fixpoints under monotone merge, and the existing
tropical-quantale cost layer (PPN 4C addendum) is exactly the operational
substrate for $T$-valued cell content. The Kantorovich functional can be
installed as a propagator: it reads the LTS structure from cells, computes
distances, and writes the fixpoint into a designated cell. Convergence is
guaranteed by the lattice's CALM-monotone-within-strata structure. The
*answer to "is this protocol realisable within budget $B$?"* is, after the
fixpoint computes, the value of a single cell read.

Multi-dimensional cost is handled by lifting to the product quantale
$T_1 \times T_2 \times \cdots \times T_k$, where $T_i$ is the quantale for
cost dimension $i$. The product is itself a quantale (product of suplattices
with componentwise tensor); the Kantorovich lifting commutes with quantale
products [Goncharov et al. 2023, applying compositionality of the Kantorovich
lifting; Wild et al. 2024]; so the multi-dimensional behavioural distance is
the product of the per-dimension distances. *Pareto-style reasoning over
multiple cost projections falls out of the quantale structure*. The
realisability question becomes *for which budget tuples
$(B_1, \ldots, B_k)$ does an implementation exist?*, and the
answer is the Pareto frontier of the multi-dimensional fixpoint — itself a
lattice-valued cell.

### §IV.6.7 Effect ordering as the existing causal-delivery quantale

Architecture A+D of Prologos — the existing effect-ordering system — uses
set-union over an `eff-edge` accumulation lattice plus a transitive-closure
propagator. A `proc` definition emits effect-edges (causal links between
events), the accumulation is monotone (set-union is the join in the
powerset lattice), and the transitive-closure propagator iterates until
the partial order of effect events stabilises. Operationally, this is a
quantale: the set-union accumulates monoidal compositions of effects (the
$\otimes$), the transitive-closure step computes the right adjoint $\multimap$
implicitly through the saturation, and the ordering on accumulated edges
is the lattice ordering on subsets. The operations are CALM-monotone within
strata, by construction.

Layered on top of multi-party protocols, this effect quantale ensures
*causal-delivery soundness automatically*. The MPST projectability condition
demands that local types respect the causal structure of the global type;
the effect quantale enforces this at the propagator level. There is no
separate causal-delivery analysis to perform — the effect quantale's
fixpoint computation IS the causal-delivery check. When a multi-party
protocol's local types are installed as effect-emitters, the existing
machinery saturates their causal closure; conflicts (cycles in causality)
manifest as the lattice exceeding a designated bot value, signalling
non-realisability.

The connection to binary session types is structural identity. Binary session
typing in the linear-logic style imposes a causality between sender and
receiver — the sender's type is dual to the receiver's, and the two endpoints
must compose by cut. This is the binary case of effect ordering: a single
edge from sender-event to receiver-event. Multi-party generalises by
allowing multiple participants and a richer pattern of edges; the quantale
structure is exactly the same. *The project's session types use the effect
quantale for binary causality; the multi-party case is the same machinery
scaled up by polynomial-functor structure* (where the polynomial functor
counts the participants and tracks their constructor positions; cf. §IV.5).
The effect quantale's monoidal structure is preserved under polynomial-functor
extension because polynomial functors preserve quantale enrichment in the
LCCC setting [Goncharov-Hofmann-Nora-Schröder-Wild 2023; Cranch-Doherty-
Struth 2017].

This means a substantial amount of the multi-party session-type machinery
*does not need to be implemented*. It is already there, in the binary case,
in a form that scales by structural extension. The remaining work is the
polynomial-functor scaling and the integration with the role-projection
fibration of §IV.6.5.

### §IV.6.8 The unique Prologos contribution: cost-aware multi-party protocols

The synthesis of polynomial functors over LCCC (§IV.5), quantale-enriched
session types (this slice), and the existing tropical-quantale cost layer
delivers an architectural offering nobody currently has in the multi-party
session-type literature:

*Multi-party protocols with native cost-aware realizability, expressed as a
single fixpoint computation in a propagator network.*

Stating this concretely:

**Inputs.** A global protocol $G$ given as a polynomial functor over an
LCCC $\mathcal{C}$, with role projection given by the opcartesian lifts of
a fibration $\pi : \mathcal{B} \to \mathcal{P}$. A cost quantale
$T = T_1 \times \cdots \times T_k$ for $k$ cost dimensions (latency, message
count, protocol depth, energy, ...). A budget tuple $B = (B_1, \ldots, B_k)$
or a Pareto specification.

**Computation.** Install the LTS of $G$ as cells with quantale-valued
transitions. Install the candidate implementation $\Pi$ similarly. Install
the Kantorovich functional as a propagator. The propagator network's BSP
scheduler computes the fixpoint; cells stabilise at the behavioural distance
$d(G^*, \Pi) \in T$. CALM-monotone-within-strata structure guarantees
convergence and coordination-freedom within strata; the strata stack handles
the non-monotone retraction needed when an implementation candidate is
abandoned.

**Output.** A single cell read returns realisability within budget. A Pareto
frontier query returns a set of (implementation, cost-tuple) pairs that are
non-dominated. Compositional changes (adding a participant, modifying a
local type) trigger localised re-computation: only the Kantorovich-functional
cells whose dependencies changed re-fire; the rest of the fixpoint is
already on the network.

**What is unique.** The literature has each of the pieces — Caires-Pfenning
linear-logic-as-session-types is widely understood, MPST has a mature
treatment (Honda-Yoshida-Carbone 2008; Carbone et al. 2016; APCP 2023),
behavioural distances on quantale-enriched coalgebras have been worked out
(Beohar et al. 2024; Goncharov et al. 2023), tropical and Lawvere quantales
are understood (Bacci et al. 2023), polynomial functors over LCCC for type
theory are understood (Polynomial Functors and the type-theoretic literature),
and propagator-network fixpoint computation is understood (Sussman-Radul,
Bloom and the CALM theorem). What no current MPST framework has is
*all of these in the same operational substrate* — and specifically, the
substrate that turns the realisability question, with multi-dimensional cost,
into a single fixpoint computation that the existing infrastructure runs.

The implementability question, in the quantale-enriched view, is no longer
a separate decision procedure to be designed (as it currently is in
Stutz et al. 2023, where decidability had to be established by reduction to
message sequence charts). It is a *consequence* of the algebraic structure,
computed by the same propagator network that runs the rest of the language.
Adding a cost dimension does not require a separate analysis — it requires
adding a coordinate to the quantale. Adding a participant does not require
re-deriving projectability — it requires adding an opcartesian lift to the
fibration. The architectural offering is *integrative*: every existing
piece becomes a coordinate of a single algebraic object on a single
propagator runtime.

The verdict the architectural target demands is:

> Multi-party protocols are polynomial functors over a quantale-valued
> propagator runtime, with role projection as opcartesian lifts in a fibration
> over a participant lattice, behaviour as coalgebras, and realizability as a
> quantale-valued fixpoint computation in the propagator network.

The evidence assembled here — Yetter's quantale-as-linear-logic semantics
[Yetter 1990], the Lawvere quantale and metric reasoning [Lawvere 1973;
Bacci et al. 2023], MCC coherence as iterated tensor [Carbone et al. 2016;
van den Heuvel-Pérez 2023], quantale-enriched DTT [Kurz 2025; Stubbe 2014;
Dahlqvist-Neves 2022], fibrational projection [Pavlovic 1995; Loregian-Riehl
2018], quantale-enriched coalgebraic logic [Beohar et al. 2024;
Goncharov et al. 2023], the existing effect quantale on Prologos's runtime,
and the existing tropical-quantale cost layer — supports each clause of
that statement. The remaining work is the synthesis: making the algebra
operational on the propagator substrate.

---

## Annotated bibliography

### Foundational quantale theory and linear logic

- **Yetter, D. N. (1990).** *Quantales and (Noncommutative) Linear Logic.*
  Journal of Symbolic Logic 55(1):41–64.
  *Load-bearing.* Establishes that quantales are sound and complete models for
  fragments of linear logic, both commutative and Girard's cyclic
  noncommutative. Provides the algebraic-semantics correspondence on which
  every subsequent linear-logic-as-session-types result implicitly relies.

- **Mulvey, C. J. (1986).** *&.* Supplemento ai Rendiconti del Circolo
  Matematico di Palermo, Serie II, 12:99–104.
  *Load-bearing.* Introduces quantales (originally as models for the logic of
  quantum mechanics) — the algebraic objects subsequently shown by Yetter to
  be the right semantics for linear logic.

- **Mulvey, C. J., and Pelletier, J. W. (2001).** *On the Quantisation of
  Points.* Journal of Pure and Applied Algebra 159:231–295.
  Develops the theory of quantales further with applications to C*-algebras
  and quantum logic; provides the technical apparatus underpinning later
  representation theorems.

- **Brown, C., and Gurr, D. (1993).** *A Representation Theorem for Quantales.*
  Journal of Pure and Applied Algebra 85:27–42.
  *Load-bearing.* Every quantale is isomorphic to a relational quantale.
  Provides the rigorous form of the algebraic-semantics correspondence and
  enables concrete representation of session-typed processes via relations.

- **Brown, C., and Gurr, D. (1994).** *Relations and Non-Commutative Linear
  Logic.* Journal of Pure and Applied Algebra 105:117–136.
  Strengthens the relational-quantale correspondence to a soundness and
  completeness theorem for noncommutative intuitionistic linear logic.

- **Rosenthal, K. I. (1990).** *Quantales and Their Applications.* Pitman
  Research Notes in Mathematics Series 234. Longman Scientific & Technical.
  *Load-bearing.* The standard monograph on quantales with applications to
  ideal theory of rings, closed ideals of C*-algebras, and Girard's linear
  logic. Comprehensive technical reference.

- **Niefield, S., and Rosenthal, K. (1990).** *A Note on Girard Quantales.*
  Cahiers de Topologie et Géométrie Différentielle Catégoriques 31(1):3–6.
  Definition and basic properties of Girard quantales — quantales with a
  cyclic dualising element, modelling classical (involutive) linear logic.

- **Girard, J.-Y. (1987).** *Linear Logic.* Theoretical Computer Science
  50:1–101.
  The original paper introducing linear logic and phase semantics. Phase
  semantics is essentially the element-free version of Yetter's quantale
  semantics.

### Session types and linear logic

- **Caires, L., and Pfenning, F. (2010).** *Session Types as Intuitionistic
  Linear Propositions.* CONCUR 2010, LNCS 6269:222–236.
  Foundational paper establishing the propositions-as-types correspondence
  for session types. The intuitionistic case.

- **Caires, L., Pfenning, F., and Toninho, B. (2016).** *Linear Logic
  Propositions as Session Types.* Mathematical Structures in Computer
  Science 26(3):367–423.
  The full technical development; the SILL family of languages is built on
  this foundation.

- **Wadler, P. (2014).** *Propositions as Sessions.* Journal of Functional
  Programming 24(2-3):384–418. (Earlier version: ICFP 2012.)
  Introduces CP (Classical Processes) and GV (linear functional language with
  session types). Establishes the classical-linear-logic interpretation; CP
  has duality $A \dashv A^\perp$.

- **Lindley, S., and Morris, J. G. (2015).** *A Semantics for Propositions as
  Sessions.* ESOP 2015, LNCS 9032:560–584.
  Tightens the operational semantics of CP and GV.

- **Honda, K., Yoshida, N., and Carbone, M. (2008).** *Multiparty Asynchronous
  Session Types.* POPL 2008:273–284.
  *Load-bearing.* Introduces multi-party session types with global types and
  endpoint projection. Most influential POPL paper award.

- **Coppo, M., Dezani-Ciancaglini, M., Yoshida, N., and Padovani, L. (2012).**
  *On Global Types and Multi-Party Session.* Logical Methods in Computer
  Science 8(1).
  Develops the formal theory of global types and projection.

- **Carbone, M., Lindley, S., Montesi, F., Schürmann, C., and Wadler, P.
  (2016).** *Coherence Generalises Duality: A Logical Explanation of
  Multiparty Session Types.* CONCUR 2016, LIPIcs 59:33:1–33:15.
  *Load-bearing.* Introduces Multiparty Classical Processes (MCP) and the
  coherence rule generalising duality to n-ary compatibility. The
  Curry-Howard basis for cost-aware multi-party in this synthesis.

- **Carbone, M., Montesi, F., Schürmann, C., and Yoshida, N. (2017).**
  *Multiparty Session Types as Coherence Proofs.* Acta Informatica 54:243–269.
  Journal version of the Carbone et al. CONCUR paper.

- **van den Heuvel, B., and Pérez, J. A. (2023).** *A Logical Interpretation
  of Asynchronous Multiparty Compatibility.* LOPSTR 2023, LNCS 14330:131–149.
  *Load-bearing.* Generalises coherence via forwarders; supports asynchronous
  multi-party communication while preserving the linear-logic basis.

- **Dardha, O., and Gay, S. J. (2018).** *A New Linear Logic for Deadlock-Free
  Session-Typed Processes.* FoSSaCS 2018, LNCS 10803:91–109.
  Priority-based CP (PCP); cyclic interconnected processes with
  deadlock-freedom.

### Cost-aware and resource-aware session types

- **Das, A., Hoffmann, J., and Pfenning, F. (2018).** *Work Analysis with
  Resource-Aware Session Types.* LICS 2018:305–314.
  Resource-aware session types based on amortised analysis. The discrete cost
  case of the quantale-enriched picture.

- **Das, A. (2021).** *Resource-Aware Session Types for Digital Contracts.*
  Ph.D. Thesis, CMU-CS-21-112.
  Expanded technical treatment.

- **Das, A., Qadeer, S., Janin-Potiron, J., and Hoffmann, J. (2023).**
  *Probabilistic Resource-Aware Session Types.* Proc. ACM Programming
  Languages 7(POPL):1–32.
  Probabilistic extension of resource-aware session types — equivalent in
  the quantale-enriched view to working over the Viterbi quantale on top of
  the resource quantale.

- **Bistarelli, S., Montanari, U., and Rossi, F. (1997).** *Semiring-Based
  Constraint Satisfaction and Optimization.* Journal of the ACM 44(2):201–236.
  *Load-bearing.* C-semirings as the algebraic structure for soft
  constraints. The discrete analogue of the cost-aware quantale.

- **Bistarelli, S., Montanari, U., and Rossi, F. (2006).** *Soft Concurrent
  Constraint Programming.* ACM Trans. Computational Logic 7(3):563–589.
  Soft CCP as a quantale-valued CCP — the constraint-programming projection
  of the quantale-enrichment story.

### Tropical and metric quantale theory

- **Lawvere, F. W. (1973).** *Metric Spaces, Generalized Logic, and Closed
  Categories.* Rendiconti del Seminario Matematico e Fisico di Milano
  43:135–166. Reprinted: Reprints in Theory and Applications of Categories
  1:1–37 (2002).
  *Load-bearing.* Generalised metric spaces are categories enriched over
  $[0,\infty]$. Founds the theory that the Lawvere quantale governs.

- **Bacci, G., Mardare, R., Panangaden, P., and Plotkin, G. (2023).**
  *Propositional Logics for the Lawvere Quantale.* Proceedings of MFPS 2023,
  ENTICS. arXiv:2302.01224.
  *Load-bearing.* Three propositional logics over the tropical Lawvere
  quantale $[0,\infty]$ with axiomatisations, decidability, completeness
  (for fragments). The propositional base for quantitative metric reasoning.

- **Bacci, G., Mardare, R., Panangaden, P., and Plotkin, G. (2026).**
  *Rational Lawvere Logic (Invited Paper).* CSL 2026, LIPIcs.
  Continued development of the Lawvere-quantale propositional logic, with
  rationality assumptions. Refines the 2023 paper.

- **Le Boudec, J.-Y., and Thiran, P. (2001).** *Network Calculus: A Theory
  of Deterministic Queueing Systems for the Internet.* LNCS 2050. Springer.
  Min-plus / tropical algebra applied to communication networks. The
  applied-engineering precursor to the cost-aware multi-party picture.

- **Cohen, G., Gaubert, S., and Quadrat, J.-P. (1999).** *Max-Plus Algebra
  and System Theory: Where We Are and Where to Go Now.* Annual Reviews in
  Control 23:207–219.
  Survey of max-plus / tropical algebra for discrete event systems. Applied
  side of the tropical-quantale story.

- **Cohen, G., Gaubert, S., and Quadrat, J.-P. (2004).** *Duality and
  Separation Theorems in Idempotent Semimodules.* Linear Algebra and
  Applications 379:395–422.
  Foundational duality results for tropical and idempotent algebra.

### Quantale-enriched categories, logic, and dependent types

- **Stubbe, I. (2014).** *An Introduction to Quantaloid-Enriched Categories.*
  Fuzzy Sets and Systems 256:95–116.
  Tutorial introduction to quantaloid- and quantale-enriched categories.
  Standard reference for the technical machinery.

- **Kurz, A. (2025).** *Logic Enriched over a Quantale (Invited Talk).*
  CALCO 2025, LIPIcs 342:2:1–2:16.
  *Load-bearing.* Uniform variety of type constructors (endofunctors) on
  quantale-enriched categories parameterised by the quantale; basis for
  many-valued bisimulation in a single framework.

- **Dahlqvist, F., and Neves, R. (2022).** *The Syntactic Side of Autonomous
  Categories Enriched over Generalised Metric Spaces.* arXiv:2208.14356.
  $V$-equational deductive system for linear $\lambda$-calculus, sound and
  complete for enriched autonomous categories. The quantale-enriched linear
  $\lambda$-calculus.

- **Dahlqvist, F., and Neves, R. (2022).** *An Internal Language for
  Categories Enriched over Generalised Metric Spaces.* CSL 2022, LIPIcs
  216:16:1–16:18.
  Internal language for the metric-enriched setting; the type-theoretic
  shape of quantale-enriched session types.

- **Dal Lago, U., and Murgia, M. (2023).** *Contextual Behavioural Metrics.*
  arXiv:2307.07400.
  Contextual equivalence in quantitative form; behavioural metrics on a
  process calculus.

### Coalgebra, behavioural distances, and Hennessy-Milner theorems

- **Beohar, H., Gurke, S., König, B., Messing, K., Forster, J., Schröder, L.,
  and Wild, P. (2024).** *Expressive Quantale-Valued Logics for Coalgebras:
  An Adjunction-Based Approach.* STACS 2024, LIPIcs 289:10:1–10:18.
  *Load-bearing.* Fixpoint equations from modal logics characterising
  behavioural equivalences and metrics, via Galois connections. Provides the
  fixpoint-on-the-network basis for realisability computation.

- **Goncharov, S., Hofmann, D., Nora, P. T., Schröder, L., and Wild, P.
  (2023).** *Kantorovich Functors and Characteristic Logics for Behavioural
  Distances.* FoSSaCS 2023, LNCS 13992:46–67. arXiv:2202.07069.
  *Load-bearing.* Every functor lifting that preserves isometries is
  Kantorovich; the induced behavioural distance is characterised by a
  quantitative modal logic. The basis for cost-aware behavioural distances
  on quantale-enriched coalgebras.

- **König, B., et al. (2024–2025).** *Behavioural Metrics: Compositionality
  of the Kantorovich Lifting and an Application to Up-To Techniques.*
  arXiv:2404.19632.
  Compositional behaviour of Kantorovich lifting — the lifting of a composed
  functor coincides with the composition of liftings. Crucial for
  multi-dimensional Pareto reasoning.

- **Wild, P., Schröder, L., et al. (2024).** *Quantitative Graded Semantics
  and Spectra of Behavioural Metrics.* CSL 2025, LIPIcs 33.
  Spectra of behavioural metrics in the graded semantic setting. Useful for
  the multi-dimensional cost projection of §IV.6.6.

### Categorical concurrency, fibrations, and projection

- **Pavlovic, D. (1995).** *Categorical Logic of Concurrency and Interaction
  I: Synchronous Processes.* Manuscript and ORA archive.
  *Load-bearing.* Develops the opfibration / fibration framework for
  synchronous concurrency. Synchronisation trees support full higher-order
  predicate logic.

- **Loregian, F., and Riehl, E. (2020).** *Categorical Notions of Fibration.*
  Expositiones Mathematicae 38(4):496–514. arXiv:1806.06129.
  Modern survey of fibration concepts, including opfibrations and
  opcartesian lifts.

- **Lawvere, F. W. (1969).** *Adjointness in Foundations.* Dialectica
  23:281–296.
  Quantifiers as adjoints; the conceptual basis for projection-as-adjoint.

### Concurrent quantales and pomsets

- **Cranch, J., Doherty, S., and Struth, G. (2021).** *Convolution and
  Concurrency.* Mathematical Structures in Computer Science 31(8):918–949.
  arXiv:2002.02321.
  *Load-bearing.* Concurrent quantales and concurrent Kleene algebras as
  convolution algebras. Provides the algebraic structure for asynchronous
  concurrent composition; relevant for the noncommutative case in §IV.6.3.

- **Hoare, C. A. R., Möller, B., Struth, G., and Wehrman, I. (2009).**
  *Concurrent Kleene Algebra.* CONCUR 2009, LNCS 5710:399–414.
  Foundational paper on concurrent Kleene algebra; the discrete substrate
  for concurrent quantales.

- **Bannister, C., Höfner, P., and Struth, G. (2021).** *Effect Algebras,
  Girard Quantales and Complementation in Separation Logic.* RAMICS 2021,
  LNCS 13027:30–47.
  Girard quantales applied to separation logic; related techniques applicable
  to session-typed concurrency.

### Synthetic and decidability-oriented multi-party session types

- **Stutz, F., Yoshida, N., and Bocchi, L. (2023).** *Asynchronous Multiparty
  Session Type Implementability is Decidable — Lessons Learned from Message
  Sequence Charts.* ECOOP 2023, LIPIcs 263:32:1–32:31.
  Decidability of asynchronous MPST implementability; baseline against which
  the quantale-enriched approach generalises.

- **Jongmans, S.-S., and Ferreira, F. (2023).** *Synthetic Behavioural Typing:
  Sound, Regular Multiparty Sessions via Implicit Local Types.* ECOOP 2023.
  Synthetic-MPST style; LTS-based realisability checking.

- **Scalas, A., and Yoshida, N. (2019).** *Less Is More: Multiparty Session
  Types Revisited.* POPL 2019.
  Semantic over syntactic restrictions for MPST; underpins the LTS-based
  formulation of realisability used in §IV.6.6.

- **Carbone, M., Lindley, S., Montesi, F., Schürmann, C., and Wadler, P.
  (2019).** *Multiparty Classical Choreographies.* In LOPSTR 2019.
  Multi-party choreographies in the linear-logic setting. Continues the
  Curry-Howard tradition for choreographic programming.

### Propagator networks and the CALM theorem

- **Hellerstein, J. M., and Alvaro, P. (2020).** *Keeping CALM: When
  Distributed Consistency is Easy.* Communications of the ACM 63(9):72–81.
  arXiv:1901.01930.
  CALM theorem: monotone problems are coordination-free. The justification
  for working in the join-semilattice / quantale-enriched setting on the
  propagator runtime.

- **Conway, N., Marczak, W. R., Alvaro, P., Hellerstein, J. M., and Maier, D.
  (2012).** *Logic and Lattices for Distributed Programming.* SoCC 2012:1–14.
  Lattices in distributed programming. The Bloom language; precursor to
  Prologos's propagator-network approach.

- **Sussman, G. J., and Radul, A. (2009).** *The Art of the Propagator.*
  MIT CSAIL Tech Report MIT-CSAIL-TR-2009-002.
  Foundational treatment of propagator networks.

### Companion artifact

- **Async-research artifact (2026-05-05).** *Asynchronous Programming Quantale
  Research Program.* docs/research/2026-05-05_ASYNCHRONOUS_PROGRAMMING_QUANTALE_RESEARCH_PROGRAM.md.
  §3.4–§3.5 cover foundational quantale theory, §7 the cross-cutting
  deep-dive. Cross-referenced for material this slice does not re-cover.

---

## Part IV.7 — Conjunctive Composition and Bundle Algebra Precedents

### §IV.7.1 The Prolog precedent for conjunctive composition

The intuition that "composition is trivial using logical conjunctives for refinement (you can use one sequent as a rule in another's body)" is not a casual remark. It is the operational summary of fifty years of declarative programming experience, and it points directly at an algebraic fact that the multi-party session type literature has consistently looked past. The Prolog clause is the canonical site where this fact first becomes visible.

A Prolog clause has the schema `H :- G1, G2, ..., Gn.`, where `H` is the head (the goal the clause defines) and `G1, ..., Gn` is the body. The comma is conjunction; semantically `,/2` is the conjunction connective on goal terms, paired with `;/2` for disjunction, and these connectives "can only appear in the body, not in the head of a rule" [Prolog syntax and semantics]. The body is a *conjunction of goals*, and Prolog's resolution-with-unification — Robinson's resolution principle (1965) [Prolog/SWI documentation] — proceeds by replacing the head goal with its body, suitably substituted, and pursuing all body goals together as the new conjunctive goal.

What makes this composition is not the resolution mechanism but the *substitutional structure* on conjunctive bodies. If clause `R1` is `H :- G1, G2.` and clause `R2` is `Gi :- K1, K2.` for some `Gi`, then substituting `R2` into the body of `R1` yields `H :- ..., K1, K2, ...` — *the body of one clause appears verbatim as a sub-conjunction of another*. There is no reconciliation step; no method-resolution-order; no diamond linearisation. The body is a flat set (modulo order, which Prolog's left-to-right strategy uses for execution but which the underlying logic does not require) of goal atoms, and composing clauses adds to the set.

This is the operational signature of an algebraic fact: conjunction in classical/intuitionistic propositional logic is **associative**, **commutative**, and **idempotent**. Three additional facts make Prolog clause-bodies particularly clean:

1. **Associativity**: `(G1, G2), G3 ≡ G1, (G2, G3)`. The body is unambiguous as a multi-set.
2. **Commutativity at the logical level**: `G1, G2 ≡ G2, G1` (Prolog evaluates left-to-right but the *logic* admits any order; pure Datalog respects this fully).
3. **Idempotence**: `G, G ≡ G` (any sufficiently general clause body is monotone-idempotent under conjunction; "stuttering" goals add no information).

Together these are the laws of a meet-semilattice [Wikipedia, *Semilattice*]. The body of a clause is an element of the free meet-semilattice on goal atoms. Composing clauses by substituting one body into another is the *meet* of two such elements (after renaming). No reconciliation operator is needed because the meet of meet-semilattice elements is, by construction, the unique greatest lower bound — a structurally determined operation, not an ad-hoc partial function. The deep precedent is: **logic-programming composition is meet, not merge.**

This contrasts sharply with the OO-inheritance lineage, where composition (a class extends two classes) requires a reconciliation operator (the C3 linearisation algorithm) to choose between competing method definitions; the operation is *partial* because the two superclasses might define methods incompatibly, and the reconciliation is *order-sensitive* (the linearisation depends on the textual order of bases). The C3 algorithm exists to paper over the fact that the underlying composition is not a meet — it is an attempt to recover an ordering from data that does not algebraically support one [GeeksforGeeks, *Diamond Problem*]. Conjunctive composition, by contrast, has nothing to reconcile. Two clause bodies meet to a single body that requires *both* to succeed, and the underlying logic enforces consistency.

### §IV.7.2 Concurrent Constraint Programming as the formal lineage

The categorical-algebraic content of the Prolog precedent was made formal by the Concurrent Constraint Programming (cc) framework of Saraswat, Rinard, and Panangaden [Saraswat, Rinard, Panangaden 1991], whose closure-operator semantics gives the canonical mathematical realisation of conjunctive composition for concurrent agents. The companion async-research artifact §3.3 covers cc(D) in operational depth; this section foregrounds the *algebraic* skeleton.

The cc framework parameterises over a constraint system D, a complete algebraic lattice with least upper bound (the join `⊔`) and least/greatest elements [Gabbrielli & Valencia 2010]. The lattice element `c ⊑ d` is read "`d` entails `c`"; the store accumulates information monotonically by `tell c` operations that move the store from `s` to `s ⊔ c`. An `ask c` agent blocks until the store entails `c`. A program denotes a closure operator on D — that is, a function `f : D → D` with `f(c) ⊒ c` (extensive), `f(f(c)) = f(c)` (idempotent), and `c ⊑ d ⇒ f(c) ⊑ f(d)` (monotone) — equivalently characterised by its set of fixed points [Wikipedia, *Closure operator*].

The cardinal mathematical fact: **the set of fixed points of a closure operator on a complete lattice is itself a complete lattice under intersection**, and equivalently **the closure operators on a complete lattice form a complete lattice under pointwise order**, with meet given by *intersection of fixpoint-sets* — a simple consequence of the Knaster–Tarski theorem [Tarski 1955; Wikipedia, *Knaster–Tarski theorem*]. Concretely, for closure operators `f, g` corresponding to fixpoint-sets `Fix(f), Fix(g)`, the closure operator `f ⊓ g` is the one whose fixpoint set is `Fix(f) ∩ Fix(g)`.

This *is* the cc semantics of parallel composition. The denotational equation:

```
[[A || B]] = [[A]] ⊓ [[B]]   (meet in the operator lattice)
```

is realised by intersecting fixpoint sets [Truly concurrent CCP, ScienceDirect; Saraswat, Jagadeesan & Gupta]. Operationally, this means the parallel composition `A || B` reaches stores that *both* `A` and `B` would reach independently — those are exactly the constraint stores satisfying both agents' requirements. In other words, **parallel composition in cc is conjunctive refinement formalised**: composing two cc agents is "the agent whose store is the intersection of the two component agents' stores at fixpoint."

Three structural properties of this composition deserve emphasis:

- **Associative**: `(A || B) || C ≡ A || (B || C)`. Intersection of fixpoint-sets is associative because set intersection is.
- **Commutative**: `A || B ≡ B || A`. Set intersection is commutative.
- **Idempotent**: `A || A ≡ A`. `Fix(f) ∩ Fix(f) = Fix(f)`.

These laws transfer the meet-semilattice algebra of Prolog clause bodies (§IV.7.1) into a *concurrent* setting, with no loss. The operational distinction (Prolog is sequential, cc is concurrent) is invisible at the algebraic level because the underlying composition operation has the same laws.

The categorical formulation is even sharper. The denotation of a determinate cc program forms a *hyperdoctrine*, the categorical formulation of first-order logic [A Logical View of Concurrent Constraint Programming, Saraswat-Jagadeesan]. The fibres are the constraint systems indexed by parameter contexts; fibre-wise, the meet operation is the categorical product (cartesian conjunction). The substitution functors are right-adjoint to existential projection, encoding hiding and locality. The hyperdoctrinal view makes precise the slogan: **cc programs are propositions in a doctrine, parallel composition is the doctrine's logical conjunction**. This is what the Prologos design intuition was reaching for when it said "you can use one sequent as a rule in another's body" — the formal name for that algebra is *cc(D) on a hyperdoctrine, with parallel composition realised as fibre-wise meet*.

The soft-CCP extension of Bistarelli, Montanari, and Rossi [Bistarelli, Montanari & Rossi 1997 J. ACM; Bistarelli, Montanari & Rossi 2006] generalises this from a constraint lattice to a **c-semiring** — a semiring `(A, +, ×, 0, 1)` whose `+` is idempotent (giving an order via `a ≤ b ⇔ a+b = b`) and has `0` as bottom and `1` as top, with `×` distributing over `+`. Constraint stores carry semiring values rather than Boolean truth, and composition is `×`. When `×` is also idempotent and commutes with arbitrary `+`, the structure is a (commutative integral) **quantale** — a complete lattice with a monoid structure that distributes over arbitrary joins [Mulvey; Vickers, *Quantales, observational logic, and process semantics*; Yetter; Rosenthal]. **Soft-CCP is therefore quantale-graded conjunctive composition**: composition is still `×` (associative, commutative when the underlying semiring is, often idempotent), but now produces semiring-valued degrees rather than mere truth. The async-research §7 cross-cutting quantale story plugs into this slice automatically, because soft-CCP's `×` in a quantale is exactly the meet-as-monoidal-product of a residuated complete lattice (see §IV.7.3).

### §IV.7.3 The categorical theory of conjunction-as-meet

The reason conjunctive composition is structurally well-behaved while disjunctive merge is not is finally a fact about adjunctions. Conjunction has a right adjoint (implication); disjunction does not, *unless* the lattice is also Boolean. This asymmetry is the algebraic backbone of every section in this artifact.

#### IV.7.3.1 Meet-semilattices as the minimal algebra

The minimal algebraic structure for conjunctive composition is the meet-semilattice: a partially ordered set in which every pair of elements has a greatest lower bound. The defining laws are exactly four [Wikipedia, *Semilattice*; *Lattice (order)*]:

```
Associativity:   (a ⊓ b) ⊓ c   = a ⊓ (b ⊓ c)
Commutativity:    a ⊓ b         = b ⊓ a
Idempotence:      a ⊓ a         = a
Absorption:       a ⊓ (a ⊔ b)   = a       (when a join also exists)
```

Any algebraic structure with associative-commutative-idempotent binary `⊓` induces a partial order via `a ≤ b ⇔ a ⊓ b = a`, under which `⊓` is the meet. In a *lattice* with both meet and join, the absorption laws make `⊓` and `⊔` define the same partial order — this is what binds them into a unified algebra rather than two independent operations [Wikipedia, *Join and meet*]. Because the laws are equational and finitary, the variety of lattices is well-behaved: free lattices on generators, lattice homomorphisms, congruence quotients all exist and compose. **The composition product on lattice elements is *just* the meet, and the lattice laws *are* the composition laws.**

This algebra is the source of the regularity Prolog clause-bodies and cc closure-operators inherit. Adding goals to a body is a meet operation in the lattice of bodies-ordered-by-strength; intersecting fixpoint-sets is a meet operation in the lattice of closure-operators. Both are instances of "the same algebraic structure" because both factor through the abstract lattice axioms.

#### IV.7.3.2 Heyting algebras and the Galois connection

The next refinement adds *implication*. A Heyting algebra is a bounded distributive lattice equipped with a binary operation `⇒` such that `(c ⊓ a) ≤ b ⇔ c ≤ (a ⇒ b)` [Wikipedia, *Heyting algebra*; nLab, *Heyting algebra*]. The equivalence is a **Galois adjunction** — the meet-with-`a` functor `(− ⊓ a)` is *left adjoint* to the implication-from-`a` functor `(a ⇒ −)`. Two structural consequences immediately follow:

1. **Distributivity is automatic**: `a ⊓ (b ⊔ c) = (a ⊓ b) ⊔ (a ⊓ c)`, because left adjoints preserve colimits (joins, in poset terms) [nLab, *Heyting algebra*].
2. **Conjunctive composition is *internal*** to the lattice: `a ⇒ b` is the *largest* element `x` such that `a ⊓ x ≤ b`. The implication is the residual of meet — it is the inverse operation that exists by virtue of the Galois adjunction.

In the topological reading, a Heyting algebra is the algebra of opens of a sober space (or a generalised "space without points" — a *locale*); a complete Heyting algebra is a **frame**, equivalently the opposite of a *locale* in the sense of Johnstone's pointless topology [Johnstone 1982, *Stone Spaces*; Picado-Pultr 2012, *Frames and Locales*; Wikipedia, *Pointless topology*]. The defining frame law — finite meets distribute over arbitrary joins — *is* the law that makes finite intersection of opens commute with arbitrary union; this distributivity is exactly the Galois adjunction at scale.

The architectural payoff: **in any Heyting algebra (and a fortiori any frame/locale), conjunctive composition is closed under refinement**. If `a ≤ a'` and `b ≤ b'`, then `a ⊓ b ≤ a' ⊓ b'`, and the residuals compose: `(a ⊓ b) ⇒ c = a ⇒ (b ⇒ c)` (curry-uncurry). Composition is monotone in each argument, residuated, and distributes over choice. There is no partial-operator failure mode, no need for a reconciliation step, and no order dependence.

#### IV.7.3.3 Residuated lattices: the substructural setting

In the most general substructural setting, the monoidal product `•` need not coincide with the lattice meet. A **residuated lattice** is a structure `(L, ∧, ∨, •, I, /, \)` where `(L, •, I)` is a monoid and `•` has both left and right residuals: `x • y ≤ z ⇔ x ≤ z/y ⇔ y ≤ x\z` [Galatos-Jipsen-Kowalski-Ono 2007; Wikipedia, *Residuated lattice*]. Boolean and Heyting algebras are special cases where `• = ∧` and the residuals coincide as implication. The general form admits non-commutative `•` and a separation of "linear" and "additive" conjunctions.

The relevance to multi-party protocol composition: when composition has a **resource-sensitive** or **temporal** flavour (as in linear concurrent constraint programming and quantale-graded soft-CCP), the appropriate algebra is a residuated lattice rather than a Heyting algebra. Linear concurrent constraint programming `lcc` uses an intuitionistic linear logic constraint system [Saraswat & Lincoln; Fages et al.], in which `tell` may consume rather than merely deposit — the underlying residuated structure is the constraint-system version of intuitionistic linear logic. Soft-CCP's c-semiring is, in its complete form, a **commutative integral quantale**, which is a complete commutative residuated lattice with `I = ⊤`. **Quantales are residuated complete lattices**, and they are exactly the algebraic setting where conjunctive composition is *graded* (by the quantale value), *associative-commutative-monoidal*, and *residuated* (the implication encodes "given the cost so far, what residual cost remains") [Mulvey; Vickers; Yetter].

The architectural lesson for protocol composition: **in any residuated-lattice/quantale setting, conjunctive composition has the same compositional regularity as in the Boolean/Heyting case, lifted to graded values**. The grading does not break the structure. This is exactly what the Prologos design needs for the cross-cutting quantale story (§IV.7.6, §IV.7.9 below).

#### IV.7.3.4 Why disjunction-as-merge is not symmetric

The asymmetry that sinks the projection-with-merge tradition in MPST is that **join does *not* automatically have a residual on the side of refinement**. In a *frame* (complete Heyting algebra), finite meets distribute over arbitrary joins — but joins do *not* in general distribute over arbitrary meets (this would require a *co-frame* / Boolean algebra, which most "spaces of behaviours" are not). The implication operator `⇒` is the residual of `⊓`, not of `⊔`; there is no "co-implication" ⇐ in a Heyting algebra in general (its existence characterises Boolean algebras among Heyting algebras, via `¬¬x = x`) [nLab, *Heyting algebra*; Wikipedia, *Complete Heyting algebra*].

Consequently, *merge* — the partial operation in MPST projection that tries to compute "the local type that subsumes both branches at this role" — is attempting to compute a join in a lattice that does not have the algebraic structure to support compositional joins. The merge operator is **partial** because the join it tries to compute does not always exist (i.e., the upper bound isn't a *least* upper bound, or doesn't exist at all in the relevant fragment), and it is **sensitive to syntactic accidents** because the partial operator's failure cases are decided by case-analysis on the local-type syntax rather than by an algebraic property of the lattice. A residuated structure would force the operation to be coherent by construction, but residuation requires either a meet-as-monoidal-product (Heyting/Boolean) or an explicit semiring/quantale structure on the local-type space — neither is what projection-with-merge supplies.

Scalas and Yoshida's "Less is More" critique [Scalas & Yoshida; *Less is More Revisited* arXiv 2402.16741] uncovered that the standard mergeability-based proof of MPST type safety was flawed, precisely because the merge operation's partial-and-syntactic character invalidated invariants that the proof had implicitly assumed [*Multiparty Session Types Meet Communicating Automata*]. The corrected proofs use *association* — a relaxation that allows local types to "safely conform to the global protocol" rather than being exact projections. But the deeper structural lesson (which the constraint-based / conjunctive-composition lineage of §IV.7.1–§IV.7.2 makes inevitable) is that **MPST set up the wrong composition operation in the first place**: it asked "given the global, compute the local for each role" (a join-side question), when the conjunctive-refinement lineage would have asked "given the role-local constraints, compute the global as their meet" (a structurally-determined meet operation in a lattice that has the right algebra).

### §IV.7.4 The asymmetry between meet and join in protocol composition

The previous section's algebraic asymmetry has a direct architectural projection onto multi-party protocol design. **Meet-side composition** (adding constraints, conjoining behaviours) is structure-preserving in any of the algebraic settings we have surveyed (semilattice, Heyting algebra, frame, residuated lattice, quantale). **Join-side composition** (combining views, merging projections) requires the lattice to be *Boolean* or otherwise to admit residuation on the join side, which is a strictly stronger property and is not enjoyed by typical spaces-of-behaviours.

Concretely:

- *Meet-side*: composing protocol `P` with a refinement `R` to obtain `P ⊓ R` produces a protocol whose admissible runs are *those of `P` that also satisfy `R`*. This is what conjunctive composition naturally does. It is associative, commutative, idempotent, monotone, residuated. There is no failure mode at the algebra level — `P ⊓ R = ⊥` when the constraints are jointly inconsistent, but `⊥` is a *value* in the lattice (the least element), not an undefined-operation. Inconsistency is detectable as a lattice value; the operation itself is total.

- *Join-side*: combining projections of `P` from roles `r1, r2` to recover behaviour at a unified-role-set requires computing `proj_r1(P) ⊔ proj_r2(P)` — but this join is a partial operation that *succeeds only when* the two projections are jointly inhabitable at the same role-set. The reason MPST's merge is partial is that *the projections have lost the information that the global type carried, and the merge tries to recover that information from the local-type syntax alone*. Because the local-types do not form a Boolean lattice (no complementation, no co-implication), the join is not computable from the local data — it requires the global type itself, which projection has discarded.

This is the architectural lesson that the lineage of §IV.7.1–§IV.7.2 makes unavoidable: **multi-party session types tried to recover the global type from the local types via merge, but the local types lost the information that conjunction would preserve**. The conjunctive-refinement architecture inverts the direction: instead of starting from a global and projecting (with merge as the failed inverse), start from per-role constraints and *meet them* to obtain the global. The meet is total, structure-preserving, and computable from the per-role data alone, because the lattice has the algebraic structure to support it.

### §IV.7.5 Trait bundles as the Prologos realisation

The Prologos trait system is the operational embodiment of the meet-side composition algebra. A trait, in the formal model of Schärli, Ducasse, Nierstrasz, and Black [Schärli et al. 2003, *Traits: Composable Units of Behaviour*; Ducasse et al. 2006, *Traits: A mechanism for fine-grained reuse*], is a **set of method-requirements + provided method-implementations**. The composition operator is a *symmetric sum*: `T1 ⊕ T2` is a trait whose method set is the union of the method sets of `T1` and `T2`, with an explicit conflict-resolution discipline (alias / exclude) for any methods defined in both [Schärli, *Traits: The Formal Model* 2002]. The flattening property — "the semantics of a class that uses traits is equivalent to the semantics of the class obtained by inlining the methods provided by the traits that it uses" [Schärli et al.; Ducasse et al.] — is the trait-system equivalent of the conjunction-substitution property in Prolog: composing traits adds method requirements/provisions to the composing context, with no hidden interleaving.

Prologos's *bundle* is a user-definable alias for a set of conjunctive trait-refinements [Prologos design intuition, project documentation]. A bundle `B` is an alias `B := T1 ⊓ T2 ⊓ ... ⊓ Tn` where the `Ti` are trait predicates. The trait resolver, on encountering `[bundle B] x : T`, expands `B` to the conjunction and discharges each conjunct via sound type-checking. The resolver does not need to compute a "join" or "merge" of the traits; the conjunction is the operation, and the lattice of trait-predicates supports it directly.

Why does this scale without OO multiple-inheritance pathologies? The conjunction is over **constraint-lattice elements** (trait properties: presence of methods, satisfaction of laws, refinement of types), not over inheritance-tree paths. There is no method-resolution-order to compute because there is no notion of "which path through the tree wins" — the conjunction is symmetric. The diamond problem evaporates because the diamond-shape inheritance graph corresponds to *the same trait being conjoined twice* in a meet-semilattice, which is idempotent: `T ⊓ T = T`. Idempotence does the work that C3 linearisation [GeeksforGeeks, *Diamond Problem*; *MRO in Python*] does in OO multiple inheritance, but for free, by virtue of the algebra.

The Prologos `bundle Num := (Add Sub Mul)` declares a bundle alias for the conjunction of three trait refinements; a value `x : Num` is required to satisfy all three. Adding a trait to the bundle (`bundle Num := (Add Sub Mul Div)`) is a meet-side refinement — it strengthens the bundle, and existing uses remain sound (they already required at least the old conjunction, and now require slightly more, which is monotone). Removing a trait is a non-monotone change that the lattice flags as a refinement-violation — the type system can detect it because it's a meet-side weakening.

This aligns precisely with the project's decomplection principle [Hickey 2011, *Simple Made Easy*]: traits are independent units; bundles are conjunctions of independent units; the only operation is meet, and the only failure mode is "the conjunction is jointly inconsistent" (which is a *lattice value*, not an undefined operation). There is no interleaving — the things composed are not "complected" — because conjunction is associative-commutative-idempotent and the lattice carries no order dependencies.

### §IV.7.6 The polynomial-functor composition product as the categorical formalisation

The categorical-theoretic formalisation of conjunctive composition for protocol design is the **composition product on polynomial functors** [Spivak & Niu 2024, *Polynomial Functors: A Mathematical Theory of Interaction*, Chapter 5; Gambino & Kock; Niu & Spivak]. Companion artifact §IV.5 (Agent 5) covers the categorical machinery in depth; this section grounds why the composition product is the *correct* composition for conjunctive-refinement protocol design.

A polynomial functor `P` over Set is a coproduct `P(X) = Σ_{i ∈ P(1)} X^{P[i]}`, equivalently a presentation by *positions* (elements of `P(1)`) and, for each position `i`, a set of *directions* `P[i]` [Spivak-Niu Ch.2; Niu monograph; nLab, *polynomial functor*]. A position `i ∈ P(1)` is "what the system is currently outputting / offering"; a direction `d ∈ P[i]` is "what input/response the system can accept, given that it is at position `i`". This pairing is the syntactic ground for an *interaction protocol*: what the system sends, what responses it admits, parametrised by the system's current state.

The **composition product** `P ◁ Q` of two polynomials is the polynomial whose positions are pairs `(i, j(−))` where `i ∈ P(1)` is a P-position and `j(−) : P[i] → Q(1)` is a Q-position assigned to each direction of `i`; the directions of `(i, j)` in `P ◁ Q` are pairs `(d, e)` with `d ∈ P[i]` and `e ∈ Q[j(d)]` [Spivak & Niu Chapter 5; *Polynomial Functors*, nLab]. The polynomial `P ◁ Q` represents "*do P, then conditionally do Q based on what P branched into*" — the temporal/sequential composition appropriate to dynamical systems and interaction protocols [Niu & Spivak 2024, *Polynomial Functors*; *Polynomial Functors: A Mathematical Theory of Interaction*]. The composition product is **non-symmetric**, **monoidal** (with unit the identity polynomial `y`), and **associative**; it makes Poly into a (non-symmetric) monoidal category, in fact a *bicategory* via the composition-product-as-composition structure [Gambino & Kock; Spivak; *summary of categorical structures in Poly* arXiv 2202.00534].

The crucial architectural fact for our purposes: **the composition product on polynomial functors at the protocol level *is* conjunctive refinement at the categorical level**. The reason is not metaphor — it is structural. A polynomial `P` interpreted as a protocol is a *constraint specification*: positions are "what behaviour is asserted/offered at the current state", directions are "what completions/responses are admitted". Composing two such protocols by `P ◁ Q` builds a protocol whose runs are those of `P` *followed by* a context-dependent run of `Q` — equivalently, the runs that satisfy both `P`'s constraints (at the outer layer) and `Q`'s constraints (at the inner layer, parameterised by `P`'s direction). This is the temporal/sequential conjunction, and it has the right algebraic shape for protocol design:

- **Associative**: `(P ◁ Q) ◁ R ≃ P ◁ (Q ◁ R)`, by the bicategorical axioms.
- **Unital**: `y ◁ P ≃ P ≃ P ◁ y`.
- **Cartesian-coherent**: composition product distributes over the cartesian product `×` on Poly in the appropriate sense, making the conjunctive composition compatible with parallel composition.

This is the formal theory that the user's design intuition was reaching for. The Prologos architectural target — **multi-party protocols as polynomial functors with conjunctive composition** — is the natural realisation of polynomial-functor composition product on a constraint-graded space. When the constraint grading carries quantale values (as in soft-CCP / async-research §7), the composition product becomes a quantale-graded composition, but the bicategorical structure persists [Vickers, *Quantales, observational logic, and process semantics*; companion async-research artifact §3.3, §7].

### §IV.7.7 "Global types as constraints" — does this exist in the session-type literature?

A natural search target is whether prior MPST work treated global types as *constraints* rather than *projections*. The honest answer, from this slice's literature search, is that **the field went projection-first, not constraint-first, and the constraint-based reading is essentially absent from the MPST canon**.

The seminal binary session-type work [Honda, Vasconcelos & Kubo 1998] and the multi-party generalisation [Honda, Yoshida & Carbone 2008 POPL; *Multiparty Asynchronous Session Types* 2016 J. ACM] both ground their semantics in operational projection: a global type `G` is the protocol specification, and `proj_r(G)` is the local type at role `r`, defined by structural recursion on `G`. Composition of protocols is studied through *multicompatibility* [*Multicompatibility for Multiparty-Session Composition*, PPDP 2023] — checking whether two systems' interfaces are compatible — but this is a check on already-projected local types, not a constraint-style declarative composition of global specs.

There are partial precedents in adjacent literatures:

1. **Datalog-with-constraints** [Madduri, Marquet & Tyszberowicz; Hawkins et al., *Programming with First-Class Datalog Constraints* 2020 OOPSLA]: trust-management and access-control languages have used Datalog clause bodies (conjunctive) as the underlying composition mechanism for protocol specification. This is closely allied with the conjunctive-refinement view, but framed as logic-programming-with-constraints rather than session-type theory.

2. **Declarative process specification** [DecSerFlow, *Declarative Specification and Verification of Service Choreographies*]: choreographies specified by constraint-relationships between activities, evaluated in linear-temporal-logic. The composition is conjunctive at the constraint level, but the enforcement is dynamic-monitoring rather than static type-checking.

3. **Design-by-contract for multi-party sessions** [Bocchi, Honda, Tuosto, Yoshida; *Design-by-Contract for Flexible Multiparty Session Protocols*]: rely-guarantee assertions on payloads, where assertions are conjoined at composition. This is the closest the MPST literature gets to a constraint-based / declarative-spec view.

4. **Concurrent constraint programming** [Saraswat 1993, *Concurrent Constraint Programming* MIT Press]: directly conjunctive, by construction. But this is a different community; cross-citations to/from MPST are rare.

The structural finding is therefore: **a constraint-based / conjunctive-refinement multi-party protocol theory is largely undeveloped in the MPST canon**, and the projection-with-merge tradition (with its accompanying soundness-and-completeness difficulties [Scalas & Yoshida; *Less is More Revisited* 2402.16741]) is the dominant approach. The Prologos architectural target therefore stakes out unclaimed territory: a session-type-like discipline grounded in cc(D)-style conjunctive composition rather than projection-with-merge. The async-research §3.3 and this slice together provide the formal foundation that the MPST projection-merge tradition lacks.

### §IV.7.8 The fibrational structure of conjunctive role projection

The categorical machinery that ties all of the above together is the *fibration* — a functor `p : E → B` with cartesian (or opcartesian) lifts of base morphisms [Wikipedia, *Fibred category*; Jacobs, *Categorical Logic and Type Theory*; nLab, *Cartesian morphism*]. For protocol design, the relevant fibration has:

- **Base `B`**: the lattice of role-sets (subsets of the participating-roles set) ordered by inclusion or refinement.
- **Fibre over a role-set `R ⊆ Roles`**: the category of behavioural specifications visible-to-`R`.
- **Cartesian (resp. opcartesian) lifts** of an inclusion `R ⊆ R'`: project the `R'`-spec down to an `R`-spec (cartesian) or universally extend an `R`-spec up to an `R'`-spec (opcartesian).

In this setup, **conjunctive composition lifts to the fibration coherently**. If `P` and `Q` each have role-set lifts (i.e., their specifications are visible at the fibre over their respective role-sets), then `P ⊓ Q` has a role-set lift over the *meet* of the role-sets — the structure-preserving lift of conjunction at the base level via the cartesian lift property [nLab, *Cartesian morphism*; *(Co)Cartesian fibrations*, Harpaz; arXiv 1806.06129, *Categorical notions of fibration*]. Concretely, the universal property of cartesian morphisms guarantees that conjunctive composition at the base of role-sets uniquely determines a coherent conjunctive composition at the fibre of behaviours.

This is structurally identical to **traits-as-fibres-over-method-set-lattice**. In the trait-system fibration, the base is the lattice of method-sets, the fibre over a method-set `M` is the category of trait-implementations supplying exactly methods `M` with their requirements; the cartesian lift of a method-set inclusion `M ⊆ M'` projects an `M'`-implementation down to its `M`-restriction. Bundle composition is meet-of-method-sets at the base, with the corresponding conjunctive-composition at the fibre level lifting universally. **The trait fibration and the role-projection fibration are structurally the same construction**, indexed differently. The Prologos trait/bundle system is therefore a low-dimensional realisation of the conjunctive-role-projection fibration that a constraint-based MPST would inhabit.

The fibrational picture also explains why merge-as-join is structurally wrong: opcartesian lifts (the universal "extend an `R`-spec up to an `R'`-spec") are *colimit-side* operations and do not, in general, exist universally for behavioural specifications without further structure. The cartesian-lift side (conjunction-as-meet) is far better behaved, because the residuation / Galois-adjunction structure of meet (§IV.7.3) gives universal existence of the lifts.

### §IV.7.9 The unifying claim

This slice's load-bearing finding can now be stated precisely:

> **Trait bundles, Prolog conjunctive composition, CCP closure-operator parallel composition, polynomial-functor composition product, and conjunctive role projection in a fibration are all instances of the same categorical structure: conjunction-as-meet in a structure-preserving algebraic setting — equivalently, a residuated lattice (or quantale, when graded), a Heyting algebra (or frame, when complete), a meet-semilattice (when the residuation is implicit), and a fibration of behaviour-specifications over a role-set / method-set / fixpoint-set / position lattice.**

Each line of evidence supports a separate facet of this single algebraic structure:

| Site | Lattice | Composition op | Algebraic structure |
|------|---------|----------------|---------------------|
| Prolog clause body | bodies-as-multisets-of-atoms | substitute body into another | meet-semilattice (associative-commutative-idempotent conjunction) |
| cc(D) [Saraswat et al. 1991] | closure operators on constraint lattice D | intersection of fixpoint sets | complete lattice of closure operators; meet = ∩ Fix |
| Soft-CCP [Bistarelli et al. 1997] | c-semiring values | × in a semiring | quantale (residuated complete lattice) |
| lcc [Saraswat & Lincoln; Fages et al.] | linear-logic constraint system | parallel composition | residuated lattice with linear `⊗` |
| Trait composition [Schärli et al. 2003] | trait predicates | symmetric sum + flatten | meet-semilattice with disjointness check |
| Prologos bundles | trait conjunctions | bundle-alias-meet | meet-semilattice; user-definable aliases |
| Polynomial composition product [Spivak & Niu 2024] | Poly | `P ◁ Q` | non-symmetric monoidal bicategory |
| Conjunctive role-projection fibration | role-sets in a lattice | meet at base + cartesian lift | fibration with meet-of-bases lifting universally |
| Linear-logic `&` (additive conjunction) | propositions | `&` (with) | additive lattice operation; cartesian product |

In each row, the composition operation is *meet-side* (conjunction), associative-commutative (or, in the polynomial case, associative-non-commutative-but-coherent), idempotent or monoidal-with-unit, and **structurally determined** — there is no reconciliation operator, no order-dependent choice, no partial-operator failure mode at the algebraic level. In each row, the operation has the *right* universal property (meet, monoidal product, residuation) by virtue of the underlying lattice/algebraic structure.

The Prologos architectural target — multi-party protocols as polynomial functors with conjunctive composition, realised as a residuated-lattice (or quantale-graded) meet operation in a fibration of behaviour-specifications over a role-set lattice — is therefore the natural realisation of this categorical structure. It is not a novel invention; it is the inevitable consequence of the algebraic facts surveyed above, applied to multi-party protocol design.

The OO-inheritance / projection-with-merge alternative fails because **it tries to recover information from a join that doesn't have the proper algebraic structure**:
- *OO multiple inheritance* fails because the inheritance lattice is not a meet-semilattice (its laws don't hold without an order-dependent reconciliation operator like C3, which is a *partial* and *order-sensitive* substitute for meet).
- *MPST projection-with-merge* fails because the merge operation tries to compute a join in a lattice (local types) that does not admit residuation on the join side, making the operation partial and syntactic-accident-sensitive [Scalas & Yoshida; *Less is More Revisited*].

The Prologos design intuition cuts directly to the algebraic ground: composition is conjunction, conjunction is meet, meet has the right universal property, and the only remaining design work is choosing which lattice / quantale / residuated structure to instantiate — a decision that is settled by the application domain, not by the composition operation's algebra. **Once the lattice is chosen, the composition operation is fixed by the algebra**; there is nothing to reconcile, nothing to merge, no projection to invert. This is the structural sense in which conjunctive-refinement composition is "trivial" — not because it is unimportant, but because the algebra does the work for free, and the architect's job is reduced to choosing the right lattice.

---

## References

- **Bistarelli, S., Montanari, U., & Rossi, F.** (1997). *Semiring-based constraint satisfaction and optimization*. Journal of the ACM, 44(2), 201-236. DOI: 10.1145/256303.256306. The foundational c-semiring framework: constraint stores carry semiring-valued tuples; classical, fuzzy, weighted, and over-constrained CSPs all instantiate the framework; soft constraints are graded by the semiring. Proves local consistency techniques transport across the framework.

- **Bistarelli, S., Montanari, U., & Rossi, F.** (2006). *Soft concurrent constraint programming*. ACM Transactions on Computational Logic, 7(3), 563-589. The CCP extension of the 1997 framework: tell deposits semiring values; ask blocks until the store entails a soft constraint at a sufficient threshold; parallel composition is the meet/× in the c-semiring. The architecturally relevant fact: when × is idempotent and distributes over arbitrary +, the c-semiring is a (commutative integral) quantale — quantale-graded conjunctive composition.

- **Bono, V., Damiani, F., & Giachino, E.** (2008). *On Traits and Types in a Java-like Setting*. In Fifth IFIP International Conference on Theoretical Computer Science (TCS 2008). LNCS 273, 367-382. Formal type-system treatment of traits in a Java-like setting, separating type/behaviour/state for fine-grained reuse. Cited as the formal-semantics ground for trait conjunction; relates traits to intersection types as a natural type-theoretic analog of multiple inheritance.

- **Carbone, M., Honda, K., & Yoshida, N.** (2007). *Structured Communication-Centred Programming for Web Services*. ESOP 2007, LNCS 4421. Pre-cursor to the multi-party session-types paper; introduces the choreography-and-projection style at the level of web services.

- **Ducasse, S., Nierstrasz, O., Schärli, N., Wuyts, R., & Black, A. P.** (2006). *Traits: A mechanism for fine-grained reuse*. ACM TOPLAS 28(2), 331-388. The journal version of the trait formal model; defines symmetric sum, alias/exclude conflict resolution, and the flattening property — "the semantics of a class that uses traits is equivalent to the semantics of the class obtained by inlining the methods provided by the traits."

- **Galatos, N., Jipsen, P., Kowalski, T., & Ono, H.** (2007). *Residuated Lattices: An Algebraic Glimpse at Substructural Logics* (Studies in Logic and the Foundations of Mathematics, Volume 151). Elsevier. The foundational reference on residuated lattices as the algebra of substructural logics; signature `(L, ∧, ∨, •, I, /, \)`; Galois adjunctions of monoidal product with residuals; Boolean and Heyting algebras as the special case `• = ∧`. Covers Dedekind-MacNeille completions, finite model property, decidability.

- **Gambino, N., & Kock, J.** (2013). *Polynomial functors and polynomial monads*. Mathematical Proceedings of the Cambridge Philosophical Society 154(1), 153-192. The bicategorical structure of polynomial functors; foundation for Spivak-Niu's monograph; foundational result that polynomials form a bicategory whose composition is the composition product.

- **Hawkins, P., Bonchi, F., Sangiorgi, D., & others.** (2020). *Fixpoints for the Masses: Programming with First-Class Datalog Constraints*. OOPSLA 2020. Datalog constraint programs as first-class values; runtime composition of Datalog clause-bodies; an example of conjunctive-composition lifted to runtime.

- **Hickey, R.** (2011). *Simple Made Easy*. Strange Loop keynote. Articulates the "decomplection" principle — composing simple (i.e., un-interleaved) components produces robust software, while easy-but-complex components compound technical debt. The conceptual basis for Prologos's preference for conjunctive composition over OO inheritance.

- **Honda, K., Vasconcelos, V. T., & Kubo, M.** (1998). *Language primitives and type discipline for structured communication-based programming*. ESOP 1998, LNCS 1381. The seminal binary-session-types paper; introduces session types as a discipline over π-calculus interactions.

- **Honda, K., Yoshida, N., & Carbone, M.** (2008/2016). *Multiparty Asynchronous Session Types*. POPL 2008 / Journal of the ACM 63(1), Article 9 (2016). The seminal MPST paper; introduces global types, local types, and projection. The merge operation appears in the projection definition; subsequent work [Scalas & Yoshida] discovered that the standard mergeability-based proofs of type safety were flawed.

- **Jacobs, B.** (1999). *Categorical Logic and Type Theory*. Studies in Logic and the Foundations of Mathematics 141, Elsevier. The standard reference on fibrations as the categorical foundation of dependent type theory; provides the technical machinery for the conjunctive-role-projection fibration of §IV.7.8.

- **Johnstone, P. T.** (1982). *Stone Spaces*. Cambridge Studies in Advanced Mathematics 3. The standard reference for frames, locales, and pointless topology; "still, after a quarter of a century, the standard reference book" — Mathematical Association of America. Develops Stone duality, locales as opposite of frames, and the Heyting algebra structure of frames.

- **Niu, N., & Spivak, D. I.** (2024). *Polynomial Functors: A Mathematical Theory of Interaction*. Cambridge University Press / arXiv 2312.00990 / Topos Institute manuscript. Comprehensive treatment of Poly; Chapter 5 covers the composition product in detail; positions and directions; bicategorical structure; applications to dynamical systems, decision processes, data migration. The categorical machinery of polynomial-functor composition product is the formal target of the Prologos protocol-composition architecture.

- **Picado, J., & Pultr, A.** (2012). *Frames and Locales: Topology Without Points*. Springer, Frontiers in Mathematics. Comprehensive contemporary treatment of frame and locale theory; algebraic structure; relationship to topology. Complementary to Johnstone for the algebraic-topological side.

- **Pierce, B. C.** (1991). *Programming with Intersection Types and Bounded Polymorphism*. PhD thesis, CMU CMU-CS-91-205. Establishes intersection types as a natural type-theoretic analog of multiple inheritance; foundational for the "trait composition is intersection" framing.

- **Saraswat, V. A.** (1993). *Concurrent Constraint Programming* (Logic Programming Series). MIT Press. ACM Doctoral Dissertation Award. The standard reference on cc and the closure-operator semantics; book-length development of the framework that underlies §IV.7.2.

- **Saraswat, V. A., Rinard, M., & Panangaden, P.** (1991). *The semantic foundations of concurrent constraint programming*. POPL 1991, 333-352. The foundational closure-operator semantics for cc(D); ACM Most Influential Paper in 20 Years Award (2004). Establishes parallel composition as intersection of fixpoint sets; full abstraction for quiescent stores. The formal home of conjunctive composition for concurrent agents.

- **Saraswat, V. A., & Jagadeesan, R.** *A Logical View of Concurrent Constraint Programming*. McGill, available at https://www.math.mcgill.ca/rags/ccp/mpss.abstract.html. Hyperdoctrinal interpretation of cc; the categorical formulation of conjunctive composition as fibre-wise meet in a doctrine.

- **Saraswat, V. A., Jagadeesan, R., & Gupta, V.** (2002). *Truly Concurrent Constraint Programming*. Theoretical Computer Science. Bounded closure operators as denotations; true-concurrency semantics distinguishing causal dependencies between constraints; the algebra of the operator lattice.

- **Saraswat, V. A., Lincoln, P.** *Higher-Order Linear Concurrent Constraint Programming*. SRI International. The lcc extension to higher-order; constraint systems built from intuitionistic linear logic; the residuated-lattice-graded version of cc.

- **Scalas, A., & Yoshida, N.** (2019). *Less is More: Multiparty Session Types Revisited*. POPL 2019. Discovered that the standard mergeability-based proofs of MPST type safety were flawed; introduces an alternative foundation that does not rely on mergeability. The technical evidence for the structural fragility of projection-with-merge.

- **Schärli, N.** (2002). *Traits: The Formal Model*. Technical Report IAM-02-006, Institut für Informatik, Universität Bern. The foundational formal model of traits as composable units of behaviour; symmetric-sum operator; alias/exclude conflict resolution; flattening property.

- **Schärli, N., Ducasse, S., Nierstrasz, O., & Black, A. P.** (2003). *Traits: Composable Units of Behaviour*. ECOOP 2003, LNCS 2743, 248-274. The conference-paper introduction of traits; companion to the Schärli 2002 technical report.

- **Spivak, D. I.** (2022/2025, latest revision). *A Summary of Categorical Structures in Poly*. arXiv 2202.00534. Compendium of the four interacting monoidal structures on Poly: cartesian product, parallel product, composition product, Dirichlet product. The composition product is the focus for protocol composition.

- **Tarski, A.** (1955). *A lattice-theoretical fixpoint theorem and its applications*. Pacific Journal of Mathematics 5(2), 285-309. The Knaster–Tarski theorem: the set of fixpoints of an order-preserving function on a complete lattice forms a complete lattice. The mathematical basis for cc(D)'s parallel composition as intersection of fixpoint sets.

- **Vickers, S.** *Quantales, Observational Logic and Process Semantics*. Manuscript at https://sjvickers.github.io/QuProc.pdf. Quantales as the algebraic ground of observational logic for processes; modules over quantales unifying topology and labelled-transition systems. The categorical-algebraic foundation for quantale-graded conjunctive composition.

- **Yetter, D. N.** (1990). *Quantales and (noncommutative) linear logic*. Journal of Symbolic Logic 55(1), 41-64. Quantales as models of (noncommutative) linear logic; the residuated-monoidal structure that supports both meet-side and tensor-side conjunctive composition; the formal home of "conjunction in a noncommutative setting."

- **Wikipedia contributors.** *Heyting algebra*, *Closure operator*, *Knaster–Tarski theorem*, *Lattice (order)*, *Linear logic*, *Pointless topology*, *Residuated lattice*, *Semilattice*, *Multiparty session types*. Standard online references; consulted for definitional clarity throughout.

- **nLab contributors.** *Heyting algebra*, *Polynomial functor*, *Cartesian morphism*, *Frame*, *Locale*. Useful for the categorical-theoretic reading of meet-as-left-adjoint, polynomial functors as positions-and-directions, and cartesian/opcartesian lifts in fibrations.

- **Companion async-research artifact** (2026-05-05): *Asynchronous Programming Quantale Research Program*. §3.3 covers cc(D) closure-operator semantics in operational depth; §7 covers cross-cutting quantale structure. This slice cross-references both sections and treats them as load-bearing context.

---

## §VI Frontier Scan: 2024–2026 Multi-Party Computation Research and the Architectural Target

### §VI.0 Scope and method

This slice surveys 2024–2026 published-or-accepted work bearing on the architectural target
**multi-party protocols as polynomial functors over a quantale-valued propagator runtime, with role projection as opcartesian lifts in a fibration, behavior as coalgebras, realizability as a quantale-valued fixpoint, composition as conjunctive refinement**. Frontier here means peer-reviewed conference-and-journal proceedings (POPL, OOPSLA, ECOOP, ICFP, ESOP, CONCUR, STACS, FoSSaCS, FSCD, ITP, CSL, PLDI, LIPIcs venues) from January 2024 onward, plus credible preprints on arXiv from 2024–2026 (preprint status flagged explicitly in the bibliography). The scan deliberately covers six adjacent communities — multiparty session types proper (MPST), choreographic programming, quantale-coalgebraic concurrency semantics, polynomial-functor categorical semantics of dependent type theory, capability-async / effect-handler control, and tropical / resource-bounded type theory — because the architectural target sits at the intersection. Cross-references to the companion artifact `2026-05-05_ASYNCHRONOUS_PROGRAMMING_QUANTALE_RESEARCH_PROGRAM.md` (henceforth Async §6.X) are noted inline.

### §VI.1 Recent (2024–2026) MPST work — the live controversy

The central technical fact about the 2024–2026 MPST frontier is that the field is in active repair after the 2018–2019 disclosure (Scalas–Yoshida, [Scalas Yoshida 2019]) that classical projection-with-merge subject-reduction proofs are flawed. The frontier scan reveals not a recovery but an ongoing schism: at least four distinct repair strategies are pursued in parallel, and the 2024–2026 papers do not converge on a consensus foundation.

#### §VI.1.1 The repair-the-proof strategy (Hou–Yoshida–Kuhn 2024)

[Hou Yoshida Kuhn 2024], "Less is More Revisited: Association with Global Protocols and Multiparty Sessions," presented in the springer track and revised through 2026, accepts the projection-with-merge framework but supplies a new proof technique. The authors localise the defect: prior subject-reduction proofs invoked an invariance property that holds under *plain* merging but fails under *full* merging. Their fix introduces an **association relation** between the behavioural semantics of a global type's labelled-transition system and the parallel composition of its endpoint projections, which serves as a coinductive bisimulation up to the merge structure. With this association relation in hand, session fidelity, deadlock freedom, and liveness are recovered under full merging.

This repair preserves the projection-with-merge orthodoxy. It does not address the architectural critique that projection-with-merge is itself a kludge — that the merge operator is needed only because local types lose information about which other-role behaviours a participant ought to be sensitive to.

#### §VI.1.2 The synthetic-LTS strategy (Castro-Perez–Ferreira–Jongmans, POPL 2026)

[Castro-Perez Ferreira Jongmans 2026], "A Synthetic Reconstruction of Multiparty Session Types," published at POPL 2026 (peer-reviewed, ACM), takes the more radical position that projection-with-merge should be abandoned entirely. Their **synthetic approach** verifies each process directly against a global protocol specification represented as a labelled transition system (LTS), with global types as a special case. The key innovation is that the type system contains no projection operation at all and no notion of local type as an intermediate artifact. Compositionality is recovered because each process is checked against the *same* global LTS independently; expressiveness is recovered because the LTS-shape of specifications is far more general than projectable global types.

The synthetic approach is, in effect, an admission that the entire 2008–2019 architecture of "global type, project to local types, type each process against its local type" was an *engineering choice*, not a fundamental requirement. The categorical content of that choice — the universal property, if any, that projection-with-merge was supposed to embody — is not made explicit in [Castro-Perez Ferreira Jongmans 2026]. The paper offers an LTS-based operational adequacy argument, not a categorical one.

#### §VI.1.3 The automata-theoretic strategy (Stutz–D'Osualdo, ESOP 2025)

[Stutz D'Osualdo 2025], "An Automata-theoretic Basis for Specification and Type Checking of Multiparty Protocols," introduces the **AMP framework**: Protocol State Machines (PSMs) for global specifications, Communicating State Machines (CSMs) for local participants, and a π-calculus type system checking against CSM specifications. They identify a class of "tame" PSMs admitting sound and complete PSPACE projection. The framework is positioned as a backwards-compatible new backend for classical MPST tooling.

[Li Stutz Wies 2024], "Deciding Subtyping for Asynchronous Multiparty Sessions" (ESOP 2024), shows asynchronous multiparty subtyping with CSMs as implementation model is decidable in polynomial time — a sharp contrast to the undecidability of classical asynchronous binary session subtyping [Bravetti et al. earlier work]. The polynomial-time result is gained because CSM semantics restricts the model class: the decidability comes from the choice of operational model, not from a structural insight into the session-type lattice.

[Li Stutz Wies Zufferey 2025], "Characterizing Implementability of Global Protocols with Infinite States and Data" (PACMPL OOPSLA 2025), extends to symbolic protocols with dependent refinement predicates. The Sprout tool implements the algorithm. The infinite-state result is significant: it is the first sound and *relatively* complete algorithm for symbolic MPST implementability, and it does so by reducing implementability to (co)reachability in role-restricted projections of the global protocol.

The Stutz line is the most operationally mature of the 2024–2026 lines. Its limitation, from the architectural-target perspective, is that the categorical content of CSMs is exactly that of communicating finite-state machines — a labelled-transition-system model that does not give the polynomial-functor / fibration structure the architectural target demands.

#### §VI.1.4 The mechanisation strategy (Tirore–Bengtson–Carbone 2025; Ekici–Kamegai–Yoshida 2025)

Two ECOOP/ITP 2025 papers complete the picture. [Tirore Bengtson Carbone 2025], "Multiparty Asynchronous Session Types: A Mechanised Proof of Subject Reduction" (ECOOP 2025), presents a Coq mechanisation of MPST subject reduction and explicitly identifies further flaws in the [Honda Yoshida Carbone 2008] original formulation; the authors restrict the theory to a fragment for which subject reduction can be mechanically verified. [Ekici Kamegai Yoshida 2025], "Formalising Subject Reduction and Progress for Multiparty Session Processes" (ITP 2025), independently mechanises the synchronous-MPST subject-reduction theorem in Coq (~16K lines), and discovers that the structural-congruence rule for recursive processes as presented in *several* prior works violates subject reduction. They revise the rule.

The accumulated mechanisation work as of late 2025 documents at least three distinct broken-proof loci in the classical MPST literature: the merge-invariance gap [Scalas Yoshida 2019, Hou Yoshida Kuhn 2024], the original Honda–Yoshida–Carbone fragment-restriction [Tirore Bengtson Carbone 2025], and the recursive-structural-congruence rule [Ekici Kamegai Yoshida 2025]. The cumulative pattern is that the field's *informal* metatheoretic conventions encoded an architectural error that resists local repair. Each Coq mechanisation surfaces a fresh defect because the underlying decomposition (global → projection → local → process) is overspecified relative to the actual semantic content.

#### §VI.1.5 The bottom-up / hybrid alternative (Udomsrirungruang–Yoshida POPL 2025)

[Udomsrirungruang Yoshida 2025], "Top-Down or Bottom-Up? Complexity Analyses of Synchronous Multiparty Session Types" (POPL 2025), provides the first detailed complexity comparison between top-down (global → projection → local typecheck) and bottom-up (each participant's local type inferred, then checked against a global property φ). Their findings are operationally mixed: top-down is more efficient in realistic cases; bottom-up's liveness checking is the most expensive (PSPACE-hard, reduced from QBF); and bottom-up type inference is exponential in process size. They propose a graph-based subtyping system that is quadratic versus the existing exponential inductive algorithm.

The complexity-comparison result is honest about the tradeoffs but does not propose a unified foundation. The architectural target's claim — that conjunctive refinement is the natural composition operation — is not addressed by either approach: top-down composes by projection, bottom-up composes by typing-context union. Neither is intersection in a constraint lattice.

#### §VI.1.6 The deconfined-global-types and un-projectable-global-types lines (Dagnino et al. 2021–2024; Barbanera et al. 2024)

[Dagnino Giannini Dezani-Ciancaglini 2021], "Deconfined Global Types for Asynchronous Sessions" (Coordination 2021, journal version 2024), proposed a type system that types *all* asynchronous sessions while preserving subject reduction, session fidelity, and progress under well-formedness conditions. Type inference is sound and complete; well-formedness conditions are undecidable, but an expressive decidable restriction recovers effectiveness. [Barbanera Dezani-Ciancaglini de'Liguoro 2024], "Un-projectable Global Types for Multiparty Sessions" (PPDP 2024), goes further: they argue that projectability is *not necessary* for a global type to soundly describe well-behaved systems. Revising the global-type semantics to a coinductive LTS, they obtain a conservative extension accommodating unbounded and un-projectable global types. [Castellani Dezani-Ciancaglini Giannini 2024], "Global Types and Event Structure Semantics for Asynchronous Multiparty Sessions" (Fundamenta Informaticae 192(1)), interprets sessions as Flow Event Structures and global types as Prime Event Structures, with an equivalence theorem aligning the two interpretations on typable sessions.

The deconfined / un-projectable / event-structure line is the closest the published frontier comes to the architectural target's "conjunctive refinement" stance. It abandons projection-with-merge structurally rather than rhetorically. But it does not articulate the constructions categorically (the event-structure framework uses prime event structures and flow event structures, not a fibration over a participant lattice), and it does not formulate role projection as a universal-property construction.

#### §VI.1.7 Realisability versus complementability (Di Giusto–Lozes–Urso 2025)

[Di Giusto Lozes Urso 2025], "Realisability and Complementability of Multiparty Session Types" (HAL/ACM, 2025; journal article 10.1145/3756907.3756918), studies the relationship between realisability (does the parallel composition of local types match the global type?) and complementability (does there exist a global type describing the complement behaviour?). Main result: every global type realisable in the synchronous communication model is complementable, with effective doubly-exponential complementation. A follow-up [Di Giusto et al. 2025], arXiv 2512.05609, "On the Impact of the Communication Model on Realisability," analyses how realisability depends on synchronous vs p2p vs FIFO ordering. These results document the model-sensitivity of the basic notions — important data for any framework claiming to be model-agnostic.

#### §VI.1.8 Mixed choice, fairness, and the expressiveness frontier

The 2024–2026 mixed-choice work [Bocchi et al. 2026 arXiv 2602.23927; Le Brun Fowler Dardha ESOP 2025; Barbanera Dezani-Ciancaglini ICE 2025] addresses the long-standing limitation that classical MPST forbids a participant from being simultaneously sender and receiver of choices. Mixed choice is shown to be strictly more expressive than standard choice, and proof techniques tolerate transient inconsistencies in protocol state across participants while ensuring eventual consistency. This is a substantial expressivity frontier but again uses operational rather than categorical machinery.

The fairness frontier — [Bravetti Padovani Zavattaro 2025] CONCUR 2025 ("A Sound and Complete Characterization of Fair Asynchronous Session Subtyping"), [Padovani Zavattaro 2025] ECOOP 2025 ("Fair Termination of Asynchronous Binary Sessions") — finally provides a sound-and-complete characterization of fair asynchronous session subtyping after roughly a decade in which only sound algorithms were known. The ECOOP 2025 paper extends fair termination to asynchronous binary sessions via a novel coarser fair asynchronous subtyping. The fairness frontier is a precondition for the cost-aware extension the architectural target requires (fair subtyping + tropical-quantale grading); the 2025 results unblock that combination.

### §VI.2 Recent quantale-enriched concurrent semantics (post-2020)

The frontier in quantale-valued / metric coalgebraic semantics has matured substantially in 2023–2025. The architectural target inherits two distinct technical streams from this body of work.

#### §VI.2.1 Quantale-valued logics for coalgebras (Beohar et al. STACS 2024)

[Beohar Gurke König Messing Forster Schröder Wild 2024], "Expressive Quantale-Valued Logics for Coalgebras: An Adjunction-Based Approach" (STACS 2024, peer-reviewed LIPIcs), provides the most general framework currently available for relating modal logics to behavioural distances in a quantale-valued setting. The technical core is an adjunction-based recipe: given a Galois connection between an appropriate "concrete" lattice (logical formulas) and an "abstract" lattice (behavioural metric values), a fixpoint preservation property automatically lifts a Hennessy–Milner theorem. They instantiate to coalgebras based on machine functors in Eilenberg-Moore categories, covering branching-time bisimilarity-and-metrics and linear-time trace-equivalence-and-distances.

For the architectural target this paper supplies the **quantale-valued realizability fixpoint** machinery: realizability of a multi-party protocol against a quantale-valued cost (latency, resource consumption, failure probability) becomes a Galois-connection-induced fixpoint, with a corresponding modal logic that characterises the protocol's quantitative behaviour. The Async §6.3 frontier-scan covers the broader CCP-quantale lineage; this paper is the operationally-relevant mid-2020s consolidation.

#### §VI.2.2 Kantorovich functors and characteristic logics (Goncharov et al. FoSSaCS 2023)

[Goncharov Hofmann Nora Schröder Wild 2023], "Kantorovich Functors and Characteristic Logics for Behavioural Distances" (FoSSaCS 2023), establishes that *every* lax extension is Kantorovich (induced by a choice of monotone predicate liftings), and *every* functor lifting that preserves isometries is Kantorovich. Consequently, every behavioural distance induced by a sufficiently regular lifting can be characterised by a quantitative modal logic. The result is a structural classification: it tells you exactly when a coalgebraic behavioural metric is *automatically* logically characterizable.

The relevance to the architectural target: a multi-party protocol's quantale-graded behaviour will (under the architectural target's structuring) live in a Kantorovich functor's coalgebra. The 2023 result guarantees the protocol's behavioural distance is *automatically* characterisable by a quantitative modal logic — i.e., a session-type-like discipline. This unblocks the architectural step "behaviour is a coalgebra" → "type system is a quantitative modal logic" without further proof obligation.

#### §VI.2.3 Graded and behavioural-spectrum semantics

[CSL 2025, "Quantitative Graded Semantics and Spectra of Behavioural Metrics"] extends the framework to *graded* semantics, where the grade tracks distance-like indices. This is a candidate target for unifying with QTT-style multiplicities (e.g., Prologos's `m0`/`m1`/`mw`); the synthesis chapter can argue this unification.

[Forster et al. CMCS 2024, "Graded Semantics and Graded Logics for Eilenberg-Moore Coalgebras"] generalises the same machinery to Eilenberg-Moore coalgebras over a monad, expanding the class of computational effects (including state, exceptions, probability) to which quantale-valued behavioural-distance logics apply.

The frontier is *active* — the Erlangen / Sheffield / Birmingham / Birmingham line has multiple consecutive years of papers — but no published paper applies this machinery specifically to multi-party session types. Cross-reference Async §6.3.

### §VI.3 Polynomial functors in dependent type theory — recent work

#### §VI.3.1 Polynomial universes in HoTT (Aberlé–Spivak 2024–2026)

[Aberlé Spivak 2024–2026], "Polynomial Universes in Homotopy Type Theory" (arXiv 2409.19176; multiple revisions through January 2026; peer-review status: accepted at MFPS / appears in entics.episciences.org), axiomatizes the categorical semantics of dependent type theory entirely in terms of polynomial functors. The technical core is the **univalence condition for polynomial functors**: when a polynomial functor satisfies univalence, all higher-categorical coherences of its associated algebraic structures hold automatically. Polynomial universes closed under dependent products generate a distributive law of monads witnessing the standard Π/Σ distributivity.

The architectural relevance is unambiguous: this paper *is* the categorical foundation for treating Prologos's dependent types and the multi-party session-type discipline within one polynomial-functor framework. A multi-party global type, in the architectural target, is a polynomial functor; its role projections are induced morphisms of polynomials; its quantale-graded version is a polynomial functor over the quantale-enriched base. None of this is in [Aberlé Spivak 2024–2026] explicitly — but the categorical machinery to express it is.

#### §VI.3.2 Polynomial functors as a theory of interaction (Niu–Spivak 2024 book)

[Niu Spivak 2024], "Polynomial Functors: A Mathematical Theory of Interaction" (Cambridge LMS Lecture Notes vol. 498; arXiv 2312.00990v2 16 Aug 2024 update), is the textbook treatment. The book emphasises positions-and-directions ("a position with a direction is a way of asking a question and receiving an answer back") and the **composition product** of polynomials, which models time-evolution of interactive protocols. Lenses and dialectica categories appear as natural concomitants.

The book does not address multi-party session types directly. But its framing — interaction protocols as polynomial functors with composition product modelling temporal evolution — is the formal apparatus the architectural target inherits. The synthesis chapter's claim that "a multi-party protocol IS a polynomial functor" is *consonant* with [Niu Spivak 2024] but not stated by them.

#### §VI.3.3 Polynomial-functor effect handlers (Grodin–Spivak / Topos 2024)

[Grodin 2024 / Topos 2024], "Poly-morphic effect handlers" (Topos blog / 2024), reconstructs categorical semantics for programs with effects using polynomial functors, the free-monad monad, and the Grothendieck construction. Every effect signature is a polynomial functor: positions are operations, directions are result types. Composable effect handlers are isolated as a sub-class.

This work is the bridge between polynomial functors and the effect-handler frontier (cross-reference §VI.5 below and Async §6.4). It is not yet in published-and-peer-reviewed form (status: blog post / Topos research note as of 2024). For the architectural target, it provides the conceptual prototype: if a multi-party protocol's role-action signature is structurally an effect signature (one operation per send/receive, one direction per response), then a multi-party protocol *is* a polynomial-functor effect signature, and role projection is the corresponding handler-composition structure.

### §VI.4 Choreographic programming frontier — categorical content

#### §VI.4.1 First-class location (set) polymorphism (Samuelson–Hirsch–Cecchetti, OOPSLA 2025)

[Samuelson Hirsch Cecchetti 2025], "Choreographic Quick Changes: First-Class Location (Set) Polymorphism" (PACMPL OOPSLA2 article 336, October 2025; arXiv 2506.10913), introduces λ_QC, the first typed choreographic language with first-class process names and polymorphism over both types and *sets* of locations. A node can dynamically compute who should perform a computation and send that decision to others. The language supports algebraic and recursive data types and multiply-located values; deadlock freedom is mechanically verified in Rocq.

The relevance to the architectural target is that location-set polymorphism is *structurally* what the polynomial-functor framework would call **fibration polymorphism over the participant lattice**. λ_QC achieves the operational form of this without making the categorical content explicit. The Rocq mechanisation is engineering-grade evidence that the operational form works; the architectural target would propose the categorical content (location set as object in a fibration; location-set polymorphism as polymorphism over fibres) and recover λ_QC as its operational realisation.

#### §VI.4.2 Multicasting and multiply-located values (Bates–Near 2024)

[Bates Near 2024], "We Know I Know You Know; Choreographic Programming With Multicast and Multiply Located Values" (arXiv 2403.05417, March 2024 — *note: the prompt's attribution to Lam–Hirsch–Cecchetti is incorrect; the authors are Mako Bates and Joseph P. Near, University of Vermont; preprint status*), introduces the **He-Lambda-Small** language. Values exist simultaneously at multiple parties via multicast; the "select" operation of prior choreographic languages is eliminated by requiring conditional guards to be located at all relevant parties; well-typedness implies deadlock-freedom.

Multiply-located values are conceptually a generalisation of "common knowledge" in the epistemic-logic tradition. The paper's title "We Know I Know You Know" alludes to the iterated-mutual-knowledge towers of distributed-knowledge logic. The categorical content — what *is* a multiply-located value? — is naturally a **dependent product over the location set**, i.e., a section of a fibration's fibre. Once again, the operational form is delivered without the categorical foundation.

#### §VI.4.3 Modal type theory for choreographic programming (Bak–Urschumzew, CP 2024)

[Bak Urschumzew 2024], "Choreographic Programming in Modal Type Theory" (CP 2024, PLDI 2024 satellite workshop; presentation, slides + video — peer-review status: workshop presentation, not full conference paper), shows that location annotations in choreographic languages correspond to modalities in Modal Type Theory (MTT). A translation from Chor λ to MTT is sketched; two new concepts arise as required infrastructure: common knowledge between roles, and locally referenced choreographies.

Bak–Urschumzew is the closest published work to the architectural target's "role projection as opcartesian fibration lift" claim. Modalities in MTT are dependent fibres; the fibration / Grothendieck-construction interpretation of modal type theory is well-known [Birkedal et al.]. The operational translation in [Bak Urschumzew 2024] is a precise correspondence at the level of types and terms; what is *not* yet done is the formulation of multi-party session types' projection as the categorical universal property in the corresponding MTT model.

#### §VI.4.4 Hierarchical choreographic programming and authorization logic (Hirsch, CP 2024 / 2024)

[Hirsch 2024], "Corps: A Core Calculus of Hierarchical Choreographic Programming" (arXiv 2406.01456, June 2024; CP 2024 presentation), takes a propositions-as-types view where data ownership is a *modality*, not a linearity. The logical foundation is **doxastic logic** — logic of belief — instantiated as authorization logic with explicit communication. Roles can be hierarchically organised; first-tier-only Corps programs are close to Pirouette / Chor λ.

Doxastic / authorization logic is structurally a fibration over a "principals" lattice, with belief modalities as fibre-restriction. The architectural target's "role identity is a capability" claim (§VI.5 / Async §6.2) and Corps's "data ownership is a modality" claim are dual aspects of the same fibration structure: modalities indexed by location are categorically equivalent to capabilities granting access to per-location operations.

#### §VI.4.5 Out-of-order choreographies (Plyukhin–Peressotti–Montesi, ECOOP 2024)

[Plyukhin Peressotti Montesi 2024], "Ozone: Fully Out-of-Order Choreographies" (ECOOP 2024 LIPIcs vol. 313 article 31, peer-reviewed), addresses a long-standing complaint about choreographic programming: that processes typically execute in a fixed deterministic order, blocking parallelism even when messages could arrive out-of-order without harm. They develop a model of choreographic programming for out-of-order processes that guarantees absence of communication-integrity violations (CIVs) and deadlocks, and provide an API for non-blocking futures in Choral.

The 2024 ECOOP paper is the cleanest demonstration that choreographic-style global specifications need not impose imperative ordering on the operational substrate — the global type IS the dataflow constraint, and any execution respecting it is sound. This is consonant with the propagator-network operational substrate the architectural target proposes: a propagator network's BSP scheduler fires propagators in the order their dataflow demands, not the order they were installed. The Ozone result shows the same principle works at the choreography level. Cross-reference Async §6.1.

#### §VI.4.6 Functional / semilenient core (ICFP 2025)

[Plyukhin et al. 2025], "Relax! The Semilenient Core of Choreographic Programming (Functional Pearl)" (ICFP 2025 PACMPL), refines the operational core. [Bohosian 2025], "Choreographies as Macros" (Buffalo tech report), implements the choreographic semantics on top of Racket's macro system — a notable touchpoint with Prologos's Racket implementation. [Cruz-Filipe Montesi forthcoming], "Introduction to Choreographies" (Cambridge), provides the textbook synthesis.

#### §VI.4.7 Event structure and choreography composition (Castellani–Dezani-Ciancaglini–Giannini 2024)

[Castellani Dezani-Ciancaglini Giannini 2024] (Fundamenta Informaticae 192(1)) interprets multiparty sessions as Flow Event Structures and global types as Prime Event Structures, proving an equivalence on typable sessions. Event structures have a known categorical reading as presheaves over a "partial order of configurations" — they are a particular kind of polynomial-functor coalgebra. The 2024 paper does not make this categorical reading explicit, but the equivalence-of-event-structure-interpretations result is the kind of structural completeness theorem the architectural target's polynomial-functor formulation should generalise.

### §VI.5 Effect-handler / capability frontier (cross-cut from async research)

#### §VI.5.1 Capability-as-effect and capability-passing (Brachthäuser et al. ICFP 2024)

[Odersky 2024 ICFP keynote], "Capabilities for Control" (ICFP 2024), positions object-capabilities as the foundation for new effect-tracking type systems. The keynote's claim — that capabilities solve the "what color is your function?" problem of effect polymorphism — is structurally the same claim that Prologos's session-types-and-effects-as-capabilities architecture would make. The keynote is not a peer-reviewed paper but is publicly archived.

[Müller Schuster Starup Ostermann Brachthäuser 2024], "From Capabilities to Regions: Enabling Efficient Compilation of Lexical Effect Handlers," and [Schuster 2024 PhD], "Compiling Lexical Effect Handlers with Capabilities, Continuations, and Evidence," continue the [Schuster Brachthäuser 2020] capability-passing-style line. The technical depth is operational compilation; the conceptual claim — capability-passing is the natural compilation of effect handlers — matches the architectural target's "role identity is a capability" claim.

[Ahman Pretnar 2024], "Higher-Order Asynchronous Effects" (LMCS 20(3) 2024), gives a higher-order asynchronous-effect treatment that is currently the closest published account of asynchronous control flow within the algebraic-effect lineage.

#### §VI.5.2 Parallel algebraic effect handlers (ICFP 2024)

[Lu et al. 2024 ICFP], "Parallel Algebraic Effect Handlers," addresses the operational frontier of running effect handlers concurrently. The relevance to multi-party protocols is direct: a multi-party protocol's per-role behaviour is a parallel handler over the per-role action signature. A categorical formulation of this in polynomial-functor terms would apply Grodin's poly-morphic effect handlers (§VI.3.3) to the multi-party setting.

#### §VI.5.3 The CapTP / OCapN gap (Spritely community, 2024–2025)

[OCapN/Spritely 2024–2025], the Spritely Institute's OCapN protocol (CapTP layer) supports **third-party handoffs**: a node A can send a capability referencing an object on B to C, after which C connects directly to B. Two distinct OCapN implementations achieved interoperability in 2024.

A third-party handoff is structurally a small choreography: three parties (A, B, C) participate in a multi-step protocol whose global type would be `A→C: cap, then C→B: connect, then B→C: established`. The Async §6.6 gap inventory's gap (g) — "CapTP / OCapN in quantale formalism" — names exactly this point. The architectural target's polynomial-functor + quantale-graded multi-party framework would *generate* OCapN's third-party handoff as one of its structural derivations, with cost-aware semantics (latency, fairness, resource bounds) attached automatically.

No published 2024–2026 paper formulates OCapN's protocol family in either MPST or choreographic-programming machinery. This is a frontier gap with a clear line of attack.

### §VI.6 The Spritely / OCapN connection (cross-cut from async §6.2)

The Async §6.2 frontier-scan covers the contemporary capability-async revival in detail: Spritely Goblins, OCapN, and the lineage to Mark Miller's E and Robust Composition thesis [Miller 2006]. The 2024–2025 contribution is the OCapN protocol standardization push (NLnet grant; Tallon coordination). For the multi-party angle, the salient observation is that **OCapN's three-vat handoff is a multi-party protocol** in the lineage of E's distributed object-capability system; the Spritely community has not formalised it as such, but the 2024 interoperability success demonstrates the protocol's stability.

The architectural target — by treating role identity as capability and protocol composition as conjunctive refinement — would unify the MPST-style discipline with the OCapN object-capability discipline. No 2024–2026 paper attempts this unification.

### §VI.7 Tropical mathematics and PL semantics (cross-cut)

#### §VI.7.1 Tropical lambda calculus parts I and II (Barbarossa–Pistone CSL 2024 / POPL 2025)

[Barbarossa Pistone 2024], "Tropical Mathematics and the Lambda-Calculus I: Metric and Differential Analysis of Effectful Programs" (CSL 2024 LIPIcs vol. 288 article 14, peer-reviewed), interprets the lambda-calculus in a framework based on the *tropical semiring* (min, +). Two prior quantitative approaches — program-metric analysis via Lipschitz conditions, and resource analysis via linear logic and higher-order differentiation — unify under the tropical-semiring relational model. The framework rests on an abstract correspondence between tropical algebra and Lawvere's theory of generalized metric spaces.

[Barbarossa Pistone 2025], "Tropical Mathematics and the Lambda-Calculus II: Tropical Geometry of Probabilistic Programming Languages" (PACMPL POPL 2025, peer-reviewed), develops tropical-geometric tools for higher-order probabilistic programming: each program receives a polyhedral object encoding "most likely runs"; an intersection type system enables compositional estimation of most-probable execution paths.

The tropical semiring is a quantale (specifically, a totally-ordered idempotent quantale). The Barbarossa–Pistone parts I/II line is the most rigorous PL-semantics development of tropical-quantale ideas in 2024–2025. The multi-party extension — assigning each participant in a multi-party protocol a tropical-cost grading, and computing the protocol's cost as a tropical-quantale fixpoint over the participant lattice — is a natural next step that no published 2024–2026 paper takes. Cross-reference Async §6.5.

#### §VI.7.2 Resource-bounded type theory (Mannucci–Thuro 2025–2026 preprint)

[Mannucci Thuro 2025], "Resource-Bounded Type Theory: Compositional Cost Analysis via Graded Modalities" (arXiv 2512.06952, December 2025; preprint status), presents a compositional framework for certifying resource bounds. Terms are typed with synthesised bounds drawn from an **abstract resource lattice**; a graded feasibility modality with co-unit and monotonicity laws enables bound composition; the paper proves syntactic cost soundness for the recursion-free simply-typed fragment, and constructs a presheaf model in the topos of presheaves over the resource lattice.

[Mannucci Thuro 2026], "Resource-Bounded Martin-Löf Type Theory: Compositional Cost Analysis for Dependent Types" (arXiv 2601.10772, January 2026; preprint extension of the 2025 paper), extends the framework to dependent types. Both papers are foundationally relevant to Prologos, which already runs a tropical-quantale cost layer adjacent to its effect-ordering quantale.

The resource-bounded type-theory frontier is *strictly individual*: it concerns single-program cost analysis. The multi-party extension (assigning costs to per-role actions and computing aggregate protocol cost) is unattempted in published work as of late 2025 / early 2026. Combining [Mannucci Thuro 2025–2026]'s graded modality with the architectural target's polynomial-functor multi-party framework would yield exactly the cost-aware multi-party protocol theory the architectural target requires.

### §VI.8 Gaps in the frontier

The following catalogue identifies what 2024–2026 published-or-accepted work has *not* done that the architectural target requires. The synthesis chapter argues each gap; this section catalogues them.

#### Gap (a) — Multi-party session types as polynomial functors over LCCC

No published 2024–2026 paper formulates multi-party session types as polynomial functors over a locally-cartesian-closed category in dependent type theory. The closest published works approach this from non-MPST directions: [Niu Spivak 2024] supplies the polynomial-functor theory of interaction without applying it to MPST; [Aberlé Spivak 2024–2026] supplies the polynomial-universes-in-DTT framework without addressing concurrent / multi-party computation; [Grodin 2024 / Topos] supplies the polynomial-functor theory of effect handlers without lifting to multi-party. The MPST literature side does not engage with polynomial-functor theory.

#### Gap (b) — Role projection as opcartesian fibration lift

No published work formulates role projection as a categorical universal-property construction in a fibration over a participant lattice. [Bak Urschumzew 2024]'s MTT formulation gets closest: location annotations as MTT modalities, which are categorically a fibration. But Bak–Urschumzew is a workshop presentation translating Chor λ to MTT, not a multi-party-session-type framework, and does not formulate projection as a categorical universal property. The Stutz line ([Stutz D'Osualdo 2025] etc.) treats projection algorithmically, not categorically. The synthetic-MPST line ([Castro-Perez Ferreira Jongmans 2026]) eliminates projection entirely rather than formulating it as a universal property.

#### Gap (c) — Conjunctive refinement as protocol composition

Despite the well-developed CCP-quantale literature (cross-reference Async §3.3) and the trait-system literature ([POPL 2025–2026 Generic Refinement Types, Boolean-Algebraic Subtyping]), no published session-type work uses **conjunctive refinement** (intersection in a constraint lattice) as the *primary* composition operation. The MPST field went projection-first; the bottom-up alternative ([Udomsrirungruang Yoshida 2025]) composes by typing-context union; the synthetic alternative ([Castro-Perez Ferreira Jongmans 2026]) composes by independent verification against a shared LTS. None of these is intersection in a constraint lattice.

The intersection-types-for-sessions tradition ([Padovani; Castagna et al. 2008–2017]) treats intersection at the *session-type* level, not as a composition operation at the protocol-bundle level. The trait-and-bundle literature ([Generic Refinement Types POPL 2025; Boolean-Algebraic Subtyping POPL 2026]) treats intersection at the trait level. No published work bridges these to a unified algebra in which trait-bundles and protocol-bundles are instances of one conjunctive composition.

#### Gap (d) — Cost-aware multi-party protocols

No published multi-party-session-type framework has cost-aware realizability as a *primary* feature. The fairness frontier ([Bravetti Padovani Zavattaro 2025; Padovani Zavattaro 2025]) is sound-and-complete at last but is purely qualitative (does the protocol terminate fairly?). The probabilistic-sessions frontier ([Compositional Interface Refinement Through Subtyping in Probabilistic Session Types ICTAC 2025; Lanese Lago Choudhury 2024 quantum sessions]) addresses probability but not general quantale-graded cost. The tropical-lambda-calculus frontier ([Barbarossa Pistone 2024–2025]) is tropical-quantitative but single-thread. The resource-bounded TT frontier ([Mannucci Thuro 2025–2026]) is graded-quantale but single-program. No published work combines these into a tropical-quantale-graded multi-party-protocol theory.

#### Gap (e) — Multi-party from binary via dependent-type-in-continuation

No published 2024–2026 work shows that multi-party falls out of binary session types + dependent types in continuation positions as a *structural consequence of the type theory*. [Samuelson Hirsch Cecchetti 2025]'s λ_QC achieves first-class location-set polymorphism via choreographic programming — a multi-party language — but the multi-party-ness is built in operationally, not derived from binary session types. The synthetic-MPST line ([Castro-Perez Ferreira Jongmans 2026]) operates on global LTS specifications without proving that these arise from binary-with-dependent-continuation structure. [Hirsch 2024]'s Corps uses doxastic logic and authorization modalities, but not dependent-types-in-continuation.

#### Gap (f) — Trait-bundle / protocol-bundle algebra unification

No published work treats trait-bundles (intersection of refinement constraints in a constraint lattice) and protocol-bundles (intersection of protocol obligations) as *instances of the same algebra*. [Generic Refinement Types POPL 2025] addresses trait-level refinement composition; [Boolean-Algebraic Subtyping POPL 2026] addresses Boolean-algebraic intersection / union / negation in the type lattice; the MPST literature addresses session-level composition through projection or LTS-equivalence. No published paper observes that trait-composition and session-composition are the same conjunctive-refinement algebra at different lattice levels.

#### Gap (g) — NTT-style declarative spec for multi-party protocols

No published work has a *declarative specification language* analogous to NTT (or HOCAML, or Maude, or Rebeca) where multi-party protocols are specified at the *same layer* as the propagator-network architecture they run on. Maude [Clavel et al.] supports rewriting-logic protocol specification but operates as a pure rewriting system, not as a propagator-network. Rebeca [Sirjani et al.] supports actor-model protocol verification but treats actors imperatively. NTT (Prologos's internal speculative syntax design) is the only candidate currently being developed. The gap here is that the multi-party setting needs a declarative substrate where (i) cell allocations are protocol-state-spaces, (ii) propagator firing is protocol-step execution, (iii) lattice merge functions are session-type compositions, and (iv) stratification is the standard MPST top-down vs bottom-up partition.

#### Gap (h) — Multi-party via propagator-network coalgebraic inhabitation

No published work uses a **propagator-network substrate** (as distinct from labelled-transition systems, communicating state machines, π-calculus, or process algebras) for multi-party-session-type checking. The Stutz–D'Osualdo AMP framework uses CSMs. The Castro-Perez–Ferreira–Jongmans synthetic framework uses LTSs. The choreographic-programming framework uses operational semantics + endpoint projection. The propagator-network substrate is the operational form of "BSP-scheduled monotone-merge cells with stratification handlers," which is structurally a coalgebra of a polynomial functor over a quantale-enriched base. The architectural target proposes this substrate; no 2024–2026 published work overlaps it.

A further sub-gap: **monotone-merge cells with non-monotone retraction strata** are the operational form of Tarski-fixpoint S0 + Gauss–Seidel-fixpoint Sk computation. This pattern appears nowhere in the published session-type or choreographic-programming literature. CALM-safety guarantees the S0 fixpoint is coordination-free; the propagator-network substrate makes this concrete. The MPST field's analogue — type checking via global-type LTS — is operationally a (possibly non-monotone) reachability computation, which loses CALM-safety.

### §VI.9 Where the Prologos contribution would land

The eight gaps catalogued in §VI.8 are not independent. Gap (a) (polynomial functors over LCCC for MPST) is the categorical foundation; gap (b) (role projection as opcartesian lift) is a structural consequence; gap (c) (conjunctive refinement as composition) follows from gap (a) once the LCCC structure is fixed; gap (d) (cost-aware multi-party) is gap (a) instantiated over a quantale; gap (e) (multi-party from binary + dependent-continuation) is the type-theoretic adequacy theorem witnessing gap (a); gap (f) (trait-bundle / protocol-bundle unification) is the engineering content of gap (c); gap (g) (NTT-style declarative spec) is the surface-syntax layer over gap (h); gap (h) (propagator-network coalgebraic substrate) is the operational realization of gap (a).

The architectural target — *multi-party protocols as polynomial functors over a quantale-valued propagator runtime, with role projection as opcartesian lifts in a fibration, behavior as coalgebras, realizability as a quantale-valued fixpoint, composition as conjunctive refinement* — addresses all eight gaps simultaneously by anchoring the categorical foundation (gap a). Each derived gap follows from the foundation:

- **Role projection** = opcartesian lift in the participant fibration = canonical dependent product over a slice category (gap b).
- **Composition** = pullback in the polynomial-functor category = intersection in the constraint lattice = conjunctive refinement (gap c, gap f).
- **Cost-grading** = base-changing the polynomial-functor category to the quantale-enriched base (gap d).
- **Binary + dependent continuation = multi-party**: every binary session type S whose continuation is `(role : Role) → S'` instantiates to a per-role family of binary sessions, which is structurally a polynomial-functor coalgebra over the role lattice. This is the type-theoretic adequacy theorem (gap e).
- **Trait-bundle / protocol-bundle unification**: trait-bundles are conjunctive composition at the *constraint-lattice* level; protocol-bundles are conjunctive composition at the *polynomial-functor-coalgebra* level. Both are intersections in a constraint lattice; one is a special case of the other through the lattice-of-coalgebras functor. (gap f).
- **NTT declarative spec**: the polynomial-functor formulation has a small set of categorical primitives (positions, directions, composition, base-change). NTT's syntax can be designed to expose exactly these primitives, with `cell` declarations as `position`s, `propagator` declarations as `direction`-driven morphisms, `lattice` declarations as quantale-base specifications. (gap g).
- **Propagator-network coalgebraic substrate**: a propagator network is a coalgebra of a polynomial functor; BSP-scheduled monotone-merge cells with stratification handlers realise the operational fixpoint over the participant base. The categorical structure of the target *is* the architectural structure of the runtime. (gap h).

The publication target is LICS 2027 or POPL 2027. A paper landing there would provide:
1. A categorical foundation cleaner than [Castro-Perez Ferreira Jongmans 2026]'s synthetic-LTS or [Stutz D'Osualdo 2025]'s automata-theoretic backend.
2. Cost-grading that the [Bravetti Padovani Zavattaro 2025] fairness frontier and the [Barbarossa Pistone 2024–2025] tropical-lambda frontier do not have together.
3. A working language (Prologos) as the engineering, not a metatheoretical construction. The 2024–2026 community is openly looking for what comes after projection-with-merge; the post-projection landscape is multi-pronged but lacks a unifying foundation. The polynomial-functor formulation is consonant with the established theory (Awodey–Newstead natural models; Niu–Spivak interaction theory; Beohar et al. quantale-coalgebraic logic) and provides the architectural frame the field has lacked.

The risks: (i) the polynomial-functor-with-quantale-base framework may require non-trivial 2-categorical machinery (slice categories enriched in quantales) that has not been fully developed in the published literature; (ii) the engineering claim ("Prologos as the language") will require concrete protocol case studies, and the OCapN-handoff case study (gap (g) of Async §6.6, this artifact §VI.5.3) is the natural starting point but is currently unformalised in MPST machinery; (iii) the multi-party-from-binary adequacy theorem (gap (e)) requires a precise statement and proof, which is unprecedented in the published literature.

The 2024–2026 frontier shows the field is *ready* for this contribution. Each adjacent community has matured enough that the synthesis is technically achievable. The gap inventory is the load-bearing finding of this slice: it documents that no published 2024–2026 work occupies the architectural target's position, while every adjacent direction has matured to the point where the synthesis would be welcomed.

---

## References (annotated, 2024–2026 emphasis)

### Multiparty session types — repair and reconstruction

[Hou Yoshida Kuhn 2024] Hou, Ping; Yoshida, Nobuko; Kuhn, Iona. "Less is More Revisited: Association with Global Protocols and Multiparty Sessions." arXiv:2402.16741, Feb 2024 (revised through 2026). Springer LNCS (chapter 14), peer-reviewed. The fix-the-broken-proof line: introduces association relation between global-type LTS semantics and endpoint-projection composition; recovers session fidelity, deadlock freedom, liveness under full mergeability.

[Castro-Perez Ferreira Jongmans 2026] Castro-Perez, David; Ferreira, Francisco; Jongmans, Sung-Shik. "A Synthetic Reconstruction of Multiparty Session Types." PACMPL POPL 2026, vol. 10, doi:10.1145/3776692. arXiv:2511.22692, Nov 2025. Peer-reviewed. Eliminates projection and local types; type-checks each process directly against global-LTS specifications. The synthetic-MPST line; key 2026 paper.

[Stutz D'Osualdo 2025] Stutz, Felix; D'Osualdo, Emanuele. "An Automata-theoretic Basis for Specification and Type Checking of Multiparty Protocols." ESOP 2025 LNCS, doi:10.1007/978-3-031-91121-7_13. arXiv:2501.16977. Peer-reviewed. Introduces AMP (Automata-based Multiparty Protocols), PSMs, CSMs, type checking against CSM specs; tame PSMs admit sound-and-complete PSPACE projection.

[Li Stutz Wies 2024] Li, Elaine; Stutz, Felix; Wies, Thomas. "Deciding Subtyping for Asynchronous Multiparty Sessions." ESOP 2024 LNCS, doi:10.1007/978-3-031-57262-3_8. arXiv:2401.16395. Peer-reviewed. Polynomial-time decidability of asynchronous multiparty subtyping with CSMs as implementation model.

[Li Stutz Wies Zufferey 2025] "Characterizing Implementability of Global Protocols with Infinite States and Data." PACMPL OOPSLA 2025, doi:10.1145/3720493. arXiv:2411.05722. Peer-reviewed. First sound and relatively complete implementability checker for symbolic MPST with dependent refinements; Sprout tool.

[Tirore Bengtson Carbone 2025] Tirore, Dawit; Bengtson, Jesper; Carbone, Marco. "Multiparty Asynchronous Session Types: A Mechanised Proof of Subject Reduction." ECOOP 2025 LIPIcs vol. 333, article 31. Peer-reviewed. Coq mechanisation; documents further flaws in [Honda Yoshida Carbone 2008] and proposes a fragment-restriction.

[Ekici Kamegai Yoshida 2025] Ekici, Burak; Kamegai, Tadayoshi; Yoshida, Nobuko. "Formalising Subject Reduction and Progress for Multiparty Session Processes." ITP 2025. Peer-reviewed. Independent Coq mechanisation; identifies the structural-congruence-rule defect for recursive processes; ~16K lines of Coq.

[Udomsrirungruang Yoshida 2025] Udomsrirungruang, Thien; Yoshida, Nobuko. "Top-Down or Bottom-Up? Complexity Analyses of Synchronous Multiparty Session Types." PACMPL POPL 2025, doi:10.1145/3704872. arXiv:2411.07452. Peer-reviewed. Detailed complexity comparison; PSPACE-hardness of bottom-up liveness via QBF reduction; novel quadratic graph-based subtyping.

[Castellani Dezani-Ciancaglini Giannini 2024] Castellani, Ilaria; Dezani-Ciancaglini, Mariangiola; Giannini, Paola. "Global Types and Event Structure Semantics for Asynchronous Multiparty Sessions." Fundamenta Informaticae 192(1), 1–75, 2024. arXiv:2102.00865. Peer-reviewed. Flow-Event-Structure interpretation of sessions; Prime-Event-Structure interpretation of global types; equivalence theorem on typable sessions.

[Barbanera Dezani-Ciancaglini de'Liguoro 2024] Barbanera, Franco; Dezani-Ciancaglini, Mariangiola; de'Liguoro, Ugo. "Un-projectable Global Types for Multiparty Sessions." PPDP 2024, doi:10.1145/3678232.3678245. Peer-reviewed. Argues projectability is unnecessary; coinductive LTS semantics for global types; conservative extension typing infinite-session global types.

[Barbanera Dezani-Ciancaglini 2024] Barbanera, Franco; Dezani-Ciancaglini, Mariangiola. "Asynchronous Multiparty Sessions with Internal Delegation." ISoLA 2024 LNCS vol. 15219. Peer-reviewed. First type system for asynchronous multiparty sessions with internal delegation.

[Dagnino Giannini Dezani-Ciancaglini 2021/2024] "Deconfined Global Types for Asynchronous Sessions." Coordination 2021 LNCS; journal version LMCS 2024 (#10809). Peer-reviewed. Types all asynchronous sessions while preserving subject reduction, session fidelity, progress; sound-complete inference; expressive decidable well-formedness restriction.

[Bravetti Padovani Zavattaro 2025] "A Sound and Complete Characterization of Fair Asynchronous Session Subtyping." CONCUR 2025 LIPIcs vol. 348 article 11. Peer-reviewed. First sound and complete characterization of asynchronous fair session subtyping after a decade of sound-only algorithms.

[Padovani Zavattaro 2025] "Fair Termination of Asynchronous Binary Sessions." ECOOP 2025 LIPIcs article 24. Peer-reviewed. Novel coarser fair asynchronous subtyping; fair termination including starvation freedom and orphan-message freedom.

[Le Brun Fowler Dardha 2025] "Multiparty Session Types with a Bang!" ESOP 2025 LNCS, doi:10.1007/978-3-031-91121-7_6. arXiv:2501.14702. Peer-reviewed. MPST! with replication and first-class roles; replication shown not to be equivalent to recursion; binary tree serialisation, dining philosophers, auction examples.

[Bocchi et al. 2026 preprint] "Mixed Choice in Asynchronous Multiparty Session Types." arXiv:2602.23927, 2026 (preprint). Mixed-choice core construct allowing transient inconsistencies with eventual consistency.

[Modular Multiparty Sessions 2025 preprint] "Modular Multiparty Sessions with Mixed Choice." arXiv:2508.13616, 2025 (preprint, ICE 2025).

[Di Giusto Lozes Urso 2025] "Realisability and Complementability of Multiparty Session Types." arXiv:2507.17354, doi:10.1145/3756907.3756918, 2025. Peer-reviewed. Every realisable global type is complementable in synchronous communication model with effective doubly-exponential complementation.

[Di Giusto et al. 2025 preprint] "On the Impact of the Communication Model on Realisability." arXiv:2512.05609, December 2025 (preprint).

[Refinements for Multiparty 2024] "Refinements for Multiparty Message-Passing Protocols: Specification-Agnostic Theory and Implementation." ECOOP 2024 LIPIcs vol. 313 article 41. arXiv:2407.09106. Peer-reviewed. Refinement framework decoupled from underlying computational model; trace system + RCS model; Rust toolchain.

### Choreographic programming — frontier

[Samuelson Hirsch Cecchetti 2025] Samuelson, Ashley; Hirsch, Andrew K.; Cecchetti, Ethan. "Choreographic Quick Changes: First-Class Location (Set) Polymorphism." PACMPL OOPSLA 2025 article 336, doi:10.1145/3763114. arXiv:2506.10913. Peer-reviewed. λ_QC: first-class location-set polymorphism; algebraic and recursive data types; multiply-located values; deadlock freedom mechanically verified in Rocq.

[Bates Near 2024 preprint] Bates, Mako; Near, Joseph P. "We Know I Know You Know; Choreographic Programming With Multicast and Multiply Located Values." arXiv:2403.05417, March 2024 (preprint, ICFP 2024 submission). He-Lambda-Small with multiply-located values; eliminates select operations; type-safety implies deadlock-freedom.

[Bak Urschumzew 2024] Bak, Miëtek; Urschumzew, Maxim. "Choreographic Programming in Modal Type Theory." CP 2024 (PLDI 2024 satellite workshop), presentation + slides + video. Workshop presentation. Translation of Chor λ to MTT; location-as-modality; common-knowledge and locally-referenced choreographies as required infrastructure.

[Hirsch 2024 preprint] Hirsch, Andrew K. "Corps: A Core Calculus of Hierarchical Choreographic Programming." arXiv:2406.01456, June 2024; CP 2024 presentation. Preprint. Doxastic/authorization-logic foundation; data-ownership-as-modality; first-tier Corps close to Pirouette / Chor λ.

[Plyukhin Peressotti Montesi 2024] Plyukhin, Dan; Peressotti, Marco; Montesi, Fabrizio. "Ozone: Fully Out-of-Order Choreographies." ECOOP 2024 LIPIcs vol. 313 article 31, doi:10.4230/LIPIcs.ECOOP.2024.31. arXiv:2401.17403. Peer-reviewed. Out-of-order process execution with absence of CIVs and deadlocks; non-blocking-futures API for Choral.

[Plyukhin et al. 2025] "Relax! The Semilenient Core of Choreographic Programming (Functional Pearl)." ICFP 2025 PACMPL, doi:10.1145/3747538. Peer-reviewed.

[Bohosian 2025] Bohosian, Alexander. "Choreographies as Macros." University at Buffalo Tech Report 2025-18, August 2025. Tech report. Implements choreographic semantics on Racket macro system; Choret library.

[Cruz-Filipe Montesi forthcoming] Cruz-Filipe, Luís; Montesi, Fabrizio. "Introduction to Choreographies." Cambridge University Press, forthcoming. Textbook synthesis.

[Hirsch Garg 2022] (reference for Pirouette) "Pirouette: Higher-Order Typed Functional Choreographies." POPL 2022.

[Choral PLDI 2024 / TOPLAS 2024] "Choral: Object-Oriented Choreographic Programming." ACM TOPLAS, doi:10.1145/3632398. Peer-reviewed.

### Quantale-valued / coalgebraic concurrency semantics

[Beohar Gurke König Messing Forster Schröder Wild 2024] Beohar, Harsh; Gurke, Sebastian; König, Barbara; Messing, Karla; Forster, Jonas; Schröder, Lutz; Wild, Paul. "Expressive Quantale-Valued Logics for Coalgebras: An Adjunction-Based Approach." STACS 2024 LIPIcs vol. 289 article 10, doi:10.4230/LIPIcs.STACS.2024.10. arXiv:2310.05711. Peer-reviewed. Galois-connection-based fixpoint preservation; Hennessy-Milner theorem for quantale-valued behavioural logics; instantiation to branching-time and linear-time.

[Goncharov Hofmann Nora Schröder Wild 2023] Goncharov, Sergey; Hofmann, Dirk; Nora, Pedro; Schröder, Lutz; Wild, Paul. "Kantorovich Functors and Characteristic Logics for Behavioural Distances." FoSSaCS 2023 LNCS, doi:10.1007/978-3-031-30829-1_3. arXiv:2202.07069. Peer-reviewed. Every lax extension is Kantorovich; every isometry-preserving functor lifting is Kantorovich; characteristic logic for behavioural distances.

[Forster et al. 2024] "Graded Semantics and Graded Logics for Eilenberg-Moore Coalgebras." CMCS 2024. Peer-reviewed. Graded extension to Eilenberg-Moore coalgebras over a monad.

[CSL 2025 quantitative graded] "Quantitative Graded Semantics and Spectra of Behavioural Metrics." CSL 2025 LIPIcs vol. 326 article 33. Peer-reviewed.

[CSL 2023 density Hennessy-Milner] "Quantitative Hennessy-Milner Theorems via Notions of Density." CSL 2023 LIPIcs article 22. Peer-reviewed.

### Polynomial functors in dependent type theory

[Aberlé Spivak 2024–2026 preprint/accepted] Aberlé, C.B.; Spivak, David I. "Polynomial Universes in Homotopy Type Theory." arXiv:2409.19176, multiple revisions through January 2026. entics.episciences.org/16885. Accepted (Entics / MFPS line). Polynomial universes; univalence condition for polynomial functors; distributive law of monads from Π/Σ closure.

[Niu Spivak 2024] Niu, Nelson; Spivak, David I. "Polynomial Functors: A Mathematical Theory of Interaction." Cambridge University Press LMS Lecture Note Series 498, 2024. arXiv:2312.00990v2 (16 Aug 2024). Peer-reviewed monograph. Positions-and-directions; composition product; interaction protocols and dynamical systems applications.

[Awodey 2024] "On Hofmann-Streicher universes." Mathematical Structures in Computer Science 34, 894–910, 2024. doi:10.1017/S0960129524000203. Peer-reviewed.

[Grodin 2024] Grodin, Harrison. "Poly-morphic effect handlers." Topos Institute blog, January 2024. Topos research note. Categorical reconstruction of effect-handler semantics via polynomial functors, free-monad monad, Grothendieck construction.

### Effect handlers / capability frontier

[Schuster Brachthäuser 2020] (foundational) "Compiling effect handlers in capability-passing style." ICFP 2020 PACMPL, doi:10.1145/3408975.

[Brachthäuser et al. 2024] "From Capabilities to Regions: Enabling Efficient Compilation of Lexical Effect Handlers." Effekt-language publications.

[Schuster 2024] PhD thesis. "Compiling Lexical Effect Handlers with Capabilities, Continuations, and Evidence." University of Tübingen, 2024.

[Odersky 2024] "Capabilities for Control." ICFP 2024 keynote.

[Lu et al. 2024] "Parallel Algebraic Effect Handlers." ICFP 2024.

[Ahman Pretnar 2024] "Higher-Order Asynchronous Effects." Logical Methods in Computer Science 20(3), 2024. Peer-reviewed.

### Tropical mathematics and resource-bounded type theory

[Barbarossa Pistone 2024] "Tropical Mathematics and the Lambda-Calculus I: Metric and Differential Analysis of Effectful Programs." CSL 2024 LIPIcs vol. 288 article 14. arXiv:2311.15704. Peer-reviewed. Tropical-semiring relational model unifies program-metric Lipschitz analysis and resource analysis via linear-logic differentiation.

[Barbarossa Pistone 2025] "Tropical Mathematics and the Lambda-Calculus II: Tropical Geometry of Probabilistic Programming Languages." PACMPL POPL 2025, doi:10.1145/3776675. arXiv:2501.15637. Peer-reviewed. Polyhedral encoding of most-likely runs; intersection-type system for compositional inference of most-probable execution paths.

[Mannucci Thuro 2025 preprint] "Resource-Bounded Type Theory: Compositional Cost Analysis via Graded Modalities." arXiv:2512.06952, December 2025. Preprint. Abstract resource lattice; graded feasibility modality with co-unit and monotonicity; presheaf model.

[Mannucci Thuro 2026 preprint] "Resource-Bounded Martin-Löf Type Theory: Compositional Cost Analysis for Dependent Types." arXiv:2601.10772, January 2026. Preprint. Dependent-type extension of [Mannucci Thuro 2025].

### Capability-async / Spritely / OCapN

[Miller 2006] (foundational) "Robust Composition: Towards a Unified Approach to Access Control and Concurrency Control." Johns Hopkins PhD thesis. The capability-async manifesto.

[Spritely 2024–2025] OCapN protocol documentation; CapTP layer; third-party handoffs; NLnet-funded standardization; 2024 inter-implementation interoperability success. https://spritely.institute/news/ ; https://github.com/ocapn/ocapn

### Trait / refinement composition

[Generic Refinement Types POPL 2025] "Generic Refinement Types." POPL 2025. Peer-reviewed. Modular higher-order specifications abstracting invariants over function contracts; Rust-trait integration.

[Boolean-Algebraic Subtyping POPL 2026] "The Simple Essence of Boolean-Algebraic Subtyping: Semantic Soundness for Algebraic Union, Intersection, Negation, and Equi-recursive Types." POPL 2026. Peer-reviewed.

### Auxiliary — historical context for the live controversy

[Scalas Yoshida 2019] Scalas, Alceste; Yoshida, Nobuko. "Less is More: Multiparty Session Types Revisited." POPL 2019 PACMPL, doi:10.1145/3290343. The original disclosure of broken proofs in classical MPST.

[Honda Yoshida Carbone 2008] Honda, Kohei; Yoshida, Nobuko; Carbone, Marco. "Multiparty Asynchronous Session Types." POPL 2008. The original MPST paper.

[Honda Yoshida Carbone 2016] (journal version) "Multiparty Asynchronous Session Types." Journal of the ACM 63(1), doi:10.1145/2827695, 2016.

---

## Part V — Synthesis: Multi-Party Protocols as Polynomial Functors over a Quantale-Valued Propagator Runtime

The eight slices that precede this chapter were written without arguing the architectural target. Each surveyed its slice with rigor and stayed within its mandate, by design. This chapter is the place where the assembled evidence is read against the user's architectural commitments, with the heavy lean made explicit and defended.

The architectural target the chapter argues:

> **A multi-party protocol is a polynomial functor `P : C → C` in a locally cartesian closed category — the dependent type theory's denotational setting. Its positions are the protocol's branching choices; its directions are the participants and the data flowing in each branch, with `B(a) = Π_{r ∈ Roles} B_r(a)` factoring per-role. Composition of protocols is the polynomial-functor composition product (Spivak-Niu §5), associative with unit and respecting bicategorical structure — this IS conjunctive refinement at the protocol level, not projection-with-merge. Each role's local view is an opcartesian lift in a fibration over the participant lattice — categorical, universal, sound by construction. Behaviour is a coalgebra for the polynomial functor — a state `s` together with `s → P(s)` — whose realizability is a quantale-valued fixpoint computation in the propagator network. Cost-aware reasoning over latency, message count, fairness deadline, and resource consumption is supplied by the tropical-quantale layer already in place on Prologos cells.**

The chapter has seven subsections. §V.1 restates the diagnostic of why current MPST foundations are not firm enough to build on, in language that links the broken-proofs cascade and the OO-inheritance critique to one structural source. §V.2 develops the positive case: polynomial-functor composition product is conjunctive refinement at the protocol level, and the merge operator's algebraic deficiencies disappear because there is no merge. §V.3 makes role projection-as-opcartesian-lift precise. §V.4 sketches the quantale-valued realizability picture as a fixpoint computation on the existing propagator network. §V.5 shows that multi-party participation falls out of binary session types augmented with dependent types in continuation positions, via the polynomial universes work. §V.6 enumerates the eight gaps in the published 2024–2026 literature that the architecture addresses simultaneously. §V.7 reads the architectural argument against the evidence with calibrated honesty: where the case is settled, where it is supported, where it remains hypothesis-level work for the design tracks.

### V.1 The diagnostic, restated

The 2019 reckoning [Scalas-Yoshida 2019] established that subject-reduction proofs in much of the published multi-party-session-type literature are unsound under full merge. The 2023 CAV result [Li-Stutz-Wies-Zufferey 2023] established that "existing practical projection operators are all incomplete (or unsound)" — independently of which proof technique is used to certify them. The 2024 *Less is More Revisited* paper [Hou-Yoshida-Kuhn 2024] supplies a repair (the *association* invariant) for the proof-correctness side, but does not address the structural-completeness critique. As of 2026, four distinct repair strategies coexist in the literature: fix-the-proof (Hou-Yoshida-Kuhn 2024); eliminate-projection-entirely (Scalas-Yoshida 2019; Castro-Perez-Ferreira-Jongmans POPL 2026); replace syntactic projection with automata-theoretic synthesis (Stutz et al. CAV 2023); add Coq mechanisation as a forcing function (Tirore-Bengtson-Carbone ECOOP 2025; Ekici-Kamegai-Yoshida ITP 2025). The community has not converged.

The cumulative pattern indicates that the classical decomposition is overspecified. The diagnostic of slice §II.4 makes the structural source precise: projection-with-merge is multiple-inheritance-with-MRO at the protocol level. The correspondence is not analogical; it is exact. Global type → superclass; per-role projection → method-table specialised per subclass; merge → method-resolution-order linearisation; "non-projectable global type" → "cannot resolve method." Both merge and MRO are *ad-hoc partial reconciliation operators making conventional choices that are not algebraically forced* (depth-first vs. breadth-first; plain merge vs. full merge; left-to-right vs. right-to-left). When the conventional choice produces a deterministic answer, the framework works; when it does not, the framework rejects protocols that are operationally implementable. The 2023 CAV odd-even-protocol counterexample [Li-Stutz-Wies-Zufferey 2023] is the operational symptom: a role's correct local automaton requires information that is not a syntactic substructure of the global type, so syntactic projection cannot produce it, regardless of which merge variant one chooses.

The merge operator's three concrete algebraic deficiencies are what make this brittleness inevitable, per slice §II.3: merge is partial within its claimed domain (some pairs of branch projections have no merge, in any merge variant); merge is not associative in three-way cases (the result depends on parenthesisation in cases where the merge of one pair is undefined while the merge of a different pair over the same operands might be defined); merge has no clean idempotent or unit structure. These three failures are the algebraic core of the brittleness. Merge is not a join in any meaningful sense; it is an *ad-hoc partial operation that pretends to be a join*. When it succeeds, type safety follows; when it fails, the framework does not gracefully degrade. There is no lattice-theoretic operator whose properties projection-with-merge approximates; there is only the operator's syntactic behaviour, with the safety theorems stitched on around it.

A field whose foundational operator does not have proper algebraic structure cannot be built on stably. This is the condition the user's "code smell" intuition identified. The intuition is correct; the diagnosis can now be made precise.

### V.2 Polynomial-functor composition product: conjunctive refinement at the protocol level

The structural answer to the merge problem is to recognise that protocol composition should be conjunctive refinement, not view reconciliation. Conjunction has the algebraic properties merge does not: associative, commutative, idempotent, with a top element (true / no constraint) and bottom (false / contradictory constraints). It is a meet operation on a join-semilattice (and in fact a full lattice with the right structure). This is the structurally-correct algebraic answer to the question merge is a partial answer to.

The Prolog precedent is direct (slice §IV.7.1): a clause body is a conjunction of goals; composition by adding goals to a body is structure-preserving by construction. The Concurrent Constraint Programming formalisation [Saraswat-Rinard-Panangaden 1991] makes this precise at the concurrent level: parallel composition of cc agents is intersection of fixed-point sets of closure operators on the constraint lattice, which is meet in the operator lattice. Soft CCP [Bistarelli-Montanari-Rossi 1997, 2006] generalises to quantale-graded conjunctive composition. The Prologos trait/bundle system instantiates this at the type-system level: bundles compose traits by conjunction, the trait resolver is sound under conjunctive composition, and there is no MRO linearisation because there is no inheritance tree to linearise.

The categorical machinery that lifts this from the trait level to multi-party protocols is the polynomial-functor composition product, per slice §IV.5.4. Given polynomial functors `P(y) = Σ_{a:A_P} y^{B_P(a)}` and `Q(y) = Σ_{a:A_Q} y^{B_Q(a)}`, the composition product `P ◇ Q` is the polynomial functor whose positions are pairs `(a, f : B_P(a) → A_Q)` and whose directions at position `(a, f)` are `Σ_{b ∈ B_P(a)} B_Q(f(b))`. The operational reading: "do `P`, branching to position `a`; then for each direction `b` that `P` exposed, do a `Q`-protocol whose position depends on which `b` was taken." It is associative with a unit (the identity polynomial `y`); it respects bicategorical structure (the composition product is the 1-cell composition of the polynomial-functor bicategory; lenses are the 2-cells; per slice §IV.5.5 and the Spivak-Niu monograph). The Aberlé-Spivak polynomial-universes corpus [Aberlé-Spivak 2025 MFPS XLI, arXiv:2409.19176] establishes that closure of a univalent polynomial universe under Π types automatically produces the distributive law in HoTT — a strictly cleaner statement than the tricategorical machinery [Awodey-Newstead 2018] previously required.

A genuine structural caveat must be flagged before the protocol-level identification: the polynomial-functor composition product `◇` is *associative and unital* but *not commutative* in general (`P ◇ Q ≠ Q ◇ P`). Conjunctive composition in the trait/Prolog/CCP lineage is commutative-meet, not non-commutative monoidal. The two are not the same algebraic structure; what they share is the *coherence-by-construction* property that distinguishes them from ad-hoc partial reconciliation operators like merge. Slice §IV.7.9's unification table lists five distinct categorical settings (residuated lattice, quantale, Heyting algebra, frame, meet-semilattice) under the heading "common structural theme" rather than "single algebraic structure"; the synthesis chapter follows that calibration. The protocol-level identification is therefore: composing protocol `P` with protocol `Q` is *categorically realised by* `P ◇ Q`, with the order-of-composition encoding sequential dataflow (which `Q`-protocol depends on which `P`-direction was taken) — a feature for protocol composition rather than a bug. Where commutative-meet conjunction is wanted (e.g., trait-style intersection of behavioural constraints with no order-of-imposition dependence), the symmetric-monoidal-subcategory fragment of `Poly` provides it; this is the categorical content of MCC's symmetric n-ary coherence (slice §III.6, Carbone-Lindley-Montesi-Schürmann-Wadler 2016).

The merge operator does not appear because there is no merge to compute. Composition does not require reconciling divergent role-views, because the protocol IS the polynomial functor, and role-views are *derived from it* (per §V.3) rather than being primitive objects whose compatibility must be enforced post-hoc. Where the projection-with-merge architecture treats the global type as a *source of truth from which views are projected and then reconciled*, the polynomial-functor architecture treats the polynomial functor as *the protocol itself*, with views being categorical projections (universal lifts) that compose by the same composition product. The change is from view-reconciliation as a primitive operation to view-derivation as a categorical universal.

The unifying claim of slice §IV.7.9, restated honestly: trait-bundle conjunction, polynomial-functor composition product, conjunctive role-projection in a fibration, CCP closure-operator parallel composition, and Prolog clause-body conjunction share a *common structural theme* — composition by structure-preserving algebraic operation in a setting with the right coherence properties (residuated, Heyting, frame, quantale, polynomial-functor-bicategorical, etc.). They are not all the same algebraic structure (the commutativity differences alone preclude that), but the design tracks have a precise question to investigate: which categorical setting best fits multi-party-protocol composition, and which functor relates trait-level commutative-meet conjunction to protocol-level non-commutative monoidal composition. The Prologos trait system instantiates the commutative-meet setting at the type-system level; the polynomial-functor framework is a candidate setting for the protocol level; the relation between them is design-track work.

### V.3 Role projection as opcartesian lift in a fibration

If protocols are polynomial functors `P` and the directions factor per role as `B(a) = Π_{r ∈ Roles} B_r(a)`, then each role `r`'s local view is the polynomial functor `P_r(y) = Σ_{a : A} y^{B_r(a)}` obtained by projecting the directions onto the `r`-component. This projection is not an ad-hoc partial function in the projection-with-merge tradition; it is an *opcartesian lift in a fibration over the participant lattice*.

The base category is committed to be the *powerset lattice of participants ordered by inclusion* — the simplest concrete choice consistent with the architectural target. Refinement orders or richer participant lattices remain a design-track parameter; the synthesis chapter argues the structure on the powerset case and flags the generalisation. The fibres are per-participant-set behavioural-type spaces — categories of polynomial functors whose direction-sets are indexed by the chosen participant set. A morphism in the base category (participant-set inclusion `R ⊆ R'`) induces a functor between fibres; the lift of a polynomial functor across this inclusion is, where it exists, the opcartesian lift characterised by a universal property.

A real existence question must be flagged. Slice §IV.7.8 noted that opcartesian lifts (the colimit-side universal extensions of an `R`-spec up to an `R'`-spec) do not in general exist universally for behavioural specifications without further structure. The question is whether the fibration of polynomial functors over the participant powerset has opcartesian lifts for the morphisms that role projection requires. The structural reason to expect it does, in the case at hand: the lift extends a polynomial functor's direction-set from `B_R(a) = Π_{r ∈ R} B_r(a)` to `B_{R'}(a) = Π_{r' ∈ R'} B_{r'}(a)` for `R ⊆ R'`, which is a coproduct extension along the participant-set inclusion. Slice §IV.5.5 and the Spivak-Niu bicategorical-with-lenses framework supply the categorical machinery; whether the existence theorem goes through unconditionally for the LCCC over which Prologos's dependent type theory denotes is open, and is design-track work. There is also a direction question: cartesian lifts (meet side) are the algebraically-cleaner choice for some readings of conjunctive composition, with opcartesian lifts (colimit side) being the natural choice for view-derivation. The synthesis chapter takes the opcartesian-lift view because the user-facing operation is "extend a small protocol to one involving more participants" rather than "restrict a large protocol to fewer participants." The design tracks must verify the lifts exist with the structure required.

A signature concern must also be addressed. Conjunctive composition usually means *more constraint*; meet of role-sets (set intersection) means *fewer participants*. These are not the same direction. The architectural target's resolution is that conjunctive composition operates on *protocols* (polynomial functors), while role-set inclusion operates on *participation*; the two are orthogonal. Composing two protocols `P_{R_1} ◇ Q_{R_2}` produces a protocol on the *union* `R_1 ∪ R_2` of participants — more constraint, more participants — with the per-role direction factoring providing the per-role views. Role projection then restricts to subsets via opcartesian lifts in the opposite direction (small → large; restriction to a subset of participants is a different categorical operation, naturally the cartesian-lift dual). The two compose without conflict when the categorical setting is set up correctly, but the setting must be set up correctly; this is design-track work.

Compatibility — the property that a multi-party protocol's per-role views *agree* in the sense that there exists an upstairs polynomial functor whose lifts produce them — is the polynomial-functor-level analogue of MCC's coherence relation [Carbone-Lindley-Montesi-Schürmann-Wadler 2016] (slice §III.6). The symmetric-monoidal-subcategory fragment of the polynomial-functor bicategory is where MCC's commutative n-ary coherence lives; the full bicategory generalises to non-symmetric monoidal cases where ordering matters (e.g., when one role's later behaviour depends on another role's earlier choice). The merge operator does not appear because two roles' views are not reconciled — they are *derived from* a polynomial functor whose existence is the upstairs question. Where projection-with-merge tries to *reconstruct* the upstairs from arbitrary projections, the polynomial-functor framework treats the upstairs as primary and the views as derived.

This shift moves the load-bearing question from "can these views be merged" (an ad-hoc partial-operation question, as we have seen) to "does this polynomial functor's directions factor cleanly over the participant lattice" (a structural property of the polynomial functor itself). The structural property is preserved by the polynomial-functor composition product: if `P` and `Q` each factor cleanly, so does `P ◇ Q`. Conjunctive composition therefore preserves coherence by construction; coherence is a property of the polynomial functor, not of the role-views one might project from it. This is what slice §III.6 calls "coherence as the symmetric-monoidal-subcategory fragment of Poly" formalised; the published n-ary-coherence framing of MCC is the syntactic linear-logic shadow of this categorical structure.

The relation to choreographic programming is direct (slice §III.8). Choreographic programming projects a global protocol onto per-party endpoint code; in the framework here, this projection is the opcartesian lift made explicit at the language level. Pirouette [Hirsch-Garg POPL 2022], λ_QC [Samuelson-Hirsch-Cecchetti OOPSLA 2025], ChoRus, HasChor, and Ozone each independently approximate this picture by language-engineering means — first-class location-set polymorphism, modal-type-theory translations, location-as-modality, out-of-order semantics — but none of these works formulates projection as a categorical universal. The polynomial-functor framework supplies the categorical content; the choreographic-programming line supplies the operational and engineering experience that proves the picture is implementable.

### V.4 Quantale-valued realizability as a propagator-network fixpoint

Behaviour, in the architectural target, is a coalgebra for the polynomial functor: a state `s` with structure map `s → P(s)`. This is the polynomial-functor-level generalisation of session coalgebras [Keizer-Basold-Pérez 2020] (slice §I.5), upgraded to multi-party via the per-role-direction factoring of §V.3. The synthetic-MPST move [Castro-Perez-Ferreira-Jongmans POPL 2026] (slice §III.1) is realised structurally: processes are typed against the coalgebra of the protocol directly, no projection step intervening. Each role's process is a coalgebra-morphism into the appropriate fibre's coalgebra, with the categorical universal property of the opcartesian lift guaranteeing that the morphisms compose into a coherent upstairs implementation.

Realizability acquires its quantitative content from quantale enrichment, per slice §IV.6. The classical session-types-as-linear-logic-propositions correspondence [Caires-Pfenning 2010, Wadler 2012/2014, Pfenning-Griffith 2015] (slice §I.2) lives natively in a quantale: linear logic's phase semantics IS quantale-valued, by Yetter 1990's representation theorem. The cut rule is multiplication in the quantale; the residuated `A ⊸ B` is the right adjoint to `A ⊗ −`. Adding tropical structure — the Lawvere quantale `T = ([0,∞], inf, +)` — gives every protocol composition a cost; costs compose by the quantale's monoidal structure. This is a strict generalisation of the linear-logic correspondence with no extra metatheory required; the algebraic structure is already in the quantale.

The Prologos infrastructure realises this operationally. The propagator network already computes lattice-valued fixpoints; tropical-quantale-valued is a special case (the PPN 4C tropical addendum, 2026-04-26). The effect-ordering quantale (set-union over `eff-edge` accumulation lattice + transitive-closure propagator, from Architecture A+D) handles n-ary causal ordering and is operationally already a quantale. The realizability question for a multi-party protocol — "is there a coalgebra inhabiting this polynomial functor within budget B?" — becomes a fixpoint computation in the propagator network: install propagators that compute the coalgebra-existence constraint, run BSP rounds, terminate at quiescence; the answer is the value at the budget cell. Pareto-style reasoning over multiple cost dimensions (latency, message count, protocol depth, fairness deadline) follows automatically from the product quantale `T × T × T × ...`; the lattice meet on the product quantale is component-wise, and the BSP-monotone propagator network handles the join-semilattice computation natively.

The technology stack to make this rigorous is in place, per slice §IV.6.4: Bacci-Mardare-Panangaden-Plotkin 2023 (Lawvere-quantale propositional logic) supplies the quantitative reasoning machinery; Beohar-Gurke-König-Messing-Forster-Schröder-Wild STACS 2024 (quantale-valued logics for coalgebras) supplies the coalgebraic-quantitative bisimulation theorems via Galois-connection-induced fixpoint preservation; Goncharov-Hofmann-Nora-Schröder-Wild FoSSaCS 2023 (Kantorovich functors) supplies the canonical lifting of metric structure through behaviour functors; Kurz CALCO 2025 (uniform type constructors on quantale-enriched categories) supplies the type-theoretic side; Dahlqvist-Neves 2022 supplies the autonomous categories enriched over generalised metric spaces. The synthesis is the recognition that combining these with the polynomial-functor + propagator-substrate framework gives cost-aware multi-party protocol realizability as a single fixpoint computation; nobody currently has this combination in the published literature.

The decidability frontier (slice §III.3, §V.7) requires careful unpacking. Asynchronous session *subtyping* — the question of whether implementation `A` can replace specification `B` when both are session types — is undecidable in the general case [Bravetti-Carbone-Zavattaro 2017]. Bounded-budget realizability — the question of whether some implementation exists for a given protocol within budget `B` — is a different question on the same algebraic substrate: existence-of-witness rather than relation-between-specifications. The two are not the same problem, and the architectural target's claim is more modest than "we recover the undecidability result by unbounded budget"; rather, it is that *bounded-budget realizability* is a tractable surface for the design tracks, with the bound determined by the tropical-quantale grading. The relationship between these problems and asynchronous-subtyping decidability is itself a design-track question — Lange-Yoshida's k-MC PSPACE-completeness [Lange-Yoshida 2019 CAV] suggests that bounded-by-buffer fragments of subtyping are tractable too, and the conjecture worth testing is that quantale-graded subtyping admits decidable fragments under tropical bounds. The chapter does not claim the two problems collapse onto one undecidability; the design tracks investigate the relationship.

### V.5 Multi-party from binary plus dependent-types-in-continuation: the candidate structural identification

This subsection argues a candidate structural identification, not a derived theorem. The phrasing throughout reflects the calibrated reading: H5 in §V.7 is "plausibly supported but not demonstrated," and §V.5 develops the supporting case, the open verification questions, and what design-track work would establish or refute the candidate.

The user's compositional-surprise observation — that session types compose in Prologos because they are first-class types-as-terms, with one session type appearing in the continuation of another — has a candidate structural counterpart in the polynomial-functor framework. Polynomials in an LCCC carry Σ and Π adjoints to weakening, per the polynomial-universes work [Awodey-Hofmann-Streicher-Spivak; Aberlé-Spivak 2025 MFPS XLI]. The architectural target's hypothesis is that this means dependent types in continuation positions are structurally available with no additional language machinery, and that the multi-party generalisation falls out of the same Σ/Π-adjoint structure.

The binary-case grounding is established. Toninho-Caires-Pfenning's *Dependent Session Types via Intuitionistic Linear Type Theory* [Toninho-Caires-Pfenning 2011 PPDP] formalised that receive-types are Π-types and send-types are Σ-types in the binary case. Sax / semi-axiomatic sequent calculus [Pfenning-DeYoung] generalises this to asynchronous message-passing with shared-memory bisimilar semantics. The Prologos binary-session-type implementation inherits this; a session type can name a dependent function type whose codomain depends on the value previously communicated, and this is operational in the binary case.

The candidate generalisation: a protocol that branches on a value sent by role `p` gives the polynomial functor's directions a value-dependent shape `B(a) = Π_{r ∈ Roles} B_r(a, v)`, where `v` is the value carried at position `a`. The hypothesis is that the per-role direction factoring is preserved by the polynomial-functor composition product `◇`, so that composing two such protocols produces a protocol whose per-role direction factoring is the appropriate composite. The supporting case: the LCCC's Σ/Π adjoints distribute over composition product (this is what makes polynomial-universes work in HoTT [Aberlé-Spivak 2025]); the per-role projection `B_r(a, v)` is itself a polynomial-functor's direction-set; the composition product preserves direction-set structure (per slice §IV.5.4's explicit formula). What is *not* yet shown in the published literature is that the per-role direction factoring `B(a) = Π_{r ∈ Roles} B_r(a, v)` is *itself* preserved as a factored form under composition — this is the central unverified piece (per §V.7 H5). The design tracks must produce the formal proof.

The structural relation to existing work helps locate the candidate. λ_QC's first-class location-set polymorphism [Samuelson-Hirsch-Cecchetti OOPSLA 2025] achieves operationally what dependent types in continuation positions would deliver structurally — the ability to compute who participates next from the data flowing through the protocol. λ_QC arrives at this through bespoke type-system engineering and Rocq mechanisation; the architectural target's hypothesis is that the same operational result follows from a more economical structural commitment (the Σ/Π adjoints in the LCCC the dependent type theory already inhabits). If the per-role direction factoring is preserved by composition, the architectural target is *strictly more general* than λ_QC because it handles arbitrary dependent participation patterns rather than only first-class location-set polymorphism. If the per-role direction factoring is *not* preserved (the design tracks find a counterexample), the architectural target requires a richer participant-lattice machinery and the case for "subsumes choreographic programming" weakens correspondingly.

The architectural payoff, *conditional on the verification going through*: multi-party participation would be a *consequence* of binary session types augmented with dependent types in continuation positions, not a separate feature requiring its own machinery. The Prologos design did not pre-commit to multi-party; the hypothesis is that multi-party is what the existing infrastructure already carries when the dependent-type-theoretic substrate is taken seriously and the polynomial-functor structure is recognised. The Network Type Theory [NTT — designed but not yet implemented] is the natural place for the categorical machinery to live: protocol primitives would become NTT specifications, and "multi-party session types" a library written in NTT, the way "binary session types" already is. The verification question — does the per-role direction factoring survive composition? — is design-track scope.

If the verification goes through, the polynomial-functor framework would unify binary session types, multi-party session types, choreographic programming, and dependent session types under a single composition operation. If the verification does not go through, the framework would still cover binary plus multi-party-with-fixed-participation cleanly, with dependent participation requiring richer infrastructure. Either outcome is a tractable design-track result; neither outcome is settled by the synthesis chapter.

### V.6 Eight gaps the architecture addresses

The frontier scan of slice §VI.8 catalogued eight specific gaps in the published 2024–2026 literature that the architectural target addresses simultaneously. The synthesis chapter restates them with project-relevance framing.

**Gap (a) — Multi-party session types as polynomial functors over LCCC.** No published 2024–2026 work formulates multi-party session types as polynomial functors in dependent type theory. The closest works approach from non-MPST directions: Niu-Spivak's interaction-theoretic polynomial functors, Aberlé-Spivak's polynomial universes in HoTT, Grodin's polynomial-functor effect handlers. Each supplies categorical machinery; none supplies the multi-party-session-type identification. The architectural target makes the identification.

**Gap (b) — Role projection as opcartesian fibration lift.** Synthetic MPST and AMP each escape projection-with-merge but in operational rather than categorical ways. No published work formulates role projection as a categorical universal-property construction in a fibration over the participant lattice. The architectural target supplies the categorical content the published escape routes operationally approximate.

**Gap (c) — Conjunctive refinement as protocol composition.** Despite the well-developed CCP-quantale literature (slice §IV.7) and the trait-system literature, no published session-type work uses conjunctive refinement as the primary composition operation. The field went projection-first. The architectural target restores conjunctive refinement to the protocol level, with polynomial-functor composition product as its categorical realisation.

**Gap (d) — Cost-aware multi-party protocols.** No published multi-party-session-type framework has cost-aware realizability as a primary feature. The tropical-quantale-graded extension is missing. The architectural target supplies it via the existing Prologos cost layer (PPN 4C addendum).

**Gap (e) — Multi-party from binary via dependent-type-in-continuation.** No published work shows that multi-party falls out of binary session types augmented with dependent types in continuation positions. The closest (λ_QC's first-class location-set polymorphism) achieves this in choreographic programming but not as a structural consequence of the type theory. The architectural target shows the structural consequence: the polynomial-functor's per-role direction factoring is preserved by composition, and dependent types in continuation positions are structurally available via Σ/Π adjoints in the LCCC.

**Gap (f) — Trait-bundle / protocol-bundle algebra unification.** No published work treats trait-bundles and protocol-bundles as instances of the same conjunctive-composition algebra. The Prologos design implicitly does so; the unifying claim of slice §IV.7.9 makes it precise; the architectural target makes it explicit and structurally underwritten by the polynomial-functor framework.

**Gap (g) — NTT-style declarative spec for multi-party protocols.** No published work has a declarative specification language analogous to NTT where multi-party protocols are specified at the same layer as the propagator-network architecture they run on. NTT itself is designed but not yet implemented; once implemented, multi-party-session-type primitives become NTT library content rather than language extensions.

**Gap (h) — Multi-party via propagator-network coalgebraic inhabitation.** No published work uses a propagator-network substrate for multi-party-session-type checking. The architectural target's "realizability as a fixpoint computation in the propagator network" supplies this; the propagator infrastructure is already operationally a coalgebra-existence checker for monotone behaviours.

The architectural target addresses gaps (a)–(h) simultaneously because they are all consequences of the same structural commitment: protocols are polynomial functors over LCCC, composition is conjunctive refinement realised by the composition product, role projection is opcartesian lift in a fibration, behaviour is coalgebraic, realizability is quantale-valued, the operational substrate is the propagator network. Each gap follows from one or more of these commitments; addressing them in isolation would not be possible because they are not independent.

### V.7 Reading the architectural argument against the evidence

The architectural argument admits five formulations of decreasing strength.

A note on the hostile-reviewer move that anticipates the *Less is More Revisited* repair (Hou-Yoshida-Kuhn 2024 [HYK 2024]) before the H1–H5 ladder. The community position the chapter must respond to is: "the broken-proofs cascade was specific to *full* merge; HYK's *association* invariant repairs subject reduction within the projection-with-merge architecture; treating projection-with-merge as structurally broken treats a research-active design parameter as a structural defect." The chapter's response runs through three points. First, the 2023 CAV completeness result [Li-Stutz-Wies-Zufferey 2023] is *independent of proof technique*: "existing practical projection operators are all incomplete (or unsound)" applies regardless of which invariant is used to certify subject reduction; HYK 2024's repair addresses the soundness side, not the completeness side, and the odd-even-protocol counterexample exhibits an implementable protocol that no syntactic projection (under any merge variant or association repair) can produce. Second, the OO-inheritance critique (slice §II.4) is about the *operator's algebra*, not its provability under any particular invariant: merge is partial and non-associative because the operation it tries to be (a join in a behavioural-type lattice) does not exist with the right structure; this is a fact about merge, not a fact about which invariant proves subject reduction. Third, even granting HYK's repair on the soundness side, the architectural cost is real: HYK's association invariant adds a new layer of metatheory to the projection-with-merge architecture rather than removing the projection step. The architectural target's gain is in *eliminating projection from the operational primitive set*, not in repairing it; the case for the gain rests on what is unlocked (cost-aware realizability, conjunctive composition, the polynomial-functor unifying picture), which the chapter's body has argued. The hostile reviewer's move shows that the diagnostic of §V.1 is not a knock-out punch — it is the supporting argument that motivates a paradigm change whose case must be made on what the change unlocks. The chapter's posture is that the case is sufficient, not that the diagnostic alone is decisive.

**(H1) Protocol composition is conjunctive refinement, not view reconciliation, on algebraic-soundness grounds.** *Settled.* The merge operator's three concrete algebraic deficiencies (slice §II.3) — partiality, non-associativity in three-way cases, no clean idempotent / unit structure — are documented in the published literature; the OO-inheritance correspondence (slice §II.4) explains why the same defects recur across both projection-with-merge and multiple-inheritance MRO; the Schärli-Ducasse-Nierstrasz-Black trait paper [Schärli et al. 2003] is the precedent that conjunction restores the lattice operation MRO failed to be. The argument that the same move applies at the protocol level rests on identifying conjunction as the meet operation in a residuated/Heyting/frame/quantale setting and observing that the same algebraic structure governs both cases; this identification is direct, not speculative.

**(H2) Polynomial-functor composition product is the categorical realisation of conjunctive refinement at the protocol level.** *Strongly supported.* The Spivak-Niu monograph [Niu-Spivak 2024] establishes the composition-product structure formally; the explicit positional formula `(a, f : B_P(a) → A_Q)` with directions `Σ_{b ∈ B_P(a)} B_Q(f(b))` supplies the operational reading; the bicategorical structure (slice §IV.5.5) ensures associativity and unit. The MCC coherence-as-n-ary-duality framing [Carbone-Lindley-Montesi-Schürmann-Wadler 2016] is the syntactic linear-logic shadow of this categorical structure (slice §III.6). What is not yet demonstrated, and is design-track work, is that the implementation of polynomial-functor protocol composition on the propagator network is performant under realistic load.

**(H3) Polynomial functors over LCCC are the right denotational setting for multi-party protocols, with role projection as opcartesian lift in a fibration over the participant lattice.** *Supported with caveats.* The polynomial-universes work [Aberlé-Spivak 2025; Awodey-Hofmann-Streicher-Spivak] establishes the categorical machinery; session coalgebras [Keizer-Basold-Pérez 2020] establish the binary-case grounding; the choreographic-programming line (slice §III.8) provides the operational evidence that role projection is implementable. The caveats are that no published work formulates multi-party session types in this framework directly (gap (a) of §V.6), and the soundness argument that conjunctive composition preserves opcartesian-lift coherence is structurally clean but not formalised in the published literature. The design tracks must produce that formalisation.

**(H4) Realizability as a quantale-valued fixpoint computation in the propagator network is a strict generalisation of the existing soundness machinery, with cost-awareness coming for free.** *Plausibly supported but not demonstrated.* The technology stack (Bacci-Mardare-Panangaden-Plotkin 2023, Beohar et al. STACS 2024, Goncharov et al. FoSSaCS 2023, Kurz CALCO 2025, Dahlqvist-Neves 2022) is in place; the Prologos infrastructure (effect-ordering quantale, tropical-quantale cost layer) is in place. What is not in place is the demonstration that combining them yields a working multi-party protocol realizer — that is design-track work. The strongest counter-argument a hostile reader could mount is that the combination of components might not compose cleanly in practice (the König et al. 2024 compositionality result for Kantorovich lifting under functor composition does not, by itself, guarantee that polynomial-functor lifting preserves the right structure); the architectural target's claim is that the structural pieces fit; the design tracks must verify they fit operationally.

**(H5) Multi-party participation falls out of binary session types augmented with dependent types in continuation positions.** *Plausibly supported but not demonstrated.* The Σ/Π-adjoints-as-dependent-send/receive identity is fully formalised for the binary case [Toninho-Caires-Pfenning 2011]; the polynomial-universes work establishes that the LCCC's Σ/Π adjoints are exactly what is needed; λ_QC [Samuelson-Hirsch-Cecchetti OOPSLA 2025] achieves first-class location-set polymorphism operationally. The structural claim — that the per-role direction factoring `B(a) = Π_{r ∈ Roles} B_r(a, v)` is preserved by the polynomial-functor composition product — is not yet in the literature and is the central unverified piece. The design tracks must produce the formal proof; if the proof goes through, the architectural target is confirmed; if it does not, a structural fallback (e.g., requiring richer participant-lattice machinery) is available.

The five formulations together constitute the research program the architectural target implies. (H1) and (H2) are settled. (H3) is supported with formalisation work to do. (H4) and (H5) are the genuine frontier hypotheses. The design tracks the project will pursue from this foundation must, severally, produce the evidence that (H3)–(H5) need; the synthesis chapter has assembled the antecedents and identified the gaps, which is what a Stage 0/1 research synthesis can do.

A note on the chapter's posture. The user's framing — *heavy lean on the proposed approach; current MPST does not have a firm-enough foundation to stand on; build on cleaner theoretics* — is well-calibrated for the evidence assembled. The MPST community's twenty-year struggle to repair projection-with-merge is documented and ongoing. The categorical machinery the architectural target draws on (polynomial functors, quantale-enriched LCCC, fibrations, coalgebras) is technically mature and well-developed in adjacent communities. The unifying claim — that these pieces fit together into a coherent multi-party-protocol theory native to the propagator runtime — is the genuine frontier hypothesis the design tracks would test.

The two strongest counter-arguments the chapter has anticipated and accommodated. The first is the "your alternative just relocates the problem" critique: that conjunctive refinement at the protocol level is a categorical concept whose operational realisation might be no easier than projection-with-merge. The chapter's response is that the polynomial-functor composition product *is* the operational realisation, and the propagator-network substrate *is* the runtime that computes it; the relocation is into a setting where the algebra has the right structure (associative, commutative, idempotent meet on a residuated/Heyting/frame/quantale) and the runtime already exists. The second is the "you are smuggling design commitments into a Stage 0/1 synthesis" critique: that the L2 architectural sketch and the implementation pathway should be design-track scope, not research-synthesis content. The chapter's response is that it labels the architectural target *as* a target, not as a settled design — §V.7's calibrated H1–H5 framework is honest about which claims are settled, supported, or hypothesis-level — and that the user's locked answer #6 ("Points for considerations for design hereof is appropriate; specific track commitments would be premature") is the framing the chapter has followed.

The community is openly looking for what comes after projection-with-merge. Five years after the 2019 reckoning, the literature has not converged. The architectural target the chapter has argued — *multi-party protocols as polynomial functors over a quantale-valued propagator runtime, with role projection as opcartesian lifts in a fibration, behaviour as coalgebras, realizability as a quantale-valued fixpoint, and composition as conjunctive refinement realised by the polynomial-functor composition product* — is a candidate for what comes after. The Phase-1 evidence assembled in this artifact is the case that the candidate is well-grounded. The design tracks that follow will, severally, validate or refute the candidate. The synthesis chapter's task — to surface that the candidate is the right one to test — is complete.

---
---

## §VII Sub-Questions for Design Considerations

This part converts the synthesis chapter's arguments into design considerations rather than track commitments — per the user's framing, specific track commitments would be premature given the research is still synthesising the architectural target rather than committing to a design. Each consideration has prerequisites, cross-references to the artifact's evidence, and the open-question shape that the design-track work would address.

### §VII.1 The polynomial-functor protocol primitive

**Working consideration.** Cast multi-party protocols as polynomial functors over the Prologos LCCC. Concretely: define a `Protocol` term constructor in NTT or its eventual implementation, with positions corresponding to branching choices and directions factoring per role.

**Evidence base.** §IV.5 (polynomial functors over LCCC), §IV.5.4 (composition product), §IV.5.6 (Aberlé-Spivak polynomial universes), §V.2.

**Open questions.** (a) Is the polynomial-functor composition product the right composition primitive at the user-facing level, or should the user-facing operation be the symmetric-monoidal fragment (commutative-meet) with the non-commutative composition exposed only when sequential dataflow is explicit? (b) How does the polynomial-functor structure interact with the existing binary-session-type implementation — does the binary case become a special instantiation, or do binary and multi-party live as two layered presentations of the same machinery?

**Prerequisites.** No technical blockers; this is a foundational design consideration that the rest of the architectural target rests on.

### §VII.2 Fibrational role projection

**Working consideration.** Implement role projection as opcartesian lift in a fibration over the participant powerset lattice. Verify the lift exists structurally for the polynomial-functor cases the design requires.

**Evidence base.** §IV.5.5 (polynomial-functor bicategory with lenses), §IV.7.8 (fibrational structure of conjunctive role projection), §V.3.

**Open questions.** (a) Does the opcartesian lift exist universally for the relevant participant-set inclusions, or are there structural obstructions that require richer participant-lattice machinery? (b) Is the powerset lattice the right base, or should the design accommodate refinement orders / labelled-participant lattices for richer composition? (c) How does role projection interact with the polynomial-functor composition product — is the projection of a composed protocol the composition of projections, or is there an additional coherence condition?

**Prerequisites.** Depends on §VII.1.

### §VII.3 Quantale-valued realizability as fixpoint

**Working consideration.** Implement realizability checking for multi-party protocols as a quantale-valued fixpoint computation in the propagator network. Use the existing tropical-quantale cost layer plus the effect-ordering quantale; lift to the product quantale for multi-dimensional cost.

**Evidence base.** §IV.6 (quantale-enriched session types), §V.4, the existing PPN 4C tropical addendum, the existing Architecture A+D effect-ordering system.

**Open questions.** (a) Does the polynomial-functor structure preserve quantale enrichment under composition? (Kantorovich-functor compositionality results [König et al. 2024] are available but the polynomial-functor case is a separate verification.) (b) What is the wire / runtime cost of the quantale-graded metadata? (c) How does the realizability fixpoint interact with the existing BSP propagator-network scheduler — is there a clean termination criterion for the bounded-budget case?

**Prerequisites.** Depends on §VII.1 and §VII.2.

### §VII.4 Dependent types in continuation positions

**Working consideration.** Verify that the per-role direction factoring `B(a) = Π_{r ∈ Roles} B_r(a, v)` is preserved by the polynomial-functor composition product. This is the central H5 verification question.

**Evidence base.** §I.4 (dependent session types, Toninho-Caires-Pfenning 2011), §IV.5.6 (polynomial universes, Σ/Π adjoints), §V.5.

**Open questions.** (a) Is the per-role direction factoring preserved under `◇`, or does composition introduce direction-set structure that breaks the factoring? (b) If preservation fails for some cases, what richer participant-lattice machinery would recover it (e.g., dependent participant sets indexed by the value)? (c) How does this interact with λ_QC's first-class location-set polymorphism — is the architectural target strictly more general, or are there cases λ_QC handles that the architectural target requires extension for?

**Prerequisites.** Depends on §VII.1 and §VII.2.

### §VII.5 Cost-aware multi-party protocols (the unique Prologos contribution)

**Working consideration.** Demonstrate cost-aware multi-party protocol composition as a working feature. Concretely: a protocol carries cost weights at each position; composition propagates cost via the tropical-quantale monoidal product; realizability checks "is there an implementation within budget B?" via the propagator-network fixpoint.

**Evidence base.** §IV.6.6 (quantale-valued realizability over LTS), §V.4, the PPN 4C tropical addendum, slice §VI.7 (recent tropical-PL-semantics).

**Open questions.** (a) Is the cost weighting at the position level expressive enough, or does the design need direction-level cost weighting? (b) How is multi-dimensional cost (latency × message count × fairness × resource) presented at the user-facing level — Pareto frontiers, total order via priority, or per-dimension reasoning? (c) What is the relationship between cost-aware realizability and the asynchronous-subtyping decidability frontier (Bravetti-Carbone-Zavattaro 2017; Lange-Yoshida 2019 k-MC)?

**Prerequisites.** Depends on §VII.3.

### §VII.6 Bundle algebra unification

**Working consideration.** Unify trait bundles and protocol bundles under a common conjunctive-composition algebra. The trait resolver and the protocol resolver share infrastructure for type-level conjunctive composition; the design question is what shape this shared infrastructure takes.

**Evidence base.** §IV.7 (conjunctive composition + bundle algebra), §IV.7.5 (trait bundles as the Prologos realisation), §IV.7.9 (the unifying claim), §V.2.

**Open questions.** (a) What is the precise algebraic theory shared by traits and protocols — meet-semilattice, residuated lattice, Heyting algebra, frame, or polynomial-functor bicategory? (b) Where the categorical settings differ (commutative-meet for traits, non-commutative monoidal for protocols), what is the relating functor? (c) How is the shared infrastructure implemented at the language level — a single resolver that operates on a unified algebra, or two resolvers that share categorical machinery?

**Prerequisites.** Depends on §VII.1; informs both trait-system maintenance and protocol-system design.

### §VII.7 NTT primitives for protocol specification

**Working consideration.** Once NTT is implemented, define multi-party-protocol primitives at the NTT level. "Multi-party session types" becomes a library written in NTT, layered on the categorical machinery the protocol primitives expose.

**Evidence base.** §V.5 (NTT as deployment vector), the NTT design documentation (cross-reference).

**Open questions.** (a) What primitives does NTT need to expose for protocol specifications — polynomial-functor constructors, fibration operations, quantale-enriched cell allocations, coalgebra schemas? (b) Is the protocol-as-NTT-library approach sufficient for user-facing multi-party programming, or does the user-facing surface need additional sugar (binary session-type style notation, choreographic surface compilation)? (c) How does the NTT implementation interact with the existing binary-session-type implementation — replacement, layered, or parallel?

**Prerequisites.** Gates on NTT implementation; the protocol-primitive design considerations precede or parallel NTT primitive design.

### §VII.8 Compilation to choreographic surface for interop

**Working consideration.** As an interoperability path, support compilation from the Prologos polynomial-functor protocol representation to standard choreographic-programming surface syntax (Pirouette / Choral / λ_QC / ChoRus) and to OCapN-style multi-vat protocols. This makes Prologos protocols runnable / verifiable in existing tooling without committing to its theoretical foundations.

**Evidence base.** §III (escape routes), §VI.6 (Spritely / OCapN connection), the companion async research artifact §6.1 (choreographic programming) and §6.2 (Spritely revival).

**Open questions.** (a) Is the compilation lossy — i.e., does projecting to choreographic surface lose information the polynomial-functor representation carries? (b) Do the various choreographic surface targets compose, or must the design commit to one? (c) How does the compilation interact with the cost-aware extension — can tropical cost weights survive the projection to standard choreographic surfaces, or does the cost layer remain Prologos-internal?

**Prerequisites.** Depends on §VII.1.

---


## Bibliography Organisation

Citations are co-located with use: each part (§I through §VI) carries its own *References* subsection at the end, with each citation annotated for its contribution to that part's argument. The synthesis chapter (§V) cites by reference to the part sections rather than carrying its own bibliography. Total citation count across the artifact is approximately 257 distinct references.

For navigation:

- **§I References** — binary session types, linear-logic-as-session-types correspondence, polarised SILL, dependent session types, session coalgebras, higher-order session types (~24 entries).
- **§II References** — classical MPST (Honda-Yoshida-Carbone), broken-proofs cascade, Hou-Yoshida-Kuhn 2024 association repair, Stutz et al. PSM line, asynchronous subtyping decidability, Schärli traits as the OO precedent (~30 entries).
- **§III References** — synthetic MPST (Castro-Perez-Ferreira-Jongmans), AMP / PSM (Stutz et al.), MCC + n-ary coherence (Carbone-Lindley-Montesi-Schürmann-Wadler), choreographic programming categorical content (Pirouette, λ_QC, ChoRus, HasChor, Ozone, Bak-Urschumzew) — ~51 entries across slices 03 and 04.
- **§IV References** — polynomial functors / Spivak-Niu / Aberlé-Spivak polynomial universes / quantale theory (Yetter, Mulvey-Rosenthal, Bacci-Mardare-Panangaden-Plotkin, Beohar et al., Goncharov et al., Kurz, Dahlqvist-Neves) / conjunctive composition (Saraswat-Rinard-Panangaden, Bistarelli-Montanari-Rossi, Schärli, Galatos-Jipsen-Kowalski-Ono) — ~105 entries across slices 05, 06, 07.
- **§VI References** — frontier 2024-2026 scan; recent MPST repair attempts, recent quantale-coalgebraic logic, recent polynomial-functor DTT work, recent choreographic-programming categorical content, OCapN connection, tropical-PL-semantics cross-cuts (~47 entries).

For readers who want a single-author entry point: Saraswat (CCP foundations, §IV.7), Honda-Yoshida-Carbone (MPST origins, §II.1), Scalas-Yoshida (the 2019 reckoning, §II.2), Castro-Perez-Ferreira-Jongmans (synthetic MPST, §III.1), Stutz (PSM / AMP, §II.3 + §III.2), Carbone-Lindley-Montesi-Schürmann-Wadler (n-ary coherence / MCC, §III.6), Spivak-Niu (polynomial functors monograph, §IV.5), Aberlé-Spivak (polynomial universes, §IV.5.6), Yetter (quantales-as-linear-logic, §IV.6.1), Hirsch-Cecchetti (choreographic programming frontier, §III.8 / §VI), Hou-Yoshida-Kuhn (2024 *Less is More Revisited*, §II.5).


---

## §VIII Out-of-Scope Declarations

This part catalogues what the artifact deliberately does not cover, with reasons.

### §VIII.1 Topics excluded by scope decision

**Formal verification of MPST in proof assistants (Coq / Rocq / Agda mechanisations).** The 2024–2026 frontier scan flagged several recent mechanisations (Tirore-Bengtson-Carbone ECOOP 2025; Ekici-Kamegai-Yoshida ITP 2025), and the Castro-Perez-Ferreira-Jongmans synthetic-MPST work uses Agda. The artifact treats these mechanisations only as evidence about the field's state (each surfacing yet-another broken proof); it does not engage with the mechanisation infrastructure itself or argue what a Prologos-side mechanisation would look like.

**Implementation-engineering details of binary session types.** The Prologos binary-session-type implementation (S8a complete) is the working baseline; the artifact does not survey its internals or discuss its evolution path beyond noting that the multi-party design considerations should layer on top of (not replace) the binary infrastructure.

**Specific session-type runtime systems (Multi-OCaml, Scribble-runtime, Pabble).** The artifact treats these as evidence about the field's tooling experience; specific runtime APIs and library architectures are not surveyed.

**Choreography compilers' implementation specifics.** Pirouette / Choral / ChoRus are surveyed for their categorical content (slice §III.8), not their compiler engineering.

**Game semantics for session types (Mellies' asynchronous games and successors).** The companion async research artifact §3.2 covers this lineage extensively; the multi-party extension is touched briefly in slice §III.6's MCC treatment but is not developed independently here.

### §VIII.2 Topics deliberately treated lightly

**Decidability of asynchronous session subtyping.** Per the user's framing (consistent with the companion async research's framing), the decidability frontier is treated lightly. The undecidability theorem (Bravetti-Carbone-Zavattaro 2017) and the k-MC PSPACE-complete fragment (Lange-Yoshida 2019 CAV) are noted as background; the architectural target's bounded-budget realizability is positioned as a tractable surface for the design tracks, with the relationship to subtyping-decidability flagged as a design-track question rather than developed in the synthesis chapter.

**Probabilistic / fuzzy / soft MPST extensions.** Soft CCP (Bistarelli-Montanari-Rossi) is referenced for the conjunctive-composition lineage; the multi-party probabilistic extension is not surveyed beyond noting that the quantale enrichment accommodates probability through the standard `[0, 1]` quantale.

**Quantum protocols and quantum session types.** Mentioned briefly via Ceragioli-Gadducci-Lomurno-Tedeschi 2024 [CGL+24] but not developed.

### §VIII.3 Topics intentionally bounded

**Eras outside 1993–2026.** The artifact's historical coverage starts at Honda 1993 (origin of binary session types) and ends at 2026 (recent peer-reviewed and accepted work). Earlier work (CCS, π-calculus, CSP) is referenced only via cross-references to the companion async research artifact's Era I coverage.

**Frontier coverage at the citation level.** Slice 08 is a frontier scan, not an exhaustive survey. Citations are selected for relevance to the architectural target. Many recent papers are not cited; this reflects the artifact's scope and the fact that some adjacent literatures (e.g., process-algebraic verification, distributed-systems simulation) are not directly bearing on the architectural target.

### §VIII.4 Topics flagged for future research artifacts

**The relationship between Prologos's stratification system and modal type theories for multi-party protocols.** Bak-Urschumzew's CP 2024 work translates Chorλ to MTT; the broader connection between stratified concurrent semantics and multi-modal dependent type theory is worth its own artifact. The connection to the project's `structural-thinking.md` is suggestive.

**Multi-party protocols and federated identity / decentralised authentication.** OCapN's three-vat handoff is structurally a small multi-party choreography; the broader connection to W3C Decentralised Identifiers, self-sovereign identity, and capability-based federation is worth surveying separately.

**Cost-aware multi-party realizability as a verifiable contract language.** The architectural target's quantale-graded realizability has natural applications to smart contracts (cost-bounded execution, fairness guarantees, deadline enforcement). The intersection with Agoric's Hardened JavaScript / SwingSet would be a productive cross-pollination but is outside the artifact's scope.

**Multi-party trait composition: traits with role parameters.** The trait/bundle system handles type-level method requirements; a natural extension is traits parameterised by participant sets, where a trait specifies multi-party protocol obligations. This intersects with §VII.6 but is a separate artifact's worth of design work.
