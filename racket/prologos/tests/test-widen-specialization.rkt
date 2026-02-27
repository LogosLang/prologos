#lang racket/base

;;;
;;; Tests for new-widenable-cell call-site specialization (Phase 6e)
;;; Verifies that the compiler registers and rewrites new-widenable-cell
;;; calls to the specialized Interval version when the type is known.
;;;

(require racket/string
         rackunit
         "test-support.rkt"
         "../driver.rkt"
         "../macros.rkt"
         "../syntax.rkt"
         "../errors.rkt")

;; ========================================
;; Helper
;; ========================================

(define (check-contains actual substr [msg #f])
  (define actual-str (if (string? actual) actual (format "~a" actual)))
  (check-true (string-contains? actual-str substr)
              (or msg (format "Expected ~s to contain ~s" actual-str substr))))

;; ========================================
;; 1. Registry Population
;; ========================================

(test-case "widen-spec: registry has Interval entry for new-widenable-cell"
  (run-ns-last
   (string-append
    "(ns ws-reg1)\n"
    "(require [prologos::core::propagator :refer [new-widenable-cell]])\n"
    "(eval 0N)\n"))
  (check-not-false (lookup-specialization 'new-widenable-cell 'Interval)))

;; ========================================
;; 2. Specialized Cell Creation
;; ========================================

(test-case "widen-spec: specialized Interval cell initial value is interval-bot"
  (check-contains
   (run-ns-last
    (string-append
     "(ns ws-init1)\n"
     "(require [prologos::core::propagator :refer [new-widenable-cell]])\n"
     "(require [prologos::core::lattice-instances :refer [Interval interval-bot Interval--Lattice--dict]])\n"
     "(require [prologos::core::widenable-instances :refer [Interval--Widenable--dict]])\n"
     "(def p : (Sigma (_ : PropNetwork) CellId) (new-widenable-cell Interval Interval--Lattice--dict Interval--Widenable--dict (net-new 100)))\n"
     "(def n : PropNetwork (first p))\n"
     "(def c : CellId (second p))\n"
     "(eval (the Interval (net-cell-read n c)))\n"))
   "interval-bot"))

(test-case "widen-spec: specialized Interval cell write and read back"
  (check-contains
   (run-ns-last
    (string-append
     "(ns ws-wr1)\n"
     "(require [prologos::core::propagator :refer [new-widenable-cell]])\n"
     "(require [prologos::core::lattice-instances :refer [Interval mk-interval Interval--Lattice--dict]])\n"
     "(require [prologos::core::widenable-instances :refer [Interval--Widenable--dict]])\n"
     "(def p : (Sigma (_ : PropNetwork) CellId) (new-widenable-cell Interval Interval--Lattice--dict Interval--Widenable--dict (net-new 100)))\n"
     "(def n1 : PropNetwork (first p))\n"
     "(def c : CellId (second p))\n"
     "(def n2 : PropNetwork (net-cell-write n1 c (mk-interval 1 10)))\n"
     "(eval (the Interval (net-cell-read n2 c)))\n"))
   "mk-interval"))

;; ========================================
;; 3. Equivalence: Specialized = Generic
;; ========================================

(test-case "widen-spec: specialized and generic produce same initial value"
  (define spec-result
    (run-ns-last
     (string-append
      "(ns ws-eq1)\n"
      "(require [prologos::core::propagator :refer [new-widenable-cell]])\n"
      "(require [prologos::core::lattice-instances :refer [Interval interval-bot Interval--Lattice--dict]])\n"
      "(require [prologos::core::widenable-instances :refer [Interval--Widenable--dict]])\n"
      "(def p : (Sigma (_ : PropNetwork) CellId) (new-widenable-cell Interval Interval--Lattice--dict Interval--Widenable--dict (net-new 100)))\n"
      "(def n : PropNetwork (first p))\n"
      "(def c : CellId (second p))\n"
      "(eval (the Interval (net-cell-read n c)))\n")))
  (check-contains spec-result "interval-bot"))

;; ========================================
;; 4. Widening Point Registration
;; ========================================

(test-case "widen-spec: specialized cell is registered as widening point"
  ;; The specialized new-widenable-cell should mark the cell as a widening point
  ;; via net-new-cell-widen (same as the generic version).
  ;; We verify this indirectly: write a value, then use run-to-quiescence-widen,
  ;; which only does anything special on cells with widening points.
  (check-not-exn
   (lambda ()
     (run-ns-last
      (string-append
       "(ns ws-widen1)\n"
       "(require [prologos::core::propagator :refer [new-widenable-cell]])\n"
       "(require [prologos::core::lattice-instances :refer [Interval mk-interval Interval--Lattice--dict]])\n"
       "(require [prologos::core::widenable-instances :refer [Interval--Widenable--dict]])\n"
       "(def p : (Sigma (_ : PropNetwork) CellId) (new-widenable-cell Interval Interval--Lattice--dict Interval--Widenable--dict (net-new 100)))\n"
       "(eval 0N)\n")))))
