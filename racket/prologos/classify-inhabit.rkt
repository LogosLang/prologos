#lang racket/base

;;;
;;; classify-inhabit.rkt — PPN 4C Phase 3a+3b infrastructure
;;;
;;; The `:type`/`:term` facet split per D.3 §6.1 + §6.15.
;;;
;;; Module Theory Realization B: one carrier (the SRE 2H TypeFacet
;;; quantale) with two tag-layers — CLASSIFIER (the type a position
;;; MUST have) and INHABITANT (the specific value solving it). User-
;;; visible surface preserves `:type` (reads CLASSIFIER) and `:term`
;;; (reads INHABITANT) via 3c shims; this module provides the
;;; tag-layer value shape + tag-dispatched accumulation merge.
;;;
;;; S1 resolution (per §6.15.1): reading (i) — TermFacet IS the
;;; SRE 2H quantale; tags are role-markers over ONE carrier lattice,
;;; not distinct lattices.
;;;
;;; P4 resolution (per §6.15.2): merge stays pure `(v × v → v)`. The
;;; cross-tag residuation check (inhabitant inhabits classifier?) is
;;; NOT in this module's merge — it's a dedicated propagator (3c
;;; scope) that watches cells where both tag layers are populated.
;;; This module's merge ACCUMULATES tag layers purely; no side
;;; effects on cross-tag writes.
;;;
;;; Phase 9 coherence (per §6.15.6): the worldview assumption-id tag
;;; is a SEPARATE dimension (Phase 9 `tagged-cell-value`) orthogonal
;;; to CLASSIFIER/INHABITANT. Both tag dimensions coexist without
;;; coupling this module to Phase 9.
;;;

(require (only-in "type-lattice.rkt" type-lattice-merge type-unify-or-top type-bot type-bot? type-top type-top?)
         (only-in "sre-core.rkt" make-sre-domain register-domain!)
         (only-in "merge-fn-registry.rkt" register-merge-fn!/lattice))

(provide
 ;; Tag-layer value shape
 (struct-out classify-inhabit-value)
 classify-inhabit-value-bot?
 ;; Construction helpers
 classifier-only        ;; type-val → classify-inhabit-value
 inhabitant-only        ;; term-val → classify-inhabit-value
 classify-and-inhabit   ;; type-val × term-val → classify-inhabit-value
 ;; Accessors (surface `:type` / `:term` read semantics)
 classify-inhabit-value-classifier-or-bot
 classify-inhabit-value-inhabitant-or-bot
 ;; Contradiction sentinel
 classify-inhabit-contradiction?
 ;; Merge
 merge-classify-inhabit)

;; ========================================
;; Tag-layer value shape
;; ========================================
;;
;; classifier: type-value (quantale element) or 'bot (layer empty)
;; inhabitant: term-value (quantale element, possibly a more-specific
;;             expression) or 'bot (layer empty)
;;
;; Invariants:
;;   - Both fields 'bot → the empty record (per-position bot state)
;;   - Classifier populated, inhabitant 'bot → this is a "type-only"
;;     position (we know what type it must have, but not yet its
;;     specific value)
;;   - Inhabitant populated, classifier 'bot → rare (inhabitant-only;
;;     typically paired with a classifier after a few BSP rounds)
;;   - Both populated → the residuation check can fire (3c scope)

