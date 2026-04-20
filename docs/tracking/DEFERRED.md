# Deferred Work

Single source of truth for all deferred work across the Prologos project.
Items are organized by topic. When work is deferred during implementation,
add an entry here immediately.

**Principle**: Completeness over deferral. Items here should be genuinely
blocked on unbuilt infrastructure or uncertain design — not effort avoidance.
See `docs/tracking/principles/DEVELOPMENT_LESSONS.org` § "Completeness Over
Deferral".

**Completed items**: Moved to `DEFERRED_COMPLETE.md` during staleness sweeps.

**Last consolidated sweep**: 2026-03-20 (PUnify Parts 1-2 complete, 7308 tests, 377 files).

---

## HIGH PRIORITY: Propagator/Cell Allocation Efficiency Track

### Design Track for Efficient Prop/Cell Allocation
- **Audit complete**: `docs/tracking/2026-03-20_CELL_PROPAGATOR_ALLOCATION_AUDIT.md` (commit `f7bd03d`)
- **Thesis**: Any even modest gains in allocation efficiency will have disproportionate effect across the entire infrastructure — every part of the system creates cells and propagators at scale
- **Key findings**: `struct-copy prop-network` (13-field copy) is dominant cost; 25 call sites; 6 optimization opportunities identified preserving pure data-in/data-out contract
- **Top 3 optimizations**: (1) mutable worklist/fuel in quiescence loop, (2) field-group struct splitting (hot/warm/cold), (3) batch cell registration via existing transient CHAMP builder
- **Incremental GC**: Future consideration — network IS the provenance trail; understand provenance patterns before committing to self-GC work
- **Next step**: Create design document from audit, scope implementation phases, benchmark before/after
- **Not blocked on anything** — can be implemented independently of PUnify or Track 8

---

## Numerics Tower

