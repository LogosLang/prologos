# T3 Research: Foundational Parallel Models & Categorical Axis

Scope: search for explicit "universal parallel substrate" / "foundational
parallel machine" / UTM-analogue framings across BSP, PRAM, dataflow (Dennis,
Arvind, Kahn), Petri nets, actors (Hewitt), pi/CSP/CCS, and categorical
foundations (Spivak Poly, polynomial functors, GoI). Quotes are verbatim from
the cited HTML/abstract pages (no PDFs parsed); inferences are flagged.

## (f) BSP / PRAM / dataflow / Petri / actors

### BSP — Valiant 1990

Valiant's framing is **"bridging model"**, deliberately *between* hardware and
programming model, and an analogue of the **von Neumann model** (not the UTM).
Verbatim from the ACM abstract:

> "The success of the von Neumann model of sequential computation is
> attributable to the fact that it is an efficient bridge between software and
> hardware … an analogous bridge between software and hardware is required for
> parallel computation if that is to become as widely used."
> — *A bridging model for parallel computation*, ACM DL abstract.
> https://dl.acm.org/doi/10.1145/79173.79181

From Valiant's own text (as quoted in The Morning Paper summary):

> "In this article we introduce the bulk-synchronous parallel (BSP) model and
> provide evidence that it is a viable candidate for the role of bridging model.
> It is intended **neither as a hardware nor programming model, but something
> in between**."
> https://blog.acolyer.org/2015/06/08/a-bridging-model-for-parallel-computation/

Universality claim made: "**universally efficient**" (i.e., compilable from many
languages and implementable on many machines), not universal in the
computability/UTM sense. The Acolyer paraphrase: *"Valiant seeks to show that
the BSP model is universally efficient."* No UTM-analogue language.

**Verdict:** BSP is explicitly framed as a *von-Neumann analogue* (engineering
bridge), **not** a UTM analogue. Valiant chose his analogy carefully — von
Neumann, not Turing.

### PRAM — Fortune-Wyllie 1978; Karp-Ramachandran

PRAM is presented as an **idealised shared-memory generalisation of RAM**, not
as a foundational universal model. From the Wisconsin notes (Tvrdík):

> "Parallel Random Access Machine is a straightforward and natural
> generalization of RAM. It is an idealized model of a shared memory SIMD
> machine."
> https://pages.cs.wisc.edu/~tvrdik/2/html/Section2.html

Karp-Ramachandran survey:

> "The principal model of computation that we consider is the parallel
> random-access machine (PRAM) … This model permits the logical structure of
> parallel computation to be studied in a context divorced from issues of
> interprocessor communication."
> https://www2.eecs.berkeley.edu/Pubs/TechRpts/1988/CSD-88-408.pdf

The closest *universality* statement in the PRAM literature is **Goldschlager
1982, "A universal interconnection pattern for parallel computers"** (J. ACM
29(3)) — proposed precisely so the parallel-computation thesis becomes
provable:

> "Goldschlager (1982) proposed a model which is sufficiently universal to
> emulate all 'reasonable' parallel models. In this model, the thesis is
> provably true."
> — Wikipedia, *Parallel computation thesis*.
> https://en.wikipedia.org/wiki/Parallel_computation_thesis

The framing here is **the parallel computation thesis** (Chandra-Stockmeyer
1976): parallel time ≈ sequential space, polynomially. Wikipedia is explicit
that this is a quantitative bridging hypothesis, *not* a Church-Turing-style
universality theorem:

> "The parallel computation thesis is **not a rigorous formal statement**, as
> it does not clearly define what constitutes an acceptable parallel model. A
> parallel machine must be sufficiently powerful to emulate the sequential
> machine in time polynomially related to the sequential space …"

There is also the **sequential computation thesis** (Goldschlager-Lister) — a
strengthening of Church-Turing for *feasibility*. No analogous "parallel
Church-Turing thesis" is named.

