# Deferred Work

Single source of truth for all deferred work across the Prologos project.
Items are organized by topic. When work is deferred during implementation,
add an entry here immediately.

**Principle**: Completeness over deferral. Items here should be genuinely
blocked on unbuilt infrastructure or uncertain design — not effort avoidance.
See `docs/tracking/principles/DEVELOPMENT_LESSONS.org` § "Completeness Over
Deferral".

**Last consolidated sweep**: 2026-03-03 (Schema Phase 5 Runtime complete: expr-panic, :default fill, :check assertion. 4963 tests, 246 files).

---

## Numerics Tower

### Phase 4: Float32/Float64
- 13 AST nodes per width (type, literal, add/sub/mul/div, neg/abs/sqrt, lt/le, from-nat, if-nan)
- Special values: ±Inf, NaN (multiple bit patterns, unlike Posit's single NaR)
- Cross-family conversions: Float↔Posit, Float↔Rat, Float↔Int
- Numeric trait instances: Add/Sub/Mul/Div/Neg/Abs/Eq/Ord for Float32/Float64
- Open: literal form for IEEE floats vs Posit (currently `~3.14` is Posit32)
- Source: `docs/tracking/2026-02-19_NUMERICS_TOWER_ROADMAP.md`

### Numerics Ergonomics (from audit) — MOSTLY COMPLETE
- ✅ Posit identity instances (AdditiveIdentity/MultiplicativeIdentity for Posit8-64) — `identity-instances.prologos`
- ✅ Posit equality primitives `p{N}-eq` — `test-posit-eq.rkt`
- ✅ Bare decimal `3.14` → Posit32 — `test-decimal-literal.rkt`
- ✅ Generic operators `+` `-` `*` `/` `<` `<=` `=` as parser keywords → trait dispatch — `test-generic-arith-01/02.rkt`
- ✅ Context-resolved `from-int` / `from-rat` keywords — `test-generic-from.rkt`, `test-cross-family-conversions-*.rkt`
- ✅ Generic `negate` and `abs` surface operators — `test-generic-arith-02.rkt`
- ✅ Numeric type join (`numeric-join`) for Posit dominance coercion — `test-numeric-join.rkt`
- ✅ Implicit coercion warnings (exact → approximate) — `test-coercion-warnings.rkt`
- Numeric literal polymorphism (`42` polymorphic via `FromInt`) — research/future
- Source: `docs/tracking/2026-02-22_NUMERICS_ERGONOMICS_AUDIT.org`

---

## Collections — Ergonomics

**STATUS**: Stages A-H COMPLETE. Generic collection functions (`map`, `filter`,
`reduce`, `length`, `into`, `head`, `empty?`, etc.) work on all collection types
via auto-resolved trait dicts. 8 native AST primitives, prelude shadowing,
29 new tests in `test-collection-fns.rkt`. 3605 tests pass.

**Stage I (Transducer runners for non-List) — DEFERRED**:
- `into-vec`, `into-set` runners using transducer protocol + transient builders
- Pipe fusion for non-List input types
- **Blocked on**: transient types not exposed at Prologos type level;
  pipe fusion requires elaborator changes

The following collection items ARE also deferred (genuine infrastructure deps):

### HKT Partial Application for Map Trait Instances
- Enable `Map K` as `Type -> Type` constructor
- Requires type-system-level partial application support
- **Blocked on**: unbuilt type system feature

### `Seq` as Proper Trait (deftype → trait migration)
- Enables trait resolver auto-dispatch for Seq
- Requires careful refactoring of deftype/trait boundary
- **Blocked on**: design uncertainty about deftype vs trait dispatch

### Clause-Style Constraint Matching (Layer 2 Specialization)
- Enable prioritized dispatch over disjoint trait constraints via `|` clause syntax
- E.g., `spec map | (Mappable C) -> ... | (Reducible C) -> (Buildable C) -> ...`
- Resolver tries clauses top-to-bottom; first satisfiable match wins
- Requires fallible trait resolution (try/fail instead of hard error)
- Foundation exists: `save-meta-state`/`restore-meta-state!` for speculative type-checking
- **Not blocked**, but separate from Layer 1 (fold+build doesn't need this)
- Source: `docs/tracking/2026-02-28_2200_CLAUSE_STYLE_CONSTRAINT_MATCHING.md`

### Sorted Collections (SortedMap, SortedSet)
- B+ tree or red-black tree backends
- New `Sorted` trait guaranteeing iteration order
- **Blocked on**: backend infrastructure not yet built

### Parallel Collection Operations
- Parallel `map`/`filter`/`reduce` via Racket's places/futures
- PVec tree structure natural for divide-and-conquer
- **Blocked on**: runtime parallelism infrastructure

---

## Collections — Data Structures Roadmap

### Phase 3: Specialized Structures (NOT STARTED)
- 3a: SortedMap + SortedSet (B+ Tree)
- 3b: Deque (Finger Tree)
- 3c: PriorityQueue (Pairing Heap)
- 3d-3f: **Subsumed by Logic Engine** — LVars, LVar-Map/Set, PropNetwork
  are now part of the Logic Engine phases (persistent PropNetwork cells
  with lattice merge functions replace standalone LVar types)
- 3g: Length-Indexed Vec (dependent types over collections)
- Source: `docs/tracking/2026-02-19_CORE_DATA_STRUCTURES_ROADMAP.md`

### Phase 4: Integration + Advanced (NOT STARTED)
- 4a: QTT Proof Erasure (erase type-level proofs at runtime)
- 4b: CRDT Collections (conflict-free replicated data types)
- 4c: Actor/Place Integration (cross-actor persistent collections)
- 4d: ConcurrentMap (Ctrie — lock-free concurrent hash map)
- 4e: SymbolTable (ART — Adaptive Radix Tree for string keys)
- 4f: **Subsumed by Logic Engine Phase 4** — UnionFind is now part of the
  Logic Engine design (persistent union-find for unification)
- Source: `docs/tracking/2026-02-19_CORE_DATA_STRUCTURES_ROADMAP.md`

### Linear Enforcement for Transient Handles
- Transient handles should be used linearly (QTT `m1` multiplicity)
- Currently enforced by convention only
- **Blocked on**: QTT linear tracking for mutable handles
- Source: `docs/tracking/2026-02-20_0347_TRANSIENT_BUILDERS.md`

---

## String Library

### Phase 4a: Grapheme Cluster Operations
- `string-graphemes : String -> LSeq String` (each grapheme as a string)
- `string-grapheme-count : String -> Nat`
- Grapheme-aware `string-reverse`
- Requires UAX #29 state machine (~30KB Unicode tables, quarterly updates)
- **Mitigation**: FFI to Racket's `string-grapheme-span` or ICU library

### Phase 4b: Unicode Normalization
- `string-normalize : NormForm -> String -> String` (NFC/NFD/NFKC/NFKD)
- Bridge to Racket's `string-normalize-nfc` etc. via FFI

### Phase 4c: String Similarity & Diffing
- `string-jaro-distance : String -> String -> Rat` (0 to 1 similarity score)
- `string-common-prefix : String -> String -> String`
- `string-myers-difference : String -> String -> List (Pair Symbol String)` (edit script)
- Useful for "did you mean?" suggestions in error messages

### Phase 4d: Regex Integration
- Depends on a regex library (not yet designed)
- `string-match`, `string-find-all`, `string-replace-regex`

### Phase 4e: Rope / TextBuffer Type
- B-tree rope with O(log n) concat/split
- Complementary to `String`, not a replacement

---

## Spec System / Extended Spec Design

### `??` Typed Holes — Phase 1 COMPLETE
- **STATUS**: Full 14-file pipeline implemented (reader → parser → elaborator →
  typing-core → pretty-print). Enhanced diagnostics: pretty-printed expected type,
  context bindings with synthetic names and multiplicities. 9 tests.
- **Remaining (Phase 2+)**: Type-aware suggestions (matching global bindings),
  editor protocol for structured hole reports (JSON).
- Source: `docs/tracking/2026-02-24_EXTENDED_SPEC_HARDENING.md`

### `property` Keyword — Phase 1 COMPLETE
- **STATUS**: Parsing, storage, `:includes` flattening, `/`-qualified names,
  `spec-properties` and `trait-laws-flattened` accessors all working.
  WS-mode integration via `rewrite-implicit-map` property-specific branch.
  Standard library declarations in `algebraic-laws.prologos`.
  73 tests (61 sexp + 12 WS).
- Source: `docs/tracking/2026-02-24_PROPERTY_KEYWORD_HARDENING.md`
- **Remaining (Phase 2+)**: QuickCheck execution of `:holds` clauses,
  `Gen` trait, runtime property checking — see Phase 2 below.

### `functor` Keyword — Phase 1 COMPLETE
- **STATUS**: Parsing, storage, deftype auto-registration all working.
  WS-mode integration fixed (rewrite-implicit-map applied at dispatch).
  Standard library declarations in `type-functors.prologos` (Xf, AppResult).
  11 tests (WS + sexp + stdlib).
- **Remaining (Phase 2+)**: `:compose`/`:identity` used for category-theoretic
  composition, opaque functors, error messages showing functor names.
- Source: `docs/tracking/2026-02-24_EXTENDED_SPEC_HARDENING.md`

### `:examples` Metadata — Phase 1 COMPLETE
- **STATUS**: Explicit parsing in `parse-spec-metadata`, `spec-examples` accessor.
  Multiple examples properly collected via `collect-constraint-values`.
  `spec-doc` accessor also added. 7 tests.
- **Remaining (Phase 2)**: Type-checking and running `:examples` entries.
- Source: `docs/tracking/2026-02-24_EXTENDED_SPEC_HARDENING.md`

### `:deprecated` Warnings — Phase 1 COMPLETE, extended for traits/functors
- **STATUS**: `deprecation-warning` struct in warnings.rkt, emitted during
  type checking when `expr-fvar` references a spec with `:deprecated` metadata.
  Extended to also check traits and functors for deprecation (G7).
  Displayed after command processing. 6 + 39 tests (test-config-audit.rkt).
- Source: `docs/tracking/2026-02-24_EXTENDED_SPEC_HARDENING.md`,
  `docs/tracking/2026-02-27_2300_SPEC_FUNCTOR_AUDIT.md`

### Configuration Language Hardening — Tier 1+2 COMPLETE
- **STATUS**: Gaps G1-G9 and opportunities O4-O7/O11 from audit implemented.
  - G1: `:invariant` / `:pre`+`:post` mutual exclusion error
  - G2: `:implicits` kind conflict detection in `deduplicate-binders`
  - G3: Property/spec `:where` constraint subset warning
  - G4: Functor/data name collision detection in `process-functor`
  - G5: `trait-meta` metadata field + `trait-doc`/`trait-deprecated` accessors
  - G6: `bundle-entry` metadata field + `bundle-doc` accessor
  - G7: Deprecation warnings for traits + functors in `typing-core.rkt`
  - G8: Improved error messages across all gap scenarios
  - G9: 39 tests in `test-config-audit.rkt`
  - O4: `:variance` parsed + stored (inert) on functor
  - O5: `:fold`/`:unfold` parsed + stored (inert) on functor
  - O6: `:pre`/`:post`/`:invariant` explicitly parsed + stored (inert)
  - O7: `:exists` clause on property
  - O11: `:refines :relevant` handled by default clause
- Source: `docs/tracking/2026-02-27_2300_SPEC_FUNCTOR_AUDIT.md`

### Phase 2: Example and Property Checking (QuickCheck-style)
- Type-check and run `:examples` entries as tests
- `Gen` trait for type-directed random generation
- Property checking for `:properties` and `:laws`
- Contract wrapping: `:pre`/`:post` generate runtime checks with blame
- Variance inference from `:unfolds` structure + declared-vs-inferred checking
- `:compose`/`:identity` active verification on functors
- `:exists` clause integration with QuickCheck witness search
- Source: `docs/tracking/2026-02-22_EXTENDED_SPEC_DESIGN.org`,
  `docs/tracking/2026-02-27_2300_SPEC_FUNCTOR_AUDIT.md` (Tier 3)

### Phase 3: Refinement Types and Verification
- `:refines` → Sigma types (dependent pairs with proofs)
- `:properties` → compile-time proof obligations
- Proof search: `:proof :auto` triggers logic engine
- `:measure` for termination checking
- Opaque functors (no `:unfolds`)
- Source: `docs/tracking/2026-02-22_EXTENDED_SPEC_DESIGN.org`

### Phase 4: Interactive Theorem Proving
- Editor protocol for `??` hole interaction
- Case splitting, proof search, refinement reflection
- `:transforms` and `:adjoint` keys on `functor`
- Source: `docs/tracking/2026-02-22_EXTENDED_SPEC_DESIGN.org`

---

## Implicit Inference

### Auto-Introduce Unbound Type Variables — COMPLETE ✅
- ✅ Direction 1: Capitalized `A` free in type signature → auto-introduce `{A : Type}`
- Implemented in `macros.rkt` (`collect-free-type-vars-from-datums`, `auto-detected-binders`)
- Filters known type names, user-defined constructors, traits, bundles, locally-bound Pi names
- 191+ passing tests in `test-auto-implicits.rkt`, real usage in `test-hkt-errors.rkt`
- Source: `docs/tracking/2026-02-22_IMPROVED_IMPLICIT_INFERENCE.org`

### Kind Inference from `:where` Clauses — Direction 2 ✅ COMPLETE
- `propagate-kinds-from-constraints` refines kinds for explicit `{C}` binders
- Auto-detect free variables in `:where` via Direction 1 auto-implicits — COMPLETE
  - `collect-free-type-vars-from-datums` already scans constraint args (macros.rkt:1685)
  - Auto-detected binders feed into `propagate-kinds-from-constraints` (macros.rkt:1699-1702)
  - Direction 1 inadvertently closed the Direction 2 gap — no new code needed
- `C` in `:where (Seqable C)` without `{C}` → infers `{C : Type -> Type}` from trait decl
- 15 e2e tests in `test-kind-inference-where.rkt`
- Source: `docs/tracking/2026-02-22_IMPROVED_IMPLICIT_INFERENCE.org`

---

## Syntax — Dot-Access

### Phases A-C COMPLETE ✅ (including nested access)
- ✅ Single-level: `user.name` → `(map-get user :name)`
- ✅ Nested: `user.address.city` → `(map-get (map-get user :address) :city)`
- Reader splits each `.field` into separate `dot-access` tokens; preparse `rewrite-dot-access` left-folds into nested `map-get`
- E2E tests pass for both sexp and WS mode (see `test-dot-access.rkt`)

### Phase D: Nil-Safe Navigation `#.`/`#:` — COMPLETE ✅
- `Nil` type + overloaded `nil` value (list-nil and Nil-nil, disambiguated by type inference)
- `nil-safe-get` keyword: `(Map K V | Nil) → K → (V | Nil)`, returns `nil` on missing key
- `#.field` / `#:key` WS-mode syntax via reader sentinel + preparse rewrite
- `nil?` predicate: `A → Bool`
- Mixed access chains: `user#.address.city`, `user.address#.city`
- 38 tests in `test-nil-type.rkt`, 4583 tests pass
- Source: plan `buzzing-launching-pascal.md`

---

## Schema + Selection

### Phases 1-3b COMPLETE ✅
- Schema: field registry, named type, typed construction, typed field access
- Selection: parsing, registry, elaboration, field-gating, structured paths
- Deep paths: `:address.zip` parsing, wildcards (`*`/`**`), brace expansion
- Deep validation: nested schema field validation in elaborator
- Source: `docs/tracking/2026-03-02_2200_SCHEMA_SELECTION_DESIGN.md`, plan `buzzing-launching-pascal.md`

### Phase 3c: Nested Field-Gating for Deep Paths (COMPLETE)
- Lazy sub-selection synthesis: accessing `:address` on `AddrZip` (requires `:address.zip`)
  returns synthetic sub-selection type restricting access to only `:zip`
- Sub-selections are normal `selection-entry` structs cached under deterministic names
  (e.g., `AddrZip/address`) in the existing selection registry
- Recursive nesting for 3+ levels, bare paths and wildcards return full schema (unrestricted)
- 4 helpers: `selection-sub-name`, `extract-path-suffixes`, `selection-field-unrestricted?`, `selection-field-type`
- 9 new tests (31-39), 2 existing tests updated
- Commit: `9435568`

### Phase 4: Selection Composition (COMPLETE)
- `:includes [A B]` set-union with `path-union` join semantics (wildcards subsume specifics)
- Cross-schema includes and unknown selection references produce clear errors
- `User * MovieTimesReq` Sigma operator in type positions — DEFERRED (requires parser changes)
- Commit: `fa288eb`

### Phase 5: Schema Properties — Parsing + Storage (COMPLETE)
- `:closed` rejects extra keys at construction time
- `:default val` stored in `schema-field-default-val`
- `:check [pred]` stored in `schema-field-check-pred`
- Commit: `e27a3f8`

### Phase 5 Runtime: Default Fill + Check Assertion (COMPLETE)
- Phase 5a: `expr-panic` AST node — general-purpose abort, types as `∀A. String → A` (commit `ea4ea9f`)
- Phase 5b: `:default` preparse injection — auto-fills missing fields at schema construction (commit `8dfd645`)
- Phase 5c: `:check` runtime wrapping — emits `if/panic` assertions on field values at construction (commit `a4d993f`)
- 14 new tests (17-30) in `test-schema-properties.rkt`; 4963 tests pass across 246 files

### Phase 3d: Selection Path Extension (COMPLETE)
- Brace items as sub-paths: `:a.{b.c d.e}` branches navigate independently (commit `1d342a9`)
- Nested braces: `:a.{b.{c d} e}` recursive expansion (commit `b288922`)
- Post-brace continuation: `:a.{b c}.**` suffix appends to all branches (commit `91528fe`)
- Cons-dot normalization: `.{...}` at tail position in brackets (commit `5b4d4dc`)
- E2E pipeline tests with real schemas (commit `994d9fb`)
- 17 new tests (40-57) in `test-selection-paths.rkt`

### Phase 3e: General-Purpose Path Expressions (COMPLETE)
- `get-in`/`update-in` expressions use path algebra for data navigation/transformation
- AST + parsing: `surf-get-in`, `surf-update-in` parsed with `validate-selection-paths` (commit `32993ad`)
- Elaboration: pure desugaring to `map-get`/`map-assoc` chains — no downstream changes (commit `f5749c8`)
- Type checking: free from desugaring — existing `map-get`/`map-assoc` type rules apply
- 20 new tests in `test-path-expressions.rkt` (commit `93af4bc`)
- WS mode disambiguation: deferred (see "WS Mode Path Expression Disambiguation" below)

---

## Syntax — Mixfix

### Statement-Like Forms in `.{...}`
- E.g., `.{x = y + 1}` for assignment
- Keep `.{...}` purely expression-oriented for now

### `do` Notation Inside `.{...}`
- Prefer dedicated `do` blocks for monadic code

### `functor :compose` Auto-Registration of Mixfix Symbol
- Deferred due to coupling concerns

### Extended Pattern Matching in `.{...}`
- E.g., `.{n + 1}` → `suc n` (Agda view patterns)

### Phase 4: Advanced Mixfix
- Unicode operator symbols
- Postfix operators (`.{n!}`)
- Full mixfix patterns (`.{if p then a else b}` — Agda-style)
- Source: `docs/tracking/2026-02-23_MIXFIX_SYNTAX_DESIGN.org`

---

## Logic Engine / Propagator Architecture

### Phase 1: Lattice Trait + champ-insert-join — COMPLETE
- `Lattice` trait: bot, join, leq — COMPLETE
- Standard instances: FlatLattice, SetLattice, MapLattice, IntervalLattice, BoolLattice — COMPLETE
- `champ-insert-join` Racket-level helper: COMPLETE (in `champ.rkt`)
- `lib/prologos/core/lattice-trait.prologos` + `lattice-instances.prologos` — COMPLETE
- Source: `docs/tracking/2026-02-24_LOGIC_ENGINE_DESIGN.org`

### Phase 2: Persistent PropNetwork — Racket-Level — COMPLETE
- Persistent/immutable propagator network backed by CHAMP maps — COMPLETE
- All structs `#:transparent` (not `#:mutable`) — pure functional operations — COMPLETE
- CellId/PropId = Nat counters (deterministic, no gensym)
- `net-cell-write` does join-on-merge — LVars subsumed by cells
- `run-to-quiescence`: pure tail-recursive loop (BSP scheduler)
- Backtracking = keep old reference (O(1)). Snapshots = free.
- 3 files (`propagator.rkt`, tests), ~60 Racket-level tests
- Source: `docs/tracking/2026-02-24_LOGIC_ENGINE_DESIGN.org`

### Phase 3: PropNetwork as Prologos Type — COMPLETE
- 14 AST nodes (3 type ctors, 3 runtime wrappers, 8 operations) across 12-file pipeline
- Type rules (`typing-core.rkt`, `qtt.rkt`), reduction (`reduction.rkt`), surface syntax
- HasTop trait + BoundedLattice bundle + trait instances
- Fix: parametric impl dispatch for compound type args without `where` (`macros.rkt`)
- 56 tests across `test-propagator-types.rkt` (32), `test-propagator-integration.rkt` (16), `test-propagator-lvar.rkt` (8)
- Source: `docs/tracking/2026-02-24_LOGIC_ENGINE_DESIGN.org`

### ~~Deferred~~ COMPLETE: `new-lattice-cell` Generic Wrapper
- `new-lattice-cell {A} PropNetwork -> [PropNetwork * CellId] where (Lattice A)`
- **Resolved 2026-02-27**: The "meta-resolution limitation" was a false alarm.
  Phase D of trait resolution (where-context propagation into closures) already handles this.
  The actual blockers were compiler edge cases:
  1. `*` operator not recognized in single-sub-list `$angle-type` (macros.rkt `param-type->angle-type`)
  2. `PropNetwork`/`CellId` missing from `known-type-name?` (auto-detected as type vars)
  3. De Bruijn shift bug in `net-new-cell` typing rule (polymorphic merge type mis-constructed)
  4. QTT `inferQ` doesn't handle standalone lambdas — fixed by using `checkQ` for merge arg
- Exported from prelude via `namespace.rkt`
- Source: `lib/prologos/core/propagator.prologos`

### Phase 4: UnionFind — Persistent Disjoint Sets (COMPLETE)
- Persistent union-find (Conchon & Filliâtre 2007) with path splitting
- 7 AST nodes through full 14-file pipeline
- `union-find.rkt` Racket module + surface syntax (`uf-empty`, `uf-make-set`, `uf-find`, `uf-union`, `uf-value`)
- 57 tests (19 unit + 29 type-level + 9 integration)
- Source: `docs/tracking/2026-02-24_LOGIC_ENGINE_DESIGN.org`

### Phase 5: Persistent ATMS — Hypothetical Reasoning (COMPLETE)
- **Persistent/immutable** ATMS backed by hasheq maps
- Assumptions, supported values, nogoods — all persistent
- Worldview switching: `struct-copy atms ... [believed new-set]` — O(1)
- Backtracking = keep old `atms` reference — O(1)
- `amb` operator, dependency-directed backtracking, `solve-all`
- 14 AST nodes through full 14-file pipeline
- `atms.rkt` Racket module + surface syntax (`atms-new`, `atms-assume`, `atms-retract`, `atms-nogood`, `atms-amb`, `atms-solve-all`, `atms-read`, `atms-write`, `atms-consistent?`, `atms-worldview`)
- 74 tests (26 unit + 37 type-level/eval + 11 integration)
- Source: `docs/tracking/2026-02-24_LOGIC_ENGINE_DESIGN.org`

### Phase 6: Tabling — SLG-Style Memoization (COMPLETE)
- Tables as PropNetwork cells with list-based set-merge (not SetLattice — lists with `remove-duplicates`)
- table-store wraps PropNetwork; backed by `hasheq` (consistent with Phases 4-5)
- Answer modes: `all` (set-union) and `first` (freeze after one); `lattice f` deferred
- 10 AST nodes (1 type + 1 wrapper + 8 operations)
- 63 tests (20 unit + 31 type-level/eval + 12 integration)
- `:tabled` and `:answer-mode` spec metadata — deferred to Phase 7 (`defr`)
- Source: `docs/tracking/2026-02-24_LOGIC_ENGINE_DESIGN.org`

### Phase 7: Surface Syntax — defr, rel, solve (COMPLETE)
- `defr` / `rel` keywords (named and anonymous relations)
- `&>` clause separator, `||` fact sentinel, `?var` logic variables
- `solve` / `solve-with` / `explain` / `explain-with` bridge to functional world
- Mode prefixes: `?` (free), `+` (input), `-` (output)
- 26 AST nodes through full 14-file pipeline
- Stratification module (Tarjan SCC + stratify)
- Provenance module (answer records + derivation trees)
- Grammar updates (EBNF §5.28 + prose)
- 140+ Phase 7-specific tests
- **Completed**: 2026-02-25

### Post-Phase 7: Stratified Evaluation — COMPLETE ✅
- `stratified-eval.rkt` orchestration module bridging stratify + tabling + relations
- Dependency extraction (`relation-info->dep-info`), cached stratification (version-based invalidation)
- Single-stratum fast path (zero overhead for programs without negation)
- Multi-stratum bottom-up evaluation with stratum ordering for sound negation-as-failure
- Variable-carrying negation fix (`rename-ast-vars`, `apply-subst-to-goal` in relations.rkt)
- Wired into reduction.rkt (`solve-goal` → `stratified-solve-goal`)
- 17 new tests in `test-stratified-eval.rkt`, 199/199 suite pass
- **Remaining (future)**: Lattice aggregation (count, min, max, sum) between strata
- Source: `docs/tracking/2026-02-26_STRATIFIED_EVALUATION.md`

### Post-Phase 7: Galois Connections + Domain Embeddings (PHASE 6 COMPLETE)
- ✅ Phase 6a: `Widenable` trait + widening-aware fixpoint (`run-to-quiescence-widen`)
- ✅ Phase 6b: `GaloisConnection {C A}` trait + `impl GaloisConnection Interval Bool`
- ✅ Phase 6c: Cross-domain propagation (`net-add-cross-domain-propagator`)
- ✅ Phase 6d: Sign + Parity abstract domain library modules
- ✅ Phase 6e: Call-site specialization for `new-widenable-cell`, grammar docs, integration tests
- ✅ Phase 6f: `sign-galois.prologos` — `impl GaloisConnection Interval Sign` (resolved: negative literals + Rat comparison)
- **Deferred**:
  - `connect-domains` Prologos-level wrapper (needs AST keyword or FFI)
  - Additional abstract domains (Congruence, Pointer, etc.)
- Source: `docs/tracking/2026-02-27_1026_GALOIS_CONNECTIONS_ABSTRACT_INTERPRETATION.md`

### ~~Capabilities — Phase 7e-7f: Dependent Capability Extensions~~ COMPLETE ✅
- **7e**: `cap-entry` struct + `cap-set` migration — commit `5c9eb93` (IO-I)
- **7f**: cap-type-bridge α/γ for `expr-app` caps — commit `5c9eb93` (IO-I)
- **7g**: Dependent caps in `foreign` blocks (`:requires [FileCap p]` syntax) — DEFERRED as IO-N
- **Context**: Phases 7a-7d complete (commit `0a75942`), 7e-7f complete via IO-I
- **Source**: `docs/tracking/2026-03-01_1500_CAPABILITIES_AS_TYPES_DESIGN.md` §Phase 7

### Capabilities — Phase 8d: Multi-Agent Cross-Network Reasoning
- Separate agents on separate propagator networks cross-referencing via
  cross-network propagators, with dependent-typed proof objects as provenance
- Machine-checkable justification chains across network boundaries
- **Blocked on**: session type design (Phase 9), dependent capabilities (Phase 7e-7g)
- **Context**: Phases 8a-8c complete (commit `cd8b1e1`) — α/γ Galois connections,
  cross-domain network, overdeclared analysis, cap-bridge REPL command
- Source: `docs/tracking/2026-03-01_1500_CAPABILITIES_AS_TYPES_DESIGN.md` §Phase 8d

### Elaborator Propagator Refactoring — Phases 8+A-E COMPLETE (E3 deferred)
- ✅ Phase 8: Propagator network as primary type inference engine (56-62% speedup)
- ✅ Phase A: CHAMP meta-info store, eliminated hash dual-writes in production
- ✅ Phase B: Level/mult/session metas migrated to CHAMP with O(1) save/restore
- ✅ Phase C: Incremental trait resolution via wakeup callbacks
- ✅ Phase D1: ATMS threaded through speculation bridge (foundation)
- ✅ Phase D2: Capture support sets on contradiction
- ✅ Phase D3: Derivation chains in union-exhaustion-error (E1006)
- ✅ Phase D4: Format derivation chains in error display
- ✅ Hash removal: CHAMP is sole source of truth; legacy hash paths removed; ~20 test files migrated to `with-fresh-meta-env`
- ✅ Phase E1: Meta-aware pure unification — `try-unify-pure` follows solved metas via read-only callback; `has-unsolved-meta?` guard prevents spurious `type-top` contradictions
- ✅ Phase E2: Propagator-driven constraint wakeup — `solve-meta!` runs `run-to-quiescence` after cell writes for transitive propagation; elab-network unwrap/rewrap for scheduler
- ✅ Phase E3: Constraint-retry propagators — cell-state-driven retry after quiescence replaces legacy wakeup registry in production path (commits d2ef419, 29cdf0f, b5ba62b). Legacy fallback retained for test contexts without network.
- Source: `docs/tracking/2026-02-25_TYPE_INFERENCE_ON_LOGIC_ENGINE_DESIGN.md`

### Propagator-First Phase 3e: Reduction Cache Cells — NOT STARTED
- **Phase**: 3e (follows Phase 3a-3d, all complete as of commit `9f85f0f`)
- **Rationale**: Reduction (whnf/nf/nat-value) is the hottest code path. Cache cell
  invalidation + dependency tracking needs performance benchmarking with explicit
  regression gates. Orthogonal to the definition-cell architecture — can be done
  independently after profiling shows no regression.
- **Dependencies**: Phase 3a (per-definition cells), Phase 3b (dependency recording)
- **Scope**: Convert whnf/nf/nat-value caches to write-through cells, gated behind
  `current-track-reduction-deps?` parameter (off for batch, on for LSP). When a
  definition changes (cell update), invalidate cached reductions that depended on it.
- **Risk**: Performance regression in batch mode if cache cell overhead exceeds savings.
  Must benchmark before and after with `racket tools/benchmark-tests.rkt --report`.
- **Design**: Each reduction cache entry gets a cell. Cache lookup reads the cell.
  Cache miss writes the result to the cell. Definition-change propagator invalidates
  dependent cache cells. The `current-track-reduction-deps?` gate ensures zero
  overhead in batch mode (caches remain simple `make-hash` when gate is off).

### Propagator-First Phase 3d: Full current-global-env Rename — DEFERRED
- **Phase**: 3d mechanical cleanup (Phase 3d documentation + alias complete, commit `9f85f0f`)
- **Rationale**: Renaming `current-global-env` → `current-prelude-env` across 266 files
  (1002 references) is purely mechanical with zero behavioral change. Alias provided
  via `rename-out` for new code. Full rename deferred to avoid risky mass-rename
  during active development.
- **Dependencies**: None (alias already works)
- **Scope**: Find-replace `current-global-env` → `current-prelude-env` in all files.
  Update test-support.rkt, batch-worker.rkt, driver.rkt, all test fixtures.

---

## FL Narrowing — WS Surface Gaps

### Nested Constructor Patterns in Match Arms
- `match` arms (`reduce-arm`) use flat bindings: `| suc n -> body` treats `n` as a variable
- Nested constructor patterns like `| suc zero -> body` treat `zero` as a variable name, not the constructor
- Bracketed form `| [suc zero] -> body` also fails — `effective-pattern` flattening unwraps it to the same flat representation
- Root cause: `parse-reduce-arm` (parser.rkt:5879) extracts everything after the ctor as raw symbol names; no recursion into `parse-single-pattern`
- **Workaround 1**: Use `defn` pattern clauses with double brackets: `defn pred | [[suc zero]] -> zero | [[suc [suc n]]] -> suc n | [[zero]] -> zero` — these compile via `compile-match-tree` which handles nested `pat-compound`
- **Workaround 2**: Nest matches manually: `| suc n -> match n | zero -> body1 | suc k -> body2`
- Fix would require: making `parse-reduce-arm` use `parse-single-pattern` infrastructure and compiling compound patterns into nested `surf-reduce` bodies
- Source: C2 investigation, 2026-03-08

### Higher-Order Narrowing in WS Mode
- `[apply-op ?f 3N 2N] = 5N` doesn't trigger HO narrowing via WS pipeline
- Infrastructure works at sexp/API level (23 tests pass)
- Issue: bound variable `f` (de Bruijn `expr-bvar`) in function body ≠ caller's `?f` (`expr-logic-var`)
- Fix requires deeper integration between narrowing substitution env and DT body traversal
- Source: C3 analysis, 2026-03-08; `examples/narrowing-demo.prologos` §9

### Pre-Existing Relational Runtime Gaps (identified 2026-03-14)
These gaps were identified during WS acceptance testing for the WFLE feature. They are pre-existing
issues in the relational subsystem (Phase 7 surface syntax), not WS-specific bugs.

- ~~**`is`-goals don't evaluate functional expressions**~~ — **RESOLVED** (commit `df65974`):
  `is`-goals now evaluate via `nf` callback, parser disables relational context for expression arg.
- ~~**`guard` not in parser keyword list**~~ — **RESOLVED** (commit `a863f20`):
  Guard wired through parser/elaborator with 1-arg (condition only) and 2-arg (condition + goal) forms.
- ~~**`cut` not in parser keyword list**~~ — **RESOLVED** (commit `a863f20`):
  Cut parses and elaborates. Runtime handler succeeds but doesn't actually prune alternatives
  (needs solver-level cooperation for true committed choice — deferred).
- **Multi-arity `|` relation variants — zero-arg solve path**: Multi-arity variants (different
  param counts per `|` clause) work correctly in the DFS solver — `solve-app-goal` tries all
  variants via `append-map` and arity-mismatched variants fail unification gracefully. The only
  gap is `solve-goal`'s zero-arg path (bare `solve rel-name`), which infers arity from the
  first variant only. Fix: iterate all variants or require explicit args for multi-arity rels.
- ~~**Anonymous `rel` + `solve` integration**~~ — **RESOLVED** (commit `14c3d2b`):
  `run-solve-goal` now dispatches on `expr-rel?`, creates temporary relation-info with gensym name.
- ~~**Trait dispatch in relational `is`-goals and `guard` conditions**~~ — **RESOLVED** (commit `78f978e`):
  Two fixes: (1) generic struct walking in `relations.rkt` (subst/rename/collect-logic-vars-in-expr)
  now walks transparent structs via `struct->vector`, enabling parser keyword nodes like `expr-int-add`
  to have their logic vars substituted. (2) Generic trait-dispatched names from the algebra module
  (`plus`, `minus`, `times`, `ord-gt`, `ord-lt`, `eq-check`) work in is-goals and guard conditions
  because their `spec` constraints trigger dict insertion at elaboration time. Users should use
  `plus`/`ord-gt` (not bare `add`/`gt?`) for type-generic relational arithmetic.
- Source: `examples/2026-03-14-wfle-acceptance.prologos` §F (STATUS annotations)

---

## Homoiconicity

### Phase IV: Runtime Eval & Read
- Runtime `eval` — evaluate quoted expressions; requires embedding compiler
- Runtime `read` — parse string to Prologos datum; requires exposing reader
- `unquote-splicing` (`,@`) — only single-element unquote is implemented
- Quasiquote `,x` unquote inside paren forms — reader.rkt:1074–1077 unconditionally
  skips commas in parens as separators, losing the `$unquote` wrapper. Needs
  quasiquote-context-aware comma handling. (Discovered in WS-mode audit, 2026-03-10)
- Source: `docs/tracking/2026-02-19_HOMOICONICITY_ROADMAP.md`

---

## Type System — HKT

### ~~Deferred~~ COMPLETE: HKT-8: Call-Site Rewriting
- **Resolved 2026-02-27**: `rewrite-specializations` implemented in `driver.rkt`.
  Walks post-zonk expression tree, matches application chains headed by functions
  with where-constraints, strips implicit type + dict args, replaces with registered
  specialized name. Wired into eval, def (unannotated), and def (annotated) paths.
- `new-lattice-cell` has Bool and Interval specializations in `propagator.prologos`.
- Fast path: empty registry → zero overhead.
- Source: `driver.rkt` (rewrite-specializations), `lib/prologos/core/propagator.prologos`

### HKT-9: Constraint Inference from Usage
- Method-triggered constraint generation algorithm designed
- Gated behind feature flag
- Source: `docs/tracking/2026-02-20_2100_HKT_GENERIFICATION.md`

---

## Mixed-Type Maps

### Type Narrowing for `map-get`
- When key is statically known, narrow return type
- Source: `docs/tracking/2026-02-22_MIXED_TYPE_MAPS.md`

### `A?` Nilable Union Syntax — COMPLETE ✅
- `String?` → `(String | Nil)` parser-level sugar for known uppercase type names ending with `?`
- Implemented in Phase D (above)

### Pattern Matching for Union Values
- Convenience forms for matching on union values
- Source: `docs/tracking/2026-02-22_MIXED_TYPE_MAPS.md`

---

## ~~Numerics — Peano Nat Efficiency~~ COMPLETE

### ~~Replace Peano Nat with Native Representation~~ DONE (commits `f17c522`, `c2ad2b5`, `5ef9fed`)
- **Implemented**: Option 3 (Idris 2 approach) — Peano surface syntax preserved, native `expr-nat-val` at runtime
- `nat->expr`, `nat-value`, elaboration, whnf, nf, pattern matching, unification all use O(1) `expr-nat-val`
- 14 pipeline files updated, 17 test files updated, 5005 tests pass
- ~~**Problem**: Peano encoding (`Z | S (S (S Z))`) is O(n) for every numeric operation.~~

### WS Mode Path Expression Disambiguation
- **Problem**: In WS mode, `.{` is tokenized as `dot-lbrace` (mixfix expressions). Path branching syntax `:address.{zip city}` conflicts with mixfix.
- **Options**:
  1. Context-sensitive: parser knows `get-in`/`update-in` path arg is a "path parsing context" where `.{` means branching
  2. Different syntax for WS path branching: `.:{zip city}` or `[path :address.{zip city}]`
  3. Sexp fallback for complex paths (always available)
- **Status**: Sexp mode works correctly now. WS disambiguation deferred until WS-mode `get-in`/`update-in` is needed.
- **Source**: Phase 3e-e plan (2026-03-03)

## Coding Standards — Nat-in-Computations Audit

### Replace Nat with PosInt/Int in Computation Examples and APIs
- **Problem**: `Nat` (Peano natural numbers) is used in many examples, docs, and APIs
  where `PosInt` or `Int` would be more correct and performant. `Nat` is a proof-level
  type (induction, length-indexed vectors); using it for runtime computations (fuel
  limits, counts, sizes) is an anti-pattern that sets bad examples.
- **Scope**: Audit all docs, examples, `:fuel` parameters, library APIs, and design
  documents for `Nat` used in computational (not proof) contexts.
- **Replace with**: `PosInt` for strictly-positive counts (fuel, sizes, ports),
  `Int` for general integers, `Nat` only for inductive/proof contexts.
- **Source**: Session type design review (2026-03-03)

---

## Propagator-First Elaboration Migration

### TMS-Aware Infrastructure Cells + Structural State — NOT STARTED (Track 6 Phase 5b blocker)

- **Problem**: Infrastructure cells and elab-network structural fields are NOT TMS-managed,
  violating the propagator-first principle. This creates a two-tier system where some state
  (TMS cells) participates in speculation branching and retraction, while other state
  (infrastructure cells, meta-info, id-map, next-meta-id) requires the legacy
  `restore-meta-state!` snapshot/restore mechanism as a mandatory fallback.
- **Discovered**: Track 6 Phase 5b (commit `cb393bb`) — attempting to retire belt-and-suspenders
  produced 2 test failures: constraint store leaks and meta-info solved-status leaks.
- **Root cause analysis**:
  1. **Infrastructure cells bypass TMS**: Created with `net-new-cell` (plain values), not
     `net-new-tms-cell`. The `net-cell-write` TMS routing (propagator.rkt line 350–352) only
     activates when `(tms-cell-value? old-val)` — infrastructure cells never enter TMS branching.
     Affected cells: constraint store, unsolved-metas set, and any cell created via
     `elab-new-infra-cell` in `elaborator-network.rkt`.
  2. **elab-network structural fields not TMS-managed**: `meta-info` CHAMP, `id-map` CHAMP,
     `next-meta-id` counter are fields in the `elab-network` struct, not cells in the propagator
     network. When a meta is solved during speculation, `meta-info` retains "solved" status after
     TMS retraction. Similarly, `id-map` mappings and `next-meta-id` advances persist.
- **Consequence**: `restore-meta-state!` (snapshot/restore) cannot be retired. The belt-and-suspenders
  pattern must remain active: TMS retraction handles cell branch cleanup, `restore-meta-state!`
  handles structural rollback. This is architectural debt — the snapshot mechanism is a
  whole-state sledgehammer that undermines incremental TMS-based rollback.
- **Fix path (two parts)**:
  1. **Infrastructure cells → TMS-aware** (~10 lines, low risk): Change `elab-new-infra-cell` to
     use `net-new-tms-cell` with `make-tms-merge` wrapping the existing merge function. This makes
     constraint store, unsolved-metas, and all infrastructure cells participate in TMS branching.
     Retraction would then undo accumulations added under the retracted assumption.
  2. **Structural fields → TMS cells or infrastructure cells** (medium effort): Move `meta-info`,
     `id-map`, and `next-meta-id` from `elab-network` struct fields to TMS-aware cells in the
     propagator network. This undoes the Phase 5a pattern (which moved meta-info INTO the struct)
     but is necessary for full TMS management. Alternative: keep as struct fields with a separate
     TMS-aware rollback mechanism (less clean, but lower risk).
- **Placement**: This should be addressed in **Track 7 (QTT Multiplicity Cells)** as a prerequisite
  phase, or as a standalone mini-track between Track 6 and Track 7. The work is architecturally
  independent of QTT but shares the same infrastructure surface area. It must be completed before
  Track 8 (Unification as Propagators) where incremental rollback correctness is load-bearing.
- **Principle**: Propagator-first — all speculation-scoped state should flow through the TMS
  mechanism, not maintain a parallel snapshot/restore path. The current two-tier system is
  an acceptable transitional state but NOT the target architecture.
- **Source**: Track 6 Phase 5b findings (commit `cb393bb`), analysis in
  `docs/tracking/2026-03-16_TRACK6_DRIVER_SIMPLIFICATION.md` §4 Phase 5b notes
- **Forward references**: Track 6 design doc (Phase 5b section), master roadmap Track 7

### Unify type inference and trait resolution under the propagator network — NOT STARTED
- **Problem**: The current elaboration pipeline uses the propagator network for infrastructure
  cells (registries, environments) but does NOT create formal propagator edges between cells.
  Constraint solving (type unification, trait resolution, hasmethod resolution) is driven by
  imperative retry loops in `metavar-store.rkt` (`solve-meta!`, `retry-constraints-via-cells!`,
  `retry-trait-for-meta!`), not by the propagator scheduler.
- **Consequence**: The propagator network contains 47+ cells with non-bot values but 0
  propagator edges. The Propagator Network Visualization (Phase 4b, commit `a2286fb`) renders
  cells correctly but shows no topology because there IS no topology in the network.
- **Goal**: Migrate the constraint-solving path to use `net-add-propagator` so that:
  1. Meta→constraint relationships are formal propagator edges
  2. Trait resolution triggers propagator firings, not imperative retry scans
  3. The propagator visualization shows the actual type inference DAG
  4. `run-to-quiescence` drives solving instead of ad-hoc retry loops
- **Scope**: This is a dedicated design/implement track — multi-session, architectural.
  The P-Unify section below covers unification specifically; this covers the full pipeline.
- **Visualization impact**: Once this lands, the existing visualization infrastructure
  (Phases 0–4b) will display real DAG topology with no additional changes needed.
- **Depends on**: Existing propagator infrastructure (COMPLETE), ATMS/GDE (COMPLETE)
- **Source**: `docs/tracking/2026-03-12_PROPAGATOR_VISUALIZATION_DESIGN.md` gap analysis,
  `docs/tracking/2026-03-11_1800_PROPAGATOR_FIRST_MIGRATION.md`

---

## Propagator-Driven Unification (P-Unify)

### Full Lattice-Propagator Unification — NOT STARTED
- **Problem**: Current `unify*` is a post-hoc observer — calls imperative `unify-core`,
  then checks propagator network for contradictions. The lattice cells react to meta-solving
  side effects but don't *drive* unification.
- **Goal**: Replace `unify-core` internals with cell-driven solving where the propagator
  network is the *authority*, not the observer.
- **Key capabilities**:
  1. Propagator-driven solving — cell narrowing triggers unification of dependent terms
  2. Bidirectional cross-domain inference — multiplicity evidence constrains type choices
  3. Incremental re-solving — partial state propagation instead of full re-unification
- **Depends on**: GDE (General Diagnostic Engine) — COMPLETE (commits 163f7c6..f7cbe22)
- **Prerequisite complete**: P1-G migration (all call sites flow through `unify*` choke point)
- **Prerequisite complete**: GDE (context assumptions, minimal diagnoses, derivation trees)
- **Source**: P1-G design discussion (2026-03-04 session)

---

## Session Types — Concurrent Runtime

### Full Concurrent Session Execution (NOT STARTED)
- **Problem**: Phase 0 compiles processes to a single propagator network that runs to
  quiescence atomically. `!!` and `!` produce identical runtime behavior — there is no
  real concurrency, no buffered channels, no async message delivery.
- **Goal**: True concurrent session execution with:
  1. Buffered channels with async message passing (bounded/unbounded)
  2. `!!`/`??` runtime distinction from `!`/`?` (non-blocking send returns immediately,
     non-blocking recv returns a promise cell with real lifecycle)
  3. Multiple propagator networks running concurrently (one per process or process group)
  4. Distributed propagator scheduling — cross-network message delivery
  5. Promise cell lifecycle: pending → resolved → consumed (with timeout/cancellation)
  6. Fairness guarantees via strategy `:fairness` parameter
- **Current Phase 0 semantics**: `!!`/`??` are parsed and type-checked as session type
  variants (`sess-async-send`/`sess-async-recv`) but compile to the same runtime
  operations as `!`/`?`. `@` is parsed as a deref operator but is identity at runtime.
  This is by design — Phase 0 validates the type-level protocol without concurrent runtime.
- **Blocked on**: Multi-network runtime infrastructure, Racket-level concurrency primitives
  (places/threads), distributed scheduling design
- **Value**: Propagators naturally model distributed computation — each cell is a "location"
  that can live on any network. Cross-network propagators are the foundation for distributed
  session execution. This is where the propagator architecture really shines.
- **Source**: S8 design discussion (2026-03-04 session), `docs/tracking/2026-03-03_SESSION_TYPE_IMPL_PLAN.md`

---

## IO Library

### Dependent Send/Receive (`!:`/`?:`) (NOT STARTED — Phase IO-J)
- **Problem**: Two small gaps remain in an otherwise complete pipeline: (1) elaborator
  discards binder name (L3201-3215), preventing dependent continuation types from
  referencing the bound variable; (2) runtime predicates `sess-send-like?`/`sess-recv-like?`
  exclude `sess-dsend`/`sess-drecv`.
- **Note**: Reader, preparse, surface syntax, parser, IR, type-checker, and pretty-printer
  are ALL complete. The prior "blocked on reader" claim was stale. See §7 of the
  implementation design for full layer-by-layer analysis.
- **Needed for**: Schema-typed IO, value-dependent protocols, length-indexed protocols,
  negotiated protocols, capability transfer
- **Blocked on**: Nothing — can be implemented immediately (no IO infrastructure dependency)
- **Implementation design**: `docs/tracking/2026-03-05_IO_IMPLEMENTATION_DESIGN.md` §7, Phase IO-J
- **Source**: `docs/tracking/2026-03-05_IO_LIBRARY_DESIGN_V2.md` §10, `docs/tracking/2026-03-03_SESSION_TYPE_DESIGN.md` §8

### IO Bridge Propagators (NOT STARTED — Phase IO-B)
- **Problem**: The double-boundary IO model (compile-time cap-check → IO bridge cell → IO
  propagator → external world) is designed but not implemented. Need `io-bridge-cell` type,
  side-effecting IO propagator, and wiring into `run-to-quiescence`.
- **Needed for**: Any actual IO operations (file, network, database)
- **Blocked on**: Nothing (builds on existing propagator + session infrastructure)
- **Implementation design**: `docs/tracking/2026-03-05_IO_IMPLEMENTATION_DESIGN.md` §5
- **Source**: `docs/tracking/2026-03-05_IO_LIBRARY_DESIGN_V2.md` §2, `docs/tracking/2026-03-03_SESSION_TYPE_DESIGN.md` §12.5

### Boundary Operations: `open`/`connect`/`listen` (NOT STARTED — Phase IO-C / IO-J)
- **Problem**: Capability-gated channel creation for external resources is designed
  (Session Type Design §12.4) but not implemented. These operations create channel
  endpoints to external resources (files, network, databases).
- **Needed for**: Any external IO beyond stdin/stdout
- **Blocked on**: IO bridge propagators (above)
- **Note**: `proc-open` (file) is Phase IO-C; `proc-connect`/`proc-listen` (network) deferred to IO-J
- **Implementation design**: `docs/tracking/2026-03-05_IO_IMPLEMENTATION_DESIGN.md` §6
- **Source**: `docs/tracking/2026-03-05_IO_LIBRARY_DESIGN_V2.md` §6, `docs/tracking/2026-03-03_SESSION_TYPE_DESIGN.md` §12.4

### Opaque Type Marshalling (NOT STARTED — Phase IO-A1)
- **Problem**: `foreign.rkt` handles Nat/Int/Bool/String/Char but not opaque Racket values
  (file ports, database connections). Need `expr-opaque` wrapper struct + tagged pass-through
  marshalling.
- **Needed for**: File handles, database connections, network sockets via FFI
- **Blocked on**: Nothing (foreign.rkt extension)
- **Implementation design**: `docs/tracking/2026-03-05_IO_IMPLEMENTATION_DESIGN.md` §4
- **Source**: `docs/tracking/2026-03-05_IO_LIBRARY_DESIGN_V2.md` §10, `docs/tracking/2026-03-01_1200_IO_LIBRARY_DESIGN.md` §6.1

### `Path` Type (NOT STARTED — Phase IO-A2)
- **Problem**: No cross-platform file path abstraction. Decision: String wrapper initially.
- **Pure operations**: join, parent, file-name, extension, with-extension, absolute?, relative?
- **Blocked on**: Nothing (straightforward String wrapper)
- **Implementation design**: `docs/tracking/2026-03-05_IO_IMPLEMENTATION_DESIGN.md` §8
- **Source**: `docs/tracking/2026-03-05_IO_LIBRARY_DESIGN_V2.md` §9

### `Bytes` Type (NOT STARTED — Deferred to Phase 2)
- **Problem**: No binary data type. Not needed for text IO (Phase 1) but needed for binary
  IO, SQLite FFI, and network protocols.
- **Blocked on**: Nothing, but lower priority than text IO
- **Source**: `docs/tracking/2026-03-05_IO_LIBRARY_DESIGN_V2.md` §12.3

### ~~Capability Inference Pipeline Integration (Phase IO-H)~~ COMPLETE ✅
- Automatic `run-post-compilation-inference!` after `process-string`/`process-string-ws`/`load-module`
- Underdeclared authority roots → hard error E2004 (not warning — security violation)
- `current-module-cap-result` parameter stores inference result
- Commit: `3a72975`, `84a8d83`

### ~~Dependent Capabilities (Phase IO-I)~~ COMPLETE ✅
- `cap-entry` struct (name + optional index-expr), `cap-set` migrated to `set` of `cap-entry`
- `extract-capability-requirements` handles `expr-app` (applied caps like `[FileCap "/data"]`)
- α/γ bridge updated for applied caps; REPL commands display applied cap syntax
- Covers Phases 7e and 7f from capabilities roadmap
- Commit: `5c9eb93`

### ~~CSV Parsing (Phase IO-G)~~ COMPLETE ✅
- RFC 4180 CSV parser in `io-ffi.rkt` with RS/US serialization
- `csv.prologos` module: `parse-csv`, `csv-to-string`, `read-csv`, `write-csv`
- 28 tests (20 Racket-side + 8 E2E)
- Commit: `7d621e8`

### CSV Maps — `parse-csv-maps` (Deferred)
- **Problem**: `parse-csv` returns `List [List String]`. A header-aware variant
  `parse-csv-maps : String -> List [Map String String]` would be more ergonomic
  for structured data (treats first row as header, returns list of maps).
- **Blocked on**: Map construction from key-value pair lists. Currently no
  `map-from-pairs : List [Pair K V] -> Map K V` function. Requires either a new
  FFI helper or Prologos-side fold over pairs.
- **Priority**: Low — `parse-csv` + manual header indexing works for all use cases
- **Source**: IO-G plan in `buzzing-launching-pascal.md`

---

## Effectful Computation on Propagators

### ~~Phase 1: Formalize Stratified Effect Barriers~~ COMPLETE ✅
- Three-stratum architecture documented in the effectful propagators research:
  Stratum 1 (pre-execution verification, monotone), Stratum 2 (effect execution,
  non-monotone sequential walk), Stratum 3 (post-execution verification, monotone)
- Correctness argument: session type order = AST structure = walk order = effect order
- Documented where Architecture A breaks down (multi-channel concurrent processes)
- Commit: `bc34e44`
- Source: `docs/tracking/2026-03-06_EFFECTFUL_PROPAGATORS_RESEARCH.md` §8
- Principles: `docs/tracking/principles/EFFECTFUL_COMPUTATION_ON_PROPAGATORS.org`

### Phase 2: Architecture A+D — Propagator-Native Effectful IO (NOT STARTED)
- **Problem**: Architecture A (walk-based barriers) doesn't support concurrent
  multi-channel processes — walk visits channels sequentially, but some effects
  should be concurrent
- **Solution**: Architecture D — session types as causal clocks, effect ordering
  derived via Galois connection (α, γ) between session lattice and effect position lattice
- **Architecture Decision**: A + D (D for session-typed IO, A for unsessioned IO/REPL)
- **Implementation Design**: `docs/tracking/2026-03-07_ARCHITECTURE_AD_IMPLEMENTATION_DESIGN.org`
- **Sub-phases** (16 sub-phases across 6 phases):
  - AD-A: Effect Position Lattice — `effect-position.rkt` (NOT STARTED)
  - AD-B: Session-Effect Bridge Propagator — `effect-bridge.rkt` (NOT STARTED)
  - AD-C: Effect Collection During Compilation — `session-runtime.rkt` modification (NOT STARTED)
  - AD-D: Ordering Analysis — data-flow edges + transitive closure in `effect-ordering.rkt` (NOT STARTED)
  - AD-E: Effect Handler (Layer 5) — `effect-executor.rkt` + `rt-execute-process-d` (NOT STARTED)
  - AD-F: ATMS Integration + Migration — architecture selection, concurrent hooks (NOT STARTED)
- **Not blocked**: All phases buildable without concurrent runtime (S8b)
- **Estimated**: ~720 new lines, ~178 new tests, 4 new modules
- **Source**: `docs/tracking/2026-03-06_SESSION_TYPES_AS_EFFECT_ORDERING.org`,
  `docs/tracking/principles/EFFECTFUL_COMPUTATION_ON_PROPAGATORS.org`

### Phase 3: Full Reactive Effect Integration (RESEARCH — NOT STARTED)
- Architecture C — topological scheduling of effect propagators with freeze semantics
- Would handle declarative effect specifications outside session contexts
- Research problem, not engineering task
- **Blocked on**: Phase 2 completion, research prototype
- **Source**: `docs/tracking/2026-03-06_EFFECTFUL_PROPAGATORS_RESEARCH.md` §5c

---

## Session Types — Parameterized/Indexed Sessions & Bounded Liveness

### Parameterized (Indexed) Session Types (RESEARCH — NOT STARTED)
- **Problem**: Multiplexed protocols (like CapTP) run N concurrent sub-sessions
  over a single connection, each tracked by an index (e.g., `questionID`). Current
  session types can model the data dependency (dependent `!:`/`?:` binding) but not
  the concurrent multiplexing structure — dependent sessions are sequential.
- **Goal**: Session type definitions parameterized by a value from the dependent type
  level. A multiplexed connection holds a family `{S(i) | i ∈ active}` of concurrent
  sub-sessions.
- **Approaches investigated** (from Endo analysis, 2026-03-07):
  1. *Encoding via `par`* — dynamic channel creation (`proc-new`/`proc-par`) can model
     each sub-session as its own channel. Works structurally but differs from the runtime
     model (single-connection multiplexing vs. separate channels).
  2. *Parameterized session types* — `session-family S [i : I] = ...` where `S` is
     indexed by a value. Requires extending session type definitions to accept type-level
     parameters. Natural fit given existing dependent type infrastructure.
  3. *Session maps* — `Map QuestionId (Session S qid)` tracking active sub-sessions.
     Combines (2) with collection types for the multiplexed container.
- **Observation**: This is the same extension needed for fuel-indexed bounded liveness
  (below). Both are instances of "session types indexed by dependent type values."
- **Literature**: Katsumata (Parametric Effect Monads, POPL 2014), Atkey (Parameterised
  Notions of Computation, JFP 2009), Gay & Hole (Subtyping for Session Types)
- **Not blocked**: Dependent type infrastructure exists. Design work needed.
- **Source**: `docs/research/2026-03-07_ENDO_AS_SESSION_TYPES.org` §4.3, §15

### Bounded Liveness for Session Types (RESEARCH — NOT STARTED)
- **Problem**: Session types verify *safety* (bad things don't happen) but not *liveness*
  (good things eventually happen). Example: a transient pin protocol has no guarantee
  that `Unpin` is ever reached — a crash between pin and unpin leaks the pin.
- **Current capabilities** (what we have today):
  - Linear types (`[1]`) prevent resource leaks within a single function scope — if you
    hold a linear pin token, you MUST consume it on every code path
  - `check-session-completeness` verifies sessions reach `end` when the process terminates
  - These are *weak* liveness: "if you terminate, you must be at end"
- **Graduated roadmap** (increasing levels of guarantee):
  1. **Today**: Linear types + session completeness (described above)
  2. **Near-term** (small extension): Timeout branches in session types — a `timeout`
     choice taken if normal protocol doesn't progress. Syntactic sugar for a choice with
     an implicit clock. Session type checker verifies timeout branch properly cleans up
     resources (releases linear tokens).
  3. **Medium-term** (parameterized sessions): Fuel-indexed recursive sessions where
     termination falls out of well-founded recursion on a decreasing `Nat` parameter.
     Requires indexed/parameterized session types (above).
  4. **Long-term** (timed session types): Full clock constraints à la Bocchi, Honda &
     Tuosto (2014). Each message step has a deadline; type checker verifies all deadlines
     are satisfiable. Bigger research investment.
- **Key insight**: Options 2-3 converge on parameterized session types — timeout branches
  need clock parameters, fuel indexing needs Nat parameters. Both are specializations
  of the parameterized session type extension above.
- **Literature**: Bocchi, Honda & Tuosto (Timed Multiparty Session Types, 2014), Neykova &
  Yoshida (Session Types with Explicit Timeouts, 2017), Barbanera & de'Liguoro (Session
  Types with Retries, 2015)
- **Not blocked**: Design and research needed, but foundational infrastructure exists
- **Source**: `docs/research/2026-03-07_ENDO_AS_SESSION_TYPES.org` §5.4, §15.2

---

## Infrastructure / Performance

### Compiled Module Cache
- Persistent compilation cache in `driver.rkt` keyed by module path + source hash
- Would benefit all test files
- Source: `docs/tracking/2026-02-19_PIPE_COMPOSE_AUDIT.md`

### Bytecode Compilation
- Compile `.prologos` to intermediate format, skip parse/elaborate/type-check
- Major investment, deferred until language stabilizes
- Source: `docs/tracking/2026-02-19_PIPE_COMPOSE_AUDIT.md`

---

## Surface Syntax Issues (Uncovered 2026-03-08)

### WS-Mode `:=` Body Parsing with Multi-Form Bodies
- `def x : List Nat := cons 1N [cons 2N nil]` fails in WS mode
- Root cause: `expand-def-assign` in macros.rkt (line 3466) requires exactly
  one form after `:=`. But the WS reader produces multiple inline elements:
  `cons`, `($nat-literal 1)`, `[cons 2N nil]` — three separate forms
- Fix: when multiple elements exist after `:=`, wrap them as implicit application
- Workaround: use quote-list syntax `'[1N 2N 3N]` instead of cons chains
- **Not blocked**: straightforward fix in `expand-def-assign`
- Source: `examples/unified-matching.prologos` Section 5

### Multi-Bracket defn Not Supported
- `defn f [a] [b] body` and `defn f [a : T] [b : T] body` don't work
- Neither sexp nor WS mode — pre-existing limitation, not caused by unified matching
- Standard pattern is uncurried single-bracket: `defn f [a b] body`
- Affects both regular defn and params+arms defn syntax
- **Not blocked**: requires parser extension for multi-bracket param groups
- Source: `examples/unified-matching.prologos` Section 11

## LSP / Editor Support

### Token-level srcloc precision for diagnostics
- Unbound variable errors point to the enclosing `defn` (line 16) instead of the exact token (line 19)
- Root cause: WS reader/parser assigns definition-level srcloc to body tokens
- **Blocked on**: full propagator integration (cell-per-node architecture gives precise provenance by construction)
- Workaround: diagnostics currently point to the definition, which is correct but imprecise
- Source: LSP Tier 2 integration testing, commit `712c45a`

### Cross-module go-to-definition
- Go-to-definition only works for symbols defined in the current file
- Prelude/imported symbols (e.g., `mult`, `map`) don't resolve
- **Blocked on**: cross-module location tracking in module registry
- Source: LSP Tier 2, commit `12ea616`

## QTT / Multiplicity

### QTT multiplicity violation with generic trait-constrained functions in defn bodies
- Any `defn` whose body uses generic `map`, `filter`, or `reduce` (from `prologos::core::collections`) fails QTT checking
- Root cause: generic collection functions carry erased (`:0`) trait dictionary params (`List--Seqable--dict`, `List--Buildable--dict`); when the defn body gets wrapped in a lambda, QTT flags the captured dicts as a multiplicity violation
- Non-generic list-specific `map` from `prologos::data::list` works fine in defn bodies (no trait dicts)
- Standalone expressions (not inside defn) work fine — QTT only runs on defn bodies
- **Blocked on**: either QTT rework for dict-param handling, or propagator integration
- Workaround: use list-specific functions via explicit `(imports (prologos::data::list :refer [map]))`, or keep expressions standalone
- Source: LSP Tier 4 testing, foray-min.prologos

## Arithmetic / Operator Dispatch

### `+` `-` `*` `/` should work as higher-order generic functions
- Currently parser keywords — desugar directly to `expr-generic-add` etc. at parse time
- Require exactly 2 arguments; can't be passed to `map`, `reduce`, or use `_` placeholders
- `[+ 1 _]` fails because `_` desugaring fires on `surf-app` but `+` produces `surf-generic-add`
- Want: `map [+ 1 _] '[1 2 3]` and `reduce + 0 '[1 2 3]` to work
- First-class wrappers (`plus`, `minus`, `times`, `divide`) exist as workarounds
- **Design question**: make `+` etc. resolve to first-class functions in HO position, or teach placeholder desugaring to handle parser keyword nodes?
- Source: LSP Tier 4 testing, foray-min.prologos

### Trait-constrained functions can't be passed bare to higher-order functions
- `reduce plus 0 '[1 2 3 4 5]` fails: "Could not infer type"
- `plus` has type `{A} -> Add A -> A -> A -> A`; when passed bare to `reduce` (which expects `B -> A -> B`), the elaborator can't match due to the implicit dict parameter
- Elaborator doesn't auto-insert dictionary args when a trait-constrained function is in HO argument position
- Workaround: wrap in explicit lambda: `reduce (fn [a : Int] [b : Int] [+ a b]) 0 xs`, or use `sum`/`product`
- **Blocked on**: elaborator enhancement for automatic eta-expansion + dictionary insertion in HO position
- Source: LSP Tier 4 testing, foray-min.prologos

## Propagator Observatory — Visualization Polish

### 5d: Bookmarked Rounds
- Allow user to bookmark specific BSP rounds for comparison
- Lightweight feature — each round's snapshot is already retained (O(1) pointer)
- Source: `2026-03-12_PROPAGATOR_VISUALIZATION_DESIGN.md` Phase 5d

### 6a-6d: Polish and Integration
- 6a: Performance tuning for large networks (force-directed layout optimization)
- 6b: SVG/PNG export of propagator graphs
- 6c: Contradiction diagnosis view (ATMS nogoods visualization)
- 6d: Documentation + user guide for the Observatory panel
- Source: `2026-03-12_PROPAGATOR_VISUALIZATION_DESIGN.md` Phases 6a-6d

## Propagator Taxonomy — Extended Research

### Richer Taxonomy Beyond Track 7 Foundation
Track 7 (§2.6) establishes a granular taxonomy of propagator patterns:
- **Structural**: transform, fan-in, fan-out, bridge
- **Lifecycle**: value cell, accumulator cell, channel cell, shadow cell
- **Scheduling**: stratum propagator, threshold propagator

A richer taxonomy should research and design:
- **Temporal propagators**: fire after a delay or on a schedule (reactive/streaming use cases)
- **Higher-order propagators**: propagators that create/remove other propagators (meta-propagation)
- **Distributed propagators**: cross-process/cross-node with eventual consistency semantics (runtime)
- **Adaptive propagators**: adjust their behavior based on network state (optimization)
- **Observational propagators**: read-only, for instrumentation/debugging (Observatory integration)

This research informs the distributed/concurrent runtime design and the LSP integration.
- Source: `2026-03-18_TRACK7_PERSISTENT_CELLS_STRATIFIED_RETRACTION.md` §2.6, §13 Q6
- Blocked on: Track 7 implementation (establishes the foundation taxonomy)
- Added: 2026-03-18

---

## Relational/Unification — PUnify Surface Gaps

Discovered during PUnify Phase 0a acceptance testing (2026-03-19). These are
deeper issues that prevent certain composition points from working. Each item
is commented out in `examples/2026-03-19-punify-acceptance.prologos`.

### ~~`defr` with `|` clause-form doesn't register relations~~ — RESOLVED (commit `490a4e3`)
- Root cause was `parse-rel-params` rejecting non-symbol elements (literals) in param lists.
  `defr |` with all-variable params always worked; only literal patterns (ints, strings, bools) failed.
- Fix: `parse-rel-params` now accepts literals as `(#:literal . value)` tags; `elaborate-defr-variant`
  desugars them to fresh logic vars + implicit `=` goals. Acceptance file §B6 now passes.

### Module-path (`::`) resolution in defr clauses
- `str::concat` (and likely other `ns::fn` references) unbound inside `defr` clause bodies when used in `is` goals
- Root cause: `::` module-path lookup doesn't resolve in the relational elaboration context — the relational fallback path in `elaborate-var` doesn't search module registries
- Affects: `is` goals in `defr` that call module-qualified functions
- Workaround: use prelude-exported names (e.g., `concat` if available) instead of `ns::fn` paths
- Source: acceptance file §H4, §K2
- Added: 2026-03-19

### solve-one type inference in defn body
- `solve-one` used inside a `defn` body (functional context) returns `_` type, causing downstream type inference failures
- `solve` works in the same position — only `solve-one` affected
- Root cause: `solve-one` returns `<Option Map>` but the elaborator doesn't propagate this type through `def` binding inference
- Workaround: use `solve` and take the first result, or use explicit type annotation
- Source: acceptance file §J (commented tests)
- Added: 2026-03-19

### `=` with prelude constructors in defr body
- Using prelude constructors (some/none) in `=` unification goals inside `defr` clause bodies fails — constructor names collide or don't resolve correctly in the solver's flat representation
- Root cause: prelude constructor names need the same keyword-based ground representation in the solver that goal-app names now use
- Workaround: works in standalone `solve` blocks (§L passes), fails only inside `defr`
- Source: acceptance file §K (commented tests)
- Added: 2026-03-19

### Parameterized types in data constructor arguments
- `data Box A := box [List A]` fails with not-a-type-error — the type checker doesn't recognize `[List A]` as a valid type when `A` is a type parameter in constructor position
- Root cause: constructor argument elaboration doesn't fully expand parameterized type applications
- Workaround: use a simple type parameter (`data Box A := box A`) and instantiate at use site
- Source: acceptance file §G (Graph type simplified)
- Added: 2026-03-19

### `eq?` trait method not in prelude scope
- The `Eq` trait's `eq?` method isn't directly callable from prelude — only `int-eq`, `str-eq`, etc. are available
- Root cause: trait method dispatch for `eq?` requires explicit trait resolution that isn't wired through the prelude auto-import
- Workaround: use concrete equality functions (`int-eq`, `str-eq`, `nat-eq`)
- Source: acceptance file §M (stress tests)
- Added: 2026-03-19

### head + match inference failure
- `[head '[1 2 3]]` followed by pattern match on the result fails type inference — `head` returns `<Option A>` but the polymorphic `A` doesn't unify with the list element type in the match context
- Pre-existing issue, not introduced by PUnify
- Workaround: explicit type annotation on the `head` call result
- Source: acceptance file §G6
- Added: 2026-03-19

### Narrowing limited to constructor-based patterns
- Functions defined with Int literal patterns (e.g., `defn classify | 0 -> "zero" | _ -> "nonzero"`) compile to `boolrec+int-eq` form, which `extract-definitional-tree` cannot invert for narrowing
- This is a design limitation: narrowing via definitional trees requires constructor-based pattern matching (Bool, Nat, user-defined ADTs)
- Not a bug — but should be documented as a known limitation in narrowing documentation
- Source: acceptance file §I (narrowing tests use Bool/Nat patterns only)
- Added: 2026-03-19
