#lang racket/base

;;;
;;; Tests for ATMS surface syntax integration
;;; Phase 5e: parser -> elaborator -> type-check -> reduce -> pretty-print
;;;

(require racket/string
         racket/list
         rackunit
         "test-support.rkt"
         "../syntax.rkt"
         "../prelude.rkt"
         "../substitution.rkt"
         "../reduction.rkt"
         (prefix-in tc: "../typing-core.rkt")
         "../pretty-print.rkt"
         "../driver.rkt"
         "../global-env.rkt"
         "../errors.rkt")

;; Helper to run with clean global env (sexp mode)
(define (run s)
  (parameterize ([current-global-env (hasheq)]
                 [current-module-definitions-content (hasheq)])
    (process-string s)))

;; ========================================
;; Type checking: type constructors (sexp mode)
;; ========================================

(test-case "surface: ATMS type check"
  (check-equal? (run "(check ATMS : (Type 0))")
                '("OK")))

(test-case "surface: AssumptionId type check"
  (check-equal? (run "(check AssumptionId : (Type 0))")
                '("OK")))

;; ========================================
;; Type inference: operations (sexp mode)
;; ========================================

(test-case "surface: atms-new type infer"
  (check-equal? (run "(infer (atms-new (net-new 1000)))")
                '("ATMS")))

(test-case "surface: atms-new check"
  (check-equal? (run "(check (atms-new (net-new 1000)) : ATMS)")
                '("OK")))

(test-case "surface: atms-assume type infer"
  (let ([result (run "(infer (atms-assume (atms-new (net-new 1000)) :h0 true))")])
    (check-equal? result '("[Sigma ATMS AssumptionId]"))))

(test-case "surface: atms-retract type infer"
  ;; atms-retract on a fresh atms with dummy aid
  ;; We use sexp mode: (atms-retract atms aid)
  ;; Build from assume first — use a multi-step eval
  (check-equal? (run "(infer (atms-retract (atms-new (net-new 1000)) (the AssumptionId _)))")
                '("ATMS")))

;; ========================================
;; Evaluation: basic operations (sexp mode)
;; ========================================

(test-case "surface: eval atms-new produces ATMS"
  (let ([result (run "(eval (atms-new (net-new 1000)))")])
    (check-true (and (list? result) (= 1 (length result))))
    (check-true (string-contains? (car result) "#<atms"))))

(test-case "surface: eval atms-assume returns pair"
  (let ([result (run "(eval (atms-assume (atms-new (net-new 1000)) :h0 true))")])
    (check-true (and (list? result) (= 1 (length result))))
    ;; Result is a pair, pretty-printed as something with "#<atms" and "#<assumption-id"
    (check-true (string-contains? (car result) "#<atms")
                "result contains ATMS store")))

;; ========================================
;; Parser arity errors (sexp mode)
;; ========================================

(test-case "surface: atms-new arity error"
  (let ([result (run "(eval (atms-new))")])
    (check-true (and (list? result) (prologos-error? (car result)))
                "arity error for atms-new with 0 args")))

(test-case "surface: atms-assume arity error"
  (let ([result (run "(eval (atms-assume (atms-new (net-new 1000))))")])
    (check-true (and (list? result) (prologos-error? (car result)))
                "arity error for atms-assume with 1 arg")))

(test-case "surface: atms-write arity error"
  (let ([result (run "(eval (atms-write (atms-new (net-new 1000))))")])
    (check-true (and (list? result) (prologos-error? (car result)))
                "arity error for atms-write with 1 arg")))
