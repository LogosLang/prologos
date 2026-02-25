- [Executive Summary](#org430ab85)
- [Current State: What Exists](#orgbc58176)
  - [Collection Types (5 Families)](#org6f809b7)
  - [Collection Traits (8 Traits)](#orgd33396d)
    - [The Collection Bundle](#org671c865)
  - [Operation Modules (7 Modules, ~60 Functions)](#org04b24e6)
  - [Current Generic Operation Surface](#org1704660)
    - [Path 1: Type-Specific (Concrete, Fast for List)](#org8e0102d)
    - [Path 2: Explicit-Dict Generic (Verbose, Complete)](#org6879c5f)
    - [Path 3: Conversion Hub (Explicit, Flexible)](#orge2f9343)
- [Critique: The Ergonomic Gap](#org4192838)
  - [Problem 1: No Auto-Dispatching Generic `map` / `filter` / `fold`](#org2bdde2b)
  - [Problem 2: All Non-List Operations Go Through List Conversion](#org7a57381)
  - [Problem 3: Map Is Excluded from the Trait System](#orgf80a728)
  - [Problem 4: `Seq` Trait Is Underutilized](#org8d6ecde)
  - [Problem 5: Functor Is Incomplete and Inconsistent](#org54369a2)
  - [Problem 6: No Type-Preserving Generic Transformation](#org70fefdb)
  - [Problem 7: No `flat-map` / `concat-map` Generic](#org5a7347a)
  - [Problem 8: Missing Operations Across Types](#org9bdafb3)
  - [Problem 9: Test Coverage Is Type-Inference Only](#org82abe35)
  - [Problem 10: Transducers Are Orphaned](#orga1faa4e)
- [Design Decisions and Tradeoffs](#orgb7a82b4)
  - [Decision 1: Auto-Dispatching `map` / `filter` / `fold` via Trait Resolution](#org094a76e)
    - [Path A: Redefine `map` as a Generic Keyword (like `+` for numerics)](#org9801618)
    - [Path B: Use `where` Constraints with Bundle Shorthand](#org9887039)
    - [Path C: Shadow Prelude `map` with a Generic Version (Recommended)](#orga891f41)
  - [Decision 2: What to Do About Map](#org0534b0c)
    - [Approach A: Partial Application (`Map K` as `Type -> Type`)](#orgcc51725)
    - [Approach B: Separate `KVSeqable` / `KVFoldable` Traits](#org4fb2462)
    - [Approach C: Clojure-Style Entry Sequences (Recommended)](#org6770d1f)
  - [Decision 3: Seq as the Primary Traversal Protocol](#orgabf298e)
  - [Decision 4: Efficient Native Implementations vs. List Conversion](#orgfaf363a)
  - [Decision 5: Pipe Fusion with Generic Collections](#orge4c2c4b)
  - [Decision 6: Naming Convention — `map` Ambiguity](#org99858bf)
- [Gaps in Infrastructure](#orgd026317)
  - [Gap 1: No Auto-Resolved Generic Operations](#orga001285)
  - [Gap 2: No `Seq` Instances for PVec or Set](#org904486d)
  - [Gap 3: Map Cannot Participate in Generic Operations](#orga45ee02)
  - [Gap 4: No `Filterable` Trait](#orgdf37a00)
  - [Gap 5: No `flat-map` / `concat-map` Generic](#orga60ddff)
  - [Gap 6: `Seq` Trait and Functions Not in Prelude](#orgccc84f0)
  - [Gap 7: Transducers Not in Prelude or Integrated with Pipe](#org4a31030)
  - [Gap 8: `Seq List` Instance Not Auto-Loaded](#org875a2b6)
  - [Gap 9: Eval Tests Missing for Collection Ops](#org11fb528)
  - [Gap 10: Stale Test Comments](#org1baacbc)
- [Recommendations](#orgd3657a8)
  - [Phase 1: Foundation Fixes (Low Risk, High Value)](#org6ec02c4)
    - [1a. Add Eval Tests for All Collection Ops](#orgcf1c685)
    - [1b. Add `Seq` Instances for PVec and Set](#org7b313b6)
    - [1c. Add `Seq` and `seq-functions` to Prelude](#org2a1f7eb)
    - [1d. Map Entry Bridge Functions](#org0557c81)
    - [1e. Fix Stale Test Comments](#org1a4126b)
  - [Phase 2: Auto-Dispatching Generic Ops (Medium Risk, Very High Value)](#org8860812)
    - [2a. Generic `map` / `filter` / `fold` with `where` Constraints](#org85cb1b0)
    - [2b. Prelude Shadowing: Generic `map` over List `map`](#org96c9c15)
    - [2c. Integrate `Seq` Protocol for Streaming Ops](#org0256e2a)
  - [Phase 3: Performance and Completeness (Higher Risk, High Value)](#orgdb80cf5)
    - [3a. Native PVec Operations](#orgd3385f4)
    - [3b. Native Set Operations](#org5defae6)
    - [3c. Transducer Integration with Pipe](#orgf11041f)
    - [3d. Missing Operations for Non-List Types](#org7acb2c1)
  - [Phase 4: Advanced (Future, Research)](#org89ce677)
    - [4a. HKT Partial Application for Map Trait Instances](#orgeb72ed5)
    - [4b. `Seq` as a Proper Trait](#orgd458bf8)
    - [4c. Sorted Collections](#org145932e)
    - [4d. Parallel Collection Operations](#org0b5badb)
- [Alignment with Design Principles](#org5bab059)
  - [The Most Generalizable Interface](#org8789eb1)
  - [Decomplection: Collections and Backends](#org900804d)
  - [Progressive Disclosure](#org010275e)
  - [Homoiconicity](#org0d03de4)
- [Summary Table](#orgd8d0793)
- [What Success Looks Like](#org6e2c4af)



<a id="org430ab85"></a>

# Executive Summary

This audit examines the gap between Prologos's *stated design goal* &#x2014; the most-generalizable interface with efficient dispatch &#x2014; and the *current reality* of its collection infrastructure. The findings: the trait foundation is architecturally sound (8 traits, 19 instances, 5 collection types), but the surface ergonomics force users into either type-specific operations (`pvec-map`, `set-filter`) or explicit-dictionary generic operations (`gmap` with `Seqable` and `Buildable` dicts). Neither path achieves the Clojure-like experience where `map`, `filter`, and `fold` simply *work* on any collection.

The core tension: Prologos's HKT trait system requires `{C : Type -> Type}` kind constraints, which excludes `Map` (two type params). All non-List collection operations go through List conversion, losing both type information and performance. And the `Seq` trait &#x2014; designed to be the universal sequence abstraction &#x2014; is barely wired into the system: only 2 instances (List, LSeq), not in the prelude, and no generic operations dispatch through it.

The recommendation is a phased approach: first, make existing generic ops auto-dispatch without explicit dicts (leveraging the trait resolver); second, introduce a `Mappable` trait for type-preserving transformations; third, extend the `Seq` protocol to all collections; fourth, add efficient native implementations that bypass the current List-conversion bottleneck.


<a id="orgbc58176"></a>

# Current State: What Exists


<a id="org6f809b7"></a>

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


<a id="orgd33396d"></a>

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


<a id="org671c865"></a>

### The Collection Bundle

```prologos
bundle Collection := (Seqable, Buildable, Foldable)
```

Conjunctive (AND), not implicative. Expands to three constraints at parse time. List, PVec, Set, and LSeq all satisfy `Collection`. Map does not.


<a id="org04b24e6"></a>

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


<a id="org1704660"></a>

## Current Generic Operation Surface

The user has three ways to transform collections:


<a id="org8e0102d"></a>

### Path 1: Type-Specific (Concrete, Fast for List)

```prologos
;; List — native, pattern-matched, O(n)
map inc '[1 2 3]          ;; => '[2 3 4] : List Nat

;; PVec — via List conversion, O(n) with 2 conversions
pvec-map inc @[1 2 3]     ;; => @[2 3 4] : PVec Nat

;; Set — via List conversion
set-map inc #{1 2 3}      ;; => #{2 3 4} : Set Nat
```


<a id="org6879c5f"></a>

### Path 2: Explicit-Dict Generic (Verbose, Complete)

```prologos
;; Requires knowing and passing trait dicts:
gmap List--Seqable--dict List--Buildable--dict inc '[1 2 3]
gmap PVec--Seqable--dict PVec--Buildable--dict inc @[1 2 3]
```


<a id="orge2f9343"></a>

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


<a id="org4192838"></a>

# Critique: The Ergonomic Gap


<a id="org2bdde2b"></a>

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


<a id="org7a57381"></a>

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


<a id="orgf80a728"></a>

## Problem 3: Map Is Excluded from the Trait System

`Map` has kind `Type -> Type -> Type`. All collection traits expect `{C : Type -> Type}`. Result: Map cannot implement Seqable, Foldable, Buildable, or Functor. It has only the `Keyed` trait.

This means:

-   `gmap` doesn't work on Map
-   `gfold` doesn't work on Map
-   `gfilter` doesn't work on Map
-   The `Collection` bundle cannot be satisfied by Map
-   Map operations exist in their own silo (`map-ops.prologos`)

Clojure solves this by having `seq` on a map return a sequence of `[key value]` entries. Haskell solves it with `Bifunctor` and by only requiring `Functor` over the value type (partially applying the key type).


<a id="org8d6ecde"></a>

## Problem 4: `Seq` Trait Is Underutilized

The `Seq` trait was designed as the universal sequence abstraction &#x2014; the Clojure `ISeq` equivalent. It provides the fundamental protocol: `first`, `rest`, `empty?`.

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


<a id="org54369a2"></a>

## Problem 5: Functor Is Incomplete and Inconsistent

`Functor` has instances for List and PVec but NOT for Set or LSeq.

The Functor instances delegate to existing functions:

-   `list-functor` = `map` (from `prologos::data::list`)
-   `pvec-functor` = pvec-to-list → map → pvec-from-list

But `fmap` is not available as a dispatch point for generic code. No test uses `fmap` through the Functor dict in a polymorphic context.

More fundamentally, `Functor` provides `fmap : (A -> B) -> F A -> F B`, which changes the element type. For type-preserving operations like `filter` and `sort`, there's no corresponding trait. The system needs both:

-   `Functor` : transform elements, possibly changing type (`map`)
-   A `Filterable` or `Mappable` trait : transform while preserving collection type


<a id="org70fefdb"></a>

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


<a id="org5a7347a"></a>

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


<a id="org9bdafb3"></a>

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


<a id="org82abe35"></a>

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


<a id="orga1faa4e"></a>

## Problem 10: Transducers Are Orphaned

The transducer infrastructure (`map-xf`, `filter-xf`, `xf-compose`, `transduce`, `into-list`) exists and is tested (28 test cases), but:

-   NOT in the prelude
-   Only works with List (the `into-list` runner)
-   No `into-vec`, `into-set`, `into-map` transducer runners
-   Not integrated with the pipe (`|>`) fusion system

The block-form `|>` already does map/filter fusion for List. Transducers should extend this to all collection types.


<a id="orgb7a82b4"></a>

# Design Decisions and Tradeoffs


<a id="org094a76e"></a>

## Decision 1: Auto-Dispatching `map` / `filter` / `fold` via Trait Resolution

*Proposed*: Introduce `map`, `filter`, and `fold` as generic operations that automatically resolve through the trait system, without requiring explicit dictionary arguments. When the collection type is known (which it usually is from the argument), the trait resolver selects the correct implementation.

```prologos
;; After: just works
map inc @[1 2 3]        ;; => @[2 3 4] : PVec Nat
filter even? #{1 2 3 4} ;; => #{2 4} : Set Nat
fold + 0 '[1 2 3]       ;; => 6 : Nat
```

*Implementation paths*:


<a id="org9801618"></a>

### Path A: Redefine `map` as a Generic Keyword (like `+` for numerics)

New parser keyword `map` that elaborates to a trait-dispatched call. When the concrete type is known, specialize to the type-specific version.

-   Pro: Single name, clean syntax, mirrors the `+` approach from numerics
-   Con: Conflicts with existing `map` from `prologos::data::list` in the prelude
-   Con: Parser keyword approach is heavyweight (14-file AST pipeline change)


<a id="org9887039"></a>

### Path B: Use `where` Constraints with Bundle Shorthand

Make `gmap` ergonomic by having the trait resolver auto-insert dicts:

```prologos
;; spec uses the Collection bundle:
spec my-transform : {C : Type -> Type} where (Collection C) [C Int] -> [C Int]
defn my-transform [xs] [gmap inc xs]  ;; resolver inserts Seqable/Buildable dicts
```

-   Pro: No new AST nodes, uses existing trait infrastructure
-   Con: Still requires the user to write `gmap` instead of `map`
-   Con: Doesn't help at the call site without a `where` in scope


<a id="orga891f41"></a>

### Path C: Shadow Prelude `map` with a Generic Version (Recommended)

Replace the prelude's `map` (currently List-only from `prologos::data::list`) with a generic `map` that dispatches via traits. The List-specific `map` remains available as `list::map` for direct use.

```prologos
;; In a new module, e.g., prologos::core::generic-collection-ops:
spec map : {A B : Type} {C : Type -> Type} where (Seqable C) (Buildable C)
           [A -> B] -> [C A] -> [C B]
defn map [f xs] [gmap f xs]  ;; trait resolver fills dicts

spec filter : {A : Type} {C : Type -> Type} where (Seqable C) (Buildable C)
              [A -> Bool] -> [C A] -> [C A]
defn filter [pred xs] [gfilter pred xs]

spec fold : {A B : Type} {C : Type -> Type} where (Foldable C)
            [A -> B -> B] -> B -> [C A] -> B
defn fold [f init xs] [gfold f init xs]
```

-   Pro: `map` just works on any collection type
-   Pro: Backwards compatible (List still works, just dispatches generically)
-   Pro: Uses existing trait infrastructure, no new AST nodes
-   Pro: Type-preserving: `map inc @[1 2 3]` returns `PVec Nat`
-   Con: List `map` performance may regress slightly (LSeq roundtrip)
-   Con: Name collision with List `map` requires careful prelude ordering

*Mitigation for performance*: Speculative specialization &#x2014; when the elaborator can see the concrete collection type, inline the type-specific implementation instead of going through LSeq.

*Tradeoff*: Path C is recommended because it achieves the stated goal ("the most-generalizable interface") without introducing new language machinery. The existing `gmap~/~gfilter` implementations become the backend; the new `map~/~filter` are thin wrappers with trait constraints.


<a id="org0534b0c"></a>

## Decision 2: What to Do About Map

Map's `Type -> Type -> Type` kind makes it incompatible with standard collection traits. Three approaches:


<a id="orgcc51725"></a>

### Approach A: Partial Application (`Map K` as `Type -> Type`)

Treat `Map K` as a `Type -> Type` constructor (fixing the key type):

```prologos
;; Map K satisfies Seqable, Foldable, Buildable when K is fixed
impl Seqable [Map K] where (Eq K)
  defn to-seq [m] [list-to-lseq [map-vals-list m]]  ;; sequence of values
```

-   Pro: Map can implement standard traits
-   Pro: `gmap f my-map` maps over values (natural for most use cases)
-   Con: Requires HKT partial application support in the trait resolver
-   Con: What about mapping over keys? Over entries?


<a id="org4fb2462"></a>

### Approach B: Separate `KVSeqable` / `KVFoldable` Traits

New traits for two-param containers:

```prologos
trait KVSeqable {C : Type -> Type -> Type}
  kv-to-seq : C K V -> LSeq [Pair K V]

trait KVFoldable {C : Type -> Type -> Type}
  kv-fold : [K -> V -> B -> B] -> B -> C K V -> B
```

-   Pro: Clean, no HKT partial application needed
-   Pro: Entry-level operations are natural (`kv-fold` gets both key and value)
-   Con: Doubles the trait count for a single type
-   Con: Generic ops need two versions (`gmap` and `kv-gmap`)


<a id="org6770d1f"></a>

### Approach C: Clojure-Style Entry Sequences (Recommended)

Map's `Seqable` implementation returns a sequence of key-value pairs:

```prologos
;; Map becomes seqable by producing Pair entries:
;; to-seq : Map K V -> LSeq [Pair K V]
;; from-seq : LSeq [Pair K V] -> Map K V
```

This requires a different kind signature for Map's Seqable instance. Since `Seqable` expects `{C : Type -> Type}`, we'd need either:

1.  A `MapEntry K V` wrapper type and `Seqable (MapEntry K)` &#x2014; awkward
2.  A separate `EntrySeqable` trait &#x2014; approach B in disguise
3.  Standalone functions (no trait) that convert Map to/from entry sequences

*Recommended*: For Phase 1, add standalone `map-to-entries` and `map-from-entries` functions that bridge Map to the sequence world:

```prologos
spec map-to-entries : {K V : Type} [Map K V] -> [LSeq [Pair K V]]
spec map-from-entries : {K V : Type} [LSeq [Pair K V]] -> [Map K V]
```

This gives users an explicit, composable bridge without overloading the trait system. Defer the HKT partial application question to a later phase when the type system can support it cleanly.


<a id="orgabf298e"></a>

## Decision 3: Seq as the Primary Traversal Protocol

*Proposed*: Elevate `Seq` to be the primary sequence protocol, used by all generic operations for element-by-element traversal. `Seqable` becomes the "convert to LSeq for bulk operations" trait; `Seq` becomes "I support first/rest/empty? directly."

Current state:

-   `Seq` has 2 instances (List, LSeq)
-   `Seqable` has 4 instances (List, PVec, Set, LSeq)
-   Generic ops use `Seqable` exclusively

Proposed state:

-   `Seq` has 5 instances (List, PVec, Set, LSeq, + Map via entry view)
-   `Seqable` remains for bulk conversion to `LSeq`
-   Generic operations dispatch through BOTH: `Seq` for streaming operations (`any?`, `all?`, `find`, `take`, `drop`), `Seqable+Buildable` for materializing operations (`map`, `filter`, `sort`)

*Tradeoff*:

-   Pro: `Seq` is the natural abstraction (Clojure's `ISeq`)
-   Pro: PVec/Set `Seq` instances can be efficient (no List conversion)
-   Pro: Streaming ops (`any?`, `find`) short-circuit without materializing
-   Con: `Seq` is a `deftype`, not a `trait` &#x2014; different dispatch mechanism
-   Con: Adding `Seq` instances for PVec and Set requires careful design (PVec traversal needs an index cursor; Set traversal needs an iterator)

*Mitigation*: Phase the rollout. Start with Seq instances for PVec and Set that delegate to `to-seq` (performance-neutral). Optimize with native iterators in a later phase.


<a id="orgfaf363a"></a>

## Decision 4: Efficient Native Implementations vs. List Conversion

*Proposed*: Replace List-conversion implementations with native operations for PVec and Set where the backend supports it.

Current: `pvec-map` does `pvec-from-list (map f (pvec-to-list v))` — three traversals.

Native alternative: The RRB-Tree backend supports O(n) in-place traversal of leaf arrays. A native `pvec-map` would:

1.  Traverse leaf arrays directly
2.  Apply `f` to each element
3.  Build the result RRB-Tree from mapped leaves

This requires new AST-level primitives (`expr-pvec-map`, `expr-pvec-filter`, etc.) touching the 14-file AST pipeline.

*Tradeoff*:

-   Pro: ~3x performance improvement for PVec/Set operations
-   Pro: Eliminates intermediate List allocation
-   Con: Significant implementation effort (14 files per new primitive)
-   Con: Each new primitive adds to the AST surface area

*Recommendation*: Defer native implementations to Phase 3+. The ergonomic improvements (auto-dispatch, type preservation) are far more valuable than raw performance in the current Phase 0 prototype. When profiling shows collection operations as a bottleneck, add native primitives for the hot paths.


<a id="orge4c2c4b"></a>

## Decision 5: Pipe Fusion with Generic Collections

The block-form `|>` already fuses consecutive `map~/~filter` on List into a single traversal. Extending this to generic collections requires:

1.  The pipe macro recognizes generic `map~/~filter` (not just List-specific)
2.  Fusion builds a transducer chain internally
3.  The final `into` step materializes into the original collection type

```prologos
;; Desired: fused single-pass, returns PVec
|> @[1 2 3 4 5]
  map inc
  filter even?
  into-vec
;; => @[2 4 6] : PVec Nat (single traversal)
```

*Tradeoff*:

-   Pro: Matches Clojure's transducer-based collection processing
-   Pro: O(n) regardless of chain length
-   Con: Pipe macro needs to know about collection types for auto-detection
-   Con: `into-vec` at the end breaks the "implicit type preservation" goal

*Recommendation*: Phase 2 work. The existing transducer infrastructure (`map-xf`, `filter-xf`, `xf-compose`, `transduce`) provides the backend. What's needed is: transducer runners for PVec/Set/Map, and pipe macro integration to auto-fuse when the input is a non-List collection.


<a id="org99858bf"></a>

## Decision 6: Naming Convention — `map` Ambiguity

`map` currently means two things:

1.  The higher-order function `map : (A -> B) -> List A -> List B`
2.  The collection type `Map K V`

Clojure avoids this because `map` is always the function and `hash-map` / `{}` is the type. In Prologos, the type is also called `Map` (capitalized), so the overlap is only at the conceptual level, not syntactic.

The real naming issue: when `map` becomes generic, the prelude needs to export the generic version, not the List-specific one. Users who want the List-specific version can use `list::map` (qualified import).

*Recommendation*: The generic `map` replaces the unqualified `map` in the prelude. `prologos::data::list` retains its `map` definition; prelude shadowing gives the generic version priority. This mirrors how Clojure's `clojure.core/map` shadows any namespace-specific `map`.


<a id="orgd026317"></a>

# Gaps in Infrastructure


<a id="orga001285"></a>

## Gap 1: No Auto-Resolved Generic Operations

The `gmap~/~gfilter~/~gfold` functions require explicit trait dictionary arguments. The trait resolver CAN resolve these automatically when the concrete type is known, but the function signatures place the dicts as explicit parameters. Fixing this requires either:

-   New wrapper functions with `where` constraints (lightweight)
-   Trait resolver enhancement to auto-insert dicts at call sites (heavier)


<a id="org904486d"></a>

## Gap 2: No `Seq` Instances for PVec or Set

PVec and Set cannot be traversed element-by-element via the `Seq` protocol. They can be converted to `LSeq` (via `Seqable`), but this materializes the entire sequence. Adding `Seq` instances would enable streaming operations (short-circuiting `any?`, `find`, etc.) without full materialization.


<a id="orga45ee02"></a>

## Gap 3: Map Cannot Participate in Generic Operations

The HKT kind mismatch (`Type -> Type -> Type` vs `Type -> Type`) locks Map out of Seqable, Foldable, Buildable, and all generic ops. Entry-sequence bridge functions (`map-to-entries`, `map-from-entries`) would provide an explicit conversion path.


<a id="orgdf37a00"></a>

## Gap 4: No `Filterable` Trait

`filter` is not captured by any trait. It's implemented per-type in each ops module. A `Filterable` trait would enable generic dispatch:

```prologos
trait Filterable {C : Type -> Type}
  cfilter : Pi [A :0 <Type>] [-> [-> A Bool] [-> [C A] [C A]]]
```

Alternatively, `filter` can be built from `Seqable + Buildable` (as `gfilter` already does), making a separate trait unnecessary if auto-dispatch works.


<a id="orga60ddff"></a>

## Gap 5: No `flat-map` / `concat-map` Generic

List has `concat-map`. No other type does. Generic `flat-map` requires `Seqable + Buildable + Foldable` (sequence, transform, flatten, rebuild).


<a id="orgccc84f0"></a>

## Gap 6: `Seq` Trait and Functions Not in Prelude

`seq-trait.prologos`, `seq-functions.prologos`, and `seq-list.prologos` are NOT loaded by the prelude. Users cannot use `Seq`-based operations without explicit `require`. This is inconsistent with the "progressive disclosure" principle &#x2014; the most-general abstraction should be the default.


<a id="org4a31030"></a>

## Gap 7: Transducers Not in Prelude or Integrated with Pipe

`transducer.prologos` (map-xf, filter-xf, xf-compose, transduce, into-list) is tested (28 cases) but not prelude-loaded and not integrated with the `|>` fusion system. The two fusion mechanisms (pipe block-form and transducers) exist in parallel without interop.


<a id="org875a2b6"></a>

## Gap 8: `Seq List` Instance Not Auto-Loaded

The prelude loads `seq-lseq` (Seq instance for LSeq) but NOT `seq-list` (Seq instance for List). This means List &#x2014; the most commonly used collection type &#x2014; doesn't have its `Seq` instance available by default.


<a id="org11fb528"></a>

## Gap 9: Eval Tests Missing for Collection Ops

`pvec-map`, `pvec-filter`, `set-map`, `set-filter`, `map-map-vals`, `map-filter-vals`, `map-merge` all have type-inference tests only. Zero eval tests verify correctness. `map-filter-vals` has no test at all.


<a id="org1baacbc"></a>

## Gap 10: Stale Test Comments

Both `test-generic-ops-01.rkt` and `test-generic-ops-02.rkt` contain the comment "generic-ops.prologos module is not yet in the prelude" — this is false; `namespace.rkt` line 461 includes it. The inline `gen-ops-preamble` definitions in those test files are now redundant.


<a id="orgd3657a8"></a>

# Recommendations


<a id="org6ec02c4"></a>

## Phase 1: Foundation Fixes (Low Risk, High Value)


<a id="orgcf1c685"></a>

### 1a. Add Eval Tests for All Collection Ops

Add correctness tests (eval, not just type-inference) for:

-   `pvec-map`, `pvec-filter`, `pvec-fold`, `pvec-any?`, `pvec-all?`
-   `set-map`, `set-filter`, `set-fold`, `set-any?`, `set-all?`
-   `map-map-vals`, `map-filter-vals`, `map-fold-entries`, `map-merge`
-   `map-keys-list`, `map-vals-list`

This validates the existing infrastructure before building on it. `Estimated: 2 test files, ~30 new test cases.`


<a id="org7b313b6"></a>

### 1b. Add `Seq` Instances for PVec and Set

Implement `Seq PVec` and `Seq Set` via delegation to `Seqable` (convert to LSeq, then use LSeq's `Seq` instance). This is not efficient but establishes the protocol:

```prologos
;; Seq instance for PVec — delegates to LSeq via Seqable
;; first: pvec -> lseq -> lseq-head
;; rest: pvec -> lseq -> lseq-rest (returns LSeq, not PVec)
```

Note: `rest` returning `LSeq` instead of `PVec` is semantically correct for the `Seq` protocol (sequences don't preserve collection type on `rest`). `Estimated: 2 instance files, ~10 tests.`


<a id="org2a1f7eb"></a>

### 1c. Add `Seq` and `seq-functions` to Prelude

Load `seq-trait`, `seq-list`, `seq-lseq`, `seq-pvec` (new), `seq-set` (new), and `seq-functions` into the prelude. This makes `seq-length`, `seq-any?`, `seq-all?`, `seq-find`, `seq-drop` available from `(ns foo)`. `Estimated: namespace.rkt changes, ~5 tests.`


<a id="org0557c81"></a>

### 1d. Map Entry Bridge Functions

Add `map-to-entries` and `map-from-entries` to `map-ops.prologos`:

```prologos
spec map-to-entries : {K V : Type} [Map K V] -> [LSeq [Pair K V]]
spec map-from-entries : {K V : Type} [LSeq [Pair K V]] -> [Map K V]
```

This gives Map an explicit path into the sequence world without overloading the trait system. `Estimated: 1 module, 1 prelude entry, ~8 tests.`


<a id="org1a4126b"></a>

### 1e. Fix Stale Test Comments

Update `test-generic-ops-01.rkt` and `test-generic-ops-02.rkt` to remove the stale "not yet in the prelude" comments. Consider removing the redundant inline `gen-ops-preamble` definitions since prelude integration tests already exist. `Estimated: 2 file edits.`


<a id="org8860812"></a>

## Phase 2: Auto-Dispatching Generic Ops (Medium Risk, Very High Value)


<a id="org85cb1b0"></a>

### 2a. Generic `map` / `filter` / `fold` with `where` Constraints

Create `prologos::core::generic-collection-fns` module with wrapper functions that have `where` constraints, allowing the trait resolver to auto-fill dicts:

```prologos
(ns prologos::core::generic-collection-fns :no-prelude)
(require [prologos::core::seqable-trait :refer-all])
(require [prologos::core::buildable-trait :refer-all])
(require [prologos::core::foldable-trait :refer-all])
;; ... instance imports ...

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

spec fold : {A B : Type} {C : Type -> Type}
            where (Foldable C)
            [A -> B -> B] -> B -> [C A] -> B

spec any? : {A : Type} {C : Type -> Type}
            where (Foldable C)
            [A -> Bool] -> [C A] -> Bool

spec all? : {A : Type} {C : Type -> Type}
            where (Foldable C)
            [A -> Bool] -> [C A] -> Bool

spec length : {A : Type} {C : Type -> Type}
              where (Seqable C)
              [C A] -> Nat

spec concat : {A : Type} {C : Type -> Type}
              where (Seqable C) (Buildable C)
              [C A] -> [C A] -> [C A]

spec flat-map : {A B : Type} {C : Type -> Type}
               where (Seqable C) (Buildable C)
               [A -> [C B]] -> [C A] -> [C B]
```

`Estimated: 1 new module, prelude update, ~40 new tests.`


<a id="org96c9c15"></a>

### 2b. Prelude Shadowing: Generic `map` over List `map`

Update the prelude to import the generic `map~/~filter~/~fold` AFTER the List-specific versions, so the generic versions shadow them. Users who want the List-specific versions use qualified `list::map`.

Critical: verify that `map inc '[1 2 3]` still works (trait resolver sees `List` and resolves `Seqable List` + `Buildable List` automatically).

`Estimated: namespace.rkt reordering, regression testing.`


<a id="org0256e2a"></a>

### 2c. Integrate `Seq` Protocol for Streaming Ops

For operations that don't need to rebuild a collection (`any?`, `all?`, `find`, `count`, `take`, `drop`), dispatch through `Seq` instead of `Seqable` to avoid materializing the entire sequence:

```prologos
spec any? : {A : Type} {S : Type -> Type} where (Seq S)
            [A -> Bool] -> [S A] -> Bool
;; Short-circuits without converting to LSeq first
```

This requires `Seq` to be a proper `trait` (not `deftype`) for the trait resolver to work. Consider migrating `Seq` from `deftype` to `trait`.

`Estimated: seq-trait refactor + 5 Seq-based generic functions.`


<a id="orgdb80cf5"></a>

## Phase 3: Performance and Completeness (Higher Risk, High Value)


<a id="orgd3385f4"></a>

### 3a. Native PVec Operations

Add AST-level primitives for PVec that bypass List conversion:

-   `expr-pvec-map` : traverse RRB-Tree leaves directly
-   `expr-pvec-filter` : traverse + rebuild
-   `expr-pvec-fold` : traverse leaves in order

Each requires touching the 14-file AST pipeline. Start with `pvec-fold` (simplest — no rebuild needed) as a proof of concept.

`Estimated: 14 files × 3 ops, ~20 tests each. Large effort.`


<a id="org5defae6"></a>

### 3b. Native Set Operations

Same pattern for Set (CHAMP trie traversal):

-   `expr-set-fold` : traverse CHAMP nodes
-   `expr-set-filter` : traverse + rebuild


<a id="orgf11041f"></a>

### 3c. Transducer Integration with Pipe

Extend the `|>` block-form macro to:

1.  Detect non-List input collections
2.  Build a transducer chain from consecutive `map~/~filter` steps
3.  Use `transduce` with the appropriate reducer for the output type

```prologos
;; Fused single-pass for PVec:
|> @[1 2 3 4 5]
  map inc
  filter even?
;; Compiles to: transduce (xf-compose (map-xf inc) (filter-xf even?)) pvec-conj (pvec-empty) v
```

Add transducer runners: `into-vec`, `into-set`, `into-map`.

`Estimated: macros.rkt changes, 3 new runners, ~20 tests.`


<a id="org7acb2c1"></a>

### 3d. Missing Operations for Non-List Types

For each operation in the gap table (Problem 8), implement either:

-   A generic version (via traits) if the operation makes sense across types
-   A type-specific version if the operation is type-dependent

Priority operations:

1.  `find` : generic via `Seq` (streaming, short-circuit)
2.  `flat-map` : generic via `Seqable + Buildable`
3.  `take` / `drop` : generic via `Seq`
4.  `zip` : generic via `Seq` (streaming)
5.  `sort` : for PVec only (List already has it)
6.  `group-by` : generic, returns `Map K [C V]`
7.  `partition` : generic via `Seqable + Buildable`

`Estimated: ~15 new functions across 2-3 modules.`


<a id="org89ce677"></a>

## Phase 4: Advanced (Future, Research)


<a id="orgeb72ed5"></a>

### 4a. HKT Partial Application for Map Trait Instances

Enable `Map K` to be treated as a `Type -> Type` constructor, allowing Map to implement standard collection traits (Seqable, Foldable, etc.) with the key type fixed. Requires type-system-level support for HKT partial application.


<a id="orgd458bf8"></a>

### 4b. `Seq` as a Proper Trait

Migrate `Seq` from `deftype` (manual Sigma assembly) to `trait` (auto dict construction). This enables the trait resolver to handle Seq instances like any other trait, enabling auto-dispatch.


<a id="org145932e"></a>

### 4c. Sorted Collections

Add `SortedMap` and `SortedSet` backed by B+ trees or red-black trees. These would implement `Indexed` (for ordered access) and a new `Sorted` trait that guarantees iteration order.


<a id="org0b5badb"></a>

### 4d. Parallel Collection Operations

For large collections, parallel `map~/~filter~/~fold` using Racket's places or futures. PVec's tree structure makes it natural for divide-and- conquer parallelism (split at internal nodes, process subtrees in parallel, merge results).


<a id="org5bab059"></a>

# Alignment with Design Principles


<a id="org8789eb1"></a>

## The Most Generalizable Interface

The design principles state: "Seq (lazy sequence) as the universal collection abstraction &#x2014; all collections convert through LSeq as a hub type." The current system partially achieves this via `Seqable`, but generic operations still require explicit dict-passing. Phase 2's auto-dispatching `map` / `filter` / `fold` fully realizes this principle.

The principles also state: "Traits over concrete types &#x2014; `Foldable` over List-specific folds." Phase 2 replaces the List-specific `fold` with a generic `Foldable`-dispatched `fold` in the prelude, achieving this directly.


<a id="org900804d"></a>

## Decomplection: Collections and Backends

The design principles state: "Collection abstractions are decoupled from their concrete backends &#x2014; users program against traits; implementations are swappable." The trait infrastructure supports this, but the ergonomics don't: users currently call `pvec-map` (coupled to the PVec backend) instead of `map` (decoupled). Phase 2 completes the decomplection by making the generic interface the default.


<a id="org010275e"></a>

## Progressive Disclosure

The design principles state: "Features should disappear until you need them." Currently, a beginner must learn about `pvec-map` vs `set-map` vs `map` vs `gmap` to work with different collections. After Phase 2, `map` works on everything. The type-specific versions become the expert escape hatch (like `int+` vs `+` in the numerics story).


<a id="org0d03de4"></a>

## Homoiconicity

All proposed changes preserve the homoiconicity invariant. Generic `map` is a function (not a macro), so it has a direct sexp representation. Pipe fusion is a compile-time optimization that doesn't affect the quoted representation.


<a id="orgd8d0793"></a>

# Summary Table

| Gap                             | Phase | Risk   | Value     | Effort  |
|------------------------------- |----- |------ |--------- |------- |
| Eval tests for collection ops   | 1a    | Low    | Med       | Small   |
| Seq instances for PVec/Set      | 1b    | Low    | Med       | Small   |
| Seq + seq-functions in prelude  | 1c    | Low    | Med       | Small   |
| Map entry bridge functions      | 1d    | Low    | Med       | Small   |
| Stale test comment cleanup      | 1e    | Low    | Low       | Tiny    |
| Auto-dispatch `map~/~filter`    | 2a    | Medium | Very High | Medium  |
| Prelude generic shadowing       | 2b    | Medium | Very High | Small   |
| Seq-based streaming ops         | 2c    | Medium | High      | Medium  |
| Native PVec operations          | 3a    | Higher | High      | Large   |
| Native Set operations           | 3b    | Higher | Med       | Large   |
| Transducer + pipe integration   | 3c    | Medium | High      | Medium  |
| Missing operations (find, etc.) | 3d    | Low    | High      | Medium  |
| HKT partial application for Map | 4a    | High   | High      | V.Large |
| Seq as proper trait             | 4b    | Medium | High      | Medium  |
| Sorted collections              | 4c    | Medium | Med       | Large   |
| Parallel collection ops         | 4d    | High   | Med       | V.Large |


<a id="org6e2c4af"></a>

# What Success Looks Like

After Phases 1-2, a user can write:

```prologos
ns my-data-pipeline

;; Generic map — works on any collection type
map inc @[1 2 3]            ;; => @[2 3 4] : PVec Nat
map inc '[1 2 3]            ;; => '[2 3 4] : List Nat
filter even? #{1 2 3 4}    ;; => #{2 4} : Set Nat
fold + 0 @[1 2 3]          ;; => 6 : Nat

;; Type-preserving: input PVec → output PVec
spec double-all : {C : Type -> Type} where (Collection C) [C Nat] -> [C Nat]
defn double-all [xs] [map [fn [x] [+ x x]] xs]

double-all @[1 2 3]     ;; => @[2 4 6] : PVec Nat
double-all '[1 2 3]     ;; => '[2 4 6] : List Nat
double-all #{1 2 3}     ;; => #{2 4 6} : Set Nat

;; Pipe-friendly
|> @[1 2 3 4 5 6 7 8 9 10]
  filter even?
  map [fn [x] [* x x]]
  fold + 0
;; => 220 : Nat

;; Map via entry sequences
|> {":a" 1 ":b" 2 ":c" 3}
  map-to-entries
  lseq-filter [fn [p] [> [snd p] 1]]
  map-from-entries
;; => {":b" 2 ":c" 3} : Map Keyword Nat

;; Seq-based streaming (short-circuits)
any? even? @[1 3 4 5 7]   ;; => true (stops at 4)
find even? '[1 3 5 7 8 9]  ;; => some 8 (stops at 8)

;; Higher-order: map is first-class
def transformer : [Nat -> Nat] -> [PVec Nat] -> [PVec Nat]
defn transformer [f xs] [map f xs]
```

This is the most-generic interface: one set of function names, all collection types, type-preserving dispatch, streaming when possible. The type-specific operations (`pvec-map`, `set-filter`) remain as expert escape hatches for when you need exact control. The progression:

1.  *Beginner*: `map`, `filter`, `fold` — just works
2.  *Intermediate*: `where (Collection C)` — write generic functions
3.  *Expert*: `pvec-map`, `Seqable`, transducers — direct control
