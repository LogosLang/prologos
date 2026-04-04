# Grammar Form — Design Thinking (Revised Draft)

**Date**: 2026-04-03 (revised 2026-04-04)
**Stage**: 2 (Design thinking — converging on direction)
**Series**: PPN Track 3.5 / Grammar Form R&D
**Status**: Living document. Captures design direction from discussion. Not yet a Stage 3 formal design.

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
- **Progressive** — a one-liner for sugar, a full spec for real language extensions (Progressive Disclosure)
- **Subsumes `defmacro`** — the simplest `grammar` form IS a defmacro. Eventually deprecates `defmacro`.
- **Multi-view** — a grammar production simultaneously specifies parsing, serialization, types, reduction, display. Each view is a DPO span on a different lattice domain.
- **Bidirectional where possible** — parsing and serialization are duals. The grammar declares invariant level. `:dual` can be inferred but is worth asserting for compiler verification.
- **Compositional** — grammar productions reference other productions by name. Repetition, optionality, and alternation as production-level combinators.
- **First-class** — grammar rules are values. They compose. They export from modules. They participate in the SRE as registered DPO spans.
- **Checked** — critical pair analysis at registration. Type rules validated. Invariant levels checked.
- **Context-sensitive capable** — productions can read from context cells (indentation, scope). Mechanically safe via propagator architecture. An experimental extension.

---

## 2. The Multi-Domain View

Each view of a `grammar` production is a DPO span on a different lattice domain in the 6-domain reduced product:

| View | Domain | DPO direction | What it specifies |
|------|--------|--------------|-------------------|
| `:lex` | Token lattice (L_token) | Characters → tokens | How to TOKENIZE this form |
| `:parse` | Surface lattice (L_surface) | Tokens/trees → tree | How to PARSE this form |
| `:type` | Type lattice (L_type) | Surface form → constraints | What TYPE this form has (optional — inferred from `:target` when present) |
| `:reduce` | Core lattice (L_core) | Redex → contractum | How this form EVALUATES |
| `:display` | Text lattice | Tree → text | How to DISPLAY this form (derived from `:parse` when lossless) |
| `:serialize` | Byte lattice | Tree → bytes | How to ENCODE this form for wire/storage |
| `:target` | Cross-domain | Parse result → structural target | The DESUGARING or COMPILATION of this form |

Not all views are required. Progressive specification: provide what you have, derive what you don't.

---

## 3. Progressive Specification

### Level 0: Sugar (replaces `defmacro`)

```prologos
grammar when
  | "when" cond:expr body:expr -> (if cond body unit)
```

One line. Pattern left, desugared form right. All other views derived from the target (`if`). This IS `defmacro` — same power, same conciseness.

### Level 1: Typed sugar

```prologos
grammar when
  | "when" cond:expr body:expr -> (if cond body unit) : A
```

Type annotation optional — if `if` has a spec, the compiler infers `cond : Bool` and `body : A → result : A` from the target's spec. Explicit types are self-documenting; compiler verifies consistency.

### Level 2: With reduction rules

```prologos
grammar when
  :parse  "when" cond:expr body:expr
  :target (if cond body unit)
  :reduce
    | when true  body -> body
    | when false _    -> unit
```

`:reduce` clauses compile to Track 6 DPO reduction rules. Same mechanism as β/δ/ι — one infrastructure, not two. Completeness principle.

### Level 3: Full multi-view

```prologos
grammar when
  :parse      "when" cond:expr body:expr
  :target     (if cond body unit)
  :type       cond : Bool, body : A -> A     ;; optional: inferred from target spec
  :reduce
    | when true  body -> body
    | when false _    -> unit
  :components [cond : Bool, body : A]         ;; SRE structural form
  :display    "when" cond body
  :invariant  value                           ;; lossy: can't reconstruct "when" from "if"
```

### Level 4: Serialization / wire protocol

```prologos
grammar json-number
  :lex        "0" | nonzero-digit digit* ("." digit+)?
  :target     [string-to-rat value]
  :serialize  [rat-to-decimal-string value]
  :invariant  structural
  :dual                                       ;; assertion: parse and serialize are inverses
```

