#lang racket/base

;;;
;;; Tests for async session types (Phase S8a) — sexp mode
;;; Validates: AST constructors, duality, lattice merge, elaboration,
;;; pretty-print, type checking, and E2E pipeline.
;;;

(require rackunit
         racket/list
         racket/string
         "../syntax.rkt"
         "../sessions.rkt"
         "../session-lattice.rkt"
         "../driver.rkt"
         "../errors.rkt"
         "../macros.rkt"
         "../global-env.rkt"
         "../namespace.rkt"
         "../metavar-store.rkt"
         "../pretty-print.rkt")

;; Helper: run sexp-mode pipeline
(define (run s)
  (parameterize ([current-global-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-session-registry (hasheq)]
                 [current-strategy-registry (hasheq)]
                 [current-module-registry (hasheq)]
                 [current-mult-meta-store (make-hasheq)])
    (define results (process-string s))
    (if (list? results) (last results) results)))

;; Helper: run and return session entry
(define (run-get-session s name)
  (parameterize ([current-global-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-session-registry (hasheq)]
                 [current-strategy-registry (hasheq)]
                 [current-module-registry (hasheq)]
                 [current-mult-meta-store (make-hasheq)])
    (process-string s)
    (lookup-session name)))

;; ========================================
;; AST constructor tests
;; ========================================

(test-case "async-send struct"
  (define s (sess-async-send (expr-Nat) (sess-end)))
  (check-true (sess-async-send? s))
  (check-equal? (sess-async-send-type s) (expr-Nat))
  (check-true (sess-end? (sess-async-send-cont s))))

(test-case "async-recv struct"
  (define s (sess-async-recv (expr-String) (sess-end)))
  (check-true (sess-async-recv? s))
  (check-equal? (sess-async-recv-type s) (expr-String))
  (check-true (sess-end? (sess-async-recv-cont s))))

;; ========================================
;; Duality: async-send ↔ async-recv
;; ========================================

(test-case "dual: async-send becomes async-recv"
  (define s (sess-async-send (expr-Nat) (sess-end)))
  (define d (dual s))
  (check-true (sess-async-recv? d))
  (check-equal? (sess-async-recv-type d) (expr-Nat))
  (check-true (sess-end? (sess-async-recv-cont d))))

(test-case "dual: async-recv becomes async-send"
  (define s (sess-async-recv (expr-String) (sess-end)))
  (define d (dual s))
  (check-true (sess-async-send? d))
  (check-equal? (sess-async-send-type d) (expr-String))
  (check-true (sess-end? (sess-async-send-cont d))))

(test-case "dual: mixed sync/async round-trip"
  ;; !!Nat . ?String . end → ??Nat . !String . end
  (define s (sess-async-send (expr-Nat) (sess-recv (expr-String) (sess-end))))
  (define d (dual s))
  (check-true (sess-async-recv? d))
  (define cont (sess-async-recv-cont d))
  (check-true (sess-send? cont))
  (check-true (sess-end? (sess-send-cont cont))))

;; ========================================
;; Lattice: merge semantics
;; ========================================

(test-case "merge: async-send + bot → async-send"
  (define s (sess-async-send (expr-Nat) (sess-end)))
  (check-equal? (session-lattice-merge sess-bot s) s)
  (check-equal? (session-lattice-merge s sess-bot) s))

(test-case "merge: async-send + async-send (same) → idempotent"
  (define s (sess-async-send (expr-Nat) (sess-end)))
  (check-equal? (session-lattice-merge s s) s))

(test-case "merge: async-recv + async-recv (same) → idempotent"
  (define s (sess-async-recv (expr-String) (sess-end)))
  (check-equal? (session-lattice-merge s s) s))

(test-case "merge: async-send + sync-send → contradiction"
  (define as (sess-async-send (expr-Nat) (sess-end)))
  (define ss (sess-send (expr-Nat) (sess-end)))
  (check-true (sess-top? (session-lattice-merge as ss))))

(test-case "merge: async-recv + sync-recv → contradiction"
  (define ar (sess-async-recv (expr-Nat) (sess-end)))
  (define sr (sess-recv (expr-Nat) (sess-end)))
  (check-true (sess-top? (session-lattice-merge ar sr))))

