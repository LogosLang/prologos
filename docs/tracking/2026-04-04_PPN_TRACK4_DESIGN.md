# PPN Track 4: Elaboration as Attribute Evaluation — Stage 3 Design (D.1)

**Date**: 2026-04-04
**Series**: [PPN (Propagator-Parsing-Network)](2026-03-26_PPN_MASTER.md) — Track 4
**Also known as**: SRE Track 2C
**Prerequisites**: [PPN Track 3 ✅](2026-04-01_PPN_TRACK3_DESIGN.md) (form cells, dependency-set pipeline), [SRE Track 2H ✅](2026-04-02_SRE_TRACK2H_DESIGN.md) (type-lattice quantale), [SRE Track 2D ✅](2026-04-03_SRE_TRACK2D_DESIGN.md) (rewrite relation, DPO spans, critical pairs)
**Principle**: Propagator Design Mindspace ([DESIGN_METHODOLOGY.org](principles/DESIGN_METHODOLOGY.org) § Propagator Design Mindspace)

**Research**:
- [Lattice Foundations for PPN](../research/2026-03-26_LATTICE_FOUNDATIONS_PPN.md) — §2.4 type-lattice semiring, §7.1.4 type lattice as quantale, §7.2 Galois bridges
- [Adhesive Categories](../research/2026-04-03_ADHESIVE_CATEGORIES_PARSE_TREES.md) — elaboration as adhesive DPO, CALM-adhesive guarantee
- [Kan Extensions / ATMS / GFP](../research/2026-03-26_KAN_EXTENSIONS_ATMS_GFP_PARSING.md) — demand-driven elaboration, Right Kan
- [Hypergraph Rewriting](../research/2026-03-24_HYPERGRAPH_REWRITING_PROPAGATOR_PARSING.md) — Engelfriet-Heyker: HR grammars = attribute grammars
- [S-Expression IR to Propagator Compiler](../research/2026-03-30_SEXP_IR_TO_PROPAGATOR_COMPILER.md) — compiler IS the network after Track 4
- [Grammar Form Design Thinking](2026-04-03_GRAMMAR_FORM_DESIGN_THINKING.md) — §14 attribute grammar thread, PPN 4 requirements

**Cross-series consumers**:
- [Grammar Form R&D](2026-04-03_GRAMMAR_FORM_DESIGN_THINKING.md) — Track 4 delivers the machinery that makes `:type` "just work"
- [PPN Track 5](2026-03-26_PPN_MASTER.md) — Type→Surface Galois bridge for disambiguation
- [SRE Track 6](2026-03-22_SRE_MASTER.md) — reduction-as-rewriting shares the DPO infrastructure
- Self-Hosting Series — after Track 4, the production compiler IS a propagator network

---

## Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| 0 | Stage 2 audit + Pre-0 benchmarks | ✅ (audit) ⬜ (Pre-0) | [Audit](2026-04-04_PPN_TRACK4_STAGE2_AUDIT.md): 19K lines, 589 arms, 0 typing propagators, 17-22 cells, 2-11ms. Pre-0 benchmarks pending. |
| 1 | Per-expression type cells on the elab-network | ⬜ | Each AST node gets a type cell. Surfs → cells (Track 3 foundation). Type cells written by elaboration propagators. |
| 2 | Typing rules as propagators (infer/check → attribute rules) | ⬜ | The 589 match arms in typing-core.rkt become registered propagator rules. Each arm = one propagator. |
| 3 | Tensor as on-network propagator | ⬜ | Wire `type-tensor-core` from Track 2H. `f x` → SRE decomposes Pi, connects arg cell to domain, result cell to codomain. |
| 4 | Meta-solving as cell writes (retire imperative metavar-store) | ⬜ | Metas are cells. `solve-meta!` = cell write. Resolution triggered by cell merge, not imperative retry. |
| 5 | ATMS replaces speculation (retire save/restore-meta-state!) | ⬜ | Union checking, Church fold, trait ambiguity → ATMS assumption branches. 37 occurrences across 7 files. |
| 6 | Trait resolution as constraint propagators | ⬜ | Trait constraints are cells. Resolution fires as propagators. ATMS manages overlapping instances. |
| 7 | Surface→Type Galois bridge | ⬜ | Bidirectional: surface form → type constraints (elaboration), type info → surface disambiguation (Track 5 prep). |
| 8 | Scaffolding retirement (8 items from Tracks 2H + 2D) | ⬜ | type-tensor-distribute, absorb-subtype-components, type-pseudo-complement, property keyword API, apply-all-sre-rewrites, K-as-hash, instantiate-template, local tag constants. |
| T | Dedicated test file: test-ppn-track4.rkt | ⬜ | Mandatory test phase (codified rule). |
| 9 | Verification + acceptance file + PIR | ⬜ | Full suite green, A/B benchmark, acceptance file, PIR (16-question checklist). |

