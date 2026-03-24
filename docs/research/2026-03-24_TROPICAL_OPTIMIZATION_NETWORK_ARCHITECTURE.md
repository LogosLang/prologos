# Tropical Optimization, ATMS-Guided Search, and Network Architecture

**Stage**: 0 (Research Note — conversational synthesis)
**Date**: 2026-03-24
**Series touches**: PPN (Propagator-Parsing-Network), PM (Track 9 reductions), SRE, OE (Optimization Enrichment), BSP-LE, NTT

**Related documents**:
- [Hypergraph Rewriting + Propagator-Native Parsing](2026-03-24_HYPERGRAPH_REWRITING_PROPAGATOR_PARSING.md) — foundational research
- [Categorical Foundations of Typed Propagator Networks](2026-03-22_CATEGORICAL_FOUNDATIONS_TYPED_PROPAGATOR_NETWORKS.md) — polynomial functors, Galois connections
- [SRE Research](2026-03-22_STRUCTURAL_REASONING_ENGINE.md) — structural decomposition as universal primitive
- [NTT Syntax Design](../tracking/2026-03-22_NTT_SYNTAX_DESIGN.md) — stratification, bridge, exchange syntax
- [Track 9 Research Note](../tracking/2026-03-21_TRACK9_REDUCTION_AS_PROPAGATORS.md) — reduction as propagators
- [SRE Master](../tracking/2026-03-22_SRE_MASTER.md) — SRE series tracking
- [Master Roadmap](../tracking/MASTER_ROADMAP.org) — all series tracking

---

## 1. The Core Realization: SRE IS Hyperedge Replacement

When `structural-relate` decomposes `Pi(A, B)` into sub-cells, it performs
exactly a DPO hyperedge replacement: the Pi hyperedge is replaced by its
component sub-cells plus connecting propagators. The ctor-desc form
registry IS a hypergraph grammar — each constructor registration is a
production rule.

The theoretical foundations for graph rewriting (termination, confluence,
typed interfaces via adhesive categories) apply to our SRE directly. We
inherit decades of results about termination guarantees, critical pair
analysis, and typed rewriting from the graph transformation community.

**Critical pair analysis for SRE confluence**: The `prop:ctor-desc-tag`
struct property guarantees that each value has exactly one constructor
tag, so exactly one decomposition rule matches any given cell value. No
critical pairs. Confluence is structural — BY CONSTRUCTION, not by
analysis. This is the strongest form of the CALM theorem applied to
our structural decomposition.

When we add REWRITING rules (optimization, reduction), critical pairs
become possible. Two rewrite rules might both match the same subgraph.
The graph transformation literature prescribes: critical pair analysis
to DETECT conflicts, stratification to RESOLVE them. Non-conflicting
rules fire in S0 (monotone, parallel). Conflicting rules are staged
across strata with exchanges mediating the interaction.

## 2. Checking Our Assumptions

The original claims that "parsing doesn't belong on the network" and
"reductions don't belong on the network" were both wrong. They
conceived parsing as sequential string-to-tree transformation and
reduction as sequential substitution. The Engelfriet-Heyker equivalence
shows parsing IS attribute evaluation IS propagator fixpoint. DPO
rewriting shows reduction IS graph transformation IS propagator
quiescence.

**Meta-lesson**: When we say "X doesn't fit on the network," ask: "are
we conceiving X too narrowly?" The propagator network is more general
than any specific algorithm — it's a computational substrate that
subsumes algorithms when given the right lattice and the right
structural forms.

## 3. Tropical Semirings and Cost-Optimal Computation

### The Categorical Framing

A tropical semiring (min-plus or max-plus algebra) is a quantale where
the tensor is addition and the join is min (or max). In our framework:

- The **correctness lattice** (type, parse, session) uses
  join-semilattice structure for monotonic information accumulation
- The **optimization lattice** (cost, tropical semiring) uses min-plus
  structure for finding optimal solutions

These are two DIFFERENT enrichments on the same network. A cell carries
BOTH a correctness value (what's the type?) and a cost value (how
expensive is this derivation?). The enrichments compose via product:
`Cell (L_correct × L_cost)`.

### Semiring Parsing (Goodman 1999)

