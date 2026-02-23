- [Executive Summary](#org425597b)
  - [Design Principles](#org01f173e)
- [Part I: Research Survey](#org250ee33)
  - [1. Agda — Full Mixfix with DAG Precedence](#org78110fd)
    - [Agda Standard Library Convention (Haskell-like)](#orgd556a3b)
    - [Key Lessons from Agda](#org547dc46)
  - [2. Maude — Mixfix with Gather Patterns](#orge2a61f1)
    - [Maude Standard Precedence Table](#org0318127)
    - [Key Lessons from Maude](#orgf7d0cb2)
  - [3. Prolog — User-Defined Operators with Type Specifiers](#org7e3939c)
    - [ISO Standard Operator Table](#org4b79cd2)
    - [Key Lessons from Prolog](#orgc496b77)
  - [4. Haskell — Explicit Numeric Precedence (0-9)](#org4ef43bb)
    - [Key Lessons from Haskell](#orgfeeca03)
  - [5. Swift — Named Precedence Groups (Partial Order DAG)](#org7239d71)
    - [Standard Precedence Groups](#org2277a79)
    - [Key Lessons from Swift](#org5927203)
  - [6. Scala & OCaml — First-Character-Based Precedence](#org864588d)
    - [Key Lessons](#org269b49a)
  - [7. Tcl `expr` — Infix Sublanguage in a Homoiconic Host](#orgb6f9b44)
    - [Key Lessons from Tcl](#orgfb8738c)
  - [8. Racket (Our Host) — SRFI-105, k-infix, Rhombus/Enforest](#org1e27e10)
    - [SRFI-105 Curly-Infix](#orgc2adf88)
    - [k-infix (Racket Package)](#org1793dec)
    - [Rhombus Enforest (Most Relevant)](#org088df25)
  - [9. Julia — Homoiconic with Native Infix](#org7556bd2)
    - [Key Lessons from Julia](#org553c078)
- [Part II: Design Patterns & Gotchas](#org174755f)
  - [The Classic C Precedence Bug](#orgfc8e67d)
  - [Few Levels vs Many Levels](#orga4ec3ca)
  - [The Precedence Interaction Problem](#org6d4aeb0)
  - [Pratt Parsing / Precedence Climbing](#org11efc7c)
- [Part III: Prologos Integration Analysis](#org5a2afbd)
  - [Current Infrastructure](#orgfa4f1df)
  - [Existing Partial Application Machinery](#org820030a)
  - [Spec Entry System](#org5be1a85)
  - [Reader Integration](#org6bc467e)
- [Part IV: Design Proposal](#org217c2fb)
  - [1. Surface Syntax: `.{...}`](#orga03f0f3)
    - [Nesting with `[]` for Prefix Calls Inside Mixfix](#orgd10f70d)
    - [Equivalence with Prefix](#org340936a)
  - [2. Named Precedence Groups (Swift/Rhombus Model)](#org0979c0c)
    - [Built-in Groups](#org89d76f0)
    - [The Chain: `composition > exponentiation > multiplicative > additive > comparison > logical-and > logical-or > pipe`](#org1c8e67e)
  - [3. `:mixfix` Key on `spec`](#org4dc88f6)
    - [`:mixfix` Map Keys](#org114c2ca)
  - [4. User-Defined Precedence Groups](#org9993783)
  - [5. Standard Operator Table](#org7313319)
    - [Arithmetic (via trait-dispatched generic operators)](#org74182da)
    - [Comparison](#org562c496)
    - [Logical](#org01f7598)
    - [Pipeline](#org7b0d44a)
    - [Cons / Append](#orgebb35e0)
  - [6. Chained Comparisons (Julia-inspired)](#orgbd0fc7b)
  - [7. Parsing Algorithm](#orgcf5d310)
    - [Binding Power Encoding](#org94a48b5)
  - [8. Sexp Mode Equivalent](#org70583ca)
- [Part V: Implementation Phases](#org3ad681d)
  - [Phase 1: Core Reader & Parser (Minimum Viable)](#org8a63ac1)
  - [Phase 2: `:mixfix` on `spec` + User Groups](#orga4e7c35)
  - [Phase 3: Chained Comparisons + Diagnostics](#orgb570498)
  - [Phase 4: Advanced Features (Future)](#org95b39e4)
- [Part VI: Design Decisions & Tradeoffs](#org40d17f4)
  - [Decision 1: Named Groups vs Numeric Levels](#org7291c5e)
  - [Decision 2: `.{...}` Delimiters vs. No Delimiters](#orgf73a9c2)
  - [Decision 3: Partial Application via `_`](#orgd93d45b)
  - [Decision 4: Comparison Chaining](#org983e7c2)
  - [Decision 5: Bitwise Operators](#org9c0cd2c)
- [Part VII: Open Questions](#org4b57a0c)
- [References](#org277af47)
  - [Academic Papers](#orgd210cb3)
  - [Language Documentation](#org0b3377c)
  - [Blog Posts & Practical Guides](#org76a4a2c)



<a id="org425597b"></a>

# Executive Summary

Prologos is a homoiconic language with prefix notation as the default: `[f x y]`, `(fn ...)`. This document designs a **lightweight mixfix sublanguage** invoked via `.{...}` delimiters, enabling natural infix arithmetic (`.{a + b * c}`) while preserving homoiconicity. The design also covers user-definable operator precedence via a `:mixfix` key on `spec`, and a standard precedence table for library operators.

The key insight: `.{...}` is syntactic sugar that desugars to prefix s-expressions at the preparse stage. The canonical data representation is always prefix. This is analogous to how our WS-mode syntax desugars to sexp forms &#x2013; the infix is a **reading convenience**, not a semantic layer.


<a id="org01f173e"></a>

## Design Principles

1.  **Homoiconicity preserved**: `.{a + b}` desugars to `[add a b]` (or the trait-dispatched generic form). The datum representation is always prefix.
2.  **Wildcard partial application**: `.{_ + 1}` desugars to `(fn [$_0] [add $_0 1])`, reusing the existing placeholder machinery.
3.  **User-definable precedence**: via `:mixfix` metadata key on `spec`, using named precedence groups (Swift/Rhombus model).
4.  **Standard library uses the same system**: `+`, `*`, `<` etc. are defined with `:mixfix` metadata, not hard-coded.
5.  **Reject on ambiguity**: if two operators have no declared precedence relationship, `.{...}` containing both is a compile error requiring explicit grouping.


<a id="org250ee33"></a>

# Part I: Research Survey


<a id="org78110fd"></a>

## 1. Agda — Full Mixfix with DAG Precedence

Agda has **no built-in operators**. Every operator is user-defined using underscores as argument slots:

| Pattern         | Kind      | Example              |
|--------------- |--------- |-------------------- |
| `_+_`           | infix     | `1 + 2`              |
| `-_`            | prefix    | `- x`                |
| `_!`            | postfix   | `n !`                |
| `if_then_else_` | mixfix    | `if b then x else y` |
| `[_]`           | circumfix | `[ x ]`              |

Precedence is declared via `infixl N`, `infixr N`, `infix N` where N is any number (including fractions and negatives). Default is 20. The precedence relation forms a **DAG** &#x2013; two operators at the same level are **unrelated** unless they share associativity, making their combination ambiguous (parse error).


<a id="orgd556a3b"></a>

### Agda Standard Library Convention (Haskell-like)

| Level | Assoc    | Operators                  |
|----- |-------- |-------------------------- |
| -1    | `infixr` | `$` (function application) |
| 0     | `infixl` | `\vert>` (pipe)            |
| 4     | `infix`  | `=`, `<=`, `<`, `>=`, `>`  |
| 5     | `infixr` | `\lor`, `xor`, `::` (cons) |
| 6     | `infixl` | `+`, `-`, `\land`          |
| 7     | `infixl` | `*`                        |
| 8     | `infixr` | `^` (exponentiation)       |
| 9     | `infixr` | `.` (composition)          |


<a id="org547dc46"></a>

### Key Lessons from Agda

-   **Strength**: Maximum expressiveness; `if_then_else_` is user-definable.
-   **Weakness**: Parsing and scope-checking are entangled. Missing imports produce confusing parse errors instead of "not in scope" errors.
-   **Weakness**: No cross-library precedence coordination. Different projects use incompatible level schemes.
-   **Weakness**: Error messages for mixfix parse failures are notoriously unhelpful.
-   **Paper**: Danielsson & Norell, "Parsing Mixfix Operators" (IFL 2008) &#x2013; the foundational algorithm.


<a id="orge2a61f1"></a>

## 2. Maude — Mixfix with Gather Patterns

Maude uses the same underscore-for-argument notation, but with a unique **gather pattern** system for associativity:

```
op _+_ : Nat Nat -> Nat [prec 33 gather (E e)] .
op _*_ : Nat Nat -> Nat [prec 31 gather (E e)] .
```

| Symbol | Meaning                                              |
|------ |---------------------------------------------------- |
| `e`    | Argument top-op precedence must be **strictly less** |
| `E`    | Argument top-op precedence must be **less or equal** |
| `&`    | Any precedence accepted                              |

Left-associativity = `gather (E e)`: left arg can be same-precedence, right cannot. Right-associativity = `gather (e E)`. Non-associative = `gather (e e)`.

Precedence is numeric, lower = tighter (0-127 by convention). **Opposite direction from Prolog/Haskell**.


<a id="org0318127"></a>

### Maude Standard Precedence Table

| Prec | Operators            | Notes          |
|---- |-------------------- |-------------- |
| 29   | `^`                  | Exponentiation |
| 31   | `*`, `quo`, `rem`    | Multiplicative |
| 33   | `+`                  | Additive       |
| 37   | `<`, `>`, `>=`, `>=` | Comparison     |
| 51   | `==`, `=/=`          | Equality       |
| 53   | `not`                | Boolean NOT    |
| 55   | `and`                | Boolean AND    |
| 57   | `xor`                | Boolean XOR    |
| 59   | `or`                 | Boolean OR     |
| 61   | `implies`            | Implication    |


<a id="orgf7d0cb2"></a>

### Key Lessons from Maude

-   **Strength**: `gather` patterns are more expressive than simple left/right associativity &#x2013; each argument position has independent control.
-   **Weakness**: Default `gather (E E)` is ambiguous for binary operators &#x2013; you *must* declare explicitly.
-   **Weakness**: Ambiguous parses are resolved **silently by arbitrary choice** with only a warning. This is a foot-gun.
-   **Gotcha**: The juxtaposition operator (`__` for list concatenation) interacts badly with infix operators.


<a id="org7e3939c"></a>

## 3. Prolog — User-Defined Operators with Type Specifiers

Prolog operators are purely syntactic sugar declared via `op(Precedence, Type, Name)`:

| Specifier | Kind    | Associativity   | Meaning                            |
|--------- |------- |--------------- |---------------------------------- |
| `xfx`     | infix   | non-associative | Both args strictly lower           |
| `xfy`     | infix   | right-assoc     | Left strict, right can be equal    |
| `yfx`     | infix   | left-assoc      | Left can be equal, right strict    |
| `fx`      | prefix  | non-assoc       | Arg strictly lower                 |
| `fy`      | prefix  | right-assoc     | Arg can be equal (allows chaining) |
| `xf`      | postfix | non-assoc       | Arg strictly lower                 |
| `yf`      | postfix | left-assoc      | Arg can be equal                   |

Precedence range is 1-1200 (higher = looser, opposite of Maude). The `x` vs `y` convention encodes the same idea as Maude's `e` vs `E`: strict-less-than vs less-or-equal.


<a id="org4b79cd2"></a>

### ISO Standard Operator Table

| Prec | Type  | Operators                                    |
|---- |----- |-------------------------------------------- |
| 1200 | `xfx` | `:-`, `-->`                                  |
| 1100 | `xfy` | `;`                                          |
| 1050 | `xfy` | `->`                                         |
| 1000 | `xfy` | `,`                                          |
| 900  | `fy`  | `\+`                                         |
| 700  | `xfx` | `=`, `\=`, `===`, `is`, `<`, `>`, `=<`, `>=` |
| 500  | `yfx` | `+`, `-`, `/\`, `\/`                         |
| 400  | `yfx` | `*`, `/`, `//`, `rem`, `mod`                 |
| 200  | `xfx` | `**`                                         |
| 200  | `fy`  | `-`, `+`, `\`                                |


<a id="orgc496b77"></a>

### Key Lessons from Prolog

-   **Strength**: 1200 levels means you never run out of room to insert new operators.
-   **Weakness**: Cognitive overload &#x2013; nobody memorizes which standard operators are at 500 vs 700.
-   **Weakness**: Global mutable operator table. Any loaded file can change how subsequent code is parsed.
-   **Weakness**: No module scoping by default (SWI-Prolog adds module-local operators).
-   **Gotcha**: `op/3` is purely syntactic &#x2013; it defines notation, not semantics.


<a id="org4ef43bb"></a>

## 4. Haskell — Explicit Numeric Precedence (0-9)

```
infixl 6 +, -
infixl 7 *, /
infixr 5 :, ++
infix  4 ==, /=, <, <=, >, >=
infixr 3 &&
infixr 2 ||
infixr 0 $
```

Function application (whitespace) is at an implicit level 10, always tightest. Backtick syntax (`` `div` ``) lets any function be used infix.


<a id="orgfeeca03"></a>

### Key Lessons from Haskell

-   **Strength**: Simple, well-understood, works well in practice for a standard library.
-   **Weakness**: Only 10 levels. Libraries compete for scarce slots. Re-exports and wrappers silently lose fixity.
-   **Weakness**: Fixity is not part of the type signature &#x2013; it is "secret" metadata.
-   **Gotcha**: The `$` operator required a hard-coded special typing rule in GHC for years due to impredicativity.
-   **Gotcha**: Two operators at the same level with different associativity produce a parse error, not a predictable result.


<a id="org7239d71"></a>

## 5. Swift — Named Precedence Groups (Partial Order DAG)

Swift (since SE-0077) uses **named precedence groups** forming a DAG via `higherThan` / `lowerThan`:

```swift
precedencegroup ExponentiationPrecedence {
    higherThan: MultiplicationPrecedence
    associativity: right
}
infix operator ** : ExponentiationPrecedence
```


<a id="org2277a79"></a>

### Standard Precedence Groups

| Group                        | Assoc | Operators               | Higher Than        |
|---------------------------- |----- |----------------------- |------------------ |
| BitwiseShiftPrecedence       | none  | `<<`, `>>`              | Multiplication     |
| MultiplicationPrecedence     | left  | `*`, `/`, `%`, `&`      | Addition           |
| AdditionPrecedence           | left  | `+`, `-`, `\vert`, `^`  | RangeFormation     |
| RangeFormationPrecedence     | none  | `...`, `..<=`           | Casting            |
| ComparisonPrecedence         | none  | `<`, `>=`, `===`, `!==` | LogicalConjunction |
| LogicalConjunctionPrecedence | left  | `&&`                    | LogicalDisjunction |
| LogicalDisjunctionPrecedence | left  | `\vert\vert`            | Ternary            |
| TernaryPrecedence            | right | `? :`                   | Assignment         |
| AssignmentPrecedence         | right | `=`, `+`, etc.          | FunctionArrow      |


<a id="org5927203"></a>

### Key Lessons from Swift

-   **Strength**: Partial order means unrelated operators are **not** silently ordered. Mixing them without parens is a compile error. This eliminates the entire class of precedence bugs.
-   **Strength**: `lowerThan` can reference groups from other modules &#x2013; allows inserting new levels below imported groups without modifying them.
-   **Strength**: Transitivity is checked; cycles are forbidden.
-   **Weakness**: More verbose to declare than numeric levels.
-   **This is the emerging consensus for new language design** (also adopted by Carbon, Fortress, Rhombus).


<a id="org864588d"></a>

## 6. Scala & OCaml — First-Character-Based Precedence

Both determine precedence entirely from the operator's **first character**:

| Priority | First Char(s) | Scala Examples        | OCaml Level |
|-------- |------------- |--------------------- |----------- |
| Lowest   | letters, `$`  | `max`, `to`           | --          |
| &#x2026; | `\vert`       | `\vert`, `\vert\vert` | Level 0     |
|          | `^`           | `^`, `^^`             | Level 1     |
|          | `&`           | `&`, `&&`             | --          |
|          | `=`, `!`      | `==`, `!=`            | Level 0     |
|          | `<`, `>`      | `<`, `>=`             | Level 0     |
|          | `:`           | `:`, `::`             | --          |
|          | `+`, `-`      | `+`, `-`, `++`        | Level 2     |
|          | `*`, `/`, `%` | `*`, `/`              | Level 3     |
| Highest  | other special | `?`, `~`              | Level 4     |

Scala: last character `:` makes it right-associative. OCaml: `**` prefix makes it right-associative.


<a id="org269b49a"></a>

### Key Lessons

-   **Strength**: Zero ceremony &#x2013; precedence just works for conventional operator names. No declarations needed.
-   **Weakness**: No customization. If your DSL operator starts with `+`, it gets addition-level precedence whether you want it or not.
-   **Not suitable for Prologos**: We want user-definable precedence, and our operators are words (`add`, `mul`) not symbols.


<a id="orgb6f9b44"></a>

## 7. Tcl `expr` — Infix Sublanguage in a Homoiconic Host

Tcl is command-based (like Prologos is prefix-based). The `expr` command provides a C-like infix sublanguage:

```
set result [expr {3 + 4 * 5}]    ;# => 23
if {$x > 0 && $y < 10} { ... }   ;# expr in condition
```


<a id="orgfb8738c"></a>

### Key Lessons from Tcl

-   **Bracing matters enormously**: `expr {$x + $y}` is ~9x faster than `expr $x + $y` because the braced form can be bytecode-compiled and cached. The unbraced form forces string concatenation + re-parse every time.
-   **Security**: Unbraced `expr $userinput` is a code injection vector.
-   **The sublanguage approach works**: Tcl demonstrates that a host language with uniform syntax (`command arg arg`) can successfully embed an infix sublanguage for arithmetic. The key is clear delimiters (braces in Tcl, `.{...}` in our case).
-   **Cognitive load**: Users must know two grammars. Minimizing the delta between them helps.


<a id="org1e27e10"></a>

## 8. Racket (Our Host) — SRFI-105, k-infix, Rhombus/Enforest


<a id="orgc2adf88"></a>

### SRFI-105 Curly-Infix

Deliberately minimal: `{a + b}` -> `(+ a b)`. Same operator folds: `{a + b + c}` -> `(+ a b c)`. Mixed operators: `{a + b * c}` -> `($nfx$ a + b * c)` &#x2013; deliberately **no** precedence at the reader level.


<a id="org1793dec"></a>

### k-infix (Racket Package)

Full Pratt-style parser with configurable precedence table:

```
($ 3 + 4 * 5)        ;; => 23
($ sin(x) + cos(y))  ;; => (+ (sin x) (cos y))
```


<a id="org088df25"></a>

### Rhombus Enforest (Most Relevant)

Rhombus (Racket's new surface language) uses **relative precedence declarations** that are:

-   **Not transitive**: `A > B` and `B > C` does NOT imply `A > C`
-   **Partial**: Two operators have a relationship only if explicitly declared
-   **Ambiguity = error**: No relationship between adjacent operators requires parentheses

```rhombus
operator (x <> y):
  ~weaker_than: * / + -
  Posn(x, y)
```

Declaration keywords: `~weaker_than`, `~stronger_than`, `~same_as`, `~same_as_on_left`, `~same_as_on_right`, `~associativity`.

This is the closest prior art to what we want for Prologos.


<a id="org7556bd2"></a>

## 9. Julia — Homoiconic with Native Infix

Julia is the most interesting case: a **homoiconic** language where infix is the **primary** surface form. Internally, `1 + 2 * 3` produces the AST `Expr(:call, :+, 1, Expr(:call, :*, 2, 3))` &#x2013; the same prefix tree a Lisp would produce.

Precedence is determined by Unicode character class (`+`-like at `prec-plus`, `*`-like at `prec-times`, etc.). Users **cannot** redefine precedence &#x2013; only define methods for existing operator symbols.

Julia also supports **chained comparisons**: `a < b <` c= desugars to `(a < b) && (b <` c)= with `b` evaluated only once. This is a popular ergonomic feature.


<a id="org553c078"></a>

### Key Lessons from Julia

-   **Proof that homoiconicity and infix coexist**: Julia's `Expr` type is manipulable code-as-data, just with infix surface syntax. Quote (`:(1 + 2)`) produces prefix trees.
-   **Character-class precedence is limiting**: Users cannot make a `+`-like symbol bind tighter than `*`. Open design issues since 2016.
-   **Chained comparisons are popular**: Worth considering for Prologos (`.{a < b <` c}=).


<a id="org174755f"></a>

# Part II: Design Patterns & Gotchas


<a id="orgfc8e67d"></a>

## The Classic C Precedence Bug

C's bitwise operators (`&`, `|`, `^`) have **lower** precedence than comparison (`==`, `<`). This was because originally there were no `&&` / `||`; bitwise operators served double duty. When logical operators were added, the bitwise precedence was not corrected. Dennis Ritchie later acknowledged this as a mistake.

Result: `if (x & mask =` 0)= parses as `if (x & (mask =` 0))=, not `if ((x & mask) =` 0)=.

This bug propagated to C++, Java, JavaScript, C#, and PHP. Only Swift, Go, Ruby, and Python get it right.

**Lesson for Prologos**: Do NOT define precedence between bitwise and comparison operators. Leave them unrelated; force parentheses.


<a id="orga4ec3ca"></a>

## Few Levels vs Many Levels

| Approach          | Levels | Languages               | Problem                      |
|----------------- |------ |----------------------- |---------------------------- |
| Few numeric       | 10     | Haskell                 | Slot scarcity, collisions    |
| Many numeric      | 1200   | Prolog                  | Cognitive overload           |
| Named groups      | DAG    | Swift, Carbon, Fortress | Verbose, but compositional   |
| Character-derived | ~10    | Scala, OCaml            | Inflexible, no customization |
| None              | 1      | Smalltalk, APL, Pony    | Violates math intuition      |

**Emerging consensus**: Named groups forming a partial order (Swift model) is the sweet spot for new languages.


<a id="org6d4aeb0"></a>

## The Precedence Interaction Problem

When combining libraries with different operator definitions:

-   Haskell: Only 10 slots, so libraries compete. Wrappers silently lose fixity.
-   Prolog: 1200 levels prevent collision but nobody memorizes the numbers.
-   Swift/Rhombus: Operators from different libraries have **no** relationship by default. Combining them requires explicit parentheses &#x2013; which is the **correct** behavior.


<a id="org11efc7c"></a>

## Pratt Parsing / Precedence Climbing

Pratt parsing (1973) and precedence climbing (1986) are the **same algorithm**. The key idea: each operator has a left binding power and right binding power. The algorithm recurses, stopping when it encounters an operator with binding power weaker than the current threshold.

**Associativity via asymmetric binding powers**:

-   Left-assoc: `right_bp = left_bp + 1` (right side slightly tighter, forces left-leaning tree)
-   Right-assoc: `right_bp = left_bp` (right side same, allows right-leaning tree)
-   Non-assoc: Same as left, but check for chaining and error

Adapts cleanly to partial orders by adding: if binding powers are **incomparable**, produce an error.


<a id="org5a2afbd"></a>

# Part III: Prologos Integration Analysis


<a id="orgfa4f1df"></a>

## Current Infrastructure

The preparse pipeline in `macros.rkt` already handles several syntactic transforms in order:

1.  **Implicit map rewriting** — indentation-based keyword blocks to map literals
2.  **Dot-access rewriting** — `user.name` -> `[map-get user :name]`
3.  **Infix operator rewriting** — `|>` and `>>` rewriting to block form
4.  **Macro expansion** — registered preparse macros (`let`, `do`, `if`, `with-transient`, etc.)
5.  **Placeholder desugaring** — `_` in application args -> anonymous lambda

The `.{...}` form would be handled at a new **step 0** or integrated into step 3, before macro expansion.


<a id="org820030a"></a>

## Existing Partial Application Machinery

Placeholders already work in application context:

-   `[add 1 _]` -> `(fn [$_0] [add 1 $_0])`
-   `[clamp _ 100 _]` -> `(fn [$_0] (fn [$_1] [clamp $_0 100 $_1]))`
-   Numbered: `[f _2 zero _1]` -> `(fn [$_1] (fn [$_2] [f $_2 zero $_1]))`

The `.{...}` form should reuse this: `.{_ + 1}` desugars to `[add _ 1]` which then hits the existing placeholder machinery.


<a id="org5be1a85"></a>

## Spec Entry System

`spec-entry` already stores metadata including `:where` constraints, `:implicits`, `:doc`, `:examples`, `:properties`. Adding `:mixfix` as another metadata key is straightforward:

```
spec add [A A] -> A
  :implicits {A : Type}
  :where (Add A)
  :mixfix {:symbol + :group additive :assoc :left}
```


<a id="org6bc467e"></a>

## Reader Integration

The `.{...}` delimiter needs reader-level support. Options:

1.  **Readtable extension**: Map `.` followed by `{` to a reader procedure that collects until matching `}` and produces a tagged datum (e.g., `($mixfix a + b * c)`).
2.  **Preparse rewrite**: If the sexp reader already produces `.` and `{...}` as separate tokens, the preparse layer can detect the pattern.

Option 1 is cleaner &#x2013; a single read produces the `($mixfix ...)` datum, which then enters the preparse pipeline for precedence resolution.


<a id="org217c2fb"></a>

# Part IV: Design Proposal


<a id="orga03f0f3"></a>

## 1. Surface Syntax: `.{...}`

The `.{...}` delimiter activates mixfix mode. Inside, operators are parsed with precedence:

```
.{a + b}           ;; => [add a b]        (or generic [+ a b])
.{a + b * c}       ;; => [add a [mul b c]]
.{a < b && c > d}  ;; => [and [lt a b] [gt c d]]
.{_ + 1}           ;; => (fn [$_0] [add $_0 1])
.{xs |> map f}     ;; => [map f xs]       (reuses pipe semantics)
```


<a id="orgd10f70d"></a>

### Nesting with `[]` for Prefix Calls Inside Mixfix

```
.{[length xs] + [length ys]}    ;; prefix calls inside mixfix
.{[f x] * [g y] + [h z]}       ;; clear grouping
```

This preserves prefix for function application while gaining infix for operators. `[]` inside `.{...}` is an **escape to prefix** &#x2013; the inverse of how `.{...}` is an escape to infix.


<a id="org340936a"></a>

### Equivalence with Prefix

| Mixfix              | Prefix                    |
|------------------- |------------------------- |
| `.{a + b}`          | `[add a b]`               |
| `.{a + b * c}`      | `[add a [mul b c]]`       |
| `.{_ * _}`          | `[mul _ _]`               |
| `map .{_ + 1} xs`   | `map [add _ 1] xs`        |
| `.{a < b && b < c}` | `[and [lt a b] [lt b c]]` |


<a id="org0979c0c"></a>

## 2. Named Precedence Groups (Swift/Rhombus Model)

We adopt **named precedence groups forming a partial order DAG**, not numeric levels.


<a id="org89d76f0"></a>

### Built-in Groups

```
;; Defined in the Prologos core, not user-modifiable

precedence-group composition
  :assoc :right

precedence-group exponentiation
  :assoc :right
  :tighter-than multiplicative

precedence-group multiplicative
  :assoc :left
  :tighter-than additive

precedence-group additive
  :assoc :left
  :tighter-than comparison

precedence-group comparison
  :assoc :none
  :tighter-than logical-and

precedence-group logical-and
  :assoc :left
  :tighter-than logical-or

precedence-group logical-or
  :assoc :left
  :tighter-than pipe

precedence-group pipe
  :assoc :left
```

Note: **bitwise operators have NO relationship to comparison**. This avoids the C precedence bug entirely. Using bitwise and comparison operators together in `.{...}` requires explicit grouping.


<a id="org1c8e67e"></a>

### The Chain: `composition > exponentiation > multiplicative > additive > comparison > logical-and > logical-or > pipe`

This matches universal mathematical convention and the consensus across Haskell, Swift, Julia, and Prolog.


<a id="org4dc88f6"></a>

## 3. `:mixfix` Key on `spec`

Operators are registered via the `:mixfix` metadata key on `spec`:

```
;; Library definition of +
spec add [A A] -> A
  :implicits {A : Type}
  :where (Add A)
  :mixfix {:symbol + :group additive}

;; Library definition of *
spec mul [A A] -> A
  :implicits {A : Type}
  :where (Mul A)
  :mixfix {:symbol * :group multiplicative}

;; Library definition of ==
spec eq? [A A] -> Bool
  :implicits {A : Type}
  :where (Eq A)
  :mixfix {:symbol == :group comparison}

;; Unary prefix
spec neg [A] -> A
  :implicits {A : Type}
  :where (Neg A)
  :mixfix {:symbol - :kind :prefix :group unary}

;; User-defined operator
spec cross-product [Vec3 Vec3] -> Vec3
  :mixfix {:symbol cross :group multiplicative}
```


<a id="org114c2ca"></a>

### `:mixfix` Map Keys

| Key       | Type    | Default    | Description                        |
|--------- |------- |---------- |---------------------------------- |
| `:symbol` | Symbol  | (required) | The infix symbol used in `.{...}`  |
| `:group`  | Symbol  | (required) | Name of the precedence group       |
| `:kind`   | Keyword | `:infix`   | `:infix`, `:prefix`, or `:postfix` |
| `:assoc`  | Keyword | from group | Override group associativity       |

Associativity is typically inherited from the group. Override is for exceptional cases only.


<a id="org9993783"></a>

## 4. User-Defined Precedence Groups

Users can define new groups and insert them into the DAG:

```
precedence-group tensor-product
  :assoc :left
  :tighter-than additive
  :looser-than multiplicative

spec tensor [Tensor A Tensor A] -> [Tensor A]
  :implicits {A : Type}
  :mixfix {:symbol (x) :group tensor-product}
```

Rules:

-   `:tighter-than` and `:looser-than` reference existing groups.
-   Cycles in the DAG are a compile error.
-   Groups from different modules with no declared relationship are **unrelated** &#x2013; mixing their operators in `.{...}` requires explicit grouping.
-   Groups declared in library modules are imported with the module. The DAG is composed by union of edges across imports.


<a id="org7313319"></a>

## 5. Standard Operator Table


<a id="org74182da"></a>

### Arithmetic (via trait-dispatched generic operators)

| Symbol | Function | Group          | Assoc  | Trait |
|------ |-------- |-------------- |------ |----- |
| `+`    | `add`    | additive       | left   | `Add` |
| `-`    | `sub`    | additive       | left   | `Sub` |
| `*`    | `mul`    | multiplicative | left   | `Mul` |
| `/`    | `div`    | multiplicative | left   | `Div` |
| `%`    | `mod`    | multiplicative | left   | `Mod` |
| `^`    | `pow`    | exponentiation | right  | `Pow` |
| `-`    | `neg`    | unary          | prefix | `Neg` |


<a id="org562c496"></a>

### Comparison

| Symbol | Function | Group      | Assoc | Trait |
|------ |-------- |---------- |----- |----- |
| `==`   | `eq?`    | comparison | none  | `Eq`  |
| `!=`   | `neq?`   | comparison | none  | `Eq`  |
| `<`    | `lt?`    | comparison | none  | `Ord` |
| `<=`   | `le?`    | comparison | none  | `Ord` |
| `>`    | `gt?`    | comparison | none  | `Ord` |
| `>=`   | `ge?`    | comparison | none  | `Ord` |


<a id="org01f7598"></a>

### Logical

| Symbol       | Function | Group       | Assoc  |
|------------ |-------- |----------- |------ |
| `&&`         | `and`    | logical-and | left   |
| `\vert\vert` | `or`     | logical-or  | left   |
| `!`          | `not`    | unary       | prefix |


<a id="org7b0d44a"></a>

### Pipeline

| Symbol   | Function   | Group       | Assoc |
|-------- |---------- |----------- |----- |
| `\vert>` | pipe       | pipe        | left  |
| `>>`     | compose    | composition | right |
| `.`      | dot-access | (special)   | left  |


<a id="orgebb35e0"></a>

### Cons / Append

| Symbol | Function | Group    | Assoc |
|------ |-------- |-------- |----- |
| `::`   | `cons`   | cons     | right |
| `++`   | `append` | additive | left  |


<a id="orgbd0fc7b"></a>

## 6. Chained Comparisons (Julia-inspired)

Inside `.{...}`, consecutive comparison operators are desugared with short-circuit:

```
.{a < b <= c}
;; => [and [lt a b] [le b c]]    (with b evaluated once)

.{0 < x < 100}
;; => [and [lt 0 x] [lt x 100]]
```

Comparison operators are **non-associative** in isolation (`.{a < b < c}` is not `.{(a < b) < c}`). Instead, consecutive comparisons trigger the chained desugaring, which is a special preparse rule.


<a id="orgcf5d310"></a>

## 7. Parsing Algorithm

The `.{...}` parser uses **Pratt parsing** adapted for partial-order precedence:

1.  Reader produces `($mixfix token1 token2 ...)` datum from `.{...}` syntax.
2.  Preparse stage runs the Pratt parser on the token list.
3.  Each operator's binding power is looked up from `spec-entry` `:mixfix` metadata.
4.  If two adjacent operators have **no** precedence relationship (incomparable in the DAG), emit a compile error: "Operators `X` and `Y` have no defined precedence relationship &#x2013; use explicit grouping."
5.  Output is a standard prefix datum: `[add a [mul b c]]`.
6.  Wildcards (`_`) in the output are handled by the existing placeholder machinery.


<a id="org94a48b5"></a>

### Binding Power Encoding

Each named group gets a pair of binding powers `(left_bp, right_bp)` derived from the DAG topology:

-   Groups are topologically sorted.
-   `left_bp` is assigned based on position in topological order.
-   `right_bp = left_bp + 1` for left-associative, `left_bp` for right-associative.
-   Groups with no relationship have **incomparable** binding powers (not just equal &#x2013; distinct so the parser can detect and error).


<a id="org70583ca"></a>

## 8. Sexp Mode Equivalent

In sexp mode, `.{...}` has a direct equivalent:

```
;; WS mode:
.{a + b * c}

;; Sexp mode:
($mixfix a + b * c)
```

The `$mixfix` head triggers the same Pratt parser in the preparse stage.


<a id="org3ad681d"></a>

# Part V: Implementation Phases


<a id="org8a63ac1"></a>

## Phase 1: Core Reader & Parser (Minimum Viable)

-   Add `.{` reader syntax producing `($mixfix ...)` datum
-   Implement Pratt parser in `macros.rkt` with **fixed** precedence table (no user-definable yet)
-   Standard table: arithmetic, comparison, logical, pipe
-   Wildcard support via existing placeholder machinery
-   Tests: arithmetic expressions, comparison, logical, wildcards, nesting with `[]`


<a id="orga4e7c35"></a>

## Phase 2: `:mixfix` on `spec` + User Groups

-   Add `:mixfix` as recognized metadata key in `parse-spec-metadata`
-   Store operator symbol -> `spec-entry` mapping for Pratt parser lookup
-   Add `precedence-group` as a new top-level form
-   Module-scoped group definitions: imported groups compose into DAG
-   Tests: user-defined operators, custom precedence groups, cross-module


<a id="orgb570498"></a>

## Phase 3: Chained Comparisons + Diagnostics

-   Special preparse rule for consecutive comparison operators
-   Error messages for precedence ambiguity: "use `.{(a X b) Y c}` or `.{a X (b Y c)}`"
-   Pretty-printer support: print `.{a + b}` when source was mixfix
-   REPL: show both mixfix and prefix forms


<a id="org95b39e4"></a>

## Phase 4: Advanced Features (Future)

-   Unicode operator symbols (`\oplus` at multiplicative, etc.)
-   Postfix operators (`.{n!}` for factorial)
-   Full mixfix patterns (`.{if p then a else b}`) &#x2013; Agda-style, if demand exists
-   Interaction with `functor` keyword: `:compose` and `:identity` could auto-register mixfix


<a id="org40d17f4"></a>

# Part VI: Design Decisions & Tradeoffs


<a id="org7291c5e"></a>

## Decision 1: Named Groups vs Numeric Levels

**Recommendation: Named groups (Swift/Rhombus model).**

| Criterion          | Numeric (Haskell)   | Named Groups (Swift)           |
|------------------ |------------------- |------------------------------ |
| Simplicity         | Simpler to declare  | More verbose                   |
| Extensibility      | Limited (10 slots)  | Unlimited (DAG grows)          |
| Cross-library      | Collision-prone     | Composable by default          |
| Ambiguity handling | Total order, silent | Partial order, explicit errors |
| Implementation     | Simpler parser      | Needs DAG topology             |
| User intuition     | "7 > 6, done"       | "multiplicative > additive"    |

Named groups win on every criterion except initial simplicity. The verbose declaration is a one-time cost; the safety benefits accumulate over the lifetime of the language.


<a id="orgf73a9c2"></a>

## Decision 2: `.{...}` Delimiters vs. No Delimiters

**Recommendation: Delimited with `.{...}`.**

Without delimiters (like Julia), infix becomes the default and prefix is the exception. This fundamentally changes the character of the language. With delimiters:

-   Homoiconicity is preserved. The canonical form is prefix.
-   The reader knows **exactly** when to switch parsing modes.
-   No ambiguity between function application and infix operators.
-   Consistent with the Tcl `expr` lesson: clear boundaries between sublanguages reduce cognitive load.

The `.` prefix is chosen because:

-   `.` is already "reclaimed" for field access; `.{...}` is a natural extension (dot-something = accessor/sugar).
-   It doesn't conflict with existing syntax: `{...}` alone is map literals.
-   It's visually lightweight: `.{a + b}` is only 2 characters of overhead.


<a id="orgd93d45b"></a>

## Decision 3: Partial Application via `_`

**Recommendation: Reuse existing placeholder machinery.**

`.{_ + 1}` desugars to `[add _ 1]`, which the existing `expand-expression` in `macros.rkt` already converts to `(fn [$_0] [add $_0 1])`. No new machinery needed. This also means `.{_ * _}` produces a curried two-argument function, consistent with how `map [* _ _] xs` already works.


<a id="org983e7c2"></a>

## Decision 4: Comparison Chaining

**Recommendation: Support chained comparisons (Julia-style).**

`.{a < b <` c}= -> `[and [lt a b] [le b c]]` with `b` evaluated once. This is:

-   Mathematically natural (`0 < x < 100` reads as expected)
-   Unambiguous (comparison operators are non-associative, so `a < b < c` can't mean `(a < b) < c`)
-   Implemented as a special preparse rule, not a change to the precedence system


<a id="org9c0cd2c"></a>

## Decision 5: Bitwise Operators

**Recommendation: No precedence relationship with comparison.**

Bitwise `&`, `|`, `^` are in their own group(s) with **no** edge to `comparison` in the precedence DAG. Using them together in `.{...}` requires explicit grouping:

```
.{(x & mask) == 0}     ;; explicit — correct
.{x & mask == 0}        ;; ERROR: no precedence between bitwise-and and comparison
```

This **prevents the C bug by construction**.


<a id="org4b57a0c"></a>

# Part VII: Open Questions

1.  **Should `.{...}` support statement-like forms?** E.g., `.{x = y + 1}` for assignment. Recommendation: No in Phase 1. Keep `.{...}` purely for expressions. Assignment remains `def x [add y 1]`.

2.  **Should we support `.{...}` in `match` patterns?** E.g., `match n | .{_ + 1} => ...`. This requires extending patterns with infix sugar. Defer to Phase 4.

3.  **What about `do` notation inside `.{...}`?** E.g., `.{x >>` fn [a] .{a + 1}}=. This is syntactically possible but may be too clever. Prefer `do` blocks for monadic code.

4.  **Should `functor` `:compose` auto-register a mixfix symbol?** E.g., `functor Xf ... :compose xf-compose` could auto-generate `:mixfix {:symbol >> :group composition}`. Appealing but adds coupling.


<a id="org277af47"></a>

# References


<a id="orgd210cb3"></a>

## Academic Papers

-   Danielsson & Norell, "Parsing Mixfix Operators" (IFL 2008)
-   Ryu, "Parsing Fortress Syntax" (PPPJ 2009)
-   van den Brand et al., "Safe Specification of Operator Precedence Rules" (SLE 2013)
-   Henzinger et al., "Regular Methods for Operator Precedence Languages" (ICALP 2023)
-   Pratt, "Top Down Operator Precedence" (POPL 1973)


<a id="org0b3377c"></a>

## Language Documentation

-   [Agda Mixfix Operators](https://agda.readthedocs.io/en/latest/language/mixfix-operators.html)
-   [agda-unimath Mixfix Guidelines](https://unimath.github.io/agda-unimath/MIXFIX-OPERATORS.html)
-   [Maude Manual Ch.3: Syntax and Basic Parsing](https://maude.lcc.uma.es/manual271/maude-manualch3.html)
-   [SWI-Prolog Operators](https://www.swi-prolog.org/pldoc/man?section=operators)
-   [Haskell 2010 Report: Expressions](https://www.haskell.org/onlinereport/haskell2010/haskellch3.html)
-   [Swift SE-0077: Improved Operator Declarations](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0077-operator-precedence.md)
-   [Carbon Proposal #555: Operator Precedence](https://github.com/carbon-language/carbon-lang/blob/trunk/proposals/p0555.md)
-   [Rhombus Enforest: Operator Precedence](https://docs.racket-lang.org/enforest/Operator_Precedence_and_Associativity.html)
-   [Julia Mathematical Operations](https://docs.julialang.org/en/v1/manual/mathematical-operations/)
-   [Tcl expr Manual](https://www.tcl.tk/man/tcl/TclCmd/expr.htm)
-   [SRFI-105: Curly-infix-expressions](https://srfi.schemers.org/srfi-105/srfi-105.html)


<a id="org76a4a2c"></a>

## Blog Posts & Practical Guides

-   [Operator Precedence: We Can Do Better (Adamant Blog)](https://blog.adamant-lang.org/2019/operator-precedence/)
-   [Operator Precedence Is Broken (foonathan)](https://www.foonathan.net/2017/07/operator-precedence/)
-   [Fix(ity) Me (Kowainik)](https://kowainik.github.io/posts/fixity)
-   [Simple but Powerful Pratt Parsing (matklad)](https://matklad.github.io/2020/04/13/simple-but-powerful-pratt-parsing.html)
-   [Pratt Parsers: Expression Parsing Made Easy (Bob Nystrom)](https://journal.stuffwithstuff.com/2011/03/19/pratt-parsers-expression-parsing-made-easy/)
-   [Pratt Parsing and Precedence Climbing Are the Same Algorithm (Oil Shell)](https://www.oilshell.org/blog/2016/11/01.html)
-   [User-Programmable Infix Operators in Racket (Alexis King)](https://lexi-lambda.github.io/blog/2017/08/12/user-programmable-infix-operators-in-racket/)
-   [Hundred Year Mistakes (Eric Lippert)](https://ericlippert.com/2020/02/27/hundred-year-mistakes/)
