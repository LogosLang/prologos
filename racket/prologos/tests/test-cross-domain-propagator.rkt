#lang racket/base

;;;
;;; Tests for Phase 6c: Cross-Domain Propagation (Racket level)
;;; Tests: alpha/gamma directions, bidirectional, no-change guard,
;;; BSP compatibility, chains/diamonds.
;;;

(require rackunit
         racket/list
         "../propagator.rkt"
         "../champ.rkt")

;; ========================================
;; Domain Helpers
;; ========================================

;; "Interval-like" concrete domain (max-merge, numbers)
(define (max-merge old new) (max old new))

;; "Bool-like" abstract domain (or-merge, #f = bot)
(define (or-merge old new) (or old new))

;; Interval→Bool alpha: 0 = unconstrained (false), anything else = constrained (true)
(define (iv-alpha val)
  (not (= val 0)))

;; Bool→Interval gamma: false = 0 (unconstrained), true = +inf.0 (most constrained)
(define (iv-gamma val)
  (if val +inf.0 0))

;; ========================================
;; 1. Alpha Direction: C → A
;; ========================================

(test-case "alpha propagation: c-cell change updates a-cell"
  (define net0 (make-prop-network 100))
  (define-values (net1 c-cell) (net-new-cell net0 0 max-merge))
  (define-values (net2 a-cell) (net-new-cell net1 #f or-merge))
  (define-values (net3 _p-alpha _p-gamma)
    (net-add-cross-domain-propagator net2 c-cell a-cell iv-alpha iv-gamma))
  ;; Write 42 to c-cell
  (define net4 (net-cell-write net3 c-cell 42))
  (define result (run-to-quiescence net4))
  ;; a-cell should be #t (alpha(42) = true)
  (check-equal? (net-cell-read result a-cell) #t))

;; ========================================
;; 2. Gamma Direction: A → C
;; ========================================

(test-case "gamma propagation: a-cell change updates c-cell"
  (define net0 (make-prop-network 100))
  (define-values (net1 c-cell) (net-new-cell net0 0 max-merge))
  (define-values (net2 a-cell) (net-new-cell net1 #f or-merge))
  (define-values (net3 _p-alpha _p-gamma)
    (net-add-cross-domain-propagator net2 c-cell a-cell iv-alpha iv-gamma))
  ;; Write #t to a-cell
  (define net4 (net-cell-write net3 a-cell #t))
  (define result (run-to-quiescence net4))
  ;; c-cell should be +inf.0 (gamma(true) = +inf.0, max(0, +inf.0) = +inf.0)
  (check-equal? (net-cell-read result c-cell) +inf.0))

;; ========================================
;; 3. Bidirectional
;; ========================================

(test-case "bidirectional: c-cell write propagates to a-cell and back stabilizes"
  (define net0 (make-prop-network 100))
  (define-values (net1 c-cell) (net-new-cell net0 0 max-merge))
  (define-values (net2 a-cell) (net-new-cell net1 #f or-merge))
  (define-values (net3 _p-alpha _p-gamma)
    (net-add-cross-domain-propagator net2 c-cell a-cell iv-alpha iv-gamma))
  ;; Write 42 to c-cell
  (define net4 (net-cell-write net3 c-cell 42))
  (define result (run-to-quiescence net4))
  ;; a-cell = true, c-cell = max(42, gamma(true)) = max(42, +inf.0) = +inf.0
  (check-equal? (net-cell-read result a-cell) #t)
  (check-equal? (net-cell-read result c-cell) +inf.0)
  ;; Should not exhaust fuel (converges quickly)
  (check-true (> (prop-network-fuel result) 50)))

;; ========================================
;; 4. No-Change Guard
;; ========================================

(test-case "no-change: writing same value doesn't trigger propagation"
  (define net0 (make-prop-network 100))
  (define-values (net1 c-cell) (net-new-cell net0 0 max-merge))
  (define-values (net2 a-cell) (net-new-cell net1 #f or-merge))
  (define-values (net3 _p-alpha _p-gamma)
    (net-add-cross-domain-propagator net2 c-cell a-cell iv-alpha iv-gamma))
  ;; Write 0 to c-cell (same as init) → alpha(0) = false, same as a-cell init
  (define net4 (net-cell-write net3 c-cell 0))
  (define result (run-to-quiescence net4))
  ;; Nothing should change
  (check-equal? (net-cell-read result c-cell) 0)
  (check-equal? (net-cell-read result a-cell) #f))

;; ========================================
;; 5. Chain Topology: C1 → A1 → C2
;; ========================================

(test-case "chain: two cross-domain connections in sequence"
  ;; C1 ←→ A1, then A1 → C2 via a copy propagator
  (define net0 (make-prop-network 200))
  (define-values (net1 c1) (net-new-cell net0 0 max-merge))
  (define-values (net2 a1) (net-new-cell net1 #f or-merge))
  (define-values (net3 c2) (net-new-cell net2 0 max-merge))
  ;; Cross-domain: C1 ←→ A1
  (define-values (net4 _p1 _p2)
    (net-add-cross-domain-propagator net3 c1 a1 iv-alpha iv-gamma))
  ;; Copy: A1 → C2 (if a1 is true, write 999 to c2)
  (define-values (net5 _p3)
    (net-add-propagator net4
      (list a1) (list c2)
      (lambda (net)
        (if (net-cell-read net a1)
            (net-cell-write net c2 999)
            net))))
  ;; Trigger: write 42 to C1
  (define net6 (net-cell-write net5 c1 42))
  (define result (run-to-quiescence net6))
  ;; C1=42→alpha→A1=true→copy→C2=999
  ;; Plus gamma(true)=+inf.0 back to C1
  (check-equal? (net-cell-read result a1) #t)
  (check-equal? (net-cell-read result c2) 999)
  (check-equal? (net-cell-read result c1) +inf.0))

;; ========================================
;; 6. Diamond Topology: C ←→ A1, C ←→ A2
;; ========================================

(test-case "diamond: one concrete cell connected to two abstract cells"
  ;; Two different abstractions of the same concrete cell
  (define net0 (make-prop-network 200))
  (define-values (net1 c-cell) (net-new-cell net0 0 max-merge))
  (define-values (net2 a1) (net-new-cell net1 #f or-merge))
  (define-values (net3 a2) (net-new-cell net2 0 max-merge))
  ;; Alpha1: 0→false, else→true (Bool abstraction)
  (define-values (net4 _pa1 _pg1)
    (net-add-cross-domain-propagator net3 c-cell a1 iv-alpha iv-gamma))
  ;; Alpha2: identity (numeric abstraction)
  (define-values (net5 _pa2 _pg2)
    (net-add-cross-domain-propagator net4 c-cell a2
      (lambda (v) v)      ;; alpha = identity
      (lambda (v) v)))    ;; gamma = identity
  ;; Write 42 to c-cell
  (define net6 (net-cell-write net5 c-cell 42))
  (define result (run-to-quiescence net6))
  ;; a1 = true (Bool abstraction), a2 = max(42, +inf.0) = +inf.0
  ;; c-cell = max(42, gamma(true), +inf.0) = +inf.0
  (check-equal? (net-cell-read result a1) #t)
  (check-equal? (net-cell-read result c-cell) +inf.0))

;; ========================================
;; 7. BSP Compatibility
;; ========================================

(test-case "cross-domain works with BSP scheduler"
  (define net0 (make-prop-network 200))
  (define-values (net1 c-cell) (net-new-cell net0 0 max-merge))
  (define-values (net2 a-cell) (net-new-cell net1 #f or-merge))
  (define-values (net3 _p1 _p2)
    (net-add-cross-domain-propagator net2 c-cell a-cell iv-alpha iv-gamma))
  (define net4 (net-cell-write net3 c-cell 10))
  (define result (run-to-quiescence-bsp net4))
  (check-equal? (net-cell-read result a-cell) #t)
  (check-equal? (net-cell-read result c-cell) +inf.0))

;; ========================================
;; 8. With Widening
;; ========================================

(test-case "cross-domain with widening-aware fixpoint"
  (define net0 (make-prop-network 200))
  (define (simple-widen old new) (if (> new old) +inf.0 new))
  (define (simple-narrow old new) (min old new))
  (define-values (net1 c-cell)
    (net-new-cell-widen net0 0 max-merge simple-widen simple-narrow))
  (define-values (net2 a-cell) (net-new-cell net1 #f or-merge))
  (define-values (net3 _p1 _p2)
    (net-add-cross-domain-propagator net2 c-cell a-cell iv-alpha iv-gamma))
  (define net4 (net-cell-write net3 c-cell 10))
  (define result (run-to-quiescence-widen net4))
  (check-equal? (net-cell-read result a-cell) #t))
