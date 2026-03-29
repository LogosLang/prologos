# SRE Track 2F: Algebraic Foundation — Stage 3 Design (D.1)

**Date**: 2026-03-28
**Series**: SRE (Structural Reasoning Engine)
**Prerequisite**: PTF Track 1 findings (module theory, residuation, algebraic embeddings)
**Audit**: `docs/tracking/2026-03-28_SRE_TRACK2F_AUDIT.md`
**Research**: `docs/research/2026-03-28_MODULE_THEORY_LATTICES.md`, `docs/research/2026-03-28_ALGEBRAIC_EMBEDDINGS_LATTICES.md`

---

## Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| 0 | Pre-0 benchmarks | ⬜ | Baseline elaboration timing |
| 1 | Algebraic-kind registry | ⬜ | `sre-algebraic-kind` struct + registration |
| 2 | Kind-variance table | ⬜ | `derive-sub-relation` replaces closures |
| 3 | Duality variance unification | ⬜ | `'d`/`'t` variances, retire `component-lattices` dispatch |
| 4 | Table-driven propagator dispatch | ⬜ | Replace 4-way `case` at line 522 |
| 5 | Topology handler unification | ⬜ | Kind-property dispatch, not name dispatch |
| 6 | Merge registry alignment | ⬜ | Explore table-driven merge selection |
| 7 | Nomenclature alignment | ⬜ | Algebraic annotations on existing names |
| 8 | Cleanup + A/B benchmarks | ⬜ | Performance-neutral verification |

**Phase completion protocol**: After each phase: commit → update tracker → update dailies → run targeted tests → proceed.

---

## §1 Objectives

Replace the ad-hoc relation dispatch throughout SRE with a data-driven algebraic foundation grounded in module theory. Each relation kind is characterized by its algebraic properties (order-preserving, involutive, idempotent), and dispatch reads these properties from a registry rather than pattern-matching on names.

**End deliverables**:
1. Kind-variance table as the single source of truth for sub-relation derivation
2. Duality using the same variance mechanism as equality/subtyping
3. All relation dispatch table-driven (no `eq?` on relation names in dispatch paths)
4. Extension point for future algebraic kinds (Heyting, residuated, quantale)
5. 383/383 GREEN, 177 SRE tests pass, zero behavioral change
6. Performance-neutral (A/B within noise)

---

## §2 Current State (from Audit)

### What works
- 5 relations: equality, subtype, subtype-reverse, duality, phantom
- Domain-parameterized decomposition via `ctor-desc` registry
- 177 SRE tests across 3 test files
- Relation-independent reconstructors

### What's ad-hoc
- **12 `eq?` checks on relation names** across sre-core.rkt (Audit A §1)
- **3 hand-written `sub-relation-fn` closures** encoding the same truth differently (lines 178, 185, 235)
- **Two parallel mechanisms** for component dispatch: `component-variances` (13 type constructors) and `component-lattices` (7 session constructors) — never overlap (Audit A §2)
- **4-way `case` dispatch** for propagator constructor selection (line 522)
- **2-way fork** in topology handler (duality vs everything else, line 871)
- **3 duplicate merge registries** with identical structure (Audit A §3)

### What's missing
- The endomorphism ring decomposition table doesn't exist as data
- No algebraic property annotations (order-preserving, involutive, etc.)
- No extension point for new kinds
- 11 structural operations across the architecture bypass SRE entirely (Audit B §2)

---

## §3 Design

### 3.1 Algebraic-Kind Registry

A new struct captures the algebraic properties of each relation kind:

```racket
(struct sre-algebraic-kind
  (name              ; symbol: 'equality, 'subtype, 'duality, 'phantom, ...
   properties        ; (seteq symbol): 'order-preserving, 'involutive, 'idempotent,
                     ;   'antitone, 'identity, 'requires-binder-opening, ...
   variance-map      ; (hash variance → kind-name): how variances derive sub-kinds
   propagator-ctor   ; (domain cell-a cell-b relation → (net → net)): fire function factory
   merge-key)        ; symbol or #f: key for domain merge-registry lookup
  #:transparent)
```

