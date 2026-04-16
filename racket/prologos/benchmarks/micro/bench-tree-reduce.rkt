#lang racket/base

;; bench-tree-reduce.rkt — Measure crossover point for tree-reduce merge
;;
;; Compares three BSP merge strategies at various worklist sizes N.
;; Measures merge phase only (fire phase excluded).
;;
;; Run: racket benchmarks/micro/bench-tree-reduce.rkt

(require "../../propagator.rkt"
         "../../decision-cell.rkt"
         racket/list)

;; Simple timing macro (inline, no external deps)
(define-syntax-rule (time-us name body ...)
  (let ()
    (collect-garbage)
    (collect-garbage)
    (define samples
      (for/list ([_ (in-range 10)])
        (define t0 (current-inexact-monotonic-milliseconds))
        body ...
        (define t1 (current-inexact-monotonic-milliseconds))
        (* (- t1 t0) 1000.0)))  ;; microseconds
    ;; Drop first 2 (warmup), report median of rest
    (define sorted (sort (drop samples 2) <))
    (define med (list-ref sorted (quotient (length sorted) 2)))
    (printf "  ~a: ~a us (median of ~a samples)\n" name (~r med #:precision 1) (length sorted))))

(define (~r n #:precision [p 1])
  (define factor (expt 10 p))
  (define rounded (/ (round (* n factor)) factor))
  (number->string (exact->inexact rounded)))

;; ============================================================
;; Setup: create N propagators + collect fire results
;; ============================================================

(define (make-test-data n)
  (define net0 (make-prop-network 1000000))
  ;; Allocate N target cells
  (define-values (net-with-cells cell-ids)
    (for/fold ([net net0] [cids '()])
              ([i (in-range n)])
      (define-values (net* cid) (net-new-cell net 0 +))
      (values net* (cons cid cids))))
  (define cids (reverse cell-ids))
  ;; Install N fire-once propagators
  (define net-with-props
    (for/fold ([net net-with-cells])
              ([cid (in-list cids)]
               [i (in-naturals)])
      (define val (+ i 1))
      (define fire-fn (lambda (net) (net-cell-write net cid val)))
      (define-values (net* _pid)
        (net-add-fire-once-propagator net '() (list cid) fire-fn))
      net*))
  ;; Snapshot
  (define snapshot
    (struct-copy prop-network net-with-props
      [hot (struct-copy prop-net-hot (prop-network-hot net-with-props)
             [worklist '()])]))
  ;; Collect prop-ids
  (define start-pid (prop-network-next-prop-id net0))
  (define pids
    (for/list ([i (in-range n)])
      (prop-id (+ start-pid i))))
  ;; Fire all and collect results (with namespaced cell-ids)
  (define fire-results
    (for/list ([pid (in-list pids)]
               [idx (in-naturals 1)])
      (fire-and-collect-writes snapshot pid idx)))
  (values snapshot fire-results))

;; ============================================================
;; Run benchmarks
;; ============================================================

(printf "\n=== Tree-Reduce Merge Crossover Benchmark ===\n")
(printf "Measuring merge phase only (fire phase excluded)\n")
(printf "Format: strategy: median_us (of 8 samples after 2 warmup)\n\n")

(for ([n (in-list '(4 8 16 32 64 128 256 512))])
  (printf "--- N = ~a ---\n" n)
  (define-values (snapshot fire-results) (make-test-data n))

  ;; Strategy A: bulk-merge-writes (sequential for/fold)
  (time-us "A: sequential for/fold"
    (bulk-merge-writes snapshot fire-results))

  ;; Strategy B: tree-reduce (sequential pairwise)
  (time-us "B: tree-reduce sequential"
    (let ([combined (tree-reduce-fire-results fire-results #f)])
      (if combined (bulk-merge-writes snapshot (list combined)) snapshot)))

  ;; Strategy C: tree-reduce (parallel pairwise via threads)
  (time-us "C: tree-reduce parallel"
    (let ([combined (tree-reduce-fire-results fire-results #t)])
      (if combined (bulk-merge-writes snapshot (list combined)) snapshot)))

  (printf "\n"))

(printf "=== Done ===\n")
