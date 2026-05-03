# E-Graphs: Equality Saturation, Adhesive Foundations, and Prologos Synthesis

**Date**: 2026-05-02
**Stage**: 1 — Deep Research (per [`DESIGN_METHODOLOGY.org`](../tracking/principles/DESIGN_METHODOLOGY.org) Stage 1)
**Status**: Foundational survey + Prologos-specific synthesis
**Target consumers**: PReduce series ([Track 0.1 architectural sketch](../tracking/2026-05-02_PREDUCE_MASTER.md), Track 1+ implementation tracks); future SH series tracks; future PPN Track 4D (Attribute Grammar Substrate Unification); any Prologos work touching equality saturation
**Related prior art**:
- [`2026-03-24_HYPERGRAPH_REWRITING_PROPAGATOR_PARSING.md`](2026-03-24_HYPERGRAPH_REWRITING_PROPAGATOR_PARSING.md) — landscape survey including e-graphs in DPO/IN/GoI context
- [`2026-03-28_MODULE_THEORY_LATTICES.md`](2026-03-28_MODULE_THEORY_LATTICES.md) §6 — e-graphs as quotient modules
- [`2026-04-21_TROPICAL_QUANTALE_RESEARCH.md`](2026-04-21_TROPICAL_QUANTALE_RESEARCH.md) — e-graph cost extraction via quantale residuation
- [`2026-04-30_LATTICE_VARIETY_AND_CANONICAL_FORM_FOR_SRE.md`](2026-04-30_LATTICE_VARIETY_AND_CANONICAL_FORM_FOR_SRE.md) — adjacent canonical-form discussion
- [`2026-04-30_PROPAGATOR_NETWORK_AS_SUPEROPTIMIZING_COMPILER.md`](2026-04-30_PROPAGATOR_NETWORK_AS_SUPEROPTIMIZING_COMPILER.md) — comparative landscape
- [`2026-05-02_PREDUCE_MASTER.md`](../tracking/2026-05-02_PREDUCE_MASTER.md) — PReduce series; primary consumer

---

## §1 Purpose and scope

### §1.1 Why this document exists

The PReduce series (founded 2026-05-02) commits to lifting reduction entirely onto the propagator network with e-graph + DPO + tropical-quantale + GoI as the algebraic substrate. PReduce Track 0.1 (architectural sketch) will reference e-graph operations heavily; PReduce Track 1+ implementation tracks consume e-graph theory directly.

Today's project documentation has e-graphs *referenced* across multiple research notes but no dedicated deep-dive — the coverage is fragmented. This note is the foundational anchor: cross-references from PReduce 0.1, future SH work, future PPN 4D, and any equality-saturation-related work point here for the foundational treatment, much as [`2026-04-21_TROPICAL_QUANTALE_RESEARCH.md`](2026-04-21_TROPICAL_QUANTALE_RESEARCH.md) anchors PPN 4C Phase 1B and downstream tropical-quantale work.

### §1.2 Thesis

E-graphs, when properly grounded in adhesive category theory + module theory, are not a separate engine bolted onto a compiler but a substrate-level infrastructure that fits naturally on the propagator network. The combination of (a) CHAMP structural sharing for hashcons, (b) monotone union-find as cell merge, (c) tropical-quantale extraction via residuation, (d) BSP-LE speculation for non-confluent rule scenarios, and (e) `.pnet` content-addressing for cross-session persistence gives Prologos's setting an architecturally-distinctive realization of equality saturation. The pieces compose because they all live on the same lattice-fixpoint substrate — not because we engineered a custom integration.

### §1.3 What we already have (Prologos context)

- **SRE Track 2D** ships 13 concrete DPO rewrite rules + structural-confluence-by-construction (`prop:ctor-desc-tag`); the rule-registry pattern PReduce generalizes
- **PPN 4C Phase 1B** ([Tropical Quantale Addendum](../tracking/2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_DESIGN.md)) is shipping the tropical-fuel quantale substrate including residuation operator — the cost-extraction algebra
- **BSP-LE Track 2B** ([PIR](../tracking/2026-04-16_BSP_LE_TRACK2B_PIR.md)) ships hypercube worldview Q_n + bitmask subcube pruning + ATMS speculation — the search infrastructure for non-confluent rule scenarios
- **PRN master** ([2026-03-26](../tracking/2026-03-26_PRN_MASTER.md)) conjectures e-graph + DPO unification; finds "E-graphs are adhesive (CALCO 2025)" already cataloged
- **Module Theory research** ([2026-03-28](2026-03-28_MODULE_THEORY_LATTICES.md)) §6 frames e-graphs as quotient modules
- **`.pnet`** content-addressable serialization exists; round-trip extension to network-as-value is SH Track 1

What we don't have: a focused survey covering e-graph foundations, theoretical grounding, production landscape, recent advances (2024-2026), performance characteristics, and Prologos-specific synthesis. This note delivers it.

### §1.4 Posture — depth-first formal grounding

Per user direction (2026-05-02): full depth treatment, mirroring `2026-04-21_TROPICAL_QUANTALE_RESEARCH.md`'s ~1000-line scope. Foundational sections (§2-§6) are literature-dense; synthesis sections (§7-§9) are Prologos-specific. Connections to interaction nets and Geometry of Interaction are mentioned briefly (§3.3) but not treated in depth — a separate IN/GoI survey can come later if needed.

---

## §2 Foundations: e-graph data structure and equality saturation

### §2.1 The data structure