Registration is declarative:

```racket
(register-algebraic-kind!
 (sre-algebraic-kind
  'subtype
  (seteq 'order-preserving)
  (hash '+ 'subtype  '- 'subtype-reverse  '= 'equality  'ø 'phantom)
  sre-make-subtype-propagator
  'subtype))
```

The `sre-relation` struct gains an `algebraic-kind` field (or the kind IS the relation — to be determined in D.2).

### 3.2 Kind-Variance Table

The table is the data form of the endomorphism ring decomposition:

```
| Variance | equality | subtype | subtype-reverse | duality | phantom |
|----------|----------|---------|-----------------|---------|---------|
| +  (co)  | equality | subtype | subtype-reverse | duality*| phantom |
| -  (contra)| equality | subtype-reverse | subtype | duality*| phantom |
| =  (inv) | equality | equality | equality | equality | phantom |
| ø  (phantom)| phantom | phantom | phantom | phantom | phantom |
| d  (dual-cont)| — | — | — | duality | — |
| t  (type-comp)| — | — | — | equality | — |
```

*`duality` for `+`/`-` is the session-domain interpretation (continuation components). Type-domain components under duality use `equality` (via `'t` variance). The `'d'`/`'t'` variances unify duality's current `component-lattices` dispatch.*

`derive-sub-relation` replaces all `sub-relation-fn` closures:

```racket
(define (derive-sub-relation parent-kind variance)
  (hash-ref (sre-algebraic-kind-variance-map parent-kind) variance
            (lambda () (error 'derive-sub-relation
                              "no sub-relation for ~a under ~a"
                              variance (sre-algebraic-kind-name parent-kind)))))
```

### 3.3 Duality Variance Unification

**Before**: Session constructors provide `component-lattices`:
```racket
(register-ctor! 'sess-send
  #:component-lattices (list type-lattice-spec session-lattice-spec)
  ...)
```

Duality's `sub-relation-fn` reads these lattices and maps:
- `type-lattice-spec` → `sre-equality`
- `session-lattice-spec` → `sre-duality`

**After**: Session constructors provide `component-variances` with new values:
```racket
(register-ctor! 'sess-send
  #:component-variances '(t d)   ;; type-component, dual-continuation
  #:component-lattices (list type-lattice-spec session-lattice-spec)  ;; kept for merge
  ...)
```

The `'t` and `'d` variances are handled by the kind-variance table. No special `component-lattices` dispatch in the sub-relation function.

**Note**: `component-lattices` is NOT retired entirely — it's still needed for merge function selection (which lattice-spec to use per component). Only its role in sub-relation derivation is replaced by variances.

### 3.4 Table-Driven Propagator Dispatch

**Before** (line 522):
```racket
(case rel-name
  [(equality) (sre-make-equality-propagator domain cell-a cell-b relation)]
  [(subtype subtype-reverse) (sre-make-subtype-propagator ...)]
  [(duality) (sre-make-duality-propagator ...)]
  [(phantom) (lambda (net) net)]
  [else (error ...)])
```

**After**:
```racket
(define kind (sre-relation-algebraic-kind relation))
((sre-algebraic-kind-propagator-ctor kind) domain cell-a cell-b relation)
```

One line. Adding a new kind means registering its propagator constructor, not editing a `case` statement.

### 3.5 Topology Handler Unification

**Before**: Two branches — `(eq? rel-name 'duality)` triggers dual-pair-specific decomposition.

**After**: The handler reads the algebraic kind's properties:

```racket
(if (set-member? (sre-algebraic-kind-properties kind) 'antitone)
    ;; Antitone kind: needs both cell values, dual-tag derivation
    (sre-decompose-antitone ...)
    ;; Non-antitone: standard generic decomposition
    (sre-decompose-generic ...))
```

The `'antitone` property is the structural reason duality needs different handling — not the name `'duality`. Future antitone kinds (if any) automatically get the right path.

### 3.6 Merge Registry Alignment

