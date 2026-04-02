# PPN Track 3: Parser as Propagators — Stage 3 Design (D.2)

**Date**: 2026-04-01
**Series**: [PPN (Propagator-Parsing-Network)](2026-03-26_PPN_MASTER.md)
**Prerequisite**: [PPN Track 2B ✅](2026-03-30_PPN_TRACK2B_DESIGN.md) (merge deployed, mixfix Pocket Universe, use-tree-parser? deleted)
**Audit**: [PPN Track 3 Stage 2 Audit](2026-04-01_PPN_TRACK3_STAGE2_AUDIT.md)
**Principle**: Propagator Design Mindspace ([DESIGN_METHODOLOGY.org](principles/DESIGN_METHODOLOGY.org) § Propagator Design Mindspace)

**Research**:
- [Hypergraph Rewriting + Propagator-Native Parsing](../research/2026-03-24_HYPERGRAPH_REWRITING_PROPAGATOR_PARSING.md) — Engelfriet-Heyker, DPO, semiring parsing, chart-as-fixpoint
- [Tree Rewriting as Structural Unification](../research/2026-03-26_TREE_REWRITING_AS_STRUCTURAL_UNIFICATION.md) — rewriting IS SRE decompose+compose
- [Grammar Toplevel Form Vision](../research/2026-03-26_GRAMMAR_TOPLEVEL_FORM.md) — multi-view grammar specification
- [Categorical Foundations](../research/2026-03-22_CATEGORICAL_FOUNDATIONS_TYPED_PROPAGATOR_NETWORKS.md) — polynomial functors, Galois connections
- [Lattice Foundations for PPN](../research/2026-03-26_LATTICE_FOUNDATIONS_PPN.md) — concrete lattice design
- [SRE Track 2G Design](2026-03-30_SRE_TRACK2G_DESIGN.md) — domain registry, property cells, ring action (infrastructure this track consumes)

**Cross-series consumers**:
- [PPN Track 4](2026-03-26_PPN_MASTER.md) — elaboration as attribute evaluation (dissolves parse/elab boundary)
- [PPN Track 7](2026-03-26_PPN_MASTER.md) — user-defined grammar extensions (capstone)
- [SRE Track 2H](2026-03-22_SRE_MASTER.md) — type lattice redesign (Track 4 prerequisite, not Track 3)

---

## Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| 0 | Pre-0 benchmarks | ⬜ | parse-datum profiling, preparse-expand-all profiling, tree-parser coverage metrics |
| 1 | Close tree-parser coverage gap: data/trait/impl | ⬜ | 3 stubs → full implementations. Registration remains in preparse (scaffolding). |
| 2 | Close tree-parser coverage gap: session/defproc/defr/quote/solver | ⬜ | 5 stubs → full implementations. Complex sublanguages. |
| 3 | Registration migration: preparse → post-tree-parse pass | ⬜ | data/trait/impl/spec/defmacro registration moves to tree-parser level. preparse-expand-all becomes deletable for WS path. |
| 4 | Delete sexp expanders on WS path | ⬜ | ~500-600 lines of macros.rkt expand-* functions become unreachable. preparse-expand-all eliminated from WS pipeline. |
| 5 | Grammar production registry (cell) | ⬜ | Production table as Pocket Universe cell. Keyword → production mapping. Static bulk registration for 236 keyword heads. |
| 6 | Per-form Pocket Universe architecture | ⬜ | One cell per top-level form. Value is Pocket Universe with embedded parse lattice. SRE decomposes for elaboration. |
| 7 | Shared cells replace merge | ⬜ | merge-preparse-and-tree-parser deleted. Both pipelines write to same per-form cell. merge-form becomes cell merge function. |
| 8 | Retire parser.rkt | ⬜ | 6,605 lines deleted. All callers rewired. parse-datum replaced by cell reads. |
| 9 | Acceptance + A/B benchmarks + verification | ⬜ | Full suite GREEN. A/B vs Track 2B baseline. Acceptance file. |
| 10 | PIR + documentation | ⬜ | |

**Phase completion protocol**: After each phase: commit → update tracker → update dailies → run targeted tests → proceed.

---

## §1 Objectives

**End state**: `parser.rkt` is deleted. Every source form is a cell on the propagator network. Grammar productions are registered propagators. The `preparse-expand-all + parse-datum + merge` pipeline is replaced by: read source → write to per-form cells → productions fire → surf-* values emerge at fixpoint. SRE decomposes cell values for elaboration.

**What is delivered**:
1. Tree-parser handles ALL 8 currently-stubbed form types (data, trait, impl, session, defproc, defr, quote, solver)
2. Registration (data constructors, traits, impls, specs, macros) migrated from preparse-expand-all to a post-tree-parse registration pass
3. `preparse-expand-all` eliminated from the WS processing path
4. ~500-600 lines of sexp-specific expanders deleted from macros.rkt
5. Grammar production registry as a Pocket Universe cell — 236 keyword heads bulk-registered, monotonically extensible
6. Per-form Pocket Universe architecture — one cell per top-level source form, value is the full parse tree for that form
7. Shared cells replace the source-line-keyed merge — identity is structural (shared cell), not computed (key lookup)
8. `parser.rkt` (6,605 lines) deleted — all `parse-datum` call sites rewired to cell reads
9. `merge-preparse-and-tree-parser` (80 lines) deleted — no more dual-pipeline merge

**What this track is NOT**:
- It does NOT put registration on the propagator network as cells — incomplete because module-load-time network doesn't exist yet; PM series scope. Registration continues via Racket parameters (scaffolding) but is structured so PM can migrate to cells.
- It does NOT implement semiring-parameterized parsing — incomplete because the semiring abstraction requires the parse forest lattice from PPN Track 5. Boolean (recognition-only) semiring suffices for Track 3.
- It does NOT implement user-defined grammar extensions — incomplete because user-facing `grammar` form requires Track 7 design. Track 3 provides the production registry mechanism that Track 7 exposes.
- It does NOT retire the sexp processing path (`process-string`) — incomplete because sexp mode remains for REPL/test convenience. `parse-datum` remains callable on the sexp path. Retirement is a future cleanup track.
- It does NOT dissolve the parse/elaborate boundary — that is PPN Track 4. Track 3 produces surf-* structs, elaboration consumes them. The boundary is preserved.

---

