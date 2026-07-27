# PReduce Engineering Inputs from Substrate Research

**Status**: distilled engineering memo derived from `outputs/preduce-adhesive-rewriting-substrate-internal-research.md`. Date: 2026-05-09.

**Purpose**: turn the spine findings (C1–C4 + the C1.alt detour + ATMS/registry considerations) into concrete inputs PReduce track designers can consume directly, without reading 838 lines of theoretical work. Pointers back to the internal-research note are given per claim for justification.

**What this memo is**: per-track concrete inputs; PReduce-master / Track-0.1 open-question dispositions; new external references; pending NAC requirement; load-bearing engineering claims with falsification targets.

**What this memo is not**: a literature review, a paper draft, or a replacement for the internal-research note. The theoretical grounding lives in `preduce-adhesive-rewriting-substrate-internal-research.md` (henceforth "the *internal note*").

**Consumers**: Track 0.1 sketch revision; Tracks 1, 2, 3, 4, 5, 6, 9 design work; Logic Engine backward-chaining alignment (C3.e merge target).

---

## §1 Headline shifts (the four things that changed)

1. **Categorical frame: semilattice-enriched SMC, not Biondo M-adhesive.** Tiurin-Barrett-Ghica-Hu *Equivalence Hypergraphs: DPO Rewriting for Monoidal E-Graphs* (LICS 2025, arXiv:2406.15882; henceforth **TBGH**). Substrate fit is direct: our lattice-valued cells **are** the semilattices the enrichment requires. (Internal note §2.C1 + §2.C1.alt.)

2. **CALM-adhesive correspondence: structural identity at the enrichment level.** BloomL's three monotone-merge axioms (commutative, associative, idempotent) ARE TBGH's first three enrichment axioms verbatim; TBGH's four distributivity axioms lift the lattice-level BloomL claim to morphism level. S0 / S(−1) decomposition gets a categorical witness: S0 = semilattice-enriched fragment; S(−1) = ATMS-worldview-parameterized commutative-monoid-without-idempotence enrichment. (Internal note §2.C2.)

3. **E-graph quotient structure = TBGH Theorem 6.5.** `SMT⁺(Σ, E) ≃ MEHypI(Σ)/S, E` IS the quotient module construction made categorical. Russo 2010 Q-module theory supplies the **residuation API** at signature level. **Track 0.1 §7.7 (residual operator API) resolved.** (Internal note §2.C3.)

4. **Runtime story is automatic: GoI execution formula = Kleene star in traced enriched SMC.** Run-to-quiescence on the propagator network IS the GoI machine, structurally. **Phase-collapse (Paper A0 H2) gets a categorical witness candidate** (C4.f): the same Kleene-star/trace operator fires on different cell contents at "compile time" and "run time." (Internal note §2.C4.)

---

## §2 Per-track inputs

### Track 0.1 — Architectural sketch (revision required)

**What changes**:

- **§10.4 external lit references**: replace flat "Biondo-Castelnovo-Gadducci CALCO 2025" reference with **primary citation TBGH LICS 2025 (arXiv:2406.15882)**. Biondo et al. remains as a comparison point (Candidate A in §2.C1.alt of the internal note). Soften the "all the adhesive theorems transfer" paraphrase per the internal note's C1 drift log.
- **§7.7 (residual operator API)**: RESOLVED at signature level — see Track 4 entry below.
- **§2 (e-class cell NTT declaration)**: extend from `:lattice :structural :order :refinement` to `:lattice :structural :enrichment :semilattice` (with `:Q-module` when cost is in scope). The merge function IS the semilattice join `+`; e-class membership IS the join's existence.
- **§5 (rule-property axis)**: reframe as *enrichment-preserving-or-not* tags. See Track 0.2 entry.

**What this memo recommends adding to §10**:

- §10.5 (new): "Engineering implications under the GBT frame" — point to this memo as the canonical engineering-input artifact.

### Track 0.2 — Rule-property taxonomy

**Reframe the axis**: rule properties become **enrichment-preserving-or-not** tags rather than independent per-property tags.

