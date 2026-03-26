# The `grammar` Toplevel Form — Vision Research

**Stage**: 0 (Vision — patterns not yet observed, informed by theory)
**Date**: 2026-03-26
**Series**: PPN (Track 3.5 Research + Design), PRN (universal primitive)
**Status**: Vision document. Syntax design follows PPN Tracks 1-3 implementation.

**Related documents**:
- [PPN Master](../tracking/2026-03-26_PPN_MASTER.md) — series tracking
- [PRN Master](../tracking/2026-03-26_PRN_MASTER.md) — theory series
- [Hypergraph Rewriting + Propagator Parsing](2026-03-24_HYPERGRAPH_REWRITING_PROPAGATOR_PARSING.md) — Engelfriet-Heyker, HR grammars
- [Kan Extensions, ATMS, GFP Parsing](2026-03-26_KAN_EXTENSIONS_ATMS_GFP_PARSING.md) — bilattice, disambiguation
- [Lattice Foundations for PPN](2026-03-26_LATTICE_FOUNDATIONS_PPN.md) — concrete lattice design
- [Tropical Optimization](2026-03-24_TROPICAL_OPTIMIZATION_NETWORK_ARCHITECTURE.md) — cost-weighted selection, lossy grammars
- [NTT Syntax Design](../tracking/2026-03-22_NTT_SYNTAX_DESIGN.md) — typing discipline
- [Toplevel Forms Reference](../tracking/TOPLEVEL_FORMS_REFERENCE.org) — existing config language

---

## 1. The Problem

`defmacro` is a TEXT SUBSTITUTION mechanism: "when you see THIS pattern,
replace it with THAT pattern." It operates on the already-parsed tree. It
doesn't change what's PARSEABLE — only what happens after parsing. It
specifies ONE view (recognition → generation) of what is actually a
MULTI-VIEW specification.

A real language extension needs to participate in ALL pipeline phases:
parsing, type checking, elaboration, reduction, pretty-printing,
serialization, and tooling (LSP, error messages). `defmacro` handles
one of these seven. The other six require ad-hoc code changes across
14 pipeline files — which is exactly the problem PPN aims to solve.

## 2. The Vision: `grammar` as Multi-View Specification

A `grammar` toplevel form declares a STRUCTURAL FORM that participates
in every pipeline phase. It is simultaneously:

1. **A parsing production** (recognition direction): How to PARSE this form from source text
2. **A serialization rule** (generation direction): How to SERIALIZE this form to bytes/text
3. **A type rule** (elaboration): What TYPE constraints does this form generate
4. **A reduction rule** (evaluation): How does this form REDUCE/EVALUATE
5. **A structural decomposition** (SRE form): What are this form's COMPONENTS
6. **A pretty-printing rule** (display): How to DISPLAY this form to the user
7. **A tooling spec** (LSP): How to HIGHLIGHT, COMPLETE, and NAVIGATE this form

These seven views are the SAME specification expressed in different
directions. The Engelfriet-Heyker equivalence guarantees: if the parsing
and serialization directions are consistent (bidirectional grammar), the
specification is sound.

### Speculative syntax (informed by NTT patterns):

```prologos
;; A grammar extension that adds a "when" form
grammar when
  ;; View 1: Parsing — how to recognize this form
  :parse
    when $cond $body            ;; pattern: keyword + condition + body

  ;; View 2: Type rule — what constraints does it generate
  :type
    $cond : Bool                ;; condition must be Bool
    $body : A                   ;; body has some type A
    -> A                        ;; result type = body type

  ;; View 3: Reduction — how does it evaluate
  :reduce
    | when true  $body -> $body
    | when false _     -> unit

  ;; View 4: Structural decomposition (SRE)
  :components [cond : Bool, body : A]

  ;; View 5: Pretty-print
  :display "when" $cond $body

  ;; View 6: Serialization (bidirectional with :parse)
  ;; Derived automatically from :parse — same rule, reverse direction

  ;; View 7: Tooling
  :highlight :keyword
  :completion "when <condition> <body>"
```

### How `grammar` subsumes `defmacro`:

`defmacro when [$cond $body] [if $cond $body unit]` is equivalent to:

