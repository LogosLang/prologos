# Comprehensive String Library: Research & Design

**Date**: 2026-02-21
**Status**: Research / Pre-implementation
**Scope**: UTF-8 string type, character type, functional string operations, backing data structure selection, Unicode strategy, trait integration, phased implementation roadmap

---

## 1. Executive Summary

Prologos currently has **zero string support** -- no `String` type, no `Char` type, no string literals in the AST, no FFI marshalling for strings. This document designs a comprehensive string library that:

1. Treats strings as **immutable UTF-8 sequences** with first-class Prologos support
2. Integrates with the **existing trait/collection infrastructure** (Seqable, Foldable, Buildable, Eq, Ord, Hashable)
3. Provides a **Clojure-inspired API** with `str` as variadic concat, functional transformations, and seq interop
4. Supports **three levels of Unicode abstraction**: bytes, codepoints, and grapheme clusters
5. Uses **Racket strings as the backing store** (flat UTF-8 via FFI), with potential future rope support for large text processing
6. Is written in **pure Prologos** (leveraging FFI primitives for the leaf operations)

**Key architectural decision**: Strings are opaque FFI values backed by Racket strings, NOT linked lists of characters. This gives us O(1) length, O(1) byte indexing, efficient memory representation, and access to Racket's mature Unicode support -- while maintaining a pure functional API surface.

---

## 2. Cross-Language Survey

### 2.1 Design Philosophy Comparison

| Language | Internal Repr | Default Unit | Immutable? | Key Innovation |
|----------|--------------|-------------|------------|----------------|
| **Clojure** | Java String (UTF-16) | Char (UTF-16 unit) | Yes | `str` as variadic concat; seq abstraction; `clojure.string` namespace |
| **Go** | `[]byte` (UTF-8) | `rune` (codepoint) | Yes | `Cut`/`CutPrefix`/`CutSuffix`; `Builder`; `NewReplacer` |
| **Rust** | `Vec<u8>` (UTF-8) | `char` (scalar value) | `&str` yes; `String` mutable | `Pattern` trait; `Cow<str>`; no integer indexing |
| **Java** | `byte[]` + coder flag | `char` (UTF-16 unit) | Yes | `intern()`; `transform()`; Compact Strings; text blocks |
| **Haskell** | `ByteArray#` (UTF-8, text-2.0) | `Char` (codepoint) | Yes | Stream fusion; `breakOn`/`breakOnAll`; `toCaseFold`; Builder |
| **Elixir** | Erlang binary (UTF-8) | Grapheme cluster | Yes | Grapheme-aware by default; `jaro_distance`; `myers_difference`; `splitter` (lazy) |

### 2.2 Functions Found Across All/Most Languages

These constitute the **core API** that any string library must provide:

| Category | Functions |
|----------|-----------|
| **Construction** | empty, singleton/from-char, from-list, concat/append |
| **Length/Empty** | length, empty?, byte-length |
| **Access** | nth/at, first, last, slice/substring |
| **Search** | contains?, starts-with?, ends-with?, index-of, last-index-of |
| **Case** | to-upper, to-lower, capitalize |
| **Trim** | trim, trim-start, trim-end |
| **Split/Join** | split, split-once, join, lines, words |
| **Replace** | replace, replace-first |
| **Transform** | map, filter, reverse, repeat |
| **Fold** | foldl, foldr, any, all |
| **Comparison** | eq?, compare, eq-ignore-case? |
| **Conversion** | to-list, from-list, to-bytes, to-nat (parse) |

### 2.3 Innovative Functions Worth Adopting

From **Clojure**:
- `str` as variadic concat (`str a b c` = `"abc"`) -- our primary concat
- `blank?` -- empty or whitespace only
- String/seq interop via `seq`/`apply str`

From **Go**:
- `cut` / `cut-prefix` / `cut-suffix` -- split-once returning `Option (Pair String String)`. Solved the "did the operation find anything?" problem elegantly
- `fields` -- split on arbitrary whitespace runs (not a fixed separator)

From **Rust**:
- `Pattern` trait concept -- unify matching on char, string, predicate. In Prologos: use trait dispatch or union types
- `split-once` / `rsplit-once` -- `Option (Pair String String)` on first/last occurrence
- `strip-prefix` / `strip-suffix` returning `Option String`

From **Haskell Data.Text**:
- `break-on` / `break-on-all` -- break around a literal needle, returning all positions
- `common-prefixes` -- find common prefix of two strings + remainders
- `case-fold` -- aggressive Unicode case folding for comparison
- `chunks-of` -- fixed-size chunks
- `map-accum-l` / `map-accum-r` -- stateful map with accumulator
- `unfold` -- generate string from seed

From **Elixir**:
- `jaro-distance` -- built-in string similarity (0.0 to 1.0). Great for "did you mean?" suggestions
- `myers-difference` -- structured edit script. Built-in diffing!
- `normalize` with all four Unicode forms (NFC, NFD, NFKC, NFKD)
- `equivalent?` -- canonical equivalence check
- `splitter` returning lazy stream -- crucial for large inputs
- Grapheme-cluster awareness as the default for length/reverse/slice

