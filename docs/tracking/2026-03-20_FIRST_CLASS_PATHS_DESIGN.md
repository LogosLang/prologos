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
| 0 | Acceptance file | ✅ | Baseline passes with 0 errors |
| 1 | AST node + surface syntax | ⬜ | |
| 2 | Parser: path literal production | ⬜ | |
| 3 | Reader integration: dot-to-path | ⬜ | |
| 4 | Elaboration: path-aware get-in/update-in | ⬜ | |
| 5 | Type system: Path type + get-in typing | ⬜ | |
| 6 | Reduction: path-based navigation | ⬜ | |
| 7 | Path combinators + destructuring | ⬜ | |
| 7b | Broadcast syntax `.*field` | ⬜ | |
| 7c | Key renaming `^` syntax | ⬜ | |
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
;; Paths as first-class values (colon optional inside #p)
def p := #p(address.zip)
[get-in user p]                    ;; works — p is a value
[update-in user p [int+ _ 1]]     ;; works

;; Composition
def full := [path-append #p(address) #p(zip)]

;; Broadcast: map a path over a collection
def records := '[{:name "Alice" :age 30}, {:name "Bob" :age 25}]
records.*name                      ;; => '["Alice" "Bob"]
records.*address.zip               ;; => deep broadcast

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
#p(address.zip)          ;; deep path: 2 segments (canonical — no colon)
#p(name)                 ;; simple: 1 segment
#p(address.*)            ;; wildcard
#p(address.**)           ;; globstar
#p(address.{zip city})   ;; branching (multiple paths)
#p(:address.zip)         ;; also accepted — colon is optional inside #p(...)
```

The `#p(...)` reader syntax is chosen because:
- `#` prefix is the standard Racket convention for reader extensions
- Avoids collision with existing `#:keyword` syntax
- Parenthesized body uses existing path grammar from selections
- Clearly distinguishes path literals from keyword symbols

**Colon is optional:** Inside `#p(...)`, all identifiers are implicitly key segments. The `:` prefix is accepted for consistency with keyword syntax used elsewhere in the language, but the canonical form omits it for conciseness. The reader strips leading `:` from segments during parsing.

**Sexp equivalent:** `(path :address.zip)` — a special form recognized by the parser. In sexp mode, the colon is retained for consistency with keyword conventions.

**WS equivalent:** `#p(address.zip)` — the reader produces the sexp form.

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

### 3.8 Broadcast Path Syntax (`.*field`)

**Syntax:** `collection.*field` — maps a path extraction over every element in a collection.

```prologos
def records := '[{:name "Alice" :age 30}, {:name "Bob" :age 25}]
records.*name                ;; => '["Alice" "Bob"]
records.*age                 ;; => '[30 25]

;; Deep broadcast
def users := '[{:name "A" :address {:zip 97403}}, {... :address {:zip 10001}}]
users.*address.zip           ;; => '[97403 10001]

;; Broadcast with branching
users.*address.{zip city}    ;; => '[{:zip 97403 :city ...} ...]

;; Broadcast on solver results
def solutions := [solve (fresh [x y] (eq? [+ x y] 10))]
solutions.*x                 ;; => all x-values from solution maps
```

**Reader mechanics:** The reader already handles `.` as a delimiter and `*` as `ident-start?`. When the reader encounters `.*` followed by an identifier character, it emits a new sentinel `$broadcast-access`:

```
records.*name → records ($broadcast-access name)
records.*address.zip → records ($broadcast-access address) ($dot-access zip)
```

**Disambiguation from wildcard `.*`:**
- `.*` followed by `ident-continue?` character → broadcast (`$broadcast-access`)
- `.*` followed by whitespace/delimiter/nothing → wildcard (existing behavior in path contexts)
- Single character lookahead, unambiguous

**Desugaring:** `rewrite-dot-access` handles `$broadcast-access` by wrapping in `map-path`:

```racket
;; ($broadcast-access field) on target
;; → (map-path target #p(field))
;; which reduces to (map (fn ($x) (map-get $x :field)) target)
```

For deep broadcast (`records.*address.zip`), subsequent `$dot-access` sentinels are absorbed into the path:

```racket
;; records ($broadcast-access address) ($dot-access zip)
;; → (map-path records #p(address.zip))
```

**Type:** If `target : List (Map K V)` and the path reaches type `T`, then `target.*path : List T`. For `target : List (Schema S)`, the field type is looked up from the schema. Type errors if the collection element type doesn't support the path.

**`map-path` primitive:** A new built-in that maps a path extraction over a collection:

```prologos
spec map-path {A B : Type} [List A] Path -> [List B]
;; where B is the type reached by the path within A
```

This is more principled than desugaring to `map` + anonymous function — it preserves the path as a value for potential optimization (e.g., the reducer can fuse multiple `map-path` calls).

**Identifier restriction:** `*`-prefixed identifiers (e.g., `*foo` as a variable name) would become ambiguous after a dot. Since nothing in the codebase uses `*`-prefixed identifiers, restricting `*identifier` after `.` to mean broadcast is safe. Bare `*foo` (not after a dot) remains a valid identifier.

### 3.9 Path Combinators (Pure Prologos)

Path combinators are implemented in Prologos itself, with a thin foreign function layer for structural operations on the `expr-path` value.

**Foreign primitives (Racket-side, minimal):**

```prologos
;; Decompose a path into its keyword segments
foreign path-segments : Path -> [List Keyword]

;; Construct a path from keyword segments
foreign path-from-segments : [List Keyword] -> Path

;; Number of branches in a branching path
foreign path-branch-count : Path -> Int

;; Extract the nth branch as a single-branch path
foreign path-branch : Path -> Int -> Path
```

**Pure Prologos combinators (library `prologos.core.path`):**

```prologos
;; Append two single-branch paths
spec path-append Path Path -> Path
defn path-append [p1 p2]
  [path-from-segments [list-append [path-segments p1] [path-segments p2]]]

;; First segment as a single-segment path
spec path-head Path -> Path
defn path-head [p]
  [path-from-segments [list [head [path-segments p]]]]

;; All segments after the first
spec path-tail Path -> Path
defn path-tail [p]
  [path-from-segments [tail [path-segments p]]]

;; Depth (number of segments)
spec path-depth Path -> Int
defn path-depth [p]
  [length [path-segments p]]

;; Is this a single-segment (leaf) path?
spec path-leaf? Path -> Bool
defn path-leaf? [p]
  [eq? [path-depth p] 1]

;; Reverse a path
spec path-reverse Path -> Path
defn path-reverse [p]
  [path-from-segments [reverse [path-segments p]]]

;; Check if a path starts with a prefix
spec path-starts-with? Path Path -> Bool
defn path-starts-with? [p prefix]
  [list-starts-with? [path-segments p] [path-segments prefix]]

;; Apply a path to a map (equivalent to get-in with a path value)
spec path-get {A : Type} A Path -> A
defn path-get [target p]
  [get-in target p]

;; Map a path over a collection (broadcast)
spec map-path {A B : Type} [List A] Path -> [List B]
defn map-path [xs p]
  [map [fn [x] [get-in x p]] xs]
```

This design keeps the foreign layer minimal (4 functions for structural access) and puts all composition logic in user-space Prologos. Users can extend with their own combinators.

### 3.10 Lessons from Specter (Prior Art)

[Specter](https://github.com/redplanetlabs/specter) is a Clojure library for navigating and transforming nested data. Its core abstraction — **navigators** that compose into paths — validates several of our design choices and suggests future directions.

**Validated by Specter:**
- First-class paths that compose are the right abstraction level
- The `select`/`transform` duality (our `get-in`/`update-in`) is proven at scale
- Broadcast over collections (Specter's `ALL`, our `.*`) is the most-used navigator — essential, not optional
- Static path compilation (our elaboration-time inlining) matches Specter's "compiled paths" performance strategy

**Specter concepts mapped to Prologos:**

| Specter Navigator | Prologos Equivalent | Status |
|-------------------|---------------------|--------|
| `keypath` | `#p(field)` | In scope |
| `ALL` | `.*field` broadcast | In scope (Phase 7b) |
| `MAP-VALS` | `.*` on map (all values) | In scope |
| `MAP-KEYS` | Future: `.*:` or path combinator | Deferred |
| `FIRST`, `LAST` | `[0]`, `[-1]` postfix indexing | Exists |
| `filterer` | Future: predicate paths | Deferred |
| `walker` | `.**` globstar | Exists (in selections) |
| `if-path` | Future: conditional navigation | Deferred |
| `collect-one` | Future: context collection | Deferred |
| `must` | `#.field` nil-safe access | Exists |

**Design-for-future from Specter:**
1. **Conditional navigation (`if-path`):** Paths that branch based on predicates mid-traversal. The `Path` type should be extensible to support predicate segments (e.g., `#p(users.[age > 30].name)`) without breaking the current design.
2. **Context collection (`collect-one`):** Gathering values during traversal for use in transforms. Powerful for complex update-in patterns. Can be added as a combinator later.
3. **Protocol paths:** Type-aware navigation for heterogeneous collections. Our schema system + trait dispatch could enable this naturally — a path navigator that dispatches on the element's schema type.

**What we intentionally differ from Specter on:**
- Specter navigators are functions (dynamic composition). Our paths are **values** (data). This matches Prologos's homoiconicity principle — paths are data you can inspect, serialize, and reason about, not opaque function compositions.
- Specter's `transform` preserves collection type (vector stays vector). Our `update-in` does this naturally via immutable CHAMP operations — no special handling needed.

### 3.11 Key Renaming with `^` (Projection Syntax)

Path selections can rename keys in the output map using `^`:

```prologos
def user := {:user-name "Pete" :id 1234 :address {:zip 12345 :city "Springfield"}}

;; Select and rename keys
user.{user-name^userName id^userID address.city^location}
;; => {:userName "Pete" :userID 1234 :location "Springfield"}
```

The `^` reads as "as" — analogous to SQL's `SELECT user_name AS userName`. The rename applies to the **leaf** of the path: `address.city^location` extracts the value at `:address.city` and places it under `:location` in the result map.

**Syntax within path contexts:**

```
segment^rename       ;; rename a simple field
deep.path^rename     ;; rename the leaf of a deep path
```

**Interaction with branching:**

```prologos
user.{user-name^name address.{zip city^loc}}
;; => {:name "Pete" :zip 12345 :loc "Springfield"}
```

The `^` is per-branch-leaf. Branches without `^` retain their original key name.

**Interaction with path literals:**

```prologos
#p(user-name^userName)           ;; path with rename annotation
#p(address.{zip city^loc})       ;; branching with partial renames
```

**Scope of renaming:** Renaming is a **projection** operation — it applies to `get-in` and `selection`, NOT to `update-in`. `update-in` modifies a value at a path in-place; renaming the key would be semantically incoherent there. This is enforced at parse time.

**Pipeline placement:**
- `^` is recognized by the path parser inside path contexts (selections, `#p(...)`, `get-in` keyword args)
- `^` is NOT in `ident-start?` or `ident-continue?` in the reader, so no identifier collision
- The parser produces path segments annotated with optional renames: `(segment keyword rename-keyword-or-#f)`
- Elaboration emits `map-assoc` with the renamed key when a rename is present

**Sexp equivalent:**

```scheme
;; user.{user-name^userName id^userID}
;; parses to path branches with renames:
;; ((#:user-name . #:userName) (#:id . #:userID))
(get-in user (path :user-name^userName :id^userID))
```

### 3.12 Path Destructuring in Pattern Matching

Paths participate in pattern matching like any first-class value:

```prologos
(match p
  | #p(head . rest) -> ...     ;; decompose: first segment + remaining path
  | #p(a.b)         -> ...     ;; match exact 2-segment path
  | #p(_)           -> ...     ;; match any single-segment path
  | #p(_ . _)       -> ...     ;; match any path with 2+ segments
)
```

This is more ergonomic than `path-head`/`path-tail` for routing on path structure. The function combinators retain their place for composition (`path-append` in a `fold`, `path-depth` as a predicate).

**Implementation:** A new pattern kind in the pattern compiler. The path pattern `#p(head . rest)` desugars to matching on the internal segments list, piggybacking on existing list pattern machinery. Requires updates to `pattern-is-simple-flat?`, `compile-match-tree`, and the narrowing handlers per the pipeline checklist for new pattern kinds.

**Phase:** Part of Phase 7 (path combinators), since it requires the `Path` type and `expr-path` AST node from earlier phases.

### 3.13 `map-path` Implementation Note

The broadcast `.*field` desugars to `map-path`. The initial implementation should desugar `map-path` to `map` + lambda rather than introducing a distinct primitive:

```prologos
;; map-path as sugar
[map-path records #p(name)]  ≡  [map [fn [x] [get-in x #p(name)]] records]
```

This avoids a new reduction rule and leverages existing `map` infrastructure. Promotion to a distinct primitive (for fusion optimizations, e.g., fusing consecutive `map-path` calls) is deferred until profiling shows a need.

### 3.14 Interaction with Existing Features

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
- Path combinators and destructuring
- Broadcast `.*field` syntax
- Key renaming `^` syntax
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

### Phase 7: Path Combinators + Destructuring (M, Library)
- Foreign primitives: `path-segments`, `path-from-segments`, `path-branch-count`, `path-branch`
- Pure Prologos combinators in `prologos.core.path`: `path-append`, `path-head`, `path-tail`, `path-depth`, `path-leaf?`, `path-reverse`, `path-starts-with?`, `path-get`, `map-path`
- Path destructuring pattern kind: `#p(head . rest)` desugars to list pattern on segments
- Update `pattern-is-simple-flat?`, `compile-match-tree`, narrowing handlers
- Tests for composition, round-tripping, and pattern matching on paths

### Phase 7b: Broadcast Syntax `.*field` (M)
- Reader: `$broadcast-access` sentinel when `.*` followed by `ident-continue?`
- Preparse: `rewrite-dot-access` handles `$broadcast-access` → desugar to `[map [fn [x] [get-in x path]] target]`
- Deep broadcast: absorb subsequent `$dot-access` sentinels into the path
- Type: `List (Map K V)` + path → `List T` where T is the reached type
- Tests: L1 sexp, L2 WS, L3 acceptance file

### Phase 7c: Key Renaming `^` Syntax (M)
- Parser: recognize `^` within path contexts as rename annotation on leaf segment
- Path segment representation extended: `(keyword . rename-keyword-or-#f)`
- Elaboration: emit `map-assoc` with renamed key when rename is present
- Scoped to `get-in` and `selection` only — parse error if used in `update-in`
- Tests: renaming in simple paths, deep paths, branching paths, error on update-in

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
| Colon optional inside `#p(...)` | Inside a path literal, everything is implicitly a key segment. `:` is accepted but not required. Canonical form is `#p(address.zip)`. |
| Unparameterized `Path` type | Path doesn't know what it navigates — types come from the application site (`get-in m p`). Phantom typing can be added later without breaking changes. |
| Static path inlining at elaboration | Zero-cost abstraction: literal paths compile away to the same chained `map-get` as today. Only dynamic paths (variables) pay the `expr-get-in` cost at reduction. |
| `.*field` for broadcast | Mirrors Specter's `ALL` navigator — the most-used pattern. Syntax is concise, disambiguable from wildcard `.*` by single-char lookahead, and composes with deep paths (`.*address.zip`). |
| Paths as values, not functions | Differs from Specter's navigator-as-function approach. Paths are inspectable data, matching Prologos's homoiconicity principle. Lens/optic function pairs can be built on top. |
| Branch lookups are parallelizable | Branching paths (`#p(address.{zip city})`) produce independent lookups on immutable data. Currently sequential at elaboration; the propagator network could parallelize them in future. |
| Lenses deferred, not rejected | Lenses compose beautifully but require significant type machinery (especially with dependent types). First-class paths provide the foundation; lenses can be built on top as a library. |
| Path combinators: thin foreign + pure Prologos | 4 foreign primitives for structural access (`path-segments`, `path-from-segments`, `path-branch-count`, `path-branch`), all composition logic in pure Prologos. Users can extend freely. |
| `^` for key renaming in projections | Analogous to SQL `AS`. Applies to leaf of path; scoped to `get-in`/`selection` (not `update-in`). `^` is unused in reader, no collision. |
| Path destructuring via pattern matching | `#p(head . rest)` desugars to list pattern on segments. More ergonomic than `path-head`/`path-tail` for routing on path structure; combinator functions remain for composition contexts. |
| `map-path` as sugar over `map` + lambda | Start with desugar, not a distinct primitive. Promote to primitive only if fusion optimization is needed later. Avoids premature abstraction. |
