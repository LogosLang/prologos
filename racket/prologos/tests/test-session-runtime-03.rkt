#lang racket/base

;;;
;;; S7c: End-to-end spawn execution tests
;;;
;;; Tests the full pipeline: source string → parse → elaborate → spawn → execute
;;; Validates process registry, spawn command, and protocol completion/violation.
;;;
;;; Note: proc-new + proc-par tests are at the runtime level in test-session-runtime-02.rkt.
;;; Session type references inside proc-new are not resolved during type-checking (S3 limitation),
;;; so proc-new tests that go through the full pipeline are deferred.
;;;

(require rackunit
         racket/list
         racket/string
         "../driver.rkt"
         "../errors.rkt"
         "../sessions.rkt"
         "../macros.rkt"
         "../global-env.rkt"
         "../namespace.rkt"
         "../metavar-store.rkt")

;; Helper: run a multi-line sexp-mode string, return last result
;; Uses minimal state (no prelude) — session types use built-in Nat.
(define (run-last s)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-session-registry (hasheq)]
                 [current-strategy-registry (hasheq)]
                 [current-process-registry (hasheq)]
                 [current-module-registry (hasheq)]
                 [current-mult-meta-store (make-hasheq)])
    (define results (process-string s))
    (last results)))

;; Helper: run and return all results
(define (run-all s)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-session-registry (hasheq)]
                 [current-strategy-registry (hasheq)]
                 [current-process-registry (hasheq)]
                 [current-module-registry (hasheq)]
                 [current-mult-meta-store (make-hasheq)])
    (process-string s)))

;; ========================================
;; Basic spawn: named process
;; ========================================

(test-case "spawn: basic send + stop"
  (define result (run-last
    (string-append
     "(session S (Send Nat End))\n"
     "(defproc sender : S (proc-send self 42N (proc-stop)))\n"
     "(spawn sender)")))
  (check-false (prologos-error? result)
               (format "Expected success, got: ~a" result))
  (check-true (string-contains? result "executed")))

(test-case "spawn: basic recv + stop"
  (define result (run-last
    (string-append
     "(session R (Recv Nat End))\n"
     "(defproc receiver : R (proc-recv self x (proc-stop)))\n"
     "(spawn receiver)")))
  (check-false (prologos-error? result)
               (format "Expected success, got: ~a" result))
  (check-true (string-contains? result "executed")))

(test-case "spawn: end-only process"
  (define result (run-last
    (string-append
     "(session E End)\n"
     "(defproc trivial : E (proc-stop))\n"
     "(spawn trivial)")))
  (check-false (prologos-error? result)
               (format "Expected success, got: ~a" result))
  (check-true (string-contains? result "executed")))

(test-case "spawn: send string + stop"
  (define result (run-last
    (string-append
     "(session Greeting (Send String End))\n"
     "(defproc greeter : Greeting (proc-send self \"hello\" (proc-stop)))\n"
     "(spawn greeter)")))
  (check-false (prologos-error? result)
               (format "Expected success, got: ~a" result))
  (check-true (string-contains? result "executed")))

;; ========================================
;; Protocol violation via spawn
;; ========================================

(test-case "spawn: protocol violation (send on recv session)"
  ;; Process tries to send but session expects recv → defproc type-check fails
  (define result (run-last
    (string-append
     "(session R (Recv Nat End))\n"
     "(defproc bad-sender : R (proc-send self 42N (proc-stop)))")))
  (check-true (prologos-error? result)
              (format "Expected error, got: ~a" result)))

(test-case "spawn: protocol violation (stop with remaining protocol)"
  ;; Process stops but session has (Send Nat (Send Nat End)) → type-check fails
  (define result (run-last
    (string-append
     "(session S (Send Nat (Send Nat End)))\n"
     "(defproc short-sender : S (proc-send self 42N (proc-stop)))")))
  (check-true (prologos-error? result)
              (format "Expected error, got: ~a" result)))

;; ========================================
;; Anonymous spawn (inline process)
;; ========================================

(test-case "spawn: anonymous inline process"
  (define result (run-last
    (string-append
     "(session S (Send Nat End))\n"
     "(spawn (proc : S (proc-send self 42N (proc-stop))))")))
  (check-false (prologos-error? result)
               (format "Expected success, got: ~a" result))
  (check-true (string-contains? result "executed")))

(test-case "spawn: anonymous inline with recv"
  (define result (run-last
    (string-append
     "(session R (Recv Nat End))\n"
     "(spawn (proc : R (proc-recv self x (proc-stop))))")))
  (check-false (prologos-error? result)
               (format "Expected success, got: ~a" result))
  (check-true (string-contains? result "executed")))

;; ========================================
;; Multi-step sessions
;; ========================================

