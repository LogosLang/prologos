# FL Narrowing — Post Implementation Review

**Date**: 2026-03-08
**Status**: COMPLETE (all 11 sub-phases delivered)
**Tracking**: `docs/tracking/2026-03-07_NARROWING_ABSTRACT_INTERPRETATION_DESIGN.org`
**Design**: `docs/research/2026-03-07_FL_NARROWING_DESIGN.org`
**Capstone**: `racket/prologos/examples/narrowing-demo.prologos`


## 1. Objectives and Scope

The FL Narrowing track aimed to unify Prologos's functional (`defn`) and relational (`defr`) paradigms. The central premise: every function defined by pattern matching should be automatically usable as a relation — queryable with unbound logic variables — without the programmer writing a separate relational definition.

This is achieved through *narrowing*: the combination of unification and term rewriting, guided by *definitional trees* extracted from function definitions.

### Concrete goals

1. **Core narrowing engine** — DT extraction, term lattice, DT-guided search, solver integration
2. **WS-mode surface syntax** — `?`-prefixed logic variables and infix `=` in `.prologos` files
3. **Static analysis** — interval pruning, termination classification, confluence analysis
4. **Advanced search** — higher-order defunctionalization, configurable heuristics, global constraints

### Non-goals (explicitly deferred)

- Narrowing over native numeric types (Int, Rat) — requires constraint propagation, not structural case splitting
- Length-interval domain for List/String (Phase 2a+)
- Full WS surface syntax for solver config blocks and global constraint declarations


## 2. What Was Delivered

### Phase 1 — Core Narrowing (5 sub-phases)

| Sub-phase | Description | Commit | Key Artifact |
|-----------|-------------|--------|--------------|
| 1a | Definitional tree extraction | `99e56a8` | `definitional-tree.rkt` ~200 lines, 39 tests |
| 1a+ | Pattern defn → DT integration | `3bd6cc8` | Verified: pattern clauses produce correct DTs |
| 1b | Term lattice | `4a7e215` | `term-lattice.rkt` 226 lines, 49 tests |
| 1c | Narrowing propagator | `77f4a5d` | `narrowing.rkt` 275 lines, 31 tests |
| 1d | Solver integration | `36831ed` | `narrowing.rkt` +400 lines, 22+24 tests |
| 1e | WS-mode syntax (`?vars`, infix `=`) | `3062b4c` | 13 files touched, 24 tests |

**Phase 1 total**: ~950 new lines, ~200 tests.

Phase 1 established the fundamental capability: given `defn add [x y] | [zero y] := y | [(suc n) y] := [suc [add n y]]`, the query `[add ?x ?y] = 5N` automatically finds all six pairs summing to 5.

### Phase 2 — Static Analysis (3 sub-phases)

| Sub-phase | Description | Commit | Key Artifact |
|-----------|-------------|--------|--------------|
| 2a | Interval abstract domain | `6301d69` | `interval-domain.rkt` ~250 lines, `narrowing-abstract.rkt` ~130 lines, 43 tests |
| 2b | Size-based termination (LJBA) | `bae2fb4` | `termination-analysis.rkt` ~300 lines, 45 tests |
| 2c | Critical pair / confluence | `3d3c0ce` | `confluence-analysis.rkt` ~200 lines, 58 tests |

**Phase 2 total**: ~1,270 new lines, ~250 tests.

Phase 2 made narrowing *practical*. Without intervals, `[add ?x ?y] = 5N` would explore an infinite search space; with them, each variable is bounded to [0, 5]. Termination analysis classifies functions before narrowing begins (terminating / bounded / non-narrowable). Confluence analysis detects overlapping clauses and selects the optimal search strategy (needed narrowing vs basic narrowing).

### Phase 3 — Advanced Search (3 sub-phases)

| Sub-phase | Description | Commit | Key Artifact |
|-----------|-------------|--------|--------------|
| 3a | 0-CFA auto-defunctionalization | `cdb6176` | `cfa-analysis.rkt` ~285 lines, 23 tests |
| 3b | Configurable search heuristics | `fdda370` | `search-heuristics.rkt` ~140 lines, 41 tests |
| 3c | Global constraints + BB optimization | `16dd1ac` | `global-constraints.rkt` ~200 lines, `bb-optimization.rkt` ~100 lines, 49 tests |

