# Surface Language Ergonomics Sprint

Created: 2026-03-09
Source: User session notes from hands-on `.prologos` usage

## Issues Reported

| # | Summary | Current Behavior | Expected Behavior |
|---|---------|-----------------|-------------------|
| 1 | `solve` output missing bound variables | `add ?y 3N = 5N` → `'{:y 2N}` | `'{:y 2N :y_ 3N}` — show bound args with `_` suffix, pull names from `spec` |
| 2 | `=` without `?` vars → unbound variable error | `[plus 1N 2N] = 3N` → "Unbound variable: =" | `true` or `false` — evaluate both sides, check unification |
| 3 | `let` binding broken with narrowing + multiple forms | `let s := add ?x 10N = 33N` → unbound; multi-let fails | Sequential lets, flat-pair lets, `=` in value position |
| 4 | Index postfix notation with path algebra | Not implemented | `xs[0].users[1].{username id}` — bracket-index + dot-access + selection |
| 5 | Mixfix operators in narrowing | `.{1N + ?y} = 3N` → `nil` | `'{:y 2N}` — narrow through trait-dispatched operators |

---

## Root Cause Analysis

### Issue 1: Narrowing output doesn't include bound args
- `run-narrowing-search` (narrowing.rkt:529) takes a `var-names` list and only projects those
- `var-names` comes from `collect-narrow-vars` (parser.rkt:5822) which finds `?`-prefixed symbols
- No connection to `spec` parameter names — solver doesn't know the function's declared parameter names
- **Fix**: After solving, look up the function's `spec`, zip parameter names with bound arg values, suffix with `_`

