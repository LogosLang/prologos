# SRE Track 0: Form Registry — Domain-Parameterized Structural Decomposition

**Stage**: 3 (Design)
**Date**: 2026-03-22
**Series**: SRE (Structural Reasoning Engine)
**Status**: Ready for implementation
**Depends on**: PM Track 8D ✅, PUnify Parts 1-2 ✅

## Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| 0 | Acceptance file baseline | ⬜ | |
| 1 | Domain spec abstraction | ⬜ | |
| 2 | Extract sre-core.rkt | ⬜ | |
| 3 | PUnify delegates to SRE | ⬜ | |
| 4 | Second domain validation | ⬜ | |
| 5 | Relation parameter stub | ⬜ | |
| 6 | Verification + benchmarks | ⬜ | |

## 1. Summary

Extract PUnify's structural decomposition primitives into a
domain-parameterized SRE module. The SRE becomes the universal
substrate for structural reasoning — any domain with "things that
have structure" registers forms and gets decomposition/composition
propagators for free.

**Key metric**: After Track 0, PUnify delegates to the SRE with
`domain = 'type`, and the SRE can accept a second domain (term-value
from NF-Narrowing) with zero changes to the core.

## 2. Audit Findings (from PUnify Structural Primitives Audit)

### What generalizes well (already domain-neutral)
- Cell infrastructure (propagator.rkt): `net-new-cell`, `net-cell-read`, `net-cell-write`
- Merge function pattern: pure `(old new → merged)`
- CHAMP-backed registries: immutable, speculative-safe
- Generic reconstructor: works for any binder-depth=0 descriptor
- `ctor-desc` struct: already has domain, recognizer, extractor, reconstructor, component-lattices

### What's hardcoded to type domain (5 functions)
1. `identify-sub-cell` — uses `type-lattice-merge`, `type-lattice-contradicts?`
2. `make-structural-unify-propagator` — uses `type-lattice-merge`, `type-top?`, `type-bot?`
3. `type-constructor-tag` — hardcoded `domain = 'type`
4. `maybe-decompose` — hardcoded case arms for Pi, Sigma, lam
5. Specialized decomposers (Pi/Sigma/lam with binder handling)

### What's hardcoded to equality relation
- All structural decomposition assumes symmetric merge (join)
- No parameterization for duality, subtyping, coercion

## 3. Design

### 3.1 The Domain Spec

A domain spec bundles the lattice operations needed for structural
reasoning in a particular domain:

```racket
(struct sre-domain
  (name           ; symbol: 'type, 'term, 'session, ...
   lattice-merge  ; (old new → merged) — the lattice join
   contradicts?   ; (val → bool) — is this value top/contradiction?
   bot?           ; (val → bool) — is this value bottom?
   bot-value      ; the bottom element
   meta-lookup    ; (expr → cell-id | #f) — map meta refs to cells
   )
  #:transparent)
```

This replaces the hardcoded `type-lattice-merge`, `type-lattice-contradicts?`,
`type-bot?` scattered through the 5 functions. Each domain creates its
own `sre-domain` instance.

**Principles alignment**:
- **Data Orientation**: Domain spec is a data value, not a set of callbacks
- **First-Class by Default**: Domains are reified values, composable
- **Decomplection**: Lattice operations separated from structural operations

### 3.2 The SRE Core Module (`sre-core.rkt`)

New file. Contains domain-parameterized versions of the 5 hardcoded
functions:

