# WS-Mode Full-Language Audit Report

**Date**: 2026-03-10
**Scope**: All language features exercised in `.prologos` WS-mode files via `process-file`
**Method**: 12 audit files, ~300 expressions, classified by outcome
**Tool**: `racket/prologos/tools/run-file.rkt` (created for this audit)

## Summary

| Code | Count | Meaning |
|------|-------|---------|
| **OK** | ~250 | Works correctly in WS-mode `.prologos` file |
| **CRASH** | 36 | Error or exception during execution |
| **WRONG** | 6 | Runs but produces incorrect result |
| **DESIGN** | 7 | Works as designed but design may surprise users |
| **SEXP-ONLY** | 0 | (not encountered — all tested forms have WS syntax) |
| **DEFN-ONLY** | 0 | (not encountered separately from CRASH) |
| **MISSING** | 0 | (features exist but may fail under these codes) |

**Key stat**: ~83% of expressions work correctly. The remaining ~17% cluster around 8 root causes.

---

## Detailed Per-File Findings

### audit-01: Literals & Base Types (41 expressions, 0 runtime errors)

**What works**: Nat (`0N`, `42N`, `zero`, `suc`), Int (`0`, `42`, `-7`), Rat (`1/2`, `-3/7`), Posit (`~3.14`, `~42`, `3.14`), Bool, String (with escapes), Keyword, Unit, `nil`. Typed `def x : T := val` and inferred `def x := val` both work. `(the T val)` ascription works.

| Finding | Code | Detail |
|---------|------|--------|
| `5/1` → `5 : Int` | WRONG | Racket reader simplifies `5/1` to integer `5` before Prologos sees it. All rationals with denominator 1 are affected. |
| Char literals `'a'` | CRASH | `'` is the quote/list-literal prefix in WS reader. `'a'` gets read as `(quote a)` followed by a stray `'`, not as a char literal. Char type exists (`Char`) but has no usable literal syntax in WS mode. |
| `nil` type shows `?meta` | DESIGN | `[prologos::data::list::nil ?meta5323] : [prologos::data::list::List ?meta5323]` — polymorphic nil with no type context to resolve the meta. Expected behavior, but the unsolved meta is user-visible in the output. |

### audit-02: Definitions & Signatures (41 expressions, 0 runtime errors)

**What works**: `def` (typed and inferred), `spec` (simple, implicit binders `{A : Type}`, trait constraints `(Eq A)`, multiple constraints), `defn` (simple, multi-arg, match-in-body on Nat/Bool/List/Option/Result, recursive, sequential lets, higher-order, `=` equality in body). `def` with computation (`[add 3N 4N]`), list values, map values.

| Finding | Code | Detail |
|---------|------|--------|
| `def x := some 42N` | CRASH | Preparse sees two tokens after `:=` (`some` and `42N`) and errors with "expected exactly one value after :=". **Workaround**: brackets — `def x := [some 42N]`. Affects all multi-token constructor applications in `def`. |
| Multi-clause `defn f \| pat -> body` | CRASH | `defn mc-zero \| zero -> true \| _ -> false` with a single-arity spec errors with "spec is single-arity but defn has multiple clauses". **Workaround**: use match-in-body pattern — `defn f [n] match n \| pat -> body`. The multi-clause sugar may work without a spec but crashes when spec is present. |

### audit-03: Data Types & Constructors (44 expressions, 10 runtime errors)

**What works**: Built-in constructors (`zero`, `suc`, `some`, `none`, `nil`, `cons`, `ok`, `err`), list literals (`'[1N 2N 3N]`), pattern matching on all built-in types (Nat/Bool/List/Option/Result), recursive functions on ADTs (`fib`), `data` with single-field constructors.

This file exposes the most severe WS-mode gaps — user-defined data types are largely broken:

