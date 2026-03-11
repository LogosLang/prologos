#lang racket/base

;;;
;;; Tests for Capabilities as Types — Phase 1: Capability Declaration + Kind Marker
;;; Tests that `capability ReadCap` parses, elaborates, registers in the capability
;;; registry, and installs the name as a type in the global env.
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
;; Shared Fixture (modules loaded once)
;; ========================================

(define shared-preamble
  "(ns test-cap)")

(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg
                shared-capability-reg)
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
                 [current-capability-registry (hasheq)])
    (install-module-loader!)
    (process-string shared-preamble)
    (values (current-global-env)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-capability-registry))))

;; Helper: run code and return (list results global-env capability-registry)
;; Captures state INSIDE the parameterize block before it exits.
(define (run-capturing s)
  (parameterize ([current-global-env shared-global-env]
                 [current-ns-context shared-ns-context]
                 [current-module-registry shared-module-reg]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry shared-trait-reg]
                 [current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg]
                 [current-capability-registry shared-capability-reg])
    (define results (process-string s))
    (list results
          (global-env-snapshot)  ;; Phase 3a: merge both layers
          (current-capability-registry))))

(define (run s)
  (car (run-capturing s)))

(define (run-last s) (last (run s)))

;; ========================================
;; Phase 1 tests: Capability Declaration
;; ========================================

;; --- Parsing ---

(test-case "capability declaration parses to surf-capability"
  (define result (parse-datum '(capability ReadCap)))
  (check-true (surf-capability? result))
  (check-equal? (surf-capability-name result) 'ReadCap)
  (check-equal? (surf-capability-params result) '()))

(test-case "capability declaration parses second capability"
  (define result (parse-datum '(capability WriteCap)))
  (check-true (surf-capability? result))
  (check-equal? (surf-capability-name result) 'WriteCap))

(test-case "capability with no name is a parse error"
  (define result (parse-datum '(capability)))
  (check-true (prologos-error? result)))

;; --- Registration and kind marker ---

(test-case "capability registers in capability registry"
  ;; Note: process-string uses sexp reader, so top-level forms need parens
  (define captured (run-capturing "(capability ReadCap)"))
  (define results (first captured))
  (define cap-reg (third captured))
  ;; Check the result string
  (check-true (string? (last results)))
  (check-true (string-contains? (last results) "ReadCap"))
  ;; Check the registry was updated
  (check-true (and (hash-ref cap-reg 'ReadCap #f) #t)
              "ReadCap should be in capability registry"))

(test-case "multiple capabilities register independently"
  (define captured (run-capturing "(capability FooCap)\n(capability BarCap)"))
  (define cap-reg (third captured))
  (check-true (and (hash-ref cap-reg 'FooCap #f) #t)
              "FooCap should be in capability registry")
  (check-true (and (hash-ref cap-reg 'BarCap #f) #t)
              "BarCap should be in capability registry"))

(test-case "capability-type? returns false for non-capabilities"
  ;; Traits are not capabilities (in the shared fixture, capability registry is empty)
  (check-false (capability-type? 'Eq))
  ;; Regular types are not capabilities
  (check-false (capability-type? 'Nat))
  ;; Unknown names are not capabilities
  (check-false (capability-type? 'NotAThing)))

;; --- Global env installation ---

(test-case "capability name appears in global env as type"
  (define captured (run-capturing "(capability TestCap1)"))
  (define env (second captured))
  ;; The name should be in the global env (under short name)
  (define entry (hash-ref env 'TestCap1 #f))
  (check-true (pair? entry)
              "TestCap1 should be in global env")
  (check-true (expr-Type? (car entry))
              "TestCap1 should have type (Type 0)"))

(test-case "capability with namespace qualification"
  (define captured (run-capturing "(capability NsCap)"))
  (define cap-reg (third captured))
  (define env (second captured))
  ;; Both short and FQN should be in registry
  (check-true (and (hash-ref cap-reg 'NsCap #f) #t)
              "Short name should be in capability registry")
  ;; FQN is test-cap::NsCap (from ns test-cap)
  (check-true (and (hash-ref cap-reg 'test-cap::NsCap #f) #t)
              "FQN should be in capability registry")
  ;; Both should be in global env
  (check-true (pair? (hash-ref env 'NsCap #f))
              "Short name should be in global env")
  (check-true (pair? (hash-ref env 'test-cap::NsCap #f))
              "FQN should be in global env"))

;; --- Use as type in expressions ---

(test-case "capability type can be referenced in infer"
  ;; After declaring a capability, the name should be usable as a type
  (define result
    (run-last "(capability InferCap)\n(infer InferCap)"))
  (check-true (string? result))
  (check-true (string-contains? result "Type")))

(test-case "capability type usable as type-level value"
  ;; Capability names are types at (Type 0), so (infer CapName) = Type 0.
  ;; Using them as runtime values requires constructors (future phases).
  ;; For now, verify the type-level behavior is correct.
  (define captured (run-capturing "(capability AnnCap)\n(infer AnnCap)"))
  (define results (first captured))
  (define last-result (last results))
  (check-true (string? last-result))
  (check-true (string-contains? last-result "Type")))

;; --- Dependent capability params rejected for now ---

(test-case "dependent capability params produce error"
  ;; Phase 7 feature — should produce a helpful error
  (define result (parse-datum '(capability FileCap (p Path))))
  (check-true (prologos-error? result)))
