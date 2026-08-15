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

# 2026-08-14 sweep — 23 discharged entries moved from `DEFERRED.md`

Moved at **EHP T1.close**, after verification. Numbers are **permanent and never
reused** (`DEFERRED.md` § NUMBERING), so a citation of any number below resolves
here. Their removal from `DEFERRED.md` lowers the highest heading there — which
is exactly why allocation must come from the **NEXT FREE register line**, never
from `max(heading) + 1`.

## How these were verified

Not by trusting the ✅. Two tiers:

- **Structural, all 23** — every commit cited by an entry was checked to exist
  and to be an **ancestor of HEAD**. All pass. ⚠ My first pass reported five
  entries citing missing commits; that was a bug in my own checker, and direct
  `git cat-file` on each hash showed all thirteen cited commits present. The
  instrument was wrong, not the register.
- **Behavioural, 5 of 23** — the entry's own reproducer re-run at HEAD:

  | # | claim | result at HEAD |
  |---|---|---|
  | 134 | `[p1:Point p2:Point]` mis-parses as one greedy `type_application` | **2** `typed_param` nodes, 0 errors ✅ |
  | 136 | `key_op` cannot parse the `^-` family or `^..` | both parse at 0 errors ✅ |
  | 135 | select-block branch names paint `@variable`, not key chrome | all four paint `font-lock-property-use-face` ✅ |
  | 102 | a preparse error after a successful `data` is a WHOLE-FILE abort | partial output + **one** per-command error ✅ |
  | 66 | a compound `\|\|` fact row is SPLAYED into fabricated rows | **one** row each, not 2 and 3 ✅ |

- **The remainder are rulings, probes, or fixes without an independently
  runnable reproducer.** They are moved on the strength of the structural check
  plus their recorded evidence, and that is stated rather than implied.

⚠ **Two adjacent observations from 66's reproducer, NOT part of its filed
defect** and not yet triaged: `defr r3 [?a] / || '[1 2]` then `(r3 q)` returns
`{:q unknown}` rather than the list, and both queries render a type of
`[PVec {:q <error>}]` — an `<error>` in the TYPE at **zero errors**. The splay
that entry 66 filed is fixed; these are something else.

---


### 36. ✅ RESOLVED (2026-08-01, at the P4c-3 opening) — BOTH DOORS PROBED, BOTH CLEAN

**Nobody in the arc tested this, including the main session.** Every probe went
through exactly two doors: `read-all-forms-string` and `process-file`.
`pipeline.md` documents a whole failure class where a reader artifact in a CACHED
module body detonates only when that body is first re-linked or beta-reduced,
with a misleading error arbitrarily far from the cause, and warns the gap "stays
latent until the node first appears in — or is first INVOKED from — a cached
module body". `$bcast-step` has no `pnet-serialize.rkt` registration and no
`access-sentinel?` membership. Separately, `CLAUDE.md`'s two-context audit rule
names the elaboration-vs-module-loading seam as the permanent architectural
boundary, and `repl.rkt` / the LSP have their own reader entry points — nobody
checked whether the post-pass runs on them at all. **PROBED, and the answer is clean on both doors.**
- **REPL/LSP door**: `process-string-ws` handles a fused param (`f : Int -> Int
  defined.`), a private-suffix form (`p : Int -> Int defined.`) and a broadcast
  (inert, honest error) — identical to the `process-file` door. Structural
  reason: `transform-let-blocks-elems` has a SINGLE call site inside the reader
  (parse-reader.rkt, in `tree-node->stx-elements`), which both doors traverse.
- **`.pnet` door**: a lib carrying `defn f [n:Int]`, `defn- helper [x:Int]` and
  `def base:Int := 41` was compiled cold, cached (4088-byte artifact under
  `data/cache/pnet/`), and re-read warm twice — results identical every time
  (`2 : Int` / `41 : Int`). **Decisively: `strings` on the cached artifact finds
  ZERO `bcast-step` occurrences**, i.e. the unwrap runs BEFORE serialization and
  no reader sentinel can enter a cached body. That is the specific `pipeline.md`
  failure class this item was raised against, and it does not apply.
⚠ One honest note on method: the first run of this probe reported "no .pnet
produced" because I looked next to the source file; the cache lives under
`data/cache/pnet/`. The artifact had been written all along. Test artifact
removed after the probe.

⚠ **THIS ✅ IS SCOPED TO THE EMPTY ENABLE-SET AND DID NOT SAY SO** (noted
2026-08-02 at the P4c-3 close). The `.pnet` conclusion holds *because the unwrap
is currently TOTAL*; the REPL/LSP structural argument is independently sound (it
is about which door is traversed) but says nothing about what SURVIVES. At the
first grant a surviving sentinel CAN reach a cached body and `pipeline.md`'s
unregistered-node failure mode — a silent raw VECTOR from the reader's
unknown-tag fallback, detonating arbitrarily far away — becomes live.
**Re-probe at the grant; do not inherit this ✅.** Note the item's own text
already records that `$bcast-step` has no `pnet-serialize.rkt` registration.

---

### 42. ✅ RESOLVED at D4.P4d-0 (`667684ad`, 2026-08-05) — the WRAPPING mint landed (one shared trigger, both groupers, Q_N3 v2 row); Q_U7's second canonical example is producible. *(original text below)*

---

### 43. ✅ RESOLVED 2026-08-04 — folded into P4c-4c by owner ruling. THE STRICTNESS TIER NOW FOLLOWS THE ω UNWRAP

**Fixed in two halves.** Typing: `select-tier-subject` peels one container layer
per LEADING ω step, so the tier sees the type the ω step unwraps to. (Non-ω
nesting never had the bug — Q_U13's NEST encoding gives every level its own
`expr-select` node with its own tier; verified, `x.inner.a` over a Map is loud.)
Reduction: `champ-of` now TIER-FORKS three ways instead of panicking
unconditionally, mirroring `project` beside it.

⚠⚠ **THIS ENTRY'S OWN DEFERRAL RATIONALE WAS FALSE, and the adversarial verify
caught it.** The text below said *"the grant is `'()`, so nothing here is
reachable in production."* The `champ-of` half was **always** production-reachable
with no grant: the `expr-select` entry admits **rrb** subjects into `select-reduce`
BEFORE the `definitely-not-map?` fork, and `expr-rrb?` is not a member of that
predicate (only `expr-hset?` is). So `ub.a` where
`ub : <[Map Keyword Int] | [PVec Int]> := @[1 2 3]` reaches `champ-of` on the
ordinary dot path — where it used to PANIC "invariant violation", itself wrong,
since the union's Map branch is exactly why typing admitted `.a`.
⚠ And my FIRST fix degraded it to `<error>`, giving a **third answer to a
two-answer question**: three adjacent union-non-map cases answered `none`,
`<error>`, `none`. Corrected to `none`, agreeing with `definitely-not-map?`'s
sibling ("Match `map-get`: degrade to `none`"). Pinned, no-grant.

**Residuals, filed rather than fixed** (see 48, 49). Original text retained below
because the false rationale is the lesson.

---

### 45. ✅ RESOLVED at D4.P4d slice 2 (`ba1c055d`) — fixed STRUCTURALLY, not patched

> ⚠ **Re-homed at the P4d close (2026-08-08).** This carried no status glyph while
> D4 §5.P4d's slice-2 record already said *"DEFERRED 45 fixed structurally:
> `select-branch-top-keys`' bcast arm answers `(list (select-step-output-name s))`
> — check ≡ meaning by shared computation"*, with the verify's OLD-vs-NEW-vs-consumers
> table finding zero divergent shapes. The divergence cannot recur because the two
> sides are now ONE computation. *(original below)*

```
branch ((@bcast 0) name)  →  top-keys = (name)   output-name(head) = #f
branch ((@bcast a) b)     →  top-keys = (a)      output-name(head) = a   ← agrees
```
`select-step-output-name` delegates to the inner step, which answers `#f` for an
ordinal; `select-branch-top-keys` recurses with `rest` and reaches the deeper key.
⚠ The NON-ω twin is consistent — the bare-number arm descends transparently,
mirroring top-keys — but the new ω arms do not. **Unobservable today** (the label
is discarded under `'path`, and block-position ω is parse-refused), so this is a
note, not a defect. Goes live with P4d or P5's factoring, and the failure mode is
the silent mis-sort P4a exists to prevent.

---

### 46. ✅ RESOLVED at D4.P4d-0 (`667684ad`) — Q_U20 in both lifts (sub-inner assembles at 'block, always); the top-keys splice (B1) and the binder unwrap defeat (B2) fixed + pinned in all grades. *(original + cross-ref below)*

---

### 47. ✅ RESOLVED at D4.P4d slice 4d-2 (`25f3f22d`) — the broadcast axis landed; ≡ 59.1

> ⚠ **Re-homed at the P4d close (2026-08-08).** This carried no status glyph. It is
> the SAME defect as **59.1** (the equivalence was probe-verified, and neither entry
> cross-referenced the other — the 40≡46 shape). Both shipped together: a
> `'bcast-elem` wrapper for the PVec/Map carrier plus a broadcast AXIS on
> `format-select-fail`, so the message now names the broadcast and says *"each
> element"* rather than misattributing to *"the subject"*. Cited at four sites in
> `typing-errors.rkt`. *(original below)*

`@[]` infers `[PVec _]`, so the inner step meets an unsolved meta and reports
"the subject … is not a record, so it has no fields to access". Per-command, file
continues, no fabrication — correct behaviour, imprecise message (the subject is
an unsolved element meta, not a non-record). Pre-existing wording from
`select-project-field`, surfaced by ω rather than caused by it.

---

### 48. ✅ RULED 2026-08-05 [owner] — KEEP THE WHOLE-NODE ABORT UNIFORM

**The ruling: uniform.** A miss inside a broadcast aborts the whole selection on
EVERY tier, including the permissive one. No change to the code; the ratified
Q_U7 rider stands unamended.

**The argument that lost, recorded because it is real** and will be re-raised
otherwise: the rider is justified by *"no `expr-panic` buried in an output
slot"*, and on the permissive tier there is no panic — the value is `none`,
which the language produces deliberately everywhere else. So the rider's stated
concern is structurally absent there, and the cost is measured: `ws:a` yields
`none` where `[pvec-map [fn [m] m.a] ws]` yields `@[1 none]` — and `pvec-map` is
the spelling broadcast's OWN diagnostic recommends.

**The argument that won**: ⭐ **the tier is INFERRED, not written.** Per-tier abort
semantics would make identical source text preserve surviving elements or not,
based on something the reader of that source cannot see. Uniform abort is
predictable; per-tier is not — and predictability of a surface construct beats
recovering data in a case the user cannot identify from the text. The rider was
also pinned specifically so a "map semantics" intuition could not drift it later,
and the drift being proposed was exactly that.

**Consequence to state honestly in docs**: on a permissive carrier, broadcast
loses data that `pvec-map` would keep. That is a KNOWN and ACCEPTED cost, not an
oversight, and the diagnostic that recommends `pvec-map` is therefore also
recommending the more forgiving spelling — which is fine, but should not be
described as "equivalent".

