#lang racket/base

;;;
;;; Tests for call-site specialization rewriting (HKT-8 Phase 2)
;;; Verifies that the compiler rewrites generic function calls to
;;; specialized zero-overhead versions when types are statically known.
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
;; 1. Registry population
;; ========================================

(test-case "specialization registry has Bool entry after propagator load"
  (run-ns-last
   (string-append
    "(ns cs-reg1)\n"
    "(require [prologos::core::propagator :refer [new-lattice-cell]])\n"
    "(eval 0N)\n"))
  (check-not-false (lookup-specialization 'new-lattice-cell 'Bool)))

(test-case "specialization registry has Interval entry after propagator load"
  (run-ns-last
   (string-append
    "(ns cs-reg2)\n"
    "(require [prologos::core::propagator :refer [new-lattice-cell]])\n"
    "(eval 0N)\n"))
  (check-not-false (lookup-specialization 'new-lattice-cell 'Interval)))

;; ========================================
;; 2. Specialization semantics: Bool
;; ========================================

(test-case "specialized Bool cell: create, write true, read back"
  (check-equal?
   (run-ns-last
    (string-append
     "(ns cs-bool1)\n"
     "(require [prologos::core::propagator :refer [new-lattice-cell]])\n"
     "(def p : (Sigma (_ : PropNetwork) CellId) (new-lattice-cell Bool Bool--Lattice--dict (net-new 100)))\n"
     "(def n : PropNetwork (first p))\n"
     "(def c : CellId (second p))\n"
     "(def n2 : PropNetwork (net-cell-write n c true))\n"
     "(eval (the Bool (net-cell-read n2 c)))\n"))
   "true : Bool"))

(test-case "specialized Bool cell: merge (false join true = true)"
  (check-equal?
   (run-ns-last
    (string-append
     "(ns cs-bool2)\n"
     "(require [prologos::core::propagator :refer [new-lattice-cell]])\n"
     "(def p : (Sigma (_ : PropNetwork) CellId) (new-lattice-cell Bool Bool--Lattice--dict (net-new 100)))\n"
     "(def n1 : PropNetwork (first p))\n"
     "(def c : CellId (second p))\n"
     "(def n2 : PropNetwork (net-cell-write n1 c false))\n"
     "(def n3 : PropNetwork (net-cell-write n2 c true))\n"
     "(eval (the Bool (net-cell-read n3 c)))\n"))
   "true : Bool"))

;; ========================================
;; 3. Specialization semantics: Interval
;; ========================================

(test-case "specialized Interval cell: create, initial value is interval-bot"
  (check-contains
   (run-ns-last
    (string-append
     "(ns cs-interval1)\n"
     "(require [prologos::core::propagator :refer [new-lattice-cell]])\n"
     "(require [prologos::core::lattice-instances :refer [Interval interval-bot Interval--Lattice--dict]])\n"
     "(def p : (Sigma (_ : PropNetwork) CellId) (new-lattice-cell Interval Interval--Lattice--dict (net-new 100)))\n"
     "(def n : PropNetwork (first p))\n"
     "(def c : CellId (second p))\n"
     "(eval (the Interval (net-cell-read n c)))\n"))
   "interval-bot"))

;; ========================================
;; 4. Fallback: no specialization for unknown type
;; ========================================

(test-case "generic call works when no specialization exists"
  ;; FlatVal has no specialization registered; dict-passing fallback is used
  (check-not-exn
   (lambda ()
     (run-ns-last
      (string-append
       "(ns cs-fallback1)\n"
       "(require [prologos::core::lattice-trait :refer-all])\n"
       "(require [prologos::core::lattice-instances :refer []])\n"
       "(spec nlc {A} PropNetwork -> (PropNetwork * CellId) where (Lattice A))\n"
       "(defn nlc [net] where (Lattice A) (net-new-cell net bot (fn (x : _) (y : _) (join x y))))\n"
       "(def p : (Sigma (_ : PropNetwork) CellId) (nlc Bool Bool--Lattice--dict (net-new 100)))\n"
       "(eval 0N)\n")))))

;; ========================================
;; 5. Fast path: empty registry
;; ========================================

(test-case "rewrite-specializations fast path: empty registry returns expr unchanged"
  ;; Create a simple expression and verify no rewriting happens with empty registry
  (parameterize ([current-specialization-registry (hash)])
    (define e (expr-app (expr-fvar 'foo) (expr-Bool)))
    (check-equal? (rewrite-specializations e) e)))

;; ========================================
;; 6. Equivalence: specialized = generic result
;; ========================================

(test-case "specialized and generic new-lattice-cell produce equivalent results"
  ;; Both should create a Bool cell, write true, and read back true
  (define specialized-result
    (run-ns-last
     (string-append
      "(ns cs-equiv1)\n"
      "(require [prologos::core::propagator :refer [new-lattice-cell]])\n"
      "(def p : (Sigma (_ : PropNetwork) CellId) (new-lattice-cell Bool Bool--Lattice--dict (net-new 100)))\n"
      "(def n : PropNetwork (first p))\n"
      "(def c : CellId (second p))\n"
      "(def n2 : PropNetwork (net-cell-write n c true))\n"
      "(eval (the Bool (net-cell-read n2 c)))\n")))
  (define generic-result
    (run-ns-last
     (string-append
      "(ns cs-equiv2)\n"
      "(require [prologos::core::lattice-trait :refer-all])\n"
      "(require [prologos::core::lattice-instances :refer []])\n"
      "(spec nlc {A} PropNetwork -> (PropNetwork * CellId) where (Lattice A))\n"
      "(defn nlc [net] where (Lattice A) (net-new-cell net bot (fn (x : _) (y : _) (join x y))))\n"
      "(def p : (Sigma (_ : PropNetwork) CellId) (nlc Bool Bool--Lattice--dict (net-new 100)))\n"
      "(def n : PropNetwork (first p))\n"
      "(def c : CellId (second p))\n"
      "(def n2 : PropNetwork (net-cell-write n c true))\n"
      "(eval (the Bool (net-cell-read n2 c)))\n")))
  (check-equal? specialized-result generic-result))
