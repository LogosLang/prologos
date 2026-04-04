# Grammar Form — Design Thinking (Early Draft)

**Date**: 2026-04-03
**Stage**: 1→2 (Research synthesis → early design thinking)
**Series**: PPN Track 3.5 / Grammar Form R&D
**Status**: Living document. Captures current design thinking, open questions, and connected research. Not yet a Stage 3 design document.

**Research grounding**:
- [Grammar Toplevel Form — Vision](../research/2026-03-26_GRAMMAR_TOPLEVEL_FORM.md) — 7-view multi-spec, progressive specification
- [Self-Describing Serialization](../research/2026-03-25_SELF_DESCRIBING_SERIALIZATION_GRAMMAR.md) — grammar as serialization spec, duality, invariant levels
- [Hypergraph Rewriting](../research/2026-03-24_HYPERGRAPH_REWRITING_PROPAGATOR_PARSING.md) — Engelfriet-Heyker, HR grammars = attribute grammars
- [Adhesive Categories](../research/2026-04-03_ADHESIVE_CATEGORIES_PARSE_TREES.md) — parse trees are adhesive presheaves, DPO toolkit, CALM connection
- [Kan Extensions / ATMS / GFP](../research/2026-03-26_KAN_EXTENSIONS_ATMS_GFP_PARSING.md) — demand-driven parsing, disambiguation
- [Lattice Foundations for PPN](../research/2026-03-26_LATTICE_FOUNDATIONS_PPN.md) — 6-domain reduced product, type-lattice semiring
- [Tropical Optimization](../research/2026-03-24_TROPICAL_OPTIMIZATION_NETWORK_ARCHITECTURE.md) — cost-weighted rewriting, lossy grammars

**Implementation grounding**:
- [SRE Track 2D](2026-04-03_SRE_TRACK2D_DESIGN.md) — DPO spans, pattern-desc, child-pattern-split, fold/tree combinators, propagator factory, critical pair analysis. 13 rules, 0 critical pairs. The compilation target.
- [SRE Track 2H](2026-04-02_SRE_TRACK2H_DESIGN.md) — type-lattice quantale, tensor, pseudo-complement. The type-level foundation.
- Existing `defmacro` in macros.rkt — pattern→template surface rewriting
- Existing precedence DAG in macros.rkt — `prec-group` with `tighter-than` DAG, `op-info` with computed binding powers

---

## 1. The Goal

A `grammar` toplevel form that is:
- **The universal extension mechanism** — powerful enough that language implementors would use it for most of their own needs
- **Progressive** — a one-liner for sugar, a full spec for real language extensions (Progressive Disclosure principle)
- **Subsumes `defmacro`** — the simplest `grammar` form IS a defmacro. No separate mechanism needed for the common case.
- **Multi-modal** — a grammar production simultaneously specifies parsing, serialization, types, reduction, display. Each view is a DPO span on a different lattice domain.
- **Bidirectional where possible** — parsing and serialization are duals when lossless. The grammar declares which invariant level (identity, structural, behavioral, value) the round-trip preserves.
- **First-class** — grammar rules are values. They compose. They can be exported from modules. They participate in the SRE as registered DPO spans.
- **Checked** — grammar extensions are verified at registration time: critical pair analysis detects conflicts, type rules are validated, invariant levels are checked.

---

## 2. Progressive Specification (from simplest to fullest)

### Level 0: Sugar (equivalent to `defmacro`)

```prologos
grammar when
  | "when" cond:expr body:expr -> (if cond body unit)
```

One line. Pattern on the left, desugared form on the right. This IS `defmacro` — same power, same simplicity. All other views derived from the desugaring target. `defmacro` can be retired or retained as syntactic sugar for this form.

### Level 1: Typed sugar

```prologos
grammar when
  | "when" cond:Bool body:A -> (if cond body unit) : A
```

Adds type constraints. The compiler verifies: does the desugared form (`if cond body unit`) actually have type `A` when `cond : Bool` and `body : A`? Type checking at grammar definition time, not at use time.

### Level 2: Reduction rules

```prologos
grammar when
  :parse  "when" cond:expr body:expr
  :type   cond : Bool, body : A -> A
  :reduce
    | when true  body -> body
    | when false _    -> unit
```

Specifies how the form evaluates. Each reduction clause is a DPO span registered with SRE Track 6. This is more than `defmacro` can do — defmacro specifies rewriting (surface → core), not reduction (core → value).

### Level 3: Full multi-view

```prologos
grammar when
  :parse      "when" cond:expr body:expr
  :type       cond : Bool, body : A -> A
  :reduce
    | when true  body -> body
    | when false _    -> unit
  :components [cond : Bool, body : A]
  :display    "when" cond body
  :invariant  value    ;; lossy: can't reconstruct "when" from "if"
```

All views explicit. The compiler checks consistency: does `:type` agree with `:reduce`? Does `:display` agree with `:parse`? Does `:invariant` match the actual round-trip?

### Level 4: Serialization / wire protocol

```prologos
grammar json-number
  :parse      digit+ ("." digit+)?
  :target     Rat
  :serialize  (rat-to-decimal-string value)
  :invariant  structural
  :dual                                ;; parse and serialize are inverses
```