`:dual` can be inferred (if `deserialize(serialize(x)) = x` at the declared invariant level). Explicit `:dual` is a DECLARATION the compiler CHECKS — same pattern as `check` in the type system. When `:serialize` is absent, `:dual` tells the compiler to derive it from `:lex`/`:parse`.

---

## 4. Type Information: `:target` Carries the Types

The `:target` expression carries all typing information via the target function's spec:

```prologos
grammar set-union
  :parse    a "∪" b
  :group    set-ops
  :target   [set-union a b]
  ;; Type inferred: set-union has spec Set<A> Set<A> -> Set<A>
  ;; Therefore a : Set<A>, b : Set<A>, result : Set<A>
```

Type annotations on `:parse` are **optional documentation** — verified by the compiler but carrying no new information beyond what `:target`'s spec already declares.

The `:type` view is only REQUIRED when there is no `:target` — i.e., for primitive forms that don't desugar to existing infrastructure:

```prologos
;; Primitive form: no desugaring target, must declare types
grammar my-primitive
  :parse  "prim" x:expr y:expr
  :type   x : Int, y : Int -> Bool    ;; required — no target to infer from
  :reduce
    | prim x y -> [int-lt x y]
```

Progressive disclosure: `:target` present → types inferred. `:target` absent → `:type` required.

---

## 5. Compositional Grammar Layering

Grammar productions COMPOSE by name reference. The grammar IS a set of mutually-referencing productions. Repetition (`+`, `*`, `?`) as production-level combinators.

### The Hierarchy

| Level | Syntax | What it matches | Example |
|-------|--------|----------------|---------|
| Character class | `/.../` | Raw characters (regex) | `/[0-9]/`, `/[a-zA-Z_]/` |
| Lexer production | name (in `:lex`) | Token by production | `digit`, `hex-digit` |
| Repetition | `name+`, `name*`, `name?` | Repeated production | `digit+`, `ident?` |
| Alternation | `a \| b` | Either production | `digit \| letter` |
| Literal token | `"..."` | Exact token string | `"when"`, `"+"`, `"("` |
| Tree nonterminal | `name` or `name:Type` | Parsed subtree | `cond:expr`, `a:Set<A>` |
| Separator pattern | `elem "sep" ...` | Separated sequence | `a:expr "," b:expr` |

### Syntactic Domain Inference

The domain is inferred from the syntactic form of each element — no modal prefix needed:

- **Quoted strings** (`"when"`, `"+"`) → token literal match
- **Bare names** (`cond`, `body`, `expr`) → tree nonterminal reference
- **Typed names** (`a:Set<A>`) → tree nonterminal with type constraint
- **Regex** (`/[0-9]/`) → character-level match (only in `:lex`)
- **Repetition** (`digit+`, `expr*`) → production combinator (works in both domains)

The compiler verifies: nonterminals must resolve to defined productions (or built-ins). Regex only appears in `:lex`. Type constraints verified against target spec.

### Composition Examples

```prologos
;; Lexer productions compose
grammar digit
  :lex /[0-9]/

grammar hex-digit
  :lex digit | /[a-fA-F]/

grammar hex-literal
  :lex "0x" hex-digit+
  :target [string-to-int value 16]

;; Parser productions compose
grammar expr
  | atom
  | "(" expr ")"
  | expr "+" expr   :group additive

grammar stmt
  | expr
  | "let" name:ident ":=" value:expr body:stmt
```

---

## 6. Operator Declarations via DAG-Based Precedence Groups

Operators use the existing DAG-based precedence system — NOT numeric precedence. Precedence groups declare `tighter-than` relations:

```prologos
;; Define a precedence group in the DAG
precedence-group set-ops
  :associativity left
  :tighter-than comparison

;; Operators reference their group
grammar set-union
  :parse    a "∪" b
  :group    set-ops
  :target   [set-union a b]

grammar set-intersect
  :parse    a "∩" b
  :group    set-ops
  :target   [set-intersect a b]
```

The DAG determines resolution order in the mixfix Pocket Universe (Track 2B). New groups extend the DAG. Groups that are UNRELATED in the DAG (neither tighter-than the other) require explicit disambiguation — the compiler warns at definition time.

