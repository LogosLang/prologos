#lang racket/base
;; pnet-read-cost.rkt — PAR 4 P0 side-measurement: how much of process-file startup is the
;; .pnet DOUBLE READ (pnet-stale? reads the whole file to compare a 2-element header;
;; deserialize-module-state reads it again). Times one full `read` of every cached .pnet.
(require racket/file racket/list)
(define dir (vector-ref (current-command-line-arguments) 0))
(define files (for/list ([f (in-directory dir)] #:when (regexp-match? #rx"[.]pnet$" (path->string f))) f))
(define total-bytes (for/sum ([f files]) (file-size f)))
(collect-garbage)
(define t0 (current-inexact-monotonic-milliseconds))
(for ([f files]) (call-with-input-file f read))
(define t1 (current-inexact-monotonic-milliseconds))
(define t2 (current-inexact-monotonic-milliseconds))
(for ([f files]) (call-with-input-file f (λ (in) (read in) (read in))))  ; what a header read would cost if header were separate datums: upper bound
(printf "pnet files: ~a  total: ~a MB  full read of all: ~a ms  (~a ms/MB)\n"
        (length files) (/ (round (/ total-bytes 1e4)) 100.0) (round (- t1 t0))
        (/ (round (* 10 (/ (- t1 t0) (/ total-bytes 1e6)))) 10.0))
(define big (take (sort files > #:key file-size) (min 5 (length files))))
(for ([f big]) (printf "  ~a  ~a KB\n" (path->string f) (quotient (file-size f) 1024)))
