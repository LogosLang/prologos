#lang racket/base

;;;
;;; ocapn-conn-ffi.rkt — per-connection state stash for the OCapN
;;; interop test server.
;;;
;;; The server drives captp-core's `connection-step` one wire frame at
;;; a time. Each frame is a separate `process-string` evaluation (so
;;; each gets a fresh reduction-fuel budget). The `ConnectionState`
;;; value must therefore persist BETWEEN those evaluations.
;;;
;;; A `ConnectionState` is a rich Prologos ADT — it cannot be marshalled
;;; through the FFI boundary. But the foreign mechanism PASSES THROUGH
;;; any type it does not recognise (`base-type-name` -> 'Passthrough):
;;; the raw IR value crosses unchanged. So the Prologos driver stashes
;;; and fetches the opaque `ConnectionState` here, keyed by an integer
;;; connection id the server assigns.

(provide ocapn-conn-stash
         ocapn-conn-fetch
         ocapn-conn-reset)

;; conn-id (integer) -> opaque ConnectionState IR value.
(define conn-table (make-hash))

(define (ocapn-conn-stash conn-id state)
  "Store the ConnectionState for a connection. Returns #t."
  (hash-set! conn-table conn-id state)
  #t)

(define (ocapn-conn-fetch conn-id)
  "Retrieve the ConnectionState for a connection (#f if never stashed)."
  (hash-ref conn-table conn-id #f))

(define (ocapn-conn-reset conn-id)
  "Drop a connection's state once it closes. Returns #t."
  (hash-remove! conn-table conn-id)
  #t)
