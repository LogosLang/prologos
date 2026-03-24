# SRE (Structural Reasoning Engine) — Series Master Tracking

**Created**: 2026-03-22
**Status**: Active
**Thesis**: PUnify is not "the unification algorithm on propagators" — it is the
universal structural reasoning engine. Every system that analyzes, decomposes, or
matches structure (elaboration, trait resolution, pattern compilation, reduction,
session types) uses the same SRE primitives. The SRE is the operational semantics
of NTT's `:lattice :structural` annotation.

**Origin**: Track 8D principles audit → SRE Research Doc → NTT case studies

**Source Documents**:
- [SRE Research](../research/2026-03-22_STRUCTURAL_REASONING_ENGINE.org) — founding insight + architectural analysis
- [NTT Syntax Design](2026-03-22_NTT_SYNTAX_DESIGN.md) — typing discipline for SRE (`:lattice :structural`)
- [NTT Case Study: Type Checker](../research/2026-03-22_NTT_CASE_STUDY_TYPE_CHECKER.md) — deep case study, impedance mismatch analysis
- [NTT Architecture Survey](../research/2026-03-22_NTT_ARCHITECTURE_SURVEY.md) — all 7 systems as NTT skeletons, gap analysis
- [Categorical Foundations](../research/2026-03-22_CATEGORICAL_FOUNDATIONS_TYPED_PROPAGATOR_NETWORKS.md) — polynomial functor grounding
- [Unified Propagator Network Roadmap](2026-03-22_UNIFIED_PROPAGATOR_NETWORK_ROADMAP.md) — on-network/off-network boundary analysis

---

## Progress Tracker

| Track | Description | Status | Design | PIR | Notes |
|-------|------------|--------|--------|-----|-------|
| 0 | Form Registry — domain-parameterized structural decomposition | ✅ | [Design](2026-03-22_SRE_TRACK0_FORM_REGISTRY_DESIGN.md) | [PIR](2026-03-22_SRE_TRACK0_PIR.md) | sre-core.rkt: 6 functions, 23 type ctor-descs, term-value validated |
| 0.5 | Structural Relation Engine — parameterize by relation | ⬜ | — | — | Equality (default), subtyping, duality, coercion, isomorphism |
| 1 | Elaborator-on-SRE — typing-core as structural-relate calls | ⬜ | — | — | Highest leverage next step |
| 2 | Trait Resolution-on-SRE — impl lookup via structural matching | ⬜ | — | — | Needs Track 0.5 (subtyping relation) |
| 3 | Session Types-on-SRE — duality via involution relation | ⬜ | — | — | Needs Track 0.5 (duality relation) |
| 4 | Pattern Compilation-on-SRE — scrutinee decomposition | ⬜ | — | — | |
| 5 | Reduction-on-SRE — interaction nets, e-graph, GoI | ⬜ | — | — | IS PM Track 9; may be Track Series |
| 6 | Module Loading-on-SRE — exports/imports as structural matching | ⬜ | — | — | Overlaps PM Track 10 |

---

## Two-Layer Architecture

- **Layer 1: SRE** (within-domain): Registered structural forms, decomposition/composition propagators
- **Layer 2: Galois Bridges** (between-domain): Pure α/γ connections between different lattice domains

Both layers live on the same propagator network and compose automatically.
The SRE makes within-domain reasoning automatic; bridges make between-domain
reasoning automatic.

---

## Track Details

### Track 0: Form Registry ✅

**Delivered**: `sre-core.rkt` — 6 core functions, domain-parameterized structural
decomposition. `type-sre-domain` with 23 constructor descriptors. Second domain
(`term-value`) validated with zero changes to sre-core.

**Key metric**: 7358 tests, 236.7s, 3% faster than baseline.

**NTT correspondence**: `sre-domain` struct IS what NTT's `:lattice :structural`
generates. `ctor-desc` IS what NTT derives from `data` constructors.

### Track 0.5: Structural Relation Engine

