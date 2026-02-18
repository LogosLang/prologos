# Higher-Rank Pi Types in Prologos: Design Proposal

## 1. Introduction

Prologos unifies dependent types, session types, and linear types (QTT) in a single
language. Its surface syntax distinguishes two forms for defining typed functions:

- **`spec`/`defn`** — the idiomatic whitespace-mode form, with uncurried parameters and
  a flat arrow signature: `spec foo A B -> C` / `defn foo [x y] body`
- **`(def name : [type] body)`** — the sexp fallback, used when the type is too complex
  for `spec` to express.

Today, any function whose *parameter* type is itself a Pi type (a polymorphic or
dependent function) must use the sexp fallback. This limitation shows up concretely in
the transducer stdlib, where every function takes an argument of type
`Pi [R :0 <Type>] [-> [-> R [-> B R]] [-> R [-> A R]]]` — a transducer polymorphic in
the result type R. Because `spec` cannot express "this parameter is a Pi", all seven
transducer functions are written in `(def ...)` form, defeating the goal of writing
Prologos in its own surface syntax.

This document surveys the theory behind higher-rank polymorphism, analyses the precise
parsing limitation in Prologos's `spec` decomposition, and proposes a surface syntax
extension that resolves it using the existing angle-bracket dependent type notation.


## 2. Theoretical Background

### 2.1 Ranks of Polymorphism

The *rank* of a type measures how deeply universal quantifiers nest to the left of
function arrows:

| Rank | Definition | Example |
|------|-----------|---------|
| 0 | No quantifiers | `Nat -> Bool` |
| 1 | Quantifiers at outermost (prenex) position only | `forall A. A -> A` |
| 2 | Rank-1 types may appear in argument position | `(forall A. A -> A) -> Nat` |
| *n* | Rank-(*n*-1) types in argument position | Arbitrarily nested |

Rank-1 is the Hindley-Milner fragment: every polymorphic binding can be prenex-
quantified, and principal types exist. The key theoretical results are:

- **Rank-1 inference is decidable** with principal types (Damas & Milner 1982).
- **Rank-2 inference is decidable** via acyclic semi-unification (Kfoury & Wells 1994).
- **Rank-3+ inference is undecidable** (Wells 1999), as is full System F type-checking.

The sharp boundary at rank-3 means that practical languages supporting arbitrary-rank
types must require programmer annotations at higher-rank boundaries. This is not a
deficiency but a design constraint: the programmer states where quantifiers scope, and
the checker verifies.

### 2.2 Dependent Types Subsume Quantification

In a dependently-typed language, there is no separate `forall` distinct from the function
type. The Pi type `Pi (A : Type) -> A -> A` *is* the universal quantification
`forall A. A -> A`. Higher-rank polymorphism is therefore not a special feature — it
falls out naturally from the ability to write Pi types in any position.

Concretely, a rank-2 type like Haskell's `(forall a. a -> a) -> Int -> Int` is, in
dependent type theory, simply a function whose first parameter has type
`Pi (A : Type) -> A -> A`:

```
Pi (f : Pi (A : Type) -> A -> A) -> Nat -> Nat
```

No extension is needed. The only question is *surface syntax*: how does the programmer
delimit "this parameter is a Pi" versus "this Pi quantifies the whole function"?

### 2.3 QTT and Erased Type Parameters

Prologos uses Quantitative Type Theory, where every binding carries a multiplicity:

- `:0` (erased) — available for type-level reasoning, erased at runtime.
- `:1` (linear) — used exactly once.
- `:w` (unrestricted) — used any number of times.

Parametric polymorphism requires erased type parameters. A function
`Pi [A :0 <Type>] [-> A A]` cannot inspect `A` at runtime, preserving parametricity.
When this appears as an argument type (higher-rank), the `:0` on `A` is part of the
argument's type signature and must be preserved through the nesting:

```
-- Rank-2 with QTT:
spec apply-poly <(f : <(A :0 Type) -> A -> A>) -> Nat -> Nat>
```

The inner `:0` on `A` is the argument function's erasure annotation, distinct from any
multiplicities on the outer function's parameters.

### 2.4 Bidirectional Type Checking

The algorithmic engine that makes higher-rank types practical is *bidirectional type
checking* (Dunfield & Krishnaswami 2013; Peyton Jones et al. 2007). The key insight:

- **Synthesis mode** (`e => A`): infer the type of an expression. Works for variables,
  applications, and annotated terms.
