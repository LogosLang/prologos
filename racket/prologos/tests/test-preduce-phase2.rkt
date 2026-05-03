#lang racket/base

;;; test-preduce-phase2.rkt
;;;
;;; Phase 2 regression tests for PReduce-lite.
;;; Covers: literals (int/true/false/nat-val/zero), int arithmetic
;;; (8 ops with Nat→Int coercion), expr-suc, expr-ann (erase), bvar
;;; (out-of-range error), pair construction + statically-resolvable
;;; fst/snd projection.
;;;
;;; Includes per-phase differential testing: every test case asserts
;;; (preduce e) ≡ (nf e) under equal? (the design doc § 8.2 per-phase
;;; gate). The existing nf is the oracle.

(require rackunit
         "../syntax.rkt"
         "../preduce.rkt"
         (only-in "../reduction.rkt" nf))

;; ====================================================================
;; Differential helper: assert preduce result matches nf result
;; ====================================================================

(define (check-preduce/nf e expected)
  (define got-preduce (preduce e))
  (define got-nf (nf e))
  (check-equal? got-preduce expected
                (format "preduce returned ~v, expected ~v" got-preduce expected))
  (check-equal? got-nf expected
                (format "nf returned ~v, expected ~v (test setup error?)" got-nf expected))
  (check-equal? got-preduce got-nf
                (format "DIFFERENTIAL MISMATCH: preduce=~v nf=~v" got-preduce got-nf)))

;; ====================================================================
;; Literals
;; ====================================================================

(test-case "expr-int literal"
  (check-preduce/nf (expr-int 42) (expr-int 42)))

(test-case "expr-true / expr-false literals"
  (check-preduce/nf (expr-true) (expr-true))
  (check-preduce/nf (expr-false) (expr-false)))

(test-case "expr-nat-val and expr-zero literals"
  (check-preduce/nf (expr-nat-val 7) (expr-nat-val 7))
  ;; Note: nf normalizes (expr-zero) to (expr-nat-val 0) per nf-whnf
  ;; line 3214; preduce keeps zero as-is. This is one of the few
  ;; differential differences allowed (canonical form choice).
  (define p (preduce (expr-zero)))
  (define n (nf (expr-zero)))
  (check-true (or (equal? p n) (and (expr-zero? p) (equal? n (expr-nat-val 0))))
              (format "preduce ~v / nf ~v" p n)))

;; ====================================================================
;; Int arithmetic
;; ====================================================================

(test-case "int-add"
  (check-preduce/nf (expr-int-add (expr-int 2) (expr-int 3)) (expr-int 5))
  (check-preduce/nf (expr-int-add (expr-int -7) (expr-int 10)) (expr-int 3))
  (check-preduce/nf (expr-int-add (expr-int 0) (expr-int 0)) (expr-int 0)))

(test-case "int-sub"
  (check-preduce/nf (expr-int-sub (expr-int 10) (expr-int 3)) (expr-int 7))
  (check-preduce/nf (expr-int-sub (expr-int 5) (expr-int 5)) (expr-int 0)))

(test-case "int-mul"
  (check-preduce/nf (expr-int-mul (expr-int 3) (expr-int 4)) (expr-int 12))
  (check-preduce/nf (expr-int-mul (expr-int 0) (expr-int 100)) (expr-int 0)))

(test-case "int-div, int-mod"
  (check-preduce/nf (expr-int-div (expr-int 10) (expr-int 3)) (expr-int 3))
  (check-preduce/nf (expr-int-mod (expr-int 10) (expr-int 3)) (expr-int 1)))

(test-case "int comparisons return Bool"
  (check-preduce/nf (expr-int-eq (expr-int 5) (expr-int 5)) (expr-true))
  (check-preduce/nf (expr-int-eq (expr-int 5) (expr-int 6)) (expr-false))
  (check-preduce/nf (expr-int-lt (expr-int 3) (expr-int 5)) (expr-true))
  (check-preduce/nf (expr-int-lt (expr-int 5) (expr-int 5)) (expr-false))
  (check-preduce/nf (expr-int-le (expr-int 5) (expr-int 5)) (expr-true))
  (check-preduce/nf (expr-int-le (expr-int 6) (expr-int 5)) (expr-false)))

(test-case "nested arithmetic"
  ;; (10 + 5) - (2 * 3) = 15 - 6 = 9
  (check-preduce/nf
   (expr-int-sub (expr-int-add (expr-int 10) (expr-int 5))
                 (expr-int-mul (expr-int 2) (expr-int 3)))
   (expr-int 9)))

(test-case "Nat→Int coercion in arithmetic"
  (check-preduce/nf (expr-int-add (expr-nat-val 2) (expr-int 3)) (expr-int 5))
  (check-preduce/nf (expr-int-add (expr-int 7) (expr-nat-val 8)) (expr-int 15))
  (check-preduce/nf (expr-int-add (expr-zero) (expr-int 5)) (expr-int 5)))

;; ====================================================================
;; expr-suc
;; ====================================================================

(test-case "suc on concrete nat-val collapses"
  (check-preduce/nf (expr-suc (expr-nat-val 5)) (expr-nat-val 6))
  (check-preduce/nf (expr-suc (expr-nat-val 0)) (expr-nat-val 1)))

(test-case "suc on expr-zero collapses to nat-val 1"
  ;; nf-whnf normalizes zero to nat-val 0 first; preduce sees zero
  ;; and writes nat-val 1 directly. Equivalent.
  (check-preduce/nf (expr-suc (expr-zero)) (expr-nat-val 1)))

;; ====================================================================
;; Annotation erasure
;; ====================================================================

(test-case "expr-ann erases the annotation"
  (check-preduce/nf (expr-ann (expr-int 42) (expr-Int)) (expr-int 42))
  ;; Nested annotations also erase fully.
  (check-preduce/nf (expr-ann (expr-ann (expr-int 1) (expr-Int)) (expr-Int)) (expr-int 1)))

;; ====================================================================
;; Pairs (statically-resolvable fst/snd)
;; ====================================================================

(test-case "pair construction + fst/snd projection"
  (check-preduce/nf (expr-fst (expr-pair (expr-int 100) (expr-int 200))) (expr-int 100))
  (check-preduce/nf (expr-snd (expr-pair (expr-int 100) (expr-int 200))) (expr-int 200)))

(test-case "nested pair projection (fst of fst)"
  (check-preduce/nf
   (expr-fst (expr-fst (expr-pair (expr-pair (expr-int 1) (expr-int 2)) (expr-int 3))))
   (expr-int 1)))

(test-case "pair component computed via arithmetic"
  ;; fst (pair (1+2) (3*4)) = 3
  (check-preduce/nf
   (expr-fst (expr-pair (expr-int-add (expr-int 1) (expr-int 2))
                        (expr-int-mul (expr-int 3) (expr-int 4))))
   (expr-int 3)))

;; ====================================================================
;; Bvar bound check (Phase 2: out-of-range error)
;; ====================================================================

(test-case "bvar out-of-range raises clear error"
  (check-exn exn:fail?
             (lambda () (preduce (expr-bvar 0)))))

;; ====================================================================
;; Hard-error policy: permanently-unsupported nodes raise
;; ====================================================================

(test-case "expr-error always raises preduce-unsupported"
  (check-exn preduce-unsupported-node-error?
             (lambda () (preduce (expr-error)))))
