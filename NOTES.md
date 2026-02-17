- [Desiderata](#org790620a)
  - [Syntax](#org384fbcc)
    - [Homoiconicity](#org5f868a0)
    - [Significant whitespace](#orgf66add7)
    - [Groupings with \`()\` (NOT \`[]\`)](#org78ab8be)
    - [Fully qualified namespaces with \`/\` seperator](#org214ceb8)
    - [EDN support](#org3bbbe43)
    - [predicate functions prefer ending in \`?\`, by convention](#org8c0d105)
  - [Propagotors as first class](#org404c1e8)
  - [Fully qualified namespaces](#orgb69ba52)
  - [Strongly typed](#org3740c54)
  - [Functional-Logic-based language](#orgf4989cb)
  - [Dependent Types as first class](#orgdd8e47a)
  - [Session Types for protocol, Linear Types for memory-guarentees](#org3a5bff1)
  - [Strong support for parallel processing](#orgf454c1b)
  - [Pattern Matching as first class (like in Erlang or Prolog)](#org52d83eb)
  - [Constraint Solver Language](#orgd53ec49)
  - [Blazingly fast](#orgf881a13)
  - [Excellent, human-readable, compiler errors in the likes of Rust or Gleam **VERY IMPORTANT**](#orgda5941d)
  - [Arbitrary precision numbers, EFFICIENTLY](#org061af57)
  - [Innovations on UNUM types](#org06c38f9)
  - [A "don't stop the world" garbage collector, like in Pony](#org7a6eeaf)
  - [Immutable datastructures with structural sharing, like in Clojure](#org222a212)
- [primitives](#org6428a7c)
- [Logic Language](#org77a1340)
  - [Runs on Propagator Infrastructure rather than typical SLD/SLG Resolution](#orgf9025f9)
  - [Logical variable names with significant modal prefixes](#orgb91f79f)
  - [First-class anonymous relation primitive](#org1f110b6)
  - [Core primitives:](#orgf3ec3c2)
  - [Seamless integration into the functional language.](#org7418df9)
    - [example prototype syntax](#orgac09464)
- [Languages that inspire us](#orgfae8f78)
  - [Logic Programmming](#org397aa33)
  - [Constraint Logic Programming](#orgd1bd510)
  - [Functional Programming](#org0a05388)
  - [Scripting Languages](#orgac9044e)
  - [Formal Verification](#org55a0a9c)
  - [Sussman's Propogators](#org8189f2e)
  - [Interesting Type Systems](#org09be324)
- [Target](#orgfc6316e)
  - [LLVM](#org6305d13)
  - [Prototype in](#orgf6a5e91)
- [Personal TODOS](#org34d966a)
  - [Editor Support](#orgef80186)
  - [Language](#orgf227fe6)
  - [Namespacing](#org0dd8a8f)
  - [Research/Implementation Guidance Documentations](#org556a8f3)
- [Syntax Studies](#org6abc0b1)
  - [Multi-arity function bodies](#org960660b)
  - [IDEAs FOR PAREN GROUPINGS](#org07feb2b)
  - [call site typing, "Explicit Application"](#orgf185df8)
  - [Piping](#orgf14fb62)
  - [\`spec\`](#orge630de2)
  - [Schema, Selection, Session](#org163f32a)
    - [schema](#orgeba7ed2)
    - [selection: require, include, and provide](#orgb9c2733)
    - [session](#orgcbfef9d)
  - [Point Free&#x2026; APL Style Trains, Trines, and Trouble????](#org54410a3)
  - [Free standing hash-map: The Implicit HashMap Syntax](#org9d8bd35)
  - [In-line let](#orgd5e5299)
  - [Sigil Design](#orgbd5a480)
  - [fn](#org2ff4ff1)
  - [HashMap](#org0c155fe)
    - [Map Literal uses EDN style](#org2a75ec5)
    - [Lookup Syntax](#org0bf5332)
  - [foreign imports and ffi](#org00a1ceb)
  - [Partial Functions, strict arity, and the Hole-y Trinity: Curry Favor](#orga28cf32)
    - [Use placeholders to invoke partial function](#org86e7899)
  - [Type Syntax](#orge2f37b7)
  - [Logical Language](#orgb071002)
    - [Keywords](#orgc3d6307)
    - [Logic Variable Syntax and notes](#orgc90fb8a)
    - [Namespaces and Requires](#orgf21f0dc)
    - [Clause Pipes](#orgaad09ff)
    - [Unification](#org008098d)
  - [fn/rel fusion&#x2026;](#orgf3e91aa)
  - [Unify | = | eq? 🤷‍♀️](#org9111032)
- [Data Structures](#org86ed023)
- [Vision, Principles,](#org2bc67dd)
- [Considerations](#org86b3e48)
  - [Part 2: Persistent Data Structures](#org4bde5bb)
    - [1. HAMT (Hash Array Mapped Trie)](#orgfad0226)
    - [2. Transients for Batch Updates](#orgecbe6cf)
    - [3. RRB-Trees for Vectors](#orgb8ca57b)
    - [4. Structural Sharing + Logic Variables/](#orgd2eea56)
  - [Part 3: Evaluation Strategy](#org512e8b1)


<a id="org790620a"></a>

# Desiderata


<a id="org384fbcc"></a>

## Syntax


<a id="org5f868a0"></a>

### Homoiconicity

-   Code as Data
    -   reflectivity, inspectability, malleability
-   Simple syntax
-   Metaprogramming facility
-   Prefix-notation


<a id="orgf66add7"></a>

### Significant whitespace

-   No opening bracketing like Lisp (more like TCL)
-   New line, same level: implicit list of arguments
-   New line, deeper level: implicit tree-depth of the AST
-   Same line with \`()\` groupings: deeper tree-depth of the AST


<a id="org78ab8be"></a>

### Groupings with \`()\` (NOT \`[]\`)


<a id="org214ceb8"></a>

### Fully qualified namespaces with \`/\` seperator


<a id="org3bbbe43"></a>

### EDN support

-   Vectors: \`[]\`
-   Hashmaps/associative arrays/dictionaries: \`{:key00 "value" :key01 12}\`


<a id="org8c0d105"></a>

### predicate functions prefer ending in \`?\`, by convention

-   valid? NOT isValid


<a id="org404c1e8"></a>

## Propagotors as first class


<a id="orgb69ba52"></a>

## Fully qualified namespaces

-   disambiguate imports' names


<a id="org3740c54"></a>

## Strongly typed


<a id="orgf4989cb"></a>

## Functional-Logic-based language

-   Also functional aspects
-   With procedural


<a id="orgdd8e47a"></a>

## Dependent Types as first class


<a id="org3a5bff1"></a>

## Session Types for protocol, Linear Types for memory-guarentees

-   Dependent Session types


<a id="orgf454c1b"></a>

## Strong support for parallel processing

-   anything that is "embarrassingly" parallel, and that would benefit from being so without extra overhead costs, should be so automatically
-   easy to understand/use primitives for concurrent and parallel processing


<a id="org52d83eb"></a>

## Pattern Matching as first class (like in Erlang or Prolog)


<a id="orgd53ec49"></a>

## Constraint Solver Language


<a id="orgf881a13"></a>

## Blazingly fast


<a id="orgda5941d"></a>

## Excellent, human-readable, compiler errors in the likes of Rust or Gleam **VERY IMPORTANT**


<a id="org061af57"></a>

## Arbitrary precision numbers, EFFICIENTLY

-   I don't like "wrapping" Ints, for example; I would rather throw run-time errors than silently wrapping


<a id="org06c38f9"></a>

## Innovations on UNUM types


<a id="org7a6eeaf"></a>

## A "don't stop the world" garbage collector, like in Pony


<a id="org222a212"></a>

## Immutable datastructures with structural sharing, like in Clojure

-   Philip Bagwell's Ideal Hashmaps Research
-   ideal vector commitments


<a id="org6428a7c"></a>

# primitives

-   (:= varName [: type] expr) inline let variable binding, attached to parent scope
-   


<a id="org77a1340"></a>

# Logic Language


<a id="orgf9025f9"></a>

## Runs on Propagator Infrastructure rather than typical SLD/SLG Resolution


<a id="orgb91f79f"></a>

## Logical variable names with significant modal prefixes

-   ?logicVar: bimodal - designates either input or output
-   +logicVar: input - must be instantiated on use
-   -logicVar: output


<a id="org1f110b6"></a>

## First-class anonymous relation primitive

\`defn\` <=> \`defr\` :: \`fn\` <=> \`rel\`


<a id="orgf3ec3c2"></a>

## Core primitives:

-   \`clause\`
-   \`&>\` conjunctive clause piping
-   \`rel\` => relation
    -   defines an anonymous relation


<a id="org7418df9"></a>

## Seamless integration into the functional language.

-   use \`rel\` inside \`defn\`s; use \`


<a id="orgac09464"></a>

### example prototype syntax

A *relation that produces proofs*, defined *locally* inside a *function*, returning *dependent types*.


<a id="orgfae8f78"></a>

# Languages that inspire us


<a id="org397aa33"></a>

## Logic Programmming

-   Prolog (also homoiconic)


<a id="orgd1bd510"></a>

## Constraint Logic Programming

-   ECLiPSe


<a id="org0a05388"></a>

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


<a id="orgac9044e"></a>

## Scripting Languages

-   TCL


<a id="org55a0a9c"></a>

## Formal Verification

-   Maude
    -   Flexibility to define arbitrary formal languages or logics, can be powerful and flexible in proving certain


<a id="org8189f2e"></a>

## Sussman's Propogators

-   Some formalisms using lattices


<a id="org09be324"></a>

## Interesting Type Systems

-   Pony
-   Idris
-   Rust


<a id="orgfc6316e"></a>

# Target


<a id="org6305d13"></a>

## LLVM

-   Hope to be able to leverage other languages in the ecosystem, with strong ffi support to things like C, C++, Rust, and others


<a id="orgf6a5e91"></a>

## Prototype in

-   ✅ Racket 🚀

Write a clean commit message detailing what we accomplished, only output as a markdown block.


<a id="org34d966a"></a>

# Personal TODOS


<a id="orgef80186"></a>

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


<a id="orgf227fe6"></a>

## Language

-   [ ] Clarify \`()\` as logic clauses and Type Groupings
-   [ ] ‼️ Better Type delimiters in WS mode
    -   Any complex grouped types, Function, Pi, Sigma use \`()\`
        -   [ ] 👩‍🔬🦆 Syntax Workshop!
-   [ ] ‼️🦆 Workshop Session Syntax
    -   [ ] Syntax Notes
-   [ ] ~~Anonymous Relation \`?()\`&#x2026; but also \`rel\`~~ DEFER
    
    | Command Language | Relational Languages |              |
    | []  OR  "bare"   | ()                   |              |
    | defn             | defr                 |              |
    | fn               | rel                  |              |
    | #()              | ?()                  | ;; more ⚙️🔧🧠 |
    
    -   [ ] Syntax Notes
-   [X] ~~Deprecate \`<>\` (but keep, for now)~~
    -   [X] Repurpose \`<>\` For Pi and Sigma Types
-   [X] Multi-arity defn: Case-split syntax with multiple arities (original feature request)
-   [X] Partial function application with wildcards
-   [ ] variable argument support \`&#x2026;name\` syntax?
-   [X] Migrate Groupings syntax from \`()\` to \`[]\`
-   [X] define sigil syntax for common data structures (see Syntax Studies below)
-   [X] Prologos \`defmacro\`
    -   test (see re: homoiconicity concerns)
-   [X] Unit Type
-   [ ] Nil Type? (equivalent semantically to Unit.. redundant? or good meaning?)
    -   [ ] verify
-   [X] Union Type
-   [X] Nullable Type? -> Union Type of [A | Nil]
-   [X] Memoization Infra
-   [-] Polymorphic Dispatch 🦆
    -   [X] \`trait\` and \`impl\`
    -   [ ] ??? check back on notes for further design patterns
-   [X] Return types arity style \`A B C -> D\` **NOT** curry style: \`A -> B -> C -> D\`
-   [X] \`defn\` default public \`defn-\` default private &#x2013; deprecate \`provide\`
-   [X] \`require\` QoL - \`:as\`
-   [X] \`let\` block vs in-line \`let\`s
    -   We support both&#x2026; sibling in-line lets share same local scope
    -   Design research/🦆
-   [ ] Map with key access syntax
    -   Make Example in Syntax Lab
    -   Implicit Map syntax
-   [ ] foreign/ffi syntax


<a id="org0dd8a8f"></a>

## Namespacing

-   [X] auto provide \`defn\`s
    -   [X] create private defn- and co.
    -   [X] remove/deprecate \`provide\`
-   [X] Ensure namespace aliasing with \`:as\`
-   [X] change namespace delimiter from \`/\` to \`::\`
-   [ ] determine what core libraries get loaded in automatically can be called in by their fully-qualified names without require


<a id="org556a8f3"></a>

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


<a id="org6abc0b1"></a>

# Syntax Studies


<a id="org960660b"></a>

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


<a id="org07feb2b"></a>

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

For this run, we want to clarify Type system syntax and the issues involved with groupings and their parsing. Let's put on our best program language design hat while we consider deeply some goals:

-   refactor \`<>\` to support Pi and Sigma dependent type groupings, remove for other cases
    -   Unified Type system for Depdent Pi and Sigma types with \`<>\` groupings
        -   Pi: \`<(x : A) -> B>\`
        -   Sigma: \`<(x : A) \* B>\`
-   In Pi and Sigma types, *optionally* drop inner parens for single binder; multiple binders still use parens
-   uncurried surface for multiple binders
-   Session types "carry the multiplicity on the arrow" in type signatures \`A -1> B\`
    -   after variable in bindings [x :1 A] and implicits {n :0 Nat}
-   Reserve \`()\` for groupings in compound types
    -   Function: \`(A -> B)\`
    -   Product: \`(A \* B)\`
    -   Union: \`(A | B)\`
-   Future plan to use \`()\` uniquely for clauses in the "Relational Language" of the Logical Core, distinct from \`[]\` in the "Command Language" (Functional Core). Defered for later.

Let's consider the following conversation to inform this work, following the best recommendations and guidance:

\`\`\` \`\`\`


<a id="orgf185df8"></a>

## call site typing, "Explicit Application"

-   When Might You Want Explicit Type Arguments?

Sometimes inference fails or you want to be explicit:

```prologos
;; Or at call site (if we support it)
let xs = nil @Nat  ;; "nil at type Nat"
```


<a id="orgf14fb62"></a>

## Piping

```prologos

|>    `pipe-as`
|>.   `pipe-first`
|>..  `pipe-last`

>>  Transducer

```


<a id="orge630de2"></a>

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


<a id="org163f32a"></a>

## Schema, Selection, Session


<a id="orgeba7ed2"></a>

### schema


<a id="orgb9c2733"></a>

### selection: require, include, and provide


<a id="orgcbfef9d"></a>

### session


<a id="org54410a3"></a>

## Point Free&#x2026; APL Style Trains, Trines, and Trouble????

```prologos

spec compose [B -> C] [A -> B] -> [A -> C]
defn compose [f g]
  f [g _]

```


<a id="org9d8bd35"></a>

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


<a id="orgd5e5299"></a>

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


<a id="orgbd5a480"></a>

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


<a id="org2ff4ff1"></a>

## fn

```prologos

fn [x] add 2 x

```


<a id="org0c155fe"></a>

## HashMap


<a id="org2a75ec5"></a>

### Map Literal uses EDN style

```prologos
{:name "Alice" :age 42}
```


<a id="org0bf5332"></a>

### Lookup Syntax


<a id="org00a1ceb"></a>

## foreign imports and ffi


<a id="orga28cf32"></a>

## Partial Functions, strict arity, and the Hole-y Trinity: Curry Favor


<a id="org86e7899"></a>

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


<a id="orge2f37b7"></a>

## Type Syntax

-   <Type>
-   var : Type
-   var::Type


<a id="orgb071002"></a>

## Logical Language


<a id="orgc3d6307"></a>

### Keywords

```prologos
rel  | relation
defr | defrel
clause
&>
=   ;; unify
.>

```


<a id="orgc90fb8a"></a>

### Logic Variable Syntax and notes

| General Modality | ?var        | Input OR Output |
| Input   Modality | var OR -var | Input only      |
| Output  Modality | ?+var       | Output          |

```prologos



```

-   \*What is a good convention for naming \`defr\` forms? (Like predicate functions in Clojure, by convention, end in \`?\`)
    -   We don't want to enforce the naming, but encourage community


<a id="orgf21f0dc"></a>

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


<a id="orgaad09ff"></a>

### Clause Pipes

1.  \`&>\`

    ```prologos
    
    ```


<a id="org008098d"></a>

### Unification

```prologos
~
<=>
=   ;; semantically overloaded... but greater primacy to Logical Language Aspect ***


;; `:=` to functional binding
;; `==` to equality test

```


<a id="orgf3e91aa"></a>

## fn/rel fusion&#x2026;


<a id="org9111032"></a>

## Unify | = | eq? 🤷‍♀️

-   Should we keep Prolog's use of \`=\` for unification
    -   ~~use \`unify\` keyword?~~
    -   We're going with the classic \`=\` is unify! 🎉


<a id="org86ed023"></a>

# Data Structures

-   Relaxed Radix Balanced Trees (RRB-trees) compared with HAMT-vectors?


<a id="org2bc67dd"></a>

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


<a id="org86b3e48"></a>

# Considerations


<a id="org4bde5bb"></a>

## Part 2: Persistent Data Structures


<a id="orgfad0226"></a>

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


<a id="orgecbe6cf"></a>

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


<a id="orgb8ca57b"></a>

### 3. RRB-Trees for Vectors

If you want efficient `concat`, `slice`, `insert-at`, consider RRB-trees (Relaxed Radix Balanced) instead of plain tries.

```prologos
;; Standard vector trie: O(n) concat
;; RRB-tree: O(log n) concat, slice, insert
```


<a id="orgd2eea56"></a>

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


<a id="org512e8b1"></a>

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
