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

**Key insight (2026-05-02)**: The architectural endpoint of PReduce is reduction natively on-network as e-graph + DPO + tropical-quantale + GoI on the **same substrate** that hosts parsing, typing, elaboration, and module loading — not as a separate engine bolted onto the compiler. Three layers compose: per-AST-PU compound regions hold occurrence-state; shared e-class cells hold term-equivalence state with refinement-poset structure; a unified rule registry holds property-tagged rewrite rules dispatched by the propagator scheduler. Two orthogonal axes parameterize the design: the **rule-property axis** (IN-fragment vs adhesive-DPO vs non-monotone) determines stratum + parallelism guarantees; the **persistence-regime axis** (ground vs contextual vs retraction-eligible vs opaque) determines cacheability across sessions. The combination is what makes the SH-series super-optimization story shippable.

**Cross-series connections**:
- **PPN 4C Phase 1B** ([Tropical Quantale Addendum](2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_DESIGN.md)) is the hard substrate prerequisite — ships `tropical-fuel.rkt` cell factory + budget cell + threshold propagator + residuation operator + SRE quantale-property declarations. PReduce inherits without recreating.
- **BSP-LE Track 2B** ([PIR](2026-04-16_BSP_LE_TRACK2B_PIR.md)) provides the speculative-search infrastructure: Q_n hypercube worldview, bitmask subcube pruning, Gray-code branch ordering, ATMS nogoods, retraction stratum S(-1). PReduce's cost-bounded speculative reduction consumes this directly.
- **SRE Track 2D** delivered 13 concrete DPO rewrite rules + adhesive guarantees; PReduce extends the rule registry to term reduction, generalizing the SRE form-registry pattern.
- **PRN Master** is the theory home; PReduce findings contribute back to PRN's Universal Primitives and Confirmed Findings tables. PRN §2 conjectures β/δ/ι-reduction-as-DPO-rules — PReduce Track 1 is the predicted confirmation.
- **SH Master** is the consumer — PReduce delivers the algorithmic perf foundation that makes self-hosted Prologos competitive at runtime; SH Track 4 (production LLVM substrate) gates on PReduce delivery for the super-optimization claim.
- **NTT** — rewrite rules will eventually carry NTT type annotations; rule-property declarations are NTT property declarations. Forward-compatible-with but not gated-on NTT formalization.

---

## Progress Tracker

| Track | Description | Status | Design | PIR | Notes |
|-------|------------|--------|--------|-----|-------|
| 0 | Series founding research synthesis (this master + three sub-deliverables) | 🔄 | This document | — | Three sub-deliverables (0.1, 0.2, 0.3) detailed below. Stage 0/1 work; no implementation. |
| 0.1 | Architectural sketch document — three-layer decomposition + NTT model + six sub-models | ⬜ | — | — | Output: ~500-line research note + NTT model. Resolves granularity, rule-registry unification, e-class poset, effect boundary, persistence regimes. |
| 0.2 | Rule-property taxonomy — catalogs Prologos reduction kinds + assigns each to stratum + property tags | ⬜ | — | — | Output: rule-property table + analysis of IN-fragment promotion candidates. Determines Track-N partition. |
| 0.3 | `.pnet` extension + LLVM lowering interface | ⬜ | — | — | Our canonical format. Collaborator's LLVM-lowering prototype is one consumer voice but rebases to whatever we commit. Co-designed with SH Track 1 (`.pnet` network-as-value). |
| 1 | E-class cell substrate — cell type + hashcons + union-find on cells | ⬜ | — | — | Analog of SRE Track 0 (form-registry substrate). Gates on PPN 4C Phase 1B + Track 0.1 closure. The first real implementation work. |
| 2 | First IN-fragment rewrite-rule kind (β-reduction) | ⬜ | — | — | Validates IN-fragment-as-property approach. Lévy-optimal sharing inherited via shared e-class cells. PRN §2 conjecture confirmation. |
| 3 | First adhesive-DPO rewrite-rule kind (ι/case-selection, structural normalization) | ⬜ | — | — | Validates DPO machinery on the same e-class substrate. Critical-pair analysis as runtime mechanism. |
| 4 | Cost-guided extraction — tropical-quantale residuation on e-class poset | ⬜ | — | — | Consumes PPN 4C Phase 1B residuation operator. Module Theory §6 e-graphs-as-quotient-modules realized. |
| 5 | Persistence — content-addressed e-class storage + `.pnet` round-trip + cross-session loading | ⬜ | — | — | Schlatt 2026 ("E-Graphs as a Persistent Compiler Abstraction") realized on our substrate. Regime-tagged cache discipline. |
| 6 | Speculative reduction — cost-bounded ATMS branching for non-confluent rule cases | ⬜ | — | — | Consumes BSP-LE 2B hypercube infrastructure. The "4-level optimization strategy" (ATMS + Left Kan + Right Kan + tropical) realized for reduction. |
| 7 | Effect-stratum boundary protocol — opaque cells for FFI + capability-typed effects | ⬜ | — | — | PReduce respects effect-stratum boundary; doesn't try to subsume opaque-evaluation. Architecture AD's Stratum 3 is the existing pattern. |
| 8 | `reduction.rkt` parity + retirement — multi-track endgame | ⬜ | — | — | Per `workflow.md` "validated ≠ deployed" discipline: parity with `reduction.rkt` validated → new substrate as production default → `reduction.rkt` retirement as its own track after baking. |
| 9 | User-facility forward-compatibility validation (out of scope for current implementation; in scope for design) | ⬜ | — | — | Confirms NTT-typed rewrite rules + rule-registry round-trip + property-declaration surface form would work without re-architecting. Not shipped; validated. |