- **Checking mode** (`e <= A`): check an expression against a known type. Works for
  lambdas, where the annotation provides the parameter type.

When a lambda is checked against a higher-rank type:

```
(fn [f] ...) <= <(f : <(A :0 Type) -> A -> A>) -> Nat>
```

the checker decomposes: bind `f : <(A :0 Type) -> A -> A>` and check the body against
`Nat`. Without the annotation, the checker cannot know `f` should be polymorphic. This
is why `spec` annotations are exactly the right place to express higher-rank — the
programmer provides the type, and `defn` checks against it.

Prologos already performs this: `spec` registers a type, `defn` injects it via
`maybe-inject-spec`, and the elaborator checks the body. The missing piece is that the
spec *parser* cannot currently represent Pi-typed parameters.

### 2.5 How Other Languages Delimit Higher-Rank

Every language that supports higher-rank types uses some form of grouping delimiter:

| Language | Higher-rank parameter | Quantifier | Notes |
|----------|----------------------|------------|-------|
| Haskell | `(forall a. a -> a)` | `forall ... .` | Parens required |
| Agda | `({A : Set} -> A -> A)` | Pi / `forall` | Parens group the Pi |
| Idris 2 | `({0 a : Type} -> a -> a)` | Pi / `forall` | `0` = erased (QTT) |
| Lean 4 | `((a : Type) -> a -> a)` | Pi / `forall` | Parens or binder syntax |
| Coq | `(forall A : Type, A -> A)` | `forall` | Comma separator |
| Scala 3 | `[A] => A => A` | `[A] =>` | Brackets + double arrow |

The universal principle: **grouping is necessary** to prevent the quantifier from floating
to the outermost scope. Without a delimiter, `Pi [A : Type] -> A -> A -> Nat` is
ambiguous between "A is a type param of the whole function" and "the first parameter is
polymorphic."


## 3. The Current Limitation

### 3.1 How `spec` Decomposes Types

The function `decompose-spec-type` in `macros.rkt` (line 1107) processes a `spec`
signature by:

1. **Splitting on `->` arrows** into segments.
2. **Flattening non-last segments**: each element becomes a separate parameter type.
3. **The last segment** is the return type.

For example:

```
spec foo Nat Bool -> Nat
```

Segments: `[Nat, Bool]` and `[Nat]`. Flat params: `[Nat, Bool]`. Return: `[Nat]`.
This produces two parameters typed `Nat` and `Bool`, returning `Nat`.

Grouped types (in `[...]` brackets) survive as single elements:

```
spec foo [Nat -> Bool] Nat -> Nat
```

Segments: `[[Nat -> Bool], Nat]` and `[Nat]`. Flat params: `[[Nat -> Bool], Nat]`.
The first parameter has type `Nat -> Bool` because the brackets prevent splitting.

### 3.2 Where It Breaks

Consider a function taking a polymorphic argument:

```
spec transduce [Pi [R :0 <Type>] [-> [-> R [-> B R]] [-> R [-> A R]]]] [-> R [-> B R]] R [List A] -> R
```

The `decompose-spec-type` algorithm splits on `->`:

- It finds `->` inside `[Pi [R :0 <Type>] [-> [-> R [-> B R]] [-> R [-> A R]]]]` — but
  wait, that's inside `[...]` brackets, so it's protected... unless the spec syntax
  doesn't use brackets around the whole parameter.

Actually, the deeper issue is that **`decompose-spec-type` flattens each non-last segment
into individual atoms**. Even with bracket grouping:

```
spec transduce [Pi [R :0 <Type>] [-> [-> R [-> B R]] [-> R [-> A R]]]] [-> R [-> B R]] R [List A] -> R
```

The `[Pi ...]` bracket is one element, `[-> R [-> B R]]` is another, `R` is another,
`[List A]` is another. The algorithm sees 4 parameter types before the final `-> R`.
But the intent is that the *entire* `[Pi [R :0 <Type>] ...]` is just *one* parameter.

The core problem: **there is no syntactic way in `spec` to say "this entire
higher-kinded thing, including its own internal arrows, is a single parameter."** Bracket
grouping `[...]` prevents arrow-splitting *within* the group, but the *spec decomposer*
then treats `[Pi ...]` as an opaque blob. When it reaches `param-type->angle-type`,
it encounters the `Pi` datum and doesn't know how to inject it as a parameter type into
`defn`.

