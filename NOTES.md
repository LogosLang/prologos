- [Desiderata](#orgf193672)
  - [Syntax](#org92b3d89)
    - [Homoiconicity](#orge3c4eb4)
    - [Significant whitespace](#org4a6fd54)
    - [Groupings with \`()\` (NOT \`[]\`)](#orga2c3a47)
    - [Fully qualified namespaces with \`/\` seperator](#orgbdc2a9d)
    - [EDN support](#org230d8f2)
  - [Fully qualified namespaces](#orga79e996)
  - [Strongly typed](#org7570bd9)
  - [Functional-Logic-based language](#orgde40418)
  - [Dependent Types as first class](#orgcc6d25d)
  - [Session Types for protocol, Linear Types for memory-guarentees](#org8a2b742)
  - [Strong support for parallel processing](#org4730464)
  - [Pattern Matching as first class (like in Erlang or Prolog)](#org5334dc9)
  - [Constraint Solver Language](#org67b3112)
  - [Blazingly fast](#orge123a76)
  - [Excellent, human-readable, compiler errors in the likes of Rust or Gleam **VERY IMPORTANT**](#orgc549259)
  - [Arbitrary precision numbers, EFFICIENTLY](#org30f2aec)
  - [Innovations on UNUM types](#org2316a8c)
  - [A "don't stop the world" garbage collector, like in Pony](#org1600c4b)
- [Languages that inspire us](#orga811c7e)
  - [Logic Programmming](#orgb017610)
  - [Constraint Logic Programming](#org9d87da5)
  - [Functional Programming](#org662c00a)
  - [Scripting Languages](#orga2cb3be)
  - [Formal Verification](#org74ad85a)
  - [Sussman's Propogators](#org6446934)
  - [Interesting Type Systems](#orgb95e29e)
- [Target](#orgbf0fd9c)
  - [LLVM](#orgbb625a6)
  - [Prototype in](#org0b5eaa4)


<a id="orgf193672"></a>

# Desiderata


<a id="org92b3d89"></a>

## Syntax


<a id="orge3c4eb4"></a>

### Homoiconicity

-   Code as Data
    -   reflectivity, inspectability, malleability
-   Simple syntax
-   Metaprogramming facility
-   Prefix-notation


<a id="org4a6fd54"></a>

### Significant whitespace

-   No opening bracketing like Lisp (more like TCL)
-   New line, same level: implicit list of arguments
-   New line, deeper level: implicit tree-depth of the AST
-   Same line with \`()\` groupings: deeper tree-depth of the AST


<a id="orga2c3a47"></a>

### Groupings with \`()\` (NOT \`[]\`)


<a id="orgbdc2a9d"></a>

### Fully qualified namespaces with \`/\` seperator


<a id="org230d8f2"></a>

### EDN support

-   Vectors: \`[]\`
-   Hashmaps/associative arrays/dictionaries: \`{:key00 "value" :key01 12}\`


<a id="orga79e996"></a>

## Fully qualified namespaces

-   disambiguate imports' names


<a id="org7570bd9"></a>

## Strongly typed


<a id="orgde40418"></a>

## Functional-Logic-based language

-   Also functional aspects
-   With procedural


<a id="orgcc6d25d"></a>

## Dependent Types as first class


<a id="org8a2b742"></a>

## Session Types for protocol, Linear Types for memory-guarentees

-   Dependent Session types


<a id="org4730464"></a>

## Strong support for parallel processing


<a id="org5334dc9"></a>

## Pattern Matching as first class (like in Erlang or Prolog)


<a id="org67b3112"></a>

## Constraint Solver Language


<a id="orge123a76"></a>

## Blazingly fast


<a id="orgc549259"></a>

## Excellent, human-readable, compiler errors in the likes of Rust or Gleam **VERY IMPORTANT**


<a id="org30f2aec"></a>

## Arbitrary precision numbers, EFFICIENTLY

-   I don't like "wrapping" Ints, for example; I would rather throw run-time errors than silently wrapping


<a id="org2316a8c"></a>

## Innovations on UNUM types


<a id="org1600c4b"></a>

## A "don't stop the world" garbage collector, like in Pony


<a id="orga811c7e"></a>

# Languages that inspire us


<a id="orgb017610"></a>

## Logic Programmming

-   Prolog (also homoiconic)


<a id="org9d87da5"></a>

## Constraint Logic Programming

-   ECLiPSe


<a id="org662c00a"></a>

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


<a id="orga2cb3be"></a>

## Scripting Languages

-   TCL


<a id="org74ad85a"></a>

## Formal Verification

-   Maude
    -   Flexibility to define arbitrary formal languages or logics, can be powerful and flexible in proving certain


<a id="org6446934"></a>

## Sussman's Propogators

-   Some formalisms using lattices


<a id="orgb95e29e"></a>

## Interesting Type Systems

-   Pony
-   Idris
-   Rust


<a id="orgbf0fd9c"></a>

# Target


<a id="orgbb625a6"></a>

## LLVM

-   Hope to be able to leverage other languages in the ecosystem, with strong ffi support to things like C, C++, Rust, and others


<a id="org0b5eaa4"></a>

## Prototype in

-   Racket?
-   Maude?
