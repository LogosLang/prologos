# WS-Mode Integration: Full .prologos File Support

**Date**: 2026-03-04
**Status**: Complete (WS-1 through WS-5)
**Priority**: PRIMARY DESIGN TARGET

---

## Principle

`.prologos` WS-mode files are the **only user-facing syntax** for Prologos. The sexp form
is an internal intermediate representation — the WS reader desugars indentation into
s-expression-shaped syntax objects, which the parser then processes identically regardless
of input source. The sexp form is never a "target to support"; it is the IR.

All testing must validate the path that users actually use:

```
.prologos text -> WS reader -> syntax objects -> preparse -> parser -> elaborator -> type-checker
```

Tests that only exercise `process-string` with sexp strings skip the WS reader and
preparse desugaring — the most fragile part of the pipeline. This is a testing gap that
must be closed for every new language feature.

**Rule**: Every new language feature MUST have WS-mode integration tests that exercise
the full reader -> preparse -> parse -> elaborate path, in addition to any sexp-mode
unit tests. The WS-mode test is the primary correctness target; the sexp-mode test is a
convenience for testing downstream components in isolation.

---

## Architecture

The pipeline is:

```
.prologos file
    | (WS reader: indentation -> nested lists)
    v
Syntax objects (s-expr shaped, with source locations)
    | (preparse: macro expansion, WS desugaring, declaration registration)
    v
Expanded syntax objects (sentinels rewritten, declarations registered)
    | (parser: dispatch on head symbol)
    v
surf-* AST (surface syntax structs)
    | (elaborator: surf-* -> core AST)
    v
Core AST (sess-*, proc-*, expr-*)
    | (type-checker, propagators, driver)
    v
Results
```

Key architectural facts:
- The sexp reader (`process-string`) and WS reader (`process-string-ws`, `process-file`)
  converge at the "syntax objects" stage — everything downstream is identical
- The WS reader produces flat lists from indented blocks; the preparse right-folds these
  into nested forms (e.g., `desugar-session-ws`, `desugar-defproc-ws`)
- Risk area: the WS reader's output datum shape may differ from hand-constructed test datums

---

## Progress Tracker

| Phase | Status | Commit | Notes |
|-------|--------|--------|-------|
| WS-1: `process-string-ws` in driver | ✅ | `3879128` | Public export + `run-ns-ws-last`/`run-ns-ws-all` helpers |
| WS-2: Session declaration WS tests | ✅ | `8eeb81a` | 13 tests: Send/Recv/End, Choice/Offer, Mu, dependent, throws. Fixed `+>` tokenizer, `&>` preparse, DSend/DRecv binders, rec handler, branch regrouping |
| WS-3: Process definition WS tests | ✅ | `c91f5a1` | 7 tests: send+stop, send+recv+stop, select, offer branches, no annotation, both-WS session+defproc |
| WS-4: Strategy WS tests | ✅ | `c91f5a1` | 7 tests: bare default, with properties, all properties, registry verification, error cases |
| WS-5: E2E `.prologos` file tests | ✅ | `c91f5a1` | 4 tests: file loading, session registry, offer+strategy from `.prologos` files |

---

## Phase WS-1: Add `process-string-ws` to driver.rkt

**Goal**: Public function that processes a WS-mode string through the full pipeline.

Currently, `process-string` always uses the sexp reader. Three test files
(`test-functor-ws.rkt`, `test-property-ws.rkt`, `test-config-audit.rkt`) define their own
local `process-string-ws` helpers. This should be a single public function in `driver.rkt`.

```racket
(define (process-string-ws s)
  (define port (open-input-string s))
  (port-count-lines! port)
  (define raw-stxs (prologos-read-syntax-all "<ws-test>" port))
  ;; ... same pipeline as process-string from here ...
)
```

Export from driver.rkt provides.

---

## Phase WS-2: Session Declaration WS Integration Tests

**Goal**: Validate that WS-mode session syntax desugars correctly through the full pipeline.

Test cases (via `process-string-ws`):

1. **Basic Send/End**:
   ```
   session Greeting
     ! String
     end
   ```

2. **Multi-step Send/Recv/End**:
   ```
   session Echo
     ! String
     ? String
     end
   ```

3. **Choice with branches**:
   ```
   session Counter
     rec
       +>
         | :inc -> ! Nat -> rec
         | :done -> end
   ```

4. **Offer with branches**:
   ```
   session Server
     &>
       | :get -> ! String -> end
       | :put -> ? String -> end
   ```

5. **Dependent send/recv**:
   ```
   session DepSend
     !: n Nat
     end
   ```

6. **Named recursion**:
   ```
   session Loop
     rec Again
       ! Nat
       Again
   ```

7. **Throws metadata**:
   ```
   session FileAccess :throws String
     ! String
     ? String
     end
   ```

8. **Session reference / cross-reference**: define one session, use it in another context

---

## Phase WS-3: Process Definition WS Integration Tests

**Goal**: Validate that WS-mode `defproc`/`proc` bodies desugar correctly.

Test cases:

1. **Send + stop**:
   ```
   defproc greeter : Greeting
     self ! "hello"
     stop
   ```

2. **Send + recv + stop**:
   ```
   defproc echo-client : Echo
     self ! "hello"
     reply := self ?
     stop
   ```

3. **Select**:
   ```
   defproc chooser : Counter
     select self :inc
     self ! 42N
     stop
   ```

