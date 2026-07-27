# UTM-FL Research Programme

**Status**: v0.1 charter — open for revision.
**Date opened**: 2026-05-08.
**Owner**: Avanti (with J. B. Nation as informal adviser).
**Convention**: this document is the thesis-level contract. Investigations under `outputs/`, paper drafts under `paper-drafts/`, and research-feeding-engineering notes under `outputs/syntheses/` all reference back here.

---

## 1. Core thesis tree

The programme rests on a four-level identification, engineered first, theorized after:

| Level | Identification | Status |
|---|---|---|
| **Substrate** | FL(ℵ₀) + Whitman is the carrier of computational state | Empirically grounded; algebraically defended (Nation–Paolini I/II/III); priority-claim audit complete |
| **Syntax of the substrate** | Polynomial functors on lattice-valued cells = Sussman–Radul propagators | Identification appears original (per round-2 audit); to be published |
| **Demarcation** | CALM characterizes the monotone fragment that lives natively on the substrate | Cited literature (Hellerstein–Alvaro 2020, Ameloot et al. 2013) |
| **Recovery** | Layered Recovery Principle: non-monotone computation decomposes into stratified monotone fixpoints with controlled inter-stratum transitions | Engineered in five-plus systems; categorical formalization in progress |

Plus an orthogonal optimality axis:

| Axis | Identification | Status |
|---|---|---|
| **Optimality** | For variety V, the Hasse of a finitely-presented sub-lattice is the optimal parallel decomposition under V's natural cost model | Theorem for Boolean (hypercube), theorem for distributive (Garg LLP), conjecture for SD/modular/FL |

And one cross-cutting empirical claim that anchors the whole programme:

> **The Logos Hyperlattice Compiler (LHC) realizes this stack as a single propagator network in which compile-time and run-time are the same fixpoint computation**, the .pnet serialization is its own IR, and the network is scheduler-portable up to CALM-permitted variation.

---

## 2. Paper plan

Five papers in a planned sequence. Two more identified as future. Skeletons live in `paper-drafts/`.

### A0 — *The Logos Hyperlattice Compiler: Order-Independent Deterministic Parallelism and Phase Collapse on a Propagator Network*

- **Type**: Systems / artifact paper.
- **Two headline claims** (per owner direction 2026-05-08; structurally coupled):
  - **H1**: Order-independent deterministic parallelism — the propagator network's fixpoint is invariant under firing order; the LVars / CALM / BloomL lineage realized at the granularity of an entire programming-language compiler.
  - **H2**: Phase collapse — the same network primitives serve compile-time and run-time; conventional compile-pipeline phases reduce to stratum boundaries on the same network.
  - **Coupling**: H1 is the cause, H2 is the consequence. (See `outputs/phase-collapse-and-deterministic-parallelism-audit.md` for the dependency chain.)
- **Supporting claims**: .pnet-as-IR; CHAMP-backed O(1) network forking; A/B benchmark infrastructure exercising the cross-scheduler equivalence across the entire compiler; NTT as the design meta-language used since inception.
- **Empirical anchors**: working compiler (Racket + Zig BSP scheduler PoC); .pnet → LoweredPNET → LLVM lowering on branch.
- **Venue tier**: PLDI, OOPSLA, CGO, or ICFP system-paper track.
- **Risk**: low. Describes what exists. No new theorems required.
- **Time-to-submit estimate**: ~6+ months from now, **gated on PReduce reaching readiness** (per owner direction 2026-05-08). Strongest paper; the wait gives full phase-collapse including reduction. Possibly aligned with proximity to fully self-hosting.
- **Sequencing role**: lowest-risk publication content-wise; establishes citable artifact ground for everything below. **Other papers can be drafted in parallel and held / released after A0.**
- **Skeleton**: `paper-drafts/A0-LHC-system-paper.md`.

### Poly — *Polynomial Functors as Propagators on Lattice-Valued Cells*

- **Type**: Foundational categorical paper. **Two-artifact pattern (per owner 2026-05-08)**:
  - **Internal Poly research note** at `outputs/poly-as-propagator-internal-research.md` — working categorical map for engineering decisions; co-evolves with NTT, PReduce, and other propagator-infrastructure work; stays in `outputs/` indefinitely.
  - **External Poly paper** at `paper-drafts/Poly-propagators.md` — polished publishable form, reworked from the internal note when ready.
