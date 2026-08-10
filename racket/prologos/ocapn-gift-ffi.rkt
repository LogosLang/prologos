#lang racket/base

;;;
;;; ocapn-gift-ffi.rkt — the exporter's cross-connection gift table.
;;;
;;; A third-party handoff necessarily spans two connections: the GIFTER
;;; deposits a gift on its session with us, and the RECEIVER — a different
;;; peer, on a different socket — withdraws it on its own. Upstream's
;;; `HandoffRemoteAsExporter` opens exactly those two sessions.
;;;
;;; Our gift table lived in `BridgeState`, which ocapn-conn-ffi.rkt stashes PER
;;; CONNECTION, so the deposit landed in conn 0's table and the withdraw
;;; searched conn 1's and correctly reported no-such-gift. The table is keyed by
;;; gift-id precisely so another session can withdraw it — it is exporter-GLOBAL
;;; state, not session state.
;;;
;;; Same passthrough trick as the ConnectionState stash: the foreign mechanism
;;; passes through any type it does not recognise, so the opaque
;;; `[List GiftEntry]` crosses unmarshalled. The driver seeds the table into a
;;; connection's BridgeState before a step and publishes it back after, which
;;; keeps captp-core.prologos a pure function of its inputs.
;;;
;;; ONLY deposited gifts belong here. captp-core's gift table also holds parked
;;; withdrawals and spent handoff identities, and both of those are keyed by
;;; values that are only unique WITHIN a connection — every connection's vat
;;; seeds its promise ids from the same counter, so connection A's park on its
;;; promise 8 and connection B's park on ITS promise 8 collide. The driver
;;; therefore publishes `bs-exportable-gifts` (gifts only) and `bs-set-gifts`
;;; re-attaches the connection's own park/used entries on the way back in.
;;;
;;; The server gives each accepted connection its own thread, so both entry
;;; points can run concurrently; Racket's `make-hash` is not safe for
;;; concurrent mutation, hence the semaphore.

(provide ocapn-gift-stash
         ocapn-gift-fetch)

;; Single-slot: the whole gift list, opaque. Keyed anyway so the Prologos-side
;; foreign signature has an argument to take.
(define gift-table (make-hash))
(define gift-sema (make-semaphore 1))

(define (ocapn-gift-stash key gifts)
  "Publish the exporter-global gift list. Returns #t."
  (call-with-semaphore gift-sema
    (lambda () (hash-set! gift-table key gifts)))
  #t)

;; Takes the empty list from the Prologos side as a fallback: the FFI cannot
;; construct a Prologos `nil` itself, and returning #f would put a non-list
;; where a [List GiftEntry] is expected — which crashes `nf` rather than
;; erroring, since #f is not a value the reducer has a case for.
(define (ocapn-gift-fetch key empty)
  "Retrieve the exporter-global gift list, or `empty` if never stashed."
  (call-with-semaphore gift-sema
    (lambda () (hash-ref gift-table key empty))))
