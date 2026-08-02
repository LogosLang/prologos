#lang racket/base

;;;
;;; ocapn-handoff-ffi.rkt — the EXPORTER's replay set for third-party handoffs.
;;;
;;; A `desc:handoff-receive` is SINGLE-USE. Its identity is the triple
;;; (receiving-session, receiving-side, handoff-count), and honouring the same
;;; triple twice hands the same gift over twice.
;;;
;;; That set used to live in `BridgeState`, which is per-connection — so the
;;; whole of it was forgotten when the connection closed. Withdraw on one
;;; connection, reconnect, replay the identical signed receive: the second
;;; withdrawal saw an empty set and succeeded. A DOUBLE-SPEND, and one that
;;; costs the attacker only a reconnect.
;;;
;;; The comment that justified the per-connection set argued the identity
;;; "carries the receiving session id, so keeping the used-set per-connection
;;; loses nothing". Two things were wrong with it. Nothing checked the session
;;; field (fixed separately, in `captp-core`), and a session id is derived
;;; ONLY from the two side-ids — so a peer that reconnects with the SAME key
;;; gets the SAME session id. Upstream generates a fresh keypair per session
;;; (utils/captp.py:49-50), which is what made this look safe; an attacker is
;;; under no such obligation.
;;;
;;;   ocapn-handoff-claim : (String -> Bool)
;;;     Test-and-set, in ONE critical section. #t means the identity had not
;;;     been used and is now claimed; #f means it is a replay.
;;;
;;;     One call, not a check followed by a mark, because the two-call form is
;;;     a race with the same shape as the bug above: the server gives each
;;;     connection its own thread, so two connections replaying the same
;;;     receive concurrently would both read "unused" and both proceed.
;;;
;;; SAFETY OF CLAIMING EARLY. The claim happens before the gift lookup, so a
;;; withdrawal that is later refused (its give unauthenticated) has still
;;; burned its identity. That is deliberate and it is safe, but only because
;;; the connection binding is checked FIRST: to reach here at all, a receive
;;; must carry a valid signature AND name this connection's session and this
;;; peer's side. So the only identities a peer can burn are its own. Reorder
;;; those two checks and this becomes a denial-of-service primitive — an
;;; attacker could burn identities belonging to an honest receiver.
;;;
;;; GROWTH. Nothing expires an entry, so this table grows with (sessions ×
;;; handoffs) for the life of the process. It joins the four other
;;; peer-driven tables under the same open item; a cap is not added here
;;; because eviction would make a replay succeed again, which is the exact
;;; property this table exists to deny.

(provide ocapn-handoff-claim
         ocapn-handoff-used?
         ocapn-handoff-reset!
         ocapn-handoff-ffi-registry)

(define lock (make-semaphore 1))

;; handoff identity (Latin-1 string) -> #t
(define used (make-hash))

(define (ocapn-handoff-claim ident)
  (call-with-semaphore lock
    (lambda ()
      (cond
        [(hash-ref used ident #f) #f]
        [else (hash-set! used ident #t) #t]))))

;; Observation only — for tests. Never gate on this: the gap between asking
;; and claiming is the race `ocapn-handoff-claim` exists to close.
(define (ocapn-handoff-used? ident)
  (call-with-semaphore lock
    (lambda () (and (hash-ref used ident #f) #t))))

(define (ocapn-handoff-reset!)
  (call-with-semaphore lock
    (lambda () (hash-clear! used))))

(define ocapn-handoff-ffi-registry
  (hasheq
   'ocapn-handoff-claim (cons ocapn-handoff-claim '(String -> Bool))
   'ocapn-handoff-used? (cons ocapn-handoff-used? '(String -> Bool))))
