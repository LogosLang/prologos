#lang racket/base

;;;
;;; S8c: End-to-end integration tests for async session types
;;; Validates complete .prologos file loading with !! / ?? operators,
;;; mixed async/sync protocols, duality, and :scheduler-io strategy.
;;;

(require rackunit
         racket/list
         racket/string
         racket/path
         "../driver.rkt"
         "../errors.rkt"
         "../sessions.rkt"
         "../macros.rkt"
         "../global-env.rkt"
         "../namespace.rkt"
         "../metavar-store.rkt")

;; Compute path to test .prologos files
(define here (path->string (path-only (syntax-source #'here))))

;; Helper: load a .prologos file via process-file
(define (run-file filename)
  (define path (build-path here filename))
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-session-registry (hasheq)]
                 [current-strategy-registry (hasheq)]
                 [current-module-registry (hasheq)]
                 [current-mult-meta-store (make-hasheq)])
    (process-file path)))

;; ========================================
;; E2E-03: Async session file
;; ========================================

(test-case "e2e-file: ws-session-e2e-03.prologos loads successfully"
  (define results (run-file "ws-session-e2e-03.prologos"))
  (check-true (list? results))
  ;; 7 results: session AsyncPing, defproc pinger, session MixedProto,
  ;; defproc mixed-client, dual AsyncPing, strategy async-plan
  (check-equal? (length results) 6)
  ;; No errors
  (for ([r (in-list results)])
    (check-false (prologos-error? r)
                 (format "Unexpected error: ~a" r))))

(test-case "e2e-file: async session defines correctly"
  (define results (run-file "ws-session-e2e-03.prologos"))
  ;; First result: session AsyncPing defined
  (check-true (string-contains? (first results) "session AsyncPing defined")))

(test-case "e2e-file: async defproc type-checks"
  (define results (run-file "ws-session-e2e-03.prologos"))
  ;; Second result: defproc pinger type-checked
  (check-true (string-contains? (second results) "type-checked")))

(test-case "e2e-file: mixed async/sync defproc type-checks"
  (define results (run-file "ws-session-e2e-03.prologos"))
  ;; Fourth result: defproc mixed-client type-checked
  (check-true (string-contains? (fourth results) "type-checked")))

(test-case "e2e-file: async session registry populated"
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-session-registry (hasheq)]
                 [current-strategy-registry (hasheq)]
                 [current-module-registry (hasheq)]
                 [current-mult-meta-store (make-hasheq)])
    (process-file (build-path here "ws-session-e2e-03.prologos"))
    ;; AsyncPing session registered with async types
    (define entry (lookup-session 'AsyncPing))
    (check-true (session-entry? entry))
    (define st (session-entry-session-type entry))
    (check-true (sess-async-send? st))
    (define cont (sess-async-send-cont st))
    (check-true (sess-async-recv? cont))
    (check-true (sess-end? (sess-async-recv-cont cont)))))

(test-case "e2e-file: mixed session has async+sync structure"
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-session-registry (hasheq)]
                 [current-strategy-registry (hasheq)]
                 [current-module-registry (hasheq)]
                 [current-mult-meta-store (make-hasheq)])
    (process-file (build-path here "ws-session-e2e-03.prologos"))
    (define entry (lookup-session 'MixedProto))
    (check-true (session-entry? entry))
    (define st (session-entry-session-type entry))
    ;; !!Nat → ?String → !Bool → ??Nat → end
    (check-true (sess-async-send? st))
    (define s2 (sess-async-send-cont st))
    (check-true (sess-recv? s2))
    (define s3 (sess-recv-cont s2))
    (check-true (sess-send? s3))
    (define s4 (sess-send-cont s3))
    (check-true (sess-async-recv? s4))
    (check-true (sess-end? (sess-async-recv-cont s4)))))

(test-case "e2e-file: dual of async session"
  (define results (run-file "ws-session-e2e-03.prologos"))
  ;; Fifth result: dual AsyncPing = ??String . !!String . end
  (define dual-result (fifth results))
  (check-true (string-contains? dual-result "??"))
  (check-true (string-contains? dual-result "!!")))

(test-case "e2e-file: :scheduler-io strategy property"
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-session-registry (hasheq)]
                 [current-strategy-registry (hasheq)]
                 [current-module-registry (hasheq)]
                 [current-mult-meta-store (make-hasheq)])
    (process-file (build-path here "ws-session-e2e-03.prologos"))
    (define entry (lookup-strategy 'async-plan))
    (check-true (strategy-entry? entry))
    (define props (strategy-entry-properties entry))
    (check-equal? (hash-ref props ':scheduler-io) ':blocking-ok)
    (check-equal? (hash-ref props ':fuel) 100000)))
