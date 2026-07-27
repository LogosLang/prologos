# Brief T3: Foundational Parallel Models & Categorical Axis

**Output file:** `outputs/.drafts/free-lattice-utm-parallel-research-parallel-categorical.md`

## Mission

Find any explicit prior work in **foundational parallel-computation models** and in **categorical foundations** that proposes (or critiques the absence of) a **universal parallel computational substrate analogous to the Universal Turing Machine**.

The user's hypothesis is that the parallel-computation community has *not* converged on a UTM analogue (BSP, PRAM, dataflow, Petri nets, actors all coexist as engineering models without a foundational consensus). We want to verify that gap, and find any explicit attempts to fill it.

## Sub-areas to cover

### (f) BSP / PRAM / dataflow / Petri nets / actors as universal parallel substrate

- **BSP** (Bulk Synchronous Parallel, Valiant 1990): Valiant's paper "A Bridging Model for Parallel Computation" (CACM 1990) explicitly framed BSP as a *bridging* model. Look for: does Valiant or follow-ups call it a "universal parallel machine" or UTM analogue? Or always "engineering bridge"?
- **PRAM**: Fortune-Wyllie 1978; Karp-Ramachandran. Theoretical model. Any universality claims?
- **Dataflow**: Jack Dennis (MIT) static dataflow; Arvind dynamic dataflow; Kahn process networks (Kahn 1974 "The semantics of a simple language for parallel programming"). Kahn networks have a beautiful fixed-point semantics — anyone framing them as a universal parallel substrate?
- **Petri nets**: Carl Adam Petri 1962. Various universality results exist (Turing-complete extensions). Look for: is the *plain* Petri net ever framed as a UTM analogue, or only the Turing-complete variants?
- **Actors**: Hewitt 1973, Agha. Hewitt has explicit "actor model as foundation of computation" claims — track these.
- Also check: **Pi-calculus** (Milner), **CSP** (Hoare), **Join calculus**, **CCS**.
- Question to keep central: does anyone claim *X is to parallel computation as the UTM is to sequential computation*? Quote the exact words.

### (g) Categorical foundations — Spivak's Poly, polynomial functors

- **David Spivak**: book "Polynomial Functors: A Mathematical Theory of Interaction" (with Niu, ~2023, draft on arXiv), Topos Institute.
- **Polynomial functors** as a setting for dynamics, interaction, dependent lenses, mode-dependent interfaces.
- Look for: any UTM-analogue claim for **Poly**, polynomial functors, or related categorical-systems frameworks (operads of wiring diagrams, hyperdoctrines, etc.).
- Adjacent: **CRDT** lattices in category-theoretic terms; **applicative/monoidal/profunctor** foundations of parallel computation; **Awodey-Rezk**, **Riehl-Verity** ∞-categorical models; **Joyal species**.
- **Game semantics / linear logic**: Girard's geometry of interaction, Abramsky-Jagadeesan; sometimes framed as foundational. Any universality claims?

## Search strategy

- `alpha_search` for academic papers.
- `web_search` for Topos Institute blog, n-Café, Hewitt's writings, Valiant's later commentary.
- Spivak has extensive lectures, slides, and the Poly book draft (HTML or arXiv abstract); pull whatever HTML/abstract exists.
- Avoid `alpha_get_paper` and `.pdf` URLs.

## Search queries to try

- "Valiant bridging model parallel computation universal"
- "PRAM universal parallel machine"
- "Kahn process networks universal computation"
- "Hewitt actor model foundation computation universal"
- "Petri net universal parallel"
- "universal parallel substrate"
- "foundational parallel machine"
- "parallel Church-Turing thesis"
- "Spivak polynomial functors interaction universal"
- "poly category interaction substrate"
- "polynomial functor universal Turing"
- "geometry of interaction universal parallel"

## Deliverable: `outputs/.drafts/free-lattice-utm-parallel-research-parallel-categorical.md`

Structure:

```markdown
# T3 Research: Foundational Parallel Models & Categorical Axis

## (f) BSP / PRAM / dataflow / Petri / actors
### Per-model findings (BSP, PRAM, Kahn, Petri, actors, pi/CSP)
### Closest UTM-analogue framings, with quotes
### Verdict per model

## (g) Categorical foundations
### Spivak Poly findings
### Other categorical-systems framings
### Verdict

## Open questions / blocked checks

## Sources
```

Quote precisely. Distinguish observation from inference. Every URL listed.
