# Lattice Foundations for Propagator-Parsing-Networks

**Stage**: 0/1 Research Synthesis
**Date**: 2026-03-26
**Series**: PPN (Propagator-Parsing-Network) -- Research Document
**Feeds into**: PPN Track 0 (Lattice Design), PPN Track 3 (Parser), PPN Track 5 (Type-Directed Disambiguation)

**Related documents**:
- [PPN Master Tracking](../tracking/2026-03-26_PPN_MASTER.md) -- series tracking
- [Hypergraph Rewriting + Propagator-Native Parsing](2026-03-24_HYPERGRAPH_REWRITING_PROPAGATOR_PARSING.md) -- foundational research
- [Categorical Foundations of Typed Propagator Networks](2026-03-22_CATEGORICAL_FOUNDATIONS_TYPED_PROPAGATOR_NETWORKS.md) -- polynomial functors, Galois connections, stratification
- [Tropical Optimization + Network Architecture](2026-03-24_TROPICAL_OPTIMIZATION_NETWORK_ARCHITECTURE.md) -- ATMS search, tropical semirings, cost-weighted rewriting
- [Master Roadmap](../tracking/MASTER_ROADMAP.org) -- cross-series dependency map

---

## Abstract

This document synthesizes five cross-disciplinary research areas -- abstract
interpretation, semiring parsing, Datalog/deductive parsing, monotone
frameworks, and categorical foundations -- into a concrete lattice design
framework for PPN (Propagator-Parsing-Networks). The central thesis: PPN's
multi-domain lattice architecture (token, surface, core, type, multiplicity,
session) is an instance of the *reduced product* from abstract interpretation,
where Galois connections between domains enable bidirectional information flow.
The scheduling strategy is *chaotic iteration* from monotone frameworks, and
the algebraic structure of parsing is captured by *semiring parameterization*.
ATMS-guided disambiguation is the novel contribution: ambiguous parses as
assumptions, type information as nogood generators.

The document concludes with a concrete lattice design proposal for PPN Track 0
and open questions for Tracks 1-4.

---

## 1. Abstract Interpretation: Domains, Products, and Soundness

### 1.1 The Core Framework

Cousot and Cousot (1977, 1979) established abstract interpretation as a
general theory of sound approximation. The framework rests on three pillars:

1. **Concrete domain** (C, <=): a complete lattice of program states (for us:
   the set of all possible parse/type derivations, ordered by information content).
2. **Abstract domain** (A, <=): a complete lattice of approximations (for us:
   individual lattice domains like the token lattice or the type lattice).
3. **Galois connection** (alpha, gamma) between them: alpha : C -> A (abstraction)
   and gamma : A -> C (concretization), satisfying alpha(c) <= a iff c <= gamma(a).

The Galois connection guarantees *soundness*: any fact derived in the abstract
domain corresponds to a valid (possibly weaker) fact in the concrete domain.
Abstract interpretation then computes a fixpoint in the abstract domain as an
approximation of the concrete fixpoint.

**Mapping to PPN**: The concrete domain is the set of all valid derivations
from source text to typed AST. Each abstract domain (token lattice, surface
lattice, type lattice, etc.) captures one projection of this derivation. The
Galois connections between domains (our "bridges") ensure that information
flowing between domains preserves soundness.

### 1.2 The Reduced Product

When multiple abstract domains analyze the same program, the naive approach
is the *Cartesian product*: run each analysis independently and collect
results. But Cousot observed that the Cartesian product misses interactions --
information in domain A can refine domain B, and vice versa.

The **reduced product** (Cousot & Cousot 1979; Cousot, Cousot & Mauborgne 2011)
addresses this. Given abstract domains (A1, alpha1, gamma1) and (A2, alpha2,
gamma2), the reduced product is the Cartesian product A1 x A2 quotiented by
mutual refinement: whenever a1 in A1 implies a tighter bound on A2 (or vice
versa), the product is *reduced* to reflect this interaction.

Formally, the reduction operator rho : A1 x A2 -> A1 x A2 iterates:
- Use alpha2(gamma1(a1)) to refine a2
- Use alpha1(gamma2(a2)) to refine a1
- Repeat until fixpoint

This is exactly what our bridge propagators do. When the type domain
determines that an expression has type `Int -> Bool`, the type-to-parse bridge
refines the parse domain (ruling out parses incompatible with function type).
When the parse domain determines the expression is a lambda, the parse-to-type
bridge refines the type domain (it must be a function type). The reduced product
is the theoretical justification for bidirectional bridge propagation.

**Key insight for PPN Track 0**: Our multi-domain architecture (token, surface,
core, type, multiplicity, session) is a 6-way reduced product. The lattice
design must specify not just each domain in isolation, but the Galois
connections (bridges) between every interacting pair. The reduction operator is
our propagator scheduling loop.

### 1.3 Widening and Convergence

For lattices of infinite height, the ascending chain condition fails and
fixpoint iteration may not terminate. Cousot and Cousot introduced *widening*
operators (nabla) that accelerate convergence by over-approximating:

a nabla b >= a join b, and every ascending chain stabilized by nabla is finite.

For PPN, the relevant lattices are all finite-height (token types are finite,
surface syntax trees over a fixed grammar are finite up to depth, type
expressions are finite modulo meta-variable instantiation). Therefore:

