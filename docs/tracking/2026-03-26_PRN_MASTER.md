# PRN (Propagator-Rewriting-Network) — Theory Series Master

**Created**: 2026-03-26
**Status**: Active (Stage 0 — accumulating findings from application tracks)
**Nature**: THEORY series. Not implemented directly — crystallizes from
application track discoveries. Tracks emerge; they are not pre-planned.

**Thesis**: Parsing, structural reasoning, reduction, logical inference,
and serialization are all instances of typed hyperlattice rewriting on
propagator networks. PRN formalizes the shared primitives that application
series (PPN, SRE, PReductions, BSP-LE) instantiate and contribute back to.

**Analogy**: PRN is to its application series as NTT is to the propagator
infrastructure tracks. NTT crystallized from PM Tracks 1-8 — we built
the infrastructure, observed the recurring structures, and NTT named them.
PRN will crystallize from PPN, SRE, PReductions, and BSP-LE as we build
applications and observe what rewriting primitives they share.

**Source Documents**:
- [Hypergraph Rewriting + Propagator-Native Parsing](../research/2026-03-24_HYPERGRAPH_REWRITING_PROPAGATOR_PARSING.md)
- [Tropical Optimization + Network Architecture](../research/2026-03-24_TROPICAL_OPTIMIZATION_NETWORK_ARCHITECTURE.md)
- [SRE Research](../research/2026-03-22_STRUCTURAL_REASONING_ENGINE.md)
- [Categorical Foundations](../research/2026-03-22_CATEGORICAL_FOUNDATIONS_TYPED_PROPAGATOR_NETWORKS.md)
- [NTT Syntax Design](2026-03-22_NTT_SYNTAX_DESIGN.md)
- [PPN Master](2026-03-26_PPN_MASTER.md)
- [SRE Master](2026-03-22_SRE_MASTER.md)
- [Master Roadmap](MASTER_ROADMAP.org)

---

## 1. Confirmed Findings

These are things we KNOW are instances of hyperlattice rewriting,
with evidence from implementation.

| Finding | Evidence | Application | Date |
|---------|----------|-------------|------|
| SRE structural decomposition IS DPO hyperedge replacement | `structural-relate` replaces a constructor hyperedge with sub-cell nodes + connecting propagators. The ctor-desc form registry IS a hypergraph grammar. | SRE Track 0-2 | 2026-03-22 |
| `prop:ctor-desc-tag` guarantees no critical pairs | Each value has exactly one constructor tag → exactly one decomposition rule matches → confluence by construction | SRE Track 2 | 2026-03-24 |
| Zonk IS a rewrite rule | `expr-meta(id) → solution(id)` applied exhaustively until no more `expr-meta` nodes. Eliminating zonk = making the rule matchless (no `expr-meta` in expressions). | PM 8F, Track 10B | 2026-03-25 |
| Parsing IS attribute evaluation IS propagator fixpoint | Engelfriet-Heyker theorem (1992): HR term languages = attribute grammar languages. Attribute evaluation = propagator fixpoint. | Research | 2026-03-24 |
| Serialization/deserialization = rewriting in opposite directions | Serialize: hypergraph → byte sequence (linearization rewriting). Deserialize: byte sequence → hypergraph (construction rewriting). Same grammar, opposite direction. DCG bidirectionality. | PM Track 10 | 2026-03-25 |
| E-graphs are adhesive (CALCO 2025) | Biondo, Castelnovo, Gadducci: e-graphs form an adhesive category. DPO rewriting theory applies directly. | External research | 2026-03-24 |

## 2. Conjectured Connections

Things we BELIEVE are instances of hyperlattice rewriting but haven't
confirmed through implementation. Each conjecture has a PREDICTED
confirmation track.

