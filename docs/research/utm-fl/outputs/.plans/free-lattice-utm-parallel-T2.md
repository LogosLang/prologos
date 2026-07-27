# Brief T2: Distributed Systems & Parallel Computation Axis

**Output file:** `outputs/.drafts/free-lattice-utm-parallel-research-distributed.md`

## Mission

Find any explicit prior work in **distributed systems and parallel computation** that frames a **lattice-based** or **monotone semilattice** computational model as a **universal substrate analogous to the Universal Turing Machine** — i.e., a "parallel Church-Turing thesis" or "foundational parallel machine".

We are interested in priority claims and the closest weaker framings. The free lattice FL(ℵ₀) itself probably never appears here; what we want to know is whether the *spirit* of the framing exists in distributed-systems literature.

## Sub-areas to cover

### (c) Hellerstein-Conway-Marczak CALM theorem; Bloom/Dedalus

- **CALM theorem**: "Consistency As Logical Monotonicity" — Ameloot-Neven-Van den Bussche proved one direction; Hellerstein-Alvaro et al. extended.
- **Bloom**: declarative distributed-systems language, lattices as state.
- **Dedalus**: Datalog-with-time foundation for Bloom.
- Key papers: Hellerstein "The Declarative Imperative" (2010 SIGMOD); Alvaro et al. "Consistency Analysis in Bloom: a CALM and Collected Approach" (2011 CIDR); Ameloot et al. "Relational Transducers for Declarative Networking" (2013 PODS); Conway et al. "Logic and Lattices for Distributed Programming" (2012 SoCC); Hellerstein-Alvaro "Keeping CALM" (2020 CACM).
- **Specifically look for**: any framing of monotone semilattice computation as a "parallel Church-Turing thesis", a universal substrate, or a foundational parallel machine. Quote any such language verbatim.

### (d) Garg's lattice-linear predicate detection (1992–2020)

- Vijay K. Garg, UT Austin.
- Body of work on **lattice-linear predicate detection**, **lattice agreement**, **predicate detection in distributed systems**, monotone predicates over the lattice of consistent global states.
- Key references: Chase-Garg "Detection of Global Predicates: Techniques and Their Limitations" (1995); Garg "Predicate Detection to Solve Consensus and Set Agreement"; book "Elements of Distributed Computing" (2002); recent "Lattice-Linear Predicate Algorithms" series (~2020).
- Look for: any UTM-analogue framing? Any "universal substrate" claim?

### (e) Kuper's LVars

- Lindsey Kuper, PhD thesis "Lattice-based data structures for deterministic parallel and distributed programming" (2014/2015, Indiana).
- Key papers: Kuper-Newton "LVars: Lattice-based Data Structures for Deterministic Parallelism" (FHPC 2013); Kuper-Turon-Krishnaswami-Newton "Freeze After Writing" (POPL 2014); LVish runtime.
- Look for: foundational/universality framings. The thesis itself might claim something like "lattices give a foundation for deterministic parallelism" — does it go further to UTM-analogue?

## Search strategy

- `alpha_search` for academic papers (semantic, keyword).
- `web_search` for blog posts, talks, slide decks (Hellerstein has many talks and blog posts; Kuper has a Composition.al blog).
- Avoid `alpha_get_paper` and `.pdf` URLs. HTML versions, abstracts, ACM DL pages, dblp, Google Scholar are fine.

## Search queries to try

- "CALM theorem monotonicity consistency"
- "Bloom Dedalus monotone lattice"
- "parallel Church-Turing thesis monotone"
- "lattice based distributed programming universal"
- "Garg lattice-linear predicate detection"
- "Garg predicate detection consistent global states"
- "LVars Kuper deterministic parallelism"
- "Kuper lattice deterministic parallel thesis"
- "monotone computation universal model"

## Deliverable: `outputs/.drafts/free-lattice-utm-parallel-research-distributed.md`

Structure:

```markdown
# T2 Research: Distributed Systems & Parallel Computation Axis

## (c) CALM / Bloom / Dedalus
### Direct findings (with verbatim quotes if possible)
### Closest framings to UTM-analogue or "parallel CT thesis"
### Verdict: explicit / adjacent / absent

## (d) Garg lattice-linear predicate detection
### Direct findings
### Verdict

## (e) Kuper LVars
### Direct findings
### Verdict

## Open questions / blocked checks

## Sources
```

Quote precisely. Distinguish observation from inference. Every URL you used should be listed.
