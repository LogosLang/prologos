#lang racket/base

;;;
;;; Tests for Tabling surface syntax integration
;;; Phase 6e: parser -> elaborator -> type-check -> reduce -> pretty-print
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
  (parameterize ([current-global-env (hasheq)])
    (process-string s)))

;; ========================================
;; Type checking: type constructor (sexp mode)
;; ========================================

(test-case "surface: TableStore type check"
  (check-equal? (run "(check TableStore : (Type 0))")
                '("OK")))

;; ========================================
;; Type inference: operations (sexp mode)
;; ========================================

(test-case "surface: table-new type infer"
  (check-equal? (run "(infer (table-new (net-new 1000)))")
                '("TableStore")))

(test-case "surface: table-new check"
  (check-equal? (run "(check (table-new (net-new 1000)) : TableStore)")
                '("OK")))

(test-case "surface: table-register type infer"
  (let ([result (run "(infer (table-register (table-new (net-new 1000)) :p :all))")])
    (check-equal? result '("[Sigma TableStore CellId]"))))

(test-case "surface: table-run type infer"
  (check-equal? (run "(infer (table-run (table-new (net-new 1000))))")
                '("TableStore")))

;; ========================================
;; Evaluation: basic operations (sexp mode)
;; ========================================

(test-case "surface: eval table-new produces TableStore"
  (let ([result (run "(eval (table-new (net-new 1000)))")])
    (check-true (and (list? result) (= 1 (length result))))
    (check-true (string-contains? (car result) "#<table-store"))))

(test-case "surface: eval table-register returns pair"
  (let ([result (run "(eval (table-register (table-new (net-new 1000)) :p :all))")])
    (check-true (and (list? result) (= 1 (length result))))
    (check-true (string-contains? (car result) "#<table-store")
                "result contains TableStore")))

(test-case "surface: eval table-run"
  (let ([result (run "(eval (table-run (table-new (net-new 1000))))")])
    (check-true (and (list? result) (= 1 (length result))))
    (check-true (string-contains? (car result) "#<table-store"))))

;; ========================================
;; Parser arity errors (sexp mode)
;; ========================================

(test-case "surface: table-new arity error"
  (let ([result (run "(eval (table-new))")])
    (check-true (and (list? result) (prologos-error? (car result)))
                "arity error for table-new with 0 args")))

(test-case "surface: table-register arity error"
  (let ([result (run "(eval (table-register (table-new (net-new 1000))))")])
    (check-true (and (list? result) (prologos-error? (car result)))
                "arity error for table-register with 1 arg")))

(test-case "surface: table-add arity error"
  (let ([result (run "(eval (table-add (table-new (net-new 1000))))")])
    (check-true (and (list? result) (prologos-error? (car result)))
                "arity error for table-add with 1 arg")))

(test-case "surface: table-lookup arity error"
  (let ([result (run "(eval (table-lookup (table-new (net-new 1000))))")])
    (check-true (and (list? result) (prologos-error? (car result)))
                "arity error for table-lookup with 1 arg")))
