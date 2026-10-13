#lang racket/base
;; cold-warm-parity.rkt — does disabling the .pnet cache change ANY observable result?
;; Runs process-file on FILE and prints each result's printed form, one per line, so two
;; runs (P0_NO_PNET unset / =1) can be diffed. Also prints wall ms on stderr.
(require racket/port racket/format
         (only-in "../../driver.rkt" process-file current-use-pnet-cache? current-pnet-write-enabled?))
(define file (vector-ref (current-command-line-arguments) 0))
(define cold? (equal? (getenv "P0_NO_PNET") "1"))
(define t0 (current-inexact-monotonic-milliseconds))
(define out (open-output-string))
(define results
  (parameterize ([current-output-port out]
                 [current-use-pnet-cache? (not cold?)]
                 [current-pnet-write-enabled? (not cold?)])
    (process-file file)))
(eprintf "wall_ms ~a cold ~a\n" (round (- (current-inexact-monotonic-milliseconds) t0)) cold?)
(for ([r (in-list (or results '()))]) (printf "~s\n" r))
(printf "--- program stdout ---\n~a" (get-output-string out))