### 2.4 Design Decision: Prologos String API Shape

Following Clojure's philosophy with Elixir's Unicode correctness:

```prologos
;; Core namespace: prologos::data::string
;; Operations namespace: prologos::core::string-ops

;; Clojure-style: `str` is variadic concat
str "hello" " " "world"        ;; => "hello world"
str x                           ;; => string representation of x (via Show trait)

;; Seq interop
to-seq "hello"                  ;; => LSeq Char: ~['h' 'e' 'l' 'l' 'o']
from-seq ~['h' 'i']            ;; => "hi"

;; Functional transformations
str::map to-upper "hello"       ;; => "HELLO"
str::filter alpha? "a1b2c3"     ;; => "abc"

;; Elixir-inspired Unicode correctness
str::length "cafe\u0301"        ;; => 4 (codepoints)
str::grapheme-count "cafe\u0301"   ;; => 4 (but e+accent = 1 grapheme => 4 total chars here)

;; Go-inspired ergonomics
str::split-once "key=value" "=" ;; => Some (Pair "key" "value")
str::words "  hello   world "   ;; => '["hello" "world"]
```

---

## 3. Data Structure Analysis

### 3.1 Backing Store Options

| Structure | Index | Concat | Split | Space | Cache | Persistent? | Best For |
|-----------|-------|--------|-------|-------|-------|-------------|----------|
| **Flat UTF-8** | O(1) byte / O(n) cp | O(n+m) | O(n) | None | Excellent | Copy-only | General strings (<1MB) |
| **Flat + SSO** | O(1) byte / O(n) cp | O(n+m) | O(n) | ~8B tag | Excellent | Copy-only | Short strings (identifiers) |
| **B-tree Rope** | O(log_B n) | O(log_B n) | O(log_B n) | ~128B/node | Good | Via COW | Text editing, large files |
| **RRB-Tree** | O(log32 n) | O(log n) | O(log n) | ~32B/node | Good | Natural | General persistent seqs |
| **Finger Tree** | O(log n) | O(log min) | O(log min) | ~48B/node | Poor | Natural | Deques, sequences |
| **Piece Table** | O(log p) | O(log p) | O(log p) | ~24B/piece | Good | Possible | Document editing |

### 3.2 Scryer Prolog's Approach

Scryer Prolog uses **packed string representation** -- storing UTF-8 bytes directly in the term heap as a specialized list structure, avoiding per-character cons cells. Key insights:

- Traditional Prolog represents strings as lists of character codes: each character is a cons cell (2 words) + an integer atom. A 100-character string costs ~200 words.
- Scryer's packed strings store the UTF-8 bytes inline in a special term, with list-like destructuring via a custom unification rule. A 100-byte string costs ~13 words + header.
- The representation supports **partial strings** (difference lists) efficiently for DCG parsing.
- **Relevance for Prologos**: Our situation is different because we have immutable opaque types (like PVec, Map, Set) backed by Racket values. We don't have the "everything is a cons cell" overhead that Scryer optimizes away. **Verdict**: Scryer's approach solves a Prolog-specific problem. Our FFI-opaque strategy is already equivalent to or better than packed strings for our architecture.

### 3.3 RRB-Tree Assessment (Our Existing PVec Backend)

We already have RRB-Trees powering `PVec`. Could we reuse them for strings?

**Pros:**
- Already implemented (`expr-rrb` with 14 AST nodes)
- O(log32 n) indexed access, O(log n) concat, efficient slicing
- Persistent/immutable by nature
- String would just be `PVec Char` with a newtype wrapper

**Cons:**
- 32-wide branching stores individual `Char` values, not UTF-8 byte chunks. Each character is a separate boxed value.
- No UTF-8 compactness -- a PVec of chars is ~8 bytes per character (pointer per element) vs 1-4 bytes in UTF-8
- `string-length` on RRB is O(1) for element count, but `byte-length` would need separate tracking
- No SIMD-friendly memory layout

**Verdict**: RRB-Tree makes sense if strings need heavy random access and structural sharing. For a V1 string library, **flat Racket strings via FFI** are simpler and more memory-efficient. RRB-Tree `PVec Char` could be a secondary "text buffer" type.

### 3.4 CHAMP Trie Assessment

CHAMP tries (used by our Map and Set) are **not suitable for strings**. They're hash-based associative structures, not sequential. No indexed access, no ordered iteration.

### 3.5 Recommendation: Flat Racket Strings (Phase 1), Optional Rope (Future)

**Phase 1**: Opaque FFI type wrapping Racket strings.
- Racket strings are immutable, Unicode-aware, well-optimized
- O(1) length (Racket caches it), O(1) byte access
- All Racket string functions available via FFI
- Memory-compact (UTF-8 or UCS-4 depending on content, Racket handles this)

**Future**: If users need mutable text buffers or very large string manipulation (editors, compilers processing source), consider adding a `Rope` or `TextBuffer` type backed by a B-tree rope. This would be a separate type, not a replacement for `String`.

---

## 4. Unicode Strategy

### 4.1 The Three Levels

