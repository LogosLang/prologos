#lang racket/base

;;;
;;; Tests for new-lattice-cell generic wrapper
;;; Dict-passing across closures, trait resolution, E2E propagator integration
;;;

(require racket/string
         rackunit
         "test-support.rkt"
         "../driver.rkt"
         "../macros.rkt"
         "../errors.rkt")

;; ========================================
;; Helper
;; ========================================

(define (check-contains actual substr [msg #f])
  (define actual-str (if (string? actual) actual (format "~a" actual)))
  (check-true (string-contains? actual-str substr)
              (or msg (format "Expected ~s to contain ~s" actual-str substr))))

;; ========================================
;; Module loading
;; ========================================

(test-case "propagator module loads with new-lattice-cell export"
  (check-not-exn
   (lambda ()
     (run-ns-last
      (string-append
       "(ns nlc-load)\n"
       "(require [prologos::core::propagator :refer [new-lattice-cell]])\n"
       "(eval 0N)\n")))))

;; ========================================
;; Type inference
;; ========================================

(test-case "new-lattice-cell has correct polymorphic type"
  ;; Verify spec+defn compiles without error — type-checking validates the polymorphic type
  (check-not-exn
   (lambda ()
     (run-ns-last
      (string-append
       "(ns nlc-type)\n"
       "(require [prologos::core::lattice :refer-all])\n"
       "(spec nlc {A} PropNetwork -> (PropNetwork * CellId) where (Lattice A))\n"
       "(defn nlc [net] where (Lattice A) (net-new-cell net bot (fn (x : _) (y : _) (join x y))))\n"
       "(eval 0N)\n")))))

;; ========================================
;; Bare method resolution
;; ========================================

(test-case "bot resolves via where-context to Lattice-bot"
  ;; In a where(Lattice A) body, bare `bot` resolves to Lattice-bot accessor
  (check-contains
   (run-ns-last
    (string-append
     "(ns nlc-bot)\n"
     "(require [prologos::core::lattice :refer-all])\n"
     "(spec get-bot {A} A -> A where (Lattice A))\n"
     "(defn get-bot [x] where (Lattice A) bot)\n"
     "(eval (get-bot Bool Bool--Lattice--dict true))\n"))
   "false"))

(test-case "join resolves via where-context to Lattice-join"
  (check-contains
   (run-ns-last
    (string-append
     "(ns nlc-join)\n"
     "(require [prologos::core::lattice :refer-all])\n"
     "(spec my-join {A} A A -> A where (Lattice A))\n"
     "(defn my-join [x y] where (Lattice A) (join x y))\n"
     "(eval (my-join Bool Bool--Lattice--dict false true))\n"))
   "true"))

;; ========================================
;; E2E: Bool lattice
;; ========================================

(test-case "new-lattice-cell Bool: create cell, initial value is bot (false)"
  (check-equal?
   (run-ns-last
    (string-append
     "(ns nlc-bool1)\n"
     "(require [prologos::core::lattice :refer-all])\n"
     "(spec nlc {A} PropNetwork -> (PropNetwork * CellId) where (Lattice A))\n"
     "(defn nlc [net] where (Lattice A) (net-new-cell net bot (fn (x : _) (y : _) (join x y))))\n"
     "(def pair1 : (Sigma (_ : PropNetwork) CellId) (nlc Bool Bool--Lattice--dict (net-new 1000)))\n"
     "(def mynet : PropNetwork (first pair1))\n"
     "(def mycid : CellId (second pair1))\n"
     "(eval (the Bool (net-cell-read mynet mycid)))\n"))
   "false : Bool"))

(test-case "new-lattice-cell Bool: write true, read back"
  (check-equal?
   (run-ns-last
    (string-append
     "(ns nlc-bool2)\n"
     "(require [prologos::core::lattice :refer-all])\n"
     "(spec nlc {A} PropNetwork -> (PropNetwork * CellId) where (Lattice A))\n"
     "(defn nlc [net] where (Lattice A) (net-new-cell net bot (fn (x : _) (y : _) (join x y))))\n"
     "(def pair1 : (Sigma (_ : PropNetwork) CellId) (nlc Bool Bool--Lattice--dict (net-new 1000)))\n"
     "(def net1 : PropNetwork (first pair1))\n"
     "(def cid : CellId (second pair1))\n"
     "(def net2 : PropNetwork (net-cell-write net1 cid true))\n"
     "(eval (the Bool (net-cell-read net2 cid)))\n"))
   "true : Bool"))

(test-case "new-lattice-cell Bool: join merges correctly (false join true = true)"
  (check-equal?
   (run-ns-last
    (string-append
     "(ns nlc-bool3)\n"
     "(require [prologos::core::lattice :refer-all])\n"
     "(spec nlc {A} PropNetwork -> (PropNetwork * CellId) where (Lattice A))\n"
     "(defn nlc [net] where (Lattice A) (net-new-cell net bot (fn (x : _) (y : _) (join x y))))\n"
     "(def p : (Sigma (_ : PropNetwork) CellId) (nlc Bool Bool--Lattice--dict (net-new 1000)))\n"
     "(def n1 : PropNetwork (first p))\n"
     "(def c : CellId (second p))\n"
     ;; Write false first (no-op since bot is false), then write true
     "(def n2 : PropNetwork (net-cell-write n1 c false))\n"
     "(def n3 : PropNetwork (net-cell-write n2 c true))\n"
     "(eval (the Bool (net-cell-read n3 c)))\n"))
   "true : Bool"))

;; ========================================
;; E2E: prelude-loaded new-lattice-cell
;; ========================================

(test-case "new-lattice-cell from prelude: Bool via explicit dict"
  (check-equal?
   (run-ns-last
    (string-append
     "(ns nlc-prelude1)\n"
     "(require [prologos::core::propagator :refer [new-lattice-cell]])\n"
     "(def p : (Sigma (_ : PropNetwork) CellId) (new-lattice-cell Bool Bool--Lattice--dict (net-new 1000)))\n"
     "(def n1 : PropNetwork (first p))\n"
     "(def c : CellId (second p))\n"
     "(def n2 : PropNetwork (net-cell-write n1 c true))\n"
     "(eval (the Bool (net-cell-read n2 c)))\n"))
   "true : Bool"))

;; ========================================
;; Equivalence with manual net-new-cell
;; ========================================

(test-case "new-lattice-cell produces same result as manual net-new-cell"
  ;; Both create a Bool cell, write true, read back
  (define generic-result
    (run-ns-last
     (string-append
      "(ns nlc-equiv1)\n"
      "(require [prologos::core::lattice :refer-all])\n"
      "(spec nlc {A} PropNetwork -> (PropNetwork * CellId) where (Lattice A))\n"
      "(defn nlc [net] where (Lattice A) (net-new-cell net bot (fn (x : _) (y : _) (join x y))))\n"
      "(def p : (Sigma (_ : PropNetwork) CellId) (nlc Bool Bool--Lattice--dict (net-new 1000)))\n"
      "(def n : PropNetwork (first p))\n"
      "(def c : CellId (second p))\n"
      "(def n2 : PropNetwork (net-cell-write n c true))\n"
      "(eval (the Bool (net-cell-read n2 c)))\n")))
  (define manual-result
    (run-ns-last
     (string-append
      "(ns nlc-equiv2)\n"
      "(def merge : (-> Bool (-> Bool Bool)) (fn (old : Bool) (fn (nv : Bool) (or old nv))))\n"
      "(def p : (Sigma (_ : PropNetwork) CellId) (net-new-cell (net-new 1000) false merge))\n"
      "(def n : PropNetwork (first p))\n"
      "(def c : CellId (second p))\n"
      "(def n2 : PropNetwork (net-cell-write n c true))\n"
      "(eval (the Bool (net-cell-read n2 c)))\n")))
  (check-equal? generic-result manual-result))

;; ========================================
;; Closure capture: join inside fn
;; ========================================

(test-case "dict-passing: join resolves in where-context body"
  ;; Demonstrates that `join` from the where-context resolves correctly
  ;; when called as a first-class method inside a dict-constrained function.
  ;; Closure capture of dict across lambda boundaries is proven by the E2E
  ;; tests above (new-lattice-cell uses `[fn x y [join x y]]` which captures $Lattice-A).
  (check-contains
   (run-ns-last
    (string-append
     "(ns nlc-dictpass)\n"
     "(require [prologos::core::lattice :refer-all])\n"
     "(spec generic-join {A} A A -> A where (Lattice A))\n"
     "(defn generic-join [x y] where (Lattice A) (join x y))\n"
     "(eval (generic-join Bool Bool--Lattice--dict false true))\n"))
   "true"))
