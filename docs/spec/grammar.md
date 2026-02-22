- [Introduction](#orge7f5df0)
- [Lexical Grammar](#org21a4b49)
  - [Comments](#orgb88b950)
  - [Identifiers](#org1a76aa3)
  - [Numeric Literals](#org51d6b97)
  - [String Literals](#orgccefed9)
  - [Keyword Literals](#org98f2384)
  - [Boolean Literals](#orge29740e)
  - [Special Tokens](#org8e28543)
  - [Bracket Types](#org1fa5088)
  - [Collection Literal Prefixes](#org85cf6ac)
- [Type Expressions](#org35ba0c8)
  - [Base Types](#org2b8773d)
  - [Parameterized Types](#org67466f7)
  - [Function Types (Arrows)](#org068c90d)
  - [Dependent Types (Angle Brackets)](#orgb83cc61)
  - [Sigma Types (Product / Pair Types)](#org45cc0ba)
  - [Equality Type](#orgbc0ccf2)
  - [Union Types](#orgd1a756d)
  - [Universe Levels](#org5b288ef)
  - [Type Holes](#orgfd1242b)
- [Expressions](#orgbfcdb70)
  - [Function Application](#org7a1146e)
  - [Lambda Expressions](#orgb67bf4e)
  - [Pattern Matching](#org1a1ffec)
  - [If (Conditional)](#org1951326)
  - [Let (Local Binding)](#org1da081e)
  - [Pipe Operator (|>)](#orgd575927)
  - [Compose Operator (>>)](#orgf426575)
  - [Type Annotations (the)](#org1acae6c)
  - [Pairs](#org712a2e3)
  - [Quote and Quasiquote](#org2945522)
  - [Collection Literals](#org0d42d7d)
  - [Partial Application](#orgc525de7)
  - [Varargs](#orge6665fd)
- [Declarations](#orgc134043)
  - [Namespace (ns)](#orgef47d53)
  - [Require](#orgf4b397a)
  - [Value Definition (def)](#orgc4afd69)
  - [Type Signature (spec)](#org4897979)
  - [Function Definition (defn)](#org020670f)
  - [Algebraic Data Types (data)](#orgd57f8fc)
  - [Traits and Implementations](#orgf87a83d)
  - [User-Defined Macros](#org734c6c9)
- [Multiplicity (QTT)](#orgf686b4a)
- [Dependent Types and Eliminators](#orgc022aff)
  - [Natural Number Elimination (natrec)](#org795c346)
  - [Equality Elimination (J)](#org606cf58)
  - [Length-Indexed Vectors](#org6f195fe)
- [Full Program Example](#org9dc40a6)
- [Appendix: S-Expression Mode](#org45a0987)
- [Appendix: Whitespace Reader Rules](#org060ccd6)
- [Appendix: Reader Desugaring Table](#org7bd86d1)



<a id="orge7f5df0"></a>

# Introduction

Prologos is a functional-logic language unifying dependent types, session types, linear types (QTT), logic programming, and propagators. This document describes the *surface syntax* of the language as written in `.prologos` files.

Prologos has two syntactic modes:

1.  **Whitespace-sensitive mode** (`.prologos` files): Indentation-based structure with `[]` for grouping and minimal punctuation. This is the primary mode.
2.  **S-expression mode**: Parenthesized fallback for use in macros, tests, and when embedding in Racket. Every WS-mode form has a canonical sexp representation.

The grammar is organized bottom-up: lexical elements, then types, then expressions, then declarations.

> **Design Principle**: Prologos is *homoiconic* &#x2014; code and data share the same representation. All syntactic sugar desugars to s-expressions. Macros operate on the post-parse representation, making code-as-data a first-class concept.


<a id="org21a4b49"></a>

# Lexical Grammar


<a id="orgb88b950"></a>

## Comments

Line comments begin with `;` and extend to end of line. There are no block comments.

```prologos
;; This is a comment
def x : Nat zero  ; inline comment
```


<a id="org1a76aa3"></a>

## Identifiers

Identifiers may contain letters, digits, hyphens, question marks, exclamation marks, and primes. They must not start with a digit.

```grammar
identifier  ::= ident-start { ident-char }
ident-start ::= letter | '_' | '+' | '*' | '/' | '!' | '?' | '<' | '>' | '='
ident-char  ::= ident-start | digit | '-' | "'"
```

Naming conventions:

-   Predicates use `?` suffix: `zero?`, `empty?`, `member?`
-   Destructive operations use `!` suffix: `persist!`, `tvec-push!`
-   Type names are capitalized: `Nat`, `List`, `Option`
-   Value names are lowercase with hyphens: `sort-on`, `find-index`

Qualified names use `::` separator:

```prologos
list::map       ;; qualified reference to list module's map
nat::add        ;; qualified reference to nat module's add
opt::unwrap-or  ;; qualified reference to option module's unwrap-or
```


<a id="org51d6b97"></a>

## Numeric Literals

Prologos has four numeric literal forms, plus a decimal variant for approximate literals:

```grammar
nat-literal     ::= digit+ 'N'                (* Natural: 0N, 42N, 100N *)
int-literal     ::= ['-'] digit+              (* Integer: 42, -7, 0     *)
rat-literal     ::= ['-'] digit+ '/' digit+   (* Rational: 3/7, -1/3   *)
decimal-literal ::= ['-'] digit+ '.' digit+   (* Decimal: 3.14, 0.5    *)
approx-literal  ::= '~' (int | rat | decimal) (* Posit approx: ~42, ~3/7, ~3.14 *)
```

```prologos
42N          ;; Nat literal (Church-encoded natural — type infrastructure only)
42           ;; Int literal (arbitrary-precision integer)
3/7          ;; Rat literal (exact rational)
~3/7         ;; approximate Posit literal (from fraction)
~3.14        ;; approximate Posit literal (from decimal, stored as exact rational 157/50)
```

Decimal literals in `~` context are converted to exact rationals: `~3.14` → `157/50` → nearest Posit32. Nat is intended for type-level infrastructure (indices, lengths, proofs), not general computation.


<a id="orgccefed9"></a>

## String Literals

Double-quoted with standard escape sequences (`\n`, `\t`, `\\`, `\"`).

```prologos
"hello world"
"line one\nline two"
```


<a id="org98f2384"></a>

## Keyword Literals

Keywords start with `:` and are used as map keys and enum-like values:

```prologos
:name
:age
:hello
```


<a id="orge29740e"></a>

## Boolean Literals

```prologos
true
false
```


<a id="org8e28543"></a>

## Special Tokens

| Token     | Meaning                                       |
|--------- |--------------------------------------------- |
| `_`       | Wildcard / type hole (inferred)               |
| `_1` `_2` | Numbered placeholders for partial application |
| `:0`      | Erased multiplicity (use 0 times)             |
| `:1`      | Linear multiplicity (use exactly 1 time)      |
| `:w`      | Unrestricted multiplicity (use any times)     |
| `zero`    | Nat zero constructor                          |
| `unit`    | Unit value                                    |
| `refl`    | Equality reflexivity proof                    |


<a id="org1fa5088"></a>

## Bracket Types

Prologos uses four bracket types, each with distinct semantics:

| Brackets | Purpose                                         |
|-------- |----------------------------------------------- |
| `[...]`  | Primary grouping: function application, params  |
| `(...)`  | Special forms: `(fn ...)`, `(match ...)`, types |
| `{...}`  | Implicit type parameters, map literals          |
| `<...>`  | Dependent types, return type annotations        |

Inside any bracket pair, newlines are treated as whitespace (indentation is not significant).


<a id="org85cf6ac"></a>

## Collection Literal Prefixes

| Syntax   | Type   | Example         |
|-------- |------ |--------------- |
| `'[...]` | `List` | `'[1N 2N 3N]`   |
| `@[...]` | `PVec` | `@[1 2 3]`      |
| `~[...]` | `LSeq` | `~[1 2 3]`      |
| `#{...}` | `Set`  | `#{1 2 3}`      |
| `{k v}`  | `Map`  | `{:name "Ada"}` |


<a id="org35ba0c8"></a>

# Type Expressions

In a dependently-typed language, types and terms share the same expression syntax. This section highlights type-specific forms.


<a id="org2b8773d"></a>

## Base Types

```grammar
base-type ::= 'Type'     (* universe of types, level inferred *)
            | 'Nat'      (* natural numbers                    *)
            | 'Int'      (* arbitrary-precision integers        *)
            | 'Rat'      (* exact rationals                     *)
            | 'Bool'     (* booleans                            *)
            | 'Unit'     (* unit type                           *)
            | 'Symbol'   (* symbols for homoiconicity           *)
            | 'Keyword'  (* keyword type for map keys           *)
            | 'Datum'    (* code-as-data algebraic type         *)
```

```prologos
def x : Nat zero
def b : Bool true
def u : Unit unit
```


<a id="org67466f7"></a>

## Parameterized Types

Types are applied to arguments via juxtaposition in brackets:

```prologos
List Nat            ;; list of natural numbers
Option Bool         ;; optional boolean
Map Keyword Int     ;; keyword-to-int map
Vec Nat 3N          ;; length-3 vector of Nats (dependent!)
Set Int             ;; set of ints
PVec Nat            ;; persistent vector of Nats
```


<a id="org068c90d"></a>

## Function Types (Arrows)

Arrows are right-associative infix operators:

```grammar
arrow-type ::= type '->' type    (* unrestricted function *)
             | type '-0>' type   (* erased function       *)
             | type '-1>' type   (* linear function       *)
             | type '-w>' type   (* unrestricted, explicit *)
```

```prologos
Nat -> Nat                ;; simple function
Nat -> Nat -> Bool        ;; curried: Nat -> (Nat -> Bool)
[List A] -> Nat           ;; bracketed domain
[A -> B] -> [List A] -> List B  ;; higher-order
```


<a id="orgb83cc61"></a>

## Dependent Types (Angle Brackets)

Angle brackets delimit dependent Pi (universal) and Sigma (existential) types:

```grammar
dependent-type ::= '<' '(' ident ':' type ')' '->' type '>'  (* dependent Pi   *)
                 | '<' '(' ident ':' type ')' '*'  type '>'  (* dependent Sigma *)
                 | '<' ident ':' type '->' type '>'           (* shorthand Pi   *)
```

```prologos
;; Dependent function: "for all n : Nat, a vector of length n"
<(n : Nat) -> Vec Nat n>

;; Dependent pair: "a natural n together with a Vec of that length"
<(n : Nat) * Vec Nat n>

;; Shorthand (single binder, no inner parens):
<n : Nat -> Vec Nat n>
```


<a id="org45cc0ba"></a>

## Sigma Types (Product / Pair Types)

Non-dependent pair types use infix `*`:

```prologos
;; Non-dependent pair
Nat * Bool

;; In return type of split-at:
[Sigma [_ <List A>] [List A]]

;; Dependent Sigma via angle brackets:
<(x : Nat) * Vec Nat x>
```


<a id="orgbc0ccf2"></a>

## Equality Type

```prologos
;; Eq type : proof that two terms are equal
(Eq Nat zero zero)       ;; 0 = 0 at type Nat
(Eq Nat [add x y] [add y x])  ;; commutativity
```


<a id="orgd1a756d"></a>

## Union Types

Union types use infix `|`:

```prologos
Nat | Bool         ;; either a Nat or a Bool
Int | Rat | Nat    ;; right-associative: Int | (Rat | Nat)
```


<a id="org5b288ef"></a>

## Universe Levels

```prologos
Type           ;; universe, level inferred
(Type 0)       ;; explicit level 0
(Type 1)       ;; explicit level 1 (contains Type 0)
```


<a id="orgfd1242b"></a>

## Type Holes

The wildcard `_` stands for an inferred type:

```prologos
def x : _ zero    ;; type inferred as Nat
map _ xs          ;; type argument inferred
```


<a id="orgbfcdb70"></a>

# Expressions


<a id="org7a1146e"></a>

## Function Application

Application is juxtaposition, with brackets `[]` for grouping:

```prologos
;; Simple application
suc zero                    ;; suc(zero)

;; Multi-argument (uncurried convention)
add x y                     ;; add(x, y)

;; Brackets for grouping
[add x y]                   ;; same as add x y
cons [f a] [map f as]       ;; cons(f(a), map(f, as))

;; Nested application
map [add 1N _] '[1N 2N 3N]  ;; map with partial application
```


<a id="orgb67bf4e"></a>

## Lambda Expressions

```grammar
lambda ::= 'fn' binder+ body
         | '(' 'fn' '(' ident ':' type ')' body ')'   (* sexp mode *)
```

```prologos
;; WS mode: fn with bracket binder
fn [x : Nat] [suc x]

;; Multiple binder groups
fn [x : Nat] [y : Nat] [add x y]

;; Bare parameter (type inferred from context)
fn x [suc x]

;; Sexp mode: explicit binder
(fn (x : Nat) (suc x))

;; With multiplicity annotation
(fn (x :1 Nat) x)          ;; linear lambda
(fn (x :0 Nat) zero)       ;; erased lambda (can't use x)
```


<a id="org1a1ffec"></a>

## Pattern Matching

`match` is the primary pattern matching form, using `|` for arm separation:

```grammar
match-expr ::= 'match' scrutinee match-arm+
match-arm  ::= '|' pattern '->' body
```

```prologos
;; Match on Nat
match n
  | zero  -> zero
  | suc k -> add k k

;; Match on Bool
match b
  | true  -> suc zero
  | false -> zero

;; Match on List
match xs
  | nil       -> zero
  | cons a as -> suc [length as]

;; Match on Option
match [find pred xs]
  | none   -> default
  | some v -> v

;; Nested match
match xs
  | nil       -> nil
  | cons a as -> match [pred a]
    | true  -> cons a [filter pred as]
    | false -> filter pred as
```

Available patterns:

-   **Variable**: `x`, `n`, `rest` &#x2013; binds the matched value
-   **Wildcard**: `_` &#x2013; matches anything, discards
-   **Constructor**: `zero`, `suc k`, `nil`, `cons a as`, `true`, `false`, `none`, `some v`, `ok v`, `err e`, `datum-nil`, `datum-cons h t`, etc.
-   **Nested**: `[cons x nil]` &#x2013; grouped pattern in brackets


<a id="org1951326"></a>

## If (Conditional)

`if` is a macro that desugars to `match` on Bool:

```prologos
;; Three-argument if
if [zero? n] base-case [step n]

;; Equivalent match:
match [zero? n]
  | true  -> base-case
  | false -> step n
```


<a id="org1da081e"></a>

## Let (Local Binding)

`let` is a macro that desugars to application:

```prologos
;; Single binding
let x = [add 1N 2N]
  suc x

;; With type annotation
let x : Nat = [add 1N 2N]
  suc x
```


<a id="orgd575927"></a>

## Pipe Operator (|>)

The pipe operator threads a value left-to-right through functions:

```prologos
;; Binary pipe
zero |> suc |> suc |> suc    ;; = suc(suc(suc(zero))) = 3

;; Block pipe with indented steps
|> nums
  map suc-fn
  filter is-positive
  reduce sum-rf zero

;; Block pipes support automatic loop fusion:
;; consecutive map/filter steps fuse into a single-pass
;; transducer when followed by a terminal (reduce, sum, etc.)
```


<a id="orgf426575"></a>

## Compose Operator (>>)

Left-to-right function composition:

```prologos
;; Compose two functions
[suc >> suc] zero           ;; = suc(suc(zero)) = 2

;; Pipe into a composed function
zero |> [suc >> double]     ;; = double(suc(zero))
```


<a id="org1acae6c"></a>

## Type Annotations (the)

Explicit type annotation on an expression:

```prologos
;; Annotate with explicit type
(the Nat zero)
(the [List Nat] nil)
```


<a id="org712a2e3"></a>

## Pairs

```prologos
;; Construct a pair
pair 1N true

;; Project from a pair
first [pair 1N true]        ;; = 1N
second [pair 1N true]       ;; = true

;; Aliases: fst, snd
fst [pair x y]
snd [pair x y]
```


<a id="org2945522"></a>

## Quote and Quasiquote

Quote `'` converts code to `Datum` (code-as-data):

```prologos
'foo          ;; -> datum-sym
'42           ;; -> datum-nat
':hello       ;; -> datum-kw
'true         ;; -> datum-bool
'()           ;; -> datum-nil
'(add 1 2)   ;; -> datum-cons chain

;; Quasiquote with unquote
def val : Datum [datum-nat 10]
`,val          ;; splice val into template
`(add 1 ,val)  ;; template with hole
```


<a id="org0d42d7d"></a>

## Collection Literals

```prologos
;; List literal (linked list)
'[1N 2N 3N]

;; List with tail
'[1N 2N | rest-list]

;; PVec (persistent vector)
@[1 2 3 4 5]

;; Set
#{1 2 3}

;; Lazy sequence
~[1 2 3]

;; Map (key-value pairs)
{:name "Ada" :age 36}
```


<a id="orgc525de7"></a>

## Partial Application

Numbered placeholders `_1`, `_2` enable positional reordering:

```prologos
;; Wildcard _ fills rightmost position
[add 1N _]           ;; fn x -> add 1N x

;; Numbered holes for reordering
[div _2 _1]          ;; fn x y -> div y x
```


<a id="orge6665fd"></a>

## Varargs

The `...` marker in specs indicates variadic arguments. In `defn`, `...name` collects excess arguments into a `List`:

```prologos
spec sum-all Nat ... -> Nat
defn sum-all [...xs]
  sum xs

sum-all 1 2 3          ;; = 6
sum-all 1 2 3 4 5      ;; = 15

;; Mixed fixed + varargs
spec first-plus-rest Nat Nat ... -> Nat
defn first-plus-rest [first ...rest]
  add first [sum rest]

first-plus-rest 100 1 2 3  ;; = 106
```


<a id="orgc134043"></a>

# Declarations


<a id="orgef47d53"></a>

## Namespace (ns)

Must be the first form in a file. Controls module identity and prelude loading:

```prologos
;; Standard namespace: auto-imports prelude
ns my-project.utils

;; Bare namespace: no prelude
ns prologos.data.list :no-prelude
```

The prelude automatically provides: `Nat`, `Bool`, `List`, `Option`, `Result`, `Pair` operations, `Eq=/=Ord=/=Add=/=Sub=/=Mul=/=Neg=/=Abs=/=FromInt=/=Num=/ =Fractional` traits and instances.


<a id="orgf4b397a"></a>

## Require

Import modules with named or aliased references:

```prologos
;; Named imports
require [prologos.data.list :refer [List nil cons map length]]

;; Aliased module
require [prologos.data.nat :as nat :refer [add mult]]

;; Multiple requires
require [prologos.data.list   :refer [List nil cons map]]
        [prologos.data.nat    :refer [add mult]]
        [prologos.data.option :refer [Option none some]]
```


<a id="orgc4afd69"></a>

## Value Definition (def)

```prologos
;; With type annotation
def x : Nat zero

;; Shorthand with :=
def x := zero

;; Multi-line body (indented)
def nums : [List Nat]
  cons 1N [cons 2N [cons 3N [nil Nat]]]

;; Private (not auto-exported)
def- internal-state : Nat zero
```


<a id="org4897979"></a>

## Type Signature (spec)

`spec` declares a type signature separately from the definition:

```prologos
;; Simple function type
spec factorial Nat -> Nat

;; With implicit type parameters
spec map {A B : Type} [A -> B] [List A] -> List B

;; With trait constraints
spec elem {A : Type} [Eq A] A [List A] -> Bool

;; With varargs
spec sum-all Nat ... -> Nat

;; With multiple implicits and constraints
spec sort-on {A B : Type} [B -> B -> Bool] [A -> B] [List A] -> List A
```


<a id="org020670f"></a>

## Function Definition (defn)

```prologos
;; Basic function
spec add Nat -> Nat -> Nat
defn add [x y]
  match x
    | zero  -> y
    | suc n -> suc [add n y]

;; With inline type
defn suc-all [xs : List Nat] : List Nat
  map [add _ 1N] xs

;; With return type annotation
impl Eq Nat
  defn eq? [x y] <Bool>
    nat-eq? x y

;; Multi-arity with |
defn fact
  | [zero]  -> suc zero
  | [suc n] -> mult [suc n] [fact n]

;; Private
defn- helper [x]
  suc x
```


<a id="orgd57f8fc"></a>

## Algebraic Data Types (data)

```prologos
;; Enumeration (nullary constructors)
data Bool
  true
  false

;; Parameterized with constructors
data List {A}
  nil
  cons : A -> List A

;; Multiple implicit params
data Either {A B}
  left  : A
  right : B

;; Single constructor (wrapper)
data Ordering
  lt-ord
  eq-ord
  gt-ord

;; Private data type
data- InternalTree {A}
  leaf
  node : A -> InternalTree A -> InternalTree A
```


<a id="orgf87a83d"></a>

## Traits and Implementations

```prologos
;; Trait definition
trait Eq {A}
  eq? : A -> A -> Bool

;; Implementation
impl Eq Nat
  defn eq? [x y] <Bool>
    nat-eq? x y

;; Multi-method trait
trait Ord {A}
  compare : A -> A -> Ordering

;; Generic functions using trait dicts
spec eq-neq [Eq A] A A -> Bool
defn eq-neq [dict x y]
  not [dict x y]

;; Bundle: named trait combination
bundle Num := (Add, Sub, Mul, Neg, Abs, FromInt)
```


<a id="org734c6c9"></a>

## User-Defined Macros

```prologos
;; Simple macro: double-it x --> add x x
defmacro double-it [$x] [add $x $x]

double-it 5             ;; = 10

;; Conditional macro
defmacro when-nonzero [$n $body]
  [if [not [zero? $n]] $body zero]

when-nonzero 5 [double 5]    ;; = 10
when-nonzero zero [double 5]  ;; = 0

;; Introspection
(expand (double-it 5))        ;; shows expansion
(expand-1 (double-it 5))      ;; one step
(expand-full (when true [suc zero]))  ;; all steps with labels
```


<a id="orgf686b4a"></a>

# Multiplicity (QTT)

Prologos uses Quantitative Type Theory for resource tracking. Each variable binding has a *multiplicity* annotation:

| Annotation | Meaning                    | Syntax       |
|---------- |-------------------------- |------------ |
| `:0`       | Erased (0 uses at runtime) | `(x :0 Nat)` |
| `:1`       | Linear (exactly 1 use)     | `(x :1 Nat)` |
| `:w`       | Unrestricted (any uses)    | `(x :w Nat)` |

Arrow types carry multiplicities:

```prologos
Nat -> Nat            ;; unrestricted (default :w)
Nat -0> Nat           ;; erased: argument not used at runtime
Nat -1> Nat           ;; linear: argument used exactly once
Nat -w> Nat           ;; unrestricted: explicit
```

```prologos
;; Erased argument (type-level only)
(fn (A :0 Type) (fn (x :w A) x))     ;; polymorphic identity

;; Linear function
(fn (x :1 Nat) x)                    ;; must use x exactly once
```


<a id="orgc022aff"></a>

# Dependent Types and Eliminators


<a id="org795c346"></a>

## Natural Number Elimination (natrec)

The low-level eliminator for natural numbers:

```prologos
;; natrec motive base step target
;; motive : Nat -> Type
;; base   : motive zero
;; step   : (n : Nat) -> motive n -> motive (suc n)
;; target : Nat
natrec motive base step target
```

In practice, `match` is preferred:

```prologos
;; Idiomatic: match instead of natrec
defn double [n]
  match n
    | zero  -> zero
    | suc k -> suc [suc [double k]]
```


<a id="org606cf58"></a>

## Equality Elimination (J)

```prologos
;; J motive base left right proof
;; Given proof : Eq A left right
;; J computes: motive(left, right, proof) via base(left)
J motive base left right refl
```


<a id="org6f195fe"></a>

## Length-Indexed Vectors

```prologos
;; Vec A n : a vector of exactly n elements of type A
;; Fin n   : a number guaranteed less than n

vnil Nat                         ;; empty: Vec Nat 0
vcons Nat 2N x xs                ;; cons:  Vec Nat 3 (given xs : Vec Nat 2)
vhead Nat 2N v                   ;; safe head (non-empty guaranteed)
vtail Nat 2N v                   ;; safe tail
vindex Nat 3N [fzero 2N] v      ;; safe index via Fin
```


<a id="org9dc40a6"></a>

# Full Program Example

A complete Prologos program demonstrating multiple features:

```prologos
ns examples.demo

require [prologos.data.list   :refer [List nil cons map reduce sum length]]
        [prologos.data.nat    :refer [add mult]]
        [prologos.data.option :refer [Option none some]]

;; Type signature with implicit params
spec factorial Nat -> Nat
defn factorial [n]
  match n
    | zero  -> suc zero
    | suc k -> mult n [factorial k]

;; Higher-order function with trait constraint
spec sum-mapped {A : Type} [A -> Nat] [List A] -> Nat
defn sum-mapped [f xs]
  sum [map f xs]

;; Data type definition
data Tree {A}
  leaf
  node : A -> Tree A -> Tree A

;; Pattern matching on user-defined types
spec tree-size [Tree A] -> Nat
defn tree-size [t]
  match t
    | leaf       -> zero
    | node _ l r -> suc [add [tree-size l] [tree-size r]]

;; Using pipe operator
def result : Nat
  |> '[1N 2N 3N 4N 5N]
    map [add 1N _]
    reduce add 0N

;; Macro definition
defmacro unless [$cond $body] [if $cond zero $body]

;; Using the macro
unless [zero? 5] [factorial 5]
```


<a id="org45a0987"></a>

# Appendix: S-Expression Mode

Every WS-mode form has a canonical s-expression representation. In sexp mode, all grouping uses parentheses and whitespace is not significant:

```prologos
;; WS mode:
defn add [x y]
  match x
    | zero  -> y
    | suc n -> suc [add n y]

;; Equivalent sexp mode:
(defn add (x y)
  (match x
    (zero  -> y)
    (suc n -> (suc (add n y)))))

;; WS mode:
spec map {A B : Type} [A -> B] [List A] -> List B

;; Equivalent sexp mode:
(spec map {A B : Type} (-> (-> A B) (-> (List A) (List B))))
```


<a id="org060ccd6"></a>

# Appendix: Whitespace Reader Rules

The WS reader converts indentation to explicit structure:

1.  **Same indentation** as previous line: NEWLINE token (sibling separator)
2.  **Deeper indentation**: INDENT token (child block begins)
3.  **Shallower indentation**: DEDENT token(s) (child blocks end)
4.  **Inside brackets** `[]`, `()`, `{}`, `<>`: newlines are whitespace
5.  **Blank/comment lines**: ignored for indentation purposes
6.  **Column 0**: always starts a new top-level form


<a id="org7bd86d1"></a>

# Appendix: Reader Desugaring Table

| Surface syntax | Reader output           | Meaning                     |
|-------------- |----------------------- |--------------------------- |
| `'expr`        | `($quote expr)`         | Quote to Datum              |
| `` `expr ``    | `($quasiquote expr)`    | Quasiquote template         |
| `,expr`        | `($unquote expr)`       | Unquote (splice into QQ)    |
| `42N`          | `($nat-literal 42)`     | Natural number literal      |
| `~42`          | `($approx-literal 42)`  | Approximate (Posit) literal |
| `:name`        | `keyword token`         | Keyword literal             |
| `'[1 2 3]`     | `($list-literal 1 2 3)` | List literal                |
| `@[1 2 3]`     | `($vec-literal 1 2 3)`  | PVec literal                |
| `~[1 2 3]`     | `($lseq-literal 1 2 3)` | Lazy sequence literal       |
| `#{1 2 3}`     | `($set-literal 1 2 3)`  | Set literal                 |
| `...name`      | `($rest-param name)`    | Rest/vararg parameter       |
| `x \vert> f`   | `($pipe-gt x f)`        | Pipe left-to-right          |
| `f >> g`       | `($compose f g)`        | Compose left-to-right       |
