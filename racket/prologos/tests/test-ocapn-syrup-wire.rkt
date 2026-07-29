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
(imports (prologos::ocapn::handshake :refer (hex-to-bytes)))
(imports (prologos::data::string :as str :refer ()))
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

(test-case "syrup-wire/a bare null is NOT wire-encodable"
  ;; There is no null form in the Syrup dialect -- the reference codec has
  ;; none. `syrup-null` is our internal "no value", and it means exactly one
  ;; thing on the wire: a record's EMPTY argument sequence. Standalone it is a
  ;; bug, and it now encodes to a poison record no peer will accept rather
  ;; than to `n`, which our own frame reader rejects.
  (check-contains (run-last "(eval (encode syrup-null))")
                  "<20'prologos:unencodable4'null>"))

(test-case "syrup-wire/an unencodable refr does not silently vanish from a list"
  ;; It used to encode as "", which deleted the element and handed the peer a
  ;; well-formed list of the WRONG ARITY.
  (check-contains
   (run-last "(eval (encode (syrup-list (cons (syrup-refr 3N) (cons (syrup-int 1) nil)))))")
   "prologos:unencodable"))

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

(test-case "syrup-wire/a null payload is a ZERO-ARG record, not a null argument"
  (check-contains
   (run-last "(eval (encode (syrup-tagged \"op\" syrup-null)))") "\"<2'op>\""))

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

(test-case "syrup-wire/decode rejects \"n\" -- there is no null on this wire"
  ;; Accepting a form we can never re-emit makes decode/re-encode a non-inverse,
  ;; which is exactly what breaks signature verification. `ocapn-framing.rkt`
  ;; already rejected byte 110; this makes the two agree.
  (check-contains
   (run-last "(eval (decode-value \"n\"))") "none"))

(test-case "syrup-wire/decode \"5+\" = some int"
  (check-contains
   (run-last "(eval (decode-value \"5+\"))") "syrup-int"))

(test-case "syrup-wire/decode \"\" (empty) = none"
  (check-contains
   (run-last "(eval (decode-value \"\"))") "none"))

;; ========================================
;; Round-trip
;; ========================================

(test-case "syrup-wire/roundtrip a zero-arg record"
  (check-contains
   (run-last "(eval (re-encode (unwrap-or syrup-null (decode-value \"<1'f>\"))))")
   "<1'f>"))

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

(test-case "syrup-wire/a string's length prefix counts CODE POINTS, not UTF-8 bytes"
  ;; Every String in this codec holds one byte per code point (Latin-1) -- that
  ;; is what the frame FFI hands us and what the outbound path re-encodes with
  ;; `string->bytes/latin-1`. So the prefix is `str::length` for strings and
  ;; symbols exactly as it is for bytes.
  ;;
  ;; These two used to assert the opposite, on the reasoning that "strings hold
  ;; text, so the spec's byte length applies". Nothing in this stack is UTF-8:
  ;; a UTF-8 "é" arrives as the TWO code points 0xC3 0xA9 and must go back out
  ;; as `2"` plus those two. Measuring the single code point U+00E9 as its
  ;; 2-byte UTF-8 form emitted a prefix no peer could follow -- and
  ;; `string->bytes/latin-1` raises outright on anything above U+00FF, so the
  ;; value the old test pinned could never have been sent at all.
  (check-contains
   (run-last "(eval (encode (syrup-string \"é\")))")
   "1\\\"")
  (check-contains
   (run-last "(eval (encode (syrup-symbol \"é\")))")
   "1'"))

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

;; ========================================
;; Splicing re-encoder — the signature-verification gate
;; ========================================
;;
;; `encode` renders a value we BUILT; `re-encode` renders a value we DECODED.
;; They disagree on multi-arg records, and the disagreement is unavoidable:
;; the decoder maps both `<tag a b>` and `<tag [a b]>` to the same value, so
;; one encoder cannot restore both.
;;
;; This matters because third-party-handoff signatures are computed over the
;; BYTES of an inner `<desc:handoff-receive ...>` record. Verification is only
;; possible if we can reproduce those bytes exactly. The frame below is a real
;; 716-byte `withdraw-gift` captured off the wire from the upstream Python
;; test suite -- 9 records, 6 of them multi-arg.
;;
;; This test is a GATE, not a nicety. If re-encoding is wrong, every signature
;; check fails as BAD SIGNATURE rather than as an error -- indistinguishable
;; from correct rejection while in fact rejecting everything, including the
;; handoff tests that pass today.

