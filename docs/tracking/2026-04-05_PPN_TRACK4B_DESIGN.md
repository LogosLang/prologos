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

## §10 Open Questions Resolved

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
