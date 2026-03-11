# WS-Mode Repair Sprint

## Context

The [WS-Mode Audit](2026-03-10_WS_MODE_AUDIT.md) (commits `41d6711`–`6fc0949`, `99ce5c3`)
exercised ~300 expressions across 12 `.prologos` audit files, revealing 36 CRASHes, 6 WRONGs,
and 7 DESIGN notes. The audit clustered these into 8 root causes (C1–C8).

This document is the implementation plan for fixing those issues. It is organized by
pipeline stage (reader → preparse → parser/elaborator → typing → reduction) because
fixes earlier in the pipeline may unblock or simplify later fixes.

**Guiding principle**: Fix from the bottom of the stack upward. Reader fixes before
preparse fixes before elaborator fixes before typing fixes before narrowing fixes.

**Validation strategy**: After each phase, re-run the affected audit file(s) via
`run-file.rkt` and un-comment any expressions that the fix should have unblocked.
Full test suite (`--all`) at each phase boundary.

---

## Dependency Graph

```
Phase 1: Reader Fixes (C5 partial)
    |
    v
Phase 2: Preparse Fixes (C3, C7, C8)
    |
    v
Phase 3: Data & Constructor Fixes (C4, C1)
    |
    v
Phase 4: Type Inference Fixes (C2, top-level if)
    |
    v
Phase 5: Narrowing Correctness (C6)
```

Phases 1 and 2 are largely independent of each other (reader vs preparse) but
are ordered this way because reader fixes may change the datum shapes that preparse
sees. Phase 3 depends on Phase 2 (preparse must correctly handle `data` forms
before we fix constructor elaboration). Phase 4 depends on Phase 3 (constructors
must be first-class before we can test inference improvements). Phase 5 is
independent but is last because narrowing correctness is lower priority than
basic functionality.

---

## Phase 1: Reader Fixes

**Cluster**: C5 (Reader-Level Syntax Conflicts)
**Files**: `racket/prologos/reader.rkt`
**Audit files affected**: audit-01, audit-06, audit-12

### Phase 1a: Char Literal Syntax in WS Mode

**Problem**: `'a'` is read as `(quote a)` + stray `'` because `'` is the
quote/list-literal prefix (reader.rkt:354–364). The Char type exists and
`\a` backslash-escape works (reader.rkt:700–759), but there's no single-char
literal syntax in WS mode.

**Approach**: The `\` escape path already handles single chars. The question is
whether we need a new literal syntax (e.g., `#'a'` or `c'a'`) or whether `\a`
is sufficient. The audit showed the Char type works fine — it's only the literal
syntax that's missing.

**Decision needed**: Is `\a` (backslash-char) sufficient for WS-mode char
literals, or do we want a dedicated syntax? If `\a` is sufficient, this is a
DESIGN note (document it) not a fix. If we want new syntax, it requires a
readtable entry.

**Effort**: S (if documentation only) / M (if new syntax)
**Audit expressions**: audit-01 `'a'`, `'\n'`
**Validation**: Un-comment char literal tests in audit-01, verify output

### Phase 1b: `=` Inside Mixfix `.{}`

**Problem**: `.{3N = 3N}` crashes with "Unexpected token after expression: ="
(audit-06). The `=` triggers the narrowing/equality rewrite pass, which runs
before mixfix parsing and conflicts with it.

**Root cause**: The rewrite pass in `macros.rkt` (not reader.rkt) scans for `=`
at the top level of forms. When `=` appears inside `.{}`, the rewrite pass
captures it before the mixfix parser sees it.

**Approach**: The rewrite pass that handles `=` needs to skip `=` tokens that
are inside `$mixfix` or `.{}` delimiters. This is a preparse fix, not a reader
fix — listing it here because it's C5 but the actual fix is in macros.rkt.

**Fix location**: `macros.rkt` — the `=` rewrite pass (find the pass that
transforms `expr1 = expr2` into `($unify expr1 expr2)` or `($eq expr1 expr2)`;
add a guard that skips when inside `$mixfix`).

**Effort**: S
**Audit expressions**: audit-06 `.{3N = 3N}`
**Validation**: Un-comment `.{3N = 3N}` in audit-06, expect `true : Bool`

### Phase 1c: Quote / Quasiquote in WS Mode