## §2 Current State (from Audit)

### 2.1 What Exists

**parser.rkt** (6,605 lines): Pure function. 73 `parse-*` functions. 236 keyword head symbols dispatched. 1 boolean parameter (`current-parsing-relational-goal?`). 0 registry reads. Recursive: 512 internal `parse-datum` calls. Single export: `parse-datum`.

**macros.rkt preparse-expand-all** (9,763 lines total): 21 `expand-*` functions. Registration side effects for data/trait/impl/spec/defmacro/bundle/subtype/deftype. ~500-600 lines of sexp-specific expanders (expand-if, expand-cond, expand-let, etc.) deletable once tree-parser covers all forms. 3 already superseded by surface-rewrite.rkt (pipe, compose, mixfix).

**tree-parser.rkt** (1,200 lines): 30 `parse-*-tree` functions. Handles: def, defn, spec, fn, if/when, eval, check/infer, ns/import/export, application, angle/bracket/brace/paren groups, list literals. 8 error stubs: data, trait, impl, session, defproc, defr, quote, solver.

**surface-rewrite.rkt** (2,038 lines): Post-tree-parse rewriting. Pipe (`|>`), compose (`>>`), mixfix (`.{...}`), tag refinement T(0), form grouping G(0). Rewrite rules are already grammar-production-like (pattern → output).

**Merge infrastructure** (driver.rkt, 80 lines): `merge-preparse-and-tree-parser` + `merge-form`. Source-line-keyed identity matching. Per-form lattice join. Called from `process-string-ws-inner` and `process-file-inner` (WS path).

**SRE Track 2G infrastructure** (consumed by Track 3):
- `register-domain!` / `lookup-domain` — pattern for registration as information flow
- Property cells with 4-valued lattice — pattern for per-cell algebraic metadata
- `with-domain-property` / `select-by-property` — pattern for property-gated behavior

### 2.2 What's Missing (from Audit §9)

1. **8 tree-parser error stubs** — data/trait/impl/session/defproc/defr/quote/solver fall back to preparse via merge
2. **Registration is in preparse-expand-all** — imperative side effects, not information flow
3. **merge is scaffolding** — source-line key lookup instead of shared cells
4. **parse-datum is a function call** — not a cell read; not incremental; not composable
5. **236 keyword heads hardcoded** — giant `case` statement, not a registered production table
6. **No per-form cells** — forms exist as list elements, not as network entities

### 2.3 Performance Profile (from Audit §6)

| Metric | Value |
|--------|-------|
| Parse phase wall time (70-cmd .prologos file) | 0ms (unmeasurable) |
| Elaboration + type check wall time | 443ms (27%) |
| Reduction wall time | 1,049ms (64%) |
| `process-string` no-prelude (6 defs) | 103ms/call |
| `process-string` with prelude (6 defs) | 488ms/call |

**Parsing is not a performance bottleneck.** Track 3's value is architecture (collapse 14-file pipeline), incrementality (parse cells for LSP), and extensibility (grammar productions for user-defined syntax).

---

## §3 Design

### 3.1 Propagator Design Mindspace — Four Questions

**1. What is the information?**

For each source form: its surface syntax type (`surf-def`, `surf-defn`, `surf-app`, ...) and its recursive sub-structure. For each keyword head: the mapping from keyword to grammar production (how to parse this form). For each registration form: the fact that a name EXISTS in the program with certain properties (constructors, methods, instances).

These are all FACTS — partial (a form might be recognized but sub-expressions pending), monotone (once known to be a `defn`, always a `defn`).

**2. What is the lattice?**

Three lattices, each with explicitly declared algebraic structure (see §3.8 for full analysis):

- **Per-form parse lattice (FormCell)**: A product lattice with deliberate ordering choices. The stage component is a finite chain (Heyting). The tree-node and surf components use **pipeline-preference ordering** (NOT flat equality) — tree-parser output > preparse output > ⊥. This makes the product distributive and Heyting, avoiding the flat-lattice trap that Track 2G found in the type domain. The registrations component is a powerset (Boolean). The FormCell domain MUST be registered via SRE Track 2G's `register-domain!` with explicit algebraic property declarations. See §3.8 for why these ordering choices matter.

- **Grammar production registry**: `Map Symbol (Set GrammarProduction)` — values are SETS of productions per keyword, not singletons. For Track 3, each set has exactly one element. Track 7 adds ambiguity (multiple productions per keyword, ATMS explores alternatives). The set-valued design avoids the type-lattice mistake of committing to a flat ordering that later needs redesign. Powerset per keyword → distributive, Heyting, Boolean.

- **Registration lattice**: ⊥ (nothing registered) → set of known names with their properties. Monotone — registrations are only added. This is the information currently in `preparse-expand-all`'s side effects. For Track 3, this remains in Racket parameters (scaffolding). The lattice structure is what matters for the future PM migration. Per-key values (e.g., a spec's type annotation) use flat equality with collision = ⊤ (contradiction = error), which is correct semantics.

**3. What is the identity?**

- **Per-form identity**: The cell. Each top-level source form has a cell. Both pipelines (tree parser and preparse) write to the SAME cell. The source-line-keyed merge in Track 2B COMPUTES identity from source lines. In Track 3, identity IS the cell — structural, not computed. (This is the Track 2B scaffolding → permanent migration.)

- **Production identity**: The keyword symbol. `defn` has one production. `data` has one production. The production registry maps keyword → production by symbol identity.

- **Registration identity**: The name. `data Foo` creates a registration keyed by `Foo`. Same as today.

**4. What emerges?**

The fully-parsed program is NOT built step by step. It emerges from all per-form cells reaching their complete state. All productions have fired. All sub-expressions have been recognized. The result is reading the final cell values — each cell holds its complete surf-* struct.

`(map parse-datum expanded-stxs)` is the algorithmic version. The propagator version: per-form cells are populated by tree-parser propagators, and the elaborator reads from them when they're complete. No sequential map. No explicit ordering.

### 3.2 Per-Form Pocket Universe Architecture

Each top-level source form gets ONE cell on the network. The cell value is a Pocket Universe containing:

```
(form-cell-value
  stage         ;; symbol: 'raw | 'tagged | 'grouped | 'rewritten | 'parsed
  tree-node     ;; parse-tree-node at current stage (or #f if parsed)
  surf          ;; surf-* struct (or #f if not yet parsed)
  provenance    ;; symbol: 'none | 'preparse | 'tree-parser — pipeline-preference ordering
  source-line   ;; integer — preserved for diagnostics
  registrations ;; set of registration side-effects (scaffolding for PM migration)
)
```

**Ordering (component-wise, all monotone)**:
- `stage`: Finite chain — `raw < tagged < grouped < rewritten < parsed`. Heyting. Each stage is a stratum.
- `tree-node`: Option with pipeline-preference — `#f < any-node`. At most one node (tree parser overwrites).
- `surf`: Option with pipeline-preference — `#f < preparse-surf < tree-parser-surf`. The provenance field tracks source for the ordering.
- `provenance`: Chain — `none < preparse < tree-parser`. This is the **pipeline-preference ordering** that makes the surf component a chain (Heyting) rather than flat (non-distributive). Track 2B's `merge-form` already encodes this ordering — D.2 makes it explicit and structural.
- `registrations`: Set (powerset) — join is union. Boolean.

The product of these components is distributive and Heyting (product of chains and powersets). See §3.8 for the algebraic property verification.

**Stages** (from Track 2 pipeline, now formalized):

| Stage | Stratum | What Happens | Propagator |
|-------|---------|-------------|-----------|
| `raw` | S0 | Source text parsed into parse-tree-node by tree-builder | Tree-builder (Track 1) |
| `tagged` | S1 | T(0) tag refinement — keyword identification | surface-rewrite.rkt tag rules |
| `grouped` | S2 | G(0) form grouping — sub-expression boundary identification | surface-rewrite.rkt group rules |
| `rewritten` | S3 | Rewrite rules — pipe, compose, mixfix, let, cond, etc. | surface-rewrite.rkt + new productions |
| `parsed` | S4 | Final surf-* struct produced from rewritten tree | Grammar production for this form type |

**Why Pocket Universe, not 5 separate cells per form**: Cell allocation cost. A program with 100 forms would need 500 cells if each stage were a separate cell, plus propagators between them. One Pocket Universe per form = 100 cells, with internal stage advancement. The merge function understands stage ordering and always advances.

