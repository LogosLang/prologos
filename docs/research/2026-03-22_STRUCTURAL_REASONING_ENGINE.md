- [The Insight](#org3f12428)
- [Why This Changes Everything](#org372abbd)
  - [The Elaborator Becomes Trivially Thin](#orgb55de06)
  - [Bidirectional Type Checking Dissolves](#orgc07867a)
  - [Six Cross-Cutting Concerns Simplify or Disappear](#org454799b)
    - [Zonk → Eliminated During Elaboration](#org67ec147)
    - [Ground-Check → Cell-Level Property](#org7cc783b)
    - [Occurs Check → Graph Cycle Detection](#orgec8d128)
    - [Error Reporting → Contradiction Cells](#org5fa4ffe)
    - [Incremental Re-Elaboration → Dependency-Tracked Propagation](#org90957f6)
    - [Speculation → Unified TMS](#org929cd12)
- [The Two-Layer Architecture](#orgdea85ec)
  - [Layer 1: Structural Reasoning Engine (Within-Domain)](#orga8a47e3)
  - [Layer 2: Galois Bridges (Between-Domain)](#orgb72a4e1)
- [How This Changes The Roadmap](#orgdc819ca)
  - [Before: Track-Per-System Migration](#org141eab9)
  - [After: Build the SRE, Then Each System Plugs In](#orgb969d7c)
  - [What The SRE Subsumes](#org9cdf97c)
  - [What The SRE Does NOT Subsume](#orgbc29015)
- [The SRE as Correct-by-Construction Infrastructure](#org2ba2a8f)
  - [Missing Decomposition Cases](#org10cb062)
  - [Inconsistent Structural Handling](#org603e9f2)
  - [Stale Cell Values](#org011dbdb)
- [Relationship to Existing Principles](#org1ba1c1c)
- [Next Steps](#org5928bd8)



<a id="org3f12428"></a>

# The Insight

PUnify was built as "the unification algorithm on propagators." But what it *actually* is, is a **structural reasoning engine** &mdash; given cell values with structure, decompose them into sub-relationships and install propagators that maintain those relationships bidirectionally.

"Unification" is a special case: asserting two cells must have the same structure, so decompose both and equate corresponding sub-cells. But the same mechanism handles:

-   **Composition**: building a Pi from a domain cell and codomain cell
-   **Decomposition**: extracting the domain and codomain cells from a Pi cell
-   **Matching**: checking whether a cell's value matches a structural pattern
-   **Inference**: propagating from known sub-cells to the parent, or from a known parent to sub-cells

All of these are "structural reasoning." The insight is that PUnify's structural decomposition propagators &mdash; `identify-sub-cell`, `get-or-create-sub-cells`, `make-pi-reconstructor`, `make-structural-unify-propagator` &mdash; are *not* unification-specific. They are the universal primitive for structural analysis on the propagator network.


<a id="org372abbd"></a>

# Why This Changes Everything


<a id="orgb55de06"></a>

## The Elaborator Becomes Trivially Thin

The current elaborator in `typing-core.rkt` manually creates cells and installs propagators for every AST node. For `(expr-app f x)`:

1.  Create fresh meta for result type
2.  Elaborate `f` to get type-of-f cell
3.  Elaborate `x` to get type-of-x cell
4.  Install propagator: type-of-f must be `Pi(type-of-x, result)`

Steps 2&ndash;4 are structural decomposition &mdash; exactly what the SRE does. With the SRE, elaborating `(expr-app f x)` becomes:

```racket
(structural-relate type-of-f-cell (Pi type-of-x-cell result-cell))
```

One call. The SRE creates decomposition propagators, handles the case where `type-of-f` is unsolved (propagation fires when it becomes known), and propagates bidirectionally. The elaborator doesn't install propagators &mdash; the SRE does, because structural decomposition IS its job.

Every elaboration case follows this pattern:

| AST Node       | SRE Call                                                 |
|-------------- |-------------------------------------------------------- |
| `(app f x)`    | `structural-relate(type(f), Pi(type(x), result))`        |
| `(lam x body)` | `structural-relate(type(lam), Pi(type(x), type(body)))`  |
| `(pair a b)`   | `structural-relate(type(pair), Sigma(type(a), type(b)))` |
| `(fst p)`      | `structural-relate(type(p), Sigma(result, _))`           |
| `(snd p)`      | `structural-relate(type(p), Sigma(_, result))`           |

The elaborator's *entire type inference job* is installing structural relationships between cells. That's what the SRE does.


<a id="orgc07867a"></a>

## Bidirectional Type Checking Dissolves

The classical distinction between `infer` (synthesize a type) and `check` (verify against a known type) partially dissolves. Both are `structural-relate` calls:

-   `infer(e)` = create fresh cell, `structural-relate(type(e), fresh)`
-   `check(e, T)` = `structural-relate(type(e), T)`

The SRE propagates in both directions. If `T` is known and `type(e)` is unknown, information flows from `T` to `type(e)` (checking mode). If `type(e)` is known and `T` is unknown, information flows from `type(e)` to `T` (inference mode). The *same propagator* handles both.

The bidirectional discipline is still useful for controlling elaboration order and providing good error messages &mdash; but it's no longer a fundamental architectural distinction. It's an elaboration *strategy* over the SRE, not a separate mechanism.


<a id="org454799b"></a>

## Six Cross-Cutting Concerns Simplify or Disappear


<a id="org67ec147"></a>

### Zonk → Eliminated During Elaboration

`zonk` exists because expressions contain `expr-meta` placeholders that must be substituted with solutions. With the SRE, metas ARE cells. Expressions reference cells. Cell values are always current via propagation. There's nothing to substitute &mdash; reading the cell IS reading the solution.

At command boundaries, `freeze` (a single-pass cell read) replaces `zonk` (a recursive expression walk). `1300 lines of ~zonk.rkt` → `200 lines of ~freeze`.


<a id="org7cc783b"></a>

### Ground-Check → Cell-Level Property

Currently `ground-expr?` walks an expression tree looking for `expr-meta` nodes. With the SRE, "groundness" is a cell-level property: a cell is ground when all sub-cells in its structural decomposition are ground.

This can be computed by a *groundness propagator* that watches sub-cells and transitions a groundness flag when all become ground. No expression walking. Groundness is structurally emergent from the SRE's decomposition topology.


<a id="orgec8d128"></a>

### Occurs Check → Graph Cycle Detection

Currently implemented as an expression walk during unification. With the SRE, it becomes a graph property: does cell A appear in cell A's structural decomposition? This is cycle detection in the cell dependency graph &mdash; a structural property of the network, not an algorithmic check.


<a id="org5fa4ffe"></a>

### Error Reporting → Contradiction Cells

Type errors are currently constructed by zonking types and formatting. With the SRE, contradictions are structural: when `structural-relate` produces inconsistent values (e.g., `Int` meets `Bool` in the same cell), the contradiction is recorded in the cell with provenance (which propagators contributed which values, via TMS).

Error reporting reads contradiction cells. No zonking. Error messages are derived from the structural decomposition path: "expected Pi because application at line 5, but got Int from annotation at line 3."


<a id="org90957f6"></a>

### Incremental Re-Elaboration → Dependency-Tracked Propagation

Currently re-elaborating a definition requires redoing the whole command. With the SRE, modifying a definition's type cell triggers re-propagation through all structural relationships that reference it. The SRE's dependency graph IS the incremental compilation graph.

LSP "re-check on edit" falls out of the SRE's propagation semantics. No separate incremental compilation infrastructure.


<a id="org929cd12"></a>

### Speculation → Unified TMS

The SRE's structural decomposition propagators participate in the same TMS as everything else. Speculative decompositions are tagged with assumption IDs. On retraction, the SRE's sub-cells from the failed branch become invisible (worldview-aware reads). No separate speculation mechanism for the SRE vs. the type checker vs. the resolver.


<a id="orgdea85ec"></a>

# The Two-Layer Architecture

The fully propagator-native architecture has two layers:


<a id="orga8a47e3"></a>

## Layer 1: Structural Reasoning Engine (Within-Domain)

Handles structural decomposition, composition, and matching within a single domain. Registered structural forms:

| Domain           | Structural Forms                                                      |
|---------------- |--------------------------------------------------------------------- |
| Type inference   | Pi, Sigma, App, PVec, Map, Set, List, &hellip;                        |
| Trait resolution | TraitConstraint(name, type-args&hellip;), Impl(name, pattern&hellip;) |
| Pattern matching | Cons(head, tail), Pair(fst, snd), Suc(pred), &hellip;                 |
| Reduction        | Redex(fn, arg), Let(binding, body), Match(scrutinee, &hellip;)        |
| Session types    | Send(type, cont), Recv(type, cont), Choice(branches&hellip;)          |
| Capabilities     | Cap(resource, operation), Grant(cap, scope)                           |

Each domain registers its forms with the SRE. The SRE handles:

-   Decomposition: parent cell → sub-cells + decomposition propagator
-   Reconstruction: sub-cells → parent cell + reconstruction propagator
-   Sub-cell reuse: `identify-sub-cell` (already exists in PUnify)
-   Decomposition registry: `get-or-create-sub-cells` (already exists)


<a id="orgb72a4e1"></a>

## Layer 2: Galois Bridges (Between-Domain)

Handles information flow between domains via α/γ Galois connections. The SRE decomposes within a domain; Galois bridges connect domains.

| Bridge           | α direction                               | γ direction                              |
|---------------- |----------------------------------------- |---------------------------------------- |
| Type → Mult      | `type->mult-alpha` (extract multiplicity) | `mult->type-gamma` (inject multiplicity) |
| Type → Session   | Type value → session continuation type    | Session protocol → expected type         |
| Type → Trait     | Ground type-args → trait lookup           | Resolved dict → type solution            |
| Type → Reduction | Unreduced expression → normal form        | Normal form → type cell                  |

Both layers live on the same propagator network. SRE propagators and Galois bridge propagators compose automatically via shared cells.


<a id="orgdc819ca"></a>

# How This Changes The Roadmap


<a id="org141eab9"></a>

## Before: Track-Per-System Migration

> "Track 8D: put registries on network. Track 8F: put meta-info on network. Track 9: put reduction on network. Each track migrates one system."


<a id="orgb969d7c"></a>

## After: Build the SRE, Then Each System Plugs In

The SRE is the foundation. Each system "migrates onto the network" by *registering structural forms with the SRE* and *expressing its reasoning as structural-relate calls*.

1.  **SRE Foundation** (new Track 8.SRE): Extract PUnify's structural decomposition primitives into a domain-agnostic SRE module. Parameterize by structural form (registry of decomposers + reconstructors). This is mostly extraction and generalization of existing code.

2.  **Type Inference on SRE**: Already substantially done &mdash; PUnify IS the SRE for the type domain. Refactor elaborator to call `structural-relate` instead of manually installing propagators. Bidirectional checking becomes strategy over SRE.

3.  **Trait Resolution on SRE**: Register trait constraints as structural forms. Pattern matching of `impl` types against constraint types becomes SRE decomposition. Replaces the current imperative `try-monomorphic-resolve` / `try-parametric-resolve` with structural matching via the SRE.

4.  **Pattern Compilation on SRE**: Register pattern constructors as structural forms. Pattern matching compilation becomes SRE decomposition of scrutinee types.

5.  **Reduction on SRE**: Register reduction rules as structural forms. β-reduction, δ-reduction, ι-reduction as SRE decomposition + recomposition. E-graph rewriting as SRE structural equivalence classes. (This intersects with the e-graph research.)

6.  **Module Loading on SRE**: Module exports/imports as structural matching. The network exists first (Track 10), module loading registers structural forms and populates cells.


<a id="org9cdf97c"></a>

## What The SRE Subsumes

| Current Infrastructure                       | SRE Replacement                                   |
|-------------------------------------------- |------------------------------------------------- |
| `punify-dispatch-sub/pi/binder`              | `structural-relate` with Pi form                  |
| `identify-sub-cell`                          | SRE cell identification (generalized)             |
| `get-or-create-sub-cells`                    | SRE decomposition registry (generalized)          |
| `make-pi-reconstructor`                      | SRE reconstruction propagator (registered)        |
| `make-structural-unify-propagator`           | SRE unification propagator (universal)            |
| Manual propagator installation in elaborator | `structural-relate` calls                         |
| `ground-expr?`                               | Groundness propagators on SRE decomposition graph |
| `zonk` (during elaboration)                  | Cell reads (cell values are always current)       |
| Trait pattern matching                       | SRE structural matching                           |
| Bridge fire functions (C1-C3)                | SRE structural matching + Galois bridges          |


<a id="orgbc29015"></a>

## What The SRE Does NOT Subsume

-   **Parser / reader**: Syntactic phase, pre-network. Not structural reasoning.
-   **QTT multiplicity tracking**: Separate lattice domain, connected via Galois bridges. The SRE decomposes types; mult bridges extract mult information.
-   **Session type duality**: An operation on session structural forms, but duality computation itself is domain-specific. The SRE decomposes session types; duality is a domain-specific propagator.
-   **Exhaustiveness checking**: Analysis over the set of patterns, not structural decomposition of individual patterns.
-   **I/O effects**: External system interaction.


<a id="org2ba2a8f"></a>

# The SRE as Correct-by-Construction Infrastructure

The SRE makes several classes of bugs structurally impossible:


<a id="org10cb062"></a>

## Missing Decomposition Cases

Currently, adding a new type constructor (e.g., `expr-Record`) requires updating 14 pipeline files. With the SRE, adding `Record` means registering a structural form: its tag, its component count, its decomposer, its reconstructor. The SRE handles all propagator installation, sub-cell creation, and registry management. If the form is registered, it works everywhere. If it's not registered, it fails at registration time, not at some downstream pattern match.


<a id="org603e9f2"></a>

## Inconsistent Structural Handling

Currently, Pi decomposition in the elaborator, in PUnify, and in trait resolution are three separate implementations. With the SRE, Pi decomposition is registered once. All consumers use the same mechanism. Inconsistency is structurally impossible.


<a id="org011dbdb"></a>

## Stale Cell Values

Currently, `zonk` is needed because expressions can contain stale `expr-meta` references. With the SRE, cell values are always current because the network's propagation semantics guarantee it. If a sub-cell changes, the parent cell's reconstruction propagator fires, updating the parent. Staleness is impossible.


<a id="org1ba1c1c"></a>

# Relationship to Existing Principles

-   **Propagators as Universal Computational Substrate**: The SRE IS the concrete realization of this principle. Structural reasoning is the most common computational pattern in the compiler; the SRE makes it native to the propagator network.

-   **Correct-by-Construction**: The SRE makes structural consistency a property of the network topology, not a property maintained by discipline. If the decomposition is registered, the propagators are correct.

-   **First-Class by Default**: Structural forms are first-class data (tag + components). Decomposers and reconstructors are first-class functions. The SRE registry is itself a cell (composable with other network state).

-   **Completeness**: The SRE is the "hard thing done right" that makes everything else simpler &mdash; elaboration, resolution, matching, reduction all become thin callers of the SRE.

-   **Most General Interface**: A domain-parameterized structural decomposition engine is the most general interface for structural reasoning. Any domain that has "things with structure" plugs in.

-   **Composition**: The SRE composes with Galois bridges. Cross-domain structural reasoning (type → trait, type → session) falls out of the SRE's decomposition + bridge propagators. No special plumbing per domain pair.


<a id="org8a1c3d7"></a>

# The SRE as Structural Relation Engine (Round 4 Insight)

The NTT case studies (6 systems modeled) revealed that the SRE handles
more than structural equality (unification). Three distinct structural
*relations* appeared across the case studies:

## Relations Beyond Equality

| Relation | Laws | Where it appears | SRE decomposition behavior |
|----------|------|-----------------|---------------------------|
| **Equality** | reflexive, symmetric, transitive | Unification (the default) | Pi(A,B) = Pi(C,D) → A=C, B=D |
| **Duality** | involution: dual(dual(x)) = x | Session types | Send(A,S) ~ Recv(A',S') → A=A', S ~ dual(S') |
| **Subtyping** | reflexive, transitive, antisymmetric | Type checking | Pi(A,B) <: Pi(A',B') → A' <: A (contra), B <: B' (co) |
| **Coercion** | directional (A ↪ B, not B ↪ A) | Numeric widening (Int → Num) | coerce(Pi(A,B), Pi(A',B')) → coerce(A',A), coerce(B,B') |
| **Isomorphism** | bijective (equality up to structure) | Curry/uncurry, α-equivalence | Iso(A×B→C, A→B→C) via structural witness |

## Relation-Parameterized Decomposition

The key insight: structural decomposition propagators can be
*parameterized by the relation*. The same structural dispatch (match
on constructor tag, extract sub-cells) applies to all relations — but
the sub-cell relationships differ:

-   **Equality**: sub-cells related by `=` (reflexive, same direction)
-   **Duality**: sub-cells related by `~` (involution, flip at each level)
-   **Subtyping**: sub-cells related by `<:` with *variance rules* —
    contravariant for function domains, covariant for codomains, invariant
    for mutable references
-   **Coercion**: sub-cells related by `↪` with directional composition

The variance rules are per-constructor-field, not per-relation. The
`domain` field of `Pi` is contravariant under subtyping; the `codomain`
is covariant. The SRE form registration should carry variance annotations:

```
;; In the form registry (derived from type definition):
Pi:
  fields: [domain (contravariant), codomain (covariant)]
  decompose: cell → [domain-cell, codomain-cell]
  reconstruct: [domain-cell, codomain-cell] → cell

;; When applying subtyping:
Pi(A,B) <: Pi(A',B') →
  A' <: A   (contravariant: flip direction)
  B <: B'   (covariant: same direction)

;; When applying duality:
Send(A,S) ~ Recv(A',S') →
  A = A'    (payload: equality, not duality)
  S ~ S'    (continuation: duality propagates)
```

## What This Changes

The SRE expands from "Structural Reasoning Engine" to "Structural
*Relation* Engine" — still abbreviated SRE, but the scope is broader.
Every place the system needs to analyze, decompose, or match structure
*under any structural relation*, the SRE provides the propagator-native
primitive.

This subsumes several mechanisms that are currently separate:
-   `unify` (equality relation on types)
-   `sess-dual?` (duality relation on sessions)
-   `subtype?` (subtyping relation on types)
-   Pattern matching compilation (equality relation on terms)
-   Coercion insertion (coercion relation on types)

All become: `structural-relate(cell-a, relation, cell-b)` where the
SRE dispatches on both the constructor tag AND the relation to determine
sub-cell relationships and variance.

## Open Questions

1.  **Can variance be derived from type definitions?** For algebraic data
    types, variance is often determinable from the polarity of type
    parameter occurrences (positive = covariant, negative = contravariant).
    This would make variance annotations on form fields derivable,
    extending the derive-not-declare principle.

2.  **How do relations compose?** If we have equality and subtyping, what
    about "equal up to subtyping" or "dual up to coercion"? Relation
    composition could be a powerful mechanism but needs careful design.

3.  **Performance**: Relation-parameterized dispatch adds a branch per
    decomposition. Is this cost significant? Likely not — the branch is
    on a small enum (5-6 relations), and most paths use equality.


<a id="org5928bd8"></a>

# Next Steps

1.  Capture this insight in `DESIGN_PRINCIPLES.org` as an elaboration of "Propagators as Universal Computational Substrate" — the SRE is the named mechanism.

2.  Track 8D (registry cells + pure bridges) is COMPLETE (`eb9857a`). Confirmed that bridges read cells directly — first SRE-aligned bridge architecture.

3.  Scope the SRE Foundation track: extract PUnify's structural primitives, parameterize by domain AND relation, build the form registry. The relation parameterization (equality, duality, subtyping, coercion, isomorphism) is the key addition from the NTT case studies.

4.  Variance derivation: investigate whether variance annotations (contravariant domain, covariant codomain) can be derived from type parameter polarity analysis. If yes, this extends derive-not-declare to relations.

5.  NTT integration: the SRE's structural relation concept informs NTT §13.3 item 9. The NTT type system should be able to express "this propagator operates under the subtyping relation with these variance rules" as a type-level constraint.

4.  Revise the Unified Propagator Network Roadmap to reflect the SRE as the foundational layer that all tracks build on.
