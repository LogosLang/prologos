# PPN Track 3: Parser as Propagators — Stage 3 Design (D.5)

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
| 0 | Pre-0 benchmarks | ✅ | `dc87fb34`. Parse=0-4% of pipeline. WS overhead <2%. All V1-V3 algebraic properties PASS. |
| 1a | Close coverage: data/trait/impl | ⬜ | 3 stubs → full implementations. Parsing only — no registration. |
| 1b | Close coverage: subtype + selection (parseable); deftype/bundle/defmacro/property/functor/schema deferred | ✅ partial | `27d22906`. subtype + selection implemented. 6 preparse-consumed forms (no surf structs) defer to after Phase 6 — same pattern as data/trait/impl. |
| 2 | Close coverage: session/defproc/defr/quote/solver | ⬜ | 5 stubs → full implementations. Complex sublanguages. |
| 3a | Spec cells: propagator-native spec resolution | ✅ | `bd13dfbb`. spec-cell-value struct, merge with collision=top (D.5 F4), extract-specs-from-form-cells. 2 specs from 6-form program. Commutativity verified. Consumption in Phase 7. |
| 3b | Data registration extraction | ⬜ | Extract registration-only logic from process-data (215 lines). Registration as data descriptors. |
| 3c | Trait/impl registration extraction | ⬜ | Extract from process-trait (739 lines) + process-impl (465 lines). |
| 3d | Spec registration extraction | ⬜ | Extract from process-spec (1,548 lines). Depends on tree-parser handling spec type signatures. |
| 3e | Generated def injection | ⬜ | Constructors, accessors, default methods → additional form cells via accumulator cell. |
| 4 | Delete sexp expanders on WS path | ⬜ | ~500-600 lines of macros.rkt expand-* become unreachable. preparse-expand-all eliminated from WS pipeline. |
| 5 | Dependency-set Pocket Universe + production registry | ✅ | `9f3c63dc`. form-pipeline-value.transforms is seteq powerset. Merge = set-union. transform-deps + transform-ready?. advance-pipeline dependency-driven. 31 inline tests pass. |
| 6 | Per-form cells + production dispatch propagators | ✅ | `7a2a4bd0`. form-cells.rkt: create-form-cells-from-tree + dispatch-form-productions. 1 cell per form on elab-network. Merge = Phase 5 set-union. Gate phase for 3a/1a+3b-3e/7. |
| 7 | Shared cells replace merge (pure merge function) | ✅ partial | `40d07caa`. Form cells + spec cells wired into driver alongside merge. extract-surfs-from-form-cells verified identical. Merge still drives process-command — full switch after Phase 4. |
| 8 | Retire parser.rkt (demote to sexp shim) | ⬜ | Incomplete — sexp path retained for tests/REPL. Full retirement when PM brings module loading on-network. Tracked in DEFERRED.md. |
| 9 | Acceptance + A/B benchmarks + verification | ⬜ | Full suite GREEN. A/B vs Track 2B baseline. Acceptance file on all examples. |
| 10 | PIR + documentation | ⬜ | |

**Phase completion protocol**: After each phase: commit → update tracker → update dailies → run targeted tests → proceed.

**Phase dependency DAG** (D.5b — revised from implementation finding: Phase 3a requires cell infrastructure from Phase 6):

```
Group 1 (parallel front):  1a ∥ 1b ∥ 2 ∥ 5
  ↓                           ↓
Group 2:                      6 (needs 5)
                              ↓
Group 3 (parallel middle): 3a ∥ 3b ∥ 3c ∥ 3d ∥ 3e ∥ 7
                           (3a needs 6; 3b-3e need 1-2 + 6; 7 needs 6)
                              ↓
Group 4:                      4 (needs all of 3 — preparse deletion)
                              ↓
Group 5:                      8 → 9 → 10
```

**Implementation order**: 1a → 1b → 2 → 5 → 6 → 3a/3b-3e/7 → 4 → 8 → 9 → 10

**Rationale for reorder** (discovered during Phase 3a mini-audit): Spec cells (Phase 3a) require per-form cell infrastructure (Phase 6) for propagator-native cell residuation. Without cells, Phase 3a would require a two-pass algorithmic approach — the exact pattern the D.4 design eliminated. Build infrastructure first (Phases 5-6), deploy features on it (Phases 3, 7), then clean up (Phase 4, 8).

---

## §1 Objectives

**End state**: `parser.rkt` is deleted. Every source form is a cell on the propagator network. Grammar productions are registered propagators. The `preparse-expand-all + parse-datum + merge` pipeline is replaced by: read source → write to per-form cells → productions fire → surf-* values emerge at fixpoint. SRE decomposes cell values for elaboration.

**What is delivered**:
1. Tree-parser handles ALL 8 currently-stubbed form types (data, trait, impl, session, defproc, defr, quote, solver)
2. Spec resolution via propagator cells — per-function spec cells replace two-pass ordering. Defn propagators read spec cells; ordering emerges from data dependency, not control flow.
3. Registration logic extracted from `process-data/trait/impl/spec/defmacro` (3,017 lines of interleaved parse+register) into registration-only functions that operate on surf-* input. Registration as data descriptors, not imperative side effects.
4. Generated def injection via accumulator cell — constructors, accessors, default methods produced by registration propagators and injected as additional form cells.
5. `preparse-expand-all` eliminated from the WS processing path
6. ~500-600 lines of sexp-specific expanders deleted from macros.rkt
7. Dependency-set Pocket Universe — pipeline stages as a powerset of completed transforms (Boolean lattice), not a chain. Independent transforms fire in parallel. Extensible: new transforms = new set elements.
8. Grammar production registry as a set-valued cell — `Map Symbol (Set GrammarProduction)`, 236 keyword heads bulk-registered, monotonically extensible for Track 7.
9. Per-form cells with production dispatch propagators — dispatch IS a propagator fire body, not a standalone function.
10. Pure merge function — provenance field replaces spec-store parameter dependency. merge-form is a pure function of its arguments.
11. Shared cells replace the source-line-keyed merge — identity is structural (shared cell), not computed (key lookup).
12. `parser.rkt` demoted to sexp compatibility shim — incomplete, tracked in DEFERRED.md. Full retirement when PM brings module loading on-network.

**What this track is NOT**:
- It does NOT put registration on the propagator network as persistent cells — incomplete because module-load-time network doesn't exist yet; PM series scope. Registration writes to per-command cells where possible (process-file path) and to Racket parameters where necessary (load-module path). PM unifies both on persistent cells.
- It does NOT implement semiring-parameterized parsing — incomplete because the semiring abstraction requires the parse forest lattice from PPN Track 5. Boolean (recognition-only) semiring suffices for Track 3.
- It does NOT implement user-defined grammar extensions — incomplete because user-facing `grammar` form requires Track 7 design. Track 3 provides the production registry mechanism that Track 7 exposes.
- It does NOT retire the sexp processing path (`process-string`) — incomplete because sexp mode remains for tests/REPL. Full retirement blocked on PM module-loading-on-network. Tracked in DEFERRED.md.
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

Four lattices, each with explicitly declared algebraic structure (see §3.8 for full analysis):

- **Per-form parse lattice (FormCell)**: A product lattice with deliberate ordering choices. The transforms component (D.4) is a **powerset of completed transforms** (Boolean — the strongest algebraic structure), replacing the D.2 stage chain. Independent transforms fire in parallel; ordering emerges from data dependency, not chain position. The tree-node and surf components use **pipeline-preference ordering** (NOT flat equality) — tree-parser output > preparse output > ⊥. The registrations component is a powerset (Boolean). The FormCell domain MUST be registered via SRE Track 2G's `register-domain!` with explicit algebraic property declarations. See §3.8 for why these ordering choices matter.

- **Grammar production registry**: `Map Symbol (Set GrammarProduction)` — values are SETS of productions per keyword, not singletons. For Track 3, each set has exactly one element. Track 7 adds ambiguity (multiple productions per keyword, ATMS explores alternatives). Powerset per keyword → Boolean.

