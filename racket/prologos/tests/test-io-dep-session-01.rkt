#lang racket/base

;;;
;;; test-io-dep-session-01.rkt — Dependent session type tests (IO-J1+J2)
;;;
;;; Group 1: Elaborator binder scope — verifies that !:/?: binders
;;;          are in scope when elaborating continuation types.
;;; Group 2: Runtime predicates — verifies sess-send-like?/recv-like?
;;;          recognize dependent variants and cont extractors work.
;;; Group 3: IO mode inference — verifies dsend/drecv protocols
;;;          correctly infer file modes.
;;;
;;; Pattern: run-ws-get-session for elaborator tests, direct struct
;;;          construction for runtime predicate tests.
;;;

(require rackunit
         racket/list
         racket/string
         "../driver.rkt"
         "../errors.rkt"
         "../sessions.rkt"
         "../session-runtime.rkt"
         "../macros.rkt"
         "../global-env.rkt"
         "../namespace.rkt"
         "../metavar-store.rkt"
         "../syntax.rkt"
         "../substitution.rkt")

;; ========================================
;; Helpers
;; ========================================

;; Run WS-mode string and return the session-entry from the registry
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

;; Run WS-mode string and return all results as a list
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

;; Check if any result is a prologos error
(define (has-error? results)
  (for/or ([r (in-list results)])
    (prologos-error? r)))

;; ========================================
;; Group 1: Elaborator binder scope (IO-J1)
;; ========================================

(test-case "IO-J1: dsend binder in scope — continuation references bound var"
  ;; session DepSendRef: !: n Nat  ! n  end
  ;; Expected: sess-dsend(Nat, sess-send(bvar(0), endS))
  ;; The 'n' in '! n' should resolve to bvar(0), the dsend binder.
  (define entry (run-ws-get-session
    "session DepSendRef\n  !: n Nat\n  ! n\n  end\n" 'DepSendRef))
  (check-true (session-entry? entry)
              "DepSendRef should be in registry")
  (define st (session-entry-session-type entry))
  (check-true (sess-dsend? st)
              "top-level should be dsend")
  ;; Check continuation: sess-send with bvar(0)
  (define cont (sess-dsend-cont st))
  (check-true (sess-send? cont)
              "continuation should be sess-send")
  (check-true (expr-bvar? (sess-send-type cont))
              "send type should be bvar (referencing dsend binder)")
  (check-equal? (expr-bvar-index (sess-send-type cont)) 0
                "bvar index should be 0"))

(test-case "IO-J1: drecv binder in scope — continuation references bound var"
  ;; session DepRecvRef: ?: x Nat  ? x  end
  ;; Expected: sess-drecv(Nat, sess-recv(bvar(0), endS))
  (define entry (run-ws-get-session
    "session DepRecvRef\n  ?: x Nat\n  ? x\n  end\n" 'DepRecvRef))
  (check-true (session-entry? entry)
              "DepRecvRef should be in registry")
  (define st (session-entry-session-type entry))
  (check-true (sess-drecv? st)
              "top-level should be drecv")
  (define cont (sess-drecv-cont st))
  (check-true (sess-recv? cont)
              "continuation should be sess-recv")
  (check-true (expr-bvar? (sess-recv-type cont))
              "recv type should be bvar (referencing drecv binder)")
  (check-equal? (expr-bvar-index (sess-recv-type cont)) 0
                "bvar index should be 0"))

(test-case "IO-J1: dsend with non-referencing continuation (baseline)"
  ;; session DepSendSimple: !: n Nat  end
  ;; Expected: sess-dsend(Nat, endS) — binder not referenced, still works
  (define entry (run-ws-get-session
    "session DepSendSimple\n  !: n Nat\n  end\n" 'DepSendSimple))
  (check-true (session-entry? entry))
  (define st (session-entry-session-type entry))
  (check-true (sess-dsend? st))
  (check-true (sess-end? (sess-dsend-cont st))))

(test-case "IO-J1: dsend + drecv combined protocol elaborates"
  ;; session DepCombo: !: n Nat  ?: m Nat  end
  (define entry (run-ws-get-session
    "session DepCombo\n  !: n Nat\n  ?: m Nat\n  end\n" 'DepCombo))
  (check-true (session-entry? entry))
  (define st (session-entry-session-type entry))
  (check-true (sess-dsend? st))
  (define cont (sess-dsend-cont st))
  (check-true (sess-drecv? cont)
              "inner should be drecv"))

(test-case "IO-J1: dsend with String type in continuation (no binder ref)"
  ;; session DepSendStr: !: n Nat  ! String  end
  ;; The continuation uses String (global), not n
  (define results (run-ws-results
    "session DepSendStr\n  !: n Nat\n  ! String\n  end\n"))
  (check-false (has-error? results)
               "should not produce errors"))

;; ========================================
;; Group 2: Runtime predicates (IO-J2)
;; ========================================

(test-case "IO-J2: sess-send-like? recognizes sess-dsend"
  (define ds (sess-dsend (expr-Nat) (sess-end)))
  (check-true (sess-send-like? ds)
              "dsend should be send-like"))

(test-case "IO-J2: sess-recv-like? recognizes sess-drecv"
  (define dr (sess-drecv (expr-Nat) (sess-end)))
  (check-true (sess-recv-like? dr)
              "drecv should be recv-like"))

(test-case "IO-J2: sess-send-like-cont extracts from sess-dsend"
  (define cont (sess-send (expr-Bool) (sess-end)))
  (define ds (sess-dsend (expr-Nat) cont))
  (check-equal? (sess-send-like-cont ds) cont
                "should extract continuation from dsend"))

(test-case "IO-J2: sess-recv-like-cont extracts from sess-drecv"
  (define cont (sess-recv (expr-Bool) (sess-end)))
  (define dr (sess-drecv (expr-Nat) cont))
  (check-equal? (sess-recv-like-cont dr) cont
                "should extract continuation from drecv"))

(test-case "IO-J2: sess-send-like? still recognizes regular send"
  (check-true (sess-send-like? (sess-send (expr-Nat) (sess-end))))
  (check-true (sess-send-like? (sess-async-send (expr-Nat) (sess-end)))))

(test-case "IO-J2: sess-recv-like? still recognizes regular recv"
  (check-true (sess-recv-like? (sess-recv (expr-Nat) (sess-end))))
  (check-true (sess-recv-like? (sess-async-recv (expr-Nat) (sess-end)))))

;; ========================================
;; Group 3: IO mode inference (IO-J2d)
;; ========================================

(test-case "IO-J2d: io-infer-mode with dsend protocol → write"
  (define ds (sess-dsend (expr-Nat) (sess-end)))
  (check-equal? (io-infer-mode ds) 'write
                "dsend should infer write mode"))

(test-case "IO-J2d: io-infer-mode with drecv protocol → read"
  (define dr (sess-drecv (expr-Nat) (sess-end)))
  (check-equal? (io-infer-mode dr) 'read
                "drecv should infer read mode"))

;; ========================================
;; Group 4: substS for dependent send (IO-J2b)
;; ========================================

(test-case "IO-J2b: substS substitutes value into dsend continuation"
  ;; After dsend(Nat, send(bvar(0), endS)), sending suc(zero) makes:
  ;; send(suc(zero), endS)
  (define cont (sess-send (expr-bvar 0) (sess-end)))
  (define result (substS cont 0 (expr-suc (expr-zero))))
  (check-true (sess-send? result))
  (check-equal? (sess-send-type result) (expr-suc (expr-zero))
                "bvar(0) should be replaced with suc(zero)"))
