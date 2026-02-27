#lang racket/base

;;;
;;; Tests for Phase 6a: Widening-Aware Fixpoint (Racket level)
;;; Tests: widen-fns struct field, widening-point registration,
;;; net-cell-write-widen, convergence, narrowing precision recovery,
;;; max-rounds safety limit.
;;;

(require rackunit
         racket/list
         racket/match
         "../propagator.rkt"
         "../champ.rkt")

;; ========================================
;; Helpers
;; ========================================

;; Simple max-merge for Nat-like cells
(define (max-merge old new) (max old new))

;; A "counter" propagator: reads src, writes (src + 1) to dst.
;; Without widening, this diverges.
(define (make-counter-fire-fn src-id dst-id)
  (lambda (net)
    (define val (net-cell-read net src-id))
    (net-cell-write net dst-id (+ val 1))))

;; Interval-like widening: if new > old, jump to +inf.0
(define (simple-widen old new)
  (if (> new old) +inf.0 new))

;; Narrowing: take min of old and new
(define (simple-narrow old new)
  (min old new))

;; ========================================
;; 1. Struct Field Defaults
;; ========================================

(test-case "widen-fns field defaults to empty champ"
  (define net (make-prop-network 100))
  (define wfns (prop-network-widen-fns net))
  (check-true (champ-empty? wfns)))

;; ========================================
;; 2. Widen-Point Registration
;; ========================================

(test-case "net-set-widen-point marks a cell"
  (define-values (net0 cid)
    (net-new-cell (make-prop-network 100) 0 max-merge))
  (define net1 (net-set-widen-point net0 cid simple-widen simple-narrow))
  (check-true (net-widen-point? net1 cid)))

(test-case "net-widen-point? returns #f for unmarked cells"
  (define-values (net0 cid)
    (net-new-cell (make-prop-network 100) 0 max-merge))
  (check-false (net-widen-point? net0 cid)))

(test-case "net-new-cell-widen creates AND marks cell"
  (define-values (net cid)
    (net-new-cell-widen (make-prop-network 100)
                        0 max-merge simple-widen simple-narrow))
  (check-true (net-widen-point? net cid))
  (check-equal? (net-cell-read net cid) 0))

;; ========================================
;; 3. net-cell-write-widen
;; ========================================

(test-case "net-cell-write-widen applies widen at widening point"
  (define-values (net0 cid)
    (net-new-cell-widen (make-prop-network 100)
                        0 max-merge simple-widen simple-narrow))
  ;; Write 5 — merge(0,5)=5, widen(0,5)=+inf (since 5>0)
  (define net1 (net-cell-write-widen net0 cid 5))
  (check-equal? (net-cell-read net1 cid) +inf.0))

(test-case "net-cell-write-widen no-ops for non-widening cells"
  (define-values (net0 cid)
    (net-new-cell (make-prop-network 100) 0 max-merge))
  ;; Normal cell: merge(0,5)=5, no widening applied
  (define net1 (net-cell-write-widen net0 cid 5))
  (check-equal? (net-cell-read net1 cid) 5))

(test-case "net-cell-write-widen no-change guard"
  ;; If widen(old, merged) = old, no change -> no worklist additions
  (define-values (net0 cid)
    (net-new-cell-widen (make-prop-network 100)
                        +inf.0 max-merge simple-widen simple-narrow))
  (define net1 (net-cell-write-widen net0 cid 5))
  ;; merge(+inf, 5) = +inf, widen(+inf, +inf) = +inf -> no change
  (check-equal? (net-cell-read net1 cid) +inf.0)
  (check-true (null? (prop-network-worklist net1))))

;; ========================================
;; 4. Convergence with Widening
;; ========================================

(test-case "divergent counter converges with widening"
  ;; Setup: cell A (seed=1), cell B (widening point, init=0)
  ;; Propagator: reads A, writes A to B  (so B should get 1)
  ;; Then: reads B, writes B+1 to B      (loop: B->2->3->... diverges without widening)
  ;; With widening: B jumps to +inf.0 after first increase
  (define net0 (make-prop-network 1000))
  (define-values (net1 a-id) (net-new-cell net0 1 max-merge))
  (define-values (net2 b-id)
    (net-new-cell-widen net1 0 max-merge simple-widen simple-narrow))
  ;; Propagator: copy A -> B
  (define-values (net3 _p1)
    (net-add-propagator net2
      (list a-id) (list b-id)
      (lambda (net)
        (define a (net-cell-read net a-id))
        (net-cell-write net b-id a))))
  ;; Propagator: B -> B+1 (self-loop)
  (define-values (net4 _p2)
    (net-add-propagator net3
      (list b-id) (list b-id)
      (lambda (net)
        (define b (net-cell-read net b-id))
        (if (and (number? b) (< b 1000))
            (net-cell-write net b-id (+ b 1))
            net))))
  (define result (run-to-quiescence-widen net4))
  ;; Widen phase pushes B to +inf.0; narrow phase recovers precision.
  ;; narrow(+inf.0, 1) = min(+inf.0, 1) = 1, and the self-loop's
  ;; attempt to increment is blocked by narrowing (min(1, 2) = 1).
  ;; So B converges to 1.0 (inexact from min with +inf.0).
  (define b-val (net-cell-read result b-id))
  (check-true (and (number? b-val) (< b-val +inf.0))
              (format "B should be finite, got ~a" b-val))
  ;; Should not have exhausted fuel
  (check-true (> (prop-network-fuel result) 0)))

