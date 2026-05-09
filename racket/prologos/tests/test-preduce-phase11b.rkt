#lang racket/base

;;; test-preduce-phase11b.rkt
;;;
;;; Phase 11b: container ops (Map, Set, PVec) — simple cases.
;;; Higher-order ops (pvec-fold/map/filter, set-fold/filter,
;;; map-fold-entries/filter-entries/map-vals) deferred to Phase 11c.

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

;; ====================================================================
;; Map ops
;; ====================================================================

(define m-empty (expr-map-empty (expr-Int) (expr-Int)))
(define m-1 (expr-map-assoc m-empty (expr-int 1) (expr-int 100)))
(define m-2 (expr-map-assoc m-1 (expr-int 2) (expr-int 200)))
(define m-3 (expr-map-assoc m-2 (expr-int 3) (expr-int 300)))

(test-case "map-empty + map-size"
  (check-preduce/nf (expr-map-size m-empty) (expr-nat-val 0)))

(test-case "map-assoc + map-size"
  (check-preduce/nf (expr-map-size m-3) (expr-nat-val 3)))

(test-case "map-get returns value for present key"
  (check-preduce/nf (expr-map-get m-3 (expr-int 2)) (expr-int 200)))

(test-case "map-has-key true / false"
  (check-preduce/nf (expr-map-has-key m-3 (expr-int 1)) (expr-true))
  (check-preduce/nf (expr-map-has-key m-3 (expr-int 99)) (expr-false)))

(test-case "map-dissoc removes entry"
  (check-preduce/nf (expr-map-size (expr-map-dissoc m-3 (expr-int 2)))
                    (expr-nat-val 2))
  (check-preduce/nf (expr-map-has-key (expr-map-dissoc m-3 (expr-int 2))
                                       (expr-int 2))
                    (expr-false)))

;; ====================================================================
;; Set ops
;; ====================================================================

(define s-empty (expr-set-empty (expr-Int)))
(define s-3 (expr-set-insert (expr-set-insert (expr-set-insert s-empty (expr-int 5))
                                               (expr-int 10))
                              (expr-int 15)))

(test-case "set-empty + set-size"
  (check-preduce/nf (expr-set-size s-empty) (expr-nat-val 0)))

(test-case "set-insert + set-size"
  (check-preduce/nf (expr-set-size s-3) (expr-nat-val 3)))

(test-case "set-member true / false"
  (check-preduce/nf (expr-set-member s-3 (expr-int 10)) (expr-true))
  (check-preduce/nf (expr-set-member s-3 (expr-int 99)) (expr-false)))

(test-case "set-delete + set-size"
  (check-preduce/nf (expr-set-size (expr-set-delete s-3 (expr-int 10)))
                    (expr-nat-val 2)))

(test-case "set-union size = |s1 ∪ s2|"
  (define a (expr-set-insert (expr-set-insert s-empty (expr-int 1)) (expr-int 2)))
  (define b (expr-set-insert (expr-set-insert s-empty (expr-int 2)) (expr-int 3)))
  (check-preduce/nf (expr-set-size (expr-set-union a b)) (expr-nat-val 3)))

(test-case "set-intersect size"
  (define a (expr-set-insert (expr-set-insert s-empty (expr-int 1)) (expr-int 2)))
  (define b (expr-set-insert (expr-set-insert s-empty (expr-int 2)) (expr-int 3)))
  (check-preduce/nf (expr-set-size (expr-set-intersect a b)) (expr-nat-val 1)))

(test-case "set-diff size"
  (define a (expr-set-insert (expr-set-insert s-empty (expr-int 1)) (expr-int 2)))
  (define b (expr-set-insert (expr-set-insert s-empty (expr-int 2)) (expr-int 3)))
  (check-preduce/nf (expr-set-size (expr-set-diff a b)) (expr-nat-val 1)))

;; ====================================================================
;; PVec ops
;; ====================================================================

(define v-empty (expr-pvec-empty (expr-Int)))
(define v-3 (expr-pvec-push (expr-pvec-push (expr-pvec-push v-empty (expr-int 7))
                                             (expr-int 8))
                             (expr-int 9)))

(test-case "pvec-empty + pvec-length"
  (check-preduce/nf (expr-pvec-length v-empty) (expr-nat-val 0)))

(test-case "pvec-push + pvec-length"
  (check-preduce/nf (expr-pvec-length v-3) (expr-nat-val 3)))

(test-case "pvec-nth"
  (check-preduce/nf (expr-pvec-nth v-3 (expr-nat-val 0)) (expr-int 7))
  (check-preduce/nf (expr-pvec-nth v-3 (expr-nat-val 1)) (expr-int 8))
  (check-preduce/nf (expr-pvec-nth v-3 (expr-nat-val 2)) (expr-int 9)))

(test-case "pvec-update"
  (check-preduce/nf (expr-pvec-nth (expr-pvec-update v-3 (expr-nat-val 1) (expr-int 99))
                                    (expr-nat-val 1))
                    (expr-int 99)))

(test-case "pvec-pop reduces length by 1"
  (check-preduce/nf (expr-pvec-length (expr-pvec-pop v-3)) (expr-nat-val 2)))

(test-case "pvec-concat lengths sum"
  (define a (expr-pvec-push v-empty (expr-int 1)))
  (define b (expr-pvec-push (expr-pvec-push v-empty (expr-int 2)) (expr-int 3)))
  (check-preduce/nf (expr-pvec-length (expr-pvec-concat a b)) (expr-nat-val 3)))

(test-case "pvec-slice"
  (check-preduce/nf (expr-pvec-length (expr-pvec-slice v-3 (expr-nat-val 1) (expr-nat-val 3)))
                    (expr-nat-val 2))
  (check-preduce/nf (expr-pvec-nth (expr-pvec-slice v-3 (expr-nat-val 1) (expr-nat-val 3))
                                    (expr-nat-val 0))
                    (expr-int 8)))
