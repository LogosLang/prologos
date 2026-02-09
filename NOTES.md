- [Desiderata](#orgfe48f51)
  - [Syntax](#orgdec3dd2)
    - [Homoiconicity](#org941be6b)
    - [Significant whitespace](#org85577b6)
    - [Groupings with \`()\` (NOT \`[]\`)](#org7931503)
    - [Fully qualified namespaces with \`/\` seperator](#org251ee97)
    - [EDN support](#org8371e81)
  - [Fully qualified namespaces](#org85d4e2e)
  - [Strongly typed](#org2234d0f)
  - [Functional-Logic-based language](#org2fb8a99)
  - [Dependent Types as first class](#orge57d3dc)
  - [Session Types for protocol, Linear Types for memory-guarentees](#orgf07f801)
  - [Strong support for parallel processing](#org2d48b39)
  - [Pattern Matching as first class (like in Erlang or Prolog)](#org3cec270)
  - [Constraint Solver Language](#org8872733)
  - [Blazingly fast](#orgf27c74d)
  - [Excellent, human-readable, compiler errors in the likes of Rust or Gleam **VERY IMPORTANT**](#org395a73e)
  - [Arbitrary precision numbers, EFFICIENTLY](#org44a9290)
  - [Innovations on UNUM types](#org12646c8)
  - [A "don't stop the world" garbage collector, like in Pony](#orga4dfb74)
  - [Immutable datastructures with structural sharing, like in Clojure](#orgc7ef3f8)
- [Languages that inspire us](#orgf0289b9)
  - [Logic Programmming](#org52b4b01)
  - [Constraint Logic Programming](#org0c85030)
  - [Functional Programming](#org2534be5)
  - [Scripting Languages](#org53295ed)
  - [Formal Verification](#org862ae7b)
  - [Sussman's Propogators](#orgc4cbe7d)
  - [Interesting Type Systems](#org9340541)
- [Target](#org0b89cb9)
  - [LLVM](#org20f039d)
  - [Prototype in](#org380a8d1)


<a id="orgfe48f51"></a>

# Desiderata


<a id="orgdec3dd2"></a>

## Syntax


<a id="org941be6b"></a>

### Homoiconicity

-   Code as Data
    -   reflectivity, inspectability, malleability
-   Simple syntax
-   Metaprogramming facility
-   Prefix-notation


<a id="org85577b6"></a>

### Significant whitespace

-   No opening bracketing like Lisp (more like TCL)
-   New line, same level: implicit list of arguments
-   New line, deeper level: implicit tree-depth of the AST
-   Same line with \`()\` groupings: deeper tree-depth of the AST


<a id="org7931503"></a>

### Groupings with \`()\` (NOT \`[]\`)


<a id="org251ee97"></a>

### Fully qualified namespaces with \`/\` seperator


<a id="org8371e81"></a>

### EDN support

-   Vectors: \`[]\`
-   Hashmaps/associative arrays/dictionaries: \`{:key00 "value" :key01 12}\`


<a id="org85d4e2e"></a>

## Fully qualified namespaces

-   disambiguate imports' names


<a id="org2234d0f"></a>

## Strongly typed


<a id="org2fb8a99"></a>

## Functional-Logic-based language

-   Also functional aspects
-   With procedural


<a id="orge57d3dc"></a>

## Dependent Types as first class


<a id="orgf07f801"></a>

## Session Types for protocol, Linear Types for memory-guarentees

-   Dependent Session types


<a id="org2d48b39"></a>

## Strong support for parallel processing

-   anything that is "embarrassingly" parallel, and that would benefit from being so without extra overhead costs, should be so automatically
-   easy to understand/use primitives for concurrent and parallel processing


<a id="org3cec270"></a>

## Pattern Matching as first class (like in Erlang or Prolog)


<a id="org8872733"></a>

## Constraint Solver Language


<a id="orgf27c74d"></a>

## Blazingly fast


<a id="org395a73e"></a>

## Excellent, human-readable, compiler errors in the likes of Rust or Gleam **VERY IMPORTANT**


<a id="org44a9290"></a>

## Arbitrary precision numbers, EFFICIENTLY

-   I don't like "wrapping" Ints, for example; I would rather throw run-time errors than silently wrapping


<a id="org12646c8"></a>

## Innovations on UNUM types


<a id="orga4dfb74"></a>

## A "don't stop the world" garbage collector, like in Pony


<a id="orgc7ef3f8"></a>

## Immutable datastructures with structural sharing, like in Clojure

-   Philip Bagwell's Ideal Hashmaps Research
-   ideal vector commitments


<a id="orgf0289b9"></a>

# Languages that inspire us


<a id="org52b4b01"></a>

## Logic Programmming

-   Prolog (also homoiconic)


<a id="org0c85030"></a>

## Constraint Logic Programming

-   ECLiPSe


<a id="org2534be5"></a>

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


<a id="org53295ed"></a>

## Scripting Languages

-   TCL


<a id="org862ae7b"></a>

## Formal Verification

-   Maude
    -   Flexibility to define arbitrary formal languages or logics, can be powerful and flexible in proving certain


<a id="orgc4cbe7d"></a>

## Sussman's Propogators

-   Some formalisms using lattices


<a id="org9340541"></a>

## Interesting Type Systems

-   Pony
-   Idris
-   Rust


<a id="org0b89cb9"></a>

# Target


<a id="org20f039d"></a>

## LLVM

-   Hope to be able to leverage other languages in the ecosystem, with strong ffi support to things like C, C++, Rust, and others


<a id="org380a8d1"></a>

## Prototype in

-   Racket?
-   Maude?