**Problem**: `'foo`, `'(a b c)`, and `` `(hello ,x world) `` all crash (audit-12).
The `'` prefix is overloaded: `'[` → list literal, `'` alone → quote. But the
quote path produces `($quote foo)` which then fails because the elaboration path
for `$quote` may not work in WS mode, or because `'(a b c)` → `($quote (a b c))`
and the inner `(a b c)` gets parsed as a function call.

**Root cause**: Reader tokenizes `'foo` as `(quote . foo)` or `($quote foo)`
(reader.rkt:354–364, quote token type). The issue is downstream — the parser
or elaborator doesn't handle the quote form correctly in WS mode.

**Approach**: Investigate the actual reader output for `'foo` in WS mode. The
fix may be in the parser (handle `$quote` sentinel) or in the elaborator (handle
`expr-quote`). Quasiquote requires the `prologos-qq-readtable` to be active in
WS mode — check if it's installed.

**Effort**: M (quote) + M (quasiquote — readtable integration)
**Audit expressions**: audit-12 `'foo`, `'(a b c)`, `` `(hello ,x world) ``
**Validation**: Un-comment quote/quasiquote tests in audit-12

### Phase 1 Status

| Sub-phase | Status | Commit |
|-----------|--------|--------|
| 1a: Char literal syntax | NOT STARTED | |
| 1b: `=` inside mixfix | NOT STARTED | |
| 1c: Quote/quasiquote | NOT STARTED | |

---

## Phase 2: Preparse Fixes

**Cluster**: C3 (Preparse Gaps), C7 (Spec/Constraint), C8 (Arity/Name)
**Files**: `racket/prologos/macros.rkt`, `racket/prologos/namespace.rkt`
**Audit files affected**: audit-02, audit-05, audit-06, audit-10, audit-11

### Phase 2a: `def-` (Private Def) Recognition

**Problem**: `def- private-val := 42N` → "def requires: (def name <type> body)"
(audit-11). `spec-` and `defn-` work but `def-` does not.

**Root cause**: In `preparse-expand-all` Pass 2 (macros.rkt:1942–2166), the
private suffix stripping handles `defn-`, `spec-`, `data-` but likely misses
`def-`. The suffix is stripped and the form is re-dispatched as a regular `def`
with a private flag.

**Fix**: Add `def-` to the private-form handling in Pass 2, mirroring the
pattern used for `defn-` and `spec-`. This is a one-line addition to the
dispatch cond clause.

**Effort**: S
**Audit expressions**: audit-11 `def- private-val := 42N`
**Validation**: Un-comment `def-` tests, verify private def works

### Phase 2b: `def` with Multi-Token RHS (Constructor Application)

**Problem**: `def x := some 42N` → "expected exactly one value after :="
(audit-02). The preparse `:=` handler sees two tokens (`some`, `42N`) and
rejects.

**Root cause**: The `:=` handler in the preparse splits on `:=` and expects
exactly one datum on the right. Multi-token constructor applications need
brackets: `[some 42N]`.

**Fix**: Change the `:=` handler to auto-wrap multiple RHS tokens in a list
(application). If there are N > 1 tokens after `:=`, wrap them as
`(token1 token2 ... tokenN)`. This matches the WS-mode convention that
juxtaposed tokens form an application.

**Risk**: Must not break cases where `:=` RHS is intentionally a single token.
Only wrap when count > 1.

**Effort**: S
**Audit expressions**: audit-02 `def x := some 42N`
**Validation**: Un-comment, expect `some 42N : Option Nat`

### Phase 2c: `def` with Lambda Value

**Problem**: `def double-fn := (fn [x : Nat] [add x x])` → "Could not infer
type" (audit-05). Also `def make-adder := (fn [x] (fn [y] ...))`.

**Root cause**: Top-level `def` with a `fn` value fails type inference because
the fn has no bidirectional type context. Inside a `defn` body with a `spec`,
the return type provides context. At top level, the fn's parameter types may
need to be fully annotated.

**Diagnosis needed**: Is this a preparse issue (the datum shape is wrong) or a
typing issue (elaborator can't infer fn types at top level)? If the datum reaches
the elaborator correctly and typing fails, this belongs in Phase 4 instead.

**Approach**: Test whether `def double-fn : [Nat -> Nat] := (fn [x : Nat] [add x x])`
(with explicit type annotation) works. If it does, the issue is inference, not
preparse, and the fix is to improve top-level fn inference or document that
type annotations are required.

**Effort**: S (if annotation works) / M (if elaborator fix needed)
**Audit expressions**: audit-05 `def double-fn`, `def make-adder`
**Validation**: Test with and without type annotations

### Phase 2d: `inject-spec-into-defn` Arity with Constraints

**Problem**: `spec both-eq {A : Type} (Eq A) A A -> Bool` paired with
`defn both-eq [a b]` → "type has 1 type parameters but defn has 2 params"
(audit-06).

**Root cause**: `inject-spec-into-defn` (macros.rkt:3211) decomposes the spec
type and counts parameters. The constraint `(Eq A)` is being counted as a
type parameter, reducing the perceived arity from 2 to 1. The `decompose-pi-type`
or arity-counting logic (macros.rkt:3255–3265) doesn't distinguish constraint
parameters (dict params) from value parameters.

**Fix**: In the arity comparison (macros.rkt:3255–3265), ensure that dict/constraint
parameters are excluded from the count that's compared against the defn's param
count. The spec's arity should count only the explicit value parameters, not the
implicit dictionary parameters injected by trait constraints.

**Effort**: S
**Audit expressions**: audit-06 `spec both-eq {A : Type} (Eq A) A A -> Bool`
**Validation**: Un-comment both-eq, verify `[both-eq 3N 3N]` → `true`

### Phase 2e: `defn` Inside `impl` Block

**Problem**: `impl Describable Nat` with indented `defn describe [n] n` →
"defn requires: (defn name [x <T> ...] body)" (audit-06).

**Root cause**: `preparse-expand-all` processes `impl` in Pass 1
(macros.rkt:1911–1927). The WS-mode indentation groups the `defn` forms as
children of the `impl` datum, but the impl handler doesn't recognize `defn`
as a valid child form — it expects sexp-style method definitions.

**Fix**: The `impl` handler needs to recognize `defn` (and `def`) as method
definition forms within its body. Each child `defn` should be treated as a
method implementation. This may require teaching the impl processing to
preparse-expand its children before interpreting them.

**Effort**: M (must understand impl processing flow, test multi-method impls)
**Audit expressions**: audit-06 `impl Describable Nat { defn describe [n] ... }`
**Validation**: Un-comment impl blocks, verify trait dispatch works

### Phase 2f: Multi-Clause `defn` with Spec

**Problem**: `defn mc-zero | zero -> true | _ -> false` with a matching spec
errors "spec is single-arity but defn has multiple clauses" (audit-02).

**Root cause**: `maybe-inject-spec` (macros.rkt:3426) classifies defns as
single-body vs multi-body. A multi-clause defn (with `$pipe`) paired with a
single-arity spec (the common case — one function type, pattern dispatch) fails
the check at macros.rkt:3436 which expects a multi-arity spec for pipe clauses.

**Fix**: Distinguish between multi-arity pipes (different param counts per clause)
and pattern-dispatch pipes (same arity, different patterns). A single-arity spec
paired with pattern-dispatch pipes should work — inject the same type into each
clause.

**Effort**: M
**Audit expressions**: audit-02 `defn mc-zero | zero -> true | _ -> false`
**Validation**: Un-comment, verify pattern dispatch works

### Phase 2g: `with-transient` Macro in WS Mode

**Problem**: `(with-transient @[] Nat [tvec-push! 1N] ...)` → "expected
(with-transient coll fn-expr), got multi-step form" (audit-12).

**Root cause**: The `with-transient` macro (defined as a preparse macro) expects
exactly 2 arguments (collection, function). WS-mode indentation groups the
multi-step body as additional arguments instead of as a single fn body.

**Fix**: Teach the `with-transient` macro to accept the multi-step WS form.
When it receives more than 2 args, wrap the trailing args as a `fn` body:
`(with-transient coll step1 step2 ...)` → `(with-transient coll (fn [t] (do step1 step2 ...)))`.

**Effort**: S
**Audit expressions**: audit-12 `with-transient` blocks
**Validation**: Un-comment, verify transient builder works

### Phase 2h: Transducer `into-list` Name Collision

**Problem**: `[into-list Nat Nat [map-xf ...] coll]` → "Too many arguments to
'into-list'" (audit-10). The prelude imports `into-list` from
`prologos::core::collections` (1-arg: collection → list), which shadows the
`into-list` from `prologos::data::transducer` (4-arg: A B xf coll → list).

**Root cause**: Namespace collision in prelude exports (`namespace.rkt`). Both
modules export `into-list` with different signatures. The prelude loads the
collection version, making the transducer version inaccessible.

**Fix options**:
1. Rename the transducer version to `transduce-to-list` or `xf-into-list`
2. Use qualified access: `transducer::into-list`
3. Make the prelude prefer the transducer version (more general)

**Recommended**: Option 1 — rename to avoid ambiguity. The collection `into-list`
is more commonly used; the transducer form should have a distinct name.

**Effort**: S
**Audit expressions**: audit-10 `into-list` with transducer args (×3)
**Validation**: Update audit-10 to use new name, verify output

### Phase 2i: Top-Level `let` as `def` Sugar

**Problem**: `let x := val` at top level → "let :=: missing value after :="
(audit-05).

**Root cause**: `let` is only recognized inside function bodies where it
desugars to nested lambda application. The preparse doesn't handle `let` as
a top-level form.

**Fix**: In the preparse, recognize top-level `let x := val` and rewrite it
to `def x := val`. This makes `let` an alias for `def` at top level, which
matches user expectation from REPL-style usage.

**Effort**: S
**Audit expressions**: audit-05 `let x := val`
**Validation**: Un-comment top-level let, verify it works as def

### Phase 2 Status

| Sub-phase | Status | Commit |
|-----------|--------|--------|
| 2a: `def-` recognition | NOT STARTED | |
| 2b: `def` multi-token RHS | NOT STARTED | |
| 2c: `def` with lambda value | NOT STARTED | |
| 2d: spec+constraint arity | NOT STARTED | |
| 2e: `defn` inside `impl` | NOT STARTED | |
| 2f: Multi-clause `defn` + spec | NOT STARTED | |
| 2g: `with-transient` WS form | NOT STARTED | |
| 2h: `into-list` name collision | NOT STARTED | |
| 2i: Top-level `let` as `def` | NOT STARTED | |

---

## Phase 3: Data & Constructor Fixes

**Cluster**: C4 (User-Defined Data Constructors), C1 (Constructor-as-HOF)
**Files**: `racket/prologos/macros.rkt` (process-data, parse-data-ctor),
`racket/prologos/elaborator.rkt` (constructor lookup, env injection)
**Audit files affected**: audit-03, audit-07, audit-10, audit-11

### Phase 3a: Nullary Constructors as Values

**Problem**: `data Direction` with `North : Direction` defines `North` as type
`Direction -> Direction` (a function) instead of a value of type `Direction`
(audit-03).

**Root cause**: `process-data` (macros.rkt:6127) generates a constructor def
with type `Pi(...) -> ... -> TypeName`. For nullary constructors (no fields),
this degenerates to `Direction -> Direction` instead of just `Direction`. The
`parse-data-ctor` (macros.rkt:5963) returns `(North . ())` for a bare symbol
ctor, but the def generation doesn't handle the empty-field-list case correctly.

**Fix**: In `process-data` (macros.rkt:6193–6210), when a constructor has zero
field types, generate `def North : Direction := <constructor-body>` instead of
`def North : (Direction -> Direction) := ...`. The Pi-wrapping of field types
should be skipped entirely for nullary constructors.

**Effort**: S
**Audit expressions**: audit-03 `North`, `South`, `direction-name`
**Validation**: Un-comment Direction tests, verify `North : Direction`

### Phase 3b: Multi-Field Constructors

**Problem**: `Rect : Nat Nat -> Shape` → "Expression is not a valid type"
(audit-03).

**Root cause**: `parse-data-ctor` (macros.rkt:5963) handles the `:` syntax
at lines 5976–5994, splitting on `->` to extract field types. The issue may
be that `Nat Nat` (two types before `->`) isn't parsed correctly — it may be
treated as a single compound expression instead of two separate field types.

**Fix**: In `parse-data-ctor`, when processing `CtorName : T1 T2 ... -> RetType`,
ensure that the segment before `->` is split into individual type expressions.
Each space-separated token is a separate field type.

**Effort**: M (need to handle various field type combinations)
**Audit expressions**: audit-03 `Rect : Nat Nat -> Shape`
**Validation**: Un-comment Rect tests, verify `[Rect 3N 4N] : Shape`

### Phase 3c: Polymorphic Constructor Binding

**Problem**: `data MyBox {A : Type}` with `MkBox : A -> MyBox A` — `MkBox`
is defined but `[MkBox 42N]` fails "Unbound variable" (audit-03).

**Root cause**: The constructor `MkBox` is registered in the constructor
metadata registry (`ctor-meta`) but not injected into the global environment
where `env-lookup` (elaborator.rkt:75–86) can find it. For built-in types
(Nat, Bool, List, etc.), constructors are injected by the prelude modules.
For user-defined types, the generated `def MkBox : ...` form should add
MkBox to the environment, but something in the elaboration path drops it.

**Diagnosis needed**: Check whether the generated `def MkBox : <type> := ...`
form from `process-data` is syntactically correct for a polymorphic constructor.
The type includes implicit params `{A : Type}` which may not be handled.

**Effort**: M
**Audit expressions**: audit-03 `MkBox 42N`, `MkBox true`
**Validation**: Un-comment MyBox tests, verify polymorphic construction works

### Phase 3d: Constructor-as-HOF (The Big One)

**Problem**: `[map suc '[1N 2N 3N]]` → "Unbound variable" (audit-07, ×5; also
audit-10 ×2, audit-11 ×1). Constructors can be applied directly (`[suc 2N]`)
and used in pipes (`0N |> suc`) but cannot be passed as arguments to
higher-order functions.

**Root cause**: When `suc` appears as a bare argument to `map`, the elaborator
looks it up in the environment via `env-lookup` (elaborator.rkt:75–86). For
built-in constructors, `suc` IS in the global environment (it's defined by
the Nat prelude module). So the issue may be more subtle — perhaps `suc` is
in the environment but its type doesn't match what `map` expects (a function
`Nat -> Nat`), or the elaborator tries to apply `suc` immediately rather than
passing it as a value.

