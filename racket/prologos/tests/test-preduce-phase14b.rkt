#lang racket/base

;;; test-preduce-phase14b.rkt
;;;
;;; Phase 14b: tail-edge ops — numeric coercion (from-int, from-nat),
;;; opaque values (cut, Open). Other tail nodes (broadcast-get, explain,
;;; explain-with, all-different, panic) deferred to Phase 14c.

(require rackunit
         "../syntax.rkt"
         "../preduce.rkt"
         (only-in "../reduction.rkt" nf))

(define (check-preduce/nf e expected)
  (define got-preduce (preduce e))
  (define got-nf (nf e))
  (check-equal? got-preduce expected)
  (check-equal? got-nf expected)
  (check-equal? got-preduce got-nf
                (format "DIFFERENTIAL: preduce=~v nf=~v" got-preduce got-nf)))

(test-case "from-int Int → Rat"
  (check-preduce/nf (expr-from-int (expr-int 5)) (expr-rat 5))
  (check-preduce/nf (expr-from-int (expr-int -3)) (expr-rat -3))
  (check-preduce/nf (expr-from-int (expr-int 0)) (expr-rat 0)))

(test-case "from-nat Nat → Int"
  (check-preduce/nf (expr-from-nat (expr-nat-val 7)) (expr-int 7))
  (check-preduce/nf (expr-from-nat (expr-nat-val 0)) (expr-int 0))
  (check-preduce/nf (expr-from-nat (expr-zero)) (expr-int 0)))

(test-case "from-int operand computed via arithmetic"
  ;; from-int (3 + 4) = Rat 7
  (check-preduce/nf (expr-from-int (expr-int-add (expr-int 3) (expr-int 4)))
                    (expr-rat 7)))

(test-case "expr-cut held opaque (logic-engine value)"
  (check-equal? (preduce (expr-cut)) (expr-cut)))

(test-case "expr-Open held opaque"
  (check-equal? (preduce (expr-Open)) (expr-Open)))
