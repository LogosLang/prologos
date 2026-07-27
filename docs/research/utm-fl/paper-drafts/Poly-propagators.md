# Paper Poly — Polynomial Functors as Propagators on Lattice-Valued Cells

**Status**: skeleton v0.2.
**Type**: Foundational categorical paper.
**Mode of development**: per owner direction (2026-05-08), develop as a **draft that feeds engineering** while becoming a publishable artifact. The paper-development process functions as a categorical map for the propagator network's design — inverting the usual research → engineering flow. The paper draft is a working document the engineering consults; rework into final-paper form happens at submission time.
**Target venues**: ACT (Applied Category Theory), MFPS, LICS short paper, LMCS.
**Time-to-submit estimate**: 6–9 months for the engineering-feeding draft; final-form submission likely after Paper A0 lands (per owner sequencing 2026-05-08).
**Owner**: TBD.
**Co-authors**: TBD.

---

## 0. Working title alternatives

- *Poly on Lattices: Propagator Networks as Polynomial Functors over Lattice-Valued Cells*
- *Sussman–Radul as Spivak: A Categorical Identification*
- *The Substrate Spivak's Poly Was Looking For*

---

## 1. Headline claim

Sussman–Radul propagators on lattice-valued cells are the polynomial-functor view of computation that Spivak's Poly programme has been seeking a substrate for. We formalize:

- **Cells** as lattice-valued objects in a propagator-network category.
- **Propagators** as polynomial functors over that category, reading from positions (cells) and writing to directions (cells).
- **Galois connections** between cells of different lattice domains as the bridge structure for cross-domain composition.
- **Left/Right Kan extensions** as the inter-stratum machinery for stratified composition.

## 2. Why this identification matters

Spivak's 2022 AFOSR talk asked *"Is Poly the true language of computation?"* without specifying a substrate. The propagator-network literature (Sussman–Radul) develops a substrate without a categorical name. The two literatures have not met. This paper introduces them.

The identification is novel per the round-2 audit in `outputs/free-lattice-utm-parallel.md` (no paper, talk, slide deck, or blog post in the surveyed Poly / dependent-optics / categorical-systems-theory corpus identifies polynomial functors with Sussman–Radul propagators on lattice-valued cells).

## 3. Outline (TBD)

- §1 Introduction — two literatures, one identification.
- §2 Background — Poly and propagators, separately.
- §3 Lattice-valued cells as objects.
- §4 Propagators as polynomial functors — the core identification.
- §5 Galois bridges — cross-domain Galois connections as polynomial-functor morphisms between lattice categories.
- §6 Kan extensions for stratified composition — LKan / RKan as the inter-stratum machinery.
- §7 An example: the LHC type-checker as a Poly diagram.
- §8 Related work — Spivak Poly programme, Hedges / Capucci / Myers categorical-systems-theory, Cousot–Cousot Galois-connection abstract interpretation, Hinze Kan-extension-for-program-optimization.
- §9 Discussion — what this enables (Paper A LRP, Paper B FL substrate).

## 4. Engineering-feeding mode (per owner direction 2026-05-08)

The Poly paper draft is unusual in this programme: it is being developed not just to publish, but to **inform engineering decisions about the propagator network's categorical structure**. Concretely:

- **Working sections** of the draft become design references: when an engineering question arises about how propagators compose, what Galois bridges are categorically, or what LKan/RKan should look like in NTT, the draft provides the categorical answer.
- **Engineering findings feed back** into the draft: when an engineering choice resolves a categorical question (e.g., the right way to compose Galois bridges across heterogeneous lattices), the resolution lands in the draft.
- **NTT design implications** are explicit: each Poly construct becomes a candidate NTT form; the draft and NTT spec evolve together.
- **At publication time**, the draft is reworked into final-paper form — cleaner narrative, less engineering-detail, more polish.

This inverts the usual research-feeds-paper / paper-feeds-academia pattern. Here: paper draft feeds engineering; engineering feeds paper draft; final paper distills the result.

## 5. Open questions blocking this paper

See `../open-questions.md`:
- Q-Poly-1 (dependent-optics overlap; sharper version of the round-2 negative finding).
- Q-Poly-2 (Galois-bridges-as-abstract-interpretation prior art).

## 6. Risk profile

**Medium-low.** Identification is clean. Categorical machinery is established (Spivak Poly, dependent optics, Galois connections, Kan extensions). Novelty is the *synthesis*, not invention of new structure.

Reviewer-vulnerable surfaces:
- "Polynomial functor" has multiple definitions in the literature (Spivak/Niu vs Gambino-Kock vs old set-theoretic definition); we must pick the right one for propagators and defend the choice.
- The cells-as-lattice choice is not strictly required by Sussman–Radul; the original propagator literature is more general. We need to either justify the lattice restriction or generalize the identification.

## 7. Provenance / source material

- `outputs/free-lattice-utm-parallel.md` (round-2 operads + Poly deep dive)
- `outputs/.drafts/free-lattice-utm-parallel-research-operads-poly-deep.md`
- `2026-03-22_CATEGORICAL_FOUNDATIONS_TYPED_PROPAGATOR_NETWORKS.md`
- `2026-03-26_KAN_EXTENSIONS_ATMS_GFP_PARSING.md`
- Niu–Spivak *Polynomial Functors* book (parsed in round-2; zero hits on lattice/propagator terms)
- Spivak *Poly* and operad-of-wiring-diagrams program
