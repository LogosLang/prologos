# Prologos Homoiconicity & Uniform Syntax — Roadmap & Work Log

**Created**: 2026-02-19
**Source audit**: `2026-02-18_UNIFORM_SYNTAX_AUDIT.md`
**Purpose**: Track implementation progress against the uniform syntax audit findings. Useful for future implementors to understand what was done, why, and what remains.

---

## Status Legend

- ✅ **Done** — implemented, tested, merged
- 🔧 **In Progress** — actively being worked on
- ⬚ **Not Started** — planned but no work yet
- ⏭️ **Deferred** — consciously postponed with rationale

---

## Phase I: Reader Parity

**Goal**: Both readers (WS and sexp) produce identical datums for equivalent inputs.
**Actual effort**: 1 session, 21 tests (estimated 1 session, ~15 tests)
**Dependencies**: None

### Completed

| ID | Issue | Status | Notes |
|----|-------|--------|-------|
| A1 | `$` quote asymmetry | ✅ 2026-02-18 | `$` is now an identifier prefix in both readers. `$foo` reads as plain symbol `$foo`. Removed `normalize-quote-vars` from macros.rkt. |
| A5 | `'expr` behavior difference | ✅ 2026-02-18 | `'expr` now produces `($quote expr)` in both WS and sexp modes. Was: WS mode errored on bare `'`, sexp mode produced Racket `(quote expr)`. |

#### Design Notes — A1/A5 (Quote Syntax Redesign)

The `$` and `'` changes were done together as a coherent redesign:

- **Before**: `$X` in WS mode → `($quote X)` via special `'dollar` token, then `normalize-quote-vars` in macros.rkt converted `($quote X)` back to `$X` for defmacro patterns. Sexp mode had no `$` handler at all.
- **After**: `$` is a plain identifier character (`ident-start?` + `ident-continue?`). `$foo` reads as the symbol `$foo` in both modes. No roundtrip needed.
- **`'expr`**: Enabled as quote operator in WS mode (was error). Both readers produce `($quote expr)`. Registered `$quote` as preparse macro (identity strip for now).
- **Rationale**: Follows the design decision in NOTES.org — `'` for quote (like Lisps), `$` for pattern variables (like regex/shell), clear separation of concerns.
- **Files changed**: `reader.rkt`, `sexp-readtable.rkt`, `macros.rkt`, `test-reader.rkt`, `test-list-literals.rkt`

### Remaining

| ID | Issue | Status | Notes |
|----|-------|--------|-------|
| A2 | `...` varargs: sexp readtable has no handler | ✅ 2026-02-19 | Consumer-side fix: `desugar-rest-type` now accepts both `$rest` and `...`; `spec-bare-param-list?` and `extract-param-names` accept `...name` symbols |
| A3 | `>>` compose: sexp readtable has no handler | ✅ 2026-02-19 | Consumer-side fix: `rewrite-infix-operators` normalizes `>>` → `$compose` before splitting |
| A3b | `\|>` pipe: sexp readtable has no handler | ✅ 2026-02-19 | Readtable fix: added `#\|` terminating-macro to `sexp-readtable.rkt` — `\|>` → `$pipe-gt`, bare `\|` → `$pipe` |
| A4 | `\|` pipe scope asymmetry | ✅ 2026-02-19 | Fixed as side effect of A3b — `\|` now globally produces `$pipe` in sexp mode (was scoped to `<...>` only) |

#### Design Notes — A2 (Varargs `...`)

We chose **consumer-side normalization** rather than a readtable handler for `.` because:
1. Racket's `.` is fundamental to dotted pairs — making it a terminating macro would break `(a . b)` syntax
2. The `...` symbol is also used by Prologos's own defmacro splice system (`$var ...` in patterns/templates), so a global `... → $rest` rewrite would break macro splicing
3. Consumer-side is safe: `desugar-rest-type` accepts both `$rest` and `...`; the `sexp-rest-param-sym?` helper extracts names from `...name` symbols

**Files changed**: `macros.rkt` (3 functions + 1 new helper)

#### Design Notes — A3 (Compose `>>`)

Same consumer-side approach as A2. `>>` already reads as a valid Racket symbol, so no readtable change needed. `rewrite-infix-operators` now maps `>>` → `$compose` before dispatching to existing compose rewriter.

**Files changed**: `macros.rkt` (1 function)

#### Design Notes — A3b/A4 (Pipe `|>` / `|`)

