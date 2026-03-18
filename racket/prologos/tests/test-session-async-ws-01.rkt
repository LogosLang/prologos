#lang racket/base

;;;
;;; WS-mode tests for async session types (Phase S8a)
;;; Validates: WS reader → preparse → parser → elaborator
;;; for !! (async send) and ?? (async recv) operators.
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

;; Helper: run WS-mode string through the full pipeline, return last result
(define (run-ws s)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-session-registry (hasheq)]
                 [current-strategy-registry (hasheq)]
                 [current-module-registry (hasheq)]
                 [current-mult-meta-store (make-hasheq)])
    (define results (process-string-ws s))
    (if (list? results) (last results) results)))

;; Helper: run WS-mode string and return session entry from registry
(define (run-ws-get-session s name)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-session-registry (hasheq)]
                 [current-strategy-registry (hasheq)]
                 [current-module-registry (hasheq)]
                 [current-mult-meta-store (make-hasheq)])
    (process-string-ws s)
    (lookup-session name)))

;; ========================================
;; WS-8a: Async send (!!) in session body
;; ========================================

(test-case "ws-session: async send !! defines"
  (check-equal? (run-ws "session AsyncGreet\n  !! String\n  end\n")
                "session AsyncGreet defined."))

(test-case "ws-session: async send elaborates to sess-async-send"
  (define entry (run-ws-get-session
    "session AsyncGreet\n  !! String\n  end\n" 'AsyncGreet))
  (check-true (session-entry? entry))
  (define st (session-entry-session-type entry))
  (check-true (sess-async-send? st))
  (check-true (sess-end? (sess-async-send-cont st))))

;; ========================================
;; WS-8b: Async recv (??) in session body
;; ========================================

(test-case "ws-session: async recv ?? defines"
  (check-equal? (run-ws "session AsyncListen\n  ?? Nat\n  end\n")
                "session AsyncListen defined."))

(test-case "ws-session: async recv elaborates to sess-async-recv"
  (define entry (run-ws-get-session
    "session AsyncListen\n  ?? Nat\n  end\n" 'AsyncListen))
  (check-true (session-entry? entry))
  (define st (session-entry-session-type entry))
  (check-true (sess-async-recv? st))
  (check-true (sess-end? (sess-async-recv-cont st))))

;; ========================================
;; WS-8c: Mixed async/sync sessions
;; ========================================

(test-case "ws-session: async send then sync recv"
  (define entry (run-ws-get-session
    "session Mixed\n  !! Nat\n  ? String\n  end\n" 'Mixed))
  (check-true (session-entry? entry))
  (define st (session-entry-session-type entry))
  ;; !!Nat → ?String → end
  (check-true (sess-async-send? st))
  (define cont (sess-async-send-cont st))
  (check-true (sess-recv? cont))
  (check-true (sess-end? (sess-recv-cont cont))))

(test-case "ws-session: sync send then async recv"
  (define entry (run-ws-get-session
    "session Mixed2\n  ! Nat\n  ?? String\n  end\n" 'Mixed2))
  (check-true (session-entry? entry))
  (define st (session-entry-session-type entry))
  ;; !Nat → ??String → end
  (check-true (sess-send? st))
  (define cont (sess-send-cont st))
  (check-true (sess-async-recv? cont))
  (check-true (sess-end? (sess-async-recv-cont cont))))

;; ========================================
;; WS-8d: Duality via dual command
;; ========================================

(test-case "ws-session: dual of async session"
  (define result
    (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                   [current-ns-context #f]
                   [current-session-registry (hasheq)]
                   [current-strategy-registry (hasheq)]
                   [current-module-registry (hasheq)]
                   [current-mult-meta-store (make-hasheq)])
      (process-string-ws "session AS\n  !! Nat\n  end\ndual AS\n")))
  (check-true (list? result))
  (check-equal? (length result) 2)
  ;; dual(!!Nat . end) = ??Nat . end
  (check-true (string-contains? (second result) "??")))

;; ========================================
;; WS-8e: Process bodies with async operators
;; ========================================

(test-case "ws-session: async send in defproc type-checks"
  (define result
    (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                   [current-ns-context #f]
                   [current-session-registry (hasheq)]
                   [current-strategy-registry (hasheq)]
                   [current-module-registry (hasheq)]
                   [current-mult-meta-store (make-hasheq)])
      (process-string-ws
       (string-append
        "session AsyncGreet\n"
        "  !! String\n"
        "  end\n"
        "defproc greeter : AsyncGreet\n"
        "  self !! \"hello\"\n"
        "  stop\n"))))
  (check-true (list? result))
  (check-equal? (length result) 2)
  (check-false (prologos-error? (second result)))
  (check-true (string-contains? (second result) "type-checked")))

(test-case "ws-session: async recv in defproc type-checks"
  (define result
    (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                   [current-ns-context #f]
                   [current-session-registry (hasheq)]
                   [current-strategy-registry (hasheq)]
                   [current-module-registry (hasheq)]
                   [current-mult-meta-store (make-hasheq)])
      (process-string-ws
       (string-append
        "session AsyncListen\n"
        "  ?? Nat\n"
        "  end\n"
        "defproc listener : AsyncListen\n"
        "  x := self ??\n"
        "  stop\n"))))
  (check-true (list? result))
  (check-equal? (length result) 2)
  (check-false (prologos-error? (second result)))
  (check-true (string-contains? (second result) "type-checked")))
