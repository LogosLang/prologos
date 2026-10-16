#lang racket/base
;; C6 probe 4 — what machine code Racket CS emits on aarch64 for allocation, publication
;; stores, fences and CAS.  Run with PLT_LINKLET_SHOW_ASSEMBLY=1; grep for dmb / ldaxr / stlxr.
(require racket/unsafe/ops racket/vector)
(provide (all-defined-out))
(struct node (a b) #:authentic)
(define (alloc-pair x) (cons x x))
(define (alloc-node x) (node x x))
(define (copy-then-set v x) (let ([n (vector-copy v)]) (vector-set! n 0 x) n))
(define (publish-plain bx v) (set-box! bx v))
(define (publish-release bx v) (memory-order-release) (set-box! bx v))
(define (read-plain bx) (unbox bx))
(define (read-acquire bx) (let ([v (unbox bx)]) (memory-order-acquire) v))
(define (cas bx old new) (box-cas! bx old new))
