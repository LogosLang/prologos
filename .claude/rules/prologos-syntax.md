# Writing .prologos Files

## Delimiters

- **`[]` for all functional contexts** -- application `[f x y]`, lambda `[fn [x : Int] body]`, partial application `[int* _ 2]`. Square brackets are the universal functional delimiter.
- **`()` only for parser keywords and RELATIONAL GOALS** -- `(match ...)`, `(the ...)`, `(def ...)`, and goals. These signal "special form, not application." Since Rel T1 POL.9 this is load-bearing rather than conventional: **a paren group in command position IS a goal** (see § Relational syntax below).
- **`<>` for type-level grouping** -- Pi `<(x : A) -> B>`, Sigma `<(x : A) * B>`, union `<Int | String>`.
- **`{}` for maps and implicit binders** -- map literals `{:name "alice"}`, implicit type binders `{A B : Type}` in specs.

## Reader (WS vs sexp)

- **WS-reader vs sexp-reader divergence** -- the WS reader tokenizes chars the sexp reader passes through: `.` (dot-access), `?`/`!` (predicate/mutation suffixes), `<`/`>` (angle-type groups), `^` (rename). Any change to keyword/identifier tokenization, or any feature whose surface uses these chars, must be validated AND census'd in **both** reader modes -- sexp-green ≠ WS-correct (CIU T6 F1b hit it 3×: dotted-`ns`, `?`-suffixed keyword keys, `<`-in-`:check`-preds were all WS-reader-only). Tokenization recognizers must delegate to the ONE predicate (`ident-continue?`), never inline a charset -- inline charsets silently drift (the F1b.7g bug: `recognize-keyword` had drifted from `ident-continue?` for 8 chars while its siblings delegated).

## Definitions

- **`spec`/`defn` for functions** -- spec declares the signature, defn provides the implementation.
- **`def` for top-level bindings** -- `def x : T := expr`. Top-level `let` is not legal in `.prologos` files.
- **`:=` for binding** -- `def x := val`, `type Foo := A | B`, `bundle Num := (Add Sub Mul)`.
- **`=` is RESERVED** for the `unify` operation -- never use `=` for binding or type definitions.

## Pattern matching and dispatch

