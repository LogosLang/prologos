# FFI Lambda Passing

**Date**: 2026-04-28
**Status**: Implemented
**Scope**: `racket/prologos/foreign.rkt`, `racket/prologos/driver.rkt`
            (foreign-type-tokens parser), `racket/prologos/reduction.rkt`
            (one removed unused require).
**Tests**: `racket/prologos/tests/test-foreign-callback.rkt` (10 tests),
          `racket/prologos/lib/examples/lambda-ffi-test.prologos` (Level 3),
          `racket/prologos/lib/examples/lambda-ffi-helper.rkt` (Racket helper).

## Summary

Until this track, Prologos lambdas could not cross the Racket FFI boundary
as live closures. A `foreign racket "..."` declaration could marshal first-
order *values* (Nat, Int, Rat, Bool, Char, String, Posit32, Posit64, Path,
Keyword, Passthrough, Opaque) but not *callable functions*. Concretely, a
signature like `apply-twice : [Nat -> Nat] Nat -> Nat` was rejected because
the function-typed parameter had no marshaller.

This change extends `parse-foreign-type` to recognise function (`Pi`) types
in argument positions and produces a recursive marshalling spec. When the
foreign function is called with a Prologos value `pf` of function type, the
marshaller wraps `pf` as a Racket procedure that — on each Racket-side call
— marshals its Racket arguments back into Prologos IR, builds the
application AST, reduces it via `nf`, and marshals the result back to
Racket.

## Stage 1 — Problem statement

Two consumers needed this:

1. **The EigenTrust-on-propagators example** (commit history in
   `docs/tracking/2026-04-28_ETPROP_PITFALLS.md` § "What MUST stay on the
   Racket side") catalogued four responsibilities that resisted being
   pushed out into Prologos. Items 1 and 2 — propagator fire functions and
   cell merge functions — had only one root cause: live Prologos lambdas
   could not be called from Racket. Items 3 and 4 are independent (data-
   carrier and posit/list marshalling glue).

2. **General FFI ergonomics**: any Racket library function that takes a
   procedure as a parameter (HOFs: `map`, `filter`, `apply`, callback
   registries, control operators) was unreachable from Prologos.

## Stage 3 — Design

### Module topology

`reduction.rkt` previously had `(require "foreign.rkt")` but did not use
any of its exports — `expr-foreign-fn` lives in `syntax.rkt`. We removed
the dead require and introduced the reverse dependency:
`foreign.rkt` now requires `reduction.rkt` so the new function-type
marshaller can call `nf` to drive callbacks back into the reducer.

This is a clean reversal — there is no actual circular use, only the
declaration was wrong.

### Marshalling specification (recursive)

`parse-foreign-type` previously returned `(arg-base-symbols . ret-base-symbol)`
where each base type was a flat symbol like `'Nat`. The returned shape is
unchanged at the top level, but each *position* (arg slot or return slot)
may now be either:

  - a base type symbol (existing behaviour, e.g. `'Nat`, `'Bool`, `'Posit32`)
  - `(cons 'fn parsed-foreign-type)` where `parsed-foreign-type` is the
    same recursive shape, representing a function-typed parameter

This is fully backward-compatible: every existing parsed type uses the
same symbol-only shape it did before. The new `'fn` tag opts in to the
function-marshaller branch in `marshal-prologos->racket`.

Examples:

| Prologos type                                | Parsed shape                               |
|----------------------------------------------|--------------------------------------------|
| `Nat -> Nat`                                 | `((Nat) . Nat)`                            |
| `Nat -> Nat -> Bool`                         | `((Nat Nat) . Bool)`                       |
| `[Nat -> Nat] Nat -> Nat`                    | `(((fn (Nat) . Nat) Nat) . Nat)`           |
| `[Nat -> Nat] [Nat -> Nat] Nat -> Nat`       | `(((fn (Nat) . Nat) (fn (Nat) . Nat) Nat) . Nat)` |
| `[[Nat -> Nat] -> Nat] -> Nat`               | `(((fn ((fn (Nat) . Nat)) . Nat)) . Nat)`  |

### The Racket→Prologos→Racket bridge

`wrap-prologos-fn-as-racket` (in `foreign.rkt`) takes a Prologos value `pf`
of function type and the parsed arg/ret specs, and returns a Racket
procedure that:

  1. Validates arity against the spec.
  2. Marshals each Racket argument back into Prologos IR via
     `marshal-racket->prologos` on the corresponding arg spec. Nested
     function specs install deeper bridges recursively.
  3. Builds `(((pf arg1) arg2) ... argN)` by left-folding `expr-app`.
  4. Reduces with `nf`. The reducer's existing memoisation (`current-nf-cache`,
     `current-whnf-cache`) handles repeat calls efficiently.
  5. Marshals the resulting IR value back to Racket via
     `marshal-prologos->racket` on the return spec.

