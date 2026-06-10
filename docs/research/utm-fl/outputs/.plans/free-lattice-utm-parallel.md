# Plan: FL(ℵ₀) as a Universal Parallel Computational Substrate

**Slug:** `free-lattice-utm-parallel`
**Date:** 2026-05-08
**Status:** PLANNING — awaiting user approval

## Research Question

Has anyone in the literature **explicitly framed** the free lattice on countably many generators FL(ℵ₀), with Whitman's decision procedure, as a **universal computational substrate for parallel computation analogous to the Universal Turing Machine (UTM)**?

This is a *priority claim search*: we are looking for explicit prior framings of this exact analogy, including weaker/partial framings (e.g., "monotone semilattice computation as a parallel Church-Turing thesis"), so we can assess how novel the framing is and where the closest prior art sits.

## Key Sub-Questions

1. **(a) Endrullis-Shallit-Smith 2017** "Undecidability and Finite Automata" and follow-ups: does anyone embed Turing-machine computation into lattice/rewriting structures with a UTM-like universality framing?
2. **(b) Nation-Paolini** work on elementary properties of free lattices and decidability of FOTFL fragments — any computational-completeness or universal-substrate framing?
3. **(c) Hellerstein-Conway-Marczak CALM theorem; Bloom/Dedalus** — is monotone semilattice computation ever explicitly framed as a "parallel Church-Turing thesis"?
4. **(d) Garg's lattice-linear predicate detection** (1992–2020) — any UTM-analogue or universal-substrate framing for parallel computation?
5. **(e) Kuper's LVars** — universality / foundational-substrate framings?
6. **(f) BSP / PRAM / dataflow / Petri-net / actor** traditions — any explicit "universal parallel substrate" or "foundational parallel machine" proposals?
7. **(g) Categorical foundations** — Spivak's Poly, polynomial functors, dependent lenses: any UTM-analogue claims?

## Evidence Needed

For each sub-area, we need:
- Direct citations (title, year, identifier/URL) of any work that uses the words/concepts: "universal", "Church-Turing", "computational substrate", "foundational machine", "UTM analogue", "parallel Church-Turing thesis", "free lattice as model of computation", "Whitman as decision procedure for computation".
- Where no explicit framing exists, the closest weaker claim (e.g., "monotone CRDT lattices are coordination-free iff problem is monotone" — CALM) and what is missing for it to be a UTM analogue.
- Confidence level: explicit framing vs. implicit/adjacent framing vs. absent.

## Scale Decision

**Scale: SUBAGENT — 3 parallel researchers.**

Reasoning:
- Topic spans **7 distinct sub-areas** across logic, lattice theory, distributed systems, parallel computation, and category theory.
- Each sub-area has its own community, terminology, and venues.
- This is not a "what is X" explainer — it's a priority/framing-claim search across multiple research traditions.
- Decomposition reduces context pressure and enables parallel evidence gathering.

**Researcher allocation:**
- **R1 — Lattice theory & logic axis:** sub-areas (a) Endrullis-Shallit-Smith and follow-ups, (b) Nation-Paolini and FOTFL decidability.
- **R2 — Distributed systems & parallel computation axis:** sub-areas (c) CALM/Bloom/Dedalus, (d) Garg lattice-linear predicate detection, (e) Kuper LVars.
- **R3 — Foundational parallel models & categorical axis:** sub-area (f) BSP/PRAM/dataflow/Petri-net/actor universal-substrate proposals, (g) Spivak Poly / polynomial functors as universal interaction substrates.

Lead (Feynman) handles synthesis, citation, verification, and final review.

## Task Ledger

| ID | Owner | Task | Status |
|----|-------|------|--------|
| T0 | Lead | Write plan, get user approval | DONE-PENDING-APPROVAL |
| T1 | R1 (researcher) | Sub-areas (a)+(b): Endrullis-Shallit-Smith and Nation-Paolini | DONE (16KB) |
| T2 | R2 (researcher) | Sub-areas (c)+(d)+(e): CALM/Bloom, Garg, LVars | DONE (22KB) |
| T3 | R3 (researcher) | Sub-areas (f)+(g): BSP/PRAM/dataflow/Petri/actor + Spivak Poly | DONE (24KB) |
| T4 | Lead | Synthesize draft → `outputs/.drafts/free-lattice-utm-parallel-draft.md` | IN PROGRESS |
| T5 | Lead (verifier unavailable) | Add citations → `outputs/.drafts/free-lattice-utm-parallel-cited.md` | PENDING |
| T6 | reviewer | Review cited draft → `outputs/.drafts/free-lattice-utm-parallel-verification.md` | PENDING |
| T7 | Lead | Deliver `outputs/free-lattice-utm-parallel.md` + provenance | DONE (round 1) |
| --- | --- | **Round 2: unblock PDFs and unsearched literatures** | --- |
| T8 | Lead (alpha_ask_paper) | Resolve Nation-Paolini III reduction shape (arXiv:2511.13149) | PENDING |
| T9 | Lead (alpha_ask_paper) | Hewitt 1008.1459 UTM-vs-actor argument | PENDING |
| T10 | Lead (alpha_ask_paper) | Kuper PhD dissertation universality framing | PENDING |
| T11 | researcher | Wolfram NKS + propagator-networks (Sussman/Radul) + CRDT-engineering (Lasp/Shapiro) literatures | PENDING |
| T12 | researcher | Operads-of-wiring-diagrams + **Polynomial Functors deep dive** (Poly ↔ propagators on a propagator network; Poly as universal interaction substrate; dependent lenses) | PENDING |
| T13 | Lead | Synthesize addendum, append to `outputs/free-lattice-utm-parallel.md`, update provenance | PENDING |

