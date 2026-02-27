#lang racket/base

;;;
;;; Phase 6e Integration Tests: Abstract Interpretation End-to-End
;;; Tests the full stack: widening + cross-domain propagation +
;;; abstract domain library modules working together.
;;;

(require rackunit
         racket/list
         racket/string
         "test-support.rkt"
         "../propagator.rkt"
         "../champ.rkt")

;; ========================================
;; Helpers
;; ========================================

(define (check-contains actual substr [msg #f])
  (define actual-str (if (string? actual) actual (format "~a" actual)))
  (check-true (string-contains? actual-str substr)
              (or msg (format "Expected ~s to contain ~s" actual-str substr))))

;; Domain helpers for Racket-level tests
(define (max-merge old new) (max old new))
(define (or-merge old new) (or old new))
(define (iv-alpha val) (not (= val 0)))
(define (iv-gamma val) (if val +inf.0 0))

;; ========================================
;; 1. Widening + Cross-Domain Combined
;; ========================================

(test-case "e2e: widenable cell with cross-domain to bool"
  ;; Create a widenable concrete cell and link to a bool abstract cell.
  ;; Widening should force convergence, cross-domain should propagate.
  (define net0 (make-prop-network 200))
  ;; Widenable concrete cell
  (define (simple-widen old new) (if (> new old) +inf.0 new))
  (define (simple-narrow old new) (min old new))
  (define-values (net1 c-cell)
    (net-new-cell-widen net0 0 max-merge simple-widen simple-narrow))
  ;; Bool abstract cell
  (define-values (net2 a-cell) (net-new-cell net1 #f or-merge))
  ;; Cross-domain link
  (define-values (net3 _pa _pg)
    (net-add-cross-domain-propagator net2 c-cell a-cell iv-alpha iv-gamma))
  ;; Write to concrete cell
  (define net4 (net-cell-write net3 c-cell 42))
  ;; Use widening-aware fixpoint
  (define result (run-to-quiescence-widen net4))
  ;; a-cell should be true (alpha(42) = true)
  (check-equal? (net-cell-read result a-cell) #t)
  ;; Should converge (fuel not exhausted)
  (check-true (> (prop-network-fuel result) 50)))

(test-case "e2e: widenable cell widening prevents divergence with cross-domain"
  ;; Self-incrementing propagator on a widenable cell + cross-domain link.
  ;; Without widening, this would loop forever. With widening, it stabilizes.
  (define net0 (make-prop-network 300))
  (define (simple-widen old new) (if (> new old) +inf.0 new))
  (define (simple-narrow old new) (min old new))
  (define-values (net1 c-cell)
    (net-new-cell-widen net0 0 max-merge simple-widen simple-narrow))
  (define-values (net2 a-cell) (net-new-cell net1 #f or-merge))
  ;; Cross-domain
  (define-values (net3 _pa _pg)
    (net-add-cross-domain-propagator net2 c-cell a-cell iv-alpha iv-gamma))
  ;; Self-incrementing propagator on c-cell: c-cell += 1
  (define-values (net4 _p)
    (net-add-propagator net3
      (list c-cell) (list c-cell)
      (lambda (net)
        (define v (net-cell-read net c-cell))
        (net-cell-write net c-cell (+ v 1)))))
  ;; Trigger
  (define net5 (net-cell-write net4 c-cell 1))
  (define result (run-to-quiescence-widen net5))
  ;; Should converge to +inf.0 (widened) and a-cell = true
  (check-equal? (net-cell-read result a-cell) #t)
  ;; Fuel should not be exhausted
  (check-true (> (prop-network-fuel result) 100)))

;; ========================================
;; 2. Multi-Domain Diamond (Racket level)
;; ========================================

(test-case "e2e: multi-domain diamond with two abstract cells"
  ;; Concrete cell C connected to both A1 (bool) and A2 (numeric)
  ;; via different alpha/gamma pairs.
  ;; Test that changes propagate through both abstractions.
  (define net0 (make-prop-network 300))
  (define-values (net1 c-cell) (net-new-cell net0 0 max-merge))
  ;; A1: Bool abstraction
  (define-values (net2 a1) (net-new-cell net1 #f or-merge))
  ;; A2: Numeric abstraction (identity alpha/gamma with max-merge)
  (define-values (net3 a2) (net-new-cell net2 0 max-merge))
  ;; Cross-domain links
  (define-values (net4 _pa1 _pg1)
    (net-add-cross-domain-propagator net3 c-cell a1 iv-alpha iv-gamma))
  (define-values (net5 _pa2 _pg2)
    (net-add-cross-domain-propagator net4 c-cell a2
      (lambda (v) v) (lambda (v) v)))
  ;; Write 42 to c-cell
  (define net6 (net-cell-write net5 c-cell 42))
  (define result (run-to-quiescence net6))
  ;; A1 = true (bool abstraction)
  (check-equal? (net-cell-read result a1) #t)
  ;; c-cell = max(42, gamma(true), identity(a2)) = +inf.0
  (check-equal? (net-cell-read result c-cell) +inf.0)
  ;; Converges quickly
  (check-true (> (prop-network-fuel result) 200)))

;; ========================================
;; 3. Chain: C1 → A1 → C2 → A2
;; ========================================

(test-case "e2e: multi-hop chain C1→A1→C2→A2"
  (define net0 (make-prop-network 400))
  ;; Layer 1
  (define-values (net1 c1) (net-new-cell net0 0 max-merge))
  (define-values (net2 a1) (net-new-cell net1 #f or-merge))
  ;; Layer 2
  (define-values (net3 c2) (net-new-cell net2 0 max-merge))
  (define-values (net4 a2) (net-new-cell net3 #f or-merge))
  ;; Cross-domain: C1 ↔ A1
  (define-values (net5 _pa1 _pg1)
    (net-add-cross-domain-propagator net4 c1 a1 iv-alpha iv-gamma))
  ;; Bridge: A1 → C2 (if a1 true, write 100 to c2)
  (define-values (net6 _pb)
    (net-add-propagator net5
      (list a1) (list c2)
      (lambda (net)
        (if (net-cell-read net a1)
            (net-cell-write net c2 100)
            net))))
  ;; Cross-domain: C2 ↔ A2
  (define-values (net7 _pa2 _pg2)
    (net-add-cross-domain-propagator net6 c2 a2 iv-alpha iv-gamma))
  ;; Trigger: write 5 to C1
  (define net8 (net-cell-write net7 c1 5))
  (define result (run-to-quiescence net8))
  ;; C1=5 → A1=true → C2=100 → A2=true
  (check-equal? (net-cell-read result a1) #t)
  (check-equal? (net-cell-read result a2) #t)
  ;; gamma(true)=+inf.0 feeds back to both C1 and C2
  (check-equal? (net-cell-read result c1) +inf.0)
  (check-equal? (net-cell-read result c2) +inf.0))

;; ========================================
;; 4. Prologos-Level: Sign Domain Type-Checks
;; ========================================

(test-case "e2e: Sign domain loads and Lattice instance works"
  (check-contains
   (run-ns-last
    (string-append
     "(ns e2e-sign1 :no-prelude)\n"
     "(require [prologos::data::sign :refer [Sign sign-bot sign-neg sign-pos sign-top]])\n"
     "(require [prologos::core::sign-lattice :refer []])\n"
     "(require [prologos::core::lattice-trait :refer [Lattice Lattice-join]])\n"
     "(eval (Lattice-join Sign--Lattice--dict sign-neg sign-pos))\n"))
   "sign-top"))

(test-case "e2e: Parity domain loads and Lattice instance works"
  (check-contains
   (run-ns-last
    (string-append
     "(ns e2e-parity1 :no-prelude)\n"
     "(require [prologos::data::parity :refer [Parity parity-bot parity-even parity-odd parity-top]])\n"
     "(require [prologos::core::parity-lattice :refer []])\n"
     "(require [prologos::core::lattice-trait :refer [Lattice Lattice-join]])\n"
     "(eval (Lattice-join Parity--Lattice--dict parity-even parity-odd))\n"))
   "parity-top"))

;; ========================================
;; 5. GaloisConnection + Cross-Domain at Prologos Level
;; ========================================

(test-case "e2e: GaloisConnection Interval Bool alpha via prelude"
  ;; Test that the GaloisConnection trait and instances are usable from prelude context
  (check-contains
   (run-ns-last
    (string-append
     "(ns e2e-gc1)\n"
     "(require [prologos::core::galois-trait :refer [GaloisConnection GaloisConnection-alpha]])\n"
     "(require [prologos::core::galois-instances :refer []])\n"
     "(require [prologos::core::lattice-instances :refer [Interval mk-interval]])\n"
     "(eval (GaloisConnection-alpha Interval-Bool--GaloisConnection--dict (mk-interval 1 10)))\n"))
   "true"))

(test-case "e2e: GaloisConnection Interval Bool gamma via prelude"
  (check-contains
   (run-ns-last
    (string-append
     "(ns e2e-gc2)\n"
     "(require [prologos::core::galois-trait :refer [GaloisConnection GaloisConnection-gamma]])\n"
     "(require [prologos::core::galois-instances :refer []])\n"
     "(require [prologos::core::lattice-instances :refer [Interval interval-bot interval-top]])\n"
     "(eval (GaloisConnection-gamma Interval-Bool--GaloisConnection--dict true))\n"))
   "interval-top"))

;; ========================================
;; 6. Widenable Trait at Prologos Level
;; ========================================

(test-case "e2e: Widenable-widen Interval accessible via prelude"
  (check-contains
   (run-ns-last
    (string-append
     "(ns e2e-widen1)\n"
     "(require [prologos::core::widenable-trait :refer [Widenable Widenable-widen]])\n"
     "(require [prologos::core::widenable-instances :refer []])\n"
     "(require [prologos::core::lattice-instances :refer [Interval interval-bot mk-interval]])\n"
     ";; widen(bot, mk-interval 1 10) = mk-interval 1 10 (old=bot means new passes through)\n"
     "(eval (Widenable-widen Interval--Widenable--dict interval-bot (mk-interval 1 10)))\n"))
   "mk-interval"))

(test-case "e2e: Widenable-narrow Interval accessible via prelude"
  (check-contains
   (run-ns-last
    (string-append
     "(ns e2e-narrow1)\n"
     "(require [prologos::core::widenable-trait :refer [Widenable Widenable-narrow]])\n"
     "(require [prologos::core::widenable-instances :refer []])\n"
     "(require [prologos::core::lattice-instances :refer [Interval interval-bot mk-interval]])\n"
     ";; narrow(mk-interval 1 10, bot) = mk-interval 1 10 (new=bot means old preserved)\n"
     "(eval (Widenable-narrow Interval--Widenable--dict (mk-interval 1 10) interval-bot))\n"))
   "mk-interval"))

;; ========================================
;; 7. BSP Scheduler with Full Stack
;; ========================================

(test-case "e2e: BSP scheduler with cross-domain and widening"
  (define net0 (make-prop-network 300))
  (define (simple-widen old new) (if (> new old) +inf.0 new))
  (define (simple-narrow old new) (min old new))
  (define-values (net1 c-cell)
    (net-new-cell-widen net0 0 max-merge simple-widen simple-narrow))
  (define-values (net2 a-cell) (net-new-cell net1 #f or-merge))
  (define-values (net3 _pa _pg)
    (net-add-cross-domain-propagator net2 c-cell a-cell iv-alpha iv-gamma))
  (define net4 (net-cell-write net3 c-cell 10))
  ;; BSP scheduler should handle widening cells + cross-domain correctly
  (define result (run-to-quiescence-bsp net4))
  (check-equal? (net-cell-read result a-cell) #t)
  (check-equal? (net-cell-read result c-cell) +inf.0))

;; ========================================
;; 8. Large Network Convergence
;; ========================================

(test-case "e2e: 10-cell chain converges without exhausting fuel"
  ;; Build a chain of 10 concrete cells connected sequentially
  ;; via copy propagators. First cell triggers the chain.
  (define net0 (make-prop-network 500))
  ;; Create 10 cells
  (define-values (net-final cells)
    (for/fold ([net net0] [cs '()])
              ([_ (in-range 10)])
      (define-values (n c) (net-new-cell net 0 max-merge))
      (values n (cons c cs))))
  (define cells-vec (list->vector (reverse cells)))
  ;; Chain propagators: cell[i] → cell[i+1] (copy value)
  (define net-chained
    (for/fold ([net net-final])
              ([i (in-range 9)])
      (define src (vector-ref cells-vec i))
      (define dst (vector-ref cells-vec (+ i 1)))
      (define-values (n _p)
        (net-add-propagator net
          (list src) (list dst)
          (lambda (net)
            (net-cell-write net dst (net-cell-read net src)))))
      n))
  ;; Trigger: write 42 to first cell
  (define net-triggered (net-cell-write net-chained (vector-ref cells-vec 0) 42))
  (define result (run-to-quiescence net-triggered))
  ;; All cells should have 42
  (for ([i (in-range 10)])
    (check-equal? (net-cell-read result (vector-ref cells-vec i)) 42
                  (format "cell ~a should be 42" i)))
  ;; Should converge quickly (10 propagators fire once each)
  (check-true (> (prop-network-fuel result) 400)))
