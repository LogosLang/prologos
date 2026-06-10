# FL(ℵ₀) + Whitman as a Universal Parallel Computational Substrate: A Priority-Claim Audit

**Question.** Has anyone in the literature **explicitly framed** the free lattice on countably many generators FL(ℵ₀), with Whitman's decision procedure, as a **universal computational substrate for parallel computation analogous to the Universal Turing Machine (UTM)**?

**Date:** 2026-05-08.
**Method.** Three parallel researcher passes covering (a) Endrullis-Shallit-Smith and follow-ups, (b) Nation-Paolini and FOTFL decidability, (c) CALM/Bloom/Dedalus, (d) Garg lattice-linear predicate detection, (e) Kuper LVars, (f) BSP/PRAM/dataflow/Petri/actor universal-substrate proposals, (g) categorical foundations (Spivak Poly, geometry of interaction). Sources are abstracts, HTML pages, official journal pages, blog posts, and talk notes — full PDFs were not parsed (per workflow). All quoted text is verbatim from the cited HTML or abstract pages; inferences are flagged.

---

## Executive summary

**No source surveyed explicitly frames FL(ℵ₀) + Whitman's decision procedure as a UTM analogue for parallel computation.** The exact framing in the question appears to be **unclaimed in print**.

Three weaker / adjacent framings exist and are the prior-art landmarks anyone proposing the FL(ℵ₀)-as-UTM-analogue thesis must engage:

1. **Nation-Paolini's free-lattice trilogy (2023–2025)** [1][2][3]. They prove that the *full* first-order theory of any free lattice F_κ (κ ≥ 3) is undecidable [3], while the universal/existential fragment is decidable [2]. This is a Tarski-style demarcation that *implies* Turing computation can be encoded in FOTFL — i.e., FL(ℵ₀) *is* (in a model-theoretic sense) computationally rich enough to be a universal substrate. But Nation and Paolini do not phrase it that way. The framing is "we resolved an open problem about the algebraic theory of free lattices."

2. **The CALM theorem** (Hellerstein-Alvaro 2020 [4] and predecessors [5][6][7]). Explicitly framed as "a computability theory for distributed systems," with monotonicity as the demarcation principle. CALM is the closest existing "parallel computability theorem" in the literature — but the *substrate* is Ameloot's relational transducer network [7], not a lattice. Lattices appear as the *type system* (BloomL [6]) and as the *property* (monotonicity) that demarcates coordination-free distributed computability.

3. **Hewitt's actor model** [16][17]. The single instance found in the entire parallel-/concurrent-computation literature where the creator explicitly and repeatedly pitches the model as a UTM analogue: actors are "the universal conceptual primitives of digital computation," and "all physically possible computation can be directly implemented using Actors" [17]. This is the explicit precedent — but on a different substrate.

The closest **lattice-flavored** "foundation / unifying abstraction" framing is **Kuper's LVars thesis** [11][12][13]: "lattice-based data structures are a general and practical foundation for deterministic and quasi-deterministic parallel and distributed programming" [11]. This is foundational-flavored and explicitly subsumes prior deterministic-parallel models (IVars, Kahn networks, pure FP, disjoint imperative parallelism) [12], but is bounded to *deterministic* parallelism and does not invoke Turing/Church-Turing rhetoric.

**Bottom line for priority claim.** The specific framing — *FL(ℵ₀) with Whitman's algorithm as the foundational machine of parallel computation* — appears novel. The closest precedents are:
- **Nation-Paolini III** (Nov 2025) [3] for the *algebraic* fact (Th(F_κ) undecidable);
- **CALM** [4] for the *computability-theoretic* spirit applied to distributed systems;
- **Kuper LVars** [11][12] for the *lattices-as-foundation-of-deterministic-parallelism* spirit;
- **Hewitt actors** [16][17] for the *explicit UTM-analogue rhetoric* (on a different substrate).

---

## Findings by sub-area

### (a) Endrullis-Shallit-Smith 2017 and follow-ups

**Verdict: ABSENT.**

Endrullis, Shallit, Smith, *"Undecidability and Finite Automata"* (DLT 2017, LNCS 10396, pp. 160–172; arXiv:1702.01394) [21]. Verbatim abstract: *"Using a novel rewriting problem, we show that several natural decision problems about finite automata are undecidable (i.e., recursively unsolvable). In contrast, we also prove three related problems are decidable. We apply one result to prove the undecidability of a related problem about k-automatic sets of rational numbers."* [21][22].

