# SRE Track 0: Form Registry — Domain-Parameterized Structural Decomposition

**Stage**: 3 (Design)
**Date**: 2026-03-22
**Series**: SRE (Structural Reasoning Engine)
**Status**: D.2 — critique incorporated, ready for implementation
**Depends on**: PM Track 8D ✅, PUnify Parts 1-2 ✅

## Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| 0 | Acceptance file baseline | ✅ | 7343 tests, 244.3s; acceptance 16/0 |
| 1 | Domain spec + sre-core.rkt extraction | ✅ | `03e9ede` — leaf module, clean compile |
| 2 | PUnify delegates to SRE (type domain) | ✅ | `08c71ac` — 7343 tests, 239.3s, all pass |
| 3 | Second domain validation (test-term) | ✅ | `217fb31` — 15/15 tests, zero sre-core changes |
| 4 | Verification + benchmarks | ✅ | 7358 tests, 236.7s, all 6 criteria met |

---

## 1. Summary

Extract PUnify's structural decomposition primitives into a
domain-parameterized SRE module (`sre-core.rkt`). The SRE becomes
the universal substrate for structural reasoning — any domain with
"things that have structure" registers forms and gets
decomposition/composition/reconstruction propagators for free.

**Key deliverable**: After Track 0, PUnify delegates to the SRE
with `domain = type-sre-domain`, a second domain (term-value from
NF-Narrowing) can register forms with zero changes to the core, and
the relation parameter exists as a skeleton for future SRE Tracks.

**Why now**: The SRE is the foundational layer for the entire
Propagator Migration program (Tracks 8E–10), CIU Series, BSP-LE
Series, and the eventual self-hosting trajectory. Getting this
right means every subsequent track builds on a solid substrate.
Getting it wrong means every subsequent track works around a
domain-specific core — compounding exactly the kind of debt Track
8D taught us to avoid.

---

## 2. Audit Findings

### 2.1 What Generalizes Well (Already Domain-Neutral)

These primitives need no changes — they're parameterized by
function arguments (merge-fn, contradicts?) already:

| Primitive | Location | Why It Generalizes |
|-----------|----------|-------------------|
| `net-new-cell` | propagator.rkt:303 | Accepts `merge-fn`, `contradicts?` as parameters |
| `net-cell-read` | propagator.rkt:426 | Opaque value; TMS-transparent via speculation stack |
| `net-cell-write` | propagator.rkt:455 | Uses per-cell merge-fn (registered at creation) |
| `net-add-propagator` | propagator.rkt:498 | Pure `(net → net*)` fire fn, any domain |
| `get-or-create-sub-cells` | elaborator-network.rkt:338 | CHAMP registry; tag+sub-cids. Domain-neutral data structure. Only calls `identify-sub-cell` for creation (which IS domain-specific). |
| `decompose-generic` | elaborator-network.rkt:803 | Descriptor-driven. Works for any binder-depth=0 constructor. |
| `make-generic-reconstructor` | elaborator-network.rkt:828 | Uses `ctor-desc-reconstruct-fn`. Fully parameterized. |
| `ctor-desc` struct | ctor-registry.rkt:70 | Already has domain, recognizer, extractor, reconstructor, component-lattices, binder-depth. |

### 2.2 What's Hardcoded to Type Domain (5 Functions)

These functions contain hardcoded `type-lattice-merge`,
`type-lattice-contradicts?`, `type-bot?`, `type-top?`, or
`domain = 'type`:

| Function | Location | Hardcoded References |
|----------|----------|---------------------|
| `identify-sub-cell` | elaborator-network.rkt:317 | `type-bot`, `type-lattice-merge`, `type-lattice-contradicts?`, `type-bot?` |
| `make-structural-unify-propagator` | elaborator-network.rkt:871 | `type-bot?`, `type-top?`, `type-lattice-merge` |
| `type-constructor-tag` | elaborator-network.rkt:302 | `ctor-desc-domain == 'type` |
| `maybe-decompose` | elaborator-network.rkt:842 | Case arms `'Pi`, `'Sigma`, `'lam`; `lookup-ctor-desc #:domain 'type` |
| `decompose-pi` / `decompose-sigma` / `decompose-lam` | elaborator-network.rkt:388-799 | Binder-opening via `expr-fvar`, `gensym`, `open-expr`, `zonk-at-depth` |

### 2.3 What's Hardcoded to Equality Relation

ALL structural decomposition assumes the equality relation (symmetric
lattice join). The `make-structural-unify-propagator` fire function
does `type-lattice-merge(va, vb)` — symmetric join. No support for:
- Subtyping (directional, with variance)
- Duality (involution)
- Coercion (one-way embedding)

### 2.4 Existing Infrastructure That the SRE Can Reuse

The NF-Narrowing system already has a term lattice (`term-lattice.rkt`)
with:
- `term-bot` / `term-top` / `term-bot?` / `term-top?`
- `term-merge` (the lattice join)
- `term-contradiction?`
- Term constructors registered in ctor-registry with `domain = 'data`

This is the natural second domain for validation.

---

## 3. NTT Speculative Syntax

This section expresses the design in NTT syntax — what we'd write if
the NTT type system existed today. This serves as: (a) design clarity
check, (b) correctness reference, (c) NTT refinement data point, and
(d) future implementation guide. The Racket implementation in §4
is the operational realization of these declarations.

### 3.0.1 Level 0: Structural Lattice Declarations

