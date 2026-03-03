#lang racket/base

;;;
;;; Tests for Phase 3a: Structured Path Parsing
;;; Verifies parsing of deep paths (:address.zip), wildcards (* / **),
;;; and brace expansion (:address.{zip city}) in selection declarations.
;;;

(require rackunit
         racket/list
         racket/string
         "../parser.rkt"
         "../surface-syntax.rkt"
         "../sexp-readtable.rkt"
         "../errors.rkt"
         "test-support.rkt"
         "../macros.rkt"
         "../prelude.rkt"
         "../syntax.rkt"
         "../metavar-store.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../namespace.rkt"
         "../multi-dispatch.rkt")

;; ========================================
;; Parse helper (direct parser tests)
;; ========================================

(define (test-parse str)
  (define port (open-input-string str))
  (define stx (prologos-sexp-read-syntax "<test>" port))
  (parse-datum stx))

;; ========================================
;; Section 1: Parser-level structured path tests
;; ========================================

;; 1. Deep path: :address.zip → ((#:address #:zip))
(test-case "sel-path/parse-deep-path"
  (define result (test-parse "(selection Req from S :requires [:address.zip])"))
  (check-true (surf-selection? result)
              (format "Expected surf-selection, got ~v" result))
  (check-equal? (surf-selection-requires-paths result) '((#:address #:zip))))

;; 2. Multiple deep paths
(test-case "sel-path/parse-multi-deep"
  (define result (test-parse "(selection Req from S :requires [:address.zip :address.city])"))
  (check-true (surf-selection? result))
  (check-equal? (surf-selection-requires-paths result) '((#:address #:zip) (#:address #:city))))

;; 3. Mixed flat and deep paths
(test-case "sel-path/parse-mixed-flat-deep"
  (define result (test-parse "(selection Req from S :requires [:name :address.zip])"))
  (check-true (surf-selection? result))
  (check-equal? (surf-selection-requires-paths result) '((#:name) (#:address #:zip))))

;; 4. Wildcard path: :address.* → ((#:address *))
(test-case "sel-path/parse-wildcard"
  (define result (test-parse "(selection Req from S :requires [:address.*])"))
  (check-true (surf-selection? result))
  (check-equal? (surf-selection-requires-paths result) '((#:address *))))

;; 5. Globstar path: :address.** → ((#:address **))
(test-case "sel-path/parse-globstar"
  (define result (test-parse "(selection Req from S :requires [:address.**])"))
  (check-true (surf-selection? result))
  (check-equal? (surf-selection-requires-paths result) '((#:address **))))

;; 6. Brace expansion: :address.{zip city} → ((#:address #:zip) (#:address #:city))
(test-case "sel-path/parse-brace-expansion"
  (define result (test-parse "(selection Req from S :requires [:address.{zip city}])"))
  (check-true (surf-selection? result)
              (format "Expected surf-selection, got ~v" result))
  (check-equal? (surf-selection-requires-paths result) '((#:address #:zip) (#:address #:city))))

;; 7. Brace expansion with three branches
(test-case "sel-path/parse-brace-three"
  (define result (test-parse "(selection Req from S :requires [:address.{zip city state}])"))
  (check-true (surf-selection? result))
  (check-equal? (surf-selection-requires-paths result)
                '((#:address #:zip) (#:address #:city) (#:address #:state))))

;; 8. Flat path stays flat: :name → ((#:name))
(test-case "sel-path/flat-path-unchanged"
  (define result (test-parse "(selection Req from S :requires [:name])"))
  (check-true (surf-selection? result))
  (check-equal? (surf-selection-requires-paths result) '((#:name))))

;; 9. Three-level deep path: :address.geo.lat → ((#:address #:geo #:lat))
(test-case "sel-path/parse-three-level"
  (define result (test-parse "(selection Req from S :requires [:address.geo.lat])"))
  (check-true (surf-selection? result))
  (check-equal? (surf-selection-requires-paths result) '((#:address #:geo #:lat))))

;; 10. :provides also handles deep paths
(test-case "sel-path/provides-deep"
  (define result (test-parse "(selection Req from S :provides [:result.status])"))
  (check-true (surf-selection? result))
  (check-equal? (surf-selection-provides-paths result) '((#:result #:status))))

;; ========================================
;; Section 2: E2E pipeline tests (structured paths through elaborator)
;; ========================================
;; Phase 3a focuses on structured path PARSING and top-level field validation.
;; Deep nested path validation (e.g. :address.zip verifying zip exists in Address)
;; is Phase 3b. Here we test:
;; - Selections with deep paths register correctly
;; - Top-level field gating with deep-path selections works
;; - Error cases for invalid first segments

(define shared-preamble
  (string-append
   "(ns test)\n"
   ;; Define schemas — Address nested in User
   "(schema Address :zip Nat :city String :state String)\n"
   "(schema User :name String :age Nat :address Address)\n"
   ;; Flat selection (top-level fields only)
   "(selection NameAddr from User :requires [:name :address])\n"
   ;; Deep path selection — first segment :address must be valid in User
   "(selection AddrZip from User :requires [:address.zip])\n"))

(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg
                shared-schema-reg
                shared-selection-reg)
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

;; 11. Both schemas register as types
(test-case "sel-path/nested-schema-registers"
  (define results
    (run (string-append
          "(infer Address)\n"
          "(infer User)")))
  (check-no-errors results)
  (check-true (string-contains? (first results) "Type"))
  (check-true (string-contains? (second results) "Type")))

;; 12. Deep-path selection registers as type
(test-case "sel-path/deep-path-selection-is-type"
  (define result
    (run-last "(infer AddrZip)"))
  (check-true (string? result) (format "Expected string, got ~v" result))
  (check-true (string-contains? result "Type")))

;; 13. NameAddr (flat) — top-level field gating works: :name allowed
(test-case "sel-path/nameaddr-name-gated"
  (define result
    (run-last (string-append
               "(def u : NameAddr (the NameAddr ($brace-params :name \"alice\" :age 30N)))\n"
               "(infer (map-get u :name))")))
  (check-true (string? result) (format "Expected string, got ~v" result))
  (check-true (string-contains? result "String")))

;; 14. NameAddr (flat) — :age is blocked
(test-case "sel-path/nameaddr-blocks-age"
  (define result
    (run-last (string-append
               "(def u : NameAddr (the NameAddr ($brace-params :name \"alice\" :age 30N)))\n"
               "(infer (map-get u :age))")))
  (check-true (prologos-error? result)
              (format "Expected error for :age via NameAddr, got ~v" result)))

;; 15. AddrZip (deep path :address.zip) — spec+defn: :address access allowed
;;     Uses spec+defn pattern to avoid nested value construction complexity
(test-case "sel-path/addzip-address-gated"
  (define results
    (run (string-append
          "(spec addzip-get-addr AddrZip -> Address)\n"
          "(defn addzip-get-addr [u] (map-get u :address))\n")))
  (check-no-errors results))

;; 16. AddrZip (deep path) — :name is blocked (not in selection)
(test-case "sel-path/addzip-blocks-name"
  (define result
    (run-last (string-append
               "(spec addzip-bad-name AddrZip -> String)\n"
               "(defn addzip-bad-name [u] (map-get u :name))\n")))
  (check-true (prologos-error? result)
              (format "Expected error for :name via AddrZip, got ~v" result)))

;; 17. AddrZip (deep path) — :age is blocked
(test-case "sel-path/addzip-blocks-age"
  (define result
    (run-last (string-append
               "(spec addzip-bad-age AddrZip -> Nat)\n"
               "(defn addzip-bad-age [u] (map-get u :age))\n")))
  (check-true (prologos-error? result)
              (format "Expected error for :age via AddrZip, got ~v" result)))

;; 18. Elaborator validates deep path first segment: :bogus not in User → error
(test-case "sel-path/error-bad-deep-first-segment"
  (define result
    (run-last "(selection Bad from User :requires [:bogus.zip])"))
  (check-true (prologos-error? result)
              (format "Expected error for invalid first segment :bogus, got ~v" result)))

;; 19. Brace expansion registers through E2E pipeline
(test-case "sel-path/brace-expansion-e2e"
  (define result
    (run-last "(selection AddrDetail from User :requires [:address.{zip city}])"))
  ;; :address is first segment of both expanded paths → valid in User
  (check-true (string? result) (format "Expected string, got ~v" result))
  (check-true (string-contains? result "selection")))

;; 20. Wildcard path registers through E2E pipeline
(test-case "sel-path/wildcard-e2e"
  (define result
    (run-last "(selection AllAddr from User :requires [:address.*])"))
  ;; :address is first segment → valid in User
  (check-true (string? result) (format "Expected string, got ~v" result))
  (check-true (string-contains? result "selection")))

;; 21. Deep path order preserved (parser-level)
(test-case "sel-path/deep-path-order"
  (define result (test-parse "(selection Req from S :requires [:name :address.zip :age :address.city])"))
  (check-true (surf-selection? result))
  (check-equal? (surf-selection-requires-paths result)
                '((#:name) (#:address #:zip) (#:age) (#:address #:city))))

;; ========================================
;; Section 3: Phase 3b — Deep path validation against nested schemas
;; ========================================

;; 22. Deep path :address.zip validated — zip exists in Address
(test-case "sel-path/deep-valid-address-zip"
  (define result
    (run-last "(selection ValidDeep from User :requires [:address.zip])"))
  (check-true (string? result) (format "Expected string, got ~v" result))
  (check-true (string-contains? result "selection")))

;; 23. Deep path :address.city validated — city exists in Address
(test-case "sel-path/deep-valid-address-city"
  (define result
    (run-last "(selection ValidDeep2 from User :requires [:address.city])"))
  (check-true (string? result) (format "Expected string, got ~v" result))
  (check-true (string-contains? result "selection")))

;; 24. Error: deep path :address.bogus — bogus does NOT exist in Address
(test-case "sel-path/deep-invalid-nested-field"
  (define result
    (run-last "(selection BadNested from User :requires [:address.bogus])"))
  (check-true (prologos-error? result)
              (format "Expected error for :address.bogus (bogus not in Address), got ~v" result)))

;; 25. Error: deep path on non-schema field — :name.foo (name is String, not schema)
(test-case "sel-path/deep-non-schema-field"
  (define result
    (run-last "(selection BadDeep from User :requires [:name.foo])"))
  (check-true (prologos-error? result)
              (format "Expected error for :name.foo (String not a schema), got ~v" result)))

;; 26. Error: deep path on non-schema field — :age.bar (age is Nat)
(test-case "sel-path/deep-non-schema-nat"
  (define result
    (run-last "(selection BadDeep2 from User :requires [:age.bar])"))
  (check-true (prologos-error? result)
              (format "Expected error for :age.bar (Nat not a schema), got ~v" result)))

;; 27. Mixed flat+deep paths — all valid
(test-case "sel-path/deep-mixed-valid"
  (define results
    (run (string-append
          "(selection MixedDeep from User :requires [:name :address.zip :address.state])")))
  (check-no-errors results))

;; 28. Error in provides deep path — bad nested field
(test-case "sel-path/deep-provides-invalid"
  (define result
    (run-last "(selection BadProv from User :provides [:address.bogus])"))
  (check-true (prologos-error? result)
              (format "Expected error for provides :address.bogus, got ~v" result)))

;; 29. Brace expansion with deep validation — :address.{zip city} valid
(test-case "sel-path/deep-brace-valid"
  (define result
    (run-last "(selection BraceDeep from User :requires [:address.{zip city}])"))
  (check-true (string? result) (format "Expected string, got ~v" result))
  (check-true (string-contains? result "selection")))

;; 30. Brace expansion with deep validation — :address.{zip bogus} errors
(test-case "sel-path/deep-brace-invalid"
  (define result
    (run-last "(selection BadBrace from User :requires [:address.{zip bogus}])"))
  (check-true (prologos-error? result)
              (format "Expected error for :address.{zip bogus}, got ~v" result)))
