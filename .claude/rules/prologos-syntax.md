# Writing .prologos Files

## Syntax
- Prefer `spec`/`defn` for function definitions
- `[]` for grouping/application, NOT `()` -- parens only for parser keywords: `(match ...)`, `(fn ...)`, `(the ...)`, `(def ...)`
- Angle brackets for Pi: `<(x : A) -> B>`, Sigma: `<(x : A) * B>`
- `{A B : Type}` for implicit erased binders in `spec`
- List literals: `'[1N 2N 3N]` not cons chains
- Uncurried: `defn foo [x y z] body`
- Don't wrap outer tree -- top-level forms are implicit
- Eval is implicit -- write `[f x]` not `eval [f x]`

## Naming
- Predicates: `?` suffix (`zero?`, `empty?`)
- No module prefix repetition (`head` not `list-head`)
- Helpers: Use multi-arity defn with `|`
- Transducers: `-xf` suffix (`map-xf`, `filter-xf`)
- Trait methods: short names (`eq?`, `from`, `add`)

## Reference examples
<!-- - Pure WS:  -->
<!-- - Sexp fallback: -->