**SRE decomposition**: When the elaborator needs to access sub-structure of a parsed form (e.g., a `surf-defn`'s parameter list), SRE's `ctor-desc` decomposes the surf-* struct, creating sub-cells for each component. This is the existing pattern from Track 2 — `parse-tree-node` is already decomposed by SRE via `ctor-desc`. surf-* structs get the same treatment.

### 3.3 Grammar Production Registry

A grammar production maps a keyword to a parsing function:

```racket
;; A grammar production
(struct grammar-production
  (keyword       ;; symbol — the keyword head (e.g., 'defn, 'data, 'fn)
   provenance    ;; symbol: 'builtin | 'library | 'user — for priority ordering
   arity-check   ;; (or/c #f (-> list? boolean?)) — arity validation
   parse-fn       ;; (-> list? srcloc? surf?) — the parsing function
   registration-fn ;; (or/c #f (-> surf? void?)) — registration side-effect (scaffolding)
   sublanguage?   ;; boolean — does this form have a complex sublanguage?
   )
  #:transparent)
```

**The production registry** is a Pocket Universe cell holding a hash from keyword symbol to **set of `grammar-production`**. Values are sets, not singletons — designed for Track 7's ambiguity where multiple productions may exist for the same keyword.

For Track 3, each keyword maps to a singleton set (one builtin production). The dispatch function selects the highest-provenance production from the set (`user > library > builtin`). When the set has one element (Track 3), this is a no-op lookup.

For Track 7, a user `grammar` declaration adds a production to the set. If the user production and a builtin production coexist, provenance ordering resolves (user wins). If two user productions coexist for the same keyword, ATMS explores alternatives (parse ambiguity). This is the same mechanism PPN Track 5 uses for type-directed disambiguation.

The merge function is per-keyword set union: `join(a, b) = {k → a[k] ∪ b[k] | k ∈ keys(a) ∪ keys(b)}`. Powerset per keyword → distributive, Heyting, Boolean. Monotone — productions are only added.

**Relationship to Track 7**: The production registry is the extension point. Track 7 exposes it to users via the `grammar` toplevel form. Track 3 populates it from Racket-side definitions. The mechanism is the same — write to the production registry cell. The set-valued design means Track 7 doesn't need a lattice redesign — it just adds elements to existing sets.

### 3.4 Registration as Information Flow (Scaffolding)

Registration (data constructors, traits, impls, specs, macros) currently happens as side effects in `preparse-expand-all`. Track 3 restructures this:

**Current flow**:
```
preparse-expand-all: read sexp → REGISTER (mutate parameters) → output expanded sexp
parse-datum: read expanded sexp → output surf-*
```

**Track 3 flow**:
```
tree-parser: read tree → output surf-*
registration-pass: read surf-* → REGISTER (mutate parameters, scaffolding)
```

Registration moves from PRE-parse to POST-parse. The surf-* struct IS the registration payload — a `surf-data` struct contains all the information needed to register constructors, accessors, and type definitions. The registration pass reads the surf-* and performs the same mutations as `preparse-expand-all`.

**Why this is progress**: Registration is now separated from parsing. The parsing step is pure (produces surf-*). The registration step is effectful but well-bounded (reads surf-*, writes parameters). This decomposition is the prerequisite for PM's migration — PM replaces the parameter writes with cell writes.

**Why this is still scaffolding**: Registration mutates Racket parameters, not cells. The information-flow model is correct (registration IS monotone information accumulation), but the mechanism is imperative. PM series replaces parameters with persistent cells.

### 3.5 Merge Retirement

Track 2B's merge infrastructure (driver.rkt lines 1481-1562) becomes obsolete:

**Current**: `merge-preparse-and-tree-parser` takes a source string + preparse surfs, runs tree parser, builds `tree-by-line` hash, calls `merge-form` per surf.

**Track 3**: Both pipelines write to the SAME per-form cell. Tree parser writes tree-parsed output. Preparse writes preparse output (sexp path only — WS path no longer calls preparse after Phase 4). The cell's merge function IS `merge-form`. Identity is structural (shared cell), not computed (source line key lookup).

**Phase 7 specifically**:
1. Create per-form cells during file processing
2. Tree parser writes to per-form cells (already produces surf-* output for handled forms)
3. Registration pass reads per-form cells (not preparse output)
4. Delete `merge-preparse-and-tree-parser` and `merge-form` from driver.rkt
5. Delete source-line-keyed identity matching infrastructure

### 3.6 parser.rkt Retirement

After Phases 1-7, `parse-datum` is no longer called on the WS path:
- Tree parser produces surf-* directly (Phases 1-2 close coverage gaps)
- Registration pass replaces preparse-expand-all on WS path (Phase 3)
- Sexp expanders deleted on WS path (Phase 4)
- Per-form cells replace `(map parse-datum expanded-stxs)` (Phases 5-7)

Phase 8 retires parser.rkt:
1. `parse-datum` call sites in driver.rkt WS path: already rewired (Phases 5-7)
2. `parse-datum` call sites in driver.rkt sexp path: RETAINED — sexp `process-string` still calls `parse-datum`. This is the REPL/test path.
3. `parse-datum` call in `load-module`: rewired to tree-parser + registration pass
4. `parse-string`/`parse-port` exports: removed from public API (internal to sexp path)
5. Narrow-var helpers (`narrow-var-symbol?`, `collect-narrow-vars`, etc.): moved to a shared utility or into the relational parsing production

**What parser.rkt retains**: The sexp path (`process-string`) continues to use `parse-datum`. parser.rkt is not DELETED — it is DEMOTED from "essential pipeline component" to "sexp compatibility shim." Its 6,605 lines remain but are only reachable from the sexp test/REPL path, not from any `.prologos` file processing.

**Full deletion** of parser.rkt happens when the sexp path itself is retired (future track).

### 3.7 WS Impact Assessment

Track 3 does NOT add new user-facing syntax. It restructures the internal pipeline. No changes to grammar.ebnf or grammar.org. No new keywords, delimiters, or parse forms.

The user-visible effect is: nothing changes. `.prologos` files parse and elaborate identically. The pipeline is faster (no redundant preparse), more modular (productions vs. monolithic parser), and extensible (production registry for future `grammar` form).

### 3.8 Algebraic Structure Analysis (D.2)

**Motivation**: SRE Track 2G found the type lattice insufficient for Heyting classification — flat equality merge with >2 incomparable atoms is not distributive. That finding necessitates a full type lattice redesign (SRE Track 2H). Track 3's lattices are designed to AVOID this trap by making deliberate ordering choices that ensure the algebraic properties we need for SRE, error reporting, and future extensions.

**Lesson applied**: The algebraic properties depend on which ORDERING we use, not just the carrier set. The same set of values can be Heyting under one ordering and non-distributive under another. We choose orderings that give us the properties we need.

#### 3.8.1 FormCell Component Analysis

| Component | Carrier | Ordering | Algebraic Class | Why This Ordering |
|-----------|---------|----------|----------------|-------------------|
| `stage` | 5 symbols | Total chain: raw < tagged < grouped < rewritten < parsed | Finite chain → **Heyting** | Stages are strictly ordered. No ambiguity. |
| `tree-node` | {#f} ∪ ParseTreeNode | Option: #f < any-node (at most one) | 2-element chain → **Boolean** | Tree parser writes once. No merge between different trees needed. |
| `surf` | {#f} ∪ SurfExpr | Pipeline-preference: #f < preparse-output < tree-parser-output | 3-element chain → **Heyting** | Track 2B's merge-form already encodes this. D.2 makes it explicit via `provenance` field. |
| `provenance` | 3 symbols | Chain: none < preparse < tree-parser | Finite chain → **Heyting** | Tracks which pipeline produced the surf. IS the surf ordering. |
| `source-line` | Nat | Max (information-preserving) | Trivial (single value per form) | Diagnostic only. Not merged. |
| `registrations` | Set of Registration | Set union (powerset) | Powerset → **Boolean** | Accumulation. Monotone. |

**Product lattice**: Chain × Boolean × Heyting × Heyting × Trivial × Boolean = **Heyting** (product of Heyting algebras is Heyting).

**Why this avoids the type-lattice trap**: The type lattice used EQUALITY merge for types — `Int ⊔ Nat = ⊤` because Int and Nat are incomparable atoms in a flat lattice. Track 3's surf component uses PIPELINE-PREFERENCE ordering — `preparse-surf ⊔ tree-parser-surf = tree-parser-surf` because tree-parser is HIGHER in the chain. There are never two incomparable surf values. The provenance field encodes this ordering structurally.

**Track 5 lattice evolution**: When Track 5 adds parse ambiguity, the surf component changes from a 3-element chain (one surf per form) to a **set of candidate surfs** (multiple parses). This is a powerset → Boolean. The product remains Heyting (powerset is stronger than Heyting). The design anticipates this: the `provenance` field becomes per-candidate, not per-form. No lattice REDESIGN needed — the component changes from chain to powerset, both of which are Heyting-or-better.

#### 3.8.2 Production Registry Analysis

| Component | Carrier | Ordering | Algebraic Class |
|-----------|---------|----------|----------------|
| Per-keyword value | Set of GrammarProduction | Set union (powerset) | **Boolean** |
| Registry | Map Symbol (Set GrammarProduction) | Per-key set union | **Boolean** (product of Boolean per key) |

**Track 7 provenance resolution**: Within a keyword's production set, provenance ordering (`user > library > builtin`) selects the active production. This is a CHOICE function on the set, not a lattice operation. The lattice (set union) accumulates all productions; the dispatch function selects from the accumulated set. Decomplected: accumulation is lattice, selection is pure function.

**Ambiguity**: If two productions of the same provenance exist for the same keyword, the production set has >1 element at the same provenance level. This IS parse ambiguity — Track 5's ATMS-tagged speculation resolves it. The lattice doesn't need to resolve ambiguity; it accumulates it. Resolution is a separate concern (ATMS).

#### 3.8.3 Registration Lattice Analysis (Scaffolding — PM Migration Target)

| Registry | Per-key ordering | Collision semantics | Algebraic Class |
|----------|-----------------|-------------------|----------------|
| Constructors | Set of CtorDesc per type | Union (accumulate) | Powerset → **Boolean** |
| Traits | Flat per trait name | Collision = ⊤ (error) | Flat → **NOT distributive** |
| Impls | Set per (trait, type) | Union (multiple impls allowed) | Powerset → **Boolean** |
| Specs | Flat per function name | Collision = ⊤ (error) | Flat → **NOT distributive** |
| Macros | Flat per macro name | Collision = ⊤ (error) | Flat → **NOT distributive** |

**NOTE**: Trait, spec, and macro registries are flat-per-key — same structure as the type lattice under equality. This means they are NOT distributive. For Track 3 (scaffolding via parameters), this doesn't matter — parameters aren't lattice-merged. For PM (cells on network), the per-key flat components will need the same attention as the type lattice. Options:
1. **Accept flat**: collision = ⊤ is the correct semantics (redeclaring a trait is an error)
2. **Version ordering**: trait-v2 > trait-v1 (incremental redefinition). Chain → Heyting.
3. **Provenance ordering**: user-defined > library-defined. Chain → Heyting.

PM's design should address this. Track 3 notes it but does not solve it.

#### 3.8.4 SRE Domain Registration

Track 3 MUST register its lattice domains via SRE Track 2G's `register-domain!` with explicit property declarations:

```racket
;; Register FormCell as an SRE domain
(register-domain!
  'form-cell
  (make-sre-domain
    ;; ... merge/meet/bot/top ...
    #:declared-properties
    (hasheq 'commutative-join  prop-confirmed
            'associative-join  prop-confirmed
            'idempotent-join   prop-confirmed
            'has-meet          prop-confirmed
            'commutative-meet  prop-confirmed
            'associative-meet  prop-confirmed
            'distributive      prop-confirmed     ;; pipeline-preference ordering
            'has-pseudo-complement prop-confirmed  ;; finite Heyting
            'has-complement    prop-refuted)))     ;; NOT Boolean (stages have >2 elements)

;; Register ProductionRegistry as an SRE domain
(register-domain!
  'production-registry
  (make-sre-domain
    ;; ... merge/meet/bot/top ...
    #:declared-properties
    (hasheq 'commutative-join  prop-confirmed
            'associative-join  prop-confirmed
            'idempotent-join   prop-confirmed
            'has-meet          prop-confirmed
            'distributive      prop-confirmed
            'has-pseudo-complement prop-confirmed
            'has-complement    prop-confirmed)))   ;; Boolean (powerset)
```

**SRE Track 2G's inference validates declarations**: After registration, `infer-domain-properties` tests the declared properties against actual samples. If the pipeline-preference ordering is implemented incorrectly (e.g., a merge function that doesn't respect the chain), inference catches the counterexample. This is the safety net that was missing for the type lattice's distributivity assumption.

#### 3.8.5 Summary: Why These Lattices Won't Need Redesign

| Lattice | Algebraic Class | Design-for-Future Provision |
|---------|----------------|---------------------------|
| FormCell | Heyting | Surf component changes from chain → powerset in Track 5 (both Heyting-or-better). No redesign. |
| ProductionRegistry | Boolean | Set-valued per keyword. Track 7 adds elements to sets. No redesign. |
| Registration (scaffolding) | Mixed | Flat components noted. PM design must address. Track 3 doesn't commit to a lattice structure for registrations. |

The type lattice required redesign because it committed to flat equality as the ordering, then discovered that downstream consumers (Heyting error reporting) needed a richer ordering. Track 3 avoids this by:
1. **Choosing pipeline-preference ordering** for components that would otherwise be flat
2. **Using set-valued collections** for components that could later have multiple values (production sets, not singletons)
3. **Registering domains with SRE 2G** so property inference validates the algebraic structure
4. **Noting flat components explicitly** in the registration lattice so PM doesn't inherit the assumption

---

## §4 Phase Details

### Phase 0: Pre-0 Benchmarks

**What**: Establish baselines and validate audit assumptions.

1. **parse-datum micro-benchmark**: Time `parse-datum` on representative programs (6-def no-prelude, 20-def with prelude). Confirm the audit finding that parsing is <1ms.
2. **preparse-expand-all micro-benchmark**: Time `preparse-expand-all` separately. Identify how much time is in expansion vs. registration.
3. **Tree-parser coverage metrics**: For each form type, count how many instances in the test suite are tree-parser-handled vs. preparse-fallback. Quantify the coverage gap.
4. **Merge overhead**: Time `merge-preparse-and-tree-parser` separately. Confirm it's negligible.

**Design input**: If preparse-expand-all is expensive (e.g., >10ms for moderate programs), the registration migration (Phase 3) has performance value beyond architecture. If tree-parser coverage is >90%, the gap-closing work (Phases 1-2) is small.

### Phase 1: Close Coverage Gap — data/trait/impl

**What**: Implement `parse-data-tree`, `parse-trait-tree`, `parse-impl-tree` in tree-parser.rkt. These are the 3 most important stubs — they are the most commonly used registration forms.

**Scope per form**:

- **data**: Tree → `surf-data` struct. Must handle: type parameters, constructor declarations, deriving clauses. Does NOT perform registration (that stays in preparse for now — Phase 3 moves it).
- **trait**: Tree → `surf-trait` struct. Must handle: trait name, type parameters, method signatures, supertraits.
- **impl**: Tree → `surf-impl` struct. Must handle: trait name, implementing type, method bodies.

**Validation**: Each new tree-parser function is tested at Level 2 (WS string via `process-string-ws`) and Level 3 (`.prologos` acceptance file). The merge should route these forms through the tree parser instead of falling back to preparse.

**Key risk**: data/trait/impl forms involve implicit generated definitions (constructors, accessors, method defaults). These are currently generated by `preparse-expand-all`. Phase 1 does NOT handle generation — the merge still routes generated defs through preparse. Phase 3 addresses generation.

### Phase 2: Close Coverage Gap — session/defproc/defr/quote/solver

**What**: Implement the remaining 5 error stubs. These are less frequently used but have complex sublanguages.

- **session**: Session type bodies with Send/Recv/Choice/Offer. Complex sublanguage.
- **defproc**: Process definitions with send/recv/select/offer primitives.
- **defr**: Relational definitions with `?`-prefixed variables, `&>` clauses.
- **quote**: Quoted expressions to literal data.
- **solver**: Solver configuration blocks.

**Ordering within Phase 2**: quote and solver are simple (10-20 lines each). session/defproc/defr are complex (100-200 lines each). Do simple ones first for quick wins.

### Phase 3: Registration Migration

**What**: Move registration side effects from `preparse-expand-all` to a post-tree-parse registration pass.

**Current**: `preparse-expand-all` calls registration functions (from namespace.rkt) as it encounters data/trait/impl/spec forms:
- `handle-data-decl` → registers constructors, accessors, type defs
- `handle-trait-decl` → registers trait declaration, method signatures
- `handle-impl-decl` → registers trait implementation
- `handle-spec-decl` → pre-scans and injects type annotations
- `handle-defmacro-decl` → registers macro definitions

**Track 3**: A new function `register-from-surfs` iterates over the tree-parser's surf-* output and calls the same registration functions. The registration logic is UNCHANGED — only the trigger point moves from preparse to post-parse.

```racket
;; Phase 3: post-tree-parse registration
(define (register-from-surfs surfs)
  (for ([surf (in-list surfs)])
    (cond
      [(surf-data? surf)    (register-data-from-surf surf)]
      [(surf-trait? surf)   (register-trait-from-surf surf)]
      [(surf-impl? surf)    (register-impl-from-surf surf)]
      [(surf-spec? surf)    (register-spec-from-surf surf)]
      [(surf-defmacro? surf) (register-macro-from-surf surf)]
      [else (void)])))
```

**Spec pre-scan**: `preparse-expand-all` pre-scans all `spec` forms before expanding other forms (so `defn` can see its type annotation). This ordering dependency must be preserved: `register-from-surfs` processes specs in a first pass, then other forms.

**Generated defs**: `preparse-expand-all` generates new defs from data/trait declarations (constructors, accessors, default methods). These generated defs must also be produced by the registration pass. They become additional surf-* structs injected into the form list.

### Phase 4: Delete Sexp Expanders on WS Path

**What**: With registration moved to post-tree-parse (Phase 3), `preparse-expand-all` is no longer needed on the WS path. The WS pipeline becomes:

```
read-all-syntax-ws → tree-parser → surface-rewrite → register-from-surfs → process-commands
```

**Deletable expanders** (~500-600 lines in macros.rkt):
- `expand-if`, `expand-cond`, `expand-let`, `expand-let-bracket-bindings`, `expand-let-inline-assign`, `expand-do` — tree-parser handles these forms directly
- `expand-list-literal`, `expand-lseq-literal` — tree-parser handles
- `expand-pipe-block`, `expand-compose-sexp`, `expand-mixfix-form` — surface-rewrite.rkt handles
- `expand-quote`, `expand-quasiquote` — tree-parser handles
- `expand-with-transient` — tree-parser handles
- `expand-def-assign` — tree-parser handles

**NOT deletable** (shared post-parse expanders, used by elaborator):
- `expand-top-level` — post-parse normalization for data/trait/impl
- `expand-expression` — post-parse expression normalization
- `expand-bundle-constraints` — constraint expansion
- `expand-defn-multi` — multi-arity defn normalization

**driver.rkt changes**: `process-string-ws-inner` and `process-file-inner` (WS path) stop calling `preparse-expand-all`. They call tree-parser → surface-rewrite → `register-from-surfs` → `process-commands`.

### Phase 5: Grammar Production Registry

**What**: Create the production registry as a Pocket Universe cell. Register the 236 keyword heads.

The production registry is a hash from keyword symbol to `grammar-production` struct. At system initialization, all built-in productions are bulk-registered:

```racket
(define (register-builtin-productions!)
  ;; Core language
  (register-production! 'def  parse-def-tree)
  (register-production! 'defn parse-defn-tree)
  (register-production! 'spec parse-spec-tree)
  (register-production! 'fn   parse-fn-tree)
  ;; ... 232 more
  )
```

**For Track 3**: The production registry is a module-level hash (scaffolding, same pattern as SRE 2G's domain registry). Not on the network — PM series migrates.

**For Track 7**: The production registry becomes a cell on the network. User `grammar` forms write to it. Dependent parsing cells re-fire when new productions arrive.

### Phase 6: Per-Form Pocket Universe Architecture

**What**: Replace `(map parse-datum expanded-stxs)` with per-form cell creation and production dispatch.

For each top-level form in the source:
1. Create a cell for this form
2. Look up the production by keyword head
3. Fire the production's parse function on the form's tree-parser output
4. Write the resulting surf-* struct to the form's cell

The cell holds a `form-cell-value` Pocket Universe (§3.2). The production dispatch replaces the giant `case` statement in `parse-list`.

**Connection to surface-rewrite.rkt**: surface-rewrite.rkt's existing rewrite rules (T(0) tag refinement, G(0) form grouping, pipe/compose/mixfix) are already grammar-production-like. Phase 6 formalizes them: each rewrite rule IS a registered production that advances the Pocket Universe's stage.

### Phase 7: Shared Cells Replace Merge

**What**: Delete `merge-preparse-and-tree-parser`. Both pipelines write to the same per-form cell.

After Phase 6, the WS path creates per-form cells and writes tree-parser output to them. The sexp path (retained for `process-string`) still uses `parse-datum`. For `process-string`, the per-form cell mechanism is not used — `parse-datum` returns surf-* directly.

The WS path no longer calls `(map parse-datum expanded-stxs)` and no longer calls the merge. The merge infrastructure is dead code on the WS path.

**Delete**:
- `merge-preparse-and-tree-parser` (driver.rkt)
- `merge-form` (driver.rkt)
- Source-line-keyed identity matching hash construction
- `tree-by-line` hash building

### Phase 8: Retire parser.rkt (Demote to Sexp Shim)

**What**: Remove `parse-datum` from the WS and file-processing paths. Retain only for sexp `process-string`.

**Call sites rewired**:
- `process-string-ws-inner`: uses per-form cells (Phase 6)
- `process-file-inner` WS path: uses per-form cells (Phase 6)
- `load-module`: uses tree-parser + `register-from-surfs` (Phase 3)
- `parse-type-annotation-string`: single call — move to a local helper

**Call sites retained**:
- `process-string-inner` (sexp path): continues using `(map parse-datum expanded-stxs)`

**parser.rkt demoted**: Still exists, still provides `parse-datum`, but only reachable from sexp `process-string`. Not on any `.prologos` file processing path.

### Phase 9: Acceptance + Benchmarks + Verification

**What**: Full regression verification and performance comparison.

1. **Acceptance file**: Run `process-file` on ALL example `.prologos` files. Zero errors.
2. **Full test suite**: 383+ files, 7491+ tests, all pass.
3. **A/B benchmark**: `bench-ab.rkt --runs 15 benchmarks/comparative/` vs Track 2B baseline. Parse-phase change should be within noise (parsing was 0ms).
4. **Suite wall time**: Should be ≤ baseline (removal of redundant preparse on WS path may improve).

### Phase 10: PIR + Documentation

Standard PIR per methodology. Update PPN Master, dailies, MASTER_ROADMAP.org.

---

## §5 NTT Speculative Syntax Model

Expressing the Track 3 architecture in NTT speculative syntax. This exercises the NTT syntax and validates that every component is "on network."

### 5.1 Per-Form Parse Lattice (Pocket Universe)

```prologos
;; The parse stage ordering — finite chain (Heyting)
type ParseStage := raw | tagged | grouped | rewritten | parsed
  :lattice :pure
  ;; raw < tagged < grouped < rewritten < parsed
  ;; Algebraic: finite chain → distributive, Heyting, NOT Boolean

impl Lattice ParseStage
  join raw x      -> x
  join x raw      -> x
  join parsed _   -> parsed
  join _ parsed   -> parsed
  join x x        -> x
  ;; Different non-extreme stages → take the higher
  bot -> raw
  ;; Meet exists (min of chain)
  meet parsed x   -> x
  meet x parsed   -> x
  meet raw _      -> raw
  meet _ raw      -> raw
  meet x x        -> x

;; Pipeline provenance — chain ordering (Heyting)
;; This is the KEY design choice that avoids the flat-lattice trap.
;; Track 2B's merge-form encoded this implicitly; D.2 makes it structural.
type Provenance := prov-none | prov-preparse | prov-tree-parser
  :lattice :pure
  ;; prov-none < prov-preparse < prov-tree-parser
  ;; Algebraic: 3-element chain → distributive, Heyting

impl Lattice Provenance
  join prov-none x            -> x
  join x prov-none            -> x
  join prov-tree-parser _     -> prov-tree-parser
  join _ prov-tree-parser     -> prov-tree-parser
  join x x                    -> x
  bot -> prov-none

;; The Pocket Universe value for a single source form
;; Product of: chain × option × option × chain × nat × powerset
;; = Heyting × Boolean × Heyting × Heyting × trivial × Boolean = HEYTING
type FormCell := FormCell
  {stage      : ParseStage         ;; chain → Heyting
   tree       : Option ParseTreeNode  ;; 2-valued option → Boolean
   surf       : Option SurfExpr    ;; option, ordered by provenance
   provenance : Provenance         ;; chain → Heyting (IS the surf ordering)
   srcline    : Int                ;; diagnostic, not merged
   regs       : Set Registration}  ;; powerset → Boolean
  :lattice :pure

impl Lattice FormCell
  join [FormCell s1 t1 sf1 p1 l1 r1] [FormCell s2 t2 sf2 p2 l2 r2]
    -> FormCell
         [stage-join s1 s2]           ;; max of chain
         [option-join t1 t2]          ;; prefer non-none
         [prov-select sf1 p1 sf2 p2]  ;; take surf with higher provenance
         [prov-join p1 p2]            ;; max of provenance chain
         [max l1 l2]
         [set-union r1 r2]
  bot -> FormCell raw none none prov-none 0 #{}

;; prov-select: choose the surf-* from the higher-provenance pipeline
;; This IS Track 2B's merge-form logic, now structural
spec prov-select (Option SurfExpr) Provenance (Option SurfExpr) Provenance -> Option SurfExpr
defn prov-select
  | none _ sf2 _  -> sf2
  | sf1 _ none _  -> sf1
  | sf1 p1 sf2 p2 -> (if [prov-ge p1 p2] sf1 sf2)
```

### 5.2 Grammar Production Registry

```prologos
;; A grammar production: keyword → parse function
;; D.2: provenance field for priority ordering within ambiguity sets
type ProductionProvenance := prov-builtin | prov-library | prov-user
  :lattice :pure
  ;; prov-builtin < prov-library < prov-user

type GrammarProduction := GrammarProduction
  {keyword    : Symbol
   provenance : ProductionProvenance  ;; D.2: for priority resolution
   parse-fn   : Fn ParseTreeNode SrcLoc -> SurfExpr
   register-fn : Option (Fn SurfExpr -> Unit)
   sublanguage : Bool}

;; Production registry: Map from keyword to SET of productions (D.2)
;; Values are sets, not singletons — designed for Track 7 ambiguity.
;; For Track 3, each set has exactly 1 element.
;; Algebraic: per-keyword powerset → Boolean. Product of Boolean → Boolean.
type ProductionRegistry := ProductionRegistry {prods : Map Symbol (Set GrammarProduction)}
  :lattice :pure

impl Lattice ProductionRegistry
  ;; Per-keyword set union: accumulate all productions
  join [ProductionRegistry a] [ProductionRegistry b]
    -> ProductionRegistry [map-merge-with set-union a b]
  bot -> ProductionRegistry {}

;; Dispatch selects highest-provenance production from the set (pure function, not lattice op)
;; Track 3: singleton sets → trivial selection
;; Track 7: multi-element sets with same provenance → ATMS ambiguity
spec select-production (Set GrammarProduction) -> GrammarProduction
defn select-production [prods]
  |> prods [max-by GrammarProduction-provenance]
```

### 5.3 Registration as Information Flow

```prologos
;; Registration pass: surf-* → parameter mutations (scaffolding)
;; In NTT, this WOULD be a propagator writing to registration cells.
;; For Track 3, it's a Racket function with side effects.

;; FUTURE (PM series): registration cells on network
;; network elab-net : ElaborationInterface
;;   embed ctor-registry   : Cell (Map Symbol CtorDesc)
;;   embed trait-registry   : Cell (Map Symbol TraitDecl)
;;   embed impl-registry    : Cell (Map (Symbol Symbol) ImplDecl)
;;   embed spec-registry    : Cell (Map Symbol TypeExpr)

;; Track 3 scaffolding: register-from-surfs is an imperative pass
spec register-from-surfs [List SurfExpr] -> Unit
defn register-from-surfs [surfs]
  ;; Phase 1: specs (pre-scan, order-dependent)
  |> surfs [filter surf-spec?] [for-each register-spec-from-surf]
  ;; Phase 2: data/trait/impl/macro (order-independent)
  |> surfs [filter registration-form?] [for-each register-form-from-surf]
```

### 5.4 Production Dispatch

```prologos
;; Dispatch: given a tagged tree node, look up production and fire
spec dispatch-production ProductionRegistry ParseTreeNode SrcLoc -> SurfExpr
defn dispatch-production [registry node loc]
  (match [node-keyword node]
    | some keyword ->
        (match [map-get [ProductionRegistry-prods registry] keyword]
          | some prod -> [GrammarProduction-parse-fn prod node loc]
          | none      -> [parse-expr-tree node loc])  ;; default: expression
    | none -> [parse-expr-tree node loc])
```

### 5.5 Correspondence Table

| NTT Construct | Racket Implementation |
|---------------|----------------------|
| `FormCell` (Pocket Universe) | `form-cell-value` struct + cell on prop-network |
| `ParseStage` lattice | Stage symbols with ordering in merge function |
| `Provenance` lattice (D.2) | Provenance symbols: `'none`, `'preparse`, `'tree-parser` |
| `prov-select` (D.2) | `merge-form` logic from Track 2B, now structural |
| `ProductionRegistry` | Module-level hash of sets (scaffolding) |
| `GrammarProduction` | `grammar-production` struct with `provenance` field (D.2) |
| `ProductionProvenance` (D.2) | Production provenance: `'builtin`, `'library`, `'user` |
| `select-production` (D.2) | Pure function: max-by provenance from set |
| `dispatch-production` | `dispatch-production` function called per form |
| `register-from-surfs` | Racket function with parameter mutations |
| Stage-advancing propagator | surface-rewrite.rkt rewrite rules |
| Per-form cell merge | `prov-select` + component-wise join (promoted from merge-form) |
| SRE decomposition of surf-* | Existing `ctor-desc` pattern |
| SRE domain registration (D.2) | `register-domain!` with declared properties for form-cell + production-registry |

### 5.6 NTT Model Observations

1. **Registration is the scaffolding boundary.** The NTT model clearly shows where Track 3 is on-network (FormCell, ProductionRegistry, dispatch-production) vs. where it's scaffolding (register-from-surfs). PM series replaces the scaffolding with the commented-out `embed` declarations.

2. **The production registry is a data structure, not a propagator.** Productions are registered, not computed. The registry is a lookup table. Dispatch (selection from set) is a pure function. The PARSING is propagator-mediated (production dispatch fires on cell writes). The GRAMMAR is data. This is Decomplection: accumulation (lattice) and selection (function) are separated.

3. **No impurities detected.** Every component is either: (a) a pure lattice value (FormCell, ParseStage, Provenance, ProductionRegistry), (b) a cell read/write (per-form cells, production dispatch), or (c) explicitly scaffolding (register-from-surfs). No disguised imperative patterns.

4. **D.2: Pipeline-preference ordering is structural, not ad-hoc.** The `Provenance` type and `prov-select` function make the ordering explicit in the NTT model. Track 2B's `merge-form` encoded this implicitly via `cond` dispatch. D.2 promotes it to a first-class lattice component. The NTT model reveals this as correct: provenance IS the ordering on surfs, not a metadata annotation.

5. **D.2: Set-valued productions prevent Track 7 lattice redesign.** The `Set GrammarProduction` per keyword means Track 7 adds elements to existing sets — the lattice structure doesn't change. The alternative (singleton per keyword) would require redesigning the registry lattice when ambiguity is introduced, exactly as the type lattice requires redesign for union types. The lesson from Track 2G is applied proactively.

6. **D.2: SRE domain registration validates algebraic properties.** The NTT model includes `register-domain!` calls with explicit property declarations. Track 2G's inference mechanism validates these post-registration. If the FormCell merge function violates the declared properties (e.g., provenance ordering is wrong), inference catches it with a counterexample. This is the safety net the type lattice lacked.

---

## §6 Risks and Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| data/trait/impl tree parsing exposes new bugs | MEDIUM | Three-level WS validation (L1 + L2 + L3). Merge provides fallback during development. |
| Registration ordering dependency (specs before other forms) | HIGH | Two-pass registration: specs first, then data/trait/impl. Explicit ordering in `register-from-surfs`. |
| Generated defs (constructors, accessors) not produced by registration pass | HIGH | Port generation logic from `preparse-expand-all` to `register-from-surfs`. Test with `data` declarations that exercise all generated def patterns. |
| `load-module` path differs from `process-file` path | MEDIUM | Module loading gets same tree-parser + registration-pass treatment. Test with cross-module imports. |
| Per-form cell overhead on large files | LOW | Pocket Universe pattern controls allocation. One cell per form, not per sub-expression. Profile on large library files (72 files in lib/prologos/). |
| sexp path diverges from WS path | LOW | Accepted — sexp path retains `parse-datum`, WS path uses per-form cells. Tests run both paths. |

---

## §7 Dependencies and Cross-Series

### Consumed (prerequisites):
- **PPN Track 2B ✅** — merge infrastructure (merge-form lattice join), tree-parser, surface-rewrite.rkt
- **PPN Track 1 ✅** — 5-cell reader architecture, RRB cells, parse-tree-node
- **PPN Track 0 ✅** — lattice types, bridge specs
- **SRE Track 2G ✅** — domain registry pattern, property cells, property-gated behavior

### Produced (enables):
- **PPN Track 4** — elaboration as attribute evaluation. Track 3 provides per-form cells that Track 4 adds type/constraint cells alongside. The parse/elaborate boundary dissolves because both use the same network.
- **PPN Track 7** — user-defined grammar extensions. Track 3 provides the production registry that Track 7 exposes to users.
- **PPN Track 8** — incremental editing. Track 3's per-form cells are the update units. Edit a form → cell changes → production re-fires → new surf-* emerges.
- **PM Series** — module-load-time on network. Track 3 structures registration as information flow (scaffolding). PM replaces scaffolding with cells.

### Not consumed (explicitly NOT prerequisites):
- **SRE Track 2H** — type lattice redesign. Track 3 does not touch the type domain. 2H is a Track 4 prerequisite.
- **PPN Track 5** — type-directed disambiguation. Track 3 produces unambiguous parses (no parse forests yet). Track 5 adds ambiguity.
