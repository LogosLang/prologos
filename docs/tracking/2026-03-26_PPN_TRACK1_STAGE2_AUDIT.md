# PPN Track 1 Stage 2 Audit: `reader.rkt` — Lexer + Structure as Propagators

**Date**: 2026-03-26
**Series**: PPN (Prologos Propagator Network) — Parsing
**Track**: Track 1 — Lexer + Structure as Propagators
**Status**: Stage 2 (Audit)
**File**: `racket/prologos/reader.rkt`

**Related docs**:
- [PPN Master](./2026-03-26_PPN_MASTER.md)
- [PPN Track 0 PIR](./2026-03-26_PPN_TRACK0_PIR.md)
- [PPN Track 0 Lattice Design](./2026-03-26_PPN_TRACK0_LATTICE_DESIGN.md)

---

## S1. File Metrics

| Metric | Value |
|--------|-------|
| Total lines | 1898 (+ 1 trailing blank) |
| `define` forms (functions + values) | 54 |
| Exported functions/values | 7 |
| `struct` definitions | 3 (`token`, `tokenizer`, `parser`) |
| Parameters | 1 (`current-qq-depth`) |

### Exports

| Name | Type | Used by |
|------|------|---------|
| `prologos-read` | `port -> datum` | `test-process-ws-01.rkt` |
| `prologos-read-syntax` | `source port -> syntax` | `repl.rkt`, `test-reader.rkt` |
| `prologos-read-syntax-all` | `source port -> (listof syntax)` | `driver.rkt` (via `read-all-syntax-ws`), `test-property-ws.rkt`, `test-functor-ws.rkt`, `test-config-audit.rkt` |
| `tokenize-string` | `string -> (listof token)` | `test-reader.rkt`, `test-reader-relational.rkt`, `test-approx-literal.rkt`, `test-negative-literals.rkt`, `test-varargs.rkt`, `test-extended-spec.rkt` |
| `read-all-forms-string` | `string -> (listof datum)` | `test-reader.rkt`, `test-lseq-literal.rkt`, `test-approx-literal.rkt`, `test-negative-literals.rkt`, `test-varargs.rkt`, `bench-ppn-track0.rkt`, `form-deps.rkt` |
| `token-type` | struct accessor | `bench-ppn-track0.rkt` (internal self-use in reader.rkt) |
| `token-value` | struct accessor | `bench-ppn-track0.rkt` (internal self-use in reader.rkt) |

### Require Dependencies

reader.rkt imports only:
1. `racket/match`
2. `racket/string`

This is a remarkably lean dependency footprint. The reader is entirely self-contained.

### Reverse Dependencies (Direct `require` of `reader.rkt`)

**Production code (3 files)**:
1. `driver.rkt` — calls `prologos-read-syntax-all` in `read-all-syntax-ws`
2. `repl.rkt` — calls `prologos-read-syntax` for REPL input
3. `tools/form-deps.rkt` — calls `read-all-forms-string` for dependency analysis

**Benchmarks (1 file)**:
4. `benchmarks/micro/bench-ppn-track0.rkt` — calls `read-all-forms-string` for pipeline baseline measurement

**Test files (50 files)** — all require `"../reader.rkt"`:
- 2 are dedicated reader tests: `test-reader.rkt`, `test-reader-relational.rkt`
- 48 are WS-mode integration tests that use `read-all-forms-string`, `prologos-read-syntax-all`, or `tokenize-string` as part of WS pipeline testing

### Test Coverage

| Test file | Test cases | Exercises |
|-----------|-----------|-----------|
| `test-reader.rkt` | 49 | Tokenizer (symbols, numbers, strings, keywords, colons, operators, brackets, comments, indentation), parser (single-line, multi-line, nested indent, bracket grouping, blank lines, brace params, commas), round-trip correctness, source locations, := tokenization |
| `test-reader-relational.rkt` | 10 | `\|\|` (facts-sep), `\|` (pipe), `\|>` (pipe-gt), `&>` (clause-sep), `&` (error), mode prefixes (`?x`, `+x`, `-x`), mixed relational context |

**Total dedicated reader tests**: 59

