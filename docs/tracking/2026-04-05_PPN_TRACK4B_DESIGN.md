# PPN Track 4B: Elaboration as Attribute Evaluation — Stage 3 Design (D.2)

**Date**: 2026-04-05 (D.1), 2026-04-06 (D.2 — external critique integration)
**Series**: [PPN (Propagator-Parsing-Network)](2026-03-26_PPN_MASTER.md) — Track 4B
**Predecessor**: [PPN Track 4A D.4](2026-04-04_PPN_TRACK4_DESIGN.md)
**Predecessor PIR**: [PPN Track 4A PIR](2026-04-04_PPN_TRACK4_PIR.md)
**Foundation**: [Prologos Attribute Grammar](../research/2026-04-05_PROLOGOS_ATTRIBUTE_GRAMMAR.md) — formal attribute mapping
**Principle**: Propagator Design Mindspace, Engelfriet-Heyker equivalence (HR grammars = attribute grammars)

**Research**:
- [Lattice Foundations for PPN](../research/2026-03-26_LATTICE_FOUNDATIONS_PPN.md) — type-lattice semiring, Galois bridges
- [Adhesive Categories](../research/2026-04-03_ADHESIVE_CATEGORIES_PARSE_TREES.md) — CALM-adhesive guarantee
- [Hypergraph Rewriting](../research/2026-03-24_HYPERGRAPH_REWRITING_PROPAGATOR_PARSING.md) — Engelfriet-Heyker
- [Grammar Form Design Thinking](2026-04-03_GRAMMAR_FORM_DESIGN_THINKING.md) — attribute grammar thread
- [Attribute Grammar Research](../research/2026-04-05_ATTRIBUTE_GRAMMARS_RESEARCH.md) — catamorphisms, aspects, CLP, DCGs, higher-order AGs

---

## Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| 0a | Fix multi-path component-indexed firing (foundational) | ✅ | commit `246e4fb3`. Fixed `assoc` first-match → list-based multi-path. App/lam/pi propagators now declare exact read positions. |
| 0b | Constraint domain lattice design (explicit design phase) | ✅ | CLP-inspired domain narrowing. Powerset lattice (⊇ ordering, intersection join). Heyting algebra. SRE domain registered. Replaces Track 4A Phase 6 flat lattice. See §11. |
| 0c | .pnet attribute cache design | ⬜ | What's cached, invalidation strategy, structural sharing format, warm-start preloading. See §9.6. |
| 0d | BSP scheduler audit + correction | ✅ | commit `246e4fb3`. Default was already `#t` (corrected D.1). Hardened 3 ephemeral PU sites to explicit `run-to-quiescence-bsp`. 3 test DFS overrides verified legitimate. |
| 0 | Stage 2 audit + attribute grammar specification | ✅ | [Attribute Grammar](../research/2026-04-05_PROLOGOS_ATTRIBUTE_GRAMMAR.md): 5 domains, 12 node kinds, stratification. [AG Research](../research/2026-04-05_ATTRIBUTE_GRAMMARS_RESEARCH.md): catamorphisms, CLP, aspects. |
| 1 | Attribute Record PU: extend type-map to full attribute record | ✅ | commit `90e4979e`. Nested (position → (hasheq facet → value)). that-read/that-write API. Facet-aware diffing. Compound component-paths. :type + :context facets. |
| 2 | Constraint attribute propagators (S0: creation during typing) | ✅ | commit `b900f04f`. Reuses constraint-cell.rkt lattice (§11 already implemented). Constraint-creation + type-narrows-constraints propagators. Cross-facet :type→:constraints bridge. |
| 3 | Trait resolution propagators (S1: readiness-triggered) | ✅ | commit `74f79506`. Meta-feedback + Option C (skip domain write for metas) + S1 resolution + output bridge. **All 17 files (59 tests) pass individually.** Suite 17→12 (batch isolation). |
| 4 | Multiplicity attribute propagators (S0: usage tracking + S2: validation) | ⬜ | QTT: single-usage, zero-usage, add-usage, scale-usage as cell ops. S2 validation: compatible(declared, actual). |
| 5 | Structural unification propagators (S0: Pi/Sigma decomposition) | ⬜ | Reuse make-structural-unify-propagator inside ephemeral PU. K-indexed sub-cell decomposition. |
| 6 | Meta solution bridging (ephemeral → main network) | ⬜ | PU output channels for solved metas, resolved constraints. Resolved type-map resolution (F1 from Track 4A, now with correct component firing). |
| 7 | Warning attribute propagators (S2: accumulation + reporting) | ⬜ | Coercion, deprecation, capability warnings as cell values. |
| 8 | ATMS integration for union type checking (S(-1): retraction) | ⬜ | ATMS branching within the attribute PU. Per-branch attribute records. |
| 9 | Retire imperative fallback: infer/check + resolve-trait-constraints! + checkQ + freeze | ⬜ | infer-on-network/err becomes the ONLY path. 100% on-network for typing + constraints + multiplicities + warnings. |
| 10 | Zonk retirement (from Track 4A Phase 4b) | ⬜ | Cell-refs replace expr-meta; fan-in default propagator at S2. |
| 11 | Scaffolding retirement (from Track 4A Phase 8) | ⬜ | 8 items from Tracks 2H + 2D. |
| T | Dedicated test file | ⬜ | Attribute-level tests: per-domain, per-node-kind, per-stratum. |
| 12 | Verification + PIR | ⬜ | Full suite GREEN, A/B benchmark, acceptance file, PIR. |

---

## §0 Objectives

**End state**: Type inference, constraint resolution, multiplicity checking, and zonking are FULLY on-network as attribute evaluation within encapsulated Pocket Universe shells. The imperative `infer/check`, `resolve-trait-constraints!`, `checkQ`, and `freeze` are retired. The core expression (from `elaborate-top-level`) gains attributes through propagator fixpoint — the typed, resolved, checked result EMERGES from quiescence.

**Reframing from Track 4A**: Track 4A framed the goal as "move side effects on-network." The attribute grammar analysis revealed this was too narrow. The side effects ARE attributes — facets of the same evaluation. The right framing: typing + resolution + checking = attribute evaluation on a structured PU value.

**What Track 4B delivers**:
1. **Foundational fix**: Multi-path component-indexed firing (the Phase 1a bug that caused thrashing)
2. **Constraint domain lattice**: CLP-inspired domain narrowing for constraints, designed with SRE algebraic structure
3. **The Attribute Record PU**: each AST node has a record with 5 facets (type, context, multiplicity, constraints, warnings) in encapsulated PU shells with own stratification (S0→S1→S2)
4. **Attribute propagators for ALL 5 domains** at appropriate strata
5. **Global attribute store** with CHAMP structural sharing and .pnet caching
6. **`that` operation** (internal API): first-class attribute read/write on the PU, designed for future user-facing exposure
7. **Retirement of imperative fallback**: `infer/check`, `resolve-trait-constraints!`, `checkQ`, `freeze`
8. **The SRE typing domain extended to full attribute rules** (not just type rules)

**What this track is NOT**:
- It does NOT move the surface→core structural transformation on-network — `elaborate-top-level` stays imperative. Elaboration-as-attributes (implicit arg insertion, name resolution, macro expansion as propagators) is **PPN Track 4C** scope, which depends on **SRE Track 6** (DPO rewriting infrastructure with e-graphs).
- It does NOT move β/δ/ι-reduction on-network — that's **SRE Track 6** scope. Track 4B uses `subst`, `whnf`, `nf` as pure function calls within propagator fire functions. SRE Track 6 replaces these with DPO rewriting later.
- It does NOT implement the self-hosted compiler — but it provides the attribute grammar data that the self-hosted compiler will consume.
- It does NOT design user-facing `that` syntax — that's **Grammar Form R&D** scope. Track 4B builds the internal mechanism.

**Track relationships**:
- **PPN Track 4B** (this track): attribute evaluation for typing + constraints + mult + warnings. Receives core expr from imperative elaborator.
- **SRE Track 6** (dependency): DPO rewriting with e-graphs over tropical semirings. Provides optimal reduction infrastructure.
- **PPN Track 4C** (future, depends on SRE 6): elaboration structural transformations as attribute propagators. Replaces `elaborate-top-level` with DPO rewriting. Also absorbs `whnf`/`nf` replacement via SRE 6.

---

## §1 The Attribute Grammar Foundation

### §1.1 Five Attribute Domains

The [Prologos Attribute Grammar](../research/2026-04-05_PROLOGOS_ATTRIBUTE_GRAMMAR.md) identifies five domains. Each has a lattice, a direction (inherited/synthesized), and a stratum:

| Domain | Direction | Lattice | Stratum | Track 4A Status |
|--------|-----------|---------|---------|----------------|
| **Type** | Synthesized ↑ + Inherited ↓ (check mode) | Type lattice (Track 2H) | S0 | 46% on-network |
| **Context** | Inherited ↓ | Context lattice (Phase 1c) | S0 | On-network (Pattern 5) |
| **Constraint** | Synthesized ↑ (created at nodes) | Constraint lattice (Phase 6) | S0 (creation), S1 (resolution) | Lattice built, not wired |
| **Multiplicity** | Synthesized ↑ | Mult semiring (m0, m1, mw) | S0 (tracking), S2 (validation) | Mult cells exist (PM Track 8), not wired to typing PU |
| **Warning** | Synthesized ↑ (accumulated) | Set lattice (monotone union) | S2 (collection) | Not on-network |

### §1.2 The Attribute Record

Each AST node position in the PU has a RECORD with one field per domain:

```
AttributeRecord = {
  type        : TypeLattice            ;; ⊥ → concrete → ⊤
  context     : ContextLattice         ;; binding stack (inherited from parent scope)
  usage       : UsageVector            ;; (listof mult) — one per context binding
  constraints : (Setof ConstraintInfo) ;; trait, unification, capability
  warnings    : (Setof WarningInfo)    ;; coercion, deprecation, capability
}
```

Track 4A's type-map held only the TYPE facet. Track 4B extends this to the full record.

