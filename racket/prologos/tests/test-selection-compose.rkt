#lang racket/base

;;;
;;; Tests for Phase 4: Selection Composition
;;; Verifies :includes set-union resolution, path join semantics,
;;; and cross-schema error checking.
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
   ;; Schemas
   "(schema Address :zip Nat :city String :state String)\n"
   "(schema User :name String :age Nat :email String :address Address)\n"
   "(schema Config :port Nat :host String)\n"
   ;; Base selections for composition
   "(selection NameOnly from User :requires [:name])\n"
   "(selection AgeOnly from User :requires [:age])\n"
   "(selection EmailOnly from User :provides [:email])\n"
   "(selection AddrZip from User :requires [:address.zip])\n"
   "(selection AddrAll from User :requires [:address.*])\n"))

(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg
                shared-schema-reg
                shared-selection-reg)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
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
    (values (current-prelude-env)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-schema-registry)
            (current-selection-registry))))

(define (run s)
  (parameterize ([current-prelude-env shared-global-env]
                 [current-ns-context shared-ns-context]
                 [current-module-registry shared-module-reg]
                 [current-lib-paths (list prelude-lib-dir)]
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
;; 1. Basic :includes — union of two selections
;; ========================================

(test-case "sel-compose/basic-includes"
  (define result
    (run-last "(selection NameAge from User :includes [NameOnly AgeOnly])"))
  (check-true (string? result) (format "Expected string, got ~v" result))
  (check-true (string-contains? result "selection")))

;; ========================================
;; 2. Included selection fields are accessible
;; ========================================

(test-case "sel-compose/includes-fields-accessible"
  ;; NameAge includes NameOnly (:name) and AgeOnly (:age) → both accessible
  (define results
    (run (string-append
          "(selection NameAge from User :includes [NameOnly AgeOnly])\n"
          "(spec compose-get-name NameAge -> String)\n"
          "(defn compose-get-name [u] (map-get u :name))\n")))
  (check-no-errors results))

;; ========================================
;; 3. Included + own :requires combined
;; ========================================

(test-case "sel-compose/includes-plus-requires"
  (define results
    (run (string-append
          "(selection NameAgeEmail from User :includes [NameOnly AgeOnly] :requires [:email])\n"
          ;; All three fields should be accessible
          "(spec compose-get-email NameAgeEmail -> String)\n"
          "(defn compose-get-email [u] (map-get u :email))\n")))
  (check-no-errors results))

;; ========================================
;; 4. Non-included fields are blocked
;; ========================================

(test-case "sel-compose/non-included-blocked"
  ;; NameAge includes only :name and :age, so :email should be blocked
  (define result
    (run-last (string-append
               "(selection NameAge2 from User :includes [NameOnly AgeOnly])\n"
               "(spec compose-bad-email NameAge2 -> String)\n"
               "(defn compose-bad-email [u] (map-get u :email))\n")))
  (check-true (prologos-error? result)
              (format "Expected error for :email access via NameAge2, got ~v" result)))

;; ========================================
;; 5. Error: :includes unknown selection
;; ========================================

(test-case "sel-compose/error-unknown-include"
  (define result
    (run-last "(selection Bad from User :includes [NoSuchSelection])"))
  (check-true (prologos-error? result)
              (format "Expected error for unknown include, got ~v" result)))

;; ========================================
;; 6. Error: :includes selection from different schema
;; ========================================

(test-case "sel-compose/error-cross-schema"
  ;; NameOnly is from User, can't include in Config-based selection
  (define result
    (run-last (string-append
               "(selection BadCross from Config :includes [NameOnly])")))
  (check-true (prologos-error? result)
              (format "Expected error for cross-schema include, got ~v" result)))

;; ========================================
;; 7. Path join: deep path + wildcard → wildcard wins
;; ========================================

(test-case "sel-compose/path-join-wildcard-wins"
  ;; AddrZip has :address.zip, AddrAll has :address.* — union should keep :address.*
  (define results
    (run (string-append
          "(selection JoinedAddr from User :includes [AddrZip AddrAll])\n"
          ;; With wildcard joined, :address.city should also be accessible
          "(spec compose-get-addr JoinedAddr -> Address)\n"
          "(defn compose-get-addr [u] (map-get u :address))\n")))
  (check-no-errors results))

;; ========================================
;; 8. Multiple inclusions with overlapping fields (idempotent)
;; ========================================

(test-case "sel-compose/idempotent-overlap"
  ;; Including NameOnly twice should work (idempotent union)
  (define result
    (run-last "(selection Idempotent from User :includes [NameOnly NameOnly])"))
  (check-true (string? result) (format "Expected string, got ~v" result))
  (check-true (string-contains? result "selection")))

;; ========================================
;; 9. Three-way composition
;; ========================================

(test-case "sel-compose/three-way"
  (define results
    (run (string-append
          "(selection ThreeWay from User :includes [NameOnly AgeOnly EmailOnly])\n"
          ;; All three fields accessible (name from requires, email from provides)
          "(spec compose-three-name ThreeWay -> String)\n"
          "(defn compose-three-name [u] (map-get u :name))\n")))
  (check-no-errors results))

;; ========================================
;; 10. Composed selection is a type (usable with infer)
;; ========================================

(test-case "sel-compose/is-type"
  (define result
    (run-last (string-append
               "(selection Composed from User :includes [NameOnly AgeOnly])\n"
               "(infer Composed)")))
  (check-true (string? result) (format "Expected string, got ~v" result))
  (check-true (string-contains? result "Type")))

;; ========================================
;; 11. Includes + provides union
;; ========================================

(test-case "sel-compose/includes-provides"
  ;; EmailOnly has :provides [:email]; include it and add own :requires
  (define results
    (run (string-append
          "(selection WithEmail from User :includes [EmailOnly] :requires [:name])\n"
          ;; Both :name (own requires) and :email (included provides) should be accessible
          "(spec compose-email-name WithEmail -> String)\n"
          "(defn compose-email-name [u] (map-get u :email))\n")))
  (check-no-errors results))

;; ========================================
;; 12. Deep path from includes accessible (returns sub-selection, not full Address)
;; ========================================

(test-case "sel-compose/deep-path-included"
  ;; AddrZip has :address.zip — include it, :address is accessible but returns sub-selection
  ;; Phase 3c: can't use `-> Address` because it returns a sub-selection type
  (define result
    (run-last (string-append
               "(selection WithAddrZip from User :includes [AddrZip] :requires [:name])\n"
               "(def u2 : WithAddrZip (the WithAddrZip ($brace-params :name \"alice\" :address (the Address ($brace-params :zip 10001N :city \"NYC\" :state \"NY\")))))\n"
               "(infer (map-get u2 :address))")))
  (check-true (string? result) (format "Expected string, got ~v" result))
  ;; Result should be a sub-selection type, not full Address
  (check-false (string-contains? result "Address")
               (format "Expected sub-selection type from composed deep path, got ~v" result)))
