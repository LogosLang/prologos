#lang racket/base

;;;
;;; Tests for Phase 1c: Schema End-to-End Integration
;;; Full round-trip: declare schema, construct value, dot-access, type in specs.
;;; Uses process-string with shared fixture (prelude-loaded env).
;;;

(require rackunit
         racket/list
         racket/string
         "test-support.rkt"
         "../macros.rkt"
         "../prelude.rkt"
         "../syntax.rkt"
         "../errors.rkt"
         "../metavar-store.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../namespace.rkt"
         "../multi-dispatch.rkt")

;; ========================================
;; Shared Fixture (modules loaded once)
;; ========================================

(define shared-preamble "(ns test)\n")

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

(define (check-no-errors results)
  (for ([r results] [i (in-naturals)])
    (check-false (prologos-error? r)
                 (format "Result ~a was an error: ~v" i r))))

;; ========================================
;; 1. Full round-trip: schema → construct → access
;; ========================================

(test-case "schema-e2e/round-trip-nat-fields"
  ;; Declare Point, construct, access both fields
  (define results
    (run (string-append
          "(schema Point :x Nat :y Nat)\n"
          "(def p : Point (the Point ($brace-params :x 1N :y 2N)))\n"
          "(infer (map-get p :x))\n"
          "(infer (map-get p :y))")))
  (check-no-errors results)
  ;; Last two results should be Nat types
  (define r-x (third results))
  (define r-y (fourth results))
  (check-true (string? r-x))
  (check-contains r-x "Nat")
  (check-true (string? r-y))
  (check-contains r-y "Nat"))

(test-case "schema-e2e/round-trip-mixed-types"
  ;; Schema with String and Nat fields
  (define results
    (run (string-append
          "(schema User :name String :age Nat)\n"
          "(def u : User (the User ($brace-params :name \"alice\" :age 30N)))\n"
          "(infer (map-get u :name))\n"
          "(infer (map-get u :age))")))
  (check-no-errors results)
  (define r-name (third results))
  (define r-age (fourth results))
  (check-true (string? r-name))
  (check-contains r-name "String")
  (check-true (string? r-age))
  (check-contains r-age "Nat"))

;; ========================================
;; 2. Schema in spec type position
;; ========================================

(test-case "schema-e2e/spec-with-schema-type"
  ;; spec using schema name as parameter type — should register without error
  (define results
    (run (string-append
          "(schema Config :port Nat :host String)\n"
          "(spec get-port : Config -> Nat)")))
  (check-no-errors results))

;; ========================================
;; 3. Schema construction sugar
;; ========================================

(test-case "schema-e2e/construction-sugar"
  ;; SchemaName {fields...} should be rewritten to (the SchemaName {fields...})
  (define result
    (run-last (string-append
               "(schema Point :x Nat :y Nat)\n"
               "(check (Point ($brace-params :x 1N :y 2N)) : Point)")))
  (check-true (string? result) (format "Expected string, got ~v" result))
  (check-true (or (string-contains? result "OK") (string-contains? result "#t"))
              (format "Expected OK or #t, got ~s" result)))

;; ========================================
;; 4. Multiple schemas in same program
;; ========================================

(test-case "schema-e2e/multiple-schemas"
  ;; Define two schemas, construct values of each, check types
  (define results
    (run (string-append
          "(schema Point :x Nat :y Nat)\n"
          "(schema Color :r Nat :g Nat :b Nat)\n"
          "(def p : Point (the Point ($brace-params :x 1N :y 2N)))\n"
          "(def c : Color (the Color ($brace-params :r 255N :g 128N :b 0N)))\n"
          "(infer p)\n"
          "(infer c)")))
  (check-no-errors results)
  ;; (infer p) should say Point, (infer c) should say Color
  (define r-p (fifth results))
  (define r-c (sixth results))
  (check-true (string? r-p))
  (check-contains r-p "Point")
  (check-true (string? r-c))
  (check-contains r-c "Color"))

;; ========================================
;; 5. Open schema: extra keys accepted
;; ========================================

(test-case "schema-e2e/open-extra-keys"
  ;; Extra keys beyond declared should be accepted (open by default)
  (define result
    (run-last (string-append
               "(schema Point :x Nat :y Nat)\n"
               "(check (the Point ($brace-params :x 1N :y 2N :z 3N :w 4N)) : Point)")))
  (check-true (string? result) (format "Expected string, got ~v" result))
  (check-true (or (string-contains? result "OK") (string-contains? result "#t"))
              (format "Expected OK or #t, got ~s" result)))

;; ========================================
;; 6. Schema type preserved through def
;; ========================================

(test-case "schema-e2e/type-preserved"
  ;; After def p : Point, infer p should return Point (not Map)
  (define result
    (run-last (string-append
               "(schema Point :x Nat :y Nat)\n"
               "(def p : Point (the Point ($brace-params :x 1N :y 2N)))\n"
               "(infer p)")))
  (check-true (string? result) (format "Expected string, got ~v" result))
  (check-contains result "Point")
  ;; Should NOT say "Map" — schema types are opaque
  (check-false (string-contains? result "Map")
               (format "Expected no 'Map' in type, got ~s" result)))

;; ========================================
;; 7. Schema field type mismatch
;; ========================================

(test-case "schema-e2e/field-type-mismatch"
  ;; Providing Bool where Nat expected should fail
  (define result
    (run-last (string-append
               "(schema Counter :count Nat :active Bool)\n"
               "(check (the Counter ($brace-params :count true :active true)) : Counter)")))
  ;; Should be a type error (struct or string)
  (check-true (or (prologos-error? result)
                  (and (string? result)
                       (or (string-contains? result "#f")
                           (string-contains? result "error")
                           (string-contains? result "mismatch"))))
              (format "Expected type error, got ~v" result)))

;; ========================================
;; 8. Undeclared field access produces error
;; ========================================

(test-case "schema-e2e/undeclared-field-access"
  ;; Accessing a field not in the schema should error
  (define result
    (run-last (string-append
               "(schema Point :x Nat :y Nat)\n"
               "(def p : Point (the Point ($brace-params :x 1N :y 2N)))\n"
               "(infer (map-get p :z))")))
  (check-true (or (prologos-error? result)
                  (and (string? result)
                       (or (string-contains? result "error")
                           (string-contains? result "Error"))))
              (format "Expected error for undeclared field :z, got ~v" result)))

;; ========================================
;; 9. Schema with Bool field
;; ========================================

(test-case "schema-e2e/bool-field"
  ;; Schema with Bool field — construct and infer field type
  (define result
    (run-last (string-append
               "(schema Feature :enabled Bool :name String)\n"
               "(def f : Feature (the Feature ($brace-params :enabled true :name \"dark-mode\")))\n"
               "(infer (map-get f :enabled))")))
  (check-true (string? result) (format "Expected string, got ~v" result))
  (check-contains result "Bool"))

;; ========================================
;; 10. Schema with Keyword field
;; ========================================

(test-case "schema-e2e/keyword-field"
  ;; Schema with Keyword field
  (define result
    (run-last (string-append
               "(schema Tag :kind Keyword :value Nat)\n"
               "(def t : Tag (the Tag ($brace-params :kind :priority :value 5N)))\n"
               "(infer (map-get t :kind))")))
  (check-true (string? result) (format "Expected string, got ~v" result))
  (check-contains result "Keyword"))
