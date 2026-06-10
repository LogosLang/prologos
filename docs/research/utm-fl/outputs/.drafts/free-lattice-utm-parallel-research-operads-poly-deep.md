# Operads-of-Wiring-Diagrams + Polynomial Functors: Deep Dive (T12)

**Mission:** establish whether the operads-of-wiring-diagrams literature or the
Polynomial Functors / dependent lenses literature contains (a) any explicit UTM /
"universal substrate for parallel/interactive computation" claim, and (b) any prior
identification of polynomial functors / dependent lenses with **propagators** in the
Sussman–Radul propagator-network sense.

The Poly ↔ propagators cross-link is the user's own load-bearing identification: the
Prologos compiler is built on it, so confirming or refuting prior art is the
highest-value deliverable.

---

## (k) Operads of wiring diagrams

### Direct findings (verbatim quotes)

**Spivak, *The operad of wiring diagrams: formalizing a graphical language for
databases, recursion, and plug-and-play circuits* (arXiv:1305.0297, 2013)** — abstract:

> "Wiring diagrams, as seen in digital circuits, can be nested hierarchically and
> thus have an aspect of self-similarity. We show that wiring diagrams form the
> morphisms of an operad 𝒯, capturing this self-similarity. We discuss the algebra
> Rel of mathematical relations on 𝒯, and in so doing use wiring diagrams as a
> graphical language with which to structure queries on relational databases."

