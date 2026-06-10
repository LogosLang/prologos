# Provenance: FL(ℵ₀) + Whitman as a Universal Parallel Computational Substrate

- **Date:** 2026-05-08 (rounds 1 and 2 same day)
- **Topic:** Priority-claim audit — has anyone explicitly framed FL(ℵ₀) with Whitman's decision procedure as a UTM analogue for parallel computation?
- **Slug:** `free-lattice-utm-parallel`
- **Final artifact:** `outputs/free-lattice-utm-parallel.md` (~95 KB, 860 lines, including round-2 addendum, post-local-PDFs supplementary patch, and bibliography closure patch)
- **Plan:** `outputs/.plans/free-lattice-utm-parallel.md`

## Workflow

- **Rounds:** 2 (with a post-round-2 supplementary patch from user-provided local PDFs).
  - **Round 1:** 3 parallel researcher subagents + lead synthesis + reviewer pass + revised final.
  - **Round 2:** user explicitly approved unblocking PDFs and 4 unsearched literatures. 3 PDF resolutions (Nation-Paolini III via arXiv HTML; Hewitt 1008.1459 via arXiv abs page; Kuper dissertation via local `document_parse`) + 2 parallel researcher subagents (Wolfram+propagator+CRDT; operads+Poly-deep-dive).
  - **Round 2 supplementary patch:** user provided two local PDFs (Niu-Spivak *Polynomial Functors* full book; Endrullis-Shallit-Smith 2017 full PDF) and a scope direction (Wolfram out of scope). Lead-driven local `document_parse` + mechanical `grep` corrections. Three patches recorded: Wolfram demoted; ESS 2017 round-1 verdict corrected (paper *does* embed TM-into-rewriting via Lemma 1 / REWRITE-POWER, citing Book-Otto 1993); Niu-Spivak book parsed sections (~93 of 489 PDF pages) mechanically confirmed to contain zero propagator / Sussman / Radul / lattice / Whitman references.
  - **Round 2 bibliography closure:** user requested closing the residual gap on Niu-Spivak Chapter 9 + bibliography. Third `document_parse` pass (40 more pages: pages 450–489) covered Chapter 8.3–8.5 + complete References (~50 entries) + complete Index. Mechanical `grep` against ~30 prior-art search terms returned zero hits for all lattice-tradition, propagator-network, TMS, CALM, CRDT, Garg, Kuper, Hewitt, Wolfram, Petri, Kahn references. Two terms that hit (`Shapiro` × 1, `actor` × 3, `Conway` × 1) confirmed spurious: Shapiro = Brandon Shapiro the category theorist; actor = substring of `factor`; Conway = John Horton Conway. Two structural corrections recorded: (i) no Chapter 9 in published CUP/LMS book (round 2's prior reference based on draft preface); (ii) [Con12] is J. H. Conway, not Neil Conway.
- **Subagents used:**
  - Round 1: 3× `researcher` (parallel) — T1 lattice/logic, T2 distributed/parallel, T3 BSP/PRAM/dataflow/Petri/actor + categorical.
  - Round 1: 1× `reviewer` — verification pass against research files.
  - Round 2: 2× `researcher` (parallel) — T11 Wolfram+propagator+CRDT; T12 operads+Poly deep dive.
- **Subagents not available in this runtime:** `verifier`. Lead performed citation/verification manually as in direct-search mode.
- **Tooling failures (round 2):** `alpha_ask_paper` returned a schema validation error (`queries: invalid_type`) on every attempted call. Workaround: used `fetch_content` for HTML and `document_parse` for the downloaded Kuper PDF. `alpha login` was authenticated by the user but the schema error persists — appears to be a tool-side bug.
- **PDF parsing:** disabled in round 1 per workflow guidance. **Enabled in round 2 at user request.** Round 2 used: arXiv HTML pages via `fetch_content` (Nation-Paolini III, Hewitt abstract); local `document_parse` of downloaded PDF (Kuper dissertation, 101 pages parsed); Spivak slide deck PDF text via researcher's `fetch_content` (AFOSR Review 2022).

## Sources

- **Sources consulted (URLs surfaced across all five research files + 2 local PDFs):** ~150 URLs across rounds 1 and 2 + 2 user-provided local PDFs (Niu-Spivak Polynomial Functors book, ESS 2017 *Undecidability and Finite Automata*).
- **Sources accepted (cited in the final artifact):** 44 round-1 numbered references [1]–[44] + 17 round-2 references [R2-1]–[R2-17] + 2 supplementary-patch sources [R2-P-1], [R2-P-2] + 1 closure-patch source [R2-C-1] = 64 cited landmarks.
  - Round 1: 44 sources covering Endrullis-Shallit-Smith, Nation-Paolini, CALM/Bloom, Garg LLP, Kuper LVars, BSP/PRAM/dataflow/Petri/actor, Spivak Poly book.
  - Round 2: 17 additional sources covering Nation-Paolini III HTML body (Nies, Whitman 1943); Wolfram multicomputation; Radul propagator-network thesis; Sussman-Radul *Art of the Propagator*; Shapiro CRDT; Lasp; Spivak's *"Is Poly the true language of computation?"* AFOSR slides (the most consequential R2 finding); Spivak's *Poly* and operad-of-wiring-diagrams program; David Jaz Myers *Categorical Systems Theory*.
  - Free-lattice theory: [1][2][3][9][10][25] — 6 sources.
  - Endrullis-Shallit-Smith: [21][22][23][24] — 4 sources.
  - CALM/Bloom/Dedalus: [4][5][6][7][8] — 5 sources.
  - Garg LLP: [14][27][28][29] — 4 sources.
  - Kuper LVars: [11][12][13][26] — 4 sources.
  - BSP/PRAM/dataflow/Petri/actors/π/CCS: [15][16][17][18][30][31][32][33][34][35][36][37][38][39][40] — 15 sources.
  - Categorical foundations: [19][20][41][42][43][44] — 6 sources.
- **Sources rejected / not load-bearing:** general-background URLs that were consulted briefly and not cited (Wikipedia *Word problem (mathematics)*, *Turing reduction*, *Bridging model*; lecture notes on group word-problem undecidability; Endrullis-Zantema RTA 2015; Wolfram cellular-automata paper; Turing Tumble universality; tile-system universality; introtcs.org; informal StackExchange threads; Tau ECTT formalisation page). These appear only in the research files' "Sources" lists and are not cited in the final artifact.

## Verification

- **Verification:** **PASS WITH NOTES** (round 1) + round-2 additions are user-prompted unblocking, with all quotations directly verified against fetched HTML / parsed PDF / researcher-returned slide-deck text. Round-2 supplementary patch: corrections directly verified by local `document_parse` output and mechanical `grep` (commands and counts recorded inline in R2-Patch-3).
- **Round-2-patch verifications performed on disk:**
  - ESS 2017 PDF: Lemma 1 / REWRITE-POWER body inspected. Verbatim TM-encoding rewrite rules (1)-(7) and reduction-from-halting passage quoted in R2-Patch-2.
  - Niu-Spivak Polynomial Functors PDF: three `document_parse` passes (~133/489 pages including complete References + complete Index). Mechanical `grep -ic` against ~30 prior-art search terms returned 0 hits for all of: propagator/propagation, Sussman, Radul, Steele, McAllester/de Kleer/Forbus, TMS/truth maintenance, constraint propagation/constraint network, lattice, Whitman/Skolem/Birkhoff, FJN/Paolini, Hellerstein/Alvaro/Marczak, Bloom/Dedalus/CALM, CRDT/Conflict-free, Lasp/Meiklejohn, Garg/Kuper/LVars, Hewitt, Wolfram, Petri/Kahn/Arvind. The terms that did hit (Shapiro, actor, Conway) verified spurious by direct context inspection.
  - Wolfram demotion: section R2-B1 left intact for audit-trail purposes; R2-Patch-1 explicitly marks Wolfram out of scope per user direction with no factual retraction.
- **Verification artifact:** `outputs/.drafts/free-lattice-utm-parallel-verification.md` (12 KB, 129 lines). Reviewer found 0 FATAL, 1 MAJOR, 6 MINOR (all addressed in round-1 revised file).
- **Reviewer fixes applied (all 7):**
  - **M1** — Tightened §(b) "equivalent in spirit" / "precisely the model-theoretic content" tension by replacing "precisely" with "model-theoretic shadow" and labeling the inferential bridge as our reading. Verified on disk: `grep "precisely the model-theoretic content"` returns nothing; `grep "model-theoretic shadow"` matches line 61.
  - **m1** — Split the Kuper concatenated quote into two block-quotes with "(Later in the same talk:)" between them. Verified line 111.
  - **m2** — Footnoted the `[6] → [paper II]` substitution in the Nation-Paolini III abstract. Verified line 59.
  - **m3** — Footnoted that the Nation-Paolini III abstract was reconstructed from search snippets, not parsed from the canonical arXiv abs page. Verified line 58.
  - **m4** — Renumbered Executive Summary to "Four weaker / adjacent framings" with Kuper as #3 and Hewitt as #4. Verified line 14.
  - **m5** — Softened the "Whitman 1941" attribution to "Whitman's structural decision procedure (mid-20th-century, embedded in [9] as 'Whitman's condition (W)')". Verified line 63.
  - **m6** — Added "(per Wikipedia summary [32]; primary source not consulted)" parenthetical on the Goldschlager 1982 universality claim, both in the table footnote and in Cross-cutting observation 1. Verified lines 138 (table footnote ³) and 178.
  - **m7** — Marked the truncated CALM block-quote with `[…]`. Verified line 76.
- **What this audit cannot adjudicate (preserved in artifact):**
  - Whether the source-material quotes in the three research files are themselves faithful to the original primary papers (the verification chain only spans cited-draft → research-files).
  - Reduction shape used in Nation-Paolini III (arXiv:2511.13149) — blocked behind PDF parsing.
  - Forward citations of Endrullis-Shallit-Smith 2017.

## Key findings

- **Headline (unchanged after round 2):** No source surveyed explicitly frames FL(ℵ₀) + Whitman as a UTM analogue for parallel computation. The exact framing in the question appears to be **unclaimed in print**.
- **Closest precedents (round 1):**
  - Nation-Paolini III (arXiv:2511.13149, Nov 2025) for the algebraic fact (Th(F_κ) undecidable) — but framed model-theoretically, not computationally.
  - CALM theorem (Hellerstein-Alvaro 2020) for the "computability theory for distributed systems" spirit — substrate is relational-transducer network.
  - Kuper LVars thesis for the lattice-foundation framing — bounded to deterministic parallelism, no UTM rhetoric.
  - Hewitt actor model for the explicit UTM-analogue rhetoric — different substrate.
- **Round 2 additions (three new priority threats / precedents):**
  - **Wolfram's *multicomputational paradigm* (2021):** the strongest competing universality framing found in either round. Explicitly stakes "fourth foundational paradigm" status with multiway / hypergraph rewriting as substrate.
  - **Spivak's *"Is Poly the true language of computation?"* (AFOSR 2022):** the closest existing UTM-analogue rhetoric for any categorically-precise substrate. "Poly could serve as the foundational language"; "Turing machines have a natural description in Poly".
  - **Radul's *Propagation Networks: A ... Substrate for Computation* (MIT 2009):** the direct ancestor for the "substrate for computation" framing in propagator-network lineages (such as Prologos).
- **Round 2 negative finding of high relevance to Prologos:** the **identification of polynomial functors / dependent lenses with Sussman-Radul propagators is novel** in the surveyed corpus. Across the Niu-Spivak book, Spivak's complete public talk list, the Topos Institute Poly-related blog corpus, the operads-of-wiring-diagrams program, David Jaz Myers's *Categorical Systems Theory*, dependent-optics work, and the Sussman-Radul propagator literature, no paper, talk, blog post, or slide deck makes this identification.
- **Round 2 resolved blocked checks:**
  - Nation-Paolini III reduction is from **Nies 1996** (∃∀-theory of finite nice bipartite graphs), not from Turing halting. **Whitman 1943** embedding is load-bearing in §5 of [3] for the κ ≥ 3 case. No UTM rhetoric in [3].
  - Hewitt v38 abstract: "universal primitives of *concurrent* digital computation" (correction — round 1 had the unscoped version). Body-level "all physically possible computation" claim corroborated by HAL but not directly fetched.
  - Kuper dissertation: zero occurrences of Turing / Church-Turing / Hewitt / actor / free lattice / Whitman / propagator / Sussman / Radul. Confirmed by mechanical `grep` on parsed text. The formal thesis statement is "general and practical unifying abstraction for deterministic and quasi-deterministic parallel and distributed programming."

## Files

- **Plan:** `outputs/.plans/free-lattice-utm-parallel.md`
- **Researcher briefs:** `outputs/.plans/free-lattice-utm-parallel-T{1,2,3}.md`
- **Research files (T1/T2/T3 outputs):**
  - `outputs/.drafts/free-lattice-utm-parallel-research-lattice-logic.md` (16 KB)
  - `outputs/.drafts/free-lattice-utm-parallel-research-distributed.md` (22 KB)
  - `outputs/.drafts/free-lattice-utm-parallel-research-parallel-categorical.md` (24 KB)
- **Round 1 drafts:**
  - `outputs/.drafts/free-lattice-utm-parallel-draft.md` — lead-synthesised pre-citation draft
  - `outputs/.drafts/free-lattice-utm-parallel-cited.md` — first cited version
  - `outputs/.drafts/free-lattice-utm-parallel-verification.md` — reviewer pass
  - `outputs/.drafts/free-lattice-utm-parallel-revised.md` — round-1 final candidate (delivered as opening of `outputs/free-lattice-utm-parallel.md`)
- **Round 2 research files:**
  - `outputs/.plans/free-lattice-utm-parallel-T11.md` — R4 brief (Wolfram + propagator + CRDT)
  - `outputs/.plans/free-lattice-utm-parallel-T12.md` — R5 brief (operads + Poly deep dive)
  - `outputs/.drafts/free-lattice-utm-parallel-research-wolfram-propagator-crdt.md` (~22 KB)
  - `outputs/.drafts/free-lattice-utm-parallel-research-operads-poly-deep.md` (~28 KB)
  - `outputs/.drafts/free-lattice-utm-parallel-round2-addendum.md` — lead-synthesised addendum, appended to final artifact
- **Round 2 supplementary patch source PDFs (local, user-provided):**
  - `/Users/avanti/dev/projects/prologos/outside/Polynomial Functors_ A Mathematical Theory of Interaction - Spivak, Niu.pdf` — Niu-Spivak Poly book (LMS Lecture Notes / CUP), 489 PDF pages, ~133 parsed across three passes including complete bibliography and complete index
  - `/Users/avanti/dev/projects/prologos/outside/UH Professor - JB Nation - Lattices, Publications/NFA undecidable.pdf` — Endrullis-Shallit-Smith 2017 *Undecidability and Finite Automata* (arXiv:1702.01394v2), 12 pages, fully parsed
- **Final delivery:** `outputs/free-lattice-utm-parallel.md` (~95 KB, 860 lines, includes round-1 body + round-2 addendum + R2 supplementary patch + bibliography closure patch).