```prologos
;; The type domain — primary structural lattice
data TypeExpr
  := type-bot
   | type-top
   | expr-pi    [domain : TypeExpr] [codomain : TypeExpr]
   | expr-sigma [fst : TypeExpr]    [snd : TypeExpr]
   | expr-app   [fn : TypeExpr]     [arg : TypeExpr]
   | expr-pvec  [elem : TypeExpr]
   | expr-map   [key : TypeExpr]    [val : TypeExpr]
   | expr-set   [elem : TypeExpr]
   | ...
  :lattice :structural
  :bot type-bot
  :top type-top

;; The term domain — NF-Narrowing's structural lattice (validation)
data TermValue
  := term-bot
   | term-top
   | term-cons [head : TermValue] [tail : TermValue]
   | term-zero
   | term-suc  [pred : TermValue]
  :lattice :structural
  :bot term-bot
  :top term-top

;; A value lattice for contrast — pure join, no structural decomposition
type MultExpr := mult-bot | m0 | m1 | mw | mult-top

impl Lattice MultExpr
  join
    | mult-bot x -> x
    | x mult-bot -> x
    | x x        -> x
    | _ _        -> mult-top
  bot -> mult-bot
```

**What `:lattice :structural` derives** (the SRE's job):
- Form registry entries from each constructor (tag, arity, fields)
- Decomposition propagators: parent cell → sub-cells per field
- Reconstruction propagators: sub-cells → parent cell
- Merge semantics: matching tags → pairwise sub-field decomposition;
  mismatching tags → top (contradiction)
- Sub-cell caching in the decomposition registry (CHAMP-backed)

### 3.0.2 Level 2: Derived Propagators

These are auto-derived from `:lattice :structural` — the user never
writes them. Shown here to make the derivation explicit:

```prologos
;; Auto-derived: structural equality propagator for TypeExpr
propagator structural-relate-TypeExpr
  :reads  [a : Cell TypeExpr, b : Cell TypeExpr]
  :writes [a : Cell TypeExpr, b : Cell TypeExpr]
  ;; Monotone implicit.
  ;; Fire: read both cells.
  ;;   Both bot → no-op.
  ;;   One bot → write known to unknown, decompose.
  ;;   Both non-bot → merge. Contradiction → write top.
  ;;     Compatible → write merged to both, decompose sub-fields.

;; Auto-derived: Pi decomposition propagator
propagator decompose-pi
  :reads  [parent : Cell TypeExpr]
  :writes [domain : Cell TypeExpr, codomain : Cell TypeExpr]
  ;; Fire: if parent has Pi tag, extract domain/codomain into sub-cells.
  ;; Reverse: if both sub-cells non-bot, reconstruct Pi and write to parent.

;; Auto-derived: generic reconstruction (one per constructor)
propagator reconstruct-pi
  :reads  [domain : Cell TypeExpr, codomain : Cell TypeExpr]
  :writes [parent : Cell TypeExpr]
  ;; Fire: if all sub-cells non-bot, build expr-pi and write to parent.
```

### 3.0.3 Level 4: Cross-Domain Bridges

```prologos
;; The mult bridge — Layer 2 concern, wired by caller after SRE decomposition
bridge TypeToMult
  :from TypeExpr
  :to   MultExpr
  :alpha type->mult
  :gamma mult->type
  :preserves [Tensor]

;; The session bridge
bridge TypeToSession
  :from TypeExpr
  :to   SessionExpr
  :alpha type->session
  :gamma session->type
```

These correspond to the `wire-mult-bridge` call in the PUnify
dispatch code. The SRE (Layer 1) decomposes structurally; the
bridge (Layer 2) crosses domains. The NTT declaration generates
the same propagator wiring that the Racket caller does manually.

### 3.0.4 Level 5: Stratification Context

```prologos
stratification ElabLoop
  :strata [S-neg1 S0 S1 S2]
  :fiber S0
    :bridges [TypeToMult TypeToSession]
    :speculation :atms
  :fiber S1
  :barrier S2 -> S-neg1
    :commit resolve-and-retract
  :fuel 100
  :where [WellFounded ElabLoop]
```

This IS our `run-to-quiescence` loop with stratified resolution.
The SRE's structural-relate propagators fire in S0. The bridges
also fire in S0. The NTT declaration describes the same architecture
that `metavar-store.rkt` implements imperatively.

### 3.0.5 NTT ↔ Racket Correspondence

| NTT Construct | Racket Implementation (SRE Track 0) |
|--------------|-------------------------------------|
| `data ... :lattice :structural` | `sre-domain` struct + `ctor-desc` registrations |
| Constructor fields | `ctor-desc` arity, extract-fn, reconstruct-fn |
| `:bot` / `:top` | `sre-domain-bot-value`, `sre-domain-contradicts?` |
| Auto-derived `structural-relate` propagator | `sre-make-structural-relate-propagator` |
| Auto-derived decomposition | `sre-maybe-decompose` → `sre-decompose-generic` |
| Auto-derived reconstruction | `make-generic-reconstructor` |
| Sub-cell caching | `sre-get-or-create-sub-cells` (CHAMP registry) |
| `bridge :from :to :alpha :gamma` | `wire-mult-bridge` call in PUnify dispatch |
| `stratification :fiber S0` | `run-to-quiescence` in `metavar-store.rkt` |
| `:lattice :structural` derivation | `sre-core.rkt` (THIS TRACK'S DELIVERABLE) |

**Key insight**: `sre-core.rkt` IS the operational semantics of
`:lattice :structural`. The NTT declaration is the surface syntax;
the SRE is the execution engine. SRE Track 0 builds the engine that
the NTT will eventually drive.

---

## 4. Design

### 4.1 The Domain Spec (`sre-domain`)

A domain spec bundles the lattice operations needed for structural
reasoning in a particular domain. It's a first-class data value —
not a set of callbacks scattered across Racket parameters.

```racket
(struct sre-domain
  (name              ; symbol: 'type, 'term, 'session, ...
   lattice-merge     ; (old new → merged) — the lattice join
   contradicts?      ; (val → bool) — is this value top/contradiction?
   bot?              ; (val → bool) — is this value bottom?
   bot-value         ; the bottom element itself
   meta-recognizer   ; (expr → bool) — pure structural check: is this a meta/var ref?
                     ; #f if domain has no meta-like references
   meta-resolver     ; (expr → cell-id | #f) — context-dependent lookup: what cell?
                     ; #f if domain has no meta-like references
   )
  #:transparent)

;; Design note (D.2 critique): meta-recognizer is PURE — safe to cache,
;; no ambient state. meta-resolver is CONTEXT-DEPENDENT — it reads from
;; the current elab-network (type domain) or narrowing context (term domain).
;; The domain spec is created per-command, so the resolver closure always
;; reads from the correct context. This invariant must be maintained.
;;
;; Design note: The lattice ordering is NOT a separate field because
;; merge IS the ordering for join-semilattices (a ≤ b iff merge(a,b) = b).
;; Subtyping variance (SRE Track 1) uses per-component annotations on
;; ctor-desc, not a domain-level ordering function.
;;
;; Design note: Domain identity is by name symbol. Two domains that
;; share a lattice (e.g., type domain and refinement type domain) are
;; treated as separate — their cells don't interact without a bridge.
;; This is a deliberate isolation choice, not accidental.
```

**Instantiations**:

```racket
;; Type domain — the primary domain (PUnify's current behavior)
(define type-sre-domain
  (sre-domain 'type
              type-lattice-merge
              type-lattice-contradicts?
              type-bot?
              type-bot
              expr-meta?                                    ;; pure recognizer
              (lambda (expr)                                ;; context-dependent resolver
                (prop-meta-id->cell-id (expr-meta-id expr)))))

;; Term domain — NF-Narrowing's domain (Phase 3 validation)
(define term-sre-domain
  (sre-domain 'term
              term-merge
              term-contradiction?
              term-bot?
              term-bot
              term-var?                                     ;; pure recognizer
              (lambda (expr)                                ;; context-dependent resolver
                (narrowing-var->cell-id (term-var-name expr)))))
```

**Why a struct, not a Racket parameter?**

The current approach scatters domain operations across parameters
(`current-structural-meta-lookup`) and hardcoded imports
(`type-lattice-merge`). The `sre-domain` struct bundles everything
into a single value that can be:
- Passed as an argument (no global state)
- Stored in a registry (domain lookup)
- Compared (which domain am I operating in?)
- Composed (future: multi-domain reasoning)

This is **Data Orientation**: the domain is a value, not ambient state.

### 4.2 The SRE Core Module (`sre-core.rkt`)

New file. Contains domain-parameterized versions of the 5 hardcoded
functions. All are pure — they accept the network as a value and
return a modified network. No Racket parameters used internally.

#### `sre-identify-sub-cell`

```racket
;; Domain-parameterized version of identify-sub-cell
;; Was: elaborator-network.rkt:317, hardcoded to type domain
(define (sre-identify-sub-cell net domain expr)
  (define recognizer (sre-domain-meta-recognizer domain))
  (define resolver (sre-domain-meta-resolver domain))
  (cond
    ;; Meta/var ref → reuse existing cell (recognizer is pure, resolver is context-dependent)
    [(and recognizer (recognizer expr))
     (define cid (and resolver (resolver expr)))
     (if cid
         (values net cid)
         ;; Recognized as meta but no cell mapping → fresh bot cell
         (net-new-cell net
                       (sre-domain-bot-value domain)
                       (sre-domain-lattice-merge domain)
                       (sre-domain-contradicts? domain)))]
    ;; Bot → fresh bot cell
    [((sre-domain-bot? domain) expr)
     (net-new-cell net
                   (sre-domain-bot-value domain)
                   (sre-domain-lattice-merge domain)
                   (sre-domain-contradicts? domain))]
    ;; Concrete value → fresh cell initialized to value
    [else
     (net-new-cell net
                   expr
                   (sre-domain-lattice-merge domain)
                   (sre-domain-contradicts? domain))]))
```

**Change from original**: `type-bot`, `type-lattice-merge`,
`type-lattice-contradicts?`, `type-bot?` → field accesses on `domain`.
`current-structural-meta-lookup` parameter → `sre-domain-meta-lookup`.

#### `sre-constructor-tag`

```racket
;; Domain-parameterized version of type-constructor-tag
;; Was: elaborator-network.rkt:302, hardcoded domain='type
(define (sre-constructor-tag domain expr)
  (define desc (ctor-tag-for-value expr))
  (and desc
       (eq? (ctor-desc-domain desc) (sre-domain-name domain))
       (ctor-desc-tag desc)))
```

**Change**: `'type` literal → `(sre-domain-name domain)`.

#### `sre-make-structural-relate-propagator`

```racket
;; Domain-parameterized version of make-structural-unify-propagator
;; Was: elaborator-network.rkt:871, hardcoded to type lattice
;;
;; Relation parameter defaults to 'equality (symmetric merge).
;; Future SRE tracks add 'subtyping, 'duality, 'coercion.
;; NOTE: Future SRE Track 1 will add a #:relation parameter here.
;; See §4.6 for design rationale on deferral.
(define (sre-make-structural-relate-propagator domain cell-a cell-b)
  (define merge (sre-domain-lattice-merge domain))
  (define contradicts? (sre-domain-contradicts? domain))
  (define bot? (sre-domain-bot? domain))
  (lambda (net)
    (define va (net-cell-read net cell-a))
    (define vb (net-cell-read net cell-b))
    (cond
      ;; Both bot: nothing to propagate
      [(and (bot? va) (bot? vb)) net]
      ;; One bot: propagate the known value, then try decomposition
      [(bot? va)
       (let ([net* (net-cell-write net cell-a vb)])
         (sre-maybe-decompose net* domain cell-a cell-b va vb vb))]
      [(bot? vb)
       (let ([net* (net-cell-write net cell-b va)])
         (sre-maybe-decompose net* domain cell-a cell-b va vb va))]
      ;; Both have values: compute lattice join
      [else
       (define unified (merge va vb))
       ;; Debug-mode idempotency check (D.2 critique): catches non-monotone merge
       ;; functions at low cost. merge(merge(a,b), a) must equal merge(a,b).
       (when (current-sre-debug?)
         (unless (equal? (merge unified va) unified)
           (error 'sre-structural-relate
                  "Non-idempotent merge detected: merge(~a, ~a) = ~a but merge(~a, ~a) = ~a"
                  va vb unified unified va (merge unified va))))
       (if (contradicts? unified)
           ;; Contradiction
           (net-cell-write net cell-a unified)
           ;; Compatible: write unified to both, then decompose
           (let* ([net*  (net-cell-write net cell-a unified)]
                  [net** (net-cell-write net* cell-b unified)])
             (sre-maybe-decompose net** domain cell-a cell-b va vb unified)))])))
```

**Change**: `type-bot?` → `bot?`, `type-top?` → `contradicts?`,
`type-lattice-merge` → `merge`. All resolved from domain struct.

**Termination argument**: Same as PUnify's current argument (preserved
exactly). Decomp registries prevent duplicate work. Lattice-merge
monotonicity + `net-cell-write` no-change guard prevent infinite loops.
Reconstructor writes the same compound as parent → no change →
terminate. Guarantee level: 2 (finite lattice height with fuel guard).

#### `sre-maybe-decompose`

```racket
;; Domain-parameterized version of maybe-decompose
;; Was: elaborator-network.rkt:842, hardcoded Pi/Sigma/lam case arms
(define (sre-maybe-decompose net domain cell-a cell-b va vb unified)
  (define tag (sre-constructor-tag domain unified))
  (cond
    [(not tag) net]  ;; Not compound — nothing to decompose
    [else
     (define pair-key (decomp-key cell-a cell-b))
     (cond
       [(net-pair-decomp? net pair-key) net]  ;; Already decomposed
       [else
        (define desc (lookup-ctor-desc tag #:domain (sre-domain-name domain)))
        (cond
          [(not desc) net]
          ;; Binder-depth=0: generic descriptor-driven decomposition
          [(zero? (ctor-desc-binder-depth desc))
           (sre-decompose-generic net domain cell-a cell-b va vb unified pair-key desc)]
          ;; Binder-depth>0: descriptor provides binder-open-fn
          [(ctor-desc-binder-open-fn desc)
           (sre-decompose-binder net domain cell-a cell-b va vb unified pair-key desc)]
          ;; Binder-depth>0 but no binder-open-fn: can't decompose
          ;; (shouldn't happen if descriptors are properly registered)
          [else net])])]))
```

**Change**: No hardcoded `case` arms for Pi/Sigma/lam. All constructors
go through the descriptor. Binder-handling constructors provide a
`binder-open-fn` on their descriptor.

#### `sre-decompose-generic`

```racket
;; Domain-parameterized version of decompose-generic
;; Was: elaborator-network.rkt:803, already mostly generic
(define (sre-decompose-generic net domain cell-a cell-b va vb unified pair-key desc)
  (define recognizer (ctor-desc-recognizer-fn desc))
  (define extractor (ctor-desc-extract-fn desc))
  ;; Determine which side to extract from
  (define source-a (if (recognizer va) va unified))
  (define source-b (if (recognizer vb) vb unified))
  (define comps-a (extractor source-a))
  (define comps-b (extractor source-b))
  (define tag (ctor-desc-tag desc))
  ;; Get or create sub-cells for each side
  (define-values (net1 sub-a) (sre-get-or-create-sub-cells net domain cell-a tag comps-a))
  (define-values (net2 sub-b) (sre-get-or-create-sub-cells net1 domain cell-b tag comps-b))
  ;; Add structural-relate propagators between corresponding sub-cells
  (define net3
    (for/fold ([n net2]) ([sa (in-list sub-a)] [sb (in-list sub-b)])
      (if (= sa sb) n  ;; Same cell — no propagator needed
          (net-add-propagator n
            (sre-make-structural-relate-propagator domain sa sb)
            (list sa sb)))))
  ;; Add reconstructors for each side
  (define net4 (net-add-propagator net3
                 (make-generic-reconstructor cell-a sub-a desc)
                 sub-a))
  (define net5 (net-add-propagator net4
                 (make-generic-reconstructor cell-b sub-b desc)
                 sub-b))
  ;; Register pair to prevent re-decomposition
  (net-pair-decomp-insert net5 pair-key))
```

**Change**: `identify-sub-cell` → `sre-identify-sub-cell` (called
inside `sre-get-or-create-sub-cells`). Reconstructor reuse unchanged.

#### `sre-get-or-create-sub-cells`

```racket
;; Domain-parameterized version of get-or-create-sub-cells
;; Was: elaborator-network.rkt:338, called identify-sub-cell (type-only)
(define (sre-get-or-create-sub-cells net domain cell-id tag components)
  (define existing (net-cell-decomp-lookup net cell-id))
  (cond
    [(not (eq? existing 'none))
     ;; Already decomposed — reuse existing sub-cells
     (values net (cdr existing))]
    [else
     ;; Create sub-cells for each component
     (define-values (net* sub-cids)
       (for/fold ([n net] [cids '()]) ([comp (in-list components)])
         (define-values (n* cid) (sre-identify-sub-cell n domain comp))
         (values n* (cons cid cids))))
     (define ordered-cids (reverse sub-cids))
     ;; Register in decomp registry
     (define net** (net-cell-decomp-insert net* cell-id (cons tag ordered-cids)))
     (values net** ordered-cids)]))
```

### 4.3 Binder Handling

The specialized Pi/Sigma/lam decomposers exist because they handle
dependent type binders: opening the codomain with a fresh fvar,
zonking at binder depth, managing the mult bridge for Pi. This
machinery is type-domain-specific in its details but structurally
generic in its pattern.

**Approach**: Extend `ctor-desc` with an optional `binder-open-fn`
field. Descriptors with `binder-depth > 0` must provide this function.

```racket
;; Extended ctor-desc — add one field (backward-compatible via default #f)
(struct ctor-desc
  (tag arity recognizer-fn extract-fn reconstruct-fn
   component-lattices binder-depth domain
   binder-open-fn)    ;; NEW: (value binder-idx → (values opened fresh-var)) | #f
  #:transparent)
```

For Pi, the binder-open-fn would be:
```racket
(lambda (codomain-expr binder-idx)
  (define fv (expr-fvar (gensym 'sre-binder)))
  (values (open-expr codomain-expr fv) fv))
```

The `sre-decompose-binder` function is generic:
1. Extract components via `ctor-desc-extract-fn`
2. For components at binder positions (index >= arity - binder-depth),
   call `binder-open-fn` to open the binder
3. Create sub-cells for opened components
4. Add structural-relate propagators
5. Add reconstructors (must close binders on reconstruction)

**Mult bridge for Pi**: Currently handled by the
`current-structural-mult-bridge` callback in `decompose-pi`. This is
Pi-specific (other binder types don't have mults). The SRE handles
this via a new optional `post-decompose-hook` on the descriptor — a
function called after sub-cells are created, receiving the sub-cell
IDs. For Pi, this hook wires the mult bridge:

```racket
;; Pi descriptor with binder-open and post-decompose-hook
(define pi-ctor-desc
  (ctor-desc 'Pi 3 expr-Pi? pi-extract pi-reconstruct
             (list mult-lattice-spec 'type 'type) 1 'type
             pi-binder-open-fn
             pi-post-decompose-hook))  ;; wires mult bridge
```

Wait — this adds a second new field. Let me reconsider.

**Alternative**: Instead of `post-decompose-hook`, the Pi mult bridge
is wired by the caller (PUnify dispatch) AFTER the SRE decomposes.
The SRE doesn't know about mults — it just decomposes structurally.
The mult bridge is a Layer 2 concern (Galois bridge), not Layer 1
(structural decomposition). This keeps the SRE clean.

**Decision**: No `post-decompose-hook`. The SRE decomposes. The
caller (PUnify or elaborator) wires any cross-domain bridges after
decomposition. One new field on `ctor-desc` (`binder-open-fn`), not
two. The mult bridge stays where it is — in the PUnify dispatch code
that calls the SRE.

**Future consideration (D.2 critique)**: `ctor-desc` now has 9 fields
and serves multiple roles (recognizer, extractor, reconstructor, domain
tag, structural descriptor, binder handler). If SRE Track 1 adds
per-component variance annotations and Track 2 adds coercion functions,
the struct grows further. Consider factoring into core (tag, arity,
domain) + capability structs (extraction, reconstruction, binder-handling,
variance) — the "small structs composed by product" pattern. Not for
Track 0, but monitor for the threshold.

**Principles check**:
- **Decomplection**: Structural decomposition (SRE, Layer 1) is
  separated from cross-domain bridging (Galois, Layer 2). Good.
- **Completeness**: The SRE handles ALL structural decomposition.
  The caller handles cross-domain concerns. No mixed responsibility.

### 4.4 PUnify Delegation

After extraction, PUnify's dispatch functions delegate to the SRE.
The delegation is mechanical — each function replaces hardcoded
calls with SRE equivalents.

#### `punify-dispatch-sub` (multi-goal)

```racket
;; Current: creates sub-cells and propagators directly
;; After: delegates to sre-core
(define (punify-dispatch-sub goals)
  (define enet (unbox (current-prop-net-box)))
  (define net (elab-network-prop-net enet))
  (define domain type-sre-domain)
  ;; For each goal pair: identify sub-cells, add structural-relate propagator
  (define net*
    (for/fold ([n net]) ([goal (in-list goals)])
      (define a (car goal))
      (define b (cdr goal))
      (define-values (n1 cid-a) (sre-identify-sub-cell n domain a))
      (define-values (n2 cid-b) (sre-identify-sub-cell n1 domain b))
      (if (= cid-a cid-b) n2  ;; same cell — skip
          (net-add-propagator n2
            (sre-make-structural-relate-propagator domain cid-a cid-b)
            (list cid-a cid-b)))))
  ;; Rebox, run quiescence, bridge cell-solved metas, check contradiction
  (set-box! (current-prop-net-box) (elab-network-rewrap enet net*))
  (define net** (punify-run-quiescence-and-bridge))
  (not (net-has-contradiction? net**)))
```

#### `punify-dispatch-pi` (Pi with binder + mult)

```racket
;; After: delegates structural part to SRE, wires mult bridge separately
(define (punify-dispatch-pi m1 m2 dom-a dom-b cod-a cod-b)
  (define enet (unbox (current-prop-net-box)))
  (define net (elab-network-prop-net enet))
  (define domain type-sre-domain)
  ;; Step 1: Unify multiplicities (separate domain, unchanged)
  (unify-mult m1 m2)
  ;; Step 2: SRE domain unification
  (define-values (n1 cid-dom-a) (sre-identify-sub-cell net domain dom-a))
  (define-values (n2 cid-dom-b) (sre-identify-sub-cell n1 domain dom-b))
  (define n3
    (if (= cid-dom-a cid-dom-b) n2
        (net-add-propagator n2
          (sre-make-structural-relate-propagator domain cid-dom-a cid-dom-b)
          (list cid-dom-a cid-dom-b))))
  ;; Step 3: Open codomains with fresh fvar (binder handling)
  (define fv (expr-fvar (gensym 'sre-pi)))
  (define opened-cod-a (open-expr (zonk-at-depth cod-a 1) fv))
  (define opened-cod-b (open-expr (zonk-at-depth cod-b 1) fv))
  ;; Step 4: SRE codomain unification
  (define-values (n4 cid-cod-a) (sre-identify-sub-cell n3 domain opened-cod-a))
  (define-values (n5 cid-cod-b) (sre-identify-sub-cell n4 domain opened-cod-b))
  (define n6
    (if (= cid-cod-a cid-cod-b) n5
        (net-add-propagator n5
          (sre-make-structural-relate-propagator domain cid-cod-a cid-cod-b)
          (list cid-cod-a cid-cod-b))))
  ;; Step 5: Wire mult bridge (Layer 2 concern, not SRE's job)
  (define n7 (wire-mult-bridge n6 cid-dom-a m1))
  ;; Step 6: Rebox, quiescence, bridge, check
  (set-box! (current-prop-net-box) (elab-network-rewrap enet n7))
  (define n8 (punify-run-quiescence-and-bridge))
  (not (net-has-contradiction? n8)))
```

**Key observation**: The Pi dispatch still handles binder-opening and
mult-bridging explicitly. The SRE handles the structural parts (identify
sub-cells, make propagators). This is the correct separation: SRE for
Layer 1 (structural decomposition), caller for Layer 2 (cross-domain
bridges) and domain-specific operations (binder opening).

**Phase 2 implementation strategy**: Start with `punify-dispatch-sub`
(simplest, no binders). Then `punify-dispatch-pi` and
`punify-dispatch-binder`. Test after each. The existing test suite
is the oracle — any behavioral change is a bug.

### 4.5 Second Domain Validation (Phase 3)

To validate the SRE is genuinely domain-parameterized, we register
term-value structural forms from NF-Narrowing and write isolated tests.

```racket
;; In test-sre-core.rkt:
(define term-sre-domain
  (sre-domain 'term
              term-merge
              term-contradiction?
              term-bot?
              term-bot
              #f))  ;; no meta-lookup for test domain

;; Register a term constructor (cons)
(register-ctor!
  (ctor-desc 'cons 2 cons? cons-extract cons-reconstruct
             (list term-lattice-spec term-lattice-spec) 0 'term
             #f)  ;; no binder
  sample-cons-value)

;; Test: structural-relate two term cells
(test-case "SRE decomposes term-value cons"
  (define-values (net c1) (net-new-cell empty-net term-bot term-merge term-contradiction?))
  (define-values (net* c2) (net-new-cell net term-bot term-merge term-contradiction?))
  ;; Write cons values to cells
  (define net1 (net-cell-write net* c1 (make-cons 1 2)))
  (define net2 (net-cell-write net1 c2 (make-cons 3 4)))
  ;; Add structural-relate propagator
  (define net3 (net-add-propagator net2
                 (sre-make-structural-relate-propagator term-sre-domain c1 c2)
                 (list c1 c2)))
  ;; Run to quiescence
  (define net4 (run-to-quiescence net3))
  ;; Sub-cells should have merged: head=merge(1,3), tail=merge(2,4)
  ...)
```

**What this validates**:
- `sre-identify-sub-cell` works with `term-merge` (not `type-lattice-merge`)
- `sre-constructor-tag` looks up `'term` domain (not `'type`)
- `sre-maybe-decompose` dispatches via descriptor (no hardcoded case arms)
- Sub-cell propagation works across domains

**What might break**: If `decompose-generic` has any residual type-domain
assumptions. The test will catch this.

### 4.6 Relation Parameter (Future — SRE Track 1)

The structural-relate propagator currently handles equality (symmetric
merge). Future SRE tracks will add a `#:relation` parameter for
subtyping (directional with variance), duality (involution), and
coercion (one-way embedding). See SRE Research doc § "Structural
Relation Engine."

**Design decision (D.2 critique)**: Do NOT add the `#:relation`
parameter as a stub in Track 0. A parameter that accepts `'subtyping`
but silently treats it as equality is a correctness hazard — worse
than the parameter not existing. When SRE Track 1 adds subtyping, it
adds the parameter with actual implementation. The API change from
"no parameter" to "optional parameter with default" is backward-
compatible — no existing call sites break.

```racket
;; NOTE (sre-make-structural-relate-propagator): Future SRE tracks
;; will add a #:relation parameter here for subtyping, duality, and
;; coercion. The structural-relate propagator will dispatch on relation
;; type with variance annotations from ctor-desc component fields.
;; See SRE Research doc § "Structural Relation Engine."
```

---

## 5. Phased Implementation Plan

### Phase 0: Acceptance File Baseline

**Deliverable**: Run existing acceptance file + full test suite. Record
baseline metrics.

**Test strategy**: `racket tools/run-affected-tests.rkt --all`. Record
wall time and test count. This is the regression baseline.

**Success criteria**: Clean pass. Recorded baseline.

### Phase 1: Domain Spec + sre-core.rkt Extraction

**Deliverable**: New files `sre-core.rkt` and updated `ctor-registry.rkt`.

**What gets created**:
- `sre-domain` struct definition
- `type-sre-domain` and `term-sre-domain` instances
- `sre-identify-sub-cell` (parameterized)
- `sre-constructor-tag` (parameterized)
- `sre-make-structural-relate-propagator` (parameterized)
- `sre-maybe-decompose` (parameterized)
- `sre-decompose-generic` (parameterized)
- `sre-get-or-create-sub-cells` (parameterized)
- `binder-open-fn` field added to `ctor-desc` (optional, default #f)

**What does NOT change yet**: `elaborator-network.rkt` and `unify.rkt`
still use the old functions. The SRE core exists but isn't wired in.

**Test strategy**: Unit tests in `test-sre-core.rkt` that exercise
each function in isolation with both type and term domains. Include
negative tests (D.2 critique):
- Unregistered constructor tag → `sre-maybe-decompose` returns net unchanged
- `contradicts?` returning true for bot → detectable inconsistency
- Debug-mode idempotency assertion catches a deliberately non-monotone merge
No integration testing in Phase 1 — that's Phase 2.

**Dependency check**: `sre-core.rkt` imports from `propagator.rkt`
(cell ops), `ctor-registry.rkt` (descriptor lookup). No circular
dependencies — `sre-core.rkt` is a leaf module.

**Success criteria**: All SRE functions compile. Unit tests pass for
both domains. Full suite still passes (no changes to production code).

### Phase 2: PUnify Delegates to SRE (Type Domain)

**Deliverable**: `unify.rkt` punify-dispatch functions call SRE instead
of hardcoded elaborator-network functions.

**Pre-step (D.2 critique)**: Grep all call sites of the 5 hardcoded
functions (`identify-sub-cell`, `make-structural-unify-propagator`,
`type-constructor-tag`, `maybe-decompose`, `get-or-create-sub-cells`).
If all callers are within `elaborator-network.rkt` + `unify.rkt`,
skip the thin-wrapper strategy — delete the old functions and update
call sites directly. If external callers exist, use thin wrappers
for backward compatibility.

**Migration order** (ascending risk):
1. `punify-dispatch-sub` — simplest, no binders, no mult
2. `punify-dispatch-binder` — binder handling (Sigma/lam)
3. `punify-dispatch-pi` — binder + mult bridge

**What changes in `unify.rkt`**: Each `punify-dispatch-*` function
replaces `identify-sub-cell` with `sre-identify-sub-cell`,
`make-structural-unify-propagator` with
`sre-make-structural-relate-propagator`, etc.

**What changes in `elaborator-network.rkt`**: If no external callers
(likely), the old functions are deleted. The SRE equivalents in
`sre-core.rkt` are the canonical implementations. If external callers
exist, the old functions become thin wrappers.

**Explicit fvar test (D.2 critique)**: After migrating `punify-dispatch-pi`,
add a test that decomposes a Pi type and verifies: (a) the codomain
sub-cell contains the opened expression with fvar, (b) the fvar is
treated as a concrete value (not routed through meta-lookup), (c) the
sub-cell is initialized to the opened codomain, not bot.

**Test strategy**: Full test suite after each sub-step (dispatch-sub,
dispatch-binder, dispatch-pi). Any failure = bug in delegation.

**Success criteria**: All 7343+ tests pass. No behavioral change.

### Phase 3: Second Domain Validation (Term-Value)

**Deliverable**: `test-sre-core.rkt` includes integration tests that
create a term-domain network, add structural-relate propagators,
run to quiescence, and verify sub-cell creation + propagation.

**What this proves**: The SRE is genuinely domain-parameterized. A
domain other than 'type can register forms and use the same
decomposition/composition machinery.

**Test strategy**: Dedicated test file with ~10 test cases covering:
- Bot propagation (one cell bot, other concrete)
- Both concrete (merge via term-merge)
- Contradiction (incompatible constructors)
- Nested decomposition (cons of cons)
- Sub-cell reuse (decompose same cell twice → same sub-cells)

**Success criteria**: All term-domain tests pass. Full suite still passes.

### Phase 4: Verification + Benchmarks

**Deliverable**: Confirmed no regression. Performance data.

**Test strategy**:
- Full test suite: `racket tools/run-affected-tests.rkt --all`
- A/B benchmark: `racket tools/bench-ab.rkt benchmarks/comparative/ --runs 10`
- Acceptance file: `process-file` on Track 8D acceptance file
- Per-command verbose: `process-file #:verbose #t` on acceptance file

**Success criteria**:
- All tests pass
- Wall time within 5% of baseline
- No `type-lattice-merge` or `type-bot?` calls in `sre-core.rkt`
- `type-sre-domain` and `term-sre-domain` both functional

---

## 6. File Plan

| File | Action | Phase | Description |
|------|--------|-------|-------------|
| `sre-core.rkt` | NEW | 1 | Domain-parameterized SRE primitives |
| `ctor-registry.rkt` | MODIFY | 1 | Add `binder-open-fn` to `ctor-desc` |
| `test-sre-core.rkt` | NEW | 1-3 | Unit + integration tests |
| `elaborator-network.rkt` | MODIFY | 2 | Old functions → thin wrappers around SRE |
| `unify.rkt` | MODIFY | 2 | PUnify dispatch → SRE calls |
| `driver.rkt` | MODIFY | 2 | Create + install `type-sre-domain` |

---

## 7. Dependency Analysis

```
sre-core.rkt
  ├── propagator.rkt (cell ops: net-new-cell, net-cell-read, net-cell-write, net-add-propagator)
  ├── ctor-registry.rkt (ctor-desc lookup, ctor-tag-for-value)
  └── (no circular dependencies — leaf module)

unify.rkt
  └── sre-core.rkt (new import: sre-identify-sub-cell, sre-make-structural-relate-propagator)

elaborator-network.rkt
  └── sre-core.rkt (new import: delegates old functions to SRE)

driver.rkt
  └── sre-core.rkt (new import: type-sre-domain creation)
```

**No circular dependency risk**: `sre-core.rkt` imports only from
`propagator.rkt` and `ctor-registry.rkt`, both of which are upstream.

---

## 8. Termination Arguments

### Structural-relate propagators (equality relation)

**Guarantee level**: 2 (finite lattice height with fuel guard)

**Argument** (preserved from PUnify, unchanged by parameterization):
1. Each cell's value can only move upward in the lattice (monotone writes)
2. Lattice has finite height (type lattice: bounded by expression depth)
3. `net-cell-write` returns net unchanged if merge produces same value
4. Decomposition registries prevent duplicate sub-cell creation
5. Pair-decomposition registries prevent duplicate propagators
6. Therefore: each propagator fires at most once per lattice level
7. Total firings bounded by: (number of cells) × (lattice height)

**What parameterization could break**: If a domain provides a
non-monotone merge function, the termination argument fails. The
SRE does NOT verify monotonicity — it trusts the domain spec. This
is documented: "domain specs must provide monotone merge functions."

Future NTT enforcement (SRE Track 1+) can verify monotonicity
statically via the `:where [Monotone]` constraint on propagators.

---

## 9. Principles Alignment (Challenge, Not Catalogue)

### Propagator-First
**Serves**: SRE primitives create cells, install propagators, use
lattice merge — all propagator-native operations.
**Challenge**: Does the `sre-domain` struct create non-propagator state?
No — it's immutable data passed as an argument, not mutable state.
The domain spec describes lattice operations; the SRE executes them
on the network.

### Data Orientation
**Serves**: Domain spec is a first-class data value. Constructor
descriptors are data. The SRE registry is a CHAMP.
**Challenge**: PUnify's delegation still boxes/unboxes `current-prop-net-box`.
This is inherited imperative debt, not new debt. Track 8E-10 addresses
this. The SRE core itself (`sre-core.rkt`) is pure — no boxes.

### Correct-by-Construction
**Serves**: Register a form → decomposition works everywhere.
**Challenge**: What if a domain registers an incorrect merge function
(non-monotone)? The SRE trusts the domain spec. Is this correct-by-
construction? No — it's correct-by-contract. True CbC would verify
monotonicity structurally. This is a known limitation, addressed by
NTT enforcement in future tracks.

### Completeness
**Serves**: This IS the hard thing done right. Every subsequent track
builds on this.
**Challenge**: Are we doing enough? We're extracting and parameterizing,
not rewriting. Is extraction "the hard thing"? Yes — the hard part is
getting the abstraction boundary right (what's domain-specific vs
domain-generic). The extraction reveals the boundary; the parameterization
makes it formal.

### Decomplection
**Serves**: Lattice operations (domain spec) separated from structural
operations (SRE core). Domain-specific from domain-generic.
**Challenge**: The binder-open-fn on ctor-desc mixes domain-specific
(opening a Pi codomain) with registry-level (constructor descriptor).
Is this the right place? Alternatives: (a) binder-open as a domain-spec
field, (b) binder-open as a separate registry. We chose descriptor-level
because different constructors in the same domain may have different
binder-opening behavior (Pi vs Sigma vs lam all open differently).
The domain-spec doesn't know about individual constructors.

### Composition
**Serves**: SRE + Galois bridges compose via shared cells. Mult bridge
wired by caller after SRE decomposition.
**Challenge**: What if a future domain needs post-decomposition hooks
that the SRE doesn't support? We explicitly decided against
`post-decompose-hook` to keep the SRE clean. If needed, the caller
handles it. This may become a friction point if many domains need
post-decomposition wiring. Monitor for this — if 3+ domains need
hooks, reconsider.

---

## 10. Acceptance Criteria

1. All 7343+ tests pass with PUnify delegating to SRE
2. No performance regression (< 5% wall time increase)
3. A second domain (term-value) registers forms and structural-relate works
4. No `type-lattice-merge` or `type-bot?` calls remain in `sre-core.rkt` (fully domain-parameterized)
5. Debug-mode idempotency assertions pass for both type and term domains
6. Negative tests confirm graceful handling of unregistered tags and malformed specs

## 11. WS Impact

None. This track changes internal infrastructure only. No new
user-facing syntax. No preparse changes. No reader changes.

---

## 12. D.2 Critique Summary

External critique received and addressed. Key changes:

| Critique Point | Response | Action |
|---------------|----------|--------|
| sre-domain missing lattice ordering | Push back: merge IS ordering for join-semilattices. Subtyping variance goes on ctor-desc, not domain. | Added design notes as comments |
| meta-lookup conflates recognizer + resolver | Accept: split into pure `meta-recognizer` + context-dependent `meta-resolver` | Updated sre-domain struct |
| binder-open-fn fvar handling unclear | Accept as test: verify fvar treated as concrete value, not meta | Added explicit fvar test in Phase 2 |
| Relation parameter stub premature | Accept: comment instead of dead code. Add parameter in Track 1 with implementation. | Removed Phase 4, added design rationale §3.6 |
| Thin wrappers may be unnecessary | Accept as pre-step: grep call sites before deciding | Added pre-step to Phase 2 |
| ctor-desc getting heavy (9 fields) | Noted: monitor for god-struct, consider factoring in future | Design note added |
| Missing negative tests | Accept: added to Phase 1 test strategy | Added 3 negative test cases |
| Monotonicity runtime assertion | Accept for debug mode: idempotency check after merge | Added to structural-relate propagator |
| Post-decompose-hook threshold (lower to 2) | Push back: mult bridge is Layer 2 caller concern, not SRE hook. Session duality same. Keep monitoring at 3. | No change, rationale documented |
| Concurrency tests | Defer: sequential scheduling currently. Note for BSP-LE Track 4. | No change |

## 13. Source Documents

| Document | Relationship |
|----------|-------------|
| [SRE Research](../research/2026-03-22_STRUCTURAL_REASONING_ENGINE.md) | Founding insight + structural relation expansion |
| [NTT Syntax Design](2026-03-22_NTT_SYNTAX_DESIGN.md) | Type theory informing the design (`:lattice :structural`) |
| [NTT Case Studies](2026-03-22_NTT_CASE_STUDIES.md) | Validated SRE concept across 6 systems |
| [Categorical Foundations](../research/2026-03-22_CATEGORICAL_FOUNDATIONS_TYPED_PROPAGATOR_NETWORKS.md) | Polynomial functor grounding |
| [PUnify Parts 1-2 PIR](2026-03-19_PUNIFY_PARTS1_2_PIR.md) | Prior art: cell-tree unification |
| [PM Track 8 PIR](2026-03-22_TRACK8_PIR.md) | Completeness violation that motivated SRE |
| [Unified Infrastructure Roadmap](2026-03-22_PM_UNIFIED_INFRASTRUCTURE_ROADMAP.md) | On/off-network boundary analysis |