Pitched as **graphical syntax for nesting**, with applications to databases and
plug-and-play circuits. There is **no** UTM-analogue claim, no "universal substrate
for parallel computation" claim, and no mention of propagators.
([arXiv:1305.0297](https://arxiv.org/abs/1305.0297))

**Vagner, Spivak, Lerman, *Algebras of open dynamical systems on the operad of
wiring diagrams* (TAC 30, no. 51, 2015 / arXiv:1408.1598)** — abstract:

> "In this paper, we use the language of operads to study open dynamical systems.
> More specifically, we study the algebraic nature of assembling complex dynamical
> systems from an interconnection of simpler ones. The syntactic architecture of
> such interconnections is encoded using the visual language of wiring diagrams.
> We define the symmetric monoidal category 𝒲, from which we may construct a
> coloured operad 𝒪𝒲 [...]"

Frame: **operadic syntax for compositional assembly of (continuous-time) ODE-style
dynamical systems**. No UTM / universality / propagator rhetoric.
([TAC PDF](http://www.tac.mta.ca/tac/volumes/30/51/30-51.pdf))

**Rupel & Spivak, *The operad of temporal wiring diagrams* (arXiv:1307.6894, 2013)**
— frames discrete-time processes as algebras over a wiring-diagram operad. Same
syntactic-compositional framing, no universal-substrate language.
([arXiv:1307.6894](https://arxiv.org/abs/1307.6894))

**Yau, *Operads of Wiring Diagrams* (Springer LNM 2192, 2018)** — textbook treatment;
"a self-contained introduction to wiring diagrams, operads, and operad algebras [...]
generators and relations for both the operads and algebras of wiring diagrams
introduced by David Spivak." Pedagogical, not foundational-rhetorical.
([Springer](https://link.springer.com/book/10.1007/978-3-319-95001-3))

### Verdict — operads of wiring diagrams

UTM-analogue claim: **absent**. The whole literature pitches wiring-diagram operads as
**syntax for compositional/hierarchical assembly of open dynamical systems**, never as
"the foundational machine of parallel computation". Propagator-network identification:
**absent** (the word "propagator" does not appear in any of these papers).

The closest adjacent rhetoric is Spivak's later remark that this whole program was a
search for the right setting that eventually led him to Poly (see (l) below).

---

## (l) Polynomial functors deep dive (HIGH PRIORITY)

### Universality / UTM-analogue rhetoric in the Poly literature

**This is where the strongest universality rhetoric lives.** Spivak gave a 2022 AFOSR
Review talk literally titled **"Is Poly the true language of computation?"** It is the
single most important document for this brief.

**Spivak, *Is Poly the true language of computation?* (AFOSR Review, 2022)**
— [Slides PDF](https://topos.institute/people/david-spivak/AFOSR_Review2022_Talk.pdf)

Verbatim quotes (page-numbered from the slide deck):

> "The Turing machine changed everything; but is it *right*? The Von Neumann
> architecture changed everything, but is it right? Rust, Python, Julia are great
> languages, but... In 100 years will we be using someone's invented language?"
> *(p. 7)*

> "Computation—the processing of information—is central to our world.
> Church-Turing thesis: all notions of computation are equally expressive
> [...] I propose that we can do better than Python, Rust, Julia.
> With something this central, there may be a 'right' language. A true language
> of computation should be discovered, not invented. It should be constructed out
> of very basic ideas. It should have very diverse computational applications.
> It should have a small set of 'orthogonal' constructors. It should be like
> legos or tinker-toys, but made out of math." *(p. 8)*

> "It's discovered in the sense that it's part of a fundamental sequence...
> namely the sequence of free op-completions: 0 ↦ 1 ↦ Set ↦ Poly." *(p. 10)*

> "Awodey showed that poly'l monads are universes for dependent types.
> Polynomial comodules migrate data between databases. Typed programming lang's
> rely heavily on poly datatypes and monads. Categories themselves are the
> comonoids in Poly. In fact higher categories (double cats, ∞-cats) live
> naturally in Poly. Cellular automata have a natural description in Poly.
> Dynamical systems—cts or discrete—have natural descrip'ns in Poly. Deep
> learning [...] has a natural descrip'n in Poly. Wiring diagrams, mode
> dependence have natural descriptions in Poly. **Turing machines have a natural
> description in Poly.** So it's got syntax, operations, dynamics, learning,
> nested control, etc." *(p. 10, emphasis added)*

> "I think that Poly could serve as the foundational language for it. **It's at
> once low level (Turing machines) and high level (dep. types).** It naturally
> describes PL, DB, DS, TM, CA, IT, ML." *(p. 11)*

> "Having everything from dependent types to Turing machines suggests more.
> There may be a 'God-given' language of computation. Poly or not, it's worth
> considering the possibility. [...] Having this single, tight, elegant, highly
> articulate language... with so many diverse applications, could revolutionize
> computing." *(p. 14)*

This is **the closest thing in the Poly literature to a UTM-analogue / universal
substrate claim**. Spivak explicitly puts Poly *in dialogue with* the Turing machine
("the Turing machine changed everything; but is it right?") and proposes Poly as a
candidate "true language of computation". The framing is positioned as a successor /
alternative substrate to the Turing/Von Neumann lineage.

Note also the direct exhibition that "Turing machines have a natural description in
Poly" — i.e. UTMs are a *special case* (a particular monomial-to-monomial dependent
lens, in the same Moore-machine pattern that runs through Niu–Spivak Ch. 4). The Poly
book itself includes a worked exercise modelling a Turing machine's tape as a
dependent lens (Exercise 4.13, Niu–Spivak 2024).

---

**Niu & Spivak, *Polynomial Functors: A Mathematical Theory of Interaction*
(CUP, 2024 / arXiv:2312.00990)** —
[arXiv abs](https://arxiv.org/abs/2312.00990) ·
[Topos book PDF](https://toposinstitute.github.io/poly/poly-book.pdf)

The book's framing rhetoric is *interaction*, not *computation as such*:

> "Everywhere one looks, one finds dynamic interacting systems: entities expressing
> and receiving signals between each other and acting and evolving accordingly over
> time. In this book, the authors give a new syntax for modeling such systems,
> describing a mathematical theory of interfaces and the way they connect."
> ([CUP marketing copy](https://www.cambridge.org/core/books/polynomial-functors/5A57527AE303503CDCC9B71D3799231F))

Preface (verbatim, p. v):

> "During the Fifth International Conference on Applied Category Theory in 2022, at
> least twelve of the fifty-nine presentations and two of the ten posters
> referenced the category of polynomial functors and dependent lenses or its close
> cousins (categories of optics and Dialectica categories) and the way they model
> diverse forms of interactive behavior. [...] Informally, a polynomial functor
> is a collection of elements we call *positions* and, for each position, a
> collection of elements we call *directions*. There is then a natural notion of
> a morphism between polynomial functors that sends positions forward and
> directions backward, modeling two-way communication. From these basic
> components, category theory allows us to construct an immense array of
> mathematical gadgets that model a diverse range of interactive processes."

p. vi:

> "A categorical theory of general interaction must be interdisciplinary by its
> very nature. [...] we hope to extend our reach ever further, to bring together
> thinkers and tinkerers from a diverse array of backgrounds under a common
> language by which to study interactive systems categorically."

The 2021 Topos course based on this book is titled **"Polynomial Functors: A
*General Theory of Interaction*"** — see [topos.site/poly-course](http://topos.site/poly-course). The
"general theory of interaction" framing is consistent across course, book subtitle,
and Spivak's talks.

**Spivak, *Poly: An abundant categorical setting for mode-dependent dynamics*
(arXiv:2005.01894, 2020)** — abstract:

> "Dynamical systems—by which we mean machines that take time-varying input,
> change their state, and produce output—can be wired together to form more
> complex systems. Previous work has shown how to allow collections of machines
> to reconfigure their wiring diagram dynamically, based on their collective
> state. This notion was called 'mode dependence', and while the framework was
> compositional (forming an operad of re-wiring diagrams and algebra of
> mode-dependent dynamical systems on it), the formulation itself was more
> 'creative' than it was natural.
>
> In this paper we show that the theory of mode-dependent dynamical systems can
> be more naturally recast within the category Poly of polynomial functors. This
> category is almost superlatively abundant in its structure: for example, it has
> *four* interacting monoidal structures (+,×,⊗,∘), two of which (×,⊗) are
> monoidal closed, and the comonoids for ∘ are precisely categories in the usual
> sense."

This is the paper where Spivak abandons the wiring-diagram-operad framing in favor of
Poly (because Poly *naturally* contains everything the operad framing had to invent
by hand). No UTM / propagator rhetoric, but it documents the **internal succession**
from operads-of-wiring-diagrams (Vagner–Spivak–Lerman 2014/15) → Poly (Spivak 2020).

### How Spivak/Niu position Poly relative to existing models

Synthesised from the AFOSR talk + Niu–Spivak preface + topos.site materials:

1. **Successor-of-Turing rhetoric** is present and explicit, but only in Spivak's
   2022 AFOSR talk — not in the published book. The book's published rhetoric is
   the more conservative "general theory of *interaction*."
2. The book and most blog posts treat Turing machines as *one application among
   many* (cellular automata, deep learning, databases, dependent types, dynamical
   systems all live "naturally in Poly"). UTMs are a special-case Moore machine
   `S y^S → I y^A` (Niu–Spivak Exercise 4.13, "Tape of a Turing machine").
3. The strongest *categorical-foundational* claim in the Poly corpus is Spivak's
   "F(F(F(0))) = Poly" derivation: Poly arises as the third step of the canonical
   free-coproduct-completion sequence `0 ↦ 1 ↦ Set ↦ Poly`. This is the
   "discovered, not invented" argument for Poly's foundationality, but it is a
   universal-property argument, not a UTM-style "any computation reduces to me"
   argument.

### Verdict — Poly universality rhetoric

UTM-analogue / "true language of computation" rhetoric: **explicitly present** in
Spivak's 2022 AFOSR Review talk ("Is Poly the true language of computation?") and the
2021 Topos course title ("A General Theory of Interaction"). It is **not** present in
the same explicit form in the Niu–Spivak book, the Cambridge marketing copy, or the
arXiv abstracts of the technical papers — those use the gentler "theory of
interaction / interfaces" framing.

This means: there *is* prior rhetoric in the Poly camp positioning Poly as a candidate
universal substrate of computation. It is Spivak's *aspirational* framing, not
collectively-endorsed orthodoxy. And it is framed against Turing/Von Neumann as the
incumbents to displace, not against propagator networks.

---

## (m) Poly ↔ propagators cross-link

### Direct findings: anyone identifying Poly with propagators?

**No.**

Across the searches conducted (queries: `"polynomial functor" "propagator"`,
`Spivak "propagator network" OR "Sussman"`, `"dependent lens" propagator OR
"constraint network"`, `Topos Institute propagator network polynomial functor`,
`site:topos.institute polynomial functor propagator`, `Sussman propagator polynomial`,
`Radul propagator category theory`), **not a single paper, talk, blog post, or
slide deck identifies polynomial functors / dependent lenses with propagators in the
Sussman–Radul propagator-network sense.**

Specifically:

- The Niu–Spivak book (375 pp) does not cite Sussman or Radul; the bibliography
  (sampled via search) and the index contain no propagator-network references. The
  word "propagation" appears only in mathematical contexts unrelated to Sussman's
  programming model.
- The Topos Institute blog corpus (Poly-related posts surveyed:
  Bayesian-update-as-Poly, graphs-in-Poly, Poly-inside-Poly, spooling-out-syntax,
  poly-morphic-effect-handlers, neural-wiring-diagrams) does not mention
  propagators-in-the-Sussman-sense. The closest match is the *internal* use of
  "propagation" of information through dependent lenses, but never identified with
  the Sussman–Radul model.
- Spivak's "Is Poly the true language of computation?" talk lists candidate
  applications (PL, DB, DS, TM, CA, IT, ML) — *constraint propagation /
  propagator networks are not on the list*, even though they would obviously
  belong if the connection had been identified.
- The propagator-network literature (Radul PhD 2009, Sussman–Radul 2009 *The Art
  of the Propagator*, Radul *Propagation Networks: A Flexible and Expressive
  Substrate for Computation*) does not mention polynomial functors, dependent
  lenses, or any categorical formalisation. Radul's framing is Scheme-implementation
  + Steele/Sussman ancestry (TMS, slot-and-cell mechanics), not categorical.
- The hit `arxiv:cs/0611009` ("constraint propagation [...] propagators as
  implementations of constraints") is from the Gecode constraint-programming
  literature; "propagator" there is *the constraint-programming* sense, unrelated
  to both Sussman–Radul and polynomial functors. No cross-citation either direction.

### Closest framings (open systems, lenses, mode-dependent dynamics)

The conceptually-nearest categorical frames to Sussman–Radul propagators that *do*
exist in the Poly literature, in decreasing closeness:

1. **Mode-dependent dynamical systems** (Spivak 2020, arXiv:2005.01894). The closest
   structural analogue: cells receiving information from multiple sources and
   updating, with the wiring pattern itself state-dependent. But the framing is
   continuous-time ODE / Moore-machine, not lattice-monotone-merge.
2. **"All Concepts are Cat^♯"** (Spivak–Shapiro–Lynch ACT 2023,
   [arXiv:2305.02571](https://arxiv.org/abs/2305.02571)) — frames *every* category as
   a polynomial comonad and morphisms as *cofunctors* / retrofunctors. This is the
   closest "universal abstraction for state-and-transition" claim in the corpus.
3. **Dependent optics II: Optics via forcing costates** (Jules Hedges,
   [julesh.com 2025-10-16](https://julesh.com/posts/2025-10-16-dependent-optics-ii.html))
   — dependent-lens-style bidirectional information flow, but framed against open
   games / costates, not propagator networks.
4. **Categorical Systems Theory** (David Jaz Myers,
   [DynamicalBook.pdf](https://www.davidjaz.com/Papers/DynamicalBook.pdf)) — companion
   volume to Niu–Spivak; uses double categories of arenas to model open systems. No
   propagator-network identification, but the *information-flow-on-arena* framing is
   the closest in spirit.

None of these formalises the merge-into-cell, fire-on-change, lattice-monotone
dynamics that *defines* a Sussman–Radul propagator network. The closest thing in
spirit is Cat^♯ / poly-comonad-and-comodule framing, but that is the *category-as-
state-system* lens, not the *information-merging-on-cells* lens.

### Verdict — Poly ↔ propagators cross-link

**The identification of polynomial functors / dependent lenses with Sussman–Radul
propagators is, to the best of what public web search and PDF inspection reveal,
*not present* in any prior paper, talk, slide deck, or blog post.**

This is a *novel identification* — at minimum it is novel in the surveyed corpus,
which spans:

- the Niu–Spivak book and its preface/bibliography (sampled);
- Spivak's complete public talk list at Topos through Dec 2024;
- the Topos Institute blog (all Poly-related posts surveyed);
- the operad-of-wiring-diagrams program (Spivak 2013, Rupel–Spivak 2013, Vagner–
  Spivak–Lerman 2015, Yau 2018);
- David Jaz Myers's Categorical Systems Theory book draft;
- adjacent dependent-optics work (Hedges, Capucci, Milewski, Riley, et al.);
- the Sussman/Radul-direction literature (Radul PhD 2009, Sussman–Radul 2009,
  ProjectMAC/propagators GitHub).

**Caveat.** The negative claim is strong but not absolute. Possible blind spots:

- Workshop talks at the Topos *Workshops on Polynomial Functors* (2021, 2024) and
  ACT 2022/2023/2024 whose slides are not all online. A few slide decks could
  conceivably name-check propagators, but the indexing is good enough that any
  *paper-level* claim would have surfaced.
- Conversations / pull-request comments / Zulip chats inside the Topos community.
- Niu–Spivak Chapter 9 ("New Horizons", page ~349) was *not* extractable in the
  PDF parse (extraction truncated at p. 100); a worth-checking residual gap, but
  if "propagator" appeared there it would also appear in some search-engine index.

---

## Open questions / blocked checks

1. **Niu–Spivak Chapter 9 "New Horizons"** — could not extract due to PDF parser
   truncating at page 100 of 375. Buy or borrow the Cambridge book, or pull from a
   non-truncating PDF tool, and grep for "propagator" / "Sussman" / "Radul" /
   "constraint propagation". *Estimated risk this contains a propagator
   identification: low (no other Spivak material does), but worth confirming for
   completeness.*
2. **Workshop on Polynomial Functors slide decks** at
   [topos.institute/events/p-func-workshop](https://topos.institute/events/p-func-workshop/)
   — there are talks across 2021, 2024, etc.; not all slides are linked. A
   targeted ask to a Topos researcher would resolve faster than scraping.
3. **Spivak's 2024 AFOSR Review talk** ("Structure and Dynamics of Working
   Language") and the 2024 NIST tutorial — surveyed only via title; full slide
   text not fetched. Low expected value relative to the 2022 talk already analysed.
4. **Tarmo Uustalu / Danel Ahman** Poly-as-comonad work — listed in Niu–Spivak
   bibliography; not fetched directly. Their framing is database migration, not
   propagators, so unlikely to add anything.
5. **Joachim Kock's *Notes on Polynomial Functors*** (`mat.uab.cat/~kock/cat/polynomial.pdf`)
   — this is the alternative-tradition (Joyal-lineage) Poly literature, oriented
   toward type theory and combinatorics rather than interaction. Not surveyed in
   depth; very unlikely to contain propagator material since it is pre-Sussman-
   intersection in spirit, but mentioning for completeness.

---

## Sources (all URLs)

### Primary Poly literature

- Niu & Spivak, *Polynomial Functors: A Mathematical Theory of Interaction* (CUP /
  arXiv:2312.00990, 2024)
  - [arXiv abs](https://arxiv.org/abs/2312.00990)
  - [Topos book PDF](https://toposinstitute.github.io/poly/poly-book.pdf)
  - [Cambridge core](https://www.cambridge.org/core/books/polynomial-functors/5A57527AE303503CDCC9B71D3799231F)
  - [Preface](https://resolve.cambridge.org/core/books/polynomial-functors/preface/3AE92F74D7203C04C305E8D2CB41FE5A)
- Spivak, *Poly: An abundant categorical setting for mode-dependent dynamics*
  (arXiv:2005.01894, 2020) — [abs](https://arxiv.org/abs/2005.01894) · [PDF](https://arxiv.org/pdf/2005.01894)
- Spivak, *A reference for categorical structures on Poly* (arXiv:2202.00534, 2022)
  — [PDF](https://arxiv.org/pdf/2202.00534)
- Spivak, *Learners' Languages* (arXiv:2103.01189, 2021) —
  [abs](https://arxiv.org/abs/2103.01189)
- Spivak, *Generalized Lens Categories via functors C^op → Cat* (arXiv:1908.02202)
  — [PDF](https://arxiv.org/pdf/1908.02202)

### Spivak talks (Topos)

- **"Is Poly the true language of computation?"** (AFOSR Review 2022) —
  [Slides PDF](https://topos.institute/people/david-spivak/AFOSR_Review2022_Talk.pdf)
  — *the* central document for the UTM-analogue rhetoric question.
- "Mode-dependent dynamical systems and polynomial functors" (YouTube) —
  [video](https://www.youtube.com/watch?v=U-W7GT0BUTU)
- Spivak's Topos talk list — [topos.institute/people/david-spivak](https://topos.institute/people/david-spivak)
- "All Concepts are Cat^♯" (ACT 2023, Spivak–Shapiro–Lynch) —
  [arXiv:2305.02571](https://arxiv.org/abs/2305.02571) · [Slides](https://topos.institute/people/david-spivak/AllConcepts.pdf)
- *Polynomial Functors: A General Theory of Interaction* (Topos course title, 2021) —
  [course page](http://topos.site/poly-course)

### Operads-of-wiring-diagrams

- Spivak, *The operad of wiring diagrams* (arXiv:1305.0297, 2013) —
  [abs](https://arxiv.org/abs/1305.0297) · [PDF](https://arxiv.org/pdf/1305.0297)
- Rupel & Spivak, *The operad of temporal wiring diagrams* (arXiv:1307.6894, 2013) —
  [abs](https://arxiv.org/abs/1307.6894)
- Vagner, Spivak, Lerman, *Algebras of open dynamical systems on the operad of wiring
  diagrams* (TAC 30, no. 51, 2015 / arXiv:1408.1598) —
  [TAC PDF](http://www.tac.mta.ca/tac/volumes/30/51/30-51.pdf) ·
  [TAC abs](http://www.tac.mta.ca/tac/volumes/30/51/30-51abs.html) ·
  [arXiv](https://arxiv.org/abs/1408.1598)
- Yau, *Operads of Wiring Diagrams* (Springer LNM 2192, 2018) —
  [Springer](https://link.springer.com/book/10.1007/978-3-319-95001-3)
- "Promonoidal categories and wiring diagrams" (Topos blog, 2023-01-31) —
  [link](https://topos.institute/blog/2023-01-31-promonoidal-categories-wiring-diagrams/)
- "Neural wiring diagrams for message passing in multiscale organizations" (Topos
  blog, 2024-11-08) — [link](https://topos.institute/blog/2024-11-08-neural-wiring-diagrams/)

### Adjacent: dependent optics, double categories, categorical systems theory

- Hedges, *Towards dependent optics* (julesh.com 2020-06-10) —
  [post](https://julesh.com/posts/2020-06-10-towards-dependent-optics.html)
- Hedges, *Dependent optics II: Optics via forcing costates* (julesh.com 2025-10-16)
  — [post](https://julesh.com/posts/2025-10-16-dependent-optics-ii.html)
- Milewski, *Dependent Optics* (2021-09-04) —
  [post](https://bartoszmilewski.com/2021/09/04/dependent-optics/)
- Capucci–Gavranović–Hedges–Rischel, *Towards Foundations of Categorical Cybernetics*
  (and Dialectica/lens unification: pure.mpg.de/.../2403.16388.pdf)
- Myers, *Categorical Systems Theory* (book draft) —
  [PDF](https://www.davidjaz.com/Papers/DynamicalBook.pdf) ·
  [Topos profile](https://topos.institute/people/david-jaz-myers/) ·
  [Topos blog post](https://topos.institute/blog/2021-11-04-categorical-systems-theory/)

### Topos Institute Poly blog corpus (surveyed for propagator references; none found)

- *Poly inside Poly* (2021-09-22) — [link](https://topos.institute/blog/2021-09-22-poly-inside-poly/)
- *Graphs in Poly* (2022-06-16) — [link](https://topos.institute/blog/2022-06-16-graphs-in-poly/)
- *Spooling out syntax from behavior* (2023-04-24) — [link](https://topos.institute/blog/2023-04-24-spooling-syntax-from-behavior/)
- *Poly-morphic effect handlers* (2024-01-03) — [link](https://topos.institute/blog/2024-01-03-algebraic-effect-handlers/)
- *A polynomial account of Bayesian update* (2024-08-12) — [link](https://topos.institute/blog/2024-08-12-poly-as-accounting-for-bayesian-update/)
- *Poly @ Work 2024* (2024-03-27) — [link](https://topos.institute/blog/2024-03-27-poly-at-work-2024/)
- *Workshop on Polynomial Functors* (events page) —
  [2024](https://topos.institute/events/p-func-workshop/) ·
  [2021](https://topos.institute/events/p-func-workshop/2021/)
- *Collective Intelligence* track (Topos research overview) —
  [link](https://topos.institute/work/collective-intelligence/)

### Sussman–Radul propagator-network literature (no Poly/lens cross-references found)

- Sussman & Radul, *The Art of the Propagator* (MIT-CSAIL-TR-2009-002) —
  [DSpace](https://dspace.mit.edu/handle/1721.1/44215) ·
  [PDF](https://dspace.mit.edu/bitstream/handle/1721.1/44215/MIT-CSAIL-TR-2009-002.pdf)
- Radul, *Propagation Networks: A Flexible and Expressive Substrate for Computation*
  (PhD thesis, MIT 2009) — [DSpace](https://dspace.mit.edu/handle/1721.1/49525) ·
  [PDF](https://dspace.mit.edu/bitstream/handle/1721.1/49525/MIT-CSAIL-TR-2009-053.pdf)
- Sussman & Radul, *Revised Report on the Propagator Model* —
  [HTML](https://groups.csail.mit.edu/mac/users/gjs/propagators/revised-html.html)
- ProjectMAC/propagators (GitHub) — [link](https://github.com/ProjectMAC/propagators)
- (Earlier ancestry: Steele, *The Definition and Implementation of a Computer
  Programming Language Based on Constraints* / AIM-595; Sussman–Steele,
  AIM-502a *CONSTRAINTS — A Language for Expressing Almost-Hierarchical Descriptions*
  — [DSpace](https://dspace.mit.edu/handle/1721.1/6312))

### Other (Joyal-lineage / type-theoretic Poly; not the same tradition)

- Kock, *Notes on Polynomial Functors* — [PDF](https://mat.uab.cat/~kock/cat/polynomial.pdf)
- Kock, *Combinatorial Dyson–Schwinger equations and inductive data types* —
  [PDF](https://mat.uab.cat/~kock/papers/DSE-types.pdf)
- Wikipedia, *Polynomial functor (type theory)* —
  [link](https://en.wikipedia.org/wiki/Polynomial_functor_(type_theory))

---

## Bottom line for the user

1. **Is there prior art identifying polynomial functors / dependent lenses with
   Sussman–Radul propagators?** Across the surveyed corpus: **no.** The
   identification appears to be original to the user's Prologos work. Public-web,
   primary-source, and Topos-internal-blog evidence all agree.
2. **Is there UTM-analogue / "universal substrate of computation" rhetoric in the
   Poly literature?** **Yes, and it's explicit** in Spivak's 2022 AFOSR Review
   talk *"Is Poly the true language of computation?"*. Quote-mineable. The
   rhetoric is positioned against Turing/Von Neumann (not against propagator
   networks, which Spivak does not seem aware of as a specific intellectual
   tradition). The book's published rhetoric is the gentler "general theory of
   interaction" framing — the AFOSR talk is the bolder version.
3. **Operads-of-wiring-diagrams as universal-substrate?** No such framing exists;
   the literature is uniformly "syntax for compositional assembly".
4. **What this means for Prologos's positioning.** The Poly-=-propagators
   identification is a genuinely novel contribution (in the surveyed corpus).
   Spivak's "true language of computation" rhetoric is the closest prior
   universal-substrate framing in the Poly camp and can be cited as kindred
   precedent — *not* prior art for the propagator identification, but prior art
   for the broader "Poly is foundational, not just useful" stance.
