# PPN Track 4B: Elaboration as Attribute Evaluation — Stage 3 Design (D.1)

**Date**: 2026-04-05
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
| 0a | Fix multi-path component-indexed firing (foundational) | ⬜ | Fix `assoc` first-match bug in propagator.rkt. Multi-map for paths per cell-id. NTT K-indexed read/write specification. Audit Track 4A for thrashing from incorrect firing. |
| 0b | Constraint domain lattice design (explicit design phase) | ⬜ | CLP-inspired domain narrowing, not flat pending→resolved→contradicted. SRE algebraic structure. Design BEFORE implementation. |
| 0c | .pnet attribute cache design | ⬜ | What's cached, invalidation strategy, structural sharing format, warm-start preloading. |
| 0 | Stage 2 audit + attribute grammar specification | ✅ | [Attribute Grammar](../research/2026-04-05_PROLOGOS_ATTRIBUTE_GRAMMAR.md): 5 domains, 12 node kinds, stratification. [AG Research](../research/2026-04-05_ATTRIBUTE_GRAMMARS_RESEARCH.md): catamorphisms, CLP, aspects. |
| 1 | Attribute Record PU: extend type-map to full attribute record | ⬜ | Type + Context + Constraint + Multiplicity + Warning facets. CHAMP-backed with shared singletons. Proper K-indexed component firing. |
| 2 | Constraint attribute propagators (S0: creation during typing) | ⬜ | Uses the new domain lattice from Phase 0b. Trait constraints, unification constraints, capability constraints as domain-narrowing cells. |
| 3 | Trait resolution propagators (S1: readiness-triggered) | ⬜ | P1 pattern: type→constraint narrowing. Monomorphic + parametric. Fires when arg types reach ground in the domain lattice. |
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

### §3.3 Why Attribute Records, Not Separate Maps

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

---

## §4 Elaboration Boundary and Scope

### §4.1 What Track 4B Receives (from imperative elaborator)

Track 4B receives the CORE EXPR from `elaborate-top-level`. By the time the attribute PU sees the expression:
- Surface syntax has been transformed to core AST (expr-* structs)
- Implicit arguments have been inserted as `expr-meta` nodes
- Names have been resolved to qualified `expr-fvar` / de Bruijn `expr-bvar`
- Trait constraints have been registered via `register-trait-constraint!`
- HasMethod constraints have been registered via `register-hasmethod-constraint!`

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
Phase 0b (Constraint domain lattice DESIGN) ← design phase, before implementation
  ↓
Phase 0c (.pnet attribute cache design) ← design phase
  ↓
Phase 1 (Attribute Record PU) ← depends on 0a (correct K-indexed firing)
  ↓
Phase 2 (Constraint creation S0) ←─── Phase 1 + 0b (domain lattice designed)
  ↓
Phase 3 (Trait resolution S1) ←─── Phase 2 (constraints exist to resolve)
  |
  ├→ Phase 4 (Multiplicity S0/S2) ←─── Phase 1 (independent of constraints)
  |
  ├→ Phase 5 (Structural unification S0) ←─── Phase 1 (independent)
  |
  └→ Phase 7 (Warnings S2) ←─── Phase 2+3 (constraints + resolution feed warnings)

Phase 6 (Meta bridging) ←─── Phase 3 (resolved traits produce meta solutions)
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

**Critical path**: 0a → 0b → 1 → 2 → 3 → 6 → 9 (retire imperative)
**Parallel**: Phases 4, 5, 7 independent after Phase 1. Phase 8 (ATMS) after Phase 3.
**Design phases**: 0a, 0b, 0c are design+implementation before main attribute work.

---

## §8 NTT Model

