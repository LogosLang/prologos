# SRE Track 2G: Algebraic Domain Awareness — Stage 3 Design (D.1)

**Date**: 2026-03-30
**Series**: [SRE (Structural Reasoning Engine)](2026-03-22_SRE_MASTER.md)
**Prerequisite**: [SRE Track 2F ✅](2026-03-28_SRE_TRACK2F_DESIGN.md) (Algebraic Foundation — relation-level properties)
**Audit**: [SRE Track 2G Stage 2 Audit](2026-03-30_SRE_TRACK2G_STAGE2_AUDIT.md)
**Principle**: Propagator Design Mindspace ([DESIGN_METHODOLOGY.org](principles/DESIGN_METHODOLOGY.org) § Propagator Design Mindspace)

**Research**:
- [Algebraic Embeddings on Lattices](../research/2026-03-28_ALGEBRAIC_EMBEDDINGS_LATTICES.md) — embedding principles, algebraic class hierarchy, capability derivation
- [Module Theory on Lattices](../research/2026-03-28_MODULE_THEORY_LATTICES.md) — endomorphism ring, Krull-Schmidt decomposition, variance as ring action
- [PTF Topology Design Patterns](2026-03-28_PTF_MASTER.md) — Pocket Universe, structural merge, claim lattice patterns
- [Lattice Catalog](../research/2026-03-14_LATTICE_CATALOG.md) — taxonomy of lattice structures

**Cross-series consumers**:
- [PPN Track 3](2026-03-26_PPN_MASTER.md) — parse lattice algebraic classes (token = Boolean, surface = Distributive, type = Heyting)
- [UCS Master](2026-03-28_UCS_MASTER.md) — domain-polymorphic `#=` operator, solving strategy selection
- [PAR Master](2026-03-27_PAR_MASTER.md) — domain class informs parallel scheduling strategy

---

## Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| 0 | Pre-0 benchmarks | ✅ | Merge: ~159μs/op. Property test: 21ms/25 pairs. Error path: 0 contradictions typical. Design unchanged. |
| 1 | Property cell infrastructure on sre-domain | ⬜ | Bool⊥ cells per property, has-property? API |
| 2 | Meet for type domain (variance-aware ring action) | ⬜ | type-lattice-meet + variance-map generalization |
| 3 | Meet for session domain | ⬜ | session-lattice-meet |
| 4 | Property declaration on domain construction | ⬜ | Explicit declaration path (#:distributive #t, etc.) |
| 5 | Property inference from operations | ⬜ | Axiom testing — structural detection fallback |
| 6 | Implication propagators between properties | ⬜ | distributive ∧ has-pseudo-complement → heyting, etc. |
| 7 | First capability consumer | ⬜ | Heyting pseudo-complement for type error reporting |
| 8 | Verification + PIR | ⬜ | Full suite GREEN, benchmark comparison, documentation |

**Phase completion protocol**: After each phase: commit → update tracker → update dailies → run targeted tests → proceed.

---

## §1 Objectives

**End state**: Every SRE domain declares (or has inferred) a set of algebraic properties. These properties are cells on the domain — both pipelines (declaration, inference) write to the same cells. Implication propagators derive composite properties from atomic ones. Downstream consumers (error reporting, backward propagation, solving strategy) read property cells to select capabilities.

**What is delivered**:
1. Property cell infrastructure on `sre-domain` — per-property Bool⊥ cells
2. `has-property?` API for querying domain algebraic properties
3. Meet operations for type and session domains (variance-aware via ring action generalization)
4. Variance-map generalized from relation-dispatch to operation-dispatch (meet/join as ring action)
5. Property declaration syntax on domain construction
6. Property inference from domain operations (axiom testing as fallback)
7. Implication propagators between properties (flat composition, no hierarchy)
8. At least one capability consumer wired up (Heyting pseudo-complement for error reporting)

**What this track is NOT**:
- It does NOT implement CDCL integration for Boolean domains — incomplete because CDCL requires ATMS infrastructure changes; deferred to UCS Track 3
- It does NOT implement automatic Galois bridge derivation — incomplete because this requires the full bidirectional propagator architecture; deferred to PPN Track 5
- It does NOT implement quantale resource tracking — incomplete because QTT/session multiplicity interaction is a separate design concern; deferred to UCS Track 2
- It does NOT implement user-facing `lattice` declarations in the language syntax — incomplete because this requires parser/elaborator support; deferred to NTT implementation tracks

---

## §2 Current State (from Audit)

### 2.1 What Exists

**Relation-level properties** (Track 2F): The `sre-relation` struct has a `properties` field (seteq of symbols). Five relations with properties: equality = `{identity, requires-binder-opening}`, subtype = `{order-preserving}`, duality = `{antitone, involutive}`, phantom = `{trivial}`. Checked at 4 call sites via `sre-relation-has-property?`.

**Variance-map registry** (Track 2F): Hardcoded hash mapping `(relation-name, variance) → sub-relation`. 40 entries. `derive-sub-relation` function. No extension API.

**Two production domains**: `type-sre-domain` (4 merge functions, unify.rkt:77), `session-sre-domain` (1 merge function, session-propagators.rkt:264). 28 ctor-descs across 3 domains.

### 2.2 What's Missing (from Audit §9)

1. **No domain-level property declarations or inference** — can check relation properties but not domain properties
2. **No meet operation for ANY domain** — blocks distributivity, Heyting, Boolean, residuation testing
3. **No extension API for variance-map** — hardcoded, cannot add meet rows
4. **No central domain registry** — domains are module-level variables
5. **No introspection of merge function behavior** — cannot test commutativity, associativity programmatically

### 2.3 The Meet Gap

The audit's most critical finding: meet is required for nearly all interesting algebraic properties. Without meet:
- ❌ Distributivity: `a ⊔ (b ⊓ c) = (a ⊔ b) ⊓ (a ⊔ c)` — needs ⊓
- ❌ Heyting: pseudo-complement requires meet
- ❌ Boolean: complement requires meet
- ❌ Residuation: adjunction test requires meet
- ✅ Commutativity: testable with join only
- ✅ Associativity: testable with join only
- ✅ Idempotence: testable with join only

Meet for type domain = type intersection. Meet for session domain = session intersection. Both are well-defined lattice operations that simply haven't been implemented.

---

## §3 Design

### 3.1 Property Cells on sre-domain

**Propagator Design Mindspace — Four Questions:**

1. **What is the information?** Which algebraic axioms a domain's operations satisfy. Each axiom is a boolean fact about the domain.
2. **What is the lattice?** Per-property: Bool⊥ = `{⊥, #t, #f}` where ⊥ = unknown, #t = property holds, #f = property violated. Join: `⊥ ⊔ #t = #t`, `⊥ ⊔ #f = #f`, `#t ⊔ #f = ⊤` (contradiction — declaration says #t but inference found #f).
3. **What is the identity?** (domain, property-name) pair. Both declaration and inference write to the SAME cell.
4. **What emerges?** The set of satisfied properties determines capabilities. Implication propagators fire when input properties are filled, writing derived properties to their cells.

**Implementation** (D.2 revised — P1: properties as cells, not struct field):

The `sre-domain` struct gains a `property-cell-ids` field — a hash from property name (symbol) to cell-id on the elaboration network. Each property IS a cell. Declaration writes to the cell at domain registration. Inference writes to the cell. Implication propagators are actual propagators connected to these cells.

**Why cells, not struct fields**: (1) Pnet caching — property values persist across sessions, zero re-inference after first run. (2) Self-hosting — properties are visible to the Logos compiler as network state, not opaque Racket data. (3) Consistency — everything is on-network per propagator-only principle.

`has-property?` reads the cell value from the network. Pure read, no side effects.

Property names (atomic, independently testable):

| Property | Meaning | Test Requires |
|----------|---------|--------------|
| `commutative-join` | `a ⊔ b = b ⊔ a` | join only |
| `associative-join` | `(a ⊔ b) ⊔ c = a ⊔ (b ⊔ c)` | join only |
| `idempotent-join` | `a ⊔ a = a` | join only |
| `has-meet` | meet operation exists on this domain | meet registration |
| `commutative-meet` | `a ⊓ b = b ⊓ a` | meet |
| `associative-meet` | `(a ⊓ b) ⊓ c = a ⊓ (b ⊓ c)` | meet |
| `distributive` | `a ⊔ (b ⊓ c) = (a ⊔ b) ⊓ (a ⊔ c)` | join + meet |
| `has-complement` | ∀a, ∃a' : a ⊔ a' = ⊤, a ⊓ a' = ⊥ | join + meet |
| `has-pseudo-complement` | ∀a,b, ∃c maximal : a ⊓ c ≤ b | meet + order |
| `residuated` | meet has a left adjoint (residual) | meet + adjunction |

Composite properties (derived by implication propagators, NOT declared directly):

| Composite | Definition | Source Properties |
|-----------|-----------|-------------------|
| `heyting` | distributive ∧ has-pseudo-complement | Two atomic properties |
| `boolean` | heyting ∧ has-complement | heyting + atomic property |
| `quantale` | complete-lattice ∧ has-tensor ∧ tensor-distributes | Three atomic properties |

**No hierarchy. No inheritance.** Properties are flat. Composites are conjunctions. This is the `bundle` approach applied to algebraic classes.

### 3.2 Meet Operations via Variance-Aware Ring Action

**Propagator Design Mindspace — Four Questions:**

1. **What is the information?** Two lattice values and the need for their greatest lower bound.
2. **What is the lattice?** The domain's own lattice. Meet IS a lattice operation — it produces the greatest lower bound.
3. **What is the identity?** Meet shares the SAME structural decomposition as join. A compound type `Pi(A, B)` decomposes into per-component operations. The identity is the constructor and its component positions.
4. **What emerges?** Meet on a compound type decomposes per-component via the variance-map (ring action). The result tree emerges from per-component meets/joins at fixpoint.

**The ring action generalization** (D.2 revised — P2: ring-action function, not table columns):

The variance-map currently maps `(relation-name, variance) → sub-relation`. The Module Theory view: variance IS a ring element. The ring element's action on ANY operation is uniform:

| Ring Element | Variance | Action on any operation |
|-------------|----------|------------------------|
| **Identity** | Invariant (=) | Preserve: operation stays the same (equality for both join and meet) |
| **Monotone** | Covariant (+) | Preserve: operation stays the same |
| **Antitone** | Contravariant (-) | Flip: join ↔ meet, subtype ↔ subtype-reverse |
| **Trivial** | Phantom (ø) | Erase: operation becomes phantom (ignore) |

Implementation: two-level dispatch:
1. `(variance → ring-element)` — one lookup (same as current variance-map)
2. `(apply-ring-action ring-element operation) → sub-operation` — case dispatch on 4 ring elements

Adding a new operation (meet, widen, narrow) requires ZERO new table entries — the ring action handles it uniformly. "Antitone flips everything" is verified once, not per-operation.

```racket
(define (apply-ring-action ring-element operation)
  (case ring-element
    [(identity)  'equality]        ;; invariant: must be equal regardless of operation
    [(monotone)  operation]        ;; covariant: operation preserved
    [(antitone)  (flip-operation operation)]  ;; contravariant: join↔meet, subtype↔reverse
    [(trivial)   'phantom]))      ;; phantom: erased

(define (flip-operation op)
  (case op
    [(join) 'meet]
    [(meet) 'join]
    [(subtype) 'subtype-reverse]
    [(subtype-reverse) 'subtype]
    [else op]))  ;; unknown operations pass through
```

**Implementation**: `type-lattice-meet` in type-lattice.rkt. For base types: `Int ⊓ Int = Int`, `Int ⊓ String = ⊥` (type-bot). For constructors: component-wise decomposition where each component's operation is determined by `apply-ring-action(component-variance, 'meet)`. Covariant → meet. Contravariant → join (flipped). Invariant → equality.

### 3.3 Property Inference (Detection Fallback)

**Propagator Design Mindspace — Four Questions:**

1. **What is the information?** Evidence from testing domain operations against algebraic axioms. Each (a, b, c) sample triple either confirms or refutes an axiom.
2. **What is the lattice?** Evidence accumulation. Per-property: `⊥ → #t` (all tests pass) or `⊥ → #f` (any test fails). Monotone: one counterexample writes #f permanently.
3. **What is the identity?** The property cell for the domain being tested. Both declaration and inference write to the same cell.
4. **What emerges?** After sufficient testing, the property cell advances from ⊥ to a definitive value. Downstream implication propagators fire.

