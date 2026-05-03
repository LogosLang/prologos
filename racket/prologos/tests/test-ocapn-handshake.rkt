#lang racket/base

;;;
;;; Phase 6 of OCapN interop — bidirectional op:start-session
;;; handshake between a Prologos listener and a Node connector.
;;;
;;; Both sides send their own op:start-session and read the
;;; other's. The test asserts both directions via BYTE EQUALITY
;;; (not via decode):
;;;
;;;   - Racket-received bytes (from Node) must equal what Prologos
;;;     would emit for the same op:start-session.
;;;   - The Node child's stdout JSON must report `ok:true` and
;;;     the matching label/version/locator fields.
;;;
;;; Why byte-equality, not decode: Prologos's `decode-op` is
;;; quadratic-ish in the size of multi-arity records (~7 min on
;;; a 60-byte op:start-session), an artefact of the recursive
;;; `decode-many-loop` + `decode-record-with` evaluation in the
;;; Prologos reducer. The decoder is correct (it round-trips
;;; the values); it's just too slow for sub-second test budgets.
;;; Filed as a known-perf gap in the design doc; byte-equality
;;; is a stricter check anyway — if the bytes match, both impls
;;; trivially decode to the same SyrupValue.
;;;
;;; The 1-arity round-trip path (op:abort, op:gc-answer) is
;;; already covered by Phase 5's test-ocapn-live-interop.rkt.
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
  (printf "handshake: SKIPPED — node + tools/interop/node_modules missing.~n")
  (printf "handshake: to enable, run `cd tools/interop && npm install`.~n")
  (exit 0))

(printf "handshake: deps present, running bidirectional test~n")

(define shared-preamble
  "(ns test-ocapn-handshake)
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
;; Bidirectional handshake
;; ========================================

(test-case "handshake/bidirectional op:start-session exchange (byte equality)"
  ;; Compute both sides' canonical bytes via Prologos. Each peer
  ;; emits its own start-session; the test asserts byte equality
  ;; against what it RECEIVED from the wire.
  (define our-start-bytes
    (extract-value-bytes
     (run-last
      "(eval (encode-op (op-start-session
                            \"0.1\"
                            (syrup-string \"tcp-testing-only:peer-racket\"))))")))
  (define expected-node-start-bytes
    (extract-value-bytes
     (run-last
      "(eval (encode-op (op-start-session
                            \"0.1\"
                            (syrup-string \"tcp-testing-only:peer-node\"))))")))

  ;; 1. Bind ephemeral port.
  (define listener (tcp-listen 0 4 #t "127.0.0.1"))
  (define-values (_a local-port _b _c) (tcp-addresses listener #t))
  (define peer-handshake (path->string (build-path INTEROP-DIR "peer-handshake.mjs")))
  (define node-exe (find-executable-path "node"))

  ;; 2. Spawn Node connector.
  (define-values (proc proc-out proc-in proc-err)
    (subprocess #f #f #f node-exe peer-handshake (number->string local-port)))

  ;; 3. Accept the child's connection.
  (define-values (cin cout) (tcp-accept listener))

  ;; 4. Both sides send their start-session.
  (write-string our-start-bytes cout)
  (write-string "\n" cout)
  (flush-output cout)

  ;; 5. Read Node's start-session bytes.
  (define their-line (read-line cin 'linefeed))
  (close-output-port cout)
  (close-input-port cin)
  (tcp-close listener)

  ;; 6. Drain child stdout (its JSON summary) and reap.
  (define child-stdout (port->string proc-out))
  (define child-stderr (port->string proc-err))
  (close-input-port proc-out)
  (close-output-port proc-in)
  (close-input-port proc-err)
  (subprocess-wait proc)

  ;; 7. Assert: bytes Node sent == bytes Prologos would have emitted.
  ;;    This is the strongest signal of wire-compatibility — if the
  ;;    bytes are byte-identical, both decoders trivially recover the
  ;;    same SyrupValue.
  (check-equal? their-line expected-node-start-bytes
                (format "Node's start-session bytes != Prologos's encoding.
                  Node sent:           ~s
                  Prologos would emit: ~s"
                        their-line expected-node-start-bytes))
  (printf "  Racket-side: Node's bytes match Prologos's expected encoding (~a bytes)~n"
          (string-length their-line))

  ;; 8. Assert child's JSON summary — Node decoded our bytes correctly.
  (check-equal? (subprocess-status proc) 0
                (format "node peer-handshake exited non-zero
                  stdout: ~s
                  stderr: ~s"
                        child-stdout child-stderr))
  (check-true (regexp-match? #px"\"ok\":true" child-stdout)
              (format "expected ok:true in node output: ~s" child-stdout))
  (check-true (regexp-match? #px"\"recv_label\":\"op:start-session\"" child-stdout)
              (format "expected node decoded op:start-session: ~s" child-stdout))
  (check-true (regexp-match? #px"\"recv_version\":\"0.1\"" child-stdout)
              (format "expected version 0.1 in node decode: ~s" child-stdout))
  (check-true (regexp-match? #px"tcp-testing-only:peer-racket" child-stdout)
              (format "expected racket's locator in node decode: ~s" child-stdout))
  (printf "  Node-side: decoded ~a~n" (string-trim child-stdout)))
