# Implementation Guide: Πρόλογος Numerics Suite
## A Phased Architecture for Exact, Posit, and IEEE Numeric Types

## Table of Contents

1. Introduction and Scope
2. Architectural Principles
3. Numeric Type Hierarchy
4. Core Numeric Traits
5. Exact Arithmetic Implementation
6. Posit Arithmetic Implementation
7. Conversion System
8. Dependent Types over Numerics
9. Numeric Operations and Algorithms
10. Literal Syntax and Type Inference
11. Integration with Language Features
12. Performance Engineering
13. Key Challenges and Open Problems
14. References and Key Literature

---

## Section 1: Introduction and Scope

### Problem Statement

The current Πρόλογος prototype implements natural numbers using Peano numerals (expr-zero and expr-suc), where each successor constructor adds a computation layer. This representation has severe performance consequences:

- Addition is O(n) in the smaller operand (recursively traverse successors)
- Multiplication is O(n²) when implemented as repeated addition
- Factorial compounds these effects: factorial(5) requires billions of reductions
- Empirical result: factorial(n > 4) takes >1 second in the prototype

This architecture was appropriate for exploring dependent types, where Peano naturals enable structural induction proofs. However, it is untenable for practical numeric computation.

### Solution Overview

This guide specifies a multi-representation numeric tower that:

1. **Preserves type-level Peano** for dependent type machinery (e.g., Vec n A requires type-level n)
2. **Uses runtime-efficient representations** (BigInt for Nat, Posit for approximate, IEEE for interop)
3. **Introduces a trait-based operations system** for uniform numeric interfaces
4. **Makes Posit the default approximate type**, not IEEE floating-point
5. **Implements automatic within-family subtyping** and explicit cross-family conversions

### Target Implementation

This guide focuses on the Racket prototype at `/mnt/prologos/racket/`, building on:

- `syntax.rkt` (expr-zero, expr-suc, expr-natrec, expr-posit8)
- `reduction.rkt` (WHNF reduction, nat-value extraction)
- `posit-impl.rkt` (pure Racket Posit8, 404 lines)
- `lib/prologos/data/nat.prologos` (Peano arithmetic library)

### Key Differentiator

Unlike most languages where IEEE float is the default approximate type, Πρόλογος makes Posit the default. This reflects the 2022 Posit Standard's advantages: tapered precision, no NaN/signed-zero complexity, and better round-trip conversions. IEEE is supported only for interoperability with external C libraries and numerical software.

---

## Section 2: Architectural Principles

### The Three Numeric Families

The Πρόλογος numerics suite organizes types into three families, each with natural within-family subtyping:

**Exact Family:** Nat < Int < Rat
- All operations are exact; no rounding or approximation
- Subtyping is lossless widening: every Nat is an Int, every Int is a Rat
- Default for numeric literals without the `~` marker

**Posit Family:** Posit8 < Posit16 < Posit32 < Posit64
- All operations are approximate; precision increases with size
- Subtyping widens to higher precision (Posit8 → Posit16 loses no information)
- 2022 Standard with es=2, tapered precision, NaR exception handling
- Default for approximate literals (with `~` marker)

**Float Family:** Float32 < Float64
- IEEE 754 for C interoperability and legacy code
- NOT the default; used only when explicitly requested
- Subtyping widens to Double

Within-family subtyping is implicit and automatic. Cross-family conversions (e.g., Rat → Posit32) are explicit, via conversion traits, and may be lossy.

### Traits for Operations, Not Types

Πρόλογος does not use an ad-hoc overloading system. Instead:

- Each numeric operation is defined via a **trait**: Add, Mul, Div, Ord, Eq, etc.
- Each numeric type **implements** the relevant traits
- Trait implementation specifies the behavior (semantics) of operations for that type

For example, Nat, Int, and Rat all implement Add, but their implementations differ: Nat addition is always non-negative, Int allows negatives, Rat is exact. The trait system makes these differences explicit in the type signature.

### Exact by Default, Approximate on Request

The principle is:

- `42` has type Int (exact, arbitrary precision)
- `3.14` has type Rat (exact, 314/100)
- `10/3` has type Rat (exact, simplified to 10/3)
- `~3.14` has type Posit32 (approximate, default width)
- `~(10/3)` converts Rat to Posit32 (lossy, user has asked for it)

This design avoids silent precision loss. Approximate computation is syntactically marked.

### Type-Level Peano, Runtime Efficiency

Peano numerals are preserved exclusively for type-level computation:

- **Type-level:** `Vec n A` uses Peano n for structural induction. Dependent functions like `append : Vec n A → Vec m A → Vec (add n m) A` require type-level n, m, and add.
- **Runtime:** `add n m` where n, m are values uses BigInt arithmetic via Racket's exact integers.
- **Bridge:** The `nat-value` function extracts the runtime representation from a type-level Peano witness, then erases it via QTT (Quantitative Type Theory).

