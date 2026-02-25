- [Why We Track and Document Efforts](#org2828266)
- [Workflow Lessons](#orge630dd0)
  - [Phase-Gated Implementation](#org13c1d5d)
  - [Tracking Documents Before Code](#org20df8bc)
  - [Deferred Work Is Real Work](#org38c8d3f)
  - [Targeted Testing During Development](#org7491317)
  - [Whale File Splitting](#org4551797)
- [Type System Lessons](#orgf222a4b)
  - [Two-Phase Zonking](#orgdea21d7)
  - [Speculative Type-Checking](#org2a97d73)
  - [Dict Params Use `:w`, Not `:0`](#org1b39bf6)
  - [Meta Variables in `infer-level`](#org0d23146)
  - [Pattern Unification Boundaries](#orgb3dc668)
- [Parser and Syntax Lessons](#orga488eeb)
  - [Parser Keywords Are Sacred](#org8849b22)
  - [WS Reader `$` Is Quote](#org2720b3e)
  - [Nested Bracket Arrow Syntax](#org04087e9)
  - [Consumer-Side Normalization](#org7f223d7)
- [Trait and Instance Lessons](#orgc5fd76e)
  - [Single-Method Trait = The Function](#org4318f28)
  - [Instance Registration Is a Side Effect](#orge2dceb0)
  - [Own-Definition Priority](#org5b129c8)
  - [Prelude Errors Are Silently Swallowed](#orgffe0987)
- [Collection and Library Lessons](#orgb82e0b0)
  - [Map Can't Use Standard Traits](#org0ec6bf2)
  - [Type Constructors Aren't Terms](#org2a06123)
  - [`inferQ` Returns Result Type](#org69c30d3)
  - [Library Function Names Don't Repeat Module Names](#orgbdea7bb)
- [Numerics Lessons](#orgc7bbb4a)
  - [`expr->impl-key-str` Must Handle All Types](#org24d7f89)
  - [Posit Widening Through Exact](#org1c2c6df)
  - [Into Blanket Impl Pattern](#org64cccde)
- [Homoiconicity Lessons](#org86140cb)
  - [Both Modes Must Produce Identical ASTs](#org779ca6b)
  - [Quote Roundtrips Must Preserve Structure](#org1a54240)
  - [Quasiquote Comma Conflict](#org027594b)
- [Architecture Lessons](#orgb080eae)
  - [14-File AST Pipeline](#org11edd53)
  - [Callback Pattern for Circular Dependencies](#orgf24af79)
  - [Sentinel AST Nodes](#org94af709)
- [Meta-Lessons](#org9d30f41)
  - [Completeness Over Deferral](#orgfe65b6c)
  - [Let Pain Drive Design](#orgd386880)
  - [Tests Are Documentation](#orgd3c2c63)
  - [Grammar Is Living](#org7e12a95)



<a id="org2828266"></a>

# Why We Track and Document Efforts

Language implementation is a long journey with compounding decisions. Every design choice constrains future choices. Every bug reveals an assumption. Every workaround reveals an abstraction gap. By tracking lessons systematically, we:

1.  **Avoid repeating mistakes** &#x2014; the same meta-variable pitfall doesn't bite twice
2.  **Preserve institutional knowledge** &#x2014; when context windows reset, the lessons survive
3.  **Inform future design** &#x2014; patterns that recur across subsystems suggest deeper abstractions
4.  **Measure progress** &#x2014; timing data, test counts, and phase completions give concrete signals


<a id="orge630dd0"></a>

# Workflow Lessons

For the full design-to-implementation lifecycle, see [DESIGN<sub>METHODOLOGY.org</sub>](DESIGN_METHODOLOGY.md) &#x2014; the five-phase process (Research → Refinement → Design Iteration → Implementation → Composition) that governs how we approach significant features.


<a id="org13c1d5d"></a>

## Phase-Gated Implementation

Break large features into lettered sub-phases (a, b, c&#x2026;) with explicit "done" vs. "remaining" tracking. This:

-   Prevents scope creep within a single session
-   Creates natural commit points
-   Makes it easy to resume after interruption


<a id="org20df8bc"></a>

## Tracking Documents Before Code

Create `docs/tracking/YYYY-MM-DD_HHMM_TOPIC.md` *before* implementation. Write down what you plan to build, what the phases are, and what success looks like. Update after completion with lessons learned.


<a id="org38c8d3f"></a>

## Deferred Work Is Real Work

When something is deferred, immediately add it to `docs/tracking/DEFERRED.md`. Deferred work that isn't tracked is forgotten work. The DEFERRED file is the single source of truth for all postponed tasks.


<a id="org7491317"></a>

## Targeted Testing During Development

Run only affected tests (`racket tools/run-affected-tests.rkt`), not the full suite. The full suite is for end-of-day regression. This keeps the feedback loop tight (seconds, not minutes).


<a id="org4551797"></a>

## Whale File Splitting

Test files exceeding 30s wall time bottleneck the parallel runner. Split into `-01`, `-02` parts with `20 test-cases each. Check with ~racket tools/benchmark-tests.rkt --slowest 10` after full runs.


<a id="orgf222a4b"></a>

# Type System Lessons


<a id="orgdea21d7"></a>

## Two-Phase Zonking

Intermediate zonking must NOT default unsolved metas &#x2014; it would commit to wrong answers before all information is available. Only final zonking (after type-checking completes) defaults metas to `lzero` / `mw`.

This was a painful lesson: defaulting too early caused "spooky action at a distance" where solving one meta would silently lock in defaults for unrelated metas.


<a id="org2a97d73"></a>

## Speculative Type-Checking

`save-meta-state` / `restore-meta-state!` enables try-and-backtrack: attempt a type check, and if it fails, restore the meta-variable store to its prior state. Critical for:

-   Church fold type inference (try fold interpretation, fall back to list)
-   Union type widening (try homogeneous, widen if mismatched)
-   Trait resolution (try one instance, backtrack to another)


<a id="org1b39bf6"></a>

## Dict Params Use `:w`, Not `:0`

Trait dictionary parameters must have unrestricted (`:w`) multiplicity. If they're erased (`:0`), the body can't call the dict's methods at runtime. This caused cryptic QTT violations until the invariant was established.


<a id="org0d23146"></a>

## Meta Variables in `infer-level`

Every AST node that appears in type position must have an `infer-level` case. When we added mixed-type maps, unsolved metas appeared in `expr-map-empty` type annotations, and `infer-level` had no case for `expr-meta`. The fix: unsolved metas default to `just-level(lzero)`, matching zonk-final's behavior.


<a id="orgb3dc668"></a>

## Pattern Unification Boundaries

Miller's pattern fragment (the decidable subset of higher-order unification) handles most practical cases, but higher-rank types push beyond it. The workaround for higher-rank polymorphism: use explicit `def ... : Type body` instead of `spec~/~defn` when the type is too complex for inference.


<a id="orga488eeb"></a>

# Parser and Syntax Lessons


<a id="org8849b22"></a>

## Parser Keywords Are Sacred

Names like `map-vals`, `set-member?` are parser keywords &#x2014; the parser recognizes them at read time before name resolution. A library function with the same name will be shadowed in unqualified usage. Solutions:

-   Use qualified access: `m::map-vals`
-   Choose a non-conflicting name for the library function


<a id="org2720b3e"></a>

## WS Reader `$` Is Quote

The `$` prefix in whitespace mode is the quote operator: `$Foo` desugars to `($quote Foo)`. It is NOT a sigil for variable names. This tripped up dict parameter naming when traits were first implemented.


<a id="org04087e9"></a>

## Nested Bracket Arrow Syntax

`[B -> [K -> [V -> B]]]` fails to parse (inner brackets create separate argument groups). The flattened form `[B -> K -> V -> B]` works correctly. This is a consequence of Prologos's uncurried convention.


<a id="org7f223d7"></a>

## Consumer-Side Normalization

When special characters (`...`, `>>`, `|`) have readtable conflicts, normalize on the consumer side (parser/elaborator) rather than hacking the readtable. This is safer and keeps the reader simple.


<a id="orgc5fd76e"></a>

# Trait and Instance Lessons


<a id="org4318f28"></a>

## Single-Method Trait = The Function

When a trait has exactly one method, the dict IS the function. No wrapper struct, no field access. `(Add Nat)` resolves directly to the Nat addition function. This gives zero-overhead dispatch for the common case.


<a id="orge2dceb0"></a>

## Instance Registration Is a Side Effect

`(require [prologos::core::eq-nat :refer []])` loads the module for its side effect (registering the Eq instance for Nat). The empty `:refer []` signals "I don't need any names, just register the instances."


<a id="org5b129c8"></a>

## Own-Definition Priority

When the user defines `def map ...` in their module, it shadows the prelude's `list::map`. This is intentional: user definitions always win. Qualified access (`list::map`) remains available.


<a id="orgffe0987"></a>

## Prelude Errors Are Silently Swallowed

`process-ns-declaration` wraps module loading in `with-handlers` that silently catches errors. When a prelude module fails to load, the only signal is that its names are missing. This made debugging prelude changes extremely difficult. Future improvement: log prelude loading errors.


<a id="orgb82e0b0"></a>

# Collection and Library Lessons


<a id="org0ec6bf2"></a>

## Map Can't Use Standard Traits

`Map K V` has two type parameters, but `Seqable`, `Foldable`, and `Buildable` expect `{C : Type -> Type}` (one parameter). This is a fundamental HKT limitation. The workaround: standalone functions in `map-ops` that operate directly on `Map K V`.


<a id="org2a06123"></a>

## Type Constructors Aren't Terms

`(infer Add)` doesn't work because `Add` is a type constructor (deftype), not a term. To test type constructors, use a typed binding: `(def x : (Add Nat) val)`.


<a id="org69c30d3"></a>

## `inferQ` Returns Result Type

For AST keyword nodes (like `expr-map-get`, `expr-set-insert`), `inferQ` must return the RESULT type, not the input type. Getting this wrong causes the QTT checker to track multiplicities against the wrong type, leading to phantom violations.


<a id="orgbdea7bb"></a>

## Library Function Names Don't Repeat Module Names

When `prologos::core::map-ops` exports `map-keys-list`, the user writes `m::map-keys-list` &#x2014; "map" appears twice. Better: export `keys`, user writes `m::keys`. This lesson drove the map-ops rename.


<a id="orgc7bbb4a"></a>

# Numerics Lessons


<a id="org24d7f89"></a>

## `expr->impl-key-str` Must Handle All Types

The trait instance dispatch function must have cases for every numeric type (`Int`, `Rat`, `Posit8`, `Posit16`, `Posit32`, `Posit64`, `Keyword`). A missing case causes silent dispatch failure with an unhelpful error.


<a id="org1c2c6df"></a>

## Posit Widening Through Exact

Converting between posit sizes goes through exact rational: `p16-from-rat (p8-to-rat x)`. This preserves as much precision as the target format allows.


<a id="org64cccde"></a>

## Into Blanket Impl Pattern

`impl Into A B where (From A B)` provides the reverse direction automatically using parametric constraint resolution. This halves the number of conversion instances needed.


<a id="org86140cb"></a>

# Homoiconicity Lessons


<a id="org779ca6b"></a>

## Both Modes Must Produce Identical ASTs

The whitespace reader and the s-expression reader must produce bit-identical ASTs. This is tested extensively and is a hard invariant. Any divergence means macros behave differently depending on input mode.


<a id="org1a54240"></a>

## Quote Roundtrips Must Preserve Structure

`'[fn [x] [add x 1N]]` must produce a `Datum` value that, when reconstructed, yields the original expression. This is the foundation for code-as-data metaprogramming.


<a id="org027594b"></a>

## Quasiquote Comma Conflict

Racket's reader consumes commas before our readtable sees them. The solution: a nested readtable (`prologos-qq-readtable`) that handles unquoting within quasiquoted expressions.


<a id="orgb080eae"></a>

# Architecture Lessons


<a id="org11edd53"></a>

## 14-File AST Pipeline

Adding a new AST node requires touching 14 files (syntax, surface-syntax, parser, elaborator, typing-core, qtt, reduction, substitution, zonk, pretty-print, and sometimes unify, macros, foreign). This is the cost of a uniform AST representation &#x2014; but the benefit is that every subsystem handles every node consistently.


<a id="orgf24af79"></a>

## Callback Pattern for Circular Dependencies

When module A needs to call module B, but B already requires A, use a callback parameter: B exposes a function that takes a callback, and A provides the implementation at the call site. This avoids Racket's circular require limitation.


<a id="org94af709"></a>

## Sentinel AST Nodes

The reader emits sentinel nodes (`$dot-access`, `$dot-key`, `$pipe-gt`) that are rewritten by preparse into standard AST forms. This keeps the reader simple (it doesn't need to understand semantics) and the preparse predictable (it transforms known sentinels).


<a id="org9d30f41"></a>

# Meta-Lessons


<a id="orgfe65b6c"></a>

## Completeness Over Deferral

When you have the clarity, the vision, and the full context &#x2014; finish the work now. Half-built pieces that get deferred are half-built pieces that get forgotten. The cost of re-acquiring context later almost always exceeds the cost of doing the work while the understanding is fresh.

This doesn't mean never defer &#x2014; sometimes layering and phasing is the only sensible approach. But the default should be: complete the solution. Defer only when there is a genuine dependency on unbuilt infrastructure or when the design is genuinely uncertain. "We'll come back to it" is a red flag; if the work is clear enough to describe, it's clear enough to do.

Corollary: when deferral *is* necessary, it must be immediately tracked in `DEFERRED.md`. Deferred work that isn't tracked is abandoned work.


<a id="orgd386880"></a>

## Let Pain Drive Design

Don't add features until they're needed. Every deferred item in `DEFERRED.md` was deferred because the pain wasn't yet sufficient to justify the complexity. When the pain arrives, the solution is better informed by real usage.


<a id="orgd3c2c63"></a>

## Tests Are Documentation

The test suite (3000+ tests) is the most accurate documentation of what the language actually does. When docs and tests disagree, tests win. New features aren't done until they have tests.


<a id="org7e12a95"></a>

## Grammar Is Living

`docs/spec/grammar.ebnf` and `docs/spec/grammar.org` are canonical and must be updated whenever syntax changes. Stale grammar docs cause more confusion than no grammar docs.
