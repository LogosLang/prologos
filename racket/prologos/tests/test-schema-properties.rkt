#lang racket/base

;;;
;;; Tests for Phase 5: Schema Properties
;;; Verifies :closed (schema-level), :default (field-level),
;;; and :check (field-level) property parsing and behavior.
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
   ;; Open schema (default behavior, for comparison)
   "(schema OpenPoint :x Nat :y Nat)\n"
   ;; Closed schema — no extra keys allowed
   "(schema ClosedConfig :closed :host String :port Nat)\n"))

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

;; Like run, but also returns the schema-registry after processing
(define (run+registry s)
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
    (define results (process-string s))
    (values results (current-schema-registry))))

(define (run-last s) (last (run s)))

(define (check-no-errors results)
  (for ([r results] [i (in-naturals)])
    (check-false (prologos-error? r)
                 (format "Result ~a was an error: ~v" i r))))

;; ========================================
;; Section 1: :closed — schema-level property
;; ========================================

;; 1. Closed schema registers as type
(test-case "schema-prop/closed-is-type"
  (define result (run-last "(infer ClosedConfig)"))
  (check-true (string? result) (format "Expected string, got ~v" result))
  (check-true (string-contains? result "Type")))

;; 2. Closed schema — declared fields accepted
(test-case "schema-prop/closed-declared-fields-ok"
  (define results
    (run (string-append
          "(def cc : ClosedConfig (the ClosedConfig ($brace-params :host \"localhost\" :port 8080N)))\n"
          "(infer cc)")))
  (check-no-errors results))

;; 3. Closed schema — extra field rejected
(test-case "schema-prop/closed-rejects-extra"
  (define result
    (run-last
     "(def bad : ClosedConfig (the ClosedConfig ($brace-params :host \"localhost\" :port 8080N :debug True)))"))
  (check-true (prologos-error? result)
              (format "Expected error for extra :debug field on closed schema, got ~v" result)))

;; 4. Open schema — extra fields accepted (baseline)
(test-case "schema-prop/open-accepts-extra"
  (define results
    (run (string-append
          "(def op : OpenPoint (the OpenPoint ($brace-params :x 1N :y 2N :z 3N)))\n"
          "(infer op)")))
  (check-no-errors results))

;; 5. Closed schema — dot-access on declared field works
(test-case "schema-prop/closed-dot-access"
  (define results
    (run (string-append
          "(spec get-host ClosedConfig -> String)\n"
          "(defn get-host [c] (map-get c :host))\n")))
  (check-no-errors results))

;; 6. Closed schema — accessing undeclared field via spec+defn fails
(test-case "schema-prop/closed-blocks-undeclared-access"
  (define result
    (run-last (string-append
               "(spec get-bad ClosedConfig -> Bool)\n"
               "(defn get-bad [c] (map-get c :debug))\n")))
  (check-true (prologos-error? result)
              (format "Expected error for :debug access on ClosedConfig, got ~v" result)))

;; 7. Closed schema with only required fields — succeeds
(test-case "schema-prop/closed-exact-fields"
  (define result
    (run-last
     "(def exact : ClosedConfig (the ClosedConfig ($brace-params :host \"x\" :port 1N)))"))
  (check-false (prologos-error? result)
               (format "Expected success for exact fields on closed schema, got ~v" result)))

