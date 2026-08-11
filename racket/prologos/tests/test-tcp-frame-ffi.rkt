#lang racket/base

;;; test-tcp-frame-ffi.rkt — byte-oriented frame IO on the TCP handle table.
;;;
;;; `tcp-send-line` / `tcp-recv-line-ret` are LF-delimited, which is fine for
;;; the tcp-testing-only netlayer and wrong for OCapN: a Syrup frame is
;;; arbitrary bytes and 0x0a occurs inside them constantly. These are the frame
;;; primitives a Prologos-side event loop needs (SH-1).
;;;
;;; Two properties matter and neither is obvious from the happy path:
;;;
;;;   * a frame containing 0x0a survives — the case that makes line framing
;;;     silently truncate rather than fail;
;;;   * an EMPTY frame and a CLOSED socket are distinguishable. Both carry a
;;;     zero-length payload, and a loop that cannot tell them apart either
;;;     spins forever on a dead peer or drops a legitimate empty frame. The
;;;     gaps document keeps re-learning this shape: "a malformed frame and an
;;;     absent frame are indistinguishable to everything except the bytes."
;;;
;;; The test drives the FFI directly rather than through Prologos. Step 3's
;;; echo-server test is what exercises the same primitives from the language.

(require rackunit
         racket/list
         "../tcp-ffi.rkt")

