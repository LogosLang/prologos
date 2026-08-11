#lang racket/base

;;; test-prologos-echo-server.rkt — an event loop written in Prologos, run.
;;;
;;; `prologos::io::server`'s `echo-once` binds a port, accepts one peer, echoes
;;; frames until that peer closes, and shuts the listener down. The whole thing
;;; is one World transformer; running it means handing it `initial-world`.
;;;
;;; The point is not that echo is interesting. It is that the LOOP is in the
;;; language: no Racket `let loop`, no accumulator held on the host side. That
;;; is the step the OCapN driver needs, because while the loop lives in Racket
;;; the host owns the state and per-connection state has to sit in an FFI hash
;;; table instead of being threaded like an ordinary value.
;;;
;;; Structure: the Prologos server runs on the MAIN thread, since
;;; `process-string` shares elaborator state and is not something to run
;;; concurrently. The client is a plain Racket thread using the same framing
;;; module the server's FFI uses. The client retries its connect, because the
;;; port is not bound until the Prologos program reaches `net-listen`.

(require rackunit
         racket/list
         racket/string
         racket/tcp
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
         "../multi-dispatch.rkt"
         (only-in "../tcp-ffi.rkt" current-framing-strategy)
         (only-in "../../../tools/interop/ocapn-framing.rkt" read-frame write-frame))

(current-framing-strategy 'netstring)

(define shared-preamble
  "(ns test-prologos-echo-server)
(imports (prologos::core::world :refer-all))
(imports (prologos::io::net :refer-all))
(imports (prologos::io::server :refer-all))
")

(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg
                shared-ctor-reg
                shared-type-meta)
  (parameterize ([current-file-module-network-ref (make-module-network)]
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
    (values (global-env-snapshot)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-ctor-registry)
            (current-type-meta))))

(define (run-last s)
  (define r
    (parameterize ([current-file-module-network-ref
                    (module-network-add-import (make-module-network)
                                               (module-network-from-snapshot shared-global-env))]
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
  (if (null? r) "" (last r)))

(define (free-port)
  (define l (tcp-listen 0 4 #t "127.0.0.1"))
  (define-values (_h p _rh _rp) (tcp-addresses l #t))
  (tcp-close l)
  p)

;; Connect, retrying until the Prologos side reaches `net-listen`.
(define (connect-retrying port [deadline-ms 15000])
  (define start (current-inexact-milliseconds))
  (let loop ()
    (define r
      (with-handlers ([exn:fail? (lambda (_) #f)])
        (call-with-values (lambda () (tcp-connect "127.0.0.1" port)) list)))
    (cond
      [r r]
      [(> (- (current-inexact-milliseconds) start) deadline-ms)
       (error 'connect-retrying "server never bound port ~a" port)]
      [else (sleep 0.02) (loop)])))

;; Send `payloads`, read one echo per payload, close. Returns the echoes.
(define (echo-client port payloads)
  (define io (connect-retrying port))
  (define in (first io))
  (define out (second io))
  (define got
    (for/list ([p (in-list payloads)])
      (write-frame out (string->bytes/latin-1 p))
      (flush-output out)
      (define fr (read-frame in))
      (if (or (eof-object? fr) (not fr)) 'eof (bytes->string/latin-1 fr))))
  (close-output-port out)
  (close-input-port in)
  got)

;; Run `echo-once` against a client sending `payloads`. Returns the echoes.
;;
;; The client runs in a thread and the Prologos program on the main thread:
;; `process-string` shares elaborator state, so it is the half that must not be
;; concurrent. `echo-once` returns only after the client closes, which is what
;; makes the join safe.
(define (run-echo payloads)
  (define port (free-port))
  (define result (box #f))
  (define client
    (thread (lambda ()
              (set-box! result
                        (with-handlers ([exn:fail? (lambda (e) (exn-message e))])
                          (echo-client port payloads))))))
  (define server-out (run-last (format "(eval ((echo-once ~aN) initial-world))" port)))
  (unless (sync/timeout 20 client)
    (error 'run-echo "client did not finish"))
  (values (unbox result) server-out))

(test-case "a Prologos loop echoes one frame"
  (define-values (got server-out) (run-echo (list "hello")))
  (check-equal? got (list "hello"))
  ;; The program's result is the final World — evidence the loop ran to
  ;; completion rather than being abandoned mid-way.
  (check-true (regexp-match? #rx"World" server-out)
              (format "echo-once did not return a World: ~a" server-out)))

(test-case "the loop keeps going for many frames"
  ;; Self-recursion in the `false` arm is the loop. One frame would pass even
  ;; if the recursive call were missing.
  (define-values (got _s) (run-echo (list "one" "two" "three" "four" "five")))
  (check-equal? got (list "one" "two" "three" "four" "five")))

(test-case "frames are bytes, not lines"
  ;; A payload containing 0x0a, which line framing truncates silently. This is
  ;; what makes the loop usable for a Syrup wire.
  (define-values (got _s) (run-echo (list "before\nafter" "plain")))
  (check-equal? got (list "before\nafter" "plain")))

(test-case "every byte value survives the round trip"
  (define payload (list->string (for/list ([i (in-range 256)]) (integer->char i))))
  (define-values (got _s) (run-echo (list payload)))
  (check-equal? (length got) 1)
  (check-equal? (string-length (first got)) 256)
  (check-equal? (first got) payload))

(test-case "an empty frame is echoed, not treated as a hangup"
  ;; The EOF-as-a-field decision, end to end. If `net-recv` reported an empty
  ;; frame as EOF, the loop would close here and the client would read EOF
  ;; instead of its echo.
  (define-values (got _s) (run-echo (list "" "after-the-empty")))
  (check-equal? got (list "" "after-the-empty")))

(test-case "the loop terminates when the peer closes"
  ;; `run-echo` returning at all IS the assertion: `echo-once` only returns
  ;; after the EOF arm runs. A loop that could not see EOF would hang here and
  ;; the file would time out rather than fail.
  (define-values (got server-out) (run-echo (list "bye")))
  (check-equal? got (list "bye"))
  (check-true (regexp-match? #rx"World" server-out)))
