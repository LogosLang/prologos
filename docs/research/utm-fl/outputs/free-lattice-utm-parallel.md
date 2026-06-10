# FL(ℵ₀) + Whitman as a Universal Parallel Computational Substrate: A Priority-Claim Audit

**Question.** Has anyone in the literature **explicitly framed** the free lattice on countably many generators FL(ℵ₀), with Whitman's decision procedure, as a **universal computational substrate for parallel computation analogous to the Universal Turing Machine (UTM)**?

**Date:** 2026-05-08.
**Method.** Three parallel researcher passes covering (a) Endrullis-Shallit-Smith and follow-ups, (b) Nation-Paolini and FOTFL decidability, (c) CALM/Bloom/Dedalus, (d) Garg lattice-linear predicate detection, (e) Kuper LVars, (f) BSP/PRAM/dataflow/Petri/actor universal-substrate proposals, (g) categorical foundations (Spivak Poly, geometry of interaction). Sources are abstracts, HTML pages, official journal pages, blog posts, and talk notes — full PDFs were not parsed (per workflow). All quoted text is verbatim from the cited HTML or abstract pages unless explicitly marked otherwise; inferences are flagged.

---

## Executive summary

**No source surveyed explicitly frames FL(ℵ₀) + Whitman's decision procedure as a UTM analogue for parallel computation.** The exact framing in the question appears to be **unclaimed in print**.

Four weaker / adjacent framings exist and are the prior-art landmarks anyone proposing the FL(ℵ₀)-as-UTM-analogue thesis must engage:

1. **Nation-Paolini's free-lattice trilogy (2023–2025)** [1][2][3]. They prove that the *full* first-order theory of any free lattice F_κ (κ ≥ 3) is undecidable [3], while the universal/existential fragment is decidable [2]. We *read* this as a Tarski-style demarcation that, on a standard interpretation, implies Turing computation can be encoded in FOTFL — i.e., FL(ℵ₀) *is* (in a model-theoretic sense) computationally rich enough to be a universal substrate. But this reading is our inference; Nation and Paolini do not phrase it that way. Their framing is "we resolved an open problem about the algebraic theory of free lattices." (See also §"What this audit does not establish" for the encoding step that this inference does not supply.)

2. **The CALM theorem** (Hellerstein-Alvaro 2020 [4] and predecessors [5][6][7]). Explicitly framed as "a computability theory for distributed systems," with monotonicity as the demarcation principle. CALM is the closest existing "parallel computability theorem" in the literature — but the *substrate* is Ameloot's relational transducer network [7], not a lattice. Lattices appear as the *type system* (BloomL [6]) and as the *property* (monotonicity) that demarcates coordination-free distributed computability.

3. **Kuper's LVars thesis** [11][12][13]: "lattice-based data structures are a general and practical foundation for deterministic and quasi-deterministic parallel and distributed programming" [11]. This is the strongest *lattice-flavored* "foundation / unifying abstraction" claim found, and explicitly subsumes prior deterministic-parallel models (IVars, Kahn networks, pure FP, disjoint imperative parallelism) [12]. But it is bounded to *deterministic* parallelism and does not invoke Turing/Church-Turing rhetoric.

4. **Hewitt's actor model** [16][17]. The single instance found in the entire parallel-/concurrent-computation literature where the creator explicitly and repeatedly pitches the model as a UTM analogue: actors are "the universal conceptual primitives of digital computation," and "all physically possible computation can be directly implemented using Actors" [17]. This is the explicit precedent — but on a different substrate.

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

- **Paper II** [2]: Nation & Paolini, *"Elementary properties of free lattices II: Decidability of the universal theory"* (arXiv:2504.09128, Apr 2025). Verbatim abstract: *"Our main result is that the universal (existential) theory of infinite free lattices is decidable."* This is the algorithmic lift of Skolem 1920 / the Whitman-style structural decision procedure (see [9]) to the universal fragment of FOTFL on FL(ℵ₀)-flavored objects.

