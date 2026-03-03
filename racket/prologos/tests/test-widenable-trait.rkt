#lang racket/base

;;;
;;; Tests for Phase 6a: Widenable Trait (Prologos level)
;;; Tests: trait registration, Interval widen/narrow semantics,
;;; new-widenable-cell via driver, prelude availability.
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

(define (ensure-string v)
  (if (string? v) v (format "~a" v)))

;; ========================================
;; 1. Module Loading
;; ========================================

(test-case "widenable-trait module loads"
  ;; Trait names aren't term-level values; test accessor availability instead
  (check-contains
    (run-ns-last (string-append
      "(ns test :no-prelude)\n"
      "(imports [prologos::core::lattice :refer [Widenable Widenable-widen Widenable-narrow Interval interval-bot]])\n"
      "(eval (Widenable-widen Interval--Widenable--dict interval-bot interval-bot))"))
    "interval-bot"))

(test-case "widenable-instances module loads"
  (check-contains
    (run-ns-last (string-append
      "(ns test :no-prelude)\n"
      "(imports [prologos::core::lattice :refer [Widenable Widenable-widen Widenable-narrow Interval interval-bot]])\n"
      "(def x : Interval interval-bot)"))
    "defined"))

;; ========================================
;; 2. Widenable Trait Accessors
;; ========================================

(test-case "Widenable-widen accessor type-checks"
  (check-contains
    (run-ns-last (string-append
      "(ns test :no-prelude)\n"
      "(imports [prologos::core::lattice :refer [Widenable Widenable-widen Widenable-narrow Interval interval-bot mk-interval]])\n"
      "(eval (Widenable-widen Interval--Widenable--dict interval-bot interval-bot))"))
    "interval-bot"))

(test-case "Widenable-narrow accessor type-checks"
  (check-contains
    (run-ns-last (string-append
      "(ns test :no-prelude)\n"
      "(imports [prologos::core::lattice :refer [Widenable Widenable-widen Widenable-narrow Interval interval-bot mk-interval]])\n"
      "(eval (Widenable-narrow Interval--Widenable--dict interval-bot interval-bot))"))
    "interval-bot"))

;; ========================================
;; 3. Interval Widen Semantics
;; ========================================

(test-case "Interval widen: stable bounds are kept"
  ;; old=[0,100], new=[0,100] → no change, return new
  (check-contains
    (run-ns-last (string-append
      "(ns test :no-prelude)\n"
      "(imports [prologos::core::lattice :refer [Widenable Widenable-widen Widenable-narrow Interval interval-bot mk-interval]])\n"
      "(eval (Widenable-widen Interval--Widenable--dict (mk-interval 0 100) (mk-interval 0 100)))"))
    "mk-interval"))

(test-case "Interval widen: tighter lo jumps to bot"
  ;; old=[0,100], new=[10,100] → lo increased (tighter), jump to interval-bot
  (check-contains
    (run-ns-last (string-append
      "(ns test :no-prelude)\n"
      "(imports [prologos::core::lattice :refer [Widenable Widenable-widen Widenable-narrow Interval interval-bot mk-interval]])\n"
      "(eval (Widenable-widen Interval--Widenable--dict (mk-interval 0 100) (mk-interval 10 100)))"))
    "interval-bot"))

(test-case "Interval widen: tighter hi jumps to bot"
  ;; old=[0,100], new=[0,50] → hi decreased (tighter), jump to interval-bot
  (check-contains
    (run-ns-last (string-append
      "(ns test :no-prelude)\n"
      "(imports [prologos::core::lattice :refer [Widenable Widenable-widen Widenable-narrow Interval interval-bot mk-interval]])\n"
      "(eval (Widenable-widen Interval--Widenable--dict (mk-interval 0 100) (mk-interval 0 50)))"))
    "interval-bot"))

;; ========================================
;; 4. Interval Narrow Semantics
;; ========================================

(test-case "Interval narrow: intersects bounds"
  ;; old=[0,100], new=[10,50] → narrow to [10,50]
  (check-contains
    (run-ns-last (string-append
      "(ns test :no-prelude)\n"
      "(imports [prologos::core::lattice :refer [Widenable Widenable-widen Widenable-narrow Interval interval-bot mk-interval]])\n"
      "(eval (Widenable-narrow Interval--Widenable--dict (mk-interval 0 100) (mk-interval 10 50)))"))
    "mk-interval"))

;; ========================================
;; 5. Prelude Availability
;; ========================================

(test-case "Widenable-widen available from prelude"
  ;; With standard prelude, Widenable accessor should be accessible
  (check-contains
    (run-ns-last (string-append
      "(ns test)\n"
      "(eval (Widenable-widen Interval--Widenable--dict interval-bot interval-bot))"))
    "interval-bot"))

(test-case "new-widenable-cell available from prelude"
  ;; new-widenable-cell should be accessible from standard prelude
  (check-contains
    (run-ns-last (string-append
      "(ns test)\n"
      "(def net0 : PropNetwork (net-new 1000))\n"
      "(def r [new-widenable-cell net0])"))
    "defined"))
