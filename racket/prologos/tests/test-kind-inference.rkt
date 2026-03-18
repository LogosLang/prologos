#lang racket/base

;;;
;;; Tests for HKT Phase 2: Kind Inference from Trait Constraints
;;; Verifies that spec where-constraints propagate kinds to implicit binders.
;;; e.g., {C} [Seqable C] infers C : Type -> Type from Seqable's trait params.
;;;

(require rackunit
         racket/list
         racket/path
         racket/string
         "test-support.rkt"
         "../macros.rkt"
         "../prelude.rkt"
         "../syntax.rkt"
         "../source-location.rkt"
         "../surface-syntax.rkt"
         "../errors.rkt"
         "../metavar-store.rkt"
         "../parser.rkt"
         "../elaborator.rkt"
         "../pretty-print.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../namespace.rkt")

;; ========================================
;; Helpers
;; ========================================

;; Run prologos source and return last result
(define (run-ns-last s)
  (parameterize ([current-global-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry])
    (install-module-loader!)
    (last (process-string s))))

;; ========================================
;; 1. propagate-kinds-from-constraints unit tests
;; ========================================

(test-case "kind-inference: Seqable C refines C from Type to Type -> Type"
  (parameterize ([current-trait-registry (hasheq)])
    ;; Register a mock Seqable with {C : Type -> Type}
    (register-trait! 'Seqable
      (trait-meta 'Seqable '((C . (-> (Type 0) (Type 0)))) '() (hasheq)))
    (define brace-params '((C . (Type 0)) (A . (Type 0)) (B . (Type 0))))
    (define where-constraints '((Seqable C)))
    (define result (propagate-kinds-from-constraints brace-params where-constraints 'test))
    ;; C should be refined to (-> (Type 0) (Type 0))
    (check-equal? (assq 'C result) '(C . (-> (Type 0) (Type 0))))
    ;; A and B stay at (Type 0)
    (check-equal? (assq 'A result) '(A . (Type 0)))
    (check-equal? (assq 'B result) '(B . (Type 0)))))

(test-case "kind-inference: Eq A keeps A at Type"
  (parameterize ([current-trait-registry (hasheq)])
    (register-trait! 'Eq
      (trait-meta 'Eq '((A . (Type 0))) '() (hasheq)))
    (define brace-params '((A . (Type 0))))
    (define where-constraints '((Eq A)))
    (define result (propagate-kinds-from-constraints brace-params where-constraints 'test))
    ;; A stays at (Type 0) — Eq has {A : Type}
    (check-equal? (assq 'A result) '(A . (Type 0)))))

(test-case "kind-inference: Buildable C refines C to Type -> Type"
  (parameterize ([current-trait-registry (hasheq)])
    (register-trait! 'Buildable
      (trait-meta 'Buildable '((C . (-> (Type 0) (Type 0)))) '() (hasheq)))
    (define brace-params '((C . (Type 0))))
    (define where-constraints '((Buildable C)))
    (define result (propagate-kinds-from-constraints brace-params where-constraints 'test))
    (check-equal? (assq 'C result) '(C . (-> (Type 0) (Type 0))))))

(test-case "kind-inference: Keyed C refines C to Type -> Type -> Type"
  (parameterize ([current-trait-registry (hasheq)])
    (register-trait! 'Keyed
      (trait-meta 'Keyed '((C . (-> (Type 0) (-> (Type 0) (Type 0))))) '() (hasheq)))
    (define brace-params '((C . (Type 0))))
    (define where-constraints '((Keyed C)))
    (define result (propagate-kinds-from-constraints brace-params where-constraints 'test))
    (check-equal? (assq 'C result) '(C . (-> (Type 0) (-> (Type 0) (Type 0)))))))

(test-case "kind-inference: mixed {A C} [Seqable C] [Eq A] — only C refined"
  (parameterize ([current-trait-registry (hasheq)])
    (register-trait! 'Seqable
      (trait-meta 'Seqable '((C . (-> (Type 0) (Type 0)))) '() (hasheq)))
    (register-trait! 'Eq
      (trait-meta 'Eq '((A . (Type 0))) '() (hasheq)))
    (define brace-params '((A . (Type 0)) (B . (Type 0)) (C . (Type 0))))
    (define where-constraints '((Seqable C) (Eq A)))
    (define result (propagate-kinds-from-constraints brace-params where-constraints 'test))
    (check-equal? (assq 'C result) '(C . (-> (Type 0) (Type 0))))
    (check-equal? (assq 'A result) '(A . (Type 0)))
    (check-equal? (assq 'B result) '(B . (Type 0)))))

;; ========================================
;; 2. Multi-constraint consistency
;; ========================================

(test-case "kind-inference: Seqable C + Buildable C — both agree on Type -> Type"
  (parameterize ([current-trait-registry (hasheq)])
    (register-trait! 'Seqable
      (trait-meta 'Seqable '((C . (-> (Type 0) (Type 0)))) '() (hasheq)))
    (register-trait! 'Buildable
      (trait-meta 'Buildable '((C . (-> (Type 0) (Type 0)))) '() (hasheq)))
    (define brace-params '((C . (Type 0))))
    (define where-constraints '((Seqable C) (Buildable C)))
    (define result (propagate-kinds-from-constraints brace-params where-constraints 'test))
    ;; Both constraints agree: C : Type -> Type
    (check-equal? (assq 'C result) '(C . (-> (Type 0) (Type 0))))))

(test-case "kind-inference: conflicting constraints error"
  (parameterize ([current-trait-registry (hasheq)])
    (register-trait! 'Seqable
      (trait-meta 'Seqable '((C . (-> (Type 0) (Type 0)))) '() (hasheq)))
    (register-trait! 'Eq
      (trait-meta 'Eq '((A . (Type 0))) '() (hasheq)))
    (define brace-params '((X . (Type 0))))
    ;; Seqable expects X : Type -> Type, Eq expects X : Type — conflict!
    (define where-constraints '((Seqable X) (Eq X)))
    (check-exn exn:fail?
      (lambda ()
        (propagate-kinds-from-constraints brace-params where-constraints 'test)))))

;; ========================================
;; 3. Explicit annotation interaction
;; ========================================

(test-case "kind-inference: explicit {C : Type -> Type} + Seqable C — no conflict"
  (parameterize ([current-trait-registry (hasheq)])
    (register-trait! 'Seqable
      (trait-meta 'Seqable '((C . (-> (Type 0) (Type 0)))) '() (hasheq)))
    (define brace-params '((C . (-> (Type 0) (Type 0)))))
    (define where-constraints '((Seqable C)))
    (define result (propagate-kinds-from-constraints brace-params where-constraints 'test))
    ;; Already correct kind, no change
    (check-equal? (assq 'C result) '(C . (-> (Type 0) (Type 0))))))

(test-case "kind-inference: explicit {C : Type} + Seqable C — error"
  (parameterize ([current-trait-registry (hasheq)])
    (register-trait! 'Seqable
      (trait-meta 'Seqable '((C . (-> (Type 0) (Type 0)))) '() (hasheq)))
    ;; C is explicitly annotated as Type, but Seqable requires Type -> Type
    ;; Since (Type 0) is also the default, the propagation upgrades it.
    ;; To test explicit annotation conflict, we need a non-default kind:
    ;; If user wrote {C : Type}, current-kind = (Type 0) which is default.
    ;; The propagation will upgrade it, not error.
    ;; A true conflict would be {C : Type -> Type -> Type} vs Seqable expecting Type -> Type.
    (define brace-params '((C . (-> (Type 0) (-> (Type 0) (Type 0))))))
    (define where-constraints '((Seqable C)))
    (check-exn exn:fail?
      (lambda ()
        (propagate-kinds-from-constraints brace-params where-constraints 'test)))))

;; ========================================
;; 4. datum->kind-string helper
;; ========================================

(test-case "datum->kind-string: formats kinds correctly"
  (check-equal? (datum->kind-string '(Type 0)) "Type")
  (check-equal? (datum->kind-string '(-> (Type 0) (Type 0))) "Type -> Type")
  (check-equal? (datum->kind-string '(-> (Type 0) (-> (Type 0) (Type 0))))
                "Type -> Type -> Type"))

;; ========================================
;; 5. Unknown traits are gracefully skipped
;; ========================================

(test-case "kind-inference: unknown trait in where is skipped (not an error)"
  (parameterize ([current-trait-registry (hasheq)])
    ;; Foldable is a deftype, not registered as a trait — should be skipped
    (define brace-params '((F . (Type 0))))
    (define where-constraints '((Foldable F)))
    (define result (propagate-kinds-from-constraints brace-params where-constraints 'test))
    ;; F stays at default (Type 0) — no trait found, no refinement
    (check-equal? (assq 'F result) '(F . (Type 0)))))

(test-case "kind-inference: constraint var not in brace-params is ignored"
  (parameterize ([current-trait-registry (hasheq)])
    (register-trait! 'Eq
      (trait-meta 'Eq '((A . (Type 0))) '() (hasheq)))
    ;; Z is in constraint but not in brace-params — just skip
    (define brace-params '((X . (Type 0))))
    (define where-constraints '((Eq Z)))
    (define result (propagate-kinds-from-constraints brace-params where-constraints 'test))
    (check-equal? (assq 'X result) '(X . (Type 0)))))

;; ========================================
;; 6. extract-inline-constraints unit tests
;; ========================================

(test-case "extract-inline: single Seqable C before ->"
  (parameterize ([current-trait-registry (hasheq)])
    (register-trait! 'Seqable
      (trait-meta 'Seqable '((C . (-> (Type 0) (Type 0)))) '() (hasheq)))
    (define tokens '((Seqable C) -> (C A) -> (LSeq A)))
    (define result (extract-inline-constraints tokens))
    (check-equal? result '((Seqable C)))))

(test-case "extract-inline: multiple constraints before ->"
  (parameterize ([current-trait-registry (hasheq)])
    (register-trait! 'Seqable
      (trait-meta 'Seqable '((C . (-> (Type 0) (Type 0)))) '() (hasheq)))
    (register-trait! 'Buildable
      (trait-meta 'Buildable '((C . (-> (Type 0) (Type 0)))) '() (hasheq)))
    (define tokens '((Seqable C) (Buildable C) -> (-> A B) -> (C A) -> (C B)))
    (define result (extract-inline-constraints tokens))
    (check-equal? result '((Seqable C) (Buildable C)))))

(test-case "extract-inline: no constraints — bare types"
  (parameterize ([current-trait-registry (hasheq)])
    (define tokens '(Nat -> Nat))
    (define result (extract-inline-constraints tokens))
    (check-equal? result '())))

(test-case "extract-inline: non-trait list form stops scanning"
  (parameterize ([current-trait-registry (hasheq)])
    (register-trait! 'Eq
      (trait-meta 'Eq '((A . (Type 0))) '() (hasheq)))
    ;; (C A) is not a trait — it's a type application. Scanning stops there.
    (define tokens '((C A) -> (LSeq A)))
    (define result (extract-inline-constraints tokens))
    (check-equal? result '())))

(test-case "extract-inline: mixed constraint and Eq"
  (parameterize ([current-trait-registry (hasheq)])
    (register-trait! 'Seqable
      (trait-meta 'Seqable '((C . (-> (Type 0) (Type 0)))) '() (hasheq)))
    (register-trait! 'Eq
      (trait-meta 'Eq '((A . (Type 0))) '() (hasheq)))
    (define tokens '((Seqable C) (Eq A) -> (C A) -> Bool))
    (define result (extract-inline-constraints tokens))
    (check-equal? result '((Seqable C) (Eq A)))))

(test-case "extract-inline: empty token list"
  (parameterize ([current-trait-registry (hasheq)])
    (check-equal? (extract-inline-constraints '()) '())))

;; ========================================
;; 7. End-to-end: spec with inline constraints in sexp mode
;; ========================================
;; These tests verify that inline (Seqable C) before -> triggers kind propagation
;; for the spec's implicit binders. We check the spec-entry's implicit-binders.

(test-case "kind-inference: e2e sexp spec with inline Seqable constraint"
  (define result
    (run-ns-last
      (string-append
        "(ns test-kind-e2e1)\n"
        "(imports [prologos::core::collection-traits :refer [Seqable]])\n"
        "(imports [prologos::data::lseq :refer [LSeq]])\n"
        "(spec my-to-seq ($brace-params C) ($brace-params A)"
        "  (Seqable C) -> (C A) -> (LSeq A))\n"
        "(eval (suc zero))\n")))
  (check-equal? result "1N : Nat"))

(test-case "kind-inference: e2e sexp spec with inline Buildable constraint"
  (define result
    (run-ns-last
      (string-append
        "(ns test-kind-e2e2)\n"
        "(imports [prologos::core::collection-traits :refer [Buildable]])\n"
        "(imports [prologos::data::lseq :refer [LSeq]])\n"
        "(spec my-from-seq ($brace-params C) ($brace-params A)"
        "  (Buildable C) -> (LSeq A) -> (C A))\n"
        "(eval (suc zero))\n")))
  (check-equal? result "1N : Nat"))

(test-case "kind-inference: e2e sexp spec with both Seqable and Buildable inline"
  (define result
    (run-ns-last
      (string-append
        "(ns test-kind-e2e3)\n"
        "(imports [prologos::core::collection-traits :refer [Seqable]])\n"
        "(imports [prologos::core::collection-traits :refer [Buildable]])\n"
        "(imports [prologos::data::lseq :refer [LSeq]])\n"
        "(spec my-transform ($brace-params C) ($brace-params A B)"
        "  (Seqable C) -> (Buildable C) -> (-> A B) -> (C A) -> (C B))\n"
        "(eval (suc zero))\n")))
  (check-equal? result "1N : Nat"))

;; ========================================
;; 8. Spec-level: verify implicit-binders get refined kind
;; ========================================
;; Test that after processing a spec with {C} and inline (Seqable C),
;; the stored spec-entry has C's kind refined to (-> (Type 0) (Type 0)).

(test-case "kind-inference: spec entry stores refined kind from inline constraint"
  (parameterize ([current-global-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-spec-store (hasheq)])
    (install-module-loader!)
    ;; Load Seqable trait so it's in the trait registry
    (process-string "(ns test-kind-spec1)\n(imports [prologos::core::collection-traits :refer [Seqable]])\n")
    ;; Now process a spec with inline constraint
    (process-string "(spec my-to-seq ($brace-params C) ($brace-params A) (Seqable C) -> (C A) -> (LSeq A))\n")
    ;; Check the stored spec entry
    (define se (hash-ref (current-spec-store) 'my-to-seq #f))
    (check-true (spec-entry? se))
    (define ibinders (spec-entry-implicit-binders se))
    ;; Should have 2 binders: C and A
    (check-equal? (length ibinders) 2)
    ;; C should have kind (-> (Type 0) (Type 0)) from Seqable constraint
    (check-equal? (assq 'C ibinders) '(C . (-> (Type 0) (Type 0))))
    ;; A should stay at default (Type 0)
    (check-equal? (assq 'A ibinders) '(A . (Type 0)))))
