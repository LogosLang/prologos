- [Executive Summary](#orgc9d4115)
- [Current State: What Exists](#orgd82c82c)
  - [Numeric Types (4 Families)](#orgb96bb22)
  - [Parser Keywords (~85 type-specific operations)](#org1a5905e)
  - [Trait Infrastructure (Complete)](#org1c38587)
  - [Subtype Coercion at Reduction (Within-Family Only)](#orgb860de0)
- [Critique: The Ergonomic Gap](#org478048d)
  - [Problem 1: Parser Keywords Are Not Generic](#org0229287)
  - [Problem 2: No Symbolic Operators for Generic Arithmetic](#orgc97ad54)
  - [Problem 3: Parser Keywords Can't Be Passed as Higher-Order Arguments](#org8b1d1f9)
  - [Problem 4: No Posit Dominance Rule](#org9037ea7)
  - [Problem 5: Identity Traits Incomplete for Posit](#orgfd1620d)
  - [Problem 6: Decimal Literals Require Tilde Ceremony](#org0dd32b9)
- [Design Decisions and Tradeoffs](#org1a48a14)
  - [Decision 1: Generic Operators (`+` `-` `*` `/`) as Trait-Dispatched Keywords](#org1f3db81)
  - [Decision 2: Posit Dominance Rule](#org2d08db2)
  - [Decision 3: Keep Type-Specific Keywords as Escape Hatch](#org54f4f9a)
  - [Decision 4: Literal Type Inference — Decimal as Posit32](#org5991261)
- [Gaps in Infrastructure](#org33a984a)
  - [Gap 1: No Generic Operator Keywords](#org58de610)
  - [Gap 2: No Posit Identity Instances](#org7c21227)
  - [Gap 3: No `negate` Generic Operator](#org2f37057)
  - [Gap 4: No `abs` Generic Operator](#orgafbdfdf)
  - [Gap 5: No `from-int` / `from-rat` Generic Syntax](#org91dd371)
  - [Gap 6: No Numeric Type Join Function](#orgbd1b76b)
  - [Gap 7: Posit Equality Derived, Not Primitive](#org0daa2d5)
  - [Gap 8: Bare Decimal Literals Route to Rat, Not Posit](#org39f3fb6)
- [Recommendations](#org9251a01)
  - [Phase 1: Foundation Fixes (Low Risk, High Value)](#org43babf8)
    - [1a. Add Posit Identity Instances](#org92e7ab7)
    - [1b. Add Posit Equality Primitives](#org43276c3)
    - [1c. Document Nat vs Int Principle](#org17ad78d)
    - [1d. Bare Decimal Literals as Posit32](#orgfcd8162)
  - [Phase 2: Generic Operators (Medium Risk, Very High Value)](#orga7e2455)
    - [2a. Add `+` `-` `*` `/` `<` `<=` `=` as Parser Keywords](#org04d3380)
    - [2b. `from-int` and `from-rat` as Context-Resolved Keywords](#orgde97436)
  - [Phase 3: Posit Dominance (Higher Risk, High Value)](#orgb37377c)
    - [3a. Numeric Type Join](#org0d725c7)
    - [3b. Coercion in Generic Operators](#orgfed40c0)
    - [3c. Implicit Coercion Warnings](#orgf492d7a)
  - [Phase 4: Numeric Literal Polymorphism (Future, Research)](#orgfdbefd9)
- [Summary Table](#org052f04b)
- [What Success Looks Like](#org2fca9da)



<a id="orgc9d4115"></a>

# Executive Summary

This audit examines the gap between Prologos's *stated design goal* &#x2014; the most-generalizable interface with efficient dispatch &#x2014; and the *current reality* of its numeric infrastructure. The findings: the trait foundation is solid and complete, but the surface ergonomics force users into type-specific parser keywords (`int+`, `rat+`, `p32+`) instead of generic operations. A user writing `[int+ a b]` is not writing to the most-general interface; they are locked to `Int`.

The recommendation is a phased introduction of generic arithmetic operators (`+`, `-`, `*`, `/`, `<`, `<=`, `=`) that dispatch through the existing trait infrastructure, with a Posit-dominance rule for mixed exact/approximate computation, and compile-time specialization to recover the performance of parser keywords.


<a id="orgd82c82c"></a>

# Current State: What Exists


<a id="orgb96bb22"></a>

## Numeric Types (4 Families)

| Family | Types               | Literals             | Purpose                  |
|------ |------------------- |-------------------- |------------------------ |
| Peano  | `Nat`               | `42N`, `zero`, `suc` | Type-level only          |
| Exact  | `Int`               | `42`, `-7`           | Default computation      |
| Exact  | `Rat`               | `3/7`, `1/2`         | Exact fractions          |
| Approx | `Posit{8,16,32,64}` | `~3.14`, `~3.14p8`   | Tapered-precision approx |

Within-family subtyping is automatic:

-   Exact: `Nat <: Int <: Rat`
-   Posit: `Posit8 <: Posit16 <: Posit32 <: Posit64`

Cross-family: NO implicit coercion (deliberate).


<a id="org1a5905e"></a>

## Parser Keywords (~85 type-specific operations)

Every numeric type has its own set of parser keywords:

| Operation | Int       | Rat       | Posit32   | Posit8    |
|--------- |--------- |--------- |--------- |--------- |
| add       | `int+`    | `rat+`    | `p32+`    | `p8+`     |
| sub       | `int-`    | `rat-`    | `p32-`    | `p8-`     |
| mul       | `int*`    | `rat*`    | `p32*`    | `p8*`     |
| div       | `int/`    | `rat/`    | `p32/`    | `p8/`     |
| neg       | `int-neg` | `rat-neg` | `p32-neg` | `p8-neg`  |
| abs       | `int-abs` | `rat-abs` | `p32-abs` | `p8-abs`  |
| lt        | `int-lt`  | `rat-lt`  | `p32-lt`  | `p8-lt`   |
| eq        | `int-eq`  | `rat-eq`  | (derived) | (derived) |

This is ~85 keywords across 4 families x 4 widths.

These are fast (direct AST nodes → Racket primitives) but fundamentally *non-generic*. A function written with `int+` cannot be reused for `Rat`.


<a id="org1c38587"></a>

## Trait Infrastructure (Complete)

All single-method traits (dict IS the function):

| Trait                      | Method               | Instances              |
|-------------------------- |-------------------- |---------------------- |
| `Add A`                    | `A -> A -> A`        | Nat, Int, Rat, Posit\* |
| `Sub A`                    | `A -> A -> A`        | Nat, Int, Rat, Posit\* |
| `Mul A`                    | `A -> A -> A`        | Nat, Int, Rat, Posit\* |
| `Div A`                    | `A -> A -> A`        | Int, Rat, Posit\*      |
| `Neg A`                    | `A -> A`             | Int, Rat, Posit\*      |
| `Abs A`                    | `A -> A`             | Int, Rat, Posit\*      |
| `Eq A`                     | `A -> A -> Bool`     | Nat, Int, Rat, Posit\* |
| `Ord A`                    | `A -> A -> Ordering` | Nat, Int, Rat, Posit\* |
| `FromInt A`                | `Int -> A`           | Int, Rat, Posit\*      |
| `FromRat A`                | `Rat -> A`           | Rat, Posit\*           |
| `AdditiveIdentity A`       | (dict = zero value)  | Nat, Int, Rat          |
| `MultiplicativeIdentity A` | (dict = one value)   | Nat, Int, Rat          |

Bundles:

-   `Num A` := `(Add A) (Sub A) (Mul A) (Neg A) (Eq A) (Ord A) (Abs A) (FromInt A)`
-   `Fractional A` := `(Num A) (Div A) (FromRat A)`


<a id="orgb860de0"></a>

## Subtype Coercion at Reduction (Within-Family Only)

`reduction.rkt` has coercion helpers:

-   `try-coerce-to-int` : Nat → Int
-   `try-coerce-to-rat` : Nat/Int → Rat
-   `try-coerce-to-posit` : narrow Posit → wider Posit

These fire at reduction time for stuck terms. Example: `[int+ 3N 4]` works because `3N` (Nat) is coerced to `(expr-int 3)` before the add is evaluated.

This is the closest thing to implicit widening — but it only works *within a family* and only for parser keywords.


<a id="org478048d"></a>

# Critique: The Ergonomic Gap


<a id="org0229287"></a>

## Problem 1: Parser Keywords Are Not Generic

A user who writes:

```prologos
spec double : Int -> Int
defn double [x] [int+ x x]
```

has hard-coded the type. To make this generic requires the trait ceremony:

```prologos
spec double : {A : Type} where (Add A) A -> A
defn double [x] [Add-add x x]   ;; actually needs dict param
```

But even this doesn't work cleanly because single-method trait resolution requires the dict to be passed explicitly or resolved at the call site. The user can't write `[+ x x]` and have it just work.


<a id="orgc97ad54"></a>

## Problem 2: No Symbolic Operators for Generic Arithmetic

There is no `+`, `-`, `*`, `/`, `<`, `<=`, `=` that dispatches by type. Compare with the vision:

```prologos
;; What we WANT to write (most-generic interface):
spec mean : {A : Type} where (Fractional A) [List A] -> A
defn mean [xs]
  [/ [sum xs] [from-int [length xs]]]

;; What we MUST write today:
;; ... depends on which type A is, can't be written generically
;; without explicit dict-param threading
```


<a id="org8b1d1f9"></a>

## Problem 3: Parser Keywords Can't Be Passed as Higher-Order Arguments

`int+` is a parser keyword, not a first-class function. You cannot write:

```prologos
reduce int+ 0 xs   ;; FAILS: int+ is not a value
```

Workaround: define a wrapper function. But if `+` dispatched through traits, it *would* be a first-class function (the resolved dict IS the function for single-method traits).


<a id="org9037ea7"></a>

## Problem 4: No Posit Dominance Rule

The user's stated desire: "If a Posit is in our computation, then the result type will be Posit (even if there is a Rat representation)."

Currently, there is no mechanism for this. Mixed exact/approximate operations are rejected outright (cross-family subtyping returns `#f`). The user must manually convert:

```prologos
;; Must explicitly convert:
[p32+ [p32-from-rat r] p]

;; Desired: Posit dominates
[+ r p]   ;; => Posit32 (Rat widened to Posit32 automatically)
```


<a id="orgfd1620d"></a>

## Problem 5: Identity Traits Incomplete for Posit

`AdditiveIdentity` and `MultiplicativeIdentity` have instances for Nat, Int, Rat &#x2014; but NOT for Posit types. This means the generic `sum` and `product` functions from `generic-numeric-ops` cannot be used with Posit lists without adding these instances.


<a id="org0dd32b9"></a>

## Problem 6: Decimal Literals Require Tilde Ceremony

Writing a Posit literal requires the `\~` prefix: `~3.14`, `~0.5`, `~1.0`. This is unfamiliar and off-putting to users coming from any mainstream language where `3.14` naturally means "a decimal number." The current grammar *defines* a `decimal-literal` production (`digit+ '.' digit+`) but routes it through the rational pipeline to produce a `Rat` &#x2014; so `3.14` becomes `157/50 : Rat`.

In practice, this is a dead path: no `.prologos` file in the project uses bare decimal literals as executable code. Every decimal in the codebase is either in a comment or uses the `~` prefix. The grammar production exists but has no real users.

Meanwhile, the ergonomic cost is high. Compare:

```prologos
;; Current (tilde ceremony):
'[~1.0 ~3.14 ~2.718]

;; Desired (natural decimals):
'[1.0 3.14 2.718]
```

The tilde prefix should remain available (as an explicit "I want approximate") but bare decimals should default to Posit32, matching every programmer's intuition that `3.14` is a floating-point-style value, not an exact fraction.

Users who genuinely want the exact rational `157/50` can write the fraction form `157/50` directly &#x2014; that syntax is unambiguous and already exists.


<a id="org1a48a14"></a>

# Design Decisions and Tradeoffs


<a id="org1f3db81"></a>

## Decision 1: Generic Operators (`+` `-` `*` `/`) as Trait-Dispatched Keywords

*Proposed*: Introduce new parser keywords `+`, `-`, `*`, `/`, `<`, `<=`, `=` that resolve through the trait system:

```prologos
[+ a b]    ;; desugars to: [Add-add <resolved-dict> a b]
[- a b]    ;; desugars to: [Sub-sub <resolved-dict> a b]
[* a b]    ;; desugars to: [Mul-mul <resolved-dict> a b]
[/ a b]    ;; desugars to: [Div-div <resolved-dict> a b]
[< a b]    ;; desugars to: [ord-lt <resolved-dict> a b]
[<= a b]   ;; desugars to: [ord-le <resolved-dict> a b]
[= a b]    ;; desugars to: [Eq-eq? <resolved-dict> a b]
```

*Tradeoff*:

-   Pro: Achieves the most-generic interface goal
-   Pro: `+` IS a first-class function (it's the resolved dict)
-   Pro: Works naturally with `reduce`, `map`, higher-order patterns
-   Con: Requires type information at elaboration time to resolve the dict
-   Con: May be slightly slower than direct parser keywords if not specialized

*Mitigation*: Compile-time specialization. When the elaborator can determine the concrete type (e.g., both args are `Int`), it can emit `expr-int-add` directly instead of going through the trait dict. This gives generic syntax with parser-keyword performance.


<a id="org2d08db2"></a>

## Decision 2: Posit Dominance Rule

*Proposed*: When exact and approximate types meet in an arithmetic operation, the result is the approximate type. Specifically:

| Left   | Right   | Result  |
|------ |------- |------- |
| Int    | Posit32 | Posit32 |
| Rat    | Posit32 | Posit32 |
| Nat    | Posit32 | Posit32 |
| Posit8 | Posit32 | Posit32 |
| Int    | Rat     | Rat     |
| Nat    | Int     | Int     |

Rule: *the wider type wins, with approximate dominating exact*.

This requires:

1.  A *join* operation on numeric types that computes the result type
2.  Implicit conversion of the narrower operand at reduction time
3.  Type-level representation of this rule for the type checker

*Tradeoff*:

-   Pro: Natural, matches user expectation (adding money to a float gives float)
-   Pro: Aligns with stated language vision
-   Pro: Simplifies mixed-type code enormously
-   Con: Implicit precision loss (Int → Posit32 is lossy)
-   Con: Breaks the current "explicit conversion" philosophy
-   Con: Requires careful handling of `NaR` propagation

*Mitigation*: Make Posit dominance opt-in via a pragma or module-level declaration. Or: allow it only through the generic operators (`+`) while type-specific keywords (`int+`, `p32+`) remain strict.


<a id="org54f4f9a"></a>

## Decision 3: Keep Type-Specific Keywords as Escape Hatch

*Proposed*: `int+`, `rat+`, `p32+` etc. remain available as explicit, type-locked operations. The generic `+` is the default; the specific keywords are the escape hatch when you need guaranteed type behavior.

This is analogous to Clojure's `+` (generic) vs `unchecked-add` (primitive).

*Tradeoff*:

-   Pro: No breaking changes
-   Pro: Performance-sensitive code can use direct keywords
-   Pro: Learning path: start with `+`, discover `int+` when you need control
-   Con: Two ways to do the same thing (complexity budget)


<a id="org5991261"></a>

## Decision 4: Literal Type Inference — Decimal as Posit32

*Current*:

-   `42` → `Int` (bare integer)
-   `3/7` → `Rat` (fraction)
-   `3.14` → `Rat` (bare decimal → exact rational; dead path, unused in practice)
-   `~3.14` → `Posit32` (tilde prefix = approximate)
-   `42N` → `Nat` (N suffix = Peano)

*Proposed*: Bare decimals produce `Posit32` (not `Rat`):

| Literal | Current   | Proposed  |
|------- |--------- |--------- |
| `42`    | `Int`     | `Int`     |
| `3/7`   | `Rat`     | `Rat`     |
| `3.14`  | `Rat`     | `Posit32` |
| `~3.14` | `Posit32` | `Posit32` |
| `42N`   | `Nat`     | `Nat`     |

This changes the *semantics* of bare decimal literals, but since no existing `.prologos` file uses them in executable code, it is a safe change. The tilde prefix remains as an explicit "approximate" marker for any numeric form: `~42` (int → Posit32), `~3/7` (rat → Posit32), `~3.14` (decimal → Posit32).

For users who want exact decimal fractions, the rational syntax `157/50` is always available and unambiguous.

*Tradeoff*:

-   Pro: Matches universal programmer intuition (`3.14` is a float-style value)
-   Pro: Eliminates the most common source of surprise for new users
-   Pro: `'[1.0 3.14 2.718]` reads naturally for scientific/numeric code
-   Pro: No breakage — the feature path is unused in practice
-   Con: Semantic divergence from the grammar's original intent (`decimal-literal` was exact)
-   Con: Users must learn that `3/7` is exact but `0.42857` is approximate
-   Con: Loss of a theoretical feature (exact-decimal-as-Rat) that nobody uses

*Mitigation*: Document clearly in the grammar that decimals with `.` are approximate (Posit), fractions with `/` are exact (Rat). This is a natural and learnable distinction.

**Width selection**: Bare decimals default to `Posit32` (the natural default width, matching `~3.14`). Width-specific variants could use a suffix: `3.14p8`, `3.14p16`, `3.14p64` — but this is deferrable to later work.


<a id="org33a984a"></a>

# Gaps in Infrastructure


<a id="org58de610"></a>

## Gap 1: No Generic Operator Keywords

The parser has no `+`, `-`, `*`, `/` keywords. Adding them requires:

-   New parser cases in `parser.rkt`
-   New surface syntax nodes (`surf-generic-add` etc.)
-   Elaboration to trait-dispatched calls
-   Optional specialization to direct keywords when types are known


<a id="org7c21227"></a>

## Gap 2: No Posit Identity Instances

`AdditiveIdentity` and `MultiplicativeIdentity` need instances for all 4 Posit widths. This is straightforward:

```prologos
;; Posit32 zero = posit32 encoding of 0 (all zeros)
impl AdditiveIdentity Posit32
  defn zero <Posit32> [posit32 0]   ;; 0 encodes to all-zero bits

impl MultiplicativeIdentity Posit32
  defn one <Posit32> [posit32 1073741824]  ;; 1.0 in posit32 es=2
```

Without these, generic `sum` and `product` don't work for Posit lists.


<a id="org2f37057"></a>

## Gap 3: No `negate` Generic Operator

There's no `negate` or unary `-` for generic negation. The `Neg` trait exists, but no operator syntax maps to it.


<a id="orgafbdfdf"></a>

## Gap 4: No `abs` Generic Operator

Same for `abs`. The trait exists, the instances exist, but no surface syntax maps to it.


<a id="org91dd371"></a>

## Gap 5: No `from-int` / `from-rat` Generic Syntax

`FromInt` and `FromRat` traits exist, but using them requires explicit dict threading. A generic `from-int` that resolves by context would allow:

```prologos
;; Desired:
def pi : Posit32 [from-rat 355/113]

;; Currently requires knowing the Posit32 dict:
def pi : Posit32 [FromRat-from-rat Posit32--FromRat--dict 355/113]
```


<a id="orgbd1b76b"></a>

## Gap 6: No Numeric Type Join Function

For Posit dominance, the type checker needs a `numeric-join` function: `numeric-join(Int, Posit32) = Posit32`. This doesn't exist. The current `subtype?` is one-directional (is A <: B?), not a join (what's A ∨ B?).


<a id="org0daa2d5"></a>

## Gap 7: Posit Equality Derived, Not Primitive

Posit types lack a primitive equality operation. The Eq instance derives equality from `and [p{N}-le x y] [p{N}-le y x]` — two comparisons per equality check. A native `p{N}-eq` parser keyword would halve this cost.


<a id="org39f3fb6"></a>

## Gap 8: Bare Decimal Literals Route to Rat, Not Posit

The reader's `read-number-token!` (line 662-679) parses `3.14` as an exact rational (`157/50`) and emits a `'number` token. The parser then matches it via `(and (number? d) (exact? d) (rational? d) (not (integer? d)))` → `surf-rat-lit`, producing a `Rat` value.

To route bare decimals to Posit32 instead:

1.  **Reader**: Emit a new token type (`'decimal-literal`) instead of `'number` when a decimal point is encountered. The value remains an exact rational (for lossless posit encoding), but the token type distinguishes it.

2.  **Parser**: Add a case for `'decimal-literal` → `surf-approx-literal` (reuse existing surface node). This enters the same elaboration path as `~3.14`.

3.  **Grammar**: Update `decimal-literal` comment from "parsed as exact rational" to "parsed as Posit32 (default approximate)."

4.  **Sexp mode**: In sexp mode, Racket's reader produces exact rationals for decimal-like forms (if they get that far). Need a sentinel like `($decimal-literal 157/50)` or detect `.` in the datum — or accept that sexp-mode decimals remain Rat (sexp mode is the fallback, not the primary syntax).

`Estimated: reader.rkt (5 lines), parser.rkt (5 lines), grammar updates, ~10 tests.`


<a id="org9251a01"></a>

# Recommendations


<a id="org43babf8"></a>

## Phase 1: Foundation Fixes (Low Risk, High Value)


<a id="org92e7ab7"></a>

### 1a. Add Posit Identity Instances

Add `AdditiveIdentity` and `MultiplicativeIdentity` for Posit8/16/32/64. This unlocks generic `sum` and `product` for Posit lists immediately. `Estimated: 1 file, 8 instances, 8 tests.`


<a id="org43276c3"></a>

### 1b. Add Posit Equality Primitives

Add `p{N}-eq` parser keywords (4 new AST nodes). Update Eq instances to use them. Halves equality-check cost. `Estimated: touches 14-file AST pipeline, 4 instance updates, 16 tests.`


<a id="org17ad78d"></a>

### 1c. Document Nat vs Int Principle

*Already done* in PATTERNS<sub>AND</sub><sub>CONVENTIONS.org</sub> (this session). Audit further examples in tutorials.


<a id="orgfcd8162"></a>

### 1d. Bare Decimal Literals as Posit32

Route `3.14` → `Posit32` instead of `Rat`. Changes `read-number-token!` in `reader.rkt` to emit `'decimal-literal` token, and adds a parser case that produces `surf-approx-literal` (reusing the existing surface node and elaboration path). The tilde prefix remains available: `~42`, `~3/7`, `~3.14` all still work.

This is an additive change with no existing breakage — no `.prologos` file uses bare decimal literals in executable code today.

After this change:

```prologos
;; Natural decimal syntax:
3.14             ;; => Posit32 (was Rat, now Posit32)
'[1.0 2.0 3.0]  ;; list of Posit32 — reads naturally

;; Tilde still works (explicit approximate marker):
~3.14            ;; => Posit32 (unchanged)
~42              ;; => Posit32 from integer (unchanged)

;; Exact fractions remain Rat:
3/7              ;; => Rat (unchanged)
157/50           ;; => Rat (unchanged — the exact form of 3.14)
```

Grammar update: update `decimal-literal` production and prose.

`Estimated: reader.rkt (~5 lines), parser.rkt (~5 lines), grammar files, ~10 new tests. Low risk.`


<a id="orga7e2455"></a>

## Phase 2: Generic Operators (Medium Risk, Very High Value)


<a id="org04d3380"></a>

### 2a. Add `+` `-` `*` `/` `<` `<=` `=` as Parser Keywords

New parser keywords that elaborate to trait-dispatched calls. When the concrete type is known at elaboration, specialize to the direct keyword (`int+`, `rat+`, etc.) for zero overhead.

Syntax: `[+ a b]`, `[* a b]`, `[< a b]`, etc.

Also add unary: `[negate x]` (Neg trait), `[abs x]` (Abs trait).

This is the single highest-value change in this audit. It transforms Prologos from "write type-specific code" to "write generic code that's also fast."

`Estimated: parser.rkt, surface-syntax.rkt, elaborator.rkt, typing-core.rkt changes. ~40 new tests.`


<a id="orgde97436"></a>

### 2b. `from-int` and `from-rat` as Context-Resolved Keywords

When the target type is known from bidirectional type checking, `from-int` and `from-rat` resolve the correct trait instance automatically:

```prologos
def pi : Posit32 [from-rat 355/113]   ;; type context resolves Posit32 instance
def n  : Rat [from-int 42]            ;; type context resolves Rat instance
```

`Estimated: elaborator.rkt changes, ~12 tests.`


<a id="orgb37377c"></a>

## Phase 3: Posit Dominance (Higher Risk, High Value)


<a id="org0d725c7"></a>

### 3a. Numeric Type Join

Add `numeric-join : Type -> Type -> Type` to the type checker. Returns the least upper bound in the numeric lattice:

```
      Posit64
     /   |   \
Posit32  |  Posit16
   |     |     |
   |  Posit8   |
   |     |     |
   Rat --|-- (cross)
    |
   Int
    |
   Nat
```

Cross-family join: approximate wins. `numeric-join(Rat, Posit32) = Posit32`. Within-family: wider wins. `numeric-join(Int, Rat) = Rat`.


<a id="orgfed40c0"></a>

### 3b. Coercion in Generic Operators

When `[+ a b]` has `a : Int` and `b : Posit32`, the elaborator:

1.  Computes `numeric-join(Int, Posit32) = Posit32`
2.  Inserts coercion: `[+ [p32-from-int a] b]`
3.  Resolves `Add Posit32` instance

This only applies to the generic operators. Type-specific keywords (`int+`) remain strict.


<a id="orgf492d7a"></a>

### 3c. Implicit Coercion Warnings

When cross-family coercion occurs (exact → approximate), emit an informational note (not an error):

```
Note: implicit coercion Int → Posit32 at line 42
  |> this loses precision for integers > 2^28
  |> use explicit [p32-from-int x] to suppress this note
```

`Estimated: typing-core.rkt, reduction.rkt, error infrastructure. ~30 tests.`


<a id="orgfdbefd9"></a>

## Phase 4: Numeric Literal Polymorphism (Future, Research)

In Haskell, `42` can be `Int`, `Float`, `Rational` depending on context. Prologos currently gives `42` a fixed type (`Int`). A future enhancement could make numeric literals polymorphic:

```prologos
;; Future: 42 has type {A : Type} where (FromInt A) => A
def x : Posit32 42       ;; 42 converts to Posit32 automatically
def y : Rat 42            ;; 42 converts to Rat automatically
def z : Int 42            ;; 42 stays as Int (no conversion)
```

This is powerful but complex (requires deferred literal typing, defaulting rules). Recommend deferring until Phase 2 operators are stable.


<a id="org052f04b"></a>

# Summary Table

| Gap                         | Phase | Risk   | Value     | Effort  |
|--------------------------- |----- |------ |--------- |------- |
| Posit identity instances    | 1a    | Low    | Med       | Small   |
| Posit equality primitives   | 1b    | Low    | Med       | Medium  |
| Bare decimal → Posit32      | 1d    | Low    | High      | Small   |
| Generic `+` `-` `*` `/` ops | 2a    | Medium | Very High | Large   |
| Context-resolved `from-int` | 2b    | Medium | High      | Medium  |
| Numeric type join           | 3a    | Higher | High      | Medium  |
| Posit dominance coercion    | 3b    | Higher | High      | Large   |
| Coercion warnings           | 3c    | Low    | Med       | Small   |
| Literal polymorphism        | 4     | High   | High      | V.Large |


<a id="org2fca9da"></a>

# What Success Looks Like

After Phases 1-3, a user can write:

```prologos
ns my-math

spec mean : {A : Type} where (Fractional A) [List A] -> A
defn mean [xs]
  [/ [sum xs] [from-int [length xs]]]

;; Works with Rat:
mean '[1/3 2/3 1]
;; => 2/3 : Rat

;; Works with Posit32 (bare decimals = Posit32):
mean '[1.0 2.0 3.0]
;; => 2.0 : Posit32

;; Mixed: Posit dominates
[+ 42 3.14]
;; => 45.14 : Posit32

;; Higher-order: + is first-class
reduce + 0 '[1 2 3 4 5]
;; => 15 : Int

;; Pipe-friendly
|> '[1 2 3 4 5]
  map [fn [x] [* x x]]
  sum
;; => 55 : Int
```

This is the most-generic interface: one syntax, all numeric types, efficient dispatch, Posit dominance for approximate computation. The type-specific keywords remain as an expert escape hatch for when you need exact control over which operation fires.
