#lang racket/base

;;; bench-subtype.rkt — Micro-benchmarks for SRE structural subtype checking
;;;
;;; SRE Track 1B Phase 1: Measures per-check overhead for flat vs structural
;;; subtype checks at various nesting depths.

(require racket/format
         "../../subtype-predicate.rkt"
         "../../syntax.rkt"
         "../../type-lattice.rkt")

;; Simple bench macro: run N warmup + N measured iterations, report mean μs
(define-syntax-rule (bench label body)
  (let ()
    ;; Warmup
    (for ([_ (in-range 100)]) body)
    ;; Measure
    (define N 10000)
    (collect-garbage)
    (define start (current-inexact-milliseconds))
    (for ([_ (in-range N)]) body)
    (define end (current-inexact-milliseconds))
    (define mean-us (* 1000.0 (/ (- end start) N)))
    (printf "~a: ~a μs/call (~a calls)\n" label (~r mean-us #:precision '(= 2)) N)))

(displayln "=== SRE Subtype Micro-Benchmarks ===\n")

;; A. Flat subtype (fast path, no cells)
(bench "flat: Nat <: Int"
  (subtype? (expr-Nat) (expr-Int)))

(bench "flat: Int <: Rat"
  (subtype? (expr-Int) (expr-Rat)))

(bench "flat: equal (Int <: Int, reflexive)"
  (subtype? (expr-Int) (expr-Int)))

(bench "flat: NOT (Int <: Nat)"
  (subtype? (expr-Int) (expr-Nat)))

;; B. Structural subtype 1-level (query pattern)
(bench "structural-1: PVec Nat <: PVec Int"
  (subtype? (expr-PVec (expr-Nat)) (expr-PVec (expr-Int))))

(bench "structural-1: Set Nat <: Set Int"
  (subtype? (expr-Set (expr-Nat)) (expr-Set (expr-Int))))

(bench "structural-1: Map String Nat <: Map String Int"
  (subtype? (expr-Map (expr-tycon 'String) (expr-Nat))
            (expr-Map (expr-tycon 'String) (expr-Int))))

;; C. Structural subtype 2-level (nested compound)
(bench "structural-2: PVec (PVec Nat) <: PVec (PVec Int)"
  (subtype? (expr-PVec (expr-PVec (expr-Nat)))
            (expr-PVec (expr-PVec (expr-Int)))))

;; D. Pi subtype with variance (contravariant domain, covariant codomain)
(bench "Pi subtype: (Int -> Nat) <: (Nat -> Int)"
  (subtype? (expr-Pi 'mw (expr-Int) (expr-Nat))
            (expr-Pi 'mw (expr-Nat) (expr-Int))))

(bench "Pi subtype: (Nat -> Nat) <: (Nat -> Int)"
  (subtype? (expr-Pi 'mw (expr-Nat) (expr-Nat))
            (expr-Pi 'mw (expr-Nat) (expr-Int))))

;; E. Negative cases (should return #f quickly)
(bench "structural-NOT: PVec Int <: PVec Nat"
  (subtype? (expr-PVec (expr-Int)) (expr-PVec (expr-Nat))))

(bench "structural-NOT: Map Int Nat <: Map String Nat (key invariant)"
  (subtype? (expr-Map (expr-tycon 'Int) (expr-Nat))
            (expr-Map (expr-tycon 'String) (expr-Nat))))

;; F. Adversarial: deeply nested
(define (make-nested-pvec depth base)
  (if (zero? depth) base
      (expr-PVec (make-nested-pvec (sub1 depth) base))))

(bench "adversarial: PVec^5 Nat <: PVec^5 Int"
  (subtype? (make-nested-pvec 5 (expr-Nat))
            (make-nested-pvec 5 (expr-Int))))

(bench "adversarial: PVec^10 Nat <: PVec^10 Int"
  (subtype? (make-nested-pvec 10 (expr-Nat))
            (make-nested-pvec 10 (expr-Int))))

;; G. Report frequency
(report-subtype-frequency!)