(struct classify-inhabit-value (classifier inhabitant) #:transparent)

;; Bot check: both layers empty (represents the per-position "unknown"
;; state at initialization).
(define (classify-inhabit-value-bot? v)
  (and (classify-inhabit-value? v)
       (eq? (classify-inhabit-value-classifier v) 'bot)
       (eq? (classify-inhabit-value-inhabitant v) 'bot)))

;; ========================================
;; Construction helpers
;; ========================================

(define (classifier-only type-val)
  (classify-inhabit-value type-val 'bot))

(define (inhabitant-only term-val)
  (classify-inhabit-value 'bot term-val))

(define (classify-and-inhabit type-val term-val)
  (classify-inhabit-value type-val term-val))

;; ========================================
;; Accessors (surface `:type` / `:term` semantics)
;; ========================================

;; Returns the classifier layer's value, or 'bot if unpopulated.
(define (classify-inhabit-value-classifier-or-bot v)
  (if (classify-inhabit-value? v)
      (classify-inhabit-value-classifier v)
      'bot))

;; Returns the inhabitant layer's value, or 'bot if unpopulated.
(define (classify-inhabit-value-inhabitant-or-bot v)
  (if (classify-inhabit-value? v)
      (classify-inhabit-value-inhabitant v)
      'bot))

;; ========================================
;; Contradiction sentinel
;; ========================================
;;
;; Returned by merge when per-tag merge detects contradiction:
;;   classifier × classifier → type-top via type-lattice-merge
;;     (handled by propagating type-top; not a sentinel at this layer)
;;   inhabitant × inhabitant → non-α-equiv (distinct values, same tag)
;;   cross-tag residuation check: deferred to 3c propagator; this
;;     module's merge does NOT compute it — it only accumulates layers.
;;
;; The sentinel exists so that if 3c's residuation propagator writes
;; a contradiction back to the cell, the merge can recognize it.

(define (classify-inhabit-contradiction? v)
  (eq? v 'classify-inhabit-contradiction))

;; ========================================
;; Merge (pure accumulation, per-tag)
;; ========================================
;;
;; Semantics per D.3 §6.15.2 (P4 resolution):
;;   bot handling: 'infra-bot defers; empty classify-inhabit-value defers
;;   per-tag merge:
;;     classifier × classifier → type-lattice-merge (the quantale's
;;       'equality relation, implemented in type-lattice.rkt)
;;     inhabitant × inhabitant → α-equivalence strict merge; mismatch →
;;       contradiction sentinel
;;     classifier × 'bot → classifier stays
;;     'bot × classifier → classifier stays
;;     (same for inhabitant)
;;   cross-tag (classifier + inhabitant): accumulated into the same
;;     struct; the residuation check is a 3c propagator's job, not
;;     this merge's.
;;
;; PURITY: `(v × v → v)` — no side effects. This is load-bearing
;; (BSP scheduler, speculation, worldview-filter all assume purity).

(define (merge-classify-inhabit v1 v2)
  (cond
    [(eq? v1 'infra-bot) v2]
    [(eq? v2 'infra-bot) v1]
    [(classify-inhabit-contradiction? v1) v1]  ;; top absorbs
    [(classify-inhabit-contradiction? v2) v2]
    [else
     ;; Merge per-tag.
     (define c1 (classify-inhabit-value-classifier v1))
     (define c2 (classify-inhabit-value-classifier v2))
     (define i1 (classify-inhabit-value-inhabitant v1))
     (define i2 (classify-inhabit-value-inhabitant v2))
     ;; Classifier × classifier: equality-enforcement (Role B).
     ;; PPN 4C Path T-3 Commit A.2-c (2026-04-22): migrated from
     ;; type-lattice-merge (Role A accumulate) to type-unify-or-top (Role B
     ;; equality-enforce). Classifier semantics: position has exactly ONE
     ;; expected type; two propagators asserting different classifiers is a
     ;; conflict (→ type-top → classify-inhabit-contradiction), not an
     ;; accumulation (Q5 2026-04-22 confirmed). Under post-T-3 Commit B
     ;; set-union merge, type-lattice-merge would silently produce unions
     ;; for conflicting classifier assertions, losing the contradiction signal
     ;; the check at line 196+ relies on.
     (define merged-classifier
       (cond
         [(eq? c1 'bot) c2]
         [(eq? c2 'bot) c1]
         [else (type-unify-or-top c1 c2)]))
     ;; Inhabitant × inhabitant: α-equivalence strict merge.
     ;; For Phase 3a+3b MVP, use equal? as the α-equivalence proxy;
     ;; 3c can refine to full α-equiv via ctor-desc decomposition.
     (define merged-inhabitant
       (cond
         [(eq? i1 'bot) i2]
         [(eq? i2 'bot) i1]
         [(equal? i1 i2) i1]
         [else 'classify-inhabit-contradiction]))
     (cond
       [(classify-inhabit-contradiction? merged-inhabitant)
        merged-inhabitant]
       ;; If classifier merge produced type-top (contradiction on the
       ;; quantale), propagate as classify-inhabit-contradiction.
       [(and (not (eq? merged-classifier 'bot))
             (type-top? merged-classifier))
        'classify-inhabit-contradiction]
       [else
        (classify-inhabit-value merged-classifier merged-inhabitant)])]))

;; ========================================
;; SRE domain registration (Tier 1 + Tier 2)
;; ========================================
;;
;; Name: 'classify-inhabit (new facet, distinct from legacy `:type`).
;; Classification: 'structural — the carrier holds tag-layered compound;
;; propagators reading it should declare :component-paths (Phase 1f
;; enforcement).
;; Bot value: (classify-inhabit-value 'bot 'bot) — both layers empty.

(define classify-inhabit-bot
  (classify-inhabit-value 'bot 'bot))

(define classify-inhabit-sre-domain
  (make-sre-domain
   #:name 'classify-inhabit
   #:merge-registry (lambda (r)
                      (case r
                        [(equality) merge-classify-inhabit]
                        [else (error 'classify-inhabit-merge
                                     "no merge for relation: ~a" r)]))
   #:contradicts? classify-inhabit-contradiction?
   #:bot? classify-inhabit-value-bot?
   #:bot-value classify-inhabit-bot
   ;; PPN 4C Phase 1f: structural classification. Propagators reading
   ;; classify-inhabit cells must declare :component-paths specifying
   ;; which tag layer (CLASSIFIER / INHABITANT) they watch.
   #:classification 'structural))
(register-domain! classify-inhabit-sre-domain)
(register-merge-fn!/lattice merge-classify-inhabit #:for-domain 'classify-inhabit)