### Phase 4: Float32/Float64
- 13 AST nodes per width (type, literal, add/sub/mul/div, neg/abs/sqrt, lt/le, from-nat, if-nan)
- Special values: ±Inf, NaN (multiple bit patterns, unlike Posit's single NaR)
- Cross-family conversions: Float↔Posit, Float↔Rat, Float↔Int
- Numeric trait instances: Add/Sub/Mul/Div/Neg/Abs/Eq/Ord for Float32/Float64
- Open: literal form for IEEE floats vs Posit (currently `~3.14` is Posit32)
- Source: `docs/tracking/2026-02-19_NUMERICS_TOWER_ROADMAP.md`

### Numeric Literal Polymorphism
- `42` polymorphic via `FromInt` — research/future
- Source: `docs/tracking/2026-02-22_NUMERICS_ERGONOMICS_AUDIT.org`

---

## Collections — Deferred Items

### Stage I: Transducer Runners for Non-List
- `into-vec`, `into-set` runners using transducer protocol + transient builders
- Pipe fusion for non-List input types
- **Blocked on**: transient types not exposed at Prologos type level;
  pipe fusion requires elaborator changes

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
- Requires fallible trait resolution (try/fail instead of hard error)
- **Not blocked**, but separate from Layer 1 (fold+build doesn't need this)
- Source: `docs/tracking/2026-02-28_2200_CLAUSE_STYLE_CONSTRAINT_MATCHING.md`

### Sorted Collections (SortedMap, SortedSet)
- B+ tree or red-black tree backends
- **Blocked on**: backend infrastructure not yet built

### Parallel Collection Operations
- Parallel `map`/`filter`/`reduce` via Racket's places/futures
- **Blocked on**: runtime parallelism infrastructure

---

## Collections — Data Structures Roadmap

### Phase 3: Specialized Structures (NOT STARTED)
- 3a: SortedMap + SortedSet (B+ Tree)
- 3b: Deque (Finger Tree)
- 3c: PriorityQueue (Pairing Heap)
- 3d-3f: **Subsumed by Logic Engine** — LVars, LVar-Map/Set, PropNetwork
- 3g: Length-Indexed Vec (dependent types over collections)
- Source: `docs/tracking/2026-02-19_CORE_DATA_STRUCTURES_ROADMAP.md`

### Phase 4: Integration + Advanced (NOT STARTED)
- 4a: QTT Proof Erasure (erase type-level proofs at runtime)
- 4b: CRDT Collections (conflict-free replicated data types)
- 4c: Actor/Place Integration (cross-actor persistent collections)
- 4d: ConcurrentMap (Ctrie — lock-free concurrent hash map)
- 4e: SymbolTable (ART — Adaptive Radix Tree for string keys)
- 4f: **Subsumed by Logic Engine Phase 4** — UnionFind
- Source: `docs/tracking/2026-02-19_CORE_DATA_STRUCTURES_ROADMAP.md`

### Linear Enforcement for Transient Handles
- Transient handles should be used linearly (QTT `m1` multiplicity)
- Currently enforced by convention only
- **Blocked on**: QTT linear tracking for mutable handles
- Source: `docs/tracking/2026-02-20_0347_TRANSIENT_BUILDERS.md`

---

## String Library

### Phase 4a: Grapheme Cluster Operations
- `string-graphemes`, `string-grapheme-count`, grapheme-aware `string-reverse`
- Requires UAX #29 state machine (~30KB Unicode tables)
- **Mitigation**: FFI to Racket's `string-grapheme-span` or ICU library

### Phase 4b: Unicode Normalization
- `string-normalize : NormForm -> String -> String` (NFC/NFD/NFKC/NFKD)
- Bridge to Racket's `string-normalize-nfc` etc. via FFI

### Phase 4c: String Similarity & Diffing
- Jaro distance, common prefix, Myers difference
- Useful for "did you mean?" suggestions in error messages

### Phase 4d: Regex Integration
- Depends on a regex library (not yet designed)

### Phase 4e: Rope / TextBuffer Type
- B-tree rope with O(log n) concat/split

---

## Spec System — Phase 2+

### Phase 2: Example and Property Checking (QuickCheck-style)
- Type-check and run `:examples` entries as tests
- `Gen` trait for type-directed random generation
- Property checking for `:properties` and `:laws`
- Contract wrapping: `:pre`/`:post` generate runtime checks with blame
- Variance inference, `:compose`/`:identity` verification, `:exists` integration
- Source: `docs/tracking/2026-02-22_EXTENDED_SPEC_DESIGN.org`,
  `docs/tracking/2026-02-27_2300_SPEC_FUNCTOR_AUDIT.md` (Tier 3)

### Phase 3: Refinement Types and Verification
- `:refines` → Sigma types, `:properties` → compile-time proof obligations
- Proof search: `:proof :auto` triggers logic engine
- `:measure` for termination checking, opaque functors
- Source: `docs/tracking/2026-02-22_EXTENDED_SPEC_DESIGN.org`

### Phase 4: Interactive Theorem Proving
- Editor protocol for `??` hole interaction
- Case splitting, proof search, refinement reflection
- Source: `docs/tracking/2026-02-22_EXTENDED_SPEC_DESIGN.org`

---

## Syntax — Mixfix

### Statement-Like Forms in `.{...}`
- Keep `.{...}` purely expression-oriented for now

### `do` Notation Inside `.{...}`
- Prefer dedicated `do` blocks for monadic code

### `functor :compose` Auto-Registration of Mixfix Symbol
- Deferred due to coupling concerns

### Extended Pattern Matching in `.{...}`
- E.g., `.{n + 1}` → `suc n` (Agda view patterns)

### Phase 4: Advanced Mixfix
- Unicode operator symbols, postfix operators, full mixfix patterns
- Source: `docs/tracking/2026-02-23_MIXFIX_SYNTAX_DESIGN.org`

---

## Logic Engine / Propagator Architecture — Remaining

### Capabilities — Phase 8d: Multi-Agent Cross-Network Reasoning
- Separate agents on separate propagator networks cross-referencing via
  cross-network propagators, with dependent-typed proof objects as provenance
- **Blocked on**: session type design (Phase 9), dependent capabilities (Phase 7e-7g)
- Source: `docs/tracking/2026-03-01_1500_CAPABILITIES_AS_TYPES_DESIGN.md` §Phase 8d

### Galois Connections — Remaining Deferred
- `connect-domains` Prologos-level wrapper (needs AST keyword or FFI)
- Additional abstract domains (Congruence, Pointer, etc.)
- Source: `docs/tracking/2026-02-27_1026_GALOIS_CONNECTIONS_ABSTRACT_INTERPRETATION.md`

### Propagator-First Phase 3e: Reduction Cache Cells — NOT STARTED
- Convert whnf/nf/nat-value caches to write-through cells
- Gated behind `current-track-reduction-deps?` parameter (off for batch, on for LSP)
- **Risk**: Performance regression in batch mode
- Dependencies: Phase 3a (per-definition cells), Phase 3b (dependency recording) — both complete

---

## FL Narrowing — WS Surface Gaps

### Nested Constructor Patterns in Match Arms
- `| suc zero -> body` treats `zero` as a variable name, not the constructor
- Root cause: `parse-reduce-arm` doesn't recurse into `parse-single-pattern`
- **Workaround**: Use `defn` pattern clauses with double brackets
- Source: C2 investigation, 2026-03-08

### Higher-Order Narrowing in WS Mode
- `[apply-op ?f 3N 2N] = 5N` doesn't trigger HO narrowing via WS pipeline
- Infrastructure works at sexp/API level (23 tests pass)
- Fix requires deeper integration between narrowing substitution env and DT body traversal
- Source: C3 analysis, 2026-03-08

### Multi-arity `|` relation variants — zero-arg solve path
- `solve-goal`'s zero-arg path infers arity from first variant only
- Fix: iterate all variants or require explicit args for multi-arity rels

---

## Homoiconicity

### Phase IV: Runtime Eval & Read
- Runtime `eval`, `read`, `unquote-splicing` (`,@`), quasiquote `,x` in paren forms
- Source: `docs/tracking/2026-02-19_HOMOICONICITY_ROADMAP.md`

---

## Type System — HKT

### HKT-9: Constraint Inference from Usage
- Method-triggered constraint generation algorithm designed, gated behind feature flag
- Source: `docs/tracking/2026-02-20_2100_HKT_GENERIFICATION.md`

---

## Mixed-Type Maps

### Type Narrowing for `map-get`
- When key is statically known, narrow return type
- Source: `docs/tracking/2026-02-22_MIXED_TYPE_MAPS.md`

### Pattern Matching for Union Values
- Convenience forms for matching on union values
- Source: `docs/tracking/2026-02-22_MIXED_TYPE_MAPS.md`

---

## Session Types — Concurrent Runtime

### Full Concurrent Session Execution (NOT STARTED)
- Buffered channels, `!!`/`??` runtime distinction, multiple concurrent prop-networks
- Distributed propagator scheduling, promise cell lifecycle, fairness guarantees
- **Blocked on**: Multi-network runtime infrastructure, Racket-level concurrency primitives
- Source: `docs/tracking/2026-03-03_SESSION_TYPE_IMPL_PLAN.md`

---

## IO Library

### Dependent Send/Receive (`!:`/`?:`) (Phase IO-J)
- Two small gaps: elaborator discards binder name, runtime predicates exclude dsend/drecv
- Reader, preparse, surface syntax, parser, IR, type-checker, pretty-printer are ALL complete
- **Not blocked** — can be implemented immediately
- Source: `docs/tracking/2026-03-05_IO_IMPLEMENTATION_DESIGN.md` §7

### IO Bridge Propagators (Phase IO-B)
- `io-bridge-cell` type, side-effecting IO propagator, wiring into `run-to-quiescence`
- **Blocked on**: Nothing
- Source: `docs/tracking/2026-03-05_IO_IMPLEMENTATION_DESIGN.md` §5

### Boundary Operations: `open`/`connect`/`listen` (Phase IO-C / IO-J)
- Capability-gated channel creation for external resources
- **Blocked on**: IO bridge propagators
- Source: `docs/tracking/2026-03-05_IO_IMPLEMENTATION_DESIGN.md` §6

### Opaque Type Marshalling (Phase IO-A1)
- `expr-opaque` wrapper struct for Racket values (file ports, db connections)
- **Blocked on**: Nothing
- Source: `docs/tracking/2026-03-05_IO_IMPLEMENTATION_DESIGN.md` §4

### `Path` Type (Phase IO-A2)
- Cross-platform file path abstraction (String wrapper initially)
- **Blocked on**: Nothing
- Source: `docs/tracking/2026-03-05_IO_IMPLEMENTATION_DESIGN.md` §8

### `Bytes` Type (Deferred to Phase 2)
- Binary data type. Not needed for text IO but needed for binary IO, SQLite FFI, network
- Source: `docs/tracking/2026-03-05_IO_LIBRARY_DESIGN_V2.md` §12.3

### CSV Maps — `parse-csv-maps`
- Header-aware CSV parsing returning `List [Map String String]`
- **Blocked on**: `map-from-pairs` function
- Source: IO-G plan

---

## Effectful Computation on Propagators — Remaining

### Phase 2: Architecture A+D — Propagator-Native Effectful IO (NOT STARTED)
- Session types as causal clocks, effect ordering via Galois connection
- 16 sub-phases across 6 phases (AD-A through AD-F)
- **Not blocked**: All phases buildable without concurrent runtime
- Source: `docs/tracking/2026-03-07_ARCHITECTURE_AD_IMPLEMENTATION_DESIGN.org`

### Phase 3: Full Reactive Effect Integration (RESEARCH)
- Architecture C — topological scheduling of effect propagators with freeze semantics
- **Blocked on**: Phase 2 completion
- Source: `docs/tracking/2026-03-06_EFFECTFUL_PROPAGATORS_RESEARCH.md` §5c

---

## Session Types — Parameterized/Indexed Sessions & Bounded Liveness

### Parameterized (Indexed) Session Types (RESEARCH)
- Session type definitions parameterized by a value from the dependent type level
- Multiplexed protocols (like CapTP) run N concurrent sub-sessions
- **Not blocked**: Dependent type infrastructure exists. Design work needed.
- Source: `docs/research/2026-03-07_ENDO_AS_SESSION_TYPES.org` §4.3, §15

### Bounded Liveness for Session Types (RESEARCH)
- Graduated roadmap: timeout branches → fuel-indexed recursive sessions → timed session types
- Both converge on parameterized session types
- Source: `docs/research/2026-03-07_ENDO_AS_SESSION_TYPES.org` §5.4, §15.2

---

## Propagator-First Elaboration Migration

### TMS-Aware Infrastructure Cells + Structural State — NOT STARTED
- Infrastructure cells and elab-network structural fields are NOT TMS-managed
- `restore-meta-state!` cannot be retired until this is addressed
- **Fix path**: (1) infra cells → TMS-aware via `net-new-tms-cell`, (2) meta-info/id-map → TMS cells
- **Placement**: PPN Track 4 (Elaboration as Attribute Evaluation) — putting elaboration on the network with formal propagator edges requires TMS-aware cells. Relabeled from "Track 8 prerequisite" (2026-03-30): PPN Track 4 IS the elaboration-on-network track.
- Source: Track 6 Phase 5b findings (commit `cb393bb`)

### Unify type inference and trait resolution under the propagator network — NOT STARTED
- Current elaboration uses propagator network for cells but NOT formal propagator edges
- Constraint solving driven by imperative retry loops, not propagator scheduler
- **Placement**: PPN Track 4 (Elaboration as Attribute Evaluation, IS SRE Track 2C). Relabeled (2026-03-30): this IS Track 4's core scope.
- Source: `docs/tracking/2026-03-11_1800_PROPAGATOR_FIRST_MIGRATION.md`

---

## Off-Network Registry Scaffolding (PM Track 12 consolidation)

**Context**: registries accumulate off-network across tracks as each track needs one. PM Track 12 ("module loading on network") is the designated consolidation track — it will both migrate existing off-network registries to on-network cells AND normalize their APIs into a unified shape.

**Principle** (established via dialogue 2026-04-19): building registries on-network per-track, without PM Track 12's unified design, risks divergent implementations that PM 12 still has to normalize. Disciplined off-network scaffolding + consistent API DNA across registries + explicit scaffolding labels is the lower-risk path. Migration from "Racket parameter holding a hash" to "cell with hash-union merge" is mechanical; migration from "N divergent on-network implementations" is re-architecture.

**Per-track registry tracking** — each track that adds a registry should append its entry here with the shape information PM Track 12 will need.

### PPN Track 4C registry additions

| Registry | Track / Phase | Status | API family / shape | Lifecycle | Retirement plan |
|---|---|---|---|---|---|
| Tier 2 merge-fn registry | 4C / Phase 1 | ⬜ planned | `register-merge-fn!/lattice` — keyword-arg style (align with existing `register-domain!` per Phase 1 mini-design audit, 2026-04-19) | Written at module load; read at `net-new-cell` for domain inheritance and at `net-add-propagator` for structural enforcement; no per-command reset | PM Track 12 migrates to cell; current shape is Racket parameter holding hash (merge-fn → domain-name) |
| `current-source-loc` parameter | 4C / Phase 1.5 | ✅ built 2026-04-19 | Racket parameter (not a keyed registry — single dynamic-scope value, similar class to `current-cell-id-namespace`, `current-speculation-stack`) | Set via `parameterize` at elaborate-entry (per surf-node srcloc field), driver command-entry (per command surf-node srcloc), and scheduler `fire-propagator` wrapper (per propagator struct srcloc field — on-network data). Read at emit sites (warnings, errors, future diagnostics) via `(current-source-loc)` | PM Track 12 evaluates during its scoping phase; may remain a parameter (dynamic-scope concept is parameter-shaped, not cell-shaped). Underlying DATA is on-network (surf-node srcloc fields, propagator struct srcloc field); the parameter is DERIVATION for reader convenience, not captured state |
| `hasse-registry-handle` Racket struct | 4C / Phase 2b | ✅ built 2026-04-19 | Racket-level struct (cell-id + l-domain-name + position-fn + subsume-fn) — lightweight wrapper around the on-network registry cell | Constructed at `net-new-hasse-registry`; held by consumers (Phase 7, 9b) and passed to `hasse-registry-register` / `hasse-registry-lookup` operations. Cell (entries storage) is ON-NETWORK; handle is OFF-NETWORK (Racket-level) | PM Track 12 evaluates shape — handle carries function references (position-fn, subsume-fn) which are Racket-runtime-meaningful only. Not a registry; a single-use per-instance metadata struct. May remain Racket-level OR migrate if PM 12 establishes a broader "handle-like value" pattern for registry wrappers |
| Hasse-registry primitive | 4C / Phase 2b | ⬜ planned | `hasse-registry` primitive parameterized by lattice L; SRE-registered lattice per §6.12 | Written at Phase 7 (impl entries) and Phase 9b (constructor entries); read at resolution time for O(log N) structural navigation | **TBD at Phase 7 mini-design** (M1 external critique finding) — write-path may be cell-write (on-network) OR `register-impl!`/`register-constructor!` scaffolding (PM Track 12). Decision applies to BOTH impl registry AND constructor catalog (M3 symmetric) |
| Impl registry | 4C / Phase 7 | ⬜ planned | Instance of Hasse-registry with L_impl (specificity lattice per §6.12.6) | Written at module load when `impl X Y` declarations elaborate; read during parametric trait resolution | Inherits Hasse-registry primitive's choice (see above) |
| Constructor inhabitant catalog | 4C / Phase 9b | ⬜ planned | Instance of Hasse-registry with L_inhabitant (subsumption lattice per §6.12.6) | Written at module load when `data X := ...` declarations elaborate; read during γ hole-fill | Inherits Hasse-registry primitive's choice (see above); M3 re-firing-on-growth semantics decided at Phase 9b mini-design |
| `current-process-id` parameter | 4C / Phase 1e-β-iii | ⬜ planned | Racket parameter (default 0) tagging Lamport timestamps at E1 clock writes | Read at every `net-write-timestamped` call to tag the new timestamp with the process-id dimension. Under single-BSP (today) always returns 0 — the pid carries no runtime information. Parameterized per-worker in future parallel-execution contexts. | PM Track 12 evaluates: (a) keep as parameter (dynamic-scope-shaped concept matches worker identity), (b) migrate to on-network cell (if worker identity needs network participation), or (c) retire entirely when BSP-round granularity becomes the natural process boundary. |

### PM Track 12 design input from PPN 4C Phase 1e-α (2026-04-20) — submodule-scope primitive

Phase 1e-α's η split of `merge-hasheq-union` surfaced a scope conflation in the current architecture that PM Track 12 is positioned to resolve. Core finding (from [PPN 4C D.3 §6.14.2](2026-04-17_PPN_TRACK4C_DESIGN.md)):

**"Identity-or-error" at a cell needs an answer to "identity within what scope?"** Today's flat shared-persistent-registry-network can't answer this — tests legitimately redefine names across runs, and that's correct behavior under the shared-fixture architecture, not a bug. Per-site identity classification is blocked until scope is first-class on the network.

**PM Track 12's submodule-scope mechanism is the structural answer**. Full discussion at [`2026-03-13_PROPAGATOR_MIGRATION_MASTER.md`](2026-03-13_PROPAGATOR_MIGRATION_MASTER.md) § Track 12, "Design input from PPN 4C Phase 1e-α (2026-04-20)." Summary of requirements this surfaces:

- Submodule as cell-space primitive (structural, not naming convention)
- Scope resolution for registry reads walks the scope chain
- Module reload = retract + reassert (extends S(-1) stratum pattern)
- Test-isolation flows from scope structure, not discipline
- Generalizes to LSP edits, REPL sessions, multi-module compilation

**32 migration-candidate sites** pre-identified in PPN 4C Phase 1e-α commit `876f3bf3`:
- 23 macros.rkt registry sites (all 23 `(define-values ... (net-new-cell ... merge-hasheq-replace))` pairs in `init-macros-cells!`)
- 1 namespace.rkt module-registry site
- 7 metavar-store.rkt per-elab store sites

Each currently uses `merge-hasheq-replace` (honest labeling of today's flat-scope semantics). When PM Track 12 provides submodule-scope, substitution to `merge-hasheq-identity` (already defined + SRE-registered as `'hasheq-identity`) is mechanical.

---

### Information PM Track 12 will want

For every entry in this section, PM 12 needs:
- **Name + API signature** — identifies the migration target
- **Lifecycle** — when written, when read, whether reset between commands (affects merge-function choice and TMS-awareness)
- **Reader count + shape** — informs whether readers can be redirected to cell reads or need API-level migration
- **API family** — identifies normalization targets; registries in the same family can share migration patterns
- **Current scaffolding label** — confirms the entry is intentionally off-network, not accidentally so

### Registries NOT (yet) catalogued

Existing pre-4C off-network registries (`register-domain!`, `register-typing-rule!`, `register-stratum-handler!`, `register-topology-handler!`, various Racket parameters across `prelude.rkt`, `namespace.rkt`, module-registry, trait-registry, etc.) are NOT itemized here — would require a separate cross-track audit. Deferred to PM Track 12's opening scoping phase, which will produce the comprehensive inventory. The discipline codified here (append per track) prevents 4C's additions from disappearing into that audit.

---

## Relational/Unification — PUnify Surface Gaps

### Module-path (`::`) resolution in defr clauses
- `str::concat` unbound inside `defr` clause bodies in `is` goals
- Root cause: `::` lookup doesn't resolve in relational elaboration context
- Source: acceptance file §H4, §K2

### solve-one type inference in defn body
- `solve-one` in `defn` body returns `_` type; `solve` works in same position
- Source: acceptance file §J

### `=` with prelude constructors in defr body
- Prelude constructors (some/none) in `=` goals inside `defr` fail
- Source: acceptance file §K

### Parameterized types in data constructor arguments
- `data Box A := box [List A]` fails with not-a-type-error
- Source: acceptance file §G

### `eq?` trait method not in prelude scope
- `Eq` trait's `eq?` not directly callable from prelude
- Workaround: concrete equality functions (`int-eq`, `str-eq`)
- Source: acceptance file §M

### head + match inference failure
- `[head '[1 2 3]]` followed by pattern match fails type inference
- Pre-existing issue, not PUnify-introduced
- Source: acceptance file §G6

### Narrowing limited to constructor-based patterns
- Functions with Int literal patterns compile to `boolrec+int-eq`, not invertible for narrowing
- Design limitation, not a bug
- Source: acceptance file §I

---

## Surface Syntax Issues

### WS-Mode `:=` Body Parsing with Multi-Form Bodies
- `def x : List Nat := cons 1N [cons 2N nil]` fails — `expand-def-assign` requires exactly one form after `:=`
- Fix: wrap multiple elements as implicit application
- **Not blocked**
- Source: `examples/unified-matching.prologos` Section 5

### Multi-Bracket defn Not Supported
- `defn f [a] [b] body` doesn't work in sexp or WS mode
- Standard pattern is uncurried single-bracket: `defn f [a b] body`
- **Not blocked**: requires parser extension
- Source: `examples/unified-matching.prologos` Section 11

### WS Mode Path Expression Disambiguation
- `.{` conflict between mixfix and path branching syntax
- Sexp mode works correctly. WS disambiguation deferred.
- Source: Phase 3e-e plan (2026-03-03)

---

## LSP / Editor Support

### Token-level srcloc precision for diagnostics
- Errors point to enclosing `defn` instead of exact token
- **Blocked on**: full propagator integration (cell-per-node architecture)
- Source: LSP Tier 2, commit `712c45a`

### Cross-module go-to-definition
- Only works for symbols defined in current file
- **Blocked on**: cross-module location tracking in module registry
- Source: LSP Tier 2, commit `12ea616`

---

## QTT / Multiplicity

### QTT multiplicity violation with generic trait-constrained functions in defn bodies
- Generic `map`/`filter`/`reduce` fail QTT checking due to erased trait dict params
- **Blocked on**: QTT rework for dict-param handling or propagator integration
- Workaround: use list-specific functions or keep expressions standalone
- Source: LSP Tier 4 testing

---

## Arithmetic / Operator Dispatch

### `+` `-` `*` `/` should work as higher-order generic functions
- Currently parser keywords, can't be passed to `map`/`reduce` or use `_` placeholders
- First-class wrappers (`plus`, `minus`, `times`, `divide`) exist as workarounds
- Source: LSP Tier 4 testing

### Trait-constrained functions can't be passed bare to higher-order functions
- `reduce plus 0 '[1 2 3 4 5]` fails — elaborator can't auto-insert dict args in HO position
- **Blocked on**: elaborator enhancement for automatic eta-expansion + dictionary insertion
- Source: LSP Tier 4 testing

---

## Propagator Observatory — Visualization Polish

### 5d: Bookmarked Rounds
- Source: `2026-03-12_PROPAGATOR_VISUALIZATION_DESIGN.md` Phase 5d

### 6a-6d: Polish and Integration
- Performance tuning, SVG/PNG export, contradiction diagnosis view, documentation
- Source: `2026-03-12_PROPAGATOR_VISUALIZATION_DESIGN.md` Phases 6a-6d

---

## Propagator Taxonomy — Extended Research

### Richer Taxonomy Beyond Track 7 Foundation
- Temporal, higher-order, distributed, adaptive, observational propagators
- Informs distributed/concurrent runtime and LSP integration
- **Blocked on**: Track 7 (now COMPLETE — foundation taxonomy established)
- Source: `2026-03-18_TRACK7_PERSISTENT_CELLS_STRATIFIED_RETRACTION.md` §2.6

---

## Coding Standards

### Nat-in-Computations Audit
- Replace `Nat` with `PosInt`/`Int` in computation examples and APIs
- `Nat` only for inductive/proof contexts
- Source: Session type design review (2026-03-03)

---

## Infrastructure / Performance

### Compiled Module Cache
- Persistent compilation cache keyed by module path + source hash
- Source: `docs/tracking/2026-02-19_PIPE_COMPOSE_AUDIT.md`

### Bytecode Compilation
- Compile `.prologos` to intermediate format, skip parse/elaborate/type-check
- Deferred until language stabilizes
- Source: `docs/tracking/2026-02-19_PIPE_COMPOSE_AUDIT.md`

### Batch-Worker Isolation: 12 Tests Fail in Suite, Pass Individually
- **Severity**: Medium — tests pass individually but fail in parallel batch runner
- **Symptoms**: 12 test files show unsolved dict-metas (`[?metaNNNN ...]`) in batch but resolve correctly when run individually via `raco test`
- **Root cause investigation** (Track 4B, commit `70a5763f`):
  - Added 12 missing constraint cell-id parameter resets to batch-worker.rkt — insufficient to fix
  - Cell-ids are correctly reset to `#f` per-file, but the divergence persists
  - Likely cause: `current-prop-net-box` state or elab-network setup differs between individual runs (fresh process) and batch context (shared process with parameterize isolation)
  - The on-network path (`infer-on-network/err`) may not activate in batch context if prop-net-box is stale/absent
- **Affected files**: test-collection-fns-01, test-eq-ord-extended-02, test-generic-ops-01-02, test-generic-ops-02-02, test-hasmethod-01, test-hkt-errors, test-kind-inference-where, test-prelude-system-01, test-punify-integration, test-reducible-02, test-trait-resolution, test-where-parsing
- **Not blocked on**: Track 4B mechanism is correct (all pass individually). This is a test-runner infrastructure issue.
- **Next step**: Audit `current-prop-net-box` lifecycle in batch-worker vs individual test runs. Check whether `infer-on-network/err` is even reached in batch context or falls back immediately.
- **Source**: Track 4B Phase 3 (commit `74f79506`), batch-worker fix (commit `70a5763f`)
