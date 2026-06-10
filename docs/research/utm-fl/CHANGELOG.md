# UTM-FL Programme Lab Notebook

Append-only. Read before resuming substantial programme work.

---

## 2026-05-08 — Programme opened

- `PROGRAMME.md` v0.1 drafted from multi-turn conversation with owner.
- Five-paper plan adopted: A0 (LHC system) → Poly (categorical foundation) → A (LRP) → B (FL substrate) → C (variety optimality). Skeletons under `paper-drafts/`.
- Existing investigation `outputs/free-lattice-utm-parallel.md` re-tagged as Paper-B prior-art floor.
- Programme-support files created: `CHANGELOG.md` (this file), `open-questions.md`, `engineering-anchors.md`, `prior-art-watch.md`, `bibliography.md`.
- Key reframings registered:
  - Paper B "is the parallel UTM" softened to "candidate substrate / analogy / programme."
  - Paper B "CALM = Church-Turing analog" reframed as CALM-as-partial-demarcation + LRP-as-recovery.
  - Paper A "uniform bifibration" weakened to "recovery principle with heterogeneous categorical character per instance" (per `2026-03-21_CATEGORICAL_STRUCTURE_FIVE_SYSTEMS` honest assessment).
  - Paper C un-deferred from 24mo; skeleton now, run in parallel.
  - Poly = propagator identification promoted from "section in B" to "standalone foundational paper."
  - A0 system paper added as front of sequence.
- Empirical Whitman 10/10 finding (`2026-05-08_PROLOGOS_LATTICE_VARIETY_CATEGORIZATION`) registered as Paper B's empirical anchor.
- Topology-strata added as sixth LRP instance (per owner note).
- Nation collaboration: weekly cadence; informal adviser; co-authorship and colleague-pointer paths open.
- Tooling note carried forward: `alpha_ask_paper` schema-error workaround in place — use `fetch_content` + `document_parse` instead.

**Next**: owner edits PROGRAMME.md v0.1 → v1.0; then either (a) novelty-positioning audit on stratified semantics for Paper A, or (b) PReduce-feeding research synthesis, or (c) A0 outline expansion. Owner picks.

---

## 2026-05-08 (later) — Phase-collapse + deterministic-parallelism audit

- Owner clarification: **A0 carries two headlines, not one.** Phase Collapse + Order-Independent Deterministic Parallelism (built on CALM + LVars). Both are major findings achieved in current architecture.
- Internal-source audit run: `outputs/phase-collapse-and-deterministic-parallelism-audit.md` (~16 KB, 13 evidence entries, 6 gaps, 6 next moves) + provenance sibling.
- Headline finding from audit: the two claims are **structurally coupled**. Lattice-valued cells + monotone propagators + semilattice merge ⇒ order-invariant fixpoint ⇒ scheduler-portable network state ⇒ .pnet-as-IR ⇒ phase collapse. H1 is the cause, H2 is the consequence.
- Updated PROGRAMME.md A0 paper section to dual-headline framing.
- Updated `paper-drafts/A0-LHC-system-paper.md` with H1 + H2 + coupling + revised outline.
- Resolved (draft, pending owner validation): Q-A0-1, Q-A0-2.
- Updated engineering-anchors A2 (4 schedulers enumerated; A/B infra cited; fixpoint-identity gap identified) and A4 (precise statement drafted from corpus; PReduce scoping decision flagged).
- Six engineering gaps identified for follow-up: G1 (PReduce scope decision for A0), G2 (add fixpoint-identity assertion to A/B harness), G3 (pin Zig PoC commit), G4 (verify scheduler count), G5 (LVars/CALM lineage citations into bibliography), G6 (NTT + Idris/Lean precedents in A0 related work).
- Tooling status: `pi-schedule-prompt` installed but not enabled in `~/.feynman/agent/settings.json`; `memory` package not installed (`feynman packages install memory` to add); `pi-zotero` installed but not enabled.

**Next**: owner reviews proposed precise statements + decides on PReduce scoping for A0. Then either (a) close G2 with a small test addition (1-day engineering), or (b) move to Q-A1 stratified-semantics novelty audit for Paper A.

---