The `grammar` form with `:group` compiles to the same `prec-group` + `op-info` registration that the existing mixfix system uses. No new mechanism — same infrastructure, surface syntax.

Critical pair analysis applies: operators in the same group with the same associativity → no critical pair. Operators in unrelated groups → require parenthesization.

---

## 7. Duality and Modality

### Invariant Levels

| Invariant | Round-trip guarantee | Example | Can be `:dual`? |
|-----------|---------------------|---------|-----------------|
| `:identity` | `eq?` preserved | In-process snapshot | ✅ Full |
| `:structural` | `equal?` preserved | .pnet cache, JSON | ✅ Full |
| `:behavioral` | Function behavior preserved | FFI re-link | ⚠️ Partial |
| `:value` | Computed value preserved | `when → if` desugar | ❌ One-directional |

### `:dual` as Assertion

`:dual` declares that `:parse` and `:serialize` (or `:display`) are inverses at the declared invariant level. The compiler verifies this structurally. When `:serialize` is absent, `:dual` tells the compiler to DERIVE it from the parse direction.

`:dual` CAN be inferred — but explicit assertion is worth keeping for the same reason `check` exists in the type system: the user says "I believe this property holds" and the compiler verifies.

### Serialization Connection

A `grammar` production with `:serialize` IS a serialization spec. The self-describing format (research §5) is a collection of `grammar` forms shipped with the data. The `.pnet` Part 1 grammar rules = `grammar` forms.

---

## 8. Context-Sensitive Grammar (Experimental)

Context-sensitivity via `:context` declaration — the production reads from a context cell on the network:

```prologos
grammar indented-block
  :parse    indent-open body:stmt* indent-close
  :context  indent-level : Nat
  :target   [block body]
```

The `:context` declaration says: this production's propagator reads from the `indent-level` cell. It only fires when the context cell has a value.

Mechanically SAFE: context is a lattice domain, the propagator reads it monotonically, the ATMS manages branching when context creates ambiguity. Adhesive DPO guarantees hold — context-sensitive productions compose with the same guarantees as context-free ones.

Conceptually EXPERIMENTAL: user-defined context-sensitivity is powerful but could create confusing syntax. Worth exploring — if it proves too complex for practical use, we can restrict it. The propagator architecture contains the power.

---

## 9. Module Export and Composition

Grammar extensions travel with modules:

```prologos
ns my-dsl

grammar my-form
  :parse  "my" x:expr
  :target [process x]
  :export                     ;; visible to importers
```

Importing a module that exports grammar extensions automatically registers those productions in the importer's grammar. Fully-qualified namespaces prevent collisions. Critical pair analysis runs at import time to verify composition safety.

Grammar rules are part of the module's exported interface — same as type definitions (`data`), trait implementations (`impl`), and function specs (`spec`).

---

## 10. Parameterized Grammars

Grammar productions parameterized by types:

```prologos
grammar list-literal {A : Type}
  :parse    "[" a:A ("," a:A)* "]"
  :target   List A
```

The type parameter determines how to parse elements. This uses existing HKT infrastructure — the grammar is a type-level function. The parse production is a generic function on the type lattice.

Connects to Track 2H's quantale: the type-lattice tensor distributes over union-typed parameters. A `list-literal {Int | String}` parses elements that are either Int or String expressions.

---

## 11. Compilation Target: Track 2D DPO Spans

The `grammar` form COMPILES TO Track 2D's DPO span infrastructure:

| Grammar feature | Track 2D mechanism |
|----------------|-------------------|
| `:parse` pattern | `pattern-desc` with child-patterns, literals, variadic |
| `:parse` separator patterns | `child-pattern-split` |
| `:parse` repetition (`+`, `*`) | Fold combinator (right-fold over repeated elements) |
| `:parse` → `:target` rewrite | `sre-rewrite-rule` with template RHS |
| `:group` operator | Registration in `prec-group` DAG + mixfix PU |
| `:reduce` clauses | DPO spans on core domain (Track 6 when available) |
| `:lex` patterns | Token-level DPO spans (PPN Track 1 domain) |
| Critical pair detection | `find-critical-pairs` at registration time |
| Confluence verification | `analyze-confluence` on the full rule set |
| Template instantiation | `instantiate-template` with `$punify-hole` markers |