**Verdict:** PRAM itself is not pitched as universal substrate; Goldschlager's
"universal interconnection pattern" is the closest deliberate universality
claim in the PRAM tradition, and even there the goal is to make a *complexity*
thesis (parallel time ↔ sequential space) provable, not to elect a UTM
analogue.

### Dataflow — Dennis, Arvind, Kahn process networks

Kahn 1974 ("The semantics of a simple language for parallel programming") and
Kahn–MacQueen 1977 are presented as a **semantic** account of deterministic
dataflow, anchored in least-fixpoint theory:

> "Kahn Process Networks have an elegant mathematical semantics in the form of
> a function that maps input streams to output streams, defined as a least
> fixed-point of an overall network function on a complete partial order."
> — Computational Modeling Work-Bench.
> https://computationalmodeling.info/static-wp/models/kahn-process-networks-and-reactive-process-networks/

The "Kahn principle" is a *determinism* result, not a universality claim:

> "The Kahn principle states that such networks are deterministic, i.e. that
> for each network we have that each execution provided with the same input
> delivers the same output."
> — *Linear dynamic Kahn networks are deterministic*, Springer abstract.
> http://hdl.handle.net/1765/1455

No source surfaced calls KPNs (or Dennis static dataflow, or Arvind's tagged-
token dynamic dataflow) "the universal parallel substrate." The literature
consistently frames them as **a model of computation (MoC)** alongside others;
e.g., scitepress survey lists Kahn/dynamic-dataflow as one MoC among several
with deterministic latency-insensitive properties.

**Verdict:** Dataflow / Kahn networks have *foundational semantic* status
(fixed-point characterisation, determinism principle) but are never claimed
as *the* universal parallel machine. They are taken as one beautiful MoC.

### Petri nets — Petri 1962

Plain place/transition Petri nets are **not Turing-complete** (reachability is
decidable). Universality results require extensions (inhibitor arcs, priorities,
timed/Sleptsov nets). Verbatim from a "universal Petri net" construction:

> "A universal **inhibitor** Petri net executing an arbitrary given inhibitor
> Petri net is constructed."
> — *Universal Petri net*, Springer abstract.
> https://link.springer.com/article/10.1007/s10559-012-9429-4

Sleptsov-net work explicitly acknowledges baseline P/T nets are restricted:

> "We follow the proof pattern of Peterson applied to prove that an inhibitor
> Petri net is Turing-complete …"
> — arXiv:2201.09034 abstract page.
> http://arxiv.org/abs/1309.7288

"Arithmetic Petri nets" are pitched as a *new computational paradigm*
explicitly equated with the Church–Turing tradition:

> "The notion of computability has its origin in … Several approaches of
> computation were proposed: recursive functions, Post programs, lambda
> calculus, Turing machines, register machines … In this paper a new
> computational paradigm called arithmetic Petri nets (APN) is introduced."
> https://acadsol.eu/npsc/24/1-4/3

**Verdict:** Petri nets are routinely framed as a *concurrency model*, with
universality claimed only for Turing-complete *extensions*. No "Petri net is
to parallel computation as UTM is to sequential" framing surfaced; the
universality literature is about Turing-completeness of extensions, not about
electing a foundational parallel substrate.

### Actors — Hewitt 1973; Hewitt 2010

This is the **strongest explicit UTM-analogue claim** found anywhere in the
parallel-models literature.

Title of the original paper: **"A Universal Modular ACTOR Formalism for
Artificial Intelligence"** (Hewitt, Bishop, Steiger, IJCAI 1973). Abstract:

> "This paper proposes a modular ACTOR architecture and definitional method for
> artificial intelligence that is conceptually based on a single kind of
> object: actors [or, if you will, virtual processors, activation frames, or
> streams]. The formalism makes no presuppositions about the representation of
> primitive data structures and control structures."
> https://www.ijcai.org/Proceedings/73/Papers/027B.pdf

Hewitt's later writings make the universality claim explicit. From the HAL
abstract of *Actor Model of Computation* (and verbatim from arXiv:1008.1459):

