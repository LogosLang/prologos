# Writing .prologos Files

## Delimiters

- **`[]` for all functional contexts** -- application `[f x y]`, lambda `[fn [x : Int] body]`, partial application `[int* _ 2]`. Square brackets are the universal functional delimiter.
- **`()` only for parser keywords** -- `(match ...)`, `(the ...)`, `(def ...)`, and relational goals inside `solve`/`defr`. These signal "special form, not application."
- **`<>` for type-level grouping** -- Pi `<(x : A) -> B>`, Sigma `<(x : A) * B>`, union `<Int | String>`.
- **`{}` for maps and implicit binders** -- map literals `{:name "alice"}`, implicit type binders `{A B : Type}` in specs.

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
- **Prefer partial application with wildcards** over inline lambdas -- `[int* _ 2]` rather than `[fn [x] [int* x 2]]`. Use `fn` only when the lambda body is complex enough to need named parameters.
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