```
-- Elaboration as attribute evaluation on the propagator network.
-- The attribute grammar IS the specification. The propagator network IS the evaluator.

-- The Attribute Record: one per AST node position
cell attribute-map
  :carrier (HasheqOf Position AttributeRecord)
  :merge   component-wise:
    type:        type-lattice-merge
    context:     context-cell-merge
    usage:       usage-vector-join
    constraints: set-union
    warnings:    set-union
  :bot     empty map (all positions ⊥ in all facets)
  :top     any type facet = type-top (contradiction)

-- Typing attribute propagator (S0) — from Track 4A, now one facet
propagator type-attribute
  :reads   sub-expression type facets
  :writes  parent expression type facet
  :fire    SRE typing domain lookup → compute type from sub-types
  :stratum S0

-- Context attribute propagator (S0) — from Track 4A Pattern 5
propagator context-attribute
  :reads   parent context facet + binder domain
  :writes  child scope context facet
  :fire    context-extend-value (tensor on context lattice)
  :stratum S0

-- Constraint creation propagator (S0) — NEW
propagator constraint-creation
  :reads   function type facet (to detect trait domain)
  :writes  constraint facet of the app node
  :fire    if domain is trait type: add (trait-name, type-arg-positions) to constraints
  :stratum S0

-- Trait resolution propagator (S1) — NEW
propagator trait-resolution
  :reads   constraint facet + type-arg type facets
  :writes  dict-meta type facet (resolved type)
  :fire    when all type-args are ground:
           resolve-trait-constraint-pure → dict expression
           write dict type to dict-meta position
  :stratum S1

-- Usage tracking propagator (S0) — NEW
propagator usage-tracking
  :reads   sub-expression usage facets + Pi multiplicity
  :writes  parent expression usage facet
  :fire    compose usages: add-usage, scale-usage per AG §4 rules
  :stratum S0

-- Usage validation propagator (S2) — NEW
propagator usage-validation
  :reads   all usage facets + context (declared multiplicities)
  :writes  warning facet (if incompatible)
  :fire    for each binding: compatible(declared-mult, actual-usage)?
           if not: add multiplicity-violation warning
  :stratum S2

-- Warning collection propagator (S2) — NEW
propagator warning-collection
  :reads   all warning facets across all positions
  :writes  aggregated warning list (output channel)
  :fire    union all position warnings into report
  :stratum S2

-- ATMS branching for union types (S(-1))
assumption union-branch
  :creates worldview where one union component holds
  :contradiction retracts branch + dependent attributes
  :mechanism existing ATMS from PM Track 8 B1
  :stratum S(-1)

-- Output channels (ephemeral PU → main elab-network)
bridge attribute-output
  :root-type    read type facet at root position → return value
  :meta-solves  for each meta position with non-⊥ type: solve-meta! on main network
  :trait-solves for each resolved constraint: update main network constraint cells
  :warnings     report collected warnings
```

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

## §11 Phase 0b Design: Constraint Domain Lattice (NEEDS DESIGN)

### The Problem

Track 4A Phase 6 built a flat constraint lattice: `pending → resolved(instance) → contradicted`. This is too simple for CLP-inspired domain narrowing.

### The Vision (from CLP(Z) analogy)

A type variable `?A` with constraint `(Add ?A)` should have a DOMAIN: the set of types that implement `Add`. As type information refines, the domain narrows:

```
(Add ?A)  where ?A : Type
  domain = {Int, Nat, Rat, String, Posit8, Posit16, Posit32, Posit64}  ;; all Add impls

?A gains info: ?A appears in (int+ ?A 3)  →  ?A narrows toward Int
  domain = {Int}  ;; only Int compatible

Resolve: impl Add Int → dict = Int--Add--dict
```

### What Needs Designing (explicit design phase)

1. **The domain lattice structure**: `(Setof Candidate)` ordered by subset (⊇ = more info). The bot is the full candidate set. The top is empty (contradiction — no valid instance).
2. **SRE algebraic properties**: commutativity, associativity, idempotence of domain intersection. Is this a Heyting algebra? Does it form a quantale with the type lattice?
3. **Integration with type lattice**: when a type-map position narrows (meta → Int), the constraint domain for that position's trait constraints narrows correspondingly.
4. **Parametric instance handling**: CLP narrowing for parametric impls (e.g., `impl Eq (List A) where (Eq A)`) — the domain includes parametric entries that generate sub-constraints.
5. **Relation to SRE Track 2H properties**: the constraint domain should be registered as an SRE domain with declared properties that property inference validates.
6. **This IS the bridge between functional types and relational constraints**: types as CLP domains, trait constraints as domain constraints, elaboration as constraint propagation. The design must account for future use as domain constraints in the Relational Language.

### Status: NEEDS DEDICATED DESIGN before Phase 2 implementation

---

## §12 Open Questions Resolved

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