## 2026-05-08 (3rd entry) — Owner reactions + sequencing decisions

- **Precise statements (Claim 1, Claim 2)**: validated. "It's what we use as a pragmatic in our system today, and depend on."
- **A0 sequencing**: **wait for PReduce, possibly until close to fully-hosting** (~6+ months). Strongest paper. Other papers proceed in parallel and are held / released after A0.
- **Poly paper sequencing**: develop as **draft that feeds engineering** while becoming a publishable artifact. Inverts research/engineering flow: paper draft becomes a categorical map the engineering consults. Rework to final-paper form at submission time.
- **Other papers**: "could use more background in their respective literature searches" — next round of investigations should include lit-positioning passes for A, B, C.
- **Gap dispositions**:
  - G1: wait for PReduce (above).
  - G2: **already done in PAR 1 + BSP 2 design + implementation**; not re-running. Audit updated.
  - G3: deferred (Zig PoC pinning not interesting to owner).
  - G4: 4 schedulers enumerated by owner: Gauss-Seidel sequential DFS; original BSP (BFS "line-draw" over frontier cells, sequential); actual BSP (PAR 2, used in BSP-LE 2/2B); Zig PoC.
  - G5: **important direct lineage** (LVars/CALM directly inspired the architecture). Bibliography promoted; A0 acknowledgments add Kuper, Hellerstein-Alvaro, BloomL team explicitly.
  - G6: scan approved.
- **PAR Track 2 anecdote**: ~40-line parallel scheduler PoC "just worked" on first run, against owner's expectation of 8+ hours debugging race conditions. Empirical evidence that CALM is enforced *architecturally* by the substrate, not by per-scheduler care. Captured in audit as E9-bis; planned for A0 introduction or discussion.
- **Files updated**: audit (E9 expanded; E9-bis added; gap-status section rewritten), PROGRAMME.md (A0 timing updated; Poly engineering-feeding mode added), bibliography.md (LVars/CALM elevated to direct lineage), paper-drafts/A0-LHC-system-paper.md (timing + acknowledgments + audit reference), paper-drafts/Poly-propagators.md (engineering-feeding mode section added).
- **Tooling status**: settings.json complete (memory + schedule-prompt + zotero); fresh session needed to expose new tools. `alpha_get_paper` confirmed working (full text retrieval, just retrieved Nation-Paolini I); `alpha_search` and `alpha_ask_paper` still broken (carry forward `web_search` + `alpha_get_paper` + `document_parse` as workarounds).

**Next** (post-fresh-session):
1. Verify memory/schedule/zotero tools exposed.
2. Use `memory_remember` to store programme conventions (PROGRAMME.md / CHANGELOG.md / open-questions.md / engineering-anchors.md / bibliography.md / prior-art-watch.md / paper-drafts/ + outputs/ structure with internal-research / audit / synthesis distinction) so future sessions inherit them.
3. Queue prior-art watches via `schedule_prompt`.
4. Owner picks the first substantive deep-research investigation:
   - **(a)** Q-A1 stratified-semantics novelty audit (gates Paper A; ~1-2 days).
   - **(b)** Q-Poly-1 + Q-Poly-2 light positioning passes (informs the Poly internal-research note + external paper; ~1 day each).
   - **(c)** Background lit-positioning pass for B (substrate-vs-decider formalization; Q-B1; ~1-2 days).
   - **(d)** Research-feeding-engineering synthesis on whatever is most engineering-pressing (PReduce-adjacent, e-graph persistence, etc.).

---

## 2026-05-08 (4th entry) — Two-Poly distinction + internal-research-notes pattern formalized

- **Two-Poly distinction** (per owner 2026-05-08): the Poly work splits into two artifacts:
  - **Internal Poly research note** at `outputs/poly-as-propagator-internal-research.md` — working categorical map for engineering decisions; co-evolves with NTT, PReduce, etc.; stays in `outputs/` indefinitely.
  - **External Poly paper** at `paper-drafts/Poly-propagators.md` — polished publishable form, reworked from the internal note when ready.
