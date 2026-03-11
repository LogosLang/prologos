#lang racket/base

;;; Run a .prologos file and print numbered results.
;;; Usage: racket tools/run-file.rkt FILE.prologos

(require racket/cmdline
         (only-in "../driver.rkt" process-file)
         (only-in "../errors.rkt" prologos-error? prologos-error-message))

(define files
  (command-line
   #:program "run-file"
   #:args files files))

(for ([f (in-list files)])
  (define results (process-file f))
  (define error-count 0)
  (for ([r (in-list results)]
        [i (in-naturals)])
    (define s
      (cond
        [(prologos-error? r)
         (set! error-count (+ error-count 1))
         (format "ERROR: ~a" (prologos-error-message r))]
        [(string? r) r]
        [else (format "~a" r)]))
    (printf "~a: ~a\n" i s))
  (printf "\n--- ~a errors ---\n" error-count))
