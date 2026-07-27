#lang racket/base

;;;
;;; definition-entry.rkt — STRUCTURAL value shape for per-name definition cells
;;;
;;; PPN 4C Addendum Phase 4A.a (Q3 / §18.15.5) introduced this; Phase 4A.b-ii
;;; (§18.17.10) DEPLOYS it as the per-name definition cell value and revises the
;;; merge to LAST-WRITE-WINS (see "Merge semantics" below).
;;;
;;; A per-name definition cell's value decomposes into :type + :value
;;; sub-components — the SRE STRUCTURAL classification of DefinitionEntry
;;; ("the lattice of definition entries", type × value). The STRUCTURAL win is
;;; facet-addressability: a propagator can read / declare :component-paths on a
;;; single facet (e.g. trait resolution reading :type, reduction reading :value)
;;; — aligned with the AttributeRecord/facet design (D.3 §6.11) + First-Class-
;;; by-Default. The cell holds a def-entry; namespace.rkt's mnr API wraps
;;; (cons type value) → def-entry on WRITE and unwraps def-entry → (cons type
;;; value) on READ (the 4A.b-ii ADAPTER, both directions) — so def-entry is
;;; fully ENCAPSULATED within the mnr API and downstream consumers are unchanged
;;; (audit-verified 0 production ripple, §18.17.10).
;;;
;;; PURE LEAF (4A.b-ii): requires only racket/base. (4A.a required type-lattice
;;; for the set-once :type merge's type-unify-or-top; under LWW the :type is
;;; new-wins, so the require is DROPPED — which also lets namespace.rkt require
;;; THIS module directly, where 4A.a's M1 (γ) noted namespace→type-lattice would
;;; cycle. If a future language-design decision restores set-once + type-unify
;;; — see "Merge semantics" — the type-lattice require returns and the
;;; namespace-layering cycle must be handled then.)
;;;
;;; Three constructors:
;;;   def-bot                — no information (fresh cell)
;;;   (def-entry type value) — type + value sub-components
;;;   def-collision          — contradiction (⊤): KEPT but UNREACHABLE under the
;;;                            current last-write-wins merge (see below).

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
;; Merge semantics — LAST-WRITE-WINS (PPN 4C Addendum 4A.b-ii / §18.17.10)
;; ========================================
;; Re-definitions are LEGAL by current language-design intent (user, 2026-06-01;
;; whether that is correct at the language-design level is a separate, OPEN
;; discussion). The merge sees only old+new values — it cannot distinguish a
;; legal user redefinition from an internal double-write — so it is LAST-WRITE-
;; WINS, NOT set-once. This matches the pre-4A.b-ii merge-replace semantics on
;; the (cons type value) shape; the def-entry migration is a behavior-preserving
;; REPRESENTATION change (probe-diff = 0) deploying the STRUCTURAL value shape.
;;
;; This merge is NON-MONOTONE (replace), like the merge-replace it succeeds —
;; the STRUCTURAL win is the value SHAPE (facet-addressability), not a monotone
;; join.
;;
;; FORWARD-COMPAT: def-collision (⊤) + the #:contradicts? registration
;; (phase1d-registrations.rkt) are KEPT but UNREACHABLE under LWW. If the open
;; language-design discussion later makes redefinition an error (or requires
;; catching internal double-writes), restore SET-ONCE on :value + type-unify-or-
;; top on :type (re-adding the type-lattice require + handling the namespace
;; cycle) — ONLY this merge changes; the constructors + registration already
;; support it.

;; :value — new wins, UNLESS new is #f. #f is the "value pending" marker
;;   (recursive defs: type registered first via (def-entry type #f), value
;;   committed after body-check; whnf treats #f as stuck — reduction.rkt:3017).
;;   #f is NEVER a legitimate value (values are elaborated exprs, never raw #f).
;;     #f new → keep old   (a type-only re-register doesn't clobber a committed value)
;;     v  new → v          (commit / redefinition: new wins)
(define (def-value-lww old-v new-v)
  (if (eq? new-v #f) old-v new-v))

;; def-entry-merge — STRUCTURAL per-component LWW.
;; Handles 'infra-bot (universal fresh-cell sentinel) + def-bot (domain bot):
;; either → take the other. :type new-wins; :value via def-value-lww.
;; def-collision absorbs (forward-compat; unreachable under LWW). Non-conforming
;; shapes error loudly (Correct-by-Construction: surface migration bugs, don't
;; absorb).
(define (def-entry-merge old new)
  (cond
    [(or (eq? old def-bot) (eq? old 'infra-bot)) new]
    [(or (eq? new def-bot) (eq? new 'infra-bot)) old]
    [(eq? old def-collision) old]    ;; forward-compat (unreachable under LWW)
    [(eq? new def-collision) new]    ;; forward-compat (unreachable under LWW)
    [(and (def-entry? old) (def-entry? new))
     ;; LWW (legal redefinition): new type wins; new value wins unless pending (#f).
     (def-entry (def-entry-type new)
                (def-value-lww (def-entry-value old) (def-entry-value new)))]
    [else
     (error 'def-entry-merge
            "unexpected value shape (expected def-bot / def-entry / def-collision / infra-bot): ~v vs ~v"
            old new)]))
