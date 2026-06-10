# PReduce (Reduction as Propagators) — Series Master

**Created**: 2026-05-02
**Status**: Stage 0/1 — research synthesis. No implementation tracks active yet; series exists to host upcoming work and capture the trajectory.
**Thesis**: Reduction in Prologos lifts entirely onto the propagator network as e-graph + DPO + tropical-quantale + GoI on the same substrate that hosts parsing, typing, and elaboration. The imperative `reduction.rkt` is retired in its entirety. The substrate IS the IR; rule application IS propagator firing; cost extraction IS quantale residuation; equivalence classes ARE shared cells. PReduce is the algorithmic foundation that lifts the SH series's architectural endpoint from "self-hosted competitive language" to "self-hosted super-optimizing compiler."

**Origin**: PRN Master §2 conjectures (β/δ/ι reduction as DPO rewrite rules, optimization as cost-weighted rewriting, NF-Narrowing as DT-guided rewriting). Track 9 Stage-1 research [`2026-03-21_TRACK9_REDUCTION_AS_PROPAGATORS.md`](2026-03-21_TRACK9_REDUCTION_AS_PROPAGATORS.md) framed the narrow incremental-reduction problem; the vision since enlarged dramatically under SH master, PPN 4C tropical addendum, BSP-LE 2B, and PRN. Series formally opened 2026-05-02 from research-conversation arc on PReduce scoping. Spurred operationally by collaborator running independent LLVM lowering prototypes who needs naive reduction-on-propagators — PReduce delivers the canonical replacement.

**Source documents**:
- [Track 9 Reduction-as-Propagators founding research](2026-03-21_TRACK9_REDUCTION_AS_PROPAGATORS.md) (2026-03-21) — original Stage-1 framing; cell-based memoization with dependency-tracked invalidation. Now superseded by the larger vision but retained as a cross-reference.
- [PRN Master](2026-03-26_PRN_MASTER.md) — theory series; PReduce is one of its application series; PRN findings table tracks confirmation against PReduce track outputs.
- [PPN 4C Tropical Quantale Addendum Design](2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_DESIGN.md) (D.2, 2026-04-26) — ships `tropical-fuel.rkt` Phase 1B substrate; PReduce inherits without recreating. Hard prerequisite for implementation tracks.
- [Tropical Quantale Research](../research/2026-04-21_TROPICAL_QUANTALE_RESEARCH.md) (2026-04-21) — Stage 1 deep research, ~1000 lines, 12 sections; tropical-quantale formal foundations (semirings → quantales → modules → residuation → Lawvere V-categories). Cited extensively for cost-extraction algebra.
- [Tropical Optimization Network Architecture](../research/2026-03-24_TROPICAL_OPTIMIZATION_NETWORK_ARCHITECTURE.md) (2026-03-24) — earlier framing; semiring parsing (Goodman 1999), cost-weighted rewriting, ATMS-guided search, stratification.
- [Hypergraph Rewriting + Propagator Parsing](../research/2026-03-24_HYPERGRAPH_REWRITING_PROPAGATOR_PARSING.md) (2026-03-24) — DPO theory, e-graphs, interaction nets, GoI; comprehensive landscape survey.
- [Adhesive Categories and Parse Trees](../research/2026-04-03_ADHESIVE_CATEGORIES_PARSE_TREES.md) — adhesive-DPO formal foundations; e-graphs are adhesive (Biondo-Castelnovo-Gadducci CALCO 2025).
- [Categorical Foundations of Typed Propagator Networks](../research/2026-03-22_CATEGORICAL_FOUNDATIONS_TYPED_PROPAGATOR_NETWORKS.md) §10 — Lafont interaction nets + Girard GoI grounded against propagator semantics; the GoI execution formula IS the propagator network fixpoint, structural identity, not metaphor.
- [Module Theory on Lattices](../research/2026-03-28_MODULE_THEORY_LATTICES.md) §6 — e-graphs as quotient modules; backward chaining as residuation.
- [Lattice Variety and Canonical Form for SRE](../research/2026-04-30_LATTICE_VARIETY_AND_CANONICAL_FORM_FOR_SRE.md) (2026-04-30) — per-domain canonical form; tightens the optimality story for cost-guided extraction.
- [Hypercube BSP-LE Design Addendum](../research/2026-04-08_HYPERCUBE_BSP_LE_DESIGN_ADDENDUM.md) — Q_n hypercube worldview, Gray-code traversal, bitmask subcube pruning; the speculative-search infrastructure PReduce consumes.
- [Kan Extensions, ATMS, GFP Parsing](../research/2026-03-26_KAN_EXTENSIONS_ATMS_GFP_PARSING.md) — 4-level optimization strategy (ATMS branching + Left Kan partial-info + Right Kan demand + tropical cost); the cost-bounded speculative-exploration pattern.
- [SH Master](2026-04-30_SH_MASTER.md) — self-hosting series; PReduce is its critical cross-series dependency.
- [Propagator Network as Super-Optimizing Compiler](../research/2026-04-30_PROPAGATOR_NETWORK_AS_SUPEROPTIMIZING_COMPILER.md) (2026-04-30) — the architectural-distinctiveness argument; PReduce is the linchpin §5.
- [PReduce Adhesive-Rewriting Substrate — Internal Research Note](../research/utm-fl/outputs/preduce-adhesive-rewriting-substrate-internal-research.md) (2026-05-09) — UTM-FL programme internal-research note grounding PReduce's categorical foundations across four spine claims (C1–C4). Headline shift: **primary categorical frame is Tiurin–Barrett–Ghica–Hu (TBGH) semilattice-enriched SMC** (LICS 2025, arXiv:2406.15882), not Biondo et al. M-adhesive. Resolves several PReduce Master open questions (Q4 superseded, Q5 math foundation, Q6 protocol clarified) and Track 0.1 §7.7 (residual operator API signature). Cross-references throughout this Master need amending; see internal note §10 drift log.
- [PReduce Engineering Inputs from Substrate Research](../research/utm-fl/outputs/preduce-engineering-inputs-from-substrate-research.md) (2026-05-09) — distilled engineering memo derived from the internal note above. Per-track inputs for Tracks 0.1, 0.2, 0.3, 1, 2, 3, 4, 5, 6, 9. **Three owner-approval points flagged**: NAC support as first-class rule requirement (§7); C3.e shared residuation API as merge target with Logic Engine (§8); HVM2 as Track 2 benchmark target. Engineering should consume this memo for immediate Track work; the internal note is the theoretical backing.