- **Headline claim**: Sussman–Radul propagators on lattice-valued cells are the polynomial-functor view of computation that Spivak's Poly programme has been seeking a substrate for. Cells live in lattices; propagators are polynomial functors over the category of lattice-valued cells; Galois connections between cells of different domains are the bridge structure; LKan/RKan extensions are the inter-stratum machinery.
- **Why separate from Paper B**: the identification is itself novel (per round-2 audit) and deserves a dedicated venue. Folding it into Paper B makes Paper B a two-thesis paper.
- **Venue tier**: ACT (Applied Category Theory), MFPS, LICS short paper, LMCS.
- **Risk**: medium-low. Identification is clean; categorical machinery is established (Spivak Poly, dependent optics, Galois connections, Kan extensions); novelty is the synthesis, not invention of new structure.
- **Time-to-submit estimate**: 6–9 months in parallel with A0.
- **Sequencing role**: provides the categorical foundation that A, B, C all cite for their notion of "propagator network."
- **Skeleton**: `paper-drafts/Poly-propagators.md`.

### A — *The Layered Recovery Principle: Stratified Recovery of Non-Monotone Computation on CALM-Safe Substrates*

- **Type**: Theory paper.
- **Headline claim**: Over a propagator network in the sense of [Poly], any non-monotone computation expressible across heterogeneous lattices recovers as a finite stratified composition of CALM-safe monotone fixpoints with controlled non-monotone transitions at stratum boundaries. We exhibit this for six-plus instances and conjecture universality.
- **Instances** (current inventory; expected to grow before submission):
  1. NAF (negation as failure) — NAF-LE
  2. WF (well-founded semantics) — WF-LE
  3. Type system stratified quiescence
  4. Effect system (QTT + session types)
  5. Stratified retraction (S(−1) / Track 7)
  6. Topology-strata (PPN series; dynamic topology changes break CALM, recovered via stratification)
- **Inter-stratum machinery**: LKan / RKan (left and right Kan extensions), Galois bridges between heterogeneous lattices.
- **Honesty caveat (per `2026-03-21_CATEGORICAL_STRUCTURE_FIVE_SYSTEMS`)**: not every instance is a strict opfibration. The contribution is the *recovery principle* with heterogeneous categorical character per instance, not a uniform bifibration claim.
- **Novelty against stratified-Datalog**: stratified-Datalog stratifies *negation* on a fixed Herbrand base. LRP stratifies *general non-monotone computation* across heterogeneous lattices via Galois bridges, with Kan extensions doing the inter-stratum work. Different generalization, not a renaming. To be defended in a novelty-positioning audit before substantive paper work.
- **Venue tier**: POPL, ICFP, OOPSLA, LMCS, JFP.
- **Risk**: medium. Instances are real; novelty against classical stratification needs the positioning audit.
- **Time-to-submit estimate**: 12–18 months.
- **Sequencing role**: establishes the recovery clause that Paper B's universality claim leans on.
- **Skeleton**: `paper-drafts/A-LRP.md`.

### B — *FL(ℵ₀) as a Candidate Universal Substrate for Parallel Computation*

- **Type**: Conceptual / foundational paper.
- **Headline claim (softened, suggestive)**: We propose FL(ℵ₀)+Whitman, with Poly-shaped propagators on lattice-valued cells, as a candidate substrate for parallel computation analogous to UTM's role for sequential computation. We do not claim Church-Turing-thesis-shape equivalence; we develop the analogy as a research programme.
- **Pillars**:
  1. Encoding chain: TM ↪ rewriting (Endrullis–Shallit–Smith 2017) ↪ algebra (Nation–Paolini I/II/III); the lift from rewriting to FL to be developed with Nation.
  2. CALM as a partial demarcation theorem (monotone-coordination-free fragment).
  3. LRP (Paper A) as the recovery clause.
  4. Empirical anchor: Whitman's condition (W) holds 10/10 across independently-built Prologos lattices (per `2026-05-08_PROLOGOS_LATTICE_VARIETY_CATEGORIZATION`); LHC (Paper A0) as the operational witness.
- **Substrate-vs-decider posture**: explicitly addressed in the paper. Substrate = network on the lattice, not the lattice alone. Hewitt-actor-style critiques pre-empted by foregrounding the Poly+FL+propagator-scheduler triple as the substrate object.
- **Venue tier**: LICS, FOCS, JACM, LMCS, ICALP. Also CACM / Bulletin of the EATCS as a perspective piece.
- **Risk**: medium-high. Materially reduced by Nation collaboration, by A0/Poly publishing first, and by the empirical Whitman finding.
- **Time-to-submit estimate**: 18–30 months.
- **Sequencing role**: flagship.
- **Skeleton**: `paper-drafts/B-FL-substrate.md`. Existing prior-art audit at `outputs/free-lattice-utm-parallel.md` is the floor.

### C — *Variety-Stratified Optimality: Per-Variety Hasse Decomposition as Optimal Parallel Schedule*