The paper is a classical undecidability-by-reduction result targeting finite-automaton decision problems. Endrullis's own homepage describes it as "we give some examples of undecidable properties [of finite automata]" [23] — explicitly framed as a catalog, not a universality claim. No mention of lattices, Whitman's condition, free algebras, or universality framing in the abstract or in the homepage description.

A related Endrullis-Grabmayer-Hendriks paper (arXiv:1501.04835) makes a *negative-control* observation that "deterministic finite-state automata would be equally powerful as Turing-machine deciders" given unrestricted (non-computable) encodings [24] — explicitly flagged as a cautionary point about encodings, not a UTM-analogue claim for any algebraic structure.

**Forward-citation pass not run.** The surveyed material did not surface any follow-up that lifts the ESS 2017 rewriting problem into a lattice or free-algebra setting.

### (b) Nation-Paolini and FOTFL decidability

**Verdict: ADJACENT — the strongest signal in the entire survey.**

A three-paper series resolves the elementary theory of free lattices in 2023–2025:

- **Paper I** [1]: Nation & Paolini, *"Elementary Properties of Free Lattices"* (arXiv:2310.03366, Oct 2023; *Forum Mathematicum*, May 2024, doi:10.1515/forum-2023-0358). Verbatim from abstract: *"We start a systematic analysis of the first-order model theory of free lattices … for any lattice K which satisfies Whitman's condition (W) and which is generated by join prime elements, the three lattices K, DM(K), and Id(K) all share the same positive universal first-order theory."* Whitman's condition (W) appears as the structural hypothesis pinning down the positive-universal theory shared by K, its Dedekind-MacNeille completion DM(K), and its ideal lattice Id(K).

- **Paper II** [2]: Nation & Paolini, *"Elementary properties of free lattices II: Decidability of the universal theory"* (arXiv:2504.09128, Apr 2025). Verbatim abstract: *"Our main result is that the universal (existential) theory of infinite free lattices is decidable."* This is the algorithmic lift of Skolem 1920 / Whitman 1941 [9] to the universal fragment of FOTFL on FL(ℵ₀)-flavored objects.

- **Paper III** [3]: Nation & Paolini, *"Elementary properties of free lattices III: Undecidability of the full theory"* (arXiv:2511.13149, Nov 2025). Verbatim abstract: *"In [paper II] we proved that the universal theory of infinite free lattices is (algorithmically) decidable, leaving open the problem of decidability of the full theory of an (infinite) free lattice. We solve this problem by proving that, for every cardinal κ ≥ 3, the first-order theory of the free lattice F_κ is undecidable."*

**Why this matters for the priority claim.** Undecidability of the full first-order theory of an algebra is, in standard logic, *equivalent in spirit* to "Turing computation can be encoded into the first-order theory of that algebra." This is precisely the model-theoretic content of "FL(ℵ₀) is a universal computational substrate." But Nation and Paolini do not phrase it that way; their framing is "we resolve an open problem about the algebraic theory of free lattices."

**Historical context.** Skolem 1920 first showed the universal first-order theory of lattices is decidable (a result that "seems to have gone unnoticed by lattice theorists" — Freese-Ježek-Nation, *Free Lattices*, AMS Mathematical Surveys & Monographs 42, 1995, recovered by Stan Burris) [9]. Whitman 1941 gave the structural decision procedure now called Whitman's condition. Bloniarz-Hunt-Rosenkrantz 1988 (*Information and Computation*) [10] classified the complexity: the uniform word problem and the generator problem for free lattices are in deterministic logarithmic space; the more general open-formula validity problem for all lattices is co-NP-complete. None of these classical sources frame the result as "FL is a universal computational substrate."

**Adjacent direction.** A separate body of work in computability theory embeds finite *lattices* into the c.e. Turing degrees and Σ⁰₂ enumeration degrees [25] — the *converse* of the framing we are auditing.

**Blocked check.** Nation-Paolini III's reduction shape (what undecidable problem they reduce from — group/semigroup word problem, Hilbert's 10th, direct Turing halting?) is not visible from the abstract. Confirming would require parsing the PDF of arXiv:2511.13149 [3], which the workflow defers.

### (c) CALM theorem; Bloom; Dedalus

**Verdict: ADJACENT — closest existing "parallel computability theorem" framing.**

