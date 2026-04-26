#lang racket/base

;;;
;;; Tests for Phase D: Method Name Resolution in Bodies
;;; When `eq?` appears in a function body under `where (Eq A)`,
;;; resolve it to the partially-applied accessor `(Eq-eq? A $Eq-A)`.
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
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)])
    (process-string s)))

(define (run-first s) (car (run s)))
(define (run-last s) (last (run s)))

(define (run-ns s)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry])
    (install-module-loader!)
    (process-string s)))

(define (run-ns-last s) (last (run-ns s)))

;; ========================================
;; Unit tests: parse-dict-param-name
;; ========================================

(test-case "parse-dict-param-name/simple"
  ;; "$Eq-A" → (cons 'Eq '(A)) when Eq is a registered trait
  (parameterize ([current-trait-registry (hasheq)])
    (register-trait! 'Eq (trait-meta 'Eq '((A . (Type 0)))
                           (list (trait-method 'eq? '(A -> A -> Bool))) (hasheq)))
    (define parsed (parse-dict-param-name '$Eq-A))
    (check-not-false parsed)
    (check-equal? (car parsed) 'Eq)
    (check-equal? (cdr parsed) '(A))))

(test-case "parse-dict-param-name/multi-type-var"
  ;; "$Foo-A-B" → (cons 'Foo '(A B)) when Foo is a registered trait
  (parameterize ([current-trait-registry (hasheq)])
    (register-trait! 'Foo (trait-meta 'Foo '((A . (Type 0)) (B . (Type 0)))
                           (list (trait-method 'bar '(A -> B))) (hasheq)))
    (define parsed (parse-dict-param-name '$Foo-A-B))
    (check-not-false parsed)
    (check-equal? (car parsed) 'Foo)
    (check-equal? (cdr parsed) '(A B))))

(test-case "parse-dict-param-name/unknown-trait"
  ;; "$Unknown-X" → #f when no Unknown trait registered
  (parameterize ([current-trait-registry (hasheq)])
    (check-false (parse-dict-param-name '$Unknown-X))))

(test-case "parse-dict-param-name/no-type-vars"
  ;; "$Eq" with no type vars → #f (malformed)
  (parameterize ([current-trait-registry (hasheq)])
    (register-trait! 'Eq (trait-meta 'Eq '((A . (Type 0)))
                           (list (trait-method 'eq? '(A -> A -> Bool))) (hasheq)))
    (check-false (parse-dict-param-name '$Eq))))

;; ========================================
;; Unit tests: dict-param->where-entries
;; ========================================

(test-case "dict-param->where-entries/single-method"
  ;; Eq has 1 method → 1 entry with correct accessor name
  (parameterize ([current-trait-registry (hasheq)])
    (register-trait! 'Eq (trait-meta 'Eq '((A . (Type 0)))
                           (list (trait-method 'eq? '(A -> A -> Bool))) (hasheq)))
    (define entries (dict-param->where-entries '$Eq-A))
    (check-not-false entries)
    (check-equal? (length entries) 1)
    (define e (car entries))
    (check-equal? (where-method-entry-method-name e) 'eq?)
    (check-equal? (where-method-entry-accessor-name e) 'Eq-eq?)
    (check-equal? (where-method-entry-trait-name e) 'Eq)
    (check-equal? (where-method-entry-type-var-names e) '(A))
    (check-equal? (where-method-entry-dict-param-name e) '$Eq-A)))

(test-case "dict-param->where-entries/multi-method"
  ;; Mock trait with 3 methods → 3 entries
  (parameterize ([current-trait-registry (hasheq)])
    (register-trait! 'Indexed (trait-meta 'Indexed '((F . (Type 0)))
                               (list (trait-method 'get '(F -> Nat -> A))
                                     (trait-method 'set '(F -> Nat -> A -> F))
                                     (trait-method 'len '(F -> Nat))) (hasheq)))
    (define entries (dict-param->where-entries '$Indexed-F))
    (check-not-false entries)
    (check-equal? (length entries) 3)
    (check-equal? (map where-method-entry-method-name entries) '(get set len))
    (check-equal? (map where-method-entry-accessor-name entries)
                  '(Indexed-get Indexed-set Indexed-len))))

(test-case "dict-param->where-entries/unknown-trait"
  ;; Unknown trait → #f
  (parameterize ([current-trait-registry (hasheq)])
    (check-false (dict-param->where-entries '$Bogus-X))))

;; ========================================
;; Unit tests: is-dict-param-name?
;; ========================================

(test-case "is-dict-param-name?/positive"
  (check-true (is-dict-param-name? '$Eq-A))
  (check-true (is-dict-param-name? '$foo)))

(test-case "is-dict-param-name?/negative"
  (check-false (is-dict-param-name? 'x))
  (check-false (is-dict-param-name? 'Eq)))

;; ========================================
;; Unit tests: resolve-method-from-where
;; ========================================

(test-case "resolve/basic-eq?"
  ;; env: A@depth0, $Eq-A@depth1; body at depth 2
  ;; eq? → (app (app (fvar 'Eq-eq?) (bvar 1)) (bvar 0))
  (parameterize ([current-trait-registry (hasheq)])
    (register-trait! 'Eq (trait-meta 'Eq '((A . (Type 0)))
                           (list (trait-method 'eq? '(A -> A -> Bool))) (hasheq)))
    (define ctx (dict-param->where-entries '$Eq-A))
    (parameterize ([current-where-context ctx])
      (define env (list (cons '$Eq-A 1) (cons 'A 0)))
      (define result (resolve-method-from-where 'eq? env 2))
      (check-not-false result)
      ;; A is at depth 0, body at depth 2: index = 2 - 0 - 1 = 1
      ;; $Eq-A is at depth 1, body at depth 2: index = 2 - 1 - 1 = 0
      (check-equal? result
        (expr-app (expr-app (expr-fvar 'Eq-eq?) (expr-bvar 1))
                  (expr-bvar 0))))))

(test-case "resolve/not-a-method"
  ;; foo? is not a method of Eq → #f
  (parameterize ([current-trait-registry (hasheq)])
    (register-trait! 'Eq (trait-meta 'Eq '((A . (Type 0)))
                           (list (trait-method 'eq? '(A -> A -> Bool))) (hasheq)))
    (define ctx (dict-param->where-entries '$Eq-A))
    (parameterize ([current-where-context ctx])
      (define env (list (cons '$Eq-A 1) (cons 'A 0)))
      (check-false (resolve-method-from-where 'foo? env 2)))))

(test-case "resolve/no-where-context"
  ;; Empty context → #f
  (parameterize ([current-where-context '()])
    (define env (list (cons 'x 0)))
    (check-false (resolve-method-from-where 'eq? env 1))))

(test-case "resolve/multi-type-var"
  ;; Trait with 2 type params → accessor applied with both type bvars + dict
  (parameterize ([current-trait-registry (hasheq)])
    (register-trait! 'Conv (trait-meta 'Conv '((A . (Type 0)) (B . (Type 0)))
                             (list (trait-method 'convert '(A -> B))) (hasheq)))
    (define ctx (dict-param->where-entries '$Conv-A-B))
    (parameterize ([current-where-context ctx])
      ;; env: A@0, B@1, $Conv-A-B@2; body at depth 3
      (define env (list (cons '$Conv-A-B 2) (cons 'B 1) (cons 'A 0)))
      (define result (resolve-method-from-where 'convert env 3))
      (check-not-false result)
      ;; A: 3-0-1=2, B: 3-1-1=1, $Conv-A-B: 3-2-1=0
      (check-equal? result
        (expr-app
          (expr-app
            (expr-app (expr-fvar 'Conv-convert) (expr-bvar 2))
            (expr-bvar 1))
          (expr-bvar 0))))))

(test-case "resolve/ambiguous-method-error"
  ;; Two traits with same method name → E1005 error
  (parameterize ([current-trait-registry (hasheq)])
    (register-trait! 'Eq (trait-meta 'Eq '((A . (Type 0)))
                           (list (trait-method 'check '(A -> Bool))) (hasheq)))
    (register-trait! 'Validate (trait-meta 'Validate '((A . (Type 0)))
                                 (list (trait-method 'check '(A -> Bool))) (hasheq)))
    (define ctx1 (dict-param->where-entries '$Eq-A))
    (define ctx2 (dict-param->where-entries '$Validate-A))
    (parameterize ([current-where-context (append ctx1 ctx2)])
      (define env (list (cons '$Validate-A 2) (cons '$Eq-A 1) (cons 'A 0)))
      (define result (resolve-method-from-where 'check env 3))
      (check-true (ambiguous-method-error? result)))))

;; ========================================
;; E2E integration tests
;; ========================================

(test-case "e2e/eq?-in-where-body"
  ;; Define function with where (Eq A), use eq? in body.
  ;; (my-eq zero zero) → true
  (define results (run-ns
    (string-append
      "(ns method-test-1)\n"
      "(imports [prologos::core::eq :refer [Eq Eq-eq? eq-neq]])\n"
      "(spec my-eq A A -> Bool where (Eq A))\n"
      "(defn my-eq [x y] where (Eq A)\n"
      "  (eq? x y))\n"
      "(eval (my-eq zero zero))\n")))
  (define result-strings (filter string? results))
  (check-true (not (null? result-strings))
              (format "Expected string results, got: ~a" results))
  (check-true (string-contains? (last result-strings) "true")
              (format "Expected true in: ~a" (last result-strings))))

(test-case "e2e/eq?-in-where-body-unequal"
  ;; (my-eq zero (suc zero)) → false
  (define results (run-ns
    (string-append
      "(ns method-test-2)\n"
      "(imports [prologos::core::eq :refer [Eq Eq-eq? eq-neq]])\n"
      "(spec my-eq A A -> Bool where (Eq A))\n"
      "(defn my-eq [x y] where (Eq A)\n"
      "  (eq? x y))\n"
      "(eval (my-eq zero (suc zero)))\n")))
  (define result-strings (filter string? results))
  (check-true (not (null? result-strings)))
  (check-true (string-contains? (last result-strings) "false")
              (format "Expected false in: ~a" (last result-strings))))

(test-case "e2e/method-in-function-position"
  ;; eq? used as the function in application: (eq? x y)
  ;; Same as basic test but verifies function-position works.
  (define results (run-ns
    (string-append
      "(ns method-test-3)\n"
      "(imports [prologos::core::eq :refer [Eq Eq-eq?]])\n"
      "(spec check-eq A A -> Bool where (Eq A))\n"
      "(defn check-eq [x y] where (Eq A)\n"
      "  (eq? x y))\n"
      "(eval (check-eq zero zero))\n")))
  (define result-strings (filter string? results))
  (check-true (not (null? result-strings)))
  (check-true (string-contains? (last result-strings) "true")
              (format "Expected true in: ~a" (last result-strings))))

(test-case "e2e/backward-compat-accessor-still-works"
  ;; Using the explicit accessor Eq-eq? with explicit type/dict args still works
  ;; inside a where body. This tests backward compat — user can always use full form.
  (define results (run-ns
    (string-append
      "(ns method-test-4)\n"
      "(imports [prologos::core::eq :refer [Eq Eq-eq?]])\n"
      "(spec check-eq-v2 A A -> Bool where (Eq A))\n"
      "(defn check-eq-v2 [x y] where (Eq A)\n"
      "  (Eq-eq? A $Eq-A x y))\n"
      "(eval (check-eq-v2 zero zero))\n")))
  (define result-strings (filter string? results))
  (check-true (not (null? result-strings)))
  (check-true (string-contains? (last result-strings) "true")
              (format "Expected true in: ~a" (last result-strings))))

(test-case "e2e/backward-compat-explicit-dict"
  ;; Explicit dict passing still works unchanged
  (define results (run-ns
    (string-append
      "(ns method-test-5)\n"
      "(imports [prologos::core::eq :refer [Eq Eq-eq? eq-neq]])\n"
      "(eval (eq-neq Nat Nat--Eq--dict zero zero))\n")))
  (define result-strings (filter string? results))
  (check-true (not (null? result-strings)))
  (check-true (string-contains? (last result-strings) "false")
              (format "Expected false in: ~a" (last result-strings))))

(test-case "e2e/method-with-nat-args"
  ;; eq? with concrete Nat args resolves correctly
  (define results (run-ns
    (string-append
      "(ns method-test-6)\n"
      "(imports [prologos::core::eq :refer [Eq Eq-eq?]])\n"
      "(spec same? A A -> Bool where (Eq A))\n"
      "(defn same? [x y] where (Eq A)\n"
      "  (eq? x y))\n"
      "(eval (same? (suc zero) (suc zero)))\n")))
  (define result-strings (filter string? results))
  (check-true (not (null? result-strings)))
  (check-true (string-contains? (last result-strings) "true")
              (format "Expected true in: ~a" (last result-strings))))

(test-case "e2e/not-eq?-in-where-body"
  ;; Use eq? inside a not expression
  (define results (run-ns
    (string-append
      "(ns method-test-7)\n"
      "(imports [prologos::core::eq :refer [Eq Eq-eq?]])\n"
      "(imports [prologos::data::bool :refer [not]])\n"
      "(spec neq? A A -> Bool where (Eq A))\n"
      "(defn neq? [x y] where (Eq A)\n"
      "  (not (eq? x y)))\n"
      "(eval (neq? zero zero))\n")))
  (define result-strings (filter string? results))
  (check-true (not (null? result-strings)))
  (check-true (string-contains? (last result-strings) "false")
              (format "Expected false (not equal of equals) in: ~a" (last result-strings))))

(test-case "e2e/unresolved-method-error"
  ;; Bare method name without where constraint → unbound variable error
  (define results (run-ns
    (string-append
      "(ns method-test-8)\n"
      "(imports [prologos::core::eq :refer [Eq Eq-eq?]])\n"
      ;; No where clause — eq? is not in scope
      "(spec bad-fn Nat -> Bool)\n"
      "(defn bad-fn [x]\n"
      "  (eq? x x))\n")))
  ;; Should produce an error
  (define errors (filter prologos-error? results))
  (check-true (not (null? errors))
              (format "Expected an unbound variable error, got: ~a" results)))

(test-case "e2e/error-format-is-helpful"
  ;; E1005 format test
  (define err (ambiguous-method-error
                srcloc-unknown "Ambiguous method 'check'" 'check '(Eq Validate)))
  (define formatted (format-error err))
  (check-true (string-contains? formatted "E1005"))
  (check-true (string-contains? formatted "check"))
  (check-true (string-contains? formatted "Eq"))
  (check-true (string-contains? formatted "Validate")))