;; ========================================
;; 5. Narrowing Precision Recovery
;; ========================================

(test-case "narrowing recovers precision after widening"
  ;; Cell A (seed=100), cell B (widening point, init=0)
  ;; Propagator: copy A -> B
  ;; Widen phase: B gets 100, widen(0,100) = +inf.0
  ;; Narrow phase: propagator fires again -> raw value 100
  ;;   narrow(+inf.0, 100) = min(+inf.0, 100) = 100.0
  (define net0 (make-prop-network 1000))
  (define-values (net1 a-id) (net-new-cell net0 100 max-merge))
  (define-values (net2 b-id)
    (net-new-cell-widen net1 0 max-merge simple-widen simple-narrow))
  (define-values (net3 _p)
    (net-add-propagator net2
      (list a-id) (list b-id)
      (lambda (net)
        (define a (net-cell-read net a-id))
        (net-cell-write net b-id a))))
  (define result (run-to-quiescence-widen net3))
  ;; After narrowing, B should be 100.0 (inexact due to min with +inf.0)
  (check-equal? (net-cell-read result b-id) 100.0))

;; ========================================
;; 6. Max-Rounds Safety
;; ========================================

(test-case "max-rounds limits narrow iterations"
  ;; A narrow-fn that always changes: narrow(old, new) = old - 1
  ;; This would loop forever without the max-rounds limit.
  (define (shrink-narrow old new) (- old 1))
  (define net0 (make-prop-network 10000))
  (define-values (net1 a-id) (net-new-cell net0 1 max-merge))
  (define-values (net2 b-id)
    (net-new-cell-widen net1 0 max-merge simple-widen shrink-narrow))
  (define-values (net3 _p)
    (net-add-propagator net2
      (list a-id) (list b-id)
      (lambda (net)
        (define a (net-cell-read net a-id))
        (net-cell-write net b-id a))))
  ;; max-rounds = 5 should terminate without burning all fuel
  (define result (run-to-quiescence-widen net3 #:max-rounds 5))
  (check-true (> (prop-network-fuel result) 0)))

;; ========================================
;; 7. No-Widening-Points: Same as run-to-quiescence
;; ========================================

(test-case "run-to-quiescence-widen works with no widening points"
  (define net0 (make-prop-network 100))
  (define-values (net1 a-id) (net-new-cell net0 0 max-merge))
  (define-values (net2 b-id) (net-new-cell net1 0 max-merge))
  (define-values (net3 _p)
    (net-add-propagator net2
      (list a-id) (list b-id)
      (lambda (net)
        (define a (net-cell-read net a-id))
        (net-cell-write net b-id a))))
  (define net4 (net-cell-write net3 a-id 42))
  (define result (run-to-quiescence-widen net4))
  (check-equal? (net-cell-read result b-id) 42))

;; ========================================
;; 8. Interval Domain Helpers (Racket-level unit tests)
;; ========================================

(test-case "Interval widen: bounds tightening jumps to unconstrained"
  ;; Interval uses constraint ordering: bot = unconstrained (-inf, +inf)
  ;; widen(old, new): if new is tighter (lo increased or hi decreased), jump to bot
  (define (iv-widen old new)
    ;; Simplified interval widen for testing
    (cond [(equal? old '(bot)) new]
          [(equal? new '(bot)) '(bot)]
          [else
           (match-let ([(list lo1 hi1) old]
                       [(list lo2 hi2) new])
             (if (or (> lo2 lo1) (< hi2 hi1))
                 '(bot)  ;; Relax to unconstrained
                 new))]))
  ;; old=[0,100], new=[10,100] — lo tightened
  (check-equal? (iv-widen '(0 100) '(10 100)) '(bot))
  ;; old=[0,100], new=[0,50] — hi tightened
  (check-equal? (iv-widen '(0 100) '(0 50)) '(bot))
  ;; old=[0,100], new=[0,100] — no change
  (check-equal? (iv-widen '(0 100) '(0 100)) '(0 100))
  ;; old=[10,90], new=[0,100] — relaxed both — no jump
  (check-equal? (iv-widen '(10 90) '(0 100)) '(0 100)))

(test-case "Interval narrow: tighten to more constrained bounds"
  (define (iv-narrow old new)
    (cond [(equal? old '(bot)) new]
          [(equal? new '(bot)) old]
          [else
           (match-let ([(list lo1 hi1) old]
                       [(list lo2 hi2) new])
             (list (max lo1 lo2) (min hi1 hi2)))]))
  ;; old=[0,100], new=[10,50] — tighten both bounds
  (check-equal? (iv-narrow '(0 100) '(10 50)) '(10 50))
  ;; old=(bot), new=[10,50] — adopt new
  (check-equal? (iv-narrow '(bot) '(10 50)) '(10 50)))
