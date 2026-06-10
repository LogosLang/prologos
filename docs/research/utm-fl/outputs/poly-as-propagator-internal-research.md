# Poly as Propagator — Internal Research Note (engineering-feeding)

**Status**: skeleton v0.1.
**Purpose**: internal research note that ties polynomial-functor categorical structure directly to Prologos implementation and engineering needs. **Not** the external paper draft (that lives at `../paper-drafts/Poly-propagators.md`). This document is a working categorical map for the propagator network's design; it evolves with engineering and stays in `outputs/` indefinitely.

**Parent paper (external)**: `../paper-drafts/Poly-propagators.md` — when this internal note is ready to be reworked for external publication, the rework happens there with a back-reference here.

**Date opened**: 2026-05-08.
**Pattern**: this is the inaugural example of the programme's *internal research notes that feed engineering directly* convention (PROGRAMME.md §10).

---

## 1. What this note is for

The propagator network has no engineering precedence we can copy. Sussman-Radul's original work is small-scale and pedagogical; everything else (LVars, BloomL, dataflow, Petri nets) has different shape. We have to synthesize from outside mathematics — polynomial functors, dependent optics, Galois-connection abstract interpretation, Kan extensions — to ground our engineering principles in correct formal theory.

This note is the working categorical map. It answers questions of the form *"how should this engineering decision look categorically?"* and *"what's the right type-theoretic structure for X?"* When engineering asks, this note answers (or flags the gap). When engineering decides, this note records the resolution.

It is **not** trying to be a publishable paper. The external Poly paper (`../paper-drafts/Poly-propagators.md`) is the polished version of whatever distills out of here.

## 2. Working identifications (engineering-grounded)

The core identifications, stated for engineering use:

- **Cell** ↔ object in the lattice category. Lattice values are the carriers; merge is the join.
- **Propagator** ↔ polynomial functor with positions = read-cells and directions = write-cells. Conditional firing on cell change ↔ the polynomial-functor's branching structure.
- **Galois bridge** ↔ adjoint pair between cells of different lattice domains. Cross-domain composition is monad/comonad-style adjunction at the cell level.
- **LKan / RKan** ↔ inter-stratum machinery. LKan = upward partial-information propagation; RKan = downward demand-driven propagation.
- **Stratification** ↔ partial order over the propagator-network's regions; stratum boundary = controlled non-monotone transition (LRP).
- **Cell hash-cons** ↔ shared sub-objects in the polynomial-functor category.
- **CHAMP-backed persistence** ↔ structural sharing in the indexed-family-of-polynomial-functors category.

## 3. Engineering questions this note answers / will answer

(Populate as engineering surfaces them. Each entry: question → categorical resolution → engineering implication → status.)

- **Q-EP1**: How should heterogeneous Galois bridges compose? Specifically: when a cell in lattice L₁ has a Galois bridge to L₂, and L₂ has a bridge to L₃, what's the categorically-correct composition?
  - *Status*: open. Affects PPN / SRE bridge design.
  - *Candidate answer*: composition of adjunctions; the bridge category should be a (small) 2-category with adjunctions as 1-morphisms.

- **Q-EP2**: When NTT declares a `bridge` form (per `2026-03-22_NTT_SYNTAX_DESIGN.md` §2), what categorical object is it building?
  - *Status*: open. NTT is design-only; this gates NTT implementation.
  - *Candidate answer*: it should construct an adjoint pair (or a Galois connection if monotone-only) between the two lattice categories; the form's body should specify the unit + counit (or the two halves of the connection).

- **Q-EP3**: PReduce wants to compose e-graph rewriting + DPO + tropical-quantale + GoI on the same substrate. Categorically, what kind of object is the "shared substrate" they all operate over?
  - *Status*: open. Gates PReduce architectural sketch (sub-deliverable 0.1 of `2026-05-02_PREDUCE_MASTER`).
  - *Candidate answer*: an adhesive category enriched in tropical-quantales; `2026-04-03_ADHESIVE_CATEGORIES_PARSE_TREES` has the adhesive part; tropical enrichment per `2026-04-21_TROPICAL_QUANTALE_RESEARCH`.

- **Q-EP4**: The "compound element" structure in the lattice variety categorization (`2026-05-08_PROLOGOS_LATTICE_VARIETY_CATEGORIZATION`) — Pi/Sigma/lambda binders breaking distributivity at the binder boundary — what categorical structure expresses this break?
  - *Status*: open. Connects to Paper C variety-optimality work and to Nation-consultation track.
  - *Candidate answer*: dependent polynomial functors (Σ, Π, fibered structure). The binder boundary is the transition from non-dependent to dependent polynomial.

- **Q-EP5**: For each of the 7 NTT forms (Lattice, property, propagator, interface, network, bridge, stratification, exchange), what's the dependent-type signature in the polynomial-functor framework?
  - *Status*: open. Will populate as NTT moves toward implementation.

(More to be added as engineering surfaces them.)

## 4. Categorical answers we've worked out

(Populate as resolutions land.)

- *(Empty initially. Each entry will record: engineering question → categorical resolution → engineering implication → date resolved → consequence in the codebase.)*

## 5. External-mathematics synthesis status

What outside fields we've drawn on, and what's been integrated vs. still being engaged:

- **Polynomial functors (Spivak Poly programme)** — primary categorical framework. Identification with propagators is the core contribution. Niu-Spivak book parsed; AFOSR-talk rhetoric noted as closest precedent for UTM-shape framing.
- **Free lattice algebra (Nation, Freese-Ježek-Nation)** — substrate algebra. Nation in informal weekly conversation. Nation-Paolini I/II/III pulled.
- **Dependent optics (Hedges, Capucci, Myers, Milewski)** — adjacent / overlapping. Q-Poly-1 positioning pass needed before public claim.
- **Galois-connection abstract interpretation (Cousot-Cousot lineage)** — adjacent. Q-Poly-2 positioning pass needed.
- **Kan extensions in computation (Hinze, Rivas-Jaskelioff)** — adjacent.
- **Adhesive categories (Lack-Sobociński, Biondo-Castelnovo-Gadducci)** — for PReduce / DPO; integrated.
- **Tropical / quantale algebra** — for cost-extraction / PReduce; integrated.

## 6. Engineering-feedback log

(Append entries as engineering decisions resolve categorical questions, or vice versa.)

- *(Empty initially.)*

## 7. Forward references

- **External paper**: `../paper-drafts/Poly-propagators.md` — to be reworked from this note when ready.
- **NTT spec**: `docs/tracking/2026-03-22_NTT_SYNTAX_DESIGN.md` — co-evolves with this note.
- **PReduce sketch**: `docs/tracking/2026-05-02_PREDUCE_MASTER.md` — Q-EP3 + Q-EP5 directly feed.
- **Paper A LRP**: `../paper-drafts/A-LRP.md` — Q-EP1 (Galois bridge composition) directly feeds.

## 8. Provenance

- Origin: 2026-05-08 conversation; owner direction to develop Poly research as engineering-feeding draft alongside external paper.
- Companion artifact: `../paper-drafts/Poly-propagators.md` (external).
