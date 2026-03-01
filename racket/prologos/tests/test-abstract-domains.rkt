#lang racket/base

;;;
;;; Tests for Phase 6d: Abstract Domain Library Modules
;;; Tests: Sign/Parity data types, Lattice instances, HasTop instances.
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

;; Common preambles
(define sign-preamble
  (string-append
    "(ns test :no-prelude)\n"
    "(require [prologos::data::sign :refer [Sign sign-bot sign-neg sign-zero sign-pos sign-top]])\n"
    "(require [prologos::core::abstract-domains :refer []])\n"
    "(require [prologos::core::lattice :refer [Lattice Lattice-bot Lattice-join Lattice-leq HasTop HasTop-top]])\n"))

(define parity-preamble
  (string-append
    "(ns test :no-prelude)\n"
    "(require [prologos::data::parity :refer [Parity parity-bot parity-even parity-odd parity-top]])\n"
    "(require [prologos::core::abstract-domains :refer []])\n"
    "(require [prologos::core::lattice :refer [Lattice Lattice-bot Lattice-join Lattice-leq HasTop HasTop-top]])\n"))

;; ========================================
;; 1. Sign Data Type
;; ========================================

(test-case "Sign: constructors type-check"
  (check-contains
    (run-ns-last (string-append sign-preamble "(def x : Sign sign-bot)"))
    "defined"))

;; ========================================
;; 2. Sign Lattice: bot, join, leq
;; ========================================

(test-case "Sign: bot = sign-bot"
  (check-contains
    (run-ns-last (string-append sign-preamble
      "(eval (Lattice-bot Sign--Lattice--dict))"))
    "sign-bot"))

(test-case "Sign: join neg pos = top"
  (check-contains
    (run-ns-last (string-append sign-preamble
      "(eval (Lattice-join Sign--Lattice--dict sign-neg sign-pos))"))
    "sign-top"))

(test-case "Sign: join neg neg = neg"
  (check-contains
    (run-ns-last (string-append sign-preamble
      "(eval (Lattice-join Sign--Lattice--dict sign-neg sign-neg))"))
    "sign-neg"))

(test-case "Sign: join bot pos = pos"
  (check-contains
    (run-ns-last (string-append sign-preamble
      "(eval (Lattice-join Sign--Lattice--dict sign-bot sign-pos))"))
    "sign-pos"))

(test-case "Sign: join zero neg = top"
  (check-contains
    (run-ns-last (string-append sign-preamble
      "(eval (Lattice-join Sign--Lattice--dict sign-zero sign-neg))"))
    "sign-top"))

(test-case "Sign: leq bot neg = true"
  (check-contains
    (run-ns-last (string-append sign-preamble
      "(eval (Lattice-leq Sign--Lattice--dict sign-bot sign-neg))"))
    "true"))

(test-case "Sign: leq neg bot = false"
  (check-contains
    (run-ns-last (string-append sign-preamble
      "(eval (Lattice-leq Sign--Lattice--dict sign-neg sign-bot))"))
    "false"))

(test-case "Sign: leq pos top = true"
  (check-contains
    (run-ns-last (string-append sign-preamble
      "(eval (Lattice-leq Sign--Lattice--dict sign-pos sign-top))"))
    "true"))

;; ========================================
;; 3. Sign HasTop
;; ========================================

(test-case "Sign: top = sign-top"
  (check-contains
    (run-ns-last (string-append sign-preamble
      "(eval (HasTop-top Sign--HasTop--dict))"))
    "sign-top"))

;; ========================================
;; 4. Parity Data Type
;; ========================================

(test-case "Parity: constructors type-check"
  (check-contains
    (run-ns-last (string-append parity-preamble "(def x : Parity parity-bot)"))
    "defined"))

;; ========================================
;; 5. Parity Lattice: bot, join, leq
;; ========================================

(test-case "Parity: bot = parity-bot"
  (check-contains
    (run-ns-last (string-append parity-preamble
      "(eval (Lattice-bot Parity--Lattice--dict))"))
    "parity-bot"))

(test-case "Parity: join even odd = top"
  (check-contains
    (run-ns-last (string-append parity-preamble
      "(eval (Lattice-join Parity--Lattice--dict parity-even parity-odd))"))
    "parity-top"))

(test-case "Parity: join even even = even"
  (check-contains
    (run-ns-last (string-append parity-preamble
      "(eval (Lattice-join Parity--Lattice--dict parity-even parity-even))"))
    "parity-even"))

(test-case "Parity: join bot odd = odd"
  (check-contains
    (run-ns-last (string-append parity-preamble
      "(eval (Lattice-join Parity--Lattice--dict parity-bot parity-odd))"))
    "parity-odd"))

(test-case "Parity: leq bot even = true"
  (check-contains
    (run-ns-last (string-append parity-preamble
      "(eval (Lattice-leq Parity--Lattice--dict parity-bot parity-even))"))
    "true"))

(test-case "Parity: leq even odd = false"
  (check-contains
    (run-ns-last (string-append parity-preamble
      "(eval (Lattice-leq Parity--Lattice--dict parity-even parity-odd))"))
    "false"))

;; ========================================
;; 6. Parity HasTop
;; ========================================

(test-case "Parity: top = parity-top"
  (check-contains
    (run-ns-last (string-append parity-preamble
      "(eval (HasTop-top Parity--HasTop--dict))"))
    "parity-top"))
