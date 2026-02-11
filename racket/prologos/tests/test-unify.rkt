#lang racket/base

;;;
;;; Tests for unification engine (Sprint 2)
;;;   - unify.rkt: core structural unification, meta solving, occur check
;;;   - Integration: replaces conv in typing-core.rkt and qtt.rkt
;;;

(require rackunit
         "../prelude.rkt"
         "../syntax.rkt"
         "../metavar-store.rkt"
         "../reduction.rkt"
         "../unify.rkt"
         "../global-env.rkt")

;; ========================================
;; Atom unification
;; ========================================

(test-case "unify: Nat ≡ Nat"
  (parameterize ([current-meta-store (make-hasheq)]
                 [current-global-env (hasheq)])
    (check-true (unify ctx-empty (expr-Nat) (expr-Nat)))))

(test-case "unify: Bool ≡ Bool"
  (parameterize ([current-meta-store (make-hasheq)]
                 [current-global-env (hasheq)])
    (check-true (unify ctx-empty (expr-Bool) (expr-Bool)))))

(test-case "unify: Nat ≢ Bool"
  (parameterize ([current-meta-store (make-hasheq)]
                 [current-global-env (hasheq)])
    (check-false (unify ctx-empty (expr-Nat) (expr-Bool)))))

(test-case "unify: zero ≡ zero"
  (parameterize ([current-meta-store (make-hasheq)]
                 [current-global-env (hasheq)])
    (check-true (unify ctx-empty (expr-zero) (expr-zero)))))

(test-case "unify: true ≢ false"
  (parameterize ([current-meta-store (make-hasheq)]
                 [current-global-env (hasheq)])
    (check-false (unify ctx-empty (expr-true) (expr-false)))))

(test-case "unify: Type(0) ≡ Type(0)"
  (parameterize ([current-meta-store (make-hasheq)]
                 [current-global-env (hasheq)])
    (check-true (unify ctx-empty (expr-Type (lzero)) (expr-Type (lzero))))))

(test-case "unify: Type(0) ≢ Type(1)"
  (parameterize ([current-meta-store (make-hasheq)]
                 [current-global-env (hasheq)])
    (check-false (unify ctx-empty
                        (expr-Type (lzero))
                        (expr-Type (lsuc (lzero)))))))

;; ========================================
;; Bare metavariable solving
;; ========================================

(test-case "unify: ?m ≡ Nat solves ?m := Nat"
  (parameterize ([current-meta-store (make-hasheq)]
                 [current-global-env (hasheq)])
    (define m (fresh-meta ctx-empty (expr-Type (lzero)) "test"))
    (check-true (unify ctx-empty m (expr-Nat)))
    (check-true (meta-solved? (expr-meta-id m)))
    (check-equal? (meta-solution (expr-meta-id m)) (expr-Nat))))

(test-case "unify: Nat ≡ ?m solves ?m := Nat (symmetric)"
  (parameterize ([current-meta-store (make-hasheq)]
                 [current-global-env (hasheq)])
    (define m (fresh-meta ctx-empty (expr-Type (lzero)) "test"))
    (check-true (unify ctx-empty (expr-Nat) m))
    (check-true (meta-solved? (expr-meta-id m)))
    (check-equal? (meta-solution (expr-meta-id m)) (expr-Nat))))

(test-case "unify: ?m1 ≡ ?m2 solves ?m1 := ?m2"
  (parameterize ([current-meta-store (make-hasheq)]
                 [current-global-env (hasheq)])
    (define m1 (fresh-meta ctx-empty (expr-Type (lzero)) "a"))
    (define m2 (fresh-meta ctx-empty (expr-Type (lzero)) "b"))
    (check-true (unify ctx-empty m1 m2))
    ;; One of them should be solved
    (check-true (meta-solved? (expr-meta-id m1)))))

(test-case "unify: already-solved meta, consistent"
  (parameterize ([current-meta-store (make-hasheq)]
                 [current-global-env (hasheq)])
    (define m (fresh-meta ctx-empty (expr-Type (lzero)) "test"))
    (solve-meta! (expr-meta-id m) (expr-Nat))
    (check-true (unify ctx-empty m (expr-Nat)))))