**Hellerstein & Alvaro, *"Keeping CALM: When Distributed Consistency Is Easy"*, CACM 63(9), Sept 2020** [4]. Verbatim:
> "Distributed systems deserve a computability theory: When is coordination required for consistency, and when can it be avoided?"
> "**THEOREM 1. Consistency As Logical Monotonicity (CALM).** A problem has a consistent, coordination-free distributed implementation if and only if it is monotonic."
> "Hence our Question is one of computability, like P vs. NP or Decidability."

**Reverse direction proved by Ameloot, Neven, Van den Bussche, *"Relational Transducers for Declarative Networking"*, JACM 60(2), 2013** [7] — a query is computable by a coordination-free relational transducer network iff it is monotone (paraphrased in [4]; see also [8] for follow-up).

**Hellerstein, *"The Declarative Imperative: Experiences and Conjectures in Distributed Logic"*, SIGMOD Record 39(1), 2010** [5] — argues Datalog "can serve as the rootstock of [a] family of languages for programming serious parallel and distributed software."

**Conway, Marczak, Alvaro, Hellerstein, Maier, *"Logic and Lattices for Distributed Programming"* (BloomL), SoCC 2012** [6] — introduces lattices as first-class state in Bloom, but as a *type system* layered over the relational-transducer model.

**What is and is not claimed.** CALM is a *characterisation* (iff), not a universality result. The framing is computability-theoretic in spirit and explicitly draws an analogy to "P vs. NP or Decidability" [4] — but the analogy lands on the demarcation question (*what is solvable*), not on the substrate question (*is this the universal parallel machine?*). The substrate Ameloot's theorem speaks to is the relational-transducer network. Lattices in BloomL appear as the *type system* for monotone state, not as the foundational machine. The phrase "Church-Turing" does not appear in the surfaced sources; the phrase "universal substrate" does not appear.

### (d) Garg's lattice-linear predicate detection (1992–2020)

**Verdict: ADJACENT — strongest "universal procedure" language found.**

- **Chase & Garg, *"Detection of Global Predicates: Techniques and Their Limitations"*, Distributed Computing 11(4), 1998** [27]. Establishes the lattice of consistent global states as the canonical model and predicate detection as NP-complete in general; introduces semi-linear predicates as a tractable subclass.
- **Garg, *"Predicate Detection to Solve Combinatorial Optimization Problems"*, SPAA 2020** [28]. Recasts a wide class of constrained combinatorial-optimization problems as searching for an element satisfying a lattice-linear predicate in a distributive lattice. LLP "can be implemented in parallel without any locks or compare-and-swap operations" [28].
- **Streit & Garg, *"Constrained Cuts, Flows, and Lattice-Linearity"* (arXiv:2512.18141, Dec 2025)** [14]. Verbatim:
  > "Lattice-linear predicate detection can be solved by a **universal procedure** admitting simple parallel algorithmic implementations."
  > "A key feature is the ability to analyze and solve a large variety of combinatorial problems in a unifying way."
- Garg's book *A Systematic Approach to Parallel Algorithms* [29] uses parallel framing: "many parallel (and sequential) algorithms can be derived in a systematic manner. In our approach, a problem is cast as searching for an element satisfying an appropriate predicate in a distributive lattice."

**What is and is not claimed.** "Universal procedure" [14] is the strongest UTM-spirited single phrase found in any axis except the actor model. But the universality is bounded to *the class of lattice-linear predicates on distributive lattices*. It is not posed as a universal substrate for parallel computation. No Turing/Church-Turing rhetoric is invoked.

### (e) Kuper's LVars

**Verdict: ADJACENT — strongest "lattices-as-foundation" claim.**

**Kuper's PhD thesis statement** (verbatim, *"My thesis proposal"*, blog post Nov 2013) [11]:
> "**Lattice-based data structures are a general and practical foundation for deterministic and quasi-deterministic parallel and distributed programming.**"

**Kuper dissertation defense talk** (verbatim) [12]:
> "[D]ifferent formalisms, and, one could argue, perhaps even different subfields of CS have been developed to deal with these two big problems [parallel and distributed]. So, it's useful to try to find unifying abstractions… **LVars are a general unifying abstraction for deterministic parallel programming.**"
> "All of those points in the space [pure FP, dataflow / Kahn networks, single-assignment IVars, disjoint imperative parallelism] are either subsumed by, or are compatible with, the LVars programming model."