| Rule property tag | Enrichment characterization | Stratum | Parallelism |
|---|---|---|---|
| **IN-fragment** | Lives in the non-enriched fragment (no `+` in hom-sets unless e-class'd) | S0 | Lévy-optimal sharing (conjecturally HVM2-style; see Track 2 below) |
| **Adhesive-DPO** | In the enriched fragment; preserves `+` via the four distributivity axioms (TBGH Def 2.5) | S0 | DPOI confluence; decidable for terminating systems (Bonchi et al. III, MSCS 2022) |
| **Confluence-by-construction** | Doesn't create new joins (no critical pairs) | S0 | Trivial parallelism |
| **Non-monotone / retraction-eligible** | Breaks idempotence; lives in ATMS-worldview-parameterized commutative-monoid-without-idempotence enrichment | S(−1) | Sequential within stratum; parallel across worldviews |
| **Opaque (FFI + effects)** | Uninterpretable; routes through effect-stratum boundary | (effect stratum) | Scheduler-determined |

**NEW requirement (load-bearing)**: rule format must support **NACs (Negative Application Conditions)** from day one. Per Biondo et al. §6 / Ehrig-Golas-Habel-Lambers-Orejas 2012, 2014 (NAC theory for M-adhesive, equally applicable to enriched setting). Without NACs, expansive rules (e.g., `x → (+ x 0)`) don't terminate.

**Concrete deliverable**: rule-property table per the above + analysis of which Prologos reduction kinds qualify for each tag. Cite C2 + §2.C2 of the internal note for the categorical justification. The NAC requirement should be a first-class field in the rule schema.

### Track 0.3 — `.pnet` extension + LLVM lowering interface

**Cell schema**: include the **enrichment annotation** as a first-class field (`:semilattice` for S0; `:commutative-monoid` for S(−1); `:Q-module` with quantale identifier for cost-bearing cells).

**Rule registry serialization** (cells holding rule data):
- Rule property tags (per Track 0.2)
- NAC specifications (per the new requirement above)
- Worldview-bitmask tag for retraction-eligible-regime entries (per Track 5 entry + §3.S5 stub in the internal note)

**E-class registry serialization** (per Track 5 entry below): content-hash + cost-criterion + chosen-extraction. Separate sub-schema for the cache; content-addressed key generation.

**Substrate-call boundary** (collaborator's LLVM lowering): the cell schema's enrichment annotation should be visible to the lowering layer; it determines parallelism strategy (IN-fragment ↔ HVM2-style massive parallelism; adhesive-DPO ↔ DPOI critical-pair-aware scheduling).

### Track 1 — E-class cell substrate

**NTT declaration**:
```
:lattice :structural :enrichment :semilattice
                                 [:Q-module Q when cost quantale Q is in scope]
```

Components:
- **Merge function**: the semilattice join `+` (commutative, associative, idempotent — verbatim BloomL axioms, verbatim TBGH enrichment axioms).
- **E-class membership**: existence of the join. Two terms `f`, `g` are in the same e-class iff `f + g` is well-defined and equals the e-class representative.
- **Hashcons + union-find**: realized as cell-id assignment (structural hash determines cell-id) + union-merge (e-class merge updates union-find roots monotonically). Categorical content: this IS the quotient functor π : C → C/S, E.

**Gates on**: PPN 4C Phase 1B (tropical-fuel substrate, prerequisite for Q-module action when cost is in scope).

**Resolves**: PReduce Master open Q2 partially (e-class merge under partial information — the enrichment axioms say merge is monotonic + order-independent, but immediate-vs-wait is still a scheduling choice).

### Track 2 — β-reduction (IN-fragment)

**Unchanged by the spine work**: IN-fragment confluence (Lafont 1990, 1997) does not route through M-adhesive theory or even through enrichment. The strong-confluence-by-binary-principal-port argument is independent and survives intact.

**NEW**:
- **Benchmark target: HVM2** (HigherOrderCO/HVM2). Production interaction-combinator runtime; 74,000 MIPS on RTX 4090 (single-thread 400 MIPS on M3 Max). Per C4.e (speculative bridging in the internal note), the IN-fragment of our enriched SMC inherits HVM2-style massive parallelism + Lévy-optimal sharing — **the empirical implementation here is the test**.
- **Lévy-optimal sharing**: shared subterm reduces at most once. Architecturally inherited via e-class cell union-find; HVM2's "lazy clone primitive" is the equivalent of our cell-id sharing.

**Track 2 design should target HVM2 performance characteristics on the IN-fragment as the upper bound; gap below HVM2 is engineering opportunity.**

### Track 3 — ι-reduction (DPO + critical pairs)

**Moved from the open M-adhesive frontier to the CLOSED EDPOI framework.**

Key consequence:
- **Bonchi-Gadducci-Kissinger-Sobociński-Zanasi III** *String diagram rewrite theory III* (MSCS 2022): **DPOI confluence is decidable for terminating systems.** Directly applicable algorithm for our setting.
- **Critical-pair analysis specializes**: critical pairs ARE the locations where the join `+` doesn't extend uniquely (C2.e structural conjecture). The EDPOI boundary complement (TBGH Def 5.2) operationally identifies these.
- **NAC support is required** for ι-rules with overlapping patterns; see Track 0.2 requirement above.

**Resolves**: the Track 3 path-call question from §2.C1's engineering implications — under GBT, ι-reduction sits in the closed framework, not the active-research M-adhesive frontier. The Baldan et al. CONCUR 2024 "left-linear M-adhesive" path is now an alternative, not the primary route.

### Track 4 — Cost-guided extraction

**Residual operator API (resolves Track 0.1 §7.7)**:

```
\_Q : Q × M → M     where M = C(A, B) hom-sets in the semilattice-enriched SMC

(equivalently, against the cost criterion:)
extract : C(A, B) × Q → C(A, B)
extract(eclass, costCriterion) := costCriterion \ eclass
```

The signature characterization (Russo 2010 §3): for any Q-module morphism `f : M → N`, the residual `f*` is the unique right adjoint, characterized by `f(a) ≤ b ⇔ a ≤ f*(b)`. For extraction, this means: given a target e-class and a cost criterion, the residual finds the cost-optimal section of the quotient map.

**Implementation paths**:
- **Tropical (1-dim)**: PPN 4C Phase 1B already ships `tropical-left-residual`. Track 4's 1-dim extraction = consume directly.
- **Multi-dim (Candidate D extension)**: cost quantale is `Q₁ ⊗ Q₂ ⊗ ...` (product / tensor); per-Q algorithm depends on the composite shape (S1 commitment in §3 of the internal note).

**Concrete algorithms by Q shape**:
- **Confluent rules + tropical Q**: greedy via DP on the e-class poset. egg's `AstSize` / `AstDepth` cost functions are concrete instances; cite Rust docs at `docs.rs/egg`.
- **Non-confluent rules + tropical Q**: ILP / heuristic / Pareto-frontier.
- **Multi-dim Q (product)**: per-component greedy; combine via Pareto-front for non-dominated solutions.
- **Multi-dim Q (tensor)**: scalarized via tensor combinator; single-objective extraction with the combined cost.
- **Multi-dim Q (lex)**: priority ordering; greedy at each priority level.

**Kleene-star algorithms transfer wholesale** (from `2026-04-21_TROPICAL_QUANTALE_RESEARCH.md` §2.5 + §9.6): Floyd-Warshall, Bellman-Ford, Dijkstra are all Kleene-star instances in different semirings. For PReduce: fuel-cost propagation, all-pairs reduction-cost computation, critical-path analysis. NICTA 2009 (Beckert-Lange) has the Isabelle/HOL formalization — direct verification target for the future self-hosted proof-aware compilation.

**C3.e — load-bearing engineering claim**: the **same residuation operator** implements both cost-guided extraction (against the cost-Q-module) and Logic Engine backward-chaining (against the propagator-Q-module). Signature is identical; only the (Q, M) instantiation differs.

**Falsification target for C3.e**: find a concrete operation that is semantically backward-chaining but doesn't fit the `\_Q : Q × M → M` signature. If none surfaces in implementation, the merge target is real.

### Track 5 — Persistence

**Owner-registered refinement (2026-05-09)**: the load-bearing object is the **persistent registry of optimal rewrites**, not just the persistent e-graph. Schlatt 2026 covers the e-graph layer; the registry of cost-extraction results is our specific contribution.

**Schema**:

| Field | Content |
|---|---|
| Cache key | `(source-e-class-content-hash, cost-criterion-id, worldview-bitmask?)` |
| Cache value | Chosen extraction (cost-optimal residuation output) |
| Regime tag | `ground` / `contextual` / `retraction-eligible` / `opaque` (PReduce Master Axis 2) |
| Content-addressing | CHAMP-derived structural hash of the input e-class (or residuated module under Candidate D) |
| Worldview tag | Optional ATMS assumption-bitmask for retraction-eligible entries (Track 6 integration) |

**Why richer than Schlatt 2026**: Schlatt persists the *residuation domain* (e-graph); this registry persists the *residuation results* (cost-optimal choices) keyed by the residuation problem. Content-addressed by the question, not by the solution-space.

**Cross-references**:
- Schlatt 2026 ([arXiv:2602.16707](https://arxiv.org/abs/2602.16707)) for the e-graph persistence layer.
- IPVM content-addressed computation pattern for the addressing scheme.
- egg persistence work (referenced in TBGH §1.5).
- Koehler-Trinder-Steuwer 2022 "Sketch-guided equality saturation" (TBGH §1.5) for LLM-guided extraction strategies.

**Publishable design point candidate**: the registry's key/value/regime structure is externalizable for the broader Paper A0 (LHC system) or Paper Poly story.

### Track 6 — Speculative reduction (cost-bounded ATMS branching)

**ATMS supplies the S(−1) coordination protocol** (per §2.C2 retraction subsection in the internal note).

| Component | Engineering site | Role |
|---|---|---|
| ATMS assumption labels | Logic Engine (existing) | Per-derivation worldview tagging |
| BSP-LE 2B hypercube | BSP-LE existing | Data structure for parallel branch maintenance |
| GBT enrichment specialization | This memo | Categorical content of each worldview |
| Tropical-quantale residuation | PPN 4C Phase 1B existing | Cost-bounded pruning across worldviews |
| Reconvergence | New, Track 6 | Limit of worldview-parameterized enrichment back to S0 |

**Operational picture**:
- Each ATMS branch = one enrichment specialization (one specific set of maintained assumptions).
- Parallel exploration of branches = parallel maintenance of competing enrichment specializations.
- Cost-bounded pruning of branches = tropical-quantale residuation across worldviews (the residual selects the lowest-cost-residual worldview; high-cost worldviews are pruned).
- Reconvergence (when multiple worldviews collapse to the same e-class) = the *limit* of the worldview-parameterized enrichment family back to the unparameterized semilattice S0.

**Open questions registered for §3.S6 in the internal note** (engineering does not block):
- (S6-Q1) ATMS label discipline lifts cleanly to enrichment-parameterization, or do we need a quasi-enrichment notion?
- (S6-Q2) Relation to **colored e-graphs** (Singher-Itzhaky 2023, conditional rewriting; cited in TBGH §1.5). Direct comparison target.
- (S6-Q3) Speculative-evaluation cost budget composition with multi-dim cost (S1 commitment).
- (S6-Q4) Track 9 (NTT-typed rules) constraining the ATMS branch space.

### Track 9 — NTT-typed rules (forward-compatibility)

**Cartesian vs general-monoidal distinction matters**: TBGH's full equivalence theorem (Thm 6.5) is for symmetric monoidal categories, not just Cartesian. The Cartesian case is standard term-rewriting with unrestricted copy/delete. The monoidal case handles **linear / affine types**.

**Prologos's QTT (Quantitative Type Theory) multiplicity discipline** pushes us into the non-Cartesian monoidal setting once e-class rewriting integrates with QTT. The GBT generalization isn't optional decoration — it's the right level for our substrate's eventual maturity.

**Engineering hook**: NTT property declarations become enrichment declarations. The rule property axis (per Track 0.2) extends with `:linear` / `:affine` / `:unrestricted` multiplicities that constrain the SMC structure (Cartesian if all unrestricted; otherwise general monoidal).

**Bindings** (lambda-style binders): **Moss-Tiurin 2025** *E-Graphs With Bindings* ([arXiv:2505.00807](https://arxiv.org/abs/2505.00807)) extends TBGH to closed symmetric monoidal categories. **Same framework, not separate work.** Track 9's NTT-typed rules + binders are in scope under the same enrichment paradigm.

---

## §3 PReduce Master open-question dispositions

Cross-referencing the PReduce Master's 12 open questions:

| Question | Disposition |
|---|---|
| Q1 (granularity) | Unchanged |
| Q2 (e-class cell merge under partial information) | Partially clarified: enrichment axioms say merge is monotonic + order-independent; immediate-vs-wait is still a scheduling choice. See Track 1 entry. |
| Q3 (IN-fragment promotion) | Clarified via Track 0.2 reframing. β-reduction is the strongest candidate per C4.e. |
| Q4 (adhesive guarantees for the full PReduce system) | **Superseded**: guarantees come from enrichment, not adhesivity. C2.f resolves the cross-system transfer (SRE Track 2D ↔ PReduce e-class subsystem share enrichment paradigm). |
| Q5 (cost lattice composition: single quantale or product/tensor) | **Math foundation supplied** via Candidate D (quantale-enriched extension); choice of Q remains S1 commitment in the internal note's §3. |
| Q6 (retraction-bit consultation discipline) | **Clarified**: ATMS-worldview-parameterized enrichment IS the protocol; persistent-registry (Track 5) describes consultation via worldview-bitmask. |
| Q7 (effect-stratum boundary protocol) | Unchanged |
| Q8 (Lévy optimality in dependent types) | Conjectural transfer via C4.e (HVM2 connection); see Track 2 entry. Empirical implementation tests. |
| Q9 (NTT-typed rules surface) | Clarified: NTT properties = enrichment properties; bindings handled by Moss-Tiurin 2025. See Track 9 entry. |
| Q10 (reduction.rkt retirement) | Unchanged |
| Q11 (PPN 4D interaction) | Unchanged |
| Q12 (cross-session persistence at scale) | Track 5 stub addresses; registry schema described above. |

**Track 0.1 §7.7 (residual operator API surface)**: **RESOLVED at signature level** via C3.d (`\_Q : Q × M → M`). Concrete algorithms remain per-Q shape; tropical case ships in PPN 4C Phase 1B.

---

## §4 Open structural conjectures (engineering does NOT block on these)

Listed for transparency; falsifiable through implementation discipline.

| Conjecture | Internal note ref | Falsification target |
|---|---|---|
| **C3.e**: One residual API unifies cost-extraction and backward-chaining. | §2.C3 | Find an operation semantically backward-chaining but not fitting `\_Q : Q × M → M`. |
| **C4.d**: Semilattice-enriched SMC supports a full trace operator. | §2.C4 | Explicit construction needed; standard categorical-GoI should adapt. |
| **C4.e**: IN-fragment inherits HVM2-style parallelism + Lévy-optimal sharing. | §2.C4 | Track 2 β-reduction implementation; benchmark vs HVM2. |
| **C4.f**: Phase collapse witnessed by same Kleene-star/trace on different cell contents. | §2.C4 | Load-bearing for Paper A0. Implementation discipline of typing-cell + reduction-cell on the same scheduler. |
| **S6-Q1**: ATMS label discipline lifts cleanly to enrichment-parameterization. | §3.S6 stub | Track 6 implementation; may need quasi-enrichment notion. |

---

## §5 Speculative bridging (durable open directions, not blockers)

Per the substrate-first / theory-after posture (memory `prologos.research_methodology.substrate_first`): these are open frontiers we draw from for engineering guidance; they are NOT pending obligations.

- **Candidate C (polynomial-functor framing)**: PROP⁺ as a polynomial functor over ℕ enriched over semilattices. Aligned with Paper Poly programme. The Poly internal-research note (`outputs/poly-as-propagator-internal-research.md`) extends naturally.
- **Candidate D (quantale-enriched extension)**: load-bearing for multi-dim cost (S1). Kupke et al. STACS 2024 + Forster et al. ICALP 2024 are the closest external precedents (both already in our corpus bibliography but not yet engaged for e-graphs).
- **ATMS-enrichment-parameterization as the formal coordination protocol for S(−1)**: structural fit is clean (each branch = one enrichment specialization); needs explicit categorical formalization.

---

## §6 New external references engineering should know

**Primary categorical frame** (load-bearing):
- **Tiurin, Barrett, Ghica, Hu.** *Equivalence Hypergraphs: DPO Rewriting for Monoidal E-Graphs.* **LICS 2025**, IEEE 209–222. [arXiv:2406.15882](https://arxiv.org/abs/2406.15882). v1 Jun 2024 read end-to-end; v2 May 2025 is the conference version.

**Residuation API** (load-bearing):
- **Russo, C.** *Quantale Modules and their Operators, with Applications.* [arXiv:1002.0968](https://arxiv.org/abs/1002.0968), 2010. Q-module structure + residual maps.

**Rewriting infrastructure**:
- **Bonchi, Gadducci, Kissinger, Sobociński, Zanasi.** *String diagram rewrite theory I / II / III.* JACM 2022 + MSCS 2022 (vols 32(4) and journal). **III contains the decidability-of-DPOI-confluence result** (Track 3 direct algorithm).

**NAC theory** (load-bearing for Track 0.2 / 0.3):
- **Ehrig, Golas, Habel, Lambers, Orejas.** *M-adhesive transformation systems with nested application conditions.* Parts 1+2 (Fund. Inform. 118, 2012 + MSCS 24(4), 2014). Equally applicable to enriched setting.

**Bindings** (Track 9):
- **Moss, Tiurin.** *E-Graphs With Bindings.* [arXiv:2505.00807](https://arxiv.org/abs/2505.00807), 2025. Builds on TBGH.

**Runtime story / GoI / interaction nets**:
- **Joyal, Street, Verity.** *Traced monoidal categories.* MPCPS 119, 1996.
- **Haghverdi, Scott.** *A categorical model for the geometry of interaction.* ICALP 2004 + TCS.
- **Muroya, Ghica.** *The Dynamic Geometry of Interaction Machine: A Call-by-Need Graph Rewriter.* CSL 2017 / LMCS. [arXiv:1703.10027](https://arxiv.org/abs/1703.10027). **Close engineering precedent for Track 6**; same author lineage as TBGH.
- **HVM2** ([github.com/HigherOrderCO/HVM2](https://github.com/HigherOrderCO/HVM2)). Production benchmark for Track 2.

**Algorithmic library transfer**:
- **Beckert, Lange.** *Dijkstra, Floyd, Warshall Meet Kleene.* NICTA 2009. Isabelle/HOL formalization of all-pairs shortest-path as Kleene-star in different semirings — **directly applicable to PReduce's fuel-cost / reduction-cost analyses**.

**Already in corpus, promoted to load-bearing**:
- **Conway-Marczak-Alvaro-Hellerstein-Maier.** *Logic and Lattices for Distributed Programming* (BloomL). SoCC 2012. **The axiomatic bridge between CALM and TBGH enrichment** (per C2).

---

## §7 New requirement: NAC support

**Source**: Biondo et al. §6 (the EGG rule format `x → (+ x 0)` doesn't terminate without NACs); equally applicable to TBGH semilattice-enriched setting; Ehrig-Golas et al. 2012/2014 develop NAC theory for M-adhesive (transfers via standard rewriting machinery).

**Engineering implication**:
- Rule schema (Track 0.2 deliverable; serialized in Track 0.3 .pnet schema) must support **negative application conditions** as first-class structure: a rule has shape `L ← K → R` plus optional `n : L → N` such that match `m : L → G` is admissible only when `m` cannot be factored through `n`.
- Termination of expansive rules depends on this.
- Critical-pair analysis (Track 3) interacts with NACs — Ehrig-Golas Part 2 (2012) covers this.

**This is orthogonal to the choice of categorical frame** (Biondo, TBGH, or other) — NACs are needed in any of them for the EGG-style rule format we want to ship.

---

## §8 Engineering merge target: C3.e

The single most consequential engineering claim from the spine work is **C3.e** (internal note §2.C3):

> **The same residuation operator implementation serves both PReduce cost-guided extraction and the Logic Engine's backward-chaining propagators.**

Signature: `\_Q : Q × M → M` where `M = C(A, B)` hom-sets in the semilattice-enriched SMC.

Concrete implications:
- **PReduce Track 4** consumes the same residual operator that **Logic Engine** already uses for backward-chaining (and that PPN 4C Phase 1B's `tropical-left-residual` ships for the 1-dim case).
- The two subsystems differ only in the (Q, M) instantiation, not in the operator code.
- Refactoring opportunity: identify the existing residuation code paths (PPN 4C Phase 1B + Logic Engine backward-chaining) and unify against the C3.d signature.

**Falsification target**: any operation that's semantically backward-chaining but doesn't fit the signature. If implementation discipline doesn't produce one, the merge target is real and yields code reduction.

---

## §9 Concrete next implementation moves

In suggested order; each item is a self-contained engineering step.

1. **Track 0.1 sketch revision** (~1 day): update §2 (cell NTT declaration), §5 (rule-property axis), §7.7 (residual operator API), §10.4 (lit refs); add §10.5 pointing at this memo. Minor; mechanical.

2. **Track 0.2 rule-property taxonomy** (~1-2 days): produce the table per §2 of this memo with enrichment-preserving-or-not as primary axis. Include NAC field. Cite C2 of internal note for categorical justification.

3. **Track 0.3 `.pnet` schema sketch** (~1 day): cell schema with enrichment annotation; rule registry with NAC + worldview-bitmask; e-class registry sub-schema for Track 5 persistence.

4. **Track 1 e-class cell implementation** (gates on PPN 4C Phase 1B + Track 0.1 revision): implement with new NTT declaration. Hashcons + union-find as cell-id assignment + union-merge.

5. **Residuation API unification** (C3.e merge target): identify Logic Engine backward-chaining + PPN 4C Phase 1B residual code paths; refactor against C3.d signature.

6. **Track 2 β-reduction prototype** (post-Track-1): IN-fragment property tag; benchmark vs HVM2 for performance characterization.

7. **Track 3 ι-reduction critical-pair analysis** (post-Track-1): consume Bonchi III decidability; NAC support for overlapping patterns.

8. **Track 4 multi-dim cost (Candidate D)**: gated on S1 commitment (which Q shape); Russo-structure generalization of the tropical case.

9. **Track 5 persistent registry**: schema per §2 above; consume Schlatt 2026 for e-graph layer; build registry on top.

10. **Track 6 speculative reduction** (post-Track-3): consume BSP-LE 2B hypercube; integrate with ATMS worldview tags; cost-bounded pruning via Q-residuation.

---

## §10 Pending corpus housekeeping (deferred from this memo)

The spine work surfaced corpus drift in several documents. **Not in this memo's scope** — to be handled in a separate corpus-amendment pass (per owner sequencing 2026-05-09). Internal-note drift log (§10) catalogs the specifics:

- `docs/research/2026-05-02_E_GRAPHS_RESEARCH.md` §3.1 — replace flat "adhesive category" with TBGH-cited "T_Σ-adhesive / semilattice-enriched" framing.
- `docs/research/2026-03-24_HYPERGRAPH_REWRITING_PROPAGATOR_PARSING.md` §3.3 — same correction.
- `docs/research/2026-05-02_PREDUCE_TRACK01_ARCHITECTURAL_SKETCH.md` §10.4 — replace Biondo-as-primary with TBGH-as-primary + Biondo-as-comparison.
- `docs/tracking/2026-05-02_PREDUCE_MASTER.md` Cross-series connections — soften "SRE Track 2D adhesive guarantees inherit" claim per C2.f resolution.
- `docs/research/2026-05-02_ARCHITECTURE_NOVELTY_SURVEY.md` — add TBGH foundational reference (currently cites Moss-Tiurin 2025 binding-extension without the foundation).

**Also pending**: linking this memo + the internal-research note into the PReduce series's `Source documents` list in the PReduce Master.

---

## §11 Provenance + maintenance

**This memo is derived from**: `outputs/preduce-adhesive-rewriting-substrate-internal-research.md` (the internal note, 838 lines as of 2026-05-09 session close).

**Maintenance discipline**: when the internal note's §2 grounding or §3 specialization develops further, update this memo's per-track inputs accordingly. Append-only drift log not needed here — the internal note carries the drift log; this memo is a snapshot derived from it.

**Owner approval points**:
- The NAC requirement (§7) is a new first-class requirement for the rule format. Acknowledge before Track 0.2 design opens.
- The C3.e merge target (§8) is the load-bearing engineering claim. Acknowledge before Track 4 design opens.
- The HVM2 benchmark target (Track 2 entry) sets a performance ceiling expectation. Acknowledge before Track 2 design opens.

**For the upcoming corpus-housekeeping pass** (per owner direction): use §10 of this memo + §10 of the internal note as the to-amend checklist.