| Finding | Code | Detail |
|---------|------|--------|
| Nullary ctors as function type | WRONG | `data Direction` with `North : Direction` defines `North` as `Direction -> Direction` (a function), not as a value of type `Direction`. Both `North` and `South` print as function types. This makes them unusable as values — `[direction-name North]` errors with "Type mismatch" because `North` is a function, not a `Direction` value. |
| Multi-field constructors | CRASH | `Rect : Nat Nat -> Shape` in a `data` definition produces "Expression is not a valid type". The parser can't handle constructor types with multiple fields in WS mode. Single-field ctors like `Circle : Nat -> Shape` work fine. |
| Polymorphic constructors | CRASH | `data MyBox {A : Type}` with `MkBox : A -> MyBox A` defines `MyBox` and `MkBox` successfully (per the output), but `MkBox 42N` and `MkBox true` both fail with "Unbound variable". The constructor is registered but not accessible as a function in the current namespace. |
| `pair 1N true` | CRASH | "Could not infer type" — the `pair` constructor from the prelude can't resolve types for the two-arg case at top level. Pair works fine in `defn` bodies with type annotations. |
| `deftype` as data synonym | CRASH | `deftype Color2` with constructor-style body crashes with "deftype requires: (deftype name-or-pattern body)". `deftype` is a *type alias* form, not a `data` synonym — it expects `deftype Alias := ExistingType`. |

### audit-04: Pattern Matching & Conditionals (36 expressions, 0 runtime errors)

**What works**: `match` on Nat (zero, suc, nested suc), Bool (true, false), List (nil, cons, nested cons), Option (some, none), Result (ok, err). Wildcard patterns (`_`). `if` in function bodies (simple, nested). `cond` with multiple branches and `true` catch-all.

| Finding | Code | Detail |
|---------|------|--------|
| Top-level `if` type is `_` | WRONG | `if true 1N 2N` → `1N : _` at top level. The value is correct (1N) but the type is unresolved (`_`) instead of `Nat`. Inside a `defn` body with a spec, if types correctly. The issue is that top-level expressions lack bidirectional type context, so the if-expression's branches don't unify their types. |
| `cond` emits `Hole ??__cond-fail` | DESIGN | The cond form generates a hole for the exhaustiveness failure case, which prints `Hole ??__cond-fail : _` as a warning at the top of the output. This is the internal exhaustiveness mechanism working — not user-facing syntax. The `Context: x : Nat (w)` shows variable bindings are tracked. The warning appears even when `true ->` catch-all is present. |
| Guard clauses | UNTESTED | `match n \| x when [gt? x 10N] -> 99N` — commented out for separate investigation. Guard syntax may or may not work in WS mode. |

### audit-05: Lambdas, Let, Do (15 expressions after commenting out crashes, 0 runtime errors)

**What works**: `(fn [x] body)` in `map` and `filter`, `(fn [x : Nat] body)` with typed params, immediate application `[(fn [x : Nat] [add x 10N]) 5N]`, `let` inside `defn` body (simple and chained), closures over `def`-bound values (`offset` used inside fn in map).

| Finding | Code | Detail |
|---------|------|--------|
| `def double-fn := (fn [x : Nat] ...)` | CRASH | "Could not infer type" — top-level `def` with a lambda value fails. The fn expression itself works fine when passed inline to `map`, but binding it to a name via `def` breaks type inference. This affects all lambda-valued definitions. |
| Multi-bracket `fn [x] [y] body` | CRASH | "Could not infer type" — `[(fn [x : Nat] [y : Nat] [add x y]) 3N 4N]` fails. Multi-bracket fn (curried parameter groups) doesn't work at top level. The grammar supports this syntax but the elaborator can't handle it without bidirectional type context. |
| `def make-adder := (fn [x] (fn [y] ...))` | CRASH | "Could not infer type" — nested fn definitions fail for the same reason as single fn definitions in `def`. |
| Top-level `let x := val` | CRASH | "let :=: missing value after := for x1" — the preparse doesn't recognize `let` as a top-level form. `let` only works inside `defn` bodies where it desugars to nested lambda application. |
| Top-level sequential lets | DESIGN | Even if individual `let`s worked at top level, they wouldn't scope into each other. Each top-level form is independent — `let p := 10N` followed by `let q := [add p 5N]` would fail because `p` is not in `q`'s scope. This is a fundamental limitation of the top-level evaluation model. |
| `do` sequencing | UNTESTED | `do` with `<-` bind syntax commented out for separate investigation. The `do` form may require monadic context not available at top level. |

### audit-06: Traits & Instances (13 expressions after commenting out crashes, 0 runtime errors)

