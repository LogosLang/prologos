#lang racket/base

;;; test-generators.rkt — Prologos AST generators for property-based testing
;;; Phase E: Random type/term generation + self-validation.

(require rackunit
         rackcheck
         racket/match
         "../prelude.rkt"
         "../syntax.rkt"
         "../metavar-store.rkt"
         "../reduction.rkt"
         "../unify.rkt"
         "../global-env.rkt"
         (prefix-in tc: "../typing-core.rkt")
         "../performance-counters.rkt")

(provide gen:prologos-type
         gen:prologos-type-depth
         gen:prologos-term
         gen:well-typed-program
         with-fresh-tc-env)

;; ============================================================
;; Fresh environment for type-checking
;; ============================================================

(define-syntax-rule (with-fresh-tc-env body ...)
  (parameterize ([current-meta-store (make-hasheq)]
                 [current-constraint-store '()]
                 [current-wakeup-registry (make-hasheq)]
                 [current-global-env (hasheq)]
                 [current-reduction-fuel (box 50000)]
                 [current-level-meta-store (make-hasheq)])
    body ...))

;; ============================================================
;; Type generators
;; ============================================================

;; Generate a random Prologos type up to the given depth.
;; At depth 0: Nat, Bool, Unit
;; At depth > 0: also Pi, Sigma (with recursive sub-types)
(define (gen:prologos-type-depth depth)
  (if (zero? depth)
      ;; Base types only
      (gen:one-of (list (expr-Nat) (expr-Bool) (expr-Unit)))
      ;; Base + compound types
      (gen:frequency
       (list
        (cons 3 (gen:one-of (list (expr-Nat) (expr-Bool) (expr-Unit))))
        ;; Pi type: dom -> cod (non-dependent, uses bvar 0 to avoid capture)
        (cons 1 (gen:let ([dom (gen:prologos-type-depth (sub1 depth))]
                          [cod (gen:prologos-type-depth (sub1 depth))])
                  (expr-Pi 'mw dom cod)))
        ;; Sigma type: dom * cod
        (cons 1 (gen:let ([dom (gen:prologos-type-depth (sub1 depth))]
                          [cod (gen:prologos-type-depth (sub1 depth))])
                  (expr-Sigma dom cod)))))))

;; Default: types up to depth 2
(define gen:prologos-type (gen:prologos-type-depth 2))

;; ============================================================
;; Term generators (well-typed by construction)
;; ============================================================

;; Generate a term of a given type.
;; Produces well-typed terms by construction (not by filtering).
(define (gen:term-of-type type)
  (match type
    [(expr-Nat)
     (gen:let ([n (gen:integer-in 0 10)])
       (let loop ([n n])
         (if (zero? n) (expr-zero) (expr-suc (loop (sub1 n))))))]
    [(expr-Bool)
     (gen:one-of (list (expr-true) (expr-false)))]
    [(expr-Unit)
     (gen:const (expr-unit))]
    [(expr-Pi mult dom cod)
     ;; Generate a lambda that takes dom and returns a term of cod
     ;; The body uses bvar 0 (the lambda's parameter)
     (gen:let ([body (gen:term-of-type-simple cod)])
       (expr-lam 'mw dom body))]
    [(expr-Sigma dom cod)
     ;; Generate a pair: (fst of dom, snd of cod)
     (gen:let ([fst (gen:term-of-type-simple dom)]
               [snd (gen:term-of-type-simple cod)])
       (expr-pair fst snd))]
    [_ ;; Fallback: return zero for unknown types
     (gen:const (expr-zero))]))

;; Simplified term generator (no recursive depth explosion)
(define (gen:term-of-type-simple type)
  (match type
    [(expr-Nat)
     (gen:let ([n (gen:integer-in 0 5)])
       (let loop ([n n])
         (if (zero? n) (expr-zero) (expr-suc (loop (sub1 n))))))]
    [(expr-Bool) (gen:one-of (list (expr-true) (expr-false)))]
    [(expr-Unit) (gen:const (expr-unit))]
    [_ (gen:const (expr-zero))]))

;; Generate a (type, term) pair where term : type
(define gen:prologos-term
  (gen:let ([ty (gen:prologos-type-depth 1)])
    (gen:let ([tm (gen:term-of-type ty)])
      (cons ty tm))))

;; Generate a well-typed program: (term . type) pair
(define gen:well-typed-program
  (gen:let ([ty (gen:prologos-type-depth 1)])
    (gen:let ([tm (gen:term-of-type ty)])
      (cons tm ty))))

;; ============================================================
;; Generator self-validation tests
;; ============================================================

(test-case "gen: base types are valid types"
  (check-property
   (make-config #:tests 50)
   (property ([ty (gen:prologos-type-depth 0)])
     (with-fresh-tc-env
       (check-true (or (expr-Nat? ty) (expr-Bool? ty) (expr-Unit? ty)))))))

(test-case "gen: compound types up to depth 2"
  (check-property
   (make-config #:tests 50)
   (property ([ty gen:prologos-type])
     ;; Should be one of the known type constructors
     (check-true (or (expr-Nat? ty) (expr-Bool? ty) (expr-Unit? ty)
                     (expr-Pi? ty) (expr-Sigma? ty))))))

(test-case "gen: Nat terms type-check"
  (check-property
   (make-config #:tests 30)
   (property ([n (gen:integer-in 0 8)])
     (with-fresh-tc-env
       (define term
         (let loop ([n n])
           (if (zero? n) (expr-zero) (expr-suc (loop (sub1 n))))))
       (define inferred (tc:infer ctx-empty term))
       (check-true (expr-Nat? inferred)
                   (format "Expected Nat, got ~a for ~a" inferred term))))))

(test-case "gen: Bool terms type-check"
  (check-property
   (make-config #:tests 20)
   (property ([b gen:boolean])
     (with-fresh-tc-env
       (define term (if b (expr-true) (expr-false)))
       (define inferred (tc:infer ctx-empty term))
       (check-true (expr-Bool? inferred))))))

(test-case "gen: well-typed programs pass type-check"
  (check-property
   (make-config #:tests 30)
   (property ([prog gen:well-typed-program])
     (with-fresh-tc-env
       (define term (car prog))
       (define type (cdr prog))
       ;; Should type-check without error
       (define result (tc:check ctx-empty term type))
       (check-true result
                   (format "Failed: ~a should check against ~a" term type))))))
