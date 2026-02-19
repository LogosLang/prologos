# Pipe-Compose Performance Audit — Root Cause & Mitigation Plan

**Created**: 2026-02-19
**Status**: ⬚ Not Started (audit complete, fix not started)
**Purpose**: Document the root cause of `test-pipe-compose.rkt` pathological performance (>60 min, >2.4 GB RAM) and the plan to fix it.

---

## Symptom

| Metric                  | Value                                                         |
|-------------------------|---------------------------------------------------------------|
| Test file               | `tests/test-pipe-compose.rkt`                                 |
| Test count              | 69 checks                                                     |
| Runtime (alone)         | >5 min (timed out at 300s)                                    |
| Runtime (in full suite) | >60 min observed before kill                                  |
| Memory                  | >2.4 GB                                                       |
| CPU                     | 94% sustained                                                 |
| Impact                  | Blocks entire `-j 10` thread pool, making full suite unusable |

For comparison: the other 81 test files complete in ~429s total.

---

## Root Cause: Quadratic Module Reloading

### Test Structure Breakdown

| Section                   | Tests | Type                          | Speed              |
|---------------------------|-------|-------------------------------|--------------------|
| A. Reader Tokenization    | 6     | Unit (no execution)           | Instant            |
| B. Preparse Desugaring    | 8     | Unit (no execution)           | Instant            |
| C. Pipe E2E Sexp          | 5     | E2E (`run-last`)              | Expensive          |
| D. Compose E2E Sexp       | 4     | E2E (`run-last`)              | Expensive          |
| E. WS Mode E2E            | 6     | E2E (`run-ws-last`)           | Expensive          |
| F. Underscore Placeholder | 4     | Unit (preparse only)          | Instant            |
| G. Edge Cases             | 4     | Mixed (1 E2E)                 | Mixed              |
| H. Backward Compatibility | 3     | Unit (tokenization)           | Instant            |
| I. Block-Form Preparse    | 22    | Unit (preparse only)          | Instant            |
| J. Block-Form E2E Sexp    | 6     | E2E (`run-last`) + modules    | **Very expensive** |
| K. Block-Form E2E WS      | 3     | E2E (`run-ws-last`) + modules | **Very expensive** |

**43 fast tests** (sections A, B, F, G-preparse, H, I) + **26 E2E tests** (sections C, D, E, G-e2e, J, K)

### The Mechanism

Each E2E test (26 of them) calls `run` or `run-ws`, which:

```racket
(define (run s)
  (parameterize ([current-global-env (hasheq)]          ; EMPTY
                 [current-module-registry (hasheq)]     ; EMPTY
                 ...)
    (install-module-loader!)
    (process-string s)))
```

This creates a **fresh empty environment** every time. When the test string includes `require` statements (sections J, K), it triggers a full module loading cascade **from scratch**:

```
prologos.data.transducer  (94 lines)
  -> prologos.data.lseq       (38 lines)
  -> prologos.data.lseq-ops   (79 lines)
  -> prologos.data.list        (536 lines) -- THE BIG ONE
     -> prologos.core.eq-trait
     -> prologos.data.option
     -> prologos.data.nat
```

Each module load involves the **full Prologos pipeline**: parse -> elaborate -> type-check -> QTT check -> trait resolution -> reduction.

### The Math (corrected after deep investigation)

- `list.prologos` alone: 536 lines, **algebraic data type** (`data List {A} | nil | cons : A -> List A`), 93 spec/defn pairs with structural pattern matching, minimal trait usage (only `elem` uses `Eq A`)
- **8 heavy E2E tests** (J: 5, K: 3) — NOT 15. Sections C, D, E are "light" E2E (Nat builtins only, no module loads)
- **8 redundant full loads of list.prologos + transducer chain**
- Each load: ~30-60s (full 8-phase pipeline: read → preparse → parse → elaborate → type-check → QTT → trait resolution → zonk)
- Total: ~8 x 60s = **~480s minimum**, plus GC pressure from retained ASTs
- The 15 light E2E tests (C, D, E) add ~1-2s each — negligible

