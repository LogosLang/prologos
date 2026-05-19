#lang racket/base

;;;
;;; run-ocapn-test-server.rkt — Phase 58 (crypto handshake).
;;;
;;; Long-running Racket TCP server that accepts incoming OCapN
;;; connections from the upstream ocapn-test-suite (Python) and
;;; responds with a valid signed op:start-session.
;;;
;;; What this server does:
;;;
;;;   1. On startup, generate an ephemeral Ed25519 keypair via
;;;      openssl CLI.
;;;   2. Listen on a TCP port.
;;;   3. For each incoming connection:
;;;      a. Send our 4-field signed op:start-session (the canonical
;;;         OCapN handshake) as raw Syrup bytes (no newline framing).
;;;      b. Read whatever the peer sends, drop on the floor.
;;;      c. Stay connected until peer closes.
;;;
;;; Limitations:
;;;
;;;   - The server does NOT yet drive the Prologos bridge. It
;;;     responds to the handshake correctly but doesn't dispatch
;;;     subsequent ops. Subsequent test-suite tests will block
;;;     waiting for op:deliver responses we don't yet generate.
;;;   - The server does NOT verify peer's incoming signature. The
;;;     Python suite generates its own valid signature and sends
;;;     it; we just drop it. Adding verification is straightforward
;;;     (call ed25519-verify) but not needed for the upstream test
;;;     to pass its handshake check.
;;;   - Only ONE swiss-num-addressed object is exposed (none yet).
;;;     The full suite expects Car Factory, Echo GC, Greeter, etc.
;;;     — those are Phase 59+.

(require racket/base
         racket/cmdline
         racket/tcp
         racket/list
         "ocapn-crypto.rkt"
         "ocapn-handshake.rkt"
         "ocapn-framing.rkt")

(define port-arg (make-parameter 22045))
(define version-arg (make-parameter "1.0"))
(define framing-arg (make-parameter 'raw-syrup))

(command-line
 #:program "run-ocapn-test-server"
 #:once-each
 [("--port") p "TCP port to listen on (default: 22045)"
             (port-arg (string->number p))]
 [("--captp-version") v "CapTP version to advertise (default: 1.0)"
                      (version-arg v)]
 [("--framing") f "Wire framing: 'raw-syrup' (default; OCapN spec) or 'newline' (Prologos cross-impl tests)"
                (framing-arg (string->symbol f))])

(unless (framing-strategy? (framing-arg))
  (error 'run-ocapn-test-server "unknown framing: ~v (expected raw-syrup or newline)" (framing-arg)))
(current-framing-strategy (framing-arg))

;; Generate keypair once at startup.
(file-stream-buffer-mode (current-output-port) 'line)
(printf "ocapn-test-server: generating Ed25519 keypair~n") (flush-output)
(define our-keypair (make-ed25519-keypair))
(define our-pubkey (ed25519-pubkey-bytes our-keypair))
(printf "ocapn-test-server: our pubkey (hex) = ~a~n"
        (string-join
         (for/list ([b (in-bytes our-pubkey)])
           (~a #:width 2 #:pad-string "0" #:align 'right
               (number->string b 16))) ""))
(flush-output)

;; Pre-build the start-session bytes once. The signature is
;; pinned to (this version, this address, this keypair); we can
;; reuse the same bytes for every incoming connection.
(define start-session-bytes
  (let-values ([(bs _kp _pub)
                (make-signed-start-session-bytes
                 (version-arg) "127.0.0.1" (port-arg))])
    bs))
(printf "ocapn-test-server: pre-built start-session is ~a bytes~n"
        (bytes-length start-session-bytes))
(flush-output)

(require (only-in racket/format ~a)
         (only-in racket/string string-join))

;; ========================================
;; Connection handler
;; ========================================

(define (handle-connection cin cout)
  (with-handlers ([exn:fail? (lambda (e)
                               (printf "ocapn-test-server: handler exn: ~a~n"
                                       (exn-message e)))])
    (printf "ocapn-test-server: connection accepted, sending start-session (framing=~v)~n"
            (current-framing-strategy))
    ;; Send our handshake immediately. The Python test suite waits
    ;; for our start-session before issuing any other ops.
    (write-frame cout start-session-bytes)
    (printf "ocapn-test-server: sent ~a bytes; reading peer frames~n"
            (bytes-length start-session-bytes))
    ;; Read incoming frames. Each frame is one Syrup value (under
    ;; 'raw-syrup) or one newline-terminated bytes-string (under
    ;; 'newline). We don't yet dispatch frames through the
    ;; captp-core bridge — frame counting + logging is the integration
    ;; point for Phase 59.
    (let loop ([n 0])
      (define frame (with-handlers ([exn:fail?
                                     (lambda (e)
                                       (printf "ocapn-test-server: read-frame exn after ~a frames: ~a~n"
                                               n (exn-message e))
                                       #f)])
                      (read-frame cin)))
      (cond
        [(or (eof-object? frame) (not frame))
         (printf "ocapn-test-server: peer closed after ~a frames~n" n)]
        [else
         (printf "ocapn-test-server: received frame ~a (~a bytes)~n"
                 (+ n 1) (bytes-length frame))
         (loop (+ n 1))])))
  (close-input-port cin)
  (close-output-port cout))

;; ========================================
;; Main loop
;; ========================================

(define listener (tcp-listen (port-arg) 4 #t "127.0.0.1"))
(printf "ocapn-test-server: listening on 127.0.0.1:~a~n" (port-arg))
(flush-output)

(let accept-loop ()
  (define-values (cin cout) (tcp-accept listener))
  (thread (lambda () (handle-connection cin cout)))
  (accept-loop))
