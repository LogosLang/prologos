#lang racket/base

;;;
;;; Tests for Capabilities as Types — Phase 4: Lexical Capability Resolution
;;; Tests that capability constraints resolve from lexical scope (function
;;; parameters, let-bindings), NOT from the global trait registry.
;;; Includes subtype-aware resolution and E2001 error messages.
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
  "(ns test-cap4)")

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

;; Helper: run code and return results (list of result strings/errors)
(define (run s)
  (parameterize ([current-prelude-env shared-global-env]
                 [current-ns-context shared-ns-context]
                 [current-module-registry shared-module-reg]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry shared-trait-reg]
                 [current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg]
                 [current-capability-registry shared-capability-reg])
    (process-string s)))

(define (run-last s) (last (run s)))

;; Helper: run and check if last result is an error
(define (run-error? s)
  (define results (run s))
  (define last-result (last results))
  (prologos-error? last-result))

;; Helper: run and get last result (which may be an error)
(define (run-last-raw s)
  (define results (run s))
  (last results))

;; ========================================
;; Capability scope tracking
;; ========================================

(test-case "capability-scope/direct-resolution"
  ;; A function with a capability parameter calling another function
  ;; that requires the same capability should succeed.
  ;; needs-cap requires {c :0 ReadCap}, has-cap provides it.
  (define result
    (run-last
      (string-append
        "(capability TestCap)\n"
        "(def needs-cap : (Pi (c :0 TestCap) (Pi (x :w Nat) Nat))"
        " := (fn (c :0 TestCap) (fn (x :w Nat) x)))\n"
        "(def has-cap : (Pi (c :0 TestCap) (Pi (x :w Nat) Nat))"
        " := (fn (c :0 TestCap) (fn (x :w Nat) (needs-cap x))))")))
  ;; Should succeed — the ReadCap from the outer lambda resolves
  (check-true (string? result)
              "has-cap should define successfully with capability in scope")
  (check-true (string-contains? result "defined")
              "should say 'defined'"))

(test-case "capability-scope/missing-capability-error"
  ;; A function WITHOUT the required capability should produce E2001 error.
  (define result
    (run-last-raw
      (string-append
        "(capability MissCap)\n"
        "(def needs-miss : (Pi (c :0 MissCap) (Pi (x :w Nat) Nat))"
        " := (fn (c :0 MissCap) (fn (x :w Nat) x)))\n"
        "(def no-cap : (Pi (x :w Nat) Nat)"
        " := (fn (x :w Nat) (needs-miss x)))")))
  ;; Should fail — no MissCap in scope
  (check-true (prologos-error? result)
              "no-cap should fail without capability in scope"))

(test-case "capability-scope/nested-scopes"
  ;; Inner function can use capability from outer scope
  (define result
    (run-last
      (string-append
        "(capability NestCap)\n"
        "(def needs-nest : (Pi (c :0 NestCap) (Pi (x :w Nat) Nat))"
        " := (fn (c :0 NestCap) (fn (x :w Nat) x)))\n"
        ;; Two nested lambdas — capability from outermost
        "(def nested : (Pi (c :0 NestCap) (Pi (y :w Nat) (Pi (z :w Nat) Nat)))"
        " := (fn (c :0 NestCap) (fn (y :w Nat) (fn (z :w Nat) (needs-nest y)))))")))
  (check-true (string? result)
              "nested function should resolve capability from outer scope")
  (check-true (string-contains? result "defined")))

;; ========================================
;; Subtype-aware resolution
;; ========================================

(test-case "capability-scope/subtype-resolution"
  ;; If scope has FsCap and constraint needs ReadCap,
  ;; and ReadCap <: FsCap, the resolution should succeed.
  ;; (The standard capability hierarchy is loaded from prelude.)
  (define result
    (run-last
      (string-append
        ;; needs-read requires ReadCap
        "(def needs-read : (Pi (c :0 ReadCap) (Pi (x :w Nat) Nat))"
        " := (fn (c :0 ReadCap) (fn (x :w Nat) x)))\n"
        ;; has-fs has FsCap — should satisfy ReadCap (ReadCap <: FsCap)
        "(def has-fs : (Pi (c :0 FsCap) (Pi (x :w Nat) Nat))"
        " := (fn (c :0 FsCap) (fn (x :w Nat) (needs-read x))))")))
  (check-true (string? result)
              "FsCap should satisfy ReadCap requirement (ReadCap <: FsCap)")
  (check-true (string-contains? result "defined")))

(test-case "capability-scope/subtype-insufficient"
  ;; If scope has ReadCap and constraint needs FsCap,
  ;; ReadCap is insufficient (ReadCap <: FsCap, but not the other way).
  (define result
    (run-last-raw
      (string-append
        "(def needs-fs : (Pi (c :0 FsCap) (Pi (x :w Nat) Nat))"
        " := (fn (c :0 FsCap) (fn (x :w Nat) x)))\n"
        "(def has-read : (Pi (c :0 ReadCap) (Pi (x :w Nat) Nat))"
        " := (fn (c :0 ReadCap) (fn (x :w Nat) (needs-fs x))))")))
  ;; ReadCap is NOT a supertype of FsCap, so this should fail
  (check-true (prologos-error? result)
              "ReadCap should NOT satisfy FsCap requirement"))

