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
**Estimated effort**: 1 session, ~15 tests
**Dependencies**: None

### Completed

| ID | Issue | Date | Notes |
|----|-------|------|-------|
| A1 | `$` quote asymmetry | 2026-02-18 | `$` is now an identifier prefix in both readers. `$foo` reads as plain symbol `$foo`. Removed `normalize-quote-vars` from macros.rkt. |
| A5 | `'expr` behavior difference | 2026-02-18 | `'expr` now produces `($quote expr)` in both WS and sexp modes. Was: WS mode errored on bare `'`, sexp mode produced Racket `(quote expr)`. |

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
**Estimated effort**: 2–3 sessions, ~40 tests
**Dependencies**: None (Phase I helpful but not required)

| ID | Feature | Status | Notes |
|----|---------|--------|-------|
| C1 | `expand-1` — single-step macro expansion | ⬚ | Currently `(expand datum)` shows only final result |
| C7 | `expand-full` — show ALL preparse transforms (including spec/where injection, infix canonicalization, let merging) | ⬚ | Currently these 5 non-macro rewrites (B1–B5) are invisible |
| C8 | REPL shortcuts: `:expand`, `:parse`, `:elaborate`, `:macros`, `:specs` | ⬚ | Currently only `:type`, `:env`, `:load`, `:quit` |
| C6 | Round-trippable pretty-printer (`pp-datum` mode) | ⬚ | Current pretty-printer produces human-readable but non-parseable output |

### Non-Macro Rewrites to Make Visible (via C7)

| ID | Rewrite | Location | What It Does |
|----|---------|----------|-------------|
| B1 | Infix canonicalization | `rewrite-infix-operators` | `(data $pipe-gt f)` → `($pipe-gt data (f))` |
| B2 | Spec injection | `maybe-inject-spec` | Inserts type annotations from `spec` into `defn` params |
| B3 | Where-clause injection | `maybe-inject-where` | Desugars trait constraints into synthetic dict params |
| B4 | Let merging | `merge-sibling-lets` | Combines consecutive let bindings |
| B5 | Foreign block combining | `combine-foreign-blocks` | Merges consecutive `$foreign` forms |

---

## Phase III: Quote & Quasiquote

**Goal**: Full code-as-data: `(quote expr)` produces runtime values, quasiquote enables template-based code construction.
**Estimated effort**: 3–4 sessions, ~60 tests
**Dependencies**: Phase II helpful (for debugging quote expansion)

| ID | Feature | Status | Notes |
|----|---------|--------|-------|
| C2 | Full runtime `quote` — `(quote expr)` produces list/symbol values | ⬚ | Currently `$quote` is identity-strip preparse macro. Need: new AST node, type (`Datum`?), reducer that builds runtime values |
| C5 | Quasiquote / unquote — `` `(expr ,hole) `` | ⬚ | Preparse macro desugaring to `cons`/`list` construction. Reader needs `` ` `` and `,` handlers |

### Design Considerations — Quote

- **What type does `(quote (add 1 2))` have?** Options: (a) a new `Datum` type, (b) `(List Symbol)`, (c) a GADT encoding. This needs design work.
- **Interaction with dependent types**: Quoted code is untyped data — how does it interact with the typed world? `eval` would need to re-elaborate.
- **Scope**: Phase III focuses on quote/unquote as *data construction*. Full `eval` is Phase IV.

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
