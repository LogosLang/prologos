#lang racket/base

;;;
;;; Tests for prologos::ocapn::locator — peer addressing.
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
  "(ns test-ocapn-locator)
(imports (prologos::ocapn::locator :refer-all))
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

(define (check-contains actual substr)
  (check-true (string-contains? actual substr)
              (format "Expected ~s to contain ~s" actual substr)))

;; ========================================
;; Constructors elaborate
;; ========================================

(test-case "locator/loopback-locator elaborates"
  (check-contains
   (run-last "(eval (mk-loopback-locator \"peer-A\"))")
   "Locator"))

(test-case "locator/tcp-locator elaborates"
  (check-contains
   (run-last "(eval (mk-tcp-locator \"peer-B\" \"127.0.0.1\" (suc (suc zero))))")
   "Locator"))

;; ========================================
;; Selectors
;; ========================================

(test-case "locator/loc-host on tcp returns host"
  (check-contains
   (run-last "(eval (loc-host (mk-tcp-locator \"x\" \"127.0.0.1\" zero)))")
   "127.0.0.1"))

(test-case "locator/loc-host on loopback returns empty"
  (check-contains
   (run-last "(eval (loc-host (mk-loopback-locator \"x\")))")
   "\""))

(test-case "locator/loc-port on tcp returns port"
  (check-contains
   (run-last "(eval (loc-port (mk-tcp-locator \"x\" \"127.0.0.1\" (suc (suc (suc zero))))))")
   "3N"))

(test-case "locator/loc-designator round-trips"
  (check-contains
   (run-last "(eval (loc-designator (mk-tcp-locator \"my-peer\" \"127.0.0.1\" zero)))")
   "my-peer"))

;; ========================================
;; Transport-name
;; ========================================

(test-case "locator/transport-name loopback"
  (check-contains
   (run-last "(eval (transport-name (loc-transport (mk-loopback-locator \"x\"))))")
   "loopback"))

(test-case "locator/transport-name tcp-testing-only"
  (check-contains
   (run-last "(eval (transport-name (loc-transport (mk-tcp-locator \"x\" \"h\" zero))))")
   "tcp-testing-only"))

;; ========================================
;; Equality
;; ========================================

(test-case "locator/equal locators"
  (check-contains
   (run-last "(eval (locator-eq? (mk-loopback-locator \"a\") (mk-loopback-locator \"a\")))")
   "true"))

(test-case "locator/different designators not equal"
  (check-contains
   (run-last "(eval (locator-eq? (mk-loopback-locator \"a\") (mk-loopback-locator \"b\")))")
   "false"))

(test-case "locator/different transports not equal"
  (check-contains
   (run-last "(eval (locator-eq? (mk-loopback-locator \"x\") (mk-tcp-locator \"x\" \"h\" zero)))")
   "false"))

(test-case "locator/transport-eq? loopback ≠ tcp"
  (check-contains
   (run-last "(eval (transport-eq? tr-loopback tr-tcp-testing-only))")
   "false"))

(test-case "locator/transport-eq? tcp = tcp"
  (check-contains
   (run-last "(eval (transport-eq? tr-tcp-testing-only tr-tcp-testing-only))")
   "true"))
