#lang racket/base
;; FIXTURE: corrected twin — every cell op goes through the fire fn's own
;; `net` parameter. Must produce zero findings.
(define n (make-network))
(define (install!)
  (net-add-propagator n (list some-cid) (list result-cid)
    (lambda (net)
      (define val (net-cell-read net some-cid))
      (net-cell-write net result-cid val))))