Currently each domain hand-writes a `(relation-name → merge-fn)` closure. The algebraic-kind registry could provide a default merge-key per kind, and the domain registers merge functions by key:

```racket
(define type-merge-table
  (hash 'equality type-lattice-merge
        'subtype  subtype-lattice-merge))

(define (type-merge-registry rel-name)
  (hash-ref type-merge-table rel-name
            (lambda () (error ...))))
```

This is already close to what we have — the closures ARE essentially hash lookups. Making it explicit (hash instead of `case`) is a small clarity win. The bigger win: the kind's `merge-key` field lets the domain register ONE merge per algebraic category rather than per relation name:

```racket
;; If subtype and subtype-reverse share the same merge:
(define kind-merge (sre-algebraic-kind-merge-key kind))
(hash-ref type-merge-table kind-merge ...)
```

### 3.7 Extension Points for Future Kinds

The registry is open — any module can call `register-algebraic-kind!`:

```racket
;; Future: Heyting-based error reporting
(register-algebraic-kind!
 (sre-algebraic-kind
  'heyting-error
  (seteq 'order-preserving 'has-pseudo-complement)
  (hash '+ 'heyting-error  '- 'heyting-error-reverse  '= 'equality)
  sre-make-heyting-propagator
  'heyting))
```

### 3.8 Separation of Domain Algebraic Class from Relation Properties

**Critical design principle** (from Algebraic Embeddings research): Properties belong at TWO levels, not one.

**Domain level** — the algebraic structure of the carrier lattice:
- Is the type lattice Heyting? (→ has pseudo-complements → precise error reporting)
- Is it residuated? (→ automatic backward propagator derivation)
- Is it Boolean? (→ SAT/CDCL optimization for ATMS)
- Is it a quantale? (→ resource-aware constraint solving)

**Relation level** — the algebraic properties of the endomorphism:
- Order-preserving (monotone)? → standard forward propagation
- Order-reversing (antitone)? → dual-tag swap, asymmetric decomposition
- Involutive? → `f(f(x)) = x`, self-inverse
- Idempotent? → `f(f(x)) = f(x)`, rewriting/normalization

The current design puts everything on the relation (`sre-algebraic-kind`). The future design (SRE Track 2G) adds domain-level declarations:

```racket
(sre-domain 'type
  #:algebraic-class 'heyting-algebra  ;; domain-level
  #:merge-registry type-merge-registry
  ...)
```

The algebraic class sits in a hierarchy:
```
Boolean ⊂ Heyting ⊂ Distributive ⊂ Modular ⊂ Lattice
Quantale ⊂ Residuated ⊂ Lattice
```

When a domain declares `'heyting-algebra`, the infrastructure derives:
- `has-pseudo-complement? → #t` (precise error reporting available)
- `distributive? → #t` (efficient join/meet algorithms apply)
- `residuated? → depends` (Heyting IS residuated for ∧/→; check additional axioms for general residuation)

**Track 2F scope**: The `sre-algebraic-kind` struct carries RELATION-level properties. The variance-map encodes how the relation's algebraic type interacts with component variance. This is correct and complete for the endomorphism ring.

**Track 2G scope** (out of scope for 2F, but 2F must not preclude it): The `sre-domain` struct gains `algebraic-class`. Capabilities are DERIVED from class, not listed. The relation's propagator constructor can query the domain's algebraic class to select strategy (e.g., "if domain is residuated, derive backward propagator automatically").

**Track 2F design rule**: Do NOT put domain-level properties on the relation. The `sre-algebraic-kind` property set contains ONLY endomorphism properties (`'order-preserving`, `'antitone`, `'involutive`, `'idempotent`). Domain properties (`'has-pseudo-complement`, `'distributive`) will go on the domain in Track 2G.

**UCS connection**: The domain-polymorphic `#=` operator selects solving strategy based on domain algebraic class + relation endomorphism type. Track 2F provides the relation dispatch table. Track 2G provides the domain class. UCS combines both to select the right constraint solver.

### 3.8 Nomenclature