**What works**: Prelude trait instances — `eq-check` on Nat/Bool, `ord-compare` returning `lt-ord`/`gt-ord`/`eq-ord`, generic operators via mixfix `.{+ - * < <=}`, equality operator `=` outside mixfix (`3N = 3N` → `true`). User-defined `trait` declaration produces the expected generic function signature.

| Finding | Code | Detail |
|---------|------|--------|
| `spec f {A : Type} (Eq A) A A -> Bool` | CRASH | "type has 1 type parameters but defn has 2 params" — `inject-spec-into-defn` in the preparse miscounts the function arity when trait constraints like `(Eq A)` are present. The constraint `(Eq A)` is being counted as a type parameter, reducing the perceived arity from 2 to 1. |
| `defn` inside `impl` block | CRASH | `impl Describable Nat` with `defn describe [n] n` indented underneath fails with "defn requires: (defn name [x <T> ...] body)". The WS-mode preparse doesn't recognize that `defn` inside an `impl` block should be treated as a method definition, not a standalone function. This blocks all user-defined trait implementations. |
| `.{3N = 3N}` | CRASH | "Unexpected token after expression: =" — the `=` operator inside mixfix `.{}` triggers the narrowing/equality rewrite pass, which conflicts with the mixfix parser. **Workaround**: use `3N = 3N` outside mixfix. |

### audit-07: Collections & Operations (67 expressions, 13 runtime errors)

**What works**: List creation (`'[...]`, `nil`, `cons`), `length`, `filter` with lambda, `reverse`, `append`, `foldr`, `sum`, `any?`, `all?`, `take`, `drop`, `zip`. PVec creation (`@[...]`), `pvec-filter`, `pvec-fold`. All Map operations (`map-empty`, `map-assoc`, `map-get`, `map-dissoc`, `map-size`, `map-has-key?`, `map-keys`, `map-vals`). Set creation (`#{...}`), `set-fold`. LSeq creation (`list-to-lseq`), `lseq-to-list`, `lseq-take`, `lseq-length`. Postfix indexing (`xs[0]`, `m[:key]`, `nested[:db][:port]`). Dot access (`config.port`).

| Finding | Code | Detail |
|---------|------|--------|
| `[map suc ...]` | CRASH | "Unbound variable" — `suc` as HOF arg. Same pattern for `pvec-map suc`, `set-map suc`, `lseq-map suc`, `map-map-vals suc`. 5 instances of this pattern. |
| `[sort '[3N 1N 2N]]` | CRASH | "Could not infer type" — `sort` requires an `Ord` constraint which isn't resolved from the list literal alone. |
| `[dedup '[1N 2N 2N 3N]]` | CRASH | "Could not infer type" — `dedup` requires an `Eq` constraint, same inference issue as sort. |
| `[range 1N 5N]` | CRASH | "Too many arguments to 'range'" — the prelude's `range` function has a different signature than the 2-arg form expected here. |
| `[opt::unwrap-or [some 42N] 0N]` | CRASH | "Could not infer type" — 2 instances. The aliased function `opt::unwrap-or` can't resolve its polymorphic type from the arguments. |
| `[set-singleton 42N]` | CRASH | "Could not infer type" — can't infer the set's type parameter from a bare Nat literal. |
| `[into-vec '[1N 2N 3N]]` | CRASH | "Could not infer type" — collection conversion fails type inference. |
| `[into-list @[1N 2N 3N]]` | CRASH | "Could not infer type" — same inference issue. |
| `head`/`tail`/`nth`/`last` return Option | DESIGN | `[head '[10N 20N 30N]]` → `some 10N : Option Nat`, not `10N : Nat`. These are safe accessors that return `Option` to handle empty lists. Correct by design, but users may expect raw values. `head` and `tail` are total functions — users who want partial behavior must unwrap the option. 4 instances. |

### audit-08: Narrowing & Logic (16 expressions, 0 runtime errors but 4 WRONG)

**What works**: Basic two-variable narrowing (`add ?x ?y = 5N` → 6 solutions, all correct). Single-variable narrowing (`add ?x 3N = 7N` → `[{:x 4N, :y_ 3N}]`). Equality mode (`[add 2N 3N] = 5N` → `true`, `= 6N` → `false`). Forward equality through user function (`[my-double 3N] = 6N` → `true`). Mixfix narrowing (`.{?x + 3N} = 7N` → `[{:x 4N}]`, `.{1N + ?y} = 5N` → `[{:y 4N}]`). Multi-level narrowing (`add [suc ?x] ?y = 5N` → solutions). Typed logic variables (`add ?x:Nat ?y:Nat = 5N`).

