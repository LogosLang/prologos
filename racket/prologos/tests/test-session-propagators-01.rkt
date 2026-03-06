#lang racket/base

;;;
;;; Tests for session-propagators.rkt
;;; Validates propagator-based session type checking.
;;;

(require rackunit
         "../syntax.rkt"
         "../sessions.rkt"
         "../processes.rkt"
         "../errors.rkt"
         "../session-lattice.rkt"
         "../session-propagators.rkt"
         "../propagator.rkt")

;; ========================================
;; Helper: check result
;; ========================================

(define (check-ok? result) (eq? result 'ok))
(define (check-contradiction? result)
  (session-protocol-error? result))

;; ========================================
;; Basic: send/stop type-checks
;; ========================================

(test-case "propagator: send/stop against Send String End"
  (define sess (sess-send (expr-String) (sess-end)))
  (define proc (proc-send (expr-string "hello") 'self (proc-stop)))
  (check-true (check-ok? (check-session-via-propagators proc sess))))

(test-case "propagator: recv/stop against Recv Nat End"
  (define sess (sess-recv (expr-Nat) (sess-end)))
  (define proc (proc-recv 'self #f #f (proc-stop)))
  (check-true (check-ok? (check-session-via-propagators proc sess))))

(test-case "propagator: multi-step send/recv/stop"
  (define sess (sess-send (expr-String) (sess-recv (expr-Nat) (sess-end))))
  (define proc (proc-send (expr-string "hello") 'self
                 (proc-recv 'self #f #f (proc-stop))))
  (check-true (check-ok? (check-session-via-propagators proc sess))))

(test-case "propagator: stop against End"
  (define sess (sess-end))
  (define proc (proc-stop))
  (check-true (check-ok? (check-session-via-propagators proc sess))))

;; ========================================
;; Contradictions: wrong polarity
;; ========================================

(test-case "propagator: send against Recv → contradiction"
  (define sess (sess-recv (expr-Nat) (sess-end)))
  (define proc (proc-send (expr-nat-val 42) 'self (proc-stop)))
  (check-true (check-contradiction? (check-session-via-propagators proc sess))))

(test-case "propagator: recv against Send → contradiction"
  (define sess (sess-send (expr-String) (sess-end)))
  (define proc (proc-recv 'self #f #f (proc-stop)))
  (check-true (check-contradiction? (check-session-via-propagators proc sess))))

(test-case "propagator: send against End → contradiction"
  (define sess (sess-end))
  (define proc (proc-send (expr-nat-val 1) 'self (proc-stop)))
  (check-true (check-contradiction? (check-session-via-propagators proc sess))))

(test-case "propagator: stop against Send → contradiction"
  (define sess (sess-send (expr-Nat) (sess-end)))
  (define proc (proc-stop))
  ;; Stop writes End to the self cell, which conflicts with sess-send
  (check-true (check-contradiction? (check-session-via-propagators proc sess))))

;; ========================================
;; Select (internal choice)
;; ========================================

(test-case "propagator: select against Choice with matching label"
  (define sess (sess-choice (list (cons 'inc (sess-send (expr-Nat) (sess-end)))
                                   (cons 'done (sess-end)))))
  (define proc (proc-sel 'self 'inc (proc-send (expr-nat-val 42) 'self (proc-stop))))
  (check-true (check-ok? (check-session-via-propagators proc sess))))

(test-case "propagator: select with label not in choice → contradiction"
  (define sess (sess-choice (list (cons 'inc (sess-send (expr-Nat) (sess-end)))
                                   (cons 'done (sess-end)))))
  (define proc (proc-sel 'self 'reset (proc-stop)))
  (check-true (check-contradiction? (check-session-via-propagators proc sess))))

;; ========================================
;; Case/Offer (external choice)
;; ========================================

(test-case "propagator: case against Offer with matching branches"
  (define sess (sess-offer (list (cons 'get (sess-send (expr-String) (sess-end)))
                                  (cons 'put (sess-recv (expr-String) (sess-end))))))
  (define proc
    (proc-case 'self
      (list (cons 'get (proc-send (expr-string "value") 'self (proc-stop)))
            (cons 'put (proc-recv 'self #f #f (proc-stop))))))
  (check-true (check-ok? (check-session-via-propagators proc sess))))

(test-case "propagator: case against Offer — branch polarity mismatch → contradiction"
  (define sess (sess-offer (list (cons 'get (sess-send (expr-String) (sess-end))))))
  ;; Process sends recv for a send-expected branch
  (define proc
    (proc-case 'self
      (list (cons 'get (proc-recv 'self #f #f (proc-stop))))))
  (check-true (check-contradiction? (check-session-via-propagators proc sess))))

;; ========================================
;; Duality (proc-new with par)
;; ========================================

(test-case "propagator: proc-new with complementary par"
  ;; new creates ch with Send String End
  ;; p1 sends on ch, p2 receives on ch (dual)
  (define sess-ty (expr-String))  ;; placeholder for proc-new session type
  (define proc
    (proc-new (sess-send (expr-String) (sess-end))
      (proc-par
        (proc-send (expr-string "hi") 'ch (proc-stop))
        (proc-recv 'ch #f #f (proc-stop)))))
  ;; No session type annotation on the outer process — just check compilation
  ;; Use End as the outer session (proc-new is self-contained)
  (check-true (check-ok? (check-session-via-propagators proc (sess-end)))))

;; ========================================
;; Cell-level operations
;; ========================================

(test-case "make-session-cell: creates cell with sess-bot"
  (define net0 (make-prop-network))
  (define-values (net1 cid) (make-session-cell net0))
  (check-true (sess-bot? (net-cell-read net1 cid))))

(test-case "make-session-cell: with initial value"
  (define net0 (make-prop-network))
  (define s (sess-send (expr-Nat) (sess-end)))
  (define-values (net1 cid) (make-session-cell net0 s))
  (check-equal? (net-cell-read net1 cid) s))

(test-case "add-send-prop: decomposes send session"
  (define net0 (make-prop-network))
  (define s (sess-send (expr-Nat) (sess-recv (expr-String) (sess-end))))
  (define-values (net1 sess-cell) (make-session-cell net0 s))
  (define-values (net2 cont-cell) (add-send-prop net1 sess-cell))
  ;; Run to quiescence
  (define net3 (run-to-quiescence net2))
  ;; Continuation cell should hold the recv part
  (check-equal? (net-cell-read net3 cont-cell)
                (sess-recv (expr-String) (sess-end))))

(test-case "add-recv-prop: decomposes recv session"
  (define net0 (make-prop-network))
  (define s (sess-recv (expr-Nat) (sess-end)))
  (define-values (net1 sess-cell) (make-session-cell net0 s))
  (define-values (net2 cont-cell) (add-recv-prop net1 sess-cell))
  (define net3 (run-to-quiescence net2))
  (check-equal? (net-cell-read net3 cont-cell) (sess-end)))

(test-case "add-select-prop: selects branch from choice"
  (define net0 (make-prop-network))
  (define s (sess-choice (list (cons 'a (sess-send (expr-Nat) (sess-end)))
                                (cons 'b (sess-end)))))
  (define-values (net1 sess-cell) (make-session-cell net0 s))
  (define-values (net2 cont-cell) (add-select-prop net1 sess-cell 'a))
  (define net3 (run-to-quiescence net2))
  (check-equal? (net-cell-read net3 cont-cell)
                (sess-send (expr-Nat) (sess-end))))

(test-case "add-offer-prop: distributes offer branches"
  (define net0 (make-prop-network))
  (define s (sess-offer (list (cons 'x (sess-send (expr-Nat) (sess-end)))
                               (cons 'y (sess-end)))))
  (define-values (net1 sess-cell) (make-session-cell net0 s))
  (define-values (net2 branch-cells) (add-offer-prop net1 sess-cell '(x y)))
  (define net3 (run-to-quiescence net2))
  (define x-cell (cdr (assq 'x branch-cells)))
  (define y-cell (cdr (assq 'y branch-cells)))
  (check-equal? (net-cell-read net3 x-cell) (sess-send (expr-Nat) (sess-end)))
  (check-equal? (net-cell-read net3 y-cell) (sess-end)))

(test-case "add-duality-prop: propagates dual bidirectionally"
  (define net0 (make-prop-network))
  (define-values (net1 cell-a) (make-session-cell net0))
  (define-values (net2 cell-b) (make-session-cell net1))
  (define net3 (add-duality-prop net2 cell-a cell-b))
  ;; Write Send String End to cell-a → cell-b should become Recv String End
  (define net4 (net-cell-write net3 cell-a (sess-send (expr-String) (sess-end))))
  (define net5 (run-to-quiescence net4))
  (check-equal? (net-cell-read net5 cell-b)
                (sess-recv (expr-String) (sess-end))))
