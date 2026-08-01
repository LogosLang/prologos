#lang racket/base

;;;
;;; ocapn-give-ffi.rkt — the RECEIVER's side of a third-party handoff.
;;;
;;; A gifter hands us a signed `desc:handoff-give` naming an exporter we may
;;; have no connection to. We dial that exporter, and on the session that
;;; results we present a `desc:handoff-receive` to withdraw the gift. The
;;; give therefore has to survive the gap between those two connections —
;;; it arrives on one and is spent on another — which is exactly the
;;; lifetime the gift table already has, and this is the same shape.
;;;
;;;   ocapn-give-park  : (String -> String -> Bool)
;;;     Hold a signed give against the LOCATION KEY of the exporter it
;;;     names. Keyed by location and not by connection: at park time the
;;;     connection does not exist yet — dialling it is the next step.
;;;
;;;   ocapn-give-claim : (String -> String)
;;;     Take the give waiting on a location, removing it. "" when there is
;;;     none, which is the common case: every start-session asks.
;;;
;;;     Claim REMOVES, and the read and the remove are one critical section.
;;;     Two connections to the same peer completing at once would otherwise
;;;     both see the give and both withdraw it — and a second withdraw of one
;;;     gift is a replay, which the exporter is entitled to refuse.
;;;
;;;   ocapn-handoff-count : (String -> Nat)
;;;     The next handoff count for a session id, starting at 0. Upstream
;;;     treats a repeat within a session as a replay (utils/captp.py:100-109)
;;;     and so does our own exporter (`withdraw-with-identity` in
;;;     captp-core), so a second gift redeemed on one session needs a fresh
;;;     count. This was a literal 0 for every withdraw, which made our own
;;;     second handoff look like a replay of our first.
;;;
;;; All three hold `lock` for the whole read-modify-write: the server gives
;;; each connection its own thread, so all of this runs concurrently.

(provide ocapn-give-park
         ocapn-give-claim
         ocapn-handoff-count
         ocapn-give-reset!
         ocapn-give-ffi-registry)

(define lock (make-semaphore 1))

;; exporter location key -> signed-give wire bytes (Latin-1 string)
(define gives (make-hash))

;; session id (Latin-1 string) -> next count
(define counts (make-hash))

(define (ocapn-give-park loc-key give)
  (call-with-semaphore lock (lambda () (hash-set! gives loc-key give)))
  #t)

(define (ocapn-give-claim loc-key)
  (call-with-semaphore lock
    (lambda ()
      (define v (hash-ref gives loc-key ""))
      (hash-remove! gives loc-key)
      v)))

(define (ocapn-handoff-count session-id)
  (call-with-semaphore lock
    (lambda ()
      (define n (hash-ref counts session-id 0))
      (hash-set! counts session-id (add1 n))
      n)))

(define (ocapn-give-reset!)
  (call-with-semaphore lock
    (lambda () (hash-clear! gives) (hash-clear! counts))))

(define ocapn-give-ffi-registry
  (hasheq
   'ocapn-give-park     (cons ocapn-give-park     '(String -> String -> Bool))
   'ocapn-give-claim    (cons ocapn-give-claim    '(String -> String))
   'ocapn-handoff-count (cons ocapn-handoff-count '(String -> Nat))))
