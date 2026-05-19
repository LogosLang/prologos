#lang racket/base

;;;
;;; ocapn-crypto.rkt — Phase 58 helper.
;;;
;;; Wraps OpenSSL CLI for Ed25519 keygen + sign + verify. Used by
;;; the OCapN test server to build the 4-field signed
;;; op:start-session that the upstream ocapn-test-suite requires.
;;;
;;; Rationale: Racket's `crypto` package isn't available offline,
;;; and OpenSSL CLI works fine for our needs (one-shot keygen +
;;; sign per server start, occasional verify). Shelling out is
;;; slow per call (~50ms) but our crypto budget is one call per
;;; handshake — fine.

(require racket/system
         racket/port
         racket/file)

(provide make-ed25519-keypair
         ed25519-sign
         ed25519-verify
         ed25519-pubkey-bytes)

;; ========================================
;; Keypair container
;; ========================================
;;
;; A "keypair" here is the path to a PEM-encoded Ed25519 private
;; key file. The public-key bytes are read on demand via openssl.

(struct keypair (private-pem-path) #:transparent)

(define (make-ed25519-keypair)
  "Generate a fresh Ed25519 keypair. Returns a keypair struct."
  (define pem-path (make-temporary-file "ocapn-ed25519-~a.pem"))
  (define result
    (system* (find-executable-path "openssl")
             "genpkey" "-algorithm" "ED25519"
             "-out" (path->string pem-path)))
  (unless result
    (error 'make-ed25519-keypair "openssl genpkey failed"))
  (keypair pem-path))

(define (ed25519-pubkey-bytes kp)
  "Extract the raw 32-byte Ed25519 public key from a keypair."
  ;; OpenSSL outputs DER-encoded SPKI: a 12-byte ASN.1 header
  ;; followed by the 32 raw pubkey bytes.
  (define out (open-output-bytes))
  (define result
    (parameterize ([current-output-port out])
      (system* (find-executable-path "openssl")
               "pkey" "-in" (path->string (keypair-private-pem-path kp))
               "-pubout" "-outform" "DER")))
  (unless result
    (error 'ed25519-pubkey-bytes "openssl pkey failed"))
  (define der (get-output-bytes out))
  ;; Drop the 12-byte SPKI header.
  (unless (= (bytes-length der) 44)
    (error 'ed25519-pubkey-bytes "expected 44-byte DER; got ~a" (bytes-length der)))
  (subbytes der 12))

(define (ed25519-sign kp msg)
  "Sign `msg` (bytes) with Ed25519 private key. Returns 64-byte signature."
  (define msg-path (make-temporary-file "ocapn-msg-~a.bin"))
  (define sig-path (make-temporary-file "ocapn-sig-~a.bin"))
  (with-output-to-file msg-path #:exists 'truncate
    (lambda () (write-bytes msg)))
  (define result
    (system* (find-executable-path "openssl")
             "pkeyutl" "-sign"
             "-inkey" (path->string (keypair-private-pem-path kp))
             "-rawin" "-in" (path->string msg-path)
             "-out" (path->string sig-path)))
  (define sig-bytes (file->bytes sig-path))
  (delete-file msg-path)
  (delete-file sig-path)
  (unless result
    (error 'ed25519-sign "openssl pkeyutl -sign failed"))
  (unless (= (bytes-length sig-bytes) 64)
    (error 'ed25519-sign "expected 64-byte signature; got ~a" (bytes-length sig-bytes)))
  sig-bytes)

(define (ed25519-verify pubkey-bytes msg sig)
  "Verify Ed25519 signature. pubkey-bytes is 32 raw bytes. Returns #t on success, #f on failure."
  ;; Build a temporary public-key PEM file from the raw bytes.
  ;; SPKI header for Ed25519: 30 2a 30 05 06 03 2b 65 70 03 21 00
  (unless (= (bytes-length pubkey-bytes) 32)
    (error 'ed25519-verify "expected 32-byte pubkey; got ~a" (bytes-length pubkey-bytes)))
  (unless (= (bytes-length sig) 64)
    (error 'ed25519-verify "expected 64-byte sig; got ~a" (bytes-length sig)))
  (define spki-header
    (bytes #x30 #x2a #x30 #x05 #x06 #x03 #x2b #x65 #x70 #x03 #x21 #x00))
  (define der (bytes-append spki-header pubkey-bytes))
  (define der-path (make-temporary-file "ocapn-pub-~a.der"))
  (define pem-path (make-temporary-file "ocapn-pub-~a.pem"))
  (define msg-path (make-temporary-file "ocapn-vmsg-~a.bin"))
  (define sig-path (make-temporary-file "ocapn-vsig-~a.bin"))
  (with-output-to-file der-path #:exists 'truncate
    (lambda () (write-bytes der)))
  (with-output-to-file msg-path #:exists 'truncate
    (lambda () (write-bytes msg)))
  (with-output-to-file sig-path #:exists 'truncate
    (lambda () (write-bytes sig)))
  ;; Convert DER → PEM (openssl pkeyutl wants PEM for the pubkey).
  (define conv-result
    (system* (find-executable-path "openssl")
             "pkey" "-pubin" "-inform" "DER" "-in" (path->string der-path)
             "-out" (path->string pem-path)))
  (define result
    (and conv-result
         (parameterize ([current-output-port (open-output-nowhere)]
                        [current-error-port (open-output-nowhere)])
           (system* (find-executable-path "openssl")
                    "pkeyutl" "-verify"
                    "-pubin" "-inkey" (path->string pem-path)
                    "-rawin" "-in" (path->string msg-path)
                    "-sigfile" (path->string sig-path)))))
  (delete-file der-path)
  (delete-file pem-path)
  (delete-file msg-path)
  (delete-file sig-path)
  result)

(define (open-output-nowhere) (open-output-bytes))
