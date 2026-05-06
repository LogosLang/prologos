#lang racket/base

;;;
;;; Tests for prologos::ocapn::captp-session — session-typed CapTP
;;; sub-protocols. Validates that the session declarations parse and
;;; the example client `defproc`s elaborate against their session
;;; types.
;;;
;;; This is a "shape" test — we don't run the protocol, we check that
;;; the type-checker accepts the declared sessions.
;;;

(require rackunit
         racket/list
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

(define shared-preamble
  "(ns test-ocapn-captp)
(imports (prologos::ocapn::captp-session :refer-all))
(imports (prologos::ocapn::message :refer-all))
(imports (prologos::ocapn::syrup :refer-all))
(imports (prologos::data::option :refer (Option some none)))
")

(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg
                shared-ctor-reg
                shared-type-meta)
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
                 [current-spec-store (hasheq)])
    (install-module-loader!)
    (process-string shared-preamble)
    (values (current-prelude-env)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-ctor-registry)
            (current-type-meta))))

(define (run s)
  (parameterize ([current-prelude-env shared-global-env]
                 [current-ns-context shared-ns-context]
                 [current-module-registry shared-module-reg]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry shared-trait-reg]
                 [current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg]
                 [current-ctor-registry shared-ctor-reg]
                 [current-type-meta shared-type-meta])
    (process-string s)))

(define (run-last s) (last (run s)))

(define (check-no-error s)
  ;; Accept anything as long as it doesn't throw.
  (check-not-exn (lambda () (run s))))

;; ========================================
;; Sessions parse + register
;; ========================================
;;
;; We probe the global env for the session symbols. Just loading the
;; module via the preamble is the bulk of the test — if anything
;; fails to elaborate, the fixture set-up itself will throw.

(test-case "captp/CapTPHandshake session parses"
  ;; A simple smoke test: refer the symbol and check it resolves.
  (check-no-error "(infer CapTPHandshake)"))

(test-case "captp/CapTPDeliver session parses"
  (check-no-error "(infer CapTPDeliver)"))

(test-case "captp/CapTPListen session parses"
  (check-no-error "(infer CapTPListen)"))

(test-case "captp/CapTPDeliverOnly session parses"
  (check-no-error "(infer CapTPDeliverOnly)"))

(test-case "captp/CapTPGc session parses"
  (check-no-error "(infer CapTPGc)"))

;; ========================================
;; defproc clients elaborate
;; ========================================

(test-case "captp/handshake-client defproc elaborated"
  (check-no-error "(infer handshake-client)"))

(test-case "captp/deliver-only-client defproc elaborated"
  (check-no-error "(infer deliver-only-client)"))
