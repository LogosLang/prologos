# Round-2 Audit: Wolfram + Propagator-Networks + CRDT-Engineering

**Brief:** T11. Goal — find any explicit framing of *X* as a UTM-analogue, parallel
Church-Turing thesis, or universal/foundational substrate for parallel/concurrent
computation in (h) Wolfram, (i) propagator networks, (j) CRDT engineering.
Per-axis verdict: **explicit / adjacent / absent** of the precise FL(ℵ₀)-style
priority claim ("free lattice on ℵ₀ generators is to parallel computation what
the UTM is to sequential computation").

---

## (h) Wolfram (NKS, Wolfram Physics Project, multiway/hypergraph rewriting)

### Direct findings (verbatim quotes)

**Principle of Computational Equivalence (PCE), NKS Ch. 12.**

> "the essence of [universality] is that it is possible to construct universal
> systems that can perform essentially any computation — and which must therefore
> all in a sense be capable of exhibiting the highest level of computational
> sophistication."
> — *NKS* Ch. 12 PDF (`files.wolframcdn.com/.../nks-ch12.pdf`)

> "the Principle of Computational Equivalence asserts that even in such a case,
> whenever the behavior one sees is not obviously simple, it will almost always
> correspond to a computation of equivalent sophistication."
> — *NKS* p.719 (`wolframscience.com/nks/p719--the-content-of-the-principle/`)

PCE is universality-flavored but **explicitly *equivalence*, not *foundational
parallel substrate*.** It asserts ceiling-of-sophistication, not "X is the
universal substrate of parallelism."

**Wolfram Physics Project — multiway/hypergraph models as universal.**

> "The Principle of Computational Equivalence suggests that when the behavior of
> our models is not obviously simple it will typically correspond to a
> computation of effectively maximal sophistication. And an important piece of
> evidence for this is that our models are capable of universal computation. ...
> our models can emulate a variety of other kinds of systems. Among these are
> Turing machines and cellular automata."
> — Wolfram Physics Project, *Computational Capabilities of Our Models*
> (`wolframphysics.org/.../computational-capabilities-of-our-models/`)

**Multiway Turing Machines.**

> "The closest analogous definition of computation universality for multiway
> Turing machines is to say that with appropriate initial conditions the
> multiway evolution of a Turing machine can emulate (up to suitable encoding)
> the multiway evolution of any other Turing machine."
> — *Multiway Turing Machines* bulletin, Feb 2021
> (`bulletins.wolframphysics.org/2021/02/multiway-turing-machines/`)

This is the **closest explicit verbiage to a "parallel UTM analogue"** found in
the corpus: a multiway Turing machine that universally simulates other multiway
Turing machines is, by construction, a universality result for nondeterministic
/ multi-thread-of-time evolution.

**The Multicomputational Paradigm — strongest "foundational parallel substrate"
language.** Wolfram's 2021 essay *Multicomputation: A Fourth Paradigm for
Theoretical Science* explicitly frames multiway systems as a new universal
substrate that subsumes the (sequential) computational paradigm:

> "at the core of our Physics Project is actually a new paradigm that goes
> beyond the computational one: a fourth paradigm for theoretical science that
> I'm calling the multicomputational paradigm. ... it really is a fundamentally
> new paradigm — that transcends physics and applies quite generally as the
> foundation for a new and broadly applicable methodology for making models in
> theoretical science."
> — *Multicomputation* (writings.stephenwolfram.com, Sep 2021)

> "In the ordinary computational paradigm, time in effect progresses in a linear
> way, corresponding to the successive computation of the next state of the
> system from the previous one. But in the multicomputational paradigm there is
> no longer just a single thread of time; instead one can think of every
> possible path through the multiway system as defining a different interwoven
> thread of time."
> — *Multicomputation*

> "The essence of the multicomputational paradigm is to generalize beyond just
> having simple linear sequences of states, and in effect to allow multiple
> interwoven threads of history."
> — *Multicomputation*

> "The multicomputational paradigm, however, suggests computations that involve
> not just chains of evaluation events, but more complicated graphs of them. ...
> The multicomputational paradigm is about the rather different idea of actually
> treating the 'answer' as corresponding to a whole bundle of paths that are
> combined or conflated through a choice of reference frame. ... gives us a
> general way to think about — and harness — such things. And potentially gives
> us a very different — and powerful — new approach to distributed computing,
> perhaps complete with very general physics-like 'bulk' laws."
> — *Multicomputation*, §"Distributed Computing"

**Ruliad (limit object).**

> "The ruliad may be defined as the entangled limit of everything that is
> computationally possible, i.e., the result of following all possible
> computational rules in all possible ways."
> — MathWorld, *Ruliad* (`mathworld.wolfram.com/Ruliad.html`)

> "The multicomputational paradigm is a generalization of the computational
> paradigm to many computational threads of time. In the ordinary computational
> paradigm, time effectively progresses in a linear way ...; in the
> multicomputational paradigm every possible path through a computation
> proceeds through a different thread of time."
> — MathWorld, *Multicomputational Paradigm*

### Verdict: **EXPLICIT (closest competing claim found in round 2)**

Wolfram's *multicomputational paradigm* is, in the literal text, framed as the
foundational successor to the (sequential) computational paradigm — including
explicit application to distributed/concurrent computing. The substrate
candidates are **multiway systems** (states + non-deterministic update events)
and **hypergraph rewriting**, with the **ruliad** as the limit-of-everything
object.

This is the strongest non-lattice competitor to the FL(ℵ₀) priority claim:
- Wolfram explicitly calls multicomputation a "fundamentally new paradigm" and
  "the foundation for a new methodology" — universality language.
- Multiway systems explicitly model "every possible interwoven thread of time."
- He claims this gives "a very different — and powerful — new approach to
  distributed computing."
- The connection to lattices is *implicit* (the ruliad has the structure of a
  Hasse diagram of a partial order, and Wolfram explicitly notes "[multiway
  graphs] have the mathematical structure of Hasse diagrams for partial
  orderings"; "the 'partially ordered set of finite causets' (or 'poscau') ...
  can be thought of as a multiway system").

**Important caveats for the priority audit.**
- Wolfram does **not** identify a *specific algebraic free object* (free
  lattice, free monoid-with-merge, etc.) as the universal substrate. He
  identifies a *graph-theoretic / rewrite-theoretic* substrate.
- He does not say "the X is to parallel computation what the UTM is to
  sequential computation" in those words; the closest is the universality
  result for multiway Turing machines and the framing of multicomputation as
  the "fourth paradigm."
- FL(ℵ₀) and the ruliad are *both* "everything-at-once" limit objects. The
  ruliad is rule-graph-theoretic; FL(ℵ₀) is order-algebraic. They are sibling
  framings rather than the same claim — but Wolfram's claim is older (2020-21)
  and more prominent.

---

## (i) Propagator networks (Sussman & Radul)

### Direct findings (verbatim quotes)

**Radul (2009 PhD thesis, MIT-CSAIL-TR-2009-053), title and abstract.**

Title: ***Propagation Networks: A Flexible and Expressive Substrate for
Computation*** (the word "Substrate" is in the title).

Abstract:

> "In this dissertation I propose **a shift in the foundations of computation**.
> Modern programming systems are not expressive enough. The traditional image of
> a single computer that has global effects on a large memory is too restrictive.
> The propagation paradigm replaces this with computing by networks of local,
> independent, stateless machines interconnected with stateful storage cells.
> ... A foundational layer is missing. ... I reflect on the new light the
> propagation perspective sheds on the deep nature of computation."

Chapter 1, §1.4 *Propagation promises Liberty*:

> "I believe that general-purpose propagation offers an opportunity of
> revolutionary magnitude. The move from instructions to expressions led to an
> immense gain in the expressive power of programming languages... The move
> from expressions to propagators is the next step in that path."

§2.1 (autonomy/asynchrony of propagators, the parallel/concurrent posture):

> "Let us likewise posit that our propagators are autonomous, asynchronous, and
> always on — always ready to perform their respective computations. This way,
> there is no notion of time embedded in questions of which device might do
> something when, for they are all always free to do what they wish."

> "A production system based on these principles might dedicate hardware to some
> propagators, or timeshare batches of propagators on various cores of a
> multicore processor, or do arbitrarily fancy distributed, decentralized,
> buzzword-compliant acrobatics. ... we will gain our expressive power even
> without sophisticated execution strategies."

The thesis explicitly subsumes evaluation:

> "I show that propagation subsumes evaluation (of expressions) the same way
> that evaluation subsumes execution (of instructions)."

**Sussman & Radul, "The Art of the Propagator" (MIT-CSAIL-TR-2009-002).**

> "We develop a programming model built on the idea that the basic computational
> elements are autonomous machines interconnected by shared cells through which
> they communicate. ... We use the idea of a propagator network as a
> computational metaphor for exploring the consequences of allowing places to
> accept information from multiple sources."

Note: cells **accumulate partial information** via merge (a join-semilattice in
practice, although Radul does not use the word "lattice" in the abstract); the
contract is exactly a monotone-merge semilattice contract:

> "Instead of thinking of a cell as an object that stores a value, think of a
> cell as an object that stores everything you know about a value."

> "It is important that this be accumulating partial information: it must never
> be lost or replaced. A cell's promise to remember everything it was ever told
> is crucial to gaining freedom from time."

(This is monotonicity. The connection to Birkhoff/Tarski lattice theory and to
CALM is implicit but never made explicit by Radul.)

### Verdict: **EXPLICIT — for "substrate" framing; ADJACENT — for the precise FL(ℵ₀)-style priority claim**

Radul's thesis explicitly proposes propagator networks as **a foundational
substrate for computation**, displacing both assembly (sequential instruction)
and Lisp-style expression evaluation. The framing is:

- "shift in the foundations of computation"
- "foundational layer is missing"
- propagators **subsume** evaluation as evaluation subsumes assembly
- explicitly motivated by **freedom from sequential time** and amenability to
  parallel/distributed/multicore execution

This is unmistakably a "universal parallel substrate" framing — but the
substrate identified is the **propagator network architecture** (cells +
asynchronous propagators + monotone merge), **not** any free algebraic object.
Radul does not name lattices, free lattices, semilattices, or any priority
claim of the form "X is to parallel computation as UTM is to sequential
computation." The relationship to FL(ℵ₀) is structural (cells are
join-semilattices; quiescence is the lattice fixed point) but is left implicit.