**Coverage gaps** (token types/forms NOT directly tested in reader tests):
- `approx-literal` (~N) — tested in `test-approx-literal.rkt`
- `decimal-literal` (3.14) — tested in `test-decimal-literal.rkt`
- `nat-literal` (42N) — tested indirectly in round-trip tests
- `char` literals (\\a, \\newline, \\uXXXX) — tested in `test-char-string-01.rkt`
- `dot-access` (.field), `dot-key` (.:kw) — tested in `test-dot-access-01/02.rkt`
- `broadcast-access` (.*field) — no dedicated reader test found
- `nil-dot-access` (#.field), `nil-dot-key` (#:kw, #.:kw) — tested in `test-nil-type.rkt`
- `typed-hole` (??, ??name) — tested in `test-extended-spec.rkt`
- `rest-param` (...name) — tested in `test-varargs.rkt`
- `path-literal` (#p(...)) — no reader-level test found
- `mixfix` (.{...}) — tested in `test-mixfix-01/02.rkt`
- `set-literal` (#{...}) — tested in `test-set.rkt`
- `lseq-literal` (~[...]) — tested in `test-lseq-literal.rkt`
- `vec-literal` (@[...]) — tested in `test-pvec.rkt`
- Postfix indexing (xs[0]) — tested in `test-postfix-index-01/03.rkt`
- Quasiquote/unquote — tested in `test-quote.rkt`
- Negative literals (-42, -3/7, -3.14) — tested in `test-negative-literals.rkt`
- Infix `=` rewriting — tested in `test-narrow-syntax-01/02.rkt`

---

## S2. Character Pattern Inventory

### Identifiers

| Pattern | ident-start? | ident-continue? | Notes |
|---------|:---:|:---:|-------|
| `a-z A-Z` | Y | Y | Alphabetic |
| `_` | Y | Y | Underscore |
| `-` | Y | Y | Hyphen (also triggers `->`, `-0>`, `-1>`, `-w>`, negative literal checks BEFORE ident) |
| `+` | Y | Y | Plus (also triggers `+>` check BEFORE ident) |
| `*` | Y | Y | Star |
| `/` | Y | Y | Slash (also in qualified names) |
| `=` | Y | Y | Equals |
| `$` | Y | Y | Dollar (defmacro pattern vars) |
| `0-9` | N | Y | Numeric continuation |
| `?` | N | Y | Predicate suffix |
| `!` | N | Y | Mutation suffix |
| `'` | N | Y | Prime suffix (e.g., `x'`) |
| `^` | N | Y | Rename suffix (key^rename in paths) |

### Namespace Separator

| Pattern | Produces | Notes |
|---------|----------|-------|
| `::` (inside identifier) | Part of single symbol | `nat::add` -> symbol `nat::add`. Only consumed when preceded by ident chars and followed by ident-start char |

### Keywords

| Pattern | Token type | Token value | Notes |
|---------|-----------|-------------|-------|
| `:name` | `keyword` | `:name` | Colon + alphabetic |
| `:widget` | `keyword` | `:widget` | `:w` followed by more ident chars = keyword, not multiplicity |
| `:=` | `symbol` | `:=` | Assignment operator |
| `:0` | `symbol` | `:0` | Multiplicity annotation (erased) |
| `:1` | `symbol` | `:1` | Multiplicity annotation (linear) |
| `:w` | `symbol` | `:w` | Multiplicity annotation (unrestricted) — standalone only |
| `:` (bare) | `colon` | `#f` | Freestanding colon (type annotation separator) |

### Numbers

| Pattern | Token type | Token value | Notes |
|---------|-----------|-------------|-------|
| `42` | `number` | `42` | Integer literal |
| `3/7` | `number` | `3/7` | Fraction literal (exact rational) |
| `3.14` | `decimal-literal` | `157/50` | Decimal -> exact rational |
| `42N` | `nat-literal` | `42` | Nat literal (N suffix) |
| `-42` | `number` | `-42` | Negative integer (special dispatch before ident) |
| `-3/7` | `number` | `-3/7` | Negative fraction |
| `-3.14` | `decimal-literal` | `-157/50` | Negative decimal |
| `-3N` | ERROR | - | Negative Nat is rejected |

### Strings

| Pattern | Token type | Notes |
|---------|-----------|-------|
| `"hello"` | `string` | Standard string literal |
| `"hello\nworld"` | `string` | Escape sequences: `\n`, `\t`, `\\`, `\"` |
| Unterminated | ERROR | "Unterminated string literal" |

### Character Literals

| Pattern | Token type | Token value | Notes |
|---------|-----------|-------------|-------|
| `\a` | `char` | `#\a` | Single character |
| `\newline` | `char` | `#\newline` | Named character |
| `\space` | `char` | `#\space` | Named character |
| `\tab` | `char` | `#\tab` | Named character |
| `\return` | `char` | `#\return` | Named character |
| `\backspace` | `char` | `#\backspace` | Named character |
| `\formfeed` | `char` | `#\formfeed` | Named character |
| `\u0041` | `char` | `#\A` | Unicode escape (4 hex digits) |
| `\u` (non-hex) | `char` | `#\u` | Fallback: literal 'u' |

### Operators and Punctuation

| Pattern | Token type | Token value | Notes |
|---------|-----------|-------------|-------|
| `->` | `symbol` | `->` | Arrow (dispatched before ident) |
| `-0>` | `symbol` | `-0>` | Multiplied arrow (dispatched before ident) |
| `-1>` | `symbol` | `-1>` | Multiplied arrow |
| `-w>` | `symbol` | `-w>` | Multiplied arrow |
| `+>` | `symbol` | `+>` | Session choice (dispatched before ident) |
| `\|>` | `symbol` | `$pipe-gt` | Pipe operator |
| `\|` | `symbol` | `$pipe` | Match arm separator |
| `\|\|` | `symbol` | `$facts-sep` | Fact block separator |
| `>>` | `symbol` | `$compose` | Compose operator (only outside angle brackets) |
| `&>` | `symbol` | `$clause-sep` | Clause separator |
| `&` (alone) | ERROR | - | Must be `&>` |
| `!` | `symbol` | `!` + rest | Session send |
| `!!` | `symbol` | `!!` | Async send |
| `!:` | `symbol` | `!:` | Dependent send |
| `?:` | `symbol` | `?:` | Dependent receive |
| `#=` | `symbol` | `#=` | Narrowing operator |

### Delimiters

| Pattern | Token type | Notes |
|---------|-----------|-------|
| `[` | `lbracket` | Primary grouping; increments bracket-depth |
| `]` | `rbracket` | Decrements bracket-depth |
| `(` | `lparen` | Parser keyword grouping; increments bracket-depth |
| `)` | `rparen` | Decrements bracket-depth |
| `{` | `lbrace` | Implicit type params / maps; increments bracket-depth |
| `}` | `rbrace` | Decrements bracket-depth |
| `<` | `langle` | Type grouping; increments both bracket-depth and angle-depth |
| `>` | `rangle` | Type grouping; decrements both (only when angle-depth > 0) |

### Compound Openers (Reader Macros)

| Pattern | Token type | Notes |
|---------|-----------|-------|
| `'[` | `quote-lbracket` | List literal opener |
| `'expr` | `quote` | Quote operator |
| `` ` `` | `backtick` | Quasiquote |
| `,` | `comma` | Unquote (in qq context) or separator (stripped in brackets) |
| `@[` | `at-lbracket` | PVec literal opener |
| `@` (alone) | ERROR | Must be `@[` |
| `~[` | `tilde-lbracket` | LSeq literal opener |
| `~N` | `approx-literal` | Approximate literal |
| `~-N` | `approx-literal` | Negative approximate |
| `~` (alone) | ERROR | Must be `~[` or `~N` |
| `#{` | `hash-lbrace` | Set literal opener |
| `#.field` | `nil-dot-access` | Nil-safe dot access |
| `#.:kw` | `nil-dot-key` | Nil-safe keyword access |
| `#:kw` | `nil-dot-key` | Nil-safe keyword (standalone prefix) |
| `#=` | `symbol` (`#=`) | Narrowing operator |
| `#p(...)` | `path-literal` | Path literal |
| `#` (other) | ERROR | Unexpected # |

### Dot Forms

| Pattern | Token type | Token value | Notes |
|---------|-----------|-------------|-------|
| `...` | `symbol` | `$rest` | Rest sentinel |
| `...name` | `rest-param` | `name` | Rest parameter |
| `.{` | `dot-lbrace` | `#f` | Mixfix form opener; increments bracket-depth |
| `.:kw` | `dot-key` | `:kw` | Keyword dot access |
| `.*field` | `broadcast-access` | `field` | Broadcast/map access |
| `.field` | `dot-access` | `field` | Dot access |
| `.` (alone) | ERROR | - | Bare dot |

### Typed Holes

| Pattern | Token type | Token value | Notes |
|---------|-----------|-------------|-------|
| `??` | `typed-hole` | `#f` | Unnamed hole |
| `??name` | `typed-hole` | `name` | Named hole |
| `?x` | `symbol` | `?x` | Logic variable (falls to ident path) |
| `?x:Nat:Even` | `symbol` | `?x:Nat:Even` | Constraint-annotated logic var (greedy : consumption) |

### Whitespace and Comments

| Pattern | Effect | Notes |
|---------|--------|-------|
| Space | Skipped (inline) | `skip-inline-whitespace!` |
| Tab | ERROR | "Use spaces for indentation, not tabs" |
| Newline (depth=0) | Sets `at-line-start?` | Triggers indentation processing |
| Newline (depth>0) | Skipped | Inside brackets, newlines are ignored |
| `;` to EOL | Skipped | Comment |
| Blank line | Skipped | Does not close indented blocks |

### Indentation Tokens (Virtual)

| Token | Condition | Notes |
|-------|-----------|-------|
| `indent` | New line column > stack top | Pushes to indent stack |
| `dedent` | New line column < stack top | Pops indent stack (may emit multiple) |
| `newline` | New line column = stack top | Same-level sibling separator |

---

## S3. Structure Building

### Indentation Tracking

The tokenizer maintains a mutable `indent-stack` (list of column numbers, initialized to `(0)`).

**Indentation processing** (`process-indentation!`, called when `at-line-start?` is true AND `bracket-depth` is 0):
1. Count leading spaces (`count-leading-spaces!`) — skips blank/comment-only lines
2. Compare column against stack top:
   - `col > top` -> push col, emit `indent` token
   - `col = top` -> emit `newline` token (sibling separator)
   - `col < top` -> pop stack until match found, emit one `dedent` per pop + final `newline`
3. Mismatched dedent (col doesn't match any stack entry) -> ERROR

**Critical state**: `at-line-start?` is set to `#t` when a newline is consumed at bracket-depth 0. When bracket-depth > 0, newlines are silently consumed (no indentation processing).

### Bracket Matching

Two depth counters:
- `bracket-depth`: Counts `(`, `)`, `[`, `]`, `{`, `}`, `<`, `>` — ALL bracket types
- `angle-depth`: Counts only `<`, `>` — used for `>` disambiguation

Opening any bracket increments `bracket-depth`. Closing decrements. Mismatch (depth=0 on close) -> ERROR.

**Angle bracket special case**: `>` has three behaviors:
1. `angle-depth > 0`: close angle bracket (decrement both depths)
2. `angle-depth = 0`, next char is `>`: compose operator `>>` -> `$compose`
3. `angle-depth = 0`, next char is not `>`: ERROR "Unexpected >"

### Tree Building (Parser)

The parser converts the flat token stream into syntax objects:

1. **Top-level**: `read-all-forms` reads forms separated by `newline` tokens
2. **Each top-level form**: `parse-top-level-form` reads line elements, then checks for `indent`:
   - If `indent`: parse children via `parse-indented-block`, append to line elements, wrap as list
   - If single paren-form: return unwrapped (no double-wrapping)
   - Otherwise: wrap as syntax list
3. **Indented blocks**: `parse-indented-block` reads children separated by `newline` until `dedent`
4. **Child forms**: `parse-child-form` reads line elements, may recurse into deeper indent
5. **Line elements**: `read-line-elements` reads inline elements until `newline`/`indent`/`dedent`/`eof`

**Infix `=` rewriting**: After reading line elements, `maybe-rewrite-infix-eq` checks for bare `=` (not `:=`, not first position) and rewrites `A = B` to `(= A B)`. The `:=` guard prevents rewriting inside binding forms.

### Multi-line Forms

Forms continue across lines via indentation:
```
def x : Nat
  fn [a : Nat]    ;; indent -> child
    a             ;; deeper indent -> grandchild
```
Produces: `(def x : Nat (fn (a : Nat) a))`

Inside brackets, newlines are ignored:
```
[fn [x : Nat,
     y : Nat]
  body]
```
This is a single bracket form — no indent/dedent tokens inside `[...]`.

### Comma Handling

Commas are stripped inside `[]`, `()`, `'[]`, `@[]`, `~[]`, `#{}`, `.{}` when `current-qq-depth` is 0. Inside quasiquote contexts (depth > 0), commas become `$unquote` operators.

### Postfix Indexing

After parsing any inline element, `parse-postfix-chain` checks if the next token is `lbracket` AND its position equals the element's end position (zero-gap adjacency). If so, it consumes the bracket contents and wraps as `($postfix-index content)`. This chains: `xs[0][1]` -> `(xs ($postfix-index 0) ($postfix-index 1))`.

---

## S4. Context-Sensitive Decisions

### 1. The `>` Ambiguity (angle-depth gating)

The `>` character has THREE meanings depending on `angle-depth`:
- Inside `<...>`: closing angle bracket
- Outside, followed by `>`: compose operator `>>`
- Outside, alone: ERROR

This is the most significant context-sensitive decision in the reader. The angle-depth counter is the mechanism, but it creates coupling: any bug in angle-depth tracking (e.g., not decrementing on error recovery) corrupts all subsequent `>` parsing.

### 2. Mixfix Form Override (`<` and `>` inside `.{...}`)

Inside `.{...}` (mixfix form), `<` and `>` are treated as operator symbols, NOT bracket delimiters. The parser temporarily bumps `angle-depth` and then in `parse-mixfix-element` undoes the tokenizer's bracket-depth changes, restoring base depths. This also handles `<=` (langle + `=` symbol -> `<=`) and `>=` (rangle + `=` symbol -> `>=`).

### 3. `-` Dispatch Priority Chain

The `-` character triggers a 4-way priority chain:
1. `-0>`, `-1>`, `-w>` — multiplied arrows (3-char lookahead)
2. `->` — arrow operator (2-char lookahead)
3. `-N` — negative literal (digit follows)
4. Fall through to ident-start (reads as identifier like `-x`)

### 4. `+` Dispatch Priority

1. `+>` — session choice (2-char lookahead)
2. Fall through to ident-start (reads as `+` or `+x`)

### 5. `:` Disambiguation

1. `:=` — assignment
2. `:0`, `:1` — multiplicity (standalone, not followed by ident chars)
3. `:w` — multiplicity if standalone; keyword `:widget` if followed by ident chars
4. `:name` — keyword (colon + alphabetic)
5. Bare `:` — colon token (type annotation)

### 6. `?` Disambiguation

1. `??` or `??name` — typed hole
2. `?:` — dependent receive
3. `?x` — logic variable (falls to ident, then greedily consumes `:Constraint` segments)

### 7. `#` Disambiguation

1. `#{` — set literal
2. `#.field` / `#.:kw` — nil-safe access
3. `#:kw` — nil-safe keyword
4. `#=` — narrowing operator
5. `#p(` — path literal
6. Other — ERROR

### 8. Quasiquote Depth Tracking

`current-qq-depth` (Racket parameter) determines comma interpretation:
- depth = 0: commas stripped as separators
- depth > 0: commas become `$unquote` operators
Backtick increments depth; comma in parse-inline-element decrements depth.

### 9. Postfix Index Adjacency

Postfix indexing fires only when `lbracket` position = preceding element's end position (zero gap). `xs[0]` triggers; `xs [0]` does not. This is a source-position-dependent context decision.

### 10. Infix `=` vs `:=` Precedence

`maybe-rewrite-infix-eq` skips rewriting if `:=` appears before `=` in the same line — the `=` is inside a value expression, not a top-level equality operator.

### Total context-sensitive decision points: 10

---

## S5. Source Location Tracking

### Token-Level

Every `token` struct carries: `(type value line col pos span)`:
- `line`: 1-based line number
- `col`: 0-based column number
- `pos`: 1-based byte position (tracks via `tok-read!`)
- `span`: character count of the token

Position tracking is manual (not using Racket port positions), maintained in the `tokenizer` struct's mutable `line`, `col`, `pos` fields. `tok-read!` updates these on every character consumed.

### Syntax Object Level

`make-stx` creates syntax objects with source location: `(datum->syntax #f datum (list source line col pos span))`. The `source` is typically a filename or `"<string>"`.

Span computation for compound forms uses `(- (end-of-last-child) (start-of-first-child))`. Virtual tokens (`indent`, `dedent`, `newline`) have span 0.

### Downstream Consumers

Source locations flow through the entire pipeline:
- `parser.rkt` uses `syntax-line`, `syntax-column` for error messages
- `elaborator.rkt` attaches srcloc to elaborated forms
- `errors.rkt` formats error messages with file:line:col
- `pretty-print.rkt` may use srcloc for source mapping

---

## S6. Edge Cases and Special Handling

### Reader Macros

| Macro | Produces | Parser form |
|-------|----------|------------|
| `'[...]` | `($list-literal ...)` | List with optional tail: `'[1 2 \| ys]` -> `($list-literal 1 2 ($list-tail ys))` |
| `'expr` | `($quote expr)` | Quote |
| `` `expr `` | `($quasiquote expr)` | Quasiquote (increments qq-depth) |
| `,expr` | `($unquote expr)` | Unquote (decrements qq-depth) |
| `@[...]` | `($vec-literal ...)` | PVec literal |
| `~[...]` | `($lseq-literal ...)` | LSeq literal |
| `~N` | `($approx-literal N)` | Approximate literal |
| `#{...}` | `($set-literal ...)` | Set literal |
| `.{...}` | `($mixfix ...)` | Mixfix expression |
| `#p(...)` | `(path :contents)` | Path literal (raw string between parens) |

### Dot-Access Syntax

`.field` tokenizes as `dot-access`, which the parser wraps as `($dot-access field)`. The preparse layer in macros.rkt then rewrites `(obj ($dot-access field))` to `(map-get obj :field)`.

### Broadcast Syntax

`.*field` tokenizes as `broadcast-access`, wrapped as `($broadcast-access field)`. Preparse rewrites to map-over-collection access.

### Postfix Indexing

`arr[i]` is detected by position adjacency (zero gap between arr's end and `[`'s start). Produces `(arr ($postfix-index i))`. Chains: `m[i][j]` -> `(m ($postfix-index i) ($postfix-index j))`.

### Implicit Map Syntax

Not handled at the reader level. Indentation-based keyword blocks are handled by the preparse layer in `macros.rkt`.

### Heredoc Strings

Not supported. Only double-quoted strings with `\n`, `\t`, `\\`, `\"` escapes.

### String Interpolation

Not supported in the reader. Noted as a desired feature in examples.

### Unicode Handling

- `\uXXXX` in character literals (4 hex digits)
- `char-alphabetic?` for identifier start (includes Unicode alphabetic)
- No explicit Unicode identifier support beyond what `char-alphabetic?` provides

### Error Recovery

**None.** All errors are fatal (`error` calls that raise `exn:fail`). There is no attempt to recover from:
- Mismatched brackets
- Bad indentation
- Unknown characters
- Unterminated strings

This is a significant concern for PPN Track 1 — propagator-based parsing benefits from partial results and error recovery.

---

## S7. Call Sites (Reverse Dependencies)

### Production Call Sites

**`driver.rkt`** (line 1307):
```
(define (read-all-syntax-ws port [source "<port>"])
  (port-count-lines! port)
  (prologos-read-syntax-all source port))
```
This is the primary entry point for `.prologos` file processing. Called from `process-file` and `process-string-ws`.

**`repl.rkt`** (lines 108, 131):
```
(define stx (prologos-read-syntax "<repl>" port))
```
Reads one form at a time from REPL input. Uses the caching mechanism (prologos-stx-cache).

**`tools/form-deps.rkt`** (line 91):
```
(define all-forms (read-all-forms-string content))
```
Parses file content for dependency analysis.

### Test Call Patterns

Tests use reader.rkt functions in three patterns:

1. **Tokenizer testing** (`tokenize-string`): 6 test files call `tokenize-string` directly to verify token types/values
2. **Parser testing** (`read-all-forms-string`): 8+ test files call `read-all-forms-string` to verify datum output
3. **WS pipeline testing** (`prologos-read-syntax-all`): 3+ test files use full syntax output for integration tests

### What Consumers Expect

All consumers expect:
- A `(listof syntax-object)` (from `prologos-read-syntax-all`) or `(listof datum)` (from `read-all-forms-string`)
- Correct source locations on all syntax objects
- Sentinel symbols (`$list-literal`, `$dot-access`, etc.) in the right positions
- Commas stripped inside brackets
- Indentation structure reified as nesting
- No indentation tokens leaking through (consumers never see `indent`/`dedent`/`newline`)

---

## S8. Migration Concerns

### EASY to Replace with Propagators

These are flat, stateless character patterns — each character/sequence maps to exactly one token with no context:

1. **Delimiter tokens**: `[`, `]`, `(`, `)`, `{`, `}` — single character, fixed token type
2. **String literals**: Read until matching `"`, handle escapes — self-contained
3. **Number literals**: Digit sequences with `/`, `.`, `N` suffixes — self-contained
4. **Character literals**: `\` + character/name/unicode — self-contained
5. **Comment skipping**: `;` to EOL — self-contained
6. **Inline whitespace**: Space characters — self-contained
7. **Simple operators**: `|>`, `||`, `&>`, `:=`, `->` — fixed multi-character sequences
8. **Keywords**: `:name` — colon + alphabetic + ident-continue

Estimated: ~60% of tokenizer logic is flat pattern matching.

### HARD to Replace with Propagators

These involve stateful tracking that spans multiple tokens:

1. **Indent stack management**: The indent stack is a mutable list that must be consistent across the entire file. Each newline at depth 0 queries AND modifies this stack. In a propagator model, this becomes a cell whose value is the current stack, with propagators that compute indent/dedent from (current-stack, new-column) pairs.

2. **Bracket depth tracking**: Two counters (`bracket-depth`, `angle-depth`) that affect:
   - Whether newlines produce indentation tokens
   - How `>` is interpreted
   - Whether commas are stripped

3. **EOF handling**: At EOF, remaining indent stack entries must produce `dedent` tokens. This is inherently sequential — you need to know the final stack state.

4. **Postfix adjacency detection**: Requires comparing end position of one element with start position of the next. In a propagator model, this becomes an edge between consecutive token cells.

### Needs SPECIAL DESIGN

1. **The parser layer**: The parser is interleaved with the tokenizer (parser-peek calls tokenizer-next!). In a propagator model, these are separate networks connected by a token stream cell/channel.

2. **Mixfix angle bracket override**: The parser reaches into the tokenizer to manipulate `angle-depth` and `bracket-depth`. This coupling must be broken — either via a mode cell that the tokenizer reads, or by having the mixfix parser reinterpret angle tokens.

3. **Quasiquote depth**: A Racket parameter that spans the parser's recursive calls. In propagators, this becomes a cell or context tag.

4. **Infix `=` rewriting**: Post-hoc transformation of line elements. Could become a normalization propagator on the form-level output.

5. **Caching** (`prologos-form-cache`, `prologos-stx-cache`): Weak hash tables for multi-call readers. The propagator network inherently caches (cell values persist). This mechanism may be unnecessary.

### Testable by Output Comparison

**Yes — the entire reader can be validated by comparing old output vs new output:**

- `read-all-forms-string(input)` -> datum list — exact equality comparison
- `prologos-read-syntax-all(source, port)` -> syntax list — compare via `syntax->datum` for structure, check `syntax-line`/`syntax-column`/`syntax-position`/`syntax-span` for source locations

This enables a golden-test migration strategy:
1. Capture output from current reader on every .prologos file in the repo
2. Run new propagator reader on same files
3. Compare datum structure (must match exactly)
4. Compare source locations (may allow small span differences)

---

## S9. Concrete Numbers

### Token Type Distribution

Analysis of `examples/2026-03-26-ppn-track0.prologos` (564 lines, comprehensive stress test):

Estimated token counts from manual analysis of the file structure:

| Token type | Estimated count | Notes |
|-----------|----------------|-------|
| `symbol` | ~350 | Identifiers, operators (`->`, `:=`, `$pipe`, etc.) |
| `lbracket` / `rbracket` | ~200 pairs | Primary grouping |
| `keyword` | ~30 | `:name`, `:age`, etc. |
| `number` | ~60 | Integer literals |
| `nat-literal` | ~15 | `0N`, `3N`, etc. |
| `string` | ~30 | String literals |
| `newline` | ~200 | Top-level form separators |
| `indent` / `dedent` | ~40 each | Block structure |
| `colon` | ~50 | Type annotations |
| `lparen` / `rparen` | ~15 pairs | `(match ...)`, `(the ...)` |
| `langle` / `rangle` | ~5 pairs | `<Int \| String>` etc. |
| `lbrace` / `rbrace` | ~10 pairs | `{:key val}` maps, `{A : Type}` |
| `quote-lbracket` | ~15 | `'[...]` list literals |
| `char` | ~3 | `'A'` etc. |
| `comma` | ~5 | In bracket forms |
| `dot-access` | ~5 | `m.name` etc. |

**Estimated total tokens**: ~1200 for 564-line file (~2.1 tokens/line)

### Forms and Indentation

From the same file:
- **Top-level forms**: ~120 (ns declarations + defs + specs + defns + expressions)
- **Average tokens per form**: ~10
- **Maximum indentation depth**: 2 (defn body -> match arm)
- **Average indentation depth**: 0.5 (most forms are single-line)
- **Namespace blocks** (`ns`): 25

### Benchmark Baseline (from bench-ppn-track0.rkt)

From Track 0 benchmark section C (pipeline baselines):
- Reader time for 4-form input: sub-millisecond
- Reader is ~1-5% of full pipeline cost (elaboration + type-checking dominates)

### Context-Sensitive Decision Points

From S4 above: **10 distinct context-sensitive decisions**, of which:
- 3 are high-complexity (angle brackets, `-` priority chain, mixfix override)
- 4 are medium-complexity (`:`, `?`, `#`, qq-depth)
- 3 are low-complexity (postfix adjacency, infix `=`, `+` priority)

---

## Summary: Key Findings for Track 1 Design

1. **The reader is self-contained** — only 2 imports (`racket/match`, `racket/string`). This simplifies replacement.

2. **The reader has two coupled subsystems**: a tokenizer (lines 36-918) and a parser (lines 920-1898). The tokenizer is ~48% of the code, the parser ~52%. They are tightly coupled: the parser reaches into the tokenizer's mutable state (bracket-depth, angle-depth) in the mixfix form handler.

3. **50 test files depend on reader.rkt**, but only 2 are dedicated reader tests. The other 48 use reader functions as infrastructure for WS pipeline testing. Replacement must maintain the same export interface.

4. **10 context-sensitive decisions** — these are where propagator design gets interesting. The angle-bracket ambiguity (#1) and the mixfix override (#2) are the hardest, because they involve the parser modifying tokenizer state.

5. **No error recovery** — the current reader fails hard on any error. A propagator-based reader could naturally support partial results via ATMS environments.

6. **Source location tracking is manual** — the tokenizer maintains its own line/col/pos counters rather than using Racket port positions. This is self-contained and portable to a propagator model.

7. **Golden-test strategy is viable** — the output format (datum lists with source locations) allows exact comparison between old and new readers. Every `.prologos` file in the repo is a potential test case.

8. **The reader is fast and small** — at ~1900 lines and sub-millisecond for typical files, the propagator replacement must not regress significantly. The reader is ~1-5% of pipeline cost, so even a 10x slowdown would be acceptable for the architecture benefits, but 100x would be noticed.
