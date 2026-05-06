#lang racket/base

;;;
;;; Phase 26 — Multi-turn questioner conversation interop test.
;;;
;;; Builds on Phase 25.4 (test-ocapn-questioner-interop.rkt) which
;;; tested ONE question + reply round. This test exercises THREE
;;; sequential question/reply rounds over the same TCP connection
;;; with peer-pipelined.mjs (Phase 9's loop-responder).
;;;
;;; What this proves:
;;;   1. Wire-level multi-turn protocol works against @endo/ocapn
;;;      (Node loops, replies to each deliver in turn).
;;;   2. Bridge correctly decodes each reply (op-deliver-to-answer
;;;      with the right q-pos).
;;;   3. Each reply's q-pos resolves the matching local promise
;;;      (verify-questioner-reply per round).
;;;
;;; Note: each round in this test uses a FRESH bridge state per
;;; verify-questioner-reply call. True shared-state-across-rounds
;;; (where one BridgeState accumulates all 3 outbound-questions
;;; entries simultaneously) is unit-tested in test-ocapn-bridge.rkt
;;; (Phase 25.2's bs-outbound-questions tests). That's an internal
;;; bridge property; the WIRE-LEVEL multi-turn behavior is what's
;;; exercised here.
;;;
;;; Wire flow:
;;;   Racket → Node: op:start-session
;;;   Racket → Node: op:deliver <desc:export 0> "ping1" <desc:answer 1> false
;;;   Racket → Node: op:deliver <desc:export 0> "ping2" <desc:answer 2> false
;;;   Racket → Node: op:deliver <desc:export 0> "ping3" <desc:answer 3> false
;;;   Node   → Racket: op:start-session
;;;   Node   → Racket: op:deliver <desc:answer 1> "ping1-ack" false false
;;;   Node   → Racket: op:deliver <desc:answer 2> "ping2-ack" false false
;;;   Node   → Racket: op:deliver <desc:answer 3> "ping3-ack" false false
;;;   Racket → Node: op:abort "done"
;;;   Node prints {ok:true, rounds_completed:3, ...}, exits 0.

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
  (error 'test-ocapn-multi-questioner-interop
         "Node + tools/interop/node_modules required.~n  Run: cd tools/interop && npm install"))

(printf "multi-questioner-interop: deps present, running 3-round test~n")

(define shared-preamble
  "(ns test-ocapn-multi-questioner-interop)
(imports (prologos::ocapn::core :refer-all))
(imports (prologos::ocapn::message :refer-all))
(imports (prologos::ocapn::syrup :refer-all))
(imports (prologos::ocapn::syrup-wire :refer-all))
(imports (prologos::ocapn::captp-wire :refer-all))
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

;; Build a Prologos `(suc (suc ... zero))` chain. For small N (<= 20)
;; suc tower is fine. Used to format Nat literals in driver expressions.
(define (build-suc-tower n)
  (cond
    [(zero? n) "zero"]
    [else (format "(suc ~a)" (build-suc-tower (sub1 n)))]))

;; ========================================
;; Multi-turn questioner-side interop
;; ========================================

(test-case "multi-questioner-interop/Racket asks Node 3 times, all promises resolve"
  ;; 1. Listen for Node's connection.
  (define listener (tcp-listen 0 4 #t "127.0.0.1"))
  (define-values (_a local-port _b _c) (tcp-addresses listener #t))

  ;; 2. Spawn Node peer-pipelined (loop-responder).
  (define peer-script (path->string (build-path INTEROP-DIR "peer-pipelined.mjs")))
  (define node-exe (find-executable-path "node"))
  (define-values (proc proc-out proc-in proc-err)
    (subprocess #f #f #f node-exe peer-script (number->string local-port)))

  ;; 3. Accept the connection.
  (define-values (cin cout) (tcp-accept listener))

  ;; 4. Build our session bytes once.
  (define our-ver "0.1")
  (define our-loc "tcp-testing-only:peer-racket-multi-questioner")
  (define session-bytes
    (extract-value-bytes
     (run-last (format "(eval (our-session-bytes ~s ~s))" our-ver our-loc))))

  ;; 5. Send our session.
  (write-string session-bytes cout) (write-string "\n" cout)
  (flush-output cout)

  ;; 6. Send 3 questions. q-pos = round number (1, 2, 3); args = "pingN".
  (define rounds (list (cons 1 "ping1") (cons 2 "ping2") (cons 3 "ping3")))
  (for ([round (in-list rounds)])
    (define q-pos (car round))
    (define args-str (cdr round))
    (define question-bytes
      (extract-value-bytes
       (run-last (format
                  "(eval (outbound-question-bytes zero (syrup-string ~s) ~a))"
                  args-str
                  (build-suc-tower q-pos)))))
    (printf "multi-questioner-interop: sending q~a = ~s~n" q-pos question-bytes)
    (write-string question-bytes cout) (write-string "\n" cout)
    (flush-output cout))

  ;; 7. Read Node's frames: 1 session + 3 replies.
  (define n-session (read-line cin 'linefeed))
  (check-pred string? n-session "expected start-session frame from Node")
  (define replies
    (for/list ([_ (in-range 3)])
      (define reply (read-line cin 'linefeed))
      (check-pred string? reply "expected reply frame from Node")
      reply))
  (printf "multi-questioner-interop: got 3 replies from Node~n")

  ;; 8. Verify each reply through the bridge.
  ;;    Each call uses a fresh bridge state internally — what we're
  ;;    proving is the wire-level + decoder + dispatch path works
  ;;    for each independent round. Cross-round state accumulation
  ;;    is unit-tested elsewhere (test-ocapn-bridge.rkt Phase 25.2).
  (for ([round (in-list rounds)]
        [reply (in-list replies)]
        [i (in-naturals 1)])
    (define q-pos (car round))
    (define args-str (cdr round))
    (define expected-ack (string-append args-str "-ack"))
    (define resolved
      (run-last (format
                 "(eval (verify-questioner-reply ~a ~s))"
                 (build-suc-tower q-pos)
                 reply)))
    (printf "multi-questioner-interop: round ~a resolved = ~s~n" i resolved)
    (check-true (regexp-match? #rx"some" resolved)
                (format "round ~a expected promise resolved (some ...); got: ~s" i resolved))
    (check-true (regexp-match? #rx"pst-fulfilled" resolved)
                (format "round ~a expected pst-fulfilled state; got: ~s" i resolved))
    (check-true (regexp-match? (regexp expected-ack) resolved)
                (format "round ~a expected resolved value to contain ~s; got: ~s"
                        i expected-ack resolved)))

  ;; 9. Send op:abort to terminate Node's loop.
  (define abort-bytes
    (extract-value-bytes
     (run-last "(eval (encode-op (op-abort \"done\")))")))
  (write-string abort-bytes cout) (write-string "\n" cout)
  (flush-output cout)

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
  (printf "multi-questioner-interop: node exit=~a stdout=~s~n" exit-code child-stdout)

  (check-equal? exit-code 0
                (format "Node peer-pipelined exited non-zero. stderr=~s" child-stderr))
  (check-true (regexp-match? #rx"\"rounds_completed\":3" child-stdout)
              (format "expected Node to complete 3 rounds; got: ~s" child-stdout))
  (check-true (regexp-match? #rx"\"saw_abort\":true" child-stdout)
              (format "expected Node to see op:abort; got: ~s" child-stdout)))
