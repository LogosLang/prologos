# UTM-FL Programme Bibliography

Shared references across all programme papers, deduplicated. Status tagging:

- 📖 **read** — full PDF or full HTML body parsed
- 👀 **skimmed** — abstract / TOC / key sections only
- 📝 **cited** — appears in at least one of our outputs / drafts
- ❓ **unread** — flagged but not yet engaged
- ⚠ **contested** — we disagree with or distance from this work

Each entry lists which paper(s) it serves: A0, Poly, A, B, C, X (cross-cutting).

---

## Free-lattice algebra (Paper B core)

- 📖 📝 **Nation, J. B., Paolini, M.** *"Elementary Properties of Free Lattices"* (Forum Math, May 2024; arXiv:2310.03366). [B]
- 👀 📝 **Nation, J. B., Paolini, M.** *"Elementary properties of free lattices II: Decidability of the universal theory"* (arXiv:2504.09128, Apr 2025). [B]
- 📖 📝 **Nation, J. B., Paolini, M.** *"Elementary properties of free lattices III: Undecidability of the full theory"* (arXiv:2511.13149, Nov 2025). [B] — **Q-B5 resolved 2026-05-09**: NP-III reduces from Nies's undecidability of the ∀∃-theory of *nice finite bipartite graphs* (Fact 2.3, citing Nies 1996), lifted via bipartite posets (Cor. 2.7) and the embedding ξ : Q ↪ F_m, then composed with the Whitman embedding ζ : FL(ℵ₀) ↪ F_3 (§5). Strategy: given a ∀∃-sentence φ on posets, construct φ* on lattices such that φ holds in all finite nice bipartite posets ⟺ F_κ ⊨ φ* (Lem. 4.4). Not group/semigroup word problem, not Hilbert's 10th, not direct Turing halting.
- 📝 **Nies, A.** *"Undecidable fragments of elementary theories"* (Algebra Universalis 35, 1996, 8–33). [B] — origin of the ∀∃-theory of nice finite bipartite graphs being undecidable; Theorem 4.7 there is the seed of NP-III's reduction. Pending direct retrieval.
- 📖 📝 **Freese, R., Ježek, J., Nation, J. B.** *Free Lattices* (AMS Math Surveys & Monographs 42, 1995). [B, C] — anchor reference.
- 👀 📝 **Bloniarz, P. A., Hunt, H. B., Rosenkrantz, D. J.** *"Algebraic structures with hard equivalence and minimization problems"* (Inform. Comput., 1988). [B]
- 👀 📝 **Whitman, P. M.** *"Free lattices"* (Ann. Math., 1941–1943). [B] — historical anchor.

## Rewriting / undecidability (Paper B encoding chain)

- 📖 📝 **Endrullis, J., Shallit, J., Smith, T.** *"Undecidability and Finite Automata"* (DLT 2017, LNCS 10396; arXiv:1702.01394). [B] — TM ↪ rewriting via Lemma 1 / REWRITE-POWER.
- 👀 📝 **Book, R. V., Otto, F.** *String-Rewriting Systems* (Springer 1993). [B] — cited by ESS 2017 for the rewriting-power lemma.

## CALM / Bloom / monotone-distributed (Paper B + Paper A demarcation)

*Cross-reference: Hellerstein-Alvaro 2020 and BloomL paper now also listed under "Lattice-based deterministic parallelism" as direct lineage. Listed here for the demarcation-theorem role they play in B + A.*

- 👀 📝 **Ameloot, T. J., Neven, F., Van den Bussche, J.** *"Relational transducers for declarative networking"* (JACM 60(2), 2013). [B] — reverse direction of CALM.
- ❓ **Alvaro, P. et al.** *Dedalus* — overlog with explicit time. [B]

## Lattice-based deterministic parallelism (DIRECT LINEAGE — elevated 2026-05-08)

**Per owner (2026-05-08)**: "this is important lineage to us. Our efforts stem from this, directly inspired from this work." Promoted from "Paper B adjacent" to *direct lineage*. A0 acknowledgments to credit explicitly.

- 📖 📝 **Kuper, L.** *"Lattice-Based Data Structures for Deterministic Parallel and Distributed Programming"* (Indiana PhD thesis, 2015). [A0, B] — **direct lineage**: lattices-as-foundation-of-deterministic-parallelism, realized in Prologos at the granularity of an entire compiler.
- 👀 📝 **Kuper, L., Newton, R.** *"LVars: lattice-based data structures for deterministic parallelism"* (FHPC 2013). [A0, B] — **direct lineage**: the LVar primitive concept lifted to compiler-cell-level.
- 📖 📝 **Hellerstein, J. M., Alvaro, P.** *"Keeping CALM: When Distributed Consistency Is Easy"* (CACM 63(9), 2020). [A0, A, B] — **direct lineage**: CALM theorem is the architectural invariant Prologos enforces; the PAR Track 2 "40-line PoC just worked" anecdote (see audit E9-bis) is empirical confirmation that the substrate enforces CALM-correctness structurally.
- 👀 📝 **Conway, N., Marczak, W. R., Alvaro, P., Hellerstein, J. M., Maier, D.** *"Logic and Lattices for Distributed Programming"* (BloomL paper). [A0, B, A] — **direct lineage**: lattice-typed distributed programming.
- 👀 **Garg, V. K.** *Predicate Detection: Theory and Application* (Springer). [C, A] — lattice-linear predicate detection.
- 👀 📝 **Garg, V. K.** Lattice-linear predicate detection paper(s) — exact citation TBD. [C]

## Polynomial functors / categorical (Paper Poly + B foundation)

