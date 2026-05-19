#lang racket/base

;;;
;;; run-ocapn-test-server.rkt — Phase 54 (CI compliance gate).
;;;
;;; Long-running Racket TCP server that accepts incoming OCapN
;;; connections and drives each through `connection-step` until the
;;; remote disconnects. Used as the peer-under-test for the
;;; ocapn-test-suite (Python).
;;;
;;; Usage:
;;;   racket tools/interop/run-ocapn-test-server.rkt --port 22045
;;;
;;; Limitations (documented honestly):
;;;
;;;   - Our `op:start-session` is the 2-field form (ver, loc); the
;;;     OCapN canonical form is 4-field (ver, pubkey, loc, loc-sig)
;;;     with Ed25519 crypto. The Python test suite sends the 4-field
;;;     form; we currently REJECT or misparse it. This is the
;;;     primary compliance gap. Until crypto handshake is shipped,
;;;     the test suite is expected to fail at handshake for all
;;;     tests.
;;;
;;;   - The test suite expects specific objects at specific
;;;     swiss-nums (Car Factory, Echo GC, Greeter, Promise resolver
;;;     — see ocapn-test-suite/README.md). Our bridge currently
;;;     exposes only an echo actor at export 0 (bootstrap). These
;;;     swiss-num-addressed objects are not yet wired up.
;;;
;;; The intent of this file is to (a) provide a peer that the
;;; test suite can at least *attempt* to connect to so we capture
;;; failure-mode diagnostics, and (b) be the integration point
;;; once we ship the crypto handshake.

(require racket/base
         racket/cmdline
         racket/tcp
         racket/list)

(define port-arg (make-parameter 22045))

(command-line
 #:program "run-ocapn-test-server"
 #:once-each
 [("--port") p "TCP port to listen on (default: 22045)"
             (port-arg (string->number p))]
 #:args () (void))

;; ========================================
;; Connection handler
;; ========================================
;;
;; NOTE: this server intentionally does NOT instantiate the Prologos
;; bridge. The Python ocapn-test-suite sends a 4-field crypto-signed
;; op:start-session that our bridge can't decode yet. Instantiating
;; the bridge would just produce malformed-handshake errors that
;; aren't more informative than the simpler "received N bytes, no
;; valid handshake" diagnostic we emit below. When crypto-handshake
;; support is shipped, replace this body with a `connection-step`
;; loop.

(define (handle-connection cin cout)
  (with-handlers ([exn:fail? (lambda (e)
                               (printf "ocapn-test-server: handler exn: ~a~n"
                                       (exn-message e)))])
    ;; Drain whatever the test suite sends. The Python suite uses
    ;; Syrup framing (not line-oriented) so read-line may not give
    ;; us clean frames — best-effort read+log only.
    (let loop ([n 0])
      (define b (read-byte cin))
      (cond
        [(eof-object? b)
         (printf "ocapn-test-server: peer closed after ~a bytes~n" n)]
        [else (loop (+ n 1))])))
  (close-input-port cin)
  (close-output-port cout))

;; ========================================
;; Main loop
;; ========================================

(define listener (tcp-listen (port-arg) 4 #t "127.0.0.1"))
(printf "ocapn-test-server: listening on 127.0.0.1:~a~n" (port-arg))

(let accept-loop ()
  (define-values (cin cout) (tcp-accept listener))
  (thread (lambda () (handle-connection cin cout)))
  (accept-loop))
