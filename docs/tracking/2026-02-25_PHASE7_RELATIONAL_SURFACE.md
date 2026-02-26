# Phase 7: Relational Language Surface Syntax

**Date**: 2026-02-25
**Status**: COMPLETE

## Summary

Implemented the user-facing relational language, making logic programming a
first-class paradigm in Prologos. This is the capstone phase of the Logic
Engine, bridging the relational world (`defr`, `&>`, `||`, `(...)`) to the
functional world (`defn`, `fn`, `[...]`) via `solve`/`explain`.

## Architecture

### Design Decisions
- **Dual clause sigils**: `||` for facts (ground data), `&>` for rules (goals)
- **Bare-name logic variables**: Mode annotations (`?`/`+`/`-`) in signatures only
- **Mode conventions**: `+` = input, `-` = output, `?` = free (Prolog/Mercury standard)
- **Multi-arity `|` dispatch**: Each variant has own params + body (reuses `defn` pattern)
- **Solve/Explain split**: `solve` -> bare bindings; `explain` -> bindings + provenance
- **Type-unsafe returns**: `expr-hole` for solve/explain (matching tabling pattern)

### Sub-phases

| Phase | Description | Status |
|-------|-------------|--------|
| 7a | Racket-level runtime (solver, relations, stratify, provenance) | DONE |
| 7b | Reader token changes (`||` -> `$facts-sep`, `&>` -> `$clause-sep`) | DONE |
| 7c | Surface syntax + Parser + Macros (19 surf-* structs) | DONE |
| 7d | Core AST + Mechanical traversals (26 structs, 6 files) | DONE |
| 7e | Type rules + QTT (typing-core, qtt) | DONE |
| 7f | Elaboration (surf-* -> expr-* in elaborator) | DONE |
| 7g | Reduction rules (whnf/nf structural self-values) | DONE |
| 7h | Integration tests + cleanup (grammar, dep-graph, tracking) | DONE |

### AST Nodes (26)
- Relational core (14): defr, defr-variant, rel, clause, fact-block, fact-row,
  goal-app, logic-var, unify-goal, is-goal, not-goal, relation-type, schema, schema-type
- Solve family (4): solve, solve-with, solve-one, goal-type
- Explain family (2): explain, explain-with
- Solver config (2): solver-config, solver-type
- Answer + provenance (2): answer-type, derivation-type
- Control (2): cut, guard

## Files Created/Modified

### New Files (11)
- `solver.rkt` — Solver configuration (map-backed, merge, accessors)
- `relations.rkt` — Relation registration, goal solving, answer projection
- `stratify.rkt` — Tarjan SCC + stratification check
- `provenance.rkt` — Answer records, derivation trees
- `tests/test-solver-config.rkt` — 13 tests
- `tests/test-relations-runtime.rkt` — 15 tests
- `tests/test-stratify.rkt` — 10 tests
- `tests/test-provenance.rkt` — 8 tests
- `tests/test-reader-relational.rkt` — 10 tests
- `tests/test-parser-relational.rkt` — 22 tests
- `tests/test-relational-types.rkt` — 62 tests

### Modified Files (14)
- `reader.rkt` — `||` and `&>` tokenization (WS mode)
- `sexp-readtable.rkt` — `||` and `&>` tokenization (sexp mode)
- `surface-syntax.rkt` — 19 new surf-* structs
- `parser.rkt` — Keywords, dispatch, parse functions
- `macros.rkt` — defr/solver/schema pre-parse handlers
- `syntax.rkt` — 26 new expr-* structs + provide + is-value?
- `substitution.rkt` — shift + subst clauses
- `zonk.rkt` — zonk, zonk-at-depth, default-metas clauses
- `pretty-print.rkt` — pp-expr + uses-bvar0? clauses
- `unify.rkt` — unify-head-str clauses
- `trait-resolution.rkt` — expr->impl-key-str clauses
- `typing-core.rkt` — infer, check, infer-level clauses
- `qtt.rkt` — inferQ, checkQ clauses
- `reduction.rkt` — whnf + nf clauses
- `elaborator.rkt` — surf-* -> expr-* elaboration + elaborate-top-level
- `driver.rkt` — defr top-level processing

### Doc/Tool Updates
- `docs/spec/grammar.ebnf` — Section 5.28 + operator desugaring
- `docs/spec/grammar.org` — Type atoms + relational language section
- `tools/dep-graph.rkt` — 7 new test entries
- `docs/tracking/DEFERRED.md` — Phase 7 marked COMPLETE

## Test Count
- Phase 7-specific tests: 140 (across 7 test files)
- Full suite: 4149 tests in 189 files, all pass (no regressions)
- Slowest file: test-transducer.rkt at 18.0s (no whale files)

## Key Lessons
- Both readtables (WS + sexp) need matching token changes for `||` and `&>`
- Type constructor atoms in bare position go through `parse-symbol`, not keyword dispatch
- Parser errors propagate to top level (test expectations need `prologos-error?` at outer level)
- `inferQ` for runtime wrappers (solver-config) should return type directly, not recurse