Goodman showed that Earley, CYK, and other parsers are all instances of
the same algorithm parameterized by the semiring:

| Semiring | What you get |
|----------|-------------|
| Boolean | Recognition (is this string in the language?) |
| Counting | Ambiguity counting (how many parse trees?) |
| Viterbi (tropical) | Optimal parsing (cheapest derivation) |
| Derivation forest | All parses (complete parse forest) |

On the network: each production propagator carries a cost annotation.
When multiple derivations reach the same cell, the tropical merge (min)
keeps the cheapest. The parse forest lattice becomes WEIGHTED — each
parse tree has a cost, and the lattice ordering prefers lower-cost trees.

### Cost-Weighted Rewriting

For reductions: each rewrite rule has a cost. The e-graph's equality
saturation explores all rewrites; the tropical extraction picks the
cheapest equivalent program. This is exactly egg/egglog's extraction
phase. The CALCO 2025 result (e-graphs are adhesive, Biondo/Castelnovo/
Gadducci) means this lives in the same categorical framework as DPO
rewriting.

### Extending Decidability Beyond Fuel Limits

Instead of hard fuel limits (explore for N steps, then stop), the
tropical semiring provides **cost-bounded exploration**: continue while
marginal cost of the next step < expected benefit threshold. This is
more nuanced than fuel — it's informed by the problem structure:

- Cheap derivation paths get explored further
- Expensive paths get pruned early
- The threshold adapts to the problem (complex types get more budget)

This connects to Kan extensions: Left Kan (speculative forwarding)
forwards the CHEAPEST partial results first; Right Kan (demand-driven)
requests computation only when expected cost < threshold.

**Research question**: Can we formalize the "marginal cost" notion as a
derivative in the tropical semiring? The tropical derivative of a formal
power series gives the sensitivity of the optimal cost to input
perturbation. This could give us a principled "explore here next"
heuristic — focus exploration where the tropical derivative is largest
(the cost is most sensitive to further computation).

## 4. ATMS and Optimal Space Exploration

### Parsing as ATMS Search

Ambiguous parses are different ATMS assumption sets. Type-directed
disambiguation adds constraints that make some sets contradictory:

- Parse A assumes `foo` is a function application
- Type checker determines `foo` is a keyword
- Contradiction → retract assumption A → parse B wins

The ATMS handles this naturally. Nogood learning from type errors
prunes the parse space. Future parses avoid assumption combinations
that led to type contradictions.

### Rewriting as ATMS Search

Each rewrite rule application is an assumption. If two rewrites
conflict (rule A blocks rule B), the ATMS records the nogood.
Future exploration avoids the conflicting combination. This is
learned-clause pruning applied to graph rewriting.

### Retraction and the S(-1) Stratum

When an assumption is retracted, the S(-1) stratum cleans up the
affected cells. For parsing: a retracted parse assumption removes
the parse tree fragment and all downstream type/elaboration cells
that depended on it. For rewriting: a retracted rewrite removes the
optimized form and reverts to the pre-rewrite version.

The TMS worldview-aware reads (Track 8 B1) ensure that retracted
entries are invisible to readers in other assumption branches. This
is exactly the isolation needed for exploring multiple parse/rewrite
alternatives concurrently.

## 5. Stratification for the Unified Network

The NTT stratification syntax can express the full compiler pipeline:

```prologos
stratification CompilerNetwork
  :strata [S-neg1 S0 S1 S2 S3]
  :fiber S0
    :mode monotone
    :networks [parse-net type-net elaborate-net]
    :bridges [ParseToType TypeToElaborate TypeToParse]
    :scheduler :bsp
  :fiber S1
    :mode monotone
    :networks [optimization-net]
    :enrichment [tropical]
  :fiber S2
    :mode monotone
    :networks [readiness-net]
  :fiber S3
    :mode commit
    :bridges [OptimizationToCodegen]
  :exchange S0 <-> S1
    :left  partial-type-info -> rewrite-candidates
    :right optimization-result -> type-constraint
  :fuel :cost-bounded
  :where [WellFounded CompilerNetwork]
```

**S0**: Parsing + typing + elaboration — all bidirectional via bridges.
Type information flows INTO the parser (disambiguation). Parse structure
flows INTO the type checker. Elaboration results flow back to both.