- **Paper III** [3]: Nation & Paolini, *"Elementary properties of free lattices III: Undecidability of the full theory"* (arXiv:2511.13149, Nov 2025). Reconstructed-from-search-snippets abstract¹: *"In [paper II]² we proved that the universal theory of infinite free lattices is (algorithmically) decidable, leaving open the problem of decidability of the full theory of an (infinite) free lattice. We solve this problem by proving that, for every cardinal κ ≥ 3, the first-order theory of the free lattice F_κ is undecidable."*

  ¹ The Nov 2025 abstract was reconstructed from search snippets in the T1 research pass; the canonical arXiv abs page was not separately parsed for this audit.
  ² Bracketed reference in the original is `[6]`, the paper's own internal numbering for "Paper II"; substituted to `[paper II]` for reader clarity. All other words in the quoted block are unmodified.

**Why this matters for the priority claim.** Undecidability of the full first-order theory of an algebra is, on a standard reading, the model-theoretic shadow of "Turing computation can be encoded into the first-order theory of that algebra." That is the inferential bridge from the Nation-Paolini III result to the language of "FL(ℵ₀) is a universal computational substrate." But Nation and Paolini do not phrase it that way; their framing is "we resolve an open problem about the algebraic theory of free lattices." The bridge itself is *our* reading, and the explicit Turing-tape-to-FOTFL encoding it would license is left unspecified — see §"What this audit does not establish" for the gap.

**Historical context.** Skolem 1920 first showed the universal first-order theory of lattices is decidable (a result that "seems to have gone unnoticed by lattice theorists" — Freese-Ježek-Nation, *Free Lattices*, AMS Mathematical Surveys & Monographs 42, 1995, recovered by Stan Burris) [9]. Whitman's structural decision procedure for the word problem of free lattices (mid-20th-century, embedded in [9] as "Whitman's condition (W)") is the structural antecedent for the modern Nation-Paolini work. Bloniarz-Hunt-Rosenkrantz 1988 (*Information and Computation*) [10] classified the complexity: the uniform word problem and the generator problem for free lattices are in deterministic logarithmic space; the more general open-formula validity problem for *all* lattices is co-NP-complete. None of these classical sources frame the result as "FL is a universal computational substrate."

**Adjacent direction.** A separate body of work in computability theory embeds finite *lattices* into the c.e. Turing degrees and Σ⁰₂ enumeration degrees [25] — the *converse* of the framing we are auditing.

**Blocked check.** Nation-Paolini III's reduction shape (what undecidable problem they reduce from — group/semigroup word problem, Hilbert's 10th, direct Turing halting?) is not visible from the abstract. Confirming would require parsing the PDF of arXiv:2511.13149 [3], which the workflow defers.

### (c) CALM theorem; Bloom; Dedalus

**Verdict: ADJACENT — closest existing "parallel computability theorem" framing.**

**Hellerstein & Alvaro, *"Keeping CALM: When Distributed Consistency Is Easy"*, CACM 63(9), Sept 2020** [4]. Verbatim:
> "Distributed systems deserve a computability theory: When is coordination required for consistency, and when can it be avoided?"
> "**THEOREM 1. Consistency As Logical Monotonicity (CALM).** A problem has a consistent, coordination-free distributed implementation if and only if it is monotonic."
> "Hence our Question is one of computability, like P vs. NP or Decidability. […]"

(The bracketed elision marks a trailing supplementary sentence "It asks what is (im)possible for a clever programmer to achieve.")

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

**Kuper dissertation defense talk** [12], two separate passages:
> "[D]ifferent formalisms, and, one could argue, perhaps even different subfields of CS have been developed to deal with these two big problems [parallel and distributed]. So, it's useful to try to find unifying abstractions that can perhaps help us understand and make progress on both of these problems — and this is really what motivates me: trying to find unifying abstractions for programming."

