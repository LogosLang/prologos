#lang racket/base

;;;
;;; Tests for Phase 6b: GaloisConnection Trait + Instances
;;; Tests: trait registration, accessors, Interval→Bool instance,
;;; adjunction law sanity, round-trip soundness.
;;;

(require rackunit
         racket/string
         "test-support.rkt")

;; ========================================
;; Helpers
;; ========================================

(define (check-contains actual substr [msg #f])
  (define actual-str (if (string? actual) actual (format "~a" actual)))
  (check-true (string-contains? actual-str substr)
              (or msg (format "Expected ~s to contain ~s" actual-str substr))))

;; Common requires preamble for no-prelude tests
(define galois-preamble
  (string-append
    "(ns test :no-prelude)\n"
    "(imports [prologos::core::lattice :refer [GaloisConnection GaloisConnection-alpha GaloisConnection-gamma Interval interval-bot interval-top mk-interval]])\n"))

;; ========================================
;; 1. Trait Registration
;; ========================================

(test-case "GaloisConnection-alpha accessor type-checks"
  (check-contains
    (run-ns-last (string-append
      galois-preamble
      "(eval (GaloisConnection-alpha Interval-Bool--GaloisConnection--dict interval-bot))"))
    "false"))

(test-case "GaloisConnection-gamma accessor type-checks"
  (check-contains
    (run-ns-last (string-append
      galois-preamble
      "(eval (GaloisConnection-gamma Interval-Bool--GaloisConnection--dict false))"))
    "interval-bot"))

;; ========================================
;; 2. Dict Name Pattern
;; ========================================

(test-case "Dict name follows C-A--GaloisConnection--dict pattern"
  ;; Interval-Bool--GaloisConnection--dict should exist and be usable
  (check-contains
    (run-ns-last (string-append
      galois-preamble
      "(eval (GaloisConnection-alpha Interval-Bool--GaloisConnection--dict interval-top))"))
    "true"))

;; ========================================
;; 3. Interval→Bool Alpha Cases
;; ========================================

(test-case "alpha: interval-bot → false (unconstrained)"
  (check-contains
    (run-ns-last (string-append
      galois-preamble
      "(eval (GaloisConnection-alpha Interval-Bool--GaloisConnection--dict interval-bot))"))
    "false : Bool"))

(test-case "alpha: interval-top → true (contradiction)"
  (check-contains
    (run-ns-last (string-append
      galois-preamble
      "(eval (GaloisConnection-alpha Interval-Bool--GaloisConnection--dict interval-top))"))
    "true : Bool"))

(test-case "alpha: mk-interval 0 100 → true (constrained)"
  (check-contains
    (run-ns-last (string-append
      galois-preamble
      "(eval (GaloisConnection-alpha Interval-Bool--GaloisConnection--dict (mk-interval 0 100)))"))
    "true : Bool"))

(test-case "alpha: mk-interval 5 10 → true (constrained)"
  (check-contains
    (run-ns-last (string-append
      galois-preamble
      "(eval (GaloisConnection-alpha Interval-Bool--GaloisConnection--dict (mk-interval 5 10)))"))
    "true : Bool"))

;; ========================================
;; 4. Bool→Interval Gamma Cases
;; ========================================

(test-case "gamma: false → interval-bot (unconstrained)"
  (check-contains
    (run-ns-last (string-append
      galois-preamble
      "(eval (GaloisConnection-gamma Interval-Bool--GaloisConnection--dict false))"))
    "interval-bot"))

(test-case "gamma: true → interval-top (most constrained)"
  (check-contains
    (run-ns-last (string-append
      galois-preamble
      "(eval (GaloisConnection-gamma Interval-Bool--GaloisConnection--dict true))"))
    "interval-top"))

;; ========================================
;; 5. Adjunction Law Sanity Checks
;; ========================================

(test-case "round-trip: alpha(gamma(false)) = false"
  ;; alpha(gamma(false)) = alpha(interval-bot) = false
  (check-contains
    (run-ns-last (string-append
      galois-preamble
      "(eval (GaloisConnection-alpha Interval-Bool--GaloisConnection--dict\n"
      "  (GaloisConnection-gamma Interval-Bool--GaloisConnection--dict false)))"))
    "false : Bool"))

(test-case "round-trip: alpha(gamma(true)) = true"
  ;; alpha(gamma(true)) = alpha(interval-top) = true
  (check-contains
    (run-ns-last (string-append
      galois-preamble
      "(eval (GaloisConnection-alpha Interval-Bool--GaloisConnection--dict\n"
      "  (GaloisConnection-gamma Interval-Bool--GaloisConnection--dict true)))"))
    "true : Bool"))

;; ========================================
;; 6. Prelude Availability
;; ========================================

(test-case "GaloisConnection-alpha available from prelude"
  (check-contains
    (run-ns-last (string-append
      "(ns test)\n"
      "(eval (GaloisConnection-alpha Interval-Bool--GaloisConnection--dict interval-bot))"))
    "false"))

(test-case "GaloisConnection-gamma available from prelude"
  (check-contains
    (run-ns-last (string-append
      "(ns test)\n"
      "(eval (GaloisConnection-gamma Interval-Bool--GaloisConnection--dict true))"))
    "interval-top"))

;; ========================================
;; 7. Soundness: α preserves ordering
;; ========================================

(test-case "alpha preserves ordering: bot ≤ mk-interval ≤ top"
  ;; bot < everything: alpha(bot) = false ≤ alpha(any) = true
  ;; This is correct since false ≤ true in Bool lattice (join=or)
  (check-contains
    (run-ns-last (string-append
      galois-preamble
      "(eval (GaloisConnection-alpha Interval-Bool--GaloisConnection--dict interval-bot))"))
    "false")
  (check-contains
    (run-ns-last (string-append
      galois-preamble
      "(eval (GaloisConnection-alpha Interval-Bool--GaloisConnection--dict (mk-interval 5 10)))"))
    "true"))