- **Type**: Theory paper.
- **Headline claim**: For lattice variety V, the Hasse diagram of a finitely-presented sub-lattice in V is the optimal parallel decomposition under V's natural cost model.
- **Instances**:
  1. Boolean / hypercube — theorem (cite source via PTF notes).
  2. Distributive — theorem (Garg lattice-linear predicate detection).
  3. SD / modular / FL — conjecture; binder-boundary phenomenon (per `2026-05-08_PROLOGOS_LATTICE_VARIETY_CATEGORIZATION`) is the natural counterexample / boundary case to study.
- **Empirical anchor**: SRE Track 2I lattice categorization (per `2026-05-08_PROLOGOS_LATTICE_VARIETY_CATEGORIZATION` and `2026-04-30_LATTICE_HIERARCHY_AND_DISTRIBUTIVITY_FOR_PROPAGATORS`).
- **Venue tier**: LICS, LMCS, or PTF-orbit theory venue.
- **Risk**: medium. Optimality results require a precise cost model; Boolean/distributive instances likely already-published theorems to be re-cited under the unified framing.
- **Time-to-submit estimate**: skeleton now, 18–24 months to submission.
- **Sequencing role**: parallel to A; potentially leverages back into B's "this is the right substrate" claim.
- **Skeleton**: `paper-drafts/C-variety-optimality.md`.

### Future / probable

- **NTT paper** — once NTT is implemented in core Prologos as a user-facing language feature (currently design-only; case-study-validated). Likely a dependent-types-for-propagator-networks paper.
- **Phase Collapse standalone** — if the phase-collapse claim grows beyond what A0 can carry, it deserves its own conceptual paper. Decision point: after A0 draft.

---

## 3. Engineering ↔ research vectors

This section is the contract between the LHC engineering effort and the academic publication effort. Both directions require explicit instrumentation, not goodwill.

### Engineering → research

- Each PIR (post-implementation review) in `docs/tracking/` is tagged for paper relevance. If a PIR contains a finding that should land in Paper A/B/C, the finding is mirrored into `outputs/` as a frozen snapshot with a back-reference to the PIR.
- Compiler measurements that anchor papers are *frozen at named versions* in `engineering-anchors.md`. Drift is logged.
- The `.pnet` artifact is treated as a publishable research artifact and versioned accordingly.

### Research → engineering

- Research-feeding-engineering notes live under `outputs/syntheses/` and are linked from the relevant track's design doc.
- When a deep-research pass surfaces a primitive, lemma, or algorithm the compiler should adopt, it surfaces as a track entry in `MASTER_ROADMAP.org` or `DEFERRED.md`.
- Active consumption priorities (as of opening this charter):
  - **PReduce** — already substantially research-fed; remaining synthesis work tracked in `2026-05-02_PREDUCE_MASTER.md` sub-deliverables 0.1/0.2/0.3.
  - **e-graphs / egg / egglog** — already covered in `2026-05-02_E_GRAPHS_RESEARCH.md`.
  - **Tropical quantales** — already covered in `2026-04-21_TROPICAL_QUANTALE_RESEARCH.md`.
  - Future: superoptimization techniques, GPU/distributed BSP scheduling, incremental-LSP integration on the network.

---

## 4. Working method

The programme inherits the workflow that produced the FL+UTM priority audit:

- **`progress.md`** — current investigation only; resets per investigation.
- **`outputs/<slug>.md`** — one canonical artifact per investigation, with a `.provenance.md` sibling.
- **`outputs/.drafts/`** — researcher-pass drafts; lead synthesis from these.
- **Multi-round structure**: priority audits run as parallel researcher subagents → reviewer pass → revised final.
- **PDF claims** — `document_parse` + `grep` mechanical confirmation before any "absent in source" verdict.
- **Workaround note**: `alpha_ask_paper` returned schema errors throughout the round-2 audit. Default to `fetch_content` for HTML and `document_parse` for local PDFs until verified otherwise.

---

## 5. Programme-level open questions

Maintained in `open-questions.md`. Examples currently live there:

- Q1: Does the recursive-on-outermost-operator merge shape *prove* Whitman's condition, or merely correlate with it empirically? (Anchors Paper B's Whitman pillar.)
- Q2: What is the precise novelty boundary for LRP against classical stratified-semantics literature? (Gates Paper A.)
- Q3: How to formalize the substrate-vs-decider distinction so reviewers don't read FL-as-UTM as a category error? (Gates Paper B.)
- Q4: Is Paper C's "natural cost model per variety" canonical, or does it require per-variety design choices that weaken the optimality claim? (Gates Paper C.)

Full list and migrations into investigations: `open-questions.md`.

---

## 6. Programme cadence

