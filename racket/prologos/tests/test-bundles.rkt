#lang racket/base

;;;
;;; Tests for Phase E: Bundles (named constraint conjunctions)
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
         "../namespace.rkt"
         "../trait-resolution.rkt")

;; ========================================
;; Helpers
;; ========================================

(define (run s)
  (parameterize ([current-global-env (hasheq)])
    (process-string s)))

(define (run-first s) (car (run s)))
(define (run-last s) (last (run s)))

(define (run-ns s)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 [current-bundle-registry (current-bundle-registry)])
    (install-module-loader!)
    (process-string s)))

(define (run-ns-last s) (last (run-ns s)))

;; ========================================
;; Unit Tests — process-bundle parsing
;; ========================================

(test-case "process-bundle/flat-shorthand"
  ;; (bundle Comparable := (Eq Ord))
  ;; WS reader: `bundle Comparable := (Eq, Ord)` → datum `(bundle Comparable := (Eq Ord))`
  ;; All bare symbols → each gets implicit type param A
  (parameterize ([current-trait-registry (hasheq)]
                 [current-bundle-registry (hasheq)])
    ;; Register mock traits
    (register-trait! 'Eq (trait-meta 'Eq '(A) (list (trait-method 'eq? '(A -> A -> Bool)))))
    (register-trait! 'Ord (trait-meta 'Ord '(A) (list (trait-method 'compare '(A -> A -> Nat)))))
    ;; Process bundle
    (process-bundle '(bundle Comparable := (Eq Ord)))
    (define b (lookup-bundle 'Comparable))
    (check-not-false b)
    (check-equal? (bundle-entry-name b) 'Comparable)
    (check-equal? (bundle-entry-params b) '(A))
    (check-equal? (bundle-entry-constraints b) '((Eq A) (Ord A)))))

(test-case "process-bundle/bracketed-sub-lists"
  ;; (bundle Conv := ((From A B) (Into B A)))
  ;; WS reader: `bundle Conv := ([From A B] [Into B A])` → datum with sub-lists
  (parameterize ([current-trait-registry (hasheq)]
                 [current-bundle-registry (hasheq)])
    (register-trait! 'From (trait-meta 'From '(A B) (list (trait-method 'from '(A -> B)))))
    (register-trait! 'Into (trait-meta 'Into '(A B) (list (trait-method 'into '(B -> A)))))
    (process-bundle '(bundle Conv := ((From A B) (Into B A))))
    (define b (lookup-bundle 'Conv))
    (check-not-false b)
    (check-equal? (bundle-entry-name b) 'Conv)
    (check-equal? (bundle-entry-params b) '(A B))
    (check-equal? (bundle-entry-constraints b) '((From A B) (Into B A)))))

(test-case "process-bundle/positional-no-:="
  ;; (bundle Simple (Eq A) (Ord A))
  (parameterize ([current-trait-registry (hasheq)]
                 [current-bundle-registry (hasheq)])
    (register-trait! 'Eq (trait-meta 'Eq '(A) (list (trait-method 'eq? '(A -> A -> Bool)))))
    (register-trait! 'Ord (trait-meta 'Ord '(A) (list (trait-method 'compare '(A -> A -> Nat)))))
    (process-bundle '(bundle Simple (Eq A) (Ord A)))
    (define b (lookup-bundle 'Simple))
    (check-not-false b)
    (check-equal? (bundle-entry-params b) '(A))
    (check-equal? (bundle-entry-constraints b) '((Eq A) (Ord A)))))

(test-case "process-bundle/error-empty-body"
  (parameterize ([current-bundle-registry (hasheq)])
    (check-exn exn:fail?
      (lambda () (process-bundle '(bundle Empty :=))))))

;; ========================================
;; Unit Tests — expand-bundle-constraints
;; ========================================

(test-case "expand/pure-traits-unchanged"
  ;; Pure trait constraints pass through unchanged
  (parameterize ([current-trait-registry (hasheq)]
                 [current-bundle-registry (hasheq)])
    (register-trait! 'Eq (trait-meta 'Eq '(A) (list (trait-method 'eq? '(A -> A -> Bool)))))
    (register-trait! 'Ord (trait-meta 'Ord '(A) (list (trait-method 'compare '(A -> A -> Nat)))))
    (check-equal?
      (expand-bundle-constraints '((Eq A) (Ord A)))
      '((Eq A) (Ord A)))))

(test-case "expand/simple-bundle"
  ;; (Comparable Nat) → ((Eq Nat) (Ord Nat))
  (parameterize ([current-trait-registry (hasheq)]
                 [current-bundle-registry (hasheq)])
    (register-trait! 'Eq (trait-meta 'Eq '(A) (list (trait-method 'eq? '(A -> A -> Bool)))))
    (register-trait! 'Ord (trait-meta 'Ord '(A) (list (trait-method 'compare '(A -> A -> Nat)))))
    (register-bundle! 'Comparable (bundle-entry 'Comparable '(A) '((Eq A) (Ord A))))
    (check-equal?
      (expand-bundle-constraints '((Comparable Nat)))
      '((Eq Nat) (Ord Nat)))))

(test-case "expand/nested-bundle"
  ;; Numeric = (Add, Sub, Comparable) where Comparable = (Eq, Ord)
  ;; (Numeric A) → ((Add A) (Sub A) (Eq A) (Ord A))
  (parameterize ([current-trait-registry (hasheq)]
                 [current-bundle-registry (hasheq)])
    (register-trait! 'Add (trait-meta 'Add '(A) (list (trait-method '+ '(A -> A -> A)))))
    (register-trait! 'Sub (trait-meta 'Sub '(A) (list (trait-method '- '(A -> A -> A)))))
    (register-trait! 'Eq (trait-meta 'Eq '(A) (list (trait-method 'eq? '(A -> A -> Bool)))))
    (register-trait! 'Ord (trait-meta 'Ord '(A) (list (trait-method 'compare '(A -> A -> Nat)))))
    (register-bundle! 'Comparable (bundle-entry 'Comparable '(A) '((Eq A) (Ord A))))
    (register-bundle! 'Numeric (bundle-entry 'Numeric '(A) '((Add A) (Sub A) (Comparable A))))
    (check-equal?
      (expand-bundle-constraints '((Numeric A)))
      '((Add A) (Sub A) (Eq A) (Ord A)))))

(test-case "expand/dedup"
  ;; (Numeric A) (Eq A) → no duplicate (Eq A)
  (parameterize ([current-trait-registry (hasheq)]
                 [current-bundle-registry (hasheq)])
    (register-trait! 'Add (trait-meta 'Add '(A) (list (trait-method '+ '(A -> A -> A)))))
    (register-trait! 'Sub (trait-meta 'Sub '(A) (list (trait-method '- '(A -> A -> A)))))
    (register-trait! 'Eq (trait-meta 'Eq '(A) (list (trait-method 'eq? '(A -> A -> Bool)))))
    (register-trait! 'Ord (trait-meta 'Ord '(A) (list (trait-method 'compare '(A -> A -> Nat)))))
    (register-bundle! 'Comparable (bundle-entry 'Comparable '(A) '((Eq A) (Ord A))))
    (register-bundle! 'Numeric (bundle-entry 'Numeric '(A) '((Add A) (Sub A) (Comparable A))))
    (define result (expand-bundle-constraints '((Numeric A) (Eq A))))
    ;; Should be ((Add A) (Sub A) (Eq A) (Ord A)) — no duplicate (Eq A)
    (check-equal? result '((Add A) (Sub A) (Eq A) (Ord A)))))

(test-case "expand/multi-param-bundle"
  ;; (Conv Int Rat) → ((From Int Rat) (Into Rat Int))
  (parameterize ([current-trait-registry (hasheq)]
                 [current-bundle-registry (hasheq)])
    (register-trait! 'From (trait-meta 'From '(A B) (list (trait-method 'from '(A -> B)))))
    (register-trait! 'Into (trait-meta 'Into '(A B) (list (trait-method 'into '(B -> A)))))
    (register-bundle! 'Conv (bundle-entry 'Conv '(A B) '((From A B) (Into B A))))
    (check-equal?
      (expand-bundle-constraints '((Conv Int Rat)))
      '((From Int Rat) (Into Rat Int)))))

(test-case "expand/cycle-detection"
  ;; A → B, B → A should error
  (parameterize ([current-trait-registry (hasheq)]
                 [current-bundle-registry (hasheq)])
    (register-trait! 'Eq (trait-meta 'Eq '(A) (list (trait-method 'eq? '(A -> A -> Bool)))))
    (register-bundle! 'BundleA (bundle-entry 'BundleA '(A) '((BundleB A))))
    (register-bundle! 'BundleB (bundle-entry 'BundleB '(A) '((BundleA A))))
    (check-exn exn:fail?
      (lambda () (expand-bundle-constraints '((BundleA X)))))))

(test-case "expand/unknown-head-passthrough"
  ;; Unknown trait or bundle name → pass through as-is (validated downstream)
  (parameterize ([current-trait-registry (hasheq)]
                 [current-bundle-registry (hasheq)])
    (check-equal?
      (expand-bundle-constraints '((NonexistentTrait A)))
      '((NonexistentTrait A)))))

(test-case "expand/arity-mismatch-error"
  ;; Bundle expects 1 param, given 2 → error
  (parameterize ([current-trait-registry (hasheq)]
                 [current-bundle-registry (hasheq)])
    (register-trait! 'Eq (trait-meta 'Eq '(A) (list (trait-method 'eq? '(A -> A -> Bool)))))
    (register-bundle! 'Eqable (bundle-entry 'Eqable '(A) '((Eq A))))
    (check-exn exn:fail?
      (lambda () (expand-bundle-constraints '((Eqable X Y)))))))

;; ========================================
;; Integration Tests — spec with bundle
;; ========================================

(test-case "integration/spec-stores-expanded-constraints"
  ;; spec with bundle in where clause stores expanded flat trait constraints
  (parameterize ([current-trait-registry (hasheq)]
                 [current-bundle-registry (hasheq)]
                 [current-spec-store (hasheq)])
    (register-trait! 'Eq (trait-meta 'Eq '(A) (list (trait-method 'eq? '(A -> A -> Bool)))))
    (register-trait! 'Ord (trait-meta 'Ord '(A) (list (trait-method 'compare '(A -> A -> Nat)))))
    (register-bundle! 'Comparable (bundle-entry 'Comparable '(A) '((Eq A) (Ord A))))
    ;; Process spec with bundle in where clause
    (process-spec '(spec my-sort (List A) -> (List A) where (Comparable A)))
    (define spec (lookup-spec 'my-sort))
    (check-not-false spec)
    ;; where-constraints should be expanded to flat traits, not the bundle
    (check-equal? (spec-entry-where-constraints spec) '((Eq A) (Ord A)))))

;; ========================================
;; E2E Tests via run-ns
;; ========================================

(test-case "e2e/bundle-in-spec+defn-with-auto-resolution"
  ;; Use bundle in spec+defn with auto-resolution
  ;; Import Eq from library, define bundle inline, use in spec+defn
  (define results (run-ns
    (string-append
      "(ns bundle-test-1)\n"
      "(require [prologos::core::eq-trait :refer [Eq Eq-eq? eq-neq]])\n"
      "(bundle Eqable := (Eq))\n"
      "(spec my-eq A A -> Bool where (Eqable A))\n"
      "(defn my-eq [x y] where (Eqable A)\n"
      "  (eq? x y))\n"
      "(eval (my-eq zero zero))\n")))
  (define result-strings (filter string? results))
  (check-true (not (null? result-strings))
              (format "Expected string results, got: ~a" results))
  (check-true (string-contains? (last result-strings) "true")
              (format "Expected true in: ~a" (last result-strings))))

(test-case "e2e/flat-where-unchanged"
  ;; Backward compat: flat `where (Eq A)` without bundles still works
  (define results (run-ns
    (string-append
      "(ns bundle-test-2)\n"
      "(require [prologos::core::eq-trait :refer [Eq Eq-eq? eq-neq]])\n"
      "(spec flat-eq A A -> Bool where (Eq A))\n"
      "(defn flat-eq [x y] where (Eq A)\n"
      "  (eq? x y))\n"
      "(eval (flat-eq zero zero))\n")))
  (define result-strings (filter string? results))
  (check-true (not (null? result-strings))
              (format "Expected string results, got: ~a" results))
  (check-true (string-contains? (last result-strings) "true")
              (format "Expected true in: ~a" (last result-strings))))

(test-case "e2e/private-bundle-not-exported"
  ;; bundle- should not be auto-exported (register only, no auto-export-name!)
  ;; We can't directly test export visibility, but we can verify the bundle-
  ;; is still registered and usable within the same module
  (define results (run-ns
    (string-append
      "(ns bundle-test-3)\n"
      "(require [prologos::core::eq-trait :refer [Eq Eq-eq? eq-neq]])\n"
      "(bundle- PrivEq := (Eq))\n"
      "(spec priv-eq A A -> Bool where (PrivEq A))\n"
      "(defn priv-eq [x y] where (PrivEq A)\n"
      "  (eq? x y))\n"
      "(eval (priv-eq zero zero))\n")))
  (define result-strings (filter string? results))
  (check-true (not (null? result-strings))
              (format "Expected string results, got: ~a" results))
  (check-true (string-contains? (last result-strings) "true")
              (format "Expected true in: ~a" (last result-strings))))

(test-case "e2e/dedup-in-practice"
  ;; where (Eqable A) (Eq A) → single Eq dict, not two
  ;; Eqable = (Eq), so (Eqable A) (Eq A) → (Eq A) after dedup
  (define results (run-ns
    (string-append
      "(ns bundle-test-4)\n"
      "(require [prologos::core::eq-trait :refer [Eq Eq-eq? eq-neq]])\n"
      "(bundle Eqable := (Eq))\n"
      "(spec dedup-eq A A -> Bool where (Eqable A) (Eq A))\n"
      "(defn dedup-eq [x y] where (Eqable A) (Eq A)\n"
      "  (eq? x y))\n"
      "(eval (dedup-eq zero zero))\n")))
  (define result-strings (filter string? results))
  (check-true (not (null? result-strings))
              (format "Expected string results, got: ~a" results))
  (check-true (string-contains? (last result-strings) "true")
              (format "Expected true in: ~a" (last result-strings))))