The wrapper is a closure over `pf`, the arg specs, and the ret spec — so a
single invocation of the foreign function may pass the same Prologos
lambda to a Racket procedure that holds onto it across many calls
(stateful Racket consumer). Each Racket-side call drives one full
`nf` reduction.

### Sub-bracket function type tokens

A foreign signature like `[Nat -> Nat] Nat -> Nat` arrives at the
foreign-type tokenizer as `((Nat -> Nat) Nat -> Nat)` — the WS reader
turns the `[...]` group into a sub-list. The existing
`foreign-type-tokens->sexp` did not recurse into sub-list tokens, so
`(Nat -> Nat)` got parsed as a function application `(Nat -> Nat)`
rather than the prefix arrow form `(-> Nat Nat)`. We added a
`normalize-sub-token` helper that, for any list-shaped token containing
`->` at the top level, recursively re-runs `foreign-type-tokens->sexp`.
The single-token branch was extended to do the same so that bare
`[Nat -> Nat]` (a one-token foreign type) parses correctly.

### Reverse direction (Racket procedure → Prologos value): NOT supported

`marshal-racket->prologos` on an `'fn` spec raises with a clear error.
Returning a Racket procedure to Prologos as a callable lambda would
require fabricating an `expr-foreign-fn` at marshal time with a
type-checked arity and signature, which crosses the surface-syntax
boundary and is out of scope here. This is a *named* limitation, not
silent — see § Edge cases below.

## WS Impact

  - **Reader**: no changes. The WS reader already produces sub-list
    forms for `[ ... ]`.
  - **Preparse**: no new pass. The function-type token normalisation
    happens in `foreign-type-tokens->sexp`, well after preparse.
  - **Keyword conflicts**: none. `->` was already a foreign-type token.
  - **flatten-ws-kv-pairs**: not touched. Foreign types are inside the
    `(foreign racket ...)` form and don't pass through pair flattening.

## Mantra alignment

> "All-at-once, all in parallel, structurally emergent information flow ON-NETWORK."