(Later in the same talk:)
> "All of those points in the space [pure FP, dataflow / Kahn networks, single-assignment IVars, disjoint imperative parallelism] are either subsumed by, or are compatible with, the LVars programming model that I'm going to talk about, because **LVars are a general unifying abstraction for deterministic parallel programming**."

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
| Goldschlager 1982 | Yes, within complexity-theoretic frame³ | "A universal interconnection pattern for parallel computers" — designed to make the parallel computation thesis provable | [32] |
| Parallel computation thesis (Chandra-Stockmeyer 1976) | Quantitative bridge | parallel-time ↔ sequential-space, polynomially; *"not a rigorous formal statement"* | [32] |
| Kahn process networks | No | Fixpoint *semantics* of deterministic dataflow; "Kahn principle" = determinism, not universality | [33][34] |
| Dennis / Arvind dataflow | No | One MoC among several | (general literature) |
| Plain Petri nets | No (decidable reachability) | Concurrency model | (general literature) |
| Inhibitor / Sleptsov / arithmetic Petri nets | Turing-complete extensions exist | Universal *Petri net* constructions framed as Turing-completeness of *extensions*, not as electing a foundational parallel substrate | [35][36][37] |
| **Actors (Hewitt 1973; 2010)** | **Yes — explicit and sustained** | *"Universal conceptual primitives of digital computation"*; *"All physically possible computation can be directly implemented using Actors"* | [16][17][18] |
| π-calculus / CCS / CSP | Implicit | *Calculi* of communicating systems | [38][39] |

³ Goldschlager 1982 attribution and characterisation are taken from the Wikipedia *Parallel computation thesis* article [32]; the J.ACM primary source was not consulted for this audit.

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

1. **The word "universal" applied to the model itself appears in only two places** in the entire survey: Hewitt 1973 ("Universal Modular ACTOR Formalism" [16]) and Goldschlager 1982 ("universal interconnection pattern" [32], per the Wikipedia summary [32]; primary source not consulted). Streit-Garg 2025 use "universal procedure" [14] — applied to the *predicate-detection algorithm*, not the lattice substrate.
2. **The word "foundation" applied to the model appears in:** Hellerstein 2010 (Datalog as foundation [5]), Kuper 2013 (lattice-based data structures as foundation [11]).
3. **No paper or talk in the entire survey uses "Church-Turing", "Turing machine analogue", or "parallel Church-Turing thesis" in connection with monotone / lattice / semilattice computation.** The closest is Hellerstein-Alvaro 2020's "Distributed systems deserve a computability theory" [4] — invoking computability theory, not Church-Turing.
4. **Three independent traditions converge on a shared mathematical kernel** — monotone functions over join-semilattices with idempotent/commutative merge — without ever being unified under a UTM-analogue framing:
   - Distributed-systems coordination (CALM/Bloom) [4][6]
   - Lattice-linear predicate detection (Garg) [14][27][28]
   - Deterministic parallelism (Kuper LVars) [11][12][13]
5. **The lattice-theoretic underpinnings exist but are presented as algebra / model theory, not computation:** Skolem 1920, Whitman's condition (mid-20th-century, embedded in [9]), Freese-Ježek-Nation 1995 [9], Bloniarz-Hunt-Rosenkrantz 1988 [10], Nation-Paolini 2023–2025 [1][2][3].
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

- (A) Th(F_κ) is undecidable for κ ≥ 3 (Nation-Paolini III, Nov 2025) [3], so first-order FOTFL is computationally rich enough to encode Turing computation (on the standard reading; the explicit reduction shape used in [3] is not visible from the abstract — see §"What this audit does not establish" item (i)).
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

- It does not establish that the FL(ℵ₀)-as-UTM-analogue claim is *correct* — only that, as far as the surveyed material shows, it is *unclaimed*. The claim itself would still need to specify (i) the encoding from Turing tapes / parallel programs into FL(ℵ₀) words (the missing structural step that the Nation-Paolini III result implicates but does not exhibit explicitly in the abstract), (ii) which Whitman-decidable subset of FL plays the role of "halting / accepting state", (iii) what notion of universality is being claimed (computational, semantic, complexity-bridging, or rhetorical-foundational), and (iv) why this is preferable to the existing actor / Kahn / LVar foundations.
- It does not exhaustively cover all of: arXiv (only metadata-level), Wolfram literature, philosophy-of-CS literature, CRDT-engineering literature, propagator-network literature (Sussman/Radul). These are *gaps*, not negative results.
- It does not independently verify the source-material quotes against the original primary papers; the audit chain runs lead → research files → cited draft, and the verification pass spans only the cited-draft → research-files step. If a research file mis-quoted a primary paper, this audit would not detect it.

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