**Kuper & Newton, *"LVars: Lattice-based Data Structures for Deterministic Parallelism"*, FHPC 2013** [13]. Verbatim: *"We present LVars, a new model for deterministic-by-construction parallel programming that **generalizes existing single-assignment models** to allow multiple assignments that are monotonically increasing with respect to a user-specified lattice."*

**Kuper, Turon, Krishnaswami, Newton, *"Freeze After Writing"*, POPL 2014** [26]. Adds principled non-monotonic events to LVars.

**What is and is not claimed.** "Foundation" and "general and practical unifying abstraction" appear verbatim [11][12]. LVars are explicitly shown to *subsume* multiple prior deterministic-parallel models — a *de facto* universality argument within scope. But:
1. The scope is explicitly *deterministic-by-construction* parallelism. Nondeterministic parallel computation is outside the model's claim.
2. No Turing/Church-Turing analogy is invoked. The word "universal" does not appear as the thesis claim; the words used are "general", "unifying", "foundation".
3. No claim that arbitrary parallel computations can be *encoded* into monotone-lattice form (which a UTM-analogue would require).

### (f) BSP / PRAM / dataflow / Petri / actors

| Model | UTM-analogue claim? | Stated framing | Source |
|---|---|---|---|
| BSP (Valiant 1990) | No | Explicit *von Neumann* analogue ("bridging model"); engineering-universal, not computability-universal | [15] |
| PRAM (Fortune-Wyllie 1978) | No | "Idealized model of a shared memory SIMD machine" / "generalization of RAM" | [30][31] |
| Goldschlager 1982 | Yes (within complexity-theoretic frame) | "A universal interconnection pattern for parallel computers" — designed to make the parallel computation thesis provable | [32] |
| Parallel computation thesis (Chandra-Stockmeyer 1976) | Quantitative bridge | parallel-time ↔ sequential-space, polynomially; *"not a rigorous formal statement"* | [32] |
| Kahn process networks | No | Fixpoint *semantics* of deterministic dataflow; "Kahn principle" = determinism, not universality | [33][34] |
| Dennis / Arvind dataflow | No | One MoC among several | (general literature) |
| Plain Petri nets | No (decidable reachability) | Concurrency model | (general literature) |
| Inhibitor / Sleptsov / arithmetic Petri nets | Turing-complete extensions exist | Universal *Petri net* constructions framed as Turing-completeness of *extensions*, not as electing a foundational parallel substrate | [35][36][37] |
| **Actors (Hewitt 1973; 2010)** | **Yes — explicit and sustained** | *"Universal conceptual primitives of digital computation"*; *"All physically possible computation can be directly implemented using Actors"* | [16][17][18] |
| π-calculus / CCS / CSP | Implicit | *Calculi* of communicating systems | [38][39] |

**Verbatim quote, Valiant 1990, *"A bridging model for parallel computation"*, CACM 33(8)** [15]:
> "The success of the von Neumann model of sequential computation is attributable to the fact that it is an efficient bridge between software and hardware … an analogous bridge between software and hardware is required for parallel computation if that is to become as widely used."

Valiant explicitly framed BSP as "neither hardware nor programming model, but something in between" [15] (paraphrased in The Morning Paper summary [40]). The analogy is **von Neumann**, not Turing. BSP is "universally efficient" in the engineering sense (compilable from many languages onto many machines), not universal in the computability/UTM sense.

**Verbatim quote, Hewitt-Bishop-Steiger 1973, *"A Universal Modular ACTOR Formalism for Artificial Intelligence"*, IJCAI 1973** [16] — the title carries "Universal" already. Abstract: *"This paper proposes a modular ACTOR architecture and definitional method for artificial intelligence that is conceptually based on a single kind of object: actors."*

**Verbatim quote, Hewitt, *"Actor Model of Computation"*, arXiv:1008.1459 / HAL hal-01163534v6** [17]:
> "The Actor Model is a mathematical theory that treats 'Actors' as **the universal conceptual primitives of digital computation.** Hypothesis: All physically possible computation can be directly implemented using Actors."

Hewitt also explicitly argues the standard Church-Turing thesis "no longer applied to computation in practice because computer systems are highly interactive as they compute" (*"Physical Indeterminacy in Digital Computation"*, SSRN abstract) [18], motivating actors as the replacement foundation.

