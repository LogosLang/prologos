#lang racket/base

;;;
;;; Tests for effect-bridge.rkt — Session-Effect Bridge Propagator (AD-B)
;;;

(require rackunit
         "../propagator.rkt"
         "../sessions.rkt"
         "../session-lattice.rkt"
         "../effect-position.rkt"
         "../effect-bridge.rkt"
         "../syntax.rkt")


;; ========================================
;; Helper: standard session types for testing
;; ========================================

;; !String . ?Int . end
(define sess-send-recv
  (sess-send (expr-String) (sess-recv (expr-Int) (sess-end))))

;; !String . end
(define sess-send-only
  (sess-send (expr-String) (sess-end)))

;; ?Int . end
(define sess-recv-only
  (sess-recv (expr-Int) (sess-end)))

;; !A . !B . !C . end (three sends)
(define sess-three-sends
  (sess-send (expr-String)
    (sess-send (expr-Int)
      (sess-send (expr-Nat)
        (sess-end)))))


;; ========================================
;; AD-B1: Single-Channel Bridge — Basic Wiring
;; ========================================

(test-case "add-session-effect-bridge: returns network and prop-id"
  (define net0 (make-prop-network))
  ;; Create session cell (bot = no session info yet)
  (define-values (net1 sess-cell)
    (net-new-cell net0 sess-bot session-lattice-merge))
  ;; Create effect position cell
  (define-values (net2 eff-cell)
    (net-new-cell net1 eff-bot eff-pos-merge))
  ;; Install bridge
  (define-values (net3 pid)
    (add-session-effect-bridge net2 sess-cell eff-cell 'ch sess-send-recv))
  (check-true (prop-network? net3))
  (check-true (prop-id? pid)))


;; ========================================
;; AD-B1: Session bot → Effect bot (no propagation)
;; ========================================

(test-case "bridge: sess-bot leaves effect cell at eff-bot"
  (define net0 (make-prop-network))
  (define-values (net1 sess-cell) (net-new-cell net0 sess-bot session-lattice-merge))
  (define-values (net2 eff-cell)  (net-new-cell net1 eff-bot eff-pos-merge))
  (define-values (net3 _pid)     (add-session-effect-bridge net2 sess-cell eff-cell 'ch sess-send-recv))
  ;; Run to quiescence — session is bot, so no effect written
  (define net4 (run-to-quiescence net3))
  (check-true (eff-bot? (net-cell-read net4 eff-cell))))


;; ========================================
;; AD-B1: Full session → depth 0
;; ========================================

(test-case "bridge: full session writes eff-pos depth 0"
  (define net0 (make-prop-network))
  ;; Session cell starts with the full session type
  (define-values (net1 sess-cell)
    (net-new-cell net0 sess-send-recv session-lattice-merge))
  (define-values (net2 eff-cell)
    (net-new-cell net1 eff-bot eff-pos-merge))
  (define-values (net3 _pid)
    (add-session-effect-bridge net2 sess-cell eff-cell 'ch sess-send-recv))
  ;; Run to quiescence — session = full-session, depth = 0
  (define net4 (run-to-quiescence net3))
  (check-equal? (net-cell-read net4 eff-cell) (eff-pos 'ch 0)))


;; ========================================
;; AD-B1: Partial session → correct depth
;; ========================================

(test-case "bridge: partial session (after one send) writes depth 1"
  (define net0 (make-prop-network))
  ;; Session cell has the continuation after the first send: ?Int.end
  (define cont-after-send (sess-recv (expr-Int) (sess-end)))
  (define-values (net1 sess-cell)
    (net-new-cell net0 cont-after-send session-lattice-merge))
  (define-values (net2 eff-cell)
    (net-new-cell net1 eff-bot eff-pos-merge))
  (define-values (net3 _pid)
    (add-session-effect-bridge net2 sess-cell eff-cell 'ch sess-send-recv))
  (define net4 (run-to-quiescence net3))
  (check-equal? (net-cell-read net4 eff-cell) (eff-pos 'ch 1)))

(test-case "bridge: session at end writes depth 2"
  (define net0 (make-prop-network))
  ;; Session cell = sess-end, the tail of !String.?Int.end after both steps
  (define-values (net1 sess-cell)
    (net-new-cell net0 (sess-end) session-lattice-merge))
  (define-values (net2 eff-cell)
    (net-new-cell net1 eff-bot eff-pos-merge))
  (define-values (net3 _pid)
    (add-session-effect-bridge net2 sess-cell eff-cell 'ch sess-send-recv))
  (define net4 (run-to-quiescence net3))
  (check-equal? (net-cell-read net4 eff-cell) (eff-pos 'ch 2)))


;; ========================================
;; AD-B1: Session advancement via cell write
;; ========================================

(test-case "bridge: writing new session value triggers position update"
  (define net0 (make-prop-network))
  ;; Start with bot
  (define-values (net1 sess-cell) (net-new-cell net0 sess-bot session-lattice-merge))
  (define-values (net2 eff-cell)  (net-new-cell net1 eff-bot eff-pos-merge))
  (define-values (net3 _pid)     (add-session-effect-bridge net2 sess-cell eff-cell 'ch sess-send-recv))
  ;; Run to quiescence — still bot
  (define net4 (run-to-quiescence net3))
  (check-true (eff-bot? (net-cell-read net4 eff-cell)))
  ;; Now write the full session to the session cell
  (define net5 (net-cell-write net4 sess-cell sess-send-recv))
  ;; Run to quiescence — should propagate to eff-pos depth 0
  (define net6 (run-to-quiescence net5))
  (check-equal? (net-cell-read net6 eff-cell) (eff-pos 'ch 0)))


;; ========================================
;; AD-B1: Session top → Effect top
;; ========================================

(test-case "bridge: sess-top propagates to eff-top"
  (define net0 (make-prop-network))
  (define-values (net1 sess-cell)
    (net-new-cell net0 sess-top session-lattice-merge))
  (define-values (net2 eff-cell)
    (net-new-cell net1 eff-bot eff-pos-merge))
  (define-values (net3 _pid)
    (add-session-effect-bridge net2 sess-cell eff-cell 'ch sess-send-recv))
  (define net4 (run-to-quiescence net3))
  (check-true (eff-top? (net-cell-read net4 eff-cell))))


;; ========================================
;; AD-B1: Three-step session
;; ========================================

(test-case "bridge: three-send session, each step gives correct depth"
  ;; full = !String.!Int.!Nat.end
  ;; after 0 steps = full → depth 0
  ;; after 1 step = !Int.!Nat.end → depth 1
  ;; after 2 steps = !Nat.end → depth 2
  ;; after 3 steps = end → depth 3
  (define net0 (make-prop-network))

  ;; Depth 0: full session
  (define-values (net1 sess-cell-0)
    (net-new-cell net0 sess-three-sends session-lattice-merge))
  (define-values (net2 eff-cell-0)
    (net-new-cell net1 eff-bot eff-pos-merge))
  (define-values (net3 _p0)
    (add-session-effect-bridge net2 sess-cell-0 eff-cell-0 'x sess-three-sends))
  (define net4 (run-to-quiescence net3))
  (check-equal? (net-cell-read net4 eff-cell-0) (eff-pos 'x 0))

  ;; Depth 2: after two sends
  (define after-two (sess-send (expr-Nat) (sess-end)))
  (define-values (net5 sess-cell-2)
    (net-new-cell net4 after-two session-lattice-merge))
  (define-values (net6 eff-cell-2)
    (net-new-cell net5 eff-bot eff-pos-merge))
  (define-values (net7 _p2)
    (add-session-effect-bridge net6 sess-cell-2 eff-cell-2 'x sess-three-sends))
  (define net8 (run-to-quiescence net7))
  (check-equal? (net-cell-read net8 eff-cell-2) (eff-pos 'x 2)))


;; ========================================
;; AD-B1: Monotonicity — deeper position overwrites shallower
;; ========================================

(test-case "bridge: effect position merge is monotonic (higher depth wins)"
  ;; In practice, session cells don't get "overwritten" with continuations —
  ;; each process step creates new cells. Test monotonicity via eff-pos-merge:
  ;; writing (eff-pos 'ch 1) after (eff-pos 'ch 0) keeps depth 1.
  (define net0 (make-prop-network))
  (define-values (net1 eff-cell) (net-new-cell net0 eff-bot eff-pos-merge))
  ;; Write depth 0
  (define net2 (net-cell-write net1 eff-cell (eff-pos 'ch 0)))
  (check-equal? (net-cell-read net2 eff-cell) (eff-pos 'ch 0))
  ;; Write depth 1 — higher depth wins via eff-pos-merge
  (define net3 (net-cell-write net2 eff-cell (eff-pos 'ch 1)))
  (check-equal? (net-cell-read net3 eff-cell) (eff-pos 'ch 1))
  ;; Write depth 0 again — lower depth is absorbed (monotone)
  (define net4 (net-cell-write net3 eff-cell (eff-pos 'ch 0)))
  (check-equal? (net-cell-read net4 eff-cell) (eff-pos 'ch 1)))


;; ========================================
;; AD-B1: Session with choice
;; ========================================

(test-case "bridge: session with choice, branch continuation"
  ;; choice { left: !String.end, right: !Int.end }
  (define sess-choice-type
    (sess-choice (list (cons 'left (sess-send (expr-String) (sess-end)))
                       (cons 'right (sess-send (expr-Int) (sess-end))))))
  (define net0 (make-prop-network))
  ;; After choosing 'left: !String.end is the continuation
  (define branch-cont (sess-send (expr-String) (sess-end)))
  (define-values (net1 sess-cell)
    (net-new-cell net0 branch-cont session-lattice-merge))
  (define-values (net2 eff-cell)
    (net-new-cell net1 eff-bot eff-pos-merge))
  (define-values (net3 _pid)
    (add-session-effect-bridge net2 sess-cell eff-cell 'ch sess-choice-type))
  (define net4 (run-to-quiescence net3))
  ;; choice is step 0, then !String is step 1 → branch-cont is at depth 1
  (check-equal? (net-cell-read net4 eff-cell) (eff-pos 'ch 1)))


;; ========================================
;; AD-B2: Multi-Channel Bridge — Basic
;; ========================================

(test-case "add-multi-channel-bridges: creates cells for all channels"
  (define net0 (make-prop-network))
  ;; Two channels: a with !String.end, b with ?Int.end
  (define-values (net1 sess-cell-a)
    (net-new-cell net0 sess-send-only session-lattice-merge))
  (define-values (net2 sess-cell-b)
    (net-new-cell net1 sess-recv-only session-lattice-merge))
  (define channel-sessions
    (list (list 'a sess-cell-a sess-send-only)
          (list 'b sess-cell-b sess-recv-only)))
  (define-values (net3 pos-cells)
    (add-multi-channel-bridges net2 channel-sessions))
  ;; Should have two effect position cells
  (check-true (hash-has-key? pos-cells 'a))
  (check-true (hash-has-key? pos-cells 'b))
  (check-true (cell-id? (hash-ref pos-cells 'a)))
  (check-true (cell-id? (hash-ref pos-cells 'b))))


;; ========================================
;; AD-B2: Multi-Channel Bridge — Propagation
;; ========================================

(test-case "add-multi-channel-bridges: each channel gets correct depth"
  (define net0 (make-prop-network))
  ;; Channel a: full session !String.end → depth 0
  (define-values (net1 sess-cell-a)
    (net-new-cell net0 sess-send-only session-lattice-merge))
  ;; Channel b: at end of ?Int.end → depth 1
  (define-values (net2 sess-cell-b)
    (net-new-cell net1 (sess-end) session-lattice-merge))
  (define channel-sessions
    (list (list 'a sess-cell-a sess-send-only)
          (list 'b sess-cell-b sess-recv-only)))
  (define-values (net3 pos-cells)
    (add-multi-channel-bridges net2 channel-sessions))
  (define net4 (run-to-quiescence net3))
  ;; Channel a: full session = depth 0
  (check-equal? (net-cell-read net4 (hash-ref pos-cells 'a)) (eff-pos 'a 0))
  ;; Channel b: (sess-end) in ?Int.end → depth 1
  (check-equal? (net-cell-read net4 (hash-ref pos-cells 'b)) (eff-pos 'b 1)))


;; ========================================
;; AD-B2: Multi-Channel Bridge — Independence
;; ========================================

(test-case "add-multi-channel-bridges: channels are independent"
  (define net0 (make-prop-network))
  ;; Channel a starts bot, channel b starts with full session
  (define-values (net1 sess-cell-a)
    (net-new-cell net0 sess-bot session-lattice-merge))
  (define-values (net2 sess-cell-b)
    (net-new-cell net1 sess-recv-only session-lattice-merge))
  (define channel-sessions
    (list (list 'a sess-cell-a sess-send-only)
          (list 'b sess-cell-b sess-recv-only)))
  (define-values (net3 pos-cells)
    (add-multi-channel-bridges net2 channel-sessions))
  (define net4 (run-to-quiescence net3))
  ;; Channel a: still bot (session cell is bot)
  (check-true (eff-bot? (net-cell-read net4 (hash-ref pos-cells 'a))))
  ;; Channel b: full session → depth 0
  (check-equal? (net-cell-read net4 (hash-ref pos-cells 'b)) (eff-pos 'b 0))
  ;; Now advance channel a
  (define net5 (net-cell-write net4 sess-cell-a sess-send-only))
  (define net6 (run-to-quiescence net5))
  ;; Channel a now at depth 0, channel b unchanged
  (check-equal? (net-cell-read net6 (hash-ref pos-cells 'a)) (eff-pos 'a 0))
  (check-equal? (net-cell-read net6 (hash-ref pos-cells 'b)) (eff-pos 'b 0)))


;; ========================================
;; AD-B2: Multi-Channel Bridge — Top Propagation
;; ========================================

(test-case "add-multi-channel-bridges: sess-top on one channel doesn't affect others"
  (define net0 (make-prop-network))
  ;; Channel a: top (contradiction), channel b: normal
  (define-values (net1 sess-cell-a)
    (net-new-cell net0 sess-top session-lattice-merge))
  (define-values (net2 sess-cell-b)
    (net-new-cell net1 sess-recv-only session-lattice-merge))
  (define channel-sessions
    (list (list 'a sess-cell-a sess-send-only)
          (list 'b sess-cell-b sess-recv-only)))
  (define-values (net3 pos-cells)
    (add-multi-channel-bridges net2 channel-sessions))
  (define net4 (run-to-quiescence net3))
  ;; Channel a: eff-top (from sess-top)
  (check-true (eff-top? (net-cell-read net4 (hash-ref pos-cells 'a))))
  ;; Channel b: depth 0 (normal)
  (check-equal? (net-cell-read net4 (hash-ref pos-cells 'b)) (eff-pos 'b 0)))


;; ========================================
;; AD-B1: Edge case — unrelated session type
;; ========================================

(test-case "bridge: session not a suffix of full-session gives eff-top"
  (define net0 (make-prop-network))
  ;; Full session is !String.end, but cell has ?Int.end (wrong polarity)
  (define-values (net1 sess-cell)
    (net-new-cell net0 sess-recv-only session-lattice-merge))
  (define-values (net2 eff-cell)
    (net-new-cell net1 eff-bot eff-pos-merge))
  (define-values (net3 _pid)
    (add-session-effect-bridge net2 sess-cell eff-cell 'ch sess-send-only))
  (define net4 (run-to-quiescence net3))
  ;; session-steps-to returns #f → bridge writes eff-top
  (check-true (eff-top? (net-cell-read net4 eff-cell))))


;; ========================================
;; AD-B2: Single channel via multi-bridge
;; ========================================

(test-case "add-multi-channel-bridges: single channel works"
  (define net0 (make-prop-network))
  (define-values (net1 sess-cell)
    (net-new-cell net0 sess-send-recv session-lattice-merge))
  (define channel-sessions
    (list (list 'only sess-cell sess-send-recv)))
  (define-values (net2 pos-cells)
    (add-multi-channel-bridges net1 channel-sessions))
  (define net3 (run-to-quiescence net2))
  (check-equal? (hash-count pos-cells) 1)
  (check-equal? (net-cell-read net3 (hash-ref pos-cells 'only)) (eff-pos 'only 0)))


;; ========================================
;; AD-B2: Empty channel list
;; ========================================

(test-case "add-multi-channel-bridges: empty list returns empty hash"
  (define net0 (make-prop-network))
  (define-values (net1 pos-cells)
    (add-multi-channel-bridges net0 '()))
  (check-equal? (hash-count pos-cells) 0)
  ;; Network should be unchanged (no new cells or propagators)
  (check-true (prop-network? net1)))


;; ========================================
;; AD-B1: Idempotency — writing same session twice doesn't change position
;; ========================================

(test-case "bridge: writing same session value is idempotent"
  (define net0 (make-prop-network))
  (define-values (net1 sess-cell) (net-new-cell net0 sess-bot session-lattice-merge))
  (define-values (net2 eff-cell)  (net-new-cell net1 eff-bot eff-pos-merge))
  (define-values (net3 _pid)     (add-session-effect-bridge net2 sess-cell eff-cell 'ch sess-send-recv))
  ;; Write full session
  (define net4 (run-to-quiescence (net-cell-write (run-to-quiescence net3) sess-cell sess-send-recv)))
  (check-equal? (net-cell-read net4 eff-cell) (eff-pos 'ch 0))
  ;; Write same value again — no change
  (define net5 (run-to-quiescence (net-cell-write net4 sess-cell sess-send-recv)))
  (check-equal? (net-cell-read net5 eff-cell) (eff-pos 'ch 0)))
