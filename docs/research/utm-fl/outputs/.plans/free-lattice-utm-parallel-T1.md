# Brief T1: Lattice Theory & Logic Axis

**Output file:** `outputs/.drafts/free-lattice-utm-parallel-research-lattice-logic.md`

## Mission

Find any explicit prior work that frames the **free lattice on countably many generators FL(ℵ₀)**, with **Whitman's decision procedure**, as a **universal computational substrate** — i.e., as a UTM-analogue for parallel computation. Also find the closest weaker/adjacent framings.

This is a priority-claim search. We need direct citations (title, year, identifier/URL) of:
- Any work using language like: "universal", "Church-Turing", "computational substrate", "foundational parallel machine", "UTM analogue", "free lattice as model of computation", "Whitman as a decision procedure for computation".
- Adjacent work that embeds Turing-machine computation into lattice or rewriting structures.
- Decidability results for fragments of first-order theory of free lattices (FOTFL) that have any computational-completeness flavor.

## Sub-areas to cover

### (a) Endrullis-Shallit-Smith 2017 "Undecidability and Finite Automata"

- Find the paper. Likely DLT 2017 / FCT 2017 / similar.
- Read abstract, intro, conclusion.
- Look for: how do they encode TM into automata/rewriting? Do they make any UTM-analogue claim? Do they touch lattices or free structures?
- Find follow-up work (cite forward) — anyone embedding TM computation into lattice/rewriting structures with universality framing.

### (b) Nation-Paolini work on free lattices

- J.B. Nation has written extensively on free lattices. Key references include Freese-Ježek-Nation "Free Lattices" (AMS 1995, Mathematical Surveys & Monographs 42).
- Look for Nation-Paolini joint work on **elementary properties of free lattices** and **decidability of fragments of the first-order theory of free lattices (FOTFL)**.
- The relevant question: do they ever frame their decidability results in a computational-substrate way? Or just as model-theoretic results?

## Search strategy

- Use `alpha_search` for academic paper search (semantic and keyword modes).
- Use `web_search` for follow-ups and authors' homepages.
- Avoid `alpha_get_paper` and `.pdf` URLs. Stick to abstracts, HTML pages, ResearchGate metadata, dblp, Google Scholar snippets, official journal pages.
- If only PDF exists, cite the PDF URL but mark full-text PDF parsing as **blocked**.

## Search queries to try (vary phrasing)

- "Endrullis Shallit Smith undecidability finite automata"
- "Turing machine embedding lattice rewriting"
- "Nation Paolini free lattice elementary theory"
- "first-order theory of free lattices decidability"
- "free lattice computational completeness"
- "Whitman decision procedure computation"
- "free lattice universal model"
- "FL(ℵ₀) universality"

## Deliverable: `outputs/.drafts/free-lattice-utm-parallel-research-lattice-logic.md`

Structure:

```markdown
# T1 Research: Lattice Theory & Logic Axis

## (a) Endrullis-Shallit-Smith and follow-ups

### Direct findings
- [Paper title, year, arXiv/DOI]: [verbatim or close paraphrase of relevant claim]. URL.
- ...

### Closest framings to UTM-analogue
- ...

### Verdict
- Explicit framing found? YES / NO / ADJACENT / UNCLEAR.
- One-sentence summary.

## (b) Nation-Paolini and FOTFL decidability

### Direct findings
- ...

### Verdict
- ...

## Open questions / blocked checks
- ...

## Sources
- [URL 1]
- [URL 2]
```

Be evidence-first. Quote or paraphrase precisely. If a claim is yours (an inference), label it as inference. List every URL you actually saw.
