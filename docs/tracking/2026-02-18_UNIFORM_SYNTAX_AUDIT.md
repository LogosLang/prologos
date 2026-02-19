# Prologos Uniform Syntax & Homoiconicity Audit

**Date**: 2026-02-18
**Test count at time of audit**: 2592
**Scope**: Full language pipeline — readers, preparse macros, parser, elaborator, REPL, introspection

---

## Executive Summary

Prologos aims to be a **homoiconic language** where all code is representable as data, with uniform prefix-notation s-expression syntax, hygienic macros, and excellent introspection tooling. This audit examines the entire pipeline to identify gaps, asymmetries, and missing infrastructure that threaten this invariant.

**Overall assessment**: The core datum pipeline (reader → preparse → parser → elaborator) is structurally sound — all syntax forms desugar to well-defined s-expressions, and sentinel symbols are properly consumed at each stage. However, there are **3 critical asymmetries** between reader modes, **several missing introspection features**, and **non-macro rewrites** that bypass the inspectable macro system.

---

## 1. Reader Mode Parity: WS vs Sexp

Both reader modes should produce **identical datums** for equivalent inputs. This is the foundation of homoiconicity — a program means the same thing regardless of surface syntax.

### 1.1 Fully Symmetric Forms (No Issues)

These forms produce identical AST in both readers:

| Syntax | WS Reader | Sexp Reader | Datum |
|--------|-----------|-------------|-------|
| `<T>` | `($angle-type T)` | `($angle-type T)` | Identical |
| `{A B : Type}` | `($brace-params A B : Type)` | `($brace-params A B : Type)` | Identical |
| `'[1 2 3]` | `($list-literal 1 2 3)` | `($list-literal 1 2 3)` | Identical |
| `~[1 2 3]` | `($lseq-literal 1 2 3)` | `($lseq-literal 1 2 3)` | Identical |
| `@[1 2 3]` | `($vec-literal 1 2 3)` | `($vec-literal 1 2 3)` | Identical |
| `#{1 2 3}` | `($set-literal 1 2 3)` | `($set-literal 1 2 3)` | Identical |
| `~3.14` | `($approx-literal 3.14)` | `($approx-literal 3.14)` | Identical |
| `[x y z]` | plain list | plain list | Identical |
| `->`, `-0>`, `-1>`, `-w>` | arrow symbols | arrow symbols | Identical |
| `:0`, `:1`, `:w`, `:=` | keyword symbols | keyword symbols | Identical |
| `N/D` rationals | rational literal | rational literal | Identical |
| `,` separators | stripped in brackets/parens | stripped in brackets/parens | Identical |

### 1.2 Critical Asymmetries

#### ISSUE-A1: `$` Quote Operator [CRITICAL]

| Mode | Input | Datum Produced |
|------|-------|----------------|
| WS | `$Foo` | `($quote Foo)` |
| Sexp | `$Foo` | symbol `$Foo` |

**Root cause**: `sexp-readtable.rkt` has no custom reader for `#\$`. The WS reader (reader.rkt lines 1001-1010) converts `$X` to the 2-element list `($quote X)`, but the sexp readtable doesn't install a `$` handler.

**Impact**: `$` is currently used only for macro pattern variables in `defmacro`, where `normalize-quote-vars` converts `($quote X)` back to `$X`. The asymmetry is latent — it doesn't cause user-facing bugs today because `$` is internal-only — but it violates the principle that both readers produce identical datums.

**Fix**: Add `#\$` terminating-macro to `sexp-readtable.rkt` that reads the next token and wraps it as `($quote X)`.

#### ISSUE-A2: `...` Varargs Rest Parameters [CRITICAL]

| Mode | Input | Datum Produced |
|------|-------|----------------|
| WS | `...` (bare) | symbol `$rest` |
| WS | `...name` | `($rest-param name)` |
| Sexp | `...` | symbol `...` (no transformation) |
| Sexp | `...name` | symbol `...name` (no transformation) |

**Root cause**: `sexp-readtable.rkt` has no reader for `...`. The WS reader (reader.rkt lines 503, 1037-1046) tokenizes these specially.

**Impact**: Varargs specs written in WS mode (`spec f A ... -> B`) produce different datums than their sexp equivalents. Users writing sexp-mode code must use `($rest ...)` and `($rest-param name)` sentinels directly, which is undocumented.

**Fix**: Add `...` handling to `sexp-readtable.rkt`, or document the sexp-mode canonical forms.