Used a **readtable handler** because `|` in Racket starts quoted symbols (`|foo bar|`), which would cause read errors for `|>`. The handler checks the next char: `>` → `$pipe-gt`, otherwise → `$pipe`. This also resolves A4 (the `|` scope asymmetry) as a free bonus — `|` now produces `$pipe` globally in sexp mode, matching WS behavior.

The inner readtable for `<...>` still overrides `|` with its own handler (producing `$pipe` for union types), so angle bracket behavior is unchanged.

**Files changed**: `sexp-readtable.rkt` (new handler + readtable registration)

---

## Phase II: Introspection Tooling

**Goal**: Make the full preparse pipeline visible and debuggable.
**Actual effort**: 2 sessions, 62 tests (estimated 2–3 sessions, ~40 tests)
**Dependencies**: None (Phase I helpful but not required)

### Completed

| ID | Feature | Status | Notes |
|----|---------|--------|-------|
| C1 | `expand-1` — single-step macro expansion | ✅ 2026-02-19 | New `preparse-expand-1` function, `surf-expand-1` struct, parser/elaborator/driver integration |
| C7 | `expand-full` — show ALL preparse transforms | ✅ 2026-02-19 | New `preparse-expand-full` returns labeled steps: input, def-assign, spec-inject, where-inject, infix-rewrite, macro-expand |
| C8 | REPL shortcuts: `:expand`, `:expand-1`, `:expand-full`, `:macros`, `:specs` | ✅ 2026-02-19 | 5 new REPL commands. `:macros` lists preparse registry (procedural vs pattern-template). `:specs` lists spec store. |
| C6 | `pp-datum` — round-trippable datum pretty-printer | ✅ 2026-02-19 | New `pp-datum` function in `pretty-print.rkt`, wired into `expand`/`expand-1`/`expand-full` output in `driver.rkt` |

#### Design Notes — C1 (expand-1)

`preparse-expand-1` performs exactly one expansion step at the outermost level. No recursion into subforms, no fixpoint loop. Returns the datum unchanged if no macro matches. Handles both procedural macros (do, let, if, $list-literal) and pattern-template macros (user `defmacro` definitions).

**Implementation detail — procedural macro behavior**: Built-in macros are procedures, not `preparse-macro` structs. Each has its own expansion logic:
- `(do expr)` with no bindings strips to just the body expression
- `(let x := 42 body)` transforms to `((fn (x : _) body) 42)` — an application of a fn
- `(if cond then else)` transforms to `(boolrec _ then else cond)`

User `defmacro` creates `preparse-macro` structs with pattern/template fields. `expand-1` uses `datum-match` + `datum-subst` for these, falling through to unchanged if the pattern doesn't match (e.g., wrong arity).

**Files changed**: `macros.rkt` (new function + provide), `surface-syntax.rkt` (new struct), `parser.rkt` (keyword + parsing), `elaborator.rkt` (passthrough), `driver.rkt` (dispatch)

#### Design Notes — C7 (expand-full)

`preparse-expand-full` applies all preparse transforms in explicit sequence, recording each step that produces a change:
1. **def-assign** — `:=` syntax expansion
2. **spec-inject** — `maybe-inject-spec`/`maybe-inject-spec-def` for def/defn
3. **where-inject** — `maybe-inject-where` for def/defn (guarded)
4. **infix-rewrite** — `rewrite-infix-operators` for `>>` → `$compose`, `|>` canonicalization
5. **macro-expand** — `preparse-expand-form` to fixpoint

**Key insight — inline pre-expansion**: When used inline as `(expand-full expr)`, the expr is pre-expanded by the pipeline before `expand-full` sees it, so macro-expansion steps may not appear. For example, `(expand-full (if True zero zero))` shows `boolrec` in the input step because `if` was already expanded. The feature is most useful via unit tests, REPL `:expand-full`, or for showing spec/where injection steps on `defn` forms.

**Key insight — where-inject guard**: `maybe-inject-where` must only be called on `def`/`defn` forms. Calling it on arbitrary forms (e.g., `(add 1 2)`) causes errors because it assumes the datum has `def`/`defn` structure. The guard `(memq (car after-spec) '(def defn))` was added after this was discovered during testing.

**Files changed**: `macros.rkt` (new function + provide + exports for internal helpers), `surface-syntax.rkt`, `parser.rkt`, `elaborator.rkt`, `driver.rkt`

#### Design Notes — C8 (REPL Shortcuts)

