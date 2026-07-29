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

;; ========================================
;; The SPEC forms of the GC ops
;; ========================================
;;
;; `op:gc-exports` / `op:gc-answers` are what a conforming peer sends;
;; the singular `op:gc-export` / `op:gc-answer` this module was built
;; around are in neither the spec nor upstream's CAPTP_TYPES. Before
;; these arms existed, every inbound GC frame from a real peer decoded
;; to `none` and was dropped in silence.

(test-case "captp-wire/decode op:gc-exports (two parallel lists)"
  (check-contains
   (run-last "(eval (decode-op \"<13'op:gc-exports[3+7+][1+2+]>\"))")
   "op-gc-exports"))

(test-case "captp-wire/decode op:gc-answers (one list)"
  (check-contains
   (run-last "(eval (decode-op \"<13'op:gc-answers[4+9+]>\"))")
   "op-gc-answers"))

(test-case "captp-wire/op:gc-answers with a second list is REJECTED"
  ;; It used to take the first list and drop the rest without a word --
  ;; the one op left without an arity gate.
  (check-contains
   (run-last "(eval (decode-op \"<13'op:gc-answers[4+][9+]>\"))")
   "none"))

;; ========================================
;; Arity and label gates
;; ========================================

(test-case "captp-wire/op:deliver with a FIFTH field is rejected"
  ;; Every dispatcher read positionally and never checked the tail, so a
  ;; frame with extra fields decoded as though it were well-formed.
  (check-contains
   (run-last
    "(eval (decode-op \"<10'op:deliver<11'desc:export1+>[]ff5\\\"EXTRA>\"))")
   "none"))

(test-case "captp-wire/an unknown descriptor label in the target slot is rejected"
  ;; `unwrap-desc` discarded the label, so `<totally-bogus 3>` routed
  ;; straight into the export table at position 3.
  (check-contains
   (run-last
    "(eval (decode-op \"<10'op:deliver<13'totally-bogus3+>[]ff>\"))")
   "none"))

(test-case "captp-wire/a NEGATIVE answer position is rejected, not read as absent"
  ;; `wire-nat` returns none on a negative, which made a malformed slot
  ;; indistinguishable from `false` -- i.e. from fire-and-forget.
  (check-contains
   (run-last
    "(eval (decode-op \"<10'op:deliver<11'desc:export1+>[]5-f>\"))")
   "none"))

(test-case "captp-wire/a well-formed op:deliver still decodes"
  ;; The gates above are only meaningful if the good case survives them.
  (check-contains
   (run-last
    "(eval (decode-op \"<10'op:deliver<11'desc:export1+>[4\\\"ping]0+<18'desc:import-object2+>>\"))")
   "op-deliver"))

;; ========================================
;; op:start-session — the four-field wire record
;; ========================================

(test-case "captp-wire/a 4-field start-session takes the locator from field 3"
  ;; Field 1 is the session PUBKEY. This bound it as the locator, so the
  ;; loc slot held the pubkey s-expression.
  (check-contains
   (run-last
    "(eval (decode-op \"<16'op:start-session3\\\"1.06'PUBKEY3'LOC3'SIG>\"))")
   "LOC"))

;; ========================================
;; The answer-position slot is a BARE integer
;; ========================================

(test-case "captp-wire/encode-op writes a bare answer position, not <desc:answer N>"
  ;; Upstream reads slot 2 raw, so a wrapped position comes back as a
  ;; record that never compares equal to the position named in a later
  ;; op:gc-answers.
  (define got
    (run-last
     "(eval (encode-op (op-deliver zero (syrup-string \"hi\") (some Nat (suc zero)) (none Nat))))"))
  (check-true (string-contains? got "1+") "answer position should be bare")
  (check-false (string-contains? got "desc:answer")
               "answer position should NOT be wrapped in desc:answer"))

(test-case "captp-wire/encode-op wraps the args slot in a list"
  ;; A peer iterates the args slot directly; a bare value raises inside
  ;; its receive loop and the peer drops the connection.
  (check-contains
   (run-last
    "(eval (encode-op (op-deliver-only zero (syrup-string \"ping\"))))")
   "[4\\\"ping]"))
