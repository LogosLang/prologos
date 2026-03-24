#lang racket/base

;; ========================================================================
;; SRE Core — Domain-Parameterized Structural Reasoning Engine
;; ========================================================================
;;
;; Extracted from elaborator-network.rkt (PUnify structural decomposition).
;; Parameterized by sre-domain (lattice ops bundled as first-class data).
;;
;; This module is the operational semantics of NTT's `:lattice :structural`.
;; Every function here is domain-neutral: the domain-specific behavior comes
;; from the sre-domain struct and the ctor-desc registry.
;;
;; SRE Track 0: Form Registry — Domain-Parameterized Structural Decomposition
;; Design: docs/tracking/2026-03-22_SRE_TRACK0_FORM_REGISTRY_DESIGN.md
;;
;; Layer 1 (within-domain) only. Cross-domain bridging (Layer 2: Galois
;; connections) is the caller's responsibility. See design §4.3.

(require "propagator.rkt"
         "ctor-registry.rkt")

(provide
 ;; Domain spec
 (struct-out sre-domain)

 ;; Relation spec (SRE Track 1)
 (struct-out sre-relation)
 sre-equality
 sre-subtype
 sre-subtype-reverse
 sre-duality
 sre-phantom

 ;; Core SRE functions
 sre-identify-sub-cell
 sre-get-or-create-sub-cells
 sre-constructor-tag
 sre-make-structural-relate-propagator
 sre-maybe-decompose
 sre-decompose-generic
 sre-make-generic-reconstructor

 ;; Polarity inference (SRE Track 1)
 variance-join
 variance-flip

 ;; Debug parameter
 current-sre-debug?)

;; ========================================================================
;; Domain Spec
;; ========================================================================
;;
;; A domain spec bundles the lattice operations needed for structural
;; reasoning in a particular domain. It's a first-class data value —
;; not a set of callbacks scattered across Racket parameters.
;;
;; Design note (D.2 critique): meta-recognizer is PURE — safe to cache,
;; no ambient state. meta-resolver is CONTEXT-DEPENDENT — it reads from
;; the current elab-network (type domain) or narrowing context (term domain).
;; The domain spec is created per-command, so the resolver closure always
;; reads from the correct context.
;;
;; Design note: The lattice ordering is NOT a separate field because
;; merge IS the ordering for join-semilattices (a ≤ b iff merge(a,b) = b).
;; Subtyping variance (SRE Track 1) uses per-component annotations on
;; ctor-desc, not a domain-level ordering function.
;;
;; Design note: Domain identity is by name symbol. Two domains that
;; share a lattice are treated as separate — their cells don't interact
;; without a bridge. This is a deliberate isolation choice.