## Verification Log

- **2026-05-08 [T1 done]** R1 returned 16KB. Found Nation-Paolini I/II/III series (arXiv:2310.03366, 2504.09128, 2511.13149) — full first-order theory of FL(κ≥3) is undecidable (Nov 2025), universal/existential is decidable. Verdict: ABSENT for explicit UTM framing; ADJACENT via Tarski-style demarcation that *implies* TM-encoding into FOTFL but is presented model-theoretically. ESS 2017 abstract: classical undecidability-by-reduction; no lattice/universality framing.
- **2026-05-08 [T2 done]** R2 returned 22KB. CALM/Bloom/Dedalus framing: Hellerstein-Alvaro 2020 *Keeping CALM* explicitly says "Distributed systems deserve a computability theory" and CALM is "like P vs. NP or Decidability" — the closest 'parallel computability theorem'. But machine model is Ameloot's relational transducer network, not lattice. Garg's LLP (Streit-Garg 2025) uses "universal procedure" — bounded to lattice-linear predicates on distributive lattices. Kuper LVars thesis statement (verbatim): "lattice-based data structures are a general and practical foundation for deterministic and quasi-deterministic parallel and distributed programming." None invoke Turing/Church-Turing.
- **2026-05-08 [T3 done]** R3 returned 24KB. Single clean explicit UTM-analogue claim found: **Hewitt's actor model** ("universal conceptual primitives of digital computation", "all physically possible computation can be directly implemented using Actors"). Valiant BSP explicitly: *von Neumann* analogue, not Turing. PRAM = RAM-generalisation. Goldschlager 1982 "universal interconnection pattern" is closest universality claim within complexity-thesis frame. Kahn = fixpoint semantics. Plain Petri = decidable; only inhibitor/Sleptsov extensions are Turing-complete. Pi/CSP = calculi. Spivak Poly = "theory of interaction" / "new syntax for modeling [interacting] systems." GoI = "mathematical models of algorithms independently of any extant languages." Neither uses UTM-analogue rhetoric.
- **2026-05-08 [synthesis]** All three research files exist on disk. Cross-cutting finding: **only Hewitt** uses explicit UTM-analogue rhetoric for any parallel/concurrent model. The lattice-based framing (Kuper, Garg, CALM) is foundational-flavored but consistently bounded (deterministic-only, predicate-detection-only, coordination-free-only). FL(ℵ₀) + Whitman as universal parallel substrate appears unclaimed.

## Decision Log

- **2026-05-08 [plan]** Slug: `free-lattice-utm-parallel`. Output type: `outputs/<slug>.md` (a research brief / priority-claim audit, not a paper-style draft).
- **2026-05-08 [scale]** Subagent mode chosen over direct search: 7 sub-areas across distinct communities make decomposition genuinely useful for context pressure.
- **2026-05-08 [tooling]** Avoid PDF parsing per workflow guidance. Use paper search metadata, abstracts, HTML, official docs, and web snippets only.
- **2026-05-08 [tooling]** `verifier` subagent is not available in this runtime (only `researcher`, `reviewer`, etc.). Lead will perform citation/verification manually (as in direct-search mode), then run `reviewer` for the final pass.
- **2026-05-08 [round 2]** User explicitly enabled PDF parsing for three targeted Q&A calls (Nation-Paolini III, Hewitt 1008.1459, Kuper dissertation) and requested unblocking of Wolfram, propagator-network, CRDT-engineering, operad-of-wiring-diagrams, and Polynomial Functors literatures. Polynomial Functors gets dedicated attention because the user identifies it as "the best categorical identification of propagators on a propagator network" — the substrate underlying the Prologos compiler. Round 2 will produce an addendum appended to the existing final artifact.

## Researcher Briefs (to write after approval)

- `outputs/.plans/free-lattice-utm-parallel-T1.md` — R1 brief (lattice theory/logic).
- `outputs/.plans/free-lattice-utm-parallel-T2.md` — R2 brief (distributed/parallel systems).
- `outputs/.plans/free-lattice-utm-parallel-T3.md` — R3 brief (foundational parallel models + categorical).

## Output Artifacts (required)

- `outputs/.plans/free-lattice-utm-parallel.md` ✅ (this file)
- `outputs/.drafts/free-lattice-utm-parallel-research-lattice-logic.md` ✅
- `outputs/.drafts/free-lattice-utm-parallel-research-distributed.md` ✅
- `outputs/.drafts/free-lattice-utm-parallel-research-parallel-categorical.md` ✅
- `outputs/.drafts/free-lattice-utm-parallel-draft.md` (pending)
- `outputs/.drafts/free-lattice-utm-parallel-cited.md` (pending)
- `outputs/free-lattice-utm-parallel.md` (pending)
- `outputs/free-lattice-utm-parallel.provenance.md` (pending)
