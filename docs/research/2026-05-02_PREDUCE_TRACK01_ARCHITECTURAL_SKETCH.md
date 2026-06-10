# PReduce Track 0.1 — Architectural Sketch

**Date**: 2026-05-02
**Stage**: 1 — Research (per [`DESIGN_METHODOLOGY.org`](../tracking/principles/DESIGN_METHODOLOGY.org) Stage 1)
**Status**: Track 0.1 of [PReduce series](../tracking/2026-05-02_PREDUCE_MASTER.md) — research synthesis, not design commitment
**Target consumers**: PReduce Track 0.2 (rule-property taxonomy); PReduce Track 0.3 (`.pnet` extension + LLVM lowering interface); PReduce Track 1+ implementation tracks
**Related prior art**:
- [PReduce Master](../tracking/2026-05-02_PREDUCE_MASTER.md) — series tracking; carries the leading direction at the roadmap level
- [E-Graphs Research](2026-05-02_E_GRAPHS_RESEARCH.md) — foundational mechanics + Prologos synthesis; load-bearing reference
- [Tropical Quantale Research](2026-04-21_TROPICAL_QUANTALE_RESEARCH.md) — cost algebra; residuation as extraction
- [Module Theory on Lattices](2026-03-28_MODULE_THEORY_LATTICES.md) §6 — e-graphs as quotient modules
- [Hypergraph Rewriting + Propagator Parsing](2026-03-24_HYPERGRAPH_REWRITING_PROPAGATOR_PARSING.md) — DPO + e-graphs + IN/GoI landscape
- [Adhesive Categories and Parse Trees](2026-04-03_ADHESIVE_CATEGORIES_PARSE_TREES.md) — adhesive-DPO foundations
- [Hypercube BSP-LE Design Addendum](2026-04-08_HYPERCUBE_BSP_LE_DESIGN_ADDENDUM.md) — Q_n hypercube + bitmask
- [Kan Extensions, ATMS, GFP Parsing](2026-03-26_KAN_EXTENSIONS_ATMS_GFP_PARSING.md) — 4-level optimization strategy
- [BSP-LE Track 2B PIR](../tracking/2026-04-16_BSP_LE_TRACK2B_PIR.md) — speculation infrastructure
- [PRN Master](../tracking/2026-03-26_PRN_MASTER.md) — confirmed findings + universal primitives
- [PPN 4C Tropical Quantale Addendum](../tracking/2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_DESIGN.md) — substrate gating-dependency

---

## §1 Purpose and scope

### §1.1 Why this document exists

The [PReduce master](../tracking/2026-05-02_PREDUCE_MASTER.md) sketched a three-layer architecture + two orthogonal axes + two-stratum dispatch as the series's leading direction. Track 0.1 is the architectural-sketch research note that takes those leading proposals and **deepens them with concrete content + surfaces alternatives + identifies decision tipping factors**, without committing to specific cell-id assignments / merge function pseudocode / serialization formats / parity strategy. Stance (b) per the founding conversation: leading proposals with alternatives genuinely surfaced.

This document is exploratory research — it inhabits the design space rather than picking a single point. Future implementation tracks (Track 1+) consume it as the canonical "where did we consider X alternative" reference.

### §1.2 What this document does NOT do

Per the founding conversation:
- **No detailed rule taxonomy**: that's Track 0.2
- **No `.pnet` format design**: that's Track 0.3
- **No cell-id assignments**: that's Track 1+ implementation
- **No `reduction.rkt` parity strategy**: that's Track 8 design
- **No NTT-formal model**: research note, not design doc; NTT model lives in Track 1+ design when implementation begins
- **No mantra-audit-per-sub-model rigor**: applied at the meta level (does the architecture preserve on-network discipline?), not per-section

### §1.3 What this document leans on

Foundational mechanics live elsewhere; 0.1 references rather than reproduces:
- **E-graph data structure + algorithms**: [E-Graphs Research](2026-05-02_E_GRAPHS_RESEARCH.md) §2 (foundations), §3 (theoretical grounding), §4 (production landscape), §5 (recent advances), §6 (performance), §7 (Prologos synthesis)
- **Cost algebra**: [Tropical Quantale Research](2026-04-21_TROPICAL_QUANTALE_RESEARCH.md) — semirings, quantales, residuation, modules
- **Quotient module framing**: [Module Theory on Lattices](2026-03-28_MODULE_THEORY_LATTICES.md) §6
- **Adhesive grounding**: [Adhesive Categories and Parse Trees](2026-04-03_ADHESIVE_CATEGORIES_PARSE_TREES.md) + Biondo-Castelnovo-Gadducci CALCO 2025
- **Speculation infrastructure**: [BSP-LE Track 2B PIR](../tracking/2026-04-16_BSP_LE_TRACK2B_PIR.md) + [Hypercube BSP-LE](2026-04-08_HYPERCUBE_BSP_LE_DESIGN_ADDENDUM.md)
- **PPN Track 1 D.7 PU pattern**: per the founding-conversation reference

---

## §2 Problem statement

### §2.1 Architectural endpoint

PReduce's deliverable, when all tracks close, is reduction natively on-network as e-graph + DPO + tropical-quantale + GoI on the same substrate that hosts parsing, typing, elaboration, and module loading. The substrate IS the IR. Rule application IS propagator firing. Cost extraction IS quantale residuation. Equivalence classes ARE shared cells. Speculative reduction IS BSP-LE 2B branch exploration. Cross-session persistence IS `.pnet` content-addressed loading. The imperative `reduction.rkt` is retired (Track 8 endgame).

