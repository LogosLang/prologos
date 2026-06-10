# T2 Research: Distributed Systems & Parallel Computation Axis

**Mission:** Find prior framings, in distributed systems / parallel computation
literature, of monotone semilattice computation as a "universal substrate"
analogous to the Universal Turing Machine — i.e., a "parallel Church-Turing
thesis" or "foundational parallel machine". The free lattice FL(ℵ₀) itself is
not expected to appear; the question is whether the *spirit* of the framing
exists.

**TL;DR.** Across all three sub-areas (CALM/Bloom/Dedalus, Garg LLP, Kuper
LVars), the **explicit UTM-analogue / "parallel Church-Turing thesis" framing
is absent**. Each body of work makes substantially weaker but adjacent claims:
CALM frames itself as "a computability theory" for distributed consistency
with monotonicity as the demarcation principle; Garg describes
lattice-linear predicate detection as a "universal procedure" / "unifying
way" for combinatorial problems on distributive lattices; Kuper claims
lattice-based data structures are "a general and practical unifying
abstraction" / "foundation" for deterministic-by-construction parallel and
distributed programming. None invokes Turing machines, Church-Turing, or a
universal parallel machine. The strongest UTM-spirited language is Kuper's
"unifying abstraction / foundation" thesis statement and Garg's "universal
procedure" — but both are bounded (deterministic-parallel and
distributive-lattice combinatorial optimization respectively), not posed as
the substrate of all parallel computation.

---

## (c) CALM / Bloom / Dedalus (Hellerstein, Conway, Marczak, Alvaro, Ameloot)

### Direct findings (verbatim quotes)

From **Hellerstein & Alvaro, "Keeping CALM: When Distributed Consistency Is
Easy", CACM 63(9), 2020** (cacm.acm.org/research/keeping-calm/):

> "Distributed systems deserve a computability theory: When is coordination
> required for consistency, and when can it be avoided?"

> "The CALM Theorem shows that monotonicity is the answer to this question.
> Monotonic problems have consistent, coordination-free implementations;
> non-monotonic problems require coordination for consistency."

> "THEOREM 1. Consistency As Logical Monotonicity (CALM). A problem has a
> consistent, coordination-free distributed implementation if and only if it
> is monotonic."

> "Hence our Question is one of computability, like P vs. NP or Decidability.
> It asks what is (im)possible for a clever programmer to achieve."

The article also explicitly contrasts CALM with prior parallel computational
*models* (BSP), but only as a coordination protocol, not as a substrate:

> "Some well-known techniques include the Paxos and Two-Phase Commit (2PC)
> protocols, and global barriers underlying computational models like Bulk
> Synchronous Parallel computing."

From **Hellerstein, "The Declarative Imperative: Experiences and Conjectures
in Distributed Logic", SIGMOD Record 39(1), 2010**
(dsf.berkeley.edu/papers/sigrec10-declimperative.pdf abstract):

> "[We argue that the foundations] of declarative database query languages
> can provide a foundation for the next generation of parallel and
> distributed programming languages. … Datalog can serve as the rootstock of
> [a] family of languages for programming serious parallel and distributed
> software."

From **Alvaro, Conway, Hellerstein, Marczak, "Consistency Analysis in Bloom:
A CALM and Collected Approach", CIDR 2011** (dsf.berkeley.edu/papers/cidr11-bloom.pdf abstract):

> "We address this situation with the CALM principle, which connects the idea
> of distributed consistency to program tests for logical monotonicity."

From **Ameloot, Neven, Van den Bussche, "Relational Transducers for
Declarative Networking", JACM 60(2), 2013** (dl.acm.org/doi/10.1145/1989284.1989321),
quoted in CACM Keeping-CALM article:

> "To capture the notion of a distributed system composed out of monotonic
> (or non-monotonic) logic, Ameloot uses the formalism of a relational
> transducer running on each machine in a network."

The reverse direction of CALM (proven by Ameloot et al.) gives an
**equivalence between coordination-free distributed computability and
monotonicity** — the closest thing in the literature to a "demarcation
theorem" for a parallel substrate. From Zinn / Ameloot / Neven 2012 PODS
("Win-move is coordination-free (sometimes)", dl.acm.org/doi/10.1145/2274576.2274588):