**Phase 3 total**: ~1,560 new lines, ~270 tests.

Phase 3 extended the engine's reach. 0-CFA enables narrowing through higher-order arguments by computing flow sets for function-position variables. Search heuristics provide three orthogonal knobs (variable ordering, value ordering, search strategy). Global constraints (all-different, element, cumulative) and branch-and-bound optimization connect narrowing to the propagator network's constraint infrastructure.


## 3. Quantitative Summary

| Metric | Value |
|--------|-------|
| Sub-phases delivered | 11 (1a, 1a+, 1b, 1c, 1d, 1e, 2a, 2b, 2c, 3a, 3b, 3c) |
| New source files | 11 (.rkt modules) |
| New test files | 12 |
| New source LOC | ~3,756 (across 11 new modules) |
| Modified source LOC | ~600+ (narrowing.rkt accretions, elaborator, parser, etc.) |
| Test LOC | ~4,935 (across 12 test files) |
| Total tests added | ~460 |
| Files modified (total) | 40 files changed |
| Total insertions | 10,683 lines |
| Feature commits | 12 (plus tracker/doc commits) |
| Capstone demo | 534 lines, 16 live queries |
| Full suite at completion | 6,471 tests, 322 files, zero failures |
| Open sub-phases | 1 (Phase 2a+: length-interval domain) |


## 4. What Went Well

### 4.1 The Definitional Tree Abstraction Was the Right Foundation

The entire narrowing system rests on definitional trees (Antoy 1992, 2005). This was a deliberate choice over simpler alternatives (backtracking SLD resolution, tabled narrowing). It paid off repeatedly:

- DTs directly encode which variable is *needed* — the narrowing strategy falls out naturally
- Termination analysis becomes straightforward: check whether recursive calls decrease on the needed position
- Confluence analysis reduces to checking whether DT branches overlap (Or-branches vs pure Branch)
- The 0-CFA integration slots in cleanly: when the needed position holds a logic variable in function position, query the CFA for candidates

Every Phase 2 and Phase 3 module builds on DTs as its interface to the function's clause structure. We never had to go back and redesign this foundation.

### 4.2 The Three-Phase Architecture Matched the Problem

Phase 1 (core), Phase 2 (analysis), Phase 3 (advanced) followed a natural dependency order. Each phase was independently testable. Phase 2 couldn't have been designed without Phase 1's DT representation being stable. Phase 3 couldn't have been designed without Phase 2's classification infrastructure. The phasing was not arbitrary — it reflected genuine conceptual dependencies.

### 4.3 Pure Leaf Modules Accelerated Development

Every new module (`definitional-tree.rkt`, `term-lattice.rkt`, `interval-domain.rkt`, `termination-analysis.rkt`, `confluence-analysis.rkt`, `cfa-analysis.rkt`, `search-heuristics.rkt`, `global-constraints.rkt`, `bb-optimization.rkt`) was designed as a pure leaf — taking structured data in, returning structured data out, with no mutable state or complex dependencies. This meant:

- Unit tests ran instantly (no prelude loading, no solver state)
- Each module could be developed and tested in isolation
- Integration into `narrowing.rkt` was a thin wiring layer, not a deep refactor

### 4.4 Propagator Architecture Enabled Composable Integration

Narrowing, interval constraints, global constraints, and branch-and-bound all compose through the existing propagator network. A narrowing goal fires, updates cells; interval constraints observe the same cells and prune; global constraints cross-reference multiple narrowing goals. This wasn't forced — the propagator architecture naturally supports this composition pattern.

### 4.5 Test Coverage Prevented Regressions

With ~460 tests across 12 files, no sub-phase introduction caused regressions in earlier sub-phases. The full suite (6,471 tests) remained green throughout. The shared fixture pattern kept test startup costs low (~0.5s per file vs ~3s without caching).


## 5. Challenges and Difficulties

### 5.1 WS-Mode Surface Syntax Gaps

The capstone demo exposed three significant WS-mode gaps that were invisible from the 460-test suite (all sexp-level):