**Scope**: Parameterize the SRE by structural relation. Track 0 delivers
equality (symmetric structural unification). Track 0.5 adds:

| Relation | Laws | Where it appears | Variance |
|----------|------|-----------------|----------|
| Equality | reflexive, symmetric, transitive | Unification (default) | No variance |
| Subtyping | reflexive, transitive, antisymmetric | Type checking | Contravariant domain, covariant codomain |
| Duality | involution (dual(dual(x)) = x) | Session types | All positions dualized |
| Coercion | directional (A ↪ B) | Numeric widening (Int → Num) | Covariant only |
| Isomorphism | bijective | Curry/uncurry, α-equivalence | Preserved |

**Key design question**: Does the relation parameter live on `sre-structural-relate`
(per-call) or on `sre-domain` (per-domain)? Per-call is more flexible (same domain,
different relations). Per-domain is simpler (each domain has one relation).

**Recommendation**: Per-call, defaulting to equality. The elaborator calls with equality;
session type checking calls with duality; subtyping calls with subtype relation.

**Coercion phasing note**: Coercion (runtime value transformation: Nat→Int,
Int→Rat) was identified in the Track 1 audit as a RUNTIME/REDUCTION concern,
not a compile-time structural relation. The SRE operates during elaboration
(type checking). Coercion *insertion* (where the elaborator wraps expressions
with coercion functions) IS an elaboration concern — but it requires the
elaborator-on-SRE architecture (Track 2). Track 1 focuses on the two
compile-time structural relations (subtyping, duality). Coercion becomes
relevant when the elaborator is on the SRE and can insert coercion nodes
as structural transformations during type checking.

**Dependencies**: Track 0 (form registry)

**Unblocks**: Track 2 (trait resolution needs subtyping), Track 3 (sessions need duality)

**Design document**: [Track 1 Design](2026-03-23_SRE_TRACK1_RELATION_PARAMETERIZED_DECOMPOSITION_DESIGN.md)

### Track 1: Elaborator-on-SRE

**Scope**: Rewrite `typing-core.rkt` to use `sre-structural-relate` instead of
manually installing propagators. The elaborator becomes a thin AST walker that
creates cells and calls `structural-relate` to express type relationships.

**What changes**:
- `infer`/`check` cases in typing-core call `sre-structural-relate` instead of
  manual cell creation + propagator installation
- Bidirectional type checking becomes elaboration strategy, not architectural
  distinction (both are `structural-relate`)
- The 6 cross-cutting concerns begin to simplify (zonk during elaboration
  becomes cell reads, ground-check becomes cell-level property)

**What doesn't change yet**:
- `zonk` at command boundaries (needs PM 8F: metas as cells)
- Registry access pattern (needs PM 8E: registries as cells)
- The `current-prop-net-box` (needs PM Track 10)

**Dependencies**: Track 1 (relation engine — equality + subtyping + duality)

**PM interleaving**: Partial benefit without PM 8E/8F. Full benefit with them.
Can proceed independently — the `sre-structural-relate` calls work with the
current box-based infrastructure. The SRE doesn't require cells-only access.

**Key risk**: typing-core.rkt is ~3000 lines with 40+ infer/check cases.
Each case needs migration. Incremental migration possible (convert one case at
a time, existing tests catch regressions).

**Known gaps from Track 1+1B PIR** (to address in this track):
- **Polarity inference integration**: `variance-join`/`variance-flip` utilities
  exist but aren't wired into `data` elaboration. User-defined types get `#f`
  variance (no structural subtyping). Integration = fill `component-variances`
  automatically during ctor-desc registration for `data` definitions.
- **Subtyping can't guide inference**: Track 1's subtype-relate is a CHECKER
  (fires on ground values, returns yes/no). For the elaborator-on-SRE, if
  subtyping needs to participate in inference (`?X <: Int` constraining `?X`),
  subtype-relate would need bounds propagation (cells carry intervals, not
  single values). This is a significant architectural change. Design must
  decide: keep checking (defer to metas being solved first) or add bounds.