---

## §1 The Propagator Design Mindspace: Four Questions for Elaboration

### Question 1: What is the INFORMATION?

Elaboration produces TYPED AST — the assignment of types to every sub-expression. The information is:

- **Per-expression type**: every AST node has a type (possibly unknown = meta, possibly contradictory = type-top)
- **Meta-variable solutions**: each meta `?A` has either no solution (⊥), a solution (concrete type), or a contradiction (⊤)
- **Trait constraints**: "this expression requires `Eq Int`" — either unresolved, resolved (instance found), or contradicted (no instance exists)
- **Multiplicity annotations**: QTT usage tracking — 0 (erased), 1 (linear), ω (unrestricted)
- **Unification constraints**: "these two types must be equal" — either pending, satisfied, or contradicted

Each of these is a FACT. Elaboration is the process of accumulating facts until a fixpoint is reached. The typed AST IS the fixpoint — it's READ from the cells, not BUILT by a function.

### Question 2: What is the LATTICE?

Each kind of information has its own lattice:

**Type lattice** (Track 2H): `type-bot` (unknown) ≤ concrete types ≤ `type-top` (contradiction). Join = `type-lattice-merge` (equality) or `subtype-lattice-merge` (subtyping). Quantale: tensor (`type-tensor-core`) distributes over union-join. Heyting: pseudo-complement for error reporting.

**Meta-solution lattice**: `unsolved` (⊥) → `solved(T)` → `contradicted` (⊤). A meta goes from unknown to solved to (possibly) contradicted. Monotone: once solved, stays solved (or contradicts).

**Constraint lattice**: `pending` (⊥) → `resolved(instance)` → `contradicted` (⊤). A trait constraint goes from pending to resolved (instance found) to contradicted (no instance). Monotone.

**Multiplicity lattice**: `{0, 1, ω, error}` with `0 < 1 < ω`. Already on the network as mult cells (PM Track 8).

**The reduced product**: These lattices form the type-level domain of the 6-domain reduced product. They interact via bridges:
- Meta-solution → type cell (solving a meta writes to the type cell)
- Type cell → constraint cell (a type refinement may resolve a trait constraint)
- Constraint cell → type cell (resolving a trait constraint may refine a type)

### Question 3: What is the IDENTITY?

In the current elaborator, identity is POSITIONAL: the AST node at position P in the tree has type T. The `infer` function walks the tree and computes types by position.

In the propagator design, identity is STRUCTURAL: each AST node IS a cell. The type IS the cell's value. Two references to the same expression share the same cell. Identity is the cell, not the position.

**Per-expression cells**: Each sub-expression gets a type cell when it's encountered during elaboration. Two occurrences of the same expression (e.g., `x` used twice) reference the SAME type cell (the cell for `x`'s type). PUnify's structural sharing handles this — shared sub-cells for shared sub-expressions.

**Meta-variables as cells**: Each `?A` IS a cell. `solve-meta!` = write to the cell. Any propagator watching the cell fires when it's solved. No imperative "retry unsolved constraints" — the network handles it.

### Question 4: What EMERGES?

The typed AST EMERGES from the lattice reaching fixpoint. Not "the elaborator builds the typed AST" but "the network's cells stabilize at the typed AST."

- Every expression's type cell has received all its inputs (from propagators that compute type rules)
- Every meta's cell has been solved (or marked unsolvable)
- Every trait constraint has been resolved (or marked unresolvable)
- Every QTT annotation has been computed