- **Pattern recognition**: the project has been doing internal research notes feeding engineering for a long time — 100+ files in `docs/research/`. The substrate has no engineering precedence to copy; outside mathematics has been synthesized into actionable engineering guidance throughout. **The pattern is now formalized inside the programme as a first-class convention** (PROGRAMME.md §9):
  - `outputs/*-internal-research.md` — evolving internal notes feeding engineering.
  - `outputs/*-audit.md` — priority-claim / novelty positioning audits.
  - `outputs/*-synthesis.md` — external-literature synthesis.
  - `paper-drafts/*.md` — external-facing manuscripts only.
- **Inaugural internal-research note created**: `outputs/poly-as-propagator-internal-research.md` (skeleton with 5 engineering questions Q-EP1–Q-EP5, working identifications, external-mathematics-synthesis status, engineering-feedback log).
- **Programme-level files updated**:
  - PROGRAMME.md: §9 "Internal research notes (programme pattern)" added; Paper-Poly section updated to two-artifact pattern; pre-existing precedent section catalogs broader-project precedent.
- **Tooling**: settings.json complete; pre-restart persistence work done (this changelog entry + PROGRAMME.md §9 + Poly internal-research skeleton + tool-recommendation list — see chat).

**This entry is the durable record of the programme state at session-end (2026-05-08).** A fresh session reading PROGRAMME.md + CHANGELOG.md + open-questions.md should be able to pick up cleanly.

---

## 2026-05-09 — Fresh-session re-acquaintance + tool surface verification + Q-B5 closed

**Session purpose**: re-orient after restart, verify the tools the previous session was waiting on, decide what to investigate next.

### Tool surface (verified by direct invocation, not by config inspection)

| Tool | Status | Notes |
|---|---|---|
| `memory_*` (search/remember/forget/lessons/stats) | ✅ working | Stats: 4 facts, 2 lessons, 6 events. Programme conventions stored as facts (`project.prologos.utm_fl_programme.layout`, `.artifact_pattern`, `.papers`). Tooling lesson stored under `prologos-tooling`. |
| `schedule_prompt` | ✅ working | Empty queue. Ready for prior-art watches. |
| `zotero` | 🟡 partial | Tool present; falls back to BibTeX file search but `BIBTEX_PATH` env var unset, so search returns the configuration message. Either set `BIBTEX_PATH` or run Zotero with Better BibTeX live. |
| `alpha_get_paper` | ✅ working | Full-text retrieval confirmed on arXiv:2511.13149 (Nation–Paolini III). Returns content + sections + missingSections. |
| `alpha_search` | ❌ broken | Returns `MCP error -32602: Tool embedding_similarity_search not found`. Upstream tool name has changed/been removed in the MCP server; wrapper still maps to the old name. |
| `alpha_ask_paper` | ❌ broken | Returns `Invalid arguments for tool answer_pdf_queries: queries expected array, received undefined`. Wrapper sends `{question: "..."}`; upstream now expects `{queries: ["..."]}`. Schema/wrapper mismatch. |
| `alpha_read_code`, `alpha_annotate_paper`, `alpha_list_annotations` | not retested | Retest if needed; no current dependency. |
| `web_search`, `fetch_content`, `document_parse`, `process`, `subagent`, etc. | ✅ available | Continue as workarounds for the broken alpha verbs. |

**Workaround posture (carries forward)**:
- For paper *discovery*: `web_search` (Perplexity/Exa/Gemini) instead of `alpha_search`.
- For paper *Q&A*: `alpha_get_paper` to retrieve full text → grep / read / parse locally instead of `alpha_ask_paper`.
- For local PDFs: `document_parse` + `grep` (proven on the round-2 audit).

Memory lesson stored so future sessions don't re-discover this. `alpha_search` and `alpha_ask_paper` should be re-tested after any feynman/alpha package update.

### Side-result: Q-B5 closed by tool acquaintance pass

When sanity-checking `alpha_get_paper` against the Nation–Paolini III preprint, the full body came back. Q-B5 ("From what undecidable problem does NP-III reduce?") is therefore answered without dedicated investigation:

