#lang racket/base

;;; test-prologos-multiplex-server.rkt — many connections, one Prologos loop.
;;;
;;; `serve-n port n` accepts n peers and echoes for all of them from a SINGLE
;;; loop, threading one `SrvState` value. No Racket threads on the server side,
;;; no per-connection table.
;;;
;;; That is the observation the OCapN migration turns on: the five shared FFI
;;; hash tables holding handoff state exist because the Racket server gives each
;;; connection its own THREAD, so per-connection state cannot be an accumulator.
;;; One loop over a multiplexed handle set removes the reason — state becomes
;;; fields of a value.
;;;
;;; The load-bearing test is "two peers are served concurrently", and it needs a
;;; RENDEZVOUS to mean anything: a server that finished each peer before
;;; accepting the next would still pass a naive N-client test, just more slowly.
;;; Making peer A wait on peer B before closing turns "serial" from slow into
;;; deadlock, which a timeout reports.

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
         (only-in "../reduction.rkt" current-reduction-fuel-budget)
         (only-in "../../../tools/interop/ocapn-framing.rkt" read-frame write-frame))

(current-framing-strategy 'netstring)

(define shared-preamble
  "(ns test-prologos-multiplex-server)
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

;; A server loop is ONE reduction that runs as long as the server does, so the
;; per-command budget (1M steps, right for a REPL command) is a few hundred
;; frames. Raised rather than removed: a runaway still stops, and the number is
;; the measurement below, not a guess.
(define server-fuel 200000000)

(define (run-last s)
  (define r
    (parameterize ([current-reduction-fuel-budget server-fuel]
                   [current-file-module-network-ref
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

(define (connect-retrying port [deadline-ms 20000])
  (define start (current-inexact-milliseconds))
  (let loop ()
    (define r (with-handlers ([exn:fail? (lambda (_) #f)])
                (call-with-values (lambda () (tcp-connect "127.0.0.1" port)) list)))
    (cond
      [r r]
      [(> (- (current-inexact-milliseconds) start) deadline-ms)
       (error 'connect-retrying "server never bound port ~a" port)]
      [else (sleep 0.02) (loop)])))

(define (send-frame! out s)
  (write-frame out (string->bytes/latin-1 s))
  (flush-output out))

(define (recv-frame! in)
  (define fr (read-frame in))
  (if (or (eof-object? fr) (not fr)) 'eof (bytes->string/latin-1 fr)))

;; Run the Prologos server for `n` peers while `client-thunks` run as threads.
;; Returns the server's own result.
(define (with-server n client-thunks)
  (define port (free-port))
  (define threads (for/list ([f (in-list client-thunks)]) (thread (lambda () (f port)))))
  (define out (run-last (format "(eval ((serve-n ~aN ~aN) initial-world))" port n)))
  (for ([t (in-list threads)])
    (unless (sync/timeout 25 t) (error 'with-server "a client never finished")))
  out)

;; ------------------------------------------------------------------

(test-case "one loop serves several peers"
  (define results (make-vector 3 #f))
  (define (client-n i)
    (lambda (port)
      (define io (connect-retrying port))
      (define in (first io)) (define out (second io))
      (define got
        (for/list ([k (in-range 3)])
          (send-frame! out (format "c~a-~a" i k))
          (recv-frame! in)))
      (vector-set! results i got)
      (close-output-port out) (close-input-port in)))
  (define server-out (with-server 3 (for/list ([i 3]) (client-n i))))
  (for ([i 3])
    (check-equal? (vector-ref results i)
                  (for/list ([k 3]) (format "c~a-~a" i k))
                  (format "peer ~a got the wrong echoes" i)))
  (check-true (regexp-match? #rx"World" server-out)
              "serve-n did not run to completion"))

(test-case "two peers are served CONCURRENTLY, not one after the other"
  ;; The rendezvous. A serves, then waits for B to have been served, and only
  ;; then closes. A server that ran each peer to completion would be stuck
  ;; reading from A while B waits to be accepted — neither side can move, and
  ;; the client timeout reports it. Without this handshake a serial server
  ;; passes, just slower.
  (define b-was-served (make-semaphore 0))
  (define a-got (box #f))
  (define b-got (box #f))

  (define (peer-a port)
    (define io (connect-retrying port))
    (define in (first io)) (define out (second io))
    (send-frame! out "a1")
    (set-box! a-got (recv-frame! in))
    ;; Hold the connection OPEN until B has been served.
    (unless (sync/timeout 20 b-was-served)
      (set-box! a-got 'deadlock-waiting-for-b))
    (close-output-port out) (close-input-port in))

  (define (peer-b port)
    ;; Give A time to connect and be mid-conversation first.
    (sleep 0.3)
    (define io (connect-retrying port))
    (define in (first io)) (define out (second io))
    (send-frame! out "b1")
    (set-box! b-got (recv-frame! in))
    (semaphore-post b-was-served)
    (close-output-port out) (close-input-port in))

  (with-server 2 (list peer-a peer-b))
  (check-equal? (unbox b-got) "b1"
                "peer B was never served while peer A held its connection open")
  (check-equal? (unbox a-got) "a1"))

(test-case "the state is one value: a peer that leaves does not disturb the rest"
  ;; `remove-conn` drops the closed peer from SrvState's list. If it removed
  ;; the wrong entry — or none — the survivor's handle would leave the watch
  ;; set and its next frame would never be serviced.
  (define long-got (box '()))
  (define short-done (make-semaphore 0))

  (define (short-peer port)
    (define io (connect-retrying port))
    (define in (first io)) (define out (second io))
    (send-frame! out "short")
    (recv-frame! in)
    (close-output-port out) (close-input-port in)
    (semaphore-post short-done))

  (define (long-peer port)
    (define io (connect-retrying port))
    (define in (first io)) (define out (second io))
    (send-frame! out "before")
    (define a (recv-frame! in))
    ;; Wait for the other peer to disconnect, THEN keep talking.
    (unless (sync/timeout 20 short-done) (error 'long-peer "short peer never finished"))
    (send-frame! out "after")
    (define b (recv-frame! in))
    (set-box! long-got (list a b))
    (close-output-port out) (close-input-port in))

  (with-server 2 (list long-peer short-peer))
  (check-equal? (unbox long-got) (list "before" "after")
                "the surviving peer stopped being serviced after the other closed"))

(test-case "frames stay byte-transparent under multiplexing"
  (define got (box #f))
  (define (peer port)
    (define io (connect-retrying port))
    (define in (first io)) (define out (second io))
    (define payload (list->string (for/list ([i (in-range 256)]) (integer->char i))))
    (send-frame! out payload)
    (define echoed (recv-frame! in))
    (set-box! got (and (string? echoed) (string=? echoed payload)))
    (close-output-port out) (close-input-port in))
  (with-server 1 (list peer))
  (check-true (unbox got) "the 0-255 payload did not survive the multiplexed loop"))
