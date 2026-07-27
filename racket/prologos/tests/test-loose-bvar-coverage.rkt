#lang racket/base
;;;
;;; test-loose-bvar-coverage.rkt — the `shift` short-circuit must never
;;; under-report.
;;;
;;; `shift` (substitution.rkt) short-circuits to a no-op when
;;; `loose-bvar-range e <= cutoff`. That makes an UNDER-report a silent
;;; wrong answer: a node reported as closed when it holds a free bvar keeps
;;; its de Bruijn indices unrenumbered, which is variable capture. An
;;; OVER-report only costs a wasted walk.
;;;
;;; `loose-bvar-range` has explicit arms for the binder forms and falls back
;;; to a generic transparent-struct walk for everything else — the
;;; total-by-construction shape that `.claude/rules/pipeline.md` § Exhaustive
;;; Walkers asks for. That totality is only real if the field-value walker
;;; covers the CONTAINER shapes struct fields actually use.
;;;
;;; It did not. The walker treated every pair as a list cell — walking the
;;; car and recurring on the cdr as a tail — so an ASSOCIATION pair
;;; `(cons key <struct>)` dropped its value. CIU T6's `expr-Record` stores
;;; exactly that (`(list (cons 'a (record-field …)))`), so a record holding a
;;; bvar reported range 0 and `shift` no-op'd on it.
;;;
;;; These tests pin each container shape independently so the next node kind
;;; to use one is covered before it ships, not after.
;;;

(require rackunit
         "../syntax.rkt"
         "../loose-bvar.rkt"
         "../substitution.rkt")

(define (fld e) (record-field e 'present))

;; ========================================
;; Container shapes
;; ========================================

(test-case "bare struct field"
  (check-equal? (loose-bvar-range (fld (expr-bvar 0))) 1)
  (check-equal? (loose-bvar-range (fld (expr-Nat))) 0))

(test-case "proper list field"
  (check-equal? (loose-bvar-range (expr-Record 'keyword '() 'closed)) 0)
  ;; a list of structs (no assoc pairs) — this shape always worked
  (check-equal? (loose-bvar-range (expr-app (expr-fvar 'f) (expr-bvar 2))) 3))

(test-case "ASSOCIATION pair field — the shape that regressed"
  ;; (cons key <struct>): the value hangs off the CDR, not the CAR.
  (check-equal? (loose-bvar-range
                 (expr-Record 'keyword (list (cons 'a (fld (expr-bvar 0)))) 'closed))
                1
                "a record holding bvar 0 is NOT closed")
  (check-equal? (loose-bvar-range
                 (expr-Record 'keyword (list (cons 'a (fld (expr-bvar 3)))) 'closed))
                4
                "range is 1 + the max free index")
  (check-equal? (loose-bvar-range
                 (expr-Record 'keyword
                              (list (cons 'a (fld (expr-Nat)))
                                    (cons 'b (fld (expr-bvar 1))))
                              'closed))
                2
                "a later field's bvar is found too")
  (check-equal? (loose-bvar-range
                 (expr-Record 'keyword (list (cons 'a (fld (expr-Nat)))) 'closed))
                0
                "a genuinely closed record still reports 0 (no over-approximation)"))

;; ========================================
;; The consequence: shift must actually renumber
;; ========================================

(test-case "shift renumbers a bvar inside a record"
  ;; This is the assertion that failed when the range under-reported: shift
  ;; short-circuited and returned the record untouched.
  (define r (expr-Record 'keyword (list (cons 'a (fld (expr-bvar 0)))) 'closed))
  (check-equal? (shift 1 0 r)
                (expr-Record 'keyword (list (cons 'a (fld (expr-bvar 1)))) 'closed)))

(test-case "shift leaves a closed record alone"
  (define r (expr-Record 'keyword (list (cons 'a (fld (expr-Nat)))) 'closed))
  (check-equal? (shift 1 0 r) r))

(test-case "shift respects the cutoff inside a record"
  ;; bvar 0 is BOUND relative to cutoff 1, so it must not move.
  (define r (expr-Record 'keyword (list (cons 'a (fld (expr-bvar 0)))) 'closed))
  (check-equal? (shift 5 1 r) r)
  ;; bvar 2 is free relative to cutoff 1, so it must move.
  (define r2 (expr-Record 'keyword (list (cons 'a (fld (expr-bvar 2)))) 'closed))
  (check-equal? (shift 5 1 r2)
                (expr-Record 'keyword (list (cons 'a (fld (expr-bvar 7)))) 'closed)))

(test-case "a record under a binder shifts at the right depth"
  ;; (lam _ Nat <record holding bvar 1>) — bvar 1 inside the body refers to
  ;; one level OUTSIDE the lambda, so shifting at cutoff 0 moves it.
  (define body (expr-Record 'keyword (list (cons 'a (fld (expr-bvar 1)))) 'closed))
  (define lam (expr-lam 'mw (expr-Nat) body))
  (check-equal? (shift 1 0 lam)
                (expr-lam 'mw (expr-Nat)
                          (expr-Record 'keyword
                                       (list (cons 'a (fld (expr-bvar 2))))
                                       'closed))
                "the record's bvar is renumbered under the binder")
  ;; bvar 0 inside the body IS the lambda's own binding — it must not move.
  (define body0 (expr-Record 'keyword (list (cons 'a (fld (expr-bvar 0)))) 'closed))
  (define lam0 (expr-lam 'mw (expr-Nat) body0))
  (check-equal? (shift 1 0 lam0) lam0
                "the lambda's own binding is untouched"))

;; ========================================
;; The memo must not cache a stale under-report
;; ========================================

(test-case "clearing the cache re-derives the same answer"
  (define r (expr-Record 'keyword (list (cons 'a (fld (expr-bvar 0)))) 'closed))
  (define before (loose-bvar-range r))
  (clear-loose-bvar-cache!)
  (check-equal? (loose-bvar-range r) before
                "range is a pure function of structure, memo or not")
  (check-equal? before 1))
