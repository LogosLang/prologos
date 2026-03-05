#lang racket/base

;;;
;;; S7a: Channel cells — runtime session execution infrastructure tests
;;;
;;; Tests the message/choice lattices, channel pair creation with cross-wiring,
;;; session advancement, and runtime network lifecycle.
;;;

(require rackunit
         "../session-runtime.rkt"
         "../propagator.rkt"
         "../sessions.rkt"
         "../session-lattice.rkt"
         "../syntax.rkt")

;; ========================================
;; Message Lattice
;; ========================================

(test-case "msg-lattice: bot is identity"
  (check-equal? (msg-lattice-merge msg-bot 42) 42)
  (check-equal? (msg-lattice-merge 42 msg-bot) 42)
  (check-equal? (msg-lattice-merge msg-bot msg-bot) msg-bot))

(test-case "msg-lattice: top is absorbing"
  (check-equal? (msg-lattice-merge msg-top 42) msg-top)
  (check-equal? (msg-lattice-merge 42 msg-top) msg-top)
  (check-equal? (msg-lattice-merge msg-top msg-top) msg-top))

(test-case "msg-lattice: same value is idempotent"
  (check-equal? (msg-lattice-merge "hello" "hello") "hello")
  (check-equal? (msg-lattice-merge 42 42) 42)
  (check-equal? (msg-lattice-merge ':foo ':foo) ':foo))

(test-case "msg-lattice: different values → contradiction"
  (check-true (msg-top? (msg-lattice-merge 42 43)))
  (check-true (msg-top? (msg-lattice-merge "hello" "world")))
  (check-true (msg-lattice-contradicts? (msg-lattice-merge 42 43))))

;; ========================================
;; Choice Lattice
;; ========================================

(test-case "choice-lattice: bot is identity"
  (check-equal? (choice-lattice-merge choice-bot ':inc) ':inc)
  (check-equal? (choice-lattice-merge ':inc choice-bot) ':inc)
  (check-equal? (choice-lattice-merge choice-bot choice-bot) choice-bot))

(test-case "choice-lattice: top is absorbing"
  (check-equal? (choice-lattice-merge choice-top ':inc) choice-top)
  (check-equal? (choice-lattice-merge ':inc choice-top) choice-top))

(test-case "choice-lattice: same label is idempotent"
  (check-equal? (choice-lattice-merge ':done ':done) ':done))

(test-case "choice-lattice: different labels → contradiction"
  (check-true (choice-top? (choice-lattice-merge ':inc ':done)))
  (check-true (choice-lattice-contradicts? (choice-lattice-merge ':inc ':done))))

;; ========================================
;; Channel Pair Creation
;; ========================================

(test-case "channel-pair: creates 8 cells with correct initial values"
  (define rnet (make-runtime-network))
  (define sess (sess-send (expr-Nat) (sess-end)))
  (define-values (rnet* pair) (rt-new-channel-pair rnet sess))
  (define ep-a (channel-pair-ep-a pair))
  (define ep-b (channel-pair-ep-b pair))
  ;; Message cells start at msg-bot
  (check-true (msg-bot? (rt-cell-read rnet* (channel-endpoint-msg-out-cell ep-a))))
  (check-true (msg-bot? (rt-cell-read rnet* (channel-endpoint-msg-in-cell ep-a))))
  (check-true (msg-bot? (rt-cell-read rnet* (channel-endpoint-msg-out-cell ep-b))))
  (check-true (msg-bot? (rt-cell-read rnet* (channel-endpoint-msg-in-cell ep-b))))
  ;; Choice cells start at choice-bot
  (check-true (choice-bot? (rt-cell-read rnet* (channel-endpoint-choice-cell ep-a))))
  (check-true (choice-bot? (rt-cell-read rnet* (channel-endpoint-choice-cell ep-b)))))

(test-case "channel-pair: session cells initialized with type and dual"
  (define rnet (make-runtime-network))
  (define sess (sess-send (expr-Nat) (sess-end)))
  (define-values (rnet* pair) (rt-new-channel-pair rnet sess))
  (define ep-a (channel-pair-ep-a pair))
  (define ep-b (channel-pair-ep-b pair))
  ;; A gets the session type
  (check-equal? (rt-cell-read rnet* (channel-endpoint-session-cell ep-a)) sess)
  ;; B gets the dual
  (check-equal? (rt-cell-read rnet* (channel-endpoint-session-cell ep-b))
                (dual sess)))

(test-case "channel-pair: cross-wiring A.out → B.in"
  (define rnet (make-runtime-network))
  (define sess (sess-send (expr-Nat) (sess-end)))
  (define-values (rnet* pair) (rt-new-channel-pair rnet sess))
  (define ep-a (channel-pair-ep-a pair))
  (define ep-b (channel-pair-ep-b pair))
  ;; Write to A's outgoing cell
  (define rnet2 (rt-cell-write rnet* (channel-endpoint-msg-out-cell ep-a) "hello"))
  ;; Run to quiescence — propagator should forward to B's incoming
  (define rnet3 (rt-run-to-quiescence rnet2))
  (check-equal? (rt-cell-read rnet3 (channel-endpoint-msg-in-cell ep-b)) "hello")
  ;; A's incoming should still be bot (nothing sent from B)
  (check-true (msg-bot? (rt-cell-read rnet3 (channel-endpoint-msg-in-cell ep-a)))))

(test-case "channel-pair: cross-wiring B.out → A.in"
  (define rnet (make-runtime-network))
  (define sess (sess-send (expr-Nat) (sess-end)))
  (define-values (rnet* pair) (rt-new-channel-pair rnet sess))
  (define ep-a (channel-pair-ep-a pair))
  (define ep-b (channel-pair-ep-b pair))
  ;; Write to B's outgoing cell
  (define rnet2 (rt-cell-write rnet* (channel-endpoint-msg-out-cell ep-b) 42))
  ;; Run to quiescence — propagator should forward to A's incoming
  (define rnet3 (rt-run-to-quiescence rnet2))
  (check-equal? (rt-cell-read rnet3 (channel-endpoint-msg-in-cell ep-a)) 42)
  ;; B's incoming should still be bot
  (check-true (msg-bot? (rt-cell-read rnet3 (channel-endpoint-msg-in-cell ep-b)))))

;; ========================================
;; Session Advancement
;; ========================================

(test-case "session-advance: Send → continuation"
  (define net0 (make-prop-network))
  ;; Session: Send Nat End
  (define sess (sess-send (expr-Nat) (sess-end)))
  (define-values (net1 curr-cell) (rt-fresh-session-cell net0 sess))
  (define-values (net2 next-cell) (rt-fresh-session-cell net1 sess-bot))
  (define-values (net3 _pid)
    (rt-add-session-advance net2 curr-cell next-cell sess-send? sess-send-cont))
  (define net4 (run-to-quiescence net3))
  ;; next-cell should have the continuation (sess-end)
  (check-equal? (net-cell-read net4 next-cell) (sess-end)))

(test-case "session-advance: Recv → continuation"
  (define net0 (make-prop-network))
  ;; Session: Recv String End
  (define sess (sess-recv (expr-String) (sess-end)))
  (define-values (net1 curr-cell) (rt-fresh-session-cell net0 sess))
  (define-values (net2 next-cell) (rt-fresh-session-cell net1 sess-bot))
  (define-values (net3 _pid)
    (rt-add-session-advance net2 curr-cell next-cell sess-recv? sess-recv-cont))
  (define net4 (run-to-quiescence net3))
  (check-equal? (net-cell-read net4 next-cell) (sess-end)))

(test-case "session-advance: wrong shape → contradiction"
  (define net0 (make-prop-network))
  ;; Session is Send, but we try to advance as Recv
  (define sess (sess-send (expr-Nat) (sess-end)))
  (define-values (net1 curr-cell) (rt-fresh-session-cell net0 sess))
  (define-values (net2 next-cell) (rt-fresh-session-cell net1 sess-bot))
  (define-values (net3 _pid)
    (rt-add-session-advance net2 curr-cell next-cell sess-recv? sess-recv-cont))
  (define net4 (run-to-quiescence net3))
  ;; Should have contradiction on the session cell
  (check-true (net-contradiction? net4)))

(test-case "session-advance: two-step chain (Send then Recv)"
  (define net0 (make-prop-network))
  ;; Session: Send Nat (Recv String End)
  (define sess (sess-send (expr-Nat) (sess-recv (expr-String) (sess-end))))
  (define-values (net1 cell-0) (rt-fresh-session-cell net0 sess))
  (define-values (net2 cell-1) (rt-fresh-session-cell net1 sess-bot))
  (define-values (net3 cell-2) (rt-fresh-session-cell net2 sess-bot))
  ;; Step 1: Send → cell-1
  (define-values (net4 _p1)
    (rt-add-session-advance net3 cell-0 cell-1 sess-send? sess-send-cont))
  ;; Step 2: Recv → cell-2
  (define-values (net5 _p2)
    (rt-add-session-advance net4 cell-1 cell-2 sess-recv? sess-recv-cont))
  (define net6 (run-to-quiescence net5))
  ;; cell-1 should be Recv String End
  (check-equal? (net-cell-read net6 cell-1) (sess-recv (expr-String) (sess-end)))
  ;; cell-2 should be End
  (check-equal? (net-cell-read net6 cell-2) (sess-end)))

(test-case "session-advance: Mu unfolds before matching"
  (define net0 (make-prop-network))
  ;; Session: Mu(Send Nat (SVar 0))  — recursive session
  ;; Unfolds to: Send Nat (Mu(Send Nat (SVar 0)))
  (define sess (sess-mu (sess-send (expr-Nat) (sess-svar 0))))
  (define-values (net1 curr-cell) (rt-fresh-session-cell net0 sess))
  (define-values (net2 next-cell) (rt-fresh-session-cell net1 sess-bot))
  (define-values (net3 _pid)
    (rt-add-session-advance net2 curr-cell next-cell sess-send? sess-send-cont))
  (define net4 (run-to-quiescence net3))
  ;; next-cell should have the unfolded continuation: Mu(Send Nat (SVar 0))
  ;; (the recursive body with SVar 0 replaced by the Mu itself)
  (check-equal? (net-cell-read net4 next-cell) sess))

;; ========================================
;; Runtime Network Operations
;; ========================================

(test-case "runtime-network: register and lookup channels"
  (define rnet (make-runtime-network))
  (define sess (sess-send (expr-Nat) (sess-end)))
  (define-values (rnet* pair) (rt-new-channel-pair rnet sess))
  (define ep-a (channel-pair-ep-a pair))
  (define rnet2 (rt-register-channel rnet* 'self ep-a))
  (check-equal? (rt-lookup-channel rnet2 'self) ep-a)
  (check-false (rt-lookup-channel rnet2 'unknown)))

(test-case "runtime-network: contradiction detection"
  (define rnet (make-runtime-network))
  (check-false (rt-contradiction? rnet))
  (define sess (sess-send (expr-Nat) (sess-end)))
  (define-values (rnet* pair) (rt-new-channel-pair rnet sess))
  (define ep-a (channel-pair-ep-a pair))
  ;; Write two different values to the same message cell → contradiction
  (define rnet2 (rt-cell-write rnet* (channel-endpoint-msg-out-cell ep-a) "first"))
  (define rnet3 (rt-cell-write rnet2 (channel-endpoint-msg-out-cell ep-a) "second"))
  (check-true (rt-contradiction? rnet3)))

(test-case "runtime-network: end-to-end message flow"
  (define rnet (make-runtime-network))
  ;; Create channel pair for Send String (Recv Nat End)
  (define sess (sess-send (expr-String) (sess-recv (expr-Nat) (sess-end))))
  (define-values (rnet* pair) (rt-new-channel-pair rnet sess))
  (define ep-a (channel-pair-ep-a pair))
  (define ep-b (channel-pair-ep-b pair))
  ;; Register channels
  (define rnet2 (rt-register-channel (rt-register-channel rnet* 'a ep-a) 'b ep-b))
  ;; A sends "hello" → B receives it
  (define rnet3 (rt-run-to-quiescence
                  (rt-cell-write rnet2 (channel-endpoint-msg-out-cell ep-a) "hello")))
  (check-equal? (rt-cell-read rnet3 (channel-endpoint-msg-in-cell ep-b)) "hello")
  ;; B sends 42 → A receives it
  (define rnet4 (rt-run-to-quiescence
                  (rt-cell-write rnet3 (channel-endpoint-msg-out-cell ep-b) 42)))
  (check-equal? (rt-cell-read rnet4 (channel-endpoint-msg-in-cell ep-a)) 42)
  ;; No contradiction
  (check-false (rt-contradiction? rnet4)))