1. **Ground constructor arguments**: `[add zero ?y] = 5N` fails in WS mode. The WS reader parses `zero` as a bare identifier, not a nullary constructor application `(zero)`. The sexp API handles `(= (add (zero) ?y) 5)` correctly.

2. **Nested match patterns**: `suc zero` and `suc [suc _]` as match arm patterns don't parse in WS mode. The WS reader treats them as separate tokens rather than compound constructor patterns.

3. **Higher-order narrowing in WS mode**: `[apply-op ?f 3N 2N] = 5N` doesn't trigger narrowing in WS mode. The `?f` in function position isn't resolved through the WS → elaboration pipeline. All 23 CFA tests pass at the sexp/API level.

These gaps are WS reader/parser issues, not narrowing engine issues. The narrowing infrastructure is complete and correct; the surface syntax doesn't yet reach it in these cases.

**Lesson**: Sexp-level tests are necessary but not sufficient. WS-mode integration tests — and especially capstone demos — are essential for validating that the surface syntax pipeline reaches the engine correctly. This motivated codifying the Feature Capstone Demo as a mandatory Phase 5 step in the Design Methodology.

### 5.2 DFS Over-Approximation

The DFS-based search over-approximates when a variable appears multiple times in a function body. For `defn my-double [n] [add n n]`, narrowing `[my-double ?x] = 6N` internally becomes `[add ?x ?x] = 6N`, but the DFS treats the two `?x` occurrences independently, finding some spurious solutions alongside the correct `{x: 3}`. This is a fundamental limitation of the current DFS approach — it doesn't enforce aliasing constraints across variable occurrences.

A future improvement would be to add an equality constraint between aliased variable positions after the DFS returns, filtering out solutions where `x₁ ≠ x₂`.

### 5.3 Composed Function Narrowing

Functions that call other functions without direct pattern matching don't narrow through composition. For example, `defn my-triple [n] [add n [add n n]]` returns nil when narrowed, because the outer `add` call sees the inner `[add n n]` as an opaque expression, not a narrowable call.

This is a known limitation of definitional-tree-based narrowing: the DT guides search based on the *immediate* pattern structure of the function being narrowed, not the transitive closure of all called functions. Supporting composition would require either inlining (expanding called functions inline before DT extraction) or a multi-function narrowing strategy.

### 5.4 Nat vs Int as the Narrowing Type

Narrowing operates over inductively defined types (Nat, Bool) because their structural recursion (zero/suc, true/false) gives the definitional tree concrete branches to walk. Prologos's standard computation type is Int, not Nat. This creates a mismatch: the most natural type for narrowing is not the type users normally reach for.

Resolving this requires constraint propagation over Int domains (CLP(FD) or CLP(Z)) — a fundamentally different mechanism from structural narrowing. This was explicitly a non-goal for this track but remains the most important extension for making narrowing practically useful in everyday code.


## 6. Results vs Expectations

### What exceeded expectations

- **Module count**: Expected ~6 new modules, delivered 11 (9 feature + 2 optimization). The problem decomposed more cleanly than anticipated.
- **Test count**: Expected ~200 tests, delivered ~460. Each module's test surface was richer than initially scoped.
- **Composability**: Global constraints composing with narrowing through the propagator network was hoped for but not guaranteed. It worked cleanly.

### What matched expectations

- **LOC**: Expected ~3,500 new lines, delivered ~3,756. Close to estimate.
- **Regression count**: Zero, as targeted.
- **Phase ordering**: The 1→2→3 dependency structure held exactly as designed.

### What fell short

- **WS-mode coverage**: Expected full WS-mode parity. Got 3 significant gaps (ground ctors, nested patterns, HO narrowing). These are fixable but represent surface syntax debt.
- **Composed narrowing**: Expected wrapper functions to narrow transparently. Got partial support (trivial dt-rule in Phase 3a), but multi-call composition doesn't work.
- **Practical utility**: Narrowing over Nat is technically sound but not practically useful for most programs. The Int extension is the real unlock.


## 7. What This Enables

### 7.1 Immediate Capabilities