**Diagnosis needed**: More precise investigation. Test in sexp mode:
`(process-string "(map suc (cons 1N (cons 2N nil)))")` — does this work?
If sexp works but WS doesn't, the issue is in the WS reader/preparse path.
If both fail, the issue is in elaboration.

**Approach**: If the issue is that constructors aren't η-expanded to functions,
the fix is to have the elaborator generate `(fn [x] (suc x))` when `suc` is
used in a position expecting a function type. This is "constructor η-expansion"
and is a standard technique in dependently typed languages.

**Effort**: M–L (depends on diagnosis; η-expansion is architecturally clean
but touches elaborator type-checking logic)
**Audit expressions**: audit-07 `map suc`, `pvec-map suc`, `set-map suc`,
`lseq-map suc`, `map-map-vals suc`; audit-10 block pipe with `map suc`,
`def suc-fn := suc`; audit-11 `map suc`
**Validation**: Un-comment all suc-as-HOF tests across audit-07, -10, -11

### Phase 3 Status

| Sub-phase | Status | Commit |
|-----------|--------|--------|
| 3a: Nullary constructors | NOT STARTED | |
| 3b: Multi-field constructors | NOT STARTED | |
| 3c: Polymorphic ctor binding | NOT STARTED | |
| 3d: Constructor-as-HOF | NOT STARTED | |

