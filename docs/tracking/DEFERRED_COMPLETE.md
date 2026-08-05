# Deferred Work — Completed Archive

Items moved from `DEFERRED.md` during staleness sweeps. These are deferred
items that have been fully implemented. Kept for historical reference and
traceability.

**Sweeps**: 2026-03-20 (initial) · 2026-08-05 (36 entries — the file had gone
four months without one, so `DEFERRED.md` had accumulated 37 `✅`-headed
entries, a third of its 107, and had grown to 7937 lines. Three `✅` entries
were deliberately LEFT in `DEFERRED.md` because they carry live residue their
header does not advertise; see the note below.)

Two entries moved as pairs with their `(original)` filing, so the historical
framing sits beside the resolution that corrected it.

**Left behind on purpose in the 2026-08-05 sweep** — `✅`-headed but not done:

| entry | what is still open |
|---|---|
| `✅ CLOSED ccf7adb0` — `(when C (parse-error …))` discards a diagnostic | the structural half: `parse-error` returning rather than raising |
| `✅ CLOSED c38f175a` — `def X :=` + multi-key layout body | a second defect found while testing it, unrelated and unfixed |
| `✅ RESOLVED bb45d2a0` — the acceptance file is gated | its own header says PARTIAL: `test-rel-t1-pol.rkt` is Level-2 throughout |

That a `✅` header can hide open work is the reason this sweep read every
entry's body rather than filtering on the header.

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

---

## Mixed-Type Maps — Resolved

### Type Narrowing for `map-get` — RESOLVED by CIU T6 F1a structural records (2026-07-16 triage)
- "When key is statically known, narrow return type" is delivered by structural row typing:
  keyword-literal maps mint rows, so `{:a 1 :b "x"}.a : Int` (CIU T6 F1a-core, commit `589fb067`);
  mixed-key literals type `(Map K ⋃observed)` (D18, commit `6a2bc9d5`).
