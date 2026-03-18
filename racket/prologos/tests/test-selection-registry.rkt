#lang racket/base

;;;
;;; Tests for Phase 2b: Selection Registry and Elaboration
;;; Verifies selection registration, field validation, type creation,
;;; and error handling through the full process-string pipeline.
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
;; Shared Fixture
;; ========================================

(define shared-preamble "(ns test)\n")

(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg
                shared-schema-reg
                shared-selection-reg)
  (parameterize ([current-global-env (hasheq)]
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
                 [current-schema-registry (hasheq)]
                 [current-selection-registry (hasheq)])
    (install-module-loader!)
    (process-string shared-preamble)
    (values (current-global-env)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-schema-registry)
            (current-selection-registry))))

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
                 [current-schema-registry shared-schema-reg]
                 [current-selection-registry shared-selection-reg])
    (process-string s)))

(define (run-last s) (last (run s)))

(define (check-no-errors results)
  (for ([r results] [i (in-naturals)])
    (check-false (prologos-error? r)
                 (format "Result ~a was an error: ~v" i r))))

;; ========================================
;; 1. Selection registers successfully
;; ========================================

(test-case "selection-reg/basic-registration"
  (define result
    (run-last (string-append
               "(schema User :name String :age Nat)\n"
               "(selection BasicUser from User :requires [:name :age])")))
  (check-true (string? result) (format "Expected string, got ~v" result))
  (check-true (string-contains? result "selection")
              (format "Expected 'selection' in result, got ~s" result))
  (check-true (string-contains? result "BasicUser")
              (format "Expected 'BasicUser' in result, got ~s" result)))

;; ========================================
;; 2. Selection creates a type (usable with infer)
;; ========================================

(test-case "selection-reg/creates-type"
  (define result
    (run-last (string-append
               "(schema User :name String :age Nat)\n"
               "(selection BasicUser from User :requires [:name])\n"
               "(infer BasicUser)")))
  (check-true (string? result) (format "Expected string, got ~v" result))
  ;; BasicUser should be (Type 0) — same as any type name
  (check-true (string-contains? result "Type")
              (format "Expected 'Type' in result, got ~s" result)))

;; ========================================
;; 3. Selection usable in spec type position
;; ========================================

(test-case "selection-reg/in-spec"
  (define results
    (run (string-append
          "(schema User :name String :age Nat)\n"
          "(selection BasicUser from User :requires [:name])\n"
          "(spec get-name : BasicUser -> String)")))
  (check-no-errors results))

;; ========================================
;; 4. Error: schema not found
;; ========================================

(test-case "selection-reg/error-no-schema"
  (define result
    (run-last "(selection Bad from NoSuchSchema :requires [:x])"))
  (check-true (prologos-error? result)
              (format "Expected error, got ~v" result)))

;; ========================================
;; 5. Error: field not in schema
;; ========================================

(test-case "selection-reg/error-bad-field"
  (define result
    (run-last (string-append
               "(schema User :name String :age Nat)\n"
               "(selection Bad from User :requires [:name :bogus])")))
  (check-true (prologos-error? result)
              (format "Expected error, got ~v" result)))

;; ========================================
;; 6. Multiple selections from same schema
;; ========================================

(test-case "selection-reg/multiple-from-same-schema"
  (define results
    (run (string-append
          "(schema User :name String :age Nat :email String)\n"
          "(selection NameOnly from User :requires [:name])\n"
          "(selection ContactInfo from User :requires [:name :email])\n"
          "(selection AgeCheck from User :requires [:age])")))
  (check-no-errors results))

;; ========================================
;; 7. Selection with :provides
;; ========================================

(test-case "selection-reg/with-provides"
  (define result
    (run-last (string-append
               "(schema Response :status Nat :body String)\n"
               "(selection StatusOnly from Response :provides [:status])")))
  (check-true (string? result) (format "Expected string, got ~v" result))
  (check-true (string-contains? result "selection")
              (format "Expected 'selection' in result, got ~s" result)))

;; ========================================
;; 8. Selection with :includes (names only, no resolution yet)
;; ========================================

(test-case "selection-reg/with-includes"
  (define result
    (run-last (string-append
               "(schema User :name String :age Nat :email String)\n"
               "(selection NameOnly from User :requires [:name])\n"
               "(selection Full from User :requires [:email] :includes [NameOnly])")))
  (check-true (string? result) (format "Expected string, got ~v" result))
  (check-true (string-contains? result "selection")
              (format "Expected 'selection' in result, got ~s" result)))

;; ========================================
;; 9. Error: provides field not in schema
;; ========================================

(test-case "selection-reg/error-bad-provides-field"
  (define result
    (run-last (string-append
               "(schema Config :port Nat :host String)\n"
               "(selection Bad from Config :provides [:port :bogus])")))
  (check-true (prologos-error? result)
              (format "Expected error, got ~v" result)))

;; ========================================
;; 10. Selection type preserved through pipeline
;; ========================================

(test-case "selection-reg/type-in-pipeline"
  ;; Schema + selection + spec that uses the selection type
  (define results
    (run (string-append
          "(schema Config :port Nat :host String)\n"
          "(selection PortConfig from Config :requires [:port])\n"
          "(spec get-port : PortConfig -> Nat)")))
  ;; All should succeed without errors
  (check-no-errors results)
  ;; At least 2 results (schema def + selection registration)
  (check-true (>= (length results) 2)
              (format "Expected >= 2 results, got ~a" (length results))))