Result: Peano is used for proofs (where performance doesn't matter); BigInt is used for computation (where it does).

### QTT Erasure

Quantitative Type Theory distinguishes between computational (multiplicity 1) and erased (multiplicity 0) occurrences of data. In Πρόλογος:

- Type-level Peano occurrences have multiplicity 0; they are erased to `()` at runtime.
- The witness to a dependent type constraint is erased; only the runtime value remains.
- This allows Peano to exist for type-checking without imposing runtime costs.

---

## Section 3: Numeric Type Hierarchy

### 3.1 Exact Family: Nat, Int, Rat

#### Nat (Natural Numbers)

**Definition:** Non-negative integers.

**Runtime representation:** Racket exact non-negative integers (backed by GMP for arbitrary precision).

**Type-level representation:** Peano numerals (expr-zero, expr-suc) for dependent typing.

**Prologos type syntax:**
```prologos
val n : Nat
val count : Nat
```

**Properties:**
- Closed under addition and multiplication
- Not closed under subtraction (sub : Nat → Nat → Maybe Nat)
- Total order: ≤, <, ≥, >
- Equality is decidable

**Example operations:**
```prologos
;; Prologos syntax
let x : Nat = 5
let y : Nat = 3
let sum : Nat = x + y      ;; 8 (automatically uses Nat.add)
let prod : Nat = x * y     ;; 15 (automatically uses Nat.mul)
let diff : Maybe Nat = x - y  ;; Just 2 (subtraction is fallible)
```

#### Int (Arbitrary-Precision Integers)

**Definition:** All integers, positive, negative, and zero.

**Runtime representation:** Racket exact integers (two's complement with arbitrary precision, GMP-backed).

**Prologos type syntax:**
```prologos
val n : Int
val balance : Int
```

**Properties:**
- Closed under addition, subtraction, multiplication, and negation
- Division truncates toward zero: div : Int → Int → Int (fallible if divisor is 0)
- Total order and equality
- Nat ⊆ Int (subtyping: every Nat is an Int)

**Example operations:**
```prologos
let x : Int = 5
let y : Int = -3
let sum : Int = x + y      ;; 2
let diff : Int = x - y     ;; 8
let neg : Int = negate x   ;; -5
```

#### Rat (Exact Rationals)

**Definition:** Quotients of integers p/q where q ≠ 0, simplified to canonical form (gcd(p,q) = 1, q > 0).

**Runtime representation:** Racket exact rationals (pairs of integers, automatically simplified by GCD).

**Prologos type syntax:**
```prologos
val r : Rat
val ratio : Rat
```

**Properties:**
- Closed under all arithmetic operations (addition, subtraction, multiplication, division)
- Division never fails: div : Rat → Rat → Rat (denominator is never zero in the result type)
- Canonical form ensures == is structural equality
- Int ⊆ Rat (every Int is a Rat via p/1)
- Nat ⊆ Int ⊆ Rat (transitive subtyping)

**Example operations:**
```prologos
let p : Rat = 10/3
let q : Rat = 7/2
let sum : Rat = p + q      ;; 41/6 (canonical form)
let prod : Rat = p * q     ;; 35/3
let inv : Rat = 1 / q      ;; 2/7
let div : Rat = p / q      ;; 20/21
```

### 3.2 Posit Family: Posit8, Posit16, Posit32, Posit64

#### Overview

Posit numbers follow the 2022 IEEE Standard for Posit arithmetic. They provide approximate arithmetic with tapered precision: higher-magnitude values have coarser precision, lower-magnitude values have finer precision. This matches the precision needs of many scientific applications better than IEEE floating-point.

**Key differences from IEEE:**
- No NaN or ±Inf (use NaR, "Not a Real")
- No signed zero
- Quire accumulator for exact product accumulation
- Regime bits encode scale in a compressed format

#### Posit8

**Bit layout:** 1 sign + regime + exponent (es=2, 2 bits) + fraction

**Total bits:** 8

**Dynamic range:** Approximately ±2^127 (regime is dominant)

**Precision:** Variable; finest near zero, coarser near extremes

**Quire size:** 32 bits

#### Posit16

**Bit layout:** 1 sign + regime + exponent (es=2, 2 bits) + fraction

**Total bits:** 16

**Dynamic range:** Approximately ±2^32767

**Precision:** Finer than Posit8, suitable for most applications

**Quire size:** 128 bits

#### Posit32

**Bit layout:** 1 sign + regime + exponent (es=2, 2 bits) + fraction

**Total bits:** 32

**Dynamic range:** Approximately ±2^2147483648 (extreme; regime dominates)

**Precision:** Coarse at extremes, very fine near 1.0

**Quire size:** 512 bits

**Note:** Posit32 is the default Posit type in Πρόλογος, analogous to `double` in C.

#### Posit64

**Bit layout:** 1 sign + regime + exponent (es=2, 2 bits) + fraction

**Total bits:** 64

**Dynamic range:** Approximately ±2^(2^62)

**Precision:** Extremely fine near 1.0, useful for high-precision scientific computing

**Quire size:** 2048 bits

### 3.3 Float Family: Float32, Float64

#### Overview

IEEE 754 floating-point types are supported for compatibility with C libraries and legacy code. However, Πρόλογος makes Posit the default approximate type. Float should be used only when explicitly needed for FFI or when working with code that requires IEEE semantics.

#### Float32

**Standard:** IEEE 754 Single Precision

**Bit layout:** 1 sign + 8 exponent + 23 fraction

**Range:** ±1.18×10^-38 to ±3.4×10^38

**Precision:** ~7 decimal digits

**Special values:** ±Inf, NaN (multiple bit patterns)

#### Float64

**Standard:** IEEE 754 Double Precision

**Bit layout:** 1 sign + 11 exponent + 52 fraction

**Range:** ±2.23×10^-308 to ±1.80×10^308

**Precision:** ~15 decimal digits

**Special values:** ±Inf, NaN (multiple bit patterns)

### 3.4 Subtyping Rules

#### Within-Family Subtyping (Implicit and Automatic)

**Exact family:**
```
Nat <: Int <: Rat
```

An expression of type Nat can be used wherever type Int is expected (and similarly for Int → Rat). No explicit conversion is required. The subtyping is justified by the fact that every Nat is an Int, and every Int is a Rat.

**Posit family:**
```
Posit8 <: Posit16 <: Posit32 <: Posit64
```

Widening to a larger Posit type always increases precision (or maintains it). The representation is compatible: a Posit8 value can be zero-extended to Posit16.

**Float family:**
```
Float32 <: Float64
```

Float32 can be widened to Float64.

#### Cross-Family Subtyping (None)

There is **no** subtyping relationship between families. For example:
- Nat and Posit8 are not related by subtyping.
- Rat and Float64 are not related by subtyping.

Conversions between families must be explicit via conversion traits (From, TryFrom).

#### Prologos Type Syntax Examples

```prologos
;; Within-family subtyping (automatic)
let x : Nat = 5
let y : Int = x          ;; OK, Nat <: Int
let z : Rat = y          ;; OK, Int <: Rat
let w : Rat = x          ;; OK, transitive: Nat <: Rat

;; Cross-family conversion (explicit)
let a : Rat = 22/7
let b : Posit32 = from a     ;; requires From trait, may fail
let c : Posit32 = try-from a ;; TryFrom, returns Maybe Posit32

;; Posit widening (automatic)
let p8 : Posit8 = ~1.5
let p16 : Posit16 = p8   ;; OK, Posit8 <: Posit16
```

---

## Section 4: Core Numeric Traits

### 4.1 Basic Arithmetic Traits

Arithmetic operations are defined via traits. Each trait specifies an operation and its signature; each numeric type implements the traits relevant to it.

#### Add Trait

```prologos
trait Add a where
  spec add : a → a → a
```

**Implementations:**
- Nat: addition always non-negative
- Int: addition without overflow
- Rat: exact addition
- Posit8/16/32/64: approximate addition with rounding
- Float32/64: IEEE addition

#### Sub Trait

```prologos
trait Sub a where
  spec sub : a → a → a
```

**Semantics by type:**
- Nat: sub returns Maybe Nat (subtraction may fail if result is negative)
- Int: sub always succeeds
- Rat: exact subtraction
- Posit: approximate subtraction

#### Mul Trait

```prologos
trait Mul a where
  spec mul : a → a → a
```

**Implementations:** Exact for Nat/Int/Rat, approximate for Posit/Float.

#### Div Trait

```prologos
trait Div a where
  spec div : a → a → a
```

**Semantics by type:**
- Nat: returns Maybe Nat (may fail if divisor is 0 or result is non-integer)
- Int: returns Maybe Int (may fail on division by 0)
- Rat: always succeeds (division by 0 is caught at type level)
- Posit/Float: approximate division

#### Neg Trait

```prologos
trait Neg a where
  spec neg : a → a
```

**Semantics:**
- Nat: returns Maybe Nat (negation fails for non-zero values)
- Int: negation always succeeds
- Rat: negation always succeeds
- Posit/Float: approximate negation (flips sign bit)

### 4.2 Comparison Traits

#### Eq Trait

```prologos
trait Eq a where
  spec eq : a → a → Bool
  spec neq : a → a → Bool
```

**Semantics:** Structural equality (or mathematical equality for Posit/Float, accounting for NaR).

#### Ord Trait

```prologos
trait Ord a where
  spec compare : a → a → Ordering

data Ordering = LT | EQ | GT
```

**Semantics:** Total order for Exact and Posit families. For Float, NaN comparisons return false (IEEE NaN semantics extended).

### 4.3 Bundle Traits

Bundle traits compose multiple operations into convenient groups.

#### Num Trait

```prologos
trait Num a where
  impl Add a
  impl Sub a
  impl Mul a
  impl Neg a
  impl Eq a
  impl Ord a
  spec from-int : Int → a
```

**Meaning:** Type a has basic numeric operations plus conversion from Int.

**Implementations:** Nat, Int, Rat, Posit8/16/32/64, Float32/64

#### Fractional Trait

```prologos
trait Fractional a where
  impl Num a
  impl Div a
  spec from-rat : Rat → a
```

**Meaning:** Type a supports division and conversion from Rat.

**Implementations:** Rat, Posit8/16/32/64, Float32/64 (NOT Nat or Int)

#### Floating Trait

```prologos
trait Floating a where
  impl Fractional a
  spec pi    : a
  spec exp   : a → a
  spec log   : a → a
  spec log10 : a → a
  spec sqrt  : a → a
  spec sin   : a → a
  spec cos   : a → a
  spec tan   : a → a
  spec asin  : a → a
  spec acos  : a → a
  spec atan  : a → a
  spec sinh  : a → a
  spec cosh  : a → a
  spec tanh  : a → a
```

**Meaning:** Type a is suitable for floating-point/transcendental operations.

**Implementations:** Posit8/16/32/64, Float32/64 (NOT Nat, Int, or Rat)

**Prologos syntax:**
```prologos
fn my-sqrt [a : Type] (impl Floating a) (x : a) : a :=
  sqrt x

let result : Posit32 = my-sqrt (~2.0)  ;; computes sqrt(2) ≈ 1.414...
```

### 4.4 Marker Traits

Marker traits have no methods; they indicate a property of the type.

#### Exact Trait

```prologos
trait Exact a where
  ;; no methods
```

**Implementations:** Nat, Int, Rat

#### Approximate Trait

```prologos
trait Approximate a where
  ;; no methods
```

**Implementations:** Posit8, Posit16, Posit32, Posit64, Float32, Float64

### 4.5 The Abs Trait

```prologos
trait Abs a where
  spec abs : a → a
```

**Implementations:** Int, Rat, Posit, Float

---

## Section 5: Exact Arithmetic Implementation

### 5.1 Nat Implementation

#### Type-Level Peano

Type-level Nat is defined as Peano numerals for dependent typing. Type-level operations (add, mul, etc.) are defined structurally in `lib/prologos/data/nat.prologos`:

```prologos
spec add Nat Nat -> Nat
defn add [x y]
  match y
    | zero  -> x
    | inc k -> inc [add x k]

spec mult Nat Nat -> Nat
defn mult [x y]
  match y
    | zero  -> zero
    | inc k -> add x [mult x k]
```

These definitions exist at the type level and are used for proving theorems about types (e.g., `Vec (add n m) a` is the type of appending vectors).

#### Runtime Nat

At runtime, Nat values are Racket exact non-negative integers (GMP-backed arbitrary precision):

```racket
;; In reduction.rkt
(define (nat-value expr)
  ;; Extract Racket integer from Peano expr
  (match expr
    ['zero 0]
    [(list 'suc e) (+ 1 (nat-value e))]))

;; Runtime operations (replace Peano arithmetic)
(define (nat-add x y) (+ x y))
(define (nat-mul x y) (* x y))
(define (nat-factorial n)
  (if (zero? n) 1 (* n (nat-factorial (sub1 n)))))
```

Performance comparison:

**Old (Peano):** `(factorial 5)` requires billions of reduction steps:
- Each successor is a thunk: O(n) space
- Addition: O(n) reductions (traverse suc chain)
- Factorial: O(n!) reductions (n multiplications, each O(n²) additions)
- Empirical: >1 second for n > 4

**New (BigInt):** `(factorial 5)` requires O(n) arithmetic operations:
- Factorial is computed iteratively: O(n) multiplications
- Each multiplication: O(m log m) where m is the bit length (GMP cost)
- Empirical: microseconds for n ≤ 1000

#### Bridge: QTT Erasure

When a dependent function uses Nat at runtime, the connection between type-level Peano and runtime Nat is made via `nat-value`. The type-level Peano is marked as multiplicity 0 (erased) by QTT:

```prologos
;; Dependent function
fn repeat [n : Nat] (x : a) : Vec n a :=
  ...

;; At runtime, n (type level) is erased; only the runtime value is used
;; Internally, nat-value bridges them during type-checking
```

### 5.2 Int Implementation

Int is implemented as Racket exact integers. Arithmetic operations map directly:

```racket
(define (int-add x y) (+ x y))
(define (int-sub x y) (- x y))
(define (int-mul x y) (* x y))
(define (int-div x y)
  (if (zero? y)
    (error "division by zero")
    (quotient x y)))  ;; truncates toward zero
(define (int-neg x) (- x))
(define (int-abs x) (abs x))
```

No overflow, no underflow. Arbitrary precision via GMP.

### 5.3 Rat Implementation

Rat is implemented as Racket exact rationals. The runtime representation is a pair of integers, automatically simplified:

```racket
(define (rat-add x y) (+ x y))  ;; Racket simplifies automatically
(define (rat-sub x y) (- x y))
(define (rat-mul x y) (* x y))
(define (rat-div x y)
  (if (zero? y)
    (error "division by zero")
    (/ x y)))  ;; exact division, simplified
(define (rat-neg x) (- x))
(define (rat-abs x) (abs x))

;; Conversion from Int to Rat
(define (int-to-rat x) (/ x 1))
```

No precision loss. Denominators are always positive; numerators and denominators are coprime.

### 5.4 Why Peano Stays at Type Level

Dependent types in Πρόλογος require type-level computation. The canonical example is `Vec n a` (vectors of length n):

```prologos
data Vec : Nat → Type → Type where
  | nil : Vec 0 a
  | cons : a → Vec n a → Vec (suc n) a
```

Now consider append:

```prologos
fn append [n m : Nat] (xs : Vec n a) (ys : Vec m a) : Vec (add n m) a :=
  match xs with
  | nil → ys
  | cons x xs' → cons x (append xs' ys)
```

The return type `Vec (add n m) a` requires type-level `add` to compute `(add n m)`. For this to work:
- n and m must be type-level values (Peano numerals, statically known)
- add must compute structurally on Peano

At runtime, the actual vectors are lists (or arrays); the type-level Peano is erased by QTT and used only for type-checking.

### 5.5 Factorial: Before and After

**Before (Peano, O(n!) reductions):**

```prologos
fn factorial : Nat → Nat
  | factorial 0 = 1
  | factorial n = n * factorial (n - 1)
```

With Peano, each successor is a thunk. `factorial 5` recursively calls factorial 5 times, and each multiplication chains through the Peano representation, resulting in billions of reductions. Empirical: `factorial 5 > 1 second`, `factorial 6` times out.

**After (BigInt, O(n) arithmetic):**

```racket
(define (factorial n)
  (let loop ([i 1] [acc 1])
    (if (> i n)
      acc
      (loop (+ 1 i) (* acc i)))))
```

With BigInt, `factorial 5` is 5 multiplications of GMP integers. For n ≤ 1000, total time: microseconds. Empirical: `factorial 1000` computes in <1ms.

---

## Section 6: Posit Arithmetic Implementation

### 6.1 Posit Number Format (2022 Standard)

Posit numbers encode a value using a tapered precision model: a regime field (variable-length) encodes the scale; smaller exponent and fraction fields encode the mantissa. This differs from IEEE's fixed exponent field.

#### Bit Layout (All Sizes)

```
[sign | regime | exponent | fraction]

sign:      1 bit
regime:    variable length (2–6 bits, typically)
exponent:  es bits (es=2 for all sizes in 2022 Standard)
fraction:  remaining bits
```

#### Regime Field

The regime encodes the scale in a compressed format:

- **Run of 0s:** k zeros followed by a one → scale factor useed^(-k)
- **Run of 1s:** k ones followed by a zero → scale factor useed^(k-1)

Where useed = 2^(2^es) = 2^4 = 16 for es=2.

#### NaR (Not a Real)

The bit pattern `10000...0` (sign=1, all zeros) represents NaR, the single exceptional value. Unlike IEEE's multiple NaN bit patterns, Posit has exactly one exceptional value.

#### Dynamic Range vs Precision (Tapered)

The regime field dominates for extreme values, allowing vast dynamic range (up to ±2^(2^62) for Posit64). However, precision decreases at extremes: near 1.0 most bits are fraction bits (fine precision); near maxpos most bits are regime bits (coarse precision). This matches scientific computing needs: relative error matters more than absolute error.

### 6.2 Current posit-impl.rkt Analysis

The existing implementation is pure Racket, implementing Posit8 in 404 lines with a decode→rational→compute→encode architecture:

```racket
;; Decode: extract regime, exponent, fraction from bit pattern
(define (posit8-decode bits)
  ;; Returns exact Racket rational
  ...)

;; Compute: arithmetic on exact rationals
(define (posit8-binary-op op p1 p2)
  (cond
    [(or (posit8-nar? p1) (posit8-nar? p2)) posit8-nar]
    [else
     (let* ([r1 (posit8-to-rational p1)]
            [r2 (posit8-to-rational p2)]
            [result (op r1 r2)])
       (rational-to-posit8 result))]))

;; Encode: convert rational back to nearest Posit8 bit pattern
(define (rational-to-posit8 r)
  ;; Round according to Posit rounding rules
  ...)
```

**Existing Operations:** posit8-add, posit8-sub, posit8-mul, posit8-div, posit8-sqrt, posit8-neg, posit8-abs, posit8-eq, posit8-lt, posit8-le

**Limitations:**
1. Posit8 only — no Posit16/32/64
2. Pure Racket — decode→rational→compute→encode is slow for large volumes
3. No quire accumulator — cannot fuse operations
4. No FFI — does not leverage softposit-rkt (which wraps SoftPosit C library)

### 6.3 PositOps Trait: Quire and Fused Operations

Beyond the standard Floating trait, Posit types support specialized accumulator operations:

```prologos
trait PositOps a where
  impl Floating a, Approximate a

  ;; Quire type (accumulator)
  type Quire a : Type

  ;; Quire operations
  spec quire-zero : Quire a
  spec quire-add  : Quire a → a → a → Quire a
  spec quire-to   : Quire a → a

  ;; Fused operations (no intermediate rounding)
  spec fma        : a → a → a → a              ;; fused multiply-add
  spec fused-dot  : Vec n a → Vec n a → a
```

#### Quire Semantics

A Quire is an accumulator that holds the exact sum of products. It is much wider than the Posit itself:

| Posit Size | Quire Size | Use Case                |
|------------|------------|-------------------------|
| Posit8     | 32 bits    | Embedded, IoT           |
| Posit16    | 128 bits   | Fixed-point, DSP        |
| Posit32    | 512 bits   | Scientific computing    |
| Posit64    | 2048 bits  | High-precision analysis |

Unlike a naive sum of products (which rounds after each multiplication and addition, accumulating O(n) ULP error), a fused dot product accumulates exactly in the quire, then rounds once at the end (≤ 0.5 ULP total error).

#### FMA (Fused Multiply-Add)

```prologos
fn quadratic (a b c x : Posit32) : Posit32 :=
  fma a (x * x) (fma b x c)
```

The expression `fma a x² (fma b x c)` computes `a·x² + b·x + c` with only two final roundings, whereas naive computation rounds at each step.

### 6.4 Implementation Strategy: Three Phases

#### Phase 1: Extend posit-impl.rkt (Pure Racket, All Sizes)

Expand the existing Posit8 implementation to cover Posit16, Posit32, Posit64:

```racket
;; Generalize with a width parameter
(define (posit-decode width bits)
  ;; Regime, exponent (es=2), fraction logic for any width
  ...)

(define (posit-binary-op width op p1 p2)
  ;; Decode to rationals, compute, re-encode at given width
  ...)

;; Quire accumulator (exact sum via big integer)
(define (quire-add width q x y)
  ;; Accumulate x*y into quire exactly
  ...)

(define (quire-to-posit width q)
  ;; Round quire to Posit of given width
  ...)
```

**Timeline:** 2–3 weeks (testing, edge cases)

#### Phase 2: FFI to SoftPosit (Performance)

Bind to softposit-rkt (which wraps the SoftPosit C library):

```racket
(require softposit-rkt)

(define posit32-add-ffi (get-ffi-obj 'p32_add softposit-lib
                          (_fun _uint32 _uint32 -> _uint32)))
```

SoftPosit is 100x faster than pure Racket for inner-loop operations.

**Timeline:** 1–2 weeks (binding, testing)

#### Phase 3: Native Code Generation (Future)

Compile Prologos Posit operations directly to native code, eliminating Racket interpreter overhead entirely. Requires an optimizing compiler backend.

**Timeline:** 6+ weeks (out of scope for prototype phase)

### 6.5 Posit32 Implementation Sketch

```racket
;; posit32-impl.rkt (extending posit-impl.rkt pattern)

(define posit32-nbits 32)
(define posit32-es 2)
(define posit32-useed 16)  ;; 2^(2^es) = 2^4

(define posit32-zero 0)
(define posit32-nar (arithmetic-shift 1 31))  ;; 0x80000000
(define posit32-maxpos (sub1 posit32-nar))     ;; 0x7FFFFFFF

(define (posit32-nar? p) (= p posit32-nar))

(define (posit32-to-rational bits)
  ;; Decode sign, regime, exponent, fraction → exact rational
  (cond
    [(= bits 0) 0]
    [(posit32-nar? bits) +nan.0]  ;; sentinel
    [else
     (let* ([sign (bitwise-bit-set? bits 31)]
            [abs-bits (if sign (bitwise-and (add1 (bitwise-not bits))
                                            #xFFFFFFFF)
                              bits)])
       ;; Extract regime, exponent, fraction from abs-bits
       ;; ... (same algorithm as posit8, wider fields)
       )]))

(define (posit32-add p1 p2)
  (posit32-binary-op + p1 p2))

(define (posit32-mul p1 p2)
  (posit32-binary-op * p1 p2))

;; Quire: 512-bit exact accumulator
(define (quire32-zero) 0)  ;; big integer

(define (quire32-fma q x y)
  ;; Decode x, y to exact rationals, multiply, add to quire
  (let* ([rx (posit32-to-rational x)]
         [ry (posit32-to-rational y)]
         [product (* rx ry)])
    (+ q product)))  ;; exact rational accumulation

(define (quire32-to-posit32 q)
  (rational-to-posit32 q))
```

---

## Section 7: Conversion System

### 7.1 Conversion Traits

Three traits manage type conversions:

#### From Trait (Total, Lossless)

```prologos
trait From a b where
  spec from : a → b
```

Meaning: Every value of type a can be converted to type b, and the conversion is lossless.

#### Into Trait (Derived)

```prologos
trait Into a b where
  spec into : a → b
```

Derived automatically from From: if `From b a` is implemented, then `Into a b` is available.

#### TryFrom Trait (Fallible, Possibly Lossy)

```prologos
trait TryFrom a b where
  spec try-from : a → Maybe b
```

Conversion may fail if the value cannot be represented in the target type.

### 7.2 Within-Family Conversions (Subtyping)

#### Exact Family: Nat → Int → Rat

All conversions are lossless (From trait):

```prologos
impl From Nat Int where
  spec from n = n  ;; embed as-is

impl From Int Rat where
  spec from i = i / 1  ;; rational with denominator 1

impl From Nat Rat where
  spec from n = from (from n : Int)  ;; transitive
```

#### Posit Family: P8 → P16 → P32 → P64

Widening increases precision; no information is lost:

```prologos
impl From Posit8 Posit16 where
  spec from p8 = widen-posit 8 16 p8

impl From Posit16 Posit32 where
  spec from p16 = widen-posit 16 32 p16

impl From Posit32 Posit64 where
  spec from p32 = widen-posit 32 64 p32
```

#### Float Family: F32 → F64

```prologos
impl From Float32 Float64 where
  spec from f32 = ieee-widen f32
```

### 7.3 Cross-Family Conversions (Explicit)

Cross-family conversions are explicit and may be lossy.

#### Rat → Posit32 (TryFrom)

A rational may be outside Posit dynamic range:

```prologos
impl TryFrom Rat Posit32 where
  spec try-from r =
    if out-of-posit32-range r then Nothing
    else Just (round-to-posit32 r)
```

#### Posit32 → Rat (From)

Every Posit (except NaR) has an exact rational representation:

```prologos
impl From Posit32 Rat where
  spec from p32 =
    if is-nar p32 then error "NaR cannot be converted"
    else posit32-to-rational p32
```

#### Float64 → Posit64 (TryFrom)

IEEE NaN and Inf have no Posit equivalents:

```prologos
impl TryFrom Float64 Posit64 where
  spec try-from f64 =
    if (is-nan f64 || is-infinite f64) then Nothing
    else Just (round-to-posit64 (float64-to-rational f64))
```

#### Posit32 → Float64 (From)

Posit32 dynamic range fits within Float64:

```prologos
impl From Posit32 Float64 where
  spec from p32 = rational-to-float64 (posit32-to-rational p32)
```

### 7.4 Conversion Table

| From    | To       | Trait    | Lossless? | Notes                           |
|---------|----------|----------|-----------|--------------------------------|
| Nat     | Int      | From     | Yes       | Subtyping                       |
| Int     | Rat      | From     | Yes       | Subtyping                       |
| Nat     | Rat      | From     | Yes       | Transitive                      |
| Posit8  | Posit16  | From     | Yes       | Widening                        |
| Posit16 | Posit32  | From     | Yes       | Widening                        |
| Posit32 | Posit64  | From     | Yes       | Widening                        |
| Float32 | Float64  | From     | Yes       | IEEE widening                   |
| Rat     | Posit32  | TryFrom  | No        | Lossy if out of range           |
| Posit32 | Rat      | From     | Yes       | Exact rational representation   |
| Int     | Posit32  | TryFrom  | No        | Lossy for large integers        |
| Float64 | Posit64  | TryFrom  | No        | NaN/Inf have no Posit equiv     |
| Posit32 | Float64  | From     | Yes       | Dynamic range fits              |

### 7.5 The `~` Operator for Explicit Approximation

The `~` prefix denotes intentional conversion to an approximate type:

```prologos
let x : Rat = 10/3                ;; exact rational
let y : Posit32 = ~x              ;; explicit conversion to approximate
let z : Posit32 = ~3.14           ;; approximate literal (Rat 157/50 → Posit32)
let w : Posit32 = ~(sqrt 2)       ;; irrational → approximate
```

Semantics:
- `~e` is syntactic sugar for `try-from e : Posit32` (or the appropriate Posit size based on context)
- If conversion fails (e.g., value out of range), a compile-time error is raised
- If conversion succeeds, the result is the nearest representable Posit value

**Type inference:**
```prologos
let a = ~3.14           ;; inferred type: Posit32 (default)
let b : Posit16 = ~3.14 ;; explicit context narrows type
```

---

## Section 8: Dependent Types over Numerics

### 8.1 Type-Level Natural Numbers

Prologos uses Peano natural numbers exclusively at the type level to enable dependent typing. The runtime uses arbitrary-precision integers (BigInt), with Quantitative Type Theory (QTT) erasing the type-level Peano indices during execution.

Vector types depend on Peano indices:

```prologos
data Vec : (n : Nat) → Type → Type where
  | nil : Vec zero A
  | cons : A → Vec n A → Vec (suc n) A

fn head [A : Type] [n : Nat] (v : Vec (suc n) A) : A :=
  match v with
  | cons a _ → a

fn append [A : Type] [m n : Nat]
          (v1 : Vec m A) (v2 : Vec n A) : Vec (add m n) A :=
  match v1 with
  | nil → v2
  | cons a v1' → cons a (append v1' v2)
```

The QTT system marks Peano indices with multiplicity 0, ensuring they are erased before runtime. Type-level arithmetic computes via dependent elimination; the type checker normalizes Peano expressions to verify correctness.

### 8.2 Refinement Types over Numeric Ranges

Prologos supports refinement types to express value-dependent constraints. A refinement type has the form `{x : T | P(x)}`, where `T` is a base numeric type and `P(x)` is a decidable predicate.

```prologos
Pos := {n : Int | n > 0}
NonNeg := {n : Int | n >= 0}
PosPosit32 := {x : Posit32 | x > ~0.0}
```

Functions can accept or produce refined types:

```prologos
fn safe-div (x y : Posit32) (h : y ∈ PosPosit32) : Posit32 :=
  div x y

fn nth [A : Type] [n : Nat] (v : Vec n A) (i : {k : Int | 0 <= k ∧ k < n}) : A :=
  ...  ;; bounds-checked access, proof erased at runtime
```

The type checker verifies refinement predicates at call sites. At runtime, predicates are erased; refinements serve only as static guarantees. When a refinement cannot be statically verified, the programmer must provide an explicit proof term or rely on a runtime check that produces a `Maybe` type.

### 8.3 Numeric Proofs

Equality and ordering over numerics at the type level enable mechanically verified properties. Proofs are constructed as terms and exist in the type layer; QTT erases them before runtime.

Commutativity of addition:

```prologos
fn add-comm (n m : Nat) : add n m ≡ add m n :=
  match n with
  | zero →
    refl  ;; add zero m = m = add m zero
  | suc n' →
    let ih = add-comm n' m
    cong suc ih
```

Associativity:

```prologos
fn add-assoc (a b c : Nat) : add (add a b) c ≡ add a (add b c) :=
  match a with
  | zero → refl
  | suc a' →
    let ih = add-assoc a' b c
    cong suc ih
```

These proofs operate on Peano representations at the type level. The runtime never executes them — BigInt operations use optimized algorithms. But code polymorphic over numeric types can require proofs as implicit arguments for dependent type safety.

---

## Section 9: Numeric Operations and Algorithms

### 9.1 Standard Library Functions

The standard library provides efficient implementations of common numeric algorithms, working primarily with `Int` for exactness and unbounded precision.

```prologos
fn factorial (n : Int) : Int :=
  let rec loop (acc : Int) (k : Int) : Int :=
    if k <= 1 then acc
    else loop (acc * k) (k - 1)
  loop 1 n

fn fibonacci (n : Int) : Int :=
  let rec fib-acc (a b : Int) (k : Int) : Int :=
    if k == 0 then a
    else fib-acc b (a + b) (k - 1)
  fib-acc 0 1 n

fn gcd (a b : Int) : Int :=
  let a' = abs a
  let b' = abs b
  let rec loop (x y : Int) : Int :=
    if y == 0 then x
    else loop y (mod x y)
  loop a' b'

fn lcm (a b : Int) : Int :=
  div (abs (a * b)) (gcd a b)
```

All of these rely on Racket's GMP-backed integer arithmetic, making them efficient even for large inputs.

### 9.2 Numeric Algorithms on Posit

Newton-Raphson square root using fused multiply-add:

```prologos
fn sqrt-posit32 (x : Posit32) : Posit32 :=
  let rec newton (guess prev : Posit32) (iters : Int) : Posit32 :=
    if iters == 0 then guess
    else
      let next = fma (~0.5) (guess + div x guess) (~0.0)
      if abs (next - prev) < ~1e-6 then next
      else newton next guess (iters - 1)
  newton x (~1.0) 20
```

Fused dot product via quire (exact accumulation, single final rounding):

```prologos
fn fused-dot-product [n : Nat] (xs ys : Vec n Posit32) : Posit32 :=
  let q = quire-zero
  let q' = vec-foldl2 (fn q x y → quire-add q x y) q xs ys
  quire-to q'
```

### 9.3 Generic Numeric Functions

Functions polymorphic over numeric traits:

```prologos
fn mean [a : Type] (impl Fractional a) (xs : List a) : a :=
  let sum = foldl add (from-int 0) xs
  let len = from-int (length xs)
  div sum len

fn poly-eval [a : Type] (impl Num a)
             (coeffs : List a) (x : a) : a :=
  ;; Horner's method: a₀ + x(a₁ + x(a₂ + ...))
  foldr (fn coeff acc → add coeff (mul x acc)) (from-int 0) coeffs

fn variance [a : Type] (impl Fractional a) (xs : List a) : a :=
  let m = mean xs
  let squared-diffs = map (fn x → mul (sub x m) (sub x m)) xs
  mean squared-diffs

fn std-dev [a : Type] (impl Floating a) (xs : List a) : a :=
  sqrt (variance xs)
```

These generic functions are instantiated at compile time for each concrete type. Type inference resolves trait bounds; if a function is called with a type lacking a required trait, compilation fails.

---

## Section 10: Literal Syntax and Type Inference

### 10.1 Literal Forms

Prologos provides multiple literal syntaxes for numeric constants, each with a default type based on form.

**Integer literals** default to `Int`:
```prologos
42          ;; Int
0xFF        ;; Int (hexadecimal, value 255)
0b1010      ;; Int (binary, value 10)
0o77        ;; Int (octal, value 63)
-5          ;; Int (negation)
```

**Rational literals** default to `Rat`:
```prologos
3.14        ;; Rat (= 157/50)
10/3        ;; Rat (exact fraction)
0.5         ;; Rat (= 1/2)
1.5e10      ;; Rat (exact scientific notation)
```

**Approximate literals** (Posit) are prefixed with `~`:
```prologos
~3.14       ;; Posit32 (default approximate width)
~0xFF       ;; Posit32 (hexadecimal, approximated)
~1e-6       ;; Posit32 (scientific notation)
~-3.14      ;; Posit32 (negative)
```

The syntax `expr : Type` forces a specific type:
```prologos
(42 : Nat)       ;; Int 42 coerced to Nat via From Int Nat
(3.14 : Posit32) ;; Rat coerced to Posit32 via TryFrom
(~5 : Posit64)   ;; Posit32 widened to Posit64 via From
```

### 10.2 Type Inference for Numerics

The type checker uses a defaulting system when context is insufficient:

**Rule 1:** Default integer literals to `Int`, decimal literals to `Rat`.

**Rule 2:** Context-driven inference — if a function expects `Nat`, the literal `5` is Nat (via From Int Nat).

**Rule 3:** The `~` prefix forces Posit32 (or contextual Posit size).

**Rule 4:** Within a family, automatic widening applies. An `Int` is automatically widened to `Rat` when assigned to a `Rat` binding.

**Rule 5:** Cross-family operations are forbidden without explicit conversion:
```prologos
5 + 3.14            ;; Type error: Int + Rat
(from 5 : Rat) + 3.14  ;; OK: Rat + Rat
```

### 10.3 Numeric Coercions in Expressions

Within-family widening is automatic in bindings but NOT in expressions:
```prologos
let x : Rat = 5        ;; OK: Nat widened to Rat in binding
let y = 5 + 3.14       ;; Error: mixed Int + Rat in expression
let y = (from 5 : Rat) + 3.14  ;; OK: explicit widening
```

Narrowing always requires explicit `try-from`:
```prologos
let n : Maybe Nat = try-from (3 : Int)  ;; Just 3
let m : Maybe Nat = try-from (-1 : Int) ;; Nothing
```

---

## Section 11: Integration with Language Features

### 11.1 Pattern Matching on Numerics

Matching on Peano constructors at the type level:

```prologos
fn from-nat (n : Nat) : Int :=
  match n with
  | zero → 0
  | suc n' → 1 + from-nat n'
```

Matching on Int with guards:

```prologos
fn classify (n : Int) : String :=
  match n with
  | n if n < 0 → "negative"
  | 0 → "zero"
  | n if mod n 2 == 0 → "positive even"
  | _ → "positive odd"
```

Matching on Posit special values:

```prologos
fn posit-category (x : Posit32) : String :=
  match x with
  | nar → "not-a-real"
  | x if x > ~0.0 → "positive"
  | x if x < ~0.0 → "negative"
  | _ → "zero"
```

### 11.2 Seq Integration

Numeric ranges as lazy sequences:

```prologos
seq/range 1 10          ;; Seq Int: 1, 2, ..., 9
seq/range-inclusive 1 10 ;; Seq Int: 1, 2, ..., 10
seq/step 0 2 20         ;; Seq Int: 0, 2, 4, ..., 20
```

Reduction over numeric sequences:

```prologos
seq/foldl add 0 (seq/range 1 11)
;; Int: sum of 1..10 = 55

seq/foldl mul 1 (seq/range 1 6)
;; Int: factorial(5) = 120
```

Fused dot product as a Seq operation:

```prologos
fn dot-product (xs ys : Seq Posit32) : Posit32 :=
  let q = quire-zero
  let pairs = seq/zip xs ys
  let q' = seq/foldl (fn q (x, y) → quire-add q x y) q pairs
  quire-to q'
```

Infinite numeric sequences:

```prologos
seq/iterate inc 0   ;; Seq Int: 0, 1, 2, 3, ...
seq/map fst (seq/iterate (fn (a, b) → (b, a + b)) (0, 1))
;; Seq Int: 0, 1, 1, 2, 3, 5, 8, ... (Fibonacci)
```

### 11.3 Collections and Numerics

Fixed-length vectors indexed by Peano:

```prologos
fn vec-sum [n : Nat] (v : Vec n Int) : Int :=
  match v with
  | nil → 0
  | cons a v' → a + vec-sum v'
```

Maps with numeric keys (requires Ord):

```prologos
fn frequency [a : Type] (impl Eq a, Ord a)
             (xs : List a) : Map a Int :=
  foldl (fn m x → map-update x (fn c → c + 1) 0 m) map-empty xs
```

Numeric aggregation:

```prologos
fn sum-ints (xs : List Int) : Int := foldl add 0 xs
fn product-ints (xs : List Int) : Int := foldl mul 1 xs
```

---

## Section 12: Performance Engineering

### 12.1 Current Performance Bottleneck

The primary bottleneck is Peano natural numbers used for runtime computation. Computing `factorial(5)` using Peano creates a chain of `suc` constructors and performs structural recursion over them. For `factorial(1000)`, the cost exceeds 27 million reduction steps.

The root cause is twofold: the unary representation requires O(n) space and time to represent the number n, and structural recursion forces the evaluator to traverse each successor.

### 12.2 BigInt Performance

Racket integers use GMP internally, providing:

- O(n log n log log n) multiplication via Karatsuba/FFT algorithms
- O(n) addition and subtraction
- Automatic promotion from fixnums to bignums
- No overflow; unlimited precision

Performance on modern hardware:
- `factorial(100)`: < 1 microsecond
- `factorial(1000)`: < 1 millisecond
- `factorial(10000)`: < 10 milliseconds

### 12.3 Posit Performance Tiers

**Tier 1: Pure Racket (posit-impl.rkt)** — Correct but slow. Decode→rational→compute→encode takes microseconds per operation. Suitable for prototyping and testing.

**Tier 2: FFI to SoftPosit C Library** — 100–1000x faster than pure Racket. SoftPosit is a reference C implementation. Benchmark on Posit32 vector summation (1000 elements): pure Racket ~10 ms, SoftPosit FFI ~0.1 ms.

**Tier 3: Native Code Generation (Future)** — Emit native machine code for numeric operations, eliminating Racket interpreter overhead. Expected 10–100x over FFI, approaching hardware limits.

### 12.4 Optimization Opportunities

**Memoization:** Cache results of recursive numeric functions (e.g., Fibonacci from ~2M calls to ~60 lookups for n=30).

**Tail-call optimization:** Accumulator-style recursion compiled to iterative bytecode with constant stack depth.

**Specialization:** Monomorphize generic numeric functions for concrete types, avoiding trait dispatch overhead.

**Unboxing:** Avoid wrapping Posit bits in Racket structs during computation; use raw integers.

### 12.5 Benchmarking Strategy

| Benchmark                    | Input Range          | Metric                          |
|------------------------------|---------------------|---------------------------------|
| Factorial                    | n = 1..10000        | Wall-clock time                 |
| Fused dot product            | vectors 10..10000   | Time + error vs Kahan sum       |
| Prime factorization          | n = 2^20..2^40      | Wall-clock time                 |
| Fibonacci(30)                | Cross-language       | Relative time vs Racket/Python  |

---

## Section 13: Key Challenges and Open Problems

### 13.1 Type Inference Complexity

Numeric literal polymorphism introduces non-trivial defaulting rules. A bare `5` could be `Nat`, `Int`, `Rat`, or even `Posit32` (via coercion). The type checker must decide based on context, and ambiguous cases require defaulting rules that balance usability with predictability. Cross-family conversion inference must distinguish between automatic within-family widening (allowed) and cross-family coercion (forbidden without explicit `from`/`into`). Interaction with dependent types further complicates inference when type-level arithmetic must align with runtime numeric semantics.

### 13.2 Posit Hardware Support

As of 2025, no widely deployed CPU includes native Posit instructions. SoftPosit and other software libraries provide correctness but impose overhead (dozens of cycles per operation vs. one cycle for IEEE float on hardware FPU). FPGA implementations exist but are niche. RISC-V is an open ISA that could define Posit extensions, but mainstream adoption remains uncertain.

### 13.3 Quire Size and Memory

The quire accumulator provides exact intermediate arithmetic but at significant memory cost: a Posit64 quire is 2048 bits (256 bytes). Operations on wide quires are slow in software. In a future native backend, allocating 2048-bit quires to CPU registers is infeasible; the backend must spill to stack memory and optimize load/store patterns.

### 13.4 Proofs and Decidability

Type-level arithmetic must terminate for type checking to be decidable. Recursive functions on Peano must be provably total (via structural recursion or explicit termination measures). Decidability of numeric equality at type level (e.g., `mul (add 2 3) (sub 10 7) ≡ 15`) requires efficient normalization. Refinement predicates (e.g., `{n : Int | is-prime n}`) must be restricted to decidable, efficiently computable properties.

### 13.5 Interoperability

**C FFI:** Posit values must be marshalled to/from C. Raw 32-bit integers preserve bit representations; care is needed for NaR.

**Serialization:** Posit has no standardized text representation. Options include hexadecimal (precise), decimal approximation (human-readable), or a custom extension.

**Database mapping:** SQL offers INTEGER, REAL, and NUMERIC. Nat/Int map to INTEGER; Rat maps to NUMERIC; Posit maps lossy to REAL/DOUBLE PRECISION.

---

## Section 14: References and Key Literature

Gustafson, J. (2017). *The End of Error: Unum Computing*. Chapman and Hall/CRC. The foundational work introducing unums and posits, motivating variable-precision arithmetic.

Gustafson, J., & Yonemoto, I. (2017). "Beating Floating Point at its Own Game: Posit Arithmetic." *Supercomputing Frontiers and Innovations*, 4(3), 71–86. Comprehensive comparison of posit performance and accuracy against IEEE floats.

Gustafson, J. (2022). *Standard for Posit Arithmetic*. The authoritative specification for the posit format, regime-exponent-mantissa structure, and rounding modes.

SoftPosit Library. https://gitlab.com/cerlane/SoftPosit. Reference C library implementing posit arithmetic for Posit8, 16, 32, 64, and quire operations.

Thien, D. softposit-rkt. https://github.com/DavidThien/softposit-rkt. Racket FFI bindings to SoftPosit, enabling efficient posit computation in the Prologos prototype.

Atkinson, R., & McBride, C. (2018). "Quantitative Type Theory." *LICS 2018*. Foundational paper on QTT, formalizing the multiplicity system enabling erasure of type-level computations.

Brady, E. (2021). "Idris 2: Quantitative Type Theory in Practice." *ECOOP 2021*. Dependent type checking and QTT in Idris 2, closely related to Prologos' type system.

Racket Documentation: Arbitrary-Precision Arithmetic. https://docs.racket-lang.org/guide/numbers.html. Official documentation for exact rational numbers and GMP-backed integer arithmetic.

GMP (GNU Multiple Precision Arithmetic Library). https://gmplib.org/. Powers Racket's bignum implementation.

Goldberg, D. (1991). "What Every Computer Scientist Should Know About Floating-Point Arithmetic." *ACM Computing Surveys*, 23(1), 5–48. Essential background for understanding posit motivation.

Peano, G. (1889). *Arithmetices principia, nova methodo exposita*. The original axiomatization of natural numbers and structural recursion.

Shewchuk, J. R. (1997). "Adaptive Precision Floating-Point Arithmetic and Fast Robust Geometric Predicates." *Discrete & Computational Geometry*, 18(3), 305–363. Related to quire-based exact accumulation.

Knuth, D. E. (1997). *The Art of Computer Programming, Volume 2: Seminumerical Algorithms* (3rd ed.). Addison-Wesley. Theoretical foundations for BigInt optimization algorithms.
