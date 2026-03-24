- [Implementation Status](#org2f10224)
- [Executive Summary](#orgd7aec3c)
- [Current State: What Exists](#org1951bec)
  - [Collection Types (5 Families)](#orge285c2e)
  - [Collection Traits (8 Traits)](#orga78056a)
    - [The Collection Bundle](#org4481b05)
  - [Operation Modules (7 Modules, ~60 Functions)](#orgd9d220b)
  - [Current Generic Operation Surface](#orgd3375c1)
    - [Path 1: Type-Specific (Concrete, Fast for List)](#org4d2b16d)
    - [Path 2: Explicit-Dict Generic (Verbose, Complete)](#orgae2e2bc)
    - [Path 3: Conversion Hub (Explicit, Flexible)](#org64cc436)
- [Critique: The Ergonomic Gap](#org19f8fc5)
  - [Problem 1: No Auto-Dispatching Generic `map` / `filter` / `fold`](#orgeb27a82)
  - [Problem 2: All Non-List Operations Go Through List Conversion](#org03b7c2e)
  - [Problem 3: Map Is Excluded from the Trait System](#org208df4a)
  - [Problem 4: `Seq` Trait Is Underutilized](#orgb2b74bf)
  - [Problem 5: Functor Is Incomplete and Inconsistent](#org148c61c)
  - [Problem 6: No Type-Preserving Generic Transformation](#org54bfe1a)
  - [Problem 7: No `flat-map` / `concat-map` Generic](#org288ef95)
  - [Problem 8: Missing Operations Across Types](#orgb152a61)
  - [Problem 9: Test Coverage Is Type-Inference Only](#orgebde58d)
  - [Problem 10: Transducers Are Orphaned](#org2a09862)
- [Design Decisions (Agreed)](#orga43259e)
  - [Decision 1: Generic Shadowing (Path C) — AGREED](#org12c4cf2)
  - [Decision 2: MapEntry Type — AGREED (Clojure-Style)](#orgc0f4e8f)
  - [Decision 3: `reduce` (not `fold`) with Identity Resolution — AGREED](#org11a4b70)
  - [Decision 4: Efficient Native Trait Instances — AGREED (Do Now)](#org30942da)
    - [PVec (RRB-Tree backend) — 3 new AST primitives](#org9c60f13)
    - [Set (CHAMP backend) — 2 new AST primitives](#org1ce92f6)
    - [Map (CHAMP backend) — 3 new AST primitives](#org7ac746e)
  - [Decision 5: `into` as Elaborator Keyword — AGREED](#org4e2adfd)
  - [Decision 6: Naming — Generic `map` Shadows Prelude — AGREED](#org7812fed)
- [Gaps in Infrastructure](#orgc8bc466)
  - [Gap 1: No Auto-Resolved Generic Operations](#orgae94f61)
  - [Gap 2: No `Seq` Instances for PVec or Set](#org30d3672)
  - [Gap 3: Map Cannot Participate in Generic Operations](#org6b899a9)
  - [Gap 4: No `Filterable` Trait](#orge5b1f45)
  - [Gap 5: No `flat-map` / `concat-map` Generic](#orgfaf1718)
  - [Gap 6: `Seq` Trait and Functions Not in Prelude](#org31a4989)
  - [Gap 7: Transducers Not in Prelude or Integrated with Pipe](#org08f89c3)
  - [Gap 8: `Seq List` Instance Not Auto-Loaded](#orgbbb40c9)
  - [Gap 9: Eval Tests Missing for Collection Ops](#orge65216a)
  - [Gap 10: Stale Test Comments](#orgf4d3ed7)
- [Implementation Plan](#org3defccc)
  - [Stage A: Foundation — Tests and Cleanup](#orgbb4959f)
    - [A1. Eval Tests for All Existing Collection Ops](#orgbc36776)
    - [A2. Fix Stale Test Comments](#orge0788f7)
  - [Stage B: MapEntry Type and Map Bridge](#org5ad2315)
    - [B1. `MapEntry` Deftype](#org345bd1e)
    - [B2. Map Bridge Functions](#org6408ebe)
    - [B3. Add MapEntry and Bridge to Prelude](#org49a3a09)
  - [Stage C: Native AST Primitives (~8 new primitives)](#orgb48842c)
    - [C1. `expr-pvec-fold` — PVec native fold](#orge210414)
    - [C2. `expr-pvec-map` — PVec native map](#org0ead11a)
    - [C3. `expr-pvec-filter` — PVec native filter](#org0f6baee)
    - [C4. `expr-set-fold` — Set native fold](#org209f232)
    - [C5. `expr-set-filter` — Set native filter](#org2738980)
    - [C6. `expr-map-fold-entries` — Map native entry fold (upgrade existing)](#org189d3e0)
    - [C7. `expr-map-filter-entries` — Map native entry filter](#org9e14cb1)
    - [C8. `expr-map-map-vals` — Map native value mapping](#org15859a0)
  - [Stage D: Efficient Trait Instances](#org61e2797)
    - [D1. Replace PVec Foldable Instance](#org06a9573)
    - [D2. Replace PVec Functor Instance](#org37c3d30)
    - [D3. Replace Set Foldable Instance](#org6f7ee2b)
    - [D4. Replace pvec-ops / set-ops / map-ops Implementations](#org194f059)
  - [Stage E: `reduce` with Identity Resolution](#org04ba8e4)
    - [E1. Add `:identity` Spec Metadata Handling](#org9649b1e)
    - [E2. Annotate Trait Method Specs with `:identity`](#orge187d22)
    - [E3. Implement 2-arg / 3-arg `reduce` Dispatch](#org2d10fff)
  - [Stage F: Generic Collection Functions Module](#orgcb2944f)
    - [F1. Create `prologos::core::collection-fns`](#orgccc9698)
    - [F2. Prelude Shadowing](#org3a18651)
  - [Stage G: `into` Elaborator Keyword](#org95bc355)
    - [G1. Add `into` to Elaborator](#org655ddb1)
    - [G2. Pipe Integration](#orgff83f40)
  - [Stage H: Seq Protocol Expansion](#org3791c33)
    - [H1. `Seq` Instances for PVec and Set](#org6c4d6e4)
    - [H2. Add Seq, seq-functions to Prelude](#orgaede9fa)
    - [H3. Streaming Operations via Seq](#org378fdcf)
  - [Stage I: Transducer Integration (if time permits)](#org1905873)
    - [I1. Transducer Runners for PVec/Set/Map](#org5429e93)
    - [I2. Pipe Macro Auto-Fusion for Non-List](#orgb4b46f3)
  - [Deferred (Genuine Dependencies on Unbuilt Infrastructure)](#orga252baf)
    - [HKT Partial Application for Map Trait Instances](#org8efb467)
    - [`Seq` as Proper Trait (deftype → trait migration)](#org1cf873d)
    - [Sorted Collections (`SortedMap`, `SortedSet`)](#org2a8777a)
    - [Parallel Collection Operations](#org6def27d)
- [Alignment with Design Principles](#orgf40f905)
  - [The Most Generalizable Interface](#orga5d4eef)
  - [Decomplection: Collections and Backends](#orgbadc9ab)
  - [Progressive Disclosure](#org736a72b)
  - [Homoiconicity](#org47a59d9)
- [Summary Table](#org7d4ddae)
- [What Success Looks Like](#orgcea70d1)



<a id="org2f10224"></a>

# Implementation Status

**Stages A-H: COMPLETE.** Stage I: DEFERRED (see `DEFERRED.md`).

| Stage | Description                                 | Status   |
|----- |------------------------------------------- |-------- |
| A     | Foundation tests + cleanup                  | COMPLETE |
| B     | MapEntry type + Map bridge                  | COMPLETE |
| C     | 8 native AST primitives (fold/map/filter)   | COMPLETE |
| D     | Efficient trait instances (native dispatch) | COMPLETE |
| E     | `reduce1` (first-element-as-init fold)      | COMPLETE |
| F     | Generic collection-fns + prelude shadowing  | COMPLETE |
| G     | `into` collection conversion                | COMPLETE |
| H     | `head`, `empty?`, `rest-seq` generic access | COMPLETE |
| I     | Transducer integration (stretch)            | DEFERRED |

**Key results:**

-   17 generic functions: `map`, `filter`, `reduce`, `reduce1`, `length`, `concat`, `any?`, `all?`, `to-list`, `find`, `take`, `drop`, `into`, `head`, `empty?`, `rest-seq`, + module `to-list`
-   8 native AST primitives: `pvec-fold`, `pvec-map`, `pvec-filter`, `set-fold`, `set-filter`, `map-fold-entries`, `map-filter-entries`, `map-map-vals`
-   Prelude shadowing: generic `map~/~filter~/~reduce` shadow List-specific versions
-   3605 tests pass (163 files)

**Design changes from plan:**

-   Stage E simplified: full `:identity` spec metadata + elaborator rewrite deferred; `reduce1` (returns `Option A`) implemented instead
-   Stage G simplified: `into` as regular function (not parser keyword); empty collection literal metavariables provide type inference
-   Stage H: `head` instead of `first` (parser keyword conflict with Sigma projection)
-   `rest-seq` returns `LSeq A` (streaming), not original collection type


<a id="orgd7aec3c"></a>

# Executive Summary

This audit examines the gap between Prologos's *stated design goal* &mdash; the most-generalizable interface with efficient dispatch &mdash; and the *current reality* of its collection infrastructure. The findings: the trait foundation is architecturally sound (8 traits, 19 instances, 5 collection types), but the surface ergonomics force users into either type-specific operations (`pvec-map`, `set-filter`) or explicit-dictionary generic operations (`gmap` with `Seqable` and `Buildable` dicts). Neither path achieves the Clojure-like experience where `map`, `filter`, and `reduce` simply *work* on any collection.

The core tension: Prologos's HKT trait system requires `{C : Type -> Type}` kind constraints, which excludes `Map` (two type params). All non-List collection operations go through List conversion, losing both type information and performance. And the `Seq` trait &mdash; designed to be the universal sequence abstraction &mdash; is barely wired into the system: only 2 instances (List, LSeq), not in the prelude, and no generic operations dispatch through it.

**Design decisions (post-review):**

1.  **Generic shadowing (Path C)**: `map`, `filter`, `reduce` shadow prelude List versions, dispatch via trait resolver. Type-specific versions remain as `list::map`, `pvec::map`, etc.
2.  **MapEntry type**: New `MapEntry K V` deftype lets Map participate in `Type -> Type` trait system via entry sequences. Clojure-style.
3.  **`reduce` over `fold`**: `reduce` is the primary name. 2-arg form pulls identity from spec `:identity` metadata or sibling trait identity; 3-arg form takes explicit identity.
4.  **`into` as elaborator keyword**: `into @[] xs` recognized at elaboration time; empty collection literal consumed as type indicator, zero runtime cost.
5.  **Efficient native trait instances**: Native AST primitives for PVec/Set/Map traversal, pushed into trait instances. Generic dispatch IS efficient dispatch.
6.  **Completeness over deferral**: Build the full solution now &mdash; efficient native instances, MapEntry, generic `into`, `reduce` with identity &mdash; rather than deferring infrastructure to later phases.


<a id="org1951bec"></a>

# Current State: What Exists


<a id="orge285c2e"></a>

## Collection Types (5 Families)

| Type | Literal    | Backend      | Kind                   | Purpose                     |
|---- |---------- |------------ |---------------------- |--------------------------- |
| List | `'[1 2 3]` | Linked cons  | `Type -> Type`         | Default, inductive, pattern |
| PVec | `@[1 2 3]` | RRB-Tree     | `Type -> Type`         | Indexed, persistent         |
| Set  | `#{1 2 3}` | CHAMP        | `Type -> Type`         | Membership, uniqueness      |
| Map  | `{:a 1}`   | CHAMP        | `Type -> Type -> Type` | Key-value association       |
| LSeq | `(lazy)`   | Thunked cons | `Type -> Type`         | Lazy, infinite, hub type    |

Key relationships:

-   LSeq is the *hub type* through which all collections convert for generic operations
-   Map is the *odd one out* with two type parameters, incompatible with standard traits
-   All non-List types are AST-level primitives (no `data` declaration)


<a id="orga78056a"></a>

## Collection Traits (8 Traits)

| Trait     | Kind                           | Methods                       | Instances             |
|--------- |------------------------------ |----------------------------- |--------------------- |
| Seqable   | `{C : Type -> Type}`           | `to-seq : C A -> LSeq A`      | List, PVec, Set, LSeq |
| Foldable  | `{F : Type -> Type}`           | `fold : (A->B->B)->B->F A->B` | List, PVec, Set, LSeq |
| Buildable | `{C : Type -> Type}`           | `from-seq`, `empty-coll`      | List, PVec, Set, LSeq |
| Functor   | `{F : Type -> Type}`           | `fmap : (A->B)->F A->F B`     | List, PVec            |
| Indexed   | `{C : Type -> Type}`           | `nth`, `length`, `update`     | List, PVec            |
| Setlike   | `{C : Type -> Type}`           | `member?`, `insert`, `remove` | Set                   |
| Keyed     | `{C : Type -> Type -> Type}`   | `get`, `assoc`, `dissoc`      | Map                   |
| Seq       | `{S : Type -> Type}` (deftype) | `first`, `rest`, `empty?`     | List, LSeq            |


<a id="org4481b05"></a>

### The Collection Bundle

```prologos
bundle Collection := (Seqable, Buildable, Foldable)
```

Conjunctive (AND), not implicative. Expands to three constraints at parse time. List, PVec, Set, and LSeq all satisfy `Collection`. Map does not.


<a id="orgd9d220b"></a>

## Operation Modules (7 Modules, ~60 Functions)

| Module                    | Functions | Scope       | Pattern                              |
|------------------------- |--------- |----------- |------------------------------------ |
| `list.prologos`           | ~50+      | List only   | Native pattern-match implementations |
| `pvec-ops.prologos`       | 7         | PVec only   | All via List conversion              |
| `set-ops.prologos`        | 7         | Set only    | All via List conversion              |
| `map-ops.prologos`        | 6         | Map only    | Via `map-keys` iteration             |
| `lseq-ops.prologos`       | 9         | LSeq only   | Native thunk implementations         |
| `generic-ops.prologos`    | 8         | HKT generic | Requires explicit dict args          |
| `collection-ops.prologos` | 4         | List only   | Legacy/demo (predates HKT)           |

Additionally:

-   `collection-conversions.prologos` : 7 hub-and-spoke conversions (List↔LSeq↔PVec/Set)
-   `seq-functions.prologos` : 5 functions over `Seq` dict (NOT in prelude)
-   `transducer.prologos` : 3 transducer constructors + runners (NOT in prelude)
-   `generic-numeric-ops.prologos` : `sum`, `product`, `int-range` (in prelude)


<a id="orgd3375c1"></a>

## Current Generic Operation Surface

The user has three ways to transform collections:


<a id="org4d2b16d"></a>

### Path 1: Type-Specific (Concrete, Fast for List)

```prologos
;; List — native, pattern-matched, O(n)
map inc '[1 2 3]          ;; => '[2 3 4] : List Nat

;; PVec — via List conversion, O(n) with 2 conversions
pvec-map inc @[1 2 3]     ;; => @[2 3 4] : PVec Nat

;; Set — via List conversion
set-map inc #{1 2 3}      ;; => #{2 3 4} : Set Nat
```


<a id="orgae2e2bc"></a>

### Path 2: Explicit-Dict Generic (Verbose, Complete)

```prologos
;; Requires knowing and passing trait dicts:
gmap List--Seqable--dict List--Buildable--dict inc '[1 2 3]
gmap PVec--Seqable--dict PVec--Buildable--dict inc @[1 2 3]
```


<a id="org64cc436"></a>

### Path 3: Conversion Hub (Explicit, Flexible)

```prologos
;; Any → LSeq → transform → Any
|> @[1 2 3]
  pvec-to-seq
  lseq-map inc
  into-vec
```

None of these achieves the Clojure-like ideal:

```clojure
;; What Clojure does:
(map inc [1 2 3])      ;; works on any seqable
(filter even? #{1 2 3}) ;; works on sets
(reduce + {} entries)    ;; works on maps
```


<a id="org19f8fc5"></a>

# Critique: The Ergonomic Gap


<a id="orgeb27a82"></a>

## Problem 1: No Auto-Dispatching Generic `map` / `filter` / `fold`

The single most impactful gap. A user writing generic code must choose between:

-   `map` (List-only, from `prologos::data::list`)
-   `pvec-map` / `set-map` (type-specific, from ops modules)
-   `gmap dict1 dict2 f coll` (generic but verbose)

There is no `map` that simply works on any collection. Compare:

```prologos
;; What we WANT (most-generic interface):
spec process : {C : Type -> Type} where (Collection C) [C Int] -> [C Int]
defn process [xs]
  |> xs
    map [fn [x] [+ x 1]]
    filter even?

;; What we MUST write today:
;; Either pick a concrete type, or thread dicts manually
```

This is the collections analogue of the numerics audit's "parser keywords are not generic" problem. Just as `int+` locked users to `Int`, `pvec-map` locks users to `PVec`.


<a id="org03b7c2e"></a>

## Problem 2: All Non-List Operations Go Through List Conversion

Every PVec, Set, and LSeq operation converts to List, operates, and converts back. The implementation pattern in every ops module:

```prologos
;; pvec-ops.prologos — EVERY function follows this pattern:
defn pvec-map [f v]
  pvec-from-list [map f [pvec-to-list v]]

defn pvec-filter [pred v]
  pvec-from-list [filter pred [pvec-to-list v]]
```

This has two costs:

1.  **Performance**: `O(n)` allocation for intermediate List, then `O(n)` allocation for result. `pvec-map` is `O(3n)` instead of `O(n)`.
2.  **Semantics**: Set operations lose element ordering guarantees during List roundtrip (though CHAMP sets are unordered, so this is benign for Set; problematic if we add sorted collections).

For the Foldable instances, the pattern is even more wasteful:

```prologos
;; foldable-pvec.prologos:
def pvec-foldable : [Foldable PVec]
  ;; converts to List, then folds the List
  (fn A B step init pvec (foldr A B step init (pvec-to-list A pvec)))
```

PVec *has* O(n) traversal natively (RRB-Tree leaves are arrays), but the Foldable instance doesn't use it.


<a id="org208df4a"></a>

## Problem 3: Map Is Excluded from the Trait System

`Map` has kind `Type -> Type -> Type`. All collection traits expect `{C : Type -> Type}`. Result: Map cannot implement Seqable, Foldable, Buildable, or Functor. It has only the `Keyed` trait.

This means:

-   `gmap` doesn't work on Map
-   `gfold` doesn't work on Map
-   `gfilter` doesn't work on Map
-   The `Collection` bundle cannot be satisfied by Map
-   Map operations exist in their own silo (`map-ops.prologos`)

Clojure solves this by having `seq` on a map return a sequence of `[key value]` entries. Haskell solves it with `Bifunctor` and by only requiring `Functor` over the value type (partially applying the key type).


<a id="orgb2b74bf"></a>

## Problem 4: `Seq` Trait Is Underutilized

The `Seq` trait was designed as the universal sequence abstraction &mdash; the Clojure `ISeq` equivalent. It provides the fundamental protocol: `first`, `rest`, `empty?`.

Current state:

-   Only 2 instances: List and LSeq
-   NOT in the prelude (neither the trait, instances, nor `seq-functions`)
-   PVec and Set have NO `Seq` instance
-   No generic operations dispatch through `Seq`
-   The `Seqable` trait (convert to `LSeq`) dominates instead

The relationship between `Seq` and `Seqable` is confused:

-   `Seqable C` : "I can be converted to an `LSeq`" (batch, materializing)
-   `Seq S` : "I can be traversed element-by-element" (streaming, lazy)

These serve different purposes but the system only uses `Seqable`. The `Seq` trait should be the primary dispatch point for generic traversal, with `Seqable` as a convenience for bulk conversion.


<a id="org148c61c"></a>

## Problem 5: Functor Is Incomplete and Inconsistent

`Functor` has instances for List and PVec but NOT for Set or LSeq.

The Functor instances delegate to existing functions:

-   `list-functor` = `map` (from `prologos::data::list`)
-   `pvec-functor` = pvec-to-list → map → pvec-from-list

But `fmap` is not available as a dispatch point for generic code. No test uses `fmap` through the Functor dict in a polymorphic context.

More fundamentally, `Functor` provides `fmap : (A -> B) -> F A -> F B`, which changes the element type. For type-preserving operations like `filter` and `sort`, there's no corresponding trait. The system needs both:

-   `Functor` : transform elements, possibly changing type (`map`)
-   A `Filterable` or `Mappable` trait : transform while preserving collection type


<a id="org54bfe1a"></a>

## Problem 6: No Type-Preserving Generic Transformation

The current `gmap` signature:

```prologos
gmap : {A B : Type} {C : Type -> Type}
       [Seqable C] -> [Buildable C] -> [A -> B] -> [C A] -> [C B]
```

This IS type-preserving in theory: `gmap` on a `PVec Int` with `(Int -> String)` returns `PVec String`. But:

1.  It materializes through `LSeq` (losing structure)
2.  It requires two explicit dict arguments
3.  It doesn't specialize to efficient implementations

The user's stated goal: "A function over a collection of type `C` should return the same collection type `C`." The infrastructure exists but is not ergonomic.


<a id="org288ef95"></a>

## Problem 7: No `flat-map` / `concat-map` Generic

`concat-map` exists for List only. There is no generic `flat-map` that works across collection types. This is a critical gap for monadic-style programming:

```prologos
;; Desired:
|> users
  flat-map .:orders      ;; User -> [List Order], flattened across all users
  filter .:active?
  map .:total

;; Not possible generically today
```


<a id="orgb152a61"></a>

## Problem 8: Missing Operations Across Types

| Operation   | List | PVec | Set | Map | LSeq |
|----------- |---- |---- |--- |--- |---- |
| map         | ✓    | ✓    | ✓   | ✓\* | ✓    |
| filter      | ✓    | ✓    | ✓   | ✓\* | ✓    |
| fold/reduce | ✓    | ✓    | ✓   | ✓\* | ✓    |
| any?        | ✓    | ✓    | ✓   | ✗   | ✗    |
| all?        | ✓    | ✓    | ✓   | ✗   | ✗    |
| find        | ✓    | ✗    | ✗   | ✗   | ✗    |
| zip         | ✓    | ✗    | ✗   | ✗   | ✗    |
| sort        | ✓    | ✗    | n/a | ✗   | ✗    |
| flat-map    | ✓    | ✗    | ✗   | ✗   | ✗    |
| take/drop   | ✓    | ✗    | n/a | ✗   | ✓    |
| group-by    | ✗    | ✗    | ✗   | ✗   | ✗    |
| partition   | ✓    | ✗    | ✗   | ✗   | ✗    |
| count       | ✓    | ✗    | ✗   | ✗   | ✗    |
| distinct    | ✓    | ✗    | n/a | ✗   | ✗    |
| intersperse | ✓    | ✗    | n/a | ✗   | ✗    |
| reverse     | ✓    | ✗    | n/a | ✗   | ✗    |

`✓*` = Map has its own version (`map-map-vals`, `map-filter-vals`, `map-fold-entries`) `n/a` = doesn't make sense for this type (Set is unordered, etc.)

List has ~50+ operations. PVec has 7. Set has 7. Map has 6. LSeq has 9. The asymmetry is stark.


<a id="orgebde58d"></a>

## Problem 9: Test Coverage Is Type-Inference Only

A subtle but important gap: most collection trait/ops tests verify only that the *type* of the operation is correct (checking the result string contains "Pi" and "PVec"). They do NOT verify that the operation produces the correct *value*.

| Module        | Type tests | Eval tests | Coverage quality |
|------------- |---------- |---------- |---------------- |
| pvec-ops      | 5          | 0          | Types only       |
| set-ops       | 5          | 0          | Types only       |
| map-ops       | 5          | 0          | Types only       |
| generic-ops   | 8          | 9          | Partial eval     |
| conversions   | 4          | 7          | Good             |
| list.prologos | n/a        | extensive  | Gold standard    |

`pvec-map`, `set-filter`, `map-merge` etc. have ZERO correctness tests.


<a id="org2a09862"></a>

## Problem 10: Transducers Are Orphaned

The transducer infrastructure (`map-xf`, `filter-xf`, `xf-compose`, `transduce`, `into-list`) exists and is tested (28 test cases), but:

-   NOT in the prelude
-   Only works with List (the `into-list` runner)
-   No `into-vec`, `into-set`, `into-map` transducer runners
-   Not integrated with the pipe (`|>`) fusion system

The block-form `|>` already does map/filter fusion for List. Transducers should extend this to all collection types.


<a id="orga43259e"></a>

# Design Decisions (Agreed)

*Updated 2026-02-23 after design review. These are final decisions, not proposals.*


<a id="org12c4cf2"></a>

## Decision 1: Generic Shadowing (Path C) — AGREED

Generic `map`, `filter`, `reduce` shadow prelude List versions. Dispatch via trait resolver. Type-specific versions remain as expert escape hatches (`list::map`, `pvec::map`, etc.).

```prologos
;; After: just works on any collection
map inc @[1 2 3]        ;; => @[2 3 4] : PVec Nat
filter even? #{1 2 3 4} ;; => #{2 4} : Set Nat
reduce + '[1 2 3]       ;; => 6 : Nat (identity from :identity or trait)
```

Implementation: New module `prologos::core::collection-fns` with `where` constraints. The trait resolver auto-fills dicts at call sites.

```prologos
(ns prologos::core::collection-fns :no-prelude)

spec map : {A B : Type} {C : Type -> Type}
           where (Seqable C) (Buildable C)
           [A -> B] -> [C A] -> [C B]
defn map [f xs]
  from-seq [lseq-map f [to-seq xs]]

spec filter : {A : Type} {C : Type -> Type}
              where (Seqable C) (Buildable C)
              [A -> Bool] -> [C A] -> [C A]
defn filter [pred xs]
  from-seq [lseq-filter pred [to-seq xs]]
```

**Performance note**: Generic dispatch is only as fast as the trait instances. Once native instances exist (Decision 4), this generic `map` on PVec resolves to `pvec-foldable` which calls native RRB traversal. Zero conversion overhead.

The prelude imports generic versions *after* List versions, so generic shadows List-specific. `list::map` remains available for direct use.

**Dispatch for novices**: The generic functions auto-dispatch against the concrete type. A novice writes `map inc @[1 2 3]` and gets native PVec performance. An expert writes `pvec::map inc @[1 2 3]` for direct control. The novice path *is* the efficient path.


<a id="orgc0f4e8f"></a>

## Decision 2: MapEntry Type — AGREED (Clojure-Style)

New `MapEntry K V` deftype lets Map participate in the sequence world. This resolves the HKT kind mismatch (`Type -> Type -> Type` vs `Type -> Type`) at the data level, not the type system level.

```prologos
;; New type in prologos::data::map-entry
deftype MapEntry (K : Type) (V : Type)
  mk-entry : K -> V -> MapEntry K V

spec entry-key : {K V : Type} [MapEntry K V] -> K
spec entry-val : {K V : Type} [MapEntry K V] -> V

;; Dot-access support:
;; e.key  => entry-key e
;; e.val  => entry-val e
```

**Why not reuse Pair?** `Pair` is positional (`fst`, `snd`); `MapEntry` is semantic (`entry-key`, `entry-val`). Clojure distinguishes MapEntry from Vector for the same reason. MapEntry can have specialized printing (`[:a 1]`) and participate in pattern matching with key/value semantics.

**Bridge functions**:

```prologos
spec map-seq     : {K V : Type} [Map K V] -> [LSeq [MapEntry K V]]
spec map-from-seq : {K V : Type} [LSeq [MapEntry K V]] -> [Map K V]

;; Usage in pipe:
|> {:a 1 :b 2 :c 3}
  map-seq
  lseq-filter [fn [e] [> [entry-val e] 1]]
  map-from-seq
;; => {:b 2 :c 3}
```

**Future**: Once MapEntry exists, `Map K` could implement `Seqable` as `Seqable (Map K)` producing `LSeq (MapEntry K V)`. This brings Map into the generic `map~/~filter~/~reduce` world. But the bridge functions come first as the ergonomic foundation.


<a id="org11a4b70"></a>

## Decision 3: `reduce` (not `fold`) with Identity Resolution — AGREED

`reduce` is the primary name for left-fold. Two forms:

```prologos
;; 2-arg: identity auto-resolved at compile time
reduce + '[1 2 3]        ;; => 6 (identity: 0 from + spec or AdditiveIdentity)

;; 3-arg: explicit identity
reduce + 100 '[1 2 3]    ;; => 106
```

**Two-level identity fallback**:

1.  Check the function's `spec` for an `:identity` metadata key
2.  If the function resolves to a trait method, check sibling traits for identity (e.g., `Add.add` → `AdditiveIdentity.additive-identity`)
3.  If both fail → compile-time error with clear message

```prologos
spec add : {A : Type} where (Add A) A -> A -> A
  :identity 0
  :doc "Addition with additive identity"
```

`foldr` remains for right-folds. No bare `fold` name.

**Implementation**: The elaborator handles the 2-arg → 3-arg rewrite. When it sees `(reduce f xs)` with 2 explicit args, it:

1.  Looks up `f`'s spec entry via `spec-entry-metadata`
2.  Extracts `:identity` if present → inserts as init argument
3.  Falls back to trait identity lookup via the bundle graph
4.  Emits clear E-code error if neither resolves


<a id="org30942da"></a>

## Decision 4: Efficient Native Trait Instances — AGREED (Do Now)

**No deferral**. Build native AST primitives for PVec, Set, and Map traversal now. Push efficiency into the trait instances so generic dispatch IS efficient.

The principle: *completeness over deferral*. We have the clarity and context. Building half the system and deferring the performance infrastructure means we'll forget to come back, or lose context when we do.


<a id="org9c60f13"></a>

### PVec (RRB-Tree backend) — 3 new AST primitives

-   `expr-pvec-fold` : traverse leaf arrays left-to-right, apply step. Single pass.
-   `expr-pvec-map` : traverse leaves, apply f, build new RRB. Single pass + result.
-   `expr-pvec-filter` : traverse leaves, test pred, collect. Single pass + result.


<a id="org1ce92f6"></a>

### Set (CHAMP backend) — 2 new AST primitives

-   `expr-set-fold` : traverse CHAMP trie nodes, apply step. Single pass.
-   `expr-set-filter` : traverse nodes, test pred, rebuild. Single pass.


<a id="org7ac746e"></a>

### Map (CHAMP backend) — 3 new AST primitives

-   `expr-map-fold-entries` : traverse CHAMP visiting key-value pairs.
-   `expr-map-filter-entries` : traverse + rebuild.
-   `expr-map-map-vals` : traverse, apply f to values, rebuild with same keys.

Each primitive touches the 14-file AST pipeline (~8 primitives × 14 files). This is substantial but mechanical — the pattern is identical each time.

**The payoff**: Trait instances become thin wrappers:

```prologos
;; Foldable PVec instance — delegates to native fold
def pvec-foldable : Foldable PVec
  (fn A B step init pvec (pvec-fold A B step init pvec))  ;; native, single pass

;; NOT: (fn A B step init pvec (foldr A B step init (pvec-to-list A pvec)))
```

Then generic `reduce + @[1 2 3]` → resolver fills `Foldable PVec` → `pvec-foldable` → native `pvec-fold`. Full efficiency, no conversion.


<a id="org4e2adfd"></a>

## Decision 5: `into` as Elaborator Keyword — AGREED

`into` is recognized by the elaborator at compile time. When the first argument is an empty collection literal, it is consumed as a type indicator &mdash; zero runtime cost.

```prologos
into @[] #{3 1 2}       ;; Set → PVec — zero-cost (no empty PVec allocated)
into #{} '[1 2 1 3]     ;; List → Set
into '[] @[1 2 3]       ;; PVec → List
into {} [mk-entry :a 1, mk-entry :b 2]  ;; entries → Map
```

**Elaborator behavior**: When it sees `(into <empty-lit> source)`:

1.  Pattern-match on `expr-pvec-empty` / `expr-set-empty` / `expr-map-empty` / empty List → extract target type constructor
2.  Resolve `Seqable` for source type, `Buildable` for target type
3.  Rewrite to `from-seq<Target> (to-seq<Source> source)`
4.  The empty literal is never allocated at runtime

**Function mode fallback**: When the first argument is not a literal (it's a variable), `into` falls through to runtime dispatch via `Buildable` dict. Same dual-mode as `+` (elaborator specializes on literals, generic otherwise).

**Pipe integration**:

```prologos
|> #{1 2 3 4 5}
  map inc
  filter even?
  into @[]      ;; Set → PVec at the end
;; => @[2 4 6] : PVec Nat
```


<a id="org7812fed"></a>

## Decision 6: Naming — Generic `map` Shadows Prelude — AGREED

Generic `map` replaces the unqualified `map` in the prelude. `prologos::data::list` retains its `map`; prelude import ordering gives the generic version priority. Users wanting the List-specific version use `list::map`. Same pattern for `filter`, `reduce`, `any?`, `all?`, etc.

No `map` / `Map` naming conflict: the type is capitalized (`Map`), the function is lowercase (`map`). Prologos is case-sensitive.


<a id="orgc8bc466"></a>

# Gaps in Infrastructure


<a id="orgae94f61"></a>

## Gap 1: No Auto-Resolved Generic Operations

The `gmap~/~gfilter~/~gfold` functions require explicit trait dictionary arguments. The trait resolver CAN resolve these automatically when the concrete type is known, but the function signatures place the dicts as explicit parameters. Fixing this requires either:

-   New wrapper functions with `where` constraints (lightweight)
-   Trait resolver enhancement to auto-insert dicts at call sites (heavier)


<a id="org30d3672"></a>

## Gap 2: No `Seq` Instances for PVec or Set

PVec and Set cannot be traversed element-by-element via the `Seq` protocol. They can be converted to `LSeq` (via `Seqable`), but this materializes the entire sequence. Adding `Seq` instances would enable streaming operations (short-circuiting `any?`, `find`, etc.) without full materialization.


<a id="org6b899a9"></a>

## Gap 3: Map Cannot Participate in Generic Operations

The HKT kind mismatch (`Type -> Type -> Type` vs `Type -> Type`) locks Map out of Seqable, Foldable, Buildable, and all generic ops. Entry-sequence bridge functions (`map-to-entries`, `map-from-entries`) would provide an explicit conversion path.


<a id="orge5b1f45"></a>

## Gap 4: No `Filterable` Trait

`filter` is not captured by any trait. It's implemented per-type in each ops module. A `Filterable` trait would enable generic dispatch:

```prologos
trait Filterable {C : Type -> Type}
  cfilter : Pi [A :0 <Type>] [-> [-> A Bool] [-> [C A] [C A]]]
```

Alternatively, `filter` can be built from `Seqable + Buildable` (as `gfilter` already does), making a separate trait unnecessary if auto-dispatch works.


<a id="orgfaf1718"></a>

## Gap 5: No `flat-map` / `concat-map` Generic

List has `concat-map`. No other type does. Generic `flat-map` requires `Seqable + Buildable + Foldable` (sequence, transform, flatten, rebuild).


<a id="org31a4989"></a>

## Gap 6: `Seq` Trait and Functions Not in Prelude

`seq-trait.prologos`, `seq-functions.prologos`, and `seq-list.prologos` are NOT loaded by the prelude. Users cannot use `Seq`-based operations without explicit `require`. This is inconsistent with the "progressive disclosure" principle &mdash; the most-general abstraction should be the default.


<a id="org08f89c3"></a>

## Gap 7: Transducers Not in Prelude or Integrated with Pipe

`transducer.prologos` (map-xf, filter-xf, xf-compose, transduce, into-list) is tested (28 cases) but not prelude-loaded and not integrated with the `|>` fusion system. The two fusion mechanisms (pipe block-form and transducers) exist in parallel without interop.


<a id="orgbbb40c9"></a>

## Gap 8: `Seq List` Instance Not Auto-Loaded

The prelude loads `seq-lseq` (Seq instance for LSeq) but NOT `seq-list` (Seq instance for List). This means List &mdash; the most commonly used collection type &mdash; doesn't have its `Seq` instance available by default.


<a id="orge65216a"></a>

## Gap 9: Eval Tests Missing for Collection Ops

`pvec-map`, `pvec-filter`, `set-map`, `set-filter`, `map-map-vals`, `map-filter-vals`, `map-merge` all have type-inference tests only. Zero eval tests verify correctness. `map-filter-vals` has no test at all.


<a id="orgf4d3ed7"></a>

## Gap 10: Stale Test Comments

Both `test-generic-ops-01.rkt` and `test-generic-ops-02.rkt` contain the comment "generic-ops.prologos module is not yet in the prelude" — this is false; `namespace.rkt` line 461 includes it. The inline `gen-ops-preamble` definitions in those test files are now redundant.


<a id="org3defccc"></a>

# Implementation Plan

*Principle: Completeness over deferral. Build the full solution now.*

The implementation is organized as a single coherent effort, not deferred phases. Dependencies dictate ordering, not risk appetite.


<a id="orgbb4959f"></a>

## Stage A: Foundation — Tests and Cleanup


<a id="orgbc36776"></a>

### A1. Eval Tests for All Existing Collection Ops

Add correctness tests (eval, not just type-inference) for every existing collection operation. This validates the foundation before we build on it.

-   `pvec-map`, `pvec-filter`, `pvec-fold`, `pvec-any?`, `pvec-all?`
-   `set-map`, `set-filter`, `set-fold`, `set-any?`, `set-all?`
-   `map-map-vals`, `map-filter-vals`, `map-fold-entries`, `map-merge`
-   `map-keys-list`, `map-vals-list`

*~2 test files, ~30 new test cases.*


<a id="orge0788f7"></a>

### A2. Fix Stale Test Comments

Remove "not yet in prelude" comments from `test-generic-ops-01.rkt` and `test-generic-ops-02.rkt`. Remove redundant inline `gen-ops-preamble`. *~2 file edits.*


<a id="org5ad2315"></a>

## Stage B: MapEntry Type and Map Bridge


<a id="org345bd1e"></a>

### B1. `MapEntry` Deftype

New file `prologos::data::map-entry`:

```prologos
(ns prologos::data::map-entry :no-prelude)

deftype MapEntry (K : Type) (V : Type)
  mk-entry : K -> V -> MapEntry K V

spec entry-key : {K V : Type} [MapEntry K V] -> K
spec entry-val : {K V : Type} [MapEntry K V] -> V
```

Requires `deftype` for `MapEntry`, pattern matching on `mk-entry`. Dot-access: `e.key` → `[entry-key e]`, `e.val` → `[entry-val e]`. *~1 new .prologos file, ~10 tests.*


<a id="org6408ebe"></a>

### B2. Map Bridge Functions

New or updated `map-ops.prologos`:

```prologos
spec map-seq      : {K V : Type} [Map K V] -> [LSeq [MapEntry K V]]
spec map-from-seq : {K V : Type} [LSeq [MapEntry K V]] -> [Map K V]
```

`map-seq` iterates via `map-fold-entries`, building `MapEntry` values. `map-from-seq` folds over the LSeq inserting entries into an empty map. *~1 module update, ~12 tests.*


<a id="org49a3a09"></a>

### B3. Add MapEntry and Bridge to Prelude

Update `namespace.rkt` to load `map-entry` and the bridge functions. *~1 file edit, ~5 regression tests.*


<a id="orgb48842c"></a>

## Stage C: Native AST Primitives (~8 new primitives)

This is the 14-file-per-primitive work. Mechanical but essential.


<a id="orge210414"></a>

### C1. `expr-pvec-fold` — PVec native fold

Traverse RRB-Tree leaf arrays left-to-right, apply step function. Single pass, no allocation. This is the simplest primitive (no rebuild). *14-file pipeline + ~15 tests.*


<a id="org0ead11a"></a>

### C2. `expr-pvec-map` — PVec native map

Traverse leaves, apply f, build new RRB from mapped leaves. *14-file pipeline + ~10 tests.*


<a id="org0f6baee"></a>

### C3. `expr-pvec-filter` — PVec native filter

Traverse leaves, test predicate, collect passing elements into new RRB. *14-file pipeline + ~10 tests.*


<a id="org209f232"></a>

### C4. `expr-set-fold` — Set native fold

Traverse CHAMP trie nodes, apply step function. Single pass. *14-file pipeline + ~10 tests.*


<a id="org2738980"></a>

### C5. `expr-set-filter` — Set native filter

Traverse CHAMP nodes, test pred, rebuild trie without failing elements. *14-file pipeline + ~10 tests.*


<a id="org189d3e0"></a>

### C6. `expr-map-fold-entries` — Map native entry fold (upgrade existing)

Currently `map-fold-entries` exists but goes through List. Upgrade to native CHAMP traversal visiting key-value pairs directly. *14-file pipeline + ~10 tests.*


<a id="org9e14cb1"></a>

### C7. `expr-map-filter-entries` — Map native entry filter

Traverse CHAMP, test predicate on entries, rebuild. *14-file pipeline + ~10 tests.*


<a id="org15859a0"></a>

### C8. `expr-map-map-vals` — Map native value mapping

Traverse CHAMP, apply f to values, rebuild with same keys. *14-file pipeline + ~10 tests.*


<a id="org61e2797"></a>

## Stage D: Efficient Trait Instances

*Depends on: Stage C (native primitives).*


<a id="org06a9573"></a>

### D1. Replace PVec Foldable Instance

Current: `fold f init pvec = fold f init (pvec-to-list pvec)` (3 traversals) New: `fold f init pvec = pvec-fold f init pvec` (1 traversal) *1 file edit + regression.*


<a id="org37c3d30"></a>

### D2. Replace PVec Functor Instance

Current: `fmap f pvec = pvec-from-list (map f (pvec-to-list pvec))` New: `fmap f pvec = pvec-map f pvec` *1 file edit + regression.*


<a id="org6f7ee2b"></a>

### D3. Replace Set Foldable Instance

Same pattern: delegate to `set-fold` native. *1 file edit + regression.*


<a id="org194f059"></a>

### D4. Replace pvec-ops / set-ops / map-ops Implementations

Rewrite `pvec-map`, `pvec-filter`, `set-map`, `set-filter`, `map-map-vals`, `map-filter-vals` to use native primitives instead of List conversion. *~3 file edits + regression.*


<a id="org04ba8e4"></a>

## Stage E: `reduce` with Identity Resolution


<a id="org9649b1e"></a>

### E1. Add `:identity` Spec Metadata Handling

The spec system already stores arbitrary metadata keys. Add elaborator logic to extract `:identity` values from `spec-entry-metadata`. *~elaborator.rkt changes.*


<a id="orge187d22"></a>

### E2. Annotate Trait Method Specs with `:identity`

Add `:identity 0` to `Add.add`, `:identity 1` to `Mul.mul`, etc. *~5-10 .prologos file edits.*


<a id="org2d10fff"></a>

### E3. Implement 2-arg / 3-arg `reduce` Dispatch

In `collection-fns` module:

```prologos
spec reduce : {A B : Type} {C : Type -> Type}
              where (Foldable C)
              [A -> B -> B] -> B -> [C A] -> B
  :doc "Left fold with explicit identity"

;; 2-arg version (elaborator-assisted):
;; reduce f xs → reduce f (identity-of f) xs
;; where identity-of checks :identity then trait graph
```

The 2-arg → 3-arg rewrite is an elaborator transform. *~elaborator.rkt + 1 module + ~20 tests.*


<a id="orgcb2944f"></a>

## Stage F: Generic Collection Functions Module

*Depends on: Stage D (efficient instances).*


<a id="orgccc9698"></a>

### F1. Create `prologos::core::collection-fns`

Generic `map`, `filter`, `reduce`, `any?`, `all?`, `flat-map`, `concat`, `find`, `take`, `drop`, `zip`, `sort`, `group-by`, `partition`, `count`, `distinct`, `intersperse`, `reverse`.

All with `where` constraints, trait resolver fills dicts automatically. *~1 new module, ~60 tests.*


<a id="org3a18651"></a>

### F2. Prelude Shadowing

Update `namespace.rkt` to import `collection-fns` AFTER List-specific versions. Generic `map~/~filter~/~reduce` shadow List versions.

Critical regression: `map inc '[1 2 3]` must still work (resolver sees `List`, resolves `Seqable List` + `Buildable List` automatically). *~1 file edit, full regression run.*


<a id="org95bc355"></a>

## Stage G: `into` Elaborator Keyword


<a id="org655ddb1"></a>

### G1. Add `into` to Elaborator

Teach the elaborator to recognize `(into <empty-lit> source)`:

1.  Pattern-match on `expr-pvec-empty` / `expr-set-empty` / `expr-map-empty`
2.  Extract target type constructor
3.  Rewrite to `from-seq<Target> (to-seq<Source> source)`
4.  Function-mode fallback for non-literal first args

*~elaborator.rkt + parser.rkt (if keyword) + ~20 tests.*


<a id="orgff83f40"></a>

### G2. Pipe Integration

Ensure `into @[]` works as a pipe step:

```prologos
|> #{1 2 3 4 5}
  map inc
  filter even?
  into @[]
;; => @[2 4 6] : PVec Nat
```

*~5 tests.*


<a id="org3791c33"></a>

## Stage H: Seq Protocol Expansion


<a id="org6c4d6e4"></a>

### H1. `Seq` Instances for PVec and Set

Implement `Seq PVec` and `Seq Set` via delegation to native fold (now efficient from Stage D). `rest` returns `LSeq` (semantically correct). *~2 instance files, ~10 tests.*


<a id="orgaede9fa"></a>

### H2. Add Seq, seq-functions to Prelude

Load `seq-trait`, `seq-list`, `seq-lseq`, `seq-pvec`, `seq-set`, and `seq-functions`. Makes `first`, `rest`, `empty?` available generically. *~namespace.rkt + ~5 tests.*


<a id="org378fdcf"></a>

### H3. Streaming Operations via Seq

`any?`, `all?`, `find`, `take`, `drop` dispatch through `Seq` for short-circuiting behavior (no materialization). *~5 function updates + ~15 tests.*


<a id="org1905873"></a>

## Stage I: Transducer Integration (if time permits)


<a id="org5429e93"></a>

### I1. Transducer Runners for PVec/Set/Map

`into-vec`, `into-set`, `into-map` transducer runners. *~3 new functions + ~15 tests.*


<a id="orgb4b46f3"></a>

### I2. Pipe Macro Auto-Fusion for Non-List

Extend `|>` block-form to detect non-List input, build transducer chain, use `transduce` with appropriate reducer. *~macros.rkt changes + ~15 tests.*


<a id="orga252baf"></a>

## Deferred (Genuine Dependencies on Unbuilt Infrastructure)

These items are deferred because they require type system features that don't yet exist, not because of effort avoidance.


<a id="org8efb467"></a>

### HKT Partial Application for Map Trait Instances

Enable `Map K` as `Type -> Type` constructor. Requires type-system-level partial application support. *Tracked in DEFERRED.md.*


<a id="org1cf873d"></a>

### `Seq` as Proper Trait (deftype → trait migration)

Enables trait resolver auto-dispatch for Seq. Requires careful refactoring of the deftype/trait boundary. *Tracked in DEFERRED.md.*


<a id="org2a8777a"></a>

### Sorted Collections (`SortedMap`, `SortedSet`)

B+ tree or red-black tree backends. Requires backend infrastructure. *Tracked in DEFERRED.md.*


<a id="org6def27d"></a>

### Parallel Collection Operations

Racket places/futures for large collections. Requires runtime changes. *Tracked in DEFERRED.md.*


<a id="orgf40f905"></a>

# Alignment with Design Principles


<a id="orga5d4eef"></a>

## The Most Generalizable Interface

The design principles state: "Seq (lazy sequence) as the universal collection abstraction &mdash; all collections convert through LSeq as a hub type." The current system partially achieves this via `Seqable`, but generic operations still require explicit dict-passing. Phase 2's auto-dispatching `map` / `filter` / `fold` fully realizes this principle.

The principles also state: "Traits over concrete types &mdash; `Foldable` over List-specific folds." Phase 2 replaces the List-specific `fold` with a generic `Foldable`-dispatched `fold` in the prelude, achieving this directly.


<a id="orgbadc9ab"></a>

## Decomplection: Collections and Backends

The design principles state: "Collection abstractions are decoupled from their concrete backends &mdash; users program against traits; implementations are swappable." The trait infrastructure supports this, but the ergonomics don't: users currently call `pvec-map` (coupled to the PVec backend) instead of `map` (decoupled). Phase 2 completes the decomplection by making the generic interface the default.


<a id="org736a72b"></a>

## Progressive Disclosure

The design principles state: "Features should disappear until you need them." Currently, a beginner must learn about `pvec-map` vs `set-map` vs `map` vs `gmap` to work with different collections. After Phase 2, `map` works on everything. The type-specific versions become the expert escape hatch (like `int+` vs `+` in the numerics story).


<a id="org47a59d9"></a>

## Homoiconicity

All proposed changes preserve the homoiconicity invariant. Generic `map` is a function (not a macro), so it has a direct sexp representation. Pipe fusion is a compile-time optimization that doesn't affect the quoted representation.


<a id="org7d4ddae"></a>

# Summary Table

| Stage | Work Item                           | Effort | Depends On |
|----- |----------------------------------- |------ |---------- |
| A1    | Eval tests for collection ops       | Small  | —          |
| A2    | Stale test comment cleanup          | Tiny   | —          |
| B1    | MapEntry deftype                    | Small  | —          |
| B2    | Map bridge functions (map-seq)      | Small  | B1         |
| B3    | MapEntry + bridge in prelude        | Tiny   | B2         |
| C1    | `expr-pvec-fold` native primitive   | Medium | —          |
| C2    | `expr-pvec-map` native primitive    | Medium | —          |
| C3    | `expr-pvec-filter` native primitive | Medium | —          |
| C4    | `expr-set-fold` native primitive    | Medium | —          |
| C5    | `expr-set-filter` native primitive  | Medium | —          |
| C6    | `expr-map-fold-entries` upgrade     | Medium | —          |
| C7    | `expr-map-filter-entries` primitive | Medium | —          |
| C8    | `expr-map-map-vals` primitive       | Medium | —          |
| D1-D4 | Replace trait instances + ops       | Small  | C1-C8      |
| E1-E3 | `reduce` with identity resolution   | Medium | —          |
| F1    | Generic collection-fns module       | Medium | D1-D4      |
| F2    | Prelude generic shadowing           | Small  | F1         |
| G1    | `into` elaborator keyword           | Medium | —          |
| G2    | Pipe integration for `into`         | Small  | G1         |
| H1    | Seq instances for PVec/Set          | Small  | D1-D4      |
| H2    | Seq + seq-functions in prelude      | Small  | H1         |
| H3    | Streaming ops via Seq               | Medium | H2         |
| I1-I2 | Transducer integration (stretch)    | Medium | F1, G1     |

**Critical path**: A → C → D → F → prelude integration → regression. Stages B, E, G, H can be done in parallel with the critical path.

**Total estimated new tests**: ~250-300. **Total estimated AST pipeline touches**: ~8 primitives × 14 files.


<a id="orgcea70d1"></a>

# What Success Looks Like

After full implementation, a user can write:

```prologos
ns my-data-pipeline

;; Generic map — works on any collection type, native efficient
map inc @[1 2 3]            ;; => @[2 3 4] : PVec Nat  (native RRB traversal)
map inc '[1 2 3]            ;; => '[2 3 4] : List Nat
filter even? #{1 2 3 4}    ;; => #{2 4} : Set Nat     (native CHAMP rebuild)
reduce + '[1 2 3]           ;; => 6 : Nat  (identity auto-resolved from +)
reduce + 100 @[1 2 3]      ;; => 106 : Nat  (explicit identity)

;; Type-preserving: input PVec → output PVec
spec double-all : {C : Type -> Type} where (Collection C) [C Nat] -> [C Nat]
defn double-all [xs] [map [fn [x] [+ x x]] xs]

double-all @[1 2 3]     ;; => @[2 4 6] : PVec Nat
double-all '[1 2 3]     ;; => '[2 4 6] : List Nat
double-all #{1 2 3}     ;; => #{2 4 6} : Set Nat

;; Pipe-friendly with into
|> #{1 2 3 4 5 6 7 8 9 10}
  filter even?
  map [fn [x] [* x x]]
  into @[]
;; => @[4 16 36 64 100] : PVec Nat

;; Map via MapEntry sequences
|> {:a 1 :b 2 :c 3}
  map-seq
  lseq-filter [fn [e] [> [entry-val e] 1]]
  map-from-seq
;; => {:b 2 :c 3} : Map Keyword Nat

;; Seq-based streaming (short-circuits)
any? even? @[1 3 4 5 7]   ;; => true (stops at 4)
find even? '[1 3 5 7 8 9]  ;; => some 8 (stops at 8)

;; Generic into — type from literal syntax
into @[] #{3 1 2}    ;; Set → PVec
into #{} '[1 2 1 3]  ;; List → Set (deduplicates)
into '[] @[1 2 3]    ;; PVec → List

;; reduce with identity from spec
spec my-add : Nat -> Nat -> Nat
  :identity 0N
defn my-add [x y] [+ x y]
reduce my-add @[1 2 3 4 5]  ;; => 15 (identity 0N from spec)
```

This is the most-generic interface: one set of function names, all collection types, type-preserving dispatch, native-efficient, streaming when possible. Type-specific operations (`pvec::map`, `set::filter`) remain as expert escape hatches. The progression:

1.  *Beginner*: `map`, `filter`, `reduce`, `into` &mdash; just works, efficient
2.  *Intermediate*: `where (Collection C)` &mdash; write generic functions
3.  *Expert*: `pvec::map`, `Seqable` dicts, transducers &mdash; direct control
