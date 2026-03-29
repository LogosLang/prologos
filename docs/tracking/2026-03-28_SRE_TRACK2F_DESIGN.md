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
| 0 | Pre-0 benchmarks | ✅ | `26d0cb2`. M1-M6 + A1-A4 + E1-E4. SRE <0.1% of elaboration. |
| 1 | Extend sre-relation | ✅ | `b0e1812`. properties, propagator-ctor, merge-key fields. |
| 2 | derive-sub-relation | ✅ | `581428e`. Table-driven sub-relation at 2 call sites. |
| 3 | Duality variance unification | ✅ | `1883020`. 7 session ctors: 'same-domain/'cross-domain. |
| 4 | Table-driven propagator dispatch | ✅ | `a33bd03`. propagator-ctor-table replaces 4-way case. |
| 5 | Topology handler unification | ✅ | `c4d38a0`. Property + domain dispatch, not name dispatch. |
| 6 | Merge registry alignment | ✅ | `2bae1a2`. 3 registries: case → hasheq. |
| 7 | Legacy field removal | ✅ | `673c19d`. sub-relation-fn DELETED. Struct: 5→4 fields. Tests updated. |
| 8 | Full suite verification | ✅ | 383/383 GREEN. 7529 tests. Zero behavioral change. |

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

### D.3 External Critique Findings (incorporated)

| # | Finding | Severity | Resolution |
|---|---------|----------|------------|
| E1 | Variance-map stores symbols, consumers need structs | HIGH | **Define relations first, then construct maps.** Racket module-level `define` is sequential — maps reference already-defined structs. No circular dependency. |
| E2 | Phase 3 text uses `'d`/`'t` despite D.2 renaming | HIGH | **Fixed.** Phase 3 text updated to `'same-domain`/`'cross-domain`. |
| E3 | `'same-domain`/`'cross-domain` generality overstated | MEDIUM | **Scoped.** Binary distinction is correct for decomposition (parent→child is inherently binary). Note added: extension needed for hypothetical multi-domain relations (not decomposition). |
| E4 | 3-phase `sub-relation-fn` migration can simplify | MEDIUM | **Accepted.** Phase 2 changes the call site, not the closures. Closures become dead code, removed in Phase 7. |
| E5 | Phase 3 failure modes under-specified | LOW-MED | **Accepted.** 4 specific failure mode tests added. Registration-time validation for variance/lattice count consistency. |

### D.2 Self-Critique Findings (incorporated)

| # | Finding | Resolution |
|---|---------|------------|
| 1 | Separate kind struct is unnecessary indirection | **Extend `sre-relation` directly** with new fields. The relation IS the kind. No lookup needed. |
| 2 | Property set is fine for Track 2F scope | Keep `seteq`. Document valid relation-level properties. |
| 3 | Variance map is clearer than derivation | Keep table. Add comments showing mathematical derivation. |
| 4 | `'d`/`'t` are duality-specific names | **Use `'same-domain`/`'cross-domain`** — works for any antitone kind. |
| 5 | Topology handler should check domain, not kind | **Derive from domain's `dual-pairs` field**, not `'antitone` property. |
| 6 | `requires-binder-opening?` → property | **Add to property set** as `'requires-binder-opening`. Remove struct field. |
| 7 | `(not variances)` fallback needs handling | **`#f` → `'equality`** in `derive-sub-relation`. Explicit default. |
| G2 | Duality sentinel check is fragile | **Phase 3 fixes this** — `'same-domain`/`'cross-domain` replaces sentinel. |

### 3.1 Extended `sre-relation` (D.2: no separate kind struct)

The `sre-relation` struct gains new fields directly. No separate `sre-algebraic-kind` struct — the relation IS the kind. This eliminates the lookup indirection and the synchronization concern.

```racket
(struct sre-relation
  (name                    ; symbol: 'equality, 'subtype, 'duality, 'phantom, ...
   sub-relation-fn         ; LEGACY — replaced by derive-sub-relation in Phase 2
   ;; New fields (Track 2F):
   properties              ; (seteq symbol): 'order-preserving, 'antitone, 'involutive,
                           ;   'idempotent, 'identity, 'requires-binder-opening, ...
                           ;   ONLY relation-level properties (not domain-level)
   variance-map            ; (hash variance → relation-ref): endomorphism ring decomposition
   propagator-ctor         ; (domain cell-a cell-b relation → (net → net)): fire function factory
   merge-key)              ; symbol or #f: key for domain merge-registry lookup
  #:transparent)
```

The 5 built-in relations are defined FIRST with `#f` variance-maps, then maps are constructed post-definition (D.3 E1 resolution — avoids circular reference):

