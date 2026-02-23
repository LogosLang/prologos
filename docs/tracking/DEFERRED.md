# Deferred Work

Single source of truth for all deferred work across the Prologos project.
Items are organized by topic. When work is deferred during implementation,
add an entry here immediately.

**Principle**: Completeness over deferral. Items here should be genuinely
blocked on unbuilt infrastructure or uncertain design — not effort avoidance.
See `docs/tracking/principles/DEVELOPMENT_LESSONS.org` § "Completeness Over
Deferral".

**Last consolidated sweep**: 2026-02-23 (all tracking docs audited).

---

## Numerics Tower

### Phase 4: Float32/Float64
- 13 AST nodes per width (type, literal, add/sub/mul/div, neg/abs/sqrt, lt/le, from-nat, if-nan)
- Special values: ±Inf, NaN (multiple bit patterns, unlike Posit's single NaR)
- Cross-family conversions: Float↔Posit, Float↔Rat, Float↔Int
- Numeric trait instances: Add/Sub/Mul/Div/Neg/Abs/Eq/Ord for Float32/Float64
- Open: literal form for IEEE floats vs Posit (currently `~3.14` is Posit32)
- Source: `docs/tracking/2026-02-19_NUMERICS_TOWER_ROADMAP.md`

### Numerics Ergonomics (from audit)
- Posit identity instances (AdditiveIdentity/MultiplicativeIdentity for Posit8-64)
- Posit equality primitives `p{N}-eq` (4 new AST nodes, halves eq cost)
- Bare decimal `3.14` → Posit32 (reader/parser changes)
- Generic operators `+` `-` `*` `/` `<` `<=` `=` as parser keywords → trait dispatch
- Context-resolved `from-int` / `from-rat` keywords
- Generic `negate` and `abs` surface operators
- Numeric type join (`numeric-join`) for Posit dominance coercion
- Implicit coercion warnings (exact → approximate)
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
- 3d: LVars + Logical Variables (monotonic lattice variables)
- 3e: LVar-Map + LVar-Set (lattice-compatible collections)
- 3f: Propagator Network (constraint propagation cells)
- 3g: Length-Indexed Vec (dependent types over collections)
- Source: `docs/tracking/2026-02-19_CORE_DATA_STRUCTURES_ROADMAP.md`

### Phase 4: Integration + Advanced (NOT STARTED)
- 4a: QTT Proof Erasure (erase type-level proofs at runtime)
- 4b: CRDT Collections (conflict-free replicated data types)
- 4c: Actor/Place Integration (cross-actor persistent collections)
- 4d: ConcurrentMap (Ctrie — lock-free concurrent hash map)
- 4e: SymbolTable (ART — Adaptive Radix Tree for string keys)
- 4f: UnionFind (Persistent union-find)
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

### `??` Typed Holes
- `??` reader token → `($typed-hole)` sentinel → `expr-typed-hole` AST node
- Type checker reports diagnostics (expected type + context + suggestions)
- Distinction: `_` = silent/automatic; `??` = interactive/diagnostic
- **Blocked on**: 14-file AST pipeline addition + editor protocol design
- Source: `docs/tracking/2026-02-22_EXTENDED_SPEC_DESIGN.org`

### `property` Keyword
- Named, parameterized conjunction of propositions
- `:includes` for composition (like `bundle` for traits)
- `:laws` key on `trait` declarations
- `property-entry` struct and `current-property-store`
- Source: `docs/tracking/2026-02-22_EXTENDED_SPEC_DESIGN.org`

### Phase 2: Example and Property Checking (QuickCheck-style)
- Parse `:examples`, type-check, run as tests
- `Gen` trait for type-directed random generation
- Property checking for `:properties` and `:laws`
- Contract wrapping: `:pre`/`:post` generate runtime checks with blame
- Source: `docs/tracking/2026-02-22_EXTENDED_SPEC_DESIGN.org`

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

### Auto-Introduce Unbound Type Variables
- Capitalized `A` free in type signature → auto-introduce `{A : Type}`
- Scan after `extract-implicit-binders`, check not in scope as type constructor
- Only kind `Type`; higher-kinded needs explicit or Direction 2
- Source: `docs/tracking/2026-02-22_IMPROVED_IMPLICIT_INFERENCE.org`

### Kind Inference from `:where` Clauses
- `C` in `:where (Seqable C)` → infer `{C : Type -> Type}` from trait decl
- Extend `propagate-kinds-from-constraints` to cases without explicit binder
- Source: `docs/tracking/2026-02-22_IMPROVED_IMPLICIT_INFERENCE.org`

---

## Syntax — Dot-Access

### Phase D: Nil-Coalescing `#:`
- **Note**: The original DEFERRED.md entry called this "Nested Dot-Access"
  but the tracking doc labels Phase D as nil-coalescing `#:`.
  Nested dot-access (`user.address.city`) may also be deferred.
- Source: `docs/tracking/2026-02-21_1800_DOT_ACCESS_SYNTAX.md`

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

## Homoiconicity

### Phase IV: Runtime Eval & Read
- Runtime `eval` — evaluate quoted expressions; requires embedding compiler
- Runtime `read` — parse string to Prologos datum; requires exposing reader
- `unquote-splicing` (`,@`) — only single-element unquote is implemented
- Source: `docs/tracking/2026-02-19_HOMOICONICITY_ROADMAP.md`

---

## Type System — HKT

### HKT-8: Call-Site Rewriting
- Specialization framework implemented, but call-site rewriting deferred
- Users use Tier 2 ops for zero overhead as workaround
- Source: `docs/tracking/2026-02-20_2100_HKT_GENERIFICATION.md`

### HKT-9: Constraint Inference from Usage
- Method-triggered constraint generation algorithm designed
- Gated behind feature flag
- Source: `docs/tracking/2026-02-20_2100_HKT_GENERIFICATION.md`

---

## Mixed-Type Maps

### Type Narrowing for `map-get`
- When key is statically known, narrow return type
- Source: `docs/tracking/2026-02-22_MIXED_TYPE_MAPS.md`

### `A?` Nilable Union Syntax
- `String?` as sugar for `(String | Nil)`
- Source: `docs/tracking/2026-02-22_MIXED_TYPE_MAPS.md`

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
