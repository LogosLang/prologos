#lang racket/base

;;;
;;; Phase 7 of OCapN interop — multi-message conversation
;;; between Prologos and @endo/ocapn over a real TCP socket.
;;;
;;; The conversation has THREE frames in each direction:
;;;
;;;   1. op:start-session  ver="0.1"  loc=...
;;;   2. op:deliver-only   target=<desc:export 0>  args="ping"
;;;   3. op:abort          reason="goodbye"
;;;
;;; Each peer sends all three frames, and reads all three from
;;; the other peer. Both sides assert byte-equality on the three
;;; received frames.
;;;
;;; This is a "lockstep echo" test, not a real CapTP exchange —
;;; both peers send identical (modulo locator) sequences, no
;;; turn-by-turn protocol logic. Phase 8+ would build out the
;;; actual conversational state machine. Phase 7 just establishes
;;; that multi-frame, multi-op-type sequences round-trip.
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
  (printf "conversation: SKIPPED — node + tools/interop/node_modules missing.~n")
  (exit 0))

(printf "conversation: deps present, running 3-frame conversation~n")

(define shared-preamble
  "(ns test-ocapn-conversation)
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
;; Multi-message conversation
;; ========================================

(test-case "conversation/3-frame multi-op exchange"
  ;; Compute Racket-side bytes for our three frames.
  (define racket-start
    (extract-value-bytes
     (run-last
      "(eval (encode-op (op-start-session
                            \"0.1\"
                            (syrup-string \"tcp-testing-only:peer-racket\"))))")))
  (define racket-deliver
    (extract-value-bytes
     (run-last
      "(eval (encode-op (op-deliver-only zero (syrup-string \"ping\"))))")))
  (define racket-abort
    (extract-value-bytes
     (run-last
      "(eval (encode-op (op-abort \"goodbye\")))")))
  ;; What we expect Node to send (peer-conversation hardcodes these).
  (define expected-node-start
    (extract-value-bytes
     (run-last
      "(eval (encode-op (op-start-session
                            \"0.1\"
                            (syrup-string \"tcp-testing-only:peer-node\"))))")))
  (define expected-node-deliver
    (extract-value-bytes
     (run-last
      "(eval (encode-op (op-deliver-only zero (syrup-string \"ping\"))))")))
  (define expected-node-abort
    (extract-value-bytes
     (run-last
      "(eval (encode-op (op-abort \"goodbye\")))")))

  ;; Bind ephemeral port + spawn Node child.
  (define listener (tcp-listen 0 4 #t "127.0.0.1"))
  (define-values (_a local-port _b _c) (tcp-addresses listener #t))
  (define peer-conv (path->string (build-path INTEROP-DIR "peer-conversation.mjs")))
  (define node-exe (find-executable-path "node"))
  (define-values (proc proc-out proc-in proc-err)
    (subprocess #f #f #f node-exe peer-conv (number->string local-port)))

  ;; Accept the child's connection.
  (define-values (cin cout) (tcp-accept listener))

  ;; Send our three frames + '\n' each.
  (write-string racket-start cout) (write-string "\n" cout)
  (write-string racket-deliver cout) (write-string "\n" cout)
  (write-string racket-abort cout) (write-string "\n" cout)
  (flush-output cout)

  ;; Read three frames from Node.
  (define n-start (read-line cin 'linefeed))
  (define n-deliver (read-line cin 'linefeed))
  (define n-abort (read-line cin 'linefeed))

  (close-output-port cout)
  (close-input-port cin)
  (tcp-close listener)

  ;; Drain child JSON + reap.
  (define child-stdout (port->string proc-out))
  (define child-stderr (port->string proc-err))
  (close-input-port proc-out)
  (close-output-port proc-in)
  (close-input-port proc-err)
  (subprocess-wait proc)

  ;; Assert byte equality on each of Node's three frames.
  (check-equal? n-start expected-node-start
                "frame 1 (op:start-session) byte mismatch")
  (check-equal? n-deliver expected-node-deliver
                "frame 2 (op:deliver-only) byte mismatch")
  (check-equal? n-abort expected-node-abort
                "frame 3 (op:abort) byte mismatch")
  (printf "  Racket-side: all 3 Node frames matched expected bytes~n")
  (printf "    start-session:  ~a bytes~n" (string-length n-start))
  (printf "    deliver-only:   ~a bytes~n" (string-length n-deliver))
  (printf "    abort:          ~a bytes~n" (string-length n-abort))

  ;; Assert Node's JSON summary — Node decoded all three of our
  ;; frames with the expected labels.
  (check-equal? (subprocess-status proc) 0
                (format "node peer-conversation exited non-zero
                  stdout: ~s
                  stderr: ~s"
                        child-stdout child-stderr))
  (check-true (regexp-match? #px"\"ok\":true" child-stdout)
              (format "expected ok:true: ~s" child-stdout))
  (check-true (regexp-match? #px"\"label\":\"op:start-session\"" child-stdout)
              (format "expected start-session in node decode: ~s" child-stdout))
  (check-true (regexp-match? #px"\"label\":\"op:deliver-only\"" child-stdout)
              (format "expected deliver-only in node decode: ~s" child-stdout))
  (check-true (regexp-match? #px"\"label\":\"op:abort\"" child-stdout)
              (format "expected abort in node decode: ~s" child-stdout))
  (printf "  Node-side: decoded all 3 Racket frames~n"))
