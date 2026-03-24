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
- [SRE Research](../research/2026-03-22_STRUCTURAL_REASONING_ENGINE.md) — founding insight + architectural analysis
- [NTT Syntax Design](2026-03-22_NTT_SYNTAX_DESIGN.md) — typing discipline for SRE (`:lattice :structural`)
- [NTT Case Studies](2026-03-22_NTT_CASE_STUDY_TYPE_CHECKER.md) — validation across 6 systems
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

**Dependencies**: Track 0 (form registry)

**Unblocks**: Track 2 (trait resolution needs subtyping), Track 3 (sessions need duality)

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

**Dependencies**: Track 0 (form registry)

**PM interleaving**: Partial benefit without PM 8E/8F. Full benefit with them.
Can proceed independently — the `sre-structural-relate` calls work with the
current box-based infrastructure. The SRE doesn't require cells-only access.

**Key risk**: typing-core.rkt is ~3000 lines with 40+ infer/check cases.
Each case needs migration. Incremental migration possible (convert one case at
a time, existing tests catch regressions).

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

**Dependencies**: Track 0.5 (duality relation)

**NTT validation**: Case study confirmed sessions are nearly network-native.
Main gap was involution-based decomposition — Track 0.5 delivers this.

### Track 4: Pattern Compilation-on-SRE

**Scope**: Pattern matching compilation via SRE scrutinee decomposition.

**What changes**:
- `compile-match-tree` uses SRE to decompose scrutinee types
- Pattern constructors registered as structural forms
- Narrowing-based pattern dispatch uses SRE structural matching

**Dependencies**: Track 0 (form registry)

**PM interleaving**: Independent of PM tracks. Pattern compilation doesn't
need registries as cells or metas as cells.

### Track 5: Reduction-on-SRE

**Scope**: Reduction/normalization as propagator-driven structural rewriting.
This IS PM Track 9 — the same work, SRE-framed.

**What changes**:
- `reduce` and `whnf` become propagator-driven
- Normal form cache IS the network (cell values are normal forms)
- E-graph rewriting: structural equivalence classes as SRE forms
- β/δ/ι-reduction as structural decomposition + recomposition

**Dependencies**: Track 1 (elaborator on SRE), PM 8F (metas as cells)

**Research basis**: [Track 9 Research Note](2026-03-21_TRACK9_REDUCTION_AS_PROPAGATORS.md),
interaction nets, Geometry of Interaction, e-graph equality saturation

**This may be a Track Series** given scope and research depth.

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
- **Exhaustiveness checking**: Analysis over the set of patterns, not individual decomposition
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
