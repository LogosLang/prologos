# Deferred Work — Completed Archive

Items moved from `DEFERRED.md` during the 2026-03-20 staleness sweep.
These are deferred items that have been fully implemented. Kept for
historical reference and traceability.

---

## Numerics Tower — Ergonomics (MOSTLY COMPLETE)

- ✅ Posit identity instances (AdditiveIdentity/MultiplicativeIdentity for Posit8-64) — `identity-instances.prologos`
- ✅ Posit equality primitives `p{N}-eq` — `test-posit-eq.rkt`
- ✅ Bare decimal `3.14` → Posit32 — `test-decimal-literal.rkt`
- ✅ Generic operators `+` `-` `*` `/` `<` `<=` `=` as parser keywords → trait dispatch — `test-generic-arith-01/02.rkt`
- ✅ Context-resolved `from-int` / `from-rat` keywords — `test-generic-from.rkt`, `test-cross-family-conversions-*.rkt`
- ✅ Generic `negate` and `abs` surface operators — `test-generic-arith-02.rkt`
- ✅ Numeric type join (`numeric-join`) for Posit dominance coercion — `test-numeric-join.rkt`
- ✅ Implicit coercion warnings (exact → approximate) — `test-coercion-warnings.rkt`
- Source: `docs/tracking/2026-02-22_NUMERICS_ERGONOMICS_AUDIT.org`
- **Remaining (still in DEFERRED.md)**: Numeric literal polymorphism (`42` polymorphic via `FromInt`) — research/future

---

## Numerics — Peano Nat Efficiency — DONE

### Replace Peano Nat with Native Representation (commits `f17c522`, `c2ad2b5`, `5ef9fed`)
- **Implemented**: Option 3 (Idris 2 approach) — Peano surface syntax preserved, native `expr-nat-val` at runtime
- `nat->expr`, `nat-value`, elaboration, whnf, nf, pattern matching, unification all use O(1) `expr-nat-val`
- 14 pipeline files updated, 17 test files updated, 5005 tests pass

---

## Collections — Ergonomics (Stages A-H COMPLETE)

Generic collection functions (`map`, `filter`, `reduce`, `length`, `into`, `head`, `empty?`, etc.)
work on all collection types via auto-resolved trait dicts. 8 native AST primitives, prelude shadowing,
29 new tests in `test-collection-fns.rkt`. 3605 tests pass.

---

## Syntax — Dot-Access (Phases A-D COMPLETE)

### Phases A-C: Single + Nested Access ✅
- `user.name` → `(map-get user :name)`
- `user.address.city` → `(map-get (map-get user :address) :city)`
- Reader splits each `.field` into separate `dot-access` tokens; preparse `rewrite-dot-access` left-folds into nested `map-get`
- E2E tests pass for both sexp and WS mode (see `test-dot-access.rkt`)

### Phase D: Nil-Safe Navigation `#.`/`#:` ✅
- `Nil` type + overloaded `nil` value (list-nil and Nil-nil, disambiguated by type inference)
- `nil-safe-get` keyword: `(Map K V | Nil) → K → (V | Nil)`, returns `nil` on missing key
- `#.field` / `#:key` WS-mode syntax via reader sentinel + preparse rewrite
- `nil?` predicate: `A → Bool`
- Mixed access chains: `user#.address.city`, `user.address#.city`
- 38 tests in `test-nil-type.rkt`, 4583 tests pass
- Source: plan `buzzing-launching-pascal.md`

---

## `A?` Nilable Union Syntax — COMPLETE ✅

- `String?` → `(String | Nil)` parser-level sugar for known uppercase type names ending with `?`
- Implemented in Dot-Access Phase D

---

## Schema + Selection (All Phases COMPLETE)

### Phases 1-3b ✅
- Schema: field registry, named type, typed construction, typed field access
- Selection: parsing, registry, elaboration, field-gating, structured paths
- Deep paths: `:address.zip` parsing, wildcards (`*`/`**`), brace expansion
- Deep validation: nested schema field validation in elaborator
- Source: `docs/tracking/2026-03-02_2200_SCHEMA_SELECTION_DESIGN.md`

### Phase 3c: Nested Field-Gating for Deep Paths
- Lazy sub-selection synthesis: accessing `:address` on `AddrZip` (requires `:address.zip`)
  returns synthetic sub-selection type restricting access to only `:zip`
