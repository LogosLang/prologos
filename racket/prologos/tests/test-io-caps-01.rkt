#lang racket/base

;;;
;;; test-io-caps-01.rkt — IO Capability Extension Tests
;;;
;;; Phase IO-A3: Tests for new leaf capabilities (AppendCap, StatCap),
;;; new composite (IOCap), and restructured subtype hierarchy.
;;; Verifies both direct and transitive subtype relationships.
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
  "(ns test-io-caps)")

(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg
                shared-capability-reg
                shared-subtype-reg)
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
                 [current-capability-registry prelude-capability-registry])
    (install-module-loader!)
    (process-string shared-preamble)
    (values (current-global-env)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-capability-registry)
            (current-subtype-registry))))

;; ========================================
;; New capabilities registered
;; ========================================

(test-case "io-caps/append-cap-registered"
  (parameterize ([current-capability-registry shared-capability-reg])
    (check-true (capability-type? 'AppendCap)
                "AppendCap should be registered")))

(test-case "io-caps/stat-cap-registered"
  (parameterize ([current-capability-registry shared-capability-reg])
    (check-true (capability-type? 'StatCap)
                "StatCap should be registered")))

(test-case "io-caps/io-cap-registered"
  (parameterize ([current-capability-registry shared-capability-reg])
    (check-true (capability-type? 'IOCap)
                "IOCap should be registered")))

;; ========================================
;; Direct subtype relationships
;; ========================================

(test-case "io-caps/append-cap-subtype-fs-cap"
  (check-true (subtype-pair? 'AppendCap 'FsCap)
              "AppendCap <: FsCap"))

(test-case "io-caps/stat-cap-subtype-fs-cap"
  (check-true (subtype-pair? 'StatCap 'FsCap)
              "StatCap <: FsCap"))

(test-case "io-caps/fs-cap-subtype-io-cap"
  (check-true (subtype-pair? 'FsCap 'IOCap)
              "FsCap <: IOCap"))

(test-case "io-caps/net-cap-subtype-io-cap"
  (check-true (subtype-pair? 'NetCap 'IOCap)
              "NetCap <: IOCap"))

(test-case "io-caps/stdio-cap-subtype-io-cap"
  (check-true (subtype-pair? 'StdioCap 'IOCap)
              "StdioCap <: IOCap"))

(test-case "io-caps/io-cap-subtype-sys-cap"
  (check-true (subtype-pair? 'IOCap 'SysCap)
              "IOCap <: SysCap"))

;; ========================================
;; Transitive subtype relationships
;; ========================================

(test-case "io-caps/read-cap-transitive-io-cap"
  ;; ReadCap <: FsCap <: IOCap
  (check-true (subtype-pair? 'ReadCap 'IOCap)
              "ReadCap <: IOCap (transitive)"))

(test-case "io-caps/read-cap-transitive-sys-cap"
  ;; ReadCap <: FsCap <: IOCap <: SysCap
  (check-true (subtype-pair? 'ReadCap 'SysCap)
              "ReadCap <: SysCap (transitive through IOCap)"))

(test-case "io-caps/append-cap-transitive-sys-cap"
  ;; AppendCap <: FsCap <: IOCap <: SysCap
  (check-true (subtype-pair? 'AppendCap 'SysCap)
              "AppendCap <: SysCap (transitive)"))

(test-case "io-caps/stat-cap-transitive-sys-cap"
  ;; StatCap <: FsCap <: IOCap <: SysCap
  (check-true (subtype-pair? 'StatCap 'SysCap)
              "StatCap <: SysCap (transitive)"))

(test-case "io-caps/stdio-cap-transitive-sys-cap"
  ;; StdioCap <: IOCap <: SysCap
  (check-true (subtype-pair? 'StdioCap 'SysCap)
              "StdioCap <: SysCap (transitive through IOCap)"))

(test-case "io-caps/http-cap-transitive-sys-cap"
  ;; HttpCap <: NetCap <: IOCap <: SysCap
  (check-true (subtype-pair? 'HttpCap 'SysCap)
              "HttpCap <: SysCap (transitive through IOCap)"))

;; ========================================
;; Negative: no false subtypes
;; ========================================

(test-case "io-caps/read-cap-not-net-cap"
  (check-false (subtype-pair? 'ReadCap 'NetCap)
               "ReadCap should NOT be subtype of NetCap"))

(test-case "io-caps/append-cap-not-net-cap"
  (check-false (subtype-pair? 'AppendCap 'NetCap)
               "AppendCap should NOT be subtype of NetCap"))

(test-case "io-caps/http-cap-not-fs-cap"
  (check-false (subtype-pair? 'HttpCap 'FsCap)
               "HttpCap should NOT be subtype of FsCap"))