(test-case "spawn: send then recv sequence"
  (define result (run-last
    (string-append
     "(session SR (Send Nat (Recv Nat End)))\n"
     "(defproc multi : SR (proc-send self 7N (proc-recv self x (proc-stop))))\n"
     "(spawn multi)")))
  (check-false (prologos-error? result)
               (format "Expected success, got: ~a" result))
  (check-true (string-contains? result "executed")))

(test-case "spawn: choice (select) + stop"
  (define result (run-last
    (string-append
     "(session C (Choice ((inc End) (done End))))\n"
     "(defproc chooser : C (proc-sel self inc (proc-stop)))\n"
     "(spawn chooser)")))
  (check-false (prologos-error? result)
               (format "Expected success, got: ~a" result))
  (check-true (string-contains? result "executed")))

(test-case "spawn: offer (case) + stop"
  (define result (run-last
    (string-append
     "(session O (Offer ((inc End) (done End))))\n"
     "(defproc handler : O (proc-case self ((inc (proc-stop)) (done (proc-stop)))))\n"
     "(spawn handler)")))
  (check-false (prologos-error? result)
               (format "Expected success, got: ~a" result))
  (check-true (string-contains? result "executed")))

;; ========================================
;; Process registry
;; ========================================

(test-case "spawn: unknown process → error"
  (define result (run-last
    "(spawn nonexistent)"))
  (check-true (prologos-error? result)
              (format "Expected error for unknown process, got: ~a" result)))

(test-case "spawn: multiple defproc + spawn"
  ;; Define two processes, spawn the second
  (define results (run-all
    (string-append
     "(session S (Send Nat End))\n"
     "(defproc p1 : S (proc-send self 1N (proc-stop)))\n"
     "(defproc p2 : S (proc-send self 2N (proc-stop)))\n"
     "(spawn p2)")))
  (check-equal? (length results) 4)
  ;; First three: session defined, p1 type-checked, p2 type-checked
  (check-false (prologos-error? (list-ref results 0)))
  (check-false (prologos-error? (list-ref results 1)))
  (check-false (prologos-error? (list-ref results 2)))
  ;; Fourth: spawn p2 executed
  (define spawn-result (list-ref results 3))
  (check-false (prologos-error? spawn-result)
               (format "Expected spawn success, got: ~a" spawn-result))
  (check-true (string-contains? spawn-result "executed")))

;; ========================================
;; Process registry check
;; ========================================

(test-case "spawn: process registry populated after defproc"
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-session-registry (hasheq)]
                 [current-strategy-registry (hasheq)]
                 [current-process-registry (hasheq)]
                 [current-module-registry (hasheq)]
                 [current-mult-meta-store (make-hasheq)])
    (process-string
      (string-append
       "(session S (Send Nat End))\n"
       "(defproc myproc : S (proc-send self 42N (proc-stop)))"))
    ;; Process should be registered
    (check-true (process-entry? (lookup-process 'myproc)))
    (define entry (lookup-process 'myproc))
    (check-equal? (process-entry-name entry) 'myproc)
    ;; Session type should be sess-send
    (check-true (sess-send? (process-entry-session-type entry)))))

(test-case "spawn: process registry not populated on type-check failure"
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-session-registry (hasheq)]
                 [current-strategy-registry (hasheq)]
                 [current-process-registry (hasheq)]
                 [current-module-registry (hasheq)]
                 [current-mult-meta-store (make-hasheq)])
    (process-string
      (string-append
       "(session R (Recv Nat End))\n"
       "(defproc bad : R (proc-send self 42N (proc-stop)))"))
    ;; Process should NOT be registered (type-check failed)
    (check-false (lookup-process 'bad))))

;; ========================================
;; E2E combination: full pipeline
;; ========================================

(test-case "e2e: session + defproc + spawn pipeline"
  (define results (run-all
    (string-append
     "(session Ping (Send Nat End))\n"
     "(defproc pinger : Ping (proc-send self 42N (proc-stop)))\n"
     "(spawn pinger)")))
  (check-equal? (length results) 3)
  ;; Session defined
  (check-true (string-contains? (list-ref results 0) "session Ping defined"))
  ;; Process type-checked
  (check-true (string-contains? (list-ref results 1) "type-checked"))
  ;; Spawn executed
  (check-true (string-contains? (list-ref results 2) "executed")))

(test-case "e2e: spawn then spawn again (same process)"
  (define results (run-all
    (string-append
     "(session S (Send Nat End))\n"
     "(defproc repeatable : S (proc-send self 1N (proc-stop)))\n"
     "(spawn repeatable)\n"
     "(spawn repeatable)")))
  (check-equal? (length results) 4)
  ;; Both spawns should succeed
  (check-false (prologos-error? (list-ref results 2)))
  (check-false (prologos-error? (list-ref results 3)))
  (check-true (string-contains? (list-ref results 2) "executed"))
  (check-true (string-contains? (list-ref results 3) "executed")))
