#lang racket/base

;;;
;;; ocapn-enliven-ffi.rkt — the GIFTER's side of a third-party handoff.
;;;
;;; An enliven arrives on the receiver's connection and the `fetch` it
;;; triggers goes out on the exporter's. The exporter's answer therefore
;;; comes back on a connection that knows nothing about the enliven that
;;; started it, and something has to hold the two together across that gap.
;;;
;;; Same shape as the gift table and the parked gives: an exporter-global
;;; table behind an FFI, written by whichever connection thread is stepping
;;; and read by any other.
;;;
;;;   ocapn-enliven-park  : (String -> String -> Bool)
;;;     Hold a pending enliven under a key naming the EXPORTER connection and
;;;     the export position we reserved on it — that pair is what the
;;;     exporter's answer arrives addressed to, and it is the only thing in
;;;     that answer we chose.
;;;
;;;   ocapn-enliven-claim : (String -> String)
;;;     Take the pending enliven for a key, removing it. "" when there is
;;;     none, which is every ordinary deliver.
;;;
;;;     Claim REMOVES, and the read and the remove are one critical section.
;;;     A `for/first` scan followed by a separate remove let two threads both
;;;     pass and send the give twice — which is what the Racket version this
;;;     replaces had to be fixed for.
;;;
;;;   ocapn-gift-id : (String -> String)
;;;     A fresh gift id, `prefix` ++ a counter. Ids must be unique: the gift
;;;     table is keyed BY gift id, its lookup returns the newest match and its
;;;     removal removes EVERY match, so two outstanding handoffs sharing one
;;;     id cross-wire and then delete each other. This was a process-wide
;;;     literal once.
;;;
;;; The parked VALUE is opaque here — the Prologos side encodes its fields as
;;; Syrup and hands over the bytes. That keeps the field list in one place
;;; (the driver, which is the only thing that reads it) instead of spread
;;; across an FFI signature that would have to change with it.

(provide ocapn-enliven-park
         ocapn-enliven-claim
         ocapn-gift-id
         ocapn-enliven-reset!
         ocapn-enliven-ffi-registry)

(define lock (make-semaphore 1))

;; "<cid>:<slot>" -> the parked enliven, Syrup-encoded by the caller
(define pending (make-hash))

(define gift-counter 0)

(define (ocapn-enliven-park key blob)
  (call-with-semaphore lock (lambda () (hash-set! pending key blob)))
  #t)

(define (ocapn-enliven-claim key)
  (call-with-semaphore lock
    (lambda ()
      (define v (hash-ref pending key ""))
      (hash-remove! pending key)
      v)))

(define (ocapn-gift-id prefix)
  (call-with-semaphore lock
    (lambda ()
      (define n gift-counter)
      (set! gift-counter (add1 n))
      (format "~a~a" prefix n))))

(define (ocapn-enliven-reset!)
  (call-with-semaphore lock
    (lambda () (hash-clear! pending) (set! gift-counter 0))))

(define ocapn-enliven-ffi-registry
  (hasheq
   'ocapn-enliven-park  (cons ocapn-enliven-park  '(String -> String -> Bool))
   'ocapn-enliven-claim (cons ocapn-enliven-claim '(String -> String))
   'ocapn-gift-id       (cons ocapn-gift-id       '(String -> String))))