```prologos
grammar when
  :parse    when $cond $body
  :desugar  [if $cond $body unit]     ;; ONLY the rewrite view
  ;; All other views derived from the desugaring target (if)
```

The `:desugar` keyword says: "this form is SUGAR for an existing form."
The type rule, reduction, SRE decomposition, pretty-printing, and
serialization are all DERIVED from the desugaring target. This is exactly
what `defmacro` does today — but made explicit as a special case of the
more general `grammar` form.

## 3. The Five Research Questions

### 3.1 What does a grammar production need to specify?

The seven views above. But not ALL views are required for every form:

- **Sugar** (like `when`): only `:parse` + `:desugar`. All other views derived.
- **Primitive** (like `if`): all seven views specified explicitly.
- **Syntax-only** (like bracket styles): only `:parse` + `:display`. No type/reduce.

The `grammar` form should support PROGRESSIVE SPECIFICATION: provide
what you have, derive what you don't. The more views you specify, the
more the compiler can CHECK (consistency between views). The fewer you
specify, the more the compiler DERIVES (from existing forms).

### 3.2 How do grammar productions compose?

Two grammar rules for the same input position: ambiguity. Resolved by:

1. **ATMS branching**: Try both, let type checking resolve (PPN architecture)
2. **Priority**: User-specified precedence (`:priority N`)
3. **Specificity**: More specific rules win (longer match, more constraints)
4. **Critical pair analysis**: At grammar-registration time, detect
   conflicts and report them. HR grammar theory provides the framework.

Composition should be CHECKED, not hoped for. When a user registers a
`grammar` extension, the compiler verifies: does this introduce ambiguity?
If so: is the ambiguity resolvable by priority/specificity/ATMS? If not:
reject the extension with a clear error.

This is the GFP analysis from our Kan/ATMS research: compare the gfp of
parses with the old grammar vs the new. Growth = ambiguity.

### 3.3 How does `grammar` relate to `defmacro`?

`defmacro` is `grammar` with only the `:desugar` view:

| Mechanism | Views specified | Other views |
|-----------|----------------|-------------|
| `defmacro` | `:parse` + `:desugar` | Derived from desugar target |
| `grammar` (sugar) | `:parse` + `:desugar` | Derived (same as defmacro) |
| `grammar` (typed) | `:parse` + `:type` + `:desugar` | Type checked, rest derived |
| `grammar` (full) | All 7 views | All explicit, fully checked |

`defmacro` REMAINS as the lightweight sugar mechanism. `grammar` is the
heavy-duty mechanism for real language extensions. They coexist: simple
extensions use `defmacro`, complex extensions use `grammar`.

### 3.4 How does `grammar` relate to `data`?

`data` defines CONSTRUCTORS (structural forms in the value domain).
`grammar` defines SYNTAX (structural forms in the surface domain).

A `data` type can have MULTIPLE `grammar` rules — different surface
syntaxes for the same underlying type:

```prologos
data Pair A B := pair A B

;; Multiple syntaxes for the same type:
grammar pair-bracket
  :parse   ($a, $b)
  :target  [pair $a $b]

grammar pair-angle
  :parse   <$a * $b>
  :target  [pair $a $b]
```

And a `grammar` rule can target an EXISTING `data` type (new syntax for
existing semantics). The grammar rule doesn't create a new type — it
creates a new way to WRITE an existing type.

The relationship: `data` defines the SEMANTIC domain. `grammar` defines
the SYNTACTIC domain. The mapping between them (parsing = syntactic →
semantic; pretty-printing = semantic → syntactic) is the grammar's
bidirectional specification.

### 3.5 Lossy/bidirectional typing on grammar productions

From the Tropical Optimization research: grammar rules carry INVARIANT
LEVELS specifying what's preserved in the round-trip:

| Level | Preserved | Example |
|-------|-----------|---------|
| `:invariant [identity]` | eq? identity, sharing | In-process snapshot |
| `:invariant [structural]` | Structural equality | .pnet module cache |
| `:invariant [behavioral]` | Function behavior | Foreign function re-link |
| `:invariant [value]` | Computed value | Optimization (different form, same result) |

A `grammar` rule that desugars `when` to `if` is `:invariant [value]` —
the desugared form computes the same value but has different structure.
A `grammar` rule for serialization is `:invariant [structural]` — the
serialized form preserves structure but may not preserve eq? identity.

