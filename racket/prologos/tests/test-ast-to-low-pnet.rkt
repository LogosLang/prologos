#lang racket/base

;; test-ast-to-low-pnet.rkt — translator unit tests.

(require rackunit
         "../syntax.rkt"
         "../low-pnet-ir.rkt"
         "../ast-to-low-pnet.rkt")

(define (count-by lp pred)
  (for/sum ([n (in-list (low-pnet-nodes lp))] #:when (pred n)) 1))

(test-case "Int literal: 1 cell, 0 propagators, entry points at it"
  (define lp (ast-to-low-pnet (expr-Int) (expr-int 42) "test.prologos"))
  (check-true (validate-low-pnet lp))
  (check-equal? (count-by lp cell-decl?) 1)
  (check-equal? (count-by lp propagator-decl?) 0)
  (define entry (for/first ([n (in-list (low-pnet-nodes lp))]
                            #:when (entry-decl? n)) n))
  (check-equal? (entry-decl-main-cell-id entry) 0))

(test-case "[int+ 1 2]: 3 cells (1, 2, r) + 1 propagator + 2 deps"
  (define body (expr-int-add (expr-int 1) (expr-int 2)))
  (define lp (ast-to-low-pnet (expr-Int) body "test.prologos"))
  (check-true (validate-low-pnet lp))
  (check-equal? (count-by lp cell-decl?) 3)
  (check-equal? (count-by lp propagator-decl?) 1)
  (check-equal? (count-by lp dep-decl?) 2)
  (define p (for/first ([n (in-list (low-pnet-nodes lp))]
                        #:when (propagator-decl? n)) n))
  (check-equal? (propagator-decl-fire-fn-tag p) 'kernel-int-add)
  ;; Inputs are the two literal cells (in order); output is the third.
  (check-equal? (propagator-decl-input-cells p) (list 0 1))
  (check-equal? (propagator-decl-output-cells p) (list 2)))

(test-case "[int* 6 7]: kernel-int-mul propagator"
  (define body (expr-int-mul (expr-int 6) (expr-int 7)))
  (define lp (ast-to-low-pnet (expr-Int) body "test.prologos"))
  (define p (for/first ([n (in-list (low-pnet-nodes lp))]
                        #:when (propagator-decl? n)) n))
  (check-equal? (propagator-decl-fire-fn-tag p) 'kernel-int-mul))

(test-case "Nested [int+ [int* 2 3] 4]: 5 cells + 2 propagators"
  ;; cell 0 = 2, cell 1 = 3, cell 2 = m (mul result), cell 3 = 4, cell 4 = r
  (define body (expr-int-add (expr-int-mul (expr-int 2) (expr-int 3))
                             (expr-int 4)))
  (define lp (ast-to-low-pnet (expr-Int) body "test.prologos"))
  (check-true (validate-low-pnet lp))
  (check-equal? (count-by lp cell-decl?) 5)
  (check-equal? (count-by lp propagator-decl?) 2)
  (check-equal? (count-by lp dep-decl?) 4)
  ;; Outer entry-decl points at cell 4 (the outermost result)
  (define entry (for/first ([n (in-list (low-pnet-nodes lp))]
                            #:when (entry-decl? n)) n))
  (check-equal? (entry-decl-main-cell-id entry) 4))

(test-case "expr-true / expr-false → Bool cells"
  (define lp-true  (ast-to-low-pnet (expr-Bool) (expr-true)  "t.prologos"))
  (define lp-false (ast-to-low-pnet (expr-Bool) (expr-false) "t.prologos"))
  (check-true (validate-low-pnet lp-true))
  (check-true (validate-low-pnet lp-false))
  (define c-true (for/first ([n (in-list (low-pnet-nodes lp-true))]
                             #:when (cell-decl? n)) n))
  (define c-false (for/first ([n (in-list (low-pnet-nodes lp-false))]
                              #:when (cell-decl? n)) n))
  (check-equal? (cell-decl-init-value c-true) #t)
  (check-equal? (cell-decl-init-value c-false) #f))

(test-case "expr-ann strips wrapper"
  (define body (expr-ann (expr-int 7) (expr-Int)))
  (define lp (ast-to-low-pnet (expr-Int) body "t.prologos"))
  (check-true (validate-low-pnet lp))
  (define c (for/first ([n (in-list (low-pnet-nodes lp))]
                        #:when (cell-decl? n)) n))
  (check-equal? (cell-decl-init-value c) 7))

(test-case "unsupported node raises ast-translation-error"
  ;; expr-Pi is a type expression, not a value — translator should reject
  (check-exn ast-translation-error?
    (lambda ()
      (ast-to-low-pnet (expr-Int)
                       (expr-Pi 'mw (expr-Int) (expr-Int))
                       "t.prologos"))))

(test-case "non-Int/Bool main type raises"
  (check-exn ast-translation-error?
    (lambda ()
      (ast-to-low-pnet (expr-Type 0) (expr-int 0) "t.prologos"))))
