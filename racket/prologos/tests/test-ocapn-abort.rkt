#lang racket/base

;;;
;;; Phase 10 of OCapN interop — graceful op:abort teardown.
;;;
;;; Both peers send op:start-session + op:abort and observe the
;;; other's abort. Verifies clean shutdown: no frame lost, both
;;; sides exit cleanly, abort reasons round-trip.
;;;

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
  (printf "abort: SKIPPED — node + tools/interop/node_modules missing.~n")
  (exit 0))

(printf "abort: deps present, running graceful-abort test~n")

(define shared-preamble
  "(ns test-ocapn-abort)
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

(define (extract-value-bytes s)
  (define m (regexp-match #px"^(\".*\") : String$" s))
  (unless m
    (error 'extract-value-bytes "couldn't extract bytes from: ~s" s))
  (read (open-input-string (cadr m))))

(test-case "abort/bidirectional graceful op:abort teardown"
  (define racket-start
    (extract-value-bytes
     (run-last
      "(eval (encode-op (op-start-session
                            \"0.1\"
                            (syrup-string \"tcp-testing-only:peer-racket\"))))")))
  (define racket-abort
    (extract-value-bytes
     (run-last
      "(eval (encode-op (op-abort \"goodbye-from-racket\")))")))
  (define expected-node-start
    (extract-value-bytes
     (run-last
      "(eval (encode-op (op-start-session
                            \"0.1\"
                            (syrup-string \"tcp-testing-only:peer-node\"))))")))
  (define expected-node-abort
    (extract-value-bytes
     (run-last
      "(eval (encode-op (op-abort \"goodbye-from-node\")))")))

  (define listener (tcp-listen 0 4 #t "127.0.0.1"))
  (define-values (_a local-port _b _c) (tcp-addresses listener #t))
  (define peer-abort-path (path->string (build-path INTEROP-DIR "peer-abort.mjs")))
  (define node-exe (find-executable-path "node"))
  (define-values (proc proc-out proc-in proc-err)
    (subprocess #f #f #f node-exe peer-abort-path (number->string local-port)))

  (define-values (cin cout) (tcp-accept listener))

  ;; Send our two frames.
  (write-string racket-start cout) (write-string "\n" cout)
  (write-string racket-abort cout) (write-string "\n" cout)
  (flush-output cout)

  ;; Read Node's two frames.
  (define n-start (read-line cin 'linefeed))
  (define n-abort (read-line cin 'linefeed))

  (close-output-port cout)
  (close-input-port cin)
  (tcp-close listener)

  (define child-stdout (port->string proc-out))
  (define child-stderr (port->string proc-err))
  (close-input-port proc-out)
  (close-output-port proc-in)
  (close-input-port proc-err)
  (subprocess-wait proc)

  (check-equal? n-start expected-node-start
                "Node's start-session bytes != expected")
  (check-equal? n-abort expected-node-abort
                "Node's op:abort bytes != expected")
  (printf "  Racket-side: both Node frames match expected bytes~n")

  (check-equal? (subprocess-status proc) 0
                (format "node peer-abort exited non-zero
                  stdout: ~s
                  stderr: ~s"
                        child-stdout child-stderr))
  (check-true (regexp-match? #px"\"ok\":true" child-stdout)
              (format "expected ok:true: ~s" child-stdout))
  (check-true (regexp-match? #px"\"saw_session_locator\":\"tcp-testing-only:peer-racket\"" child-stdout)
              (format "expected racket's locator in node output: ~s" child-stdout))
  (check-true (regexp-match? #px"\"saw_abort_reason\":\"goodbye-from-racket\"" child-stdout)
              (format "expected goodbye-from-racket: ~s" child-stdout))
  (printf "  Node-side: ~a~n" (string-trim child-stdout)))