- **Coercion insertion**: Runtime coercion (Nat→Int, Int→Rat) needs to be
  expressed as SRE structural transformations during elaboration. Deferred
  from Track 1 (runtime concern). Track 2 is where it becomes relevant.

**Design consideration from Track 1+1B PIR §14**: Structural relations are
a FAMILY of operations with different algebraic properties:
- Symmetry: equality=symmetric, subtyping=directional, duality=involutive
- Merge semantics: equality=merges cells, subtyping=checks cells, duality=swaps constructors
- Constructor mapping: equality=same tag, duality=dual tag pairs
- Binder requirements: equality=needs fresh metas, subtype/duality=ground types

When the elaborator generates structural-relate calls, the RELATION determines
decomposition mechanics. Each new relation should be analyzed along these 4 axes
before implementation. Track 1 discovered 3 bugs from equality-specific assumptions;
the elaborator-on-SRE design must not inherit these assumptions.

### Track 2: Trait Resolution-on-SRE

**Scope**: Trait constraint resolution via structural pattern matching. `impl Eq (List A) where (Eq A)` is a structural pattern — unify the constraint's type args against the impl's type pattern, extract bindings.

**What changes**:
- `try-monomorphic-resolve` / `try-parametric-resolve` replaced by
  `sre-structural-relate` with subtyping relation
- Impl registry lookups become SRE form matching
- C1-C3 bridge propagators simplified — the bridge α reads dependency cells
  and calls SRE structural matching, not custom pattern matching

**Dependencies**: Track 0.5 (subtyping relation), Track 1 (elaborator provides cells)

**PM interleaving**: Subsumes PM 8E's "resolution state" migration. The resolution
state IS the SRE's structural matching state.

### Track 3: Session Types-on-SRE

**Scope**: Session type verification via SRE with duality relation.

**What changes**:
- `sess-dual?` replaced by `sre-structural-relate` with duality relation
- Session type decomposition (Send/Recv/Choice) as registered structural forms
- Duality checking is structural: `Send(A, S) ~ dual(Recv(A', S'))` decomposes
  into `A ~ A'` (equality) and `S ~ dual(S')` (recursive duality)

**Dependencies**: Track 1 (duality relation — basic integration done in Track 1/1B)

**NTT validation**: Case study confirmed sessions are nearly network-native.
Track 1/1B delivered basic duality integration (Send/Recv/AsyncSend/AsyncRecv/Mu/DSend/DRecv).

**Known gaps from Track 1+1B PIR** (to address in this track):
- **Choice/Offer branch duality**: Variable-arity branch lists (label → session maps),
  not fixed-arity components. Current ctor-desc assumes fixed arity. Needs a different
  decomposition pattern (match branches by label, dualize each).
- **`dual` function retirement**: `sessions.rkt` still exports imperative `dual`, called
  in error messages, pretty-printing, and `typing-sessions.rkt` (4 remaining call sites).
  Track 1 replaced the `session-propagators.rkt` call site only. Full retirement
  means replacing the 4 remaining call sites with SRE-based duality queries or
  keeping `dual` as a utility for non-network uses (error formatting).

### Track 4: Pattern Compilation-on-SRE

**Scope**: Pattern matching compilation via SRE scrutinee decomposition.
Unifies term-level and type-level exhaustiveness analysis via NF-Narrowing.

**What changes**:
- `compile-match-tree` uses SRE to decompose scrutinee types
- Pattern constructors registered as structural forms
- Narrowing-based pattern dispatch uses SRE structural matching
- **NF-Narrowing as unified exhaustiveness engine**: NF-Narrowing already
  solves "given constraints, which branches are reachable?" for term-level
  values via definitional trees. GADT exhaustiveness is the same problem
  at the type level — "given type constraints, which constructor branches
  are reachable?" If type parameters are treated as narrowable positions
  (natural in our dependent type system where types and terms share a
  universe), NF-Narrowing handles both levels with one engine.