---

## Phase 4: Type Inference Fixes

**Cluster**: C2 (Generic/Polymorphic Inference)
**Files**: `racket/prologos/typing-core.rkt`, `racket/prologos/elaborator.rkt`
**Audit files affected**: audit-04, audit-07, audit-12

### Phase 4a: Top-Level `if` Type Resolution

**Problem**: `if true 1N 2N` → `1N : _` at top level (audit-04). The value
is correct but the type shows as `_` (unresolved) instead of `Nat`.

**Root cause**: Top-level expressions use `infer` mode (no expected type). The
`if` elaboration infers both branches but doesn't unify their types with the
result type when there's no bidirectional context. Inside a `defn` with a spec,
the return type provides context.

**Fix**: In the `if` elaboration path, after inferring both branch types,
explicitly unify them and use the unified type as the result. This should
already happen but may be guarded behind a `check` mode condition.

**Effort**: S
**Audit expressions**: audit-04 `if true 1N 2N`
**Validation**: Un-comment top-level if test, expect `1N : Nat`

### Phase 4b: `sort` / `dedup` Trait Constraint Resolution

**Problem**: `[sort '[3N 1N 2N]]` → "Could not infer type" (audit-07). The
function requires an `Ord` constraint on the element type, which isn't resolved
from the list literal alone.