A grammar that is both a parser AND a serializer. The `:dual` declaration asserts the round-trip property. Not all grammars can be dual — lossy transformations (like `when → if` desugaring) are one-directional.

---

## 3. Operator Declarations via Grammar

The existing mixfix system uses a DAG of precedence groups:

```racket
;; From macros.rkt:
(struct prec-group (name assoc tighter-than) #:transparent)
;; DAG: pipe < logical-or < logical-and < comparison < additive < multiplicative < ...
```

Users can define new groups with `tighter-than` relations — no numeric precedence. This is the RIGHT design: extensible, intuitive, no "what number do I pick?" problem.

Grammar subsumes this:

```prologos
;; Define a precedence group
precedence-group set-ops
  :associativity left
  :tighter-than comparison

;; Define operators in the group
grammar set-union
  :parse    a:expr "∪" b:expr
  :group    set-ops
  :target   [set-union a b]
  :type     a : Set A, b : Set A -> Set A

grammar set-intersect
  :parse    a:expr "∩" b:expr
  :group    set-ops
  :target   [set-intersect a b]
  :type     a : Set A, b : Set A -> Set A
```

The `precedence-group` declaration defines a group in the DAG. The `:group` attribute on a grammar production places it in the group. The DAG determines resolution order in the mixfix PU (Track 2B).

This naturally coexists with the existing `prec-group` + `op-info` infrastructure. The grammar form COMPILES TO the same registration calls. New groups extend the DAG; new operators register in groups.

Critical pair analysis applies: two operators in the SAME group with the same associativity have no critical pair. Two operators in UNRELATED groups (neither tighter-than the other) require explicit disambiguation — the compiler warns at definition time.

---

## 4. The Prolog/DCG Connection: Grammars as Relations

A Prolog DCG:
```prolog
sentence --> noun_phrase, verb_phrase.
noun_phrase --> determiner, noun.
```

Is a relation: `sentence(S0, S)` means "the string from position S0 to S is a sentence." Running with S0 bound and S unbound → parsing. Running with S bound and S0 unbound → generation.

The Prologos `grammar` form has the same duality. A production like:

```prologos
grammar pair-literal
  :parse    "(" a:expr "," b:expr ")"
  :target   [pair a b]
```

IS a relation between surface syntax `"(" a "," b ")"` and structural target `[pair a b]`. Running forward (surface → target) is parsing. Running backward (target → surface) is serialization/display.

The propagator network makes this bidirectionality concrete: the parse production is a propagator with input cells (surface tokens) and output cells (structural target). Information flows in BOTH directions via the reduced product. The lattice merge handles partial information — you can have the surface form without the target, or the target without the surface form, and the network fills in what it can.

This is MORE powerful than Prolog's DCG because:
1. **Typed**: each production carries type constraints (`:type`)
2. **Lattice-based**: partial information is handled naturally (not just bound/unbound)
3. **Parallel**: independent productions fire simultaneously (adhesive guarantee)
4. **Multi-domain**: the production touches multiple domains (surface, type, core) via the reduced product
5. **Cost-weighted**: the tropical semiring selects optimal parsings/serializations

---

## 5. Duality and Modality

Not all grammars can be `:dual`. The invariant level declares what's preserved:

| Invariant | Round-trip | Example | Dual? |
|-----------|-----------|---------|-------|
| `:identity` | `eq?` identity preserved | In-process snapshot | ✅ Full |
| `:structural` | `equal?` preserved | .pnet cache, JSON | ✅ Full |
| `:behavioral` | Function behavior preserved | FFI re-link | ⚠️ Partial (behavioral equivalence, not structural) |
| `:value` | Computed value preserved | `when → if` desugar | ❌ One-directional |

The `:dual` declaration asserts: `:parse` and `:serialize` are inverses at the declared invariant level. The type system ENFORCES this — a consumer requiring `:structural` round-trip can't use a `:value`-only grammar.

For serialization / wire protocols:

```prologos
;; Full dual: JSON ↔ Prologos values
grammar json-object
  :parse      "{" (key:string ":" value:json-value ",")* "}"
  :target     Map String JsonValue
  :serialize  ... ;; derived from :parse when :dual
  :invariant  structural
  :dual

;; Lossy: compact binary → Prologos (no reverse)
grammar compact-binary
  :parse      byte-header content:bytes
  :target     ModuleState
  :invariant  value     ;; can't reconstruct exact bytes from ModuleState
  ;; NO :serialize, NO :dual — one-directional parse only
```

---

## 6. What Track 2D Provides as Compilation Target

The `grammar` form COMPILES TO Track 2D's DPO span infrastructure:

| Grammar feature | Track 2D mechanism |
|----------------|-------------------|
| `:parse` pattern | `pattern-desc` with child-patterns, literals, variadic |
| `:parse` separator patterns | `child-pattern-split` (e.g., `guard "->" body`) |
| `:parse` → `:target` rewrite | `sre-rewrite-rule` with template RHS |
| `:group` (operator precedence) | Registration in `prec-group` DAG + mixfix PU |
| `:reduce` clauses | Fold combinator + step rules (DPO spans on core domain) |
| Critical pair detection | `find-critical-pairs` at grammar registration time |
| Confluence verification | `analyze-confluence` on the full rule set |
| Template instantiation | `instantiate-template` with `$punify-hole` markers |