;; 8. Open schema (default) — closed? is #f in registry
(test-case "schema-prop/open-default"
  (define entry (hash-ref shared-schema-reg 'OpenPoint #f))
  (check-true (schema-entry? entry))
  (check-false (schema-entry-closed? entry)))

;; 9. Closed schema — closed? is #t in registry
(test-case "schema-prop/closed-registry"
  (define entry (hash-ref shared-schema-reg 'ClosedConfig #f))
  (check-true (schema-entry? entry))
  (check-true (schema-entry-closed? entry)))

;; ========================================
;; Section 2: :default — field-level property (parsing + storage)
;; ========================================

;; 10. :default field parses and registers
(test-case "schema-prop/default-field-registers"
  (define-values (results reg)
    (run+registry "(schema Employee :name String :email String :default \"\" :salary Nat)"))
  (check-no-errors results)
  ;; Verify Employee registered with 3 fields
  (define entry (hash-ref reg 'Employee #f))
  (check-true (schema-entry? entry))
  (check-equal? (length (schema-entry-fields entry)) 3))

;; 11. :default value stored in schema-field struct
(test-case "schema-prop/default-value-stored"
  (define-values (results reg)
    (run+registry "(schema Cfg2 :host String :default \"localhost\" :port Nat :default 8080)"))
  (check-no-errors results)
  (define entry (hash-ref reg 'Cfg2 #f))
  (check-true (schema-entry? entry))
  (define fields (schema-entry-fields entry))
  ;; host field should have default "localhost"
  (define host-field (findf (lambda (f) (eq? (schema-field-keyword f) 'host)) fields))
  (check-true (schema-field? host-field))
  (check-equal? (schema-field-default-val host-field) "localhost")
  ;; port field should have default 8080
  (define port-field (findf (lambda (f) (eq? (schema-field-keyword f) 'port)) fields))
  (check-true (schema-field? port-field))
  (check-equal? (schema-field-default-val port-field) 8080))

;; 12. Field without :default has #f default
(test-case "schema-prop/no-default-is-false"
  (define-values (results reg)
    (run+registry "(schema Plain :name String :age Nat)"))
  (check-no-errors results)
  (define entry (hash-ref reg 'Plain #f))
  (check-true (schema-entry? entry))
  (define fields (schema-entry-fields entry))
  (define name-field (findf (lambda (f) (eq? (schema-field-keyword f) 'name)) fields))
  (check-equal? (schema-field-default-val name-field) #f))

;; ========================================
;; Section 3: :check — field-level property (parsing + storage)
;; ========================================

;; 13. :check field parses and registers
(test-case "schema-prop/check-field-registers"
  (define-values (results reg)
    (run+registry "(schema Validated :name String :age Nat :check (> _ 0))"))
  (check-no-errors results)
  (define entry (hash-ref reg 'Validated #f))
  (check-true (schema-entry? entry))
  (check-equal? (length (schema-entry-fields entry)) 2))

;; 14. :check predicate stored in schema-field struct
(test-case "schema-prop/check-pred-stored"
  (define-values (results reg)
    (run+registry "(schema Val2 :salary Nat :check (> _ 0) :name String)"))
  (check-no-errors results)
  (define entry (hash-ref reg 'Val2 #f))
  (check-true (schema-entry? entry))
  (define fields (schema-entry-fields entry))
  (define sal-field (findf (lambda (f) (eq? (schema-field-keyword f) 'salary)) fields))
  (check-true (schema-field? sal-field))
  ;; check-pred should be the parsed predicate expression
  (check-true (pair? (schema-field-check-pred sal-field)))
  ;; name field should have #f check-pred
  (define name-field (findf (lambda (f) (eq? (schema-field-keyword f) 'name)) fields))
  (check-equal? (schema-field-check-pred name-field) #f))

;; 15. Combined :default + :check on same field
(test-case "schema-prop/default-and-check"
  (define-values (results reg)
    (run+registry "(schema Badge :id Nat :check (> _ 0) :default 1)"))
  (check-no-errors results)
  (define entry (hash-ref reg 'Badge #f))
  (check-true (schema-entry? entry))
  (define fields (schema-entry-fields entry))
  (define id-field (findf (lambda (f) (eq? (schema-field-keyword f) 'id)) fields))
  (check-true (schema-field? id-field))
  (check-equal? (schema-field-default-val id-field) 1)
  (check-true (pair? (schema-field-check-pred id-field))))

;; 16. :closed + :default combined
(test-case "schema-prop/closed-with-defaults"
  (define-values (results reg)
    (run+registry "(schema ClosedDef :closed :host String :default \"localhost\" :port Nat)"))
  (check-no-errors results)
  (define entry (hash-ref reg 'ClosedDef #f))
  (check-true (schema-entry? entry))
  (check-true (schema-entry-closed? entry))
  (define fields (schema-entry-fields entry))
  (define host-field (findf (lambda (f) (eq? (schema-field-keyword f) 'host)) fields))
  (check-equal? (schema-field-default-val host-field) "localhost"))

;; ========================================
;; Section 4: panic — runtime abort construct
;; ========================================

;; 17. panic type-checks in checking context (inhabits any type)
(test-case "schema-prop/panic-checks-any-type"
  (define results
    (run (string-append
          "(spec always-panic Nat -> Nat)\n"
          "(defn always-panic [x] (panic \"not implemented\"))\n")))
  (check-no-errors results))

;; 18. panic at runtime produces a prologos-error (via eval, not def)
(test-case "schema-prop/panic-runtime-error"
  (define result
    (run-last "(the Nat (panic \"kaboom\"))"))
  (check-true (prologos-error? result)
              (format "Expected prologos-error from panic, got ~v" result)))

;; 19. panic in if-else: true branch taken, panic not triggered
(test-case "schema-prop/panic-if-else-not-triggered"
  (define result
    (run-last "(if true 42N (panic \"unreachable\"))"))
  (check-false (prologos-error? result)
               (format "Expected success when panic branch not taken, got ~v" result))
  (check-true (string? result))
  (check-true (string-contains? result "42")))

;; 20. panic in if-else: false branch triggers panic
(test-case "schema-prop/panic-if-else-triggered"
  (define result
    (run-last "(if false 42N (panic \"hit the panic\"))"))
  (check-true (prologos-error? result)
              (format "Expected prologos-error from false-branch panic, got ~v" result)))

;; ========================================
;; Section 5: :default — runtime enforcement
;; ========================================

;; 21. :default fills missing field at construction time
(test-case "schema-prop/default-fills-missing"
  (define results
    (run (string-append
          "(schema DefPoint :x Nat :y Nat :default 0N)\n"
          "(def dp : DefPoint (DefPoint ($brace-params :x 5N)))\n"
          "(map-get dp :y)\n")))
  (check-no-errors results)
  ;; Last result should be 0 (the default), not an error
  (define last-result (last results))
  (check-true (string? last-result) (format "Expected string, got ~v" last-result))
  (check-true (string-contains? last-result "0")))

;; 22. :default doesn't override explicitly provided value
(test-case "schema-prop/default-no-override"
  (define results
    (run (string-append
          "(schema DefPoint2 :x Nat :y Nat :default 0N)\n"
          "(def dp2 : DefPoint2 (DefPoint2 ($brace-params :x 5N :y 99N)))\n"
          "(map-get dp2 :y)\n")))
  (check-no-errors results)
  (define last-result (last results))
  (check-true (string? last-result))
  (check-true (string-contains? last-result "99")))

;; 23. Multiple defaults: both missing fields filled
(test-case "schema-prop/multiple-defaults"
  (define results
    (run (string-append
          "(schema MultiDef :a Nat :default 1N :b String :default \"hello\")\n"
          "(def md : MultiDef (MultiDef ($brace-params)))\n"
          "(map-get md :a)\n")))
  (check-no-errors results)
  (define last-result (last results))
  (check-true (string? last-result))
  (check-true (string-contains? last-result "1")))

;; 24. No defaults needed (all fields provided)
(test-case "schema-prop/default-all-provided"
  (define results
    (run (string-append
          "(schema DefPoint3 :x Nat :y Nat :default 0N)\n"
          "(def dp3 : DefPoint3 (DefPoint3 ($brace-params :x 10N :y 20N)))\n"
          "(map-get dp3 :x)\n")))
  (check-no-errors results)
  (define last-result (last results))
  (check-true (string? last-result))
  (check-true (string-contains? last-result "10")))