| Level | Unit | Example: `"cafe\u0301"` | When to Use |
|-------|------|--------------------------|-------------|
| **Bytes** | Raw UTF-8 bytes | 6 bytes: `63 61 66 65 CC 81` | Binary protocols, hashing, low-level |
| **Codepoints** | Unicode scalar values | 5 codepoints: `c a f e \u0301` | Default for most string operations |
| **Graphemes** | Extended grapheme clusters | 4 graphemes: `c a f e\u0301` | User-facing text (display, editing) |

### 4.2 Prologos Unicode Design

Following Elixir's three-level model but with **codepoints as the default** (pragmatic choice matching Go, Rust, Haskell):

```prologos
;; Default: codepoint operations
length "cafe\u0301"                 ;; => 5 (codepoints) -- this is the pragmatic default
byte-length "cafe\u0301"            ;; => 6 (UTF-8 bytes)
grapheme-count "cafe\u0301"         ;; => 4 (grapheme clusters)

;; Iteration at different levels
codepoints "hi"                     ;; => LSeq Char
bytes "hi"                          ;; => LSeq Nat (byte values)
graphemes "cafe\u0301"              ;; => LSeq String (each grapheme as a string)
```

**Rationale for codepoints as default** (not graphemes):
1. Codepoint operations are O(n) but with small constants -- no Unicode lookup tables needed
2. Grapheme segmentation requires UAX #29 state machine (~30KB tables, quarterly Unicode updates)
3. Most programmatic string processing (parsing, templating, protocol handling) works at the codepoint level
4. Grapheme-level operations can be provided as a separate module (`prologos::text::grapheme`)
5. This matches Go, Rust, Haskell, Java -- only Elixir defaults to graphemes

### 4.3 Char Type Design

A `Char` represents a Unicode codepoint (U+0000 to U+10FFFF, excluding surrogates).

```prologos
;; Char : Type 0
;; Constructed from character literals: \a, \newline, \u0041
;; Backed by Racket char (via FFI)

;; Core operations (in prologos::data::char; qualify as char::code etc.)
code : Char -> Nat               ;; codepoint as natural number
from-code : Nat -> Option Char   ;; Nat -> Char (validates range)
upper : Char -> Char
lower : Char -> Char
alpha? : Char -> Bool
digit? : Char -> Bool
whitespace? : Char -> Bool
upper? : Char -> Bool
lower? : Char -> Bool
```

### 4.4 Unicode Normalization (Deferred)

Full Unicode normalization (NFC/NFD/NFKC/NFKD) is complex and version-dependent. Recommendation:
- **Phase 1**: Skip normalization. Provide `normalize` as a TODO.
- **Phase 2**: Bridge to Racket's `string-normalize-nfc` etc. via FFI.
- **Future**: Pure Prologos normalization if ever needed (unlikely -- FFI is fine here).

---

## 5. Current Infrastructure Gaps

### 5.1 Critical Gaps (Must Fill Before String Library)

| Gap | Severity | Fix | Files Affected |
|-----|----------|-----|---------------|
| **No Char type** | CRITICAL | Add `expr-Char` / `expr-char` AST nodes | 14 AST pipeline files |
| **No String type** | CRITICAL | Add `expr-String` / `expr-string` AST nodes | 14 AST pipeline files |
| **No char literal syntax** | CRITICAL | Reader support for `'a'` character literals | reader.rkt |
| **String literal → AST** | CRITICAL | Parser route for `"..."` → `expr-string` | parser.rkt |
| **No FFI String marshalling** | HIGH | Add String case to `foreign.rkt` | foreign.rkt |
| **No String pretty-printing** | HIGH | Add String case to `pretty-print.rkt` | pretty-print.rkt |

### 5.2 Infrastructure Already Available

| Capability | Status | Notes |
|-----------|--------|-------|
| Trait system | Ready | Eq, Ord, Add, Hashable, Seqable, Foldable, Buildable all defined |
| FFI mechanism | Ready | `foreign racket "module" [name : Type]` works for opaque types |
| Module system | Ready | `ns`, `require`, `refer`, prelude auto-loading |
| Reader (string literals) | Partial | Racket reader already handles `"..."` -- just need AST routing |
| Test infrastructure | Ready | Shared fixture pattern, dep-graph, parallel runner |
| Dep-graph validation | Ready | `update-deps.rkt --check` |

### 5.3 Reader Analysis

The Racket reader already tokenizes `"hello"` as a string datum. The question is whether Prologos's WS reader preserves this. Empirical testing needed, but likely:
- Sexp mode: `(def s "hello")` -- the Racket reader produces a string datum, which our parser needs to route to `expr-string`
- WS mode: `def s "hello"` -- the tokenizer needs to recognize string literals and produce a `'string-literal` token type

---

## 6. API Design: Complete Function List

### 6.1 Module: `prologos::data::string` (Core Type + Primitives)

These are the FFI-backed leaf operations. Each wraps a Racket primitive.