- Sub-selections are normal `selection-entry` structs cached under deterministic names
  (e.g., `AddrZip/address`) in the existing selection registry
- Recursive nesting for 3+ levels, bare paths and wildcards return full schema (unrestricted)
- 4 helpers: `selection-sub-name`, `extract-path-suffixes`, `selection-field-unrestricted?`, `selection-field-type`
- 9 new tests (31-39), 2 existing tests updated
- Commit: `9435568`

### Phase 4: Selection Composition
- `:includes [A B]` set-union with `path-union` join semantics (wildcards subsume specifics)
- Cross-schema includes and unknown selection references produce clear errors
- `User * MovieTimesReq` Sigma operator in type positions — DEFERRED (requires parser changes)
- Commit: `fa288eb`

### Phase 5: Schema Properties — Parsing + Storage
- `:closed` rejects extra keys at construction time
- `:default val` stored in `schema-field-default-val`
- `:check [pred]` stored in `schema-field-check-pred`
- Commit: `e27a3f8`

### Phase 5 Runtime: Default Fill + Check Assertion
- Phase 5a: `expr-panic` AST node — general-purpose abort, types as `∀A. String → A` (commit `ea4ea9f`)
- Phase 5b: `:default` preparse injection — auto-fills missing fields at schema construction (commit `8dfd645`)
- Phase 5c: `:check` runtime wrapping — emits `if/panic` assertions on field values at construction (commit `a4d993f`)
- 14 new tests (17-30) in `test-schema-properties.rkt`; 4963 tests pass across 246 files

### Phase 3d: Selection Path Extension
- Brace items as sub-paths: `:a.{b.c d.e}` branches navigate independently (commit `1d342a9`)
- Nested braces: `:a.{b.{c d} e}` recursive expansion (commit `b288922`)
- Post-brace continuation: `:a.{b c}.**` suffix appends to all branches (commit `91528fe`)
- Cons-dot normalization: `.{...}` at tail position in brackets (commit `5b4d4dc`)
- E2E pipeline tests with real schemas (commit `994d9fb`)
- 17 new tests (40-57) in `test-selection-paths.rkt`

### Phase 3e: General-Purpose Path Expressions
- `get-in`/`update-in` expressions use path algebra for data navigation/transformation
- AST + parsing: `surf-get-in`, `surf-update-in` parsed with `validate-selection-paths` (commit `32993ad`)
- Elaboration: pure desugaring to `map-get`/`map-assoc` chains — no downstream changes (commit `f5749c8`)
- Type checking: free from desugaring — existing `map-get`/`map-assoc` type rules apply
- 20 new tests in `test-path-expressions.rkt` (commit `93af4bc`)

---

## Spec System — Phase 1 Items (All COMPLETE)

### `??` Typed Holes — Phase 1
- Full 14-file pipeline implemented (reader → parser → elaborator → typing-core → pretty-print).
- Enhanced diagnostics: pretty-printed expected type, context bindings with synthetic names and multiplicities. 9 tests.
- Source: `docs/tracking/2026-02-24_EXTENDED_SPEC_HARDENING.md`

### `property` Keyword — Phase 1
- Parsing, storage, `:includes` flattening, `/`-qualified names,
  `spec-properties` and `trait-laws-flattened` accessors all working.
  WS-mode integration via `rewrite-implicit-map` property-specific branch.
  Standard library declarations in `algebraic-laws.prologos`.
  73 tests (61 sexp + 12 WS).
- Source: `docs/tracking/2026-02-24_PROPERTY_KEYWORD_HARDENING.md`

### `functor` Keyword — Phase 1
- Parsing, storage, deftype auto-registration all working.
  WS-mode integration fixed (rewrite-implicit-map applied at dispatch).
  Standard library declarations in `type-functors.prologos` (Xf, AppResult).
  11 tests (WS + sexp + stdlib).
- Source: `docs/tracking/2026-02-24_EXTENDED_SPEC_HARDENING.md`

### `:examples` Metadata — Phase 1
- Explicit parsing in `parse-spec-metadata`, `spec-examples` accessor.
  Multiple examples properly collected via `collect-constraint-values`.
  `spec-doc` accessor also added. 7 tests.
- Source: `docs/tracking/2026-02-24_EXTENDED_SPEC_HARDENING.md`