- **Reduction source**: Nies, A. "Undecidable fragments of elementary theories." Algebra Universalis 35 (1996), 8–33, **Theorem 4.7** — ∃∀-theory of *nice finite bipartite graphs* is undecidable.
- **Lift**: bipartite graphs ↔ bipartite posets (Cor. 2.7); standard embedding ξ : Q ↪ F_m by ξ(qᵢ) = ∏{xⱼ : qⱼ ⩾ qᵢ} (Fact 4.1); recovery internal to F via the first-order predicate t E u for doubly-minimal join covers (§3, Lem. 3.2). For F_κ with κ ⩾ 3, compose with Whitman's ζ : FL(ℵ₀) ↪ F_3 (§5).
- **Translation**: φ(∀∃ on bipartite posets) ↦ φ* on lattices using Ψ(w) (Lem. 3.3) to first-order-define the carrier bipartite poset U = {u : w E u} inside F_κ; φ holds in all finite nice bipartite posets ⟺ F_κ ⊨ φ* (Lem. 4.4).
- **Not**: group/semigroup word problem, not Hilbert's 10th, not direct Turing halting.
- **Implication for Paper B (substrate-vs-decider, Q-B1 still open)**: the undecidability *of FL's full theory* propagates through **first-order definable internal structure** — doubly-minimal join covers — not through a Turing simulation. The encoding chain TM ↪ rewriting (ESS 2017) is a *separate* track, addressing computability not theory-undecidability. Paper B should not conflate them. This actually helps the substrate-vs-decider posture: the decider story is computability via rewriting/automata; the substrate story is the algebraic carrier whose theory is rich enough to internally encode hard combinatorial problems. Q-B1 still needs its own audit but Q-B5 won't appear there as a blocker.
- **Files updated**: `bibliography.md` (NP-III entry expanded; Nies 1996 added as new entry, retrieval pending), `open-questions.md` (Q-B5 marked ✅ with full provenance).
- **Memory note** stored as part of `project.prologos.utm_fl_programme.papers` lineage; Nies 1996 retrieval is the only remaining loose end here.

### Side-discovery (not yet acted on)

NP-III has a clean **Whitman tie-in inside the proof itself** (§5 "Whitman revisited") — the Whitman embedding ζ : FL(ℵ̃) ↪ F_3 is reused as the cardinality-reduction step. This is interesting for Paper B's Whitman pillar (Q-B3): the same Whitman construction that anchors our empirical 10/10 finding is *also* the cardinality lever in the undecidability proof. May be worth a one-paragraph note in Paper B's Whitman section. Filed mentally; not a blocker.

### State at session-end (2026-05-09)

- Owner-facing decision pending: which substantive deep-research investigation to start (the four options from the previous changelog entry remain open: Q-A1 stratified-semantics novelty audit / Q-Poly-1+2 positioning / Q-B1 substrate-vs-decider lit pass / research-feeding-engineering synthesis).
- No `schedule_prompt` cron jobs added yet — deferred until owner decides cadence (monthly arXiv re-scan and quarterly stratified-semantics scan from PROGRAMME.md §6 are the natural candidates).
- Memory now carries the four programme facts/lessons listed above so the next fresh session can `memory_search prologos` and pick up programme structure without re-reading every file.

**Next**: owner picks investigation target. Four candidates from prior session still on the menu; Q-B5 no longer needs to be one of them.

---

## 2026-05-09 (later) — Alpha MCP wrapper diagnosed and patched

**Trigger**: owner asked whether `alpha_search` / `alpha_ask_paper` could be diagnosed and fixed instead of worked around.

**Diagnosis path**:
1. Read the local `@companion-ai/alpha-hub@0.1.3` source (`src/lib/alphaxiv.js`, `src/mcp/{server,tools}.js`). Saw the wrapper calls upstream tools `embedding_similarity_search`, `full_text_papers_search`, `agentic_paper_retrieval`, `answer_pdf_queries` (sending `{urls:[url], queries:[query]}` first, fallback to singular `{url, query}`), `get_paper_content`, `read_files_from_github_repository`.
2. Ran the `alpha` CLI directly (bypassing MCP) and saw the same upstream errors: three `Tool not found` on the search trio, `queries: expected array, received undefined` on ask. So the bug is upstream-of-the-wrapper-but-below-the-CLI.
3. Fetched the official alphaXiv MCP docs page (`https://www.alphaxiv.org/docs/mcp`) — lists 6 tools, documents `answer_pdf_queries` as `{url, query}` singular. Inconsistent with the live errors.
4. Wrote a standalone probe (`alpha-diagnose.mjs` in the Feynman npm root) that uses the same SDK + token and calls `client.listTools()` directly. Result: **upstream actually exposes 4 tools, not 6**, and the schemas differ from the docs.