The compilation is: parse the `grammar` form → generate `sre-rewrite-rule` registrations → verify via `verify-rewrite-rule` + `find-critical-pairs`.

---

## 12. Adhesive Category Guarantees

From the [adhesive categories research](../research/2026-04-03_ADHESIVE_CATEGORIES_PARSE_TREES.md):

- **Grammar extensions compose correctly** — concurrency theorem
- **Conflicts are detectable** — critical pair lemma completeness
- **Parallel parsing is safe** — parallelism theorem
- **CALM-compliant** — monotone grammar propagators are coordination-free

These apply to USER-DEFINED extensions. When a user writes `grammar my-form`, the compiler verifies adhesive safety before accepting it.

---

## 13. Resolved Design Decisions

| Decision | Resolution | Rationale |
|----------|-----------|-----------|
| `defmacro` relationship | `grammar` subsumes; `defmacro` eventually deprecated | Level 0 grammar IS defmacro. No rush — deprecate when grammar is proven. |
| Numeric vs DAG precedence | DAG with `tighter-than` (existing design) | Extensible, intuitive, no "what number?" problem. |
| Type information source | `:target` carries types; `:type` optional/required when no target | Progressive disclosure. Most grammars have targets. |
| `:reduce` mechanism | Compiles to Track 6 DPO reduction rules | One mechanism. Completeness principle. |
| `:dual` explicit vs inferred | Explicit assertion, compiler verifies. Can be inferred. | Same pattern as `check` — assert + verify. |
| Syntactic domain distinction | Inferred from syntax: strings=tokens, names=nonterminals, regex=chars | No modal prefix needed. Clean progressive disclosure. |
| Context-sensitivity | Experimental `:context` declaration. Mechanically safe. | Propagator architecture contains the power. Worth exploring. |
| Module export | Grammar rules export with modules. CPA at import time. | Grammar IS part of the module interface. |
| Parameterized grammars | Supported via existing HKT | Grammar is a type-level function. |

---

## 14. Open Questions (Remaining)

### A. Code-as-data introspection for grammar forms

Grammar rules AS data means richer introspection than `defmacro` — you can inspect the full multi-view spec, not just pattern→template. What does the introspection API look like? Can a program query "what grammar productions exist for this form?"

### B. Type view scope (deferred to PPN Track 4)

The `:type` view's representation depends on what PPN Track 4 delivers for elaboration-on-network. Track 4 should design with `grammar :type` compilation in mind. Ambition: Track 4 improves and makes more efficient the typing infrastructure overall.

### C. Token-level vs tree-level interaction

When a `:lex` production and a `:parse` production compose (`:lex` produces tokens that `:parse` consumes), how is the interface specified? Is it implicit (`:lex` produces tokens, `:parse` consumes them) or explicit (some bridge declaration)?

### D. Separator patterns and repetition

The `("," a:expr)*` pattern in parameterized grammars — is this a built-in combinator or composed from simpler productions? How does it relate to Track 2D's `child-pattern-split`?

### E. Error messages for grammar violations

When a user's input doesn't match any grammar production, what error does the compiler produce? Can the grammar form specify custom error messages (`:error "expected condition after 'when'"`)? How does this interact with error recovery (PPN Track 5)?

### F. Self-describing serialization as grammar export

The `.pnet` format's Part 1 (grammar rules) = exported `grammar` forms. How does the grammar form's module export interact with the serialization format? Is Part 1 literally the serialized `grammar` declarations?

---

## 15. Next Steps

1. **Deepen remaining open questions** (A-F) through focused discussion
2. **Speculative NTT syntax** for grammar productions — what is the NTT type of a grammar?
3. **Prototype**: compile a small grammar extension to Track 2D DPO spans, end-to-end
4. **Formalize the DCG/Prolog relational interpretation** — grammar as bidirectional relation
5. **Design the `:context` mechanism** for context-sensitive grammars
6. **Connect to PPN Track 4 design** — grammar `:type` compilation target
