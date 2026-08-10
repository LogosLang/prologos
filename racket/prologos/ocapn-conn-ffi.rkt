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
;;;
;;;   ocapn-conn-fetch : (Nat -> ConnectionState -> ConnectionState)
;;;     Takes the caller's `ConnectionState` as a fallback for the
;;;     never-stashed case, the same way ocapn-gift-ffi.rkt's fetch takes
;;;     the empty list. The FFI cannot construct a Prologos value itself,
;;;     and returning #f would hand the reducer a non-ADT where a
;;;     `ConnectionState` is expected — which crashes `nf` rather than
;;;     erroring, since #f is not a value the reducer has a case for. The
;;;     miss is not silent: it is reported on stderr, because the only way
;;;     to reach it is an `init-connection` that did not land.
;;;
;;;   ocapn-conn-reset : called by the SERVER when a connection closes.
;;;     Nothing else drops an entry, so a missed call retains that
;;;     connection's whole vat — actors, promises, both tables — for the
;;;     life of the process.
;;;
;;; The server hands each accepted connection its own thread, so all three
;;; entry points can run concurrently. Racket's `make-hash` is not safe
;;; for concurrent mutation, hence the semaphore.

(provide ocapn-conn-stash
         ocapn-conn-fetch
         ocapn-conn-reset)

;; conn-id (integer) -> opaque ConnectionState IR value.
(define conn-table (make-hash))
(define conn-sema (make-semaphore 1))

(define (ocapn-conn-stash conn-id state)
  "Store the ConnectionState for a connection. Returns #t."
  (call-with-semaphore conn-sema
    (lambda () (hash-set! conn-table conn-id state)))
  #t)

(define (ocapn-conn-fetch conn-id fallback)
  "Retrieve the ConnectionState for a connection, or `fallback` if never stashed."
  (call-with-semaphore conn-sema
    (lambda ()
      (hash-ref conn-table conn-id
                (lambda ()
                  (eprintf "ocapn-conn-ffi: no state for connection ~a — init-connection did not land; using the caller's fallback~n"
                           conn-id)
                  fallback)))))

(define (ocapn-conn-reset conn-id)
  "Drop a connection's state once it closes. Returns #t."
  (call-with-semaphore conn-sema
    (lambda () (hash-remove! conn-table conn-id)))
  #t)
