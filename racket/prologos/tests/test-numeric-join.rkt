#lang racket/base

;;;
;;; Tests for numeric-join (Phase 3a)
;;; Tests the least-upper-bound function for numeric types.
;;;

(require rackunit
         "../syntax.rkt"
         (only-in "../typing-core.rkt"
                  numeric-join exact-numeric-type? posit-type?))

;; ========================================
;; Same type → identity
;; ========================================

(test-case "numeric-join/same-int"
  (check-equal? (numeric-join (expr-Int) (expr-Int)) (expr-Int)))

(test-case "numeric-join/same-rat"
  (check-equal? (numeric-join (expr-Rat) (expr-Rat)) (expr-Rat)))

(test-case "numeric-join/same-nat"
  (check-equal? (numeric-join (expr-Nat) (expr-Nat)) (expr-Nat)))

(test-case "numeric-join/same-posit32"
  (check-equal? (numeric-join (expr-Posit32) (expr-Posit32)) (expr-Posit32)))

;; ========================================
;; Within exact family: wider wins
;; ========================================

(test-case "numeric-join/nat-int"
  (check-equal? (numeric-join (expr-Nat) (expr-Int)) (expr-Int)))

(test-case "numeric-join/int-nat"
  ;; commutative
  (check-equal? (numeric-join (expr-Int) (expr-Nat)) (expr-Int)))

(test-case "numeric-join/nat-rat"
  (check-equal? (numeric-join (expr-Nat) (expr-Rat)) (expr-Rat)))

(test-case "numeric-join/int-rat"
  (check-equal? (numeric-join (expr-Int) (expr-Rat)) (expr-Rat)))

;; ========================================
;; Within posit family: wider wins
;; ========================================

(test-case "numeric-join/p8-p16"
  (check-equal? (numeric-join (expr-Posit8) (expr-Posit16)) (expr-Posit16)))

(test-case "numeric-join/p16-p32"
  (check-equal? (numeric-join (expr-Posit16) (expr-Posit32)) (expr-Posit32)))

(test-case "numeric-join/p32-p64"
  (check-equal? (numeric-join (expr-Posit32) (expr-Posit64)) (expr-Posit64)))

(test-case "numeric-join/p8-p64"
  (check-equal? (numeric-join (expr-Posit8) (expr-Posit64)) (expr-Posit64)))

;; ========================================
;; Cross-family: posit dominates (at least P32)
;; ========================================

(test-case "numeric-join/int-p32"
  (check-equal? (numeric-join (expr-Int) (expr-Posit32)) (expr-Posit32)))

(test-case "numeric-join/rat-p32"
  (check-equal? (numeric-join (expr-Rat) (expr-Posit32)) (expr-Posit32)))

(test-case "numeric-join/nat-p32"
  (check-equal? (numeric-join (expr-Nat) (expr-Posit32)) (expr-Posit32)))

(test-case "numeric-join/int-p8-widens-to-p32"
  ;; P8 is too narrow; cross-family should widen to at least P32
  (check-equal? (numeric-join (expr-Int) (expr-Posit8)) (expr-Posit32)))

(test-case "numeric-join/rat-p16-widens-to-p32"
  (check-equal? (numeric-join (expr-Rat) (expr-Posit16)) (expr-Posit32)))

(test-case "numeric-join/int-p64-stays-p64"
  ;; P64 > P32, so stays P64
  (check-equal? (numeric-join (expr-Int) (expr-Posit64)) (expr-Posit64)))

;; Commutative: posit on left
(test-case "numeric-join/p32-int"
  (check-equal? (numeric-join (expr-Posit32) (expr-Int)) (expr-Posit32)))

(test-case "numeric-join/p8-rat"
  (check-equal? (numeric-join (expr-Posit8) (expr-Rat)) (expr-Posit32)))

;; ========================================
;; Non-numeric types → #f
;; ========================================

(test-case "numeric-join/bool-int"
  (check-false (numeric-join (expr-Bool) (expr-Int))))

(test-case "numeric-join/int-bool"
  (check-false (numeric-join (expr-Int) (expr-Bool))))

(test-case "numeric-join/bool-bool"
  (check-false (numeric-join (expr-Bool) (expr-Bool))))

;; ========================================
;; Helper predicates
;; ========================================

(test-case "exact-numeric-type?"
  (check-true (exact-numeric-type? (expr-Nat)))
  (check-true (exact-numeric-type? (expr-Int)))
  (check-true (exact-numeric-type? (expr-Rat)))
  (check-false (exact-numeric-type? (expr-Posit32)))
  (check-false (exact-numeric-type? (expr-Bool))))

(test-case "posit-type?"
  (check-true (posit-type? (expr-Posit8)))
  (check-true (posit-type? (expr-Posit32)))
  (check-true (posit-type? (expr-Posit64)))
  (check-false (posit-type? (expr-Int)))
  (check-false (posit-type? (expr-Bool))))
