#lang racket/base

;;;
;;; Tests for UnionFind type-level integration
;;; Phase 4c: type formation, infer, check, QTT, substitution, pretty-print
;;;

(require racket/string
         rackunit
         "../syntax.rkt"
         "../prelude.rkt"
         "../substitution.rkt"
         "../reduction.rkt"
         (prefix-in tc: "../typing-core.rkt")
         "../pretty-print.rkt"
         "../qtt.rkt"
         "../global-env.rkt"
         "../union-find.rkt")

;; ========================================
;; Type formation: UnionFind
;; ========================================

(test-case "UnionFind type formation"
  (check-equal? (tc:infer ctx-empty (expr-uf-type))
                (expr-Type (lzero))
                "UnionFind : Type 0")
  (check-true (tc:is-type ctx-empty (expr-uf-type))
              "UnionFind is a type"))

;; ========================================
;; Runtime wrapper
;; ========================================

(test-case "UnionFind runtime wrapper check"
  (check-true (tc:check ctx-empty (expr-uf-store (uf-empty)) (expr-uf-type))
              "uf-store checks against UnionFind type"))

(test-case "UnionFind runtime wrapper infer"
  (check-equal? (tc:infer ctx-empty (expr-uf-store (uf-empty)))
                (expr-uf-type)
                "uf-store infers as UnionFind"))

;; ========================================
;; Operation type inference
;; ========================================

(test-case "uf-empty infers as UnionFind"
  (check-equal? (tc:infer ctx-empty (expr-uf-empty))
                (expr-uf-type)))

(test-case "uf-make-set infers as UnionFind"
  (check-equal? (tc:infer ctx-empty
                  (expr-uf-make-set (expr-uf-empty)
                                    (expr-zero)
                                    (expr-true)))
                (expr-uf-type)))

(test-case "uf-find infers as [Nat * UnionFind]"
  (let ([store (expr-uf-store (uf-make-set (uf-empty) 0 (expr-true)))])
    (check-equal? (tc:infer ctx-empty
                    (expr-uf-find store (expr-zero)))
                  (expr-Sigma (expr-Nat) (expr-uf-type)))))

(test-case "uf-union infers as UnionFind"
  (let ([store (expr-uf-store
                (uf-make-set
                 (uf-make-set (uf-empty) 0 (expr-true))
                 1 (expr-false)))])
    (check-equal? (tc:infer ctx-empty
                    (expr-uf-union store (expr-zero) (expr-suc (expr-zero))))
                  (expr-uf-type))))

(test-case "uf-value infers as hole (type-unsafe)"
  (let ([store (expr-uf-store (uf-make-set (uf-empty) 0 (expr-true)))])
    (check-equal? (tc:infer ctx-empty
                    (expr-uf-value store (expr-zero)))
                  (expr-hole))))

;; ========================================
;; Type errors
;; ========================================

(test-case "uf-make-set rejects non-Nat id"
  (check-equal? (tc:infer ctx-empty
                  (expr-uf-make-set (expr-uf-empty) (expr-true) (expr-zero)))
                (expr-error)
                "id must be Nat, not Bool"))

(test-case "uf-find rejects non-UnionFind store"
  (check-equal? (tc:infer ctx-empty
                  (expr-uf-find (expr-true) (expr-zero)))
                (expr-error)
                "store must be UnionFind, not Bool"))

;; ========================================
;; QTT inferQ
;; ========================================

