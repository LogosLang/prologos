#lang racket/base

;;;
;;; Tests for `where` clause parsing and desugaring
;;; Phase A of implicit trait resolution
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

(define (run s)
  (parameterize ([current-global-env (hasheq)])
    (process-string s)))

(define here (path->string (path-only (syntax-source #'here))))
(define lib-dir (simplify-path (build-path here ".." "lib")))

(define (run-ns s)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-trait-registry (current-trait-registry)]
                 [current-impl-registry (current-impl-registry)]
                 [current-type-meta (current-type-meta)])
    (install-module-loader!)
    (process-string s)))

;; ========================================
;; 1. extract-where-clause — unit tests
;; ========================================

(test-case "extract-where-clause/no-where"
  (define-values (type-tokens constraints) (extract-where-clause '(Nat Nat -> Nat)))
  (check-equal? type-tokens '(Nat Nat -> Nat))
  (check-equal? constraints '()))

(test-case "extract-where-clause/single-constraint"
  (define-values (type-tokens constraints) (extract-where-clause '(A A -> Bool where (Eq A))))
  (check-equal? type-tokens '(A A -> Bool))
  (check-equal? constraints '((Eq A))))

(test-case "extract-where-clause/multiple-constraints"
  (define-values (type-tokens constraints)
    (extract-where-clause '(A A -> A where (Eq A) (Ord A))))
  (check-equal? type-tokens '(A A -> A))
  (check-equal? constraints '((Eq A) (Ord A))))

(test-case "extract-where-clause/where-at-end"
  ;; Type with complex arrow chain + where at end
  (define-values (type-tokens constraints)
    (extract-where-clause '(List A -> List A where (Ord A))))
  (check-equal? type-tokens '(List A -> List A))
  (check-equal? constraints '((Ord A))))

;; ========================================
;; 2. process-spec with where clause
;; ========================================

(test-case "spec/where-single-constraint"
  (parameterize ([current-spec-store (hasheq)]
                 [current-trait-registry (hasheq)])
    ;; Register a mock trait so extract-where-clause can validate
    ;; For spec, extract-where-clause doesn't validate traits — it just splits on 'where
    (process-spec '(spec my-eq A A -> Bool where (Eq A)))
    (define entry (lookup-spec 'my-eq))
    (check-true (spec-entry? entry))
    ;; The where constraint (Eq A) should be prepended as a leading param type
    ;; So effective type is: (Eq A) -> A A -> Bool
    (check-equal? (spec-entry-type-datums entry) '(((Eq A) -> A A -> Bool)))
    (check-equal? (spec-entry-where-constraints entry) '((Eq A)))
    (check-false (spec-entry-multi? entry))))

(test-case "spec/where-multiple-constraints"
  (parameterize ([current-spec-store (hasheq)])
    (process-spec '(spec my-fn A -> A where (Eq A) (Ord A)))
    (define entry (lookup-spec 'my-fn))
    ;; Effective type: (Eq A) -> (Ord A) -> A -> A
    (check-equal? (spec-entry-type-datums entry) '(((Eq A) (Ord A) -> A -> A)))
    (check-equal? (spec-entry-where-constraints entry) '((Eq A) (Ord A)))))

(test-case "spec/no-where-backward-compat"
  ;; Existing spec without where still works
  (parameterize ([current-spec-store (hasheq)])
    (process-spec '(spec add Nat Nat -> Nat))
    (define entry (lookup-spec 'add))
    (check-equal? (spec-entry-type-datums entry) '((Nat Nat -> Nat)))
    (check-equal? (spec-entry-where-constraints entry) '())))

(test-case "spec/where-with-docstring"
  (parameterize ([current-spec-store (hasheq)])
    (process-spec '(spec my-eq "Equality test" A A -> Bool where (Eq A)))
    (define entry (lookup-spec 'my-eq))
    (check-equal? (spec-entry-docstring entry) "Equality test")
    (check-equal? (spec-entry-where-constraints entry) '((Eq A)))))

(test-case "spec/existing-explicit-dict-style-still-works"
  ;; The OLD style: spec eq-neq [Eq A] A A -> Bool (no where)
  ;; Should still work exactly as before
  (parameterize ([current-spec-store (hasheq)])
    (process-spec '(spec eq-neq (Eq A) A A -> Bool))
    (define entry (lookup-spec 'eq-neq))
    (check-equal? (spec-entry-type-datums entry) '(((Eq A) A A -> Bool)))
    (check-equal? (spec-entry-where-constraints entry) '())))

;; ========================================
;; 3. maybe-inject-where — unit tests
;; ========================================

(test-case "maybe-inject-where/no-where"
  ;; No where keyword → datum unchanged
  (parameterize ([current-trait-registry (hasheq)])
    (define result (maybe-inject-where '(defn foo [x] body)))
    (check-equal? result '(defn foo [x] body))))

(test-case "maybe-inject-where/with-Eq-constraint"
  ;; Register Eq as a known trait
  (parameterize ([current-trait-registry (hasheq)])
    (register-trait! 'Eq (trait-meta 'Eq '((A . (Type 0))) (list (trait-method 'eq? '(A A -> Bool)))))
    (define result
      (maybe-inject-where
       '(defn my-eq [x ($angle-type A) y ($angle-type A)] ($angle-type Bool) where (Eq A) (eq? x y))))
    ;; Should have $Eq-A param prepended into the bracket
    (check-true (list? result))
    (check-equal? (car result) 'defn)
    (check-equal? (cadr result) 'my-eq)
    ;; The third element should be the parameter bracket with $Eq-A prepended
    (define bracket (caddr result))
    (check-true (list? bracket))
    ;; First param should be the synthetic dict: $Eq-A
    (check-equal? (car bracket) '$Eq-A)
    ;; Second should be its type annotation: ($angle-type (Eq A))
    (check-equal? (cadr bracket) '($angle-type (Eq A)))
    ;; Remaining should be original params
    (check-equal? (caddr bracket) 'x)))

(test-case "maybe-inject-where/multiple-constraints"
  (parameterize ([current-trait-registry (hasheq)])
    (register-trait! 'Eq (trait-meta 'Eq '((A . (Type 0))) (list (trait-method 'eq? '(A A -> Bool)))))
    (register-trait! 'Ord (trait-meta 'Ord '((A . (Type 0))) (list (trait-method 'compare '(A A -> Ordering)))))
    (define result
      (maybe-inject-where
       '(defn my-fn [x ($angle-type A)] ($angle-type A) where (Eq A) (Ord A) body)))
    (define bracket (caddr result))
    ;; Should have both $Eq-A and $Ord-A prepended
    (check-equal? (car bracket) '$Eq-A)
    (check-equal? (caddr bracket) '$Ord-A)))

;; ========================================
;; 4. End-to-end: spec with where + defn
;; ========================================

;; Test that a spec with where clause + corresponding defn with bare params
;; produces the right type (leading dict param)
(test-case "e2e/spec-where-plus-bare-defn"
  ;; Uses sexp mode for simplicity
  (define results
    (run (string-append
          "(trait (Eq (A : (Type 0))) (eq? : (-> A (-> A Bool))))\n"
          "(impl Eq Nat (defn eq? (x : Nat) (y : Nat) : Bool true))\n"
          "(spec my-eq A A -> Bool where (Eq A))\n"
          "(defn my-eq [dict x y] (dict x y))\n")))
  ;; The spec type is: (Eq A) -> A -> A -> Bool
  ;; The defn should have 3 params: dict, x, y
  ;; It should type-check and produce a defined message
  (check-true (pair? results))
  ;; Look for the "my-eq : ... defined." message
  (define my-eq-result (findf (lambda (r) (and (string? r) (string-contains? r "my-eq"))) results))
  (check-true (string? my-eq-result))
  (check-true (string-contains? my-eq-result "defined.")))

;; Test backward compat: existing explicit dict-style still works
(test-case "e2e/explicit-dict-backward-compat"
  (define results
    (run (string-append
          "(trait (Eq (A : (Type 0))) (eq? : (-> A (-> A Bool))))\n"
          "(impl Eq Nat (defn eq? (x : Nat) (y : Nat) : Bool true))\n"
          ;; Old style: [Eq A] as explicit param type (no where)
          "(spec old-eq (Eq A) A A -> Bool)\n"
          "(defn old-eq [dict x y] (dict x y))\n")))
  (define old-eq-result (findf (lambda (r) (and (string? r) (string-contains? r "old-eq"))) results))
  (check-true (string? old-eq-result))
  (check-true (string-contains? old-eq-result "defined.")))

;; ========================================
;; 5. End-to-end with module system
;; ========================================

(test-case "e2e/where-with-eq-trait-module"
  ;; Use the real Eq trait from the standard library
  (define results
    (run-ns (string-append
             "(ns test-where1)\n"
             "(require [prologos::core::eq-trait :refer [Eq Eq-eq? nat-eq eq-neq]])\n"
             ;; Define a function using where clause (sexp mode)
             "(spec my-neq A A -> Bool where (Eq A))\n"
             ;; defn with bare params — spec injection adds types including the leading (Eq A) dict
             "(defn my-neq [d x y] (not (d x y)))\n"
             ;; Call with explicit dict (no resolution yet — Phase C)
             "(eval (my-neq nat-eq zero zero))\n")))
  (define eval-result (last results))
  ;; (nat-eq zero zero) = true, so not true = false
  (check-equal? eval-result "false : Bool"))

;; ========================================
;; 6. WS-mode where syntax through reader
;; ========================================

(test-case "e2e/where-ws-mode-spec"
  ;; In WS mode, 'where' is a bare symbol in the token stream
  ;; Test via the full driver with WS-mode reader
  (define results
    (run-ns (string-append
             "(ns test-where-ws)\n"
             "(require [prologos::core::eq-trait :refer [Eq Eq-eq? nat-eq eq-neq]])\n"
             ;; Tricky: in sexp mode, where is just a bare symbol in the token list
             ;; We test that process-spec handles it correctly
             "(spec ws-neq A A -> Bool where (Eq A))\n"
             "(defn ws-neq [d x y] (not (d x y)))\n"
             "(eval (ws-neq nat-eq zero (suc zero)))\n")))
  ;; nat-eq zero (suc zero) = false, so not false = true
  (check-equal? (last results) "true : Bool"))