### `:deprecated` Warnings — Phase 1 (extended for traits/functors)
- `deprecation-warning` struct in warnings.rkt, emitted during
  type checking when `expr-fvar` references a spec with `:deprecated` metadata.
  Extended to also check traits and functors for deprecation (G7).
  Displayed after command processing. 6 + 39 tests (test-config-audit.rkt).
- Source: `docs/tracking/2026-02-24_EXTENDED_SPEC_HARDENING.md`,
  `docs/tracking/2026-02-27_2300_SPEC_FUNCTOR_AUDIT.md`

### Configuration Language Hardening — Tier 1+2
- Gaps G1-G9 and opportunities O4-O7/O11 from audit implemented.
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

---

## Implicit Inference (Both Directions COMPLETE)

### Auto-Introduce Unbound Type Variables ✅
- Direction 1: Capitalized `A` free in type signature → auto-introduce `{A : Type}`
- Implemented in `macros.rkt` (`collect-free-type-vars-from-datums`, `auto-detected-binders`)
- Filters known type names, user-defined constructors, traits, bundles, locally-bound Pi names
- 191+ passing tests in `test-auto-implicits.rkt`, real usage in `test-hkt-errors.rkt`
- Source: `docs/tracking/2026-02-22_IMPROVED_IMPLICIT_INFERENCE.org`

### Kind Inference from `:where` Clauses — Direction 2 ✅
- `propagate-kinds-from-constraints` refines kinds for explicit `{C}` binders
- Auto-detect free variables in `:where` via Direction 1 auto-implicits — COMPLETE
  - `collect-free-type-vars-from-datums` already scans constraint args (macros.rkt:1685)
  - Auto-detected binders feed into `propagate-kinds-from-constraints` (macros.rkt:1699-1702)
  - Direction 1 inadvertently closed the Direction 2 gap — no new code needed
- `C` in `:where (Seqable C)` without `{C}` → infers `{C : Type -> Type}` from trait decl
- 15 e2e tests in `test-kind-inference-where.rkt`
- Source: `docs/tracking/2026-02-22_IMPROVED_IMPLICIT_INFERENCE.org`

---

## Type System — HKT-8: Call-Site Rewriting — COMPLETE

- `rewrite-specializations` implemented in `driver.rkt`.
  Walks post-zonk expression tree, matches application chains headed by functions
  with where-constraints, strips implicit type + dict args, replaces with registered
  specialized name. Wired into eval, def (unannotated), and def (annotated) paths.
- `new-lattice-cell` has Bool and Interval specializations in `propagator.prologos`.
- Fast path: empty registry → zero overhead.
- Source: `driver.rkt` (rewrite-specializations), `lib/prologos/core/propagator.prologos`

---

## Logic Engine / Propagator Architecture (Phases 1-7 + Extensions COMPLETE)

### Phase 1: Lattice Trait + champ-insert-join
- `Lattice` trait: bot, join, leq
- Standard instances: FlatLattice, SetLattice, MapLattice, IntervalLattice, BoolLattice
- `champ-insert-join` Racket-level helper (in `champ.rkt`)
- `lib/prologos/core/lattice-trait.prologos` + `lattice-instances.prologos`
- Source: `docs/tracking/2026-02-24_LOGIC_ENGINE_DESIGN.org`

### Phase 2: Persistent PropNetwork — Racket-Level
- Persistent/immutable propagator network backed by CHAMP maps
- All structs `#:transparent` (not `#:mutable`) — pure functional operations
- CellId/PropId = Nat counters (deterministic, no gensym)
- `net-cell-write` does join-on-merge — LVars subsumed by cells
- `run-to-quiescence`: pure tail-recursive loop (BSP scheduler)
- Backtracking = keep old reference (O(1)). Snapshots = free.
- 3 files (`propagator.rkt`, tests), ~60 Racket-level tests
- Source: `docs/tracking/2026-02-24_LOGIC_ENGINE_DESIGN.org`

### Phase 3: PropNetwork as Prologos Type
- 14 AST nodes (3 type ctors, 3 runtime wrappers, 8 operations) across 12-file pipeline
- Type rules (`typing-core.rkt`, `qtt.rkt`), reduction (`reduction.rkt`), surface syntax
- HasTop trait + BoundedLattice bundle + trait instances
- Fix: parametric impl dispatch for compound type args without `where` (`macros.rkt`)
- 56 tests across `test-propagator-types.rkt` (32), `test-propagator-integration.rkt` (16), `test-propagator-lvar.rkt` (8)
- Source: `docs/tracking/2026-02-24_LOGIC_ENGINE_DESIGN.org`

