# First-Class Path Values — Stage 3 Design Document

**Date**: 2026-03-20
**Status**: Draft
**Scope**: Promote paths from syntactic sugar to first-class typed values
**Prerequisite**: Existing path algebra (2026-03-03), dot-access syntax, schema system
**Supersedes**: None (extends PATH_ALGEBRA_DESIGN.md)

---

## Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| 0 | Acceptance file | ⬜ | |
| 1 | AST node + surface syntax | ⬜ | |
| 2 | Parser: path literal production | ⬜ | |
| 3 | Reader integration: dot-to-path | ⬜ | |
| 4 | Elaboration: path-aware get-in/update-in | ⬜ | |
| 5 | Type system: Path type + get-in typing | ⬜ | |
| 6 | Reduction: path-based navigation | ⬜ | |
| 7 | Path combinators (library) | ⬜ | |
| 8 | Lens layer (future) | ⬜ | Out of scope |

---

## 1. Problem Statement

Paths in Prologos currently exist at two disconnected levels that interfere with each other:

**Level 1 — Reader dot-access (eager desugar):** The reader tokenizes `user.address.zip` into sentinel tokens (`$dot-access`), and `rewrite-dot-access` in preparse (macros.rkt lines 4955–5040) desugars them into nested `(map-get (map-get user :address) :zip)`. This fires **before parsing** — paths are destroyed before any downstream form can see them.

**Level 2 — Parser get-in/update-in (late desugar):** `(get-in m :address.zip)` is parsed by the parser (parser.rkt lines 1966–1982), which splits `:address.zip` on `.` into structured path data `'((#:address #:zip))`. The elaborator (elaborator.rkt lines 1856–1888) then desugars this into chained `map-get` calls. Paths exist as structured data briefly in the parser but are destroyed at elaboration.

**The interference:** In WS mode, writing `[get-in user :address.zip]` fails because the reader's dot-access rewriting fires on `:address.zip` BEFORE the parser's `get-in` handler sees it. The keyword becomes `(map-get (map-get :address :zip) ...)` — nonsensical. A `reconstitute-selection-paths` workaround (macros.rkt lines 2271–2314) patches this for `selection` declarations but not for general `get-in`/`update-in`.

**Deeper issue:** Even when the parse works (sexp mode), paths are not values — you cannot bind a path to a variable, pass it to a function, compose paths, or abstract over them. This violates the language's core principle that all constructs should be first-class.

### What we want

```prologos
;; Paths as first-class values
def p := #p(:address.zip)
[get-in user p]                    ;; works — p is a value
[update-in user p [int+ _ 1]]     ;; works

;; Composition
def full := [path-append #p(:address) #p(:zip)]

;; Path in higher-order context
[map [fn [p] [get-in user p]] paths]

;; Existing dot-access still works for simple cases
user.address.zip                   ;; still desugars to nested map-get (ergonomic shorthand)
```

---

## 2. Design Space (Evaluated Options)

### Option A: Path Quoting (Rejected)

Recognize `get-in`/`update-in` at preparse and suppress dot-rewriting inside them.

- **Pros**: Minimal change, no new AST nodes
- **Cons**: Each new path-consuming form needs special preparse handling. Paths remain sugar, not values. Cannot bind/pass/compose paths. Doesn't scale.

**Verdict**: Fixes the immediate interference bug but doesn't address the fundamental limitation.

### Option B: First-Class Path Values (Selected)

Introduce a `Path` type and `expr-path` AST node. Paths are runtime values that survive through the entire pipeline.

- **Pros**: Composable, bindable, passable. Aligns with homoiconicity (paths are data). Wildcards and branching work as values. Enables path-parametric functions. Future lens layer can build on top.
- **Cons**: New AST node (14-file pipeline update). New type to check. Path composition typing needs care.

**Verdict**: Matches language principles. Implementation weight is moderate — standard pipeline extension.

### Option C: Lenses/Optics (Deferred)

Paths as function pairs `(get, set)` with algebraic composition. Well-studied theory (van Laarhoven, profunctor optics).

- **Pros**: Maximally principled. Prisms handle sum types, traversals handle collections. Composes with existing type system.
- **Cons**: Heavy runtime (function pairs vs direct CHAMP lookup). Complex type signatures with dependent types. Wide ergonomic gap. High implementation cost.

