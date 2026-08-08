#lang racket/base
;; memoization table — FIXTURE: eq-keyed twin, must produce zero findings.
(define memo-table (make-hasheq))