The "elaboration result" is: READ the type cells. If any cell is `type-top` (contradiction), there's a type error — report it via Heyting pseudo-complement (ATMS nogood → dependency trace). If all cells are concrete types, elaboration succeeded.

**What this means**: there is no `elaborate-top-level` function that WALKS the tree. Instead, constructing the per-expression cells and installing the typing propagators IS elaboration. The walk is replaced by cell creation + propagator installation. Fixpoint IS the result.

---

## §1a. Audit Findings (Stage 2 Audit — [2026-04-04_PPN_TRACK4_STAGE2_AUDIT.md](2026-04-04_PPN_TRACK4_STAGE2_AUDIT.md))

Key findings that shaped this design:

1. **The network today has ZERO typing propagators.** Cells exist for metas and infrastructure (17-22 per program). ALL typing computation is in `infer`/`check` match arms (589 arms, 249 unique expr types). The propagator network is passive storage. Track 4 makes it active computation.

2. **Speculation is frequent, not rare.** 0-9 speculations for SIMPLE programs (e.g., `m.name` triggers union-type speculation). Phase 5 (ATMS) improves the HOT PATH, not just cleaning code.

3. **Elaboration + type-check are two sequential walks.** Elaborate (2-6ms) then type-check (2-11ms) — two passes over the same structure. Track 4 merges them into ONE fixpoint computation.

4. **The elab-network struct has 5 fields.** `prop-net`, `cell-info`, `next-meta-id`, `id-map`, `meta-info` (CHAMP maps). Track 4's integration point.

5. **19,058 lines across 11 files.** The migration surface. Incremental approach essential — start with the 10 most common typing arms.

---

## §2 Architecture: Elaboration as Network Construction

### Current (imperative — from audit §2)

```
process-command(surf):
  1. reset-meta-store!()
  2. register-global-env-cells!()
  3. expand-top-level(surf)               → expanded surface form
  4. elaborate-top-level(expanded)         → core AST [walk 1: surface→core]
  5. infer/check(ctx-empty, expr)          → type     [walk 2: core→types]
  6. check-unresolved-trait-constraints()              [resolution loop]
  7. freeze(expr) → zonk()                             [walk 3: meta cleanup]
  8. nf(zonked)                                        [walk 4: reduction]
  9. register-definition()                             [global env update]
```

Four walks of the same structure. The elaborator accumulates constraints imperatively. Resolution retries in loops. Speculation uses save/restore (37 sites, 7 files).

### Target (propagator)

```
process-command(surf):
  ;; Step 1: Create cells for the surface form's sub-expressions
  cells = create-expression-cells(surf)

  ;; Step 2: Install typing propagators for each sub-expression
  ;; (These are the 589 match arms, now as propagator rules)
  install-typing-propagators(cells)

  ;; Step 3: Run to fixpoint
  ;; (The network scheduler fires propagators, resolves constraints,
  ;;  manages ATMS branches, until quiescence)
  run-to-quiescence()

  ;; Step 4: Read the result
  ;; (Type cells hold the computed types. Meta cells hold solutions.
  ;;  Errors are contradictions with ATMS dependency traces.)
  read-elaboration-result(cells)
```

Steps 1-2 are CONSTRUCTION (creating the network for this command). Step 3 is EXECUTION (the network computes). Step 4 is READING (the result IS the cell values).

The key shift: the elaborator no longer COMPUTES types. It DECLARES constraints (as propagators). The network COMPUTES the fixpoint.

---

## §3 Design

### §3.1 Phase 1: Per-Expression Type Cells

**The Four Questions applied to type cells:**

- **Information**: the type of each sub-expression (unknown → concrete → error)
- **Lattice**: type lattice from Track 2H (equality merge for unification)
- **Identity**: the cell IS the expression's type. Shared sub-expressions share cells.
- **Emerges**: types emerge from propagator fixpoint, not from infer/check walk

**What changes**: Currently, `infer` returns a type value. In the propagator design, `infer` doesn't return — it WRITES to a cell. The caller reads the cell when it needs the type.

**Cell creation**: When a surface form is encountered, cells are created for each sub-expression:

```
surf-def "x" : Int := [add 1 2]
  → cell for x's type (initially: declared type Int)
  → cell for [add 1 2]'s type (initially: ⊥)
  → cell for 1's type (initially: infer from literal → Int)
  → cell for 2's type (initially: infer from literal → Int)
  → cell for add's type (initially: lookup spec → Int Int → Int)
```

**Pocket Universe approach**: Not one cell per sub-expression (cell explosion). ONE cell per top-level form, holding a Pocket Universe of sub-expression types. The PU value is a tree of type assignments — one entry per AST position. The merge function understands the tree structure.

This mirrors PPN Track 3's form pipeline: one cell per form, with a PU value that tracks progress. Track 4's PU tracks type assignments instead of pipeline transforms.

**Baseline**: Current elab-network has 17-22 infrastructure cells per program (audit §4). Track 4 adds type information per expression — but the PU approach keeps the CELL count from exploding. The type-map lives INSIDE the form cell's PU value, not as separate cells.

**Existing infrastructure**: Track 3's `form-pipeline-value` holds `(transforms-set × tree-node × registrations)`. Track 4 adds a `type-map` component: `(transforms-set × tree-node × registrations × type-map)`. The type-map is a hash from AST position → type value. The merge for type-maps is pointwise type-lattice-merge.

### §3.2 Phase 2: Typing Rules as Propagators

**The 589 match arms → propagator rules.**

Currently, `infer` is a giant `match` expression. Each arm computes a type for one AST node kind. In the propagator design, each arm becomes a propagator that:
1. Watches the input cells (sub-expression types)
2. Fires when its inputs have values
3. Writes the computed type to the output cell

**Example: Pi elimination (application)**

Current (typing-core.rkt line 548):
```racket
[(expr-app e1 e2)
 (let ([t1 (whnf (infer ctx e1))])
   (match t1
     [(expr-Pi m a b) (if (check ctx e2 a) (subst 0 e2 b) (expr-error))]
     [_ (expr-error)]))]
```

Propagator:
```
;; When function-type and arg-type cells both have values:
propagator app-typing [func-type-cell arg-type-cell → result-type-cell]
  :reads func-type-cell, arg-type-cell
  :writes result-type-cell
  :fire
    func-type = read(func-type-cell)
    arg-type = read(arg-type-cell)
    result = type-tensor-core(func-type, arg-type)    ;; Track 2H's tensor
    write(result-type-cell, result)
```

This IS `type-tensor-core` from Track 2H — the tensor as a propagator fire function. Track 2H delivered it as a pure function; Track 4 wires it on the network.

**Not all 589 arms become separate propagators.** Many arms share patterns (literal typing, variable lookup, annotation checking). The propagator rules group by AST node kind:

| AST Kind | Propagator | What it computes |
|----------|-----------|-----------------|
| `expr-app` | Tensor propagator | `type-tensor-core(func-type, arg-type)` → result-type |
| `expr-lam` | Lambda propagator | Creates Pi type from domain + codomain cells |
| `expr-Pi` | Pi formation | Checks domain is a type, codomain is a type under binder |
| `expr-fvar` | Lookup propagator | Reads type from global env cell |
| `expr-meta` | Meta propagator | Follows solution via meta cell |
| `expr-Sigma` | Sigma formation | Component-wise type cells |
| `expr-fst/snd` | Projection | Reads Sigma type, extracts component |
| `expr-natrec` | Eliminator | Dependent typing with motive |
| `expr-boolrec` | Eliminator | Motive-dependent branch typing |
| `expr-J` | Eliminator | Equality proof typing |
| `expr-reduce` | Match propagator | Per-arm type checking, result type unification |
| literals | Constant propagator | Fixed type (Int, Nat, Bool, String, etc.) |

### §3.3 Phase 3: Tensor as On-Network Propagator

Track 2H delivered `type-tensor-core` as a pure function. Track 4 wires it:

```
For each (expr-app func arg) in the AST:
  1. Create result-type cell
  2. Install propagator: reads func-type-cell + arg-type-cell → writes result-type-cell
  3. Fire function: type-tensor-core(func-type, arg-type)
```