### §1.3 Cross-Domain Bridges

Information flows BETWEEN attribute domains via bridge propagators:

| Bridge | From → To | Mechanism | Stratum |
|--------|-----------|-----------|---------|
| Type → Constraint | App typing reveals trait constraints | Implicit arg insertion detects trait domains | S0 |
| Constraint → Type | Resolved trait fills dict-meta type | `solve-meta!` writes to type position | S1 |
| Type ↔ Mult | Pi multiplicity extracted/injected | `type->mult-alpha` / `mult->type-gamma` bridge | S0 |
| Type → Warning | Cross-family types → coercion warning | Comparison of arg types at app positions | S2 |
| Constraint → Warning | Unresolved constraint → error | `build-trait-error` at S2 commitment | S2 |

### §1.4 Stratification

| Stratum | What Evaluates | Monotonicity | When |
|---------|---------------|--------------|------|
| **S0** | Type inference/checking, context extension, constraint CREATION, usage tracking | Monotone (cells only gain info) | Main fixpoint |
| **S1** | Trait resolution, hasmethod resolution, constraint retry | Readiness-triggered (fires when dependencies are ground) | After S0 quiescence |
| **S2** | Meta defaulting, multiplicity VALIDATION, warning collection, error reporting | Non-monotone (commitment decisions) | After S0+S1 quiescence |
| **S(-1)** | ATMS retraction (union type branches that contradict) | Non-monotone (remove info) | On contradiction |

---

## §2 The Propagator Design Mindspace: Four Questions

### Question 1: What is the INFORMATION?

The typed, resolved, checked expression. Not just types — the FULL attribute record for every node. Every fact that the current imperative pipeline computes.

### Question 2: What is the LATTICE?

The REDUCED PRODUCT of all five domain lattices. Each domain has its own lattice (§1.1). The cross-domain bridges (§1.3) create interactions. The product is NOT a formal Cousot-Cousot reduced product — it's a multi-domain product with bridge propagators (same terminology correction as Track 4A D.3 §2d).

### Question 3: What is the IDENTITY?

Each AST node IS a position in the attribute PU. The position holds an attribute record. Two propagators writing to the same position's type facet merge via type-lattice-merge. Two propagators writing to the same position's constraint facet merge via set-union. Identity IS the position.

### Question 4: What EMERGES?

The fully-elaborated expression EMERGES from all positions reaching stable attribute records:
- All type facets are concrete (no ⊥, no unsolved metas)
- All constraint facets are resolved (traits found, constraints satisfied)
- All usage facets are validated (multiplicities compatible)
- All warning facets are collected (diagnostics ready)
- Contradiction at any type facet = type error with ATMS dependency trace

---

## §3 Architecture: The Attribute PU

### §3.1 PU Structure

The attribute PU is an ephemeral prop-network (Track 4A §15) whose single cell value is the ATTRIBUTE MAP — a hasheq mapping AST node positions to attribute records.

```
Attribute PU (ephemeral prop-network):
  ONE cell: attribute-map (hasheq position → attribute-record)
  Merge: component-wise across all 5 facets
    type:        type-lattice-merge
    context:     context-cell-merge
    usage:       usage-vector-join (pointwise mult-add)
    constraints: set-union (monotone)
    warnings:    set-union (monotone)

  Propagators (installed per AST node, fire at appropriate strata):
    S0: typing propagators (existing from Track 4A)
    S0: context-extension propagators (existing from Track 4A Pattern 5)
    S0: constraint-creation propagators (NEW: detect trait domains, create constraint entries)
    S0: usage-tracking propagators (NEW: compute usage vectors per node)
    S1: trait-resolution propagators (NEW: watch type facets, resolve when ground)
    S1: constraint-retry propagators (NEW: retry unification when metas solve)
    S2: meta-default propagator (existing: Track 4A Phase 4b-i fan-in readiness)
    S2: usage-validation propagator (NEW: check compatibility with declared mults)
    S2: warning-collection propagator (NEW: gather all warnings for reporting)

  Output channels (bridge to main elab-network):
    Root type → for return to process-command
    Solved metas → solve-meta! on main network (for zonk + downstream)
    Resolved traits → trait constraint cells on main network
    Diagnostics → warning reporting
```

### §3.1a Position Identity Protocol

Each AST node in the core expr IS a position in the attribute map. The position key is the **eq?-identity** of the `expr-*` struct produced by `elaborate-top-level`. This works because elaboration produces a fresh struct tree per command — no struct is shared across commands.

**Position assignment**: `install-attribute-network` recursively decomposes the core expr tree. Each `expr-*` struct encountered becomes a position key in the attribute map. Sub-expression positions are linked to their parent by the propagators installed at each node (e.g., the app propagator reads from func-pos and arg-pos, writes to this-pos).

**Substitution-created nodes**: When a dependent codomain requires substitution (`subst(0, arg-expr, cod)`), the substitution creates FRESH expr structs. These get fresh positions in the attribute map — they are new nodes, not aliases of existing ones. Track 4A's expression-key substitution (commit `d8a22c3`) established this pattern: the substituted codomain is a new position whose type is written by the app propagator's upward write.

**Meta-variable positions**: `expr-meta` nodes from implicit argument insertion are positions like any other. They start with type facet = ⊥ (type-bot). Propagators write to them (bidirectional app writes domain type, structural unification writes decomposed types). The meta IS the position — there is no separate "meta-variable" entity. See §3.6 for the full meta lifecycle.

### §3.2 How Evaluation Works

1. **Form cell at 'done'** → `elaborate-top-level` produces core expr (still imperative for structural transformation).

2. **Create attribute PU** — ephemeral prop-network with attribute-map cell.

3. **Install attribute propagators** — `install-attribute-network(net, cell, expr, ctx)`:
   - For each AST node: install typing propagator (S0) + usage propagator (S0)
   - For each app with implicit args: install constraint-creation propagator (S0)
   - For each binder: install context-extension propagator (S0)
   - For each trait constraint: install resolution propagator (S1)
   - Install meta-default propagator (S2) + usage-validator (S2) + warning-collector (S2)

4. **Run to stratified quiescence**:
   - S0: types, contexts, constraints, usages flow to fixpoint
   - S1: traits resolve, constraints retry
   - S2: defaults written, multiplicities validated, warnings collected

5. **Bridge outputs** — read the attribute map, write results to main network:
   - Root type → return value
   - Solved metas → `solve-meta!` for each resolved meta position
   - Trait solutions → update constraint cells
   - Warnings → accumulate for reporting

6. **Discard PU** — GC the ephemeral network.

**Cross-command composition**: results from one command's attribute PU are visible to subsequent commands through the ENVIRONMENT, not through PU-to-PU communication. When `def f [x] [+ x 1]` is evaluated, the output bridge writes `f`'s type to the environment. When `[f 42]` is evaluated, `elaborate-top-level` resolves `f` to `expr-fvar` and the typing propagator reads the type from `lookup-toplevel-type`. The global attribute store (§9) caches full attribute records for this purpose — subsequent references to `f` start from the cached record, avoiding re-evaluation.

### §3.3 Network Hosting Decision

**Track 4B implements the EPHEMERAL PU architecture** (§3.1). Each command's attribute evaluation runs in a fresh, isolated prop-network. Results are bridged to the main elab-network via output channels (§13). The ephemeral PU is discarded after output bridging.

This is a **deliberate, validated choice**: Track 4A proved ephemeral PUs work (no accumulation regression, clean GC, isolation between commands). The alternative — scoped propagators on the main network — is theoretically superior but unvalidated at scale.

**Future target: scoped propagators on the main elab-network.** In this model, attribute propagators live ON the main network, become INERT after quiescence (no deletion, no firing — inputs stabilize). Results stay on-network, observable to downstream propagators, composable with the form pipeline. This follows the same pattern as form-cell pipeline propagators in Track 3. Advantages: provenance, error-reporting, and observability benefit from on-network results. Self-hosting compilation can read attribute records directly from the main network.

**Why not now**: Track 4A's 3-timeout regression was caused by propagator accumulation on the main network. The inertness argument (stable inputs → no re-firing) is sound in theory but needs empirical validation: do inert propagators cause memory pressure over hundreds of commands? Does CHAMP structural sharing keep growth sub-linear? These questions require Track 4B's full attribute evaluation working first.

**Migration path**: the attribute-map cell structure and propagator fire functions are IDENTICAL in both models — only the network hosting changes. Phase 11 (scaffolding retirement) or a follow-on track evaluates migration from ephemeral to scoped-on-main once accumulation behavior is characterized under full attribute evaluation load. The internal API (`that-read`, `that-write`, `install-attribute-network`) abstracts over the hosting model.

### §3.4 Why Attribute Records, Not Separate Maps

Track 4A used separate maps: type-map for types, separate context positions for contexts. This created complexity — different merge functions, different position key spaces, special cases for context-cell-values in the type-map merge.

The attribute record unifies these: ONE map, ONE merge (component-wise), ONE position space (AST nodes). Each facet merges independently via its domain's lattice. No special cases.

### §3.4 Relation to Track 4A

Track 4A's infrastructure becomes FACETS of the attribute record:
- `type-map` → the TYPE facet of the attribute map
- `context positions` → the CONTEXT facet
- `meta-readiness cell` → the META-STATUS sub-facet for S2 defaulting
- `constraint lattice` → the CONSTRAINT facet's merge function
- `SRE typing domain` → extended to ATTRIBUTE domain (type + usage + constraints per entry)

All Track 4A code is reusable — it's the TYPE facet implementation. Track 4B adds the other four facets alongside it.

### §3.5 Unification = Merge (Foundational Invariant)

**There is no separate unification step.** Unification IS the merge function on the type facet of the attribute map.

When two propagators write different type values to the SAME position, `type-lattice-merge` (Track 2H quantale) computes the most-general unifier:
- Compatible types merge to the unified type: `merge(Int, Int) = Int`
- Meta meets concrete: `merge(⊥, Int) = Int` (the meta gains its solution)
- Incompatible types merge to ⊤: `merge(Int, String) = ⊤` (type error)

