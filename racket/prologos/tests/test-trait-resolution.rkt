#lang racket/base

;;;
;;; Tests for implicit trait resolution (Phases B + C)
;;; Phase B: Parametric instance registry
;;; Phase C: Trait constraint resolution
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
         "../namespace.rkt"
         "../trait-resolution.rkt")

;; ========================================
;; Helpers
;; ========================================

;; process-string uses the SEXP reader — all input must be parenthesized.
;; For WS-mode testing, use run-ns which loads .prologos library files
;; via process-file (which auto-detects WS mode from .prologos extension).

(define (run s)
  (parameterize ([current-global-env (hasheq)])
    (process-string s)))

(define (run-first s) (car (run s)))
(define (run-last s) (last (run s)))

(define here (path->string (path-only (syntax-source #'here))))
(define lib-dir (simplify-path (build-path here ".." "lib")))

(define (run-ns s)
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
    (process-string s)))

(define (run-ns-last s) (last (run-ns s)))

;; ========================================
;; Phase B.1: Parametric impl registry unit tests
;; ========================================

(test-case "param-impl-registry/roundtrip"
  (parameterize ([current-param-impl-registry (hasheq)])
    ;; Initially empty
    (check-equal? (lookup-param-impls 'Eq) '())
    ;; Register one
    (register-param-impl! 'Eq
      (param-impl-entry 'Eq '((List A)) '(A) 'List-A--Eq--dict '((Eq A))))
    ;; Lookup returns it
    (define impls (lookup-param-impls 'Eq))
    (check-equal? (length impls) 1)
    (check-equal? (param-impl-entry-trait-name (car impls)) 'Eq)
    (check-equal? (param-impl-entry-type-pattern (car impls)) '((List A)))
    (check-equal? (param-impl-entry-pattern-vars (car impls)) '(A))
    (check-equal? (param-impl-entry-dict-name (car impls)) 'List-A--Eq--dict)
    (check-equal? (param-impl-entry-where-constraints (car impls)) '((Eq A)))
    ;; Different trait still empty
    (check-equal? (lookup-param-impls 'Ord) '())))

(test-case "param-impl-registry/multiple-entries"
  (parameterize ([current-param-impl-registry (hasheq)])
    (register-param-impl! 'Eq
      (param-impl-entry 'Eq '((List A)) '(A) 'List-A--Eq--dict '((Eq A))))
    (register-param-impl! 'Eq
      (param-impl-entry 'Eq '((Option A)) '(A) 'Option-A--Eq--dict '((Eq A))))
    (define impls (lookup-param-impls 'Eq))
    (check-equal? (length impls) 2)))

;; ========================================
;; Phase B.2-B.3: Parametric impl via process-impl (macro-level)
;; ========================================

(test-case "param-impl/monomorphic-impl-does-not-register-in-param-registry"
  ;; Define trait + monomorphic impl, verify param registry stays empty.
  ;; Uses process-trait/process-impl directly with s-expression datums
  ;; (like test-trait-impl.rkt does for macro-level tests).
  (parameterize ([current-trait-registry (hasheq)]
                 [current-impl-registry (hasheq)]
                 [current-param-impl-registry (hasheq)]
                 [current-preparse-registry (current-preparse-registry)])
    ;; Define Eq trait
    (process-trait '(trait (Eq (A : (Type 0))) (eq? : A -> A -> Bool)))
    ;; Define monomorphic impl for Nat
    (process-impl '(impl Eq Nat (defn eq? [x : Nat, y : Nat] : Bool
                     (natrec x (natrec y true (fn [_ _] false)) (fn [k rec] (natrec y false (fn [j _] (rec j))))))))
    ;; Verify monomorphic impl registered in concrete registry
    (check-not-false (lookup-impl 'Nat--Eq))
    ;; Verify param registry still empty
    (check-equal? (lookup-param-impls 'Eq) '())))

(test-case "param-impl/where-in-impl-registers-in-param-registry"
  ;; Define trait + parametric impl with where, verify param registry.
  (parameterize ([current-trait-registry (hasheq)]
                 [current-impl-registry (hasheq)]
                 [current-param-impl-registry (hasheq)]
                 [current-preparse-registry (current-preparse-registry)])
    ;; Define Eq trait
    (process-trait '(trait (Eq (A : (Type 0))) (eq? : A -> A -> Bool)))
    ;; Define parametric impl: impl Eq (List A) where (Eq A)
    (define defs
      (process-impl '(impl Eq (List A) where (Eq A)
                       (defn eq? [xs : (List A), ys : (List A)] : Bool
                         true))))   ;; placeholder body
    ;; Verify registered in param registry
    (define impls (lookup-param-impls 'Eq))
    (check-equal? (length impls) 1)
    (check-equal? (param-impl-entry-trait-name (car impls)) 'Eq)
    (check-equal? (param-impl-entry-type-pattern (car impls)) '((List A)))
    (check-equal? (param-impl-entry-pattern-vars (car impls)) '(A))
    (check-equal? (param-impl-entry-where-constraints (car impls)) '((Eq A)))
    ;; Verify NOT registered in concrete registry (parametric impls are separate)
    (check-equal? (lookup-impl 'List-A--Eq) #f)))

(test-case "param-impl/generated-dict-and-method-names"
  ;; Verify generated names for parametric impl
  (parameterize ([current-trait-registry (hasheq)]
                 [current-impl-registry (hasheq)]
                 [current-param-impl-registry (hasheq)]
                 [current-preparse-registry (current-preparse-registry)])
    (process-trait '(trait (Eq (A : (Type 0))) (eq? : A -> A -> Bool)))
    (define defs
      (process-impl '(impl Eq (List A) where (Eq A)
                       (defn eq? [xs : (List A), ys : (List A)] : Bool
                         true))))
    ;; Should generate method helper + dict alias
    (check-true (>= (length defs) 2))
    ;; First should be the method helper defn
    (define helper-defn (car defs))
    (check-equal? (car helper-defn) 'defn)
    ;; Method helper name: List-A--Eq--eq?
    (check-equal? (cadr helper-defn) 'List-A--Eq--eq?)
    ;; Dict name in param registry
    (define impls (lookup-param-impls 'Eq))
    (check-equal? (param-impl-entry-dict-name (car impls)) 'List-A--Eq--dict)))

(test-case "param-impl/constraint-params-prepended-to-method"
  ;; Verify constraint dict params are injected into the method helper
  (parameterize ([current-trait-registry (hasheq)]
                 [current-impl-registry (hasheq)]
                 [current-param-impl-registry (hasheq)]
                 [current-preparse-registry (current-preparse-registry)])
    (process-trait '(trait (Eq (A : (Type 0))) (eq? : A -> A -> Bool)))
    (define defs
      (process-impl '(impl Eq (List A) where (Eq A)
                       (defn eq? [xs : (List A), ys : (List A)] : Bool
                         true))))
    (define helper-defn (car defs))
    ;; The method helper should have constraint params prepended in the bracket
    ;; Original params: [xs : (List A), ys : (List A)]
    ;; After injection: [$Eq-A ($angle-type (Eq A)) xs : (List A), ys : (List A)]
    ;; Find the bracket (first list with symbol as first element after defn name)
    (define params-after-name (cddr helper-defn))
    (define bracket (findf list? params-after-name))
    (check-not-false bracket)
    ;; The bracket should start with constraint param: $Eq-A
    (check-equal? (car bracket) '$Eq-A)))

;; ========================================
;; Phase B.4: E2E parametric impl with explicit dict passing
;; ========================================

(test-case "param-impl/backward-compat-monomorphic"
  ;; Existing monomorphic impl still works unchanged via run-ns.
  ;; Note: process-string uses sexp reader, so input must be parenthesized.
  (define results (run-ns
    (string-append
      "(ns compat-test)\n"
      "(require [prologos.core.eq-trait :refer [Eq Eq-eq? eq-neq]])\n"
      "(eval (eq-neq Nat Nat--Eq--dict zero zero))\n")))
  ;; Filter for actual result strings (not error structs or empty)
  (define result-strings (filter string? results))
  (check-true (not (null? result-strings))
              (format "Expected string results, got: ~a" results))
  ;; eq-neq = "not equal", so (eq-neq zero zero) = false (they ARE equal)
  (check-true (string-contains? (last result-strings) "false")
              (format "Expected false (not-equal of equal values) in: ~a" result-strings)))

(test-case "param-impl/e2e-parametric-impl-defines-helper"
  ;; E2E: load Eq trait from library, define parametric impl for List with
  ;; a simple placeholder body, verify the method helper is defined and
  ;; the param registry is populated.
  ;; Note: Full match-based body requires Phase C (resolution) to work,
  ;; so we use a simple placeholder body for now.
  (define results (run-ns
    (string-append
      "(ns param-impl-test)\n"
      "(require [prologos.core.eq-trait :refer [Eq Eq-eq? nat-eq]])\n"
      "(require [prologos.data.bool :refer [not]])\n"
      "(impl Eq (List A) where (Eq A)\n"
      "  (defn eq? [xs : (List A), ys : (List A)] : Bool\n"
      "    true))\n")))
  ;; The method helper should be defined (first result is a string)
  (define result-strings (filter string? results))
  (check-true (not (null? result-strings))
              (format "Expected at least one definition, got: ~a" results))
  ;; First result should mention List-A--Eq--eq? definition
  (check-true (string-contains? (car result-strings) "List-A--Eq--eq?")
              (format "Expected List-A--Eq--eq? in: ~a" (car result-strings))))

;; ========================================
;; Phase C: Monomorphic trait constraint resolution
;; ========================================

(test-case "resolution/monomorphic-eq-nat-auto-resolves"
  ;; THE KEY TEST: Define a function with `spec ... where (Eq A)` and call without explicit dict.
  ;; `where` desugars to a leading m0 Pi binder of type (Eq A).
  ;; When called with (my-neq zero zero), the elaborator inserts 2 metas:
  ;; one for A (→Nat), one for Eq A dict.
  ;; After type-checking, resolve-trait-constraints! should solve the dict meta to Nat--Eq--dict.
  (define results (run-ns
    (string-append
      "(ns monomorphic-resolve-test)\n"
      "(require [prologos.core.eq-trait :refer [Eq Eq-eq?]])\n"
      "(require [prologos.data.bool :refer [not]])\n"
      ;; Define my-neq with where clause — dict is implicit m0 parameter
      "(spec my-neq A A -> Bool where (Eq A))\n"
      "(defn my-neq [x y]\n"
      "  (not (Eq-eq? A $Eq-A x y)))\n"
      "(eval (my-neq zero zero))\n")))
  (define result-strings (filter string? results))
  (check-true (not (null? result-strings))
              (format "Expected results, got: ~a" results))
  ;; my-neq = "not equal", so (my-neq zero zero) → false (they ARE equal)
  (check-true (string-contains? (last result-strings) "false")
              (format "Expected 'false' in: ~a" result-strings)))

(test-case "resolution/monomorphic-eq-bool-auto-resolves"
  ;; Auto-resolve Eq Bool — requires defining an Eq Bool impl since the library
  ;; only ships with Eq Nat. Define Eq Bool inline for this test.
  (define results (run-ns
    (string-append
      "(ns bool-resolve-test)\n"
      "(require [prologos.core.eq-trait :refer [Eq Eq-eq?]])\n"
      "(require [prologos.data.bool :refer [not]])\n"
      ;; Define Eq Bool impl inline (library only has Eq Nat)
      "(impl Eq Bool\n"
      "  (defn eq? [x : Bool, y : Bool] : Bool\n"
      "    (boolrec (fn [_] (boolrec (fn [_] true) false y)) (boolrec (fn [_] false) true y) x)))\n"
      "(spec my-neq A A -> Bool where (Eq A))\n"
      "(defn my-neq [x y]\n"
      "  (not (Eq-eq? A $Eq-A x y)))\n"
      "(eval (my-neq true true))\n")))
  (define result-strings (filter string? results))
  (check-true (not (null? result-strings))
              (format "Expected results, got: ~a" results))
  (check-true (string-contains? (last result-strings) "false")
              (format "Expected 'false' in: ~a" result-strings)))

(test-case "resolution/backward-compat-explicit-dict-still-works"
  ;; Explicit dict passing should still work (backward compatibility).
  ;; When user provides ALL args (including dict), implicit insertion doesn't fire.
  (define results (run-ns
    (string-append
      "(ns backward-compat-test)\n"
      "(require [prologos.core.eq-trait :refer [Eq Eq-eq? eq-neq]])\n"
      "(eval (eq-neq Nat Nat--Eq--dict zero zero))\n")))
  (define result-strings (filter string? results))
  (check-true (not (null? result-strings))
              (format "Expected results, got: ~a" results))
  (check-true (string-contains? (last result-strings) "false")
              (format "Expected 'false' in: ~a" result-strings)))

(test-case "resolution/monomorphic-eq-nat-unequal-values"
  ;; (my-neq zero (suc zero)) → true (they are NOT equal)
  (define results (run-ns
    (string-append
      "(ns eq-neq-diff-test)\n"
      "(require [prologos.core.eq-trait :refer [Eq Eq-eq?]])\n"
      "(require [prologos.data.bool :refer [not]])\n"
      "(spec my-neq A A -> Bool where (Eq A))\n"
      "(defn my-neq [x y]\n"
      "  (not (Eq-eq? A $Eq-A x y)))\n"
      "(eval (my-neq zero (suc zero)))\n")))
  (define result-strings (filter string? results))
  (check-true (not (null? result-strings))
              (format "Expected results, got: ~a" results))
  (check-true (string-contains? (last result-strings) "true")
              (format "Expected 'true' in: ~a" result-strings)))

;; ========================================
;; Resolution engine unit tests
;; ========================================

(test-case "resolution/expr->impl-key-str-basics"
  (check-equal? (expr->impl-key-str (expr-Nat)) "Nat")
  (check-equal? (expr->impl-key-str (expr-Bool)) "Bool")
  (check-equal? (expr->impl-key-str (expr-fvar 'List)) "List")
  (check-equal? (expr->impl-key-str (expr-app (expr-fvar 'List) (expr-Nat))) "List-Nat"))

(test-case "resolution/ground-expr-basics"
  (check-true (ground-expr? (expr-Nat)))
  (check-true (ground-expr? (expr-Bool)))
  (check-true (ground-expr? (expr-fvar 'foo)))
  (check-true (ground-expr? (expr-app (expr-fvar 'List) (expr-Nat))))
  ;; Unsolved meta is not ground
  (parameterize ([current-meta-store (make-hasheq)]
                 [current-constraint-store '()]
                 [current-wakeup-registry (make-hasheq)])
    (define m (fresh-meta ctx-empty (expr-hole) "test"))
    (check-false (ground-expr? m))
    ;; Solved meta is ground if solution is ground
    (solve-meta! (expr-meta-id m) (expr-Nat))
    (check-true (ground-expr? m))))

;; ========================================
;; C.5: Parametric resolution unit tests
;; ========================================

(test-case "resolution/match-type-pattern-simple"
  ;; Pattern: (List A) with pvar A, matching against (app (fvar List) Nat)
  (parameterize ([current-param-impl-registry (hasheq)])
    (define pentry
      (param-impl-entry 'Eq '((List A)) '(A) 'List-A--Eq--dict '((Eq A))))
    ;; type-args: single element [(app (fvar List) (expr-Nat))]
    (define bindings (match-type-pattern
                       (list (expr-app (expr-fvar 'List) (expr-Nat)))
                       pentry))
    (check-not-false bindings)
    (check-true (equal? (hash-ref bindings 'A) (expr-Nat)))))

(test-case "resolution/match-type-pattern-no-match"
  ;; Pattern: (List A), matching against (app (fvar Option) Nat) — should fail
  (parameterize ([current-param-impl-registry (hasheq)])
    (define pentry
      (param-impl-entry 'Eq '((List A)) '(A) 'List-A--Eq--dict '((Eq A))))
    (define bindings (match-type-pattern
                       (list (expr-app (expr-fvar 'Option) (expr-Nat)))
                       pentry))
    (check-false bindings)))

(test-case "resolution/build-parametric-dict-expr-simple"
  ;; Build dict expr for Eq (List Nat) with sub-constraint dict for Eq Nat
  (define pentry
    (param-impl-entry 'Eq '((List A)) '(A) 'List-A--Eq--dict '((Eq A))))
  (define bindings (hasheq 'A (expr-Nat)))
  (define sub-dicts (list (expr-fvar 'Nat--Eq--dict)))
  (define result (build-parametric-dict-expr pentry bindings sub-dicts))
  ;; Expected: (app (app (fvar List-A--Eq--dict) Nat) (fvar Nat--Eq--dict))
  (check-true (expr-app? result))
  (define inner (expr-app-func result))
  (check-true (expr-app? inner))
  (check-true (expr-fvar? (expr-app-func inner)))
  (check-equal? (expr-fvar-name (expr-app-func inner)) 'List-A--Eq--dict)
  (check-true (equal? (expr-app-arg inner) (expr-Nat)))
  (check-true (equal? (expr-app-arg result) (expr-fvar 'Nat--Eq--dict))))

(test-case "resolution/try-parametric-resolve-with-mono-sub-constraint"
  ;; Register a monomorphic Eq Nat impl and a parametric Eq (List A) impl.
  ;; Then try to resolve Eq (List Nat) — should find the parametric impl
  ;; and recursively resolve the Eq Nat sub-constraint.
  (parameterize ([current-impl-registry (hasheq)]
                 [current-param-impl-registry (hasheq)])
    ;; Register monomorphic Eq Nat
    (define nat-eq-entry (impl-entry 'Eq '(Nat) 'Nat--Eq--dict))
    (register-impl! 'Nat--Eq nat-eq-entry)
    ;; Register parametric Eq (List A)
    (register-param-impl! 'Eq
      (param-impl-entry 'Eq '((List A)) '(A) 'List-A--Eq--dict '((Eq A))))
    ;; Resolve Eq (List Nat)
    (define result
      (try-parametric-resolve 'Eq (list (expr-app (expr-fvar 'List) (expr-Nat)))))
    (check-not-false result)
    ;; Expected: (app (app (fvar List-A--Eq--dict) Nat) (fvar Nat--Eq--dict))
    (check-true (expr-app? result))
    (define inner (expr-app-func result))
    (check-true (expr-app? inner))
    (check-equal? (expr-fvar-name (expr-app-func inner)) 'List-A--Eq--dict)))

;; ========================================
;; C.5: E2E parametric resolution
;; ========================================

(test-case "resolution/parametric-eq-list-nat-auto-resolves"
  ;; Define Eq trait, Nat impl, parametric List impl, then call a function
  ;; with where (Eq A) passing List Nat args — should auto-resolve.
  ;; Note: The method body just returns true (placeholder) since we're testing
  ;; resolution, not the equality algorithm itself.
  (define results (run-ns
    (string-append
      "(ns parametric-resolve-test)\n"
      "(require [prologos.core.eq-trait :refer [Eq Eq-eq?]])\n"
      "(require [prologos.data.list :refer [List nil cons]])\n"
      ;; Define parametric impl: Eq (List A) where (Eq A)
      "(impl Eq (List A) where (Eq A)\n"
      "  (defn eq? [xs : (List A), ys : (List A)] : Bool\n"
      "    true))\n"  ;; placeholder body
      ;; Define a function using where (Eq A)
      "(spec list-test A A -> Bool where (Eq A))\n"
      "(defn list-test [x y]\n"
      "  (Eq-eq? A $Eq-A x y))\n"
      ;; Call with List Nat args — should resolve Eq (List Nat) parametrically
      "(eval (list-test (cons zero nil) (cons zero nil)))\n")))
  (define result-strings (filter string? results))
  (check-true (not (null? result-strings))
              (format "Expected results, got: ~a" results))
  ;; Our placeholder body always returns true
  (check-true (string-contains? (last result-strings) "true")
              (format "Expected 'true' in: ~a" result-strings)))

(test-case "resolution/try-parametric-resolve-nested"
  ;; Resolve Eq (List (List Nat)) — should resolve recursively:
  ;; Eq (List (List Nat)) → List-A--Eq--dict (List Nat) (List-A--Eq--dict Nat Nat--Eq--dict)
  (parameterize ([current-impl-registry (hasheq)]
                 [current-param-impl-registry (hasheq)])
    ;; Register monomorphic Eq Nat
    (register-impl! 'Nat--Eq (impl-entry 'Eq '(Nat) 'Nat--Eq--dict))
    ;; Register parametric Eq (List A)
    (register-param-impl! 'Eq
      (param-impl-entry 'Eq '((List A)) '(A) 'List-A--Eq--dict '((Eq A))))
    ;; Resolve Eq (List (List Nat))
    (define list-nat (expr-app (expr-fvar 'List) (expr-Nat)))
    (define list-list-nat (expr-app (expr-fvar 'List) list-nat))
    (define result
      (try-parametric-resolve 'Eq (list list-list-nat)))
    (check-not-false result)
    ;; The outer dict should be List-A--Eq--dict applied to (List Nat) and sub-dict
    (check-true (expr-app? result))))

;; ========================================
;; C.6: Error reporting for unresolved trait constraints
;; ========================================

(test-case "resolution/missing-instance-produces-no-instance-error"
  ;; Call a where-constrained function with a type that has no Eq instance.
  ;; Should produce a no-instance-error, not leave an unsolved meta.
  (define results (run-ns
    (string-append
      "(ns missing-instance-test)\n"
      "(require [prologos.core.eq-trait :refer [Eq Eq-eq?]])\n"
      "(require [prologos.data.bool :refer [not]])\n"
      "(spec my-neq A A -> Bool where (Eq A))\n"
      "(defn my-neq [x y]\n"
      "  (not (Eq-eq? A $Eq-A x y)))\n"
      ;; Posit8 has no Eq instance — should error
      "(eval (my-neq (posit8 72) (posit8 72)))\n")))
  (define last-result (last results))
  (check-true (no-instance-error? last-result)
              (format "Expected no-instance-error, got: ~a" last-result))
  (check-equal? (no-instance-error-trait-name last-result) 'Eq))

(test-case "resolution/error-format-is-helpful"
  ;; Verify the formatted error message includes trait name and type
  (define results (run-ns
    (string-append
      "(ns error-format-test)\n"
      "(require [prologos.core.eq-trait :refer [Eq Eq-eq?]])\n"
      "(require [prologos.data.bool :refer [not]])\n"
      "(spec my-neq A A -> Bool where (Eq A))\n"
      "(defn my-neq [x y]\n"
      "  (not (Eq-eq? A $Eq-A x y)))\n"
      "(eval (my-neq (posit8 72) (posit8 72)))\n")))
  (define err (last results))
  (check-true (no-instance-error? err))
  (define msg (format-error err))
  (check-true (string-contains? msg "E1004")
              (format "Expected E1004 in: ~a" msg))
  (check-true (string-contains? msg "Eq")
              (format "Expected trait name Eq in: ~a" msg)))