(define handoff-frame-hex
  (string-append
   "3c3130276f703a64656c697665723c313127646573633a6578706f7274302b3e5b31332777697468647261772d676966"
   "743c313727646573633a7369672d656e76656c6f70653c323027646573633a68616e646f66662d726563656976653332"
   "3a80ac24325c0ad104eac168cbf1bb67e0c349c27382cad5db5f91e18d5c8a030a33323a777564ff857cb2fcbd0d0875"
   "022cc41238916df90ef232d93a30ade85b2e39bd302b3c313727646573633a7369672d656e76656c6f70653c31372764"
   "6573633a68616e646f66662d676976655b3130277075626c69632d6b65795b33276563635b3527637572766537274564"
   "32353531395d5b3527666c616773352765646473615d5b31277133323a391573c713b294f67c7204444dd1fce674148c"
   "917d8a8b84978acca5075d73315d5d5d3c3130276f6361706e2d706565723136277463702d74657374696e672d6f6e6c"
   "793332224a616451302b2b527a7344344d2b3430754c785457566156714d31304463424a7b3422686f73743922313237"
   "2e302e302e313422706f7274352232323131367d3e33323a08ca4310f071e32dbc3b9be78c096fc44b42b174e738e8c4"
   "8add887b9eba7aa833323aec9c661defc354b829fd2b426fe8429a653a0716cb021395c5c4612d2a20b1d5373a6d792d"
   "676966743e5b37277369672d76616c5b352765646473615b31277233323a42677932d969d60d651f41502c29b1032395"
   "f95ba8c247d3b64f4ad1549d8ee25d5b31277333323aa44329e7b3236014d99ac390750a78dde4259388028d3ddf27bb"
   "74468e5aeb005d5d5d3e3e5b37277369672d76616c5b352765646473615b31277233323a02790feb642506c02deb0d69"
   "ec7cee5f7fe6188ae7e77c1a3c3429445c9dd6a35d5b31277333323a0017ee74376826395ff3e3280d3b959f9d911126"
   "fc8587e0243dde06e103bf095d5d5d3e5d663c313827646573633a696d706f72742d6f626a656374302b3e3e"))

(define (frame-expr body)
  (format "(eval (let ((raw (hex-to-bytes \"~a\"))) ~a))" handoff-frame-hex body))

(test-case "syrup-wire/the captured handoff frame decodes at all"
  ;; A decode failure would surface as `none` and make every assertion below
  ;; vacuously green.
  (check-false
   (string-contains?
    (run-last (frame-expr "(decode-value raw)"))
    "none")))

(test-case "syrup-wire/re-encode round-trips the handoff frame BYTE-IDENTICALLY"
  (check-contains
   (run-last
    (frame-expr "(str::eq raw (re-encode (unwrap-or syrup-null (decode-value raw))))"))
   "true"))

(test-case "syrup-wire/encode round-trips it too -- the two readings are now one"
  ;; This used to pin the OPPOSITE: `encode` wrapped a record's argument
  ;; sequence where `re-encode` spliced it, so `encode` came back +2 bytes per
  ;; multi-arg record and the test existed to stop anyone "simplifying"
  ;; re-encode into encode.
  ;;
  ;; The asymmetry was not a design, it was the decoder losing information.
  ;; `<tag [a b]>` and `<tag a b>` decoded to the SAME value, so no single
  ;; encoder could restore both and the two functions took opposite guesses --
  ;; which meant `encode` emitted `<op:deliver [to args ap rm]>` for a record
  ;; upstream reads as four fields. `decode-record-with` now distinguishes the
  ;; two shapes, so both encoders splice and both are inverses.
  ;;
  ;; The remaining difference is dict key ordering, and it is deliberate: see
  ;; the dict tests below.
  (check-contains
   (run-last
    (frame-expr "(str::eq raw (encode (unwrap-or syrup-null (decode-value raw))))"))
   "true"))

(test-case "syrup-wire/a record payload splices, under both encoders"
  (check-contains
   (run-last "(eval (re-encode (unwrap-or syrup-null (decode-value \"<1'f1+2+>\"))))")
   "<1'f1+2+>")
  (check-contains
   (run-last "(eval (encode (unwrap-or syrup-null (decode-value \"<1'f1+2+>\"))))")
   "<1'f1+2+>")
  ;; Single-arg and zero-arg records too.
  (check-contains
   (run-last "(eval (re-encode (unwrap-or syrup-null (decode-value \"<1'f1+>\"))))")
   "<1'f1+>")
  (check-contains
   (run-last "(eval (re-encode (unwrap-or syrup-null (decode-value \"<1'f>\"))))")
   "<1'f>"))

(test-case "syrup-wire/a record whose ONE argument is a list keeps its brackets"
  ;; The case that made re-encode a non-inverse: `<f [1 2]>` (one list
  ;; argument) and `<f 1 2>` (two arguments) decoded to the same value, and
  ;; re-encode turned the first into the second -- a 1-arg record silently
  ;; becoming a 2-arg one, ON THE SIGNATURE-VERIFICATION PATH.
  (check-contains
   (run-last "(eval (re-encode (unwrap-or syrup-null (decode-value \"<1'f[1+2+]>\"))))")
   "<1'f[1+2+]>")
  (check-contains
   (run-last "(eval (encode (unwrap-or syrup-null (decode-value \"<1'f[1+2+]>\"))))")
   "<1'f[1+2+]>"))