The FFI marshaller is **off-network scaffolding by design**: it sits at
the boundary between the propagator-network world (Prologos IR + reducer)
and arbitrary Racket libraries that have no notion of cells, monotone
merges, or BSP. The mantra still applies — challenged adversarially:

  - **All-at-once**: ✓ Each Racket-side callback produces ONE `nf` call
    that fully reduces the application. We do not stream partial results.
    Challenge: should multiple parallel Racket-side calls share work?
    Answer: the `nf` cache already memoises subexpressions; the wrapper
    is a thin closure, no per-call coordination needed. Scaffolding-with-
    retirement-plan: when propagator-native callbacks land (the long-term
    solution where a Racket consumer subscribes to a cell rather than
    holding a procedure), this off-network bridge retires.

  - **All in parallel**: ⚠ Each Racket call drives a sequential `nf`.
    Challenge: this looks like step-think. Honest answer: it IS step-think,
    inherent to the FFI shape — Racket consumers expect synchronous
    procedure semantics. The bridge is a synchronous adapter, named as
    such, with the long-term retirement path being on-network propagator
    callbacks (cell subscription) rather than procedure-shaped foreign
    callbacks.

  - **Structurally emergent**: ✓ The marshaller's branching on `'fn`
    tag emerges from the type's shape. There is no imperative dispatch
    table — `parse-foreign-type` walks the `Pi` chain and tags each
    function-typed slot. The marshaller's case analysis is a structural
    consequence of the parsed spec.

  - **Information flow**: ⚠ Information flows through Racket procedure
    calls (parameters and return values), not through cells. Same
    mantra-failure as above; same retirement path.

  - **ON-NETWORK**: ✗ The bridge itself is off-network. Named as
    scaffolding. The path to retire it is *propagator-native foreign
    callbacks*: a Racket consumer that wants a Prologos function as a
    "callback" subscribes to a cell whose value is the desired output;
    the Prologos lambda becomes a propagator that writes to that cell;
    BSP drives evaluation; the Racket consumer reads the cell rather
    than calling a procedure. That is a separate track — until then,
    this synchronous bridge is the right scaffolding to remove items 1
    and 2 from the EigenTrust pitfalls list and to enable a large class
    of immediate FFI use cases.

**Net mantra-alignment self-assessment**: scaffolding, named, with a
retirement plan. The alternative — refusing to build the bridge until
propagator-native callbacks are designed — would block items 1 & 2
indefinitely and leave every Racket HOF unreachable from Prologos. The
bridge buys real freedom while the on-network path matures.

## SRE lattice lens

This is a marshalling layer, not a propagator track, so the lens is
applied modestly:

  - **Q1 — VALUE vs STRUCTURAL**: The marshalling spec lattice is
    VALUE: a flat ordered set of base-type symbols + the recursive
    `'fn` constructor. There is no monotone refinement — specs are
    fully determined at parse time.

  - **Q2 — algebraic properties**: Specs form a tree under `Pi`
    nesting. The leaf set (base-type symbols) is finite and discrete.
    There is no join structure because parsing produces a single fixed
    spec; no two specs need to be merged. This is consistent with the
    marshaller's pure-function shape (no cell, no merge).

  - **Q3 — bridges**: The marshaller bridges *between* the IR-value
    lattice (Prologos `expr-*` AST) and the Racket-value space (no
    lattice; Racket values are extensional). The bridge is not a Galois
    connection — Racket has no order — so we don't get joint-preservation
    guarantees. This is acceptable because the marshaller is at the
    system boundary; downstream of the boundary, Racket code is
    responsible for its own correctness.

  - **Q4 — composition**: The recursive `'fn` spec composes: a
    function-typed argument's marshaller calls
    `marshal-racket->prologos` on the inner arg specs, which can itself
    hit another `'fn` for nested function types. This composition is
    structural induction on the spec.

  - **Q5 — primary/derived**: The Prologos type (`expr-Pi` chain) is
    PRIMARY. The marshalling spec is DERIVED via `parse-foreign-type`.

  - **Q6 — Hasse diagram**: N/A. There is no order on specs.

The lens confirms what the mantra check named: this is boundary code,
correctly off-network, with the Racket side disclaiming any lattice
discipline.

## Correspondence: Prologos type ↔ Racket marshaller behaviour

| Prologos arg position type | Marshaller behaviour                                                  |
|----------------------------|-----------------------------------------------------------------------|
| Base type (Nat, etc.)      | Convert IR value to Racket value via the existing per-type case.      |
| `[A -> B]`                 | Wrap the IR value as a Racket procedure of arity 1. On call: marshal one Racket arg (per `A`'s spec) into IR, apply, `nf`, marshal result (per `B`'s spec). |
| `[A -> B -> C]`            | Wrap as Racket procedure of arity 2. Inner specs handle their own marshalling, recursively. |
| `[[A -> B] -> C]`          | Wrap as arity-1 Racket procedure whose argument is itself a procedure. The inner-procedure marshaller fires when the arg-procedure is called. (See `callback/parse-nested-fn-type` test.) |

| Prologos return type       | Marshaller behaviour                                                  |
|----------------------------|-----------------------------------------------------------------------|
| Base type                  | Convert Racket return value to IR via the existing per-type case.     |
| Function type (`A -> B`)   | **Error**: returning a Racket procedure to Prologos as a callable lambda is reserved for a future track. |

## Edge cases

- **Multi-argument lambdas**: a `[A B -> C]` callback wraps as a Racket
  procedure of arity 2 (uncurried at the Racket boundary). Internally,
  the application is built `((pf arg1) arg2)` because the Prologos lambda
  is curried. This works because `nf` reduces the curried application
  fully.

- **Currying / partial application from Prologos**: if Prologos partially
  applies a callback (e.g. `def f := my-inc` where `my-inc` is later
  passed to `apply-twice`), the value `f` is a Prologos lambda — fine.
  The marshaller does not care about the lambda's internal shape, only
  that `nf` will reduce the application. Tested via `callback/apply-twice-with-named-lambda`.

- **Recursive Prologos lambdas**: a recursive Prologos function is a
  closure over its (typically `defn`-bound) name. As long as the
  reducer can resolve the name when `nf` runs, recursion works.
  Reduction-fuel limits apply (`current-reduction-fuel`).

