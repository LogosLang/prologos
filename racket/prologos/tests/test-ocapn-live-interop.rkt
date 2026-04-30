#lang racket/base

;;;
;;; Phase 5 of OCapN interop — live Racket↔Node wire exchange.
;;;
;;; Two end-to-end tests, both running real OS-level child
;;; processes that exchange CapTP bytes over a real TCP socket:
;;;
;;;   Test A. Prologos sends → Node decodes
;;;     Racket binds an ephemeral port, spawns
;;;     `node tools/interop/peer-recv.mjs <port>`, accepts the
;;;     child's connection, sends `encode-op (op-abort
;;;     "phase-5-says-hi")` plus a newline, and asserts the
;;;     child's stdout reports a successfully-decoded `op:abort`
;;;     record with the matching reason.
;;;
;;;   Test B. Node sends → Prologos decodes
;;;     Racket spawns `node tools/interop/peer-send.mjs op-abort`,
;;;     reads the child's chosen port, dials it, reads one line
;;;     of bytes, decodes via Prologos's `decode-op`, asserts the
;;;     resulting CapTPOp is `(op-abort "phase-5-says-hi")`.
;;;
;;; The Node side uses @endo/ocapn (the published JS reference);
;;; @endo/init has to be imported first to set up SES.
;;;
;;; The test is gated on `node` being on PATH AND
;;; `tools/interop/node_modules/@endo/ocapn` being present
;;; (i.e. `npm install` was run in tools/interop). If either is
;;; missing the test prints a SKIP message and exits 0 — keeps
;;; the suite green for environments that don't have Node
;;; available, while CI explicitly installs Node + the deps.
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
  (printf "live-interop: SKIPPED — node + tools/interop/node_modules missing.~n")
  (printf "live-interop: to enable, run `cd tools/interop && npm install`.~n")
  (exit 0))

(printf "live-interop: deps present, running cross-runtime tests~n")

;; ========================================
;; Prologos fixture
;; ========================================

(define shared-preamble
  "(ns test-ocapn-live-interop)
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

;; ========================================
;; Test A — Prologos sends, Node decodes
;; ========================================

(test-case "live-interop/prologos-sends → node-decodes (op:abort)"
  ;; 1. Compute the wire bytes for our op-abort.
  (define wire-bytes
    (extract-value-bytes
     (run-last
      "(eval (encode-op (op-abort \"phase-5-says-hi\")))")))
  ;; 2. Bind an ephemeral localhost port.
  (define listener (tcp-listen 0 4 #t "127.0.0.1"))
  (define-values (_a local-port _b _c) (tcp-addresses listener #t))
  (define peer-recv (path->string (build-path INTEROP-DIR "peer-recv.mjs")))
  (define node-exe (find-executable-path "node"))
  ;; 3. Spawn node peer-recv.
  (define-values (proc proc-out proc-in proc-err)
    (subprocess #f #f #f node-exe peer-recv (number->string local-port)))
  ;; 4. Accept ONE connection (the child's), send the bytes + '\n', close.
  (define-values (cin cout) (tcp-accept listener))
  (write-string wire-bytes cout)
  (write-string "\n" cout)
  (flush-output cout)
  (close-output-port cout)
  (close-input-port cin)
  ;; 5. Wait for child to exit; capture stdout/stderr.
  (define child-stdout (port->string proc-out))
  (define child-stderr (port->string proc-err))
  (close-input-port proc-out)
  (close-output-port proc-in)
  (close-input-port proc-err)
  (subprocess-wait proc)
  (tcp-close listener)
  ;; 6. Assert: child exited 0, JSON has ok=true and the right label/value.
  (check-equal? (subprocess-status proc) 0
                (format "node peer-recv exited non-zero
                  stdout: ~s
                  stderr: ~s"
                        child-stdout child-stderr))
  (check-true (regexp-match? #px"\"ok\":true" child-stdout)
              (format "expected ok:true in node output: ~s" child-stdout))
  (check-true (regexp-match? #px"\"label\":\"op:abort\"" child-stdout)
              (format "expected op:abort label: ~s" child-stdout))
  (check-true (regexp-match? #px"phase-5-says-hi" child-stdout)
              (format "expected reason \"phase-5-says-hi\": ~s" child-stdout))
  (printf "  Test A: node-decoded successfully: ~a~n"
          (string-trim child-stdout)))

;; ========================================
;; Test B — Node sends, Prologos decodes
;; ========================================

(test-case "live-interop/node-sends → prologos-decodes (op:abort)"
  (define peer-send (path->string (build-path INTEROP-DIR "peer-send.mjs")))
  (define node-exe (find-executable-path "node"))
  ;; 1. Spawn node peer-send.
  (define-values (proc proc-out proc-in proc-err)
    (subprocess #f #f #f node-exe peer-send "op-abort"))
  ;; 2. Read the chosen port from the child's first stdout line.
  (define port-line (read-line proc-out 'linefeed))
  (define remote-port
    (cond
      [(eof-object? port-line)
       (error 'live-interop "peer-send produced no port line; stderr=~s"
              (port->string proc-err))]
      [else
       (define n (string->number (string-trim port-line)))
       (unless n
         (error 'live-interop "peer-send first stdout line not numeric: ~s"
                port-line))
       n]))
  ;; 3. Connect, read one line of bytes, close.
  (define-values (rin rout) (tcp-connect "127.0.0.1" remote-port))
  (define received-line (read-line rin 'linefeed))
  (close-input-port rin)
  (close-output-port rout)
  ;; 4. Drain child stdout/err and reap.
  (define rest-stdout (port->string proc-out))
  (define child-stderr (port->string proc-err))
  (close-input-port proc-out)
  (close-output-port proc-in)
  (close-input-port proc-err)
  (subprocess-wait proc)
  ;; 5. Decode the bytes via Prologos.
  (check-true (string? received-line)
              (format "received-line not a string. stderr=~s rest-stdout=~s"
                      child-stderr rest-stdout))
  (check-equal? (subprocess-status proc) 0
                (format "node peer-send exited non-zero. stderr=~s" child-stderr))
  (define decode-result
    (run-last (format "(eval (decode-op ~v))" received-line)))
  (check-true (string-contains? decode-result "op-abort")
              (format "Prologos decode of node-sent bytes failed.
                received bytes: ~s
                Prologos result: ~s"
                      received-line decode-result))
  (check-true (string-contains? decode-result "phase-5-says-hi")
              (format "expected reason \"phase-5-says-hi\" in decode: ~s"
                      decode-result))
  (printf "  Test B: prologos-decoded successfully: ~a~n"
          (string-trim decode-result)))