### §2.2 What success looks like

PReduce closes successfully when:
- All `reduction.rkt` reduction kinds (β, δ, ι, structural, arithmetic, trait-dispatch, NAF-aware, capability-aware, session-typed, FFI) have on-network realizations as rule-registry entries with property tags
- `reduction.rkt`'s test parity is matched by the new substrate (bit-identical results for closed terms; semantic-equivalence for open terms)
- Cost-guided extraction yields measurably-cheaper reductions than naive imperative reduction on at least the targeted optimization patterns (constant folding, common-subexpression elimination, β-η normalization)
- `.pnet` round-trips e-class state for ground-regime equivalences; cold-start reduction times for re-compiled modules drop measurably
- The substrate is forward-compatible with future user-defined rewrite rules (no architectural commitment ruling them out, even though surface syntax stays Racket-internal)
- SH Track 4's production LLVM substrate has the perf foundation it needs (super-optimization story shippable)

### §2.3 What this means for 0.1

0.1's architectural sketch must be coherent enough that Track 1's first implementation can begin without re-litigating the layer decomposition, axis taxonomy, or stratum count. It must surface alternatives explicitly enough that future tracks can revisit a leading proposal if empirical work reveals a tipping factor. It must NOT commit to specifics that belong in Track 1+ design or implementation.

---

## §3 What's structurally constrained

These are settled by existing infrastructure — the architectural design space we don't get to redo:

| Constraint | Source | Implication for PReduce |
|---|---|---|
| **On-network discipline** | Mantra non-negotiable per [`on-network.md`](../../.claude/rules/on-network.md) | Every layer is cells with monotone merges; off-network state is debt |
| **SRE rule-registry pattern** | SRE Track 2D (13 DPO rules); `prop:ctor-desc-tag` for confluence-by-construction | PReduce's rule registry generalizes the SRE form-registry pattern; existing SRE rules become rule-registry entries with property-tag = `confluence-by-construction` |
| **PPN 4C Phase 1B substrate** | In flight per [`PPN 4C Tropical Quantale Addendum`](../tracking/2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_DESIGN.md) — ships `tropical-fuel.rkt` + residuation operator + SRE quantale-property declarations | PReduce inherits cost algebra without recreating; extraction algorithm IS the residual operator |
| **BSP-LE 2B speculation** | [PIR](../tracking/2026-04-16_BSP_LE_TRACK2B_PIR.md): Q_n hypercube worldview + bitmask subcube + ATMS nogoods + S(-1) retraction | PReduce's speculative cost-bounded reduction consumes this directly; non-confluent rule cases handled |
| **Adhesive guarantee for e-graphs** | Biondo-Castelnovo-Gadducci CALCO 2025 (e-graphs adhesive); SRE Track 2D + [Adhesive Categories](2026-04-03_ADHESIVE_CATEGORIES_PARSE_TREES.md) | PReduce's e-class cells inherit DPO toolkit; critical-pair analysis transfers |
| **Quotient-module framing** | [Module Theory §6](2026-03-28_MODULE_THEORY_LATTICES.md) — e-graphs as quotient modules | Cost-guided extraction = residuation on the quotient module; algebraic frame for rule composition |
| **Lévy-optimal sharing requires hashcons** | HVM2 demonstrates; e-graphs research §7.2 | Sharing is realized via shared e-class cells (CHAMP-derived structural identity); per-node PUs would break this |
| **CHAMP structural sharing** | Existing infrastructure | Hashcons + content-addressing for free; cells inherit CHAMP cache behavior |
| **PPN Track 1 D.7 PU pattern** | Tree topology stored as polynomial-functor M-type in one cell (5000+ cells → 5 PUs) | AST is one PU; per-node state is compound-component, not per-node PU |
| **CALM theorem** | Hellerstein 2010 | Monotone computation is coordination-free; PReduce's S0 rewriting stratum has this property |

These constraints are non-negotiable in the sense that PReduce builds on them. Designing around them isn't an option; the architecture must respect them.

---

## §4 The leading architectural proposal — three layers

The decomposition: occurrence-state lives in **per-AST-PU compound regions** (Layer 1); term-equivalence state lives in **shared e-class cells with refinement-poset structure** (Layer 2); rewriting machinery lives in a **unified rule registry with property-tagged dispatch** (Layer 3). Together these realize on-network e-graph rewriting that respects Lévy-optimal sharing, inherits adhesive guarantees, and composes with PPN 4C 1B's cost-extraction algebra.

### §4.1 Layer 1: per-AST-PU compound regions

**Leading proposal**: the AST is one Pocket Universe (per PPN Track 1 D.7). Per-node occurrence-state — reduction status, cost-in-context, substitution environment, provenance — lives as compound-cell components keyed by node-position inside the AST PU. Component values reference Layer 2 (shared e-class cells) by cell-id. Multiple syntactic occurrences of the same term share the same e-class cell; occurrence-state distinguishes positions, e-class state distinguishes equivalence classes.

**Why this is the lean**: PPN Track 1 D.7 already established the pattern for parse trees (5000 cells → 5 PUs via tree-as-M-type). Reusing it for ASTs gives us tested infrastructure + structural alignment with parsing. The compound-component-per-node-position granularity keeps occurrence-specific information local without creating O(N) PU allocations.