(test-case "capability-scope/transitive-subtype"
  ;; Transitive: ReadCap <: FsCap <: SysCap
  ;; If scope has SysCap, it should satisfy ReadCap (ReadCap <: FsCap <: SysCap).
  (define result
    (run-last
      (string-append
        "(def needs-read2 : (Pi (c :0 ReadCap) (Pi (x :w Nat) Nat))"
        " := (fn (c :0 ReadCap) (fn (x :w Nat) x)))\n"
        "(def has-sys : (Pi (c :0 SysCap) (Pi (x :w Nat) Nat))"
        " := (fn (c :0 SysCap) (fn (x :w Nat) (needs-read2 x))))")))
  (check-true (string? result)
              "SysCap should satisfy ReadCap (transitive: ReadCap <: FsCap <: SysCap)")
  (check-true (string-contains? result "defined")))

;; ========================================
;; Multiple capabilities
;; ========================================

(test-case "capability-scope/multiple-capabilities"
  ;; A function with both ReadCap and HttpCap can call functions requiring either.
  (define result
    (run-last
      (string-append
        "(def needs-http : (Pi (c :0 HttpCap) (Pi (x :w Nat) Nat))"
        " := (fn (c :0 HttpCap) (fn (x :w Nat) x)))\n"
        "(def needs-read3 : (Pi (c :0 ReadCap) (Pi (x :w Nat) Nat))"
        " := (fn (c :0 ReadCap) (fn (x :w Nat) x)))\n"
        "(def has-both : (Pi (c1 :0 ReadCap) (Pi (c2 :0 HttpCap) (Pi (x :w Nat) Nat)))"
        " := (fn (c1 :0 ReadCap) (fn (c2 :0 HttpCap) (fn (x :w Nat) (needs-read3 x)))))")))
  (check-true (string? result)
              "has-both should resolve ReadCap from scope")
  (check-true (string-contains? result "defined")))

(test-case "capability-scope/multiple-capabilities-second"
  ;; Same setup, but calling needs-http — should resolve HttpCap from scope.
  (define result
    (run-last
      (string-append
        "(def needs-http2 : (Pi (c :0 HttpCap) (Pi (x :w Nat) Nat))"
        " := (fn (c :0 HttpCap) (fn (x :w Nat) x)))\n"
        "(def has-both2 : (Pi (c1 :0 ReadCap) (Pi (c2 :0 HttpCap) (Pi (x :w Nat) Nat)))"
        " := (fn (c1 :0 ReadCap) (fn (c2 :0 HttpCap) (fn (x :w Nat) (needs-http2 x)))))")))
  (check-true (string? result)
              "has-both2 should resolve HttpCap from scope")
  (check-true (string-contains? result "defined")))

;; ========================================
;; Pure functions (no capabilities)
;; ========================================

(test-case "capability-scope/pure-function-no-constraints"
  ;; A pure function (no capability params) calling another pure function — should work.
  (define result
    (run-last
      (string-append
        "(def pure-fn : (Pi (x :w Nat) Nat) := (fn (x :w Nat) x))\n"
        "(def call-pure : (Pi (x :w Nat) Nat) := (fn (x :w Nat) (pure-fn x)))")))
  (check-true (string? result))
  (check-true (string-contains? result "defined")))

;; ========================================
;; E2001 error message format
;; ========================================

(test-case "capability-scope/e2001-error-message"
  ;; The error message should mention the capability name and suggest adding it.
  (define result
    (run-last-raw
      (string-append
        "(capability AuditCap)\n"
        "(def needs-audit : (Pi (c :0 AuditCap) (Pi (x :w Nat) Nat))"
        " := (fn (c :0 AuditCap) (fn (x :w Nat) x)))\n"
        "(def no-audit : (Pi (x :w Nat) Nat)"
        " := (fn (x :w Nat) (needs-audit x)))")))
  (check-true (prologos-error? result)
              "should produce an error")
  (define msg (prologos-error-message result))
  (check-true (string-contains? msg "E2001")
              "error should contain E2001 code")
  (check-true (string-contains? msg "AuditCap")
              "error should mention the capability name"))

;; ========================================
;; Capability types usable as types (no regression)
;; ========================================

(test-case "capability-scope/type-in-pi-position"
  ;; Capability types should still work in Pi type positions (Phase 1 regression)
  (define result (run-last "(infer (Pi (fs :0 ReadCap) Nat))"))
  (check-true (string? result))
  (check-true (string-contains? result "Type")))

(test-case "capability-scope/prelude-capabilities-available"
  ;; Standard capabilities should be available from prelude (Phase 3 regression)
  (parameterize ([current-capability-registry shared-capability-reg])
    (check-true (capability-type? 'ReadCap))
    (check-true (capability-type? 'WriteCap))
    (check-true (capability-type? 'FsCap))
    (check-true (capability-type? 'NetCap))
    (check-true (capability-type? 'SysCap))))
