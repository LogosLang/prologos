#lang racket/base

;;;
;;; test-solver-occurs.rkt — Occurs check + solver walk/unify edge cases
;;;
;;; Covers: solver-term-occurs? (via unify-terms), infinite term prevention,
;;; walk/walk* chains, compound unification, descriptor-based decomposition.
;;;
;;; Motivated by PUnify PIR §10.4: "No existing test exercises solver-term-occurs?"
;;; Phase 8 added occurs-check guards but no test creates infinite terms.
;;;
;;; Tests the PUBLIC hasheq-path API (walk, walk*, unify-terms from relations.rkt).
;;; The solver-env (cell-based) path is tested via integration in test-punify-integration.rkt.
;;;

(require rackunit
         "../relations.rkt")

;; ========================================
;; Suite 1: walk (hasheq path)
;; ========================================

(test-case "walk: unbound variable → returns variable"
  (check-eq? (walk (hasheq) 'x) 'x))

(test-case "walk: bound variable → returns value"
  (check-equal? (walk (hasheq 'x 42) 'x) 42))

(test-case "walk: chain — x → y → 42"
  (define subst (hasheq 'x 'y 'y 42))
  (check-equal? (walk subst 'x) 42))

(test-case "walk: ground atom → returns itself"
  (check-equal? (walk (hasheq) 42) 42)
  (check-equal? (walk (hasheq) "hello") "hello"))

(test-case "walk: deep chain — a → b → c → d → 99"
  (define subst (hasheq 'a 'b 'b 'c 'c 'd 'd 99))
  (check-equal? (walk subst 'a) 99))

;; ========================================
;; Suite 2: walk* (hasheq path)
;; ========================================

(test-case "walk*: resolves variable in nested list"
  (define subst (hasheq 'x 1 'y 2))
  (check-equal? (walk* subst '(cons x (cons y nil)))
                '(cons 1 (cons 2 nil))))

(test-case "walk*: nested variables with chains"
  (define subst (hasheq 'a 'b 'b 42))
  (check-equal? (walk* subst '(some a)) '(some 42)))

(test-case "walk*: ground list unchanged"
  (check-equal? (walk* (hasheq) '(cons 1 nil)) '(cons 1 nil)))

(test-case "walk*: atom unchanged"
  (check-equal? (walk* (hasheq) 'nil) 'nil))

;; ========================================
;; Suite 3: unify-terms basics (hasheq path)
;; ========================================

(test-case "unify-terms: ground equal → success"
  (define result (unify-terms 42 42 (hasheq)))
  (check-not-false result))

(test-case "unify-terms: ground unequal → #f"
  (check-false (unify-terms 42 99 (hasheq))))

(test-case "unify-terms: variable binds to ground"
  (define result (unify-terms 'x 42 (hasheq)))
  (check-not-false result)
  (check-equal? (walk result 'x) 42))

(test-case "unify-terms: ground binds to variable (symmetric)"
  (define result (unify-terms 42 'x (hasheq)))
  (check-not-false result)
  (check-equal? (walk result 'x) 42))

(test-case "unify-terms: variable = variable"
  (define result (unify-terms 'x 'y (hasheq)))
  (check-not-false result)
  ;; x bound to y (or y to x — either direction is valid)
  (define x-val (walk result 'x))
  (define y-val (walk result 'y))
  ;; After walking, at least one should resolve to the other
  (check-true (or (eq? x-val 'y) (eq? y-val 'x))))

;; ========================================
;; Suite 4: Compound unification
;; ========================================

(test-case "unify-terms: same-length lists — recursive"
  (define result (unify-terms '(cons x nil) '(cons 1 nil) (hasheq)))
  (check-not-false result)
  (check-equal? (walk result 'x) 1))

(test-case "unify-terms: nested compound"
  ;; (cons (some x) nil) ≡ (cons (some 42) nil) → x = 42
  (define result (unify-terms '(cons (some x) nil) '(cons (some 42) nil) (hasheq)))
  (check-not-false result)
  (check-equal? (walk result 'x) 42))

(test-case "unify-terms: different-length lists → #f"
  (check-false (unify-terms '(cons 1) '(cons 1 nil) (hasheq))))

(test-case "unify-terms: compound mismatch → #f"
  ;; (some 1) ≠ (some 2) — head matches but component differs
  (check-false (unify-terms '(some 1) '(some 2) (hasheq))))

(test-case "unify-terms: deep compound — pair of ok/err"
  (define result (unify-terms '(pair (ok a) (err b)) '(pair (ok 1) (err "x")) (hasheq)))
  (check-not-false result)
  (check-equal? (walk result 'a) 1)
  (check-equal? (walk result 'b) "x"))

(test-case "unify-terms: transitive — x bound, then constrained"
  ;; First: x = (some y), then y = 42
  (define s1 (unify-terms 'x '(some y) (hasheq)))
  (check-not-false s1)
  (define s2 (unify-terms 'y 42 s1))
  (check-not-false s2)
  ;; Walk x → (some y), walk* x → (some 42)
  (check-equal? (walk* s2 'x) '(some 42)))

;; ========================================
;; Suite 5: Occurs check — infinite term prevention
;; ========================================

(test-case "occurs: x = (cons x nil) → #f (direct cycle)"
  (check-false (unify-terms 'x '(cons x nil) (hasheq))))

(test-case "occurs: x = (some x) → #f (direct cycle)"
  (check-false (unify-terms 'x '(some x) (hasheq))))

(test-case "occurs: x = x → succeeds (not a cycle)"
  (define result (unify-terms 'x 'x (hasheq)))
  (check-not-false result))

(test-case "occurs: transitive cycle — x = (cons 1 y), y = (cons 2 x) → #f"
  (define s1 (unify-terms 'x '(cons 1 y) (hasheq)))
  (check-not-false s1)
  ;; Now y = (cons 2 x) — walking x through subst finds (cons 1 y),
  ;; walking y finds (cons 2 x) → x occurs in y's walked value
  (check-false (unify-terms 'y '(cons 2 x) s1)))

(test-case "occurs: variable in deeply nested term → #f"
  ;; x = (cons (some (pair x nil)) nil)
  (check-false (unify-terms 'x '(cons (some (pair x nil)) nil) (hasheq))))

(test-case "occurs: variable NOT in term → succeeds"
  ;; x = (cons y nil) — x doesn't occur, so this should succeed
  (define result (unify-terms 'x '(cons y nil) (hasheq)))
  (check-not-false result))

;; ========================================
;; Suite 6: Edge cases
;; ========================================

(test-case "unify-terms: empty list = empty list"
  (define result (unify-terms '() '() (hasheq)))
  (check-not-false result))

(test-case "unify-terms: nil atom = nil atom"
  (define result (unify-terms 'nil 'nil (hasheq)))
  (check-not-false result))

(test-case "unify-terms: multiple variables, shared constraints"
  ;; (cons x y) ≡ (cons y x) — x = y
  (define result (unify-terms '(cons x y) '(cons y x) (hasheq)))
  (check-not-false result)
  ;; After resolution, x and y should be equal
  (define x-val (walk* result 'x))
  (define y-val (walk* result 'y))
  (check-equal? x-val y-val))

(test-case "unify-terms: chain of three — x=y, y=z, z=42"
  (define s1 (unify-terms 'x 'y (hasheq)))
  (check-not-false s1)
  (define s2 (unify-terms 'y 'z s1))
  (check-not-false s2)
  (define s3 (unify-terms 'z 42 s2))
  (check-not-false s3)
  (check-equal? (walk* s3 'x) 42)
  (check-equal? (walk* s3 'y) 42)
  (check-equal? (walk* s3 'z) 42))