New REPL commands added to `handle-repl-command` in `repl.rkt`:
- `:expand expr` — wraps as `(expand expr)`, shows full preparse expansion
- `:expand-1 expr` — wraps as `(expand-1 expr)`, shows single-step
- `:expand-full expr` — wraps as `(expand-full expr)`, shows all transform steps with labels
- `:macros` — lists all entries in `current-preparse-registry` with type (procedural vs pattern→template)
- `:specs` — lists all entries in `current-spec-store` with type signatures

**Ordering constraint**: `:expand-full` and `:expand-1` use `string-prefix?` matching, so they must appear before `:expand` in the cond chain.

**Files changed**: `repl.rkt`

#### Design Notes — C6 (pp-datum)

`pp-datum` renders preparse datums (s-expressions with sentinel symbols) as readable Prologos syntax. Handles all sentinel forms:

| Sentinel | Output |
|----------|--------|
| `($quote expr)` | `'expr` |
| `($angle-type ...)` | `<...>` |
| `($brace-params ...)` | `{...}` |
| `$pipe-gt` | `\|>` |
| `$compose` | `>>` |
| `$pipe` | `\|` |
| `($list-literal ...)` | `'[...]` |
| `($list-tail expr)` | `\| expr` |
| `($set-literal ...)` | `#{...}` |
| `($vec-literal ...)` | `@[...]` |
| `($lseq-literal ...)` | `~[...]` |
| `$rest` | `...` |
| `($rest-param name)` | `...name` |
| `($approx-literal val)` | `~val` |
| `($quasiquote expr)` | `` `expr `` |
| `($unquote expr)` | `,expr` |

Wired into `driver.rkt`: `expand`, `expand-1`, and `expand-full` handlers now use `pp-datum` instead of `(format "~s" ...)`.

**Files changed**: `pretty-print.rkt` (new function + provide), `driver.rkt` (replace `~s` with `pp-datum`)

### Non-Macro Rewrites Made Visible (via C7)

| ID | Rewrite | Location | What It Does |
|----|---------|----------|-------------|
| B1 | Infix canonicalization | `rewrite-infix-operators` | `(data $pipe-gt f)` → `($pipe-gt data (f))` |
| B2 | Spec injection | `maybe-inject-spec` | Inserts type annotations from `spec` into `defn` params |
| B3 | Where-clause injection | `maybe-inject-where` | Desugars trait constraints into synthetic dict params |
| B4 | Let merging | `merge-sibling-lets` | Combines consecutive let bindings |
| B5 | Foreign block combining | `combine-foreign-blocks` | Merges consecutive `$foreign` forms |

**Note**: B4 (let merging) and B5 (foreign combining) happen in `preparse-expand-subforms` during recursive expansion. They are made visible by the macro-expand step in `expand-full` (the final expanded result reflects their effect). They are not individually labeled because they operate on sibling elements within a form, not at the top level.

---

## Phase III: Quote & Quasiquote

**Goal**: Full code-as-data: `(quote expr)` produces runtime values, quasiquote enables template-based code construction.
**Actual effort**: 1 session, 42 tests (estimated 3–4 sessions, ~60 tests)
**Dependencies**: Phase II helpful (for debugging quote expansion)

### Completed

| ID | Feature | Status | Notes |
|----|---------|--------|-------|
| C2 | Full runtime `quote` — `'expr` produces `Datum` values | ✅ 2026-02-19 | New `Symbol` primitive type (8-file pipeline), `Datum` algebraic data type (stdlib), `$quote` preparse macro desugars to datum constructors |
| C5 | Quasiquote / unquote — `` `(expr ,hole) `` | ✅ 2026-02-19 | `` ` `` and `,` readers in both sexp and WS modes, `$quasiquote` preparse macro with `($unquote expr)` passthrough |

### Design Decisions — Quote

- **`Datum` type chosen** over `(List Symbol)` or GADT encoding. `Datum` is an algebraic data type with 8 constructors: `datum-sym`, `datum-kw`, `datum-nat`, `datum-int`, `datum-rat`, `datum-bool`, `datum-nil`, `datum-cons`. This provides a clean, pattern-matchable representation.
- **New `Symbol` primitive type** added to the 8-file pipeline (following the `Keyword` pattern). `symbol-lit` is an internal parser keyword emitted by `$quote` — users don't write it directly.
- **Scope**: Phase III focuses on quote/unquote as *data construction*. Full `eval` is Phase IV.

#### Design Notes — C2 (Runtime Quote)

**Symbol type**: Added `expr-Symbol`/`expr-symbol` following the `Keyword` pattern exactly. `Symbol` is an opaque atomic type. `(symbol-lit foo)` produces a symbol literal. Both are pipeline passthroughs (zero-usage in QTT, values in reduction, no substitution/zonk needed).