- **Stateful Racket consumers** that call the wrapper many times: the
  wrapper is a long-lived closure; each call produces a fresh `nf` invocation.
  The reducer's whnf/nf caches accelerate repeated calls with structurally
  identical arguments.

- **Errors during the inner reduction**: any exception raised inside
  `nf` (fuel exhaustion, reducer error) propagates out of the wrapper
  to the Racket caller. The wrapper does not catch — Racket's exception
  protocol is the right discipline for boundary errors.

- **Returning a Racket procedure to Prologos**: explicitly errors with a
  message pointing at this design doc.

## Pipeline checklists applied

(per `.claude/rules/pipeline.md`)

  - **New AST node**: N/A. We added no new struct, no new AST node.
    The marshaller spec is internal Racket data, not an AST node.
  - **New Racket parameter**: N/A. We added no `make-parameter` calls.
    The bridge uses a closure over its specs, not a parameter.
  - **New struct field**: N/A. `expr-foreign-fn`'s field count is
    unchanged; only the *content* of the `marshal-in` list now admits
    structured specs (which were already opaque to other consumers
    that only treat each element as a procedure of one argument).

## Stretch: removing items 1 & 2 from EigenTrust's "must stay in Racket" list

Items 1 (propagator fire functions) and 2 (cell merge functions) in
`docs/tracking/2026-04-28_ETPROP_PITFALLS.md` were both blocked on
"Prologos lambdas can't cross the FFI boundary as live closures."
That blocker is removed by this track.

The ETPROP_PITFALLS doc has been updated to downgrade items 1 and 2
to **"preferentially Racket for performance, but no longer required"**.
A future refactor can move EigenTrust's fire-fn into a Prologos lambda
called via FFI from a Racket harness propagator that just adapts the
lambda to the network's fire-fn protocol:

```racket
;; Racket harness propagator (sketch)
(define (install-prologos-fire-fn pf-arity-1)
  ;; pf-arity-1 is the Racket-procedure wrapper produced by
  ;; marshal-prologos->racket on a Prologos lambda of type
  ;;   net-snapshot -> net-snapshot
  ;; (or whatever the fire-fn signature normalises to in the
  ;;  propagator base layer).
  (lambda (net) (pf-arity-1 net)))
```

In the .prologos source the user writes their fire-fn as a normal
`def` whose RHS is a Prologos lambda; the foreign declaration takes
that lambda and registers it through the harness. We have NOT done
this refactor in the EigenTrust example — leaving that as a follow-up
so this track stays scoped to the marshaller.

## Files touched

  - `racket/prologos/foreign.rkt` — recursive marshalling spec, function-
    type wrapper, error path for reverse direction.
  - `racket/prologos/reduction.rkt` — removed unused `(require "foreign.rkt")`
    to permit the reverse import.
  - `racket/prologos/driver.rkt` — `foreign-type-tokens->sexp` now recurses
    into sub-list tokens via `normalize-sub-token`.
  - `racket/prologos/tests/test-foreign-callback.rkt` — 10 new tests.
  - `racket/prologos/lib/examples/lambda-ffi-helper.rkt` — Racket helper
    module for the acceptance file.
  - `racket/prologos/lib/examples/lambda-ffi-test.prologos` — Level 3
    acceptance file.
  - `docs/tracking/2026-04-28_ETPROP_PITFALLS.md` — items 1 & 2 downgraded.

## Test results

  - `tests/test-foreign-callback.rkt`: 10 pass, 0.5s
  - `tests/test-foreign.rkt`: pre-existing 47 pass, no regression
  - `tests/test-foreign-block.rkt`: pre-existing pass, no regression
  - `tests/test-pvec.rkt`: pre-existing pass, no regression
  - `tests/test-io-opaque-01.rkt`: pre-existing 13 pass (uses
    `marshal-prologos->racket` directly with symbol specs — confirms
    backward compatibility).
  - `lib/examples/lambda-ffi-test.prologos` (Level 3 via `process-file`):
    runs end-to-end with all four expected results.
  - `lib/examples/eigentrust.prologos` (Level 3 regression check):
    runs to completion with the same output.
  - Full suite: 17 pre-existing failures (rackcheck collection missing,
    `prologos/propagator` collection missing, stale macOS path entries
    in compiled metadata) — none touched by this change. Verified by
    stashing and re-running on the parent branch.
