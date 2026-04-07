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
- [From S-Expression IR to Propagator Compiler](../research/2026-03-30_SEXP_IR_TO_PROPAGATOR_COMPILER.md) — sexp role analysis, self-hosting trajectory (Racket prototype → propagator compiler → LLVM lowering → Logos self-hosting)
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
| 2 | Surface normalization as rewriting | ✅ | [Design D.1c+§8](2026-03-28_PPN_TRACK2_DESIGN.md), [PIR](2026-03-29_PPN_TRACK2_PIR.md). reader.rkt DELETED. Tree parser switchover + merge deployed. |
| 2B | Production deployment + mixfix Pocket Universe | ✅ | [Design §12](2026-03-30_PPN_TRACK2B_DESIGN.md), [PIR](2026-03-30_PPN_TRACK2B_PIR.md). Merge deployed (source-line-keyed). Mixfix claim lattice. Pipe/compose rewrites. `use-tree-parser?` deleted. |
| 3 | Parser as propagators — ON-NETWORK | ✅ | [Design D.5b+§11+§12](2026-04-01_PPN_TRACK3_DESIGN.md), [PIR](2026-04-02_PPN_TRACK3_PIR.md). All forms ON-NETWORK. Per-form cells. SRE domains + ctor-descs. Dependency-set Pocket Universe. Spec cells. parser.rkt retired from WS dispatch. 383/383 GREEN. |
| 3.5 | **Grammar Form: Research + Design** | ⬜ | [`grammar` vision](../research/2026-03-26_GRAMMAR_TOPLEVEL_FORM.md). Multi-view spec. DPO structural preservation. Full theory + syntax after Tracks 1-3. **From Track 1**: typed productions (NTT-typed rewrite rules). |
| 4A | Elaboration as attribute evaluation — typing on-network | ✅ | [Design D.4](2026-04-04_PPN_TRACK4_DESIGN.md), [PIR](2026-04-04_PPN_TRACK4_PIR.md). 46% on-network typing. Ephemeral PU architecture. SRE typing domain (~150 entries). Bidirectional app writes. Context cells. NRC codified. |
| 4B | Attribute evaluation — typing + constraints + mult + warnings | ✅ | [Design D.2](2026-04-05_PPN_TRACK4B_DESIGN.md). All 5 attribute domains on-network. On-network primary for all command types. Global attribute store on persistent registry (§9). P1/P2/P3 patterns. 7578 tests GREEN, 133s. 6 imperative bridges remain as scaffolding → Track 4C scope. |
| 4C | Elaboration on-network — retire ALL imperative bridges | ⬜ | [Design Note](../research/2026-04-07_PPN_TRACK4C_DESIGN_NOTE.md). 6 bridges from 4B: parametric resolution, solve-meta!, infer/err fallback, freeze/zonk, unsolved-dict, warning params. Bridges dissolve when elaboration boundary moves on-network. `:kind` facet separation, parametric-narrowing propagator, attribute-map-based freeze, checkQ retirement, remaining expression kinds. DEPENDS ON BSP-LE 1.5 (cell-based TMS) for union types. SRE 6 for on-network reduction (nf). |
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

### Track 2: Surface Normalization as Rewriting ✅

**Design**: [PPN Track 2 Design D.1c + §8 Addendum](2026-03-28_PPN_TRACK2_DESIGN.md)
**Audit**: [PPN Track 2 Stage 2 Audit](2026-03-28_PPN_TRACK2_STAGE2_AUDIT.md)
**PIR**: [PPN Track 2 PIR](2026-03-29_PPN_TRACK2_PIR.md)
**Status**: ✅ COMPLETE. reader.rkt deleted. Switchover live. Phase 11 deferred to Track 3 prerequisite.

