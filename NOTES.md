- [Desiderata](#org4361c1b)
  - [Syntax](#org338599e)
    - [Homoiconicity](#org275c7aa)
    - [Significant whitespace](#orgc0dcd80)
    - [Groupings with \`()\` (NOT \`[]\`)](#org2032ad7)
    - [Fully qualified namespaces with \`/\` seperator](#orgf104e1e)
    - [EDN support](#org83e25c0)
    - [predicate functions prefer ending in \`?\`, by convention](#org0835a88)
  - [Propagotors as first class](#org847bc7e)
  - [Fully qualified namespaces](#orgb87086e)
  - [Strongly typed](#org744c4ad)
  - [Functional-Logic-based language](#orgd88713c)
  - [Dependent Types as first class](#org3f823ab)
  - [Session Types for protocol, Linear Types for memory-guarentees](#orgaa77461)
  - [Strong support for parallel processing](#org5c2d0f8)
  - [Pattern Matching as first class (like in Erlang or Prolog)](#orgf425702)
  - [Constraint Solver Language](#org311f7fd)
  - [Blazingly fast](#org5098e23)
  - [Excellent, human-readable, compiler errors in the likes of Rust or Gleam **VERY IMPORTANT**](#org3613038)
  - [Arbitrary precision numbers, EFFICIENTLY](#org2f115d8)
  - [Innovations on UNUM types](#orge7aeacd)
  - [A "don't stop the world" garbage collector, like in Pony](#orge0bb7fd)
  - [Immutable datastructures with structural sharing, like in Clojure](#org421513a)
- [primitives](#orga762286)
- [Logic Language](#org2ee79d7)
  - [Runs on Propagator Infrastructure rather than typical SLD/SLG Resolution](#org0b49ea2)
  - [Logical variable names with significant modal prefixes](#orga8ae13e)
  - [First-class anonymous relation primitive](#orgd330bb9)
  - [Core primitives:](#org0659dfc)
  - [Seamless integration into the functional language.](#org263e5e3)
    - [example prototype syntax](#orgb53b5af)
- [Languages that inspire us](#org311ef24)
  - [Logic Programmming](#orgd2cfa82)
  - [Constraint Logic Programming](#orgf22eae7)
  - [Functional Programming](#org5980df5)
  - [Scripting Languages](#org0555793)
  - [Formal Verification](#org0567a94)
  - [Sussman's Propogators](#org1829fd0)
  - [Interesting Type Systems](#org0d4e2a3)
- [Target](#org35f89f4)
  - [LLVM](#org290fdb0)
  - [Prototype in](#org4833402)


<a id="org4361c1b"></a>

# Desiderata


<a id="org338599e"></a>

## Syntax


<a id="org275c7aa"></a>

### Homoiconicity

-   Code as Data
    -   reflectivity, inspectability, malleability
-   Simple syntax
-   Metaprogramming facility
-   Prefix-notation


<a id="orgc0dcd80"></a>

### Significant whitespace

-   No opening bracketing like Lisp (more like TCL)
-   New line, same level: implicit list of arguments
-   New line, deeper level: implicit tree-depth of the AST
-   Same line with \`()\` groupings: deeper tree-depth of the AST


<a id="org2032ad7"></a>

### Groupings with \`()\` (NOT \`[]\`)


<a id="orgf104e1e"></a>

### Fully qualified namespaces with \`/\` seperator


<a id="org83e25c0"></a>

### EDN support

-   Vectors: \`[]\`
-   Hashmaps/associative arrays/dictionaries: \`{:key00 "value" :key01 12}\`


<a id="org0835a88"></a>

### predicate functions prefer ending in \`?\`, by convention

-   valid? NOT isValid


<a id="org847bc7e"></a>

## Propagotors as first class


<a id="orgb87086e"></a>

## Fully qualified namespaces

-   disambiguate imports' names


<a id="org744c4ad"></a>

## Strongly typed


<a id="orgd88713c"></a>

## Functional-Logic-based language

-   Also functional aspects
-   With procedural


<a id="org3f823ab"></a>

## Dependent Types as first class


<a id="orgaa77461"></a>

## Session Types for protocol, Linear Types for memory-guarentees

-   Dependent Session types


<a id="org5c2d0f8"></a>

## Strong support for parallel processing

-   anything that is "embarrassingly" parallel, and that would benefit from being so without extra overhead costs, should be so automatically
-   easy to understand/use primitives for concurrent and parallel processing


<a id="orgf425702"></a>

## Pattern Matching as first class (like in Erlang or Prolog)


<a id="org311f7fd"></a>

## Constraint Solver Language


<a id="org5098e23"></a>

## Blazingly fast


<a id="org3613038"></a>

## Excellent, human-readable, compiler errors in the likes of Rust or Gleam **VERY IMPORTANT**


<a id="org2f115d8"></a>

## Arbitrary precision numbers, EFFICIENTLY

-   I don't like "wrapping" Ints, for example; I would rather throw run-time errors than silently wrapping


<a id="orge7aeacd"></a>

## Innovations on UNUM types


<a id="orge0bb7fd"></a>

## A "don't stop the world" garbage collector, like in Pony


<a id="org421513a"></a>

## Immutable datastructures with structural sharing, like in Clojure

-   Philip Bagwell's Ideal Hashmaps Research
-   ideal vector commitments


<a id="orga762286"></a>

# primitives

-   (:= varName [: type] expr) inline let variable binding, attached to parent scope
-   


<a id="org2ee79d7"></a>

# Logic Language


<a id="org0b49ea2"></a>

## Runs on Propagator Infrastructure rather than typical SLD/SLG Resolution


<a id="orga8ae13e"></a>

## Logical variable names with significant modal prefixes

-   ?logicVar: bimodal - designates either input or output
-   +logicVar: input - must be instantiated on use
-   -logicVar: output


<a id="orgd330bb9"></a>

## First-class anonymous relation primitive

\`defn\` <=> \`defr\` :: \`fn\` <=> \`rel\`


<a id="org0659dfc"></a>

## Core primitives:

-   \`clause\`
-   \`&>\` conjunctive clause piping
-   \`rel\` => relation
    -   defines an anonymous relation


<a id="org263e5e3"></a>

## Seamless integration into the functional language.

-   use \`rel\` inside \`defn\`s; use \`


<a id="orgb53b5af"></a>

### example prototype syntax

A *relation that produces proofs*, defined *locally* inside a *function*, returning *dependent types*.


<a id="org311ef24"></a>

# Languages that inspire us


<a id="orgd2cfa82"></a>

## Logic Programmming

-   Prolog (also homoiconic)


<a id="orgf22eae7"></a>

## Constraint Logic Programming

-   ECLiPSe


<a id="org5980df5"></a>

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


<a id="org0555793"></a>

## Scripting Languages

-   TCL


<a id="org0567a94"></a>

## Formal Verification

-   Maude
    -   Flexibility to define arbitrary formal languages or logics, can be powerful and flexible in proving certain


<a id="org1829fd0"></a>

## Sussman's Propogators

-   Some formalisms using lattices


<a id="org0d4e2a3"></a>

## Interesting Type Systems

-   Pony
-   Idris
-   Rust


<a id="org35f89f4"></a>

# Target


<a id="org290fdb0"></a>

## LLVM

-   Hope to be able to leverage other languages in the ecosystem, with strong ffi support to things like C, C++, Rust, and others


<a id="org4833402"></a>

## Prototype in

-   Racket?
-   Maude?
