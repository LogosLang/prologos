#lang racket/base

;;;
;;; ocapn-peer-ffi.rkt — the connection registry, and the outbound-send
;;; queue that needs it.
;;;
;;; TWO tables, one purpose: letting the PROLOGOS side act on a connection
;;; other than the one being serviced.
;;;
;;; That is the capability the third-party handoff needs and did not have. A
;;; gifter receives an enliven on one connection and must fetch from the
;;; exporter on another; a receiver is handed a give on one connection and
;;; must withdraw on the connection it then dials. Nothing in the vat could
;;; name a second connection, so both roles lived in Racket byte-scanners
;;; running alongside captp-core on the same frames — the double-processing
;;; recorded as §1.7 M8 in the gaps document, and the reason §0.2 called the
;;; roles "not self-hosting".
;;;
;;; The shape is deliberately the gift table's (`ocapn-gift-ffi.rkt`): an
;;; exporter-GLOBAL table behind an FFI, written by whichever connection
;;; thread is stepping and read by any other. That table already carries
;;; state across connections for exactly this reason — a handoff deposits on
;;; one connection and withdraws on another — so this is an application of a
;;; design that already ships, not a new mechanism.
;;;
;;;   ocapn-peer-register : (String -> Nat -> String -> Bool)
;;;     Record `location key -> (connection id, peer side-id)`. Returns #t so
;;;     the Prologos caller has a value to force: reduction is lazy and a Unit
;;;     result would let the call be dropped with no error anywhere.
;;;
;;;     The SIDE-ID rides along because knowing a connection exists is not
;;;     enough to use it. Anything addressed to that peer through a session
;;;     identity — a `desc:handoff-receive`, for one — needs the session id,
;;;     and that is derived from the two side-ids. Without it a receiver could
;;;     redeem a give only on a connection it had just watched open, never on
;;;     one that was already there.
;;;
;;;   ocapn-peer-lookup   : (String -> Nat)
;;;     The connection id for a location, or 0 for "no connection". Zero is
;;;     safe as the miss value because connection ids start at 1.
;;;
;;;   ocapn-peer-side-id  : (String -> String)
;;;     The peer's side-id for a location, or "" when we have no connection.
;;;
;;;   ocapn-peer-loc-of   : (Nat -> String)
;;;     The location key of a connection — the reverse of `lookup`. A step
;;;     knows which connection it is servicing, but the outbound side names
;;;     peers by LOCATION: a gifter answering an enliven has to get back to
;;;     the connection the enliven arrived on, and by then it is servicing a
;;;     different one.
;;;
;;;   ocapn-peer-forget   : called by the SERVER when a connection closes.
;;;
;;;   ocapn-send-on       : (Nat -> String -> Bool)
;;;     Queue wire bytes for connection `cid`, as a Latin-1 string — the same
;;;     convention every other payload crosses this boundary under. The
;;;     Prologos side cannot hold a port, so it names the connection and the
;;;     server writes.
;;;
;;;   ocapn-send-drain    : (String -> List String)
;;;     Every pending send, oldest first, as "<cid>:<bytes>" strings, clearing
;;;     the queue. One flat string per entry rather than a pair, because the
;;;     FFI marshals `List String` and not a list of tuples. The argument is
;;;     an empty-case fallback, for the same reason `ocapn-dial-drain` takes
;;;     one: returning #f crashes `nf` rather than erroring.
;;;
;;;     The consumer must split at the FIRST colon BY INDEX. A payload is
;;;     arbitrary bytes and may contain colons, newlines, anything — a
;;;     `#px"^([0-9]+):(.*)$"` fails outright on a frame containing 0x0a,
;;;     because `.` does not match a newline.
;;;
;;; Every entry point holds `lock` for its whole read-modify-write. The
;;; server gives each connection its own thread, so all of these run
;;; concurrently, and a bare `set!` drops a send queued between a drainer's
;;; read and its clear.

(provide ocapn-peer-register
         ocapn-peer-lookup
         ocapn-peer-side-id
         ocapn-peer-loc-of
         ocapn-peer-forget
         ocapn-peer-reset!
         ocapn-send-on
         ocapn-send-drain
         ocapn-peer-ffi-registry)

(define lock (make-semaphore 1))

;; location key (as a Latin-1 string) -> (cons connection-id side-id)
(define peers (make-hash))

;; pending sends, oldest first, as (cons cid payload)
(define sends '())

(define (ocapn-peer-register loc cid side-id)
  "Record loc -> (cid, side-id). Returns #t."
  (call-with-semaphore lock (lambda () (hash-set! peers loc (cons cid side-id))))
  #t)

(define (ocapn-peer-lookup loc)
  "The connection id for loc, or 0 when we have none."
  (call-with-semaphore lock (lambda () (car (hash-ref peers loc '(0 . ""))))))

(define (ocapn-peer-side-id loc)
  "The peer's side-id for loc, or \"\" when we have no connection."
  (call-with-semaphore lock (lambda () (cdr (hash-ref peers loc '(0 . ""))))))

(define (ocapn-peer-loc-of cid)
  "The location key registered for cid, or \"\" when there is none."
  (call-with-semaphore lock
    (lambda ()
      (or (for/first ([(loc v) (in-hash peers)] #:when (equal? (car v) cid)) loc)
          ""))))

(define (ocapn-peer-forget loc)
  "Drop a location's entry once its connection closes."
  (call-with-semaphore lock (lambda () (hash-remove! peers loc)))
  #t)

(define (ocapn-peer-reset!)
  "Drop every entry and every pending send. Test-only."
  (call-with-semaphore lock
    (lambda () (hash-clear! peers) (set! sends '()))))

(define (ocapn-send-on cid payload)
  "Queue wire bytes (Latin-1) for connection cid. Returns #t."
  (call-with-semaphore lock
    (lambda () (set! sends (append sends (list (cons cid payload))))))
  #t)

(define (ocapn-send-drain _fallback)
  "Every pending send as \"<cid>:<bytes>\", oldest first, clearing the queue."
  (call-with-semaphore lock
    (lambda ()
      (define out (map (lambda (p) (format "~a:~a" (car p) (cdr p))) sends))
      (set! sends '())
      out)))

(define ocapn-peer-ffi-registry
  (hasheq
   'ocapn-peer-register (cons ocapn-peer-register '(String -> Nat -> String -> Bool))
   'ocapn-peer-lookup   (cons ocapn-peer-lookup   '(String -> Nat))
   'ocapn-peer-side-id  (cons ocapn-peer-side-id  '(String -> String))
   'ocapn-peer-loc-of   (cons ocapn-peer-loc-of   '(Nat -> String))
   'ocapn-peer-forget   (cons ocapn-peer-forget   '(String -> Bool))
   'ocapn-send-on       (cons ocapn-send-on       '(Nat -> String -> Bool))
   'ocapn-send-drain    (cons ocapn-send-drain    '((List String) -> (List String)))))
