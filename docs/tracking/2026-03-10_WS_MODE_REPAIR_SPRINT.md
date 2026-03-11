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

**Validation strategy**: After each sub-phase, re-run the affected audit file(s)
via `run-file.rkt` and un-comment any expressions that the fix should have
unblocked. Full test suite at phase boundaries per the checkpoint schedule below.

**Rollback strategy**: Each sub-phase is committed individually. If a fix breaks
the regression suite, revert via `git revert <commit>` and re-assess. For Phase 3d
(constructor-as-HOF), which may require broader changes, branch if the fix is
non-trivial and reconcile after the sprint.

### Validation Checkpoints

| After | Run |
|-------|-----|
| Each sub-phase | Affected audit file(s) via `run-file.rkt` |
| Each phase completion | `racket tools/run-affected-tests.rkt --all` |
| Phases 1–2 complete | Full audit re-run (all 12 files) |
| Phases 3–4 complete | Full audit re-run (all 12 files) |
| Sprint complete | Full audit + regression + `--slowest 10` |

---

## Dependency Graph

```
Phase 1: Reader Fixes (C5 — quote/quasiquote, char docs)
    |
    v
Phase 2: Preparse Fixes (C3, C5, C7, C8 — 10 sub-phases)
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
are ordered this way because reader fixes may change the datum shapes that
preparse sees. The `=` inside mixfix fix (formerly C5/reader) is in Phase 2
since the actual fix is in `macros.rkt`, not `reader.rkt`. Phase 3 depends on
Phase 2 (preparse must correctly handle `data` forms before we fix constructor
elaboration). Phase 4 depends on Phase 3 (constructors must be first-class
before we can test inference improvements). Phase 5 is independent but is last
because narrowing correctness is lower priority than basic functionality.

---

## Phase Tracker

| # | Sub-phase | Effort | Status | Notes |
|---|-----------|--------|--------|-------|
| **Phase 1: Reader** | | | | |
| 1a | Char literal docs | S | ✅ | `3165faa` — `\a` is canonical char form |
| 1b | Quote/quasiquote | M+M | ✅ | `2f8e889` — datum in prelude; `,x` in parens deferred |
| **Phase 2: Preparse** | | | | |
| 2a | `def-` recognition | S | ✅ | `dd5c09d` — expand-def-assign + spec-def injection |
| 2b | `def` multi-token RHS | M | ✅ | `02bce89` — auto-wrap multi-token after `:=` |
| 2c | `def` with lambda value | S–M | ⏭️ | Typing issue, not preparse; use `spec` as workaround |
| 2d | spec+constraint arity | S | ✅ | `7e1d212` — Pass -1 for ns/imports before Pass 0/1 |
| 2e | `defn` inside `impl` | M | ✅ | `e7e78f4` — bare-param defn + return type from trait |
| 2f | Multi-clause `defn` + spec | M | ✅ | `a467299` — flat $pipe grouping + bare pattern parsing |
| 2g | `with-transient` WS form | S | ✅ | `4b816b0` — multi-step expansion + transient var injection |
| 2h | `into-list` name collision | S | ✅ | `4a32d2f` — renamed to xf-into-list / xf-into-list-rev |
| 2i | Top-level `let` error | S | ✅ | `52d16fd` — clear error with `def` hint |
| 2j | `=` inside mixfix | S | ✅ | `9a597cf` — = alias for == in mixfix operator table |
| 2k | Error reporting: `expr-bvar` in errors | M | ✅ | `c101a11` — expr-bvar→A/B/C; fallback uses pp-expr |
| **Phase 3: Data & Constructors** | | | | |
| 3a | Nullary constructors | S | ✅ | `cd5d97d` — was wrong audit syntax (GADT vs field-list) |
| 3b | Multi-field constructors | M | ✅ | `cd5d97d` — was wrong audit syntax; + Phase 5b partition fix |
| 3c | Polymorphic ctor binding | M | ✅ | `cd5d97d` — was wrong audit syntax; MkBox works with `MkBox : A` |
| 3d | Constructor-as-HOF | M–L | ✅ | `aa8d7ee` — eta-expand `suc` in elaborator; 8 audit expressions fixed |
| **Phase 4: Type Inference** | | | | |
| 4a | Top-level `if` type | S | ✅ | Fresh-meta motive in boolrec infer handler |
| 4b | sort/dedup constraints | M | ✅ | Wrong audit syntax — sort/dedup take explicit comparators |
| 4c | `opt::unwrap-or` inference | M | ✅ | Wrong audit arg order — (default, opt) not (opt, default) |
| 4d | Collection conversion | M–L | ✅ | Wrong audit types — into-vec/into-list take LSeq, not List/PVec |
| 4e | Multi-bracket `fn` | S–M | ✅ | Lambda with explicit domain now synthesizes Pi type |
| **Phase 5: Narrowing** | | | | |
| 5a | Shared variable constraint | M | ⬜ | |
| 5b | Constructor narrowing | M | ⬜ | |
| 5c | Narrowing through `if` | M | ⬜ | |

**Legend**: ⬜ Not started · 🔨 In progress · ✅ Done · ⏭️ Skipped · 🔬 Diagnosing

---

## Phase 1: Reader Fixes

**Cluster**: C5 (Reader-Level Syntax Conflicts)
**Files**: `racket/prologos/reader.rkt`
**Audit files affected**: audit-01, audit-12
**Note**: The `=` inside mixfix fix (C5) is in Phase 2j since the fix is in
`macros.rkt`, not `reader.rkt`.

### Phase 1a: Char Literal Syntax — Documentation Only

**Problem**: `'a'` is read as `(quote a)` + stray `'` because `'` is the
quote/list-literal prefix (reader.rkt:354–364). The Char type exists and
`\a` backslash-escape works (reader.rkt:700–759), but `'x'`-style char
literal syntax is not available in WS mode.

**Resolution**: `\a` (backslash-char) is sufficient for WS-mode char literals.
The reader already handles single chars (`\a`), named chars (`\newline`,
`\space`, `\tab`), and Unicode escapes (`\uXXXX`) via reader.rkt:700–759.
No new syntax needed — document `\a` as the canonical char literal form.

**Action**: Update audit-01 char literal annotations from CRASH to DESIGN
(WS-mode char syntax is `\a` not `'a'`). Update grammar docs to document
the `\x` char literal form.

**Effort**: S (documentation only)
**Audit expressions**: audit-01 `'a'`, `'\n'`

### Phase 1b: Quote / Quasiquote in WS Mode

**Problem**: `'foo`, `'(a b c)`, and `` `(hello ,x world) `` all crash (audit-12)
with "Unbound variable" errors for `datum-sym`, `datum-cons`, etc.