**Alternatives considered**:
- **(a) Per-node PUs** — each AST node has its own top-level PU. **Rejected**: PPN Track 1 D.7 lesson cuts the other way (5000 → 5); allocation pressure compounds; per-occurrence PUs that hold mostly references-to-shared-cells are scaffolding not value.
- **(b) Flat occurrence-table cell** — single CHAMP cell from node-position → occurrence-state. Possible; loses the local-monotonicity-shell semantics that PUs provide; concentrates write contention. Workable if CHAMP per-key access pattern dominates; less clean architecturally.
- **(c) No occurrence-layer** — all per-occurrence info derived from e-class cells + position-in-AST-topology. **Rejected**: loses occurrence-specific provenance ("why does THIS position reduce to that value"); loses cost-in-context (different occurrences of the same term may have different costs in different surrounding contexts).

**Tipping factors** (would push toward an alternative):
- If CHAMP per-key access dominates allocation pressure for the AST PU, alternative (b) might win
- If occurrence-state turns out to be derivable from e-class state + topology in all cases, alternative (c) becomes possible
- If PU allocation overhead per AST is empirically small (Track 1+ measurement), the per-AST-PU pattern is reinforced

**References**: [E-Graphs Research §7.1](2026-05-02_E_GRAPHS_RESEARCH.md); PPN Track 1 D.7 (PPN Track 2B PIR); founding conversation Section "PU-per-AST-node may be wrong granularity" refinement.

### §4.2 Layer 2: shared e-class cells with refinement-poset structure

**Leading proposal**: each e-class is a cell on the propagator network. Cell value carries refinement-poset structure (`A ≤ B` iff every term in A is in B). Cell merge implements union-find (union of e-node sets, structural-hash-derived canonical representative, tropical-min cost merge, monotone provenance accumulation). Hashcons via CHAMP — cell-id assignment is the structural hash of the canonical representative. Binder-aware e-class structure per Moss 2025 *E-Graphs with Bindings* is the leading direction; concrete mechanics (de Bruijn integration, α-equivalence, capture-avoiding substitution) deferred to Track 1+ design.

**Why this is the lean**: [E-Graphs Research](2026-05-02_E_GRAPHS_RESEARCH.md) §7.1-7.4 establishes the composition; PPN 4C Phase 1B's residuation operator IS the extraction algorithm (§7.5); CHAMP delivers hashcons + content-addressing for free (§7.2); union-find as monotone merge satisfies CALM (§7.3); adhesive guarantees inherit from Biondo-Castelnovo-Gadducci 2025 (§7.4). Each piece is independently grounded; the composition falls out without engineering effort.

The refinement-poset (rather than join-semilattice) declaration matters because cost-guided extraction's residuation walks the Hasse diagram of the poset. SRE lattice lens Q6: the poset's Hasse diagram IS the operational graph extraction navigates.

Binder handling: dependent types + lambda calculi force the issue. Moss 2025 introduces explicit binder-aware e-class structure handling α-equivalence, capture-avoiding substitution, and de Bruijn-like indexing. Our existing substitution + zonking infrastructure provides the implementation hooks; integration is non-trivial but well-grounded.