An **e-graph** is a data structure that represents a set of expressions partitioned into equivalence classes. The classical presentation (Tate-Stepp-Tatlock POPL '09; Willsey et al. 2021):

- **E-nodes**: nodes labeled with an operator from a fixed signature `Σ`, with a list of children. Each child is a reference to an **e-class**, not to another e-node.
- **E-classes**: equivalence classes of e-nodes. Conceptually, an e-class is a set of e-nodes that have been proven equivalent.
- **Hashcons**: a map from `(operator, [child-e-class-ids])` to e-node-id, ensuring each distinct e-node appears at most once.
- **Union-find**: a disjoint-set structure on e-class-ids, supporting `find(c)` (canonical representative) and `union(c1, c2)` (merge classes).
- **Parent pointers**: for each e-class, the set of e-nodes that have this class as a child. Used during rebuild (§2.3).

Critical invariant — the **congruence closure invariant**: if e-node `f(a, b)` and e-node `f(a', b')` exist in the e-graph and `find(a) = find(a')` and `find(b) = find(b')`, then they are in the same e-class. This is the "if children are equal, parents are equal" rule that makes the e-graph more than a flat term-with-equalities table.

The e-graph thus represents an exponentially-large (sometimes infinite) set of equivalent expressions in a structurally-shared compact form. A single e-class can stand for "any of these equivalent expressions"; an e-graph with `n` e-classes can represent up to `O(2^n)` distinct equivalent expressions due to multiplicative combinatorics across child positions.

### §2.2 Core operations

The egg (Willsey et al. 2021) interface canonicalized three primary operations:

- **`add(node)`** — given an e-node `f(c1, ..., ck)` where each `ci` is an e-class id, return the e-class id containing this node. Uses hashcons to deduplicate; allocates a fresh e-class if novel.
- **`find(c)`** — return the canonical representative of the e-class containing `c` (union-find lookup with path compression).
- **`union(c1, c2)`** — merge the two e-classes. After union, `find(c1) = find(c2)`. May invalidate the congruence closure invariant temporarily.
- **`rebuild()`** — restore the congruence closure invariant by repairing hashcons collisions exposed by recent unions (§2.3).

Additional operations for equality saturation:
- **`match(pattern, e-class)`** — given a left-hand-side pattern with pattern variables, return all bindings under which the pattern matches some e-node in the e-class.
- **`apply(rule, bindings)`** — given a rule `lhs ⇒ rhs` and a substitution from match, add the rhs (with substitution applied) and union with the lhs's e-class.

### §2.3 The rebuild step

Rebuilding is the operation that maintains the congruence closure invariant after unions. The classical version (Tate-Stepp-Tatlock 2009; Nelson-Oppen 1980) interleaved rebuild with each union, giving worst-case `O(n²)` behavior. egg (Willsey et al. 2021) introduced **deferred rebuild**: batch unions, then rebuild once, exploiting the fact that congruence updates are themselves union-find merges that can be batched.

Algorithm (egg-style):
1. `union(c1, c2)` — record the union but do not propagate congruence
2. After a batch of unions: scan parent-pointer lists; for each pair of e-nodes where children's `find()` values now match, union their parent e-classes; repeat until fixpoint
3. Update hashcons to reflect canonicalized e-class-ids

Performance: deferred rebuild is sub-quadratic in practice — the empirical observation in egg's paper is "near-linear in the size of the e-graph for typical workloads." The key insight is that congruence cascades are bounded by the depth of the rule's application chain, which is typically small.

### §2.4 Equality saturation algorithm

Equality saturation runs the following loop:

```
while not saturated:
    matches = {}
    for rule in ruleset:
        matches[rule] = match(rule.lhs, e-graph)
    for rule, all_bindings in matches:
        for binding in all_bindings:
            apply(rule, binding)
    rebuild()
```

The loop continues until either (a) no rule application produces new e-nodes or unions (true saturation), or (b) a fuel/iteration/size budget is exhausted (bounded saturation). True saturation is decidable for terminating rule systems but undecidable in general; bounded saturation is the practical default.

Critical property: **rule application is monotone — the e-graph only grows**. New e-nodes are added; existing e-nodes are never removed. E-classes only merge; they never split. This is precisely the CALM-compatible monotone discipline (Hellerstein 2010) and matches the propagator network's structural commitment.

### §2.5 Extraction

After saturation, each e-class represents a set of equivalent expressions; we want to *extract* the "best" one according to some cost function. Formally:

- **Cost function**: `cost : Term → ℝ` (or any totally-ordered tropical-semiring valuation).
- **Extraction problem**: given an e-class `c`, find the term `t` representable from `c` with minimum cost.

A term is *representable from `c`* if it can be built by recursively choosing one e-node from each visited e-class, starting at `c`.

**Greedy / local extraction**: for each e-class, choose the e-node with minimum self-cost + sum of child e-classes' minimum costs. Bottom-up dynamic programming. Runs in `O(|e-graph|)`. Sound when costs are *additive* and *non-negative*.

**ILP-based extraction**: encode as integer linear program; optimal but exponential worst-case. Used when greedy is unsound (e.g., common-subexpression sharing changes cost calculations).

**NP-hardness in general**: extraction with sharing-aware cost (where reused e-classes count once, not per use) is NP-hard. The greedy algorithm above effectively assumes tree-shaped extraction (each e-class instance counts independently); sharing-aware DAG extraction requires more sophisticated techniques.

### §2.6 Termination and saturation discipline

Equality saturation may not terminate. A rule like `x ⇒ x + 0` always produces a new representation; if applied unboundedly, the e-graph grows without bound.

Practical disciplines:
- **Iteration cap**: stop after `N` saturation rounds.
- **Size cap**: stop when the e-graph exceeds a node/class budget.
- **Fuel-bounded**: each rule application consumes fuel; stop when fuel is exhausted (this is the tropical-quantale framing — see §7.5).
- **Termination-by-design**: prove the rule system is terminating using term-rewriting termination techniques (recursive path orderings, polynomial interpretations). The `egg` book gives examples; the tropical-quantale extraction view (§7.5) gives a different angle.

For our setting: the tropical fuel cell (PPN 4C Phase 1B) provides a principled bound; we fuel-bound by default and graduate to terminating rule systems where provable.

### §2.7 Worked examples

**Arithmetic optimization**:
- Rule: `x * 2 ⇒ x + x`
- Rule: `x + x ⇒ x * 2`
- Starting term: `(a * 2) * 2`
- After saturation: e-graph contains `(a * 2) * 2`, `(a + a) * 2`, `(a * 2) + (a * 2)`, `(a + a) + (a + a)`, `a * 4`, etc.
- Extraction with cost = number of multiplications: `a + a + a + a` if multiplication is expensive; `a * 4` if multiplication is cheap.

**Instruction selection** (Tate-Stepp-Tatlock 2009): patterns target specific machine instructions; cost reflects cycle counts; extraction picks the optimal lowering. The rules essentially encode "this AST fragment can be implemented as that instruction sequence."

**Tensor reasoning** (egg's spire / TASO line): tensor algebra rewrites with cost = FLOPs or memory traffic; extraction picks computation-graph layout.

For Prologos: β/δ/ι reduction rules are the immediate target; structural-decomposition rules (currently SRE-Track-2D) generalize naturally; future optimization rules (constant folding, common-subexpression elimination, etc.) layer atop.

---

## §3 Theoretical grounding

### §3.1 Adhesive category theory and e-graphs

**Theorem (Biondo, Castelnovo, Gadducci CALCO 2025)**: e-graphs form an adhesive category.

**What adhesive means** (Lack-Sobocinski 2005): a category is **adhesive** if pushouts along monomorphisms exist and satisfy a "van Kampen" condition that ensures pushout squares compose well. Adhesive categories axiomatize the conditions for DPO (Double-Pushout) graph rewriting to be well-behaved.

**Consequences for e-graphs**:
- DPO rewrite rules over e-graphs are well-behaved (rule application has the expected algebraic properties)
- Equality saturation can be understood as iterated DPO rewriting
- Confluence and parallelism analysis tools for adhesive categories apply directly
- Critical pair analysis transfers (when do two rule applications conflict?)
- Local Church-Rosser, parallelism, concurrency theorems all transfer

This is the foundational result that connects e-graph theory to the mature graph-transformation literature. Prior to CALCO 2025, e-graph rewriting was understood operationally (algorithm + invariant) but not categorically grounded in a way that gave systematic transfer of theorems.

**For Prologos**: SRE Track 2D already uses DPO rewriting via adhesive structure (parse trees as adhesive, per [`2026-04-03_ADHESIVE_CATEGORIES_PARSE_TREES.md`](2026-04-03_ADHESIVE_CATEGORIES_PARSE_TREES.md)). E-graphs being adhesive means the same theoretical machinery applies to PReduce's e-class cells and rewrite rules. We don't need a separate framework; the SRE foundations transfer.

### §3.2 E-graphs as quotient modules

The Module Theory research ([`2026-03-28_MODULE_THEORY_LATTICES.md`](2026-03-28_MODULE_THEORY_LATTICES.md)) §6 frames e-graphs as **quotient modules** in the quantale-module framework:

- The free module of terms over a signature is the term-graph itself
- The rewrite rules generate a congruence relation
- The e-graph is the quotient module by this congruence
- Cost-guided extraction is **residuation** on the quotient module: given a target e-class and a cost lattice, residuation finds the minimum-cost preimage

This frames extraction algebraically rather than combinatorially. The greedy algorithm (§2.5) is the residuation computation in the tropical quantale `T_min = ([0,∞], min, +)`. ILP-based extraction is residuation in a richer cost quantale where sharing is encoded structurally.

**Key formula**: extraction = `cost \ e-class` where `\` is the tropical residual. By Tropical Quantale Research §5 ([`2026-04-21_TROPICAL_QUANTALE_RESEARCH.md`](2026-04-21_TROPICAL_QUANTALE_RESEARCH.md) §5.1-5.6), this residual exists, is computable, and has clean formulas in the tropical case.

This is load-bearing: it tells us that PPN 4C Phase 1B's residuation operator (already shipping) is the EXTRACTION ALGORITHM for PReduce. We don't engineer an extractor — we use the residual.

### §3.3 Brief: connections to interaction nets and Geometry of Interaction

E-graphs are not the only "rewriting with sharing" model. Two adjacent traditions:

**Interaction nets** (Lafont 1990, 1997): graph-rewriting where each agent has a fixed number of typed ports (one principal); rules apply only at principal-port interactions; rules are local. Strong confluence (rule order doesn't matter) is built in. **HVM2** ([Taelin / HigherOrderCO](https://github.com/HigherOrderCO/HVM2)) implements interaction-combinator runtime with Lévy-optimal sharing — each shared subterm reduces at most once. The HVM2 sharing-and-duplication primitives play the role e-class union-find plays in e-graphs.

**Geometry of Interaction** (Girard 1989; Mackie 1995; Muroya-Ghica DGoIM 2017-2018): cut-elimination as a fixpoint of token-passing on a graph. The execution formula `I + σπ + (σπ)² + ...` IS a propagator-network fixpoint computation (per [`2026-03-22_CATEGORICAL_FOUNDATIONS_TYPED_PROPAGATOR_NETWORKS.md`](2026-03-22_CATEGORICAL_FOUNDATIONS_TYPED_PROPAGATOR_NETWORKS.md) §10.3).

**The connections, briefly**:
- HVM2's sharing-via-explicit-duplication is a different realization of the "shared subterm reduces once" property that e-class union-find delivers
- GoI's token-passing fixpoint is operationally similar to equality-saturation iteration (both are fixpoint computations on graph-shaped data)
- E-graphs subsume both perspectives in the sense that an e-class IS the equivalence-up-to-sharing that interaction-net combinators preserve, and IS the equivalence-up-to-cut-elimination that GoI computes

For PReduce: the rule-property-tag approach (§7.6 below) gives us a clean way to mix these perspectives — IN-fragment rules get strong-confluence + Lévy-optimal sharing guarantees; non-IN rules get adhesive-DPO + critical-pair handling; both write to the same e-class cells. A future research note focused on IN/GoI specifically can deepen this; for our purposes here, e-graph theory is the unifying frame.

### §3.4 Connection to Datalog / egglog

**egglog** ([Better Together](https://news.ycombinator.com/item?id=35593635); Zhang et al. 2023) unifies egg with Datalog by treating equality as a first-class predicate in a logic program. The resulting system:
- Expresses both Datalog rules and equality-saturation rules in one language
- Compiles to an efficient evaluator that handles both monotone fact accumulation and e-class management
- Supports advanced features (subsumption, lattice values per e-class, etc.)

This matters for Prologos because:
- Datalog evaluation = monotone fixpoint = propagator network quiescence (we've established this)
- E-graph operations = cell allocation + monotone merge (equality-saturation = propagator quiescence at the merged-cell level)
- Both compose naturally on our substrate
- egglog's cell-with-lattice-value semantics matches what we already do (cells with monotone merge)

**Implication**: egglog's design choices are directly informative for PReduce's lattice design. Particularly: egglog's "lattice analysis" (each e-class can have a per-class lattice value, joined on union) is the same pattern as our cost-cell-per-e-class.

---

## §4 Production landscape

### §4.1 egg (Willsey et al. 2021)

**egg** ([arXiv:2004.03082](https://arxiv.org/abs/2004.03082)) is the canonical modern e-graph library, written in Rust. Key contributions:
- Deferred rebuild for sub-quadratic performance
- E-class analysis: per-e-class data with monotone merge (used for type information, constant folding, dataflow analysis)
- Pattern matching with bindings
- Open-source, embedded in many subsequent systems

**Production users**: Cranelift's mid-end optimizations (acyclic variant, see §4.3); SPORES (linear algebra); Tensat (tensor compilation); Diospyros (vectorization); Fast Fourier Transform synthesis. egg's reach is significant.

**Limitations**: in-memory data structure; no incremental persistence story prior to Schlatt 2026; pattern matching is term-rewriting-style rather than higher-order; binding handling is hand-rolled per-application.

**For Prologos**: egg is the design reference. We won't link against it (we're on a different substrate), but its operational shapes guide our cell layout and rebuild scheduling. Notable: egg's batched-rebuild matches our BSP-round semantics — propagators fire concurrently within a round, then the merge happens at the round boundary. This is structurally aligned.

### §4.2 egglog

**egglog** unifies egg with Datalog — equality saturation rules and Datalog rules in one language ([Better Together](https://news.ycombinator.com/item?id=35593635)). Treats equality as a first-class predicate, evaluates via efficient Datalog backend, supports advanced features (lattice values, subsumption, schedules).

**Why it matters**: egglog demonstrates that e-graphs are a special case of monotone Datalog computation. This is exactly the framing PReduce uses — monotone propagator-network fixpoint with cell-merge corresponding to Datalog's monotone semantics. egglog's design choices (rule scheduling, schedule expressions, multi-stratum execution) inform PReduce's architecture.

**Specifically**: egglog's lattice-value-per-eclass mechanism is the direct analog of our cost-cell-per-e-class plan (§7.5). The schedule expressions language gives a precedent for how rule-property-tag dispatch (§7.6) could be exposed at the user-facility level (out of scope for current implementation but design-relevant).

### §4.3 Cranelift acyclic e-graphs

**Cranelift** (the WebAssembly + native compiler used by Wasmtime) uses an **acyclic e-graph** variant for mid-end optimizations ([egraphs.org meeting notes](https://egraphs.org/meeting/2025-08-21-dialegg)). The "acyclic" restriction:
- Single-pass eager rewriting, not full equality saturation
- Each e-class can only be added to (never removed); no fixpoint iteration
- Bounded saturation by construction (no termination concern)

**Trade-off**: Cranelift achieves production-grade performance at the cost of acyclicity, which limits expressiveness. Some valuable optimizations (e.g., those requiring back-and-forth rewriting) cannot be expressed.

**For Prologos**: Cranelift's pragmatic compromise is informative but not necessary for us. The adhesive guarantees give correctness for full saturation; the BSP scheduler bounds cost; tropical residuation gives termination via fuel exhaustion. We don't have to give up expressiveness for performance — the substrate handles both. Cranelift's choice is what you'd do without our infrastructure.

### §4.4 DialEgg (CGO 2025)

**DialEgg** ([CGO 2025](https://2025.cgo.org/details/cgo-2025-papers/44/DialEgg-Dialect-Agnostic-MLIR-Optimizer-using-Equality-Saturation-with-Egglog)) integrates egglog with MLIR dialect-agnostically. Allows MLIR optimization passes to be expressed as egglog rules and run via the egglog backend over MLIR's dialect IR.

**For Prologos**: DialEgg validates the "e-graphs as general compiler infrastructure" thesis — they're not a special-purpose tool. Our substrate goes further (the substrate IS the IR rather than a separate engine over the IR), but DialEgg confirms that e-graphs work over typed/structured IRs, not just untyped term graphs.

### §4.5 eqsat MLIR dialect

**eqsat MLIR dialect** ([arXiv:2505.09363](https://arxiv.org/html/2505.09363v1)) proposes representing e-graphs *as* an MLIR dialect, allowing equality saturation on arbitrary domain-specific IRs without bolting on a separate engine.

This is the closest existing-system analog to Prologos's "the substrate IS the IR" position. The eqsat MLIR dialect makes e-graph state into a first-class IR construct; we make it cell-state on the propagator network. Both move e-graphs from "tool you call" to "structure that lives inside the compilation substrate."

### §4.6 Schlatt 2026: persistent compiler abstraction

**Schlatt et al.** "E-Graphs as a Persistent Compiler Abstraction" ([arXiv:2602.16707](https://arxiv.org/abs/2602.16707), February 2026) proposes representing e-graphs natively in the compiler's IR rather than as a separate optimization phase. Key insight: if the e-graph persists throughout compilation, equality information discovered during one phase is available to all subsequent phases. This avoids the "information loss" problem where an early phase discovers equalities that a later phase could use but cannot access.

The implementation (using xDSL and MLIR) introduces an `eqsat` dialect that represents e-graph equivalence classes directly in the IR. Pattern rewriting can be interleaved with other compiler transformations, with the e-graph maintaining all discovered equalities.

**For Prologos**: Schlatt 2026 is the architectural cousin closest to our setting. Their `eqsat` dialect role is filled in our setting by e-class cells on the propagator network. Their persistence story (e-graph persists through compilation) maps to our cell-state persistence (`.pnet` round-trip + content-addressing). They report that persistent e-graphs unlock optimizations across phase boundaries; we get the same benefit by virtue of the unified-substrate architecture, not as a separate add-on.

### §4.7 Production maturity assessment

Equality saturation moved from "specialized tool" to "general compiler infrastructure" between 2021 (egg) and 2026 (Schlatt persistent abstraction; eqsat MLIR dialect). The frontier is moving, but production integration is still uneven:

| System | E-graph maturity | Persistence | Integration depth |
|---|---|---|---|
| egg | Library | None | Application-specific |
| egglog | Library + DSL | None (in-memory) | Application-specific |
| Cranelift | Acyclic only | None (per-function) | Compiler-internal |
| DialEgg | Research | None | MLIR plug-in |
| eqsat MLIR | Research | Per-dialect | First-class IR |
| Schlatt 2026 | Research | Cross-phase | First-class IR |
| **Prologos PReduce target** | First-class | Cross-session via `.pnet` | Substrate-level |

The trend line points where Prologos is heading. Schlatt 2026 is the closest existing peer; PReduce's combination of substrate-level integration + cross-session persistence + tropical-quantale extraction + BSP-LE speculation is novel.

---

## §5 Recent advances (2024-2026)

### §5.1 E-Graphs Modulo Theories

**E-Graphs Modulo Theories** ([arXiv:2504.14340](https://arxiv.org/html/2504.14340), 2024) extends e-graphs to handle theory reasoning (linear arithmetic, uninterpreted functions, etc.) natively, akin to SMT-solver theory combinators. Each e-class can carry theory-specific information; theory propagators discover new equalities during saturation.

**For Prologos**: this is the bridge to our trait-resolution and constraint-system infrastructure. Theory-level reasoning (e.g., "these two trait constraints are equivalent given the current dictionary resolution") naturally fits as theory-aware e-classes. The propagator-network substrate gives us the theory-propagator pattern for free; we don't need a separate theory-combination architecture.

### §5.2 E-Graphs with Bindings (Moss 2025)

**Moss** "E-Graphs with Bindings" ([arXiv:2505.00807](https://arxiv.org/abs/2505.00807), 2025) addresses one of e-graphs' classical weaknesses: handling lambda-calculus-style binders. Standard e-graphs treat terms as ground; α-equivalent terms with bound variables are not naturally identified. Moss 2025 introduces explicit binder-aware e-class structure that handles α-equivalence, capture-avoiding substitution, and de Bruijn-like indexing within the e-graph framework.

**For Prologos**: this is **load-bearing for PReduce**. Prologos has dependent types, lambdas, sigmas, pis — binder-rich constructs throughout. Without binder-aware e-graph theory, naive e-graph encoding would either (a) break α-equivalence (treating `λx.x` and `λy.y` as distinct), or (b) require a custom substitution mechanism layered atop classical e-graphs.

Moss 2025's approach gives us the theoretical handle. Implementation-wise, the binder structure interacts with our existing substitution + zonking infrastructure (which handles bound variables via de Bruijn indices) — PReduce can reuse those mechanisms with e-class wrapping. The integration is non-trivial but well-grounded; expect this to be a major design topic in PReduce Track 0.1's e-class cell sub-model.

### §5.3 Colored e-graphs (context-sensitive equivalences)

**Colored e-graphs** generalize standard e-graphs to support context-sensitive equivalences: an equality `f(x) ≡ g(x)` may hold under one set of assumptions and not another. Each e-class is "colored" by the assumption set under which its equivalences hold; merging e-classes requires compatible colorings.

The original "Colored E-Graphs: Abstract Interpretation with Equality Saturation" framing (Singher-Itzhaky 2023, in ICFP venue) introduced the construction; subsequent work extends it to richer color algebras.

**For Prologos**: colored e-graphs map directly to our **worldview-tagged e-classes** (§7.8 below). BSP-LE 2B's bitmask-tagged-cell-value pattern is the operational realization; colored e-graphs provide the theoretical grounding. An e-class equivalence discovered under worldview `wv1` is colored by `wv1`; a different worldview `wv2` sees its own equivalences; merging requires worldview compatibility (subset, intersection, etc., per BSP-LE 2B's tagging algebra).

This means: BSP-LE 2B's tag system + colored-e-graph theory + tropical-quantale residuation give us a principled framework for **speculative cost-bounded reduction with retraction-aware persistence**. Each piece is independently developed; PReduce assembles them.

### §5.4 LLM-guided strategy synthesis

**LLM-Guided Strategy Synthesis for Scalable Equality Saturation** ([arXiv:2604.17364](https://arxiv.org/html/2604.17364v1), 2026) uses LLMs to discover effective rewriting strategies for equality saturation, addressing the "saturation explosion" problem (e-graph grows too large too fast) by guiding rule application.

**For Prologos**: not in immediate scope, but architecturally compatible. Our network-as-data architecture would let LLMs propose new propagators (rewrite rules) directly as data — the rule registry (§7.6) is a CHAMP cell from rule-id to rule-data, so adding rules at runtime is structurally identical to adding them at compile time. LLM-proposed rules would need property-tag analysis (which stratum?) but otherwise integrate cleanly.

Worth experimenting once the substrate is in place. Not a near-term track.

### §5.5 Persistent compiler abstraction (revisited)

Schlatt 2026 (cited in §4.6) deserves mention here as well — it's the closest peer to Prologos's vision. Three pieces:

1. **E-graph persistence across compilation phases**: equality information from earlier phases available to later phases.
2. **First-class IR construct**: the `eqsat` dialect makes e-graph state visible in the IR, not hidden in a separate optimization engine.
3. **Cross-pass interleaving**: rewrites can be applied alongside lowering, type inference, etc., rather than as a phase.

Prologos PReduce's "substrate IS the IR" position generalizes all three. Phases ARE strata in our setting; cross-phase information flow IS cell-state propagation; first-class IR construct IS cell-id assignment. Schlatt 2026 is the proof-of-concept that persistent e-graphs unlock cross-phase optimization; PReduce extends it to cross-session persistence via `.pnet`.

---

## §6 Performance characteristics

### §6.1 Termination and saturation bounds

**True saturation** (no rule produces new e-nodes or unions) is decidable for terminating rule systems but undecidable in general. **Bounded saturation** (iteration cap or size cap or fuel) is the practical default.

- **Iteration-bounded**: cap `N` rounds; deterministic; loses theoretical optimality
- **Size-bounded**: cap node/class count; degrades gracefully under explosion
- **Fuel-bounded** (tropical-quantale framing, §7.5): each rule application consumes fuel; stop at exhaustion; principled cost-aware termination
- **Termination-by-design**: prove rule system terminates via term-rewriting techniques (recursive path orderings, polynomial interpretations)

For Prologos: fuel-bounded is the substrate-aligned default (PPN 4C Phase 1B ships the tropical fuel cell). Termination-by-design is reachable for restricted rule subsets (β/δ in normal form; structural decomposition). Iteration-bounded and size-bounded are degraded fallbacks.

### §6.2 E-class explosion

The "e-class explosion" problem: applying rules can grow the e-graph faster than useful. Common pathologies:
- **Identity rules** (`x ⇒ x + 0`) blow up the e-graph linearly per round
- **Distributive rules** (`a*(b+c) ⇒ a*b + a*c`) can blow up combinatorially
- **Symmetric rules** (`a + b ⇒ b + a` AND `b + a ⇒ a + b`) cause oscillation

Mitigations:
- **Conditional rules**: apply only when a condition is met (e.g., `x ⇒ x + 0` only if no addition exists)
- **Rule scheduling**: priority-based; cheap-rules-first; egglog's schedule expressions formalize this
- **Subsumption**: when an equivalence is "obviously implied," don't re-derive it
- **Cost-bounded rule application**: don't apply a rule if it raises cost above threshold

For Prologos: the propagator scheduler is already round-based; rule scheduling at the round level falls out of the BSP discipline. The tropical fuel cell prevents unbounded growth. The set-latch + threshold pattern (per `propagator-design.md` § Set-Latch for Fan-In Readiness) gives us natural backpressure on rule applications.

### §6.3 Extraction complexity

Extraction with non-shared cost (each e-class instance counts independently): **polynomial** via greedy DP — `O(|e-graph|)`.

Extraction with sharing-aware cost (each e-class counted once regardless of uses): **NP-hard** in general. Approaches:
- **ILP-based**: optimal but exponential worst-case; usable for small e-graphs
- **Greedy approximation**: polynomial; suboptimal but typically close
- **Sampling-based**: Monte Carlo extraction; good empirical results
- **Learned heuristics**: neural-network-guided extraction (recent egg work)

For Prologos: tropical residuation gives the algebraic frame; concrete algorithm choice depends on rule-property analysis. For confluent rule subsets (interaction-net-fragment), greedy is optimal because there's no cost-relevant choice to make. For non-confluent rules (where multiple rewrites give different costs), residuation-via-DP is the polynomial-time approximation; residuation-via-ILP is the optimal exponential option.

### §6.4 Cache locality and memory layout

Production e-graph implementations care deeply about memory layout:
- **Hashcons table** dominated by hash-table operations; cache-friendly hash table layouts (hopscotch hashing, robin hood) are common
- **Union-find** with path compression is highly cache-unfriendly without optimization; rank-balanced union-find with periodic rebuild is better
- **Parent pointers** form a sparse graph; vector-of-vectors layouts vs CHAMP-like persistent structures trade insert speed for query speed

For Prologos: CHAMP gives us structural sharing for free. Our cells are CHAMP-resident; e-class cells inherit CHAMP's cache behavior. The empirical question is whether CHAMP's branching factor (typically 32) pessimizes the typical e-graph access pattern (small-class lookups dominated by union-find finds). Likely answer: it's fine — CHAMP's path lengths are bounded by `log_32(N)` which is `≤ 6` for `N ≤ 10^9`.

`.pnet` content-addressing introduces an additional locality concern: cross-session loads must fetch e-class fragments from disk. The chunking strategy (per Track 0.3 design) determines how this performs at scale. For modest programs (thousands of e-classes), full-load-on-startup is fine; for very large programs (millions), demand-loading with locality-aware prefetch is needed.

### §6.5 Empirical performance signatures

Drawing on the egg paper and subsequent benchmarks:
- **Saturation time** for typical workloads: linear-to-near-linear in final e-graph size
- **Memory** for typical workloads: 10-100x the input term size (depending on rule density and equivalence richness)
- **Extraction time** with greedy: linear in e-graph size; with ILP: exponential worst-case but typically tractable for modest e-graphs

For PReduce: we expect comparable signatures, with CHAMP overhead adding a constant factor (~2x slower than egg's hand-rolled hashcons). The trade is structural sharing across cells, content-addressability, and `.pnet` round-trip — properties egg doesn't have. The constant-factor cost is amortized by skipping recompute (cross-session cache hits) and by the substrate's parallel BSP scheduling (which egg doesn't exploit).

---

## §7 Prologos synthesis

### §7.1 E-class cells on the propagator network

The keystone realization: **each e-class is a cell on the propagator network**. Specifically:

- **Cell value**: the e-class state — set of e-nodes, representative, accumulated cost, equivalence-witness provenance
- **Merge function**: union-find merge — when two cells are unioned, take the union of e-node sets, resolve cost via tropical-min, accumulate provenance
- **Cell-id assignment**: structural hash of the canonical representative — content-addressing built in
- **Parent-pointer structure**: bidirectional cell references (e-class cell has parent-list as compound-component; updated monotonically)

Per SRE lattice lens (Q1): e-class cell is **structural** (multiple components: e-node set, representative, cost, provenance). NTT declaration: `:lattice :structural :order :refinement`.

The refinement-poset structure (`A ≤ B` iff every term in A is in B) is critical — it's what extraction's residuation walks. The poset is **not** a lattice because it has no joins in general (two unrelated e-classes have no common refinement); it's a meet-semilattice (intersections always exist). Cost-extraction operates on the meet-semilattice via residuation.

### §7.2 Hashcons via CHAMP structural sharing

Hashcons is the operation: given `(operator, [child-e-class-ids])`, return a canonical e-node id, deduplicating if the same combination has been seen before.

CHAMP delivers this for free:
- The hashcons "table" is a CHAMP cell from `(operator, child-ids)` → e-node-id
- `add(node)` writes to this cell; CHAMP's structural-sharing-by-content makes duplicates idempotent
- `eq?` on CHAMP keys gives structural equality testing in O(1) for shared structures

This is a substantive engineering simplification: we don't write a hashcons module; we use the CHAMP infrastructure already shipped. The cost (CHAMP's branching-factor-32 lookups) is the price paid for free structural sharing across all cells, not just hashcons. Net: positive.

### §7.3 Union-find as monotone merge

Union-find on cells:
- Each e-class cell has a "canonical-representative" component; reads via `find(c) := follow canonical-pointer chain to root`
- `union(c1, c2)` writes to the cells: link one's canonical-pointer to the other's root
- Path compression: monotone (paths only shorten); applies during `find`
- Rank-balancing: heuristic; not load-bearing for correctness

The merge function on the canonical-representative component is **monotone** in the union-find sense: pointers only move toward the root, never away. This is CALM-compatible.

A subtlety: the union operation involves reading the root of one cell and writing it as the canonical-pointer of another. This is two cells interacting via propagator dataflow. In the propagator-network realization, union is a propagator that watches one cell, computes root, and writes to another's canonical-pointer component.

### §7.4 Adhesive guarantees inherited

Per Biondo-Castelnovo-Gadducci CALCO 2025 (§3.1 above), e-graphs form an adhesive category. The adhesive structure means DPO rewriting is well-behaved on e-graphs.

For Prologos: SRE Track 2D already uses DPO rewriting via adhesive structure (parse trees). E-class cells being adhesive means:
- The same DPO machinery applies — we don't need a separate framework for e-graph rewriting
- Critical-pair analysis gives us confluence detection
- Local Church-Rosser and parallelism theorems transfer
- Our existing `prop:ctor-desc-tag` confluence-by-construction approach for structural decomposition is one specific use; rewriting rules with critical pairs are handled by the adhesive analysis

The PRN master's universality observation ("rule registration as universal primitive") is realized: we have ONE rule registry, with property tags determining which adhesive-category-theorem applies to which rule.

### §7.5 Tropical-quantale extraction via residuation

Cost-guided extraction = **residuation in the tropical quantale**.

Concretely:
- Each e-class cell has a cost component in `T_min = ([0,∞], min, +)`
- Cost merge on union: take the minimum (cheapest derivation wins) — Viterbi-style semiring parsing
- Extraction = compute `cost \ e-class-id` via the tropical residual operator
- The residual operator is the Phase 1B deliverable in PPN 4C (already in design); PReduce consumes it

The clean operational meaning: given an e-class and a cost budget `B`, residuation finds the minimum-cost term representable from the e-class with total cost ≤ B. If no such term exists, residuation yields `+∞` (infeasible).

For confluent rule subsets, this is polynomial (greedy DP via tropical-residual recursion). For non-confluent rules, this is the algebraic specification; concrete algorithms (ILP, sampling, heuristic) are residual approximation strategies.

The key architectural realization: **we don't need to engineer an extractor**. The extraction algorithm IS the residual operator that PPN 4C Phase 1B already ships. PReduce inherits the algebra.

### §7.6 BSP-LE speculation for non-confluent rules

When rules are non-confluent (two rules can both apply but produce different results), classical e-graph saturation tracks both alternatives in the same e-graph (both are added; both are merged into the e-class via union). This works, but doesn't give us **branch-aware cost analysis** — we can't easily ask "what's the cost if we apply rule A but not rule B."

BSP-LE 2B's hypercube worldview gives us this: each branch is a worldview bit; rule applications can be tagged with the worldview they were applied under; cost-bounded ATMS exploration prunes branches whose cost exceeds budget.

The integration:
- E-class cells use **bitmask-tagged-cell-value** (BSP-LE 2B pattern) — each equivalence is tagged with the worldview where it was discovered
- Worldview-narrow reads return only the equivalences valid in the current worldview
- ATMS branching at non-confluent rule applications creates worldview branches
- Tropical cost per branch = sum of cost contributions tagged with that branch's worldview
- Subcube pruning (BSP-LE 2B Phase 3) eliminates worldview combinations whose cost exceeds budget

This is the **4-level optimization strategy** from [`2026-03-26_KAN_EXTENSIONS_ATMS_GFP_PARSING.md`](2026-03-26_KAN_EXTENSIONS_ATMS_GFP_PARSING.md) realized for reduction:
1. ATMS branches at non-confluent rule applications (full exploration)
2. Left Kan partial-info forwards reduce premature commitments
3. Right Kan demand-driven focus restricts exploration to demanded e-classes
4. Tropical cost-bounded extraction selects the cheapest viable branch

The four levels compose because they're different lenses on the same propagator-network fixpoint.

### §7.7 `.pnet` content-addressing for cross-session persistence

Schlatt 2026's persistent-compiler-abstraction story extends across sessions for free in our setting:

- Each e-class cell has a structural hash (CHAMP-derived)
- `.pnet` serialization preserves cell IDs (when SH Track 1 lands; design context for PReduce Track 0.3)
- Content-addressed `.pnet` fragments can be loaded on demand
- Two `.pnet` fragments with the same hash are not just bit-equal — they're fixpoint-equal with the same derivation tree

The cross-session story:
- Compile a module → e-class state populated → serialize via `.pnet`
- Future compilation of dependent module → load e-class fragments by hash → equalities discovered in earlier compilation are immediately available
- No saturation re-run needed for ground-regime e-classes

This is the persistence vision. Caveats per §5 of the [PReduce master](../tracking/2026-05-02_PREDUCE_MASTER.md) Open Question 6: retraction-eligible equalities consult the retraction state before promotion to ground regime; contextual equalities persist with worldview tags; truly open templates persist as rules, not values. The regime split governs what can be cross-session-cached.

### §7.8 Worldview-tagged e-classes (colored × bitmask)

Synthesis of §5.3 (colored e-graphs) and BSP-LE 2B's tagged-cell-value:

- Each equivalence in an e-class carries a worldview tag (bitmask)
- Reads narrow by worldview: only equivalences valid in the current worldview are visible
- Speculative branches each see their own equivalences without cross-contamination
- Retraction (S(-1) stratum) invalidates worldview tags whose hypothesis was withdrawn
- Persistence (§7.7) consults worldview tags before promoting to ground regime

This is the **fully principled speculative-cost-bounded-reduction-with-persistence** architecture. Each piece:
- Colored e-graph theory (§5.3) — the equivalences are color-tagged
- BSP-LE 2B bitmask (Hypercube addendum) — operational realization of color tags
- Tropical-quantale extraction (§7.5) — cost-bounded extraction respecting worldview narrowing
- `.pnet` content-addressing (§7.7) — persistence with retraction-bit consultation

Coordinates to land: PReduce Track 1 ships e-class cells with bitmask-tagged-cell-value; Track 4 lands worldview-aware extraction; Track 5 lands worldview-aware persistence; Track 6 lands ATMS-driven branch creation.

### §7.9 The unified rule registry

PRN master §3 lists "rule registration" as a confirmed universal primitive. PReduce realizes it:

- One CHAMP cell `rule-registry-cid` from rule-id → rule-data
- Rule-data carries property-tag declarations (IN-fragment / adhesive-DPO / confluence-by-construction / non-monotone / opaque)
- The propagator scheduler dispatches rule application based on property tags
- SRE form-registry rules (structural decomposition) integrate as one rule kind with `confluence-by-construction` tag
- PReduce rewrite rules (β/δ/ι/optimization) integrate as additional rule kinds

This generalizes the SRE form-registry pattern to the full rewriting substrate. The architecture is **one registry, many consumers** — analogous to how a database has one schema and many query patterns.

### §7.10 Architectural summary

PReduce's e-graph realization is the composition of nine pieces:

1. **E-class cells** (§7.1) — substrate atom; structural-poset cell value
2. **CHAMP hashcons** (§7.2) — content-addressed structural sharing; free
3. **Union-find as monotone merge** (§7.3) — CALM-compatible cell merge
4. **Adhesive guarantees inherited** (§7.4) — DPO machinery applies; SRE Track 2D foundation
5. **Tropical-quantale extraction** (§7.5) — residuation as the algorithm; PPN 4C 1B substrate
6. **BSP-LE speculation** (§7.6) — worldview-tagged branches; cost-bounded ATMS
7. **`.pnet` content-addressing** (§7.7) — cross-session persistence for ground regime
8. **Worldview-tagged e-classes** (§7.8) — colored × bitmask × retraction-aware
9. **Unified rule registry** (§7.9) — one CHAMP, property-tagged rules, scheduler dispatch

Each piece is independently grounded in literature or in shipped Prologos infrastructure. The composition is novel; the substrate is what makes the composition fall out without engineering effort.

---

## §8 Open frontiers for our setting

### §8.1 E-graphs × dependent types

E-graph rewriting in dependently-typed settings is partially explored (Moss 2025 E-Graphs with Bindings handles α-equivalence and substitution; not full dependent type theory). Open questions:

- Type-level e-classes — `Vec n A` and `Vec m A` should be in the same e-class iff `n ≡ m`; how does e-class merging interact with the type-level equality propagator?
- Eta equivalence at the type level — `Π (x : A). B[x] ≡ Π (x : A). B[x]` (trivial) vs `Π (x : A). f x ≡ f` (function eta — when does it hold?)
- Universe polymorphism — equivalences across universe levels need careful handling
- Coercion handling in e-classes (related to subtyping)

For Prologos: PUnify Phase -1 already discovered the coupling between cell-level meta solutions and trait resolution (`solve-meta!` bridge); analogous coupling will exist between e-class equivalences and trait/universe/coercion resolution. PReduce Track 0.1 should name this as a load-bearing open question.

### §8.2 E-graphs × QTT erasure

QTT (Quantitative Type Theory) tracks usage multiplicities — `m0` (erased), `m1` (linear), `mw` (unrestricted). Two terms can be type-equal but multiplicity-distinct (different usage profiles). When does e-class equivalence respect multiplicity?

Open question: should erased subterms be in the same e-class as their non-erased counterparts? Argument for: they have the same value-level meaning. Argument against: they have different runtime cost (one is erased, one isn't). Resolution likely: cost lattice encodes the difference; same e-class, different cost.

### §8.3 E-graphs × capability typing

Capability typing tracks effects via type witnesses. Two terms can be value-equivalent but capability-distinct (one has IO capability, one doesn't). E-class membership respect:
- Capability-equivalent → same e-class (likely)
- Capability-distinct → distinct e-classes (likely; otherwise we lose effect tracking)

Implementation: capability witnesses become part of the e-class structural identity. Witnesses participate in the canonical-representative computation.

### §8.4 E-graphs × session types

Session types describe communication protocols. Two protocols can be subtype-related but not equal. E-class structure for session types interacts with the duality and session-protocol-equivalence theory developed in SRE Track 1+ and effect-executor.rkt.

Open question: is session-type equivalence an e-class congruence? Does session-protocol normalization integrate as a rewrite rule kind?

### §8.5 Theory combination and propagator monotonicity

E-Graphs Modulo Theories (§5.1) extends e-graphs to handle theory reasoning. Our setting already has theory propagators (trait resolution, constraint solving). The open question: how does theory-level e-class extension interact with our existing theory-propagator infrastructure?

Likely answer: theory propagators write to e-class cells with theory-specific tags; the cell merge handles theory-tagged equalities. But this requires careful design to preserve monotonicity (theory propagators must only ADD information, never RETRACT it within S0 — retraction goes through S(-1)).

### §8.6 Distributed equality saturation

The multi-agent / Vat / DCR vision wants distributed compilation. Open question: can e-graph state be sharded across nodes with local saturation + periodic synchronization?

Mathematically: a distributed e-graph is a colimit of local e-graphs over a sync category. CALM theorem says monotone computation is coordination-free; e-graph saturation is monotone; distributed saturation is therefore in principle coordination-free. Practically: synchronization frequency, conflict resolution, and identity-preserving partition design are all engineering questions.

For Prologos: PReduce can ship single-node initially; distributed extension is a future track aligned with the multi-agent vision.

### §8.7 Schedule expressions and rule-application strategy

egglog's schedule expressions formalize "how to apply rules" as a separate concern from "what rules exist." Schedule expressions can express priorities, conditional triggers, multi-stratum dispatch.

For Prologos: the scheduler IS the propagator scheduler; schedule expressions correspond to property tags + stratum assignments. But the design question is whether to expose schedule-expression-style configuration at any user-facing level (out of scope per Open Question 9 in PReduce master, but in scope for forward-compatibility design).

### §8.8 LLM-guided rule discovery

§5.4 references LLM-guided strategy synthesis; the broader frontier is LLM-guided RULE discovery — propose new rewrite rules based on observed program-program equivalences. Network-as-data architecture supports this; design implications for rule-property analysis pipelines.

---

## §9 References

### §9.1 Foundational e-graph papers
- Tate, R., Stepp, M., Tatlock, Z., & Lerner, S. (2009). Equality saturation: a new approach to optimization. *POPL '09*.
- Willsey, M., et al. (2021). egg: Fast and Extensible Equality Saturation. *POPL '21*. [arXiv:2004.03082](https://arxiv.org/abs/2004.03082)
- Nelson, G., & Oppen, D. C. (1980). Fast decision procedures based on congruence closure. *J. ACM*.

### §9.2 Adhesive theory
- Lack, S., & Sobociński, P. (2005). Adhesive and quasiadhesive categories. *RAIRO*.
- Biondo, R., Castelnovo, D., & Gadducci, F. (2025). EGGs Are Adhesive! *CALCO 2025*. [Dagstuhl](https://drops.dagstuhl.de/entities/document/10.4230/LIPIcs.CALCO.2025.10), [arXiv:2503.13678](https://arxiv.org/abs/2503.13678)
- Corradini, A., et al. (2024). Left-Linear Rewriting in Adhesive Categories. *CONCUR 2024*.

### §9.3 Production systems
- egg [GitHub](https://github.com/egraphs-good/egg)
- egglog [Better Together HN](https://news.ycombinator.com/item?id=35593635)
- Cranelift acyclic e-graphs [egraphs.org meeting](https://egraphs.org/meeting/2025-08-21-dialegg)
- DialEgg (CGO 2025). [Conference page](https://2025.cgo.org/details/cgo-2025-papers/44/DialEgg-Dialect-Agnostic-MLIR-Optimizer-using-Equality-Saturation-with-Egglog)
- eqsat MLIR dialect. [arXiv:2505.09363](https://arxiv.org/html/2505.09363v1)
- Schlatt, A., et al. (2026). E-Graphs as a Persistent Compiler Abstraction. [arXiv:2602.16707](https://arxiv.org/abs/2602.16707)

### §9.4 Recent advances
- E-Graphs Modulo Theories (2024). [arXiv:2504.14340](https://arxiv.org/html/2504.14340)
- Moss, A. (2025). E-Graphs with Bindings. [arXiv:2505.00807](https://arxiv.org/abs/2505.00807)
- Singher, E., & Itzhaky, S. (2023). Colored E-Graphs: Abstract Interpretation with Equality Saturation.
- LLM-Guided Strategy Synthesis for Scalable Equality Saturation (2026). [arXiv:2604.17364](https://arxiv.org/html/2604.17364v1)

### §9.5 Adjacent rewriting frameworks
- Lafont, Y. (1990). Interaction nets. *POPL '90*.
- Lafont, Y. (1997). Interaction Combinators.
- Girard, J.-Y. (1989). Geometry of Interaction.
- Mackie, I. (1995). The Geometry of Interaction Machine.
- Muroya, K., & Ghica, D. R. (2017-2018). Dynamic GoI Machine. [LMCS](https://lmcs.episciences.org/5882/pdf), [arXiv:1803.00427](https://arxiv.org/abs/1803.00427)
- HVM2 [HigherOrderCO/HVM2](https://github.com/HigherOrderCO/HVM2)

### §9.6 Algebraic foundations
- Goodman, J. (1999). Semiring Parsing. *Computational Linguistics*.
- Bistarelli, S., Montanari, U., & Rossi, F. (1997). Semiring-based Constraint Satisfaction and Optimization. *J. ACM*.
- Lawvere, F. W. (1973). Metric Spaces, Generalized Logic, and Closed Categories.
- Russo, C. (2010). Quantale Modules and their Operators. [arXiv:1002.0968](https://arxiv.org/abs/1002.0968)

### §9.7 Topos and categorical
- Topos Institute (2025). How to prove equations using diagrams. [Blog](https://topos.institute/blog/2025-05-27-e-graphs-1/)

### §9.8 Prologos prior research
- [`2026-03-22_CATEGORICAL_FOUNDATIONS_TYPED_PROPAGATOR_NETWORKS.md`](2026-03-22_CATEGORICAL_FOUNDATIONS_TYPED_PROPAGATOR_NETWORKS.md) — Lafont + GoI grounding
- [`2026-03-24_HYPERGRAPH_REWRITING_PROPAGATOR_PARSING.md`](2026-03-24_HYPERGRAPH_REWRITING_PROPAGATOR_PARSING.md) — landscape survey
- [`2026-03-24_TROPICAL_OPTIMIZATION_NETWORK_ARCHITECTURE.md`](2026-03-24_TROPICAL_OPTIMIZATION_NETWORK_ARCHITECTURE.md) — cost-weighted rewriting
- [`2026-03-26_KAN_EXTENSIONS_ATMS_GFP_PARSING.md`](2026-03-26_KAN_EXTENSIONS_ATMS_GFP_PARSING.md) — 4-level optimization strategy
- [`2026-03-28_MODULE_THEORY_LATTICES.md`](2026-03-28_MODULE_THEORY_LATTICES.md) §6 — e-graphs as quotient modules
- [`2026-04-03_ADHESIVE_CATEGORIES_PARSE_TREES.md`](2026-04-03_ADHESIVE_CATEGORIES_PARSE_TREES.md) — adhesive-DPO foundations
- [`2026-04-08_HYPERCUBE_BSP_LE_DESIGN_ADDENDUM.md`](2026-04-08_HYPERCUBE_BSP_LE_DESIGN_ADDENDUM.md) — Q_n hypercube + bitmask
- [`2026-04-21_TROPICAL_QUANTALE_RESEARCH.md`](2026-04-21_TROPICAL_QUANTALE_RESEARCH.md) — cost-extraction algebra
- [`2026-04-30_LATTICE_VARIETY_AND_CANONICAL_FORM_FOR_SRE.md`](2026-04-30_LATTICE_VARIETY_AND_CANONICAL_FORM_FOR_SRE.md) — adjacent canonical form
- [`2026-04-30_PROPAGATOR_NETWORK_AS_SUPEROPTIMIZING_COMPILER.md`](2026-04-30_PROPAGATOR_NETWORK_AS_SUPEROPTIMIZING_COMPILER.md) — comparative landscape
- [`../tracking/2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_DESIGN.md`](../tracking/2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_DESIGN.md) — Phase 1B residuation operator
- [`../tracking/2026-05-02_PREDUCE_MASTER.md`](../tracking/2026-05-02_PREDUCE_MASTER.md) — primary consumer

---

## Document status

**Stage 1 research note** — foundational survey + Prologos-specific synthesis. To be referenced by PReduce Track 0.1 (architectural sketch), Track 1+ implementation tracks, future SH series tracks, future PPN 4D, and any equality-saturation-related Prologos work.

This document is a living reference; cross-references from PReduce track documents back here carry the full literature citation. New findings during PReduce implementation that refine the theoretical framing should be added here as supplementary sections rather than scattered across track documents.

**Next steps**: PReduce Track 0.1 (`docs/research/2026-MM-DD_PREDUCE_TRACK01_ARCHITECTURAL_SKETCH.md` or similar — naming TBD) opens with this research as foundational input. Light treatment of e-graph mechanics there; this note carries the depth.
