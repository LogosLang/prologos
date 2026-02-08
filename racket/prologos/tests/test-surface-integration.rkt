#lang racket/base

;;;
;;; Surface integration tests — full pipeline from surface syntax to results.
;;; Tests: parse -> elaborate -> type-check -> pretty-print
;;;

(require rackunit
         racket/string
         "../prelude.rkt"
         "../syntax.rkt"
         "../reduction.rkt"
         (prefix-in tc: "../typing-core.rkt")
         "../source-location.rkt"
         "../surface-syntax.rkt"
         "../parser.rkt"
         "../elaborator.rkt"
         "../pretty-print.rkt"
         "../errors.rkt"
         "../typing-errors.rkt"
         "../global-env.rkt"
         "../driver.rkt")

;; ========================================
;; Helper: process commands and return results list
;; ========================================
(define (run s)
  (parameterize ([current-global-env (hasheq)])
    (process-string s)))

(define (run-first s)
  (car (run s)))

;; ========================================
;; Basic type checking
;; ========================================

(test-case "surface: (check zero : Nat) -> OK"
  (check-equal? (run-first "(check zero : Nat)") "OK"))

(test-case "surface: (check (suc zero) : Nat) -> OK"
  (check-equal? (run-first "(check (suc zero) : Nat)") "OK"))

(test-case "surface: (check true : Bool) -> OK"
  (check-equal? (run-first "(check true : Bool)") "OK"))

(test-case "surface: (check refl : (Eq Nat zero zero)) -> OK"
  (check-equal? (run-first "(check refl : (Eq Nat zero zero))") "OK"))

;; ========================================
;; Type inference
;; ========================================

(test-case "surface: (infer zero) -> Nat"
  (check-equal? (run-first "(infer zero)") "Nat"))

(test-case "surface: (infer (suc zero)) -> Nat"
  (check-equal? (run-first "(infer (suc zero))") "Nat"))

(test-case "surface: (infer true) -> Bool"
  (check-equal? (run-first "(infer true)") "Bool"))

(test-case "surface: (infer Nat) -> (Type 0)"
  (check-equal? (run-first "(infer Nat)") "(Type 0)"))

;; ========================================
;; Evaluation
;; ========================================

(test-case "surface: (eval zero) -> zero : Nat"
  (check-equal? (run-first "(eval zero)") "zero : Nat"))

(test-case "surface: (eval (suc (suc zero))) -> 2 : Nat"
  (check-equal? (run-first "(eval (suc (suc zero)))") "2 : Nat"))

;; ========================================
;; Definitions
;; ========================================

(test-case "surface: define identity function"
  (parameterize ([current-global-env (hasheq)])
    (define results (process-string
                     "(def myid : (-> Nat Nat) (lam (x : Nat) x))"))
    (check-true (string-contains? (car results) "myid"))
    (check-true (string-contains? (car results) "defined"))))

(test-case "surface: define and use identity"
  (parameterize ([current-global-env (hasheq)])
    (define results (process-string
                     (string-append
                      "(def myid : (-> Nat Nat) (lam (x : Nat) x))\n"
                      "(eval (myid zero))")))
    (check-equal? (length results) 2)
    (check-true (string-contains? (car results) "defined"))
    (check-equal? (cadr results) "zero : Nat")))

(test-case "surface: define and check identity"
  (parameterize ([current-global-env (hasheq)])
    (define results (process-string
                     (string-append
                      "(def myid : (-> Nat Nat) (lam (x : Nat) x))\n"
                      "(check (myid (suc zero)) : Nat)")))
    (check-equal? (length results) 2)
    (check-equal? (cadr results) "OK")))

;; ========================================
;; Polymorphic identity
;; ========================================

(test-case "surface: polymorphic identity"
  (parameterize ([current-global-env (hasheq)])
    (define results (process-string
                     (string-append
                      "(def id : (Pi (A :0 (Type 0)) (-> A A))\n"
                      "  (lam (A :0 (Type 0)) (lam (x : A) x)))\n"
                      "(eval (id Nat zero))")))
    (check-equal? (length results) 2)
    (check-true (string-contains? (car results) "defined"))
    (check-equal? (cadr results) "zero : Nat")))

(test-case "surface: polymorphic identity applied to Bool"
  (parameterize ([current-global-env (hasheq)])
    (define results (process-string
                     (string-append
                      "(def id : (Pi (A :0 (Type 0)) (-> A A))\n"
                      "  (lam (A :0 (Type 0)) (lam (x : A) x)))\n"
                      "(eval (id Bool true))")))
    (check-equal? (cadr results) "true : Bool")))

;; ========================================
;; Type annotations
;; ========================================

(test-case "surface: annotated lambda"
  (check-equal?
   (run-first "(check (the (-> Nat Nat) (lam (x : Nat) (suc x))) : (-> Nat Nat))")
   "OK"))

;; ========================================
;; Negative tests (type errors)
;; ========================================

(test-case "surface: NEGATIVE — check true : Nat"
  (check-true (prologos-error? (run-first "(check true : Nat)"))))

(test-case "surface: NEGATIVE — unbound variable"
  (check-true (prologos-error? (run-first "(eval undefined_var)"))))

;; ========================================
;; Pairs and Sigma
;; ========================================

(test-case "surface: check pair against Sigma"
  (parameterize ([current-global-env (hasheq)])
    (check-equal?
     (run-first "(check (pair zero refl) : (Sigma (x : Nat) (Eq Nat x zero)))")
     "OK")))

;; ========================================
;; Vec operations
;; ========================================

(test-case "surface: check vnil"
  (check-equal?
   (run-first "(check (vnil Nat) : (Vec Nat zero))")
   "OK"))

(test-case "surface: check vcons"
  (check-equal?
   (run-first
    "(check (vcons Nat zero (suc zero) (vnil Nat)) : (Vec Nat (suc zero)))")
   "OK"))

;; ========================================
;; Multiple definitions building on each other
;; ========================================

(test-case "surface: chained definitions"
  (parameterize ([current-global-env (hasheq)])
    (define results (process-string
                     (string-append
                      "(def one : Nat (suc zero))\n"
                      "(def two : Nat (suc one))\n"
                      "(eval two)")))
    (check-equal? (length results) 3)
    (check-equal? (caddr results) "2 : Nat")))
