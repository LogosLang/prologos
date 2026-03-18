#lang racket/base

;;;
;;; Tests for Phase 3a: HasMethod constraint + projection
;;; Verifies: spec :over/:method parsing, HasMethod constraint registration,
;;; resolve-hasmethod-constraints! dispatch, project-method, end-to-end.
;;;

(require rackunit
         racket/list
         racket/string
         racket/port
         "test-support.rkt"
         "../macros.rkt"
         "../prelude.rkt"
         "../syntax.rkt"
         "../errors.rkt"
         "../metavar-store.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../namespace.rkt"
         "../trait-resolution.rkt"
         "../zonk.rkt")

;; ========================================
;; Shared Fixture (prelude loaded once)
;; ========================================

(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg
                shared-bundle-reg)
  (parameterize ([current-global-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
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
    (process-string "(ns test-hasmethod)")
    (values (current-global-env)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-bundle-registry))))

;; Run sexp code using shared environment
(define (run s)
  (parameterize ([current-global-env shared-global-env]
                 [current-ns-context shared-ns-context]
                 [current-module-registry shared-module-reg]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry shared-trait-reg]
                 [current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg]
                 [current-bundle-registry shared-bundle-reg])
    (process-string s)))

(define (run-last s) (last (run s)))

;; ========================================
;; A. Unit tests: trait-expr->name
;; ========================================

(test-case "trait-expr->name: tycon → name"
  (check-equal? (trait-expr->name (expr-tycon 'Eq)) 'Eq)
  (check-equal? (trait-expr->name (expr-tycon 'Ord)) 'Ord))

(test-case "trait-expr->name: fvar → stripped name"
  (check-equal? (trait-expr->name (expr-fvar 'Eq)) 'Eq)
  (check-equal? (trait-expr->name (expr-fvar 'ns::Eq)) 'Eq))

(test-case "trait-expr->name: non-name expr → #f"
  (check-false (trait-expr->name (expr-Nat)))
  (check-false (trait-expr->name (expr-app (expr-fvar 'f) (expr-Nat)))))

;; ========================================
;; B. Unit tests: project-method
;; ========================================

(test-case "project-method: single-method trait → identity"
  (parameterize ([current-trait-registry shared-trait-reg])
    (define tm (lookup-trait 'Eq))
    (check-true (and tm #t))
    (define dict (expr-fvar 'my-dict))
    ;; Eq has 1 method (eq?) → projection is identity
    (define projected (project-method dict tm 0))
    (check-equal? projected dict)))

(test-case "project-method: multi-method trait → fst/snd projection"
  ;; Create a synthetic 3-method trait-meta for testing
  (define tm (trait-meta 'TestTrait '()
               (list (trait-method 'method-a '())
                     (trait-method 'method-b '())
                     (trait-method 'method-c '()))
               (hasheq)))
  (define dict (expr-fvar 'test-dict))
  ;; Method 0 → (fst dict)
  (check-equal? (project-method dict tm 0) (expr-fst dict))
  ;; Method 1 → (fst (snd dict))
  (check-equal? (project-method dict tm 1) (expr-fst (expr-snd dict)))
  ;; Method 2 (last) → (snd (snd dict))
  (check-equal? (project-method dict tm 2) (expr-snd (expr-snd dict))))

;; ========================================
;; C. Spec parsing: :over and :method (sexp mode uses $brace-params wrapper)
;; ========================================

(test-case "spec with :over and :method parses without error"
  (check-not-exn
    (lambda ()
      (run "(spec apply-eq {A : Type} (P A) A A -> Bool ($brace-params :over P :method P eq? : A A -> Bool))"))))

(test-case "spec :over/:method stores where-constraints with HasMethod marker"
  (run "(spec test-hm-spec {A : Type} (P A) A A -> Bool ($brace-params :over P :method P eq? : A A -> Bool))")
  (define entry (lookup-spec 'test-hm-spec))
  (check-true (and entry (spec-entry? entry)))
  (define wc (spec-entry-where-constraints entry))
  ;; Should have exactly 1 HasMethod marker
  (check-equal? (length wc) 1)
  (define hm (car wc))
  (check-equal? (car hm) 'HasMethod)
  (check-equal? (cadr hm) 'P)
  (check-equal? (caddr hm) 'eq?))

(test-case "spec :over adds P to implicit binders"
  (run "(spec test-hm-binders {A : Type} (P A) A A -> Bool ($brace-params :over P :method P eq? : A A -> Bool))")
  (define entry (lookup-spec 'test-hm-binders))
  (check-true (and entry (spec-entry? entry)))
  (define ib (spec-entry-implicit-binders entry))
  ;; Should have P and A as implicit binders
  (check-true (>= (length ib) 2))
  ;; P should be first (prepended by :over)
  (check-equal? (car (car ib)) 'P))

;; ========================================
;; D. End-to-end: single-method trait (Eq)
;; ========================================

(test-case "HasMethod end-to-end: apply-eq with Eq dict resolves correctly"
  ;; Define spec + defn + call in single run (global-env is functional, doesn't persist between run calls)
  ;; Nat--Eq--dict is the Eq implementation dictionary for Nat from the prelude
  (define result
    (run-last (string-append
      "(spec apply-eq2 {A : Type} (P A) A A -> Bool ($brace-params :over P :method P eq? : A A -> Bool))"
      "(defn apply-eq2 [dict x y] [eq? x y])"
      "(apply-eq2 Nat--Eq--dict 1N 2N)")))
  (check-true (string? result)
              (format "Expected string result, got: ~a" result))
  (check-true (string-contains? result "false")
              (format "Expected 'false' in result, got: ~a" result)))

(test-case "HasMethod end-to-end: apply-eq with same args → true"
  (define result
    (run-last (string-append
      "(spec apply-eq3 {A : Type} (P A) A A -> Bool ($brace-params :over P :method P eq? : A A -> Bool))"
      "(defn apply-eq3 [dict x y] [eq? x y])"
      "(apply-eq3 Nat--Eq--dict 3N 3N)")))
  (check-true (string? result)
              (format "Expected string result, got: ~a" result))
  (check-true (string-contains? result "true")
              (format "Expected 'true' in result, got: ~a" result)))
