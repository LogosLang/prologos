# UTM-FL Programme — Open Questions

Cross-paper unknowns. Each question tagged with the paper(s) it gates and the kind of work needed to resolve it (audit / synthesis / formalization / experiment / consult).

Status legend: 🔴 blocking | 🟡 active | 🟢 backlogged | ✅ resolved

---

## Paper-A questions (LRP)

- 🔴 **Q-A1 / novelty positioning** — What is the precise novelty boundary for LRP against classical stratified-semantics literature (Apt-Blair-Walker, Przymusinski, Van Gelder-Ross-Schlipf, Gelfond-Lifschitz)? Specifically: has anyone unified NAF + WF + type-stratification + effect-stratification + retraction + topology under one structural framework? **Resolution**: novelty-positioning audit, structured like the FL+UTM priority audit. Required before substantive Paper A work begins. Related: Galois-bridges-as-abstract-interpretation prior art (Cousot–Cousot lineage); Kan-extensions-as-program-transformation prior art (Hinze, Rivas–Jaskelioff).
- 🟡 **Q-A2 / instance set** — What is the final LRP instance set for the paper? Currently six (NAF, WF, type, effect, retraction, topology) plus hints in PPN series of more. **Resolution**: scan PPN-series PIRs for additional stratified-recovery sites; freeze inventory before submission.
- 🟡 **Q-A3 / heterogeneity vs uniformity** — `2026-03-21_CATEGORICAL_STRUCTURE_FIVE_SYSTEMS` is honest that not every instance is a strict opfibration. What is the right uniform structural claim that is *true* across all instances? Bifibration is too strong. **Candidate**: stratified posets of monotone-fixpoint-cells with inter-stratum Galois bridges + Kan extensions. **Resolution**: formalization, possibly with Nation input.
- 🟢 **Q-A4 / universality conjecture** — How aggressive should the universality clause be? Three options: (i) "every non-monotone computation we care about decomposes," (ii) "every FOTFL-expressible non-monotone decomposes," (iii) "every Turing-computable non-monotone decomposes (modulo encoding)." Each carries different proof obligations. **Resolution**: deferred until instance set is frozen.

## Paper-B questions (FL universal substrate)

- 🔴 **Q-B1 / substrate-vs-decider formalization** — How to formalize the substrate-vs-decider distinction so reviewers don't read FL-as-UTM as a category error? **Candidate**: substrate = (FL(ℵ₀), Whitman-decision-procedure, Poly-shaped propagators, BSP-style scheduler); compare structurally to UTM = (tape, transition function, head, scheduler-trivial). **Resolution**: Hewitt-actor-precedent study + formalization; required before Paper B writing.
- 🟡 **Q-B2 / encoding-chain rigor** — TM ↪ NFA ↪ join-only relations ↪ FL is a synthesis across multiple sources, not a single citation. Specifically: what is the precise lift from rewriting (Endrullis–Shallit–Smith 2017, Lemma 1 / REWRITE-POWER, citing Book-Otto 1993) to FL? **Resolution**: develop with Nation; possibly his existing work or his collaborators' work has the chain.
- 🟡 **Q-B3 / Whitman-from-recursive-merge** — Does the recursive-on-outermost-operator merge shape *prove* Whitman's condition (W), or merely correlate with it empirically (10/10 in our sample)? **Resolution**: candidate theorem; Nation consultation; possibly a small lemma in the paper or in a Paper-B technical appendix.
- 🟡 **Q-B4 / CALM scope** — Soft / suggestive framing accepted (per 2026-05-08 conversation). What pieces need to be in play before the Church-Turing-shaped statement can be taken seriously? Owner: "more pieces in play before we can grapple with that claim." **Resolution**: revisit after Paper A and the empirical Paper-A0 anchors are in place.
- ✅ **Q-B5 / Nation-Paolini III reduction shape** — *Resolved 2026-05-09* via `alpha_get_paper` retrieval of arXiv:2511.13149 (full body, all sections). Reduction is from **Nies (1996), Algebra Universalis 35, Theorem 4.7**: the ∀∃-theory of *nice finite bipartite graphs* is undecidable. NP-III lifts this to bipartite posets (Cor. 2.7), embeds Q ↪ F_m via ξ(qᵢ) = ∏{xⱼ : qⱼ ⩾ qᵢ} (Fact 4.1), then composes with the Whitman embedding ζ : FL(ℵ₀) ↪ F_3 (§5) for the cardinality-3 case. The translation is φ ↦ φ* where φ* uses the first-order definable predicate t E u (doubly-minimal-join-cover, Lem. 3.2) to recover the bipartite poset internally to F_κ. **Not** group/semigroup word problem, **not** Hilbert's 10th, **not** direct Turing halting. **Implication for Paper B**: the encoding chain is `TM ↪ rewriting (ESS 2017)` on one branch and `bipartite-graph-∀∃-theory ↪ FL` (NP-III) on another; the substrate carries undecidability through *first-order definable structure inside FL*, not through Turing simulation. This is a more natural shape for the Paper-B substrate-vs-decider story than a Turing-style reduction would have been. Bibliography updated; Nies (1996) added as new entry, retrieval pending.