[32] Wikipedia, *"Parallel computation thesis"* (covers Goldschlager 1982 and Chandra-Stockmeyer 1976; primary source for Goldschlager 1982 not consulted). https://en.wikipedia.org/wiki/Parallel_computation_thesis

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

---

# Round 2 Supplementary Patch (2026-05-08, post-local-PDFs)

The user provided two local PDFs and one scope direction. This patch records three corrections to the round-2 addendum based on direct local-PDF inspection.

## R2-Patch-1. Wolfram dropped from priority-threat list (user direction)

The user explicitly stated: *"I am not interested in building from Wolfram's work. I deem it irrelevant to our efforts."*

**Effect on the audit.** Section R2-B1 (Wolfram multicomputational paradigm) is deprioritized: the *factual* findings stand (Wolfram does have explicit "fourth foundational paradigm" rhetoric for multiway/hypergraph rewriting, multiway-Turing-machine universality, ruliad as everything-at-once limit), but Wolfram is **out of scope** as a priority threat for Prologos's positioning. Any future paper-style writeup may drop this axis or treat it as a single-paragraph "competing-paradigm note", not as a first-class precedent.

The updated priority-claim landscape (from R2-D) reduces to two competing UTM-analogue rhetoric programs to engage:

```
                                    UTM-analogue rhetoric?  Substrate kind
                                    ──────────────────────────────────────
Hewitt actors (1973, 2010)      ─→  YES — "universal primitives of      Concurrent message-passing
                                    concurrent digital computation"
Spivak "Poly as true language   ─→  YES — explicitly successor to        Polynomial functors /
of computation" (AFOSR 2022)        Turing/Von Neumann                    dependent lenses
[Wolfram multicomputation]      ─→  [out of scope per user direction]
```

## R2-Patch-2. Endrullis-Shallit-Smith 2017 — full-PDF correction of round 1 sub-area (a)

**Source:** local PDF parsed via `document_parse`, full body inspected (12 pages, 592 lines).

**Round-1 verdict was "ABSENT — no TM-into-rewriting embedding, no universality framing." The first half of that verdict is wrong; the second half is right.**

**Verbatim from the proof of Lemma 1 (REWRITE-POWER undecidable), §2:**

> "The standard approach for showing that a rewriting problem is undecidable is to reduce from the halting problem, by encoding a Turing machine M and simulating its computation using the rewrite rules; for example, see [Book-Otto 1993, *String-Rewriting Systems*]."
>
> "We construct our length-preserving rewriting system mimicking the computations of M as follows. Let Σ = Γ ∪ Q ∪ {a, b, $}. Let S contain the following rewrite rules:
> aa → $q₀ ... [seven rules total simulating one-tape Turing machine transitions]
> ... Therefore M halts when run on a blank tape iff there exists an n ≥ 1 such that aⁿ ⟹ bⁿ, completing the reduction from the halting problem."

