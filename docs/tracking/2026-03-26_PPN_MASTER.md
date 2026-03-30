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
| 1 | Lexer + structure as propagators (char → structured token tree) | ✅ | [Design D.9](2026-03-26_PPN_TRACK1_DESIGN.md), [Audit](2026-03-26_PPN_TRACK1_STAGE2_AUDIT.md), [PIR](2026-03-26_PPN_TRACK1_PIR.md). **5-cell architecture**: 4 RRB embedded cells + 1 tree M-type cell. 380/380 GREEN. 108 tests. reader.rkt switchover complete. |
| 2 | Surface normalization as rewriting | 🔄 | [Design D.1c](2026-03-28_PPN_TRACK2_DESIGN.md), [Audit](2026-03-28_PPN_TRACK2_STAGE2_AUDIT.md). **Parse tree as Pocket Universe**: SRE operates directly on `parse-tree-node` via `ctor-desc`. 14 simple rules + 4 specialized propagators. CALM-compliant stratified pipeline (Layered Recovery). Eliminates datum layer, compat layer, syntax objects. Retires reader.rkt (1898 lines) + macros.rkt preparse (~3000-5000 lines). |
| 3 | Parser as propagators (chart/Earley, HR productions) | ⬜ | Replaces parser.rkt (~1500 lines). **From Track 1**: needs span-based SRE decomposition (recognizer reads span of embedded RRB lattice, not single cell value). |
| 3.5 | **Grammar Form: Research + Design** | ⬜ | [`grammar` vision](../research/2026-03-26_GRAMMAR_TOPLEVEL_FORM.md). Multi-view spec. DPO structural preservation. Full theory + syntax after Tracks 1-3. **From Track 1**: typed productions (NTT-typed rewrite rules). |
| 4 | Elaboration as attribute evaluation | ⬜ | IS SRE Track 2C. Dissolves parse/elab boundary. |
| 5 | Type-directed disambiguation | ⬜ | Backward type→parse flow via Galois bridges. Bilattice (gfp/elimination) added here via WF-LE newtype pattern. |
| 6 | Error recovery as lattice repair | ⬜ | Tropical semiring optimization. Track 1 writes error cells; Track 6 adds ATMS repair. |
| 7 | User-defined grammar extensions (`grammar` form) | ⬜ | CAPSTONE. **Notes from Track 1**: token pattern registry migration from hash to cell needed here (dynamic grammar patterns). DPO framework for structural preservation. |
| 8 | Incremental editing (LSP-grade propagation) | ⬜ | IS PM Track 11. **From Track 1 D.7**: RRB structural diff IS the incremental change tracking mechanism. Edit char → new RRB (path-copy) → diff → tree-builder re-resolves affected nodes. Track 8 adds: file watcher, trigger mechanism, persistent tree serialization. |
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

**Design**: [PPN Track 2 Design D.1c](2026-03-28_PPN_TRACK2_DESIGN.md)
**Audit**: [PPN Track 2 Stage 2 Audit](2026-03-28_PPN_TRACK2_STAGE2_AUDIT.md)
**Status**: 🔄 Design phase (D.1c complete, pre-0 benchmarks complete, D.2 pending)

**What**: Replace the preparse expansion pipeline in `macros.rkt` with
SRE rewrite rules operating directly on the parse tree from Track 1.

**Key design decisions (D.1c)**:
- **Parse tree as Pocket Universe**: SRE operates directly on `parse-tree-node` via `ctor-desc`. No datum layer, no compat layer, no syntax objects.
- **CALM-compliant stratified pipeline**: Rewrites at stratum boundaries (Layered Recovery). Set-once cells between strata. R(-1)→R(0)→R(1)→V(0)→V(1)→V(2).
- **14 simple rules** (pattern→template via SRE descriptors) + **4 specialized propagators** (pipe fusion, mixfix Pratt, defn-multi, session-ws).
- **Module Theory lens**: Parse tree is a module over the endomorphism ring of rewrite rules. Submodule independence = parallelizability.
- **Retirement**: reader.rkt (1898 lines) + macros.rkt preparse (~3000-5000 lines). Total ~5000-7000 lines eliminated.

**Replaces**: `preparse-expand-form`, `preparse-expand-all`,
`preparse-expand-single`, `preparse-expand-subforms` (~3000 lines).
Also: `flatten-ws-kv-pairs`, `rewrite-implicit-map`, dot-access
transformation, broadcast transformation, all surface-level desugaring.

**Deferred items incorporated**: Mixfix (specialized Pratt propagator), token struct migration (eliminated — parse tree IS the representation), syntax-object elimination (parse tree nodes carry srcloc directly), reader.rkt retirement (explicit Phase 8c).

Each rewrite IS a DPO rewrite rule. The preparse phase IS hypergraph
rewriting on the parse tree — we're just doing it imperatively today.

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

### Module Theory ↔ PPN

[Module Theory on Lattices](../research/2026-03-28_MODULE_THEORY_LATTICES.md): PPN domains form a filtration (Token ⊆ Surface ⊆ Core). Cross-level bridges are module homomorphisms. Parse ambiguity = quotient-module extraction.

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
