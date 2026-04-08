#lang racket/base

;; bench-broadcast-vs-nprop.rkt — A/B: N-propagator model vs broadcast model
;;
;; BSP-LE Track 2 Phase 1Bi: measures INFRASTRUCTURE OVERHEAD.
;; Each "item" does trivial work (collect a symbol to the accumulator).
;; The difference between models is pure propagator/BSP overhead.

(require "../../tools/bench-micro.rkt"
         "../../propagator.rkt")

(define (set-union-merge old new)
  (cond [(null? old) new] [(null? new) old] [else (append old new)]))

;; Model A: N separate propagators
(define (run-model-a n)
  (define net0 (make-prop-network))
  (define-values (net1 input-cid) (net-new-cell net0 'ready (lambda (a b) b)))
  (define-values (net2 output-cid) (net-new-cell net1 '() set-union-merge))
  (define items (for/list ([i (in-range n)]) i))
  (define (make-fire item)
    (lambda (net) (net-cell-write net output-cid (list item))))
  (define-values (net3 _pids)
    (net-add-parallel-map-propagator net2 (list input-cid) output-cid items make-fire))
  (run-to-quiescence net3))

;; Model B: ONE broadcast propagator
(define (run-model-b n)
  (define net0 (make-prop-network))
  (define-values (net1 input-cid) (net-new-cell net0 'ready (lambda (a b) b)))
  (define-values (net2 output-cid) (net-new-cell net1 '() set-union-merge))
  (define items (for/list ([i (in-range n)]) i))
  (define fire-fn
    (lambda (net)
      (define results (for/list ([item (in-list items)]) item))
      (net-cell-write net output-cid results)))
  (define-values (net3 _pid)
    (net-add-propagator net2 (list input-cid) (list output-cid) fire-fn))
  (run-to-quiescence net3))

;; Model B under BSP
(define (run-model-b-bsp n)
  (define net0 (make-prop-network))
  (define-values (net1 input-cid) (net-new-cell net0 'ready (lambda (a b) b)))
  (define-values (net2 output-cid) (net-new-cell net1 '() set-union-merge))
  (define items (for/list ([i (in-range n)]) i))
  (define fire-fn
    (lambda (net)
      (define results (for/list ([item (in-list items)]) item))
      (net-cell-write net output-cid results)))
  (define-values (net3 _pid)
    (net-add-propagator net2 (list input-cid) (list output-cid) fire-fn))
  (run-to-quiescence-bsp net3))

;; === N=3 ===
(bench "A(N-prop) N=3 x1000"   (for ([_ (in-range 1000)]) (run-model-a 3)))
(bench "B(broadcast) N=3 x1000" (for ([_ (in-range 1000)]) (run-model-b 3)))
(bench "B-BSP(broadcast) N=3 x1000" (for ([_ (in-range 1000)]) (run-model-b-bsp 3)))

;; === N=5 ===
(bench "A(N-prop) N=5 x1000"   (for ([_ (in-range 1000)]) (run-model-a 5)))
(bench "B(broadcast) N=5 x1000" (for ([_ (in-range 1000)]) (run-model-b 5)))
(bench "B-BSP(broadcast) N=5 x1000" (for ([_ (in-range 1000)]) (run-model-b-bsp 5)))

;; === N=10 ===
(bench "A(N-prop) N=10 x500"   (for ([_ (in-range 500)]) (run-model-a 10)))
(bench "B(broadcast) N=10 x500" (for ([_ (in-range 500)]) (run-model-b 10)))
(bench "B-BSP(broadcast) N=10 x500" (for ([_ (in-range 500)]) (run-model-b-bsp 10)))

;; === N=20 ===
(bench "A(N-prop) N=20 x200"   (for ([_ (in-range 200)]) (run-model-a 20)))
(bench "B(broadcast) N=20 x200" (for ([_ (in-range 200)]) (run-model-b 20)))
(bench "B-BSP(broadcast) N=20 x200" (for ([_ (in-range 200)]) (run-model-b-bsp 20)))

;; === N=50 ===
(bench "A(N-prop) N=50 x100"   (for ([_ (in-range 100)]) (run-model-a 50)))
(bench "B(broadcast) N=50 x100" (for ([_ (in-range 100)]) (run-model-b 50)))
(bench "B-BSP(broadcast) N=50 x100" (for ([_ (in-range 100)]) (run-model-b-bsp 50)))

;; === N=100 ===
(bench "A(N-prop) N=100 x50"   (for ([_ (in-range 50)]) (run-model-a 100)))
(bench "B(broadcast) N=100 x50" (for ([_ (in-range 50)]) (run-model-b 100)))
(bench "B-BSP(broadcast) N=100 x50" (for ([_ (in-range 50)]) (run-model-b-bsp 100)))
