# Brief T12: Operads-of-wiring-diagrams + Polynomial Functors deep dive

**Output file:** `outputs/.drafts/free-lattice-utm-parallel-research-operads-poly-deep.md`

## Mission

Round-2 deep dive on **two categorical literatures** flagged as gaps in the round-1 priority-claim audit:

1. **Operads of wiring diagrams** (Spivak's earlier program).
2. **Polynomial functors** (Spivak-Niu Poly book, dependent lenses, Topos Institute work, applied-category-theory uptake).

The user has explicitly identified Polynomial Functors as **"the best categorical identification of propagators on a propagator network, from which we have built our language infrastructure/compiler"** — i.e., the categorical substrate underlying their actual compiler (the Prologos system). So Poly is the **highest-priority** strand here, not just one of several gaps.

Reframe the question for this brief:

> Does the Poly/polynomial-functor literature (or the operads-of-wiring-diagrams literature) contain *any* explicit framing of polynomial functors / dependent lenses / wiring-diagram-operads as a **universal computational substrate for parallel/interactive computation analogous to the UTM**? And is there *any* prior identification of polynomial functors with **propagators on a propagator network**?

## Sub-areas

### (k) Operads of wiring diagrams

Foundational papers:
- **Spivak, *"The Operad of Wiring Diagrams"*** (~2013, arXiv).
- **Vagner, Spivak, Lerman, *"Algebras of Open Dynamical Systems on the Operad of Wiring Diagrams"*** (TAC 2015 or similar).
- Spivak, Schultz, Rupel — wiring diagram algebras.
- Look for: any UTM-analogue / universal-substrate / foundational-parallel-machine claim. The wiring-diagram operad is typically pitched as "syntax for compositional dynamical systems" — quote whatever foundational rhetoric exists.

### (l) Polynomial Functors deep dive (HIGH PRIORITY)

Core literature:
- **Niu & Spivak, *Polynomial Functors: A Mathematical Theory of Interaction*** (CUP/Topos, draft on arXiv:2312.00990 and topos-institute.github.io/poly).
- **Spivak, *"Generalized Lens Categories via Functors C^op → Cat"*** (~2019).
- **Spivak, *"Poly: An abundant categorical setting for mode-dependent dynamics"*** (~2020).
- **Spivak's Topos Institute lectures and blog posts** on Poly.
- David Jaz Myers, *"Categorical Systems Theory"* book draft (related double-categorical framework).

Specific questions to answer:
1. Does any Poly paper explicitly claim Poly is a UTM analogue, "universal substrate for interaction", or "foundational machine of parallel/interactive computation"? Quote verbatim.
2. Does any Poly paper or talk explicitly identify polynomial functors / dependent lenses with **propagators** (as in Sussman-Radul propagator networks)? This is the user's specific technical claim, so we need either to confirm prior art or document its absence.
3. The "mode-dependent dynamics" framing — how does Spivak position it relative to Turing/UTM rhetoric?
4. The dependent-lens / Poly / wiring-diagram cluster — is there a "this is the foundation of compositional computation" claim somewhere?

Adjacent technical strands:
- **Awodey-Garner-Kock-Hyland** polynomial-functors-and-types literature.
- **Joyal species** as related but distinct categorical foundations.
- **Mode-dependent / open systems** literature (Fong-Spivak applied-CT).

### (m) Cross-link: Poly ↔ propagators

- Search explicitly for any paper, talk, or blog post that uses both vocabularies (polynomial functor + propagator, or dependent lens + propagator network).
- Possible terms: "interaction protocol", "open game", "open system", "categorical propagator", "lens-based propagator".

## Search strategy

- `alpha_search` for category-theory papers (semantic + keyword).
- `web_search` for Topos Institute blog (topos.site, topos.institute), David Spivak's homepage, n-Category Café posts, David Jaz Myers's blog/notes.
- `fetch_content` on HTML pages of Topos Institute lectures, arXiv abs pages, Spivak's homepage talks.
- **PDF parsing is ENABLED** — use `document_parse` after `curl` for the Poly book draft if needed; or `alpha_ask_paper` for targeted Q&A on arXiv:2312.00990.

## Search queries to try

Operads of wiring diagrams:
- "Spivak operad wiring diagram universal"
- "wiring diagram operad foundational parallel"
- "Vagner Spivak Lerman algebras open dynamical systems"

Polynomial functors universality:
- "Spivak Niu polynomial functors interaction universal"
- "polynomial functor universal substrate"
- "polynomial functor Turing machine"
- "Poly category universal interactive computation"
- "Spivak Poly mode-dependent dynamics"
- "dependent lens foundation computation"

Poly ↔ propagators:
- "polynomial functor propagator network"
- "categorical propagator dependent lens"
- "Sussman propagator polynomial"
- "Radul propagator category theory"

## Deliverable

`outputs/.drafts/free-lattice-utm-parallel-research-operads-poly-deep.md`

Structure:

```markdown
## (k) Operads of wiring diagrams
### Direct findings (verbatim quotes)
### Verdict: UTM-analogue claim? explicit/adjacent/absent

## (l) Polynomial functors deep dive
### Universality / UTM-analogue rhetoric in Poly literature
### How Spivak/Niu position Poly relative to existing models
### Verdict

## (m) Poly ↔ propagators cross-link
### Direct findings: anyone identifying Poly with propagators?
### Closest framings (open systems, lenses, mode-dependent dynamics)
### Verdict

## Open questions / blocked checks
## Sources (all URLs)
```

The Poly ↔ propagator cross-link is the most important deliverable — confirm or refute prior art. Quote precisely. Distinguish observation from inference. Every URL listed.
