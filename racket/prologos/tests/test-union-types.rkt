#lang racket/base

;;;
;;; Tests for union types (Phase B.2)
;;;   - expr-union AST node: substitution, zonk, reduction, pretty-print
;;;   - Unification: ACI (associativity, commutativity, idempotence)
;;;   - Type checking: infer-level, is-type, check, infer
;;;   - Surface syntax: parsing, elaboration, full pipeline
;;;

(require rackunit
         racket/string
         "../prelude.rkt"
         "../syntax.rkt"
         "../substitution.rkt"
         "../reduction.rkt"
         "../zonk.rkt"
         "../unify.rkt"
         "../pretty-print.rkt"
         "../metavar-store.rkt"
         "../global-env.rkt"
         "../surface-syntax.rkt"
         "../parser.rkt"
         "../elaborator.rkt"
         "../errors.rkt"
         "../driver.rkt"
         "../macros.rkt"
         (prefix-in tc: "../typing-core.rkt"))

;; ========================================
;; Helper
;; ========================================
(define (run s)
  (parameterize ([current-global-env (hasheq)])
    (process-string s)))

(define (run-first s)
  (car (run s)))

;; ========================================
;; AST: substitution
;; ========================================

(test-case "union: shift passes through"
  (check-equal?
    (shift 1 0 (expr-union (expr-bvar 0) (expr-Nat)))
    (expr-union (expr-bvar 1) (expr-Nat))))

(test-case "union: subst passes through"
  (check-equal?
    (subst 0 (expr-zero) (expr-union (expr-bvar 0) (expr-Bool)))
    (expr-union (expr-zero) (expr-Bool))))

;; ========================================
;; AST: zonk
;; ========================================

(test-case "union: zonk passes through"
  (parameterize ([current-meta-store (make-hasheq)])
    (check-equal?
      (zonk (expr-union (expr-Nat) (expr-Bool)))
      (expr-union (expr-Nat) (expr-Bool)))))

