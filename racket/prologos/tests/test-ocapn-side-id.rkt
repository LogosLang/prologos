#lang racket/base

;;; test-ocapn-side-id.rkt — the two side-id implementations must agree.
;;;
;;; A CapTP side-id is SHA-256 applied twice to the ENCODED public-key
;;; s-expression. It is computed in two places, in two languages:
;;;
;;;   * `read-start-session` in tools/interop/run-ocapn-test-server.rkt —
;;;     `(sha256-bytes (sha256-bytes pk-bytes))` over the raw frame slice.
;;;     Feeds the crossed-hellos tie-break.
;;;   * `side-id-of-encoded-key` in prologos::ocapn::crypto — `sha256d`,
;;;     i.e. `sha256-raw (sha256-raw s)` over a Latin-1 String. Feeds
;;;     handoff receive-binding and the session id.
;;;
;;; Nothing forces them to agree, and they are the SAME identity: if they
;;; diverge, the tie-break and the handoff machinery disagree about who the
;;; peer is, with no error anywhere. That is the shape gaps document §1.10
;;; finding 9 called out in the abstract and which turned out to be
;;; load-bearing twice — a slot wrong in one encoder and right in another,
;;; held wrong by fixtures that pinned the wrong form.
;;;
;;; The underlying hash is shared (`sha256-bytes` from `racket/base`, reached
;;; by Prologos through `crypto-sha256`), so what is actually under test is
;;; the COMPOSITION and the Latin-1 round trip either side of the FFI. That
;;; round trip is where this codebase's encoding bugs live: a Latin-1 byte
;;; string measured or re-encoded as UTF-8 silently changes above 0x7F, and
;;; every input here is a hash digest, which is half high-bit bytes.
;;;
;;; A DIFFERENTIAL ORACLE: it runs both implementations over one battery and
;;; compares. A test exercising only one would have passed throughout any
;;; divergence.

(require rackunit
         racket/list
         racket/string
         (only-in file/sha1 bytes->hex-string)
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
  "(ns test-ocapn-side-id)
(imports (prologos::ocapn::crypto :refer-all))
(imports (prologos::ocapn::handshake :refer-all))
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
  (last
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
     (process-string s))))

(define (string-result out who)
  (define m (regexp-match #px"^(\".*\") : String$" (string-trim out)))
  (unless m (error who "unreadable result: ~s" out))
  (string->bytes/latin-1 (read (open-input-string (cadr m)))))

;; Bytes cross as hex — the server's own channel, and the only safe one for a
;; digest inside a Prologos string literal.
(define (prologos-side-id pk-bytes)
  (string-result
   (run-last (format "(eval (side-id-of-encoded-key (hex-to-bytes ~s)))"
                     (bytes->hex-string pk-bytes)))
   'prologos-side-id))

;; The server's implementation, transcribed. It lives in a `#lang racket/base`
;; script that opens sockets at module level, so it cannot be required; this
;; copy is the same code and this file is the reason to keep it so.
(define (server-side-id pk-bytes)
  (sha256-bytes (sha256-bytes pk-bytes)))

;; A real gcrypt-encoded public key is mostly high-bit bytes inside an ASCII
;; s-expression frame, so the battery covers both regions and the boundary.
(define battery
  (list #""
        #"a"
        (bytes 0)
        (bytes 127)
        (bytes 128)                       ; first byte UTF-8 would widen
        (bytes 255)
        (bytes 0 127 128 255)
        (make-bytes 32 128)
        (make-bytes 64 255)
        ;; The shape the protocol actually hashes.
        (bytes-append #"[10'public-key[3'ecc[5'curve7'Ed25519][5'flags5'eddsa][1'q32:"
                      (list->bytes (for/list ([i (in-range 32)]) (modulo (* i 37) 256)))
                      #"]]]")
        ;; Every byte value, so no single value can be mishandled unnoticed.
        (list->bytes (for/list ([i (in-range 256)]) i))))

(test-case "side-id agrees across the language boundary"
  (for ([pk (in-list battery)])
    (check-equal? (prologos-side-id pk)
                  (server-side-id pk)
                  (format "side-id diverged for ~a-byte input ~a"
                          (bytes-length pk) (bytes->hex-string pk)))))

(test-case "side-id is 32 bytes and actually doubled"
  ;; Pins the doubling, not just the agreement: a single round would still
  ;; make both implementations agree if BOTH dropped it, and the two are
  ;; transcriptions of each other.
  (define pk #"abc")
  (check-equal? (bytes-length (prologos-side-id pk)) 32)
  (check-equal? (prologos-side-id pk) (sha256-bytes (sha256-bytes pk)))
  (check-not-equal? (prologos-side-id pk) (sha256-bytes pk)
                    "side-id is a SINGLE hash — the doubling was lost"))

(test-case "distinct keys get distinct side-ids"
  (define ids (map prologos-side-id battery))
  (check-equal? (length (remove-duplicates ids)) (length ids)))