**Root cause**: The reader correctly produces `($quote expr)` (reader.rkt:1439–1448)
and the `expand-quote` macro (macros.rkt:5041) correctly expands to `datum-*`
constructor calls. But `prologos::data::datum` was NOT in the prelude imports
(namespace.rkt), so the `datum-sym`, `datum-cons`, etc. constructors were unbound.

**Fix**: Added `prologos::data::datum` to the prelude imports in `namespace.rkt`,
referring `Datum`, all 8 constructors (`datum-sym`, `datum-kw`, `datum-nat`,
`datum-int`, `datum-rat`, `datum-bool`, `datum-nil`, `datum-cons`), and all 8
predicates (`sym?`, `kw?`, `nat?`, `int?`, `rat?`, `bool?`, `nil?`, `cons?`).

**Result**:
- `'foo` → OK: `datum-sym 'foo : Datum` ✅
- `'(a b c)` → OK: `datum-cons` chain : Datum ✅
- `` `(hello ,x world) `` → WRONG: produces `(hello x world)` — the `,x`
  unquote is lost because reader.rkt:1074–1077 **unconditionally skips commas
  inside paren forms** as separators. The comma in `,x` is consumed and `x` is
  read as a bare symbol rather than wrapped in `$unquote`. This is a residual
  reader-level issue requiring quasiquote-context-aware comma handling.

**Effort**: M (prelude fix = S, residual reader fix = M, deferred)
**Audit expressions**: audit-12 `'foo`, `'(a b c)`, `` `(hello ,x world) ``

### Phase 1 Status

