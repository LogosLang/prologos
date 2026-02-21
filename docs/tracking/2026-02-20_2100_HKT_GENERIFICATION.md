# HKT-Based Whole-Library Generification

**Created**: 2026-02-20
**Research doc**: `docs/research/RESEARCH_HKT_GENERIFICATION_DESIGN.md`
**Implementation guide**: `docs/research/IMPLEMENTATION_GUIDE_GENERIFICATION.md`
**Purpose**: Enable HKT dispatch for generic collection operations; clean surface syntax with automatic trait resolution.

---

## Status Legend

- **Pending** — not yet started
- **In progress** — actively being implemented
- **Done** — implemented, tested, merged

---

## Phase Summary

| Phase | Goal | Status | Tests | Commit |
|-------|------|--------|-------|--------|
| HKT-1 | `expr-tycon` AST + normalization + trait resolution extensions | Done | 30 | — |
| HKT-2 | Kind inference from trait constraints | Done | 22 | — |
| HKT-3 | Convert Foldable/Functor to `trait`; auto-register manual dict defs in impl registry | Done | 20 | — |
| HKT-4 | Coherence rules (duplicate detection, most-specific-wins, overlap warnings) | Done | 15 | test-coherence.rkt |
| HKT-5 | Elaborator: bare method name resolution for implicit dict params | Done | 13 | test-bare-methods.rkt |
| HKT-6 | Generic ops (gmap, gfilter, gfold, etc.) + Collection bundle + prelude integration | Pending | ~30 | — |
| HKT-7 | Error messages (no-instance, kind-mismatch, ambiguity, not-in-scope) | Pending | ~12 | — |
| HKT-8 | Specialization framework (macro + registry, call-site rewriting deferred) | Pending | ~10 | — |
| HKT-9 | Constraint inference from usage (optional, feature-flagged) | Pending | ~15 | — |

**Total estimated**: ~162 tests, ~1740 lines across 9 phases

---

## Key Design Decisions

1. **`expr-tycon`**: Single new AST node representing unapplied type constructors; normalization layer converts built-in types to `expr-app`/`expr-tycon` form in unifier
2. **Kind inference**: Pre-parse time propagation from trait params to brace params in `process-spec`
3. **Coherence**: Duplicate detection as error, most-specific-wins for parametric, orphan as warning
4. **Naming**: `Collection` bundle (not `Seq`); `gmap`/`gfilter`/`gfold` prefix for generic ops
5. **Map integration**: Partial application via `expr-tycon` — `Map K` = `(expr-app (expr-tycon 'Map) K)` with kind `Type -> Type`
6. **Specialization**: Registry-based, deferred call-site rewriting; users can always use Tier 2 ops for zero overhead
7. **Constraint inference**: Deferred behind feature flag; method-triggered constraint generation algorithm designed

---

## Critical Path

```
HKT-1 → HKT-2 → HKT-3 → HKT-5 → HKT-6 (critical path)
                    │
                    └── HKT-4 (parallel with HKT-5)
                              HKT-6 → HKT-7 (parallel with HKT-8)
                              HKT-5 → HKT-9 (independent)
```

---

## Files to Modify (Summary)

### Racket source (racket/prologos/)
- `syntax.rkt` — `expr-tycon` struct, kind table, provide
- `substitution.rkt` — identity case
- `zonk.rkt` — identity cases (3 variants)
- `typing-core.rkt` — infer kind from table
- `qtt.rkt` — return `'m0`
- `reduction.rkt` — identity (normal form)
- `pretty-print.rkt` — symbol→string
- `unify.rkt` — normalization + tycon decomposition
- `trait-resolution.rkt` — key-str, match-one, ground-expr?, resolve normalize
- `macros.rkt` — kind propagation, impl extensions, coherence, specialize macro
- `elaborator.rkt` — where-context for implicit dicts, constraint inference
- `namespace.rkt` — prelude additions

### Library (.prologos) files to create
- `lib/prologos/core/collection-bundle.prologos`
- `lib/prologos/core/generic-ops.prologos`
- `lib/prologos/core/seqable-map.prologos`

### Library (.prologos) files to modify
- `lib/prologos/core/foldable-trait.prologos` — deftype → trait
- `lib/prologos/core/functor-trait.prologos` — deftype → trait (if exists)
- ~14 trait instance files — manual `def` → proper `impl`

### Test files to create
- `tests/test-tycon.rkt` (~20 tests)
- `tests/test-kind-inference.rkt` (~15 tests)
- `tests/test-hkt-impl.rkt` (~25 tests)
- `tests/test-coherence.rkt` (~15 tests)
- `tests/test-bare-methods.rkt` (~20 tests)
- `tests/test-generic-ops.rkt` (~30 tests)
- `tests/test-hkt-errors.rkt` (~12 tests)
- `tests/test-specialization.rkt` (~10 tests)
- `tests/test-constraint-inference.rkt` (~15 tests)
