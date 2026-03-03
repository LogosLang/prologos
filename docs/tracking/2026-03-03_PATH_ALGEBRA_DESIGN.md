# Path Algebra Design Document

**Date**: 2026-03-03
**Status**: Implementation complete (Phases 3d, 3e)
**Scope**: Selection path extensions + general-purpose path expressions

---

## Overview

The path algebra is Prologos's system for navigating and transforming nested data
structures. Originally designed for `selection` declarations (declaring which fields
are accessible), it has been promoted to a general-purpose language feature via
`get-in` and `update-in` expression forms.

## Path Syntax

### Core Grammar (EBNF)

```ebnf
field-path    = ':' , identifier , { '.' , path-segment } ;
path-segment  = identifier
              | '*'                                      (* wildcard *)
              | '**'                                     (* globstar *)
              | '{' , branch , { ' ' , branch } , '}'   (* brace expansion *)
              ;
branch        = identifier , { '.' , path-segment } ;   (* sub-path *)
```

### Path Forms

| Form | Example | Expansion |
|------|---------|-----------|
| Simple | `:name` | `((#:name))` |
| Deep | `:address.zip` | `((#:address #:zip))` |
| Three-level | `:a.b.c` | `((#:a #:b #:c))` |
| Wildcard | `:address.*` | `((#:address *))` |
| Globstar | `:address.**` | `((#:address **))` |
| Brace | `:address.{zip city}` | `((#:address #:zip) (#:address #:city))` |
| Branch sub-path | `:a.{b.c d.e}` | `((#:a #:b #:c) (#:a #:d #:e))` |
| Nested braces | `:a.{b.{c d} e}` | `((#:a #:b #:c) (#:a #:b #:d) (#:a #:e))` |
| Post-brace suffix | `:a.{b c}.**` | `((#:a #:b **) (#:a #:c **))` |
| Cartesian product | `:a.{b c}.{d e}` | 4 paths (cons-dot normalization) |

### Key Design Insight

**Brace items are paths, not just field names.** This single generalization enables:
- Per-branch continuation: `{foo.waz bar.quux}` — each branch navigates differently
- Mixed depth: `{name address.zip age}` — some branches are leaves, some are deep
- Recursive nesting: `{name address.{zip city.{name abbrev}}}` — braces within braces
- Wildcards in branches: `{name address.** settings}` — glob within a branch

## Expression Forms

### `get-in` — Navigate and Extract

```prologos
;; Single path: returns the value at the leaf
(get-in user :address.zip)
;; Desugars to: (map-get (map-get user :address) :zip)

;; Branched path: returns a map with projected fields
(get-in user :address.{zip city})
;; Desugars to: (map-assoc (map-assoc (map-empty K V) :zip (map-get (map-get user :address) :zip))
;;                         :city (map-get (map-get user :address) :city))
```

### `update-in` — Navigate and Transform

```prologos
;; Apply function at leaf, rebuild structure
(update-in user :address.zip (fn [n] 0N))
;; Desugars to: (map-assoc user :address
;;                (map-assoc (map-get user :address) :zip
;;                  ((fn [n] 0N) (map-get (map-get user :address) :zip))))

;; Only single paths allowed (no branching)
(update-in user :address.{zip city} f)  ;; ERROR: branched update-in
```

## Architecture

### Parser (`parser.rkt`)

The path algebra parser is shared between `selection` declarations and `get-in`/`update-in`
expressions. The core function `validate-selection-paths` handles all path parsing:

- **`parse-path-string`**: Splits dotted strings on `.`, converts segments to keywords/wildcards
- **`expand-brace-branches`**: Handles brace expansion with sub-paths and nested braces
- **`consume-post-brace-continuation`**: Detects and appends post-brace suffixes
- **`normalize-cons-dot-braces`**: Repairs cons-dot garbling from Racket's `.{` reader

### Elaborator (`elaborator.rkt`)

Pure desugaring — no new AST nodes emitted downstream:

- `surf-get-in` → chains of `expr-map-get` (single path) or `expr-map-empty`/`expr-map-assoc` (branched)
- `surf-update-in` → nested `expr-map-get`/`expr-map-assoc` with `expr-app` at leaf
- Keyword conversion: path segments are Racket keywords (`#:zip`); `expr-keyword` takes symbols (`'zip`)

### Type Checking

No new type checking code needed. Since `get-in`/`update-in` desugar to existing
`map-get`/`map-assoc` operations, the existing type checker handles them automatically.

### WS Mode (Deferred)

In sexp mode, `:address.{zip city}` tokenizes as `:address.` + `($brace-params zip city)`.
In WS mode, `.{` is the `dot-lbrace` token for mixfix expressions. Disambiguation is deferred;
sexp mode is the canonical surface for complex paths. See DEFERRED.md.

## Prior Art

- **Clojure**: `get-in`, `update-in`, `assoc-in` — same concept, no brace expansion
- **Specter**: Navigators for nested transformations — more powerful but complex API
- **Lenses** (Haskell): Get/set/modify with composable optics — theoretically elegant,
  operationally similar to what path algebra provides
- **GraphQL**: Field selection with nested projections — `selection` declarations are
  directly inspired by this
- **jq**: Path expressions for JSON — wildcards and recursive descent similar to `*`/`**`

## Sexp Tokenization Details

Understanding how Racket's sexp reader tokenizes path syntax is critical:

| Input | Sexp tokens |
|-------|-------------|
| `:address.zip` | Symbol `:address.zip` (one token) |
| `:address.{zip city}` | `:address.` + `($brace-params zip city)` |
| `:a.{b.{c d} e}` | `:a.` + `($brace-params b. ($brace-params c d) e)` |
| `[:a.{b c}.{d e}]` | `(:a. ($brace-params b c) $brace-params d e)` (cons-dot!) |

The cons-dot issue occurs because `.{...}` at the tail of a bracket list triggers Racket's
cons-dot reader. The `normalize-cons-dot-braces` pass detects the bare `$brace-params` symbol
and re-wraps it.

## Test Coverage

- **56 tests** in `test-selection-paths.rkt` — parser + E2E selection path tests
- **20 tests** in `test-path-expressions.rkt` — parser + E2E get-in/update-in tests

## Commits

| Phase | Description | Commit |
|-------|-------------|--------|
| 3d-a | Branch items as sub-paths | `1d342a9` |
| 3d-b | Nested braces inside branches | `b288922` |
| 3d-c | Uniform post-brace continuation | `91528fe` |
| 3d-d | Cons-dot normalization | `5b4d4dc` |
| 3d-e | E2E pipeline tests | `994d9fb` |
| 3e-a | AST nodes and parsing | `32993ad` |
| 3e-b/c | Elaboration (get-in + update-in) | `f5749c8` |
| 3e-f | Path expression tests | `93af4bc` |
