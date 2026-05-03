#lang racket/base

;;; test-preduce-phase10.rkt
;;;
;;; Phase 10: expr-reduce — general constructor pattern matching.
;;; Built-in constructor scope: true, false, zero, suc (incl. nat-val
;;; collapse), refl, nil, vnil, vcons, fzero, fsuc, pair.
;;;
;;; Includes the end-to-end factorial-iter acceptance test, which is
;;; the deepest PReduce-lite case enabled by Phases 0-10 (no foreign-fn,
;;; no expr-meta).

(require rackunit
         "../syntax.rkt"
         "../preduce.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         (only-in "../reduction.rkt" nf))

(define (check-preduce/nf e expected)
  (define got-preduce (preduce e))
  (define got-nf (nf e))
  (check-equal? got-preduce expected
                (format "preduce returned ~v" got-preduce))
  (check-equal? got-nf expected
                (format "nf returned ~v" got-nf))
  (check-equal? got-preduce got-nf
                (format "DIFFERENTIAL: preduce=~v nf=~v" got-preduce got-nf)))

;; ====================================================================
;; Bool match (true / false arms)
;; ====================================================================

(test-case "match on Bool: true arm"
  ;; (match true | true → 1 | false → 2) = 1
  (define e
    (expr-reduce (expr-true)
                 (list (expr-reduce-arm 'true 0 (expr-int 1))
                       (expr-reduce-arm 'false 0 (expr-int 2)))
                 #t))
  (check-preduce/nf e (expr-int 1)))

(test-case "match on Bool: false arm"
  (define e
    (expr-reduce (expr-false)
                 (list (expr-reduce-arm 'true 0 (expr-int 1))
                       (expr-reduce-arm 'false 0 (expr-int 2)))
                 #t))
  (check-preduce/nf e (expr-int 2)))

(test-case "match on int comparison result"
  (define e
    (expr-reduce (expr-int-lt (expr-int 3) (expr-int 5))
                 (list (expr-reduce-arm 'true 0 (expr-int 100))
                       (expr-reduce-arm 'false 0 (expr-int 200)))
                 #t))
  (check-preduce/nf e (expr-int 100)))

;; ====================================================================
;; Nat match (zero / suc arms)
;; ====================================================================

(test-case "match on Nat: zero arm"
  (define e
    (expr-reduce (expr-nat-val 0)
                 (list (expr-reduce-arm 'zero 0 (expr-int 99))
                       (expr-reduce-arm 'suc 1 (expr-bvar 0)))
                 #t))
  (check-preduce/nf e (expr-int 99)))

(test-case "match on Nat: suc arm via nat-val collapse"
  ;; (match 5 | zero → 0 | suc n → n) — n is the predecessor (nat-val 4)
  (define e
    (expr-reduce (expr-nat-val 5)
                 (list (expr-reduce-arm 'zero 0 (expr-int 0))
                       (expr-reduce-arm 'suc 1 (expr-bvar 0)))
                 #t))
  ;; preduce returns (expr-nat-val 4); nf returns (expr-nat-val 4) too
  (check-preduce/nf e (expr-nat-val 4)))

;; ====================================================================
;; End-to-end: factorial via match (the headline acceptance test)
;; ====================================================================

(test-case "factorial-iter 1 5 = 120 via acceptance file"
  (process-file "../examples/preduce-lite/07-factorial.prologos")
  (define main-body (global-env-lookup-value 'main))
  (check-equal? (preduce main-body) (expr-int 120))
  (check-equal? (nf main-body) (expr-int 120)))