> "The Actor Model is a mathematical theory that treats 'Actors' as **the
> universal conceptual primitives of digital computation.** Hypothesis: All
> physically possible computation can be directly implemented using Actors."
> https://hal.science/hal-01163534v6
> https://arxiv.org/pdf/1008.1459

Hewitt also argues the standard CT thesis fails for interactive/concurrent
computation, motivating actors as the replacement foundation:

> "After physical computers were constructed, they soon diverged from
> computing only algorithms meaning that the Church/Turing theory of
> computation no longer applied to computation in practice because computer
> systems are highly interactive as they compute, which inspired the
> development of new models of computation."
> — *Physical Indeterminacy in Digital Computation*, SSRN abstract.
> https://papers.ssrn.com/sol3/papers.cfm?abstract_id=3459566

**Verdict:** Actor model is the **only** mainstream parallel/concurrent model
whose creator explicitly and repeatedly pitches it as the UTM analogue
("universal primitives of digital computation," "all physically possible
computation"). This is the candidate framing the brief asked us to find.

### Pi-calculus / CSP / CCS — Milner, Hoare

Process algebras are framed as **calculi of communicating systems**, with
foundational ambition but typically expressed as "models of concurrency"
rather than "the universal parallel machine." From Milner–Parrow–Walker:

> "We present the π-calculus, a calculus of communicating systems in which one
> can naturally express processes which have changing structure."
> — *A Calculus of Mobile Processes, I*.
> https://www.sciencedirect.com/science/article/pii/0890540192900084

From Milner's polyadic π tutorial:

> "The π-calculus is a model of concurrent computation based upon the notion of
> *naming*."
> https://link.springer.com/chapter/10.1007/978-3-642-58041-3_6

Universality is implicit (encoding of λ-calculus into π is well-known) but
none of the surveyed abstracts use phrases like "universal parallel machine"
or "Turing analogue for parallelism." Milner's own framing is *successor to
CCS* / *calculus*, not *universal machine*.

**Verdict:** Pi-calculus / CCS / CSP are presented as **calculi** (algebraic
foundations of concurrency) rather than as universal parallel *machines*.
Foundational ambition: yes. Explicit UTM-analogue rhetoric: **not** in the
sources surfaced.

### Synthesis for (f)

| Model | UTM-analogue claim? | Closest framing |
|---|---|---|
| BSP (Valiant 1990) | No | Explicit *von-Neumann* analogue ("bridging model"), engineering-universal not computability-universal |
| PRAM | No | Idealised shared-memory generalisation of RAM |
| Goldschlager 1982 | Yes (within complexity) | "A universal interconnection pattern for parallel computers" — designed to make the parallel computation thesis provable |
| Parallel computation thesis (Chandra-Stockmeyer 1976) | Quantitative bridge | parallel-time ↔ sequential-space, polynomially; *not a rigorous formal statement* |
| Kahn process networks | No | Fixpoint *semantics* of deterministic dataflow |
| Dennis / Arvind dataflow | No | One MoC among several |
| Plain Petri nets | No (decidable reachability) | Concurrency model |
| Inhibitor / Sleptsov Petri nets | Turing-complete extensions exist | "Universal Petri net" constructions, but framed as *Turing-completeness of extensions*, not as UTM-analogue |
| Actors (Hewitt) | **Yes, explicit** | "Universal conceptual primitives of digital computation" |
| π / CCS / CSP | Implicit | Calculi of communicating systems |

The one **clean explicit UTM analogue** is Hewitt's actor model. Everyone else
is more careful: Valiant says *von Neumann analogue*; PRAM theorists say
*generalisation of RAM*; Kahn says *fixpoint semantics*; Petri-universality is
narrowly Turing-completeness-of-extensions; Milner says *calculus*. The user's
hypothesis — that the parallel community has *not* converged on a UTM analogue
— is supported, with the single sustained dissent being Hewitt's actor
program.

## (g) Categorical foundations

### Spivak Poly — Niu & Spivak, "Polynomial Functors: A Mathematical Theory of Interaction" (2023, CUP/arXiv 2312.00990)

The book's framing is "**theory of interaction**," not "universal machine."
Verbatim from the arXiv abstract:

> "This monograph is a study of the category of polynomial endofunctors on the
> category of sets and its applications to modeling interaction protocols and
> dynamical systems."
> https://arxiv.org/abs/2312.00990

Verbatim from the Cambridge University Press book page:

> "Everywhere one looks, one finds dynamic interacting systems: entities
> expressing and receiving signals between each other and acting and evolving
> accordingly over time. In this book, the authors give a new syntax for
> modeling such systems, describing a mathematical theory of interfaces and
> the way they connect."
> https://www.cambridge.org/core/books/polynomial-functors/5A57527AE303503CDCC9B71D3799231F

The **Topos Institute** PDF preface notes the *uptake* of Poly across applied
category theory:

> "During the Fifth International Conference on Applied Category Theory in
> 2022, at least twelve of the fifty-nine presentations and two of the ten
> posters referenced the category of polynomial functors and dependent lenses …"
> https://toposinstitute.github.io/poly/poly-book.pdf

No verbatim "Poly is to parallel/interactive computation as UTM is to
sequential computation" claim surfaces in the abstract or CUP blurb. The
language is **"a mathematical theory of interaction,"** **"new syntax for
modeling [interacting] systems,"** **"theory of interfaces and the way they
connect."** This is foundational ambition pitched as *theory* not *machine*,
analogous to how λ-calculus was originally pitched (calculus, not machine).
*Inference (flagged):* Poly behaves *structurally* like a UTM-analogue
candidate — single uniform substrate, expressive of dynamical systems and
protocols — but the authors do not use UTM-analogue rhetoric in the surfaced
materials.

### Geometry of Interaction — Girard; Abramsky-Jagadeesan; Haghverdi-Scott

GoI is pitched as a foundational program for *the dynamics of computation*
(cut-elimination), not as a parallel UTM. Verbatim:

> "Girard's Geometry of Interaction (GoI) is a program that **aims at giving
> mathematical models of algorithms independently of any extant languages**.
> In the context of proof theory, where one views algorithms as proofs and
> computation as cut-elimination, this program translates to providing a
> mathematical modelling of the dynamics of cut-elimination."
> — Haghverdi tutorial.
> https://cgi.luddy.indiana.edu/~ehaghver/Tutorial.pdf

> "Geometry of Interaction is based on the idea that the ultimate explanation
> of logical rules is through the cut-elimination procedure … proofs are
> operators on the Hilbert space describing I/O dependencies; cut-elimination
> is the solution of an I/O equation … termination is nilpotency of the
> operator; execution is the solution of a feedback equation."
> — Springer abstract, *Geometry of Interaction*.
> https://link.springer.com/chapter/10.1007/978-3-540-48654-1_1

Abramsky-Haghverdi-Scott axiomatise GoI categorically:

> "We present an axiomatic framework for Girard's Geometry of Interaction in
> the context of linear combinatory algebras …"
> https://www.cambridge.org/core/journals/mathematical-structures-in-computer-science/article/abs/geometry-of-interaction-and-linear-combinatory-algebras/983F3238099D7BCBC9FAA3BC9ABBAD51

> "We consider the multiplicative and exponential fragment of linear logic
> (MELL) and give a geometry of interaction (GoI) semantics for it based on
> unique decomposition categories … We show that Girard's original approach to
> GoI 1 via operator algebras is exactly captured in this categorical
> framework."
> — *A categorical model for the geometry of interaction*.
> https://www.sciencedirect.com/science/article/pii/S0304397505006808

The phrase "**independently of any extant languages**" is the closest GoI
comes to universality rhetoric — a foundational, language-independent model of
computation. Still framed as *semantics of cut-elimination*, not as *the
universal parallel machine*.

### Other categorical-systems framings (brief)

No surfaced source uses "UTM analogue" rhetoric for: operads of wiring
diagrams; species (Joyal); Riehl-Verity ∞-categorical models; profunctorial /
applicative / monoidal foundations of parallelism; CRDT lattices in
category-theoretic terms. (These were named in the brief but the searches
above did not surface explicit universality claims for them; recording as a
*gap* rather than as a negative result.)

### Synthesis for (g)

| Framework | UTM-analogue claim? | Stated framing |
|---|---|---|
| Spivak/Niu Poly | **No** (in surfaced abstracts) | "Mathematical theory of interaction"; "new syntax for modeling [interacting] systems" |
| Geometry of Interaction | Foundational but **not** UTM-analogue | "Mathematical models of algorithms independently of any extant languages"; semantics of cut-elimination |
| Linear logic / categorical proof theory | No | Semantic, not machine-theoretic |

**Verdict (g):** The categorical-foundations literature is consistently
*calculus-flavoured* and *semantics-flavoured*, never *machine-flavoured*. No
explicit "X is the UTM analogue for parallel computation" claim was found in
this axis. The closest in spirit is Hewitt (in axis f), not anyone in the
categorical world.

## Open questions / blocked checks

- Did not pull Hewitt's full **arXiv:1008.1459** PDF body (only the surfaced
  abstract paragraph). Likely contains stronger UTM-analogue rhetoric in §1.
  Flagged as worth fetching if a deeper Hewitt-vs-Turing analysis is needed.