4. **Offer with branches**:
   ```
   defproc handler : Server
     offer self
       | :get ->
           self ! "hello"
           stop
       | :put ->
           data := self ?
           stop
   ```

5. **With capability binders**:
   ```
   defproc secured : S {net :0 NetCap}
     self ! "hello"
     stop
   ```

6. **Without type annotation**:
   ```
   defproc worker
     self ! "hello"
     stop
   ```

7. **Dependent send/recv operators**:
   ```
   defproc dep : S
     self !: val
     name := self ?:
     stop
   ```

8. **Link**:
   ```
   defproc forwarder
     link c1 c2
   ```

9. **Rec (tail recursion)**:
   ```
   defproc looper : Loop
     self ! 42N
     rec
   ```

---

## Phase WS-4: Strategy WS Integration Tests

1. **Default strategy**:
   ```
   strategy default
   ```

2. **With properties**:
   ```
   strategy realtime
     :fairness :priority
     :fuel 10000
   ```

3. **All properties**:
   ```
   strategy batch
     :fairness :round-robin
     :fuel 1000000
     :io :blocking-ok
     :parallelism :work-stealing
   ```

---

## Phase WS-5: End-to-End `.prologos` File Tests

Create actual `.prologos` files and load via `process-file`:

1. **`tests/ws-session-e2e-01.prologos`**: Complete session + process program
2. **`tests/ws-session-e2e-02.prologos`**: Session with throws + strategy

Test harness loads via `process-file` in an `.rkt` test file.

---

## Existing WS Test Infrastructure

| Pattern | Example | Used by |
|---------|---------|---------|
| Local `process-string-ws` | `test-functor-ws.rkt:33-42` | 3 test files |
| Temp file + `process-file` | `test-char-string.rkt` | WS char/string tests |
| `process-file` on lib `.prologos` | `test-functor-ws.rkt:80-95` | Functor WS test |

---

## Risk Areas

1. **WS reader datum grouping**: The WS reader groups by indentation. `self ! "hello"`
   should produce `(self ! "hello")` (3-element list). If the reader groups differently,
   `desugar-defproc-ws` won't recognize the pattern.

2. **`:=` binding**: `name := self ?` should produce `(name := self ?)` (4-element list).
   If `:=` is treated as a special token, grouping may differ.

3. **Branch syntax**: `$pipe` children under `offer` need correct indentation grouping.

4. **Keyword-value pairs**: Strategy properties like `:fairness :priority` must not be
   consumed by other preparse rules (e.g., implicit map syntax).

5. **Session body operators vs expression operators**: `!` and `?` are now tokenized
   correctly (S2c, commit `9f7692b`), but the WS reader's interaction with indentation
   grouping needs validation.

---

## Completion Summary

**Total new WS tests**: 31 (13 + 7 + 7 + 4)
**Full suite verification**: 5471 tests, 274 files, 0 regressions (2 pre-existing failures unrelated to WS)
**Test count**: 5440 → 5471

### Bugs Found and Fixed During WS-2

| Bug | Root Cause | Fix |
|-----|-----------|-----|
| `+>` not tokenized | `+` enters `ident-start?` but `>` not in `ident-continue?` | Added special-case handler in reader.rkt before `ident-start?` |
| `&>` produces `$clause-sep` | `&>` already tokenized for logic rules as `$clause-sep` | Updated `session-item->sexp` to match both `&>` and `$clause-sep` |
| DSend/DRecv lose type info | WS reader's `(!: n Nat)` 3-elem list vs expected `(n : Nat)` binder | Reconstructed binder form for 3-element case in `session-item->sexp` |
| `rec` handler too simplistic | Single handler couldn't distinguish named/unnamed/head/continuation contexts | Rewrote with contextual branching for all `rec` positions |
| Branch body tokens ungrouped | `flatten-arrow-chain` left operators as bare tokens: `! Nat rec` | Added `regroup-session-tokens` to reconstruct operator groups |
| `->` symbols not stripped | `flatten-arrow-chain` only handled nested `(-> ...)`, not bare `->` | Added bare symbol filtering clause |
| `rec` at continuation = new Mu | Bare `rec` in single-item position treated as Mu, not recursion variable | Special-cased single bare `rec` as pass-through symbol |
| Unnamed Mu + `rec` variable | `'rec` not in rec-stack for unnamed Mu (only `session-name` was) | Added `'rec` alias to rec-stack in elaborator |

### New Files

| File | Type | Tests |
|------|------|-------|
| `tests/test-session-ws-01.rkt` | Test | 13 |
| `tests/test-process-ws-02.rkt` | Test | 7 |
| `tests/test-strategy-ws-01.rkt` | Test | 7 |
| `tests/test-session-e2e-ws.rkt` | Test | 4 |
| `tests/ws-session-e2e-01.prologos` | E2E fixture | — |
| `tests/ws-session-e2e-02.prologos` | E2E fixture | — |

### Modified Files

| File | Changes |
|------|---------|
| `driver.rkt` | Added `process-string-ws` export |
| `reader.rkt` | Added `+>` tokenizer handler |
| `macros.rkt` | Fixed session desugaring (6 issues), added `desugar-strategy-ws`, `regroup-session-tokens` |
| `elaborator.rkt` | Added `'rec` alias in rec-stack for unnamed Mu |
| `test-support.rkt` | Added `run-ns-ws-last`, `run-ns-ws-all` helpers |
