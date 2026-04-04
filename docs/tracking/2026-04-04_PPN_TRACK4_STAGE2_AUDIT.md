# PPN Track 4 — Stage 2 Audit: Elaboration Infrastructure

**Date**: 2026-04-04
**Scope**: Current elaboration pipeline — what exists, how it works, what the real numbers are. Validates the D.1 design against actual codebase reality.

---

## §1. File Inventory and Scale

| File | Lines | Role |
|------|-------|------|
| typing-core.rkt | 2,796 | Core typing rules: `infer`, `check`, `infer-level`. 448 match arms in infer, 88 in check, 53 in infer-level. |
| elaborator.rkt | 4,156 | AST walker: `elaborate-top-level`, `elaborate`, macro expansion, surface→core translation. |
| metavar-store.rkt | 2,695 | Meta-variable store, constraint accumulation, save/restore state. 453 parameter-related lines. |
| elaborator-network.rkt | 1,080 | Elab-network bridge: cell creation, unify constraints, structural decomposition. 11 cell creation sites, 40 propagator creation sites. |
| trait-resolution.rkt | 640 | Trait impl lookup, instance matching. |
| resolution.rkt | 683 | Unified resolution dispatcher. 16 resolve-trait + constraint-retry sites. |
| elab-speculation-bridge.rkt | 302 | Speculation save/restore bridge for propagator network. |
| typing-errors.rkt | 276 | Error-reporting wrappers around infer/check. |
| qtt.rkt | 2,413 | QTT multiplicity checking: `inferQ`, `checkQ`. |
| zonk.rkt | 1,352 | Meta-variable cleanup: intermediate zonk, final zonk, level zonk. |
| driver.rkt | 2,665 | Pipeline orchestration: process-command, process-def, process-string-ws. |
| **Total** | **19,058** | |

## §2. The Current Elaboration Flow

```
process-command(surf):
  1. reset-meta-store!()
  2. register-global-env-cells!()
  3. init-speculation-tracking!()
  4. expand-top-level(surf)           → expanded surface form
  5. elaborate-top-level(expanded)    → (list 'eval expr) or (list 'check expr type) etc.
  6. infer/check(ctx-empty, expr)     → type                  [type-check phase]
  7. check-unresolved-trait-constraints()                      [resolution phase]
  8. freeze(expr) → zonk()                                     [meta cleanup]
  9. nf(zonked)                                                 [reduction]
  10. register-definition()                                     [global env update]
```

Steps 5-6 are the core elaboration: `elaborate-top-level` walks the surface form, translating to core AST. `infer`/`check` walks the core AST, computing types. These are two SEQUENTIAL walks of the same structure.

Step 7 is the resolution loop: check if all trait constraints were resolved during type-checking. If not, report errors.

Steps 8-9 are cleanup: meta-variable zonking + reduction to normal form.

## §3. Typing Rules: The 589 Arms

| Function | Arms | What it computes |
|----------|------|-----------------|
| `infer` | 448 | Synthesized type: given expr, produce type |
| `check` | 88 | Type checking: given expr + expected type, verify |
| `infer-level` | 53 | Universe level inference |
| **Total** | **589** | |

249 unique `expr-*` types referenced across all arms.

The 10 most common arm patterns (by occurrence in infer):
1. `expr-app` — function application (tensor)
2. `expr-lam` — lambda abstraction (Pi formation)
3. `expr-Pi` — Pi type formation
4. `expr-fvar` — free variable lookup
5. `expr-meta` — meta-variable following
6. `expr-Sigma` — Sigma type formation
7. `expr-boolrec` — Bool elimination (motive-dependent)
8. `expr-natrec` — Nat elimination (motive-dependent)
9. `expr-fst`/`expr-snd` — Sigma projection
10. `expr-reduce` — pattern matching

Plus ~100 arms for: integer arithmetic, rational arithmetic, posit arithmetic, string ops, char ops, keyword ops, symbol ops, map ops, set ops, pvec ops, vec ops, foreign function calls, session types, capability types, logic engine types, etc.

## §4. Cell and Propagator Metrics (Current)

From live measurements on real programs:

| Program | Commands | Cells | Propagators | Cell Allocs | Metas | Speculations | Elaborate ms | Type-check ms |
|---------|----------|-------|-------------|-------------|-------|-------------|-------------|--------------|
| Simple (def + spec + eval) | 5 | 21 | 0 | 62 | 0 | 0 | — | — |
| List + map + match | 5 | 22 | 0 | 69 | 6 | 0 | — | — |
| Maps + dot-access + greet | 6 | 19 | 0 | 96 | 2 | 9 | 6 | 11 |
| Generic arithmetic (+ *) | 3 | 17 | 0 | 48 | 0 | 0 | 2 | 2 |

**Key observations**:
- **0 propagators in all programs.** The current elab-network creates cells but does NOT create typing propagators. Unification constraints are added imperatively. The network's quiescence loop doesn't fire typing rules — `infer`/`check` do.
- **Cells are few** (17-22 per program). These are infrastructure cells (global env, namespace, spec store), not per-expression type cells.
- **Cell allocations are higher** (48-96) because cells are created and garbage-collected within individual commands.
- **Metas are rare** (0-6) for typical programs. Polymorphic code creates more.
- **Speculations exist** (0-9) even for simple programs — map access triggers union-type speculation (Track 2H).
- **Elaboration is fast** (2-11ms) for small programs. Dominated by prelude loading for first command.

## §5. The elab-network Structure

```racket
(struct elab-network
  (prop-net      ;; prop-network (the propagator network substrate)
   cell-info     ;; CHAMP: cell-id → elab-cell-info (type, meta-id, source)
   next-meta-id  ;; Nat — deterministic counter
   id-map        ;; CHAMP: meta-id (gensym) → cell-id
   meta-info)    ;; CHAMP: meta-id (gensym) → meta-info (solution, constraints)
  #:transparent)
```

5 fields. The `prop-net` is the propagator network. The `cell-info`, `id-map`, and `meta-info` are CHAMP persistent hash maps. The `next-meta-id` is a counter.

**What's ON the network today**: meta-variable cells, multiplicity cells, level cells, session cells, infrastructure cells. Unification propagators connect meta cells.

**What's NOT on the network**: typing rules (in typing-core.rkt as `match` arms), trait resolution (imperative in resolution.rkt), constraint retry (loop in metavar-store.rkt), speculation (save/restore in elab-speculation-bridge.rkt).

## §6. Speculation Infrastructure

37 occurrences across 7 files:

| File | Count | What it does |
|------|-------|-------------|
| metavar-store.rkt | 9 | `save-meta-state` / `restore-meta-state!` — snapshot/restore CHAMP stores |
| elab-speculation-bridge.rkt | 11 | Bridge between elaborator speculation and propagator network state |
| typing-core.rkt | 4 | `with-speculative-rollback` for union checks, Church fold attempts |
| qtt.rkt | 1 | Speculative QTT checking |
| typing-errors.rkt | 1 | Error reporting with speculation context |
| elaborator-network.rkt | 1 | Network state in speculation |

`save-meta-state` captures: `(current-meta-store)`, `(current-constraint-store)`, `(current-trait-constraint-store)`, `(current-hasmethod-store)`, and potentially the elab-network. `restore-meta-state!` reverts all of these.

**ATMS already exists** (from BSP-LE): `atms-assume!`, `atms-retract!`, nogood management. The infrastructure is built — Track 4 replaces save/restore with ATMS assumption branches.

## §7. Constraint and Resolution Infrastructure

**Constraints**: Currently stored in `(current-constraint-store)` — a list of pending unification constraints. `add-constraint!` appends. The resolution loop iterates and retries.

**Trait constraints**: Stored in `(current-trait-constraint-store)` — a hash of pending trait lookups. `resolve-trait-constraint!` attempts instance lookup. If meta unsolved, constraint is re-queued.

**Resolution dispatcher** (resolution.rkt): Unified handler for multiple constraint types:
- `action-resolve-trait` — find impl instance
- `action-retry-unify` — retry unification after meta solved
- `action-resolve-hasmethod` — check trait method availability

The resolution loop runs after each `solve-meta!` call — 19 resolution-related sites in metavar-store.rkt.

## §8. What Track 3 Already Provides

| Infrastructure | Status | Where |
|---------------|--------|-------|
| Per-form cells on elab-network | ✅ | form-cells.rkt: one cell per top-level form |
| Form pipeline (dependency-set PU) | ✅ | surface-rewrite.rkt: transforms-set + tree-node |
| Spec cells (per-function) | ✅ | form-cells.rkt: spec-cell-value with collision detection |
| SRE ctor-descs for surf-* | ✅ | form-cells.rkt: 5 registrations (surf-def/defn/eval/check/narrow) |
| FormCell SRE domain | ✅ | form-cells.rkt: registered, Heyting confirmed |
| Tree-canonical parsing | ✅ | tree-parser.rkt: tree-parser is canonical, datums derived |

