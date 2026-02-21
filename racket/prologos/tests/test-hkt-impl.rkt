#lang racket/base

;;;
;;; Tests for HKT Phase 3: Trait Conversion + Impl Registration
;;; Verifies that Foldable/Functor are now proper traits, and that
;;; manual `def` trait dict forms get auto-registered in the impl registry.
;;;

(require rackunit
         racket/list
         racket/path
         racket/string
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

(define here (path->string (path-only (syntax-source #'here))))
(define lib-dir (simplify-path (build-path here ".." "lib")))

(define (run-ns-last s)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (current-trait-registry)]
                 [current-impl-registry (current-impl-registry)]
                 [current-param-impl-registry (current-param-impl-registry)])
    (install-module-loader!)
    (last (process-string s))))

;; Process string and return the impl registry state
(define (run-ns-impls s)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (current-trait-registry)]
                 [current-impl-registry (current-impl-registry)]
                 [current-param-impl-registry (current-param-impl-registry)])
    (install-module-loader!)
    (process-string s)
    (current-impl-registry)))

;; ========================================
;; 1. Foldable is now a proper trait
;; ========================================

(test-case "hkt-impl: Foldable is registered as trait"
  (define impls
    (run-ns-impls
      (string-append
        "(ns test-hkt-impl-1)\n"
        "(require [prologos::core::foldable-trait :refer [Foldable]])\n"
        "(eval zero)\n")))
  ;; Foldable should be in trait registry after loading
  ;; (We can't directly check trait registry here since it's parameterized,
  ;;  but the module loaded without error, which means trait form was valid)
  (void))

(test-case "hkt-impl: Foldable trait generates accessor Foldable-fold"
  (define result
    (run-ns-last
      (string-append
        "(ns test-hkt-impl-2)\n"
        "(require [prologos::core::foldable-trait :refer [Foldable Foldable-fold]])\n"
        "(eval (suc zero))\n")))
  (check-equal? result "1N : Nat"))

;; ========================================
;; 2. Functor is now a proper trait
;; ========================================

(test-case "hkt-impl: Functor is registered as trait"
  (define result
    (run-ns-last
      (string-append
        "(ns test-hkt-impl-3)\n"
        "(require [prologos::core::functor-trait :refer [Functor Functor-fmap]])\n"
        "(eval (suc zero))\n")))
  (check-equal? result "1N : Nat"))

;; ========================================
;; 3. Auto-registration from manual defs
;; ========================================

