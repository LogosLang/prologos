#lang racket/base

;;;
;;; Tests for parser.rkt and surface-syntax.rkt
;;;

(require rackunit
         "../source-location.rkt"
         "../surface-syntax.rkt"
         "../parser.rkt"
         "../errors.rkt")

;; Helper: parse from string, ignoring source locations in comparisons
(define (p s) (parse-string s))

;; ========================================
;; Bare symbols
;; ========================================

(test-case "parse: Nat"
  (check-true (surf-nat-type? (p "Nat"))))

(test-case "parse: Bool"
  (check-true (surf-bool-type? (p "Bool"))))

(test-case "parse: zero"
  (check-true (surf-zero? (p "zero"))))

(test-case "parse: true"
  (check-true (surf-true? (p "true"))))

(test-case "parse: false"
  (check-true (surf-false? (p "false"))))

(test-case "parse: refl"
  (check-true (surf-refl? (p "refl"))))

(test-case "parse: variable"
  (let ([r (p "x")])
    (check-true (surf-var? r))
    (check-equal? (surf-var-name r) 'x)))

;; ========================================
;; Number literals
;; ========================================

(test-case "parse: 0 -> surf-zero"
  (check-true (surf-zero? (p "0"))))

(test-case "parse: 3 -> surf-nat-lit"
  (let ([r (p "3")])
    (check-true (surf-nat-lit? r))
    (check-equal? (surf-nat-lit-value r) 3)))

;; ========================================
;; suc
;; ========================================

(test-case "parse: (suc zero)"
  (let ([r (p "(suc zero)")])
    (check-true (surf-suc? r))
    (check-true (surf-zero? (surf-suc-pred r)))))

(test-case "parse: (suc (suc zero))"
  (let ([r (p "(suc (suc zero))")])
    (check-true (surf-suc? r))
    (check-true (surf-suc? (surf-suc-pred r)))))

;; ========================================
;; Lambda
;; ========================================

(test-case "parse: (lam (x : Nat) x)"
  (let ([r (p "(lam (x : Nat) x)")])
    (check-true (surf-lam? r))
    (let ([b (surf-lam-binder r)])
      (check-equal? (binder-info-name b) 'x)
      (check-equal? (binder-info-mult b) 'mw)
      (check-true (surf-nat-type? (binder-info-type b))))
    (check-true (surf-var? (surf-lam-body r)))))

(test-case "parse: (lam (x :1 Nat) x) — linear lambda"
  (let ([r (p "(lam (x :1 Nat) x)")])
    (check-true (surf-lam? r))
    (check-equal? (binder-info-mult (surf-lam-binder r)) 'm1)))

(test-case "parse: (lam (x :0 Nat) zero) — erased lambda"
  (let ([r (p "(lam (x :0 Nat) zero)")])
    (check-true (surf-lam? r))
    (check-equal? (binder-info-mult (surf-lam-binder r)) 'm0)))

;; ========================================
;; Pi
;; ========================================

(test-case "parse: (Pi (x : Nat) Nat)"
  (let ([r (p "(Pi (x : Nat) Nat)")])
    (check-true (surf-pi? r))
    (check-equal? (binder-info-name (surf-pi-binder r)) 'x)
    (check-true (surf-nat-type? (surf-pi-body r)))))

(test-case "parse: (Pi (A :0 (Type 0)) (-> A A))"
  (let ([r (p "(Pi (A :0 (Type 0)) (-> A A))")])
    (check-true (surf-pi? r))
    (check-equal? (binder-info-mult (surf-pi-binder r)) 'm0)
    (check-true (surf-arrow? (surf-pi-body r)))))

;; ========================================
;; Arrow
;; ========================================

(test-case "parse: (-> Nat Nat)"
  (let ([r (p "(-> Nat Nat)")])
    (check-true (surf-arrow? r))
    (check-true (surf-nat-type? (surf-arrow-domain r)))
    (check-true (surf-nat-type? (surf-arrow-codomain r)))))

;; ========================================
;; Sigma
;; ========================================

(test-case "parse: (Sigma (x : Nat) (Eq Nat x zero))"
  (let ([r (p "(Sigma (x : Nat) (Eq Nat x zero))")])
    (check-true (surf-sigma? r))
    (check-true (surf-eq? (surf-sigma-body r)))))

;; ========================================
;; Pair, fst, snd
;; ========================================

(test-case "parse: (pair zero refl)"
  (let ([r (p "(pair zero refl)")])
    (check-true (surf-pair? r))
    (check-true (surf-zero? (surf-pair-fst r)))
    (check-true (surf-refl? (surf-pair-snd r)))))

(test-case "parse: (fst x)"
  (let ([r (p "(fst x)")])
    (check-true (surf-fst? r))
    (check-true (surf-var? (surf-fst-expr r)))))

(test-case "parse: (snd x)"
  (let ([r (p "(snd x)")])
    (check-true (surf-snd? r))
    (check-true (surf-var? (surf-snd-expr r)))))

;; ========================================
;; the (annotation)
;; ========================================

(test-case "parse: (the Nat zero)"
  (let ([r (p "(the Nat zero)")])
    (check-true (surf-ann? r))
    (check-true (surf-nat-type? (surf-ann-type r)))
    (check-true (surf-zero? (surf-ann-term r)))))

;; ========================================
;; Eq
;; ========================================

(test-case "parse: (Eq Nat zero zero)"
  (let ([r (p "(Eq Nat zero zero)")])
    (check-true (surf-eq? r))
    (check-true (surf-nat-type? (surf-eq-type r)))
    (check-true (surf-zero? (surf-eq-lhs r)))
    (check-true (surf-zero? (surf-eq-rhs r)))))

;; ========================================
;; Type
;; ========================================

(test-case "parse: (Type 0)"
  (let ([r (p "(Type 0)")])
    (check-true (surf-type? r))
    (check-equal? (surf-type-level r) 0)))

(test-case "parse: (Type 1)"
  (let ([r (p "(Type 1)")])
    (check-equal? (surf-type-level r) 1)))

;; ========================================
;; natrec
;; ========================================

(test-case "parse: (natrec m b s t)"
  (let ([r (p "(natrec m b s t)")])
    (check-true (surf-natrec? r))
    (check-equal? (surf-var-name (surf-natrec-motive r)) 'm)
    (check-equal? (surf-var-name (surf-natrec-target r)) 't)))

;; ========================================
;; J
;; ========================================

(test-case "parse: (J m b l r p)"
  (let ([r (p "(J m b l r p)")])
    (check-true (surf-J? r))
    (check-equal? (surf-var-name (surf-J-motive r)) 'm)
    (check-equal? (surf-var-name (surf-J-proof r)) 'p)))

;; ========================================
;; Vec/Fin
;; ========================================

(test-case "parse: (Vec Nat (suc zero))"
  (let ([r (p "(Vec Nat (suc zero))")])
    (check-true (surf-vec-type? r))
    (check-true (surf-nat-type? (surf-vec-type-elem-type r)))
    (check-true (surf-suc? (surf-vec-type-length r)))))

(test-case "parse: (vnil Nat)"
  (check-true (surf-vnil? (p "(vnil Nat)"))))

(test-case "parse: (vcons Nat (suc zero) zero (vnil Nat))"
  (let ([r (p "(vcons Nat (suc zero) zero (vnil Nat))")])
    (check-true (surf-vcons? r))))

(test-case "parse: (Fin (suc zero))"
  (check-true (surf-fin-type? (p "(Fin (suc zero))"))))

(test-case "parse: (fzero zero)"
  (check-true (surf-fzero? (p "(fzero zero)"))))

(test-case "parse: (fsuc (suc zero) (fzero zero))"
  (check-true (surf-fsuc? (p "(fsuc (suc zero) (fzero zero))"))))

(test-case "parse: (vhead Nat zero v)"
  (check-true (surf-vhead? (p "(vhead Nat zero v)"))))

(test-case "parse: (vtail Nat zero v)"
  (check-true (surf-vtail? (p "(vtail Nat zero v)"))))

(test-case "parse: (vindex Nat (suc zero) i v)"
  (check-true (surf-vindex? (p "(vindex Nat (suc zero) i v)"))))

;; ========================================
;; Application
;; ========================================

(test-case "parse: (f x) — single arg"
  (let ([r (p "(f x)")])
    (check-true (surf-app? r))
    (check-equal? (surf-var-name (surf-app-func r)) 'f)
    (check-equal? (length (surf-app-args r)) 1)))

(test-case "parse: (f x y z) — multi-arg"
  (let ([r (p "(f x y z)")])
    (check-true (surf-app? r))
    (check-equal? (length (surf-app-args r)) 3)))

(test-case "parse: ((lam (x : Nat) x) zero) — compound function"
  (let ([r (p "((lam (x : Nat) x) zero)")])
    (check-true (surf-app? r))
    (check-true (surf-lam? (surf-app-func r)))))

;; ========================================
;; Top-level commands
;; ========================================

(test-case "parse: (def id : (-> Nat Nat) (lam (x : Nat) x))"
  (let ([r (p "(def id : (-> Nat Nat) (lam (x : Nat) x))")])
    (check-true (surf-def? r))
    (check-equal? (surf-def-name r) 'id)
    (check-true (surf-arrow? (surf-def-type r)))
    (check-true (surf-lam? (surf-def-body r)))))

(test-case "parse: (check zero : Nat)"
  (let ([r (p "(check zero : Nat)")])
    (check-true (surf-check? r))
    (check-true (surf-zero? (surf-check-expr r)))
    (check-true (surf-nat-type? (surf-check-type r)))))

(test-case "parse: (eval zero)"
  (let ([r (p "(eval zero)")])
    (check-true (surf-eval? r))
    (check-true (surf-zero? (surf-eval-expr r)))))

(test-case "parse: (infer zero)"
  (let ([r (p "(infer zero)")])
    (check-true (surf-infer? r))
    (check-true (surf-zero? (surf-infer-expr r)))))

;; ========================================
;; Error cases
;; ========================================

(test-case "parse: (suc) — wrong arity"
  (check-true (prologos-error? (p "(suc)"))))

(test-case "parse: (suc a b) — wrong arity"
  (check-true (prologos-error? (p "(suc a b)"))))

(test-case "parse: (Type x) — non-numeric level"
  (check-true (prologos-error? (p "(Type x)"))))

(test-case "parse: (lam x y) — bad binder"
  (check-true (prologos-error? (p "(lam x y)"))))

;; ========================================
;; parse-port: multiple forms
;; ========================================

(test-case "parse-port: multiple forms"
  (let* ([in (open-input-string "(def x : Nat zero)\n(eval x)")]
         [results (parse-port in "<test>")])
    (check-equal? (length results) 2)
    (check-true (surf-def? (car results)))
    (check-true (surf-eval? (cadr results)))))

;; ========================================
;; Source location tracking
;; ========================================

(test-case "parse: source locations from read-syntax"
  (let ([r (p "zero")])
    ;; Should have a srcloc from the string reader
    (check-true (srcloc? (surf-zero-srcloc r)))))
