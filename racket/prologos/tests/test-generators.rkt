#lang racket/base

;;; test-generators.rkt — self-validation for the generators in generators.rkt
;;;
;;; These five properties assert that the generators produce well-formed,
;;; type-checkable output — i.e. that a green run of `test-properties.rkt`
;;; means something. They live HERE, not next to the generators, so that
;;; requiring the generators has no test side effects; see generators.rkt's
;;; header for what that used to cost.

(require rackunit
         rackcheck
         racket/match
         "../prelude.rkt"
         "../syntax.rkt"
         "../metavar-store.rkt"
         "../reduction.rkt"
         "../unify.rkt"
         "../global-env.rkt"
         (prefix-in tc: "../typing-core.rkt")
         "../performance-counters.rkt"
         "../driver.rkt"
         "generators.rkt")

;; ============================================================
;; Generator self-validation tests
;; ============================================================

(test-case "gen: base types are valid types"
  (check-property
   (make-config #:tests 50)
   (property ([ty (gen:prologos-type-depth 0)])
     (with-fresh-tc-env
       (check-true (or (expr-Nat? ty) (expr-Bool? ty) (expr-Unit? ty)))))))

(test-case "gen: compound types up to depth 2"
  (check-property
   (make-config #:tests 50)
   (property ([ty gen:prologos-type])
     ;; Should be one of the known type constructors
     (check-true (or (expr-Nat? ty) (expr-Bool? ty) (expr-Unit? ty)
                     (expr-Pi? ty) (expr-Sigma? ty))))))

(test-case "gen: Nat terms type-check"
  (check-property
   (make-config #:tests 30)
   (property ([n (gen:integer-in 0 8)])
     (with-fresh-tc-env
       (define term
         (let loop ([n n])
           (if (zero? n) (expr-zero) (expr-suc (loop (sub1 n))))))
       (define inferred (tc:infer ctx-empty term))
       (check-true (expr-Nat? inferred)
                   (format "Expected Nat, got ~a for ~a" inferred term))))))

(test-case "gen: Bool terms type-check"
  (check-property
   (make-config #:tests 20)
   (property ([b gen:boolean])
     (with-fresh-tc-env
       (define term (if b (expr-true) (expr-false)))
       (define inferred (tc:infer ctx-empty term))
       (check-true (expr-Bool? inferred))))))

(test-case "gen: well-typed programs pass type-check"
  (check-property
   (make-config #:tests 30)
   (property ([prog gen:well-typed-program])
     (with-fresh-tc-env
       (define term (car prog))
       (define type (cdr prog))
       ;; Should type-check without error
       (define result (tc:check ctx-empty term type))
       (check-true result
                   (format "Failed: ~a should check against ~a" term type))))))
