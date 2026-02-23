- [Guiding Principle: Disappearing Features](#org2ae1b81)
- [Surface Syntax Ergonomics](#org2c8fe12)
  - [Minimal Punctuation](#org0c38363)
  - [YAML-Like Data Literals](#org262f8a9)
  - [Dot-Access for Maps](#orge9fbfd6)
  - [Short Spec/Defn Pairs](#org191279d)
- [Type System Ergonomics](#org0b1890f)
  - [Inference Does the Heavy Lifting](#org796f85a)
  - [Trait Constraints Read Like English](#org0e6b396)
  - [Bundle Shortcuts](#org632e180)
  - [Nilable Types Are Lightweight](#orgeff26d3)
- [Collection Ergonomics](#org8fe8f99)
  - [Literal Syntax for All Collection Types](#org6b3af08)
  - [Range Syntax](#org6013a9f)
  - [Head | Tail Destructuring](#org12f8062)
- [Pipe Ergonomics](#org4987ee5)
  - [Left-to-Right Data Flow](#org36a349b)
  - [Block Form Enables Loop Fusion](#org209cdb2)
- [Error Message Ergonomics](#orga6c03be)
  - [Structured Error Codes](#org2690640)
  - [Contextual Suggestions](#org4495f4d)
  - [Human-Readable Type Display](#orgf17df48)
- [REPL Ergonomics](#org0571e6f)
  - [Interactive Exploration](#org36d3442)
  - [Implicit Eval](#orgae6e07f)
- [Editor Support](#org5ed3f3c)
  - [Emacs Integration (149 ERT tests)](#org1f7b730)
  - [Structural Editing](#orged560a5)



<a id="org2ae1b81"></a>

# Guiding Principle: Disappearing Features

The most important ergonomic principle in Prologos is *progressive disclosure*. Features should disappear until you need them. A beginner should be able to write:

```prologos
ns hello

defn greet [name]
  string-append "Hello, " name

[greet "world"]
```

&#x2026;and never encounter dependent types, session types, linear types, or logic programming until they choose to. The same language scales from this to formally verified protocols, but the complexity is opt-in.


<a id="org2c8fe12"></a>

# Surface Syntax Ergonomics


<a id="org0c38363"></a>

## Minimal Punctuation

Prologos requires far less punctuation than most typed languages:

| Feature         | Haskell   | Rust          | Prologos     |    |            |
|--------------- |--------- |------------- |------------ |--- |---------- |
| Function call   | `f x y`   | `f(x, y)`     | `f x y`      |    |            |
| Type annotation | `x :: T`  | `x: T`        | `x : T`      |    |            |
| Lambda          | `\x -> e` | ~\\           | x\\          | e~ | `fn [x] e` |
| Pattern match   | `case...` | `match...`    | `match...`   |    |            |
| Generic type    | `f :: a`  | `f<T>`        | `{A : Type}` |    |            |
| List literal    | `[1,2,3]` | `vec![1,2,3]` | `'[1 2 3]`   |    |            |

No commas between arguments. No semicolons. No curly braces for blocks. Whitespace and indentation do the work.


<a id="org262f8a9"></a>

## YAML-Like Data Literals

Keyword maps are the most common data structure. The implicit map syntax makes data entry feel natural:

```prologos
def user
  :name "Alice"
  :age 42
  :roles
    - :admin
    - :editor
  :preferences
    :theme "dark"
    :lang "en"
```

This is still homoiconic &#x2014; it desugars to an explicit map literal that can be quoted, transformed, and inspected.


<a id="orge9fbfd6"></a>

## Dot-Access for Maps

The most common operation on maps is field access. Dot syntax makes this feel like struct access in other languages:

```prologos
user.name          ;; => "Alice"
user.preferences   ;; => {:theme "dark" :lang "en"}

;; Chaining (deferred: Phase D)
;; user.preferences.theme  => "dark"

;; Piping with dot-key prefix
|> users
  filter [fn [u] [eq? u.role :admin]]
  map .:name
```


<a id="org191279d"></a>

## Short Spec/Defn Pairs

The spec/defn pattern keeps type signatures close to implementations without being verbose:

```prologos
spec clamp : Int Int Int -> Int
defn clamp [lo hi x]
  if [< x lo] lo [if [> x hi] hi x]
```

Two lines for the type, two lines for the definition. Implicit type parameters (`{A : Type}`) hide from call sites.


<a id="org0b1890f"></a>

# Type System Ergonomics


<a id="org796f85a"></a>

## Inference Does the Heavy Lifting

Most types are inferred. Users annotate only where they want to &#x2014; at module boundaries (`spec`), ambiguous call sites, and for documentation:

```prologos
;; Type inferred: List Int -> Int
defn sum-list
  | [nil]        -> 0
  | [[cons h t]] -> [+ h [sum-list t]]

;; Only needs spec if exported or if inference is ambiguous
spec sum-list : [List Int] -> Int
```


<a id="org0e6b396"></a>

## Trait Constraints Read Like English

```prologos
spec sort : {A : Type} where (Ord A) [List A] -> [List A]
;; "sort takes a list of any type A that has ordering, and returns a sorted list"

spec merge-maps : {K V : Type} where (Eq K) [Map K V] [Map K V] -> [Map K V]
;; "merge two maps where keys can be compared for equality"
```


<a id="org632e180"></a>

## Bundle Shortcuts

Bundles let users express common constraint combinations concisely:

```prologos
;; Instead of: where (Add A) (Sub A) (Mul A) (Neg A) (Abs A) (FromInt A) (Eq A) (Ord A)
spec mean : {A : Type} where (Num A) (Fractional A) [List A] -> A
```


<a id="orgeff26d3"></a>

## Nilable Types Are Lightweight

`A?` is less ceremony than `Option A` for the common case:

```prologos
spec lookup : Key -> A?              ;; vs. Key -> Option A
spec first : [List A] -> A?          ;; vs. List A -> Option A
spec find : [A -> Bool] [List A] -> A?
```


<a id="org8fe8f99"></a>

# Collection Ergonomics


<a id="org6b3af08"></a>

## Literal Syntax for All Collection Types

No builder functions needed for common cases:

```prologos
'[1N 2N 3N]           ;; List
@[1 2 3]              ;; PVec (persistent vector)
#{:a :b :c}           ;; Set
{:name "Ada" :age 36} ;; Map
~[1 2 3]              ;; Lazy sequence
```


<a id="org6013a9f"></a>

## Range Syntax

```prologos
'[1..5]                  ;; [1 2 3 4 5]
'[1..<5]                 ;; [1 2 3 4] (exclusive upper)
@[0..100 :by 10]         ;; [0 10 20 ... 100] (step)
~[1..]                   ;; infinite lazy range
~[1.. :where even?]      ;; infinite filtered range
~[1.. :while [< _ 100]]  ;; take-while
```


<a id="org12f8062"></a>

## Head | Tail Destructuring

Pattern matching works across all collection types:

```prologos
'[h | t]         ;; List: head and tail
'[a b | rest]    ;; List: first two, then rest
@[x | xs]        ;; PVec: first element, rest (O(log n))
{:name n | _}    ;; Map: extract :name, ignore rest
```


<a id="org4987ee5"></a>

# Pipe Ergonomics


<a id="org36a349b"></a>

## Left-to-Right Data Flow

`|>` threads data left-to-right, matching how humans read transformations:

```prologos
|> users
  filter [fn [u] [> u.age 18]]
  map .:name
  sort
  take 10
```

Compare the equivalent without pipe:

```prologos
[take 10 [sort [map .:name [filter [fn [u] [> u.age 18]] users]]]]
```


<a id="org209cdb2"></a>

## Block Form Enables Loop Fusion

The block form of `|>` is not just syntactic sugar &#x2014; consecutive map/filter operations automatically fuse into a single pass:

```prologos
;; This runs in O(n), not O(3n):
|> @[1 2 3 4 5]
  map inc
  filter even?
  sum
```


<a id="orga6c03be"></a>

# Error Message Ergonomics


<a id="org2690640"></a>

## Structured Error Codes

Every error has a searchable code:

| Code  | Category                                |
|----- |--------------------------------------- |
| E1001 | Implicit argument inference failure     |
| E1002 | Constraint postponement (unsolved meta) |
| E1003 | QTT linearity violation                 |
| E2xxx | Session type errors (future)            |
| E3xxx | Logic programming errors (future)       |


<a id="org4495f4d"></a>

## Contextual Suggestions

Errors suggest fixes when mechanically derivable:

-   Type mismatch: show expected vs. actual, suggest coercion if available
-   Unbound variable: suggest similarly-named bindings (Jaro distance)
-   Missing trait instance: list available instances, suggest `impl`
-   Linear variable reused: show both use sites, suggest `:w`


<a id="orgf17df48"></a>

## Human-Readable Type Display

Types are printed in surface syntax, not internal representation:

```
;; Good: surface syntax
Expected: <(n : Nat) -> Vec String n>
Actual:   <(n : Nat) -> Vec Int n>

;; Bad: internal representation (never shown to user)
Expected: (expr-Pi 'n (expr-Nat) (expr-app (expr-app (expr-fvar 'Vec) ...)))
```


<a id="org0571e6f"></a>

# REPL Ergonomics


<a id="org36d3442"></a>

## Interactive Exploration

The REPL supports both WS-mode and sexp-mode input. Key features:

-   `(infer expr)` &#x2014; show the inferred type of an expression
-   `(check expr : Type)` &#x2014; verify that an expression has a type
-   `(eval expr)` &#x2014; evaluate and print result
-   Top-level `defn~/~def~/~spec` persist across REPL interactions
-   `ns` switching for namespace exploration


<a id="orgae6e07f"></a>

## Implicit Eval

Bare expressions at the top level are implicitly evaluated:

```prologos
[add 2 3]    ;; => 5 : Nat (no explicit "eval" needed)
```


<a id="org5ed3f3c"></a>

# Editor Support


<a id="org1f7b730"></a>

## Emacs Integration (149 ERT tests)

Four Emacs packages provide:

-   Syntax highlighting (font-lock)
-   Indentation (SMIE-based)
-   REPL integration (comint)
-   Surfer mode for interactive development


<a id="orged560a5"></a>

## Structural Editing

The homoiconic AST makes structural editing natural:

-   Slurp/barf brackets
-   Wrap/unwrap expressions
-   Navigate by AST node, not by character