## §9. What Tracks 2H and 2D Provide

### From Track 2H (Type Lattice Quantale)

| Deliverable | What Track 4 uses it for |
|------------|------------------------|
| `type-tensor-core` | Propagator fire function for application typing |
| `type-tensor-distribute` (scaffolding) | Retired by Track 4 — network distribution |
| `subtype-lattice-merge` with unions | Cell merge for subtype-relation type cells |
| `type-lattice-meet` (complete, 11 ctors) | GLB computation for meet propagators |
| `type-pseudo-complement` (scaffolding) | Retired by Track 4 — ATMS nogood derivation |
| `build-union-type-with-absorption` | Union construction for cell merges |
| Per-relation property declarations | Property cells populated by Track 4 |
| `current-lattice-subtype-fn` callback | Replaced by direct cell reads |
| `make-sre-domain` keyword constructor | Clean domain construction |

### From Track 2D (Rewrite Relation)

| Deliverable | What Track 4 uses it for |
|------------|------------------------|
| `sre-rewrite-rule` (DPO spans) | Elaboration rules AS rewrite rules |
| `pattern-desc` + `child-pattern-split` | Pattern matching for typing rule dispatch |
| `match-pattern-desc` | Structural matching for rule selection |
| `instantiate-template` (scaffolding) | Retired — PUnify fills holes |
| `find-critical-pairs` | Confluence verification for typing rules |
| `make-rewrite-propagator-fn` | Propagator factory for typing rules |
| `apply-all-sre-rewrites` (scaffolding) | Retired — per-rule propagators |
| Form-tag ctor-descs | Form tags as first-class SRE citizens |

## §10. Gap Analysis: What Must Change

| Current | Target | Gap |
|---------|--------|-----|
| `infer`/`check` as match arms | Propagator rules | 589 arms → registered propagators |
| Imperative AST walk | Cell creation + propagator installation | elaborator.rkt rewritten as network constructor |
| `solve-meta!` writes to CHAMP | Meta cells on network | metavar-store.rkt rewritten |
| `save-meta-state!` / `restore-meta-state!` | ATMS assumption branches | 37 sites across 7 files |
| Resolution retry loop | Constraint propagator cells | resolution.rkt + trait-resolution.rkt rewritten |
| `current-constraint-store` (list) | Constraint cells on network | Constraints are cells, not list entries |
| Per-command `reset-meta-store!` | Network state management | Persistent cells + per-command isolation |
| `with-speculative-rollback` | ATMS assumptions | 4 sites in typing-core.rkt |
| 0 typing propagators per program | N typing propagators (one per rule) | The core architectural shift |

## §11. Performance Baseline

| Metric | Measured Value | Source |
|--------|---------------|--------|
| Elaborate phase (simple program) | 2-6 ms | PHASE-TIMINGS |
| Type-check phase (simple program) | 2-11 ms | PHASE-TIMINGS |
| QTT phase | 0-5 ms | PHASE-TIMINGS |
| Zonk phase | 0-1 ms | PHASE-TIMINGS |
| Reduce phase | 4-7 ms | PHASE-TIMINGS |
| Full suite wall time | 138 s | run-affected-tests |
| Cells per program (current) | 17-22 | CELL-METRICS |
| Propagators per program (current) | 0 | CELL-METRICS |
| Meta-variables (typical) | 0-6 | PERF-COUNTERS |
| Speculations (typical) | 0-9 | PROVENANCE-STATS |

**Target**: Track 4 should not regress elaboration + type-check by more than 2× (i.e., combined phase should stay under ~30ms for simple programs). Cell counts will increase (per-expression type cells), but the Pocket Universe approach controls this.

---

## §12. Cross-References

- [PPN Track 4 Design (D.1)](2026-04-04_PPN_TRACK4_DESIGN.md) — the design this audit validates
- [PPN Master Track 4 notes](2026-03-26_PPN_MASTER.md) — integration vision, scaffolding tables
- [DEFERRED.md §Propagator-First Elaboration](DEFERRED.md) — 2 deferred items scoped to Track 4