The compilation is: parse the `grammar` form → generate `sre-rewrite-rule` registrations + `pattern-desc` + template trees → register with `register-sre-rewrite-rule!` → verify via `verify-rewrite-rule` + `find-critical-pairs`.

---

## 7. Adhesive Category Guarantees

From the [adhesive categories research](../research/2026-04-03_ADHESIVE_CATEGORIES_PARSE_TREES.md):

- **Grammar extensions compose correctly** — the concurrency theorem guarantees that non-conflicting grammar rules can coexist
- **Conflicts are detectable** — critical pair analysis finds ALL conflicts at registration time
- **Parallel parsing is safe** — independent productions fire simultaneously (parallelism theorem)
- **CALM-compliant** — monotone grammar propagators are coordination-free

These guarantees apply to USER-DEFINED grammar extensions, not just built-in rules. When a user writes `grammar my-form ...`, the compiler verifies the extension is adhesive-safe before accepting it.

---

## 8. Open Design Questions

### A. Does `grammar` fully subsume `defmacro`?

The Level 0 syntax (`grammar when | "when" cond body -> (if cond body unit)`) is as concise as `defmacro when [cond body] [if cond body unit]`. If `grammar` has a one-liner form, `defmacro` adds no value. Should `defmacro` be:
- (a) Retained as syntax sugar for `grammar` Level 0
- (b) Deprecated in favor of `grammar`
- (c) Retained for backward compatibility but documented as "prefer `grammar`"

### B. Scope of `:type` view

Does `:type` specify:
- (a) Type CONSTRAINTS only (the elaborator infers the rest) — easier to write, less precise
- (b) Full typing JUDGMENT (infer/check rules) — more powerful, more complex
- (c) Progressive: constraints by default, full judgment with `:type-rule` escape

### C. `:reduce` view interaction with Track 6

`:reduce` clauses are DPO spans on the core domain. Should they:
- (a) Compile to Track 6 reduction rules (when Track 6 exists)
- (b) Be a separate mechanism that coexists with Track 6
- (c) BE Track 6 — grammar `:reduce` IS how reduction rules are defined

### D. Context-sensitive syntax

The existing WS syntax has context-sensitivity: indentation, operator precedence, `.{...}` blocks. Can `grammar` express context-sensitivity? Options:
- (a) Context-free only — context-sensitivity handled by separate mechanisms
- (b) `:context` parameter declaring what context the production needs
- (c) Context as a lattice domain in the reduced product — the production's type includes its context requirements

### E. Grammar modularity and export

Can a module export grammar extensions? Can two modules' extensions compose?
- Module A defines `grammar my-if` with its own semantics
- Module B imports Module A and uses `my-if`
- The grammar rules travel with the module (like type definitions travel with `data`)
- Critical pair analysis runs at import time to verify composition safety

### F. Parameterized grammars

```prologos
grammar list-literal {A : Type}
  :parse    "[" (a:A ",")* "]"
  :target   List A
```

Requires HKT integration — the grammar is parameterized by a type. The type parameter determines how to parse elements. This is powerful (generic syntax) but complex (type-level computation in the parser).

### G. Self-describing serialization integration

The [Self-Describing Serialization research](../research/2026-03-25_SELF_DESCRIBING_SERIALIZATION_GRAMMAR.md) envisions grammar rules embedded in `.pnet` files. The `:serialize` view of `grammar` IS the serialization spec. The `.pnet` format's Part 1 (grammar rules) is a collection of `grammar` forms.

### H. Interaction with ATMS for ambiguity

When two grammar productions match the same input (ambiguity), the ATMS explores both branches. Does the `grammar` form specify ATMS interaction?
- (a) Implicit — the compiler manages ATMS branching automatically
- (b) `:ambiguity` parameter controlling how to resolve
- (c) `:priority` + `:group` for operator-style resolution; ATMS for type-directed resolution

---

## 9. Cross-References

- **SRE Track 2D** (completed): provides the DPO compilation target
- **SRE Track 2H** (completed): provides the type-lattice foundation
- **PPN Track 4** (next): elaboration on network — consumes grammar extensions for type inference
- **SRE Track 6** (future): reduction as rewriting — consumes `:reduce` view
- **PPN Track 5** (future): disambiguation — consumes `:ambiguity` view
- **Adhesive Categories**: formal guarantees for grammar composition

---

## 10. Next Steps

1. **Deepen into each open question** (A-H) through focused design discussion
2. **Speculative syntax for NTT-typed grammar forms** — what does the NTT type of a grammar production look like?
3. **Prototype**: compile a small grammar extension to Track 2D DPO spans, end-to-end
4. **DCG/Prolog connection**: formalize the relational interpretation of grammar productions
5. **Serialization integration**: design the `:serialize` / `:dual` / `:invariant` subsystem