**Synthesis.** The user's hypothesis — that the parallel-computation community has *not* converged on a UTM analogue — is supported. Valiant deliberately picked the *von Neumann* analogy [15]. PRAM is "RAM in parallel" [30][31]. Kahn is *semantics* [33][34]. Petri-universality is Turing-completeness of *extensions* [35][36]. Process algebras are *calculi* [38][39]. The single sustained explicit dissent is Hewitt's actor program [16][17][18].

### (g) Categorical foundations — Spivak Poly, geometry of interaction

**Verdict: ABSENT (in surfaced material) — but structurally adjacent.**

- **Niu & Spivak, *"Polynomial Functors: A Mathematical Theory of Interaction"* (arXiv:2312.00990; CUP forthcoming)** [19][20]. Verbatim arXiv abstract:
  > "This monograph is a study of the category of polynomial endofunctors on the category of sets and its applications to modeling interaction protocols and dynamical systems."

  Verbatim CUP page [20]:
  > "Everywhere one looks, one finds dynamic interacting systems… In this book, the authors give a new syntax for modeling such systems, describing a mathematical theory of interfaces and the way they connect."

  Topos Institute preface [41]: at ACT 2022, "at least twelve of the fifty-nine presentations and two of the ten posters referenced the category of polynomial functors and dependent lenses."

- **Geometry of interaction (Girard; Abramsky-Haghverdi-Scott; Haghverdi-Scott)** [42][43][44].
  > "Girard's Geometry of Interaction (GoI) is a program that aims at giving mathematical models of algorithms **independently of any extant languages**." [42]
  > "Geometry of Interaction is based on the idea that the ultimate explanation of logical rules is through the cut-elimination procedure …" [43]

**What is and is not claimed.** Spivak Poly is pitched as "a mathematical theory of interaction" / "new syntax for modeling interacting systems" — foundational ambition, but as *theory*, not as *machine*. GoI is explicitly *language-independent semantics of cut-elimination*, not a universal parallel machine. Neither uses UTM-analogue rhetoric in surfaced material.

**Inference (flagged).** Poly is structurally a strong candidate for a UTM-analogue framing (single uniform substrate, expressive enough for both dynamical systems and interaction protocols, with dependent-lens composition as the primitive operation). The rhetorical gap is open.

---

## Cross-cutting observations

1. **The word "universal" applied to the model itself appears in only two places** in the entire survey: Hewitt 1973 ("Universal Modular ACTOR Formalism" [16]) and Goldschlager 1982 ("universal interconnection pattern" [32]). Streit-Garg 2025 use "universal procedure" [14] — applied to the *predicate-detection algorithm*, not the lattice substrate.
2. **The word "foundation" applied to the model appears in:** Hellerstein 2010 (Datalog as foundation [5]), Kuper 2013 (lattice-based data structures as foundation [11]).
3. **No paper or talk in the entire survey uses "Church-Turing", "Turing machine analogue", or "parallel Church-Turing thesis" in connection with monotone / lattice / semilattice computation.** The closest is Hellerstein-Alvaro 2020's "Distributed systems deserve a computability theory" [4] — invoking computability theory, not Church-Turing.
4. **Three independent traditions converge on a shared mathematical kernel** — monotone functions over join-semilattices with idempotent/commutative merge — without ever being unified under a UTM-analogue framing:
   - Distributed-systems coordination (CALM/Bloom) [4][6]
   - Lattice-linear predicate detection (Garg) [14][27][28]
   - Deterministic parallelism (Kuper LVars) [11][12][13]
5. **The lattice-theoretic underpinnings exist but are presented as algebra / model theory, not computation:** Skolem 1920, Whitman 1941, Freese-Ježek-Nation 1995 [9], Bloniarz-Hunt-Rosenkrantz 1988 [10], Nation-Paolini 2023–2025 [1][2][3].
6. **The single explicit and sustained UTM-analogue claim** in any parallel/concurrent model is Hewitt's actor model [16][17][18].

## What is unclaimed and why this matters

The question asked for an *explicit* framing of FL(ℵ₀) + Whitman as a UTM analogue for parallel computation. None was found.

The closest convergent picture:

```
                              UTM analogue rhetoric?
                              ────────────────────────
Hewitt actors            ─→   YES (the only sustained example)        [16][17][18]
CALM (Hellerstein)       ─→   "computability theory"; not UTM-analogue [4]
Garg LLP                 ─→   "universal procedure"; bounded            [14]
Kuper LVars              ─→   "general and practical foundation";
                              deterministic-only                       [11][12]
Nation-Paolini FL theory ─→   not framed computationally at all        [1][2][3]
Spivak Poly              ─→   "theory of interaction"; foundational,
                              not machine                              [19][20]
Valiant BSP              ─→   *von Neumann* analogue, deliberately     [15]
```