---

## Architecture: The Three-Layer Decomposition

(Per adversarial-round-refined design from the founding conversation, 2026-05-02. Detailed in Track 0.1.)

### Layer 1 — Per-AST-PU compound regions

The AST is one Pocket Universe (per [PPN Track 1 D.7](2026-03-30_PPN_TRACK2B_DESIGN.md): tree topology stored as polynomial-functor M-type in one cell, reducing 5000+ cells to 5 PUs). Per-node occurrence-state (reduction status, cost-in-context, substitution environment, provenance) lives as **compound-cell components** keyed by node-position inside the AST PU, NOT as separate per-node PUs. The PU is the monotonic execution shell at compound-component granularity.

Component values reference Layer 2 (shared e-class cells) by cell-id. Multiple syntactic occurrences of the same term share the same e-class cell, preserving Lévy-optimal sharing.

### Layer 2 — Shared e-class cells

One cell per term-equivalence class. Hashcons + union-find realized as cell-id assignment (structural hash determines cell-id) + union-merge (e-class merge updates union-find roots monotonically).

E-class cell value carries **refinement-poset structure** (`:order :refinement`, not just join-semilattice) — `A ≤ B` iff every term in A is in B. The poset's Hasse diagram IS the operational graph that cost-guided extraction (Layer 3 stratum) walks via tropical-quantale residuation. SRE lattice-lens Q6 (Hasse diagram = parallel decomposition) applies directly.

The e-class cell is **structural** (multiple components: term set, representative, cost, equivalence-witnesses). NTT declaration: `:lattice :structural :order :refinement`.

### Layer 3 — Unified rule registry + property-tagged rules

One CHAMP cell from rule-id → rule-data, generalizing the SRE form registry. SRE's `prop:ctor-desc-tag` becomes a *property* on a rule, not a separate registry. PRN §3 "rule registration as universal primitive" realized: the registry hosts structural-decomposition rules (formerly SRE-only) AND term-rewriting rules (PReduce contribution).

Rules carry **property-tag declarations** (Axis 1 below). The propagator scheduler dispatches rules to the correct stratum based on property tags. Two strata suffice:
- **S0 rewriting stratum** (monotone): all confluent rewriting (IN-fragment + adhesive-DPO + structural-decomposition). Property tags determine local guarantees + parallelism (Lévy-optimal vs DPO with critical-pair analysis).
- **S(-1) retraction stratum** (non-monotone): retraction-eligible rewrites (BSP-LE 2B existing pattern).

Effect-aware reduction respects the existing effect-stratum boundary (Architecture AD Stratum 3) — opaque cells are uninterpretable to PReduce's rewriting layer.

---

## Two Orthogonal Axes

### Axis 1: Rule-property axis (determines stratum + parallelism)

| Rule property tag | Algebraic guarantees | Stratum | Parallelism |
|---|---|---|---|
| **IN-fragment** | Binary principal port + locality + strong confluence (Lafont 1990, 1997) | S0 | Lévy-optimal sharing; HVM2-style massive parallelism |
| **Adhesive-DPO** | Adhesive category + critical-pair analysis (Lack-Sobocinski 2005, Biondo et al. 2025) | S0 | DPO confluence under critical-pair-free scheduling |
| **Confluence-by-construction** | `prop:ctor-desc-tag`-style structural confluence (SRE pattern) | S0 | Trivial parallelism (no critical pairs) |
| **Non-monotone / retraction-eligible** | Requires retraction stratum | S(-1) | Sequential within stratum; parallel with other S(-1) work |
| **Opaque (FFI + effects)** | Uninterpretable; trust-and-record | (effect stratum) | Scheduler-determined; outside PReduce's reach |

A rule's property tags can stack — a rule can be both `IN-fragment` and `confluence-by-construction`. The scheduler exploits the strongest guarantee available.

### Axis 2: Persistence-regime axis (determines cacheability)

| Regime | Persistence | Cache key | Example |
|---|---|---|---|
| **Ground/closed** | Persist freely across sessions | Content hash (CHAMP-derived) | `(+ 1 2) ≡ 3`; structural decomposition of closed types |
| **Contextual** | Persist with worldview-bitmask tag | Content hash + worldview | Trait-resolved equality; constraint-dependent rewrites |
| **Retraction-eligible** | Contextual + retraction-bit consultation before promotion to ground | Content hash + worldview + retraction state | Equalities discovered under hypothesis; speculative rewrites |
| **Open** | Don't persist resolved value; persist the rewrite-rule template | Rule-id | Rules with free metas; pattern templates |
| **Opaque** | Cannot persist rewrites (no rewrite to persist) | N/A | FFI calls; capability-typed effect evaluation |

