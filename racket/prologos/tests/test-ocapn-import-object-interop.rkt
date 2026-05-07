#lang racket/base

;;;
;;; Phase 37 — desc:import-object cross-impl gate.
;;;
;;; Validates the desc:import-object decode/encode contract with
;;; @endo/ocapn as the foreign counterparty:
;;;
;;;   1. Node sends op:start-session.
;;;   2. Node sends op:deliver target=<desc:export 0>
;;;        args = ["hello-import", <desc:import-object 11>]
;;;        answer-pos=<desc:answer 200>.
;;;   3. Racket processes the inbound via drive-handshake-and-deliver:
;;;      a. emits our session bytes (handshake reply)
;;;      b. dispatches the deliver through the echo actor → reply
;;;         bytes targeting <desc:answer 200> with echoed args
;;;   4. Racket sends concat to Node.
;;;   5. Node verifies it received both frames AND that the echoed
;;;      reply args contain a Record labeled "desc:import-object"
;;;      with id=11n (i.e., Racket round-tripped the new desc:* tag
;;;      faithfully — it didn't drop it, didn't transform it).
;;;
;;; Symmetric to test-ocapn-refr-passing-interop.rkt (which exercises
;;; the desc:export side); together they cover both export-shaped and
;;; import-object-shaped refrs in cross-impl wire round-trip.

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
  (error 'test-ocapn-import-object-interop
         "Node + tools/interop/node_modules required.~n  Run: cd tools/interop && npm install"))

(printf "import-object-interop: deps present, running test~n")

(define shared-preamble
  "(ns test-ocapn-import-object-interop)
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
;; desc:import-object cross-impl interop
;; ========================================

(test-case "import-object-interop/Node sends Q with desc:import-object in args, Racket echoes it back intact"
  (define listener (tcp-listen 0 4 #t "127.0.0.1"))
  (define-values (_a local-port _b _c) (tcp-addresses listener #t))

  (define peer-script (path->string (build-path INTEROP-DIR "peer-import-object.mjs")))
  (define node-exe (find-executable-path "node"))
  (define-values (proc proc-out proc-in proc-err)
    (subprocess #f #f #f node-exe peer-script (number->string local-port)))

  (define-values (cin cout) (tcp-accept listener))

  (define n-session (read-line cin 'linefeed))
  (define n-q (read-line cin 'linefeed))
  (check-pred string? n-session "expected Node start-session")
  (check-pred string? n-q "expected Node deliver-with-import-object")
  (printf "import-object-interop: node-q = ~s~n" n-q)

  (define our-ver "0.1")
  (define our-loc "tcp-testing-only:peer-racket-import-object")
  (define driver-blob
    (extract-value-bytes
     (run-last (format
                "(eval (drive-handshake-and-deliver ~s ~s ~s))"
                our-ver our-loc n-q))))
  (printf "import-object-interop: driver-blob = ~s~n" driver-blob)
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
  (printf "import-object-interop: node exit=~a stdout=~s~n" exit-code child-stdout)

  (check-equal? exit-code 0
                (format "Node peer-import-object exited non-zero. stderr=~s" child-stderr))
  (check-true (regexp-match? #rx"\"ok\":true" child-stdout)
              (format "expected ok:true; got: ~s" child-stdout))
  (check-true (regexp-match? #rx"\"saw_import_object_in_reply\":true" child-stdout)
              (format "expected echo to round-trip desc:import-object; got: ~s" child-stdout))
  (check-true (regexp-match? #rx"\"import_object_id\":11" child-stdout)
              (format "expected import_object_id=11; got: ~s" child-stdout)))
