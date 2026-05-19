#lang racket/base

;;;
;;; Phase 25.4 — Questioner-side interop test.
;;;
;;; Counterpart to test-ocapn-bridge-interop.rkt (which tested
;;; Prologos as a CapTP RESPONDER): this exercises Prologos as a
;;; CapTP QUESTIONER. Prologos initiates a question to Node,
;;; receives the reply, decodes it through the bridge, and verifies
;;; the local promise we allocated for the question gets resolved
;;; with the answer payload.
;;;
;;; Wire flow:
;;;   Racket → Node: op:start-session
;;;   Racket → Node: op:deliver target=<desc:export 0>
;;;                              args="ping"
;;;                              answer-pos=<desc:answer 7>   ;; OUR q-pos
;;;                              resolver=false
;;;   Node receives, computes "ping-pong" (peer-responder.mjs default)
;;;   Node → Racket: op:start-session
;;;   Node → Racket: op:deliver target=<desc:answer 7>         ;; OUR q-pos
;;;                              args="ping-pong"
;;;                              answer-pos=false
;;;                              resolver=false
;;;   Racket bridge:
;;;     decode-op → op-deliver-to-answer 7 "ping-pong"
;;;     dispatch  → look up q-pos 7 in outbound-questions
;;;                 → resolve local promise with "ping-pong"
;;;
;;; Counterpart to peer-responder.mjs (which already exists for
;;; Phase 8's RPC test). We reuse it directly.

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

;; Hard-fail rather than silently skipping — Node + @endo/ocapn are
;; required for all OCapN interop tests in CI and locally.
(unless (interop-deps-present?)
  (error 'test-ocapn-questioner-interop
         "Node + tools/interop/node_modules required.~n  Run: cd tools/interop && npm install"))

(printf "questioner-interop: deps present, running questioner-side test~n")

(define shared-preamble
  "(ns test-ocapn-questioner-interop)
(imports (prologos::ocapn::core :refer-all))
(imports (prologos::ocapn::message :refer-all))
(imports (prologos::ocapn::syrup :refer-all))
(imports (prologos::ocapn::syrup-wire :refer-all))
(imports (prologos::ocapn::captp-wire :refer-all))
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

;; Build a Prologos `(suc (suc ... zero))` chain. Used to format
;; Nat literals in process-string driver expressions for small N.
(define (build-suc-tower-or-nat-literal n)
  (cond
    [(zero? n) "zero"]
    [else (format "(suc ~a)" (build-suc-tower-or-nat-literal (sub1 n)))]))

;; ========================================
;; Questioner-side interop
;; ========================================

(test-case "questioner-interop/Racket asks Node, Node replies, promise resolves"
  ;; 1. Listen for Node's connection.
  (define listener (tcp-listen 0 4 #t "127.0.0.1"))
  (define-values (_a local-port _b _c) (tcp-addresses listener #t))

  ;; 2. Spawn Node peer-responder.
  (define peer-script (path->string (build-path INTEROP-DIR "peer-responder.mjs")))
  (define node-exe (find-executable-path "node"))
  (define-values (proc proc-out proc-in proc-err)
    (subprocess #f #f #f node-exe peer-script (number->string local-port)))

  ;; 3. Accept the connection.
  (define-values (cin cout) (tcp-accept listener))

  ;; 4. Build our session bytes.
  (define our-ver "0.1")
  (define our-loc "tcp-testing-only:peer-racket-questioner")
  (define session-bytes
    (extract-value-bytes
     (run-last (format "(eval (our-session-bytes ~s ~s))" our-ver our-loc))))
  (printf "questioner-interop: our-session-bytes = ~s~n" session-bytes)

  ;; 5. Build our outbound question via the atomic bridge-send-question
  ;;    helper (Phase 27). This allocates a fresh local promise (pid=0
  ;;    in a fresh vat), registers q-pos = pid in BridgeState's
  ;;    outbound-questions table, and encodes the wire bytes — all
  ;;    in one call. Q-pos is 0 by construction (first allocation
  ;;    from empty-vat).
  ;;
  ;;      <op:deliver <desc:export 0> "ping" <desc:answer 0> false>
  (define our-q-pos 0)
  (define question-bytes
    (extract-value-bytes
     (run-last (format
                "(eval (bq-bytes (bridge-send-question zero (syrup-string ~s) empty-vat bridge-state-empty)))"
                "ping"))))
  (printf "questioner-interop: question-bytes = ~s~n" question-bytes)

  ;; 6. Send both frames to Node.
  (write-string session-bytes cout) (write-string "\n" cout)
  (write-string question-bytes cout) (write-string "\n" cout)
  (flush-output cout)

  ;; 7. Read Node's two frames: its session + its reply to our question.
  (define n-session (read-line cin 'linefeed))
  (define n-reply (read-line cin 'linefeed))
  (check-pred string? n-session "expected start-session frame from Node")
  (check-pred string? n-reply "expected reply frame from Node")
  (printf "questioner-interop: node sent reply = ~s~n" n-reply)

  ;; 8. Drive the bridge: decode Node's reply via the questioner-side
  ;;    helper and verify the local promise was resolved with the
  ;;    answer payload "ping-pong" (peer-responder appends "-pong").
  (define resolved
    (run-last (format
               "(eval (verify-questioner-reply ~a ~s))"
               (build-suc-tower-or-nat-literal our-q-pos)
               n-reply)))
  (printf "questioner-interop: resolved = ~s~n" resolved)
  (check-true (regexp-match? #rx"some" resolved)
              (format "expected promise resolved (some ...); got: ~s" resolved))
  (check-true (regexp-match? #rx"ping-pong" resolved)
              (format "expected resolved value to contain 'ping-pong'; got: ~s" resolved))

  ;; 9. Close our half of the TCP connection FIRST so Node sees FIN
  ;;    and exits cleanly — otherwise Node would hit its 30s safety
  ;;    timeout and exit 3 even though respond() already succeeded.
  (close-output-port cout)
  (close-input-port cin)
  (tcp-close listener)

  ;; 10. Drain Node's stdout + stderr + reap.
  (define child-stdout (port->string proc-out))
  (define child-stderr (port->string proc-err))
  (close-output-port proc-in)
  (close-input-port proc-out)
  (close-input-port proc-err)
  (subprocess-wait proc)
  (define exit-code (subprocess-status proc))
  (printf "questioner-interop: node exit=~a stdout=~s~n" exit-code child-stdout)
  (check-equal? exit-code 0
                (format "Node peer-responder exited non-zero. stderr=~s" child-stderr)))