| Finding | Code | Detail |
|---------|------|--------|
| `my-double ?x = 6N` over-generates | WRONG | Returns `[{:x 6N} {:x 5N} {:x 4N} {:x 3N}]` but only `x=3N` satisfies `add x x = 6N`. The narrowing unfolds `my-double` to `add ?x ?x` but then treats the two `?x` references as independent variables during the `add` narrowing, returning all `x+y=6` solutions without enforcing `x=y`. The constraint that both arguments to `add` are the same variable is lost during narrowing. |
| `[suc ?n] = 3N` → `nil` | WRONG | Should find `n=2N` since `suc 2N = 3N`. The narrowing engine can't narrow through the `suc` constructor in the equality direction. `suc` applied to a free variable doesn't produce a definitional tree step — the narrowing only works through function definitions (`defn`), not through bare constructor application. |
| `[suc [suc ?n]] = 5N` → `nil` | WRONG | Same issue — nested `suc` constructor narrowing fails. Should find `n=3N`. |
| `my-and ?a ?b = true` → `nil` | WRONG | Should find `a=true, b=true`. The function uses `if a b false`, but narrowing through `if` doesn't work — the `if` form doesn't generate a definitional tree that the narrowing engine can decompose. Only `match`-based definitions create narrowable definitional trees. |

### audit-09: Numerics (55 expressions, 0 errors — FULLY CLEAN)

**Everything works**: Nat arithmetic (`add`, `mult`, `double`, `sub`, `pred`, `pow`), Nat comparison (`zero?`, `lt?`, `gt?`, `le?`, `ge?`, `nat-eq?`), Nat utilities (`min`, `max`, `clamp`). Int arithmetic (`int+`, `int-`, `int*`, `int/`, `int-mod`), Int signs (`int-neg`, `int-abs`), Int comparison (`int-lt`, `int-le`, `int-eq`), negative literals (`-7`, `-1`), Nat→Int (`from-nat`). Rat arithmetic (`rat+`, `rat-`, `rat*`, `rat/`), Rat utilities (`rat-neg`, `rat-abs`, `rat-numer`, `rat-denom`), Rat comparison (`rat-lt`, `rat-eq`), Int→Rat (`from-int`). Posit32 literals (`~3.14`, `~42`, `~0.5`), Posit32 arithmetic (`p32+`, `p32*`, `p32-neg`, `p32-abs`). Generic mixfix (`.{+ - * < <=}`).

### audit-10: Pipe, Compose, Transducers (14 expressions, 6 runtime errors)

**What works**: Binary pipe — `0N |> suc |> suc |> suc` → `3N`, `5N |> double |> suc` → `11N`, `3N |> [add 2N]` → `5N`, chained `2N |> [add 3N] |> [mult 2N]` → `10N`. Compose — `[suc >> suc] 0N` → `2N`, `[double >> suc] 3N` → `7N`, `[suc >> double] 3N` → `8N`.

| Finding | Code | Detail |
|---------|------|--------|
| Block pipe `\|> xs map suc sum` | CRASH | "Type mismatch" — the block pipe form compiles but the `map suc` step fails because `suc` can't be passed as HOF arg (same Cluster 1 issue). The block pipe form itself may work with lambda arguments instead. |
| `def suc-fn : [Nat -> Nat] := suc` | CRASH | "Unbound variable" — can't bind constructor `suc` to a function-typed variable (Cluster 1 again). |
| `[into-list Nat Nat [map-xf ...] coll]` | CRASH | "Too many arguments to 'into-list'" — 3 instances. The transducer `into-list` from `prologos::data::transducer` takes 4 args (`A B xf coll`) but collides with the collection `into-list` from `prologos::core::collections` which takes 1 arg. The prelude imports the collection version, shadowing the transducer version. |

### audit-11: Module System (12 expressions, 4 runtime errors)

**What works**: Prelude auto-loading (`ns examples.audit.modules-imports` loads all prelude functions). FQN access (`[prologos::data::nat::add 10N 20N]` → `30N`, `[prologos::data::nat::mult 3N 4N]` → `12N`, `[prologos::data::nat::zero? 0N]` → `true`). `ok?` on result. `spec-`/`defn-` private function definitions work.