(struct sre-domain
  (name              ; symbol: 'type, 'term, 'session, ...
   lattice-merge     ; (old new → merged) — the lattice join
   contradicts?      ; (val → bool) — is this value top/contradiction?
   bot?              ; (val → bool) — is this value bottom?
   bot-value         ; the bottom element itself
   meta-recognizer   ; (expr → bool) | #f — pure structural check: is this a meta/var ref?
   meta-resolver     ; (expr → cell-id | #f) | #f — context-dependent: what cell?
   dual-pairs        ; SRE Track 1: '((Send . Recv) (Choice . Offer) ...) or #f
                     ; Constructor pairing for duality relation. #f = domain doesn't
                     ; support duality. Derivation assumption: same-domain components
                     ; are continuations (get duality), cross-domain get equality.
   subtype-merge     ; SRE Track 1: (a b → merged) | #f — lattice merge for subtype ordering.
                     ; Returns the join in the subtype ordering:
                     ;   merge(a, b) = b if a <: b, = a if b <: a, = top if incomparable.
                     ; This is a proper lattice merge (monotone, commutative, associative,
                     ; idempotent). The subtype propagator uses this instead of lattice-merge
                     ; to keep subtyping fully on-network — no off-network predicate escape hatch.
                     ; #f = domain doesn't support subtyping.
   )
  #:transparent)

;; Debug mode: enables idempotency assertions (D.2 critique)
(define current-sre-debug? (make-parameter #f))

;; ========================================================================
;; Polarity Inference (SRE Track 1)
;; ========================================================================
;;
;; Infer variance annotations for type parameters from constructor field
;; positions. Uses iterative fixpoint on the 4-element lattice {ø, +, -, =}.
;;
;; Polarity rules:
;; - Direct occurrence of param → covariant (+)
;; - Occurrence in contravariant position (e.g., Pi domain) → contravariant (-)
;; - Occurrence in both positions → invariant (=)
;; - No occurrence → phantom (ø)
;;
;; Fixpoint handles recursive types: `data List A := nil | cons A (List A)`
;; - Start with ø for all params
;; - Propagate polarity through fields (including recursive occurrences)
;; - Converge in 2-3 iterations on the finite lattice
;;
;; Known limitations:
;; - HKT parameters treated as invariant (safe default)
;; - GADTs: out of scope (would need equational constraint analysis)
;; - Mutual recursion: needs simultaneous iteration over all types in group

;; Join two variance values: polarity lattice join
(define (variance-join a b)
  (cond
    [(eq? a b) a]
    [(eq? a 'ø) b]
    [(eq? b 'ø) a]
    [else '=]))  ;; + and - join to = (invariant)

;; Flip polarity (for contravariant positions)
(define (variance-flip v)
  (case v
    [(+) '-]
    [(-) '+]
    [(=) '=]
    [(ø) 'ø]))

;; ========================================================================
;; SRE Relation (Track 1)
;; ========================================================================
;;
;; A first-class structural relation. Parameterizes how the SRE propagates
;; between cell pairs.
;;
;; Semantic distinction (D.4 clarification):
;; - Equality and duality are INFORMATION PROPAGATORS: they write new values
;;   into cells, moving them up the lattice.
;; - Subtyping is a STRUCTURAL CHECKER via propagation infrastructure: it
;;   fires when cells are ground, verifies the relationship, and signals
;;   contradiction on failure. Does NOT write new information.
;;
;; name:            symbol — 'equality, 'subtype, 'subtype-reverse, 'duality, 'phantom
;; sub-relation-fn: (relation ctor-desc component-index domain → relation)
;;   Given the parent relation, the constructor descriptor, the component
;;   index, and the domain, returns the sub-cell relation for that component.
;;   For equality: always equality.
;;   For subtyping: uses component-variances from ctor-desc.
;;   For duality: uses component-lattices (same-domain → duality, cross → equality).

(struct sre-relation
  (name
   sub-relation-fn)
  #:transparent)

;; --- Built-in relations ---

;; Equality: symmetric merge. Sub-relation is always equality.
(define sre-equality
  (sre-relation
   'equality
   (λ (rel desc idx domain-name) sre-equality)))

;; Subtype: directional check a ≤ b. Sub-relation from variance.
(define sre-subtype
  (sre-relation
   'subtype
   (λ (rel desc idx domain-name)
     (define variances (ctor-desc-component-variances desc))
     (if (not variances)
         sre-equality  ;; no variance info → treat as invariant
         (case (list-ref variances idx)
           [(+) sre-subtype]          ;; covariant: same direction
           [(-) sre-subtype-reverse]  ;; contravariant: flip
           [(=) sre-equality]         ;; invariant: equality
           [(ø) sre-phantom])))))     ;; phantom: no constraint

;; Subtype-reverse: flipped direction (b ≤ a instead of a ≤ b).
;; Used for contravariant positions under subtyping.
(define sre-subtype-reverse
  (sre-relation
   'subtype-reverse
   (λ (rel desc idx domain-name)
     (define variances (ctor-desc-component-variances desc))
     (if (not variances)
         sre-equality
         (case (list-ref variances idx)
           [(+) sre-subtype-reverse]  ;; covariant: same direction (still reversed)
           [(-) sre-subtype]          ;; contravariant: flip back to normal
           [(=) sre-equality]
           [(ø) sre-phantom])))))

;; Duality: constructor pairing with involution. Sub-relation derived
;; from component lattice type (same domain → duality, cross → equality).
;; Assumption: same-domain components are continuations.
;; See design §2.5 for documented fragility and mitigation.
;; Duality: constructor pairing with involution. Sub-relation derived
;; from component lattice type (same domain → duality, cross → equality).
;; Assumption: same-domain components are continuations.
;; See design §2.5 for documented fragility and mitigation.
;;
;; The lattice-spec matching uses a helper that checks whether a component's
;; lattice belongs to the same domain. For session constructors:
;;   - payload components have type-lattice-spec ('type sentinel) → cross-domain → equality
;;   - continuation components have session-lattice-spec → same domain → duality
(define sre-duality
  (sre-relation
   'duality
   (λ (rel desc idx domain-name)
     (define lats (ctor-desc-component-lattices desc))
     (define comp-lat (list-ref lats idx))
     ;; Determine if this component's lattice is the same domain
     ;; lattice-spec has no domain tag, so we compare by identity:
     ;; - 'type sentinel → type domain
     ;; - lattice-spec objects are matched by eq? against known domain specs
     ;; For Phase 3, session constructor registration will use a
     ;; session-lattice-spec that's distinct from type-lattice-spec.
     ;; Same-domain = continuation → duality. Cross-domain = payload → equality.
     (define same-domain?
       (cond
         ;; Symbol sentinels: 'type = type domain, 'session = session domain, etc.
         [(symbol? comp-lat) (eq? comp-lat domain-name)]
         ;; lattice-spec structs: compare against domain's known spec
         ;; For now, type-lattice-spec is 'type (a symbol sentinel), so
         ;; any lattice-spec struct is non-type, i.e., could be session/mult/term
         ;; This will be refined in Phase 3 when session domain is registered
         [else #f]))
     (if same-domain?
         sre-duality    ;; same domain: continuation → duality
         sre-equality)  ;; cross-domain: payload → equality
     )))

;; Phantom: no constraint. Used for phantom type parameters.
(define sre-phantom
  (sre-relation
   'phantom
   (λ (rel desc idx domain-name) sre-phantom)))

;; ========================================================================
;; sre-identify-sub-cell
;; ========================================================================
;;
;; Domain-parameterized version of identify-sub-cell.
;; Was: elaborator-network.rkt:317, hardcoded to type domain.
;;
;; Creates or reuses a sub-cell for a decomposed component expression.
;; - Meta/var ref (recognized by domain's meta-recognizer): reuse existing cell
;; - Bot value: fresh bot cell
;; - Concrete value: fresh cell initialized to the expression value

(define (sre-identify-sub-cell net domain expr)
  (define recognizer (sre-domain-meta-recognizer domain))
  (define resolver (sre-domain-meta-resolver domain))
  (define merge (sre-domain-lattice-merge domain))
  (define contradicts? (sre-domain-contradicts? domain))
  (define bot? (sre-domain-bot? domain))
  (define bot-val (sre-domain-bot-value domain))
  (cond
    ;; Meta/var ref → reuse existing cell
    [(and recognizer (recognizer expr))
     (define cid (and resolver (resolver expr)))
     (if cid
         (values net cid)
         ;; Recognized as meta but no cell mapping → fresh bot cell
         (net-new-cell net bot-val merge contradicts?))]
    ;; Bot → fresh bot cell
    [(bot? expr)
     (net-new-cell net bot-val merge contradicts?)]
    ;; Concrete value → fresh cell initialized to value
    [else
     (net-new-cell net expr merge contradicts?)]))

;; ========================================================================
;; sre-get-or-create-sub-cells
;; ========================================================================
;;
;; Domain-parameterized version of get-or-create-sub-cells.
;; Was: elaborator-network.rkt:338, called identify-sub-cell (type-only).
;;
;; Checks decomp registry first — if cell already decomposed, reuse sub-cells.
;; Otherwise, create sub-cells for each component and register.
;; Returns (values net* sub-cell-ids).

(define (sre-get-or-create-sub-cells net domain cell-id tag components)
  (define existing (net-cell-decomp-lookup net cell-id))
  (cond
    [(not (eq? existing 'none))
     ;; Already decomposed — reuse existing sub-cells
     (values net (cdr existing))]
    [else
     ;; Create sub-cells for each component
     (define-values (net* sub-ids-rev)
       (for/fold ([n net] [ids '()])
                 ([comp (in-list components)])
         (define-values (n* cid) (sre-identify-sub-cell n domain comp))
         (values n* (cons cid ids))))
     (define sub-ids (reverse sub-ids-rev))
     ;; Register in decomp registry
     (define net** (net-cell-decomp-insert net* cell-id tag sub-ids))
     (values net** sub-ids)]))

;; ========================================================================
;; sre-constructor-tag
;; ========================================================================
;;
;; Domain-parameterized version of type-constructor-tag.
;; Was: elaborator-network.rkt:302, hardcoded domain='type.
;;
;; Returns the constructor tag for a compound value, or #f for atoms/bot/top.

(define (sre-constructor-tag domain expr)
  (define bot? (sre-domain-bot? domain))
  (define contradicts? (sre-domain-contradicts? domain))
  (cond
    [(bot? expr) #f]
    [(contradicts? expr) #f]
    [else
     (define desc (ctor-tag-for-value expr))
     (and desc
          (eq? (ctor-desc-domain desc) (sre-domain-name domain))
          (ctor-desc-tag desc))]))

;; ========================================================================
;; sre-make-generic-reconstructor
;; ========================================================================
;;
;; Domain-parameterized version of make-generic-reconstructor.
;; Was: elaborator-network.rkt:788, hardcoded type-bot?/type-top?.
;;
;; Reads sub-cells, reconstructs parent. If any sub-cell is bot, waits.
;; If any sub-cell is contradiction, propagates to parent.

(define (sre-make-generic-reconstructor domain parent-cell sub-cells desc)
  (define bot? (sre-domain-bot? domain))
  (define contradicts? (sre-domain-contradicts? domain))
  (lambda (net)
    (define vals (map (λ (sc) (net-cell-read net sc)) sub-cells))
    (cond
      [(ormap bot? vals) net]  ;; wait for more info
      [(ormap contradicts? vals)
       ;; Propagate contradiction to parent
       ;; Use the first contradicted value as the contradiction signal
       (define top-val (findf contradicts? vals))
       (net-cell-write net parent-cell top-val)]
      [else
       (net-cell-write net parent-cell
                       ((ctor-desc-reconstruct-fn desc) vals))])))

;; ========================================================================
;; sre-decompose-generic
;; ========================================================================
;;
;; Domain-parameterized version of decompose-generic.
;; Was: elaborator-network.rkt:803, already mostly generic.
;;
;; Descriptor-driven structural decomposition for binder-depth=0 constructors.
;; Extracts components from both sides, creates sub-cells, adds
;; structural-relate propagators between corresponding sub-cells,
;; adds reconstructors for each side.

(define (sre-decompose-generic net domain cell-a cell-b va vb unified pair-key desc
                                #:relation [relation sre-equality])
  (define tag (ctor-desc-tag desc))
  (define recog (ctor-desc-recognizer-fn desc))
  (define extract (ctor-desc-extract-fn desc))
  (define domain-name (sre-domain-name domain))
  ;; Per-side sources: use original value if it matches, else unified
  (define src-a (if (recog va) va unified))
  (define src-b (if (recog vb) vb unified))
  ;; Extract components
  (define comps-a (extract src-a))
  (define comps-b (extract src-b))
  ;; Get or create sub-cells for each side
  (define-values (net1 subs-a) (sre-get-or-create-sub-cells net domain cell-a tag comps-a))
  (define-values (net2 subs-b) (sre-get-or-create-sub-cells net1 domain cell-b tag comps-b))
  ;; Add structural-relate propagators for each component pair
  ;; SRE Track 1: sub-cell relation derived via relation's sub-relation-fn
  (define sub-rel-fn (sre-relation-sub-relation-fn relation))
  (define net3
    (for/fold ([n net2])
              ([sa (in-list subs-a)]
               [sb (in-list subs-b)]
               [idx (in-naturals)])
      (if (equal? sa sb)
          n
          (let* ([sub-rel (sub-rel-fn relation desc idx domain-name)]
                 [_ (void)]  ;; phantom relation → skip entirely
                 )
            (if (eq? (sre-relation-name sub-rel) 'phantom)
                n  ;; no constraint for phantom components
                (let-values ([(n* _pid)
                              (net-add-propagator n
                                (list sa sb) (list sa sb)
                                (sre-make-structural-relate-propagator
                                 domain sa sb #:relation sub-rel))])
                  n*))))))
  ;; Add generic reconstructors for each side
  ;; (reconstructors are relation-independent — they always rebuild from sub-cells)
  (define-values (net4 _p1)
    (net-add-propagator net3 subs-a (list cell-a)
      (sre-make-generic-reconstructor domain cell-a subs-a desc)))
  (define-values (net5 _p2)
    (net-add-propagator net4 subs-b (list cell-b)
      (sre-make-generic-reconstructor domain cell-b subs-b desc)))
  ;; Register pair as decomposed
  (net-pair-decomp-insert net5 pair-key))

;; ========================================================================
;; sre-maybe-decompose
;; ========================================================================
;;
;; Domain-parameterized version of maybe-decompose.
;; Was: elaborator-network.rkt:842, hardcoded Pi/Sigma/lam case arms.
;;
;; Dispatches structural decomposition based on constructor tag.
;; All constructors go through the descriptor — no hardcoded case arms.
;; Binder-depth>0 constructors require binder-open-fn on their descriptor.
;;
;; NOTE: For Phase 2 migration, Pi/Sigma/lam retain their existing
;; decomposers temporarily (called from the PUnify dispatch layer,
;; not from the SRE). Once binder-open-fn is fully wired, they can
;; be migrated to sre-decompose-binder. See design §4.3.

(define (sre-maybe-decompose net domain cell-a cell-b va vb unified
                             #:relation [relation sre-equality])
  (define tag (sre-constructor-tag domain unified))
  (cond
    [(not tag) net]  ;; Not compound — nothing to decompose
    [else
     ;; SRE Track 1: decomp key includes relation name so equality and
     ;; subtype decompositions don't collide in the cache.
     (define rel-name (sre-relation-name relation))
     (define pair-key (decomp-key cell-a cell-b rel-name))
     (cond
       [(net-pair-decomp? net pair-key) net]  ;; Already decomposed
       [else
        (define desc (lookup-ctor-desc tag #:domain (sre-domain-name domain)))
        (cond
          [(not desc) net]
          ;; Binder-depth=0: generic descriptor-driven decomposition
          [(zero? (ctor-desc-binder-depth desc))
           (sre-decompose-generic net domain cell-a cell-b va vb unified pair-key desc
                                  #:relation relation)]
          ;; Binder-depth>0: not handled by SRE core yet.
          ;; Callers (PUnify dispatch) handle Pi/Sigma/lam binders directly.
          ;; Future: sre-decompose-binder using ctor-desc binder-open-fn.
          [else net])])]))

;; ========================================================================
;; sre-make-structural-relate-propagator
;; ========================================================================
;;
;; Domain-parameterized, relation-parameterized structural relate propagator.
;; Was: elaborator-network.rkt:871, hardcoded to type lattice + equality.
;;
;; SRE Track 1: dispatches on relation type:
;; - Equality: reads two cells, merges to join, writes both, decomposes.
;;   This is INFORMATION PROPAGATION — cells move up the lattice.
;; - Subtype: reads two cells, checks a ≤ b, decomposes with variance.
;;   This is STRUCTURAL CHECKING — no writes except contradiction.
;; - Duality: reads two cells, applies dual constructor pairing.
;;   This is INFORMATION PROPAGATION with constructor swapping.
;; - Phantom: no-op (for phantom type parameters).
;;
;; Termination argument:
;; - Equality: decomp registries + lattice-merge monotonicity + no-change guard.
;; - Subtype: no cell writes on success; only contradiction signals (monotone).
;;   Decomposition creates sub-checkers that are strictly smaller.
;; - Duality: involution preserves lattice ordering; no-change guard.
;; Guarantee level: 2 (finite lattice height with fuel guard)

(define (sre-make-structural-relate-propagator domain cell-a cell-b
                                                #:relation [relation sre-equality])
  (define rel-name (sre-relation-name relation))
  (case rel-name
    [(equality) (sre-make-equality-propagator domain cell-a cell-b relation)]
    [(subtype subtype-reverse) (sre-make-subtype-propagator domain cell-a cell-b relation)]
    [(duality) (sre-make-duality-propagator domain cell-a cell-b relation)]
    [(phantom) (lambda (net) net)]  ;; no constraint
    [else (error 'sre-make-structural-relate-propagator
                 "unknown relation: ~a" rel-name)]))

;; --- Equality propagator (Track 0 behavior, unchanged) ---
(define (sre-make-equality-propagator domain cell-a cell-b relation)
  (define merge (sre-domain-lattice-merge domain))
  (define contradicts? (sre-domain-contradicts? domain))
  (define bot? (sre-domain-bot? domain))
  (lambda (net)
    (define va (net-cell-read net cell-a))
    (define vb (net-cell-read net cell-b))
    (cond
      [(and (bot? va) (bot? vb)) net]
      [(bot? va)
       (let ([net* (net-cell-write net cell-a vb)])
         (sre-maybe-decompose net* domain cell-a cell-b va vb vb
                              #:relation relation))]
      [(bot? vb)
       (let ([net* (net-cell-write net cell-b va)])
         (sre-maybe-decompose net* domain cell-a cell-b va vb va
                              #:relation relation))]
      [else
       (define unified (merge va vb))
       (when (current-sre-debug?)
         (unless (equal? (merge unified va) unified)
           (error 'sre-structural-relate
                  "Non-idempotent merge detected for domain ~a: merge(~a, ~a) = ~a but merge(~a, ~a) = ~a"
                  (sre-domain-name domain) va vb unified unified va (merge unified va))))
       (if (contradicts? unified)
           (net-cell-write net cell-a unified)
           (let* ([net*  (net-cell-write net cell-a unified)]
                  [net** (net-cell-write net* cell-b unified)])
             (sre-maybe-decompose net** domain cell-a cell-b va vb unified
                                  #:relation relation)))])))

;; --- Subtype propagator (Track 1: structural checker) ---
;; Checks a ≤ b directionally. Does NOT merge/write cell values.
;; Fires when both cells are non-bot. Decomposes structurally with variance.
;; For subtype-reverse: checks b ≤ a (used for contravariant positions).
;;
;; KEY INSIGHT: The type lattice merge is equality-based (different compound
;; types → top/contradiction). For subtyping, we must decompose structurally
;; BEFORE using the flat lattice check. Strategy:
;; 1. Both compound with same tag? → decompose with variance (structural path)
;; 2. Both atomic? → check flat subtype relationship (flat path)
;; 3. Different tags? → subtype violation
(define (sre-make-subtype-propagator domain cell-a cell-b relation)
  (define contradicts? (sre-domain-contradicts? domain))
  (define bot? (sre-domain-bot? domain))
  (define sub-merge (sre-domain-subtype-merge domain))
  (define reversed? (eq? (sre-relation-name relation) 'subtype-reverse))
  (lambda (net)
    (define va (net-cell-read net cell-a))
    (define vb (net-cell-read net cell-b))
    (cond
      ;; Wait for both cells to have values
      [(or (bot? va) (bot? vb)) net]
      [else
       ;; Direction: check lhs ≤ rhs
       (let* ([lhs (if reversed? vb va)]
              [rhs (if reversed? va vb)]
              [tag-lhs (sre-constructor-tag domain lhs)]
              [tag-rhs (sre-constructor-tag domain rhs)])
         (cond
           ;; Both compound with same tag → structural decomposition with variance
           [(and tag-lhs tag-rhs (eq? tag-lhs tag-rhs))
            (sre-maybe-decompose net domain cell-a cell-b va vb lhs
                                 #:relation relation)]
           ;; At least one atomic, or different compound tags →
           ;; use subtype-merge lattice (proper subtype ordering).
           ;; subtype-merge(a, b) = b if a <: b, = a if b <: a,
           ;; = top if incomparable. This is fully on-network.
           [else
            (if (not sub-merge)
                ;; No subtype-merge → domain doesn't support subtyping.
                ;; Fall back to equality check.
                (let ([eq-merged ((sre-domain-lattice-merge domain) lhs rhs)])
                  (if (contradicts? eq-merged)
                      (net-cell-write net cell-a eq-merged)
                      net))
                ;; Use the subtype-ordering merge
                (let ([merged (sub-merge lhs rhs)])
                  (cond
                    [(contradicts? merged)
                     ;; Incomparable → subtype violation
                     (net-cell-write net cell-a merged)]
                    [(equal? merged rhs)
                     ;; merged = rhs → lhs ≤ rhs holds (lhs joins up to rhs)
                     net]
                    [(equal? merged lhs)
                     ;; merged = lhs → rhs ≤ lhs (wrong direction) → violation
                     ;; Unless lhs = rhs (handled by equal? in sub-merge)
                     (net-cell-write net cell-a
                       ((sre-domain-lattice-merge domain) lhs rhs))]
                    [else
                     ;; merged ≠ either → shouldn't happen for well-formed subtype merge
                     net])))]))])))

;; --- Duality propagator (Track 1: Phase 3 implements) ---
;; Reads cell-a, applies dual constructor pairing, writes to cell-b.
;; Bidirectional: cell-b changes → apply inverse dual → write cell-a.
(define (sre-make-duality-propagator domain cell-a cell-b relation)
  ;; Phase 3 will implement the full duality propagator.
  ;; Error rather than silent equality fallback — equality is stricter than
  ;; duality, so falling back would give silently wrong behavior.
  (error 'sre-make-duality-propagator
         "duality relation not yet implemented (SRE Track 1 Phase 3)"))
