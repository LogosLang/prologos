# Writing .prologos Files

## Delimiters

- **`[]` for all functional contexts** -- application `[f x y]`, lambda `[fn [x : Int] body]`, partial application `[int* _ 2]`. Square brackets are the universal functional delimiter.
- **`()` only for parser keywords** -- `(match ...)`, `(the ...)`, `(def ...)`, and relational goals inside `solve`/`defr`. These signal "special form, not application."
- **`<>` for type-level grouping** -- Pi `<(x : A) -> B>`, Sigma `<(x : A) * B>`, union `<Int | String>`.
- **`{}` for maps and implicit binders** -- map literals `{:name "alice"}`, implicit type binders `{A B : Type}` in specs (but see "Implicit binder inference" below — most specs do not need them).

## Definitions

- **`spec`/`defn` for functions** -- spec declares the signature, defn provides the implementation.
- **`def` for top-level bindings** -- `def x : T := expr`. Top-level `let` is not legal in `.prologos` files.
- **`:=` for binding** -- `def x := val`, `type Foo := A | B`, `bundle Num := (Add Sub Mul)`.
- **`=` is RESERVED** for the `unify` operation -- never use `=` for binding or type definitions.

## Pattern matching and dispatch

- **Multi-arity `defn` is the primary dispatch mechanism.** If a function dispatches on its argument's constructors, use `defn foo | pattern -> body`, NOT `defn foo [x] match x | ...`.
- **`match` is for mid-expression dispatch** -- when matching inside a larger body, not at the top level of a definition.
- **Avoid `if`** -- structural pattern matching via multi-arity `defn` is always preferred. `if` is essentially redundant in a language with pattern matching on Bool. Minimize its use; prefer `defn foo | true -> ... | false -> ...`.

## Application style

- **Uncurried** -- `defn foo [x y z] body`, `spec f A B -> C`. Multiple arguments in one bracket group.
- **Prefer partial application with wildcards** over inline lambdas -- `[int* _ 2]` rather than `[fn [x] [int* x 2]]`. Use `fn` only when the lambda body is complex enough to need named parameters.
- **Pipeline `|>` and `compose`** for chaining named functions -- `|> 5 inc dbl sqr` is idiomatic.
- **Eval is implicit** -- write `[f x]` not `eval [f x]`. Top-level expressions just evaluate.
- **Don't wrap outer tree** -- top-level forms are implicit.

## Type annotations

- **Prefer type inference** where unambiguous -- `def x := 42` over `def x : Int := 42`. We work hard on inference; lean on it. Use explicit annotations when the type is genuinely ambiguous (union types, polymorphic contexts) or for documentation in specs.
- **Angle brackets for complex types** -- `<Int | String>`, `<(x : A) -> B>`.
- **`{A B : Type}` for implicit erased binders** in `spec` -- but **prefer the bare form** when D1/D2 covers the binders (see "Implicit binder inference" below).

## Implicit binder inference (issue #20)

`spec` auto-introduces implicit binders for capitalized identifiers that appear free in the signature. Two directions, additive:

- **Direction 1**: a capitalized identifier `A`, `B`, ... that appears free in the spec body and is not a known type or constructor name is introduced as `{A : Type}`.

  ```
  spec length [List A] -> Nat        ;; equivalent to {A : Type} [List A] -> Nat
  spec const A -> B -> A             ;; equivalent to {A : Type} {B : Type} A -> B -> A
  ```

- **Direction 2**: when a free variable appears in a `:where (TraitName Var)` clause (or as an inline trait constraint before the first `->`), the binder's kind is inferred from the trait declaration. If `Seqable` is declared over `{C : Type -> Type}`, then `C` in `[Seqable C]` is auto-introduced as `{C : Type -> Type}`.

  ```
  ;; Before (issue #20):
  spec gmap {A B : Type} {C : Type -> Type}
       [Seqable C] -> [Buildable C] -> [A -> B] -> [C A] -> [C B]

  ;; After:
  spec gmap [Seqable C] -> [Buildable C] -> [A -> B] -> [C A] -> [C B]
  ```

**Canonical form**: drop both kinds of explicit binders. Keep them only when:

- The spec has no constraining position to anchor inference (e.g. `spec empty {A : Type} [List A]` — `A` has no usage that would pin it).
- Disambiguating a genuinely ambiguous spec (rare).
- Pedagogic clarity in book / tutorial code.

**Trait declarations are NOT specs**: `trait Seqable {C : Type -> Type}` MUST keep its explicit binder — D1/D2 only run on `spec`, not on `trait` declarations.

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

;; Bare-binder spec (D1+D2): no explicit {A : Type} or {C : Type -> Type}
spec gmap [Seqable C] -> [Buildable C] -> [A -> B] -> [C A] -> [C B]
```