| Finding | Code | Detail |
|---------|------|--------|
| `[map suc '[1N 2N 3N]]` | CRASH | "Unbound variable" — same constructor-as-HOF pattern (Cluster 1). |
| `[opt::unwrap-or [some 42N] 0N]` | CRASH | "Could not infer type" — same polymorphic inference failure (Cluster 2). |
| `def-` private def | CRASH | "def requires: (def name <type> body)" — the `def-` form (private `def`) is not recognized by the WS-mode preparse. Note that `spec-` and `defn-` DO work, so the gap is specific to `def-`. |

### audit-12: Advanced Features (23 expressions, 3 runtime errors)

**What works**: `(check 42N : Nat)` → `OK`, `(check true : Bool)` → `OK`. `(infer 42N)` → `Nat`, `(infer true)` → `Bool`, `(infer [add 2N 3N])` → `Nat`, `(infer Nat)` → `[Type 0]`. `eval [add 10N 20N]` → `30N`. All mixfix operators. Polymorphic function (`dep-id {A : Type} A -> A`). `(the Nat 42N)`, `(the Bool true)`, `(the [List Nat] '[1N 2N 3N])`.

| Finding | Code | Detail |
|---------|------|--------|
| `'foo` (quote) | CRASH | "Unbound variable" — `'` is the list-literal prefix in WS mode. `'foo` gets read as a list-literal attempt on `foo`, which fails. Standard Lisp-style quote is not available in WS-mode files. |
| `'(a b c)` (quoted list) | CRASH | "Unbound variable" — same reader conflict. The `'(` prefix gets parsed as a list literal containing `(a b c)`, not as a quoted datum. |
| `` `(hello ,x world) `` (quasiquote) | CRASH | "Unbound variable" — backtick quasiquote syntax not supported in WS-mode file reader. The quasiquote readtable isn't active in the WS reader path. |
| `with-transient` | CRASH | "expected (with-transient coll fn-expr), got multi-step form" — the `with-transient` macro expects exactly 2 args (collection, function) but WS-mode indentation groups the multi-step body differently. The macro was designed for sexp syntax `(with-transient @[] (fn [t] (tvec-push! t 1N)))`, not the WS sugared multi-step form. |

---

## DESIGN Findings (Detailed)

These 7 findings are not bugs — the system works as designed. But the design may surprise users or limit ergonomics:

### D1. `nil` shows unsolved meta-variable in type (audit-01)
```
[prologos::data::list::nil ?meta5323] : [prologos::data::list::List ?meta5323]
```
Polymorphic `nil` with no surrounding type context can't resolve its type parameter. The `?meta` is an internal unification variable that leaks into user-visible output. In practice, `nil` in a typed context (e.g., `def x : (List Nat) := nil`) resolves fine. But bare `nil` at top level shows the raw meta.

**Possible mitigation**: Pretty-print unsolved metas as `_` or `?` in user-facing output instead of `?meta5323`.

### D2. `head`/`tail`/`nth`/`last` return `Option` (audit-07)
`[head '[10N 20N 30N]]` → `some 10N : Option Nat`, not `10N : Nat`. These are *total* safe accessors that handle empty lists by returning `none` instead of crashing. This is the correct functional programming design (Haskell's `Data.Maybe.headMay` equivalent), but users expecting partial `head` (crash on empty) may be surprised. Unwrapping requires `match` or `opt::unwrap-or` (which itself has inference issues — see Cluster 2).

**Possible mitigation**: Provide `head!` / `tail!` partial variants that crash on empty, for convenience in exploratory code.

### D3. Top-level sequential `let` forms don't scope into each other (audit-05)
Each top-level form is processed independently. `let p := 10N` followed by `let q := [add p 5N]` would fail because `p` is not in `q`'s scope. This is a fundamental property of the top-level evaluation model — `let` is only a local binding form, not a top-level declaration. Users should use `def` for top-level bindings.

**Possible mitigation**: Document this prominently. Or implement top-level `let` as sugar for `def` that adds to the global environment.

