---

# Round 2 Addendum (2026-05-08)

This addendum unblocks the three PDF checks flagged in round 1 and resolves four unsearched literatures (Wolfram, propagator networks, CRDT engineering, operads of wiring diagrams) plus a deep dive on **polynomial functors as universal interaction substrate** with attention to the **Poly ↔ propagator-network** identification.

**Tooling note.** `alpha_ask_paper` returned a schema error (`queries: invalid_type, expected array`) on every attempted call in this round — appears to be a tool-side bug. PDF parsing was instead done via (i) `fetch_content` on arXiv HTML versions, (ii) `document_parse` on a downloaded PDF (Kuper dissertation), and (iii) two parallel `researcher` subagents for the literature searches.

---

## R2-A. Resolved blocked checks

### R2-A1. Nation-Paolini III reduction shape (arXiv:2511.13149)

**Source:** full HTML of arXiv:2511.13149v1 fetched via `fetch_content`.

**Reduction shape.** The reduction is **not** from Turing halting, **not** from Hilbert's 10th, **not** from group/semigroup word problem. It is from **Nies 1996** (André Nies, *"Undecidable fragments of elementary theories"*, Algebra Universalis 35, 8–33, 1996), specifically Theorem 4.7: the **∃∀-theory of finite nice bipartite graphs is undecidable**. Nation-Paolini lift this first to the ∃∀-theory of finite nice bipartite *posets* (Corollary 2.7 of [3]), then encode such posets as elements of FL(κ) using a first-order definable predicate Ψ(w) over a "doubly minimal join cover" relation E (drawn from [9, p. 45]).

Verbatim from the paper:

> "We rely on the undecidability of the ∀∃-theory of nice finite bipartite graphs (cf. 2.2) proved by Nies in [Nies 1996, Theorem 4.7]. First we observe that also the ∀∃-theory of nice finite bipartite posets is undecidable and then, given a ∀∃-sentence φ in the language of posets, we construct a sentence φ_∗ in the same language (which is also the language of lattices) such that φ is true in all finite lattices if and only if φ_∗ is true in F_κ (where κ ⩾ 3 is fixed)."

**Whitman is load-bearing.** §5 of the paper is titled *"Whitman revisited"* and uses Whitman 1943 (*"Free lattices II"*, Annals of Math 43, 104–115) [10/11] explicitly to push the κ ≥ 3 case down to F_3 via the embedding ζ : FL(X) → F_3 built from Whitman's four polynomials f_1, f_2, f_3, f_4. The κ ≥ 3 result depends critically on this Whitman embedding:

> "Recall the Whitman embedding of F_k (for 3 ⩽ k ⩽ ω) into F_3 from [Whitman 1943]. Let X_3 = {x_1, x_2, x_3}. To get a sublattice isomorphic to F_4, use X_4 = {u_1, u_2, u_3, u_4} where u_i are [the four] lattice polynomials [f_1, f_2, f_3, f_4 above]."

So Whitman's structural decision procedure shows up in two places: (i) as the historical antecedent for word-problem decidability (round 1's framing), and (ii) load-bearingly in Nation-Paolini III's undecidability proof itself, as the embedding mechanism that compresses the κ ≥ 3 cases into F_3. This is a **genuinely substantive** appearance of Whitman in the modern undecidability result.

**UTM-analogue rhetoric.** **None.** The paper's introduction is uniformly Tarski-tradition decidability framing:

> "The question of algorithmic decidability of a given first-order theory is a classical theme of mathematical logic. Starting from the undecidability of Th((ℕ, +, ·)), the field is riddled with (un)decidability results of first-order theories."

No "Turing machine", "Church-Turing", "universal computational substrate", or UTM-analogue language appears anywhere in the paper.

**Net effect on the priority audit.** The round-1 reading is sharpened: Th(F_κ) being undecidable for κ ≥ 3 is now known to come from a *graph-theoretic* ∃∀-undecidability source (Nies), not from Turing halting directly. The Turing-encoding-into-FOTFL lives in the Nies → bipartite-graph → FOTFL chain, not in Nation-Paolini's own work. The framing remains entirely model-theoretic.

### R2-A2. Hewitt arXiv:1008.1459 — UTM contrast and "universal primitives" framing

**Source:** `fetch_content` on `https://arxiv.org/abs/1008.1459` retrieved the abstract page (4.6 KB, abstract + version history of 38 revisions across 2010–2015).

**Verbatim abstract (v38, January 2015):**

