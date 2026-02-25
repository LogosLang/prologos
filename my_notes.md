- [Desiderata](#org4b1c05f)
  - [Syntax](#orgaf300a8)
    - [Homoiconicity](#org254ccd6)
    - [Significant whitespace](#org8bae28c)
    - [Groupings](#org4b32098)
    - [Fully qualified namespaces with \`/\` seperator](#org2870200)
    - [EDN support](#org9b47f13)
    - [predicate functions prefer ending in \`?\`, by convention](#org5873596)
  - [Propagotors as first class](#org7325692)
  - [Fully qualified namespaces](#org377157f)
  - [Strongly typed](#org15a1a42)
  - [Functional-Logic-based language](#orgc626ef2)
  - [Dependent Types as first class](#org9cd09f2)
  - [Session Types for protocol, Linear Types for memory-guarentees](#org695ac35)
  - [Strong support for parallel processing](#org11d03dd)
  - [Pattern Matching as first class (like in Erlang or Prolog)](#org1cee0ea)
  - [Constraint Solver Language](#orgf58e91f)
  - [Blazingly fast](#org287d4de)
  - [Excellent, human-readable, compiler errors in the likes of Rust or Gleam **VERY IMPORTANT**](#orgf51576c)
  - [Arbitrary precision numbers, EFFICIENTLY](#org2bc9a22)
  - [Innovations on UNUM types](#org44a63d6)
  - [A "don't stop the world" garbage collector, like in Pony](#org80b706b)
  - [Immutable datastructures with structural sharing, like in Clojure](#org0b0f2b8)
- [primitives](#org0f1402b)
- [Logic Language](#orge092597)
  - [Runs on Propagator Infrastructure rather than typical SLD/SLG Resolution](#orgc08c03d)
  - [Logical variable names with significant modal prefixes](#orga8fcc18)
  - [First-class anonymous relation primitive](#org13e7548)
  - [Core primitives:](#org0553316)
  - [Seamless integration into the functional language.](#org9acb351)
    - [example prototype syntax](#org44cba6f)
- [Languages that inspire us](#orge403da5)
  - [Logic Programmming](#orgd9bac3c)
  - [Constraint Logic Programming](#orgd41ea7e)
  - [Functional Programming](#orgfbdeef1)
  - [Scripting Languages](#org9d7f18b)
  - [Formal Verification](#org1f3df1c)
  - [Sussman's Propogators](#org2aa8e9a)
  - [Interesting Type Systems](#org51471ac)
- [Target](#org633d1b9)
  - [LLVM](#orge3c2f45)
  - [Prototype in](#orgd18dd1f)
- [Personal TODOS](#orgf572857)
  - [Editor Support](#org24d9aab)
  - [Language Features](#org8d0537b)
  - [optmiizations/audits](#org7819d14)
  - [Array Language!](#orgb18ba1d)
  - [todo](#org840577e)
  - [Namespacing](#org70dbbd8)
  - [Research/Implementation Guidance Documentations](#orgf2e8308)
- [Bundles](#bundles)
  - [1. Composition, Not Inheritance](#org033062d)
  - [2. Arbitrary Refinement](#org475104a)
  - [3. Open-World Assumption](#orgc2b9565)
  - [The Lattice Structure](#org1d7f341)
- [Syntax Studies](#org9f164de)
  - [Multi-arity function bodies](#org66fd2b8)
  - [IDEAs FOR PAREN GROUPINGS](#org7a67bb1)
  - [Mixed syntax](#org9da41d1)
  - [call site typing, "Explicit Application"](#orgfc82b52)
  - [Piping](#org9f0cb55)
  - [\`spec\`](#org8db9bcc)
  - [Schema, Selection, Session](#orgb0aea6e)
    - [schema](#orgf47aef5)
    - [selection: require, include, and provide](#orga4c7841)
    - [session](#org9c420fa)
  - [Point Free&#x2026; APL Style Trains, Trines, and Trouble????](#org64e0923)
  - [!!!!!!!Narrowing](#org44eb15d)
  - [Map Syntax](#org2508617)
    - [Free standing hash-map: The Implicit HashMap Syntax](#orgf72a532)
    - [Map Key Accessor Pattern Syntax](#org4828880)
  - [Head Tail List Syntax](#org3095c5e)
    - [I'm thinking of adding support for prolog style [E1, \_, E3 | Rest] head|tail style syntax in lists. Would this keep homoiconicity? Does this work well on other collection types? Does it make sense? Maps? \`{:name "Alice" :age 42" | \_}\`. Can be used for unification/structural pattern-matching?](#org48aa4d2)
  - [Range Syntax](#orgac257de)
    - [I'm also thinking of supporting "Range Syntax" for lists and vectors. '[1..5] expands to '[1 2 3 4 5]; also '[1.10 :by 2] expands to '[1 3 5 7 9], '[10..0 :by -2] expands to '[10 8 6 4 2 0], and so on. Should also work on vectors, lazy lists?](#org8ed6014)
    - [Oh! Another idea is to include predicate functions as filter with lazy lists \`~[1.. even?]\`, \`~[1.. [< \_ 100]\`](#org1382afb)
    - [Two issues with the pipe operator to raise: 1. Clarify, does this prevent the nontermination issue? 2. We also have prolog [head | tail] syntax planned out, which uses the same \`|\`&#x2026; but because the range syntax uses .., would the set-builder like \`|\` still work?](#org56db35b)
    - [Let's make a short summary of our recommendations for Range Syntax (using keywords on predicates). Be concise, give examples.](#orgfad6532)
    - [Let's summarize our syntax conclusions from above for \`|>\` and \`>>\` with default last position piping, with considerations for \`\_\` magic holes. Let's provide concise but full examples to an implementer, and some considerations for implementing this as O(n) automatically at compiler.](#org53b1142)
  - [In-line let](#org9d78f56)
  - [Sigil Design](#org6d63a0b)
  - [fn](#org5a88d71)
  - [HashMap](#org1bb6501)
    - [Map Literal uses EDN style](#org891c3de)
    - [Lookup Syntax](#org215222c)
  - [foreign imports and ffi](#org653b936)
  - [Partial Functions, strict arity, and the Hole-y Trinity: Curry Favor](#org6e19391)
    - [Use placeholders to invoke partial function](#org847c1eb)
  - [Type Syntax](#org1845859)
  - [Logical Language](#org587e9fc)
    - [Keywords](#org90f3881)
    - [Logic Variable Syntax and notes](#org8c6d36f)
    - [Namespaces and Requires](#org8e43090)
    - [Clause Pipes](#orga762c7f)
    - [Unification](#org36b8eff)
  - [fn/rel fusion&#x2026;](#orge2afbc1)
  - [Unify | = | eq? 🤷‍♀️](#org2c8453b)
- [Data Structures](#orgfd551f9)
- [Vision, Principles,](#org21922c5)
- [Considerations](#org4fda43f)
  - [Part 2: Persistent Data Structures](#orgb54d278)
    - [1. HAMT (Hash Array Mapped Trie)](#org94db902)
    - [2. Transients for Batch Updates](#org84e35ee)
    - [3. RRB-Trees for Vectors](#org77eff9f)
    - [4. Structural Sharing + Logic Variables/](#orgccce636)
  - [Part 3: Evaluation Strategy](#orgb3bf61d)
- [Higher Rank Pi Type Syntax](#org77fca78)
  - [We have a current limitation with higher-rank Pi types that force us to use the s-expr backend language to write prologos transducers:](#org22750d6)
- [pipe](#org500f8d8)


<a id="org4b1c05f"></a>

# Desiderata


<a id="orgaf300a8"></a>

## Syntax


<a id="org254ccd6"></a>

### Homoiconicity

-   Code as Data
    -   reflectivity, inspectability, malleability
-   Simple syntax
-   Metaprogramming facility
-   Prefix-notation


<a id="org8bae28c"></a>

### Significant whitespace

-   No opening bracketing like Lisp (more like TCL)
-   New line, same level: implicit list of arguments
-   New line, deeper level: implicit tree-depth of the AST
-   Same line with \`()\` groupings: deeper tree-depth of the AST


<a id="org4b32098"></a>

### Groupings

-   [] - Functional Core - Command Language
-   () - Logical Core - Relational Language


<a id="org2870200"></a>

### Fully qualified namespaces with \`/\` seperator


<a id="org9b47f13"></a>

### EDN support


<a id="org5873596"></a>

### predicate functions prefer ending in \`?\`, by convention

-   valid? NOT isValid


<a id="org7325692"></a>

## Propagotors as first class


<a id="org377157f"></a>

## Fully qualified namespaces

-   disambiguate imports' names


<a id="org15a1a42"></a>

## Strongly typed


<a id="orgc626ef2"></a>

## Functional-Logic-based language

-   Also functional aspects
-   With procedural


<a id="org9cd09f2"></a>

## Dependent Types as first class


<a id="org695ac35"></a>

## Session Types for protocol, Linear Types for memory-guarentees

-   Dependent Session types


<a id="org11d03dd"></a>

## Strong support for parallel processing

-   anything that is "embarrassingly" parallel, and that would benefit from being so without extra overhead costs, should be so automatically
-   easy to understand/use primitives for concurrent and parallel processing


<a id="org1cee0ea"></a>

## Pattern Matching as first class (like in Erlang or Prolog)


<a id="orgf58e91f"></a>

## Constraint Solver Language


<a id="org287d4de"></a>

## Blazingly fast


<a id="orgf51576c"></a>

## Excellent, human-readable, compiler errors in the likes of Rust or Gleam **VERY IMPORTANT**


<a id="org2bc9a22"></a>

## Arbitrary precision numbers, EFFICIENTLY

-   I don't like "wrapping" Ints, for example; I would rather throw run-time errors than silently wrapping


<a id="org44a63d6"></a>

## Innovations on UNUM types


<a id="org80b706b"></a>

## A "don't stop the world" garbage collector, like in Pony


<a id="org0b0f2b8"></a>

## Immutable datastructures with structural sharing, like in Clojure

-   Philip Bagwell's Ideal Hashmaps Research
-   ideal vector commitments


<a id="org0f1402b"></a>

# primitives

-   (:= varName [: type] expr) inline let variable binding, attached to parent scope
-   


<a id="orge092597"></a>

# Logic Language


<a id="orgc08c03d"></a>

## Runs on Propagator Infrastructure rather than typical SLD/SLG Resolution


<a id="orga8fcc18"></a>

## Logical variable names with significant modal prefixes

-   ?logicVar: bimodal - designates either input or output
-   -logicVar: input - must be instantiated on use
-   +logicVar: output


<a id="org13e7548"></a>

## First-class anonymous relation primitive

\`defn\` <=> \`defr\` :: \`fn\` <=> \`rel\`


<a id="org0553316"></a>

## Core primitives:

-   \`clause\`
-   \`&>\` conjunctive clause piping
-   \`rel\` => relation
    -   defines an anonymous relation


<a id="org9acb351"></a>

## Seamless integration into the functional language.

-   use \`rel\` inside \`defn\`s; use \`


<a id="org44cba6f"></a>

### example prototype syntax

A *relation that produces proofs*, defined *locally* inside a *function*, returning *dependent types*.


<a id="orge403da5"></a>

# Languages that inspire us


<a id="orgd9bac3c"></a>

## Logic Programmming

-   Prolog (also homoiconic)


<a id="orgd41ea7e"></a>

## Constraint Logic Programming

-   ECLiPSe


<a id="orgfbdeef1"></a>

## Functional Programming

-   LISP
    -   Clojure
        -   "Hosted language",
            -   allows for seamless inte rop, especially on the JVM with Java
            -   Large reach, can reuse pre-existing libraries in ecosystem
            -   multiple hosts, JVM and javascript&#x2026; even more reach
        -   Immutable datastructures
            -   Efficient with structural sharing (like git)
            -   Safe sharing for concurrency use-cases


<a id="org9d7f18b"></a>

## Scripting Languages

-   TCL


<a id="org1f3df1c"></a>

## Formal Verification

-   Maude
    -   Flexibility to define arbitrary formal languages or logics, can be powerful and flexible in proving certain


<a id="org2aa8e9a"></a>

## Sussman's Propogators

-   Some formalisms using lattices


<a id="org51471ac"></a>

## Interesting Type Systems

-   Pony
-   Idris
-   Rust


<a id="org633d1b9"></a>

# Target


<a id="orge3c2f45"></a>

## LLVM

-   Hope to be able to leverage other languages in the ecosystem, with strong ffi support to things like C, C++, Rust, and others


<a id="orgd18dd1f"></a>

## Prototype in

-   ✅ Racket 🚀

Write a clean commit message detailing what we accomplished, only output as a markdown block.


<a id="orgf572857"></a>

# Personal TODOS


<a id="org24d9aab"></a>

## Editor Support

-   [X] load file, proper library path loading
-   [ ] tab on argument vectors, let-binding vectors, align to first var
-   [ ] rather than send last sym-expr to repl, send surfer-highlight region
-   [ ] \`:=\` syntax breaks highlighting
-   [ ] Surfer Mode QoL
    -   [ ] timer issue 🐞
    -   [ ] forward-back tree gets occasional stuck&#x2026; just jump to next tree node if misaligned
    -   [ ] better keybindings for nav, expand/contract context
    -   [ ] send overlay region to REPL
-   [ ] Documentation
    -   [ ] Doc Completion Keep currying in the core, add arity checking in the surface language
    -   [ ] Docstrings: Store documentation strings with definitions
-   quasiquote unquote \`,\` being stripped
-   Interactivity
    -   Hole-Driven Development Features


<a id="org8d0537b"></a>

## Language Features

-   [ ] Create Benchmarking Design -> intent Testing metavar upgrade
-   [ ] Upgrade our metavar and type inference infrastructure to our propagator network
-   [X] Clarify \`()\` as logic clauses and Type Groupings
-   [ ] Allow uncurried style in traits
-   [ ] Rewrite any code to prefer A? types as Unions (A | Nil)
    -   [ ] Emit warnings/errors for unhandled Nil cases in functions
-   [X] ‼️ Better Type delimiters in WS mode
    -   Any complex grouped types, Function, Pi, Sigma use \`()\`
        -   [X] 👩‍🔬🦆 Syntax Workshop!
            -   We repurpose \`<&#x2026;>\` to unify Pi and Sigma dependent types
-   [ ] if **must** take 3 args, let's write a version that can take 2
-   [ ] Map with key access syntax
    -   Make Example in Syntax Lab
    -   Implicit Map syntax
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
-   Macro Stuff
    -   When displaying list, use '[] display instead of cons
-   [ ] Return \`suc\` and \`pred\` to operate on Nat; \`inc\` and \`dec\` on Int 🌱
    -   [ ] In fact \`inc\` and \`dec\` should work on any Num type with trait and impl
    -   [ ] Map integer number literals to Int; 56N to Nat
    -   [ ] datum-sym -> sym?
-   [X] Update memory to indicate var-name? convention for predicate functions that return Bool
-   [X] Multi-arity defn: Case-split syntax with multiple arities (original feature request)
-   [X] Partial function application with wildcards
-   [X] 📝 variable argument support \`&#x2026;name\` syntax?
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
    -   key as first position is functional accessor to map \`:key {:key "a"} => "a"\`

-   [X] [BUNDLES!!!](#bundles)
-   [X] Return types arity style \`A B C -> D\` **NOT** curry style: \`A -> B -> C -> D\`
-   [X] \`defn\` default public \`defn-\` default private &#x2013; deprecate \`provide\`
-   [X] \`require\` QoL - \`:as\`
-   [X] \`let\` block vs in-line \`let\`s
    -   We support both&#x2026; sibling in-line lets share same local scope
    -   Design research/🦆
-   [X] foreign/ffi syntax
-   Metadata with ^{&#x2026;} ???
-   [X] ensure foreign symbols import cleanly
    -   [X] add :as foreign symbol aliasing
    -   [X] add WS support for foreign symbol imports
    -   [X] foreign symbols use \`/\` as distinct from prologos \`::\`
-   add a javascript foreign import
    -   spin up a v8 vm when there's a js import/block, run against that as sibling runtime


<a id="org7819d14"></a>

## optmiizations/audits

-   [ ] loop fusion with |> >>
    -   [ ] fusion only on pipe with reduce termination, needs further optimization
-   [ ] Type inference audit
    -   we know there's places for improvement
-   [ ] match desurgering &#x2013; do we have proper structural pattern matching?
    -   [ ] audit
-   [X] claude memory architecture
-   [ ] narrowing research document
-   [ ] revisit transients for full full pipeline implementation option
-   [ ] Revist UnionFind §4.3 in Logic Engine Design &#x2013; can we push for a O(log<sub>32</sub> n) variant with find and union? on CHAMP? (currently O(log n))


<a id="orgb18ba1d"></a>

## Array Language!

-   <f g h> Point Free combinators, Combinator Logic
    -   Intended to work over collections&#x2013;arrays, in particular


<a id="org840577e"></a>

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


<a id="org70dbbd8"></a>

## Namespacing

-   [X] auto provide \`defn\`s
    -   [X] create private defn- and co.
    -   [X] remove/deprecate \`provide\`
-   [X] Ensure namespace aliasing with \`:as\`
-   [X] change namespace delimiter from \`/\` to \`::\`
-   [ ] determine what core libraries get loaded in automatically can be called in by their fully-qualified names without require


<a id="orgf2e8308"></a>

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


<a id="org033062d"></a>

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


<a id="org475104a"></a>

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


<a id="orgc2b9565"></a>

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


<a id="org1d7f341"></a>

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


<a id="org9f164de"></a>

# Syntax Studies


<a id="org66fd2b8"></a>

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


<a id="org7a67bb1"></a>

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


<a id="org9da41d1"></a>

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


<a id="orgfc82b52"></a>

## call site typing, "Explicit Application"

-   When Might You Want Explicit Type Arguments?

Sometimes inference fails or you want to be explicit:

```prologos
;; Or at call site (if we support it)
let xs = nil @Nat  ;; "nil at type Nat"
```


<a id="org9f0cb55"></a>

## Piping

```prologos

|>    `pipe-as`
|>.   `pipe-first`
|>..  `pipe-last`

>>  Transducer

```


<a id="org8db9bcc"></a>

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


<a id="orgb0aea6e"></a>

## Schema, Selection, Session


<a id="orgf47aef5"></a>

### schema


<a id="orga4c7841"></a>

### selection: require, include, and provide


<a id="org9c420fa"></a>

### session


<a id="org64e0923"></a>

## Point Free&#x2026; APL Style Trains, Trines, and Trouble????

```prologos

spec compose [B -> C] [A -> B] -> [A -> C]
defn compose [f g]
  f [g _]

```


<a id="org44eb15d"></a>

## !!!!!!!Narrowing


<a id="org2508617"></a>

## Map Syntax


<a id="orgf72a532"></a>

### Free standing hash-map: The Implicit HashMap Syntax

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

1.  I've also been thinking through this concept of "implicit maps" syntax, something like:

    ```prologos
    def my-map
      :name "Alice"
      :age  42
      :address
        :city "Springfield"
        :zip  12345
        :street
          :street-name "Main"
          :street-type "Ave"
          :street-number 256
      :friends
        "Bob" "Candy"
        "Derick" "Epiphany"
    
    ;; parses to =>
    {:name "Alice" :age 42 :address {:city "Springfield" :street {:street-name "Main" :street-type "Ave" :street-number 256 :friends @["Bod" "Candy" "Derick" "Epiphany"]}}}
    
    
    At first I was thinking that we could maintain `[]` as a vector as in Clojure/EDN style, but on second thought, commands as dynamic values could be powerfully useful so we`d need to maintain specificity with the `@[]` syntax ... then we could write `:friends [get-friend-list "Alice"]`
    
    - Implicit Map Syntax: Significant Whitespace for Data
    
    This is a fascinating idea—using indentation to express nested structure.
    
    ---
    
    - The Core Concept
    
    #+begin_src prologos
    ;; Implicit map: indentation defines nesting
    def config
      :host "localhost"
      :port 8080
      :database
        :name "mydb"
        :user "admin"
        :pool-size 10
    
    ;; Equivalent to:
    def config {:host "localhost"
                :port 8080
                :database {:name "mydb"
                           :user "admin"
                           :pool-size 10}}
    ```
    
    &#x2014;
    
    -   Parsing Rules
    
    ```
    1. Keyword at start of line + value on same line = key-value pair
    2. Keyword at start of line + indented block = nested map
    3. Non-keyword values in sequence = vector/list
    4. [] is command (evaluation), @[] is vector literal
    5. Deeper indentation = deeper nesting
    ```
    
    &#x2014;
    
    -   Your Example Refined
    
    ```prologos
    def my-map
      :name "Alice"
      :age 42
      :address
        :city "Springfield"
        :zip 12345
        :street
          :street-name "Main"
          :street-type "Ave"
          :street-number 256
      :friends
        "Bob" "Candy"
        "Derick" "Epiphany"
    
    ;; Parses to:
    {:name "Alice"
     :age 42
     :address {:city "Springfield"
               :zip 12345
               :street {:street-name "Main"
                        :street-type "Ave"
                        :street-number 256}}
     :friends @["Bob" "Candy" "Derick" "Epiphany"]}
    ```
    
    &#x2014;
    
    -   Distinguishing Commands from Data
    
    ```prologos
    ;; [] is COMMAND (evaluated)
    ;; @[] is VECTOR LITERAL (data)
    
    def user-record
      :name "Alice"
      :friends @["Bob" "Candy"]           ;; literal vector
      :friend-count [length friends]      ;; computed!
      :created-at [now]                   ;; evaluated!
      :tags @[:admin :active]             ;; literal vector of keywords
      :permissions [get-permissions :admin]  ;; function call
    
    ;; Parses to:
    {:name "Alice"
     :friends @["Bob" "Candy"]
     :friend-count [length friends]       ;; this gets evaluated
     :created-at [now]                    ;; this gets evaluated
     :tags @[:admin :active]
     :permissions [get-permissions :admin]}
    ```
    
    &#x2014;
    
    -   Ambiguity Resolution
    
    Some cases need clear rules:
    
    ```prologos
    ;; ========================================
    ;; Case 1: Values on same line
    ;; ========================================
    
    def point
      :x 10 :y 20        ;; two pairs on one line?
    
    ;; Option A: Error (one pair per line)
    ;; Option B: Allow, parse as {:x 10 :y 20}
    
    ;; Recommendation: One pair per line (cleaner)
    def point
      :x 10
      :y 20
    
    ;; ========================================
    ;; Case 2: Bare values (no keyword)
    ;; ========================================
    
    def items
      "apple"
      "banana"
      "cherry"
    
    ;; This is a vector, not a map!
    ;; => @["apple" "banana" "cherry"]
    
    ;; ========================================
    ;; Case 3: Mixed keywords and bare values
    ;; ========================================
    
    def mixed
      :header "Title"
      "body text"
      "more text"
      :footer "End"
    
    ;; Error? Or special handling?
    ;; Recommendation: Error - must be consistent
    
    ;; ========================================
    ;; Case 4: Nested command
    ;; ========================================
    
    def computed
      :data
        [fetch-from-db "users"]     ;; command, not nested map
    
    ;; Indented [] is still a command
    ;; Returns result of fetch-from-db
    
    ;; ========================================
    ;; Case 5: List of maps
    ;; ========================================
    
    def users
      -
        :name "Alice"
        :age 30
      -
        :name "Bob"
        :age 25
    
    ;; Using - as item separator (YAML-like)
    ;; => @[{:name "Alice" :age 30} {:name "Bob" :age 25}]
    ```
    
    &#x2014;
    
    -   Full Syntax Proposal
    
    ```prologos
    ;; ========================================
    ;; Simple map
    ;; ========================================
    
    def config
      :key1 value1
      :key2 value2
      :key3 value3
    
    ;; => {:key1 value1 :key2 value2 :key3 value3}
    
    ;; ========================================
    ;; Nested map (indentation)
    ;; ========================================
    
    def nested
      :level1
        :level2a "value"
        :level2b
          :level3 "deep"
    
    ;; => {:level1 {:level2a "value" :level2b {:level3 "deep"}}}
    
    ;; ========================================
    ;; Vector value (explicit @[])
    ;; ========================================
    
    def with-vec
      :items @[1 2 3 4 5]
      :names @["Alice" "Bob"]
    
    ;; => {:items @[1 2 3 4 5] :names @["Alice" "Bob"]}
    
    ;; ========================================
    ;; Computed value ([] command)
    ;; ========================================
    
    def computed
      :timestamp [now]
      :user-count [count-users]
      :config [load-config "app.toml"]
    
    ;; => {:timestamp <evaluated> :user-count <evaluated> ...}
    
    ;; ========================================
    ;; Inline vector of values (bare, same indent)
    ;; ========================================
    
    def with-inline
      :tags
        :admin :user :guest    ;; multiple keywords = vec of keywords?
    
    ;; Ambiguous! Better to be explicit:
    def with-inline
      :tags @[:admin :user :guest]
    
    ;; ========================================
    ;; List of maps (- separator)
    ;; ========================================
    
    def users
      -
        :name "Alice"
        :role :admin
      -
        :name "Bob"
        :role :user
      -
        :name "Carol"
        :role :guest
    
    ;; => @[{:name "Alice" :role :admin}
    ;;      {:name "Bob" :role :user}
    ;;      {:name "Carol" :role :guest}]
    
    ;; ========================================
    ;; Mixed: map with list of maps
    ;; ========================================
    
    def app-config
      :name "MyApp"
      :version "1.0"
      :endpoints
        -
          :path "/users"
          :method :get
        -
          :path "/users"
          :method :post
      :database
        :host "localhost"
        :port 5432
    
    ;; => {:name "MyApp"
    ;;     :version "1.0"
    ;;     :endpoints @[{:path "/users" :method :get}
    ;;                  {:path "/users" :method :post}]
    ;;     :database {:host "localhost" :port 5432}}
    ```
    
    &#x2014;
    
    -   Comparison with Other Formats
    
    | Format   | Nesting     | Lists        | Commands | Prologos Equivalent  |
    |-------- |----------- |------------ |-------- |-------------------- |
    | JSON     | `{}`        | `[]`         | None     | `{:k v}`, `@[]`      |
    | EDN      | `{}`        | `[]`, `()`   | None     | `{:k v}`, `@[]`      |
    | YAML     | Indentation | `- item`     | None     | Indentation + `-`    |
    | TOML     | `[section]` | `[]`         | None     | Different            |
    | Prologos | Indentation | `-` or `@[]` | `[]`     | *Best of all worlds* |
    
    &#x2014;
    
    -   Power of Commands in Data
    
    ```prologos
    ;; ========================================
    ;; Dynamic configuration
    ;; ========================================
    
    def server-config
      :host [env "SERVER_HOST" ?: "localhost"]
      :port [env "SERVER_PORT" |> int ?: 8080]
      :debug [env "DEBUG" |> bool ?: false]
      :db
        :url [env "DATABASE_URL"]
        :pool-size [env "DB_POOL" |> int ?: 5]
    
    ;; ========================================
    ;; Computed relationships
    ;; ========================================
    
    def user
      :name "Alice"
      :email "alice@example.com"
      :friends [get-friend-list "Alice"]
      :friend-count [length [get-friend-list "Alice"]]
      :is-admin [has-role? "Alice" :admin]
    
    ;; ========================================
    ;; Template-like structures
    ;; ========================================
    
    def html-page
      :doctype "html"
      :html
        :head
          :title [page-title]
          :meta @[{:charset "utf-8"}]
        :body
          :div
            :class "container"
            :content [render-content]
    
    ;; ========================================
    ;; Test fixtures with setup
    ;; ========================================
    
    def test-context
      :db [setup-test-db]
      :user [create-test-user "test@example.com"]
      :token [generate-auth-token user]
      :cleanup [fn [] [teardown-test-db db]]
    ```
    
    &#x2014;
    
    -   Homoiconicity: What's the AST?
    
    ```prologos
    ;; Source (implicit map)
    def config
      :host "localhost"
      :port 8080
      :db
        :name "mydb"
    
    ;; AST (explicit form)
    [def config
      {:host "localhost"
       :port 8080
       :db {:name "mydb"}}]
    
    ;; Or if we want implicit-map as its own node:
    [def config
      [implicit-map
        [:host "localhost"]
        [:port 8080]
        [:db [implicit-map
               [:name "mydb"]]]]]
    
    ;; Quote captures implicit structure
    $[def config
        :host "localhost"
        :port 8080]
    
    ;; => [def config [implicit-map [:host "localhost"] [:port 8080]]]
    ```
    
    &#x2014;
    
    -   When to Use Which Syntax?
    
    | Syntax           | Use Case                  | Example                   |
    |---------------- |------------------------- |------------------------- |
    | Implicit map     | Config, specs, large data | `def config :key val ...` |
    | Explicit `{...}` | Inline, small, one-liners | `{:x 1 :y 2}`             |
    | `@[...]`         | Vector literals           | `@[1 2 3]`                |
    | `[...]`          | Commands, function calls  | `[get user :name]`        |
    
    ```prologos
    ;; ========================================
    ;; Implicit: large, multi-line configs
    ;; ========================================
    
    def app-manifest
      :name "My Application"
      :version "2.1.0"
      :description "A sample application"
      :author
        :name "Alice Developer"
        :email "alice@example.com"
      :dependencies
        -
          :name "core-lib"
          :version "^1.0"
        -
          :name "http-client"
          :version "^2.3"
      :scripts
        :build [concat "prologos build " target]
        :test "prologos test"
        :deploy [deploy-script env]
    
    ;; ========================================
    ;; Explicit: inline, in expressions
    ;; ========================================
    
    [map (fn [x] {:value x :squared (* x x)}) numbers]
    
    [assoc user :address {:city "NYC" :zip 10001}]
    
    let point = {:x 10 :y 20}
    ```
    
    &#x2014;
    
    -   Potential Issues and Solutions
    
    | Issue                        | Solution                             |
    |---------------------------- |------------------------------------ |
    | Ambiguous: keyword or value? | Keywords start with `:`, always      |
    | Mixed map and list?          | Error: must be consistent per block  |
    | Inline vs nested?            | Same line = value, indented = nested |
    | Command vs literal?          | `[]` = command, `@[]` = literal      |
    | Empty map/list?              | `:key {}` or `:key @[]`              |
    
    &#x2014;
    
    -   Final Recommendation
    
    ```prologos
    ;; ========================================
    ;; Summary: Data Syntax
    ;; ========================================
    
    ;; Explicit map (inline, small)
    {:key "value" :other 42}
    
    ;; Explicit vector (literal)
    @[1 2 3 4 5]
    @[:a :b :c]
    
    ;; Command (evaluated)
    [function arg1 arg2]
    
    ;; Implicit map (multi-line, config-like)
    def my-data
      :key1 "value1"
      :key2 42
      :nested
        :inner "data"
      :list @[1 2 3]
      :computed [some-function arg]
    
    ;; List of maps (- separator)
    def items
      -
        :name "first"
      -
        :name "second"
    
    ;; ========================================
    ;; Rules
    ;; ========================================
    
    ;; 1. :keyword value     => map entry
    ;; 2. Indented block     => nested map
    ;; 3. @[...]             => literal vector
    ;; 4. [...]              => command (evaluated)
    ;; 5. - starts item      => list of items
    ;; 6. One entry per line => cleaner, less ambiguous
    ```
    
    This gives you YAML's readability with Lisp's power (commands in data) while maintaining homoiconicity.
    
    Does this capture what you're envisioning?
    
    **\*\***
    
    \#+end<sub>src</sub>
    
    -   Implicit Map Syntax: Indentation-Based Maps
    
    This is a lovely idea. It leverages your significant whitespace and creates a very clean, YAML-like syntax for data.
    
    &#x2014;
    
    -   The Concept
    
    ```prologos
    ;; ========================================
    ;; Implicit map: keyword at line start = key
    ;; ========================================
    
    def my-map
      :name "Alice"
      :age 42
      :active true
    
    ;; Parses to:
    {:name "Alice" :age 42 :active true}
    
    ;; ========================================
    ;; Nested: indentation = nesting
    ;; ========================================
    
    def user
      :name "Alice"
      :address
        :city "Springfield"
        :zip 12345
    
    ;; Parses to:
    {:name "Alice" :address {:city "Springfield" :zip 12345}}
    
    ;; ========================================
    ;; Deep nesting
    ;; ========================================
    
    def config
      :server
        :host "localhost"
        :port 8080
        :ssl
          :enabled true
          :cert "/path/to/cert"
      :database
        :url "postgres://..."
        :pool-size 10
    
    ;; Parses to:
    {:server {:host "localhost"
              :port 8080
              :ssl {:enabled true :cert "/path/to/cert"}}
     :database {:url "postgres://..." :pool-size 10}}
    ```
    
    &#x2014;
    
    -   Parsing Rules
    
    ```
    1. Line starts with keyword → key-value pair
    2. Same indentation as sibling → same map
    3. Deeper indentation after keyword-only line → nested map
    4. Value on same line as keyword → leaf value
    5. No value after keyword → nested map follows
    ```
    
    ```prologos
    ;; Rule 4: value on same line = leaf
    :name "Alice"        ;; {:name "Alice"}
    
    ;; Rule 5: no value = nested map
    :address             ;; {:address {...}}
      :city "NYC"        ;;   nested content
    ```
    
    &#x2014;
    
    -   Grammar Sketch
    
    ```
    ImplicitMap ::= ImplicitEntry+
    
    ImplicitEntry ::= Keyword Value Newline           ;; leaf
                    | Keyword Newline Indent ImplicitMap Dedent  ;; nested
    
    Value ::= Literal | Expr | ImplicitVec | InlineMap
    
    Indent ::= increase in indentation
    Dedent ::= decrease in indentation
    ```
    
    &#x2014;
    
    -   Edge Cases and Extensions
    
    -   Lists/Vectors in Implicit Maps
    
    ```prologos
    ;; Option A: inline
    def user
      :name "Alice"
      :tags @[:admin :active]
      :scores @[95 87 92]
    
    ;; Option B: implicit list with -
    def user
      :name "Alice"
      :tags
        - :admin
        - :active
      :scores
        - 95
        - 87
        - 92
    
    ;; Parses to:
    {:name "Alice" :tags @[:admin :active] :scores @[95 87 92]}
    ```
    
    -   Mixed: Inline and Implicit
    
    ```prologos
    ;; Can mix inline and implicit
    def config
      :server {:host "localhost" :port 8080}  ;; inline map
      :database
        :url "postgres://..."
        :pool-size 10
    
    ;; Parses to:
    {:server {:host "localhost" :port 8080}
     :database {:url "postgres://..." :pool-size 10}}
    ```
    
    -   Expressions as Values
    
    ```prologos
    def computed
      :timestamp [now]
      :sum [+ 1 2 3]
      :greeting [format "Hello, ~a" name]
    
    ;; Parses to:
    {:timestamp [now] :sum [+ 1 2 3] :greeting [format "Hello, ~a" name]}
    ```
    
    -   String Keys (Non-Keyword)
    
    ```prologos
    ;; What if key isn't a keyword?
    def headers
      "Content-Type" "application/json"
      "Authorization" [format "Bearer ~a" token]
    
    ;; Could use different syntax
    def headers
      ="Content-Type" "application/json"    ;; = prefix for string key?
      ="Authorization" [format "Bearer ~a" token]
    ```
    
    &#x2014;
    
    -   Comparison: Explicit vs Implicit
    
    ```prologos
    ;; ========================================
    ;; Explicit (EDN-style)
    ;; ========================================
    
    def user {:name "Alice"
              :age 42
              :address {:city "Springfield"
                        :zip 12345
                        :street {:name "Main"
                                 :type "Ave"
                                 :number 256}}}
    
    ;; ========================================
    ;; Implicit (indentation-based)
    ;; ========================================
    
    def user
      :name "Alice"
      :age 42
      :address
        :city "Springfield"
        :zip 12345
        :street
          :name "Main"
          :type "Ave"
          :number 256
    ```
    
    | Aspect            | Explicit         | Implicit           |
    |----------------- |---------------- |------------------ |
    | Verbosity         | More punctuation | Less punctuation   |
    | Nesting clarity   | Brackets         | Indentation        |
    | Diff-friendliness | Poor (brackets)  | Excellent          |
    | Copy-paste        | Works anywhere   | Whitespace matters |
    | Homoiconic        | Obvious          | After parsing      |
    
    &#x2014;
    
    -   When to Use Which
    
    ```prologos
    ;; ========================================
    ;; Implicit: config, data definitions
    ;; ========================================
    
    def app-config
      :server
        :host "0.0.0.0"
        :port 8080
      :logging
        :level :info
        :format :json
    
    ;; ========================================
    ;; Explicit: inline, small maps
    ;; ========================================
    
    let point = {:x 10 :y 20}
    let user = {:name n :age a}
    [assoc m :key {:nested "value"}]
    
    ;; ========================================
    ;; Both work, user chooses
    ;; ========================================
    ```
    
    &#x2014;
    
    -   Integration with Schema
    
    ```prologos
    ;; ========================================
    ;; Schema definition
    ;; ========================================
    
    schema User
      :name String
      :age Nat
      :address Address
    
    schema Address
      :city String
      :zip Nat
      :street Street
    
    schema Street
      :name String
      :type StreetType
      :number Nat
    
    ;; ========================================
    ;; Instance using implicit map
    ;; ========================================
    
    def alice : User
      :name "Alice"
      :age 42
      :address
        :city "Springfield"
        :zip 12345
        :street
          :name "Main"
          :type :ave
          :number 256
    
    ;; Type-checked against schema!
    ```
    
    &#x2014;
    
    -   Implementation Considerations
    
    -   Reader Phase
    
    ```racket
    ;; Reader tracks indentation stack
    ;; When it sees:
    ;;   :key value   → (cons :key value)
    ;;   :key\n       → (cons :key (read-implicit-map deeper-indent))
    
    (define (read-implicit-map current-indent)
      (let loop ([pairs '()])
        (let ([line-indent (peek-indent)])
          (cond
            [(< line-indent current-indent)
             ;; dedent: done with this map
             (make-map (reverse pairs))]
            [(= line-indent current-indent)
             ;; same level: read key-value
             (let* ([key (read-keyword)]
                    [val (read-value-or-nested)])
               (loop (cons (cons key val) pairs)))]
            [else
             ;; deeper indent: shouldn't happen at map start
             (error "unexpected indent")]))))
    ```
    
    -   AST Representation
    
    ```prologos
    ;; Source
    def user
      :name "Alice"
      :address
        :city "NYC"
    
    ;; AST (same as explicit map)
    [def user
      [map
        [:name "Alice"]
        [:address
          [map
            [:city "NYC"]]]]]
    
    ;; Homoiconic: both syntaxes produce same AST
    ```
    
    &#x2014;
    
    -   Implicit Vec Syntax?
    
    Should we also have implicit vectors?
    
    ```prologos
    ;; ========================================
    ;; Option A: - prefix (YAML-style)
    ;; ========================================
    
    def numbers
      - 1
      - 2
      - 3
    
    ;; Parses to: @[1 2 3]
    
    def users
      -
        :name "Alice"
        :age 30
      -
        :name "Bob"
        :age 25
    
    ;; Parses to: @[{:name "Alice" :age 30} {:name "Bob" :age 25}]
    
    ;; ========================================
    ;; Option B: no implicit vec, use inline
    ;; ========================================
    
    def user
      :name "Alice"
      :scores @[95 87 92]      ;; inline vec
      :tags #{:admin :active}  ;; inline set
    ```
    
    &#x2014;
    
    -   Full Example: Config File
    
    ```prologos
    ;; ========================================
    ;; app-config.prol
    ;; ========================================
    
    def config
      :app
        :name "MyApp"
        :version "1.0.0"
        :env :production
    
      :server
        :host "0.0.0.0"
        :port 8080
        :ssl
          :enabled true
          :cert "/etc/ssl/cert.pem"
          :key "/etc/ssl/key.pem"
    
      :database
        :primary
          :url "postgres://localhost:5432/myapp"
          :pool-size 20
          :timeout 30000
        :replica
          :url "postgres://replica:5432/myapp"
          :pool-size 10
    
      :logging
        :level :info
        :format :json
        :outputs
          - :stdout
          - :file "/var/log/myapp.log"
    
      :features
        :new-dashboard true
        :beta-api false
        :allowed-origins
          - "https://example.com"
          - "https://app.example.com"
    ```
    
    &#x2014;
    
    -   Summary
    
    | Feature              | Syntax             |
    |-------------------- |------------------ |
    | Key-value (leaf)     | `:key value`       |
    | Nested map           | `:key` + indent    |
    | List in implicit map | `- item` or inline |
    | Inline map           | `{:k1 v1 :k2 v2}`  |
    | Mixed                | Freely combine     |
    
    | Benefit         | Description                    |
    |--------------- |------------------------------ |
    | Readable        | No bracket noise               |
    | Diff-friendly   | One key-value per line         |
    | Config-friendly | Feels like YAML/TOML           |
    | Homoiconic      | Parses to same AST as explicit |
    | Type-safe       | Can validate against schema    |
    
    Does this implicit map syntax feel right for Prologos?


<a id="org4828880"></a>

### Map Key Accessor Pattern Syntax

1.  Conversation: I've also been thinking through this concept of "implicit maps" syntax, something like:

    ```prologos
    def my-map
      :name "Alice"
      :age  42
      :address
        :city "Springfield"
        :zip  12345
        :street
          :street-name "Main"
          :street-type "Ave"
          :street-number 256
      :friends
        "Bob" "Candy"
        "Derick" "Epiphany"
    
    ;; parses to =>
    {:name "Alice" :age 42 :address {:city "Springfield" :street {:street-name "Main" :street-type "Ave" :street-number 256 :friends @["Bod" "Candy" "Derick" "Epiphany"]}}}
    
    
    At first I was thinking that we could maintain `[]` as a vector as in Clojure/EDN style, but on second thought, commands as dynamic values could be powerfully useful so we`d need to maintain specificity with the `@[]` syntax ... then we could write `:friends [get-friend-list "Alice"]`
    
    - Implicit Map Syntax: Significant Whitespace for Data
    
    This is a fascinating idea—using indentation to express nested structure.
    
    ---
    
    - The Core Concept
    
    #+begin_src prologos
    ;; Implicit map: indentation defines nesting
    def config
      :host "localhost"
      :port 8080
      :database
        :name "mydb"
        :user "admin"
        :pool-size 10
    
    ;; Equivalent to:
    def config {:host "localhost"
                :port 8080
                :database {:name "mydb"
                           :user "admin"
                           :pool-size 10}}
    ```
    
    &#x2014;
    
    -   Parsing Rules
    
    ```
    1. Keyword at start of line + value on same line = key-value pair
    2. Keyword at start of line + indented block = nested map
    3. Non-keyword values in sequence = vector/list
    4. [] is command (evaluation), @[] is vector literal
    5. Deeper indentation = deeper nesting
    ```
    
    &#x2014;
    
    -   Your Example Refined
    
    ```prologos
    def my-map
      :name "Alice"
      :age 42
      :address
        :city "Springfield"
        :zip 12345
        :street
          :street-name "Main"
          :street-type "Ave"
          :street-number 256
      :friends
        "Bob" "Candy"
        "Derick" "Epiphany"
    
    ;; Parses to:
    {:name "Alice"
     :age 42
     :address {:city "Springfield"
               :zip 12345
               :street {:street-name "Main"
                        :street-type "Ave"
                        :street-number 256}}
     :friends @["Bob" "Candy" "Derick" "Epiphany"]}
    ```
    
    &#x2014;
    
    -   Distinguishing Commands from Data
    
    ```prologos
    ;; [] is COMMAND (evaluated)
    ;; @[] is VECTOR LITERAL (data)
    
    def user-record
      :name "Alice"
      :friends @["Bob" "Candy"]           ;; literal vector
      :friend-count [length friends]      ;; computed!
      :created-at [now]                   ;; evaluated!
      :tags @[:admin :active]             ;; literal vector of keywords
      :permissions [get-permissions :admin]  ;; function call
    
    ;; Parses to:
    {:name "Alice"
     :friends @["Bob" "Candy"]
     :friend-count [length friends]       ;; this gets evaluated
     :created-at [now]                    ;; this gets evaluated
     :tags @[:admin :active]
     :permissions [get-permissions :admin]}
    ```
    
    &#x2014;
    
    -   Ambiguity Resolution
    
    Some cases need clear rules:
    
    ```prologos
    ;; ========================================
    ;; Case 1: Values on same line
    ;; ========================================
    
    def point
      :x 10 :y 20        ;; two pairs on one line?
    
    ;; Option A: Error (one pair per line)
    ;; Option B: Allow, parse as {:x 10 :y 20}
    
    ;; Recommendation: One pair per line (cleaner)
    def point
      :x 10
      :y 20
    
    ;; ========================================
    ;; Case 2: Bare values (no keyword)
    ;; ========================================
    
    def items
      "apple"
      "banana"
      "cherry"
    
    ;; This is a vector, not a map!
    ;; => @["apple" "banana" "cherry"]
    
    ;; ========================================
    ;; Case 3: Mixed keywords and bare values
    ;; ========================================
    
    def mixed
      :header "Title"
      "body text"
      "more text"
      :footer "End"
    
    ;; Error? Or special handling?
    ;; Recommendation: Error - must be consistent
    
    ;; ========================================
    ;; Case 4: Nested command
    ;; ========================================
    
    def computed
      :data
        [fetch-from-db "users"]     ;; command, not nested map
    
    ;; Indented [] is still a command
    ;; Returns result of fetch-from-db
    
    ;; ========================================
    ;; Case 5: List of maps
    ;; ========================================
    
    def users
      -
        :name "Alice"
        :age 30
      -
        :name "Bob"
        :age 25
    
    ;; Using - as item separator (YAML-like)
    ;; => @[{:name "Alice" :age 30} {:name "Bob" :age 25}]
    ```
    
    &#x2014;
    
    -   Full Syntax Proposal
    
    ```prologos
    ;; ========================================
    ;; Simple map
    ;; ========================================
    
    def config
      :key1 value1
      :key2 value2
      :key3 value3
    
    ;; => {:key1 value1 :key2 value2 :key3 value3}
    
    ;; ========================================
    ;; Nested map (indentation)
    ;; ========================================
    
    def nested
      :level1
        :level2a "value"
        :level2b
          :level3 "deep"
    
    ;; => {:level1 {:level2a "value" :level2b {:level3 "deep"}}}
    
    ;; ========================================
    ;; Vector value (explicit @[])
    ;; ========================================
    
    def with-vec
      :items @[1 2 3 4 5]
      :names @["Alice" "Bob"]
    
    ;; => {:items @[1 2 3 4 5] :names @["Alice" "Bob"]}
    
    ;; ========================================
    ;; Computed value ([] command)
    ;; ========================================
    
    def computed
      :timestamp [now]
      :user-count [count-users]
      :config [load-config "app.toml"]
    
    ;; => {:timestamp <evaluated> :user-count <evaluated> ...}
    
    ;; ========================================
    ;; Inline vector of values (bare, same indent)
    ;; ========================================
    
    def with-inline
      :tags
        :admin :user :guest    ;; multiple keywords = vec of keywords?
    
    ;; Ambiguous! Better to be explicit:
    def with-inline
      :tags @[:admin :user :guest]
    
    ;; ========================================
    ;; List of maps (- separator)
    ;; ========================================
    
    def users
      -
        :name "Alice"
        :role :admin
      -
        :name "Bob"
        :role :user
      -
        :name "Carol"
        :role :guest
    
    ;; => @[{:name "Alice" :role :admin}
    ;;      {:name "Bob" :role :user}
    ;;      {:name "Carol" :role :guest}]
    
    ;; ========================================
    ;; Mixed: map with list of maps
    ;; ========================================
    
    def app-config
      :name "MyApp"
      :version "1.0"
      :endpoints
        -
          :path "/users"
          :method :get
        -
          :path "/users"
          :method :post
      :database
        :host "localhost"
        :port 5432
    
    ;; => {:name "MyApp"
    ;;     :version "1.0"
    ;;     :endpoints @[{:path "/users" :method :get}
    ;;                  {:path "/users" :method :post}]
    ;;     :database {:host "localhost" :port 5432}}
    ```
    
    &#x2014;
    
    -   Comparison with Other Formats
    
    | Format   | Nesting     | Lists        | Commands | Prologos Equivalent  |
    |-------- |----------- |------------ |-------- |-------------------- |
    | JSON     | `{}`        | `[]`         | None     | `{:k v}`, `@[]`      |
    | EDN      | `{}`        | `[]`, `()`   | None     | `{:k v}`, `@[]`      |
    | YAML     | Indentation | `- item`     | None     | Indentation + `-`    |
    | TOML     | `[section]` | `[]`         | None     | Different            |
    | Prologos | Indentation | `-` or `@[]` | `[]`     | *Best of all worlds* |
    
    &#x2014;
    
    -   Power of Commands in Data
    
    ```prologos
    ;; ========================================
    ;; Dynamic configuration
    ;; ========================================
    
    def server-config
      :host [env "SERVER_HOST" ?: "localhost"]
      :port [env "SERVER_PORT" |> int ?: 8080]
      :debug [env "DEBUG" |> bool ?: false]
      :db
        :url [env "DATABASE_URL"]
        :pool-size [env "DB_POOL" |> int ?: 5]
    
    ;; ========================================
    ;; Computed relationships
    ;; ========================================
    
    def user
      :name "Alice"
      :email "alice@example.com"
      :friends [get-friend-list "Alice"]
      :friend-count [length [get-friend-list "Alice"]]
      :is-admin [has-role? "Alice" :admin]
    
    ;; ========================================
    ;; Template-like structures
    ;; ========================================
    
    def html-page
      :doctype "html"
      :html
        :head
          :title [page-title]
          :meta @[{:charset "utf-8"}]
        :body
          :div
            :class "container"
            :content [render-content]
    
    ;; ========================================
    ;; Test fixtures with setup
    ;; ========================================
    
    def test-context
      :db [setup-test-db]
      :user [create-test-user "test@example.com"]
      :token [generate-auth-token user]
      :cleanup [fn [] [teardown-test-db db]]
    ```
    
    &#x2014;
    
    -   Homoiconicity: What's the AST?
    
    ```prologos
    ;; Source (implicit map)
    def config
      :host "localhost"
      :port 8080
      :db
        :name "mydb"
    
    ;; AST (explicit form)
    [def config
      {:host "localhost"
       :port 8080
       :db {:name "mydb"}}]
    
    ;; Or if we want implicit-map as its own node:
    [def config
      [implicit-map
        [:host "localhost"]
        [:port 8080]
        [:db [implicit-map
               [:name "mydb"]]]]]
    
    ;; Quote captures implicit structure
    $[def config
        :host "localhost"
        :port 8080]
    
    ;; => [def config [implicit-map [:host "localhost"] [:port 8080]]]
    ```
    
    &#x2014;
    
    -   When to Use Which Syntax?
    
    | Syntax           | Use Case                  | Example                   |
    |---------------- |------------------------- |------------------------- |
    | Implicit map     | Config, specs, large data | `def config :key val ...` |
    | Explicit `{...}` | Inline, small, one-liners | `{:x 1 :y 2}`             |
    | `@[...]`         | Vector literals           | `@[1 2 3]`                |
    | `[...]`          | Commands, function calls  | `[get user :name]`        |
    
    ```prologos
    ;; ========================================
    ;; Implicit: large, multi-line configs
    ;; ========================================
    
    def app-manifest
      :name "My Application"
      :version "2.1.0"
      :description "A sample application"
      :author
        :name "Alice Developer"
        :email "alice@example.com"
      :dependencies
        -
          :name "core-lib"
          :version "^1.0"
        -
          :name "http-client"
          :version "^2.3"
      :scripts
        :build [concat "prologos build " target]
        :test "prologos test"
        :deploy [deploy-script env]
    
    ;; ========================================
    ;; Explicit: inline, in expressions
    ;; ========================================
    
    [map (fn [x] {:value x :squared (* x x)}) numbers]
    
    [assoc user :address {:city "NYC" :zip 10001}]
    
    let point = {:x 10 :y 20}
    ```
    
    &#x2014;
    
    -   Potential Issues and Solutions
    
    | Issue                        | Solution                             |
    |---------------------------- |------------------------------------ |
    | Ambiguous: keyword or value? | Keywords start with `:`, always      |
    | Mixed map and list?          | Error: must be consistent per block  |
    | Inline vs nested?            | Same line = value, indented = nested |
    | Command vs literal?          | `[]` = command, `@[]` = literal      |
    | Empty map/list?              | `:key {}` or `:key @[]`              |
    
    &#x2014;
    
    -   Final Recommendation
    
    ```prologos
    ;; ========================================
    ;; Summary: Data Syntax
    ;; ========================================
    
    ;; Explicit map (inline, small)
    {:key "value" :other 42}
    
    ;; Explicit vector (literal)
    @[1 2 3 4 5]
    @[:a :b :c]
    
    ;; Command (evaluated)
    [function arg1 arg2]
    
    ;; Implicit map (multi-line, config-like)
    def my-data
      :key1 "value1"
      :key2 42
      :nested
        :inner "data"
      :list @[1 2 3]
      :computed [some-function arg]
    
    ;; List of maps (- separator)
    def items
      -
        :name "first"
      -
        :name "second"
    
    ;; ========================================
    ;; Rules
    ;; ========================================
    
    ;; 1. :keyword value     => map entry
    ;; 2. Indented block     => nested map
    ;; 3. @[...]             => literal vector
    ;; 4. [...]              => command (evaluated)
    ;; 5. - starts item      => list of items
    ;; 6. One entry per line => cleaner, less ambiguous
    ```
    
    This gives you YAML's readability with Lisp's power (commands in data) while maintaining homoiconicity.
    
    Does this capture what you're envisioning?

2.  Conversation:

    \#+end<sub>src</sub>
    
    -   Implicit Map Syntax: Indentation-Based Maps
    
    This is a lovely idea. It leverages your significant whitespace and creates a very clean, YAML-like syntax for data.
    
    &#x2014;
    
    -   The Concept
    
    ```prologos
    ;; ========================================
    ;; Implicit map: keyword at line start = key
    ;; ========================================
    
    def my-map
      :name "Alice"
      :age 42
      :active true
    
    ;; Parses to:
    {:name "Alice" :age 42 :active true}
    
    ;; ========================================
    ;; Nested: indentation = nesting
    ;; ========================================
    
    def user
      :name "Alice"
      :address
        :city "Springfield"
        :zip 12345
    
    ;; Parses to:
    {:name "Alice" :address {:city "Springfield" :zip 12345}}
    
    ;; ========================================
    ;; Deep nesting
    ;; ========================================
    
    def config
      :server
        :host "localhost"
        :port 8080
        :ssl
          :enabled true
          :cert "/path/to/cert"
      :database
        :url "postgres://..."
        :pool-size 10
    
    ;; Parses to:
    {:server {:host "localhost"
              :port 8080
              :ssl {:enabled true :cert "/path/to/cert"}}
     :database {:url "postgres://..." :pool-size 10}}
    ```
    
    &#x2014;
    
    -   Parsing Rules
    
    ```
    1. Line starts with keyword → key-value pair
    2. Same indentation as sibling → same map
    3. Deeper indentation after keyword-only line → nested map
    4. Value on same line as keyword → leaf value
    5. No value after keyword → nested map follows
    ```
    
    ```prologos
    ;; Rule 4: value on same line = leaf
    :name "Alice"        ;; {:name "Alice"}
    
    ;; Rule 5: no value = nested map
    :address             ;; {:address {...}}
      :city "NYC"        ;;   nested content
    ```
    
    &#x2014;
    
    -   Grammar Sketch
    
    ```
    ImplicitMap ::= ImplicitEntry+
    
    ImplicitEntry ::= Keyword Value Newline           ;; leaf
                    | Keyword Newline Indent ImplicitMap Dedent  ;; nested
    
    Value ::= Literal | Expr | ImplicitVec | InlineMap
    
    Indent ::= increase in indentation
    Dedent ::= decrease in indentation
    ```
    
    &#x2014;
    
    -   Edge Cases and Extensions
    
    -   Lists/Vectors in Implicit Maps
    
    ```prologos
    ;; Option A: inline
    def user
      :name "Alice"
      :tags @[:admin :active]
      :scores @[95 87 92]
    
    ;; Option B: implicit list with -
    def user
      :name "Alice"
      :tags
        - :admin
        - :active
      :scores
        - 95
        - 87
        - 92
    
    ;; Parses to:
    {:name "Alice" :tags @[:admin :active] :scores @[95 87 92]}
    ```
    
    -   Mixed: Inline and Implicit
    
    ```prologos
    ;; Can mix inline and implicit
    def config
      :server {:host "localhost" :port 8080}  ;; inline map
      :database
        :url "postgres://..."
        :pool-size 10
    
    ;; Parses to:
    {:server {:host "localhost" :port 8080}
     :database {:url "postgres://..." :pool-size 10}}
    ```
    
    -   Expressions as Values
    
    ```prologos
    def computed
      :timestamp [now]
      :sum [+ 1 2 3]
      :greeting [format "Hello, ~a" name]
    
    ;; Parses to:
    {:timestamp [now] :sum [+ 1 2 3] :greeting [format "Hello, ~a" name]}
    ```
    
    -   String Keys (Non-Keyword)
    
    ```prologos
    ;; What if key isn't a keyword?
    def headers
      "Content-Type" "application/json"
      "Authorization" [format "Bearer ~a" token]
    
    ;; Could use different syntax
    def headers
      ="Content-Type" "application/json"    ;; = prefix for string key?
      ="Authorization" [format "Bearer ~a" token]
    ```
    
    &#x2014;
    
    -   Comparison: Explicit vs Implicit
    
    ```prologos
    ;; ========================================
    ;; Explicit (EDN-style)
    ;; ========================================
    
    def user {:name "Alice"
              :age 42
              :address {:city "Springfield"
                        :zip 12345
                        :street {:name "Main"
                                 :type "Ave"
                                 :number 256}}}
    
    ;; ========================================
    ;; Implicit (indentation-based)
    ;; ========================================
    
    def user
      :name "Alice"
      :age 42
      :address
        :city "Springfield"
        :zip 12345
        :street
          :name "Main"
          :type "Ave"
          :number 256
    ```
    
    | Aspect            | Explicit         | Implicit           |
    |----------------- |---------------- |------------------ |
    | Verbosity         | More punctuation | Less punctuation   |
    | Nesting clarity   | Brackets         | Indentation        |
    | Diff-friendliness | Poor (brackets)  | Excellent          |
    | Copy-paste        | Works anywhere   | Whitespace matters |
    | Homoiconic        | Obvious          | After parsing      |
    
    &#x2014;
    
    -   When to Use Which
    
    ```prologos
    ;; ========================================
    ;; Implicit: config, data definitions
    ;; ========================================
    
    def app-config
      :server
        :host "0.0.0.0"
        :port 8080
      :logging
        :level :info
        :format :json
    
    ;; ========================================
    ;; Explicit: inline, small maps
    ;; ========================================
    
    let point = {:x 10 :y 20}
    let user = {:name n :age a}
    [assoc m :key {:nested "value"}]
    
    ;; ========================================
    ;; Both work, user chooses
    ;; ========================================
    ```
    
    &#x2014;
    
    -   Integration with Schema
    
    ```prologos
    ;; ========================================
    ;; Schema definition
    ;; ========================================
    
    schema User
      :name String
      :age Nat
      :address Address
    
    schema Address
      :city String
      :zip Nat
      :street Street
    
    schema Street
      :name String
      :type StreetType
      :number Nat
    
    ;; ========================================
    ;; Instance using implicit map
    ;; ========================================
    
    def alice : User
      :name "Alice"
      :age 42
      :address
        :city "Springfield"
        :zip 12345
        :street
          :name "Main"
          :type :ave
          :number 256
    
    ;; Type-checked against schema!
    ```
    
    &#x2014;
    
    -   Implementation Considerations
    
    -   Reader Phase
    
    ```racket
    ;; Reader tracks indentation stack
    ;; When it sees:
    ;;   :key value   → (cons :key value)
    ;;   :key\n       → (cons :key (read-implicit-map deeper-indent))
    
    (define (read-implicit-map current-indent)
      (let loop ([pairs '()])
        (let ([line-indent (peek-indent)])
          (cond
            [(< line-indent current-indent)
             ;; dedent: done with this map
             (make-map (reverse pairs))]
            [(= line-indent current-indent)
             ;; same level: read key-value
             (let* ([key (read-keyword)]
                    [val (read-value-or-nested)])
               (loop (cons (cons key val) pairs)))]
            [else
             ;; deeper indent: shouldn't happen at map start
             (error "unexpected indent")]))))
    ```
    
    -   AST Representation
    
    ```prologos
    ;; Source
    def user
      :name "Alice"
      :address
        :city "NYC"
    
    ;; AST (same as explicit map)
    [def user
      [map
        [:name "Alice"]
        [:address
          [map
            [:city "NYC"]]]]]
    
    ;; Homoiconic: both syntaxes produce same AST
    ```
    
    &#x2014;
    
    -   Implicit Vec Syntax?
    
    Should we also have implicit vectors?
    
    ```prologos
    ;; ========================================
    ;; Option A: - prefix (YAML-style)
    ;; ========================================
    
    def numbers
      - 1
      - 2
      - 3
    
    ;; Parses to: @[1 2 3]
    
    def users
      -
        :name "Alice"
        :age 30
      -
        :name "Bob"
        :age 25
    
    ;; Parses to: @[{:name "Alice" :age 30} {:name "Bob" :age 25}]
    
    ;; ========================================
    ;; Option B: no implicit vec, use inline
    ;; ========================================
    
    def user
      :name "Alice"
      :scores @[95 87 92]      ;; inline vec
      :tags #{:admin :active}  ;; inline set
    ```
    
    &#x2014;
    
    -   Full Example: Config File
    
    ```prologos
    ;; ========================================
    ;; app-config.prol
    ;; ========================================
    
    def config
      :app
        :name "MyApp"
        :version "1.0.0"
        :env :production
    
      :server
        :host "0.0.0.0"
        :port 8080
        :ssl
          :enabled true
          :cert "/etc/ssl/cert.pem"
          :key "/etc/ssl/key.pem"
    
      :database
        :primary
          :url "postgres://localhost:5432/myapp"
          :pool-size 20
          :timeout 30000
        :replica
          :url "postgres://replica:5432/myapp"
          :pool-size 10
    
      :logging
        :level :info
        :format :json
        :outputs
          - :stdout
          - :file "/var/log/myapp.log"
    
      :features
        :new-dashboard true
        :beta-api false
        :allowed-origins
          - "https://example.com"
          - "https://app.example.com"
    ```
    
    &#x2014;
    
    -   Summary
    
    | Feature              | Syntax             |
    |-------------------- |------------------ |
    | Key-value (leaf)     | `:key value`       |
    | Nested map           | `:key` + indent    |
    | List in implicit map | `- item` or inline |
    | Inline map           | `{:k1 v1 :k2 v2}`  |
    | Mixed                | Freely combine     |
    
    | Benefit         | Description                    |
    |--------------- |------------------------------ |
    | Readable        | No bracket noise               |
    | Diff-friendly   | One key-value per line         |
    | Config-friendly | Feels like YAML/TOML           |
    | Homoiconic      | Parses to same AST as explicit |
    | Type-safe       | Can validate against schema    |
    
    Does this implicit map syntax feel right for Prologos?


<a id="org3095c5e"></a>

## Head Tail List Syntax


<a id="org48aa4d2"></a>

### I'm thinking of adding support for prolog style [E1, \_, E3 | Rest] head|tail style syntax in lists. Would this keep homoiconicity? Does this work well on other collection types? Does it make sense? Maps? \`{:name "Alice" :age 42" | \_}\`. Can be used for unification/structural pattern-matching?

-   Head|Tail Syntax: Analysis

Let me explore this thoroughly.

&#x2014;

-   The Prolog Pattern

```prolog
% Prolog: [H|T] destructures list
append([], Ys, Ys).
append([X|Xs], Ys, [X|Zs]) :- append(Xs, Ys, Zs).

% With holes
[A, _, C | Rest]  % matches list with at least 3 elements
```

&#x2014;

-   Prologos Adaptation

```prologos
;; ========================================
;; List destructuring
;; ========================================

'[H | T]              ;; head and tail
'[A, B | Rest]        ;; first two, then rest
'[A, _, C | Rest]     ;; first, skip, third, rest
'[A, B, C]            ;; exactly three elements

;; ========================================
;; In pattern matching
;; ========================================

match xs
  | '[] -> "empty"
  | '[x] -> "singleton"
  | '[x, y] -> "pair"
  | '[x | rest] -> format "head: ~a, tail length: ~a" x (length rest)

;; ========================================
;; In relations (unification)
;; ========================================

defr append (?xs ?ys ?zs)
  &> (= ?xs '[])
     (= ?zs ?ys)
  &> (= ?xs '[?h | ?t])
     (= ?zs '[?h | ?r])
     (append ?t ?ys ?r)
```

&#x2014;

-   Homoiconicity Check

```prologos
;; ========================================
;; Surface syntax
;; ========================================

'[A, B | Rest]

;; ========================================
;; AST representation
;; ========================================

;; Option A: Special cons-pattern node
[list-pattern A B [rest Rest]]

;; Option B: Nested cons
[cons A [cons B Rest]]

;; Option C: Splice-like syntax
[list A B [splice Rest]]

;; ========================================
;; Quoting behavior
;; ========================================

$'[A, B | Rest]
;; Should produce:
[quote [list-pattern A B [rest Rest]]]

;; ========================================
;; Is it homoiconic?
;; ========================================

;; YES, if:
;; 1. The | syntax desugars to a consistent AST node
;; 2. That node can be quoted, manipulated, evaluated
;; 3. Round-trip works: parse → AST → print → same syntax
```

&#x2014;

-   Vec (RRB-Tree) Considerations

```prologos
;; ========================================
;; Does head|tail make sense for Vec?
;; ========================================

@[A, B | Rest]

;; Semantically: first two elements, rest as Vec

;; ========================================
;; Problem: Vec is not cons-based
;; ========================================

;; List: '[H | T] is O(1) - just pointer to cons cell
;; Vec:  @[H | T] is O(log n) - must slice

;; ========================================
;; But still useful for pattern matching!
;; ========================================

match vec
  | @[] -> "empty"
  | @[x] -> "singleton"
  | @[x | rest] -> process x rest

;; Compiler generates:
match vec
  | (if (= 0 (length vec)) ...) -> "empty"
  | (if (= 1 (length vec)) (let x = (nth vec 0)) ...) -> "singleton"
  | (let x = (nth vec 0)
         rest = (slice vec 1))
    -> (process x rest)

;; ========================================
;; Performance caveat
;; ========================================

;; User should know:
;; - '[H | T] on List: O(1)
;; - @[H | T] on Vec: O(log n) for slice

;; Maybe warn? Or just document?
```

&#x2014;

-   Map Destructuring

```prologos
;; ========================================
;; What would {... | Rest} mean?
;; ========================================

{:name "Alice" :age 42 | Rest}

;; Possible interpretations:

;; A: Extract specified keys, Rest = remaining keys
{:name n :age a | Rest}
;; n = "Alice", a = 42, Rest = {:other-key "value" ...}

;; B: Match these keys, ignore rest (like Elixir)
{:name n :age a | _}
;; n = "Alice", a = 42, don't bind rest

;; ========================================
;; This is actually useful!
;; ========================================

match user
  | {:name n :age a | _} -> format "~a is ~a years old" n a
  | {:name n | _} -> format "~a (age unknown)" n
  | _ -> "unknown user"

;; ========================================
;; In relations
;; ========================================

defr adult? (?user)
  &> (= ?user {:age ?a | _})
     (>= ?a 18)

defr named? (?user ?name)
  &> (= ?user {:name ?name | _})
```

&#x2014;

-   Syntax Variations

```prologos
;; ========================================
;; Option A: | for all collections
;; ========================================

'[a, b | rest]        ;; list
@[a, b | rest]        ;; vec
{:k v | rest}         ;; map

;; ========================================
;; Option B: Different syntax per collection
;; ========================================

'[a, b | rest]        ;; list (Prolog-style)
@[a, b .. rest]       ;; vec (slice-like)
{:k v, ... rest}      ;; map (spread-like)

;; ========================================
;; Option C: | everywhere (consistent)
;; ========================================

;; Use | uniformly, semantics differ by type
;; List: cons/tail
;; Vec: slice
;; Map: split by keys
```

&#x2014;

-   Unification Semantics

```prologos
;; ========================================
;; List unification
;; ========================================

(= '[1, 2, 3] '[?h | ?t])
;; ?h = 1, ?t = '[2, 3]

(= '[1, 2, 3] '[?a, ?b | ?rest])
;; ?a = 1, ?b = 2, ?rest = '[3]

(= '[1, 2] '[?a, ?b, ?c | ?rest])
;; FAIL: list too short

;; ========================================
;; Vec unification
;; ========================================

(= @[1, 2, 3] @[?h | ?t])
;; ?h = 1, ?t = @[2, 3]

;; ========================================
;; Map unification
;; ========================================

(= {:name "Alice" :age 42} {:name ?n | ?rest})
;; ?n = "Alice", ?rest = {:age 42}

(= {:name "Alice" :age 42} {:name ?n :age ?a | _})
;; ?n = "Alice", ?a = 42

(= {:name "Alice"} {:name ?n :age ?a | _})
;; FAIL: no :age key (unless ?a is optional?)

;; ========================================
;; Partial map matching (with optional)
;; ========================================

(= {:name "Alice"} {:name ?n :age (?a :default nil) | _})
;; ?n = "Alice", ?a = nil

;; Or use different syntax for optional:
(= {:name "Alice"} {:name ?n :age? ?a | _})
;; ?n = "Alice", ?a = nil
```

&#x2014;

-   Pattern Matching Integration

```prologos
;; ========================================
;; Full pattern matching syntax
;; ========================================

match expr
  ;; Literal
  | 42 -> "forty-two"

  ;; Variable
  | x -> use x

  ;; List patterns
  | '[] -> "empty list"
  | '[x] -> "singleton"
  | '[x, y] -> "pair"
  | '[x | xs] -> "cons"
  | '[_, _, z | _] -> "third element"

  ;; Vec patterns
  | @[] -> "empty vec"
  | @[x] -> "singleton vec"
  | @[x | xs] -> "head and rest"

  ;; Map patterns
  | {} -> "empty map"
  | {:type :user :name n | _} -> "user named ~a" n
  | {:type :admin | rest} -> "admin with ~a" rest
  | {| _} -> "any map"  ;; or just `{_}`?

  ;; Nested
  | {:users '[first | _] | _} -> "has users, first is ~a" first

  ;; With guards
  | '[x | _] if (> x 0) -> "starts with positive"
```

&#x2014;

-   AST Representation

```prologos
;; ========================================
;; List pattern AST
;; ========================================

;; Surface: '[a, b | rest]
;; AST:
[list-pattern
  [elements a b]
  [rest rest]]

;; Surface: '[a, b, c]
;; AST:
[list-pattern
  [elements a b c]
  [rest nil]]  ;; no rest = exact match

;; ========================================
;; Vec pattern AST
;; ========================================

;; Surface: @[a, b | rest]
;; AST:
[vec-pattern
  [elements a b]
  [rest rest]]

;; ========================================
;; Map pattern AST
;; ========================================

;; Surface: {:name n :age a | rest}
;; AST:
[map-pattern
  [entries [:name n] [:age a]]
  [rest rest]]

;; Surface: {:name n | _}
;; AST:
[map-pattern
  [entries [:name n]]
  [rest _]]  ;; wildcard rest

;; ========================================
;; Quoting preserves structure
;; ========================================

$'[a | b]
;; => [list-pattern [elements a] [rest b]]

${:k v | r}
;; => [map-pattern [entries [:k v]] [rest r]]
```

&#x2014;

-   Implementation Considerations

```racket
;; ========================================
;; Pattern compilation
;; ========================================

(define (compile-pattern pat)
  (match pat
    ;; List with rest
    [`(list-pattern (elements ,elems ...) (rest ,rest-var))
     (define n (length elems))
     `(and (list? val)
           (>= (length val) ,n)
           ,@(for/list ([e elems] [i (in-naturals)])
               (compile-pattern-at e `(list-ref val ,i)))
           ,(if rest-var
                `(let ([,rest-var (drop val ,n)]) #t)
                `(= (length val) ,n)))]

    ;; Vec with rest
    [`(vec-pattern (elements ,elems ...) (rest ,rest-var))
     (define n (length elems))
     `(and (vec? val)
           (>= (vec-length val) ,n)
           ,@(for/list ([e elems] [i (in-naturals)])
               (compile-pattern-at e `(vec-ref val ,i)))
           ,(if rest-var
                `(let ([,rest-var (vec-slice val ,n)]) #t)
                `(= (vec-length val) ,n)))]

    ;; Map with rest
    [`(map-pattern (entries ,entries ...) (rest ,rest-var))
     (define keys (map first entries))
     `(and (map? val)
           ,@(for/list ([e entries])
               (match-define (list k v) e)
               `(let ([,v (map-ref val ',k)])
                  ,(compile-pattern v v)))
           ,(cond
              [(eq? rest-var '_) #t]
              [rest-var `(let ([,rest-var (map-dissoc-keys val ',keys)]) #t)]
              [else `(= (map-count val) ,(length entries))]))]))
```

&#x2014;

-   Summary

| Collection | Syntax           | Semantics           | Cost     |
|---------- |---------------- |------------------- |-------- |
| List       | `'[h \vert t]`   | cons destructure    | O(1)     |
| Vec        | `@[h \vert t]`   | head + slice        | O(log n) |
| Map        | `{:k v \vert r}` | extract keys + rest | O(k)     |

| Question                   | Answer                               |
|-------------------------- |------------------------------------ |
| Homoiconic?                | Yes, desugars to pattern AST nodes   |
| Works for all collections? | Yes, with type-appropriate semantics |
| Good for pattern matching? | Yes, very expressive                 |
| Good for unification?      | Yes, natural fit for relations       |
| Performance concerns?      | Vec slice is O(log n), document this |
| Map rest semantics?        | Extract named keys, rest = remaining |

```prologos
;; ========================================
;; Final syntax
;; ========================================

;; Lists
'[h | t]              ;; head, tail
'[a, b | rest]        ;; first two, rest
'[a, _, c | _]        ;; first, skip, third, ignore rest

;; Vecs
@[h | t]              ;; head, rest (slice)
@[a, b | rest]        ;; first two, rest

;; Maps
{:key val | rest}     ;; extract key, rest = remaining
{:k1 v1 :k2 v2 | _}   ;; extract multiple, ignore rest
{| _}                 ;; match any map (or just `{_}`)

;; In match
match data
  | '[x | xs] -> ...
  | @[x, y | _] -> ...
  | {:name n | _} -> ...

;; In relations
defr member (?x ?xs)
  &> (= ?xs '[?x | _])
  &> (= ?xs '[_ | ?rest]) (member ?x ?rest)
```

```prologos




```


<a id="orgac257de"></a>

## Range Syntax


<a id="org8ed6014"></a>

### I'm also thinking of supporting "Range Syntax" for lists and vectors. '[1..5] expands to '[1 2 3 4 5]; also '[1.10 :by 2] expands to '[1 3 5 7 9], '[10..0 :by -2] expands to '[10 8 6 4 2 0], and so on. Should also work on vectors, lazy lists?

-   Range Syntax for Collections

This is a great ergonomic addition. Let me explore the design space.

&#x2014;

-   Core Syntax

```prologos
;; ========================================
;; Basic range: start..end (inclusive)
;; ========================================

'[1..5]           ;; => '[1 2 3 4 5]
@[1..5]           ;; => @[1 2 3 4 5]
~[1..5]           ;; => ~[1 2 3 4 5] (lazy)

;; ========================================
;; With step: start..end :by step
;; ========================================

'[1..10 :by 2]    ;; => '[1 3 5 7 9]
'[10..1 :by -2]   ;; => '[10 8 6 4 2]
@[0..100 :by 10]  ;; => @[0 10 20 30 40 50 60 70 80 90 100]

;; ========================================
;; Exclusive end: start..<end
;; ========================================

'[1..<5]          ;; => '[1 2 3 4]
@[0..<10]         ;; => @[0 1 2 3 4 5 6 7 8 9]
'[0..<10 :by 2]   ;; => '[0 2 4 6 8]

;; ========================================
;; Infinite (lazy only)
;; ========================================

~[1..]            ;; => ~[1 2 3 4 5 ...] (infinite)
~[0.. :by 2]      ;; => ~[0 2 4 6 8 ...] (infinite evens)
~[10.. :by -1]    ;; => ~[10 9 8 7 6 ...] (infinite countdown)
```

&#x2014;

-   Syntax Variations

| Syntax        | Meaning          | Result                   |
|------------- |---------------- |------------------------ |
| `1..5`        | 1 to 5 inclusive | 1, 2, 3, 4, 5            |
| `1..<5`       | 1 to 5 exclusive | 1, 2, 3, 4               |
| `1..5 :by 2`  | 1 to 5 step 2    | 1, 3, 5                  |
| `5..1 :by -1` | 5 down to 1      | 5, 4, 3, 2, 1            |
| `1..`         | 1 to infinity    | 1, 2, 3, &#x2026; (lazy) |

&#x2014;

-   Collection Type Determines Behavior

```prologos
;; ========================================
;; List '[...] - eager, linked
;; ========================================

'[1..5]           ;; eager evaluation, linked list
'[1..1000000]     ;; builds entire list (expensive!)

;; ========================================
;; Vec @[...] - eager, indexed
;; ========================================

@[1..5]           ;; eager evaluation, vector
@[1..1000000]     ;; builds entire vector (expensive!)

;; ========================================
;; Seq ~[...] - lazy, streaming
;; ========================================

~[1..5]           ;; lazy, computed on demand
~[1..1000000]     ;; cheap! only computed as needed
~[1..]            ;; infinite! only possible with lazy

;; ========================================
;; Set #{...} - eager, unique (if meaningful)
;; ========================================

#{1..5}           ;; => #{1 2 3 4 5}
;; Note: step must not create duplicates
```

&#x2014;

-   Desugaring

```prologos
;; ========================================
;; Surface syntax desugars to range calls
;; ========================================

'[1..5]
;; => [into '[] [range 1 5]]

@[1..10 :by 2]
;; => [into @[] [range 1 10 :by 2]]

~[1..]
;; => [range-lazy 1 inf]

'[1..<5]
;; => [into '[] [range-exclusive 1 5]]

;; ========================================
;; Core range functions
;; ========================================

spec range
  | Nat Nat -> Seq Nat                    ;; range 1 5
  | Nat Nat :by Int -> Seq Int            ;; range 1 10 :by 2
  | Nat -> Seq Nat                        ;; range 1 (infinite)

spec range-exclusive
  | Nat Nat -> Seq Nat
  | Nat Nat :by Int -> Seq Int
```

&#x2014;

-   Edge Cases

```prologos
;; ========================================
;; Empty ranges
;; ========================================

'[5..1]           ;; => '[] (empty, start > end with positive step)
'[1..5 :by -1]    ;; => '[] (empty, wrong direction)

;; ========================================
;; Single element
;; ========================================

'[5..5]           ;; => '[5]
'[5..<5]          ;; => '[] (exclusive, empty)

;; ========================================
;; Type inference
;; ========================================

'[1..5]           ;; Nat range
'[-5..5]          ;; Int range (negative start)
'[1.5..5.5]       ;; Rat range? Or error?

;; Recommendation: integer ranges only for simplicity
;; Use explicit for non-integer: [range 1.5 5.5 :by 0.5]

;; ========================================
;; Variables in ranges
;; ========================================

'[1..n]           ;; range from 1 to n
@[start..end :by step]  ;; fully parameterized
~[x..]            ;; infinite from x

;; ========================================
;; Expressions in ranges
;; ========================================

'[1..[length xs]]        ;; range to length of xs
@[[+ 1 start]..[- end 1]]  ;; computed bounds
```

&#x2014;

-   Implementation

```racket
;; ========================================
;; Reader/Parser Phase
;; ========================================

;; Detect range syntax in collection literals
;; '[1..5]  =>  (list-from-range (range 1 5 #:inclusive #t))
;; @[1..5]  =>  (vec-from-range (range 1 5 #:inclusive #t))
;; ~[1..5]  =>  (range-lazy 1 5)

(define (parse-collection-literal sigil contents)
  (match contents
    ;; Range pattern: start..end or start..<end
    [(list (? range-expr? r))
     (desugar-range sigil r)]

    ;; Range with step: start..end :by step
    [(list (? range-expr? r) ':by step)
     (desugar-range sigil r step)]

    ;; Normal collection
    [elements
     (make-collection sigil elements)]))

(define (range-expr? e)
  (and (symbol? e)
       (or (regexp-match? #rx"\\.\\." (symbol->string e))
           (regexp-match? #rx"\\.\\.<" (symbol->string e)))))

;; ========================================
;; Range Function (Lazy Core)
;; ========================================

(define (range start end #:by [step 1] #:inclusive [incl #t])
  (define cmp (if (positive? step) <= >=))
  (define limit (if incl end (- end (sgn step))))

  (lazy-seq
    (if (cmp start limit)
        (cons start (range (+ start step) end #:by step #:inclusive incl))
        '())))

;; ========================================
;; Infinite Range
;; ========================================

(define (range-infinite start #:by [step 1])
  (lazy-seq
    (cons start (range-infinite (+ start step) #:by step))))

;; ========================================
;; Materialization
;; ========================================

(define (into-list seq)
  (if (empty-seq? seq)
      '()
      (cons (seq-first seq) (into-list (seq-rest seq)))))

(define (into-vec seq)
  (list->vector (into-list seq)))
```

&#x2014;

-   Full Examples

```prologos
;; ========================================
;; Common Use Cases
;; ========================================

;; Indices
@[0..<[length xs]]        ;; @[0 1 2 ... n-1]

;; Enumerate with index
|> @[0..<[length xs]]
  map (fn [i] (pair i (nth xs i)))

;; Countdown
'[10..1 :by -1]           ;; '[10 9 8 7 6 5 4 3 2 1]

;; Alphabet (if char ranges supported)
'[:a..:z]                 ;; '[:a :b :c ... :z]

;; ========================================
;; With Pipes and Transducers
;; ========================================

;; First 10 squares
|> ~[1..]
  map [* _ _]
  take 10
  into @[]
;; => @[1 4 9 16 25 36 49 64 81 100]

;; Sum of even numbers up to 100
|> ~[2..100 :by 2]
  reduce + 0
;; => 2550

;; Fizzbuzz
|> ~[1..100]
  map (fn [n]
        cond
          [divisible? n 15] -> "FizzBuzz"
          [divisible? n 3]  -> "Fizz"
          [divisible? n 5]  -> "Buzz"
          else              -> [str n])
  into @[]

;; ========================================
;; Nested Ranges
;; ========================================

;; Multiplication table
|> @[1..10]
  map (fn [x]
        |> @[1..10]
          map [* x _])

;; Coordinates
|> ~[0..<width]
  mapcat (fn [x]
           |> ~[0..<height]
             map (fn [y] (point x y)))
  into @[]

;; ========================================
;; Lazy Infinite
;; ========================================

;; Primes (using lazy)
def primes
  let sieve = fn [s]
    let p = first s
    ~[p | sieve (filter [not [divisible? _ p]] (rest s))]
  sieve ~[2..]

take 10 primes
;; => ~[2 3 5 7 11 13 17 19 23 29]

;; Fibonacci (using lazy)
def fibs
  ~[0 1 | map + fibs (rest fibs)]

take 10 fibs
;; => ~[0 1 1 2 3 5 8 13 21 34]
```

&#x2014;

-   Syntax Summary

| Syntax           | Collection | Meaning              |
|---------------- |---------- |-------------------- |
| `'[1..5]`        | List       | Eager, inclusive     |
| `@[1..5]`        | Vec        | Eager, inclusive     |
| `~[1..5]`        | Seq        | Lazy, inclusive      |
| `'[1..<5]`       | List       | Eager, exclusive     |
| `'[1..10 :by 2]` | List       | Eager, with step     |
| `~[1..]`         | Seq        | Lazy, infinite       |
| `~[1.. :by 2]`   | Seq        | Lazy, infinite, step |

&#x2014;

-   Design Decisions

| Decision               | Choice                 | Rationale                 |
|---------------------- |---------------------- |------------------------- |
| Inclusive vs exclusive | `..` vs `..<` syntax   | Clear, familiar (Rust)    |
| Step syntax            | `:by step`             | Keyword arg, readable     |
| Infinite allowed?      | Only for `~[]`         | Prevents accidental hang  |
| Empty range behavior   | Empty collection       | No error, just empty      |
| Non-integer ranges     | Explicit function only | Keep syntax simple        |
| Variables in ranges    | Allowed                | Useful for dynamic bounds |

Does this range syntax design feel right for Prologos?


<a id="org1382afb"></a>

### Oh! Another idea is to include predicate functions as filter with lazy lists \`~[1.. even?]\`, \`~[1.. [< \_ 100]\`

-   Predicate Filters in Range Syntax

This is elegant! It makes lazy sequences read like set-builder notation.

&#x2014;

-   The Concept

```prologos
;; ========================================
;; Set-builder notation feel
;; ========================================

;; Math: { x ∈ ℕ | x is even }
;; Prologos:
~[1.. even?]              ;; => ~[2 4 6 8 10 ...]

;; Math: { x ∈ ℕ | x < 100 }
;; Prologos:
~[1.. [< _ 100]]          ;; => ~[1 2 3 ... 99]

;; Math: { x ∈ ℕ | x is even ∧ x < 100 }
;; Prologos:
~[1.. even? [< _ 100]]    ;; => ~[2 4 6 ... 98]
```

&#x2014;

-   Extended Syntax

```prologos
;; ========================================
;; Basic: range with predicate
;; ========================================

~[1.. even?]              ;; infinite evens from 1
~[1.. odd?]               ;; infinite odds from 1
~[1.. prime?]             ;; infinite primes from 1

;; ========================================
;; With termination predicate
;; ========================================

~[1.. [< _ 100]]          ;; 1..99 (stops when predicate fails)
~[1.. [<= _ 100]]         ;; 1..100

;; ========================================
;; Multiple predicates (conjunction)
;; ========================================

~[1.. even? [< _ 100]]    ;; even numbers under 100
~[1.. [> _ 10] [< _ 50] prime?]  ;; primes between 10 and 50

;; ========================================
;; With step
;; ========================================

~[1.. :by 3 [< _ 100]]    ;; 1, 4, 7, 10, ... under 100
~[0.. :by 2 [< _ 20]]     ;; 0, 2, 4, ... 18

;; ========================================
;; Filter vs Terminator distinction?
;; ========================================

;; Option A: All predicates are filters (keeps going)
~[1.. even?]              ;; skips odds, never stops

;; Option B: Last predicate can be terminator
~[1.. even? [< _ 100]]    ;; filter even, stop at 100

;; Option C: Explicit distinction
~[1.. :where even? :until [>= _ 100]]
~[1.. :filter even? :take-while [< _ 100]]
```

&#x2014;

-   Syntax Options

-   Option A: Positional (Simple)

```prologos
;; All trailing expressions are filters
~[start.. pred1 pred2 pred3]

~[1.. even?]              ;; filter: keep evens
~[1.. [< _ 100]]          ;; filter: keep < 100 (but infinite!)

;; Problem: [< _ 100] as filter never terminates!
;; It keeps checking forever, just returns nothing after 99
```

-   Option B: Distinguished Terminator

```prologos
;; :while for termination, :where for filter
~[start.. :while term-pred :where filter-pred]

~[1.. :while [< _ 100]]              ;; 1..99
~[1.. :while [< _ 100] :where even?] ;; 2,4,6,...98
~[1.. :where even?]                  ;; infinite evens

;; Or reversed order
~[1.. :where even? :while [< _ 100]]
```

-   Option C: Take-While is Default for Comparison Predicates

```prologos
;; Heuristic: comparison predicates terminate, others filter

~[1.. [< _ 100]]          ;; terminates (comparison detected)
~[1.. even?]              ;; filters (not a comparison)
~[1.. even? [< _ 100]]    ;; filters even, terminates at 100

;; Smart desugaring based on predicate shape
;; [< _ n], [<= _ n], [> _ n], [>= _ n] → take-while
;; Other predicates → filter
```

-   Option D: Explicit Keywords (Most Clear)

```prologos
;; Be explicit about intent
~[1..]                                ;; infinite naturals
~[1.. | even?]                        ;; infinite evens (filter)
~[1.. | [< _ 100]]                    ;; 1..99 (take-while)
~[1.. | even?, [< _ 100]]             ;; even AND < 100

;; The | separates range from predicates
;; Comma combines predicates (conjunction)
```

&#x2014;

-   My Recommendation: Option D (Pipe Separator)

```prologos
;; ========================================
;; Syntax: ~[range | predicates]
;; ========================================

;; Infinite with filter
~[1.. | even?]            ;; infinite evens

;; Bounded (take-while behavior)
~[1.. | [< _ 100]]        ;; 1 to 99

;; Combined (filter AND bound)
~[1.. | even?, [< _ 100]] ;; even numbers under 100

;; Multiple filters
~[1.. | [> _ 10], [< _ 50], prime?]  ;; primes between 10 and 50

;; With step
~[0.. :by 2 | [< _ 20]]   ;; 0, 2, 4, ..., 18

;; ========================================
;; The | reads as "such that" or "where"
;; ========================================

;; ~[1.. | even?]
;; "sequence from 1 WHERE even"

;; ~[1.. | [< _ 100]]
;; "sequence from 1 WHERE less than 100"
```

&#x2014;

-   Semantics: Filter vs Take-While

```prologos
;; ========================================
;; Key question: when does predicate terminate?
;; ========================================

;; Option 1: All predicates are filters (lazy, may not terminate)
~[1.. | even?]
;; Keeps generating, skips odds
;; Never terminates on its own

;; Option 2: Comparison predicates auto-terminate
~[1.. | [< _ 100]]
;; Generates 1, 2, 3... stops at 100
;; Because [< _ 100] fails, we stop (take-while)

;; ========================================
;; Recommendation: Smart behavior
;; ========================================

;; If ALL predicates are monotonic-failing on ascending sequence,
;; use take-while semantics (terminates)

;; Otherwise, use filter semantics (may not terminate)

;; Monotonic-failing: once false, stays false
;; [< _ 100]: once x >= 100, always false → terminates
;; even?: alternates true/false → filters

;; Combined:
~[1.. | even?, [< _ 100]]
;; even? is filter (non-monotonic)
;; [< _ 100] is terminator (monotonic)
;; Result: filter evens, stop at 100
```

&#x2014;

-   Desugaring

```prologos
;; ========================================
;; Simple range
;; ========================================

~[1..5]
;; => [range 1 5]

;; ========================================
;; Infinite range
;; ========================================

~[1..]
;; => [range-from 1]

;; ========================================
;; With filter predicates
;; ========================================

~[1.. | even?]
;; => [filter even? [range-from 1]]

~[1.. | even?, odd?]
;; => [filter (both even? odd?) [range-from 1]]
;; (always empty, but valid)

;; ========================================
;; With terminating predicate
;; ========================================

~[1.. | [< _ 100]]
;; => [take-while [< _ 100] [range-from 1]]

;; ========================================
;; Mixed
;; ========================================

~[1.. | even?, [< _ 100]]
;; => [take-while [< _ 100] [filter even? [range-from 1]]]
;; Or equivalently:
;; => [filter even? [take-while [< _ 100] [range-from 1]]]
;; (order matters for efficiency!)

;; Optimal: take-while OUTER (stops generation)
;; => [take-while [< _ 100] [filter even? [range-from 1]]]
```

&#x2014;

-   Full Examples

```prologos
;; ========================================
;; Mathematical sequences
;; ========================================

;; Evens under 100
~[2.. :by 2 | [< _ 100]]
;; => ~[2 4 6 8 ... 98]

;; Alternative
~[1.. | even?, [< _ 100]]
;; => ~[2 4 6 8 ... 98]

;; Primes under 1000
~[2.. | prime?, [< _ 1000]]
;; => ~[2 3 5 7 11 ... 997]

;; Squares under 500
~[1.. | [< [* _ _] 500]]
;; Hmm, predicate uses transformed value
;; Maybe: ~[1.. | [< (square _) 500]]
;; Or use pipe:
|> ~[1..]
  map square
  take-while [< _ 500]

;; ========================================
;; Fizzbuzz numbers
;; ========================================

;; Numbers divisible by 3 or 5
~[1..100 | (either [divisible? _ 3] [divisible? _ 5])]

;; ========================================
;; Working with data
;; ========================================

;; IDs of active users
~[1.. | [< _ max-user-id], (fn [id] (active? (get-user id)))]

;; ========================================
;; Nested predicates
;; ========================================

;; Numbers where digit sum is even
~[1.. | (fn [n] (even? (digit-sum n))), [< _ 1000]]
;; => ~[2 4 6 8 11 13 15 17 19 20 22 ...]

;; ========================================
;; Combining with pipes
;; ========================================

|> ~[1.. | prime?]
  take 100
  reduce + 0
;; Sum of first 100 primes

|> ~[1.. | [< _ 1000000], [= 0 [mod _ 7]]]
  filter [= 0 [mod _ 13]]
  take 10
;; First 10 numbers divisible by both 7 and 13
```

&#x2014;

-   Works Across Collection Types?

```prologos
;; ========================================
;; Lazy (natural fit)
;; ========================================

~[1.. | even?]            ;; infinite lazy evens

;; ========================================
;; Eager collections (must be bounded!)
;; ========================================

'[1.. | even?, [< _ 20]]  ;; '[2 4 6 8 10 12 14 16 18]
@[1.. | even?, [< _ 20]]  ;; @[2 4 6 8 10 12 14 16 18]

;; Error or warning for unbounded eager:
'[1.. | even?]            ;; ERROR: unbounded range in eager collection
@[1.. | even?]            ;; ERROR: unbounded range in eager collection

;; ========================================
;; Alternative: bounded range with filter
;; ========================================

'[1..100 | even?]         ;; OK: bounded range, filter applied
@[1..1000 | prime?]       ;; OK: bounded range, filter applied
```

&#x2014;

-   Syntax Summary

| Syntax          | Meaning                  |
|--------------- |------------------------ |
| `~[1..]`        | Infinite naturals from 1 |
| =~[1.. \\       | even?]=                  | Infinite evens                |
| =~[1.. \\       | [< \_ 100]]=             | 1 to 99 (terminates)          |
| =~[1.. \\       | even?, [< \_ 100]]=      | Evens under 100               |
| =~[1.. :by 2 \\ | [< \_ 50]]=              | 1, 3, 5, &#x2026; 49          |
| ='[1..100 \\    | prime?]=                 | Primes up to 100 (eager list) |
| =@[1..50 \\     | odd?]=                   | Odd numbers 1-49 (eager vec)  |

&#x2014;

-   Grammar

```
RangeExpr ::= '[' Start RangeOp End? Step? Preds? ']'

Start     ::= Expr
RangeOp   ::= '..' | '..<'
End       ::= Expr | ε (infinite)
Step      ::= ':by' Expr
Preds     ::= '|' Pred (',' Pred)/
Pred      ::= Expr  ;; must be A -> Bool
```

&#x2014;

-   Final Comparison

```prologos
;; ========================================
;; Without predicate syntax
;; ========================================

|> ~[1..]
  filter even?
  take-while [< _ 100]
  into @[]

;; ========================================
;; With predicate syntax
;; ========================================

@[1.. | even?, [< _ 100]]

;; Much cleaner!
;; Reads like: "integers from 1 where even and less than 100"
```

This feels like a natural extension of the range syntax. The `|` separator clearly marks "such that" and multiple predicates combine naturally.

Does this feel right?


<a id="org56db35b"></a>

### Two issues with the pipe operator to raise: 1. Clarify, does this prevent the nontermination issue? 2. We also have prolog [head | tail] syntax planned out, which uses the same \`|\`&#x2026; but because the range syntax uses .., would the set-builder like \`|\` still work?

-   Addressing Pipe Ambiguity and Non-Termination

Let me tackle both issues.

&#x2014;

-   Issue 1: Non-Termination

The `|` syntax alone does *not* prevent non-termination. Let me clarify:

```prologos
;; ========================================
;; Problem: filter never terminates on infinite seq
;; ========================================

~[1.. | even?]
;; This is FINE: generates evens lazily forever
;; Consumer decides when to stop: (take 10 ~[1.. | even?])

~[1.. | [> _ 100]]
;; This is PROBLEMATIC as filter!
;; Generates 1, 2, 3... filters out 1-100... then emits 101, 102...
;; Actually terminates (eventually emits values)
;; But: (take 1 ~[1.. | [> _ 100]]) must skip 100 elements first

~[1.. | [< _ 100]]
;; As FILTER: generates 1-99, then infinite stream of nothing
;; Lazily "works" but never emits after 99
;; (take 200 ~[1.. | [< _ 100]]) hangs after 99 elements!

;; ========================================
;; The semantic question
;; ========================================

;; Is [< _ 100] a:
;;   A) FILTER: keep elements where pred is true (may produce gaps)
;;   B) TAKE-WHILE: stop when pred becomes false (terminates)

;; For bounded iteration, we want TAKE-WHILE
;; For sparse selection, we want FILTER
```

-   Solution: Distinguish Filter from Terminator

```prologos
;; ========================================
;; Option A: Separate syntax
;; ========================================

;; | for filter (keeps checking forever)
~[1.. | even?]            ;; filter: infinite evens

;; || or |! or |. for take-while (stops when false)
~[1.. || [< _ 100]]       ;; take-while: 1..99
~[1.. |. [< _ 100]]       ;; alternative
~[1.. |! [< _ 100]]       ;; alternative

;; Combined
~[1.. | even? || [< _ 100]]  ;; filter evens, stop at 100

;; ========================================
;; Option B: Keywords
;; ========================================

~[1.. :where even?]                    ;; filter
~[1.. :while [< _ 100]]                ;; take-while
~[1.. :where even? :while [< _ 100]]   ;; both

;; ========================================
;; Option C: Smart default based on position
;; ========================================

;; Last predicate is take-while, others are filter
~[1.. | even?, [< _ 100]]
;;       ^^^^^ filter
;;              ^^^^^^^^^^^ take-while (last)

;; Single predicate needs explicit marker for take-while
~[1.. | even?]            ;; filter (infinite)
~[1.. |. [< _ 100]]       ;; take-while (terminates)
```

-   My Recommendation: Keywords for Clarity

```prologos
;; ========================================
;; Clear, unambiguous syntax
;; ========================================

;; :where = filter (may not terminate)
~[1.. :where even?]       ;; infinite evens

;; :while = take-while (terminates when false)
~[1.. :while [< _ 100]]   ;; 1..99, terminates

;; Both
~[1.. :where even? :while [< _ 100]]  ;; evens under 100

;; ========================================
;; This is explicit about behavior
;; ========================================

;; No ambiguity about termination
;; Reader knows exactly what to expect
```

&#x2014;

-   Issue 2: Conflict with Prolog Head|Tail Syntax

```prologos
;; ========================================
;; Prolog-style list pattern
;; ========================================

'[head | tail]            ;; destructure: first element and rest

match xs
  | '[h | t] -> ...       ;; head and tail
  | '[] -> ...            ;; empty

;; ========================================
;; Proposed range predicate
;; ========================================

~[1.. | even?]            ;; range with predicate

;; ========================================
;; Are these ambiguous?
;; ========================================
```

-   Analyzing the Conflict

```prologos
;; ========================================
;; Context 1: Pattern matching (in match/destructure)
;; ========================================

match xs
  | '[h | t] -> ...

;; Here '[h | t] is a PATTERN
;; h and t are binding variables
;; | means "cons" or "head|tail"

;; ========================================
;; Context 2: Range literal (in expression position)
;; ========================================

let evens = ~[1.. | even?]

;; Here ~[1.. | even?] is an EXPRESSION
;; 1.. is a range
;; | even? is a predicate clause

;; ========================================
;; Key difference: .. in range
;; ========================================

'[h | t]         ;; NO dots, this is pattern
~[1.. | even?]   ;; HAS dots, this is range

'[1 | rest]      ;; Pattern: 1 consed onto rest
~[1.. | even?]   ;; Range: 1.. with filter even?

;; The .. makes it unambiguous!
```

-   When Could It Be Ambiguous?

```prologos
;; ========================================
;; Potentially confusing cases
;; ========================================

;; Case 1: Range without ..
'[1 | rest]               ;; Pattern: cons 1 onto rest
;; vs
'[1 | even?]              ;; ??? Range with filter? Or pattern?

;; If we only allow | filter with .., no ambiguity:
'[1.. | even?]            ;; Range (has ..)
'[1 | rest]               ;; Pattern (no ..)

;; ========================================
;; Case 2: Variable that looks like predicate
;; ========================================

let even? = some-list
'[1 | even?]              ;; Pattern: cons 1 onto even?

;; This is clearly pattern because no ..

;; ========================================
;; Case 3: Bounded range with predicate
;; ========================================

'[1..10 | even?]          ;; Range 1..10, filter even? (has ..)
'[1 | 10]                 ;; Pattern? Cons 1 onto 10? (weird but valid)

;; Still unambiguous: .. triggers range interpretation
```

-   The Rule

```
RULE:
  If collection literal contains .., it's a RANGE expression
  If no .., | means head|tail (cons pattern)

'[1..5]           ;; Range: 1 to 5
'[1.. | even?]    ;; Range: 1.. filtered by even?
'[1..10 | prime?] ;; Range: 1..10 filtered by prime?

'[h | t]          ;; Pattern: head and tail
'[1 | xs]         ;; Pattern: 1 consed onto xs
'[1 2 | rest]     ;; Pattern: 1, 2, then rest
```

&#x2014;

-   Full Syntax Summary

```prologos
;; ========================================
;; Range Syntax (has ..)
;; ========================================

;; Basic
~[1..5]                   ;; 1 to 5
~[1..<5]                  ;; 1 to 4 (exclusive)
~[1..]                    ;; 1 to infinity

;; With step
~[1..10 :by 2]            ;; 1, 3, 5, 7, 9
~[10..1 :by -1]           ;; 10, 9, 8, ..., 1

;; With filter (:where)
~[1.. :where even?]       ;; infinite evens

;; With terminator (:while)
~[1.. :while [< _ 100]]   ;; 1..99

;; Combined
~[1.. :where even? :while [< _ 100]]  ;; evens under 100

;; ========================================
;; Pattern Syntax (no ..)
;; ========================================

'[h | t]                  ;; head and tail
'[a b | rest]             ;; first two and rest
'[x | '[y | z]]           ;; nested destructure

;; In match
match xs
  | '[] -> "empty"
  | '[x] -> "single"
  | '[x | rest] -> "multiple"

;; ========================================
;; NO AMBIGUITY
;; ========================================

;; .. present → range
;; .. absent → pattern (if | present) or literal (if | absent)

'[1 2 3]                  ;; literal list (no .. no |)
'[h | t]                  ;; pattern (no .., has |)
'[1..3]                   ;; range (has ..)
'[1.. :where odd?]        ;; range with filter (has ..)
```

&#x2014;

-   Alternative: Different Syntax for Predicates

If you want to avoid any `|` overloading concern:

```prologos
;; ========================================
;; Option: Use ? for predicates
;; ========================================

~[1..? even?]             ;; range where even?
~[1..? [< _ 100]]         ;; range while < 100

;; ========================================
;; Option: Use // for predicates
;; ========================================

~[1.. // even?]           ;; range where even?
~[1.. // [< _ 100]]       ;; range while < 100

;; ========================================
;; Option: Use :| for predicates
;; ========================================

~[1.. :| even?]           ;; range where even?
~[1.. :| [< _ 100]]       ;; range while < 100

;; ========================================
;; Option: Keywords only (no special symbol)
;; ========================================

~[1.. :where even?]       ;; filter
~[1.. :while [< _ 100]]   ;; take-while
```

&#x2014;

-   Final Recommendation

```prologos
;; ========================================
;; Use keywords for predicate clauses
;; ========================================

;; This avoids ALL ambiguity with head|tail

;; Range with filter
~[1.. :where even?]

;; Range with terminator
~[1.. :while [< _ 100]]

;; Both
~[1.. :where even? :while [< _ 100]]

;; ========================================
;; Head|tail is unchanged
;; ========================================

'[h | t]                  ;; pattern: head and tail

;; ========================================
;; Clear, unambiguous, readable
;; ========================================

;; ~[1.. :where even? :while [< _ 100]]
;; Reads: "lazy seq from 1, WHERE even, WHILE under 100"

;; No conflict with:
;; '[h | t]
;; Reads: "list pattern: head h, tail t"
```

&#x2014;

-   Summary

| Issue                | Solution                                                 |                                              |            |
|-------------------- |-------------------------------------------------------- |-------------------------------------------- |---------- |
| Non-termination      | Distinguish `:where` (filter) from `:while` (terminates) |                                              |            |
| Conflict with head\\ | tail                                                     | `..` triggers range mode; keywords avoid =\\ | = entirely |
| Clarity              | Keywords `:where` and `:while` are explicit              |                                              |            |

Does this resolve both concerns?


<a id="orgfad6532"></a>

### Let's make a short summary of our recommendations for Range Syntax (using keywords on predicates). Be concise, give examples.

-   Range Syntax Summary

&#x2014;

-   Basic Ranges

```prologos
'[1..5]                   ;; '[1 2 3 4 5] (inclusive)
'[1..<5]                  ;; '[1 2 3 4] (exclusive)
@[0..10 :by 2]            ;; @[0 2 4 6 8 10] (with step)
~[1..]                    ;; ~[1 2 3 ...] (infinite, lazy only)
```

&#x2014;

-   With Predicates

```prologos
;; :where = filter (keeps checking)
~[1.. :where even?]                    ;; ~[2 4 6 8 ...] infinite evens

;; :while = take-while (stops when false)
~[1.. :while [< _ 100]]                ;; ~[1 2 3 ... 99] terminates

;; Combined
~[1.. :where even? :while [< _ 100]]   ;; ~[2 4 6 ... 98] evens under 100

;; With step
~[1.. :by 3 :while [< _ 50]]           ;; ~[1 4 7 10 ... 49]
```

&#x2014;

-   Eager Collections (Must Be Bounded)

```prologos
'[1..100 :where prime?]   ;; primes up to 100 (list)
@[1..50 :where odd?]      ;; odd numbers 1-49 (vector)

;; ERROR: unbounded eager
'[1.. :where even?]       ;; Error! Use ~[] for infinite
```

&#x2014;

-   No Conflict with Head|Tail

```prologos
;; .. present → range
~[1.. :where even?]       ;; range with predicate

;; .. absent → pattern
'[h | t]                  ;; head|tail pattern
```

&#x2014;

-   Quick Reference

| Syntax                                | Result                |
|------------------------------------- |--------------------- |
| `'[1..5]`                             | `'[1 2 3 4 5]`        |
| `'[1..<5]`                            | `'[1 2 3 4]`          |
| `@[0..10 :by 2]`                      | `@[0 2 4 6 8 10]`     |
| `~[1..]`                              | Infinite naturals     |
| `~[1.. :where even?]`                 | Infinite evens        |
| `~[1.. :while [< _ 100]]`             | 1 to 99               |
| `~[1.. :where even? :while [< _ 50]]` | Even numbers under 50 |


<a id="org53b1142"></a>

### Let's summarize our syntax conclusions from above for \`|>\` and \`>>\` with default last position piping, with considerations for \`\_\` magic holes. Let's provide concise but full examples to an implementer, and some considerations for implementing this as O(n) automatically at compiler.

-   Pipe and Compose Operators: Syntax Summary

&#x2014;

-   Core Operators

| Operator | Name    | Purpose                                     |
|-------- |------- |------------------------------------------- |
| `\vert>` | Pipe    | Thread value through sequence of operations |
| `>>`     | Compose | Compose functions/transducers left-to-right |

&#x2014;

-   Pipe Operator `|>`

-   Rules

-   Default: pipes to *last argument position*
-   Override: use `_` for explicit position
-   `_` inside `[...]` is a closure hole (different!)
-   `_` bare in pipe step is pipe position

-   Examples

```prologos
;; ========================================
;; Basic: pipes to last position
;; ========================================

|> @[1 2 3 4 5]
  map inc               ;; [map inc @[1 2 3 4 5]]
  filter even?          ;; [filter even? <prev>]
  take 3                ;; [take 3 <prev>]

;; Result: @[2 4 6]

;; ========================================
;; Explicit position with _
;; ========================================

|> user
  get _ :name           ;; [get user :name] (first position)
  str/upper             ;; [str/upper <prev>] (last position)
  str/take 10           ;; [str/take 10 <prev>] (last position)

;; ========================================
;; Closure holes vs pipe position
;; ========================================

|> @[1 2 3 4 5]
  map [+ _ 10]          ;; [+ _ 10] is closure: (fn [x] (+ x 10))
                        ;; piped to last position of map
  filter [> _ 12]       ;; [> _ 12] is closure: (fn [x] (> x 12))
  get-in _ [:0]         ;; bare _ is pipe position

;; ========================================
;; Multi-line with complex transforms
;; ========================================

|> raw-data
  parse-json
  get _ :results        ;; pipe to first
  map _.name            ;; point-free accessor
  filter [str/starts? _ "A"]
  sort
  take 10
  into @[]
```

&#x2014;

-   Compose Operator =>>

-   Rules

-   Composes functions/transducers left-to-right
-   Returns a new function/transducer
-   Used for building reusable transforms

-   Examples

```prologos
;; ========================================
;; Function composition
;; ========================================

def process = >> parse-int inc double str

;; Equivalent to:
;; (fn [x] (str (double (inc (parse-int x)))))

process "5"   ;; => "12"

;; ========================================
;; Transducer composition
;; ========================================

def xf = >>
  map inc
  filter even?
  take 5

;; Apply transducer
into @[] xf @[1 2 3 4 5 6 7 8 9 10]
;; => @[2 4 6 8 10]

transduce xf + 0 @[1 2 3 4 5 6 7 8 9 10]
;; => 30

;; ========================================
;; With point-free accessors
;; ========================================

def extract-names >>
  filter _.active
  map _.profile.name
  distinct

into @[] extract-names users
```

&#x2014;

-   Disambiguation Summary

| Context               | Syntax       | Meaning           |
|--------------------- |------------ |----------------- |
| Bare `_` in pipe step | `get _ :key` | Pipe position     |
| `_` inside `[...]`    | `[+ _ 10]`   | Closure hole      |
| `_.foo`               | `_.name`     | Point-free getter |
| No `_` in pipe step   | `map f`      | Pipes to last arg |

```prologos
;; Unambiguous examples:

|> xs
  map [* _ 2]           ;; _ in [...] = closure hole
  get-in _ [:a :b]      ;; bare _ = pipe position
  filter _.active       ;; _.foo = point-free getter
  take 10               ;; no _ = last position
```

&#x2014;

-   Automatic O(n) Fusion

-   What the Compiler Sees

```prologos
;; User writes:
|> users
  filter _.active
  map _.name
  filter [str/starts? _ "A"]
  take 10
  into @[]
```

-   Compiler Recognition

```
1. Recognize fusible pattern:
   - filter, map, filter, take are all transducer-compatible
   - into is a terminal operation

2. Check all operations are:
   - Stateless (filter, map) or
   - Bounded stateful (take, drop, distinct)
   - No side effects

3. Convert to transducer composition
```

-   Compiler Emits

```prologos
;; Rewrites to:
let xf = >>
  filter _.active
  map _.name
  filter [str/starts? _ "A"]
  take 10

into @[] xf users
```

-   Implementation Considerations

```racket
;; ========================================
;; 1. Identify Fusible Operations
;; ========================================

(define fusible-ops
  '(map filter remove take drop take-while drop-while
    distinct dedupe mapcat flatten partition interpose))

(define terminal-ops
  '(into transduce reduce fold first last nth count))

;; ========================================
;; 2. Pattern Match Pipe Sequence
;; ========================================

(define (analyze-pipe steps)
  (match steps
    ;; All fusible, ends with terminal
    [(list (list (? fusible-op?) _ ...) ...
           (list (? terminal-op?) _ ...))
     'fusible]

    ;; Has non-fusible in middle
    [_ 'not-fusible]))

;; ========================================
;; 3. Rewrite to Transducer
;; ========================================

(define (fuse-pipe input steps)
  (define-values (xf-steps terminal) (split-at-terminal steps))
  (define xf (compose-transducers xf-steps))
  (apply-terminal terminal xf input))

;; ========================================
;; 4. Transducer Composition
;; ========================================

;; Each transducer: (reducer → reducer)
;; Composition is function composition

(define ((map-xf f) rf)
  (λ (acc x) (rf acc (f x))))

(define ((filter-xf pred) rf)
  (λ (acc x) (if (pred x) (rf acc x) acc)))

(define ((take-xf n) rf)
  (define count (box 0))
  (λ (acc x)
    (if (< (unbox count) n)
        (begin (set-box! count (add1 (unbox count)))
               (rf acc x))
        (reduced acc))))

;; ========================================
;; 5. Single-Pass Execution
;; ========================================

(define (transduce xf rf init coll)
  (define xrf (xf rf))  ;; composed reducer
  (for/fold ([acc init])
            ([x coll])
    (define result (xrf acc x))
    (if (reduced? result)
        (reduced-val result)
        result)))
```

&#x2014;

-   Fusion Example: Before and After

```prologos
;; ========================================
;; BEFORE (naive, multi-pass)
;; ========================================

;; Pass 1: filter active
let step1 = filter _.active users    ;; O(n), allocates

;; Pass 2: map name
let step2 = map _.name step1         ;; O(n), allocates

;; Pass 3: filter starts with A
let step3 = filter [...] step2       ;; O(n), allocates

;; Pass 4: take 10
let step4 = take 10 step3            ;; O(n) worst case

;; Pass 5: into vector
let result = into @[] step4          ;; O(n), allocates

;; Total: 5 passes, 4 intermediate collections

;; ========================================
;; AFTER (fused, single-pass)
;; ========================================

;; Single composed transducer
let xf = >> (filter _.active)
            (map _.name)
            (filter [str/starts? _ "A"])
            (take 10)

;; Single pass, no intermediate collections
let result = into @[] xf users

;; Total: 1 pass, 0 intermediate collections
;; Also: early termination at 10 items!
```

&#x2014;

-   Edge Cases

```prologos
;; ========================================
;; NOT fusible: side effects
;; ========================================

|> xs
  map (fn [x] (print x) x)  ;; side effect!
  filter even?

;; Compiler should NOT fuse (order of effects matters)
;; Or: warn user

;; ========================================
;; NOT fusible: non-transducer op in middle
;; ========================================

|> xs
  map inc
  reverse              ;; reverse needs full collection!
  filter even?

;; Cannot fuse across reverse
;; Compiler: fuse before reverse, fuse after, run reverse between

;; ========================================
;; Fusible: stateful but bounded
;; ========================================

|> xs
  distinct             ;; stateful (tracks seen elements)
  take 10              ;; stateful (tracks count)

;; Still fusible! State is per-transducer
```

&#x2014;

-   Full Implementation Skeleton

```racket
;; ========================================
;; pipe-transform : Syntax -> Syntax
;; ========================================

(define (pipe-transform stx)
  (syntax-parse stx
    [(_ init step ...)
     (define steps (syntax->list #'(step ...)))
     (define analyzed (analyze-steps steps))

     (match analyzed
       [(fusible-sequence xf-steps terminal)
        ;; Emit fused version
        #`(let ([xf (compose-xf #,@xf-steps)])
            (#,(terminal-fn terminal) xf #,#'init))]

       [(mixed-sequence segments)
        ;; Emit partially fused
        (emit-mixed segments #'init)]

       [(unfusible-sequence)
        ;; Emit sequential (original semantics)
        (emit-sequential #'init steps)])]))

;; ========================================
;; compose-xf : (Listof Transducer) -> Transducer
;; ========================================

(define (compose-xf . xfs)
  (λ (rf)
    (foldr (λ (xf acc) (xf acc)) rf xfs)))

;; ========================================
;; into : Collection Transducer Collection -> Collection
;; ========================================

(define (into target xf source)
  (define rf (buildable-rf target))     ;; get reducer for target type
  (transduce xf rf (empty target) source))
```

&#x2014;

-   Summary

| Feature          | Syntax                | Notes                  |
|---------------- |--------------------- |---------------------- |
| Pipe to last     | `\vert> x (f) (g)`    | Default                |
| Pipe to position | `\vert> x (get _ :k)` | Bare `_`               |
| Closure hole     | `[+ _ 10]`            | `_` inside brackets    |
| Point-free       | `_.name`              | Accessor               |
| Compose          | `>> f g h`            | Left-to-right          |
| Transducer       | `(map f)`             | 1-arity returns xf     |
| Apply xf         | `into @[] xf xs`      | Terminal               |
| Fusion           | Automatic             | Compiler rewrites pipe |


<a id="org9d78f56"></a>

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


<a id="org6d63a0b"></a>

## Sigil Design

```quote
| Collection        | Sigil    | Mnemonic              | Example           |
|-------------------+----------+-----------------------+-------------------|
| Grouping          |  [...]  | "Expression"           |  [add 1 2]        |
| Grouping          |  (...)  | "Relational Clause"    | (edge ?from ?to)  |
| Persistent Vec    | @[...]  | "At" = indexed access  | @[1 2 3]          |
| Linked List       | '[...]  | "Quote" = literal      | '[1 2 3]          |
| Lazy Seq          | ~[...]  | "Tilde" = lazy/wave    | ~[1 2 3]          |
| Set               | #{...}  | EDN-style              | #{1 2 3}          |
| Map               |  {...}  | EDN-style              |  {:a 1 :b 2}      |
| Tuple (if needed) |  (...)  | Traditional            | (1, "a", true)    |
```


<a id="org5a88d71"></a>

## fn

```prologos

fn [x] add 2 x

```


<a id="org1bb6501"></a>

## HashMap


<a id="org891c3de"></a>

### Map Literal uses EDN style

```prologos
{:name "Alice" :age 42}
```


<a id="org215222c"></a>

### Lookup Syntax


<a id="org653b936"></a>

## foreign imports and ffi


<a id="org6e19391"></a>

## Partial Functions, strict arity, and the Hole-y Trinity: Curry Favor


<a id="org847c1eb"></a>

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


<a id="org1845859"></a>

## Type Syntax

-   <Type>
-   var : Type
-   var::Type


<a id="org587e9fc"></a>

## Logical Language


<a id="org90f3881"></a>

### Keywords

```prologos
rel  | relation
defr | defrel
clause
&>
=   ;; unify
.>

```


<a id="org8c6d36f"></a>

### Logic Variable Syntax and notes

| General Modality | ?var        | Input OR Output |
| Input   Modality | var OR -var | Input only      |
| Output  Modality | ?+var       | Output          |

```prologos



```

-   \*What is a good convention for naming \`defr\` forms? (Like predicate functions in Clojure, by convention, end in \`?\`)
    -   We don't want to enforce the naming, but encourage community


<a id="org8e43090"></a>

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


<a id="orga762c7f"></a>

### Clause Pipes

1.  \`&>\`

    ```prologos
    
    ```


<a id="org36b8eff"></a>

### Unification

```prologos
~
<=>
=   ;; semantically overloaded... but greater primacy to Logical Language Aspect ***


;; `:=` to functional binding
;; `==` to equality test

```


<a id="orge2afbc1"></a>

## fn/rel fusion&#x2026;


<a id="org2c8453b"></a>

## Unify | = | eq? 🤷‍♀️

-   Should we keep Prolog's use of \`=\` for unification
    -   ~~use \`unify\` keyword?~~
    -   We're going with the classic \`=\` is unify! 🎉


<a id="orgfd551f9"></a>

# Data Structures

-   Relaxed Radix Balanced Trees (RRB-trees) compared with HAMT-vectors?


<a id="org21922c5"></a>

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


<a id="org4fda43f"></a>

# Considerations


<a id="orgb54d278"></a>

## Part 2: Persistent Data Structures


<a id="org94db902"></a>

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


<a id="org84e35ee"></a>

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


<a id="org77eff9f"></a>

### 3. RRB-Trees for Vectors

If you want efficient `concat`, `slice`, `insert-at`, consider RRB-trees (Relaxed Radix Balanced) instead of plain tries.

```prologos
;; Standard vector trie: O(n) concat
;; RRB-tree: O(log n) concat, slice, insert
```


<a id="orgccce636"></a>

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


<a id="orgb3bf61d"></a>

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


<a id="org77fca78"></a>

# Higher Rank Pi Type Syntax


<a id="org22750d6"></a>

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


<a id="org500f8d8"></a>

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
