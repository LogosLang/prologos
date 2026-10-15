#lang racket/base
;; demos-threshold.rkt — run bench-parallel-demos with current-tree-reduce-threshold overridden.
;;   racket benchmarks/par4/demos-threshold.rkt 256|off
;; PAR 4 P0 §3 / §10 (DEFERRED 150). Relative requires: runs against the tree it lives in.
(require (only-in "../../propagator.rkt" current-tree-reduce-threshold)
         racket/runtime-path)
(define-runtime-path demos "../micro/bench-parallel-demos.rkt")
(define v (let ([a (vector-ref (current-command-line-arguments) 0)])
            (if (equal? a "off") #f (string->number a))))
(parameterize ([current-tree-reduce-threshold v])
  (dynamic-require demos #f))