```racket
;; Step 1: Define all relations (variance-map = #f initially)
(define sre-equality  (sre-relation 'equality #f (seteq 'identity 'requires-binder-opening) #f sre-make-equality-propagator 'equality))
(define sre-subtype   (sre-relation 'subtype  #f (seteq 'order-preserving) #f sre-make-subtype-propagator 'subtype))
(define sre-subtype-reverse (sre-relation 'subtype-reverse #f (seteq 'order-preserving) #f sre-make-subtype-propagator 'subtype))
(define sre-duality   (sre-relation 'duality  #f (seteq 'antitone 'involutive) #f sre-make-duality-propagator 'duality))
(define sre-phantom   (sre-relation 'phantom  #f (seteq 'trivial) #f (lambda (d a b r) (lambda (net) net)) 'phantom))

;; Step 2: Construct variance-maps referencing the now-defined structs
(define equality-variance-map
  (hasheq '+ sre-equality '- sre-equality '= sre-equality 'ø sre-phantom
          'same-domain sre-equality 'cross-domain sre-equality #f sre-equality))
;; ... (similarly for subtype, subtype-reverse, duality, phantom)

;; Step 3: Set the maps (requires mutable field or wrapper — design choice TBD)
```

**D.3 E1 note**: Racket module-level `define` is sequential. By step 2, all 5 relation values exist. The maps can reference them directly — no symbol lookup registry needed. The remaining question is how step 3 "installs" the maps. Options: (a) make `variance-map` mutable (`#:mutable`), (b) use a separate hash from relation→map, (c) reconstruct the struct with `struct-copy`. Option (b) is cleanest — `derive-sub-relation` reads from a module-level hash, not from the struct field. This means the variance-map field on the struct can be removed entirely, with the module-level hash as the single source of truth.

### 3.2 Kind-Variance Table

The table is the data form of the endomorphism ring decomposition:

```
| Variance      | equality | subtype | subtype-reverse | duality  | phantom |
|---------------|----------|---------|-----------------|----------|---------|
| + (covariant) | equality | subtype | subtype-reverse | —        | phantom |
| - (contra)    | equality | sub-rev | subtype         | —        | phantom |
| = (invariant) | equality | equality| equality        | equality | phantom |
| ø (phantom)   | phantom  | phantom | phantom         | phantom  | phantom |
| same-domain   | —        | —       | —               | duality  | —       |
| cross-domain  | —        | —       | —               | equality | —       |
| #f (unspec)   | equality | equality| equality        | equality | phantom |
```

`'same-domain`/`'cross-domain` replace the duality-specific `'d`/`'t` from D.1. They're general — any antitone kind across domain boundaries uses the same variance values. `#f` (unspecified variances) defaults to equality — the safety fallback from the current code (line 190-191 of sre-core.rkt).

**Mathematical derivation this table encodes**:
- Identity endomorphism (equality): preserves everything → always identity sub-relation
- Monotone endomorphism (subtype): covariant = same direction, contravariant = reversed
- Antitone endomorphism (duality): same-domain = continues in antitone, cross-domain = drops to identity
- Zero endomorphism (phantom): maps everything to zero → no constraint

`derive-sub-relation` replaces all `sub-relation-fn` closures:

```racket
(define (derive-sub-relation parent-kind variance)
  (hash-ref (sre-algebraic-kind-variance-map parent-kind) variance
            (lambda () (error 'derive-sub-relation
                              "no sub-relation for ~a under ~a"
                              variance (sre-algebraic-kind-name parent-kind)))))
```

### 3.3 Duality Variance Unification (D.2: `'same-domain`/`'cross-domain`)

**Before**: Session constructors provide `component-lattices`:
```racket
(register-ctor! 'sess-send
  #:component-lattices (list type-lattice-spec session-lattice-spec)
  ...)
```

Duality's `sub-relation-fn` reads these lattices and uses a fragile sentinel check:
```racket
(define cross-domain? (eq? comp-lat 'type))  ;; sentinel — breaks if type-lattice-spec changes
```

**After**: Session constructors provide `component-variances` with general values:
```racket
(register-ctor! 'sess-send
  #:component-variances '(cross-domain same-domain)  ;; payload crosses to type domain, continuation stays
  #:component-lattices (list type-lattice-spec session-lattice-spec)  ;; kept for merge
  ...)
```

`'same-domain` and `'cross-domain` are general — any future antitone kind can use them, not just duality. The names are self-documenting: no need to remember that `'d` means "dual-continuation."

Duality's variance-map:
```racket
(hash 'same-domain 'duality     ;; continuation stays in session domain → duality
      'cross-domain 'equality   ;; payload crosses to type domain → equality
      '= 'equality              ;; invariant → equality
      'ø 'phantom               ;; phantom → phantom
      #f 'equality)             ;; unspecified → equality (safety default)
```

**Note**: `component-lattices` is NOT retired — still needed for merge function selection. Only its role in sub-relation derivation is replaced by variances.

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

### 3.5 Topology Handler Unification (D.2: check domain, not kind)

**Before**: Two branches — `(eq? rel-name 'duality)` triggers dual-pair-specific decomposition.

**After**: The handler checks the DOMAIN's `dual-pairs` field, not the kind's properties:

```racket
(if (and (sre-domain-dual-pairs domain)
         (set-member? (sre-relation-properties relation) 'antitone))
    ;; Domain has dual-pairs AND relation is antitone → dual-pair decomposition
    (sre-decompose-antitone ...)
    ;; Standard generic decomposition
    (sre-decompose-generic ...))
```