- **Spec cell lattice** (D.4): Per-function cells holding spec annotations. ⊥ (no spec) → `spec-entry` (type signature + metadata). Set-once. Defn production propagators read spec cells — if ⊥, the defn residuates until the spec is written. This eliminates the two-pass ordering in `preparse-expand-all`. Ordering emerges from cell dependency, not control flow. Flat per-function → same structure as the type lattice under equality, but collision = ⊤ (error) is correct semantics (redefining a spec is an error).

- **Registration lattice**: ⊥ (nothing registered) → set of known names with their properties. Monotone — registrations are only added. For Track 3: per-command cells where possible (process-file path), Racket parameters where necessary (load-module path). PM unifies both on persistent cells.

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
  transforms    ;; set of symbols: completed transforms (powerset lattice)
  tree-node     ;; parse-tree-node at current refinement (or #f if parsed)
  surf          ;; surf-* struct (or #f if not yet parsed)
  provenance    ;; symbol: 'none | 'preparse | 'tree-parser — pipeline-preference ordering
  source-line   ;; integer — preserved for diagnostics
  registrations ;; set of registration descriptors (data, not side effects)
)
```

**Ordering (component-wise, all monotone)**:
- `transforms` (D.4): **Powerset** — set of completed transform names. Join is set union. ⊥ = ∅, ⊤ = {all transforms}. **Boolean** (strongest algebraic structure). Replaces the D.2 stage chain. Each transform is an element: `'tagged`, `'grouped`, `'pipe-rewritten`, `'compose-rewritten`, `'mixfix-resolved`, `'let-expanded`, `'parsed`, etc. A propagator declares its dependencies as a required subset; it fires when that subset ⊆ `transforms`.
- `tree-node`: Option with pipeline-preference — `#f < any-node`. At most one node (tree parser overwrites).
- `surf`: Option with pipeline-preference — `#f < preparse-surf < tree-parser-surf`. The provenance field tracks source for the ordering.
- `provenance`: Chain — `none < preparse < tree-parser`. This is the **pipeline-preference ordering** that makes the surf component a chain (Heyting) rather than flat (non-distributive). Track 2B's `merge-form` already encodes this ordering — D.2 makes it explicit and structural.
- `registrations`: Set (powerset) — join is union. Boolean.

The product of these components is **Boolean** (product of powersets and chains, all Boolean or Heyting). See §3.8 for the algebraic property verification.

**Transforms as dependency-set** (D.4 — replaces D.2 stage chain):

Each transform is a named operation with declared dependencies:

| Transform | Dependencies | What it does | Propagator |
|-----------|-------------|-------------|-----------|
| `tagged` | ∅ | T(0) tag refinement — keyword identification | surface-rewrite.rkt tag rules |
| `grouped` | ∅ | G(0) form grouping — sub-expression boundaries | surface-rewrite.rkt group rules |
| `pipe-rewritten` | `{tagged, grouped}` | `\|>` expansion at tree level | surface-rewrite.rkt pipe rule |
| `compose-rewritten` | `{tagged, grouped}` | `>>` expansion at tree level | surface-rewrite.rkt compose rule |
| `mixfix-resolved` | `{tagged, grouped}` | `.{...}` Pocket Universe resolution | surface-rewrite.rkt mixfix |
| `parsed` | `{tagged, grouped}` | Final surf-* struct produced | Grammar production for this form type |

**D.5 simplification (from external critique F5)**: Sub-expression transforms (`let-expanded`, `cond-expanded`, etc.) are NOT separate dependency-set entries. They are handled INTERNALLY by each production's parse function during recursive descent — `parse-defn-tree` calls `parse-expr-tree` which handles let/cond/if inline. Only tree-level transforms (those that rewrite top-level form nodes before production dispatch) are separate entries: `tagged`, `grouped`, `pipe-rewritten`, `compose-rewritten`, `mixfix-resolved`. Sub-expression transforms are part of the `parsed` transform.

**Critical pairs analysis** (DPO theory, D.3 finding, extended D.5):

| Transform A | Transform B | Critical Pair? | Rationale |
|-------------|-------------|----------------|-----------|
| `tagged` | `grouped` | NO | Touch different attributes (keyword vs children). **Parallel.** |
| `pipe-rewritten` | `compose-rewritten` | NO | Different token patterns (`\|>` vs `>>`). **Parallel.** |
| `pipe-rewritten` | `mixfix-resolved` | NO | Different contexts (bare `\|>` vs `.{...}` blocks). **Parallel.** |
| Any rewrite | `tagged`/`grouped` | YES | Rewrites read tag and group structure. **Stratification: tag+group before rewrites.** |
| `parsed` (spec) | trait registration | YES (D.5) | Spec production reads trait registry to recognize constraints. **Spec residuates until trait registered.** |
| `parsed` (impl) | trait registration | YES (D.5) | Impl production reads trait registry for validation. **Impl residuates until trait registered.** |
| `parsed` (defn) | spec cell | YES | Defn production reads spec cell for annotation. **Defn residuates until spec written (or quiescence).** |

**D.5 addition — four-pass dependencies from `preparse-expand-all`**: The current `preparse-expand-all` (macros.rkt:2366) has FOUR passes, not two:

| Pass | What | Propagator model |
|------|------|-----------------|
| Pass -1 | `ns`/`imports` → prelude loading | **Existing stratum boundary.** `process-file` processes ns first. No change needed. |
| Pass 0 | `data`/`trait`/`deftype`/`defmacro`/`bundle`/etc. pre-registration | **Cell dependency.** Each registration writes to a registration cell. Dependents residuate. |
| Pass 1 | `spec`/`impl` pre-registration (depends on trait registry) | **Cell dependency.** Spec/impl productions read trait registration cell; residuate if ⊥; re-fire when trait registered. |
| Pass 2 | Full expansion with generated defs | **Production dispatch + generated-def propagator.** |

All four passes are replaced by cell-mediated dependency. No explicit Pass ordering in control flow. ns is an existing stratum boundary. Data/trait→spec/impl is a critical pair resolved by residuation.

**Why dependency-set, not chain** (D.4):
1. **Parallelism**: T(0) and G(0) fire concurrently. All rewrite rules for a form fire concurrently (no critical pairs between different keyword-dispatched rules). The chain serialized ALL of these.
2. **Extensibility**: Adding a new rewrite rule = adding a new transform name + declaring its dependencies. No chain modification. Track 7 user-defined grammar extensions add transforms without changing the existing set.
3. **Algebraic strength**: Powerset is Boolean (strongest). Chain was only Heyting. Boolean gives complement (useful for "what transforms have NOT fired" diagnostics).
4. **Correctness**: Critical pair analysis guarantees that independent transforms commute. The dependency declarations capture EXACTLY the ordering constraints that exist. No over-constraining.

**Why Pocket Universe, not N separate cells per form**: Cell allocation cost. A program with 100 forms would need 100 × M cells (M = number of transforms) if each transform were a separate cell. One Pocket Universe per form = 100 cells, with internal dependency-set advancement.

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

### 3.4 Registration as Information Flow (D.4 — Propagator-Native)

Registration (data constructors, traits, impls, specs, macros) currently happens as interleaved parse+register side effects in `preparse-expand-all`. The D.3 self-critique found this is 3,017 lines of code across 5 functions, not simple wrappers. D.4 restructures registration as propagator-native information flow.

**Current flow** (algorithmic, interleaved):
```
preparse-expand-all:
  Pass 1: scan ALL specs → write spec-store (ordering dependency!)
  Pass 2: for each form → PARSE + REGISTER (interleaved) → output expanded sexp
parse-datum: read expanded sexp → output surf-*
```

**Track 3 flow** (propagator-native, D.4):
```
tree-parser: read tree → output surf-* (pure)
spec cells: each spec form writes to per-function spec cell (propagator)
registration propagators: each data/trait/impl form's propagator extracts
  registration descriptors from its surf-* struct and writes to registration cells
generated-def propagator: registration descriptors → additional form cells
elaboration: reads form cells + registration cells (cell dependency, not ordering)
```

**Key D.4 changes from D.2:**

1. **Spec cells replace two-pass ordering.** Each function name has a spec cell. When a `spec` form is processed, its production propagator writes the type annotation + metadata to the spec cell. When a `defn` form's production fires, it reads the spec cell for its name. If ⊥ (spec not yet processed), the defn residuates. When the spec cell is written, the defn propagator re-fires. No Pass 1/Pass 2. Ordering emerges from cell dependency.

2. **Registration as data descriptors, not side effects.** The registration logic extracted from `process-data/trait/impl/spec` produces DESCRIPTORS — data values describing what to register (constructor names, method signatures, impl targets) — rather than directly mutating parameters. These descriptors are written to the form's `registrations` set in the Pocket Universe. A downstream registration propagator reads descriptors and performs the actual registration.

3. **Generated defs via accumulator cell.** When `data Color := Red | Green | Blue` is processed, the registration propagator produces descriptors for constructors (`Red`, `Green`, `Blue`), type-check function (`Color?`), and accessors. A generated-def propagator reads these descriptors and creates ADDITIONAL per-form cells for the generated definitions. These cells go through the same production dispatch as user-written forms.

4. **Trait→spec dependency via cell residuation (D.5).** Spec production propagators call `lookup-trait` to recognize constraint forms. In the current code, this is resolved by Pass 0 (data/trait) completing before Pass 1 (spec/impl). In the propagator model: spec propagators read from trait registration cells. If the trait isn't registered yet, the spec residuates. When the trait registration cell advances, the spec propagator re-fires. Same pattern as spec→defn. No barrier cell needed — just cell dependency.

5. **Two registration paths with dual-mode interface (D.5, scaffolding boundary).** Registration descriptor extraction functions must be callable in BOTH execution contexts (Two-Context Audit from pipeline.md):

   - **process-file / process-string-ws** (network active): descriptors → write to per-command registration cells → elaboration reads cells.
   - **load-module** (no network): descriptors → write to Racket parameters directly (scaffolding, persists across commands). Generated defs must also be handled (currently `process-data` returns generated def sexps that `preparse-expand-all` accumulates).

   The interface: each `extract-*-registrations` function returns `(list-of reg-descriptor)`. A `commit-registrations!` function takes descriptors and writes them to either cells (process-file context) or parameters (load-module context) based on which context is active. PM unifies both on persistent cells.

**Why this is progress over D.2**: D.2 proposed `register-from-surfs` as an imperative loop. D.4/D.5 replaces this with propagators for the process-file path, with an explicit dual-mode interface for load-module. The only imperative remnant is the `load-module` parameter write (scaffolding for PM).

**Registration function extraction scope** (D.3 finding R1):

| Function | Lines | Extraction approach |
|----------|-------|-------------------|
| `process-data` | 215 | surf-data already contains all info. Extract: ctor names, accessor patterns, type def. |
| `process-trait` | 739 | surf-trait contains method signatures. Extract: trait declaration, method types, defaults. |
| `process-impl` | 465 | surf-impl contains method bodies. Extract: impl entry, method implementations. |
| `process-spec` | 1,548 | Most is type-signature PARSING (tree-parser handles in Phases 1-2). Extract: spec-store write, mixfix metadata, generated defs. |
| `process-defmacro` | ~50 | surf-defmacro contains pattern+template. Extract: macro rule registration. |

The extraction does NOT port 3,017 lines. It extracts the REGISTRATION-ONLY portions from functions whose PARSING portions are replaced by the tree-parser. For `process-spec`, the 1,548 lines are mostly parsing — the registration portion is the spec-store write + mixfix metadata + a few generated defs.

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
| `transforms` (D.4) | Powerset of transform names | Set union | Powerset → **Boolean** | Independent transforms fire in parallel. Critical pair analysis: no ordering between independent rules. |
| `tree-node` | {#f} ∪ ParseTreeNode | Option: #f < any-node (at most one) | 2-element chain → **Boolean** | Tree parser writes once. No merge between different trees needed. |
| `surf` | {#f} ∪ SurfExpr | Pipeline-preference: #f < preparse-output < tree-parser-output | 3-element chain → **Heyting** | Track 2B's merge-form already encodes this. D.2 makes it explicit via `provenance` field. |
| `provenance` | 3 symbols | Chain: none < preparse < tree-parser | Finite chain → **Heyting** | Tracks which pipeline produced the surf. IS the surf ordering. |
| `source-line` | Nat | Max (information-preserving) | Trivial (single value per form) | Diagnostic only. Not merged. |
| `registrations` (D.4) | Set of registration descriptors | Set union (powerset) | Powerset → **Boolean** | Registration as data, not side effects. Accumulation. Monotone. |

**Product lattice**: Boolean × Boolean × Heyting × Heyting × Trivial × Boolean = **Heyting** (product of Heyting algebras is Heyting; D.5 correction from F9). The `transforms` component is individually Boolean (supports complement for "which transforms have NOT fired" diagnostics). The overall product is Heyting due to the 3-element provenance chain (Heyting, not Boolean — complement of `prov-preparse` doesn't exist in a 3-element chain). This is sufficient for SRE (pseudo-complement exists).

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
| FormCell (D.5) | **Heyting** | `transforms` is Boolean individually (complement for diagnostics). Product is Heyting due to 3-element provenance chain. Sufficient for SRE. Surf → powerset in Track 5. No redesign. |
| SpecCell (D.5) | Flat (set-once, collision = ⊤) | D.5 fix: collision produces top (error), restoring commutativity. |
| ProductionRegistry | Boolean | Set-valued per keyword. Track 7 adds elements to sets. No redesign. |
| Registration descriptors (D.4) | Boolean (powerset) | Descriptors accumulate as sets. No flat-value issue. |
| Registration effect (scaffolding) | Mixed | Parameter writes for load-module. PM replaces with persistent cells. |

The type lattice required redesign because it committed to flat equality as the ordering, then discovered that downstream consumers (Heyting error reporting) needed a richer ordering. Track 3 avoids this by:
1. **Choosing dependency-set (powerset)** for transforms — Boolean, the strongest algebraic structure (D.4, upgraded from D.2 chain)
2. **Choosing pipeline-preference ordering** for surf component — chain, not flat
3. **Using set-valued collections** for components that could later have multiple values (production sets, registration descriptors)
4. **Registering domains with SRE 2G** so property inference validates the algebraic structure
5. **Separating registration data from registration effects** — descriptors (Boolean powerset) vs parameter writes (scaffolding). PM only needs to change the effect mechanism, not the data structure.
6. **Spec cells with cell-mediated dependency** — eliminates algorithmic ordering that would have been another redesign target when Track 4 needs propagator-native spec resolution

---

## §4 Phase Details (D.4 — revised from D.3 self-critique)

### Phase 0: Pre-0 Benchmarks ✅

See §8 for full data. Key findings: parse = 0-4% of pipeline, WS overhead <2%, all algebraic properties PASS, set-valued registry zero overhead. No design changes.

### Phase 1: Close Coverage Gap — data/trait/impl + registration forms

**What**: Implement tree-parser functions for the most important stubs. These are forms with registration side effects AND forms consumed by preparse Pass 0.

**Phase 1a — Core registration forms**:
- **data**: Tree → `surf-data` struct. Type parameters, constructor declarations, deriving clauses. **Parsing only** — no registration (Phase 3 handles).
- **trait**: Tree → `surf-trait` struct. Trait name, type parameters, method signatures, supertraits.
- **impl**: Tree → `surf-impl` struct. Trait name, implementing type, method bodies.

**Phase 1b — Additional preparse-consumed forms (D.5, F7)**:

tree-parser.rkt has error stubs for 6 additional forms that `preparse-expand-all` consumes in Pass 0. These MUST be handled before Phase 4 can delete preparse on the WS path:

- **deftype**: Type alias declaration. Tree → `surf-deftype`. Simple.
- **subtype**: Subtype relation declaration. Tree → `surf-subtype`. Simple. (Currently NOT in tree-parser at all — must be added.)
- **bundle**: Trait bundle constraint. Tree → `surf-bundle`. Moderate.
- **defmacro**: Macro definition. Tree → `surf-defmacro`. Moderate.
- **property**: Property declaration. Tree → `surf-property`. Simple.
- **schema/selection/functor**: Configuration forms. Tree → respective surf-* structs. Simple-moderate.

**Validation**: Three-level WS validation (L1 + L2 + L3). The merge routes these forms through tree parser instead of falling back to preparse.

**Key risk**: surf-* structs must contain ALL information that registration needs. If the struct is missing information that `process-data/trait/impl` extracts from the raw datum, registration propagators (Phase 3b-3c) can't extract it.

### Phase 2: Close Coverage Gap — session/defproc/defr/quote/solver

**What**: Implement the remaining 5 stubs. Less frequently used but have complex sublanguages.

- **quote/solver**: Simple (10-20 lines each). Do first.
- **session/defproc**: Session type sublanguage (Send/Recv/Choice/Offer). Complex.
- **defr**: Relational sublanguage (`?`-prefixed variables, `&>` clauses). Complex.

### Phase 3a: Spec Cells — Propagator-Native Spec Resolution

**What**: Create per-function spec cells that replace the two-pass spec ordering.

**Mechanism**: For each function name that has a `spec` declaration, create a spec cell on the per-command network. The spec form's production propagator writes `(spec-entry type-expr metadata)` to the cell. The defn form's production propagator reads the spec cell for its name. If ⊥ (no spec yet), the defn residuates. When the spec cell is written, the defn propagator re-fires with the type annotation.

```racket
;; Spec cell: per-function, set-once
;; ⊥ = (spec-cell-value #f #f)
;; Written by spec production: (spec-cell-value type-expr metadata)
(struct spec-cell-value (type-expr metadata) #:transparent)

(define (spec-cell-merge old new)
  (cond
    [(not (spec-cell-value-type-expr old)) new]  ;; ⊥ ⊔ x = x
    [(not (spec-cell-value-type-expr new)) old]  ;; x ⊔ ⊥ = x
    [else old]))  ;; set-once: first write wins
```

**Key insight**: This eliminates the spec pre-scan Pass 1 from `preparse-expand-all`. The ordering "specs before defns" is not encoded in control flow — it emerges from cell dependency. If a program has `defn f` before `spec f`, the defn's propagator fires first (produces surf-defn without annotation), then when the spec is processed and the spec cell is written, the defn's propagator RE-FIRES (produces surf-defn WITH annotation). Monotone refinement, not sequential ordering.

**Impact**: Removes the single largest algorithmic workaround from the design.

### Phase 3b: Data Registration Extraction

**What**: Extract registration-only logic from `process-data` (215 lines in macros.rkt).

The surf-data struct produced by Phase 1's `parse-data-tree` contains: type name, type parameters, constructor declarations, deriving clauses. The registration extraction reads this struct and produces DESCRIPTORS:

```racket
;; Registration descriptors — data, not side effects
(struct reg-constructor (type-name ctor-name arity field-types) #:transparent)
(struct reg-type-def (name params constructors) #:transparent)
(struct reg-accessor (type-name ctor-name field-index field-name) #:transparent)
```

A registration propagator reads the form cell (when it reaches `{parsed}` in the transforms set), extracts descriptors from the surf-data, and writes them to the form's `registrations` set in the Pocket Universe.

A downstream registration-effect propagator reads the descriptors and performs the actual parameter writes (scaffolding) or cell writes (future PM).

### Phase 3c: Trait/Impl Registration Extraction

**What**: Same pattern for `process-trait` (739 lines) and `process-impl` (465 lines).

- **Trait**: Extract trait name, method signatures, default methods, supertraits → `reg-trait-decl`, `reg-method-sig` descriptors.
- **Impl**: Extract trait name, implementing type, method bodies, validation → `reg-impl-entry`, `reg-method-impl` descriptors.

These are larger than data registration because traits have method signatures and defaults, impls have validation logic. The extraction separates: parsing (tree-parser handles) from registration data (descriptors) from registration effect (parameter/cell writes).

### Phase 3d: Spec Registration Extraction

**What**: Extract registration-only logic from `process-spec` (1,548 lines in macros.rkt).

**D.3 finding**: Most of `process-spec` is type-signature PARSING. The tree-parser (Phases 1-2) handles this parsing. The registration-only portion is:
- Write to spec-store: `(hash-set (current-spec-store) name spec-entry)` — becomes the spec cell write from Phase 3a
- Mixfix metadata: if spec has `:mixfix`, register as user operator — extract as `reg-mixfix-operator` descriptor
- Generated defs: spec sometimes generates dict-param defs — extract as generated def descriptors

The 1,548 lines shrink to ~100-200 lines of registration extraction once parsing is handled by tree-parser.

### Phase 3e: Generated Def Injection

**What**: Data/trait/impl processing generates new definitions (constructors, accessors, type-check predicates, default methods). These must become additional per-form cells.

**Mechanism**: A generated-def propagator reads the `registrations` set from each form's Pocket Universe. For each `reg-constructor`, `reg-accessor`, etc., it creates a NEW per-form cell containing the generated surf-* struct.

```
data Color := Red | Green | Blue
  → form cell for Color (surf-data)
  → registration descriptors: [reg-constructor Color Red 0 (), reg-constructor Color Green 0 (), ...]
  → generated-def propagator creates form cells for: Red, Green, Blue, Color? (surf-def each)
  → these generated form cells go through the same production dispatch as user forms
```

**Key design point**: Generated defs are ADDITIONAL form cells, not modifications to the original form cell. The original `data Color` form cell holds the surf-data. The generated `Red`, `Green`, `Blue` form cells hold surf-defs. Both types of cells are consumed by elaboration via `process-command`.

**Stratum boundary and termination argument (D.5, F6)**:

Generated-def creation is SCATTER (topology creation — new cells). This requires an explicit stratum boundary:

- **S0**: Parse all user-written forms to completion (tagged + grouped + rewritten + parsed). Extract registration descriptors. Write to registration cells.
- **S1**: Generated-def propagator reads registration descriptors. Creates new per-form cells for constructors, accessors, type-check predicates, default methods. These cells go through production dispatch (tagged + grouped + parsed).
- **S1 does NOT produce further S1 work**: Generated defs are `surf-def` (simple value definitions) and `surf-defn` (simple function definitions). They do not declare new data types, traits, or impls. **Depth is bounded at 1.** No cascading generation.
- The wiring-state cell pattern (from Track 2G property cell auto-creation) controls propagator installation on newly created cells: the generated-def propagator writes new cell IDs to a wiring-state cell, and a downstream propagator installs dispatch propagators on those cells.

**Quiescence accounting**: The network cannot declare quiescence while the generated-def propagator is creating new cells. The wiring-state cell serves as the quiescence barrier — quiescence requires the wiring-state cell to be stable (no new cell IDs being added).

### Phase 4: Delete Sexp Expanders on WS Path

**What**: With Phases 1-3e complete, `preparse-expand-all` is no longer needed on the WS path.

**WS pipeline becomes**:
```
read-all-syntax-ws → tree-parser → surface-rewrite → per-form cells
  → spec cells written → production dispatch propagators fire
  → registration propagators fire → generated-def propagators fire
  → process-command reads completed form cells
```

**Deletable expanders** (~500-600 lines): `expand-if`, `expand-cond`, `expand-let`, `expand-let-bracket-bindings`, `expand-let-inline-assign`, `expand-do`, `expand-list-literal`, `expand-lseq-literal`, `expand-pipe-block`, `expand-compose-sexp`, `expand-mixfix-form`, `expand-quote`, `expand-quasiquote`, `expand-with-transient`, `expand-def-assign`.

**NOT deletable** (shared post-parse expanders, used by elaborator): `expand-top-level`, `expand-expression`, `expand-bundle-constraints`, `expand-defn-multi`.

### Phase 5: Dependency-Set Pocket Universe + Production Registry

**What**: Replace the existing `form-pipeline-value` stage chain (surface-rewrite.rkt) with the dependency-set Pocket Universe. Create the production registry as a set-valued cell.

**Dependency-set implementation**: The `form-cell-value` struct uses a `transforms` field (set of symbols). Each production/rewrite rule declares its dependencies (required subset). The merge function is set union. A propagator fires when its required subset ⊆ the form's `transforms` set.

**Production registry**: `Map Symbol (Set GrammarProduction)`. 236 builtin productions bulk-registered at startup. Set-valued for Track 7 extensibility. Module-level hash (scaffolding).

### Phase 6: Per-Form Cells + Production Dispatch Propagators

**What**: Replace `(map parse-datum expanded-stxs)` with per-form cell creation and propagator-based dispatch.

For each top-level form:
1. Create a per-form cell (Pocket Universe with `transforms = ∅`)
2. Tree-builder writes the parse-tree-node to the cell
3. T(0) and G(0) propagators fire IN PARALLEL (no critical pair) — add `'tagged` and `'grouped` to transforms
4. Rewrite propagators fire when `{tagged, grouped} ⊆ transforms` — add their respective transform names
5. Production dispatch propagator fires when all form-specific dependencies are met — writes final surf-* to the cell
6. Registration propagator fires when surf-* is present — extracts descriptors, writes to registrations
7. Generated-def propagator fires when registrations are present — creates additional form cells

**Dispatch IS a propagator**: The dispatch function is the fire body of a propagator installed on each form cell. It reads the form's keyword from the tree-node, looks up the production in the registry, and fires the production's parse function. This is NOT a standalone function call — it's a propagator that fires when the form cell reaches the appropriate transform state.

### Phase 7: Pure Merge Function + Shared Cells

**What**: Rewrite `merge-form` as a pure function (no spec-store parameter dependency). Delete the merge infrastructure.

**D.3 finding P5**: Current `merge-form` reads `(current-spec-store)` to decide if a form is spec-annotated. The D.2/D.4 `provenance` field replaces this: spec-annotated forms have `provenance = prov-preparse` set by the preparse pipeline. The merge function reads only the provenance field — pure function of its arguments.

**Delete**: `merge-preparse-and-tree-parser`, `merge-form`, source-line-keyed identity matching, `tree-by-line` hash building. Total ~80 lines from driver.rkt.

### Phase 8: Retire parser.rkt (Demote — Incomplete)

**What**: Remove `parse-datum` from WS and file-processing paths. parser.rkt retained as sexp compatibility shim.

**Call sites rewired**: `process-string-ws-inner`, `process-file-inner` (WS path), `load-module`, `parse-type-annotation-string`.

**Call sites retained**: `process-string-inner` (sexp path for tests/REPL).

**Honest label**: This is INCOMPLETE. parser.rkt (6,605 lines) remains reachable from the sexp path. Full retirement blocked on PM bringing module loading on-network + test migration to WS. Tracked in DEFERRED.md.

### Phase 9: Acceptance + A/B Benchmarks + Verification

1. **Acceptance file**: `process-file` on ALL example `.prologos` files. Zero errors.
2. **Full test suite**: 383+ files, 7491+ tests, all pass.
3. **A/B benchmark**: `bench-ab.rkt --runs 15 benchmarks/comparative/` vs Track 2B baseline.
4. **Suite wall time**: Should be ≤ baseline.
5. **Algebraic validation**: Re-run V1-V3 on the new dependency-set FormCell. Confirm Boolean properties.

### Phase 10: PIR + Documentation

Standard PIR per methodology. Update PPN Master, dailies, MASTER_ROADMAP.org.

---

## §5 NTT Speculative Syntax Model

Expressing the Track 3 architecture in NTT speculative syntax. This exercises the NTT syntax and validates that every component is "on network."

### 5.1 Per-Form Parse Lattice (Pocket Universe) — D.4

```prologos
;; D.4: Dependency-set replaces stage chain
;; Transforms as powerset (Boolean — strongest algebraic structure)
;; Each transform is a named operation. Propagators declare required subsets.
type TransformSet := TransformSet (Set Symbol)
  :lattice :pure
  ;; Algebraic: powerset → Boolean (complement, distributive, Heyting)

impl Lattice TransformSet
  join [TransformSet a] [TransformSet b] -> TransformSet [set-union a b]
  meet [TransformSet a] [TransformSet b] -> TransformSet [set-intersect a b]
  complement [TransformSet a] -> TransformSet [set-diff all-transforms a]
  bot -> TransformSet #{}
  top -> TransformSet all-transforms

;; Pipeline provenance — chain ordering (Heyting)
type Provenance := prov-none | prov-preparse | prov-tree-parser
  :lattice :pure

impl Lattice Provenance
  join prov-none x            -> x
  join x prov-none            -> x
  join prov-tree-parser _     -> prov-tree-parser
  join _ prov-tree-parser     -> prov-tree-parser
  join x x                    -> x
  bot -> prov-none

;; The Pocket Universe value for a single source form
;; Product of: powerset × option × option × chain × nat × powerset
;; = Boolean × Boolean × Heyting × Heyting × trivial × Boolean = BOOLEAN
type FormCell := FormCell
  {transforms  : TransformSet       ;; D.4: powerset → Boolean
   tree        : Option ParseTreeNode
   surf        : Option SurfExpr
   provenance  : Provenance
   srcline     : Int
   regs        : Set RegDescriptor}  ;; D.4: registration descriptors, not side effects
  :lattice :pure

impl Lattice FormCell
  join [FormCell t1 tr1 sf1 p1 l1 r1] [FormCell t2 tr2 sf2 p2 l2 r2]
    -> FormCell
         [transform-join t1 t2]       ;; set union
         [option-join tr1 tr2]        ;; prefer non-none
         [prov-select sf1 p1 sf2 p2]  ;; take surf with higher provenance
         [prov-join p1 p2]
         [max l1 l2]
         [set-union r1 r2]            ;; registration descriptors accumulate
  bot -> FormCell (TransformSet #{}) none none prov-none 0 #{}
```

### 5.1b Spec Cells — D.4

```prologos
;; D.4: Per-function spec cell — eliminates two-pass ordering
;; Ordering emerges from cell dependency, not control flow
type SpecCell := SpecCell
  {type-expr : Option TypeExpr
   metadata  : Option SpecMetadata}
  :lattice :pure

impl Lattice SpecCell
  join [SpecCell none _] [SpecCell t m]  -> SpecCell t m    ;; ⊥ ⊔ x = x
  join [SpecCell t m] [SpecCell none _]  -> SpecCell t m    ;; x ⊔ ⊥ = x
  join [SpecCell t1 m1] [SpecCell t2 m2]
    | [eq? t1 t2] -> SpecCell t1 m1                        ;; same spec = idempotent
    | else        -> spec-cell-top                          ;; D.5 fix: collision = ⊤ (error)
  bot -> SpecCell none none
  ;; D.5 (F4): "first write wins" violated commutativity.
  ;; collision = ⊤ restores: join(a,b) = join(b,a) = ⊤ when a ≠ b.
  ;; Elaborator detects ⊤ and reports "duplicate spec for function X."

;; Spec cell lives on the per-command network, keyed by function name
;; network parse-net : ParseInterface
;;   embed spec-cells : Cell (Map Symbol SpecCell)

;; Production propagator for spec forms:
;;   reads: form cell (when 'parsed ∈ transforms)
;;   writes: spec-cells[name] := SpecCell type-expr metadata

;; Production propagator for defn forms:
;;   reads: form cell (when 'parsed ∈ transforms) AND spec-cells[name]
;;   if spec-cells[name] = ⊥: residuate (wait for spec)
;;   if spec-cells[name] = SpecCell type meta: annotate surf-defn with type
;;   at quiescence: any defn still waiting → spec-less (correct, no annotation)
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

### 5.3 Registration as Propagators (D.5 — replaces D.2 imperative model)

```prologos
;; D.5: Registration is propagator-native on the process-file path.
;; Each registration form's propagator extracts descriptors and writes to cells.
;; No imperative loop. No ordering in control flow. Cell dependency determines order.

;; Registration descriptor types — data, not side effects
type RegDescriptor
  := RegConstructor {type-name : Symbol, ctor-name : Symbol, arity : Int, fields : List TypeExpr}
   | RegTypeDef {name : Symbol, params : List Symbol, ctors : List Symbol}
   | RegAccessor {type-name : Symbol, ctor-name : Symbol, field-idx : Int}
   | RegTraitDecl {name : Symbol, params : List Symbol, methods : List MethodSig}
   | RegImplEntry {trait : Symbol, type : Symbol, methods : List MethodImpl}
   | RegSpecEntry {name : Symbol, type-expr : TypeExpr, metadata : Option SpecMetadata}
   | RegMacroRule {name : Symbol, pattern : SurfExpr, template : SurfExpr}

;; Per-form registration propagator:
;; reads: form cell (when 'parsed ∈ transforms)
;; writes: form cell registrations set (set-union with extracted descriptors)
propagator extract-registrations
  :reads  [form-cell :when (set-member? (FormCell-transforms form-cell) 'parsed)]
  :writes [form-cell.registrations]
  :fire
    (match (FormCell-surf form-cell)
      | some (surf-data name params ctors _) ->
          [extract-data-registrations name params ctors]
      | some (surf-trait name params methods _) ->
          [extract-trait-registrations name params methods]
      | some (surf-impl trait-name type-name methods _) ->
          [extract-impl-registrations trait-name type-name methods]
      | _ -> #{})  ;; no registrations for non-registration forms

;; Dual-mode commit (D.5 F8 — Two-Context Audit):
;; process-file path: write descriptors to registration cells
;; load-module path: write descriptors to parameters (scaffolding)
spec commit-registrations (List RegDescriptor) -> Unit
defn commit-registrations [descs]
  (if [network-active?]
    [for-each write-to-registration-cell descs]    ;; process-file path
    [for-each write-to-parameter descs])            ;; load-module path (scaffolding)

;; Trait → spec dependency (D.5 F2):
;; Spec production reads trait registration cell. Residuates if trait not yet registered.
;; When trait cell advances, spec propagator re-fires and resolves constraint forms.
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

### 5.5 Correspondence Table (D.4)

| NTT Construct | Racket Implementation |
|---------------|----------------------|
| `FormCell` (Pocket Universe) | `form-cell-value` struct + cell on prop-network |
| `TransformSet` (D.4) | Set of symbols: completed transform names. Powerset lattice. |
| `Provenance` (D.2) | Provenance symbols: `'none`, `'preparse`, `'tree-parser` |
| `prov-select` (D.2) | Pure merge-form logic, no parameter dependencies |
| `SpecCell` (D.4) | Per-function cell. Set-once. Defn propagators read; residuate if ⊥. |
| `RegDescriptor` (D.4) | `reg-constructor`, `reg-trait-decl`, `reg-impl-entry`, etc. — data, not effects |
| `ProductionRegistry` | Module-level hash of sets (scaffolding) |
| `GrammarProduction` | `grammar-production` struct with `provenance` field (D.2) |
| `select-production` (D.2) | Pure function: max-by provenance from set |
| Dispatch propagator (D.4) | Propagator installed per form cell. Fires when dependencies ⊆ transforms. |
| Registration propagator (D.4) | Reads parsed surf-*. Extracts descriptors. Writes to registrations set. |
| Generated-def propagator (D.4) | Reads registration descriptors. Creates additional form cells. |
| Transform-advancing propagator | surface-rewrite.rkt rewrite rules. Adds transform name to set. |
| Per-form cell merge | `prov-select` + set-union transforms + set-union registrations (pure) |
| SRE decomposition of surf-* | Existing `ctor-desc` pattern |
| SRE domain registration (D.2) | `register-domain!` with declared properties for form-cell + production-registry |

### 5.6 NTT Model Observations (D.4)

1. **Registration is propagator-native on the process-file path.** D.4 replaces the D.2 imperative `register-from-surfs` with registration propagators that extract descriptors and write to cells. The only scaffolding remnant is the `load-module` parameter write path. The NTT model shows this clearly: `RegDescriptor` is data, not effects.

2. **Spec cells eliminate the last algorithmic ordering.** D.4's `SpecCell` replaces the D.2 two-pass spec ordering. The NTT model shows the propagator pattern: spec production writes to spec cell, defn production reads spec cell, residuates if ⊥. No control-flow ordering. This is the most significant D.4 improvement over D.2.

3. **Dependency-set is algebraically stronger than chain.** D.4's `TransformSet` (powerset, Boolean) replaces D.2's `ParseStage` (chain, Heyting). The NTT model includes `complement` — useful for "which transforms have NOT completed" diagnostics (Track 6 error recovery). The chain couldn't express this.

4. **Critical pair analysis is the correctness argument for parallelism.** The NTT model's transform declarations with dependencies make the DPO critical pair analysis explicit: transforms with non-overlapping patterns have no critical pairs → can fire in parallel. This is the hypergraph rewriting correctness guarantee applied to our pipeline.

5. **Generated-def propagator is the novel pattern.** A propagator that reads registration descriptors and CREATES NEW CELLS. This is scatter (topology creation) — the same pattern as Track 2G's property cell auto-creation. The wiring-state cell pattern handles this at a stratum boundary.

6. **D.2 observations 2, 4, 5, 6 remain valid.** Production registry is data (Decomplection). Pipeline-preference is structural. Set-valued productions prevent Track 7 redesign. SRE domain registration validates properties.

---

## §6 Risks and Mitigations (D.5 — updated from external critique F1)

| Risk | Severity | Mitigation |
|------|----------|------------|
| data/trait/impl tree parsing exposes new bugs | MEDIUM | Three-level WS validation (L1 + L2 + L3). Merge provides fallback during development. |
| Spec cell residuation at quiescence (D.5) | MEDIUM | Defns whose spec cell is still ⊥ at quiescence proceed without annotation. Correct semantics — spec-less function. |
| Trait→spec dependency: spec production needs trait registry (D.5) | HIGH | Spec production reads trait registration cell, residuates if trait not yet registered. Re-fires when trait cell advances. Same pattern as spec→defn. |
| Generated defs: scatter + termination (D.5) | HIGH | Stratum boundary S0/S1. Depth bounded at 1 (generated defs don't produce further data/trait). Wiring-state cell for quiescence accounting. |
| Registration extraction scope (3,017 lines interleaved parse+register) | HIGH | Phases 3b-3e extract registration-only logic. Most of process-spec (1,548 lines) is parsing handled by tree-parser. Extraction is ~200-400 lines per form type. |
| Missing form types (bundle, deftype, subtype, etc.) (D.5 F7) | HIGH | Added to Phase 1b scope. 6 additional error stubs + 1 missing form (subtype). Must complete before Phase 4 deletes preparse. |
| `load-module` path: no network, needs parameter writes (D.5 F8) | HIGH | Dual-mode registration interface: `commit-registrations!` writes to cells or parameters based on context. Two-Context Audit applied. |
| Per-form cell overhead on large files | LOW | Pocket Universe controls allocation. Pre-0: 2ns creation, 12ns merge. 200 forms × 5 merges = 12μs. |
| sexp path diverges from WS path | LOW | Accepted — incomplete, tracked in DEFERRED.md. Full retirement at PM module-loading-on-network. |

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

---

## §8 Pre-0 Benchmark Data (`dc87fb34`)

Benchmark file: `benchmarks/micro/bench-ppn-track3.rkt`
19 tests: M1-M7 micro, A1-A5 adversarial, E1-E4 E2E, V1-V3 algebraic validation.

### M1: parse-datum isolation

| Program | parse-datum x100 | Per-call |
|---------|-----------------|----------|
| simple (6 forms) | 1.9ms | 19μs |
| medium (25 forms) | 1.8ms | 18μs |
| large (55 forms) | 1.9ms | 19μs |

**parse-datum is ~19μs per call.** At 200 forms = 3.8ms. Negligible vs 485ms total pipeline.

### M2: preparse-expand-all decomposed

| Operation | simple | trait-impl |
|-----------|--------|-----------|
| preparse-expand-all | 0.051ms | 0.056ms |
| map parse-datum | 0.059ms | 0.057ms |

**Both sub-0.1ms.** Registration and expansion are not separable at this granularity — both are noise-level.

### M3: tree-parser vs parse-datum per form

| Form | Tree pipeline | Sexp pipeline | Ratio |
|------|--------------|---------------|-------|
| def | 0.144ms | 0.059ms | 2.4× |
| defn | 0.175ms | 0.057ms | 3.1× |
| data (stub) | 0.138ms | 0.062ms | 2.2× |
| trait (stub) | 0.142ms | 0.060ms | 2.4× |

**Tree pipeline is 2-3× slower per form** (includes read-to-tree + group + tag + rewrite + parse). Absolute difference: 0.08-0.12ms — negligible in context of 80-500ms full pipeline.

### M4: WS vs sexp full pipeline

| Program | WS | Sexp | WS overhead |
|---------|-----|------|-------------|
| simple (6 forms) | 83.3ms | 82.4ms | 1.1% |
| data-match (5 forms) | 78.1ms | — | — |

**WS merge overhead is ~1%.** Within measurement noise.

### M5: Production dispatch overhead

| Registry size | 1000 lookups | Per-lookup |
|---------------|-------------|-----------|
| 236 entries (hit) | 0.095ms | 95ns |
| 500 entries (hit) | 0.072ms | 72ns |
| 1000 entries (hit) | 0.072ms | 72ns |
| 236 entries (miss) | 0.017ms | 17ns |
| Merge 236+10 | 0.058ms | — |

**Registry lookup <100ns regardless of size.** Set-valued design (D.2) has zero measurable overhead. Scaling from 236 → 1000 entries does NOT increase lookup cost (hash amortized O(1)).

### M6: Per-form cell creation

| Operation | x1000 | Per-op |
|-----------|-------|--------|
| FormCell creation | 0.002ms | 2ns |
| FormCell merge (advance) | 0.008ms | 8ns |
| FormCell merge (no-op) | 0.012ms | 12ns |

**Cell creation is 2ns, merge is 8-12ns.** 200 forms × 5 merges = 1000 merges = 12μs total.

### M7: Full pipeline phase timing

| Phase | simple (6) | large (55) | A1 (167) |
|-------|-----------|-----------|----------|
| read-to-tree | 0.213ms | 1.983ms | 18.79ms |
| group-tree | 0.019ms | 0.061ms | 0.144ms |
| refine-tag | 0.020ms | 0.042ms | 0.091ms |
| rewrite-tree | 0.027ms | 0.087ms | 0.411ms |
| parse-forms | 0.041ms | 0.121ms | 0.279ms |
| **total-tree** | **0.320ms** | **2.294ms** | **19.715ms** |

**read-to-tree dominates** (66-95% of tree pipeline time). Group/refine/rewrite/parse are all sub-0.5ms even at 167 forms.

### A1-A5: Adversarial

| Test | Total pipeline | Tree pipeline fraction |
|------|---------------|----------------------|
| A1: 200-form program | 485ms | 20ms (4%) |
| A2: 20 data × 10 ctors (registration stress) | 901ms | — |
| A3: 50 spec+defn pairs | 401ms | — |
| A4: 20 mixfix expressions | 173ms | — |
| A5: 500-entry registry, 1000 dispatches | 0.8ms | — |

**Parsing is 4% of the 200-form pipeline.** A2 (registration stress) is the most expensive adversarial at 901ms — registration of 200 constructors, not parsing.

### E1: Comparative suite

14 programs. Range: 127ms (simple-typed) to 4,072ms (constraints-adversarial). **parse_ms = 0 across ALL per-command verbose outputs.** Confirms audit finding at scale.

### E2: Library file loading (top 10)

| File | Size | Time |
|------|------|------|
| lattices.prologos | 25.6KB | 2,642ms |
| lists.prologos | 22.7KB | 2,703ms |
| list.prologos | 17.1KB | 2,118ms |
| characters-and-strings.prologos | 17.0KB | 2,628ms |
| pairs-and-options.prologos | 12.2KB | 1,221ms |
| string-ops.prologos | 11.9KB | 2,466ms |
| lattice.prologos | 11.2KB | 1,440ms |
| lazy-sequences.prologos | 10.7KB | 700ms |
| collection-functions.prologos | 10.5KB | 2,096ms |
| collections.prologos | 10.2KB | 2,639ms |

72 library files found. Largest library files take 0.7-2.7s. This is the module-loading path that Phase 3 (registration migration) must not regress.

### E4: WS vs sexp pipeline comparison

| Program | WS | Sexp | WS overhead |
|---------|-----|------|-------------|
| simple | 141.8ms | 140.6ms | 0.8% |
| medium (20 defs) | 224.2ms | 220.3ms | 1.8% |

**WS overhead <2%.** Merge infrastructure cost is within noise.

### V1-V3: Algebraic Validation — ALL PASS

| Test | Property | Result |
|------|----------|--------|
| V1a | FormCell merge commutativity | 0 failures / 500 |
| V1b | FormCell merge associativity | 0 failures / 500 |
| V1c | FormCell merge idempotence | 0 failures / 500 |
| V2 | Stage chain distributivity | 0 failures / 1000 |
| V2b | Stage chain pseudo-complement (Heyting) | ALL PASS |
| V3a | ProductionRegistry set-union commutativity | 0 failures / 100 |
| V3b | ProductionRegistry set-union associativity | 0 failures / 100 |
| V3c | ProductionRegistry set-union idempotence | 0 failures / 100 |
| V3d | Provenance selection from merged set | `fn` → 2 productions (builtin + user) ✓ |

**All algebraic properties confirmed.** The stage chain IS distributive and Heyting. The production registry set-union IS Boolean. D.2 algebraic structure claims are validated by data.

---

## §9 Design Implications from Pre-0 Data

### Confirmed (no design changes needed)

1. **Parsing is confirmed negligible (0-4% of pipeline).** Track 3's value is architecture, incrementality, and extensibility — not performance. The design correctly prioritizes structural improvement over speed.

2. **WS merge overhead is <2%.** The merge infrastructure can be retired without performance concern. No need to optimize the merge path before replacing it.

3. **Set-valued production registry is performance-free.** D.2's decision to use `Set GrammarProduction` per keyword has zero measurable overhead vs singleton at any scale (236-1000 entries). Future-proofing for Track 7 costs nothing today.

4. **FormCell creation+merge is negligible (2-12ns per op).** Per-form Pocket Universe architecture adds μs-level overhead at worst. 200 forms × 5 merges = 12μs.

5. **All algebraic properties validated.** The D.2 lattice design is correct:
   - FormCell stage chain: distributive, Heyting ✓
   - Pipeline-preference ordering: avoids flat-lattice trap ✓
   - Production registry: Boolean (powerset) ✓
   - No type-lattice-style redesign will be needed ✓

### Findings that inform phasing

6. **read-to-tree dominates the tree pipeline (66-95%).** If parsing performance ever becomes a concern, read-to-tree is the optimization target — not group/refine/rewrite/parse. This is Track 1 infrastructure, not Track 3 scope.

7. **A2 registration stress (901ms) shows registration is the dominant cost for data-heavy programs.** Phase 3 (registration migration) should focus on correctness and not introduce additional overhead. The current registration mechanism is fast enough — the cost is in elaboration of the 200 generated constructors/accessors, not in the registration itself.

8. **Library file loading (0.7-2.7s per file) is the sensitive path.** Phase 3 must not regress module loading. The load-module path currently uses preparse-only (no merge) — Track 3 switches it to tree-parser + registration pass. E2 provides the regression baseline.

9. **Tree pipeline is 2-3× slower per form than sexp pipeline (M3), but both are sub-0.2ms.** This ratio is irrelevant at pipeline scale (elaboration dominates at 96%). No optimization needed for individual production fire cost.

### Design unchanged by Pre-0 data

No revisions to D.2 from performance data. All assumptions validated. All algebraic properties confirmed. Performance overhead of the new architecture is within noise.

---

## §10 Self-Critique (D.3)

### Lens 1 — Principles Challenge

**D3-P1: `register-from-surfs` is an imperative loop — NOT propagator-first.**

The design presents Phase 3's registration pass as a clean separation (parsing is pure, registration is a post-pass). But `register-from-surfs` is `(for ([surf surfs]) (cond ...))` — an imperative loop with side effects. This is explicitly not propagator-first.

*Challenge*: Could registration write to CELLS instead of parameters within the per-command network? For `process-file` / `process-string-ws`, the network exists. Registration cells could be per-command cells that elaboration reads. For `load-module`, registration must persist across commands (parameters necessary, scaffolding).

*Resolution*: Draw the scaffolding boundary at `load-module`-only, not ALL registration. For `process-file` / `process-string-ws`, Phase 3 COULD create registration cells alongside per-form cells — but this adds complexity (two registration paths: cells for process-file, parameters for load-module). **Accept as scaffolding for Track 3 with the explicit note: "incomplete because PM series unifies both paths on persistent cells."** Do not rationalize as "clean."

**D3-P2: Two-pass spec ordering is an ALGORITHMIC WORKAROUND.**

The design's `register-from-surfs` processes specs first, then data/trait/impl. This sequential ordering is encoded in control flow, not data dependency. In the propagator mindspace, a `defn` needing its spec should RESIDUATE until the spec cell is written.

*Resolution*: Keep two-pass for Track 3 as algorithmic scaffolding. Track 4 replaces it with cell-mediated dependency (spec cell → defn propagator). **Flag as red flag in the design: "sequential ordering in control flow where data dependency should determine ordering."**

**D3-P3: 5-stage chain over-constrains the pipeline ordering.**

The stage chain `raw → tagged → grouped → rewritten → parsed` forces a total order. But tag refinement (T(0)) and form grouping (G(0)) are partially independent — the code currently runs G(0) before T(0), but the data dependency is only that T(0) must see grouped nodes. A partial order (DAG) would be more faithful.

*Resolution*: Accept the chain as a simplification for Track 3. The algebraic properties (Heyting) are preserved by DAGs (product of chains). Note as a refinement opportunity: "stages could be a DAG; the chain is a conservative linearization." No redesign needed — only relaxation of ordering constraints if performance or extensibility demands it.

**D3-P4: parser.rkt retained as 6,605-line sexp shim — INCOMPLETE, not "pragmatic."**

The design says parser.rkt is "demoted." The honest label is: retaining 6,605 lines of dead-on-WS code is incomplete. The sexp path is used by 7,491 tests — migrating them is high-effort but is the Completeness principle applied.

*Resolution*: Label explicitly as "incomplete (deferred because test migration is high-effort; tracked in DEFERRED.md)." NOT "demoted" (which implies deliberate design choice). The sexp path retirement is a future track.

**D3-P5: merge-form has a spec-store parameter dependency — IMPURE merge function.**

The current `merge-form` (driver.rkt line 1543) reads `(current-spec-store)` via a closure to decide whether a form is spec-annotated. Cell merge functions MUST be pure (no parameter reads). The D.2 design adds a `provenance` field to handle this, but does not explicitly address removing the spec-store dependency from merge-form.

*Resolution*: The `provenance` field (D.2) IS the fix. When the preparse pipeline encounters a spec-annotated form, it sets `provenance = prov-preparse` (spec-annotated forms prefer preparse output). The merge function reads only the provenance field, not the spec-store parameter. **Phase 7 implementation must ensure provenance is set correctly for spec-annotated forms and that merge-form is rewritten as a pure function of its arguments.** Add this as an explicit implementation note in Phase 7.

**D3-P6: Production dispatch should be named as a propagator.**

The design describes `dispatch-production` as a "pure function." But in the propagator architecture, dispatch IS a propagator's fire body — it reads the production registry cell and the form cell, then writes to the form cell. Calling it a "function" obscures its propagator nature.

*Resolution*: In the implementation, dispatch should be a registered propagator factory (for each form cell, a dispatch propagator is installed that reads the form cell's keyword and fires the appropriate production). The design should use propagator terminology.

### Lens 2 — Codebase Reality Check

**D3-R1: Registration functions are MUCH larger than the design assumes.**

The design describes Phase 3 as "a new function `register-from-surfs` iterates over surf-* output and calls the same registration functions." But the actual registration functions are:

| Function | Lines | Complexity |
|----------|-------|-----------|
| `process-spec` | 1,548 | Parsing + metadata + mixfix registration + spec injection + generated defs |
| `process-trait` | 739 | Parsing + method signatures + default methods + registry |
| `process-impl` | 465 | Parsing + method bodies + validation + registry |
| `process-data` | 215 | Parsing + constructors + accessors + type definitions |
| `process-defmacro` | ~50 | Parsing + rule registration |
| **Total** | **~3,017** | |

**`process-spec` alone is 1,548 lines** — it's NOT just "registration." It parses the spec's type signature, extracts metadata, handles keyword arguments, registers mixfix operators, and generates derived definitions. This is INTERLEAVED parsing+registration.

*Implication for Phase 3*: `register-from-surfs` cannot simply "call the same registration functions." These functions expect RAW DATUMS (sexp), not surf-* structs. Phase 3 must either:
- (a) Port 3,017 lines of registration logic to work on surf-* input, or
- (b) Convert surf-* back to datum and call existing functions (wasteful), or
- (c) Extract the registration-ONLY logic from the parsing logic (significant refactoring)

Option (c) is the principled approach but is a major undertaking. The design underestimates Phase 3 scope.

**D3-R2: `preparse-expand-all` is more than expansion + registration.**

The design (§3.4) presents two responsibilities: expansion and registration. But `preparse-expand-all` (line 2366) also:
- Pre-scans ALL forms for specs before expanding any form
- Generates derived definitions (constructors, accessors, default methods)
- Handles `provide`/`export` auto-export for public forms
- Processes `subtype` and `deftype` declarations
- Handles `bundle` constraint expansion
- Does Pass 1 (spec + data + trait pre-scan) and Pass 2 (full expansion) as a TWO-PASS architecture

The design's Phase 3 must replicate ALL of this, not just "iterate over surfs and register."

**D3-R3: Generated definitions are a significant gap.**

When `data Color := Red | Green | Blue` is processed, `process-data` generates:
- Constructor functions: `Red`, `Green`, `Blue`
- Type check: `Color?`
- Pattern accessors
- These are ADDITIONAL surf-* forms injected into the form list

The design mentions this ("generated defs... must also be produced by the registration pass") but doesn't detail the mechanism. How does `register-from-surfs` inject generated defs into the form list? They need to go through the same elaboration pipeline as user-defined forms.

**D3-R4: The sexp path and WS path share `process-command`.**

Both paths produce surf-* structs that feed into `process-command` (driver.rkt). The shared tail means Track 3 only needs to change the front of the pipeline (how surfs are produced), not the back (how surfs are elaborated). This is correctly assumed in the design.

### Propagator Mindspace Check

**Red flags detected:**

1. `register-from-surfs` — `for/fold` over a list, mutating parameters. **Red flag: "for/fold to determine ordering."**
2. Two-pass spec ordering — "process specs before other forms." **Red flag: "Process X before Y."**
3. `merge-form` reading `current-spec-store` — parameter read inside what should be a pure merge. **Red flag: "cond/if dispatch choosing between sources" based on external state.**

**Not red flags (correctly propagator-native):**

1. FormCell Pocket Universe — lattice value with stage ordering. Information flow.
2. Production registry — monotone set, join is union. Information flow.
3. Stage advancement — propagator fire advances stage monotonically. Information flow.
4. Provenance-based merge — lattice ordering on surfs. Information flow.
5. SRE decomposition of surf-* — structural pattern matching on cell values. Information flow.

### Summary of D.3 Findings

| Finding | Severity | Resolution |
|---------|----------|------------|
| D3-P1: Registration is imperative, not propagator-first | MEDIUM | Accept as scaffolding. Label honestly. PM unifies. |
| D3-P2: Two-pass spec ordering is algorithmic workaround | MEDIUM | Accept for Track 3. Track 4 replaces with cell dependency. Flag as red flag. |
| D3-P3: Stage chain over-constrains ordering | LOW | Accept as simplification. DAG refinement available if needed. |
| D3-P4: parser.rkt retention is incomplete | LOW | Label as "incomplete (deferred)" not "demoted." Track in DEFERRED.md. |
| D3-P5: merge-form has impure spec-store dependency | HIGH | D.2 provenance field IS the fix. Phase 7 must rewrite merge-form as pure. Add implementation note. |
| D3-R1: Registration functions are 3,017 lines total | HIGH | Phase 3 scope is significantly larger than D.1/D.2 assumed. process-spec alone is 1,548 lines of interleaved parse+register. Option (c) extraction is correct but major. |
| D3-R2: preparse-expand-all is a 2-pass architecture | HIGH | Phase 3 must replicate pre-scan + generation + auto-export, not just "iterate and register." |
| D3-R3: Generated definitions injection mechanism unspecified | HIGH | Design must detail how register-from-surfs injects generated defs into the form pipeline. |

**D3-R1 through D3-R3 are the critical findings.** The design underestimates Phase 3 scope. The registration migration is not "call the same functions" — it's extracting registration logic from 3,017 lines of interleaved parsing+registration code. This may warrant splitting Phase 3 into sub-phases (3a: extract registration-only logic, 3b: wire into post-tree-parse pass, 3c: handle generated defs).
