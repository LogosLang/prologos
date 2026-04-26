#lang racket/base

;;;
;;; Tests for Capabilities as Types — Phase 3: Subtype Hierarchy + Standard Library
;;; Tests that capability subtypes register correctly, transitive closure works,
;;; and the standard capability library loads from the prelude.
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
  "(ns test-cap3)")

(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg
                shared-capability-reg
                shared-subtype-reg)
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
                 [current-capability-registry prelude-capability-registry])
    (install-module-loader!)
    (process-string shared-preamble)
    (values (current-prelude-env)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-capability-registry)
            (current-subtype-registry))))

;; Helper: run code and return (list results global-env capability-registry subtype-registry)
(define (run-capturing s)
  (parameterize ([current-prelude-env shared-global-env]
                 [current-ns-context shared-ns-context]
                 [current-module-registry shared-module-reg]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry shared-trait-reg]
                 [current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg]
                 [current-capability-registry shared-capability-reg])
    (define results (process-string s))
    (list results
          (current-prelude-env)
          (current-capability-registry)
          (current-subtype-registry))))

(define (run s) (car (run-capturing s)))

(define (run-last s) (last (run s)))

;; ========================================
;; Capability subtype registration
;; ========================================

(test-case "capability-subtype/direct-registration"
  ;; subtype between two capabilities should succeed (no coercion needed)
  (define captured
    (run-capturing "(capability AlphaCap)\n(capability BetaCap)\n(subtype AlphaCap BetaCap)"))
  (define results (first captured))
  (define sub-reg (fourth captured))
  ;; subtype-pair? should work with short names
  (check-true (subtype-pair? 'AlphaCap 'BetaCap)
              "AlphaCap should be subtype of BetaCap"))

(test-case "capability-subtype/not-reverse"
  ;; Subtype is directional — BetaCap is NOT a subtype of AlphaCap
  (define captured
    (run-capturing "(capability ACap)\n(capability BCap)\n(subtype ACap BCap)"))
  (check-false (subtype-pair? 'BCap 'ACap)
               "BCap should NOT be subtype of ACap"))

(test-case "capability-subtype/transitive-closure"
  ;; A <: B <: C → A <: C via transitive closure
  (define captured
    (run-capturing
     (string-append "(capability LeafCap)\n"
                    "(capability MidCap)\n"
                    "(capability RootCap)\n"
                    "(subtype LeafCap MidCap)\n"
                    "(subtype MidCap RootCap)")))
  (check-true (subtype-pair? 'LeafCap 'MidCap)
              "LeafCap should be subtype of MidCap")
  (check-true (subtype-pair? 'MidCap 'RootCap)
              "MidCap should be subtype of RootCap")
  (check-true (subtype-pair? 'LeafCap 'RootCap)
              "LeafCap should be transitively subtype of RootCap"))

(test-case "capability-subtype/result-string"
  ;; subtype should return a result string
  (define result
    (run-last "(capability XCap)\n(capability YCap)\n(subtype XCap YCap)"))
  (check-true (string? result))
  (check-true (string-contains? result "subtype")))

;; ========================================
;; Standard library loaded from prelude
;; ========================================

(test-case "prelude/standard-capabilities-registered"
  ;; The shared fixture loads the prelude, which should include capabilities.
  ;; Check that standard capability names are in the shared capability registry.
  (parameterize ([current-capability-registry shared-capability-reg])
    (check-true (capability-type? 'ReadCap)
                "ReadCap should be registered from prelude")
    (check-true (capability-type? 'WriteCap)
                "WriteCap should be registered from prelude")
    (check-true (capability-type? 'HttpCap)
                "HttpCap should be registered from prelude")
    (check-true (capability-type? 'StdioCap)
                "StdioCap should be registered from prelude")
    (check-true (capability-type? 'FsCap)
                "FsCap should be registered from prelude")
    (check-true (capability-type? 'NetCap)
                "NetCap should be registered from prelude")
    (check-true (capability-type? 'SysCap)
                "SysCap should be registered from prelude")))

(test-case "prelude/standard-capabilities-in-global-env"
  ;; Capability names should be in the global env as types
  (check-true (pair? (hash-ref shared-global-env 'ReadCap #f))
              "ReadCap should be in global env")
  (check-true (pair? (hash-ref shared-global-env 'FsCap #f))
              "FsCap should be in global env")
  (check-true (pair? (hash-ref shared-global-env 'SysCap #f))
              "SysCap should be in global env"))

(test-case "prelude/standard-subtype-hierarchy"
  ;; The standard subtype hierarchy should be registered
  (check-true (subtype-pair? 'ReadCap 'FsCap)
              "ReadCap <: FsCap")
  (check-true (subtype-pair? 'WriteCap 'FsCap)
              "WriteCap <: FsCap")
  (check-true (subtype-pair? 'HttpCap 'NetCap)
              "HttpCap <: NetCap")
  (check-true (subtype-pair? 'FsCap 'SysCap)
              "FsCap <: SysCap")
  (check-true (subtype-pair? 'NetCap 'SysCap)
              "NetCap <: SysCap")
  (check-true (subtype-pair? 'StdioCap 'SysCap)
              "StdioCap <: SysCap"))

(test-case "prelude/transitive-subtype-hierarchy"
  ;; Transitive: ReadCap <: FsCap <: SysCap → ReadCap <: SysCap
  (check-true (subtype-pair? 'ReadCap 'SysCap)
              "ReadCap <: SysCap (transitive)")
  (check-true (subtype-pair? 'WriteCap 'SysCap)
              "WriteCap <: SysCap (transitive)")
  (check-true (subtype-pair? 'HttpCap 'SysCap)
              "HttpCap <: SysCap (transitive)"))

(test-case "prelude/no-false-subtypes"
  ;; ReadCap is NOT a subtype of NetCap
  (check-false (subtype-pair? 'ReadCap 'NetCap)
               "ReadCap should not be subtype of NetCap")
  ;; HttpCap is NOT a subtype of FsCap
  (check-false (subtype-pair? 'HttpCap 'FsCap)
               "HttpCap should not be subtype of FsCap")
  ;; SysCap is NOT a subtype of ReadCap (direction matters)
  (check-false (subtype-pair? 'SysCap 'ReadCap)
               "SysCap should not be subtype of ReadCap"))

;; ========================================
;; Capability types usable in expressions
;; ========================================

(test-case "prelude/capability-usable-as-type"
  ;; After prelude loading, capability names should be usable as types
  (define result (run-last "(infer ReadCap)"))
  (check-true (string? result))
  (check-true (string-contains? result "Type")))

(test-case "prelude/capability-in-pi-type"
  ;; Capability types should work in Pi type positions
  (define result (run-last "(infer (Pi (fs :0 ReadCap) Nat))"))
  (check-true (string? result))
  (check-true (string-contains? result "Type")))