Storage realization (Track 5): content-addressed `.pnet` fragments load on demand. Schlatt 2026 ("E-Graphs as a Persistent Compiler Abstraction") + IPVM-style content addressing realized on our substrate. The retraction-bit consultation is the discipline that prevents stale equalities from polluting the ground regime.

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
4. **Rewriting stratum (S0)** + retraction stratum (S(-1)) — only two needed; S0 internal property-tag-based dispatch; S(-1) consumes BSP-LE 2B retraction infrastructure.
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

4. **Adhesive guarantees for the full PReduce rewriting system**: SRE Track 2D + adhesive theory established this for structural decomposition. Does it extend to term-reduction rules with critical pairs? Adhesive theory says yes (Biondo et al. 2025); empirical confirmation is Track 3 work.

5. **Cost lattice composition**: PPN 4C Phase 1B ships single-quantale tropical fuel. PReduce extraction needs per-rewrite-rule cost + per-eclass cheapest-derivation. Single tropical quantale or product/tensor of multiple? PPN 4C addendum §4 multi-quantale composition NTT model is the basis; PReduce's specific composition decided in Track 4.

6. **Retraction-bit consultation discipline**: how does the persistence layer check retraction state before promoting to ground regime? Periodic sweep? On-write check? Retraction-stratum coordination? Track 0.1 design + Track 5 implementation.

7. **Effect-stratum boundary protocol**: how does PReduce hand off to Architecture AD's Stratum 3? When does an opaque-cell value re-enter PReduce's reach (after the effect resolves)? Track 0.1 + Track 7 design.

8. **Lévy optimality reachability**: does Lévy-optimal sharing extend to dependent types + QTT + sessions, or only to a restricted fragment? E-Graphs with Bindings (Moss 2025) + DGoIM (Muroya-Ghica) literature; open in our setting.

9. **NTT-typed rewrite rules surface**: out of scope for current implementation per user direction (compiler-infrastructure focus). In scope for design — the architecture must not preclude eventual user-defined rewrite rules. Forward-compatibility validated in Track 9 (design-only).

10. **`reduction.rkt` retirement gating criteria**: what parity tests + soak time + production-default duration are required before Track 8 deletion? Per `workflow.md` "validated ≠ deployed" + belt-and-suspenders red-flag discipline. Decided at Track 8 design time, not now.

11. **Interaction with PPN Track 4D (Attribute Grammar Substrate Unification)**: 4D proposes collapsing typing/elaboration/reduction into unified attribute-grammar substrate. PReduce delivers reduction-on-network; 4D would unify it with typing/elaboration. Sequencing TBD — 4D's prereqs include PPN 4C completion + T-3 landing + PM Track 12; PReduce can advance independently and contribute its substrate when 4D opens.

12. **Cross-session persistence at scale**: CHAMP scales for the cell substrate. Whether full e-class persistence scales to large programs (millions of e-classes) is empirical. Track 5 work; mitigation paths (sharding, partial loading) designed in Track 0.3.

---

## References to Project Artifacts

### Roadmap + masters
- [`docs/tracking/MASTER_ROADMAP.org`](MASTER_ROADMAP.org) — series-of-series tracking; PReduce slot to be added under PRN's application-series rollup
- [PRN Master](2026-03-26_PRN_MASTER.md) — theory series; PReduce is one of its application series
- [SH Master](2026-04-30_SH_MASTER.md) — self-hosting series; PReduce is its critical cross-series dependency
- [PPN Master](2026-03-26_PPN_MASTER.md) — propagator-parsing series; provides the parser/elaborator substrate PReduce reduces over
- [BSP-LE Master](2026-03-21_BSP_LE_MASTER.md) — speculative-search infrastructure (Track 2B PIR consumed)
- [SRE Master](2026-03-22_SRE_MASTER.md) — form registry (generalized into PReduce's unified rule registry); structural-decomposition rules (one rule property tag in PReduce's taxonomy)
- [PPN 4C Tropical Quantale Addendum Design D.2](2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_DESIGN.md) — substrate prerequisite

### Implementation references
- [`racket/prologos/reduction.rkt`](../../racket/prologos/reduction.rkt) — current imperative reducer (~4000 lines, ~50 cases); Track 8 retirement target
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
- **E-graphs / equality saturation**: Willsey et al. (2021) [arXiv:2004.03082](https://arxiv.org/abs/2004.03082); Schlatt (2026) "E-Graphs as a Persistent Compiler Abstraction" [arXiv:2602.16707](https://arxiv.org/abs/2602.16707); Moss (2025) "E-Graphs with Bindings" [arXiv:2505.00807](https://arxiv.org/abs/2505.00807); Biondo-Castelnovo-Gadducci CALCO 2025 "EGGs Are Adhesive!"
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