(test-case "QTT: uf-type has zero usage"
  (check-equal? (inferQ ctx-empty (expr-uf-type))
                (tu (expr-Type (lzero)) '())))

(test-case "QTT: uf-empty has zero usage"
  (check-equal? (inferQ ctx-empty (expr-uf-empty))
                (tu (expr-uf-type) '())))

(test-case "QTT: uf-store wrapper has zero usage"
  (check-equal? (inferQ ctx-empty (expr-uf-store (uf-empty)))
                (tu (expr-uf-type) '())))

;; ========================================
;; Substitution round-trip
;; ========================================

(test-case "shift on UnionFind type constructor"
  (check-equal? (shift 1 0 (expr-uf-type)) (expr-uf-type)))

(test-case "shift on uf-empty"
  (check-equal? (shift 1 0 (expr-uf-empty)) (expr-uf-empty)))

(test-case "shift on uf-make-set recurses into fields"
  (let ([e (expr-uf-make-set (expr-bvar 0) (expr-zero) (expr-true))])
    (check-equal? (shift 1 0 e)
                  (expr-uf-make-set (expr-bvar 1) (expr-zero) (expr-true)))))

(test-case "subst on uf-find recurses into fields"
  (let ([e (expr-uf-find (expr-bvar 0) (expr-zero))])
    (check-equal? (subst 0 (expr-uf-empty) e)
                  (expr-uf-find (expr-uf-empty) (expr-zero)))))

;; ========================================
;; Pretty-print
;; ========================================

(test-case "pp-expr: UnionFind type"
  (check-equal? (pp-expr (expr-uf-type) '()) "UnionFind"))

(test-case "pp-expr: uf-empty"
  (check-equal? (pp-expr (expr-uf-empty) '()) "[uf-empty]"))

(test-case "pp-expr: uf-make-set"
  (check-true (string-contains?
               (pp-expr (expr-uf-make-set (expr-uf-empty) (expr-zero) (expr-true)) '())
               "uf-make-set")))

(test-case "pp-expr: uf-find"
  (check-true (string-contains?
               (pp-expr (expr-uf-find (expr-uf-empty) (expr-zero)) '())
               "uf-find")))

(test-case "pp-expr: uf-union"
  (check-true (string-contains?
               (pp-expr (expr-uf-union (expr-uf-empty) (expr-zero) (expr-zero)) '())
               "uf-union")))

(test-case "pp-expr: uf-value"
  (check-true (string-contains?
               (pp-expr (expr-uf-value (expr-uf-empty) (expr-zero)) '())
               "uf-value")))

;; ========================================
;; Reduction (eval) tests
;; ========================================

(test-case "eval: uf-empty reduces to wrapped store"
  (let ([result (whnf (expr-uf-empty))])
    (check-true (expr-uf-store? result)
                "uf-empty reduces to uf-store wrapper")))

(test-case "eval: uf-make-set reduces to wrapped store"
  (let ([result (whnf (expr-uf-make-set (expr-uf-empty) (expr-zero) (expr-true)))])
    (check-true (expr-uf-store? result)
                "uf-make-set reduces to uf-store wrapper")))

(test-case "eval: uf-find returns Sigma pair"
  (let* ([store (whnf (expr-uf-make-set (expr-uf-empty) (expr-zero) (expr-true)))]
         [result (whnf (expr-uf-find store (expr-zero)))])
    (check-true (expr-pair? result) "uf-find returns a pair")
    ;; First element should be 0 (the root of a singleton set)
    (check-equal? (whnf (expr-fst result)) (expr-zero) "root of singleton is 0")
    ;; Second element should be a uf-store
    (check-true (expr-uf-store? (whnf (expr-snd result))) "updated store is uf-store")))

(test-case "eval: uf-value retrieves stored value"
  (let* ([store (whnf (expr-uf-make-set (expr-uf-empty) (expr-zero) (expr-true)))]
         [result (whnf (expr-uf-value store (expr-zero)))])
    (check-equal? result (expr-true) "uf-value retrieves the stored value")))

(test-case "eval: uf-union merges two sets"
  (let* ([s0 (whnf (expr-uf-empty))]
         [s1 (whnf (expr-uf-make-set s0 (expr-zero) (expr-true)))]
         [s2 (whnf (expr-uf-make-set s1 (expr-suc (expr-zero)) (expr-false)))]
         [s3 (whnf (expr-uf-union s2 (expr-zero) (expr-suc (expr-zero))))]
         ;; After union, both should have the same root
         [find0 (whnf (expr-uf-find s3 (expr-zero)))]
         [find1 (whnf (expr-uf-find s3 (expr-suc (expr-zero))))]
         [root0 (whnf (expr-fst find0))]
         [root1 (whnf (expr-fst find1))])
    (check-true (expr-uf-store? s3) "union returns uf-store")
    (check-equal? root0 root1 "after union, both ids have same root")))

(test-case "eval: persistence — old store unchanged after union"
  (let* ([s0 (whnf (expr-uf-empty))]
         [s1 (whnf (expr-uf-make-set s0 (expr-zero) (expr-true)))]
         [s2 (whnf (expr-uf-make-set s1 (expr-suc (expr-zero)) (expr-false)))]
         [s3 (whnf (expr-uf-union s2 (expr-zero) (expr-suc (expr-zero))))]
         ;; s2 should be unchanged — 0 and 1 have different roots
         [find0-old (whnf (expr-uf-find s2 (expr-zero)))]
         [find1-old (whnf (expr-uf-find s2 (expr-suc (expr-zero))))]
         [root0-old (whnf (expr-fst find0-old))]
         [root1-old (whnf (expr-fst find1-old))])
    (check-not-equal? root0-old root1-old "old store: 0 and 1 are separate")))