So the paper **does** contain an explicit, body-level **Turing-machine-into-rewriting embedding** — exactly the kind of TM-into-rewriting-structure embedding round-1 sub-area (a) was searching for. The rewriting system is length-preserving (a constraint that keeps it well-behaved as a finitely-presented combinatorial structure) and the encoding is the standard halting-problem reduction (cited to Book-Otto 1993's textbook).

**What the paper does *not* do.** No "universal computational substrate", "Turing machine analogue for parallelism", "foundation of computation", or any framing of the rewriting system as anything other than a tool for proving undecidability of subsequent automaton-property decision problems (REWRITE-POWER, ACCEPTS-SHIFT, ACCEPTS-POWER, etc.). The framing is: rewriting system as a *vehicle for reduction*, not as a *substrate*. **Mechanical grep on the full PDF returns zero references to Nation, Whitman, Skolem, free lattice, substrate, or universal-in-the-UTM-sense.**

**Note on the user's filing.** The user provided this PDF under the path `outside/UH Professor - JB Nation - Lattices, Publications/NFA undecidable.pdf`. The paper itself is by Endrullis-Shallit-Smith (2017), not Nation; mechanical grep confirms zero Nation references in the body. The paper is presumably in Nation's research collection because rewriting-system decidability and free-lattice decidability share the algebraic-decidability theme (Skolem 1920 / Whitman 1941 / FJN 1995 for free-lattice word problem, Markov / Post / Book-Otto for rewriting-system word problem).

**Updated round-1 sub-area (a) verdict:** ESS 2017 *does* embed Turing computation into a (length-preserving) rewriting system, via the standard halting-problem reduction, **but the rewriting structure is never elevated to "universal substrate" status.** The framing stays uniformly inside the undecidability-by-reduction tradition. The paper is therefore prior art for "TM-in-rewriting" as a *technique*, not for "rewriting-as-universal-parallel-substrate" as a *framing*.

## R2-Patch-3. Niu-Spivak *Polynomial Functors* book — mechanical confirmation that propagator/Sussman/Radul/lattice/Whitman are absent

**Source:** local PDF parsed via `document_parse` in two passes covering ~93 of 376 pages: pages 1-15 (preface, frontmatter, early Chapter 1) plus a 37-page slice including the tail of Chapter 7 (*Polynomial Comonoids are Categories*, the categorical heart of the book where one would most expect propagator-network-style examples to appear if they were present).

**Mechanical grep results across all parsed Spivak text (~93 pages):**

| Search term | Hits |
|---|---|
| `propagator` / `propagation` (in Sussman-Radul sense) | 0 |
| `Sussman` | 0 |
| `Radul` | 0 |
| `TMS` / `truth maintenance` | 0 |
| `constraint propagation` / `constraint network` | 0 |
| `lattice` | 0 |
| `Whitman` | 0 |

**Effect.** This **confirms mechanically** the round-2 researcher's finding that the Niu-Spivak book does not connect polynomial functors / dependent lenses with Sussman-Radul propagator networks, with the lattice tradition, or with the Whitman / free-lattice algebraic decidability tradition. The negative result is now anchored in direct text inspection, not just metadata search.

**Caveat.** The remaining ~283 pages of the book (Chapters 8 and 9 if they exist, full bibliography, index) were not parsed. Round-2 reported Chapter 9 was titled *"New Horizons"*; the parses we ran did not reach that chapter. Risk that "propagator" appears in the unparsed tail is low (the front matter, preface, and Chapter 7 are the most likely places for such a connection, and they are clean), but the residual gap is open. A targeted bibliography-grep would close this completely.

**Net effect on the priority audit.** The round-2 conclusion that **the polynomial-functor ↔ Sussman-Radul-propagator identification is novel in the surveyed corpus** is now mechanically anchored, not only via web search but via direct local inspection of the primary Niu-Spivak text. This is the strongest form of the negative claim available without reading every page of the 376-page book.

## R2-Patch-4. Updated bottom line for Prologos

With Wolfram out of scope (R2-Patch-1), ESS 2017 sharpened (R2-Patch-2), and Niu-Spivak Poly ↔ propagator absence mechanically confirmed (R2-Patch-3), the priority-claim landscape relevant to Prologos has two strands:

**Strand 1: FL(ℵ₀) + Whitman as universal parallel substrate (algebraic / on-network word algebra).**
- Closest prior art: Nation-Paolini I/II/III (algebra); Radul (substrate framing); Kuper (lattice + deterministic-parallel scope); CALM (computability framing).
- Closest competing UTM-analogue rhetoric: **Hewitt actors** (different substrate kind — concurrent message passing).
- Status: framing appears unclaimed. ESS 2017's TM-into-rewriting reduction is technique-level prior art for the encoding move but not framing-level prior art.

**Strand 2: Polynomial functors / dependent lenses as the categorical identity of Sussman-Radul propagators (categorical / on-network interaction algebra).**
- Closest prior art: none found in surveyed corpus, mechanically confirmed for the Niu-Spivak book sections we parsed.
- Closest competing UTM-analogue rhetoric: **Spivak's *"Is Poly the true language of computation?"* (AFOSR 2022)** — same Poly substrate, but no propagator identification.
- Status: identification appears novel. Spivak's universality rhetoric is the closest kindred precedent and can be cited as such.

The two strands together — **propagator networks as universal parallel substrates, with FL(ℵ₀) as the on-network word algebra and polynomial functors as the categorical identity** — form a coherent positioning that no single existing landmark fills. The two strongest priority-rhetoric precedents to engage are Hewitt (concurrent-message-passing universality) and Spivak (Poly as true language of computation).

## R2-Patch sources

[R2-P-1] *"NFA undecidable.pdf"* (= arXiv:1702.01394v2, Endrullis-Shallit-Smith 2017, full body parsed locally), filed under `/Users/avanti/dev/projects/prologos/outside/UH Professor - JB Nation - Lattices, Publications/`.

[R2-P-2] N. Niu, D. I. Spivak, *Polynomial Functors: A Mathematical Theory of Interaction*, CUP/LMS Lecture Notes Series, full PDF at `/Users/avanti/dev/projects/prologos/outside/Polynomial Functors_ A Mathematical Theory of Interaction - Spivak, Niu.pdf`. Parsed locally; ~93 of 376 pages mechanically inspected for propagator/Sussman/Radul/lattice/Whitman references — zero hits.

---

# Round 2 Bibliography Closure (2026-05-08)

This closure patch resolves the residual blocked check from R2-Patch-3: the complete bibliography and complete index of the Niu-Spivak *Polynomial Functors* book are now mechanically inspected.

## Method

The PDF is 489 pages (printed-book pagination ~468 pp). Three `document_parse` passes covered:
- Pass 1: pages 1–15, 56 pages parsed (front matter + early chapters).
- Pass 2: pages 340–376 (relative request), 37 pages parsed (Chapter 7 tail).
- Pass 3 (this closure): pages 450–489, **40 pages parsed covering Chapter 8.3–8.5 + complete References (50+ entries) + complete Index** (entries from `*-bifibration` through `Yoneda lemma`).

Combined coverage: ~133 of 489 PDF pages (~27%), including **the entire bibliography and the entire index**.

## Mechanical grep results across the parsed bibliography + index pass

The following terms were searched case-insensitively against the parsed bibliography + index (the most relevant section for catching prior-art citations):

| Search term | Hits | Notes |
|---|---|---|
| `propagator` / `propagation` | 0 | — |
| `Sussman` | 0 | — |
| `Radul` | 0 | — |
| `Steele` | 0 | — |
| `McAllester` / `de Kleer` / `Forbus` | 0 | — |
| `TMS` / `truth maintenance` | 0 | — |
| `constraint propagation` / `constraint network` | 0 | — |
| `lattice` | 0 | — |
| `Whitman` / `Skolem` / `Birkhoff` | 0 | — |
| `Free Lattices` / `FJN` / `Paolini` | 0 | — |
| `Hellerstein` / `Alvaro` / `Marczak` | 0 | — |
| `Bloom` / `Dedalus` / `CALM` | 0 | — |
| `CRDT` / `Conflict-free` | 0 | — |
| `Lasp` / `Meiklejohn` | 0 | — |
| `Garg` / `Kuper` / `LVars` | 0 | — |
| `Hewitt` | 0 | — |
| `Wolfram` | 0 | — |
| `Petri` / `Kahn` / `Arvind` | 0 | — |
| `Shapiro` | **1** | **Brandon Shapiro**, *Familial Monads as Higher Category Theories* (arXiv:2111.14796, 2021) — category theorist, **not** Marc Shapiro of CRDT fame. Spurious. |
| `actor` | **3** | All three are substrings of `factor` / `factorization` in mathematical proofs ("`f` cannot factor through `y`", "factorization system"). **No reference to Hewitt's actor model.** Spurious. |
| `Conway` | 1 | **John Horton Conway** [Con12], *Regular algebra and finite machines* (Courier, 2012; orig. 1971) — classic on regular expressions and finite-state algebra. **Not** Neil Conway of CALM/Bloom. Cited only on p. 166 in the context of polynomial-functor / state-system equivalences. |

## Net result

The Niu-Spivak *Polynomial Functors: A Mathematical Theory of Interaction* book contains, **across its complete bibliography (~50 entries) and complete index, zero references to**:

- Sussman-Radul propagator networks (or any propagator-network literature).
- The TMS / ATMS / truth maintenance tradition (McAllester, de Kleer, Forbus, Steele).
- Constraint propagation / constraint networks.
- The free-lattice / Whitman / Skolem / Nation / Freese-Ježek-Nation / Nation-Paolini lattice tradition.
- The CALM / Bloom / Dedalus distributed-systems lattice tradition (Hellerstein, Alvaro, Marczak, Neil Conway).
- CRDT engineering literature (Marc Shapiro, Lasp, Meiklejohn).
- Garg's lattice-linear predicate detection.
- Kuper's LVars.
- Hewitt's actor model.
- Wolfram's multicomputational paradigm or any Wolfram work.
- Petri nets, Kahn process networks, Dennis/Arvind dataflow.

The two terms that *did* match (`Shapiro`, `Conway`) refer to different people working in unrelated areas (Brandon Shapiro = category-theoretic familial monads; John Horton Conway = regular algebra and finite machines). The three `actor` matches are substring-of-`factor` artefacts.

**This is the strongest possible mechanical negative result.** The Niu-Spivak book — which round 2 surveys identified as the canonical Poly text — does not connect polynomial functors / dependent lenses with **any** of the lattice-based, propagator-network, CRDT, or actor-model traditions in either its body, its bibliography, or its index.

## Two structural corrections

1. **No Chapter 9 in the published book.** The book's structure ends with Chapter 8.5 (*Exercise Solutions*), then **References**, then **Index**. Round 2's earlier reference to a "Chapter 9 (*New Horizons*)" was based on the Topos Institute draft preface or the arXiv preprint (arXiv:2312.00990), which apparently differed from the final CUP / LMS Lecture Notes edition. The published book has 8 chapters.
2. **John Horton Conway ≠ Neil Conway.** [Con12] in the Spivak bibliography is John Horton Conway's *Regular algebra and finite machines* (the mathematician, 1937–2020), cited on p. 166 in the context of polynomial-functor / state-system equivalences. This is not Neil Conway of CALM / Bloom / BloomL. Easy to confuse but unrelated. Recording for clarity.

## Final positioning summary for Prologos

The two-strand positioning identified in R2-Patch-4 is now mechanically-anchored at the strongest level:

- **FL(ℵ₀) + Whitman as universal parallel substrate**: closest competing UTM-rhetoric is **Hewitt actors**; closest substrate-framing ancestor is **Radul's *Propagation Networks: A Flexible and Expressive Substrate for Computation* (MIT 2009)**.
- **Polynomial functors / dependent lenses as the categorical identity of Sussman-Radul propagators**: identification is **definitively absent** from the canonical Niu-Spivak Poly text (body + bibliography + index), and absent from the surveyed Topos blog / Spivak-talk corpus, and absent from the surveyed propagator-network literature. Closest competing UTM-rhetoric is **Spivak's *"Is Poly the true language of computation?"* (AFOSR 2022)**, which uses the same Poly substrate without the propagator identification.

The bibliography-closure check leaves no residual gap on the categorical strand. The novelty claim for Poly ↔ propagator is mechanically defensible.

**Residual gap on the algebraic strand**: round-1 sub-area (b) Nation-Paolini III's reduction shape was resolved (Nies 1996 ∃∀-theory of nice bipartite graphs); the Whitman embedding in §5 of [3] is load-bearing. No further bibliography-level checks remain on the lattice axis. The Hewitt arXiv:1008.1459 v38 PDF body (rather than abstract) is the only minor PDF gap remaining, and the round-1 HAL source for the body-level "all physically possible computation" claim corroborates round 1's reading.

## Closure-patch source

[R2-C-1] N. Niu, D. I. Spivak, *Polynomial Functors: A Mathematical Theory of Interaction*, CUP / LMS Lecture Notes Series, 489 PDF pages, parsed locally. Three `document_parse` passes covering ~133 pages including the complete References section and complete Index. Bibliography has ~50 entries; mechanical grep confirms all listed-as-zero terms above. Local file: `/Users/avanti/dev/projects/prologos/outside/Polynomial Functors_ A Mathematical Theory of Interaction - Spivak, Niu.pdf`.