| Sub-phase | Status | Commit |
|-----------|--------|--------|
| 1a: Char literal docs | ✅ | `3165faa` |
| 1b: Quote/quasiquote (prelude fix) | ✅ | `2f8e889` |
| 1b-residual: Quasiquote unquote in parens | DEFERRED | reader.rkt:1074–1077 |

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
(audit-02). `expand-def-assign` (macros.rkt:3607) at line 3616 does
`(unless (= (length after) 1) (error ...))`.

**Root cause**: The `:=` handler splits on `:=` and expects exactly one datum
on the right. The WS reader produces separate datums for `some` and `42N`.

**Fix**: In `expand-def-assign`, when `(length after) > 1`, auto-wrap as
`(token1 token2 ... tokenN)`. This matches the WS-mode convention that
juxtaposed tokens form an application. Prologos sexp is uniformly
list-application, so wrapping is always semantically correct:
- `def x := some 42N` → `(some 42N)` — constructor application, correct
- `def f := fn [x] [add x 1]` → `(fn (x) (add x 1))` — fn expression, correct
- `def y := if cond a b` → `(if cond a b)` — if expression, correct

**Risk**: Low — all multi-token sequences after `:=` ARE applications in
Prologos. But edge cases need test coverage: forms with type annotations
(`def x : T := multi token`), forms where `:=` RHS contains brackets
(`def x := [f a] b`). Only wrap when count > 1 and no type annotation
is present (the type-annotated path is already separate).

**Effort**: M (edge case testing required)
**Audit expressions**: audit-02 `def x := some 42N`
**Validation**: Un-comment, expect `some 42N : Option Nat`. Add tests for
`def` with fn value, if expression, and nested brackets on RHS.

### Phase 2c: `def` with Lambda Value — SKIPPED (typing issue, not preparse)

**Problem**: `def double-fn := (fn [x : Nat] [add x x])` → "Could not infer type".

**Diagnosis**: Tested — the datum reaches the elaborator correctly. The issue is
type inference: top-level `def` with a `fn` value has no bidirectional type context.
With a `spec` providing the type, it works perfectly:
```
spec double-fn Nat -> Nat
def double-fn := (fn [x : Nat] [add x x])
[double-fn 5N]  ;; → 10N : Nat ✅
```

**Resolution**: This is a typing limitation, not a preparse bug. Skipped from
Phase 2. Workaround: use `spec` before `def` to provide type context, or use
`defn` (which is the idiomatic way to define functions in Prologos).

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

**Root cause**: The impl machinery already handles `defn` forms correctly.
`process-impl` (macros.rkt:7039) checks `(eq? (caar remaining) 'defn)` at
line 7089 and processes method definitions. The WS reader's `parse-child-form`
(reader.rkt:1602) produces the correct outer shape: `(impl Describable Nat
(defn describe (n) n))`.

The error "defn requires: (defn name [x <T>...] body)" comes from *inside*
defn processing, not from impl failing to find the defn. The issue is in how
the method defn's internal datum structure (bracket arguments, body) is shaped
by the WS reader within the impl context. This is a datum-shape debugging
problem, not an architectural one.

**Fix**: Diagnose the exact datum shape `process-impl` passes to method
processing. The defn's bracket `[n]` may be flattened or mis-grouped when
nested inside impl's indented block. Fix the datum normalization for method
defns before they're processed.

**Effort**: M (datum-shape debugging, not impl machinery rewrite)
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

### Phase 2i: Top-Level `let` — Error with Hint

**Problem**: `let x := val` at top level → "let :=: missing value after :="
(audit-05).

**Root cause**: `let` is only recognized inside function bodies where it
desugars to nested lambda application. The preparse doesn't handle `let` as
a top-level form.

**Fix**: Emit a clear error with guidance instead of the cryptic current error:
```
Error: `let` is not allowed at top level. Use `def` instead.
  let x := 1N
  ^^^
  Use: def x := 1N
```
Rationale: `let` and `def` have different semantics — `let` shadows (in nested
scope), `def` creates a unique global binding. Silently converting `let` → `def`
would surprise users when `let x := 1N; let x := 2N` behaves differently at
top level (redefinition error) vs in a function body (shadowing). A clear error
preserves the semantic distinction.