**Verdict**: Excellent future direction. Can be built ON TOP of first-class path values as a library layer. Deferred to a future track.

---

## 3. Design: First-Class Path Values

### 3.1 Path Literal Syntax

```
#p(:address.zip)         ;; deep path: 2 segments
#p(:name)                ;; simple: 1 segment
#p(:address.*)           ;; wildcard
#p(:address.**)          ;; globstar
#p(:address.{zip city})  ;; branching (multiple paths)
```

The `#p(...)` reader syntax is chosen because:
- `#` prefix is the standard Racket convention for reader extensions
- Avoids collision with existing `#:keyword` syntax
- Parenthesized body uses existing path grammar from selections
- Clearly distinguishes path literals from keyword symbols

**Sexp equivalent:** `(path :address.zip)` — a special form recognized by the parser.

**WS equivalent:** `#p(:address.zip)` — the reader produces the sexp form.

### 3.2 AST Nodes

**Surface syntax** (`surface-syntax.rkt`):
```racket
;; A path literal — list of path-branches, each branch a list of segments
;; Segment = keyword | '* | '**
;; Example: :address.{zip city} → '((#:address #:zip) (#:address #:city))
(struct surf-path (branches srcloc) #:transparent)
```

**Core syntax** (`syntax.rkt`):
```racket
;; A path value — fully elaborated
;; branches: list of (listof expr-keyword|expr-symbol)
(struct expr-path (branches) #:transparent)

;; The Path type
;; No type parameters initially — Path is a simple ground type.
;; get-in/update-in typing uses the path's structure to compute result types.
(struct expr-Path () #:transparent)
```

**Why `expr-Path` is unparameterized:** A path like `#p(:address.zip)` doesn't carry type information intrinsically — the types come from the map/schema it's applied to. This is analogous to how keyword literals (`:name`) don't carry types. The typing happens at `get-in`/`update-in` application sites.

### 3.3 Reader Integration

**New reader token** (`reader.rkt`):

The reader recognizes `#p(` and enters path-literal mode:
1. Read the contents as a single keyword-dotted form using existing path tokenization
2. Emit `(path <contents>)` into the datum stream
3. The preparse and parser handle `path` as a known form

**Dot-access interaction:** Single-dot access (`user.name`) continues to desugar via `rewrite-dot-access` to `(map-get user :name)` — this is the ergonomic shorthand for the common case. The path literal is for when you need a reified, bindable path value.

**Keyword-dot interaction:** The existing problem where `:address.zip` inside `get-in` gets destroyed by dot-rewriting is resolved by changing the desugar priority:
- `rewrite-dot-access` already runs in preparse
- `get-in`/`update-in` path arguments are **quoted** from dot-rewriting by the preparse handler (similar to how `selection` already reconstitutes paths)
- Alternatively, the preparse handler for `get-in`/`update-in` converts keyword-dot arguments to `(path ...)` forms before dot-rewriting runs

### 3.4 Parser

`parse-expr` gains a `path` case:

```racket
[(path . path-contents)
 ;; Reuse existing validate-selection-paths machinery
 (define branches (validate-selection-paths path-contents srcloc))
 (surf-path branches srcloc)]
```

`get-in` and `update-in` parsing remains largely unchanged, but now also accepts `surf-path` values as path arguments (not only inline keyword paths).

### 3.5 Elaboration

**Path literal elaboration:**
```racket
[(surf-path branches srcloc)
 ;; Each branch is a list of keywords/wildcards — elaborate each segment
 (expr-path (for/list ([branch (in-list branches)])
              (for/list ([seg (in-list branch)])
                (cond
                  [(keyword? seg) (expr-keyword (keyword->symbol seg))]
                  [(eq? seg '*) (expr-symbol '*)]
                  [(eq? seg '**) (expr-symbol '**)]))))]
```

**get-in elaboration (revised):**

Currently (lines 1856–1888), `get-in` immediately desugars to chained `map-get`. The revised behavior:

- **Static path (literal `expr-path` argument):** Desugar to chained `map-get` as before — this enables the type checker to verify field existence at each level. This is the zero-cost path: the path literal is "compiled away" at elaboration.
- **Dynamic path (variable or expression of type `Path`):** Emit `expr-get-in` as a proper core AST node that survives to reduction. The type checker infers a general result type (the value type of the outermost map).