**Alternatives considered**:
- **(a) Vanilla egg-style without CHAMP structural sharing** — engineered hashcons table, no cross-cell sharing. **Rejected**: gives up the substrate's free structural sharing; doesn't compose with `.pnet` content-addressing.
- **(b) Schlatt-style persistent in MLIR-dialect form** ([arXiv:2602.16707](https://arxiv.org/abs/2602.16707)) — e-graph as first-class IR construct. **Architecturally analogous to ours** — Schlatt's `eqsat` dialect role is filled by e-class cells in our setting. Not a true alternative; the same architectural move on a different substrate.
- **(c) Colored e-graphs as primary representation** (Singher-Itzhaky 2023) — context-sensitive equivalences first-class throughout. **Adopted partially** — colored e-graph theory grounds our worldview-tagged e-classes (§5.2 below); but as PRIMARY representation for closed-term equivalences (the bulk of cases), the coloring overhead is unnecessary. Colored equivalences layer atop ground equivalences via worldview tags.

**Tipping factors**:
- If dependent type interaction reveals cases where ground equivalences are inherently context-dependent (no truly closed terms), alternative (c) might promote to primary
- If `.pnet` content-addressing turns out to be incompatible with refinement-poset hashing at scale, simpler value-lattice cell might be needed (with extraction handled separately)
- Moss 2025 binder-aware mechanics not landing well empirically would force a binder-handling redesign

**References**: [E-Graphs Research §3.2, §7](2026-05-02_E_GRAPHS_RESEARCH.md); [Module Theory §6](2026-03-28_MODULE_THEORY_LATTICES.md); Moss 2025 ([arXiv:2505.00807](https://arxiv.org/abs/2505.00807)); Singher-Itzhaky 2023.

### §4.3 Layer 3: unified rule registry with property-tagged dispatch

**Leading proposal**: one CHAMP cell `rule-registry-cid` from rule-id → rule-data. Rule-data carries property-tag declarations (Axis 1 below: IN-fragment / adhesive-DPO / confluence-by-construction / non-monotone / opaque). The propagator scheduler dispatches rule application based on property tags. SRE form-registry rules (structural decomposition) integrate as rule-kind with `confluence-by-construction` tag. PReduce rewrite rules (β/δ/ι/optimization) integrate as additional rule kinds. Forward-compatible with future user-defined rewrite rules (rules-as-data, not Racket-only closures).

**Why this is the lean**: PRN master §3 lists "rule registration" as confirmed universal primitive across SRE, PPN, and (predicted) PReductions. SRE Track 2D's form-registry is the existing instance; PReduce generalizes. One registry + many consumers is the architectural simplification — analogous to one database schema with many query patterns.

**Alternatives considered**:
- **(a) Per-stratum registries** — separate rule registry per stratum (S0 has one, S(-1) has another). **Rejected**: duplicates infrastructure for no semantic gain; cross-stratum rule references become harder.
- **(b) Per-domain registries** (β rules separate from structural rules, separate from arithmetic rules, etc.) — multiple parallel registries. **Rejected for same reasons as (a)**; but the consumer-side dispatch CAN be domain-aware (a propagator for β-reduction reads only β-tagged rules from the unified registry).
- **(c) Implicit registry — rules as Racket data only** — no first-class on-network registry; rules embedded in propagator code. **Rejected**: precludes runtime rule discovery, LLM-guided rule synthesis, future user-defined rules; off-network state.

**Tipping factors**:
- If rule-property-tag dispatch turns out to have measurable overhead vs domain-specific dispatch, alternative (b)'s consumer-side specialization becomes the optimization
- If user-facility forward-compat (Track 9) is descoped permanently, alternative (c)'s simplicity becomes attractive — but at the cost of architectural cleanliness

**References**: PRN master §3; SRE Track 2D; [E-Graphs Research §7.9](2026-05-02_E_GRAPHS_RESEARCH.md).

---

## §5 The two orthogonal axes

The three-layer decomposition is parameterized by two orthogonal axes that determine HOW rules dispatch and HOW e-class equivalences persist.

### §5.1 Rule-property axis (determines stratum + parallelism guarantees)

**Leading proposal**: rules carry property-tag declarations from the following taxonomy:

- **IN-fragment** — Lafont-style binary principal port + locality + strong confluence; Lévy-optimal sharing inherited; HVM2-style massive parallelism
- **Adhesive-DPO** — adhesive category + critical-pair analysis (Biondo et al. 2025); DPO confluence under critical-pair-free scheduling
- **Confluence-by-construction** — `prop:ctor-desc-tag`-style structural confluence (existing SRE pattern); trivial parallelism (no critical pairs)
- **Non-monotone / retraction-eligible** — retraction stratum (S(-1)); sequential within stratum
- **Opaque (FFI + effects)** — uninterpretable; trust-and-record; effect-stratum delegation

A rule's tags can stack — a rule can be both `IN-fragment` and `confluence-by-construction`. The scheduler exploits the strongest guarantee available.

**Why this taxonomy**: each tag corresponds to a well-grounded algebraic property (Lafont 1990; Biondo et al. 2025; SRE Track 2D `prop:ctor-desc-tag`; BSP-LE 2B retraction stratum; Architecture AD effect stratum). The taxonomy maps reduction-kind → algebraic-guarantees → scheduler-treatment.

**Alternatives considered**:
- **(a) Simpler binary classification** — confluent vs non-confluent. Loses the IN-fragment optimization (we couldn't exploit Lévy-optimal sharing); loses confluence-by-construction's structural simplicity. Workable but sacrifices algebraic precision.
- **(b) Finer-grained per-rule-kind taxonomy** — explicit tag for each reduction kind (β-tag, δ-tag, ι-tag, …). Conflates *reduction kind* with *algebraic property*; the same kind can have different properties in different contexts. Architecturally noisy.

**Tipping factors**:
- If IN-fragment promotion analysis (Track 0.2) turns out to apply to fewer rules than expected, the taxonomy might collapse toward alternative (a)
- If rule property tags are too coarse to express scheduler-relevant distinctions, expansion toward (b)'s rule-kind specificity may be needed

**References**: Lafont 1990; Biondo-Castelnovo-Gadducci CALCO 2025; SRE Track 2 PIR (`prop:ctor-desc-tag`); [BSP-LE Track 2B PIR](../tracking/2026-04-16_BSP_LE_TRACK2B_PIR.md); Architecture AD; [E-Graphs Research §7](2026-05-02_E_GRAPHS_RESEARCH.md).

### §5.2 Persistence-regime axis (determines cacheability across sessions)

**Leading proposal**: e-class equivalences fall into one of five regimes, each with distinct persistence semantics:

- **Ground/closed**: persist freely across sessions; cache key is content hash; example: `(+ 1 2) ≡ 3`
- **Contextual**: persist with worldview-bitmask tag (BSP-LE 2B pattern); cache key is content hash + worldview; example: trait-resolved equality
- **Retraction-eligible**: contextual + retraction-bit consultation before promotion to ground; cache key is content hash + worldview + retraction state; example: equalities under hypothesis
- **Open**: don't persist resolved value; persist the rewrite-rule template; cache key is rule-id; example: rules with free metas
- **Opaque**: cannot persist (no rewrite to persist); cache key N/A; example: FFI calls

**Why this taxonomy**: each regime corresponds to a real distinction in equivalence semantics. Ground equivalences are absolutely true; contextual depends on hypothesis state; retraction-eligible may be invalidated; open is template, not value; opaque is unevaluable. The five regimes cover the space.

**Alternatives considered**:
- **(a) Simpler binary (cached vs not-cached)** — single regime distinguishing what persists from what doesn't. Loses the worldview-tag composition story; loses the retraction-bit consultation discipline; conflates "this isn't cacheable for foundational reasons" (opaque) with "this isn't cacheable in context X" (contextual).
- **(b) Single regime with worldview-tags only** — every equivalence carries a worldview tag (the full bitmask is the unconstrained "ground" worldview); persistence is uniform. Conceptually clean; in practice the operational distinctions (when to consult retraction state, when to evict on session boundary, when to fail-on-load) collapse into worldview-specific logic that ends up reproducing the regime taxonomy implicitly.

**Tipping factors**:
- If retraction-bit consultation turns out to have prohibitive overhead, retraction-eligible might be merged into contextual (with retraction-bits in the worldview)
- If `.pnet` content-addressing scales better with uniform regime treatment, alternative (b) becomes attractive

**References**: [E-Graphs Research §7.7-7.8](2026-05-02_E_GRAPHS_RESEARCH.md); BSP-LE 2B tagged-cell-value pattern; Schlatt 2026 ([arXiv:2602.16707](https://arxiv.org/abs/2602.16707)); Singher-Itzhaky 2023.

---

## §6 Two-stratum architecture

### §6.1 S0 rewriting stratum

**Leading proposal**: a single S0 stratum hosts all monotone rewriting — IN-fragment, adhesive-DPO, and confluence-by-construction rules all fire here. The propagator scheduler uses property-tag dispatch within S0 to apply per-rule guarantees (Lévy-optimal sharing for IN-fragment; critical-pair-aware ordering for adhesive-DPO; trivial parallelism for confluence-by-construction). Rule applications write to e-class cells; cell merges reconcile cross-rule results.

**Why one stratum is enough**: stratification is a fixpoint-precedence mechanism (per [`stratification.md`](../../.claude/rules/stratification.md): "reach for a stratum when a computation requires fixpoint of another stratum before evaluating"). The various confluent rule kinds don't require each other's fixpoint; they can fire concurrently. The property-tag dispatch handles per-rule guarantees without separate strata.

### §6.2 S(-1) retraction stratum

**Leading proposal**: an S(-1) stratum handles non-monotone rewrites (rules tagged `non-monotone / retraction-eligible`). Retraction-eligible equivalences are invalidated when their hypothesis is retracted. This is the existing BSP-LE 2B retraction stratum; PReduce consumes it for retraction-bit consultation.

**Why the stratum is needed separately**: retraction is structurally non-monotone (it removes information), which violates S0's CALM-compatible monotone discipline. Per `stratification.md`, non-monotone work belongs at higher strata; retraction is the lowest non-monotone stratum (it removes the most information).

### §6.3 Effect-stratum boundary

**Leading proposal**: PReduce respects the existing effect-stratum boundary (Architecture AD's Stratum 3, referenced in `effect-executor.rkt:54`). Opaque cells (FFI calls, capability-typed effects) are uninterpretable to PReduce's rewriting layer. Protocol: when PReduce encounters an opaque cell, it stops rewriting at that cell's boundary and emits a topology request for effect-stratum evaluation. When the effect resolves and the cell value becomes evaluable, PReduce can re-enter (the cell is no longer opaque). This is the same pattern as topology requests for unregistered relations (per `on-network.md`).

**Open**: the precise re-entry protocol — when does a previously-opaque cell signal "ready for PReduce"? This is named as an open question in §7 below, with leading proposal: a per-effect-stratum-completion topology request that PReduce subscribes to.

### §6.4 Why two strata is enough

**Alternatives considered**:
- **(a) Many concern-strata** — one stratum per reduction kind (β-stratum, δ-stratum, structural-stratum, arithmetic-stratum, …). **Rejected**: violates `stratification.md`'s test (these don't require each other's fixpoint); creates unnecessary scheduler complexity.
- **(b) Single-stratum-with-priority** — one stratum, priority-based scheduling determines order. **Rejected**: priority-based scheduling is imperative-flavored; conflicts with the substrate's emergent-from-dataflow discipline. Also: retraction stratum can't share a stratum with monotone rewriting (CALM violation).

The two-stratum architecture (S0 monotone + S(-1) retraction) is the minimum that respects monotonicity discipline + provides a place for non-monotone work. Adding more strata is unnecessary unless a future track surfaces a fixpoint-precedence requirement we haven't identified.

**Tipping factors**:
- If a third class of rewrites emerges that requires fixpoint of S0 OR S(-1) before evaluating (e.g., a re-saturation phase after retraction), a third stratum may be warranted
- If effect-stratum coordination turns out to require deeper integration (rather than handoff via topology requests), the effect stratum may need to be modeled within PReduce rather than treated as boundary

**References**: [`stratification.md`](../../.claude/rules/stratification.md); [BSP-LE Track 2B PIR](../tracking/2026-04-16_BSP_LE_TRACK2B_PIR.md); Architecture AD; PReduce master Track 7 (effect-stratum boundary protocol).

---

## §7 Genuinely open questions

These are questions where the leading proposals have a recognizable lean but the literature isn't yet settled or our setting amplifies the difficulty. Each is a candidate for follow-up research or for Track 1+ design dialogue.

### §7.1 Granularity dial for Layer 1

How fine-grained do the AST PU's compound regions go? Per node-position? Per (node-position, reduction-concern)? Coarser (per scope, per term-shape)? The dial choice affects allocation pressure, write contention, and incremental-recomputation granularity. Leading direction: per node-position is the natural fit (each AST node has one component); but per-(node-position, concern) might pay off if concerns have radically different update frequencies. Empirical question for Track 1+ measurements.

### §7.2 Binder handling specifics

Moss 2025 *E-Graphs with Bindings* is the leading direction for handling lambda-calculus-style binders in e-classes. But the concrete mechanics — how α-equivalence is realized at the cell level; how capture-avoiding substitution interacts with our existing zonking infrastructure; whether de Bruijn indices are the canonical representation throughout or only at e-class boundaries — are non-trivial design decisions. Open for Track 1+ design.

### §7.3 IN-fragment promotion criteria

Which Prologos reduction kinds genuinely qualify for IN-fragment property declaration? β is the strongest candidate (Lafont's interaction combinators are essentially the lambda calculus). δ-unfolding might qualify (deterministic, single-rule-per-name) but recursive definitions complicate it. ι-reduction (case selection) almost certainly doesn't (overlapping patterns). The detailed taxonomy is Track 0.2's deliverable; here we name the question and acknowledge it's under-determined.

### §7.4 Retraction-bit consultation discipline

When does a contextual-regime equivalence get promoted to ground regime (cacheable across sessions)? The retraction state must be stable — no live hypothesis depends on it. Possible disciplines:
- **Periodic sweep**: scan contextual entries periodically; promote those whose retraction-bits are clear
- **On-write check**: at write time, check retraction state; tag accordingly
- **Lazy promotion**: don't promote; on read, check both ground and contextual; promote on first ground-eligible read

Each has trade-offs (overhead, latency, complexity). Leading direction: lazy promotion, since it amortizes the check across reads. Open for Track 5 (persistence) design.

### §7.5 Effect-stratum coordination protocol

When does an opaque cell value re-enter PReduce's reach (after the effect resolves)? Leading direction: a per-effect-stratum-completion topology request that PReduce subscribes to (Architecture AD coordinates emission; PReduce coordinates re-entry). But the precise semantics — does re-entry retract prior reductions that crossed the opaque boundary? Does it merely add new ones? — needs careful design. Open for Track 7 design.

### §7.6 Adhesive-DPO absorbing structural-decomposition

PRN master §1 confirms: SRE structural decomposition IS DPO hyperedge replacement. PRN §2 conjectures: β/δ/ι reduction as DPO rewrite rules. **The synthesis question**: do SRE Track 2D's 13 DPO rules cleanly absorb into PReduce's unified rule registry as rule-registry entries with property-tag = `confluence-by-construction`? Or do structural-decomposition rules retain enough specialness (e.g., the `prop:ctor-desc-tag` constraint) that they remain a separate rule kind alongside reduction rules?

Leading direction: full absorption — `prop:ctor-desc-tag` becomes a property tag, structural-decomposition rules are rule-registry entries like any other, the SRE form registry IS the rule registry. But if absorption introduces dispatch overhead or breaks SRE's optimizations, partial absorption (separate registries that both implement the same protocol) becomes the fallback. Empirical question for Track 1+.

### §7.7 What's the tropical residual operator's actual API surface?

[E-Graphs Research §7.5](2026-05-02_E_GRAPHS_RESEARCH.md) makes the strong claim: the extraction algorithm IS the tropical residual operator that PPN 4C Phase 1B already ships. PReduce inherits the algebra. The **operational** question: what's the residual operator's actual API surface in `tropical-fuel.rkt`? Phase 1B is in flight (D.2 design); PReduce 0.1 references the residual but doesn't constrain its interface. Verification work for Track 4 (cost-guided extraction) once Phase 1B closes.

### §7.8 Fixpoint termination across non-confluent rules

Equality saturation may not terminate when rules introduce structural growth (e.g., `x ⇒ x + 0`). The tropical fuel cell bounds total work, but **does it bound saturation depth structurally**? Or does it bound only via wall-clock-equivalent fuel exhaustion? The two are different — structural saturation termination would let us prove specific reductions terminate; fuel exhaustion only guarantees forward progress within budget. Open theoretical question; Track 4+ design.

---

## §8 Connection to broader vision

### §8.1 SH series — super-optimization story

PReduce is SH master's [critical cross-series dependency](../tracking/2026-04-30_SH_MASTER.md) — what shifts the architectural endpoint from "competitive" to "super-optimizing." The synthesis: e-graph + tropical-quantale + adhesive-DPO + content-addressed `.pnet` + BSP-LE speculation = on-network super-optimization. Each piece is independently grounded; PReduce is the assembly. After PReduce + SH Track 1 (`.pnet` network-as-value) + SH Track 4 (production LLVM substrate), Prologos compiles to native via LLVM with super-optimization intrinsic to compilation. That position is novel; per [`Propagator Network as Super-Optimizing Compiler`](2026-04-30_PROPAGATOR_NETWORK_AS_SUPEROPTIMIZING_COMPILER.md), no existing production compiler holds it.

### §8.2 Multi-agent / Vat / DCR

Content-addressed `.pnet` artifacts mobile across compartments, with first-class provenance (ATMS-tracked support sets) and fixpoint-equality (not just bit-equality). PReduce's e-class cells inherit the content-addressing; `.pnet` round-trip extends to e-graph state; deployment artifacts carry not just compiled programs but the equivalence reasoning that proved them equivalent. This is the multi-agent vision realized at the artifact level — receivers can verify, optimize, or reason about the artifact without re-deriving the equality structure.

### §8.3 Incremental compilation (PPN 4D potential)

PPN Track 4D (Attribute Grammar Substrate Unification) proposes collapsing typing/elaboration/reduction into a unified attribute-grammar substrate. PReduce delivers reduction-on-network; 4D would unify it with typing/elaboration. The sequencing TBD — 4D's prereqs include PPN 4C completion + T-3 landing + PM Track 12. PReduce can advance independently; if/when 4D opens, PReduce contributes its substrate. The 4D coordination is a future-tracking concern, not a 0.1 commitment.

### §8.4 Cross-session caching is what makes the LLVM lowering tractable

A subtle point worth surfacing: the SH Track 4 LLVM substrate isn't just "compile to native" — it's "compile + cache + reuse across sessions." Without cross-session e-class persistence (PReduce Track 5), every session pays the full saturation cost. With it, ground-regime equivalences amortize across compilations. This is the Salsa-style incremental compilation story (per [`Propagator Network as Super-Optimizing Compiler`](2026-04-30_PROPAGATOR_NETWORK_AS_SUPEROPTIMIZING_COMPILER.md) §3.5) realized at the equality-saturation level.

---

## §9 Decision points the series will face

Catalog of decisions Track 1+ tracks will need to make. Not 0.1's resolution targets; 0.1 names them so they're tracked.

1. **First implementation track scope**: e-class cell substrate (the SRE-Track-0 analog) vs first rule-kind implementation (β as IN-fragment exemplar). Trade-off: substrate-first lands the cell layer cleanly but doesn't exercise rule application; rule-first exercises end-to-end but requires substrate as inline scaffolding. Lean: substrate-first. Decided in Track 1 design.

2. **`reduction.rkt` parity strategy**: incremental (one reduction kind at a time) vs big-bang (all kinds simultaneously). Per `workflow.md` "validated ≠ deployed" + belt-and-suspenders red-flag discipline: incremental is the lean. But incremental requires both substrates running in parallel for an extended period, which has its own complexity. Decided in Track 8 design.

3. **User-facility forward-compat dial**: how aggressively do we keep rules-as-data through every track, even though user-defined rules are out of scope? Lean: aggressively — keep the abstraction clean now, save rework later. Decided per-track at Track 1+ design.

4. **PPN Track 4D coordination**: design pessimistically (PReduce stands alone) with 4D-compat hooks, or wait for 4D's design to clarify? Lean: pessimistic. Revisit when 4D opens.

5. **Effect-stratum re-entry semantics** (per §7.5): retract prior reductions or only add new ones? Decided in Track 7 design.

6. **Persistence retraction-bit consultation discipline** (per §7.4): periodic sweep / on-write check / lazy promotion? Decided in Track 5 design.

7. **Granularity dial for Layer 1** (per §7.1): per-node-position / per-(node, concern) / coarser? Decided in Track 1 design (or revisited later if measurements suggest a different granularity).

8. **Whether to absorb SRE 2D rules into PReduce's rule registry** (per §7.6): full / partial. Decided in Track 1 or Track 3 design.

---

## §10 References

### §10.1 Foundational research notes (Prologos)
- [PReduce Master](../tracking/2026-05-02_PREDUCE_MASTER.md) — series tracking; this document deepens its leading proposals
- [E-Graphs Research](2026-05-02_E_GRAPHS_RESEARCH.md) — foundational mechanics + Prologos synthesis (load-bearing reference throughout)
- [Tropical Quantale Research](2026-04-21_TROPICAL_QUANTALE_RESEARCH.md) — cost algebra; residuation theory
- [Module Theory on Lattices](2026-03-28_MODULE_THEORY_LATTICES.md) §6 — quotient module framing
- [Hypergraph Rewriting + Propagator Parsing](2026-03-24_HYPERGRAPH_REWRITING_PROPAGATOR_PARSING.md) — DPO + e-graphs + IN/GoI landscape
- [Adhesive Categories and Parse Trees](2026-04-03_ADHESIVE_CATEGORIES_PARSE_TREES.md) — adhesive-DPO foundations
- [Hypercube BSP-LE Design Addendum](2026-04-08_HYPERCUBE_BSP_LE_DESIGN_ADDENDUM.md) — Q_n hypercube + bitmask
- [Kan Extensions, ATMS, GFP Parsing](2026-03-26_KAN_EXTENSIONS_ATMS_GFP_PARSING.md) — 4-level optimization strategy
- [Categorical Foundations of Typed Propagator Networks](2026-03-22_CATEGORICAL_FOUNDATIONS_TYPED_PROPAGATOR_NETWORKS.md) §10 — Lafont + GoI grounding
- [Propagator Network as Super-Optimizing Compiler](2026-04-30_PROPAGATOR_NETWORK_AS_SUPEROPTIMIZING_COMPILER.md) — comparative landscape; super-optimization argument

### §10.2 Tracking documents
- [PRN Master](../tracking/2026-03-26_PRN_MASTER.md) — confirmed findings + universal primitives (rule registration §3 is load-bearing)
- [SH Master](../tracking/2026-04-30_SH_MASTER.md) — self-hosting series; PReduce is critical cross-series dependency
- [PPN 4C Tropical Quantale Addendum Design](../tracking/2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_DESIGN.md) — substrate prerequisite (Phase 1B residuation operator)
- [BSP-LE Track 2B PIR](../tracking/2026-04-16_BSP_LE_TRACK2B_PIR.md) — speculation infrastructure
- [SRE Master](../tracking/2026-03-22_SRE_MASTER.md) — form registry (generalizes into PReduce's unified rule registry)

### §10.3 Project rules + methodology
- [`on-network.md`](../../.claude/rules/on-network.md) — design mantra (on-network discipline)
- [`stratification.md`](../../.claude/rules/stratification.md) — strata design discipline
- [`propagator-design.md`](../../.claude/rules/propagator-design.md) — propagator design checklist
- [`structural-thinking.md`](../../.claude/rules/structural-thinking.md) — SRE lattice lens (6 questions)
- [`workflow.md`](../../.claude/rules/workflow.md) — methodology gates + validation discipline
- [`DESIGN_METHODOLOGY.org`](../tracking/principles/DESIGN_METHODOLOGY.org) — Stage 1 research framing

### §10.4 External literature (cited via the e-graphs research note's reference list)

*Amended 2026-05-09 per substrate-research note*: primary categorical frame for PReduce is Tiurin–Barrett–Ghica–Hu (LICS 2025); Biondo et al. retained as alternative / comparison.

**Primary categorical frame for PReduce**:
- **Tiurin, Barrett, Ghica, Hu (LICS 2025)** — *Equivalence Hypergraphs: DPO Rewriting for Monoidal E-Graphs* ([arXiv:2406.15882](https://arxiv.org/abs/2406.15882)). E-graphs as morphisms in semilattice-enriched SMCs; full equivalence of categories `SMT⁺(Σ, E) ≃ MEHypI(Σ)/S, E`. **This is the working categorical frame for PReduce per `docs/research/utm-fl/outputs/preduce-adhesive-rewriting-substrate-internal-research.md` §2.C1.alt.**
- **Moss, Tiurin (2025)** — *E-Graphs With Bindings* ([arXiv:2505.00807](https://arxiv.org/abs/2505.00807)). Extends TBGH to closed SMCs; covers λ-binders within the same enrichment framework. Track 9 (NTT-typed rules) consumes this.
- **Russo (2010)** — *Quantale Modules and their Operators* ([arXiv:1002.0968](https://arxiv.org/abs/1002.0968)). Q-module residuation; supplies the residual operator API (§7.7 resolution).
- **Bonchi, Gadducci, Kissinger, Sobociński, Zanasi (2022)** — *String diagram rewrite theory* I/II/III (JACM 2022, MSCS 2022). Underlying rewriting infrastructure; III contains decidability of DPOI confluence for terminating systems (directly applicable to Track 3).

**Alternative / comparison categorical frame**:
- **Biondo, Castelnovo, Gadducci (CALCO 2025)** — *EGGs are Adhesive!* ([arXiv:2503.13678](https://arxiv.org/abs/2503.13678)). E-graphs are `T_Σ`-adhesive (a form of M-adhesive, not full adhesive). Standard DPO parallelism/causality transfer is *open* per the paper's own §7; engineering proceeds under TBGH instead.
- **Baldan, Castelnovo, Corradini, Gadducci (CONCUR 2024)** — *Left-linear rewriting in adhesive categories*. Active-research-frontier reference if we needed the Biondo route.
- **Ehrig, Golas, Habel, Lambers, Orejas (2012, 2014)** — NAC theory for M-adhesive transformation systems; equally applicable to TBGH setting.

**Foundational categorical references**:
- Lack, Sobociński (2005) — adhesive categories
- Lafont (1990, 1997) — interaction nets / interaction combinators (IN-fragment Track 2 grounding)
- Joyal, Street, Verity (1996) — traced monoidal categories
- Haghverdi, Scott (ICALP 2004) — categorical model for geometry of interaction

**Production / runtime references**:
- Willsey et al. (POPL 2021) — egg ([arXiv:2004.03082](https://arxiv.org/abs/2004.03082))
- Schlatt et al. (2026) — E-Graphs as a Persistent Compiler Abstraction ([arXiv:2602.16707](https://arxiv.org/abs/2602.16707))
- Singher, Itzhaky (2023) — Colored E-Graphs (Track 6 speculative-reduction precedent)
- Muroya, Ghica (CSL 2017) — Dynamic GoI Machine ([arXiv:1703.10027](https://arxiv.org/abs/1703.10027)); close engineering precedent for Track 6
- HVM2 (HigherOrderCO) — production interaction-combinator runtime; Track 2 benchmark target

(Full citations live in [E-Graphs Research §9](2026-05-02_E_GRAPHS_RESEARCH.md) and the substrate-research note's running bibliography; this note references rather than reproduces.)

---

## Document status

**Stage 1 research note** — opens PReduce Track 0.1. Architectural sketch with leading proposals + alternatives surfaced + decision tipping factors named. Not a design commitment; a research synthesis.

**Next steps**:
- PReduce Track 0.2 (rule-property taxonomy) — catalogs reduction kinds and assigns property tags from §5.1
- PReduce Track 0.3 (`.pnet` extension + LLVM lowering interface) — references Layer 2 e-class cell layout from §4.2 and persistence regimes from §5.2
- PReduce Track 1+ implementation begins after PPN 4C Phase 1B closes; this note is the architectural reference

This document is a living reference until Track 1 design opens; refinements through Track 0.2 and 0.3 may surface decisions that update specific sections. Significant updates should be commits with traceable hashes; minor refinements live as section-level edits.