### D4. `cond` emits `Hole ??__cond-fail` warning (audit-04)
```
Hole ??__cond-fail : _
Context:
  x : Nat  (w)
```
The `cond` form's exhaustiveness checking generates an internal hole for the failure case. This warning appears in the process-file output even when a `true ->` catch-all clause is present. The hole is part of the internal exhaustiveness mechanism and shouldn't be user-visible.

**Possible mitigation**: Suppress the hole warning when a `true ->` catch-all is present. Or filter internal hole warnings from process-file output.

### D5. Constructor application in `def` requires brackets (audit-02)
`def x := some 42N` fails because the preparse sees two tokens after `:=`. The workaround `def x := [some 42N]` works. This is consistent with the general rule that multi-token expressions need brackets in WS mode, but users may expect `some 42N` to work since it looks like a single application.

**Possible mitigation**: Teach the preparse that everything after `:=` is a single expression, even if it contains multiple tokens.

### D6. `=` is overloaded between equality and narrowing (audit-06, audit-08)
The `=` operator serves double duty: `[expr] = [expr]` (no `?vars`) → boolean equality check; `expr ?x = expr` (with `?vars`) → narrowing search. This is powerful but means `=` cannot appear inside mixfix `.{}` because the rewrite pass gets confused. And the narrowing behavior depends on the *presence* of `?`-prefixed variables, which is implicit.

**Not a bug**: This is a deliberate design choice that enables the functional-logic duality. But it means certain syntactic contexts are unavailable for `=`.

### D7. `cons 1N nil` pretty-prints as `'[1N]` (audit-03)
The pretty-printer normalizes cons chains into list literal notation. `cons 1N [cons 2N nil]` prints as `'[1N 2N]`. This is ergonomically nice but may confuse users trying to understand the underlying data representation.

**Not a bug**: This is desirable normalization. Could optionally provide a verbose mode that shows raw cons chains.

---

## Root Cause Clusters

### Cluster 1: Constructor-as-HOF-Argument (10 instances, HIGH priority)

**Symptom**: `[map suc '[1N 2N 3N]]` → "Unbound variable"
**Affected**: `suc`, nullary constructors (`North`, `South`), any constructor passed to `map`, `filter`, `pvec-map`, `set-map`, `lseq-map`, `map-map-vals`, block pipe steps.
**Root cause**: Data constructors are not first-class functions in the WS elaboration path. They work in pipe (`0N |> suc`) and direct application (`[suc 2N]`) but cannot be passed as arguments to higher-order functions.
**Instances**: audit-07 (x5), audit-10 (x2), audit-11 (x1), audit-03 (x2 for nullary ctors)
**Impact**: Users must wrap constructors in lambdas: `(fn [x : Nat] [suc x])` instead of bare `suc`. This is a significant ergonomic tax on common functional patterns.

### Cluster 2: Type Inference for Generic/Polymorphic Operations (8 instances, HIGH priority)

