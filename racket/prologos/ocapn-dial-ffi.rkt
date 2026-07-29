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
;;; have no connection to yet. It follows that the queue has MANY writers and
;;; MANY drainers: `ocapn-dial-request` runs on whichever connection thread
;;; was stepping, `ocapn-dial-drain` runs from every connection's frame loop,
;;; and the server also enqueues directly off its handoff-give scanner. A bare
;;; `set!` read-modify-write drops a request queued between a drainer's read
;;; and its clear, so both entry points hold the semaphore for the whole
;;; read-modify-write.
;;;
;;;   ocapn-dial-request  : (String -> Bool)
;;;     Append one request (an encoded sturdyref). Returns #t so the Prologos
;;;     caller has a value to force — reduction is lazy and a Unit result
;;;     would let the call be dropped.
;;;
;;;   ocapn-dial-drain    : (String -> List String)
;;;     Return every pending request, oldest first, and clear the queue. The
;;;     argument is a fallback for the empty case: returning #f from an FFI
;;;     crashes `nf` rather than erroring, which is a defect that has already
;;;     cost one debugging session (see ocapn-gift-ffi.rkt's fetch). Only the
;;;     Racket server drains today — the Prologos driver has no use for the
;;;     list, so it carries no `foreign` declaration for this one.
;;;
;;; The queue is held REVERSED (newest first) so a push is a `cons` rather
;;; than the O(n) `append` it used to be; the drain reverses once.

(provide ocapn-dial-request
         ocapn-dial-drain
         ocapn-dial-reset!
         ocapn-dial-ffi-registry)

;; Newest-first; `ocapn-dial-drain` restores arrival order.
(define pending '())
(define dial-sema (make-semaphore 1))

(define (ocapn-dial-request sturdyref)
  "Queue an outbound-connection request. Returns #t."
  (call-with-semaphore dial-sema
    (lambda () (set! pending (cons sturdyref pending))))
  #t)

(define (ocapn-dial-drain _fallback)
  "Return all pending requests in arrival order, clearing the queue."
  (call-with-semaphore dial-sema
    (lambda ()
      (define out (reverse pending))
      (set! pending '())
      out)))

(define (ocapn-dial-reset!)
  "Drop every pending request. Test-only."
  (call-with-semaphore dial-sema
    (lambda () (set! pending '()))))

;; No consumer reads this today; it is the one place the two signatures are
;; written down now that the driver declares only `ocapn-dial-request`.
(define ocapn-dial-ffi-registry
  (hasheq
   'ocapn-dial-request (cons ocapn-dial-request '(String -> Bool))
   'ocapn-dial-drain   (cons ocapn-dial-drain   '((List String) -> (List String)))))