- 📖 📝 **Niu, N., Spivak, D. I.** *Polynomial Functors: A Mathematical Theory of Interaction* (CUP / LMS, 2024). [Poly, B] — full book parsed in round-2 audit; zero hits on lattice/propagator/Sussman/Radul/Whitman/CALM/LVar/CRDT/Garg/Petri/Kahn/Hewitt/Wolfram terms across ~93/489 pages parsed including References + Index.
- 👀 📝 **Spivak, D. I.** *"Is Poly the true language of computation?"* (AFOSR Review talk, 2022). [Poly, B] — closest UTM-analogue rhetoric in the Poly literature.
- ❓ **Hedges, J., Capucci, M., et al.** Categorical systems theory / dependent optics. [Poly]
- ❓ **Myers, D. J.** *Categorical Systems Theory*. [Poly]

## Propagator literature (Poly + A0)

- 👀 📝 **Sussman, G. J., Radul, A.** *"The Art of the Propagator"* (MIT-CSAIL-TR-2009-002). [Poly, A0]
- 👀 📝 **Radul, A.** *Propagation Networks: A Flexible and Expressive Substrate for Computation* (MIT PhD thesis, 2009). [Poly, A0]

## Stratified semantics / negation (Paper A novelty boundary)

- ❓ **Apt, K. R., Blair, H. A., Walker, A.** *"Towards a theory of declarative knowledge"* (1988). [A]
- ❓ **Przymusinski, T. C.** *"On the declarative semantics of deductive databases and logic programs"* (1988). [A]
- ❓ **Van Gelder, A., Ross, K. A., Schlipf, J. S.** *"The well-founded semantics for general logic programs"* (JACM 1991). [A]
- ❓ **Gelfond, M., Lifschitz, V.** *"The stable model semantics for logic programming"* (1988). [A]
- (Likely more once the Q-A1 novelty-positioning audit runs.)

## Galois connections / abstract interpretation (A + Poly)

- ❓ **Cousot, P., Cousot, R.** *"Abstract interpretation: a unified lattice model for static analysis of programs by construction or approximation of fixpoints"* (POPL 1977). [A, Poly]
- ❓ **Pichardie, D.** Abstract-interpretation lineage, Galois-connection-based. [A, Poly]
- ❓ **Miné, A.** Octagon / abstract-interpretation work. [A]

## Kan extensions in computation (A + Poly)

- ❓ **Hinze, R.** *"Kan extensions for program optimization, or: art and dan explain an old trick"* (MPC 2012). [A, Poly]
- ❓ **Rivas, E., Jaskelioff, M.** *"Notions of computation as monoids"* (JFP 2017). [A, Poly]

## Compiler-as-network / IR-as-network (A0)

- ❓ **Tate, R. et al.** *"Equality Saturation: A New Approach to Optimization"* (POPL 2009). [A0] — equality-saturation / e-graph as IR.
- ❓ **Willsey, M. et al.** `egg` / egglog. [A0, PReduce-feeding]
- ❓ **Schlatt, B.** *"E-Graphs as a Persistent Compiler Abstraction"* (2026). [A0, PReduce-feeding]

## Hewitt actors / universal-substrate precedent (B framing)

- 👀 📝 **Hewitt, C.** *"Actor Model of Computation"* (arXiv:1008.1459, multiple revisions). [B] — explicit UTM-analogue precedent on a different substrate.

## Variety theory / lattice algebra (C)

- 👀 **Jónsson, B.** Lattice variety theory. [C]
- 👀 📝 **Project internal**: `2026-05-08_PROLOGOS_LATTICE_VARIETY_CATEGORIZATION.md` — empirical Whitman 10/10 + binder boundary.
- 👀 📝 **Project internal**: `2026-04-30_LATTICE_HIERARCHY_AND_DISTRIBUTIVITY_FOR_PROPAGATORS.md` — operational catalog of what each variety unlocks.
- 👀 📝 **Project internal**: `2026-04-30_LATTICE_VARIETY_AND_CANONICAL_FORM_FOR_SRE.md` — element-level theory.

## Tropical / quantale (PReduce + C optimality)

- 👀 📝 **Project internal**: `2026-04-21_TROPICAL_QUANTALE_RESEARCH.md`. [PReduce-feeding, C]
- ❓ Goodman, J. *"Semiring parsing"* (1999) — cited in PReduce. [PReduce-feeding]

## Internal Prologos research (load-bearing)

- 📖 📝 `outputs/free-lattice-utm-parallel.md` (this programme, 2026-05-08) — Paper B prior-art floor.
- 📖 📝 `2026-03-13_LAYERED_RECOVERY_CATEGORICAL_ANALYSIS.md` — Paper A starting material.
- 📖 📝 `2026-03-21_CATEGORICAL_STRUCTURE_FIVE_SYSTEMS.md` — Paper A honest-instance analysis.
- 📖 📝 `2026-03-22_NTT_SYNTAX_DESIGN.md` — Paper A0 NTT section.
- 📖 📝 `2026-03-22_NTT_ARCHITECTURE_SURVEY.md` — Paper A0 NTT section, case studies.
- 📖 📝 `2026-05-02_PREDUCE_MASTER.md` — research-feeding-engineering home for reduction work.

---

## TODO

- Run **Q-A1** novelty-positioning audit; populate stratified-semantics section with read-status updates.
- Run **Q-B5** Nation-Paolini III PDF parse; update reduction-shape note in §Free-lattice algebra.
- Run **Q-Poly-1** + **Q-Poly-2** light positioning passes; update Galois-connection / dependent-optics sections.
- Convert `❓ unread` entries to `👀 skimmed` or `📖 read` as engaged.