**Key insight (2026-05-02)**: The architectural endpoint of PReduce is reduction natively on-network as e-graph + DPO + tropical-quantale + GoI on the **same substrate** that hosts parsing, typing, elaboration, and module loading — not as a separate engine bolted onto the compiler. Three layers compose: per-AST-PU compound regions hold occurrence-state; shared e-class cells hold term-equivalence state with refinement-poset structure; a unified rule registry holds property-tagged rewrite rules dispatched by the propagator scheduler. Two orthogonal axes parameterize the design: the **rule-property axis** (IN-fragment vs adhesive-DPO vs non-monotone) determines stratum + parallelism guarantees; the **persistence-regime axis** (ground vs contextual vs retraction-eligible vs opaque) determines cacheability across sessions. The combination is what makes the SH-series super-optimization story shippable.

**Cross-series connections**:
- **PPN 4C Phase 1B** ([Tropical Quantale Addendum](2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_DESIGN.md)) is the hard substrate prerequisite (CLOSED 2026-05-17; gates Track 1 *implementation*, not Track 0.x design closure) — ships the tropical-fuel substrate: quantale algebra + SRE quantale-property declarations (`tropical-fuel-primitives.rkt` re-exported via `tropical-fuel.rkt`), specialized-cell factory + live fuel/budget cells (`propagator.rkt` + `specialized-cells.rkt`). Wording corrected per 2026-06-10 grounding audit: (i) the planned threshold *propagator* was REPLACED in D.4 by an on-write predicate (no separate propagator); (ii) `tropical-left-residual` is a pure read-time function with zero production consumers today — PReduce inherits the ALGEBRA without recreating it, but the on-network residuation wrapping Track 4 needs is greenfield work, not inheritance; (iii) the monotone-counter fast path is gated to not-under-speculation, so Track 6 (speculative reduction) gets the slow path — Phase 1V ns/cycle numbers do not port.
- **BSP-LE Track 2B** ([PIR](2026-04-16_BSP_LE_TRACK2B_PIR.md)) provides the speculative-search infrastructure: Q_n hypercube worldview, bitmask subcube pruning, Gray-code branch ordering, ATMS nogoods, retraction stratum S(-1). PReduce's cost-bounded speculative reduction consumes this directly.
- **SRE Track 2D** delivered 13 concrete DPO rewrite rules; PReduce extends the rule registry to term reduction, generalizing the SRE form-registry pattern. The Track 2D *adhesive guarantees* (in the strict-adhesive presheaf category) transfer to PReduce's e-class subsystem through *shared semilattice enrichment* per the substrate-research note (C2.f, 2026-05-09), not through shared adhesivity — a unified categorical home rather than a per-theorem audit.
- **PRN Master** is the theory home; PReduce findings contribute back to PRN's Universal Primitives and Confirmed Findings tables. PRN §2 conjectures β/δ/ι-reduction-as-DPO-rules — PReduce Track 2 (first rule kind, β) is the predicted confirmation, consistent with the Track 2 tracker row (Track 1 is the e-class substrate; rule-kind confirmations land in Tracks 2-3). (Locus inconsistency fixed 2026-06-10.)
- **SH Master** is the consumer — PReduce delivers the algorithmic perf foundation that makes self-hosted Prologos competitive at runtime; SH Track 4 (production LLVM substrate) gates on PReduce delivery for the super-optimization claim.
- **NTT** — rewrite rules will eventually carry NTT type annotations; rule-property declarations are NTT property declarations. Forward-compatible-with but not gated-on NTT formalization.

