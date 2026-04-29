#lang racket/base

;;;
;;; Phase 3 of OCapN interop — live tcp-testing-only handshake.
;;;
;;; Two threads in one process exchange a CapTP message over a
;;; real localhost TCP socket using the Phase-2 wire codec
;;; (encode-op/decode-op). The line is the CapTP message bytes
;;; with a trailing newline (Phase-0 framing convention from
;;; tcp-testing.prologos).
;;;
;;; This is the end-to-end validation of the interop pipeline:
;;;   CapTPOp → op-to-syrup → wire::encode → bytes
;;;   bytes → wire::decode-value → syrup-to-op → CapTPOp
;;;
;;; What this test does NOT do:
;;;   - exchange with @endo/ocapn (no Node dependency in CI)
;;;   - real CapTP handshake protocol — just one send/receive
;;;   - cryptographic auth (tcp-testing-only is by design unauth'd)
;;;

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
         "../multi-dispatch.rkt")

(define shared-preamble
  "(ns test-ocapn-netlayer-tcp)
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

(define (check-contains actual substr [msg #f])
  (check-true (string-contains? actual substr)
              (or msg (format "Expected ~s to contain ~s" actual substr))))

;; ========================================
;; Helpers — bytes ↔ Prologos String
;; ========================================
;;
;; The test-support fixture's `run` returns a string of the form
;; "<value> : <type>". The encoded bytes look like e.g.
;; "<5'op:abort5\"hello>" — extracting them requires stripping
;; the wrapper. We do this by re-encoding via a fresh Prologos
;; eval that returns the bytes directly, then extracting the
;; literal-string region.

;; Extract the literal value string from a "value : type" string.
;; The Prologos pretty-printer prints String values with the same
;; \" / \\ escapes Racket uses, so `read`ing the quoted prefix
;; recovers the literal byte sequence directly.
(define (extract-value-bytes s)
  (define m (regexp-match #px"^(\".*\") : String$" s))
  (unless m
    (error 'extract-value-bytes "couldn't extract bytes from: ~s" s))
  (read (open-input-string (cadr m))))
(define (encode-op-bytes prologos-expr)
  (extract-value-bytes (run-last prologos-expr)))

;; ========================================
;; Phase 3: end-to-end TCP exchange
;; ========================================
;;
;; Strategy: bind a localhost server on an ephemeral port, then
;; spawn a thread that accepts ONE connection and reads ONE line.
;; The main thread connects, sends the encoded message + newline,
;; and waits for the accept thread's result through a channel.

(define (with-localhost-port f)
  ;; tcp-listen with port 0 picks an ephemeral port.
  (define listener (tcp-listen 0 4 #t "127.0.0.1"))
  (define-values (_ local-port _2 _3) (tcp-addresses listener #t))
  (with-handlers ([exn:fail? (lambda (e)
                               (tcp-close listener)
                               (raise e))])
    (define result (f listener local-port))
    (tcp-close listener)
    result))

(test-case "netlayer-tcp/round-trip op:abort across real TCP socket"
  ;; 1. Encode "op-abort \"phase-3-works\"" to wire bytes.
  (define wire-bytes
    (encode-op-bytes
     "(eval (encode-op (op-abort \"phase-3-works\")))"))
  (check-equal? (substring wire-bytes 0 9) "<8'op:abo")
  ;; 2. Set up TCP localhost server, spawn accept thread.
  (with-localhost-port
   (lambda (listener port)
     (define done-ch (make-channel))
     (thread
      (lambda ()
        (define-values (in out) (tcp-accept listener))
        (define line (read-line in 'linefeed))
        (close-input-port in)
        (close-output-port out)
        (channel-put done-ch line)))
     ;; 3. Main thread: connect + send the wire bytes + newline.
     (define-values (cin cout) (tcp-connect "127.0.0.1" port))
     (write-string wire-bytes cout)
     (write-string "\n" cout)
     (flush-output cout)
     (close-output-port cout)
     (close-input-port cin)
     ;; 4. Wait for the accept thread to surface the line.
     (define received-line (sync done-ch))
     (check-equal? received-line wire-bytes
                   "TCP round-trip preserved bytes exactly")
     ;; 5. Decode the received bytes back to a CapTPOp via Prologos.
     ;; Embed via Racket's `format` with a quoted Prologos string;
     ;; we use `~v` so Racket re-escapes to a syntactically valid
     ;; quoted form that Prologos also accepts.
     (define probe-expr
       (format "(eval (decode-op ~v))" received-line))
     (check-contains (run-last probe-expr) "op-abort"))))

(test-case "netlayer-tcp/round-trip op:gc-answer across real TCP socket"
  (define wire-bytes
    (encode-op-bytes
     "(eval (encode-op (op-gc-answer (suc (suc zero)))))"))
  (with-localhost-port
   (lambda (listener port)
     (define done-ch (make-channel))
     (thread
      (lambda ()
        (define-values (in out) (tcp-accept listener))
        (define line (read-line in 'linefeed))
        (close-input-port in)
        (close-output-port out)
        (channel-put done-ch line)))
     (define-values (cin cout) (tcp-connect "127.0.0.1" port))
     (write-string wire-bytes cout)
     (write-string "\n" cout)
     (flush-output cout)
     (close-output-port cout)
     (close-input-port cin)
     (define received-line (sync done-ch))
     (check-equal? received-line wire-bytes)
     (check-contains
      (run-last (format "(eval (decode-op ~v))" received-line))
      "op-gc-answer"))))