(test-case "union: zonk resolves metas inside"
  (parameterize ([current-meta-store (make-hasheq)])
    (define id (gensym 'test))
    (hash-set! (current-meta-store) id
               (meta-info id ctx-empty (expr-hole) 'solved (expr-Nat) '() #f))
    (check-equal?
      (zonk (expr-union (expr-meta id) (expr-Bool)))
      (expr-union (expr-Nat) (expr-Bool)))))

;; ========================================
;; AST: reduction
;; ========================================

(test-case "union: whnf passes through"
  (parameterize ([current-global-env (hasheq)])
    (check-equal?
      (whnf (expr-union (expr-Nat) (expr-Bool)))
      (expr-union (expr-Nat) (expr-Bool)))))

(test-case "union: nf normalizes components"
  (parameterize ([current-global-env (hasheq)])
    (check-equal?
      (nf (expr-union (expr-Nat) (expr-Bool)))
      (expr-union (expr-Nat) (expr-Bool)))))

;; ========================================
;; AST: pretty-print
;; ========================================

(test-case "union: pretty-print"
  (check-equal?
    (pp-expr (expr-union (expr-Nat) (expr-Bool)) '())
    "Nat | Bool"))

(test-case "union: pretty-print nested"
  (check-equal?
    (pp-expr (expr-union (expr-Nat) (expr-union (expr-Bool) (expr-Unit))) '())
    "Nat | Bool | Unit"))

;; ========================================
;; Unification: union ≡ union
;; ========================================

(test-case "unify: Nat | Bool ≡ Nat | Bool"
  (parameterize ([current-meta-store (make-hasheq)]
                 [current-global-env (hasheq)])
    (check-true
      (unify-ok? (unify ctx-empty
                        (expr-union (expr-Nat) (expr-Bool))
                        (expr-union (expr-Nat) (expr-Bool)))))))

(test-case "unify: Nat | Bool ≡ Bool | Nat (commutativity)"
  (parameterize ([current-meta-store (make-hasheq)]
                 [current-global-env (hasheq)])
    (check-true
      (unify-ok? (unify ctx-empty
                        (expr-union (expr-Nat) (expr-Bool))
                        (expr-union (expr-Bool) (expr-Nat)))))))

(test-case "unify: (Nat | Bool) | Unit ≡ Nat | (Bool | Unit) (associativity)"
  (parameterize ([current-meta-store (make-hasheq)]
                 [current-global-env (hasheq)])
    (check-true
      (unify-ok? (unify ctx-empty
                        (expr-union (expr-union (expr-Nat) (expr-Bool)) (expr-Unit))
                        (expr-union (expr-Nat) (expr-union (expr-Bool) (expr-Unit))))))))

(test-case "unify: Nat | Bool ≢ Nat | Unit"
  (parameterize ([current-meta-store (make-hasheq)]
                 [current-global-env (hasheq)])
    (check-false
      (unify ctx-empty
             (expr-union (expr-Nat) (expr-Bool))
             (expr-union (expr-Nat) (expr-Unit))))))

(test-case "unify: Nat | Bool ≢ Nat (different cardinality)"
  (parameterize ([current-meta-store (make-hasheq)]
                 [current-global-env (hasheq)])
    (check-false
      (unify ctx-empty
             (expr-union (expr-Nat) (expr-Bool))
             (expr-Nat)))))

;; ========================================
;; Type formation: is-type and infer-level
;; ========================================

(test-case "is-type: Nat | Bool is a type"
  (check-true
    (tc:is-type ctx-empty (expr-union (expr-Nat) (expr-Bool)))))

(test-case "is-type: Nat | Bool | Unit is a type"
  (check-true
    (tc:is-type ctx-empty
                (expr-union (expr-Nat) (expr-union (expr-Bool) (expr-Unit))))))

(test-case "infer: Nat | Bool : Type(0)"
  (check-equal?
    (tc:infer ctx-empty (expr-union (expr-Nat) (expr-Bool)))
    (expr-Type (lzero))))

;; ========================================
;; Type checking: check against union
;; ========================================

(test-case "check: zero : Nat | Bool"
  (check-true
    (tc:check ctx-empty (expr-zero) (expr-union (expr-Nat) (expr-Bool)))))

(test-case "check: true : Nat | Bool"
  (check-true
    (tc:check ctx-empty (expr-true) (expr-union (expr-Nat) (expr-Bool)))))

(test-case "check: suc(zero) : Nat | Bool"
  (check-true
    (tc:check ctx-empty (expr-suc (expr-zero)) (expr-union (expr-Nat) (expr-Bool)))))

(test-case "check: false : Bool | Nat"
  (check-true
    (tc:check ctx-empty (expr-false) (expr-union (expr-Bool) (expr-Nat)))))

(test-case "check: unit : Unit | Nat"
  (check-true
    (tc:check ctx-empty (expr-unit) (expr-union (expr-Unit) (expr-Nat)))))

(test-case "check: unit does not check against Nat | Bool"
  (check-false
    (tc:check ctx-empty (expr-unit) (expr-union (expr-Nat) (expr-Bool)))))

(test-case "check: lambda checks against Pi | Nat (union with function type)"
  ;; fn [x : Nat] -> x  should check against (Nat -> Nat) | Bool
  (check-true
    (tc:check ctx-empty
              (expr-lam 'mw (expr-Nat) (expr-bvar 0))
              (expr-union (expr-Pi 'mw (expr-Nat) (expr-Nat)) (expr-Bool)))))

;; ========================================
;; Surface syntax: full pipeline tests
;; In sexp mode, | is only parsed inside <...> angle brackets
;; ========================================

(test-case "surface: (check zero : <Nat | Bool>)"
  (check-equal? (run-first "(check zero : <Nat | Bool>)") "OK"))

(test-case "surface: (check true : <Nat | Bool>)"
  (check-equal? (run-first "(check true : <Nat | Bool>)") "OK"))

(test-case "surface: (check (suc zero) : <Bool | Nat>)"
  (check-equal? (run-first "(check (suc zero) : <Bool | Nat>)") "OK"))

(test-case "surface: (check unit : <Unit | Nat | Bool>)"
  (check-equal? (run-first "(check unit : <Unit | Nat | Bool>)") "OK"))

(test-case "surface: (infer <Nat | Bool>)"
  ;; Nat | Bool should infer Type 0
  (check-equal? (run-first "(infer <Nat | Bool>)") "[Type 0]"))

(test-case "surface: union type is-type in def annotation"
  ;; def with union type annotation
  (check-equal?
    (run-first "(def x : <Nat | Bool> zero)")
    "x : Nat | Bool defined."))

;; ========================================
;; Flatten-union helper
;; ========================================

(test-case "flatten-union: flat"
  (check-equal?
    (flatten-union (expr-union (expr-Nat) (expr-Bool)))
    (list (expr-Nat) (expr-Bool))))

(test-case "flatten-union: nested left"
  (check-equal?
    (flatten-union (expr-union (expr-union (expr-Nat) (expr-Bool)) (expr-Unit)))
    (list (expr-Nat) (expr-Bool) (expr-Unit))))

(test-case "flatten-union: nested right"
  (check-equal?
    (flatten-union (expr-union (expr-Nat) (expr-union (expr-Bool) (expr-Unit))))
    (list (expr-Nat) (expr-Bool) (expr-Unit))))

(test-case "flatten-union: non-union"
  (check-equal?
    (flatten-union (expr-Nat))
    (list (expr-Nat))))