**Root cause**: `sort` has type `{A : Type} (Ord A) [List A] -> [List A]`. When
called as `[sort '[3N 1N 2N]]`, the list literal infers `A = Nat`, but the
trait constraint `(Ord Nat)` resolution may happen too late or not at all at
top level. The trait instance exists (Nat has Ord) but the constraint solver
doesn't fire.

**Fix**: Investigate whether trait resolution is triggered for top-level
applications. The `resolve-trait-constraints!` pass may skip top-level
expressions or the constraints may not be registered.

**Effort**: M
**Audit expressions**: audit-07 `sort`, `dedup`
**Validation**: Un-comment sort/dedup tests

### Phase 4c: `opt::unwrap-or` Polymorphic Inference

**Problem**: `[opt::unwrap-or [some 42N] 0N]` → "Could not infer type"
(audit-07, audit-11). Three instances.

**Root cause**: `unwrap-or` has type `{A : Type} [Option A] A -> A`. The
polymorphic `A` should be inferred from `[some 42N]` (giving `A = Nat`), but
the qualified alias `opt::unwrap-or` may not carry the type information
correctly, or the two arguments don't propagate types to each other.

**Diagnosis needed**: Test whether the unqualified `unwrap-or` works (if
accessible), and whether explicit type application helps.

**Effort**: M
**Audit expressions**: audit-07 `opt::unwrap-or` (×2), audit-11 `opt::unwrap-or`
**Validation**: Un-comment all opt::unwrap-or tests