The type system ENFORCES invariant levels: a consumer requiring
structural preservation can't use a value-only grammar rule.

## 4. DPO Structural Preservation — The Key Property

When a `defmacro` rewrites a sub-tree in Prologos, does the surrounding
structure survive? Today: yes, BY CONVENTION (our macros are careful).
With DPO rewriting: yes, BY CONSTRUCTION.

The DPO (Double Pushout) framework guarantees: a rewrite rule replaces a
sub-graph while preserving the INTERFACE (the boundary between the
replaced region and the surrounding context). The interface IS the
parent-child cell topology at the rewrite boundary.

For `grammar`/`defmacro` applied to our token-cell trees:
- The sub-tree matched by the pattern is the "L" (left-hand side)
- The replacement is the "R" (right-hand side)
- The surrounding tree is the "context"
- DPO guarantees: context is preserved, interface is preserved
- INDENTATION is part of the tree structure → indentation is preserved

This is structural preservation BY THEOREM, not by careful implementation.
No existing macro system has this property. Python macros break indentation
because indentation is in the token stream (linear), not in the tree
topology. Our macros preserve indentation because indentation IS the
tree topology, and DPO preserves tree topology.

## 5. Connection to Serialization

A `grammar` production IS a serialization spec:
- `:parse` = deserialization (bytes → structure)
- `:display` = serialization (structure → text)
- `:invariant` = round-trip guarantee

The self-describing serialization vision (Part 0 header + Part 1 grammar
rules + Part 2 data) is a collection of `grammar` productions shipped
alongside the data they describe. The receiver parses the data using
the shipped grammar rules. No pre-agreed format needed — the format
IS the grammar.

## 6. What Implementation Experience Will Teach Us

This vision is INFORMED BY THEORY but NOT VALIDATED BY IMPLEMENTATION.
PPN Tracks 1-3 will reveal:

- **Track 1 (lexer)**: What do TOKEN-LEVEL grammar rules look like?
  Character patterns → token classifications. How does indentation
  structure interact with token rules?

- **Track 2 (normalization)**: What do REWRITE rules look like?
  `defmacro` patterns are the existing data. How do they map to
  `grammar :desugar` specifications?

- **Track 3 (parser)**: What do PRODUCTION rules look like?
  CFG/Earley items are the existing data. How do they map to
  `grammar :parse` specifications?

After Track 3, we'll have THREE categories of production rules observed
in practice. The `grammar` syntax design follows — naming the patterns
we've observed, not the patterns we imagine.

## 7. Relationship to NTT

`grammar` productions are NTT-typed. Each production has:
- A LATTICE (which domain it operates in: token, surface, type)
- MONOTONICITY (the production is a monotone operation on its lattice)
- BRIDGES (cross-domain flow: `:type` creates type constraints)
- STRATIFICATION (which stratum fires this production)

The NTT type of a `grammar` production tells you: in which domain it
operates, what information it produces, and what guarantees it provides.
Type-checking a grammar extension means verifying its NTT type is
compatible with the existing grammar's type.

## 8. Open Questions

1. **Can `grammar` handle context-sensitive syntax?** CFG productions are
   context-free. Our WS syntax has context-sensitive elements (indentation,
   operator precedence). Does `grammar` need a `:context` parameter?

2. **How does `grammar` interact with the ATMS?** If two grammar rules
   produce different parses, the ATMS explores both. Does the `grammar`
   specification include ATMS-awareness, or is ATMS handling implicit?

3. **Can `grammar` rules be PARAMETERIZED?** A generic `grammar` rule that
   takes a type parameter: `grammar list-literal {A} := '[' A (',' A)* ']'`.
   This would need HKT integration.

4. **What is the MINIMAL specification?** For sugar: just `:parse` +
   `:desugar`. For full extensions: all 7 views. What's the minimum for
   each use case, and what can be derived?

5. **How does `grammar` interact with `.pnet` serialization?** If a module
   defines grammar extensions, the `.pnet` needs to include the grammar
   rules so that importers can parse the module's exported syntax.

6. **Can users define INFIX operators via `grammar`?** Currently infix
   is hardcoded. A `grammar` rule for `$a + $b` with `:precedence 6
   :associativity left` would generalize operator definition.
