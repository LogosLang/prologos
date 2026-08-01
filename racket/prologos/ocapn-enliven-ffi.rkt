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
;;;   ocapn-enliven-peek  : (String -> String)
;;;     The pending enliven for a key, WITHOUT removing it. "" for a miss,
;;;     which is every ordinary deliver.
;;;
;;;   ocapn-enliven-drop  : (String -> Bool)
;;;     Remove it, once the caller has decided it can act on it.
;;;
;;;     PEEK-THEN-DROP, not claim-then-check. The single `claim` this replaces
;;;     removed unconditionally and the caller validated afterwards, so any
;;;     deliver to a reserved slot that was NOT a well-formed `['fulfill REF]`
;;;     — a break, a `desc:answer` reference, a second delivery — consumed the
;;;     pending handoff permanently, with nothing logged and no way back. The
;;;     handoff then stalled forever. Validate first; remove only when the
;;;     frame is one we are actually going to answer.
;;;
;;;     The drop is still a single critical section, which is what stops two
;;;     threads both acting on one entry: `drop` reports whether IT was the
;;;     one that removed, so the caller can make the send conditional on
;;;     having won.
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
         ocapn-enliven-peek
         ocapn-enliven-drop
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

(define (ocapn-enliven-peek key)
  (call-with-semaphore lock (lambda () (hash-ref pending key ""))))

;; #t only for the caller that actually removed it. Two threads racing one
;; slot: exactly one sees #t, so exactly one sends.
(define (ocapn-enliven-drop key)
  (call-with-semaphore lock
    (lambda ()
      (cond [(hash-has-key? pending key) (hash-remove! pending key) #t]
            [else #f]))))

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
   'ocapn-enliven-peek  (cons ocapn-enliven-peek  '(String -> String))
   'ocapn-enliven-drop  (cons ocapn-enliven-drop  '(String -> Bool))
   'ocapn-gift-id       (cons ocapn-gift-id       '(String -> String))))