```racket
;; Domain-parameterized identify-sub-cell
;; Was: identify-sub-cell in elaborator-network.rkt (type-domain only)
(define (sre-identify-sub-cell net domain expr)
  ;; Uses domain's lattice-merge, contradicts?, bot?, meta-lookup
  ...)

;; Domain-parameterized get-or-create-sub-cells (unchanged signature)
;; Already mostly generic — just thread domain for sub-cell creation
(define (sre-get-or-create-sub-cells net domain cell-id tag components)
  ...)

;; Domain-parameterized structural-relate propagator
;; Was: make-structural-unify-propagator (type-domain only)
(define (sre-make-structural-relate-propagator domain cell-a cell-b)
  ;; Uses domain's lattice-merge, contradicts?, bot?
  ...)

;; Domain-parameterized constructor tag lookup
;; Was: type-constructor-tag (hardcoded domain='type)
(define (sre-constructor-tag domain expr)
  (define desc (ctor-tag-for-value expr))
  (and desc (eq? (ctor-desc-domain desc) (sre-domain-name domain))
       (ctor-desc-tag desc)))

;; Domain-parameterized decompose dispatch
;; Was: maybe-decompose (hardcoded Pi/Sigma/lam case arms)
(define (sre-maybe-decompose net domain cell-a cell-b va vb unified pair-key)
  (define tag (sre-constructor-tag domain unified))
  (cond
    [(not tag) net]  ; not compound
    [(net-pair-decomp? net pair-key) net]  ; already decomposed
    [else
     (define desc (lookup-ctor-desc tag #:domain (sre-domain-name domain)))
     (cond
       [(and desc (zero? (ctor-desc-binder-depth desc)))
        ;; Generic path: descriptor-driven decomposition
        (sre-decompose-generic net domain cell-a cell-b va vb unified pair-key desc)]
       [(and desc (positive? (ctor-desc-binder-depth desc)))
        ;; Binder path: domain provides binder-open function via descriptor
        (sre-decompose-binder net domain cell-a cell-b va vb unified pair-key desc)]
       [else net])]))
```

### 3.3 Binder Handling

The specialized Pi/Sigma/lam decomposers exist because they handle
binders (opening codomain with fresh fvar, zonk-at-depth). This
binder machinery is type-domain-specific but structurally generic.

The ctor-desc already has `binder-depth`. We extend it with an
optional `binder-open-fn`:

```racket
;; Extended ctor-desc (new optional field)
binder-open-fn  ; (value binder-index → (values opened-value fresh-var))
                ; #f for binder-depth=0 descriptors
```

For the type domain, Pi's `binder-open-fn` does:
```racket
(lambda (codomain-expr binder-idx)
  (define fv (expr-fvar (gensym 'sre-pi)))
  (values (open-expr codomain-expr fv) fv))
```

This extracts the binder-opening logic from the hardcoded Pi decomposer
into the descriptor. The SRE's `sre-decompose-binder` is generic over
any descriptor with `binder-depth > 0` and a `binder-open-fn`.

### 3.4 PUnify Delegation

After extraction, PUnify's dispatch functions (`punify-dispatch-sub`,
`punify-dispatch-pi`, `punify-dispatch-binder`) delegate to the SRE:

```racket
;; In unify.rkt — punify-dispatch-sub becomes:
(define (punify-dispatch-sub goals)
  (define domain type-sre-domain)  ; the type domain spec
  (define enet (unbox (current-prop-net-box)))
  (define net (elab-network-prop-net enet))
  (for ([goal goals])
    (define-values (a b) (values (car goal) (cdr goal)))
    (define-values (net* cid-a) (sre-identify-sub-cell net domain a))
    (define-values (net** cid-b) (sre-identify-sub-cell net* domain b))
    (unless (= cid-a cid-b)
      (set! net (net-add-propagator net**
                  (sre-make-structural-relate-propagator domain cid-a cid-b)
                  (list cid-a cid-b)))))
  ;; run quiescence, rebox, bridge, check contradiction
  ...)
```

The specialized `punify-dispatch-pi` and `punify-dispatch-binder` also
delegate — they call `sre-identify-sub-cell` and
`sre-make-structural-relate-propagator` with `type-sre-domain`.

**Critical**: Existing PUnify behavior is preserved exactly. This is
extraction, not rewrite. The test suite (7343 tests) is the oracle.

### 3.5 Second Domain Validation (NF-Narrowing)

To validate that the SRE is genuinely domain-parameterized, we
register term-value forms from NF-Narrowing:

```racket
(define term-sre-domain
  (sre-domain 'term
              term-lattice-merge
              term-lattice-contradicts?
              term-bot?
              term-bot
              narrowing-meta-lookup))
```

And register term constructors:
```racket
(register-ctor! (ctor-desc 'cons 2 cons? cons-extract cons-reconstruct
                           (list 'term 'term) 0 'term)
                sample-cons)
```

A simple test: structural-relate two term cells containing cons values,
verify that sub-cells are created and propagated correctly.

