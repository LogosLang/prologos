#lang racket/base

;;;
;;; Tests for Phase 2c: Selection Type Checking
;;; Verifies field-gating: selection-typed values restrict map-get access
;;; to only the fields declared in the selection's :requires/:provides.
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

(define shared-preamble
  (string-append
   "(ns test)\n"
   ;; Define schemas
   "(schema User :name String :age Nat :email String)\n"
   ;; Define selections with different field sets
   "(selection NameOnly from User :requires [:name])\n"
   "(selection NameAge from User :requires [:name :age])\n"
   "(selection EmailOnly from User :provides [:email])\n"))

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
;; 1. Selection field access via map-get — selected field returns correct type
;; ========================================

(test-case "selection-typing/access-selected-field"
  ;; NameOnly has :requires [:name], so map-get for :name should return String
  (define result
    (run-last (string-append
               "(def u : NameOnly (the NameOnly ($brace-params :name \"alice\")))\n"
               "(infer (map-get u :name))")))
  (check-true (string? result) (format "Expected string, got ~v" result))
  (check-true (string-contains? result "String")
              (format "Expected 'String' in result, got ~s" result)))

;; ========================================
;; 2. Selection blocks access to non-selected field
;; ========================================

(test-case "selection-typing/blocks-unselected-field"
  ;; NameOnly only has :name, so :age should be blocked → inference error
  (define result
    (run-last (string-append
               "(def u : NameOnly (the NameOnly ($brace-params :name \"alice\")))\n"
               "(infer (map-get u :age))")))
  (check-true (prologos-error? result)
              (format "Expected error for accessing non-selected field :age, got ~v" result)))

;; ========================================
;; 3. Selection blocks access to :email via NameOnly
;; ========================================

(test-case "selection-typing/blocks-email-via-nameonly"
  (define result
    (run-last (string-append
               "(def u : NameOnly (the NameOnly ($brace-params :name \"alice\")))\n"
               "(infer (map-get u :email))")))
  (check-true (prologos-error? result)
              (format "Expected error for accessing :email via NameOnly, got ~v" result)))

;; ========================================
;; 4. Multi-field selection — both fields accessible
;; ========================================

(test-case "selection-typing/multi-field-access"
  ;; NameAge has :requires [:name :age]
  (define results
    (run (string-append
          "(def u : NameAge (the NameAge ($brace-params :name \"bob\" :age 25N)))\n"
          "(infer (map-get u :name))\n"
          "(infer (map-get u :age))")))
  (check-no-errors results)
  (define r-name (second results))
  (define r-age (third results))
  (check-true (string-contains? r-name "String"))
  (check-true (string-contains? r-age "Nat")))

;; ========================================
;; 5. Multi-field selection — blocks field NOT in selection
;; ========================================

(test-case "selection-typing/multi-field-blocks-other"
  ;; NameAge has :name and :age, but NOT :email
  (define result
    (run-last (string-append
               "(def u : NameAge (the NameAge ($brace-params :name \"bob\" :age 25N)))\n"
               "(infer (map-get u :email))")))
  (check-true (prologos-error? result)
              (format "Expected error for :email via NameAge, got ~v" result)))

;; ========================================
;; 6. Provides field is accessible
;; ========================================

(test-case "selection-typing/provides-field-accessible"
  ;; EmailOnly has :provides [:email]
  (define result
    (run-last (string-append
               "(def u : EmailOnly (the EmailOnly ($brace-params :email \"a@b.c\")))\n"
               "(infer (map-get u :email))")))
  (check-true (string? result) (format "Expected string, got ~v" result))
  (check-true (string-contains? result "String")
              (format "Expected 'String' in result, got ~s" result)))

;; ========================================
;; 7. Provides does NOT grant access to non-provided fields
;; ========================================

(test-case "selection-typing/provides-blocks-other-fields"
  ;; EmailOnly only provides :email, not :name
  (define result
    (run-last (string-append
               "(def u : EmailOnly (the EmailOnly ($brace-params :email \"a@b.c\")))\n"
               "(infer (map-get u :name))")))
  (check-true (prologos-error? result)
              (format "Expected error for :name via EmailOnly, got ~v" result)))

;; ========================================
;; 8. Full schema type allows all fields (contrast with selection)
;; ========================================

(test-case "selection-typing/full-schema-all-fields"
  (define results
    (run (string-append
          "(def u : User (the User ($brace-params :name \"alice\" :age 30N :email \"a@b.c\")))\n"
          "(infer (map-get u :name))\n"
          "(infer (map-get u :age))\n"
          "(infer (map-get u :email))")))
  (check-no-errors results)
  (check-true (string-contains? (second results) "String"))
  (check-true (string-contains? (third results) "Nat"))
  (check-true (string-contains? (fourth results) "String")))

;; ========================================
;; 9. spec+defn with selection — access selected field
;; ========================================

(test-case "selection-typing/spec-defn-access"
  ;; Use no-colon spec syntax in sexp mode: (spec name Type -> RetType)
  (define results
    (run (string-append
          "(spec sel-get-name NameOnly -> String)\n"
          "(defn sel-get-name [u] (map-get u :name))\n")))
  (check-no-errors results))

;; ========================================
;; 10. spec+defn with selection — block unselected field
;; ========================================

(test-case "selection-typing/spec-defn-blocks"
  ;; NameOnly doesn't have :age, so defn using map-get :age should error
  (define result
    (run-last (string-append
               "(spec sel-bad-age NameOnly -> Nat)\n"
               "(defn sel-bad-age [u] (map-get u :age))\n")))
  (check-true (prologos-error? result)
              (format "Expected error for accessing :age via NameOnly in defn, got ~v" result)))

;; ========================================
;; 11. Selection type appears in infer output
;; ========================================

(test-case "selection-typing/infer-shows-type"
  (define result
    (run-last (string-append
               "(def u : NameOnly (the NameOnly ($brace-params :name \"alice\")))\n"
               "(infer u)")))
  (check-true (string? result) (format "Expected string, got ~v" result))
  (check-true (string-contains? result "NameOnly")
              (format "Expected 'NameOnly' in infer result, got ~s" result)))

;; ========================================
;; 12. spec+defn with full schema — all fields accessible
;; ========================================

(test-case "selection-typing/spec-defn-schema"
  (define results
    (run (string-append
          "(spec sel-full-name User -> String)\n"
          "(defn sel-full-name [u] (map-get u :name))\n")))
  (check-no-errors results))