**Datum algebraic data type**: Defined in `lib/prologos/data/datum.prologos` using the existing `data` declaration infrastructure. Key insight: multi-arg constructors use curried arrow syntax (`datum-cons : Datum -> Datum`), not space-separated (`datum-cons : Datum Datum`). All constructors, pattern matching, and `reduce` are generated automatically by `process-data`.

**$quote preparse macro**: Replaced the identity-strip `$quote` with `datum->datum-expr`, a recursive function that walks the quoted datum and emits Datum constructor calls:
- `'foo` → `(datum-sym (symbol-lit foo))`
- `'42` → `(datum-nat 42)`
- `'(add 1 2)` → `(datum-cons (datum-sym (symbol-lit add)) (datum-cons (datum-nat 1) (datum-cons (datum-nat 2) datum-nil)))`
- `':bar` → `(datum-kw :bar)` (keyword-like symbols detected by leading `:`)
- `'()` → `datum-nil`

**Files changed**: `syntax.rkt`, `surface-syntax.rkt`, `parser.rkt`, `elaborator.rkt`, `typing-core.rkt`, `qtt.rkt`, `reduction.rkt`, `substitution.rkt`, `zonk.rkt`, `pretty-print.rkt`, `macros.rkt`, new `lib/prologos/data/datum.prologos`, new `tests/test-quote.rkt`

#### Design Notes — C5 (Quasiquote)

**Sexp reader**: Added `` ` `` as a terminating macro in `sexp-readtable.rkt`. Inside backtick context, a **nested readtable** (`prologos-qq-readtable`) replaces the comma handler: `,expr` produces `($unquote expr)` instead of being skipped as a separator. Lazy initialization breaks the circular dependency between the outer readtable and the qq readtable.

**WS reader**: Added `backtick` and `comma` token types in `reader.rkt`. `parse-inline-element` handles them: `` `expr `` → `($quasiquote expr)`, `,expr` → `($unquote expr)`. Comma outside quasiquote context produces `($unquote expr)` which is harmless since the preparse layer doesn't recognize `$unquote` as a macro — it would cause a type error if used outside quasiquote.

**$quasiquote preparse macro**: `qq->datum-expr` is identical to `datum->datum-expr` except that `($unquote expr)` nodes are passed through raw (the `expr` itself, not quoted). This means `expr` must be of type `Datum` at runtime. No nested quasiquote depth tracking is needed for this initial implementation.

**Limitation**: No `unquote-splicing` (`,@`) support. Only single-element unquote (`,expr`) is implemented.

**Files changed**: `sexp-readtable.rkt` (backtick handler + qq readtable), `reader.rkt` (backtick/comma tokens + parser cases), `macros.rkt` (`$quasiquote` macro + `qq->datum-expr`), `tests/test-quote.rkt` (extended with quasiquote sections)

---

## Phase IV: Runtime Eval & Read

**Goal**: Full metaprogramming — evaluate quoted code at runtime, parse strings into Prologos data.
**Estimated effort**: 5+ sessions, ~80 tests
**Dependencies**: Phase III required

| ID | Feature | Status | Notes |
|----|---------|--------|-------|
| C3 | Runtime `eval` — evaluate quoted expressions | ⏭️ | Requires embedding compiler in runtime. Significant effort. |
| C4 | Runtime `read` — parse string to Prologos datum | ⏭️ | Requires exposing reader as Prologos function. |

### Design Considerations — Eval

- **Embedding the compiler**: `eval` needs access to elaborator, type-checker, and reducer at runtime. This is a large architectural change.
- **Security**: Runtime eval with dependent types raises questions about type safety — can `eval` produce ill-typed terms?
- **Phase 0 scope**: This may be deferred past Phase 0 (formal specification). The Phase 0 goal is a *verified spec*, not a production runtime.

---

## Deferred / Won't Fix

| ID | Issue | Reason |
|----|-------|--------|
| A4 | `\|` pipe global vs scoped | By design — global `\|` in sexp mode would break Racket `\|quoted\|` syntax |

---

## Cross-References

| Document | Contents |
|----------|----------|
| `2026-02-18_UNIFORM_SYNTAX_AUDIT.md` | Original audit — full technical details, sentinel inventory, file reference |
| `MEMORY.md` (project memory) | Living project state — test counts, sprint history, architectural patterns |
| `NOTES.org` / `NOTES.md` | Design conversations, quote syntax decision table |
| `bundle-design-philosophy.md` | Trait bundle design philosophy (related: where-clause injection in B3) |

---

## Session Log

