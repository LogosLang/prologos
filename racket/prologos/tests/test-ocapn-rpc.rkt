#lang racket/base

;;;
;;; Phase 8 of OCapN interop — actual conversational state
;;; machine: real RPC-style request/response.
;;;
;;; Unlike Phase 7 (lockstep echo), this test exercises the
;;; first stateful round-trip:
;;;
;;;   Racket → Node:  op:start-session
;;;   Racket → Node:  op:deliver target=<desc:export 0>
;;;                              args="ping"
;;;                              answer-pos=<desc:answer 0>
;;;                              resolver=null
;;;   Node → Racket:  op:start-session  (Node's session)
;;;   Node → Racket:  op:deliver target=<desc:answer 0>     ;; the reply
;;;                              args="ping-pong"
;;;                              answer-pos=null
;;;                              resolver=null
;;;
;;; Node's reply args ("ping-pong") is COMPUTED by the Node
;;; responder from the args it received ("ping" + "-pong"). This
;;; proves Node really decoded our deliver, extracted the args,
;;; and answered to the right answer-pos.
;;;
;;; Racket asserts byte-equality on both Node frames against
;;; what Prologos would have encoded for the equivalent values.
;;; (The Phase-6/7 byte-equality strategy applies — sidesteps the
;;; pitfall-#27 reducer perf issue.)
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
  (printf "rpc: SKIPPED — node + tools/interop/node_modules missing.~n")
  (exit 0))

(printf "rpc: deps present, running RPC-style state-machine test~n")

(define shared-preamble
  "(ns test-ocapn-rpc)
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
;; RPC-style conversation
;; ========================================

(test-case "rpc/Racket sends deliver, Node parses + replies, Racket verifies bytes"
  ;; Compute Racket-side bytes:
  ;;   1. our start-session (locator = peer-racket)
  ;;   2. our deliver (target=desc:export 0, args="ping",
  ;;                    answer-pos=some 0, resolver=none)
  (define racket-start
    (extract-value-bytes
     (run-last
      "(eval (encode-op (op-start-session
                            \"0.1\"
                            (syrup-string \"tcp-testing-only:peer-racket\"))))")))
  (define racket-deliver
    (extract-value-bytes
     (run-last
      "(eval (encode-op (op-deliver zero
                                       (syrup-string \"ping\")
                                       (some Nat zero)
                                       (none Nat))))")))

  ;; Compute expected Node response bytes:
  ;;   1. Node's start-session (locator = peer-node)
  ;;   2. Node's reply: <op:deliver <desc:answer 0> "ping-pong" n n>
  ;;      We bypass op-deliver because our op-deliver always wraps
  ;;      the target in desc-export. The reply targets desc-answer,
  ;;      so we use encode-record directly.
  (define expected-node-start
    (extract-value-bytes
     (run-last
      "(eval (encode-op (op-start-session
                            \"0.1\"
                            (syrup-string \"tcp-testing-only:peer-node\"))))")))
  (define expected-node-reply
    (extract-value-bytes
     (run-last
      "(eval (encode-record \"op:deliver\"
                              (cons (syrup-tagged \"desc:answer\" (syrup-nat zero))
                                (cons (syrup-string \"ping-pong\")
                                  (cons (syrup-bool false)
                                    (cons (syrup-bool false) nil))))))")))

  ;; Bind ephemeral port + spawn Node responder.
  (define listener (tcp-listen 0 4 #t "127.0.0.1"))
  (define-values (_a local-port _b _c) (tcp-addresses listener #t))
  (define peer-resp (path->string (build-path INTEROP-DIR "peer-responder.mjs")))
  (define node-exe (find-executable-path "node"))
  (define-values (proc proc-out proc-in proc-err)
    (subprocess #f #f #f node-exe peer-resp (number->string local-port)))

  ;; Accept the child's connection.
  (define-values (cin cout) (tcp-accept listener))

  ;; Send our two frames.
  (write-string racket-start cout) (write-string "\n" cout)
  (write-string racket-deliver cout) (write-string "\n" cout)
  (flush-output cout)

  ;; Read two frames from Node: start-session + reply.
  (define n-start (read-line cin 'linefeed))
  (define n-reply (read-line cin 'linefeed))

  (close-output-port cout)
  (close-input-port cin)
  (tcp-close listener)

  ;; Drain child stdout + reap.
  (define child-stdout (port->string proc-out))
  (define child-stderr (port->string proc-err))
  (close-input-port proc-out)
  (close-output-port proc-in)
  (close-input-port proc-err)
  (subprocess-wait proc)

  ;; Assert byte equality on Node's two frames.
  (check-equal? n-start expected-node-start
                "Node's start-session bytes != Prologos's encoding")
  (check-equal? n-reply expected-node-reply
                (format "Node's reply bytes != Prologos's expected encoding.
                  Node sent:           ~s
                  Prologos would emit: ~s
                  child-stdout:        ~s"
                        n-reply expected-node-reply child-stdout))
  (printf "  Racket-side: Node's start-session and reply both match expected bytes~n")
  (printf "    start-session:   ~a bytes~n" (string-length n-start))
  (printf "    deliver-reply:   ~a bytes~n" (string-length n-reply))

  ;; Assert Node's JSON summary — Node decoded our messages and
  ;; answered to the right answer-pos.
  (check-equal? (subprocess-status proc) 0
                (format "node peer-responder exited non-zero
                  stdout: ~s
                  stderr: ~s"
                        child-stdout child-stderr))
  (check-true (regexp-match? #px"\"ok\":true" child-stdout)
              (format "expected ok:true: ~s" child-stdout))
  (check-true (regexp-match? #px"\"saw_session\":\"tcp-testing-only:peer-racket\"" child-stdout)
              (format "expected racket's locator in node's saw_session: ~s" child-stdout))
  (check-true (regexp-match? #px"\"saw_deliver_args0\":\"ping\"" child-stdout)
              (format "expected node saw args=\"ping\": ~s" child-stdout))
  (check-true (regexp-match? #px"\"answer_pos\":0" child-stdout)
              (format "expected node saw answer-pos=0: ~s" child-stdout))
  (check-true (regexp-match? #px"\"sent_reply_args0\":\"ping-pong\"" child-stdout)
              (format "expected node replied with ping-pong: ~s" child-stdout))
  (printf "  Node-side: ~a~n" (string-trim child-stdout)))