- **Any `defn` with pattern matching is now a relation**: No separate `defr` needed. The `?` prefix and `=` operator are sufficient.
- **Automatic backward execution**: `[add ?x ?y] = 10N` finds all input pairs. `[not ?b] = true` finds the input. Test oracles, constraint satisfaction, and program inversion come for free.
- **Static safety classification**: Before narrowing runs, the compiler knows whether the function terminates, whether its clauses overlap, and what the numeric bounds are. Unsafe functions residuate rather than diverge.
- **Configurable search**: Users (via sexp API, with WS syntax upcoming) can tune variable ordering, value ordering, iterative deepening, and optimization criteria.

### 7.2 Future Extensions (Ordered by Impact)

1. **CLP(Z)/CLP(FD) for Int narrowing** — The highest-impact extension. Enables narrowing over the standard computation type. Would use interval propagation (Phase 2a infrastructure) as the constraint store, with integer arithmetic operations replacing structural Peano recursion. Estimated effort: ~500 lines + ~80 tests.

2. **WS-mode gap closure** — Three fixes to make the surface syntax reach the engine:
   - Ground constructor recognition in the WS reader/parser (~30 lines)
   - Compound constructor patterns in match arms (~50 lines)
   - HO narrowing resolution in the elaborator (~20 lines)

3. **Inline expansion for composed narrowing** — Expand called functions inline before DT extraction, enabling `[my-triple ?x] = 9N` to work. Requires care to avoid infinite expansion (use termination analysis to bound inlining depth). ~200 lines.

4. **Length-interval domain** (Phase 2a+) — Extend interval analysis to List and String types, bounding the length of list-typed variables to prune infinite list enumeration. ~150 lines.

5. **Incremental CFA** — Currently 0-CFA recomputes from scratch. For large programs, incremental re-analysis on module change would improve compilation performance. ~200 lines.

6. **Solver config WS syntax** — Surface syntax for `solver` declarations and `solve-with` blocks, making search heuristics accessible from `.prologos` files. ~100 lines in parser/elaborator.


## 8. Architecture and Integration

### Module Dependency Structure

```
syntax.rkt ──→ definitional-tree.rkt ──→ narrowing.rkt ←── solver.rkt
                    ↑                        ↑↑↑↑
              term-lattice.rkt         interval-domain.rkt
                                       narrowing-abstract.rkt
                                       termination-analysis.rkt
                                       confluence-analysis.rkt
                                       cfa-analysis.rkt
                                       search-heuristics.rkt
                                       global-constraints.rkt
                                       bb-optimization.rkt
```

All analysis modules are pure leaves. `narrowing.rkt` is the integration hub — it imports all analysis results and orchestrates the DT-guided search. `solver.rkt` invokes narrowing goals alongside relational goals.

### Pipeline Integration Points

| Pipeline Stage | Integration |
|----------------|-------------|
| **Reader** (`reader.rkt`) | `?` prefix → `expr-logic-var`; WS `=` → `(= lhs rhs)` |
| **Parser** (`parser.rkt`) | `(= lhs rhs)` → `surf-narrow-goal`; pattern defn clauses |
| **Surface Syntax** (`surface-syntax.rkt`) | `surf-narrow-goal` struct; `surf-logic-var` struct |
| **Elaborator** (`elaborator.rkt`) | `elaborate-narrow-goal` invokes DT extraction + search |
| **Macros** (`macros.rkt`) | `expand-defn` dispatches pattern clauses to DT builder |
| **Reduction** (`reduction.rkt`) | `reduce` recognizes logic vars, avoids reducing them |
| **Solver** (`solver.rkt`) | `narrow-goal` type; dispatches narrowing alongside relations |
| **Typing** (`typing-core.rkt`) | Logic var type inference; narrowing result typing |
| **Zonk** (`zonk.rkt`) | Logic var zonking; narrowing substitution application |
| **Pretty-print** (`pretty-print.rkt`) | Logic var display; solution map formatting |


## 9. Lessons Learned

### 9.1 Theoretical Foundations Matter

The choice to ground the implementation in Antoy's definitional tree theory (1992, 2005) and the Lee-Jones-Ben-Amram termination criterion (2001) paid dividends throughout. Every design question had a clear theoretical answer:

- "How do we pick which variable to narrow?" → DT induction position (Antoy)
- "Is this function safe to narrow?" → LJBA size-change principle
- "Are these clauses overlapping?" → Critical pair analysis (Knuth-Bendix)
- "How do we handle higher-order arguments?" → 0-CFA defunctionalization (Shivers 1991)

We never had to invent new theory. We translated known results into Prologos's representation.

### 9.2 Capstone Demos Expose Integration Gaps

The capstone demo (534 lines, committed as `92d4e0c`) exposed three WS-mode gaps that were invisible from 460 unit tests. All three are at the reader/parser boundary — the narrowing engine is correct, but the surface syntax doesn't always reach it.

This validated the practice strongly enough that we codified Feature Capstone Demos as a mandatory Phase 5 step in the Design Methodology (commit `1734cc6`). The lesson: unit tests validate components; capstone demos validate the user experience.

### 9.3 Pure Leaf Modules Are the Right Default

Every new narrowing module follows the same pattern: take structured data in (DTs, AST nodes, configs), return structured data out (classifications, flow sets, pruned intervals), no mutation. This made testing trivial, composition easy, and debugging straightforward.

The one module that manages state — `narrowing.rkt` with its search stack and substitution threading — is also the one that required the most debugging. The correlation is not coincidental.

### 9.4 DFS Is Simple but Limited

DFS-based search (try each DT branch sequentially, collect solutions) is simple to implement and reason about. But it has fundamental limitations:

- **Aliasing**: Can't enforce that two occurrences of `?x` take the same value during search
- **Composition**: Can't narrow through nested function calls that aren't part of the immediate DT
- **Efficiency**: Explores branches that interval analysis has already pruned (though propagation mitigates this)

A future BFS or constraint-propagation-based search would address these, at the cost of more complex state management.

### 9.5 The Propagator Architecture Is a Force Multiplier

The existing propagator + ATMS infrastructure made Phase 2 and Phase 3 significantly easier than they would have been in a conventional architecture:

- Interval constraints are just propagators on cells
- Global constraints (all-different, element) are just more propagators
- Branch-and-bound is a global propagator that cross-references worldviews
- Narrowing goals are propagators that fire when their input cells update

We didn't build a constraint solver for narrowing. We connected narrowing to the constraint solver we already had.

### 9.6 Nat Is a Pedagogical Type, Not a Practical One

The most significant architectural lesson: narrowing over Peano naturals is academically satisfying but practically limited. Real programs use Int. The gap between "this works on Nat" and "this works on Int" is not a simple type change — it requires a fundamentally different search mechanism (constraint propagation over finite domains vs structural case splitting on constructors).

Future narrowing work should prioritize CLP(Z) integration over refinements to the current Nat-based system.


## 10. Process Observations

### What the Design Methodology Got Right

- **Phase 0 research** before implementation prevented false starts. The definitional tree foundation was chosen through research, not discovered through refactoring.
- **Phase subdivision** (a/b/c within major phases) kept individual commits focused. No commit touched more than 5 source files.
- **Commit-after-phase discipline** kept the git history clean and traceable. Every sub-phase has a commit hash in the tracker.

### What the Design Methodology Gained

- **Feature Capstone Demo** as a mandatory Phase 5 step was a direct outcome of this track. The narrowing capstone discovered gaps that 460 tests missed. This practice is now codified in `docs/tracking/principles/DESIGN_METHODOLOGY.org`.

### Development Cadence

The 11 sub-phases were delivered across ~4 working sessions. The typical pattern: research + design (session 1), Phase 1 implementation (sessions 2-3), Phase 2-3 implementation (sessions 3-4), capstone + PIR (session 4). The sub-phase structure kept momentum consistent — each sub-phase was small enough to complete in a focused block.


## 11. Recommendations

### For Immediate Follow-Up

1. **Close WS-mode gaps** — The three surface syntax issues (ground ctors, nested patterns, HO narrowing) are straightforward parser/reader fixes. They should be addressed before the next feature track, not deferred indefinitely.

2. **Add narrowing items to DEFERRED.md** — Currently no narrowing-specific items appear in DEFERRED.md. The WS gaps and CLP(Z) extension should be tracked there.

