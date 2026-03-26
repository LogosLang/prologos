# PPN Track 0: Parse Domain Lattice Design

**Stage**: 3 (Design)
**Date**: 2026-03-26
**Series**: PPN (Propagator-Parsing-Network)
**Status**: D.1 — initial design, pending critique

**Prerequisite**: SRE Track 0 ✅ (form registry — rewrite rule infrastructure)
**Enables**: PPN Track 1 (lexer), Track 2 (surface normalization), Track 3 (parser)
**Cross-dependencies**: SRE (form registry = rewrite rule registry), NTT (lattice types), PRN (theoretical grounding)

**Source Documents**:
- [Lattice Foundations for PPN](../research/2026-03-26_LATTICE_FOUNDATIONS_PPN.md) — theoretical grounding, 6 domain lattices, reduced product, scheduling
- [Kan Extensions, ATMS, GFP Parsing](../research/2026-03-26_KAN_EXTENSIONS_ATMS_GFP_PARSING.md) — bilattice, 4-level search, demand lattice
- [Hypergraph Rewriting + Propagator Parsing](../research/2026-03-24_HYPERGRAPH_REWRITING_PROPAGATOR_PARSING.md) — Engelfriet-Heyker, HR grammars
- [SRE Track 0 Design](2026-03-22_SRE_TRACK0_FORM_REGISTRY_DESIGN.md) — domain-parameterized decomposition
- [PPN Master](2026-03-26_PPN_MASTER.md) — series tracking
- [PRN Master](2026-03-26_PRN_MASTER.md) — theory series

---

## Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| Pre-0 | Microbenchmarks: current pipeline stage costs | ⬜ | Measure: reader, preparse, parse, elaborate per-form |
| 0 | Acceptance file: parse lattice exerciser | ⬜ | Exercises each lattice domain with known-ambiguous forms |
| 1 | Token lattice + IndentState struct | ⬜ | `token-cell.rkt`: lattice struct, merge, bot/top |
| 2 | Surface bilattice (per-item cells) | ⬜ | `parse-cell.rkt`: SPPF node, derivation/elimination orderings |
| 3 | Demand lattice | ⬜ | `demand-cell.rkt`: Position × Domain demands |
| 4 | Bridge specifications (6 bridges) | ⬜ | α/γ for each domain pair |
| 5 | NTT speculative syntax | ⬜ | Each lattice + bridge in NTT syntax |
| 6 | Small integration test (hand-constructed network) | ⬜ | Parse `def x : Int := 42` through lattice cells |
| 7 | A/B benchmarks + verification | ⬜ | Compare lattice operations against current pipeline |
| 8 | Update dailies + tracker | ⬜ | Per-phase completion |
| 9 | PIR | ⬜ | Per methodology |

---

## 1. Vision

PPN Track 0 defines the LATTICE SUBSTRATE that all subsequent PPN tracks
build on. It doesn't replace any existing pipeline code — it defines the
data structures and operations that Tracks 1-9 will use.

The key architectural decision: parsing is a FIXPOINT COMPUTATION on
lattice-valued cells connected by propagators. Each lattice domain
(tokens, surface syntax, core AST, demands) has a well-defined merge
operation. Ambiguity is lattice structure (multiple values), not control
flow (backtracking). Disambiguation is cross-domain information flow
via Galois bridges, not heuristics.

**What Track 0 delivers**: Racket structs for each lattice, merge
functions, bot/top values, bridge α/γ functions, and a small integration
test proving the lattices compose correctly on the propagator network.

**What Track 0 does NOT deliver**: No pipeline replacement. No lexer,
parser, or elaborator changes. Those are Tracks 1-4.

---

## 2. Lattice Domains

### 2.1 Three key findings from track analysis

**Finding 1: Preparse is NOT a separate lattice.** Surface normalization
(defmacro expansion, let/cond desugaring, implicit map rewriting) uses
the SAME cell + SRE infrastructure as structural decomposition. Rewrite
rules are registered form entries. Normalization is quiescence. No new
lattice needed — Track 2 registers rewrite rules with the existing SRE
form registry, applied to surface forms instead of type expressions.

**Finding 2: Parse cell granularity is the critical design choice.**
Per-item cells (one cell per Earley item) give standard O(n³) complexity.
Per-span cells (one cell per input span) give O(n⁵) — quadratic blowup
from merge cost. Track 0 MUST specify per-item granularity.

**Finding 3: Context-sensitive lexing needs a SurfaceToToken bridge.**
Our WS syntax has tokens whose meaning depends on parse context (`>` in
angle brackets, keywords in certain positions). The bridge γ-function
projects parse context into token disambiguation. First concrete instance
of "every domain is a disambiguation source."

