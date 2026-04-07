# Design Note: PPN Track 4C — Elaboration On-Network

**Date**: 2026-04-07
**Series**: PPN (Propagator-Parsing-Network) — Track 4C
**Predecessor**: PPN Track 4B (Elaboration as Attribute Evaluation)
**Status**: Design note — ready for Stage 2 audit when scheduled

---

## Thesis

Track 4B delivered the attribute evaluation infrastructure: 5-facet attribute records, S0/S1/S2 strata, constraint domain lattice, meta-feedback, structural unification, coercion detection, and the global attribute store on the persistent registry network. ALL tests green, 133s suite time.

Track 4B also created IMPERATIVE BRIDGES between the on-network attribute evaluation and the off-network elaboration/zonking pipeline. These bridges produce correct results but are technical debt — each one is work that Track 4C dissolves by moving elaboration itself on-network.

**Track 4C's goal**: The bridges retire as a consequence of elaboration absorption, not as individual fixes. When elaboration IS attribute evaluation, there's no boundary to bridge.

---

## The Six Bridges (Track 4B Scaffolding)

Each bridge exists because of the elaboration/network boundary:

### Bridge 1: `resolve-trait-constraints!` (parametric resolution)

**What it does**: Called imperatively from `infer-on-network/err` after on-network typing. Handles parametric trait constraints (Seqable, Foldable, Reducible) by pattern matching type-args against parametric impl patterns.

**Why it's off-network**: `build-trait-constraint` in constraint-propagators.rkt only includes monomorphic impls. Parametric impls need pattern matching + sub-constraint generation — designed in §11.7 (two-level narrowing) but not implemented as propagators.

**4C resolution**: Parametric-narrowing propagator. Watches constraint domain + type-arg types. When type-args are ground and parametric candidates remain, performs pattern match → generates sub-constraints as new domain entries → writes narrowed domain. All S0, monotone.

### Bridge 2: `solve-meta!` (output cell → CHAMP)

**What it does**: Reads the meta-solution output cell after quiescence. Calls `solve-meta!` for each resolved meta, writing to the imperative CHAMP meta-store.

**Why it exists**: `freeze`/`zonk` reads from the CHAMP. The CHAMP is the source of truth for the post-typing pipeline. The attribute map has the solutions but the CHAMP doesn't know about them.

**4C resolution**: When `freeze` reads from the attribute map (Bridge 4), the CHAMP bridge is unnecessary. The attribute map IS the meta-store.

### Bridge 3: `infer/err` fallback

**What it does**: Falls back to the imperative type checker for expression kinds the on-network path can't handle: ATMS ops, narrowing expressions, auto-implicits, and expressions where erased type-arg metas can't be resolved.

**Why it exists**: ~10% of expression kinds return type-bot or unsolved metas from the on-network path. The elaborator produces these expressions, but the attribute evaluation doesn't have rules for them.

**4C resolution**: Two parts:
1. Remaining expression kinds get custom match cases or SRE rules (same pattern as Phase 9 prep — ann, tycon, reduce, generics). Bounded work per kind.
2. Erased type-arg metas need the `:kind` facet separation — see Bridge 5.

### Bridge 4: `freeze`/`zonk` (post-typing tree walk)

**What it does**: Walks the expression tree post-typing. Substitutes `expr-meta` nodes with their solutions from the CHAMP. Defaults unsolved level/mult/session metas to ground values.

**Why it exists**: The expression tree from `elaborate-top-level` contains `expr-meta` placeholder nodes. The attribute map has types at meta positions, but the expression tree still has the placeholders. Something must substitute them before reduction and display.

**Measurement (Phase 10)**: 1-21 substitutions per freeze call. Not a no-op.

**4C resolution**: Two options:
- **Option A (incremental)**: `freeze` reads from the attribute map instead of the CHAMP. Same tree walk, on-network data source. `solve-meta!` bridge (Bridge 2) becomes unnecessary.
- **Option B (structural)**: Zonking becomes an S2 propagator. Reads all meta positions from the attribute map, produces a "zonked expression" in an output cell. `default-metas` becomes an S2 fan-in (write defaults to unsolved level/mult positions before the zonk propagator fires). Driver reads the output cell.
- **Option C (radical, depends on SRE Track 6)**: The expression representation changes — metas become cell-refs that auto-resolve. The elaborator produces expressions with cell-refs. "Zonking" is implicit in reading the expression. No tree walk. This is the `WS-B` vision noted in zonk.rkt line 937.

### Bridge 5: Unsolved-dict fallback (erased type-arg metas)

**What it does**: After on-network typing succeeds, checks for remaining unsolved dict-metas. If found, returns an error to trigger the imperative fallback (`infer/err`). The fallback's CHECK mode resolves erased type-arg metas through the unification chain.

**Why it exists**: Option C (Phase 3) skips the downward write for meta arg positions. Erased type-args (domain = `Type(0)`) don't get their solutions via feedback because the domain isn't a compound type containing the meta. The meta stays at bot.

**4C resolution**: Separate `:kind` and `:type` facets for meta positions. `:kind` stores `Type(0)` (the kind of the type variable). `:type` stores the solution (e.g., `Nat`). The downward write goes to `:kind` (no conflict with solution). The feedback writes to `:type`. The constraint bridge reads `:type`. No more Option C skip — both kind and solution coexist.

This is the same pattern as the `#f` context-bot fix from Phase 3: separating semantic levels that were conflated in a single facet.