> "Ameloot et al. showed that a query can be computed by a coordination-free
> relational transducer network iff it is monotone, thus answering in the
> affirmative a variant of Hellerstein's CALM conjecture, based on a
> particular definition of coordination-free computation."

### Closest framings to UTM-analogue / "parallel CT thesis"

- The **explicit "computability theory" framing** in Keeping-CALM is the
  closest. Hellerstein & Alvaro draw an explicit analogy to "P vs. NP or
  Decidability" — both *Turing-era* computability concepts — but the
  *machine model* invoked is **Ameloot's relational transducer network**,
  not a lattice. The lattice/monotonicity is the *property* that demarcates
  what the transducer-network model can compute coordination-free.
- **BloomL / Conway et al. 2012 SoCC ("Logic and Lattices for Distributed
  Programming")** introduces lattices as first-class state, but frames them
  as a *type system* for monotonic state inside the existing Bloom/transducer
  model — not as the model itself.
- The 2010 SIGMOD "Declarative Imperative" calls Datalog (not lattices) the
  "rootstock" / "foundation" for next-gen parallel/distributed languages.

### Verdict: **adjacent, not explicit**

CALM/Bloom/Dedalus *do* make a foundational, computability-flavored claim:
monotonicity is the iff-condition for coordination-free distributed
computability over relational-transducer networks. But:

1. The substrate they posit is the **relational transducer network** (a
   message-passing Datalog model), not the lattice. The lattice/monotonicity
   is the *demarcator*, not the *machine*.
2. There is **no UTM analogy**, no use of "Church-Turing", no claim that
   monotone-lattice computation is *universal* in the Turing sense. The
   theorem is a characterization, not a universality result.
3. The framing is **negative-bound** (what cannot be done coordination-free)
   rather than constructive-universal (this substrate computes everything
   computable in parallel).

CALM is the closest existing framing in the literature to "lattice =
foundational parallel substrate", but it stops well short of the UTM/CT-thesis
analogy.

---

## (d) Garg lattice-linear predicate detection

### Direct findings (verbatim quotes)

From **Garg, "Predicate Detection to Solve Combinatorial Optimization
Problems", SPAA 2020** (par.nsf.gov/servlets/purl/10190128 abstract):

> "We present a method to design parallel algorithms for constrained
> combinatorial optimization problems by casting them as searching for an
> element that satisfies an appropriate predicate in a distributive lattice.
> … Lattice-Linear Predicate Detection (LLP) can be implemented in parallel
> without any locks or compare-and-swap operations."

From **Garg's book page, "A Systematic Approach to Parallel Algorithms"**
(users.ece.utexas.edu/~garg/algo.html):

> "I show that many parallel (and sequential) algorithms can be derived in a
> systematic manner. In our approach, a problem is cast as searching for an
> element satisfying an appropriate predicate in a distributive lattice.
> Multiple processes cooperate to determine the element. Our method solves
> and generalizes many classical combinatorial optimization problems …"

From **Streit & Garg, "Constrained Cuts, Flows, and Lattice-Linearity",
arXiv:2512.18141 (Dec 2025)** (arxiv.org/html/2512.18141v1):

> "Recently, [Garg 2020] showed that many problems on distributive lattices
> can be solved in a simple and unifying way using lattice-linear predicate
> detection. The idea is to model the problem as satisfaction of a
> lattice-linear predicate, which informally is such that the satisfying
> preimage forms a semilattice under some meet operation. **Lattice-linear
> predicate detection can be solved by a universal procedure admitting simple
> parallel algorithmic implementations**." [emphasis added]

> "Application of lattice-linear predicate detection towards combinatorial
> problems was introduced in [Garg 2020] by building on algorithms for
> verifying distributed systems [Chase-Garg 1998]. **A key feature is the
> ability to analyze and solve a large variety of combinatorial problems in
> a unifying way.**"

The lattice/semilattice structure is foundational to the method:

> "BB is lattice-linear if and only if B(G) ∧ B(H) ⟹ B(G ⊓ H), i.e. the set
> of elements satisfying B is a meet-subsemilattice of ℒ."

From **Chase & Garg, "Detection of Global Predicates: Techniques and Their
Limitations", Distributed Computing 11(4), 1998** (Springer abstract):

> "We show that the problem of predicate detection in distributed systems is
> NP-complete. … We introduce a class of predicates, semi-linear predicates,
> which properly contains all linear predicates …"

The lattice-of-consistent-global-states model (Mattern/Cooper-Marzullo,
formalized by Chase-Garg) frames a distributed computation as a poset whose
ideals form a distributive lattice; LLP is then "search this lattice for an
element satisfying B".

### Closest framings to UTM-analogue

The phrase **"universal procedure"** in Streit & Garg 2025 is the most
UTM-spirited single word found in the Garg corpus. But the universality is
bounded: the procedure is universal *over the class of lattice-linear
predicates on distributive lattices*. It is not claimed to be a universal
substrate for parallel computation in the Church-Turing sense.

Garg's book title — **"A Systematic Approach to Parallel Algorithms"** with
the lattice search framing — comes close in spirit ("many parallel and
sequential algorithms can be derived in a systematic manner") but again is
methodological, not foundational/universal in the Turing sense.

### Verdict: **adjacent, not explicit**

- Garg has the **strongest "universal procedure" language** of the three
  sub-areas, and explicitly grounds his algorithmic method in
  distributive-lattice / semilattice structure.
- However, the universality is **scoped to lattice-linear predicate
  detection**, which is a (rich, but bounded) class of combinatorial
  optimization problems — not all parallel computation.
- **No Turing-machine analogy. No Church-Turing thesis language.** The work
  is presented as a unifying *algorithmic technique*, not as a foundational
  model of computation.
- Garg's earlier (Chase-Garg 1995/1998) work establishes the
  consistent-global-states *lattice* as the canonical model for distributed
  predicate detection — this *is* a "lattice-as-substrate" framing for
  distributed observability, but it is observational/diagnostic, not
  computational-universal.

---

## (e) Kuper LVars

### Direct findings (verbatim quotes)

From **Kuper, "My thesis proposal" blog post (Nov 2013)**
(decomposition.al/blog/2013/11/30/my-thesis-proposal-and-my-second-hacker-school-residency/):

> "**Lattice-based data structures are a general and practical foundation
> for deterministic and quasi-deterministic parallel and distributed
> programming.**" [Kuper's thesis statement, verbatim]

From **Kuper, dissertation defense talk notes
(github.com/lkuper/dissertation/blob/master/talks/defense.md, 2014)**:

> "…my thesis is that lattice-based data structures are a general and
> practical unifying abstraction for deterministic and quasi-deterministic
> parallel and distributed programming."

> "[D]ifferent formalisms, and, one could argue, perhaps even different
> subfields of CS have been developed to deal with these two big problems
> [parallel and distributed]. So, it's useful to try to find unifying
> abstractions that can perhaps help us understand and make progress on both
> of these problems — and this is really what motivates me: trying to find
> unifying abstractions for programming."

> "All of those points in the space [pure FP, dataflow / Kahn networks,
> single-assignment IVars, disjoint imperative parallelism] are either
> subsumed by, or are compatible with, the LVars programming model that I'm
> going to talk about, because **LVars are a general unifying abstraction
> for deterministic parallel programming**."

> "IVars turn out to be a special case of LVars."

> "And finally, I've shown how we can bring LVar-style threshold reads to
> the setting of convergent replicated data types in distributed cloud
> storage systems. And so we can have LVars not only across the landscape
> but also in the cloud!"

From **Kuper & Newton, "LVars: Lattice-based Data Structures for
Deterministic Parallelism", FHPC 2013**
(users.soe.ucsc.edu/~lkuper/papers/lvars-fhpc13.pdf abstract / excerpt):

> "We present LVars, a new model for deterministic-by-construction parallel
> programming that **generalizes existing single-assignment models** to
> allow multiple assignments that are monotonically increasing with respect
> to a user-specified lattice."

> "**A general model**: By taking monotonicity as a starting point …"

From **Kuper et al., "Freeze After Writing", POPL 2014**
(users.soe.ucsc.edu/~lkuper/papers/lvish-popl14.pdf):

> "A principled approach to deterministic-by-construction parallel
> programming with shared state is offered by LVars: shared memory locations
> whose semantics are defined in terms of an application-specific lattice."

### Closest framings to UTM-analogue / "parallel CT thesis"

Kuper's thesis statement is the **single strongest "lattice = foundation /
unifying abstraction"** claim found in any of the three sub-areas:

- "**foundation**" appears verbatim in the thesis-proposal phrasing.
- "**general and practical unifying abstraction**" is the dissertation
  phrasing.
- LVars are explicitly shown to **subsume** other deterministic-parallel
  models (IVars, Kahn process networks, pure FP, disjoint imperative
  parallelism) — a *de facto* universality argument, but only within the
  scope of "deterministic-by-construction parallel programming", not over
  all computation.

### Verdict: **adjacent, not explicit**

- Kuper's framing is the **closest to a UTM-spirit claim** in the literature
  surveyed: "foundation", "unifying abstraction", and explicit subsumption
  of multiple prior parallel-programming models. The defense talk literally
  enumerates a "landscape" of deterministic-parallel models and argues LVars
  cover all of them.
- However:
  1. **No Turing/Church-Turing analogy is invoked.** The word "universal"
     does not appear as a thesis claim; the words used are "general",
     "unifying", "foundation".
  2. The scope is explicitly **deterministic-by-construction parallelism**,
     not parallel computation in general. Nondeterministic parallel
     computation is outside the model's claim.
  3. No claim that arbitrary parallel computations can be *encoded* into
     monotone-lattice form (which is what a true UTM-analogue would require).

The Kuper framing is the **strongest adjacent precedent** for the
"lattice-as-foundational-parallel-substrate" intuition, but it stops short
of a UTM analogy or a parallel-Church-Turing-thesis claim.

---

## Cross-cutting observations

1. **The word "universal" appears once** — in Streit & Garg 2025, applied to
   the LLP *procedure*, not to lattices as a substrate.
2. **The word "foundation"** appears in Hellerstein 2010 (Datalog as
   foundation) and Kuper 2013 (lattice-based data structures as foundation).
3. **No paper or talk in the surveyed corpus uses "Church-Turing", "Turing
   machine", or "universal substrate"** in connection with monotone /
   lattice / semilattice computation.
4. **The CALM theorem is the closest to a "computability theorem"** for a
   parallel substrate — but the substrate is the relational-transducer
   network, and lattices/monotonicity are the *property* that demarcates
   what it can compute coordination-free.
5. **All three traditions converge on a shared mathematical kernel**:
   monotone functions over a join-semilattice with idempotent/commutative
   merge. None of them frames that kernel as a Turing-equivalent universal
   parallel machine.

---

## Open questions / blocked checks

- Did **Conway's PhD dissertation** (Berkeley, ~2014) on Bloom/BloomL contain
  any stronger universality framing than the published papers? Not located
  via the searches conducted; would need targeted dblp / Berkeley dissertation
  catalogue lookup.
- Did **Marczak's** Dedalus papers / dissertation invoke any
  computability-theoretic universality language? Not located.
- Did **Ameloot's** dissertation ("Declarative Networking: Recent Theoretical
  Work …", SIGMOD Record 2014) frame relational transducers as a
  "universal parallel machine"? The SIGMOD Record summary did not surface
  such language; full dissertation not consulted (PDF avoided per brief).
- **Lasp** (Meiklejohn & Van Roy, PPDP 2015), referenced in Keeping-CALM as
  a CRDT-composition language, was not searched directly. Worth a follow-up
  if a stronger "universal substrate" framing exists in the CRDT/eventual-
  consistency literature.
- **Suggested next step:** dblp-search Ameloot, Neven, Marczak, Conway for
  any survey/keynote/blog-post material; check if Hellerstein's PODS 2010
  keynote slides (vs. SIGMOD Record write-up) contain stronger language.

---

## Sources (URLs consulted)

### CALM / Bloom / Dedalus
- https://cacm.acm.org/research/keeping-calm/ — Hellerstein & Alvaro, *Keeping CALM*, CACM 63(9), 2020 (full HTML article fetched)
- https://arxiv.org/abs/1901.01930 — arXiv preprint of Keeping CALM
- https://dsf.berkeley.edu/papers/cidr11-bloom.pdf — Alvaro et al., CIDR 2011 (abstract from search snippet)
- https://dsf.berkeley.edu/papers/UCB-lattice-tr.pdf — Conway et al., BloomL TR (abstract snippet)
- https://dsf.berkeley.edu/papers/sigrec10-declimperative.pdf — Hellerstein, *The Declarative Imperative*, SIGMOD Record 2010 (abstract snippet)
- http://www.bloom-lang.net/calm/ — Bloom language site, "calm: consistency as logical monotonicity"
- https://dsf.berkeley.edu/bloom-lattice/ — BloomL / SoCC'12 page
- https://dl.acm.org/doi/10.1145/1989284.1989321 — Ameloot/Neven/Van den Bussche, PODS 2011 / JACM 2013
- https://dl.acm.org/doi/10.1145/2274576.2274588 — Zinn/Green/Ludäscher, *Win-move is coordination-free (sometimes)*, ICDT 2012
- https://dl.acm.org/doi/10.1145/2694413.2694415 — Ameloot, SIGMOD Record 2014 (declarative networking survey)
- https://documentserver.uhasselt.be/handle/1942/16393 — Zinn et al., *Weaker Forms of Monotonicity for Declarative Networking*, PODS 2014
- https://bibbase.org/network/publication/hellerstein-alvaro-keepingcalmwhendistributedconsistencyiseasy-2020 — bib entry
- https://par.nsf.gov/biblio/10221254-keeping-calm-when-distributed-consistency-easy — NSF PAR landing

### Garg lattice-linear predicate detection
- https://users.ece.utexas.edu/~garg/topics/detection-desc.html — Garg, predicate-detection topic page (full text fetched)
- https://users.ece.utexas.edu/~garg/dist/spaa20-slides.pdf — Garg SPAA 2020 slides (snippet)
- https://users.ece.utexas.edu/~garg/dist/icdcn13-lattice-slides.pdf — Garg, antichain-lattice algorithms slides, ICDCN 2013 (snippet)
- https://users.ece.utexas.edu/~garg/dist/wdag95.pdf — Chase-Garg WDAG 1995 (snippet)
- https://users.ece.utexas.edu/~garg/algo.html — Garg, *A Systematic Approach to Parallel Algorithms* book page
- https://link.springer.com/article/10.1007/s004460050049 — Chase & Garg, *Detection of Global Predicates*, Distributed Computing 11(4), 1998 (Springer abstract)
- https://arxiv.org/abs/2103.06264 — Garg, *Lattice Linear Predicate Parallel Algorithm for Dynamic Programming*, 2021 (abstract)
- https://par.nsf.gov/servlets/purl/10190128 — Garg SPAA 2020 author copy (abstract snippet)
- https://par.nsf.gov/servlets/purl/10384080 — Garg dynamic programming LLP (abstract snippet)
- https://arxiv.org/html/2512.18141v1 — Streit & Garg, *Constrained Cuts, Flows, and Lattice-Linearity*, arXiv:2512.18141 (Dec 2025) — full HTML fetched; contains "universal procedure" quote

### Kuper LVars
- https://decomposition.al/ — Kuper's blog index
- https://decomposition.al/blog/2013/11/30/my-thesis-proposal-and-my-second-hacker-school-residency/ — Kuper, thesis proposal post (full text fetched; verbatim thesis statement)
- https://decomposition.al/blog/2014/08/18/dissertation-draft-readers-wanted/ — dissertation-draft post (snippet)
- https://decomposition.al/blog/2013/01/18/a-ten-minute-talk-about-my-research/ — ten-minute talk
- https://decomposition.al/blog/2013/05/25/how-to-read-from-an-lvar-an-illustrated-guide/ — LVar reads tutorial
- https://decomposition.al/blog/2013/09/22/some-example-mvar-ivar-and-lvar-programs-in-haskell/ — MVar/IVar/LVar examples
- https://decomposition.al/blog/2013/10/31/whats-the-deal-with-lvars-and-crdts/ — LVars & CRDTs (RICON West talk writeup)
- https://decomposition.al/blog/2014/05/28/the-lvar-that-was-after-all/ — LVar revisited
- https://users.soe.ucsc.edu/~lkuper/papers/lindsey-kuper-dissertation.pdf — dissertation (abstract snippet from search; PDF not parsed per brief)
- https://users.soe.ucsc.edu/~lkuper/papers/lvars-fhpc13.pdf — LVars FHPC 2013 paper (abstract snippet)
- https://users.soe.ucsc.edu/~lkuper/papers/lvish-popl14.pdf — Freeze After Writing POPL 2014 (abstract snippet)
- https://aturon.github.io/academic/lvish-tr.pdf — LVish TR (abstract snippet)
- https://github.com/lkuper/dissertation/blob/master/talks/defense.md — Kuper dissertation defense notes (full text fetched; many verbatim "unifying abstraction" / "general and practical foundation" quotes)