#### ISSUE-A3: `>>` Compose Operator [MODERATE]

| Mode | Input | Datum Produced |
|------|-------|----------------|
| WS | `>>` | symbol `$compose` |
| Sexp | `>>` | symbol `>>` (standard Racket) |

**Root cause**: WS tokenizer (reader.rkt lines 343-345) converts `>>` to sentinel `$compose`. Sexp readtable has no override for `>`.

**Impact**: Users must write `($compose ...)` in sexp mode. The `|>` operator (`$pipe-gt`) has the same asymmetry, though it's less impactful since `|>` is primarily a block-form keyword in WS mode.

**Mitigation**: This is partially by design — `>>` and `|>` are WS-mode syntactic sugar. The canonical sexp forms `($pipe-gt ...)` and `($compose ...)` are the "true" representations. However, adding sexp readers for these would improve ergonomics.

### 1.3 Minor Asymmetries

#### ISSUE-A4: `|` Pipe Symbol Scope

- **WS mode**: `|` → `$pipe` globally (reader.rkt line 390)
- **Sexp mode**: `|` → `$pipe` only inside `<...>` angle brackets (sexp-readtable.rkt lines 27-30)

**Impact**: Low. Union types always appear inside `<...>`, so this rarely matters in practice.

#### ISSUE-A5: Bare `'` (Quote) Behavior

- **WS mode**: Bare `'` (not followed by `[`) → ERROR
- **Sexp mode**: Bare `'foo` → `(quote foo)` (standard Racket quote)

**Impact**: WS mode is more restrictive. This is intentional — WS mode reserves `'` exclusively for list literals `'[...]`. But it means `quote` as a concept doesn't have a WS-mode surface form.

---

## 2. Preparse Macro System

### 2.1 Registered Preparse Macros

All registrations in `macros.rkt` (lines 2287-2293):

| Symbol | Macro Function | Expansion |
|--------|---------------|-----------|
| `let` | `expand-let` | `(let [x := e] body)` → `((fn (x : _) body) e)` |
| `do` | `expand-do` | `(do [x := e] body)` → `(let [x : _ e] body)` |
| `if` | `expand-if` | `(if c t e)` → `(boolrec _ t e c)` |
| `$list-literal` | `expand-list-literal` | `($list-literal 1 2)` → `(cons 1 (cons 2 nil))` |
| `$lseq-literal` | `expand-lseq-literal` | `($lseq-literal 1 2)` → `(lseq-cell 1 (fn ...))` |
| `$pipe-gt` | `expand-pipe-block` | Block-form pipe with loop fusion |
| `$compose` | `expand-compose-sexp` | `(f $compose g)` → `(fn ($>>0 : _) (g (f $>>0)))` |

**All 7 macros produce valid s-expressions that users could write directly.** This is good.

### 2.2 Non-Macro Rewrites (Bypassing Macro Registry)

These transformations happen in the preparse pipeline but are **NOT registered as macros**, meaning they are **not visible via `(expand ...)` introspection**:

#### ISSUE-B1: Infix Operator Canonicalization [MODERATE]

`rewrite-infix-operators` (macros.rkt lines 2048-2057) rewrites infix `$pipe-gt` and `$compose` to prefix form before macro expansion:

```
Input:  (data $pipe-gt f a $pipe-gt g b)
Output: ($pipe-gt data (f a) (g b))
```

This is a datum→datum rewrite that happens in `preparse-expand-subforms` (line 617), outside the macro registry. The user cannot see this step via `(expand ...)`.

#### ISSUE-B2: Spec Injection [MODERATE]

`maybe-inject-spec` (macros.rkt lines 1350-1459) injects type annotations from `spec` declarations into `defn` parameters:

```
Spec:   (spec foo Nat -> Nat)
Input:  (defn foo [x] (add x 1))
Output: (defn foo [x ($angle-type Nat)] ($angle-type Nat) (add x 1))
```

This is metadata-driven rewriting, not a macro. It's invisible to `(expand ...)`.

#### ISSUE-B3: Where-Clause Injection [MODERATE]

`maybe-inject-where` (macros.rkt lines 1472-1554) desugars trait constraints into synthetic dict parameters:

```
Input:  (defn sum [xs] where (Add A) body)
Output: (defn sum [$Add-A ($angle-type (Add A))] [xs] body)
```

Also invisible to `(expand ...)`.