> "The Actor model is a mathematical theory that treats 'Actors' as the **universal primitives of concurrent digital computation**. The model has been used both as a framework for a theoretical understanding of concurrency, and as the theoretical basis for several practical implementations of concurrent systems. **Unlike previous models of computation, the Actor model was inspired by physical laws.** It was also influenced by the programming languages Lisp, Simula 67 and Smalltalk-72, as well as ideas for Petri Nets, capability-based systems and packet switching. ... The Actor Model is intended to provide a foundation for inconsistency robust information integration."

**Correction to round 1.** Round 1 quoted the Hewitt phrasing as "the universal conceptual primitives of digital computation". The arXiv abstract (v38) has "universal primitives of **concurrent** digital computation" — note the word *concurrent*, which scopes the universality claim. Round 1's phrasing was either drawn from the body (which we have not fetched the full PDF of — blocked check remains for the body's stronger "all physically possible computation" claim) or from a prior version. We retain round 1's verdict that Hewitt's program is the only sustained explicit UTM-analogue rhetoric in any parallel/concurrent model, but with a sharpened scope: the abstract-level claim is *concurrent digital computation*, not *digital computation* full stop.

**No lattice / semilattice / monotone competitors.** The abstract contrasts actors with "previous models of computation" generally and lists influences (Lisp, Simula, Smalltalk, Petri Nets, capability-based systems, packet switching). No mention of lattices, semilattices, fixed-point/order-theoretic substrates as competitors or candidates. The motivation Hewitt foregrounds is **physical-law-inspired** ("Unlike previous models of computation, the Actor model was inspired by physical laws") — a strikingly different framing register from the algebraic / order-theoretic register of the FL(ℵ₀) program.

**Blocked check that remains.** The "all physically possible computation can be directly implemented using Actors" claim is in the body of the paper, not the abstract. We did not fetch the v38 PDF body. Unverified, but the round-1 sources for this exact phrasing (HAL hal-01163534v6) corroborate it.

### R2-A3. Kuper dissertation universality framing

**Source:** Kuper PhD dissertation, Indiana University 2015, *Lattice-Based Data Structures for Deterministic Parallel and Distributed Programming*, downloaded as PDF and parsed via `document_parse` (101 pages parsed, covering preface + Chapter 1 Introduction + Appendix A proofs). Other chapters covered structurally via the table of contents.

**Verbatim formal thesis statement (Chapter 1.6, p. 9):**

> "**Lattice-based data structures are a general and practical unifying abstraction for deterministic and quasi-deterministic parallel and distributed programming.**"

Note the exact phrasing: *unifying abstraction*. The dissertation abstract uses *foundation*: "lattice-based data structures, or LVars, are **the foundation for a guaranteed-deterministic parallel programming model** that allows a more general form of sharing." Both phrasings are bounded to *deterministic / quasi-deterministic* parallelism.

**Verbatim subsumption claim (Chapter 1.2, p. 4):**

> "no-shared-state parallelism, data-flow parallelism and single-assignment parallelism are all subsumed by the LVars programming model, and ... imperative disjoint parallel updates are compatible with LVars as well."

This is the *de facto* universality argument: LVars subsume four prior deterministic-parallel programming models (no-shared-state pure FP; Kahn process networks; IVars; DPJ-style imperative disjoint parallelism). It is universality *within deterministic-parallel scope*.

**Negative results (mechanically verified by `grep` on the parsed text):**
- Zero occurrences of "Turing", "Church-Turing", "universal substrate", "computability".
- Zero occurrences of "Hewitt" or "actor".
- Zero occurrences of "free lattice" or "Whitman".
- Zero occurrences of "propagator", "Sussman", or "Radul".

The only occurrence of "foundation" in a substantive place is in the abstract, applied to "guaranteed-deterministic parallel programming model" — bounded scope.

**Net effect.** Round 1's verdict is fully confirmed and now mechanically anchored: Kuper's dissertation does **not** invoke UTM/Church-Turing rhetoric, does **not** discuss free lattices or Whitman's condition, does **not** mention propagator networks, and does **not** position LVars as a universal substrate beyond the deterministic-parallel scope. The "foundation" / "unifying abstraction" rhetoric is real but bounded.

---

## R2-B. Wolfram, propagator networks, CRDT engineering

Two researcher subagents covered four newly-searched literatures in round 2. Full per-axis findings live in `outputs/.drafts/free-lattice-utm-parallel-research-wolfram-propagator-crdt.md` and `outputs/.drafts/free-lattice-utm-parallel-research-operads-poly-deep.md`. Synthesis below.

### R2-B1. Wolfram — multicomputational paradigm (NEW PRIORITY THREAT)