```prologos
;; === Type ===
;; String : Type 0
;; Char : Type 0

;; === Construction ===
empty : String                                 ;; ""
singleton : Char -> String                     ;; single character string
str : String -> String -> String               ;; binary concat (variadic via preparse macro)

;; === Length ===
length : String -> Nat                         ;; codepoint count
byte-length : String -> Nat                    ;; UTF-8 byte count
empty? : String -> Bool                        ;; length == 0

;; === Access ===
nth : Nat -> String -> Option Char             ;; codepoint at index
first : String -> Option Char                  ;; first codepoint
last : String -> Option Char                   ;; last codepoint

;; === Slicing ===
slice : Nat -> Nat -> String -> String         ;; start, length -> substring
take : Nat -> String -> String                 ;; first n codepoints
drop : Nat -> String -> String                 ;; drop first n codepoints
take-end : Nat -> String -> String             ;; last n codepoints
drop-end : Nat -> String -> String             ;; drop last n codepoints

;; === Comparison (FFI leaf) ===
eq? : String -> String -> Bool
compare : String -> String -> Ordering
hash : String -> Nat

;; === Char operations (in prologos::data::char) ===
code : Char -> Nat
from-code : Nat -> Option Char
eq? : Char -> Char -> Bool
compare : Char -> Char -> Ordering
upper : Char -> Char
lower : Char -> Char
alpha? : Char -> Bool
digit? : Char -> Bool
whitespace? : Char -> Bool
```

> **Naming convention**: All library functions use short names without module prefixes. Users qualify via module alias: `str::length`, `str::split`, `char::alpha?`, `char::code`. This follows the Prologos convention established by existing modules (e.g., `list::map`, `opt::unwrap-or`).

### 6.2 Module: `prologos::core::string-ops` (Functional Operations)

These are written in pure Prologos, using the primitives from 6.1 and the seq abstraction.

```prologos
;; === Searching ===
contains? : String -> String -> Bool
starts-with? : String -> String -> Bool
ends-with? : String -> String -> Bool
index-of : String -> String -> Option Nat
last-index-of : String -> String -> Option Nat
count : String -> String -> Nat                ;; count non-overlapping occurrences

;; === Case Conversion ===
upper : String -> String
lower : String -> String
capitalize : String -> String                  ;; first char upper, rest lower

;; === Trimming ===
trim : String -> String                        ;; trim Unicode whitespace
trim-start : String -> String
trim-end : String -> String
strip-prefix : String -> String -> Option String
strip-suffix : String -> String -> Option String

;; === Splitting & Joining ===
split : String -> String -> List String        ;; split on separator
split-once : String -> String -> Option (Pair String String)  ;; Go's Cut
rsplit-once : String -> String -> Option (Pair String String)
lines : String -> List String                  ;; split on \n
words : String -> List String                  ;; split on whitespace runs (Go's Fields)
join : String -> List String -> String         ;; join with separator
unlines : List String -> String                ;; join with \n
unwords : List String -> String                ;; join with space
chunks : Nat -> String -> List String          ;; fixed-size chunks

;; === Replacement ===
replace : String -> String -> String -> String ;; pattern -> replacement -> input -> result
replace-first : String -> String -> String -> String

;; === Transformation ===
map : (Char -> Char) -> String -> String
filter : (Char -> Bool) -> String -> String
reverse : String -> String
repeat : Nat -> String -> String
pad-start : Nat -> Char -> String -> String
pad-end : Nat -> Char -> String -> String
intercalate : String -> List String -> String  ;; alias for join

;; === Predicates ===
blank? : String -> Bool                        ;; empty or all whitespace
all? : (Char -> Bool) -> String -> Bool
any? : (Char -> Bool) -> String -> Bool

;; === Folding ===
foldl : (A -> Char -> A) -> A -> String -> A
foldr : (Char -> A -> A) -> A -> String -> A

;; === Conversion ===
to-list : String -> List Char
from-list : List Char -> String
to-lseq : String -> LSeq Char                 ;; for seq interop
from-lseq : LSeq Char -> String
to-nat : String -> Option Nat                  ;; parse
to-int : String -> Option Int                  ;; parse
codepoints : String -> LSeq Char              ;; alias for to-lseq
bytes : String -> LSeq Nat                    ;; UTF-8 byte values

;; === Similarity (Phase 3+, deferred) ===
jaro-distance : String -> String -> Rat        ;; 0.0 to 1.0
common-prefix : String -> String -> String     ;; longest common prefix
```

### 6.3 Module: `prologos::core::string-traits` (Trait Instances)

```prologos
;; String trait instances
impl Eq String          ;; via eq?
impl Ord String         ;; via compare
impl Add String         ;; via str (concatenation)
impl Hashable String    ;; via hash
impl Seqable String     ;; via to-lseq
impl Buildable String   ;; via from-lseq
impl Foldable String    ;; via foldl
impl Indexed String     ;; via nth, length

;; Char trait instances
impl Eq Char            ;; via eq?
impl Ord Char           ;; via compare
impl Hashable Char      ;; via code (as hash)
```

### 6.4 Polymorphic `str` via Preparse Macro

Following Clojure's design, `str` should be variadic AND polymorphic — it accepts any argument type, not just strings. Non-string arguments are implicitly converted via `show`. This makes `str` the 80% ergonomic choice for string construction:

```prologos
str "hello"                         ;; => "hello" (identity)
str "hello" " " "world"             ;; => "hello world" (concat all args)
str "My favorite number: " " " 67   ;; => "My favorite number: 67" (auto-show on Int)
str "count=" n " items"             ;; => "count=5 items" (if n : Nat = 5N)
```

For programmers who want more specificity:
- `str-strict : String ... -> String` — variadic concat, strings only (no implicit show)
- `show : {A : Type} (Show A) -> A -> String` — explicit conversion, returns String

**Implementation**: `str` is a preparse macro that rewrites each argument:
- If the argument is a string literal, pass through
- Otherwise, wrap in `(show arg)` to convert via the Show trait
- Then fold all results via `string-append`

`(str a b c)` → `(string-append (show a) (string-append (show b) (show c)))`

The `show` dispatch is zero-cost for String arguments since `impl Show String` is the identity function.

---

## 7. Trait Integration Design: Prologos Bundles

### 7.1 Why Bundles Matter for the String Library

Prologos's trait system is fundamentally different from languages with trait inheritance (Rust's supertraits, Haskell's superclasses). Viewing traits and constraints from a logic-programming perspective (Curry-Howard correspondence), we recognized that:

- **Trait inheritance is logical implication** (`Ord: Eq` means `Ord → Eq`). This creates hierarchies, nested dictionaries, and diamond problems.
- **Bundles are logical conjunction** (`bundle Comparable := (Eq, Ord)` means `Eq ∧ Ord`). Traits remain fully independent; no trait "knows about" any other.

The Prolog analogy is precise: a bundle is a *named compound goal*, exactly like `comparable(A) :- eq(A), ord(A).` in Prolog. It is easy to compose and reuse predicates as sub-rules within other predicates — through sequents of conjunctive statements.

**Key properties**:
- **Zero conflicts**: Bundles are flat sets of aliased traits. Composing bundles with other bundles or individual traits never creates diamond problems or method resolution ambiguity — it's just further type refinement.
- **Zero runtime overhead**: Bundles are fully erased at desugar time. No bundle types, bundle dicts, or bundle accessors exist at runtime. After expansion, the system only sees flat, independent trait constraints with individual dict parameters.
- **No AST nodes**: Bundles have zero representation in `syntax.rkt`, `surface-syntax.rkt`, `elaborator.rkt`, `typing-core.rkt`, or any pipeline file. They exist only in the preparse layer (`macros.rkt`), registered in a `bundle-registry` and expanded to flat constraint lists by `expand-bundle-constraints`.

### 7.2 Bundle Mechanics (How It Works)

```prologos
;; Define a bundle — flat set of trait aliases
bundle Stringlike := (Eq, Ord, Hashable, Seqable, Buildable, Foldable)

;; Use in a spec — expands to 6 individual dict parameters
spec generic-process {A : Type} [A] -> A where (Stringlike A)

;; After preparse expansion, the system sees:
;; spec generic-process {A : Type} (Eq A) (Ord A) (Hashable A)
;;                      (Seqable A) (Buildable A) (Foldable A) [A] -> A
```

Bundles can nest other bundles:
```prologos
bundle Comparable := (Eq, Ord)
bundle TextLike := (Comparable, Hashable, Seqable, Foldable)
;; TextLike A expands → (Eq A) (Ord A) (Hashable A) (Seqable A) (Foldable A)
;; Deduplication removes any repeated constraints automatically
```

At expansion time, each trait constraint becomes an implicit dict parameter (e.g., `$Eq-A`, `$Ord-A`) prepended to the function signature. The trait resolution engine fills them in at call sites from the impl registry.

### 7.3 String as a Collection (via Bundles)

String naturally satisfies many collection-related traits. With bundles, we can express combined requirements ergonomically:

```prologos
;; In prologos::core::string-bundles.prologos:
bundle StringCollection := (Eq, Ord, Hashable, Seqable, Buildable, Foldable, Indexed)

;; Generic collection operations automatically work on strings:
from-seq [map char-upper [to-seq "hello"]]    ;; => "HELLO"
from-seq [filter alpha? [to-seq "a1b2c3"]]    ;; => "abc"
fold str "" '["hello" " " "world"]             ;; => "hello world"
```

Individual trait instances for String:

| Trait | Implementation | Notes |
|-------|---------------|-------|
| `Eq String` | via `eq?` FFI | Structural equality |
| `Ord String` | via `compare` FFI | Lexicographic ordering |
| `Hashable String` | via `hash` FFI | Consistent with Eq |
| `Add String` | via `str` FFI | Concatenation as addition |
| `Seqable String` | via `to-lseq` | Yields `LSeq Char` |
| `Buildable String` | via `from-lseq` | Builds from `LSeq Char` |
| `Foldable String` | via `foldl` | Left fold over codepoints |
| `Indexed String` | via `nth`, `length` | Codepoint indexing |

Existing bundles like `Num` (= `Add, Sub, Mul, Neg, Eq, Ord, Abs, FromInt`) and `Fractional` (= `Num, Div, FromRat`) demonstrate that this pattern scales well — `Fractional A` expands to 10 flat constraints with zero overhead.