### Phase 4d: Collection Conversion Inference

**Problem**: `[into-vec '[1N 2N 3N]]` and `[into-list @[1N 2N 3N]]` both fail
with "Could not infer type" (audit-07). Also `[set-singleton 42N]`.

**Root cause**: These functions involve trait constraints (Seqable, Buildable)
with complex type parameter relationships. The trait resolution at top level
may not have enough context to select the right instance.

**Effort**: M–L (may require improvements to bidirectional inference for
trait-constrained functions at top level)
**Audit expressions**: audit-07 `into-vec`, `into-list`, `set-singleton`
**Validation**: Un-comment conversion tests

### Phase 4e: Multi-Bracket `fn` at Top Level

**Problem**: `[(fn [x : Nat] [y : Nat] [add x y]) 3N 4N]` → "Could not infer
type" (audit-05).

**Root cause**: Multi-bracket fn (curried parameter groups) produces a nested
fn structure. At top level without bidirectional context, the elaborator can't
resolve the curried application. This may work with explicit type annotations
on the fn.

**Effort**: S–M
**Audit expressions**: audit-05 multi-bracket fn
**Validation**: Un-comment, test with and without annotations

### Phase 4 Status

| Sub-phase | Status | Commit |
|-----------|--------|--------|
| 4a: Top-level if type | NOT STARTED | |
| 4b: sort/dedup constraints | NOT STARTED | |
| 4c: opt::unwrap-or inference | NOT STARTED | |
| 4d: Collection conversion | NOT STARTED | |
| 4e: Multi-bracket fn | NOT STARTED | |

---

## Phase 5: Narrowing Correctness

**Cluster**: C6 (Narrowing Correctness)
**Files**: `racket/prologos/reduction.rkt`, `racket/prologos/definitional-tree.rkt`
**Audit files affected**: audit-08

### Phase 5a: Shared Variable Constraint in Narrowing

**Problem**: `my-double ?x = 6N` returns `[{:x 6N} {:x 5N} {:x 4N} {:x 3N}]`
but only `x=3N` is valid (audit-08). The narrowing unfolds `my-double` to
`add ?x ?x` but then treats the two `?x` references as independent variables.

**Root cause**: When the narrowing engine unfolds a user function, it replaces
the function's formal parameters with the logic variables. If the function body
uses a parameter twice (like `add n n`), both occurrences should be the same
logic variable. But the narrowing for `add` then enumerates all `x+y=6`
solutions without enforcing `x=y`.

**Fix**: After unfolding, the narrowing engine must track that duplicated
parameter references share identity. When generating solutions, filter to only
those where shared variables have equal bindings. Alternatively, emit an
additional equality constraint `?x = ?y` when a parameter is used twice.

**Effort**: M
**Audit expressions**: audit-08 `my-double ?x = 6N`
**Validation**: Expect only `[{:x 3N}]`

### Phase 5b: Constructor Narrowing (suc, nested suc)

**Problem**: `[suc ?n] = 3N` → `nil` and `[suc [suc ?n]] = 5N` → `nil`
(audit-08). Bare constructor application doesn't create a narrowable
definitional tree.

