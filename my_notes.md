- [Desiderata](#org9eaeda0)
  - [Syntax](#orgcc18e17)
    - [Homoiconicity](#orgc8092cc)
    - [Significant whitespace](#org3cb651c)
    - [Groupings](#org184c4d4)
    - [Fully qualified namespaces with \`/\` seperator](#org876b0d0)
    - [EDN support](#orgfed6674)
    - [predicate functions prefer ending in \`?\`, by convention](#orge961ecd)
  - [Propagotors as first class](#org983a115)
  - [Fully qualified namespaces](#org9eea632)
  - [Strongly typed](#org87501fc)
  - [Functional-Logic-based language](#orge64b11e)
  - [Dependent Types as first class](#org5bf1633)
  - [Session Types for protocol, Linear Types for memory-guarentees](#org65800c5)
  - [Strong support for parallel processing](#org7607d7a)
  - [Pattern Matching as first class (like in Erlang or Prolog)](#org580a563)
  - [Constraint Solver Language](#org29b4ff9)
  - [Blazingly fast](#org80f1483)
  - [Excellent, human-readable, compiler errors in the likes of Rust or Gleam **VERY IMPORTANT**](#org9d9cb5b)
  - [Arbitrary precision numbers, EFFICIENTLY](#org3ec249f)
  - [Innovations on UNUM types](#org751ca0f)
  - [A "don't stop the world" garbage collector, like in Pony](#orgcb65ab5)
  - [Immutable datastructures with structural sharing, like in Clojure](#org186b00d)
- [primitives](#org8ae2372)
- [Logic Language](#org4b06efc)
  - [Runs on Propagator Infrastructure rather than typical SLD/SLG Resolution](#orgd0526f3)
  - [Logical variable names with significant modal prefixes](#org691105b)
  - [First-class anonymous relation primitive](#org422fec3)
  - [Core primitives:](#org165a1c9)
  - [Seamless integration into the functional language.](#org6f0348a)
    - [example prototype syntax](#orgd6759f4)
- [Languages that inspire us](#org4c3f111)
  - [Logic Programmming](#orgfe7b32e)
  - [Constraint Logic Programming](#orga203921)
  - [Functional Programming](#org329d27a)
  - [Scripting Languages](#org43c73c4)
  - [Formal Verification](#org1d5b66b)
  - [Sussman's Propogators](#org21c5c48)
  - [Interesting Type Systems](#org948ca11)
- [Target](#org8250de2)
  - [LLVM](#orgff6446b)
  - [Prototype in](#org0609710)
- [Personal TODOS](#org7beebca)
  - [Editor Support](#org8eb36e7)
  - [Language Features](#org3346bca)
  - [optmiizations](#org4c4336f)
  - [Array Language!](#orgd780735)
  - [todo](#orgfe29006)
  - [Namespacing](#orgd739740)
  - [Research/Implementation Guidance Documentations](#org8afeb84)
- [Bundles](#bundles)
  - [1. Composition, Not Inheritance](#orge8dbb25)
  - [2. Arbitrary Refinement](#orgc6e0c90)
  - [3. Open-World Assumption](#orgee33601)
  - [The Lattice Structure](#orge3feef6)
- [Syntax Studies](#org284eedf)
  - [Multi-arity function bodies](#orgd51be3d)
  - [IDEAs FOR PAREN GROUPINGS](#orgb3d8dd0)
  - [Mixed syntax](#org9b241b2)
  - [call site typing, "Explicit Application"](#org03e6dda)
  - [Piping](#org4d8ee5f)
  - [\`spec\`](#org18e55d8)
  - [Schema, Selection, Session](#org926fd20)
    - [schema](#org48b7dc5)
    - [selection: require, include, and provide](#org9b0f77d)
    - [session](#org0b14778)
  - [Point Free&#x2026; APL Style Trains, Trines, and Trouble????](#orgdb2a966)
  - [Free standing hash-map: The Implicit HashMap Syntax](#orgfaaeb6f)
  - [In-line let](#org94b12b8)
  - [Sigil Design](#org2872ff0)
  - [fn](#orgc823c31)
  - [HashMap](#org547a536)
    - [Map Literal uses EDN style](#org848428b)
    - [Lookup Syntax](#org90102b4)
  - [foreign imports and ffi](#orgb967c08)
  - [Partial Functions, strict arity, and the Hole-y Trinity: Curry Favor](#orge5e55b8)
    - [Use placeholders to invoke partial function](#orgc78eaa9)
  - [Type Syntax](#org3424d1a)
  - [Logical Language](#org9895f38)
    - [Keywords](#org85cce19)
    - [Logic Variable Syntax and notes](#org619ec04)
    - [Namespaces and Requires](#org8cd08a1)
    - [Clause Pipes](#org0726d54)
    - [Unification](#orge56258f)
  - [fn/rel fusion&#x2026;](#org5899a19)
  - [Unify | = | eq? 🤷‍♀️](#org96333f7)
- [Data Structures](#org7ec5027)
- [Vision, Principles,](#org536203e)
- [Considerations](#org6652123)
  - [Part 2: Persistent Data Structures](#org8101f1f)
    - [1. HAMT (Hash Array Mapped Trie)](#orga5471c3)
    - [2. Transients for Batch Updates](#org8532c4b)
    - [3. RRB-Trees for Vectors](#orgaded2a3)
    - [4. Structural Sharing + Logic Variables/](#org66d36a4)
  - [Part 3: Evaluation Strategy](#orgd5ed640)
- [Higher Rank Pi Type Syntax](#org975c3af)
  - [We have a current limitation with higher-rank Pi types that force us to use the s-expr backend language to write prologos transducers:](#org5603606)
- [pipe](#org2b990d8)


<a id="org9eaeda0"></a>

# Desiderata


<a id="orgcc18e17"></a>

## Syntax


<a id="orgc8092cc"></a>

### Homoiconicity

-   Code as Data
    -   reflectivity, inspectability, malleability
-   Simple syntax
-   Metaprogramming facility
-   Prefix-notation


<a id="org3cb651c"></a>

### Significant whitespace

-   No opening bracketing like Lisp (more like TCL)
-   New line, same level: implicit list of arguments
-   New line, deeper level: implicit tree-depth of the AST
-   Same line with \`()\` groupings: deeper tree-depth of the AST


<a id="org184c4d4"></a>

### Groupings

-   [] - Functional Core - Command Language
-   () - Logical Core - Relational Language


<a id="org876b0d0"></a>

### Fully qualified namespaces with \`/\` seperator


<a id="orgfed6674"></a>

### EDN support


<a id="orge961ecd"></a>

### predicate functions prefer ending in \`?\`, by convention

-   valid? NOT isValid


<a id="org983a115"></a>

## Propagotors as first class


<a id="org9eea632"></a>

## Fully qualified namespaces

-   disambiguate imports' names


<a id="org87501fc"></a>

## Strongly typed


<a id="orge64b11e"></a>

## Functional-Logic-based language

-   Also functional aspects
-   With procedural


<a id="org5bf1633"></a>

## Dependent Types as first class


<a id="org65800c5"></a>

## Session Types for protocol, Linear Types for memory-guarentees

-   Dependent Session types


<a id="org7607d7a"></a>

## Strong support for parallel processing

-   anything that is "embarrassingly" parallel, and that would benefit from being so without extra overhead costs, should be so automatically
-   easy to understand/use primitives for concurrent and parallel processing


<a id="org580a563"></a>

## Pattern Matching as first class (like in Erlang or Prolog)


<a id="org29b4ff9"></a>

## Constraint Solver Language


<a id="org80f1483"></a>

## Blazingly fast


<a id="org9d9cb5b"></a>

## Excellent, human-readable, compiler errors in the likes of Rust or Gleam **VERY IMPORTANT**


<a id="org3ec249f"></a>

## Arbitrary precision numbers, EFFICIENTLY

-   I don't like "wrapping" Ints, for example; I would rather throw run-time errors than silently wrapping


<a id="org751ca0f"></a>

## Innovations on UNUM types


<a id="orgcb65ab5"></a>

## A "don't stop the world" garbage collector, like in Pony


<a id="org186b00d"></a>

## Immutable datastructures with structural sharing, like in Clojure

-   Philip Bagwell's Ideal Hashmaps Research
-   ideal vector commitments


<a id="org8ae2372"></a>

# primitives

-   (:= varName [: type] expr) inline let variable binding, attached to parent scope
-   


<a id="org4b06efc"></a>

# Logic Language


<a id="orgd0526f3"></a>

## Runs on Propagator Infrastructure rather than typical SLD/SLG Resolution


<a id="org691105b"></a>

## Logical variable names with significant modal prefixes

-   ?logicVar: bimodal - designates either input or output
-   -logicVar: input - must be instantiated on use
-   +logicVar: output


<a id="org422fec3"></a>

## First-class anonymous relation primitive

\`defn\` <=> \`defr\` :: \`fn\` <=> \`rel\`


<a id="org165a1c9"></a>

## Core primitives:

-   \`clause\`
-   \`&>\` conjunctive clause piping
-   \`rel\` => relation
    -   defines an anonymous relation


<a id="org6f0348a"></a>

## Seamless integration into the functional language.

-   use \`rel\` inside \`defn\`s; use \`


<a id="orgd6759f4"></a>

### example prototype syntax

A *relation that produces proofs*, defined *locally* inside a *function*, returning *dependent types*.


<a id="org4c3f111"></a>

# Languages that inspire us


<a id="orgfe7b32e"></a>

## Logic Programmming

-   Prolog (also homoiconic)


<a id="orga203921"></a>

## Constraint Logic Programming

-   ECLiPSe


<a id="org329d27a"></a>

## Functional Programming

-   LISP
    -   Clojure
        -   "Hosted language",
            -   allows for seamless interop, especially on the JVM with Java
            -   Large reach, can reuse pre-existing libraries in ecosystem
            -   multiple hosts, JVM and javascript&#x2026; even more reach
        -   Immutable datastructures
            -   Efficient with structural sharing (like git)
            -   Safe sharing for concurrency use-cases


<a id="org43c73c4"></a>

## Scripting Languages

-   TCL


<a id="org1d5b66b"></a>

## Formal Verification

-   Maude
    -   Flexibility to define arbitrary formal languages or logics, can be powerful and flexible in proving certain


<a id="org21c5c48"></a>

## Sussman's Propogators

-   Some formalisms using lattices


<a id="org948ca11"></a>

## Interesting Type Systems

-   Pony
-   Idris
-   Rust


<a id="org8250de2"></a>

# Target


<a id="orgff6446b"></a>

## LLVM

-   Hope to be able to leverage other languages in the ecosystem, with strong ffi support to things like C, C++, Rust, and others


<a id="org0609710"></a>

## Prototype in

-   ✅ Racket 🚀

Write a clean commit message detailing what we accomplished, only output as a markdown block.


<a id="org7beebca"></a>

# Personal TODOS


<a id="org8eb36e7"></a>

## Editor Support

-   [X] load file, proper library path loading
-   [ ] tab on argument vectors, let-binding vectors, align to first var
-   [ ] rather than send last sym-expr to repl, send surfer-highlight region
-   [ ] Surfer Mode QoL
    -   [ ] timer issue 🐞
    -   [ ] forward-back tree gets occasional stuck&#x2026; just jump to next tree node if misaligned
    -   [ ] better keybindings for nav, expand/contract context
    -   [ ] send overlay region to REPL
-   [ ] Documentation
    -   [ ] Doc Completion Keep currying in the core, add arity checking in the surface language
    -   [ ] Docstrings: Store documentation strings with definitions
-   Interactivity
    -   Hole-Driven Development Features


<a id="org3346bca"></a>

## Language Features

-   [ ] Clarify \`()\` as logic clauses and Type Groupings
-   [ ] Rewrite any code to prefer A? types as Unions (A | Nil)
    -   [ ] Emit warnings/errors for unhandled Nil cases in functions
-   [X] ‼️ Better Type delimiters in WS mode
    -   Any complex grouped types, Function, Pi, Sigma use \`()\`
        -   [X] 👩‍🔬🦆 Syntax Workshop!
            -   We repurpose \`<&#x2026;>\` to unify Pi and Sigma dependent types
-   [ ] ‼️🦆 Workshop Session Syntax
    -   [ ] Syntax Notes
-   [ ] ~~Anonymous Relation \`?()\`&#x2026; but also \`rel\`~~ DEFER
    
    | Command Language | Relational Languages |              |
    | []  OR  "bare"   | ()                   |              |
    | defn             | defr                 |              |
    | fn               | rel                  |              |
    | #[]              | ?()                  | ;; more ⚙️🔧🧠 |
    
    -   [ ] Syntax Notes
-   [X] ~~Deprecate \`<>\` (but keep, for now)~~
    -   [X] Repurpose \`<>\` For Pi and Sigma Types
-   [X] Multi-arity defn: Case-split syntax with multiple arities (original feature request)
-   [X] Partial function application with wildcards
-   [ ] 📝 variable argument support \`&#x2026;name\` syntax?
-   [ ] List head tail syntax '[x1 x2 \_ | xs]
-   [X] Migrate Groupings syntax from \`()\` to \`[]\`
-   [X] define sigil syntax for common data structures (see Syntax Studies below)
-   [X] Prologos \`defmacro\`
    -   test (see re: homoiconicity concerns)
-   [X] Unit Type
    -   Unit is vacuously true ≅ Nil
-   [X] Nil Type? (equivalent semantically to Unit.. redundant? or good meaning?)
    -   [X] verify
-   [X] Union Type
-   [X] Nullable Type? -> Union Type of [A | Nil]
-   [X] Memoization Infra
-   [-] Polymorphic Dispatch 🦆
    -   [X] \`trait\` and \`impl\`
    -   [ ] ??? check back on notes for further design patterns
-   With Map key access, what does it mean for a collection to be an operator in the first position?
    -   m.key
    -   also with Vec[indx] syntax?
-   [ ] [BUNDLES!!!](#bundles)

-   [X] Return types arity style \`A B C -> D\` **NOT** curry style: \`A -> B -> C -> D\`
-   [X] \`defn\` default public \`defn-\` default private &#x2013; deprecate \`provide\`
-   [X] \`require\` QoL - \`:as\`
-   [X] \`let\` block vs in-line \`let\`s
    -   We support both&#x2026; sibling in-line lets share same local scope
    -   Design research/🦆
-   [ ] Map with key access syntax
    -   Make Example in Syntax Lab
    -   Implicit Map syntax
-   [X] foreign/ffi syntax
-   Metadata with ^{&#x2026;} ???
-   [X] ensure foreign symbols import cleanly
    -   [X] add :as foreign symbol aliasing
    -   [X] add WS support for foreign symbol imports
    -   [X] foreign symbols use \`/\` as distinct from prologos \`::\`
-   add a javascript foreign import
    -   spin up a v8 vm when there's a js import/block, run against that as sibling runtime


<a id="org4c4336f"></a>

## optmiizations

-   [ ] loop fusion with |> >>
    -   [ ] fusion only on pipe with reduce termination, needs further optimization
-   [ ] Type inference audit
    -   we know there's places for improvement


<a id="orgd780735"></a>

## Array Language!

-   <f g h> Point Free combinators, Combinator Logic
    -   Intended to work over collections&#x2013;arrays, in particular


<a id="orgfe29006"></a>

## todo

-   [ ] Higher-rank polymorphism syntax in def/defn

```prologos
;;    Higher-rank polymorphism works with `(def ... : [type] body)`. The key insight: **`spec`/`defn` cannot handle higher-rank types** (Pi as parameter), but **`(def name : [type] body)` can be freely mixed into WS files**. And the transducer functions need higher-rank types for the `xf` parameter.

;;  Now I understand the constraints. For the transducer rewrite:
;;  - Functions with simple types (like `list-conj`) → use `spec`/`defn` (pure WS)
;;  - Functions with higher-rank polymorphic params (like `transduce`, `xf-compose`) → must use `(def ... : ...)` with sexp bodies
;;  - For the `(def ...)` forms, the TYPE annotation should use `[...]` bracket syntax, and the body uses sexp with uncurried arguments where possible

  (def map-xf : [Pi [A :0 <Type>] [Pi [B :0 <Type>]
                  [-> [-> A B]
                    [Pi [R :0 <Type>] [-> [-> R [-> B R]] [-> R [-> A R]]]]]]]
    (fn (A :0 (Type 0)) (fn (B :0 (Type 0)) (fn (f : (-> A B))
      (fn (R :0 (Type 0)) (fn (rf : (-> R (-> B R))) (fn (acc : R) (fn (x : A)
        (rf acc (f x))))))))))


```


<a id="orgd739740"></a>

## Namespacing

-   [X] auto provide \`defn\`s
    -   [X] create private defn- and co.
    -   [X] remove/deprecate \`provide\`
-   [X] Ensure namespace aliasing with \`:as\`
-   [X] change namespace delimiter from \`/\` to \`::\`
-   [ ] determine what core libraries get loaded in automatically can be called in by their fully-qualified names without require


<a id="org8afeb84"></a>

## Research/Implementation Guidance Documentations

-   [ ] Updated Deep Propagator Implementation Guide?
    -   Update with choice-point designs
    -   What are the core
-   [ ] WAM-light? SLD/SLG fallbacks
    -   What's the MVP for Unification, at least? (Our type inference already has this&#x2026; can we re-purpose the same tooling?)
-   [ ] Dependent Type Interactive Design: Agda/Idris: Implementation Guide
-   [ ] Develop Spec Language as core to Dependent Type Interactive Dev
    -   Lessons from Clojure | Idris | Agda
    -   Property Based test (comprehensive research across language ecosystem)
        -   properl - Erlang
        -   Lean, Coq, Maude&#x2026; Formal methods as a grounding into sound inference
    -   Automated fuzzing/generative testing at a push of button
    -   [ ] Derive Properties (see notes&#x2026; fill in more here)
-   [ ] Best in Modern Tooling Support
    -   Package manager
    -   build tools
    -   test framework
-   [ ] Modal Logic | LTL Applications&#x2026; How does our type system do at expressing, constructing Modal Logic Modelling!!!!
-   Point Free, Combinators, Combinator Logic, and the History and Frontiers of Array Programming!!


<a id="bundles"></a>

# Bundles

```prologos
bundle CompoundTypeConstraint := (Eq Ord MyOtherTrait)

;; ========================================
;; We have:
;; ========================================

trait Eq (A : Type)
  (==) : A -> A -> Bool

trait Ord (A : Type)
  compare : A -> A -> Ordering

;; Independent predicates, combined as needed

;; If a function needs both:
defn foo [x : A] where (Eq A, Ord A)
  ...

;; Or use a bundle:
bundle Comparable (A) = (Eq A, Ord A)

defn foo [x : A] where (Comparable A)
  ...

```

Supertraits and trait inheritance is inherently IMPLICATION bundles are Conjunctive constraints, scaling Type refinement like prolog conjunctive clauses, One bundle can be used as a sub-constraint in another. COMPOSES!!

```quote
| Aspect              | Traditional (Supertraits) | Prologos (Bundles)    |
|---------------------+---------------------------+-----------------------|
| Structure           | Tree (hierarchy)          | Set (flat)            |
| Combination         | Inheritance (→)           | Conjunction (∧)       |
| Flexibility         | Rigid paths               | Any combination       |
| Adding constraints  | Modify hierarchy          | Define new bundle     |
| Prolog mapping      | Implication (unnatural)   | Conjunction (natural) |
| Lattice structure   | Partial order             | Join-semilattice      |
| Propagator friendly | Awkward                   | Natural               |
```

-   What Makes Bundles Different


<a id="orge8dbb25"></a>

## 1. Composition, Not Inheritance

```prologos
;; ========================================
;; Supertraits (inheritance): Implication
;; ========================================

trait Ord : Eq          ;; Ord → Eq
trait Hash : Eq         ;; Hash → Eq
trait Num : Add, Mul    ;; Num → Add ∧ Mul

;; Problem: rigid hierarchy
;; Num MUST include Add and Mul
;; Can't have Num without them

;; ========================================
;; Bundles (composition): Conjunction
;; ========================================

bundle Numeric = (Add, Mul, Neg, Eq)
bundle Comparable = (Eq, Ord)
bundle Hashable = (Eq, Hash)

;; Flexible: Define new bundles freely
bundle MySpecial = (Add, Hash, Seqable)

;; No hierarchy, just sets of requirements
```


<a id="orgc6e0c90"></a>

## 2. Arbitrary Refinement

```prologos
;; Start broad
bundle Basic = (Eq)

;; Refine progressively
bundle Ordered = (Basic, Ord)          ;; = (Eq, Ord)
bundle Complete = (Ordered, Hash)       ;; = (Eq, Ord, Hash)
bundle Full = (Complete, Show, Parse)   ;; = (Eq, Ord, Hash, Show, Parse)

;; Or lateral combinations
bundle PrintableOrdered = (Ord, Show)
bundle SerializableHashable = (Hash, Serialize)

;; Any combination you need!
```


<a id="orgee33601"></a>

## 3. Open-World Assumption

```prologos
;; New traits can be added later
trait MyNewTrait

;; New bundles can combine old and new
bundle Enhanced = (Eq, Ord, MyNewTrait)

;; No need to modify existing traits
;; No reopening of trait hierarchies
;; Just define new bundles as needed
```

&#x2014;


<a id="orge3feef6"></a>

## The Lattice Structure

Bundles form a *lattice* under subset ordering:

```
                     ┌─────────────────────────┐
                     │ (Eq, Ord, Hash, Show)   │  ← most refined
                     └───────────┬─────────────┘
                                 │
           ┌─────────────────────┼─────────────────────┐
           ▼                     ▼                     ▼
   ┌───────────────┐    ┌───────────────┐    ┌───────────────┐
   │ (Eq, Ord, Hash)│   │ (Eq, Ord, Show)│   │(Eq, Hash, Show)│
   └───────┬───────┘    └───────┬───────┘    └───────┬───────┘
           │                    │                    │
     ┌─────┴─────┐        ┌─────┴─────┐        ┌─────┴─────┐
     ▼           ▼        ▼           ▼        ▼           ▼
┌─────────┐ ┌─────────┐ ┌─────────┐ ...
│ (Eq,Ord)│ │(Eq,Hash)│ │(Eq,Show)│
└────┬────┘ └────┬────┘ └────┬────┘
     │           │           │
     └───────────┼───────────┘
                 ▼
            ┌─────────┐
            │  (Eq)   │  ← least refined
            └─────────┘
```

This is a *join-semilattice*:

-   Meet (∧) = union of constraints = more refined
-   Join (∨) = intersection of constraints = less refined

Let's stage all relevant changes; then write a clean commit message output as a markdown block. ONLY STAGE, DO NOT COMMIT.


<a id="org284eedf"></a>

# Syntax Studies


<a id="orgd51be3d"></a>

## Multi-arity function bodies

```prologos
;; Multi-arity syntax design
;; Option 1: groupings with `()`
defn clamp
  "clamp `low` `high` returns a function that clamps `x` to [`low`, `high`]"
  ([low : Nat, high : Nat] : Nat -> Nat
    fn [x] max low (min x high))

  ([x : Nat, low : Nat, high : Nat] : Nat
    max low (min x high))

;; Option 2: Case-Style
defn clamp
  "Clamp a value to a range"
  | [low : Nat, high : Nat] : Nat -> Nat
      fn [x] (max low (min x high))

  | [x : Nat, low : Nat, high : Nat] -> Nat
      max low (min x high)
```


<a id="orgb3d8dd0"></a>

## IDEAs FOR PAREN GROUPINGS

```prologos

;; if we move from `()` -> `[]` groupings for AST-nesting
;; perhaps we could set aside `()` to offer a mixed fix arithmetic sub-language???
;; NOPE!

[(x : A) -> B]
<(x : A) -> B>

[(x : A) * B]
<(x : A) * B>


```

Next we want to consider design and implementation for Phace 2c: Seq Fusion / Transducer. We are seeking to ensure that anytime the compiler sees our pipe syntax \`|>\` that it automatically does a "loop fusion" or transducer over the entire structure.

We have two specific syntax operators that we would like to introduce in this work \`|>\` and \`>>\`

The \`>>\` or transducer-pipe operator takes a list of forms that each return a point-free transducer

```prologos
def xf
  >> map inc
     filter even?
     map [* _ _]    ;; same argument goes in hole


```


<a id="org9b241b2"></a>

## Mixed syntax

```prologos
spec find-path Graph Node Node -> Maybe [List Node]
defn find-path [graph, start, end]
  ;; Define a local relation
  let reachable := (rel [?from ?to ?path]
    &> (= ?from ?to)
       (= ?path '[?to | nil])
    &> (edge ?from ?mid)
       (reachable ?mid ?to ?rest)
       (= ?path '[?from | ?rest])

  ;; Use relation in functional context
  match (solve [reachable start end ?p])
    | [some path] -> [just path]
    | none        -> nothing

```


<a id="org03e6dda"></a>

## call site typing, "Explicit Application"

-   When Might You Want Explicit Type Arguments?

Sometimes inference fails or you want to be explicit:

```prologos
;; Or at call site (if we support it)
let xs = nil @Nat  ;; "nil at type Nat"
```


<a id="org4d8ee5f"></a>

## Piping

```prologos

|>    `pipe-as`
|>.   `pipe-first`
|>..  `pipe-last`

>>  Transducer

```


<a id="org18e55d8"></a>

## \`spec\`

```prologos
spec add Nat Nat -> Nat
defn add [x y]
    + x y


defn clamp
  "Clamp a value to a range"
  | [low : Nat, high : Nat] : Nat -> Nat
      fn [x] (max low (min x high))

  | [x : Nat, low : Nat, high : Nat] -> Nat
      max low (min x high)
;; ---

spec clamp
  "Clamp a value to a range"
  | Nat Nat -> [Nat -> Nat]
  | Nat Nat Nat -> Nat

defn clamp
  | [low high] [fn [x] (max low (min x high))]
  | [max low [min x high]]

;; full potential example
;; This starts to feel like Clojure's =spec= system—contracts, generative testing, documentation all in one.
spec add
  "Add two natural numbers."
  Nat Nat -> Nat
  :examples
    [add 1 2] => 3
    [add 0 n] => n
  :properties
    [add x y] = [add y x]   ;; commutativity

```


<a id="org926fd20"></a>

## Schema, Selection, Session


<a id="org48b7dc5"></a>

### schema


<a id="org9b0f77d"></a>

### selection: require, include, and provide


<a id="org0b14778"></a>

### session


<a id="orgdb2a966"></a>

## Point Free&#x2026; APL Style Trains, Trines, and Trouble????

```prologos

spec compose [B -> C] [A -> B] -> [A -> C]
defn compose [f g]
  f [g _]

```


<a id="orgfaaeb6f"></a>

## Free standing hash-map: The Implicit HashMap Syntax

-   Keys on same level implicit Hashmap
-   

```prologos

spec add
  "Add two natural numbers."
  Nat Nat -> Nat
  :examples
    [add 1 2] => 3
    [add 0 n] => n
  :properties
    [add x y] = [add y x]   ;; commutativity

```


<a id="org94b12b8"></a>

## In-line let

-   \`:=\` vs \`let\`

```prologos

:=  foo 42
let foo 42


let x : Nat 42     ;; 1?
let x : Nat = 42   ;; 2?
let x : Nat := 42  ;; 3?

;; should the `:=` or `=` be optional?



;; 1. Paren Groupings? `()`
let answer <Nat> (mult 21 2)  ;; 1?  var <Type> expr
let answer : Nat (mult 21 2)  ;; 2?  var : Type expr
let answer::Nat  (mult 21 2)  ;; 3?  var::Type  expr

;; 2. Square brackets groupings? `[]`
let answer <Nat> [mult 21 2]  ;; 1?   var <Type> expr
let answer : Nat [mult 21 2]  ;; 2?   var : Type expr
let answer::Nat  [mult 21 2]  ;; 3?   var::Type expr




let xs [: Vec 5 Nat]  [1 2 3 4 5]

let xs : Vec 5 Nat := [1 2 3 4 5]
let ys : List Nat  := #[3 4 5]
let xs : List Nat  := #[1 2 | ys]
let xs : Seq A := #'[...]  ;; VERY LOW CONFIDENCE ON THIS SYNTAX
let xs : Set A := #{...}   ;; EDN-style sets
let xs : HMapType := {:k v, ...}  ;; EDN-style maps


let [xs [: List Nat] #[10 20]
     ys [: List Nat] #[3 4 5]
     zs #[xs | ys]]

let [xs (: List Nat) #[10 20]
     ys (: List Nat) #[3 4 5]
     zs #[xs | ys]]


 map [add 2 _] xs
 map [clamp _ 50 100] xs

 map (add 2 _) xs
 map (clamp _ 50 100) xs


```


<a id="org2872ff0"></a>

## Sigil Design

```quote
| Collection        | Sigil    | Mnemonic              | Example          |
|-------------------+----------+-----------------------+------------------|
| Grouping          |  `[...]`  | "Expression"         | =[add 1 2]=      |
| Persistent Vec    | `@[...]` | "At" = indexed access | =@[1 2 3]=       |
| Linked List       | `'[...]` | "Quote" = literal     | ='[1 2 3]=       |
| Lazy Seq          | `~[...]` | "Tilde" = lazy/wave   | =~[1 2 3]=       |
| Set               | `#{...}` | EDN-style             | =#{1 2 3}=       |
| Map               |  `{...}` | EDN-style            | ={:a 1 :b 2}=     |
| Tuple (if needed) | =(...)=  | Traditional           | =(1, "a", true)= |
```


<a id="orgc823c31"></a>

## fn

```prologos

fn [x] add 2 x

```


<a id="org547a536"></a>

## HashMap


<a id="org848428b"></a>

### Map Literal uses EDN style

```prologos
{:name "Alice" :age 42}
```


<a id="org90102b4"></a>

### Lookup Syntax


<a id="orgb967c08"></a>

## foreign imports and ffi


<a id="orge5e55b8"></a>

## Partial Functions, strict arity, and the Hole-y Trinity: Curry Favor


<a id="orgc78eaa9"></a>

### Use placeholders to invoke partial function

```prologos
defn clamp
  "Clamp value to range"
  | [low : Nat, high : Nat] : Nat -> Nat
      fn x (max low (min high x))
  | [low : Nat, high : Nat, x : Nat] : Nat
      max low (min high x)

;; Now both work:
clamp 0 100          ;; 2-arity, returns function
clamp 0 100 50       ;; 3-arity, returns value

;; And placeholder works too:
map (clamp 0 100 _) xs   ;; explicit partial of 3-arity
map (clamp 0 100) xs     ;; using 2-arity overload (cleaner!)

```


<a id="org3424d1a"></a>

## Type Syntax

-   <Type>
-   var : Type
-   var::Type


<a id="org9895f38"></a>

## Logical Language


<a id="org85cce19"></a>

### Keywords

```prologos
rel  | relation
defr | defrel
clause
&>
=   ;; unify
.>

```


<a id="org619ec04"></a>

### Logic Variable Syntax and notes

| General Modality | ?var        | Input OR Output |
| Input   Modality | var OR -var | Input only      |
| Output  Modality | ?+var       | Output          |

```prologos



```

-   \*What is a good convention for naming \`defr\` forms? (Like predicate functions in Clojure, by convention, end in \`?\`)
    -   We don't want to enforce the naming, but encourage community


<a id="org8cd08a1"></a>

### Namespaces and Requires

-   \`require\` should take a list of require forms and allow for local aliasing with \`alias/def-name\` syntax

Example:

```prologos

require [prologos.data.nat  :as nat  :refer [add mult pow zero?]]
        [prologos.data.bool :as bool :refer [not and or]]
        [prologos.data.list :as list :refer [List nil cons map filter reduce]]

defn double-all [xs : List Nat] : List Nat
  map (nat/double _) xs

```


<a id="org0726d54"></a>

### Clause Pipes

1.  \`&>\`

    ```prologos
    
    ```


<a id="orge56258f"></a>

### Unification

```prologos
~
<=>
=   ;; semantically overloaded... but greater primacy to Logical Language Aspect ***


;; `:=` to functional binding
;; `==` to equality test

```


<a id="org5899a19"></a>

## fn/rel fusion&#x2026;


<a id="org96333f7"></a>

## Unify | = | eq? 🤷‍♀️

-   Should we keep Prolog's use of \`=\` for unification
    -   ~~use \`unify\` keyword?~~
    -   We're going with the classic \`=\` is unify! 🎉


<a id="org7ec5027"></a>

# Data Structures

-   Relaxed Radix Balanced Trees (RRB-trees) compared with HAMT-vectors?


<a id="org536203e"></a>

# Vision, Principles,

-   Interactive Development
    -   The programmer is in constant conversation with the runtime tooling, code, evaluation
    -   Hole-driven Development with Dependent Types
        -   Derive structure, case splits, etc.
        -   Editor Assisted Coding
    -   In-line evaluation
    -   Keep locked in to context (no switching cost between code and run/eval)
    -   Frictionless Developer Tooling Integration
-   Tooling
    -   Data Viewer
    -   Build Tooling
    -   Testing Infrastructure
    -   Package Manager
-   Homoiconicity: Code is Data
    -   What you you see is what you get, your code is your data
        -   easy macro rewriting and expanding/inspectability of data and runtime
    -   Uniform Syntax


<a id="org6652123"></a>

# Considerations


<a id="org8101f1f"></a>

## Part 2: Persistent Data Structures


<a id="orga5471c3"></a>

### 1. HAMT (Hash Array Mapped Trie)

```
;; Key insight: 32-bit hash → 6 levels max (32^6 > 1 billion)
;; Each node: up to 32 children
;; Structural sharing: updates copy only path from root to changed leaf

       [root]
      /      \
   [node]   [node]
   /    \
[leaf] [leaf]  <-- update here copies 3 nodes, shares rest
```


<a id="org8532c4b"></a>

### 2. Transients for Batch Updates

```prologos
;; Problem: building a map one item at a time = O(n log n)
;; Solution: transient (mutable) version for batch ops

defn build-map [pairs : List (Pair K V)] : Map K V
  persistent!
    (reduce pairs (transient empty-map)
      (fn acc (k, v) -> assoc! acc k v))
```

*3. RRB-Trees for Vectors*

If you want efficient `concat`, `slice`, `insert-at`, consider RRB-trees (Relaxed Radix Balanced) instead of plain tries.

```prologos
;; Standard vector trie: O(n) concat
;; RRB-tree: O(log n) concat, slice, insert
```


<a id="orgaded2a3"></a>

### 3. RRB-Trees for Vectors

If you want efficient `concat`, `slice`, `insert-at`, consider RRB-trees (Relaxed Radix Balanced) instead of plain tries.

```prologos
;; Standard vector trie: O(n) concat
;; RRB-tree: O(log n) concat, slice, insert
```


<a id="org66d36a4"></a>

### 4. Structural Sharing + Logic Variables/

This is unique to Prologos:

```prologos
;; Logic variables in persistent structures
:= m (map-of "a" ?x "b" ?y)

;; Unification might bind ?x
(unify ?x 42)

;; What happens to m?
;; Option A: m is unchanged (logic vars are immutable references)
;; Option B: m "sees" the binding (requires indirection)
```

You need to decide how logic variables interact with persistent structures.


<a id="orgd5ed640"></a>

## Part 3: Evaluation Strategy

*Key Question: Strict or Lazy by Default?*

| Strategy                 | Pros                            | Cons                         |
|------------------------ |------------------------------- |---------------------------- |
| Strict (Clojure, ML)     | Predictable, debuggable         | Can't do infinite structures |
| Lazy (Haskell)           | Infinite structures, modularity | Space leaks, hard to reason  |
| Lazy Seqs Only (Clojure) | Best of both                    | Two mental models            |

-   Recommendation for Prologos

```prologos
;; Strict by default (like Clojure)
;; Explicit laziness via Seq and delay/force

defn eager-map {A B} [f : A -> B, xs : List A] : List B
  match xs
    | nil       -> nil
    | cons x xs -> cons (f x) (eager-map f xs)

defn lazy-map {A B} [f : A -> B, xs : Seq A] : Seq B
  match xs
    | empty    -> empty
    | cell x xs -> cell (f x) (delay (lazy-map f (force xs)))
```


<a id="org975c3af"></a>

# Higher Rank Pi Type Syntax


<a id="org5603606"></a>

## We have a current limitation with higher-rank Pi types that force us to use the s-expr backend language to write prologos transducers:

```prologos
(def xf-compose : [Pi [A :0 <Type>] [Pi [B :0 <Type>] [Pi [C :0 <Type>]
                  [-> [Pi [S :0 <Type>] [-> [-> S [-> B S]] [-> S [-> A S]]]]
                    [-> [Pi [S :0 <Type>] [-> [-> S [-> C S]] [-> S [-> B S]]]]
                      [Pi [S :0 <Type>] [-> [-> S [-> C S]] [-> S [-> A S]]]]]]]]]
(fn (A :0 (Type 0)) (fn (B :0 (Type 0)) (fn (C :0 (Type 0))
  (fn (xf1 : (Pi (S :0 (Type 0)) (-> (-> S (-> B S)) (-> S (-> A S)))))
    (fn (xf2 : (Pi (S :0 (Type 0)) (-> (-> S (-> C S)) (-> S (-> B S)))))
      (fn (R :0 (Type 0)) (fn (rf : (-> R (-> C R)))
        (xf1 R (xf2 R rf))))))))))

```

With a proposal of adding implicit binders and <..> Pi in parameter position denoting a higher-rank polymorphic parameter, the rewrite would look something like:

```prologos
  spec xf-compose {A B C : Type}
                <(S :0 Type) -> [S -> B -> S] -> S -> A -> S>
                <(S :0 Type) -> [S -> C -> S] -> S -> B -> S>
                -> <(S :0 Type) -> [S -> C -> S] -> S -> A -> S>
defn xf-compose [xf1 xf2]
  fn [R :0 <Type>] [rf]
    xf1 R [xf2 R rf]
```

The problem is, that I still cannot conceive of being able to write this. It feels clunky and unintuitive. Can we explore possible syntax design that would feel approachable to users yet able to express the requirements of higher rank pi types?

-   Higher-Rank Types: Making Them Approachable

This is a fundamental challenge. Let me explore the design space.

&#x2014;

-   The Core Problem

Higher-rank types require *nested quantification*:

```
;; Rank-1 (simple)
∀A. A → A                       ;; "for all A, A to A"

;; Rank-2 (higher)
(∀S. (S → B → S) → S → A → S)   ;; quantifier INSIDE argument
;; "a function that works for ANY S you give it"

;; This is what transducers need!
;; The reducer type (S → B → S) is polymorphic in S
;; The transducer doesn't know what S is
```

&#x2014;

-   Why It Feels Clunky

```prologos
;; Current: explicit Pi everywhere
<(S :0 Type) -> [S -> B -> S] -> S -> A -> S>

;; Problems:
;; 1. S appears 4 times (noisy)
;; 2. :0 annotation (erased) adds visual weight
;; 3. The "shape" of a transducer is obscured
;; 4. Users must understand universal quantification
```

&#x2014;

-   Exploration: Multiple Syntax Approaches

&#x2014;

-   Approach A: Type Aliases Hide the Complexity

```prologos
;; ========================================
;; Define the transducer type once
;; ========================================

type Reducer S A = S -> A -> S
type Transducer A B = forall S. Reducer S B -> Reducer S A

;; Now xf-compose is readable:
spec xf-compose {A B C : Type}
  Transducer A B -> Transducer B C -> Transducer A C

defn xf-compose [xf1 xf2]
  fn {S} [rf]
    xf1 (xf2 rf)
```

| Pros                     | Cons                           |
|------------------------ |------------------------------ |
| ✅ Very clean at use site | ⚠️ Must define type aliases     |
| ✅ Domain concepts named | ⚠️ Hides the polymorphism       |
| ✅ Approachable to users | ⚠️ Need `forall` in type alias  |

&#x2014;

-   Approach B: Infer Higher-Rank from Usage

```prologos
;; ========================================
;; Let compiler infer the polymorphism
;; ========================================

spec xf-compose {A B C}
  (Reducer _ B -> Reducer _ A) ->   ;; _ means "polymorphic here"
  (Reducer _ C -> Reducer _ B) ->
  (Reducer _ C -> Reducer _ A)

defn xf-compose [xf1 xf2]
  fn [rf]
    xf1 (xf2 rf)

;; Compiler sees _ in same position across arrows
;; Infers: this must be universally quantified
```

| Pros                      | Cons                            |
|------------------------- |------------------------------- |
| ✅ Minimal syntax         | ⚠️ Inference may be undecidable  |
| ✅ Familiar \_ placeholder | ⚠️ Magic / implicit              |
| ✅ Focus on structure     | ⚠️ Error messages harder         |

&#x2014;

-   Approach C: Explicit `forall` Keyword (Haskell-Style)

```prologos
;; ========================================
;; Use forall keyword inline
;; ========================================

spec xf-compose {A B C}
  (forall S. [S -> B -> S] -> [S -> A -> S]) ->
  (forall S. [S -> C -> S] -> [S -> B -> S]) ->
  (forall S. [S -> C -> S] -> [S -> A -> S])

defn xf-compose [xf1 xf2]
  fn {S} [rf]
    xf1 {S} (xf2 {S} rf)
```

| Pros                        | Cons                     |
|--------------------------- |------------------------ |
| ✅ Explicit, clear          | ⚠️ Verbose                |
| ✅ Familiar to Haskell users | ⚠️ "forall" is scary      |
| ✅ Standard in literature   | ⚠️ S repeated many times  |

&#x2014;

-   Approach D: `poly` Blocks for Scoped Quantification

```prologos
;; ========================================
;; poly introduces a scoped type variable
;; ========================================

spec xf-compose {A B C}
  poly S. ([S B -> S] -> [S A -> S]) ->
  poly S. ([S C -> S] -> [S B -> S]) ->
  poly S. ([S C -> S] -> [S A -> S])

;; Or even shorter with convention:
;; poly always quantifies over immediately following type var

spec xf-compose {A B C}
  poly [S B -> S] -> [S A -> S] ->   ;; S is bound in this arg
  poly [S C -> S] -> [S B -> S] ->   ;; fresh S bound here
  poly [S C -> S] -> [S A -> S]      ;; fresh S bound here
```

| Pros                     | Cons             |
|------------------------ |---------------- |
| ✅ Scoped, clear binding | ⚠️ New keyword    |
| ✅ Less scary than forall | ⚠️ Still verbose  |

&#x2014;

-   Approach E: Arrow Annotations

```prologos
;; ========================================
;; Annotate the arrow with polymorphism
;; ========================================

spec xf-compose {A B C}
  ([S B -> S] ->{S} [S A -> S]) ->    ;; ->{S} means "polymorphic in S"
  ([S C -> S] ->{S} [S B -> S]) ->
  ([S C -> S] ->{S} [S A -> S])

;; Or prefix:
spec xf-compose {A B C}
  {S}([S B -> S] -> [S A -> S]) ->    ;; {S} scopes over this arg
  {S}([S C -> S] -> [S B -> S]) ->
  {S}([S C -> S] -> [S A -> S])
```

| Pros                      | Cons                     |
|------------------------- |------------------------ |
| ✅ Compact                | ⚠️ New annotation syntax  |
| ✅ Quantifier near binding | ⚠️ May be cryptic         |

&#x2014;

-   Approach F: Pattern-Based / Relational View

Since you think in Prolog terms:

```prologos
;; ========================================
;; Think of type as a relation/predicate
;; ========================================

;; "xf-compose takes two transducers and returns a transducer"
;; Transducer is a SHAPE, not a specific type

spec xf-compose {A B C}
  Xf A B -> Xf B C -> Xf A C

;; Xf A B is a "type pattern" that expands to:
;; "something that, for any S, transforms (S B -> S) to (S A -> S)"

;; Define the pattern:
pattern Xf A B = forall S. [S -> B -> S] -> [S -> A -> S]
```

| Pros                          | Cons                         |
|----------------------------- |---------------------------- |
| ✅ Pattern = reusable shape   | ⚠️ New construct              |
| ✅ Matches Prolog intuition   | ⚠️ Pattern vs type confusion  |
| ✅ Extremely clean at use site |                              |

&#x2014;

-   Approach G: Implicit Rank via Trait/Protocol

```prologos
;; ========================================
;; Transducer as a trait, not a type
;; ========================================

trait Transducer (X : Type -> Type -> Type)
  transform : forall S. [S -> B -> S] -> [S -> A -> S]

;; Now functions just use the trait:
spec xf-compose {A B C}
  {X : Transducer A B} -> {Y : Transducer B C} -> Transducer A C

;; The higher-rank is hidden inside the trait definition
;; Users never see forall at the function level
```

| Pros               | Cons                   |
|------------------ |---------------------- |
| ✅ Hides complexity | ⚠️ Trait overhead       |
| ✅ Familiar pattern | ⚠️ Indirection          |
| ✅ Extensible      | ⚠️ May be too abstract  |

&#x2014;

-   My Recommendation: Approach A + F (Aliases + Patterns)

```prologos
;; ========================================
;; Step 1: Define the vocabulary
;; ========================================

;; Reducer: takes state and value, returns new state
type Reducer S A = S -> A -> S

;; Transducer: transforms reducers (polymorphic in state)
type Xf A B = forall S. Reducer S B -> Reducer S A

;; ========================================
;; Step 2: Use clean signatures
;; ========================================

spec xf-compose {A B C}
  Xf A B -> Xf B C -> Xf A C

spec map-xf {A B}
  (A -> B) -> Xf A B

spec filter-xf {A}
  (A -> Bool) -> Xf A A

spec take-xf {A}
  Nat -> Xf A A

;; ========================================
;; Step 3: Implementation uses {S} for type app
;; ========================================

defn xf-compose [xf1 xf2]
  fn {S} [rf : Reducer S C] : Reducer S A
    xf1 {S} (xf2 {S} rf)

;; Or let inference handle it:
defn xf-compose [xf1 xf2]
  fn [rf]
    xf1 (xf2 rf)

;; ========================================
;; Step 4: Users just use combinators
;; ========================================

def my-xf = >> (map-xf inc) (filter-xf even?) (take-xf 10)

;; They never see forall!
```

&#x2014;

-   The Key Insight

```
USERS should see:          LIBRARY AUTHORS see:

Xf A B                     forall S. Reducer S B -> Reducer S A
Reducer S A                S -> A -> S
map-xf : (A -> B) -> Xf A B    (the full type)

Domain vocabulary          Type-theoretic machinery
```

The `forall` exists, but it's *hidden inside type aliases*.

&#x2014;

-   Surface Syntax Summary

```prologos
;; ========================================
;; Type alias with forall
;; ========================================

type Xf A B = forall S. [S -> B -> S] -> [S -> A -> S]

;; ========================================
;; forall keyword when needed
;; ========================================

type Lens S A = forall F. Functor F => (A -> F A) -> S -> F S

;; ========================================
;; Implicit type application
;; ========================================

;; When calling a forall-quantified function:
xf1 rf          ;; compiler infers S from rf's type

;; Explicit when needed:
xf1 {Int} rf    ;; apply Int for S

;; ========================================
;; In spec, forall at argument position
;; ========================================

;; If you MUST write it inline:
spec foo (forall S. [S -> A -> S]) -> Result

;; Or with alias:
spec foo (Reducer _ A) -> Result   ;; _ = universally quantified
```

&#x2014;

-   Error Message Consideration

```prologos
;; When user makes a mistake:

let bad = xf1 rf1 rf2

;; Error message should use vocabulary:

;; BAD:
"Expected: forall S. (S -> B -> S) -> (S -> A -> S)
 Got: (Int -> B -> Int)"

;; GOOD:
"Expected: Xf A B (a transducer from A to B)
 Got: a concrete reducer for Int

 A transducer must work for ANY state type S,
 but you provided a reducer that only works for Int.

 Hint: did you mean to wrap this in a transducer?
       map-xf f  instead of  (fn [rf] ...)"
```

&#x2014;

-   Final Syntax Proposal

```prologos
;; ========================================
;; Defining higher-rank types (library author)
;; ========================================

;; Use 'type' with 'forall'
type Reducer S A = S -> A -> S
type Xf A B = forall S. Reducer S B -> Reducer S A

;; Or inline in spec
spec weird-fn
  (forall S. S -> S) -> Int   ;; function that works on any S

;; ========================================
;; Using higher-rank types (regular user)
;; ========================================

;; Just use the aliases
spec my-transform
  Xf String Int -> Xf Int Bool -> Xf String Bool

;; Implementation: compiler infers type applications
defn my-transform [xf1 xf2]
  fn [rf] [xf1 [xf2 rf]]

;; ========================================
;; Explicit type application when needed
;; ========================================

;; {Type} syntax for explicit application
defn explicit-example [xf]
  xf {Int} int-reducer    ;; apply Xf at S = Int

;; ========================================
;; Anonymous forall with _
;; ========================================

;; If you want quick inline:
spec quick
  (forall _. [_ -> A -> _] -> [_ -> B -> _]) -> C

;; _ is anonymous, equivalent to fresh variable
```

&#x2014;

-   Does This Feel More Approachable?

The strategy:

1.  *Name the concepts* with type aliases
2.  *Hide the forall* inside those aliases
3.  *Users work with domain vocabulary* (Xf, Reducer)
4.  *Library authors use forall* when defining aliases
5.  *Explicit {S}* only when compiler can't infer


<a id="org2b990d8"></a>

# pipe

I'm confused at how \`|>\` and \`>>\` are being used in piping.prologos.

They should be **prefix** notation. We are aiming to be a homoiconic language with prefix notation, for consistent syntax, macro definition, and code-as-data introspectability.

Both of these operators should take a list of expressions

Our piping implementation is fundamentally flawed in an important way, breaking a core invariant.

In our memory file, let us emphasis a core invariant of Prologos:

-   Prologos is a homoiconic language, supporting code-as-data
    -   Simple, uniform syntax with prefix notation
    -   Macros work on post-parse level (where whitespaces are resolved) to enable clear and predictable ASTs
    -   macros as first-class metaprogramming
        -   hygienic macros
        -   user available
    -   Excellent inspection tools
        -   macroexpand
        -   quote
        -   clear, visible AST available

After we note this in our memory, let's do a full language design audit looking out for issues that may threaten this invariant. Let's identify gaps and opportunities to improve on this promise, and design and plan out tooling and infrastructure that will help us improve on this promise, and can be used for further development.
