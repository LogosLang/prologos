#lang racket/base

;;;
;;; Tests for prelude.rkt — Port of test-0a.maude (multiplicity + level tests)
;;;

(require rackunit
         "../prelude.rkt")

;; ========================================
;; Multiplicity semiring tests
;; ========================================

(test-case "mult-add: m0 + m0 = m0"
  (check-equal? (mult-add 'm0 'm0) 'm0))
(test-case "mult-add: m0 + m1 = m1"
  (check-equal? (mult-add 'm0 'm1) 'm1))
(test-case "mult-add: m1 + m1 = mw"
  (check-equal? (mult-add 'm1 'm1) 'mw))
(test-case "mult-add: m1 + mw = mw"
  (check-equal? (mult-add 'm1 'mw) 'mw))
(test-case "mult-add: mw + mw = mw"
  (check-equal? (mult-add 'mw 'mw) 'mw))

;; Commutativity
(test-case "mult-add commutative: m1 + m0 = m1"
  (check-equal? (mult-add 'm1 'm0) 'm1))
(test-case "mult-add commutative: mw + m0 = mw"
  (check-equal? (mult-add 'mw 'm0) 'mw))
(test-case "mult-add commutative: mw + m1 = mw"
  (check-equal? (mult-add 'mw 'm1) 'mw))

;; Multiplication
(test-case "mult-mul: m0 * m1 = m0"
  (check-equal? (mult-mul 'm0 'm1) 'm0))
(test-case "mult-mul: m1 * m1 = m1"
  (check-equal? (mult-mul 'm1 'm1) 'm1))
(test-case "mult-mul: mw * m1 = mw"
  (check-equal? (mult-mul 'mw 'm1) 'mw))
(test-case "mult-mul: m0 * mw = m0"
  (check-equal? (mult-mul 'm0 'mw) 'm0))
(test-case "mult-mul: mw * mw = mw"
  (check-equal? (mult-mul 'mw 'mw) 'mw))

;; Commutativity of multiplication
(test-case "mult-mul commutative: m1 * m0 = m0"
  (check-equal? (mult-mul 'm1 'm0) 'm0))
(test-case "mult-mul commutative: mw * m0 = m0"
  (check-equal? (mult-mul 'mw 'm0) 'm0))

;; Ordering
(test-case "mult-leq: m0 <= m1"
  (check-true (mult-leq 'm0 'm1)))
(test-case "mult-leq: m1 <= mw"
  (check-true (mult-leq 'm1 'mw)))
(test-case "mult-leq: not (mw <= m1)"
  (check-false (mult-leq 'mw 'm1)))
(test-case "mult-leq: m0 <= mw"
  (check-true (mult-leq 'm0 'mw)))
(test-case "mult-leq: m0 <= m0"
  (check-true (mult-leq 'm0 'm0)))
(test-case "mult-leq: m1 <= m1"
  (check-true (mult-leq 'm1 'm1)))
(test-case "mult-leq: mw <= mw"
  (check-true (mult-leq 'mw 'mw)))
(test-case "mult-leq: not (m1 <= m0)"
  (check-false (mult-leq 'm1 'm0)))
(test-case "mult-leq: not (mw <= m0)"
  (check-false (mult-leq 'mw 'm0)))

;; Compatibility
(test-case "compatible: mw allows zero use"
  (check-true (compatible 'mw 'm0)))
(test-case "compatible: mw allows one use"
  (check-true (compatible 'mw 'm1)))
(test-case "compatible: mw allows omega use"
  (check-true (compatible 'mw 'mw)))
(test-case "compatible: m1 allows exactly one use"
  (check-true (compatible 'm1 'm1)))
(test-case "compatible: m1 does not allow zero use"
  (check-false (compatible 'm1 'm0)))
(test-case "compatible: m0 does not allow one use"
  (check-false (compatible 'm0 'm1)))
(test-case "compatible: m0 allows zero use"
  (check-true (compatible 'm0 'm0)))
(test-case "compatible: m0 does not allow omega use"
  (check-false (compatible 'm0 'mw)))
(test-case "compatible: m1 does not allow omega use"
  (check-false (compatible 'm1 'mw)))

;; ========================================
;; Universe level tests
;; ========================================

(test-case "lmax: lzero and lsuc(lzero) = lsuc(lzero)"
  (check-equal? (lmax (lzero) (lsuc (lzero)))
                (lsuc (lzero))))
(test-case "lmax: lsuc(lzero) and lzero = lsuc(lzero)"
  (check-equal? (lmax (lsuc (lzero)) (lzero))
                (lsuc (lzero))))
(test-case "lmax: lsuc(lzero) and lsuc(lzero) = lsuc(lzero)"
  (check-equal? (lmax (lsuc (lzero)) (lsuc (lzero)))
                (lsuc (lzero))))
(test-case "lmax: lsuc(lsuc(lzero)) and lsuc(lzero) = lsuc(lsuc(lzero))"
  (check-equal? (lmax (lsuc (lsuc (lzero))) (lsuc (lzero)))
                (lsuc (lsuc (lzero)))))
(test-case "lmax: lzero and lzero = lzero"
  (check-equal? (lmax (lzero) (lzero))
                (lzero)))

;; Additional level tests
(test-case "level? recognizes lzero"
  (check-true (level? (lzero))))
(test-case "level? recognizes lsuc"
  (check-true (level? (lsuc (lzero)))))
(test-case "level? rejects non-levels"
  (check-false (level? 42)))
