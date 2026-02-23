- [Why We Track and Document Efforts](#orgb9f454d)
- [Workflow Lessons](#orgd427271)
  - [Phase-Gated Implementation](#org7e050ca)
  - [Tracking Documents Before Code](#orgaa4c66b)
  - [Deferred Work Is Real Work](#org6f8ec43)
  - [Targeted Testing During Development](#org9b77da2)
  - [Whale File Splitting](#org3e9c5af)
- [Type System Lessons](#orgc39379b)
  - [Two-Phase Zonking](#org812ee28)
  - [Speculative Type-Checking](#org75ccad2)
  - [Dict Params Use `:w`, Not `:0`](#orgbd08ef1)
  - [Meta Variables in `infer-level`](#org5421f78)
  - [Pattern Unification Boundaries](#org8b211aa)
- [Parser and Syntax Lessons](#orgf37090d)
  - [Parser Keywords Are Sacred](#org2f50125)
  - [WS Reader `$` Is Quote](#org66dd016)
  - [Nested Bracket Arrow Syntax](#orgf8fe57b)
  - [Consumer-Side Normalization](#org4a766a1)
- [Trait and Instance Lessons](#org736581c)
  - [Single-Method Trait = The Function](#orgb56ace5)
  - [Instance Registration Is a Side Effect](#org70f1e7f)
  - [Own-Definition Priority](#orgee83b39)
  - [Prelude Errors Are Silently Swallowed](#org139b0aa)
- [Collection and Library Lessons](#orge56180f)
  - [Map Can't Use Standard Traits](#org375171c)
  - [Type Constructors Aren't Terms](#org6145f01)
  - [`inferQ` Returns Result Type](#org63c1dfd)
  - [Library Function Names Don't Repeat Module Names](#orgcd52997)
- [Numerics Lessons](#org99c8d06)
  - [`expr->impl-key-str` Must Handle All Types](#orgedda8a6)
  - [Posit Widening Through Exact](#org8903269)
  - [Into Blanket Impl Pattern](#org11b9979)
- [Homoiconicity Lessons](#orgfea8881)
  - [Both Modes Must Produce Identical ASTs](#orgc44992e)
  - [Quote Roundtrips Must Preserve Structure](#org1a2608c)
  - [Quasiquote Comma Conflict](#orgad6cf4d)
- [Architecture Lessons](#orgd6ec9f3)
  - [14-File AST Pipeline](#org37d839f)
  - [Callback Pattern for Circular Dependencies](#org044ca9d)
  - [Sentinel AST Nodes](#orgf848fac)
- [Meta-Lessons](#orgfbb67f9)
  - [Let Pain Drive Design](#orgf5e6a0f)
  - [Tests Are Documentation](#org6f5282b)
  - [Grammar Is Living](#org18097a3)



<a id="orgb9f454d"></a>

# Why We Track and Document Efforts

Language implementation is a long journey with compounding decisions. Every design choice constrains future choices. Every bug reveals an assumption. Every workaround reveals an abstraction gap. By tracking lessons systematically, we:

1.  **Avoid repeating mistakes** &#x2014; the same meta-variable pitfall doesn't bite twice
2.  **Preserve institutional knowledge** &#x2014; when context windows reset, the lessons survive
3.  **Inform future design** &#x2014; patterns that recur across subsystems suggest deeper abstractions
4.  **Measure progress** &#x2014; timing data, test counts, and phase completions give concrete signals


<a id="orgd427271"></a>

# Workflow Lessons


<a id="org7e050ca"></a>

## Phase-Gated Implementation

Break large features into lettered sub-phases (a, b, c&#x2026;) with explicit "done" vs. "remaining" tracking. This:

-   Prevents scope creep within a single session
-   Creates natural commit points
-   Makes it easy to resume after interruption


<a id="orgaa4c66b"></a>

## Tracking Documents Before Code

Create `docs/tracking/YYYY-MM-DD_HHMM_TOPIC.md` *before* implementation. Write down what you plan to build, what the phases are, and what success looks like. Update after completion with lessons learned.


<a id="org6f8ec43"></a>

## Deferred Work Is Real Work

When something is deferred, immediately add it to `docs/tracking/DEFERRED.md`. Deferred work that isn't tracked is forgotten work. The DEFERRED file is the single source of truth for all postponed tasks.


<a id="org9b77da2"></a>

## Targeted Testing During Development

Run only affected tests (`racket tools/run-affected-tests.rkt`), not the full suite. The full suite is for end-of-day regression. This keeps the feedback loop tight (seconds, not minutes).


<a id="org3e9c5af"></a>

## Whale File Splitting

Test files exceeding 30s wall time bottleneck the parallel runner. Split into `-01`, `-02` parts with `20 test-cases each. Check with ~racket tools/benchmark-tests.rkt --slowest 10` after full runs.


<a id="orgc39379b"></a>

# Type System Lessons


<a id="org812ee28"></a>

## Two-Phase Zonking

Intermediate zonking must NOT default unsolved metas &#x2014; it would commit to wrong answers before all information is available. Only final zonking (after type-checking completes) defaults metas to `lzero` / `mw`.

This was a painful lesson: defaulting too early caused "spooky action at a distance" where solving one meta would silently lock in defaults for unrelated metas.


<a id="org75ccad2"></a>

## Speculative Type-Checking

`save-meta-state` / `restore-meta-state!` enables try-and-backtrack: attempt a type check, and if it fails, restore the meta-variable store to its prior state. Critical for:

-   Church fold type inference (try fold interpretation, fall back to list)
-   Union type widening (try homogeneous, widen if mismatched)
-   Trait resolution (try one instance, backtrack to another)


<a id="orgbd08ef1"></a>

## Dict Params Use `:w`, Not `:0`

Trait dictionary parameters must have unrestricted (`:w`) multiplicity. If they're erased (`:0`), the body can't call the dict's methods at runtime. This caused cryptic QTT violations until the invariant was established.


<a id="org5421f78"></a>

## Meta Variables in `infer-level`

Every AST node that appears in type position must have an `infer-level` case. When we added mixed-type maps, unsolved metas appeared in `expr-map-empty` type annotations, and `infer-level` had no case for `expr-meta`. The fix: unsolved metas default to `just-level(lzero)`, matching zonk-final's behavior.


<a id="org8b211aa"></a>

## Pattern Unification Boundaries

Miller's pattern fragment (the decidable subset of higher-order unification) handles most practical cases, but higher-rank types push beyond it. The workaround for higher-rank polymorphism: use explicit `def ... : Type body` instead of `spec~/~defn` when the type is too complex for inference.


<a id="orgf37090d"></a>

# Parser and Syntax Lessons


<a id="org2f50125"></a>

## Parser Keywords Are Sacred

Names like `map-vals`, `set-member?` are parser keywords &#x2014; the parser recognizes them at read time before name resolution. A library function with the same name will be shadowed in unqualified usage. Solutions:

-   Use qualified access: `m::map-vals`
-   Choose a non-conflicting name for the library function


<a id="org66dd016"></a>

## WS Reader `$` Is Quote

The `$` prefix in whitespace mode is the quote operator: `$Foo` desugars to `($quote Foo)`. It is NOT a sigil for variable names. This tripped up dict parameter naming when traits were first implemented.


<a id="orgf8fe57b"></a>

## Nested Bracket Arrow Syntax

`[B -> [K -> [V -> B]]]` fails to parse (inner brackets create separate argument groups). The flattened form `[B -> K -> V -> B]` works correctly. This is a consequence of Prologos's uncurried convention.


<a id="org4a766a1"></a>

## Consumer-Side Normalization

When special characters (`...`, `>>`, `|`) have readtable conflicts, normalize on the consumer side (parser/elaborator) rather than hacking the readtable. This is safer and keeps the reader simple.


<a id="org736581c"></a>

# Trait and Instance Lessons


<a id="orgb56ace5"></a>

## Single-Method Trait = The Function

When a trait has exactly one method, the dict IS the function. No wrapper struct, no field access. `(Add Nat)` resolves directly to the Nat addition function. This gives zero-overhead dispatch for the common case.


<a id="org70f1e7f"></a>

## Instance Registration Is a Side Effect

`(require [prologos::core::eq-nat :refer []])` loads the module for its side effect (registering the Eq instance for Nat). The empty `:refer []` signals "I don't need any names, just register the instances."


<a id="orgee83b39"></a>

## Own-Definition Priority

When the user defines `def map ...` in their module, it shadows the prelude's `list::map`. This is intentional: user definitions always win. Qualified access (`list::map`) remains available.


<a id="org139b0aa"></a>

## Prelude Errors Are Silently Swallowed

`process-ns-declaration` wraps module loading in `with-handlers` that silently catches errors. When a prelude module fails to load, the only signal is that its names are missing. This made debugging prelude changes extremely difficult. Future improvement: log prelude loading errors.


<a id="orge56180f"></a>

# Collection and Library Lessons


<a id="org375171c"></a>

## Map Can't Use Standard Traits

`Map K V` has two type parameters, but `Seqable`, `Foldable`, and `Buildable` expect `{C : Type -> Type}` (one parameter). This is a fundamental HKT limitation. The workaround: standalone functions in `map-ops` that operate directly on `Map K V`.


<a id="org6145f01"></a>

## Type Constructors Aren't Terms

`(infer Add)` doesn't work because `Add` is a type constructor (deftype), not a term. To test type constructors, use a typed binding: `(def x : (Add Nat) val)`.


<a id="org63c1dfd"></a>

## `inferQ` Returns Result Type

For AST keyword nodes (like `expr-map-get`, `expr-set-insert`), `inferQ` must return the RESULT type, not the input type. Getting this wrong causes the QTT checker to track multiplicities against the wrong type, leading to phantom violations.


<a id="orgcd52997"></a>

## Library Function Names Don't Repeat Module Names

When `prologos::core::map-ops` exports `map-keys-list`, the user writes `m::map-keys-list` &#x2014; "map" appears twice. Better: export `keys`, user writes `m::keys`. This lesson drove the map-ops rename.


<a id="org99c8d06"></a>

# Numerics Lessons


<a id="orgedda8a6"></a>

## `expr->impl-key-str` Must Handle All Types

The trait instance dispatch function must have cases for every numeric type (`Int`, `Rat`, `Posit8`, `Posit16`, `Posit32`, `Posit64`, `Keyword`). A missing case causes silent dispatch failure with an unhelpful error.


<a id="org8903269"></a>

## Posit Widening Through Exact

Converting between posit sizes goes through exact rational: `p16-from-rat (p8-to-rat x)`. This preserves as much precision as the target format allows.


<a id="org11b9979"></a>

## Into Blanket Impl Pattern

`impl Into A B where (From A B)` provides the reverse direction automatically using parametric constraint resolution. This halves the number of conversion instances needed.


<a id="orgfea8881"></a>

# Homoiconicity Lessons


<a id="orgc44992e"></a>

## Both Modes Must Produce Identical ASTs

The whitespace reader and the s-expression reader must produce bit-identical ASTs. This is tested extensively and is a hard invariant. Any divergence means macros behave differently depending on input mode.


<a id="org1a2608c"></a>

## Quote Roundtrips Must Preserve Structure

`'[fn [x] [add x 1N]]` must produce a `Datum` value that, when reconstructed, yields the original expression. This is the foundation for code-as-data metaprogramming.


<a id="orgad6cf4d"></a>

## Quasiquote Comma Conflict

Racket's reader consumes commas before our readtable sees them. The solution: a nested readtable (`prologos-qq-readtable`) that handles unquoting within quasiquoted expressions.


<a id="orgd6ec9f3"></a>

# Architecture Lessons


<a id="org37d839f"></a>

## 14-File AST Pipeline

Adding a new AST node requires touching 14 files (syntax, surface-syntax, parser, elaborator, typing-core, qtt, reduction, substitution, zonk, pretty-print, and sometimes unify, macros, foreign). This is the cost of a uniform AST representation &#x2014; but the benefit is that every subsystem handles every node consistently.


<a id="org044ca9d"></a>

## Callback Pattern for Circular Dependencies

When module A needs to call module B, but B already requires A, use a callback parameter: B exposes a function that takes a callback, and A provides the implementation at the call site. This avoids Racket's circular require limitation.


<a id="orgf848fac"></a>

## Sentinel AST Nodes

The reader emits sentinel nodes (`$dot-access`, `$dot-key`, `$pipe-gt`) that are rewritten by preparse into standard AST forms. This keeps the reader simple (it doesn't need to understand semantics) and the preparse predictable (it transforms known sentinels).


<a id="orgfbb67f9"></a>

# Meta-Lessons


<a id="orgf5e6a0f"></a>

## Let Pain Drive Design

Don't add features until they're needed. Every deferred item in `DEFERRED.md` was deferred because the pain wasn't yet sufficient to justify the complexity. When the pain arrives, the solution is better informed by real usage.


<a id="org6f5282b"></a>

## Tests Are Documentation

The test suite (3000+ tests) is the most accurate documentation of what the language actually does. When docs and tests disagree, tests win. New features aren't done until they have tests.


<a id="org18097a3"></a>

## Grammar Is Living

`docs/spec/grammar.ebnf` and `docs/spec/grammar.org` are canonical and must be updated whenever syntax changes. Stale grammar docs cause more confusion than no grammar docs.
