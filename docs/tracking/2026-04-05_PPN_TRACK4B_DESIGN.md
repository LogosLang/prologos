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

---

## Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| 0 | Stage 2 audit + attribute grammar specification | ✅ | [Attribute Grammar](../research/2026-04-05_PROLOGOS_ATTRIBUTE_GRAMMAR.md): 5 domains, 12 node kinds, stratification map |
| 1 | Attribute Record PU: extend type-map to full attribute record | ⬜ | Type + Context + Constraint + Multiplicity + Warning facets |
| 2 | Constraint attribute propagators (S0: creation during typing) | ⬜ | Trait constraints, unification constraints, capability constraints |
| 3 | Trait resolution propagators (S1: readiness-triggered) | ⬜ | P1 pattern: type→constraint narrowing. Monomorphic + parametric. |
| 4 | Multiplicity attribute propagators (S0: usage tracking) | ⬜ | QTT: single-usage, zero-usage, add-usage, scale-usage as cell ops |
| 5 | Structural unification propagators (S0: Pi/Sigma decomposition) | ⬜ | Reuse make-structural-unify-propagator inside ephemeral PU |
| 6 | Meta solution bridging (ephemeral → main network) | ⬜ | PU output channels for solved metas, resolved constraints |
| 7 | Warning attribute propagators (S2: accumulation + reporting) | ⬜ | Coercion, deprecation, capability warnings as cell values |
| 8 | ATMS integration for union type checking (S(-1): retraction) | ⬜ | ATMS branching for union speculation within the attribute PU |
| 9 | Elaboration attributes: implicit args + name resolution on-network | ⬜ | Move insert-implicits-with-tagging into attribute propagators |
| 10 | Retire imperative fallback entirely | ⬜ | infer-on-network/err becomes the ONLY path |
| 11 | Zonk retirement (from Track 4A Phase 4b) | ⬜ | Cell-refs replace expr-meta; fan-in default propagator |
| 12 | Scaffolding retirement (from Track 4A Phase 8) | ⬜ | 8 items from Tracks 2H + 2D |
| T | Dedicated test file | ⬜ | Attribute-level tests: per-domain, per-node-kind, per-stratum |
| 13 | Verification + PIR | ⬜ | Full suite GREEN, A/B benchmark, acceptance file, PIR |

---

## §0 Objectives

**End state**: Elaboration IS attribute evaluation on the propagator network. The parse tree gains attributes (type, context, multiplicity, constraints, warnings) through propagator fixpoint — not through imperative tree walks. The typed, resolved, checked expression EMERGES from quiescence. The imperative `infer/check`, `resolve-trait-constraints!`, `checkQ`, and `freeze` are retired.

**Reframing from Track 4A**: Track 4A framed this as "move side effects on-network." The attribute grammar analysis (§0 foundation) revealed this framing was too narrow. The side effects ARE attributes — they're not separate things to migrate, they're facets of the same evaluation. The right framing: elaboration is attribute evaluation on a structured PU value.

**What Track 4B delivers**:
1. The Attribute Record PU — each AST node has a record with 5 facets (type, context, multiplicity, constraints, warnings)
2. Attribute propagators for ALL 5 domains at the appropriate strata (S0/S1/S2)
3. Elaboration-specific attributes (implicit arg insertion, name resolution) as on-network propagators
4. Retirement of the imperative `infer/check`, `resolve-trait-constraints!`, `checkQ`, and `freeze`
5. The SRE typing domain extended to full attribute rules (not just type rules)

**What this track is NOT**:
- It does NOT move reduction on-network — that's SRE Track 6
- It does NOT move the surface→core structural transformation on-network — that's already on-network via PPN Track 3's form pipeline
- It does NOT implement the self-hosted compiler — but it provides the attribute grammar data that the self-hosted compiler will consume

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

## §4 Elaboration-Specific Attributes