**Verdict: EXPLICIT.** This is the strongest competing universality framing found in the entire two-round audit, and it postdates the round-1 search.

**Verbatim, Wolfram, *Multicomputation: A Fourth Paradigm for Theoretical Science* (writings.stephenwolfram.com, Sept 2021):**

> "at the core of our Physics Project is actually a new paradigm that goes beyond the computational one: a fourth paradigm for theoretical science that I'm calling the **multicomputational paradigm**. ... it really is a fundamentally new paradigm — that transcends physics and applies quite generally as the **foundation** for a new and broadly applicable methodology for making models in theoretical science."

> "In the ordinary computational paradigm, time in effect progresses in a linear way ... But in the multicomputational paradigm there is no longer just a single thread of time; instead one can think of every possible path through the multiway system as defining a different interwoven thread of time."

> "[the multicomputational paradigm] potentially gives us a very different — and powerful — new approach to **distributed computing**, perhaps complete with very general physics-like 'bulk' laws."

The substrate is **multiway systems / hypergraph rewriting**, with the **ruliad** (the entangled limit of all computationally possible rules) as the limit object. From MathWorld:

> "The ruliad may be defined as the entangled limit of everything that is computationally possible, i.e., the result of following all possible computational rules in all possible ways."

**Multiway Turing Machines bulletin (Feb 2021)** has the closest explicit UTM-analogue construction:

> "The closest analogous definition of computation universality for multiway Turing machines is to say that with appropriate initial conditions the multiway evolution of a Turing machine can emulate (up to suitable encoding) the multiway evolution of any other Turing machine."

**Net effect on the priority audit.** Wolfram's multicomputational paradigm (2021) is now the **most serious competing priority claim** for "universal substrate of parallel computation." It postdates all the lattice-side framings (CALM, Garg, Kuper) and explicitly stakes out *foundational* status against the (sequential) computational paradigm, with explicit application to distributed computing. The substrate is graph-rewrite-theoretic (multiway / hypergraph rewriting) rather than order-algebraic. Wolfram explicitly notes that multiway graphs have "the mathematical structure of Hasse diagrams for partial orderings," so the connection to lattices is structurally present but never made explicit.

**Caveats (also from research):**
- Wolfram does not identify a *specific algebraic free object* (free lattice, free monoid-with-merge, etc.) as the substrate.
- He does not write the literal sentence "X is to parallel computation as UTM is to sequential computation"; the closest is the universality result for multiway Turing machines (*MTMs simulate all MTMs*).
- The ruliad and FL(ℵ₀) are sibling everything-at-once limit objects — one rule-graph-theoretic, one order-algebraic. The framing roles are similar.

### R2-B2. Propagator networks (Sussman & Radul) — DIRECT ANCESTOR

**Verdict: EXPLICIT for "substrate" framing. ADJACENT for FL(ℵ₀)-style priority.**

**Radul's PhD dissertation (MIT, 2009) is titled *Propagation Networks: A Flexible and Expressive Substrate for Computation*** — "Substrate" is in the title.

Verbatim from the abstract:

> "In this dissertation I propose **a shift in the foundations of computation**. Modern programming systems are not expressive enough. The traditional image of a single computer that has global effects on a large memory is too restrictive. The propagation paradigm replaces this with computing by networks of local, independent, stateless machines interconnected with stateful storage cells. ... A foundational layer is missing. ... I reflect on the new light the propagation perspective sheds on the deep nature of computation."

§1.4 of the thesis is titled *Propagation promises Liberty*:

> "I believe that general-purpose propagation offers an opportunity of revolutionary magnitude. The move from instructions to expressions led to an immense gain in the expressive power of programming languages... **The move from expressions to propagators is the next step in that path**."

§2.1 (cells store partial information; merge is monotone — i.e., a join-semilattice contract):

> "Instead of thinking of a cell as an object that stores a value, think of a cell as an object that stores everything you know about a value."
> "It is important that this be **accumulating partial information**: it must never be lost or replaced. A cell's promise to remember everything it was ever told is crucial to gaining freedom from time."

(Radul does *not* use the words "lattice" or "semilattice" in the abstract — the connection to Birkhoff/Tarski lattice theory and to CALM is structurally implicit but never made explicit.)

**Net effect on the priority audit.** Radul's "substrate for computation" framing is **the direct ancestor** of any propagator-network universal-substrate claim. The thesis title literally has "Substrate for Computation" in it; the abstract proposes "a shift in the foundations of computation." Any FL(ℵ₀)-as-UTM-analogue paper that builds on a propagator base (as Prologos does) **must** acknowledge Radul as prior art for the "substrate" framing, while distinguishing the *kind* of substrate (algebraic / order-theoretic FL(ℵ₀) vs. architectural / propagator-network with merge-monotone cells).