- This track delivers GADT-style exhaustiveness as a CONSEQUENCE of
  unifying term-level and type-level narrowing, not as separate machinery.

**Research connection: GADTs**:
- Our TMS/speculation infrastructure maps naturally to GADT branch
  refinement: each branch is a speculation scope where local type
  equalities (A = Int in the `lit` branch) are installed as propagators.
- Session type checking already solves the same TMS + linearity (QTT)
  interaction that GADTs require — speculative branches with linear
  resource tracking through type equality introduction.
- The "complexity cost" of GADTs is less than expected because the
  hardest parts (speculation, exhaustiveness, linearity) are solved by
  existing infrastructure built for other purposes.
- **Open question**: How much GADT expressivity do we already get from
  dependent types + spec annotations on constructors? ("80% solution")
  And how much additional work would TMS-based branch refinement add?

**Dependencies**: Track 0 (form registry)

**PM interleaving**: Independent of PM tracks. Pattern compilation doesn't
need registries as cells or metas as cells.

### Track 5: Reduction-on-SRE (Typed Graph Rewriting Engine)

**Scope**: Reduction/normalization as propagator-driven structural rewriting.
This IS PM Track 9 — the same work, SRE-framed. The deeper framing:
build a **typed graph rewriting engine** on the SRE, where GADTs,
e-graphs, interaction nets, and GoI are all applications of the same
substrate.

**The unified vision**: All four are instances of "typed (hyper)graph
with rewrite rules, executed to fixpoint":

| System | Nodes | Rewriting | Fixpoint |
|--------|-------|-----------|----------|
| GADTs | Typed terms | Pattern match with type refinement | Branch exhaustion |
| E-graphs | Equivalence classes | Rule saturation (merge classes) | Equality saturation |
| Interaction nets | Typed agents + ports | Local graph rewriting at interaction sites | Strong confluence → normal form |
| GoI | Paths in traced monoidal category | Execution traces | Trace normalization |

The SRE provides the substrate for all four:
- **SRE structural decomposition** = graph inspection (decompose a node into components)
- **Propagator network** = fixpoint execution (rewriting to saturation/normal form)
- **NTT types** = invariant preservation (rewrites are type-safe)
- **TMS** = speculation (explore multiple rewrite paths / GADT branches)
- **NF-Narrowing** = rewrite strategy (which rule applies where — definitional trees)

**What changes**:
- `reduce` and `whnf` become propagator-driven
- Normal form cache IS the network (cell values are normal forms)
- E-graph rewriting: structural equivalence classes as SRE forms
- β/δ/ι-reduction as structural decomposition + recomposition
- **Rewrite rules registered as SRE structural forms + propagators**:
  a rule becomes a propagator that watches for its LHS pattern (via SRE
  matching) and writes the RHS to the output cell