- Did not check **Agha's** dissertation directly; only cited via Hewitt
  literature.
- Did not surface explicit UTM-analogue claims from the **operads of wiring
  diagrams** (Spivak-Rupel) or **CRDT/lattice categorical** literature; this
  is a *gap*, not a negative.
- Did not check **Goldschlager 1982 J.ACM** body for any claim that the
  "universal interconnection pattern" is a UTM analogue rather than just a
  thesis-enabling complexity model.
- Did not check **Lamport** ("Time, Clocks, and the Ordering of Events"),
  **Pratt** (transition graphs / Chu spaces), or **Mazurkiewicz traces** —
  any of which might contain foundational rhetoric the brief missed.

## Sources (all URLs consulted)

Kept (used in findings):

- ACM DL — Valiant, *A bridging model for parallel computation* (abstract):
  https://dl.acm.org/doi/10.1145/79173.79181
- The Morning Paper summary, Valiant 1990:
  https://blog.acolyer.org/2015/06/08/a-bridging-model-for-parallel-computation/
- OSTI mirror of Valiant abstract:
  https://www.osti.gov/scitech/biblio/6502724
- Wikipedia, *Bridging model*:
  https://en.wikipedia.org/wiki/Bridging_model
- Wikipedia, *Parallel computation thesis*:
  https://en.wikipedia.org/wiki/Parallel_computation_thesis