### 3.3 The Injection Failure

Even if decomposition works, `param-type->angle-type` (line 1140) converts each
parameter type into an `($angle-type ...)` wrapper for the parser. It handles three
cases:

1. Plain atom: `Nat` -> `($angle-type Nat)`
2. Grouped list: `[List A]` -> `($angle-type List A)`
3. Dependent binder: `(n : Nat)` -> `($angle-type Nat)` (extracts the type)

A Pi-typed parameter like `[Pi [R :0 <Type>] ...]` doesn't match any of these patterns.
It is a grouped list, so it becomes `($angle-type Pi [R :0 <Type>] ...)`, which the
parser then fails to parse as a valid type annotation.

### 3.4 The `defn` Body Problem

Even if spec injection worked, the `defn` body faces a second issue. Given:

```
defn transduce [xf rf init xs] ...
```

The parameter `xf` receives the Pi-typed annotation. But inside the body, calling
`xf R rf` requires passing the type argument `R` explicitly (since Prologos does not
perform implicit argument insertion). In a `defn` with bare parameters, the erased
type variables `A`, `B`, `R` from the `spec` are not in scope — they were never bound
as `defn` parameters.

This means higher-rank `spec`/`defn` requires that the outer function's own erased type
parameters (like `A`, `B`, `R`) appear as explicit `defn` parameters that can be used
in the body.


## 4. Design Proposal

### 4.1 Design Principles

The extension should:

1. **Use angle-bracket notation** — Prologos's existing `<...>` syntax for dependent
   types is the natural vehicle.
2. **Be unambiguous** — a Pi in parameter position must be syntactically distinguished
   from a Pi quantifying the whole function.
3. **Support QTT multiplicities** — erased `:0`, linear `:1`, and unrestricted `:w`
   annotations must work inside higher-rank parameters.
4. **Compose with `where`** — higher-rank parameters should coexist with trait constraints.
5. **Preserve backward compatibility** — all existing `spec`/`defn` code continues to work.
6. **Require minimal new syntax** — reuse existing constructs rather than inventing new
   keywords.

### 4.2 The Proposed Syntax

**Angle-bracket Pi in parameter position:**

A parameter whose type is itself a Pi is written as a single angle-bracketed
dependent type `<...>` within the `spec` signature:

```
spec transduce <(A :0 Type, B :0 Type, R :0 Type)
               -> <(S :0 Type) -> [-> S [-> B S]] -> S -> A -> S>
               -> [-> R [-> B R]]
               -> R
               -> [List A]
               -> R>
```

Breaking this down:

- `<(A :0 Type, B :0 Type, R :0 Type) -> ... >` — the whole function type, wrapped in
  angle brackets, with the outer erased binders.
- `<(S :0 Type) -> [-> S [-> B S]] -> S -> A -> S>` — the **higher-rank parameter**:
  a Pi type inside angle brackets, appearing in parameter position. The angle brackets
  delimit it as a single parameter type.
- `[-> R [-> B R]]`, `R`, `[List A]`, `R` — the remaining parameters and return type.

However, this wraps the *entire* function type in `<...>`, which is verbose. A cleaner
approach preserves `spec`'s flat arrow convention for the outer function while using
`<...>` only for the higher-rank parameter:

```
spec transduce {A :0 Type} {B :0 Type} {R :0 Type}
               <(S :0 Type) -> [S -> B -> S] -> S -> A -> S>
               [R -> B -> R]
               R
               [List A]
               -> R
```

Here:
- **`{A :0 Type}`** — erased implicit binder (new syntax, borrowing from Agda/Lean).
- **`<(S :0 Type) -> [S -> B -> S] -> S -> A -> S>`** — a Pi-typed parameter, delimited
  by angle brackets. The parser sees a complete `<...>` group containing a dependent
  Pi and treats it as a single parameter type.
- The remaining parameters use existing syntax: `[R -> B -> R]` (bracket-grouped arrow),
  `R` (bare type), `[List A]` (type application).
- `-> R` — return type after the final arrow.

### 4.3 Implicit Binders: the `{...}` Extension

To fully support higher-rank in `spec`, we need a way to declare the outer function's
erased type parameters. Currently these are written as `Pi [A :0 <Type>]` in sexp form,
but `spec` has no equivalent.

**Proposal: curly-brace implicit binders.**

```
spec id {A : Type} A -> A
defn id [x] x
```