The relation names stay as-is (`'equality`, `'subtype`, `'duality`, `'phantom`). The algebraic kind is a DERIVED property, not a replacement:

```racket
(define (sre-relation-algebraic-kind rel)
  (lookup-algebraic-kind (sre-relation-name rel)))
```

This preserves readability in error messages, test assertions, and decomposition pair-keys while gaining algebraic dispatch.

---

## §4 Phase Details

### Phase 0: Pre-0 Benchmarks ✅

**Deliverable**: Baseline timing. Benchmark file: `benchmarks/micro/bench-sre-track2f.rkt`.

#### Micro-benchmarks (M1-M6)

| Measurement | Current | Proposed | Ratio | Impact |
|-------------|---------|----------|-------|--------|
| M1: sub-relation (closure vs hash-ref) | 0.009 μs | 0.032 μs | 3.5× | 0.023ms/1000 decomps — invisible |
| M2: propagator dispatch (case vs field) | 0.002 μs | 0.002 μs (field) | 1.0× | Zero cost via struct field |
| M3: property check (eq? vs set-member?) | 0.002 μs | 0.053 μs | 26× | Use boolean field for hot path |
| M4: merge registry (case vs hash-ref) | 0.002 μs | 0.025 μs | 12× | Cold path — invisible |
| M5: full decomposition | 1.9-3.3 μs | — | baseline | Dispatch is <5% of total |
| M6: session processing | ~55 ms | — | baseline | SRE dispatch invisible |

**Design implication**: Use struct field access for hot paths (propagator-ctor, antitone? boolean). Hash-ref acceptable for cold paths. `set-member?` for properties is fine for non-hot paths but add `antitone?` boolean field to `sre-algebraic-kind` for the topology handler.

#### Adversarial benchmarks (A1-A4)

| Test | Result | Notes |
|------|--------|-------|
| A1: PVec depth 1-4 | 2.0→2.4→26.9→3.8 μs | Depth-3 spike = GC. Otherwise linear. |
| A2: Pi wide (3+6 comp) | 0.5→0.4 μs | Width doesn't stress dispatch |
| A3: Session 2-4 deep | 54→58 ms | Dominated by process-string |
| A4: Mixed relations | 57 ms | No cross-relation interference |

#### E2E benchmarks (E1-E4)

| Test | Baseline | Notes |
|------|----------|-------|
| E1: 14 comparative programs | ±3% noise | bench-ab 5 runs, saved to JSON |
| E2: 72 library files | 33.3s total | Top: generic-ops 3.7s, list 3.5s |
| E3: Session e2e files | 89-91 ms each | Stable |
| E4: Full suite | ~136s (383 files) | From PM Track 10C baseline |

**Conclusion**: SRE dispatch overhead is <5% of decomposition cost and <0.1% of elaboration cost. The refactoring is performance-free to use any dispatch mechanism. All baselines recorded for post-implementation comparison.

### Phase 1: Algebraic-Kind Registry

**Deliverable**: `sre-algebraic-kind` struct, `register-algebraic-kind!`, `lookup-algebraic-kind`. Five built-in kinds registered.

**Scope**: New file `sre-algebraic-kinds.rkt` (or section in `sre-core.rkt`). No behavior change — the registry exists but nothing reads it yet.

**Tests**: Unit tests for registration and lookup. Verify all 5 kinds registered at module load time.

### Phase 2: Kind-Variance Table (`derive-sub-relation`)

**Deliverable**: `derive-sub-relation` function. The 3 `sub-relation-fn` closures in `sre-relation` definitions call `derive-sub-relation` instead of hand-coding the variance map.

**Scope**: Replace closure bodies in lines 178-262 of sre-core.rkt. The `sre-relation` struct's `sub-relation-fn` field becomes `(lambda (rel desc idx domain-name) (derive-sub-relation kind variance))` where `kind` is looked up from the relation and `variance` from `(list-ref (ctor-desc-component-variances desc) idx)`.

**Risk**: Duality currently reads `component-lattices`, not `component-variances`. Phase 2 changes equality/subtype only. Duality unchanged until Phase 3.