### `new-lattice-cell` Generic Wrapper — COMPLETE
- `new-lattice-cell {A} PropNetwork -> [PropNetwork * CellId] where (Lattice A)`
- Resolved 2026-02-27: The "meta-resolution limitation" was a false alarm.
- Exported from prelude via `namespace.rkt`
- Source: `lib/prologos/core/propagator.prologos`

### Phase 4: UnionFind — Persistent Disjoint Sets
- Persistent union-find (Conchon & Filliâtre 2007) with path splitting
- 7 AST nodes through full 14-file pipeline
- `union-find.rkt` Racket module + surface syntax
- 57 tests (19 unit + 29 type-level + 9 integration)
- Source: `docs/tracking/2026-02-24_LOGIC_ENGINE_DESIGN.org`

### Phase 5: Persistent ATMS — Hypothetical Reasoning
- Persistent/immutable ATMS backed by hasheq maps
- Assumptions, supported values, nogoods — all persistent
- Worldview switching: `struct-copy atms ... [believed new-set]` — O(1)
- `amb` operator, dependency-directed backtracking, `solve-all`
- 14 AST nodes through full 14-file pipeline
- 74 tests (26 unit + 37 type-level/eval + 11 integration)
- Source: `docs/tracking/2026-02-24_LOGIC_ENGINE_DESIGN.org`

### Phase 6: Tabling — SLG-Style Memoization
- Tables as PropNetwork cells with list-based set-merge
- table-store wraps PropNetwork; backed by `hasheq`
- Answer modes: `all` (set-union) and `first` (freeze after one); `lattice f` deferred
- 10 AST nodes (1 type + 1 wrapper + 8 operations)
- 63 tests (20 unit + 31 type-level/eval + 12 integration)
- Source: `docs/tracking/2026-02-24_LOGIC_ENGINE_DESIGN.org`

### Phase 7: Surface Syntax — defr, rel, solve
- `defr` / `rel` keywords (named and anonymous relations)
- `&>` clause separator, `||` fact sentinel, `?var` logic variables
- `solve` / `solve-with` / `explain` / `explain-with` bridge to functional world
- Mode prefixes: `?` (free), `+` (input), `-` (output)
- 26 AST nodes through full 14-file pipeline
- Stratification module (Tarjan SCC + stratify)
- Provenance module (answer records + derivation trees)
- Grammar updates (EBNF §5.28 + prose)
- 140+ Phase 7-specific tests
- Completed: 2026-02-25

### Post-Phase 7: Stratified Evaluation ✅
- `stratified-eval.rkt` orchestration module bridging stratify + tabling + relations
- Dependency extraction, cached stratification (version-based invalidation)
- Single-stratum fast path (zero overhead for programs without negation)
- Multi-stratum bottom-up evaluation with stratum ordering for sound negation-as-failure
- Variable-carrying negation fix
- 17 new tests in `test-stratified-eval.rkt`, 199/199 suite pass
- Source: `docs/tracking/2026-02-26_STRATIFIED_EVALUATION.md`

### Post-Phase 7: Galois Connections + Domain Embeddings (Phase 6 COMPLETE)
- ✅ Phase 6a: `Widenable` trait + widening-aware fixpoint (`run-to-quiescence-widen`)
- ✅ Phase 6b: `GaloisConnection {C A}` trait + `impl GaloisConnection Interval Bool`
- ✅ Phase 6c: Cross-domain propagation (`net-add-cross-domain-propagator`)
- ✅ Phase 6d: Sign + Parity abstract domain library modules
- ✅ Phase 6e: Call-site specialization for `new-widenable-cell`, grammar docs, integration tests
- ✅ Phase 6f: `sign-galois.prologos` — `impl GaloisConnection Interval Sign`
- Source: `docs/tracking/2026-02-27_1026_GALOIS_CONNECTIONS_ABSTRACT_INTERPRETATION.md`