Meaning: `id` has one erased (`:0`) type parameter `A`, one value parameter of type `A`,
and returns `A`. The curly braces signal "this is an implicit/erased binder, not a value
parameter." The `defn` does NOT list `A` in its parameter list — `A` is inferred and
erased.

With multiplicity annotations:

```
spec id {A :0 Type} A -> A       ;; explicit :0 (erased)
spec use {A :1 Type} A -> A      ;; explicit :1 (linear type usage)
spec id {A : Type} A -> A        ;; default multiplicity (inferred, typically :0)
```

The default multiplicity for `{...}` binders can be `:0` (erased), matching the
convention that type parameters are parametric. This aligns with Idris 2, where implicit
arguments default to multiplicity 0.

#### Multiple implicit binders

```
spec map-xf {A : Type} {B : Type} [A -> B] -> <(R :0 Type) -> [R -> B -> R] -> R -> A -> R>
```

Or grouped:

```
spec map-xf {A B : Type} [A -> B] -> <(R :0 Type) -> [R -> B -> R] -> R -> A -> R>
```

The grouped form `{A B : Type}` binds multiple names to the same type, analogous to
Lean's `{α β : Type}`.

### 4.4 Higher-Rank Parameters via `<...>`

The key rule:

> **An `<...>` group containing a dependent Pi binder in parameter position of a `spec`
> is treated as a single higher-rank parameter type.**

This means:

```
spec foo {A : Type} <(B :0 Type) -> B -> A -> B> -> Nat -> A
```

decomposes as:
1. Implicit binder: `A : Type` (erased)
2. Parameter 1: `<(B :0 Type) -> B -> A -> B>` — a Pi-typed parameter (higher-rank)
3. Parameter 2: `Nat`
4. Return type: `A`

The `<...>` brackets serve double duty: they are already the Prologos notation for
dependent types, and they provide the *grouping delimiter* that prevents the inner `->` from
being confused with the outer function's arrow.

For `defn`:

```
defn foo [f n]
  f Nat n zero
```

The `spec` injection binds `f : <(B :0 Type) -> B -> A -> B>` and `n : Nat`. In the
body, `f Nat n zero` explicitly applies `f` at type `Nat`, then passes `n` and `zero`.

### 4.5 The `defn` Body and Type Variable Scope

A critical design question: are the implicit binders `{A : Type}` in scope in the `defn`
body?

**Yes.** When `spec` has `{A : Type}`, the `inject-spec-into-defn` mechanism should
introduce `A` as an in-scope erased variable. This allows the body to reference `A` for
explicit type applications:

```
spec list-conj {A : Type} [List A] -> A -> [List A]
defn list-conj [acc x]
  cons A x acc
```

Here `A` is used in `cons A x acc` to pass the type argument to `cons`. Without `A`
being in scope, this would be impossible.

**Implementation sketch**: The `{A : Type}` binders in `spec` become invisible leading
parameters in the desugared form. `defn list-conj [acc x] ...` desugars to
`fn (A :0 Type) -> fn (acc : List A) -> fn (x : A) -> cons A x acc`. The `{...}` binders
are prepended *before* the explicit `[...]` parameters but are not listed in the `defn`
parameter list.

### 4.6 Interaction with `where` Constraints

`where` constraints prepend trait dictionary parameters. With implicit binders, the
ordering is:

```
spec sort {A : Type} [List A] -> [List A] where Ord A
```

Desugars to:

```
Pi (A :0 Type) -> Pi ($Ord-A :w (Ord A)) -> List A -> List A
```

The `where` constraints are resolved after type-checking (as today). The `{A : Type}`
binder provides the scope in which `A` is available for the `Ord A` constraint.

### 4.7 Complete Transducer Example

Here is how the transducer stdlib would look with the proposed syntax:

```
;; map-xf : transform each element through f before passing to reducer.
spec map-xf {A B : Type} [A -> B] -> <(R :0 Type) -> [R -> B -> R] -> R -> A -> R>
defn map-xf [f]
  fn [R :0 <Type>] [rf acc x]
    rf acc [f x]

;; filter-xf : only pass elements satisfying pred to the reducer.
spec filter-xf {A : Type} [A -> Bool] -> <(R :0 Type) -> [R -> A -> R] -> R -> A -> R>
defn filter-xf [pred]
  fn [R :0 <Type>] [rf acc x]
    if [pred x] [rf acc x] acc

;; remove-xf : opposite of filter.
spec remove-xf {A : Type} [A -> Bool] -> <(R :0 Type) -> [R -> A -> R] -> R -> A -> R>
defn remove-xf [pred]
  fn [R :0 <Type>] [rf acc x]
    if [pred x] acc [rf acc x]

;; list-conj : cons-to-front reducer.
spec list-conj {A : Type} [List A] -> A -> [List A]
defn list-conj [acc x]
  cons A x acc

;; transduce : apply a polymorphic transducer to a list.
spec transduce {A B R : Type}
               <(S :0 Type) -> [S -> B -> S] -> S -> A -> S>
               [R -> B -> R]
               R
               [List A]
               -> R
defn transduce [xf rf init xs]
  lseq-fold R A [xf R rf] init [list-to-lseq A xs]

;; xf-compose : compose two transducers.
spec xf-compose {A B C : Type}
                <(S :0 Type) -> [S -> B -> S] -> S -> A -> S>
                <(S :0 Type) -> [S -> C -> S] -> S -> B -> S>
                -> <(S :0 Type) -> [S -> C -> S] -> S -> A -> S>
defn xf-compose [xf1 xf2]
  fn [R :0 <Type>] [rf]
    xf1 R [xf2 R rf]

;; into-list-rev : transduce into a reversed list.
spec into-list-rev {A B : Type}
                   <(S :0 Type) -> [S -> B -> S] -> S -> A -> S>
                   [List A]
                   -> [List B]
defn into-list-rev [xf xs]
  lseq-fold [List B] A [xf [List B] [list-conj B]] [nil B] [list-to-lseq A xs]
```

Every function is now in pure WS syntax. The `{...}` binders declare erased type
parameters, `<...>` groups delimit higher-rank parameters, and the `defn` bodies use
the type variables from `{...}` for explicit type applications.

### 4.8 Grammar Summary

The extensions to the spec grammar:

```
spec-decl     ::= "spec" name implicit* param-type* "->" return-type [where-clause]

implicit      ::= "{" binder-list "}"
binder-list   ::= name+ [":" mult] type
                 | binder-list "," binder-list

param-type    ::= bare-type              ;; Nat, Bool, [List A], [A -> B]
                | angle-pi-type          ;; <(x : T) -> body> (higher-rank Pi)

angle-pi-type ::= "<" "(" binders ")" arrow body ">"

bare-type     ::= atom | "[" type-expr "]"

where-clause  ::= "where" constraint+
constraint    ::= "(" trait-name type+ ")"
```

The critical addition is **`implicit`** (`{...}`) and the recognition that `<...>` in
parameter position denotes a higher-rank Pi.


## 5. Implementation Roadmap

### Phase 1: Reader — `{...}` tokenization

The WS reader already handles `{...}` for Map literals. A new context-sensitive rule is
needed: `{...}` after `spec` (before the first `->`) produces `($implicit-binder ...)`
sentinel datums rather than `($brace-literal ...)`. This may require the reader to track
whether it is inside a `spec` preamble, or alternatively, the preparse layer can
reinterpret brace groups in spec position.

### Phase 2: Macros — `process-spec` extension

Extend `process-spec` to:
1. Recognize leading `($implicit-binder ...)` groups before the first parameter type.
2. Store them separately in the `spec-entry` as `implicit-binders`.
3. Pass them through to `inject-spec-into-defn`.

### Phase 3: Macros — `decompose-spec-type` extension

Extend `decompose-spec-type` to:
1. Recognize `($angle-type ...)` elements in parameter position as opaque single params
   (already partially handled — angle types survive as grouped elements).
2. Ensure `param-type->angle-type` handles Pi-containing angle types by passing them
   through unchanged (they are already `($angle-type ...)` wrapped).

### Phase 4: Macros — `inject-spec-into-defn` extension

Extend `inject-spec-into-defn` to:
1. Prepend the `{...}` implicit binders as leading `fn (A :0 (Type 0))` wrappers around
   the desugared `defn` body.
2. Bring the implicit binder names into scope for the body.

### Phase 5: Parser — `defn` body with erased-Pi return

Extend the `defn` body parser to handle `fn [R :0 <Type>] [rf acc x] ...` — a lambda
with an erased binder followed by uncurried value parameters. This is a mixed
curried/uncurried form where the first parameter is a type and the rest are values.

### Phase 6: Tests

