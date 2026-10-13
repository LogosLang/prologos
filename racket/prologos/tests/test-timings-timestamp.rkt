#lang racket/base

;;; test-timings-timestamp.rkt — run-record timestamps (tools/bench-lib.rkt).
;;;
;;; DEFERRED 164 open(5): `current-iso-timestamp` called (seconds->date now #t)
;;; under a "; UTC" comment, but #t is LOCAL-TIME?, so every `timestamp` ending
;;; in "Z" was the local clock labelled UTC (off by 6-7 h here). From schema 4
;;; the offset is explicit; schema <= 3 records are read as the local clock.

(require rackunit
         racket/date
         racket/string
         "../tools/bench-lib.rkt")

(define (local-offset secs) (date-time-zone-offset (seconds->date secs #t)))

(test-case "timestamp: written with an EXPLICIT local offset, and it parses back to the same instant"
  (for ([secs (list (current-seconds)
                    1789300800    ; 2026-09-13, summer time here
                    1798000000    ; 2026-12-23, standard time here
                    0)])
    (define ts (seconds->iso-timestamp secs))
    (check-false (string-suffix? ts "Z") ts)
    (check-regexp-match #px"^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[+-][0-9]{2}:[0-9]{2}$" ts)
    (define off (local-offset secs))
    (define want (format "~a~a:~a" (if (< off 0) "-" "+")
                         (pad-num (quotient (abs off) 3600) 2)
                         (pad-num (quotient (remainder (abs off) 3600) 60) 2)))
    (check-true (string-suffix? ts want) (format "~a should end in ~a" ts want))
    (check-equal? (parse-record-timestamp ts #:schema TIMINGS-SCHEMA-VERSION) secs ts)))

(test-case "timestamp: current-iso-timestamp is now, and the record schema is bumped to 4"
  (define before (current-seconds))
  (define ts (current-iso-timestamp))
  (define t (parse-record-timestamp ts #:schema TIMINGS-SCHEMA-VERSION))
  (check-true (<= before t (current-seconds)) ts)
  (check-equal? TIMINGS-SCHEMA-VERSION 4))

(test-case "timestamp: a legacy \"Z\" record (schema <= 3) is read as the LOCAL clock it really was"
  (define secs 1791890719)  ; 2026-10-13 ~04:25 local
  (define d (seconds->date secs #t))
  (define legacy
    (format "~a-~a-~aT~a:~a:~aZ" (date-year d) (pad-num (date-month d) 2) (pad-num (date-day d) 2)
            (pad-num (date-hour d) 2) (pad-num (date-minute d) 2) (pad-num (date-second d) 2)))
  (check-equal? (parse-record-timestamp legacy #:schema 3) secs)
  (check-equal? (parse-record-timestamp legacy) secs "no schema = legacy")
  ;; a schema-4 "Z" would be genuine UTC
  (check-equal? (parse-record-timestamp "1970-01-01T00:00:00Z" #:schema 4) 0)
  ;; the first 19 characters are the local clock in BOTH formats, so a string
  ;; sort of old and new records stays chronological across the cut-over
  (check-equal? (substring (seconds->iso-timestamp secs) 0 19) (substring legacy 0 19))
  (check-false (parse-record-timestamp "not a time")))
