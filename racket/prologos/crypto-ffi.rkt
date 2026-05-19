#lang racket/base

;;;
;;; crypto-ffi.rkt — Phase 58.b: Ed25519 FFI bridge for Prologos.
;;;
;;; Mirrors `tcp-ffi.rkt`'s handle-table + registry approach:
;;; Prologos sees only integer handles + Latin-1-encoded String
;;; payloads; Racket maintains a keypair-id → keypair table.
;;;
;;; Prologos `String` carries arbitrary bytes via Latin-1 (any
;;; 0-255 byte is a valid 1-char Latin-1 string). The same
;;; convention is already used by `syrup-bytes` in the wire codec.
;;;
;;; Primitives (handle ID semantics):
;;;
;;;   crypto-gen-keypair    : (-> Nat)
;;;     Generate a fresh Ed25519 keypair; return its handle.
;;;
;;;   crypto-pubkey         : (Nat -> String)
;;;     Return the 32-byte raw public key as a Latin-1 String.
;;;
;;;   crypto-sign           : (Nat -> String -> String)
;;;     Sign the given message bytes (Latin-1 String) with the
;;;     keypair's private key. Returns 64-byte signature as
;;;     Latin-1 String.
;;;
;;;   crypto-verify         : (String -> String -> String -> Bool)
;;;     Verify a signature given (pubkey-bytes, message-bytes,
;;;     signature-bytes), all as Latin-1 Strings. Returns Bool.
;;;
;;;   crypto-close-keypair  : (Nat -> Bool)
;;;     Release a keypair handle. Returns #t if it was present.

(require ffi/unsafe
         ffi/unsafe/define
         racket/list)

(provide
 crypto-gen-keypair
 crypto-pubkey
 crypto-sign
 crypto-verify
 crypto-close-keypair
 crypto-ffi-registry
 ;; Test-only helpers
 crypto-table-size
 crypto-table-clear!)

;; ========================================
;; libsodium binding
;; ========================================

(define-ffi-definer define-sodium (ffi-lib "libsodium" '("23" #f)))

(define-sodium sodium-init (_fun -> _int) #:c-id sodium_init)

(define-sodium crypto-sign-keypair-raw
  (_fun [pk : (_bytes o 32)]
        [sk : (_bytes o 64)]
        -> [r : _int]
        -> (values r pk sk))
  #:c-id crypto_sign_keypair)

(define-sodium crypto-sign-detached-raw
  (_fun [sig : (_bytes o 64)]
        [siglen : (_ptr o _uint64)]
        [m : _bytes]
        [mlen : _uint64 = (bytes-length m)]
        [sk : _bytes]
        -> [r : _int]
        -> (values r sig siglen))
  #:c-id crypto_sign_detached)

(define-sodium crypto-sign-verify-detached-raw
  (_fun [sig : _bytes]
        [m : _bytes]
        [mlen : _uint64 = (bytes-length m)]
        [pk : _bytes]
        -> _int)
  #:c-id crypto_sign_verify_detached)

;; Initialise libsodium on module load.
(let ([r (sodium-init)])
  (unless (or (= r 0) (= r 1))
    (error 'crypto-ffi "sodium_init failed: ~a" r)))

;; ========================================
;; Latin-1 String ↔ raw bytes
;; ========================================
;;
;; Prologos's `String` is Racket's `string`. Racket strings can
;; hold any code point including 128-255. We round-trip raw bytes
;; via Latin-1 (each byte becomes a 1-char string slice).

(define (string->raw-bytes s)
  (string->bytes/latin-1 s))

(define (raw-bytes->string b)
  (bytes->string/latin-1 b))

;; ========================================
;; Keypair handle table
;; ========================================
;;
;; Each entry maps a handle (Nat) to (cons pubkey-bytes secret-key-bytes).

(define crypto-table  (make-hasheq))
(define crypto-next-id 0)

(define (crypto-fresh-id!)
  (define id crypto-next-id)
  (set! crypto-next-id (add1 id))
  id)

(define (crypto-store! pk sk)
  (define id (crypto-fresh-id!))
  (hash-set! crypto-table id (cons pk sk))
  id)

(define (crypto-lookup id)
  (hash-ref crypto-table id
            (lambda () (error 'crypto-ffi "invalid keypair handle: ~a" id))))

(define (crypto-table-size)
  (hash-count crypto-table))

(define (crypto-table-clear!)
  (set! crypto-table (make-hasheq))
  (set! crypto-next-id 0))

;; ========================================
;; Prologos-visible operations
;; ========================================

(define (crypto-gen-keypair [_unit #f])
  "Generate a fresh Ed25519 keypair; store it in the table; return its handle.
   The optional _unit argument is accepted so callers can invoke this from
   Prologos with a unit value (Prologos zero-arg foreign functions accept
   one dummy argument)."
  (define-values (r pk sk) (crypto-sign-keypair-raw))
  (unless (= r 0)
    (error 'crypto-gen-keypair "crypto_sign_keypair failed: ~a" r))
  (crypto-store! pk sk))

(define (crypto-pubkey id)
  "Return the 32-byte raw Ed25519 public key for the keypair handle as a Latin-1 String."
  (raw-bytes->string (car (crypto-lookup id))))

(define (crypto-sign id msg-str)
  "Sign `msg-str` (Latin-1 bytes) with the keypair's private key. Returns 64-byte signature as Latin-1 String."
  (define sk (cdr (crypto-lookup id)))
  (define msg (string->raw-bytes msg-str))
  (define-values (r sig _siglen) (crypto-sign-detached-raw msg sk))
  (unless (= r 0)
    (error 'crypto-sign "crypto_sign_detached failed: ~a" r))
  (raw-bytes->string sig))

(define (crypto-verify pubkey-str msg-str sig-str)
  "Verify Ed25519 signature. All three args are Latin-1 Strings of raw bytes."
  (define pk (string->raw-bytes pubkey-str))
  (define msg (string->raw-bytes msg-str))
  (define sig (string->raw-bytes sig-str))
  (unless (= (bytes-length pk) 32)
    (error 'crypto-verify "expected 32-byte pubkey; got ~a" (bytes-length pk)))
  (unless (= (bytes-length sig) 64)
    (error 'crypto-verify "expected 64-byte sig; got ~a" (bytes-length sig)))
  (= 0 (crypto-sign-verify-detached-raw sig msg pk)))

(define (crypto-close-keypair id)
  "Release a keypair handle. Returns #t if it was present."
  (define present? (hash-has-key? crypto-table id))
  (when present?
    (hash-remove! crypto-table id))
  present?)

;; ========================================
;; FFI registry (mirrors tcp-ffi-registry)
;; ========================================

(define crypto-ffi-registry
  (hasheq
   'crypto-gen-keypair    (cons crypto-gen-keypair    '(-> Nat))
   'crypto-pubkey         (cons crypto-pubkey         '(Nat -> String))
   'crypto-sign           (cons crypto-sign           '(Nat -> String -> String))
   'crypto-verify         (cons crypto-verify         '(String -> String -> String -> Bool))
   'crypto-close-keypair  (cons crypto-close-keypair  '(Nat -> Bool))))
