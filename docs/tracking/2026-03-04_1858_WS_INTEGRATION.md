# WS-Mode Integration: Full .prologos File Support

**Date**: 2026-03-04
**Status**: In progress
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
| WS-1: `process-string-ws` in driver | ☐ | | Public export for WS-mode string processing |
| WS-2: Session declaration WS tests | ☐ | | Send/Recv/End, Choice/Offer, Mu, dependent, throws |
| WS-3: Process definition WS tests | ☐ | | send/recv/stop, select, offer, caps, boundary ops |
| WS-4: Strategy WS tests | ☐ | | keyword-value property blocks |
| WS-5: E2E `.prologos` file tests | ☐ | | Full session program in `.prologos` via `process-file` |

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
