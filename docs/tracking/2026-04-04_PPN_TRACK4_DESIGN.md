# PPN Track 4: Elaboration as Attribute Evaluation — Stage 3 Design (D.4)

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

## §0 Objectives

**End state**: Elaboration IS a propagator fixpoint computation on the network. The parse→elaborate boundary is dissolved. Type inference, trait resolution, and constraint solving are propagator firings in the same S0 pass. The typed AST EMERGES from cells reaching quiescence — not BUILT by an imperative walker. After Track 4, the production compiler IS a propagator network.

**What is delivered**:
1. Per-expression type cells — each AST node has a type cell in a Pocket Universe per form
2. Typing rules as DPO rewrite rules — the 589 match arms become `sre-rewrite-rule` data on the type domain (Engelfriet-Heyker: HR grammars = attribute grammars). Critical pair analysis validates confluence.
3. Context lattice — typing context IS a cell. Binding stack = PU value. Variable lookup = structural read. Scope extension = tensor on context lattice. Module Theory parallel (SRE Track 7 prep).
4. Tensor as on-network propagator — `type-tensor-core` (Track 2H) wired into the network
5. Meta-solving as cell writes — metas ARE cells, `solve-meta!` = cell write, cascade is automatic
6. Zonk retirement — cell-refs replace `expr-meta`. Downstream code reads cells, not walks trees. ~1,300 lines deleted. Fan-in default propagator at S2 for unsolvable metas. (Absorbs SRE Track 2C scope.)
7. ATMS extension — PM Track 8 B1 already retired `save-meta-state!`/`restore-meta-state!` and installed TMS worldview + ATMS hypothesis creation. Track 4 extends to new elaboration patterns (union type checking, Church fold, trait ambiguity under propagator-native elaboration).
8. Trait resolution as constraint propagators — constraints ARE cells, resolution fires as propagators
9. Constraint SRE domain — registered with algebraic properties, meet operation, property inference validation
10. Surface→Type Galois bridge — bidirectional: infer = join relation (upward), check = meet relation (downward). Same cells, per-relation SRE merge. Track 5 prep.
11. Scaffolding retirement — 8 items from Tracks 2H + 2D replaced by on-network mechanisms
12. Dedicated test file — mandatory per codified rule