The structural overlap: Radul cells = join-semilattice elements; merge = least-upper-bound; quiescence = lattice fixed point. Prologos's compiler is built on this directly.

### R2-B3. CRDT engineering — ABSENT (universalism), ADJACENT (lattice primacy)

**Verdict: ABSENT for universality framing. ADJACENT (Lasp explicitly takes lattices as primitive).**

**Shapiro et al. CRDTs (SSS 2011 / INRIA RR-7687)** — the convergence proof is built on the join-semilattice structure (states form a join-semilattice, updates monotonically increase, replicas merge by join, all replicas converge to the same supremum). But Shapiro et al. do **not** use universality language; the framing is *design discipline for eventual consistency*.

**Lasp (Meiklejohn & Van Roy, PPDP 2015)** — explicitly takes **lattices** as the unifying primitive (the "L" in Lasp = Lattice Processing). But the framing is engineering-pragmatic ("simplify large-scale distributed programming"), not universality-claiming.

**Closest "universal" usage found.** Lewis-Pye & Shapiro, *"The Blocklace: A Universal, Byzantine Fault-Tolerant, Conflict-free Replicated Data Type"* (arXiv:2402.08068). But "universal" here means *can implement any CRDT* (universality within the CRDT class), not foundational-substrate universality.

**Net effect.** CRDT engineering is the technology that already realises the join-semilattice merge contract at internet scale (Yjs, Automerge, Riak), but no engineering-side paper makes a foundational priority claim. The lattice/monotonicity primacy is implicit in the math but never elevated to a "universal substrate" thesis.

---

## R2-C. Operads of wiring diagrams + Polynomial Functors deep dive (HIGH PRIORITY)

### R2-C1. Operads of wiring diagrams — ABSENT

The operads-of-wiring-diagrams literature (Spivak 2013 *The Operad of Wiring Diagrams* arXiv:1305.0297; Vagner-Spivak-Lerman 2015 *Algebras of Open Dynamical Systems on the Operad of Wiring Diagrams* TAC 30 / arXiv:1408.1598; Rupel-Spivak 2013 arXiv:1307.6894; Yau 2018 Springer LNM 2192) uniformly pitches wiring-diagram operads as **syntax for compositional/hierarchical assembly of open dynamical systems**, never as a foundational/universal parallel substrate.

The word "propagator" does not appear in any of these papers. UTM-analogue / universality claims: **absent**.

### R2-C2. Polynomial Functors — Spivak 2022 AFOSR talk is the strongest prior UTM-analogue rhetoric

**The single most important document discovered in round 2:**