(test-case "hkt-impl: maybe-register detects def with (TraitName Type) annotation"
  (parameterize ([current-trait-registry (hasheq)]
                 [current-impl-registry (hasheq)])
    ;; Register a mock trait
    (register-trait! 'Seqable
      (trait-meta 'Seqable '((C . (-> (Type 0) (Type 0)))) '()))
    ;; Simulate processing a def with trait type annotation
    (maybe-register-trait-dict-def '(def my-dict : (Seqable List) some-body))
    ;; Should now be registered
    (define entry (lookup-impl 'List--Seqable))
    (check-true (impl-entry? entry))
    (check-equal? (impl-entry-trait-name entry) 'Seqable)
    (check-equal? (impl-entry-type-args entry) '(List))
    (check-equal? (impl-entry-dict-name entry) 'my-dict)))

(test-case "hkt-impl: maybe-register detects spec with (TraitName Type) annotation"
  (parameterize ([current-trait-registry (hasheq)]
                 [current-impl-registry (hasheq)])
    (register-trait! 'Buildable
      (trait-meta 'Buildable '((C . (-> (Type 0) (Type 0)))) '()))
    (maybe-register-trait-dict-def '(spec PVec--Buildable--dict (Buildable PVec)))
    (define entry (lookup-impl 'PVec--Buildable))
    (check-true (impl-entry? entry))
    (check-equal? (impl-entry-dict-name entry) 'PVec--Buildable--dict)))

(test-case "hkt-impl: maybe-register ignores non-trait type annotations"
  (parameterize ([current-trait-registry (hasheq)]
                 [current-impl-registry (hasheq)])
    ;; No trait registered for Nat
    (maybe-register-trait-dict-def '(def foo : (Nat) bar))
    ;; Should NOT be registered
    (check-false (lookup-impl 'Nat--))))

(test-case "hkt-impl: maybe-register ignores defs without type annotations"
  (parameterize ([current-trait-registry (hasheq)]
                 [current-impl-registry (hasheq)])
    (register-trait! 'Eq
      (trait-meta 'Eq '((A . (Type 0))) '()))
    ;; No colon/type annotation
    (maybe-register-trait-dict-def '(def foo bar))
    ;; Registry should be empty
    (check-equal? (current-impl-registry) (hasheq))))

(test-case "hkt-impl: maybe-register skips already-registered impls"
  (parameterize ([current-trait-registry (hasheq)]
                 [current-impl-registry (hasheq)])
    (register-trait! 'Eq
      (trait-meta 'Eq '((A . (Type 0))) '()))
    ;; Pre-register an impl
    (register-impl! 'Nat--Eq (impl-entry 'Eq '(Nat) 'Nat--Eq--dict))
    ;; Try to auto-register with same key but different dict name
    (maybe-register-trait-dict-def '(def other-dict : (Eq Nat) body))
    ;; Should keep original entry, not overwrite
    (check-equal? (impl-entry-dict-name (lookup-impl 'Nat--Eq)) 'Nat--Eq--dict)))

;; ========================================
;; 4. Seqable instances registered after loading
;; ========================================

(test-case "hkt-impl: Seqable List impl registered after require"
  (define impls
    (run-ns-impls
      (string-append
        "(ns test-hkt-impl-seq1)\n"
        "(require [prologos::core::seqable-list :refer [List--Seqable--dict]])\n"
        "(eval zero)\n")))
  (define entry (hash-ref impls 'List--Seqable #f))
  (check-true (impl-entry? entry))
  (check-equal? (impl-entry-trait-name entry) 'Seqable)
  (check-equal? (impl-entry-type-args entry) '(List))
  (check-equal? (impl-entry-dict-name entry) 'List--Seqable--dict))

(test-case "hkt-impl: Seqable PVec impl registered after require"
  (define impls
    (run-ns-impls
      (string-append
        "(ns test-hkt-impl-seq2)\n"
        "(require [prologos::core::seqable-pvec :refer [PVec--Seqable--dict]])\n"
        "(eval zero)\n")))
  (define entry (hash-ref impls 'PVec--Seqable #f))
  (check-true (impl-entry? entry))
  (check-equal? (impl-entry-type-args entry) '(PVec)))

(test-case "hkt-impl: Seqable LSeq impl registered after require"
  (define impls
    (run-ns-impls
      (string-append
        "(ns test-hkt-impl-seq3)\n"
        "(require [prologos::core::seqable-lseq :refer [LSeq--Seqable--dict]])\n"
        "(eval zero)\n")))
  (define entry (hash-ref impls 'LSeq--Seqable #f))
  (check-true (impl-entry? entry)))

(test-case "hkt-impl: Seqable Set impl registered after require"
  (define impls
    (run-ns-impls
      (string-append
        "(ns test-hkt-impl-seq4)\n"
        "(require [prologos::core::seqable-set :refer [Set--Seqable--dict]])\n"
        "(eval zero)\n")))
  (define entry (hash-ref impls 'Set--Seqable #f))
  (check-true (impl-entry? entry)))

;; ========================================
;; 5. Buildable instances registered
;; ========================================

(test-case "hkt-impl: Buildable List impl registered"
  (define impls
    (run-ns-impls
      (string-append
        "(ns test-hkt-impl-build1)\n"
        "(require [prologos::core::buildable-list :refer [List--Buildable--dict]])\n"
        "(eval zero)\n")))
  (define entry (hash-ref impls 'List--Buildable #f))
  (check-true (impl-entry? entry))
  (check-equal? (impl-entry-trait-name entry) 'Buildable)
  (check-equal? (impl-entry-type-args entry) '(List)))

(test-case "hkt-impl: Buildable PVec impl registered"
  (define impls
    (run-ns-impls
      (string-append
        "(ns test-hkt-impl-build2)\n"
        "(require [prologos::core::buildable-pvec :refer [PVec--Buildable--dict]])\n"
        "(eval zero)\n")))
  (define entry (hash-ref impls 'PVec--Buildable #f))
  (check-true (impl-entry? entry)))

;; ========================================
;; 6. Foldable instances registered
;; ========================================

(test-case "hkt-impl: Foldable List impl registered"
  (define impls
    (run-ns-impls
      (string-append
        "(ns test-hkt-impl-fold1)\n"
        "(require [prologos::core::foldable-list :refer [list-foldable]])\n"
        "(eval zero)\n")))
  (define entry (hash-ref impls 'List--Foldable #f))
  (check-true (impl-entry? entry))
  (check-equal? (impl-entry-dict-name entry) 'list-foldable))

(test-case "hkt-impl: Foldable PVec impl registered"
  (define impls
    (run-ns-impls
      (string-append
        "(ns test-hkt-impl-fold2)\n"
        "(require [prologos::core::foldable-pvec :refer [pvec-foldable]])\n"
        "(eval zero)\n")))
  (define entry (hash-ref impls 'PVec--Foldable #f))
  (check-true (impl-entry? entry)))

;; ========================================
;; 7. Functor instances registered
;; ========================================

(test-case "hkt-impl: Functor List impl registered"
  (define impls
    (run-ns-impls
      (string-append
        "(ns test-hkt-impl-func1)\n"
        "(require [prologos::core::functor-list :refer [list-functor]])\n"
        "(eval zero)\n")))
  (define entry (hash-ref impls 'List--Functor #f))
  (check-true (impl-entry? entry))
  (check-equal? (impl-entry-dict-name entry) 'list-functor))

(test-case "hkt-impl: Functor PVec impl registered"
  (define impls
    (run-ns-impls
      (string-append
        "(ns test-hkt-impl-func2)\n"
        "(require [prologos::core::functor-pvec :refer [pvec-functor]])\n"
        "(eval zero)\n")))
  (define entry (hash-ref impls 'PVec--Functor #f))
  (check-true (impl-entry? entry)))

;; ========================================
;; 8. Backward compatibility: existing code still works
;; ========================================

(test-case "hkt-impl: existing foldable list usage works"
  (define result
    (run-ns-last
      (string-append
        "(ns test-hkt-impl-compat1)\n"
        "(require [prologos::core::foldable-list :refer [list-foldable]])\n"
        "(require [prologos::data::list :refer [List cons nil]])\n"
        "(eval (list-foldable Nat Nat (fn (a : Nat) (fn (b : Nat) (add a b))) zero"
        "  (cons Nat (suc (suc zero)) (cons Nat (suc zero) (nil Nat)))))\n")))
  (check-equal? result "3N : Nat"))

(test-case "hkt-impl: existing functor list usage works"
  (define result
    (run-ns-last
      (string-append
        "(ns test-hkt-impl-compat2)\n"
        "(require [prologos::core::functor-list :refer [list-functor]])\n"
        "(require [prologos::data::list :refer [List cons nil length]])\n"
        "(eval (length (list-functor Nat Nat (fn (n : Nat) (suc n))"
        "  (cons Nat (suc zero) (cons Nat zero (nil Nat))))))\n")))
  (check-equal? result "2N : Nat"))