- Annotated `(Map K <union>)` dictionaries deliberately keep the uniform V (D18: "dictionaries
  stay honest") — per-key narrowing is the ROW path, by design, not a pending Map feature.
- Source: `docs/tracking/2026-02-22_MIXED_TYPE_MAPS.md`; triaged out of DEFERRED.md at the
  CIU T6 F1b opening per workflow.md § "DEFERRED.md triage at track start".

---

## ✅ WITHDRAWN, with a correction — "the `:=` let chain is BROKEN in UNSPECCED defns" was issue #70 in a let costume (filed 2026-07-31, corrected same day at LET P2 `e8a41a9a`)

**The filing was WRONG and is withdrawn.** Its repro used `[+ a [+ x y]]` —
generic `+` over the defn's UNANNOTATED parameter — which is the documented
issue-#70 inference limitation, unrelated to let. The control that would have
caught it (`defn ca [a] [+ a 4]`, no let at all) fails identically. A pre-P2
A/B (worktree at `974e5cc5`) shows the unspecced `:=` chain WORKED with
concrete ops (`int+`) before any P2 change. 4th data point this session for
"a failing test is only evidence if it fails for the reason you claim" — and
the first filed by the same process that codified the pattern. Kept (not
deleted) because a withdrawn filing teaches more than a silent one.

What WAS real and did land at P2 (`e8a41a9a`): the tree spine's let-chain arm
was a rival half-implementation (`:=`-only, annotation-dropping, and a no-`:=`
`let-bracket` head fell through to a junk application surf that would WIN the
merge). It now DEFERS to preparse per the driver's own architecture comment —
a structural single-implementation move with no demonstrated behavioral delta,
claimed as exactly that. The defer is named scaffolding; it retires when the
form-cell path grows a real let.

---

## ✅ CLOSED `7efc781d` — Cross-FILE spec-store leakage within a batch worker (filed 2026-07-31, fixed 2026-08-02)

**Root cause, confirmed.** The 2026-07-31 note's prime suspect was right:
`run-ns-*` handed every call the shared `prelude-persistent-registry-net-box`
UNFORKED, so the cell-backed spec store was one table for the life of the
worker process. `spec-store-lookup` (macros.rkt:496) reads the CELL FIRST and
falls back to the parameter; the worker's per-file snapshot restores the
PARAMETER, which that read never consults. The dual write to both is what made
the restore look complete.

**Fix**: fork `current-persistent-registry-net-box` per call, alongside the
prop network `run-ns-*` already forked, seeded FROM the prelude box so
prelude registrations survive. Five lines in `test-support.rkt`;
`tests/test-batch-isolation.rkt` pins both directions (nothing leaks forward,
the prelude still arrives).

**How it was finally caught**: bisection to a TWO-FILE deterministic repro
(`test-defn-multiarg-patterns` then `test-error-messages`, `--jobs 1`), after
five sightings across two separate DEFERRED entries — this one and the OCapN
backlog's X2. The second symptom was the instructive one: a leaked
`(spec ok2 Nat -> Nat)` turned a `defn ok2` that must INFER into one that
CHECKS, and the failure read "cannot infer the type of an unannotated
parameter" — naming an engine that was working perfectly. Same lying-diagnostic
shape as `infer`/`inferQ`, from a different cause.

**Lesson worth keeping**: an order-dependent batch flake is reproducible.
`--jobs 1 --all` makes the order deterministic, and bisecting the prefix
against the failing file found the culprit in six runs. Three earlier sessions
re-observed it instead.

---

## ✅ CLOSED — two soundness holes on the STRICT path, found while grounding P6 (2026-07-31)

Both confirmed by probe at `7584c16e`, both independent of P6/P7. **Both were
FIXED at the time — see the CLOSED entry above.** Retained for the mechanisms,
which are still the best description of how each hole worked; the open-bug
marker on this entry was left behind by mistake and is corrected here
(2026-08-02). Hole 2's diagnostic was improved separately — see the
cross-constructor hint entry above.

1. **An unknown constructor in a match pattern silently becomes an irrefutable
   VARIABLE pattern**, making every later arm dead code with zero diagnostics.
   `defn deadarm [v] match v (vnil -> 1N) (vcons a b -> "not-a-nat")` at expected
   type `Nat` DEFINES CLEAN — arm 2's String body is never checked. Mechanism:
   `normalize-pattern`'s `[else pat]` (macros.rkt). Consequence beyond the bug:
   any probe using a misspelled constructor proves nothing, because no
   `expr-reduce` is produced at all.
2. **A constructor from an UNRELATED data type is accepted in an arm.**
   `spec crossctor Bool -> Nat` / `defn crossctor [b] match b (true -> 1N)
   (mk-b3 x -> 2N)` where `mk-b3 : Nat -> Box3` DEFINES with 0 errors. Cause: the
   bare-name `global-env-lookup-type` fallback in `reduce-arm-ctx`'s derivation
   (typing-core.rkt) with no membership test against `lookup-type-ctors`. Note
   this CONSTRAINS any "make an unfindable ctor an error" fix — the fallback
   already half-defeats it.

---

## ✅ CLOSED `6d4e8c73` — Linear destructuring via a multi-clause `defn` is rejected (2026-07-31)

**Root cause was wider than this symptom** — see the CLOSED entry above.
Original report retained:

`spec c3 Handle2 -1> Nat` + `defn c3 | mk-h k -> k` → "Multiplicity violation",
though it consumes the linear scrutinee exactly once. The fio spelling
(`defn f [h] match h (mk-h k -> …)`) works, so the two surface forms disagree.
Verified PRE-EXISTING by A/B against the parent commit while implementing P6 —
not caused by the QTT track.

---

## ✅ FIXED 2026-08-03 — `.pnet` registration gaps by SIBLING, not by node (found while fixing QTT P5 residual 2)

`pipeline.md` names this shape — *"a fix applied to one member of a container
family but not its siblings"* — and the `.pnet` tag tables are full of it,
because each registration was added when that particular node DETONATED.

Verified in-process (construct the node, `deep-struct->serializable` →
`deep-serializable->struct`, assert the result is a `struct?` and not a raw
vector), so these are measurements rather than inferences:

| Family | Registered before | MISSING before |
|---|---|---|
| `expr-generic-*` | `from-int`, `from-rat` (they bit — the Q11 Posit→Float instances) | `add sub mul div lt le gt ge eq mod negate abs` — **12** |
| `expr-int-*` | `add sub mul div lt eq` | `le`, `mod` — **2** |
| Posit ops | the 12-op list per width, ×4 widths | `sqrt`, `from-nat` per width — **8** |
| Vec/Fin | none | all **9** (P5 residual 2 above) |

The generic set is the alarming one: those are not exotic nodes. Every generic
`+ - * / < <= > >= = mod`, `negate`, `abs` a user writes elaborates to one, and
the family's OTHER two members are registered specifically because they caused
a months-latent crash. All 31 now register; pinned per-member in
`tests/test-pnet-vec-fin.rkt` (enumerated, not sampled — the defect IS the
per-member gap, so a test that checked one member per family would have passed
against every one of these).

**A blanket coverage test was attempted and is NOT the answer as written.** A
reflective sweep over all 345 `expr-*` structs — build a dummy, round-trip it —
reports 130 failures, and that number is NOT trustworthy: dummy field values
are ill-formed for the sentinel-serialized containers (`expr-champ`,
`expr-hset`, `expr-rrb`, the transients), which serialize RECONSTRUCTIVELY and
legitimately reject a dummy payload. It also produced at least one outright
false positive (`expr-Symbol`, which round-trips correctly when checked
in-process). Treat 130 as an upper bound that needs per-node triage, not as a
defect count. The residual — auditing the rest, and deciding which nodes are
deliberately non-persistable (`expr-prop-network`, `expr-opaque`, the
transients) versus simply missed — is real work and is **not** done. Reproduce
the sweep with the recipe above before trusting any number in it.

---

## ✅ CLOSED `2df675d5` — `expr-foreign-fn` treated as a closed leaf (filed 2026-07-30, fixed 2026-08-02)

The comment *"opaque leaf — no Prologos sub-expressions"* was false in SIX
walkers, not two: `shift`, `subst`, `nf`, `uses-bvar0?`, and all three of
`zonk` / `zonk-at-depth` / `default-metas`. `reduction.rkt`'s partial-
application arm appends whnf'd argument expressions into `args`, so a node
reachable under a binder can hold an open term.

All six now descend `args`, `eq?`-preserving when nothing changed (so the
GitHub #58 P1 sharing property survives). `tests/test-foreign-fn-walkers.rkt`
goes at the walkers DIRECTLY — 5 of its 7 cases fail against the previous
commit, which is the point: the original filing correctly noted the defect is
not reachable from any source program today, so a behavioural test would have
passed with the bug in place. That is how it survived to be found by reading.

Kept the tripwire framing: this arms the invariant rather than relying on the
reduction order that currently hides it.

---

## ✅ RULED + SHIPPED — `m0 ⊔ m1`: a linear resource MUST be consumed on every path (2026-07-30)

**Owner ruled option 3; implemented in QTT P3 (`3a4d521a`).** Kept here rather
than deleted because the reasoning is the reference for the next multiplicity
question. Ruling: *"linear types should always be linear... there's a
correctness concern otherwise."* The join stayed the honest lub and a separate
`join-branches` guard supplies linear-per-path — `maybe-close` (the fd leak
below) now errors; `always-close` type-checks. Two residuals, both filed:
- P4 ✅ `e7fbd2ba` — the message NOW names the resource, its declaration, what
  happened and why, for all four violation classes. (The premise above was wrong:
  `multiplicity-error` already had `variable`/`declared`/`actual` fields that
  already rendered — they were filled with the string literals "declared" and
  "actual". No protocol change was needed, only real values.)
- The reduce arm's permissive fallback never checks agreement, so a leak on an
  unanalysable (Church-fold) arm still hides. Closes when that path does.

Original framing, retained:

Raised by QTT P1/P2 (`966226cf`, `9fbbc90f`). NOT the implementer's call, so it
shipped with the status-quo-preserving cell and is recorded here.

`mult-join` (prelude.rkt) is the lub of the tree's own `mult-leq` order, so
`m0 ⊔ m1 = m1`. That means a linear value consumed on SOME branches and dropped
on others type-checks — **affine per path**, not linear per path. Demonstrated on
the real API (fio, verified at `9fbbc90f`):

```prologos
;; closes the handle on EVERY path — the correct linear program
def always-close := [fn [h :1 <Handle>] [fn [c : Bool]
  (boolrec [fn [_ : Bool] Unit] [fio-close h] [fio-close h] c)]]   ;; ✓ accepted

;; closes on one branch, SILENTLY DROPS the handle on the other — an fd leak
def maybe-close  := [fn [h :1 <Handle>] [fn [c : Bool]
  (boolrec [fn [_ : Bool] Unit] [fio-close h] unit c)]]            ;; ✓ ALSO accepted
```

Before P1 this pair was **inverted**: `always-close` was REJECTED (m1+m1 = mw)
and `maybe-close` accepted. P1 fixed the false rejection. What remains is that
the leak is still accepted — precisely the failure `Handle`'s linearity exists to
prevent.

Three options:
1. **Lenient (shipped)** — `m0 ⊔ m1 = m1`. Preserves every currently-accepted
   program; permits the leak.
2. **Strict** — `m0 ⊔ m1 = mw`, so a linear resource must be consumed on every
   path. Rejects the leak, but is a behavioural regression for accepted code AND
   mislabels "zero-or-one" as "unrestricted" behind the generic "Multiplicity
   violation" string (typing-errors.rkt hardcodes the declared/actual fields as
   literals, so the message cannot say what actually went wrong).
3. **Lenient join + a per-position branch-AGREEMENT guard** for positions whose
   DECLARED multiplicity is m1. Gives strict linear-per-path semantics with a
   PRECISE failure instead of encoding a rejection as `mw`. Expressible where the
   join now sits: `ctx` is in scope and carries `(type . mult)` positionally
   parallel to the usage vectors, and `(tu-error)` is already the arm's failure
   form. This is the option the first analysis pass never enumerated.

Recommendation: (3) if linear-per-path is wanted, since it is the only one that
can produce a diagnostic naming the dropped resource. Do NOT read the shipped
default as an endorsement — it is the status quo, and the status quo permits the
leak.

---

## ✅ CLOSED `63dea0b6` — natrec's `step` usage is counted ONCE though it runs n times (2026-07-30)

**Superseded by QTT P7**, which also found the filing under-scoped: the same
defect sat in 8 HOF primitives with 121 shipped uses, while natrec has none.
The Redex model's matching natrec rule is noted below and still stands as a
follow-up. Original entry retained:

QTT P1 changed eliminator branch combination to a join at 5 sites and
DELIBERATELY left `natrec` on `add-usage` (qtt.rkt, comment in place). The
rationale is sound as far as it goes — base and step are not mutually exclusive
alternatives, so joining them would UNDER-count, unsound in the permissive
direction. But the current rule is not right either: `step` has type
`Π(n:Nat). motive(n) → motive(suc n)` and is applied 0..n times, while its usage
is added exactly ONCE. A linear variable captured only in the step is therefore
counted `m1` no matter how many times it is consumed.

Making it sound means scaling the step by `mw`
(`(add-usage u4 (add-usage u2 (scale-usage 'mw u3)))`), which newly rejects a
class of currently-accepted code. Recorded rather than defaulted into. Note the
Redex model (redex/qtt.rkt:173-186) carries the same natrec rule, so the two are
currently IN AGREEMENT — a fix must move both.

---

## ✅ CLOSED `9f0ddede` + `7b14fffe` — Retire `contains-unsupported-qtt?` (2026-07-30)

**Done in QTT P5**: all 8 nodes armed in qtt.rkt and the guard DELETED, so
multiplicity checking is unconditional at the def seam. PNET_VERSION 7→8 rode
the deletion. Original entry retained for the rationale:

QTT P2 removed the `expr-reduce` entry, which was the one that mattered. What is
left (driver.rkt) is a hand-armed walk that recurses 12 node kinds, flags 8
(`expr-vnil`, `expr-vcons`, `expr-vhead`, `expr-vtail`, `expr-vindex`,
`expr-fzero`, `expr-fsuc`, `expr-foreign-fn`), and terminates at `[_ #f]` — over
~344 `expr-*` structs. Everything else stops the walk and is reported
"supported" WITHOUT being looked inside, so the guard both over-skips (a flagged
node anywhere disables QTT for the whole def) and under-detects.

Per `pipeline.md` § "Exhaustive Walkers" the structural answer is a reflective
fallback; per `workflow.md` the guard IS the belt-and-suspenders dual path
masking qtt.rkt's gaps, and the endgame is arming those 8 nodes in qtt.rkt and
DELETING the function. Each of the 8 is its own typing question (Vec/Fin are
length-indexed; `expr-foreign-fn` is an opaque runtime value), which is why P2
deleted one entry rather than the guard.

⚠ Whoever does this: a `.pnet` version bump belongs in the same commit, for the
reason P2's did — on a cache hit the driver never elaborates, so the QTT gate
does not run and a module that should newly fail keeps loading from cache.

---

## ✅ CLOSED `f51bda2b` — a guarded clause group with no `[params]` header CRASHES the compiler and aborts the whole file (found 2026-07-30)

**Cause was a missing parse, not a compiler bug**: `parse-defn-clause` took
everything before `->` as PATTERNS with no `when` handling, though the
bracketed-header parser has always had that split. `n when [int-lt n 0]` became
three patterns, the clauses had mismatched arity, and the pattern compiler
indexed off the end of its parameter list and raised — a whole-file abort by
construction. Fixed by mirroring the header path, so the bare-`|` guarded form
now WORKS rather than merely failing politely. Semantics pinned (dispatch,
successive-guard fallthrough, header form unchanged, and an earlier command's
output surviving). Original report retained:

**Repro** (independently verified at `5e6d9f41`, pre-existing — the crash is in
`macros.rkt`, long before typing):

```
ns pre1
def before := 1
defn m07
  | n when [int-lt n 0] -> "neg"
  | n -> 5
def after := 2
```

`racket tools/run-file.rkt` prints NO numbered results at all — not even
`def before := 1`, which precedes the offending form — just a raw Racket
`list-ref: index too large for list / index: 3 / in: '(__arg0 __arg1)` with a
`context...:` dump through `macros.rkt:9928 compile-match-tree` →
`macros.rkt:10235 compile-pattern-group` → `macros.rkt:10309
expand-defn-multi`. Adding the bracket header (`defn m07 [n] | n when … -> …`)
avoids it. Same **whole-file-abort silence class** as the `.( )` mixfix entry
below and the tilde-reader entry: a raise on the expansion path takes the file
down instead of becoming a per-command error. Likely cause: the guard row's
pattern list is arity-adjusted for a 1-column group while `param-names` still
holds two entries, so `compile-match-tree` indexes past the list.

---

## ✅ CLOSED `c4aa917c` — live `.( )` mixfix errors RAISE and abort the whole file (filed 2026-07-28, fixed 2026-08-02)

Fixed via the seat the entry named. `expand-mixfix-form` collapses its own
failures to a `($mixfix-error msg)` datum; parser.rkt turns that into a
`parse-error` VALUE with the form's location. Same channel as LET P1's
`$let-error` — reused rather than duplicated, so there is one mechanism for
"a preparse expander failed" and not two.

```
0: a : Int defined.
1: ERROR: Operators from groups 'additive' and 'cons' have no defined precedence relationship — use [] for explicit grouping
2: b : Int defined.
--- 1 errors ---
```

Genuinely PER-COMMAND, unlike the reader raises: expansion is per-form, so the
commands before AND after the bad one still run. Pinned in both directions —
each failure mode reports, and a well-formed `.( 1 + 2 )` still evaluates.

A distinguished `exn:mixfix` struct (mirroring `exn:let-syntax`) rather than
catching `exn:fail?`, so a genuine Racket-level bug inside the parse still
surfaces as itself instead of being reported to the user as a syntax error.

**Five raise sites, not three.** The first pass converted the three in
`parse-expr` and left `parse-primary`'s two, which kept aborting — caught
because a test pinned the surviving raise. Converting a family and stopping at
the ones you happened to grep for is the same shape as the walker defects
elsewhere in this file.

Three tests that pinned the raise are updated to pin the marker; that is the
change the entry existed to make, not collateral.

---

## ✅ CLOSED — the tilde-number reader diagnostic (filed 2026-07-28; silence fixed `5da580f9`, per-command routing fixed 2026-08-03)

**Was fixed at `5da580f9`**: it became a reported error rather than a raw
Racket `context...:` dump with exit 1 and zero output. Reader raises carry LINE
AND COLUMN (`rrb-line-col`, computed from the char buffer, since tokenization
runs before any syntax object exists), and `process-file-inner` guards the READ
step.

**Now fixed too — the file's other commands survive.** The old entry said this
"needs the reader to EMIT A MARKER instead of raising — the D4.P1a
`parse-error`-value seat", and that is exactly what it took. The `tilde-number`
token pattern no longer raises; it tags the token, `token-entry->stx` emits
`($reader-error "msg")`, and `parser.rkt` converts it on the same channel as
`$let-error` / `$mixfix-error` (plus the `macros.rkt` head-symbol exclusion the
channel requires). One command lost, not the file:

```
"a : Int defined."
(parse-error (srcloc … 3 9 3) "`~` approximate literals were removed — …")
"c : Int defined."
```

Two things worth knowing if this channel is extended again:

- **The `token-pattern`'s third field is the TYPE function, not a value
  function.** Returning a marker symbol from it renames the token TYPE, so the
  `token-entry->stx` arm keyed on the old name silently stops firing and the
  token falls through two `[else]`s to a bare symbol — `~32` came out as an
  unbound variable with no diagnostic at all. Same silent-fallthrough shape the
  `.N` ordinal-access arm is annotated for at that site.
- **The location moved off the message and onto the srcloc**, so the text no
  longer spells "line 4, column 9". A test asserting `#rx"line 4"` against the
  message string is asserting the OLD delivery mechanism; assert
  `srcloc-line` / `srcloc-col` instead.

The five `check-exn` test files the entry named are updated (4 files, 5 cases —
`test-lseq-literal`, `test-negative-literals`, `test-num-lit`,
`test-numeric-display`), each now asserting the rejection is REPORTED rather
than raised. `test-reader-robustness` additionally pins that the commands on
either side survive — the half `5da580f9` could not deliver.

**Narrow the guard, not the blast radius** (unchanged, still load-bearing):
guarding the whole `surfs` computation instead of just the read ALSO swallowed
raises from `preparse-expand-all` that tests rely on escaping (a numeric `ns`
segment). Turning a REJECTION into a report is a different decision from
turning an ABORT into one; only the second was wanted. Caught by the suite, two
files.

**Also learned, and pinned as a negative** (`test-reader-robustness.rkt`): the
sibling raises in `tokenize-string`'s validation loop — negative Nat literal,
stray `&` — are NOT reachable for the obvious inputs. A per-command check gets
there first with a real srcloc, which is strictly better. With the tilde
pattern no longer raising, that loop is the only raising code left in the
reader, and `compat-tokenize-string` has no production caller — it is a
test-only compatibility path.

---

## ✅ CLOSED `4efe236c` — bare top-level `[]` hard-aborts the reader (filed 2026-07-28, fixed 2026-08-02)

The chain was one step longer than the filing's: a `'()` element gets a syntax
object with line 0, `make-stx` maps 0 → #f (as it is supposed to), and the
re-wrap in `read-all-forms-from-tree` reads that #f back and hands it to
`make-stx` again — whose guards compared with `>` BEFORE checking for #f. So
the crash was `>` on #f, not `max`/`-`, and it fired from the re-wrap rather
than the emission.

`make-stx` now accepts #f in every field, which its own comment always claimed
it did. The three inline `(- (+ (syntax-position last) (syntax-span last))
(syntax-position first))` sites are one `stx-range` helper that degrades to "no
location" instead of raising. `tests/test-reader-robustness.rkt` pins that the
file SURVIVES — 2 of its 3 cases fail against the previous commit.

**Residual, smaller and separate (filed below).** `[]` no longer aborts, but it
does not error consistently either.

---

## ✅ FIXED 2026-08-03 — a bare top-level `[]` yielded the WRONG command's result when another form followed (found 2026-08-02, splitting out of the abort fix above)

The filing was accurate and its two guesses were both wrong, in a way worth
recording. It said "the reader is not at fault" and pointed at
`preparse-expand-all`. The reader WAS at fault, `preparse-expand-all` was not
involved, and the entry's control case — `[]` alone erroring, annotated
"(correct)" — was the third bug rather than the baseline.

**Three faults, each masking the others.**

1. **The reader located an empty group nowhere.** `wrap-stx-list` had no
   elements to take a range from and passed 0 for line and column; `make-stx`
   maps 0 to `#f`; `stx-range` then propagated `#f` up to the enclosing form.
   The opening bracket's token was sitting in the caller, unused. Fixed with an
   `#:at` fallback — an empty group is located at its bracket.

2. **`merge-preparse-and-tree-parser` treated line 0 as a line.** The merge keys
   the two parse spines against each other BY SOURCE LINE, and 0 is the
   project's unknown-location sentinel (`srcloc-unknown` is `(srcloc … 0 0 0)`,
   and `stx->loc` folds a missing `syntax-line` to 0). So every located-nowhere
   surf on one spine matched every located-nowhere surf on the other — and the
   tree spine routinely carries one. Fixed with a `real-line?` guard on both
   the map build and the lookup.

