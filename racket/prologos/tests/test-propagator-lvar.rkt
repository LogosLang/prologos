#lang racket/base

;;;
;;; Tests for PropNetwork library wrappers + HasTop + BoundedLattice
;;; Phase 3e: Lattice-aware cell creation, trait resolution, integration
;;;

(require racket/string
         racket/list
         rackunit
         "test-support.rkt"
         "../syntax.rkt"
         "../prelude.rkt"
         "../driver.rkt"
         "../global-env.rkt"
         "../errors.rkt")

;; Helper: substring match for FQN-prefixed output
(define (check-contains actual substr [msg #f])
  (define actual-str (if (string? actual) actual (format "~a" actual)))
  (check-true (string-contains? actual-str substr)
              (or msg (format "Expected ~s to contain ~s" actual-str substr))))

;; ========================================
;; HasTop trait — explicit dict passing
;; ========================================

(test-case "HasTop Bool: top = true"
  (check-equal?
   (run-ns-last "(ns ht1)\n(eval (HasTop-top Bool--HasTop--dict))")
   "true : Bool"))

(test-case "HasTop Interval: top = interval-top"
  (check-contains
   (run-ns-last "(ns ht3)\n(eval (HasTop-top Interval--HasTop--dict))")
   "interval-top"))

;; ========================================
;; BoundedLattice bundle resolution
;; ========================================

(test-case "BoundedLattice Bool resolves both Lattice and HasTop"
  ;; bot = false (from Lattice), top = true (from HasTop)
  (check-equal?
   (run-ns-last "(ns bl1)\n(eval (Lattice-bot Bool--Lattice--dict))")
   "false : Bool")
  (check-equal?
   (run-ns-last "(ns bl2)\n(eval (HasTop-top Bool--HasTop--dict))")
   "true : Bool"))

;; ========================================
;; Lattice cell creation via net-new-cell + explicit merge
;; (uses Bool lattice: bot=false, join=or)
;; ========================================

(test-case "lattice cell Bool: initial value is bot (false)"
  (check-equal?
   (run-ns-last
    (string-append
     "(ns nlc1)\n"
     "(def merge : (-> Bool (-> Bool Bool)) (fn (old : Bool) (fn (nv : Bool) (or old nv))))\n"
     "(def pair1 : (Sigma (_ : PropNetwork) CellId) (net-new-cell (net-new 1000) false merge))\n"
     "(def mynet : PropNetwork (first pair1))\n"
     "(def mycid : CellId (second pair1))\n"
     "(eval (the Bool (net-cell-read mynet mycid)))"))
   "false : Bool"))

(test-case "lattice cell Bool: write true, read back"
  (check-equal?
   (run-ns-last
    (string-append
     "(ns nlc2)\n"
     "(def merge : (-> Bool (-> Bool Bool)) (fn (old : Bool) (fn (nv : Bool) (or old nv))))\n"
     "(def pair1 : (Sigma (_ : PropNetwork) CellId) (net-new-cell (net-new 1000) false merge))\n"
     "(def net1 : PropNetwork (first pair1))\n"
     "(def cid : CellId (second pair1))\n"
     "(def net2 : PropNetwork (net-cell-write net1 cid true))\n"
     "(eval (the Bool (net-cell-read net2 cid)))"))
   "true : Bool"))

(test-case "lattice cell Bool: merge is join (or)"
  ;; Write true, then write false — should remain true (join = or)
  (check-equal?
   (run-ns-last
    (string-append
     "(ns nlc3)\n"
     "(def merge : (-> Bool (-> Bool Bool)) (fn (old : Bool) (fn (nv : Bool) (or old nv))))\n"
     "(def pair1 : (Sigma (_ : PropNetwork) CellId) (net-new-cell (net-new 1000) false merge))\n"
     "(def net1 : PropNetwork (first pair1))\n"
     "(def cid : CellId (second pair1))\n"
     "(def net2 : PropNetwork (net-cell-write net1 cid true))\n"
     "(def net3 : PropNetwork (net-cell-write net2 cid false))\n"
     "(eval (the Bool (net-cell-read net3 cid)))"))
   "true : Bool"))

;; ========================================
;; Persistence with lattice cells
;; ========================================

(test-case "lattice cell: persistence — old net has bot"
  (check-equal?
   (run-ns-last
    (string-append
     "(ns lcp1)\n"
     "(def merge : (-> Bool (-> Bool Bool)) (fn (old : Bool) (fn (nv : Bool) (or old nv))))\n"
     "(def pair1 : (Sigma (_ : PropNetwork) CellId) (net-new-cell (net-new 1000) false merge))\n"
     "(def net1 : PropNetwork (first pair1))\n"
     "(def cid : CellId (second pair1))\n"
     "(def net2 : PropNetwork (net-cell-write net1 cid true))\n"
     ";; Read from OLD network — should still be false (bot)\n"
     "(eval (the Bool (net-cell-read net1 cid)))"))
   "false : Bool"))

;; ========================================
;; net-run + net-contradict? integration
;; ========================================

(test-case "fresh lattice network: no contradiction"
  (check-equal?
   (run-ns-last
    (string-append
     "(ns nrc1)\n"
     "(def merge : (-> Bool (-> Bool Bool)) (fn (old : Bool) (fn (nv : Bool) (or old nv))))\n"
     "(def pair1 : (Sigma (_ : PropNetwork) CellId) (net-new-cell (net-new 1000) false merge))\n"
     "(def net1 : PropNetwork (first pair1))\n"
     "(def net2 : PropNetwork (net-run net1))\n"
     "(eval (net-contradict? net2))"))
   "false : Bool"))