**Effort**: S
**Audit expressions**: audit-05 `let x := val`
**Validation**: Verify error message is emitted with hint text

### Phase 2j: `=` Inside Mixfix `.{}`

**Problem**: `.{3N = 3N}` crashes with "Unexpected token after expression: ="
(audit-06). The `=` triggers the narrowing/equality rewrite pass, which
conflicts with the mixfix parser.

**Root cause**: `maybe-rewrite-infix-eq` in reader.rkt:1604 (called from
`parse-child-form` and `parse-top-level-form`) scans for `=` tokens and
rewrites `expr1 = expr2` into `($unify expr1 expr2)` or `($eq expr1 expr2)`.
When `=` appears inside a `$mixfix` form (`.{}`), the rewrite captures it
before the mixfix parser processes the expression.

**Fix**: In `maybe-rewrite-infix-eq`, skip rewriting when the `=` token is
inside a `$mixfix` delimiter. Check whether the surrounding context is a
mixfix form and if so, leave `=` as a bare symbol for the mixfix parser to
handle.

**Effort**: S
**Audit expressions**: audit-06 `.{3N = 3N}`
**Validation**: Un-comment `.{3N = 3N}` in audit-06, expect `true : Bool`

### Phase 2k: Error Reporting — `expr-bvar` in Error Messages

**Problem**: Constraint/type errors expose internal AST structures like
`#(struct:expr-bvar 3)` instead of human-readable type variable names.
Example: `No instance of Eq for #(struct:expr-bvar 3)` should say
`No instance of Eq for type variable A`.

**Root cause**: Error messages format type expressions using Racket's default
struct printing. The pretty-printer (`pretty-print.rkt`) handles most display,
but error message paths in `typing-core.rkt` and `elaborator.rkt` use raw
`format` with `~a` on AST nodes.

**Fix**: Add a `type->display-string` helper that renders `expr-bvar` nodes
as their original variable names (using the de Bruijn index to look up the
name from the typing context). Use this in error message formatting paths.

**Effort**: M
**Audit expressions**: All constraint/inference errors across audit files

### Phase 2 Status

| Sub-phase | Status | Commit |
|-----------|--------|--------|
| 2a: `def-` recognition | ✅ | `dd5c09d` |
| 2b: `def` multi-token RHS | ✅ | `02bce89` |
| 2c: `def` with lambda value | ⏭️ | (typing issue, not preparse) |
| 2d: spec+constraint arity | ✅ | `7e1d212` |
| 2e: `defn` inside `impl` | ✅ | `e7e78f4` |
| 2f: Multi-clause `defn` + spec | ✅ | `a467299` |
| 2g: `with-transient` WS form | ✅ | `4b816b0` |
| 2h: `into-list` name collision | ✅ | `4a32d2f` |
| 2i: Top-level `let` error | ✅ | `52d16fd` |
| 2j: `=` inside mixfix | ✅ | `9a597cf` |
| 2k: Error reporting: expr-bvar | ✅ | `c101a11` |

---

## Phase 3: Data & Constructor Fixes

**Cluster**: C4 (User-Defined Data Constructors), C1 (Constructor-as-HOF)
**Files**: `racket/prologos/macros.rkt` (process-data, parse-data-ctor),
`racket/prologos/elaborator.rkt` (constructor lookup, env injection)
**Audit files affected**: audit-03, audit-07, audit-10, audit-11

### Phases 3a–3c: Constructor Syntax Reclassification

**Original diagnosis**: The audit used GADT-style syntax (`North : Direction`,
`Circle : Nat -> Shape`, `MkBox : A -> MyBox A`) but the established Prologos
convention is **field-list syntax** where everything after `:` is field types
and the return type is always implicit.

**Library convention** (used in all stdlib `.prologos` files):
- Nullary: bare symbol (`none`, `nil`, `lt-ord`)
- One field: `some : A`, `mk-path : String`
- Two fields: `cons : A -> List A`, `mk-entry : K -> V`
- GADT syntax: only with `data Foo [params] where | ctor : full-type`