- **Strategy via NF-Narrowing**: Definitional trees determine which rules
  apply where. The narrowing lattice tracks possible reductions. This
  connects NF-Narrowing (Track 4's narrowing engine) to reduction
  strategy — the same infrastructure serves both exhaustiveness and
  reduction order selection.

**Tropical semirings and optimization**:
- E-graph extraction requires choosing WHICH equivalent form to use.
  The tropical semiring (min-plus algebra) provides a cost lattice for
  optimization: each rewrite rule carries a cost, the optimal reduction
  sequence is the shortest path in the tropical semiring.
- This connects to our logic engine: NF-Narrowing + tropical semiring =
  optimal narrowing strategy selection. Instead of "which derivation
  exists?" (boolean), "which derivation is cheapest?" (optimization).
- **Dual enrichment**: A cell simultaneously carries (a) a lattice value
  for correctness (type/term lattice, monotone propagation) and (b) a
  tropical value for optimization (cost, min-plus). The correctness
  lattice says "what are the valid reductions?" The tropical lattice
  says "which valid reduction is optimal?"
- This is the "dual quantale enrichment" identified as an open question
  in the [Categorical Foundations](../research/2026-03-22_CATEGORICAL_FOUNDATIONS_TYPED_PROPAGATOR_NETWORKS.md) §9.5.
- **Application to constraint solving**: The logic engine / NF-Narrowing
  framework becomes a general constraint solver + optimizer when extended
  with tropical semirings. "Find a solution" (SAT) becomes "find the
  cheapest solution" (optimization). Propagator networks naturally handle
  both: the lattice fixpoint finds solutions, the tropical fixpoint
  ranks them.

**Confluence and term rewriting**:
- NF-Narrowing already provides narrowing-based functional-logic
  evaluation, which touches on confluence (do all reduction paths converge
  to the same normal form?). Interaction nets guarantee strong confluence
  by construction (local rewriting, no critical pairs). E-graphs
  sidestep confluence entirely (all equivalent forms coexist).
- The SRE + propagator network can support all three strategies:
  (a) confluent rewriting (interaction net style — register only
  confluent rules), (b) equality saturation (e-graph style — register
  ALL rules, merge results), (c) narrowing (NF-Narrowing style —
  explore possible reductions, backtrack via TMS on failure).
- The strategy is a `stratification` configuration choice, not an
  architectural difference. Different `:strategy` values on the
  reduction stratum select different rewriting disciplines.

**Dependencies**: Track 1 (elaborator on SRE), PM 8F (metas as cells)

**Research basis**: [Track 9 Research Note](2026-03-21_TRACK9_REDUCTION_AS_PROPAGATORS.md),
interaction nets, Geometry of Interaction, e-graph equality saturation,
tropical semirings

**This is almost certainly a Track Series** given scope and research depth.
Suggested sub-tracks:
- 5a: β/δ-reduction as propagators (basic rewriting)
- 5b: E-graph equivalence classes (equality saturation)
- 5c: Tropical semiring optimization layer
- 5d: Interaction net / GoI integration
- 5e: Confluence verification

### Track 6: Module Loading-on-SRE

**Scope**: Module exports/imports as structural matching on the network.
Overlaps with PM Track 10.

**What changes**:
- Module loading creates network cells directly (no parameter-only path)
- Module exports/imports as structural matching (SRE form matching)
- Eliminates dual-write pattern entirely
- The network exists at startup; module loading populates it

**Dependencies**: Track 1 (elaborator), PM 8F (metas as cells)

**This IS the convergence point** with PM Track 10. When Track 6 is complete,
there is no off-network compilation state.

---

## Cross-Dependencies: SRE ↔ PM Series

The SRE and PM series describe the same migration from different angles.
SRE describes *what uses the network* (which systems do structural reasoning).
PM describes *what's on the network* (which state lives as cells).

```
PM Series (state migration)          SRE Series (system migration)
─────────────────────────            ────────────────────────────
PM 8D ✅ (3 registries+bridges)  →   SRE Track 0 ✅ (form registry)
PM 8E (17 registries as cells)   ↔   SRE Track 1 (elaborator-on-SRE)
                                      SRE Track 0.5 (relation engine)
                                      SRE Track 2 (trait resolution)
                                      SRE Track 3 (sessions)
                                      SRE Track 4 (pattern compilation)
PM 8F (meta-info as cells)       ↔   SRE Track 5 (reduction-on-SRE)
PM Track 9 = SRE Track 5
PM Track 10                      =   SRE Track 6 (module loading)
```

**Key interleaving points**:
- SRE Track 1 benefits from PM 8E (registries as cells enable propagator-driven
  registry access) but can proceed independently (SRE works with current box infra)
- SRE Track 5 requires PM 8F (metas as cells — reduction reads meta solutions)
- SRE Track 6 IS PM Track 10 (convergence)
- PM 8E's "resolution state" migration is subsumed by SRE Track 2
- PM Track 9 IS SRE Track 5 — these should be unified into one track

**Recommended ordering** (interleaved):

1. **SRE Track 1** (elaborator-on-SRE) — highest leverage, validates SRE under real load
2. **PM 8E** (registries as cells) — mechanical, unblocks full SRE Track 1 benefit
3. **SRE Track 0.5** (structural relations) — unblocks Tracks 2-3
4. **SRE Track 2** (trait resolution) — subsumes PM 8E resolution state
5. **SRE Track 3** (sessions) + **Track 4** (patterns) — can run in parallel
6. **PM 8F** (metas as cells) — prerequisite for reduction
7. **SRE Track 5/PM 9** (reduction) — unified track
8. **SRE Track 6/PM 10** (module loading + convergence) — endgame

---

## What The SRE Subsumes

| Current Infrastructure | SRE Replacement |
|----------------------|----------------|
| `punify-dispatch-sub/pi/binder` | `structural-relate` with registered forms |
| `identify-sub-cell` | `sre-identify-sub-cell` (generalized) ✅ |
| `get-or-create-sub-cells` | `sre-get-or-create-sub-cells` (generalized) ✅ |
| `make-pi-reconstructor` | SRE reconstruction propagator (registered) ✅ |
| `make-structural-unify-propagator` | `sre-make-structural-relate-propagator` ✅ |
| Manual propagator installation in elaborator | `structural-relate` calls (Track 1) |
| `ground-expr?` | Groundness propagators on SRE decomposition graph (Track 1) |
| `zonk` (during elaboration) | Cell reads (Track 1 + PM 8F) |
| `try-monomorphic-resolve` / `try-parametric-resolve` | SRE structural matching (Track 2) |
| `sess-dual?` | SRE duality relation (Track 3) |
| `compile-match-tree` scrutinee decomposition | SRE structural matching (Track 4) |
| `reduce` / `whnf` | SRE structural rewriting (Track 5) |
| Bridge fire functions (C1-C3) | SRE matching + Galois bridges (Track 2) |

## What The SRE Does NOT Subsume

- **Parser / reader**: Syntactic phase, pre-network
- **QTT multiplicity tracking**: Separate lattice domain, connected via Galois bridges
- **Exhaustiveness checking**: Partially subsumed — NF-Narrowing unified with type-level
  narrowing (Track 4) handles GADT-style exhaustiveness. Pure combinatorial exhaustiveness
  (are all constructors covered?) remains a separate analysis over the pattern set.
- **I/O effects**: External system interaction
- **Session duality computation**: Domain-specific (but SRE handles the structural matching around it via Track 0.5)
- **Opaque foreign types**: May use coinductive observations (NTT `codata`) but not SRE structural decomposition

---

## NTT Correspondence

The SRE is the operational semantics of NTT's type system at Levels 0-2:

| NTT Concept | SRE Implementation |
|------------|-------------------|
| `data T ... :lattice :structural` | `sre-domain` struct |
| Constructor fields | `ctor-desc` (polynomial summands) |
| `:bot` / `:top` | `sre-domain` sentinels |
| Auto-derived merge | `sre-structural-relate` propagator |
| Value lattice (`impl Lattice`) | Not SRE — pure join function |
| Structural relation (equality/duality/subtyping) | Track 0.5 relation parameter |

Building the SRE with this correspondence explicit makes NTT implementation
a code-generation step, not a redesign. Each `sre-domain` IS what NTT would
generate from a `data` definition with `:lattice :structural`.

---

## Conjecture: Lattice Computing Optimality

PUnify demonstrated that propagator-based structural unification can match or beat
optimized imperative unification (Robinson's algorithm). The working conjecture:

> Lattice computing over fixpoints (with speculative+demand-driven scheduling and
> stratified recovery) IS optimal computing. The network's topology adapts to the
> data regime — information flows where it's needed, when it's needed.

An imperative algorithm encodes a *fixed traversal order*. A lattice network
explores the solution space *in the order that information arrives*. You can't do
better than "process the most-constrained thing next" — which is what propagator
scheduling does when cells with new information fire their dependents.

If the SRE generates network topology correctly (from type definitions, function
definitions, and program structure), the generated network captures this optimality
for every structural reasoning task. Each SRE track is a test of this conjecture.
