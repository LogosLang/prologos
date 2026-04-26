#lang racket/base

;;;
;;; WS-5: End-to-end .prologos file tests
;;; Validates loading actual .prologos files via process-file,
;;; exercising the complete WS reader → type-checker pipeline.
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
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-session-registry (hasheq)]
                 [current-strategy-registry (hasheq)]
                 [current-module-registry (hasheq)]
                 )
    (process-file path)))

;; ========================================
;; E2E-01: Basic session + process
;; ========================================

(test-case "e2e-file: ws-session-e2e-01.prologos loads successfully"
  (define results (run-file "ws-session-e2e-01.prologos"))
  (check-true (list? results))
  ;; Should have 4 results: session Greeting, defproc greeter, session Echo, defproc echo-client
  (check-equal? (length results) 4)
  ;; No errors
  (for ([r (in-list results)])
    (check-false (prologos-error? r)
                 (format "Unexpected error: ~a" r)))
  ;; First result: session defined
  (check-true (string-contains? (car results) "session Greeting defined"))
  ;; Second result: defproc type-checked
  (check-true (string-contains? (cadr results) "type-checked"))
  ;; Third: session Echo defined
  (check-true (string-contains? (caddr results) "session Echo defined"))
  ;; Fourth: defproc echo-client type-checked
  (check-true (string-contains? (cadddr results) "type-checked")))

(test-case "e2e-file: session registry populated from file"
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-session-registry (hasheq)]
                 [current-strategy-registry (hasheq)]
                 [current-module-registry (hasheq)]
                 )
    (process-file (build-path here "ws-session-e2e-01.prologos"))
    ;; Greeting and Echo sessions should be registered
    (check-true (session-entry? (lookup-session 'Greeting)))
    (check-true (session-entry? (lookup-session 'Echo)))
    ;; Greeting: Send String End
    (define greeting-st (session-entry-session-type (lookup-session 'Greeting)))
    (check-true (sess-send? greeting-st))
    (check-true (sess-end? (sess-send-cont greeting-st)))))

;; ========================================
;; E2E-02: Offer + strategy
;; ========================================

(test-case "e2e-file: ws-session-e2e-02.prologos loads successfully"
  (define results (run-file "ws-session-e2e-02.prologos"))
  (check-true (list? results))
  ;; Should have 4 results: session Server, defproc handler, strategy default, strategy realtime
  (check-equal? (length results) 4)
  ;; No errors
  (for ([r (in-list results)])
    (check-false (prologos-error? r)
                 (format "Unexpected error: ~a" r))))

(test-case "e2e-file: offer session + process from file"
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-session-registry (hasheq)]
                 [current-strategy-registry (hasheq)]
                 [current-module-registry (hasheq)]
                 )
    (process-file (build-path here "ws-session-e2e-02.prologos"))
    ;; Server session
    (define entry (lookup-session 'Server))
    (check-true (session-entry? entry))
    (define st (session-entry-session-type entry))
    (check-true (sess-offer? st))
    ;; Strategy registry
    (check-true (strategy-entry? (lookup-strategy 'default)))
    (check-true (strategy-entry? (lookup-strategy 'realtime)))
    ;; Realtime strategy has overridden properties
    (define rt (lookup-strategy 'realtime))
    (check-equal? (hash-ref (strategy-entry-properties rt) ':fairness) ':priority)
    (check-equal? (hash-ref (strategy-entry-properties rt) ':fuel) 10000)))
