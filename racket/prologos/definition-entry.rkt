#lang racket/base

;;;
;;; definition-entry.rkt — STRUCTURAL lattice for per-name definition entries
;;;
;;; PPN 4C Addendum Phase 4A.a (Q3 / §18.15.5 of 2026-04-21_PPN_4C_PHASE_9_DESIGN.md).
;;;
;;; A per-name definition cell's value decomposes into :type + :value
;;; sub-components — the SRE STRUCTURAL classification of DefinitionEntry.
;;; This is "the lattice of definition entries" (type × value), parallel to
;;; type-lattice.rkt being "the lattice of types": it sits ABOVE type-lattice
;;; (requires type-unify-or-top for the :type sub-component merge).
;;;
;;; LAYERING (why this is a dedicated leaf module, M1 (γ) — falsification record
;;; at design §18.16.5.M1): namespace.rkt is a LOW-level module (it feeds
;;; ns-context? to reduction/zonk/substitution). type-lattice.rkt sits ABOVE that
;;; pipeline. So namespace.rkt CANNOT require type-lattice.rkt (layering cycle).
;;; def-entry-merge needs type-unify-or-top → it lives here, above type-lattice,
;;; required by phase1d-registrations.rkt (registration) and (at 4A.b) global-env.rkt.
;;; Matches the F14 "two-layer module split for cycle-breaking" precedent
;;; (DEVELOPMENT_LESSONS § 6.8; tropical-fuel-primitives.rkt leaf).
;;;
;;; Three constructors (NTT model §18.15.6):
;;;   def-bot                — no information (fresh cell)
;;;   (def-entry type value) — type + value sub-components
;;;   def-collision          — contradiction (⊤): type-incompatible OR double-write
;;;
;;; STRUCTURAL realization follows the attribute-map-merge-fn precedent
;;; (typing-propagators.rkt:440): ONE merge function with internal per-component
;;; dispatch (NOT sre-decompose-generic sub-cell allocation). The "sub-cells"
;;; framing is conceptual — type/value are sub-components merged pointwise.
;;;
;;; REGISTRATION-ONLY at 4A.a (Q3 LOCKED): no cell uses def-entry-merge yet
;;; (writes/reads stay on the legacy (cons type value) shape until 4A.b's
;;; read-flip). The merge is COMPLETE here so 4A.b doesn't revisit semantics.
;;; This subsumes global-env-add-type-only as a separate API — "type known
;;; before value" is structural: write (def-entry type #f); value stays at
;;; #f-bot until committed.

(require (only-in "type-lattice.rkt"  ;; :type sub-component merge (Role B equality-enforce)
                  type-unify-or-top type-top?))

(provide (struct-out def-entry)
         def-bot
         def-collision
         def-entry-merge)

;; ========================================
;; Sentinels (symbol convention, matching type-bot/'type-bot, 'infra-bot)
;; ========================================

(define def-bot 'def-bot)
(define def-collision 'def-collision)

(struct def-entry (type value) #:transparent)

;; ========================================
;; :value sub-component merge — strict set-once
;; ========================================
;; Q3 §18.15.5 (PM Track 7 PIR §12 precedent). #f is the "value pending"
;; marker (recursive defs: type registered first, value committed after
;; body-check) — matches the existing (cons type #f) convention from
;; global-env-add-type-only. #f is NEVER a legitimate value (values are
;; elaborated exprs, never raw Racket #f).
;;   #f + v     → v          (bot → take new; recursive-def value commit)
;;   v + #f     → v          (keep known value)
;;   v + v      → v          (idempotent)
;;   v1 + v2≠   → collision   (double-write with inconsistency: CAUGHT, not absorbed)
(define (def-value-set-once old-v new-v)
  (cond
    [(eq? old-v #f) new-v]
    [(eq? new-v #f) old-v]
    [(equal? old-v new-v) old-v]
    [else 'value-collision]))

;; ========================================
;; def-entry-merge — STRUCTURAL per-component merge
;; ========================================
;; Handles 'infra-bot (universal fresh-cell sentinel — convention shared by all
;; infra-cell merges, e.g. merge-hasheq-identity at infra-cell.rkt:121) AND
;; def-bot (domain bot). def-collision absorbs (⊤). Both def-entry → merge :type
;; via type-unify-or-top, :value via set-once; either sub-component contradiction
;; (type-top / value-collision) → def-collision. Non-conforming shapes error
;; loudly (Correct-by-Construction: surface migration bugs at 4A.b, don't absorb).
(define (def-entry-merge old new)
  (cond
    [(or (eq? old def-bot) (eq? old 'infra-bot)) new]
    [(or (eq? new def-bot) (eq? new 'infra-bot)) old]
    [(eq? old def-collision) old]
    [(eq? new def-collision) new]
    [(and (def-entry? old) (def-entry? new))
     (define mt (type-unify-or-top (def-entry-type old) (def-entry-type new)))
     (define mv (def-value-set-once (def-entry-value old) (def-entry-value new)))
     (if (or (type-top? mt) (eq? mv 'value-collision))
         def-collision
         (def-entry mt mv))]
    [else
     (error 'def-entry-merge
            "unexpected value shape (expected def-bot / def-entry / def-collision / infra-bot): ~v vs ~v"
            old new)]))