### 2.2 Token Lattice (L_token)

**Purpose**: Classify character sequences into token types. Handle
indentation-sensitivity and context-sensitive disambiguation.

```racket
(struct token-cell-value
  (type          ;; symbol: 'identifier, 'keyword, 'number, 'string, 'operator, 'delimiter, 'whitespace, 'error
   lexeme        ;; string: the actual character sequence
   span          ;; (start . end): position in source
   indent-level  ;; exact-nonneg-integer: column of first non-whitespace char on this line
   indent-delta  ;; 'indent | 'dedent | 'same | #f: change from previous line
   )
  #:transparent)
```

| Property | Value |
|----------|-------|
| Carrier | `token-cell-value \| bot \| top` |
| Bot | `'token-bot` (unclassified position) |
| Top | `'token-error` (lexer error) |
| Join | ATMS branching for ambiguous tokens (rare) |
| Height | 3 (bot → value → error). Finite. |
| Merge | If same type+lexeme: identity. If different: ATMS branch. |

**Design decisions**:
- `indent-level` and `indent-delta` are PART OF the token, not separate
  state. This avoids a separate indent lattice. The indent information
  flows forward through the token stream.
- Context-sensitive disambiguation (is `>` closing an angle bracket?)
  comes from the SurfaceToToken bridge γ-function, NOT from the token
  lattice itself. The token lattice is context-free; context comes from
  the bridge.
- ATMS branching for ambiguous tokens is rare. Most tokens have unique
  classification. The lattice is simple (height 3) with ATMS for edge
  cases.

### 2.3 Surface Bilattice (L_surface)

**Purpose**: Represent parse state as a bilattice combining derivation
(what's parsed) and elimination (what's impossible). Cells are PER-ITEM
(one per Earley item), not per-span.

```racket
;; An Earley item: production + dot position + origin
(struct parse-item
  (production   ;; symbol: grammar production name
   dot          ;; exact-nonneg-integer: position of dot in RHS
   origin       ;; exact-nonneg-integer: start position of this item
   span-end     ;; exact-nonneg-integer: current end position
   )
  #:transparent)

;; A parse cell value (bilattice)
(struct parse-cell-value
  (derivations    ;; set of derivation-trees (lfp component)
   eliminations   ;; set of assumption-ids that are retracted (gfp component)
   )
  #:transparent)

;; A derivation tree node (SPPF-like)
(struct derivation-node
  (item           ;; parse-item: which item this derives
   children       ;; list of derivation-node: sub-derivations
   assumption-id  ;; assumption-id | #f: ATMS tag for this derivation
   cost           ;; real (tropical enrichment, default 0)
   )
  #:transparent)
```

| Property | Value |
|----------|-------|
| Carrier | `parse-cell-value \| bot \| top` |
| Bot (derivation) | `(parse-cell-value (seteq) (seteq))` — no derivations, nothing eliminated |
| Top (derivation) | `'parse-error` |
| Join (derivation) | Set union of derivation trees (add alternatives) |
| Join (elimination) | Set union of assumption-ids (accumulate eliminations) |
| Height | O(n² · G) for input length n, grammar size G |
| Merge | Bilattice merge: union derivations AND union eliminations |

**Design decisions**:
- **Per-item cells**, not per-span. Each Earley item gets its own cell.
  Completion/prediction/scanning are propagators that read input cells
  and write output cells. This gives O(n³) overall — same as standard
  Earley.
- **Bilattice structure**: derivation ordering (lfp: accumulate parses)
  and elimination ordering (gfp: rule out impossibilities). The well-
  founded parse is the combined fixpoint.
- **ATMS integration**: each derivation-node carries an optional
  assumption-id. Ambiguous derivations are different ATMS branches. Type
  contradictions retract assumptions, adding to the elimination set.
- **Tropical cost**: each derivation-node carries a cost (default 0).
  Error recovery assigns costs to repair actions. The tropical merge
  (min-plus) selects cheapest surviving derivation.

### 2.4 Core Lattice (L_core)

**Purpose**: Hold elaborated AST nodes. Deterministic given surface +
type — the core lattice is simple; ambiguity is handled by ATMS tagging
on the surface and type lattices.

```racket
;; Core cell value = our existing expr-* AST nodes
;; No new struct needed — reuse syntax.rkt expressions
;; ATMS tagging comes from the propagator network (tagged-entry)
```

| Property | Value |
|----------|-------|
| Carrier | `expr-* \| bot \| top` |
| Bot | `'core-bot` (unelaborated) |
| Top | `'core-error` (elaboration error) |
| Join | N/A — core is deterministic given (surface, type) |
| Merge | Replacement (new elaboration supersedes) |

