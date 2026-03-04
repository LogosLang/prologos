#lang racket/base

;;;
;;; Tests for session deadlock/completeness detection (Phase S4f)
;;; Validates that incomplete protocols and unused channels are detected.
;;;

(require rackunit
         racket/string
         "../syntax.rkt"
         "../sessions.rkt"
         "../processes.rkt"
         "../errors.rkt"
         "../session-lattice.rkt"
         "../session-propagators.rkt"
         "../propagator.rkt")

;; ========================================
;; Helpers
;; ========================================

(define (check-ok? result) (eq? result 'ok))
(define (check-protocol-error? result) (session-protocol-error? result))

(define (error-message result)
  (if (prologos-error? result) (prologos-error-message result) ""))

;; ========================================
;; Valid processes: completeness passes
;; ========================================

(test-case "deadlock: send/stop against Send End passes"
  (define sess (sess-send (expr-String) (sess-end)))
  (define proc (proc-send (expr-string "hello") 'self (proc-stop)))
  (check-true (check-ok? (check-session-via-propagators proc sess))))

(test-case "deadlock: multi-step send/recv/stop passes"
  (define sess (sess-send (expr-String) (sess-recv (expr-Nat) (sess-end))))
  (define proc (proc-send (expr-string "hello") 'self
                 (proc-recv 'self #f (proc-stop))))
  (check-true (check-ok? (check-session-via-propagators proc sess))))

(test-case "deadlock: stop against End passes"
  (define sess (sess-end))
  (define proc (proc-stop))
  (check-true (check-ok? (check-session-via-propagators proc sess))))

(test-case "deadlock: select with matching label passes"
  (define sess (sess-choice (list (cons 'inc (sess-send (expr-Nat) (sess-end)))
                                   (cons 'done (sess-end)))))
  (define proc (proc-sel 'self 'inc (proc-send (expr-nat-val 42) 'self (proc-stop))))
  (check-true (check-ok? (check-session-via-propagators proc sess))))

(test-case "deadlock: case/offer with branches passes"
  (define sess (sess-offer (list (cons 'get (sess-send (expr-String) (sess-end)))
                                  (cons 'put (sess-recv (expr-String) (sess-end))))))
  (define proc
    (proc-case 'self
      (list (cons 'get (proc-send (expr-string "value") 'self (proc-stop)))
            (cons 'put (proc-recv 'self #f (proc-stop))))))
  (check-true (check-ok? (check-session-via-propagators proc sess))))

(test-case "deadlock: proc-new with complementary par passes"
  (define proc
    (proc-new (sess-send (expr-String) (sess-end))
      (proc-par
        (proc-send (expr-string "hi") 'ch (proc-stop))
        (proc-recv 'ch #f (proc-stop)))))
  (check-true (check-ok? (check-session-via-propagators proc (sess-end)))))

;; ========================================
;; Standalone completeness check
;; ========================================

(test-case "completeness: direct call on clean network passes"
  (define net0 (make-prop-network))
  (define-values (net1 cid) (make-session-cell net0 (sess-end)))
  ;; A cell at sess-end with init trace should pass
  (define trace (hasheq cid (list (session-op 'init 'self "test"))))
  (check-true (check-ok? (check-session-completeness net1 trace))))

(test-case "completeness: stop cell not at end detected"
  ;; Create a cell with a concrete session, add a stop trace but don't actually
  ;; run stop propagator — simulating incomplete termination
  (define net0 (make-prop-network))
  (define-values (net1 cid) (make-session-cell net0 (sess-send (expr-Nat) (sess-end))))
  (define trace
    (hasheq cid (list (session-op 'stop 'self "process stops"))))
  (define result (check-session-completeness net1 trace))
  ;; Cell is at sess-send (not end), has stop op → incomplete
  (check-true (check-protocol-error? result))
  (check-true (string-contains? (error-message result) "Incomplete protocol")))

;; ========================================
;; Contradictions still work
;; ========================================

(test-case "deadlock: contradiction takes priority over completeness"
  ;; send against recv is a contradiction, not a deadlock
  (define sess (sess-recv (expr-Nat) (sess-end)))
  (define proc (proc-send (expr-nat-val 42) 'self (proc-stop)))
  (define result (check-session-via-propagators proc sess))
  (check-true (check-protocol-error? result))
  (check-true (string-contains? (error-message result) "Protocol violation")))