### 3.6 Relation Parameter (Phase 5 — Stub)

Phase 5 adds a relation parameter to `sre-make-structural-relate-propagator`:

```racket
(define (sre-make-structural-relate-propagator domain cell-a cell-b
                                                #:relation [relation 'equality])
  ;; For 'equality: symmetric merge (current behavior)
  ;; For 'subtyping: directional with variance from descriptor
  ;; For 'duality: involution with per-field rules
  ...)
```

Phase 5 implements equality (preserving current behavior) and stubs
subtyping (skeleton that dispatches but falls through to equality).
Full relation support is SRE Track 1+ scope.

## 4. File Plan

| File | Action | Description |
|------|--------|-------------|
| `sre-core.rkt` | NEW | Domain-parameterized SRE primitives |
| `ctor-registry.rkt` | MODIFY | Add `binder-open-fn` to `ctor-desc`; register field |
| `elaborator-network.rkt` | MODIFY | Delegate identify-sub-cell etc. to sre-core |
| `unify.rkt` | MODIFY | PUnify dispatch delegates to SRE |
| `driver.rkt` | MODIFY | Create `type-sre-domain` instance |
| `test-sre-core.rkt` | NEW | Unit tests for domain-parameterized SRE |

## 5. Principles Alignment

| Principle | How This Phase Serves It |
|-----------|------------------------|
| **Propagator-First** | SRE primitives are propagator-native: they create cells, install propagators, use lattice merge |
| **Data Orientation** | Domain spec is a data value. Constructor descriptors are data. The SRE registry is a CHAMP. |
| **Correct-by-Construction** | Register a form → decomposition works everywhere. No form → fails at registration, not downstream. |
| **First-Class by Default** | Domains, descriptors, and relations are reified as first-class values |
| **Decomplection** | Lattice operations separated from structural operations. Domain-specific from domain-generic. |
| **Completeness** | This IS the hard thing done right. Every subsequent track (elaborator, resolution, matching, reduction) builds on this foundation. |
| **Most General Interface** | Domain-parameterized + relation-parameterized = maximally general |

**Red-flag check**: No "temporary bridge," no "belt-and-suspenders," no
"keeping the old path as fallback." PUnify delegates to SRE — it doesn't
maintain a parallel path. The old functions are replaced, not wrapped.

## 6. Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|-----------|
| Binder handling complexity | MEDIUM | Phase 3 preserves specialized decomposers initially; generic binder handling in Phase 3b |
| Performance regression from indirection | LOW | Domain spec is a struct access (one pointer deref). Benchmark in Phase 6. |
| ctor-desc field addition breaks external callers | LOW | Optional field with default #f. Recompile all via `raco make driver.rkt`. |
| Second domain (term-value) doesn't fit cleanly | MEDIUM | If term-value reveals gaps, Phase 4 is where we discover and fix them — that's the point. |

## 7. Acceptance Criteria

1. All 7343+ tests pass with PUnify delegating to SRE
2. No performance regression (< 5% wall time increase)
3. A second domain (term-value) registers forms and structural-relate works
4. Relation parameter exists with equality as default; subtyping skeleton compiles
5. No `type-lattice-merge` or `type-bot?` calls remain in SRE core (domain-parameterized)

## 8. Source Documents

| Document | Relationship |
|----------|-------------|
| [SRE Research](../research/2026-03-22_STRUCTURAL_REASONING_ENGINE.md) | Founding insight + structural relation expansion |
| [NTT Syntax Design](2026-03-22_NTT_SYNTAX_DESIGN.md) | Type theory for the SRE's forms |
| [Categorical Foundations](../research/2026-03-22_CATEGORICAL_FOUNDATIONS_TYPED_PROPAGATOR_NETWORKS.md) | Polynomial functor grounding |
| [PUnify Parts 1-2 PIR](2026-03-19_PUNIFY_PARTS1_2_PIR.md) | Prior art: cell-tree unification |
| [PM Track 8D Design](2026-03-22_TRACK8D_DESIGN.md) | Pure bridge fire functions (prerequisite) |
| [Unified Infrastructure Roadmap](2026-03-22_PM_UNIFIED_INFRASTRUCTURE_ROADMAP.md) | On/off-network boundary analysis |