**Design decision**: Core lattice is TRIVIAL. The complexity lives in
the surface bilattice (ambiguity) and type lattice (inference). The core
lattice is just the output — one cell per definition, set once.

### 2.5 Demand Lattice (L_demand)

**Purpose**: Track what information is needed at what position. Unifies
DT demands (narrowing), type-checking demands (bidirectional), and parse
demands (disambiguation).

```racket
(struct demand
  (position     ;; exact-nonneg-integer | symbol: where in the source/AST
   domain       ;; symbol: 'token, 'surface, 'core, 'type, 'narrowing
   specificity  ;; symbol: 'constructor, 'type, 'value, 'any
   )
  #:transparent)

(struct demand-cell-value
  (demands      ;; set of demand: accumulated demands at this point
   )
  #:transparent)
```

| Property | Value |
|----------|-------|
| Carrier | `demand-cell-value \| bot` |
| Bot | `(demand-cell-value (seteq))` — no demands |
| Join | Set union (accumulate demands) |
| Height | Bounded by |positions| × |domains| × |specificities| |
| Merge | Union of demand sets |

**Design decision**: Demands are MONOTONE (only grow). A demand, once
placed, is never retracted. This is correct: "I need to know X" doesn't
become "I don't need to know X" — once you've asked, you've asked.
The demand lattice has no gfp/elimination component.

### 2.6 Cost Lattice (L_cost) — OE Enrichment

**Purpose**: Tropical semiring for cost-optimal selection. Enriches
other lattices — not a standalone domain.

```racket
;; Cost is a field on derivation-node (§2.3), not a separate cell.
;; The tropical merge (min) selects cheapest derivation.
;; No separate cost lattice struct needed for Track 0.

;; When OE Track 0 provides the tropical infrastructure,
;; the cost field becomes a first-class enrichment.
```

**Design decision**: Cost is a FIELD on derivation-node, not a separate
lattice. This is simpler for Track 0 and sufficient for Tracks 1-6.
Full tropical infrastructure (OE Track 0) provides the generalization
when needed.

### 2.7 Existing Lattices (unchanged)

Type lattice (L_type), Multiplicity lattice (L_mult), Session lattice
(L_session) — existing infrastructure, unchanged. They participate in
the reduced product via Galois bridges.

---

## 3. Galois Bridges

Six bridges connect the parse domains to each other and to existing
domains. Each bridge has an α (forward) and γ (backward) function.

### 3.1 TokenToSurface

```
α: token-cell-value → parse-cell-value
   "This token feeds into these parse items"
   Scanning step in Earley: token at position i feeds items expecting
   this token type at position i.

γ: parse-cell-value → token-cell-value
   "This parse context constrains token classification"
   Context-sensitive lexing: parse state disambiguates tokens.
   Example: in angle-bracket context, `>` is delimiter not operator.
```

### 3.2 SurfaceToCore

```
α: parse-cell-value → core-cell-value
   "This completed parse produces this AST node"
   When a parse item is complete (dot at end of production),
   construct the corresponding core AST.

γ: core-cell-value → parse-cell-value
   "This elaboration result constrains which parse is valid"
   Type-directed disambiguation: if elaboration of parse A fails,
   eliminate derivation A from the surface bilattice.
```

### 3.3 SurfaceToType

```
α: parse-cell-value → type-cell-value
   "This parse form generates these type constraints"
   Elaboration of a parsed form creates type cells and constraints.

γ: type-cell-value → parse-cell-value
   "This type information disambiguates parsing"
   Arity, argument types, return types constrain which parse
   alternatives are valid. The γ-function projects type constraints
   into parse elimination.
```

### 3.4 SurfaceToDemand

```
α: parse-cell-value → demand-cell-value
   "Parsing this form requires this information"
   A grammar rule that needs to see a token/type/constructor
   generates a demand.

γ: demand-cell-value → parse-cell-value
   "This demand triggers targeted computation"
   Right Kan: demands flow backward, triggering only the computation
   needed to satisfy them.
```

### 3.5 TypeToToken (indirect, via Surface)

Type information constraining token classification flows through two
bridges: TypeToSurface γ → SurfaceToToken γ. No direct TypeToToken
bridge needed — the composition is handled by propagation through
intermediate cells.

### 3.6 DemandToNarrowing

```
α: demand-cell-value → narrowing-demand
   "A parse/type demand triggers narrowing of a variable"
   When disambiguation needs to know a variable's constructor,
   demand flows into the narrowing engine.

γ: narrowing-result → demand-cell-value
   "Narrowing result satisfies a demand"
   The narrowing engine produces a constructor → the demand is
   satisfied → downstream computation proceeds.
```