This is NOT an approximation of unification — it IS unification, by construction. The Track 2H type lattice was designed so that the merge operation coincides with the most-general unifier on the type carrier. The lattice merge is commutative, associative, and idempotent — exactly the properties required for sound unification in a concurrent propagator network where write order is non-deterministic.

**Bidirectional application writes ARE unification**. The app propagator writes `dom` downward to the arg position and `subst(0, arg-expr, cod)` upward to the result position. If the arg position already has a type from its own typing propagator, the merge of `dom` with that type IS the unification of the function's expected argument type with the argument's inferred type. Merge failure (⊤) = type mismatch.

**Structural unification** handles compound types. When `merge(Pi(m, ?A, ?B), Pi(m, Int, String))` is needed, a structural unification propagator (Phase 5) DECOMPOSES this into sub-writes: `?A ← Int`, `?B ← String`. Each sub-write is itself a merge on the sub-position. This is the propagator equivalent of the "decompose" rule in standard unification algorithms, but distributed across cells rather than executed as a sequential algorithm.

**Occurs check**: The standard unification occurs check (`?A ∉ FV(T)` before solving `?A = T`) is handled by contradiction detection — if a cyclic merge produces ⊤, the type error is reported. This is sound because the type lattice has no infinite ascending chains (well-founded by construction).

### §3.6 Meta-Variable Lifecycle on the Network

A meta-variable is NOT a special entity — it is an **attribute-map position that starts at ⊥**.

**1. Creation** (imperative elaborator, before attribute PU):
`elaborate-top-level` inserts `expr-meta` nodes for implicit arguments. Each `expr-meta` becomes a position in the attribute map with type facet = ⊥ (type-bot). The meta IS the position. The imperative `meta-store` (CHAMP mapping meta-id → meta-info) tracks metadata (origin, kind, expected-type), but the TYPE SOLUTION lives in the attribute map.

**2. Solution** (S0 propagators, during attribute evaluation):
Propagators write to meta positions through normal cell writes:
- **Bidirectional app**: writes domain type downward to arg-meta position → merge(⊥, dom) = dom. The meta is solved.
- **Structural unification** (Phase 5): decomposes `Pi(?A, ?B)` matching against `Pi(Int, String)` → writes `Int` to `?A`'s position, `String` to `?B`'s position.
- **Constraint narrowing**: when a constraint domain reaches singleton, the resolution propagator writes the resolved dict expression to the dict-meta position.

Each write is a MERGE — if multiple paths converge on the same meta (e.g., two uses of `?A` in different positions), they must agree (merge to the same type) or contradict (⊤ = type error).

**3. Bridging** (Phase 6, output channels):
After internal quiescence, the output bridge reads solved meta positions (type facet ≠ ⊥) and calls `solve-meta!` on the main network for each. This bridges the ephemeral PU's solutions into the main `meta-store` CHAMP, triggering downstream resolution (trait constraints that depend on the solved meta, hasmethod retry, etc.).

**4. Defaulting** (S2, after S0+S1 quiescence):
Metas that remain at ⊥ after all monotone (S0) and readiness (S1) computation are UNSOLVED. The meta-default propagator (fan-in threshold from Track 4A Phase 4b-i) writes default values:
- Level metas → `lzero` (universe level 0)
- Multiplicity metas → `mw` (unrestricted usage)
- Session metas → `sess-end` (session termination)
- Type metas with no constraints → type error (genuinely ambiguous)

Defaulting is S2 (non-monotone commitment) because it OVERWRITES ⊥ with a chosen value, foreclosing other possible solutions. This is safe only after S0+S1 prove no further monotone progress is possible.

---

## §4 Elaboration Boundary and Scope

### §4.1 What Track 4B Receives (from imperative elaborator)

Track 4B receives the CORE EXPR from `elaborate-top-level`. By the time the attribute PU sees the expression:
- Surface syntax has been transformed to core AST (expr-* structs)
- Implicit arguments have been inserted as `expr-meta` nodes
- Names have been resolved to qualified `expr-fvar` / de Bruijn `expr-bvar`
- Trait constraints have been registered via `register-trait-constraint!`
- HasMethod constraints have been registered via `register-hasmethod-constraint!`

### §4.1a Handoff Protocol: Elaborator → Attribute PU

The handoff from imperative elaboration to attribute evaluation is a FUNCTION CALL, not a cell write:

1. `process-command` calls `elaborate-top-level(surface-expr, env)` → returns core expr (imperative)
2. `infer-on-network(core-expr, env, ctx)` creates the ephemeral attribute PU:
   a. `(make-prop-network)` — fresh network
   b. `(install-attribute-network net cell core-expr ctx)` — recursive decomposition installs propagators
   c. `(run-to-quiescence-bsp net)` — stratified evaluation
   d. Read output channels → bridge results to main network
   e. Discard PU

This boundary is DELIBERATE — `elaborate-top-level` does structural transformation (surface → core) which is imperative in Track 4B. Track 4C moves structural transformation on-network via DPO rewriting. The handoff protocol in Track 4B is simple: imperative function produces data (core expr), propagator network consumes it.

**Error handling**: if `elaborate-top-level` fails (parse error, name resolution error), no attribute PU is created. Elaboration errors are reported directly. The attribute PU only sees WELL-FORMED core expressions.

### §4.2 What Track 4B Evaluates (attribute propagators)

