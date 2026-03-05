#lang racket/base

;;;
;;; PROLOGOS SOURCE LOCATION
;;; Source location tracking for error reporting.
;;;

(provide
 (struct-out srcloc)
 srcloc-unknown
 format-srcloc)

;; Source location: file, line, column, span
(struct srcloc (file line col span) #:transparent)

;; Sentinel for unknown locations
(define srcloc-unknown (srcloc "<unknown>" 0 0 0))

;; Format a source location for display
(define (format-srcloc loc)
  (cond
    [(not loc) "<unknown>"]
    [(equal? loc srcloc-unknown) "<unknown>"]
    [else (format "~a:~a:~a"
                  (srcloc-file loc)
                  (srcloc-line loc)
                  (srcloc-col loc))]))
