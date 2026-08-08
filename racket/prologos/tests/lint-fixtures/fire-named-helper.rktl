#lang racket/base
;; FIXTURE: the Track 2B "discrimination propagator" shape written as a
;; NAMED helper (no "fire" in the name) passed by reference — rule (c).
(define n (make-network))
(define (discriminate-step net2)
  (net-cell-write n out-cid 42))
(define (install!)
  (net-add-propagator n (list in-cid) (list out-cid) discriminate-step))
