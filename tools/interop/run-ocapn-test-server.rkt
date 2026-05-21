#lang racket/base

;;;
;;; run-ocapn-test-server.rkt — Phase 58.b-3 (consolidated).
;;;
;;; Long-running Racket TCP server that accepts incoming OCapN
;;; connections from the upstream ocapn-test-suite (Python) and
;;; responds with a valid signed op:start-session.
;;;
;;; CONSOLIDATION: the signed start-session bytes are now produced
;;; by the canonical Prologos implementation
;;; (`prologos::ocapn::handshake` → `mk-handshake-bytes`), not by a
;;; parallel Racket-side fixture. This server is a thin TCP shell:
;;; it loads the Prologos modules once, calls `mk-handshake-bytes`
;;; via `process-string`, and serves the resulting bytes. Crypto
;;; (libsodium FFI) and Syrup encoding both live inside Prologos.
;;;
;;; What this server does:
;;;   1. Load the OCapN Prologos modules at startup.
;;;   2. Call mk-handshake-bytes to build the signed start-session.
;;;   3. Listen on a TCP port.
;;;   4. For each connection: send the start-session bytes (via the
;;;      configurable framing), read peer frames, log, close.
;;;
;;; Limitation: the server does NOT yet dispatch post-handshake
;;; frames through captp-core's connection-step. The full
;;; ocapn-test-suite needs swiss-num-addressed objects + op:deliver
;;; dispatch — that's Phase 59.

(require racket/cmdline
         racket/tcp
         racket/list
         racket/string
         (only-in racket/format ~a)
         "ocapn-framing.rkt"
         "../../racket/prologos/tests/test-support.rkt"
         "../../racket/prologos/macros.rkt"
         "../../racket/prologos/prelude.rkt"
         "../../racket/prologos/syntax.rkt"
         "../../racket/prologos/source-location.rkt"
         "../../racket/prologos/surface-syntax.rkt"
         "../../racket/prologos/errors.rkt"
         "../../racket/prologos/metavar-store.rkt"
         "../../racket/prologos/parser.rkt"
         "../../racket/prologos/elaborator.rkt"
         "../../racket/prologos/pretty-print.rkt"
         "../../racket/prologos/global-env.rkt"
         "../../racket/prologos/driver.rkt"
         "../../racket/prologos/namespace.rkt"
         "../../racket/prologos/multi-dispatch.rkt")

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

(file-stream-buffer-mode (current-output-port) 'line)

;; ========================================
;; Load the Prologos OCapN modules once
;; ========================================

(define preamble
  "(ns ocapn-test-server)
(imports (prologos::ocapn::handshake :refer-all))
")

(printf "ocapn-test-server: loading Prologos OCapN modules~n") (flush-output)

(define-values (g-env g-ns g-mods g-traits g-impls g-pimpls g-ctors g-tmeta)
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
    (process-string preamble)
    (values (current-prelude-env)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-ctor-registry)
            (current-type-meta))))

(define (run-prologos s)
  (parameterize ([current-prelude-env g-env]
                 [current-ns-context g-ns]
                 [current-module-registry g-mods]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry g-traits]
                 [current-impl-registry g-impls]
                 [current-param-impl-registry g-pimpls]
                 [current-ctor-registry g-ctors]
                 [current-type-meta g-tmeta])
    (process-string s)))

;; ========================================
;; Build the signed start-session via Prologos
;; ========================================
;;
;; mk-handshake-bytes produces a Latin-1 String of wire bytes. The
;; process-string result is pretty-printed as `"...." : String`;
;; `read` recovers the Racket string, which we convert to bytes.

(define (extract-latin1-bytes prologos-result)
  (define m (regexp-match #px"^(\".*\") : String$" prologos-result))
  (unless m
    (error 'extract-latin1-bytes "couldn't extract String from: ~s" prologos-result))
  (string->bytes/latin-1 (read (open-input-string (cadr m)))))

(define start-session-bytes
  (extract-latin1-bytes
   (last
    (run-prologos
     (format "(eval (mk-handshake-bytes ~s \"tcp-testing-only\" \"0123456789abcdef0123456789abcdef\" \"127.0.0.1\" ~s))"
             (version-arg)
             (number->string (port-arg)))))))

(printf "ocapn-test-server: built signed start-session (~a bytes) via prologos::ocapn::handshake~n"
        (bytes-length start-session-bytes))
(flush-output)

;; ========================================
;; Connection handler
;; ========================================

(define (handle-connection cin cout)
  (with-handlers ([exn:fail? (lambda (e)
                               (printf "ocapn-test-server: handler exn: ~a~n"
                                       (exn-message e)))])
    (printf "ocapn-test-server: connection accepted, sending start-session (framing=~v)~n"
            (current-framing-strategy))
    (write-frame cout start-session-bytes)
    (printf "ocapn-test-server: sent ~a bytes; reading peer frames~n"
            (bytes-length start-session-bytes))
    ;; Read incoming frames. We don't yet dispatch through
    ;; captp-core's connection-step — frame counting + logging is
    ;; the integration point for Phase 59.
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
