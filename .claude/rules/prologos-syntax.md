# Writing .prologos Files

## Delimiters

- **`[]` for all functional contexts** -- application `[f x y]`, lambda `[fn [x : Int] body]`, partial application `[int* _ 2]`. Square brackets are the universal functional delimiter.
- **`()` only for parser keywords** -- `(match ...)`, `(the ...)`, `(def ...)`, and relational goals inside `solve`/`defr`. These signal "special form, not application."
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

- **Never write three-deep nested `match` as a single function body.** Three-deep nested `match` inside a single function body fails to elaborate at *import time* with "Unbound variable" errors in Prologos's current elaborator. The fix is mechanical: factor into a chain of single-match helpers. Each helper does one `match`, returns to the caller, the caller does the next `match`. Same semantics for the user, no elaborator failure. OCapN Phases 15 and 21 both shipped this workaround; codified after the second occurrence. Until the underlying elaborator bug is fixed, this is the safe pattern.
  ```
  ;; WRONG — fails at import time
  defn pipeline-deliver [target args v]
    match [lookup-actor target v]
      | some _ -> send-only target args v
      | none ->
          match [lookup-promise target v]
            | none -> v
            | some pst ->
                match pst
                  | pst-unresolved msgs -> ...
                  | _ -> v

  ;; RIGHT — helper chain
  spec deliver-to-promise Nat SyrupValue PromiseState Vat -> Vat
  defn deliver-to-promise [pid args pst v]
    match pst | pst-unresolved msgs -> ... | _ -> v

  spec deliver-to-promise-or-drop Nat SyrupValue Vat -> Vat
  defn deliver-to-promise-or-drop [target args v]
    match [lookup-promise target v]
      | none -> v
      | some pst -> deliver-to-promise target args pst v

  spec pipeline-deliver Nat SyrupValue Vat -> Vat
  defn pipeline-deliver [target args v]
    match [lookup-actor target v]
      | some _ -> send-only target args v
      | none -> deliver-to-promise-or-drop target args v
  ```

## Application style

- **Uncurried** -- `defn foo [x y z] body`, `spec f A B -> C`. Multiple arguments in one bracket group.
- **Prefer partial application with wildcards** over inline lambdas -- `[int* _ 2]` rather than `[fn [x] [int* x 2]]`. Use `fn` only when the lambda body is complex enough to need named parameters. Partials are ALWAYS explicit-hole sections (`[+ 7 _]`); under-application (`[+ 7]`) is an error, never an implicit partial (D-N6E.1).
- **Operators are first-class values** (Numerics N6e-E2) -- `+`, `-`, `*`, `/`, `negate`, `abs` can be passed to higher-order functions directly: `reduce + 0 xs`, `map negate xs`. Semantics pin: in HEAD position at arity 2, `[+ a b]` is the parser keyword with **auto-widening** numeric-join (mixed numeric types fine: `[+ 1 1.5]` → Posit32); everywhere else the name denotes the lawful **same-type** trait function (`{A} A A -> A where (Add A)`, dicts resolved from context). HOF contexts are homogeneous by container, so the difference rarely surfaces.
- **Pipeline `|>` and `compose`** for chaining named functions -- `|> 5 inc dbl sqr` is idiomatic.
- **Eval is implicit** -- write `[f x]` not `eval [f x]`. Top-level expressions just evaluate.
- **Don't wrap outer tree** -- top-level forms are implicit.
- **Keep multi-arg applications on a single line.** A continuation line whose first token is a bare identifier is parsed as a sibling form, not as more args to the previous head. Pitfalls #36 and #38 (goblin-pitfalls log) both stem from this:
  ```
  ;; WRONG — `es as qs p oqs ir er pm` is parsed as an application of `es` to 7 args
  bridge-state [list-filter-listeners-by-notified ls notified]
               es as qs p oqs ir er pm

  ;; WRONG — `let X := EXPR` value can't span lines; reader sees no value for X
  let step1 := [captp-incoming-with-state op1 [alloc-vat sa]
                 [bridge-state-with-our-session ver loc]]

  ;; RIGHT — all positional args on the function-head line; break BEFORE a bracketed sub-call (which becomes the last arg) if the line gets too long
  bridge-state [list-filter-listeners-by-notified ls notified] es as qs p oqs ir er pm
  ```
  If a line is unavoidably long, factor a sub-expression to a separate `let` or top-level helper rather than splitting positional args.

- **Single-arg `defn` over a `data` type uses `defn name [arg] match arg | ...`, NOT multi-arity `defn name | [pat1] -> ... | [pat2] -> ...`.** The latter shape can cause the elaborator to lift a phantom 2nd parameter (pitfall #37 in goblin-pitfalls). Multi-arity `defn` is fine for 2+ args; for one-arg over a data type, prefer `match`:
  ```
  ;; WRONG — inferred type becomes `PromiseState SyrupValue -> [Option SyrupValue]` (2 args)
  spec resolution-syrup-of-pst PromiseState -> [Option SyrupValue]
  defn resolution-syrup-of-pst
    | [pst-unresolved _] -> none
    | [pst-broken     r] -> some [wrap-error r]
    | [pst-fulfilled  v] -> some v

  ;; RIGHT — inferred type matches the spec
  spec resolution-syrup-of-pst PromiseState -> [Option SyrupValue]
  defn resolution-syrup-of-pst [pst]
    match pst
      | pst-unresolved _ -> none
      | pst-broken     r -> some [wrap-error r]
      | pst-fulfilled  v -> some v
  ```

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
- **NEVER use `->` in identifiers** (silently fails to compile per pitfall #35). Use `-to-` for converters: `refr-to-syrup`, `op-to-syrup`, `syrup-to-op`. The Common Lisp / Scheme convention `refr->syrup` is incompatible with Prologos's WS-mode reader, which parses `->` as the function-arrow type operator inside any identifier.

## Data type definitions

- **Constructor signatures have IMPLICIT return type** (per pitfall #34). Write `data X { ctor : T1 -> T2 }` to mean "ctor takes 2 args of types T1 and T2 and returns X." Do NOT write `ctor : T1 -> T2 -> X` — that means "takes 3 args (T1, T2, X) and returns X." Existing examples: `data Listener { listener : Nat -> Nat }`, `data QEntry { q-entry : Nat -> Nat }`. Symptom of getting it wrong: smart constructors fail with `Type mismatch [Pi T -> Result -> Result]`.

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