### Bridge 6: Warning/coercion parameter bridge

**What it does**: Reads coercion warnings from the warning output cell and calls `emit-coercion-warning!` to write to the imperative warning parameter.

**Why it exists**: `driver.rkt` reads from `current-coercion-warnings` (a parameter) and `read-coercion-warnings` (a cell read). Both paths check for warnings. The bridge ensures on-network warnings reach the imperative parameter.

**4C resolution**: Driver reads from the warning output cell directly. The imperative warning parameters are retired. ONE source of truth for warnings: the output cell.

---

## Architectural Connections

The bridges aren't independent — they're connected through the elaboration boundary:

```
Elaboration (imperative)
  produces: expression tree with expr-meta nodes
  registers: trait constraints in CHAMP cells
  ↓
Attribute Evaluation (on-network, Track 4B)
  computes: types, constraints, usages, warnings in attribute map
  resolves: monomorphic traits via S1 propagators
  ↓ BRIDGES (Track 4B scaffolding)
  solve-meta! → CHAMP          (Bridge 2: because freeze reads CHAMP)
  resolve-trait-constraints!    (Bridge 1: because parametric not on-network)
  unsolved-dict → infer/err    (Bridge 5: because erased type-args can't resolve)
  emit-coercion-warning!        (Bridge 6: because driver reads parameters)
  ↓
Post-typing pipeline (imperative)
  freeze/zonk → tree walk       (Bridge 4: because expression has expr-meta nodes)
  checkQ → tree walk            (redundant with Phase 7 on-network validation)
  nf → reduction tree walk      (SRE Track 6 scope)
  pp-expr → display tree walk   (inherent)
```

Track 4C dissolves the bridges by moving the BOUNDARY:

```
Elaboration + Attribute Evaluation (on-network, Track 4C)
  produces: fully-attributed expression in the attribute map
  resolves: ALL traits (monomorphic + parametric) via propagators
  computes: ALL attributes (type, context, constraints, usage, warnings)
  defaults: unsolved metas via S2 fan-in
  zonks: expression via S2 propagator (or cell-ref auto-resolution)
  ↓
Post-typing (minimal, on-network where possible)
  nf → SRE Track 6 (DPO rewriting on-network)
  pp-expr → display (inherent tree walk)
```

---

## Dependencies

| Track 4C Phase | Depends On | Delivers |
|---|---|---|
| `:kind` facet separation | Track 4B Phase 1 (facet infrastructure) | Retires Bridge 5 (unsolved-dict fallback) |
| Parametric-narrowing propagator | Track 4B Phase 2 (constraint domain) + §11.7 | Retires Bridge 1 (resolve-trait-constraints!) |
| Remaining expression kinds | Track 4B Phase 9 prep patterns | Retires Bridge 3 (infer/err fallback) |
| Attribute-map-based freeze | Track 4B Phase 0c (global attribute store) | Retires Bridge 4 (freeze/zonk) + Bridge 2 (solve-meta!) |
| Driver reads output cells | Track 4B Phase 7 (warning output cell) | Retires Bridge 6 (warning bridge) |
| checkQ retirement | Track 4B Phase 7 (usage validation) | Retires `checkQ-top/err` |

**External dependencies**:
- BSP-LE Track 1.5: Cell-based TMS (for Phase 8 / union types)
- SRE Track 6: DPO rewriting (for on-network reduction — `nf` replacement)

---

## Propagator Patterns Available (from Track 4B)

Track 4B established patterns that 4C should use:

- **P1 (initial writes)**: Values known at installation → write directly, no propagator
- **P2 (fire-once)**: Single-input propagators → flag-guard, zero overhead
- **P3 (per-command cleanup)**: net-clear-dependents after quiescence
- **Structural meta-feedback**: Extract internal meta bindings from compound type matches
- **Contradiction propagation**: Type-top at arg/term positions propagates to result
- **S2 coercion detection**: Cross-family type comparison via type-family classifier

---

## Principles Alignment

Track 4C must satisfy the ten load-bearing principles:

- **Propagator-First**: Every bridge replaced by a propagator. No ambient parameters, no imperative function calls during attribute evaluation.
- **Data Orientation**: The attribute map IS the data. `freeze` reads data, doesn't compute. The expression tree is structure; the attribute map is meaning.
- **Correct-by-Construction**: `:kind` / `:type` facet separation prevents the conflation that created Option C. Parametric narrowing is monotone (domains only shrink).
- **Completeness**: 100% expression coverage. No fallback path. The on-network path IS the only path.
- **Decomplection**: Typing, constraints, resolution, usage, warnings, zonking — each is a separate facet/stratum. They compose through the attribute record, not through sequential function calls.

---

## Cross-References

- [Track 4B Design (D.2)](../tracking/2026-04-05_PPN_TRACK4B_DESIGN.md) — predecessor design
- [Track 4A PIR](../tracking/2026-04-04_PPN_TRACK4_PIR.md) — side-effect boundary finding
- [Cell-Based TMS Design Note](2026-04-06_CELL_BASED_TMS_DESIGN_NOTE.md) — BSP-LE Track 1.5
- [Attribute Grammar Research](2026-04-05_ATTRIBUTE_GRAMMARS_RESEARCH.md) — theoretical foundation
- [PPN Master](../tracking/2026-03-26_PPN_MASTER.md) — series roadmap