*(original entry retained below)*

---

### 51. ✅ FIXED 2026-08-05 (commit `e0f03601`; message only, owner-ruled option (a)) — the parenless `&>` guard blamed dot-access for a condition that is not dot-access

**⚠ The filed diagnosis was WRONG in its load-bearing half, corrected by
re-measurement.** As filed this read as a G2 regression ("the relation goes
defined → undefined"). It is not. The **relation loss is PRE-EXISTING**: the
same clause shape spelled with dot-access instead of broadcast behaves
**identically** at pre-G2 (`0fd2098c`) and at `b429d038` —

```
defr dotbare [?a]
  &> base users.name 2
(dotbare q)
```
→ guard fires, relation never registers, `solve: Unknown relation: dotbare`,
file continues — **byte-identical on both legs** (fresh-file A/B, 2026-08-05).
G2 only added *broadcast* to a trigger set that already contained dot-access and
postfix-index (`xs[0]`); all three verified at `b429d038`.

**Root cause (verified by instrumenting `parse-clause-content`)**: `macros.rkt`
strips every top-level form to a bare datum before preparse
(`(define datum (syntax->datum stx))`, :3168) and the `defr` arm rebuilds with a
**3-arg** `datum->syntax` (:~3391), so every inner element inherits the `defr`'s
own line/column. Measured: a healthy clause has sentinel col 2 and element cols
`(5,5) (5,10) (5,13)`; a rewritten one has **every element at `(6,0)`**, and
`parse-clause-content`'s `(zero? sent-col)` test routes to `parse-degraded`,
which only accepts fully-parenthesized goals.

This is a **NAMED, EYES-OPEN POL.8 LIMIT**, not an accident — the Rel T1 design
doc says so verbatim ("degraded srclocs … are DETECTED via the impossible
sentinel-column-0 marker: all-paren parses as before, parenless errors with
guidance") and it is test-pinned at `test-rel-t1-pol.rkt` ("POL.8: degraded
srclocs (preparse rewrite) + parenless goals → guidance").

**Owner ruling 2026-08-05: option (a)** — keep the limit, fix only the message.
The message now names the CONDITION (a preparse rewrite anywhere in the defr)
and all three families, instead of "(e.g. dot-access)". Note "teach the guard
about `$bcast-step`" would have been wrong by construction: `pol8-goal-pair?`
requires a *pair*, so `&> base users:name` fails on the bare head `base` before
any sentinel is consulted.

**Still open, deliberately** (pinned as status quo so a change is conscious):
- **(b)** the refusal takes the relation's registration with it. Prior art for a
  better shape already exists — the floundering gate produces *"Unknown relation:
  unsafe-r — its defr failed to register (see the earlier error)"*. Registering
  the relation with only its GOOD clauses is refused: that would be a silent
  wrong answer.
- **(c)** ✅ **DONE 2026-08-05 — the limit is LIFTED for `defr`.**
  `rebuild-preserving-locs` (macros.rkt, above `preparse-expand-all`) re-attaches
  srclocs AFTER expansion by walking the original syntax tree against the
  expanded datum: unchanged subtree ⇒ reuse the original syntax object; same-shape
  lists ⇒ align by common prefix/suffix and recurse; changed middle ⇒ anchored on
  the first original element it replaced. Applied at the **`defr` arm only** —
  that is where the tree's only LAYOUT-DRIVEN grammars live (POL.8 clause
  grouping reads element columns; the `||` splitter reads the sentinel's line).
  All four rewrite families now parse in a parenless clause, and DEFERRED 66's
  dominant residual closes with it.
  ⚠ ~~Still limited: a bare top-level `rel` … still degrades~~ **✅ CLOSED same
  day (owner-requested): the `[else]` arm now uses the helper too**, so a bare
  top-level `rel` takes parenless goals with a rewrite, grouped identically to a
  rewrite-free control (test-pinned). POL.9's property contract is carried by the
  helper — its list rebuild and fallback are both 4-arg against the original stx,
  so `prologos-paren-origin` survives exactly as the old direct rebuild kept it
  (probed: `(p2 1:Int 2:Int)` still errors as a goal; `(fruit-color f mm.k)`
  still implicit-solves).
  ⚠ ~~The one spelling still degrading is UNPARENTHESIZED `def r := rel …`~~
  **✅ CLOSED same day (owner-requested): the DEF arm too.** Both of that arm's
  degrading paths now route through the helper: the `def-rhs-stx = #f` fallback
  (multi-element RHS — the measured target; also serves `defn`) and branch (b)
  (single-element rewritten RHS — so a paren `(rel …)` RHS containing a rewrite
  keeps its clause layout, pinned rows-based). The Q_C contract is untouched by
  construction — no `prologos-defrhs-command` is stamped on the multi-element
  path today, the helper never mints properties, and the [else] verify's
  exhaustive property inventory (2 properties, 3 readers, all
  position-restricted) covers the def arm too.
  **Measured post-fix semantics of the unparen spelling, eyes open**: the clause
  PARSES, and the spelling then routes into the PRE-EXISTING POL.9b def-seam gap
  ("Expression is not a valid type" — a bare multi-token RHS is
  application/value by Q_C, and a def-bound rel VALUE infers a hole type), i.e.
  exactly what `def bad := (dbl 3)` is already pinned to produce. Consistency
  with the sibling spellings; the misdirecting "parenthesize each GOAL" refusal
  (when the actual fix is parenthesizing the REL) is gone. The seam gap itself
  remains its own pinned item ("Pinned so a future diagnostic fix shows").
  ⚠ ~~With all three arms converted, the POL.8 guard now has NO known reachable
  trigger~~ **REFUTED by the def-arm adversarial verify within hours, and the
  claim itself was the error** (3rd "family is closed" claim to fall this arc —
  see the dailies Watching entry). The guard fires on a bare top-level
  **`let r := (rel …)`** with parenless clauses and ZERO rewrites in the source
  (measured, 6-line reproducer). Mechanism, from the helper's own algebra: `let`
  goes through the CONVERTED [else] arm, but its desugar is a TOTAL RESHAPE
  (`let` → nested `fn` application through the one funnel), so no prefix/suffix
  alignment at any list level can recover the `rel` subtree — it moved both
  position and depth. ~~That is precisely the case DEFERRED 68's real-diff … is for~~
  **✅ CLOSED same day (owner-requested), and the instrumentation REFINED the
  diagnosis**: the desugar `(let r := V body) → ((fn (r : _) body) V)` is a
  reshape, but V survives DATUM-IDENTICAL — it only MOVES (element 3 → element
  1). So the fix is not a real diff: `rebuild-preserving-locs` gained a
  RELOCATION step — before stamping a changed middle, pair each COMPOUND
  expanded element with a datum-equal original middle element when the match is
  unique IN BOTH DIRECTIONS, and recurse (datum-equal ⇒ the original stx comes
  back wholesale). Guards, each load-bearing: compound elements only (identical
  atoms are everywhere — a false pair attaches the WRONG LINE, the mis-grouping
  class this arc keeps paying for); uniqueness on the original side (two
  identical goals on different lines must not swap locs); uniqueness on the
  expanded side (a duplicated output must not take one loc twice). Ambiguity ⇒
  stamp, exactly as before — monotone by construction.
  Pinned equality-with-the-PAREN-control (same semantics, parenless vs paren
  spelling), single-goal and two-sibling-goal shapes. Genuine moves that are
  ALSO rewritten, or ambiguous duplicates, still stamp — DEFERRED 68's real
  diff remains the durable answer for those.
  ⚠ **A 5th member exists and is pinned as a KNOWN LIMIT (not fixed):
  SIBLING-LET chains** (`let x := 5` / `let r := (rel …)` / body) — found by
  self-probe minutes after the let-leg landing, per the Watching-4 discipline.
  `merge-toplevel-sibling-lets` FUSES the siblings' stxs into one datum
  (`(map syntax->datum unit)` → a merged nested let), so its rebuild has TWO
  source trees; single-source alignment and the one-level relocation step
  structurally cannot recover the second sibling's subtrees. Closing it needs
  NEW machinery — either an stx-carrying `merge-sibling-lets` (the merge
  helpers currently test datum shapes throughout) or deep multi-source pool
  relocation in the helper — a design step, deliberately not improvised
  mid-arc given that every clever alignment extension this arc introduced a
  silent mis-parse caught only by adversarial verification. The guard's honest
  message covers it meanwhile.
  ⚠ **The relocation verify's census (2026-08-07) — the full member list, so no
  future "family is closed" claim is needed**: FIXED = single-binding direct
  `let` spellings (`:=`, bare, multi-line value, two sibling goals), `defr`,
  `[else]` (bare `rel`, goal keywords), `def`/`defn`. STILL DEGRADING, all LOUD,
  all pre-existing: sibling-let chains (above), bracket-form
  `let [r := (rel …)]`, aligned-block bindings (relocation never reaches
  `$let-block` innards), defmacro-EXPANDED rel RHS (rewritten ⇒ relocation
  correctly refuses), moved-AND-rewritten subtrees. Perf: Δ≈0 on 200 lets.
  ⚠ **One CONFIRMED latent false-pair** (re-measured): a user lambda
  datum-identical to the let funnel's minted `(fn (name : _) body)` wrapper —
  with the peel having consumed the true twin — relocates the MINTED node to the
  user node's plausible locs, defeating both uniqueness guards. Today this
  demotes the precise guard message to a generic "Could not infer type" (a rel
  in a lambda body does not type, so no wrong answer is expressible); **it goes
  live as a silent-misgroup hole the day lambda-body queries type — Rel T2's
  purity ruling MUST revisit this** (the code comment at the relocation site
  says so too). "Monotone by construction" is qualified in place: monotone in
  srcloc quantity, not detectability.
  ⚠ **Bodyless goal-RHS let** (`let r := (rel …)` with NO body): the paren
  spelling yields a STUCK `(rel [1] ...) : _` with 0 errors on both legs
  (pre-existing control defect — POL.10's snapshot semantics never fire); the
  parenless spelling now MATCHES that control, converting its old loud guard
  error into the same silent stuck value. Equal-to-control per the pin
  criterion, but the control looks broken — owner look wanted on the bodyless
  semantics.
  ⚠ Also from the same verify: branch (b)'s "a mis-grouping would surface as an
  arity error, not a row" pin-strength argument is TOO STRONG — in DEFERRED 68's
  peel-residual zone (rewrites in BOTH goal lines) with a relation of the merged
  arity registered, the def paren-RHS spelling solves SILENTLY (@[] under a
  mis-grouped 5-ary reading; control errors pairr/2). Pre-existing — byte-identical
  at the pre-51(c) base — but the def spelling belongs on DEFERRED 68's list of
  reachable-through spellings, and the rows-based pin covers the single-rewrite
  case only.
  ⚠ Blast radius of what landed is **narrow**: the `let` aligned-block classifier
  and `||` multi-row splitting already survived a rewrite (the reader's indent
  grouping builds them pre-preparse), so `parse-clause-content` and the fact-row
  splitter were the only consumers re-deriving layout AFTER preparse.
  **Two silent MIS-PARSES were introduced and fixed during development**, both
  found by measurement, both now regression-pinned — see the 51(c) note under
  DEFERRED 66's residual 1 and the tests in `test-rel-t1-pol.rkt`.

---

### 52. ✅ FIXED 2026-08-05 (commit `e0f03601`; owner-ruled) — a type error in relational GOAL-ARGUMENT position was silently swallowed

**⚠ The filed A/B was a MIS-DIAGNOSIS.** As filed: "a goal-position arity error
becomes a silent empty bag". Re-measured against a pre-G2 baseline worktree:

- Pre-G2, `a:b` was **spliced into two tokens**, so a 2-argument call was
  reported as `p2/4`. That "loud arity error" was **itself a symptom of the
  splicing bug** — the diagnostic was a lie. G2 made arity counting CORRECT
  (`(p2 1:Int)` → `p2/1`; `(p2 1:Int 2:Int 3:Int)` → `p2/3`). Nothing to restore.
- The silent empty bag is **not new and unrelated to broadcast**: pre-G2,
  `(p2 1:Int)` already returned a silent `@[]`, and `[+ "str" 1]` /
  `[undefined-fn 1]` in goal-arg position are silent on **both** legs.

**The actual defect** (found by instrumenting `infer`): the "Goals → Goal" and
solve/explain arms of `infer` (typing-core.rkt) called `infer` on goal arguments
purely for effect and returned a fixed type, **discarding an `expr-error`
result**. `infer` signals type failure by RETURNING `(expr-error)`, not by
raising. So an ill-typed argument became an opaque term that unified with
nothing → empty bag, zero errors. The same expression is LOUD in `def` position
and as a bare expression command:

```
(q1 [+ "str" 1])     → @[]  zero errors        def z := [+ "str" 1] → ERROR
(q1 1:Int)           → @[]  zero errors        1:Int (bare)         → ERROR
(is x [+ "str" 1])   → @[{:x unknown}]         ← a bogus BINDING, worse than @[]
```

**The fix** propagates the error, gated on **logic-var freedom**. That gate is
load-bearing and was learned the hard way: an ungated first version broke the
pinned POL.9 test "a preparse rewrite inside a paren goal keeps goal-ness",
because under the relational fallback a bare name is a LOGIC VARIABLE — so in
`(fruit-color f mm.c)`, `mm` is a logic var and `mm.c` is genuinely
un-inferrable **without being a user error** (the documented "computed goal args
don't evaluate" semantics). Rule applied: **propagate only from EVALUATED,
logic-var-free positions**.
- `expr-goal-app` args — evaluated (`(q1 [+ 0 1])` → `@[{}]`) ⇒ propagate
- `expr-is-goal` RHS — evaluated (`(is x [+ 1 1])` → `{:x 2}`) ⇒ propagate
- `expr-unify-goal` — **NOT** tightened: `=` does not evaluate at all
  (`(= x [+ 1 1])` and `(= x [+ "str" 1])` both render `{:x unknown}`), so its
  operands are TERMS and rejecting one would be inconsistent.

**⚠ THE GATE HAD TO BE WIDENED TWICE — an `expr-error` out of the IMPERATIVE
`infer` has THREE meanings, not two.** The adversarial verify found three live
over-rejections in the first version of this fix, all of which the full suite
(9863 tests) passed straight through:

| input | before the fix | first fix | why |
|---|---|---|---|
| `(q1 [pair 1 2])` | `@[]` | **ERROR** | `infer` has NO `expr-pair` arm — it types pairs only in `check`, against an expected Sigma. The ON-NETWORK inferencer has a rule, and the command boundary tries on-network FIRST, so `def z := [pair 1 2]` succeeds (`[Sigma Int Int]`) while goal args — which reach the imperative inferencer only — did not. |
| `(is g2 [int* _ 2])` | binds a closure | **ERROR** | a partial-application section types only in CHECK position, and an `is` RHS is inferred with no expected type. It also escapes the logic-var gate BY CONSTRUCTION: the elaborator turns the relational fallback OFF for an `is` RHS, so `_` stays an `expr-hole` rather than becoming a logic var. This is the idiom `prologos-syntax.md` explicitly RECOMMENDS. |
| `solve (guard [lt 0 1])` | stuck term | **ERROR** | the 1-arg form elaborates to `(expr-guard ec #f)`; the pre-fix arm called `(infer ctx #f)` and DISCARDED it. Every other walker over this struct carries `(and goal …)`; this arm now does too. |

So the excuse predicate is `goal-arg-excused?`, not "contains a logic var": an
argument is excused if it contains a logic variable **or** a node the imperative
`infer` cannot synthesize (`infer-unsynthesizable?` — `expr-pair`, `expr-hole`,
`expr-reduce`, `expr-refl`). That set is **DERIVED, not guessed**: it is exactly
`{nodes with register-typing-rule!} \ {nodes with an imperative infer arm}`
minus `expr-error`, computed mechanically — and `test-goal-arg-typing.rkt`
**recomputes it from source and fails on drift**, so a future
`register-typing-rule!` cannot silently widen the class and reintroduce the
`expr-pair` shape under another node name.

`goal-arg-excused?` is a **generic reflective walk**, not a hand-armed one
(`.claude/rules/pipeline.md` § Exhaustive Walkers). reduction.rkt's
`collect-deep-logic-vars` was unusable for this: it arms only 4 node kinds behind
an `[else '()]` catch-all and has **no `expr-select` arm**, so it reports "no
logic vars" for `mm.c` — the exact form the predicate exists to recognise.
⚠ Its own honest limit: the walk covers struct / pair / vector / hash / set / box,
so it cannot miss a NODE kind, but a sub-expression reachable only through some
other container type would be missed. None exists today.

**Named residuals** (real, out of the ruled scope):
- **The gate's WHOLE-ARGUMENT granularity is now BIMODAL, which reads as
  nondeterminism.** Two clauses with the SAME type error diverge on whether a
  logic var happens to sit beside it:
  `&> (fc x [+ "str" 1])` → the defr is DELETED;
  `&> (fc x [+ "str" y])` → registers, query returns a silent `@[]`.
  Pre-change both were silent — the residual existed but its consequences were
  UNIFORM. Sharpened by the adversarial verify, and it is the strongest argument
  for the subterm-granularity fix below.
- An argument containing a logic var AND a genuine type error stays silent
  (`(q1 [+ "str" ?x])`) — the gate is deliberately conservative, and since a goal
  argument that mentions a variable is the NORMAL relational shape, the fix is
  live mainly on fully-ground arguments. Worse sub-case found by the verify:
  `(not (q1 [+ "str" ?y]))` returns `@[{}]` — the ill-typed inner goal silently
  fails to match, so the NEGATION succeeds. A wrong positive, not just a lost
  diagnostic. Pre-existing (all of these were silent before), but the right
  long-term fix is to test logic-var-freedom at the FAILING SUBTERM rather than
  at the argument root.
- ~~`expr-clause` / `expr-fact-block` / `expr-fact-row` still discard sub-errors~~
  **✅ FIXED same day, owner-requested** (see below). Those three plus
  `expr-defr`, `expr-defr-variant` and `expr-rel` now propagate, so an ill-typed
  goal in a `defr` clause BODY is loud at registration. ⚠ The consequence, stated
  eyes-open: this **widens the class of `defr`s that fail to register**, which is
  51(b) territory pointing the opposite way — 51(b) frames registration-loss as
  the problem and names a better shape (the enriched *"its defr failed to
  register (see the earlier error)"* message) as prior art. Owner-directed, so
  not illegitimate, but the two entries pull against each other until 51(b) is
  taken. Adopting that enriched message would reconcile them.
  ⚠ `expr-fact-row`'s propagation is **inert for compound terms** — they are
  splayed at parse time before typing sees them (DEFERRED 66).
  ⚠ Still swallowing, same shape, no repro constructed: `expr-narrow`.
  ⚠ **The rejection now NAMES the relation** — `defr badclause: Could not infer
  type — the relation was NOT registered` — because the bare form gave a
  whole-relation deletion with no pointer to which `defr`. The QUERY-side message
  is still the bare `Unknown relation: badclause` (misleading — they DID define
  it) rather than the enriched *"its defr failed to register (see the earlier
  error)"* that the schema/floundering gates get. Reaching that branch needs the
  name env-bound to an `expr-defr`, i.e. an env write carrying a body that FAILED
  to type — which `zonk` may not survive (DEFERRED 67). That reconciliation is
  51(b)'s job.
- `(= x [+ 1 1])` rendering the binding as `unknown` is its own pre-existing
  display defect; pinned as status quo.
- `expr-guard`'s CONDITION is checked with `check`, whose boolean result is
  discarded, so an ill-typed guard condition behaves exactly like `guard true`
  (`(guard [+ "str" 1])` succeeds). Pre-existing; unreachable in practice today
  because `expr-clause` swallows it first.

---

### 55. ✅ DISCHARGED at D4.P4d-0 slice 5 (`77259635`) — the spurious-dot display fixed (one pp arm honouring `first?`) and the vector-element refusal now names the broadcast alternative. *(original below)*

---

### 59. ✅ RESOLVED at D4.P4d slice 4d-2 (`25f3f22d`) — BOTH members; 59.1 ≡ 47

> ⚠ **Re-homed at the P4d close (2026-08-08).** It was homed on *"P4d slice 4's
> diagnostics batch"*, which has since completed. **59.1** (the misattributed
> subject) is the SAME defect as **47** and shipped with it. **59.2**
> (`not-indexable`'s `x{k}` remedy off-key inside a broadcast) also shipped — the
> remedy moved INTO the `cond` that knows the carrier, is broadcast-aware, and is
> suppressed entirely where nothing true can be said. ⚠ Note the plan's claim that
> *"the existing cond already discriminates the right three cases"* was FALSE: the
> cond discriminated carrier kind and the remedy sat in the unconditional tail.
> *(original below)*

Both pre-existing, both surfaced while pinning the carriers; natural riders on
P4d slice 4's diagnostics batch.

1. **The `@[]` / meta-element broadcast refusal misattributes the subject.**
   `def emp := @[]` types `[PVec _]`; `emp:t` refuses with *"select: the subject
   is not a record, so it has no fields to access"* — which describes the (meta)
   ELEMENT as "the subject", names neither the broadcast nor the key, and carries
   no branch. Refusal is the monotone-safe direction; the wording is the defect.
2. **`not-indexable`'s remedy is off-key inside a broadcast.** An ordinal inner
   over a row carrier (`evs:0`) correctly names the position and the failure, but
   the appended advice is *"select named fields instead (`x{k}`)"* — the spelling
   for the NON-broadcast case. Inside a broadcast the fix the user wants is
   `evs:t`.

---

### 64. ✅ RESOLVED at D4.P4d slice 4c (`a31b7475`) — both gates now name their remedy

The open-schema arm says the admitted form is `:closed`; the collided-selection
arm says "This is a SELECTION — a capability-restricted view" and offers no
list conversion. Both are battery-pinned ("an OPEN schema is told the one thing
that fixes it", "a collided SELECTION is told it is a view"). *(original below)*

The resolver refuses an open schema and a name-collided selection, and both fall
through to the generic `bcast-carrier` message. Neither says the thing the user
needs:

1. **open schema** — the remedy is literally "add `:closed`", and no message
   says so.
2. **collided selection** — it gets the generic carrier refusal, which
   `select-row-of`'s own comment calls "a LIE — a view is a record, restricted",
   and which offers `pvec-from-list` / `pvec-map`, both wrong for a view.
   `select-row-of` already has the honest bespoke message; the broadcast path
   does not reach it. The resolver argues the selection case at length in a
   comment and emits none of it.

⚠ The collision pin asserts only the ABSENCE of the leaked value, so neither
gap can be caught by the battery today. Both are `bcast-carrier` per-carrier
split work — slice 4c.

---

### 66. ✅ FIXED 2026-08-05 — a compound term in a `||` fact row was SPLAYED into fabricated rows (pre-existing silent WRONG ANSWER)

> ⚠ **Renumbered 53 → 66 at the merge-back** (2026-08-08). It was **53** on branch `wizardly-mendel-2fd502`, where it collided with a DIFFERENT `main` entry of the same number. Commit messages and any code comment saying "DEFERRED 53" from that branch mean THIS entry.

Measured, **byte-identical at `b429d038` and after the DEFERRED 51/52 work**, so
this is neither caused by nor fixed by that arc:

```
defr r2 [?a]
  || [some 1]
solve (r2 q)        →  @[{:q unknown} {:q 1}]        ← TWO rows, from ONE

defr r3 [?a]
  || '[1 2]
solve (r3 q)        →  @[{:q unknown} {:q 1} {:q 2}] ← THREE rows, from ONE

defr r4 [?a ?b]
  || {:k 1} 2       →  ERROR: defr facts: 3 terms do not fill rows of arity 2
```

**This is the silent-wrong-answer class, not a lost diagnostic**: the query
returns rows that were never written, with ZERO errors, and the fabricated
values (`unknown`, then the constituent tokens) are indistinguishable from real
data. `r4` is the only arity that gets caught, and only by accident — the splay
happens to make the term count wrong.

**Mechanism** (suspected, from the CIU T6 grounding critic's G5 — verify before
fixing): `parser.rkt`'s fact-row splitter partitions on `term-sentinel?`, which
is a **numeric-literal whitelist** (`$nat-literal`, `$decimal-literal`,
`$float-literal`, `$exp-literal`, `$posit-literal`). Anything else that is a
compound pair is treated as a NESTED ROW and splayed. The polarity is the same
as `pattern-var?`'s — the fix is inversion (a conservative default), not adding
another member.

**Why it stayed hidden**: `grep -rn "^\s*||.*("` over `examples/` and `lib/`
returns **zero** compound fact terms, so nothing in the corpus or the suite
exercises it. The DEFERRED 52 fix added `expr-fact-row` propagation, which is
therefore **inert for compound terms** — they are splayed into individually
well-typed atoms before typing ever sees them. That propagation is not wrong,
just currently unreachable by this shape; it is recorded here so nobody reads it
as coverage.

**Also noted from the same probe** (separate, smaller): a `3.14` or `nil` fact
row renders as `unknown` in a solution row — pre-existing, unrelated to the
splay, and probably the same display gap as `(= x [+ 1 1])` → `{:x unknown}` in
DEFERRED 52's residuals.

---

#### THE FIX (2026-08-05) — two changes, and what each one buys

**(A) `term-sentinel?` INVERTED.** It was a five-member numeric whitelist
(`$nat-literal`, `$decimal-literal`, `$float-literal`, `$exp-literal`,
`$posit-literal`), so every OTHER reader sentinel fell through to the
`pair? ⇒ nested row` reading — the exact "new sentinel, old recognizer" polarity
failure `.claude/rules/pipeline.md` warns about. It now tests **`$`-headedness
AND NOT structural**, so a future VALUE sentinel is a term BY CONSTRUCTION. This
is what fixes `'[1 2]` (which reads as `($list-literal-parse 1 2)`), and — being
srcloc-independent — it fixes `$`-headed compounds on CONTINUATION lines too,
including the row REORDERING the splay caused (nested rows are appended after all
flat rows, so `|| 1 / '[2 3] / 4` used to come back 1, 4, 2, 3).

⚠ **The "AND NOT structural" half was learned the hard way.** The first version
asserted that inside fact CONTENT a `$`-headed pair is always ONE VALUE. **False**:
the reader wraps a continuation LINE by its FIRST TOKEN, so a line beginning with
a structural sentinel arrives as `($pipe 3 4)` / `($clause-sep foo a)` /
`($facts-sep 2)`. Classifying those as terms turned an ordinary leading-pipe
table

```
defr digit [?d]
  || 0
   | 1
   | 2
```

from a LOUD `empty row beside \`|\`` into **two fabricated rows leaking the raw
sentinel** — `@[{:d 0} {:d [?$pipe 1]} {:d [?$pipe 2]}]`, zero errors — i.e. it
moved a NEW shape into the very class this entry is about. Caught by the
adversarial verify; regression-pinned. The exclusion reads the structural set off
the predicates that already define it (`sentinel-kind-of`, `$pipe`) so it cannot
drift from them.

**(B) A LINE RULE.** An element on the same source line as the `$facts-sep`
sentinel is a first-row TERM, never a nested row — a continuation row is BY
DEFINITION on a later line. This is what fixes `[some 1]` and `{:k 1}`, which are
plain groups, not `$`-headed. Verified by instrumenting the reader: `|| 1 2` /
`3 4` gives sentinel line 3 with the nested `(3 4)` at line 4, while
`|| [some 1]` puts sentinel and compound BOTH on line 6.

⚠ **Guarded on trustworthy srclocs** via DEFERRED 51's impossible-column-0
marker: a preparse rewrite anywhere in the defr collapses every element onto the
defr's own line, which would make "same line" vacuously TRUE and MERGE real
continuation rows into the first row. Degraded ⇒ exact old behaviour, A/B'd
byte-identical.

**Measured** (`b429d038` vs fixed): `|| [some 1]` 2 rows → **1**; `|| '[1 2]`
3 rows → **1**; `|| {:k 1} 2` arity error → **1 row**. Controls byte-identical:
multi-line continuation rows, arity chunking (`|| 1 2 3 4` at arity 2 → 2 rows),
pipes mixed with continuation lines, leading-pipe tables, and the degraded-srcloc
fallback. An independent element-by-element A/B of the OLD vs NEW predicate over
**all 20 corpus files containing a `||` line (86 fact groups) reclassified ZERO
elements**.

#### Residuals — all test-pinned

1. **A preparse rewrite ANYWHERE in the defr disables rule (B) — the biggest
   limit, and it acts AT A DISTANCE.** `macros.rkt` rebuilds the whole defr
   whenever preparse changes anything in it (DEFERRED 51), collapsing every
   element to column 0; the guard then declines, and "declines" means the
   FABRICATION RETURNS. Confirmed triggers include `|>` and dot-access — both
   documented as IDIOMATIC in `prologos-syntax.md`. Note the list literal that
   (A) fixes is itself a (B)-killer for its siblings: `|| '[1 2]` beside
   `|| [some 3]` splays the latter. Rule (A) is srcloc-independent and survives.
   Closing this needs **DEFERRED 51(c)**, not more work here.
2. **A NON-`$`-headed compound alone on a CONTINUATION line is still splayed**
   (e.g. `[some 2]`). Narrow by design — the `$`-headed case is fixed by (A).
   The reader has already SPLICED the bracket group away there, so `[some 2]`
   and a bare two-token row `some 2` are literally the same datum.
   ⚠ **Closing it is cheaper than first assessed**: `parse-reader.rkt` already
   attaches `'prologos-paren-origin` to PAREN groups at the group-construction
   site and returns bracket groups bare — so a bracket marker is a one-line,
   precedented change at that same site. It would NOT close residual 1, because
   the degraded rebuild destroys syntax PROPERTIES exactly as it destroys
   srclocs.
3. **Compound fact VALUES do not work — the row is SEMANTICALLY DEAD, not merely
   mis-rendered.** `|| [some 1]` then `(m1 [some 1])` → `@[]`: the row cannot be
   matched by the very term that wrote it. Removing the splay is what makes
   compounds REACH the solver, where this shows. Corrections to the first draft
   of this note, all from the adversarial verify:
   · `[some 1]` does not render `unknown` — it renders **`[?some 1]`**: the
     CONSTRUCTOR HEAD became a logic variable, i.e. a fact row containing a free
     variable, and the column type is **`<error>`** emitted under `--- 0 errors ---`.
   · that mangling is **fact-row-specific, NOT pre-existing** — `(= x [some 1])`
     renders correctly. Only the `'[1 2]` / `{:k 1}` shapes reproduce outside a
     fact row (`(= y '[1 2])` → `unknown`).
   So the fix trades "N fabricated rows" for "1 unmatchable row". Strictly better
   (the count is right and nothing is invented) but still not WORKING — do not
   read the row-count fix as making compound facts usable.

---

### 70. ✅ FIXED 2026-08-07 (commit `066e2c45`) — the right-peel over-reached: a COMPOUND `let` body stole the rel RHS's srclocs, and the let leg's pins all used the one body shape that worked

> ⚠ **Renumbered 57 → 70 at the merge-back** (2026-08-08). It was **57** on branch `wizardly-mendel-2fd502`, where it collided with a DIFFERENT `main` entry of the same number. Commit messages and any code comment saying "DEFERRED 57" from that branch mean THIS entry.

**The landed let leg (`134ddb79`) was BODY-SHAPE-DEPENDENT.** With a compound
body — `[some vr]`, the idiomatic spelling — two parenless sibling goals under a
`let`-bound `rel` COLLAPSED into one over-arity goal:

```
let vr := (rel [f]
  &> fruit-color f "blue"
     fruit-size f "small")
  [some vr]
```
→ `solve: Unknown procedure: fruit-color/5 — however, there are definitions for:
fruit-color/2`. The paren-goal control returns `@[{:f "blueberry"}]`. Swap the
body for the ATOM `vr` and the same clause parses correctly.

⚠ **It is not reliably loud.** When the collapsed arity happens to be LEGAL (a
multi-arity relation), the collapse solves and returns a result with **0 errors**
while the correct reading errors — measured. So this was a reachable
silent-wrong-answer, not merely a bad message.

⚠ **And it was a REGRESSION, not a residual**: before the let leg landed, this
same input got the LOUD POL.8 guard. The fix converted a correct refusal into a
mis-grouping — precisely the trade `rebuild-preserving-locs`'s own commentary
forbids ("a partial fix that converts a LOUD refusal into a SILENT mis-grouping
is strictly worse than the status quo").

**Root cause**: `peelable?` accepts ANY two lists ("a group pairs with a group"),
so it cannot tell a list that was EDITED from one RESHAPED WHOLESALE. The let
desugar `(let r := V BODY)` → `((fn (r : _) BODY) V)` leaves BODY and V last on
their respective sides, both compound — so the peel paired them and V (the rel
RHS, carrying the clause layout) was rebuilt against BODY's tree. Nonzero column
⇒ POL.8's column-0 marker goes blind. With an ATOM body `peelable?` refused and
the relocation step found V correctly, which is exactly why every pin passed.

**Fix**: the peel now requires a **shared left anchor** (`pre > 0`).
Right-alignment presumes the two lists are THE SAME LIST with a changed middle,
and `peelable?` only ever sees the single pair it is about to take. The
discriminator is structural, not lucky: the lists this walk protects are CLAUSE
REGIONS, anchored on the left by the `&>` sentinel, which no rewrite touches — so
`pre >= 1` there even when a rewrite lands on the goal head itself. A total
reshape changes element 0's very KIND (the keyword `let` becomes an application),
so `pre = 0`. The reshape case falls through to RELOCATION, which matches V by
datum equality and does not care that it moved.

**Test-pinned** (3 cases, each by CONTROL EQUALITY against the paren spelling —
"no error" was the pin shape that missed this in the first place): the compound
body (the regression); the atom body (guards the relocation path the fix must not
cost); and the single-goal case, which **isolates the trigger — the collapse
needs TWO OR MORE sibling goals AND a compound body** (one goal has no
continuation line for the peel to mis-pair).

**How it was found, and the lesson**: not by any gate. The suite was green over
it throughout (9890/483/0) because no pin used a compound body. It surfaced by
PROBING an *inferred* claim from a grounding audit — the audit reasoned the peel
was body-shape-dependent from the code, and the probe confirmed it. This is the
4th instance this arc of "every automated gate went green over a live defect",
and the 2nd of "the pinned FIXED row is narrower than the pin's name suggests".
⭐ **The generalizable form: when a fix is pinned by a fixture you chose, ask
which axis of that fixture you never varied.** Here it was the let BODY — an
element that is not part of the feature under test at all, which is why nobody
varied it.

⚠ **THE FIRST CUT OF THIS FIX WAS WRONG AND WAS CORRECTED SAME DAY**
(`066e2c45` → `83d06156`), by an adversarial verify that measured both halves.
It gated the peel on `pre > 0`, arguing that clause regions are anchored by the
`&>` sentinel (so `pre >= 1`) while a total reshape changes element 0's KIND.
Both halves fail:
- **It REGRESSED working code.** `pre = 0` is necessary for a reshape but far
  from sufficient — ANY rewrite landing on element 0 zeroes it. The
  **aligned-block** (`let vr (rel …)` with an aligned second binding) and
  **bracket** (`let [vr (rel …)]`) spellings, with a compound body and EXACTLY
  ONE parenless goal, answered CORRECTLY at `fb788bfc` and hit the guard after
  the gate. There relocation cannot reach the moved rel RHS at all (DEPTH: one
  level below the middle for the bracket form, two for `$let-block`), so the peel
  was the only thing carrying the srclocs.
- **It was unsound the other way.** A head-position `mm.k` / `xs[0]` is an
  ORDER-PRESERVING fold where right-alignment is correct; the gate withdrew the
  peel there and stamped a whole clause subtree — two goals became one 5-arg goal
  at a NONZERO column, i.e. the silent mis-group this code exists to prevent.
  (Confirmed at the srcloc + parser level; end-to-end currently unreachable, so
  mechanism-confirmed / severity-refuted.)

**The rule that shipped** is about the PAIR, not the list: refuse the peel only
when the expanded element **moved through unchanged** — datum-equal to exactly
one original in the pre-peel middle, unique on the expanded side too — because
then RELOCATION pairs it with its true original, which is strictly stronger
evidence than positional adjacency. A genuinely rewritten element has no exact
match and still gets the peel, which is the continuation-line case the peel
exists for.

⚠ **CENSUS CORRECTION.** DEFERRED 51(c) lists the bracket form and aligned-block
bindings as "STILL DEGRADING, all LOUD". Measured: at TWO OR MORE parenless goals
they **MIS-GROUP** (`fruit-color/5`), they do not hit the guard — and a mis-group
is loud only while the collapsed arity happens to be undefined; on a multi-arity
relation the same shape is a silent wrong answer. Pre-existing and byte-identical
at `fb788bfc`; now test-pinned as a KNOWN LIMIT so it is visible. Root cause is
DEPTH (relocation scans only the middle's top-level elements), which is the same
wall the SIBLING-LET merge hits.

**Adjacent, still open**: the SIBLING-LET chain (DEFERRED 51(c), the known limit)
is unaffected by this fix — it degrades LOUDLY, upstream, at the fusion in
`merge-toplevel-sibling-lets`, and is the next slice. A grounding audit
additionally named, all unfiled and all LOUD, the private `def-`/`defn-` arms and
the `trait`/`impl`/`specialize` arms, which still do the bare whole-form stamp;
and noted that error POSITIONS for siblings 2..N of a merged let run are all
reported at sibling 1's line.

---

### 71. ✅ FIXED 2026-08-07 (commits `b3e03913` slice 1, `1ad9411f` slice 2) — THE DEPTH WALL: cons-cell identity was already an exact provenance marker, and the strip was throwing it away

> ⚠ **Renumbered 58 → 71 at the merge-back** (2026-08-08). It was **58** on branch `wizardly-mendel-2fd502`, where it collided with a DIFFERENT `main` entry of the same number. Commit messages and any code comment saying "DEFERRED 58" from that branch mean THIS entry.

Closes the last three members of the 51(c) family in one mechanism: **bracket
`let [vr (rel …)] body`**, **aligned-block `let` (`$let-block`)**, and the
**top-level SIBLING-LET chain**. All three now group and solve exactly like their
paren controls; three KNOWN LIMIT pins are INVERTED (they said to).

**THE WALL.** Everything in `rebuild-preserving-locs` aligns two ELEMENT VECTORS
at ONE level — common prefix, common suffix, the right peel, the relocation step.
A desugar that moves a subtree DEEPER is invisible to all of it. Measured depths
of the moved rel RHS, ORIGINAL side: inline `:=` **1** (works today), bracket
**2**, `$let-block` **3**. On the EXPANDED side it is **2k−1** for the k-th
binding (`let-bindings->nested-fn`'s `foldr` builds a right-nested chain), and
each level of `let` nesting adds +3 original / +2 expanded — i.e. **unbounded
along two axes**, so a fixed-depth-K search was never a fix.

⚠ **AND "SEARCH DEEPER" WAS THE WRONG ANSWER ANYWAY** — the prior audit's
"extend the pool by one level" would have been unsound. Deepening keeps DATUM
EQUALITY as the oracle, and datum equality cannot tell a user subtree from one
the desugar MINTS. That is not theoretical: **at the shallow depth we already
shipped**, `let q := [fn [q : _] [some q]]` has the minted `(fn (q : _) …)`
wrapper taking the USER lambda's srclocs while the user's own lambda is
flat-stamped — a **SWAP**, not a loss. An adversarial 2-line reproducer exists
that is safe at depth 1 and unsound at depth ≥ 2. Deepening strictly enlarges
that class, and it adds a route far wider than the recorded one (which needed the
peel to have consumed the true twin first).

**THE OBSERVATION.** `syntax->datum` allocates **fresh pairs**, and the movers
splice sub-datums **BY REFERENCE** — `let-bindings->nested-fn`'s `foldr` inserts
`value` unchanged, `datum-subst` is a bare `hash-ref`, `preparse-expand-subforms`
returns the SAME object when nothing changed. So **cons-cell identity is already
an exact, zero-cost provenance marker** for precisely the class this family is
about: a subtree that moved through a desugar UNCHANGED. `strip-with-origin!`
records it (`hasheq`: freshly-allocated pair → the syntax object it came from)
while producing the same datum `syntax->datum` produces.

Better than the search on every axis: **no depth parameter** to re-derive when a
sentinel adds a level; **no false-pair exposure by construction**, because a
minted node is a fresh cell and is `eq?` to nothing; and it resolves cases that
datum-ambiguity stamps today.

**THREE THINGS THAT HAD TO BE TRUE**, each measured to matter:
1. **ADDITION, never replacement.** The index holds only COMPOUND nodes and
   POL.8's own sentinel (`$clause-sep`) is an ATOM — replacing the alignment with
   an index walk regressed the `defr` control by handing that symbol the
   whole-form anchor.
2. **Consult at EVERY recursive entry**, not just the outer call.
3. **The STAMP must RECURSE.** It was terminal, which is what made the depth look
   *unbounded* rather than merely *nested*: a moved subtree inside a stamped
   element was never visited at all.

**SLICE 2 — and the earlier diagnosis was wrong in its load-bearing half.**
DEFERRED 51(c) recorded the sibling chain as needing "an stx-carrying merge
(~62 datum-shape sites over 12 functions) or deep multi-source pool relocation",
because the fusion "has TWO source trees". **Neither.** It was never a
depth-of-search problem: `merge-toplevel-sibling-lets` did `(map syntax->datum
unit)` and rebuilt against sibling 1, and `datum->syntax` stamps **RECURSIVELY**
over a bare datum, so every node already carried sibling 1's line and column
before `rebuild-preserving-locs` was ever called. No search, at any depth, can
recover information that is no longer in the tree. The fix is to stop discarding
it: strip the siblings through a **shared** index (~10 lines, all machinery
shared with slice 1). `merge-sibling-lets` still receives plain datums, still
decides on datum shapes, and its error-containment invariant is untouched.

⭐ **The old loudness was INCIDENTAL.** The chain failed LOUDLY only because
sibling 1 sits at column 0 — exactly POL.8's degradation marker. The identical
defect written indented (inside a `defn`) would have been SILENT. "It fails
loudly" was a property of the fixture, not of the code. The same correction
applies to the census's "still degrading, all LOUD" language generally.

**RULED (owner, 2026-08-07)**: a duplicated node takes the **same** loc.
`datum-subst` splices by reference, so a `defmacro` template using `?e` twice
yields two `eq?`-identical copies; both resolve through the index to the one
original. Relocation refuses that case via an expanded-side uniqueness guard; the
index deliberately does not.

**Tests**: the three inverted pins by control-equality, plus an explicit "the
collapse is gone, not merely relabelled" check (control-equality alone would pass
if BOTH sides broke identically — which is exactly how the `def := rel` member
hides from its own pin), plus a "still merges" pin for the fusion (a grouping
test cannot see whether the fusion stopped fusing, which would drop earlier
siblings out of scope). New `tests/test-origin-index.rkt` pins the two properties
a green suite would NOT demonstrate: (A) `strip-with-origin!` is datum-identical
to `syntax->datum` over shapes chosen to break a naive walker (improper lists,
vectors, nested empties) — it is on the hot path for every form now; (B) the
recorded key is `eq?` to the pair the expander receives, **and a SECOND strip
shares no keys** — the trap that would silently reduce the index to a no-op while
every behavioural test still passed.

**Gates**: suite **10020 / 487 / 0** (at `c77fbeb4`); both acceptance files 0
errors. **Both corpus A/Bs came back with ZERO SEMANTIC DIFFS**, each isolated to
its own change:
- D57 (161 files, `fb788bfc` → `f9d68338`): 4 DIFFERS = 2 gensym drifts + 2
  absolute-path echoes; 20 caps all SYMMETRIC with identical sizes.
- D58 (161 files, **`75401b89` → `c77fbeb4`**): 5 DIFFERS = 2 gensym drifts + 3
  path-only (they collapse to IDENTICAL lines once the two worktree paths are
  normalised); 20 caps all SYMMETRIC.

⚠ **A BASELINE-SELECTION TRAP, recorded because it nearly produced a false
alarm.** The D58 A/B was FIRST run against `f9d68338` — the last baseline that
happened to be frozen — which is **PRE-MERGE**. That comparison spans main's
entire 30-commit delta as well as the three D58 commits, and it reported 13
differing lines in `examples/2026-07-26-ciu-t6-path-selection.prologos` with the
BASE leg showing **12 errors** against head's 0. That is main's own broadcast work
landing, measured backwards — not a defect. **The base of a corpus A/B must be the
commit the change actually sits on, not the newest baseline lying around.**
⭐ The tell that caught it: the diff pointed the WRONG WAY. Base worse than head,
in a file already known to run at 0 errors on the current tree, is structurally
impossible for a change of ours — so it is a statement about the HARNESS, not the
code. (Note the asymmetry: had it pointed the other way, that reasoning would not
have been available and the two explanations would have needed separating by
measurement.)

**Explicitly NOT in scope** (owner-ruled a separate slice): the FOURTH member,
`def name := rel …` spliced/unparenthesized, which collapses the same way at a
nonzero column with a blind guard. It is **not** a relocation miss — the expanded
`(rel (?q) ($facts-sep …))` is a NEWLY CONSTRUCTED grouping of three previously
sibling elements, so no datum-equal twin exists at any depth and the index cannot
see it. It needs expanded-side DESCENT, a different generalization. ⚠ And
repairing it will silently flip that arm's `||` fact-row count (measured 3 rows
vs `defr`'s 4 on the same block, both with 0 errors), so it needs its own pin
BEFORE the fix lands.

**Still open, unfiled, and now cheaper**: the private `def-`/`defn-` arms and the
`trait`/`impl`/`specialize` arms (+ private twins) still do a bare whole-form
stamp and never reach `rebuild-preserving-locs`. Because those are STAMP sites,
an index-aware stamp would close them with no per-arm work (inferred, not
measured). Same mechanism discharges the "error POSITIONS for siblings 2..N are
reported at sibling 1's line" item.

⚠ **A SEMANTIC SIDE EFFECT RODE IN ON SLICE 1 AND WAS CORRECTED** (`c77fbeb4`),
found by adversarial verify, measured, **with a silent mode**. The index hands
back the ORIGINAL syntax object — which also carries its syntax PROPERTIES — and
`prologos-paren-origin` is **position-sensitive**: the reader attaches it to every
paren group and `paren-goal-stx?` reads it to decide that a paren group AT COMMAND
POSITION is a relational goal (POL.9). So a `defmacro` lifting its argument to top
level turned an application into a goal:

```
defmacro dbg [$e]
  $e
dbg (inc 10)    before: `11 : Int`, 0 errors  →  after: ERROR, 1 error
dbg (= 1 1)     before: `true : Bool`, 0 err  →  after: `@[{}] : _`, 0 ERRORS
```

The second is the sharp one — zero errors on both legs, only the value and type
differ. `dbg [inc 10]` is identical throughout, isolating the trigger to
macro-spliced PARENS at command position.

**THE RULE THAT FIXED IT**: a hit whose original is the node we were ALREADY
aligned with has not moved and keeps its properties (as the `equal?` branch always
did); any other hit MOVED and takes **srclocs only** (`syntax-locs-only`). That is
byte-equivalent to pre-index behaviour for properties — the old code stamped,
which dropped them — while keeping every srcloc the index exists for.

⚠ Which reading is *correct* is genuinely arguable: POL.9 does say a paren group
at command position is a goal, so the accident arguably made macro-spliced code
behave like hand-written code. **That is exactly why it could not stay** — a
language-semantics change arriving unreviewed, undocumented and untested inside a
srcloc fix.

✅ **RULED 2026-08-07 [owner]: KEEP THE GOAL READING OUT.** A macro-spliced paren
group at command position stays an APPLICATION. This is now a decision, not
merely a reverted side effect — do not "fix" it later by adopting POL.9's
command-position reading for macro output on the grounds of consistency. It is
test-pinned three ways, including the silent goal-keyword case.

⭐ **The generalizable lesson**: "hand back the original node" is NOT neutral. A
syntax object carries a POSITION *and* CLAIMS ABOUT ITS POSITION, and moving it
re-asserts the second where it was never true. Slice 1 argued its own safety as
"the helper never mints properties, only copies originals" — reasoning about
MINTING, and missing that COPYING a property to a different position is itself a
semantic act. The class was entirely unguarded (zero `syntax-property` references
in any test); now pinned three ways, including the silent case.

⚠ **A fail-safe correction for whoever touches this next**: the "stamp at a
column-0 anchor" constraint recorded earlier is a design GOAL that HEAD already
violated in 2 of 3 members, not a property to preserve — and no column-0 anchor
is even available from a syntax object in scope, since a paren-wrapped top-level
form sits at column **1**. The reliable fail-safe is a `#f` loc
(`(datum->syntax #f d #f)`), which BOTH layout guards already test for alongside
`(zero? sent-col)`.

---

### 72. ✅ FIXED 2026-08-08 (commit `e05729a5`) — MEMBER 4: `def name := rel …` mis-grouped a clause containing a REWRITE; expanded-side descent closes it

> ⚠ **Renumbered 59 → 72 at the merge-back** (2026-08-08). It was **59** on branch `wizardly-mendel-2fd502`, where it collided with a DIFFERENT `main` entry of the same number. Commit messages and any code comment saying "DEFERRED 59" from that branch mean THIS entry.

The fourth member of the 51(c) family, owner-ruled into its own slice. Its clause
elements are collapsed onto one line at a NONZERO column, so POL.8's column-0
marker is blind and a parenless clause silently mis-groups.

⚠ **BUT NOTHING ABOUT IT REACHES OUTPUT, which changes how it can be worked.**
Measured at `c77fbeb4` — the mis-grouped spelling and its shape-identical paren
control produce **byte-identical output**:

```
def k := rel [?f]                    def k := rel [?f]
  &> fruit-color f "blue"              &> (fruit-color f "blue") (fruit-size f "small")
     fruit-size f "small"            k
k
```
→ both: `ERROR: Expression is not a valid type` + `ERROR: Unbound variable`,
2 errors. The **POL.9b def-seam gap** (a bare multi-token RHS is application/value
by Q_C, and a def-bound rel VALUE infers a hole type) masks the whole thing.

**The PARENTHESIZED spelling is CORRECT and is not affected**: `def k := (rel [?f]
&> fruit-color f "blue" / fruit-size f "small")` returns `@[{:f "blueberry"}]`,
0 errors, byte-identical to its paren-goal control.

**CONSEQUENCES FOR SEQUENCING** (this is the entry's point):
- there is **no behavioural failing-test-first** available — the fix would change
  no observable behaviour, so it is pinnable only at the PARSER level (parse the
  form, inspect the `surf-*` tree);
- the `||` fact-row pin a prior audit demanded "BEFORE the fix" **cannot be
  written behaviourally for this arm either**, because the arm errors out. The
  audit's 3-rows-vs-4 observation was made at surf level, not end to end;
- so the honest options are (a) fix it with PARSER-LEVEL pins as insurance,
  labelled latent; (b) close the def-seam gap FIRST — that is what makes
  `def name := rel …` usable at all — after which member 4 is observable and
  testable normally; or (c) leave it filed and take observable work instead.

**Why it is not free to ignore**: the day the def-seam gap closes, this becomes a
LIVE SILENT mis-group, and whoever closes that gap will have no reason to look
here.

✅ **FIXED — and the filed description above was STALE in a way that changed the
fix.** It says the clause elements are "collapsed onto one line". Measured at
`c77fbeb4`: DEFERRED 71's origin index ALREADY recovered the UNCHANGED goal
(L4:C5, correct). What actually collapsed was the **CHANGED** subtree and its
enclosing `$clause-sep` group, both landing on the `:=` token (L2:C7). So the
defect is smaller and sharper than filed, and it fires ONLY when a preparse
rewrite sits inside the rel — without one the group is datum-unchanged and the
index returns the original wholesale.

**THE FIX — EXPANDED-SIDE DESCENT** (`rebuild-preserving-locs`, the relocation
branch). When a RUN of original middle elements folds into ONE compound expanded
element, wrap the run and recurse; ordinary alignment then pairs each element
with its original and descends into the changed one. Guards: exactly one expanded
middle element, a proper list, no longer than the run, and a datum-equal HEAD.
Failing any of them falls through to the stamp, i.e. prior behaviour.

⚠ **THE FOLD ALSO DROPS TOKENS** — this is what the first cut got wrong.
`expand-def-assign` consumes the `:=` as well as wrapping, so an original run of
FOUR (`:=` `rel` `(?f)` `($clause-sep …)`) becomes a THREE-element list; an
equal-length guard never fires. The correspondence is the run's TRAILING slice of
the folded element's own length, and the matching HEAD is what makes it a claim
rather than a coincidence of arity.

Measured: `$clause-sep` L2:C7 → **L3:C2**, `($select-path mm k)` L2:C7 →
**L3:C19** — byte-identical to the known-correct PARENTHESIZED control.

**Test-pinned at the SRCLOC level** (`tests/test-def-rel-srcloc.rkt`), because the
defect is invisible from output and the pre-existing end-to-end guard is VACUOUS
for it (both sides collapse identically, so `check-equal?` passes over a live
bug). ⚠ The helper must handle BOTH sentinel shapes: indent-grouped sources give
a GROUP headed by `$clause-sep`, while inside explicit parens the reader suspends
indent grouping and it arrives as a BARE SYMBOL — a helper knowing one shape
silently returns `#f` for the other.

**Gates**: suite 10027/488/0; both acceptance files 0 errors; corpus A/B
(`59b4174e` → `e05729a5`, 161 files) ZERO semantic diffs, all caps symmetric.
⚠ **The corpus is WEAK evidence here and should not be cited as strong**: no
corpus file contains a `def := rel …` form at all, so it demonstrates
"no collateral damage", not "the fix works". The srcloc pins are the real
evidence.

⚠ **STILL OPEN, and it was the reason this member was scheduled after the seam**:
the `||` fact-row divergence on this arm. A prior audit measured THREE rows here
where `defr` gives FOUR on an identical block, at surf level. That remains
unpinned and unresolved — and see DEFERRED 73, which found the `defr` side is not
a clean oracle either.

**And it is NOT a relocation miss** — the origin index of DEFERRED 71 cannot see
it. The expanded `(rel (?q) ($facts-sep …))` is a NEWLY CONSTRUCTED grouping of
three previously-SIBLING original elements, so no datum-equal twin exists at any
depth and no cons-cell identity survives. It needs **expanded-side DESCENT**
(recurse into the folded expanded element against the folded original run, whose
tail is datum-equal to the originals) — a different generalization from anything
DEFERRED 71 built.

---

### 74. ✅ FIXED 2026-08-08 (commit `59b4174e`) — THE POL.9b DEF-SEAM: one shared gate, and the honest message when a type never existed

> ⚠ **Filed at the merge-back.** This entry was referenced as "DEFERRED 61" by
> commit `59b4174e` and by code comments in `driver.rkt`, `qtt.rkt`,
> `typing-errors.rkt` and `tests/test-rel-t1-pol.rkt`, but an entry was never
> actually written — the number was in use before the section existed. It is
> filed here at its post-merge number; the code comments now say 74.

**THE SEAM WAS ONE LINE, AND THE DEFECT WAS A DIVERGENCE.** The ANNOTATED `def`
path guarded `is-type/err` against non-ground types; the INFERRED path called it
bare. Both were written by the same commit — the guard was simply not mirrored.
The fix is ONE predicate (`def-type-not-ground?`) behind ONE gate
(`def-body-type-ok`) used by BOTH paths, rather than a second copy that could
drift a second time.

**WHAT IT COST WAS MORE THAN A BAD MESSAGE.** The def path type-checks BEFORE it
evaluates, so rejecting a non-ground body preempted every diagnostic raised at
EVALUATION time. Three already-written guiding messages were unreachable:
`def bad := (dbl 3)` → *"dbl is a function — application is written `[dbl …]`"*;
`def bad := solve (nosuchrel a b)` → *"Unknown relation: nosuchrel"*;
`def bad := explain (dbl 3)` → the same guiding message. And `def k := rel …`
(an unparenthesized rel VALUE) could not bind at all.

✅ **RULED (owner, 2026-08-08)**: `def k := rel …` yields a **rel VALUE**. Note
this is NOT the same output as the parenthesized `def k := (rel …)`, which is a
GOAL with implicit solve (POL.9) and yields the SOLVED row set — making them
identical would mean an unparenthesized RHS solves, contradicting Q_C.

⚠ **AN ASYMMETRY THE "just mirror the guard" FRAMING HIDES**: the annotated
path's hole comes from the USER's bare-param annotation — a legitimate wildcard
by construction — while the inferred path's can mean inference FAILED. That is
why mirroring alone was not enough:

**THE HONEST MESSAGE WHEN THE TYPE NEVER EXISTED.** Letting non-ground bodies
through to QTT means QTT is asked to check a body's usage AGAINST a type that is
not there, and its generic `tu-error` reads **"Multiplicity violation"** — naming
a subsystem that is working perfectly. Measured on the corpus: FIVE forms in
three files moved from "Expression is not a valid type" to that, i.e.
vague-but-neutral → specific-but-wrong. So when the type is NOT GROUND and QTT
fails, the report is the inference failure.
⚠ **The trigger is NOT "contains a hole"**: `def d := flip const false 2` infers
a type carrying an unsolved META, and a hole-only test misses it — the first cut
did exactly that and the lying message survived. The condition is the GATE's own
predicate, which is also the principled one.
⭐ **Bonus, unlooked-for**: this also fixed a PRE-EXISTING lying diagnostic —
`examples/2026-04-17-ppn-track4c-adversarial.prologos` command 0 read
"Multiplicity violation" BEFORE any of this work and now reads "Could not infer
type".

**RIDE-ALONG — the `expr-narrow` infer/inferQ TWIN.** `infer` has had an arm
since the node was added; `inferQ` never did, so it fell to `[_ (tu-error)]`.
It was MASKED by the seam, so it is not optional alongside this fix.
See `.claude/rules/pipeline.md` § "infer / inferQ Are Twins".

**Gates**: suite 10019/487/0 at the time; corpus blast radius BOUNDED BY
SIGNATURE to 4 of 161 files and compared exhaustively — zero semantic diffs, no
"Multiplicity violation" left in the affected set.

---

### 102. ✅ FIXED (`41458174`) ⭐⭐ THE ABORT SEAM — a PREPARSE error in a file that also has a successful `data`/`trait`/`impl` was a WHOLE-FILE ABORT with a raw Racket stack trace (139/305 corpus files susceptible)

> **✅ FIXED at `41458174`; glyph corrected 2026-08-10** — the fix commit did not
> touch this file, so the entry read `⬜` while the code was already repaired, and
> the D4 tracker, Q_U31 and the dailies all said FIXED. **Re-verified by running
> the reproducer below at `19560a7c`**: it now yields PARTIAL output with ONE
> per-command error — `Col`/`Red`/`Green`/`before` all defined, `preparse: bundle
> Bx: invalid body syntax`, and `after` still defined. That is the intended
> per-command channel, not an abort. *(Original report below.)*

Found by the star-surface census (`wf_19cd5077-15b`), reproduced on the main
thread at `d0ac2a58`. **Not a star defect** — the star was merely the probe.

```
ns c1
def before := 1
data Col := Red | Green
bundle Bx := (Add Sub) *
def after := 2
```
```
syntax->datum: contract violation
  expected: syntax?
  given: '($preparse-error "bundle: bundle Bx: invalid body syntax")
  … macros.rkt:4175 · partition · preparse-expand-all · process-file-inner
```
**No output at all** — `before` never prints. Remove the `data` line and the same
file reports a clean per-command `preparse: bundle …: invalid body syntax`.

**Cause**: the `$preparse-error` seat conses a BARE list into `result`
(`macros.rkt:3684` — the only emit site), and Phase-5b's hoist partition
(`macros.rkt:4175`) calls `syntax->datum` on every element. The partition runs
only when `generated-decl-names` is non-empty — i.e. only when a `data`/`trait`/
`impl` succeeded in the same file. That is why it hides: a probe file without a
declaration takes the fast path and looks clean.

⚠ **THE IRONY, and the reason this is filed loud**: that seat was ruled into
existence *to PREVENT* whole-file aborts — it is CIU T6's own option-B preparse
seam guard (`ae26f540`), which converts a preparse RAISE into a per-command error
VALUE. It does exactly that, and then the value it produces aborts the file by a
different route whenever a declaration precedes it.

**Blast radius**: **139 of 305** corpus files contain a `data`/`trait`/`impl`, so
any preparse error in them is an abort. Reachable from ordinary typos, not just
stars — measured with `bundle`, and the census found 5 of 8 star-carrier form
refusals abort this way.

**Fix**: make `:3684` emit a syntax object, or make `:4175`'s predicate tolerate
a non-syntax element. Exactly one emit site and one consume site in non-test code.

**Test obligation, earned by how this hid**: every preparse-error probe file MUST
contain a successful `data`/`trait`/`impl`. Five parallel censuses each reported
"zero aborts" because none of their probe files did.

⭐ **Prerequisite for any design whose refusal lives in a preparse validator** —
including the star work's own guided refusals.

---

### 117. ✅ DISCHARGED 2026-08-13 (1b-iv verify) ⭐ THE L4 SORT GATE SHARED THE DUP GATE'S TOP-LEVEL-ONLY BLINDNESS — a keyless star component spliced from inside a `(@sub …)` behind a dissolve reaches `select-assemble-row` unchecked

**✅ DISCHARGED** at the 1b-iv adversarial verify — and its exposure was
UNDERSTATED here, which is why it is worth re-reading rather than just closing.
The entry called it "cheap — the predicate already exists". It was also
**BLOCKING, in two directions**, measured on the untouched VECTOR path (so it
never needed 1b-iv to be reachable):
· `nv{m k^.{a*}}` → **WHOLE-FILE ABORT** (`symbol<?: contract violation` out of
  `make-record`; no output at all, not even the preceding `def`)
· `nv{k^.{a*} m}` → `@[@[1 2] @[9]]` at **ZERO errors**, `:m`'s key silently
  dropped — order-dependent, the round-1 defect shape exactly
while the un-nested `nv{k^.a* m}` refused correctly in both orders.
⭐ **The landmine held**: the gate and its diagnostic's `findf` were widened in
ONE edit, because the message renders its label with the SAME predicate — widen
the gate alone and `pp-select-branch` gets a `#f` on the ERROR path, which is the
whole-file-abort shape this track has already shipped once. Reduction's
`level-entries` twin was widened in the same edit. Pinned with both
manifestations, both orders, the label, and file survival.

Found by the D4.P4e-1b-iii-C2 adversarial verify (`wf_bf354f2d-675`).
**PRE-EXISTING — reproduces identically on the pre-C2 build**, so C2 neither
caused nor closed it. Filed because it is the SAME gate defect as the blocking
dup finding, three lines away, and **any fix must widen both gates together**.

Typing's star L4 check in `select-level-components` tests
`(ormap (lambda (br) (ormap select-star-step? br)) branches)` — the branch's
TOP-LEVEL steps only. C2's verify round 1 gave the dup gate a recursive test
(`select-branch-has-star?/deep`, syntax.rkt) and **deliberately did not widen the
L4 one**, because that is a behaviour change to a pre-existing gate and
mid-flight widening is where this arc introduces defects (*Watching 9*).

**Two manifestations, by component order:**
· keyed-first → `symbol<?: contract violation` and the file produces **NO output
  at all** (whole-file abort);
· keyless-first → silently DEMOTES the level to a positional tuple and DROPS the
  keyed sibling's key, at zero errors.

**What is owed**: widen the L4 gate to `select-branch-has-star?/deep` and pin
both orders, as the dup gate now is. Cheap — the predicate already exists.

---

### 133. ✅ **DISCHARGED `862fc7e3`** (filed and fixed same day) ⭐ THE BATTERY'S STAR-TOKEN HELPERS ARE EXACT-LEXEME `"*"` AND SO ARE STRUCTURALLY BLIND TO `*_` — DEFERRED 127's defect one layer down, where its repair never propagated

> **FIXED at `862fc7e3`** (B2b step 1). Both helpers now sweep a star-operator
> REGEX (`#rx"^[*][-_]*$"` — deliberately not a fifth hand-copied spelling list,
> and deliberately WIDER than the reserved family) and report an explicit `'none`
> rather than `#f`. RED observed first (`actual: #f / expected: 'symbol`).
> ⭐ The power-check then caught a VACUOUS pin in the new rows themselves — a
> last-star row giving `OLD=symbol NEW=symbol`, passing for opposite reasons —
> replaced with one measured at `OLD=postfix-star NEW=symbol` that stays
> discriminating after B2b. Containment pinned; the 5 pre-existing star rows
> verified byte-identical under the widening. Battery 550 → 553.

Found by the CIU T6 D4.P4e-1b slice **1b-v-B2b** grounding (`wf_7f5bda0c-500`,
completeness critic). **A PRECONDITION FOR B2b's OWN TESTS**, not a latent issue:
any B2b row written with these helpers has no power.

**THE FACT** (verified): in `tests/test-path-selection.rkt` (~:6110-6132),
`p4e-star-type` uses `(assoc "*" (p4e-token-types src))` and `p4e-last-star-type`
uses `(string=? (car (car ts)) "*")`. Both match the lexeme EXACTLY, so on a `*_`
source both return `#f` — and `#f` is indistinguishable from "this source
correctly does not mint."

**WHY IT IS THE SAME DEFECT AS [127](#127)**: that entry describes
`tools/star-arrival-matrix.rkt` gating on `(string=? … "*")` — *"it could not
distinguish 'correctly does not mint' from 'I cannot see this token'"* — and its
repair swept `star-spellings` and returned an explicit `'none` so blindness could
not read as success. **The repair landed in the tool and never reached the
suite.** The class is now at three instances in this phase.

**FIX**: widen both helpers to sweep the spelling set and report an explicit
not-seen value (mirroring `star-last-token-type`), or add spelling-parameterized
twins. ⚠ Do it BEFORE writing any B2b row, and mutation-test that a blind helper
now FAILS rather than silently passing.

---

### 134. ✅ **DISCHARGED** `type_application` IS GREEDY INSIDE A FUSED `typed_param`, so `[p1:Point p2:Point]` MIS-PARSES — valid code the COMPILER accepts at 0 errors

Found by EHP T1 P4 while re-checking catalogued issue #4 on the repaired base.

`defn point-add2 [p1:Point p2:Point]` compiles at **0 errors**
(`point-add2 : p::Point p::Point -> p::Point defined.`). The grammar reads it as:

```
typed_param "p1:Point p2"
  identifier "p1"
  type_expr "Point p2"
    type_application "Point p2"    <- the type EATS the next parameter
ERROR ":Point"
```

So the second parameter is painted as a **type**, and the stranded `:Point`
becomes an ERROR region — where `semanticTokens.ts` deliberately suppresses
semantic tokens, so VS Code falls through to TextMate. That fall-through is the
residual half of issue #4's "fused `var:Type` mispaint"; the TextMate half was
fixed at `805e14be`.

**Why it was previously judged "the grammar is right"** (§4 of the EHP doc): the
probe used a SINGLE fused param, where the grammar IS right. The defect needs a
SECOND one to appear — the differential varied more than one thing.

⚠ **Incidence is small and was nearly overstated.** A first scan counted 124 of
1609 param_lists containing an ERROR, but that conflated two populations: most
are the SPACED form (`[x : Int  y : Int]`), which the **compiler also rejects**,
so the grammar is right about those. The confirmed valid-but-mis-parsed shape —
two or more FUSED typed params — is **2 sites**:
`lib/examples/foray.prologos:1424` and
`examples/2026-07-31-let-toplevel.prologos:37`.

**FIXED 2026-08-15.** `typed_param`'s type is now `_param_type` —
`identifier | grouped_type | angle_group`, i.e. exactly the alternatives that
CANNOT absorb what follows. `type_application` and `arrow_type` are dropped;
a fused `Int->Bool` lexes as one identifier anyway (ARROW T1), so nothing real
is lost.

⚠ **The compiler is the authority and says the fused type is ATOMIC** —
measured: `[xs:List Int]` elaborates to TWO parameters, `xs : List` plus a bare
`Int`, not one parameter typed `List Int`.

⚠ **Also corrects this entry's own claim that `[x:Int y]` is invalid.** It is
valid — `f3 : Int _ -> Int defined.` The earlier probe's errors came from its
BODY (`[+ x y]` with `y : _`), not the param list. Only the SPACED `[x : Int]`
is genuinely rejected, so the grammar erroring on it is correct.

**A GLR conflict, not a narrowing**: `typed_param` is shared with `let_binding`,
and a `let` type may legitimately be multi-token (`let f : Int -> Bool := v`).
Declaring `[$._param_type, $.type_expr]` lets the parser carry both and settle on
the following tokens. A/B'd: all three `let` shapes parse identically before and
after, including the `-> ` one, which was ALREADY failing at HEAD (pre-existing,
not caused here).

⭐ **Every corpus signal improved** — unlike DEFERRED 136, no recovery-churn
caveat: clean **34 → 35**, ERROR 2693 → **2579**, MISSING 75 → **73**,
error-bytes 14691 → **14529**. Ratchet tightened to 73.

⚠ **And it caused a colour regression the dump caught**: the fused type used to
be a `type_application`, which carried its own `@type`; bounding it to a bare
identifier left a USER type with no type rule, so `Point` fell to `@variable`.
`Int` did NOT, because the builtin rule matches it by name — which is exactly
what made the loss easy to miss. Added `(typed_param type: (identifier) @type)`.

**Original fix note**: bound the type in a fused `typed_param` so it cannot absorb a following
identifier — the fused spelling is documented as single-token types only
(`prologos-syntax.md`), so the type there should not be a `type_application` at
all. TSG work, not EHP; filed rather than done because it is a grammar change
with its own corpus gate to re-measure.

---

### 135. ✅ **DISCHARGED** (filed and fixed same day) SELECT-BLOCK BRANCH NAMES ARE KEYS BUT PAINT AS `@variable` — only the DOTTED step gets `@property`, so one concept renders two ways

Found by EHP T1 P4 re-checking catalogued issue #2. **Refutes the filed
diagnosis**: §4 recorded "suspected TextMate showing through". The census reports
**zero disagreement** with TextMate over these spans — it is purely a query
choice.

`queries/highlights.scm` has exactly one key capture on a path:
`(nominal_step key: (identifier) @property)`. Measured on
`cfg{server^.{ssl^.enabled^ssl port} version}`:

| span | node | capture |
|---|---|---|
| `enabled` | `nominal_step` (a `.step`) | `@property` ✅ |
| `server`, `ssl` | head `identifier` of a `path_expr` | `@variable` ❌ |
| `port`, `version` | bare branch `identifier` in a `select_block` | `@variable` ❌ |
| `ssl` in `^ssl` | rename target inside `key_op` | `@variable` ❌ |

All five are keys under the law *"dot DESCENDS · brace SELECTS · `:` BROADCASTS ·
`^` RE-KEYS"*; only the one reached by a dot is chromed as one.

**FIXED 2026-08-15.** Three captures added, placed above `(key_op) @operator`
(which spans the whole `^ssl`, so file order decides):

```
(select_block (path_expr . (identifier) @property))
(select_block (identifier) @property)
(key_op (identifier) @property)
```

⭐ **The `select_block` ancestor is load-bearing, not decoration.** The OUTER
`path_expr` of `cfg{...}` has head `cfg` — the SUBJECT — so a bare
`(path_expr . (identifier) @property)` would have recoloured every path subject
in the corpus. Verified on real code
(`2026-07-26-ciu-t6-path-selection.prologos:80`): `app-config` still resolves to
`@variable` alone, while all nine branch names take key chrome.

The design call on the rename target went to `@property` like every other key:
the vocabulary draws no read/write distinction for a field name, and having the
new name read differently from the old one is the inconsistency being removed.

Measured: **135 identifiers across 3 files** gain key chrome. Fixture extended
with a path form (deliberately avoiding the `^-` family, DEFERRED 136), golden
**234 → 260**, all six gates green.

**Original fix note**: capture the other key positions — the `path_expr` head, bare
`select_block` branches, and the `key_op` rename target. ⚠ **Carries a design
call**: the rename target is a key being *created*, not read, so it may want a
different capture than `@property`. And this changes rendered colour, so it is
the owner's to rule on. Golden will move.

---

### 136. ✅ **DISCHARGED** (filed and fixed same day) `key_op` CANNOT PARSE THE `^-` COLLAPSE FAMILY OR `^..` — landed language surface (CIU T6 D4.P3b) that the grammar never learned

Found by EHP T1 P4 re-checking catalogued issue #3, which points at
`foray.prologos:712`:
`app-config{server.ssl.{enabled^-ssl cert-path^cert}}`.

`grammar.js` `key_op`:

```js
key_op: $ => seq(token.immediate('^'), optional(choice(
  field('rename', alias(token.immediate(/[a-zA-Z_][a-zA-Z0-9_?!-]*/), $.identifier)),
  field('synth',  token.immediate('_')))))
```

The rename alternative must START with a letter or `_`, so every `-` continuation
is unrepresentable. Measured, one form per probe:

| form | grammar | compiler |
|---|---|---|
| `^` · `^_` · `^lbl` | 0 ERROR | ✅ |
| **`^-` · `^-_` · `^-lbl`** | **1 ERROR each** | ✅ **0 errors** (`cfg{server.host^-_}` → `{:server-host String}`; `^-` → `{:host String}`) |
| **`^..`** | **1 ERROR** | (Q_T8) |

The `-` collapse family is **Q_T7** and `^..` is **Q_T8**, both landed at
`36ce601c` (D4.P3b). The design doc states the continuation grammar as
`-`?·{ε\|label\|`_`} + `^..`; the tree-sitter rule implements the middle of it
and neither edge.

**Why it renders as issue #3's "closing inner projection ≠ opening"**: the
stranded `-` becomes an `ERROR`, and `semanticTokens.ts` suppresses semantic
tokens inside ERROR subtrees *by design*, so part of the span falls through to
TextMate and part does not. The asymmetry is the suppression boundary, not a
brace rule.

Corpus: `^-_` ×3 in `examples/2026-07-26-ciu-t6-path-selection.prologos`, plus
`foray.prologos:712`. **FIXED 2026-08-15.** `key_op`'s continuation now spells the whole grammar —
`..` (Q_T8) and `-`? · {ε | label | `_`} (Q_T7) — written out branch-by-branch
rather than as nested optionals, so no alternative can match empty. All seven
forms parse at 0 ERROR/MISSING, and `^a-b` (a rename with an internal dash) is
unaffected.

⭐⭐ **The census gate then caught a bug the fix EXPOSED — a `synth` field that
had been dead since before this change.** The rename regex started `[a-zA-Z_]`,
so it matched a bare `_` and won: `^_` parsed as a rename to a field literally
called `_`, and `field('synth', …)` never matched. Invisible until DEFERRED 135
started painting the rename identifier, at which point `_` came out `@property`
and disagreed with TextMate's `keyword.operator.wildcard`. Regex tightened to
`[a-zA-Z][…]*|_[…]+` so `_` alone is the synth marker while `_abc` is still a
rename (longest match). **Third vacuous rule found in this arc.**

⚠ **Corpus A/B against the committed grammar, per-file**: ERROR 2700 → 2693,
MISSING 76 → 75, swallows 0 → 0, unparsed 1.3% → 1.3%. But ERROR-BYTES ROSE
14586 → 14691 (+105), and that is **not** the documented count/bytes
anti-correlation. Attributed: `foray.prologos` improved (bytes 1031 → 1022,
missing 113 → 106) — that is the fix — while `collection-traits.prologos` (×2
copies) and `sudoku-demo` moved the other way, **and none of those three files
contains a `^`**. What fails in collection-traits is `fold`/`reduce`/`deftype`/
`fmap`. It is ERROR-RECOVERY CHURN: adding alternatives perturbs the LR tables,
so recovery takes different paths in files that were already broken.

Ratchet tightened `max_missing` 76 → 75. Fixture gains the family and `^..`;
golden 260 → 298. All six gates green.

**Original fix note**: extend `key_op`'s continuation to
`optional('-')` + the existing choice, and add `^..`. TSG work; re-measure with
`check-corpus.sh` after.

---