- **Token lattice**: finite (bounded by the grammar's terminal vocabulary).
  No widening needed.
- **Surface lattice**: finite height per parse span (bounded by grammar
  nesting depth). No widening needed.
- **Type lattice**: potentially infinite (dependent types can nest arbitrarily).
  But our meta-variable mechanism + fuel limits already provide the termination
  guarantee. Widening could formalize fuel limits as principled over-approximation
  rather than ad-hoc cutoffs.
- **Multiplicity lattice**: finite ({0, 1, omega}). No widening needed.
- **Session lattice**: potentially infinite (recursive session types). Our
  mu-binder mechanism bounds this. Widening is relevant for coinductive
  session types.

**Design implication**: PPN Track 0 should mark each lattice domain with its
height property (finite/infinite) and its convergence mechanism (structural
finiteness, widening, or fuel). This classification determines scheduling
requirements.

### 1.4 Narrowing and Precision Recovery

After widening produces an over-approximation, *narrowing* operators (delta)
recover precision by iterating downward from the widened fixpoint:

a delta b <= a, and every descending chain stabilized by delta reaches a
fixpoint no worse than the greatest fixpoint below the widening result.

For PPN, narrowing corresponds to our S(-1) retraction stratum: after S2
commits a choice (widening = over-approximate by choosing), S(-1) retracts
alternatives (narrowing = recover precision by eliminating impossible branches).
The ATMS nogood mechanism is a form of narrowing -- each nogood removes an
assumption set, tightening the approximation.

### 1.5 Summary: What Abstract Interpretation Gives PPN

| AI Concept | PPN Mapping | Design Implication |
|------------|-------------|-------------------|
| Abstract domain | Individual lattice (token, surface, type, ...) | Each domain needs: carrier set, ordering, join, bot, top |
| Galois connection | Bridge propagator pair (alpha/gamma) | Each bridge needs: soundness proof (round-trip is inflationary) |
| Reduced product | Multi-domain network | Bridge propagators implement mutual refinement |
| Fixpoint | Run-to-quiescence | Monotonicity of all propagators guarantees existence |
| Widening | Fuel limits / meta-variable defaulting | Needed only for infinite-height domains |
| Narrowing | ATMS nogood retraction | S(-1) stratum implements precision recovery |
| Soundness | Type safety | Galois connection laws on bridges guarantee soundness |

---

## 2. Semiring Parsing: Algebraic Parameterization

### 2.1 Goodman's Framework

Goodman (1999) showed that parsing algorithms over context-free grammars
factor into two orthogonal components:

1. **Control structure**: the strategy for exploring derivations (Earley's
   prediction/scanning/completion, CYK's span-based dynamic programming,
   GLL's descriptors).
2. **Algebraic structure**: the semiring that combines sub-derivation values.

The control structure is invariant across analyses; only the semiring changes:

| Semiring | Addition (oplus) | Multiplication (otimes) | What it computes |
|----------|----------|---------------|-----------------|
| Boolean ({0,1}, or, and) | Disjunction | Conjunction | Recognition |
| Counting (N, +, *) | Sum | Product | Number of parses |
| Viterbi ([0,1], max, *) | Best probability | Chain probability | Most probable parse |
| Tropical (R+ u {inf}, min, +) | Minimum | Sum | Cheapest derivation |
| Forest (SPPF, union, concat) | Ambiguity merge | Tree composition | All parse trees |
| Inside (R+, +, *) | Marginalize | Chain | Total probability |

The semiring addition (oplus) corresponds to combining analyses of the *same*
span from different derivations (ambiguity resolution). The semiring
multiplication (otimes) corresponds to composing analyses of *adjacent* spans
within one derivation (sequential composition).

### 2.2 Mapping to Propagator Lattices

The semiring-to-lattice mapping is direct but subtle:

- **Semiring addition (oplus)** maps to **lattice join**. When two propagators
  write to the same cell (two derivations for the same span), the cell's merge
  function computes the join. For the Boolean semiring, this is `or`. For
  the forest semiring, this is SPPF union. For the tropical semiring, this
  is `min`.

- **Semiring multiplication (otimes)** maps to **propagator computation**. A
  propagator that reads from two cells (two adjacent spans) and writes their
  combination to a third cell (the composed span) computes the semiring product.

This means the cell merge function IS the semiring addition, and the propagator
fire function IS the semiring multiplication (composed with the rule's semantic
action).

**Critical requirement**: For the fixpoint to be well-defined, the semiring must
be *omega-continuous* (ascending chains have least upper bounds) or, equivalently,
the corresponding lattice must satisfy the ascending chain condition. All the
standard parsing semirings satisfy this: Boolean and counting are finite or
omega-continuous; tropical and Viterbi are complete lattices under their
respective orderings; the forest semiring has finite height for fixed-length
inputs.

### 2.3 The Tropical Semiring and PPN Optimization

The tropical semiring (min, +) over R+ u {infinity} deserves special attention
for PPN. When parsing is parameterized by the tropical semiring:

- Each grammar production carries a **cost** (e.g., priority, probability, or
  complexity weight).
- Each derivation's total cost is the sum of its productions' costs.
- When multiple derivations reach the same cell, `min` keeps the cheapest.
- The optimal parse is the one with minimum total cost.

This connects to our OE (Optimization Enrichment) series: tropical-enriched
parsing IS cost-optimal parsing. For PPN:

- Error recovery edits (insert/delete/substitute token) carry costs. The
  minimum-cost repair is the tropical-optimal parse with error productions.
- Type-directed disambiguation carries costs: parses consistent with known
  type constraints have cost 0; parses requiring type coercion have positive
  cost. The tropical semiring selects the parse requiring least coercion.
- Ambiguity resolution by precedence/associativity is naturally expressed as
  cost assignment to grammar alternatives.

### 2.4 Beyond Classical Semirings: Lattice Semirings

A key insight for PPN: our lattice domains (type, multiplicity, session)
are themselves semirings (or, more precisely, *quantales* -- complete lattices
with an associative tensor distributing over joins). The type lattice has:

- Join: type union (`Int | Bool`)
- Tensor: function type application (`A -> B` applied to `A` yields `B`)

This means parsing can be parameterized by the *type lattice as semiring*.
The resulting "parse" doesn't produce trees -- it produces *types*. This is
type inference as parsing: the grammar's semantic actions compute types, and
the semiring combines types according to the grammar's composition rules.

**This is the theoretical basis for PPN Track 4** (Elaboration as Attribute
Evaluation): elaboration IS parsing in the type-lattice semiring.

### 2.5 Summary: What Semiring Parsing Gives PPN

| Concept | PPN Mapping | Design Implication |
|---------|-------------|-------------------|
| Semiring addition | Cell merge function | Each lattice domain IS a semiring; merge = oplus |
| Semiring multiplication | Propagator fire body | Productions compose sub-results via otimes |
| Tropical semiring | Cost-optimal parsing / error recovery | OE enrichment on parse lattice |
| Forest semiring | Ambiguity cells (multiple parses) | SPPF as lattice value type |
| Type-lattice semiring | Elaboration as parsing | Type inference = parsing in the type semiring |
| Omega-continuity | Convergence guarantee | Each semiring must have ACC or equivalent |

---

## 3. Datalog and Semi-Naive Evaluation

### 3.1 Parsing as Deduction

Shieber, Schabes, and Pereira (1995) established *deductive parsing*: parsing
algorithms are deduction systems where items are derived by inference rules.
Each parsing algorithm (Earley, CYK, LR) corresponds to a different set of
inference rules over the same item domain.

The connection to Datalog is immediate: parsing items are Datalog facts,
inference rules are Datalog rules, and parsing is bottom-up evaluation of a
Datalog program.

For CYK, the Datalog program is:

```
% Base case: terminal matches
item(A, I, I+1) :- terminal(A, I).

% Inductive case: production application
item(A, I, K) :- item(B, I, J), item(C, J, K), production(A, B, C).
```

Earley parsing adds prediction and completion rules. The Grammar Flow Graph
(GFG) formulation makes this explicit: each position in the grammar is a
Datalog predicate, and prediction/scanning/completion are Datalog rules.

### 3.2 Semi-Naive Evaluation = Delta Propagation

Naive bottom-up evaluation recomputes all derivable facts at each iteration.
Semi-naive evaluation (Bancilhon 1985) optimizes this by tracking *deltas*:
at each round, only newly derived facts from the previous round are used as
premises. Old facts x old facts are skipped (they were already computed).

This maps precisely to our propagator worklist scheduling:

| Datalog Concept | Propagator Mapping |
|----------------|-------------------|
| Fact | Cell value |
| Delta (new facts) | Worklist entries (cells that changed) |
| Rule | Propagator |
| Semi-naive iteration | Fire only propagators whose inputs changed |
| Stratification | S(-1) / S0 / S1 / S2 stratum boundaries |

The key optimization: our worklist scheduler already implements semi-naive
evaluation. When a cell value changes, only propagators depending on that cell
are enqueued. Propagators that haven't seen any input changes are not re-fired.
This is semi-naive evaluation applied to the propagator graph.

### 3.3 Stratification and Non-Monotone Operations

Datalog with negation requires *stratification*: rules are partitioned into
strata such that negation only applies to predicates defined in lower strata.
Within each stratum, evaluation is monotone (bottom-up fixpoint). At stratum
boundaries, negated atoms are evaluated against the completed lower stratum.

Our stratification (S(-1), S0, S1, S2) is a direct instance:

| Stratum | Datalog analog | Monotonicity |
|---------|---------------|-------------|
| S(-1) | Retraction (deletion of obsolete facts) | Non-monotone |
| S0 | Base stratum (all monotone rules) | Monotone |
| S1 | Readiness stratum (negation-as-failure: "not still unsolved") | Non-monotone guard |
| S2 | Commitment stratum (select from alternatives) | Non-monotone choice |

The Datalog perspective clarifies why stratification is necessary: S1's
readiness check ("all dependencies are ground") is a negation ("not exists
unsolved dependency"). This is negation-as-failure, which requires the base
stratum (S0) to reach fixpoint before evaluation. S2's commitment ("choose
this instance") is a choice operator, which requires S1 to confirm readiness.

### 3.4 Provenance and Traced Cells

Datalog provenance tracking annotates each derived fact with its derivation
tree: which rules fired, on which premises. This is the Datalog analog of
our TracedCell concept (from the BSP-LE series).

For PPN, provenance serves three purposes:

1. **Error messages**: when a parse fails or a type error occurs, the
   provenance trace explains *why* -- which parse decisions led to the failure,
   which type constraints are unsatisfiable.

2. **Incremental invalidation**: when a source edit changes a fact, the
   provenance DAG identifies exactly which derived facts depend on the changed
   fact. Only those need re-derivation. This is semi-naive evaluation with
   deletion support.

3. **ATMS integration**: each derivation path is an ATMS justification. The
   label (set of assumptions) supporting a derived fact is the set of parsing
   choices made along its derivation. Retraction of an assumption invalidates
   all facts whose provenance depends on it.

### 3.5 Datalog Extensions: Flix and Lattice Semantics

The Flix language (Madsen, Yee, Lhotak 2016) extends Datalog with lattice
semantics: facts are not just present/absent but carry lattice values, and
rule evaluation is monotone lattice computation. This is precisely our
propagator model applied to Datalog.

The connection is deep: Flix's lattice Datalog IS a propagator network where
rules are propagators and facts are cells. PPN's parsing-as-Datalog, when
extended with lattice values (types, multiplicities, session types), becomes
Flix-style lattice Datalog. The semiring of Section 2 provides the lattice;
the Datalog rules of this section provide the control structure.

### 3.6 Summary: What Datalog Gives PPN

| Concept | PPN Mapping | Design Implication |
|---------|-------------|-------------------|
| Bottom-up evaluation | Propagator fixpoint | Parsing IS bottom-up Datalog evaluation |
| Semi-naive evaluation | Worklist scheduling | Only fire propagators for changed cells |
| Stratification | S(-1)/S0/S1/S2 | Negation and choice require stratum boundaries |
| Provenance | TracedCell / ATMS justification | Derivation tracking enables error messages + incrementality |
| Lattice Datalog (Flix) | Multi-domain propagator network | Lattice values generalize Boolean Datalog to our setting |

---

## 4. Monotone Frameworks and Chaotic Iteration

### 4.1 Transfer Functions as Propagators

Kildall (1973) introduced the lattice-theoretic framework for data-flow
analysis: program analysis is fixpoint computation over a lattice, where each
program point has a lattice value and each control-flow edge has a *transfer
function* that maps input values to output values.

Kam and Ullman (1977) generalized this to *monotone frameworks*: frameworks
where transfer functions are monotone (f(x) <= f(y) whenever x <= y) but not
necessarily distributive. The key results:

1. **Fixpoint existence**: every monotone framework on a complete lattice of
   finite height has a unique least fixpoint (Tarski-Knaster).

2. **MFP = iterative solution**: the Maximal Fixed Point (MFP) solution
   computed by iteration equals the greatest solution of the data-flow
   equations. Kildall's algorithm computes MFP.

3. **MOP vs MFP**: the Meet Over all Paths (MOP) solution -- the ideal,
   path-sensitive analysis -- equals MFP when transfer functions are
   *distributive* (f(x meet y) = f(x) meet f(y)). For merely monotone
   frameworks, MFP is an over-approximation of MOP.

**Mapping to PPN**: Each propagator fire function is a transfer function.
Monotonicity of fire functions guarantees fixpoint existence. The question of
distributivity determines whether our fixpoint is exact (MOP = MFP) or
approximate:

| PPN Domain | Transfer functions | Distributive? | MOP = MFP? |
|------------|-------------------|--------------|-----------|
| Token lattice | Lexer rules | Yes (deterministic) | Yes |
| Surface lattice | Grammar productions | Yes (CFG productions distribute over union) | Yes |
| Type lattice | Type inference rules | Not always (subtyping + polymorphism) | Not always |
| Multiplicity lattice | QTT rules | Yes (multiplicity algebra is distributive) | Yes |
| Session lattice | Duality checking | Yes (session ops distribute) | Yes |

The type lattice is the exception: inference rules involving polymorphic
instantiation and subtyping are monotone but not distributive in general.
This means our type-level fixpoint may be an over-approximation of the ideal.
The meta-variable mechanism + speculation handle this: where the MFP
over-approximates, we use speculation to explore the MOP branches.

### 4.2 Chaotic Iteration

Chaotic iteration (Cousot 1977) is the observation that fixpoint computation
does not require a fixed evaluation order. Any order of applying transfer
functions reaches the same fixpoint, provided:

1. Every transfer function is applied *infinitely often* (fairness).
2. All transfer functions are monotone.
3. The lattice has finite height (ascending chain condition).

Different orders affect *efficiency* but not *correctness*. This is the
theoretical foundation for our worklist-based scheduler: propagators fire in
whatever order the worklist provides, and the result is the same regardless
of order.

**Chaotic iteration = propagator scheduling**. This correspondence is exact:

| Chaotic Iteration | Propagator Network |
|-------------------|-------------------|
| Variable | Cell |
| Transfer function | Propagator fire function |
| Iteration order | Worklist order |
| Fairness | Every enqueued propagator eventually fires |
| Convergence | Run-to-quiescence |
| Fixpoint | All cells stable |

### 4.3 Worklist Strategies and Efficiency

While chaotic iteration guarantees correctness for any fair order, the choice
of worklist strategy significantly affects performance. The data-flow analysis
literature provides guidance:

1. **Round-robin**: iterate through all transfer functions in fixed order.
   Simple but wasteful -- re-evaluates functions whose inputs haven't changed.
   This is naive evaluation (Section 3.2).

2. **Worklist (FIFO)**: enqueue functions whose inputs changed. Avoids
   redundant re-evaluation. This is semi-naive evaluation. Our current
   scheduler uses this approach.

3. **Reverse postorder (RPO)**: process functions in reverse postorder of
   the dependency graph. For reducible flow graphs, RPO converges in
   O(depth * |nodes|) iterations. For our DAG-structured dependencies
   (parse tree is a DAG, type dependencies are mostly tree-like), RPO
   would follow the natural bottom-up order.

4. **Priority worklist**: assign priorities based on lattice-height distance
   from fixpoint. Process cells closest to their fixpoint first. This
   minimizes wasted work on cells that will change again before converging.

5. **Topological/stratified**: respect stratum boundaries. Within a stratum,
   use worklist. Between strata, use the fixed order S(-1) -> S0 -> S1 -> S2.
   This IS our current approach.

**Optimal strategy for PPN**: topological-stratified with priority within
S0. Within the S0 monotone stratum:

- Parse-level propagators fire first (bottom-up, leaves to root).
- Bridge propagators fire when a domain value changes.
- Type-level propagators fire as parse cells stabilize.

This is RPO within the parse dependency DAG, composed with priority-based
firing for bridge propagators. The result: parse information flows bottom-up,
type information feeds back as soon as it's available, and bridges fire at
the earliest opportunity for disambiguation.

### 4.4 The MOP/MFP Gap and Speculation

The gap between MOP and MFP matters for PPN when type inference involves
non-distributive operations. Specifically:

**Polymorphic instantiation** is not distributive. Consider a polymorphic
function `id : forall a. a -> a` applied to a union type `Int | Bool`. The
MOP solution (path-sensitive) would track `id @Int : Int -> Int` and
`id @Bool : Bool -> Bool` separately. The MFP solution merges them into
`id @(Int|Bool) : (Int|Bool) -> (Int|Bool)`, losing the correlation between
input and output types.

Our *speculation mechanism* (save-meta-state / restore-meta-state!) addresses
exactly this gap. Speculation explores MOP branches when MFP over-approximates:

1. MFP computes the merged approximation.
2. If the approximation is too coarse (constraint unsolvable), speculation
   branches into MOP paths.
3. Each speculation branch is an ATMS assumption set.
4. Successful branches are committed; failing branches are retracted.

This is widening (MFP) followed by narrowing (speculation + retraction) --
the same pattern as Section 1.4, now grounded in the MOP/MFP distinction.

### 4.5 Summary: What Monotone Frameworks Give PPN

| Concept | PPN Mapping | Design Implication |
|---------|-------------|-------------------|
| Transfer function | Propagator fire | Must be monotone for correctness |
| MFP = iterative fixpoint | Run-to-quiescence | Worklist scheduler computes MFP |
| Distributivity | MOP = MFP | Distributive domains get exact results for free |
| MOP/MFP gap | Speculation branches | Non-distributive domains need ATMS speculation |
| Chaotic iteration | Any worklist order is correct | Choose order for efficiency, not correctness |
| RPO ordering | Parse bottom-up, type top-down | Respects natural information flow |

---

## 5. Categorical Connections

### 5.1 Galois Connections as Adjunctions

Abstract interpretation's Galois connections are adjunctions in the category
**Lat** of complete lattices and monotone maps. Given lattices C and A, a
Galois connection (alpha, gamma) with alpha : C -> A left adjoint to
gamma : A -> C means:

alpha(c) <= a iff c <= gamma(a)

This is an adjunction alpha -| gamma in Lat. The round-trip properties:

- alpha . gamma >= id_A (inflationary: concretizing then abstracting may gain information)
- gamma . alpha >= id_C (inflationary: abstracting then concretizing may gain information)

For PPN bridges:

- **Parse-to-type bridge** (alpha): given a parse, compute the type constraints
  it implies. alpha(parse) = type_constraints.
- **Type-to-parse bridge** (gamma): given type information, constrain the
  parse to be compatible. gamma(type) = parse_constraints.
- **Soundness**: alpha -| gamma guarantees that any type derived from a parse
  (alpha) is compatible with the parse constraints derived from that type
  (gamma . alpha >= id). No information is lost in the round-trip --
  information may only be gained (mutual refinement).

### 5.2 The Reduced Product as Fibered Product

The reduced product of domains A1 and A2 connected by Galois connections to
a common concrete domain C can be characterized categorically as a *fibered
product* (pullback) in the category of Galois connections:

```
A1 x_C A2 ----> A2
    |              |
    v              v
    A1 --------> C
```

This pullback IS the reduced product: elements of A1 x_C A2 are pairs
(a1, a2) that are mutually consistent with respect to C. The reduction
operator rho projects the Cartesian product A1 x A2 down to the fibered
product A1 x_C A2 by iterating mutual refinement.

**For PPN**: the 6-domain architecture (token, surface, core, type, mult,
session) forms a diagram of Galois connections. The reduced product is the
limit of this diagram -- the most precise joint analysis achievable by
combining all six domains. The propagator network computes this limit
iteratively via bridge propagators.

### 5.3 Lawvere's Quantitative View: Enriched Categories

Lawvere (1973) observed that metric spaces are categories enriched over the
quantale ([0, infinity], >=, +) -- the tropical semiring. In this view:

- Objects are points (for us: parse items or cells).
- Hom-values are distances (for us: derivation costs).
- Composition is addition of costs (the tropical product).
- Identity is zero cost.

This means **tropical-enriched parsing is parsing in a Lawvere metric space**.
Each parse item has a distance from the start symbol (its derivation cost).
The parse chart is a metric space where distance = cost. The cheapest parse
is the item closest to the start symbol. This connects Goodman's tropical
semiring (Section 2) to Lawvere's enriched-category perspective.

More broadly, each of our lattice domains can be viewed as enrichment:

| Domain | Enrichment base | Hom-value meaning |
|--------|----------------|-------------------|
| Boolean (recognition) | ({0,1}, >=, and) | Can item A derive item B? |
| Counting | (N, >=, *) | How many derivations from A to B? |
| Tropical (cost) | (R+, >=, +) | Cheapest derivation cost from A to B |
| Type lattice | (Types, <=, ->) | What type does derivation A->B have? |
| Parse forest | (SPPF, subset, concat) | What parse trees connect A to B? |

The enriched-category perspective unifies these: each semiring from Section 2
defines an enrichment, and parsing in that semiring IS computing in the
enriched category.

### 5.4 Functorial Parsing: Grammar as Functor

A grammar G defines a functor from the category of *productions* to the
category of *lattice computations*:

F_G : Prod(G) -> Lat

where Prod(G) has productions as morphisms (nonterminal -> sequence of
symbols) and Lat has lattice values as objects and monotone maps as morphisms.
Each production p : A -> B C maps to a monotone function
F_G(p) : L_B x L_C -> L_A that computes the parent's lattice value from the
children's.

This functor IS the semantic action of the grammar, viewed categorically.
Changing the target category from Lat to Set gives recognition; to (N, +, *)
gives counting; to (R+ u {inf}, min, +) gives optimization.

**The key observation**: PPN's grammar is a functor to a *product category*
Lat_token x Lat_surface x Lat_type x ... Each production simultaneously
maps to lattice computations in ALL domains. This is the functorial expression
of the reduced product: the grammar functor targets the product of all
domains, and the Galois connections between domains are natural
transformations between the component functors.

### 5.5 Grothendieck Fibration for Stratified Parsing

Our existing analysis (Categorical Foundations document, Section 4) showed
that stratification is a Grothendieck fibration over the stratum poset.
For PPN, this extends naturally:

- **Fiber S0**: monotone parsing + typing + elaboration. All bridge propagators.
  The "main" computation.
- **Fiber S1**: readiness detection for disambiguation choices. "Is the
  parse ambiguity resolvable given current type information?"
- **Fiber S2**: commitment to disambiguation choices. "Choose parse A over
  parse B based on type information."
- **Fiber S(-1)**: retraction of rejected parses and their downstream effects.

The fibration structure guarantees: S0's fixpoint is well-defined (monotone
on finite lattice). S1 observes S0's fixpoint correctly (cartesian lift).
S2's commitment pushes forward correctly (opcartesian lift). S(-1)'s
retraction is consistent (reindexing).

### 5.6 Adhesive Categories and Parse Forest Rewriting

The CALCO 2025 result (Biondo, Castelnovo, Gadducci) that e-graphs are
adhesive has direct implications for PPN. Parse forests are DAGs (shared
packed parse forests), and SPPFs share structure with e-graphs (both are
quotients of term trees by equivalence relations).

If parse forests form an adhesive category (which they should, as they are
a subcategory of hypergraphs), then:

- **DPO rewriting** on parse forests is well-defined. Grammar productions ARE
  DPO rewrite rules (as argued in the Hypergraph Rewriting document).
- **Confluence analysis** for grammar rules follows from adhesive category
  theory. Non-ambiguous grammars have no critical pairs; ambiguous grammars
  have critical pairs that the ATMS resolves.
- **Parallel application** of non-conflicting rules is sound. Multiple
  independent parse steps can fire simultaneously.

### 5.7 Polynomial Functors for Parse Decomposition

From the Categorical Foundations document: structural decomposition is a
polynomial functor. Parse decomposition is an instance:

```
p_parse(y) = y^{lhs, rhs}         for binary production A -> B C
           + y^{child}            for unary production A -> B
           + y^{}                 for terminal production A -> a
           + ...
```

Each grammar production is a summand of the polynomial. The SRE form
registry for parse forms IS the catalog of polynomial summands. Adding a
grammar production adds a summand -- extending the polynomial functor.

### 5.8 Summary: What Category Theory Gives PPN

| Concept | PPN Mapping | Design Implication |
|---------|-------------|-------------------|
| Galois connection = adjunction | Bridge soundness | Adjunction laws verify bridge correctness |
| Reduced product = fibered product | Multi-domain architecture | Limit of Galois connection diagram |
| Enriched category (Lawvere) | Semiring parsing | Each semiring = an enrichment; parsing = enriched computation |
| Grammar functor | Semantic actions | Productions map to monotone lattice functions |
| Grothendieck fibration | Stratification | Strata are fibers; transitions are lifts |
| Adhesive categories | Parse forest rewriting | DPO theory applies to parse forests |
| Polynomial functors | Parse decomposition | Grammar productions are polynomial summands |

---

## 6. ATMS-Guided Parsing: The Novel Contribution

### 6.1 Parsing as Assumption Management

Traditional parsing strategies differ in how they handle ambiguity:

| Strategy | Ambiguity handling | Weakness |
|----------|-------------------|----------|
| PEG (committed choice) | Take first match, never backtrack | May miss valid parses; grammar-order-dependent |
| LR/LALR | Shift-reduce / reduce-reduce conflicts detected; grammar restricted to avoid | Limited to unambiguous (sub)grammars |
| GLR | Produce parse forest, select later | No information to guide selection during parsing |
| GLL/Earley | SPPF, all parses | Same: selection is a separate, post-hoc phase |

All these strategies separate parsing (producing candidates) from
disambiguation (selecting among candidates). Information from later phases
(type checking, elaboration) cannot influence the parsing phase.

**ATMS-guided parsing** breaks this separation. Each ambiguous parse decision
is an **ATMS assumption**:

- "Token `foo` at position 5 is an identifier" = assumption A1
- "Token `foo` at position 5 is a keyword" = assumption A2

Each assumption generates downstream consequences via propagation:
- A1 leads to parse tree P1, which has type constraints T1
- A2 leads to parse tree P2, which has type constraints T2

If T1 is satisfiable and T2 leads to a type error, the type error generates
a **nogood** {A2}: assumption A2 is inconsistent. The ATMS retracts A2 and
all downstream consequences. Parse P2 is eliminated not by parser heuristics
but by type-level information.

### 6.2 Why This Is Strictly More Powerful

ATMS-guided parsing subsumes all classical strategies:

- **PEG**: equivalent to always selecting the first assumption and never
  exploring alternatives. A degenerate case.
- **GLR/GLL**: equivalent to making all assumptions and never retracting.
  Produces the same forest but without type-directed pruning.
- **Type-directed**: equivalent to ATMS-guided parsing without cost weighting.
  The tropical semiring addition (Section 2) adds optimization on top.

The power hierarchy:

```
PEG < LR < GLR/Earley/GLL < ATMS-guided < ATMS-guided + tropical
```

### 6.3 Connection to Existing Prologos Infrastructure

The ATMS infrastructure already exists in Prologos (Track 4 BSP-LE, Track 8D
bridges). The same mechanism used for type inference speculation works for
parse disambiguation:

| Type Inference (existing) | Parse Disambiguation (PPN) |
|--------------------------|---------------------------|
| Church fold speculation: "is this a fold?" = assumption | "Is this an application?" = assumption |
| Type checking succeeds/fails | Type checking succeeds/fails |
| save-meta-state / restore-meta-state! | ATMS assumption commit / retract |
| Speculation branches | Parse alternatives |

The key difference: type inference speculation is sequential (try one branch,
backtrack if it fails). ATMS-guided parsing is parallel (all branches exist
simultaneously, tagged by assumptions, and nogoods prune lazily). The ATMS
approach is more efficient for parsing because parse ambiguities are
typically local and independent -- multiple ambiguities can be resolved in
parallel without interaction.

### 6.4 Nogood Learning for Parse Grammars

When a type error identifies a nogood assumption set, the nogood can be
*generalized* to a grammar-level constraint:

- Specific nogood: {A2: "foo at position 5 is keyword"} -- only this instance.
- Generalized nogood: "when `foo` appears in function position, it cannot be
  a keyword" -- a grammar-level disambiguation rule.

Generalized nogoods become permanent parse constraints: they prune future
ambiguities without re-deriving the type error. This is *learned-clause
propagation* from SAT solving, applied to parsing.

For PPN, learned nogoods could be:
- Cached across parses of the same file (incremental editing preserves nogoods)
- Shared across files in the same module (module-level disambiguation)
- Elevated to grammar-level precedence rules (user-visible disambiguation)

### 6.5 Multi-Level Disambiguation

ATMS-guided disambiguation operates at multiple levels simultaneously:

1. **Lexical level**: token classification ambiguities (identifier vs keyword).
   Resolved by syntactic context propagated from the surface level.

2. **Syntactic level**: parse structure ambiguities (application vs tuple,
   prefix vs infix). Resolved by type information propagated from the type
   level.

3. **Semantic level**: overloading ambiguities (which `+` is meant?).
   Resolved by trait constraint solving propagated from the multiplicity and
   session levels.

Each level's disambiguation feeds into the others via bridges:

```
Token <--bridge--> Surface <--bridge--> Core <--bridge--> Type
                                                    |
                                              bridge to Mult
                                                    |
                                              bridge to Session
```

The ATMS tracks assumptions at ALL levels simultaneously. A nogood can span
levels: "token A1 AND parse structure P3 AND type T7 are jointly
inconsistent." This cross-level nogood pruning is unique to the ATMS approach
and impossible in traditional pipeline architectures where levels don't
interact.

### 6.6 Summary: What ATMS-Guided Parsing Gives PPN

| Concept | PPN Mapping | Design Implication |
|---------|-------------|-------------------|
| Parse choice = assumption | ATMS assumption at parse cell | Each ambiguity point generates assumptions |
| Type error = nogood | Type-level contradiction retracts parse assumption | Bridges carry nogood information backward |
| Parallel exploration | All parse alternatives coexist | No backtracking; lazy pruning |
| Nogood learning | Generalized disambiguation rules | Cache and share disambiguation knowledge |
| Multi-level nogoods | Cross-domain assumption sets | Assumptions span token/surface/type levels |
| Speculation reuse | Same mechanism as Church fold speculation | Existing infrastructure applies directly |

---

## 7. Concrete Lattice Design Proposal for PPN Track 0

### 7.1 Domain Lattices

Based on the synthesis above, the following lattice types are proposed for
each PPN domain:

#### 7.1.1 Token Lattice (L_token)

```
Carrier:  PowerSet(TokenType) u {bot, top}
Bot:      {} (unclassified)
Top:      {error-token}
Join:     set union (ambiguous token = multiple possible classifications)
Height:   |TokenType| + 2 (finite, bounded by grammar vocabulary)
Semiring: Boolean on each token type; PowerSet for ambiguity
```

Values: a token cell holds the set of possible token classifications for that
input position. `{identifier}` = unambiguous identifier. `{identifier, keyword}`
= ambiguous between identifier and keyword. The ATMS creates one assumption
per element when disambiguation is needed.

**Merge**: set union (monotone: classifications can only be added, never
removed, within S0). Removal happens in S(-1) via ATMS retraction.

#### 7.1.2 Surface Lattice (L_surface)

```
Carrier:  SPPF(SurfaceSyntax) u {bot, top}
Bot:      empty-forest (no parse)
Top:      error-forest
Join:     SPPF union (merge parse forests)
Height:   O(n^3) for input length n (Earley/CYK chart size bound)
Semiring: Forest semiring (union, concatenation)
```

Values: a surface cell holds a shared packed parse forest (SPPF) representing
all valid parses of the corresponding input span. Ambiguity is represented
as multiple packed nodes at the same span position.

**Merge**: SPPF union. Two propagators writing to the same surface cell
(two different derivations for the same span) merge their forests. This is
the forest semiring addition.

#### 7.1.3 Core Lattice (L_core)

```
Carrier:  CoreAST u {bot, top}
Bot:      unelaborated
Top:      elaboration-error
Join:     N/A (core AST is deterministic given surface + type)
Height:   Bounded by surface lattice height
Semiring: Not applicable (core is a function of surface + type, not a semiring)
```

Values: a core cell holds the elaborated AST node. This is deterministic once
the surface form and type information are known. The core lattice is NOT
independently a semiring -- it is computed from the reduced product of
surface and type.

**Merge**: replacement (when surface and type information jointly determine a
unique elaboration, the core cell is set). In the ambiguous case, core cells
are ATMS-tagged: each assumption set leads to a different core AST.

#### 7.1.4 Type Lattice (L_type)

```
Carrier:  TypeExpr u {bot, top}
Bot:      unsolved-meta
Top:      type-error / contradiction
Join:     union type (Int join Bool = Int | Bool)
Height:   Finite modulo meta-instantiation; fuel-bounded for dependent types
Semiring: Quantale (join = union, tensor = function application)
```

This is our existing type lattice, unchanged. The key property: it is a
quantale, making it simultaneously a lattice (for fixpoint computation) and
a semiring (for type-level "parsing" = elaboration).

**Merge**: existing lattice merge from `infra-cell.rkt`. Union types, subtype
joins, meta-variable refinement.

#### 7.1.5 Multiplicity Lattice (L_mult)

```
Carrier:  {0, 1, omega, error}
Bot:      unsolved (fresh multiplicity meta)
Top:      error (contradictory usage)
Join:     max (0 < 1 < omega)
Height:   4 (finite)
Semiring: Quantale ({0,1,omega}, max, *)
```

Existing lattice, unchanged. Distributive, so MOP = MFP always.

#### 7.1.6 Session Lattice (L_session)

```
Carrier:  SessionProtocol u {bot, top}
Bot:      unsolved-session
Top:      protocol-error
Join:     protocol union (ambiguous protocol)
Height:   Bounded by mu-binder depth; fuel for coinductive
Semiring: Traced monoidal (tensor = parallel composition, trace = recursion)
```

Existing lattice, adapted with union for ambiguity in protocol inference.

### 7.2 Galois Connections (Bridges)

The following bridges connect the six domains:

| Bridge | alpha (forward) | gamma (backward) | Purpose |
|--------|----------------|------------------|---------|
| Token -> Surface | Token classifications constrain valid productions | Surface parse context constrains token classification | Context-sensitive lexing |
| Surface -> Core | Surface tree guides elaboration | Core constraints refine surface (disambiguation) | Parse -> elaborate |
| Surface -> Type | Surface structure determines type skeleton | Type information disambiguates surface parses | **KEY: type-directed disambiguation** |
| Core -> Type | Elaborated AST is type-checked | Type constraints guide elaboration choices | Bidirectional type checking |
| Type -> Mult | Type structure determines multiplicity skeleton | Multiplicity violations constrain type | QTT bridge (existing) |
| Type -> Session | Type of channel determines session protocol | Session protocol constrains channel types | Session bridge (existing) |
| Token -> Type | (indirect, via Surface) | Type-level keywords inform lexing | Rare; mostly via Surface |

**New bridges for PPN** (not in current architecture):

- **Token <-> Surface**: currently implicit (the reader does lexing and parsing
  as one step). PPN separates these, requiring an explicit bridge.
- **Surface <-> Type**: currently implicit (parser produces AST, elaborator
  type-checks it). PPN makes this bidirectional.

### 7.3 Reduced Product Structure

The six domains combine via reduced product. The reduction operator iterates:

1. Parse propagators: token -> surface (production application)
2. Elaboration propagators: surface -> core (elaboration)
3. Type propagators: core -> type (type inference)
4. QTT propagators: type -> mult (multiplicity checking)
5. Session propagators: type -> session (session checking)
6. **Backward bridges**: type -> surface (disambiguation), surface -> token
   (context-sensitive lexing)

Steps 1-5 are the "forward" direction (traditional pipeline). Step 6 is
the novel backward flow that PPN enables. The reduced product iterates
until all domains are mutually consistent.

### 7.4 Required Lattice Properties

Each domain lattice MUST satisfy:

1. **Complete lattice**: bot and top exist; arbitrary joins exist. Required
   for fixpoint existence.
2. **Finite height** (or effectively finite via fuel): required for
   convergence of chaotic iteration.
3. **Monotone merge**: the merge function (cell update) must be monotone.
   This is the join operation.

Each bridge MUST satisfy:

4. **Galois connection**: alpha -| gamma. Required for soundness of the
   reduced product.
5. **Monotonicity of alpha and gamma**: both functions must be monotone.
   Required for fixpoint stability.

The overall network MUST satisfy:

6. **Stratification correctness**: non-monotone operations (ATMS retraction,
   commitment) confined to designated strata. Required for the Datalog
   stratification guarantee.

**Optional but beneficial**:

7. **Distributivity** of transfer functions: gives MOP = MFP (exact analysis).
   Holds for token, surface, mult, session. Does not hold for type.
8. **Bounded join-semilattice** (not just complete lattice): gives efficient
   merge. All our domains satisfy this.

### 7.5 Scheduling Strategy

Based on the monotone frameworks analysis (Section 4):

**Within S0 (monotone stratum)**:
- **Primary**: topological worklist. Parse propagators fire bottom-up
  (leaves to root in the parse DAG). Type propagators fire top-down for
  inherited attributes, bottom-up for synthesized attributes.
- **Bridge priority**: bridge propagators fire at medium priority -- after
  the triggering domain reaches a local fixpoint but before the receiving
  domain's next iteration.
- **Semi-naive**: only fire propagators whose input cells changed (delta
  tracking via worklist). Never re-fire a propagator with unchanged inputs.

**Across strata**:
- S0 runs to quiescence (complete the reduced product fixpoint).
- S1 checks readiness of disambiguation choices.
- S2 commits chosen disambiguations (via ATMS assumption commitment).
- S(-1) retracts rejected alternatives and their downstream effects.
- Cycle S(-1) -> S0 -> S1 -> S2 until no more disambiguations needed.

**Fuel management**: the S(-1) -> S0 -> S1 -> S2 cycle is fuel-bounded.
For well-formed programs, parsing terminates without hitting fuel limits.
For erroneous programs, the tropical semiring (error recovery costs) ensures
graceful degradation.

---

## 8. Open Questions for PPN Tracks 1-4

### 8.1 Track 0: Lattice Design

1. **SPPF as lattice**: the surface lattice uses SPPF as carrier. Is SPPF
   union truly a lattice join (associative, commutative, idempotent)? SPPF
   union is set-union on packed nodes, which satisfies these properties. But
   the *compaction* step (sharing common subtrees) is an optimization that
   must be shown to preserve the lattice properties.

2. **Tropical enrichment composability**: can the same cell carry both a
   lattice value (for correctness) and a tropical cost (for optimization)?
   The product enrichment `L_correct x L_cost` is straightforward, but does
   the tropical cost interact correctly with bridge propagators?

3. **Type lattice height**: our type lattice is infinite-height (dependent
   types nest arbitrarily). The fuel mechanism provides termination, but
   does it preserve soundness? Formally: is fuel-bounded fixpoint iteration
   a widening operator in the sense of Section 1.3?

### 8.2 Track 1: Lexer as Propagators

4. **Context-sensitive lexing**: the Token <-> Surface bridge enables
   context-sensitive lexing (e.g., indentation sensitivity). But does this
   introduce cycles between token and surface lattices? If so, the cycle
   must converge (circular attribute grammar condition, Section 3 of the
   Hypergraph document). For indentation sensitivity, convergence is
   immediate (indentation level is determined by surface structure, which
   determines token boundaries, which don't change the indentation level).

### 8.3 Track 3: Parser as Propagators

5. **Earley vs CYK on propagators**: Earley's prediction step creates new
   chart items dynamically, while CYK pre-allocates all possible span cells.
   On a propagator network, Earley corresponds to dynamic cell creation
   (cells created as predictions succeed), while CYK corresponds to static
   cell allocation (one cell per (nonterminal, span) pair). Which is more
   efficient on our infrastructure?

6. **Grammar extension and polynomial growth**: when a user adds a grammar
   production (PPN Track 7), the polynomial functor gains a summand. Does
   this affect convergence? For finite grammars, no (the chart size is
   polynomial in input length). But for grammar extensions that add
   recursive productions, termination requires the grammar to be cycle-free
   at the derivation level (which CFG guarantees structurally).

### 8.4 Track 5: Type-Directed Disambiguation

7. **Nogood granularity**: should nogoods be at the cell level ("this cell
   value is inconsistent") or the assumption level ("this assumption set is
   inconsistent")? Cell-level nogoods are more precise but more expensive
   to maintain. Assumption-level nogoods are coarser but match the ATMS
   architecture directly.

8. **Disambiguation completeness**: does ATMS-guided disambiguation always
   select the correct parse (if one exists)? For unambiguous grammars, yes
   (there is only one parse). For ambiguous grammars, the question reduces
   to: does the type system have enough information to distinguish all
   parse alternatives? This depends on the grammar and type system design --
   it is a property of the *language*, not the *mechanism*.

9. **Performance of parallel exploration**: maintaining all parse alternatives
   simultaneously (with ATMS tags) consumes memory proportional to the
   ambiguity degree. For practical programming languages, ambiguity is
   typically local and low-degree (2-3 alternatives at each ambiguity
   point). But pathological grammars could produce exponential ambiguity.
   The tropical semiring provides a mitigation: prune alternatives whose
   cost exceeds a threshold.

### 8.5 Cross-Cutting

10. **Incremental reparse granularity**: when a source edit changes a token,
    how far does the re-parse propagate? In the worst case, the entire parse
    is invalidated (e.g., changing an indentation level). In the common case,
    only a local subtree is affected. The propagator network handles this
    naturally (only changed cells trigger propagation), but the *granularity
    of cells* determines the best-case performance. Finer granularity (one
    cell per token) gives better incrementality but higher overhead. Coarser
    granularity (one cell per statement) gives lower overhead but worse
    incrementality.

11. **Self-hosting bootstrap**: if PPN parses Prologos, and PPN is written
    in Prologos, how does the bootstrap work? The initial PPN implementation
    must be in Racket (the existing parser). The Prologos PPN can then be
    defined as grammar extensions that are parsed by the Racket PPN. Full
    self-hosting requires the Prologos PPN to parse its own grammar -- a
    fixpoint that must be shown to converge.

---

## 9. Cross-Reference to Existing Infrastructure

| PPN Concept | Existing Prologos Implementation | Gap |
|-------------|----------------------------------|-----|
| Cell merge = semiring addition | `infra-cell.rkt` merge operators | Need parse forest (SPPF) merge |
| Propagator = transfer function | `propagator.rkt` fire functions | Need grammar production propagators |
| Bridge = Galois connection | `session-propagators.rkt`, Track 8D bridges | Need parse<->type bridges |
| Stratification | `metavar-store.rkt` S(-1)/S0/S1/S2 | Unchanged; PPN domains fit into S0 |
| ATMS assumptions | `tms.rkt` (Track 4 BSP-LE) | Need parse-level assumption creation |
| Worklist scheduling | `propagator.rkt` worklist | May need priority augmentation for RPO |
| Speculation | `save-meta-state`/`restore-meta-state!` | ATMS subsumes sequential speculation |
| Reduced product iteration | Bridge propagator firing loop | Already implemented as S0 quiescence |

**Key gaps to fill in PPN Tracks 1-4**:
1. SPPF data structure as a lattice value type (Track 0)
2. Grammar production propagators (Track 3)
3. Parse<->type Galois bridges (Track 5)
4. Parse-level ATMS assumption creation (Track 5)
5. Token propagators with context-sensitive lexing (Track 1)

---

## 10. References

### Seminal Works

- Cousot, P. & Cousot, R. (1977). "Abstract interpretation: a unified lattice
  model for static analysis of programs by construction or approximation of
  fixpoints." POPL 1977.
- Cousot, P. & Cousot, R. (1979). "Systematic design of program analysis
  frameworks." POPL 1979.
- Goodman, J. (1999). "Semiring Parsing." Computational Linguistics, 25(4):573-605.
- Kildall, G. (1973). "A unified approach to global program optimization."
  POPL 1973.
- Kam, J.B. & Ullman, J.D. (1977). "Monotone data flow analysis frameworks."
  Acta Informatica, 7:305-317.
- Knuth, D.E. (1968). "Semantics of context-free languages." Mathematical
  Systems Theory, 2(2):127-145.
- Earley, J. (1970). "An efficient context-free parsing algorithm." CACM,
  13(2):94-102.
- de Kleer, J. (1986). "An assumption-based TMS." Artificial Intelligence,
  28(2):127-162.
- Lafont, Y. (1990). "Interaction nets." POPL 1990.
- Shieber, S., Schabes, Y. & Pereira, F. (1995). "Principles and
  implementation of deductive parsing." J. Logic Programming, 24(1-2):3-36.

### Modern Extensions

- Cousot, P., Cousot, R. & Mauborgne, L. (2011). "The reduced product of
  abstract domains and the combination of decision procedures." FoSSaCS 2011.
- Biondo, R., Castelnovo, D. & Gadducci, F. (2025). "EGGs are adhesive!"
  CALCO 2025.
- Rau, M. (2024). "A Verified Earley Parser." ITP 2024.
- Madsen, M., Yee, M.-H. & Lhotak, O. (2016). "From Datalog to Flix: A
  Declarative Language for Fixed Points on Lattices." PLDI 2016.
- Spivak, D. & Niu, N. (2024). "Polynomial Functors: A Mathematical Theory
  of Interaction." Cambridge University Press.
- Magnusson, E. & Hedin, G. (2007). "Circular Reference Attributed Grammars."
  Science of Computer Programming, 68(1):21-37.
- Van Wyk, E. et al. (2010). "Silver: an Extensible Attribute Grammar System."
  Science of Computer Programming, 75(1-2):39-54.

---

## 11. GFP/Bilattice Parsing and Advanced Search (Post-Conversation Addendum)

*Added after conversational research (2026-03-26). See
[Kan Extensions, ATMS, GFP Parsing](2026-03-26_KAN_EXTENSIONS_ATMS_GFP_PARSING.md)
for the full development of these ideas.*

### 11.1 The Parse Bilattice

The lattice design in §7 specifies a SINGLE ordering on each domain
(derivation — what can be parsed). But parsing benefits from a DUAL
ordering: **elimination** (what can be ruled out). The combination is
a **bilattice**, paralleling WF-LE's well-founded semantics.

| Ordering | Direction | Starting point | Question |
|----------|-----------|---------------|----------|
| Derivation (lfp) | Upward from bot | No parses known | "What CAN we derive?" |
| Elimination (gfp) | Downward from top | All rules possible | "What can we NOT rule out?" |

The **well-founded parse** is the combined fixpoint: derivations that
exist AND are not eliminated. This is computed by alternating lfp and
gfp passes, exactly as WF-LE alternates knowledge and truth orderings.

**Implications for §7 lattice design**: The parse state lattice should
be a bilattice, not a simple lattice. The carrier set is the same (sets
of parse items), but with two orderings: derivation (subset inclusion)
and elimination (superset inclusion in the dual). The ATMS manages
branching across both orderings.

**Applications**:
- **Error recovery**: lfp = what DID match (partial parse). gfp = what
  COULD match (all applicable rules). Gap (gfp - lfp) = possible repairs.
  Tropical semiring selects cheapest repair.
- **Grammar extension validation**: gfp of parses with old grammar vs
  new grammar. Growth = ambiguity. Static check, no test strings needed.
- **Foreign type inference**: gfp of "what types could this value have,
  given observations." Coinductive: define by what you CAN DO, not how
  you BUILD.

### 11.2 GFP on Propagator Networks

GFP doesn't need new infrastructure. Use the **dual lattice** (reverse
ordering): top becomes dual-bot, bot becomes dual-top. Start cells at
dual-bot (original top). Propagate monotonically in the dual. The
fixpoint in the dual IS the gfp in the original.

The existing WF-LE bilattice (`newtype Knowledge`, `newtype Truth`)
already implements this pattern. The PPN analog: `newtype Derivation`
and `newtype Elimination` on the same carrier.

### 11.3 The 4-Level Search Strategy

ATMS, Kan extensions, and tropical semirings compose into a search
strategy more powerful than any single mechanism:

1. **ATMS creates branches** (full exploration space): One branch per
   parse alternative. Complete but expensive.

2. **Left Kan prunes** (speculative forwarding): Forward PARTIAL type
   information from elaboration into parse branches before full fixpoint.
   If even the lower bound contradicts a branch, prune it without
   running to fixpoint. "Speculative pruning."

3. **Right Kan focuses** (demand-driven): Among surviving branches, only
   compute what's demanded. Don't elaborate parts of a parse that no
   downstream consumer needs.

4. **Tropical selects** (cost-optimal): Among branches that survive
   pruning and produce complete results, select the cheapest.

**The composition**: Branch → Prune → Focus → Select. Each level uses
a different mechanism on the same network. The parse result is not
heuristic — it's a PROOF that the surviving parse is the unique
type-consistent, cost-optimal interpretation.

### 11.4 NF-Narrowing as Strategy Layer

Definitional trees provide OPTIMAL rule selection for inductively
sequential systems (Antoy 2005). The optimality result: needed narrowing
uses the MINIMUM number of narrowing steps. No other strategy uses fewer.

This transfers to PPN IF grammar rules are inductively sequential (each
production matches a specific nonterminal at a specific position — which
CFGs guarantee). DT-guided rule application for CFGs is conjectured
optimal.

Key correspondences:
- **Residuation = propagator waiting**: cell at bot → propagator doesn't
  fire. Identical behavior, not analogy.
- **DT dispatch = form registry**: `prop:ctor-desc-tag` IS a 1-level DT.
  Multi-level DTs handle nested pattern matching.
- **Needed narrowing = Right Kan demand**: only compute what's needed
  to reach a result.

### 11.5 Demand Lattice

Right Kan formalization requires a **demand lattice** — a lattice of
"what information is needed, at what position." Currently demands are
imperative (DT traversal in NF-Narrowing, bidirectional mode in type
checking). Formal demand lattice would unify:

- DT demands (narrowing: "which constructor at position P?")
- Type-checking demands (bidirectional: "what type does this subexpression have?")
- Parse demands (disambiguation: "what token/form is at position P?")

All three are "I need information at position P to proceed." A shared
demand lattice lets them compose: a type demand can trigger a parse
demand (need to parse more to determine the type), which can trigger a
narrowing demand (need to narrow a type variable to determine the parse).

### 11.6 Cross-Network Disambiguation Sources

Every lattice domain on the network is a potential disambiguation
source for parsing. The parser isn't standalone — it participates in
the full network's fixpoint:

| Domain | What it tells the parser |
|--------|------------------------|
| Type lattice | Arity, argument types, return types |
| Session lattice | Expected communication actions in protocol context |
| QTT multiplicities | Linear variable usage constraints |
| Effect lattice | Valid operations in current effect context |
| Module exports | Available names for import resolution |
| Trait constraints | Overloaded function resolution |
| Narrowing lattice | Possible constructors for pattern matching |
| Coercion lattice | Implicit numeric conversions |

Each flows backward (from downstream domain into parser) via Galois
bridge γ-functions. The γ-image of downstream constraints projected
into the parse domain IS the disambiguation — not heuristic, but the
mathematically-determined projection.

### 11.7 Revised Lattice Design Recommendations

Based on these insights, §7's concrete lattice design should be
extended:

1. **Parse state**: bilattice (derivation × elimination), not simple
   lattice. Two orderings on the same carrier.
2. **Demand lattice**: new domain. Carries "what's needed" information.
   Connected to parse, type, and narrowing domains via demand bridges.
3. **Cost lattice**: tropical semiring (min-plus) for optimization.
   Enriches parse state with derivation costs for optimal selection.
4. **Scheduling**: the 4-level strategy (ATMS → Left Kan → Right Kan →
   tropical) replaces simple worklist scheduling for parse-related
   strata.

---

### Foundational Category Theory

- Lawvere, F.W. (1973). "Metric spaces, generalized logic, and closed
  categories." Rendiconti del Seminario Matematico e Fisico di Milano, 43:135-166.
- Grothendieck, A. (1971). SGA 1: Revetements etales et groupe fondamental.
  Lecture Notes in Mathematics 224.
- Lack, S. & Sobocinski, P. (2005). "Adhesive and quasiadhesive categories."
  Theoretical Informatics and Applications, 39(3):511-545.
- Girard, J.-Y. (1989). "Geometry of Interaction I: Interpretation of System F."
  Logic Colloquium '88.

### Datalog and Deductive Frameworks

- Bancilhon, F. (1985). "Naive evaluation of recursively defined relations."
  Invited talk, Islamorada Workshop.
- Ceri, S., Gottlob, G. & Tanca, L. (1989). "What you always wanted to know
  about Datalog (and never dared to ask)." IEEE TKDE, 1(1):146-166.
- Engelfriet, J. & Heyker, L. (1992). "Context-free hypergraph grammars have
  the same term-generating power as attribute grammars." Acta Informatica,
  29(2):161-210.
- Courcelle, B. (1990). "The monadic second-order logic of graphs I:
  Recognizable sets of finite graphs." Information and Computation, 85(1):12-75.
