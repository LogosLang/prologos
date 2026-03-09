#lang racket/base

;;;
;;; Tests for UnionFind surface syntax integration (Part 1)
;;; Sections A-C: Type checking, basic ops, find returns Sigma
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

;; Helper to run with clean global env (sexp mode, no prelude)
(define (run s)
  (parameterize ([current-global-env (hasheq)])
    (process-string s)))

;; Helper to run with prelude (needed for nat-eq?, etc.)
(define (run-ns s)
  (parameterize ([current-global-env (hasheq)])
    (process-string (string-append "(ns test) " s))))

;; ========================================
;; Type checking: type constructor (sexp mode)
;; ========================================

(test-case "surface: UnionFind type check"
  (check-equal? (run "(check UnionFind : (Type 0))")
                '("OK")))

(test-case "surface: uf-empty type check"
  (check-equal? (run "(check (uf-empty) : UnionFind)")
                '("OK")))

;; ========================================
;; Eval: basic operations
;; ========================================

(test-case "surface: eval uf-empty"
  (let ([result (run "(eval (uf-empty))")])
    (check-equal? (length result) 1)
    (check-true (string-contains? (car result) "#<union-find")
                "uf-empty evals to union-find wrapper")))

(test-case "surface: eval uf-make-set"
  (let ([result (run "(eval (uf-make-set (uf-empty) 0N true))")])
    (check-equal? (length result) 1)
    (check-true (string-contains? (car result) "#<union-find")
                "uf-make-set evals to union-find wrapper")))

(test-case "surface: eval uf-value retrieves stored value"
  ;; uf-value is type-unsafe (returns hole), so result type is "_"
  (let ([result (run "(def s : UnionFind (uf-make-set (uf-empty) 0N true)) (eval (uf-value s 0N))")])
    (check-not-false (member "true : _" result)
                "uf-value retrieves the stored Bool (type is _ since uf-value is type-unsafe)")))

;; ========================================
;; Eval: find returns Sigma pair
;; ========================================

(test-case "surface: eval uf-find returns pair"
  (let ([result (run "(def s : UnionFind (uf-make-set (uf-empty) 0N true)) (eval (fst (uf-find s 0N)))")])
    (check-not-false (member "0N : Nat" result)
                "first of uf-find is the root id (0 for singleton)")))
