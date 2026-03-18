#lang racket/base

;;;
;;; test-io-dep-session-02.rkt — Dependent session E2E WS tests (IO-J3)
;;;
;;; End-to-end tests for dependent session types through the full
;;; WS pipeline: WS reader → preparse → parser → elaborator.
;;; Validates that !:/?: work correctly in session declarations
;;; and in combination with other session operators.
;;;
;;; Pattern: process-string-ws with inline session definitions.
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
         "../metavar-store.rkt"
         "../syntax.rkt")

;; ========================================
;; Helpers
;; ========================================

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

(define (run-ws-results s)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-session-registry (hasheq)]
                 [current-strategy-registry (hasheq)]
                 [current-module-registry (hasheq)]
                 [current-mult-meta-store (make-hasheq)])
    (define results (process-string-ws s))
    (if (list? results) results (list results))))

(define (has-error? results)
  (for/or ([r (in-list results)])
    (prologos-error? r)))

;; ========================================
;; Group 1: WS pipeline E2E for dependent session types
;; ========================================

(test-case "IO-J3: dependent send parses through full WS pipeline"
  ;; !: n Nat in a session declaration
  (define entry (run-ws-get-session
    "session DS1\n  !: n Nat\n  end\n" 'DS1))
  (check-true (session-entry? entry)
              "DS1 should be in session registry")
  (define st (session-entry-session-type entry))
  (check-true (sess-dsend? st)
              "should produce sess-dsend")
  (check-true (sess-end? (sess-dsend-cont st))
              "continuation should be end"))

(test-case "IO-J3: dependent recv parses through full WS pipeline"
  (define entry (run-ws-get-session
    "session DR1\n  ?: x Bool\n  end\n" 'DR1))
  (check-true (session-entry? entry))
  (define st (session-entry-session-type entry))
  (check-true (sess-drecv? st))
  (check-true (sess-end? (sess-drecv-cont st))))

(test-case "IO-J3: dependent session dual is correct"
  ;; dsend should dual to drecv
  (define entry (run-ws-get-session
    "session DualTest\n  !: n Nat\n  ! String\n  end\n" 'DualTest))
  (check-true (session-entry? entry))
  (define st (session-entry-session-type entry))
  (define d (dual st))
  (check-true (sess-drecv? d)
              "dual of dsend should be drecv")
  (check-true (sess-recv? (sess-drecv-cont d))
              "dual of inner send should be recv"))

(test-case "IO-J3: dependent send with binder reference in continuation"
  ;; The real test: n is used in the continuation type
  ;; session DepRef: !: n Nat  ! n  end
  (define entry (run-ws-get-session
    "session DepRef\n  !: n Nat\n  ! n\n  end\n" 'DepRef))
  (check-true (session-entry? entry))
  (define st (session-entry-session-type entry))
  (check-true (sess-dsend? st))
  (define cont (sess-dsend-cont st))
  (check-true (sess-send? cont))
  ;; The type in the continuation should reference bvar(0)
  (check-true (expr-bvar? (sess-send-type cont))
              "type should be bvar referencing dsend binder")
  (check-equal? (expr-bvar-index (sess-send-type cont)) 0))

(test-case "IO-J3: dependent recv with binder reference in continuation"
  ;; session DepRecvRef: ?: x Nat  ? x  end
  (define entry (run-ws-get-session
    "session DepRecvRef\n  ?: x Nat\n  ? x\n  end\n" 'DepRecvRef))
  (check-true (session-entry? entry))
  (define st (session-entry-session-type entry))
  (check-true (sess-drecv? st))
  (define cont (sess-drecv-cont st))
  (check-true (sess-recv? cont))
  (check-true (expr-bvar? (sess-recv-type cont)))
  (check-equal? (expr-bvar-index (sess-recv-type cont)) 0))

(test-case "IO-J3: dependent session with recursive protocol"
  ;; session DepRec: rec  !: n Nat  ! String  rec
  (define entry (run-ws-get-session
    "session DepRec\n  rec\n    !: n Nat\n    ! String\n    rec\n" 'DepRec))
  (check-true (session-entry? entry))
  (define st (session-entry-session-type entry))
  (check-true (sess-mu? st)
              "top-level should be mu")
  (define body (sess-mu-body st))
  (check-true (sess-dsend? body)
              "body should be dsend"))

(test-case "IO-J3: dependent send followed by choice"
  ;; session DepChoice: !: n Nat  +>  | :a -> end  | :b -> end
  (define results (run-ws-results
    "session DepChoice\n  !: n Nat\n  +>\n    | :a -> end\n    | :b -> end\n"))
  (check-false (has-error? results)
               "dsend followed by choice should not error"))

(test-case "IO-J3: multiple dependent binders in sequence"
  ;; session MultiDep: !: a Nat  !: b Nat  end
  (define entry (run-ws-get-session
    "session MultiDep\n  !: a Nat\n  !: b Nat\n  end\n" 'MultiDep))
  (check-true (session-entry? entry))
  (define st (session-entry-session-type entry))
  (check-true (sess-dsend? st))
  (define inner (sess-dsend-cont st))
  (check-true (sess-dsend? inner)
              "nested dsend"))
