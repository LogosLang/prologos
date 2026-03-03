#lang racket/base

;;;
;;; Tests for Phase 1b: Schema as Named Type
;;; Verifies schema name as (Type 0), construction checking against schema,
;;; dot-access returning declared field types, and error cases.
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
         "../multi-dispatch.rkt"
         (only-in "../typing-core.rkt" schema-field-type->expr schema-lookup-field))

;; ========================================
;; Shared Fixture (modules loaded once)
;; ========================================

(define shared-preamble
  "(ns test)
")

(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg
                shared-schema-reg)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 [current-multi-defn-registry (current-multi-defn-registry)]
                 [current-spec-store (hasheq)]
                 [current-schema-registry (hasheq)])
    (install-module-loader!)
    (process-string shared-preamble)
    (values (current-global-env)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-schema-registry))))

(define (run s)
  (parameterize ([current-global-env shared-global-env]
                 [current-ns-context shared-ns-context]
                 [current-module-registry shared-module-reg]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry shared-trait-reg]
                 [current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg]
                 [current-schema-registry shared-schema-reg])
    (process-string s)))

(define (run-last s) (last (run s)))

(define (check-contains actual substr [msg #f])
  (check-true (string-contains? actual substr)
              (or msg (format "Expected ~s to contain ~s" actual substr))))

(define (check-ok-or-true result)
  (check-true (string? result) (format "Expected string, got ~v" result))
  (check-true (or (string-contains? result "#t") (string-contains? result "OK"))
              (format "Expected success (#t or OK), got ~s" result)))

;; ========================================
;; 1. Schema name is (Type 0)
;; ========================================

(test-case "schema-types/name-is-type"
  (define result (run-last "(schema Point :x Nat :y Nat)\n(infer Point)"))
  (check-true (string? result) (format "Expected string, got ~v" result))
  (check-contains result "Type"))

;; ========================================
;; 2. Schema in spec type positions
;; ========================================

(test-case "schema-types/in-spec-type"
  ;; spec can use schema name as a type — verify no errors
  ;; spec declarations are silent (no output), so schema def is the only result
  (define results (run "(schema Point :x Nat :y Nat)\n(spec get-x : Point -> Nat)"))
  ;; At least the schema def produced output; spec may be silent
  (check-true (>= (length results) 1))
  (check-true (string? (first results)))
  (check-contains (first results) "Point")
  ;; No errors in any result
  (for ([r results])
    (check-false (prologos-error? r)
                 (format "Unexpected error: ~v" r))))

;; ========================================
;; 3. Construction checking: (check expr : SchemaType)
;; ========================================

(test-case "schema-types/check-map-against-schema"
  ;; (check (the Point {:x 1N :y 2N}) : Point) should succeed
  (define result
    (run-last "(schema Point :x Nat :y Nat)\n(check (the Point ($brace-params :x 1N :y 2N)) : Point)"))
  (check-ok-or-true result))

(test-case "schema-types/check-wrong-field-type"
  ;; Providing a String where Nat is expected should fail
  (define result
    (run-last "(schema Point :x Nat :y Nat)\n(check (the Point ($brace-params :x \"bad\" :y 2N)) : Point)"))
  ;; Should be an error (struct or string with error/mismatch/#f)
  (check-true (or (prologos-error? result)
                  (and (string? result)
                       (or (string-contains? result "#f")
                           (string-contains? result "error")
                           (string-contains? result "mismatch"))))
              (format "Expected type error for wrong field type, got ~v" result)))

(test-case "schema-types/check-open-extra-keys"
  ;; Extra keys should be accepted (schema is open by default)
  (define result
    (run-last "(schema Point :x Nat :y Nat)\n(check (the Point ($brace-params :x 1N :y 2N :z 3N)) : Point)"))
  (check-ok-or-true result))

(test-case "schema-types/construct-sugar"
  ;; Point {:x 1N :y 2N} → preparse rewrites to (the Point {:x 1N :y 2N})
  (define result
    (run-last "(schema Point :x Nat :y Nat)\n(check (Point ($brace-params :x 1N :y 2N)) : Point)"))
  (check-ok-or-true result))

;; ========================================
;; 4. Def with schema type + dot-access
;; ========================================

(test-case "schema-types/def-schema-typed"
  ;; def p : Point (the Point {...})
  (define result
    (run-last "(schema Point :x Nat :y Nat)\n(def p : Point (the Point ($brace-params :x 1N :y 2N)))\n(infer p)"))
  (check-true (string? result) (format "Expected string, got ~v" result))
  (check-contains result "Point"))

(test-case "schema-types/dot-access-nat"
  ;; p.x (map-get p :x) should have type Nat
  (define result
    (run-last "(schema Point :x Nat :y Nat)\n(def p : Point (the Point ($brace-params :x 1N :y 2N)))\n(infer (map-get p :x))"))
  (check-true (string? result) (format "Expected string, got ~v" result))
  (check-contains result "Nat"))

(test-case "schema-types/dot-access-string"
  ;; user.name should have type String
  (define result
    (run-last "(schema User :name String :age Nat)\n(def u : User (the User ($brace-params :name \"alice\" :age 30N)))\n(infer (map-get u :name))"))
  (check-true (string? result) (format "Expected string, got ~v" result))
  (check-contains result "String"))

(test-case "schema-types/dot-access-second-field"
  ;; user.age should have type Nat
  (define result
    (run-last "(schema User :name String :age Nat)\n(def u : User (the User ($brace-params :name \"alice\" :age 30N)))\n(infer (map-get u :age))"))
  (check-true (string? result) (format "Expected string, got ~v" result))
  (check-contains result "Nat"))

;; ========================================
;; 5. Error: access undeclared field
;; ========================================

(test-case "schema-types/undeclared-field-errors"
  ;; Accessing field not in schema should produce an error
  (define result
    (run-last "(schema Point :x Nat :y Nat)\n(def p : Point (the Point ($brace-params :x 1N :y 2N)))\n(infer (map-get p :z))"))
  (check-true (or (prologos-error? result)
                  (and (string? result)
                       (or (string-contains? result "error")
                           (string-contains? result "Error"))))
              (format "Expected error for undeclared field, got ~v" result)))

;; ========================================
;; 6. schema-field-type->expr helper (unit tests)
;; ========================================

(test-case "schema-types/field-type-helper-builtins"
  (check-true (expr-Nat? (schema-field-type->expr 'Nat)))
  (check-true (expr-Int? (schema-field-type->expr 'Int)))
  (check-true (expr-Rat? (schema-field-type->expr 'Rat)))
  (check-true (expr-Bool? (schema-field-type->expr 'Bool)))
  (check-true (expr-String? (schema-field-type->expr 'String)))
  (check-true (expr-Char? (schema-field-type->expr 'Char)))
  (check-true (expr-Keyword? (schema-field-type->expr 'Keyword))))

(test-case "schema-types/field-type-helper-user-types"
  (define result (schema-field-type->expr 'Address))
  (check-true (expr-fvar? result))
  (check-equal? (expr-fvar-name result) 'Address))

(test-case "schema-types/field-type-helper-compound"
  (define result (schema-field-type->expr '(List Nat)))
  (check-true (expr-app? result))
  (check-true (expr-fvar? (expr-app-func result)))
  (check-true (expr-Nat? (expr-app-arg result))))