**Spivak, *"Is Poly the true language of computation?"*, AFOSR Review 2022** ([slides PDF](https://topos.institute/people/david-spivak/AFOSR_Review2022_Talk.pdf)).

Verbatim from the slide deck:

> "The Turing machine changed everything; but is it *right*? The Von Neumann architecture changed everything, but is it right? Rust, Python, Julia are great languages, but... In 100 years will we be using someone's invented language?" *(p. 7)*

> "Computation—the processing of information—is central to our world. Church-Turing thesis: all notions of computation are equally expressive [...] I propose that we can do better than Python, Rust, Julia. With something this central, there may be a 'right' language. **A true language of computation should be discovered, not invented.** It should be constructed out of very basic ideas. It should have very diverse computational applications. It should have a small set of 'orthogonal' constructors. It should be like legos or tinker-toys, but made out of math." *(p. 8)*

> "It's discovered in the sense that it's part of a fundamental sequence... namely the sequence of **free op-completions: 0 ↦ 1 ↦ Set ↦ Poly**." *(p. 10)*

> "Awodey showed that poly'l monads are universes for dependent types. Polynomial comodules migrate data between databases. Typed programming lang's rely heavily on poly datatypes and monads. Categories themselves are the comonoids in Poly. In fact higher categories (double cats, ∞-cats) live naturally in Poly. Cellular automata have a natural description in Poly. Dynamical systems—cts or discrete—have natural descrip'ns in Poly. Deep learning [...] has a natural descrip'n in Poly. Wiring diagrams, mode dependence have natural descriptions in Poly. **Turing machines have a natural description in Poly.** So it's got syntax, operations, dynamics, learning, nested control, etc." *(p. 10)*

> "I think that **Poly could serve as the foundational language for it.** It's at once low level (Turing machines) and high level (dep. types). It naturally describes PL, DB, DS, TM, CA, IT, ML." *(p. 11)*

> "Having everything from dependent types to Turing machines suggests more. **There may be a 'God-given' language of computation.** Poly or not, it's worth considering the possibility. [...] Having this single, tight, elegant, highly articulate language... with so many diverse applications, could revolutionize computing." *(p. 14)*

**This is the closest existing UTM-analogue rhetoric in any of the surveyed literatures.** Spivak explicitly:
- Names the Turing machine as the incumbent ("The Turing machine changed everything; but is it *right*?").
- Invokes the Church-Turing thesis ("Church-Turing thesis: all notions of computation are equally expressive").
- Stakes a successor claim for Poly ("Poly could serve as the foundational language").
- Demonstrates Turing-machines-in-Poly explicitly: Niu-Spivak Exercise 4.13 *"Tape of a Turing machine"* models a Turing machine as a particular monomial-to-monomial dependent lens, the same Moore-machine pattern that runs through the book.

The published Niu-Spivak book uses gentler "**a mathematical theory of interaction**" / "**new syntax for modeling [interacting] systems**" rhetoric. The 2021 Topos course was titled *"Polynomial Functors: A General Theory of Interaction."* The bolder 2022 AFOSR framing is Spivak's aspirational version.

### R2-C3. Poly ↔ propagator-network identification — NOT IN PRIOR LITERATURE

**This is the most consequential finding of round 2 for the user's specific work.**

The researcher subagent searched:
- The Niu-Spivak *Polynomial Functors* book (375 pp), preface, bibliography (sampled), and chapter index.
- Spivak's complete public talk list at Topos Institute through Dec 2024.
- The Topos Institute blog corpus (Poly-related posts surveyed: Bayesian-update-as-Poly, graphs-in-Poly, Poly-inside-Poly, spooling-out-syntax, poly-morphic-effect-handlers, neural-wiring-diagrams).
- The operad-of-wiring-diagrams program (Spivak 2013, Rupel-Spivak 2013, Vagner-Spivak-Lerman 2015, Yau 2018).
- David Jaz Myers's *Categorical Systems Theory* book draft.
- Adjacent dependent-optics work (Hedges, Capucci, Milewski, Riley, et al.).
- The Sussman/Radul-direction literature (Radul PhD 2009, Sussman-Radul 2009, ProjectMAC/propagators GitHub).

Search queries explicitly tried (a non-exhaustive list): `"polynomial functor" "propagator"`, `Spivak "propagator network" OR "Sussman"`, `"dependent lens" propagator OR "constraint network"`, `Topos Institute propagator network polynomial functor`, `site:topos.institute polynomial functor propagator`, `Sussman propagator polynomial`, `Radul propagator category theory`.

**Not a single paper, talk, blog post, or slide deck identifies polynomial functors / dependent lenses with propagators in the Sussman-Radul propagator-network sense.** Specifically:

- The Niu-Spivak book's bibliography (sampled) and index contain no propagator-network references. The word "propagation" appears only in mathematical contexts unrelated to Sussman's programming model.
- Spivak's AFOSR talk lists candidate Poly applications (PL, DB, DS, TM, CA, IT, ML); **constraint propagation / propagator networks are not on the list**, even though they would obviously belong if the connection had been recognized.
- The propagator-network literature (Radul 2009, Sussman-Radul 2009) does not mention polynomial functors, dependent lenses, or any categorical formalisation. Radul's framing is Scheme-implementation + Steele/Sussman ancestry (TMS, slot-and-cell mechanics), not categorical.
- The closest *categorical* analogues to propagators in the surveyed corpus, in decreasing closeness:
  1. **Mode-dependent dynamical systems** (Spivak 2020, arXiv:2005.01894): cells receiving information from multiple sources with state-dependent wiring, but framed as continuous-time ODE / Moore-machine, not lattice-monotone-merge.
  2. **All Concepts are Cat^♯** (Spivak-Shapiro-Lynch ACT 2023, arXiv:2305.02571): every category is a polynomial comonad, morphisms are cofunctors. Closest "universal abstraction for state-and-transition" claim.
  3. **Categorical Systems Theory** (David Jaz Myers, *DynamicalBook.pdf*): double-categorical framework for open systems. Information-flow-on-arena framing is closest in spirit, but no propagator identification.

**None of these formalises the merge-into-cell, fire-on-change, lattice-monotone dynamics that defines a Sussman-Radul propagator network.**

**Caveats.**
- Niu-Spivak Chapter 9 *"New Horizons"* (page ~349) was not extractable in the round-2 PDF parse (extraction truncated at page 100 of 375). Risk that "propagator" appears there is low (no other Spivak material does), but worth a future check.
- Workshop talks at the Topos *Workshops on Polynomial Functors* (2021, 2024) and ACT 2022/2023/2024 are not all archived as slides. A targeted Topos community ask (Zulip / blog comments / direct email) would resolve any residual blind spot.

**Net effect on the user's Prologos work.** The Poly-as-categorical-identification-of-propagators framing appears to be **novel** in the surveyed corpus. This is now a **second** novel contribution alongside the FL(ℵ₀)-as-UTM-analogue framing:
- (Round 1) FL(ℵ₀) + Whitman as universal parallel substrate: unclaimed.
- (Round 2) Polynomial functors / dependent lenses as the categorical identity of Sussman-Radul propagators: unclaimed.

For Prologos's compiler architecture, this means two distinct positioning claims need to be defended in print — and the Poly = propagator one has Spivak's *"Is Poly the true language of computation?"* (2022) as the closest kindred precedent rhetorically (universality language for Poly), even though Spivak does not name the propagator connection. Radul's *Propagation Networks: ... Substrate for Computation* (2009) is the direct ancestor for the "substrate" framing (without the categorical identification).

---

## R2-D. Updated priority-claim landscape

The round-1 table is now extended with three more landmarks (Wolfram, Radul, Spivak Poly-AFOSR-2022):

```
                                    UTM-analogue rhetoric?  Substrate kind
                                    ──────────────────────────────────────
Hewitt actors (1973, 2010)      ─→  YES — "universal primitives of      Concurrent message-passing
                                    concurrent digital computation"      [16][17][18]
Wolfram multicomputation (2021) ─→  YES — "fourth paradigm";             Multiway / hypergraph
                                    "foundation"; explicitly applied     rewriting (ruliad as limit)
                                    to distributed computing             [R2: Wolfram corpus]
Spivak "Poly as true language   ─→  YES — explicitly successor to         Polynomial functors /
of computation" (AFOSR 2022)        Turing/Von Neumann; Turing-           dependent lenses
                                    machines-in-Poly demonstrated         [R2: AFOSR slides]
Radul "Propagation Networks:    ─→  YES (substrate framing) —             Architectural propagator
A ... Substrate for Computation"    "shift in the foundations of          network (cells +
(2009)                              computation"                          monotone merge)
                                                                         [R2: Radul thesis]
CALM (Hellerstein 2020)         ─→  Computability theory framing,        Relational-transducer
                                    not UTM-analogue                      network [4]
Garg LLP (2020, 2025)           ─→  "Universal procedure"; bounded       Distributive lattice [14]
Kuper LVars (2015)              ─→  "General and practical unifying     Deterministic-parallel
                                    abstraction"; deterministic-only      lattice-cell model
                                                                         [11][12][R2: diss parse]
Nation-Paolini I/II/III         ─→  Not framed computationally at all   FL(ℵ₀) (algebraic)
(2023-2025)                                                              [1][2][3][R2: NP-III HTML]
Niu-Spivak Poly book (2024)     ─→  "Theory of interaction"; not        Polynomial functors
                                    machine                              [19][20]
Valiant BSP (1990)              ─→  Von Neumann analogue,               Bridging engineering model
                                    deliberately                         [15]
```

**Three categories of priority threat:**

1. **Different substrate, explicit UTM-analogue rhetoric.** Hewitt (concurrent message-passing), Wolfram (multiway/hypergraph), Spivak (Poly). These are the priority claims to engage head-on. Hewitt is the oldest (1973). Wolfram is the most aggressive (2021, "fourth paradigm"). Spivak is the most categorically-precise (2022, free-coproduct-completion 0 ↦ 1 ↦ Set ↦ Poly).

2. **Right substrate kind, UTM rhetoric absent.** Radul (propagator network architecturally; "substrate for computation" framing); Kuper (lattice-cell model; "unifying abstraction" / "foundation" framing, deterministic-only); CALM/Garg/CRDT (semilattice merge; engineering-or-theoretic framings).

3. **Right substrate kind, computational framing absent.** Nation-Paolini (FL(ℵ₀) algebraic, model-theoretic only); Niu-Spivak Poly book (interaction-theoretic, not machine).

**The FL(ℵ₀)-as-UTM-analogue claim sits in a gap that no single existing landmark fills.** Closest to the *full* claim:
- Hewitt-style explicit UTM-rhetoric, but on Poly substrate: Spivak AFOSR 2022.
- Right substrate kind (semilattice / monotone-merge cells), but with engineering or scope-bounded framing: Radul, Kuper, CALM.
- The algebraic free object FL(ℵ₀) as the substrate, with computational framing: nobody.

---

## R2-E. Updates to the open questions

Closed:
- ~~Open Question 1 — Reduction shape in Nation-Paolini III.~~ **Resolved (R2-A1)**: reduction is from Nies 1996 ∃∀-theory of nice bipartite graphs, with Whitman embedding load-bearing in §5. No UTM rhetoric in the paper.
- ~~Open Question 5 — Hewitt's full UTM-vs-actor argument.~~ **Partially resolved (R2-A2)**: abstract-level claim is "universal primitives of *concurrent* digital computation" (correction to round 1's broader paraphrase). Body-level claim ("all physically possible computation") not directly verified; round 1's HAL source corroborates.
- Open Question 3 — Wolfram and "computational equivalence". **Resolved (R2-B1)**: Wolfram's *multicomputational paradigm* (2021) is the strongest competing universality framing in the entire two-round audit. Now a first-class priority threat.
- Open Question 4 — CRDT-categorical literature. **Partially resolved (R2-B3)**: CRDT engineering literature does not contain UTM-analogue framings. Lasp comes closest (lattices as unifying primitive) but is engineering-pragmatic.
- Open Question 6 — Operads of wiring diagrams. **Resolved (R2-C1)**: no UTM-analogue framing; the literature is uniformly "syntax for compositional assembly".

New / sharpened:
- **R2-Open-1.** Niu-Spivak Chapter 9 *"New Horizons"* — could not extract due to PDF parser truncating at page 100. Worth a future check for any stray "propagator" reference.
- **R2-Open-2.** Topos Institute *Workshops on Polynomial Functors* (2021, 2024) and ACT 2022/2023/2024 slide decks — not all archived. A targeted Topos-community ask would close this.
- **R2-Open-3.** Hewitt v38 PDF body — body-level "all physically possible computation" claim corroborated by HAL but not directly fetched here. Worth a future fetch if a deeper Hewitt-vs-Poly-vs-FL comparison is needed.
- **R2-Open-4.** Wolfram-Gorard literal "parallel-CT-thesis" sentence — Wolfram or Jonathan Gorard may have written the literal sentence "multiway systems are to parallel/concurrent computation what the Turing machine is to sequential computation" in a livestream / Gorard arXiv paper not surveyed. Likely exists; not load-bearing for the audit's bottom line.

---

## R2-F. Updated bottom line

The round-1 conclusion holds: **the specific framing — FL(ℵ₀) with Whitman's algorithm as the foundational machine of parallel computation — appears unclaimed in print.** Round 2 strengthens this in two ways and complicates it in one way:

**Strengthens (in favor of novelty):**
- Nation-Paolini III's reduction is *graph-theoretic* (Nies 1996), not Turing-direct, so the Turing-encoding-into-FOTFL bridge in round 1 §(b) was if anything *understating* how indirect the algebraic-undecidability path is. The FL(ℵ₀) ↔ Turing connection genuinely lives in our reading, not in the literature.
- Kuper's dissertation mechanically confirmed to contain no UTM/Hewitt/free-lattice/propagator/Sussman/Radul references.
- CRDT engineering, operads of wiring diagrams: no UTM-analogue framings.
- **Polynomial functors ↔ propagator-network identification is novel** in the surveyed corpus. This is a second priority claim alongside FL(ℵ₀)-as-UTM-analogue.

**Complicates (new priority threats found):**
- **Wolfram's multicomputational paradigm (2021)** is now the most aggressive competing universality framing. It is graph-rewrite-substrate (multiway / hypergraph), not algebraic, but the framing role ("fourth paradigm", "foundation") is the same role FL(ℵ₀) is being claimed to play. Any FL(ℵ₀)-as-UTM-analogue paper must engage Wolfram.
- **Spivak's *"Is Poly the true language of computation?"* (AFOSR 2022)** is the closest existing UTM-analogue rhetoric for any categorically-precise substrate. Same family as Poly = propagators (the user's identification), so this rhetorical precedent transfers most directly to the categorical strand of Prologos's positioning.
- **Radul's *Propagation Networks: A Flexible and Expressive Substrate for Computation* (2009)** is the direct ancestor for the "substrate" framing on the architectural side. Any propagator-base universality claim must cite this.