**Delivered**:
- **surface-rewrite.rkt** (~1200 lines, 31 tests): Tag refinement T(0), form grouping G(0), pipeline-as-cell model, 10 rewrite rules
- **tree-parser.rkt** (~1250 lines, 26 tests): Core language tree→surf-* (def, defn, fn, Pi, Sigma, arrows, match, builtins)
- **parse-reader.rkt**: Full compat wrapper (tokenize-string, read-all-forms-string, prologos-read-syntax), native implementations replacing reader.rkt
- **reader.rkt DELETED** (1898 lines) — Phase 10 (`469e2276`)
- **Switchover**: Tree parser output used for elaboration via spec-aware merge
- **Remaining (deferred to Track 3)**: macros.rkt sexp expander retirement (~1000 lines) — blocked on tree parser handling all form types

**Key design decisions**:
- **Parse tree as Pocket Universe**: SRE operates directly on `parse-tree-node` via `ctor-desc`
- **CALM-compliant stratified pipeline**: Set-once cells between strata
- **Spec-aware merge**: Generated defs from preparse + user forms from tree parser

### Track 3: Parser as Propagators ✅ COMPLETE

**Status**: COMPLETE (2026-04-02). [Design](2026-04-01_PPN_TRACK3_DESIGN.md), [PIR](2026-04-02_PPN_TRACK3_PIR.md).

**What was delivered**: Per-form cells on elab-network. Tree-parser canonical (§11 pivot): ALL top-level form dispatch ON-NETWORK via `parse-form-tree`. Expression parsing via datum conversion (`parse-datum` as canonical expression parser). SRE integration (§12): FormCell + SpecCell domains registered with property inference, 5 ctor-descs for surf-* decomposition. Dependency-set Pocket Universe (Boolean powerset). Spec cells with collision detection.

**parser.rkt**: Effectively retired from WS form dispatch. Called from on-network dispatch for expression parsing (datum conversion) and from sexp path (`process-string`).

**Preparse**: Retained for registration side effects only (idempotent). PM series migrates to persistent cells.

**Original description** (preserved for reference):

Replace `parser.rkt` with grammar-production-based parsing on
the network. Each grammar production installs propagators. Parse forests
(ambiguity) as lattice values.

**Replaces**: `parser.rkt` (~1500 lines), `parse-datum`, all the
`parse-*` functions.

**Prerequisite from Track 2 (Phase 11 — sexp expander retirement)**:
Track 2 deleted reader.rkt but could NOT delete macros.rkt's sexp
expanders (~1000 lines: `expand-if`, `expand-when`, `expand-cond`,
`expand-let`, etc.) because `preparse-expand-all` is still called by
both the sexp and WS processing paths. These expanders become deletable
once the tree parser (from Track 2) handles ALL form types — including
`data`, `trait`, `impl`, `spec`, and generated defs (constructors,
accessors, type definitions) — making `preparse-expand-all` obsolete.
Track 3's early phases should include:
1. Extend tree-parser.rkt to handle all preparse-consumed forms
2. Move registration (data/trait/impl → registries) to tree-level
3. Delete `preparse-expand-all` + sexp-specific expanders from macros.rkt
4. Retain `expand-top-level` and `expand-expression` (post-parse, shared)

**From Track 2B**: V(1) user macros — tree-level macro expansion as grammar productions. User-defined macros (`defmacro`) register rewrite rules that fire at tree level. Currently handled by merge fallback to preparse. V(1) belongs here if macros are grammar productions, or in Track 7 if macros are user-defined grammar extensions. Decision deferred to Track 3 design.