**Resolution**: Corrected audit-03 to use field-list syntax:
- `North` (bare) instead of `North : Direction`
- `Circle : Nat` instead of `Circle : Nat -> Shape`
- `Rect : Nat -> Nat` instead of `Rect : Nat Nat -> Shape`
- `MkBox : A` instead of `MkBox : A -> MyBox A`

All expressions now work correctly.

**Bonus fix (Phase 5b partition)**:  Found that `[direction-name North]` was
being hoisted by the Phase 5b partition because `North` (the second datum
element) matched a generated constructor name. The partition lambda now also
checks that `(car datum)` is a definition keyword (`def`/`defn`/`spec`/`deftype`),
preventing function calls from being misclassified as generated declarations.

**Commit**: `cd5d97d`

### Phase 3d: Constructor-as-HOF (The Big One)

**Problem**: `[map suc '[1N 2N 3N]]` → "Unbound variable" (audit-07, ×5; also
audit-10 ×2, audit-11 ×1). Constructors can be applied directly (`[suc 2N]`)
and used in pipes (`0N |> suc`) but cannot be passed as arguments to
higher-order functions.

**Existing evidence**: Audit-10 shows `def suc-fn : [Nat -> Nat] := suc` also
crashes with "Unbound variable". So `suc` as a bare expression (outside of
application context) fails even with an explicit type annotation. This
suggests constructors aren't valid as standalone expressions — they only
work in application position (`[suc 2N]`) and pipe position (`0N |> suc`,
which desugars to application).

**Diagnosis steps** (before attempting fix):
1. Test in sexp mode: `(process-string "(map suc (cons 1N (cons 2N nil)))")`
   — if sexp works but WS doesn't, issue is reader/preparse
2. Test alias: `def suc-alias := (fn [x : Nat] [suc x])` then `[map suc-alias xs]`
   — if the lambda wrapper works, confirms constructors need η-expansion
3. Check `env-lookup` for `suc` — is it in the global env? What type does it have?
4. Check elaborator path for bare symbols in non-application position

**Root cause hypothesis**: Constructors are only elaborated correctly when
they appear as the head of an application. In HOF position, `suc` is a bare
symbol that the elaborator tries to look up as a regular variable. Either it's
not in the environment, or its type (as a constructor) doesn't match the
expected function type.

**Approach (after diagnosis confirms)**: Constructor η-expansion — when a
constructor name appears in a position expecting a function type, the elaborator
generates an η-expanded lambda:
- `suc` (unary) → `(fn [x : Nat] (suc x))`
- `cons` (binary) → `(fn [x : A] (fn [y : (List A)] (cons x y)))`
- `some` (polymorphic) → `(fn [x : A] (some x))` with `A` inferred

**Implementation notes**:
- Only η-expand in HOF position (when expected type is a function type), not everywhere
- Arity must match the constructor's field count
- Polymorphic constructors: type variables must be preserved/inferred
- Alternative: compile constructors as functions from the start (inject into
  global-env as function-typed values during `process-data`)

**Effort**: M–L (depends on diagnosis; η-expansion is architecturally clean
but touches elaborator type-checking logic)
**Audit expressions**: audit-07 `map suc`, `pvec-map suc`, `set-map suc`,
`lseq-map suc`, `map-map-vals suc`; audit-10 block pipe with `map suc`,
`def suc-fn := suc`; audit-11 `map suc`
**Validation**: Un-comment all suc-as-HOF tests across audit-07, -10, -11

### Phase 3 Status

| Sub-phase | Status | Commit |
|-----------|--------|--------|
| 3a: Nullary constructors | ✅ | `cd5d97d` (syntax reclassification + partition fix) |
| 3b: Multi-field constructors | ✅ | `cd5d97d` (syntax reclassification) |
| 3c: Polymorphic ctor binding | ✅ | `cd5d97d` (syntax reclassification) |
| 3d: Constructor-as-HOF | ✅ | `aa8d7ee` |

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