## Paper-C questions (variety optimality)

- 🟡 **Q-C1 / cost model** — What is the "natural cost model" per variety? Is it canonical, or does it require per-variety design choices that weaken the optimality claim? Boolean: parallel circuit depth. Distributive: Garg LLP rounds. SD/modular/FL: ? **Resolution**: PTF-orbit synthesis pass; identify whether each variety's "natural" cost model is unique up to equivalence.
- 🟡 **Q-C2 / binder-boundary** — The binder boundary (Pi/Sigma/lambda) breaks distributivity per `2026-05-08_PROLOGOS_LATTICE_VARIETY_CATEGORIZATION`. Does this match a known phenomenon in algebra / model theory of dependent types? Is it the natural counterexample for Paper C's distributive-instance, or a separate object of study? **Resolution**: Nation consultation + literature scan.
- 🟢 **Q-C3 / instance citations** — For Boolean and distributive instances of the optimality claim, what is the correct prior-art citation? "Hypercube ATMS theorem" needs a name; Garg LLP needs source. **Resolution**: small bibliographic pass.

## Paper-Poly questions

- 🟡 **Q-Poly-1 / dependent-optics overlap** — How much of the Poly = propagator identification is already implicit in the dependent-optics / categorical-systems-theory literature (Hedges, Myers, Capucci, Milewski)? Round-2 audit said "no propagator identification anywhere"; that needs sharpening into "no identification with *Sussman-Radul* propagators on *lattice-valued* cells." **Resolution**: targeted positioning audit; Niu–Spivak Chapter 8 already mechanically scanned (zero hits on lattice/propagator terms) but the *adjacent* literature merits one more pass.
- 🟡 **Q-Poly-2 / Galois bridges as abstract interpretation** — How much of "Galois connections between cells of different lattice domains" overlaps with classical abstract-interpretation Galois-connection structure (Cousot-Cousot)? **Resolution**: prior-art positioning pass; required for Poly-paper and indirectly for Paper A.

## Paper-A0 questions (LHC system paper)

- ✅ **Q-A0-1 / phase-collapse precise statement** — *Resolved (draft) 2026-05-08*: see `outputs/phase-collapse-and-deterministic-parallelism-audit.md` Claim 1 §"Precise technical statement." Statement composed from corpus evidence E1–E8; flagged for owner validation. Outstanding: G1 (PReduce scoping decision).
- ✅ **Q-A0-2 / scheduler-portability evidence** — *Resolved (draft) 2026-05-08*: see audit doc Claim 2 §"Direct evidence" E9–E13. Four schedulers enumerated (Gauss-Seidel, BSP/Jacobi, widening, Zig PoC) with `bench-scheduler-ab.rkt` as the A/B harness. Outstanding: G2 (fixpoint-identity assertion vs current wall-time-only A/B), G3 (Zig PoC pinning), G4 (verify count if more schedulers exist in branches).
- 🟡 **Q-A0-3 / NTT positioning in A0** — Does NTT get a section ("design meta-language") or is it a sidebar ("we used a specification language to design the system")? Length implications either way. **Resolution**: depends on how A0's narrative arc is shaped.
- 🟡 **Q-A0-4 / .pnet IR claim novelty** — ".pnet IS the IR" is a strong claim. What other compilers have a network-as-IR rather than tree/SSA-as-IR? Some (Equality Saturation / e-graphs as IR — Tate et al. 2009; Ureche RAW IR; etc.). Positioning audit needed. **Resolution**: small lit scan.

## Cross-cutting questions

- 🟡 **Q-X1 / Poly-paper before B?** — Confirmed in v0.1 charter. But *strictly* required, or could Paper B reference a tech report? **Resolution**: depends on Poly-paper venue acceptance timing.
- 🟡 **Q-X2 / engineering-anchor freezing protocol** — When a paper depends on an empirical measurement (e.g., the Whitman 10/10 finding, the 4-5-schedulers result), how is that frozen? Git tag? Versioned artifact in `engineering-anchors.md`? **Resolution**: design pass; recommend git tag + archived `.pnet` + measurement script.
- 🟢 **Q-X3 / Nation co-authorship triggers** — Under what conditions does the relationship escalate from informal adviser to co-author? Owner indicated this is open and to be discussed as papers approach submission. **Resolution**: organic; revisit at Paper B outline stage.

---

## Resolution log

- **2026-05-08**: Q-A0-1, Q-A0-2 resolved (draft) by `outputs/phase-collapse-and-deterministic-parallelism-audit.md`. Pending owner validation of the proposed precise statements; six gaps G1–G6 identified for follow-up engineering.
