#lang racket/base

;; bench-parallel-scaling.rkt — Phase 0c+: Parallel Executor Scaling
;;
;; Finds the crossover point where parallel executors beat sequential.
;; Creates synthetic workloads with controlled:
;;   N = number of concurrent propagators per BSP round (4, 8, 16, 32, 64, 128)
;;   W = work per propagator fire (light, medium, heavy)
;;
;; Tests all three executors at each (N, W) combination.
;; Goal: identify the N threshold where futures/threads win,
;; and distinguish which parallel approach is better.
;;
;; Run: racket benchmarks/micro/bench-parallel-scaling.rkt

(require "../../tools/bench-micro.rkt"
         "../../propagator.rkt"
         racket/list
         racket/format)

;; ============================================================
;; Synthetic workload: N propagators, each doing W units of work
;; ============================================================

;; Work functions of varying cost
(define (light-work n)
  ;; ~0.1us: single hash lookup
  (hash-ref (hasheq 'a 1 'b 2 'c 3) 'b))

(define (medium-work n)
  ;; ~1us: small computation + allocation
  (for/fold ([acc 0]) ([i (in-range 10)])
    (+ acc (* i i))))

(define (heavy-work n)
  ;; ~10us: larger computation + allocation
  (for/fold ([acc (hasheq)]) ([i (in-range 50)])
    (hash-set acc i (* i i))))

;; Build a network with N independent propagators, each doing work W.
;; All propagators read from a single trigger cell and write to
;; independent output cells. One BSP round fires all N concurrently.
(define (make-parallel-workload n work-fn)
  (define net0 (make-prop-network))
  ;; Trigger cell — writing to this activates all propagators
  (define-values (net1 trigger-cid)
    (net-new-cell net0 #f (lambda (a b) (or a b))))
  ;; N output cells + N propagators
  (define net-final
    (for/fold ([net net1])
              ([i (in-range n)])
      (define-values (net2 out-cid)
        (net-new-cell net 0 +))
      (define-values (net3 _pid)
        (net-add-propagator net2 (list trigger-cid) (list out-cid)
          (lambda (net)
            (define v (net-cell-read net trigger-cid))
            (when v
              (define result (work-fn i))
              (net-cell-write net out-cid (if (number? result) result 1))))))
      net3))
  ;; Write trigger to activate all propagators
  (net-cell-write net-final trigger-cid #t))

;; Run the workload to quiescence under a given executor
(define (run-workload net executor-val)
  (parameterize ([current-parallel-executor executor-val]
                 [current-use-bsp-scheduler? #t])
    (run-to-quiescence net)))

;; ============================================================
;; Executor configs
;; ============================================================

(define seq-exec #f)
(define fut-exec (make-parallel-fire-all))
(define thr-exec (make-parallel-thread-fire-all))

;; ============================================================
;; Scaling benchmarks
;; ============================================================

(define ns '(4 8 16 32 64 128))
(define work-levels
  (list (list "light"  light-work)
        (list "medium" medium-work)
        (list "heavy"  heavy-work)))

(define exec-configs
  (list (list "seq" seq-exec)
        (list "fut" fut-exec)
        (list "thr" thr-exec)))

(displayln "\n=== Parallel Executor Scaling ===")
(displayln "N = concurrent propagators per BSP round")
(displayln "W = work per propagator (light ~0.1us, medium ~1us, heavy ~10us)\n")

;; Header
(displayln "| N | Work | Seq (ms) | Fut (ms) | Thr (ms) | Fut/Seq | Thr/Seq | Winner |")
(displayln "|---|---|---|---|---|---|---|---|")

(for ([wl (in-list work-levels)])
  (define w-name (first wl))
  (define w-fn (second wl))
  (for ([n (in-list ns)])
    ;; Determine iteration count to get ~10-50ms per bench
    (define iters
      (cond
        [(and (equal? w-name "heavy") (>= n 64)) 50]
        [(and (equal? w-name "heavy") (>= n 16)) 100]
        [(and (equal? w-name "medium") (>= n 64)) 200]
        [(>= n 64) 500]
        [(>= n 32) 1000]
        [else 2000]))

    ;; Build workload once (reuse — CHAMP immutable)
    (define workload-net (make-parallel-workload n w-fn))

    ;; Measure each executor
    (define results
      (for/list ([ec (in-list exec-configs)])
        (define exec-name (first ec))
        (define exec-val (second ec))
        ;; Warmup
        (for ([_ (in-range 3)])
          (run-workload workload-net exec-val))
        ;; Measure
        (collect-garbage 'major)
        (define start (current-inexact-monotonic-milliseconds))
        (for ([_ (in-range iters)])
          (run-workload workload-net exec-val))
        (define end (current-inexact-monotonic-milliseconds))
        (define total-ms (- end start))
        (define per-op-ms (/ total-ms iters))
        (list exec-name total-ms per-op-ms)))

    (define seq-ms (third (first results)))
    (define fut-ms (third (second results)))
    (define thr-ms (third (third results)))
    (define fut-ratio (/ fut-ms seq-ms))
    (define thr-ratio (/ thr-ms seq-ms))
    (define winner
      (cond
        [(and (<= fut-ratio thr-ratio) (< fut-ratio 0.95)) "futures"]
        [(and (< thr-ratio fut-ratio) (< thr-ratio 0.95)) "threads"]
        [(and (< fut-ratio 1.0) (< thr-ratio 1.0)) "both (marginal)"]
        [else "sequential"]))

    (displayln
     (format "| ~a | ~a | ~a | ~a | ~a | ~ax | ~ax | ~a |"
             n w-name
             (~r seq-ms #:precision '(= 3))
             (~r fut-ms #:precision '(= 3))
             (~r thr-ms #:precision '(= 3))
             (~r fut-ratio #:precision '(= 2))
             (~r thr-ratio #:precision '(= 2))
             winner))))

(displayln "")
(displayln "Legend: Fut/Seq < 1.0 = futures faster. Thr/Seq < 1.0 = threads faster.")
(displayln "Winner requires >5% improvement (ratio < 0.95) to avoid noise.")