---

## Progress Tracker

| Track | Description | Status | Design | PIR | Notes |
|-------|------------|--------|--------|-----|-------|
| 0 | Series founding research synthesis (this master + three sub-deliverables) | ✅ | This document | — | **CLOSED 2026-06-10** — all three sub-deliverables closed (0.1 D.1, 0.2 D.2, 0.3 D.3). Implementation tracks unblocked. |
| 0.1 | Architectural design — six sub-models + coarse NTT model + correspondence table | ✅ | [D.1](2026-06-10_PREDUCE_TRACK01_DESIGN.md) | — | **CLOSED 2026-06-10**: SM1-SM6 locked through six panel rounds + owner co-design; NTT exit gate PASSED (D.1 §8.4). Resolved: granularity (per-position×facet, adopted), rule-registry unification (universe cell, two-tier), e-class realization (product cell, merge-IS-order), effect boundary (F-A/F-B soundness floor + guard), persistence regimes (Axis-2 product re-spec). |
| 0.2 | Rule-property taxonomy — 10-kind table + promotion analysis + Track-N partition | ✅ | [D.2](2026-06-10_PREDUCE_TRACK0.2_RULE_TAXONOMY.md) | — | **CLOSED 2026-06-10.** Partition: Track 2 = IN-ladder (guard Phase 0 → arithmetic seed → δ → guarded β; structural exit criterion bound); Track 3 = ι/DPO. HVM2 posture deferred WITH guard (Track 2 design opens with it). Census: 461 whnf arms / 235 heads. |
| 0.3 | `.pnet` extension + LLVM lowering interface | ✅ | [D.3](2026-06-10_PREDUCE_TRACK0.3_PNET_LOWERING.md) | — | **CLOSED 2026-06-10.** PCE/1 identity package signed off (canonical encoding + sha256; D3 rulings; key-space closed incl. rule-set-digest); .pnet/2 tagged-section container; boundary payload tier 2′ (cell-record frozen = the SH Track 1 joint seam; propagator-record reserved). Owner ruling: the Zig PoC is a separate lowering experiment, NOT a consumer; golden vectors = sole conformance artifact until a real consumer exists. |
| 1 | E-class cell substrate — cell type + hashcons + union-find on cells | ⬜ | — | — | Analog of SRE Track 0 (form-registry substrate). Gates on PPN 4C Phase 1B + Track 0.1 closure. The first real implementation work. |
| 2 | IN-fragment rule track — interior LADDERED per D.2 §5 (2026-06-10): Phase 0 effect-safety guard (BLOCKING) → arithmetic seed (~12-20 ops) → δ → guarded β | ⬜ | — | — | EXIT CRITERION (owner-bound): not done until the guard passes AND guarded β fires AND PRN §2 confirmation recorded. Design doc MUST open with the HVM2 benchmark-posture decision (deferred 2026-06-10 with this guard). |
| 3 | First adhesive-DPO rule kind: ι (dual-Nat-rep pairs + user expr-reduce) | ⬜ | — | — | Critical pairs resolve by lattice JOIN (SM4 F4). OPENS with the blocking implicit-NAC verification (D.2 §4) — only then does the pattern-completion-vs-nac-spec choice exist. |
| 4 | Cost-guided extraction — tropical-quantale residuation on e-class poset | ⬜ | — | — | Consumes PPN 4C Phase 1B residuation operator. Module Theory §6 e-graphs-as-quotient-modules realized. |
| 5 | Persistence — content-addressed e-class storage + `.pnet` round-trip + cross-session loading | ⬜ | — | — | Merckx et al. 2026 realized on our substrate. Implements D.3's frozen spec: PCE/1 encoder + golden vectors, .pnet/2 migration (one-time cold rebuild), question sidecar + epoch GC, serialize-time projection; per-module e-class sections gated on D5 cache-hit data (the rewrites registry earns its keep first). |
| 6 | Speculative reduction — cost-bounded ATMS branching for non-confluent rule cases | ⬜ | — | — | Consumes BSP-LE 2B hypercube infrastructure. The "4-level optimization strategy" (ATMS + Left Kan + Right Kan + tropical) realized for reduction. |
| 7 | Effect-stratum boundary protocol — opaque cells for FFI + capability-typed effects | ⬜ | — | — | PReduce respects effect-stratum boundary; doesn't try to subsume opaque-evaluation. Architecture AD's Stratum 3 is the existing pattern. |
| 8 | `reduction.rkt` parity + retirement — multi-track endgame | ⬜ | — | — | Per `workflow.md` "validated ≠ deployed" discipline: parity with `reduction.rkt` validated → new substrate as production default → `reduction.rkt` retirement as its own track after baking. |
| 9 | User-facility forward-compatibility validation (out of scope for current implementation; in scope for design) | ⬜ | — | — | Confirms NTT-typed rewrite rules + rule-registry round-trip + property-declaration surface form would work without re-architecting. Not shipped; validated. |

