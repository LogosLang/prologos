#lang racket/base

;;;
;;; Tests for spec ordering — defn-before-spec forward references.
;;;
;;; Phase 5 of the literate book system enables free ordering of spec
;;; and defn within a module. A defn can appear before its matching spec,
;;; and the spec pre-scan in preparse-expand-all will still inject the
;;; type annotation.
;;;

(require rackunit
         racket/string
         racket/list
         "../prelude.rkt"
         "../syntax.rkt"
         "../surface-syntax.rkt"
         "../parser.rkt"
         "../elaborator.rkt"
         "../pretty-print.rkt"
         "../errors.rkt"
         "../typing-errors.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../macros.rkt"
         "../source-location.rkt")

;; ========================================
;; Helper
;; ========================================
(define (run s)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-spec-store (hasheq)]
                 [current-preparse-registry (current-preparse-registry)])
    (process-string s)))

(define (run-first s)
  (car (run s)))

;; Helper: define add from scratch using natrec (no prelude dependency)
(define add-defn
  (string-append
   "(spec add Nat Nat -> Nat)\n"
   "(defn add [x y] (natrec Nat x (fn (k : Nat) (fn (r : Nat) (suc r))) y))\n"))

;; ========================================
;; 1. Spec-before-defn (baseline, existing behavior)
;; ========================================

(test-case "ordering: spec before defn (baseline)"
  (define results
    (run (string-append
          "(spec double Nat -> Nat)\n"
          "(defn double [x] (suc (suc x)))\n"
          "(eval (double (suc (suc zero))))")))
  (check-equal? (length results) 2)
  (check-equal? (cadr results) "4N : Nat"))

(test-case "ordering: spec before defn with two params (baseline)"
  (define results
    (run (string-append
          add-defn
          "(spec my-add Nat Nat -> Nat)\n"
          "(defn my-add [x y] (add x y))\n"
          "(eval (my-add (suc zero) (suc (suc zero))))")))
  (check-equal? (length results) 3)
  (check-equal? (caddr results) "3N : Nat"))

;; ========================================
;; 2. Defn-before-spec (new: forward reference)
;; ========================================

(test-case "ordering: defn before spec — simple Nat -> Nat"
  (define results
    (run (string-append
          "(defn inc2 [x] (suc (suc x)))\n"
          "(spec inc2 Nat -> Nat)\n"
          "(eval (inc2 (suc (suc zero))))")))
  (check-equal? (length results) 2)
  (check-equal? (cadr results) "4N : Nat"))

(test-case "ordering: defn before spec — two params"
  (define results
    (run (string-append
          "(defn my-add [x y] (natrec Nat x (fn (k : Nat) (fn (r : Nat) (suc r))) y))\n"
          "(spec my-add Nat Nat -> Nat)\n"
          "(eval (my-add (suc zero) (suc (suc zero))))")))
  (check-equal? (length results) 2)
  (check-equal? (cadr results) "3N : Nat"))

(test-case "ordering: defn before spec — Bool result"
  (define results
    (run (string-append
          "(defn is-zero [n] (natrec Bool true (fn (_ : Nat) (fn (_ : Bool) false)) n))\n"
          "(spec is-zero Nat -> Bool)\n"
          "(eval (is-zero zero))")))
  (check-equal? (length results) 2)
  (check-equal? (cadr results) "true : Bool"))

;; ========================================
;; 3. Multiple defn-before-spec pairs
;; ========================================

(test-case "ordering: multiple defns before their specs"
  (define results
    (run (string-append
          "(defn inc1 [x] (suc x))\n"
          "(defn inc3 [x] (suc (suc (suc x))))\n"
          "(spec inc1 Nat -> Nat)\n"
          "(spec inc3 Nat -> Nat)\n"
          "(eval (inc1 (suc zero)))\n"
          "(eval (inc3 zero))")))
  (check-equal? (length results) 4)
  (check-equal? (caddr results) "2N : Nat")
  (check-equal? (cadddr results) "3N : Nat"))

;; ========================================
;; 4. Mixed ordering (some before, some after)
;; ========================================

(test-case "ordering: mixed — some specs before, some after"
  (define results
    (run (string-append
          "(spec foo Nat -> Nat)\n"         ;; spec first
          "(defn foo [x] (suc x))\n"
          "(defn bar [x] (suc (suc x)))\n"  ;; defn first
          "(spec bar Nat -> Nat)\n"
          "(eval (foo zero))\n"
          "(eval (bar (suc (suc zero))))")))
  (check-equal? (length results) 4)
  (check-equal? (caddr results) "1N : Nat")
  (check-equal? (cadddr results) "4N : Nat"))

;; ========================================
;; 5. Defn-before-spec with docstring
;; ========================================

(test-case "ordering: defn before spec with docstring"
  (define results
    (run (string-append
          "(defn inc4 [x] (suc (suc (suc (suc x)))))\n"
          "(spec inc4 \"Adds four to a natural\" Nat -> Nat)\n"
          "(eval (inc4 (suc zero)))")))
  (check-equal? (length results) 2)
  (check-equal? (cadr results) "5N : Nat"))

;; ========================================
;; 6. Defn using result of another defn-before-spec
;; ========================================

(test-case "ordering: chained defns both before their specs"
  (define results
    (run (string-append
          "(defn inc2 [x] (suc (suc x)))\n"
          "(defn inc4 [x] (inc2 (inc2 x)))\n"
          "(spec inc2 Nat -> Nat)\n"
          "(spec inc4 Nat -> Nat)\n"
          "(eval (inc4 zero))")))
  (check-equal? (length results) 3)
  (check-equal? (caddr results) "4N : Nat"))

;; ========================================
;; 7. Spec-after-defn with higher-order type
;; ========================================

(test-case "ordering: defn before spec — higher-order function"
  (define results
    (run (string-append
          "(defn apply-twice [f x] (f (f x)))\n"
          "(spec apply-twice [Nat -> Nat] Nat -> Nat)\n"
          "(eval (apply-twice (fn (n : Nat) (suc n)) zero))")))
  (check-equal? (length results) 2)
  (check-equal? (cadr results) "2N : Nat"))