**S1**: Cost-weighted optimization (tropical enrichment). Each rewrite
rule carries a cost. The tropical merge keeps cheapest derivations.

**S2**: Readiness checking — all optimizations applied?

**S3**: Commit to code generation. Non-monotone (finalizes choices).

**`:fuel :cost-bounded`**: Tropical semiring replaces flat fuel limits.
Exploration continues while marginal cost < threshold.

The exchange between S0 and S1 is the key architectural innovation:
type information guides which rewrites are type-safe (left adjoint),
and optimization results constrain types (right adjoint). This
bidirectional flow doesn't exist in traditional compiler pipelines
where optimization is a post-type-checking phase.

## 6. User-Defined Grammar Extensions

If the grammar IS a hypergraph grammar registered with the SRE, then
adding new syntax = adding new hyperedge replacement rules. This is
more powerful than Lisp-style macros:

| Capability | Lisp Macros | HR Grammar Extensions |
|-----------|-------------|----------------------|
| Transform syntax | ✓ | ✓ |
| Add new structural forms | ✗ (desugars to existing) | ✓ (new hyperedges) |
| Type-checked extensions | ✗ | ✓ (NTT types the rule) |
| Participate in disambiguation | ✗ | ✓ (type-directed) |
| Participate in optimization | ✗ | ✓ (DPO rewrite rules) |
| Incremental tooling support | ✗ | ✓ (propagation) |

A grammar extension registers: the new production (hyperedge
replacement rule), its type rule (NTT-typed propagator), its
optimization rules (DPO rewrite rules with costs), and its
pretty-printing rule (reconstruction propagator). The extension
participates in the FULL compilation pipeline, not just parsing.

## 7. Cross-Series Connections

### PPN (Propagator-Parsing-Network)

PPN consumes: lattice designs from this research, ATMS search from
BSP-LE, stratification from NTT. PPN produces: parse-on-network
infrastructure that Track 9 and SRE consume for their own rewriting.

### PM Track 9 (Reductions as Propagators)

Track 9 is the convergence point for DPO rewriting, interaction nets,
e-graphs, and parsing. The hypergraph rewriting research provides the
theoretical foundation. The tropical semiring provides the optimization
layer. The ATMS provides the search strategy.

### SRE Series

The SRE's form registry IS a hypergraph grammar (confirmed by this
research). Future SRE tracks should be designed with this in mind:
adding a structural form = adding a grammar production = adding a
DPO rewrite rule. The SRE Master doc should reference this framing.

### OE (Optimization Enrichment)

A cross-cutting research series that provides the tropical semiring
infrastructure consumed by PPN (weighted parsing), PM Track 9
(cost-weighted rewriting), BSP-LE (cost-bounded search), and
constraint solving (weighted constraints).

### NTT

NTT provides the typing discipline for all of the above. Grammar rules
are typed. Rewrite rules are typed. Cost annotations are typed. The
NTT stratification form expresses the full compiler architecture.

## 8. Open Research Questions

1. **Tropical derivatives for exploration heuristics**: Can the
   derivative of a tropical formal power series guide "where to explore
   next" in the ATMS search?

2. **Adhesive categories for Prologos**: The CALCO 2025 result shows
   e-graphs are adhesive. Are our propagator networks adhesive? If so,
   all DPO rewriting theory applies directly.

3. **Weighted NTT**: Can NTT's type system be extended to carry tropical
   cost annotations? A rewrite rule's type would include its cost, and
   the type checker would verify cost monotonicity.

4. **Incremental critical pair analysis**: As new grammar/rewrite rules
   are registered, do we need to re-analyze confluence? Or can we
   design the registration API to guarantee confluence structurally
   (as prop:ctor-desc-tag does for SRE decomposition)?

5. **Interaction net normal forms**: Lafont's interaction nets have
   strong confluence (every reduction sequence reaches the same normal
   form). Can we design our rewrite rules to be interaction-net-like,
   guaranteeing strong confluence without critical pair analysis?

6. **Self-hosting parsing**: If the parser is on the network, and the
   network is typed by NTT, and NTT is expressible in Prologos...
   then the parser is a Prologos program that parses Prologos. What
   bootstrapping strategy makes this work?
