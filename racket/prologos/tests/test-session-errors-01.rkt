#lang racket/base

;;;
;;; Tests for session error derivation chains (Phase S4d)
;;; Validates that protocol violations produce structured errors
;;; with "because:" derivation chains explaining the conflict.
;;;

(require rackunit
         racket/string
         "../syntax.rkt"
         "../sessions.rkt"
         "../processes.rkt"
         "../errors.rkt"
         "../session-lattice.rkt"
         "../session-propagators.rkt"
         "../pretty-print.rkt")

;; ========================================
;; Helpers
;; ========================================

(define (check-ok? result) (eq? result 'ok))

;; Check that result is a session-protocol-error
(define (check-protocol-error? result)
  (session-protocol-error? result))

;; Extract derivation chain from a session-protocol-error
(define (error-derivation result)
  (if (session-protocol-error? result)
      (session-protocol-error-derivation result)
      '()))

;; Check that error's derivation chain contains a specific substring
(define (derivation-contains? result substr)
  (and (session-protocol-error? result)
       (for/or ([step (in-list (session-protocol-error-derivation result))])
         (string-contains? step substr))))

;; ========================================
;; Error structure: polarity mismatch
;; ========================================

(test-case "error: send against Recv has derivation chain"
  (define sess (sess-recv (expr-Nat) (sess-end)))
  (define proc (proc-send (expr-nat-val 42) 'self (proc-stop)))
  (define result (check-session-via-propagators proc sess))
  ;; Is a structured error
  (check-true (check-protocol-error? result))
  ;; Has channel info
  (check-equal? (session-error-channel result) 'self)
  ;; Has derivation chain with at least 2 entries (init + send)
  (check-true (>= (length (error-derivation result)) 2))
  ;; Derivation mentions session declaration
  (check-true (derivation-contains? result "session type declared"))
  ;; Derivation mentions send operation
  (check-true (derivation-contains? result "sends on self")))

(test-case "error: recv against Send has derivation chain"
  (define sess (sess-send (expr-String) (sess-end)))
  (define proc (proc-recv 'self #f #f (proc-stop)))
  (define result (check-session-via-propagators proc sess))
  (check-true (check-protocol-error? result))
  (check-true (derivation-contains? result "receives from self")))

(test-case "error: send against End has derivation chain"
  (define sess (sess-end))
  (define proc (proc-send (expr-nat-val 1) 'self (proc-stop)))
  (define result (check-session-via-propagators proc sess))
  (check-true (check-protocol-error? result))
  (check-true (derivation-contains? result "session type declared"))
  (check-true (derivation-contains? result "sends on self")))

(test-case "error: stop against Send has derivation chain"
  (define sess (sess-send (expr-Nat) (sess-end)))
  (define proc (proc-stop))
  (define result (check-session-via-propagators proc sess))
  (check-true (check-protocol-error? result))
  (check-true (derivation-contains? result "process stops")))

;; ========================================
;; Error structure: select/choice mismatch
;; ========================================

(test-case "error: select missing label has derivation"
  (define sess (sess-choice (list (cons 'inc (sess-send (expr-Nat) (sess-end)))
                                   (cons 'done (sess-end)))))
  (define proc (proc-sel 'self 'reset (proc-stop)))
  (define result (check-session-via-propagators proc sess))
  (check-true (check-protocol-error? result))
  (check-true (derivation-contains? result "selects label 'reset")))

;; ========================================
;; Error structure: offer/case branch mismatch
;; ========================================

(test-case "error: case branch polarity mismatch has derivation"
  (define sess (sess-offer (list (cons 'get (sess-send (expr-String) (sess-end))))))
  (define proc
    (proc-case 'self
      (list (cons 'get (proc-recv 'self #f #f (proc-stop))))))
  (define result (check-session-via-propagators proc sess))
  (check-true (check-protocol-error? result))
  ;; Should mention the branch context and the conflicting operation
  (check-true (or (derivation-contains? result "branch")
                  (derivation-contains? result "receives from self"))))

;; ========================================
;; Error formatting: format-error output
;; ========================================

(test-case "format-error: session-protocol-error has because: lines"
  (define sess (sess-recv (expr-Nat) (sess-end)))
  (define proc (proc-send (expr-nat-val 42) 'self (proc-stop)))
  (define result (check-session-via-propagators proc sess))
  (check-true (session-protocol-error? result))
  (define formatted (format-error result))
  ;; Check that formatted output contains structured info
  (check-true (string-contains? formatted "Protocol violation"))
  (check-true (string-contains? formatted "Channel: self"))
  (check-true (string-contains? formatted "because:"))
  ;; Should have at least one "because:" line
  (define because-count
    (length (filter (lambda (line) (string-contains? line "because:"))
                    (string-split formatted "\n"))))
  (check-true (>= because-count 2)))  ;; At least init + send

(test-case "format-error: includes declared session type"
  (define sess (sess-send (expr-String) (sess-end)))
  (define proc (proc-recv 'self #f #f (proc-stop)))
  (define result (check-session-via-propagators proc sess))
  (define formatted (format-error result))
  ;; Detail line should mention the declared session
  (check-true (string-contains? formatted "Declared session type")))

;; ========================================
;; Success cases still return 'ok
;; ========================================

(test-case "success: send/stop returns 'ok"
  (define sess (sess-send (expr-String) (sess-end)))
  (define proc (proc-send (expr-string "hello") 'self (proc-stop)))
  (check-true (check-ok? (check-session-via-propagators proc sess))))

(test-case "success: multi-step returns 'ok"
  (define sess (sess-send (expr-String) (sess-recv (expr-Nat) (sess-end))))
  (define proc (proc-send (expr-string "hello") 'self
                 (proc-recv 'self #f #f (proc-stop))))
  (check-true (check-ok? (check-session-via-propagators proc sess))))
