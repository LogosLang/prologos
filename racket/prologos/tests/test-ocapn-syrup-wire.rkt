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
  (parameterize ([current-file-module-network-ref (make-module-network)]
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
    (values (current-file-module-network-ref)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-ctor-registry)
            (current-type-meta))))

(define (run s)
  (parameterize ([current-file-module-network-ref shared-global-env]
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

;; ========================================
;; Phase 19 — syrup-bytes (opaque bytestring)
;; ========================================

(test-case "syrup-wire/encode bytes \"abc\" = `3:abc`"
  (check-contains
   (run-last "(eval (encode (syrup-bytes \"abc\")))") "\"3:abc\""))

(test-case "syrup-wire/encode empty bytes = `0:`"
  (check-contains
   (run-last "(eval (encode (syrup-bytes \"\")))") "\"0:\""))

(test-case "syrup-wire/decode `3:abc` -> some syrup-bytes"
  (check-contains
   (run-last "(eval (decode-value \"3:abc\"))") "syrup-bytes"))

(test-case "syrup-wire/roundtrip bytes \"hi\""
  (check-contains
   (run-last "(eval (decode-value (encode (syrup-bytes \"hi\"))))")
   "syrup-bytes"))

;; ========================================
;; Phase 20 — UTF-8 byte-length aware encoding
;; ========================================

(test-case "syrup-wire/encode UTF-8 string \"é\" uses byte length 2 not char length 1"
  ;; "é" is 1 char, 2 bytes in UTF-8 (0xC3 0xA9). Wire form: 2"é
  (check-contains
   (run-last "(eval (encode (syrup-string \"é\")))")
   "2\\\""))

(test-case "syrup-wire/encode UTF-8 string \"αβγ\" uses byte length 6 not char length 3"
  ;; Each Greek letter is 2 bytes in UTF-8. 3 chars × 2 = 6 bytes.
  (check-contains
   (run-last "(eval (encode (syrup-string \"αβγ\")))")
   "6\\\""))

;; ========================================
;; Syrup DICTIONARIES — `{ k1 v1 k2 v2 ... }`
;; ========================================
;;
;; The last unimplemented Syrup form, and its absence was invisible until it
;; wasn't: `decode-at` dispatched on n / t / f / [ / < / digits and fell to
;; `none` on anything else, so EVERY frame carrying an OCapN location — which
;; expresses its netlayer hints as a dict — failed to decode, with no
;; diagnostic. That is what blocked the third-party-handoff tests.

(test-case "syrup-wire/decode an empty dict `{}`"
  (check-contains
   (run-last "(eval (decode-value \"{}\"))") "syrup-dict"))

(test-case "syrup-wire/decode a one-entry dict"
  (check-contains
   (run-last "(eval (decode-value \"{4\\\"host9\\\"127.0.0.1}\"))") "syrup-dict"))

(test-case "syrup-wire/roundtrip a dict is BYTE-IDENTICAL"
  ;; We neither re-sort nor re-order, so re-encoding a decoded dict reproduces
  ;; the exact input bytes. Syrup canonicalises by sorted key on the wire; the
  ;; peer already sent it canonical, so preserving order preserves canonicity.
  (check-contains
   (run-last
    "(eval (encode (unwrap-or syrup-null (decode-value \"{4\\\"host9\\\"127.0.0.14\\\"port5\\\"22116}\"))))")
   "{4\\\"host9\\\"127.0.0.14\\\"port5\\\"22116}"))

(test-case "syrup-wire/a dict nested inside a record decodes"
  ;; This is the shape that actually failed: <ocapn-peer ... {hints}>.
  (check-contains
   (run-last
    "(eval (decode-value \"<10'ocapn-peer16'tcp-testing-only{4\\\"host9\\\"127.0.0.1}>\"))")
   "syrup-tagged"))

(test-case "syrup-wire/a dict IS encodable; a dict holding a refr is NOT"
  ;; encodable? must recurse into a dict rather than reject it outright — the
  ;; mechanical arm-migration initially cloned `false` from the promise arm,
  ;; which would have made every location-bearing frame unencodable.
  (check-contains
   (run-last "(eval (encodable? (syrup-dict (cons (syrup-symbol \"k\") (cons (syrup-nat 1N) nil)))))")
   "true")
  (check-contains
   (run-last "(eval (encodable? (syrup-dict (cons (syrup-symbol \"k\") (cons (syrup-refr 3N) nil)))))")
   "false"))

(test-case "syrup-wire/a dict is not a promise and has no promise id"
  ;; Both mis-cloned by the mechanical pass off the syrup-promise arm.
  (check-contains
   (run-last "(eval (promise? (syrup-dict nil)))") "false")
  (check-contains
   (run-last "(eval (get-promise (syrup-dict nil)))") "none"))