(test-case "syrup-wire/decode-value rejects trailing residue"
  ;; It used to discard `decode-at`'s offset, so a frame with garbage after a
  ;; valid value parsed clean at every layer -- including the one that decides
  ;; what a signature covers.
  (check-contains (run-last "(eval (decode-value \"5+xyz\"))") "none")
  (check-contains (run-last "(eval (decode-value \"1+\"))")    "syrup-int"))

(test-case "syrup-wire/decode rejects non-canonical and malformed forms"
  ;; Leading zeros: `00000000005\"hello` and `5\"hello` must not both decode,
  ;; or a peer can vary the bytes it signs without varying the value we check.
  (check-contains (run-last "(eval (decode-value \"005\\\"hello\"))") "none")
  ;; A dict is a flat alternating key/value sequence, so an odd count is
  ;; malformed. This used to decode into a one-element `syrup-dict`.
  (check-contains (run-last "(eval (decode-value \"{1+}\"))") "none"))

(test-case "syrup-wire/encode sorts dict keys; re-encode preserves the peer's order"
  ;; Syrup canonicalises a dict by sorted encoded key, so frames WE originate
  ;; must be sorted. But `re-encode` exists to reproduce a peer's bytes for
  ;; signature verification, and a peer that sent a non-canonical dict must be
  ;; reproduced as sent -- otherwise every such signature fails, which looks
  ;; exactly like correct rejection while rejecting everything.
  (check-contains
   (run-last "(eval (encode (syrup-dict (cons (syrup-string \"port\") (cons (syrup-string \"1\") (cons (syrup-string \"host\") (cons (syrup-string \"2\") nil)))))))")
   "{4\\\"host1\\\"24\\\"port1\\\"1}")
  (check-contains
   (run-last "(eval (re-encode (unwrap-or syrup-null (decode-value \"{4\\\"port1\\\"14\\\"host1\\\"2}\"))))")
   "{4\\\"port1\\\"14\\\"host1\\\"2}"))

(test-case "syrup-wire/encode bytes uses the RAW byte count, not the UTF-8 count"
  ;; `syrup-bytes` smuggles raw bytes as one code point per byte, so its length
  ;; prefix is `str::length`. Using `str::bytes-length` (right for text)
  ;; re-measures those code points as UTF-8 and inflates the prefix on any byte
  ;; >= 0x80 -- which is every cryptographic payload in a third-party handoff.
  ;;
  ;; This 32-byte key measures 32 code points but 51 UTF-8 bytes. We used to
  ;; emit `51:` in front of 32 bytes: an unparseable frame, outbound.
  (check-contains
   (run-last
    (string-append
     "(eval (str::slice (encode (syrup-bytes (hex-to-bytes \""
     "80ac24325c0ad104eac168cbf1bb67e0c349c27382cad5db5f91e18d5c8a030a"
     "\"))) 0 3))"))
   "32:")
  ;; ASCII is unaffected -- both measures agree, which is why every earlier
  ;; test passed.
  (check-contains
   (run-last "(eval (encode (syrup-bytes \"abc\")))") "3:abc"))

;; ========================================
;; Sets and floats
;; ========================================
;;
;; The reference emits both (`contrib/syrup.py`: `b'#' + sorted(items) + b'$'`
;; and `b'D' + struct.pack('>d', obj)`), so a peer that sent one used to get a
;; decode failure from us and no diagnostic.

(test-case "syrup-wire/a set decodes"
  (check-contains
   (run-last "(eval (decode-value \"#1+2+$\"))") "syrup-set"))

(test-case "syrup-wire/encode sorts set items; re-encode preserves the peer's order"
  ;; Same split as dicts, for the same reason: we owe a peer canonical bytes
  ;; on frames we originate, and byte-exact reproduction on frames it sent.
  (check-contains
   (run-last "(eval (encode (syrup-set (cons (syrup-int 2) (cons (syrup-int 1) nil)))))")
   "#1+2+$")
  (check-contains
   (run-last "(eval (re-encode (unwrap-or syrup-null (decode-value \"#2+1+$\"))))")
   "#2+1+$"))

(test-case "syrup-wire/a double round-trips byte-exactly"
  ;; `D` + 8 bytes. Carried as raw bytes INCLUDING the marker rather than as a
  ;; number: nothing here does float arithmetic, and a signature covers bytes.
  (check-contains
   (run-last "(eval (re-encode (unwrap-or syrup-null (decode-value \"D12345678\"))))")
   "D12345678"))

(test-case "syrup-wire/a single float round-trips as F, not widened to D"
  ;; Decoding `F` to a number and re-emitting the `D` the reference prefers
  ;; would preserve the value and change the bytes -- exactly what re-encode
  ;; exists to prevent.
  (check-contains
   (run-last "(eval (re-encode (unwrap-or syrup-null (decode-value \"F1234\"))))")
   "F1234"))

(test-case "syrup-wire/a truncated float is rejected"
  (check-contains (run-last "(eval (decode-value \"D123\"))") "none"))

(test-case "syrup-wire/a set nested in a record decodes and round-trips"
  (check-contains
   (run-last "(eval (re-encode (unwrap-or syrup-null (decode-value \"<1'f#1+2+$>\"))))")
   "<1'f#1+2+$>"))
