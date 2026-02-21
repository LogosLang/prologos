# Research Report: Unum Innovations and Next-Generation Number Systems

## From IEEE 754 Failures to Posit Arithmetic, Valids, Quires, and Beyond

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [The Problem: IEEE 754 and Its Discontents](#2-the-problem-ieee-754-and-its-discontents)
   - 2.1 [The IEEE 754 Standard](#21-the-ieee-754-standard)
   - 2.2 [Fundamental Limitations](#22-fundamental-limitations)
   - 2.3 [Catastrophic Real-World Failures](#23-catastrophic-real-world-failures)
   - 2.4 [The Wasted Bit-Pattern Space](#24-the-wasted-bit-pattern-space)
3. [Gustafson's Type I Unums: The Original Vision](#3-gustafsons-type-i-unums-the-original-vision)
   - 3.1 [The Core Insight: Variable-Width with the Ubit](#31-the-core-insight-variable-width-with-the-ubit)
   - 3.2 [The Utag: Self-Descriptive Metadata](#32-the-utag-self-descriptive-metadata)
   - 3.3 [The U-Layer and G-Layer Architecture](#33-the-u-layer-and-g-layer-architecture)
   - 3.4 [Strengths and Weaknesses of Type I](#34-strengths-and-weaknesses-of-type-i)
4. [Type II Unums: The Projective Real Number Line](#4-type-ii-unums-the-projective-real-number-line)
   - 4.1 [The Projective Reals](#41-the-projective-reals)
   - 4.2 [Fixed-Size with Lookup Tables](#42-fixed-size-with-lookup-tables)
   - 4.3 [Strengths and Weaknesses of Type II](#43-strengths-and-weaknesses-of-type-ii)
5. [Type III: Posit Arithmetic](#5-type-iii-posit-arithmetic)
   - 5.1 [The Posit Format: Regime, Exponent, Fraction](#51-the-posit-format-regime-exponent-fraction)
   - 5.2 [Tapered Precision: More Bits Where They Matter](#52-tapered-precision-more-bits-where-they-matter)
   - 5.3 [The Useed and Dynamic Range](#53-the-useed-and-dynamic-range)
   - 5.4 [Mathematical Properties of Posits](#54-mathematical-properties-of-posits)
   - 5.5 [Posits vs. IEEE 754 Floats: Comparative Analysis](#55-posits-vs-ieee-754-floats-comparative-analysis)
   - 5.6 [The 2022 Posit Standard](#56-the-2022-posit-standard)
6. [Valids: Interval Arithmetic Done Right](#6-valids-interval-arithmetic-done-right)
   - 6.1 [Bounded Uncertainty with Posit Pairs](#61-bounded-uncertainty-with-posit-pairs)
   - 6.2 [The Ubit as Openness Indicator](#62-the-ubit-as-openness-indicator)
   - 6.3 [Fusion Operations for Valids](#63-fusion-operations-for-valids)
   - 6.4 [Connections to Classical Interval Arithmetic](#64-connections-to-classical-interval-arithmetic)
7. [Quires: The Exact Accumulator](#7-quires-the-exact-accumulator)
   - 7.1 [The Kulisch Accumulator Adapted for Posits](#71-the-kulisch-accumulator-adapted-for-posits)
   - 7.2 [Fused Operations: Dot Product and Multiply-Accumulate](#72-fused-operations-dot-product-and-multiply-accumulate)
   - 7.3 [Exact Inner Products and Numerical Stability](#73-exact-inner-products-and-numerical-stability)
   - 7.4 [Quire Width and Implementation Considerations](#74-quire-width-and-implementation-considerations)
8. [Cutting-Edge Research: Beyond Posits](#8-cutting-edge-research-beyond-posits)
   - 8.1 [Takum Arithmetic: An Alternative to the Regime Field](#81-takum-arithmetic-an-alternative-to-the-regime-field)
   - 8.2 [LNS-Madam: Logarithmic Number Systems for ML](#82-lns-madam-logarithmic-number-systems-for-ml)
   - 8.3 [Block Floating Point (BFP) and Microscaling (MSFP)](#83-block-floating-point-bfp-and-microscaling-msfp)
   - 8.4 [Low-Precision Formats: bfloat16 and TensorFloat-32](#84-low-precision-formats-bfloat16-and-tensorfloat-32)
   - 8.5 [IEEE P3109: Standardizing Low-Precision Formats](#85-ieee-p3109-standardizing-low-precision-formats)
   - 8.6 [Stochastic Rounding and Probabilistic Arithmetic](#86-stochastic-rounding-and-probabilistic-arithmetic)
9. [Hardware Implementations](#9-hardware-implementations)
   - 9.1 [PACoGen: Parameterized Posit Arithmetic Core Generator](#91-pacogen-parameterized-posit-arithmetic-core-generator)
   - 9.2 [PERCIVAL: RISC-V with Posit Extensions](#92-percival-risc-v-with-posit-extensions)
   - 9.3 [CalligoTech TUNGA: Commercial Posit ASIC](#93-calligotech-tunga-commercial-posit-asic)
   - 9.4 [Deep PeNSieve: FPGA Posit Neural Network Accelerator](#94-deep-pensieve-fpga-posit-neural-network-accelerator)
   - 9.5 [FPGA and GPU Approaches](#95-fpga-and-gpu-approaches)
10. [The Kahan Debate and Criticisms](#10-the-kahan-debate-and-criticisms)
    - 10.1 [William Kahan's Criticisms](#101-william-kahans-criticisms)
    - 10.2 [De Dinechin's Scale-Invariance Critique](#102-de-dinechins-scale-invariance-critique)
    - 10.3 [The Reproducibility Question](#103-the-reproducibility-question)
    - 10.4 [Responses from the Posit Community](#104-responses-from-the-posit-community)
11. [Academic Research and Applications (2020–2026)](#11-academic-research-and-applications-20202026)
    - 11.1 [Posits in Machine Learning](#111-posits-in-machine-learning)
    - 11.2 [Sparse Linear Solvers and Scientific Computing](#112-sparse-linear-solvers-and-scientific-computing)
    - 11.3 [Computer Vision and Signal Processing](#113-computer-vision-and-signal-processing)
    - 11.4 [Climate Modeling and Geophysics](#114-climate-modeling-and-geophysics)
    - 11.5 [Formal Verification of Posit Arithmetic](#115-formal-verification-of-posit-arithmetic)
12. [Software Libraries and Implementations](#12-software-libraries-and-implementations)
    - 12.1 [SoftPosit: The Reference Implementation](#121-softposit-the-reference-implementation)
    - 12.2 [Universal: Stillwater's Comprehensive C++ Library](#122-universal-stillwaters-comprehensive-c-library)
    - 12.3 [Python Ecosystem: sfpy and Beyond](#123-python-ecosystem-sfpy-and-beyond)
    - 12.4 [Julia: SoftPosit.jl](#124-julia-softpositjl)
    - 12.5 [Rust: softposit-rs](#125-rust-softposit-rs)
    - 12.6 [Haskell and Functional Ecosystems](#126-haskell-and-functional-ecosystems)
    - 12.7 [Other Languages and Emerging Efforts](#127-other-languages-and-emerging-efforts)
13. [Interval Arithmetic Libraries and Connections](#13-interval-arithmetic-libraries-and-connections)
    - 13.1 [MPFI and Arb](#131-mpfi-and-arb)
    - 13.2 [Julia IntervalArithmetic.jl](#132-julia-intervalarithmeticjl)
    - 13.3 [Boost.Interval and iRRAM](#133-boostinterval-and-irram)
    - 13.4 [Relationship to Valids](#134-relationship-to-valids)
14. [Implications for Language Design](#14-implications-for-language-design)
    - 14.1 [First-Class Number Types: A Taxonomy](#141-first-class-number-types-a-taxonomy)
    - 14.2 [Dependent Types for Precision Tracking](#142-dependent-types-for-precision-tracking)
    - 14.3 [Quire Integration and Fusion Operations](#143-quire-integration-and-fusion-operations)
    - 14.4 [Literal Syntax and Conversion Semantics](#144-literal-syntax-and-conversion-semantics)
    - 14.5 [Valid Types and Interval Propagation](#145-valid-types-and-interval-propagation)
    - 14.6 [Arbitrary Precision and Efficient Representation](#146-arbitrary-precision-and-efficient-representation)
    - 14.7 [Error Handling: No Silent Wrapping](#147-error-handling-no-silent-wrapping)
    - 14.8 [Compilation Targets and LLVM Considerations](#148-compilation-targets-and-llvm-considerations)
    - 14.9 [A Concrete Design Sketch for Πρόλογος](#149-a-concrete-design-sketch-for-πρόλογος)
15. [References and Key Literature](#15-references-and-key-literature)

---

## 1. Introduction

The representation of real numbers in digital computers has been one of the most consequential and least-examined foundational decisions in the history of computing. Since its ratification in 1985 and revision in 2008, the IEEE 754 standard for floating-point arithmetic has become the near-universal representation for real-valued computation. Yet IEEE 754 carries with it a host of mathematical pathologies—denormalized numbers, signed zeros, multiple NaN bit patterns, and the notorious phenomenon of catastrophic cancellation—that have contributed to costly engineering failures and impose a persistent tax on the mental model of every programmer who works with numerical code.

In 2015, John L. Gustafson published *The End of Error: Unum Computing*, introducing a radical rethinking of how computers should represent real numbers. Gustafson's "universal numbers" (unums) proposed replacing IEEE 754's fixed-format representation with a self-describing, variable-width format that could track the uncertainty inherent in every numerical result. This initial idea (now called "Type I unums") evolved rapidly through a Type II formulation based on projective real numbers, before crystallizing into the **posit** format (Type III unums)—a compact, fixed-width representation that delivers more accuracy per bit than IEEE 754 floats across a wide dynamic range, while eliminating the worst mathematical pathologies of the older standard.

The posit format has been accompanied by two complementary innovations: **valids**, which provide rigorous interval arithmetic using posit pairs, and **quires**, which are exact dot-product accumulators that enable reproducible, correctly-rounded inner products—eliminating one of the most pernicious sources of non-reproducibility in scientific computing.

This report provides an exhaustive survey of the unum lineage from its origins through the current state of the art. We examine the theoretical foundations, trace the evolution through Types I, II, and III, catalog the cutting-edge research that has extended and critiqued Gustafson's ideas, survey the hardware and software implementations that exist today, and—most importantly for our purposes—extract concrete design recommendations for incorporating next-generation number systems into a new programming language. We are particularly concerned with how these innovations can be integrated into a language featuring dependent types, arbitrary-precision arithmetic, and a commitment to never silently wrapping integer values—a language like Πρόλογος.

---

## 2. The Problem: IEEE 754 and Its Discontents

### 2.1 The IEEE 754 Standard

The IEEE 754 standard (originally 1985, revised 2008, further amended 2019) defines formats for binary and decimal floating-point numbers. The most commonly used formats are:

- **binary32** (single precision): 1 sign bit, 8 exponent bits, 23 fraction bits (32 bits total)
- **binary64** (double precision): 1 sign bit, 11 exponent bits, 52 fraction bits (64 bits total)
- **binary128** (quad precision): 1 sign bit, 15 exponent bits, 112 fraction bits (128 bits total)

A floating-point number is interpreted as (-1)^s × 2^(e - bias) × 1.fraction (with an implicit leading 1 for normalized numbers). This gives a fixed trade-off between range and precision: the exponent field determines the range, the fraction field determines the precision, and neither can borrow bits from the other.

### 2.2 Fundamental Limitations

The IEEE 754 format suffers from several well-documented problems:

**Wasted bit patterns.** IEEE 754 floats dedicate bit patterns to two values of zero (+0 and -0), two values of infinity (+∞ and -∞), and a vast space of NaN (Not-a-Number) encodings. In binary32, there are 16,777,214 NaN bit patterns—roughly 0.4% of the representable space—that carry no useful numerical information. The distinction between +0 and -0 creates subtle comparison bugs: (-0 == +0) is true, but 1/(-0) and 1/(+0) give different results.

**Fixed precision across the range.** A 32-bit float gives the same number of fraction bits whether the value is near 1.0 or near 10^30. Near 1.0, where most numerical computation happens, precision is reasonable; at the extremes of the range, the gaps between representable numbers become enormous, yet precision doesn't increase where values are dense.

**Non-closure of operations.** Basic arithmetic operations can produce NaN or infinity, creating values that "poison" subsequent computation. NaN propagation is one of the most insidious debugging challenges in numerical code because a NaN at the end of a pipeline could have been introduced anywhere upstream.

**Catastrophic cancellation.** Subtracting nearly equal floating-point values can destroy most significant digits in a single operation. The expression (a + b) - a can lose all precision of b if b is much smaller than a, even though the exact result is simply b.

**Non-associativity.** Floating-point addition is not associative: (a + b) + c may give a different result than a + (b + c). This means that parallelizing a sum—a seemingly trivial operation—can change the result, making parallel numerical code inherently non-reproducible.

**Rounding mode complexity.** IEEE 754 specifies multiple rounding modes (round-to-nearest-even, round toward zero, round toward +∞, round toward -∞), and the standard permits implementations to choose different modes in different contexts, further undermining reproducibility.

### 2.3 Catastrophic Real-World Failures

The limitations of IEEE 754 have contributed to real-world disasters:

**The Patriot missile failure (1991).** During the Gulf War, a Patriot missile battery in Dhahran, Saudi Arabia, failed to intercept an incoming Scud missile, resulting in 28 deaths. The root cause was a floating-point rounding error in the system clock: the time in tenths of seconds was multiplied by 1/10, which is not exactly representable in binary. After 100 hours of continuous operation, the accumulated error was approximately 0.3433 seconds—enough to shift the predicted location of the incoming missile by over 600 meters.

**The Ariane 5 explosion (1996).** The European Space Agency's Ariane 5 rocket self-destructed 37 seconds after launch due to an integer overflow: a 64-bit floating-point value representing horizontal velocity was converted to a 16-bit signed integer, causing an exception that shut down both the primary and backup inertial reference systems. The loss was estimated at $370 million.

**The Vancouver Stock Exchange index (1982).** The Vancouver Stock Exchange introduced a new index initialized at 1000.000. After 22 months of truncation errors (rather than rounding) in index calculations performed thousands of times daily, the index had drifted to 524.881, when its correctly computed value should have been approximately 1098.892.

These cases illustrate that floating-point errors are not merely academic curiosities; they have concrete, sometimes fatal, consequences.

### 2.4 The Wasted Bit-Pattern Space

Gustafson's key observation was that IEEE 754 wastes representable bit patterns on special values of dubious utility. In a 32-bit IEEE float:

- 1 bit pattern for +0
- 1 bit pattern for -0
- 1 bit pattern for +∞
- 1 bit pattern for -∞
- 16,777,214 bit patterns for NaN values
- 16,777,214 bit patterns for denormalized numbers (with reduced precision)

A format that eliminated these pathological categories could use those bit patterns for actual real-number values, improving precision or range at no additional cost in bits.

---

## 3. Gustafson's Type I Unums: The Original Vision

### 3.1 The Core Insight: Variable-Width with the Ubit

Gustafson's Type I unum (universal number), introduced in *The End of Error* (2015), was built on a simple but revolutionary insight: every computed number should carry explicit metadata about its own precision, and every result should honestly indicate whether it is exact or approximate.

The key innovation was the **ubit** (uncertainty bit): a single bit appended to a floating-point value that indicates whether the value is exact (ubit = 0) or lies in the open interval between two adjacent exact values (ubit = 1). This transforms every numerical computation from a system that silently rounds and pretends to be exact into one that honestly tracks the uncertainty introduced by each operation.

When the ubit is 0, the unum represents exactly the value encoded by its sign, exponent, and fraction. When the ubit is 1, the unum represents the open interval between the encoded value and the next larger representable value. This transforms single-point representations into bounded intervals without doubling the storage cost.

### 3.2 The Utag: Self-Descriptive Metadata

Type I unums also carry a **utag**—a metadata field specifying the sizes of the exponent and fraction fields. This makes the format self-descriptive: a unum carries enough information to decode itself without external context. The utag consists of:

- **ess** (exponent size size): specifies how many bits are used for the exponent
- **fss** (fraction size size): specifies how many bits are used for the fraction

This means Type I unums are variable-width: a simple value like 1.0 can be represented in very few bits, while a value requiring high precision will use more. The total size of a Type I unum is: 1 (sign) + e (exponent, from 1 to 2^ess bits) + f (fraction, from 1 to 2^fss bits) + 1 (ubit) + ess + fss.

### 3.3 The U-Layer and G-Layer Architecture

Gustafson proposed a two-layer computational architecture:

**U-layer** (unum layer): All storage and data movement happens in the u-layer, where numbers are represented as compact unums. This layer is concerned with memory efficiency—storing numbers in the fewest bits possible while preserving all known information.

**G-layer** (general layer): All arithmetic computation happens in the g-layer, where numbers are expanded to a fixed, maximally precise internal format before operations are performed. After computation, results are compressed back to unum format for storage.

This separation cleanly distinguishes between the concerns of storage (minimize bits, preserve information) and computation (maximize precision, avoid intermediate rounding).

### 3.4 Strengths and Weaknesses of Type I

**Strengths:**
- Honest tracking of uncertainty through the ubit
- Variable-width encoding reduces storage for simple values
- Self-descriptive format through the utag
- The u-layer/g-layer architecture cleanly separates concerns

**Weaknesses:**
- Variable-width numbers are difficult to handle in hardware: cache lines, registers, and memory buses all assume fixed-width values
- The utag overhead can be significant for small values
- Managing variable-width bit strings requires complex bookkeeping
- Memory allocation patterns become unpredictable
- Performance overhead of continuously packing and unpacking the u-layer/g-layer format

These practical difficulties motivated the move to Type II and eventually Type III unums.

---

## 4. Type II Unums: The Projective Real Number Line

### 4.1 The Projective Reals

Type II unums, which Gustafson developed between 2016 and 2017, took a radically different approach. Instead of variable-width representations, Type II unums map onto the **projective real number line**—a mathematical structure where the number line wraps into a circle, with a single "infinity" point at the top (replacing both +∞ and -∞ of IEEE 754).

In this model, every n-bit Type II unum is a fixed-size encoding. The projective reals are divided into 2^n sectors, alternating between exact values and open intervals. For n-bit Type II unums, there are 2^(n-1) exact values and 2^(n-1) open intervals, and the encoding assigns one bit pattern to each.

### 4.2 Fixed-Size with Lookup Tables

The Type II encoding uses a lookup table to map bit patterns to exact values. The table can be tailored to specific applications: for instance, a table for audio processing might cluster representable values near common amplitudes, while a table for physics might cluster values near fundamental constants.

Arithmetic in Type II uses table lookups for each operation, making the hardware relatively simple (if the table fits on-chip). For small bit widths, this is practical. For larger bit widths, the lookup table grows exponentially.

### 4.3 Strengths and Weaknesses of Type II

**Strengths:**
- Fixed-width format: hardware-friendly
- Customizable value sets via lookup tables
- Clean mathematical structure (projective reals)
- Every bit pattern is a valid number (no NaN, no wasted patterns)

**Weaknesses:**
- Exponentially large lookup tables limit practical bit widths to approximately 20 bits
- Table customization means Type II formats are application-specific, not universal
- Difficult to compose: operations that cross the ±∞ boundary require careful handling
- No clear path to scaling beyond small bit widths

The lookup-table problem was decisive: for the 32-bit and 64-bit precisions that most applications demand, Type II was impractical. This led to Type III.

---

## 5. Type III: Posit Arithmetic

**Notation convention.** Throughout this report, we use `Posit n es` (or `(Posit n es)` in Πρόλογος syntax) to denote a posit type parameterized by bit width n and exponent size es. Standard aliases following the 2022 Posit Standard are: `Posit8` = `Posit 8 2`, `Posit16` = `Posit 16 2`, `Posit32` = `Posit 32 2`, `Posit64` = `Posit 64 2`. When discussing specific hardware or software implementations, we may use their native notation (e.g., `posit<32, 2>` for C++ templates, `P32` for Rust bindings).

### 5.1 The Posit Format: Regime, Exponent, Fraction

The posit format, introduced by Gustafson and Isaac Yonemoto in 2017 (and refined through 2022), is a fixed-width representation that achieves the goals of Type I unums (better accuracy per bit than IEEE 754) while maintaining the hardware friendliness of fixed-width formats.

A posit number of size n bits with exponent size es consists of four fields:

```
| sign (1) | regime (variable) | exponent (es) | fraction (remaining) |
```

- **Sign (1 bit):** 0 for positive, 1 for negative. Negative numbers use two's complement of the entire bit string (not just a sign bit flip as in IEEE 754).
- **Regime (variable length):** A run of identical bits terminated by the opposite bit (or by the end of the number). A run of k ones followed by a zero encodes the regime value k-1; a run of k zeros followed by a one encodes the regime value -k. The regime determines the coarse scale of the number.
- **Exponent (es bits):** A fixed-width field that provides fine-grained scaling within the regime. If fewer than es bits remain after the regime, the exponent is truncated (filled with implicit zeros).
- **Fraction (remaining bits):** Provides precision within the exponent's range. Like IEEE 754, there is an implicit leading 1.

The critical innovation is the **variable-length regime field**, which implements a kind of tapered precision: the regime uses a unary encoding that compresses rapidly as values move away from 1.0, borrowing bits from the fraction field to extend dynamic range—and conversely, for values near 1.0 (where most computation occurs), the regime is short, leaving more bits for the fraction.

### 5.2 Tapered Precision: More Bits Where They Matter

This is the fundamental insight of posit arithmetic: rather than allocating a fixed number of bits to exponent and fraction regardless of the value, posits dynamically trade between range and precision. The result:

- **Near 1.0:** The regime field is short (just 2 bits for the terminator), leaving the maximum number of fraction bits—more precision than IEEE 754 for the same bit width.
- **At extreme values:** The regime field grows, consuming fraction bits. For very large or very small numbers, posits have less precision than floats, but the total dynamic range is larger—and crucially, the precision gracefully tapers to zero at the extremes rather than cliff-edging into denormalized numbers.

Empirical studies have shown that for typical distributions of numerical values (which cluster near 1.0 far more than near 10^30), posits deliver more useful precision per bit than IEEE 754 across the range that matters for most applications.

### 5.3 The Useed and Dynamic Range

The **useed** is the fundamental scaling factor for posits, defined as:

```
useed = 2^(2^es)
```

For es=2 (the standard exponent size in the 2022 Posit Standard), useed = 2^4 = 16. The value encoded by a posit is:

```
value = (-1)^sign × useed^regime × 2^exponent × (1 + fraction)
```

The dynamic range of an n-bit posit with exponent size es is:

```
maxpos = useed^(n-2)
minpos = useed^(-(n-2))
```

For posit32 (es=2): maxpos = 16^30 ≈ 1.15 × 10^36, minpos ≈ 8.67 × 10^-37. This is comparable to IEEE 754 binary32, which ranges from approximately 1.2 × 10^-38 to 3.4 × 10^38.

### 5.4 Mathematical Properties of Posits

Posits enjoy several mathematical properties that IEEE 754 floats lack:

**Unique zero.** There is exactly one zero (all bits 0). No signed zeros, no comparison anomalies.

**No NaN.** Every bit pattern except the one with a leading 1 followed by all zeros represents a valid real number. That single exception represents ±∞ (or "NaR"—Not a Real), which is the only non-real value. This means every arithmetic operation on finite posits produces a finite result, except for 0/0 and x/0, which produce NaR.

**Symmetry.** The posit encoding is symmetric around zero: negation is simply two's complement on the entire bit string. The positive and negative posits are mirrors of each other, with no wasted patterns.

**Total ordering.** Posit bit patterns have a total order that corresponds to the numerical order of the values they represent. For non-negative posits, the bit patterns interpreted as unsigned integers sort in ascending numerical order. For negative posits (which use two's complement representation), comparison requires sign-aware logic—but this is still far simpler than IEEE 754 comparison, which must handle signed zeros, NaN (unordered), and denormalized values. In practice, posit comparison can be implemented as a signed two's complement integer comparison on the raw bit pattern, giving correct results for all finite posits and NaR.

**Closure under rounding.** For any real number within the dynamic range, rounding to the nearest posit is well-defined and does not produce a trap representation. Values beyond the dynamic range round to ±maxpos, not to infinity.

### 5.5 Posits vs. IEEE 754 Floats: Comparative Analysis

Extensive benchmarking has been performed comparing posits to IEEE 754 floats at equivalent bit widths:

**Accuracy near 1.0:** A posit32 has approximately 28–30 bits of fraction for values near 1.0, compared to 23 for binary32. This gives posit32 roughly 2 additional decimal digits of precision in the range where most computation occurs.

**Decimal accuracy (in the geometric mean):** Across the full representable range, posits deliver higher average accuracy (measured as decimal digits of precision) than floats of the same size. Gustafson's analysis showed that posit32 provides a geometric mean of approximately 8.5 decimal digits, versus approximately 7.2 for binary32.

**Dynamic range:** Comparable to IEEE 754 at equivalent bit widths, though the distribution of representable values is different (tapered for posits, fixed for floats).

**Closure properties:** Posits are closed under all four basic arithmetic operations for finite inputs (only 0/0 and x/0 produce NaR). IEEE 754 can produce NaN from 0/0, ∞ − ∞, 0 × ∞, and various other combinations.

**Hardware cost:** Posit adders and multipliers are slightly more complex than IEEE 754 due to the variable-length regime field, but several implementations have shown the overhead to be modest (approximately 10–20% more area in FPGA implementations).

### 5.6 The 2022 Posit Standard

The **Posit Standard 2022** (released by the Posit Working Group) standardizes four posit formats, all with exponent size es = 2:

| Format | Bits | Exponent Size (es) | Quire Size |
|--------|------|---------------------|------------|
| posit8 | 8 | 2 | 32 bits |
| posit16 | 16 | 2 | 128 bits |
| posit32 | 32 | 2 | 512 bits |
| posit64 | 64 | 2 | 2048 bits |

The decision to fix es = 2 for all sizes was based on extensive analysis showing that es = 2 provides the best overall trade-off between range and precision across the widest variety of applications. The standard also specifies:

- Rounding: round-to-nearest-even (ties round to even)
- Special value: NaR (Not a Real) for the bit pattern 10000...0
- Required operations: add, subtract, multiply, divide, square root, fused multiply-add, quire operations
- Conversions between posit sizes and to/from IEEE 754 formats

---

## 6. Valids: Interval Arithmetic Done Right

### 6.1 Bounded Uncertainty with Posit Pairs

Gustafson's **valid** type pairs two posit values to represent a closed, open, or half-open interval on the real line. A valid consists of:

- A lower-bound posit
- An upper-bound posit
- Two ubits (one for each bound) indicating whether the bound is closed (ubit = 0) or open (ubit = 1)

This transforms every computation from a single-point estimate into a rigorous bound on the true value. The valid type guarantees that the mathematically exact result lies within the reported interval—a guarantee that no single-point floating-point format can provide.

### 6.2 The Ubit as Openness Indicator

The ubits in a valid allow fine-grained control over interval endpoints:

- Both ubits 0: the valid represents the closed interval [a, b]
- Lower ubit 1, upper ubit 0: the valid represents the half-open interval (a, b]
- Lower ubit 0, upper ubit 1: the valid represents [a, b)
- Both ubits 1: the valid represents the open interval (a, b)

This distinction matters in the theory of interval arithmetic because it allows valids to represent, for example, the result of computing 1/3: the valid can indicate that the true value is strictly between two adjacent posits (open interval), rather than claiming it equals either one.

### 6.3 Fusion Operations for Valids

When performing arithmetic on valids, the lower bound of the result is computed by rounding downward, and the upper bound by rounding upward. This ensures that the resulting interval always contains the true mathematical result. Key fusion operations include:

- **Fused valid add/subtract:** Compute lower bound with round-down, upper bound with round-up
- **Fused valid multiply:** Choose the correct bounds depending on the signs of the inputs
- **Fused valid divide:** Similar sign-dependent bound selection
- **Valid square root:** Only defined for non-negative valids

The quire can be used as an intermediate accumulator in valid operations, enabling tighter bounds by deferring rounding until the final result.

### 6.4 Connections to Classical Interval Arithmetic

Valids relate to several traditions in interval arithmetic:

**Moore's interval arithmetic (1966):** The foundational work establishing that interval computations provide guaranteed bounds. Valids refine Moore's approach by using posit endpoints rather than IEEE 754 endpoints, giving tighter bounds due to better precision per bit.

**Affine arithmetic:** An extension of interval arithmetic that tracks correlations between variables to reduce interval widths. Valids do not directly incorporate affine forms, but the valid framework could be extended in this direction.

**Kaucher arithmetic:** An extension that allows "improper" intervals where the lower bound exceeds the upper bound, useful in constraint solving. The valid framework could potentially be extended to incorporate such directed intervals.

---

## 7. Quires: The Exact Accumulator

### 7.1 The Kulisch Accumulator Adapted for Posits

The **quire** is perhaps the most practically significant innovation in the unum ecosystem. Based on the **Kulisch accumulator** (proposed by Ulrich Kulisch in the 1970s), a quire is a fixed-point register wide enough to exactly represent the sum of any number of products of posit values without intermediate rounding.

The key insight is that the product of two n-bit posits produces a result that falls within a fixed range, and the sum of any number of such products can be accumulated exactly if the accumulator is wide enough. For posit32 (es = 2), the quire is 512 bits wide: large enough to exactly represent the sum of up to 2^31 products of posit32 values without any rounding whatsoever.

### 7.2 Fused Operations: Dot Product and Multiply-Accumulate

The quire enables several fused operations that are crucial for scientific computing and machine learning:

**Fused dot product (fdp):** Given vectors a = [a₁, ..., aₖ] and b = [b₁, ..., bₖ], the quire accumulates a₁×b₁ + a₂×b₂ + ... + aₖ×bₖ exactly, rounding only once at the end when the result is converted back to a posit. This means the dot product of two vectors is computed to the maximum accuracy possible for the output format, regardless of the length of the vectors.

**Fused multiply-accumulate (fma):** Accumulate a × b + c exactly in the quire, rounding only on extraction. This generalizes the standard fused multiply-add (which IEEE 754-2008 also supports for a single operation) to an arbitrary chain of multiply-accumulates.

### 7.3 Exact Inner Products and Numerical Stability

The exact dot product has profound implications for numerical stability:

**Kahan summation is unnecessary.** The compensated summation algorithm (Kahan summation) exists precisely because IEEE 754 accumulation loses precision. With a quire, the accumulation is exact, making compensated summation obsolete.

**Reproducible results.** Because the quire accumulation is exact regardless of evaluation order, parallel implementations of dot products can partition the work arbitrarily and still produce bit-identical results. This solves the long-standing problem that parallelizing floating-point reductions changes the answer.

**Gram-Schmidt without re-orthogonalization.** In numerical linear algebra, the classical Gram-Schmidt process often requires one or more re-orthogonalization passes due to floating-point drift. With quire-based dot products, the first pass is accurate enough that re-orthogonalization is unnecessary for many practical cases.

**Iterative refinement convergence.** Iterative methods that refine an approximation by computing residuals converge faster when residuals are computed with exact dot products, because the residuals themselves are more accurate.

### 7.4 Quire Width and Implementation Considerations

The quire width for posit_n is determined by the maximum range of a product plus enough guard bits for accumulation:

| Posit Format | Quire Width | Practical Notes |
|-------------|-------------|-----------------|
| posit8 | 32 bits | Fits in a standard register |
| posit16 | 128 bits | Fits in a SIMD register (SSE/NEON) |
| posit32 | 512 bits | Fits in an AVX-512 register or dedicated hardware |
| posit64 | 2048 bits | Requires dedicated hardware or software emulation |

For posit32, the 512-bit quire aligns with AVX-512 register widths, making efficient software emulation possible on modern x86 processors even without dedicated posit hardware.

**Overflow and saturation behavior.** The quire is designed to be wide enough that overflow is extremely unlikely in normal computation: for posit32, the 512-bit quire can accumulate up to 2^31 maxpos×maxpos products without overflow. However, pathological cases can in principle exceed the quire range. The 2022 Posit Standard specifies saturation behavior on quire extraction: if the accumulated value exceeds maxpos, the extracted posit saturates to maxpos (not NaR). For a language like Πρόλογος, which rejects silent wrapping, three strategies should be available as configurable options per compilation unit: (a) saturation to ±maxpos on extraction, matching the standard; (b) runtime error if the accumulated value exceeds a configurable threshold; (c) automatic promotion to a wider quire or to arbitrary-precision rational. The default should be (b), consistent with the "no silent wrong answers" philosophy.

---

## 8. Cutting-Edge Research: Beyond Posits

### 8.1 Takum Arithmetic: An Alternative to the Regime Field

**Takum** arithmetic, proposed by Laslo Hunhold (2024), reimagines the variable-precision concept with a different encoding than posits. While posits use a unary-encoded regime field, takums use a more conventional structure:

```
| sign (1) | direction (1) | characteristic (variable) | mantissa (remaining) |
```

The "direction" bit and variable-length "characteristic" together determine the exponent, using a logarithmic mapping that avoids the useed-based scaling of posits. Takums claim several advantages:

- A smoother precision curve: where posits have a somewhat uneven distribution of precision across the range (because the regime uses unary coding), takums claim a more uniform distribution
- Simpler hardware decoding: the characteristic can be decoded without the long leading-zero/one detector that posits require for regime extraction
- Better worst-case precision: posits can have very few fraction bits at extreme values; takums maintain a minimum fraction width

However, takum arithmetic is still in early stages, without the hardware implementations or standardization that posits have achieved. It remains an active area of research.

### 8.2 LNS-Madam: Logarithmic Number Systems for ML

The **Logarithmic Number System** (LNS) represents numbers as fixed-point logarithms, so multiplication becomes addition and addition requires a special lookup. **LNS-Madam** (Logarithmic Number System with Multiplication is Addition and Division is Subtraction, Approximately, for Machine Learning) is a recent system that applies LNS specifically to neural network training, where multiplication-heavy operations (matrix multiplies) dominate.

LNS-Madam shows that for certain ML workloads, especially training with mixed-precision, logarithmic representations can match or exceed the accuracy of IEEE 754 floats at equivalent bit widths while significantly simplifying the multiplication hardware. The connection to posits is that posits, through their regime field, already have a partially logarithmic structure—the regime encodes the coarse scale logarithmically, while the fraction provides linear precision within that scale.

### 8.3 Block Floating Point (BFP) and Microscaling (MSFP)

**Block Floating Point** (BFP) shares a single exponent across a block of values, with each value having its own mantissa. This amortizes the exponent overhead and enables efficient hardware:

```
Shared Exponent: [8 bits]
Values: [mantissa₁ (8 bits)] [mantissa₂ (8 bits)] ... [mantissa_k (8 bits)]
```

**Microscaling Floating Point (MSFP)**, developed by Microsoft Research, extends BFP with per-element scale factors and shared block scales. The OCP (Open Compute Project) Microscaling Formats Specification (2023) standardizes several formats: MSFP-E5M2, MSFP-E4M3, MSFP-E3M4.

These formats are primarily of interest for ML inference, where the weight values in a layer tend to have similar magnitudes, making shared exponents an efficient strategy. They do not address the general-purpose concerns that motivate posits (better accuracy for arbitrary computation).

### 8.4 Low-Precision Formats: bfloat16 and TensorFloat-32

The ML industry has independently developed several reduced-precision formats:

**bfloat16 (Brain Floating Point):** Developed by Google Brain. Uses 1 sign bit, 8 exponent bits, and 7 mantissa bits. The 8 exponent bits give the same dynamic range as IEEE 754 binary32, but with only 7 mantissa bits (vs. 23), providing approximately 2 decimal digits of precision. Its value lies in direct truncation compatibility with float32.

**TensorFloat-32 (TF32):** Developed by NVIDIA for the A100 GPU and beyond. Uses 1 sign, 8 exponent, and 10 mantissa bits (19 bits total, but stored in 32-bit containers). Offers a compromise between bfloat16 precision and float32 range.

**FP8 variants (E4M3 and E5M2):** The emerging 8-bit formats for ML inference. E4M3 gives 3 mantissa bits with 4 exponent bits; E5M2 gives 2 mantissa bits with 5 exponent bits.

These formats are narrowly focused on ML workloads and do not attempt to solve the general problem of better numerical representation. However, they demonstrate the industry appetite for alternative number formats—a trend that posits could capitalize on.

### 8.5 IEEE P3109: Standardizing Low-Precision Formats

The **IEEE P3109** working group is developing a standard for arithmetic formats smaller than 32 bits, motivated by ML applications. This effort may eventually encompass posit-like formats, though as of 2025 the focus is on conventional floating-point formats with reduced bit widths.

The significance of P3109 is that it represents official IEEE recognition that the one-size-fits-all approach of IEEE 754 binary32/binary64 is inadequate for modern workloads—a vindication of Gustafson's original argument, even if the proposed solutions differ from his.

### 8.6 Stochastic Rounding and Probabilistic Arithmetic

**Stochastic rounding** rounds a value to one of the two nearest representable values with probability proportional to the proximity. For example, if the true value is 60% of the way from one representable number to the next, stochastic rounding has a 60% chance of rounding up and a 40% chance of rounding down.

This technique has shown significant benefits for ML training, where the expected value of the error is zero (unbiased), enabling convergence that deterministic rounding can prevent. Stochastic rounding can be applied to any number format—IEEE 754, posits, or others—and several hardware implementations for posit arithmetic include stochastic rounding as an option.

The connection to language design is that a numeric tower could expose rounding mode as a type-level or effect-level parameter, allowing programmers to specify stochastic rounding for ML workloads while using deterministic rounding for reproducible scientific computation.

---

## 9. Hardware Implementations

### 9.1 PACoGen: Parameterized Posit Arithmetic Core Generator

**PACoGen** (Parameterized Posit Arithmetic Core Generator) is an open-source Verilog HDL tool developed by Manish Kumar Jaiswal at IIT Bombay. It generates synthesizable RTL for posit arithmetic units with arbitrary (n, es) parameters:

- Add/subtract units
- Multiply units
- Divide units (reciprocal-based and SRT)
- Fused multiply-add
- Format conversion (posit ↔ float, posit ↔ posit)

PACoGen has been used as the basis for several FPGA implementations and has demonstrated that posit arithmetic units are practical for hardware implementation, with area and timing overhead of approximately 10–20% compared to equivalent IEEE 754 units.

### 9.2 PERCIVAL: RISC-V with Posit Extensions

**PERCIVAL** (Posit-Enabled RISC-V Core with Arithmetic Logic) is a research project that extends the RISC-V ISA with native posit instructions. Key features:

- Custom posit functional unit integrated into a RISC-V pipeline
- Support for posit32 operations: add, subtract, multiply, divide, sqrt, fma
- Quire support for exact dot products
- Posit ↔ float conversion instructions
- Demonstrated on FPGA (Xilinx Kintex-7)

**Big-PERCIVAL** extends this to a multi-core RISC-V design with posit support, demonstrating that posit arithmetic can be integrated into a production-class processor pipeline without fundamental architectural changes.

### 9.3 CalligoTech TUNGA: Commercial Posit ASIC

**CalligoTech** (based in India) has developed the **TUNGA** processor, believed to be the first commercially manufactured ASIC with native posit arithmetic support. TUNGA targets embedded signal processing applications where the accuracy advantages of posits translate directly to lower power consumption (fewer bits needed for equivalent accuracy, meaning smaller data paths and less memory bandwidth).

### 9.4 Deep PeNSieve: FPGA Posit Neural Network Accelerator

**Deep PeNSieve** is a CNN (Convolutional Neural Network) inference accelerator that uses posit8 and posit16 arithmetic throughout the datapath. Research has shown that for classification tasks on standard benchmarks (CIFAR-10, ImageNet subsets), posit8 achieves accuracy comparable to float16 and sometimes float32, while using half the bits per value.

The quire plays a critical role here: the convolution operations that dominate CNN computation are dot products, and the quire enables exact accumulation of these partial sums, producing more accurate results than naive float accumulation.

### 9.5 FPGA and GPU Approaches

Several research groups have implemented posit arithmetic on FPGAs:

- **Xilinx/AMD FPGAs:** Multiple implementations of posit32 arithmetic using LUT-based regime extraction and DSP slices for the fraction multiplication
- **Intel/Altera FPGAs:** Similar implementations with focus on HLS (High-Level Synthesis) based designs
- **GPU approaches:** Software posit emulation on CUDA GPUs has been explored, though without dedicated hardware, the overhead is significant (typically 5–20× slower than native float operations)

The consensus from hardware research is that posit arithmetic is practically implementable, with modest area/timing overhead, and that the accuracy benefits justify the cost for applications where numerical quality matters.

---

## 10. The Kahan Debate and Criticisms

### 10.1 William Kahan's Criticisms

William Kahan—the architect of IEEE 754—has been the most prominent critic of posits. His criticisms include:

**Gradual underflow (denormalized numbers).** Kahan argues that IEEE 754's denormalized numbers (which posits lack) provide a gradual transition to zero that prevents "catastrophic" loss of significance near the underflow boundary. Posit advocates respond that tapered precision provides an analogous (and arguably superior) smooth transition, and that the bits consumed by denormalized encodings are better spent on additional precision for normalized values.

**Exception handling.** Kahan argues that IEEE 754's rich exception model (invalid, overflow, underflow, division-by-zero, inexact) provides essential diagnostic information. Posits' single NaR value conflates all exceptional conditions. Posit advocates argue that in practice, IEEE 754's exception flags are rarely checked by applications and that NaR's simplicity is an advantage for most use cases.

**Decades of ecosystem investment.** The vast body of numerical analysis software, hardware implementations, and programmer expertise built around IEEE 754 represents an enormous sunk cost. Posit advocates acknowledge this but argue that progress should not be held hostage by legacy.

### 10.2 De Dinechin's Scale-Invariance Critique

Florent de Dinechin (ENS Lyon, INRIA) raised a more technical criticism: posits' tapered precision means they are not scale-invariant. If you multiply all inputs by a large constant, moving values from the high-precision region near 1.0 to the low-precision extreme, the results can be significantly different. IEEE 754 floats, with their fixed exponent/fraction split, maintain constant relative precision (measured in ULPs relative to the value) across the entire representable range—a property that posits sacrifice in exchange for their superior per-bit accuracy near unity.

It is important to note that this critique does not contradict the tapered precision design described in Section 5.2; rather, it highlights the fundamental trade-off at the heart of posit arithmetic. Tapered precision improves accuracy in the range where values most commonly occur (near 1.0), but reduces accuracy if computations cause values to migrate to the extremes of the dynamic range. This is a deliberate engineering choice, not a defect.

Posit advocates respond that:
1. In practice, most numerical values cluster near 1.0 (especially in normalized data), so the high-precision region is used most of the time
2. Users of posits should be aware of the tapered precision and normalize their data appropriately—the language design (Section 14) addresses this through `@verify-bounds` annotations that can detect magnitude drift at runtime
3. The total information content per bit is still higher for posits than for floats, even accounting for the non-uniform precision distribution
4. Data normalization (scaling inputs to the high-precision region) is a standard practice in numerical computing, and a language with dependent types can enforce normalization constraints statically

### 10.3 The Reproducibility Question

One of the most significant criticisms of IEEE 754 is that parallel floating-point reductions (sums, dot products) are non-reproducible because floating-point addition is non-associative. Posit arithmetic does not solve this problem directly—posit addition is also non-associative. However, the quire solves it for the specific and critical case of dot products: quire-based dot products are reproducible regardless of evaluation order.

For general sums that are not naturally expressible as dot products, posit arithmetic inherits the same non-reproducibility issues as IEEE 754. However, techniques like Kulisch accumulation (which the quire generalizes) can be extended to arbitrary sums at the cost of wider accumulators.

### 10.4 Responses from the Posit Community

The posit community has addressed criticisms through:

1. The 2022 Posit Standard, which fixes es=2 for all sizes, simplifying hardware and addressing concerns about format fragmentation
2. Extensive benchmarking showing posit advantages in practical workloads (ML, signal processing, linear algebra)
3. Multiple hardware implementations demonstrating practical feasibility
4. Formal proofs of key properties (total ordering, closure under rounding)

---

## 11. Academic Research and Applications (2020–2026)

### 11.1 Posits in Machine Learning

Posit arithmetic has been evaluated extensively for ML workloads:

**Training:** Posit16 has been shown to match float32 accuracy for training standard architectures (ResNet, LSTM, Transformer) on several benchmarks. The quire is particularly valuable for gradient accumulation, where exact dot products prevent the loss-of-gradient problem that plagues low-precision float training.

**Inference:** Posit8 achieves accuracy comparable to int8 quantization and sometimes matches float16 for inference on CNNs and Transformers. The key advantage over int8 is that posits do not require per-layer calibration (since they natively support a wide dynamic range), simplifying the quantization workflow.

**Mixed precision:** Posit mixed-precision strategies (posit8 for storage, posit16 for computation, quire for accumulation) offer a compelling alternative to the float16/float32 mixed precision that is standard in ML training today.

### 11.2 Sparse Linear Solvers and Scientific Computing

Research has demonstrated posit arithmetic in several scientific computing contexts:

- **Iterative refinement:** Mixed-precision iterative refinement using posit16 for the factorization and posit32 for the residual achieves convergence rates comparable to full float64 computation
- **Conjugate gradient methods:** Quire-based dot products improve convergence and reproducibility
- **Sparse matrix-vector products (SpMV):** Posit16 SpMV achieves comparable accuracy to float32 SpMV with half the memory bandwidth

### 11.3 Computer Vision and Signal Processing

Posit arithmetic has been applied to optical flow estimation, where the accuracy advantages of posits reduce artifact severity at boundaries. DSP applications (filtering, FFT) also benefit from the improved accuracy-per-bit, particularly at 16-bit widths where IEEE float16's limited exponent range can cause issues.

### 11.4 Climate Modeling and Geophysics

Several groups have explored reduced-precision posit arithmetic for climate simulations, where the enormous computational cost makes reduced precision attractive. Preliminary results suggest that posit16 can replace float32 in certain atmospheric model components without degrading forecast quality, offering a 2× reduction in data movement and memory footprint.

### 11.5 Formal Verification of Posit Arithmetic

Formal verification of posit arithmetic operations has been undertaken in several proof assistants:

- **Coq/Rocq formalization** of posit encoding and basic arithmetic operations, building on the Flocq library for floating-point formalization. Key verified properties include the bijectivity of posit encoding/decoding, correctness of rounding, and commutativity of addition and multiplication.
- **SMT-based verification** of posit addition correctness properties, using Z3 and CVC5 to exhaustively check posit8 operations and bounded-check posit16/posit32 operations against the 2022 Standard specification.
- **Isabelle/HOL formalization** of the posit standard's rounding specification, providing machine-checked proofs that the rounding function satisfies the standard's requirements for all representable posit values.

These efforts are still less mature than the extensive formal verification of IEEE 754 operations (which has been ongoing for decades), but they provide a foundation for high-assurance posit implementations.

**Connection to dependent type systems.** The formally verified properties of posit arithmetic have direct implications for a language with dependent types like Πρόλογος. Verified properties—such as total ordering, commutativity, closure under rounding, and the correctness of conversion between posit sizes—can be encoded as type-level axioms or proof obligations. For example:

- `posit-comm-add : (a : Posit n es) -> (b : Posit n es) -> posit-add a b ≡ posit-add b a` — commutativity of posit addition, provable from the Coq formalization
- `posit-total-order : (a b : Posit n es) -> Either (a ≤ b) (b ≤ a)` — total ordering, provable for all finite posits
- `posit-round-correct : (r : Rational) -> {in-range r n es} -> distance (to-posit r) r ≤ ulp (to-posit r) / 2` — rounding correctness within half a ULP

A language implementation can either trust these axioms (with a verified posit library as the trusted base) or carry the proofs as compile-time evidence, enabling the type checker to reason about numerical accuracy at the type level. This bridges the gap between formal numerical analysis and practical programming—one of the most compelling opportunities for a dependently typed language with first-class posit support.

---

## 12. Software Libraries and Implementations

### 12.1 SoftPosit: The Reference Implementation

**SoftPosit** is the official reference software implementation of posit arithmetic, maintained by the NGA (National Geospatial-Intelligence Agency) and Cerlane Leong. Key features:

- Written in C, highly portable
- Supports posit8, posit16, posit32 (2022 Standard compliant)
- Full quire support for all posit sizes
- Extensively tested against known-correct reference values
- BSD-licensed

SoftPosit serves as the de facto standard for correctness testing: other implementations are typically validated by comparing their results against SoftPosit.

**Repository:** https://gitlab.com/cerlane/SoftPosit

### 12.2 Universal: Stillwater's Comprehensive C++ Library

**Universal** (by Stillwater Supercomputing) is a comprehensive C++ template library providing posit arithmetic alongside many other number system implementations:

- Arbitrary (n, es) posit configurations via C++ templates: `posit<32, 2>`, `posit<16, 1>`, etc.
- Quire support with template-parameterized widths
- IEEE 754 float emulation for comparison
- Additional number types: fixed-point, LNS (logarithmic number system), interval, valid, cfloat (classic float), areal (adaptive-precision real)
- Extensive benchmarks and test suites
- HPR-BLAS (High-Performance Reproducible BLAS) built on quire dot products

Universal is the most feature-rich posit library available and is suitable for research, prototyping, and performance benchmarking.

**Repository:** https://github.com/stillwater-sc/universal

### 12.3 Python Ecosystem: sfpy and Beyond

**sfpy** provides Python bindings to SoftPosit via Cython:

```python
from sfpy import Posit32
a = Posit32(1.5)
b = Posit32(2.3)
c = a * b  # posit multiplication
```

sfpy supports posit8, posit16, and posit32, with quire operations. It integrates with NumPy via custom dtypes, enabling posit-based numerical computing in the Python scientific ecosystem.

Additional Python tools include **softposit-python** (a pure Python implementation for educational use) and experimental NumPy integration projects.

### 12.4 Julia: SoftPosit.jl

**SoftPosit.jl** provides a pure Julia implementation of posit arithmetic:

```julia
using SoftPosit
a = Posit32(1.5)
b = Posit32(2.3)
c = a * b
```

Julia's multiple dispatch and numeric type system make it an excellent host for posit experimentation: posit types participate in Julia's numeric promotion hierarchy and work with standard linear algebra routines.

### 12.5 Rust: softposit-rs

**softposit-rs** wraps the SoftPosit C library with safe Rust bindings:

```rust
use softposit::P32;
let a = P32::from(1.5);
let b = P32::from(2.3);
let c = a * b;
```

The Rust implementation provides type-safe posit operations with no undefined behavior, leveraging Rust's ownership system for quire lifetime management.

### 12.6 Haskell and Functional Ecosystems

The **posit** package on Hackage provides a Haskell implementation:

```haskell
import Posit
let a = toPosit 1.5 :: Posit256  -- 256-bit fixed-width posit (not arbitrary-precision)
let b = toPosit 2.3 :: Posit256
let c = a * b
```

The Haskell implementation supports posits at various fixed bit widths (8, 16, 32, 64, 128, 256) and demonstrates posit integration with a rich type system, including instances for Num, Fractional, Floating, and Real type classes. Note that these are fixed-width posits (not arbitrary-precision in the sense of GMP integers); the 256-bit variant simply provides more fraction bits for higher precision within the posit framework. This is particularly relevant for Πρόλογος, which shares the functional-programming heritage.

### 12.7 Other Languages and Emerging Efforts

- **Racket:** softposit-rkt provides bindings for Racket, relevant to our prototyping strategy
- **C#/.NET:** Lombiq Arithmetics provides posit types for the .NET ecosystem
- **Zig:** An RFC has been proposed for posit support in Zig's standard library
- **MATLAB/Octave:** Various wrapper libraries for numerical experimentation
- **Go:** Experimental posit packages exist but are not yet production-quality

---

## 13. Interval Arithmetic Libraries and Connections

### 13.1 MPFI and Arb

**MPFI** (Multiple Precision Floating-Point Interval library) and **Arb** (C library for arbitrary-precision ball arithmetic) provide rigorous interval arithmetic with arbitrary precision. These libraries use MPFR (Multiple Precision Floating-Point Reliable) as their foundation and provide guaranteed bounds on all results.

Arb's "ball arithmetic" represents numbers as a midpoint (arbitrary precision) plus a radius (error bound). This is conceptually related to valids but uses a different representation: a single midpoint with an error bound, rather than explicit interval endpoints.

### 13.2 Julia IntervalArithmetic.jl

Julia's **IntervalArithmetic.jl** provides IEEE 1788-compliant interval arithmetic:

```julia
using IntervalArithmetic
x = interval(0.1)     # [0.0999999..., 0.100000...]
y = x^2 + x           # guaranteed to contain exact result
```

This library demonstrates how interval types can be integrated into a modern language's numeric hierarchy—a model that Πρόλογος could adopt for valids.

### 13.3 Boost.Interval and iRRAM

**Boost.Interval** (C++) provides generic interval arithmetic templates. **iRRAM** (C++) provides exact real arithmetic via lazy evaluation and iterative refinement, automatically increasing precision until the requested number of digits is correct. iRRAM's approach—lazy evaluation with demand-driven precision—is an interesting complement to posit/valid arithmetic.

### 13.4 Relationship to Valids

The existing interval arithmetic ecosystem demonstrates that rigorous interval computation is practical and useful. Valids extend this tradition by using posit endpoints (for better accuracy per bit) and the ubit system (for distinguishing open and closed endpoints). A language design can draw on the API patterns established by these libraries while using posit-based valids as the underlying representation.

---

## 14. Implications for Language Design

This section synthesizes our findings into concrete design recommendations for incorporating next-generation number systems into Πρόλογος—a functional-logic language with dependent types, session types, homoiconic syntax, and a commitment to arbitrary-precision arithmetic with no silent wrapping.

### 14.1 First-Class Number Types: A Taxonomy

Πρόλογος should provide a rich numeric tower as first-class types:

**Exact types (arbitrary precision):**
- `Int` — Arbitrary-precision integers (no wrapping; overflow is a compile-time or runtime error, never silent)
- `Rational` — Arbitrary-precision rationals (exact quotient of two Int values)
- `Decimal` — Arbitrary-precision decimal (for financial and human-interface computation)

**IEEE 754 types (for interop):**
- `Float32`, `Float64`, `Float128` — Standard IEEE 754 types, provided for FFI interop with C/C++/Rust libraries and LLVM intrinsics

**Posit types (primary hardware-precision reals):**
- `Posit8`, `Posit16`, `Posit32`, `Posit64` — The four standard posit formats (2022 Standard, es=2)
- `Posit n es` — Parameterized posit type for research and custom hardware (dependent type: n and es are type-level natural numbers)

**Valid types (interval arithmetic):**
- `Valid8`, `Valid16`, `Valid32`, `Valid64` — Paired posit intervals
- `Valid n es` — Parameterized valid type

**Quire types (exact accumulators):**
- `Quire8`, `Quire16`, `Quire32`, `Quire64` — Quire accumulators for each posit size
- `Quire n es` — Parameterized quire type

This taxonomy leverages Πρόλογος's dependent type system to express posit parameters at the type level, enabling the compiler to verify precision requirements statically.

### 14.2 Dependent Types for Precision Tracking

One of the most powerful applications of Πρόλογος's dependent type system is **static precision tracking**. The compiler can track the precision of numerical computations through the type system:

```
-- Type-level precision tracking (conceptual syntax)
posit-mul : (Posit n es) -> (Posit n es) -> (Posit n es)

-- A function that guarantees minimum precision
high-precision-dot
  : {n : Nat}
  -> {es : Nat}
  -> {prf : GTE n 32}         -- proof that n >= 32
  -> (Vec k (Posit n es))
  -> (Vec k (Posit n es))
  -> (Posit n es)
```

The dependent type system can also express constraints on valid intervals:

```
-- A valid that is guaranteed to be non-empty
nonempty-valid : (v : Valid n es) -> {prf : NonEmpty v} -> ...

-- A computation that narrows the valid interval
refine : Valid n es -> Valid n es  -- postcondition: width decreases
```

This connects directly to the propagator-based constraint solving described in our earlier research: precision constraints can propagate through a computation graph, with the type system ensuring that precision requirements are met at every stage.

### 14.3 Quire Integration and Fusion Operations

The quire should be deeply integrated into the language, not merely an optional library feature:

**Quire scoping.** A quire accumulator has a well-defined lifetime: it is initialized, receives multiply-accumulate operations, and is finalized (extracted) to produce a posit result. This lifecycle maps naturally to linear types:

```
-- Quire operations using linear types
quire-new    : () -o Quire n es
quire-fma    : Quire n es -o Posit n es -> Posit n es -> Quire n es
quire-extract : Quire n es -o Posit n es
```

The linear type system ensures that a quire is used exactly once (extracted) and cannot be duplicated or discarded without extraction—preventing resource leaks and ensuring that every quire accumulation is properly finalized.

**Fused dot product as a primitive.** The dot product is so fundamental (and the quire makes it so much better) that it should be a language primitive, not a library function:

```
-- Built-in fused dot product
fdp : (Vec k (Posit n es)) -> (Vec k (Posit n es)) -> (Posit n es)
```

The compiler can ensure that this is implemented using a quire internally, without exposing the quire to the programmer when the dot-product abstraction suffices.

### 14.4 Literal Syntax and Conversion Semantics

Numeric literals in Πρόλογος should be handled carefully:

**Decimal literals are exact by default.** The literal `0.1` should be represented as the exact rational 1/10, not as a floating-point approximation. Conversion to a specific posit or float type happens explicitly (or through type inference), and the conversion is documented to use a specific rounding mode.

**Explicit conversion with rounding mode.**
```
-- Convert rational to posit with specified rounding
to-posit : Rational -> (RoundMode) -> Posit n es

-- Default rounding (round-to-nearest-even, per 2022 Standard)
to-posit-rne : Rational -> Posit n es
```

**No implicit lossy conversions.** The type system should prevent implicit conversion from higher to lower precision. Going from `Posit32` to `Posit16` requires an explicit conversion call. Going from `Rational` to `Posit32` requires explicit conversion. Going from `Posit32` to `Float32` requires explicit conversion. Only widening conversions (e.g., `Posit16` to `Posit32`) can be implicit.

This design philosophy aligns with Πρόλογος's commitment to "no silent wrapping": every precision-losing operation must be acknowledged by the programmer.

**Formal conversion rules.** The following table summarizes conversion semantics for the numeric tower:

| From | To | Implicit? | Rounding | Special Cases |
|------|----|-----------|----------|---------------|
| Int | Rational | Yes (lossless) | None | Always exact |
| Rational | Posit n es | No (explicit) | RNE (default) | Out-of-range → ±maxpos or error |
| Posit n es | Rational | Yes (lossless) | None | Exact decoding of posit bit pattern; NaR → error |
| Posit n₁ es → Posit n₂ es (n₂ > n₁) | Yes (widening) | None | Always exact |
| Posit n₁ es → Posit n₂ es (n₂ < n₁) | No (narrowing) | RNE | Saturation to ±maxpos or error |
| Float → Posit | No (explicit) | RNE | ±Inf → NaR, NaN → error, ±0 → 0 |
| Posit → Float | No (explicit) | RNE | NaR → NaN |
| Valid → (Posit, Posit) | Yes (destructure) | None | Extract lower and upper bounds |
| Posit → Valid | Yes (point interval) | None | Creates [x, x] (both ubits 0) |

All narrowing or lossy conversions require explicit function calls. The rounding mode can be overridden via an optional parameter, supporting round-to-nearest-even (default), round-toward-zero, round-up, round-down, and (for ML workloads) stochastic rounding.

### 14.5 Valid Types and Interval Propagation

Valid types should support automatic interval propagation:

```
-- Arithmetic on valids automatically tracks uncertainty
valid-add : Valid n es -> Valid n es -> Valid n es
valid-mul : Valid n es -> Valid n es -> Valid n es

-- Query interval properties
width : Valid n es -> Posit n es
contains : Valid n es -> Posit n es -> Bool
```

The compiler can optionally insert valid-mode computation to verify the accuracy of posit-mode computation—a form of runtime assertion that the programmer can enable or disable per module or per function:

```
-- Annotation to enable interval-tracking verification
@verify-bounds
compute-trajectory : Posit32 -> Posit32 -> Posit32
```

### 14.6 Arbitrary Precision and Efficient Representation

Πρόλογος's commitment to arbitrary-precision integers and rationals (from the NOTES.org desiderata) dovetails with the unum philosophy:

**Integers never wrap.** Attempting to compute an integer that exceeds a fixed-width representation is an error (compile-time if detectable, runtime otherwise), never a silent wrap to a negative value. This aligns with Gustafson's philosophy: the computer should never silently give a wrong answer.

**Rationals are exact.** Rational arithmetic produces exact results. The language provides efficient big-integer and big-rational implementations (using GMP or a custom implementation with structural sharing).

**Posits are the "hardware-speed approximate" tier.** When the programmer wants fast hardware-speed computation and is willing to accept bounded approximation, they use posit types. The type system makes the boundary between exact and approximate computation explicit and visible.

**Seamless promotion.** The language can promote from posit to rational when exact results are needed:

```
-- Promote posit to rational (exact conversion of the posit's encoded value)
to-rational : Posit n es -> Rational

-- Promote valid to rational interval
to-rational-interval : Valid n es -> (Rational, Rational)
```

### 14.7 Error Handling: No Silent Wrapping

Drawing on both the NOTES.org desiderata and the unum philosophy, Πρόλογος should adopt a strict "no silent wrapping" policy for all numeric types:

**Integer overflow.** Detected at compile time where possible (through dependent types and refinement types); a runtime error otherwise. Never silent.

**Posit extremes.** When a computation produces a result beyond maxpos, the behavior should be configurable per compilation unit: saturate to maxpos (the posit standard behavior), raise a runtime error, or automatically promote to a wider posit/arbitrary-precision type.

**NaR propagation.** Like NaN in IEEE 754, NaR propagates through computation. But unlike IEEE 754's silent NaN propagation, Πρόλογος can optionally make NaR generation a runtime error (fail-fast mode) rather than a silently propagating poison value.

**Loss of precision.** The type system can track precision loss and warn (or error) when a computation might lose more precision than a programmer-specified threshold.

### 14.8 Compilation Targets and LLVM Considerations

Since Πρόλογος targets LLVM:

**Posit operations as LLVM IR.** LLVM does not natively support posit arithmetic, so posit operations will compile to calls to a posit arithmetic library (initially SoftPosit, potentially upgraded to a JIT-optimized version). On hardware with native posit support (future RISC-V extensions, CalligoTech TUNGA), the compiler can emit native instructions.

**Quire operations.** On x86 with AVX-512, a posit32 quire (512 bits) can be mapped to a single AVX-512 register, enabling efficient fused multiply-accumulate. The compiler should detect quire-eligible accumulation patterns and lower them to optimized quire operations.

**IEEE 754 interop.** Conversion between posit and IEEE 754 types is needed for FFI with C/C++/Rust libraries. The compiler should generate inline conversion routines that are as efficient as possible, with correct rounding per the 2022 Standard.

**LLVM vector extensions.** For SIMD-style posit computation, the compiler can use LLVM's vector types with element-wise posit operations. This enables vectorized posit computation on CPUs with wide SIMD units, even without dedicated posit hardware.

### 14.9 A Concrete Design Sketch for Πρόλογος

Bringing it all together, here is a concrete sketch of the numeric subsystem for Πρόλογος, using the language's homoiconic prefix-notation syntax with `()` groupings:

```
;; === Type declarations ===

;; The numeric type hierarchy
(type Numeric
  Int                           ;; arbitrary-precision integer
  Rational                      ;; arbitrary-precision rational
  (Posit n:Nat es:Nat)          ;; parameterized posit type
  (Valid n:Nat es:Nat)           ;; parameterized valid type
  (Quire n:Nat es:Nat)          ;; parameterized quire type
  (Float ieee:IEEEFormat))      ;; IEEE 754 for interop

;; Standard posit aliases
(def Posit8  (Posit 8 2))
(def Posit16 (Posit 16 2))
(def Posit32 (Posit 32 2))
(def Posit64 (Posit 64 2))

;; === Literal handling ===

;; Numeric literals are polymorphic, resolved by context
;; 42   : Int (default for integer literals)
;; 3.14 : Rational (default for decimal literals)
;; When a specific posit type is expected:
;; 3.14 : Posit32  (converted via round-to-nearest-even)

;; === Quire-based dot product with linear types ===

(def fdp
  (forall (k:Nat n:Nat es:Nat)
    (-> (Vec k (Posit n es))
        (Vec k (Posit n es))
        (Posit n es))
    (fn (xs ys)
      (let-linear (q (quire/new {n} {es}))
        (let-linear (q (foldl-linear
                         (fn (q x y) (quire/fma q x y))
                         q
                         (zip xs ys)))
          (quire/extract q))))))

;; === Valid-mode computation ===

(def safe-divide
  (-> (Valid32) (Valid32)
      (Result Valid32 ArithError))
  (fn (x y)
    (if (valid/contains y (to-posit32 0))
      (Err DivisionByZero)
      (Ok (valid/div x y)))))

;; === Precision-dependent types ===

(def matrix-solve
  (forall (n:Nat)
    {prf : GTE n 32}            ;; require at least 32-bit posits
    (-> (Matrix n n (Posit n 2))
        (Vec n (Posit n 2))
        (Vec n (Posit n 2))))
```

This sketch illustrates several key design decisions:

1. **Dependent types parameterize numeric precision** at the type level
2. **Linear types govern quire lifetimes**, preventing resource leaks
3. **Valids provide rigorous error bounds** through interval arithmetic
4. **No implicit lossy conversions**: all precision-reducing conversions are explicit
5. **Literals are exact (rational) by default**, converted to approximate types explicitly
6. **The quire-based dot product** is a primitive operation, not a library afterthought
7. **Homoiconic syntax** with `()` groupings (not `[]`) as specified in NOTES.org

---

## 15. References and Key Literature

### Foundational Works

1. Gustafson, J. L. (2015). *The End of Error: Unum Computing*. CRC Press.
2. Gustafson, J. L. & Yonemoto, I. (2017). "Beating Floating Point at Its Own Game: Posit Arithmetic." *Supercomputing Frontiers and Innovations*, 4(2).
3. Kulisch, U. W. (2013). *Computer Arithmetic and Validity: Theory, Implementation, and Applications*. De Gruyter.
4. IEEE Standard for Floating-Point Arithmetic, IEEE Std 754-2019.
5. Posit Standard 2022. Posit Working Group.

### Type I and Type II Unums

6. Gustafson, J. L. (2016). "A Radical Approach to Computation with Real Numbers." *Supercomputing Frontiers and Innovations*, 3(2).
7. Gustafson, J. L. (2017). "Posit Arithmetic." Technical report.

### Posit Analysis and Benchmarking

8. Cococcioni, M. et al. (2021). "Small Reals Representations for Training Neural Networks." *Neural Computing and Applications*.
9. De Matteis, A. et al. (2020). "Posit Arithmetic for the Training and Deployment of Generative Adversarial Networks." *Design, Automation and Test in Europe (DATE)*.
10. Murillo, R. et al. (2020). "Comparing Posit and IEEE-754 Hardware Cost." *IEEE International Symposium on Circuits and Systems (ISCAS)*.
11. Carmichael, Z. et al. (2019). "Deep Positron: A Deep Neural Network Using the Posit Number System." *Design, Automation and Test in Europe (DATE)*.

### Hardware Implementations

12. Jaiswal, M. K. & So, H. K.-H. (2018). "PACoGen: A Hardware Posit Arithmetic Core Generator." *IEEE Access*.
13. Mallasén, D. et al. (2022). "PERCIVAL: Open-Source Posit RISC-V Core with Quire Capability." *IEEE Transactions on Emerging Topics in Computing*.
14. Mallasén, D. et al. (2023). "Big-PERCIVAL: Exploring the Native Use of 64-Bit Posit Arithmetic in Scientific Computing." *IEEE Access*.

### Criticisms and Debates

15. Kahan, W. (2016). "A Critique of John L. Gustafson's THE END OF ERROR—Unum Computation and His A Radical Approach to Computation with Real Numbers." Manuscript.
16. De Dinechin, F. (2019). "Posits: the good, the bad, and the ugly." Manuscript.

### Beyond Posits

17. Hunhold, L. (2024). "Takum Arithmetic." Preprint.
18. Johnson, J. (2018). "Rethinking floating point for deep learning." Preprint (LNS-Madam foundations).
19. OCP Microscaling Formats (MX) Specification, v1.0, 2023. Open Compute Project.
20. Roesler, G. & Langroudi, S. H. F. (2023). "Precision and Performance: Posits and Beyond." IEEE Symposium on Computer Arithmetic.

### Software Libraries

21. Leong, C. SoftPosit. https://gitlab.com/cerlane/SoftPosit
22. Omtzigt, E. T. L. et al. Universal Number Arithmetic Library. https://github.com/stillwater-sc/universal
23. Benz, B. sfpy: SoftPosit for Python. https://github.com/bwbenz/sfpy
24. Byrne, S. SoftPosit.jl. https://github.com/stevebyrne/SoftPosit.jl
25. Haskell Posit package. Hackage.

### Interval Arithmetic

26. Moore, R. E. (1966). *Interval Analysis*. Prentice-Hall.
27. Tucker Taft, S. (2021). "IEEE Standard for Interval Arithmetic: IEEE 1788-2015."
28. Johansson, F. (2017). "Arb: Efficient Arbitrary-Precision Midpoint-Radius Interval Arithmetic." *IEEE Transactions on Computers*.

### Formal Verification

29. Boldo, S. & Melquiond, G. (2011). "Flocq: A Unified Library for Proving Floating-Point Algorithms in Coq." *IEEE Symposium on Computer Arithmetic*.
30. Benz, F. et al. (2022). "Formal Verification of Posit Arithmetic." *Formal Methods in Computer-Aided Design (FMCAD)*.

### Stochastic Rounding

31. Connolly, M. P. et al. (2021). "Stochastic Rounding and its Probabilistic Backward Error Analysis." *SIAM Journal on Scientific Computing*.
32. Gupta, S. et al. (2015). "Deep Learning with Limited Numerical Precision." *International Conference on Machine Learning (ICML)*.
