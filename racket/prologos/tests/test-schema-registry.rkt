#lang racket/base

;;;
;;; Tests for Phase 1a: Schema Field Registry
;;; Verifies schema-field parsing, schema registration, and lookup.
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
         "../multi-dispatch.rkt")

;; ========================================
;; Unit tests: parse-schema-fields
;; ========================================

(test-case "schema-registry/parse-empty-fields"
  (define-values (fields _subs) (parse-schema-fields '() #f))
  (check-equal? fields '()))

(test-case "schema-registry/parse-single-field"
  (define-values (fields _subs) (parse-schema-fields '(:name String) #f))
  (check-equal? (length fields) 1)
  (check-equal? (schema-field-keyword (car fields)) 'name)
  (check-equal? (schema-field-type-datum (car fields)) 'String))

(test-case "schema-registry/parse-multiple-fields"
  (define-values (fields _subs) (parse-schema-fields '(:name String :age Nat :active Bool) #f))
  (check-equal? (length fields) 3)
  (check-equal? (schema-field-keyword (first fields)) 'name)
  (check-equal? (schema-field-type-datum (first fields)) 'String)
  (check-equal? (schema-field-keyword (second fields)) 'age)
  (check-equal? (schema-field-type-datum (second fields)) 'Nat)
  (check-equal? (schema-field-keyword (third fields)) 'active)
  (check-equal? (schema-field-type-datum (third fields)) 'Bool))

(test-case "schema-registry/parse-compound-type"
  ;; (List Nat) as a compound type datum
  (define-values (fields _subs) (parse-schema-fields '(:items (List Nat)) #f))
  (check-equal? (length fields) 1)
  (check-equal? (schema-field-keyword (car fields)) 'items)
  (check-equal? (schema-field-type-datum (car fields)) '(List Nat)))

(test-case "schema-registry/parse-error-missing-type"
  (check-exn exn:fail?
             (lambda () (parse-schema-fields '(:name) #f))))

(test-case "schema-registry/parse-error-non-keyword"
  (check-exn exn:fail?
             (lambda () (parse-schema-fields '(name String) #f))))

;; ========================================
;; Unit tests: register + lookup
;; ========================================

(test-case "schema-registry/register-and-lookup"
  (parameterize ([current-schema-registry (hasheq)])
    (define fields (list (schema-field 'name 'String #f #f)
                         (schema-field 'age 'Nat #f #f)))
    (define entry (schema-entry 'User fields #f #f))
    (register-schema! 'User entry)
    (define looked-up (lookup-schema 'User))
    (check-true (schema-entry? looked-up))
    (check-equal? (schema-entry-name looked-up) 'User)
    (check-equal? (length (schema-entry-fields looked-up)) 2)
    (check-false (schema-entry-closed? looked-up))))

(test-case "schema-registry/lookup-missing"
  (parameterize ([current-schema-registry (hasheq)])
    (check-false (lookup-schema 'NonExistent))))

(test-case "schema-registry/register-multiple"
  (parameterize ([current-schema-registry (hasheq)])
    (register-schema! 'A (schema-entry 'A (list (schema-field 'x 'Nat #f #f)) #f #f))
    (register-schema! 'B (schema-entry 'B (list (schema-field 'y 'Bool #f #f)) #f #f))
    (check-true (schema-entry? (lookup-schema 'A)))
    (check-true (schema-entry? (lookup-schema 'B)))
    (check-equal? (schema-entry-name (lookup-schema 'A)) 'A)
    (check-equal? (schema-entry-name (lookup-schema 'B)) 'B)))

;; ========================================
;; Integration: schema declaration via process-string
;; ========================================

;; Shared fixture for integration tests
(define shared-preamble "(ns test :no-prelude)\n")

(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg
                shared-schema-reg)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
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
    (values (current-prelude-env)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-schema-registry))))

(define (run s)
  (parameterize ([current-prelude-env shared-global-env]
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

;; Run and return the schema registry state after processing
(define (run-with-registry s)
  (parameterize ([current-prelude-env shared-global-env]
                 [current-ns-context shared-ns-context]
                 [current-module-registry shared-module-reg]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry shared-trait-reg]
                 [current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg]
                 [current-schema-registry (hasheq)])
    (process-string s)
    (current-schema-registry)))

(test-case "schema-registry/integration-basic"
  ;; process-string uses sexp reader, so wrap in parens
  (define reg (run-with-registry "(schema Point :x Nat :y Nat)"))
  (define entry (hash-ref reg 'Point #f))
  (check-true (schema-entry? entry))
  (check-equal? (schema-entry-name entry) 'Point)
  (define fields (schema-entry-fields entry))
  (check-equal? (length fields) 2)
  (check-equal? (schema-field-keyword (first fields)) 'x)
  (check-equal? (schema-field-type-datum (first fields)) 'Nat)
  (check-equal? (schema-field-keyword (second fields)) 'y)
  (check-equal? (schema-field-type-datum (second fields)) 'Nat))

(test-case "schema-registry/integration-string-types"
  (define reg (run-with-registry "(schema User :name String :email String :age Nat)"))
  (define entry (hash-ref reg 'User #f))
  (check-true (schema-entry? entry))
  (check-equal? (length (schema-entry-fields entry)) 3)
  (check-equal? (schema-field-keyword (third (schema-entry-fields entry))) 'age)
  (check-equal? (schema-field-type-datum (third (schema-entry-fields entry))) 'Nat))

(test-case "schema-registry/integration-compound-types"
  ;; Schema with compound (multi-word) type datums
  (define reg (run-with-registry "(schema Config :items (List Nat) :meta (Map Keyword String))"))
  (define entry (hash-ref reg 'Config #f))
  (check-true (schema-entry? entry))
  (check-equal? (length (schema-entry-fields entry)) 2)
  (check-equal? (schema-field-keyword (first (schema-entry-fields entry))) 'items)
  (check-equal? (schema-field-type-datum (first (schema-entry-fields entry))) '(List Nat))
  (check-equal? (schema-field-keyword (second (schema-entry-fields entry))) 'meta)
  (check-equal? (schema-field-type-datum (second (schema-entry-fields entry))) '(Map Keyword String)))
