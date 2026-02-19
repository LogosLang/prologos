# Pipe-Compose Performance Audit — Root Cause & Mitigation Plan

**Created**: 2026-02-19
**Status**: ⬚ Not Started (audit complete, fix not started)
**Purpose**: Document the root cause of `test-pipe-compose.rkt` pathological performance (>60 min, >2.4 GB RAM) and the plan to fix it.

---

## Symptom

| Metric | Value |
|--------|-------|
| Test file | `tests/test-pipe-compose.rkt` |
| Test count | 69 checks |
| Runtime (alone) | >5 min (timed out at 300s) |
| Runtime (in full suite) | >60 min observed before kill |
| Memory | >2.4 GB |
| CPU | 94% sustained |
| Impact | Blocks entire `-j 10` thread pool, making full suite unusable |

For comparison: the other 81 test files complete in ~429s total.

---

## Root Cause: Quadratic Module Reloading

### Test Structure Breakdown

| Section | Tests | Type | Speed |
|---------|-------|------|-------|
| A. Reader Tokenization | 6 | Unit (no execution) | Instant |
| B. Preparse Desugaring | 8 | Unit (no execution) | Instant |
| C. Pipe E2E Sexp | 5 | E2E (`run-last`) | Expensive |
| D. Compose E2E Sexp | 4 | E2E (`run-last`) | Expensive |
| E. WS Mode E2E | 6 | E2E (`run-ws-last`) | Expensive |
| F. Underscore Placeholder | 4 | Unit (preparse only) | Instant |
| G. Edge Cases | 4 | Mixed (1 E2E) | Mixed |
| H. Backward Compatibility | 3 | Unit (tokenization) | Instant |
| I. Block-Form Preparse | 22 | Unit (preparse only) | Instant |
| J. Block-Form E2E Sexp | 6 | E2E (`run-last`) + modules | **Very expensive** |
| K. Block-Form E2E WS | 3 | E2E (`run-ws-last`) + modules | **Very expensive** |

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

### The Math

- `list.prologos` alone: 536 lines of Church-encoded List with fold/map/filter/reverse/partition/zip + trait constraints + pattern matching
- ~15 heavy E2E tests (J, K, plus some C-E with simple nat-only loads)
- **~15 redundant full loads of list.prologos + transducer chain**
- Each load: ~30-60s (parse + elaborate + type-check 536 lines)
- Total: ~15 x 60s = **~900s minimum**, plus GC pressure from retained ASTs

### Memory Consumption (2.4 GB)

- 26 independent environments: separate hashmaps for global-env, module-registry, trait-registry, impl-registry, bundle-registry, meta-store
- Retained module ASTs (expr-* nodes) in each environment
- Meta-variable stores from type inference
- Racket GC can't reclaim until test file completes

---

## What's NOT the Problem

- **Pipe/compose macros are efficient**: `expand-pipe-block`, `build-fused-reducer`, `classify-pipe-step` are all O(n) single-pass. Section I (22 preparse tests) is instant.
- **No exponential blowup in fusion**: Fused reducers are linear in step count.
- **Reader/tokenizer is fast**: Sections A, H are instant.
- **Type-checking pipe expressions is not the bottleneck**: The pipe expression itself is simple. The cost is in loading the modules that provide `map`, `filter`, `reduce`, etc.

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

**Option D: Module caching across tests** — Make `load-module` support a precompiled module cache. Would benefit all test files, not just pipe-compose. Medium-term optimization, worth investigating separately.

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