---

## 4. NTT Speculative Syntax

```prologos
;; === Level 0: Parse Domain Lattices ===

;; Token lattice (value lattice — simple merge)
data TokenValue
  := token-bot
   | token [type : Symbol] [lexeme : String] [span : Span]
           [indent-level : Int] [indent-delta : IndentChange]
   | token-error
  :lattice :value
  :bot token-bot
  :top token-error

;; Surface bilattice (structural lattice — bilattice merge)
data ParseValue
  := parse-bot
   | parse-cell [derivations : Set DerivationNode]
                [eliminations : Set AssumptionId]
   | parse-error
  :lattice :bilattice
  :bot parse-bot
  :top parse-error
  :derivation-join set-union
  :elimination-join set-union

;; Demand lattice (value lattice — set accumulation)
data DemandValue
  := demand-bot
   | demands [set : Set Demand]
  :lattice :value
  :bot demand-bot
  :join set-union

;; === Level 4: Bridges ===

bridge TokenToSurface
  :from TokenValue
  :to   ParseValue
  :alpha token-to-parse-scan
  :gamma parse-context-to-token-disambiguate

bridge SurfaceToCore
  :from ParseValue
  :to   TypeExpr    ;; existing type lattice
  :alpha parse-to-type-elaborate
  :gamma type-to-parse-disambiguate

bridge SurfaceToDemand
  :from ParseValue
  :to   DemandValue
  :alpha parse-to-demand
  :gamma demand-to-targeted-computation

;; === Level 5: Parse Stratification ===

stratification ParseLoop
  :strata [S-retract S-parse S-elaborate S-disambiguate]
  :fiber S-parse
    :networks [token-net surface-net]
    :bridges [TokenToSurface]
  :fiber S-elaborate
    :networks [core-net type-net]
    :bridges [SurfaceToCore SurfaceToType]
  :fiber S-disambiguate
    :networks [demand-net]
    :bridges [SurfaceToDemand]
    ;; Left Kan: partial type info prunes parse branches
    ;; Right Kan: demands focus computation
  :exchange S-parse <-> S-elaborate
    :left  partial-parse -> type-constraints
    :right type-result -> parse-elimination
  :barrier S-retract
    :commit retract-eliminated-derivations
  :fuel :cost-bounded
  :where [WellFounded ParseLoop]
```

---

## 5. Implementation Plan

### Phase Pre-0: Pipeline Cost Measurement

Measure current per-form costs across the pipeline:
- Reader: time per form (character → sexp)
- Preparse: time per form (sexp → expanded sexp)
- Parser: time per form (sexp → surface AST)
- Elaborator: time per form (surface → core + types)

This establishes baselines for Track 1-4 to compare against.

### Phase 1: Token Lattice Struct

**File**: `racket/prologos/parse-lattice.rkt` (new)

**Deliverables**:
1. `token-cell-value` struct with merge function
2. `token-lattice-merge`: identity if same, ATMS branch if different
3. `token-bot`, `token-top` sentinels
4. `token-lattice-spec`: `sre-domain`-compatible lattice spec for
   registration with the propagator network

**Tests**: `tests/test-parse-lattice.rkt` — merge operations, bot/top
behavior, ATMS branching for ambiguous tokens.

Update dailies + tracker.

### Phase 2: Surface Bilattice Struct

**File**: `racket/prologos/parse-lattice.rkt` (extend)

**Deliverables**:
1. `parse-item` struct (production, dot, origin, span-end)
2. `derivation-node` struct (item, children, assumption-id, cost)
3. `parse-cell-value` struct (derivations set, eliminations set)
4. `parse-bilattice-merge`: union derivations AND union eliminations
5. Per-item cell creation: given a parse item, get-or-create its cell
6. Derivation construction: given completed item + children, build node

**Tests**: merge derivation sets, elimination accumulation, bilattice
fixpoint on small hand-built parse.

Update dailies + tracker.

### Phase 3: Demand Lattice Struct

**File**: `racket/prologos/parse-lattice.rkt` (extend)

**Deliverables**:
1. `demand` struct (position, domain, specificity)
2. `demand-cell-value` struct (demands set)
3. `demand-merge`: set union
4. Demand creation helpers: `demand-token`, `demand-type`, `demand-constructor`

**Tests**: demand accumulation, demand set operations.

Update dailies + tracker.

### Phase 4: Bridge Specifications

**File**: `racket/prologos/parse-bridges.rkt` (new)