- Karp-Ramachandran PRAM survey (Berkeley TR abstract page):
  https://www2.eecs.berkeley.edu/Pubs/TechRpts/1988/CSD-88-408.pdf
- Wisconsin PRAM lecture notes (Tvrdík):
  https://pages.cs.wisc.edu/~tvrdik/2/html/Section2.html
- Hewitt-Bishop-Steiger 1973, *A Universal Modular ACTOR Formalism*:
  https://www.ijcai.org/Proceedings/73/Papers/027B.pdf
- Hewitt, *Actor Model of Computation*, HAL:
  https://hal.science/hal-01163534v6
- Hewitt, arXiv:1008.1459 (abstract paragraph):
  https://arxiv.org/pdf/1008.1459
- Hewitt, *Physical Indeterminacy in Digital Computation*, SSRN:
  https://papers.ssrn.com/sol3/papers.cfm?abstract_id=3459566
- Kahn process networks semantic note (Computational Modeling Work-Bench):
  https://computationalmodeling.info/static-wp/models/kahn-process-networks-and-reactive-process-networks/
- *Linear dynamic Kahn networks are deterministic*, Springer:
  https://link.springer.com/chapter/10.1007/3-540-61550-4_152
- Erasmus repository, Kahn fixed-point linear dynamic networks:
  http://hdl.handle.net/1765/1455
  https://repub.eur.nl/pub/520/
