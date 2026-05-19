#lang racket/base

;;;
;;; ocapn-crypto.rkt — Phase 58 (revised): Ed25519 via Racket FFI
;;; into libsodium.
;;;
;;; Replaces the original openssl-CLI shellout. Direct FFI is:
;;;   - ~100× faster (no subprocess per crypto op)
;;;   - no temp files
;;;   - usable from Prologos via the existing FFI hooks (when this
;;;     module gets folded into the captp-core implementation)
;;;
;;; libsodium APIs used (all from <sodium/crypto_sign.h>):
;;;   int crypto_sign_keypair(uint8_t *pk, uint8_t *sk);
;;;   int crypto_sign_detached(uint8_t *sig, uint64_t *siglen,
;;;                            const uint8_t *m, uint64_t mlen,
;;;                            const uint8_t *sk);
;;;   int crypto_sign_verify_detached(const uint8_t *sig,
;;;                                   const uint8_t *m, uint64_t mlen,
;;;                                   const uint8_t *pk);
;;;
;;; Sizes:
;;;   crypto_sign_PUBLICKEYBYTES = 32
;;;   crypto_sign_SECRETKEYBYTES = 64 (includes pubkey appended)
;;;   crypto_sign_BYTES          = 64 (signature)

(require ffi/unsafe
         ffi/unsafe/define)

(provide make-ed25519-keypair
         ed25519-sign
         ed25519-verify
         ed25519-pubkey-bytes
         keypair-private
         keypair-public)

(define-ffi-definer define-sodium (ffi-lib "libsodium" '("23" #f)))

;; int sodium_init(void) — must be called once before any other
;; libsodium function. Idempotent; returns 0 on first call, 1 if
;; already initialized, -1 on error.
(define-sodium sodium-init (_fun -> _int) #:c-id sodium_init)

;; int crypto_sign_keypair(unsigned char *pk, unsigned char *sk);
(define-sodium crypto-sign-keypair
  (_fun [pk : (_bytes o 32)]
        [sk : (_bytes o 64)]
        -> [r : _int]
        -> (values r pk sk))
  #:c-id crypto_sign_keypair)

;; int crypto_sign_detached(uint8_t *sig, uint64_t *siglen,
;;                          const uint8_t *m, uint64_t mlen,
;;                          const uint8_t *sk);
(define-sodium crypto-sign-detached
  (_fun [sig : (_bytes o 64)]
        [siglen : (_ptr o _uint64)]
        [m : _bytes]
        [mlen : _uint64 = (bytes-length m)]
        [sk : _bytes]
        -> [r : _int]
        -> (values r sig siglen))
  #:c-id crypto_sign_detached)

;; int crypto_sign_verify_detached(const uint8_t *sig,
;;                                 const uint8_t *m, uint64_t mlen,
;;                                 const uint8_t *pk);
(define-sodium crypto-sign-verify-detached
  (_fun [sig : _bytes]
        [m : _bytes]
        [mlen : _uint64 = (bytes-length m)]
        [pk : _bytes]
        -> _int)
  #:c-id crypto_sign_verify_detached)

;; Initialise libsodium on module load.
(define _init-result (sodium-init))
(unless (or (= _init-result 0) (= _init-result 1))
  (error 'ocapn-crypto "sodium_init failed: ~a" _init-result))

;; ========================================
;; Keypair container
;; ========================================
;;
;; libsodium's secret key is 64 bytes — the 32 raw bytes followed
;; by the 32-byte public key. We store both fields explicitly for
;; convenience.

(struct keypair (private public) #:transparent)

(define (make-ed25519-keypair)
  "Generate a fresh Ed25519 keypair. Returns a keypair struct."
  (define-values (r pk sk) (crypto-sign-keypair))
  (unless (= r 0)
    (error 'make-ed25519-keypair "crypto_sign_keypair failed: ~a" r))
  (keypair sk pk))

(define (ed25519-pubkey-bytes kp)
  "Return the 32-byte raw Ed25519 public key from a keypair."
  (keypair-public kp))

(define (ed25519-sign kp msg)
  "Sign `msg` (bytes) with the keypair's private key. Returns the
   64-byte detached signature."
  (define-values (r sig siglen) (crypto-sign-detached msg (keypair-private kp)))
  (unless (= r 0)
    (error 'ed25519-sign "crypto_sign_detached failed: ~a" r))
  sig)

(define (ed25519-verify pubkey-bytes msg sig)
  "Verify Ed25519 signature. pubkey-bytes is 32 raw bytes; sig is
   64. Returns #t on success, #f on failure."
  (unless (= (bytes-length pubkey-bytes) 32)
    (error 'ed25519-verify "expected 32-byte pubkey; got ~a" (bytes-length pubkey-bytes)))
  (unless (= (bytes-length sig) 64)
    (error 'ed25519-verify "expected 64-byte sig; got ~a" (bytes-length sig)))
  (= 0 (crypto-sign-verify-detached sig msg pubkey-bytes)))
