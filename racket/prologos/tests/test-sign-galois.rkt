#lang racket/base

;;;
;;; Tests for GaloisConnection Interval Sign
;;; Tests: alpha (abstraction), gamma (concretization),
;;; round-trip soundness, edge cases.
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
(define sign-galois-preamble
  (string-append
    "(ns test :no-prelude)\n"
    "(require [prologos::core::galois-trait :refer [GaloisConnection GaloisConnection-alpha GaloisConnection-gamma]])\n"
    "(require [prologos::core::galois-instances :refer []])\n"
    "(require [prologos::core::sign-galois :refer []])\n"
    "(require [prologos::core::lattice-instances :refer [Interval interval-bot interval-top mk-interval]])\n"
    "(require [prologos::data::sign :refer [Sign sign-bot sign-neg sign-zero sign-pos sign-top]])\n"))

(define dict "Interval-Sign--GaloisConnection--dict")

;; ========================================
;; 1. Alpha: Interval → Sign
;; ========================================

(test-case "alpha: interval-bot → sign-bot (unreachable)"
  (check-contains
    (run-ns-last (string-append
      sign-galois-preamble
      (format "(eval (GaloisConnection-alpha ~a interval-bot))" dict)))
    "sign-bot"))

(test-case "alpha: interval-top → sign-top (contradiction)"
  (check-contains
    (run-ns-last (string-append
      sign-galois-preamble
      (format "(eval (GaloisConnection-alpha ~a interval-top))" dict)))
    "sign-top"))

(test-case "alpha: mk-interval 1 10 → sign-pos (entirely positive)"
  (check-contains
    (run-ns-last (string-append
      sign-galois-preamble
      (format "(eval (GaloisConnection-alpha ~a (mk-interval 1 10)))" dict)))
    "sign-pos"))

(test-case "alpha: mk-interval -10 -1 → sign-neg (entirely negative)"
  (check-contains
    (run-ns-last (string-append
      sign-galois-preamble
      (format "(eval (GaloisConnection-alpha ~a (mk-interval -10 -1)))" dict)))
    "sign-neg"))

(test-case "alpha: mk-interval 0 0 → sign-zero (exactly zero)"
  (check-contains
    (run-ns-last (string-append
      sign-galois-preamble
      (format "(eval (GaloisConnection-alpha ~a (mk-interval 0 0)))" dict)))
    "sign-zero"))

(test-case "alpha: mk-interval -5 5 → sign-top (spans zero)"
  (check-contains
    (run-ns-last (string-append
      sign-galois-preamble
      (format "(eval (GaloisConnection-alpha ~a (mk-interval -5 5)))" dict)))
    "sign-top"))

(test-case "alpha: mk-interval 0 10 → sign-top (includes zero at lower bound)"
  (check-contains
    (run-ns-last (string-append
      sign-galois-preamble
      (format "(eval (GaloisConnection-alpha ~a (mk-interval 0 10)))" dict)))
    "sign-top"))

(test-case "alpha: mk-interval -10 0 → sign-top (includes zero at upper bound)"
  (check-contains
    (run-ns-last (string-append
      sign-galois-preamble
      (format "(eval (GaloisConnection-alpha ~a (mk-interval -10 0)))" dict)))
    "sign-top"))

;; ========================================
;; 2. Gamma: Sign → Interval
;; ========================================

(test-case "gamma: sign-bot → interval-bot (unreachable)"
  (check-contains
    (run-ns-last (string-append
      sign-galois-preamble
      (format "(eval (GaloisConnection-gamma ~a sign-bot))" dict)))
    "interval-bot"))

(test-case "gamma: sign-neg → mk-interval -999999 -1"
  (check-contains
    (run-ns-last (string-append
      sign-galois-preamble
      (format "(eval (GaloisConnection-gamma ~a sign-neg))" dict)))
    "mk-interval -999999 -1"))

(test-case "gamma: sign-zero → mk-interval 0 0"
  (check-contains
    (run-ns-last (string-append
      sign-galois-preamble
      (format "(eval (GaloisConnection-gamma ~a sign-zero))" dict)))
    "mk-interval 0 0"))

(test-case "gamma: sign-pos → mk-interval 1 999999"
  (check-contains
    (run-ns-last (string-append
      sign-galois-preamble
      (format "(eval (GaloisConnection-gamma ~a sign-pos))" dict)))
    "mk-interval 1 999999"))

(test-case "gamma: sign-top → mk-interval -999999 999999"
  (check-contains
    (run-ns-last (string-append
      sign-galois-preamble
      (format "(eval (GaloisConnection-gamma ~a sign-top))" dict)))
    "mk-interval -999999 999999"))

;; ========================================
;; 3. Round-Trip: α(γ(a)) = a (upper closure)
;; ========================================

(test-case "round-trip: alpha(gamma(sign-pos)) = sign-pos"
  (check-contains
    (run-ns-last (string-append
      sign-galois-preamble
      (format "(eval (GaloisConnection-alpha ~a\n  (GaloisConnection-gamma ~a sign-pos)))" dict dict)))
    "sign-pos"))

(test-case "round-trip: alpha(gamma(sign-neg)) = sign-neg"
  (check-contains
    (run-ns-last (string-append
      sign-galois-preamble
      (format "(eval (GaloisConnection-alpha ~a\n  (GaloisConnection-gamma ~a sign-neg)))" dict dict)))
    "sign-neg"))

(test-case "round-trip: alpha(gamma(sign-zero)) = sign-zero"
  (check-contains
    (run-ns-last (string-append
      sign-galois-preamble
      (format "(eval (GaloisConnection-alpha ~a\n  (GaloisConnection-gamma ~a sign-zero)))" dict dict)))
    "sign-zero"))

(test-case "round-trip: alpha(gamma(sign-top)) = sign-top"
  (check-contains
    (run-ns-last (string-append
      sign-galois-preamble
      (format "(eval (GaloisConnection-alpha ~a\n  (GaloisConnection-gamma ~a sign-top)))" dict dict)))
    "sign-top"))

;; ========================================
;; 4. Edge Cases: Fractional Intervals
;; ========================================

(test-case "alpha: mk-interval 1/2 3/2 → sign-pos (fractional positive)"
  (check-contains
    (run-ns-last (string-append
      sign-galois-preamble
      (format "(eval (GaloisConnection-alpha ~a (mk-interval 1/2 3/2)))" dict)))
    "sign-pos"))

(test-case "alpha: mk-interval -3/2 -1/2 → sign-neg (fractional negative)"
  (check-contains
    (run-ns-last (string-append
      sign-galois-preamble
      (format "(eval (GaloisConnection-alpha ~a (mk-interval -3/2 -1/2)))" dict)))
    "sign-neg"))