| Conjecture | Reasoning | Predicted confirmation |
|-----------|-----------|----------------------|
| β/δ/ι reduction as DPO rewrite rules | `(λx.body) arg → body[x:=arg]` is pattern match + structural substitution = DPO rewrite. Interaction nets (Lafont) provide strong confluence. | PReductions Track 1 |
| NAF as non-monotone rewrite rule | "If no derivation for P after lfp, assert ¬P" is a rewrite that fires on ABSENCE of a value — non-monotone, stratified. | BSP-LE Track 3 |
| Tabling as memoized rewriting | Tabled predicates cache rewrite results. The cell holds all known derivations; new derivations merge monotonically. Suspension = waiting for cell to accumulate more values. | BSP-LE Track 4 |
| Session duality as involutive rewriting | `dual(Send(A, S)) → Recv(A, dual(S))` is a rewrite rule with involution structure. SRE Track 1 confirmed the structural dispatch; full session protocol rewriting awaits SRE Track 3. | SRE Track 3 |
| Surface normalization as rewriting | `(let [x := val] body) → ((fn [x] body) val)` and all preparse expansions are DPO rewrite rules on the surface syntax lattice. | PPN Track 2 |
| Type inference as attribute evaluation | Each typing rule (`infer-app`, `check-lam`, etc.) is an attribute computation on the parse tree. The elaborator IS an attribute evaluator. | PPN Track 4 / SRE Track 2C |
| Grammar extension as rule registration | Adding new syntax = adding new rewrite rules to the grammar. The `defmacro` system is an ad-hoc version; PPN Track 7 makes it first-class and typed. | PPN Track 7 |
| Optimization as cost-weighted rewriting | Each rewrite rule has a cost (tropical semiring). Optimal program = cheapest rewrite sequence to normal form. | PReductions Track 3, OE |
| NF-Narrowing as DT-guided rewriting | Definitional trees ARE rewrite strategies — they determine which rule to apply at which position. Narrowing IS rewriting with unification (binding variables, not just matching ground). Residuation IS propagator waiting (input cell at bot → suspend). "Needed" narrowing = optimal strategy (provably minimal steps for inductively sequential systems). | PPN (strategy layer), PReductions, BSP-LE |
| Needed narrowing optimality transfers to grammar rules | If grammar rules are inductively sequential (each matches a specific token/form at a specific position — which CFGs guarantee), then DT-guided rule selection is PROVABLY OPTIMAL. This means: the optimal parsing strategy may be derivable from the grammar's definitional tree. | PPN Track 3, PRN foundational |

## 3. Universal Primitives

Shared abstractions that emerge from multiple applications. These are
candidates for formalization as PRN core infrastructure — but ONLY
after multiple applications confirm the need.

### Confirmed (3+ instances)

| Primitive | Instances | Description |
|-----------|-----------|-------------|
| Rewrite rule registration | SRE (ctor-desc), PPN (grammar production), PReductions (β-rule) | Register a pattern → replacement rule with the network |
| Fixpoint computation | All systems | Apply rules until quiescence (no more applicable rules) |
| Lattice merge | All systems | Monotonic information accumulation in cells |
| Stratified recovery | PM (S0-S2), BSP-LE (NAF strata), PPN (parse→elaborate→check) | Non-monotone operations staged across barrier strata |
| ATMS-guided search | PM (speculation), BSP-LE (choice points), PPN (ambiguity) | Assumption-based exploration with nogood learning |
| Structural decomposition | SRE (type constructors), PPN (grammar constituents), PReductions (redex matching) | Match a pattern in the graph, decompose into sub-parts |

### Emerging (2 instances, watching)

| Primitive | Instances | Description |
|-----------|-----------|-------------|
| Bidirectional rule application | PPN (serialize/deserialize), SRE (composition/decomposition) | Same rule, opposite information flow direction |
| Cost-weighted rule selection | PPN (optimal parse), PReductions (optimal reduction) | Tropical semiring selects cheapest rewrite |
| Invariant-typed rules | PPN (grammar invariant levels), NTT (monotonicity proofs) | Rules carry type annotations that constrain their applicability |
| Rule confluence guarantee | SRE (prop:ctor-desc-tag), PReductions (interaction nets) | Structural guarantee that rule application order doesn't matter |

### Speculative (1 instance, need more data)

| Primitive | Instance | Description |
|-----------|----------|-------------|
| Meta-grammar (rules that generate rules) | PPN Track 7 (user-defined extensions) | A rule that, when applied, registers new rules |
| Incremental re-propagation | PPN Track 8 (edit → re-propagate) | When a cell value changes, only re-fire affected rules |
| Non-monotone rewrite with retraction | BSP-LE (NAF) | A rule that REMOVES information, staged in barrier stratum |

## 4. Open Research Questions

Deep questions that cut across applications. These are the questions
we return to as application tracks teach us more.

### Foundational

1. **What is the MINIMAL rewriting substrate?** What's the smallest set
   of primitives from which all application-specific rewriting can be
   derived? Is it: {rule registration, pattern match, cell write,
   quiescence}? Or do we need more (stratification, ATMS, cost)?