Given the core expr, the attribute PU computes:
- **Type attributes** (S0): the type of every sub-expression (Track 4A's scope, extended)
- **Constraint attributes** (S0): constraint DOMAIN narrowing alongside type computation
- **Trait resolution** (S1): resolving trait constraints when argument types are ground
- **Multiplicity attributes** (S0+S2): usage tracking + validation
- **Warning attributes** (S2): coercion, deprecation detection
- **Meta defaulting** (S2): fan-in for unsolvable metas

### §4.3 What Track 4C Will Add (future, depends on SRE 6)

Track 4C moves the elaboration structural transformation ON-network:
- Implicit argument insertion as attribute propagators (DPO rewriting on the form cell)
- Name resolution as attribute propagators
- Macro expansion as attribute propagators
- `whnf`/`nf` as DPO rewriting (replaces function calls in propagator fire functions)

Track 4C depends on SRE Track 6 for the DPO rewriting + e-graph infrastructure.

### §4.4 Constraint Registration in Track 4B

The imperative elaborator ALREADY registers trait constraints before the attribute PU runs. Track 4B's constraint propagators READ these registrations and create corresponding constraint domain cells in the attribute PU.

The constraint-creation propagator (S0) reads the registered `trait-constraint-info` from the main elab-network (via bridge read) and creates a constraint domain entry in the attribute record for the corresponding node. The domain lattice (Phase 0b) represents the set of possible trait instances, narrowed as type information refines.

**Known off-network boundary: impl registry.** The impl registry (`current-impl-registry`) is a Racket-side hash table, NOT a cell on any propagator network. Constraint-creation and trait-resolution propagators read this registry at fire time via direct hash-table lookup. This is an off-network oracle read.

This is acceptable for Track 4B because the impl registry is **STATIC within a single command's attribute evaluation** — impl registrations happen at module-load time, before any command is processed. During attribute evaluation, no new impls are registered. Reading a constant is not an information-flow violation.

**Migration plan**: PM Track 7 (module loading infrastructure) migrates the impl registry to cells. When the registry becomes a cell, adding a new impl (loading a new module) triggers re-evaluation of affected constraints — enabling incremental recompilation. This is out of scope for Track 4B but the constraint-creation propagator's interface (`lookup-impls-for-type(trait, type)`) is designed to be swappable: replace the hash-table read with a cell read when Track 7 provides it.

---

## §5 Existing Infrastructure Mapping

| Infrastructure | File | Maps To | Reuse Strategy |
|---------------|------|---------|----------------|
| Type propagators (install-typing-network) | typing-propagators.rkt | TYPE facet S0 propagators | Direct reuse — becomes one facet of install-attribute-network |
| Context-extension propagators | typing-propagators.rkt | CONTEXT facet S0 propagators | Direct reuse |
| SRE typing domain (~150 entries) | typing-propagators.rkt | Attribute domain TYPE column | Extend entries with usage + constraint columns |
| Constraint lattice (join/meet) | typing-propagators.rkt | CONSTRAINT facet merge | Direct reuse |
| Meta-readiness fan-in | typing-propagators.rkt | META-STATUS sub-facet for S2 | Direct reuse |
| Constraint narrowing P1-P4 | constraint-propagators.rkt | S1 trait resolution propagators | Install P1 inside the attribute PU |
| Structural unify propagators | elaborator-network.rkt | S0/S1 unification propagators | Install inside the attribute PU for Pi/Sigma decomposition |
| Trait resolution (pure) | trait-resolution.rkt | S1 resolution fire function | Call from S1 propagator's fire-fn |
| Multiplicity cells + bridge | elaborator-network.rkt + qtt.rkt | MULT facet propagators | Install mult bridge inside attribute PU |
| ATMS (atms-assume/retract) | atms.rkt + elab-speculation-bridge.rkt | S(-1) for union type branching | Integrate with attribute PU's quiescence |
| BSP stratification | propagator.rkt | Attribute PU evaluation order | Existing S0/S1/S2/S(-1) strata |

---

## §6 Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| Accumulation regression | High | Ephemeral PU (validated in Track 4A) — attribute propagators don't persist |
| Attribute record merge complexity | Medium | Component-wise merge is independent per facet — each facet uses its existing lattice |
| Stratified quiescence in ephemeral PU | Medium | BSP scheduler already handles S0/S1/S2. The ephemeral PU uses the same scheduler. |
| Implicit arg insertion as propagator | High | This is the most complex elaboration logic. Incremental: start with explicit-only, add implicit handling in Phase 9. |
| Performance from full attribute records vs type-only | Low | Track 4A showed cell ops are 300-1000× cheaper than typing computation. Adding facets adds merge cost but not typing cost. |
| Interaction between ephemeral PU strata and main network strata | Medium | The ephemeral PU completes ALL strata before bridging outputs. Main network sees only final results. |

---

## §7 Phase Dependencies

```
Phase 0a (Fix multi-path component-indexed firing) ← FOUNDATIONAL, blocks everything
  ↓
Phase 0b (Constraint domain lattice DESIGN) ✅ designed, ready to implement
  ↓
Phase 0c (.pnet attribute cache design)
  ↓
Phase 0d (BSP scheduler audit + correction) ← audit Track 4A, correct to BSP default
  ↓
Phase 1 (Attribute Record PU) ← depends on 0a (correct K-indexed) + 0d (BSP)
  ↓
Phase 2 (Constraint creation S0) ←─── Phase 1 + 0b (domain lattice)
  ↓
Phase 3 (Trait resolution S1) ←─── Phase 2 (constraints exist to resolve)
  |
  ├→ Phase 4 (Multiplicity S0/S2) ←─── Phase 1 (independent of constraints)
  |
  ├→ Phase 5 (Structural unification S0) ←─── Phase 1 (independent)
  |
  └→ Phase 7 (Warnings S2) ←─── Phase 2+3 (constraints + resolution feed warnings)

Phase 6 (Meta bridging via output channels) ←─── Phase 3
  ↓
Phase 8 (ATMS) ←─── Phase 2+3 (constraints + resolution under assumptions)
  ↓
Phase 9 (Retire imperative fallback) ←─── ALL above (2-8)
  ↓
Phase 10 (Zonk retirement) ←─── Phase 9
  ↓
Phase 11 (Scaffolding retirement) ←─── Phase 9
  ↓
Phase T + 12 (Tests + PIR) ←─── ALL
```

**Critical path**: 0a → 0d → 1 → 2 → 3 → 6 → 9 (retire imperative)
**Parallel**: Phases 4, 5, 7 independent after Phase 1. Phase 8 (ATMS) after Phase 3. Phase 0b (✅) + 0c parallel with 0a.
**Design phases**: 0b ✅ designed, 0c needs design. 0a + 0d are implementation phases.

### §7a Phase 9 Acceptance Gate

Phase 9 (retire imperative fallback) is the track's climax. It is NOT complete until ALL of the following are satisfied:

1. **On-network success rate = 100%**: `on-network-success-count` = total, `on-network-fallback-count` = 0 across the full test suite. No expression kind falls back to imperative `infer/check`.
2. **Zero fallback invocations**: the `infer-on-network/err` fallback path (calling imperative `infer/err`) is NEVER taken. This is verified by counter + logging.
3. **Dead code confirmation**: `infer`, `check`, `resolve-trait-constraints!`, `checkQ`, and `freeze` have NO call sites in the production path. Grep confirms. They may remain as test utilities or be removed entirely.
4. **Full test suite GREEN**: all ~7300 tests pass with the imperative path removed (not just bypassed — removed from `process-command`).
5. **Level 3 acceptance file**: the Track 4B acceptance `.prologos` file runs via `process-file` with zero errors. Exercises all 5 attribute domains across diverse expression kinds.
6. **A/B benchmark**: `bench-ab.rkt --runs 15` shows no statistically significant regression vs pre-Track-4B baseline (Mann-Whitney U, p > 0.05).
7. **Unhandled expression audit**: `unhandled-expr-counts` is empty — every expression kind in the SRE attribute domain is handled by a propagator, no kind falls through to "unhandled."

### §7b Phase 3 Acceptance: 17 Known-Failing Test Files

Triage (2026-04-06) of 17 test files (59 failing tests) revealed a **uniform root cause**: the imperative trait resolution pipeline fires before type meta-variables are solved. The resolver sees `(Eq _)` instead of `(Eq Nat)`, or the dict-meta `?metaNNNN` is never filled.

This is exactly the S0→S1 ordering that Phase 3 implements: type inference (S0) quiesces → type args are ground → trait resolution (S1) fires on concrete types.

**Category A — Unsolved dict-meta (10 files, 30 tests)**: Dict-meta for trait methods never solved → function never reduces → `?metaNNNN` in output.

| File | Failing/Total |
|------|--------------|
| test-bare-methods.rkt | 7/12 |
| test-bundles.rkt | 4/17 |
| test-collection-fns-01.rkt | 1/14 |
| test-eq-let-surface-01.rkt | 3/13 |
| test-hasmethod-01.rkt | 2/10 |
| test-method-resolution.rkt | 5/23 |
| test-generic-ops-01-02.rkt | 1/5 |
| test-generic-ops-02-02.rkt | 2/10 |
| test-prelude-system-01.rkt | 4/15 |
| test-reducible-02.rkt | 1/14 |

**Category B — No-instance for unsolved type `_` (4 files, 23 tests)**: Trait resolution fires but sees `_` (unsolved meta) instead of concrete type.

| File | Failing/Total |
|------|--------------|
| test-constraint-inference.rkt | 2/11 |
| test-eq-ord-extended-02.rkt | 10/12 |
| test-kind-inference-where.rkt | 5/15 |
| test-hkt-errors.rkt | 6/9 |

**Category C — Compound causes (3 files, 6 tests)**: Primarily trait resolution timing + secondary symptoms.

| File | Failing/Total | Notes |
|------|--------------|-------|
| test-trait-resolution.rkt | 3/22 | `boolrec` arity (dict-meta not auto-inserted) + unsolved meta |
| test-where-parsing.rkt | 2/16 | WS parse diagnostics + `no instance for (Eq _)` |
| test-punify-integration.rkt | 1/24 | Contradiction detection — may resolve with full attribute eval |

**Acceptance criterion**: Phase 3 is not complete until ALL 59 failing tests across these 17 files pass. Any that don't pass after Phase 3 indicate a secondary bug to be fixed in Phase 3 scope (not deferred).

---

## §8 NTT Model

```
-- Elaboration as attribute evaluation on the propagator network.
-- The attribute grammar IS the specification. The propagator network IS the evaluator.
-- The constraint domain IS a Heyting algebra on candidate sets.
-- All evaluation uses BSP scheduler (CALM-invariant enforcement).

-- ================================================================
-- The Attribute Record: one per AST node position
-- ================================================================
cell attribute-map
  :carrier (HasheqOf Position (HasheqOf Facet Value))
  :merge   component-wise per position, per facet:
    :type        type-lattice-merge          ;; Track 2H quantale
    :context     context-cell-merge          ;; Track 4A Phase 1c
    :usage       usage-vector-join           ;; pointwise mult-add
    :constraints constraint-domain-merge     ;; §11: set intersection (Heyting)
    :warnings    set-union                   ;; monotone accumulation
  :bot     empty map (all positions, all facets at ⊥)
  :top     any type facet = type-top (contradiction)
  :index   K-indexed by (position . facet) — multi-path component firing (Phase 0a)

-- ================================================================
-- S0 Monotone Propagators (type, context, constraints, usage)
-- ================================================================

-- Typing attribute propagator
propagator type-attribute
  :reads   attribute-map @ [(sub-expr-pos . :type), ...]
  :writes  attribute-map @ [(this-pos . :type)]
  :fire    SRE attribute domain lookup → compute type from sub-types
  :stratum S0

-- Context extension propagator (scope tensor)
propagator context-attribute
  :reads   attribute-map @ [(parent-ctx-pos . :context), (domain-pos . :type)]
  :writes  attribute-map @ [(child-ctx-pos . :context)]
  :fire    context-extend-value(parent-ctx, domain-expr, mult)
  :stratum S0

-- Bidirectional application propagator
propagator app-attribute
  :reads   attribute-map @ [(func-pos . :type)]
  :writes  attribute-map @ [(arg-pos . :type),     -- DOWNWARD: domain constraint
                            (this-pos . :type)]    -- UPWARD: subst(0, arg, cod)
  :fire    if func-type is Pi(m, dom, cod):
             that-write(arg-pos, :type, dom)        -- merge IS unification
             that-write(this-pos, :type, subst(0, arg-expr, cod))
  :stratum S0

-- Constraint domain creation propagator
propagator constraint-creation
  :reads   attribute-map @ [(func-pos . :type)]
  :writes  attribute-map @ [(this-pos . :constraints)]
  :fire    read registered trait-constraint-info for this app
           build constraint-domain from impl registry candidates
           that-write(this-pos, :constraints, domain)
  :stratum S0

-- Type → constraint domain narrowing bridge
propagator type-narrows-constraints
  :reads   attribute-map @ [(type-arg-pos . :type)]
  :writes  attribute-map @ [(constraint-pos . :constraints)]
  :fire    when type-arg gains concrete value:
             candidates-for-type = lookup-impls(trait, type-val)
             narrowed = constraint-domain-merge(current, candidates-for-type)
             that-write(constraint-pos, :constraints, narrowed)
  :stratum S0 (monotone: domains only narrow)

-- Usage tracking propagator
propagator usage-tracking
  :reads   attribute-map @ [(sub-expr-pos . :usage), ..., (func-pos . :type)]
  :writes  attribute-map @ [(this-pos . :usage)]
  :fire    compose: add-usage(func.usage, scale-usage(m, arg.usage))
  :stratum S0

-- ================================================================
-- S1 Readiness Propagators (trait resolution, constraint retry)
-- ================================================================

-- Trait resolution propagator (fires when constraint domain narrows to singleton)
propagator trait-resolution
  :reads   attribute-map @ [(constraint-pos . :constraints)]
  :writes  attribute-map @ [(dict-meta-pos . :type)]   -- resolved dict expression
  :fire    when constraint-domain is singleton {candidate}:
             dict-expr = build-dict(candidate)
             that-write(dict-meta-pos, :type, dict-expr)
  :stratum S1 (readiness: fires only when domain reaches singleton)

-- Constraint retry propagator (structural unification)
propagator constraint-retry
  :reads   attribute-map @ [(lhs-pos . :type), (rhs-pos . :type)]
  :writes  attribute-map @ [(lhs-pos . :type), (rhs-pos . :type)]
  :fire    when both types are now ground:
             merged = type-lattice-merge(lhs-type, rhs-type)
             that-write both positions with merged
  :stratum S1 (readiness: fires when dependency metas solved)

-- ================================================================
-- S2 Commitment Propagators (defaulting, validation, collection)
-- ================================================================

-- Meta default propagator (fan-in threshold)
propagator meta-default
  :reads   internal-readiness-cell (bitmask of solved metas)
  :writes  attribute-map @ [(unsolved-meta-pos . :type), ...]
  :fire    when S0+S1 quiesce:
             for each unsolved meta:
               that-write(meta-pos, :type, default-value)   -- lzero, mw, sess-end
  :stratum S2

-- Usage validation propagator
propagator usage-validation
  :reads   attribute-map @ [(all-positions . :usage), (root . :context)]
  :writes  attribute-map @ [(all-positions . :warnings)]
  :fire    for each binding position:
             if not compatible(declared-mult, actual-usage):
               that-write(pos, :warnings, {multiplicity-violation(...)})
  :stratum S2

-- Warning collection propagator
propagator warning-collection
  :reads   attribute-map @ [(all-positions . :warnings)]
  :writes  output-warning-cell (on containing network)
  :fire    union all position warnings → write to output channel
  :stratum S2

-- ================================================================
-- S(-1) ATMS Retraction
-- ================================================================

assumption union-branch
  :api     atms-assume / atms-retract (pure functional, PM Track 8 B1)
  :creates worldview where one union component holds
  :per-branch attribute records diverge under assumption
  :contradiction retracts branch via net-retract-assumption
  :commit  surviving branch promotes via net-commit-assumption
  :stratum S(-1)

-- ================================================================
-- Output Channels: PU → Containing Network (Galois Connection)
-- ================================================================

bridge output-channels
  :trigger internal-readiness threshold (all strata quiesced)
  :stratum S2 (after all internal computation complete)
  :channels
    root-type-cell        ← that-read(root-pos, :type) → write to containing network
    meta-solution-cells   ← for each meta with non-⊥ type: solve-meta! on main network
    constraint-cells      ← resolved constraint domain values
    mult-validation-cell  ← pass/fail for multiplicity checks
    warning-cell          ← accumulated warning set
  :galois
    α: attribute-map → (root-type × meta-solutions × constraint-resolutions × warnings)
    γ: outputs → attribute-map (injection)
    adjunction: α(map) ⊑ outputs ⟺ map ⊑ γ(outputs)
```

### NTT Correspondence Table

| NTT Construct | Racket Implementation | File |
|---------------|----------------------|------|
| `attribute-map` cell | Extended from Track 4A type-map to 5-facet hasheq | typing-propagators.rkt |
| `type-attribute` propagator | Existing typing propagators + SRE domain | typing-propagators.rkt |
| `context-attribute` propagator | Existing context-extension propagators | typing-propagators.rkt |
| `app-attribute` propagator | Existing bidirectional app propagator | typing-propagators.rkt |
| `constraint-creation` propagator | NEW: reads trait-constraint-info, builds domain | typing-propagators.rkt |
| `type-narrows-constraints` bridge | NEW: P1 pattern from constraint-propagators.rkt | constraint-propagators.rkt |
| `usage-tracking` propagator | NEW: from qtt.rkt inferQ rules as propagators | typing-propagators.rkt |
| `trait-resolution` propagator (S1) | Existing resolve-trait-constraint-pure as fire-fn | resolution.rkt |
| `constraint-retry` propagator (S1) | Existing retry-unify-constraint-pure as fire-fn | resolution.rkt |
| `meta-default` propagator (S2) | Existing meta-readiness fan-in (Track 4A Phase 4b-i) | typing-propagators.rkt |
| `usage-validation` propagator (S2) | NEW: from qtt.rkt check-all-usages as propagator | typing-propagators.rkt |
| `warning-collection` propagator (S2) | NEW: accumulating set cell | typing-propagators.rkt |
| `union-branch` assumption | Existing ATMS from PM Track 8 B1 | elab-speculation-bridge.rkt |
| `output-channels` bridge | NEW: threshold → external cell writes | typing-propagators.rkt |
| BSP scheduler | Existing propagator.rkt run-to-quiescence-bsp | propagator.rkt |
| Constraint domain lattice | NEW: §11 design, replaces Phase 6 flat lattice | typing-propagators.rkt |

---

## §9 Global Attribute Store with Structural Sharing

### §9.1 The Insight

Most attribute records share common structure. Every `int+` has `{type: Int→Int→Int, constraints: ∅, usage: zero, warnings: ∅}`. Every type constructor has `{type: Type(0), constraints: ∅, usage: zero, warnings: ∅}`. The constraint, usage, and warning facets are `∅/zero/∅` for ~90% of global names.

With CHAMP-backed records, the shared facets are POINTER-EQUAL. A global attribute store with structural sharing means:
- Prelude loading caches ~500 names with their full attribute records
- Each module export has a precomputed attribute record
- Per-use records start as references to the global record
- Uses that add constraints (generic dispatch) are CHAMP path-copies: shared root, new constraint facet only
- Memory: O(shared) for common facets, O(delta) for per-use variation

### §9.2 Record Structure

Attribute records are CHAMP-like persistent maps with facet keys:

```
Global record (e.g., int+):
  { :signature  (Pi mw Int (Pi mw Int Int))
    :constraints ∅                              ← shared singleton
    :usage      zero                            ← shared singleton
    :warnings   ∅ }                             ← shared singleton

Per-use record (e.g., int+ used as (int+ x 3)):
  same as global — no per-use delta, pointer-equal

Generic record (e.g., +):
  { :signature  (Pi mw A (Pi mw A A))
    :constraints {(Add A)}                      ← trait constraint
    :usage      zero
    :warnings   ∅ }

Per-use generic (e.g., (+ 3 4) where A=Int):
  { :signature  (Pi mw Int (Pi mw Int Int))     ← resolved from generic
    :constraints {(Add Int) → resolved}         ← CHAMP path-copy: new constraint facet
    :usage      zero                            ← shared with global
    :warnings   ∅ }                             ← shared with global
```

### §9.3 Signature Patterns

Most attribute records fall into a small number of SIGNATURE PATTERNS:

| Pattern | Type Shape | Count | Examples |
|---------|-----------|-------|---------|
| Binary same-type | `A → A → A` | ~50 | int-add, rat-mul, p8-add, generic-add |
| Binary comparison | `A → A → Bool` | ~30 | int-lt, rat-eq, p8-le, generic-gt |
| Unary same-type | `A → A` | ~15 | int-neg, rat-abs, p8-sqrt, generic-negate |
| Conversion | `A → B` | ~20 | from-nat, p8-to-rat, from-int |
| Type constructor | `Type(0)` | ~20 | Int, Nat, Bool, String, Posit8, ... |
| Literal | `T` (constant) | ~15 | 42:Int, true:Bool, "hi":String |
| Zero-arity | `T` (nullary) | ~10 | zero:Nat, unit:Unit, nil:Nil |

The signature pattern IS the structural sharing key: all binary-same-type ops share the `A → A → A` template, differing only in the concrete type `A`.

### §9.4 The `that` Operation (Design Thinking)

A `that` operation on variables provides first-class access to the attribute record:

- **Read**: `(that x :type)` → reads the type facet of x's attribute record
- **Write**: `(that x :constraints (Add Int))` → adds a constraint claim to x's record
- **Full record**: `(that x)` → the complete attribute record for x

This grounds WHERE clauses in the attribute grammar:
```
spec sort {A} (that A :constraints (Ord A)) [List A] -> [List A]
```

In the propagator model, `that` IS a cell read/write on the attribute PU. The merge handles accumulation: multiple `that` writes to the same facet join via the facet's lattice.

This is design-thinking — `that` may or may not become user-facing syntax. But it captures the CONCEPT: variables accumulate evidence (attributes) through elaboration, and `that` is the operation to access/extend that evidence.

### §9.5 Integration with SRE Typing Domain

The SRE typing domain (Track 4A §16) extends to a FULL ATTRIBUTE DOMAIN:

```
(register-attribute-rule! 'expr-int-add
  #:arity 2
  #:children (list expr-int-add-a expr-int-add-b)
  #:signature (expr-Int)                         ;; type facet
  #:constraints '()                              ;; constraint facet
  #:usage-pattern 'binary-compose)               ;; usage: add-usage(a, b)
```

The domain entry IS the cached global attribute record template. For literals and type constructors, the template is COMPLETE. For structural nodes, the template has HOLES filled by propagators.

### §9.6 .pnet Cache Integration

The `.pnet` cache (used for module compilation artifacts) can cache ATTRIBUTE RECORDS alongside compiled code. When loading a module:
1. Read `.pnet` → get pre-compiled propagator network snapshot
2. Read attribute records → get precomputed global attribute records
3. Populate the global attribute store with these records
4. Per-command attribute evaluation starts from cached records — only per-use delta needs computation

This makes prelude loading nearly free for attribute evaluation: ~500 names × cached attribute records = zero propagator firings for global names.

---

## §10 Phase 0a Design: Multi-Path Component-Indexed Firing

### The Bug

Track 4A Phase 1a introduced component-indexed firing: propagators declare which PU component paths they watch. Only propagators whose watched paths intersect the changed components are scheduled.

The bug: `net-add-propagator` uses `(assoc cid component-paths equal?)` to find the path for a cell-id. When a propagator has MULTIPLE paths on the SAME cell-id (e.g., app propagator watches both `func-pos` and `arg-pos` on the same type-map cell), `assoc` finds only the FIRST path. The second path is lost.

### The Impact

When position `arg-pos` changes, the app propagator (which registered only `func-pos` as its path) is NOT scheduled. This caused:
- Incorrect behavior: propagators miss updates they should see
- Workaround: multi-position propagators omit component-paths (watch entire cell → fire on ANY change)
- Thrashing: propagators watching entire cell fire unnecessarily, causing cascading re-firings

The Pattern 2 timeout regression was likely caused by this: bidirectional app writes trigger ALL propagators (because component-paths was omitted), each of which writes to other positions, triggering more firings.

### The Fix

Change `prop-cell.dependents` from `(champ prop-id → path-or-#f)` to `(champ prop-id → (listof path) | #f)`. A propagator can watch MULTIPLE paths on the same cell.

In `net-add-propagator`: for each input cell, collect ALL matching paths from component-paths (not just the first). Store as a list.

In `net-cell-write`'s `filter-dependents-by-paths`: check if ANY of the propagator's watched paths intersect the changed set. Fire if any match.

### NTT Specification

```
propagator app-typing
  :reads   attribute-map @ [func-pos, arg-pos]   ;; K-indexed multi-path reads
  :writes  attribute-map @ [result-pos, arg-pos]  ;; K-indexed writes (bidirectional)
  :fire    ...
```

The `:reads` and `:writes` declarations specify WHICH positions the propagator accesses. The scheduler uses these for:
- **Selective scheduling**: only fire when a read-position changes
- **Cycle detection**: if a propagator writes to its own read-position, flag for review (potential loop)
- **Audit**: NTT declarations can be validated against actual fire-fn behavior

### Audit of Track 4A for Thrashing

With the fix in place, audit ALL propagators in `install-typing-network`:
- Each propagator should declare its EXACT read/write positions
- No propagator should watch the entire cell (path=#f) unless it genuinely reads ALL positions
- The bidirectional app propagator's read={func-pos} and write={arg-pos, result-pos} should NOT cause self-triggering

---

## §11 Phase 0b Design: Constraint Domain Lattice

### §11.1 The Problem

Track 4A Phase 6 built a flat constraint lattice: `pending → resolved(instance) → contradicted`. This is too simple. It has no notion of PROGRESSIVE NARROWING — a constraint jumps from "pending" to "resolved" in one step.

CLP solvers work differently: a variable has a DOMAIN (set of possible values), and constraints NARROW the domain monotonically. `X ∈ {0..9}, X > 5 → X ∈ {6..9}`. The narrowing IS the computation.

### §11.2 The Constraint Domain Lattice

The constraint domain is NOT a separate lattice — it's an ADDITIONAL RELATION on the type carrier, following the SRE Track 2H pattern (equality and subtype are different relations on the same carrier).

| Relation | Carrier | Ordering | Merge | Properties |
|----------|---------|----------|-------|------------|
| Equality | Type expressions | Flat (equal or ⊤) | `type-lattice-merge` | Comm, Assoc, Idemp |
| Subtype | Type expressions | Partial order (Nat ≤ Int) | `subtype-lattice-merge` | Comm, Assoc, Idemp, Distributive, Heyting (ground) |
| **Constraint domain** | **(Setof impl-candidate)** | **⊇ (superset = less info)** | **Set intersection** | **Comm, Assoc, Idemp, Distributive, Heyting** |

The constraint domain lattice:

```
⊥ (no info) = universe of all types (all candidates possible)
  ↓ (gaining info = narrowing)
{Int, Nat, Rat, String, Posit8, ...} = types with Add instance
  ↓
{Int, Nat} = types with both Add and Ord instances (intersection)
  ↓
{Int} = fully resolved (one candidate)
  ↓
⊤ (contradiction) = ∅ (no type satisfies all constraints)
```

**⚠️ DUAL ORDERING WARNING**: This lattice uses the OPPOSITE of the standard powerset ordering. In the standard powerset lattice, ⊆ means "less" and bigger sets are "higher." Here, ⊇ means "less information" (more possibilities = less constrained) and SMALLER sets are "higher" (more constrained = more information). This dual arises because we're tracking REMAINING CANDIDATES, not ACCUMULATED EVIDENCE — fewer candidates = more is known. Confusion between the two orderings will invert join/meet and produce unsound narrowing. When in doubt: narrowing (gaining info) = INTERSECTION (removing candidates). Relaxing (losing info) = UNION (adding candidates).

**Join** (⊔ = gaining information): SET INTERSECTION. Adding a constraint removes candidates.
**Meet** (⊓ = relaxing): SET UNION. Removing a constraint adds candidates.
**Bot** (⊥): the universal set (all impl candidates).
**Top** (⊤): the empty set (no candidates — contradiction).

### §11.3 Algebraic Properties

Powerset lattices under intersection are ALWAYS Heyting algebras:

| Property | Status | Proof |
|----------|--------|-------|
| Commutative | ✅ | A ∩ B = B ∩ A |
| Associative | ✅ | (A ∩ B) ∩ C = A ∩ (B ∩ C) |
| Idempotent | ✅ | A ∩ A = A |
| Has-meet | ✅ | A ∪ B (set union) |
| Distributive | ✅ | A ∩ (B ∪ C) = (A ∩ B) ∪ (A ∩ C) |
| Heyting | ✅ | Pseudo-complement: ¬A = complement(A). For error reporting: "types that DON'T satisfy the constraint" |

The pseudo-complement is the key for error reporting: `¬{types with Eq impl}` = `{types WITHOUT Eq impl}`. When a type `Posit8` is found to lack `Eq`, the pseudo-complement produces the error context.

### §11.4 SRE Domain Registration

```
(make-sre-domain
  'constraint-domain
  ;; merge-registry: narrowing relation = set intersection
  (hasheq 'narrowing constraint-domain-merge)
  ;; contradicts?: empty set
  constraint-domain-contradicts?
  ;; bot?: universe
  constraint-domain-bot?
  ;; bot-value
  constraint-domain-universe
  ;; top-value
  constraint-domain-empty
  ;; meta-recognizer / meta-resolver: #f (no metas in domain values)
  #f #f
  ;; dual-pairs: #f
  #f
  ;; property-cell-ids: from property inference
  (hasheq)
  ;; declared-properties (per-relation):
  (hasheq 'narrowing
    (hasheq 'commutative #t
            'associative #t
            'idempotent #t
            'has-meet #t
            'distributive #t
            'heyting #t))
  ;; operations
  (hasheq 'pseudo-complement constraint-domain-complement))
```

### §11.5 Concrete Representation

```racket
;; A constraint domain value: set of impl candidates for a trait
(struct constraint-domain
  (trait-name    ;; symbol: 'Add, 'Eq, 'Ord, etc.
   candidates    ;; (listof impl-candidate) | 'universe
   ;; Each candidate: monomorphic (concrete fqn) or parametric (pattern + where-constraints)
   )
  #:transparent)

;; Bot: all candidates possible (no narrowing yet)
(define (constraint-domain-universe trait-name)
  (constraint-domain trait-name 'universe))

;; Top: no candidates (contradiction)
(define (constraint-domain-empty trait-name)
  (constraint-domain trait-name '()))

;; Merge (join = narrowing = intersection)
(define (constraint-domain-merge a b)
  (cond
    ;; Universe ∩ X = X
    [(eq? (constraint-domain-candidates a) 'universe) b]
    [(eq? (constraint-domain-candidates b) 'universe) a]
    ;; Empty ∩ X = Empty (contradiction absorbs)
    [(null? (constraint-domain-candidates a)) a]
    [(null? (constraint-domain-candidates b)) b]
    ;; Set intersection
    [else
     (define intersected
       (filter (lambda (c) (member c (constraint-domain-candidates b) equal?))
               (constraint-domain-candidates a)))
     (constraint-domain (constraint-domain-trait-name a) intersected)]))

;; Contradicts?: empty candidate set
(define (constraint-domain-contradicts? d)
  (and (constraint-domain? d)
       (not (eq? (constraint-domain-candidates d) 'universe))
       (null? (constraint-domain-candidates d))))

;; Pseudo-complement for error reporting
(define (constraint-domain-complement d all-impls)
  ;; Returns candidates NOT in d — for "available instances" error message
  (if (eq? (constraint-domain-candidates d) 'universe)
      '()  ;; complement of universe is empty
      (filter (lambda (c) (not (member c (constraint-domain-candidates d) equal?)))
              all-impls)))
```

### §11.6 Integration with Type Lattice

When a type-map position narrows (e.g., meta `?A` gains type `Int`), the constraint domain for trait constraints on `?A` narrows correspondingly:

**Bridge propagator (type → constraint domain)**:
```
propagator type-narrows-constraint-domain
  :reads   type-map @ [?A-position] (type facet)
  :writes  attribute-map @ [?A-position] (constraint facet)
  :fire
    type-val = that-read(attribute-map, ?A-position, :type)
    if type-val is concrete (not bot, not meta):
      for each constraint on ?A:
        current-domain = that-read(attribute-map, ?A-position, :constraints)
        candidates-for-type = lookup-impls-for-type(trait-name, type-val)
        narrowed = constraint-domain-merge(current-domain, candidates-for-type)
        that-write(net, attribute-cell, ?A-position, :constraints, narrowed)
  :stratum S0 (monotone: domains only narrow)
```

### §11.7 Parametric Instance Handling

Parametric impls (e.g., `impl Eq (List A) where (Eq A)`) are candidates whose match GENERATES sub-constraints. This is NOT simple set intersection — it's constraint PROPAGATION.

**The merge function handles MONOMORPHIC narrowing only** (pure set filtering by type tag). Parametric narrowing requires pattern matching + sub-constraint generation, which is COMPUTATION that belongs in a PROPAGATOR, not in a merge function.

```racket
(struct parametric-candidate
  (impl-entry      ;; the parametric impl registration
   pattern-vars    ;; type variables in the pattern
   where-clauses)  ;; sub-constraints that must also be satisfied
  #:transparent)
```

**Two-level narrowing**:

1. **Merge level (pure, in constraint-domain-merge)**: filter candidates by type tag. `?A → List ?B` eliminates monomorphic candidates (Eq Int, Eq Nat, etc.) that don't match `List`. Parametric candidates with compatible patterns STAY in the set.

2. **Propagator level (S0, parametric-narrowing propagator)**: watches the constraint domain. When it sees parametric candidates AND the type is sufficiently ground to attempt pattern matching:
   - Match candidate pattern against current type: `List A` matches `List ?B` → binding `A = ?B`
   - Generate sub-constraints: `where (Eq A)` with `A = ?B` → `(Eq ?B)` as a NEW constraint entry
   - Write sub-constraints to the attribute map: `that-write(net, cell, ?B-position, :constraints, (constraint-domain 'Eq ...))`
   - The sub-constraints narrow independently via the same lattice

```
propagator parametric-narrowing
  :reads   attribute-map @ [(constraint-pos . :constraints), (type-arg-pos . :type)]
  :writes  attribute-map @ [(sub-constraint-positions . :constraints)]
  :fire    for each parametric candidate in domain:
             bindings = match-type-pattern(type-val, candidate.pattern)
             if bindings:
               for each where-clause in candidate.where-clauses:
                 sub-constraint = instantiate(where-clause, bindings)
                 that-write(sub-constraint-position, :constraints, sub-constraint-domain)
  :stratum S0 (monotone: sub-constraints are new info, narrowing only)
```

**This IS CLP constraint propagation**: `X ∈ {1..9}, X = Y + Z` generates constraints on Y and Z. In Prologos: `(Eq ?A)` where `?A = List ?B` matches `impl Eq (List A) where (Eq A)`, generating `(Eq ?B)`. The constraint domain lattice handles the domain; the parametric propagator handles the generation. Both are monotone S0 operations.

### §11.8 Generalization: Universal Constraint Domain Solving

The constraint domain lattice generalizes to ANY domain-solving scenario:

| Use Case | Carrier | Domain Values | Narrowing |
|----------|---------|--------------|-----------|
| **Trait resolution** | Type expressions | {types with trait impl} | Type info narrows candidates |
| **CLP(Z) integers** | Integers | {0..9} or arbitrary ranges | Arithmetic constraints narrow ranges |
| **CLP(B) booleans** | {true, false} | Boolean domain | SAT constraints narrow |
| **Relational language** | Ground terms | {terms matching a pattern} | Unification narrows |
| **Type inference** | Type expressions | {types compatible with constraints} | Unification + subtyping narrow |

The lattice structure is IDENTICAL across all cases: (Setof carrier-values) ordered by ⊇, join = intersection, meet = union, Heyting algebra. The ONLY difference is the carrier and the narrowing operations.

By designing the constraint domain lattice NOW with this generalization in mind, we build infrastructure that serves:
1. Track 4B: trait resolution as domain narrowing
2. SRE Track 6: reduction constraints
3. Relational Language: CLP-style domain variables
4. Future: any domain-solving scenario

### §11.9 Replaces Track 4A Phase 6 Constraint Lattice

The flat lattice from Track 4A Phase 6 (`pending → resolved → contradicted`) is RETIRED. The constraint domain lattice subsumes it:

| Old (Phase 6) | New (Domain Lattice) |
|---------------|---------------------|
| `pending` | Universe (all candidates) |
| `resolved(instance)` | Singleton set ({one candidate}) |
| `contradicted` | Empty set (∅) |

The new lattice adds ALL intermediate states between universe and singleton — progressive narrowing that the flat lattice couldn't express.

---

## §12 Phase 0d Design: BSP Scheduler Audit

**Correction (D.2)**: `current-use-bsp-scheduler?` already defaults to `#t` (BSP is the global default). The D.1 claim that it defaults to `#f` was stale. However, ephemeral PU sites used the generic `run-to-quiescence` dispatcher (which inherits the global default) rather than explicit `run-to-quiescence-bsp`. Phase 0d hardens these to explicit BSP calls. For Track 4B:

1. **Audit all `run-to-quiescence` calls in Track 4A code** — `infer-on-network` and any internal uses. Verify they work correctly under BSP.
2. **Set BSP as default for ephemeral PUs** — `(parameterize ([current-use-bsp-scheduler? #t]) ...)` around PU creation and evaluation.
3. **CALM-invariant enforcement** — BSP snapshot isolation guarantees monotone operations are safe to parallelize. Any non-monotone write across BSP rounds is a CALM violation → flag for review.
4. **Stratum ordering via BSP** — S0→S1→S2 within the PU is implemented by the BSP outer/inner loop structure. Value stratum (S0) is the inner BSP loop. Topology/readiness stratum (S1) is the outer loop. Commitment (S2) is after full quiescence.

---

## §13 Output Channel Protocol: PU → Containing Network

### The Mechanism

A propagator INSIDE the ephemeral PU fires into a cell on the CONTAINING network. This IS a Galois connection: the PU's internal lattice (full attribute map) maps to the containing network's lattice (specific output values).

### The Pattern (from prior art)

`make-trait-resolution-bridge-fire-fn` in resolution.rkt IS this pattern: a propagator fires from one context (resolution stratum) into cells on the main elab-network. It syncs state, computes, writes back.

### The Design

The ephemeral PU has a THRESHOLD PROPAGATOR watching an internal "all-done" cell (the meta-readiness fan-in from Track 4A Phase 4b-i, extended to all attribute facets). When all internal strata quiesce (S0+S1+S2 complete), the threshold fires and writes results to external cells:

```
propagator output-bridge
  :reads   internal-readiness-cell (within PU)
  :writes  external cells (on containing network):
    root-type-cell     ← type facet of root position
    meta-solution-cells ← solve-meta! for each resolved meta
    constraint-cells    ← resolved constraint domain values
    warning-cell        ← accumulated warnings
  :fire
    when all-done?(readiness):
      for each output channel:
        read internal value → write to external cell
  :stratum S2 (fires after S0+S1 quiesce within PU)
```

The containing network sees SINGLE WRITES (⊥ → final value) on each output channel cell. These writes trigger downstream propagators on the containing network (e.g., constraint retry, trait resolution at the containing level).

### Galois Connection Formalization

The output bridge IS a Galois connection between the PU lattice (attribute map) and the containing network lattice (individual output cells):

- **α (abstraction)**: PU attribute map → individual output values (projection per output channel)
- **γ (concretization)**: individual output values → attribute map (injection into the full record)
- **Adjunction**: α(attribute-map) ⊑ output-value ⟺ attribute-map ⊑ γ(output-value)

This ensures: the output is CONSISTENT with the PU's internal computation. The containing network's view of the PU is a sound abstraction of the PU's full state.

---

## §14 `that` Internal API Specification

### Concrete Racket API

```racket
;; Read a specific facet of a position's attribute record
(define (that-read attribute-map position facet)
  ;; attribute-map: hasheq position → (hasheq facet → value)
  ;; position: AST node (eq? identity)
  ;; facet: ':type | ':context | ':usage | ':constraints | ':warnings
  ;; Returns: facet value, or facet-specific ⊥ if not present
  (define record (hash-ref attribute-map position (hasheq)))
  (hash-ref record facet (facet-bot facet)))

;; Write a specific facet (cell write, triggers component-indexed firing)
(define (that-write net attribute-cell-id position facet value)
  ;; Writes a SINGLE-FACET update to the attribute map cell
  ;; The merge handles: existing record + new facet value → merged record
  ;; Component-indexed firing: only propagators watching this position+facet fire
  (net-cell-write net attribute-cell-id
    (hasheq position (hasheq facet value))))

;; Facet-specific bot values
(define (facet-bot facet)
  (case facet
    [(:type) type-bot]
    [(:context) context-empty-value]
    [(:usage) '()]                    ;; empty usage vector
    [(:constraints) (constraint-domain-universe #f)]  ;; all candidates
    [(:warnings) '()]))              ;; no warnings
```

### Component-Indexed Firing for Facets

With the Phase 0a multi-path fix, a propagator can watch a SPECIFIC position AND facet:

```racket
;; A typing propagator watches position P's type facet
(net-add-propagator net (list attribute-cell)
  (list attribute-cell)
  typing-fire-fn
  #:component-paths (list (cons attribute-cell (cons position ':type))))

;; A constraint propagator watches position P's type AND constraint facets
(net-add-propagator net (list attribute-cell)
  (list attribute-cell)
  constraint-fire-fn
  #:component-paths (list (cons attribute-cell (cons position ':type))
                          (cons attribute-cell (cons position ':constraints))))
```

The component path is now a COMPOUND KEY: `(cell-id . (position . facet))`. The `pu-value-diff` detects which position+facet combinations changed. Only propagators watching those specific combinations fire.

### Relation to User-Facing `that` (future)

The internal API is designed for future external exposure:
- `(that x :type)` in user code → `(that-read current-attribute-map x ':type)` internally
- `(that x :constraints (Ord A))` → `(that-write net cell x ':constraints (constraint-domain 'Ord ...))`
- The Grammar Form system will compile `that` expressions to these internal operations

---

## §15 Self-Critique Findings (P/R/M Lenses)

### Critical (must address before implementation)

**R1+M1: Facet-aware diffing required.** The `pu-value-diff` currently diffs at the POSITION level (which hasheq keys changed). For the attribute map, a change to `(position-P . :constraints)` registers as "position-P changed" — ALL propagators watching P fire, not just constraint propagators. The Phase 0a multi-path fix allows propagators to declare `(cell . (position . facet))` compound paths, but the DIFF itself must also detect at the (position, facet) granularity. Without this, the attribute PU thrashes like Track 4A did. **Resolution**: Phase 0a scope INCLUDES facet-aware diffing — the diff recurses one level deeper, comparing old/new records per position to identify which facets changed. Compound keys `(position . facet)` in component-paths. Implementation detail, not architectural.

**P1: Parametric instance narrowing is not set intersection.** `impl Eq (List A) where (Eq A)` requires PATTERN MATCHING during narrowing. The merge function handles MONOMORPHIC narrowing only (pure set filtering). A SEPARATE S0 propagator handles parametric narrowing: pattern match → extract bindings → generate sub-constraints → write to attribute map. This is CLP constraint propagation within the domain lattice. **Resolution**: §11.7 updated with two-level narrowing design (merge for monomorphic, propagator for parametric). The merge stays pure; the computation lives in propagators. Principled per propagator-first.

### Medium

**R2**: Constraint domain merge uses linear list scanning. Use sorted/indexed sets for O(N) intersection.

**R4**: BSP topology stratum needs decomp-request infrastructure in ephemeral PU. Verify compatibility.

**P2**: Cross-facet cascade (type → constraint → type) terminates via Heyting finiteness for finite candidate sets. The TYPE lattice interaction should be verified formally or empirically.

### Low (acceptable as-is)

**R3**: Output bridge revised — PREFERRED architecture is scoped propagators on main network (§3.3). Attribute-map cell lives on main network, propagators become inert after quiescence. Results are reactive, visible to downstream propagators. Ephemeral PU is fallback only. Provenance, error-reporting, observability benefit from on-network results.

**R4**: BSP topology stratum needs `decomp-request-cell-id` for structural decomposition requests. If attribute PU uses BSP (per Phase 0d), ensure decomp-request cell is initialized. Track 4A's ephemeral PU creation (`make-prop-network`) does NOT set up decomp-request. **Resolution**: either initialize it in the PU setup, or verify that the attribute propagators don't generate decomp requests (they shouldn't — structural decomposition is Phase 5 scope, not every propagator).

**P3**: Constraint creation reads impl registry at fire time (bridge). SRE domain registration is static. Acceptable.

**M2**: Impl registry read is off-network bridge. Track 7 migrates it.

**M3**: Output bridge is boundary operation. Acceptable for ephemeral PU.

**M4**: S0 is confirmed monotone. Bidirectional app feedback is safe (merge idempotence). ✓

---

## §16 Open Questions Resolved

### Q1: The `that` Operation — User-Facing Syntax

**Decision**: `that` IS user-facing syntax. Design for external considerations; implement now for internal use.

`that` is the first-class mechanism for accessing and extending the attribute grammar at the language level. Users can denote attributes in grammar forms and on variables:
```
;; Set constraint attribute (like CLP(Z)'s `ins`)
spec sort {A} (that A :constraints (Ord A)) [List A] -> [List A]

;; Query attribute record
(that x :type)         ;; → Int
(that x :constraints)  ;; → {(Eq Int)}

;; In grammar forms (future)
grammar my-expr :target :type (that :result :constraints ...)
```

For Track 4B implementation: `that` is the internal API for propagator attribute access — cell read/write on the attribute PU. The user-facing syntax design is deferred to the Grammar Form R&D track, but the MECHANISM is built now.

### Q2: Attribute Record Implementation

**Decision**: Whatever's most efficient. No architectural consequence either way.

Options: CHAMP-backed hasheq with facet keys (most flexible) or struct with optional fields (fastest access). Since the global attribute store uses CHAMP for structural sharing (§9), the hasheq approach is consistent.

The shared singletons (`∅` for constraints, `zero` for usage, `∅` for warnings) are global constants. ~90% of records share these facets pointer-equally.

### Q3: Encapsulated PU Shells with Own Stratification

**Decision**: Each PU has its own stratified evaluation. Contained monotonic computational shells.

The "network soup" problem (Track 4A's accumulation timeout) validates this. Each PU is:
- **Isolated**: no cross-contamination with other PUs or the main network
- **Self-stratified**: S0→S1→S2 evaluated WITHIN the PU
- **Composable**: the PU IS a cell value on the parent network
- **GC-friendly**: internal state disappears on discard

The parent network sees the PU as a single cell transitioning from ⊥ to a complete attribute record. The PU's internal stratification is invisible to the parent.

This IS the Pocket Universe model: a self-contained lattice computation with its own monotone shells. The S0 shell computes types + contexts + constraints. The S1 shell resolves traits + retries constraints. The S2 shell defaults metas + validates multiplicities.

### Q4: Auditing Imperative Ordering — Essential vs Incidental

**Decision**: Audit closely using AG dependency analysis.

From the AG research: the evaluation order is determined by the ATTRIBUTE DEPENDENCY GRAPH. Essential ordering = attribute dependency. Incidental ordering = sequential implementation artifact.

**Essential ordering identified**:
- Can't resolve trait constraint until argument type is ground → S0 (types) before S1 (trait resolution)
- Can't validate multiplicity until all usages are computed → S0 (usage tracking) before S2 (validation)
- Can't default unsolved metas until monotone fixpoint is reached → S0+S1 before S2 (defaulting)
- Can't check if meta is solved until it has a value → monotone lattice progression (⊥ → value)

**Incidental ordering in the imperative path**:
- "Elaborate first, then type-check" → in AG, these are attribute evaluations at different levels of the same grammar (higher-order attributes, §4 of AG research)
- "Create meta, then solve it" → in AG, the meta IS a position that starts at ⊥ and gains a value through attribute propagation
- "Register trait constraint, then resolve it" → in AG, constraint creation is S0 (monotone), resolution is S1 (readiness)
- "Walk left-to-right through arguments" → in AG, argument order is irrelevant (all positions evaluate independently to fixpoint)

**The stratification that emerges**:
- **S0**: ALL monotone attribute computation (types, contexts, constraints, usage) — this is the main fixpoint where most work happens
- **S1**: Readiness-dependent resolution (trait resolution, constraint retry) — fires ONLY when S0 produces ground values that enable resolution
- **S2**: Non-monotone commitment (meta defaults, multiplicity validation, warning collection) — fires ONLY after S0+S1 quiesce
- **S(-1)**: ATMS retraction (union type contradiction) — fires on contradiction

This matches the BSP scheduler's existing strata exactly.

---

## §11 Research Integration

See [Attribute Grammar Research](../research/2026-04-05_ATTRIBUTE_GRAMMARS_RESEARCH.md) for the full theoretical grounding.

Key findings integrated into this design:

1. **AG = catamorphisms** (§1 of research): The imperative `infer` IS a hand-written catamorphism. Track 4B replaces it with the declarative attribute grammar specification evaluated by propagators.

2. **Aspects = domain facets** (§2): Each attribute domain IS an aspect in the Silver/JastAdd sense. The SRE attribute domain IS aspect weaving.

3. **CRAGs = propagator fixpoint** (§3): Circular attribute dependencies ARE propagator quiescence. BSP stratification adds ordered evaluation beyond standard CRAGs.

4. **Higher-order attributes = elaboration** (§4): Surface→core IS a higher-order attribute. Elaboration and typing are NOT separate phases.

5. **CLP = attribute constraints** (§8): Trait constraints ARE CLP-style domain constraints on type variables. The propagator network IS the general constraint propagation engine.

6. **Semantically enriched CFGs** (§8.4): The parse tree gains attributes through evaluation. The attributes are the full record (type + context + constraint + multiplicity + warning). The enrichment IS elaboration.

---

## §17 External Critique Integration (D.2)

External architectural critique received 2026-04-06. Ten recommendations across six categories. Dispositions:

| ID | Finding | Severity | Disposition | D.2 Action |
|----|---------|----------|-------------|------------|
| A1 | Elaboration-to-attribute handoff protocol unspecified | Medium | Partially Accept | Added §4.1a Handoff Protocol |
| L1 | Dual ordering convention needs explicit warning | Low | Accept | Added ⚠️ callout in §11.2 |
| L2 | Unification must be explicitly stated as merge | High | Accept | Added §3.5 Unification = Merge |
| I1 | Impl registry is off-network oracle | Medium | Accept observation, reject severity | Strengthened §4.4 with boundary analysis |
| I2 | Trait resolution reads registry at fire time | Medium | Same as I1 | Same as I1 |
| C1 | Cross-command PU composition unaddressed | Medium | Reject (already handled) | Added clarifying paragraph in §3.2 |
| G3 | Meta-variable lifecycle is largest gap | High | Partially Accept | Added §3.6 Meta-Variable Lifecycle |
| G4 | Missing AST-node position identity protocol | Medium | Partially Accept | Added §3.1a Position Identity Protocol |
| G5 | No Phase 9 acceptance criteria | High | Accept | Added §7a Phase 9 Acceptance Gate |
| R1 | §3.1 vs §3.3 present contradictory architectures | High | Accept | Rewrote §3.3 as Network Hosting Decision |

**No architectural changes resulted from the critique.** All accepted findings were EXPOSITION gaps — the design decisions were sound but not clearly documented. The strongest finding (L2: unification = merge) addressed a conceptual foundation that the document assumed implicitly from Track 2H context. Making it explicit in §3.5 strengthens the document for readers who come from an imperative type-checking background.

**Rejected with rationale:**
- **C1** (cross-command composition): already handled by environment threading + global attribute store (§9). The standard compilation model — not a gap.
- **I1/I2 severity**: the impl registry IS off-network, but it's STATIC during attribute evaluation. Track 7 migrates it. Named as known boundary, not blocked.

---

## §12 Cross-References

- [Prologos Attribute Grammar](../research/2026-04-05_PROLOGOS_ATTRIBUTE_GRAMMAR.md) — Stage 1 foundation: 5 domains, 12 node kinds, stratification
- [PPN Track 4A D.4](2026-04-04_PPN_TRACK4_DESIGN.md) — §15 Typing PU, §16 SRE Domain, §17 Three Frontiers
- [PPN Track 4A PIR](2026-04-04_PPN_TRACK4_PIR.md) — side-effect boundary finding, longitudinal survey
- [SRE Track 2H](2026-04-02_SRE_TRACK2H_DESIGN.md) — type-lattice quantale (merge = unification)
- [SRE Track 2D](2026-04-03_SRE_TRACK2D_DESIGN.md) — DPO rewrite rules
- [PPN Track 3](2026-04-01_PPN_TRACK3_DESIGN.md) — form cells, pipeline PU pattern
- [PM Track 8](2026-03-22_TRACK8_PIR.md) — elaboration network, ATMS, TMS worldview
- [Hypergraph Rewriting](../research/2026-03-24_HYPERGRAPH_REWRITING_PROPAGATOR_PARSING.md) — Engelfriet-Heyker
- [Grammar Form Design Thinking](2026-04-03_GRAMMAR_FORM_DESIGN_THINKING.md) — attribute grammar thread
