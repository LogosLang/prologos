#lang racket/base

;;;
;;; Phase 43 — pipelining wire-out forwarding cross-impl gate.
;;;
;;; Validates the Phase 41/42 closure end-to-end with @endo/ocapn:
;;;
;;;   1. Node sends op:start-session.
;;;   2. Node sends Q1: op:deliver target=<desc:export 0>
;;;        args=<desc:export 99>          (a refr in args)
;;;        answer-pos=<desc:answer 7> false.
;;;   3. Node sends Q2 (pipelined): op:deliver target=<desc:answer 7>
;;;        args="forwardable" false false.
;;;   4. Racket processes via drive-handshake-q-and-pipeline:
;;;      a. Q1 dispatched to echo actor → resolves local promise(7) with
;;;         <desc:export 99> (the echoed args).
;;;      b. Q2 dispatched via dispatch-pipeline-on-our-q → queues
;;;         "forwardable" at bridge-side pipelined-msgs[pid].
;;;      c. Drain runs echo, fulfills promise(7) with <desc:export 99>.
;;;      d. Pump-outbound emits resolution bytes for Q1 + walks
;;;         pipelined-msgs. syrup-as-export-target sees <desc:export 99>;
;;;         lookup-actor 99 = none → Phase 41 wire forwarding fires.
;;;         Emits <op:deliver <desc:export 99> "forwardable" false false>.
;;;   5. Racket sends 3 frames to Node (session + Q1 reply + forwarding).
;;;   6. Node verifies session received + Q1 reply targets desc:answer 7
;;;      with echoed refr in args + forwarding targets desc:export 99
;;;      with payload "forwardable".

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
  (error 'test-ocapn-pipeline-forwarding-interop
         "Node + tools/interop/node_modules required.~n  Run: cd tools/interop && npm install"))

(printf "pipeline-forwarding-interop: deps present, running test~n")

(define shared-preamble
  "(ns test-ocapn-pipeline-forwarding-interop)
(imports (prologos::ocapn::core :refer-all))
(imports (prologos::ocapn::message :refer-all))
(imports (prologos::ocapn::syrup :refer-all))
(imports (prologos::ocapn::syrup-wire :refer-all))
(imports (prologos::ocapn::captp-wire :refer-all))
(imports (prologos::ocapn::captp-core :refer-all))
(imports (prologos::ocapn::captp-interop-helpers :refer-all))
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
;; Wire-out forwarding cross-impl interop
;; ========================================

(test-case "pipeline-forwarding-interop/Node sends Q+pipelined, Racket resolves to refr, emits forwarding bytes"
  (define listener (tcp-listen 0 4 #t "127.0.0.1"))
  (define-values (_a local-port _b _c) (tcp-addresses listener #t))

  (define peer-script (path->string (build-path INTEROP-DIR "peer-pipeline-forwarding.mjs")))
  (define node-exe (find-executable-path "node"))
  (define-values (proc proc-out proc-in proc-err)
    (subprocess #f #f #f node-exe peer-script (number->string local-port)))

  (define-values (cin cout) (tcp-accept listener))

  (define n-session (read-line cin 'linefeed))
  (define n-q1 (read-line cin 'linefeed))
  (define n-q2 (read-line cin 'linefeed))
  (check-pred string? n-session "expected Node start-session")
  (check-pred string? n-q1 "expected Node Q1 (with refr in args)")
  (check-pred string? n-q2 "expected Node Q2 (pipelined)")
  (printf "pipeline-forwarding-interop: node-q1 = ~s~n" n-q1)
  (printf "pipeline-forwarding-interop: node-q2 = ~s~n" n-q2)

  (define our-ver "0.1")
  (define our-loc "tcp-testing-only:peer-racket-pipeline-forwarding")
  (define driver-blob
    (extract-value-bytes
     (run-last (format
                "(eval (drive-handshake-q-and-pipeline ~s ~s ~s ~s))"
                our-ver our-loc n-q1 n-q2))))
  (printf "pipeline-forwarding-interop: driver-blob = ~s~n" driver-blob)
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
  (printf "pipeline-forwarding-interop: node exit=~a stdout=~s~n" exit-code child-stdout)

  (check-equal? exit-code 0
                (format "Node peer-pipeline-forwarding exited non-zero. stderr=~s" child-stderr))
  (check-true (regexp-match? #rx"\"ok\":true" child-stdout)
              (format "expected ok:true; got: ~s" child-stdout))
  (check-true (regexp-match? #rx"\"saw_forwarding\":true" child-stdout)
              (format "expected forwarding bytes; got: ~s" child-stdout))
  (check-true (regexp-match? #rx"\"forwarding_target\":99" child-stdout)
              (format "expected forwarding to <desc:export 99>; got: ~s" child-stdout))
  (check-true (regexp-match? #rx"\"forwarding_payload\":\"forwardable\"" child-stdout)
              (format "expected payload 'forwardable'; got: ~s" child-stdout)))