This is the closest thing to a *direct lineage* for the design we're auditing:
Prologos's propagator base is descended from this work, and Radul's "substrate
for computation" claim is the direct ancestor framing.

---

## (j) CRDT engineering (Shapiro et al., Lasp, Automerge, Yjs, Riak)

### Direct findings (verbatim quotes)

**Shapiro, Preguiça, Baquero, Zawirski — *Conflict-free Replicated Data Types*
(SSS 2011 / INRIA RR-7687).**

> "Under a formal Strong Eventual Consistency (SEC) model, we study sufficient
> conditions for convergence. A data type that satisfies these conditions is
> called a Conflict-free Replicated Data Type (CRDT). Replicas of any CRDT are
> guaranteed to converge in a self-stabilising manner, despite any number of
> failures."
> — Shapiro et al., RR-7687 abstract

The convergence proof is built on the join-semilattice structure of state-based
CRDTs: states form a join-semilattice, updates monotonically increase, replicas
merge by join (LUB), so all replicas converge to the same supremum. **This is
precisely the lattice-monotonicity-on-network mantra.** But Shapiro et al. do
**not** use universality language; they frame CRDTs as a *design discipline for
eventual consistency*, not as a "universal substrate for distributed
computation."

**Lasp — Meiklejohn & Van Roy (PPDP 2015).**