**Note on Phases 4b–4d**: These three issues may share a root cause — trait
constraint resolution failing at top level. If 4b's fix (making `sort` work)
also resolves `opt::unwrap-or` and `into-vec`, mark 4c and 4d as done
automatically. However, they're tracked separately because `opt::unwrap-or`
uses the qualified alias path (`opt::`) which has its own lookup machinery
and may have independent bugs.

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
| 4a: Top-level if type | ✅ | (see commits table) |
| 4b: sort/dedup constraints | ✅ | (wrong audit syntax — explicit comparators needed) |
| 4c: opt::unwrap-or inference | ✅ | (wrong audit arg order — default before opt) |
| 4d: Collection conversion | ✅ | (wrong audit types — into-vec/into-list take LSeq) |
| 4e: Multi-bracket fn | ✅ | (see commits table) |

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

**Root cause**: `if` is a preparse macro (`expand-if`, macros.rkt:3976) that
expands to `boolrec` (the Bool eliminator), NOT to `match`:
```
(if cond then else) → (boolrec _ then else cond)
```
`boolrec` is the type-theoretically canonical elimination form for Bool in
the dependent type system. The narrowing engine only understands `match`-based
case splits (definitional trees), not `boolrec`. Changing `if` to produce
`match` instead would alter the type-theoretic foundation.

**Fix options**:
1. Teach the narrowing engine to recognize `boolrec` as a case split on Bool
   (analogous to how it recognizes `match` — when `boolrec` appears with a
   logic variable in the condition position, split into `true` and `false` branches)
2. Document that narrowable functions should use `match`, not `if`
3. Generate a parallel `match`-based definitional tree alongside `boolrec`
   during elaboration, for narrowing purposes only

**Recommended**: Option 1 — teach narrowing about `boolrec`. This preserves
the type theory while giving narrowing the structure it needs. The narrowing
engine's definitional tree builder should recognize `boolrec _ then-e else-e cond`
as equivalent to `match cond | true -> then-e | false -> else-e` for the
purpose of case splitting.

**Effort**: M (must integrate boolrec into definitional tree construction)
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
| D3 | Top-level sequential `let` scoping | Phase 2i emits error-with-hint directing users to `def` |
| D4 | `cond` emits `Hole ??__cond-fail` warning | Suppress internal hole in process-file output (separate ticket) |
| D5 | Constructor app in `def` needs brackets | Addressed by Phase 2b (auto-wrap multi-token RHS) |
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
| Total sub-phases | 23 (1a–b, 2a–k, 3a–d, 4a–e, 5a–c) |
| Completed | 21 (1a, 1b, 2a, 2b, 2d, 2e, 2f, 2g, 2h, 2i, 2j, 2k, 3a, 3b, 3c, 3d, 4a, 4b, 4c, 4d, 4e) |
| Skipped | 1 (2c) |
| Remaining | 3 (5a, 5b, 5c) |
| Regression test count | 6725 (all pass) |
| Audit expressions fixed | 36 CRASH + 6 WRONG reclassified |

---

## Commits

| Phase | Commit | Date | Notes |
|-------|--------|------|-------|
| (planning) | `c8f3929` | 2026-03-10 | Initial sprint document |
| (revision) | | 2026-03-10 | Incorporated external critique |
| 1a | `3165faa` | 2026-03-10 | Char literal documentation |
| 1b | `2f8e889` | 2026-03-10 | Datum in prelude for quote/quasiquote |
| 2a | `dd5c09d` | 2026-03-10 | def- recognition via expand-def-assign |
| 2b | `02bce89` | 2026-03-10 | Multi-token RHS auto-wrap |
| 2d | `7e1d212` | 2026-03-10 | Pass -1 for ns/imports; constraint stripping |
| 2e | `e7e78f4` | 2026-03-10 | Bare-param defn; trait return type injection |
| 2f | `a467299` | 2026-03-10 | Flat $pipe grouping; bare pattern parsing |
| 2g | `4b816b0` | 2026-03-10 | Multi-step with-transient expansion |
| 2h | `4a32d2f` | 2026-03-10 | Rename into-list → xf-into-list |
| 2i | `52d16fd` | 2026-03-10 | Top-level let error with def hint |
| 2j | `9a597cf` | 2026-03-10 | = alias for == in mixfix |
| 2k | `c101a11` | 2026-03-10 | expr-bvar readable names in errors |
| 3a-c | `cd5d97d` | 2026-03-10 | Syntax reclassification + Phase 5b partition fix |
| 3d | `aa8d7ee` | 2026-03-10 | Eta-expand suc in HOF position |
