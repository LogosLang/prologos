#lang racket/base

;;;
;;; Tests for prologos::ocapn::syrup-wire — Phase 1 of OCapN
;;; interop. Encoder + decoder + round-trip + encodability check
;;; + golden vectors derived from the OCapN Syrup spec.
;;;
;;; Test set is intentionally small (~12 cases) — encoder calls
;;; reduce through deeply structural pattern matches and the
;;; reducer is the bottleneck, not the function itself. A larger
;;; matrix lives in
;;; `examples/2026-04-29-syrup-wire-acceptance.prologos` and
;;; runs at module-load time via `process-file` (Level 3).
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
  "(ns test-ocapn-syrup-wire)
(imports (prologos::ocapn::syrup :refer-all))
(imports (prologos::ocapn::syrup-wire :refer-all))
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
;; Encoder — golden vectors
;; ========================================
;;
;; Hand-derived from the OCapN Syrup spec.

(test-case "syrup-wire/encode null = \"n\""
  (check-contains (run-last "(eval (encode syrup-null))") "\"n\""))

(test-case "syrup-wire/encode bool true = \"t\""
  (check-contains (run-last "(eval (encode (syrup-bool true)))") "\"t\""))

(test-case "syrup-wire/encode int 5 = \"5+\""
  (check-contains (run-last "(eval (encode (syrup-int 5)))") "\"5+\""))

(test-case "syrup-wire/encode int -7 = \"7-\""
  (check-contains
   (run-last "(eval (encode (syrup-int (int-neg 7))))") "\"7-\""))

(test-case "syrup-wire/encode string \"hi\" = `2\"hi`"
  (check-contains
   (run-last "(eval (encode (syrup-string \"hi\")))") "\"2\\\"hi\""))

(test-case "syrup-wire/encode tagged \"op\" null = \"<2'opn>\""
  (check-contains
   (run-last "(eval (encode (syrup-tagged \"op\" syrup-null)))") "\"<2'opn>\""))

;; ========================================
;; Encodability check
;; ========================================

(test-case "syrup-wire/encode-safe refr = none"
  (check-contains
   (run-last "(eval (encode-safe (syrup-refr zero)))") "none"))

(test-case "syrup-wire/encode-safe null = some"
  (check-contains
   (run-last "(eval (encode-safe syrup-null))") "some"))

;; ========================================
;; Decoder — atoms
;; ========================================

(test-case "syrup-wire/decode \"n\" = some null"
  (check-contains
   (run-last "(eval (decode-value \"n\"))") "syrup-null"))

(test-case "syrup-wire/decode \"5+\" = some int"
  (check-contains
   (run-last "(eval (decode-value \"5+\"))") "syrup-int"))

(test-case "syrup-wire/decode \"\" (empty) = none"
  (check-contains
   (run-last "(eval (decode-value \"\"))") "none"))

;; ========================================
;; Round-trip
;; ========================================

(test-case "syrup-wire/roundtrip null"
  (check-contains
   (run-last "(eval (decode-value (encode syrup-null)))") "syrup-null"))

(test-case "syrup-wire/roundtrip int 42"
  (check-contains
   (run-last "(eval (decode-value (encode (syrup-int 42))))") "syrup-int"))