(current-framing-strategy 'netstring)

;; A free ephemeral port. Racket hands one out for port 0, but the FFI takes a
;; number, so bind-probe-close and reuse the number. A race is possible in
;; principle; in practice the window is microseconds and the alternative is
;; hard-coding a port that collides with a parallel test run.
(define (free-port)
  (define l ((dynamic-require 'racket/tcp 'tcp-listen) 0 4 #t "127.0.0.1"))
  (define-values (_h p _rh _rp) ((dynamic-require 'racket/tcp 'tcp-addresses) l #t))
  ((dynamic-require 'racket/tcp 'tcp-close) l)
  p)

;; Run `body` with a connected (server-side, client-side) handle pair.
(define (with-pair body)
  (define port (free-port))
  (define srv (tcp-listen port))
  (define cli (tcp-connect "127.0.0.1" port))
  (define acc (tcp-accept srv))
  (dynamic-wind
   void
   (lambda () (body acc cli))
   (lambda ()
     (for ([h (list acc cli srv)])
       (with-handlers ([exn:fail? void]) (tcp-close h))))))

;; Send from `from`, read on `to`, return the payload.
(define (round-trip from to payload)
  (tcp-send-frame from payload)
  (tcp-recv-frame-ret to)
  (tcp-recv-frame-cached to))

(test-case "a frame round-trips"
  (with-pair
    (lambda (a b)
      (check-equal? (round-trip a b "hello") "hello")
      (check-false (tcp-recv-frame-eof? b)))))

(test-case "a frame containing 0x0a survives"
  ;; THE case line framing gets wrong. With `tcp-send-line` this payload
  ;; arrives truncated at the newline and the remainder becomes a phantom
  ;; second frame — silently, since both halves are well-formed strings.
  (with-pair
    (lambda (a b)
      (define payload "before\nafter\nmore")
      (check-equal? (round-trip a b payload) payload))))

(test-case "every byte value survives"
  ;; Latin-1 in, Latin-1 out: 1 char == 1 byte. A UTF-8 conversion anywhere on
  ;; the path widens everything above 0x7F and this fails.
  (with-pair
    (lambda (a b)
      (define payload (list->string (for/list ([i (in-range 256)]) (integer->char i))))
      (define got (round-trip a b payload))
      (check-equal? (string-length got) 256)
      (check-equal? got payload))))

(test-case "an EMPTY frame is not EOF"
  (with-pair
    (lambda (a b)
      (check-equal? (round-trip a b "") "")
      (check-false (tcp-recv-frame-eof? b)
                   "a zero-length frame was reported as end-of-stream"))))

(test-case "a CLOSED socket is EOF"
  (with-pair
    (lambda (a b)
      (tcp-close a)
      (tcp-recv-frame-ret b)
      (check-true (tcp-recv-frame-eof? b))
      (check-equal? (tcp-recv-frame-cached b) ""))))

(test-case "EOF and empty frame are distinguishable on one handle"
  ;; The pair of the two cases above, on the SAME handle in sequence — which is
  ;; what a loop actually sees. Asserting them separately would pass even if
  ;; the flag were never updated after the first read.
  (with-pair
    (lambda (a b)
      (check-equal? (round-trip a b "") "")
      (check-false (tcp-recv-frame-eof? b))
      (tcp-close a)
      (tcp-recv-frame-ret b)
      (check-true (tcp-recv-frame-eof? b)))))

(test-case "frames keep their order"
  (with-pair
    (lambda (a b)
      (for ([p (list "one" "two" "three")])
        (tcp-send-frame a p))
      (check-equal? (for/list ([_ 3])
                      (tcp-recv-frame-ret b)
                      (tcp-recv-frame-cached b))
                    (list "one" "two" "three")))))

(test-case "an unread handle reports EOF rather than a frame"
  ;; The default has to be the SAFE answer. Reporting "not EOF" for a handle
  ;; nobody has read keeps a loop running against a socket with nothing on it.
  (with-pair
    (lambda (a b)
      (check-true (tcp-recv-frame-eof? b))
      (check-equal? (tcp-recv-frame-cached b) ""))))

;; ------------------------------------------------------------------
;; Effects are functions of their tick
;; ------------------------------------------------------------------
;;
;; The reducer is CALL-BY-NAME: it does not share an evaluated redex, so a
;; `match` binding two fields of an effect's result re-evaluates that effect
;; once per field used. Measured — instrumenting the FFI showed `accept`
;; entering twice with the same tick, the second call blocking forever on a
;; listener whose only client had already been taken.
;;
;; So the World token orders effects but does NOT make them at-most-once, and
;; the memo on `(op, tick, args)` is what does. These pin that, because it is
;; an invariant nothing else would catch: without it the failures are a hang or
;; a duplicated frame, arbitrarily far from the cause.

(test-case "an effect is a function of its tick"
  (with-pair
    (lambda (a b)
      ;; Twice at the SAME tick — a re-walk of one subterm, not two sends.
      (tcp-frame-send 100 a "once")
      (tcp-frame-send 100 a "once")
      (tcp-recv-frame-ret b)
      (check-equal? (tcp-recv-frame-cached b) "once")
      ;; Nothing more on the wire. Send a sentinel and check it arrives NEXT:
      ;; a second copy of "once" would be read here instead.
      (tcp-frame-send 101 a "sentinel")
      (tcp-recv-frame-ret b)
      (check-equal? (tcp-recv-frame-cached b) "sentinel"
                    "the same effect ran twice at one tick"))))

(test-case "a different tick is a different effect"
  ;; The other half. If the memo key were too coarse — the connection alone,
  ;; say — the second send would be swallowed and the loop would stall.
  (with-pair
    (lambda (a b)
      (tcp-frame-send 200 a "first")
      (tcp-frame-send 201 a "second")
      (check-equal? (for/list ([_ 2])
                      (tcp-recv-frame-ret b)
                      (tcp-recv-frame-cached b))
                    (list "first" "second")))))

(test-case "a re-read at one tick sees that read, not a later one"
  ;; Payload and EOF are keyed by the tick the READ produced, not by handle.
  ;; Keyed by handle they would report whatever the socket saw MOST RECENTLY,
  ;; so re-walking an older subterm would silently observe a newer frame —
  ;; a wrong answer rather than a hang.
  (with-pair
    (lambda (a b)
      (tcp-frame-send 300 a "alpha")
      (tcp-frame-send 301 a "beta")
      (define t1 (tcp-frame-recv 310 b))
      (check-equal? (tcp-frame-payload-at t1 b) "alpha")
      (define t2 (tcp-frame-recv t1 b))
      (check-equal? (tcp-frame-payload-at t2 b) "beta")
      ;; The older tick still answers with the older frame.
      (check-equal? (tcp-frame-payload-at t1 b) "alpha"
                    "an earlier tick observed a later frame"))))

(test-case "a memo key must identify a point in TIME, not just a thing"
  ;; `tcp-tick-after` answers "what is the clock now", memoized so a re-walk
  ;; cannot see a clock that has since moved. Keyed on its `dep` argument alone
  ;; it looks right — a handle is unique per accept — and it DEADLOCKS the
  ;; server loop: `dep` is the handle `sync` returned, the same connection is
  ;; ready on every iteration, so iteration two hits the memo and receives
  ;; iteration one's tick. The clock stops; the next `sync` runs at a tick it
  ;; has already answered; the loop replays one cached event forever.
  ;;
  ;; Observed before the fix as `FFI sync tick=6 handles=(1)` repeating after
  ;; the peer had disconnected. Pinned here because the symptom is a hang with
  ;; no error, arbitrarily far from the key that caused it.
  (with-pair
    (lambda (a b)
      ;; Same (tick, dep) twice: stable, which is the whole point of the memo.
      (define first-answer (tcp-tick-after 900 a))
      (check-equal? (tcp-tick-after 900 a) first-answer)
      ;; Advance the clock, then ask again with the SAME dep at a NEW tick.
      ;; This must move. If it does not, the loop above cannot progress.
      (tcp-frame-send 901 a "advance")
      (check-not-equal? (tcp-tick-after 902 a) first-answer
                        "the clock froze: tick-after ignored its tick argument"))))

(test-case "closing a handle drops its frame state"
  (define port (free-port))
  (define srv (tcp-listen port))
  (define cli (tcp-connect "127.0.0.1" port))
  (define acc (tcp-accept srv))
  (tcp-send-frame acc "payload")
  (tcp-recv-frame-ret cli)
  (check-equal? (tcp-recv-frame-cached cli) "payload")
  (tcp-close cli)
  ;; Handles are freshly numbered, so this asserts the CACHE was cleared, not
  ;; that the id was reused: a stale entry would outlive the socket and be
  ;; served to whoever next got that id.
  (check-equal? (tcp-recv-frame-cached cli) "")
  (check-true (tcp-recv-frame-eof? cli))
  (for ([h (list acc srv)]) (with-handlers ([exn:fail? void]) (tcp-close h))))