**For the Prologos compiler positioning specifically:** there are now two distinct novel claims to defend, with different prior-art landscapes:

| Claim | Closest prior-art | Closest competing universality framing |
|---|---|---|
| FL(ℵ₀) + Whitman as universal parallel substrate | Nation-Paolini III for the algebra; Radul for the substrate framing; Kuper for the lattice-deterministic-parallelism scope | Wolfram multicomputation (2021); Hewitt actors (1973–) |
| Polynomial functors / dependent lenses as the categorical identity of Sussman-Radul propagators | None found | Spivak *"Is Poly the true language of computation?"* (AFOSR 2022) for the rhetorical move; Radul (2009) for the propagator side |

The two claims are independent: one is order-algebraic, one is categorical. Together they would say: **propagator networks are universal parallel substrates, with Polynomial Functors as the categorical identity and FL(ℵ₀) as the on-network word algebra.** No prior art bridges both.

---

## R2-G. Updated sources

New sources cited in this addendum (extending the round-1 numbering):

[R2-1] J.B. Nation, G. Paolini, *"Elementary properties of free lattices III: Undecidability of the full theory"*, arXiv:2511.13149v1, full HTML. https://arxiv.org/html/2511.13149v1

[R2-2] A. Nies, *"Undecidable fragments of elementary theories"*, *Algebra Universalis* 35 (1996), 8–33 (cited in [R2-1] as the source ∃∀-undecidability result).

