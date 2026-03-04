#lang racket/base

;;;
;;; test-unify-structural.rkt — P-U1a: Unit tests for classify-whnf-problem
;;;
;;; Tests the pure classifier that decomposes unification problems into
;;; tagged classifications without any side effects. Each test constructs
;;; AST terms directly and verifies the classification tag and structure.
;;;

(require rackunit
         "../prelude.rkt"
         "../syntax.rkt"
         "../unify.rkt")

;; ========================================
;; Suite 1: Trivial equality / wildcards
;; ========================================

(test-case "classify: equal atoms → ok"
  (check-equal? (classify-whnf-problem (expr-Nat) (expr-Nat)) '(ok)))

(test-case "classify: hole on left → ok"
  (check-equal? (classify-whnf-problem (expr-hole) (expr-Bool)) '(ok)))

(test-case "classify: hole on right → ok"
  (check-equal? (classify-whnf-problem (expr-Nat) (expr-hole)) '(ok)))

(test-case "classify: typed-hole → ok"
  (check-equal? (classify-whnf-problem (expr-typed-hole 'th1) (expr-Bool)) '(ok)))

(test-case "classify: same unsolved meta → ok"
  (check-equal? (classify-whnf-problem (expr-meta 'a) (expr-meta 'a)) '(ok)))

;; ========================================
;; Suite 2: Flex-rigid (meta solving)
;; ========================================

(test-case "classify: meta on left → flex-rigid"
  (define result (classify-whnf-problem (expr-meta 'm1) (expr-Nat)))
  (check-equal? (car result) 'flex-rigid)
  (check-equal? (cadr result) 'm1)
  (check-true (expr-Nat? (caddr result))))

(test-case "classify: meta on right → flex-rigid"
  (define result (classify-whnf-problem (expr-Bool) (expr-meta 'm2)))
  (check-equal? (car result) 'flex-rigid)
  (check-equal? (cadr result) 'm2)
  (check-true (expr-Bool? (caddr result))))

(test-case "classify: different metas → flex-rigid (left wins)"
  (define result (classify-whnf-problem (expr-meta 'a) (expr-meta 'b)))
  (check-equal? (car result) 'flex-rigid)
  (check-equal? (cadr result) 'a))

;; ========================================
;; Suite 3: Structural decomposition
;; ========================================

(test-case "classify: Pi vs Pi → pi tag"
  (define result
    (classify-whnf-problem
     (expr-Pi mw (expr-Nat) (expr-bvar 0))
     (expr-Pi mw (expr-Bool) (expr-bvar 0))))
  (check-equal? (car result) 'pi)
  ;; Fields: m1 m2 dom-a dom-b cod-a cod-b
  (check-true (expr-Nat? (list-ref result 3)))
  (check-true (expr-Bool? (list-ref result 4))))

(test-case "classify: Sigma vs Sigma → binder tag"
  (define result
    (classify-whnf-problem
     (expr-Sigma (expr-Nat) (expr-bvar 0))
     (expr-Sigma (expr-Bool) (expr-bvar 0))))
  (check-equal? (car result) 'binder)
  (check-true (expr-Nat? (cadr result)))
  (check-true (expr-Bool? (caddr result))))

(test-case "classify: suc vs suc → sub with pred goal"
  (define result
    (classify-whnf-problem
     (expr-suc (expr-zero))
     (expr-suc (expr-nat-val 1))))
  (check-equal? (car result) 'sub)
  (check-equal? (length (cadr result)) 1)
  ;; Goal pair: zero vs nat-val(1)
  (check-true (expr-zero? (caar (cadr result))))
  (check-true (expr-nat-val? (cdar (cadr result)))))

(test-case "classify: app vs app → sub with func+arg goals"
  (define f1 (expr-fvar 'f))
  (define f2 (expr-fvar 'g))
  (define a1 (expr-Nat))
  (define a2 (expr-Bool))
  (define result
    (classify-whnf-problem (expr-app f1 a1) (expr-app f2 a2)))
  (check-equal? (car result) 'sub)
  (check-equal? (length (cadr result)) 2))

(test-case "classify: Eq vs Eq → sub with 3 goals"
  (define result
    (classify-whnf-problem
     (expr-Eq (expr-Nat) (expr-zero) (expr-zero))
     (expr-Eq (expr-Bool) (expr-true) (expr-false))))
  (check-equal? (car result) 'sub)
  (check-equal? (length (cadr result)) 3))

(test-case "classify: Vec vs Vec → sub with 2 goals"
  (define result
    (classify-whnf-problem
     (expr-Vec (expr-Nat) (expr-zero))
     (expr-Vec (expr-Bool) (expr-suc (expr-zero)))))
  (check-equal? (car result) 'sub)
  (check-equal? (length (cadr result)) 2))

(test-case "classify: pair vs pair → sub with 2 goals"
  (define result
    (classify-whnf-problem
     (expr-pair (expr-zero) (expr-true))
     (expr-pair (expr-suc (expr-zero)) (expr-false))))
  (check-equal? (car result) 'sub)
  (check-equal? (length (cadr result)) 2))

(test-case "classify: lam vs lam → binder tag"
  (define result
    (classify-whnf-problem
     (expr-lam mw (expr-Nat) (expr-bvar 0))
     (expr-lam mw (expr-Bool) (expr-bvar 0))))
  (check-equal? (car result) 'binder))

;; ========================================
;; Suite 4: Nat cross-representation
;; ========================================

(test-case "classify: nat-val(0) vs zero → ok"
  (check-equal? (classify-whnf-problem (expr-nat-val 0) (expr-zero)) '(ok)))

(test-case "classify: zero vs nat-val(0) → ok"
  (check-equal? (classify-whnf-problem (expr-zero) (expr-nat-val 0)) '(ok)))

(test-case "classify: nat-val(3) vs suc(X) → sub (decrement)"
  (define result (classify-whnf-problem (expr-nat-val 3) (expr-suc (expr-meta 'm))))
  (check-equal? (car result) 'sub)
  (check-equal? (expr-nat-val-n (caar (cadr result))) 2))

(test-case "classify: nat-val(0) vs suc(_) → conv (fail)"
  (check-equal? (classify-whnf-problem (expr-nat-val 0) (expr-suc (expr-zero))) '(conv)))

;; ========================================
;; Suite 5: Special cases
;; ========================================

(test-case "classify: Type vs Type → level"
  (define result
    (classify-whnf-problem (expr-Type (lzero)) (expr-Type (lsuc (lzero)))))
  (check-equal? (car result) 'level))

(test-case "classify: union vs union → union"
  (define result
    (classify-whnf-problem
     (expr-union (expr-Nat) (expr-Bool))
     (expr-union (expr-Bool) (expr-Nat))))
  (check-equal? (car result) 'union))

(test-case "classify: tycon same name → ok"
  (check-equal?
   (classify-whnf-problem (expr-tycon 'List) (expr-tycon 'List))
   '(ok)))

(test-case "classify: tycon different name → conv"
  (check-equal?
   (classify-whnf-problem (expr-tycon 'List) (expr-tycon 'Vec))
   '(conv)))

(test-case "classify: mismatch atoms → conv"
  (check-equal? (classify-whnf-problem (expr-Nat) (expr-Bool)) '(conv)))

(test-case "classify: ann stripped → retry"
  (define result
    (classify-whnf-problem (expr-ann (expr-zero) (expr-Nat)) (expr-zero)))
  (check-equal? (car result) 'retry)
  (check-true (expr-zero? (cadr result))))