**Tests**: All 177 SRE tests must pass. Add tests for `derive-sub-relation` directly.

### Phase 3: Duality Variance Unification

**Deliverable**: Session constructors gain `component-variances` (`'d`, `'t`). Duality's `sub-relation-fn` uses `derive-sub-relation` like all other kinds.

**Scope**:
- Update 7 session constructor registrations in `ctor-registry.rkt`
- Update duality's sub-relation-fn to use variances
- `'d` maps to `'duality`, `'t` maps to `'equality` in duality's variance-map

**Risk**: This is the highest-risk phase. Duality tests are comprehensive (62+ cases) so regressions will be caught. The `component-lattices` field stays for merge function selection — only its role in sub-relation derivation is replaced.

**Tests**: All 62+ duality tests must pass. Add tests for `'d`/`'t` variance derivation.

### Phase 4: Table-Driven Propagator Dispatch

**Deliverable**: The 4-way `case` at line 522 becomes a single-line kind lookup.

**Scope**: ~5 lines changed. The `propagator-ctor` field in `sre-algebraic-kind` points to the existing propagator constructors (`sre-make-equality-propagator`, etc.). No propagator logic changes.

**Tests**: All 177 SRE tests. This is a dispatch change, not a logic change.

### Phase 5: Topology Handler Unification

**Deliverable**: Topology handler dispatches on `'antitone` property, not `(eq? 'duality)`.

**Scope**: ~10 lines in the topology handler. The duality-specific path stays but is reached via property check, not name check.

**Tests**: PAR Track 1's BSP tests cover the topology handler path.

### Phase 6: Merge Registry Alignment

**Deliverable**: Merge registries use explicit hash tables. Kind's `merge-key` enables category-level merge registration.

**Scope**: 3 merge registry functions (type, session, subtype-query) converted from `case` to `hash-ref`. Small clarity win.

**Tests**: All tests. Merge behavior unchanged.

### Phase 7: Nomenclature Alignment

**Deliverable**: Each `sre-relation` gains an `algebraic-kind` accessor. Documentation updated to reference algebraic properties alongside domain names.

**Scope**: Add derived accessor. Update comments. No behavioral change.

### Phase 8: Cleanup + A/B Benchmarks

**Deliverable**: Performance comparison (before vs after). Remove any temporary scaffolding.

**Scope**: Run `bench-ab.rkt --runs 5` on comparative suite. Compare against Phase 0 baseline. Expect within noise (±3%).

**Tests**: 383/383 GREEN. Full suite.

---

## §5 Principles Alignment

| Principle | How this design serves it |
|-----------|---------------------------|
| Data Orientation | The kind-variance table IS data. Dispatch reads properties, not code. |
| Correct-by-Construction | Adding a new kind is registration, not editing dispatch sites. Missing registration → immediate error. |
| Completeness | The table encodes the full endomorphism ring decomposition. No partial encoding. |
| Decomplection | Algebraic properties separated from domain names. Variance separated from lattice selection. |
| First-Class by Default | Algebraic kinds are first-class values with properties, not opaque symbols. |
| Propagator-Only | All dispatch is value-driven (read properties from kind struct). No imperative case analysis on names. |
| Progressive Disclosure | Users see relation names. Developers see algebraic properties. Theorists see the endomorphism ring. |
| Ergonomics | `register-algebraic-kind!` is the only API for extension. |
| Most General Interface | The property set is open — any algebraic property can be added without changing infrastructure. |

---

## §6 WS Impact

None. This track modifies internal SRE dispatch only. No user-facing syntax changes.

---

## §7 Risks and Mitigations

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Duality regression (Phase 3) | Medium | 62+ duality tests. Run individually before suite. |
| Performance regression from indirection | Low | Kind lookup is hash-ref (O(1)). Pre/post benchmark. |
| `component-lattices` still needed for merge | Certain | Design explicitly keeps it for merge; only sub-relation dispatch changes. |
| Future kinds need more than variance→sub-relation | Medium | Property set is open. Future kinds can add properties without changing existing code. |
