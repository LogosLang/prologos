- [Desiderata](#org7cdc8f5)
  - [Syntax](#orgd224f84)
    - [Homoiconicity](#org70c213d)
    - [Significant whitespace](#orgcae528a)
    - [Groupings with \`()\` (NOT \`[]\`)](#orga74732d)
    - [Fully qualified namespaces with \`/\` seperator](#org38da7be)
    - [EDN support](#org3fe906b)
  - [Propagotors as first class](#org20a91d1)
  - [Fully qualified namespaces](#orgdee00f5)
  - [Strongly typed](#orgc85eb4a)
  - [Functional-Logic-based language](#orgb7478c7)
  - [Dependent Types as first class](#org3e45f2e)
  - [Session Types for protocol, Linear Types for memory-guarentees](#org28ed9c2)
  - [Strong support for parallel processing](#org56d1316)
  - [Pattern Matching as first class (like in Erlang or Prolog)](#orgca64df5)
  - [Constraint Solver Language](#orgf7abc6d)
  - [Blazingly fast](#orga41e80c)
  - [Excellent, human-readable, compiler errors in the likes of Rust or Gleam **VERY IMPORTANT**](#org0ba41e6)
  - [Arbitrary precision numbers, EFFICIENTLY](#org36b7ba4)
  - [Innovations on UNUM types](#org997ccee)
  - [A "don't stop the world" garbage collector, like in Pony](#org63bfe7c)
  - [Immutable datastructures with structural sharing, like in Clojure](#org1dbbcb9)
- [Logic Language](#org185491b)
  - [Runs on Propagator Infrastructure rather than typical SLD/SLG Resolution](#orge977c80)
  - [First-class anonymous relation primitive](#org6692fdd)
  - [Core primitives:](#orge611451)
- [Languages that inspire us](#orgf2c1a8a)
  - [Logic Programmming](#org50e6722)
  - [Constraint Logic Programming](#org8b878a1)
  - [Functional Programming](#org33cf2f9)
  - [Scripting Languages](#org5675b9d)
  - [Formal Verification](#orgae352ac)
  - [Sussman's Propogators](#org8b26cce)
  - [Interesting Type Systems](#org79eb08b)
- [Target](#orgcf1ccc2)
  - [LLVM](#orge73d49f)
  - [Prototype in](#org87a7ba6)


<a id="org7cdc8f5"></a>

# Desiderata


<a id="orgd224f84"></a>

## Syntax


<a id="org70c213d"></a>

### Homoiconicity

-   Code as Data
    -   reflectivity, inspectability, malleability
-   Simple syntax
-   Metaprogramming facility
-   Prefix-notation


<a id="orgcae528a"></a>

### Significant whitespace

-   No opening bracketing like Lisp (more like TCL)
-   New line, same level: implicit list of arguments
-   New line, deeper level: implicit tree-depth of the AST
-   Same line with \`()\` groupings: deeper tree-depth of the AST


<a id="orga74732d"></a>

### Groupings with \`()\` (NOT \`[]\`)


<a id="org38da7be"></a>

### Fully qualified namespaces with \`/\` seperator


<a id="org3fe906b"></a>

### EDN support

-   Vectors: \`[]\`
-   Hashmaps/associative arrays/dictionaries: \`{:key00 "value" :key01 12}\`


<a id="org20a91d1"></a>

## Propagotors as first class


<a id="orgdee00f5"></a>

## Fully qualified namespaces

-   disambiguate imports' names


<a id="orgc85eb4a"></a>

## Strongly typed


<a id="orgb7478c7"></a>

## Functional-Logic-based language

-   Also functional aspects
-   With procedural


<a id="org3e45f2e"></a>

## Dependent Types as first class


<a id="org28ed9c2"></a>

## Session Types for protocol, Linear Types for memory-guarentees

-   Dependent Session types


<a id="org56d1316"></a>

## Strong support for parallel processing

-   anything that is "embarrassingly" parallel, and that would benefit from being so without extra overhead costs, should be so automatically
-   easy to understand/use primitives for concurrent and parallel processing


<a id="orgca64df5"></a>

## Pattern Matching as first class (like in Erlang or Prolog)


<a id="orgf7abc6d"></a>

## Constraint Solver Language


<a id="orga41e80c"></a>

## Blazingly fast


<a id="org0ba41e6"></a>

## Excellent, human-readable, compiler errors in the likes of Rust or Gleam **VERY IMPORTANT**


<a id="org36b7ba4"></a>

## Arbitrary precision numbers, EFFICIENTLY

-   I don't like "wrapping" Ints, for example; I would rather throw run-time errors than silently wrapping


<a id="org997ccee"></a>

## Innovations on UNUM types


<a id="org63bfe7c"></a>

## A "don't stop the world" garbage collector, like in Pony


<a id="org1dbbcb9"></a>

## Immutable datastructures with structural sharing, like in Clojure

-   Philip Bagwell's Ideal Hashmaps Research
-   ideal vector commitments


<a id="org185491b"></a>

# Logic Language


<a id="orge977c80"></a>

## Runs on Propagator Infrastructure rather than typical SLD/SLG Resolution


<a id="org6692fdd"></a>

## First-class anonymous relation primitive

\`defn\` <=> \`defr\` :: \`fn\` <=> \`rel\`


<a id="orge611451"></a>

## Core primitives:

-   \`rel\` => relation
    -   defines an anonymous relation


<a id="orgf2c1a8a"></a>

# Languages that inspire us


<a id="org50e6722"></a>

## Logic Programmming

-   Prolog (also homoiconic)


<a id="org8b878a1"></a>

## Constraint Logic Programming

-   ECLiPSe


<a id="org33cf2f9"></a>

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


<a id="org5675b9d"></a>

## Scripting Languages

-   TCL


<a id="orgae352ac"></a>

## Formal Verification

-   Maude
    -   Flexibility to define arbitrary formal languages or logics, can be powerful and flexible in proving certain


<a id="org8b26cce"></a>

## Sussman's Propogators

-   Some formalisms using lattices


<a id="org79eb08b"></a>

## Interesting Type Systems

-   Pony
-   Idris
-   Rust


<a id="orgcf1ccc2"></a>

# Target


<a id="orge73d49f"></a>

## LLVM

-   Hope to be able to leverage other languages in the ecosystem, with strong ffi support to things like C, C++, Rust, and others


<a id="org87a7ba6"></a>

## Prototype in

-   Racket?
-   Maude?
