#lang racket/base

;;;
;;; Tests for prologos::ocapn::captp-wire — Phase 2 of OCapN
;;; interop. CapTP frame encoder/decoder built on top of Phase-1's
;;; pure Syrup codec.
;;;
;;; Test set is small (~5 cases) — encoder/decoder calls reduce
;;; through deeply structural matches and the reducer is the
;;; bottleneck. Each test case is ~30s on Racket 9.1.
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
  "(ns test-ocapn-captp-wire)
(imports (prologos::ocapn::syrup :refer-all))
(imports (prologos::ocapn::message :refer-all))
(imports (prologos::ocapn::syrup-wire :refer-all))
(imports (prologos::ocapn::captp-wire :refer-all))
(imports (prologos::data::list :refer (List nil cons)))
(imports (prologos::data::option :refer (Option some none unwrap-or)))
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

(define (check-contains actual substr [msg #f])
  (check-true (string-contains? actual substr)
              (or msg (format "Expected ~s to contain ~s" actual substr))))

;; ========================================
;; Encoder — verify structure, not full bytes
;; ========================================

(test-case "captp-wire/encode op:abort emits record bytes"
  (check-contains
   (run-last "(eval (encode-op (op-abort \"hello\")))")
   "op:abort"))

(test-case "captp-wire/encode op:gc-answer emits record bytes"
  (check-contains
   (run-last "(eval (encode-op (op-gc-answer (suc zero))))")
   "op:gc-answer"))

(test-case "captp-wire/encode op:deliver-only includes desc:export"
  (check-contains
   (run-last
    "(eval (encode-op (op-deliver-only zero (syrup-string \"args\"))))")
   "desc:export"))

;; ========================================
;; Decoder — round-trip the simplest ops
;; ========================================

(test-case "captp-wire/round-trip op:abort"
  (check-contains
   (run-last "(eval (decode-op (encode-op (op-abort \"bye\"))))")
   "op-abort"))

(test-case "captp-wire/round-trip op:gc-answer"
  (check-contains
   (run-last
    "(eval (decode-op (encode-op (op-gc-answer (suc zero)))))")
   "op-gc-answer"))

;; ========================================
;; Decoder — graceful failure on bad input
;; ========================================

(test-case "captp-wire/decode garbage returns none"
  (check-contains
   (run-last "(eval (decode-op \"garbage\"))")
   "none"))
