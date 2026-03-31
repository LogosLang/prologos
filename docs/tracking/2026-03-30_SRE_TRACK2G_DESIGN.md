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
| 0 | Pre-0 benchmarks | ⬜ | Profile SRE decomposition, measure merge/meet candidate cost |
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

**Implementation**: The `sre-domain` struct gains a `properties` field — a hash from property name (symbol) to Bool⊥ value. Initially all ⊥ (unknown). Declaration writes specific properties to #t. Inference tests and writes results.

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

**The ring action generalization**: The variance-map currently maps `(relation-name, variance) → sub-relation`. The generalization: `(operation, variance) → sub-operation`.

| Variance | Join (⊔) | Meet (⊓) | Subtype (≤) |
|----------|----------|----------|-------------|
| Covariant (+) | join | meet | subtype |
| Contravariant (-) | join | **join** (flipped) | subtype-reverse |
| Invariant (=) | equality | equality | equality |
| Phantom (ø) | phantom | phantom | phantom |

The contravariant meet row is the key: meet at a contravariant position uses JOIN, because in the reversed ordering, the greatest lower bound is the least upper bound. This is the antitone ring element's action on the meet operation.

**Implementation**: `type-lattice-meet` in type-lattice.rkt. Mirrors `type-lattice-merge` but dispatches per-component via the meet column of the variance-map. For base types: `Int ⊓ Int = Int`, `Int ⊓ String = ⊥` (type-bot). For constructors: component-wise with variance-aware operation selection.

The variance-map table (sre-core.rkt:246-271) gains meet entries alongside the existing subtype/equality entries. Same lookup mechanism, different operation column. The `derive-sub-operation(operation, variance)` function replaces `derive-sub-relation(relation, variance)` — or extends it to handle both.

### 3.3 Property Inference (Detection Fallback)

**Propagator Design Mindspace — Four Questions:**

1. **What is the information?** Evidence from testing domain operations against algebraic axioms. Each (a, b, c) sample triple either confirms or refutes an axiom.
2. **What is the lattice?** Evidence accumulation. Per-property: `⊥ → #t` (all tests pass) or `⊥ → #f` (any test fails). Monotone: one counterexample writes #f permanently.
3. **What is the identity?** The property cell for the domain being tested. Both declaration and inference write to the same cell.
4. **What emerges?** After sufficient testing, the property cell advances from ⊥ to a definitive value. Downstream implication propagators fire.

**Mechanism**: For each undeclared property (cell at ⊥), the inference engine:
1. Samples values from the domain (using bot, top, and values encountered during elaboration)
2. Tests the axiom against the samples
3. If any test fails: writes #f (property violated)
4. If all tests pass (N samples, configurable): writes #t (property holds, with sampling confidence)

The inference propagator fires lazily — only when a property is QUERIED and is at ⊥. Not eager. This avoids testing properties nobody cares about.

**Connection to property-based testing**: This is a small-scale version of QuickCheck-style property testing. The same infrastructure will later support the `spec` system's `:property` declarations (Prologos language feature). Track 2G's implementation is a foundational piece.

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

## §9 Propagator Design Mindspace Verification

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
