#lang racket/base

;;;
;;; Phase 34f — refr-in-args interop test.
;;;
;;; Tests Racket's auto-track-and-release flow for imported refrs
;;; end-to-end with @endo/ocapn:
;;;
;;;   1. Node connects, sends op:start-session.
;;;   2. Node sends op:deliver target=<desc:export 0>
;;;        args=(syrup-list ["ping", <desc:export 7>])
;;;        answer-pos=<desc:answer 100>.
;;;      The args carry a refr (desc:export 7) — peer is sharing
;;;      one of its exports with us. Racket's bridge auto-increments
;;;      imports-refcount[7].
;;;   3. Racket processes the inbound via
;;;      drive-handshake-deliver-and-release, which:
;;;      a. emits our session bytes (handshake reply)
;;;      b. dispatches the deliver through the echo actor → reply
;;;         bytes targeting <desc:answer 100>
;;;      c. calls release-import 7 1 → emits op:gc-export 7 1 bytes
;;;      Returns the framed concatenation of all three.
;;;   4. Racket sends the concat to Node.
;;;   5. Node verifies it received all three frames + the gc-export
;;;      has pos=7 and cnt=1; prints summary; exits 0.

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
  (error 'test-ocapn-refr-passing-interop
         "Node + tools/interop/node_modules required.~n  Run: cd tools/interop && npm install"))

(printf "refr-passing-interop: deps present, running test~n")

(define shared-preamble
  "(ns test-ocapn-refr-passing-interop)
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

(define (build-suc-tower n)
  (cond
    [(zero? n) "zero"]
    [else (format "(suc ~a)" (build-suc-tower (sub1 n)))]))

;; ========================================
;; Refr-passing interop
;; ========================================

(test-case "refr-passing-interop/Node sends Q with refr in args, Racket replies + emits op:gc-export"
  (define listener (tcp-listen 0 4 #t "127.0.0.1"))
  (define-values (_a local-port _b _c) (tcp-addresses listener #t))

  (define peer-script (path->string (build-path INTEROP-DIR "peer-refr-passing.mjs")))
  (define node-exe (find-executable-path "node"))
  (define-values (proc proc-out proc-in proc-err)
    (subprocess #f #f #f node-exe peer-script (number->string local-port)))

  (define-values (cin cout) (tcp-accept listener))

  ;; Read Node's two outbound frames: session + Q (with refr in args).
  (define n-session (read-line cin 'linefeed))
  (define n-q (read-line cin 'linefeed))
  (check-pred string? n-session "expected Node start-session")
  (check-pred string? n-q "expected Node deliver-with-refr")
  (printf "refr-passing-interop: node-q = ~s~n" n-q)

  ;; Drive: handshake + reply + release-import 7 1.
  ;; Returns concat of session-bytes + reply-bytes + op:gc-export bytes.
  (define our-ver "0.1")
  (define our-loc "tcp-testing-only:peer-racket-refr-passing")
  (define release-id 7)
  (define release-cnt 1)
  (define driver-blob
    (extract-value-bytes
     (run-last (format
                "(eval (drive-handshake-deliver-and-release ~s ~s ~s ~a ~a))"
                our-ver our-loc n-q
                (build-suc-tower release-id)
                (build-suc-tower release-cnt)))))
  (printf "refr-passing-interop: driver-blob = ~s~n" driver-blob)
  (check-true (> (string-length driver-blob) 30)
              (format "driver blob suspiciously short: ~s" driver-blob))

  ;; Send to Node.
  (write-string driver-blob cout)
  (flush-output cout)

  ;; Close our half so Node sees FIN, then drain + reap.
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
  (printf "refr-passing-interop: node exit=~a stdout=~s~n" exit-code child-stdout)

  (check-equal? exit-code 0
                (format "Node peer-refr-passing exited non-zero. stderr=~s" child-stderr))
  (check-true (regexp-match? #rx"\"ok\":true" child-stdout)
              (format "expected ok:true; got: ~s" child-stdout))
  (check-true (regexp-match? #rx"\"saw_gc_export\":true" child-stdout)
              (format "expected Node to receive op:gc-export; got: ~s" child-stdout))
  (check-true (regexp-match? #rx"\"gc_export_pos\":7" child-stdout)
              (format "expected gc_export_pos=7; got: ~s" child-stdout))
  (check-true (regexp-match? #rx"\"gc_export_cnt\":1" child-stdout)
              (format "expected gc_export_cnt=1; got: ~s" child-stdout)))
