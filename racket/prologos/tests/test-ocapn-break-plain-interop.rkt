#lang racket/base

;;;
;;; Phase 49 — break-forwarding + plain-value-as-error cross-impl gate.
;;;
;;; Validates Phase 45 (break-forwarding) and Phase 46 (plain-value-as-
;;; error) end-to-end against @endo/ocapn:
;;;
;;; Sub-test 1 — break-forwarding (peer-break-forwarding.mjs):
;;;   - Node sends Q1 (target=desc:export 0, args=desc:export 99,
;;;     ap=desc:answer 7) and Q2 (pipelined: target=desc:answer 7,
;;;     args="forward-me", ap=desc:answer 88).
;;;   - Racket invokes drive-handshake-break-q-and-pipeline which
;;;     dispatches both, then BREAKS the local promise with reason
;;;     "rejected" (skipping drain so the actor's resolve never fires).
;;;   - Pump emits broken-resolution at peer's q-pos 7 + Phase 45
;;;     break-forward at peer's queued ap 88, both wrapped in
;;;     <Error "rejected">.
;;;   - Node verifies both frames are op:deliver-to-desc:answer with
;;;     <Error "rejected"> args.
;;;
;;; Sub-test 2 — plain-value-as-error (peer-plain-value-error.mjs):
;;;   - Node sends Q1 with args=plain-string "i-am-a-string" and
;;;     Q2 pipelined with ap=desc:answer 88.
;;;   - Racket invokes drive-handshake-q-and-pipeline (existing helper);
;;;     echo resolves with the plain string verbatim.
;;;   - Pump emits resolution at peer's q-pos 7 + Phase 46 plain-value
;;;     error answer at peer's queued ap 88 with reason
;;;     "deliver-to-non-callable".
;;;   - Node verifies the reply echoes the plain string AND the
;;;     error-answer carries <Error "deliver-to-non-callable">.

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
  (error 'test-ocapn-break-plain-interop
         "Node + tools/interop/node_modules required.~n  Run: cd tools/interop && npm install"))

(printf "break-plain-interop: deps present, running test~n")

(define shared-preamble
  "(ns test-ocapn-break-plain-interop)
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

(define (run-peer-test peer-script-name driver-call our-loc-suffix)
  ;; Spawn the Node peer; wait for it to send 3 frames (session+Q1+Q2);
  ;; have Racket compute the response blob via `driver-call`; write it
  ;; back to the socket; close; capture peer's exit + stdout.
  (define listener (tcp-listen 0 4 #t "127.0.0.1"))
  (define-values (_a local-port _b _c) (tcp-addresses listener #t))

  (define peer-script (path->string (build-path INTEROP-DIR peer-script-name)))
  (define node-exe (find-executable-path "node"))
  (define-values (proc proc-out proc-in proc-err)
    (subprocess #f #f #f node-exe peer-script (number->string local-port)))

  (define-values (cin cout) (tcp-accept listener))

  (define n-session (read-line cin 'linefeed))
  (define n-q1 (read-line cin 'linefeed))
  (define n-q2 (read-line cin 'linefeed))
  (check-pred string? n-session "expected Node start-session")
  (check-pred string? n-q1 "expected Node Q1")
  (check-pred string? n-q2 "expected Node Q2")
  (printf "break-plain-interop[~a]: node-q1=~s~n" peer-script-name n-q1)
  (printf "break-plain-interop[~a]: node-q2=~s~n" peer-script-name n-q2)

  (define our-ver "0.1")
  (define our-loc (string-append "tcp-testing-only:peer-racket-" our-loc-suffix))
  (define driver-blob
    (extract-value-bytes
     (run-last (driver-call our-ver our-loc n-q1 n-q2))))
  (printf "break-plain-interop[~a]: driver-blob=~s~n" peer-script-name driver-blob)
  (check-true (> (string-length driver-blob) 30)
              (format "driver blob suspiciously short: ~s" driver-blob))

  (write-string driver-blob cout)
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
  (printf "break-plain-interop[~a]: node exit=~a stdout=~s~n"
          peer-script-name exit-code child-stdout)
  (values exit-code child-stdout child-stderr))

;; ========================================
;; Sub-test 1: break-forwarding cross-impl
;; ========================================

(test-case "break-plain-interop/Node sends Q+pipelined, Racket breaks promise, emits Error answers"
  (define-values (exit-code child-stdout child-stderr)
    (run-peer-test
     "peer-break-forwarding.mjs"
     (lambda (our-ver our-loc n-q1 n-q2)
       (format "(eval (drive-handshake-break-q-and-pipeline ~s ~s ~s ~s ~s))"
               our-ver our-loc n-q1 n-q2 "rejected"))
     "break-forwarding"))

  (check-equal? exit-code 0
                (format "Node peer-break-forwarding exited non-zero. stderr=~s" child-stderr))
  (check-true (regexp-match? #rx"\"ok\":true" child-stdout)
              (format "expected ok:true; got: ~s" child-stdout))
  (check-true (regexp-match? #rx"\"saw_reply_to_q1\":true" child-stdout)
              (format "expected reply to Q1; got: ~s" child-stdout))
  (check-true (regexp-match? #rx"\"saw_break_forward\":true" child-stdout)
              (format "expected break-forward bytes; got: ~s" child-stdout))
  (check-true (regexp-match? #rx"\"reply_is_error\":true" child-stdout)
              (format "expected reply args wrapped in Error; got: ~s" child-stdout))
  (check-true (regexp-match? #rx"\"break_is_error\":true" child-stdout)
              (format "expected break-forward args wrapped in Error; got: ~s" child-stdout))
  (check-true (regexp-match? #rx"\"reply_reason\":\"rejected\"" child-stdout)
              (format "expected reply reason 'rejected'; got: ~s" child-stdout))
  (check-true (regexp-match? #rx"\"break_reason\":\"rejected\"" child-stdout)
              (format "expected break reason 'rejected'; got: ~s" child-stdout)))

;; ========================================
;; Sub-test 2: plain-value-as-error cross-impl
;; ========================================

(test-case "break-plain-interop/Node sends Q+pipelined, Racket resolves to plain value, emits error at peer's ap"
  (define-values (exit-code child-stdout child-stderr)
    (run-peer-test
     "peer-plain-value-error.mjs"
     (lambda (our-ver our-loc n-q1 n-q2)
       (format "(eval (drive-handshake-q-and-pipeline ~s ~s ~s ~s))"
               our-ver our-loc n-q1 n-q2))
     "plain-value-error"))

  (check-equal? exit-code 0
                (format "Node peer-plain-value-error exited non-zero. stderr=~s" child-stderr))
  (check-true (regexp-match? #rx"\"ok\":true" child-stdout)
              (format "expected ok:true; got: ~s" child-stdout))
  (check-true (regexp-match? #rx"\"saw_reply_to_q1\":true" child-stdout)
              (format "expected reply to Q1; got: ~s" child-stdout))
  (check-true (regexp-match? #rx"\"saw_error_answer\":true" child-stdout)
              (format "expected error-answer bytes; got: ~s" child-stdout))
  (check-true (regexp-match? #rx"\"reply_echoes_string\":true" child-stdout)
              (format "expected Q1 reply to echo plain string; got: ~s" child-stdout))
  (check-true (regexp-match? #rx"\"error_is_error_wrapped\":true" child-stdout)
              (format "expected error answer wrapped in Error; got: ~s" child-stdout))
  (check-true (regexp-match? #rx"\"error_reason\":\"deliver-to-non-callable\"" child-stdout)
              (format "expected error reason 'deliver-to-non-callable'; got: ~s" child-stdout)))