### Capabilities — Phase 7e-7f: Dependent Capability Extensions ✅
- **7e**: `cap-entry` struct + `cap-set` migration — commit `5c9eb93` (IO-I)
- **7f**: cap-type-bridge α/γ for `expr-app` caps — commit `5c9eb93` (IO-I)
- Context: Phases 7a-7d complete (commit `0a75942`), 7e-7f complete via IO-I
- Source: `docs/tracking/2026-03-01_1500_CAPABILITIES_AS_TYPES_DESIGN.md` §Phase 7

### Elaborator Propagator Refactoring — Phases 8+A-E COMPLETE
- ✅ Phase 8: Propagator network as primary type inference engine (56-62% speedup)
- ✅ Phase A: CHAMP meta-info store, eliminated hash dual-writes in production
- ✅ Phase B: Level/mult/session metas migrated to CHAMP with O(1) save/restore
- ✅ Phase C: Incremental trait resolution via wakeup callbacks
- ✅ Phase D1-D4: ATMS threaded through speculation, support sets, derivation chains
- ✅ Hash removal: CHAMP is sole source of truth; legacy hash paths removed
- ✅ Phase E1-E3: Meta-aware pure unification, propagator-driven constraint wakeup, constraint-retry propagators
- Source: `docs/tracking/2026-02-25_TYPE_INFERENCE_ON_LOGIC_ENGINE_DESIGN.md`

---

## Effectful Computation on Propagators — Phase 1 COMPLETE ✅

- Three-stratum architecture documented in the effectful propagators research:
  Stratum 1 (pre-execution verification, monotone), Stratum 2 (effect execution,
  non-monotone sequential walk), Stratum 3 (post-execution verification, monotone)
- Correctness argument: session type order = AST structure = walk order = effect order
- Documented where Architecture A breaks down (multi-channel concurrent processes)
- Commit: `bc34e44`
- Source: `docs/tracking/2026-03-06_EFFECTFUL_PROPAGATORS_RESEARCH.md` §8
- Principles: `docs/tracking/principles/EFFECTFUL_COMPUTATION_ON_PROPAGATORS.org`

---

## IO Library — Completed Phases

### Capability Inference Pipeline Integration (Phase IO-H) ✅
- Automatic `run-post-compilation-inference!` after `process-string`/`process-string-ws`/`load-module`
- Underdeclared authority roots → hard error E2004 (not warning — security violation)
- `current-module-cap-result` parameter stores inference result
- Commit: `3a72975`, `84a8d83`

### Dependent Capabilities (Phase IO-I) ✅
- `cap-entry` struct (name + optional index-expr), `cap-set` migrated to `set` of `cap-entry`
- `extract-capability-requirements` handles `expr-app` (applied caps like `[FileCap "/data"]`)
- α/γ bridge updated for applied caps; REPL commands display applied cap syntax
- Commit: `5c9eb93`

### CSV Parsing (Phase IO-G) ✅
- RFC 4180 CSV parser in `io-ffi.rkt` with RS/US serialization
- `csv.prologos` module: `parse-csv`, `csv-to-string`, `read-csv`, `write-csv`
- 28 tests (20 Racket-side + 8 E2E)
- Commit: `7d621e8`

---

## Propagator-First Phase 3d: Full current-global-env Rename — COMPLETE

- Completed in Track 6 Phase 9 (commit `36588ee`)
- 994 occurrences across 271 files renamed `current-global-env` → `current-prelude-env`
- Removed identity rename-out alias; `current-prelude-env` is now sole canonical name
- Zero remaining references in .rkt files

---

## FL Narrowing — Resolved Runtime Gaps

### `defr` with `|` clause-form — RESOLVED (commit `490a4e3`)
- Root cause was `parse-rel-params` rejecting non-symbol elements (literals) in param lists.
- Fix: `parse-rel-params` now accepts literals as `(#:literal . value)` tags; `elaborate-defr-variant`
  desugars them to fresh logic vars + implicit `=` goals.

### Pre-Existing Relational Runtime Gaps — RESOLVED
- ~~`is`-goals don't evaluate functional expressions~~ — RESOLVED (commit `df65974`)
- ~~`guard` not in parser keyword list~~ — RESOLVED (commit `a863f20`)
- ~~`cut` not in parser keyword list~~ — RESOLVED (commit `a863f20`)
- ~~Anonymous `rel` + `solve` integration~~ — RESOLVED (commit `14c3d2b`)
- ~~Trait dispatch in relational `is`-goals and `guard` conditions~~ — RESOLVED (commit `78f978e`)