3. **The two spines disagreed about what an empty group MEANS.** The tree spine
   has always said nil (`parse-bracket-group-tree`: "empty brackets = nil") and
   `def x := []` is tested as the empty list; `parse-datum` said "Unexpected
   datum: ()". Fault 2 was papering over fault 3 — the error surf got swapped
   for the tree surf by the very collision that was corrupting everything else,
   so `def x := []` worked BY ACCIDENT. Tightening the merge key exposed it on
   the first suite run, which is the useful thing about removing an accident.
   `parse-datum` now returns `surf-nil` for `'()`, so the spines agree.

**Consequence for the entry's "(correct)" annotation**: a bare `[]` is no
longer an error, it evaluates to nil — the same thing it means in `def x := []`
and the same thing the tree spine has always said. The inconsistency was the
error, not the value.

The defect was also broader than filed: `def y := ()` in a multi-command file
corrupted results identically (`z` reported twice), so it was every empty
group anywhere, not just a bare top-level `[]`.

Pinned by `tests/test-empty-group-toplevel.rkt` at all three levels — reader
location, one-result-per-command-in-order, and both spines agreeing on nil in
value position. The end-to-end assertion checks COUNT, ORDER and NO-DUPLICATE
together; asserting only that `a`, `b` and `c` each appear would have passed
throughout the bug, since they all did — one of them twice.

---

## ✅ RESOLVED — CIU T6 F1b: D23 posture-flip (DEPLOYED F1b.6 `7bcbca69`, 2026-07-18)