**From Track 2B scaffolding (design considerations for Track 3)**:
- *Registry-as-cell*: Track 2B reads operator/precedence-group registries via Racket parameters (imperative). Track 3 should make these cells on the parse network — when a `precedence-group` or `:mixfix` spec is registered, dependent mixfix resolution cells re-fire.
- *Pocket Universe scheduling*: Track 2B's mixfix resolution executes the lattice computation eagerly within a rewrite-rule builder. Track 3 can separate strata into actual BSP rounds if needed — the lattice is the same, only the scheduler changes.
- *load-module exclusion*: Track 2B skips the merge for load-module (recursive merge causes unbounded read-to-tree). Track 3's propagator architecture eliminates this — cells replace function calls, no recursion.
- *Merge identity matching → shared cells*: Track 2B's source-line-keyed merge matches pipeline outputs by source line (hash lookup). In Track 3, both pipelines write to the SAME cell per source form — identity is structural (shared cell), not computed (key lookup). The source-line key disappears. The `merge-form` lattice join function becomes the cell's merge function directly. See Track 2B §12.6.
- *Merge scheduling → propagator firing*: Track 2B iterates preparse surfs sequentially. In Track 3, each cell's join fires when both inputs arrive (event-driven). Ordering emerges from cell readiness, not list position.

**Key mechanism**: Chart parsing / Earley as fixpoint. Each chart entry
is a cell. Completion/prediction/scanning are propagators. The grammar
is the set of registered productions. Adding a production = adding a
propagator.

**Semiring parsing (Goodman 1999)**: Same parser parameterized by semiring.
Boolean = recognition. Counting = ambiguity. Tropical = optimal parse.
Forest = all parses. The semiring is a lattice parameter — PPN Track 0's
lattice design determines which semiring we use.

### Track 4: Elaboration as Attribute Evaluation

**Adhesive DPO foundation**: Elaboration rules are DPO rewriting on adhesive presheaf objects. Type inference (meta-solving), elaboration (surface→core), and narrowing (bidirectional type checking) are all DPO spans. Non-dependent definitions have no critical pairs → parallelize. Dependent definitions have critical pairs → ordering required (matching the dependency analysis the pipeline already provides). See [Adhesive Categories research](../research/2026-04-03_ADHESIVE_CATEGORIES_PARSE_TREES.md) §6. CALM-adhesive unified guarantee: monotone elaboration propagators implementing DPO rules without critical pairs are provably coordination-free, order-independent, parallelizable, and composable (§7).

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

**From Track 3 (2026-04-02)**:

Track 3 delivers the foundation that Track 4 builds on:

1. **Per-form cells on elab-network**: Each top-level form has a cell. Track 4 adds TYPE cells and CONSTRAINT cells alongside form cells. The parse/elaborate boundary dissolves because both use the same network.

2. **SRE ctor-descs for surf-* structs** (§12 S4): surf-def, surf-defn, surf-eval, surf-check, surf-narrow have registered decomposition patterns. Track 4's elaboration reads form sub-structure via SRE decomposition (`ctor-desc-extract-fn`), creating typed sub-cells. This is the attribute evaluation pattern: each component gets a cell, propagators connect them.

3. **FormCell SRE domain** (§12 S1): Registered with algebraic properties confirmed by inference (Heyting). Track 4 adds per-expression type domains.

4. **Spec cells** (§12 S3+S5): Spec cells exist on-network with collision detection. Track 4 wires a propagator: when spec cell has value, write spec type to defn's type cell. This replaces the scaffolding `annotate-surfs-with-specs`.

5. **Surfs as cell values**: Track 3 extracts surfs as a list (not in cells). Track 4's FIRST step: put surfs INTO form cells as the final value. This enables propagators to read/write surfs on-network. The spec→defn propagator (S5 completion) becomes possible.

6. **Dependency-set Pocket Universe**: Track 4 can extend the transform set with elaboration-phase transforms (type-inferred, constraints-resolved, etc.).

**Prerequisite ordering**: SRE Track 2H (type lattice redesign) → Grammar Form research → PPN Track 4.

**From Track 2B**: V(2) spec injection — cross-form attribute flow where one form's `spec` declaration annotates another form's `defn`. Track 3 scaffolding (`annotate-surfs-with-specs`). Track 4 replaces with on-network propagator.