---

## Architecture: The Three-Layer Decomposition

(Per adversarial-round-refined design from the founding conversation, 2026-05-02. Detailed in Track 0.1.)

### Layer 1 — Per-AST-PU compound regions

**Amended 2026-06-10 per Track 0.1 SM1 lock ([D.1 §4](2026-06-10_PREDUCE_TRACK01_DESIGN.md))** — realization-or-pivot: the "AST is one Pocket Universe / M-type in one cell / 5 PUs" framing is retired as design-lore (verified: the parse tree IS the M-type — parse-tree-node, parse-reader.rkt:1104-1114 — but no AST-topology-as-one-cell exists; "PU" in code is the pattern: one compound cell, components indexed by alternatives). Layer 1's realization: per-node occurrence-state (`:eclass-link`, `:reduction-status`, `:cost-in-context`, `:reduction-provenance`) lives as new FACETS of the production typed attribute map (the persistent compound cell, positions = expr identity, per-(position × facet) components, two-level pointwise merge) — the proven per-AST compound region, extended.

Component values reference Layer 2 by **content-address KEY** (never cell-id, never canonical NAME — D3 three-key separation). Multiple syntactic occurrences of the same term share the same e-class through the shared KEY, preserving Lévy-optimal sharing. The attribute map is SESSION-persistent only; cross-session persistence is Layer 2 / `.pnet` business (Track 5 / SM6).

### Layer 2 — Shared e-class cells

