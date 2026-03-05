#lang racket/base

;;;
;;; S4e: Session ↔ Type cross-domain bridge tests
;;;
;;; Tests α/γ functions, bridge construction, constraint collection,
;;; type-aware checking, and contradiction propagation.
;;;

(require rackunit
         "../syntax.rkt"
         "../sessions.rkt"
         "../processes.rkt"
         "../errors.rkt"
         "../session-lattice.rkt"
         "../session-propagators.rkt"
         "../session-type-bridge.rkt"
         "../type-lattice.rkt"
         "../propagator.rkt")

;; ========================================
;; α Functions
;; ========================================

(test-case "send-type-alpha: sess-bot → type-bot"
  (check-equal? (send-type-alpha sess-bot) type-bot))

(test-case "send-type-alpha: sess-top → type-top"
  (check-equal? (send-type-alpha sess-top) type-top))

(test-case "send-type-alpha: sess-send → extracts message type"
  (check-equal? (send-type-alpha (sess-send (expr-Nat) (sess-end)))
                (expr-Nat)))

(test-case "send-type-alpha: sess-recv → type-bot (wrong direction)"
  (check-equal? (send-type-alpha (sess-recv (expr-String) (sess-end)))
                type-bot))

(test-case "send-type-alpha: sess-dsend → extracts message type"
  (check-equal? (send-type-alpha (sess-dsend (expr-Nat) (sess-end)))
                (expr-Nat)))

(test-case "recv-type-alpha: sess-bot → type-bot"
  (check-equal? (recv-type-alpha sess-bot) type-bot))

(test-case "recv-type-alpha: sess-top → type-top"
  (check-equal? (recv-type-alpha sess-top) type-top))

(test-case "recv-type-alpha: sess-recv → extracts message type"
  (check-equal? (recv-type-alpha (sess-recv (expr-String) (sess-end)))
                (expr-String)))

(test-case "recv-type-alpha: sess-send → type-bot (wrong direction)"
  (check-equal? (recv-type-alpha (sess-send (expr-Nat) (sess-end)))
                type-bot))

(test-case "recv-type-alpha: sess-drecv → extracts message type"
  (check-equal? (recv-type-alpha (sess-drecv (expr-String) (sess-end)))
                (expr-String)))

;; ========================================
;; γ Function
;; ========================================

(test-case "type-to-session-gamma: always returns sess-bot"
  (check-equal? (type-to-session-gamma type-bot) sess-bot)
  (check-equal? (type-to-session-gamma type-top) sess-bot)
  (check-equal? (type-to-session-gamma (expr-Nat)) sess-bot))

;; ========================================
;; Bridge Construction — Send
;; ========================================

(test-case "send-type-bridge: session cell with sess-send → type cell gets message type"
  (define net0 (make-prop-network))
  (define sess (sess-send (expr-Nat) (sess-end)))
  (define-values (net1 sess-cell)
    (net-new-cell net0 sess session-lattice-merge session-lattice-contradicts?))
  (define-values (net2 type-cell) (add-send-type-bridge net1 sess-cell))
  ;; Run to quiescence — α propagator should fire
  (define net3 (run-to-quiescence net2))
  (check-equal? (net-cell-read net3 type-cell) (expr-Nat)))

(test-case "send-type-bridge: session cell at bot → type cell stays bot"
  (define net0 (make-prop-network))
  (define-values (net1 sess-cell)
    (net-new-cell net0 sess-bot session-lattice-merge session-lattice-contradicts?))
  (define-values (net2 type-cell) (add-send-type-bridge net1 sess-cell))
  (define net3 (run-to-quiescence net2))
  (check-true (type-bot? (net-cell-read net3 type-cell))))

;; ========================================
;; Bridge Construction — Recv
;; ========================================

(test-case "recv-type-bridge: session cell with sess-recv → type cell gets message type"
  (define net0 (make-prop-network))
  (define sess (sess-recv (expr-String) (sess-end)))
  (define-values (net1 sess-cell)
    (net-new-cell net0 sess session-lattice-merge session-lattice-contradicts?))
  (define-values (net2 type-cell) (add-recv-type-bridge net1 sess-cell))
  (define net3 (run-to-quiescence net2))
  (check-equal? (net-cell-read net3 type-cell) (expr-String)))

(test-case "recv-type-bridge: session cell at bot → type cell stays bot"
  (define net0 (make-prop-network))
  (define-values (net1 sess-cell)
    (net-new-cell net0 sess-bot session-lattice-merge session-lattice-contradicts?))
  (define-values (net2 type-cell) (add-recv-type-bridge net1 sess-cell))
  (define net3 (run-to-quiescence net2))
  (check-true (type-bot? (net-cell-read net3 type-cell))))

;; ========================================
;; γ No-op Verification
;; ========================================

(test-case "γ no-op: writing to type cell doesn't change session cell"
  (define net0 (make-prop-network))
  (define sess (sess-send (expr-Nat) (sess-end)))
  (define-values (net1 sess-cell)
    (net-new-cell net0 sess session-lattice-merge session-lattice-contradicts?))
  (define-values (net2 type-cell) (add-send-type-bridge net1 sess-cell))
  ;; Write to type cell — should trigger γ which returns sess-bot (no-op)
  (define net3 (net-cell-write net2 type-cell (expr-String)))
  (define net4 (run-to-quiescence net3))
  ;; Session cell should still have original value
  (check-equal? (net-cell-read net4 sess-cell) sess))

;; ========================================
;; Contradiction Propagation
;; ========================================

