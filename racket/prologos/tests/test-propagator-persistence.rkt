#lang racket/base

;;;
;;; Tests for Phase 2d-2e: Propagator Network — Quiescence, Persistence, Backtracking
;;; Tests: run-to-quiescence, fuel limits, contradiction, persistence guarantees,
;;; backtracking, LVar-style cells.
;;;

(require rackunit
         racket/list
         "../propagator.rkt"
         "../champ.rkt")

;; ========================================
;; Test Merge Functions
;; ========================================

(define (flat-merge old new)
  (cond [(eq? old 'bot) new]
        [(eq? new 'bot) old]
        [(equal? old new) old]
        [else 'top]))

(define (flat-contradicts? v) (eq? v 'top))

(define (max-merge old new) (max old new))

(define (set-merge old new)
  (remove-duplicates (append old new)))

;; Map merge: accumulate key-value pairs (simple alist-based)
(define (map-merge old new)
  (define (assoc-merge alist k v)
    (cond [(null? alist) (list (cons k v))]
          [(equal? (caar alist) k)
           (cons (cons k (max (cdar alist) v)) (cdr alist))]
          [else (cons (car alist) (assoc-merge (cdr alist) k v))]))
  (for/fold ([acc old]) ([entry (in-list new)])
    (assoc-merge acc (car entry) (cdr entry))))

;; ========================================
;; Helpers
;; ========================================

(define (make-copy-fire-fn src-id dst-id)
  (lambda (net)
    (define val (net-cell-read net src-id))
    (if (eq? val 'bot)
        net
        (net-cell-write net dst-id val))))

;; ========================================
;; 1. Run to Quiescence — Basic
;; ========================================

(test-case "quiescence: simple chain converges"
  (define net0 (make-prop-network))
  (define-values (net1 ca) (net-new-cell net0 'bot flat-merge))
  (define-values (net2 cb) (net-new-cell net1 'bot flat-merge))
  (define-values (net3 _pid)
    (net-add-propagator net2 (list ca) (list cb)
                        (make-copy-fire-fn ca cb)))
  (define net4 (run-to-quiescence (net-cell-write net3 ca 'hello)))
  (check-true (net-quiescent? net4))
  (check-equal? (net-cell-read net4 cb) 'hello))

(test-case "quiescence: empty worklist returns immediately"
  (define net (make-prop-network))
  (define net1 (run-to-quiescence net))
  (check-true (net-quiescent? net1))
  (check-eq? net net1 "should return same network object"))

(test-case "quiescence: idempotent on already-quiescent network"
  (define net0 (make-prop-network))
  (define-values (net1 ca) (net-new-cell net0 'bot flat-merge))
  (define-values (net2 cb) (net-new-cell net1 'bot flat-merge))
  (define-values (net3 _pid)
    (net-add-propagator net2 (list ca) (list cb)
                        (make-copy-fire-fn ca cb)))
  (define net4 (run-to-quiescence (net-cell-write net3 ca 42)))
  (define net5 (run-to-quiescence net4))
  (check-eq? net4 net5 "re-running should return same network"))

;; ========================================
;; 2. Multi-Step Convergence
;; ========================================

(test-case "convergence: chain of 5 cells"
  (define net0 (make-prop-network))
  (define-values (net1 c0) (net-new-cell net0 'bot flat-merge))
  (define-values (net2 c1) (net-new-cell net1 'bot flat-merge))
  (define-values (net3 c2) (net-new-cell net2 'bot flat-merge))
  (define-values (net4 c3) (net-new-cell net3 'bot flat-merge))
  (define-values (net5 c4) (net-new-cell net4 'bot flat-merge))
  (define-values (net6 _p1) (net-add-propagator net5 (list c0) (list c1) (make-copy-fire-fn c0 c1)))
  (define-values (net7 _p2) (net-add-propagator net6 (list c1) (list c2) (make-copy-fire-fn c1 c2)))
  (define-values (net8 _p3) (net-add-propagator net7 (list c2) (list c3) (make-copy-fire-fn c2 c3)))
  (define-values (net9 _p4) (net-add-propagator net8 (list c3) (list c4) (make-copy-fire-fn c3 c4)))
  (define result (run-to-quiescence (net-cell-write net9 c0 'propagated)))
  (check-equal? (net-cell-read result c4) 'propagated))

;; ========================================
;; 3. Fuel Limit
;; ========================================

(test-case "fuel: exhausted stops execution"
  ;; Create a propagator that always generates new work (non-monotone for testing)
  ;; by writing an incrementing value. This would loop forever without fuel.
  (define net0 (make-prop-network 10))  ;; only 10 steps
  (define-values (net1 ca) (net-new-cell net0 0 max-merge))
  (define-values (net2 _pid)
    (net-add-propagator net1 (list ca) (list ca)
      (lambda (net)
        ;; Always increase by 1 — creates infinite work
        (net-cell-write net ca (+ 1 (net-cell-read net ca))))))
  (define result (run-to-quiescence net2))
  ;; Should have stopped due to fuel, not infinite loop
  (check-true (<= (net-fuel-remaining result) 0)
              "fuel should be exhausted"))

(test-case "fuel: normal network uses minimal fuel"
  (define net0 (make-prop-network 1000))
  (define-values (net1 ca) (net-new-cell net0 'bot flat-merge))
  (define-values (net2 cb) (net-new-cell net1 'bot flat-merge))
  (define-values (net3 _pid)
    (net-add-propagator net2 (list ca) (list cb)
                        (make-copy-fire-fn ca cb)))
  (define result (run-to-quiescence (net-cell-write net3 ca 42)))
  ;; Should use very little fuel for a simple chain
  (check-true (> (net-fuel-remaining result) 990)
              "simple chain should use minimal fuel"))

;; ========================================
;; 4. Contradiction Halts Execution
;; ========================================

(test-case "contradiction: halts run-to-quiescence"
  (define net0 (make-prop-network))
  (define-values (net1 ca)
    (net-new-cell net0 'bot flat-merge flat-contradicts?))
  (define-values (net2 cb) (net-new-cell net1 'bot flat-merge))
  ;; Propagator that writes contradictory values
  (define-values (net3 _pid)
    (net-add-propagator net2 (list ca) (list ca)
      (lambda (net)
        ;; Write a different value to cause contradiction (1 ≠ existing → top)
        (net-cell-write net ca 2))))
  ;; Write 1 to A, the propagator will try to write 2 → flat-merge(1,2) = 'top
  (define net4 (net-cell-write net3 ca 1))
  (define result (run-to-quiescence net4))
  (check-true (net-contradiction? result))
  (check-equal? (prop-network-contradiction result) ca))

(test-case "contradiction: propagators after contradiction are not fired"
  (define net0 (make-prop-network))
  (define-values (net1 ca)
    (net-new-cell net0 'bot flat-merge flat-contradicts?))
  (define-values (net2 cb) (net-new-cell net1 'bot flat-merge))
  ;; First: write value to A
  (define net3 (net-cell-write net2 ca 1))
  ;; Then write contradictory value → contradiction
  (define net4 (net-cell-write net3 ca 2))
  (check-true (net-contradiction? net4))
  ;; run-to-quiescence on contradicted network returns immediately
  (define net5 (run-to-quiescence net4))
  (check-true (net-contradiction? net5)))

;; ========================================
;; 5. Persistence Guarantees
;; ========================================

(test-case "persistence: old network unchanged after cell write"
  (define net0 (make-prop-network))
  (define-values (net1 ca) (net-new-cell net0 'bot flat-merge))
  (define net2 (net-cell-write net1 ca 42))
  ;; net1 should still have 'bot
  (check-equal? (net-cell-read net1 ca) 'bot)
  ;; net2 should have 42
  (check-equal? (net-cell-read net2 ca) 42))

(test-case "persistence: old network unchanged after adding propagator"
  (define net0 (make-prop-network))
  (define-values (net1 ca) (net-new-cell net0 'bot flat-merge))
  (define-values (net2 cb) (net-new-cell net1 'bot flat-merge))
  (define-values (net3 _pid)
    (net-add-propagator net2 (list ca) (list cb)
                        (make-copy-fire-fn ca cb)))
  ;; net2 should still have no propagators in worklist
  (check-true (net-quiescent? net2))
  ;; net3 should have propagator in worklist
  (check-false (net-quiescent? net3)))

(test-case "persistence: old network unchanged after run-to-quiescence"
  (define net0 (make-prop-network))
  (define-values (net1 ca) (net-new-cell net0 'bot flat-merge))
  (define-values (net2 cb) (net-new-cell net1 'bot flat-merge))
  (define-values (net3 _pid)
    (net-add-propagator net2 (list ca) (list cb)
                        (make-copy-fire-fn ca cb)))
  (define net4 (net-cell-write net3 ca 42))
  (define net5 (run-to-quiescence net4))
  ;; net4 should still have B as 'bot (not yet propagated)
  (check-equal? (net-cell-read net4 cb) 'bot)
  ;; net5 should have B as 42
  (check-equal? (net-cell-read net5 cb) 42))

;; ========================================
;; 6. Backtracking
;; ========================================

(test-case "backtracking: reuse pre-contradiction network"
  (define net0 (make-prop-network))
  (define-values (net1 ca)
    (net-new-cell net0 'bot flat-merge flat-contradicts?))
  ;; Good path
  (define net2 (net-cell-write net1 ca 42))
  (check-false (net-contradiction? net2))
  (check-equal? (net-cell-read net2 ca) 42)
  ;; Bad path (contradiction)
  (define net3 (net-cell-write net2 ca 99))  ;; 42 ≠ 99 → top
  (check-true (net-contradiction? net3))
  ;; Backtrack: net2 is still perfectly valid
  (check-false (net-contradiction? net2))
  (check-equal? (net-cell-read net2 ca) 42))

(test-case "backtracking: multiple branches from same point"
  (define net0 (make-prop-network))
  (define-values (net1 ca) (net-new-cell net0 0 max-merge))
  ;; Branch 1: write 10
  (define net-branch1 (net-cell-write net1 ca 10))
  ;; Branch 2: write 20 (from the same base)
  (define net-branch2 (net-cell-write net1 ca 20))
  ;; Both branches independent
  (check-equal? (net-cell-read net-branch1 ca) 10)
  (check-equal? (net-cell-read net-branch2 ca) 20)
  ;; Base unchanged
  (check-equal? (net-cell-read net1 ca) 0))

;; ========================================
;; 7. LVar-Style Cells
;; ========================================

(test-case "lvar-style: set cell accumulates elements"
  (define net0 (make-prop-network))
  (define-values (net1 cid) (net-new-cell net0 '() set-merge))
  (define net2 (net-cell-write net1 cid '(a)))
  (define net3 (net-cell-write net2 cid '(b)))
  (define net4 (net-cell-write net3 cid '(a c)))
  (define result (sort (net-cell-read net4 cid) symbol<?))
  (check-equal? result '(a b c)))

(test-case "lvar-style: set cell is monotonic (re-adding is no-op)"
  (define net0 (make-prop-network))
  (define-values (net1 cid) (net-new-cell net0 '() set-merge))
  (define net2 (net-cell-write net1 cid '(a b)))
  (define net3 (net-cell-write net2 cid '(a)))  ;; subset — no new info
  ;; Should be the same network (no change)
  (check-eq? net2 net3 "re-adding existing elements should not change net"))

(test-case "lvar-style: map cell with pointwise join"
  (define net0 (make-prop-network))
  (define-values (net1 cid) (net-new-cell net0 '() map-merge))
  (define net2 (net-cell-write net1 cid '((x . 1) (y . 2))))
  (define net3 (net-cell-write net2 cid '((x . 5) (z . 3))))
  (define result (net-cell-read net3 cid))
  ;; x should be max(1,5)=5, y stays 2, z is 3
  (check-equal? (cdr (assoc 'x result)) 5)
  (check-equal? (cdr (assoc 'y result)) 2)
  (check-equal? (cdr (assoc 'z result)) 3))

;; ========================================
;; 8. Snapshot (Identity)
;; ========================================

(test-case "snapshot: network IS already persistent"
  ;; No separate snapshot operation needed — keeping a reference IS a snapshot
  (define net0 (make-prop-network))
  (define-values (net1 ca) (net-new-cell net0 0 max-merge))
  (define snapshot net1)  ;; "snapshot" = binding the reference
  (define net2 (net-cell-write net1 ca 42))
  ;; Snapshot is unchanged
  (check-equal? (net-cell-read snapshot ca) 0)
  (check-equal? (net-cell-read net2 ca) 42))