One cell per term-equivalence class. **Amended 2026-06-10 per Track 0.1 SM2 lock ([D.1 §2](2026-06-10_PREDUCE_TRACK01_DESIGN.md))**: the cell value is a componentwise-ACI product `{best: (Q-cost × form) argmin | alts: e-node set-union | canonical: min-join over allocation-order | provenance: monotone}` on a join-semilattice where **merge IS the order** (matching sre-core.rkt's design note exactly). NTT declaration: `:lattice :structural :enrichment :semilattice [:Q-module Q]` — Q-POLYMORPHIC per owner D7 (2026-06-10 S1 commitment; tropical is the first instance); this realizes the engineering memo's 2026-05-09 pivot and supersedes the original `:order :refinement` declaration, which had no substrate realization.

Three keys are SEPARATE by decision D3 (resolving a verified circularity — "cell-id = structural hash of canonical representative" is circular once classes merge): union-find canonical NAME (allocation-order id), cost-best FORM (per-Q argmin), content-address KEY (structural hash; hashcons + `.pnet`). Extraction's operational graph is the e-node child-DAG walked by Track-4 cost propagators between cells; per the 2026-06-02 sweep correction, residuation supplies cost-PROVENANCE — it is not an NP-escaping DAG extractor. Congruence closure is S0 signature-set watchers (structurally emergent at the quiescent fixpoint), and the eager-vs-saturate regime is a per-rule write-target datum, not a cell-shape commitment.

### Layer 3 — Unified rule registry + property-tagged rules

One CHAMP cell from rule-id → rule-data, generalizing the SRE form registry. SRE's `prop:ctor-desc-tag` becomes a *property* on a rule, not a separate registry. PRN §3 "rule registration as universal primitive" realized: the registry hosts structural-decomposition rules (formerly SRE-only) AND term-rewriting rules (PReduce contribution).

Rules carry **property-tag declarations** (Axis 1 below). **Amended 2026-06-10 per Track 0.1 SM4 lock ([D.1 §5](2026-06-10_PREDUCE_TRACK01_DESIGN.md))**: the rule-DISPATCH strata are two — **S0** (monotone rewriting: IN-fragment + adhesive-DPO + structural-decomposition, broadcast-over-rules with property tags routing the write-target) and **S(-1)** (retraction: the unified `process-retraction` value-tier handler; lineage PM Track 7 → PPN 4C 2B 2026-05-20). Everything else PReduce uses is tier-ordered handler INSTANCES of existing kinds (`#:tier 'value` / `#:tier 'topology`) plus the CELL layer (fuel exhaustion via on-write-check). **PReduce introduces ZERO new stratum/tier kinds** — exhibited, computation by computation, in the D.1 §5.1 assignment table, which together with `.claude/rules/stratification.md` is the NORMATIVE home for stratum semantics (this section is deliberately just the claim + pointer).

Effect-aware reduction respects the existing effect-stratum boundary (Architecture AD Stratum 3) — opaque cells are uninterpretable to PReduce's rewriting layer.

---

## Two Orthogonal Axes

### Axis 1: Rule-property axis (determines stratum + parallelism)

| Rule property tag | Algebraic guarantees | Stratum | Parallelism |
|---|---|---|---|
| **IN-fragment** | Binary principal port + locality + strong confluence (Lafont 1990, 1997) | S0 | Lévy-optimal sharing; HVM2-style massive parallelism |
| **Adhesive-DPO** | Adhesive category + critical-pair analysis (Lack-Sobocinski 2005, Biondo et al. 2025; enrichment frame per TBGH) | S0 | Critical pairs resolve by lattice JOIN (merge-as-answer, order-independent); critical-pair analysis is a REGISTRY datum routing write-target (+ optional scheduler perf hint) — correctness never depends on scheduling (amended 2026-06-10, SM4 F4) |
| **Confluence-by-construction** | `prop:ctor-desc-tag`-style structural confluence (SRE pattern) | S0 | Trivial parallelism (no critical pairs) |
| **Non-monotone / retraction-eligible** | Requires retraction stratum | S(-1) | Sequential within stratum; parallel with other S(-1) work |
| **Opaque (FFI + effects)** | Uninterpretable; trust-and-record | none — boundary marker (Stratum 3 is comment-only at effect-executor.rkt:53-54; posture = SM5) | Scheduler-determined; outside PReduce's reach |

A rule's property tags can stack — a rule can be both `IN-fragment` and `confluence-by-construction`. The scheduler exploits the strongest guarantee available.

### Axis 2: Persistence-regime axis (determines cacheability)

**Re-specified 2026-06-10 per Track 0.1 SM6 lock ([D.1 §7.1](2026-06-10_PREDUCE_TRACK01_DESIGN.md))**:
Axis 2 is a PRODUCT, not a flat five-way table — a 3-element **dynamic-confidence chain**
(`retraction-eligible ⊑ contextual ⊑ ground`, max-merge toward ground; demotion structurally
inexpressible, so admission is guarded) × static **admission classes**. `opaque` sits OUTSIDE
the chain (SM5's Boolean facet — an identity property, not a confidence level); `open` is
discharged by the rule registry's rule-id keyspace (templates persist as rules). Ground
admission day one: born-context-free entries only (D.1 §7.2); promoted entries stay
module-homed. The original table is retained below as examples of the classes:

| Regime | Persistence | Cache key | Example |
|---|---|---|---|
| **Ground/closed** | Persist freely across sessions | Content hash (CHAMP-derived) | `(+ 1 2) ≡ 3`; structural decomposition of closed types |
| **Contextual** | Within-session (cross-session = reserved schema slot) | Content hash + worldview | Trait-resolved equality; constraint-dependent rewrites |
| **Retraction-eligible** | Contextual + per-bit commitment evidence before promotion | Content hash + worldview + retraction state | Equalities discovered under hypothesis; speculative rewrites |
| **Open** (admission class) | Persist the rule template via the rule registry | Rule-id | Rules with free metas; pattern templates |
| **Opaque** (admission class) | Cannot persist rewrites; per-occurrence identity keys | (epoch × occurrence-path) | FFI calls; capability-typed effect evaluation |

Storage realization (Track 5): content-addressed `.pnet` fragments load on demand. Merckx et al. 2026 ("E-Graphs as a Persistent Compiler Abstraction") + IPVM-style content addressing realized on our substrate. The retraction-bit consultation is the discipline that prevents stale equalities from polluting the ground regime.

---

## Track Details

### Track 0: Series Founding (2026-05-02)

**Status**: 🔄 in progress this session (master + three sub-deliverables outlined; sub-deliverable docs to follow).

**Deliverables**:

#### Track 0.1 — Architectural sketch document

Six concrete NTT sub-models specifying the three-layer architecture:

1. **AST PU compound cell layout** — what components carry occurrence-state per node-position; how component-paths address nodes; merge semantics per component.
2. **E-class cell** — `:lattice :structural :order :refinement` declarations; merge function (union-find with structural-hash dedup); component layout (term set, representative, cost annotation, equivalence-witnesses, provenance).
3. **Unified rule registry cell** — CHAMP from rule-id → rule-data; property-tag taxonomy from Axis 1; per-rule consumers (which dispatch propagators care).
4. **Rewriting stratum (S0)** + retraction stratum (S(-1)) — only two needed; S0 internal property-tag-based dispatch; S(-1) consumes the unified BSP stratum-handler retraction infrastructure (`process-retraction` via `register-stratum-handler!`; lineage PM Track 7 → PPN 4C 2B, 2026-05-20).
5. **Effect-stratum boundary marker** — opaque cell type the rewriting layer doesn't enter; protocol for handing off to Architecture AD Stratum 3.
6. **Persistence regimes** — content-hashing scheme; worldview-tag composition; retraction-bit consultation discipline.

**Scope**: ~500-line research note + NTT model + correspondence table mapping NTT constructs to Racket implementations (per `workflow.md` NTT model requirement).

#### Track 0.2 — Rule-property taxonomy

Catalogs Prologos's reduction kinds and assigns each to a stratum + property tags:

- β-reduction (function application) — IN-fragment candidate
- δ-reduction (definition unfolding) — IN-fragment candidate (deterministic single-rule-per-name)
- ι-reduction (case selection) — adhesive-DPO; pattern-matching with overlapping clauses needs critical-pair analysis
- Structural decomposition (Pi/Sigma/etc) — confluence-by-construction (existing SRE pattern, generalized)
- Arithmetic evaluation — IN-fragment candidate (deterministic, no rewrite alternatives for ground inputs)
- Trait-dispatched reduction — non-monotone (depends on resolution); S(-1) candidate or contextual-regime cache
- NAF-aware reduction — non-monotone; existing BSP-LE NAF stratum integration
- Capability-aware reduction — effect-boundary-respecting (opaque pass-through)
- Session-typed reduction — coordinates with session-propagators.rkt; effect-boundary-aware
- FFI calls — opaque; effect-stratum delegation

**Output**: rule-property table + analysis of which kinds qualify for IN-fragment promotion (Lévy-optimal sharing). This determines the implementation Track-N partition.

#### Track 0.3 — `.pnet` extension + LLVM lowering interface

Our canonical format design for e-class state in `.pnet`. Co-designed with SH Track 1 (`.pnet` network-as-value).

Sections:
- E-class cell serialization — content-hashing scheme; structural-hash determinism
- Worldview-tag composition — how contextual-regime entries serialize
- Cross-session lookup protocol — load-on-demand fragment loading; CHAMP-friendly chunking
- Substrate-call boundary — what an LLVM-substrate consumer reads from `.pnet` to execute reduction
- Rule-registry serialization — rules-as-data; forward-compatible with future user-defined rules (Track 9)

Collaborator's LLVM-lowering prototype is one consumer voice — input shapes the design, output is OUR canonical commit. Their prototype rebases to whatever we land on `main`.

### Tracks 1-9: Pending

Track ordering in the progress tracker reflects expected dependency chain:
- Track 1 (e-class cell substrate) is the smallest-scope unblocking move; gates on PPN 4C Phase 1B + Track 0.1 closure.
- Tracks 2-3 add first rule kinds (one IN-fragment, one DPO) on top of Track 1's substrate.
- Track 4 (cost-guided extraction) consumes PPN 4C Phase 1B's residuation operator.
- Track 5 (persistence) extends `.pnet` with e-class state.
- Track 6 (speculative reduction) consumes BSP-LE 2B.
- Track 7 (effect boundary) coordinates with Architecture AD.
- Track 8 (`reduction.rkt` parity + retirement) is the multi-track endgame; gates on all prior tracks delivering parity.
- Track 9 (user-facility forward-compatibility validation) is design-only, not shipped.

Tracks beyond 1 emerge from Track 0 findings — exact partition decided at Track 0 closure.

---

## Open Questions

1. **Granularity of the per-AST-PU compound regions**: how fine-grained do components go — per node-position? Per node-position-and-reduction-concern? Coarser? Track 0.1 NTT model resolves.

2. **E-class cell merge under partial information**: when two e-classes are discovered to be equal but only some equivalence-witnesses are computed, does merge happen immediately or wait? Affects parallelism vs information-preservation trade-off. Track 0.1 design.

3. **IN-fragment promotion**: which Prologos reduction kinds genuinely qualify for IN-fragment property declaration? β is the strongest candidate; how far does the property extend (δ? structural? arithmetic?). Track 0.2 deliverable.

4. **Adhesive guarantees for the full PReduce rewriting system**: SRE Track 2D + adhesive theory established this for structural decomposition. Does it extend to term-reduction rules with critical pairs? **Reframed 2026-05-09 via substrate-research note**: under the Tiurin–Barrett–Ghica–Hu (LICS 2025) semilattice-enriched SMC frame, the guarantees come from *enrichment* rather than adhesivity proper. Per Bonchi et al. *String diagram rewrite theory III* (MSCS 2022), **DPOI confluence is decidable for terminating systems** — directly applicable to Track 3. Empirical confirmation is still Track 3 work; the formal grounding is no longer at the open M-adhesive frontier.

5. **Cost lattice composition**: PPN 4C Phase 1B ships single-quantale tropical fuel. PReduce extraction needs per-rewrite-rule cost + per-eclass cheapest-derivation. Single tropical quantale or product/tensor of multiple? PPN 4C addendum §4 multi-quantale composition NTT model is the basis; PReduce's specific composition decided in Track 4. **Disposition 2026-05-09 (substrate note + engineering memo; body amended 2026-06-10)**: the math foundation is supplied — quantale-module framing with residual operator signature `\_Q : Q × M → M` per C3.d. The CHOICE of Q (single tropical vs product/tensor) remains an explicit S1 commitment — owner decision at Track 4 design. Foundation resolved; choice open.

6. **Retraction-bit consultation discipline**: how does the persistence layer check retraction state before promoting to ground regime? Periodic sweep? On-write check? Retraction-stratum coordination? Track 0.1 design + Track 5 implementation. **Disposition 2026-05-09 (substrate note + engineering memo; body amended 2026-06-10)**: protocol clarified — ATMS-worldview-parameterized enrichment IS the protocol; the remaining work is implementation discipline (Track 0.1 design + Track 5), not protocol invention.

7. **Effect-stratum boundary protocol**: how does PReduce hand off to Architecture AD's Stratum 3? When does an opaque-cell value re-enter PReduce's reach (after the effect resolves)? Track 0.1 + Track 7 design.

8. **Lévy optimality reachability**: does Lévy-optimal sharing extend to dependent types + QTT + sessions, or only to a restricted fragment? E-Graphs with Bindings (Moss 2025) + DGoIM (Muroya-Ghica) literature; open in our setting.

9. **NTT-typed rewrite rules surface**: out of scope for current implementation per user direction (compiler-infrastructure focus). In scope for design — the architecture must not preclude eventual user-defined rewrite rules. Forward-compatibility validated in Track 9 (design-only).

10. **`reduction.rkt` retirement gating criteria**: what parity tests + soak time + production-default duration are required before Track 8 deletion? Per `workflow.md` "validated ≠ deployed" + belt-and-suspenders red-flag discipline. Decided at Track 8 design time, not now.

11. **Interaction with PPN Track 4D (Attribute Grammar Substrate Unification)**: 4D proposes collapsing typing/elaboration/reduction into unified attribute-grammar substrate. PReduce delivers reduction-on-network; 4D would unify it with typing/elaboration. Sequencing TBD — 4D's prereqs include PPN 4C completion + T-3 landing + PM Track 12; PReduce can advance independently and contribute its substrate when 4D opens.

12. **Cross-session persistence at scale**: CHAMP scales for the cell substrate. Whether full e-class persistence scales to large programs (millions of e-classes) is empirical. Track 5 work; mitigation paths (sharding, partial loading) designed in Track 0.3.

---

## References to Project Artifacts

### Roadmap + masters
- [`docs/tracking/MASTER_ROADMAP.org`](MASTER_ROADMAP.org) — series-of-series tracking; PReduce is referenced at the PM Track 9 promotion note, SRE Track 6 ownership row, and SH gating rows (2026-06-10: a dedicated PReduce rollup section under PRN remains to be added)
- [PRN Master](2026-03-26_PRN_MASTER.md) — theory series; PReduce is one of its application series
- [SH Master](2026-04-30_SH_MASTER.md) — self-hosting series; PReduce is its critical cross-series dependency
- [PPN Master](2026-03-26_PPN_MASTER.md) — propagator-parsing series; provides the parser/elaborator substrate PReduce reduces over
- [BSP-LE Master](2026-03-21_BSP_LE_MASTER.md) — speculative-search infrastructure (Track 2B PIR consumed)
- [SRE Master](2026-03-22_SRE_MASTER.md) — form registry (generalized into PReduce's unified rule registry); structural-decomposition rules (one rule property tag in PReduce's taxonomy)
- [PPN 4C Tropical Quantale Addendum Design D.2](2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_DESIGN.md) — substrate prerequisite

### Implementation references
- [`racket/prologos/reduction.rkt`](../../racket/prologos/reduction.rkt) — current imperative reducer (~3,560 lines; **461 whnf arms over 235 head constructors** per the D.2 census, 2026-06-10 — the earlier "~50 cases" was stale by ~9×); Track 8 retirement target
- [`racket/prologos/propagator.rkt`](../../racket/prologos/propagator.rkt) — substrate primitives; `register-stratum-handler!` pattern PReduce extends
- [`racket/prologos/pnet-serialize.rkt`](../../racket/prologos/pnet-serialize.rkt) — `.pnet` format; Track 0.3 + Track 5 extension target
- [`racket/prologos/sre-core.rkt`](../../racket/prologos/sre-core.rkt) — SRE form registry; PReduce's unified rule registry generalizes this pattern
- [`racket/prologos/effect-executor.rkt:54`](../../racket/prologos/effect-executor.rkt) — Stratum 3 reference; effect-boundary protocol PReduce respects

### Foundational research (chronological)
- [Track 9 Reduction-as-Propagators](2026-03-21_TRACK9_REDUCTION_AS_PROPAGATORS.md) — original Stage-1 founding (2026-03-21)
- [Categorical Foundations of Typed Propagator Networks](../research/2026-03-22_CATEGORICAL_FOUNDATIONS_TYPED_PROPAGATOR_NETWORKS.md) §10 — Lafont + GoI grounded against propagator semantics
- [Hypergraph Rewriting + Propagator Parsing](../research/2026-03-24_HYPERGRAPH_REWRITING_PROPAGATOR_PARSING.md) — DPO + e-graphs + interaction nets + GoI landscape
- [Tropical Optimization + Network Architecture](../research/2026-03-24_TROPICAL_OPTIMIZATION_NETWORK_ARCHITECTURE.md) — semiring parsing, cost-weighted rewriting, ATMS-guided search
- [Tree Rewriting as Structural Unification](../research/2026-03-26_TREE_REWRITING_AS_STRUCTURAL_UNIFICATION.md) — macro rewriting IS SRE decompose+reconstruct; rewrite as 4th SRE relation
- [Kan Extensions, ATMS, GFP Parsing](../research/2026-03-26_KAN_EXTENSIONS_ATMS_GFP_PARSING.md) — 4-level optimization strategy
- [Module Theory on Lattices](../research/2026-03-28_MODULE_THEORY_LATTICES.md) §6 — e-graphs as quotient modules; backward chaining as residuation
- [Adhesive Categories and Parse Trees](../research/2026-04-03_ADHESIVE_CATEGORIES_PARSE_TREES.md) — adhesive-DPO formal foundations
- [Hypercube BSP-LE Design Addendum](../research/2026-04-08_HYPERCUBE_BSP_LE_DESIGN_ADDENDUM.md) — Q_n hypercube + Gray code + bitmask subcube
- [Tropical Quantale Research](../research/2026-04-21_TROPICAL_QUANTALE_RESEARCH.md) — deep formal grounding for cost algebra
- [Lattice Variety and Canonical Form for SRE](../research/2026-04-30_LATTICE_VARIETY_AND_CANONICAL_FORM_FOR_SRE.md) — per-domain canonical form
- [Propagator Network as Super-Optimizing Compiler](../research/2026-04-30_PROPAGATOR_NETWORK_AS_SUPEROPTIMIZING_COMPILER.md) — architectural-distinctiveness argument

### External literature (from prior research notes)
- **E-graphs / equality saturation**: Willsey et al. (2021) [arXiv:2004.03082](https://arxiv.org/abs/2004.03082); Merckx, Lopoukhine, Coward, Cheng, De Suer, Grosser (2026) "E-Graphs as a Persistent Compiler Abstraction" [arXiv:2602.16707](https://arxiv.org/abs/2602.16707) (attribution corrected 2026-06-10; previously mis-cited as "Schlatt"; ID WebSearch-verified); Moss (2025) "E-Graphs with Bindings" [arXiv:2505.00807](https://arxiv.org/abs/2505.00807); Biondo-Castelnovo-Gadducci CALCO 2025 "EGGs Are Adhesive!"
- **Interaction nets / GoI**: Lafont (1990, 1997); Girard GoI I-V; Mackie GoI Machine; Muroya-Ghica DGoIM [arXiv:1803.00427](https://arxiv.org/abs/1803.00427); HVM2 [HigherOrderCO/HVM2](https://github.com/HigherOrderCO/HVM2)
- **Adhesive categories**: Lack-Sobocinski (2005); Inria (2025) Rocq formalization; Corradini et al. (CONCUR 2024)
- **Tropical / quantale**: Litvinov-Maslov (2001); Russo (arXiv:1002.0968); Fujii (arXiv:1909.07620); Bacci-Mardare-Panangaden-Plotkin (2023); Lawvere (1973)
- **Self-hosting peer systems**: Lean 4, Idris 2, GHC, MLIR, Cranelift — comparison points in SH master § super-optimization research note

---

## Notes on series operation

- This is a **theory + implementation series**. Track 0 produces research notes; Tracks 1+ produce code. Track 9 is design-only forward-compatibility validation.
- **Series can advance independently of PPN Track 4D** (Attribute Grammar Substrate Unification). When 4D opens, PReduce contributes its substrate; sequencing TBD.
- **PRN contributes back**: each PReduce track's PIR includes a "PRN contribution" section per PRN Master's Cross-Series Contribution Ledger (§5).
- **The design mantra applies at every layer**: per-AST-PU compound regions are on-network; e-class cells are on-network; rule registry is on-network; cost extraction is on-network. Off-network state is debt against self-hosting per `.claude/rules/on-network.md`.
- **`reduction.rkt`'s deletion is a milestone**, not a track activity — it lands when Track 8 closes after parity + soak + production-default. The discipline matters: per `workflow.md`, validated ≠ deployed; belt-and-suspenders is a blocking red flag.

---

*This document grows as Track 0 sub-deliverables land and implementation tracks open. Each track's PIR contributes back to PRN Master's findings tables.*