> "We propose Lasp, a new programming model designed to simplify large-scale
> distributed programming. Lasp combines ideas from deterministic dataflow
> programming with conflict-free replicated data types ..."
> — PPDP 2015 preprint

The 2025 retrospective (`webperso.info.ucl.ac.be/~pvr/ppdp-2025-lasp.pdf`):

> "Lasp, a coordination-free programming model built atop Conflict-Free
> Replicated Data Types (CRDTs). Designed to simplify distributed programming
> by prioritizing availability and convergence ..."

Lasp explicitly takes **lattices** as the unifying primitive ("Lattice
Processing" — the L in Lasp). But Meiklejohn & Van Roy do not write "Lasp /
CRDTs are to parallel computation what the UTM is to sequential computation."
The framing is engineering-pragmatic ("simplify large-scale distributed
programming"), not universality-claiming.

**Automerge / Yjs / Loro.** Pure documentation-level framing:

> "Automerge is a library which provides fast implementations of several
> different CRDTs ... The objective of the project is to support local-first
> applications in the same way that relational databases support server
> applications — by providing mechanisms for collaborative work without
> requiring central servers."
> — `github.com/automerge/automerge`

> "Yjs is a CRDT implementation that exposes its internal data structure as
> *shared types*. ... changes are automatically distributed to other peers and
> merged without merge conflicts. ... Yjs is network agnostic (p2p!), supports
> many existing rich text editors ..."
> — `github.com/yjs/yjs`

These are tool/library framings, **not foundational claims**.

**Closest "universal" usage found:**

> "**The Blocklace: A Universal, Byzantine Fault-Tolerant, Conflict-free
> Replicated Data Type**"
> — Lewis-Pye & Shapiro, arXiv:2402.08068

But here "universal" means *can implement any CRDT* (i.e., universality within
the class of CRDTs), not "universal substrate for parallel computation."

### Verdict: **ABSENT (engineering literature) / ADJACENT (Lasp)**

The CRDT engineering literature uniformly avoids universality / foundational /
parallel-Church-Turing framings. It treats CRDTs as a **design discipline for
eventual consistency** built on the join-semilattice merge contract. Lattices
are the unifying technical primitive (especially in Lasp), and the
join-semilattice / monotone-merge contract is exactly what FL(ℵ₀) instantiates
abstractly — but no CRDT engineering paper found makes a priority claim of the
form "lattices/CRDTs are the universal substrate for parallel computation" or
"CRDTs are to parallel computation as the UTM is to sequential computation."

The Blocklace paper's "Universal" qualifier is universality *within* the CRDT
class, not foundational-substrate universality.

CALM (Hellerstein–Ameloot, *Keeping CALM*, CACM 2020) — covered in round 1 —
remains the closest adjacent framing on the engineering / theory side: it
identifies monotonicity (lattice-style) as exactly what's coordination-free.
But CALM, too, frames this as a *theorem about coordination*, not as "the
universal substrate."

---

## Cross-axis summary

| Axis | Verdict | Closest competing framing |
|------|---------|---------------------------|
| (h) Wolfram | **EXPLICIT** | Multicomputational paradigm as "fourth foundational paradigm"; ruliad as everything-at-once limit object; explicit application to distributed computing |
| (i) Propagator networks | **EXPLICIT for "substrate"; ADJACENT for FL(ℵ₀)-style priority** | Radul thesis title + abstract: "shift in the foundations of computation," propagation as substrate, propagators subsume evaluation |
| (j) CRDT engineering | **ABSENT (universality framing); ADJACENT (lattice primacy)** | Lasp's "Lattice Processing"; CRDT semilattice merge is structurally identical to FL(ℵ₀)-style join, but no priority claim |

**Net effect on the FL(ℵ₀) priority audit.**

1. **Wolfram is the most serious priority threat.** The multicomputational
   paradigm essay (2021) explicitly stakes out "fourth foundational paradigm"
   territory for *multi-thread-of-time / multiway / hypergraph rewriting* as the
   universal substrate that supersedes the sequential computational paradigm,
   with explicit application to distributed computing. The substrate identified
   is graph-rewrite-theoretic, not order-algebraic, but the *role* in the
   architecture is the same role FL(ℵ₀) is being claimed to play.
2. **Radul's "substrate" framing is the direct ancestor of Prologos's
   propagator base.** The priority claim being audited cannot be made without
   acknowledging Radul's "I propose a shift in the foundations of computation"
   — that exact phrase exists in his abstract. Any FL(ℵ₀)-as-UTM-analogue paper
   must cite Radul as prior art for the "substrate" framing, while
   distinguishing the *kind* of substrate (algebraic / order-theoretic vs.
   architectural / propagator-network).
3. **CRDT engineering is the technology that already realizes the
   join-semilattice merge contract at internet scale.** Any priority claim has
   to acknowledge that CRDTs *engineer* exactly the FL(ℵ₀) merge primitive on
   distributed substrates (Yjs, Automerge, Riak), even though no CRDT paper
   makes the "universal substrate" priority claim.

---

## Open questions / blocked checks

- **Wolfram's exact phrasing on parallel-Church-Turing.** Did Wolfram or Gorard
  ever write the literal sentence "multiway systems are to parallel/concurrent
  computation what the Turing machine is to sequential computation"? Not found
  in the searched corpus, but plausibly exists in Gorard's papers or Wolfram's
  livestreams. Worth a targeted Gorard arXiv search in a follow-up.
- **Hewitt actor model.** Out of scope for this brief but possibly relevant as
  an even-earlier "universal model of concurrent computation" claim — Hewitt
  has explicitly framed actors that way.
- **Lasp/CALM — semilattice as universal coordination primitive.** Could not
  find a paper that explicitly says "the join-semilattice is the universal
  primitive for coordination-free distributed computation" in those words; the
  CALM theorem is the strongest known statement (monotone ⇒ coordination-free,
  and a converse).

## Sources (all URLs)

### Wolfram
- https://www.wolframscience.com/nks/p719--the-content-of-the-principle/
- https://www.wolframscience.com/nks/notes-12-2--note-for-mathematicians-about-pce/
- https://www.wolframscience.com/nks/chap-12--the-principle-of-computational-equivalence/
- https://files.wolframcdn.com/pub/www.wolframscience.com/nks/nks-ch12.pdf
- https://wolframphysics.org/technical-introduction/equivalence-and-computation-in-our-models/computational-capabilities-of-our-models/index.html
- https://www.wolframphysics.org/technical-introduction/the-updating-process-in-our-models/multiway-systems-for-our-models/
- https://bulletins.wolframphysics.org/2021/02/multiway-turing-machines/
- https://www.wolframphysics.org/bulletins/2021/10/multicomputation-with-numbers-the-case-of-simple-multiway-systems/
- http://www.wolframphysics.org/technical-introduction/potential-relation-to-physics/multiway-systems-in-the-space-of-all-possible-rules/index.html
- https://www.wolframphysics.org/technical-introduction/potential-relation-to-physics/basic-concepts/index.html
- https://www.wolframphysics.org/technical-introduction/equivalence-and-computation-in-our-models/correspondence-with-other-systems/index.html
- https://www.wolframphysics.org/bulletins/2020/06/exploring-rulial-space-the-case-of-turing-machines/
- https://www.wolframphysics.org/questions/computation-theory/
- https://wolframinstitute.org/output/multicomputation-a-fourth-paradigm-for-theoretical-science
- https://writings.stephenwolfram.com/2021/09/even-beyond-physics-introducing-multicomputation-as-a-fourth-general-paradigm-for-theoretical-science/
- https://writings.stephenwolfram.com/2021/09/charting-a-course-for-complexity-metamodeling-ruliology-and-more/
- https://arxiv.org/abs/2101.10907 (Wolfram, *Exploring Rulial Space: The Case of Turing Machines*)
- https://mathworld.wolfram.com/Ruliad.html
- https://mathworld.wolfram.com/Multicomputation.html
- https://mathworld.wolfram.com/MulticomputationalParadigm.html

### Propagator networks
- https://dspace.mit.edu/handle/1721.1/44215 (Sussman & Radul, *Art of the Propagator*, MIT-CSAIL-TR-2009-002)
- https://dspace.mit.edu/bitstream/handle/1721.1/44215/MIT-CSAIL-TR-2009-002.pdf
- https://dspace.mit.edu/handle/1721.1/49525 (Radul thesis, *Propagation Networks: A Flexible and Expressive Substrate for Computation*, MIT-CSAIL-TR-2009-053)
- https://groups.csail.mit.edu/genesis/papers/radul%202009.pdf
- http://hdl.handle.net/1721.1/54635
- https://groups.csail.mit.edu/mac/users/gjs/propagators/ (Sussman, *Revised Report on the Propagator Model*)
- https://systemreboot.net/post/propnet-primer
- https://blog.tanyakhovanova.com/2009/08/propagation-networks/

### CRDT engineering
- https://inria.hal.science/hal-00932836v1/file/CRDTs_SSS-2011.pdf (Shapiro et al., SSS 2011)
- https://pages.lip6.fr/Marc.Shapiro/papers/RR-7687.pdf (INRIA RR-7687)
- https://gsd.di.uminho.pt/members/cbm/members/cbm/ps/sss2011.pdf
- https://dsf.berkeley.edu/cs286/papers/crdt-tr2011.pdf
- https://hal.science/hal-01578910v1/file/replicated-data-types-Encyclopedia-DB-systems-2016-authorversion.pdf
- https://arxiv.org/abs/0907.0929 (Shapiro/Preguiça, *CRDTs: Consistency without concurrency control*)
- https://christophermeiklejohn.com/publications/ppdp-2015-preprint.pdf (Lasp PPDP 2015)
- https://dl.acm.org/doi/10.1145/2790449.2790525
- https://webperso.info.ucl.ac.be/~pvr/papoc-2015-lasp-abstract.pdf
- https://webperso.info.ucl.ac.be/~pvr/ppdp-2025-lasp.pdf
- https://christophermeiklejohn.com/publications/erlang-workshop-2015-preprint.pdf
- https://arxiv.org/html/2402.08068v1 (Lewis-Pye & Shapiro, *The Blocklace: A Universal ... CRDT*)
- https://github.com/yjs/yjs/
- https://github.com/yjs/yjs/blob/main/INTERNALS.md
- https://github.com/automerge/automerge/
- https://automerge.org/docs/concepts/
- https://automerge.org/docs/tutorial/concepts
- https://automerge.org/docs/documents/
- https://www.inkandswitch.com/peritext/static/cscw-publication.pdf