- **Weekly**: Nation conversation; capture algebraic guidance into `bibliography.md` and `open-questions.md`.
- **Per investigation**: `progress.md` ledger; final artifact + provenance into `outputs/`.
- **Monthly**: arXiv re-scan for FL / Whitman / propagator / CALM / monotone / lattice-linear / LVar terms. Logged in `prior-art-watch.md`.
- **Quarterly**: stratified-semantics scan for new NAF/WF/perfect-model work; lattice-variety re-scan.
- **Per major engineering milestone**: PIR-relevance tag pass; freeze any measurement that a paper depends on.
- **Programme-level lab notebook**: `CHANGELOG.md` — append-only.

---

## 7. Decisions registered

- **2026-05-08**: Programme opened. Core thesis tree fixed at four levels + optimality axis. Five-paper plan adopted: A0 → Poly → A → B → C. Paper B framing softened from "is" to "candidate / analogy / research programme." Paper C skeletoned now (was: deferred 24mo).
- **2026-05-08**: NTT positioned as A0 section + future standalone paper (post-implementation in core Prologos).
- **2026-05-08**: Phase-collapse positioned as A0 headline claim; standalone-paper option deferred to post-A0-draft decision point.
- **2026-05-08**: Engineering anchor for Paper B Whitman pillar fixed at `2026-05-08_PROLOGOS_LATTICE_VARIETY_CATEGORIZATION` 10/10 finding.

---

## 8. Things this charter is not

- **Not a publication schedule**. Estimates are estimates.
- **Not a contract with venues**. Venue tiers reflect ambition; final submission targets are per-paper decisions.
- **Not a freeze on instances or pillars**. Paper A's instance set in particular is expected to grow as PPN series progresses.
- **Not authorship**. Co-authorship with J. B. Nation (Papers B/C particularly) is open and to be discussed as papers approach submission.

---

## 9. Internal research notes (programme pattern)

**Pattern recognition (2026-05-08)**: the Prologos project has been doing internal research notes that feed engineering for a long time — 100+ files in `docs/research/`. The substrate has no engineering precedence to copy; outside mathematics has to be synthesized into actionable engineering guidance. This pattern is now formalized inside the programme.

### Convention

- **`outputs/*-internal-research.md`** — internal research notes feeding engineering directly. Co-evolve with engineering. Stay in `outputs/` indefinitely. Some never become external papers; some do.
- **`outputs/*-audit.md`** — priority-claim audits, novelty positioning passes (defensive). One-shot artifacts.
- **`outputs/*-synthesis.md`** — external-literature synthesis (offensive). One-shot or evolving.
- **`paper-drafts/*.md`** — external-facing manuscripts only. When an internal note is reworked for publication, the rework happens here with a back-reference to the internal note.

### Why this matters for the programme

- **Not every internal research note needs an external counterpart.** Many die as design references; that's correct.
- **Some internal notes spawn multiple external papers.** A foundational note can serve A0, B, and C simultaneously.
- **The internal note is the working memory.** External papers distill; internal notes evolve.
- **Future sessions need to know the difference.** Mistaking an internal note for a paper draft (or vice versa) leads to bad rewrites.

### Inaugural example

`outputs/poly-as-propagator-internal-research.md` — the Poly internal research note. Companion external paper at `paper-drafts/Poly-propagators.md`. The internal note holds working categorical identifications, engineering questions Q-EP1–Q-EP5+, external-mathematics-synthesis status, and engineering-feedback log. The external paper distills the polished result.

### Pre-existing precedent (broader project)

The broader `docs/research/` directory is a 100+ document corpus of internal research notes feeding the LHC engineering effort. Many of those documents are direct precedents for the pattern formalized here. Examples directly relevant to the utm-fl programme:

- `2026-03-22_CATEGORICAL_FOUNDATIONS_TYPED_PROPAGATOR_NETWORKS.md` — categorical foundations for typed networks; feeds NTT.
- `2026-03-13_LAYERED_RECOVERY_CATEGORICAL_ANALYSIS.md` — categorical analysis of layered recovery; Paper A starting material.
- `2026-03-21_CATEGORICAL_STRUCTURE_FIVE_SYSTEMS.md` — honest per-instance categorical assessment; Paper A.
- `2026-04-30_LATTICE_HIERARCHY_AND_DISTRIBUTIVITY_FOR_PROPAGATORS.md` — operational catalog per variety; Paper C.
- `2026-05-08_PROLOGOS_LATTICE_VARIETY_CATEGORIZATION.md` — empirical Whitman 10/10 + binder boundary; Papers B and C.
- `2026-04-21_TROPICAL_QUANTALE_RESEARCH.md` — tropical-quantale foundations; PReduce.
- `2026-05-02_E_GRAPHS_RESEARCH.md` — e-graph synthesis; PReduce.

The utm-fl programme inherits this corpus as its broader bibliographic + design context.