**From DEFERRED.md** (relabeled 2026-03-30):
- TMS-aware infrastructure cells: `restore-meta-state!` cannot be retired until elab-network fields are TMS-managed. This is Track 4 scope (formal propagator edges require TMS-aware cells).
- Unify type inference + trait resolution under propagator network: constraint solving currently driven by imperative retry loops, not propagator scheduler. This IS Track 4's core work.

**From SRE Track 2G PIR + type lattice investigation (2026-03-30)**:

*Prerequisite*: SRE Track 2H (type lattice redesign) delivers the algebraic foundation Track 4 needs:
- Union types as subtype join (`Int ⊔_sub String = Int | String`, not ⊤) — Track 2H Phase 2-3
- Subtype-aware meet (`Int ⊓_sub Nat = Nat`, not ⊥) — Track 2H Phase 4
- Full quantale: tensor (`type-tensor`) distributes over union-join — Track 2H Phase 5-6
- Tensor-aware elaboration (pure, no speculation) — Track 2H Phase 6
- Heyting under subtype ordering → pseudo-complement error reporting — Track 2H Phase 9
- Per-relation algebraic properties: `type.subtype.heyting = #t`, `type.equality.heyting = #f` — Track 2H Phase 7-8

*Architectural pattern*: Type inference on the propagator network is structurally analogous to LE resolution — facts as cells, typing rules as propagators, resolution as fixpoint, trait selection as clause selection with ATMS. NOT using the LE directly — but the same propagator patterns apply. Draw from LE when designing type inference propagators.

*Semiring structure — the type lattice as quantale* ([Lattice Foundations](../research/2026-03-26_LATTICE_FOUNDATIONS_PPN.md) §2.4, [SRE Track 2H Design](2026-04-02_SRE_TRACK2H_DESIGN.md) §10):

The type lattice is a **quantale** — simultaneously a lattice (for fixpoint computation) and a semiring (for type-level "parsing" = elaboration):
- **Addition (⊕)**: union-join (`Int ⊕ String = Int | String`). Delivered by SRE Track 2H.
- **Multiplication (⊗)**: function type application (`(A → B) ⊗ A = B`). Delivered by SRE Track 2H as pure `type-tensor`. Track 4 wires it as a propagator.

The research says: "The resulting 'parse' doesn't produce trees — it produces types. This is type inference as parsing: the grammar's semantic actions compute types, and the semiring combines types according to the grammar's composition rules."

SRE Track 2H delivers both halves of the quantale:
- **⊕ (union-join)**: subtype-aware join producing union types with absorption
- **⊗ (tensor)**: `type-tensor` — reified function application distributing over unions, wired into the imperative elaborator as a pure function

Track 2H also wires tensor-aware elaboration into `infer` for `expr-app` (Phase 6), handling union-typed functions and arguments via pure `type-tensor` — no speculation, no rollback. The existing `check(G, e, A | B)` speculation path (`with-speculative-rollback` at `typing-core.rkt:2424`) is NOT extended by Track 2H. It is documented as debt for Track 4.

Track 4's design MUST:
1. Wire `type-tensor` as a **propagator fire function**: given cells for f-type and arg-type, write result-type. The propagator IS the tensor on-network.
2. **Retire imperative union speculation via ATMS**: The `with-speculative-rollback` path for `check(G, e, A | B)` (`typing-core.rkt:2424`) uses `save-meta-state`/`restore-meta-state!` — sequential, imperative, not on-network. Track 4 replaces this with ATMS-managed assumption branches: each union component becomes an assumption, elaboration proceeds under each assumption in parallel, the ATMS manages consistency and retracts contradictory branches. Union types ARE type-level ambiguity — the same pattern as parse ambiguity in the Lattice Foundations research (§7.4, §8.4). After Track 2H, more union types flow through the elaborator, making this retirement more pressing.
3. Connect to the **6-domain reduced product** architecture: the type lattice is one of six domains (token, surface, core, type, mult, session) connected by Galois bridges. Track 4 builds the Surface→Type and Type→Surface bridges.
4. Design the type-level semantic actions that make grammar productions compute types — these are the propagators that turn parsing into type inference.
5. Semiring axioms (distribution, associativity, identity, annihilation) are validated by Track 2H — Track 4 inherits them.