- Spec parsing with `{...}` binders.
- Angle-bracket Pi in parameter position.
- Injection into `defn` with implicit binder scoping.
- Full transducer stdlib rewrite as validation.


## 6. Alternatives Considered

### 6.1 `forall` keyword instead of `{...}`

A dedicated `forall` keyword:

```
spec id forall A : Type . A -> A
```

**Rejected** because: (a) it introduces a new keyword; (b) the `.` separator is foreign
to Prologos syntax; (c) `{...}` is more consistent with Agda/Lean/Idris which Prologos's
type theory aligns with.

### 6.2 Leading `Pi` in spec

Allow `Pi [A :0 <Type>]` directly in spec:

```
spec id Pi [A :0 <Type>] A -> A
```

**Rejected** because: (a) `decompose-spec-type` would need to distinguish "this Pi is
an outer binder" from "this Pi is a parameter type"; (b) without a distinct delimiter, the
flat arrow convention breaks — `Pi [A :0 <Type>] A -> A` looks like it has parameters
`Pi`, `[A :0 <Type>]`, and `A`, all before `-> A`.

### 6.3 Parenthesized `forall` (Haskell-style)

```
spec transduce (forall R. (R -> B -> R) -> R -> A -> R) -> ...
```

**Rejected** because: (a) Prologos does not use parentheses for grouping in WS mode
(brackets `[...]` and angle brackets `<...>` serve that role); (b) `forall` would be a
new keyword; (c) the `.` separator is unidiomatic.

### 6.4 Type aliases

```
type Xf A B = <(R :0 Type) -> [R -> B -> R] -> R -> A -> R>
spec transduce {A B R : Type} [Xf A B] [R -> B -> R] R [List A] -> R
```

**Complementary**, not a replacement. Type aliases are a separate feature that could be
built on top of the proposed syntax. The underlying mechanism for parsing and injecting
higher-rank Pi types is still needed even with aliases.


## 7. Summary

The proposed extension adds two syntactic forms to `spec`:

1. **`{...}` implicit binders** — declare erased type parameters that are in scope for
   the `defn` body but not listed as explicit parameters.
2. **`<...>` Pi in parameter position** — an angle-bracketed dependent type appearing as
   a parameter type denotes a higher-rank (polymorphic) parameter.

These two forms, together with the existing `[...]` bracket grouping and `<...>` dependent
type syntax, provide a complete and consistent surface for expressing arbitrary-rank
polymorphic types in Prologos's whitespace mode. The design:

- Reuses existing notation rather than inventing new keywords.
- Aligns with Agda/Lean/Idris conventions for implicit binders.
- Preserves full backward compatibility with existing `spec`/`defn` code.
- Composes naturally with `where` constraints and QTT multiplicities.
- Resolves the concrete limitation that forces the transducer stdlib into sexp form.


## References

1. Damas, L. & Milner, R. (1982). *Principal type-schemes for functional programs.* POPL.
2. Kfoury, A.J. & Wells, J.B. (1994). *A direct algorithm for type inference in the rank-2 fragment of the second-order lambda-calculus.* LFCS.
3. Wells, J.B. (1999). *Typability and type checking in System F are equivalent and undecidable.* Annals of Pure and Applied Logic.
4. Odersky, M. & Laufer, K. (1996). *Putting type annotations to work.* POPL.
5. Peyton Jones, S., Vytiniotis, D., Weirich, S. & Shields, M. (2007). *Practical type inference for arbitrary-rank types.* JFP.
6. Dunfield, J. & Krishnaswami, N. (2013). *Complete and easy bidirectional typechecking for higher-rank polymorphism.* ICFP.
7. Dunfield, J. & Krishnaswami, N. (2021). *Bidirectional typing.* ACM Computing Surveys.
8. Atkey, R. (2018). *Syntax and semantics of Quantitative Type Theory.* LICS.
9. Brady, E. (2021). *Idris 2: Quantitative Type Theory in practice.* ECOOP.
10. Serrano, A., Hage, J., Peyton Jones, S. & Vytiniotis, D. (2020). *A quick look at impredicativity.* ICFP.
11. Choudhury, P., Eisenberg, R., Weirich, S. & Eades, H. (2020). *Counting on Quantitative Type Theory.*
12. Abel, A., Danielsson, N.A. & Eriksson, A.S. (2023). *A graded modal dependent type theory with a universe and erasure.* ICFP.