**D.2 rationale**: An antitone kind WITHOUT dual-pairs (e.g., a contravariant functor on a non-session domain) should NOT be dispatched to the dual-pair path. The dual-pair path requires `(sre-domain-dual-pairs domain)` to derive constructor swaps. Checking the domain is correct-by-construction — if the domain has no dual-pairs, the handler can't construct dual tags and would crash. The domain check prevents this structurally.

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

### 3.8 Nomenclature (D.2: relation IS the kind)

The relation names stay as-is (`'equality`, `'subtype`, `'duality`, `'phantom`). Since D.2 eliminated the separate kind struct, the relation IS the kind — no separate nomenclature needed. The algebraic properties are accessed directly:

```racket
(sre-relation-properties rel)      ;; → (seteq 'antitone 'involutive)
(sre-relation-variance-map rel)    ;; → (hash 'same-domain 'duality ...)
(sre-relation-propagator-ctor rel) ;; → sre-make-duality-propagator
```

The `requires-binder-opening?` field is retired. Its information moves to the property set as `'requires-binder-opening`.

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

### Phase 1: Extend `sre-relation` struct (D.2: no separate kind)

**Deliverable**: `sre-relation` gains 4 new fields: `properties`, `variance-map`, `propagator-ctor`, `merge-key`. The `requires-binder-opening?` field is replaced by `'requires-binder-opening` in the property set. All 5 built-in relations updated with the new fields.

**Scope**: Modify `sre-relation` struct in `sre-core.rkt`. Update all 5 `(define sre-*)` relation definitions. Run `raco make driver.rkt` to catch all struct-copy and pattern-match sites (pipeline exhaustiveness checklist: new struct field). The `sub-relation-fn` field stays for backward compatibility — Phase 2 replaces its callers.

**Tests**: All 177 SRE tests must pass (struct change is additive). Add tests for property access and variance-map access on each relation.

### Phase 2: Kind-Variance Table (`derive-sub-relation`) (D.3: simplified)

**Deliverable**: `derive-sub-relation` function. The ONE call site that invokes `sub-relation-fn` switches to `derive-sub-relation` instead. The closures become dead code (removed in Phase 7).

**Scope (D.3 E4)**: Change the single call site in `sre-decompose-generic` from `((sre-relation-sub-relation-fn rel) rel desc idx domain-name)` to `(derive-sub-relation rel (list-ref (ctor-desc-component-variances desc) idx))`. The closures are NOT rewritten — they just stop being called.

**`derive-sub-relation`**: Looks up the relation's variance-map (from the module-level hash, per D.3 E1), returns the `sre-relation` struct value for the given variance. Falls back to `sre-equality` for `#f` (unspecified variance).

**Risk**: Duality currently reads `component-lattices`, not `component-variances`. Phase 2 changes equality/subtype only. Duality uses the `sub-relation-fn` closure until Phase 3 adds `'same-domain`/`'cross-domain` variances.

**Compatibility**: The call site checks: if `component-variances` exists, use `derive-sub-relation`. Otherwise, fall back to `sub-relation-fn` (for duality in Phase 2, before Phase 3 adds variances).

**Tests**: All 177 SRE tests must pass. Add tests for `derive-sub-relation` directly.

### Phase 3: Duality Variance Unification (D.2 + D.3)

**Deliverable**: Session constructors gain `component-variances` (`'same-domain`, `'cross-domain`). `derive-sub-relation` handles duality like all other kinds.

**Scope**:
- Update 7 session constructor registrations in `ctor-registry.rkt` to add `#:component-variances`
- Phase 2's call site already uses `derive-sub-relation` — duality just needs the variance-map populated (done in Phase 1)
- `'same-domain` maps to `sre-duality`, `'cross-domain` maps to `sre-equality`

**D.3 scope note**: `'same-domain`/`'cross-domain` is general for decomposition (parent→child is inherently binary: same domain as parent, or different). Extension needed only for hypothetical multi-domain relations, which are not decomposition.

**Risk**: Highest-risk phase. Mitigated by:
- 62+ duality tests run individually before suite
- Registration-time validation: `component-variances` count must match arity
- 4 specific failure mode tests (D.3 E5):
  1. Variance/lattice disagreement detection (validate at registration)
  2. `#f` variance on session constructor → explicit error, not silent equality fallback
  3. Mu constructor: `'same-domain` for recursive body (correct: mu's body IS session domain)
  4. Merge function reads `component-lattices` independently of variance (both paths exercised)

**Tests**: All 62+ duality tests. Add 4 failure mode tests. Add validation check in `register-ctor!`.

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

### Phase 7: Legacy field removal + documentation

**Deliverable**: Remove `sub-relation-fn` and `requires-binder-opening?` fields from `sre-relation` (all callers migrated in Phases 2-3). Update documentation and comments to reference algebraic properties.

**Scope**: Struct field removal triggers pipeline exhaustiveness checklist (grep for struct-copy and pattern-match on `sre-relation`). All callers already migrated. Documentation update.

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
