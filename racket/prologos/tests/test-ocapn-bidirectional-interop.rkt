#lang racket/base

;;;
;;; Phase 29 — True bidirectional peer-to-peer interop test.
;;;
;;; Both sides act as questioner AND responder on the same socket
;;; connection. Combines Phase 24 (responder-side bridge) with
;;; Phase 25-28 (questioner-side bridge) running on the same Racket
;;; process for one connection.
;;;
;;; Wire flow:
;;;
;;;   Node   → Racket: op:start-session
;;;   Node   → Racket: op:deliver <desc:export 0> "node-q"
;;;                     <desc:answer 100> false      ;; Node's question to Racket
;;;
;;;   Racket processes Node's question via the responder bridge:
;;;     - decode op
;;;     - vat with echo actor at export 0 dispatches "node-q"
;;;     - echo resolves the local promise (peer-q-pos=100 → answer)
;;;     - pump-outbound emits the wire reply
;;;
;;;   Racket → Node: op:start-session
;;;   Racket → Node: op:deliver <desc:answer 100> "node-q" false false
;;;
;;;   Now Racket asks its own question via the questioner bridge:
;;;     - connection-ask 0 "racket-q" cs → ConnAsk with bytes + pid
;;;
;;;   Racket → Node: op:deliver <desc:export 0> "racket-q"
;;;                    <desc:answer 0> false           ;; Racket's q-pos
;;;
;;;   Node receives all 3 Racket frames, replies to Racket's question:
;;;
;;;   Node → Racket: op:deliver <desc:answer 0>
;;;                    "racket-q-bidi-ack" false false
;;;
;;;   Racket dispatches Node's reply via the questioner bridge:
;;;     - decode-op → op-deliver-to-answer 0 "racket-q-bidi-ack"
;;;     - dispatch-incoming-answer → resolve local promise 0
;;;     - lookup-promise yields pst-fulfilled "racket-q-bidi-ack"
;;;
;;;   Verifies Node printed JSON summary with all expected fields.

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
  (error 'test-ocapn-bidirectional-interop
         "Node + tools/interop/node_modules required.~n  Run: cd tools/interop && npm install"))

(printf "bidirectional-interop: deps present, running test~n")

(define shared-preamble
  "(ns test-ocapn-bidirectional-interop)
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
;; Bidirectional peer-to-peer
;; ========================================

(test-case "bidirectional-interop/Racket and Node both ask + answer on same connection"
  ;; 1. Listen for Node's connection.
  (define listener (tcp-listen 0 4 #t "127.0.0.1"))
  (define-values (_a local-port _b _c) (tcp-addresses listener #t))

  ;; 2. Spawn Node peer-bidirectional.
  (define peer-script (path->string (build-path INTEROP-DIR "peer-bidirectional.mjs")))
  (define node-exe (find-executable-path "node"))
  (define-values (proc proc-out proc-in proc-err)
    (subprocess #f #f #f node-exe peer-script (number->string local-port)))

  ;; 3. Accept the connection.
  (define-values (cin cout) (tcp-accept listener))

  ;; 4. Read Node's two outbound frames: its session + its question to us.
  (define n-session (read-line cin 'linefeed))
  (define n-q (read-line cin 'linefeed))
  (check-pred string? n-session "expected Node start-session")
  (check-pred string? n-q "expected Node question")
  (printf "bidirectional-interop: node-q = ~s~n" n-q)

  ;; 5. Process Node's question via the existing handshake-aware
  ;;    responder helper (drive-handshake-and-deliver, Phase 24/25).
  ;;    Returns framed concat: our-session + our-reply-to-node-Q.
  (define our-ver "0.1")
  (define our-loc "tcp-testing-only:peer-racket-bidirectional")
  (define handshake-and-reply-blob
    (extract-value-bytes
     (run-last (format
                "(eval (drive-handshake-and-deliver ~s ~s ~s))"
                our-ver our-loc n-q))))
  (printf "bidirectional-interop: handshake-and-reply blob = ~s~n"
          handshake-and-reply-blob)

  ;; 6. Build OUR question via connection-ask. Empty connection state
  ;;    means our q-pos starts at 0.
  ;;    Note: each process-string call has its own state, so this Q
  ;;    is built independently from the responder-side state above.
  ;;    The wire-level behavior is what matters here.
  (define our-q-pos 0)
  (define our-q-bytes
    (extract-value-bytes
     (run-last (format
                "(eval (conn-ask-bytes (connection-ask zero (syrup-string ~s) empty-connection)))"
                "racket-q"))))
  (printf "bidirectional-interop: our-q-bytes = ~s~n" our-q-bytes)

  ;; 7. Send back to Node:
  ;;      a. handshake-and-reply blob (already framed: session + reply)
  ;;      b. our question (one frame, needs trailing newline)
  (write-string handshake-and-reply-blob cout)
  (write-string our-q-bytes cout) (write-string "\n" cout)
  (flush-output cout)

  ;; 8. Read Node's reply to OUR question.
  (define n-reply (read-line cin 'linefeed))
  (check-pred string? n-reply "expected Node reply to Racket's question")
  (printf "bidirectional-interop: node-reply-to-our-q = ~s~n" n-reply)

  ;; 9. Verify Node's reply through the questioner bridge.
  ;;    Racket's promise (q-pos 0) should resolve with "racket-q-bidi-ack".
  (define resolved
    (run-last (format
               "(eval (verify-questioner-reply zero ~s))"
               n-reply)))
  (printf "bidirectional-interop: resolved = ~s~n" resolved)
  (check-true (regexp-match? #rx"some" resolved)
              (format "expected promise resolved (some ...); got: ~s" resolved))
  (check-true (regexp-match? #rx"pst-fulfilled" resolved)
              (format "expected pst-fulfilled state; got: ~s" resolved))
  (check-true (regexp-match? #rx"racket-q-bidi-ack" resolved)
              (format "expected resolved value to contain 'racket-q-bidi-ack'; got: ~s"
                      resolved))

  ;; 10. Close our half so Node sees FIN, then drain + reap.
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
  (printf "bidirectional-interop: node exit=~a stdout=~s~n" exit-code child-stdout)

  (check-equal? exit-code 0
                (format "Node peer-bidirectional exited non-zero. stderr=~s" child-stderr))
  (check-true (regexp-match? #rx"\"ok\":true" child-stdout)
              (format "expected Node summary ok:true; got: ~s" child-stdout))
  (check-true (regexp-match? #rx"\"saw_reply_to_node_q\":\"node-q\"" child-stdout)
              (format "expected Node to see reply 'node-q' to its question; got: ~s"
                      child-stdout))
  (check-true (regexp-match? #rx"\"saw_racket_q_args\":\"racket-q\"" child-stdout)
              (format "expected Node to see Racket's question args 'racket-q'; got: ~s"
                      child-stdout))
  (check-true (regexp-match? #rx"\"saw_racket_q_pos\":0" child-stdout)
              (format "expected Node to see Racket's q-pos 0; got: ~s" child-stdout)))