*Integration vision for Track 4*:
1. AST nodes get type cells (PPN Track 4 = attribute evaluation)
2. Type signatures are cell writes (facts)
3. Application installs propagator: `f x` → SRE decomposes `f`'s Pi type, connects argument cell to domain, result cell to codomain — **this IS the tensor (⊗)**
4. Unification = PUnify cell-tree sharing (bidirectional info flow)
5. Trait resolution = constraint cells that fire on meta resolution (LE pattern with ATMS)
6. Type errors = contradiction (⊤) → ATMS dependency trace → Heyting pseudo-complement (after type lattice redesign)

**From SRE Track 2H: scaffolding to retire in Track 4** ([PIR §11](2026-04-03_SRE_TRACK2H_PIR.md)):

Track 2H delivered 4 scaffolding components that Track 4 MUST retire. If not scoped explicitly in Track 4's design, scaffolding becomes permanent (validated ≠ deployed pattern).

| Scaffolding | What it does | Permanent replacement |
|-------------|-------------|----------------------|
| `type-tensor-distribute` | Imperative union distribution (iterates components, builds result union) | Network fires `type-tensor-core` per component; cell merge produces union (M3) |
| `absorb-subtype-components` | O(n²) pairwise subtype filter on union component list | Network does pairwise merge natively as writes arrive (F3) |
| `type-pseudo-complement` | Function-over-list: filters context types by meet incompatibility | ATMS nogood → retract conflicting assumption → pseudo-complement from dependency structure (M2) |
| Property keyword API (`#:relation` on `has-property?`) | Keyword dispatch selects which ordering's properties to query | Property cells (`property-cell-ids`) on network; query = cell read (F5) |

Track 4's design should include a "scaffolding retirement" phase that replaces each with the on-network mechanism. The retirement order: property cells first (simplest — populate existing `property-cell-ids` field), then tensor distribution (requires tensor propagator wiring), then pseudo-complement (requires ATMS), then absorption (requires union cells with pairwise merge).

**From Track 2B scaffolding (design considerations for Track 4)**:
- *Eager Pocket Universe → BSP strata*: The mixfix claim lattice (from Track 2B) executes eagerly. Track 4's elaboration network could host mixfix resolution cells alongside type cells — precedence resolution and type checking as concurrent information flow on the same network. The lattice design from Track 2B is the foundation; Track 4 distributes it across actual BSP strata.
- *Per-form lattice join as cell merge*: Track 2B's `merge-form` function (§12.6) is the permanent per-form lattice join for merging pipeline outputs. Track 4 inherits this as the cell merge function when parse and elaboration cells coexist on the same network. The join logic (tree parser > preparse for user forms, preparse > tree parser for spec-annotated/generated) encodes pipeline preference as lattice ordering — both pipelines write, the lattice resolves. No "choice function" — the ordering IS the merge.

### Track 5: Type-Directed Disambiguation

**Adhesive DPO foundation**: Error repair rules (insert, remove, substitute tokens) are DPO rewriting on the token stream. Multiple valid repairs → tropical semiring selects optimal. Critical pair analysis on repair rules identifies where repairs interact. See [Adhesive Categories research](../research/2026-04-03_ADHESIVE_CATEGORIES_PARSE_TREES.md) §6.

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

**From Track 2B**: If V(1) user macros are NOT handled by Track 3 as grammar productions, they belong here as user-defined grammar extensions. The distinction: Track 3 macros are production-level (the compiler's grammar is extended), Track 7 macros are user-level (user code extends the grammar). Decision deferred to Track 3 design — if Track 3 provides the mechanism, Track 7 exposes it to users.

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
