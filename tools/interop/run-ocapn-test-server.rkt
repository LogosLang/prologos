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
         (only-in file/sha1 bytes->hex-string)
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

;; The captp-core dependency tree must be imported as explicit
;; top-level `imports` in dependency order. Auto-loading a module's
;; deps transitively (just `(imports captp-core)`) mis-elaborates
;; `data` constructor matches into `??__match-fail` holes — a known
;; module-loading-context boundary. This preamble mirrors the proven
;; import list from tests/test-ocapn-bridge.rkt.
(define preamble
  "(ns ocapn-test-server)
(imports (prologos::ocapn::core :refer-all))
(imports (prologos::ocapn::message :refer-all))
(imports (prologos::ocapn::captp-wire :refer-all))
(imports (prologos::ocapn::syrup-wire :refer-all))
(imports (prologos::ocapn::captp-core :refer-all))
(imports (prologos::ocapn::pipelining :refer (promise-queue-length)))
(imports (prologos::ocapn::captp-interop-helpers :refer (framed-concat)))
(imports (prologos::data::list :refer (List nil cons)))
(imports (prologos::data::option :refer (Option some none unwrap-or)))
(imports (prologos::data::string :as str :refer ()))
(imports (prologos::ocapn::handshake :refer-all))
(imports (prologos::ocapn::interop-driver :refer-all))
")

(printf "ocapn-test-server: loading Prologos OCapN modules~n") (flush-output)

(define-values (g-env g-ns g-mods g-traits g-impls g-pimpls g-ctors g-tmeta)
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
    (process-string preamble)
    (values (current-file-module-network-ref)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-ctor-registry)
            (current-type-meta))))

(define (run-prologos s)
  (parameterize ([current-file-module-network-ref g-env]
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
;; Inbound start-session validation
;; ========================================
;;
;; The decision logic lives in `prologos::ocapn::handshake`
;; (`check-incoming-start-session`). The server hex-encodes the
;; inbound frame, passes it through, and gets back either the empty
;; string (accept) or op:abort wire bytes (reject).

(define validate-sema (make-semaphore 1))

(define (validate-incoming frame-bytes)
  ;; `process-string` shares elaborator state across calls; serialise
  ;; per-connection validation so concurrent connections cannot race.
  (call-with-semaphore
   validate-sema
   (lambda ()
     (extract-latin1-bytes
      (last
       (run-prologos
        (format "(eval (check-incoming-start-session ~s ~s))"
                (version-arg)
                (bytes->hex-string frame-bytes))))))))

;; ========================================
;; Post-handshake CapTP dispatch
;; ========================================
;;
;; Once the handshake is accepted the server drives captp-core's
;; connection-step, one wire frame at a time. Each frame is a separate
;; `process-string` call (fresh reduction-fuel budget); the
;; ConnectionState persists in ocapn-conn-ffi.rkt's table keyed by an
;; integer connection id. `step-connection` returns the concatenated
;; outbound wire bytes (raw-syrup is self-delimiting).

(define conn-id-box (box 0))

(define (next-conn-id!)
  (define id (unbox conn-id-box))
  (set-box! conn-id-box (add1 id))
  id)

(define (drive-init! cid)
  (call-with-semaphore validate-sema
    (lambda ()
      (run-prologos (format "(eval (init-connection ~aN))" cid)))))

;; Returns the outbound wire bytes for one frame, or #"" if the step
;; produced nothing / failed. A step that errors (e.g. an op captp-core
;; cannot yet service) must not take down the connection handler.
(define (drive-step cid frame-bytes)
  (call-with-semaphore validate-sema
    (lambda ()
      (with-handlers ([exn:fail?
                       (lambda (e)
                         (printf "ocapn-test-server: step exn (conn ~a): ~a~n"
                                 cid (exn-message e))
                         #"")])
        (define results
          (run-prologos
           (format "(eval (step-connection ~aN ~s))"
                   cid (bytes->hex-string frame-bytes))))
        (define r (and (pair? results) (last results)))
        (cond
          [(not (string? r))
           (printf "ocapn-test-server: step produced no String (conn ~a)~n" cid)
           #""]
          [(regexp-match #px"^(\".*\") : String$" r)
           => (lambda (m)
                (string->bytes/latin-1 (read (open-input-string (cadr m)))))]
          [else
           (printf "ocapn-test-server: step result unparsable (conn ~a): ~a~n" cid r)
           #""])))))

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
    (printf "ocapn-test-server: sent ~a bytes; reading peer start-session~n"
            (bytes-length start-session-bytes))
    (define first-frame
      (with-handlers ([exn:fail? (lambda (e)
                                   (printf "ocapn-test-server: read-frame exn: ~a~n"
                                           (exn-message e))
                                   #f)])
        (read-frame cin)))
    (cond
      [(or (eof-object? first-frame) (not first-frame))
       (printf "ocapn-test-server: peer closed before sending start-session~n")]
      [else
       (define abort-reply (validate-incoming first-frame))
       (cond
         [(zero? (bytes-length abort-reply))
          (define cid (next-conn-id!))
          (drive-init! cid)
          (printf "ocapn-test-server: inbound start-session accepted (conn ~a); driving captp-core~n"
                  cid)
          (let loop ([n 1])
            (define frame (with-handlers ([exn:fail?
                                           (lambda (e)
                                             (printf "ocapn-test-server: read-frame exn after ~a frames: ~a~n"
                                                     n (exn-message e))
                                             #f)])
                            (read-frame cin)))
            (cond
              [(or (eof-object? frame) (not frame))
               (printf "ocapn-test-server: peer closed after ~a frames (conn ~a)~n" n cid)]
              [else
               (define out (drive-step cid frame))
               (printf "ocapn-test-server: conn ~a frame ~a (~a in / ~a out bytes)~n"
                       cid (+ n 1) (bytes-length frame) (bytes-length out))
               (when (> (bytes-length out) 0)
                 (write-frame cout out))
               (loop (+ n 1))]))]
         [else
          (printf "ocapn-test-server: inbound start-session REJECTED (~a bytes); sending op:abort~n"
                  (bytes-length abort-reply))
          (write-frame cout abort-reply)])]))
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