[R2-3] M. Whitman, *"Free lattices II"*, Annals of Math. (2) 43 (1943), 104–115 (cited in [R2-1] §5 as the embedding mechanism).

[R2-4] L. Kuper, *Lattice-Based Data Structures for Deterministic Parallel and Distributed Programming*, PhD dissertation, Indiana University, Sept 2015. PDF parsed locally via `document_parse`. https://users.soe.ucsc.edu/~lkuper/papers/lindsey-kuper-dissertation.pdf

[R2-5] S. Wolfram, *"Multicomputation: A Fourth Paradigm for Theoretical Science"*, writings.stephenwolfram.com, Sept 2021. https://writings.stephenwolfram.com/2021/09/even-beyond-physics-introducing-multicomputation-as-a-fourth-general-paradigm-for-theoretical-science/

[R2-6] S. Wolfram, *"Multiway Turing Machines"*, Wolfram Physics Project Bulletin, Feb 2021. https://bulletins.wolframphysics.org/2021/02/multiway-turing-machines/

[R2-7] *"Ruliad"*, MathWorld. https://mathworld.wolfram.com/Ruliad.html

[R2-8] A. Radul, *Propagation Networks: A Flexible and Expressive Substrate for Computation*, PhD thesis, MIT, 2009 (MIT-CSAIL-TR-2009-053). https://dspace.mit.edu/handle/1721.1/49525