**Mechanism** (D.2 revised — M3: Pocket Universe on-network, P4: eager at registration):

The inference state for a domain IS a Pocket Universe cell on the network:

```racket
(struct property-inference-state
  (tested-axioms    ;; (hasheq axiom-name → 'passed | 'failed | 'untested)
   sample-count     ;; how many samples tested so far (monotone)
   ) #:transparent)
```

Merge: union of tested-axioms (monotone — axioms only get tested). Failed axiom dominates passed (one counterexample = permanent #f). Sample count takes max.

The inference propagator fires eagerly at domain registration (D.2 P4 revision). It samples values (bot, top, representative constructor instances), tests axioms, and advances the inference state cell. A watcher propagator reads the inference state cell: when an axiom passes with sufficient evidence, it writes #t to the corresponding property cell. When an axiom fails, it writes #f immediately.

**Everything on-network**: The inference state cell participates in pnet caching. First elaboration tests axioms and caches results. Subsequent runs read from cache — zero inference cost. The inference state is also extensible: if future elaboration encounters new representative values, the inference propagator can fire again and test additional samples.

**Connection to property-based testing**: This is a small-scale version of QuickCheck-style property testing. The same Pocket Universe pattern (evidence accumulation as monotone cell value) will later support the `spec` system's `:property` declarations.

### 3.4 Implication Propagators

Properties compose via implications. Each implication is a propagator:

```
;; When distributive AND has-pseudo-complement → write heyting
(implication-propagator
  #:reads (domain.distributive domain.has-pseudo-complement)
  #:when (and (eq? distributive #t) (eq? has-pseudo-complement #t))
  #:writes (domain.heyting := #t))

;; When heyting AND has-complement → write boolean
(implication-propagator
  #:reads (domain.heyting domain.has-complement)
  #:when (and (eq? heyting #t) (eq? has-complement #t))
  #:writes (domain.boolean := #t))
```

These are standard propagators — they fire when their input cells advance. No explicit "class hierarchy" evaluation. The composite property cells fill automatically when their source properties are determined.

**No multiple inheritance because there's no inheritance.** A domain that is both distributive and residuated simply has both property cells at #t. The heyting implication fires because distributive = #t. The residuated implications fire independently. No conflict resolution needed.

### 3.5 Capability Consumer: Heyting Pseudo-Complement for Error Reporting

When a type contradiction is detected (cell reaches ⊤), the error reporter:
1. Reads `type-sre-domain.has-pseudo-complement`
2. If #t: computes the pseudo-complement (maximal consistent refinement)
3. Reports: "The constraint `x : Int ∧ String` is unsatisfiable. The maximal consistent refinement is `x : ⊥`. This arose from constraints C1 and C2."
4. If #f or ⊥: falls back to current error format (no pseudo-complement information)

The pseudo-complement of `a` relative to `b` is the largest `c` such that `a ⊓ c ≤ b`. For the type lattice: "given conflicting constraints A and B on a type variable, what is the largest type that satisfies A and is compatible with B?"

This requires meet (Phase 2) and the heyting property (Phase 6). The consumer wires into the existing error diagnostic system (driver.rkt `emit-error-diagnostic`).

---

## §4 Phasing

### Phase 0: Pre-0 Benchmarks

Profile SRE decomposition cost (from Track 2F benchmarks: <5% of decomposition, <0.1% of elaboration). Measure candidate meet implementation cost. Establish baseline for property testing overhead.

### Phase 1: Property Cell Infrastructure

Add `properties` field to `sre-domain` (hash: symbol → Bool⊥). Implement `sre-domain-has-property?` API. Update domain construction in unify.rkt and session-propagators.rkt. All properties initially ⊥.

**Verification**: Existing tests pass (no behavioral change — properties are unused initially).

### Phase 2: Meet for Type Domain

Implement `type-lattice-meet` mirroring `type-lattice-merge` with variance-aware flipping. Generalize variance-map table to support meet column (ring action extension). Wire meet into type-sre-domain as a registered operation.

**Verification**: Unit tests for meet: `Int ⊓ Int = Int`, `Int ⊓ String = ⊥`, `Pi(Nat, Int) ⊓ Pi(Nat, String) = Pi(Nat, ⊥)`, `Pi(Int, Nat) ⊓ Pi(String, Nat) = Pi(Int|String, Nat)` (contravariant position uses join).

### Phase 3: Meet for Session Domain

Implement `session-lattice-meet`. Simpler than type domain — session constructors have dual-pair structure.

**Verification**: Unit tests for session meet.

### Phase 4: Property Declaration

Add declaration syntax to domain construction: `(sre-domain ... #:properties (hasheq 'distributive #t 'has-pseudo-complement #t))`. Write declared properties to property cells.

Declare properties for existing domains:
- `type-sre-domain`: `{commutative-join, associative-join, idempotent-join, has-meet, distributive, has-pseudo-complement}` → implies heyting
- `session-sre-domain`: `{commutative-join, associative-join, idempotent-join, has-meet}` → basic lattice properties

**Verification**: `sre-domain-has-property? type-sre-domain 'heyting` returns #t (after implication propagators fire in Phase 6).

### Phase 5: Property Inference

Implement axiom testing for undeclared properties. Lazy firing — test only when queried. Sample-based with configurable N. Counterexample immediately writes #f.

Properties testable with join only: commutative-join, associative-join, idempotent-join.
Properties testable with join + meet: distributive, has-complement.

**Verification**: Create a test domain without declarations. Query properties. Verify inference produces correct results.

### Phase 6: Implication Propagators

Register implication propagators for composite properties:
- `distributive ∧ has-pseudo-complement → heyting`
- `heyting ∧ has-complement → boolean`
- (Extensible — future tracks add more implications)

**Verification**: Declare type-sre-domain with atomic properties. Verify `heyting` is derived by implication propagator. Verify `boolean` is NOT derived (type lattice has no complement — `Int | String` has no complement).

### Phase 7: Heyting Error Reporting

Wire pseudo-complement computation into error diagnostic system. When type contradiction detected and `has-pseudo-complement = #t`: compute and report maximal consistent refinement.

**Verification**: Trigger a type error. Verify enhanced error message includes pseudo-complement information.

### Phase 8: Verification + PIR

Full suite GREEN. Benchmark comparison (Phase 0 baseline vs post-implementation). Update design doc, PPN Master, SRE Master, dailies. Write PIR.

---

## §5 Scope Boundaries

| Item | Status | Reason |
|------|--------|--------|
| CDCL for Boolean domains | Deferred to UCS Track 3 | Requires ATMS infrastructure changes |
| Automatic Galois bridge derivation | Deferred to PPN Track 5 | Requires bidirectional propagator architecture |
| Quantale resource tracking | Deferred to UCS Track 2 | QTT/session multiplicity interaction needs separate design |
| User-facing `lattice` declarations | Deferred to NTT implementation | Requires parser/elaborator syntax support |
| Automatic structure detection for user-defined domains | Phase 5 (this track) | Core inference mechanism |

---

## §6 Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Type-lattice-meet implementation complexity | Medium | Meet for union types, dependent types, and metavariables has subtle interactions | Mirror type-lattice-merge structure. Unit test each type constructor. |
| Variance-map generalization breaks existing subtype dispatch | Low | Table is additive (new rows, not changed rows) | Existing entries unchanged. Meet rows are NEW entries. |
| Property inference gives false positives (sampling misses counterexample) | Medium | Domain declared as distributive when it's not | Configurable sample count. Counterexamples immediately write #f. Declaration overrides inference (trusted). |
| Heyting pseudo-complement computation is expensive | Low | Only fires on error paths (not hot path) | Acceptable — error reporting can be slower than elaboration. |
| No meet operation for sub-query domain (3rd domain) | Low | Sub-query domain is internal — properties less important | Defer to future if needed. 2 production domains is sufficient. |

---

## §7 Red-Flag Phrase Audit

| Phrase | Check |
|--------|-------|
| "class hierarchy" | NOT USED — properties are flat, composites are conjunctions via implication propagators |
| "inherits from" | NOT USED — no inheritance. Properties are independent boolean cells. |
| "defaults to #f for safety" | NOT PRESENT — properties default to ⊥ (unknown), not #f. #f means "tested and failed." |
| "pragmatic approach" | NOT USED — each deferral says "incomplete because [specific reason]" |
| "keeping the old path" | NOT PRESENT — meet is additive, existing join/merge untouched |

---

## §8 NTT Speculative Syntax

How domain algebraic properties would appear in NTT declarations:

```prologos
;; Domain declaration with explicit properties
lattice TypeLattice
  :join type-lattice-merge
  :meet type-lattice-meet
  :bot type-bot
  :top type-top
  :properties {distributive, has-pseudo-complement}
  ;; 'heyting' derived automatically by implication propagator

;; Property implication (registered as propagator)
property-implication heyting
  :requires {distributive, has-pseudo-complement}

;; Capability enabled by property
capability pseudo-complement-errors
  :requires {has-pseudo-complement}
  :provides enhanced-error-reporting
```

This is speculative — the actual NTT syntax depends on NTT implementation tracks. But the data model (properties as flat boolean cells, implications as propagators, capabilities as property-gated features) is what Track 2G implements.

---

## §9 Pre-0 Benchmark Data

| Metric | Value | Implication |
|--------|-------|------------|
| Single merge cost | ~159 μs/op | Meet mirrors this — negligible per-operation |
| Commutativity test (5 types, 25 pairs) | 21ms | Property inference cheap (~0.8ms/pair) |
| Associativity test (5 types, 125 triples) | 94ms | Full axiom suite ~200ms one-time |
| unify_steps per file | 36 (simple) → 666 (complex) | Meet adds ≤100ms worst-case if called per unification |
| type_check_ms per file | 90ms → 537ms | Bottleneck is type checking, not SRE |
| Contradictions per file | 0 (typical) | Pseudo-complement fires zero times on success |

**Conclusion**: All design assumptions confirmed. Meet is cheap. Property inference is one-time. Error reporting adds zero overhead on success path. Design proceeds unchanged.

---

## D.2 Self-Critique Findings

### Lens 1 — Principles Challenge

| # | Decision | Principle | Severity | Finding |
|---|----------|-----------|----------|---------|
| P1 | Properties as hash field on sre-domain | Propagator-First | MEDIUM | **Are property "cells" actually cells on the network, or struct fields?** A hash field is data-oriented but not propagator-first. If properties are determined at domain construction (before elaboration), struct fields are honest. If they change mid-elaboration (inference from encountered values), they must be actual network cells. **Resolution**: Properties are determined at domain registration time (startup). Struct fields with a clear initialization protocol are sufficient for Track 2G. The path to actual cells is: domain registration writes to cells on the elaboration network. This is the Track 3-4 refinement (same scaffolding→permanent pattern as Track 2B's merge). Note the scaffolding explicitly. |
| P2 | Variance-map generalization as table with operation column | Data Orientation | LOW | **The ring action is a FUNCTION, not a per-operation table column.** The monotone ring element preserves any operation; the antitone element flips any operation. Adding an operation shouldn't require a new column — the ring element's action handles it. **Resolution**: Implement as ring-action function: `(apply-ring-action ring-element operation) → sub-operation`. The table becomes `(variance → ring-element)` + `(ring-element, operation → sub-operation)`. Cleaner generalization, extensible without new columns. |
| P3 | Property set coverage for PPN Track 3 | Completeness | LOW | PPN Track 3 creates 3-4 new domains (parse lattices). Design addresses existing domains but doesn't detail new domain creation. **Resolution**: Note in design that Phase 4 (declaration syntax) must support new domain construction with properties, not just adding properties to existing domains. |
| P4 | Lazy property inference (fires on query) | Decomplection | LOW | **Query-with-side-effect entangles reading with writing.** Eager inference at domain registration is cleaner. Pre-0 data: ~200ms one-time cost — negligible. **Resolution**: Change to eager inference at registration. The `has-property?` API is a pure read, never triggers inference. Simpler, more predictable. |

### Lens 2 — Codebase Reality Check

| # | Claim | Verification | Result |
|---|-------|-------------|--------|
| R1 | `sre-domain` can gain a `properties` field | 2 production + N test construction sites | ✓ Mechanical. All sites use positional args — must add 10th arg. Consider keyword args. |
| R2 | `type-lattice-meet` mirrors `type-lattice-merge` | Read type-lattice.rkt:125-143 | ✓ Structure mirrorable: swap bot↔top in identity cases, intersection for else. |
| R3 | Constructor meet uses SRE decomposition | Read try-unify-pure:169-204 | ✓ Component-wise, but currently hardcoded per-constructor, not variance-map-driven. Meet would follow same per-constructor pattern or use variance-map. |
| R4 | Contradictions occur in error paths | Pre-0: 0 contradictions in well-typed programs | ✓ Correct — Heyting consumer fires only on type errors. Zero overhead on success. |

### Lens 3 — Propagator Design Mindspace

| # | Component | Four Questions Check | Finding |
|---|-----------|---------------------|---------|
| M1 | Property cells | Information ✓ Lattice ✓ Identity ✓ Emergence ✓ | **Red flag: "hash field" is not a cell.** Properties described as propagator cells but implemented as struct field hash. Scaffolding is acceptable IF noted. The information-flow model is correct even if the scheduling is eager-at-registration. |
| M2 | Meet operations | Information ✓ Lattice ✓ Identity ✓ Emergence ✓ | **Sound.** Meet IS a lattice operation. The ring action generalization encodes ordering in data (table/function), not control flow. Per-component decomposition follows existing SRE pattern. |
| M3 | Property inference | Information ✓ Lattice ✓ Identity ✓ | **Emergence concern**: Does inference EMERGE from the network, or is it an algorithm that RUNS and writes results? Axiom testing (sample values, check equality) is procedural. The RESULT is written to a cell, but the testing process itself isn't information-flow. This is acceptable — axiom testing IS computation that produces information. The information then enters the network via cell write. Not everything needs to be on-network; the RESULT does. |
| M4 | Implication propagators | Information ✓ Lattice ✓ Identity ✓ Emergence ✓ | **Clean.** These ARE actual propagators (or their structural equivalent). Input property cells → derived property cell. Fires when inputs advance. No algorithmic thinking. |
| M5 | Heyting error reporting | Information ✓ Lattice ✓ | **Identity concern**: The pseudo-complement computation — what is the information flow? It reads two conflicting values, computes their meet, and reports the result. This is a MAP propagator: input = contradiction cell, output = error message cell. The computation (meet) is a lattice operation. Sound. |

### Design Changes from D.2

1. **P1**: Note that properties-as-struct-field is scaffolding. The information-flow model is correct; scheduling is eager-at-registration. Track 3-4 path: domain registration writes to cells on the network.
2. **P2**: Implement variance-map generalization as ring-action function, not per-operation columns.
3. **P4**: Change inference from lazy (query-triggered) to eager (registration-triggered). `has-property?` becomes a pure read.

---

## §10 Propagator Design Mindspace Verification

### Property Cells
- [x] Information identified: algebraic axioms as boolean facts
- [x] Lattice defined: Bool⊥ per property, join = information accumulation
- [x] Identity structural: (domain, property-name) pair → one cell
- [x] Emergence: capabilities emerge from implication propagators at fixpoint
- [x] No red flags: no loops, no queues, no scanning, no dispatch

### Meet Operations
- [x] Information identified: two values needing greatest lower bound
- [x] Lattice defined: the domain's own lattice
- [x] Identity structural: same decomposition as join (variance-map = ring action)
- [x] Emergence: per-component meets emerge from cell-tree decomposition
- [x] Ring action check: variance-map generalization encodes ordering in DATA (table), not control flow

### Property Inference
- [x] Information identified: sampled axiom test results
- [x] Lattice defined: evidence accumulation (monotone: ⊥ → #t or ⊥ → #f)
- [x] Identity structural: writes to same property cell as declaration
- [x] Emergence: property determined when evidence sufficient
- [x] Lazy firing: no eager scanning — fires on query

### Implication Propagators
- [x] Information identified: conjunction of source properties
- [x] Lattice defined: Bool⊥ (derived property)
- [x] Identity structural: one cell per derived property per domain
- [x] Emergence: derived properties fire automatically when sources resolve
- [x] No hierarchy: flat composition via propagators, not inheritance
