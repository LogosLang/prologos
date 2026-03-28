#lang racket/base

;; bench-bsp-overhead.rkt — PAR Track 1 Phase 0a: BSP vs DFS scheduling overhead
;;
;; Measures raw quiescence loop cost under both schedulers.
;; Data feeds PAR Track 1 D.2 design critique.
;;
;; M1: Empty quiescence (nothing to fire)
;; M2: Single-propagator fire (minimal work unit)
;; M3: Chain propagation depth-10 (BSP weak case: sequential dependency)
;; M4: Fan-out width-10 (BSP strong case: independent propagators)
;; M5: SRE decomposition baseline (inline cost, DFS only)

(require "../../tools/bench-micro.rkt"
         "../../propagator.rkt"
         "../../performance-counters.rkt")

;; ============================================================
;; Helpers
;; ============================================================

;; Simple merge: take the newer value (last-write-wins lattice)
(define (last-write-merge old new) new)

;; Build a network with N cells (initial value 0) and return (net . cell-ids)
(define (make-test-network-cells n)
  (let loop ([net (make-prop-network)] [ids '()] [i 0])
    (if (>= i n)
        (values net (reverse ids))
        (let-values ([(net* cid) (net-new-cell net 0 last-write-merge)])
          (loop net* (cons cid ids) (+ i 1))))))

;; Build a chain: cell[0] → prop → cell[1] → prop → ... → cell[N]
;; Each propagator reads cell[i] and writes cell[i]+1 to cell[i+1]
(define (make-chain-network depth)
  (define-values (net0 cids) (make-test-network-cells (+ depth 1)))
  (let loop ([net net0] [i 0])
    (if (>= i depth)
        (values net cids)
        (let* ([in-cid (list-ref cids i)]
               [out-cid (list-ref cids (+ i 1))]
               [fire-fn (lambda (n)
                          (define v (net-cell-read n in-cid))
                          (net-cell-write n out-cid (+ v 1)))])
          (let-values ([(net* _pid) (net-add-propagator net (list in-cid) (list out-cid) fire-fn)])
            (loop net* (+ i 1)))))))

;; Build a fan-out: cell[0] → 10 props → cell[1]..cell[10]
;; Each propagator reads cell[0] and writes to its own output cell
(define (make-fanout-network width)
  (define-values (net0 cids) (make-test-network-cells (+ width 1)))
  (define src-cid (car cids))
  (let loop ([net net0] [i 0])
    (if (>= i width)
        (values net cids)
        (let* ([out-cid (list-ref cids (+ i 1))]
               [fire-fn (lambda (n)
                          (define v (net-cell-read n src-cid))
                          (net-cell-write n out-cid (+ v 1)))])
          (let-values ([(net* _pid) (net-add-propagator net (list src-cid) (list out-cid) fire-fn)])
            (loop net* (+ i 1)))))))

;; Seed a cell to trigger propagation
(define (seed-cell net cid val)
  (net-cell-write net cid val))

;; ============================================================
;; M1: Empty Quiescence
;; ============================================================

(define (m1-setup)
  ;; Network with 5 cells, 3 propagators, all at fixpoint (no dirty)
  (define-values (net cids) (make-test-network-cells 5))
  (define c0 (list-ref cids 0))
  (define c1 (list-ref cids 1))
  (define c2 (list-ref cids 2))
  (let*-values
    ([(net _) (net-add-propagator net (list c0) (list c1)
               (lambda (n) (net-cell-write n c1 (net-cell-read n c0))))]
     [(net _) (net-add-propagator net (list c1) (list c2)
               (lambda (n) (net-cell-write n c2 (net-cell-read n c1))))]
     ;; Converge once so nothing is dirty
     [(net) (values (run-to-quiescence net))])
    net))

(define m1-net (m1-setup))

(define b-m1-dfs
  (bench "M1-DFS: empty quiescence (nothing fires)"
    (parameterize ([current-use-bsp-scheduler? #f])
      (for ([_ (in-range 10000)])
        (run-to-quiescence m1-net)))))

(define b-m1-bsp
  (bench "M1-BSP: empty quiescence (nothing fires)"
    (parameterize ([current-use-bsp-scheduler? #t])
      (for ([_ (in-range 10000)])
        (run-to-quiescence m1-net)))))

;; ============================================================
;; M2: Single-Propagator Fire
;; ============================================================

(define (m2-setup)
  ;; One cell, one propagator that writes it to 1
  (define-values (net cids) (make-test-network-cells 2))
  (define c0 (car cids))
  (define c1 (cadr cids))
  (let-values ([(net _) (net-add-propagator net (list c0) (list c1)
                          (lambda (n) (net-cell-write n c1 (+ (net-cell-read n c0) 1))))])
    (values net c0)))

(define-values (m2-net-base m2-c0) (m2-setup))

(define b-m2-dfs
  (bench "M2-DFS: single-propagator fire"
    (parameterize ([current-use-bsp-scheduler? #f])
      (for ([_ (in-range 5000)])
        (run-to-quiescence (seed-cell m2-net-base m2-c0 1))))))

(define b-m2-bsp
  (bench "M2-BSP: single-propagator fire"
    (parameterize ([current-use-bsp-scheduler? #t])
      (for ([_ (in-range 5000)])
        (run-to-quiescence (seed-cell m2-net-base m2-c0 1))))))

;; ============================================================
;; M3: Chain Propagation (depth 10)
;; ============================================================

(define-values (m3-net-base m3-cids) (make-chain-network 10))
(define m3-c0 (car m3-cids))

(define b-m3-dfs
  (bench "M3-DFS: chain depth=10"
    (parameterize ([current-use-bsp-scheduler? #f])
      (for ([_ (in-range 2000)])
        (run-to-quiescence (seed-cell m3-net-base m3-c0 1))))))

(define b-m3-bsp
  (bench "M3-BSP: chain depth=10"
    (parameterize ([current-use-bsp-scheduler? #t])
      (for ([_ (in-range 2000)])
        (run-to-quiescence (seed-cell m3-net-base m3-c0 1))))))

;; ============================================================
;; M4: Fan-Out (width 10)
;; ============================================================

(define-values (m4-net-base m4-cids) (make-fanout-network 10))
(define m4-c0 (car m4-cids))

(define b-m4-dfs
  (bench "M4-DFS: fan-out width=10"
    (parameterize ([current-use-bsp-scheduler? #f])
      (for ([_ (in-range 2000)])
        (run-to-quiescence (seed-cell m4-net-base m4-c0 1))))))

(define b-m4-bsp
  (bench "M4-BSP: fan-out width=10"
    (parameterize ([current-use-bsp-scheduler? #t])
      (for ([_ (in-range 2000)])
        (run-to-quiescence (seed-cell m4-net-base m4-c0 1))))))

;; ============================================================
;; M5: Topology Creation Baseline (what the topology stratum replaces)
;; ============================================================

;; Measure the raw cost of net-new-cell + net-add-propagator — the operations
;; that the topology stratum must execute. This is the floor cost for any
;; topology-stratum iteration: how long does creating N cells + N propagators take?

(define (m5-topo-creation n)
  ;; Create N cells and N propagators (simulating decomposition of arity-N type)
  (define net0 (make-prop-network))
  (let loop ([net net0] [i 0] [last-cid #f])
    (if (>= i n)
        net
        (let*-values
          ([(net* cid) (net-new-cell net 0 last-write-merge)]
           [(net** _pid) (if last-cid
                             (net-add-propagator net* (list last-cid) (list cid)
                               (lambda (n) (net-cell-write n cid (+ (net-cell-read n last-cid) 1))))
                             (values net* (void)))])
          (loop net** (+ i 1) cid)))))

(define b-m5-topo-small
  (bench "M5: topology creation N=4 (typical arity)"
    (for ([_ (in-range 2000)])
      (m5-topo-creation 4))))

(define b-m5-topo-large
  (bench "M5: topology creation N=20 (deep compound type)"
    (for ([_ (in-range 500)])
      (m5-topo-creation 20))))

;; ============================================================
;; Summary
;; ============================================================

(printf "\n")
(print-bench-summary
 (list b-m1-dfs b-m1-bsp
       b-m2-dfs b-m2-bsp
       b-m3-dfs b-m3-bsp
       b-m4-dfs b-m4-bsp
       b-m5-topo-small b-m5-topo-large))
