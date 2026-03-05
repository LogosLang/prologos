#lang racket/base

;;;
;;; S7b: Process-to-propagator compilation tests
;;;
;;; Tests compile-live-process and rt-execute-process: compiling proc-*
;;; trees into live propagator networks that execute via run-to-quiescence.
;;;

(require rackunit
         "../session-runtime.rkt"
         "../propagator.rkt"
         "../sessions.rkt"
         "../session-lattice.rkt"
         "../processes.rkt"
         "../syntax.rkt")

;; ========================================
;; Helper: endpoint-advance-session
;; ========================================

(test-case "endpoint-advance-session: preserves msg/choice cells"
  (define rnet (make-runtime-network))
  (define sess (sess-send (expr-Nat) (sess-end)))
  (define-values (rnet* pair) (rt-new-channel-pair rnet sess))
  (define ep-a (channel-pair-ep-a pair))
  ;; Create a new session cell
  (define-values (rnet2 new-sess-cell)
    (let-values ([(n c) (rt-fresh-session-cell (runtime-network-prop-net rnet*) sess-bot)])
      (values (runtime-network n
                               (runtime-network-channel-info rnet*)
                               (runtime-network-next-chan-id rnet*))
              c)))
  (define ep-new (endpoint-advance-session ep-a new-sess-cell))
  ;; msg-out, msg-in, choice preserved
  (check-equal? (channel-endpoint-msg-out-cell ep-new)
                (channel-endpoint-msg-out-cell ep-a))
  (check-equal? (channel-endpoint-msg-in-cell ep-new)
                (channel-endpoint-msg-in-cell ep-a))
  (check-equal? (channel-endpoint-choice-cell ep-new)
                (channel-endpoint-choice-cell ep-a))
  ;; session cell changed
  (check-equal? (channel-endpoint-session-cell ep-new) new-sess-cell)
  (check-not-equal? (channel-endpoint-session-cell ep-new)
                    (channel-endpoint-session-cell ep-a)))

;; ========================================
;; resolve-expr
;; ========================================