#### ISSUE-B4: Let Merging [MINOR]

`merge-sibling-lets` (macros.rkt lines 381-414) merges consecutive let bindings:

```
Input:  (defn f (let x := 1) (let y := 2 (+ x y)))
Output: (defn f (let (x := 1 y := 2) (+ x y)))
```

#### ISSUE-B5: Foreign Block Combining [MINOR]

`combine-foreign-blocks` (macros.rkt lines 514-611) merges consecutive `$foreign` forms:

```
Input:  (def f ($foreign (c1) ...) ($foreign (c2) ...) body)
Output: (def f ($foreign-block racket ((c1) (c2)) ...) body)
```

### 2.3 User-Defined Macros

Users can define macros via `defmacro` and `deftype`:

```prologos
(defmacro swap ($x $y) ($y $x))
(deftype Bool (fn (p : _) (p Unit Unit)))
(deftype (Pair $A $B) (fn [x $A] [y $B] body))
```

These register as pattern-template preparse macros. The `$`-prefixed variables in patterns/templates go through `normalize-quote-vars` to convert `($quote X)` → `$X`.

**User macros are fully homoiconic** — they are inspectable via `(expand ...)` and work identically in both reader modes.

---

## 3. Sentinel Symbol Inventory

Complete inventory of all `$`-prefixed sentinel symbols and where they are consumed:

### 3.1 Consumed by Preparse Macros (Before Parser)

| Sentinel | Generated By | Consumed By | User-Writable? |
|----------|-------------|-------------|----------------|
| `$list-literal` | Reader (`'[...]`) | `expand-list-literal` | No |
| `$lseq-literal` | Reader (`~[...]`) | `expand-lseq-literal` | No |
| `$list-tail` | Reader (`'[a \| xs]`) | `expand-list-literal` | No |
| `$pipe-gt` | Reader (`\|>`) | `expand-pipe-block` | No |
| `$compose` | Reader (`>>`) | `expand-compose-sexp` | No |
| `$rest` | Reader (`...`) | `desugar-rest-type` | No |
| `$rest-param` | Reader (`...name`) | `extract-param-names` | No |
| `$quote` | Reader (`$X`) | `normalize-quote-vars` (defmacro only) | No |

### 3.2 Consumed by Parser

| Sentinel | Generated By | Parser Handler | User-Writable? |
|----------|-------------|----------------|----------------|
| `$angle-type` | Reader (`<T>`) | `unwrap-angle-type` | No |
| `$brace-params` | Reader/Parser (`{...}`) | Context-dependent: `extract-implicit-binders` in spec/defn; `parse-map-literal` at top level | No |
| `$vec-literal` | Reader (`@[...]`) | `parse-pvec-literal` | No |
| `$set-literal` | Reader (`#{...}`) | `parse-set-literal` | No |
| `$approx-literal` | Reader (`~N`) | `parse-datum` | No |
| `$pipe` | Reader (`\|`) | `parse-match-arms` (for alternation) | No |
| `$foreign-block` | Preparse | Elaborator (foreign eval) | No |

### 3.3 Safety Assessment

**All sentinels are accounted for.** None can leak through to the elaborator without either being consumed or triggering a parse error. The pipeline is structurally sound.

### 3.4 Context-Dependent Sentinel: `$brace-params`

`$brace-params` has **dual semantics** depending on position:
- **In `spec`/`defn` leading position**: Interpreted as implicit type binders `{A B : Type}`
- **At expression level**: Interpreted as map literal `{:key val}`

This is handled correctly by the parser dispatching to different handlers based on context. However, it means `{...}` is **overloaded syntax** — a potential source of confusion for users, and a design point worth documenting clearly.

---

## 4. Introspection & Tooling

### 4.1 What Exists

| Feature | Status | Location | Notes |
|---------|--------|----------|-------|
| `(expand datum)` | Exists | `driver.rkt:196` | Shows preparse expansion result |
| `(parse datum)` | Exists | `driver.rkt:200` | Shows surface AST struct |
| `(elaborate expr)` | Exists | `driver.rkt:204` | Shows elaborated core AST (pretty-printed) |
| `:type expr` | Exists | `repl.rkt:218` | Type-checks and shows type |
| `:env` | Exists | `repl.rkt:199` | Dumps current environment |
| `:load "path"` | Exists | `repl.rkt:201` | Loads a file |
| `:quit` / `:q` | Exists | `repl.rkt:196` | Exits REPL |
| `(eval expr)` | Exists | `driver.rkt:172` | Top-level evaluation command |
| `defmacro` | Exists | `macros.rkt:918` | User-defined pattern-template macros |
| `deftype` | Exists | `macros.rkt:932` | Type alias macros |

