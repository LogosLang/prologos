#lang racket/base

;;;
;;; test-effect-ordering-01.rkt — AD-D: Effect Ordering tests
;;;
;;; Tests for data-flow edge extraction (AD-D1), ordering propagator (AD-D2),
;;; and effect linearization integration (AD-D3).
;;;
;;; Pattern: Direct struct construction, no shared fixtures, no process-string.
;;;

(require rackunit
         racket/file
         racket/list
         "../effect-bridge.rkt"
         "../effect-ordering.rkt"
         "../effect-position.rkt"
         "../io-bridge.rkt"
         "../processes.rkt"
         "../propagator.rkt"
         "../sessions.rkt"
         "../session-lattice.rkt"
         "../session-runtime.rkt"
         "../syntax.rkt")


;; ========================================
;; Group 1: Free Variable Extraction
;; ========================================

(test-case "free-variables: literal string has no free vars"
  (check-equal? (free-variables-in-expr (expr-string "hello")) '()))

(test-case "free-variables: expr-fvar has one free var"
  (check-equal? (free-variables-in-expr (expr-fvar 'x)) '(x)))

(test-case "free-variables: raw symbol is a free var"
  (check-equal? (free-variables-in-expr 'content) '(content)))

(test-case "free-variables: expr-app collects vars from both sides"
  (define e (expr-app (expr-fvar 'f) (expr-fvar 'x)))
  (define vars (free-variables-in-expr e))
  (check-not-false (member 'f vars) "should include f")
  (check-not-false (member 'x vars) "should include x"))

(test-case "free-variables: nested expr-app deduplicates"
  ;; (f x x) → 'f and 'x, each once
  (define e (expr-app (expr-app (expr-fvar 'f) (expr-fvar 'x)) (expr-fvar 'x)))
  (define vars (free-variables-in-expr e))
  (check-equal? (length vars) 2)
  (check-not-false (member 'f vars))
  (check-not-false (member 'x vars)))

(test-case "free-variables: literal nat has no free vars"
  (check-equal? (free-variables-in-expr (expr-nat-val 42)) '()))

(test-case "free-variables: pair collects vars from both components"
  (define e (expr-pair (expr-fvar 'a) (expr-fvar 'b)))
  (define vars (free-variables-in-expr e))
  (check-equal? (length vars) 2)
  (check-not-false (member 'a vars))
  (check-not-false (member 'b vars)))


;; ========================================
;; Group 2: Session Ordering Edges
;; ========================================

(test-case "session-ordering-edges: sess-end → no edges"
  (check-equal? (session-ordering-edges 'ch (sess-end)) '()))

(test-case "session-ordering-edges: single step → no edges"
  ;; !String.end → 1 step, 0 edges
  (check-equal? (session-ordering-edges 'ch (sess-send (expr-String) (sess-end))) '()))

(test-case "session-ordering-edges: two steps → one edge"
  ;; !String.?Int.end → 2 steps, 1 edge: (ch,0) < (ch,1)
  (define sess (sess-send (expr-String) (sess-recv (expr-Int) (sess-end))))
  (define edges (session-ordering-edges 'a sess))
  (check-equal? (length edges) 1)
  (check-equal? (car edges) (eff-edge (eff-pos 'a 0) (eff-pos 'a 1))))

(test-case "session-ordering-edges: three steps → two edges"
  ;; !S.?S.!S.end → 3 steps, edges: (ch,0)<(ch,1), (ch,1)<(ch,2)
  (define sess (sess-send (expr-String)
                 (sess-recv (expr-String)
                   (sess-send (expr-String) (sess-end)))))
  (define edges (session-ordering-edges 'x sess))
  (check-equal? (length edges) 2)
  (check-equal? (car edges) (eff-edge (eff-pos 'x 0) (eff-pos 'x 1)))
  (check-equal? (cadr edges) (eff-edge (eff-pos 'x 1) (eff-pos 'x 2))))


;; ========================================
;; Group 3: Data-Flow Edge Extraction
;; ========================================

(test-case "data-flow: no cross-channel deps → no edges"
  ;; send "hello" on ch, stop — no recv, no data flow
  (define proc (proc-send (expr-string "hello") 'ch (proc-stop)))
  (check-equal? (extract-data-flow-edges proc) '()))

(test-case "data-flow: same-channel recv→send → no cross-channel edges"
  ;; recv on ch, then send the received value on ch — same channel
  (define proc
    (proc-recv 'ch 'x (expr-String)
      (proc-send (expr-fvar 'x) 'ch (proc-stop))))
  (check-equal? (extract-data-flow-edges proc) '()))

(test-case "data-flow: cross-channel recv→send → one edge"
  ;; recv 'content on channel 'a, send 'content on channel 'b
  ;; Creates edge: (a, 0) < (b, 0)
  (define proc
    (proc-recv 'a 'content (expr-String)
      (proc-send (expr-fvar 'content) 'b (proc-stop))))
  ;; Need to start with both channels at depth 0
  (define edges (extract-data-flow-edges proc (hasheq 'a 0 'b 0) (hasheq)))
  (check-equal? (length edges) 1)
  (check-equal? (car edges) (eff-edge (eff-pos 'a 0) (eff-pos 'b 0))))

(test-case "data-flow: cross-channel at deeper depths"
  ;; recv on 'a (depth 0), then recv on 'a (depth 1, binds 'y'),
  ;; then send 'y on 'b (depth 0) → edge: (a, 1) < (b, 0)
  (define proc
    (proc-recv 'a 'x (expr-String)
      (proc-recv 'a 'y (expr-String)
        (proc-send (expr-fvar 'y) 'b (proc-stop)))))
  (define edges (extract-data-flow-edges proc (hasheq 'a 0 'b 0) (hasheq)))
  (check-equal? (length edges) 1)
  (check-equal? (car edges) (eff-edge (eff-pos 'a 1) (eff-pos 'b 0))))

(test-case "data-flow: multiple cross-channel edges"
  ;; recv 'x on 'a, recv 'y on 'b, send 'x on 'c, send 'y on 'c
  ;; Edges: (a,0)<(c,0), (b,0)<(c,1)
  (define proc
    (proc-recv 'a 'x (expr-String)
      (proc-recv 'b 'y (expr-String)
        (proc-send (expr-fvar 'x) 'c
          (proc-send (expr-fvar 'y) 'c (proc-stop))))))
  (define edges (extract-data-flow-edges proc (hasheq 'a 0 'b 0 'c 0) (hasheq)))
  (check-equal? (length edges) 2)
  ;; (a,0) < (c,0)
  (check-not-false (member (eff-edge (eff-pos 'a 0) (eff-pos 'c 0)) edges))
  ;; (b,0) < (c,1)
  (check-not-false (member (eff-edge (eff-pos 'b 0) (eff-pos 'c 1)) edges)))

(test-case "data-flow: proc-par merges edges from both sides"
  ;; par: left sends 'x on 'b, right sends 'y on 'c
  ;; where 'x was bound on 'a and 'y was bound on 'a
  (define proc
    (proc-recv 'a 'x (expr-String)
      (proc-recv 'a 'y (expr-String)
        (proc-par
          (proc-send (expr-fvar 'x) 'b (proc-stop))
          (proc-send (expr-fvar 'y) 'c (proc-stop))))))
  (define edges (extract-data-flow-edges proc (hasheq 'a 0 'b 0 'c 0) (hasheq)))
  (check-equal? (length edges) 2)
  (check-not-false (member (eff-edge (eff-pos 'a 0) (eff-pos 'b 0)) edges))
  (check-not-false (member (eff-edge (eff-pos 'a 1) (eff-pos 'c 0)) edges)))

(test-case "data-flow: no binding → no edges from recv"
  ;; recv without binding (binding = #f) → no variable tracked
  (define proc
    (proc-recv 'a #f (expr-String)
      (proc-send (expr-string "literal") 'b (proc-stop))))
  (define edges (extract-data-flow-edges proc (hasheq 'a 0 'b 0) (hasheq)))
  (check-equal? edges '()))

(test-case "data-flow: literal send → no edges (no vars used)"
  (define proc
    (proc-recv 'a 'x (expr-String)
      (proc-send (expr-string "literal") 'b (proc-stop))))
  (define edges (extract-data-flow-edges proc (hasheq 'a 0 'b 0) (hasheq)))
  (check-equal? edges '()))

(test-case "data-flow: proc-open starts channel 'ch at depth 0"
  ;; proc-open creates IO channel 'ch; recv on 'ch (depth 0) binds 'x
  ;; then send 'x on 'self → cross-channel edge
  (define proc
    (proc-open (expr-string "/tmp/test") (sess-recv (expr-String) (sess-end)) 'FsCap
      (proc-recv 'ch 'data (expr-String)
        (proc-send (expr-fvar 'data) 'self (proc-stop)))))
  (define edges (extract-data-flow-edges proc (hasheq 'self 0) (hasheq)))
  (check-equal? (length edges) 1)
  (check-equal? (car edges) (eff-edge (eff-pos 'ch 0) (eff-pos 'self 0))))


;; ========================================
;; Group 4: Ordering Propagator
;; ========================================

(test-case "ordering-propagator: computes transitive closure"
  (define net (make-prop-network))
  ;; Create cells
  (define-values (net1 sess-cell) (net-new-cell net eff-bot eff-ordering-cell-merge))
  (define-values (net2 df-cell) (net-new-cell net1 eff-bot eff-ordering-cell-merge))
  (define-values (net3 out-cell) (net-new-cell net2 eff-bot eff-ordering-cell-merge))
  (define-values (net4 contra-cell) (net-new-cell net3 eff-bot eff-pos-merge))
  ;; Install propagator
  (define-values (net5 _pid) (add-ordering-propagator net4 sess-cell df-cell out-cell contra-cell))
  ;; Write session edges: (a,0)<(a,1)
  (define sess-ord (eff-ordering (list (eff-edge (eff-pos 'a 0) (eff-pos 'a 1)))))
  ;; Write data-flow edges: (a,1)<(b,0)
  (define df-ord (eff-ordering (list (eff-edge (eff-pos 'a 1) (eff-pos 'b 0)))))
  (define net6 (net-cell-write net5 sess-cell sess-ord))
  (define net7 (net-cell-write net6 df-cell df-ord))
  ;; Run to quiescence
  (define net-q (run-to-quiescence net7))
  ;; Output should have transitive closure: (a,0)<(a,1), (a,1)<(b,0), (a,0)<(b,0)
  (define result (net-cell-read net-q out-cell))
  (check-true (eff-ordering? result))
  (define edges (eff-ordering-edges result))
  (check-true (>= (length edges) 3) "should have at least 3 edges (including transitive)")
  ;; Check the transitive edge exists
  (check-not-false (member (eff-edge (eff-pos 'a 0) (eff-pos 'b 0)) edges)
    "transitive edge (a,0)<(b,0) should be present")
  ;; No contradiction
  (check-true (eff-bot? (net-cell-read net-q contra-cell))))

(test-case "ordering-propagator: cycle → contradiction"
  (define net (make-prop-network))
  (define-values (net1 sess-cell) (net-new-cell net eff-bot eff-ordering-cell-merge))
  (define-values (net2 df-cell) (net-new-cell net1 eff-bot eff-ordering-cell-merge))
  (define-values (net3 out-cell) (net-new-cell net2 eff-bot eff-ordering-cell-merge))
  (define-values (net4 contra-cell) (net-new-cell net3 eff-bot eff-pos-merge))
  (define-values (net5 _pid) (add-ordering-propagator net4 sess-cell df-cell out-cell contra-cell))
  ;; Create a cycle: (a,0)<(b,0), (b,0)<(a,0)
  (define sess-ord (eff-ordering (list (eff-edge (eff-pos 'a 0) (eff-pos 'b 0)))))
  (define df-ord (eff-ordering (list (eff-edge (eff-pos 'b 0) (eff-pos 'a 0)))))
  (define net6 (net-cell-write net5 sess-cell sess-ord))
  (define net7 (net-cell-write net6 df-cell df-ord))
  (define net-q (run-to-quiescence net7))
  ;; Contradiction cell should be eff-top
  (check-true (eff-top? (net-cell-read net-q contra-cell))))

(test-case "ordering-propagator: bot inputs → no output"
  (define net (make-prop-network))
  (define-values (net1 sess-cell) (net-new-cell net eff-bot eff-ordering-cell-merge))
  (define-values (net2 df-cell) (net-new-cell net1 eff-bot eff-ordering-cell-merge))
  (define-values (net3 out-cell) (net-new-cell net2 eff-bot eff-ordering-cell-merge))
  (define-values (net4 contra-cell) (net-new-cell net3 eff-bot eff-pos-merge))
  (define-values (net5 _pid) (add-ordering-propagator net4 sess-cell df-cell out-cell contra-cell))
  ;; Leave both inputs at bot
  (define net-q (run-to-quiescence net5))
  ;; Output should still be bot
  (check-true (eff-bot? (net-cell-read net-q out-cell)))
  (check-true (eff-bot? (net-cell-read net-q contra-cell))))

(test-case "ordering-propagator: empty orderings → empty output"
  (define net (make-prop-network))
  (define-values (net1 sess-cell) (net-new-cell net eff-bot eff-ordering-cell-merge))
  (define-values (net2 df-cell) (net-new-cell net1 eff-bot eff-ordering-cell-merge))
  (define-values (net3 out-cell) (net-new-cell net2 eff-bot eff-ordering-cell-merge))
  (define-values (net4 contra-cell) (net-new-cell net3 eff-bot eff-pos-merge))
  (define-values (net5 _pid) (add-ordering-propagator net4 sess-cell df-cell out-cell contra-cell))
  ;; Write empty orderings
  (define net6 (net-cell-write net5 sess-cell eff-ordering-empty))
  (define net7 (net-cell-write net6 df-cell eff-ordering-empty))
  (define net-q (run-to-quiescence net7))
  ;; Output should be an empty ordering
  (define result (net-cell-read net-q out-cell))
  (check-true (eff-ordering? result))
  (check-equal? (eff-ordering-edges result) '())
  (check-true (eff-bot? (net-cell-read net-q contra-cell))))


;; ========================================
;; Group 5: Effect Linearization (AD-D3)
;; ========================================

(test-case "linearize-effects: single channel, three steps"
  ;; Three effects at unique positions: write@0, read@1, close@2
  ;; Ordering: (ch,0)<(ch,1)<(ch,2)
  ;; Input is in reverse order to verify reordering
  (define effs (list
    (eff-close 'ch (eff-pos 'ch 2))
    (eff-read 'ch (eff-pos 'ch 1))
    (eff-write 'ch (eff-pos 'ch 0) (expr-string "data"))))
  (define ordering (eff-ordering
    (list (eff-edge (eff-pos 'ch 0) (eff-pos 'ch 1))
          (eff-edge (eff-pos 'ch 1) (eff-pos 'ch 2)))))
  (define result (linearize-effects ordering effs))
  (check-true (list? result))
  (check-equal? (length result) 3)
  ;; Order: write@0, read@1, close@2
  (check-true (eff-write? (car result)))
  (check-true (eff-read? (cadr result)))
  (check-true (eff-close? (caddr result))))

(test-case "linearize-effects: unique positions, correct order"
  ;; Three effects at positions (a,0), (a,1), (a,2) with ordering (0)<(1)<(2)
  (define effs (list
    (eff-close 'a (eff-pos 'a 2))
    (eff-write 'a (eff-pos 'a 0) (expr-string "data"))
    (eff-read 'a (eff-pos 'a 1))))
  (define ordering (eff-ordering
    (list (eff-edge (eff-pos 'a 0) (eff-pos 'a 1))
          (eff-edge (eff-pos 'a 1) (eff-pos 'a 2)))))
  (define result (linearize-effects ordering effs))
  (check-true (list? result))
  (check-equal? (length result) 3)
  ;; First should be write@0, then read@1, then close@2
  (check-true (eff-write? (car result)))
  (check-true (eff-read? (cadr result)))
  (check-true (eff-close? (caddr result))))

(test-case "linearize-effects: cross-channel ordering respected"
  ;; Two channels: write on 'a@0, then read on 'b@0
  ;; Data-flow edge: (a,0) < (b,0)
  (define effs (list
    (eff-read 'b (eff-pos 'b 0))
    (eff-write 'a (eff-pos 'a 0) (expr-string "x"))))
  (define ordering (eff-ordering
    (list (eff-edge (eff-pos 'a 0) (eff-pos 'b 0)))))
  (define result (linearize-effects ordering effs))
  (check-true (list? result))
  (check-equal? (length result) 2)
  ;; write@(a,0) should come before read@(b,0)
  (check-true (eff-write? (car result)))
  (check-true (eff-read? (cadr result))))

(test-case "linearize-effects: concurrent effects → deterministic tiebreak"
  ;; Two effects with no ordering between them: (a,0) and (b,0)
  ;; Deterministic tiebreak: channel name 'a < 'b
  (define effs (list
    (eff-write 'b (eff-pos 'b 0) (expr-string "b"))
    (eff-write 'a (eff-pos 'a 0) (expr-string "a"))))
  (define ordering eff-ordering-empty)
  (define result (linearize-effects ordering effs))
  (check-true (list? result))
  (check-equal? (length result) 2)
  ;; 'a < 'b alphabetically
  (check-equal? (eff-write-channel (car result)) 'a)
  (check-equal? (eff-write-channel (cadr result)) 'b))

(test-case "linearize-effects: empty effects → empty result"
  (define result (linearize-effects eff-ordering-empty '()))
  (check-equal? result '()))


;; ========================================
;; Group 6: Full Pipeline Integration (AD-D3)
;; ========================================

(test-case "full-pipeline: collect effects → extract edges → linearize"
  ;; Session: !String.end on 'ch
  ;; Process: open file, send "hello", stop
  ;; Collect effects, extract session ordering, linearize
  (define tmp (make-temporary-file))
  (define sess (sess-send (expr-String) (sess-end)))
  (define proc
    (proc-open (expr-string (path->string tmp))
               sess 'FsCap
               (proc-send (expr-string "hello") 'ch (proc-stop))))
  (define rnet (make-runtime-network))
  (define-values (rnet* bindings trace)
    (compile-live-process rnet proc (hasheq) (hasheq)
                          #:collect-effects? #t))
  ;; Extract effects from bindings
  (define effs (effect-set-effects (get-effect-acc bindings)))
  (check-true (> (length effs) 0) "should have collected effects")
  ;; Extract session ordering edges
  (define sess-edges (session-ordering-edges 'ch sess))
  ;; Combine with data-flow edges (none for single-channel)
  (define df-edges (extract-data-flow-edges proc))
  (check-equal? df-edges '() "single-channel → no cross-channel edges")
  ;; Build ordering
  (define ordering (eff-ordering (append sess-edges df-edges)))
  ;; Linearize
  (define linearized (linearize-effects ordering effs))
  (check-true (list? linearized) "linearization should succeed")
  ;; Should have 3 effects: open, write, close
  (check-equal? (length linearized) 3)
  ;; First should be open (or write — both at depth 0)
  ;; Last should be close
  (check-true (eff-close? (last linearized)) "close should be last")
  (delete-file tmp))