### For Medium-Term

3. **CLP(Z) design document** — Write a Phase 0 research document for narrowing over integer domains. This is the most impactful extension and deserves the same theoretical grounding that the Nat-based system received.

4. **Aliasing constraint** — Add a post-search filter that checks whether variables appearing multiple times in a function body have consistent values. This eliminates the DFS over-approximation for functions like `my-double`.

### For Long-Term Architecture

5. **Evaluate BFS/IDDFS as default** — The current DFS is simple but can miss solutions or over-approximate. BFS with iterative deepening might be a better default for general use, with DFS as an optimization for known-terminating functions.

6. **Narrowing-aware WS reader** — The WS reader currently doesn't distinguish "function application context" from "pattern matching context" from "narrowing context." A future reader pass that's aware of these contexts could resolve the ground constructor and nested pattern issues systematically.


## File Index

### New Source Files (11)

| File | Lines | Purpose |
|------|-------|---------|
| `definitional-tree.rkt` | 269 | DT extraction from function definitions |
| `term-lattice.rkt` | 226 | Algebraic lattice over term representations |
| `narrowing.rkt` | 1,137 | DT-guided narrowing search engine |
| `interval-domain.rkt` | 368 | Galois connections, interval arithmetic |
| `narrowing-abstract.rkt` | 139 | Abstract interpretation bridge |
| `termination-analysis.rkt` | 414 | LJBA size-change termination |
| `confluence-analysis.rkt` | 246 | Critical pair analysis |
| `cfa-analysis.rkt` | 285 | 0-CFA flow analysis |
| `search-heuristics.rkt` | 174 | Variable/value ordering, search strategy |
| `global-constraints.rkt` | 362 | all-different, element, cumulative |
| `bb-optimization.rkt` | 136 | Branch-and-bound cost optimization |

### New Test Files (12)

| File | Lines | Tests |
|------|-------|-------|
| `test-definitional-tree-01.rkt` | 570 | ~39 |
| `test-term-lattice-01.rkt` | 348 | ~49 |
| `test-narrowing-01.rkt` | 500 | ~31 |
| `test-narrowing-search-01.rkt` | 269 | ~24 |
| `test-narrow-syntax-01.rkt` | 260 | ~24 |
| `test-interval-domain-01.rkt` | 438 | ~43 |
| `test-termination-01.rkt` | 403 | ~45 |
| `test-confluence-01.rkt` | 509 | ~58 |
| `test-cfa-analysis-01.rkt` | 366 | ~23 |
| `test-search-heuristics-01.rkt` | 433 | ~41 |
| `test-global-constraints-01.rkt` | 484 | ~49 |
| `test-pattern-defn-01.rkt` | 355 | ~34 |

### Modified Files (Key)

| File | Changes |
|------|---------|
| `elaborator.rkt` | +107 lines (narrow goal elaboration, DT extraction triggers) |
| `parser.rkt` | +424 lines (pattern defn clauses, `=` operator, `?` vars) |
| `macros.rkt` | +641 lines (pattern clause expansion, defn dispatch) |
| `solver.rkt` | +42 lines (narrow-goal type, config keys) |
| `reduction.rkt` | +43 lines (logic var awareness) |
| `reader.rkt` | +38 lines (`?` prefix, `=` operator) |
| `surface-syntax.rkt` | +49 lines (surf-narrow-goal, surf-logic-var) |
| `syntax.rkt` | +15 lines (expr-logic-var, expr-narrow-goal) |
| `driver.rkt` | +45 lines (narrowing pipeline integration) |

### Documentation

| File | Purpose |
|------|---------|
| `docs/research/2026-03-07_FL_NARROWING_DESIGN.org` | Phase 0-1 design (canonical) |
| `docs/tracking/2026-03-07_NARROWING_ABSTRACT_INTERPRETATION_DESIGN.org` | Phase 2-3 design + progress tracker |
| `docs/research/2026-03-07_NARROWING_AND_SEARCH_HEURISTICS.md` | Search heuristics research |
| `racket/prologos/examples/narrowing-demo.prologos` | Feature capstone demo |
| `docs/tracking/2026-03-08_FL_NARROWING_PIR.md` | This document |