**Live tool surface (canonical, May 9 2026)**:
- `discover_papers` (NEW; replaces all three search tools): `{ keywords: string[], question: string, difficulty: number 1–10 }` — all required.
- `get_paper_content`: `{ url: string, fullText?: boolean }` (matches wrapper).
- `answer_pdf_queries`: `{ url: string, queries: string[] }` — singular `url`, **plural** `queries`. Returns filtered raw page XML, not prose.
- `read_files_from_github_repository`: `{ githubUrl: string, path: string }` (matches wrapper).

**Fix applied** (patched `src/lib/alphaxiv.js` in place; backup at `.bak`):
- Added `discoverPapers({ keywords, question, difficulty })`.
- `searchByEmbedding/Keyword/Agentic` are now thin shims that auto-extract keywords (whitespace split, drop stopwords, top 4 tokens), build a question, and route through `discover_papers`. Mode → difficulty: keyword=3, semantic=5, agentic=8.
- `answerPdfQuery(url, queriesOrQuery)` rewritten to send `{ url, queries: <array> }`. Accepts either a single string (auto-wrapped) or an array (preferred — enables batched questions on one PDF).

**Verification (CLI works end-to-end)**:
- `alpha search` (all three modes) returns paper lists.
- `alpha ask 2511.13149 "..."` returns filtered XML page content.
- Live agent-side `alpha_search` / `alpha_ask_paper` tools still 404/schema-error in **this** session because the `alpha-mcp` subprocess loaded the old code at boot. Next session restart picks up the patch.

**Behaviour change to internalize**: `alpha_ask_paper` no longer returns a prose answer. It returns filtered raw page XML keyed by query terms. The agent must synthesize the answer itself from the returned XML, or use `alpha_get_paper` for the whole paper.

**Durability + maintenance**:
- Full fix notes at `notes/alpha-mcp-fix-2026-05-09.md` — includes diagnosis recipe, exact diff intent, re-application instructions if `feynman packages install` re-fetches alpha-hub.
- Memory lesson `prologos-tooling` rewritten with the new state (old lesson forgotten).
- Recommended: file an issue + PR upstream at `getcompanion-ai/alpha-hub` (small repo, 1 maintainer); also report stale docs to alphaXiv. Both deferred to owner.

**Files modified or created this session**:
- `bibliography.md` — NP-III entry expanded with reduction shape; Nies (1996) added.
- `open-questions.md` — Q-B5 marked ✅.
- `CHANGELOG.md` — this session's entries.
- `notes/alpha-mcp-fix-2026-05-09.md` — new file, full alpha fix dossier.
- `…/alpha-hub/src/lib/alphaxiv.js` — patched (outside the repo; backup `.bak`).
- `…/feynman/npm/alpha-diagnose.mjs` and `alpha-diagnose2.mjs` — probes, kept for re-use after future feynman updates.

**Programme impact**: zero behavioural lock on the programme — we never depended on the broken tools functionally; we always had `alpha_get_paper` + `web_search` + `fetch_content` + `document_parse`. But future deep-research investigations (Q-A1, Q-Poly-1, Q-B1) will run faster now that `alpha_search` / `discover_papers` is available again.

---

## 2026-05-09 (later) — PReduce substrate research: spine C1–C4 + engineering memo + corpus housekeeping

**Session purpose**: support PReduce engineering with an inward-facing research synthesis on the categorical foundations of e-graphs + tropical-quantale cost + GoI runtime; integrate with adhesive-DPO hypergraph rewriting already partially realized in PPN parsing + SRE Track 2D.

### Two new durable artifacts (programme-level)