### Memory Consumption (2.4 GB)

- 26 independent environments: separate hashmaps for global-env, module-registry, trait-registry, impl-registry, bundle-registry, meta-store
- Retained module ASTs (expr-* nodes) in each environment
- Meta-variable stores from type inference
- Racket GC can't reclaim until test file completes

---

## What's NOT the Problem

- **List encoding is well-designed**: Algebraic data type (NOT Church-encoded), 93 functions with structural pattern matching. No encoding inefficiency.
- **Pipe/compose macros are efficient**: `expand-pipe-block`, `build-fused-reducer`, `classify-pipe-step` are all O(n) single-pass. Section I (22 preparse tests) is instant.
- **No exponential blowup in fusion**: Fused reducers are linear in step count.
- **Reader/tokenizer is fast**: Sections A, H are instant.
- **Trait constraints are minimal**: Only `elem` in 536-line list.prologos uses trait constraints (`Eq A`).
- **Type-checking pipe expressions is not the bottleneck**: The pipe expression itself is simple. The cost is in loading the modules that provide `map`, `filter`, `reduce`, etc.

---

## Deep Investigation Findings (2026-02-19)

### Corrected E2E Test Categorization

The 26 E2E tests split into two distinct cost categories:

| Category | Count | Sections | Module Loads | Cost per Test |
|----------|-------|----------|-------------|---------------|
| **Light** | 15 | C (5), D (4), E (6) | None (Nat builtins only) | ~1-2s |
| **Heavy** | 8 | J (5), K (3) | 6-7 modules each | ~30-60s |
| **Mixed** | 3 | G (1 E2E) | Minimal | ~1-2s |

Only the **8 heavy tests** cause the pathological behavior. The 15 light E2E tests use only `zero`, `suc`, and basic Nat operations — no `require` statements, no module loading.

### The Fundamental Issue: Zero Caching Architecture

Investigation of `driver.rkt` (`load-module`, lines 529-628) revealed:

1. **Module cache exists and works**: `current-module-registry` stores `module-info` structs with env-snapshots. On cache hit, it copies bindings into the caller's global-env. This is correct.

2. **Test isolation defeats the cache**: Each E2E test creates a fresh environment via `(parameterize ([current-module-registry (hasheq)] ...)`, which empties the cache. This means every test starts from zero — no cached modules.

3. **No compilation artifact cache**: The module cache stores only final environment snapshots (name→value bindings). It does NOT cache intermediate artifacts: parsed ASTs, elaborated forms, type-checked results. Every load re-runs the full 8-phase pipeline from scratch.

4. **Pipeline cost breakdown** (estimated from code inspection):

| Phase | % of Load Time | Notes |
|-------|---------------|-------|
| Type-checking | ~40-50% | Unification, occurs-check, constraint solving |
| Elaboration | ~20-30% | Pattern match compilation, implicit arg insertion |
| Trait resolution | ~5-10% | Constraint gathering + parametric instance search |
| Parsing + preparse | ~5-10% | Reader + macro expansion |
| QTT + zonk + reduction | ~10-15% | Linearity check, meta resolution, WHNF |

### Quadratic Patterns in Pipeline (future optimization targets)

These don't cause the pipe-compose issue specifically, but make each module load slower than necessary:

- **Occurs-check without memoization**: `occurs-in?` traverses full type trees repeatedly, no caching between checks
- **Repeated WHNF reduction**: `whnf` re-reduces the same terms during unification without caching results
- **Constraint retry**: Failed constraints are retried linearly against the full constraint list

### Three-Tier Improvement Plan

| Tier | Approach | Effort | Impact | Scope |
|------|----------|--------|--------|-------|
| **1** | Shared test fixture + split file | ~1-2 hours | ~8x for pipe-compose | This test only |
| **2** | Compiled module cache in driver.rkt | ~weeks | ~10x for module-heavy tests | All tests |
| **3** | Bytecode compilation (.zo-like) | ~months | ~100x | Entire language |