- **Multi-arity `defn` is the primary dispatch mechanism.** If a function dispatches on its argument's constructors, use `defn foo | pattern -> body`, NOT `defn foo [x] match x | ...`.
- **`match` is for mid-expression dispatch** -- when matching inside a larger body, not at the top level of a definition.
- **Avoid `if`** -- structural pattern matching via multi-arity `defn` is always preferred. `if` is essentially redundant in a language with pattern matching on Bool. Minimize its use; prefer `defn foo | true -> ... | false -> ...`.
- **Multi-line clause body: continuation indented past the `|`.** When a clause body is more complex than a single inline expression (e.g., contains a nested `match`), put the body on the next line indented further than the `|` it belongs to. This is the canonical layout-based form, consistent with `defn` body, `def := body`, and `let` body indentation rules:
  ```
  defn nth [n xs]
    | n nil -> none
    | n [cons h t] ->
      match [eq n 0]
        | true  -> [some h]
        | false -> [nth [- n 1] t]
  ```
  Body at the **same** indent as `|` is a layout violation (currently produces a hard parser error; tracked in issue #27 for diagnostic improvement). Body indent must be **strictly greater than** the `|` column.

## Application style

- **Uncurried** -- `defn foo [x y z] body`, `spec f A B -> C`. Multiple arguments in one bracket group.
- **Prefer partial application with wildcards** over inline lambdas -- `[int* _ 2]` rather than `[fn [x] [int* x 2]]`. Use `fn` only when the lambda body is complex enough to need named parameters. Partials are ALWAYS explicit-hole sections (`[+ 7 _]`); under-application (`[+ 7]`) is an error, never an implicit partial (D-N6E.1).
- **Operators are first-class values** (Numerics N6e-E2) -- `+`, `-`, `*`, `/`, `negate`, `abs` can be passed to higher-order functions directly: `reduce + 0 xs`, `map negate xs`. Semantics pin: in HEAD position at arity 2, `[+ a b]` is the parser keyword with **auto-widening** numeric-join (mixed numeric types fine: `[+ 1 1.5]` → Posit32); everywhere else the name denotes the lawful **same-type** trait function (`{A} A A -> A where (Add A)`, dicts resolved from context). HOF contexts are homogeneous by container, so the difference rarely surfaces.
- **Pipeline `|>` and `compose`** for chaining named functions -- `|> 5 inc dbl sqr` is idiomatic.
- **Eval is implicit** -- write `[f x]` not `eval [f x]`. Top-level expressions just evaluate.
- **Don't wrap outer tree** -- top-level forms are implicit.

## Type annotations

- **Prefer type inference** where unambiguous -- `def x := 42` over `def x : Int := 42`. We work hard on inference; lean on it. Use explicit annotations when the type is genuinely ambiguous (union types, polymorphic contexts) or for documentation in specs.
- **Angle brackets for complex types** -- `<Int | String>`, `<(x : A) -> B>`.
- **`{A B : Type}` for implicit erased binders** in `spec`.

## Lists and literals

- List literals: `'[1N 2N 3N]` not cons chains
- Map literals: `{:key val :key2 val2}`
- Nat literals: `0N`, `3N`, `5N` (NOT bare `0`, `3` which are Int)

## Naming

- Predicates: `?` suffix (`zero?`, `empty?`)
- No module prefix repetition (`head` not `list-head`)
- Helpers: Use multi-arity defn with `|`
- Transducers: `-xf` suffix (`map-xf`, `filter-xf`)
- Trait methods: short names (`eq?`, `from`, `add`)
- Module paths use `::` not `.` -- `str::length`, `prologos::data::nat`
- Dot access is for map keys -- `user.name` -> `[map-get user :name]`

## Relational syntax (`defr` / `rel` / goals)

Landed in Rel Track 1 (POL.7/.8/.9, 2026-07-25). All three are **additive** —
the older parenthesized spellings remain legal everywhere.

- **Facts: `||` blocks, one row per line, or `|` row separators on one line.**
  `defr digits [?d]` + `|| 0 | 1 | 2 | … | 9` is ten rows. Pipes = EXPLICIT
  rows (each segment must match the arity exactly; an empty segment errors).
  Without pipes, terms chunk by arity and a **partial remainder is a loud
  error** (it used to register a silent dead row no query could match).

- **Rule clauses: `&>` groups may drop the goal parens (layout decides).**
  The `&>` line's HEAD TOKEN chooses the reading: a `(` head means the line is
  a *sequence* of paren goals (each one parenthesized — mixing errors); a
  symbol head means the line is **exactly one goal**, and parens inside it are
  ARGUMENT terms (so `not (= c n)` works). Continuation lines: a line at the
  first goal's column is a **sibling goal** (conjunction); a line indented
  **deeper** continues the previous goal; a line between the `&>` column and
  the goal column is a mis-indent error naming both columns.

  ```
  defr fruit-not-of-color [?fruit ?not-color]
    &> fruit-color fruit color      ;; bare head → one goal
       not (= color not-color)      ;; goal column → sibling goal

  defr same [?fruit ?not-color]
    &> fruit-color fruit color
       not                          ;; sibling goal…
         = color not-color          ;; …deeper → its argument
  ```

  Inside explicit parens (`(rel [x] &> …)`) the reader suspends indent
  grouping, but the same grammar applies (the parser regroups by srcloc).
  A zero-arg goal on its own line must be written `(foo)` — a lone token is
  spliced bare by the reader and cannot be told from an argument.

- **Goals carry an implicit `solve` at command position.** *Goal-ness comes
  from context (`defr`/`solve`/`rel` bodies) or from PARENS (everywhere
  else).* A paren group at top level or on a `def` RHS is a goal:

  ```
  (fruit-not-of-color f "red")        ;; ≡ solve (fruit-not-of-color f "red")
  def blues := (fruit-color f "blue") ;; ≡ := solve (…)  (POL.10 snapshot)
  ```

  `foo x` and `[foo x]` stay **application**; keyword heads keep their forms
  (`(match …)`, `(+ 1 2)`); `rel` is the one keyword that queries when
  parenthesized. Scope is command position ONLY — top-level commands and
  `def` RHS, **not** general expression position (a goal inside a `defn` body
  would make calls re-query the ambient fact store; that is a deferred
  purity question). `solve-one` / `explain` stay explicit (they are adverbs).

  ⚠ **Institutionalized WS-vs-sexp divergence, accepted eyes-open**: `(f x)`
  is a GOAL in WS but stays APPLICATION in the sexp IR (the WS reader marks
  paren origin; the native sexp reader does not). Writing sexp fixtures —
  including sexp-style `(def x : T (cons …))` forms embedded in `.prologos`
  files — you get application. Watch this when authoring sexp-mode tests.

- **`defn` and `defr` namespaces are DISJOINT** within a module: registering a
  name held by the other kind is an error pointing at the first. Same-kind
  redefinition stays legal, and the gate is **local-only** — shadowing a
  refer-imported name (e.g. a prelude `xor`) with your own `defr` is fine.

- **Solution sets are BAGS, not sets** (owner ruling, Rel T1 POL.1). `solve`
  returns **one row per derivation path**, so duplicate rows are expected and
  intended: the multiplicity IS the derivation count (the ATMS-as-provenance
  reading; ℕ-semiring provenance — a duplicate row is a distinct proof). This
  matches Prolog's `findall`/`bagof` default. Do **not** "fix" duplicate rows;
  an opt-in `distinct` (the `setof` analogue) is deferred to Rel T2, where it
  meets the DFS first-hit short-circuit question that dedup would make
  observable.

- ⚠ **`not` / `=` / `is` do NOT take the implicit solve.** They are parser
  keywords, so `(not (blocked "c"))` at top level is **functional Bool
  negation applied to a stuck goal term**, not a NAF query — it types as
  `Bool` and computes nothing useful. Write `solve (not (blocked "c"))`
  explicitly. (Verified 2026-07-25; tracked in DEFERRED.md.)

- **Diagnostics you should expect** (they are guiding, not generic): a paren
  goal over a function → "foo is a function — application is written
  [foo …]"; a wrong arity → the SWI-style "Unknown procedure: truths/1 —
  however, there are definitions for: truths/4"; an unsafe negation → the
  floundering error at `defr` registration.

## Nat vs Int

- **Int for computation** -- arithmetic, counting, general numeric work
- **Nat ONLY for inductive patterns** -- structural recursion, Peano arithmetic, type-level naturals, proofs
- **Generic arithmetic (`+`, `-`, `*`, `/`)** for polymorphic contexts via traits

## Reference examples

```
;; Multi-arity definition (PREFERRED)
spec is-zero Nat -> Bool
defn is-zero
  | zero  -> true
  | suc _ -> false

;; Partial application (PREFERRED over fn)
map [int* _ 2] '[1 2 3]

;; Pipeline
|> 5 inc dbl sqr

;; Closure returning function
spec make-adder Int -> [Int -> Int]
defn make-adder [n]
  [fn [x : Int] [int+ n x]]

;; Top-level def with inference
def greeting := "hello"

;; Generic arithmetic
[+ [* 3 4] [- 10 3]]
```