- **`outputs/preduce-adhesive-rewriting-substrate-internal-research.md`** (~840 lines) — internal-research note per programme §9 pattern. Four spine claims (C1–C4) worked end-to-end under a substrate-first/theory-after posture, plus alternative-frame detour (§2.C1.alt) and engineering specialization stubs (§3.S5, §3.S6).
- **`outputs/preduce-engineering-inputs-from-substrate-research.md`** (~360 lines) — distilled engineering memo derived from the internal note. Per-track inputs for Tracks 0.1, 0.2, 0.3, 1, 2, 3, 4, 5, 6, 9; PReduce-Master open-question dispositions; new external references; NAC requirement; C3.e merge target with Logic Engine; HVM2 benchmark.

### Headline finding

**Primary categorical frame for PReduce shifts from Biondo-et-al. M-adhesive (CALCO 2025, arXiv:2503.13678) to Tiurin–Barrett–Ghica–Hu (TBGH) semilattice-enriched SMC (LICS 2025, arXiv:2406.15882).** Substrate fit is direct: our lattice-valued cells *are* the semilattices the enrichment requires. The substrate-research note's recommendation is adopted; corpus housekeeping landed (see below).

### Methodological refinement

Owner clarified a project-level norm: internal-research notes have lee-way for *speculative bridging* beyond what external research permits. Pattern is **substrate-first / theory-after** — engineering crystallizes structures that don't yet have a closed categorical/algebraic theory; the formal frame is found afterward via adjacent mathematics. Owner-named precedent: logical resolution on propagator networks. Methodology refinement persisted to memory (`prologos.research_methodology.substrate_first`) and embedded in the internal note's §2.0 Posture subsection. Strength labels in the 4-column memo extended to include **Speculative bridging** alongside Theorem / Engineered-and-tested / Structural-conjecture / Asserted.

### Spine outcomes (one line each)

- **C1** (e-graphs are adhesive): corpus claim **downgraded** — they are T_Σ-adhesive (M-adhesive, not full adhesive). The C1.alt detour established TBGH semilattice-enriched as primary frame instead.
- **C2** (adhesive ↔ CALM): **sharpened** to structural identity at the enrichment level — BloomL's three monotone-merge axioms ARE TBGH's first three enrichment axioms. ATMS supplies the S(−1) coordination protocol (owner-registered).
- **C3** (e-graphs as quotient modules; backward chaining as residuation): **direct categorical identification** with TBGH Thm 6.5; Russo 2010 Q-module theory supplies residuation API at signature level. Resolves Track 0.1 §7.7. **C3.e is the load-bearing engineering claim**: shared residual operator for cost-extraction + Logic Engine backward-chaining.
- **C4** (GoI = propagator fixpoint): **structural identity at the Kleene-star / trace level** in a traced semilattice-enriched SMC. Runtime story is automatic. **Phase collapse (Paper A0 H2) gets a categorical witness candidate** (C4.f).

### Engineering implications registered

Three owner-approval points in the engineering memo §11, flagged for explicit acknowledgment before specific tracks open:

1. **NAC support is now a first-class requirement** for the rule format (memo §7).
2. **C3.e (shared residual API)** is the load-bearing merge target with the Logic Engine (memo §8).
3. **HVM2 (74,000 MIPS RTX 4090) as Track 2 benchmark target** sets performance-ceiling expectation.

Other tracks: clarified per-track inputs per memo §2. Cell NTT declaration extends from `:lattice :structural :order :refinement` to `:lattice :structural :enrichment :semilattice [:Q-module Q]`. Rule-property axis reframes as *enrichment-preserving-or-not* tags. \.pnet schema extends with enrichment annotations + NAC + worldview-bitmask + e-class registry sub-schema.

### Corpus housekeeping landed (2026-05-09 third batch)

Five corpus locations amended in this session per the internal note's drift log:

