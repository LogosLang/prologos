#lang racket/base

;;;
;;; Phase 9 of OCapN interop — multi-turn RPC with response-driven
;;; followup.
;;;
;;; Racket sends three deliver requests in sequence, where each
;;; subsequent request's args are derived from the previous reply
;;; (NOT pipelined in the strict OCapN sense — Racket waits for
;;; each reply before sending the next; pipelining-on-promise is a
;;; separate test, deferred):
;;;
;;;   Round 1:  Racket → Node:  deliver  args="ping"        ap=0
;;;             Node   → Racket: deliver target=ans:0 args="ping-ack"
;;;
;;;   Round 2:  Racket → Node:  deliver  args="ping-ack"    ap=1
;;;             Node   → Racket: deliver target=ans:1 args="ping-ack-ack"
;;;
;;;   Round 3:  Racket → Node:  deliver  args="ping-ack-ack" ap=2
;;;             Node   → Racket: deliver target=ans:2 args="ping-ack-ack-ack"
;;;
;;;   Termination: Racket → Node: op:abort
;;;
;;; Asserts:
;;;   - Each Node reply byte-equals what Prologos would emit for
;;;     `<op:deliver <desc:answer N> <args+"-ack"> false false>`.
;;;   - Node's JSON summary reports rounds_completed=3, saw_abort=true.
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
  (printf "pipelined: SKIPPED — node + tools/interop/node_modules missing.~n")
  (exit 0))

(printf "pipelined: deps present, running multi-turn test~n")

(define shared-preamble
  "(ns test-ocapn-pipelined)
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

;; Build a Prologos sexp for `(suc^k zero)`.
(define (prologos-nat k)
  (cond [(= k 0) "zero"]
        [else (format "(suc ~a)" (prologos-nat (- k 1)))]))

;; Build a request: <op:deliver <desc:export 0> "args" <desc:answer N> false>
(define (encode-our-deliver args-string ap)
  (extract-value-bytes
   (run-last
    (format "(eval (encode-op (op-deliver zero
                                            (syrup-string ~v)
                                            (some Nat ~a)
                                            (none Nat))))"
            args-string (prologos-nat ap)))))

;; Build expected reply: <op:deliver <desc:answer N> "args-ack" false false>
(define (expected-reply ap args-string)
  (extract-value-bytes
   (run-last
    (format "(eval (encode-record \"op:deliver\"
                                    (cons (syrup-tagged \"desc:answer\" (syrup-nat ~a))
                                      (cons (syrup-string ~v)
                                        (cons (syrup-bool false)
                                          (cons (syrup-bool false) nil))))))"
            (prologos-nat ap) args-string))))

;; ========================================
;; Multi-turn pipelined RPC
;; ========================================

(test-case "pipelined/3 sequential RPCs followed by op:abort"
  (define racket-start
    (extract-value-bytes
     (run-last
      "(eval (encode-op (op-start-session
                            \"0.1\"
                            (syrup-string \"tcp-testing-only:peer-racket\"))))")))
  (define racket-abort
    (extract-value-bytes
     (run-last
      "(eval (encode-op (op-abort \"done\")))")))

  ;; Sequence:
  ;;   Round 1: send "ping" expect "ping-ack"
  ;;   Round 2: send "ping-ack" expect "ping-ack-ack"
  ;;   Round 3: send "ping-ack-ack" expect "ping-ack-ack-ack"
  (define args-seq (list "ping" "ping-ack" "ping-ack-ack"))
  (define expected-replies
    (for/list ([i (in-naturals)] [args (in-list args-seq)])
      (expected-reply i (string-append args "-ack"))))

  (define listener (tcp-listen 0 4 #t "127.0.0.1"))
  (define-values (_a local-port _b _c) (tcp-addresses listener #t))
  (define peer-pipelined (path->string (build-path INTEROP-DIR "peer-pipelined.mjs")))
  (define node-exe (find-executable-path "node"))
  (define-values (proc proc-out proc-in proc-err)
    (subprocess #f #f #f node-exe peer-pipelined (number->string local-port)))

  (define-values (cin cout) (tcp-accept listener))

  ;; Send our start-session.
  (write-string racket-start cout) (write-string "\n" cout)
  (flush-output cout)

  ;; (Drain Node's start-session — the first frame on cin.)
  (define _node-start (read-line cin 'linefeed))

  ;; Three rounds: send deliver-i, read reply-i.
  (define received-replies
    (for/list ([i (in-naturals)] [args (in-list args-seq)])
      (define req (encode-our-deliver args i))
      (write-string req cout) (write-string "\n" cout)
      (flush-output cout)
      (read-line cin 'linefeed)))

  ;; Send abort — Node will close after seeing it.
  (write-string racket-abort cout) (write-string "\n" cout)
  (flush-output cout)

  (close-output-port cout)
  (close-input-port cin)
  (tcp-close listener)

  (define child-stdout (port->string proc-out))
  (define child-stderr (port->string proc-err))
  (close-input-port proc-out)
  (close-output-port proc-in)
  (close-input-port proc-err)
  (subprocess-wait proc)

  ;; Assert: each reply byte-equals expected.
  (for ([i (in-naturals)]
        [got (in-list received-replies)]
        [expected (in-list expected-replies)])
    (check-equal? got expected
                  (format "Round ~a reply mismatch.
                    Got:      ~s
                    Expected: ~s"
                          i got expected)))
  (printf "  Racket-side: all 3 round replies match expected bytes~n")

  ;; Assert: Node's JSON reports rounds_completed=3 and saw_abort=true.
  (check-equal? (subprocess-status proc) 0
                (format "node peer-pipelined exited non-zero
                  stdout: ~s
                  stderr: ~s"
                        child-stdout child-stderr))
  (check-true (regexp-match? #px"\"ok\":true" child-stdout)
              (format "expected ok:true: ~s" child-stdout))
  (check-true (regexp-match? #px"\"rounds_completed\":3" child-stdout)
              (format "expected 3 rounds: ~s" child-stdout))
  (check-true (regexp-match? #px"\"saw_abort\":true" child-stdout)
              (format "expected saw_abort=true: ~s" child-stdout))
  (printf "  Node-side: ~a~n" (string-trim child-stdout)))
