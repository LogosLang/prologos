- [Naming Conventions](#org8a4cc57)
  - [Functions and Values](#orge5fd694)
  - [Types and Constructors](#org25d8ad3)
  - [Modules and Namespaces](#orgbe476b0)
  - [Library Functions Should Not Repeat the Library Name](#orgddd13f4)
  - [Trait Methods](#orgc9b68c7)
- [Nat vs Int: When to Use Each](#orgdeff697)
- [Function Definition Patterns](#org75330cb)
  - [Prefer `spec` / `defn` Over `def` With Lambda](#orgc37a1c9)
  - [Prefer Multi-Arity Over Helper Functions](#org1d25982)
  - [Uncurried Arguments, Curried Results](#org91c7f6f)
- [Bracket Usage Rules](#orga14348c)
- [Collection Conventions](#org41fafb1)
  - [Seq as Universal Hub](#orgab36ec7)
  - [Map as Two-Param Type](#org56fa1d7)
- [Import and Module Patterns](#org3ad96d0)
  - [Standard Import Forms](#org20b6704)
  - [Library Modules Skip Prelude](#org3540ac2)
  - [Prelude Exports](#org2f7764e)
- [Type Annotation Patterns](#org7bd8ed7)
  - [Spec for Public Functions](#orgbc472ee)
  - [Inline Annotation for Local Bindings](#orgf5386c6)
  - [Implicit vs. Explicit Type Parameters](#org01b4baf)
- [Error Handling Conventions](#orga25bef1)
  - [Use `A?` (Nilable) for Simple Absence](#org63bbb7b)
  - [Use `Result E A` for Recoverable Errors](#org8a369b5)
  - [Use Dependent Types for Preconditions](#org3360345)
- [Pipe and Composition](#org0dec943)
  - [`|>` for Value Threading (Last Argument Position)](#orgcc9eb99)
  - [`>>` for Function Composition (Left-to-Right)](#orgb244744)
  - [Block-Form `|>` Enables Loop Fusion](#org09c4f9b)



<a id="org8a4cc57"></a>

# Naming Conventions


<a id="orge5fd694"></a>

## Functions and Values

-   Lowercase with hyphens: `find-index`, `sort-on`, `map-get`
-   Predicates end in `?`: `zero?`, `empty?`, `member?`, `even?`
-   Destructive / side-effecting operations end in `!`: `persist!`, `tvec-push!`
-   Transducers end in `-xf`: `map-xf`, `filter-xf`, `take-xf`


<a id="org25d8ad3"></a>

## Types and Constructors

-   Capitalized: `Nat`, `List`, `Option`, `Bool`, `Map`
-   Multi-word types: PascalCase: `QueryResult`, `AdditiveIdentity`
-   Constructors: lowercase of their type: `some`, `none`, `cons`, `nil`


<a id="orgbe476b0"></a>

## Modules and Namespaces

-   Separated by `::`: `prologos::data::list`, `prologos::core::map-ops`
-   Module aliases with `:as`: `require [prologos::core::map-ops :as m]`
-   Selective import: `:refer [merge fold-entries keys vals]`
-   Side-effect import: `:refer []` (triggers instance registration)


<a id="orgddd13f4"></a>

## Library Functions Should Not Repeat the Library Name

By convention, users import libraries with an alias. This means library functions should use short, unqualified names:

```prologos
;; GOOD: short names, users alias the module
;; In prologos::core::map-ops:
spec keys : {K V : Type} [Map K V] -> [List K]
spec vals : {K V : Type} [Map K V] -> [List V]
spec merge : {K V : Type} [Map K V] [Map K V] -> [Map K V]

;; Usage: qualified access prevents collision
require [prologos::core::map-ops :as m :refer [merge]]
m::keys my-map
m::vals my-map
merge m1 m2

;; BAD: redundant prefix
spec map-keys-list ...   ;; "map" is already in the module name
spec map-vals-list ...   ;; user would write m::map-vals-list (double "map")
```

When a library function name collides with a parser keyword or another prelude name, use the module alias for disambiguation rather than lengthening the function name.


<a id="orgc9b68c7"></a>

## Trait Methods

Short, action-oriented names: `eq?`, `from`, `add`, `sub`, `compare`. The trait name provides context: `(Eq A)` implies `eq?` compares for equality within type `A`.


<a id="orgdeff697"></a>

# Nat vs Int: When to Use Each

`Nat` (Peano naturals: `zero`, `suc`) is *type-level machinery* &#x2014; it exists for dependent type indexing, structural induction, and proof terms. It is NOT for general-purpose arithmetic.

`Int` (arbitrary-precision integers) is the default numeric type for computation. `Rat` for exact rationals. `Posit32` for approximate.

| Use Case                      | Type      | Example                         |
|----------------------------- |--------- |------------------------------- |
| General arithmetic            | `Int`     | `[+ 3 4]` => `7 : Int`          |
| Exact fractions               | `Rat`     | `3/7 : Rat`                     |
| Approximate computation       | `Posit32` | `~3.14 : Posit32`               |
| Type-level vector length      | `Nat`     | `<(n : Nat) -> Vec A n>`        |
| Structural induction / proofs | `Nat`     | ~defn by-induction \\           | [zero] &#x2026;~ |
| List length (structural)      | `Nat`     | `spec length : [List A] -> Nat` |
| Indexing (nth, take, drop)    | `Nat`     | `spec nth : Nat [List A] -> A?` |

```prologos
;; GOOD: Int for computation
spec factorial : Int -> Int
defn factorial [n]
  if [<= n 1] 1 [* n [factorial [- n 1]]]

;; GOOD: Nat for type-level indexing
spec safe-head : {A : Type} (xs : [List A]) {pf : [NonEmpty xs]} -> A

;; BAD: Nat for general computation
;; spec factorial : Nat -> Nat   -- Nat is for types, not computation
```


<a id="org75330cb"></a>

# Function Definition Patterns


<a id="orgc37a1c9"></a>

## Prefer `spec` / `defn` Over `def` With Lambda

```prologos
;; GOOD: spec + defn
spec factorial : Int -> Int
defn factorial [n]
  if [<= n 1] 1
    [* n [factorial [- n 1]]]

;; ACCEPTABLE but less idiomatic:
def factorial : [Int -> Int]
  fn [n] (if (<= n 1) 1 (* n (factorial (- n 1))))
```


<a id="org1d25982"></a>

## Prefer Multi-Arity Over Helper Functions

Use the `|` separator for pattern-matching arities rather than defining separate helper functions. Note that Nat multi-arity is appropriate for structural/type-level functions (like `length`), while computational functions use `Int`:

```prologos
;; GOOD: multi-arity for structural recursion (Nat is appropriate here)
spec length : {A : Type} [List A] -> Nat
defn length
  | [nil]        -> 0N
  | [[cons _ t]] -> [suc [length t]]

;; GOOD: Int for computational functions
spec sum-list : [List Int] -> Int
defn sum-list
  | [nil]        -> 0
  | [[cons h t]] -> [+ h [sum-list t]]
```

Multi-arity definitions keep related logic together, are more readable, and let the compiler see the full pattern space for exhaustiveness checking.


<a id="org91c7f6f"></a>

## Uncurried Arguments, Curried Results

Functions take arguments as a flat group, not curried:

```prologos
;; GOOD: uncurried
spec fold : {A B : Type} [B -> A -> B] B [List A] -> B
defn fold [f z xs] ...

;; AVOID: fully curried (Haskell style)
spec fold : {A B : Type} [B -> A -> B] -> B -> [List A] -> B
```

The uncurried convention matches the `[f x y z]` call syntax and avoids partial application confusion. When currying is desired, use explicit lambda: `[fn [x] [fold f x]]`.


<a id="orga14348c"></a>

# Bracket Usage Rules

| Context          | Use     | Example                   |
|---------------- |------- |------------------------- |
| Function call    | `[...]` | `[map inc xs]`            |
| Logic clause     | `(...)` | `(edge ?from ?to)`        |
| Type grouping    | `<...>` | `<(n : Nat) -> Vec A n>`  |
| Parser keywords  | `(...)` | `(match ...)`, `(fn ...)` |
| Implicit binders | `{...}` | `{A B : Type}`            |
| Map literal      | `{...}` | `{:name "Ada"}`           |
| PVec literal     | `@[..]` | `@[1 2 3]`                |
| List literal     | `'[..]` | `'[1 2 3]`                |
| Set literal      | `#{..}` | `#{:a :b}`                |
| Lazy seq literal | `~[..]` | `~[1 2 3]`                |

Key rule: **outer trees are implicit** &#x2014; top-level forms don't need wrapping brackets. Write `defn foo [x] body`, not `[defn foo [x] body]`.


<a id="org41fafb1"></a>

# Collection Conventions


<a id="orgab36ec7"></a>

## Seq as Universal Hub

All collection operations go through `LSeq` (lazy sequence) as the universal intermediate representation:

```
Any Collection → to-seq → transform (map/filter/fold) → to-seq → Any Collection
```

Use `Seqable`, `Buildable`, and `Foldable` traits for generic code. Use collection-specific modules (`pvec-ops`, `set-ops`, `map-ops`) for type-specific operations.


<a id="org56fa1d7"></a>

## Map as Two-Param Type

`Map K V` has two type parameters, which means it cannot implement the standard one-param traits (`Seqable`, `Foldable`, `Buildable`). Instead, use standalone functions from `map-ops`:

```prologos
;; These are standalone functions, not trait methods
[m::fold-entries f z my-map]   ;; fold over (K, V) pairs
[m::map-vals f my-map]         ;; map over values
[m::keys my-map]               ;; extract key list
```


<a id="org3ad96d0"></a>

# Import and Module Patterns


<a id="org20b6704"></a>

## Standard Import Forms

```prologos
;; Import with alias (preferred for libraries)
require [prologos::core::map-ops :as m :refer [merge]]

;; Import specific names
require [prologos::data::list :refer [List nil cons map filter]]

;; Side-effect only (registers trait instances)
require [prologos::core::eq-nat :refer []]

;; Full prelude
ns my-module

;; Bare mode (no prelude)
ns my-module :no-prelude
```


<a id="org3540ac2"></a>

## Library Modules Skip Prelude

Library modules under `prologos::data::*` and `prologos::core::*` must use `:no-prelude` (or the equivalent Racket-side mechanism) to avoid circular dependencies. They import only what they need explicitly.


<a id="org2f7764e"></a>

## Prelude Exports

The prelude (`ns foo`) provides:

-   Core types: `Nat`, `Bool`, `List`, `Option`, `Result`, `Pair`
-   Collections: `PVec`, `Map`, `Set`, `LSeq`
-   All traits and instances: `Eq`, `Ord`, `Add`, `Sub`, etc.
-   Collection operations and conversions
-   Generic numeric functions: `sum`, `product`, `int-range`

Own-definition priority: a user's `def map` shadows the prelude's `list::map`.


<a id="org7bd8ed7"></a>

# Type Annotation Patterns


<a id="orgbc472ee"></a>

## Spec for Public Functions

Every exported function should have a `spec`:

```prologos
spec sort : {A : Type} where (Ord A) [List A] -> [List A]
defn sort [xs] ...
```


<a id="orgf5386c6"></a>

## Inline Annotation for Local Bindings

Use `(the Type expr)` or `(def x : Type val)` for local type ascription:

```prologos
def xs : [List Int] '[1 2 3]
(the [List Int] '[1 2 3])
```


<a id="org01b4baf"></a>

## Implicit vs. Explicit Type Parameters

-   `{A : Type}` in `spec` &#x2014; implicit, inferred at call site
-   `(A : Type)` in `spec` &#x2014; explicit, must be provided
-   Convention: type parameters are implicit unless the caller needs to specify them (e.g., `map-empty K V` where both must be explicit)


<a id="orga25bef1"></a>

# Error Handling Conventions


<a id="org63bbb7b"></a>

## Use `A?` (Nilable) for Simple Absence

```prologos
spec find : {A : Type} [A -> Bool] [List A] -> A?
```


<a id="org8a369b5"></a>

## Use `Result E A` for Recoverable Errors

```prologos
spec parse-int : String -> [Result ParseError Int]
```


<a id="org3360345"></a>

## Use Dependent Types for Preconditions

```prologos
spec head : {A : Type} (xs : [List A]) -> {pf : [NonEmpty xs]} -> A
```


<a id="org0dec943"></a>

# Pipe and Composition


<a id="orgcc9eb99"></a>

## `|>` for Value Threading (Last Argument Position)

```prologos
|> @[1 2 3 4 5]
  pvec-filter even?
  pvec-map inc
  pvec-fold add 0
```

Default: value goes to last argument position. Use `_` for explicit placement: `|> x [f _ y]` threads `x` into the `_` position.


<a id="orgb244744"></a>

## `>>` for Function Composition (Left-to-Right)

```prologos
def process := >> parse validate transform serialize
```


<a id="org09c4f9b"></a>

## Block-Form `|>` Enables Loop Fusion

Consecutive `map~/~filter` steps in a block-form pipe fuse into a single pass when followed by a terminal (`fold`, `sum`, `reduce`).