1. **`docs/tracking/2026-05-02_PREDUCE_MASTER.md`** — added two `Source documents` entries linking the internal note + engineering memo; softened SRE Track 2D adhesive-guarantees claim in Cross-series-connections (C2.f); reframed open Q4 to cite TBGH + Bonchi III decidability.
2. **`docs/research/2026-05-02_E_GRAPHS_RESEARCH.md` §3.1** — replaced single-frame Biondo paraphrase with two-frame picture (Frame A = M-adhesive Biondo; Frame B = semilattice-enriched TBGH); flagged Frame B as primary for our substrate.
3. **`docs/research/2026-03-24_HYPERGRAPH_REWRITING_PROPAGATOR_PARSING.md` §3.3** — same correction.
4. **`docs/research/2026-05-02_PREDUCE_TRACK01_ARCHITECTURAL_SKETCH.md` §10.4** — promoted TBGH (LICS 2025) + Russo (2010) + Bonchi et al. (I/II/III) + Moss-Tiurin (2025) to primary lit refs; demoted Biondo to alternative/comparison. Added foundational + production/runtime sub-categories.
5. **`docs/research/2026-05-02_ARCHITECTURE_NOVELTY_SURVEY.md`** — added TBGH foundation entry before Moss-Tiurin (which builds on it) and Biondo (alternative frame).

### Tooling activity (in passing this session)

Alpha MCP wrapper diagnosed + patched + verified working (CLI end-to-end). `alpha_get_paper` was working all along; `alpha_search` and `alpha_ask_paper` had upstream schema migration not reflected in `@companion-ai/alpha-hub@0.1.3`. Patch at `…/alpha-hub/src/lib/alphaxiv.js` (backup `.bak`). Full dossier at `notes/alpha-mcp-fix-2026-05-09.md`. Restart picks up the patch for agent-side tools.

Mempalace CLI used throughout for stable-architectural-concept lookup per `.claude/rules/mempalace.md`; cross-checked against current dailies before relying on hits.

### Programme impact

This is the first end-to-end *substrate-first/theory-after internal-research note* the programme has produced under the formalized convention (§9). It validates the pattern:

- Spine C1–C4 each followed the same shape (Locate → Read → External probe → Stress-test → 4-column memo).
- The same external framework (TBGH semilattice-enriched SMC) collapsed four different metaphors / conjectures / informal observations in our corpus into structural identities. The pattern "engineering already builds the structure; the categorical name comes after" was concretely realized.
- Two artifacts in `outputs/` (one internal-research note + one engineering memo derived from it) demonstrate the two-artifact pattern (matching Poly's pair: `outputs/poly-as-propagator-internal-research.md` + `paper-drafts/Poly-propagators.md`, though Poly's external manuscript hasn't been written yet).

### Follow-ups (registered, not blocking)

- §3 specialization passes (S1–S6) in the internal note when engineering needs them.
- Owner acknowledgment on the three approval points before Tracks 0.2 / 4 / 2 open.
- The MaRDI portal entry on "Enriched categorical semantics for distributed calculi" — retrieval pending.
- Baldan et al. CONCUR 2024 (left-linear M-adhesive) — retrieval pending; carried as alternative-frame reference, not load-bearing for primary engineering.
- Bachelard et al. NAC-specific edge cases for Track 3 — to surface when Track 3 design opens.

**Files modified or created this session (2026-05-09 third batch)**:
- `outputs/preduce-adhesive-rewriting-substrate-internal-research.md` — NEW, ~840 lines
- `outputs/preduce-engineering-inputs-from-substrate-research.md` — NEW, ~360 lines
- `docs/tracking/2026-05-02_PREDUCE_MASTER.md` — amended (Source documents, Cross-series-connections, open Q4)
- `docs/research/2026-05-02_E_GRAPHS_RESEARCH.md` — amended (§3.1 two-frame rewrite)
- `docs/research/2026-03-24_HYPERGRAPH_REWRITING_PROPAGATOR_PARSING.md` — amended (§3.3 two-frame rewrite)
- `docs/research/2026-05-02_PREDUCE_TRACK01_ARCHITECTURAL_SKETCH.md` — amended (§10.4 lit-ref reorg)
- `docs/research/2026-05-02_ARCHITECTURE_NOVELTY_SURVEY.md` — amended (TBGH entry added)
- `CHANGELOG.md` — this entry
- Memory: `project.prologos.research_methodology.substrate_first` fact added

**Programme state at session-end**: PReduce engineering has two consumable artifacts (internal note + engineering memo) and a refreshed corpus that no longer misleads on the categorical frame. Three owner-approval points await acknowledgment before specific tracks open. Spine work closed; specialization passes (S1–S6) and corpus housekeeping both complete for this round.