**Deliverables**:
1. `token-to-surface-alpha`: token → parse items (scanning)
2. `surface-to-token-gamma`: parse context → token disambiguation
3. `surface-to-core-alpha`: completed parse → AST node
4. `core-to-surface-gamma`: type error → parse elimination
5. `surface-to-demand-alpha`: parse rule → demands
6. `demand-to-narrowing-alpha`: demand → narrowing request

Each bridge specified as an `sre-domain`-compatible pair (α, γ) that
can be installed as cross-domain propagators.

**Tests**: each bridge function on small examples. Round-trip: α then γ
should be coherent (not necessarily identity, but adjunction laws hold).

Update dailies + tracker.

### Phase 5: NTT Speculative Syntax

Add §4's syntax to the NTT Syntax Design document. Verify it composes
with existing NTT forms (lattice, propagator, bridge, stratification).

Update dailies + tracker.

### Phase 6: Integration Test

**Deliverable**: A hand-constructed propagator network that parses
`def x : Int := 42` through:
1. Token cells (7 tokens: `def`, `x`, `:`, `Int`, `:=`, `42`, newline)
2. Surface cells (parse items for the `def` production)
3. Core cell (the elaborated `(def x Int 42)` AST node)
4. Type cell (verifies `42 : Int`)
5. Demand cell (elaborate demands the type of `42`)

The test manually creates cells and installs propagators (no lexer or
parser — just the lattice infrastructure). Validates: cells merge
correctly, bridges propagate, ATMS handles a deliberate ambiguity,
bilattice elimination removes the wrong parse.

Update dailies + tracker.

### Phase 7: A/B Benchmarks

Measure lattice operation costs:
- Token merge: ns/call
- Parse bilattice merge: ns/call (vary set sizes)
- Demand merge: ns/call
- Bridge α/γ: ns/call for each bridge

Compare against current pipeline stage costs (from Pre-0).

Update dailies + tracker.

### Phase 8: PIR

Per PIR methodology. Cross-reference with SRE Track 0 PIR (similar
scope — lattice infrastructure without pipeline integration).

Update dailies + tracker.

---

## 6. Principles Alignment

**Propagator-First**: All parse state is lattice-valued cells on the
network. No off-network parse state. Ambiguity is lattice structure,
not control flow.

**Data Orientation**: Parse items, derivation nodes, demands are pure
data structs. No closures in lattice values. Bridges are pure α/γ
functions (from Track 8D lesson: data at rest, closures derived).

**Correct-by-Construction**: The bilattice structure guarantees: only
derivations that survive elimination are in the well-founded parse.
This is structural correctness, not disciplined checking.

**Completeness**: The bilattice (derivation × elimination) is the
COMPLETE parse model. Simple derivation-only lattices miss the
elimination direction. The bilattice does the hard thing right.

**Composition**: Six bridges connect parse domains to existing domains.
The reduced product composes automatically via propagation. No manual
composition code.

**Challenge**: Is the bilattice NECESSARY for Track 0, or is it
premature? Counter: Track 0 defines the lattice. If we define it as
simple (derivation only) and later need elimination, we retrofit.
If we define it as bilattice from the start, no retrofit needed. The
bilattice is one additional set field — negligible implementation cost,
significant architectural benefit.

**Challenge**: Is the demand lattice necessary for Track 0? It's
cross-cutting — used by Tracks 4, 5, 8. But if we don't define it in
Track 0, Tracks 4+ define their own ad-hoc demand mechanisms (like our
current DT demands). Defining it now prevents the ad-hoc divergence.

---

## 7. Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| SPPF merge complexity at scale | MEDIUM | Per-item cells, not per-span. O(n³) guaranteed. |
| Bilattice adds complexity without immediate payoff | LOW | Single additional set field. Payoff in Tracks 5-6. |
| Bridge α/γ correctness (adjunction laws) | MEDIUM | Integration test (Phase 6) validates round-trip coherence. |
| Demand lattice overengineered for Track 0 | LOW | Simple set-union lattice. If unused, zero overhead. |
| Performance: lattice merge slower than current pipeline | MEDIUM | Pre-0 + Phase 7 benchmarks detect before integration. |

---

## 8. Completion Criteria

1. All 4 lattice structs defined with merge functions and bot/top values.
2. All 6 bridge specifications with α/γ functions.
3. Integration test: hand-constructed parse of `def x : Int := 42` through
   token → surface → core → type cells with bilattice elimination.
4. NTT speculative syntax added to NTT Syntax Design document.
5. A/B benchmarks: lattice merge operations < 1μs per call.
6. Suite green (no regressions from new module).
7. PIR written per methodology.
