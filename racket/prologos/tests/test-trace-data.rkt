#lang racket/base

;;;
;;; test-trace-data.rkt — Tests for Visualization Phase 0 trace data types
;;;
;;; Validates: struct construction, transparency/equality, field access,
;;; ATMS event hierarchy, prop-trace assembly.
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