(test-case "send-type-bridge: session contradiction → type contradiction"
  (define net0 (make-prop-network))
  (define-values (net1 sess-cell)
    (net-new-cell net0 sess-top session-lattice-merge session-lattice-contradicts?))
  (define-values (net2 type-cell) (add-send-type-bridge net1 sess-cell))
  (define net3 (run-to-quiescence net2))
  (check-true (type-top? (net-cell-read net3 type-cell))))

;; ========================================
;; Extended Compilation
;; ========================================

(test-case "compile-with-bridges: single send → 1 constraint"
  (define net0 (make-prop-network))
  (define sess (sess-send (expr-Nat) (sess-end)))
  (define-values (net1 self-cell) (make-session-cell net0 sess))
  (define channel-cells (hasheq 'self self-cell))
  (define proc (proc-send (expr-nat-val 42) 'self (proc-stop)))
  (define-values (net2 trace constraints)
    (compile-proc-with-type-bridges net1 proc channel-cells))
  ;; Should have exactly 1 constraint (for the send)
  (check-equal? (length constraints) 1)
  (define c (car constraints))
  (check-equal? (msg-type-constraint-channel c) 'self)
  (check-equal? (msg-type-constraint-direction c) 'send)
  ;; After quiescence, the type cell should have the message type
  (define net3 (run-to-quiescence net2))
  (check-equal? (net-cell-read net3 (msg-type-constraint-type-cell c)) (expr-Nat)))

(test-case "compile-with-bridges: send + recv → 2 constraints"
  (define net0 (make-prop-network))
  (define sess (sess-send (expr-String) (sess-recv (expr-Nat) (sess-end))))
  (define-values (net1 self-cell) (make-session-cell net0 sess))
  (define channel-cells (hasheq 'self self-cell))
  (define proc (proc-send (expr-string "hello") 'self
                 (proc-recv 'self #f (proc-stop))))
  (define-values (net2 trace constraints)
    (compile-proc-with-type-bridges net1 proc channel-cells))
  ;; Should have 2 constraints (send + recv)
  (check-equal? (length constraints) 2)
  ;; First constraint in list is the last added (recv), second is send
  ;; (cons adds to front)
  (define recv-c (car constraints))
  (define send-c (cadr constraints))
  (check-equal? (msg-type-constraint-direction recv-c) 'recv)
  (check-equal? (msg-type-constraint-direction send-c) 'send)
  ;; After quiescence, type cells should have correct message types
  (define net3 (run-to-quiescence net2))
  (check-equal? (net-cell-read net3 (msg-type-constraint-type-cell send-c)) (expr-String))
  (check-equal? (net-cell-read net3 (msg-type-constraint-type-cell recv-c)) (expr-Nat)))

(test-case "compile-with-bridges: stop only → 0 constraints"
  (define net0 (make-prop-network))
  (define sess (sess-end))
  (define-values (net1 self-cell) (make-session-cell net0 sess))
  (define channel-cells (hasheq 'self self-cell))
  (define proc (proc-stop))
  (define-values (net2 trace constraints)
    (compile-proc-with-type-bridges net1 proc channel-cells))
  (check-equal? (length constraints) 0))

;; ========================================
;; Type-Aware Checker
;; ========================================

(test-case "check-session-with-types: no type-check-fn → query mode returns constraints"
  (define sess (sess-send (expr-Nat) (sess-end)))
  (define proc (proc-send (expr-nat-val 42) 'self (proc-stop)))
  (define result (check-session-with-types proc sess))
  ;; Should be (cons 'ok-with-constraints constraints)
  (check-true (pair? result))
  (check-equal? (car result) 'ok-with-constraints)
  ;; Should have 1 constraint
  (check-equal? (length (cdr result)) 1))

(test-case "check-session-with-types: type-check-fn passes → ok"
  (define sess (sess-send (expr-Nat) (sess-end)))
  (define proc (proc-send (expr-nat-val 42) 'self (proc-stop)))
  ;; Type check function that always passes
  (define (always-ok _expr _type) #t)
  (define result (check-session-with-types proc sess always-ok))
  (check-equal? result 'ok))

(test-case "check-session-with-types: type-check-fn fails → msg-type-error"
  (define sess (sess-send (expr-Nat) (sess-end)))
  (define proc (proc-send (expr-string "wrong") 'self (proc-stop)))
  ;; Type check function that always fails
  (define (always-fail _expr _type) #f)
  (define result (check-session-with-types proc sess always-fail))
  (check-true (msg-type-error? result))
  (check-equal? (msg-type-error-channel result) 'self)
  (check-equal? (msg-type-error-direction result) 'send))

(test-case "check-session-with-types: protocol violation still detected"
  ;; Session expects Send, process does Recv → protocol error
  (define sess (sess-send (expr-Nat) (sess-end)))
  (define proc (proc-recv 'self #f (proc-stop)))
  (define result (check-session-with-types proc sess))
  ;; Should be a session-protocol-error (protocol shape error), not a type error
  (check-true (session-protocol-error? result)))

(test-case "check-session-with-types: multi-step with type checking"
  (define sess (sess-send (expr-String) (sess-recv (expr-Nat) (sess-end))))
  (define proc (proc-send (expr-string "hello") 'self
                 (proc-recv 'self #f (proc-stop))))
  ;; Check function that verifies expr-string matches expr-String
  (define (simple-check expr expected-type)
    (cond
      [(and (expr-string? expr) (equal? expected-type (expr-String))) #t]
      [(and (not (expr-string? expr)) (equal? expected-type (expr-Nat))) #t]
      [else #f]))
  (define result (check-session-with-types proc sess simple-check))
  (check-equal? result 'ok))