Tier 1 is recommended now. Tiers 2 and 3 are tracked here for future consideration.

---

## Mitigation Plan

### Recommended: Option A + B (Shared Fixture + Split File)

**Phase 1: Split the test file**

- `test-pipe-compose.rkt` -> 43 fast tests (sections A, B, F, G-preparse, H, I)
- `test-pipe-compose-e2e.rkt` -> 26 E2E tests (sections C, D, E, G-e2e, J, K)

**Phase 2: Shared fixture for E2E file**

In `test-pipe-compose-e2e.rkt`, load modules **once** at top level:

```racket
;; === Shared fixture: load modules ONCE ===
(define-values (shared-global-env shared-module-reg shared-trait-reg
                shared-impl-reg shared-param-impl-reg shared-bundle-reg)
  (parameterize ([current-global-env (hasheq)]
                 [current-module-registry (hasheq)]
                 ...)
    (install-module-loader!)
    (process-string (pipe-preamble-sexp))
    (process-string (pipe-helpers-sexp))
    (values (current-global-env) (current-module-registry)
            (current-trait-registry) (current-impl-registry)
            (current-param-impl-registry) (current-bundle-registry))))

;; Each E2E test reuses the pre-loaded environment
(define (run-with-shared s)
  (parameterize ([current-global-env shared-global-env]
                 [current-module-registry shared-module-reg]
                 [current-trait-registry shared-trait-reg]
                 [current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg]
                 [current-bundle-registry shared-bundle-reg]
                 [current-mult-meta-store (make-hasheq)])  ; Fresh per test
    (process-string s)))
```

**Risk assessment**: E2E tests appear independent (each evaluates an expression, checks the result, doesn't modify global state). The `current-mult-meta-store` must be fresh per test (type inference creates unification variables). Other registries are read-only during test evaluation.

### Expected Performance

| Scenario | Before | After |
|----------|--------|-------|
| `test-pipe-compose.rkt` (fast tests) | >60 min (mixed with E2E) | **<10s** |
| `test-pipe-compose-e2e.rkt` (shared fixture) | N/A | **30-60s** |
| Full suite (82 -> 83 files) | >60 min | **<10 min** |

### Other Options Considered

**Option C: Reduce redundant E2E tests** — Some tests are near-duplicates (`pipe-chain` vs `pipe-4-deep`, `compose-basic` vs `compose-4`). Could reduce 26 -> ~12. Lower priority since shared fixture already fixes the issue.

**Tier 2: Compiled module cache** — Add persistent compilation cache to `driver.rkt` keyed by module path + source hash. Would benefit ALL test files, not just pipe-compose. See "Three-Tier Improvement Plan" above.

**Tier 3: Bytecode compilation** — Compile `.prologos` to intermediate format skipping parse/elaborate/type-check on subsequent loads. Major investment, deferred until language stabilizes.

---

## Key Files

| Action | File |
|--------|------|
| MODIFY | `tests/test-pipe-compose.rkt` (keep fast tests, remove E2E) |
| CREATE | `tests/test-pipe-compose-e2e.rkt` (E2E with shared fixture) |
| MODIFY | `tools/dep-graph.rkt` (add `test-pipe-compose-e2e.rkt` to `test-deps`) |
| UPDATE | This tracking document |

---

## Verification Plan

1. Both files pass: `raco test tests/test-pipe-compose.rkt tests/test-pipe-compose-e2e.rkt`
2. Total test count unchanged (43 + 26 = 69)
3. `test-pipe-compose.rkt` completes in **<10s**
4. `test-pipe-compose-e2e.rkt` completes in **<120s**
5. Full suite (`raco test -j 10 tests/`) completes in **<10 min**
6. No test regressions: `raco test -j 10 prologos/tests/` all pass

---

## Implementation Log

*(To be filled during implementation)*
