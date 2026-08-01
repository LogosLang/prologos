#lang racket/base

;;;
;;; ocapn-identity-ffi.rkt — the process's signing key, by handle.
;;;
;;; ONE value, deliberately. Everything else about our identity is
;;; DERIVABLE from it and so is not stored here:
;;;
;;;   our raw public key  = `pubkey-raw handle`            (crypto.prologos)
;;;   our side-id         = `side-id-of-encoded-key` of its gcrypt sexp
;;;   a session id        = `session-id-of ours theirs`
;;;
;;; and the PEER's key is already on the connection — `bs-peer-key`, put
;;; there by the start-session handler. So a driver holding this handle can
;;; compute every field of a `desc:handoff-give` and a
;;; `desc:handoff-receive` without asking Racket for anything further.
;;;
;;; That is the whole point. The gifter and receiver roles lived in the
;;; Racket test server partly because signing lived there; the identity
;;; substrate is this handle plus SHA-256, and both are now reachable from
;;; Prologos.
;;;
;;; The keypair itself stays in `crypto-ffi.rkt`'s handle table, where the
;;; secret key is zeroed on release. Nothing here can read it — a handle is
;;; an index, and the only operations on it are sign/pubkey/close.
;;;
;;;   ocapn-identity-set!    : called by the SERVER once, at startup, with
;;;                            the handle it generated for the handshake.
;;;                            Both sides must sign with the SAME key: a
;;;                            handoff-give names the gifter's session key,
;;;                            and the peer checks it against the one we
;;;                            presented in our op:start-session.
;;;
;;;   ocapn-identity-keypair : (Nat -> Nat)
;;;     The handle, or the caller's fallback when the server never set one
;;;     (a unit test loading the driver without a server). Taking a
;;;     fallback rather than returning 0 keeps the miss visible at the call
;;;     site instead of turning into a signature made with keypair 0.

(provide ocapn-identity-set!
         ocapn-identity-keypair
         ocapn-identity-reset!
         ocapn-identity-ffi-registry)

(define lock (make-semaphore 1))
(define keypair-handle #f)

(define (ocapn-identity-set! h)
  (call-with-semaphore lock (lambda () (set! keypair-handle h)))
  #t)

(define (ocapn-identity-keypair fallback)
  (call-with-semaphore lock (lambda () (or keypair-handle fallback))))

(define (ocapn-identity-reset!)
  (call-with-semaphore lock (lambda () (set! keypair-handle #f))))

(define ocapn-identity-ffi-registry
  (hasheq
   'ocapn-identity-keypair (cons ocapn-identity-keypair '(Nat -> Nat))))
