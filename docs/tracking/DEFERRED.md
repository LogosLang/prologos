# Deferred Work

Single source of truth for all deferred work across the Prologos project.
Items are organized by topic. When work is deferred during implementation,
add an entry here immediately.

**Principle**: Completeness over deferral. Items here should be genuinely
blocked on unbuilt infrastructure or uncertain design — not effort avoidance.
See `docs/tracking/principles/DEVELOPMENT_LESSONS.org` § "Completeness Over
Deferral".

**Last consolidated sweep**: 2026-02-27 (Nil type + safe navigation complete; Dot-Access Phase D + A? nilable sugar complete. Type inference Phases 8+A-E complete. Config language hardening Tier 1+2 complete).

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

### Capabilities — Phase 8d: Multi-Agent Cross-Network Reasoning
- Separate agents on separate propagator networks cross-referencing via
  cross-network propagators, with dependent-typed proof objects as provenance
- Machine-checkable justification chains across network boundaries
- **Blocked on**: session type design (Phase 9), dependent capabilities (Phase 7)
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
- **Deferred**:
  - Phase E3: Constraint-retry propagators — move full constraint retry into fire functions (side-effectful propagators, re-entrancy risk). Current E2 legacy retry path covers this safely.
- Source: `docs/tracking/2026-02-25_TYPE_INFERENCE_ON_LOGIC_ENGINE_DESIGN.md`

---

## Homoiconicity

### Phase IV: Runtime Eval & Read
- Runtime `eval` — evaluate quoted expressions; requires embedding compiler
- Runtime `read` — parse string to Prologos datum; requires exposing reader
- `unquote-splicing` (`,@`) — only single-element unquote is implemented
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

## Infrastructure / Performance

### Compiled Module Cache
- Persistent compilation cache in `driver.rkt` keyed by module path + source hash
- Would benefit all test files
- Source: `docs/tracking/2026-02-19_PIPE_COMPOSE_AUDIT.md`

### Bytecode Compilation
- Compile `.prologos` to intermediate format, skip parse/elaborate/type-check
- Major investment, deferred until language stabilizes
- Source: `docs/tracking/2026-02-19_PIPE_COMPOSE_AUDIT.md`