This dual behavior gives us both static type safety (for literal paths) and dynamic flexibility (for path variables).

```racket
[(surf-get-in target paths srcloc)
 (define elab-target (elaborate target))
 (cond
   ;; Static path: inline to chained map-get (existing behavior)
   [(and (= (length paths) 1) (surf-path? (car paths)))
    (path->chain elab-target (surf-path-branches (car paths)))]
   ;; Dynamic path: keep as get-in node
   [else
    (expr-get-in elab-target (elaborate (car paths)))])]
```

### 3.6 Type System

**Path literal typing:**
```racket
[(expr-path branches)
 (expr-Path)]  ;; Path is a ground type
```

**get-in with static path (chained map-get):** Already typed correctly — each `map-get` is individually typed.

**get-in with dynamic path:**
```racket
[(expr-get-in target path-expr)
 ;; target : Map K V or Schema S — result type is V (or Any for deeply-nested)
 ;; This is the "escape hatch" — less precise than static, but sound
 (define target-ty (infer target))
 (match (whnf target-ty)
   [(expr-Map k v) v]
   [_ (fresh-meta)])]  ;; For schemas etc., infer via meta
```

**Typed path future (not in scope):** A future enhancement could parameterize `Path` with phantom types `Path S T` (from schema `S`, reaching type `T`), enabling static checking of dynamic paths. This is compatible with the current design — `expr-Path` can be extended to `(struct expr-Path (source-type target-type) ...)` later without breaking existing code.

### 3.7 Reduction

**Path literal reduction:** `expr-path` is a value (normal form) — it reduces to itself.

**get-in with dynamic path:**
```racket
[(expr-get-in target path-expr)
 (define t (whnf target))
 (define p (whnf path-expr))
 (match p
   [(expr-path branches)
    ;; Single-branch path: walk segments
    (define branch (car branches))
    (let loop ([current t] [segs branch])
      (if (null? segs)
          current
          (loop (whnf (expr-map-get current (car segs)))
                (cdr segs))))]
   [_ (expr-get-in t p)])]  ;; stuck if path isn't concrete
```

### 3.8 Path Combinators (Library Layer)

Implemented in Prologos itself (not Racket-side), as library functions:

```prologos
;; Path append — concatenate two paths
spec path-append Path Path -> Path
;; Implementation: foreign function or macro that concatenates branch segments

;; Path length
spec path-length Path -> Int

;; Path head/tail
spec path-head Path -> Path    ;; first segment
spec path-tail Path -> Path    ;; remaining segments
```

These are thin wrappers around the `expr-path` structure. They can be implemented as foreign functions (Racket-side) that destructure and reconstruct `expr-path` nodes.

### 3.9 Interaction with Existing Features

**Dot-access (`user.name`):** Unchanged. Single-field access continues to desugar to `map-get`. This is the lightweight, ergonomic form for the common case.

**Multi-dot access (`user.address.zip`):** Unchanged. Desugars to nested `(map-get (map-get user :address) :zip)` via `rewrite-dot-access`. This is still the best path for the common case — zero overhead, full static typing at each level.

**`selection` declarations:** Unchanged. Selections use paths as data in their `:requires` clauses, parsed by the existing path parser.

**Schema field access:** Unchanged. `(map-get user :name)` with schema typing continues to work.

**Nil-safe access (`user#.address#.zip`):** Unchanged. Desugars to nested `nil-safe-get`.

**`get-in` with inline paths:** Still works — `[get-in user :address.zip]` parses the keyword-dot form into a path and elaborates to chained `map-get` (static path optimization). The fix for the WS reader interference is that the preparse handler for `get-in` either reconstitutes or converts keyword-dot arguments before `rewrite-dot-access` runs.

**`update-in` with inline paths:** Same treatment as `get-in`.

---

## 4. Pipeline Impact (14-File Checklist)