For an FL(ℵ₀)-as-UTM-analogue claim to be defensible as new work, it would need to bridge two facts that already exist *separately* in the literature:

- (A) Th(F_κ) is undecidable for κ ≥ 3 (Nation-Paolini III, Nov 2025) [3], so first-order FOTFL is computationally rich enough to encode Turing computation.
- (B) Monotone-lattice / semilattice computation is the convergent kernel of CALM / Garg LLP / Kuper LVars / BloomL [4][6][14][11] — three independent parallel-computation traditions.

The synthesis — that FL(ℵ₀) with Whitman's word-problem decision procedure as primitive and FOTFL as expressive layer is the candidate UTM analogue for parallel computation — does not appear to be in the literature, in either the lattice-theory tradition or the parallel-computation tradition. The framings closest in spirit are Hewitt's actor program (rhetoric, different substrate) and Kuper's LVars thesis (right substrate, bounded scope, no UTM rhetoric).

## Open questions

1. **Reduction shape in Nation-Paolini III** [3]. What undecidable problem is reduced from? Most likely candidates (group/semigroup word problem, Hilbert's 10th, direct halting) determine how natural the Turing-encoding into FOTFL is. *(Blocked: requires PDF parse of arXiv:2511.13149.)*
2. **Forward citations of ESS 2017** [21]. Does any follow-up to Endrullis-Shallit-Smith 2017 lift the rewriting problem into a lattice or free-algebra setting? The surveys conducted did not surface any; a forward Google Scholar / Semantic Scholar pass is the obvious next step.
3. **Wolfram and "computational equivalence."** Wolfram's *A New Kind of Science* (2002) makes broad computational-equivalence claims for cellular automata and rewriting systems. Did not search this venue; if an informal "lattice/rewriting as universal substrate" framing exists outside mathematical lattice-theory venues, it likely lives there.
4. **CRDT-categorical literature.** Lasp (Meiklejohn & Van Roy, PPDP 2015) and the broader CRDT-as-lattice formalisation work were not searched directly; a "universal substrate" framing in the eventually-consistent / CRDT / Riak ecosystem is possible but unsurveyed.
5. **Hewitt's full UTM-vs-actor argument** [17]. arXiv:1008.1459 contains the full case but only the abstract was surfaced. Worth a deeper read if the goal is to position FL(ℵ₀) as a *third* candidate after UTM (sequential) and Hewitt actors (parallel).
6. **Operads of wiring diagrams; Pratt's Chu spaces; Mazurkiewicz traces.** Not searched directly; foundational rhetoric there could bear on the categorical axis.

## What this audit does *not* establish

- It does not establish that the FL(ℵ₀)-as-UTM-analogue claim is *correct* — only that, as far as the surveyed material shows, it is *unclaimed*. The claim itself would still need to specify (i) the encoding from Turing tapes / parallel programs into FL(ℵ₀) words, (ii) which Whitman-decidable subset of FL plays the role of "halting / accepting state", (iii) what notion of universality is being claimed (computational, semantic, complexity-bridging, or rhetorical-foundational), and (iv) why this is preferable to the existing actor / Kahn / LVar foundations.
- It does not exhaustively cover all of: arXiv (only metadata-level), Wolfram literature, philosophy-of-CS literature, CRDT-engineering literature, propagator-network literature (Sussman/Radul). These are *gaps*, not negative results.

---

## Sources

### Free-lattice theory (Nation-Paolini and predecessors)

[1] J.B. Nation, L. Paolini, *"Elementary Properties of Free Lattices"*, Forum Mathematicum, doi:10.1515/forum-2023-0358, May 2024 (arXiv:2310.03366, Oct 2023). https://arxiv.org/abs/2310.03366 ; https://www.degruyter.com/document/doi/10.1515/forum-2023-0358/html

[2] J.B. Nation, L. Paolini, *"Elementary properties of free lattices II: Decidability of the universal theory"*, arXiv:2504.09128, Apr 2025. https://arxiv.org/abs/2504.09128

[3] J.B. Nation, L. Paolini, *"Elementary properties of free lattices III: Undecidability of the full theory"*, arXiv:2511.13149, Nov 2025. https://arxiv.org/abs/2511.13149

[9] R. Freese, J. Ježek, J.B. Nation, *Free Lattices*, AMS Mathematical Surveys & Monographs 42, 1995. Draft chapters online: https://math.hawaii.edu/~ralph/Classes/649M/FreeLatChap.pdf ; https://math.hawaii.edu/~ralph/Classes/649M/freelat.pdf

[10] P. Bloniarz, H. Hunt III, D. Rosenkrantz, *"The word and generator problems for lattices"*, *Information and Computation* 81 (1988). https://research.ibm.com/publications/the-word-and-generator-problems-for-lattices

[25] MaRDI portal entry, *"Lattice representations for computability theory"*. https://portal.mardi4nfdi.de/wiki/Lattice_representations_for_computability_theory

### Endrullis-Shallit-Smith and follow-ups

[21] J. Endrullis, J. Shallit, T. Smith, *"Undecidability and Finite Automata"*, DLT 2017, LNCS 10396 (arXiv:1702.01394). https://arxiv.org/abs/1702.01394

[22] Springer landing page for [21]. https://link.springer.com/chapter/10.1007/978-3-319-62809-7_11

[23] J. Endrullis, "Finite-State Transducers" research page. https://joerg.endrullis.de/research/finite-state-transducers/

[24] J. Endrullis, C. Grabmayer, D. Hendriks, *"Notions of computability by finite-state automata"*, arXiv:1501.04835. https://arxiv.org/abs/1501.04835

### CALM, Bloom, Dedalus

[4] J. M. Hellerstein, P. Alvaro, *"Keeping CALM: When Distributed Consistency Is Easy"*, CACM 63(9), Sept 2020. https://cacm.acm.org/research/keeping-calm/ ; arXiv preprint: https://arxiv.org/abs/1901.01930

[5] J. M. Hellerstein, *"The Declarative Imperative: Experiences and Conjectures in Distributed Logic"*, SIGMOD Record 39(1), 2010. https://dsf.berkeley.edu/papers/sigrec10-declimperative.pdf

[6] N. Conway, W. Marczak, P. Alvaro, J. M. Hellerstein, D. Maier, *"Logic and Lattices for Distributed Programming"* (BloomL), SoCC 2012. https://dsf.berkeley.edu/papers/UCB-lattice-tr.pdf ; https://dsf.berkeley.edu/bloom-lattice/

[7] T. J. Ameloot, F. Neven, J. Van den Bussche, *"Relational Transducers for Declarative Networking"*, JACM 60(2), 2013. https://dl.acm.org/doi/10.1145/1989284.1989321

[8] D. Zinn, T. J. Green, B. Ludäscher, *"Win-move is coordination-free (sometimes)"*, ICDT 2012. https://dl.acm.org/doi/10.1145/2274576.2274588

### Garg lattice-linear predicate detection

[14] N. Streit, V. K. Garg, *"Constrained Cuts, Flows, and Lattice-Linearity"*, arXiv:2512.18141, Dec 2025. https://arxiv.org/html/2512.18141v1

[27] C. Chase, V. K. Garg, *"Detection of Global Predicates: Techniques and Their Limitations"*, *Distributed Computing* 11(4), 1998. https://link.springer.com/article/10.1007/s004460050049

[28] V. K. Garg, *"Predicate Detection to Solve Combinatorial Optimization Problems"*, SPAA 2020. https://par.nsf.gov/servlets/purl/10190128 ; https://users.ece.utexas.edu/~garg/topics/detection-desc.html

[29] V. K. Garg, *A Systematic Approach to Parallel Algorithms* (book page). https://users.ece.utexas.edu/~garg/algo.html

### Kuper LVars

[11] L. Kuper, *"My thesis proposal"*, blog post Nov 2013. https://decomposition.al/blog/2013/11/30/my-thesis-proposal-and-my-second-hacker-school-residency/

[12] L. Kuper, dissertation defense talk notes, 2014. https://github.com/lkuper/dissertation/blob/master/talks/defense.md

[13] L. Kuper, R. R. Newton, *"LVars: Lattice-based Data Structures for Deterministic Parallelism"*, FHPC 2013. https://users.soe.ucsc.edu/~lkuper/papers/lvars-fhpc13.pdf

[26] L. Kuper, A. Turon, N. R. Krishnaswami, R. R. Newton, *"Freeze After Writing: Quasi-Deterministic Parallel Programming with LVars"*, POPL 2014. https://users.soe.ucsc.edu/~lkuper/papers/lvish-popl14.pdf

### BSP / PRAM / dataflow / Petri / actors

[15] L. G. Valiant, *"A bridging model for parallel computation"*, CACM 33(8), 1990. https://dl.acm.org/doi/10.1145/79173.79181

[40] A. Colyer, summary of Valiant 1990, *The Morning Paper*, 2015. https://blog.acolyer.org/2015/06/08/a-bridging-model-for-parallel-computation/

[16] C. Hewitt, P. Bishop, R. Steiger, *"A Universal Modular ACTOR Formalism for Artificial Intelligence"*, IJCAI 1973. https://www.ijcai.org/Proceedings/73/Papers/027B.pdf

[17] C. Hewitt, *"Actor Model of Computation: Scalable Robust Information Systems"*, arXiv:1008.1459 / HAL hal-01163534v6. https://arxiv.org/abs/1008.1459 ; https://hal.science/hal-01163534v6

[18] C. Hewitt, *"Physical Indeterminacy in Digital Computation"*, SSRN. https://papers.ssrn.com/sol3/papers.cfm?abstract_id=3459566

[30] A. Karp, V. Ramachandran, *"A Survey of Parallel Algorithms for Shared-Memory Machines"*, UC Berkeley TR CSD-88-408, 1988. https://www2.eecs.berkeley.edu/Pubs/TechRpts/1988/CSD-88-408.pdf

[31] P. Tvrdík, parallel-algorithms lecture notes (PRAM). https://pages.cs.wisc.edu/~tvrdik/2/html/Section2.html

[32] Wikipedia, *"Parallel computation thesis"* (covers Goldschlager 1982 and Chandra-Stockmeyer 1976). https://en.wikipedia.org/wiki/Parallel_computation_thesis

[33] *"Kahn process networks and reactive process networks"*, Computational Modeling Work-Bench. https://computationalmodeling.info/static-wp/models/kahn-process-networks-and-reactive-process-networks/

[34] *"Linear dynamic Kahn networks are deterministic"*, Springer LNCS 1126, 1996. https://link.springer.com/chapter/10.1007/3-540-61550-4_152

[35] *"Universal Petri net"* (inhibitor construction), Cybernetics and Systems Analysis, 2012. https://link.springer.com/article/10.1007/s10559-012-9429-4

[36] *"Small Polynomial Time Universal Petri Nets"*, arXiv:1309.7288. https://arxiv.org/abs/1309.7288

[37] *"Computability power of an extended Petri net model (APN)"*, NPSC 24. https://acadsol.eu/npsc/24/1-4/3

[38] R. Milner, J. Parrow, D. Walker, *"A Calculus of Mobile Processes I"*, Information and Computation 100, 1992. https://www.sciencedirect.com/science/article/pii/0890540192900084

[39] R. Milner, *"The Polyadic π-Calculus: a Tutorial"* (Springer chapter). https://link.springer.com/chapter/10.1007/978-3-642-58041-3_6

### Categorical foundations

[19] N. Niu, D. I. Spivak, *"Polynomial Functors: A Mathematical Theory of Interaction"*, arXiv:2312.00990, 2023. https://arxiv.org/abs/2312.00990

[20] CUP book page for [19]. https://www.cambridge.org/core/books/polynomial-functors/5A57527AE303503CDCC9B71D3799231F

[41] Topos Institute open-source preface for [19]. https://toposinstitute.github.io/poly/poly-book.pdf

[42] E. Haghverdi, *"Geometry of Interaction tutorial"*. https://cgi.luddy.indiana.edu/~ehaghver/Tutorial.pdf

[43] J.-Y. Girard, *"Geometry of Interaction"*, Springer chapter. https://link.springer.com/chapter/10.1007/978-3-540-48654-1_1

[44] S. Abramsky, E. Haghverdi, P. Scott, *"Geometry of interaction and linear combinatory algebras"*, MSCS. https://www.cambridge.org/core/journals/mathematical-structures-in-computer-science/article/abs/geometry-of-interaction-and-linear-combinatory-algebras/983F3238099D7BCBC9FAA3BC9ABBAD51 ; E. Haghverdi, P. Scott, *"A categorical model for the geometry of interaction"*, TCS. https://www.sciencedirect.com/science/article/pii/S0304397505006808
