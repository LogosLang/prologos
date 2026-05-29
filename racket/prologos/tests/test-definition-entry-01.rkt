#lang racket/base

;;;
;;; test-definition-entry-01.rkt — PPN 4C Addendum Phase 4A.a (Q3 §18.15.5)
;;;
;;; Unit tests for the STRUCTURAL DefinitionEntry lattice (definition-entry.rkt):
;;;   def-entry-merge — per-component merge (:type via type-unify-or-top,
;;;   :value via strict set-once); def-bot / def-collision sentinels;
;;;   'infra-bot universal-sentinel handling.
;;;
;;; REGISTRATION-ONLY at 4A.a — these test the merge SEMANTICS directly
;;; (the merge is wired into the 'definition-entry SRE domain but no cell
;;; uses it until 4A.b's read-flip).
;;;

(require rackunit
         "../definition-entry.rkt"
         (only-in "../type-lattice.rkt" type-top))

;; ========================================
;; Bot absorption (def-bot + 'infra-bot universal sentinel)
;; ========================================

(test-case "def-entry-merge: def-bot + entry → entry"
  (check-equal? (def-entry-merge def-bot (def-entry 'Int 42))
                (def-entry 'Int 42)))

(test-case "def-entry-merge: entry + def-bot → entry"
  (check-equal? (def-entry-merge (def-entry 'Int 42) def-bot)
                (def-entry 'Int 42)))

(test-case "def-entry-merge: 'infra-bot + entry → entry (universal sentinel)"
  (check-equal? (def-entry-merge 'infra-bot (def-entry 'Bool #t))
                (def-entry 'Bool #t)))

(test-case "def-entry-merge: entry + 'infra-bot → entry (universal sentinel)"
  (check-equal? (def-entry-merge (def-entry 'Bool #t) 'infra-bot)
                (def-entry 'Bool #t)))

;; ========================================
;; Collision absorption (⊤)
;; ========================================

(test-case "def-entry-merge: def-collision + entry → def-collision (absorbs)"
  (check-equal? (def-entry-merge def-collision (def-entry 'Int 1)) def-collision))

(test-case "def-entry-merge: entry + def-collision → def-collision (absorbs)"
  (check-equal? (def-entry-merge (def-entry 'Int 1) def-collision) def-collision))

;; ========================================
;; :value strict set-once (recursive-def commit + idempotence + collision)
;; ========================================

(test-case "def-entry-merge: type-only then value commit ((t #f) + (t v) → (t v))"
  ;; Recursive-def pattern: type registered first (value=#f), value committed after.
  ;; Subsumes global-env-add-type-only as a separate API.
  (check-equal? (def-entry-merge (def-entry 'Int #f) (def-entry 'Int 42))
                (def-entry 'Int 42)))

(test-case "def-entry-merge: value-bot both sides stays bot ((t #f) + (t #f))"
  (check-equal? (def-entry-merge (def-entry 'Int #f) (def-entry 'Int #f))
                (def-entry 'Int #f)))

(test-case "def-entry-merge: idempotent ((t v) + (t v) → (t v))"
  (check-equal? (def-entry-merge (def-entry 'Int 42) (def-entry 'Int 42))
                (def-entry 'Int 42)))

(test-case "def-entry-merge: value collision (same type, diff value) → def-collision"
  ;; Double-write with inconsistency: CAUGHT (set-once), not silently absorbed.
  (check-equal? (def-entry-merge (def-entry 'Int 1) (def-entry 'Int 2)) def-collision))

;; ========================================
;; :type unify-or-top (type contradiction → def-collision)
;; ========================================

(test-case "def-entry-merge: type contradiction (type-top) → def-collision"
  ;; type-unify-or-top with type-top on one side → type-top → whole entry collides.
  (check-equal? (def-entry-merge (def-entry type-top 1) (def-entry 'Int 1)) def-collision))

(test-case "def-entry-merge: equal types unify to identity (value set-once)"
  ;; type 'Int + 'Int = 'Int (eq? short-circuit); value #f + 7 = 7.
  (check-equal? (def-entry-merge (def-entry 'Int #f) (def-entry 'Int 7))
                (def-entry 'Int 7)))

;; ========================================
;; Non-conforming shape errors loudly (Correct-by-Construction)
;; ========================================

(test-case "def-entry-merge: non-conforming shape errors (surfaces migration bugs)"
  (check-exn exn:fail?
             (lambda () (def-entry-merge (cons 'Int 1) (def-entry 'Int 2)))))