### 7.4 Advantage Over Trait Inheritance for Strings

In Rust or Haskell, integrating strings into the trait hierarchy requires careful placement: does `String : Display`? Does `Display : Debug`? Does `Iterable : Collection`? These supertrait hierarchies create rigid dependency chains.

In Prologos, each trait is independent. If a function needs `Eq`, `Foldable`, and `Seqable`, you can:
1. List them individually: `where (Eq A) (Foldable A) (Seqable A)`
2. Create an ad-hoc bundle: `bundle MyNeeds := (Eq, Foldable, Seqable)`
3. Reuse an existing bundle that includes them: `where (StringCollection A)`

All three are equivalent after expansion. No method resolution ambiguity, no orphan-instance drama, no trait hierarchy to navigate. This makes the String library's trait integration completely modular — add or remove trait instances without ripple effects.

### 7.5 Show Trait Integration

The `Show` trait (if/when defined) allows `str` to convert any value to string:

```prologos
trait Show {A}
  show : A -> String

impl Show Nat
  defn show [n] (nat-to-string n)

impl Show String
  defn show [s] s

;; Then str can use Show:
str "count: " [show 42N]  ;; => "count: 42"

;; And Show can be bundled with other display-related traits:
bundle Displayable := (Show, Eq)
```

---

## 8. Phased Implementation Plan

### Phase 0: Char Type (Foundation)

**Goal**: Define the `Char` type with AST nodes, reader syntax, and basic operations.

**Prerequisites**: None (greenfield)

