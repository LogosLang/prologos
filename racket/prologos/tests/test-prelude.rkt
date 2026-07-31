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

;; ========================================
;; mult-join — the ALTERNATION operator (2026-07-30)
;; ========================================
;; `mult-add` composes usages that BOTH happen (sequential); `mult-join` is the
;; least upper bound, for branches of which exactly ONE happens. The whole point
;; is the single cell where they differ, so pin the full table.

(test-case "mult-join: m1 join m1 = m1 — THE cell that differs from mult-add"
  ;; mult-add gives mw here, which is what rejected a linear variable used once
  ;; in each branch of an `if` (legal: only one branch runs).
  (check-equal? (mult-join 'm1 'm1) 'm1)
  (check-equal? (mult-add  'm1 'm1) 'mw))

(test-case "mult-join: agrees with mult-add on every OTHER cell"
  ;; This is the property that makes swapping add→join at an alternation site
  ;; monotone-permissive — it can never reject a program it used to accept.
  (for* ([a (in-list '(m0 m1 mw))]
         [b (in-list '(m0 m1 mw))]
         #:unless (and (eq? a 'm1) (eq? b 'm1)))
    (check-equal? (mult-join a b) (mult-add a b)
                  (format "mult-join/mult-add disagree at (~a ~a)" a b))))

(test-case "mult-join: m0 is the identity (= the lattice bottom)"
  ;; join-usage's null shortcuts depend on this.
  (for ([x (in-list '(m0 m1 mw))])
    (check-equal? (mult-join 'm0 x) x)
    (check-equal? (mult-join x 'm0) x)))

(test-case "mult-join: idempotent, commutative, associative"
  (for* ([a (in-list '(m0 m1 mw))] [b (in-list '(m0 m1 mw))])
    (check-equal? (mult-join a b) (mult-join b a) "commutative")
    (for ([c (in-list '(m0 m1 mw))])
      (check-equal? (mult-join a (mult-join b c))
                    (mult-join (mult-join a b) c) "associative")))
  (for ([x (in-list '(m0 m1 mw))])
    (check-equal? (mult-join x x) x "idempotent")))

(test-case "mult-join: it IS the lub of mult-leq"
  ;; Derived from the tree's own order rather than asserted independently.
  (for* ([a (in-list '(m0 m1 mw))] [b (in-list '(m0 m1 mw))])
    (define j (mult-join a b))
    (check-true (mult-leq a j) "upper bound of a")
    (check-true (mult-leq b j) "upper bound of b")
    ;; least: no strictly smaller element is also an upper bound
    (for ([c (in-list '(m0 m1 mw))]
          #:when (and (mult-leq c j) (not (eq? c j))))
      (check-false (and (mult-leq a c) (mult-leq b c))
                   (format "~a is a smaller upper bound of (~a ~a)" c a b)))))

(test-case "mult-join: mult-meta is treated as mw, like every sibling"
  (check-equal? (mult-join (mult-meta 99) 'm1) 'mw))

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