| # | File | Change | Weight |
|---|------|--------|--------|
| 1 | `syntax.rkt` | Add `expr-path`, `expr-Path` structs | S |
| 2 | `surface-syntax.rkt` | Add `surf-path` struct | S |
| 3 | `parser.rkt` | Add `path` form parsing; update `get-in`/`update-in` to accept path exprs | M |
| 4 | `elaborator.rkt` | Elaborate `surf-path`; dual-path `get-in` elaboration | M |
| 5 | `typing-core.rkt` | Type `expr-path` → `expr-Path`; type dynamic `expr-get-in` | M |
| 6 | `qtt.rkt` | `inferQ`/`checkQ` for `expr-path` (zero usage — it's a literal) and dynamic `expr-get-in` | S |
| 7 | `reduction.rkt` | `expr-path` is a value; reduce dynamic `expr-get-in` | M |
| 8 | `substitution.rkt` | Traverse `expr-path` (no-op, no free vars); traverse `expr-get-in` | S |
| 9 | `zonk.rkt` | All three zonk functions for `expr-path` (no-op) and `expr-get-in` | S |
| 10 | `pretty-print.rkt` | Display `expr-path` as `#p(:a.b.c)` | S |
| 11 | `reader.rkt` | Add `#p(...)` reader syntax | M |
| 12 | `macros.rkt` | Preparse: protect `get-in`/`update-in` keyword args from dot-rewriting | M |
| 13 | `unify.rkt` | `expr-Path` unifies with `expr-Path` (ground type, trivial) | S |
| 14 | `foreign.rkt` | Path combinators as foreign functions (Phase 7) | S |

**Total**: ~4 medium changes, ~10 small changes. Standard pipeline extension.

---

## 5. WS Impact

### What forms does the WS reader produce?

- `#p(:address.zip)` → reader emits `(path :address.zip)` (new reader extension)
- Inside the `(path ...)` form, dots are NOT tokenized as `$dot-access` sentinels — the reader recognizes the `#p(` prefix and reads the contents in "path mode" where dots are segment separators

### Does preparse need a new pass or handler?

- **New**: `path` form in preparse pass-through (no transformation needed, just don't interfere)
- **Modified**: `get-in`/`update-in` preparse handler must shield keyword-dot arguments from `rewrite-dot-access`. Two approaches:
  1. Convert keyword-dot args to `(path ...)` forms before dot-rewriting runs
  2. Mark `get-in`/`update-in` subtrees as dot-rewrite-exempt (more invasive)

  Approach (1) is cleaner — it unifies the representation early.

### Keyword/delimiter conflicts?

- `#p(` is unambiguous — `#` followed by `p` followed by `(` doesn't conflict with `#:keyword`, `#.field` (nil-safe), `#t`/`#f` (booleans), or `#\char` (character literals)
- If `p` is problematic, alternatives: `#path(`, `#%(`, `@p(`. The `#p` form is concise and mnemonic.

### Does `flatten-ws-kv-pairs` apply?

No — path literals are self-contained within `#p(...)` and don't participate in keyword-value pairing.

---

## 6. Phased Implementation

### Phase 0: Acceptance File
Write `examples/2026-03-20-first-class-paths.prologos` exercising:
- Path literals (simple, deep, branching, wildcard)
- `get-in`/`update-in` with path variables
- Path passed to higher-order functions
- Path combinators
- Existing dot-access still working

### Phase 1: AST Nodes + Surface Syntax (S)
- Add `expr-path`, `expr-Path` to `syntax.rkt`
- Add `surf-path` to `surface-syntax.rkt`
- Stub cases in substitution, zonk, pretty-print (no-op traversals)
- `raco make driver.rkt` to verify compilation

### Phase 2: Parser (M)
- Add `path` form recognition in `parse-expr`
- Reuse `validate-selection-paths` for branch parsing
- Add `surf-path` acceptance in `get-in`/`update-in` parsing
- Unit tests: path literal parsing, get-in with path variable

### Phase 3: Reader Integration (M)
- Add `#p(` reader extension in `reader.rkt`
- In path-literal mode, read keyword-dot contents without dot-sentinel tokenization
- Emit `(path ...)` datum
- L2 tests: `process-string-ws` with `#p(:address.zip)`

### Phase 4: Elaboration (M)
- Elaborate `surf-path` → `expr-path`
- Dual-path get-in: static paths inline to chained `map-get`, dynamic paths emit `expr-get-in`
- L1 tests: path literal elaboration, get-in with bound path variable

### Phase 5: Type System (M)
- `expr-path` → `expr-Path` type
- Dynamic `expr-get-in` typing: infer from target map type
- QTT: `expr-path` has zero usage; dynamic `expr-get-in` uses target and path
- Type error tests: path applied to non-map

### Phase 6: Reduction (M)
- `expr-path` is a value (self-reducing)
- Dynamic `expr-get-in` reduces by walking path segments on concrete map
- Integration tests: runtime navigation via path variables
- L3 acceptance file validation

### Phase 7: Path Combinators (S, Library)
- `path-append`, `path-length`, `path-head`, `path-tail` as foreign functions
- Library module `prologos.core.path`
- Tests for composition

### Phase 8: Lens Layer (Future, Out of Scope)
Deferred. When/if desired:
- Lens as `{get : [S -> A], set : [S -> A -> S]}` schema
- `lens` constructor from path: `[lens #p(:address.zip)]` → `Lens User Int`
- van Laarhoven or profunctor encoding for advanced composition
- Prisms for sum types, traversals for collections
- Affine lenses for nil-safe paths

---

## 7. Preparse Fix: get-in/update-in WS Compatibility

This is the immediate bug fix that Phase 3 resolves. The details:

**Current behavior (broken):**
```
WS input: [get-in user :address.zip]
Reader:   (get-in user ($dot-key :address) ($dot-access zip))
Preparse: (get-in user (map-get :address :zip))   ;; rewrite-dot-access fires
Parser:   ERROR — get-in expects keyword path, got (map-get ...)
```

**Fixed behavior:**
```
WS input: [get-in user :address.zip]
Reader:   (get-in user ($dot-key :address) ($dot-access zip))
Preparse: recognizes get-in, reconstitutes dotted args → (get-in user (path :address.zip))
Parser:   surf-get-in with surf-path argument
Elaborator: static path → chained (map-get (map-get user :address) :zip)
```

The key change in macros.rkt preparse: when processing `get-in` or `update-in`, convert any keyword + dot-sentinel sequences in the argument list to `(path ...)` forms BEFORE `rewrite-dot-access` runs on the rest.

---

## 8. Test Strategy

- **Level 1 (sexp):** Path literal construction, get-in/update-in with paths, path combinators
- **Level 2 (WS string):** `#p(:address.zip)` parsing, get-in with path variable
- **Level 3 (WS file):** Acceptance file exercises all path forms
- **Regression:** Existing dot-access, selection, get-in/update-in tests must continue passing

---

## 9. Key Files

| File | Role |
|------|------|
| `syntax.rkt` | `expr-path`, `expr-Path` struct definitions |
| `surface-syntax.rkt` | `surf-path` struct |
| `reader.rkt` | `#p(...)` reader extension |
| `macros.rkt` | Preparse protection for get-in/update-in args |
| `parser.rkt` | `path` form parsing, get-in/update-in update |
| `elaborator.rkt` | Path elaboration, dual-path get-in |
| `typing-core.rkt` | `expr-Path` type, dynamic get-in typing |
| `qtt.rkt` | Usage tracking for path nodes |
| `reduction.rkt` | Dynamic get-in runtime navigation |
| `docs/tracking/2026-03-03_PATH_ALGEBRA_DESIGN.md` | Prior art — selection path algebra |
| `docs/tracking/2026-02-21_1800_DOT_ACCESS_SYNTAX.md` | Dot-access implementation record |

---

## 10. Design Decisions Log

| Decision | Rationale |
|----------|-----------|
| `#p(...)` syntax over bare `:a.b.c` auto-promotion | Explicit > implicit. Bare `:a.b.c` continues as ergonomic shorthand (desugars to `map-get`). Path promotion only when the user wants a value. |
| Unparameterized `Path` type | Path doesn't know what it navigates — types come from the application site (`get-in m p`). Phantom typing can be added later without breaking changes. |
| Static path inlining at elaboration | Zero-cost abstraction: literal paths compile away to the same chained `map-get` as today. Only dynamic paths (variables) pay the `expr-get-in` cost at reduction. |
| Lenses deferred, not rejected | Lenses compose beautifully but require significant type machinery (especially with dependent types). First-class paths provide the foundation; lenses can be built on top as a library. |
| Path combinators as foreign functions | Paths are Racket structs (`expr-path`) — manipulation requires Racket-side code. A thin foreign function layer is cleaner than trying to implement path operations in pure Prologos. |
