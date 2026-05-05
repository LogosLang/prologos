#lang racket/base

;;;
;;; Phase 24 — Bridge-driven live responder interop test.
;;;
;;; This is the first true end-to-end interop test: Node sends real
;;; Syrup-encoded CapTP frames over TCP; the Prologos bridge
;;; processes the equivalent op via captp-incoming-with-state +
;;; drain + pump-outbound (Phases 11–18); outbound bytes are written
;;; back to Node; Node decodes the reply and verifies it targets
;;; the correct answer-pos with the echoed payload.
;;;
;;; Until this test, our test matrix had two disjoint layers:
;;;   - 26 in-process unit tests of bridge components (test-ocapn-bridge.rkt)
;;;   - Hand-coded byte-equality interop tests (test-ocapn-rpc.rkt etc.)
;;; This file is the seam where they meet.
;;;
;;; Implementation choice: the bridge chain (decode-op +
;;; captp-incoming-with-state + drain + pump-outbound + first-bytes)
;;; lives in a *.prologos library (`prologos::ocapn::bridge-interop-helpers`)
;;; that raco make compiles to .pnet once. The test invokes
;;; `drive-echo-bridge-from-bytes` via a single function call in
;;; process-string, sidestepping the deep let-chain inference issue
;;; (goblin pitfall #30) by keeping the function body inside a
;;; top-level `defn` where Prologos elaboration handles it correctly.
;;;
;;; The test thus proves: Node connects, sends 2 frames, our bridge
;;; DECODES the deliver, processes it through the vat (echo behavior
;;; resolves the local promise tied to Node's question pos), and
;;; emits the encoded reply. Node's @endo/ocapn decoder accepts our
;;; bytes and verifies the reply shape (answer-pos=7, args="hello").
;;;
;;; Wire flow:
;;;   Node →  Racket: op:start-session
;;;   Node →  Racket: op:deliver target=<desc:export 0>
;;;                              args="hello"
;;;                              answer-pos=<desc:answer 7>
;;;                              resolver=false
;;;   Racket bridge processes both frames via connection-step:
;;;     - op:start-session → state-preserving no-op (0 outbound)
;;;     - op:deliver       → enqueue VatMsg, drain (echo resolves
;;;                          local promise), pump emits outbound:
;;;                          <op:deliver <desc:answer 7> "hello" false false>
;;;   Racket → Node: outbound bytes
;;;   Node verifies the reply, exits 0.

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
  (printf "bridge-interop: SKIPPED — node + tools/interop/node_modules missing.~n")
  (exit 0))

(printf "bridge-interop: deps present, running bridge-driven responder interop test~n")

(define shared-preamble
  "(ns test-ocapn-bridge-interop)
(imports (prologos::ocapn::core :refer-all))
(imports (prologos::ocapn::message :refer-all))
(imports (prologos::ocapn::bridge-interop-helpers :refer-all))
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
;; Bridge-driven responder
;; ========================================

(test-case "bridge-interop/Node sends deliver, Racket bridge replies via connection-step"
  ;; 1. Listen on ephemeral port.
  (define listener (tcp-listen 0 4 #t "127.0.0.1"))
  (define-values (_a local-port _b _c) (tcp-addresses listener #t))

  ;; 2. Spawn Node peer-questioner.
  (define peer-script (path->string (build-path INTEROP-DIR "peer-questioner.mjs")))
  (define node-exe (find-executable-path "node"))
  (define-values (proc proc-out proc-in proc-err)
    (subprocess #f #f #f node-exe peer-script (number->string local-port)))

  ;; 3. Accept connection.
  (define-values (cin cout) (tcp-accept listener))

  ;; 4. Read 2 inbound frames from Node (start-session + deliver).
  ;;    Each frame is one line; line-oriented framing matches our
  ;;    test transport convention from Phases 5–10.
  (define f1-bytes (read-line cin 'linefeed))
  (define f2-bytes (read-line cin 'linefeed))
  (check-pred string? f1-bytes "expected start-session frame from Node")
  (check-pred string? f2-bytes "expected deliver frame from Node")

  ;; 5. Verify Node sent two frames; the first is op:start-session
  ;;    (a state-preserving no-op for the bridge in this test) and
  ;;    the second is op:deliver. We feed the SECOND, raw bytes and
  ;;    all, into a Prologos library helper that calls decode-op +
  ;;    captp-incoming-with-state + drain + pump-outbound. The
  ;;    helper lives in prologos::ocapn::bridge-interop-helpers
  ;;    (raco make compiles it once) so process-string only has
  ;;    to elaborate a single function call (sidesteps pitfall #30).
  (check-true (> (string-length f1-bytes) 10) "Node start-session frame too short")
  (check-true (> (string-length f2-bytes) 10) "Node deliver frame too short")

  ;; 6. Drive the bridge with Node's actual deliver bytes. The
  ;;    helper returns Option String; unwrap-or yields the bytes
  ;;    or a sentinel.
  (define driver-expr
    (format "(eval (unwrap-or \"NO-OUTBOUND\"
                                (drive-echo-bridge-from-bytes ~s)))"
            f2-bytes))
  (define reply-bytes (extract-value-bytes (run-last driver-expr)))
  (printf "bridge-interop: reply-bytes from Prologos = ~s~n" reply-bytes)

  ;; 6. Sanity check: the bridge produced a non-trivial reply.
  (check-true (> (string-length reply-bytes) 10)
              (format "bridge produced suspiciously short reply: ~s" reply-bytes))
  (check-false (equal? reply-bytes "NO-OUTBOUND")
               "bridge emitted no outbound bytes — pump did not fire")

  ;; 7. Write the reply back to Node.
  (write-string reply-bytes cout)
  (write-string "\n" cout)
  (flush-output cout)

  ;; 8. Wait for Node to verify and exit. Read its summary line.
  (define node-summary (read-line proc-out 'linefeed))
  (subprocess-wait proc)
  (define exit-code (subprocess-status proc))

  (close-output-port cout)
  (close-input-port cin)
  (close-output-port proc-in)
  (close-input-port proc-out)
  (close-input-port proc-err)
  (tcp-close listener)

  (check-equal? exit-code 0
                (format "Node peer-questioner exited ~a. summary=~s"
                        exit-code node-summary))
  (check-pred string? node-summary)
  ;; Node's JSON summary contains the verified pos + payload. Check
  ;; for the load-bearing fields directly in the JSON text.
  (check-true (regexp-match? #rx"\"ok\":true" node-summary)
              (format "Node reported failure: ~s" node-summary))
  (check-true (regexp-match? #rx"\"saw_reply_target_pos\":7" node-summary)
              (format "Node saw wrong reply target_pos: ~s" node-summary))
  (check-true (regexp-match? #rx"\"saw_reply_args0\":\"hello\"" node-summary)
              (format "Node saw wrong reply args: ~s" node-summary)))
