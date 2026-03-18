#lang racket/base

;;;
;;; WS-3: Process definition WS integration tests (full pipeline)
;;; Validates the full path: WS reader → preparse → parser → elaborator → type-check
;;; for defproc declarations in .prologos WS syntax.
;;;
;;; Unlike test-process-ws-01.rkt (preparse-level unit tests), these tests exercise
;;; the COMPLETE WS reader → type-checker path via process-string-ws.
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

;; Helper: set up a session in sexp mode, then process a WS defproc
(define (run-defproc-ws session-sexp defproc-ws)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-session-registry (hasheq)]
                 [current-strategy-registry (hasheq)]
                 [current-module-registry (hasheq)]
                 [current-mult-meta-store (make-hasheq)])
    (process-string session-sexp)
    (define results (process-string-ws defproc-ws))
    (if (list? results) (last results) results)))

;; Helper: run both session and defproc in WS mode
(define (run-all-ws ws-string)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-session-registry (hasheq)]
                 [current-strategy-registry (hasheq)]
                 [current-module-registry (hasheq)]
                 [current-mult-meta-store (make-hasheq)])
    (define results (process-string-ws ws-string))
    (if (list? results) (last results) results)))

;; ========================================
;; WS-3a: Send + stop via full WS pipeline
;; ========================================

(test-case "ws-pipeline: send + stop"
  (define result
    (run-defproc-ws
      "(session Greeting (Send String End))"
      "defproc greeter : Greeting\n  self ! \"hello\"\n  stop\n"))
  (check-true (string? result))
  (check-true (string-contains? result "type-checked")))

;; ========================================
;; WS-3b: Send + recv + stop
;; ========================================

(test-case "ws-pipeline: send + recv + stop"
  (define result
    (run-defproc-ws
      "(session Echo (Send String (Recv String End)))"
      "defproc echo-client : Echo\n  self ! \"hello\"\n  reply := self ?\n  stop\n"))
  (check-true (string? result))
  (check-true (string-contains? result "type-checked")))

;; ========================================
;; WS-3c: Select
;; ========================================

(test-case "ws-pipeline: select"
  (define result
    (run-defproc-ws
      "(session Counter (Choice ((:inc (Send Nat End)) (:done End))))"
      "defproc chooser : Counter\n  select self :inc\n  self ! 42N\n  stop\n"))
  (check-true (string? result))
  (check-true (string-contains? result "type-checked")))

;; ========================================
;; WS-3d: Offer with branches
;; ========================================

(test-case "ws-pipeline: offer with branches"
  (define result
    (run-defproc-ws
      "(session Server (Offer ((:get (Send String End)) (:put (Recv String End)))))"
      "defproc handler : Server\n  offer self\n    | :get ->\n        self ! \"hello\"\n        stop\n    | :put ->\n        data := self ?\n        stop\n"))
  (check-true (string? result))
  (check-true (string-contains? result "type-checked")))

;; ========================================
;; WS-3e: Without type annotation
;; ========================================

(test-case "ws-pipeline: without type annotation defines"
  (define result
    (run-defproc-ws
      "(session S (Send String End))"
      "defproc worker\n  self ! \"hello\"\n  stop\n"))
  (check-true (string? result))
  (check-true (string-contains? result "defined")))

;; ========================================
;; WS-3f: Full WS pipeline (session + defproc)
;; ========================================

(test-case "ws-pipeline: session + defproc both WS"
  (define result
    (run-all-ws
      "session Greeting\n  ! String\n  end\n\ndefproc greeter : Greeting\n  self ! \"hello\"\n  stop\n"))
  (check-true (string? result))
  (check-true (string-contains? result "type-checked")))

(test-case "ws-pipeline: session offer + defproc offer both WS"
  (define result
    (run-all-ws
      (string-append
        "session Server\n"
        "  &>\n"
        "    | :get -> ! String -> end\n"
        "    | :put -> ? String -> end\n"
        "\n"
        "defproc handler : Server\n"
        "  offer self\n"
        "    | :get ->\n"
        "        self ! \"hello\"\n"
        "        stop\n"
        "    | :put ->\n"
        "        data := self ?\n"
        "        stop\n")))
  (check-true (string? result))
  (check-true (string-contains? result "type-checked")))