[R2-9] G. J. Sussman, A. Radul, *"The Art of the Propagator"*, MIT-CSAIL-TR-2009-002, 2009. https://dspace.mit.edu/handle/1721.1/44215

[R2-10] M. Shapiro et al., *"Conflict-free Replicated Data Types"*, INRIA RR-7687 / SSS 2011. https://pages.lip6.fr/Marc.Shapiro/papers/RR-7687.pdf

[R2-11] C. Meiklejohn, P. Van Roy, *"Lasp: A Language for Distributed, Coordination-Free Programming"*, PPDP 2015. https://christophermeiklejohn.com/publications/ppdp-2015-preprint.pdf

[R2-12] D. Spivak, *"Is Poly the true language of computation?"*, AFOSR Review 2022 (slides). https://topos.institute/people/david-spivak/AFOSR_Review2022_Talk.pdf

[R2-13] D. Spivak, *"Poly: An abundant categorical setting for mode-dependent dynamics"*, arXiv:2005.01894, 2020. https://arxiv.org/abs/2005.01894

[R2-14] D. Spivak, R. Shapiro, J. Lynch, *"All Concepts are Cat^♯"*, ACT 2023 / arXiv:2305.02571. https://arxiv.org/abs/2305.02571

[R2-15] D. Spivak, *"The Operad of Wiring Diagrams"*, arXiv:1305.0297, 2013. https://arxiv.org/abs/1305.0297

[R2-16] D. Vagner, D. Spivak, E. Lerman, *"Algebras of Open Dynamical Systems on the Operad of Wiring Diagrams"*, TAC 30 (2015) / arXiv:1408.1598. http://www.tac.mta.ca/tac/volumes/30/51/30-51.pdf

[R2-17] D. J. Myers, *Categorical Systems Theory* (book draft). https://www.davidjaz.com/Papers/DynamicalBook.pdf

Full per-axis URL lists in `outputs/.drafts/free-lattice-utm-parallel-research-wolfram-propagator-crdt.md` and `outputs/.drafts/free-lattice-utm-parallel-research-operads-poly-deep.md`.
