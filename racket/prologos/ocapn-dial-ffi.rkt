#lang racket/base

;;; ocapn-dial-ffi.rkt — outbound-connection requests.
;;;
;;; A Prologos behaviour is pure and cannot open a socket, so the sturdyref
;;; enlivener records WHERE it wants to connect and the server dials on its
;;; behalf between steps. This is the same shape as ocapn-gift-ffi.rkt: a
;;; Racket-side queue the Prologos side appends to and the driver drains,
;;; rather than a new Effect variant plus a sixth Vat field threaded through
;;; nineteen constructor sites.
;;;
;;; The queue is process-global on purpose. A dial request is not scoped to
;;; the connection that produced it — the whole point is to reach a peer we
;;; have no connection to yet.
;;;
;;;   ocapn-dial-request  : (String -> Bool)
;;;     Append one request (an encoded sturdyref). Returns #t so the Prologos
;;;     caller has a value to force — reduction is lazy and a Unit result
;;;     would let the call be dropped.
;;;
;;;   ocapn-dial-drain    : (String -> List String)
;;;     Return every pending request and clear the queue. The argument is a
;;;     fallback for the empty case: returning #f from an FFI crashes `nf`
;;;     rather than erroring, which is a defect that has already cost one
;;;     debugging session (see ocapn-gift-ffi.rkt's fetch).

(provide ocapn-dial-request
         ocapn-dial-drain
         ocapn-dial-reset!
         ocapn-dial-ffi-registry)

(define pending '())

(define (ocapn-dial-request sturdyref)
  "Queue an outbound-connection request. Returns #t."
  (set! pending (append pending (list sturdyref)))
  #t)

(define (ocapn-dial-drain _fallback)
  "Return all pending requests, clearing the queue."
  (define out pending)
  (set! pending '())
  out)

(define (ocapn-dial-reset!)
  "Drop every pending request. Test-only."
  (set! pending '()))

(define ocapn-dial-ffi-registry
  (hasheq
   'ocapn-dial-request (cons ocapn-dial-request '(String -> Bool))
   'ocapn-dial-drain   (cons ocapn-dial-drain   '((List String) -> (List String)))))
