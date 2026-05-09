#lang racket/base

;;; test-preduce-phase6.rkt
;;;
;;; Phase 6: Vec eliminators (vhead, vtail) + Vec constructors (vcons,
;;; vnil) + Fin family (fzero, fsuc, Fin held opaque).
;;; Differential against nf where applicable.

(require rackunit
         "../syntax.rkt"
         "../preduce.rkt"
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

(define t (expr-Int))

;; [1, 2, 3] : Vec(Int, 3)
(define v3
  (expr-vcons t (expr-nat-val 2) (expr-int 1)
   (expr-vcons t (expr-nat-val 1) (expr-int 2)
    (expr-vcons t (expr-nat-val 0) (expr-int 3) (expr-vnil t)))))

(test-case "vhead of literal vcons"
  (check-preduce/nf (expr-vhead t (expr-nat-val 3) v3) (expr-int 1)))

(test-case "vhead of vtail (= second element)"
  (check-preduce/nf
   (expr-vhead t (expr-nat-val 2) (expr-vtail t (expr-nat-val 3) v3))
   (expr-int 2)))

(test-case "vhead of vtail of vtail (= third element)"
  (check-preduce/nf
   (expr-vhead t (expr-nat-val 1)
               (expr-vtail t (expr-nat-val 2)
                           (expr-vtail t (expr-nat-val 3) v3)))
   (expr-int 3)))

(test-case "vcons head computed via arithmetic"
  ;; vhead of [1+2, 4] = 3
  (define v2 (expr-vcons t (expr-nat-val 1)
                        (expr-int-add (expr-int 1) (expr-int 2))
                        (expr-vcons t (expr-nat-val 0) (expr-int 4) (expr-vnil t))))
  (check-preduce/nf (expr-vhead t (expr-nat-val 2) v2) (expr-int 3)))

;; ====================================================================
;; Fin family — held as values
;; ====================================================================

(test-case "fzero is a value"
  (define got (preduce (expr-fzero (expr-nat-val 5))))
  ;; nf returns (expr-fzero (expr-nat-val 5)) — same shape
  (check-equal? got (expr-fzero (expr-nat-val 5))))

(test-case "fsuc inner reduces"
  ;; (fsuc 3 (fzero 2)) — inner is a value already
  (define got (preduce (expr-fsuc (expr-nat-val 3) (expr-fzero (expr-nat-val 2)))))
  (check-true (expr-fsuc? got)))
