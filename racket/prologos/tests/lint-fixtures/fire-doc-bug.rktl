#lang racket/base
;; FIXTURE (read by lint, never compiled): the exact WRONG example from
;; propagator-design.md § Fire Function Network Parameter — the fire fn
;; writes through the captured installation-time network `n`.
(define n (make-network))
(define (install!)
  (net-add-propagator n (list some-cid) (list result-cid)
    (lambda (net)
      (define val (net-cell-read net some-cid))
      (net-cell-write n result-cid val))))