(test-case "unify: already-solved meta, conflicting"
  (parameterize ([current-meta-store (make-hasheq)]
                 [current-global-env (hasheq)])
    (define m (fresh-meta ctx-empty (expr-Type (lzero)) "test"))
    (solve-meta! (expr-meta-id m) (expr-Nat))
    (check-false (unify ctx-empty m (expr-Bool)))))

;; ========================================
;; Structural decomposition
;; ========================================

(test-case "unify: Pi(mw, ?m1, ?m2) ≡ Pi(mw, Nat, Bool) solves both"
  (parameterize ([current-meta-store (make-hasheq)]
                 [current-global-env (hasheq)])
    (define m1 (fresh-meta ctx-empty (expr-Type (lzero)) "dom"))
    (define m2 (fresh-meta ctx-empty (expr-Type (lzero)) "cod"))
    (check-true (unify ctx-empty
                       (expr-Pi 'mw m1 m2)
                       (expr-Pi 'mw (expr-Nat) (expr-Bool))))
    (check-equal? (meta-solution (expr-meta-id m1)) (expr-Nat))
    (check-equal? (meta-solution (expr-meta-id m2)) (expr-Bool))))

(test-case "unify: Sigma(?m1, ?m2) ≡ Sigma(Nat, Bool) solves both"
  (parameterize ([current-meta-store (make-hasheq)]
                 [current-global-env (hasheq)])
    (define m1 (fresh-meta ctx-empty (expr-Type (lzero)) "a"))
    (define m2 (fresh-meta ctx-empty (expr-Type (lzero)) "b"))
    (check-true (unify ctx-empty
                       (expr-Sigma m1 m2)
                       (expr-Sigma (expr-Nat) (expr-Bool))))
    (check-equal? (meta-solution (expr-meta-id m1)) (expr-Nat))
    (check-equal? (meta-solution (expr-meta-id m2)) (expr-Bool))))

(test-case "unify: suc(?m) ≡ suc(zero) solves ?m := zero"
  (parameterize ([current-meta-store (make-hasheq)]
                 [current-global-env (hasheq)])
    (define m (fresh-meta ctx-empty (expr-Nat) "test"))
    (check-true (unify ctx-empty
                       (expr-suc m)
                       (expr-suc (expr-zero))))
    (check-equal? (meta-solution (expr-meta-id m)) (expr-zero))))

(test-case "unify: nested suc(?m) ≡ suc(suc(suc(zero)))"
  (parameterize ([current-meta-store (make-hasheq)]
                 [current-global-env (hasheq)])
    (define m (fresh-meta ctx-empty (expr-Nat) "test"))
    (check-true (unify ctx-empty
                       (expr-suc (expr-suc m))
                       (expr-suc (expr-suc (expr-suc (expr-zero))))))
    (check-equal? (meta-solution (expr-meta-id m)) (expr-suc (expr-zero)))))

(test-case "unify: Vec(?m1, ?m2) ≡ Vec(Nat, suc(zero)) solves both"
  (parameterize ([current-meta-store (make-hasheq)]
                 [current-global-env (hasheq)])
    (define m1 (fresh-meta ctx-empty (expr-Type (lzero)) "elem"))
    (define m2 (fresh-meta ctx-empty (expr-Nat) "len"))
    (check-true (unify ctx-empty
                       (expr-Vec m1 m2)
                       (expr-Vec (expr-Nat) (expr-suc (expr-zero)))))
    (check-equal? (meta-solution (expr-meta-id m1)) (expr-Nat))
    (check-equal? (meta-solution (expr-meta-id m2)) (expr-suc (expr-zero)))))

(test-case "unify: Fin(?m) ≡ Fin(suc(zero)) solves"
  (parameterize ([current-meta-store (make-hasheq)]
                 [current-global-env (hasheq)])
    (define m (fresh-meta ctx-empty (expr-Nat) "bound"))
    (check-true (unify ctx-empty
                       (expr-Fin m)
                       (expr-Fin (expr-suc (expr-zero)))))
    (check-equal? (meta-solution (expr-meta-id m)) (expr-suc (expr-zero)))))

(test-case "unify: Eq(?m1, ?m2, ?m3) ≡ Eq(Nat, zero, suc(zero)) solves all"
  (parameterize ([current-meta-store (make-hasheq)]
                 [current-global-env (hasheq)])
    (define m1 (fresh-meta ctx-empty (expr-Type (lzero)) "ty"))
    (define m2 (fresh-meta ctx-empty (expr-Nat) "lhs"))
    (define m3 (fresh-meta ctx-empty (expr-Nat) "rhs"))
    (check-true (unify ctx-empty
                       (expr-Eq m1 m2 m3)
                       (expr-Eq (expr-Nat) (expr-zero) (expr-suc (expr-zero)))))
    (check-equal? (meta-solution (expr-meta-id m1)) (expr-Nat))
    (check-equal? (meta-solution (expr-meta-id m2)) (expr-zero))
    (check-equal? (meta-solution (expr-meta-id m3)) (expr-suc (expr-zero)))))

(test-case "unify: app(?m1, ?m2) ≡ app(fvar(f), fvar(x)) solves both"
  (parameterize ([current-meta-store (make-hasheq)]
                 [current-global-env (hasheq)])
    (define m1 (fresh-meta ctx-empty (expr-Type (lzero)) "func"))
    (define m2 (fresh-meta ctx-empty (expr-Type (lzero)) "arg"))
    (check-true (unify ctx-empty
                       (expr-app m1 m2)
                       (expr-app (expr-fvar 'f) (expr-fvar 'x))))
    (check-equal? (meta-solution (expr-meta-id m1)) (expr-fvar 'f))
    (check-equal? (meta-solution (expr-meta-id m2)) (expr-fvar 'x))))

;; ========================================
;; Occur check
;; ========================================

(test-case "occurs?: meta found directly"
  (define id (gensym 'test))
  (check-true (occurs? id (expr-meta id))))

(test-case "occurs?: meta not in atom"
  (define id (gensym 'test))
  (check-false (occurs? id (expr-Nat))))

(test-case "occurs?: meta in Pi domain"
  (define id (gensym 'test))
  (check-true (occurs? id (expr-Pi 'mw (expr-meta id) (expr-Nat)))))

(test-case "occurs?: meta in Pi codomain"
  (define id (gensym 'test))
  (check-true (occurs? id (expr-Pi 'mw (expr-Nat) (expr-meta id)))))

(test-case "unify: occur check prevents infinite type"
  (parameterize ([current-meta-store (make-hasheq)]
                 [current-global-env (hasheq)])
    (define m (fresh-meta ctx-empty (expr-Type (lzero)) "test"))
    (check-false (unify ctx-empty m (expr-Pi 'mw m (expr-Nat))))))

(test-case "occurs?: follows solved metas"
  (parameterize ([current-meta-store (make-hasheq)])
    (define m1 (fresh-meta ctx-empty (expr-Nat) "first"))
    (define m2 (fresh-meta ctx-empty (expr-Nat) "second"))
    (define id1 (expr-meta-id m1))
    (define id2 (expr-meta-id m2))
    ;; m2 is solved to m1
    (solve-meta! id2 m1)
    ;; Checking if m1's id occurs in m2 should follow the solution
    (check-true (occurs? id1 m2))))

;; ========================================
;; expr-hole wildcard
;; ========================================

(test-case "unify: hole ≡ Nat"
  (parameterize ([current-meta-store (make-hasheq)]
                 [current-global-env (hasheq)])
    (check-true (unify ctx-empty (expr-hole) (expr-Nat)))))

(test-case "unify: Nat ≡ hole"
  (parameterize ([current-meta-store (make-hasheq)]
                 [current-global-env (hasheq)])
    (check-true (unify ctx-empty (expr-Nat) (expr-hole)))))

(test-case "unify: hole ≡ hole"
  (parameterize ([current-meta-store (make-hasheq)]
                 [current-global-env (hasheq)])
    (check-true (unify ctx-empty (expr-hole) (expr-hole)))))

;; ========================================
;; Head mismatch
;; ========================================

(test-case "unify: Pi ≢ Sigma (head mismatch)"
  (parameterize ([current-meta-store (make-hasheq)]
                 [current-global-env (hasheq)])
    (check-false (unify ctx-empty
                        (expr-Pi 'mw (expr-Nat) (expr-Nat))
                        (expr-Sigma (expr-Nat) (expr-Nat))))))

(test-case "unify: suc(zero) ≢ zero"
  (parameterize ([current-meta-store (make-hasheq)]
                 [current-global-env (hasheq)])
    (check-false (unify ctx-empty (expr-suc (expr-zero)) (expr-zero)))))

(test-case "unify: Pi multiplicity mismatch"
  (parameterize ([current-meta-store (make-hasheq)]
                 [current-global-env (hasheq)])
    (check-false (unify ctx-empty
                        (expr-Pi 'm0 (expr-Nat) (expr-Nat))
                        (expr-Pi 'mw (expr-Nat) (expr-Nat))))))

;; ========================================
;; Nested meta solving
;; ========================================

(test-case "unify: nested Pi with three metas"
  (parameterize ([current-meta-store (make-hasheq)]
                 [current-global-env (hasheq)])
    (define m1 (fresh-meta ctx-empty (expr-Type (lzero)) "a"))
    (define m2 (fresh-meta ctx-empty (expr-Type (lzero)) "b"))
    (define m3 (fresh-meta ctx-empty (expr-Type (lzero)) "c"))
    (check-true (unify ctx-empty
                       (expr-Pi 'mw m1 (expr-Pi 'mw m2 m3))
                       (expr-Pi 'mw (expr-Nat) (expr-Pi 'mw (expr-Bool) (expr-Nat)))))
    (check-equal? (meta-solution (expr-meta-id m1)) (expr-Nat))
    (check-equal? (meta-solution (expr-meta-id m2)) (expr-Bool))
    (check-equal? (meta-solution (expr-meta-id m3)) (expr-Nat))))

(test-case "unify: meta chain — whnf resolves solved meta"
  (parameterize ([current-meta-store (make-hasheq)]
                 [current-global-env (hasheq)])
    (define m1 (fresh-meta ctx-empty (expr-Type (lzero)) "first"))
    (define m2 (fresh-meta ctx-empty (expr-Type (lzero)) "second"))
    ;; Solve m1 to m2
    (solve-meta! (expr-meta-id m1) m2)
    ;; Now unify m1 with Nat — should follow m1→m2, then solve m2 := Nat
    (check-true (unify ctx-empty m1 (expr-Nat)))
    (check-true (meta-solved? (expr-meta-id m2)))
    (check-equal? (meta-solution (expr-meta-id m2)) (expr-Nat))))

;; ========================================
;; Conv fallback (atoms handled by conv-nf)
;; ========================================

(test-case "unify: bvar(0) ≡ bvar(0)"
  (parameterize ([current-meta-store (make-hasheq)]
                 [current-global-env (hasheq)])
    (check-true (unify ctx-empty (expr-bvar 0) (expr-bvar 0)))))

(test-case "unify: fvar(x) ≢ fvar(y)"
  (parameterize ([current-meta-store (make-hasheq)]
                 [current-global-env (hasheq)])
    (check-false (unify ctx-empty (expr-fvar 'x) (expr-fvar 'y)))))

;; ========================================
;; Same unsolved meta on both sides
;; ========================================

(test-case "unify: same unsolved meta"
  (parameterize ([current-meta-store (make-hasheq)]
                 [current-global-env (hasheq)])
    (define m (fresh-meta ctx-empty (expr-Type (lzero)) "test"))
    (check-true (unify ctx-empty m m))
    ;; Should NOT be solved (no information to solve with)
    (check-false (meta-solved? (expr-meta-id m)))))

;; ========================================
;; Sprint 2b: Pattern condition
;; ========================================

(test-case "pattern-check: distinct bvars passes"
  (check-true (pattern-check (list (expr-bvar 0) (expr-bvar 1)))))

(test-case "pattern-check: repeated bvars fails"
  (check-false (pattern-check (list (expr-bvar 0) (expr-bvar 0)))))

(test-case "pattern-check: non-bvar argument fails"
  (check-false (pattern-check (list (expr-bvar 0) (expr-zero)))))

(test-case "pattern-check: empty spine passes"
  (check-true (pattern-check '())))

(test-case "pattern-check: single bvar passes"
  (check-true (pattern-check (list (expr-bvar 2)))))

;; ========================================
;; Sprint 2b: decompose-meta-app
;; ========================================

(test-case "decompose-meta-app: bare meta"
  (parameterize ([current-meta-store (make-hasheq)])
    (define m (fresh-meta ctx-empty (expr-Nat) "test"))
    (define-values (id args) (decompose-meta-app m))
    (check-equal? id (expr-meta-id m))
    (check-equal? args '())))

(test-case "decompose-meta-app: applied meta"
  (parameterize ([current-meta-store (make-hasheq)])
    (define m (fresh-meta ctx-empty (expr-Nat) "test"))
    (define applied (expr-app m (expr-bvar 0)))
    (define-values (id args) (decompose-meta-app applied))
    (check-equal? id (expr-meta-id m))
    (check-equal? args (list (expr-bvar 0)))))

(test-case "decompose-meta-app: doubly applied meta"
  (parameterize ([current-meta-store (make-hasheq)])
    (define m (fresh-meta ctx-empty (expr-Nat) "test"))
    (define applied (expr-app (expr-app m (expr-bvar 1)) (expr-bvar 0)))
    (define-values (id args) (decompose-meta-app applied))
    (check-equal? id (expr-meta-id m))
    (check-equal? args (list (expr-bvar 1) (expr-bvar 0)))))

(test-case "decompose-meta-app: non-meta head returns #f"
  (define applied (expr-app (expr-fvar 'f) (expr-bvar 0)))
  (define-values (id args) (decompose-meta-app applied))
  (check-false id))

(test-case "decompose-meta-app: solved meta returns #f"
  (parameterize ([current-meta-store (make-hasheq)])
    (define m (fresh-meta ctx-empty (expr-Nat) "test"))
    (solve-meta! (expr-meta-id m) (expr-fvar 'f))
    (define applied (expr-app m (expr-bvar 0)))
    (define-values (id args) (decompose-meta-app applied))
    (check-false id)))

;; ========================================
;; Sprint 2b: Applied meta solving
;; ========================================

(test-case "unify: (app ?m (bvar 0)) ≡ Nat solves ?m"
  (parameterize ([current-meta-store (make-hasheq)]
                 [current-global-env (hasheq)])
    (define m (fresh-meta ctx-empty (expr-Type (lzero)) "test"))
    ;; (app ?m (bvar 0)) on the left, Nat on the right
    ;; Pattern check: args = (bvar 0) — distinct bvar, passes
    ;; Solution: ?m := lam(_, _, Nat)
    ;; (since Nat has no bvar 0 refs, shifting is a no-op)
    (define flex-term (expr-app m (expr-bvar 0)))
    (check-true (unify ctx-empty flex-term (expr-Nat)))
    (check-true (meta-solved? (expr-meta-id m)))
    ;; The solution should be a lambda that returns Nat
    (define sol (meta-solution (expr-meta-id m)))
    (check-true (expr-lam? sol))
    (check-equal? (expr-lam-body sol) (expr-Nat))))

(test-case "unify: applied meta with non-pattern args fails gracefully"
  (parameterize ([current-meta-store (make-hasheq)]
                 [current-global-env (hasheq)])
    (define m (fresh-meta ctx-empty (expr-Type (lzero)) "test"))
    ;; (app ?m zero) — zero is not a bvar, pattern check fails
    (define flex-term (expr-app m (expr-zero)))
    (check-false (unify ctx-empty flex-term (expr-Nat)))))

(test-case "unify: applied meta occur check"
  (parameterize ([current-meta-store (make-hasheq)]
                 [current-global-env (hasheq)])
    (define m (fresh-meta ctx-empty (expr-Type (lzero)) "test"))
    ;; (app ?m (bvar 0)) ≡ (Pi mw ?m Nat) — ?m occurs in rhs
    (define flex-term (expr-app m (expr-bvar 0)))
    (check-false (unify ctx-empty flex-term (expr-Pi 'mw m (expr-Nat))))))