**Union distribution**: When func-type is a union (from Track 2H's subtype merge), the network handles it:
- The tensor propagator fires with the union value
- `type-tensor-core` returns `type-bot` for inapplicable components (F1 from Track 2H)
- The result cell's merge (union-join) combines valid results
- Distribution is EMERGENT from multiple writes, not imperative (M3 from Track 2H)

In the scaffolding (Track 2H), `type-tensor-distribute` iterates components. On-network (Track 4), the propagator fires ONCE with the union value. If the union has N components and only K are applicable, the propagator writes K results to the output cell. The cell's merge produces the union of valid results.

### §3.4 Phase 4: Meta-Solving as Cell Writes

**Current**: `solve-meta!` in metavar-store.rkt writes to a CHAMP hash. Downstream consumers check `meta-solution(id)` to follow solved metas. Resolution retries poll unsolved metas.

**Propagator**: Each meta IS a cell. `solve-meta!` = write to the cell. Propagators watching the cell fire automatically when it's solved. No polling. No retry loops.

```
meta ?A:
  cell: type-cell (initially type-bot)
  solve-meta!(?A, Int):
    write(type-cell, Int)          ;; cell merge: ⊥ ⊔ Int = Int
    → all propagators watching ?A's cell fire
    → constraint cells that depended on ?A re-evaluate
    → resolution cascade: no imperative loop needed
```

**The meta-solution callback** (`current-lattice-meta-solution-fn` from Track 2H) becomes a cell read. The callback is scaffolding; the cell IS the permanent mechanism.

### §3.5 Phase 5: ATMS Replaces Speculation

**The most architecturally significant change.**

Current: `with-speculative-rollback` (37 occurrences) uses `save-meta-state!` / `restore-meta-state!` to try a path, roll back on failure, try another. Sequential. Imperative. Blocks on each attempt.

Propagator: Each speculative branch is an ATMS assumption. The network explores ALL branches simultaneously. The ATMS manages consistency — contradictory branches are retracted. No rollback. No sequential try/fail.

**Union type checking** (typing-core.rkt line 2424):
```
;; Current: speculative rollback
check(G, e, A | B) =
  (or (with-speculative-rollback (check G e A))
      (check G e B))

;; Propagator: ATMS branches
check(G, e, A | B):
  assumption α₁ = "e : A"
  assumption α₂ = "e : B"
  → both branches elaborate simultaneously under their assumptions
  → if α₁ leads to contradiction: ATMS retracts α₁
  → if α₂ succeeds: α₂ survives
  → if both succeed: union type preserved (both are valid)
```

**Church fold attempts** (elaborator.rkt):
```
;; Current: try fold-style typing, roll back if it fails, try regular
;; Propagator: ATMS explores both simultaneously
assumption α_fold = "this is a Church fold"
assumption α_regular = "this is a regular expression"
→ both type-check simultaneously
→ contradictions retract the failing assumption
```

**This is the same pattern as parse disambiguation** (PPN Track 5, future): ambiguous parses create ATMS assumptions, type information retracts inconsistent ones. Track 4 establishes the ATMS infrastructure for type-level ambiguity. Track 5 extends it to parse-level ambiguity.

### §3.6 Phase 6: Trait Resolution as Constraint Propagators

**Current**: Trait constraints accumulate in a list. A resolution loop iterates, trying to resolve each constraint. Unsolved constraints are retried when metas are solved (via `constraint-retry` mechanism).

**Propagator**: Each trait constraint IS a cell. The constraint cell watches the type cells of its arguments. When an argument type is refined (meta solved), the constraint cell re-evaluates automatically.

```
constraint (Eq ?A):
  cell: constraint-cell (initially pending)
  watches: ?A's type cell

  when ?A's cell is written (e.g., ?A → Int):
    → constraint propagator fires
    → looks up: impl Eq Int? → found
    → writes: constraint-cell → resolved(int-eq-instance)

  when ?A's cell is contradicted:
    → constraint propagator fires
    → writes: constraint-cell → contradicted
```

**Overlapping instances**: When multiple impl instances could match (trait coherence issue), the ATMS creates assumptions for each. The one that's consistent with all other constraints survives. Critical pair analysis from Track 2D detects incoherent instances at registration time.

### §3.7 Phase 7: Surface→Type Galois Bridge

The bridge between the surface lattice (parsed tree) and the type lattice (computed types). This is the bidirectional connection that the reduced product provides:

**Forward (surface → type)**: When a surface form is parsed, its type constraints are generated. This IS elaboration — the typing propagators fire.

**Backward (type → surface)**: When type information constrains which parse is valid, the type lattice writes BACK to the surface lattice. This is Track 5 scope (type-directed disambiguation), but the BRIDGE INFRASTRUCTURE is Track 4.

The bridge is a set of propagators that connect surface cells to type cells:
- A surface cell holding a surf-def writes the definition's declared type to a type cell
- A type cell holding a contradiction writes a parse-invalid signal to the surface cell
- The ATMS manages the assumption space for ambiguous parses

### §3.8 Phase 8: Scaffolding Retirement

**From Track 2H** (4 items):

| Scaffolding | Retirement in Track 4 |
|-------------|----------------------|
| `type-tensor-distribute` | Phase 3: tensor propagator handles unions natively. Distribution is emergent. |
| `absorb-subtype-components` | Phase 1: type cell merge does pairwise absorption. |
| `type-pseudo-complement` | Phase 5: ATMS nogood → retract → pseudo-complement from dependency structure. |
| Property keyword API | Phase 1: populate `property-cell-ids` on sre-domain. Query = cell read. |

**From Track 2D** (4 items):

| Scaffolding | Retirement in Track 4 |
|-------------|----------------------|
| `apply-all-sre-rewrites` (for/or) | Phase 2: per-rule propagators on network. |
| K bindings as hash | Phase 2: K as sub-cells (PUnify). |
| `instantiate-template` (recursive) | Phase 2: PUnify structural unification fills holes. |
| Local tag constants | Phase 1: shared module or network-level tag registry. |

---

## §4 NTT Model

```
-- Elaboration as attribute evaluation on the propagator network.
-- The type lattice IS a semiring. Elaboration IS parsing in the type semiring.
-- "The parse doesn't produce trees — it produces types."

-- Per-expression type cells (Pocket Universe per form)
cell form-elab-pu
  :carrier FormPipelineValue × TypeMap
  :type-map (HasheqOf ASTPosition TypeValue)
  :merge   pointwise type-lattice-merge on type-map
  :bot     empty type-map (all positions ⊥)
  :top     any position = type-top (contradiction)

-- Typing rule as propagator
propagator typing-rule
  :reads   sub-expression type cells
  :writes  parent expression type cell
  :fire    compute type from sub-types (one infer/check arm)
  :example
    app-typing [func-type arg-type → result-type]
      fire: type-tensor-core(func-type, arg-type)

-- Tensor as propagator (from Track 2H)
propagator tensor
  :reads   func-type-cell, arg-type-cell
  :writes  result-type-cell
  :fire    type-tensor-core(func, arg)
  :union-distribution emergent from cell merge (not explicit iteration)

-- Meta as cell
cell meta-cell
  :carrier TypeValue
  :merge   type-lattice-merge
  :bot     type-bot (unsolved)
  :solve   write(meta-cell, solution-type)
  :cascade all watchers fire on solve

-- Trait constraint as cell
cell constraint-cell
  :carrier ConstraintState
  :merge   constraint-lattice-join
  :bot     pending
  :resolved instance found
  :top     contradicted (no instance)
  :watches argument type cells → re-evaluates on refinement

-- ATMS assumption for speculation
assumption branch
  :creates worldview where branch holds
  :contradiction retracts branch + all dependent cells
  :replaces save-meta-state! / restore-meta-state!

-- Surface→Type Galois bridge
bridge surface-type
  :forward  surface form → install typing propagators (elaboration)
  :backward type contradiction → retract parse assumption (Track 5)
  :mechanism propagators connecting surface cells to type cells
```

### NTT Correspondence Table

| NTT Construct | Racket Implementation | File |
|---------------|----------------------|------|
| `form-elab-pu` | Extended `form-pipeline-value` with type-map | form-cells.rkt |
| `typing-rule` propagator | Registered propagator per AST node kind | typing-propagators.rkt (NEW) |
| `tensor` propagator | `type-tensor-core` wired via `net-add-propagator` | subtype-predicate.rkt + elaborator-network.rkt |
| `meta-cell` | Meta as network cell (replacing CHAMP hash) | metavar-store.rkt (REWRITTEN) |
| `constraint-cell` | Trait constraint as network cell | trait-resolution.rkt (REWRITTEN) |
| `assumption` (ATMS) | `atms-assume!` replacing `save-meta-state!` | elab-speculation-bridge.rkt (REWRITTEN) |
| `bridge surface-type` | Propagators connecting form cells to type cells | elaborator-network.rkt (EXPANDED) |

---

## §5 Risks and Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| Cell explosion (per-expression cells) | High | Pocket Universe: one cell per form, PU tracks sub-expression types. Not one cell per AST node. |
| Performance regression from network overhead | High | Pre-0 benchmarks establish baseline. Per-command elaboration is ~15ms today. Target: no worse than 2×. |
| ATMS memory pressure from many assumptions | Medium | ATMS assumptions are lightweight (bitvectors). Track 4's usage: ~2-5 assumptions per union check. |
| 595-arm typing-core.rkt migration scope | High | Incremental: start with the 10 most common arms (app, lam, Pi, fvar, literal, meta, Sigma, fst/snd, boolrec). Coverage grows per phase. |
| Interaction between typing propagators and constraint propagators | Medium | The existing stratification (S0 monotone, S1 readiness, S2 commit, S(-1) retraction) handles this. Constraint resolution is S0 (monotone — constraints can only gain information). |
| `restore-meta-state!` retirement breaks existing tests | High | Incremental: ATMS coexists with save/restore during migration. Tests migrate incrementally. |

---

## §6 Dependencies

**Depends on (all met)**:
- PPN Track 3 ✅: per-form cells, form pipeline, dependency-set PU, spec cells, SRE ctor-descs
- SRE Track 2H ✅: type-lattice quantale (union-join, tensor, Heyting, per-relation properties)
- SRE Track 2D ✅: DPO rewrite relation, pattern-desc, critical pair analysis, propagator factory
- PM Track 8 ✅: elaboration on propagator network (cells exist, structural decomposition works)
- BSP-LE ✅: ATMS infrastructure (atms-assume!, atms-retract!, nogood management)

**Depended on by**:
- PPN Track 5: type-directed disambiguation (needs Surface→Type bridge)
- SRE Track 6: reduction-as-rewriting (needs per-expression cells for reduction targets)
- Grammar Form: `:type` compilation (needs typing propagator infrastructure)
- Self-Hosting Series: compiler IS the network

---

## §7 Test Strategy

**Phase 0**: Pre-0 benchmarks
- Per-command elaboration wall time (current baseline)
- Per-expression type inference cost
- Meta-solving cascade cost
- Constraint resolution round-trip cost
- ATMS assumption creation/retraction cost

**Phase T**: Dedicated test file (mandatory per codified rule)
- test-ppn-track4.rkt
- Per-propagator-rule output equivalence (old infer arm vs new propagator)
- ATMS speculation equivalence (old rollback vs new assumption)
- Scaffolding retirement verification

**Phase 9**: Full suite GREEN + A/B benchmark

---

## §8 WS Impact

Track 4 does NOT change user-facing syntax. It changes the INTERNAL mechanism for type-checking existing syntax. All `.prologos` programs should produce the same types before and after Track 4. The change is: HOW types are computed (propagator fixpoint vs imperative walk), not WHAT types are computed.

One observable change: error messages may improve (ATMS dependency traces → Heyting pseudo-complement → more informative "why did this fail?" messages).

---

## §9 Cross-References

- **PPN Master Track 4** — detailed integration notes, scaffolding retirement table, integration vision
- **Track 2H PIR §13** — "What's Next": Track 4 is the primary consumer
- **Track 2D PIR §10** — "What Does This Enable": critical pair analysis + sub-cell interfaces for Track 4
- **DEFERRED.md §Propagator-First Elaboration** — 2 items scoped to Track 4
- **Lattice Foundations §2.4** — "type inference as parsing" quote, semiring structure
- **Adhesive Categories §6** — elaboration as adhesive DPO, parallelism guarantee
- **Grammar Form §14** — attribute grammar thread, PPN 4 requirements