**Root cause**: The narrowing engine only works through `match`-based
function definitions that create definitional trees. `suc` is a constructor,
not a `defn`, so there's no definitional tree to decompose. The narrowing
should recognize that `suc ?n = 3N` can be solved by pattern-matching on `3N`
as `suc 2N`, yielding `?n = 2N`.

**Fix**: Add a constructor-inversion rule to the narrowing engine. When the
LHS is a constructor applied to a logic variable and the RHS is a concrete
value of the same type, attempt to deconstruct the RHS using the inverse of
the constructor. For `suc`, this means checking if the RHS is `suc k` and
binding `?n = k`.

**Effort**: M
**Audit expressions**: audit-08 `[suc ?n] = 3N`, `[suc [suc ?n]] = 5N`
**Validation**: Expect `[{:n 2N}]` and `[{:n 3N}]`

### Phase 5c: Narrowing Through `if` (Boolean Functions)

**Problem**: `my-and ?a ?b = true` → `nil` (audit-08). The function uses
`if a b false`, but `if` doesn't generate a definitional tree.

**Root cause**: Only `match`-based definitions create definitional trees that
the narrowing engine can decompose. `if` is elaborated differently — it
doesn't produce the same case-split structure. The narrowing engine is
opaque to `if`.

**Fix options**:
1. Teach the narrowing engine to handle `if` as a case split (treat
   `if cond then-e else-e` as `match cond | true -> then-e | false -> else-e`)
2. Document that narrowable functions should use `match`, not `if`
3. Desugar `if` to `match` during elaboration (making them equivalent)

**Recommended**: Option 3 is the cleanest — `if` becomes sugar for a boolean
match, and narrowing works automatically.

**Effort**: S (option 3, if `if` already desugars to match) / M (option 1)
**Audit expressions**: audit-08 `my-and ?a ?b = true`
**Validation**: Expect `[{:a true, :b true}]`

### Phase 5 Status

| Sub-phase | Status | Commit |
|-----------|--------|--------|
| 5a: Shared variable constraint | NOT STARTED | |
| 5b: Constructor narrowing | NOT STARTED | |
| 5c: Narrowing through if | NOT STARTED | |

---

## DESIGN Notes (Non-Fix Items)

These are tracked here for completeness but are not bugs to fix. They may
inform future ergonomic improvements.

| ID | Finding | Disposition |
|----|---------|-------------|
| D1 | `nil` shows `?meta` in type | Cosmetic — pretty-print unsolved metas as `_` (separate ticket) |
| D2 | `head`/`tail`/`nth`/`last` return `Option` | Correct by design — add `head!` etc. partial variants later |
| D3 | Top-level sequential `let` scoping | Fixed by Phase 2i (`let` → `def` at top level) |
| D4 | `cond` emits `Hole ??__cond-fail` warning | Suppress internal hole in process-file output (separate ticket) |
| D5 | Constructor app in `def` needs brackets | Fixed by Phase 2b (auto-wrap multi-token RHS) |
| D6 | `=` overloaded equality/narrowing | By design — document the duality |
| D7 | `cons` pretty-prints as list literal | Desirable normalization — no action needed |

---

## Remaining Audit Gaps

These items were marked UNTESTED in the audit and should be verified during
or after the repair sprint:

| Item | Audit File | Notes |
|------|-----------|-------|
| Guard clauses (`when`) in match | audit-04 | May work, needs WS-mode test |
| `do` sequencing with `<-` bind | audit-05 | May require monadic context |
| `range` function signature | audit-07 | Audit says "Too many arguments" — check actual prelude sig |
| `pair 1N true` at top level | audit-03 | "Could not infer type" — may be fixed by Phase 4 improvements |
| `5/1` parsed as Int | audit-01 | Racket reader pre-simplifies — may need custom reader |

---

## Sprint Metrics

| Metric | Target |
|--------|--------|
| Total sub-phases | 22 |
| Estimated S fixes | 10 |
| Estimated M fixes | 10 |
| Estimated L fixes | 2 |
| Audit expressions to un-comment | ~36 (all CRASH) + ~6 (WRONG) |
| Regression test count | 5440 (must stay green) |

---

## Commits

| Phase | Commit | Date | Notes |
|-------|--------|------|-------|
| (planning) | | 2026-03-10 | This document |