- *Universal Petri net* (inhibitor), Springer:
  https://link.springer.com/article/10.1007/s10559-012-9429-4
- *Small Polynomial Time Universal Petri Nets*, arXiv:1309.7288:
  http://arxiv.org/abs/1309.7288
- *Computability power of an extended Petri net model (APN)*:
  https://acadsol.eu/npsc/24/1-4/3
- *Universal Sleptsov net* (Tandfonline abstract):
  https://www.tandfonline.com/doi/full/10.1080/00207160.2017.1283410
- Milner-Parrow-Walker, *A Calculus of Mobile Processes I*, ScienceDirect:
  https://www.sciencedirect.com/science/article/pii/0890540192900084
- Milner, *Polyadic π-Calculus: a Tutorial*, Springer:
  https://link.springer.com/chapter/10.1007/978-3-642-58041-3_6
- LFCS report ECS-LFCS-89-85:
  https://www.lfcs.inf.ed.ac.uk/reports/89/ECS-LFCS-89-85
- Niu & Spivak, *Polynomial Functors: A Mathematical Theory of Interaction*,
  arXiv:2312.00990: https://arxiv.org/abs/2312.00990
- Cambridge University Press book page:
  https://www.cambridge.org/core/books/polynomial-functors/5A57527AE303503CDCC9B71D3799231F
- Topos Institute PDF page (preface text only):
  https://toposinstitute.github.io/poly/poly-book.pdf
- ADS record for the Poly book:
  https://ui.adsabs.harvard.edu/abs/2023arXiv231200990N/abstract
- Girard, *Geometry of Interaction* (Springer chapter abstract):
  https://link.springer.com/chapter/10.1007/978-3-540-48654-1_1
- Haghverdi, GoI tutorial page (PDF text only):
  https://cgi.luddy.indiana.edu/~ehaghver/Tutorial.pdf
- Haghverdi-Scott, *A categorical model for the geometry of interaction*:
  https://www.sciencedirect.com/science/article/pii/S0304397505006808
- Abramsky-Haghverdi-Scott, *GoI and linear combinatory algebras*, MSCS:
  https://www.cambridge.org/core/journals/mathematical-structures-in-computer-science/article/abs/geometry-of-interaction-and-linear-combinatory-algebras/983F3238099D7BCBC9FAA3BC9ABBAD51
- CACM, *The Church-Turing Thesis*:
  https://cacm.acm.org/research/the-church-turing-thesis/
- CMU Harper, *λ-Calculus: The Other Turing Machine* (slides page):
  https://www.cs.cmu.edu/~rwh/talks/cs50talk.pdf

Dropped / not used (surfaced but not load-bearing):

- introtcs.org chapter on equivalent models — generic Church-Turing intro, no
  parallel-specific UTM-analogue claim.
- Wisconsin/Western Ontario PRAM slide decks — pedagogical, no foundational
  claim beyond "generalisation of RAM."
- StackExchange thread on time-complexity Church-Turing — informal.
- Tau ECTT formalisation paper page — orthogonal (sequential CT thesis).

## Bottom line

- The user's hypothesis is **substantially correct**: the parallel-models
  community has not converged on a UTM analogue. Valiant chose the *von
  Neumann* analogy explicitly. PRAM is just "RAM in parallel." Kahn is a
  *semantics*. Petri-universality is the Turing-completeness of *extensions*.
  Process algebras are *calculi*.
- The **single explicit dissent** is Hewitt's actor program, which uses
  exactly the UTM-analogue rhetoric ("universal conceptual primitives of
  digital computation," "all physically possible computation can be directly
  implemented using Actors"). This is the prior-art landmark to cite when
  framing any new universal-parallel-substrate proposal.
- In the categorical axis, **Spivak's Poly** and **Girard's GoI** are the
  closest in spirit (both pitch foundational, language-independent substrates
  for interaction / dynamics), but neither uses UTM-analogue rhetoric in
  surfaced material. Inference (flagged): Poly is structurally a strong
  candidate; the rhetorical gap is open and could be filled.