(test-case "merge: async-send + async-recv → contradiction"
  (define as (sess-async-send (expr-Nat) (sess-end)))
  (define ar (sess-async-recv (expr-Nat) (sess-end)))
  (check-true (sess-top? (session-lattice-merge as ar))))

;; ========================================
;; Pretty-print
;; ========================================

(test-case "pp-session: async-send"
  (define s (sess-async-send (expr-Nat) (sess-end)))
  (check-true (string-contains? (pp-session s '()) "!!")))

(test-case "pp-session: async-recv"
  (define s (sess-async-recv (expr-String) (sess-end)))
  (check-true (string-contains? (pp-session s '()) "??")))

;; ========================================
;; E2E: session declaration via sexp
;; ========================================

(test-case "e2e sexp: AsyncSend/End session defines"
  (check-equal? (run "(session AsyncGreet (AsyncSend String End))")
                "session AsyncGreet defined."))

(test-case "e2e sexp: AsyncRecv/End session defines"
  (check-equal? (run "(session AsyncListen (AsyncRecv Nat End))")
                "session AsyncListen defined."))

(test-case "e2e sexp: AsyncSend elaborates to sess-async-send"
  (define entry (run-get-session "(session AS (AsyncSend Nat End))" 'AS))
  (check-true (session-entry? entry))
  (define st (session-entry-session-type entry))
  (check-true (sess-async-send? st))
  (check-true (sess-end? (sess-async-send-cont st))))

(test-case "e2e sexp: AsyncRecv elaborates to sess-async-recv"
  (define entry (run-get-session "(session AR (AsyncRecv String End))" 'AR))
  (check-true (session-entry? entry))
  (define st (session-entry-session-type entry))
  (check-true (sess-async-recv? st))
  (check-true (sess-end? (sess-async-recv-cont st))))

(test-case "e2e sexp: mixed async/sync session"
  (define entry (run-get-session
    "(session Mixed (AsyncSend Nat (Recv String End)))" 'Mixed))
  (check-true (session-entry? entry))
  (define st (session-entry-session-type entry))
  (check-true (sess-async-send? st))
  (define cont (sess-async-send-cont st))
  (check-true (sess-recv? cont))
  (check-true (sess-end? (sess-recv-cont cont))))

;; ========================================
;; E2E: dual computation for async sessions
;; ========================================

(test-case "e2e sexp: dual of async session"
  (define result
    (parameterize ([current-global-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                   [current-ns-context #f]
                   [current-session-registry (hasheq)]
                   [current-strategy-registry (hasheq)]
                   [current-module-registry (hasheq)]
                   [current-mult-meta-store (make-hasheq)])
      (process-string
       "(session AS (AsyncSend Nat End))\n(dual AS)")))
  (check-true (list? result))
  (check-equal? (length result) 2)
  ;; dual(!!Nat . end) = ??Nat . end
  (check-true (string-contains? (second result) "??")))

;; ========================================
;; E2E: process type-checking with async session
;; ========================================

(test-case "e2e sexp: proc-send against async-send type-checks"
  (define result
    (parameterize ([current-global-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                   [current-ns-context #f]
                   [current-session-registry (hasheq)]
                   [current-strategy-registry (hasheq)]
                   [current-module-registry (hasheq)]
                   [current-mult-meta-store (make-hasheq)])
      (process-string
       (string-append
        "(session AsyncGreet (AsyncSend String End))\n"
        "(defproc greeter : AsyncGreet (proc-send self \"hello\" (proc-stop)))"))))
  (check-true (list? result))
  (check-equal? (length result) 2)
  (check-false (prologos-error? (second result)))
  (check-true (string-contains? (second result) "type-checked")))

(test-case "e2e sexp: proc-recv against async-recv type-checks"
  (define result
    (parameterize ([current-global-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                   [current-ns-context #f]
                   [current-session-registry (hasheq)]
                   [current-strategy-registry (hasheq)]
                   [current-module-registry (hasheq)]
                   [current-mult-meta-store (make-hasheq)])
      (process-string
       (string-append
        "(session AsyncListen (AsyncRecv Nat End))\n"
        "(defproc listener : AsyncListen (proc-recv self x (proc-stop)))"))))
  (check-true (list? result))
  (check-equal? (length result) 2)
  (check-false (prologos-error? (second result)))
  (check-true (string-contains? (second result) "type-checked")))
