#lang racket/base

;;;
;;; Tests for syntax.rkt — Context operations, nat->expr, sugar
;;; Port of context/sugar tests from test-0a.maude
;;;

(require rackunit
         "../prelude.rkt"
         "../syntax.rkt")

;; ========================================
;; nat->expr convenience
;; ========================================

(test-case "nat->expr: 0 = zero"
  (check-equal? (nat->expr 0) (expr-zero)))
(test-case "nat->expr: 3 = suc(suc(suc(zero)))"
  (check-equal? (nat->expr 3) (expr-suc (expr-suc (expr-suc (expr-zero))))))
(test-case "nat->expr: 1 = suc(zero)"
  (check-equal? (nat->expr 1) (expr-suc (expr-zero))))

;; ========================================
;; Context operations
;; ========================================

(test-case "ctx-len: empty = 0"
  (check-equal? (ctx-len ctx-empty) 0))
(test-case "ctx-len: extend(empty, Nat, mw) = 1"
  (check-equal? (ctx-len (ctx-extend ctx-empty (expr-Nat) 'mw)) 1))
(test-case "ctx-len: extend(extend(empty, Nat, mw), Bool, m1) = 2"
  (check-equal? (ctx-len (ctx-extend (ctx-extend ctx-empty (expr-Nat) 'mw) (expr-Bool) 'm1)) 2))

(let* ([ctx1 (ctx-extend ctx-empty (expr-Nat) 'mw)]
       [ctx2 (ctx-extend ctx1 (expr-Bool) 'm1)])

  (test-case "lookup-type: position 0 in single context = Nat"
    (check-equal? (lookup-type 0 ctx1) (expr-Nat)))
  (test-case "lookup-type: position 0 in double context = Bool (most recent)"
    (check-equal? (lookup-type 0 ctx2) (expr-Bool)))
  (test-case "lookup-type: position 1 in double context = Nat"
    (check-equal? (lookup-type 1 ctx2) (expr-Nat)))

  (test-case "lookup-mult: position 0 in single context = mw"
    (check-equal? (lookup-mult 0 ctx1) 'mw))
  (test-case "lookup-mult: position 0 in double context = m1"
    (check-equal? (lookup-mult 0 ctx2) 'm1))
  (test-case "lookup-mult: position 1 in double context = mw"
    (check-equal? (lookup-mult 1 ctx2) 'mw)))

;; ========================================
;; Non-dependent type sugar
;; ========================================

(test-case "arrow: Nat --> Nat = Pi(mw, Nat, Nat)"
  (check-equal? (arrow (expr-Nat) (expr-Nat))
                (expr-Pi 'mw (expr-Nat) (expr-Nat))))
(test-case "sigma-pair: Nat ** Bool = Sigma(Nat, Bool)"
  (check-equal? (sigma-pair (expr-Nat) (expr-Bool))
                (expr-Sigma (expr-Nat) (expr-Bool))))

;; ========================================
;; Struct transparency (deep equality via #:transparent)
;; ========================================

(test-case "transparent structs: equal? works for nested expressions"
  (check-equal? (expr-app (expr-lam 'mw (expr-Nat) (expr-bvar 0)) (expr-zero))
                (expr-app (expr-lam 'mw (expr-Nat) (expr-bvar 0)) (expr-zero))))

(test-case "transparent structs: not equal for different expressions"
  (check-not-equal? (expr-bvar 0) (expr-bvar 1)))

;; ========================================
;; Expr predicate
;; ========================================

(test-case "expr? recognizes all constructors"
  (check-true (expr? (expr-bvar 0)))
  (check-true (expr? (expr-fvar 'x)))
  (check-true (expr? (expr-zero)))
  (check-true (expr? (expr-suc (expr-zero))))
  (check-true (expr? (expr-lam 'mw (expr-Nat) (expr-bvar 0))))
  (check-true (expr? (expr-app (expr-bvar 0) (expr-zero))))
  (check-true (expr? (expr-pair (expr-zero) (expr-true))))
  (check-true (expr? (expr-fst (expr-bvar 0))))
  (check-true (expr? (expr-snd (expr-bvar 0))))
  (check-true (expr? (expr-refl)))
  (check-true (expr? (expr-ann (expr-zero) (expr-Nat))))
  (check-true (expr? (expr-natrec (expr-bvar 0) (expr-zero) (expr-bvar 1) (expr-zero))))
  (check-true (expr? (expr-J (expr-bvar 0) (expr-bvar 1) (expr-zero) (expr-zero) (expr-refl))))
  (check-true (expr? (expr-Type (lzero))))
  (check-true (expr? (expr-Nat)))
  (check-true (expr? (expr-Bool)))
  (check-true (expr? (expr-true)))
  (check-true (expr? (expr-false)))
  (check-true (expr? (expr-Pi 'mw (expr-Nat) (expr-Nat))))
  (check-true (expr? (expr-Sigma (expr-Nat) (expr-Bool))))
  (check-true (expr? (expr-Eq (expr-Nat) (expr-zero) (expr-zero))))
  ;; Vec/Fin
  (check-true (expr? (expr-Vec (expr-Nat) (expr-zero))))
  (check-true (expr? (expr-vnil (expr-Nat))))
  (check-true (expr? (expr-vcons (expr-Nat) (expr-zero) (expr-zero) (expr-vnil (expr-Nat)))))
  (check-true (expr? (expr-Fin (expr-suc (expr-zero)))))
  (check-true (expr? (expr-fzero (expr-zero))))
  (check-true (expr? (expr-fsuc (expr-zero) (expr-fzero (expr-zero)))))
  (check-true (expr? (expr-vhead (expr-Nat) (expr-zero) (expr-bvar 0))))
  (check-true (expr? (expr-vtail (expr-Nat) (expr-zero) (expr-bvar 0))))
  (check-true (expr? (expr-vindex (expr-Nat) (expr-zero) (expr-fzero (expr-zero)) (expr-bvar 0))))
  ;; Error
  (check-true (expr? (expr-error))))

(test-case "expr? rejects non-expressions"
  (check-false (expr? 42))
  (check-false (expr? "hello"))
  (check-false (expr? #t)))

;; ========================================
;; Edge cases
;; ========================================

(test-case "lookup-type: out of bounds returns error"
  (check-equal? (lookup-type 5 ctx-empty) (expr-error)))

(test-case "ctx-extend: preserves existing bindings"
  (let* ([c1 (ctx-extend ctx-empty (expr-Nat) 'mw)]
         [c2 (ctx-extend c1 (expr-Bool) 'm1)]
         [c3 (ctx-extend c2 (expr-Type (lzero)) 'm0)])
    (check-equal? (ctx-len c3) 3)
    (check-equal? (lookup-type 0 c3) (expr-Type (lzero)))
    (check-equal? (lookup-type 1 c3) (expr-Bool))
    (check-equal? (lookup-type 2 c3) (expr-Nat))
    (check-equal? (lookup-mult 0 c3) 'm0)
    (check-equal? (lookup-mult 1 c3) 'm1)
    (check-equal? (lookup-mult 2 c3) 'mw)))