2. **Does adhesive category theory apply to our propagator networks?**
   CALCO 2025 showed e-graphs are adhesive. Our networks have richer
   structure (cells + propagators + lattice merge + strata). Are they
   adhesive? If so, ALL DPO rewriting theory applies directly —
   termination, confluence, critical pair analysis.

3. **How do non-monotone rewrites compose with monotone ones?**
   NAF, retraction, and commit are non-monotone. They're currently
   staged via stratification. Is there a more elegant composition?
   Kan extensions between monotone and non-monotone strata?

4. **Can rewrite rules be NTT-typed?** A rule type would be:
   `input-pattern-type → output-pattern-type`, with monotonicity
   conditions. The type system would verify rule soundness at
   registration time, not at application time.

### Applied

5. **What's the right cost model for rule selection?** Tropical
   semiring for "cheapest rewrite"? Interaction net optimal reduction
   for "shortest path"? Problem-dependent? Can the cost model itself
   be a parameter (Goodman's semiring parsing generalization)?

6. **Can the rewriting substrate be self-hosting?** If rules are
   registered on the network, and the network is built by applying
   rules to source code... can the rule registration mechanism itself
   be expressed as rules? This is the bootstrapping question.

7. **How does the rewriting substrate interact with speculation?**
   Speculative rewriting (try rule A; if contradiction, retract and
   try rule B) uses ATMS. Is speculation a PRIMITIVE of the rewriting
   substrate, or a pattern built from simpler primitives?

8. **Can we express the entire compiler as a stratified rewrite system?**
   Lexing (stratum 0) → parsing (stratum 1) → normalization (stratum 2)
   → elaboration (stratum 3) → type checking (stratum 4) → optimization
   (stratum 5) → code generation (stratum 6). Each stratum is a set of
   rewrite rules. The compiler is the fixpoint of the stratified system.

### Categorical

9. **What IS the categorical structure of our rewriting substrate?**
   Is it a 2-category (rules are 1-morphisms, rule applications are
   2-morphisms)? A double category (horizontal = rewriting, vertical =
   lattice ordering)? A fibration (fibers = strata, base = stratum
   poset)?

10. **How do polynomial functors interact with rewrite rules?** The SRE's
    structural forms are polynomial summands. Rewrite rules transform
    polynomial expressions. Is the rewriting substrate a natural
    transformation between polynomial functors?

## 5. Cross-Series Contribution Ledger

Tracks the flow of insights between application and theory. Updated
as application tracks complete PIRs.

| Date | Source Track | Finding | PRN Contribution | Consumed By |
|------|-------------|---------|-----------------|-------------|
| 2026-03-22 | SRE Track 0 | Form registry = rewrite rule registration | Confirmed: rule registration is a universal primitive | SRE, PPN |
| 2026-03-23 | SRE Track 1 | Relation-parameterized dispatch | Same rule infrastructure, different lattice orderings | PPN (Track 5 disambiguation) |
| 2026-03-24 | SRE Track 2 | prop:ctor-desc-tag = confluence by construction | Confirmed: structural confluence guarantee is universal | PReductions (interaction nets) |
| 2026-03-24 | PM Track 10 | .pnet serialization = rewriting in opposite directions | Bidirectional rules (DCG insight) | PPN (Track 9 self-describing) |
| 2026-03-25 | PM Track 10B | Zonk = rewrite rule (expr-meta → solution) | Rewrite elimination by making rules matchless | SRE Track 2C |
| 2026-03-26 | Conversation | Invariant-typed grammars (identity/structural/behavioral/value) | Rules carry type annotations constraining applicability | PPN (Track 9), NTT |
| 2026-03-26 | Conversation | NF-Narrowing as strategy layer for rewriting | DTs = optimal rule selection; residuation = propagator waiting; needed narrowing = provably minimal | PPN, PReductions, BSP-LE |
| 2026-03-26 | Conversation | ATMS + type network = proof-based disambiguation | Parse ambiguity → branches → type contradiction → retraction. Strictly more powerful than all existing parsers. | PPN Track 5 |
| 2026-03-26 | Conversation | Cross-network information for parsing | Session protocols, QTT multiplicities, effect positions, module exports, trait constraints — ALL are disambiguation sources | PPN Tracks 3-5 |
| 2026-03-26 | Research | Lattice Foundations for PPN | 6-domain reduced product, semiring parsing, Datalog stratification, ATMS-guided parsing, concrete lattice design | PPN Track 0 foundational |

## 6. Research Documents Index

| Document | Date | Scope | Key contributions to PRN |
|----------|------|-------|------------------------|
| [Hypergraph Rewriting + Propagator Parsing](../research/2026-03-24_HYPERGRAPH_REWRITING_PROPAGATOR_PARSING.md) | 2026-03-24 | Engelfriet-Heyker, DPO/SPO, Courcelle, semiring parsing, interaction nets, GoI | Foundational: establishes HR grammars + attribute grammars + propagator networks equivalence |
| [Tropical Optimization + Network Architecture](../research/2026-03-24_TROPICAL_OPTIMIZATION_NETWORK_ARCHITECTURE.md) | 2026-03-24 | Cost-weighted rewriting, ATMS search, stratification, quantale morphisms | Cost model for rule selection; stratification as compiler architecture |
| [SRE Research](../research/2026-03-22_STRUCTURAL_REASONING_ENGINE.md) | 2026-03-22 | PUnify as universal structural reasoning, domain-parameterized decomposition | SRE = DPO hyperedge replacement; form registry = HR grammar |
| [Categorical Foundations](../research/2026-03-22_CATEGORICAL_FOUNDATIONS_TYPED_PROPAGATOR_NETWORKS.md) | 2026-03-22 | Polynomial functors, Grothendieck fibrations, Kan extensions, quantales | Categorical grounding for network types and rewriting |
| [NTT Syntax Design](2026-03-22_NTT_SYNTAX_DESIGN.md) | 2026-03-22 | Type theory for networks: lattice → cell → propagator → network → bridge → stratification | Types for rewrite rules; invariant levels |
| [PPN Master §4: Bidirectional Typed Grammars](2026-03-26_PPN_MASTER.md) | 2026-03-26 | DCG bidirectionality, invariant levels, NTT type correspondence | Grammar-as-type; serialization/deserialization as dual rewriting |
| [Lattice Foundations for PPN](../research/2026-03-26_LATTICE_FOUNDATIONS_PPN.md) | 2026-03-26 | Abstract interpretation, semiring parsing, Datalog, monotone frameworks, categorical connections, ATMS-guided parsing | Concrete lattice design for 6 domains + reduced product + scheduling strategy |
| [FL-Narrowing Design](../research/2026-03-07_FL_NARROWING_DESIGN.org) | 2026-03-07 | Definitional trees, residuation-first, term lattice, needed narrowing | Strategy layer: DTs as optimal rewrite rule selection |

## 7. Watching / Emerging Patterns

Medium-term observations not yet confirmed as universals. Need 2-3
more data points before promotion to §3 (Universal Primitives).

| Pattern | Instances so far | What would confirm it |
|---------|-----------------|----------------------|
| "Lattice merge IS a rewrite rule" | SRE (type merge), PM (cell write) | If PPN's parse lattice merge and PReductions' e-graph merge follow the same pattern, merge is rewriting |
| "All rewriting is monotone + stratified non-monotone" | PM (S0 monotone + S2 commit), BSP-LE (lfp + NAF) | If PPN and PReductions follow the same monotone/barrier pattern |
| "Rule matchlessness eliminates entire subsystems" | Zonk (matchless = deleted), SRE (matchless = no decomposition needed) | If PPN has examples of rules that become matchless after optimization |
| "DTs are the universal strategy layer" | NF-Narrowing (DTs guide narrowing), SRE (ctor-desc dispatch = 1-level DT) | If PPN parsing uses DT-like strategy, and PReductions uses DTs for optimization rule selection — DTs are the STRATEGY primitive across all applications |
| "Needed optimality transfers across domains" | NF-Narrowing (needed narrowing = minimal steps) | If "needed parsing" (DT-guided rule selection) is provably optimal for CFGs, the optimality result generalizes beyond logic programming |
| "ATMS + type network = proof-based disambiguation" | Conversation insight (2026-03-26): parse ambiguity → ATMS branches → type contradiction → nogood → retraction. Strictly more powerful than PEG/GLR/GLL/Earley. | PPN Track 5 implementation |
| "The grammar IS the type" | PPN (grammar = parse type), SRE (form = structural type) | If PReductions' rewrite rules are typed by their input/output pattern types |
| "Self-describing formats = meta-grammars" | PPN Track 9 (grammar-as-Part-1) | Need implementation evidence |

---

*This document grows as application tracks contribute findings. Each
application track's PIR should include a "PRN contribution" section
noting what the track taught us about the universal rewriting formalism.*