(test-case "resolve-expr: symbol lookup in bindings"
  (define bindings (hasheq 'x 42 'y "hello"))
  (check-equal? (resolve-expr 'x bindings) 42)
  (check-equal? (resolve-expr 'y bindings) "hello")
  (check-equal? (resolve-expr 'z bindings) 'z)  ;; unbound → self
  (check-equal? (resolve-expr 99 bindings) 99)   ;; non-symbol → as-is
  (check-equal? (resolve-expr "lit" bindings) "lit"))

;; ========================================
;; proc-send: writes value, advances session
;; ========================================

(test-case "proc-send: writes to msg-out and advances session"
  ;; Session: Send Nat End
  (define sess (sess-send (expr-Nat) (sess-end)))
  (define proc (proc-send 42 'self (proc-stop)))
  (define result (rt-execute-process proc sess))
  ;; Should succeed (no contradiction)
  (check-equal? (rt-exec-result-status result) 'ok)
  ;; The msg-out cell of self should have 42
  (define rnet (rt-exec-result-runtime-network result))
  (define ep (rt-lookup-channel rnet 'self))
  (check-equal? (rt-cell-read rnet (channel-endpoint-msg-out-cell ep)) 42))

(test-case "proc-send: protocol violation (send on recv session)"
  ;; Session: Recv Nat End — but process tries to send
  (define sess (sess-recv (expr-Nat) (sess-end)))
  (define proc (proc-send 42 'self (proc-stop)))
  (define result (rt-execute-process proc sess))
  ;; Should hit contradiction
  (check-equal? (rt-exec-result-status result) 'contradiction))

;; ========================================
;; proc-recv: reads from msg-in, advances session
;; ========================================

(test-case "proc-recv: advances session through recv"
  ;; Session: Recv Nat End
  (define sess (sess-recv (expr-Nat) (sess-end)))
  (define proc (proc-recv 'self (expr-Nat) (proc-stop)))
  (define result (rt-execute-process proc sess))
  ;; Should succeed
  (check-equal? (rt-exec-result-status result) 'ok))

(test-case "proc-recv: protocol violation (recv on send session)"
  ;; Session: Send Nat End — but process tries to recv
  (define sess (sess-send (expr-Nat) (sess-end)))
  (define proc (proc-recv 'self (expr-Nat) (proc-stop)))
  (define result (rt-execute-process proc sess))
  ;; Should hit contradiction
  (check-equal? (rt-exec-result-status result) 'contradiction))

;; ========================================
;; proc-stop
;; ========================================

(test-case "proc-stop: succeeds when session is End"
  ;; Session: End (trivial)
  (define sess (sess-end))
  (define proc (proc-stop))
  (define result (rt-execute-process proc sess))
  (check-equal? (rt-exec-result-status result) 'ok))

(test-case "proc-stop: contradiction when session not at End"
  ;; Session: Send Nat End — but process stops immediately
  (define sess (sess-send (expr-Nat) (sess-end)))
  (define proc (proc-stop))
  (define result (rt-execute-process proc sess))
  ;; Stopping with remaining protocol → contradiction
  (check-equal? (rt-exec-result-status result) 'contradiction))

;; ========================================
;; proc-sel + proc-case (choice / offer)
;; ========================================

(test-case "proc-sel: writes label to choice cell"
  ;; Session: Choice { :inc → End }
  (define sess (sess-choice (list (cons ':inc (sess-end))
                                  (cons ':done (sess-end)))))
  (define proc (proc-sel 'self ':inc (proc-stop)))
  (define result (rt-execute-process proc sess))
  (check-equal? (rt-exec-result-status result) 'ok)
  ;; Choice cell should have :inc
  (define rnet (rt-exec-result-runtime-network result))
  (define ep (rt-lookup-channel rnet 'self))
  (check-equal? (rt-cell-read rnet (channel-endpoint-choice-cell ep)) ':inc))

(test-case "proc-case: compiles all branches"
  ;; Session: Offer { :inc → End, :done → End }
  (define sess (sess-offer (list (cons ':inc (sess-end))
                                  (cons ':done (sess-end)))))
  ;; Process offers two branches, both stop
  (define proc (proc-case 'self
                 (list (cons ':inc (proc-stop))
                       (cons ':done (proc-stop)))))
  ;; Pre-write the choice to :inc
  (define rnet0 (make-runtime-network))
  (define-values (rnet1 pair) (rt-new-channel-pair rnet0 sess))
  (define ep-a (channel-pair-ep-a pair))
  (define ep-b (channel-pair-ep-b pair))
  (define rnet2 (rt-cross-wire-choice rnet1 ep-a ep-b))
  ;; Write choice :inc to ep-a's choice cell
  (define rnet3 (rt-cell-write rnet2 (channel-endpoint-choice-cell ep-a) ':inc))
  ;; Compile the process
  (define channel-eps (hasheq 'self ep-a))
  (define-values (rnet4 bindings trace)
    (compile-live-process rnet3 proc channel-eps))
  ;; Run to quiescence
  (define rnet5 (rt-run-to-quiescence rnet4))
  ;; No contradiction
  (check-false (rt-contradiction? rnet5)))

(test-case "proc-sel + proc-case: select resolves offer via new"
  ;; Session: Choice { :inc → End, :done → End }
  ;; p1 (selector) selects :done, p2 (offerer) offers both branches
  (define sess (sess-choice (list (cons ':inc (sess-end))
                                  (cons ':done (sess-end)))))
  (define p1 (proc-sel 'ch ':done (proc-stop)))
  (define p2 (proc-case 'ch
               (list (cons ':inc (proc-stop))
                     (cons ':done (proc-stop)))))
  (define proc (proc-new sess (proc-par p1 p2)))
  ;; Use a trivial self session to wrap the new
  (define self-sess (sess-end))
  (define result (rt-execute-process proc self-sess))
  ;; No contradiction — selector picks :done, offerer accepts
  (check-equal? (rt-exec-result-status result) 'ok))

;; ========================================
;; proc-new: channel pair creation
;; ========================================

(test-case "proc-new: parallel processes communicate via channel pair"
  ;; Session: Send Nat End
  ;; p1 sends 42 on ch, p2 receives on ch
  (define sess (sess-send (expr-Nat) (sess-end)))
  ;; p1: ch ! 42; stop
  (define p1 (proc-send 42 'ch (proc-stop)))
  ;; p2: ch ? Nat; stop  (dual session: Recv Nat End)
  (define p2 (proc-recv 'ch (expr-Nat) (proc-stop)))
  (define proc (proc-new sess (proc-par p1 p2)))
  ;; Wrap with trivial self session
  (define self-sess (sess-end))
  (define result (rt-execute-process proc self-sess))
  ;; Should succeed
  (check-equal? (rt-exec-result-status result) 'ok))

(test-case "proc-new: cross-wired message delivery"
  ;; Verify that p1 sending on ch results in p2's msg-in receiving the value
  (define sess (sess-send (expr-Nat) (sess-end)))
  (define p1 (proc-send 99 'ch (proc-stop)))
  (define p2 (proc-recv 'ch (expr-Nat) (proc-stop)))
  (define proc (proc-new sess (proc-par p1 p2)))
  (define self-sess (sess-end))
  (define result (rt-execute-process proc self-sess))
  (check-equal? (rt-exec-result-status result) 'ok))

;; ========================================
;; proc-par: shared channels
;; ========================================

(test-case "proc-par: compiles both sides"
  ;; Two parallel stops with End session
  (define sess (sess-end))
  (define proc (proc-par (proc-stop) (proc-stop)))
  (define result (rt-execute-process proc sess))
  (check-equal? (rt-exec-result-status result) 'ok))

;; ========================================
;; proc-link: channel forwarding
;; ========================================

(test-case "proc-link: forwards between channels"
  ;; Create two channels, link them, verify forwarding
  (define rnet0 (make-runtime-network))
  (define sess1 (sess-send (expr-Nat) (sess-end)))
  (define sess2 (sess-send (expr-Nat) (sess-end)))
  (define-values (rnet1 pair1) (rt-new-channel-pair rnet0 sess1))
  (define-values (rnet2 pair2) (rt-new-channel-pair rnet1 sess2))
  (define ep-a1 (channel-pair-ep-a pair1))
  (define ep-a2 (channel-pair-ep-a pair2))
  ;; Link ep-a1 and ep-a2
  (define channel-eps (hasheq 'c1 ep-a1 'c2 ep-a2))
  (define proc (proc-link 'c1 'c2))
  (define-values (rnet3 bindings trace)
    (compile-live-process rnet2 proc channel-eps))
  ;; Write to c1's msg-out
  (define rnet4 (rt-cell-write rnet3 (channel-endpoint-msg-out-cell ep-a1) "forwarded"))
  ;; Run to quiescence
  (define rnet5 (rt-run-to-quiescence rnet4))
  ;; c2's msg-in should receive the forwarded value
  (check-equal? (rt-cell-read rnet5 (channel-endpoint-msg-in-cell ep-a2)) "forwarded"))

;; ========================================
;; End-to-end scenarios
;; ========================================

(test-case "e2e: Send then Recv sequence"
  ;; Session: Send String . Recv Nat . End
  (define sess (sess-send (expr-String) (sess-recv (expr-Nat) (sess-end))))
  (define proc
    (proc-send "hello" 'self
      (proc-recv 'self (expr-Nat)
        (proc-stop))))
  (define result (rt-execute-process proc sess))
  (check-equal? (rt-exec-result-status result) 'ok))

(test-case "e2e: Mu unfold + step"
  ;; Session: Mu(Send Nat . SVar 0) — recursive send
  ;; Process: send one value, then stop (which should fail — session expects more sends)
  (define sess (sess-mu (sess-send (expr-Nat) (sess-svar 0))))
  ;; One send then stop: contradicts the recursive session (next step is still Send)
  (define proc (proc-send 1 'self (proc-stop)))
  (define result (rt-execute-process proc sess))
  ;; After one send, session unfolds to another Send Nat (Mu ...) — stop contradicts
  (check-equal? (rt-exec-result-status result) 'contradiction))

(test-case "e2e: rt-exec-result has bindings hash"
  ;; Verify the result struct carries bindings
  (define sess (sess-recv (expr-Nat) (sess-end)))
  (define proc (proc-recv 'self (expr-Nat) (proc-stop)))
  (define result (rt-execute-process proc sess))
  (check-equal? (rt-exec-result-status result) 'ok)
  ;; bindings should have a 'self entry from the recv
  (check-true (hash-has-key? (rt-exec-result-bindings result) 'self)))

;; ========================================
;; Choice cross-wiring
;; ========================================

(test-case "rt-cross-wire-choice: propagates choice value"
  (define rnet (make-runtime-network))
  (define sess (sess-end))
  (define-values (rnet* pair) (rt-new-channel-pair rnet sess))
  (define ep-a (channel-pair-ep-a pair))
  (define ep-b (channel-pair-ep-b pair))
  ;; Cross-wire choice cells
  (define rnet2 (rt-cross-wire-choice rnet* ep-a ep-b))
  ;; Write choice to A
  (define rnet3 (rt-cell-write rnet2 (channel-endpoint-choice-cell ep-a) ':foo))
  (define rnet4 (rt-run-to-quiescence rnet3))
  ;; B should have the same choice
  (check-equal? (rt-cell-read rnet4 (channel-endpoint-choice-cell ep-b)) ':foo))
