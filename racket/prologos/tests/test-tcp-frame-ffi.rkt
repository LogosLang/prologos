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