**Files changed**:
- `syntax.rkt` -- Add `expr-Char`, `expr-char` (2 new AST nodes)
- `surface-syntax.rkt` -- Add `surf-char-literal`
- `parser.rkt` -- Parse char literals to surface node
- `elaborator.rkt` -- Elaborate `surf-char-literal` to `expr-char`
- `typing-core.rkt` -- Type rule: `expr-char : Char`
- `reduction.rkt` -- Reduce char operations
- `substitution.rkt` -- Char cases (atoms, no substitution needed)
- `zonk.rkt` -- Char cases (atoms)
- `pretty-print.rkt` -- Print chars: `\a`, `\newline`
- `reader.rkt` -- Tokenize `\a` character literals (new `cond` branch for `\` dispatch)
- `foreign.rkt` -- Marshal Char <-> Racket char
- `lib/prologos/data/char.prologos` -- Char operations module
- `lib/prologos/core/eq-char.prologos` -- `impl Eq Char`
- `lib/prologos/core/ord-char.prologos` -- `impl Ord Char`
- `lib/prologos/core/hashable-char.prologos` -- `impl Hashable Char`
- `tests/test-char.rkt` -- ~20 tests

**Estimated**: ~15 AST node cases across 10 pipeline files + 3 .prologos files + 1 test file

### Phase 1: String Type Foundation

**Goal**: Define the `String` type with AST nodes, literal support, and FFI primitives.

**Prerequisites**: Phase 0 (Char type)

**Files changed**:
- `syntax.rkt` -- Add `expr-String`, `expr-string`, `expr-string-length`, `expr-string-append`, `expr-string-ref`, `expr-string-substring` (6 new AST nodes)
- `surface-syntax.rkt` -- Add `surf-string-literal`
- `parser.rkt` -- Route string datums to `surf-string-literal`
- `elaborator.rkt` -- Elaborate string literals and string operations
- `typing-core.rkt` -- Type rules for string operations
- `reduction.rkt` -- Reduce string operations (delegate to Racket)
- `substitution.rkt`, `zonk.rkt` -- String cases
- `pretty-print.rkt` -- Print strings: `"hello"`
- `reader.rkt` -- Ensure string literals tokenize correctly in WS mode
- `foreign.rkt` -- Marshal String <-> Racket string
- `lib/prologos/data/string.prologos` -- Core String module with FFI primitives
- `tests/test-string.rkt` -- ~30 tests (type formation, literals, basic ops)

**Estimated**: ~30 AST node cases across 10 pipeline files + 1 .prologos file + 1 test file

### Phase 2: Trait Instances & Seq Integration

**Goal**: Make String a first-class collection with trait instances.

**Prerequisites**: Phase 1 (String type)

**Files changed**:
- `lib/prologos/core/eq-string.prologos` -- `impl Eq String`
- `lib/prologos/core/ord-string.prologos` -- `impl Ord String`
- `lib/prologos/core/add-string.prologos` -- `impl Add String` (concat)
- `lib/prologos/core/hashable-string.prologos` -- `impl Hashable String`
- `lib/prologos/core/seqable-string.prologos` -- `impl Seqable String`
- `lib/prologos/core/buildable-string.prologos` -- `impl Buildable String`
- `lib/prologos/core/foldable-string.prologos` -- `impl Foldable String`
- `lib/prologos/core/indexed-string.prologos` -- `impl Indexed String`
- `namespace.rkt` -- Add String modules to prelude auto-loading
- `tools/dep-graph.rkt` -- Add test entries
- `tests/test-string-traits.rkt` -- ~30 tests

**Estimated**: 8 .prologos files + 2 infrastructure files + 1 test file

### Phase 3: Extended String Operations

**Goal**: Full functional string API in pure Prologos.

**Prerequisites**: Phase 2 (trait instances)

**Files changed**:
- `lib/prologos/core/string-ops.prologos` -- All functions from Section 6.2
- `macros.rkt` -- Optional: variadic `str` preparse macro
- `tests/test-string-ops.rkt` -- ~50 tests

**Sub-phases**:
- **3a**: Search operations (contains?, starts-with?, ends-with?, index-of)
- **3b**: Case conversion and trimming (upper, lower, trim, strip-prefix/suffix)
- **3c**: Splitting and joining (split, split-once, lines, words, join)
- **3d**: Replacement and transformation (replace, map, filter, reverse, repeat)
- **3e**: Folding and predicates (foldl, foldr, blank?, all?, any?)
- **3f**: Conversion (to-list, from-list, to-nat, to-int, codepoints, bytes)

### Phase 4: Advanced Features (Deferred)

- **4a**: Grapheme cluster operations (`graphemes`, `grapheme-count`, grapheme-aware `reverse`)
- **4b**: Unicode normalization (NFC/NFD/NFKC/NFKD via FFI)
- **4c**: String similarity (`jaro-distance`, `common-prefix`, `myers-difference`)
- **4d**: Regex integration (if/when regex library exists)
- **4e**: Rope/TextBuffer type for large text processing

---

## 9. Open Design Questions

### 9.1 Character Literal Syntax

Options:

- **`'a'`** -- C/Java/Rust style. **Conflicts** with current `'` usage (list literals: `'[1 2 3]`, quote: `'foo`). The reader dispatches `'` immediately as quote/list-literal prefix — adding paired-quote char literals would create severe parsing ambiguity. **Not viable.**

- **`#\a`** -- Racket/Scheme style. **Conflicts** with current `#` usage. In Prologos, `#` is reserved exclusively for set literals (`#{1 2 3}`). The reader explicitly rejects `#` followed by anything other than `{`: `"# must be followed by { for Set literal"`. Adding `#\` support would require expanding the `#` dispatch, which is feasible but splits the `#` sigil across unrelated purposes (sets vs characters). **Feasible but inelegant.**

- **`\a`** -- Clojure style. **No conflicts.** Backslash (`\`) is currently unused outside string literals. Inside strings, `\n` etc. are escape sequences, but at the top-level tokenizer `\` falls through to the `else` error case: `"Unexpected character: \"`. Since `\` is not in `ident-start?` or `ident-continue?`, it cannot appear in any identifier. This makes `\` a clean, unambiguous prefix for character literals.

- **`c"a"`** -- Tagged string prefix. No conflicts. But awkward for multi-character names: `c"newline"` reads like a string, not a character.

#### Clojure-Style `\` Analysis

Clojure uses `\` followed by a single character or a named character:

| Syntax | Character | Notes |
|--------|-----------|-------|
| `\a` | `a` (U+0061) | Any single character |
| `\A` | `A` (U+0041) | Case-sensitive |
| `\newline` | newline (U+000A) | Named char |
| `\space` | space (U+0020) | Named char |
| `\tab` | tab (U+0009) | Named char |
| `\return` | carriage return (U+000D) | Named char |
| `\backspace` | backspace (U+0008) | Named char |
| `\formfeed` | form feed (U+000C) | Named char |
| `\u0041` | `A` (U+0041) | Unicode escape |

**Implementation in Prologos reader**: Would require a new `cond` branch in `tokenizer-next!` before the final `else`:

```racket
[(char=? c #\\)
 (tok-read! tok)  ;; consume \
 (define next (tok-peek tok))
 (cond
   ;; Named characters
   [(and (char? next) (char-alphabetic? next))
    (define name (read-ident-chars tok))
    (cond
      [(= (string-length name) 1) (token 'char (string-ref name 0) ln cl ps 2)]
      [(string=? name "newline")   (token 'char #\newline ln cl ps 8)]
      [(string=? name "space")     (token 'char #\space ln cl ps 6)]
      [(string=? name "tab")       (token 'char #\tab ln cl ps 4)]
      [(string=? name "return")    (token 'char #\return ln cl ps 7)]
      [else (error "Unknown named character: \\~a" name)])]
   ;; \uXXXX unicode escape
   [(and (char? next) (char=? next #\u))
    ...]
   ;; Single non-alpha character: \!, \?, etc.
   [(char? next)
    (tok-read! tok)
    (token 'char next ln cl ps 2)]
   [else (error "Expected character after \\")])]
```

**Edge case: `\n` ambiguity**. In Clojure, `\n` is the single character `n`, not a newline. The newline character is `\newline`. This is counterintuitive for developers used to `\n` meaning newline in strings. Prologos should follow Clojure's convention here — `\n` = character `n`, `\newline` = newline character — since string escapes (`"\n"`) and character literals (`\n`) operate in different syntactic contexts (inside vs outside double quotes).

**Interaction with string escapes**: No conflict. String escape sequences (`\n`, `\t`, `\\`, `\"`) are handled inside `read-string-token!`, which only fires after a `"` opener. Character literal `\` dispatch fires at the top level. The two contexts are completely disjoint.

**Interaction with other syntax**: No conflict. `\` is not in `ident-start?` or `ident-continue?`, so it can't appear in identifiers. It's not used by any existing reader dispatch. The grammar EBNF currently has no character literal production — one would need to be added.

**Recommendation**: **`\a` (Clojure style)**. It's clean, conflict-free, and consistent with Prologos's existing design sensibility (minimal punctuation, single-character prefixes like `'` for quote, `@` for PVec, `~` for LSeq/approx, `:` for keywords). Adding `\` as the character literal prefix follows the same pattern: a single-character sigil with clear, unambiguous meaning.

The grammar EBNF would add:

```ebnf
char-literal    = '\' , ( letter                  (* single char: \a *)
                        | digit                   (* digit char: \0 *)
                        | char-name               (* named: \newline, \space, \tab *)
                        | 'u' , hex-digit , hex-digit , hex-digit , hex-digit
                                                  (* unicode: \u0041 *)
                        ) ;
char-name       = 'newline' | 'space' | 'tab' | 'return' | 'backspace' | 'formfeed' ;
```

### 9.2 String Type Name

Options:
- `String` -- conventional, clear
- `Str` -- shorter, matches Rust
- `Text` -- matches Haskell

**Recommendation**: `String` -- it's the most widely understood, matches Clojure/Java/Go, and avoids confusion with Haskell's `Text` (which implies a specific non-default representation).

### 9.3 Default Indexing Unit

Options:
- **Codepoints** (Go, Rust, Haskell) -- pragmatic, most algorithms work here
- **Graphemes** (Elixir) -- most correct for user-facing text
- **Bytes** -- fastest, but wrong abstraction for text

**Recommendation**: Codepoints as default, with explicit byte/grapheme functions available. This matches the majority of languages and avoids the performance overhead of grapheme segmentation in the hot path.

### 9.4 PVec Char vs Opaque FFI String

Options:
- **`PVec Char`** with a newtype wrapper -- reuses existing RRB-tree, O(log32 n) indexed access, persistent
- **Opaque FFI** wrapping Racket strings -- O(1) length, compact memory, access to Racket's string functions

**Recommendation**: Opaque FFI for V1. `PVec Char` costs ~8x more memory and doesn't give us the UTF-8 string functions we need. Can always add `PVec Char` as an alternative "text buffer" type later.

---

## 10. Risk Analysis

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| 14-file AST pipeline changes are error-prone | Medium | High | Follow existing Keyword/Symbol pattern exactly; comprehensive tests |
| Character literal syntax conflicts | Low | Low | Use Clojure-style `\a` -- no conflicts with existing syntax |
| String operations too slow via FFI | Low | Medium | Racket strings are well-optimized; profile before optimizing |
| Grapheme operations are complex | Low | Low | Defer to Phase 4; FFI to ICU/Racket's unicode lib |
| `str` variadic macro conflicts | Low | Low | Careful preparse macro scoping (only for symbol `str`) |

---

## 11. Dependency Graph

```
Phase 0: Char Type
    |
    v
Phase 1: String Type Foundation
    |
    v
Phase 2: Trait Instances & Seq Integration
    |
    v
Phase 3: Extended String Operations (3a-3f, can be done incrementally)
    |
    v
Phase 4: Advanced Features (4a-4e, independent of each other)
```

**Critical path**: Phases 0 → 1 → 2 are sequential. Phase 3 sub-phases can be done in any order. Phase 4 items are independent.

**Estimated total**:
- ~20 new AST nodes (Char + String)
- ~12 new .prologos library files
- ~4 new test files, ~130 tests
- ~10 pipeline files touched (14 for each new AST node, but many overlap)

---

## 12. References

### Language Documentation
- Clojure: `clojure.string` namespace, `clojure.core/str`
- Go: `strings` package, `unicode/utf8` package
- Rust: `std::str`, `std::string::String`, `Pattern` trait
- Java: `java.lang.String`, `java.lang.StringBuilder`
- Haskell: `Data.Text`, `Data.Text.Lazy`, `Data.Text.Encoding`
- Elixir: `String` module, Unicode handling guide

### Data Structures
- Boehm, Atkinson, Plass (1995): "Ropes: an Alternative to Strings"
- Ropey crate (Rust): B-tree rope with O(log n) operations
- RRB-Trees: Bagwell & Rompf (2011), used by Clojure PersistentVector
- Scryer Prolog: Packed string representation in WAM

### Unicode
- Unicode Standard Annex #29: Unicode Text Segmentation (grapheme clusters)
- simdutf library: SIMD-accelerated UTF-8 validation and transcoding
- Unicode CLDR: Common Locale Data Repository (for locale-aware operations)

### Search Algorithms
- Boyer-Moore (1977): Sublinear string search
- Aho-Corasick (1975): Multi-pattern matching
- RE2/Rust regex: Thompson NFA + lazy DFA for guaranteed O(n) matching
