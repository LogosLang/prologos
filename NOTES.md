- [Desiderata](#orgbbaab94)
  - [Syntax](#org9983c45)
    - [Homoiconicity](#org94fc5a8)
    - [Significant whitespace](#org651f862)
    - [Groupings with \`()\` (NOT \`[]\`)](#orga007d9b)
    - [Fully qualified namespaces with \`/\` seperator](#org4551f33)
    - [EDN support](#orga3e673a)
    - [predicate functions prefer ending in \`?\`, by convention](#orgef359c2)
  - [Propagotors as first class](#orgad7d77a)
  - [Fully qualified namespaces](#org07a73f7)
  - [Strongly typed](#orgf436199)
  - [Functional-Logic-based language](#orgde8a316)
  - [Dependent Types as first class](#orge840dd6)
  - [Session Types for protocol, Linear Types for memory-guarentees](#orgbdf7261)
  - [Strong support for parallel processing](#org017a8ae)
  - [Pattern Matching as first class (like in Erlang or Prolog)](#org47b59ed)
  - [Constraint Solver Language](#org59d4792)
  - [Blazingly fast](#orge071783)
  - [Excellent, human-readable, compiler errors in the likes of Rust or Gleam **VERY IMPORTANT**](#org89d5a71)
  - [Arbitrary precision numbers, EFFICIENTLY](#orgab7fc3b)
  - [Innovations on UNUM types](#org93283d5)
  - [A "don't stop the world" garbage collector, like in Pony](#org71962fd)
  - [Immutable datastructures with structural sharing, like in Clojure](#orgbb9aedd)
- [primitives](#org186e783)
- [Logic Language](#org3e97158)
  - [Runs on Propagator Infrastructure rather than typical SLD/SLG Resolution](#org798c4b2)
  - [Logical variable names with significant modal prefixes](#orgfd00b24)
  - [First-class anonymous relation primitive](#org45cc756)
  - [Core primitives:](#org0c41b87)
  - [Seamless integration into the functional language.](#org1776e0e)
    - [example prototype syntax](#org6e58a83)
- [Languages that inspire us](#org7c4d6c5)
  - [Logic Programmming](#org6af7cf2)
  - [Constraint Logic Programming](#org0702350)
  - [Functional Programming](#org4bd32ad)
  - [Scripting Languages](#org65e2aa3)
  - [Formal Verification](#org3805c7c)
  - [Sussman's Propogators](#org4b12ccb)
  - [Interesting Type Systems](#orgba4d291)
- [Target](#org9923d3a)
  - [LLVM](#org8c6a8e7)
  - [Prototype in](#org6bb9375)
- [Personal TODOS](#org2ed0bdf)
  - [Editor Support](#org6627375)
  - [Language](#org1dc0760)
  - [Namespacing](#org876dc9a)
  - [Research/Implementation Guidance Documentations](#org4fc0ff3)
- [Syntax Studies](#orga2a5207)
  - [Multi-arity function bodies](#org358c1fb)
  - [IDEAs FOR PAREN GROUPINGS](#org0fdac64)
  - [Piping](#org4be0124)
  - [\`spec\`](#org690bc49)
  - [Schema, Selection, Session](#org6aedb5f)
    - [schema](#org06199ae)
    - [selection: require, include, and provide](#org42f3a1f)
    - [session](#org15c4e79)
  - [Point Free&#x2026; APL Style Trains, Trines, and Trouble????](#orgc34bd5f)
  - [Free standing hash-map: The Implicit HashMap Syntax](#orgc009fd3)
  - [In-line let](#orgd26cb9a)
  - [Sigil Design](#org63da54d)
  - [fn](#org3eba3db)
  - [Partial Functions, strict arity, and the Hole-y Trinity: Curry Favor](#org7970aa6)
    - [Use placeholders to invoke partial function](#orgadeaace)
  - [Type Syntax](#orgc8c0300)
  - [Logical Language](#org10efabb)
    - [Keywords](#orgcb9e81c)
    - [Logic Variable Syntax and notes](#org79e9c02)
    - [Namespaces and Requires](#orgb294b6c)
    - [Clause Pipes](#org36d8bd1)
    - [Unification](#org05bf156)
  - [fn/rel fusion&#x2026;](#orgd2a6928)
  - [Unify | = | eq? 🤷‍♀️](#orgb993681)
- [Data Structures](#orga04cc8b)
- [Vision, Principles,](#org2c9f23f)
- [Considerations](#org4794351)
  - [Part 2: Persistent Data Structures](#orge1bff4c)
    - [1. HAMT (Hash Array Mapped Trie)](#org493dc9e)
    - [2. Transients for Batch Updates](#orga30febe)
    - [3. RRB-Trees for Vectors](#orgfa2d30c)
    - [4. Structural Sharing + Logic Variables/](#org0b1b05f)
  - [Part 3: Evaluation Strategy](#org1c779aa)


<a id="orgbbaab94"></a>

# Desiderata


<a id="org9983c45"></a>

## Syntax


<a id="org94fc5a8"></a>

### Homoiconicity

-   Code as Data
    -   reflectivity, inspectability, malleability
-   Simple syntax
-   Metaprogramming facility
-   Prefix-notation


<a id="org651f862"></a>

### Significant whitespace

-   No opening bracketing like Lisp (more like TCL)
-   New line, same level: implicit list of arguments
-   New line, deeper level: implicit tree-depth of the AST
-   Same line with \`()\` groupings: deeper tree-depth of the AST


<a id="orga007d9b"></a>

### Groupings with \`()\` (NOT \`[]\`)


<a id="org4551f33"></a>

### Fully qualified namespaces with \`/\` seperator


<a id="orga3e673a"></a>

### EDN support

-   Vectors: \`[]\`
-   Hashmaps/associative arrays/dictionaries: \`{:key00 "value" :key01 12}\`


<a id="orgef359c2"></a>

### predicate functions prefer ending in \`?\`, by convention

-   valid? NOT isValid


<a id="orgad7d77a"></a>

## Propagotors as first class


<a id="org07a73f7"></a>

## Fully qualified namespaces

-   disambiguate imports' names


<a id="orgf436199"></a>

## Strongly typed


<a id="orgde8a316"></a>

## Functional-Logic-based language

-   Also functional aspects
-   With procedural


<a id="orge840dd6"></a>

## Dependent Types as first class


<a id="orgbdf7261"></a>

## Session Types for protocol, Linear Types for memory-guarentees

-   Dependent Session types


<a id="org017a8ae"></a>

## Strong support for parallel processing

-   anything that is "embarrassingly" parallel, and that would benefit from being so without extra overhead costs, should be so automatically
-   easy to understand/use primitives for concurrent and parallel processing


<a id="org47b59ed"></a>

## Pattern Matching as first class (like in Erlang or Prolog)


<a id="org59d4792"></a>

## Constraint Solver Language


<a id="orge071783"></a>

## Blazingly fast


<a id="org89d5a71"></a>

## Excellent, human-readable, compiler errors in the likes of Rust or Gleam **VERY IMPORTANT**


<a id="orgab7fc3b"></a>

## Arbitrary precision numbers, EFFICIENTLY

-   I don't like "wrapping" Ints, for example; I would rather throw run-time errors than silently wrapping


<a id="org93283d5"></a>

## Innovations on UNUM types


<a id="org71962fd"></a>

## A "don't stop the world" garbage collector, like in Pony


<a id="orgbb9aedd"></a>

## Immutable datastructures with structural sharing, like in Clojure

-   Philip Bagwell's Ideal Hashmaps Research
-   ideal vector commitments


<a id="org186e783"></a>

# primitives

-   (:= varName [: type] expr) inline let variable binding, attached to parent scope
-   


<a id="org3e97158"></a>

# Logic Language


<a id="org798c4b2"></a>

## Runs on Propagator Infrastructure rather than typical SLD/SLG Resolution


<a id="orgfd00b24"></a>

## Logical variable names with significant modal prefixes

-   ?logicVar: bimodal - designates either input or output
-   +logicVar: input - must be instantiated on use
-   -logicVar: output


<a id="org45cc756"></a>

## First-class anonymous relation primitive

\`defn\` <=> \`defr\` :: \`fn\` <=> \`rel\`


<a id="org0c41b87"></a>

## Core primitives:

-   \`clause\`
-   \`&>\` conjunctive clause piping
-   \`rel\` => relation
    -   defines an anonymous relation


<a id="org1776e0e"></a>

## Seamless integration into the functional language.

-   use \`rel\` inside \`defn\`s; use \`


<a id="org6e58a83"></a>

### example prototype syntax

A *relation that produces proofs*, defined *locally* inside a *function*, returning *dependent types*.


<a id="org7c4d6c5"></a>

# Languages that inspire us


<a id="org6af7cf2"></a>

## Logic Programmming

-   Prolog (also homoiconic)


<a id="org0702350"></a>

## Constraint Logic Programming

-   ECLiPSe


<a id="org4bd32ad"></a>

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


<a id="org65e2aa3"></a>

## Scripting Languages

-   TCL


<a id="org3805c7c"></a>

## Formal Verification

-   Maude
    -   Flexibility to define arbitrary formal languages or logics, can be powerful and flexible in proving certain


<a id="org4b12ccb"></a>

## Sussman's Propogators

-   Some formalisms using lattices


<a id="orgba4d291"></a>

## Interesting Type Systems

-   Pony
-   Idris
-   Rust


<a id="org9923d3a"></a>

# Target


<a id="org8c6a8e7"></a>

## LLVM

-   Hope to be able to leverage other languages in the ecosystem, with strong ffi support to things like C, C++, Rust, and others


<a id="org6bb9375"></a>

## Prototype in

-   ✅ Racket 🚀

Write a clean commit message detailing what we accomplished, only output as a markdown block.


<a id="org2ed0bdf"></a>

# Personal TODOS


<a id="org6627375"></a>

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


<a id="org1dc0760"></a>

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


<a id="org876dc9a"></a>

## Namespacing

-   [X] auto provide \`defn\`s
    -   [X] create private defn- and co.
    -   [X] remove/deprecate \`provide\`
-   [X] Ensure namespace aliasing with \`:as\`
-   [X] change namespace delimiter from \`/\` to \`::\`
-   [ ] determine what core libraries get loaded in automatically can be called in by their fully-qualified names without require


<a id="org4fc0ff3"></a>

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


<a id="orga2a5207"></a>

# Syntax Studies


<a id="org358c1fb"></a>

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


<a id="org0fdac64"></a>

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


<a id="org4be0124"></a>

## Piping

```prologos

|>    `pipe-as`
|>.   `pipe-first`
|>..  `pipe-last`

>>  Transducer

```


<a id="org690bc49"></a>

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


<a id="org6aedb5f"></a>

## Schema, Selection, Session


<a id="org06199ae"></a>

### schema


<a id="org42f3a1f"></a>

### selection: require, include, and provide


<a id="org15c4e79"></a>

### session


<a id="orgc34bd5f"></a>

## Point Free&#x2026; APL Style Trains, Trines, and Trouble????

```prologos

spec compose [B -> C] [A -> B] -> [A -> C]
defn compose [f g]
  f [g _]

```


<a id="orgc009fd3"></a>

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


<a id="orgd26cb9a"></a>

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


<a id="org63da54d"></a>

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


<a id="org3eba3db"></a>

## fn

```prologos

fn [x] add 2 x

```


<a id="org7970aa6"></a>

## Partial Functions, strict arity, and the Hole-y Trinity: Curry Favor


<a id="orgadeaace"></a>

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


<a id="orgc8c0300"></a>

## Type Syntax

-   <Type>
-   var : Type
-   var::Type


<a id="org10efabb"></a>

## Logical Language


<a id="orgcb9e81c"></a>

### Keywords

```prologos
rel  | relation
defr | defrel
clause
&>
=   ;; unify
.>

```


<a id="org79e9c02"></a>

### Logic Variable Syntax and notes

| General Modality | ?var        | Input OR Output |
| Input   Modality | var OR -var | Input only      |
| Output  Modality | ?+var       | Output          |

```prologos



```

-   \*What is a good convention for naming \`defr\` forms? (Like predicate functions in Clojure, by convention, end in \`?\`)
    -   We don't want to enforce the naming, but encourage community


<a id="orgb294b6c"></a>

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


<a id="org36d8bd1"></a>

### Clause Pipes

1.  \`&>\`

    ```prologos
    
    ```


<a id="org05bf156"></a>

### Unification

```prologos
~
<=>
=   ;; semantically overloaded... but greater primacy to Logical Language Aspect ***


;; `:=` to functional binding
;; `==` to equality test

```


<a id="orgd2a6928"></a>

## fn/rel fusion&#x2026;


<a id="orgb993681"></a>

## Unify | = | eq? 🤷‍♀️

-   Should we keep Prolog's use of \`=\` for unification
    -   use \`unify\` keyword?


<a id="orga04cc8b"></a>

# Data Structures

-   Relaxed Radix Balanced Trees (RRB-trees) compared with HAMT-vectors?


<a id="org2c9f23f"></a>

# Vision, Principles,

-   Interactive Development
    -   The programmer is in constant conversation with the runtime tooling, code, evaluation
    -   Hole-driven Development with Dependent Types
        -   Derive structure, case splits, etc.
        -   Editor Assisted Coding
    -   In-line evaluation
    -   Keep locked in to context (no switching cost between code and run/eval)
    -   Frictionless Developer Tooling Integration
-   Homoiconicity: Code is Data
    -   What you
    -   Uniform Syntax


<a id="org4794351"></a>

# Considerations


<a id="orge1bff4c"></a>

## Part 2: Persistent Data Structures


<a id="org493dc9e"></a>

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


<a id="orga30febe"></a>

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


<a id="orgfa2d30c"></a>

### 3. RRB-Trees for Vectors

If you want efficient `concat`, `slice`, `insert-at`, consider RRB-trees (Relaxed Radix Balanced) instead of plain tries.

```prologos
;; Standard vector trie: O(n) concat
;; RRB-tree: O(log n) concat, slice, insert
```


<a id="org0b1b05f"></a>

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


<a id="org1c779aa"></a>

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
