#lang racket/base
;; C6 probe 2b — the exact shape D.2 §6.5 proposes: fire-propagator enters the fire under a
;; continuation mark with a private key, fire-fn called in tail position of the wcm,
;; fire-propagator itself called non-tail by the scheduler loop.
(require racket/fixnum)
(define M 2000000)
(define key (make-continuation-mark-key 'srcloc))
(define p (make-parameter #f))
(struct prop (srcloc fire-fn))
(define props (for/vector ([i 8]) (prop (vector 'file i 0) (lambda (net) (fx+ net 1)))))
(define (fire-mark pr net) (with-continuation-mark key (prop-srcloc pr) ((prop-fire-fn pr) net)))
(define (fire-param pr net) (parameterize ([p (prop-srcloc pr)]) ((prop-fire-fn pr) net)))
(define (fire-none pr net) ((prop-fire-fn pr) net))
(define (fire-mark-reading pr net)
  (with-continuation-mark key (prop-srcloc pr)
    ((prop-fire-fn pr) (if (continuation-mark-set-first #f key) net 0))))
(define (bench label fire)
  (collect-garbage)
  (define b0 (current-memory-use 'cumulative))
  (define t0 (current-inexact-milliseconds))
  (define r (let loop ([i 0] [net 0])
              (if (fx= i M) net
                  (loop (fx+ i 1) (fxand (fire (vector-ref props (fxand i 7)) net) #xFFFF)))))
  (printf "  ~a: ~a B/fire  ~a ns/fire (r=~a)\n" label
          (/ (- (current-memory-use 'cumulative) b0) (exact->inexact M))
          (/ (* 1e6 (- (current-inexact-milliseconds) t0)) M) r))
(printf "fire-entry shapes, M=~a\n" M)
(bench "no context" fire-none)
(bench "parameterize current-source-loc (today's fire-propagator)" fire-param)
(bench "wcm private key, fire-fn in tail position (D.2 proposal)" fire-mark)
(bench "wcm private key, fire reads the mark" fire-mark-reading)