### Issue 2: `=` without logic vars falls through to application
- Parser's `=` handler (parser.rkt:2680-2694): if `collect-narrow-vars` returns `'()`, falls through to `parse-application`
- `parse-application` treats `=` as a variable lookup → "Unbound variable: ="
- **Fix**: Add a third branch — no `?` vars → `surf-eq-check` or similar that evaluates both sides and returns Bool

### Issue 3: `let` binding — three sub-issues
- **3a**: `let s := narrowing-expr` — the `expand-let` preparse macro (macros.rkt:3521) splits at `:=` correctly, but the value expression `add ?x 10N = 33N` contains `=` which gets parsed in a context where `=` fails (Issue 2). Fixing Issue 2 partially fixes this.
- **3b**: Sequential `let` — `let x := v1\nlet y := v2\n body` — WS reader produces separate top-level forms, not a nested let. Need either: (a) WS reader recognizes `let` blocks, or (b) preparse macro detects sequential lets and nests them.
- **3c**: Flat-pair `let [x v1 y v2 z expr] body` — `expand-let` expects `[[x v1] [y v2]]` (list-of-lists) but user wrote flat pairs. Need: detect and partition flat lists into 2-element pairs.

### Issue 4: Index postfix notation
- Brackets `[]` currently reserved for grouping/application in the WS reader
- No postfix index syntax exists — `x[0]` would be parsed as two separate tokens `x` and `[0]`
- Reader-level change needed: detect `ident[expr]` as postfix index (no whitespace between ident and `[`)
- Must integrate with existing dot-access (`.field`) and selection paths (`.{branch}`)
- Largest scope item — new syntax in reader, parser, and elaborator

### Issue 5: Narrowing through trait-dispatched operators
- Mixfix `.{1N + ?y}` correctly expands to `(+ 1N ?y)` via pratt-parse
- `(= (+ 1N ?y) 3N)` is correctly recognized as narrowing (has `?y`)
- Parsed as `surf-narrow` → enters narrowing engine
- Narrowing engine calls `run-narrowing-search` with function `+`
- `+` is a trait-dispatched generic, NOT a `defn` — no definitional tree, no function body to narrow through
- Returns empty solutions → `nil`
- **Fix**: Narrowing engine needs to resolve trait dispatch to concrete instances, then narrow through the instance body

---

## Grouping & Batching Strategy

### Batch 1: `=` Operator Semantics + Let Binding Fixes
**Files**: parser.rkt, macros.rkt
**Rationale**: Issues 2, 3 share parser/macros code paths. Fixing `=` semantics (Issue 2) partially unblocks Issue 3a. Let binding fixes are all in the same preparse macro.

| Phase | Description | Depends On |
|-------|-------------|------------|
| 1a | `=` without `?` vars → evaluate + return Bool | — |
| 1b | `let` with `=` in value position (unblocked by 1a) | 1a |
| 1c | Sequential `let` blocks: `let x := v1\nlet y := v2` | — |
| 1d | Flat-pair `let [x v1 y v2] body` syntax | — |

### Batch 2: Narrowing Output Enrichment + Trait-Dispatch Narrowing
**Files**: narrowing.rkt, parser.rkt, driver.rkt
**Rationale**: Issues 1, 5 both touch the narrowing engine. Enriching output (bound vars + spec names) and enabling trait-dispatch narrowing are related — both require the narrowing engine to understand more about the function being narrowed.

| Phase | Description | Depends On |
|-------|-------------|------------|
| 2a | Bound variable tracking with `_` suffix in output | — |
| 2b | `spec` parameter name lookup for narrowing results | 2a |
| 2c | Key collision handling design (user vars vs bound vars) | 2a |
| 2d | Narrowing through trait-dispatched operators (`+`, `-`, etc.) | — |

### Batch 3: Index Postfix Notation + Path Algebra Extension
**Files**: reader.rkt, parser.rkt, elaborator.rkt
**Rationale**: Issue 4 is self-contained and the largest scope item. Touches the reader (new token type), parser (new expression form), and integrates with existing dot-access and selection-path infrastructure.

| Phase | Description | Depends On |
|-------|-------------|------------|
| 3a | `x[n]` bracket-index postfix in reader (no-space rule) | — |
| 3b | Chained indexing: `x[0][1]`, `x[0].field` | 3a |
| 3c | Path algebra integration: `.{field1 field2[0].sub}` | 3a, 3b |

---

## Recommended Execution Order

```
Batch 1 (small, high-impact)     Batch 2 (medium, narrowing)     Batch 3 (large, new syntax)
├─ 1a: = as Bool check           ├─ 2a: bound var _ suffix        ├─ 3a: x[n] postfix
├─ 1b: let + = interop           ├─ 2b: spec param names          ├─ 3b: chained index
├─ 1c: sequential let            ├─ 2c: collision handling         └─ 3c: path algebra
└─ 1d: flat-pair let             └─ 2d: trait-dispatch narrowing
```

**Batch 1 → Batch 2 → Batch 3** (left to right)

Rationale:
- Batch 1 is smallest scope, highest daily-usage impact — `=` and `let` are fundamental
- Batch 2 enriches the narrowing experience, builds on Batch 1's `=` fixes
- Batch 3 is the largest and most independent — can be done any time

---

## Design Notes

### 1a: `=` as Boolean Equality Check

When `=` has no `?`-prefixed variables on either side:
- Evaluate both sides to WHNF
- Compare structurally (or via `Eq` trait if available)
- Return `true : Bool` or `false : Bool`

This makes `=` a universal operator:
- With `?` vars → narrowing (returns solution maps)
- Without `?` vars → equality check (returns Bool)
- In relational context → unification goal (existing behavior)

Parser change at line 2693-2694: desugar to `(eq-check a b)` — a wrapper function in `eq.prologos` with `spec eq-check [Eq A] A A -> Bool` that delegates to the `eq?` trait method with a dictionary constraint. Added `eq-check` to prelude imports in `namespace.rkt`.

**Note**: `=` as a keyword in the parser intercepts before application lookup. Code that declares `=` as a foreign function (e.g., `(foreign racket "racket/base" (= : Nat Nat -> Bool))`) should use `:as` qualifier to avoid the keyword: `(foreign racket "racket/base" :as rkt (= ...))` then `(rkt/= ...)`.

**Implementation detail**: `merge-sibling-lets` handles single bodyless lets by first pre-processing with `preprocess-let-infix-eq` (restructures `a = b` → `(= a b)` in value tokens) so that `let-bodyless?` correctly identifies lets whose values contain `=`.

### 1c: Sequential Let Blocks

Two design options:

**Option A: Preparse macro detects consecutive lets**
The preparse macro sees `(let x := v1 (let y := v2 body))` and nests them.
Pro: No reader changes. Con: Requires WS reader to group consecutive lets.

**Option B: WS reader `let`-block syntax**
```prologos
let
  x := 21
  y := 23
  z := [plus x y]
in z
```
Pro: Clean syntax. Con: New reader rule, `in` keyword.

**Option C: Implicit nesting — consecutive top-level lets scope into next expression**
```prologos
let x := 21
let y := 23
let z := [plus x y]
z
```
Pro: Minimal syntax. Con: Scoping rules complex — where does the let end?

Recommend starting with **Option A** (preparse nesting) as it's the smallest change.

### 2a-2c: Bound Variable Tracking

Current output: `'{:y 2N}` for `add ?y 3N = 5N`
Proposed output: `'{:y 2N :y_ 3N}` where `y_` = the bound argument

Implementation:
1. In `run-narrowing-search`, after solving, look up `spec` for the function
2. Extract parameter names from the spec's Pi-type binders
3. For each parameter that was bound (not a `?` var), add `param_` → value to result map
4. Collision risk: user has `?y` AND the spec has param named `y` → `y` and `y_` are both present (fine, no collision)
5. Edge case: user has `?y_` (with underscore) → would collide with bound var suffix. Options:
   - (a) Restrict `?` vars from ending in `_` (arbitrary, user-hostile)
   - (b) Double the suffix: `y__` for spec params when `y_` is taken
   - (c) Use a different sigil: `y·` or `y@` or `:bound-y`
   Recommend **(c) with `:bound-` prefix**: `{:y 2N :bound-y 3N}` — unambiguous, no collision possible with user vars since `?bound-y` would be `?bound-y` not `:bound-y`.

Actually, the user's suggestion of `_` suffix is elegant. Collision is unlikely in practice. Start with `_` suffix, document the convention, handle collisions if they arise.

### 2d: Trait-Dispatch Narrowing

The narrowing engine currently only narrows through `defn`-defined functions (which have definitional trees extracted from their pattern-match structure). Trait-dispatched operators like `+` resolve to instance methods at elaboration time.

Approach:
1. When narrowing encounters a trait-dispatched function, resolve the trait to the concrete instance for the known types
2. If all arguments have known types → resolve to instance method → narrow through that body
3. If argument types are unknown (logic vars) → enumerate possible instances and branch (ATMS `amb`)
4. For builtin numeric operations (`+` on `Nat` is `nat-add`, on `Int` is `int-add`), can short-circuit to inverse operations

This is the most complex item — essentially teaching the narrowing engine about the trait system.

### 3a: Bracket-Index Postfix

Reader rule: when `]` is immediately followed by `[` (no whitespace), or when an identifier/closing-bracket is immediately followed by `[` (no whitespace), treat as postfix index.

```
xs[0]      → (index-get xs 0)
xs[0][1]   → (index-get (index-get xs 0) 1)
xs[0].name → (map-get (index-get xs 0) :name)
```

New reader token: `$postfix-index` wrapping the indexee and the index expression.
Preparse macro: `rewrite-postfix-index` desugars to `index-get` calls (or `nth` / `pvec-get` depending on type).

The no-space rule is critical — `xs [0]` is application (passing list `[0]`), but `xs[0]` is indexing.

---

## Progress Tracker

| Phase | Status | Commit |
|-------|--------|--------|
| 1a: `=` as Bool check | DONE | `f4ef4c0`, `587cacf` |
| 1b: let + = interop | DONE | `4584739`, `d2714ef`, `587cacf` |
| 1c: sequential let | DONE (already worked) | verified in `587cacf` |
| 1d: flat-pair let | DONE | `b8b5039`, `587cacf` |
| 2a: bound var `_` suffix | NOT STARTED | |
| 2b: spec param names | NOT STARTED | |
| 2c: collision handling | NOT STARTED | |
| 2d: trait-dispatch narrowing | DONE (Stage 3 Phase 2a) | `44539b1` (resolve-generic-narrowing) |
| 3a: `x[n]` postfix index | NOT STARTED | |
| 3b: chained indexing | NOT STARTED | |
| 3c: path algebra integration | NOT STARTED | |
