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
| 1 | Property cell infrastructure on sre-domain | ⬜ | 4-valued cells (⊥, #t, #f, ⊤) per property, has-property? API (D.3 F1) |
| 1.5 | Domain registry | ⬜ | Cell on network: domain-name → sre-domain. register-domain!, lookup-domain. (D.3 F10) |
| 2 | Meet for type domain (variance-aware ring action) | ⬜ | type-lattice-meet + ring-action function. Context-dependent equality (D.3 F6). Meta → ⊥ (D.3 F4). |
| 3 | Meet for session domain | ⬜ | session-lattice-meet |
| 4 | Property declaration on domain construction | ⬜ | Explicit declaration via register-domain! |
| 5 | Property inference from operations | ⬜ | Pocket Universe evidence cell: confirmed(count) \| refuted(witness) (D.3 F2). Eager-synchronous + pnet cache. |
| 6 | Implication propagators between properties | ⬜ | Auto-installed for all registered domains via registry (D.3 F10). Retroactive firing verified (D.3 F5). |
| 7 | First capability consumer | ⬜ | Heyting pseudo-complement for ground type sublattice (D.3 F7) |
| 8 | Verification + PIR | ⬜ | Full suite GREEN, benchmark comparison, documentation |

**Phase completion protocol**: After each phase: commit → update tracker → update dailies → run targeted tests → proceed.

---

## §1 Objectives

**End state**: Every SRE domain declares (or has inferred) a set of algebraic properties. These properties are cells on the domain — both pipelines (declaration, inference) write to the same cells. Implication propagators derive composite properties from atomic ones. Downstream consumers (error reporting, backward propagation, solving strategy) read property cells to select capabilities.

**What is delivered**:
1. Property cell infrastructure on `sre-domain` — per-property 4-valued cells (⊥, #t, #f, ⊤) on the elaboration network
2. Central domain registry — cell on network, `register-domain!` / `lookup-domain` API
3. `has-property?` API for querying domain algebraic properties (pure read)
4. Meet operations for type and session domains (variance-aware via ring action function)
5. Ring action generalization — variance → ring element → uniform operation dispatch
6. Property declaration syntax on domain construction
7. Property inference from domain operations (Pocket Universe evidence cell with counterexample witnesses)
8. Implication propagators between properties (flat composition, auto-installed via domain registry)
9. At least one capability consumer wired up (Heyting pseudo-complement for ground type sublattice)

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
2. **What is the lattice?** Per-property: 4-valued = `{⊥, #t, #f, ⊤}` where ⊥ = unknown, #t = confirmed, #f = refuted, ⊤ = contradiction (declaration says #t but inference found #f). Join: `⊥ ⊔ #t = #t`, `⊥ ⊔ #f = #f`, `#t ⊔ #f = ⊤`. (D.3 F1: ⊤ semantics explicit — implication propagators treat ⊤ as #f for capability gating. ⊤ IS preserved in cell for diagnostics: "declared distributive but inference refuted.")
3. **What is the identity?** (domain, property-name) pair. Both declaration and inference write to the SAME cell on the elaboration network.
4. **What emerges?** The set of satisfied properties determines capabilities. Implication propagators fire when input properties are filled, writing derived properties to their cells. ⊤ propagates as #f for capability gating (conservative: contradicted = not available).

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

### 3.1.5 Domain Registry (D.3 F10)

**Propagator Design Mindspace — Four Questions:**

1. **What is the information?** Which domains exist and what operations/properties they provide.
2. **What is the lattice?** Set-accumulation: domains only get added (monotone). The registry value is a hash from domain-name to sre-domain. Join is hash-union.
3. **What is the identity?** Domain name (symbol). Each domain has a unique name.
4. **What emerges?** Propagators that need "all domains" (implication installation, property inference scheduling) fire when the registry cell advances. New domain registered → implication propagators auto-installed.

**Implementation**: `current-domain-registry` — a cell on the elaboration network. Value: `(hasheq 'type type-sre-domain 'session session-sre-domain ...)`.

- `register-domain!(name, domain)` — writes to registry cell (hash-set, monotone)
- `lookup-domain(name)` — reads from registry cell (hash-ref)
- Existing domain creation migrated from module-level variables to `register-domain!` calls
- Phase 6: a "for-all-domains" propagator reads the registry and installs implication propagators for each domain. When a new domain is registered, the propagator fires and installs implications for the new domain.

Parallels `ctor-registry.rkt` at the domain level. Pnet-cacheable (domain list persists across sessions). Self-hosting visible (Logos compiler can enumerate domains).

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
    [(identity)  (equality-for-context operation)]  ;; D.3 F6: context-dependent equality
    [(monotone)  operation]        ;; covariant: operation preserved
    [(antitone)  (flip-operation operation)]  ;; contravariant: join↔meet, subtype↔reverse
    [(trivial)   'phantom]))      ;; phantom: erased

;; D.3 F6: Equality in join context produces ⊤ on mismatch.
;; Equality in meet context produces ⊥ on mismatch. Distinct sub-operations.
(define (equality-for-context operation)
  (case operation
    [(join)  'equality-join]      ;; mismatch → ⊤
    [(meet)  'equality-meet]      ;; mismatch → ⊥
    [else    'equality]))         ;; subtype, other: standard equality

(define (flip-operation op)
  (case op
    [(join) 'meet]
    [(meet) 'join]
    [(subtype) 'subtype-reverse]
    [(subtype-reverse) 'subtype]
    [else (error 'flip-operation "unknown operation: ~a" op)]))  ;; D.3 F9: fail-closed
```

**Implementation**: `type-lattice-meet` in type-lattice.rkt. For base types: `Int ⊓ Int = Int`, `Int ⊓ String = ⊥` (type-bot). For constructors: component-wise decomposition where each component's operation is determined by `apply-ring-action(component-variance, 'meet)`. Covariant → meet. Contravariant → join (flipped). Invariant → equality-meet (mismatch → ⊥).

**Metavariables** (D.3 F4): `?A ⊓ T = ⊥` (conservative). Meet cannot resolve an unsolved meta — the greatest lower bound is unknown. Returns ⊥ (type-bot). This is acceptable because: (1) property inference uses ground types as samples (no metas), (2) pseudo-complement fires on error paths where metas are typically resolved. If both sides have unsolved metas: `?A ⊓ ?B = ⊥`.

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
  (tested-axioms    ;; (hasheq axiom-name → axiom-status)
   sample-count     ;; how many samples tested so far (monotone)
   ) #:transparent)

;; D.3 F2: Per-axiom status lattice with counterexample witness
;; untested < confirmed(count) < refuted(witness)
;; Refuted dominates confirmed. Witness preserved for error reporting.
(struct axiom-untested () #:transparent)
(struct axiom-confirmed (count) #:transparent)     ;; count = number of passing samples
(struct axiom-refuted (witness) #:transparent)       ;; witness = (a, b, c) triple that failed
```

Merge per-axiom: `untested ⊔ confirmed(n) = confirmed(n)`, `untested ⊔ refuted(w) = refuted(w)`, `confirmed(n) ⊔ confirmed(m) = confirmed(max(n,m))`, `confirmed(n) ⊔ refuted(w) = refuted(w)` (counterexample dominates). Witness preserved for diagnostics: "distributivity fails because join(Int, Pi(Nat,Int)) ≠ Pi(Nat, join(Int,Int))".

Merge of inference-state: union of tested-axioms (monotone per axiom). Sample count takes max.

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

**Scope** (D.3 F7): Phase 7 implements pseudo-complement for the **ground type sublattice** — base types (Int, Nat, String, Bool), simple constructors (Pi, Sigma with ground components), and unions. Pseudo-complement for types containing unsolved metas or dependent types is a research question (may be undecidable for full dependent types). The `has-pseudo-complement` property declared on the type domain means: pseudo-complement is computable for ground types. Error reporting uses it when the conflicting types are ground (which is the common case for type errors like `Int ∧ String`).

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

Implement axiom testing for undeclared properties. Eager firing at domain registration (D.2 P4). Pocket Universe evidence cell with confirmed(count)/refuted(witness) per axiom (D.3 F2). Counterexample immediately writes refuted with witness.

Properties testable with join only: commutative-join, associative-join, idempotent-join.
Properties testable with join + meet: distributive, has-complement.

**Verification**: Create a test domain without declarations. Query properties. Verify inference produces correct results.

### Phase 6: Implication Propagators

Register implication propagators for composite properties:
- `distributive ∧ has-pseudo-complement → heyting`
- `heyting ∧ has-complement → boolean`
- (Extensible — future tracks add more implications)

**Verification**: Declare type-sre-domain with atomic properties. Verify `heyting` is derived by implication propagator. Verify `boolean` is NOT derived (type lattice has no complement — `Int | String` has no complement). (D.3 F5): Verify implication propagators fire retroactively when connected to property cells already filled in Phase 5. Standard BSP behavior — new propagators on filled cells fire on next round.

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
| P1 | Properties as cells on network | Propagator-First | MEDIUM | **Resolved in D.2 revision**: Properties ARE cells on the elaboration network (`property-cell-ids` field on sre-domain). Pnet-cacheable, self-hosting visible. Declaration and inference write to same cells. `has-property?` is a pure network cell read. |
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

## D.3 External Critique Findings

| # | Severity | Finding | Resolution |
|---|----------|---------|------------|
| F1 | HIGH | Bool-⊤ semantics undefined — downstream poisoning | 4-valued lattice: ⊤ propagates as #f for capability gating. ⊤ preserved for diagnostics. |
| F2 | HIGH | Per-axiom inference lattice loses counterexample witness | `untested < confirmed(count) < refuted(witness)`. Witness preserved. |
| F3 | HIGH | P1 resolution contradicts main design (3 implementations described) | Stale D.2 text fixed. Cells-on-network is THE answer. |
| F4 | HIGH | Meet for metavariable-containing types unspecified | `?A ⊓ T = ⊥` (conservative). Property inference uses ground types. Pseudo-complement fires on resolved metas. |
| F5 | MEDIUM | Phase 5→6 ordering assumes retroactive propagator firing | Standard BSP behavior — noted explicitly in Phase 6 verification. |
| F6 | MEDIUM | Ring-action equality is context-dependent (⊤-producing vs ⊥-producing) | `equality-for-context`: `(identity, join) → equality-join`, `(identity, meet) → equality-meet`. |
| F7 | MEDIUM | Pseudo-complement computation hand-waved for dependent types | Phase 7 scoped to ground type sublattice. Full dependent-type pseudo-complement is research. |
| F8 | MEDIUM | Eager-synchronous inference blocks registration | 400ms one-time with pnet caching. Acceptable. Eager-async deferred as optimization. |
| F9 | MEDIUM | `flip-operation` else clause fail-open | Changed to error (fail-closed per pipeline exhaustiveness). |
| F10 | MEDIUM (scoped in) | No domain registry — manual wiring won't scale | Domain registry cell on network. `register-domain!` / `lookup-domain`. Phase 1.5. Auto-install implications. |
| F11 | LOW | Stale "lazy firing" in verification checklist | Fixed to "eager at registration." |

---

## §10 NTT Model

Expressing the Track 2G architecture in NTT speculative syntax. This exercises the NTT syntax and validates that every component is "on network."

### 10.1 Property Lattice

```prologos
;; The 4-valued property lattice (D.3 F1)
type PropertyValue := prop-unknown | prop-confirmed | prop-refuted | prop-contradicted
  :lattice :pure
  ;; ⊥ = prop-unknown, ⊤ = prop-contradicted
  ;; prop-confirmed ⊔ prop-refuted = prop-contradicted

impl Lattice PropertyValue
  join prop-unknown x        -> x
  join x prop-unknown        -> x
  join prop-confirmed prop-confirmed -> prop-confirmed
  join prop-refuted prop-refuted     -> prop-refuted
  join prop-confirmed prop-refuted   -> prop-contradicted
  join prop-refuted prop-confirmed   -> prop-contradicted
  join prop-contradicted _           -> prop-contradicted
  join _ prop-contradicted           -> prop-contradicted
  bot -> prop-unknown
```

### 10.2 Domain Registry

```prologos
;; Domain registry as a cell on the network
;; Value: set-accumulation lattice (domains only added, monotone)
type DomainRegistry := DomainRegistry {domains : Map Symbol SreDomain}
  :lattice :pure

impl Lattice DomainRegistry
  join [DomainRegistry a] [DomainRegistry b] -> DomainRegistry [map-union a b]
  bot -> DomainRegistry {}

;; The registry lives on the elaboration network
network elab-net : ElaborationInterface
  embed domain-registry : Cell DomainRegistry
```

### 10.3 Domain with Property Cells

```prologos
;; An SRE domain declares its operations + has property cells on-network
;; Each property is a Cell PropertyValue
interface DomainInterface {name : Symbol}
  :inputs  [join-fn  : Cell (Fn L L -> L)
            meet-fn  : Cell (Fn L L -> L)
            bot-val  : Cell L
            top-val  : Cell L]
  :outputs [;; Property cells — one per algebraic property
            commutative-join     : Cell PropertyValue
            associative-join     : Cell PropertyValue
            idempotent-join      : Cell PropertyValue
            has-meet             : Cell PropertyValue
            commutative-meet     : Cell PropertyValue
            associative-meet     : Cell PropertyValue
            distributive         : Cell PropertyValue
            has-complement       : Cell PropertyValue
            has-pseudo-complement : Cell PropertyValue
            residuated           : Cell PropertyValue
            ;; Derived (by implication propagators)
            heyting              : Cell PropertyValue
            boolean              : Cell PropertyValue]
```

### 10.4 Ring Action (Variance → Sub-Operation)

```prologos
;; The four ring elements (Krull-Schmidt irreducibles)
type RingElement := ring-identity | ring-monotone | ring-antitone | ring-trivial

;; Variance → ring element (one lookup)
spec variance-to-ring Variance -> RingElement
defn variance-to-ring
  | invariant    -> ring-identity
  | covariant    -> ring-monotone
  | contravariant -> ring-antitone
  | phantom      -> ring-trivial

;; Ring action: uniform across all operations (D.2 P2)
spec apply-ring-action RingElement Operation -> Operation
defn apply-ring-action
  | ring-identity  op -> equality-for-context op
  | ring-monotone  op -> op
  | ring-antitone  op -> flip-operation op
  | ring-trivial   _  -> phantom-op

;; Context-dependent equality (D.3 F6)
spec equality-for-context Operation -> Operation
defn equality-for-context
  | join-op -> equality-join     ;; mismatch → ⊤
  | meet-op -> equality-meet     ;; mismatch → ⊥
  | other   -> equality-op       ;; standard

;; Flip: antitone action (D.3 F9 — fail-closed)
spec flip-operation Operation -> Operation
defn flip-operation
  | join-op           -> meet-op
  | meet-op           -> join-op
  | subtype-op        -> subtype-reverse-op
  | subtype-reverse-op -> subtype-op
  ;; no catch-all — fail-closed
```

### 10.5 Property Inference as Pocket Universe

```prologos
;; Per-axiom evidence (D.3 F2)
type AxiomStatus := axiom-untested
                  | axiom-confirmed {count : Nat}
                  | axiom-refuted {witness : (L, L, L)}
  :lattice :pure

impl Lattice AxiomStatus
  join axiom-untested x -> x
  join x axiom-untested -> x
  join [axiom-confirmed n] [axiom-confirmed m] -> axiom-confirmed [max n m]
  join [axiom-confirmed _] [axiom-refuted w]   -> axiom-refuted w    ;; counterexample dominates
  join [axiom-refuted w] _                     -> axiom-refuted w
  bot -> axiom-untested

;; Inference state: Pocket Universe cell (one per domain)
type InferenceState := InferenceState
  {tested-axioms : Map Symbol AxiomStatus
   sample-count  : Nat}
  :lattice :pure

impl Lattice InferenceState
  join [InferenceState a n] [InferenceState b m] ->
    InferenceState [map-union-with axiom-join a b] [max n m]
  bot -> InferenceState {} 0

;; Inference propagator: reads domain operations, writes to inference state cell
propagator infer-properties
  :reads  [domain-ops : Cell DomainOps]
  :writes [inference  : Cell InferenceState]
  ;; Fire: sample values, test axioms, advance inference state
  ;; Monotone: evidence only accumulates
```

### 10.6 Implication Propagators

```prologos
;; Implication: reads source property cells, writes derived property cell
;; Auto-installed for each registered domain via domain registry watcher

propagator imply-heyting
  :reads  [dist : Cell PropertyValue, pseudo : Cell PropertyValue]
  :writes [heyting : Cell PropertyValue]
  (match [read dist] [read pseudo]
    | prop-confirmed prop-confirmed -> [write heyting prop-confirmed]
    | prop-contradicted _           -> [write heyting prop-refuted]    ;; ⊤ → #f for capability
    | _ prop-contradicted           -> [write heyting prop-refuted]
    | _ _                           -> void)    ;; wait for both inputs

propagator imply-boolean
  :reads  [hey : Cell PropertyValue, comp : Cell PropertyValue]
  :writes [bool : Cell PropertyValue]
  (match [read hey] [read comp]
    | prop-confirmed prop-confirmed -> [write bool prop-confirmed]
    | _ _                           -> void)

;; Auto-installer: reads domain registry, installs implications for new domains
propagator install-implications
  :reads  [registry : Cell DomainRegistry]
  :writes []   ;; side effect: installs propagators on domain property cells
  ;; foreach domain in registry that doesn't have implications wired:
  ;;   install imply-heyting, imply-boolean, etc. on its property cells
```

### 10.7 Capability Consumer (Heyting Error Reporting)

```prologos
;; Error reporter reads domain property, computes pseudo-complement if available
propagator enhanced-error-reporter
  :reads  [contradiction : Cell TypeLattice
           has-pseudo    : Cell PropertyValue
           meet-fn       : Cell (Fn TypeLattice TypeLattice -> TypeLattice)]
  :writes [error-msg : Cell ErrorDiagnostic]
  (match [read has-pseudo]
    | prop-confirmed ->
        ;; Compute pseudo-complement: maximal consistent refinement
        (let [pc (pseudo-complement [read contradiction] [read meet-fn])]
          [write error-msg (enhanced-diagnostic [read contradiction] pc)])
    | _ ->
        ;; Fallback: standard error message
        [write error-msg (standard-diagnostic [read contradiction])])
```

### 10.8 NTT Observations

**What the model reveals:**

1. **Everything IS on-network.** Property values, inference state, domain registry, ring action results, error diagnostics — all expressed as cell reads/writes. No off-network computation.

2. **The property inference propagator has a gap.** The `infer-properties` propagator "samples values and tests axioms" — but the NTT model shows it reads `Cell DomainOps` and writes `Cell InferenceState`. The sampling/testing is the fire function body. NTT types the inputs/outputs but the BODY is procedural. This is the M3 finding — the testing IS computation, the result IS information flow. The NTT model confirms this is acceptable: the propagator declaration types the boundary (what it reads, what it writes), not the internal computation.

3. **The `install-implications` propagator has a `foreach` pattern.** It reads the registry and installs propagators for each domain. This is the `:foreach` NTT extension proposed in PPN Track 2 NTT modeling (§17.3). Without `:foreach`, we can't express "for each element in a collection cell, install a sub-network." This remains an open NTT gap.

4. **The ring action is pure function, not propagator.** `apply-ring-action` and `flip-operation` are `spec`/`defn` declarations, not `propagator` declarations. They're pure functions called within propagator fire bodies. This is correct — they don't read/write cells, they transform values. The NTT model naturally distinguishes: `propagator` = cell-mediated, `spec`/`defn` = pure function.

5. **PropertyValue lattice is well-formed.** The NTT `impl Lattice PropertyValue` declaration shows all join cases explicitly. Commutative: symmetric cases are listed. Idempotent: `confirmed ⊔ confirmed = confirmed`. ⊥ is `prop-unknown`. ⊤ is `prop-contradicted`. The lattice is 4-valued with clear semantics.

6. **AxiomStatus lattice preserves witness.** The `axiom-refuted {witness}` carries the counterexample triple. The join `confirmed(n) ⊔ refuted(w) = refuted(w)` — counterexample dominates, witness preserved. This is well-formed as a lattice join (one-directional dominance, monotone).

**NTT gaps identified:**

- **`:foreach` extension** — needed for `install-implications` (iterate over registry contents). Proposed in PPN Track 2 NTT §17.3 but not yet formalized.
- **Lattice-parameterized interfaces** — `DomainInterface` is parameterized by `L` (the domain's value type) but NTT's `interface` form doesn't show how `L` flows through. The `functor` form (§5.3) may handle this, but the relationship between `interface` type parameters and `functor` instantiation needs clarification.
- **Property cell auto-creation** — when a domain is registered, its property cells must be created on the network. The NTT model doesn't have syntax for "creating cells as part of registration." This is the `Scatter` propagator kind from PTF — topology-creating, requires stratum boundary.

---

## §11 Propagator Design Mindspace Verification

### Property Cells
- [x] Information identified: algebraic axioms as boolean facts
- [x] Lattice defined: 4-valued (⊥, #t, #f, ⊤) per property, join = information accumulation (D.3 F1)
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
- [x] Eager firing at domain registration — has-property? is a pure read (D.2 P4 revision)

### Implication Propagators
- [x] Information identified: conjunction of source properties
- [x] Lattice defined: Bool⊥ (derived property)
- [x] Identity structural: one cell per derived property per domain
- [x] Emergence: derived properties fire automatically when sources resolve
- [x] No hierarchy: flat composition via propagators, not inheritance