**What this track is NOT**:
- It does NOT migrate the global environment onto the network — that's SRE Track 7 (Module Loading). Track 4 uses the existing bridge cells and ensures `fvar` propagators are ready for Track 7. See §1c.
- It does NOT implement type-directed parse disambiguation — that's PPN Track 5. Track 4 builds the Surface→Type bridge that Track 5 consumes.
- It does NOT implement β/δ/ι-reduction as propagators — that's SRE Track 6. Track 4 builds per-expression type cells that Track 6 uses as reduction targets.
- It does NOT implement the `grammar :type` compilation target directly — that's Grammar Form R&D. Track 4 delivers the MACHINERY (typing propagator infrastructure) that grammar `:type` will compile to.
- It does NOT implement full PUnify parity (the PUnify toggle, Track 10B's systemic regression). PUnify's structural decomposition IS used for type cell-trees. The PUnify parity track remains separate.

---

## Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| 0 | Stage 2 audit + Pre-0 benchmarks + acceptance file | ✅ | [Audit](2026-04-04_PPN_TRACK4_STAGE2_AUDIT.md): 19K lines, 589 arms, 0 typing propagators. [Pre-0](§Pre-0): cell ops 300-1000× cheaper than typing. Acceptance file: 8 sections, L3 clean (commit `81cf3a72`). DEFERRED triage: 2 items in scope, 1 out. |
| 1a | Component-indexed propagator firing infrastructure | ✅ | `pu-value-diff` + `filter-dependents-by-paths` in `net-cell-write`. `net-add-propagator` gains `#:component-paths` keyword. Fast path preserved for all-#f dependents. 13 tests. (commit `6d5f1adb`) |
| 1b | Per-expression type cells as PU cell-trees | ✅ | `type-map` field added to `form-pipeline-value` (5th field, hasheq). `type-map-merge` pointwise. 30+ construction sites updated. Phase 2 wires in lattice merge. (commit `bffe3c90`) |
| 1c | Context lattice: typing context as cells | ✅ | `context-cell-value` struct in typing-propagators.rkt. Extension = tensor (depth+1). Lookup = de Bruijn position read. Merge: pointwise same-depth, deeper wins. 8 tests. (commit `2f50c6c4`) |
| 2 | Typing rules as propagator fire functions | ✅ | **D.4 REDO** (commit `9aabacdc`): propagator fire functions installed via `net-add-propagator`. Fire fns read/write type-map via `net-cell-read`/`net-cell-write`. `install-typing-network` decomposes expr and installs propagators. -1402/+396 lines. NRC passes. |
| 3 | Type-map population + propagator installation | ✅ | **D.4 REDO** (commit `c3f9db39`): `infer-on-network` creates typing cell + installs propagators + runs to quiescence + reads result from cell. `type-map-merge-fn` for standalone typing cells. NRC passes. |
| 4a | Meta-solving as cell writes | ✅ | Cell-id fast path (`4b8f3876`). Cells authoritative for meta solutions. KEPT — genuinely on-network. |
| 4b | Zonk retirement: fan-in default propagator | 🔄 | **4b-i** ✅ meta-readiness infra (`002f7cc3`). **4b-ii-a** ✅ cell-id fast path (`4b8f3876`). **4b-ii-b** ⬜ zonk deletion: blocked on Phases 2-3 redo (propagator-native typing must produce cell-refs, not expr-meta). |
| P5 | Pattern 5: Context threading as cell positions | ✅ | Context positions in type-map, ctx-extension propagators, bvar reads from ctx position. Lambda/Pi/bvar/fvar enabled. App disabled (Pattern 1). (commit `fb1a69b0`) |
| P1 | Pattern 1: Bidirectional app propagator | ✅ | App writes domain DOWNWARD to arg, result UPWARD. Unification IS the merge at arg-pos. (commit `297faf33`) |
| P2 | Pattern 2: Ephemeral PU typing + expression-key subst | ✅ | Ephemeral prop-network per call (GC'd). subst(0, arg-expr, cod) uses expression keys. Fuel limit + unsolved-meta fallback. Dependent guard REMOVED. (commit `21bcbd58`) |
| 5 | ATMS extension | ⬜ | Blocked on Pattern 2 (dependent subst value-level tracking) and Pattern 3 (constraint postponement). |
| 6 | Constraint propagators + SRE domain | 🔄 | ✅ Constraint lattice (`f7ef8665`). ⬜ Constraint cells as on-network propagators: blocked on Phase 2-3 redo. **DELETE** effects protocol + delegation pattern (imperative scaffolding). |
| 7 | Surface→Type Galois bridge | ✅ | **D.4 REDO** (commit `f1354276`): `infer-on-network/err` wired into process-command for eval/infer. Leaf expressions typed on-network. Non-leaf falls back to imperative (unification not yet on-network). NRC passes. |
| 8 | Scaffolding retirement | ⬜ | Blocked on Phases 2-7 completing on-network. |
| T | Dedicated test file | 🔄 | Infrastructure tests (1a, 1c, 4b-i, constraint lattice) KEPT. Function-call dispatch tests (2a-2e, 3, parity) to be REPLACED with propagator-firing tests. |
| 9 | Verification + PIR | ⬜ | After all phases complete on-network. |

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

**The multi-domain product**: These lattices form the type-level domain of a multi-domain product with bridge propagators (not a formal Cousot-Cousot reduced product — we have monotone bridges but no explicit reduction operator). They interact via bridges:
- Meta-solution → type cell (solving a meta writes to the type cell)
- Type cell → constraint cell (a type refinement may resolve a trait constraint)
- Constraint cell → type cell (resolving a trait constraint may refine a type)

### Question 3: What is the IDENTITY?

In the current elaborator, identity is POSITIONAL: the AST node at position P in the tree has type T. The `infer` function walks the tree and computes types by position.

In the propagator design, identity is STRUCTURAL: each AST node IS a cell. The type IS the cell's value. Two references to the same expression share the same cell. Identity is the cell, not the position.

**Per-expression cells**: Each sub-expression gets a type cell within the form's Pocket Universe. Two occurrences of the same expression (e.g., `x` used twice) reference the SAME type cell (the cell for `x`'s type). PUnify's structural sharing handles this — shared sub-cells for shared sub-expressions. The form cell's PU value holds the ENTIRE parse tree — there is no traversal, only structural decomposition via SRE pattern matching (PPN Track 1-2 established this: the tree IS a cell value).

**Meta-variables as cells**: Each `?A` IS a cell. Expressions contain cell-refs (not `expr-meta` nodes). Reading the cell gives the current value — solved or unsolved. No zonk walk needed. `solve-meta!` = write to the cell. Any propagator watching the cell fires when it's solved. No imperative "retry unsolved constraints" — the network handles it.

**Typing context as a cell**: The context (binding stack for de Bruijn indices) IS a cell whose PU value is a list of (type, multiplicity) bindings. Scope extension (entering a lambda/Pi/let) = tensor on the context lattice, creating a child context cell. Variable lookup = structural read at position k. This parallels Module Theory (SRE Track 7): a typing context is a "local module" with positional exports. See §1e.

### Question 4: What EMERGES?

The typed AST EMERGES from the lattice reaching fixpoint. Not "the elaborator builds the typed AST" but "the network's cells stabilize at the typed AST."

- Every expression's type cell has received all its inputs (from propagators that compute type rules)
- Every meta's cell has been solved (or marked unsolvable)
- Every trait constraint has been resolved (or marked unresolvable)
- Every QTT annotation has been computed
- Every context cell has been extended with all bindings in its scope

The "elaboration result" is: READ the type cells. If any cell is `type-top` (contradiction), there's a type error — report it via Heyting pseudo-complement (ATMS nogood → dependency trace). If all cells are concrete types, elaboration succeeded. There is no zonk walk — expressions contain cell-refs, downstream code reads cells directly.

**Quiescence detection**: A meta-readiness cell per form tracks solved/unsolved metas as a bitmask (monotone: bits flip 0→1 on solve). At S2 commit, a single threshold propagator reads the bitmask complement and writes defaults for genuinely unsolvable metas. One propagator, not N.

**What this means**: there is no `elaborate-top-level` function that WALKS the tree. The form cell holds the parsed surface form as a PU value. A DPO structural decomposition propagator (Track 2D) fires on the form cell, decomposes it into sub-expression type COMPONENTS within the PU value, and installs typing rules (as `sre-rewrite-rule` data) for each component. Typing propagators fire as their inputs arrive. The typed tree IS the form cell's PU value at quiescence — enriched with type information via monotone writes. No traversal. No imperative setup. The cell IS the tree, and elaboration IS the tree gaining type annotations through propagator firings.

**Critical architectural invariant — PU-internal, not topology mutation**: Sub-expression "cells" are COMPONENTS within the form cell's Pocket Universe value, not top-level cells on the prop-network. DPO decomposition ENRICHES the PU value (writing richer structure to an existing cell), it does not CREATE new network cells. Typing propagators are installed ONCE per form cell (at form-cell creation time, which Track 3 already does) with component-indexed firing (§1d) — they fire only when their specific PU component changes. The network topology (which cells exist, which propagators watch them) is FIXED after form-cell creation. Only the VALUES flow. This is the same architecture as PPN Track 1-2: characters → tokens → tree, all as enrichments to existing cell PU values, not topology changes.

**Incremental re-elaboration is emergent**: When a definition's form cell changes, only propagators that depend on it fire. Independent definitions are unaffected. This is the CALM-adhesive guarantee from the [Adhesive Categories research](../research/2026-04-03_ADHESIVE_CATEGORIES_PARSE_TREES.md): monotone elaboration on adhesive structures is coordination-free.

---

## §1a. Audit Findings (Stage 2 Audit — [2026-04-04_PPN_TRACK4_STAGE2_AUDIT.md](2026-04-04_PPN_TRACK4_STAGE2_AUDIT.md))

Key findings that shaped this design:

1. **The network today has ZERO typing propagators.** Cells exist for metas and infrastructure (17-22 per program). ALL typing computation is in `infer`/`check` match arms (589 arms, 249 unique expr types). The propagator network is passive storage. Track 4 makes it active computation.

2. **Speculation is frequent, not rare.** 0-9 speculations for SIMPLE programs (e.g., `m.name` triggers union-type speculation). Phase 5 (ATMS) improves the HOT PATH, not just cleaning code.

3. **Elaboration + type-check are two sequential walks.** Elaborate (2-6ms) then type-check (2-11ms) — two passes over the same structure. Track 4 merges them into ONE fixpoint computation.

4. **The elab-network struct has 5 fields.** `prop-net`, `cell-info`, `next-meta-id`, `id-map`, `meta-info` (CHAMP maps). Track 4's integration point.

5. **19,058 lines across 11 files.** The migration surface. Incremental approach essential — start with the 10 most common typing arms.

---

## §Pre-0: Benchmark Data and Findings

**Benchmark file**: `benchmarks/micro/bench-ppn-track4.rkt` (commit `b3e42297`)
**28 tests across 4 tiers**: M1-M8 micro, A1-A4 adversarial, E1-E6 E2E, V1-V4 validation.

### Two Cost Regimes

| Regime | Operations | Cost | Implication |
|--------|-----------|------|------------|
| **Typing computation** | infer, check, unify, tensor | 50-200μs per op | Dominates elaboration time. This is what each propagator fire costs. |
| **Cell operations** | create, write, read | 0.1-0.4μs per op | **300-1000× cheaper** than typing. Network overhead is negligible. |

### Key Baselines

| Operation | Cost | Design Implication |
|-----------|------|-------------------|
| `infer(literal)` (M1b) | 126μs | Per-arm cost. With ~10 arms per command, ~1ms typing per command. |
| `check(lit:type)` (M2a) | 50μs | Cheaper than infer (no type synthesis). |
| `unify(equal)` (M3a) | 199μs | Structural comparison dominates. |
| `unify(meta solve)` (M3c) | 432μs | Meta-bearing unification includes solve cascade. |
| `save-meta-state` (M5a) | 46μs | Speculation save is cheap. |
| `restore-meta-state!` (M5b) | 48μs | Speculation restore is cheap. ATMS motivation is correctness, not performance. |
| `type-tensor-core` applicable (M6a) | 103μs | Includes whnf + subtype check. This is the propagator fire cost for application. |
| `type-tensor-core` inapplicable (M6b) | 1.3μs | Fast bot return. Network avoids firing downstream propagators. |
| `elab-fresh-meta` (M7a) | 0.3μs | Cell creation is trivially cheap. |
| `elab-cell-write` (M7b) | 0.4μs | Cell write is trivially cheap. |
| `elab-cell-read` (M7c) | 0.08μs | Cell read is nearly free. |
| `make-elaboration-network` (M8a) | 0.1μs | Network creation is trivially cheap. |

### Adversarial Scaling

| Input | Cost | Scaling |
|-------|------|---------|
| depth-5 app chain (A1a) | 1.7ms | Linear |
| depth-10 (A1b) | 3.9ms | Linear |
| depth-20 (A1c) | 7.9ms | Linear (~400μs/level) |
| 20 meta+solve cycles (A2b) | 0.16ms | Linear |
| 20 speculation cycles (A3b) | 0.13ms | Linear |
| 100 cell allocations (A4b) | 0.12ms | Linear |

### E2E Baselines

| Program | Median | Character |
|---------|--------|-----------|
| E1 simple (no metas) | 70ms | Baseline: prelude load + simple typing |
| E2 pattern matching | 78ms | Data + defn with arms |
| E3 mixed-type maps | 78ms | Union speculation |
| E4 polymorphic (prelude + map) | 494ms | **Prelude loading dominates** |
| E5 generic arithmetic | 111ms | Trait dispatch |
| E6 recursive fib(10) | 2,391ms | **Reduction-dominated**, not elaboration |

### Design Impact

**No design changes from Pre-0 data.** The data confirms:
1. Cell creation is cheap (0.1-0.4μs) → per-expression type cells are feasible, PU approach is architectural choice not performance necessity
2. Typing computation dominates (50-200μs) → propagator overhead is negligible compared to what each propagator DOES
3. Speculation is cheap (46-48μs) → ATMS replacement motivated by correctness (parallel branches), not performance
4. Deep nesting scales linearly → propagator chains will scale the same
5. E4/E6 are NOT elaboration bottlenecks (prelude loading / reduction dominate)

---

## §1b. Lattice Algebraic Properties and SRE Domain Registration

### Property Map for Track 4's Lattices

| Domain | Relation | Comm | Assoc | Idemp | Has-meet | Distributive | Heyting | SRE Registered? |
|--------|----------|------|-------|-------|----------|-------------|---------|----------------|
| Type | equality | ✅ | ✅ | ✅ | ✅ | ❌ (flat) | ❌ | ✅ `type-sre-domain` |
| Type | subtype | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ (ground) | ✅ per-relation properties |
| Meta-solution | equality | ✅ | ✅ | ✅ | ✅ | ❌ (flat) | ❌ | Uses type domain directly |
| Constraint | equality | ✅ | ✅ | ✅ | ? | ❌ (flat) | ❌ | ⬜ **REGISTER IN TRACK 4** |
| Multiplicity | max | ✅ | ✅ | ✅ | ✅ | ✅ (chain) | ✅ | ✅ existing mult cells |

**Meta cells use the type domain directly**: A meta IS a type cell with the equality merge. `⊥ (unsolved) ⊔ Nat = Nat`. `Nat ⊔ Int = ⊤ (contradiction)`. No separate domain needed — metas ARE type cells.

**Constraint domain should be registered in Track 4**: Constraints have the same flat-lattice structure as types under equality: `pending (⊥) → resolved(instance) → contradicted (⊤)`. Registering as an SRE domain gives: property inference validation, critical pair analysis on constraint propagators, domain-parameterized operations. The merge:

```
pending ⊔ pending = pending
pending ⊔ resolved(A) = resolved(A)
resolved(A) ⊔ resolved(A) = resolved(A)  (idempotent)
resolved(A) ⊔ resolved(B) = contradicted  (A ≠ B)
contradicted ⊔ X = contradicted
```

### Constraint Domain Meet

The constraint lattice needs a meet (GLB) for the SRE domain registration:

```
meet(contradicted, X) = X                 (⊤ is identity for meet)
meet(X, contradicted) = X
meet(pending, X) = pending                (⊥ is annihilator)
meet(X, pending) = pending
meet(resolved(A), resolved(A)) = resolved(A)  (idempotent)
meet(resolved(A), resolved(B)) = pending       (different instances → ⊥, no common lower bound)
```

This is the DUAL of the join. `pending` is annihilator for meet (dual of ⊤ absorbing for join). `contradicted` is identity for meet (dual of ⊥ identity for join).

### Property Verification Plan

Following the Pre-0 property check pattern (Track 2G L6, Track 2H):

**Before implementation** (Phase 0 → design validation):
- Manually verify constraint lattice properties on sample values (commutativity, associativity, idempotence, identity, absorption)
- Verify meet duality (meet(a, join(a,b)) = a for constraint domain)

**During implementation** (Phase 6 → constraint propagators):
- Register constraint SRE domain with `make-sre-domain`
- Declare properties in `declared-properties` (per-relation, nested hash from Track 2H)
- Run `infer-domain-properties` with constraint samples
- Verify: commutative ✅, associative ✅, idempotent ✅, has-meet ✅, distributive ❌ (expected — flat)
- Any contradictions between declared and inferred → design error, fix before proceeding

**Distributivity analysis**: 2 of 4 domains are distributive (subtype, mult). The non-distributive ones (type-equality, constraint) are flat — conflicts go directly to ⊤, which is correct because conflicts ARE errors. For the reduced product iteration, flat lattices converge in one step (any non-⊥ write is final) — no iteration needed for the non-distributive domains.

### Bidirectional Ring Structure

Bidirectional type inference (infer + check) is TWO RELATIONS on the same carrier — the SRE per-relation merge registry handles this natively:

| Direction | Mode | SRE Relation | Ring Role | Flow |
|-----------|------|-------------|-----------|------|
| Upward | Synthesis (infer) | Join relation | Additive operation | Sub-expression types → parent type |
| Downward | Checking (check) | Meet relation | Multiplicative operation | Expected type → sub-expression constraints |

**The ring**: infer-join is additive (accumulate type information upward), check-meet is multiplicative (constrain type information downward). Distribution of meet over join = distribution of checking over synthesis. This IS the Heyting quantale from Track 2H applied bidirectionally. Same cells, same network, different relations. The SRE dispatches the correct merge based on which relation is active.

**What this means for propagators**: A typing propagator for `expr-app` operates bidirectionally:
- **Infer direction** (join): `func-type ⊔ arg-type → result-type` via tensor
- **Check direction** (meet): `result-type ⊓ func-codomain → arg-constraint` via meet-projection

Both directions are monotone. Both use the SAME cells. The propagator fires in whichever direction has new information. The SRE per-relation property system guarantees the algebraic properties hold for each direction independently.

**Distribution scope**: Meet distributes over join for the ground sublattice (Track 2H confirmed Heyting). For dependent types with value-dependency, distribution may not hold algebraically — dependent types are handled by propagator cascade (substitution triggers re-computation of dependent PU components), not by algebraic distribution. Substitution within a dependent application writes a new value to a PU component (value change within existing cell, not topology change).

**QTT multiplicity flow (backward)**: QTT multiplicities flow BACKWARD from usage site to binding site — a variable's multiplicity is determined by how it is used in the body. This is the MEET direction of the bidirectional ring (downward, multiplicative). The mult lattice merge (max) operates at each binding position in the context cell. PM Track 8 already integrates this via `elab-add-type-mult-bridge`. Context cells' per-binding mult component absorbs this backward flow naturally.

**Trait resolution is monotone**: Bundles are conjunctions (`bundle Comparable := (Eq Ord)`) — no inheritance, no superclass hierarchy, no ordering dependencies. Resolving `Eq ?A` never affects how `Ord ?A` resolves. Each constraint cell is independent. All trait resolution is S0 (monotone stratum).

### Bridges Between Domains

| Bridge | From → To | Mechanism | Status |
|--------|-----------|-----------|--------|
| Surface → Type | form cell → typing propagators | **Track 4 core deliverable** | Phase 1-2 |
| Type ↔ Meta | unification → meta cell write/read | Exists (elab-add-unify-constraint) | Reuse, upgrade to permanent cells |
| Meta → Constraint | meta solved → constraint re-evaluates | **Track 4 Phase 6** — replaces retry loop | New |
| Constraint → Meta | instance resolved → dict meta solved | Transitive (constraint writes meta) | Emergent |
| Type ↔ Mult | type structure → mult annotation | Exists (PM Track 8: elab-add-type-mult-bridge) | Reuse unchanged |
| ATMS branch → PU merge | assumption survival → type-map merge | **Track 4 Phase 5** | New |

The cascade: `constraint resolved → meta solved → type cell refined → typing propagators fire → more constraints generated → ...` continues automatically via propagator scheduling until fixpoint. No imperative iteration needed.

### Off-Network State Mapping

| State | Current Location | Track 4 Status | Migration Target |
|-------|-----------------|----------------|-----------------|
| Per-expression types | `infer`/`check` return values | **ON-NETWORK** (Track 4 Phase 1-2) | — |
| Meta-variable solutions | CHAMP `meta-info` + cells | **ON-NETWORK** (Track 4 Phase 4a) — cells become sole authority | — |
| Typing context (`ctx`) | Function argument (linked list) | **ON-NETWORK** (Track 4 Phase 1c) — context cells | — |
| Trait constraint store | `current-trait-constraint-store` (parameter) | **ON-NETWORK** (Track 4 Phase 6) — constraint cells | — |
| Trait instance registry | Hash table (`impl-registry`) | **OFF-NETWORK** — bridge pattern (cell read triggers hash lookup) | SRE Track 7 (instances as module-level cell exports) |
| Global environment | `current-global-env` (parameter) | **OFF-NETWORK** — existing bridge cells (§1c) | SRE Track 7 (per-name cells) |
| Spec store | `current-spec-store` (parameter) | **OFF-NETWORK** — existing bridge cells | SRE Track 7 |
| Bundle registry | `bundle-registry` (hash table) | **OFF-NETWORK** — read-only lookup | SRE Track 7 (bundles as module exports) |

Track 4 migrates 4 of 8 major state items onto the network. The remaining 4 are module-level concerns deferred to SRE Track 7. Each off-network item is accessed via bridge (cell read triggers hash lookup) — the bridge pattern ensures typing propagators don't directly touch off-network state. Track 7 replaces bridges with authoritative cells.

### Pocket Universe Composition with SRE and ATMS

**ATMS branching → per-branch PU → merge at commitment:**

1. ATMS creates assumption branches for union type checking
2. Each branch works with the form cell's type-map PU
3. Typing propagators fire within each branch's worldview
4. Contradicted branches are retracted
5. Surviving branch's PU merges into the main cell (pointwise type-lattice-merge on type-map)

**SRE decomposition → per-component type cells → cascade:**

1. SRE decomposes `[f x]` into sub-cells for `f`, `x`, result
2. Typing propagator watches `f`-type and `x`-type cells
3. Tensor fires: `type-tensor-core(f-type, x-type)` → writes result-type
4. If `f`-type later refines (meta solved): propagator re-fires with new input
5. Result cell merges old and new values (type-lattice-merge)

---

## §1c. Global Environment Scoping Decision

### Current State

The global environment (`current-global-env`) is a Racket parameter holding a hash table. It is NOT on the network. After elaboration computes a type via propagator fixpoint, the result is extracted from cells and written to the OFF-NETWORK hash (`global-env-add`). The cells are used during elaboration; the hash is the persisted state.

`register-global-env-cells!` creates BRIDGE cells that sync with the hash — so `fvar` lookup can read from cells during elaboration. But the authoritative store is the hash.

### Decision: NOT in Track 4 scope

Full global-env-on-network is **SRE Track 7** (Module Loading-on-SRE) scope. Track 7 envisions per-name cells, module export/import as structural matching, adhesive DPO for name resolution. This is a large scope that Track 4 should not absorb.

Track 4's approach: use the existing `register-global-env-cells!` bridge. The `fvar` typing propagator:
1. Reads type from global env hash (current behavior, fast)
2. ALSO checks if a global env cell exists for this name
3. If cell exists, watches it — when the definition's type changes (incremental recompilation), the `fvar` propagator re-fires

This makes Track 4's `fvar` propagator READY for Track 7's full env-on-network — the propagator already watches cells, Track 7 just makes the cells authoritative.

---

## §1d. PU-Based Cell-Trees with PUnify Integration (Path A)

### Architecture: Types as Pocket Universe Cell-Trees

Every type expression is a cell-tree — a Pocket Universe value within an expression cell. The PU value holds the type's structure (tag + components). Components may REFERENCE other cells (meta variables, shared sub-expressions). The merge function understands the tree structure — component-wise type-lattice-merge.

```
Expression cell (top-level on prop-net):
  PU value: type-cell-tree
    tag: 'Pi | 'Sigma | 'app | 'meta-ref | 'atom | ...
    components: [value-or-cell-ref, ...]
      value: concrete type (expr-Nat, expr-Int, etc.)
      cell-ref: reference to a meta cell or shared expression cell

Meta cell (top-level on prop-net):
  value: type-bot (unsolved) | concrete type (solved)
```

**Cell count**: One top-level cell per expression + one per meta + one per constraint. Type structure is WITHIN the PU, not separate cells. For 50 expressions, 10 metas, 5 constraints: **65 cells** (vs 165 without PU).

**PUnify integration**: When unifying two type cell-trees, PUnify reads both PU values, matches tags, and for each component pair: if both are concrete and equal → identity. If one is a meta-ref → install propagator to sync. If both are concrete and different → contradiction. This uses the EXISTING `elab-add-unify-constraint` mechanism — but operating on PU values instead of standalone type values.

**Sharing**: When two expressions reference the same meta `?A`, their PU values contain the same meta-ref (cell-id to ?A's cell). When `?A` is solved, any propagator watching a cell whose PU contains a ref to `?A` fires and reads the updated value. Sharing IS cell identity.

### Component-Indexed Propagator Firing

Standard propagators fire on ANY write to their input cells. For PU-based type cells, this means a propagator watching a Pi type cell fires even if only the multiplicity changed — wasteful when the propagator only cares about the domain.

**Component-indexed firing**: Propagators declare WHICH component of a PU they watch. Only propagators watching changed components are scheduled.

**Infrastructure changes** (targeted, backward-compatible):

1. **Extended watch declaration**: propagators specify an optional component path alongside each input cell-id.

```
;; Current:
(net-add-propagator net (list cell-a cell-b) (list cell-out) fire-fn)

;; Extended:
(net-add-propagator net
  (list (watched-input cell-a #:path '(domain))    ;; watch domain component only
        (watched-input cell-b #:path #f))           ;; watch entire cell (default)
  (list cell-out)
  fire-fn)
```

2. **PU diff on write**: When a PU value is written, the merge determines which components changed. `pu-diff(old-value, new-value) → (listof component-path)`. For a Pi where only codomain changed: `'((codomain))`.

3. **Selective scheduling**: Only propagators whose watched paths intersect the dirty set go on the worklist. Propagators with `#:path #f` fire on any change (current behavior — full backward compat).

**Cost**: `pu-diff` is one `equal?` per component (~0.05μs each). Selective scheduling is set membership (~0.05μs). Total overhead per write: ~0.2μs. Savings: avoids N-1 unnecessary firings where N is component count. For deeply nested types (10+ components), significant.

**Backward compatibility**: All existing propagators have `#:path #f` — they behave exactly as today. Only Track 4's new typing propagators use component paths.

### What This Enables

**Bidirectional type inference as information flow**: Knowing the result type of `f x` constrains `f`'s codomain AND `x`'s type simultaneously. The propagator watching the codomain component fires when the result type is known (from `check` context), writing the constraint backward to `f`'s type cell.

**Incremental re-elaboration**: Changing one definition's type triggers only the propagators that depend on that specific type component. No full re-walk.

**Unification is cell sharing**: To unify two types, install propagators connecting corresponding components. No separate unification pass — it's just "these two PU components must agree."

**Meta-solving cascades naturally**: When meta `?A` is solved, every cell with a meta-ref to `?A` sees the change. Each such cell's propagators fire. The cascade is automatic, targeted (only affected components), and complete (fixpoint).

### Relation-Parameterized Merge

Cell-tree merges are RELATION-PARAMETERIZED via SRE's `sre-domain-merge domain relation` dispatch. The type domain is registered with both equality and subtype relations — same carrier, different merge functions:

- **Equality merge** (unification context): `merge(Nat, Int) = type-top` (contradiction)
- **Subtype merge** (checking context): `merge(Nat, Int) = Nat` (Nat ≤ Int, more information)

For compound types, the relation determines component-wise behavior:
- `Pi(A→B)` under subtype: domain is CONTRAVARIANT (meet), codomain is COVARIANT (join)
- `Pi(A→B)` under equality: both components use equality-merge

Track 2H's per-relation properties already declared this: subtype on the type domain has `distributive: ✅`, `heyting: ✅ (ground)`. The SRE's property inference validates.

---

## §1e. Context Lattice: Typing Context as Cells

### The Problem

In the current elaborator, `infer(ctx, e)` and `check(ctx, e, T)` thread a context `ctx` as a function argument. `ctx` is a linked list of `(type . multiplicity)` pairs using de Bruijn indices — `ctx-extend` conses a new pair onto the front, `lookup-type k ctx` reads position k. Simple and correct, but entirely OFF-NETWORK. Every typing rule takes `ctx` as input; no cell holds the context; no propagator watches context changes.

### Context as a Cell

The typing context IS a cell. Its PU value is a binding stack (list of (type, mult) pairs). The context lattice:

| Element | Meaning |
|---------|---------|
| ⊥ | No bindings known yet |
| `[(Int, ω), (Bool, 1)]` | Two bindings: position 0 is `Int` unrestricted, position 1 is `Bool` linear |
| ⊤ | Contradicted context (impossible binding combination) |

**Merge**: Pointwise on bindings at each position — `merge([(A₁, m₁)], [(A₂, m₂)]) = [(merge(A₁,A₂), merge(m₁,m₂))]`. Types merge via the active relation (equality or subtype). Multiplicities merge via mult-lattice (max). Monotone: bindings only GAIN information.

**Extension (tensor)**: Entering a binder (lambda, Pi, let, Sigma) creates a CHILD context cell whose value = parent extended with the new binding. The child cell watches the parent — when the parent is refined, the child updates. This IS the tensor on the context lattice: `ctx ⊗ (A, m) = child-ctx`.

**Variable lookup**: A `bvar(k)` propagator reads position k from its enclosing context cell. When the context cell is refined (e.g., a binding's type goes from `type-bot` to `Int`), the lookup propagator fires and writes to the variable's type cell.

### Module Theory Parallel

| Module concept | Context concept | SRE mechanism |
|---------------|----------------|---------------|
| Module export set | Typing context | Cell with PU binding-stack value |
| Import resolution | `bvar(k)` lookup | Structural read propagator at position k |
| Module dependency | Scope nesting (lambda inside lambda) | Cell parent→child extension (tensor) |
| Export refinement | Type refinement of a binding | Cell merge (monotone, relation-parameterized) |
| Module composition | Context extension | Tensor on context lattice |

SRE Track 7 (Module Loading) and PPN Track 4 share the SAME cell-based scoping mechanism. A typing context IS a "local module" — a structured value holding positional name-type bindings. Track 4 establishes this pattern; Track 7 extends it to inter-module scope.

### Why This Matters

Without context-as-cells, typing propagators cannot function: the `fvar` propagator needs to know what's in scope, the lambda propagator needs to extend scope, the let propagator needs to introduce bindings. Context threading is what makes typing bidirectional (context flows DOWN from parent to child scope, types flow UP from sub-expressions to parent). On-network context cells make this flow explicit as information flow between cells, not as an argument passed through a function call chain.

---

## §2 Architecture: Elaboration IS the Network

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

Four walks of the same structure. The elaborator accumulates constraints imperatively. Resolution retries in loops. Zonking walks the tree a third time to substitute solved metas.

### Target (propagator — no walks)

```
process-command(surf):
  ;; The form cell already holds the parsed surface form (from PPN Track 1-3).
  ;; Writing to the form cell is the ONLY imperative action.
  ;; Everything else is propagator firing.

  write(form-cell, surf)
    → DPO decomposition propagator fires (Track 2D infrastructure)
      → structural matching on form tag creates sub-expression cells
      → each sub-cell installs typing rewrite rules (sre-rewrite-rule data)
      → sub-cells trigger further decomposition recursively
    → context cells created at each binder scope (tensor on context lattice)
    → typing propagators fire as their inputs arrive
      → bidirectional: infer (join, upward) and check (meet, downward)
      → tensor propagator for application (type-tensor-core from Track 2H)
      → constraint cells created for trait requirements
    → meta cells solved → cascade to dependent propagators
    → constraint cells resolved → cascade to type cells
    → quiescence: all cells stable

  read(form-cell.type-map)
    → the typed AST IS the cell values at quiescence
    → no zonk walk: expressions contain cell-refs, read directly
    → contradictions (type-top) reported via ATMS dependency traces
    → unsolvable metas defaulted by S2 fan-in threshold propagator
```

**Elaboration walks eliminated (walks 1-3).** Writing to the form cell triggers the entire elaboration cascade via propagator firings. The form cell IS the tree (PPN Track 1-2 established: the tree IS a cell value, a Pocket Universe). DPO decomposition IS the "traversal" — but it's a propagator pattern enriching PU values, not an imperative walk. Sub-expressions decompose in parallel (CALM-adhesive guarantee: independent sub-trees elaborate without coordination). The typed tree EMERGES from quiescence.

**Remaining walks** (NOT in Track 4 scope): Reduction (walk 4, currently `nf(zonked)`) → SRE Track 6 (reduction-as-rewriting). Pretty-print reads the tree → out of scope (display concern, not computation). After Track 4, only these two walks remain.

**The architectural boundary**: `write(form-cell, surf)` is the ONE imperative entry point — the external stimulus that triggers the reactive network. This is analogous to characters entering the RRB cell in PPN Track 1. Everything downstream of this write is purely reactive propagator firing. There is no elaboration FUNCTION. There is a form cell. Writing to it triggers the network. Reading from it yields the result. The network IS the elaborator.

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

**PU-based cell-trees (Path A — §1d)**: Each expression gets a top-level cell whose PU value IS a type-cell-tree — structured tag + components, where components may reference meta cells. The merge is component-wise type-lattice-merge. PUnify operates on PU values directly. Component-indexed firing ensures propagators only trigger on their specific component changes.

**Cell count**: One top-level cell per expression + one per meta + one per constraint. Type structure is WITHIN the PU. Baseline: 17-22 infrastructure cells (audit §4). Track 4 adds: ~N expression cells + ~M meta cells + ~K constraint cells per command. For a typical command: N≈20, M≈5, K≈2 → ~27 new cells + 17-22 existing ≈ ~45-50 total. Cell creation cost: ~15μs (negligible vs 70ms elaboration).

**Existing infrastructure**: Track 3's per-form cells provide the form-level anchor. The form cell holds the parsed surface form as a PU value (PPN Track 1-2: tree IS cell value). DPO decomposition propagators (Track 2D) structurally match the form cell and create per-expression sub-cells. No imperative walk — the form cell write triggers decomposition, decomposition creates sub-cells, sub-cells trigger further decomposition recursively.

**Context cells**: Each binder scope (lambda, Pi, let, Sigma) creates a context cell via tensor on the parent context. The root context cell starts as `ctx-empty`. Variable lookup propagators read their enclosing context cell at the appropriate de Bruijn position. See §1e.

### §3.2 Phase 2: Typing Rules as DPO Rewrite Rules

**The 589 match arms → ~50-80 `sre-rewrite-rule` instances on the type domain.**

This is the Engelfriet-Heyker equivalence: HR grammars = attribute grammars. Typing rules ARE attribute grammar rules. Expressing them as DPO rewrite rules makes them first-class DATA — inspectable, composable, analyzable via critical pairs.

**A typing rule as a DPO span:**

```
;; The app typing rule as a DPO rewrite rule
(sre-rewrite-rule
  'app-typing                                    ;; name
  (pattern-desc 'app                             ;; L: match app node
    (list (child-pattern 0 'bind "func")         ;; bind func sub-cell
          (child-pattern 1 'bind "arg")))         ;; bind arg sub-cell
  '("func" "arg")                                ;; K: preserved sub-cells
  (lambda (K)                                    ;; R: type computation
    (let ([func-type (cell-read (K "func" 'type))]
          [arg-type  (cell-read (K "arg" 'type))])
      (type-tensor-core func-type arg-type)))     ;; Track 2H tensor
  'app-typing-fire                               ;; apply-fn
  'forward                                        ;; directionality
  1                                               ;; cost
  'infer                                          ;; confluence-class
  0)                                              ;; stratum (S0 monotone)
```

**What this gives us over closure-based propagators:**
- **Critical pair analysis** (Track 2D): two rules that could fire on the same cell must produce compatible results. Validates confluence automatically.
- **Inspectable structure**: the `pattern-desc` is data, not opaque code. Rules can be listed, filtered, composed.
- **PUnify integration**: K bindings are sub-cells. PUnify's structural matching fills type holes. The `instantiate-template` scaffolding is retired — PUnify IS the template mechanism.
- **Bidirectional rules**: each rule can operate in both infer (join) and check (meet) direction. The SRE per-relation dispatch selects the right merge.

**Rule grouping by AST node kind** (many arms share the same pattern, differing only by tag):

| AST Kind | DPO Rule | Fire function | Direction |
|----------|----------|--------------|-----------|
| `expr-app` | App tensor rule | `type-tensor-core(func-type, arg-type)` | Bidirectional |
| `expr-lam` | Lambda rule | Creates Pi from domain + codomain cells via ctx tensor | Infer up, check destructures down |
| `expr-Pi` | Pi formation rule | Checks domain/codomain are types under context | Infer |
| `expr-fvar` | Lookup rule | Reads type from context cell at position k | Infer |
| `expr-bvar` | Bound var rule | Reads type from enclosing context cell at de Bruijn k | Infer |
| `expr-Sigma` | Sigma formation rule | Component-wise type cells | Infer |
| `expr-fst/snd` | Projection rule | Reads Sigma type, extracts component | Bidirectional |
| `expr-natrec` | Nat eliminator rule | Dependent typing with motive | Infer |
| `expr-boolrec` | Bool eliminator rule | Motive-dependent branch typing | Infer |
| `expr-J` | Equality eliminator rule | Equality proof typing | Infer |
| `expr-reduce` | Match rule | Per-arm type checking, result type unification | Infer |
| literals | Constant rule | Fixed type write (Int, Nat, Bool, String, etc.) | Infer |

**Note**: meta cells have no typing rule. They ARE cells. `expr-meta` becomes a cell-ref — reading the cell gives the current value. No `expr-meta` match arm needed. This is the zonk-retirement connection (Phase 4b).

### 589 → ~60 Rule Accounting

| Category | Current Arms | DPO Rules | Why Reduced |
|----------|-------------|-----------|-------------|
| Core structural (app, lam, Pi, Sigma, fst/snd, let) | ~30 | ~10 | Each structural form = one bidirectional rule |
| Variable lookup (fvar, bvar) | ~10 | 2 | One rule each: global env bridge read, context cell read |
| Meta follow (expr-meta) | ~8 | 0 | Retired — cell-refs replace expr-meta entirely |
| Eliminators (natrec, boolrec, J, reduce) | ~25 | ~8 | Motive-dependent typing: one rule per eliminator |
| Literal types (Int, Nat, Bool, String, Char, Keyword, Symbol, Rational, Posit) | ~20 | 1 | Single "literal → its type" constant rule, parameterized by tag |
| Arithmetic/string/char/keyword ops | ~100 | ~8 | Group by arity pattern: unary-op, binary-op, ternary-op × return-type-class |
| Collection ops (map, set, vec, pvec, list) | ~80 | ~10 | Group by collection kind × operation pattern (get, put, fold, etc.) |
| Session/capability/logic engine | ~30 | ~8 | Domain-specific rules, one per construct kind |
| Type formation (Type, Universe) | ~15 | ~3 | Universe level computation |
| Annotation/cast (the, as) | ~10 | ~2 | Type annotation = merge expected with inferred |
| check-mode arms | 88 | 0 | Subsumed by bidirectional rules (each infer rule works in check direction via meet) |
| infer-level arms | 53 | ~8 | Level inference follows the same pattern structure |
| **Total** | **~589** | **~60** | **~10× reduction** |

The 88 `check` arms and 53 `infer-level` arms are the biggest wins: `check` is subsumed by bidirectional rules (the meet direction), and `infer-level` shares structure with the corresponding `infer` rules. The ~100 arithmetic/string/collection arms collapse because DPO rules are parameterized by tag — one rule for "binary Int op" covers `int+`, `int-`, `int*`, `int/`, etc.

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

### §3.4a Phase 4a: Meta-Solving as Cell Writes (Cell-Refs Replace expr-meta)

**Current state (partially migrated)**: `solve-meta!` already writes to cells AND triggers `run-stratified-resolution-pure` (propagator network to quiescence). The meta→cell→propagator cascade is already implemented. What remains: making cells the ONLY authoritative store (retiring the CHAMP `meta-info` as redundant), and replacing `expr-meta` nodes in expressions with cell-refs.

**Cell-refs**: Currently, expressions contain `expr-meta id cell-id` nodes. Zonking walks the tree to substitute solved metas. With cell-refs, expressions reference cells directly — reading a cell-ref gives the current value (solved or unsolved). No substitution walk needed.

```
;; Current: expr-meta nodes require zonk to substitute
(expr-meta ?A cell-42)  → zonk walks tree → (expr-Nat)

;; Track 4: cell-refs read directly
(cell-ref cell-42)      → read(cell-42) → (expr-Nat)
```

**Fast path preservation**: `elab-add-unify-constraint` currently skips propagator creation for fully-ground types (no unsolved metas). This optimization MUST be preserved — if both types are concrete and equal, cell-merge is identity, no propagator needed.

**The meta-solution callback** (`current-lattice-meta-solution-fn` from Track 2H) becomes a cell read. The callback is scaffolding; the cell IS the permanent mechanism.

### §3.4b Phase 4b: Zonk Retirement — Fan-In Default Propagator

**Retire zonking entirely.** With cell-refs replacing `expr-meta`, there is nothing to "zonk." Downstream code reads cells directly. ~1,300 lines of zonk.rkt deleted. This absorbs SRE Track 2C scope ("Cell References in Expressions — ENABLES zonk elimination").

**What about defaulting unsolvable metas?**

Currently, final zonk defaults unsolved metas to `lzero` (universe level) and `mw` (unrestricted multiplicity). In the propagator design, this becomes a SINGLE fan-in threshold propagator per form:

```
meta-readiness cell (per form):
  value: bitmask of meta solve states (monotone: bits flip 0→1 on solve)
  merge: bitwise-OR

Each meta-solve: flips one bit in the readiness cell
  → merge: OR(old-bitmask, new-bit) → updated bitmask

S2 commit handler (ONE propagator):
  fires when S0 reaches quiescence
  reads: meta-readiness cell → bitmask
  computes: complement (unsolved positions)
  for each unsolved meta:
    write(meta-cell, default-value)  ;; lzero for level metas, mw for mult metas
  → cascading propagator firings settle naturally
```

**Why fan-in, not per-meta**: One propagator per meta is N propagators doing trivial work at S2. A single fan-in propagator reads the bitmask complement and writes all defaults in one batch. The readiness cell's merge (bitwise-OR) is monotone and trivially cheap. The S2 propagator fires exactly once.

**What's deleted**: `zonk-intermediate`, `zonk-final`, `zonk-level` — all three zonk functions (~1,300 lines). The two-phase zonking distinction (intermediate preserves unsolved, final defaults) becomes: S0 propagators do the work that intermediate zonk did (substituting solved metas is just cell reads), S2 fan-in does the work that final zonk did (defaulting unsolvable metas).

### §3.5 Phase 5: ATMS Extension (Delta from PM Track 8 B1)

**PM Track 8 B1 already retired `save-meta-state!`/`restore-meta-state!`.** The current `with-speculative-rollback` uses TMS worldview + ATMS hypothesis creation + `net-commit-assumption`/`net-retract-assumption`. The ATMS API is pure functional (`atms-assume`, `atms-retract` — no `!`, returns new values). The infrastructure is BUILT.

**What Track 4 adds**: extending the existing ATMS mechanism to propagator-native elaboration patterns. The delta:

1. **Union type checking under DPO rules**: When a typing rule encounters a union type, it creates ATMS assumptions for each component. In D.1 this was framed as replacing save/restore — but save/restore is already gone. The actual work: make the DPO typing rules (§3.2) ATMS-aware. Each rule that may branch (app on union func-type, check against union expected-type) creates assumptions via the existing `atms-assume` API.

2. **ATMS-aware cell-tree merge**: When two ATMS branches compute different types for the same cell, the surviving branch's PU value merges into the main cell at commitment. This uses the existing `net-commit-assumption` mechanism.

3. **Learned clause propagation to DPO rules**: The existing nogood infrastructure (`atms-add-nogood`) already prunes known-bad assumption combinations. Track 4 connects this to the DPO rule registry: if a rule's pattern matches a known-bad combination, skip firing.

**Union type checking example** (already works via existing ATMS, Track 4 wires it to DPO rules):
```
check(G, e, A | B):
  assumption α₁ = atms-assume("e : A")    ;; pure functional, returns new ATMS
  assumption α₂ = atms-assume("e : B")
  → both branches elaborate simultaneously under their assumptions
  → if α₁ leads to contradiction: atms-retract(α₁)
  → if α₂ succeeds: α₂ survives, net-commit-assumption promotes values
  → if both succeed: union type preserved (both are valid)
```

**Church fold attempts** (elaborator.rkt): Same pattern — ATMS assumptions for "this is a Church fold" vs "this is a regular expression." Both type-check simultaneously via the existing `with-speculative-rollback` (which ALREADY uses ATMS under the hood since PM Track 8 B1). Track 4's work: ensure the DPO typing rules integrate cleanly with the ATMS branching.

**TMS worldview and lattice composition**: Meta cells hold values per TMS worldview, not globally. The flat lattice join (solved(A) ⊔ solved(B) = contradicted when A≠B) applies WITHIN a single worldview. Cross-worldview values are managed by the TMS stack — each ATMS branch sees only its own worldview's values. This is already built (PM Track 8 B1). Context cells compose the same way: under ATMS branching, each branch extends context under its own worldview. Context cells form TREES (parent→child via tensor), and ATMS branches create worldview-separated subtrees, not merged contexts. There is no cross-branch context merging.

**Error reporting**: Type errors are cells at `type-top` (contradiction). The ATMS dependency trace identifies which assumptions caused the contradiction. The Heyting pseudo-complement (Track 2H scaffolding, retired into ATMS here) computes the minimal error witness. User-facing message generation reads the dependency trace and formats contextual error messages ("Expected A, got B because [trace]"). This replaces the current imperative error path (`typing-errors.rkt`).

**This is the same pattern as parse disambiguation** (PPN Track 5, future): ambiguous parses create ATMS assumptions, type information retracts inconsistent ones. The infrastructure is shared — Track 4 validates it for type-level ambiguity, Track 5 extends to parse-level ambiguity.

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

### §3.7 Phase 7: Surface→Type Galois Bridge (Bidirectional Ring)

The bridge between the surface lattice (parsed tree) and the type lattice (computed types). This IS the bidirectional ring structure from §1b realized as infrastructure:

**Forward / Infer (join, upward)**: Surface form → DPO decomposition → sub-expression cells → typing rules fire → type information accumulates upward. This is the additive operation of the ring.

**Backward / Check (meet, downward)**: Expected type → destructure into component constraints → write to sub-expression type cells. This is the multiplicative operation of the ring. The SRE per-relation merge dispatch selects the meet-merge (subtype relation, contravariant for Pi domains).

**Distribution (Heyting)**: Meet distributes over join — checking distributes over synthesis. When a sub-expression has been inferred (join) AND there's an expected type constraint (meet), the merge combines them. For ground types, this is the Heyting algebra from Track 2H.

The bridge is a set of propagators connecting surface cells to type cells:
- DPO decomposition creates type cells from surface form structure (forward)
- Expected type propagators write constraints to sub-expression cells (backward)
- The ATMS manages the assumption space for ambiguous parses (Track 5 prep)
- Same cells participate in both directions — the relation determines the merge

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
-- Typing rules are DPO rewrite rules (Engelfriet-Heyker: HR = AG).

-- Per-expression type cells (Pocket Universe per form)
cell form-elab-pu
  :carrier FormPipelineValue × TypeMap
  :type-map (HasheqOf ASTPosition TypeValue)
  :merge   pointwise type-lattice-merge on type-map
  :merge-relation per-relation via SRE merge-registry (equality | subtype)
  :bot     empty type-map (all positions ⊥)
  :top     any position = type-top (contradiction)

-- Typing context as cell (§1e)
cell context-cell
  :carrier (Listof (Pair TypeValue Multiplicity))
  :merge   pointwise (type-merge × mult-merge) at each position
  :bot     () (empty context)
  :tensor  ctx-extend: parent-ctx ⊗ (type, mult) = child-ctx
  :lookup  bvar(k) = structural read at position k

-- Typing rule as DPO rewrite rule (§3.2)
rewrite-rule typing-rule
  :lhs     pattern-desc matching AST tag + sub-expressions
  :K       preserved sub-cells (PUnify structural matching)
  :rhs     type computation (fire function)
  :direction bidirectional (infer = join, check = meet)
  :example
    app-typing: pattern-desc 'app [func, arg]
      K: {func, arg} sub-cells preserved
      fire: type-tensor-core(func-type, arg-type)
    lam-typing: pattern-desc 'lam [domain, body]
      K: {domain, body} sub-cells
      fire: ctx-tensor(parent-ctx, domain-type) → child-ctx
            infer(body) under child-ctx → codomain
            write Pi(domain, codomain)

-- DPO decomposition propagator (no imperative walk)
propagator form-decompose
  :reads   form-cell (holds parsed surface form as PU value)
  :writes  sub-expression cells (created by structural matching)
  :fire    SRE pattern-desc matches form tag
           → creates sub-cells for each child position
           → installs typing rewrite rules for each sub-cell
           → sub-cells trigger further decomposition recursively

-- Tensor as propagator (from Track 2H)
propagator tensor
  :reads   func-type-cell, arg-type-cell
  :writes  result-type-cell
  :fire    type-tensor-core(func, arg)
  :union-distribution emergent from cell merge (not explicit iteration)

-- Meta as cell (cell-refs replace expr-meta)
cell meta-cell
  :carrier TypeValue
  :merge   type-lattice-merge
  :bot     type-bot (unsolved)
  :solve   write(meta-cell, solution-type)
  :cascade all watchers fire on solve
  :ref     expressions contain cell-ref (not expr-meta) — no zonk needed

-- Meta-readiness fan-in (zonk retirement)
cell meta-readiness
  :carrier Bitmask (one bit per meta in this form)
  :merge   bitwise-OR (monotone: bits flip 0→1)
  :s2-handler single threshold propagator
    reads complement → writes defaults to unsolvable metas

-- Trait constraint as cell
cell constraint-cell
  :carrier ConstraintState
  :merge   constraint-lattice-join
  :bot     pending
  :resolved instance found
  :top     contradicted (no instance)
  :watches argument type cells → re-evaluates on refinement
  :monotone bundles are conjunctions, no inheritance, no ordering deps

-- ATMS assumption (extends existing PM Track 8 B1 infrastructure)
assumption branch
  :api     atms-assume / atms-retract (pure functional, no !)
  :creates worldview where branch holds
  :contradiction retracts branch via net-retract-assumption
  :commit  surviving branch promotes via net-commit-assumption
  :track4-delta wire DPO typing rules into existing ATMS branching

-- Surface→Type Galois bridge (bidirectional ring)
bridge surface-type
  :forward  surface form → DPO decomposition → type cells (infer = join, upward)
  :backward expected type → destructure → sub-cell constraints (check = meet, downward)
  :ring     join is additive, meet is multiplicative, distribution = Heyting
  :mechanism per-relation SRE merge dispatch on same cells
```

### NTT Correspondence Table

| NTT Construct | Racket Implementation | File |
|---------------|----------------------|------|
| `form-elab-pu` | Extended `form-pipeline-value` with type-map | form-cells.rkt |
| `context-cell` | Context as cell with binding-stack PU value | typing-propagators.rkt (NEW) |
| `typing-rule` (DPO) | `sre-rewrite-rule` instances on type domain | typing-propagators.rkt (NEW) |
| `form-decompose` | DPO structural decomposition propagator | typing-propagators.rkt (NEW) |
| `tensor` propagator | `type-tensor-core` wired as DPO rule fire fn | subtype-predicate.rkt + typing-propagators.rkt |
| `meta-cell` | Meta as network cell (cell-refs in expressions) | metavar-store.rkt (MODIFIED) |
| `meta-readiness` | Bitmask cell + S2 fan-in threshold propagator | metavar-store.rkt (MODIFIED) |
| `constraint-cell` | Trait constraint as network cell | trait-resolution.rkt (REWRITTEN) |
| `assumption` (ATMS) | Existing `atms-assume`/`atms-retract` (PM Track 8 B1) | elab-speculation-bridge.rkt (EXTENDED) |
| `bridge surface-type` | Bidirectional per-relation propagators | elaborator-network.rkt (EXPANDED) |

---

## §4b Phase Dependency Graph

```
Phase 0 (audit + benchmarks) ✅
  ↓
Phase 1a (component-indexed firing) ←— foundation for all typing propagators
  ↓
Phase 1b (PU cell-trees) ←— depends on 1a for selective scheduling
  ↓
Phase 1c (context lattice) ←— depends on 1b for PU value structure
  ↓
Phase 2 (DPO typing rules) ←— depends on 1a-1c for cells + context + component firing
  ↓
Phase 3 (tensor propagator) ←— depends on 2 (typing rule infrastructure)
  |
  ├→ Phase 4a (meta cells, cell-refs) ←— independent of 3, depends on 1b
  |   ↓
  |   Phase 4b (zonk retirement) ←— depends on 4a (cell-refs exist)
  |
  ├→ Phase 5 (ATMS extension) ←— depends on 2 (DPO rules to wire into ATMS)
  |
  ├→ Phase 6 (constraint propagators) ←— depends on 2 + 4a (rules + meta cells)
  |
  └→ Phase 7 (bidirectional bridge) ←— depends on 2 + 3 (rules + tensor)

Phase 8 (scaffolding retirement) ←— depends on 3, 4a, 5 (replaces all scaffolding)
  ↓
Phase T (test file) ←— throughout, but dedicated phase after 8
  ↓
Phase 9 (verification + PIR) ←— after all above
```

**Parallelizable**: Phases 4a, 5, 6, 7 can proceed in parallel after Phase 2+3. Phase 4b depends only on 4a.

### Mixed-State Migration Strategy

During incremental migration, the system operates in MIXED state — some AST tags handled by DPO typing rules, some still by imperative `infer`/`check` arms. The coexistence strategy:

1. **DPO-first with imperative fallback**: When elaborating an expression, check the DPO typing rule registry for the AST tag. If a rule exists, fire it (propagator path). If not, fall back to the imperative `infer`/`check` arm (current path). This is the same pattern as Track 2D's `apply-all-sre-rewrites` with lambda fallback in surface-rewrite.rkt.

2. **Migration batches**: Rules are migrated in batches by AST kind family. Each batch: implement DPO rules → critical pair analysis → test parity → delete imperative arms. The batch sequence follows the rule accounting table: core structural first (highest impact), then operators (highest count), then domain-specific.

3. **Parity gate per batch**: After each batch, the full test suite (7308+ tests) must pass, and A/B benchmark must show no >2× regression. A batch that breaks parity is reverted.

4. **Final deletion**: The imperative `infer`/`check` match arms are not deleted until ALL corresponding DPO rules pass parity. This avoids "validated but not deployed" — each batch's imperative arms are deleted in the same commit as the DPO rules that replace them.

### Debugging and Observability

| Mechanism | What it provides | Status |
|-----------|-----------------|--------|
| Per-command verbose output | Macro-level metrics: metas, constraints, firings, wall time per command | Exists (Track 7 Phase 0b) |
| `trace-serialize.rkt` | Propagator firing traces: which propagator fired, inputs, output | Exists — extend to typing propagators |
| DPO rule isolation testing | Individual rules testable via Track 2D's `apply-sre-rewrite-rule` + `match-pattern-desc` | Exists — DPO rules are data, testable independently |
| ATMS dependency trace | Which assumptions caused a contradiction — causal chain | Exists (PM Track 8 B1) |
| Per-phase A/B benchmark | Statistical comparison before/after each phase | Exists (`bench-ab.rkt`) |

### Regression Parity Criteria

| Criterion | Target |
|-----------|--------|
| Full test suite | All 7308+ tests pass (0 regressions) |
| A/B benchmark | No >2× regression on any comparative program |
| Acceptance file | Level 3 validation (process-file on .prologos file) |
| Type output equivalence | Every test that infers type T today infers type T after Track 4 |
| Error output equivalence | Type error messages at least as informative (ATMS traces may improve them) |

---

## §5 Risks and Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| Cell explosion (per-expression cells) | High | Pocket Universe: PU-internal components, not top-level cells. Fixed network topology. |
| Performance regression from network overhead | High | Pre-0 benchmarks establish baseline. Target: no worse than 2×. Ground-type fast path preserved (propagator with cheap fire for ground case, ON-network). |
| DPO typing rules: 589 arms → ~60 rules migration scope | High | Incremental batch migration with DPO-first + imperative-fallback coexistence (§4b). Critical pair analysis per batch. Parity gate per batch. |
| Mixed-state coexistence during migration | High | DPO-first dispatch: registry check → propagator path or imperative fallback. Each batch self-contained. No "validated but not deployed" — arms deleted with their replacement. |
| Zonk retirement scope (~1,300 lines) | Medium | Cell-refs are a local change (expr-meta → cell-ref). Incremental: intermediate zonk first (just reads), then final zonk (S2 fan-in). |
| Context-as-cells: de Bruijn indexing under substitution | Medium | Context cells use positional merge. Substitution writes PU component values, not topology change. |
| Off-network state (instance registry, global env, specs, bundles) | Medium | Bridge pattern (cell read triggers hash lookup). Explicitly deferred to SRE Track 7. See off-network state mapping (§1b). |
| Interaction between typing and constraint propagators | Medium | Both are S0 (monotone). Trait resolution is monotone (bundles are conjunctions). Existing stratification handles S0→S2. |
| ATMS integration with DPO rules | Low | ATMS infrastructure already built (PM Track 8 B1). Track 4 delta is wiring, not construction. |

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

Observable changes:
- Error messages may improve (ATMS dependency traces → more informative "why did this fail?" messages)
- ~1,300 lines of zonk.rkt deleted (zonk retirement — cell-refs replace expr-meta, no tree walk needed)
- SRE Track 2C scope absorbed (cell references in expressions)

---

## §9 Cross-References

- **PPN Master Track 4** — detailed integration notes, scaffolding retirement table, integration vision
- **Track 2H PIR §13** — "What's Next": Track 4 is the primary consumer
- **Track 2D PIR §10** — "What Does This Enable": critical pair analysis + sub-cell interfaces for Track 4
- **DEFERRED.md §Propagator-First Elaboration** — 2 items scoped to Track 4
- **Lattice Foundations §2.4** — "type inference as parsing" quote, semiring structure
- **Adhesive Categories §6** — elaboration as adhesive DPO, parallelism guarantee
- **Grammar Form §14** — attribute grammar thread, PPN 4 requirements
- **SRE Track 2C** — cell references in expressions, zonk elimination — scope absorbed into Track 4 Phase 4b

---

## §10 D.1→D.2 Critique Findings and Changes

Self-critique with three lenses: Principles (P), Reality Check (R), Propagator Mindspace (M).

### Critical Findings (incorporated into D.2)

| # | Lens | Finding | Resolution |
|---|------|---------|-----------|
| R1 | R | `save-meta-state!`/`restore-meta-state!` already retired by PM Track 8 B1. D.1 Phase 5 scope was wrong. | Phase 5 rescoped as "ATMS extension (delta)" — wiring DPO rules into existing ATMS, not building from scratch. |
| M1 | M | Context (`ctx`) had no cell representation. Typing propagators cannot work without it. | Added §1e Context Lattice. Context = cell with binding-stack PU value. Extension = tensor. Lookup = structural read. Module Theory parallel. |
| M2 | M | `check` mode (top-down flow) not modeled. Bidirectional typing requires backward propagation. | Added bidirectional ring structure to §1b. Infer = join relation (upward), check = meet relation (downward). Same cells, per-relation SRE merge. |
| M3 | M | D.1 had imperative walks for cell creation. Trees are already cells (PPN Track 1-2). | Rewrote §2: form cell write → DPO decomposition propagator → sub-cells → typing rules. No walks. |
| P5 | P | Typing rules as closures, not data. Missed connection to Track 2D rewrite rules. | Rewrote §3.2: typing rules as `sre-rewrite-rule` DPO data. Engelfriet-Heyker. Critical pair analysis validates confluence. |
| M6 | M | Zonking not addressed. Should be retired entirely, not adapted. | Added §3.4b: zonk retirement. Cell-refs replace `expr-meta`. Fan-in bitmask threshold propagator at S2. ~1,300 lines deleted. Absorbs SRE Track 2C. |
| R3 | R | `watched-input` doesn't exist in current API. | Retained as new infrastructure in Phase 1a with acknowledgment that it's new, not extending existing. |
| R4 | R | `solve-meta!` already triggers network resolution. | Phase 4a rescoped: cell-refs replacing `expr-meta` and retiring CHAMP as authoritative store. |

### Retracted Findings

| # | Lens | Finding | Why Retracted |
|---|------|---------|--------------|
| P2 | P | Trait resolution ordering dependencies. | Bundles are conjunctions (no inheritance). Each constraint cell is independent. Trait resolution IS monotone, IS S0. |

### Confirmed (no change needed)

| # | Finding |
|---|---------|
| M4 | Quiescence detection via meta-readiness cell + S2 threshold propagator (fan-in bitmask). |
| M5 | Cell-tree merge is relation-parameterized via SRE merge-registry. Contravariant/covariant per Pi component. |
| P1 | Constraint SRE domain kept for consistency (flat lattice, trivial properties, but uniform with all other domains). |
| R5 | Ground-type fast path in `elab-add-unify-constraint` must be preserved. Noted in §5 Risks. |

---

## §11 D.2→D.3 External Critique Findings and Changes

External critique through propagator-information-flow lens.

### Accepted and Incorporated

| # | Finding | Resolution |
|---|---------|-----------|
| 1a | "Installs typing rules" hides topology mutation — is decomposition creating new cells or enriching PU values? | Clarified in Q4: PU-internal components, NOT top-level cells. Network topology fixed at form-cell creation. DPO decomposition enriches PU values. Same architecture as PPN Track 1-2. |
| 1b | `write(form-cell)` is an imperative seed — should be declared as THE boundary | Declared in §2 as the one imperative entry point. Everything downstream is reactive. |
| 1c | "No walks" is unqualified — reduce + pretty-print remain | Accounted: walks 1-3 (elaborate, type-check, zonk) eliminated. Walk 4 (reduce) → SRE Track 6. Pretty-print → out of scope. |
| 2a | ATMS + flat meta lattice composition: how do assumption-indexed values interact with flat merge? | TMS worldview layer (PM Track 8 B1) handles assumption-indexing. Flat join within worldview, cross-worldview managed by TMS stack. Added to §3.5. |
| 2c | Context length mismatch under ATMS branching | Context cells form trees (not flat merge). ATMS branches via worldviews, not merged contexts. Added to §3.5. |
| 2d | "Reduced product" is wrong terminology — we have ad-hoc bridges, not Cousot-Cousot reduction | Corrected to "multi-domain product with bridge propagators" in §1 Q2. |
| 3a | Instance registry is off-network state — the largest piece | Added off-network state mapping table to §1b. 4 of 8 items migrated by Track 4; remaining 4 deferred to SRE Track 7 with bridge pattern. |
| 3b | Dependent type distribution may not hold algebraically | Added note: distribution holds for ground sublattice (Heyting). Dependent types handled by propagator cascade. |
| 3c | K-bindings under substitution — DPO R side may need new structure | Clarified: substitution writes PU component values (within existing cell), not topology change. |
| 3d | QTT multiplicity flow is backward (usage → binding) and unaddressed | Added QTT backward flow paragraph in §1b. Meet direction of bidirectional ring. Context cells' per-binding mult absorbs this. |
| 5a | Error reporting path absent | Added error reporting paragraph in §3.5: type-top → ATMS dependency trace → Heyting pseudo-complement → formatted message. |
| 5b | Incremental re-elaboration is emergent but not stated | Added explicit statement in Q4: CALM-adhesive guarantee, only affected propagators fire. |
| 5c | 589→80 reduction unsubstantiated | Added detailed rule accounting table in §3.2 with per-category breakdown. Estimate refined to ~60 rules. |
| 5f | No phase dependency graph | Added §4b with full dependency graph, parallelization notes. |
| 6b | Mixed-state migration risk (dual-path coexistence) | Added mixed-state migration strategy in §4b: DPO-first + imperative-fallback, batch migration, parity gate per batch. |
| 6c | Debugging and observability absent | Added debugging/observability table in §4b: trace-serialize extension, DPO rule isolation testing, ATMS traces. |
| 6d | Regression parity criteria unspecified | Added parity criteria table in §4b: 7308+ tests, A/B benchmark, acceptance file, type/error output equivalence. |

### Rejected

| # | Finding | Why Rejected |
|---|---------|-------------|
| 2b | Constraint lattice meet unclear | Already specified in §1b Constraint Domain Meet section. Per-cell (one constraint per cell), not per-expression aggregate. |
| 5d | Ground-type fast path is off-network | It IS on-network: a propagator with a cheap fire function that detects ground inputs and writes identity. No bypass. CALM-safe. |
| 5e | NTT model not present | Present in full §4 of the document. Critique received a truncated summary due to context limits. |
| 4c | DPO + PUnify composition: PUnify creates propagators during firing | PUnify operates on PU values within a firing, not on network topology. Value computation, not cell creation. |

---

## §12 D.3→D.4 Divergence Analysis and Correction

### The Divergence

The D.3 design describes a **propagator-native** architecture: types flow through cells, typing rules fire as propagators, unification is cell merge, the typed AST emerges from quiescence.

The implementation built an **imperative wrapper** architecture: typing rules as function-call closures in a registry, dispatched via hash-table lookup, delegating to the same imperative `infer` they were supposed to replace. 21 rules "deployed to production" that are no-op wrappers — the non-leaf rules call `infer-fallback(ctx, e)` which IS the original imperative `infer`.

### Root Causes

1. **Phase 3 scope compromise**: the design says "install typing propagators via `net-add-propagator`." The implementation built `make-typing-rule-infer` — a function-call wrapper. This was the point of divergence. Every subsequent phase built on the wrapper.

2. **"Parity with imperative" as validation criterion**: tests proved the rules produce the same types as imperative `infer`. But parity means you're still doing the imperative thing. The correct criterion: **does the result come from reading a cell value after propagator quiescence?**

3. **Side-effect coupling solved imperatively**: the 53-failure diagnostic revealed that non-leaf rules can't replace imperative because of side effects (unify → solve-meta! → add-constraint!). Instead of making unification a cell merge (on-network), the "effects protocol" injected imperative functions as callbacks. This made the rules CALL the imperative path instead of REPLACING it.

4. **Network Reality Check not yet codified**: the Vision Alignment Gate asked "On-network?" too subjectively. The Network Reality Check (now codified in workflow.md) asks concretely: "Which `net-add-propagator` calls were added? Which `net-cell-write` calls produce the result?" — the answer for the imperative implementation was "none" for both.

### What Is Kept (Genuinely On-Network)

| Phase | Deliverable | Why Kept |
|-------|-------------|----------|
| 0 | Acceptance file + DEFERRED triage | Validates at Level 3 |
| 1a | Component-indexed propagator firing | `pu-value-diff` + selective scheduling in `net-cell-write`. Real propagator infrastructure. Passes Network Reality Check. |
| 1b | Type-map in form-pipeline-value | PU carries type information. Correct placement. |
| 1c | Context cell value struct | Correct lattice: tensor extension, de Bruijn lookup, merge. |
| 4a | Meta cell-id fast path | Cell reads as sole authority for meta solutions. |
| 4b-i | Meta-readiness fan-in | Set-based tracking, monotone merge. |
| 6 (partial) | Constraint lattice | Join/meet/contradicts. Correct flat-lattice design. |

### What Is Replaced (Imperative Scaffolding)

| Component | File | Why Replaced |
|-----------|------|-------------|
| `typing-rule` struct with `infer-fn`/`check-fn` closures | typing-propagators.rkt | Function-call dispatch, not propagator fire functions |
| `make-typing-rule-registry`, `dispatch-typing-rule` | typing-propagators.rkt | Hash-table lookup, not network scheduling |
| `delegating-infer`, `delegating-check` | typing-propagators.rkt | No-op wrappers that call back to imperative `infer` |
| `effects` hash (`'unify`, `'check`, `'infer-fallback`) | typing-propagators.rkt | Imperative callback injection, not cell operations |
| `make-typing-rule-infer`, `make-default-typing-registry` | typing-propagators.rkt | Function-call wrapper around imperative `infer` |
| `current-typing-rule-infer` parameter | typing-propagators.rkt | Injects wrapper into `infer/err` — remove |
| `infer/err` integration | typing-errors.rkt | Remove `current-typing-rule-infer` check |
| `(current-typing-rule-infer (make-typing-rule-infer ...))` | driver.rkt | Remove installation of wrapper |

### Corrected Implementation: Propagator-Native Typing

The corrected implementation follows the D.3 §2 architecture. No function-call dispatch. No delegation. No effects callbacks. Information flows through cells.

**How the AST enters the network**: The AST IS the form cell's PU value (PPN Track 1-2). It does not get "walked" — it IS a cell value, structurally accessible. When the form reaches 'done', the PU value holds the complete parse tree. SRE structural decomposition (Track 2D's `pattern-desc` matching) identifies sub-expression positions within the PU.

**How type-map positions are populated**: The form cell's `type-map` (Phase 1b) maps sub-expression positions to type values. Each position starts at ⊥ (`type-bot`). This is a cell value write — `net-cell-write` to the form cell with an updated PU value that has `type-bot` for each position.

**How typing propagators are installed**: For each sub-expression position, a typing propagator is installed via `net-add-propagator`:
- Inputs: the form cell (with `#:component-paths` specifying which type-map positions this propagator watches — Phase 1a infrastructure)
- Outputs: the form cell (writes to this propagator's output position in the type-map)
- Fire function: reads the watched positions from the type-map PU value; if all non-⊥, computes the output type and writes it

**How context flows**: Each binder scope (lambda, Pi, let, Sigma) creates a child `context-cell-value` via `context-extend-value` (Phase 1c). The child context is written as part of the PU value at the binder's position. Variable lookup propagators read from the enclosing context at the appropriate de Bruijn position. Context is NOT a function argument — it's a cell value, part of the PU.

**How unification works**: Unification IS cell merge. When two propagators write to the same type-map position, `type-lattice-merge` resolves: equal types → identity, one is ⊥ → take the other, conflict → type-top (contradiction). For structural unification (Pi domain ≡ argument type), a constraint cell is created whose merge checks compatibility. This uses the constraint lattice from Phase 6 (kept).

**How metas work**: A meta's type-map position starts at ⊥. When the meta is solved (via `solve-meta!` → cell write → cascade), the position transitions to the solution type. Every propagator watching that position fires. This is the EXISTING mechanism — `solve-meta!` already writes to cells (Phase 4a kept).

**How the result is read**: After `run-to-quiescence`, read the form cell's PU value. The type-map holds the type of every sub-expression. The top-level expression's type is at the root position. If any position is `type-top`, there's a type error — ATMS dependency traces identify which assumptions caused the contradiction.

**Concrete corrected phases**:

| Phase | Deliverable | How It Passes Network Reality Check |
|-------|-------------|--------------------------------------|
| 2 (redo) | Typing propagator fire functions | Each rule is a `(lambda (net) ...)` that reads type-map positions via `net-cell-read` and writes results via `net-cell-write`. NOT a closure in a hash table. |
| 3 (redo) | Type-map population + propagator installation | `net-add-propagator` called for each sub-expression position. Component paths specify watched positions. Form cell write triggers initial propagation. `run-to-quiescence` produces the typed result. Trace: cell creation (type-map ⊥) → propagator installation → cell write (type) → cell read (result). |
| 5 (redo) | ATMS branching for union types | When a typing propagator encounters a union, ATMS assumptions are created via the existing `atms-assume` API. Per-assumption PU values diverge. `net-commit-assumption` merges the surviving branch. |
| 6 (redo) | Constraint cells for trait resolution | Each trait constraint is a cell on the network (using constraint lattice from Phase 6 kept). Constraint propagators watch argument type positions. When arguments refine, constraint fires and resolves. |
| 7 (redo) | Bidirectional bridge | The typing propagators ARE the bridge. Infer-direction propagators write upward (sub-expression types → parent type). Check-direction propagators write downward (expected type → sub-expression constraints). Same cells, per-relation SRE merge dispatch. |

### Process Codification

**Network Reality Check** added to `workflow.md` (commit `0175c986`): for any phase claiming on-network computation, verify (1) `net-add-propagator` calls added, (2) `net-cell-write` produces the result, (3) full trace from cell creation through propagator firing to cell read. Zero on any = imperative, regardless of data structures.

---

## §13 Continuation: Five On-Network Patterns for Full Non-Leaf Typing

Non-leaf typing propagators (app, lambda, bvar, fvar, Pi) are defined, tested, and pass the NRC in isolation. They can't be deployed because five problems remain imperative. Each maps to prior art in SRE, PPN, and the lattice/module theory.

### Pattern 1: Implicit Arguments — Structural Decomposition, Not Meta Creation

**The problem**: `[id 42]` where `id : {A : Type} → A → A`. The imperative path calls `fresh-meta` to create `?A`, unifies `?A` with `Int`, substitutes. The propagator model has no "create a meta" operation.

**Prior art**: PPN Track 1-2 — when the parser encounters ambiguity, the alternatives ARE the PU value. ATMS branches represent possibilities. The tree cell holds ALL possible parses simultaneously. Alternatives aren't "created" — they're structural components that start at ⊥.

SRE Track 2D — `pattern-desc` matches form structure and creates sub-cell bindings for ALL children, including optional ones. Structural decomposition discovers positions, it doesn't create them.

**The pattern**: Implicit parameters ARE sub-expression positions in the Pi's structural decomposition. When `install-typing-network` encounters a Pi with an implicit domain, it creates a position for the implicit argument at ⊥. The app propagator writes the inferred type (from the explicit argument) to that position. The position starts at ⊥ and gains information through writes — exactly like any other position.

The implicit argument is not "created on demand" — it's a structural component of the Pi that's always there, starting at ⊥, gaining information through bidirectional writes. SRE structural decomposition of the Pi creates all positions, including implicit ones.

**Cell model**: When the app propagator reads `Pi({A:Type}, A → A)` applied to `42`:
- Position for `{A}` starts at ⊥
- The literal propagator writes `Int` to the arg position
- The app propagator reads `Pi({A}, A→A)` and the arg type `Int`
- The app writes `Int` to the `{A}` position (domain = A, arg = Int, so A = Int)
- The `{A}` position goes from ⊥ to `Int` via merge
- The codomain `A → A` becomes `Int → Int` after substitution
- Result position gets `Int`

No `fresh-meta`, no `solve-meta!`. Information flows through positions.

### Pattern 2: Dependent Substitution — Template Instantiation as Propagator

**The problem**: `Pi(m, A, B)` where `B` mentions bvar(0). After the argument type is known, `subst(0, arg, B)` computes the result type. If the argument contains metas, the substituted result does too.

**Prior art**: Track 2D's `instantiate-template` — fill holes from K bindings. The codomain template has a hole (bvar 0), the argument fills it. PUnify's structural matching is this exact operation.

Track 2H's tensor — `type-tensor-core(Pi(m,A,B), arg-type) = subst(0, arg, B)`. The tensor IS substitution. It's already a pure function that computes the result type from the function type and argument.

**The pattern**: A substitution propagator watches the argument position and the codomain. When the argument gains a value, the propagator computes `subst(0, arg, cod)` and writes the result to the output position. This is the same as Track 2D's template hole-filling: the codomain is the template, the argument is the binding, the result is the instantiation.

**Cell model**: The app propagator already does this — `(subst 0 arg-expr cod)` in the upward (infer) direction. If `arg-expr` contains metas (positions at ⊥), the substituted result references those positions. When the metas solve (positions gain values), the substituted result updates. This is AUTOMATIC if the result type itself is written to a position — when its constituent positions change, the merge at the result position fires dependent propagators.

This may require the result type to be a STRUCTURED PU value (like the type-cell-tree from the D.3 design) rather than a flat type value. The type-cell-tree decomposes the result type into sub-positions, so changes to constituent metas cascade through. This connects to the PU model from §1d.

### Pattern 3: Constraint Postponement — Stratified Merge, Not Immediate Contradiction

**The problem**: `?A join Int` where `?A` is a simple meta → `Int` (merge gains info). But `(?A x y) join (f x y)` where `?A` is an applied meta → the merge can't decide. `type-lattice-merge` calls `try-unify-pure` which returns `#f` → `type-top`. But this should be DEFERRED, not contradicted.

**Prior art**: BSP-LE stratification — S0 handles monotone computation, S1 handles readiness checks, S2 handles commitment. Constraints that can't resolve at S0 are held for later strata. The ATMS manages open assumptions that are retracted if contradicted.

SRE Track 2G — property inference validates lattice properties, but some properties can only be confirmed after accumulating enough information. The "infer then validate" pattern: accumulate at S0, validate at S2.

**The pattern**: The merge function needs a THIRD outcome: "defer." For cases where `type-lattice-merge` can't determine agreement or contradiction (applied metas, higher-order patterns), the merge returns the MORE INFORMATIVE value (not type-top) and registers a DEFERRED CONSTRAINT. The deferred constraint is a cell on the network (using the constraint lattice from Phase 6). A readiness propagator at S1 watches the constituent positions; when they gain enough info, the constraint re-evaluates.

**Cell model**: `type-lattice-merge` already has the meta-handling case: "if either has unsolved metas, keep the more concrete value." This IS deferral for simple metas. The gap: for applied metas, `try-unify-pure` returns `#f` too eagerly. The fix is in `type-lattice-merge` or `try-unify-pure`: instead of returning `#f` (which triggers type-top), return a "postponed" marker that `type-lattice-merge` treats as "keep both, wait for more info."

This connects to the ATMS: a postponed constraint IS an ATMS assumption ("these types agree, we just can't verify yet"). If later information contradicts the assumption, ATMS retracts it.

### Pattern 4: Trait Dispatch — Instance Registry as Cell, Resolution as Propagator

**The problem**: `[+ 3 4]` dispatches through the `Add` trait. The imperative path: create dict-meta → look up instance registry → find `impl Add Int` → fill dict-meta with `int-add`. None of this exists on-network.

**Prior art**: Module theory on SRE — module exports ARE cells. SRE Track 7 envisions per-name cells, module export/import as structural matching. Trait instances ARE module-level exports.

SRE Track 2G — domain registration with `make-sre-domain` + declared properties. The trait instance registry IS an SRE domain: the carrier is "set of instances for a trait," the merge is set-union (monotone — instances only increase), properties include coherence (no overlapping instances).

Constraint propagators (elaborator-network.rkt) — `install-type->constraint-propagator` watches a type cell and writes to a constraint cell when the type refines. This is the EXACT pattern for trait resolution.

**The pattern**: Each trait constraint (`Add ?A`) is a constraint cell (using the constraint lattice from Phase 6). A constraint propagator watches the argument type position (`?A`). When `?A`'s position gains a value (e.g., `Int`), the constraint propagator:
1. Reads the instance registry (off-network bridge for now, SRE Track 7 makes it a cell)
2. Matches: `impl Add Int` → `int-add`
3. Writes `resolved(int-add)` to the constraint cell
4. Writes the resolved type to the function position (dict-meta → concrete implementation)

The dict-meta IS a position in the type-map. It starts at ⊥. When the constraint resolves, the constraint propagator writes the implementation type to the dict-meta position. Dependent propagators fire.

**Cell model**: The constraint cell watches the argument type position. When `Int` is written there, the constraint cell resolves. The resolved implementation type flows into the typing network. No imperative `resolve-trait-constraint!` — the constraint propagator IS the resolution.

### Pattern 5: Context Threading — Scope Tree as Cell Tree, Module Theory Parallel

**The problem**: Lambda extends context for its body. Nested lambdas need nested extensions. Currently `install-typing-network` captures context at installation time — a static snapshot. Nested scopes don't get dynamically extended contexts.

**Prior art**: Module theory — modules nest. A submodule's scope includes parent's exports plus its own. SRE Track 7's module loading: per-module cells, import/export as structural matching.

PPN Track 3 — per-form cells with dependency-set pipeline. Each form has a cell, dependencies flow through the pipeline. The form cell's PU value enriches as the pipeline progresses.

Phase 1c context lattice — `context-extend-value` creates a child from parent via tensor. The lattice IS the scope tree structure.

**The pattern**: Each binder scope creates a CONTEXT POSITION in the type-map. A context propagator watches the enclosing context position and the binder's domain type position. When both have values, it computes the extended context and writes it to the scope's context position.

**Cell model**: For `(lambda [x : Int] (lambda [y : Bool] body))`:
- Outer context position: `ctx-empty` (written immediately)
- Outer lambda's context propagator reads `ctx-empty` + domain position `Int` → writes `[(Int, mw)]` to inner-scope context position
- Inner lambda's context propagator reads `[(Int, mw)]` + domain position `Bool` → writes `[(Bool, mw), (Int, mw)]` to body-scope context position
- Body's bvar propagators read from body-scope context position

The context flows DOWNWARD through the scope tree via cell writes. When a domain type refines (meta solved), the context position updates, and all body propagators fire. The scope tree IS a cell tree — each scope has a context position, connected by context-extension propagators.

This is the Module Theory parallel: each scope is a "local module" with exports (bindings). Import resolution (bvar lookup) reads from the enclosing module's export cell. Module composition (scope nesting) is tensor on the context lattice.

---

## §14 Continuation Priority and Scope Assessment

The five patterns decompose into three implementation tiers:

**Tier 1 — Near-term (enables non-leaf deployment)**:
- Pattern 1 (implicit args): Structural decomposition of Pi creates implicit positions. Primarily a change to `install-typing-network`'s Pi/app handling.
- Pattern 2 (dependent substitution): Already handled by the app propagator's `subst` call. The gap is structured PU values for result types containing metas.
- Pattern 5 (context threading): Context positions in type-map, context-extension propagators. Uses existing Phase 1c lattice.

**Tier 2 — Medium-term (enables constraint-dependent typing)**:
- Pattern 4 (trait dispatch): Constraint cells + constraint propagators watching type positions. Uses existing Phase 6 constraint lattice. Instance registry as off-network bridge (Track 7 scope for on-network).

**Tier 3 — Longer-term (completes edge cases)**:
- Pattern 3 (constraint postponement): Requires stratified merge (S0 defers to S1/S2) and ATMS integration. This is the hardest pattern — it touches the merge function semantics and the stratification boundary.

Tier 1 is where the next implementation work should focus. Patterns 1, 2, and 5 together enable the core non-leaf propagators (app, lambda, Pi, variables) to type correctly on-network for the common cases that don't involve traits or deferred constraints.

---

## §15 Typing PU Architecture (from Pattern 2 Investigation)

### Discovery

Pattern 2 investigation (dependent substitution) revealed three issues:
1. **Network accumulation**: typing propagators on the main elab-network persist across commands, causing timeouts from unbounded growth
2. **Ephemeral typing networks solve this**: fresh prop-network per call, discarded after
3. **Expression keys for subst are correct**: `subst(0, arg-pos, cod)` produces the right types

### Architecture: Typing as a Pocket Universe

The ephemeral typing network IS a Pocket Universe — a self-contained lattice computation within a single cell on the main elab-network.

```
Main elab-network:
  form cell ← parse tree + pipeline (existing, PPN Track 3)
  typing PU cell ← NEW: one per eval/infer command
    value: type-map (hasheq position → type)
    merge: type-map-merge-fn (pointwise type-lattice-merge)
    Internal prop-network (ephemeral, GC'd after quiescence):
      K-indexed positions (expression keys in the type-map)
      Typing propagators attached to K-indices
      Context-extension propagators for scope tree
      Quiesces internally → final type-map value
    Result written to typing PU cell on main network
  constraint cells ← trait constraints (Phase 6 lattice, existing)
  meta cells ← metavariable solutions (existing)
```

### How It Works

1. **Typing PU cell created** on the main elab-network (`net-new-cell` with `type-map-merge-fn`). This is the ONE cell that the main network sees.

2. **Ephemeral internal prop-network created** (`make-prop-network`). This is the PU's computational engine — a real propagator network with cells, propagators, and a scheduler, but ISOLATED from the main network.

3. **K-indexed positions populated**: `install-typing-network` walks the core expr and installs propagators on the internal network. Each sub-expression is a K-index (expression key). The internal network's ONE cell holds the type-map hasheq.

4. **Internal quiescence**: `run-to-quiescence` on the internal network fires typing propagators until the type-map stabilizes. The app propagator writes domain DOWNWARD (bidirectional merge = unification) and `subst(0, arg-expr, cod)` UPWARD (expression keys for dependent substitution).

5. **Result written to main network**: the final type-map value is written to the typing PU cell on the main elab-network. Downstream main-network propagators (constraint resolution, ATMS) see this ONE write and fire accordingly.

6. **Ephemeral network discarded**: the internal prop-network is unreferenced after step 5. Racket GC collects it. No manual cleanup. Efficient because CHAMP is persistent (structural sharing, no mutation to undo).

### Why This Works

- **No accumulation**: each typing PU creates a fresh internal network. No propagators persist across commands.
- **One cell on main network**: the typing PU cell is the bridge. Main-network consumers see a single monotone write (⊥ → typed type-map).
- **Real propagators inside**: the internal network has proper scheduling, fixpoint iteration, and component-indexed firing. Circular dependencies (recursive types) are handled by the scheduler.
- **Expression keys for substitution**: `subst(0, arg-pos, cod)` uses the expression key (the value), while the type-map validates type agreement via merge. Clean separation: type-map for validation, expression keys for computation.
- **GC-efficient**: the internal network is a transient Racket value. The typing PU cell's value (the final hasheq) is lightweight.

### Relation to PPN Track 1-2

This is the same PU pattern as PPN Track 1-2: the tree cell holds a PU value (the parse tree as a lattice). The tree cell's internal structure is computed by propagators. The main network sees the tree cell as a single cell with a structured value.

For typing: the typing PU cell holds the type-map. The internal structure is computed by typing propagators. The main network sees the typing PU cell as a single cell with a structured value (the typed type-map).

### Implementation Status

- Ephemeral prop-network: VALIDATED (zero timeouts, correct results for narrow tests)
- Expression-key substitution: VALIDATED (identity, compose, polymorphic functions)
- Typing PU cell on main network: NOT YET IMPLEMENTED (current code creates ephemeral network but doesn't write result to main network cell)
- 15 failures: all PRE-EXISTING (not from Track 4 changes)
- On-network rate: ~46% (acceptance file). Remaining fallbacks from 3 frontiers.

---

## §17 Three Frontiers to 100% On-Network

Current on-network rate: ~46-54%. Three categories of fallback remain.

### Frontier 2: Trait Dispatch (generic-add, generic-eq, etc.)

**Problem**: `(+ 3 4)` → `(expr-generic-add 3 4)`. Return type depends on the `Add` trait instance for the argument type. Currently registered with `return-type=#f`.

**Options**:
- **A. Full constraint propagator**: constraint cell watches arg type, resolves instance from registry. Architecturally complete but requires new propagator kind + instance registry bridge.
- **B. Direct type derivation**: for most numeric traits, return type = argument type (`Add: a→a→a`, `Sub: a→a→a`). Comparison traits return Bool. The return type IS derivable from the argument type without trait resolution.
- **C. Computed return type via SRE domain** (CHOSEN): register generic ops with `return-type = (lambda (arg-type) arg-type)` for arithmetic, `return-type = (lambda (_) (expr-Bool))` for comparison. Uses existing §16 infrastructure. No new architecture.

**Decision**: Option C attempted and REVERTED. same-as-arg-type heuristic produces correct types for same-type ops but bypasses coercion warnings for cross-family ops (Int + Posit32) and produces wrong types for mixed-type operations. Generic arithmetic requires FULL Pattern 4 (Option A): constraint propagators + instance registry bridge + coercion detection. This is a larger scope than simple return-type functions.

### Frontier 1: Meta Resolution (dependent apps with implicit args)

**Problem**: `(id zero)` → `(expr-app (expr-app id ?A) zero)`. The on-network typing computes `subst(0, ?A, cod)` which preserves the meta in the result. `has-unsolved-meta?` catches it and defers.

**The root issue**: The ephemeral network solves `?A` conceptually (the downward write puts `Type` at `?A`'s position). But `subst` uses the EXPRESSION `?A`, not the position's value. The result contains the meta even though the type-map has it solved.

**Options**:
- **A. Local zonk of result**: After quiescence, walk the result type and replace `(expr-meta ?A cid)` with the value at its type-map position (if non-⊥). Local to the ephemeral result, not a global tree walk. Pragmatic.
- **B. Type-map holds type×value pairs**: Each position carries both type (for validation/merge) and value (for substitution). Richer lattice. Architecturally clean but doubles information per position.
- **C. Bridge meta solutions to main network**: After quiescence, write solved meta values back to the main elab-network via `solve-meta!`. The typing PU's output channel. Crosses the ephemeral boundary.

**Prior art**: PPN Track 1-2 tree cell holds both structure and metadata (two facets). SRE Track 2D K bindings hold both value and tag. Option B follows this PU pattern.

### Frontier 3: Structural Collection Types (map-get, set-*, etc.)

**Problem**: `map-get(m, k)` → return type is `V` where `m : Map K V`. Computed return types handle simple Map types but fail on unions (`Map K (Int | String)`).

**Options**:
- **A. Union distribution**: Extract V from each union component, join results. Follows Track 2H tensor distribution pattern. The test-mixed-map regression showed where edge cases are.
- **B. Conservative #f for unions**: Handle `Map K V → V` for concrete maps only. Union maps fall back. Safe intermediate.
- **C. Leave at #f**: Structural ops fall back to imperative. Low impact (few map expressions in typical code).

**Prior art**: Track 2H's tensor distributes over unions — `type-tensor-core` returns `type-bot` for inapplicable, union-join collects valid results. Same pattern for `map-value-type`.

### Implementation Order

1. **F2 first** (trait dispatch): uses existing infrastructure, immediate improvement
2. **F1 next** (meta resolution): architectural decision, Option A as pragmatic start
3. **F3 last** (structural types): union distribution following Track 2H pattern

---

## §16 SRE Typing Domain: Expression-Kind → Type as Domain Data

### The Problem

294 expr-* struct kinds exist. 26 are handled by explicit match arms in `install-typing-network`. The remaining 268 fall through to ⊥, triggering imperative fallback. Adding 268 match arms replicates the imperative 589-arm match — not data-oriented.

### The Self-Hosting Constraint

The §0 end state: "the production compiler IS a propagator network." For self-hosting, ALL typing knowledge must be ON the network as data. Imperative results written to cells is a dead end — the self-hosted compiler needs the typing rules themselves to be network-native data that it can read, execute, and extend.

### The Design: Typing Rules as SRE Domain Entries

Each expression kind is registered in an SRE typing domain — a structured registry where each entry describes:
- **tag**: the expr struct predicate (e.g., `expr-int-add?`)
- **arity**: number of sub-expression children (0, 1, 2, ...)
- **children**: accessor functions for sub-expressions (e.g., `expr-int-add-a`, `expr-int-add-b`)
- **return-type**: either a constant type (e.g., `(expr-Int)`) or a computation tag (`'tensor`, `'pi-formation`, `'bvar-lookup`, etc.)

This parallels Track 2D's `sre-rewrite-rule`:
- `sre-rewrite-rule.tag` → typing-rule tag (expr predicate)
- `sre-rewrite-rule.lhs-pattern` → typing-rule children (structural decomposition)
- `sre-rewrite-rule.rhs-template` → typing-rule return-type (result computation)

### How It Works

**Registration** (one line per expression kind):
```
(register-typing-rule! 'expr-int-add  #:arity 2  #:children (list expr-int-add-a expr-int-add-b)  #:return-type (expr-Int))
(register-typing-rule! 'expr-rat-mul  #:arity 2  #:children (list expr-rat-mul-a expr-rat-mul-b)  #:return-type (expr-Rational))
(register-typing-rule! 'expr-string   #:arity 0  #:children '()  #:return-type (expr-String))
```

**Installation** (the catch-all in `install-typing-network`):
```racket
[_
 (define rule (lookup-typing-rule e))
 (if rule
     (install-from-rule net tm-cid e ctx-pos rule)
     net)]
```

**install-from-rule** dispatches on arity pattern:
- Arity 0: install literal propagator (return-type is a constant)
- Arity 1: recurse on child, install unary propagator
- Arity 2: recurse on both children, install binary propagator
- Special tags ('tensor, 'pi-formation, 'bvar-lookup): use existing special-case propagators

### What This Enables

1. **Self-hosting**: the SRE typing domain IS the compilation target. The self-hosted compiler reads domain entries and installs propagators. No imperative match arms to translate.

2. **Critical pair analysis**: Track 2D infrastructure validates that no two typing rules conflict for the same expression kind. Confluence verified automatically.

3. **Property inference**: SRE Track 2G validates algebraic properties (type(A+B) = type(B+A) for commutative ops).

4. **Completeness check**: data query — "which expr structs have no typing rule?" Auditable, not a code review.

5. **Extensibility**: library authors register typing rules for new constructs. No editing core files.

6. **Coverage**: 268 entries (one line each) + ~10 special-case match arms = complete coverage. The catch-all handles the bulk; explicit arms handle the complex cases (tensor, Pi, context, etc.).
