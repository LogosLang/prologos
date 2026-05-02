# Gate 3 — String / Bytes / Char Domain
**Date**: 2026-05-02
**Status**: Design (rev 1.0, compile-time-only variant)
**Branch**: `lowering-yolo`
**Predecessor**: [`2026-05-02_LOWERING_INVENTORY.md`](2026-05-02_LOWERING_INVENTORY.md)

## 1. Motivation

Day-0 inventory bucketed 5 files as GATE3_STRING but on inspection
*none* were actual lowering failures — they were elaboration failures
(unknown relation, missing module, mixfix parse) that just happened
to use `str::` symbols. So the actual gap on the existing corpus is
zero.

That said, real Prologos programs use strings (filenames, error
messages, lookup keys, …), and the eventual self-hosting compiler
will need them. Gate 3 ships the smallest useful piece.

## 2. Constraint: Prologos strings are foreign Racket procedures

All string ops in `racket/prologos/lib/prologos/data/string.prologos`
are imported via `foreign racket "racket/base" [...]`. The elaborator
produces an `expr-foreign-fn` with the Racket procedure embedded:

```
> (global-env-lookup-value 'prologos::data::string::length)
(expr-foreign-fn 'length #<procedure:string-length> 1 '()
                 '(#<marshal-in>) #<marshal-out>
                 "racket/base" 'string-length)
```

This means:

  - At runtime in the Racket interpreter, calls to `length` apply
    `string-length` to the Racket-side string value.
  - In a native binary, **there is no Racket runtime** — we cannot
    `dynamic-require` Racket modules from compiled LLVM IR.

Therefore, native lowering of foreign string ops is fundamentally
limited to **compile-time evaluation** of literal-only expressions.

## 3. Scope (rev 1.0, conservative)

  In scope:
    - `expr-string` literals at compile time (no runtime
      representation).
    - `(expr-app (expr-fvar F) ⟨lit-args⟩)` where F is an
      `expr-foreign-fn` and ALL value args are literal scalars
      (Int / Bool / Char / String). Lower as the constant-folded
      result of `apply`-ing the embedded Racket procedure to the
      marshalled args.
    - The result must lower to a literal scalar (Int, Bool) — no
      string-typed cells in the final low-pnet.

  Out of scope (deferred):
    - Runtime string operations (taking a non-literal string).
    - String-typed cells in the runtime.
    - Native string heap (UTF-8 byte buffers, GC).
    - Bytes domain (separate from String).
    - Char as runtime value.

## 4. AST shape

```
def main : Int := length "hello"

main = (expr-app
         (expr-fvar 'prologos::data::string::length)
         (expr-string "hello"))
```

Lookup `prologos::data::string::length` in global-env, find an
`expr-foreign-fn`. Apply its marshallers + procedure to the literal
arg. The result is `5`. Lower as `(expr-int 5)`.

For `eq "abc" "abc"`:

```
main = (expr-app
         (expr-app (expr-fvar 'prologos::data::string::eq)
                   (expr-string "abc"))
         (expr-string "abc"))
```

Lookup `eq`, find `expr-foreign-fn` with arity 2. Apply to the two
strings, get `#t`. Lower as `(expr-true)`.

## 5. Implementation

In `ast-to-low-pnet.rkt`:

  - New helper `lookup-foreign-fn : symbol → expr-foreign-fn-or-#f`
    queries the global env's value entry, returns it if it's an
    `expr-foreign-fn`, else `#f`.

  - New helper `try-fold-foreign-call : expr × env → vtree-or-#f`
    inspects an `expr-app` chain. If:
      (a) The head is an fvar pointing to an `expr-foreign-fn`.
      (b) Type args are all `type-arg?` (erased).
      (c) Value args all reduce to literal values via
          `expr-to-literal-value` (Int/Bool/Char/String/Nat).
    then apply the foreign proc with the literals (after running
    them through `marshal-in`), unmarshal the result, and return
    the lowered literal vtree. Otherwise return `#f` and the
    caller falls through to regular dispatch.

  - The `expr-app` of fvar dispatch tries `try-fold-foreign-call`
    AFTER ctor detection (so user-defined ctors that happen to
    overlap a foreign name resolve correctly), but BEFORE
    tail-rec / inline.

  - `expr-string` literals get a translate-error message in any
    OTHER context (not as an arg to a fold-able foreign fn). They
    have no runtime representation.

In `expr-to-literal-value`:

  - `(expr-int n)` → `n`
  - `(expr-true)` → `#t`
  - `(expr-false)` → `#f`
  - `(expr-string s)` → `s`
  - `(expr-char c)` → `c`
  - everything else → `#f` (signals "not a literal")

In `literal-value-to-vtree`:

  - integer → `(emit-cell! b INT-DOMAIN-ID n)`
  - boolean → `(emit-cell! b BOOL-DOMAIN-ID b)`
  - char → `(emit-cell! b INT-DOMAIN-ID (char->integer c))`
  - string → translate-error "string result not lowerable to scalar"

## 6. Acceptance suite (rev 1.0)

Six examples under `examples/network/n10-strings/`:

  1. `length-hello.prologos`        — `length "hello"` → 5
  2. `length-empty.prologos`        — `length ""`      → 0
  3. `eq-yes.prologos`              — `eq "abc" "abc"` → 1 (Bool)
  4. `eq-no.prologos`               — `eq "abc" "abd"` → 0 (Bool)
  5. `concat-then-length.prologos`  — `length (append "ab" "cd")` → 4
  6. `length-of-substring.prologos` — `length (slice "hello" 1 4)` → 3

If all 6 pass via round-trip + native binary, Gate 3 rev 1.0 is met.

## 7. What rev 1.0 does NOT enable

  - Runtime strings. No string variables, no string cells.
  - Foreign-imported procs that aren't pure on their literal args
    (e.g. file I/O, time, randomness).
  - Foreign procs whose argument types are non-literal Prologos
    structures (e.g. lists of strings — needs Gate 1 rev 2).

## 8. Path to rev 2

When real native strings are needed:

  - Add a STRING-DOMAIN-ID kernel domain whose values are u32
    handles into a sidecar string-intern table.
  - Kernel additions: `prologos_string_intern(buf, len) → u32`,
    `prologos_string_length(handle) → i64`,
    `prologos_string_eq(h1, h2) → i64`,
    `prologos_string_concat(h1, h2) → u32`.
  - Add `expr-str-len`, `expr-str-eq`, etc. as core AST nodes (or
    keep recognizing the foreign-fn names) and lower to kernel
    calls.

Rev 2 is a multi-day item; deferred behind Gate 4 and the rest of
the lowering-yolo session.
