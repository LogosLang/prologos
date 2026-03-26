# PPN (Propagator-Parsing-Network) — Series Master Tracking

**Created**: 2026-03-26
**Status**: Active (Stage 0-1 research, Track 0 design pending)
**Thesis**: Parsing IS attribute evaluation IS propagator fixpoint
(Engelfriet-Heyker). The 14-file multi-pass pipeline collapses to
registered rewrite rules on the propagator network. User-defined
grammar extensions as typed hyperedge replacement rules — more
powerful than Lisp macros. Bidirectional serialization grammars
with typed invariant levels.

**Priority**: PREREQUISITE to future syntax/language design work. The
14-file pipeline is the biggest development friction: every new syntax
feature touches all 14 files, every AST node is a pipeline exhaustiveness
problem. PPN collapses this to: register a rewrite rule (one file).

**Origin**: Track 8D principles audit → SRE Research → NTT case studies →
Hypergraph rewriting research

**Source Documents**:
- [Hypergraph Rewriting + Propagator-Native Parsing](../research/2026-03-24_HYPERGRAPH_REWRITING_PROPAGATOR_PARSING.md) — foundational research (Engelfriet-Heyker, DPO, semiring parsing)
- [Tropical Optimization + Network Architecture](../research/2026-03-24_TROPICAL_OPTIMIZATION_NETWORK_ARCHITECTURE.md) — ATMS search, stratification, cost-weighted rewriting
- [Self-Describing Serialization (§4 below)](#4-research-lossy-bidirectional-typed-grammars) — grammar-as-type, invariant levels
- [SRE Research](../research/2026-03-22_STRUCTURAL_REASONING_ENGINE.md) — SRE decomposition IS DPO hyperedge replacement
- [NTT Syntax Design](2026-03-22_NTT_SYNTAX_DESIGN.md) — stratification, bridge, exchange syntax
- [Categorical Foundations](../research/2026-03-22_CATEGORICAL_FOUNDATIONS_TYPED_PROPAGATOR_NETWORKS.md) — polynomial functors, Galois connections
- [Master Roadmap](MASTER_ROADMAP.org) — cross-series dependency map

**Relationship to PRN**: PPN is an APPLICATION series of the PRN
(Propagator-Rewriting-Network) theory. PPN contributes parse lattice
design, ambiguity resolution patterns, and bidirectional information
flow insights back to PRN. PRN formalizes shared primitives that
PPN consumes.

---

## 1. Progress Tracker

| Track | Description | Status | Notes |
|-------|-------------|--------|-------|
| 0 | Lattice design (parse, token, surface, core lattices) | ✅ | `c41bbca` [PIR](2026-03-26_PPN_TRACK0_PIR.md). 4 lattices, 6 bridges, 57 tests. |
| 1 | Lexer + structure as propagators (char → structured token tree) | ⬜ | Replaces reader.rkt. Tokenization + indent structure in one pass. |
| 2 | Surface normalization as rewriting | ⬜ | Replaces macros.rkt preparse (~3000 lines). HIGHEST VALUE per effort. |
| 3 | Parser as propagators (chart/Earley, HR productions) | ⬜ | Replaces parser.rkt (~1500 lines) |
| 3.5 | **Grammar Form: Research + Design** | ⬜ | [`grammar` vision](../research/2026-03-26_GRAMMAR_TOPLEVEL_FORM.md). Multi-view spec (parse/type/reduce/SRE/display/serialize/tooling). Subsumes `defmacro`. DPO structural preservation. Syntax design follows Tracks 1-3 implementation experience. |
| 4 | Elaboration as attribute evaluation | ⬜ | IS SRE Track 2C. Dissolves parse/elab boundary. |
| 5 | Type-directed disambiguation | ⬜ | Backward type→parse flow via Galois bridges |
| 6 | Error recovery as lattice repair | ⬜ | Tropical semiring optimization on parse lattice (OE) |
| 7 | User-defined grammar extensions (`grammar` form) | ⬜ | CAPSTONE: first-class language extension, richer than Lisp macros. Based on Track 3.5 research. |
| 8 | Incremental editing (LSP-grade propagation) | ⬜ | IS PM Track 11 (partial) |
| 9 | Self-describing serialization | ⬜ | Grammar-based .pnet format. Self-hosting capstone. |

## 2. Track Details

### Track 0: Lattice Design

**What**: Define the lattice types for each layer of the parsing pipeline.

| Lattice | Domain | Values | Join | Bot | Top |
|---------|--------|--------|------|-----|-----|
| Token | Character classification | token types | ambiguity union | unclassified | error |
| Surface | WS→sexp transformation | surface syntax trees | ambiguity set | unparsed | parse error |
| Core | sexp→AST transformation | core AST nodes | — | unelaborated | type error |
| Attribute | Type/mult/session assignment | type expressions | lattice merge | unsolved meta | contradiction |

**Key design question**: Are these 4 separate lattices with Galois bridges,
or one product lattice? The Engelfriet-Heyker equivalence suggests: one
lattice per attribute kind, connected by the grammar's attribute flow.

**SRE connection**: SRE Track 0's form registry IS Track 0 applied to
the type domain. The ctor-desc is a lattice value description. The
structural decomposition is an attribute evaluation rule.

### Track 1: Lexer as Propagators

**What**: Replace `reader.rkt` with propagator-based lexing.
Character cells → token cells via registered lexer rules.

**Replaces**: `reader.rkt` (~800 lines), `read-all-syntax-ws`,
reader dispatch for `#p(...)`, `#[...]`, etc.

**Key consideration**: The current reader handles WS-mode indentation
sensitivity. This is context-dependent lexing (indentation level affects
token boundaries). The propagator model handles this naturally — the
indentation level is a cell that the lexer rules read.

### Track 2: Surface Normalization as Rewriting

**What**: Replace the preparse expansion pipeline in `macros.rkt` with
registered rewrite rules on the network.

**Replaces**: `preparse-expand-form`, `preparse-expand-all`,
`preparse-expand-single`, `preparse-expand-subforms` (~3000 lines).
Also: `flatten-ws-kv-pairs`, `rewrite-implicit-map`, dot-access
transformation, broadcast transformation, all surface-level desugaring.

**HIGHEST VALUE per effort**: macros.rkt is 7000+ lines, the most complex
file in the codebase. Every syntax change touches it. Converting preparse
from imperative tree-walking to registered rewrite rules would be
transformative for development velocity.

**Current preparse rules that become rewrite rules**:

| Current | Rewrite rule |
|---------|-------------|
| `expand-if` | `(if cond then else) → (match cond \| true → then \| false → else)` |
| `expand-let` | `(let [x := val] body) → ((fn [x] body) val)` |
| `expand-cond` | `(cond \| p1 → e1 \| p2 → e2) → (if p1 e1 (if p2 e2 ...))` |
| `expand-when` | `(when cond body) → (if cond body unit)` |
| `expand-do` | `(do e1 e2 ... en) → (let [_ := e1] (let [_ := e2] ... en))` |
| `expand-pipe-block` | `(\|> x f g) → (g (f x))` |
| `expand-list-literal` | `'[1 2 3] → (cons 1 (cons 2 (cons 3 nil)))` |
| `expand-compose-sexp` | `(compose f g) → (fn [x] (f (g x)))` |
| `defmacro` templates | User-defined pattern → template substitution |

Each of these IS a DPO rewrite rule. The preparse phase IS hypergraph
rewriting. We're just doing it imperatively today.

### Track 3: Parser as Propagators

**What**: Replace `parser.rkt` with grammar-production-based parsing on
the network. Each grammar production installs propagators. Parse forests
(ambiguity) as lattice values.

**Replaces**: `parser.rkt` (~1500 lines), `parse-datum`, all the
`parse-*` functions.

**Key mechanism**: Chart parsing / Earley as fixpoint. Each chart entry
is a cell. Completion/prediction/scanning are propagators. The grammar
is the set of registered productions. Adding a production = adding a
propagator.

**Semiring parsing (Goodman 1999)**: Same parser parameterized by semiring.
Boolean = recognition. Counting = ambiguity. Tropical = optimal parse.
Forest = all parses. The semiring is a lattice parameter — PPN Track 0's
lattice design determines which semiring we use.

### Track 4: Elaboration as Attribute Evaluation

**What**: Recognize that elaboration (type inference, constraint generation)
IS attribute evaluation on the parse tree. Register elaboration rules
alongside grammar rules. The parse→elaborate boundary dissolves.

**IS SRE Track 2C**: The elaborator uses `structural-relate` (SRE) which
is attribute computation on structural forms. If grammar productions and
elaboration rules are both registered on the same network, they compose
via propagation.

**Key implication**: `typing-core.rkt`'s 60+ infer/check cases become
registered attribute rules. Adding a new type-level construct = registering
a grammar production + an attribute rule. One action, not 14-file pipeline
changes.

### Track 5: Type-Directed Disambiguation

**What**: Use type information flowing BACKWARD through the network to
resolve parse ambiguities. The parser produces multiple parses (ambiguity
cells); the type checker constrains which parses are type-correct; the
ATMS retracts type-incorrect parses.

**Key mechanism**: Galois bridge between parse lattice and type lattice.
Type constraints flow INTO the parser's ambiguity cells. Parse structure
flows INTO the type checker. Bidirectional.

**Concrete example**: `[f x y]` could be `(app (app f x) y)` or
`(app f (tuple x y))`. The parser produces both. The type checker
determines which is type-correct. The incorrect parse is retracted via
ATMS assumption management.

### Track 6: Error Recovery as Lattice Repair

**What**: Parse errors as partial fixpoints (some cells at ⊥). Error
recovery as tropical semiring optimization — find the minimum-cost edit
that makes the parse complete.

**Connects to OE**: This IS tropical semiring optimization applied to
the parse lattice. Each repair (insert token, delete token, change token)
has a cost. The optimal repair is the cheapest sequence that produces a
complete parse.

### Track 7: User-Defined Grammar Extensions

**What**: Users register new grammar productions as first-class language
extensions. Productions are NTT-typed. The extension participates in
the full compilation pipeline — not just parsing, but type checking,
optimization, and tooling.

**CAPSTONE**: This is more powerful than Lisp macros because:
- Macros transform syntax; grammar extensions add new STRUCTURAL FORMS
- Macros are untyped; grammar extensions are NTT-typed
- Macros don't participate in disambiguation; grammar extensions do
- Macros are invisible to tooling; grammar extensions are first-class

**Design work needed**: What does the `grammar` toplevel form look like?
How does a user express a production + attribute rules + rewrite rules
in one declaration?

### Track 8: Incremental Editing

**What**: Edit a character → propagation updates only affected cells.
No re-parse of the entire file. LSP-grade responsiveness.

**IS PM Track 11 (partial)**: The LSP integration track. PPN provides
the mechanism (incremental propagation); PM Track 11 provides the
protocol (LSP notifications, diagnostic publishing).

### Track 9: Self-Describing Serialization

**What**: Grammar-based `.pnet` format. The grammar IS the type of the
serialized data. Serialization = generation from grammar. Deserialization
= parsing against grammar. The grammar is embeddable in the serialized
file (self-describing).

**Three-part format**:
- Part 0: Fixed-size header (magic bytes + version + grammar-size)
- Part 1: Grammar rules (type description for Part 2)
- Part 2: Data (serialized according to Part 1's grammar)

**See §4 below** for the bidirectional typed grammar research.

## 3. Cross-Series Connections

### SRE ↔ PPN

| PPN Track | SRE Connection |
|-----------|---------------|
| 0 (lattice design) | SRE Track 0 is an instance (type lattice) |
| 2 (surface normalization) | SRE form registry = grammar for core expressions |
| 4 (elaboration) | IS SRE Track 2C (elaborator-on-SRE) |
| 5 (disambiguation) | Uses SRE relation dispatch (subtype, duality) |

### OE ↔ PPN

| PPN Track | OE Connection |
|-----------|--------------|
| 3 (parser) | Goodman semiring parsing — tropical for optimal parse |
| 6 (error recovery) | Tropical optimization on parse lattice |

### PM ↔ PPN

| PPN Track | PM Connection |
|-----------|--------------|
| 8 (incremental) | IS PM Track 11 (LSP integration) |
| 9 (serialization) | Replaces PM Track 10's ad-hoc .pnet format |

### PRN ↔ PPN

PPN contributes to PRN:
- Parse lattice design patterns
- Ambiguity resolution as ATMS search
- Bidirectional information flow (type↔parse bridges)
- Grammar-as-type (invariant levels)

PPN consumes from PRN:
- Rewrite rule registration primitives (when formalized)
- Fixpoint termination guarantees
- Cost-weighted rule selection (tropical)

## 4. Research: Lossy Bidirectional Typed Grammars

### The DCG Insight

In Prolog DCGs, grammar rules are RELATIONS, not functions. They work
both ways:
- Given input, decompose into components (parsing/recognition)
- Given components, compose into output (generation/serialization)

Our hypergraph rewriting grammars are the same: a rewrite rule
`Pi(A, B) ↔ [tag: Pi, field-0: A, field-1: B]` is bidirectional.
Serialization matches the left side, emits the right. Deserialization
matches the right side, constructs the left. The rule is the SAME;
the direction of information flow determines which way it runs.
This IS the propagator model.

### Where Information CAN Be Lost

| Property | Serialization behavior | Deserialization behavior | Lost? |
|----------|----------------------|------------------------|-------|
| Structural sharing | Linearized (shared node appears twice) | Two separate nodes reconstructed | YES — `eq?` identity lost |
| Gensym identity | Tagged as `symbol$$N` | Fresh gensym per module | YES — cross-module `eq?` lost |
| Closures | Replaced with `(module-path . binding)` | Re-linked via `dynamic-require` | YES — captured environment lost |
| Network topology | Cell values serialized, propagators dropped | Fresh network, no propagators | YES — intentional (already fired) |
| Algebraic structure | Tree-to-bytes, complete representation | Bytes-to-tree, complete reconstruction | NO — lossless for structural data |

### Invariant Levels

Every grammar rule declares its **invariant level** — what's preserved
across the round-trip:

| Level | Preserved | May be lost | Use case |
|-------|----------|-------------|----------|
| `identity` | `eq?` identity, sharing, all structure | Nothing | In-process snapshot |
| `structural` | Structural equality, field values | `eq?` identity, sharing | `.pnet` module cache |
| `behavioral` | Function behavior, API contract | Closure identity, environment | Foreign function re-linking |
| `value` | Computed value equivalence | Structure, behavior, identity | Optimization (different expr, same result) |

The grammar compiler checks: consumers requiring a higher invariant
level can't use a rule that only guarantees a lower level. A function
needing `eq?`-identical results can't consume a `:invariant [structural]`
serialization. **This is a type error in the grammar.**

### NTT Connection

Invariant levels ARE NTT types:
- `:invariant [identity]` → `Iso(A, A)` (isomorphism)
- `:invariant [structural]` → `≅(A, B)` (structural equivalence)
- `:invariant [behavioral]` → `≈(A, B)` (behavioral equivalence)
- `:invariant [value]` → `≡(A, B)` (observational equivalence)

The NTT type system enforces that weak equivalences aren't used where
strong isomorphisms are required.

### Speculative Syntax

```prologos
;; Lossless bidirectional grammar rule
grammar Pi
  :structure [domain : TypeExpr, codomain : TypeExpr]
  :serial    [tag "Pi", field domain, field codomain]
  :invariant [structural]

;; Lossy grammar rule with explicit annotation
grammar SharedExpr
  :structure [expr : TypeExpr]
  :serial    [tree : TypeExpr]
  :invariant [value]
  :lossy     [sharing]

;; Grammar with closure re-linking
grammar ForeignFn
  :structure [proc : Procedure, arity : Int]
  :serial    [module : ModulePath, name : Symbol, arity : Int]
  :invariant [behavioral]
  :relink    [proc :via dynamic-require module name]

;; Self-describing format
grammar PnetFile
  :header    [magic "PNET", version : Int, grammar-size : Int]
  :rules     [grammar-rules : [Grammar ...]]    ;; Part 1
  :data      [module-state : ModuleState]        ;; Part 2
  :invariant [structural]
```

### Open Questions

1. Can ALL information loss be expressed as an invariant level, or are
   there losses that don't fit the hierarchy? (e.g., ordering of map
   entries — is that `structural` or something else?)

2. Can invariant levels COMPOSE? If rule A has `:invariant [structural]`
   and rule B has `:invariant [behavioral]`, what invariant does
   `(compose A B)` have? (Answer: the WEAKER of the two — `behavioral`.)

3. Can the grammar itself be expressed as a grammar (meta-grammar)?
   If so, Part 1 of the self-describing format is parsed by the
   meta-grammar, which is built into every reader. This is the
   bootstrapping anchor.

4. How do grammar extensions interact with invariant levels? If a user
   adds a grammar rule with `:invariant [value]` but the system expects
   `:invariant [structural]`, is this caught at extension-registration
   time or at usage time?
