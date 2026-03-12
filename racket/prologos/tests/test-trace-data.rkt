#lang racket/base

;;;
;;; test-trace-data.rkt — Tests for Visualization Phase 0-1 trace data types & capture
;;;
;;; Validates: struct construction, transparency/equality, field access,
;;; ATMS event hierarchy, prop-trace assembly, BSP observer capture.
;;;

(require rackunit
         "../propagator.rkt")

;; ========================================
;; cell-diff
;; ========================================

(test-case "cell-diff: construction and field access"
  (define cd (cell-diff (cell-id 0) 'bot 42 (prop-id 3)))
  (check-true (cell-diff? cd))
  (check-equal? (cell-diff-cell-id cd) (cell-id 0))
  (check-equal? (cell-diff-old-value cd) 'bot)
  (check-equal? (cell-diff-new-value cd) 42)
  (check-equal? (cell-diff-source-propagator cd) (prop-id 3)))

(test-case "cell-diff: transparency / structural equality"
  (check-equal? (cell-diff (cell-id 1) 'a 'b (prop-id 2))
                (cell-diff (cell-id 1) 'a 'b (prop-id 2)))
  (check-not-equal? (cell-diff (cell-id 1) 'a 'b (prop-id 2))
                    (cell-diff (cell-id 1) 'a 'c (prop-id 2))))

;; ========================================
;; atms-event hierarchy
;; ========================================

(test-case "atms-event: base struct"
  (define e (atms-event))
  (check-true (atms-event? e)))

(test-case "atms-event:assume"
  (define e (atms-event:assume (cell-id 5) 'alpha))
  (check-true (atms-event? e))
  (check-true (atms-event:assume? e))
  (check-equal? (atms-event:assume-cell-id e) (cell-id 5))
  (check-equal? (atms-event:assume-assumption-label e) 'alpha))

(test-case "atms-event:retract"
  (define e (atms-event:retract (cell-id 7) 'beta 'contradiction))
  (check-true (atms-event? e))
  (check-true (atms-event:retract? e))
  (check-equal? (atms-event:retract-cell-id e) (cell-id 7))
  (check-equal? (atms-event:retract-assumption-label e) 'beta)
  (check-equal? (atms-event:retract-reason e) 'contradiction))

(test-case "atms-event:nogood"
  (define e (atms-event:nogood '(a1 a2 a3) '(c1 c2)))
  (check-true (atms-event? e))
  (check-true (atms-event:nogood? e))
  (check-equal? (atms-event:nogood-nogood-set e) '(a1 a2 a3))
  (check-equal? (atms-event:nogood-explanation e) '(c1 c2)))

(test-case "atms-event: structural equality"
  (check-equal? (atms-event:assume (cell-id 1) 'x)
                (atms-event:assume (cell-id 1) 'x))
  (check-not-equal? (atms-event:assume (cell-id 1) 'x)
                    (atms-event:retract (cell-id 1) 'x 'r)))

;; ========================================
;; bsp-round
;; ========================================

(test-case "bsp-round: construction and field access"
  (define net (make-prop-network))
  (define diffs (list (cell-diff (cell-id 0) 'bot 10 (prop-id 0))))
  (define fired (list (prop-id 0) (prop-id 1)))
  (define events (list (atms-event:assume (cell-id 0) 'a1)))
  (define r (bsp-round 0 net diffs fired #f events))
  (check-true (bsp-round? r))
  (check-equal? (bsp-round-round-number r) 0)
  (check-equal? (bsp-round-network-snapshot r) net)
  (check-equal? (bsp-round-cell-diffs r) diffs)
  (check-equal? (bsp-round-propagators-fired r) fired)
  (check-false (bsp-round-contradiction r))
  (check-equal? (bsp-round-atms-events r) events))

(test-case "bsp-round: with contradiction"
  (define r (bsp-round 3 (make-prop-network) '() '() (cell-id 42) '()))
  (check-equal? (bsp-round-contradiction r) (cell-id 42)))

;; ========================================
;; prop-trace
;; ========================================

(test-case "prop-trace: construction and field access"
  (define net0 (make-prop-network))
  (define net1 (make-prop-network 500))
  (define rounds (list (bsp-round 0 net0 '() '() #f '())
                       (bsp-round 1 net1 '() '() #f '())))
  (define meta (hasheq 'file "test.prologos" 'fuel-used 100))
  (define tr (prop-trace net0 rounds net1 meta))
  (check-true (prop-trace? tr))
  (check-equal? (prop-trace-initial-network tr) net0)
  (check-equal? (length (prop-trace-rounds tr)) 2)
  (check-equal? (prop-trace-final-network tr) net1)
  (check-equal? (hash-ref (prop-trace-metadata tr) 'file) "test.prologos"))

(test-case "prop-trace: structural equality"
  (define net (make-prop-network))
  (define t1 (prop-trace net '() net (hasheq)))
  (define t2 (prop-trace net '() net (hasheq)))
  (check-equal? t1 t2))

;; ========================================
;; Phase 1: BSP Observer Capture
;; ========================================

(test-case "make-trace-accumulator: basic accumulation"
  (define-values (observe get-rounds) (make-trace-accumulator))
  (define net (make-prop-network))
  (define r0 (bsp-round 0 net '() '() #f '()))
  (define r1 (bsp-round 1 net '() '() #f '()))
  (observe r0)
  (observe r1)
  (define rounds (get-rounds))
  (check-equal? (length rounds) 2)
  (check-equal? (bsp-round-round-number (car rounds)) 0)
  (check-equal? (bsp-round-round-number (cadr rounds)) 1))

(test-case "current-bsp-observer: default is #f (zero cost)"
  (check-false (current-bsp-observer)))

(test-case "BSP observer: captures rounds during propagation"
  ;; Build a simple network: cell A -> propagator -> cell B
  ;; Propagator copies A's value to B
  (define-values (observe get-rounds) (make-trace-accumulator))
  (define net0 (make-prop-network))
  (define-values (net1 cid-a) (net-new-cell net0 'bot (lambda (old new) new)))
  (define-values (net2 cid-b) (net-new-cell net1 'bot (lambda (old new) new)))
  (define (copy-a-to-b net)
    (define a-val (net-cell-read net cid-a))
    (if (eq? a-val 'bot)
        net
        (net-cell-write net cid-b a-val)))
  (define-values (net3 pid) (net-add-propagator net2 (list cid-a) (list cid-b) copy-a-to-b))
  ;; Write to cell A to trigger propagation
  (define net4 (net-cell-write net3 cid-a 42))
  ;; Run with observer
  (define final
    (parameterize ([current-bsp-observer observe])
      (run-to-quiescence-bsp net4)))
  (define rounds (get-rounds))
  ;; Should have at least 1 round (propagator fires, writes to B)
  (check-true (>= (length rounds) 1))
  ;; First round should have round-number 0
  (check-equal? (bsp-round-round-number (car rounds)) 0)
  ;; First round should have cell-diffs (B changed from bot to 42)
  (define diffs (bsp-round-cell-diffs (car rounds)))
  (check-true (>= (length diffs) 1))
  ;; Verify the diff records the change
  (define b-diff (findf (lambda (d) (equal? (cell-diff-cell-id d) cid-b)) diffs))
  (check-true (cell-diff? b-diff))
  (check-equal? (cell-diff-old-value b-diff) 'bot)
  (check-equal? (cell-diff-new-value b-diff) 42)
  (check-equal? (cell-diff-source-propagator b-diff) pid)
  ;; Final network should have B = 42
  (check-equal? (net-cell-read final cid-b) 42))

(test-case "BSP observer: no observer = no overhead"
  ;; Run without observer — should work identically
  (define net0 (make-prop-network))
  (define-values (net1 cid-a) (net-new-cell net0 'bot (lambda (old new) new)))
  (define-values (net2 cid-b) (net-new-cell net1 'bot (lambda (old new) new)))
  (define (copy-a-to-b net)
    (define a-val (net-cell-read net cid-a))
    (if (eq? a-val 'bot) net (net-cell-write net cid-b a-val)))
  (define-values (net3 pid) (net-add-propagator net2 (list cid-a) (list cid-b) copy-a-to-b))
  (define net4 (net-cell-write net3 cid-a 99))
  (define final (run-to-quiescence-bsp net4))
  (check-equal? (net-cell-read final cid-b) 99))

(test-case "BSP observer: multi-round propagation"
  ;; Chain: A -> P1 -> B -> P2 -> C
  ;; Should produce 2 rounds of propagation
  (define-values (observe get-rounds) (make-trace-accumulator))
  (define net0 (make-prop-network))
  (define-values (net1 cid-a) (net-new-cell net0 'bot (lambda (old new) new)))
  (define-values (net2 cid-b) (net-new-cell net1 'bot (lambda (old new) new)))
  (define-values (net3 cid-c) (net-new-cell net2 'bot (lambda (old new) new)))
  (define (copy-a-to-b net)
    (define v (net-cell-read net cid-a))
    (if (eq? v 'bot) net (net-cell-write net cid-b v)))
  (define (copy-b-to-c net)
    (define v (net-cell-read net cid-b))
    (if (eq? v 'bot) net (net-cell-write net cid-c v)))
  (define-values (net4 _p1) (net-add-propagator net3 (list cid-a) (list cid-b) copy-a-to-b))
  (define-values (net5 _p2) (net-add-propagator net4 (list cid-b) (list cid-c) copy-b-to-c))
  (define net6 (net-cell-write net5 cid-a 7))
  (define final
    (parameterize ([current-bsp-observer observe])
      (run-to-quiescence-bsp net6)))
  (define rounds (get-rounds))
  ;; Round 0: P1 fires (A->B), Round 1: P2 fires (B->C)
  (check-equal? (length rounds) 2)
  (check-equal? (bsp-round-round-number (car rounds)) 0)
  (check-equal? (bsp-round-round-number (cadr rounds)) 1)
  (check-equal? (net-cell-read final cid-c) 7))