The attribute grammar (§1 foundation, §5 of the AG document) identifies elaboration-specific attributes beyond typing:

### §4.1 Implicit Argument Insertion

Currently imperative in `insert-implicits-with-tagging` (elaborator.rkt:362-528). This creates metas for implicit params, registers trait constraints, and detects capabilities.

**On-network**: the form pipeline (Track 3) produces the surface syntax with arity information. An implicit-insertion propagator watches the function type and argument count. When the function type is a Pi chain with m0 binders and the arg count is less than the total parameter count, the propagator inserts meta POSITIONS in the attribute map for each implicit argument.

This is structurally similar to Track 4A Pattern 1 (implicit argument positions ARE structural components of the Pi decomposition). The difference: Track 4A relied on the elaborator to insert the metas BEFORE typing. Track 4B makes the insertion itself an attribute propagator.

### §4.2 Name Resolution

Currently imperative in `elaborate` (elaborator.rkt:755+). Translates surface names to qualified fvars and de Bruijn bvars.

**On-network**: this is ALREADY on-network via the form pipeline (Track 3). The surface→core structural transformation happens in the form cell's pipeline propagators. Track 4B doesn't change this.

### §4.3 Constraint Registration

Currently imperative: `register-trait-constraint!`, `register-hasmethod-constraint!`, `register-capability-constraint!`.

**On-network**: constraint CREATION is an S0 attribute propagator. When an app's function type reveals an implicit trait domain, the constraint-creation propagator writes a constraint entry to the CONSTRAINT facet of that node's attribute record. The constraint entry includes: trait name, type-arg positions (metas that need solving), dict-meta position.

At S1, the trait-resolution propagator watches the type-arg positions. When they gain ground values, it resolves the instance and writes the dict-meta position's type facet.

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
Phase 0 (audit + AG spec) ✅
  ↓
Phase 1 (Attribute Record PU)
  ↓
Phase 2 (Constraint creation S0) ←─── Phase 1
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
Phase 9 (Elaboration attributes: implicit args) ←─── Phases 2+3+8 (needs constraints + ATMS)
  ↓
Phase 10 (Retire imperative fallback) ←─── ALL above
  ↓
Phase 11 (Zonk retirement) ←─── Phase 10
  ↓
Phase 12 (Scaffolding retirement) ←─── Phase 10
  ↓
Phase T + 13 (Tests + PIR) ←─── ALL
```

Phases 4, 5, 7 are PARALLEL with Phase 3. Phase 9 (implicit args) is the HARDEST and depends on most other phases.

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

## §9 Cross-References

- [Prologos Attribute Grammar](../research/2026-04-05_PROLOGOS_ATTRIBUTE_GRAMMAR.md) — Stage 1 foundation: 5 domains, 12 node kinds, stratification
- [PPN Track 4A D.4](2026-04-04_PPN_TRACK4_DESIGN.md) — §15 Typing PU, §16 SRE Domain, §17 Three Frontiers
- [PPN Track 4A PIR](2026-04-04_PPN_TRACK4_PIR.md) — side-effect boundary finding, longitudinal survey
- [SRE Track 2H](2026-04-02_SRE_TRACK2H_DESIGN.md) — type-lattice quantale (merge = unification)
- [SRE Track 2D](2026-04-03_SRE_TRACK2D_DESIGN.md) — DPO rewrite rules
- [PPN Track 3](2026-04-01_PPN_TRACK3_DESIGN.md) — form cells, pipeline PU pattern
- [PM Track 8](2026-03-22_TRACK8_PIR.md) — elaboration network, ATMS, TMS worldview
- [Hypergraph Rewriting](../research/2026-03-24_HYPERGRAPH_REWRITING_PROPAGATOR_PARSING.md) — Engelfriet-Heyker
- [Grammar Form Design Thinking](2026-04-03_GRAMMAR_FORM_DESIGN_THINKING.md) — attribute grammar thread
