# Brief T11: Wolfram + Propagator-networks + CRDT-engineering

**Output file:** `outputs/.drafts/free-lattice-utm-parallel-research-wolfram-propagator-crdt.md`

## Mission

Round-2 follow-up to the FL(ℵ₀)-as-UTM-analogue priority-claim audit. The round-1 audit flagged three literatures as **not searched** that could plausibly contain explicit "universal computational substrate for parallel computation" framings outside the lattice-theory and parallel-systems traditions. Search them now.

Goal per literature: find any explicit framing of *X* as a UTM analogue, parallel Church-Turing thesis, or universal/foundational substrate for parallel/concurrent/distributed computation, and verbatim-quote whatever language gets closest.

## Sub-areas

### (h) Wolfram

- Wolfram, *A New Kind of Science* (2002), especially chapters on cellular automata, Turing machines, and the **Principle of Computational Equivalence**.
- Wolfram Physics Project (2020-): **multiway systems**, **hypergraph rewriting**, **causal graphs**.
- Look for: explicit "X is to parallel computation as UTM is to sequential" claims. Also: any framing of multiway/hypergraph rewriting as the foundational parallel substrate. Wolfram is famously aggressive about computational-equivalence claims, so quotes here matter.
- Sources to try: wolframphysics.org, wolfram.com/nks (the online edition), Wolfram's blog posts, his *Computation: From Mathematics to Artificial Intelligence* slide decks.

### (i) Propagator networks (Sussman / Radul)

- **Sussman & Radul, "The Art of the Propagator"** (MIT-CSAIL-TR-2009-002, 2009).
- Radul PhD dissertation, *Propagation Networks: A Flexible and Expressive Substrate for Computation* (MIT, 2009).
- Sussman SICP-related propagator talks.
- Look for: explicit framings of propagator networks as a foundational/universal parallel substrate. The phrase "substrate for computation" appears in Radul's title — quote and contextualise.
- Adjacent: McAllester / TMS / ATMS literature (de Kleer, Forbus); constraint propagation; Steele's *RABBIT* / *AMORD* work.

### (j) CRDT-engineering literature

- Shapiro, Preguiça, Baquero, Zawirski, *"Conflict-free Replicated Data Types"* (SSS 2011, INRIA TR 7506); state-based vs op-based CRDTs.
- **Lasp** (Meiklejohn & Van Roy, PPDP 2015) — "Lattice processing".
- Riak ecosystem; Automerge; Yjs; Loro.
- *Crystal* / *Antidote* / *Cassandra* with CRDTs.
- Look for: any "lattices/CRDTs as foundational parallel substrate" or "universal coordination-free substrate" framing. CALM is in scope here too — already covered in round 1 but deeper engineering-side citations may exist.

## Search strategy

- `web_search` for blog posts, talks, slide decks (Wolfram has many; CRDT engineering has Riak/Microsoft talks).
- `alpha_search` for papers (semantic + keyword).
- `fetch_content` on HTML pages of NKS / wolframphysics.org / decomposition.al / dl.acm.org.
- **PDF parsing is ENABLED for round 2** — use `document_parse` after `curl` if you need full text of a specific PDF. Prefer targeted Q&A via `alpha_ask_paper` for arXiv papers.

## Search queries to try

Wolfram:
- "Wolfram principle of computational equivalence universal"
- "Wolfram multiway system parallel computation universal substrate"
- "hypergraph rewriting Turing machine analogue"
- "Wolfram Physics Project foundational"

Propagator networks:
- "Sussman Radul propagator network substrate computation"
- "Radul propagation networks substrate"
- "propagator network universal Turing"
- "TMS ATMS truth maintenance universal computation"
- "constraint propagation foundational parallel"

CRDT:
- "Shapiro CRDT semilattice universal foundation"
- "Lasp lattice processing universal"
- "CRDT distributed computation universal substrate"
- "monotone CRDT foundational parallel"

## Deliverable

`outputs/.drafts/free-lattice-utm-parallel-research-wolfram-propagator-crdt.md`

Per-axis structure:
```markdown
## (h) Wolfram
### Direct findings (verbatim quotes)
### Verdict: explicit / adjacent / absent

## (i) Propagator networks
### Direct findings
### Verdict

## (j) CRDT-engineering
### Direct findings
### Verdict

## Open questions / blocked checks
## Sources (all URLs)
```

Quote precisely. Distinguish observation from inference. Every URL listed.