### 2026-02-18 — Audit + Quote Syntax Redesign

- **Audit written**: `2026-02-18_UNIFORM_SYNTAX_AUDIT.md` — identified 5 reader asymmetries, 5 non-macro rewrites, 8 introspection gaps
- **A1 + A5 fixed**: Quote syntax redesign — `'` for quote, `$` for pattern vars, reader parity for both
- **Test count**: 2592 (all passing)

### 2026-02-19 — Phase I: Reader Parity (COMPLETE)

- **This document created**: Roadmap + work log
- **A2 fixed**: `...` varargs — consumer-side normalization in `desugar-rest-type`, `spec-bare-param-list?`, `extract-param-names`; new `sexp-rest-param-sym?` helper
- **A3 fixed**: `>>` compose — consumer-side normalization in `rewrite-infix-operators` maps `>>` → `$compose`
- **A3b fixed**: `|>` pipe — readtable handler in `sexp-readtable.rkt`, `|>` → `$pipe-gt`, `|` → `$pipe`
- **A4 fixed**: `|` pipe scope — resolved as side effect of A3b
- **21 new tests**: `test-sexp-reader-parity.rkt` — datum-level + end-to-end for all three operators
- **Test count**: 2613 (2592 + 21 new), all passing
- **Files changed**: `macros.rkt`, `sexp-readtable.rkt`, new `tests/test-sexp-reader-parity.rkt`

### 2026-02-19 — Phase II: Introspection Tooling (COMPLETE)

- **C1 implemented**: `expand-1` — new `preparse-expand-1` function (single-step, no recursion), `surf-expand-1` struct, full pipeline integration
- **C7 implemented**: `expand-full` — new `preparse-expand-full` function returning labeled `(label . datum)` pairs showing each transform step (input, def-assign, spec-inject, where-inject, infix-rewrite, macro-expand)
- **C8 implemented**: 5 new REPL commands — `:expand`, `:expand-1`, `:expand-full`, `:macros`, `:specs`
- **C6 deferred**: Round-trip pretty-printer — deferred to next session
- **Newly exported**: `rewrite-infix-operators`, `maybe-inject-spec`, `maybe-inject-spec-def`, `expand-def-assign` from macros.rkt for external introspection use
- **34 new tests**: `test-introspection.rkt` — expand-1 unit (11), expand-full unit (8), e2e sexp (6), regression (3), registry (6)
- **Test count**: 2647 (2613 + 34 new), all passing
- **Files changed**: `macros.rkt`, `surface-syntax.rkt`, `parser.rkt`, `elaborator.rkt`, `driver.rkt`, `repl.rkt`, new `tests/test-introspection.rkt`

### 2026-02-19 — C6 + Phase III: Quote & Quasiquote (COMPLETE)

- **C6 implemented**: `pp-datum` — round-trippable datum pretty-printer handling all sentinel forms. Wired into `expand`/`expand-1`/`expand-full` output in driver.rkt, replacing raw `(format "~s" ...)`.
- **C2 implemented**: Full runtime quote
  - New `Symbol` primitive type across 8-file pipeline (following `Keyword` pattern)
  - `Datum` algebraic data type in `lib/prologos/data/datum.prologos` (8 constructors: datum-sym/kw/nat/int/rat/bool/nil/cons)
  - `$quote` preparse macro replaced from identity-strip to `datum->datum-expr` recursive desugaring
  - `symbol-lit` internal parser keyword for creating symbol literals
- **C5 implemented**: Quasiquote / unquote
  - Backtick reader in both sexp (`sexp-readtable.rkt`) and WS (`reader.rkt`) modes
  - Nested readtable in sexp mode: `,expr` inside `` ` `` produces `($unquote expr)`
  - `$quasiquote` preparse macro: `qq->datum-expr` walks datum like `datum->datum-expr` but passes `($unquote expr)` through raw
- **70 new tests**: 28 in `test-introspection.rkt` (pp-datum), 42 in new `test-quote.rkt` (Symbol/Datum/quote/quasiquote)
- **Test count**: 2717 (2647 + 70 new), all passing
- **Files changed**: `pretty-print.rkt`, `driver.rkt`, `syntax.rkt`, `surface-syntax.rkt`, `parser.rkt`, `elaborator.rkt`, `typing-core.rkt`, `qtt.rkt`, `reduction.rkt`, `substitution.rkt`, `zonk.rkt`, `macros.rkt`, `sexp-readtable.rkt`, `reader.rkt`, `tests/test-introspection.rkt`, new `lib/prologos/data/datum.prologos`, new `tests/test-quote.rkt`
