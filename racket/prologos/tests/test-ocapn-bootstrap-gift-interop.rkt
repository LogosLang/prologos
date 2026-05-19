#lang racket/base

;;;
;;; Phase 52b cross-impl wire-shape gate (revised 2026-05-18).
;;;
;;; Verifies that the OCapN bootstrap-method-dispatch shape we emit
;;; for gift handoff (op:deliver to <desc:export 0> with args = (symbol
;;; "deposit-gift" / "withdraw-gift") + payload) is decode-able by
;;; @endo/ocapn's Syrup decoder AND has the structural shape @endo
;;; would treat as a method dispatch on bootstrap.
;;;
;;; This is a WIRE-SHAPE-only gate: it does NOT exercise @endo's
;;; deposit-gift / withdraw-gift HANDLERS (those require signed
;;; HandoffReceive envelopes + key-pair management beyond our scope).
;;; Validation here is "does our wire form match what @endo's decoder
;;; expects to receive for the canonical handoff dispatch."

(require rackunit
         racket/list
         racket/string
         racket/system
         racket/port
         racket/tcp
         racket/runtime-path
         racket/file
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

(define-runtime-path INTEROP-DIR "../../../tools/interop")

(define (interop-deps-present?)
  (and (find-executable-path "node")
       (file-exists?
        (build-path INTEROP-DIR "node_modules" "@endo" "ocapn"
                    "src" "syrup" "js-representation.js"))))

(unless (interop-deps-present?)
  (error 'test-ocapn-bootstrap-gift-interop
         "Node + tools/interop/node_modules required.~n  Run: cd tools/interop && npm install"))

(printf "bootstrap-gift-interop: deps present, running test~n")

(define shared-preamble
  "(ns test-ocapn-bootstrap-gift-interop)
(imports (prologos::ocapn::core :refer-all))
(imports (prologos::ocapn::message :refer-all))
(imports (prologos::ocapn::syrup :refer-all))
(imports (prologos::ocapn::syrup-wire :refer-all))
(imports (prologos::ocapn::captp-wire :refer-all))
(imports (prologos::ocapn::captp-bridge :refer-all))
(imports (prologos::ocapn::bridge-interop-helpers :refer-all))
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

(define (extract-value-bytes s)
  (define m (regexp-match #px"^(\".*\") : String$" s))
  (unless m
    (error 'extract-value-bytes "couldn't extract bytes from: ~s" s))
  (read (open-input-string (cadr m))))

;; ========================================
;; Bootstrap-method gift wire-shape interop
;; ========================================

(test-case "bootstrap-gift-interop/Racket emits op:deliver-to-bootstrap with method symbols; @endo decoder accepts the shape"
  (define listener (tcp-listen 0 4 #t "127.0.0.1"))
  (define-values (_a local-port _b _c) (tcp-addresses listener #t))

  (define peer-script (path->string (build-path INTEROP-DIR "peer-bootstrap-gift.mjs")))
  (define node-exe (find-executable-path "node"))
  (define-values (proc proc-out proc-in proc-err)
    (subprocess #f #f #f node-exe peer-script (number->string local-port)))

  (define-values (cin cout) (tcp-accept listener))

  ;; Build the 3-frame blob (session + deposit-gift + withdraw-gift).
  ;; Numbers must match the peer's expectations:
  ;;   gid=99, xid=7, ap=4 (resolver answer-pos)
  ;; 99 = suc^99 zero — represented in the helper via a chain of sucs.
  ;; For readability, use the helper that takes Nats directly via
  ;; (suc-of-nat 99) — but Prologos doesn't have that yet, so we
  ;; build the small chain by hand. 99 sucs is too long; use 7 / 4
  ;; directly. The peer expects gid=99, but we'll send gid=7 and
  ;; tell the peer to expect 7 via env var. Easier: hardcode small
  ;; numbers everywhere.
  ;;
  ;; Update: peer-bootstrap-gift.mjs currently hardcodes GIFT_ID=99n.
  ;; Use small numbers consistent with both ends — change the peer
  ;; to match.
  (define our-ver "0.1")
  (define our-loc "tcp-testing-only:peer-racket-bootstrap-gift")
  (define blob
    (extract-value-bytes
     (run-last
      (format "(eval (gift-bytes-trio ~s ~s (suc (suc (suc (suc (suc (suc (suc (suc (suc (suc zero)))))))))) (suc (suc (suc (suc (suc (suc (suc zero))))))) (suc (suc (suc (suc zero))))))"
              our-ver our-loc))))
  ;; gid = suc^10 zero = 10; xid = suc^7 zero = 7; ap = suc^4 zero = 4
  ;; But peer wants gid=99, xid=7, ap=4. Use small numbers consistent
  ;; on both sides — update peer to expect gid=10.
  (printf "bootstrap-gift-interop: blob length = ~a~n" (string-length blob))
  (check-true (> (string-length blob) 30)
              (format "blob suspiciously short: ~s" blob))

  (write-string blob cout)
  (flush-output cout)
  (close-output-port cout)
  (close-input-port cin)
  (tcp-close listener)

  (define child-stdout (port->string proc-out))
  (define child-stderr (port->string proc-err))
  (close-output-port proc-in)
  (close-input-port proc-out)
  (close-input-port proc-err)
  (subprocess-wait proc)
  (define exit-code (subprocess-status proc))
  (printf "bootstrap-gift-interop: node exit=~a stdout=~s~n" exit-code child-stdout)
  (when (not (= exit-code 0))
    (printf "bootstrap-gift-interop: node stderr=~s~n" child-stderr))

  (check-true (regexp-match? #rx"\"saw_session\":true" child-stdout)
              (format "expected saw_session; got: ~s" child-stdout))
  (check-true (regexp-match? #rx"\"saw_deposit\":true" child-stdout)
              (format "expected saw_deposit; got: ~s" child-stdout))
  (check-true (regexp-match? #rx"\"saw_withdraw\":true" child-stdout)
              (format "expected saw_withdraw; got: ~s" child-stdout))
  (check-true (regexp-match? #rx"\"deposit_shape_ok\":true" child-stdout)
              (format "expected deposit shape OK; got: ~s" child-stdout))
  (check-true (regexp-match? #rx"\"withdraw_shape_ok\":true" child-stdout)
              (format "expected withdraw shape OK; got: ~s" child-stdout)))