**The Q4 tightening is DEPLOYED — D23 (track doc §2a round 6): escape-boundary
hard error.** A dyn-row point-projection meta (kinds `dyn-row-projection` /
`dyn-row-dynamic-projection` ONLY — the narrow partition; bulk-op result kinds
keep scrubbing) escaping into a stored type is a HARD ERROR with def-srcloc, at
the two def-commit boundaries; exploration stays permissive; escape hatch =
explicit annotation. Implementation = F1b.2 (groundwork) + F1b.6 (the flip, via a
type-LOCAL walk `check-escaping-projection-metas` / `collect-expr-metas-deep`).
Full record: design doc §13.6 F1b.6 ✏ CLOSE. This pin is now historical (kept for
the sequencing rationale below); the flip landed AFTER F1b.3's presence activation
as required. **Rejected-with-reason (do NOT resurrect
from this entry's old phrasing)**: (a) freeze-wide default-to-error at zonk-final —
freeze fires in NON-display contexts (stored types driver.rkt:1704, constraint
rendering :1579-1580/:1754-1755, capture :1349); a policy there corrupts error
messages and capture, verified blast radius; (b) the constraint-store realization
of the obligation — the constraint struct's equational rendering + retry-only
failed-transitions do not fit an unsolved-observation obligation (the meta store
already records provenance at mint; a second record is duplication). The
refusal-relax half (meta-V from dyn rows) moved to § F-carrier below.

---

## ✅ RESOLVED — CIU T6: the cross-module schema channel (probe-found at F1b.5-p0, 2026-07-17; last gap closed 2026-08-03)

> **TRIAGED 2026-07-27 (GitHub #78 X.close): gaps 2 and 3 RESOLVED. Gap 1
> RESOLVED 2026-08-03 — all three are now closed.** This entry called its own fix shape correctly ten days early
> — "serialize the schema registry into `.pnet` (the ctor-registry precedent:
> serialize + cache-hit merge + load-module capture/re-propagation)" is exactly
> what #78 P2 shipped (`54358a5f`).
>
> - **Gap 2 — RESOLVED** (`54358a5f`). schema (and selection/session/strategy/
>   process/user-operators/user-precedence-groups) are now serialized into
>   `.pnet` (v4, indices 24-30), restored into BOTH parameter and cell on a
>   cache hit, and captured/re-propagated by `load-module`. Cross-module
>   schemas are no longer cold-load-only. Regression-gated by
>   `tests/test-pnet-registry-restore.rkt` (severity-3 case).
>   ⚠ The predicted symptom was UNDER-stated: this did not merely make
>   inject/wrap silently no-op — it produced a HARD module-load failure
>   (`imports: Error loading module <M>: Type mismatch`), because the seal
>   guard at `typing-core.rkt:3125-3126` turns the arm off entirely. That is
>   the issue's severity 3.
> - **Gap 3 — RESOLVED** (verify: all 7 registries appear in
>   `save-macros-registry-snapshot`, and `tools/batch-worker.rkt` save/restores
>   via it at `:98`/`:223`). The F1b.5-s1 hygiene rider this entry anticipated
>   did land.
> - **Gap 1 — RESOLVED 2026-08-03.** `pnet-stale?` now also consults
>   `lib-sources-stale?`: the newest mtime across every `.prologos` under
>   `current-lib-paths`, compared against the `.pnet`'s own. A dependency's
>   schema changing DOES invalidate a dependent's cache now. #78 P2 made the
>   *contents* correct on a hit; this decides *when* a hit is legitimate, which
>   is the line this entry drew.
>
>   **Deliberately blunt, and the bluntness is the design.** It is the newest
>   mtime across all library sources rather than a per-module dependency set.
>   The precise alternative — record each module's dep list in its `.pnet` and
>   walk it — needs the `dep-edges` field re-added WITH a consumer (it was
>   retired as write-only at PPN 4C Addendum Phase 4B.1). Correct-and-blunt
>   follows the `driver.zo` precedent already sitting one line above rather than
>   inventing a second policy; the cost is one cache-regeneration sweep (~3-4 s
>   for the ~55 prelude modules) and it is paid only when a lib `.prologos` is
>   actually edited. Memoized per process and **keyed by the lib paths** — a
>   single unkeyed box answers for the wrong directory set, which turned
>   `test-pnet-registry-restore`'s intended cache HITS into misses on the first
>   cut.
>
>   Pinned by `tests/test-pnet-dep-staleness.rkt`, phases 1-3 (a `defn` through
>   a middle module) and phase 4 (this entry's own shape: a schema whose
>   `:default` is baked into a middle module's AST). Both are three-level
>   chains, and **that is load-bearing rather than thorough** — the first draft
>   of phase 4 had the user file import the schema module directly, so the
>   schema module's own mtime invalidated its own `.pnet` and the phase passed
>   with the fix disabled. Verified by A/B: with `lib-sources-stale?` stubbed to
>   `#f`, phases 3 and 4 both fail with the pre-edit answer; with it live, all
>   five pass.

PRE-EXISTING class, probe-verified at `6584b443` (F1b.5-p0 agents; full record
design doc §13.8 ✏ items 6-7). THREE coupled gaps, ONE channel fix:

1. **No cross-module cache invalidation**: `.pnet` validity = own source mtime +
   `driver_rkt.zo` stamp ONLY (`source-hash-for-module`'s own comment concedes
   no content/dep hashing). Schema-derived data baked into a USING module's AST
   (defaults + :check chains TODAY via inject-schema-defaults/wrap-schema-checks;
   validate's baked plans from F1b.5-s2) goes silently stale when the DEFINING
   module's schema changes. update-deps' edge graph feeds test selection only.
2. **Schemas are not serialized into `.pnet` and not re-registered on cache-hit**
   (zero schema tokens in pnet-serialize's 17-registry list; no register-schema!
   on the cache-hit merge path) → A-cache-hit + B-cache-miss ⇒ `lookup-schema`
   = #f ⇒ the existing inject/wrap SILENTLY NO-OP. Cross-module schemas are
   COLD-LOAD-ONLY today. (Validate's elaboration bake errors LOUD on the miss —
   better diagnosability, same underlying gap.)
3. **The registry parameter is off three save/restore lists** (batch-worker
   restore, test-support parameterize, the macros 19-param snapshot) — masked
   by cell-first reads + the cell-id riding save-macros-cell-ids. The list
   insertions land as the F1b.5-s1 hygiene rider; THIS entry keeps the
   structural fix.

**Fix shape (one channel)**: serialize the schema registry into `.pnet` (the
ctor-registry precedent: serialize + cache-hit merge + load-module capture/
re-propagation) + dep participation in the cache key (content/dep hashing at
source-hash-for-module — its comment already names the full implementation).
**Entry gates**: (a) first REAL cross-module schema consumer (a library module
exporting schemas — none exist today; the demo is single-file); (b) or the
first stale-baked-plan incident in practice. Until then the class is documented
here + at §13.8.

---

## ✅ CLOSED `65edc1a4` — resolution bridges capture registry cell-ids while they are still #f (found 2026-07-27, fixed 2026-08-02)

Took the **read-at-fire-time** option, not the defer-into-the-lambda one. The
lambda is called at INSTALL time, which is also before some paths have
identified the cells — deferring one level would have moved the bug rather than
removed it. Fire time is the only point at which the answer is guaranteed
current, and it costs a parameter read on a path that is already ambient:
`read-persistent-registry-cell` reads `current-persistent-registry-net-box`
ambiently inside these same fire functions, so no new assumption is added.

The three captured cell-ids and their six parameter passes are GONE rather than
deferred — the fire functions read `(current-impl-registry-cell-id)` and friends
at the point of use. A stale capture is now unrepresentable instead of merely
fixed.

**Test shape, stated honestly.** This defect is silent because the pure bridges
are not the production trait-resolution path, so there is no behavioural
assertion that fails before and passes after. What the tests pin is the ARITY of
the fire functions (which changes exactly when the plumbing is removed), that
both factories survive construction with the cell-ids unset — the module-level
situation — and that ordinary trait dispatch still works, since the factories
really are built at module level.

Unblocks PM Track 12's read-path work, which named this as a prerequisite
(`2026-07-27_PM_TRACK12_REGISTRY_READ_PATH_NOTE.md` §2.4).

---

## ✅ CLOSED `97c113c7` — `.pnet` positional format has no arity assertion (filed 2026-07-27, fixed 2026-08-02)

Took the "assert the length" option, on BOTH sides, plus the named constant the
entry implied:

- `PNET_SLOT_COUNT` (31) sits beside `PNET_VERSION`, exported, with the rule
  that it moves with the version — a payload of a different shape IS a
  different format.
- **The writer asserts before writing**, so a mis-ordered build fails on the
  machine that made it instead of becoming a shifted read somewhere else.
- **The reader requires EXACT equality**, replacing a `>= 14` minimum. A short
  or long payload is now a cache miss rather than a shifted read.

The write side already knew the count; the read side accepted anything from 14
up. The two disagreed by construction, and nothing said so.

Removed while there: 18 per-slot `(>= (length raw) N)` guards and the 18
`(if s-X … (hasheq))` fallbacks behind them. Both were unreachable — the
version gate already required an exact match, and the code said so itself
("the length guards here are vestigial … but they are kept in the existing
style"). A second mechanism standing in front of the version gate, hiding what
it does; keeping it alongside the new assertion would be the same mistake
twice.

`tests/test-pnet-slot-count.rkt` pins the constant so a change to it is
deliberate rather than a quiet adjustment to make the new assertion pass.

---

## ✅ RESOLVED 2026-08-03 — CIU T6: named-`?`-field vs presence-optional DISPLAY ambiguity (7g surfaced, owner-acknowledged 2026-07-19)

**Fixed by MOVING the marker, not by inventing a new one.** The entry offered
three presentation options (a leading `?`, a space, `{:active [?] Bool}`); the
leading `?` is the one with a structural argument behind it, so it is the one
that shipped. `recognize-keyword` requires `char-alphabetic?` for the character
after the colon, so **no user field can ever be named `?active`** — the marker
now occupies a position the lexer reserves, which makes the distinction
impossible to collide with rather than merely unlikely to. A space or a bracket
form would have been equally readable and equally conventional; this one cannot
be defeated by a field name.

All three cases are now distinct in one rendering:
`:n` present · `:?n` optional · `:active?` a present field NAMED `active?` ·
`:?active?` that same field, optional.

Display-layer only, exactly as the entry predicted — no reader or typing touch.
Cost: 3 acceptance markers in `2026-07-06-ciu-t6-f1-records.prologos` (the
suffix spelling was pinned there), the `syntax.rkt` presence-lattice spec, and
2 new test cases pinning both halves — the optional field marks in FRONT, and a
present `?`-named field gains no marker at all.

Original entry follows.

---

## (original) CIU T6: named-`?`-field vs presence-optional DISPLAY ambiguity

F1b.7g made `?`/`!`-suffixed keyword keys read whole (`:active?` is now a valid
field/key name). This makes a PRE-EXISTING, display-only ambiguity newly
REACHABLE: a field literally named `active?` with presence `'present` renders
`{:active? Bool}` — INDISTINGUISHABLE from an OPTIONAL field `active` (the D24
presence-`'unknown` display marker appends a `?` suffix, pretty-print.rkt:439-445;
already-documented at syntax.rkt:684-686 as "revisit if it bites"). It is
**display-only** — flips NO parse-time behavior; the stored label is `active?`
verbatim and the value reads/projects correctly (`s.active?` → the value). Owner
acknowledged (7g Q2), NOT a blocker. **When it bites** (a user confused by
`{:active? Bool}` meaning "field active?" vs "optional active"): the fix is a
presentation-design choice in the pretty-printer — e.g. render presence-unknown
with a distinct marker (a leading `?`, or a space, or `{:active [?] Bool}`) so the
suffix-`?` of a real field name never collides with the presence marker. Couples
to the D24 presence-marks display + the broader FQN-display-verbosity presentation
question (dailies 29). Low urgency; a display-layer-only change (no reader/typing
touch).

---

## ✅ FIXED 2026-08-04 — `test-properties.rkt` reported a nondeterministic test count (found 2026-08-03)

**Diagnosed, fixed, and the entry's own alarm CORRECTED.**

`test-generators.rkt` was a library and a test file at once: it exported the
generators AND ran five `check-property` self-tests at module top level.
rackunit counts a check when it RUNS, and Racket instantiates a module once per
process — so within a batch worker, whichever of the two files was reached
first got the five, and the other got none.

That accounts for every number:

| layout | generators | properties | sum |
|---|---|---|---|
| the two files land in DIFFERENT workers | 5 | 13 | 18 |
| SAME worker, generators first | 5 | 8 | 13 |

Work-stealing picks between those per run. The recorded history in
`timings.jsonl` shows exactly this alternation and — the giveaway — shows
`test-generators.rkt` at **5 every single time**, never 0.

⚠ **Which makes this entry's central claim WRONG, and it was mine.** It said
"silently running 8 of 13 is a coverage hole nothing reports". There was no
coverage hole: the five self-tests always ran, and in the different-worker case
they ran TWICE (once per process) — the 18 was the anomaly, not the 13. What
actually varied was ATTRIBUTION between two files. The entry reasoned from a
count diff to a coverage claim without checking the other file's count, which
was sitting in the same records and would have refuted it immediately.

**Fix** — split the double duty, which is the actual defect:

- `tests/generators.rkt` — the library. Deliberately NOT named `test-*.rkt`,
  because that prefix is exactly what the runner collects (run-affected-tests
  `:401`).
- `tests/test-generators.rkt` — the five self-tests, requiring the library.
- `tests/test-properties.rkt` — requires the library, so requiring generators
  has no test side effects.

Now constant: **generators 5, properties 8**, under `--jobs 1` and under full
work-stealing alike. Suite total drops 10634 → **10629**, which is the five
self-tests no longer running twice.

**The transferable bit**: a module that is both a library and a test file has a
test count that depends on who imports it first. Anything requiring a
`test-*.rkt` file is suspect for this — these two were the only such pair in the
tree, checked.

---

## (original filing) `test-properties.rkt` reports a NONDETERMINISTIC test count

Noticed while diffing per-file test counts across two full-suite runs (the
runner records them in `data/benchmarks/timings.jsonl`, which is what made this
visible at all). Same commit, same file set:

```
test-properties.rkt   baseline 13  ->  another run 8
```

Run alone via `--tests`, it reports **13** consistently. So under the batch
worker it sometimes executes 5 fewer `check-property` cases — and **passes
either way**, because rackcheck reports success for the cases it did run.

Not diagnosed. Two things make it worth an entry rather than a shrug:

- **A green suite with fewer cases is indistinguishable from a green suite.**
  These are the property tests — subject reduction, unification soundness, zonk
  idempotence, nf fixpoint. Silently running 8 of 13 is a coverage hole nothing
  reports.
- **It was found by a COUNT diff, not by a failure.** The only reason it
  surfaced is that an unrelated A/B (the N6d-i derive skip set) moved the total
  by 5 and the number had to be explained. Without that it would have kept
  alternating unnoticed.

First things to check: whether `check-property`'s case count depends on a seed
or on wall-clock budget, and whether the batch worker's per-file timeout or its
parameter save/restore interacts with rackcheck's config. Suspect the shared
`make-config #:tests 50` and any implicit deadline before suspecting the
worker.

---

## ✅ RESOLVED 2026-08-03 — a malformed DECLARATION took the whole file down (found while probing the Mixfix entry)

Not previously filed as its own entry; found because a bad `functor` while
probing § Syntax — Mixfix produced a raw Racket `context...:` dump with **zero
numbered results**, and a bad `trait` had done the same an hour earlier.

**The class**: ~150 `(error 'functor …)` / `(error 'trait …)` / `(error 'spec …)`
sites in `macros.rkt`. Preparse finishes before any command runs, so an escaping
raise left no expansion to run anything from — the file's already-successful
commands vanished along with the bad one. The loudest possible failure presented
as the quietest, which is the same class already fixed three times for other
paths: the reader (`$reader-error`), `let` (`$let-error`), and `.( )` mixfix
(`$mixfix-error`).

**Fixed by reusing that channel, not adding a fourth.** The preparse dispatch
contains a form's failure and emits a `($preparse-error msg)` marker in its
place; `parser.rkt` turns it into an ordinary per-command `parse-error` value.
Commands before AND after the bad declaration still run:

```
0: before : Int defined.
1: ERROR: functor: functor ⊕: requires :unfolds type expression
2: ERROR: trait: trait Bad: method must be (name : type ...), got A
3: after : Int defined.
4: 2 : Int
--- 2 errors ---
```

**Two design points, each measured rather than assumed:**

- **The guard converts ONLY an exception whose message begins with the form's
  own head** (`"functor: "` for a `functor`), which is exactly what Racket's
  `(error 'functor …)` produces. Anything else RE-RAISES, so a genuine
  internal bug inside `process-trait` still surfaces as itself. Verified by
  planting `(car '())` inside `process-trait`: it comes out as a `car:
  contract violation` with its context, not as the user's syntax error. A
  blanket `exn:fail?` catch here would be scaffolding that hides truth, and
  this file already carries a comment about a Pass-0 `with-handlers` doing
  exactly that.

- **CONTEXT-establishing forms are excluded** — `ns`, `imports`, `exports`,
  `foreign`. They set up what every later form depends on, so a failure there
  genuinely invalidates the rest. This was tried both ways: with `imports`
  contained, a file whose import failed for *"no namespace is in scope"*
  carried on and reported *"Unbound variable: module"* instead — a named,
  deliberately-built diagnostic replaced by a downstream symptom.
  `tests/test-import-no-ns.rkt` caught it, which is why that test existed.

**Cost: 6 test files.** Each asserted `check-exn` on a preparse form, i.e. they
pinned the whole-file-abort contract. Converted to assert the per-command error
VALUE with the same message — and four of them TIGHTENED in the process, since
they were `check-exn exn:fail?`, satisfied by any failure at all, and now have
to match the actual message.

---

## ✅ CLOSED `6e38d214` — bench-ab.rkt `--refs` for multi-way comparison (issue #63, fixed 2026-08-02)

`--refs HEAD~1` for A/B, `--refs A,B,C` for multi-way, `--md FILE` for a
markdown table, `--output` for JSON. One GIT WORKTREE per ref, built there and
run from there; the benchmark PROGRAMS always come from the working tree, so
what is compared is the compiler and not the input. No stash and no checkout —
the working tree is never touched, which is the standing rule. A ref that fails
to build is reported and EXCLUDED rather than silently measured against the
working tree's driver.

**This closed a live hazard, not just a gap.** The tool DOCUMENTED a `--ref`
flag it never had: the header advertised it, `workflow.md` instructed it, and
`run-ab-comparison` ran the B leg against the same tree with a comment saying
so ("same code for now; with --ref would checkout different code"). Anyone
following the documentation measured identical code twice and read the
difference as a result. Both rules files had been amended to warn that the flag
did not exist; they now describe the one that does.

Consumers named in the original entry (OE Track 1, PReduce Track 4, PAR
scheduler variants) are unblocked.

---

## ✅ RESOLVED 2026-08-03 — a NON-EXHAUSTIVE match returned a junk VALUE at zero errors (found and fixed same day)

```
spec p1 Nat -> Nat
defn p1
  | zero -> 1N

[p1 0N]   ⇒ 1N : Nat
[p1 5N]   ⇒ ??__match-fail : Nat        ← 0 errors
```

A pattern match with no matching row compiles to a typed hole named
`__match-fail` (`macros.rkt`, two sites), and a typed hole is a legal term that
types at anything. So a partial function **silently returns a hole at its
declared return type** rather than failing.

The hole mechanism itself is deliberate and fine — a user-written `??foo` is
also accepted at 0 errors, which is the Agda/Idris hole story. What is different
here is that **the user did not write this hole; the compiler inserted it
because their match was incomplete**. Silence is defensible for a hole someone
typed on purpose and much less so for one that means "your function has a case
you did not cover".

**Not filed anywhere before this** — grepping the tree finds no
non-exhaustiveness diagnostic at all, only the comment `;; No rows —
unreachable branch (incomplete pattern match)` at the site that plants the hole.

**✅ FIXED the same day — W3002, a default-on WARNING.** The severity question
answered itself once measured, which is the same route W3001 took:

| corpus | `__match-fail` holes planted |
|---|---|
| full prelude load | **0** |
| F1-records acceptance file | 0 |
| F1b5-validate acceptance file | 0 |
| OCapN acceptance file | **1** |

So the ordinary path is silent and the signal is precise — it does NOT fire on
every constructor split, only where coverage genuinely fails. A warning rather
than an error because Prologos has typed holes as a FIRST-CLASS feature (a
user-written `??foo` is accepted at 0 errors on purpose), so a partial function
is not obviously illegal here the way it is in Agda or Idris. What is not
defensible is silence about a hole the COMPILER inserted.

⚠ **It paid for itself on its first run.** The single hit was `step-cell` in
`lib/prologos/ocapn/behavior.prologos`: `syrup-bytes` was added to `SyrupValue`
at Phase 19 and that match was never extended, so `step-cell` on a bytes
argument had been returning `??__match-fail` at zero errors ever since. Fixed in
the same commit, and the module is now pinned clean — if another `SyrupValue`
constructor lands without extending the match, the warning fires there again.

Pinned in `tests/test-inexhaustive-match-warning.rkt`, including the two halves
that decide whether it is usable rather than noisy: an exhaustive match must
stay silent, and the `_` catch-all the message recommends must actually silence
it.

Found while probing "Extended Pattern Matching in `.{...}`" below — the
unsupported view pattern `.{n + 1}` produced exactly this silent failure, which
is what made the general case visible.

---

## ✅ CLOSED — Surface Syntax Issues (TRIAGED 2026-08-02; all three sub-items resolved or reclassified, header corrected 2026-08-03)

### ✅ RESOLVED — WS-Mode `:=` Body Parsing with Multi-Form Bodies

The entry said `def x : List Nat := cons 1N [cons 2N nil]` fails because
`expand-def-assign` requires exactly one form after `:=`. It does not: it wraps
a multi-token RHS as an application, which is the fix the entry asked for.
Verified with the entry's exact example, with and without the annotation, and
with the source file's own `def sample-list : List Nat := cons 1N [cons 2N
[cons 3N nil]]`.

`examples/unified-matching.prologos` carried that line COMMENTED OUT under an
"Ideal syntax (commented out — WS := body parsing issue)" note. It is
uncommented and the file runs 0 errors. The note outlived the behaviour it
described — worth remembering when reading an example's own ISSUE comments.

### ⬜ NOT A DEFECT — Multi-Bracket defn

`defn f [a] [b] body` does not work in either mode, and the entry itself says
the standard pattern is the uncurried single-bracket form —
`prologos-syntax.md` makes that the convention ("Uncurried"). So this is a
design NON-GOAL, not a gap. It produces a clean per-command error naming what
it expected, not a crash. Reclassified rather than closed: if curried `defn`
is ever wanted, this is where the note lives.

### ✅ SUPERSEDED — WS Mode Path Expression Disambiguation (`.{`)

The `.{` conflict has a ruling and a diagnostic since CIU T6 D4.P1b-ii:
`cfg.{a}` at top level now gives the guided per-command error "a `.{…}`
sub-block belongs inside a select block — write `x{server.{host port}}`; at top
level, `x{…}` selects and `x.k` accesses". The entry predates that work.

---

## ✅ FIXED 2026-08-03 — a higher-order list function on a `def` RHS failed; the same expression as a bare command worked (merged + re-probed 2026-08-02, fixed 2026-08-03)

The entry was accurate throughout, including its two negative findings (not
about first-class operators; the offered `plus`/`minus` workaround does not
exist), and its "where to start" pointer at `pipeline.md` § "infer / inferQ Are
Twins" named the right SHAPE. The cause was one layer under that: not a missing
`inferQ` arm, but a comparison the two passes make differently.

**Two independent faults, each with a lying diagnostic.**

1. **"Multiplicity violation" was a KIND mismatch.** A type constructor's kind
   is `Pi m0 Type Type` — its type argument really is erased — while a spec's
   `{C : Type -> Type}` writes an unannotated arrow, which defaults to `mw`.
   `subtype?` demanded the two multiplicities be IDENTICAL, so `List` did not
   fit `C` and the whole application spine failed to infer.

   It reached only the QTT pass because typing-core sees `C` as an unsolved
   META, and meta-solving never compares multiplicities — only the post-freeze
   QTT check meets the concrete `List`. That is why the bare command worked:
   it runs no `checkQ-top` at all. The command "working" was never evidence
   the term was well-formed.

   Fixed in `subtype-predicate.rkt`, and not by new policy: Pi multiplicity is
   an UPPER BOUND on the function's use of its argument, and `compatible 'mw
   'm0` is already `#t` everywhere else in the system. The new arm applies that
   same predicate structurally (normalize t1's mult to t2's, then delegate to
   the existing structural walk), so it loosens exactly as far as `compatible`
   and no further — `mw <: m1` stays false, which is the unsoundness the
   ordering exists to prevent.

2. **"Expression is not a valid type" ran `is-type` on an UNZONKED type.** An
   implicit higher-kinded argument leaves a meta-headed application behind,
   which is not a type by inspection. The tell was inside the message: it
   renders with `pp-expr`, which DOES follow solutions, so it printed
   "not a valid type: [List Int]" — naming a valid type. A diagnostic that
   pretty-prints through a resolution its own predicate did not perform will
   always read as nonsense; that mismatch is the thing to notice. Fixed by
   zonking before the check (intermediate `zonk`, not `freeze` — a genuinely
   undetermined type must still fail).

All six lines of the entry's sharp repro now work, `def a : Int := reduce + 0
'[1 2 3]` works on the annotated seam too, and a HOF inside a spec'd `defn`
returns a real value rather than the stuck term the entry recorded.

Pinned by `tests/test-hof-def-seam.rkt`. Every case is a `def` — the bare
command passed throughout and proves nothing here — plus one that asserts the
def and the command PRINT IDENTICALLY, since the disagreement was the defect,
and a unit table for the multiplicity relation in both directions.

**Found while probing, NOT this defect — ✅ FIXED 2026-08-03**: an unbracketed
application as a `defn` body (`defn bump [x] int+ x 1`) reported, WITH a spec
present, "Type mismatch … `[fn [x <Int>] [fn [y <Int>] [fn [z <Int>] [int+ y
z]]]]`" — a message about a three-parameter lambda the user never wrote.

Two faults, and the first hid the second. `inject-spec-into-defn` spliced
`,@body-forms` unconditionally, so three body forms became
`(defn bump [x <Int>] <Int> int+ x 1)` — which parses as a THREE-parameter
typed defn, bypassing the parser's bare-params guard entirely. WITHOUT a spec
the same source already produced a proper parse error, so the two paths
disagreed about the same mistake and only the spec'd one was misleading.

Fixed by DECLINING to inject (rather than raising — this runs inside
`preparse-expand-all`, where a raise costs the whole file) so the parser's
guard speaks, and by making that guard name the actual mistake instead of the
return-type slot: *"defn bump: the body looks like an application written
without brackets — write `[int+ …]`."*

⚠ **The guard's BARE-SYMBOL head is load-bearing, and the obvious predicate is
wrong.** "A well-formed defn under a spec has exactly one body form" is FALSE:
a `let` CHAIN is legitimately several forms at injection time, because the
sibling-chain merge runs later. Declining on mere multiplicity dropped the
spec's types for every specced let-chain defn and broke two `test-let-blocks`
cases — caught by the suite, not by reasoning. Those forms are LISTS; only the
unbracketed-application mistake leads with a bare symbol.

Pinned in `test-error-messages.rkt`, including an assertion that the spec'd and
un-spec'd paths now report the SAME message (a test on either alone would have
missed the disagreement that was the whole defect) and the specced let-chain
control.

---


## ✅ RETIRED — PPN 4C tropical addendum: hybrid pivot scaffolding retirement — RETIRED-PER-D.4-CANONICAL (2026-05-14; header marked 2026-08-03)

**Status (2026-05-14)**: RETIRED. The hybrid pivot SCAFFOLDING never shipped. Under the D.4 architectural reframing (Cell/Propagator/Scheduler Orthogonality principle codified `6a628bc7`), the §13.6 Pre-0 spike (commit `7b681b9e`) directly measured the specialized cell type framework's fast-path performance and falsified the hybrid pivot's empirical motivation (Pre-0 R-19 extrapolation). The cell IS the live state under D.4 canonical — no scaffolding to retire later.

**Spike results that falsified the hybrid motivation**:
- W1+ specialized cell-write (with realistic dispatch overhead): **6.4 ns/call** (target ≤ 30 ns; ~4× under)
- W3 GC at 5×100k decrements: **0.000 ms major-GC** (target ZERO; structurally guaranteed by direct fixnum mutation)
- W3 alloc (10×100k decrements): **1.1 KB** (vs Pre-0 A7.3 struct-copy 6251 KB — **5700× memory improvement**)
- W4 specialized cell-read: **0.8 ns/call** (target ≤ 15 ns)
- W1+ + W4 per-decrement cycle: **7.3 ns** (target ≤ 45 ns)

**What this entry would have tracked** (preserved for historical record): under D.3 hybrid pivot, the per-decrement fuel-cost cell migration was scaffolded as off-network struct field (PRIMARY) + cell (DERIVED via lazy sync). The retirement was deferred to SH Series runtime infrastructure. The discipline added a four-surface tracking matrix (this DEFERRED.md entry + GitHub Issue #55 + D.3 §10.1.A retirement plan + Q-1B-6 falsification gate) to ensure the scaffolding wasn't forgotten.

**Why this is RETIRED rather than DELETED**: the entry serves as a record of the alternative design considered + the discipline applied. The discipline itself (four-surface tracking; falsification gate before locking in a principle-violating commit) is valid prophylactically for future tracks; this entry serves as a worked example. The "Hot-Load Is a Protocol, Not a Prioritization" pattern from DEVELOPMENT_LESSONS.org applies: don't delete the historical record of design alternatives considered.

**Cross-references**:
- [GitHub Issue #55](https://github.com/LogosLang/prologos/issues/55) — closed as "superseded by D.4 principled on-network design"
- [D.4 design doc](2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_DESIGN.md) §10 — D.4 canonical direct migration (replaces D.3 hybrid)
- [D.4 design doc](2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_DESIGN.md) §13.6 — Pre-0 spike plan + result
- [§4.6 Specialized cell type framework](2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_DESIGN.md) — the canonical D.4 architecture
- Spike implementation: `racket/prologos/benchmarks/micro/bench-specialized-cell-spike.rkt` (throwaway; commit `7b681b9e`)
- Spike result data: `racket/prologos/data/benchmarks/tropical-spike-d4-2026-05-14.txt`
- D.3 historical sections marked RETIRED-PER-D.4-CANONICAL: §10.1.A (Honest framing + retirement plan), §10.A (Threshold propagator role under hybrid), §10.B (Cell Staleness Contract), §14.4 Q5 (dual classification)
- [DESIGN_PRINCIPLES.org § Cell / Propagator / Scheduler Orthogonality](principles/DESIGN_PRINCIPLES.org)
- [DEVELOPMENT_LESSONS.org § Cell/Propagator/Scheduler Orthogonality](principles/DEVELOPMENT_LESSONS.org)

---


## ✅ CLOSED `10f5a080` — solver term conversion drops pvec/map literals (captured 2026-07-25, fixed 2026-08-02)

Not in the conversion functions the entry named. `ground->prologos-expr`
(reduction.rkt) filtered AST nodes through a HAND-ENUMERATED list of thirteen
predicates in front of an `unknown` fallback:

```racket
[(or (expr-zero? v) (expr-suc? v) … (expr-champ? v) (expr-lam? v) (expr-pair? v)) v]
[else (expr-fvar (if (symbol? v) v 'unknown))]
```

Maps and vectors were not on it, so they fell through and the fallback returned
the SYMBOL `unknown`, quietly. That is the exhaustive-walker shape `pipeline.md`
warns about, in a place nobody had looked for it — the third instance found this
session, after the `expr-foreign-fn` walkers and the mixfix raise sites.

Fixed structurally: `(expr? v)`. The fallback exists to catch RAW RACKET values
arriving from the solver's normalization boundary — strings, booleans, integers,
all handled just above — not to filter AST nodes. Every expr passes through now,
including the ones added tomorrow.

Verified for map, list AND pvec. The runtime row now agrees with the static row
type (`:v {:a 1}` under `{:v {:a Int}}`), which was the entry's real point:
this was the one place the two provably disagreed.

**Why it survived**: scalars were always fine. A test written with a string or
an integer literal passes either way, so the control case is in the test file
alongside the three that fail without the fix.

Unblocks the B3.2 FILL path, whose only reachable surface case this was
blocking.

---

## ✅ STALE — Rel T1 POL.9c: the `defr`-against-prior-multi-arity-`defn` direction is GATED after all (re-probed 2026-08-04)

**The premise is false at HEAD, so the PM 12/12B routing was unnecessary.**

The entry held that this fourth direction could not be gated because
"multi-arity base names live only in the ambient `current-multi-defn-registry`,
which carries no module provenance". Probed both spellings:

```
defn zzz | zero -> true | suc _ -> false     (with a spec, and without)
defr zzz [?x] || 1
  ⇒ defr zzz: zzz is already defined as a function/value in this module …
```

A multi-arity `defn` ALSO takes a local global-env binding, so
`global-env-lookup-local` — which is how the other three directions enforce
local-only — sees it, and `check-crosskind-collision` covers this direction
exactly like them.

And the entry's stated FEAR does not materialise: it worried that gating "would
fire on prelude multi-defns (`nth` and friends)" and break refer-import
shadowing. `defr nth` over the prelude's multi-defn runs clean at 0 errors and
answers the query — imports arrive through the cascade, not the module's own
binding, so the local-only gate correctly ignores them.

**Not bisected** — this may have been true when filed (2026-07-25) and closed by
later work, or the premise may have been wrong from the start. Recorded as
measured, without attributing a fix.

Two pins added to `tests/test-rel-t1-pol.rkt`: the gate in both `defn`
spellings, and an imported-multi-defn canary for the fear.

`current-multi-defn-registry` IS still a bare `make-parameter` holding a hasheq
(multi-dispatch.rkt:24) — a textbook on-network.md red flag, and still worth PM
12's attention. It just is not what blocks this gate.

### (original) the direction is UNGATED — routing to PM 12/12B

> Routed 2026-07-25: the blocker is the multi-defn registry's lack of module
> provenance, which PM Track 12 removes by bringing it on-network — see
> [PM 12B §11.4](2026-06-06_PM_TRACK12B_FREE_ORDERING_ON_NETWORK.md) item 1
> and 12B §7 Q3.

### Original entry

Q_B (defn/defr namespaces disjoint) gates three directions: `defr` over a local
`def`/`defn`, `def`/`defn` over a local `defr`, and a multi-arity `defn` BASE
name over a local `defr` (all at driver.rkt `check-crosskind-collision`).

The FOURTH direction — a `defr` whose name is already a **multi-arity `defn`** —
is deliberately **not** gated: multi-arity base names live only in the ambient
`current-multi-defn-registry` (multi-dispatch.rkt), which carries **no module
provenance**. Gating against it would fire on prelude multi-defns (`nth` and
friends) and so would violate the local-only rule that keeps refer-import
shadowing legal (the `lib/examples/foray.prologos` `xor` precedent).

**Unblocks when**: the multi-defn registry gains module provenance (i.e. moves
onto the per-module network like the def cells did in PPN 4C 4A) — at which
point the fourth direction can be gated with the same local-only discipline.

---


## ✅ RESOLVED (2026-07-25, X.close Batch C `cdb535ac`) — un-arm'd node → spurious "Multiplicity violation"

> **Root was NOT what this entry recorded.** The trigger was logged as
> `def := [validate …]`; probing showed `expr-validate` has a proper `inferQ`
> arm that DELEGATES to its subject — the subject (a map whose value was a
> LAMBDA) was the problem. `inferQ` carried an `expr-lam` arm only inside the
> beta-redex case, so a lambda in INFER position fell to the catch-all. Fixed
> by adding the arm (TYPE delegated to typing-core, USAGE mirroring checkQ).
> The class is promoted to BOTH tiers: `pipeline.md` checklist item 8 (ambient,
> actionable + the debug rule) and `DEVELOPMENT_LESSONS.org` § "infer / inferQ
> Are Twins" (the record). Kept below for the history.

---

## ✅ CLOSED 2026-08-03 — (historical) Un-arm'd AST node → spurious "Multiplicity violation" — 3rd data point (captured 2026-07-25)

**A recurring BUG CLASS, not a single defect.** When an AST node has no `inferQ`
arm, qtt's tu-error fallback propagates the failure and `checkQ-top` reports the
generic *"Multiplicity violation"* — a message with no relationship to the
actual problem. Three confirmed instances:

| # | Trigger | Status |
|---|---|---|
| 1 | `def m0 := {}` (CIU T6 F1a.2) | fixed |
| 2 | `def x := solve (…)` (Rel T1 POL.5, `485f4e7d`) | fixed |
| 3 | `def m := {:f [fn …]}` (first SEEN through `validate`, 2026-07-24) | ✅ fixed `cdb535ac` |

**Both actions are DONE — verified 2026-08-03, and the second was already
done when this entry was written:**

- *Fix instance 3* — landed at `cdb535ac` (the entry already carried the ✅).
  Re-probed at HEAD: all three triggers now define cleanly —
  `def m0 := {}` → `{ | _}`, `def m := {:f [fn [x : Int] x]}` →
  `{:f Int -> Int}`, `def x := solve (p ?a)` → `[PVec {:a Int}]`. No
  multiplicity violation from any of them.
- *Promote the CLASS* — **already present in BOTH required forms**, which is
  what `workflow.md` § "A promoted lesson gets TWO forms" asks for and what
  this entry was tracking:
  - the ambient one-liner in `.claude/rules/pipeline.md` § "New AST Node"
    item 8, carrying the debug rule verbatim and pointing down;
  - the full record in `DEVELOPMENT_LESSONS.org` § "infer / inferQ Are Twins —
    a Missing Arm Makes the DIAGNOSTIC Lie", with the three-instance table,
    the why-it-hides paragraph, and the structural fix direction.

  Nothing was owed here; the entry outlived the work. Worth noting because a
  "promote this" item that is silently already done is the same class of stale
  as a "this is broken" item that is silently already fixed — and this session
  has now found several of each.

**Original framing follows.**

- *(original)* Fix instance 3 — the same shape as POL.5's one-arm fix.
- *Promote the CLASS* to `DEVELOPMENT_LESSONS.org`: at 3 data points this is
  codification-ready. The lesson is diagnostic, not just corrective — **a
  "Multiplicity violation" on a `def` whose body is a non-lambda should be
  suspected as an un-arm'd node before it is believed as a QTT result.** The
  structural fix direction is the `pipeline.md` § "Exhaustive Walkers" answer
  applied to `inferQ`: a generic fallback that contributes zero usage rather
  than a tu-error, so a missing arm degrades to imprecision instead of a
  false failure.

---


## ✅ RESOLVED (2026-07-25, X.close ruling Q_N1) — the goal keywords now take the implicit solve

> **Owner ruled option (A)**: whitelist all three. `goal-keywords` in
> `parser.rkt` is `{rel, not, =, is}`, **derived from `run-solve-goal`'s
> dispatch set** so it cannot drift from the engine; `guard`/`cut` stay out
> because a top-level solve does not dispatch them either. `(not (blocked "c"))`,
> `(= 1 1)` and `(is q 5)` are now byte-identical to their explicit `solve`
> spellings (test-pinned, incl. def-RHS parity). The functional readings live
> on the bracket spelling — `[not true]`, `[= 1 1]` — which is the delimiter
> convention's own. One corpus line changed: `narrowing-demo.prologos`'s
> `(= ?x 5)`, whose comment was updated (it was already being used as a query).

### Original entry

**A real ergonomic hazard, not cosmetic.** POL.9's `paren-goal-stx?`
(`parser.rkt`) requires a **non-keyword** head (plus `rel`). `not`, `=` and `is`
are parser keywords, so at top level:

```
(not (blocked "c"))
;; => [reduce [(defr blocked …) "c"] | true -> false | false -> true] : Bool
```

— i.e. **functional Bool negation applied to a stuck goal term**, computing
nothing useful and reporting **0 errors**. A user who has internalized "parens
make goals" writes exactly this and gets a silently-useless answer. The explicit
`solve (not (blocked "c"))` works (it is the A.1 deliverable).

**Why it is the way it is**: the keyword exclusion is what protects `(match …)`,
`(+ 1 2)` and `(= ?x 5)` from being read as goals; `not`/`is`/`=` ride that
exclusion incidentally rather than by decision.

**Options** (needs an owner ruling, not a unilateral fix):
1. Whitelist the GOAL keywords (`not`, `=`, `is`) alongside `rel` in
   `paren-goal-stx?` — smallest change; makes the surface uniform.
2. Leave the exclusion and add a DIAGNOSTIC when a paren-`not` at command
   position wraps a goal-app (point at `solve (not …)`).
3. Document only (done — `.claude/rules/prologos-syntax.md` § Relational
   syntax now carries the warning).

Option 1 interacts with the functional `not` on Bool, which is why this is a
ruling and not a patch.

---


## ✅ CLOSED `790dfa53` — `current-relation-store` is not threaded into test-support or batch-worker (captured 2026-07-25, fixed 2026-08-02)

Threaded into both files the checklist names. The store is an immutable hasheq,
so re-binding the ambient value per call (test-support) and the post-prelude
value per file (batch-worker) is COMPLETE isolation: a `defr` inside builds a
new store and cannot escape.

`tests/test-relation-store-isolation.rkt` pins all three directions — nothing
leaks forward, the caller's binding survives a call, and register-then-query
within ONE call still works. 2 of its 3 cases fail against the previous commit.

**On the entry's own framing** ("worth treating as an architectural signal
rather than a seventh individual fix: the class recurs because the parameter
set is discovered by grep rather than declared in one place") — that is right,
and the architectural fix is still open. What this changes is that instance #7
is no longer silently live while the general answer is designed, and the leak
is now pinned by a test rather than by a grep that has to be remembered.

Note the same session closed the CELL-BACKED half of the identical class (the
cross-file spec-store leak, above). Two instances of one boundary, both live,
found from opposite directions — one by bisecting a flake, one by reading a
DEFERRED entry.

---

## ✅ RESOLVED (2026-07-25, `bb45d2a0`) — SC now has its regression test

> Three cases in `test-rel-t1-pol.rkt` run through `run-ns-ws-last`
> (== `process-string-ws`, the exact path SC fixed): a NAMED `solver` config
> with `solve-with` (the owner's literal blocker), inline `{overrides}`, and
> the `:semantics` key. Each asserts the "should have been expanded" failure
> cannot recur.

### Original entry

`19d9f8ae` fixed an owner-reported blocker (`process-string-ws` dropped
preparse-macro support, so `solver` configs failed in the REPL/LSP path) with
+12/−17 in `driver.rkt` and **zero new tests**. The commit cites "130 REPL/LSP/WS
tests pass" — that is pre-existing regression evidence, not a pin on the fixed
behavior. No test anywhere spells `solver cfg` / `:tabling` (grep = 0), so the
exact regression would not be caught again. Phase SC is also still 🔄 in the
tracker. `workflow.md` permits a no-test commit only for "refactor with zero
behavioral change"; this was a behavioral fix.

**Fix**: add a `process-string-ws` test that defines a named `solver` config and
runs `solve-with` against it.

---


## ✅ RESOLVED (2026-07-25, `bb45d2a0`) — the merge FUTURE-TRAP is test-pinned

> A layout canary in `test-rel-t1-pol.rkt` runs the nested-`not` form through
> the L2 path; if the merge winner flips to the srcloc-stripped tree surf, the
> column info is gone, the nesting collapses, and the test fails at the point
> of change rather than silently.

### Original entry

Adding a `defr` arm to `driver.rkt`'s `surf-source-line` / `same-form-type?`
(e.g. while extending the preparse/tree merge for an unrelated reason) would
silently flip the L2 winner for `defr` to the **srcloc-STRIPPED** tree-spine
surf, breaking POL.8's column-based layout grammar with no test failure at the
point of change. Named in design §8 prose; not filed, not test-pinned.

**Fix direction**: a test that asserts POL.8 layout still parses under
`process-string-ws` (the L2 path) would fail loudly if the merge winner flipped.

---