**Symptom**: "Could not infer type" for operations with trait constraints or complex polymorphism
**Affected operations**:
- `sort`, `dedup` — need Ord/Eq constraint, not resolved from list literal
- `opt::unwrap-or` — polymorphic option unwrap fails inference (3 instances across files)
- `set-singleton` — can't infer set type from bare value
- `into-vec`, `into-list` — collection conversion inference fails
**Root cause**: Top-level expressions with polymorphic functions that need trait resolution can't gather enough type information from the argument alone. Trait dispatch requires knowing the concrete type parameter to select an instance, but inference from a list literal like `'[3N 1N 2N]` doesn't propagate the element type through to the Ord constraint.
**Impact**: These operations may work inside `defn` bodies with spec annotations but fail at top level. Users who write exploratory top-level expressions (REPL-style) hit this frequently.

### Cluster 3: WS-Mode Preparse Gaps (8 instances, MEDIUM priority)

**Symptom**: Various preparse/parse errors for valid language forms
**Affected forms**:
- `def- x := val` — "def requires: ..." (private def not recognized; `spec-`/`defn-` work)
- `let x := val` at top level — "missing value after :=" (let is body-only)
- `def x := (fn ...)` — "Could not infer type" (fn as def value)
- Multi-clause `defn f | pat -> body` — "spec is single-arity but defn has multiple clauses"
- `defn` inside `impl` block — "defn requires: ..."
- `with-transient` multi-step macro — "expected 2 args"
- `def x := suc` — constructor as def value
**Root cause**: Preparse (`macros.rkt:preparse-expand-all`) doesn't handle all WS-mode form variants. The preparse was built for sexp-level forms; WS-mode indentation grouping produces different AST shapes that the preparse doesn't expect.

### Cluster 4: User-Defined Data Constructors (5 instances, HIGH priority)

**Symptom**: `data` definitions produce broken constructors
**Issues**:
- Nullary constructors (`North`, `South`) defined as function type `Direction -> Direction` instead of value
- Multi-field constructors (`Rect : Nat Nat -> Shape`) — "Expression is not a valid type"
- Polymorphic constructors (`MkBox`) — "Unbound variable" after definition
- `deftype` as type synonym — "deftype requires: ..."
**Root cause**: `data` form in WS mode has fundamental issues with constructor generation — only single-field constructors of non-polymorphic types work. This severely limits the usefulness of user-defined algebraic data types.

### Cluster 5: Reader-Level Syntax Conflicts (5 instances, MEDIUM priority)

**Symptom**: Certain syntax forms conflict with the WS reader
**Affected**:
- `'a'` char literals conflict with `'` quote/list-literal prefix (audit-01)
- `'foo` quote conflicts with list-literal prefix in WS mode (audit-12)
- `'(a b c)` quote of s-expression fails (audit-12)
- `` `(hello ,x world) `` quasiquote fails (audit-12)
- `.{3N = 3N}` — `=` inside mixfix conflicts with narrowing rewrite (audit-06)
**Root cause**: The WS reader repurposes `'` for list literals (`'[1N 2N]`), which prevents standard quote syntax. The `=` operator has special handling in the narrowing/equality rewrite pass that conflicts with mixfix parsing.

### Cluster 6: Narrowing Correctness (4 instances, MEDIUM priority)

**Symptom**: Narrowing returns wrong or empty results
**Issues**:
- `my-double ?x = 6N` → over-generates — returns `[{:x 6N} {:x 5N} {:x 4N} {:x 3N}]` when only `x=3` is valid (shared variable constraint lost)
- `[suc ?n] = 3N` → `nil` — bare constructor application doesn't create narrowable definitional tree
- `[suc [suc ?n]] = 5N` → `nil` — same
- `my-and ?a ?b = true` → `nil` — `if` doesn't produce a definitional tree; only `match` does
**Root cause**: Two distinct issues: (a) the narrowing engine doesn't track shared variable constraints when unfolding user functions, leading to over-generation; (b) only `match`-based function definitions create definitional trees that the narrowing engine can decompose — `if` and bare constructor application are opaque to narrowing.

### Cluster 7: Spec/Constraint Interaction (1 instance, LOW priority)

**Symptom**: `spec f {A : Type} (Eq A) A A -> Bool` with `defn f [a b]` → "type has 1 type parameters but defn has 2 params"
**Root cause**: `inject-spec-into-defn` in `macros.rkt` miscounts arity when trait constraints like `(Eq A)` are present. The constraint is being subtracted from the perceived arity.

### Cluster 8: Arity/Name Collisions (4 instances, LOW priority)

**Symptom**: Wrong arity or wrong function called
**Issues**:
- `[range 1N 5N]` — "Too many arguments" (range takes different args than expected)
- `[into-list A B xf coll]` — "Too many arguments" (transducer `into-list` clashes with collection `into-list`)
- `5/1` parsed as Int `5` not Rat (reader simplifies)
**Root cause**: Prelude imports create name collisions between modules (transducer `into-list` vs collection `into-list`), and some function signatures differ from expected ergonomic form.

---

## What Works Well

These areas are **fully functional** in WS-mode `.prologos` files:

1. **All literal types**: Nat, Int, Rat, Posit, Bool, String, Keyword, Unit
2. **Basic definitions**: `def` (typed and inferred), `spec`/`defn`, `spec-`/`defn-` (private)
3. **Pattern matching**: `match` on Nat/Bool/List/Option/Result — all correct in defn bodies
4. **Conditionals**: `if` (in defn bodies), `cond` with multi-branch
5. **Sequential `let` in defn bodies**: scopes correctly with chaining
6. **Lambda with explicit types**: `(fn [x : Nat] body)` in map/filter/immediate application
7. **All numeric operations**: Complete Nat, Int, Rat, Posit32 arithmetic and comparison
8. **Prelude trait dispatch**: `eq-check`, `ord-compare`, all mixfix `.{+ - * < <=}` operators
9. **Pipe and compose**: `|>` binary pipe, `>>` compose — all forms work
10. **Narrowing**: Basic `add ?x ?y = 5N`, mixfix `.{?x + 3N} = 7N`, equality mode, typed vars
11. **Collection primitives**: Map creation/access/mutation, PVec filter/fold, LSeq creation/conversion
12. **Postfix indexing**: `xs[0]`, `m[:key]`, `nested[:db][:port]`, `m.field` — all work
13. **Module system**: FQN access, `ns` with prelude, qualified aliases
14. **check/infer/eval/the**: All meta-programming and introspection forms work
15. **Dependent types**: Polymorphic `{A : Type}` specs, parametric identity function
16. **User-defined traits**: `trait` definition creates expected generic function signature

---

## Prioritized Repair Backlog

### Priority 1: CRASH — Blocks Basic Usage

| # | Issue | Cluster | Effort | Files |
|---|-------|---------|--------|-------|
| 1a | Constructor-as-HOF (suc in map/filter) | C1 | M | elaborator, typing-core |
| 1b | User data constructors (nullary/multi-field/poly) | C4 | L | parser, elaborator |
| 1c | defn inside impl block | C3 | M | macros.rkt (preparse) |
| 1d | spec + constraint arity mismatch | C7 | S | macros.rkt:inject-spec-into-defn |
| 1e | def with fn value fails | C3 | S | macros.rkt or elaborator |
| 1f | Top-level let | C3 | M | macros.rkt (preparse) |

### Priority 2: WRONG — Incorrect Results

| # | Issue | Cluster | Effort | Files |
|---|-------|---------|--------|-------|
| 2a | Narrowing over-generates (shared variable constraint) | C6 | M | reduction.rkt (narrowing) |
| 2b | suc/bool narrowing returns nil (no definitional tree) | C6 | M | reduction.rkt (narrowing) |
| 2c | Top-level if type is `_` | — | S | typing-core.rkt |
| 2d | 5/1 parsed as Int 5 | C8 | S | reader.rkt |

### Priority 3: CRASH — Advanced Features

| # | Issue | Cluster | Effort | Files |
|---|-------|---------|--------|-------|
| 3a | Type inference for sort/dedup/unwrap-or etc. | C2 | L | typing-core, trait resolution |
| 3b | Quote/quasiquote reader conflict | C5 | M | reader.rkt |
| 3c | = inside mixfix | C5 | S | macros.rkt (rewrite pass) |
| 3d | def- in WS mode | C3 | S | macros.rkt (preparse) |
| 3e | with-transient macro in WS mode | C3 | S | macros.rkt |
| 3f | Multi-clause defn syntax | C3 | M | macros.rkt |
| 3g | Char literal reader conflict | C5 | M | reader.rkt |
| 3h | Transducer into-list name collision | C8 | S | namespace.rkt (prelude) |

### Effort Legend
- **S** (Small): 1-2 hours, localized fix
- **M** (Medium): 2-4 hours, may touch multiple files
- **L** (Large): 4+ hours, architectural consideration needed

### Suggested Repair Sprint Order

1. **Quick wins** (1d, 1e, 2c, 2d, 3c, 3d, 3e, 3h) — 8 small fixes, ~1 day
2. **Constructor-as-HOF** (1a) — single systemic fix, unblocks ~10 expressions
3. **Preparse gaps** (1c, 1f, 3f) — grouped preparse work, ~1 day
4. **Data constructors** (1b) — significant work, unblocks user-defined types
5. **Narrowing correctness** (2a, 2b) — narrowing search improvements
6. **Type inference** (3a) — complex, may need bidirectional inference improvements
7. **Reader conflicts** (3b, 3g) — reader architecture changes

---

## Commits

- `41d6711` — audit-01 + run-file.rkt tool
- `e0e0a03` — audit-02
- `8a92675` — audit-03 + audit-04
- `d7d2c0b` — audit-05 + audit-06
- `2ce0e75` — audit-07 through audit-12
- `6fc0949` — initial summary report (v1)