### 4.2 What's Missing

#### ISSUE-C1: No `macroexpand-1` / Step-by-Step Expansion [HIGH]

Users can call `(expand datum)` but it shows only the **final** result after all macro expansions. There is no way to see expansion step by step:

```
> (expand (let x := 1 (if true x zero)))
;; Shows FINAL result — both let and if already expanded
;; No way to see: let expansion first, then if expansion
```

**Recommendation**: Implement `(expand-1 datum)` that expands only the outermost macro once.

#### ISSUE-C2: No Runtime `quote` Form [HIGH]

There is no user-facing `quote` form. Users cannot write:

```prologos
(quote (add 1 2))  ;; → the list (add 1 2) as data
```

`$quote` exists internally for macro pattern variables but is not exposed as a general-purpose quoting mechanism.

**Recommendation**: Implement `quote` as a core form that the parser recognizes and produces a list/symbol value at runtime. This is fundamental to code-as-data.

#### ISSUE-C3: No Runtime `eval` [HIGH]

`(eval expr)` exists as a top-level command but is **not a function** — it cannot be called within expressions:

```prologos
;; This works (top-level):
(eval (add 1 2))

;; This doesn't work (in expression position):
(defn run-code [code] (eval code))  ;; eval is not a function
```

**Recommendation**: This is a design decision — runtime `eval` requires embedding the compiler in the runtime. For Phase 0 (specification), this may be deferred.

#### ISSUE-C4: No `read` Form [MEDIUM]

No way to parse a string into Prologos data at runtime:

```prologos
(read "(add 1 2)")  ;; → the datum (add 1 2) — doesn't exist
```

**Recommendation**: Defer to later phases. Runtime `read` requires exposing the reader as a Prologos function.

#### ISSUE-C5: No Quasiquote / Unquote [MEDIUM]

No quasiquote mechanism for constructing code templates with computed parts:

```prologos
`(add ,x 2)  ;; → (add <value-of-x> 2) — doesn't exist
```

**Recommendation**: This is a significant feature. Could be implemented as a preparse macro that desugars to `cons`/`list` construction.

#### ISSUE-C6: Pretty-Print Cannot Round-Trip [MODERATE]

`pretty-print.rkt` produces human-readable output, but it is **not valid Prologos source**:
- Uses de Bruijn-to-name conversion with fresh names
- Contains internal struct notation
- Cannot be parsed back

**Recommendation**: Add a `pp-datum` mode that outputs valid Prologos sexp syntax, enabling parse → pp → parse round-trips.

#### ISSUE-C7: `(expand ...)` Doesn't Show Non-Macro Rewrites [MODERATE]

The `(expand ...)` command only shows preparse macro expansions. It does **not** show:
- Spec injection
- Where-clause injection
- Infix canonicalization
- Let merging

Users cannot see the full picture of how their code is transformed before parsing.

**Recommendation**: Add `(expand-full datum)` that shows the result after ALL preparse transformations (including injection).

#### ISSUE-C8: No REPL Shortcuts for Introspection [MINOR]

The REPL has `:type`, `:env`, `:load`, `:quit` but no:
- `:expand expr` — macro expansion
- `:parse expr` — surface AST
- `:elaborate expr` — core AST
- `:macros` — list registered macros
- `:specs` — list registered specs

These exist as `(expand ...)`, `(parse ...)`, `(elaborate ...)` forms but not as REPL commands.

---

## 5. Design Philosophy Notes

### 5.1 What Homoiconicity Means for Prologos

Prologos is not a Lisp — it has dependent types, session types, QTT, and a rich type system. Its homoiconicity operates at the **datum level**:

1. **All syntax is s-expressions** — WS mode is syntactic sugar that desugars to sexps
2. **Macros operate on datums** — pattern-template macros work on post-reader s-expressions
3. **Sentinel symbols are visible** — `$angle-type`, `$brace-params`, etc. are ordinary symbols, not hidden metadata
4. **The macro system is user-extensible** — `defmacro` and `deftype` are first-class

This is a **strong form of homoiconicity** — stronger than languages that have "macro" systems but where the transformations are opaque.

### 5.2 Where Prologos Differs from Lisp

- **No runtime eval** (yet) — code-as-data is a compile-time concept
- **No runtime quote** (yet) — quoting is internal to the macro system
- **Typed macros** — the type system constrains what macros can produce
- **Dependent types** — the line between "type" and "value" is blurred by design

### 5.3 The `$brace-params` Overloading Decision

`{...}` serves double duty: implicit binders in spec/defn and map literals at expression level. This is a conscious tradeoff:
- **Pro**: Fewer brackets to learn, familiar `{}` for maps
- **Con**: Context-dependent parsing, potential user confusion
- **Mitigation**: Parser context-switching is clean and well-tested

---

## 6. Prioritized Issue Summary

### Critical (Should Fix)

| ID | Issue | Effort | Impact |
|----|-------|--------|--------|
| A1 | `$` quote asymmetry between readers | Small | Violates reader parity invariant |
| A2 | `...` varargs asymmetry between readers | Small | Varargs broken in sexp mode |
| C2 | No runtime `quote` form | Medium | Core homoiconicity feature missing |

### High (Should Address)

| ID | Issue | Effort | Impact |
|----|-------|--------|--------|
| C1 | No `macroexpand-1` step expansion | Small | Limits macro debugging |
| C3 | No runtime `eval` | Large | Limits metaprogramming |
| C7 | `(expand ...)` hides non-macro rewrites | Medium | Limits transparency |
| B1-B3 | Non-macro rewrites bypass inspection | Medium | Transparency gap |

### Medium (Should Plan)

| ID | Issue | Effort | Impact |
|----|-------|--------|--------|
| A3 | `>>` compose asymmetry | Small | Ergonomic, not correctness |
| C4 | No runtime `read` | Medium | Limits metaprogramming |
| C5 | No quasiquote/unquote | Medium | Limits code construction |
| C6 | Pretty-print can't round-trip | Medium | Limits tooling |

### Low (Track for Future)

| ID | Issue | Effort | Impact |
|----|-------|--------|--------|
| A4 | `\|` pipe scope asymmetry | Small | Rare edge case |
| A5 | Bare `'` behavior difference | Trivial | By design |
| C8 | No REPL introspection shortcuts | Small | Ergonomic only |

---

## 7. Recommended Roadmap

### Phase I: Reader Parity (Small, High Value)

Fix the 3 critical reader asymmetries:
1. Add `$` handler to `sexp-readtable.rkt`
2. Add `...` handling to `sexp-readtable.rkt`
3. Optionally add `>>` and `|>` handling to `sexp-readtable.rkt`

**Estimated**: 1-2 sessions, ~20 tests

### Phase II: Introspection Tooling (Medium, High Value)

1. `(expand-1 datum)` — single-step macro expansion
2. `(expand-full datum)` — show all preparse transformations including injection
3. REPL `:expand`, `:parse`, `:elaborate`, `:macros`, `:specs` commands
4. Round-trippable pretty-printer mode

**Estimated**: 2-3 sessions, ~40 tests

### Phase III: Quote & Quasiquote (Medium-Large, Core Feature)

1. `(quote expr)` as a core form — produces list/symbol values
2. Quasiquote `` `(expr ,hole) `` as preparse macro
3. List/symbol operations in the stdlib for working with quoted data

**Estimated**: 3-4 sessions, ~60 tests

### Phase IV: Runtime Eval (Large, Deferred)

1. Runtime `(eval quoted-expr)` — requires embedding compiler in runtime
2. Runtime `(read string)` — requires exposing reader
3. Full REPL-in-language capability

**Estimated**: Significant effort, likely deferred past Phase 0

---

## 8. Appendix: File Reference

| File | Role in Pipeline |
|------|-----------------|
| `reader.rkt` | WS-mode reader — generates sentinel datums |
| `sexp-readtable.rkt` | Sexp-mode reader — generates sentinel datums |
| `macros.rkt` | Preparse macro registry, expansion, injection |
| `surface-syntax.rkt` | Surface AST struct definitions |
| `parser.rkt` | Datum → surface AST conversion |
| `elaborator.rkt` | Surface AST → core AST conversion |
| `driver.rkt` | Pipeline orchestration, `expand`/`parse`/`elaborate` commands |
| `repl.rkt` | Interactive REPL, `:type`/`:env`/`:load` commands |
| `pretty-print.rkt` | Core AST → human-readable string |
