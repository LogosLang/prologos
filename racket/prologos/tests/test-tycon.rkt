#lang racket/base

;;;
;;; Tests for HKT Phase 1: expr-tycon AST node + normalization
;;; Tests the new expr-tycon struct, normalize-for-resolution,
;;; kind inference, unifier decomposition, and trait resolution extensions.
;;;

(require rackunit
         racket/list
         "../syntax.rkt"
         "../prelude.rkt"
         "../metavar-store.rkt"
         "../substitution.rkt"
         "../zonk.rkt"
         "../reduction.rkt"
         (prefix-in tc: "../typing-core.rkt")
         "../pretty-print.rkt"
         "../unify.rkt"
         "../trait-resolution.rkt"
         "../global-env.rkt"
         "../driver.rkt")

;; ========================================
;; 1. expr-tycon construction and predicates
;; ========================================

(test-case "expr-tycon: construction and field access"
  (define tc (expr-tycon 'PVec))
  (check-true (expr-tycon? tc))
  (check-equal? (expr-tycon-name tc) 'PVec)
  (check-true (expr? tc)))

(test-case "expr-tycon: structural equality via #:transparent"
  (check-equal? (expr-tycon 'PVec) (expr-tycon 'PVec))
  (check-not-equal? (expr-tycon 'PVec) (expr-tycon 'Set))
  (check-not-equal? (expr-tycon 'Map) (expr-fvar 'Map)))

;; ========================================
;; 2. Kind table
;; ========================================

(test-case "builtin-tycon-arity: known constructors"
  (check-equal? (hash-ref builtin-tycon-arity 'PVec) 1)
  (check-equal? (hash-ref builtin-tycon-arity 'Set) 1)
  (check-equal? (hash-ref builtin-tycon-arity 'Map) 2)
  (check-equal? (hash-ref builtin-tycon-arity 'List) 1)
  (check-equal? (hash-ref builtin-tycon-arity 'LSeq) 1)
  (check-equal? (hash-ref builtin-tycon-arity 'Vec) 2)
  (check-equal? (hash-ref builtin-tycon-arity 'TVec) 1)
  (check-equal? (hash-ref builtin-tycon-arity 'TMap) 2)
  (check-equal? (hash-ref builtin-tycon-arity 'TSet) 1))

(test-case "builtin-tycon-arity: unknown constructor returns #f"
  (check-false (hash-ref builtin-tycon-arity 'Foo #f)))

;; ========================================
;; 3. normalize-for-resolution
;; ========================================

(test-case "normalize-for-resolution: PVec A → (app (tycon PVec) A)"
  (with-fresh-meta-env
    (define result (normalize-for-resolution (expr-PVec (expr-Nat))))
    (check-true (expr-app? result))
    (check-true (expr-tycon? (expr-app-func result)))
    (check-equal? (expr-tycon-name (expr-app-func result)) 'PVec)
    (check-equal? (expr-app-arg result) (expr-Nat))))

(test-case "normalize-for-resolution: Set A → (app (tycon Set) A)"
  (with-fresh-meta-env
    (define result (normalize-for-resolution (expr-Set (expr-Int))))
    (check-true (expr-app? result))
    (check-true (expr-tycon? (expr-app-func result)))
    (check-equal? (expr-tycon-name (expr-app-func result)) 'Set)
    (check-equal? (expr-app-arg result) (expr-Int))))

(test-case "normalize-for-resolution: Map K V → (app (app (tycon Map) K) V)"
  (with-fresh-meta-env
    (define result (normalize-for-resolution (expr-Map (expr-Keyword) (expr-Nat))))
    ;; Should be (app (app (tycon Map) Keyword) Nat)
    (check-true (expr-app? result))
    (check-equal? (expr-app-arg result) (expr-Nat))
    (define inner (expr-app-func result))
    (check-true (expr-app? inner))
    (check-true (expr-tycon? (expr-app-func inner)))
    (check-equal? (expr-tycon-name (expr-app-func inner)) 'Map)
    (check-equal? (expr-app-arg inner) (expr-Keyword))))

(test-case "normalize-for-resolution: fvar List → tycon List"
  (with-fresh-meta-env
    (define result (normalize-for-resolution (expr-fvar 'List)))
    (check-true (expr-tycon? result))
    (check-equal? (expr-tycon-name result) 'List)))

(test-case "normalize-for-resolution: fvar Foo → fvar Foo (not in kind table)"
  (with-fresh-meta-env
    (define result (normalize-for-resolution (expr-fvar 'Foo)))
    (check-true (expr-fvar? result))
    (check-equal? (expr-fvar-name result) 'Foo)))

(test-case "normalize-for-resolution: expr-app (fvar List) Nat → (app (tycon List) Nat)"
  (with-fresh-meta-env
    (define result (normalize-for-resolution (expr-app (expr-fvar 'List) (expr-Nat))))
    (check-true (expr-app? result))
    (check-true (expr-tycon? (expr-app-func result)))
    (check-equal? (expr-tycon-name (expr-app-func result)) 'List)
    (check-equal? (expr-app-arg result) (expr-Nat))))

(test-case "normalize-for-resolution: plain types pass through"
  (with-fresh-meta-env
    (check-equal? (normalize-for-resolution (expr-Nat)) (expr-Nat))
    (check-equal? (normalize-for-resolution (expr-Bool)) (expr-Bool))
    (check-equal? (normalize-for-resolution (expr-Int)) (expr-Int))))

;; ========================================
;; 4. Pipeline identity cases
;; ========================================

(test-case "substitution: shift and subst are identity for expr-tycon"
  (define tc (expr-tycon 'PVec))
  (check-equal? (shift 5 0 tc) tc)
  (check-equal? (subst 0 (expr-Nat) tc) tc))

(test-case "zonk: expr-tycon passes through all zonk variants"
  (with-fresh-meta-env
    (define tc (expr-tycon 'Set))
    (check-equal? (zonk tc) tc)
    (check-equal? (zonk-at-depth 3 tc) tc)
    (check-equal? (zonk-final tc) tc)))

(test-case "reduction: expr-tycon is already in normal form"
  (with-fresh-meta-env
    (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)])
      (define tc (expr-tycon 'Map))
      (check-equal? (whnf tc) tc)
      (check-equal? (nf tc) tc))))

(test-case "pretty-print: expr-tycon prints as constructor name"
  (with-fresh-meta-env
    (check-equal? (pp-expr (expr-tycon 'PVec)) "PVec")
    (check-equal? (pp-expr (expr-tycon 'Map)) "Map")
    (check-equal? (pp-expr (expr-tycon 'Set)) "Set")))

;; ========================================
;; 5. Typing: kind inference for expr-tycon
;; ========================================

(test-case "typing: expr-tycon PVec has kind Type -> Type"
  (with-fresh-meta-env
    (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)])
      (define kind (tc:infer '() (expr-tycon 'PVec)))
      ;; Should be (Pi m0 (Type lzero) (Type lzero))
      (check-true (expr-Pi? kind))
      (check-equal? (expr-Pi-mult kind) 'm0)
      (check-true (expr-Type? (expr-Pi-domain kind)))
      (check-true (expr-Type? (expr-Pi-codomain kind))))))

(test-case "typing: expr-tycon Map has kind Type -> Type -> Type"
  (with-fresh-meta-env
    (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)])
      (define kind (tc:infer '() (expr-tycon 'Map)))
      ;; Should be (Pi m0 (Type lzero) (Pi m0 (Type lzero) (Type lzero)))
      (check-true (expr-Pi? kind))
      (check-equal? (expr-Pi-mult kind) 'm0)
      (define inner (expr-Pi-codomain kind))
      (check-true (expr-Pi? inner))
      (check-equal? (expr-Pi-mult inner) 'm0)
      (check-true (expr-Type? (expr-Pi-codomain inner))))))

(test-case "typing: expr-tycon with unknown name returns error"
  (with-fresh-meta-env
    (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)])
      (define kind (tc:infer '() (expr-tycon 'Unknown)))
      (check-true (expr-error? kind)))))

;; ========================================
;; 6. Unifier: expr-tycon decomposition
;; ========================================

(test-case "unify: tycon vs tycon (same name) succeeds"
  (with-fresh-meta-env
    (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)])
      (check-true (unify ctx-empty (expr-tycon 'PVec) (expr-tycon 'PVec))))))

(test-case "unify: tycon vs tycon (different names) fails"
  (with-fresh-meta-env
    (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)])
      (check-false (unify ctx-empty (expr-tycon 'PVec) (expr-tycon 'Set))))))

(test-case "unify: meta solves to expr-tycon"
  (with-fresh-meta-env
    (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)])
      (define m (fresh-meta ctx-empty (expr-Type (lzero)) "test"))
      (check-true (unify ctx-empty m (expr-tycon 'PVec)))
      (check-true (meta-solved? (expr-meta-id m)))
      (check-equal? (meta-solution (expr-meta-id m)) (expr-tycon 'PVec)))))

;; ========================================
;; 7. Unifier: HKT normalization
;; ========================================

(test-case "unify: (PVec Nat) vs (app (tycon PVec) Nat) — normalization"
  (with-fresh-meta-env
    (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)])
      (check-true (unify ctx-empty
                         (expr-PVec (expr-Nat))
                         (expr-app (expr-tycon 'PVec) (expr-Nat)))))))

(test-case "unify: (app ?F Nat) vs (PVec Nat) — HKT meta solving"
  (with-fresh-meta-env
    (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)])
      (define m (fresh-meta ctx-empty (expr-Type (lzero)) "F"))
      (check-true (unify ctx-empty
                         (expr-app m (expr-Nat))
                         (expr-PVec (expr-Nat))))
      (check-true (meta-solved? (expr-meta-id m)))
      (check-equal? (meta-solution (expr-meta-id m)) (expr-tycon 'PVec)))))

(test-case "unify: (app ?F Int) vs (Set Int) — HKT meta solving for Set"
  (with-fresh-meta-env
    (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)])
      (define m (fresh-meta ctx-empty (expr-Type (lzero)) "F"))
      (check-true (unify ctx-empty
                         (expr-app m (expr-Int))
                         (expr-Set (expr-Int))))
      (check-true (meta-solved? (expr-meta-id m)))
      (check-equal? (meta-solution (expr-meta-id m)) (expr-tycon 'Set)))))

;; ========================================
;; 8. Trait resolution extensions
;; ========================================

(test-case "expr->impl-key-str: expr-tycon produces constructor name"
  (check-equal? (expr->impl-key-str (expr-tycon 'PVec)) "PVec")
  (check-equal? (expr->impl-key-str (expr-tycon 'List)) "List")
  (check-equal? (expr->impl-key-str (expr-tycon 'Map)) "Map"))

(test-case "expr->impl-key-str: built-in types produce short names"
  (check-equal? (expr->impl-key-str (expr-PVec (expr-Nat))) "PVec")
  (check-equal? (expr->impl-key-str (expr-Set (expr-Int))) "Set")
  (check-equal? (expr->impl-key-str (expr-Map (expr-Keyword) (expr-Nat))) "Map"))

(test-case "ground-expr?: expr-tycon is ground"
  (with-fresh-meta-env
    (check-true (ground-expr? (expr-tycon 'PVec)))
    (check-true (ground-expr? (expr-tycon 'Map)))))

(test-case "match-one: expr-tycon matches its name symbol"
  (check-equal?
    (match-one (expr-tycon 'PVec) 'PVec '() (hasheq))
    (hasheq)))

(test-case "match-one: expr-tycon matches pattern variable"
  (define result (match-one (expr-tycon 'PVec) 'F '(F) (hasheq)))
  (check-equal? result (hasheq 'F (expr-tycon 'PVec))))

(test-case "match-one: expr-tycon doesn't match wrong name"
  (check-false (match-one (expr-tycon 'PVec) 'Set '() (hasheq))))
